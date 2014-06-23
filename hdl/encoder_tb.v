`timescale 1ns / 1ps

`include "ieee80211_defs.v"

module encoder_tb;

  localparam WIDTH = 24;
  localparam CLOCKPERIOD = 20;

  // Half rate test vectors
  localparam H_INPUT = 24'h000c8d;
  localparam H_EXPECTED = 48'h000e7c40858b;
  localparam TF_COUNT = 10;

  // Three fourths rate test vectors
  reg [WIDTH-1:0] tf_input [TF_COUNT-1:0];
  reg [4*WIDTH/3.0-1:0] tf_gold [TF_COUNT-1:0];

  reg clk = 1;
  reg rst;

  reg [WIDTH-1:0] s_tdata;
  reg [3:0] s_tuser = `RATE_6M;
  reg s_tvalid;
  wire s_tready;

  wire [(2*WIDTH)-1:0] m_tdata;
  wire m_tvalid;
  reg m_tready;

  integer i;

  task reset;
      begin
        rst = 0;
        repeat (2) @(posedge clk);
        rst = 1;
      end
  endtask

  task tvalid_before_tready(input [WIDTH:0] data);
      begin
        #(CLOCKPERIOD/4) s_tdata = data;
        s_tvalid = 1'b1;
        #(CLOCKPERIOD) m_tready = 1'b1;
        #(CLOCKPERIOD*3/4+1) s_tvalid = 1'b0;
        m_tready = 1'b0;
      end
  endtask

  task tready_before_tvalid(input [WIDTH:0] data);
      begin
        #(CLOCKPERIOD/4) m_tready = 1'b1;
        #(CLOCKPERIOD) s_tdata = data;
        s_tvalid = 1'b1;
        #(CLOCKPERIOD*3/4+1) s_tvalid = 1'b0;
        m_tready = 1'b0;
      end
  endtask

  task tvalid_with_tready(input [WIDTH:0] data);
    begin
      #(CLOCKPERIOD/2) m_tready = 1'b1;
      s_tdata = data;
      s_tvalid = 1'b1;
      #(CLOCKPERIOD/2+1) s_tvalid = 1'b0;
      m_tready = 1'b0;
    end
  endtask

  task validate(input [2*WIDTH-1:0] expected);
    begin
      if (m_tdata != expected) begin
        $display("TEST FAILED at %t\n", $realtime);
        $display("EXP: %b\nOUT: %b\n", expected, m_tdata);
        //$finish;
      end
    end
  endtask

  // Load test vectors
  initial begin
    $readmemb("vectors/data_after_scrambling.txt", tf_input, 0, TF_COUNT-1);
    $readmemb("vectors/data_after_encoding.txt", tf_gold, 0, TF_COUNT-1);
    $dumpfile("encoder.vcd");
    $dumpvars;
  end

  encoder dut(
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
    $timeformat(-12, 2, " ps", 4);
    s_tvalid = 1'b0;
    m_tready = 1'b0;
    s_tuser = `RATE_6M;
    reset();

    $display("Starting half rate tvalid before tready...");
    tvalid_before_tready(H_INPUT);
    validate(H_EXPECTED);
    reset();

    $display("Starting half rate tready before tvalid...");
    tready_before_tvalid(H_INPUT);
    validate(H_EXPECTED);
    reset();

    $display("Starting half rate tvalid with tready...");
    tvalid_with_tready(H_INPUT);
    validate(H_EXPECTED);
    reset();

    $display("Starting three-fourths rate streaming...");
    s_tuser = `RATE_9M;
    for (i = 0; i < TF_COUNT; i = i + 1) begin
        $display("Iteration: %2d", i);
        tvalid_with_tready(tf_input[i]);
        validate(tf_gold[i]);
    end
    reset();

    #100 $finish;
  end

endmodule

