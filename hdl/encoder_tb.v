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

  reg [WIDTH-1:0] s_tdata;
  reg [3:0] s_tuser = `RATE_6M;
  reg s_tvalid;
  wire s_tready;

  wire [2*WIDTH-1:0] m_tdata;
  wire m_tvalid;
  reg m_tready;

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
    .s_axis_tdata(s_tdata),
    .s_axis_tvalid(s_tvalid),
    .s_axis_tready(s_tready),
    .s_axis_tuser(s_tuser),
    .s_axis_tlast(1'b0),
    .m_axis_tdata(m_tdata),
    .m_axis_tvalid(m_tvalid),
    .m_axis_tready(m_tready),
    .m_axis_tlast()
  );

  always #(CLOCKPERIOD/2) clk <= ~clk;

  initial begin
    s_tvalid = 1'b0;
    m_tready = 1'b0;
    s_tuser = `RATE_6M;
    reset();

    $display("Starting SIGNAL tvalid before tready test...");
    tvalid_before_tready(SIGNAL_INPUT);
    if (m_tdata != SIGNAL_OUTPUT) begin
      $display("Failed SIGNAL tvalid before tready test.");
      $display("EXP: %b", SIGNAL_OUTPUT);
      $display("OUT: &b", m_tdata);
      $finish;
    end
    reset();

    $display("Starting SIGNAL tready before tvalid test...");
    tready_before_tvalid(SIGNAL_INPUT);
    if (m_tdata != SIGNAL_OUTPUT) begin
      $display("Failed SIGNAL tready before tvalid test.");
      $display("EXP: %b", SIGNAL_OUTPUT);
      $display("OUT: &b", m_tdata);
      $finish;
    end
    reset();

    $display("Starting SIGNAL tvalid with tready test...");
    tvalid_with_tready(SIGNAL_INPUT);
    if (m_tdata != SIGNAL_OUTPUT) begin
      $display("Failed SIGNAL tvalid with tready test.");
      $display("EXP: %b", SIGNAL_OUTPUT);
      $display("OUT: &b", m_tdata);
      $finish;
    end
    reset();

    $display("Starting DATA encoding test...");
    s_tuser = `RATE_9M;
    for (i = 0; i < DATA_COUNT; i = i + 1) begin
        tvalid_with_tready(data_input[i]);
        if (m_tdata != data_output[i]) begin
          $display("Failed DATA scrambling test %2d.", i);
          $display("EXP: %b", data_output[i]);
          $display("OUT: &b", m_tdata);
          $finish;
      end
    end
    reset();

    $display("All tests succeeded.");
    $finish;
  end

endmodule

