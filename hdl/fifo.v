`timescale 1ns / 1ps

module fifo
  #(parameter WIDTH = 32,
    parameter DEPTH = 5)
   (input aclk,
    input aresetn,

    input [WIDTH-1:0] s_axis_tdata,
    input s_axis_tvalid,
    output s_axis_tready,

    output [WIDTH-1:0] m_axis_tdata,
    output m_axis_tvalid,
    input m_axis_tready);

    localparam FULL = 2'b11;
    localparam READY = 2'b01;
    localparam EMPTY = 2'b00;

    reg [1:0] state = EMPTY;

    wire s_handshake = s_axis_tvalid & s_axis_tready;
    wire m_handshake = m_axis_tvalid & m_axis_tready;

    assign s_axis_tready = state != FULL;
    assign m_axis_tvalid = state != EMPTY;

    reg [DEPTH-1:0] addr;
    reg [2**DEPTH-1:0] dsr [WIDTH-1:0];

    integer i;
    initial
        for (i = 0; i < WIDTH; i = i + 1)
            dsr[i] = {2**DEPTH{1'b0}};

    // Dynamic shift register using inferred SRL
    genvar j;
    for (j = 0; j < WIDTH; j = j + 1) begin : gen_dsr
        always @(posedge aclk)
            if (s_handshake)
                dsr[j] <= {dsr[j][2**DEPTH-2:0], s_axis_tdata[j]};

        assign m_axis_tdata[j] = dsr[j][addr];
    end

    // AXI-Stream interface
    always @(posedge aclk)
        if (~aresetn) begin
            addr <= 0;
            state <= EMPTY;
        end else
            case (state)
                EMPTY :
                    if (s_handshake)
                        state <= READY;
                READY :
                    if (m_handshake & ~s_handshake)
                        if (addr == 0)
                            state <= EMPTY;
                        else
                            addr <= addr - 1;
                    else if (s_handshake & ~m_handshake) begin
                        if (addr == 2**DEPTH - 2)
                            state <= FULL;
                        addr <= addr + 1;
                    end
                FULL :
                    if (m_handshake) begin
                        state <= READY;
                        addr <= addr - 1;
                    end
            endcase
endmodule

