//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-06-21
// Module Name       : ubwc_dec_meta_blk_get_cmd_gen.v
// Description       : DEC metadata 8x8 block command generator
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_dec_meta_blk_get_cmd_gen #(
    parameter                                       ADDR_WIDTH                      = 32,
    parameter                                       TW_DW                           = 16,
    parameter                                       TH_DW                           = 16
)(
    input   wire                                        clk                             ,
    input   wire                                        rst_n                           ,

    input   wire                                        start                           ,
    input   wire    [3                      :0]         i_fcnt                          ,
    input   wire    [1                      :0]         i_rotate_mode                   ,
    input   wire    [4                      :0]         base_format                     ,
    input   wire    [ADDR_WIDTH          -1 :0]         meta_base_addr_rgba_y0          ,
    input   wire    [ADDR_WIDTH          -1 :0]         meta_base_addr_uv0              ,
    input   wire    [ADDR_WIDTH          -1 :0]         meta_base_addr_rgba_y1          ,
    input   wire    [ADDR_WIDTH          -1 :0]         meta_base_addr_uv1              ,
    input   wire    [TW_DW               -1 :0]         tile_x_numbers                  ,
    input   wire    [TH_DW               -1 :0]         tile_y_numbers                  ,

    output  wire                                        meta_blk_valid                  ,
    input   wire                                        meta_blk_ready                  ,
    output  wire    [ADDR_WIDTH          -1 :0]         meta_blk_addr                   ,
    output  wire    [4                      :0]         meta_blk_format                 ,
    output  wire    [TW_DW               -1 :0]         meta_blk_xbase                  ,
    output  wire    [TH_DW               -1 :0]         meta_blk_ybase                  ,
    output  wire    [3                      :0]         meta_blk_cols_valid             ,
    output  wire    [3                      :0]         meta_blk_rows_valid             ,
    output  wire                                        meta_blk_is_uv                  ,
    output  wire    [3                      :0]         meta_blk_fcnt
);

    localparam  integer                             META_SUB_AW                     = TW_DW + 4;
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
    localparam  [1                      :0]         SCAN_PHASE_RGBA                 = 2'd0;
    localparam  [1                      :0]         SCAN_PHASE_UV                   = 2'd1;
    localparam  [1                      :0]         SCAN_PHASE_Y0                   = 2'd2;
    localparam  [1                      :0]         SCAN_PHASE_Y1                   = 2'd3;

    wire                                            base_is_rgba8888                ;
    wire                                            base_is_rgba1010102             ;
    wire                                            base_is_rgba                    ;
    wire                                            base_is_nv12                    ;
    wire                                            base_is_p010                    ;
    wire                                            base_is_yuv420                  ;
    wire                                            base_supported                  ;
    wire                                            frame_empty                     ;
    wire                                            rotate_mode_requested           ;
    wire                                            rotate_270_requested            ;
    wire                                            scan_column_mode                ;
    wire                                            scan_reverse_x                  ;
    wire                                            issue_fire                      ;
    wire                                            phase_is_rgba                   ;
    wire                                            phase_is_uv                     ;
    wire                                            phase_is_y0                     ;
    wire                                            phase_is_y1                     ;
    wire                                            phase_valid                     ;
    wire                                            phase_done_fire                 ;
    wire                                            phase_skip_fire                 ;
    wire                                            phase_advance_fire              ;
    wire                                            group_done_fire                 ;
    wire                                            frame_done_fire                 ;
    wire                                            block_x_last                    ;
    wire                                            block_y_last                    ;
    wire                                            segment_last                    ;
    wire        [TW_DW                  :0]         block_x_step_ext                ;
    wire        [15                     :0]         tile_x_numbers_ext              ;
    wire        [15                     :0]         meta_pitch_bytes                ;
    wire        [ADDR_WIDTH          -1 :0]         meta_row_stride_bytes           ;
    wire        [TH_DW                  :0]         uv_tile_y_numbers_ext           ;
    wire        [TH_DW               -1 :0]         uv_tile_y_numbers               ;
    wire        [TH_DW               -1 :0]         phase_tile_y_numbers            ;
    wire        [TH_DW               -1 :0]         phase_ybase                     ;
    wire        [TH_DW               -1 :0]         scan_ybase                      ;
    wire        [TH_DW               -1 :0]         y1_ybase                        ;
    wire        [TW_DW                  :0]         block_x_next_ext                ;
    wire        [TW_DW                  :0]         block_x_scan_next_ext           ;
    wire        [TW_DW               -1 :0]         block_x_start                   ;
    wire        [TH_DW                  :0]         block_y_next_ext                ;
    wire        [TH_DW                  :0]         group_y_next_ext                ;
    wire        [TH_DW                  :0]         group_uv_next_ext               ;
    wire        [ADDR_WIDTH          -1 :0]         active_meta_base_addr           ;
    wire        [ADDR_WIDTH          -1 :0]         active_meta_row_base_addr       ;
    wire        [META_SUB_AW         -1 :0]         meta_xy_offset_addr             ;
    wire        [ADDR_WIDTH          -1 :0]         meta_offset_addr                ;
    wire        [TW_DW               -1 :0]         cols_left                       ;
    wire        [TH_DW               -1 :0]         rows_left                       ;
    wire                                            cols_full_block                 ;
    wire                                            rows_full_block                 ;

    reg                                             scan_active                     ;
    reg         [1                      :0]         scan_phase                      ;
    reg         [TW_DW               -1 :0]         block_x_base                    ;
    reg         [TH_DW               -1 :0]         block_y_base                    ;
    reg         [TH_DW               -1 :0]         group_y_base                    ;
    reg         [TH_DW               -1 :0]         group_uv_base                   ;
    reg         [3                      :0]         active_fcnt                     ;
    reg         [ADDR_WIDTH          -1 :0]         active_meta_base_addr_y         ;
    reg         [ADDR_WIDTH          -1 :0]         active_meta_base_addr_uv        ;
    reg         [ADDR_WIDTH          -1 :0]         active_meta_row_base_addr_y     ;
    reg         [ADDR_WIDTH          -1 :0]         active_meta_row_base_addr_uv    ;

    assign base_is_rgba8888             = (base_format == BASE_FMT_RGBA8888);
    assign base_is_rgba1010102          = (base_format == BASE_FMT_RGBA1010102);
    assign base_is_rgba                 = base_is_rgba8888 || base_is_rgba1010102;
    assign base_is_nv12                 = (base_format == BASE_FMT_YUV420_8);
    assign base_is_p010                 = (base_format == BASE_FMT_YUV420_10);
    assign base_is_yuv420               = base_is_nv12 || base_is_p010;
    assign base_supported               = base_is_rgba || base_is_yuv420;
    assign frame_empty                  = !base_supported ||
                                          (tile_x_numbers == {TW_DW{1'b0}}) ||
                                          (tile_y_numbers == {TH_DW{1'b0}});
    assign rotate_mode_requested        = (|i_rotate_mode) && base_is_nv12;
    assign rotate_270_requested         = (i_rotate_mode == 2'd2) && base_is_nv12;
    assign scan_column_mode             = rotate_mode_requested;
    assign scan_reverse_x               = scan_column_mode && rotate_270_requested;
    assign issue_fire                   = meta_blk_valid && meta_blk_ready;
    assign phase_is_rgba                = (scan_phase == SCAN_PHASE_RGBA);
    assign phase_is_uv                  = (scan_phase == SCAN_PHASE_UV);
    assign phase_is_y0                  = (scan_phase == SCAN_PHASE_Y0);
    assign phase_is_y1                  = (scan_phase == SCAN_PHASE_Y1);
    assign tile_x_numbers_ext           = {{(16-TW_DW){1'b0}}, tile_x_numbers};
    assign meta_pitch_bytes             = (tile_x_numbers_ext + 16'd63) & 16'hffc0;
    assign meta_row_stride_bytes        = {{(ADDR_WIDTH-20){1'b0}}, meta_pitch_bytes, 4'd0};
    assign uv_tile_y_numbers_ext        = {1'b0, tile_y_numbers} + {{TH_DW{1'b0}}, 1'b1};
    assign uv_tile_y_numbers            = uv_tile_y_numbers_ext[TH_DW:1];
    assign y1_ybase                     = group_y_base + {{(TH_DW-4){1'b0}}, 4'd8};
    assign phase_ybase                  = phase_is_uv ? group_uv_base :
                                          phase_is_y1 ? y1_ybase      :
                                                        group_y_base;
    assign phase_tile_y_numbers         = phase_is_uv ? uv_tile_y_numbers :
                                                        tile_y_numbers;
    assign scan_ybase                   = scan_column_mode ? block_y_base :
                                                             phase_ybase;
    assign phase_valid                  = scan_active && (scan_ybase < phase_tile_y_numbers);
    assign block_x_step_ext             = scan_column_mode ? {{TW_DW{1'b0}}, 1'b1} :
                                                             {{(TW_DW-3){1'b0}}, 4'd8};
    assign block_x_next_ext             = {1'b0, block_x_base} + block_x_step_ext;
    assign block_x_scan_next_ext        = scan_reverse_x ?
                                          ({1'b0, block_x_base} - {{TW_DW{1'b0}}, 1'b1}) :
                                          ({1'b0, block_x_base} + {{TW_DW{1'b0}}, 1'b1});
    assign block_x_start                = scan_reverse_x ?
                                          (tile_x_numbers - {{(TW_DW-1){1'b0}}, 1'b1}) :
                                          {TW_DW{1'b0}};
    assign block_y_next_ext             = {1'b0, block_y_base} + {{(TH_DW-3){1'b0}}, 4'd8};
    assign group_y_next_ext             = {1'b0, group_y_base} + (base_is_rgba ?
                                          {{(TH_DW-3){1'b0}}, 4'd8} :
                                          {{(TH_DW-4){1'b0}}, 5'd16});
    assign group_uv_next_ext            = {1'b0, group_uv_base} + {{(TH_DW-3){1'b0}}, 4'd8};
    assign block_x_last                 = scan_column_mode ?
                                          (scan_reverse_x ? (block_x_base == {TW_DW{1'b0}}) :
                                                            (block_x_next_ext >= {1'b0, tile_x_numbers})) :
                                          (block_x_next_ext >= {1'b0, tile_x_numbers});
    assign block_y_last                 = block_y_next_ext >= {1'b0, phase_tile_y_numbers};
    assign segment_last                 = scan_column_mode ? block_y_last :
                                                             block_x_last;
    assign phase_done_fire              = issue_fire && segment_last;
    assign phase_skip_fire              = scan_active && !phase_valid;
    assign phase_advance_fire           = phase_done_fire || phase_skip_fire;
    assign group_done_fire              = phase_advance_fire &&
                                          (scan_column_mode ? phase_is_y0 :
                                          (phase_is_rgba || phase_is_y1 ||
                                           (phase_is_y0 && (y1_ybase >= tile_y_numbers))));
    assign frame_done_fire              = group_done_fire &&
                                          (scan_column_mode ? block_x_last :
                                          (base_is_rgba ? (group_y_next_ext >= {1'b0, tile_y_numbers}) :
                                                          (group_y_next_ext >= {1'b0, tile_y_numbers})));
    assign active_meta_base_addr        = phase_is_uv ? active_meta_base_addr_uv :
                                                        active_meta_base_addr_y;
    assign active_meta_row_base_addr    = phase_is_uv ? active_meta_row_base_addr_uv :
                                                        active_meta_row_base_addr_y;
    assign meta_xy_offset_addr          = {
                                          block_x_base[TW_DW-1:4],
                                          scan_ybase[3],
                                          block_x_base[3],
                                          6'd0
                                          };
    assign meta_offset_addr             = {{(ADDR_WIDTH-META_SUB_AW){1'b0}}, meta_xy_offset_addr};
    assign cols_left                    = tile_x_numbers - block_x_base;
    assign rows_left                    = phase_tile_y_numbers - scan_ybase;
    assign cols_full_block              = cols_left >= {{(TW_DW-4){1'b0}}, 4'd8};
    assign rows_full_block              = rows_left >= {{(TH_DW-4){1'b0}}, 4'd8};
    assign meta_blk_valid               = phase_valid;
    assign meta_blk_addr                = active_meta_base_addr +
                                          active_meta_row_base_addr +
                                          meta_offset_addr;
    assign meta_blk_format              = base_is_rgba8888    ? META_FMT_RGBA8888    :
                                          base_is_rgba1010102 ? META_FMT_RGBA1010102 :
                                          phase_is_uv         ? (base_is_p010 ? META_FMT_P010_UV :
                                                                                META_FMT_NV12_UV) :
                                                                (base_is_p010 ? META_FMT_P010_Y :
                                                                                META_FMT_NV12_Y);
    assign meta_blk_xbase               = block_x_base;
    assign meta_blk_ybase               = scan_ybase;
    assign meta_blk_cols_valid          = scan_column_mode ? 4'd1 :
                                          (cols_full_block ? 4'd8 : cols_left[3:0]);
    assign meta_blk_rows_valid          = rows_full_block ? 4'd8 : rows_left[3:0];
    assign meta_blk_is_uv               = phase_is_uv;
    assign meta_blk_fcnt                = active_fcnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            scan_active <= 1'b0;
        else if (start)
            scan_active <= !frame_empty;
        else if (frame_done_fire)
            scan_active <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            scan_phase <= SCAN_PHASE_RGBA;
        else if (start)
            scan_phase <= base_is_yuv420 ? SCAN_PHASE_UV :
                                            SCAN_PHASE_RGBA;
        else if (phase_advance_fire && group_done_fire)
            scan_phase <= base_is_yuv420 ? SCAN_PHASE_UV :
                                            SCAN_PHASE_RGBA;
        else if (phase_advance_fire && phase_is_uv)
            scan_phase <= SCAN_PHASE_Y0;
        else if (phase_advance_fire && phase_is_y0 && scan_column_mode)
            scan_phase <= SCAN_PHASE_UV;
        else if (phase_advance_fire && phase_is_y0)
            scan_phase <= SCAN_PHASE_Y1;
        else if (phase_advance_fire && phase_is_y1)
            scan_phase <= SCAN_PHASE_UV;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            block_x_base <= {TW_DW{1'b0}};
        else if (start)
            block_x_base <= block_x_start;
        else if (phase_advance_fire && !scan_column_mode)
            block_x_base <= {TW_DW{1'b0}};
        else if (issue_fire && !scan_column_mode && !block_x_last)
            block_x_base <= block_x_next_ext[TW_DW-1:0];
        else if (phase_advance_fire && scan_column_mode && group_done_fire && !frame_done_fire)
            block_x_base <= block_x_scan_next_ext[TW_DW-1:0];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            block_y_base <= {TH_DW{1'b0}};
        else if (start || (phase_advance_fire && scan_column_mode))
            block_y_base <= {TH_DW{1'b0}};
        else if (phase_advance_fire)
            block_y_base <= phase_is_uv ? group_y_base :
                            phase_is_y0 ? y1_ybase      :
                                          group_uv_base;
        else if (issue_fire && scan_column_mode && !block_y_last)
            block_y_base <= block_y_next_ext[TH_DW-1:0];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            group_y_base <= {TH_DW{1'b0}};
        else if (start)
            group_y_base <= {TH_DW{1'b0}};
        else if (group_done_fire && !scan_column_mode && !frame_done_fire)
            group_y_base <= group_y_next_ext[TH_DW-1:0];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            group_uv_base <= {TH_DW{1'b0}};
        else if (start)
            group_uv_base <= {TH_DW{1'b0}};
        else if (group_done_fire && base_is_yuv420 && !scan_column_mode && !frame_done_fire)
            group_uv_base <= group_uv_next_ext[TH_DW-1:0];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_fcnt <= 4'd0;
        else if (start)
            active_fcnt <= i_fcnt;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_meta_base_addr_y <= {ADDR_WIDTH{1'b0}};
        else if (start)
            active_meta_base_addr_y <= i_fcnt[0] ? meta_base_addr_rgba_y1 :
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
            active_meta_row_base_addr_y <= {ADDR_WIDTH{1'b0}};
        else if (start || (phase_advance_fire && scan_column_mode))
            active_meta_row_base_addr_y <= {ADDR_WIDTH{1'b0}};
        else if (issue_fire && scan_column_mode && !phase_is_uv &&
                 !block_y_last && (block_y_next_ext[3:0] == 4'd0))
            active_meta_row_base_addr_y <= active_meta_row_base_addr_y + meta_row_stride_bytes;
        else if (group_done_fire && !frame_done_fire &&
                 !scan_column_mode && (group_y_next_ext[3:0] == 4'd0))
            active_meta_row_base_addr_y <= active_meta_row_base_addr_y + meta_row_stride_bytes;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_meta_row_base_addr_uv <= {ADDR_WIDTH{1'b0}};
        else if (start || (phase_advance_fire && scan_column_mode))
            active_meta_row_base_addr_uv <= {ADDR_WIDTH{1'b0}};
        else if (issue_fire && scan_column_mode && phase_is_uv &&
                 !block_y_last && (block_y_next_ext[3:0] == 4'd0))
            active_meta_row_base_addr_uv <= active_meta_row_base_addr_uv + meta_row_stride_bytes;
        else if (group_done_fire && base_is_yuv420 && !frame_done_fire &&
                 !scan_column_mode && (group_uv_next_ext[3:0] == 4'd0))
            active_meta_row_base_addr_uv <= active_meta_row_base_addr_uv + meta_row_stride_bytes;
    end

endmodule
