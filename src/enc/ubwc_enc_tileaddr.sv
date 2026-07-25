//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-03-24  00:02:23
// Module Name       : ubwc_tileaddr.sv
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							:
//
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module ubwc_enc_tile_addr
    #(
        parameter                                       TH_DW                           = 13,
        parameter                                       TW_DW                           = 8
    )(
        input   wire                                        i_clk                           ,
        input   wire                                        i_rstn                          ,

        input   wire                                        i_lvl1_bank_swizzle_en          ,
        input   wire                                        i_lvl2_bank_swizzle_en          ,
        input   wire                                        i_lvl3_bank_swizzle_en          ,
        input   wire    [5                   -1 :0]         i_highest_bank_bit              ,
        input   wire                                        i_bank_spread_en                ,

        input   wire                                        i_4line_format                  ,
        input   wire                                        i_is_lossy_rgba_2_1_format      ,
        input   wire    [12                  -1 :0]         i_tile_pitch                    ,

        input   wire    [64                  -1 :0]         i_y_base_offset_addr            ,
        input   wire    [64                  -1 :0]         i_uv_base_offset_addr           ,
        input   wire                                        i_addr_cfg_valid                ,

        input   wire    [TH_DW               -1 :0]         i_ycoord                        ,
        input   wire    [TW_DW               -1 :0]         i_xcoord                        ,
        input   wire    [5                   -1 :0]         i_format                        ,
        input   wire    [4                   -1 :0]         i_fcnt                          ,

        input   wire                                        i_co_valid                      ,
        output  wire                                        o_co_ready                      ,
        input   wire    [3                   -1 :0]         i_co_alen                       ,

        output  reg     [28                  -1 :0]         o_tile_addr                     ,
        output  reg     [3                   -1 :0]         o_tile_alen                     ,
        output  reg     [4                   -1 :0]         o_tile_fcnt                     ,
        output  reg                                         o_tile_addr_vld
    );

    localparam  [4                      :0]         FMT_NV12_UV                     = 5'd9;
    localparam  [4                      :0]         FMT_NV16_UV                     = 5'd11;
    localparam  [4                      :0]         FMT_NV16_10_UV                  = 5'd13;
    localparam  [4                      :0]         FMT_P010_UV                     = 5'd15;
    localparam  [4                      :0]         FMT_RGBA8888                    = 5'd0;

    wire        [12                     :0]         active_ycoord                   ;
    wire        [27                     :0]         active_xcoord                   ;
    wire        [4                      :0]         active_format                   ;
    wire                                            active_is_uv_plane              ;
    wire        [63                     :0]         active_y_base_offset_addr       ;
    wire        [63                     :0]         active_uv_base_offset_addr      ;
    wire        [27                     :0]         active_base_offset_addr         ;

    wire        [10                     :0]         macrotile_y                     ;
    wire        [10                     :0]         macrotile_x                     ;
    wire        [3                      :0]         macrotile                       ;
    wire        [16                     :0]         macrotile_pitch                 ;
    wire        [27                     :0]         product                         ;
    wire        [27                     :0]         product_term0                   ;
    wire        [27                     :0]         product_term1                   ;
    wire        [27                     :0]         product_term2                   ;
    wire        [27                     :0]         product_term3                   ;
    wire        [27                     :0]         product_term4                   ;
    wire        [27                     :0]         product_term5                   ;
    wire        [27                     :0]         product_term6                   ;
    wire        [27                     :0]         product_term7                   ;
    wire        [27                     :0]         product_term8                   ;
    wire        [27                     :0]         product_term9                   ;
    wire        [27                     :0]         product_term10                  ;
    wire        [27                     :0]         add_x                           ;
    wire        [7                      :0]         add_inter_tile                  ;
    wire        [27                     :0]         add_before_bs                   ;
    wire        [7                      :0]         super_pixel_size                ;
    wire        [15                     :0]         surface_pitch                   ;
    wire        [19                     :0]         surface_pitch_x16               ;
    wire        [12                     :0]         ycoord_int_sel                  ;
    wire        [15                     :0]         line_ycoord_int                 ;
    wire        [3                      :0]         add_y_2_1_shift                 ;
    wire        [27                     :0]         swizzle_addr                    ;
    wire        [27                     :0]         tile_addr_calc                  ;
    wire        [27                     :0]         tile_addr_with_base             ;
    wire                                            lossy_rgba_2_1_active           ;
    wire                                            small_payload_bank_spread_en    ;

    reg         [31                     :0]         swizzle_xor                     ;

    assign o_co_ready                   = i_addr_cfg_valid;
    assign active_format                = i_format;
    assign active_ycoord                = {{(13-TH_DW){1'b0}}, i_ycoord};
    assign active_xcoord                = {{(28-TW_DW){1'b0}}, i_xcoord};
    assign active_is_uv_plane           = (active_format == FMT_NV12_UV)    ||
                                          (active_format == FMT_NV16_UV)    ||
                                          (active_format == FMT_NV16_10_UV) ||
                                          (active_format == FMT_P010_UV);
    assign active_y_base_offset_addr    = i_y_base_offset_addr;
    assign active_uv_base_offset_addr   = i_uv_base_offset_addr;
    assign active_base_offset_addr      = active_is_uv_plane ? active_uv_base_offset_addr[31:4] :
                                                               active_y_base_offset_addr[31:4];
    assign lossy_rgba_2_1_active        = i_is_lossy_rgba_2_1_format && (active_format == FMT_RGBA8888);
    assign ycoord_int_sel               = i_is_lossy_rgba_2_1_format ? {1'b0, active_ycoord[12:1]} : active_ycoord;
    assign line_ycoord_int              = i_4line_format ? (16'(ycoord_int_sel) << 2) : (16'(ycoord_int_sel) << 3);
    assign macrotile_y                  = ycoord_int_sel[12:2];
    assign macrotile_x                  = active_xcoord[12:2];
    assign macrotile[3:0]               = {
                                           active_xcoord[1],
                                           active_xcoord[0]^ycoord_int_sel[0]^active_xcoord[2]^ycoord_int_sel[2],
                                           active_xcoord[1]^active_xcoord[0]^ycoord_int_sel[1]^ycoord_int_sel[0],
                                           active_xcoord[0]^ycoord_int_sel[1]
                                           };
    assign macrotile_pitch              = i_4line_format ? {1'd0, i_tile_pitch, 4'd0} : {i_tile_pitch, 5'd0};
    assign product_term0                = macrotile_y[0]  ? {11'd0, macrotile_pitch}        : 28'd0;
    assign product_term1                = macrotile_y[1]  ? {10'd0, macrotile_pitch, 1'd0}  : 28'd0;
    assign product_term2                = macrotile_y[2]  ? {9'd0,  macrotile_pitch, 2'd0}  : 28'd0;
    assign product_term3                = macrotile_y[3]  ? {8'd0,  macrotile_pitch, 3'd0}  : 28'd0;
    assign product_term4                = macrotile_y[4]  ? {7'd0,  macrotile_pitch, 4'd0}  : 28'd0;
    assign product_term5                = macrotile_y[5]  ? {6'd0,  macrotile_pitch, 5'd0}  : 28'd0;
    assign product_term6                = macrotile_y[6]  ? {5'd0,  macrotile_pitch, 6'd0}  : 28'd0;
    assign product_term7                = macrotile_y[7]  ? {4'd0,  macrotile_pitch, 7'd0}  : 28'd0;
    assign product_term8                = macrotile_y[8]  ? {3'd0,  macrotile_pitch, 8'd0}  : 28'd0;
    assign product_term9                = macrotile_y[9]  ? {2'd0,  macrotile_pitch, 9'd0}  : 28'd0;
    assign product_term10               = macrotile_y[10] ? {1'd0,  macrotile_pitch, 10'd0} : 28'd0;
    assign product                      = product_term0 + product_term1 + product_term2 +
                                          product_term3 + product_term4 + product_term5 +
                                          product_term6 + product_term7 + product_term8 +
                                          product_term9 + product_term10;
    assign add_x                        = {9'd0, macrotile_x, 8'd0};
    assign add_inter_tile               = {macrotile, 4'd0};
    assign add_y_2_1_shift              = i_is_lossy_rgba_2_1_format ? {active_ycoord[0], 3'b0} : 4'b0;
    assign add_before_bs                = product + add_x + {20'd0, add_inter_tile} + {24'd0, add_y_2_1_shift};
    assign super_pixel_size             = i_4line_format ? 8'd32 : 8'd8;
    assign surface_pitch                = {i_tile_pitch, 4'd0};
    assign surface_pitch_x16            = {surface_pitch, 4'd0};
    assign swizzle_addr                 = add_before_bs ^ swizzle_xor[31:4];
    assign small_payload_bank_spread_en = i_bank_spread_en &&
                                          !lossy_rgba_2_1_active &&
                                          (i_co_alen <= 3'd3);
    assign tile_addr_calc               = small_payload_bank_spread_en ?
                                          (swizzle_addr + {24'd0, swizzle_addr[5] ^ swizzle_addr[4], 3'd0}) :
                                                                         swizzle_addr;
    assign tile_addr_with_base          = tile_addr_calc + active_base_offset_addr;

    always_comb begin
        swizzle_xor = 32'd0;
        case (i_highest_bank_bit)
            5'd13: begin
                if (!(|surface_pitch_x16[11:0]) && (super_pixel_size <= 8'd128)) begin
                    if (i_lvl1_bank_swizzle_en && (super_pixel_size >= 8'd32))
                        swizzle_xor[11] = line_ycoord_int[3] ^ active_xcoord[1];
                end
                if (i_lvl2_bank_swizzle_en && !(|surface_pitch_x16[12:0]))
                    swizzle_xor[12] = (super_pixel_size == 8'd8) ? line_ycoord_int[5] : line_ycoord_int[4];
                if (i_lvl3_bank_swizzle_en && !(|surface_pitch_x16[13:0]))
                    swizzle_xor[13] = (super_pixel_size == 8'd8) ? line_ycoord_int[6] : line_ycoord_int[5];
            end
            5'd14: begin
                if (!(|surface_pitch_x16[12:0]) && (super_pixel_size <= 8'd128)) begin
                    if (i_lvl1_bank_swizzle_en && (super_pixel_size >= 8'd32))
                        swizzle_xor[12] = line_ycoord_int[3] ^ active_xcoord[1];
                end
                if (i_lvl2_bank_swizzle_en && !(|surface_pitch_x16[13:0]))
                    swizzle_xor[13] = (super_pixel_size == 8'd8) ? line_ycoord_int[5] : line_ycoord_int[4];
                if (i_lvl3_bank_swizzle_en && !(|surface_pitch_x16[14:0]))
                    swizzle_xor[14] = (super_pixel_size == 8'd8) ? line_ycoord_int[6] : line_ycoord_int[5];
            end
            5'd15: begin
                if (!(|surface_pitch_x16[13:0]) && (super_pixel_size <= 8'd128)) begin
                    if (i_lvl1_bank_swizzle_en && (super_pixel_size >= 8'd32))
                        swizzle_xor[13] = line_ycoord_int[3] ^ active_xcoord[1];
                end
                if (i_lvl2_bank_swizzle_en && !(|surface_pitch_x16[14:0]))
                    swizzle_xor[14] = (super_pixel_size == 8'd8) ? line_ycoord_int[5] : line_ycoord_int[4];
                if (i_lvl3_bank_swizzle_en && !(|surface_pitch_x16[15:0]))
                    swizzle_xor[15] = (super_pixel_size == 8'd8) ? line_ycoord_int[6] : line_ycoord_int[5];
            end
            5'd16: begin
                if (!(|surface_pitch_x16[14:0]) && (super_pixel_size <= 8'd128)) begin
                    if (i_lvl1_bank_swizzle_en && (super_pixel_size >= 8'd32))
                        swizzle_xor[14] = line_ycoord_int[3] ^ active_xcoord[1];
                end
                if (i_lvl2_bank_swizzle_en && !(|surface_pitch_x16[15:0]))
                    swizzle_xor[15] = (super_pixel_size == 8'd8) ? line_ycoord_int[5] : line_ycoord_int[4];
                if (i_lvl3_bank_swizzle_en && !(|surface_pitch_x16[16:0]))
                    swizzle_xor[16] = (super_pixel_size == 8'd8) ? line_ycoord_int[6] : line_ycoord_int[5];
            end
            5'd17: begin
                if (!(|surface_pitch_x16[15:0]) && (super_pixel_size <= 8'd128)) begin
                    if (i_lvl1_bank_swizzle_en && (super_pixel_size >= 8'd32))
                        swizzle_xor[15] = line_ycoord_int[3] ^ active_xcoord[1];
                end
                if (i_lvl2_bank_swizzle_en && !(|surface_pitch_x16[16:0]))
                    swizzle_xor[16] = (super_pixel_size == 8'd8) ? line_ycoord_int[5] : line_ycoord_int[4];
                if (i_lvl3_bank_swizzle_en && !(|surface_pitch_x16[17:0]))
                    swizzle_xor[17] = (super_pixel_size == 8'd8) ? line_ycoord_int[6] : line_ycoord_int[5];
            end
            5'd18: begin
                if (!(|surface_pitch_x16[16:0]) && (super_pixel_size <= 8'd128)) begin
                    if (i_lvl1_bank_swizzle_en && (super_pixel_size >= 8'd32))
                        swizzle_xor[16] = line_ycoord_int[3] ^ active_xcoord[1];
                end
                if (i_lvl2_bank_swizzle_en && !(|surface_pitch_x16[17:0]))
                    swizzle_xor[17] = (super_pixel_size == 8'd8) ? line_ycoord_int[5] : line_ycoord_int[4];
                if (i_lvl3_bank_swizzle_en && !(|surface_pitch_x16[18:0]))
                    swizzle_xor[18] = (super_pixel_size == 8'd8) ? line_ycoord_int[6] : line_ycoord_int[5];
            end
            5'd19: begin
                if (!(|surface_pitch_x16[17:0]) && (super_pixel_size <= 8'd128)) begin
                    if (i_lvl1_bank_swizzle_en && (super_pixel_size >= 8'd32))
                        swizzle_xor[17] = line_ycoord_int[3] ^ active_xcoord[1];
                end
                if (i_lvl2_bank_swizzle_en && !(|surface_pitch_x16[18:0]))
                    swizzle_xor[18] = (super_pixel_size == 8'd8) ? line_ycoord_int[5] : line_ycoord_int[4];
                if (i_lvl3_bank_swizzle_en && !(|surface_pitch_x16[19:0]))
                    swizzle_xor[19] = (super_pixel_size == 8'd8) ? line_ycoord_int[6] : line_ycoord_int[5];
            end
            default: swizzle_xor = 32'd0;
        endcase
    end

    // Match ubwc_tileaddr.v / ubwc_demo.cpp:
    // bank spread only applies to <=128B compressed payload tiles, and is disabled
    // for RGBA8888 2:1 lossy vertical packing.

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            o_tile_addr <= '0;
        else if (i_co_valid && i_addr_cfg_valid)
            o_tile_addr <= tile_addr_with_base;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            o_tile_alen <= '0;
        else if (i_co_valid && i_addr_cfg_valid)
            o_tile_alen <= i_co_alen;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            o_tile_fcnt <= '0;
        else if (i_co_valid && i_addr_cfg_valid)
            o_tile_fcnt <= i_fcnt;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            o_tile_addr_vld <= 1'b0;
        else
            o_tile_addr_vld <= i_co_valid && i_addr_cfg_valid;
    end

endmodule
