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

    wire s_handshake = s_axis_tvalid & s_axis_tready;
    wire m_handshake = m_axis_tvalid & m_axis_tready;
    reg [1:0] m_addr;
    wire [7:0] m_dout [3:0];

    assign m_dout[3] = fifo_dout[31:24];
    assign m_dout[2] = fifo_dout[23:16];
    assign m_dout[1] = fifo_dout[15:8];
    assign m_dout[0] = fifo_dout[7:0];

    reg [35:0] fifo_ram [511:0];
    reg [8:0] fifo_waddr;
    reg [8:0] fifo_raddr;
    reg [35:0] fifo_dout;
    reg fifo_rden;
    wire fifo_full;
    wire fifo_empty;

    reg [3:0] p_rate;

    reg valid_int;
    reg ready_int;

    // Distributed RAM for permutation
    reg [7:0] p_ram [35:0];
    reg [5:0] p_ram_ra;
    reg [5:0] p_ram_wa;

    reg [15:0] p_bpsk [2:0];
    reg [31:0] p_qpsk [2:0];
    reg [31:0] p_qam16 [5:0];
    reg [31:0] p_qam64 [8:0];

    reg [31:0] p_dout [8:0];
    reg [3:0] p_dout_addr;

    // Concatenate distributed RAM read ports into a single bus
    wire [287:0] p_ram_net = {p_ram[35], p_ram[34], p_ram[33], p_ram[32],
                             p_ram[31], p_ram[30], p_ram[29], p_ram[28],
                             p_ram[27], p_ram[26], p_ram[25], p_ram[24],
                             p_ram[23], p_ram[22], p_ram[21], p_ram[20],
                             p_ram[19], p_ram[18], p_ram[17], p_ram[16],
                             p_ram[15], p_ram[14], p_ram[13], p_ram[12],
                             p_ram[11], p_ram[10], p_ram[ 9], p_ram[ 8],
                             p_ram[ 7], p_ram[ 6], p_ram[ 5], p_ram[ 4],
                             p_ram[ 3], p_ram[ 2], p_ram[ 1], p_ram[ 0]};

    // Permutation buses
    wire [CBPS_BPSK-1:0] p_bpsk_net = {p_bpsk[2], p_bpsk[1], p_bpsk[0]};
    wire [CBPS_QPSK-1:0] p_qpsk_net = {p_qpsk[2], p_qpsk[1], p_qpsk[0]};
    wire [CBPS_QAM16-1:0] p_qam16_net = {p_qam16[5], p_qam16[4], p_qam16[3],
                                         p_qam16[2], p_qam16[1], p_qam16[0]};
    wire [CBPS_QAM64-1:0] p_qam64_net = {p_qam64[8], p_qam64[7], p_qam64[6],
                                         p_qam64[5], p_qam64[4], p_qam64[3],
                                         p_qam64[2], p_qam64[1], p_qam64[0]};

    genvar j;
    for (j = 0; j < CBPS_BPSK; j = j + 1) begin : gen_bpsk
        assign p_bpsk_net[j] = p_ram_net[permute(j, CBPS_BPSK)];
    end
    for (j = 0; j < CBPS_QPSK; j = j + 1) begin : gen_qpsk
        assign p_qpsk_net[j] = p_ram_net[permute(j, CBPS_QPSK)];
    end
    for (j = 0; j < CBPS_QAM16; j = j + 1) begin : gen_16qam
        assign p_qam16_net[j] = p_ram_net[permute(j, CBPS_QAM16)];
    end
    for (j = 0; j < CBPS_QAM64; j = j + 1) begin : gen_64qam
        assign p_qam64_net[j] = p_ram_net[permute(j, CBPS_QAM64)];
    end

    // Mux
    integer k;
    always@*
        case (p_rate)
            `RATE_12M, `RATE_18M: begin
                for (k = 0; k < 3; k = k + 1)
                    p_dout[k] = p_qpsk[k];
                for (k = 3; k < 9; k = k + 1)
                    p_dout[k] = {32{1'bx}};
            end
            `RATE_24M, `RATE_36M: begin
                for (k = 0; k < 6; k = k + 1)
                    p_dout[k] = p_qam16[k];
                for (k = 6; k < 9; k = k + 1)
                    p_dout[k] = {32{1'bx}};
            end
            `RATE_48M, `RATE_54M: begin
                for (k = 0; k < 9; k = k + 1)
                    p_dout[k] = p_qam64[k];
            end
            default: begin
                p_dout[0] = {p_bpsk[1], p_bpsk[0]};
                p_dout[1] = {{16{1'bx}}, p_bpsk[2]};
                for (k = 2; k < 9; k = k + 1)
                    p_dout[k] = {32{1'bx}};
            end
        endcase


    // FIFO
    always @(posedge aclk)
        if (fifo_rden) begin
            fifo_dout <= fifo_ram[fifo_raddr];
            fifo_raddr <= fifo_raddr + 1;
        end

    always @(posedge aclk)
        if (valid_int) begin
            fifo_ram[fifo_waddr] <= {p_rate, p_dout[p_dout_addr]};
            fifo_waddr <= fifo_waddr + 1;
        end

    assign fifo_full = fifo_waddr == fifo_raddr + 1;
    assign fifo_empty = fifo_waddr == fifo_raddr;


    always @(posedge aclk)
        if (~aresetn)
            p_dout_addr <= 0;
        else
            case (p_rate)
                `RATE_6M, `RATE_9M: if (p_dout_addr == 2) p_dout_addr <= 0;
                `RATE_12M, `RATE_18M: if (p_dout_addr == 3) p_dout_addr <= 0;
                `RATE_24M, `RATE_36M: if (p_dout_addr == 6) p_dout_addr <= 0;
                `RATE_48M, `RATE_54M: if (p_dout_addr == 9) p_dout_addr <= 0;
            endcase


    always @(posedge aclk)
        if (~aresetn)
            ready_int <= 0;
        else if (valid_int & ready_int)
            ready_int <= 0;
        else
            case (p_rate)
                `RATE_6M, `RATE_9M: if (p_dout_addr == 2) ready_int <= 1;
                `RATE_12M, `RATE_18M: if (p_dout_addr == 3) ready_int <= 1;
                `RATE_24M, `RATE_36M: if (p_dout_addr == 6) ready_int <= 1;
                `RATE_48M, `RATE_54M: if (p_dout_addr == 9) ready_int <= 1;
            endcase

    // FIXME ???
    assign s_axis_tready = ready_int;

    // AXI-Stream slave interface
    always @(posedge aclk) begin
        if (~aresetn)
            p_ram_wa <= 0;
        else if (ready_int) begin
            if (valid_int)
                valid_int <= 0;

            if (s_handshake) begin
                p_ram[p_ram_wa] <= s_axis_tdata;
                p_ram_wa <= p_ram_wa + 1;

                if (p_ram_wa == 0)
                    p_rate <= s_axis_tuser;
                else
                    case (p_rate)
                        `RATE_6M, `RATE_9M:
                            if (p_ram_wa == 5) begin
                                p_ram_wa <= 0;
                                valid_int <= 1;
                            end
                        `RATE_12M, `RATE_18M:
                            if (p_ram_wa == 12) begin
                                p_ram_wa <= 0;
                                valid_int <= 1;
                            end
                        `RATE_24M, `RATE_36M:
                            if (p_ram_wa == 23) begin
                                p_ram_wa <= 0;
                                valid_int <= 1;
                            end
                        `RATE_48M, `RATE_54M:
                            if (p_ram_wa == 35) begin
                                p_ram_wa <= 0;
                                valid_int <= 1;
                            end
                    endcase
            end
        end
    end

    // AXI-Stream master interface
    always @(posedge aclk) begin
        if (~aresetn) begin
            m_addr <= 0;
            m_axis_tvalid <= 0;
        end
        else if (m_handshake) begin
            if (m_addr == 3) begin
                if (fifo_full)
                    m_axis_tvalid <= 0;
                else
                    fifo_rden <= 1;
            end
            else if (fifo_rden == 1)
                fifo_rden <= 1;
            m_axis_tdata <= m_dout[m_addr];
            m_axis_tuser <= fifo_dout[35:32];
            m_addr <= m_addr + 1;
        end
    end
endmodule
