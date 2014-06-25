`timescale 1ns / 1ps

`include "ieee80211_defs.v"

module system_tb;

    localparam WIDTH = 24;
    localparam DELAY = 2;
    localparam CLOCKPERIOD = 20;
    localparam DATA_COUNT = 10;

    `include "axis_tasks.v"

    reg [WIDTH-1:0] data_input [DATA_COUNT-1:0];
    reg [2*WIDTH-1:0] data_output [DATA_COUNT-1:0];

    reg clk = 1;
    reg rst;

    reg [WIDTH-1:0] i_tdata;
    reg i_tvalid;
    wire i_tready;
    reg i_tlast;
    reg [3:0] i_tuser;

    wire [2*WIDTH-1:0] o_tdata;
    wire o_tvalid;
    reg o_tready;
    wire o_tlast;
    wire [3:0] o_tuser;

    integer i;

    system #(.WIDTH(WIDTH)) system_i(
        .aclk(clk),
        .aresetn(rst),
        .s_axis_tdata(i_tdata),
        .s_axis_tvalid(i_tvalid),
        .s_axis_tready(i_tready),
        .s_axis_tuser(i_tuser),
        .s_axis_tlast(i_tlast),
        .m_axis_tdata(o_tdata),
        .m_axis_tvalid(o_tvalid),
        .m_axis_tready(o_tready),
        .m_axis_tlast(o_tlast),
        .m_axis_tuser(o_tuser)
    );

    always #(CLOCKPERIOD/2) clk <= ~clk;

    initial begin
        $readmemb("vectors/data_before_scrambling.txt", data_input, 0, DATA_COUNT-1);
        $readmemb("vectors/data_after_encoding.txt", data_output, 0, DATA_COUNT-1);
        $dumpfile("system.vcd");
        $dumpvars;
    end

    initial begin
        i_tvalid = 0;
        i_tlast = 0;
        i_tuser = 0;
        o_tready = 0;
        reset();

        o_tready = 1;
        for (i = 0; i < DATA_COUNT; i = i + 1) begin
            send(data_input[i]);
            repeat (DELAY-1) @(posedge clk) #1;
            if (o_tdata != data_output[i]) begin
                $display("EXP: %b", data_output[i]);
                $display("GOT: %b", o_tdata);
                $display;
            end
        end
        $finish;
    end
endmodule
