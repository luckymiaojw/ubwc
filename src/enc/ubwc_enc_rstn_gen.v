//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : OpenAI Codex
// Module Name       : ubwc_enc_rstn_gen.v
// Description       : Reset synchronizer for the UBWC encode wrapper clocks.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_enc_rstn_gen (
    input  wire i_rstn,
    input  wire i_clk,
    input  wire i_otf_clk,
    output wire o_core_rst_n,
    output wire o_otf_rst_n,
    output wire o_core_rst,
    output reg  o_core_srst
);

    reg  [1:0] core_rst_n_sync;
    reg  [1:0] otf_rst_n_sync;
    reg        core_srst_d;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            core_rst_n_sync <= 2'b00;
        end else begin
            core_rst_n_sync <= {core_rst_n_sync[0], 1'b1};
        end
    end

    always @(posedge i_otf_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            otf_rst_n_sync <= 2'b00;
        end else begin
            otf_rst_n_sync <= {otf_rst_n_sync[0], 1'b1};
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            core_srst_d <= 1'b1;
            o_core_srst <= 1'b1;
        end else begin
            core_srst_d <= ~core_rst_n_sync[1];
            o_core_srst <= core_srst_d;
        end
    end

    assign o_core_rst_n = core_rst_n_sync[1];
    assign o_otf_rst_n  = otf_rst_n_sync[1];
    assign o_core_rst   = ~i_rstn;

endmodule
