`timescale 1ns / 1ps

`include "ieee80211_defs.v"

module system_tb;

    `include "axis_tasks.v"

    localparam WIDTH = 24;
    localparam DELAY = 2;

    localparam SEND_WIDTH = WIDTH;
    localparam RECV_WIDTH = 2*WIDTH;

    localparam CLOCKPERIOD = 20;
    localparam DATA_COUNT = 10;

    reg [WIDTH-1:0] data_input [DATA_COUNT-1:0];
    reg [2*WIDTH-1:0] data_output [DATA_COUNT-1:0];
    reg [2*WIDTH-1:0] data_buffer [DATA_COUNT-1:0];

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
        $readmemb("data_before_scrambling.txt", data_input, 0, DATA_COUNT-1);
        $readmemb("data_after_encoding.txt", data_output, 0, DATA_COUNT-1);
        $dumpfile("system.vcd");
        $dumpvars;
    end

    integer i, j;

    initial begin
        i_tvalid = 0;
        i_tlast = 0;
        i_tuser = 0;
        o_tready = 0;
        reset();

        #(CLOCKPERIOD/4) o_tready = 1;
        fork
            begin
                for (i = 0; i < DATA_COUNT; i = i + 1)
                    send(data_input[i]);
            end
            begin
                for (j = 0; j < DATA_COUNT; j = j + 1)
                    recv(data_buffer[j]);
            end
        join

        if (i != j)
            $display("ERROR: sent %d, received, %d", i, j);

        for (i = 0; i < DATA_COUNT; i = i + 1)
            if (data_buffer[i] != data_output[i]) begin
                $display("ERROR: item %d", i);
                $display("EXP: %b", data_output[i]);
                $display("GOT: %b", data_buffer[i]);
                $finish;
            end

        $display("All tests succeeded");
        $finish;
    end
endmodule
