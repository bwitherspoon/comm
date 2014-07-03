`timescale 1ns / 1ps

`include "ieee80211_defs.v"

`define INPUT_VECTOR  "encoded_data_bits.txt"
`define OUTPUT_VECTOR "interleaved_data_bits.txt"

module interleaver_tb;

    `include "axis_tasks.v"

    localparam WIDTH = 8;

    localparam SEND_WIDTH = WIDTH;
    localparam RECV_WIDTH = WIDTH;

    localparam CLOCKPERIOD = 100;
    localparam DATA_COUNT = 24;

    reg [WIDTH-1:0] data_input [DATA_COUNT-1:0];
    reg [WIDTH-1:0] data_output [DATA_COUNT-1:0];

    reg clk = 1;
    reg rst;

    reg [WIDTH-1:0] i_tdata;
    reg [WIDTH/2-1:0] i_tuser;
    reg i_tvalid;
    wire i_tready;
    reg i_tlast;

    wire [WIDTH-1:0] o_tdata;
    wire [WIDTH/2-1:0] o_tuser;
    wire o_tvalid;
    reg o_tready;
    wire o_tlast;

    interleaver dut(
        .aclk(clk),
        .aresetn(rst),
        .s_axis_tdata(i_tdata),
        .s_axis_tvalid(i_tvalid),
        .s_axis_tready(i_tready),
        .s_axis_tuser(i_tuser),
        .s_axis_tlast(i_tlast),
        .m_axis_tdata(o_tdata),
        .m_axis_tvalid(o_tvalid),
        .m_axis_tuser(o_tuser),
        .m_axis_tready(o_tready),
        .m_axis_tlast(o_tlast)
    );

    always #(CLOCKPERIOD/2) clk <= ~clk;

    initial begin
        $display("Loading test vectors...");
        $readmemb(`INPUT_VECTOR, data_input, 0, DATA_COUNT-1);
        $readmemb(`OUTPUT_VECTOR, data_output, 0, DATA_COUNT-1);
        $dumpfile("interleaver.vcd");
        $dumpvars;
    end

    integer i;
    initial begin
        $display("Start...");
        // Initialize and reset
        i_tuser = 0;
        i_tvalid = 0;
        i_tlast = 0;
        o_tready = 0;
        reset();

        $display("Starting DATA interleaving test...");
        i_tuser = `RATE_36M;
        for (i = 0; i < DATA_COUNT; i = i + 1) begin
            send(data_input[i]);
            if (o_tdata != data_output[i]) begin
                $display("Failed DATA interleaving test %1d.", i);
                $display("EXP: %b", data_output[i]);
                $display("GOT: %b", o_tdata);
                $finish;
            end
        end

        $display("All tests succeeded.");
        #(10*CLOCKPERIOD) $finish;
    end
endmodule
