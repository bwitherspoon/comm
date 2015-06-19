`timescale 1ns / 1ps

`include "ieee80211_defs.v"

/**
 * Radio
 * IEEE 802.11 OFDM PHY Convolutional Encoder
 *
 *      +-------------------->(+)------->(+)----------------->(+)------->(+)-> G0(n)
 *      |                      ^          ^                    ^          ^
 *      |  +------+   +------+ | +------+ | +------+  +------+ | +------+ |
 * D(n)-+->|D(n-1)|-->|D(n-2)|-->|D(n-3)|-->|D(n-4)|->|D(n-5)|-->|D(n-6)|-+
 *      |  +------+ | +------+ | +------+ | +------+  +------+   +------+ |
 *      |           v          v          v                               v
 *      +--------->(+)------->(+)------->(+)---------------------------->(+)-> G1(n)
 *
 *      G0(n) = D(n) + D(n-2) + D(n-3) + D(n-5) + D(n-6)
 *      G1(n) = D(n) + D(n-1) + D(n-2) + D(n-3) + D(n-6) = G0(n) + D(n-1) + D(n-5)
 *
 *      3/4 rate puncturing:
 *
 *      +-----+-----+-----+
 *      |G0(0)|G0(1)|  X  |
 *      +-----+-----+-----+
 *      |G1(0)|  X  |G1(2)|
 *      +-----+-----+-----+
 *
 *      2/3 rate puncturing:
 *
 *      +-----+-----+
 *      |G0(0)|G0(1)|
 *      +-----+-----+
 *      |G1(0)|  X  |
 *      +-----+-----+
 */
