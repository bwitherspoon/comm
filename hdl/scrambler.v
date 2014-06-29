`timescale 1ns / 1ps

module scrambler
 #(parameter WIDTH = 32,
   parameter SEED = 7'b1111111)
  (input aclk,
   input aresetn,

   input [WIDTH-1:0] s_axis_tdata,
   input [3:0] s_axis_tuser,
   input s_axis_tvalid,
   output s_axis_tready,
   input s_axis_tlast,

   output reg [WIDTH-1:0] m_axis_tdata,
   output reg [3:0] m_axis_tuser,
   output reg m_axis_tvalid,
   input m_axis_tready,
   output reg m_axis_tlast);

  localparam TAIL_MASK = {{7{1'b0}}, {(WIDTH-7){1'b1}}};

  // We are ready whenever downstream is ready
  wire axis_tready_int = m_axis_tready;
  assign s_axis_tready = axis_tready_int;

  wire m_handshake = m_axis_tvalid && axis_tready_int;
  wire s_handshake = s_axis_tvalid && axis_tready_int;

  // LFSR with generator polynomial: s^7 + s^4 + 1
  // Note: R(n-1) = lfsr[6] .. R(n-7) = lfsr[0]
  reg [6:0] lfsr = SEED;
  wire [WIDTH-1:0] fb;

  genvar i;
  generate
    for (i = 0; i < WIDTH; i = i + 1) begin : gen_feedback
      if (i < 4)
        assign fb[i] = lfsr[i+3] ^ lfsr[i];
      else if (i < 7)
        assign fb[i] = lfsr[i] ^ fb[i-4];
      else
        assign fb[i] = fb[i-7] ^ fb[i-4];
    end
  endgenerate

  // AXI-Stream Interface
  always @(posedge aclk)
    if (~aresetn) begin
      m_axis_tdata <= {WIDTH{1'b0}};
      m_axis_tuser <= 4'h0;
      m_axis_tlast <= 1'b0;
      m_axis_tvalid <= 1'b0;
    end
    else if (s_handshake) begin
      if (s_axis_tlast)
        m_axis_tdata <= (s_axis_tdata ^ fb) & TAIL_MASK;
      else
        m_axis_tdata <= s_axis_tdata ^ fb;
      m_axis_tuser <= s_axis_tuser;
      m_axis_tlast <= s_axis_tlast;
      m_axis_tvalid <= 1'b1;
    end
    else if (m_handshake)
      m_axis_tvalid <= 1'b0;

  // LFSR
  always @(posedge aclk)
    if (~aresetn)
      lfsr <= SEED;
    else if (s_handshake)
      lfsr <= fb[WIDTH-1:WIDTH-7];

endmodule
