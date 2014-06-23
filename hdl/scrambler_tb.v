`timescale 1ns / 1ps

module scrambler_tb;

  localparam CLOCKPERIOD = 20;
  localparam WIDTH = 24;
  localparam DATA_COUNT = 10;
  localparam SEQ_COUNT = 3;

  `include "axis_tasks.v"

  reg [WIDTH-1:0] data_input [DATA_COUNT-1:0];
  reg [WIDTH-1:0] data_output [DATA_COUNT-1:0];
  reg [WIDTH-1:0] seq_output [SEQ_COUNT-1:0];

  reg clk = 1;
  reg rst;

  reg [WIDTH-1:0] s_tdata;
  reg s_tvalid;
  wire s_tready;

  wire [WIDTH-1:0] m_tdata;
  wire m_tvalid;
  reg m_tready;

  integer i;

  scrambler #(.WIDTH(WIDTH), .SEED(7'b1011101)) dut(
    .aclk(clk),
    .aresetn(rst),
    .s_axis_tdata(s_tdata),
    .s_axis_tvalid(s_tvalid),
    .s_axis_tready(s_tready),
    .s_axis_tlast(1'b0),
    .m_axis_tdata(m_tdata),
    .m_axis_tvalid(m_tvalid),
    .m_axis_tready(m_tready),
    .m_axis_tlast()
  );

  always #(CLOCKPERIOD/2) clk <= ~clk;

  initial begin
    $readmemb("vectors/data_before_scrambling.txt", data_input, 0, DATA_COUNT-1);
    $readmemb("vectors/data_after_scrambling.txt", data_output, 0, DATA_COUNT-1);
    $dumpfile("scrambler.vcd");
    $dumpvars;
  end

  initial begin
    s_tvalid = 0;
    m_tready = 0;
    reset();

    $display("Starting scrambler sequence test...");
    for (i = 0; i < SEQ_COUNT; i = i + 1) begin
      tvalid_with_tready(0);
      if (m_tdata != seq_output[i]) begin
        $display("Failed scrambler sequence test %2d.", i);
        $display("EXP: %b", seq_output[i]);
        $display("OUT: %b", m_tdata);
        $finish;
      end
    end
    reset();

    $display("Starting DATA scrambling test...");
    for (i = 0; i < DATA_COUNT; i = i + 1) begin
      tvalid_with_tready(data_input[i]);
      if (m_tdata != data_output[i]) begin
        $display("Failed DATA scrambling test %2d.", i);
        $display("EXP: %b", data_output[i]);
        $display("OUT: %b", m_tdata);
        $finish;
      end
    end
    reset();

    $display("All tests succeeded.");
    $finish;
  end

endmodule
