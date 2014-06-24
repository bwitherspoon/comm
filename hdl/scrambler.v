`timescale 1ns / 1ps

module scrambler
 #(parameter WIDTH = 32,
   parameter SEED = 7'b1111111)
  (input aclk,
   input aresetn,

   input [WIDTH-1:0] s_axis_tdata,
   input s_axis_tvalid,
   output s_axis_tready,
   input s_axis_tlast,

   output [WIDTH-1:0] m_axis_tdata,
   output m_axis_tvalid,
   input m_axis_tready,
   output  m_axis_tlast);

  // Constraint length determined from the polynomial
  // R(n-1) = lfsr[6] .. R(n-7) = lfsr[0]
  reg [6:0] lfsr = SEED;

  wire [WIDTH-1:0] fb;
  wire [WIDTH-1:0] axis_tdata_int;
  wire m_handshake = m_axis_tvalid && m_axis_tready;

  // For generator polynomial: s^7 + s^4 + 1
  genvar i;
  generate
    for (i = 0; i < WIDTH; i = i + 1) begin : gen_fb
      if (i < 4)
        assign fb[i] = lfsr[i+3] ^ lfsr[i];
      else if (i < 7)
        assign fb[i] = lfsr[i] ^ fb[i-4];
      else
        assign fb[i] = fb[i-7] ^ fb[i-4];
    end
  endgenerate

  fifo #(.WIDTH(WIDTH+1), .DEPTH(5)) fifo_int(
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata({s_axis_tlast, s_axis_tdata}),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .m_axis_tdata({m_axis_tlast, axis_tdata_int}),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready)
  );

  assign m_axis_tdata = axis_tdata_int ^ fb;

  always @(posedge aclk)
    if (~aresetn)
      lfsr <= SEED;
    else if (m_handshake)
      lfsr <= fb[WIDTH-1:WIDTH-7];

endmodule
