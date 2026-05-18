//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-03-28  17:28:11
// Design Name       :
// Module Name       : ubwc_dec_meta_get_cmd_gen.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							:
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_dec_meta_get_cmd_gen #(
    parameter                                       ADDR_WIDTH                      = 32,
    parameter                                       TW_DW                           = 16,
    parameter                                       TH_DW                           = 16
)(
    input   wire                                        clk                             ,
    input   wire                                        rst_n                           ,

    // --- Control and configuration interface ---
    input   wire                                        start                           ,
    input   wire    [3                      :0]         i_fcnt                          ,
    input   wire    [4                      :0]         base_format                     , // Frame-level format only
    input   wire    [ADDR_WIDTH          -1 :0]         meta_base_addr_rgba_y0          , // Start base address for RGBA or Y, fcnt[0] == 0
    input   wire    [ADDR_WIDTH          -1 :0]         meta_base_addr_uv0              , // Start base address for UV plane, fcnt[0] == 0
    input   wire    [ADDR_WIDTH          -1 :0]         meta_base_addr_rgba_y1          , // Start base address for RGBA or Y, fcnt[0] == 1
    input   wire    [ADDR_WIDTH          -1 :0]         meta_base_addr_uv1              , // Start base address for UV plane, fcnt[0] == 1
    input   wire    [TW_DW               -1 :0]         tile_x_numbers                  , // Image tile columns, one metadata byte per tile
    input   wire    [TH_DW               -1 :0]         tile_y_numbers                  , // Image tile rows, one metadata byte per tile

    // --- Metadata group interface ---
    output  wire                                        meta_grp_valid                  ,
    input   wire                                        meta_grp_ready                  ,
    output  wire    [ADDR_WIDTH          -1 :0]         meta_grp_addr                   ,
    output  wire    [4                      :0]         meta_format                     ,
    output  wire    [TW_DW               -1 :0]         meta_xcoord                     ,
    output  wire    [TH_DW               -1 :0]         meta_ycoord                     ,
    output  wire    [3                      :0]         meta_fcnt
);

    localparam  integer                             META_SUB_AW                     = TW_DW + 4;
    localparam  [TW_DW               -1 :0]         TILE_STEP_X                     = {{(TW_DW-4){1'b0}}, 4'd8};
    localparam  [4                      :0]         BASE_FMT_RGBA8888               = 5'b00000;
    localparam  [4                      :0]         BASE_FMT_RGBA1010102            = 5'b00001;
    localparam  [4                      :0]         BASE_FMT_YUV420_8               = 5'b00010;
    localparam  [4                      :0]         BASE_FMT_YUV420_10              = 5'b00011;
    localparam  [4                      :0]         META_FMT_RGBA8888               = 5'b00000;
    localparam  [4                      :0]         META_FMT_RGBA1010102            = 5'b00001;
    localparam  [4                      :0]         META_FMT_NV12_Y                 = 5'b01000;
    localparam  [4                      :0]         META_FMT_NV12_UV                = 5'b01001;
    localparam  [4                      :0]         META_FMT_P010_Y                 = 5'b01110;
    localparam  [4                      :0]         META_FMT_P010_UV                = 5'b01111;
    localparam  [1                      :0]         SCAN_PHASE_UV                   = 2'd0;
    localparam  [1                      :0]         SCAN_PHASE_YH                   = 2'd1;
    localparam  [1                      :0]         SCAN_PHASE_YL                   = 2'd2;

    wire                                            base_is_rgba                    ;
    wire                                            base_is_yuv420                  ;
    wire                                            base_supported                  ;
    wire                                            base_is_rgba101                 ;
    wire                                            base_is_p010                    ;
    wire        [15                     :0]         tile_x_numbers_ext              ;
    wire        [15                     :0]         meta_pitch_bytes                ;
    wire                                            frame_empty                     ;
    wire        [TW_DW                  :0]         xcoord_next_ext                 ;
    wire        [TH_DW                  :0]         y_row_next_ext                  ;
    wire        [TH_DW                  :0]         y_pair_next_ext                 ;
    wire        [TH_DW               -1 :0]         uv_row_next                     ;
    wire                                            y_pair_has_lower                ;
    wire                                            y_pair_last                     ;
    wire                                            scan_phase_is_uv                ;
    wire                                            scan_phase_is_yh                ;
    wire                                            scan_phase_is_yl                ;
    wire                                            x_row_last                      ;
    wire                                            y_row_last                      ;
    wire                                            issue_fire                      ;
    wire                                            current_is_uv                   ;
    wire        [TH_DW               -1 :0]         current_ycoord                  ;
    wire        [4                      :0]         current_format                  ;
    wire        [ADDR_WIDTH          -1 :0]         meta_base_addr                  ;
    wire        [ADDR_WIDTH          -1 :0]         meta_row_stride_bytes           ;
    wire        [ADDR_WIDTH          -1 :0]         meta_y_base_addr                ;
    wire        [META_SUB_AW         -1 :0]         meta_xy_offset_addr             ;
    wire        [ADDR_WIDTH          -1 :0]         meta_offset_addr                ;
    wire                                            row_end_fire                    ;
    wire                                            rgba_frame_done_fire            ;
    wire                                            rgba_y_advance_fire             ;
    wire                                            yuv_uv_row_fire                 ;
    wire                                            yuv_yh_row_fire                 ;
    wire                                            yuv_yl_row_fire                 ;
    wire                                            yuv_yh_frame_done_fire          ;
    wire                                            yuv_yl_frame_done_fire          ;
    wire                                            yuv_pair_advance_fire           ;
    wire        [TH_DW                  :0]         y_next_after_current_ext        ;
    wire                                            y_row_base_inc_fire             ;
    wire                                            uv_row_base_inc_fire            ;

    reg                                             scan_active                     ;
    reg         [1                      :0]         scan_phase                      ;
    reg         [TW_DW               -1 :0]         xcoord_cnt                      ;
    reg         [TH_DW               -1 :0]         y_row_cnt                       ;
    reg         [TH_DW               -1 :0]         uv_row_cnt                      ;
    reg         [3                      :0]         active_fcnt                     ;
    reg         [ADDR_WIDTH          -1 :0]         active_meta_base_addr_rgba_y    ;
    reg         [ADDR_WIDTH          -1 :0]         active_meta_base_addr_uv        ;
    reg         [ADDR_WIDTH          -1 :0]         active_meta_y_row_base_rgba_y   ;
    reg         [ADDR_WIDTH          -1 :0]         active_meta_y_row_base_uv       ;

    // base_format is a frame-level format selector.

    // meta_format is a tile-level format selector and keeps Y/UV split codes.

    assign base_is_rgba               = (base_format == BASE_FMT_RGBA8888) || (base_format == BASE_FMT_RGBA1010102);
    assign base_is_yuv420             = (base_format == BASE_FMT_YUV420_8) || (base_format == BASE_FMT_YUV420_10);
    assign base_supported             = base_is_rgba || base_is_yuv420;
    assign base_is_rgba101            = (base_format == BASE_FMT_RGBA1010102);
    assign base_is_p010               = (base_format == BASE_FMT_YUV420_10);
    assign tile_x_numbers_ext         = {{(16-TW_DW){1'b0}}, tile_x_numbers};
    assign meta_pitch_bytes           = (tile_x_numbers_ext + 16'd63) & 16'hffc0;
    assign frame_empty                = !base_supported ||
                                        (tile_x_numbers == {TW_DW{1'b0}}) ||
                                        (tile_y_numbers == {TH_DW{1'b0}});
    assign xcoord_next_ext            = {1'b0, xcoord_cnt} + {1'b0, TILE_STEP_X};
    assign y_row_next_ext             = {1'b0, y_row_cnt} + {{TH_DW{1'b0}}, 1'b1};
    assign y_pair_next_ext            = {1'b0, y_row_cnt} + {{(TH_DW-1){1'b0}}, 2'd2};
    assign uv_row_next                = uv_row_cnt + {{(TH_DW-1){1'b0}}, 1'b1};
    assign y_pair_has_lower           = (y_row_next_ext < {1'b0, tile_y_numbers});
    assign y_pair_last                = (y_pair_next_ext >= {1'b0, tile_y_numbers});
    assign scan_phase_is_uv           = (scan_phase == SCAN_PHASE_UV);
    assign scan_phase_is_yh           = (scan_phase == SCAN_PHASE_YH);
    assign scan_phase_is_yl           = (scan_phase == SCAN_PHASE_YL);
    assign x_row_last                 = (xcoord_next_ext >= {1'b0, tile_x_numbers});
    assign y_row_last                 = (y_row_next_ext >= {1'b0, tile_y_numbers});
    assign issue_fire                 = meta_grp_valid && meta_grp_ready;
    assign current_is_uv              = base_is_yuv420 && scan_phase_is_uv;
    assign current_ycoord             = current_is_uv     ? uv_row_cnt                  :
                                        scan_phase_is_yl  ? y_row_next_ext[TH_DW-1:0]  :
                                                            y_row_cnt;
    assign current_format             = base_is_rgba101 ? META_FMT_RGBA1010102 :
                                        base_is_rgba    ? META_FMT_RGBA8888    :
                                        current_is_uv   ? (base_is_p010 ? META_FMT_P010_UV : META_FMT_NV12_UV) :
                                        (base_is_p010 ? META_FMT_P010_Y  : META_FMT_NV12_Y);
    assign meta_base_addr             = current_is_uv ? active_meta_base_addr_uv : active_meta_base_addr_rgba_y;
    assign meta_row_stride_bytes      = {{(ADDR_WIDTH-20){1'b0}}, meta_pitch_bytes, 4'd0};
    assign meta_y_base_addr           = current_is_uv ? active_meta_y_row_base_uv :
                                                        active_meta_y_row_base_rgba_y;
    assign meta_xy_offset_addr        = {
                                         xcoord_cnt[TW_DW-1:4],
                                         current_ycoord[3],
                                         xcoord_cnt[3],
                                         current_ycoord[2:0],
                                         xcoord_cnt[2:0]
                                         };
    assign meta_offset_addr           = {{(ADDR_WIDTH-META_SUB_AW){1'b0}}, meta_xy_offset_addr};
    assign meta_grp_valid             = scan_active;
    assign meta_grp_addr              = meta_base_addr + meta_y_base_addr + meta_offset_addr;
    assign meta_format                = current_format;
    assign meta_xcoord                = xcoord_cnt;
    assign meta_ycoord                = current_ycoord;
    assign meta_fcnt                  = active_fcnt;
    assign row_end_fire               = issue_fire && x_row_last;
    assign rgba_frame_done_fire       = row_end_fire && base_is_rgba && y_row_last;
    assign rgba_y_advance_fire        = row_end_fire && base_is_rgba && !y_row_last;
    assign yuv_uv_row_fire            = row_end_fire && base_is_yuv420 && scan_phase_is_uv;
    assign yuv_yh_row_fire            = row_end_fire && base_is_yuv420 && scan_phase_is_yh;
    assign yuv_yl_row_fire            = row_end_fire && base_is_yuv420 && scan_phase_is_yl;
    assign yuv_yh_frame_done_fire     = yuv_yh_row_fire && !y_pair_has_lower;
    assign yuv_yl_frame_done_fire     = yuv_yl_row_fire && y_pair_last;
    assign yuv_pair_advance_fire      = yuv_yl_row_fire && !y_pair_last;
    assign y_next_after_current_ext   = scan_phase_is_yh ? y_row_next_ext :
                                                           y_pair_next_ext;
    assign y_row_base_inc_fire        = (rgba_y_advance_fire && (y_row_next_ext[3:0] == 4'd0)) ||
                                        ((yuv_yh_row_fire || yuv_yl_row_fire) &&
                                         !yuv_yh_frame_done_fire && !yuv_yl_frame_done_fire &&
                                         (y_next_after_current_ext[3:0] == 4'd0));
    assign uv_row_base_inc_fire       = yuv_uv_row_fire && (uv_row_next[3:0] == 4'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            scan_active <= 1'b0;
        else if (start)
            scan_active <= !frame_empty;
        else if (rgba_frame_done_fire || yuv_yh_frame_done_fire || yuv_yl_frame_done_fire)
            scan_active <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            scan_phase <= SCAN_PHASE_UV;
        else if (start)
            scan_phase <= base_is_yuv420 ? SCAN_PHASE_UV : SCAN_PHASE_YH;
        else if (yuv_uv_row_fire)
            scan_phase <= SCAN_PHASE_YH;
        else if (yuv_yh_row_fire && y_pair_has_lower)
            scan_phase <= SCAN_PHASE_YL;
        else if (yuv_yh_row_fire && !y_pair_has_lower)
            scan_phase <= SCAN_PHASE_UV;
        else if (yuv_yl_row_fire)
            scan_phase <= SCAN_PHASE_UV;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            xcoord_cnt <= {TW_DW{1'b0}};
        else if (start)
            xcoord_cnt <= {TW_DW{1'b0}};
        else if (issue_fire && !x_row_last)
            xcoord_cnt <= xcoord_next_ext[TW_DW-1:0];
        else if (row_end_fire)
            xcoord_cnt <= {TW_DW{1'b0}};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            y_row_cnt <= {TH_DW{1'b0}};
        else if (start)
            y_row_cnt <= {TH_DW{1'b0}};
        else if (rgba_y_advance_fire)
            y_row_cnt <= y_row_next_ext[TH_DW-1:0];
        else if (yuv_pair_advance_fire)
            y_row_cnt <= y_pair_next_ext[TH_DW-1:0];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            uv_row_cnt <= {TH_DW{1'b0}};
        else if (start)
            uv_row_cnt <= {TH_DW{1'b0}};
        else if (yuv_uv_row_fire)
            uv_row_cnt <= uv_row_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_fcnt <= 4'd0;
        else if (start)
            active_fcnt <= i_fcnt;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_meta_base_addr_rgba_y <= {ADDR_WIDTH{1'b0}};
        else if (start)
            active_meta_base_addr_rgba_y <= i_fcnt[0] ? meta_base_addr_rgba_y1 :
                                                        meta_base_addr_rgba_y0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_meta_base_addr_uv <= {ADDR_WIDTH{1'b0}};
        else if (start)
            active_meta_base_addr_uv <= i_fcnt[0] ? meta_base_addr_uv1 :
                                                    meta_base_addr_uv0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_meta_y_row_base_rgba_y <= {ADDR_WIDTH{1'b0}};
        else if (start)
            active_meta_y_row_base_rgba_y <= {ADDR_WIDTH{1'b0}};
        else if (y_row_base_inc_fire)
            active_meta_y_row_base_rgba_y <= active_meta_y_row_base_rgba_y + meta_row_stride_bytes;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_meta_y_row_base_uv <= {ADDR_WIDTH{1'b0}};
        else if (start)
            active_meta_y_row_base_uv <= {ADDR_WIDTH{1'b0}};
        else if (uv_row_base_inc_fire)
            active_meta_y_row_base_uv <= active_meta_y_row_base_uv + meta_row_stride_bytes;
    end

endmodule
