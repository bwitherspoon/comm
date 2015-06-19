/**
 * g0(0), g1(0), g0(1), g1(1), g0(2), g1(3) -> ram1, raddr1
 *                                   others -> ram0, raddr0
 */
module encoder_ram
    (input clk,
     input we,
     input [15:0] din,
     input waddr,
     input raddr0,
     input raddr1,
     output [15:0] dout);

    reg [5:0] ram0 [1:0];
    reg [9:0] ram1 [1:0];

    always @(posedge clk)
        if (we) begin
            ram0[waddr] <= {din[11], din[9:8], din[2:0]};
            ram1[waddr] <= {din[15:12], din[10], din[7:3]};
        end

    assign dout[2:0] = ram0[raddr0][2:0];
    assign dout[9:8] = ram0[raddr0][4:3];
    assign dout[11] = ram0[raddr0][5];

    assign dout[7:3] = ram1[raddr1][4:0];
    assign dout[10] = ram1[raddr1][5];
    assign dout[15:12] = ram1[raddr1][9:6];

endmodule
