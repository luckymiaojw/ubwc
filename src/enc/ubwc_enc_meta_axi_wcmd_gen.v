//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-03-11  07:19:23
// Module Name       : ubwc_enc_meta_axi_wcmd_gen.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//      Revision 1.00 - File Created by        : MiaoJiawang
//      Description                            :
//
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module ubwc_enc_meta_axi_wcmd_gen
    #(
        parameter   AXI_AW          = 64,
        parameter   AXI_DW          = 256,
        parameter   AXI_LENW        = 8,
        parameter   AXI_IDW         = 6,
        parameter   META_DW         = 66,
        parameter   IN_FIFO_DEPTH   = 64,
        parameter   BEAT_FIFO_DEPTH = 32,
        parameter   PKT_FIFO_DEPTH  = 8,
        parameter   AXI_ID_VALUE    = 0
    )(
        input   wire                                i_aclk,
        input   wire                                i_aresetn,

        input   wire    [META_DW-1:0]               i_meta_data,
        input   wire                                i_meta_data_valid,
        output  wire                                o_meta_data_ready,

        input   wire    [AXI_AW-1:0]                i_meta_addr,
        input   wire                                i_meta_addr_valid,
        output  wire                                o_meta_addr_ready,

        output  wire    [AXI_IDW-1:0]               o_m_axi_awid,
        output  wire    [AXI_AW-1:0]                o_m_axi_awaddr,
        output  wire    [AXI_LENW-1:0]              o_m_axi_awlen,
        output  wire    [2:0]                       o_m_axi_awsize,
        output  wire    [1:0]                       o_m_axi_awburst,
        output  wire    [1:0]                       o_m_axi_awlock,
        output  wire    [3:0]                       o_m_axi_awcache,
        output  wire    [2:0]                       o_m_axi_awprot,
        output  wire                                o_m_axi_awvalid,
        input   wire                                i_m_axi_awready,

        output  wire    [AXI_DW-1:0]                o_m_axi_wdata,
        output  wire    [AXI_DW/8-1:0]              o_m_axi_wstrb,
        output  wire                                o_m_axi_wvalid,
        output  wire                                o_m_axi_wlast,
        input   wire                                i_m_axi_wready,

        input   wire    [AXI_IDW-1:0]               i_m_axi_bid,
        input   wire    [1:0]                       i_m_axi_bresp,
        input   wire                                i_m_axi_bvalid,
        output  wire                                o_m_axi_bready
    );

    localparam [2:0] AXI_SIZE_W = 3'($clog2(AXI_DW / 8));

    wire    [2          -1:0]       meta_w_lane_sel             ;

    assign  meta_w_lane_sel     = i_meta_data[64+:2];

    assign  o_m_axi_awid        = AXI_ID_VALUE[AXI_IDW-1:0] ;
    assign  o_m_axi_awaddr      = {i_meta_addr[AXI_AW-1:5], 5'd0};
    assign  o_m_axi_awlen       = {AXI_LENW{1'b0}}          ;
    assign  o_m_axi_awsize      = AXI_SIZE_W                ;
    assign  o_m_axi_awburst     = 2'b01                     ;
    assign  o_m_axi_awlock      = 2'b00                     ;
    assign  o_m_axi_awcache     = 4'b0011                   ;
    assign  o_m_axi_awprot      = 3'b000                    ;
    assign  o_m_axi_awvalid     = i_meta_addr_valid         ;
    assign  o_meta_addr_ready   = i_m_axi_awready           ;

    assign  o_m_axi_wdata       = {4{i_meta_data[0+:64]}}   ;

    assign  o_m_axi_wstrb       = (meta_w_lane_sel == 2'd0) ? 32'h000000ff :
                                  (meta_w_lane_sel == 2'd1) ? 32'h0000ff00 :
                                  (meta_w_lane_sel == 2'd2) ? 32'h00ff0000 :
                                                              32'hff000000 ;
    assign  o_m_axi_wvalid      = i_meta_data_valid         ;
    assign  o_m_axi_wlast       = i_meta_data_valid         ;
    assign  o_meta_data_ready   = i_m_axi_wready            ;

    assign  o_m_axi_bready      = 1'b1                      ;

endmodule
