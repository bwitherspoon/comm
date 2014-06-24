`timescale 1ps / 1ps

module fifo_tb;

    localparam CLOCKPERIOD = 10;
    localparam WIDTH = 32;
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

    wire i_handshake = i_tvalid & i_tready;
    wire c_handshake = c_tvalid & c_tready;
    wire o_handshake = o_tvalid & o_tready;

    reg [3:0] counter = 1;

    task reset;
    begin
        rst = 0;
        @(posedge clk);
        #1 rst = 1;
    end
    endtask

    fifo #(.WIDTH(WIDTH)) dut_0(
        .aclk(clk),
        .aresetn(rst),
        .s_axis_tdata(i_tdata),
        .s_axis_tvalid(i_tvalid),
        .s_axis_tready(i_tready),
        .m_axis_tdata(c_tdata),
        .m_axis_tvalid(c_tvalid),
        .m_axis_tready(c_tready)
    );

    fifo #(.WIDTH(WIDTH)) dut_1(
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

    initial begin
        $dumpfile("fifo.vcd");
        $dumpvars;
    end

    initial begin
        // Init
        i_tvalid = 0;
        o_tready = 0;
        reset();

        // Leave o_tready low and observe
        i_tvalid = 1;
        i_tdata = 1;
        repeat (50) @(posedge clk) begin
            if (i_handshake)
                #1 i_tdata = i_tdata + 1;
            else
                $display("No handshake at %2d...", i_tdata);
        end
        i_tvalid = 0;
        o_tready = 1;
        @(negedge o_tvalid);

        $finish;
    end

endmodule
