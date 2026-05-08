//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-03-11  06:48:35
// Module Name       : ubwc_enc_rst_mdl.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
//  
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module ubwc_enc_rst_mdl
    (
        input   wire        i_clk               ,
        input   wire        i_otf_clk           ,
        input   wire        i_rstn              ,

        output  wire        o_rst               ,
        output  wire        o_rst_n_sys         ,
        output  wire        o_rst_n_otf         ,
        output  reg         o_srst
    );

    (* async_reg = "true" *) reg rst_n_sys_meta;
    (* async_reg = "true" *) reg rst_n_sys_sync;
    (* async_reg = "true" *) reg rst_n_otf_meta;
    (* async_reg = "true" *) reg rst_n_otf_sync;
    reg srst_d;

    assign  o_rst           = ~i_rstn   ;
    assign  o_rst_n_sys     = rst_n_sys_sync;
    assign  o_rst_n_otf     = rst_n_otf_sync;

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            rst_n_sys_meta <= 1'b0;
        else
            rst_n_sys_meta <= 1'b1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            rst_n_sys_sync <= 1'b0;
        else
            rst_n_sys_sync <= rst_n_sys_meta;
    end

    always @(posedge i_otf_clk or negedge i_rstn) begin
        if(~i_rstn)
            rst_n_otf_meta <= 1'b0;
        else
            rst_n_otf_meta <= 1'b1;
    end

    always @(posedge i_otf_clk or negedge i_rstn) begin
        if(~i_rstn)
            rst_n_otf_sync <= 1'b0;
        else
            rst_n_otf_sync <= rst_n_otf_meta;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            srst_d      <= 1'b1 ;
        else
            srst_d      <= ~rst_n_sys_sync;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            o_srst      <= 1'b1 ;
        else
            o_srst      <= srst_d ;
    end

endmodule
