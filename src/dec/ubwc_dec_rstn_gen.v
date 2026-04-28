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
    input  wire i_axi_clk,
    input  wire i_axi_rstn,
    input  wire i_otf_clk,
    input  wire i_otf_rstn,
    output wire o_ctrl_rst_n,
    output wire o_sram_rst_n,
    output wire o_otf_rst_n
);

    wire       ctrl_rst_n_async = i_presetn & i_axi_rstn;
    wire       otf_rst_n_async  = i_presetn & i_axi_rstn & i_otf_rstn;
    reg  [1:0] ctrl_rst_n_sync;
    reg  [1:0] otf_rst_n_sync;

    always @(posedge i_axi_clk or negedge ctrl_rst_n_async) begin
        if (!ctrl_rst_n_async) begin
            ctrl_rst_n_sync <= 2'b00;
        end else begin
            ctrl_rst_n_sync <= {ctrl_rst_n_sync[0], 1'b1};
        end
    end

    always @(posedge i_otf_clk or negedge otf_rst_n_async) begin
        if (!otf_rst_n_async) begin
            otf_rst_n_sync <= 2'b00;
        end else begin
            otf_rst_n_sync <= {otf_rst_n_sync[0], 1'b1};
        end
    end

    assign o_ctrl_rst_n = ctrl_rst_n_sync[1];
    assign o_sram_rst_n = ctrl_rst_n_sync[1];
    assign o_otf_rst_n  = otf_rst_n_sync[1];

endmodule
