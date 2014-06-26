`timescale 1ns / 1ps

`include "ieee80211_defs.v"

module system
  #(parameter WIDTH = 24)
   (input aclk,
    input aresetn,

    input [WIDTH-1:0] s_axis_tdata,
    input s_axis_tvalid,
    output s_axis_tready,
    input s_axis_tlast,
    input [3:0] s_axis_tuser,

    output [2*WIDTH-1:0] m_axis_tdata,
    output m_axis_tvalid,
    input m_axis_tready,
    output m_axis_tlast,
    output [3:0] m_axis_tuser);

    localparam SEED = 7'b1011101;

    wire [WIDTH-1:0] s2e_tdata;
    wire s2e_tvalid;
    wire s2e_tready;
    wire s2e_tlast;
    //wire s2e_tuser;

    scrambler #(.WIDTH(WIDTH), .SEED(SEED)) scrambler_i(
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(s2e_tdata),
        .m_axis_tvalid(s2e_tvalid),
        .m_axis_tready(s2e_tready),
        .m_axis_tlast(s2e_tlast)
    );

    encoder #(.WIDTH(WIDTH)) encoder_i(
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tdata(s2e_tdata),
        .s_axis_tvalid(s2e_tvalid),
        .s_axis_tready(s2e_tready),
        .s_axis_tuser(`RATE_9M),
        .s_axis_tlast(s2e_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tuser(m_axis_tuser)
    );
endmodule
