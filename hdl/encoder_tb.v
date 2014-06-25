`timescale 1ns / 1ps

`include "ieee80211_defs.v"

module encoder_tb;

  localparam WIDTH = 24;
  localparam CLOCKPERIOD = 20;
  localparam DATA_COUNT = 10;

  `include "axis_tasks.v"

  // Half rate test vectors
  localparam SIGNAL_INPUT = 24'h000c8d;
  localparam SIGNAL_OUTPUT = 48'h000e7c40858b;

  // Three fourths rate DATA test vectors
  reg [WIDTH-1:0] data_input [DATA_COUNT-1:0];
  reg [4*WIDTH/3.0-1:0] data_output [DATA_COUNT-1:0];

  reg clk = 1;
  reg rst;

  reg [WIDTH-1:0] i_tdata;
  reg [3:0] i_tuser = `RATE_6M;
  reg i_tvalid;
  wire i_tready;
  reg i_tlast;

  wire [2*WIDTH-1:0] o_tdata;
  wire [3:0] o_tuser;
  wire o_tvalid;
  reg o_tready;
  wire o_tlast;

  integer i;

  // Load test vectors
  initial begin
    $readmemb("vectors/data_after_scrambling.txt", data_input, 0, DATA_COUNT-1);
    $readmemb("vectors/data_after_encoding.txt", data_output, 0, DATA_COUNT-1);
    $dumpfile("encoder.vcd");
    $dumpvars;
  end

  encoder #(.WIDTH(WIDTH)) dut(
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
    // Initialize and reset
    i_tuser = 0;
    i_tvalid = 0;
    i_tlast = 0;
    o_tready = 0;
    reset();

    $display("Starting SIGNAL encoding test...");
    i_tuser = `RATE_6M;
    o_tready = 1;
    send(SIGNAL_INPUT);
    if (o_tdata != SIGNAL_OUTPUT) begin
      $display("Failed SIGNAL encoding test.");
      $display("EXP: %b", SIGNAL_OUTPUT);
      $display("GOT: %b", o_tdata);
      $finish;
    end
    reset();

    $display("Starting DATA encoding test...");
    i_tuser = `RATE_9M;
    i_tlast = 1;
    for (i = 0; i < DATA_COUNT; i = i + 1) begin
        send(data_input[i]);
        if (o_tdata != data_output[i]) begin
          $display("Failed DATA encoding test %1d.", i);
          $display("EXP: %b", data_output[i]);
          $display("GOT: %b", o_tdata);
          $finish;
      end
    end
    reset();

    $display("All tests succeeded.");
    $finish;
  end

endmodule

