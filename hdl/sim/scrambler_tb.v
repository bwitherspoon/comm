`timescale 1ns / 1ps

module scrambler_tb;

  `include "axis_tasks.v"

  localparam WIDTH = 24;
  localparam SEND_WIDTH = WIDTH;
  localparam RECV_WIDTH = WIDTH;

  localparam CLOCKPERIOD = 20;
  localparam DATA_COUNT = 10;
  localparam SEQ_COUNT = 3;

  reg [WIDTH-1:0] data_input [DATA_COUNT-1:0];
  reg [WIDTH-1:0] data_output [DATA_COUNT-1:0];
  reg [WIDTH-1:0] seq_output [SEQ_COUNT-1:0];

  reg clk = 1;
  reg rst;

  reg [WIDTH-1:0] i_tdata;
  reg i_tvalid;
  wire i_tready;

  wire [WIDTH-1:0] o_tdata;
  wire o_tvalid;
  reg o_tready;

  integer i;

  scrambler #(.WIDTH(WIDTH), .SEED(7'b1011101)) dut(
    .aclk(clk),
    .aresetn(rst),
    .s_axis_tdata(i_tdata),
    .s_axis_tvalid(i_tvalid),
    .s_axis_tready(i_tready),
    .s_axis_tlast(1'b0),
    .m_axis_tdata(o_tdata),
    .m_axis_tvalid(o_tvalid),
    .m_axis_tready(o_tready),
    .m_axis_tlast()
  );

  always #(CLOCKPERIOD/2) clk <= ~clk;

  initial begin
    $readmemb("scrambler_sequence_for_seed_1011101.txt", seq_output, 0, SEQ_COUNT-1);
    $readmemb("data_before_scrambling.txt", data_input, 0, DATA_COUNT-1);
    $readmemb("data_after_scrambling.txt", data_output, 0, DATA_COUNT-1);
    $dumpfile("scrambler.vcd");
    $dumpvars;
  end

  initial begin
    i_tvalid = 0;
    o_tready = 0;
    reset();

    $display("Starting scrambler sequence test...");
    o_tready = 1;
    for (i = 0; i < SEQ_COUNT; i = i + 1) begin
      send({WIDTH{1'b0}});
      if (o_tdata != seq_output[i]) begin
        $display("Failed scrambler sequence test %1d:", i);
        $display("EXP: %b", seq_output[i]);
        $display("OUT: %b", o_tdata);
        $finish;
      end
    end
    reset();

    $display("Starting DATA scrambling test...");
    for (i = 0; i < DATA_COUNT; i = i + 1) begin
      send(data_input[i]);
      if (o_tdata != data_output[i]) begin
        $display("Failed DATA scrambling test %1d:", i);
        $display("EXP: %b", data_output[i]);
        $display("OUT: %b", o_tdata);
        $finish;
      end
    end
    reset();

    $display("All tests succeeded.");
    $finish;
  end

endmodule
