`timescale 1ns / 1ps

`include "ieee80211_defs.v"

/**
 * IEEE 802.11 Block Interleaver
 *
 * Interleaving:
 *
 * i = (N_cbps/16)(k mod 16) + floor(k/16)
 * j = s * floor(i/s) + (i + N_cbps - floor(16*i/N_cpbs)) mod s
 * s = max(N_bpsc/2, 1)
 *
 * Deinterleaving:
 *
 * i = s * floor(j/s) + (j + floor(16*j/N_cpbs)) mod s
 * k = 16 * i - (N_cbps - 1) * floor(16*i/N_cbps)
 */
module interleaver
    (input aclk,
     input aresetn,

     input [7:0] s_axis_tdata,
     input [3:0] s_axis_tuser,
     input s_axis_tvalid,
     output s_axis_tready,
     input s_axis_tlast,

     output reg [7:0] m_axis_tdata,
     output reg [3:0] m_axis_tuser,
     output reg m_axis_tvalid,
     input m_axis_tready,
     output m_axis_tlast);

    // Coded bits per subcarrier
    localparam CBPS_BPSK = 48;
    localparam CBPS_QPSK = 96;
    localparam CBPS_QAM16 = 192;
    localparam CBPS_QAM64 = 288;

    // Reverse permutations for the generate blocks
    function integer permute(input integer j, input integer cbps);
        integer s, i;
        begin
            s = (cbps == CBPS_QAM64) ? 3 : (cbps == CBPS_QAM16) ? 2 : 1;
            i = s * (j/s) + (j + (16*j)/cbps) % s;
            permute = 16*i - (cbps - 1) * ((16*i)/cbps);
        end
    endfunction

    //// Forward permutations for the generate blocks
    //function integer permute(input integer k, input integer cbps);
    //    integer s, i;
    //    begin
    //        s = (cbps == CBPS_QAM64) ? 3 : (cbps == CBPS_QAM16) ? 2 : 1;
    //        i = (cbps/16) * (k % 16) + k/16;
    //        permute = s * (i/s) + (i + cbps - (16*i)/cbps) % s;
    //    end
    //endfunction

    wire m_handshake = m_axis_tvalid & m_axis_tready;

    // FIFO
    reg [35:0] fifo [511:0];
    reg [8:0] fifo_waddr;
    reg [8:0] fifo_raddr;
    reg [35:0] fifo_dout;
    reg [1:0] fifo_state;
    // FIXME
    wire fifo_ren = m_handshake && ~fifo_empty;
    wire fifo_wen = ctl_state == WRITE && ~fifo_full;
    wire fifo_empty = fifo_raddr == fifo_waddr;
    reg fifo_full;

    // Input block
    reg [7:0] block [35:0];
    reg [3:0] block_rate;
    reg [5:0] block_waddr;
    reg [5:0] block_raddr;
    wire [287:0] block_net = {block[35], block[34], block[33], block[32],
                              block[31], block[30], block[29], block[28],
                              block[27], block[26], block[25], block[24],
                              block[23], block[22], block[21], block[20],
                              block[19], block[18], block[17], block[16],
                              block[15], block[14], block[13], block[12],
                              block[11], block[10], block[ 9], block[ 8],
                              block[ 7], block[ 6], block[ 5], block[ 4],
                              block[ 3], block[ 2], block[ 1], block[ 0]};

    wire is_bpsk_rate = block_rate == `RATE_6M || block_rate == `RATE_9M;
    wire is_qpsk_rate = block_rate == `RATE_12M || block_rate == `RATE_18M;
    wire is_qam16_rate = block_rate == `RATE_24M || block_rate == `RATE_36M;
    wire is_qam64_rate = block_rate == `RATE_48M || block_rate == `RATE_54M;

    wire block_bpsk_end  = is_bpsk_rate && block_waddr == 5;
    wire block_qpsk_end  = is_qpsk_rate && block_waddr == 12;
    wire block_qam16_end = is_qam16_rate && block_waddr == 23;
    wire block_qam64_end = is_qam64_rate && block_waddr == 35;

    wire block_end = block_qam64_end || block_qam16_end ||
                     block_qpsk_end  || block_bpsk_end;

    // Interleaving for each block size
    reg [15:0] inter_bpsk [2:0];
    reg [31:0] inter_qpsk [2:0];
    reg [31:0] inter_qam16 [5:0];
    reg [31:0] inter_qam64 [8:0];

    wire [CBPS_BPSK-1:0] inter_bpsk_net = {inter_bpsk[2], inter_bpsk[1],
                                           inter_bpsk[0]};

    wire [CBPS_QPSK-1:0] inter_qpsk_net = {inter_qpsk[2], inter_qpsk[1],
                                           inter_qpsk[0]};

    wire [CBPS_QAM16-1:0] inter_qam16_net = {inter_qam16[5], inter_qam16[4],
                                             inter_qam16[3], inter_qam16[2],
                                             inter_qam16[1], inter_qam16[0]};

    wire [CBPS_QAM64-1:0] inter_qam64_net = {inter_qam64[8], inter_qam64[7],
                                             inter_qam64[6], inter_qam64[5],
                                             inter_qam64[4], inter_qam64[3],
                                             inter_qam64[2], inter_qam64[1],
                                             inter_qam64[0]};

    genvar j;
    for (j = 0; j < CBPS_BPSK; j = j + 1) begin : gen_bpsk
        assign inter_bpsk_net[j] = block_net[permute(j, CBPS_BPSK)];
    end
    for (j = 0; j < CBPS_QPSK; j = j + 1) begin : gen_qpsk
        assign inter_qpsk_net[j] = block_net[permute(j, CBPS_QPSK)];
    end
    for (j = 0; j < CBPS_QAM16; j = j + 1) begin : gen_qam16
        assign inter_qam16_net[j] = block_net[permute(j, CBPS_QAM16)];
    end
    for (j = 0; j < CBPS_QAM64; j = j + 1) begin : gen_qam64
        assign inter_qam64_net[j] = block_net[permute(j, CBPS_QAM64)];
    end

    wire inter_bpsk_end = is_bpsk_rate && inter_raddr == 1;
    wire inter_qpsk_end = is_qpsk_rate && inter_raddr == 2;
    wire inter_qam16_end = is_qam16_rate && inter_raddr == 5;
    wire inter_qam64_end = is_qam64_rate && inter_raddr == 8;

    wire inter_end = inter_qam64_end || inter_qam16_end ||
                     inter_qpsk_end  || inter_bpsk_end;

    // Interleaved data
    reg [31:0] inter [8:0];
    reg [3:0] inter_raddr;

    // Controller state
    reg ctl_state;

    localparam READ = 0;
    localparam WRITE = 1;

    // Controller
    always @(posedge aclk)
        if (~aresetn) begin
            ctl_state <= READ;
            block_waddr <= 0;
            inter_raddr <= 0;
        end
        else
            case (ctl_state)
                READ: begin
                    if (s_axis_tvalid) begin
                        block[block_waddr] <= s_axis_tdata;
                        if (block_waddr == 0)
                            block_rate <= s_axis_tuser;
                        if (block_end) begin
                            block_waddr <= 0;
                            ctl_state <= WRITE;
                        end
                        else begin
                            block_waddr <= block_waddr + 1;
                            ctl_state <= READ;
                        end
                    end
                    else begin
                        ctl_state <= READ;
                    end
                end
                WRITE: begin
                    if (~fifo_full) begin
                        if (inter_end) begin
                            inter_raddr <= 0;
                            ctl_state <= READ;
                        end
                        else begin
                            inter_raddr <= inter_raddr + 1;
                            ctl_state <= WRITE;
                        end
                    end
                    else begin
                        ctl_state <= WRITE;
                    end
                end
            endcase

    assign s_axis_tready = ctl_state == READ;

    // Interleaving mux
    integer k;
    always@*
        case (block_rate)
            `RATE_12M, `RATE_18M: begin
                for (k = 0; k < 3; k = k + 1)
                    inter[k] = inter_qpsk[k];
                for (k = 3; k < 9; k = k + 1)
                    inter[k] = {32{1'bx}};
            end
            `RATE_24M, `RATE_36M: begin
                for (k = 0; k < 6; k = k + 1)
                    inter[k] = inter_qam16[k];
                for (k = 6; k < 9; k = k + 1)
                    inter[k] = {32{1'bx}};
            end
            `RATE_48M, `RATE_54M: begin
                for (k = 0; k < 9; k = k + 1)
                    inter[k] = inter_qam64[k];
            end
            default: begin
                inter[0] = {inter_bpsk[1], inter_bpsk[0]};
                inter[1] = {{16{1'bx}}, inter_bpsk[2]};
                for (k = 2; k < 9; k = k + 1)
                    inter[k] = {32{1'bx}};
            end
        endcase

    // FIFO
    always @(posedge aclk)
        if (~aresetn)
            fifo_raddr <= 0;
        else if (fifo_ren) begin
            fifo_dout <= fifo[fifo_raddr];
            fifo_raddr <= fifo_raddr + 1;
        end

    always @(posedge aclk)
        if (~aresetn)
            fifo_waddr <= 0;
        else if (fifo_wen) begin
            fifo[fifo_waddr] <= {block_rate, inter[inter_raddr]};
            fifo_waddr <= fifo_waddr + 1;
        end

    always @(posedge aclk)
        if (~aresetn)
            fifo_full <= 0;
        else if (fifo_ren && ~fifo_wen)
            fifo_full <= 0;
        else if (fifo_wen && ~fifo_ren && fifo_waddr + 2 == fifo_raddr)
            fifo_full <= 1;

    // AXI-Stream master interface
    always @(posedge aclk) begin
        if (~aresetn) begin
            m_axis_tvalid <= 0;
        end
        else if (m_handshake) begin
        end
    end
endmodule
