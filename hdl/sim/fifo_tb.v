`timescale 1ps / 1ps

module fifo_tb;

    `include "axis_tasks.v"

    localparam WIDTH = 32;
    localparam DEPTH = 5;

    localparam SEND_WIDTH = WIDTH;
    localparam RECV_WIDTH = WIDTH;

    localparam CLOCKPERIOD = 10;
    localparam TEST_COUNT = 10;

    reg clk = 1;
    reg rst;

    reg [WIDTH-1:0] i_tdata;
    reg i_tvalid;
    wire i_tready;

    wire [WIDTH-1:0] c_tdata;
    wire c_tvalid;
    wire c_tready;

    wire [WIDTH-1:0] o_tdata;
    wire o_tvalid;
    reg o_tready;

    reg [WIDTH-1:0] out;

    fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut_0(
        .aclk(clk),
        .aresetn(rst),
        .s_axis_tdata(i_tdata),
        .s_axis_tvalid(i_tvalid),
        .s_axis_tready(i_tready),
        .m_axis_tdata(c_tdata),
        .m_axis_tvalid(c_tvalid),
        .m_axis_tready(c_tready)
    );

    fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut_1(
        .aclk(clk),
        .aresetn(rst),
        .s_axis_tdata(c_tdata),
        .s_axis_tvalid(c_tvalid),
        .s_axis_tready(c_tready),
        .m_axis_tdata(o_tdata),
        .m_axis_tvalid(o_tvalid),
        .m_axis_tready(o_tready)
    );

    always #(CLOCKPERIOD/2) clk = ~clk;

    integer i, j;

    initial begin
        $dumpfile("fifo.vcd");
        $dumpvars;

        // Initialize and reset
        i_tvalid = 0;
        o_tready = 0;
        reset();

        // Fill the FIFOs and wait for it propagate out
        for (i = 0; i_tready == 1'b1; i = i + 1) begin
            send(i);
        end

        for (j = 0; o_tvalid == 1'b1; j = j + 1) begin
            recv(out);
            if (out != j) begin
                $display("ERROR: Expected %2d, Got %2d", j, out);
                $finish;
            end
        end

        if (i != j) begin
            $display("ERROR: Sent %2d, Received %2d", i, j);
            $finish;
        end

        $display("All tests succeeded.");
        $finish;
    end

endmodule
