`timescale 1ns / 1ps

`include "ieee80211_defs.v"

module encoder
 #(parameter WIDTH = 24)
  (input aclk,
   input aresetn,

   input [WIDTH-1:0] s_axis_tdata,
   input [3:0] s_axis_tuser,
   input s_axis_tvalid,
   output s_axis_tready,
   input s_axis_tlast,

   output reg [2*WIDTH-1:0] m_axis_tdata,
   output [3:0] m_axis_tuser,
   output reg m_axis_tvalid,
   input m_axis_tready,
   output  m_axis_tlast);

  // Constraint length determined from the generator polynomial
  localparam HISTSIZE = 6;

  reg [HISTSIZE-1:0] history = 0;
  reg [WIDTH-1:0] tdata_int;

  wire [WIDTH-1:0] g0;
  wire [WIDTH-1:0] g1;

  wire axis_tready_int;
  wire axis_tlast_int;
  wire [3:0] axis_tuser_int;

  wire [WIDTH+HISTSIZE-1:0] operand;

  wire m_handshake = m_axis_tvalid && m_axis_tready;
  wire s_handshake = s_axis_tvalid && s_axis_tready;

  wire [2*WIDTH-1:0] hr;
  wire [2*WIDTH-1:0] tfr;
  wire [2*WIDTH-1:0] ttr;

  // Concatenate input data with history for the convolution
  assign operand = {tdata_int, history};

  genvar i;
  generate
    // For generator polynomials: g0 = 133, g1 = 171
    for (i = 0; i < WIDTH; i = i + 1) begin : gen_poly
      assign g0[i] = operand[i+6] ^ operand[i+4] ^ operand[i+3] ^ operand[i+1] ^ operand[i];
      assign g1[i] = g0[i] ^ operand[i+5] ^ operand[i+1];
    end
    // Generate the half rate output
    for (i = 0; i < 2*WIDTH-1; i = i + 2) begin : gen_half_rate
      assign hr[i]   = g0[i/2];
      assign hr[i+1] = g1[i/2];
    end
    // Generate the two-thirds rate output
    for (i = 0; i < 3*WIDTH/2-2; i = i + 3) begin : gen_two_thirds
      assign ttr[i]   = g0[i/3];
      assign ttr[i+1] = g1[i/3];
      assign ttr[i+2] = g0[i/3+1];
    end
    // Generate the three-fourths rate output
    for (i = 0; i < 4*WIDTH/3-3; i = i + 4) begin : gen_three_fourths
      assign tfr[i]   = g0[i-i/4];
      assign tfr[i+1] = g1[i-i/4];
      assign tfr[i+2] = g0[i-i/4+1];
      assign tfr[i+3] = g1[i-i/4+2];
    end
  endgenerate

  // Zero pad two-thirds and three-fourths rate outputs
  assign ttr[2*WIDTH-1:3*WIDTH/2] = 0;
  assign tfr[2*WIDTH-1:4*WIDTH/3] = 0;

  // We are ready whenever downstream is ready
  assign axis_tready_int = m_axis_tready;
  assign s_axis_tready = axis_tready_int;

  // Propagate tlast downstream
  assign axis_tlast_int = s_axis_tlast;
  assign m_axis_tlast = axis_tlast_int;

  // Propagate tuser downstream
  assign axis_tuser_int = s_axis_tuser;
  assign m_axis_tuser = axis_tuser_int;

  // Output mux
  always @*
    case (axis_tuser_int)
      `RATE_9M, `RATE_18M, `RATE_36M, `RATE_54M:
        m_axis_tdata = tfr;
      `RATE_48M:
        m_axis_tdata = ttr;
      default:
        m_axis_tdata = hr;
    endcase

  always @(posedge aclk)
    if (~aresetn)
      tdata_int <= 0;
    else if (s_handshake)
      tdata_int <= s_axis_tdata;

  always @(posedge aclk)
    if (~aresetn)
      m_axis_tvalid <= 1'b0;
    else begin
      if (s_handshake)
        m_axis_tvalid <= 1'b1;
      else if (m_handshake)
        m_axis_tvalid <= 1'b0;
    end

  always @(posedge aclk)
    if (~aresetn)
      history <= 0;
    else if (m_handshake)
      history <= tdata_int[WIDTH-1:WIDTH-HISTSIZE];

endmodule

