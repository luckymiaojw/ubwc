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
        input   wire        i_rstn              ,

        output  wire        o_rst               ,
        output  reg         o_srst
    );

    reg     srst            ;

    assign  o_rst           = ~i_rstn   ;

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            srst        <= 1'b1 ;
        else
            srst        <= ~i_rstn  ;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            o_srst      <= 1'b1 ;
        else
            o_srst      <= srst ;
    end

endmodule