module encoder
    (input aclk,
     input aresetn,

     input [WIDTH-1:0] s_axis_tdata,
     input [3:0] s_axis_tuser,
     input s_axis_tvalid,
     output s_axis_tready,
     input s_axis_tlast,

     output reg [WIDTH-1:0] m_axis_tdata,
     output reg [3:0] m_axis_tuser,
     output reg m_axis_tvalid,
     input m_axis_tready,
     output reg m_axis_tlast);

    localparam WIDTH = 8;
    localparam HISTSIZE = 6;

    wire m_handshake = m_axis_tvalid && m_axis_tready;
    wire s_handshake = s_axis_tvalid && s_axis_tready;

    wire [WIDTH-1:0] poly [1:0];
    reg [HISTSIZE-1:0] hist;

    // Concatenate data and history as operand for the convolution
    wire [WIDTH+HISTSIZE-1:0] op = {s_axis_tdata, hist};

    genvar i;
    // For generator polynomials: g0 = 133, g1 = 171
    for (i = 0; i < WIDTH; i = i + 1) begin : gen_poly
      assign poly[0][i] = op[i+6] ^ op[i+4] ^ op[i+3] ^ op[i+1] ^ op[i];
      assign poly[1][i] = poly[0][i] ^ op[i+5] ^ op[i+1];
    end

    // Data distributed RAM
    wire [4:0] enc_raddr [1:0];
    reg [4:0] enc_waddr;
    wire [15:0] enc;
    reg dram_full;
    wire dram_empty = enc_raddr[0] == enc_waddr;

    // FIXME
    assign enc_raddr[0] = sel[34:30];
    assign enc_raddr[1] = sel[29:25];

    encoder_ram enc_ram(
        .clk(aclk),
        .we(s_handshake),
        .din({poly[1], poly[0]}),
        .waddr(enc_waddr),
        .raddr0(enc_raddr[0]),
        .raddr1(enc_raddr[1]),
        .dout(enc)
    );

    always @(posedge aclk)
        if (m_handshake && ~s_handshake)
            dram_full <= 0;
        else if (s_handshake && ~m_handshake && enc_raddr[0] + 3 == enc_waddr)
            dram_full <= 1;
    // End data distributed RAM

    // Rate distributed RAM
    wire [15:0] rate_dout;
    reg [3:0] rate [31:0];

    always @(posedge aclk)
        if (s_handshake)
            rate[enc_waddr] <= s_axis_tuser;

    assign rate_dout = rate[enc_raddr[0]];
    // End rate distributed RAM

    // TODO
    always @(posedge aclk)
        if (~aresetn) begin
            enc_waddr <= 5'b00000;
        end
        else begin
            if (s_handshake)
                enc_waddr <= enc_waddr + 1;
        end

    // Select LUT ROM
    (* rom_style = "distributed" *) reg [34:0] sel_rom;
    wire [34:0] sel;
    reg [6:0] sel_raddr;

    /*
     *   raddr0  raddr1   sel7    sel6    sel5    sel4   sel3   sel2  sel1  sel0
     * +-------+-------+-------+-------+-------+-------+------+-----+-----+-----+
     * | 34:30 | 29:25 | 24:22 | 21:19 | 18:15 | 14:12 | 11:9 | 8:6 | 5:3 | 2:0 |
     * +-------+-------+-------+-------+-------+-------+------+-----+-----+-----+
     */
    always @(posedge aclk)
        if (m_handshake)
            case (sel_raddr)
            // 1/2 rate
            7'b0000000: sel_rom <= {5'b00000, 5'b00000, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0000001: sel_rom <= {5'b00000, 5'b00000, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0000010: sel_rom <= {5'b00001, 5'b00001, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0000011: sel_rom <= {5'b00001, 5'b00001, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0000100: sel_rom <= {5'b00010, 5'b00010, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0000101: sel_rom <= {5'b00010, 5'b00010, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0000110: sel_rom <= {5'b00011, 5'b00011, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0000111: sel_rom <= {5'b00011, 5'b00011, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0001000: sel_rom <= {5'b00100, 5'b00100, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0001001: sel_rom <= {5'b00100, 5'b00100, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0001010: sel_rom <= {5'b00101, 5'b00101, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0001011: sel_rom <= {5'b00101, 5'b00101, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0001100: sel_rom <= {5'b00110, 5'b00110, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0001101: sel_rom <= {5'b00110, 5'b00110, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0001110: sel_rom <= {5'b00111, 5'b00111, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0001111: sel_rom <= {5'b00111, 5'b00111, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0010000: sel_rom <= {5'b01000, 5'b01000, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0010001: sel_rom <= {5'b01000, 5'b01000, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0010010: sel_rom <= {5'b01001, 5'b01001, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0010011: sel_rom <= {5'b01001, 5'b01001, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0010100: sel_rom <= {5'b01010, 5'b01010, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0010101: sel_rom <= {5'b01010, 5'b01010, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0010110: sel_rom <= {5'b01011, 5'b01011, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0010111: sel_rom <= {5'b01011, 5'b01011, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0011000: sel_rom <= {5'b01100, 5'b01100, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0011001: sel_rom <= {5'b01100, 5'b01100, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0011010: sel_rom <= {5'b01101, 5'b01101, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0011011: sel_rom <= {5'b01101, 5'b01101, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0011100: sel_rom <= {5'b01110, 5'b01110, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0011101: sel_rom <= {5'b01110, 5'b01110, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            7'b0011110: sel_rom <= {5'b01111, 5'b01111, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            7'b0011111: sel_rom <= {5'b01111, 5'b01111, 3'b001, 3'b001, 4'b0001, 3'b001, 3'b001, 3'b001, 3'b001, 3'b001};
            // TODO 2/3 rate
            // TODO 3/4 rate
            default: sel_rom <= {5'b00000, 5'b00000, 3'b000, 3'b000, 4'b0000, 3'b000, 3'b000, 3'b000, 3'b000, 3'b000};
            endcase

    assign sel = sel_rom;

    // First bit mux
    always @*
        case (sel[2:0])
             3'b000: m_axis_tdata[0] = enc[0];  // poly[0][0]
             3'b001: m_axis_tdata[0] = enc[4];  // poly[0][4]
             3'b010: m_axis_tdata[0] = enc[6];  // poly[0][6]
             3'b011: m_axis_tdata[0] = enc[2];  // poly[0][2]
             3'b100: m_axis_tdata[0] = enc[5];  // poly[0][5]
            default: m_axis_tdata[0] = enc[10]; // poly[1][2]
        endcase

    // Second bit mux
    always @*
        case (sel[5:3])
             3'b000: m_axis_tdata[1] = enc[8];  // poly[1][0]
             3'b001: m_axis_tdata[1] = enc[12]; // poly[1][4]
             3'b010: m_axis_tdata[1] = enc[14]; // poly[1][6]
             3'b011: m_axis_tdata[1] = enc[10]; // poly[1][2]
             3'b100: m_axis_tdata[1] = enc[6];  // poly[0][6]
            default: m_axis_tdata[1] = enc[3];  // poly[0][3]
        endcase

    // Third bit mux
    always @*
        case (sel[8:6])
             3'b000: m_axis_tdata[2] = enc[1];  // poly[0][1]
             3'b001: m_axis_tdata[2] = enc[5];  // poly[0][5]
             3'b010: m_axis_tdata[2] = enc[7];  // poly[0][7]
             3'b011: m_axis_tdata[2] = enc[3];  // poly[0][3]
             3'b100: m_axis_tdata[2] = enc[14]; // poly[1][6]
            default: m_axis_tdata[2] = enc[4];  // poly[0][4]
        endcase

    // Fourth bit mux
    always @*
        case (sel[11:9])
            3'b000: m_axis_tdata[3] = enc[9];  // poly[1][1]
            3'b001: m_axis_tdata[3] = enc[13]; // poly[1][5]
            3'b010: m_axis_tdata[3] = enc[14]; // poly[1][6]
            3'b011: m_axis_tdata[3] = enc[12]; // poly[1][4]
            3'b100: m_axis_tdata[3] = enc[10]; // poly[1][2]
            3'b101: m_axis_tdata[3] = enc[8];  // poly[1][0]
            3'b110: m_axis_tdata[3] = enc[2];  // poly[0][2]
            3'b111: m_axis_tdata[3] = enc[7];  // poly[0][7]
        endcase

    // Fifth bit mux
    always @*
        case (sel[14:12])
            3'b000: m_axis_tdata[4] = enc[2];  // poly[0][2]
            3'b001: m_axis_tdata[4] = enc[6];  // poly[0][6]
            3'b010: m_axis_tdata[4] = enc[7];  // poly[0][7]
            3'b011: m_axis_tdata[4] = enc[5];  // poly[0][5]
            3'b100: m_axis_tdata[4] = enc[3];  // poly[0][3]
            3'b101: m_axis_tdata[4] = enc[1];  // poly[0][1]
            3'b110: m_axis_tdata[4] = enc[10]; // poly[1][2]
            3'b111: m_axis_tdata[4] = enc[0];  // poly[0][0]
        endcase

    // Sixth bit mux
    always @*
        case (sel[18:15])
            4'b0000: m_axis_tdata[5] = enc[10]; // poly[1][2]
            4'b0001: m_axis_tdata[5] = enc[14]; // poly[1][6]
            4'b0010: m_axis_tdata[5] = enc[15]; // poly[1][7]
            4'b0011: m_axis_tdata[5] = enc[13]; // poly[1][5]
            4'b0100: m_axis_tdata[5] = enc[11]; // poly[1][3]
            4'b0101: m_axis_tdata[5] = enc[9];  // poly[1][1]
            4'b0110: m_axis_tdata[5] = enc[11]; // poly[0][3]
            4'b0111: m_axis_tdata[5] = enc[8];  // poly[1][0]
            default: m_axis_tdata[5] = enc[6];  // poly[0][6]
        endcase

    // Seventh bit mux
    always @*
        case (sel[21:19])
            3'b000: m_axis_tdata[6] = enc[3];  // poly[0][3]
            3'b001: m_axis_tdata[6] = enc[7];  // poly[0][7]
            3'b010: m_axis_tdata[6] = enc[0];  // poly[0][0]
            3'b011: m_axis_tdata[6] = enc[6];  // poly[0][6]
            3'b100: m_axis_tdata[6] = enc[4];  // poly[0][4]
            3'b101: m_axis_tdata[6] = enc[2];  // poly[0][2]
            3'b110: m_axis_tdata[6] = enc[1];  // poly[0][1]
            3'b111: m_axis_tdata[6] = enc[14]; // poly[1][6]
        endcase

    // Eighth bit mux
    always @*
        case (sel[24:22])
             3'b000: m_axis_tdata[7] = enc[11]; // poly[1][3]
             3'b001: m_axis_tdata[7] = enc[15]; // poly[1][7]
             3'b010: m_axis_tdata[7] = enc[9];  // poly[1][1]
             3'b011: m_axis_tdata[7] = enc[13]; // poly[1][5]
             3'b100: m_axis_tdata[7] = enc[12]; // poly[1][4]
             3'b101: m_axis_tdata[7] = enc[2];  // poly[0][2]
            default: m_axis_tdata[7] = enc[7];  // poly[0][7]
        endcase

    // History register
    always @(posedge aclk)
        if (~aresetn)
            hist <= {HISTSIZE{1'b0}};
        else if (s_handshake)
            hist <= s_axis_tdata[WIDTH-1:WIDTH-HISTSIZE];

endmodule
