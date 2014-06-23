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
   output reg m_axis_tvalid,
   input m_axis_tready,
   output  m_axis_tlast);

  // Constraint length determined from the polynomial
  // R(n-1) = lfsr[6] .. R(n-7) = lfsr[0]
  reg [6:0] lfsr = SEED;

  reg [WIDTH-1:0] tdata_int;

  wire [WIDTH-1:0] fb;

  wire axis_tready_int;
  wire axis_tlast_int;

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

  // We are ready whenever downstream is ready
  assign axis_tready_int = m_axis_tready;
  assign s_axis_tready = axis_tready_int;

  // Propagate tlast downstream
  assign axis_tlast_int = s_axis_tlast;
  assign m_axis_tlast = axis_tlast_int;

  assign m_axis_tdata = tdata_int ^ fb;

  assign m_handshake = m_axis_tvalid && m_axis_tready;
  assign s_handshake = s_axis_tvalid && s_axis_tready;

  always @(posedge aclk)
    if (~aresetn)
      tdata_int <= 0;
    else if (s_handshake)
      tdata_int <= s_axis_tdata;

  always @(posedge aclk)
    if (~aresetn)
      m_axis_tvalid <= 0;
    else begin
      if (s_handshake)
        m_axis_tvalid <= 1;
      else if (m_handshake)
        m_axis_tvalid <= 0;
    end

  always @(posedge aclk)
    if (~aresetn)
      lfsr <= SEED;
    else if (m_handshake)
      lfsr <= fb[WIDTH-1:WIDTH-7];

endmodule
