//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : OpenAI Codex
// Module Name       : ubwc_dec_rstn_gen.v
// Description       : Reset combiner for the UBWC decode wrapper clocks.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_dec_rstn_gen (
    input  wire i_presetn,
    input  wire i_axi_rstn,
    input  wire i_otf_rstn,
    output wire o_ctrl_rst_n,
    output wire o_otf_rst_n
);

    assign o_ctrl_rst_n = i_presetn & i_axi_rstn;
    assign o_otf_rst_n  = i_presetn & i_axi_rstn & i_otf_rstn;

endmodule
