//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-03-20  15:06:52
// Design Name       :
// Module Name       : ubwc_enc_otf_tile_top.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							:
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
`default_nettype none

module ubwc_enc_otf_to_tile
    #(
        parameter                                       ADDR_W                          = 16,
        parameter                                       DATA_FIFO_DEPTH                 = 4,
        parameter                                       CI_FIFO_DEPTH                   = 16,
        parameter                                       DATA_FIFO_AF_LEVEL              = DATA_FIFO_DEPTH - 1,
        parameter                                       COORD_FIFO_DEPTH                = 32,
        parameter                                       SB_WIDTH                        = 1,
        parameter                                       TH_DW                           = 13,
        parameter                                       TW_DW                           = 8
    )(
        input   wire                                        clk                             ,
        input   wire                                        i_otf_clk                       ,
        input   wire                                        i_vivo_clk                      ,
        input   wire                                        rst_n_sys                       ,
        input   wire                                        rst_n_otf                       ,
        input   wire                                        rst_n_vivo                      ,
        input   wire                                        i_start_pulse                   ,

    // static config
        input   wire    [3                   -1 :0]         i_cfg_format                    ,
        input   wire    [16                  -1 :0]         i_cfg_width                     ,
        input   wire    [16                  -1 :0]         i_cfg_height                    ,
        input   wire    [16                  -1 :0]         i_cfg_active_width              ,
        input   wire    [16                  -1 :0]         i_cfg_active_height             ,
        input   wire    [16                  -1 :0]         i_cfg_tile_w                    ,
        input   wire    [4                   -1 :0]         i_cfg_tile_h                    ,
        input   wire    [16                  -1 :0]         i_cfg_y_tile_cols               ,
        input   wire    [16                  -1 :0]         i_cfg_uv_tile_cols              ,

    // error flags
        output  wire                                        o_err_bline                     ,
        output  wire                                        o_err_bframe                    ,
        output  wire                                        o_err_fifo_ovf                  ,
        input   wire                                        i_err_clear                     ,

    // OTF input
        input   wire                                        i_otf_vsync                     ,
        input   wire                                        i_otf_hsync                     ,
        input   wire                                        i_otf_de                        ,
        input   wire    [127                    :0]         i_otf_data                      ,
        input   wire    [3                      :0]         i_otf_fcnt                      ,
        input   wire    [11                     :0]         i_otf_lcnt                      ,
        output  wire                                        o_otf_ready                     ,

    // SRAM bank0
        output  wire                                        o_bank0_en                      ,
        output  wire                                        o_bank0_wen                     ,
        output  wire    [ADDR_W              -1 :0]         o_bank0_addr                    ,
        output  wire    [127                    :0]         o_bank0_din                     ,
        input   wire    [127                    :0]         i_bank0_dout                    ,
        input   wire                                        i_bank0_dout_vld                ,

    // SRAM bank1
        output  wire                                        o_bank1_en                      ,
        output  wire                                        o_bank1_wen                     ,
        output  wire    [ADDR_W              -1 :0]         o_bank1_addr                    ,
        output  wire    [127                    :0]         o_bank1_din                     ,
        input   wire    [127                    :0]         i_bank1_dout                    ,
        input   wire                                        i_bank1_dout_vld                ,

    // final tile output
        output  wire                                        o_tile_vld                      ,
        input   wire                                        i_tile_rdy                      ,
        output  wire    [255                    :0]         o_tile_data                     ,
        output  wire    [31                     :0]         o_tile_keep                     ,
        output  wire                                        o_tile_last                     ,
        output  wire                                        o_tile_stat_valid               ,
        output  wire                                        o_tile_stat_last                ,
        output  wire                                        o_tile_stat_slot                ,

        output  wire                                        o_ci_valid                      ,
        input   wire                                        i_ci_ready                      ,
        output  wire                                        o_ci_forced_pcm                 ,
        output  wire    [15                     :0]         o_tile_x                        ,
        output  wire    [15                     :0]         o_tile_y                        ,
        output  wire    [3                      :0]         o_tile_fcnt                     ,
        output  wire    [4                      :0]         o_tile_format                   ,

        input   wire                                        i_co_valid                      ,
        input   wire                                        i_co_ready                      ,
        output  wire    [TW_DW               -1 :0]         o_co_tile_x                     ,
        output  wire    [TH_DW               -1 :0]         o_co_tile_y                     ,
        output  wire    [3                      :0]         o_co_tile_fcnt                  ,
        output  wire    [4                      :0]         o_co_tile_format                ,
        output  wire    [SB_WIDTH            -1 :0]         o_co_sb                         ,
        output  wire                                        o_coord_fifo_wr_en              ,
        output  wire                                        o_coord_fifo_rd_en              ,
        output  wire                                        o_addr_cfg_done_pulse           ,
        output  wire                                        o_addr_cfg_done_slot            ,

        output  wire                                        o_correct_irq_pulse             ,
        output  wire                                        o_correct_irq_slot              ,
        output  wire    [31                     :0]         o_otf_de_count0                 ,
        output  wire    [31                     :0]         o_otf_de_count1                 ,
        output  wire    [31                     :0]         o_otf_line_count0               ,
        output  wire    [31                     :0]         o_otf_line_count1
    );

    localparam  [2                      :0]         FMT_RGBA8888                    = 3'd0;
    localparam  [2                      :0]         FMT_RGBA10                      = 3'd1;
    localparam  [2                      :0]         FMT_YUV420_8                    = 3'd2;
    localparam  [2                      :0]         FMT_YUV420_10                   = 3'd3;
    localparam  integer                             DATA_FIFO_W                     = 4 + 256 + 32 + 1;
    localparam  integer                             CI_FIFO_W                       = 1 + 16 + 16 + 4 + 5;
    localparam  integer                             COORD_FIFO_W                    = 4 + 5 + TH_DW + TW_DW;
    localparam  integer                             DATA_FIFO_PROG_DEPTH            = DATA_FIFO_DEPTH - DATA_FIFO_AF_LEVEL;
    localparam  integer                             DATA_FIFO_DEPTH_BITS            = (DATA_FIFO_DEPTH <= 2)  ? 1 : $clog2(DATA_FIFO_DEPTH);
    localparam  integer                             CI_FIFO_DEPTH_BITS              = (CI_FIFO_DEPTH <= 2)    ? 1 : $clog2(CI_FIFO_DEPTH);
    localparam  integer                             COORD_FIFO_DEPTH_BITS           = (COORD_FIFO_DEPTH <= 2) ? 1 : $clog2(COORD_FIFO_DEPTH);

    wire                                            pack_fifo_a_vld                 ;
    wire                                            pack_fifo_a_rdy                 ;
    wire        [162                    :0]         pack_fifo_a_data                ;
    wire                                            pack_fifo_b_vld                 ;
    wire                                            pack_fifo_b_rdy                 ;
    wire        [162                    :0]         pack_fifo_b_data                ;
    wire                                            line_tile_vld                   ;
    wire                                            line_tile_rdy                   ;
    wire        [127                    :0]         line_tile_data                  ;
    wire        [15                     :0]         line_tile_keep                  ;
    wire                                            line_tile_last                  ;
    wire                                            line_plane                      ;
    wire        [15                     :0]         line_tile_x                     ;
    wire        [15                     :0]         line_tile_y                     ;
    wire        [3                      :0]         line_tile_fcnt                  ;
    wire                                            data_fifo_full                  ;
    wire                                            data_fifo_almost_full           ;
    wire                                            data_fifo_empty                 ;
    wire                                            data_fifo_valid                 ;
    wire        [DATA_FIFO_W         -1 :0]         data_fifo_dout                  ;
    wire        [DATA_FIFO_W         -1 :0]         data_fifo_din                   ;
    wire                                            data_fifo_wr_en                 ;
    wire                                            data_fifo_rd_en                 ;
    wire        [DATA_FIFO_DEPTH_BITS    :0]         data_fifo_wr_data_count         ;
    wire        [DATA_FIFO_DEPTH_BITS    :0]         data_fifo_rd_data_count         ;
    wire                                            data_fifo_pre_empty             ;
    wire                                            ci_fifo_full                    ;
    wire                                            ci_fifo_empty                   ;
    wire                                            ci_fifo_valid                   ;
    wire        [CI_FIFO_W           -1 :0]         ci_fifo_dout                    ;
    wire        [CI_FIFO_W           -1 :0]         ci_fifo_din                     ;
    wire                                            ci_fifo_wr_en                   ;
    wire                                            ci_fifo_rd_en                   ;
    wire                                            ci_fifo_prog_full               ;
    wire        [CI_FIFO_DEPTH_BITS      :0]         ci_fifo_wr_data_count           ;
    wire        [CI_FIFO_DEPTH_BITS      :0]         ci_fifo_rd_data_count           ;
    wire                                            ci_fifo_pre_empty               ;
    wire                                            start_fifo_full                 ;
    wire                                            start_fifo_valid                ;
    wire                                            start_fifo_wr_en                ;
    wire                                            start_fifo_rd_en                ;
    wire                                            ci_tile_forced_pcm              ;
    wire        [4                      :0]         ci_tile_format                  ;
    wire        [3                      :0]         ci_tile_fcnt                    ;
    wire        [15                     :0]         ci_tile_y                       ;
    wire        [15                     :0]         ci_tile_x                       ;
    wire                                            coord_fifo_wr_en                ;
    wire                                            coord_fifo_rd_en                ;
    wire        [COORD_FIFO_W        -1 :0]         coord_fifo_din                  ;
    wire        [COORD_FIFO_W        -1 :0]         coord_fifo_dout                 ;
    wire                                            coord_fifo_full                 ;
    wire                                            coord_fifo_prog_full            ;
    wire                                            coord_fifo_empty                ;
    wire                                            coord_fifo_valid                ;
    wire        [COORD_FIFO_DEPTH_BITS   :0]         coord_fifo_wr_data_count        ;
    wire        [COORD_FIFO_DEPTH_BITS   :0]         coord_fifo_rd_data_count        ;
    wire                                            coord_fifo_pre_empty            ;
    wire                                            coord_is_yuv420                 ;
    wire                                            coord_is_uv_plane               ;
    wire        [15                     :0]         coord_plane_height_px           ;
    wire        [15                     :0]         coord_tile_cols                 ;
    wire        [15                     :0]         coord_tile_rows                 ;
    wire        [15                     :0]         coord_tile_x_u16                ;
    wire        [15                     :0]         coord_tile_y_u16                ;
    wire                                            coord_last_col                  ;
    wire                                            coord_last_row                  ;
    wire                                            coord_frame_last                ;
    wire        [4                      :0]         line_tile_format                ;
    wire        [15                     :0]         tile_h_u16                      ;
    wire        [15                     :0]         active_width_px                 ;
    wire        [15                     :0]         active_height_px                ;
    wire        [15                     :0]         active_tile_cols_div            ;
    wire        [15                     :0]         active_tile_rows_div            ;
    wire                                            active_width_rem                ;
    wire                                            active_height_rem               ;
    wire                                            line_is_yuv420                  ;
    wire                                            line_is_uv_plane                ;
    wire        [15                     :0]         plane_active_height_px          ;
    wire        [15                     :0]         active_tile_cols                ;
    wire        [15                     :0]         active_tile_rows                ;
    wire                                            active_width_partial            ;
    wire                                            active_height_partial           ;
    wire                                            partial_right_tile              ;
    wire                                            partial_bottom_tile             ;
    wire                                            line_tile_forced_pcm            ;
    wire                                            data_push_ready                 ;
    wire                                            ci_push_ready                   ;
    wire                                            line_tile_fire                  ;
    wire                                            pack_first_fire                 ;
    wire                                            pack_second_fire                ;
    wire                                            pack_in_ready                   ;
    wire                                            flush_half_only                 ;
    wire                                            ci_push_needed                  ;
    wire                                            half_valid_clear                ;
    wire                                            otf_input_enable                ;
    wire                                            otf_vsync_gated                 ;
    wire                                            otf_hsync_gated                 ;
    wire                                            otf_de_gated                    ;
    wire                                            packer_otf_ready                ;
    wire                                            otf_frame_start                 ;
    wire                                            otf_line_fire                   ;
    wire                                            otf_de_fire                     ;
    wire                                            otf_slot                        ;
    wire                                            otf_count_snapshot_event        ;
    wire                                            otf_count_snapshot_pulse        ;
    wire        [31                     :0]         otf_de_count0_snap_data         ;
    wire        [31                     :0]         otf_de_count1_snap_data         ;
    wire        [31                     :0]         otf_line_count0_snap_data       ;
    wire        [31                     :0]         otf_line_count1_snap_data       ;

    reg                                             half_valid_r                    ;
    reg         [127                    :0]         half_data_r                     ;
    reg         [15                     :0]         half_keep_r                     ;
    reg                                             half_last_r                     ;
    reg         [15                     :0]         half_x_r                        ;
    reg         [15                     :0]         half_y_r                        ;
    reg         [3                      :0]         half_fcnt_r                     ;
    reg         [4                      :0]         half_format_r                   ;
    reg                                             half_forced_pcm_r               ;
    reg                                             tile_first_word_r               ;
    reg                                             tile_cmd_sent_r                 ;
    reg                                             otf_frame_active                ;
    reg                                             otf_vsync_d                     ;
    reg                                             otf_hsync_d                     ;
    reg         [31                     :0]         otf_de_count0_r                 ;
    reg         [31                     :0]         otf_de_count1_r                 ;
    reg         [31                     :0]         otf_line_count0_r               ;
    reg         [31                     :0]         otf_line_count1_r               ;
    reg                                             otf_count_snap_toggle           ;
    reg         [31                     :0]         otf_de_count0_snap              ;
    reg         [31                     :0]         otf_de_count1_snap              ;
    reg         [31                     :0]         otf_line_count0_snap            ;
    reg         [31                     :0]         otf_line_count1_snap            ;
    reg         [31                     :0]         otf_de_count0_clk               ;
    reg         [31                     :0]         otf_de_count1_clk               ;
    reg         [31                     :0]         otf_line_count0_clk             ;
    reg         [31                     :0]         otf_line_count1_clk             ;

    (* async_reg = "true" *) reg     [2:0]                               otf_count_snap_toggle_sync      ;

    assign line_tile_format           = (i_cfg_format == FMT_RGBA8888)  ? 5'd0  :
                                        (i_cfg_format == FMT_RGBA10)    ? 5'd1  :
                                        (i_cfg_format == FMT_YUV420_8)  ? (line_plane ? 5'd9  : 5'd8)  :
                                        (i_cfg_format == FMT_YUV420_10) ? (line_plane ? 5'd15 : 5'd14) :
                                                                          5'd0;
    assign tile_h_u16                 = {12'd0, i_cfg_tile_h};
    assign active_width_px            = (i_cfg_active_width  != 16'd0) ? i_cfg_active_width  : i_cfg_width;
    assign active_height_px           = (i_cfg_active_height != 16'd0) ? i_cfg_active_height : i_cfg_height;
    assign active_tile_cols_div       = (i_cfg_tile_w == 16'd1)   ? active_width_px :
                                        (i_cfg_tile_w == 16'd2)   ? ({1'd0, active_width_px[15:1]} + {15'd0, |active_width_px[0:0]}) :
                                        (i_cfg_tile_w == 16'd4)   ? ({2'd0, active_width_px[15:2]} + {15'd0, |active_width_px[1:0]}) :
                                        (i_cfg_tile_w == 16'd8)   ? ({3'd0, active_width_px[15:3]} + {15'd0, |active_width_px[2:0]}) :
                                        (i_cfg_tile_w == 16'd16)  ? ({4'd0, active_width_px[15:4]} + {15'd0, |active_width_px[3:0]}) :
                                        (i_cfg_tile_w == 16'd32)  ? ({5'd0, active_width_px[15:5]} + {15'd0, |active_width_px[4:0]}) :
                                        (i_cfg_tile_w == 16'd64)  ? ({6'd0, active_width_px[15:6]} + {15'd0, |active_width_px[5:0]}) :
                                        (i_cfg_tile_w == 16'd128) ? ({7'd0, active_width_px[15:7]} + {15'd0, |active_width_px[6:0]}) :
                                        (i_cfg_tile_w == 16'd256) ? ({8'd0, active_width_px[15:8]} + {15'd0, |active_width_px[7:0]}) :
                                                                    16'd0;
    assign active_tile_rows_div       = (tile_h_u16 == 16'd1)   ? plane_active_height_px :
                                        (tile_h_u16 == 16'd2)   ? ({1'd0, plane_active_height_px[15:1]} + {15'd0, |plane_active_height_px[0:0]}) :
                                        (tile_h_u16 == 16'd4)   ? ({2'd0, plane_active_height_px[15:2]} + {15'd0, |plane_active_height_px[1:0]}) :
                                        (tile_h_u16 == 16'd8)   ? ({3'd0, plane_active_height_px[15:3]} + {15'd0, |plane_active_height_px[2:0]}) :
                                        (tile_h_u16 == 16'd16)  ? ({4'd0, plane_active_height_px[15:4]} + {15'd0, |plane_active_height_px[3:0]}) :
                                        (tile_h_u16 == 16'd32)  ? ({5'd0, plane_active_height_px[15:5]} + {15'd0, |plane_active_height_px[4:0]}) :
                                        (tile_h_u16 == 16'd64)  ? ({6'd0, plane_active_height_px[15:6]} + {15'd0, |plane_active_height_px[5:0]}) :
                                        (tile_h_u16 == 16'd128) ? ({7'd0, plane_active_height_px[15:7]} + {15'd0, |plane_active_height_px[6:0]}) :
                                        (tile_h_u16 == 16'd256) ? ({8'd0, plane_active_height_px[15:8]} + {15'd0, |plane_active_height_px[7:0]}) :
                                                                  16'd0;
    assign active_width_rem           = (i_cfg_tile_w == 16'd1)   ? 1'b0 :
                                        (i_cfg_tile_w == 16'd2)   ? |active_width_px[0:0] :
                                        (i_cfg_tile_w == 16'd4)   ? |active_width_px[1:0] :
                                        (i_cfg_tile_w == 16'd8)   ? |active_width_px[2:0] :
                                        (i_cfg_tile_w == 16'd16)  ? |active_width_px[3:0] :
                                        (i_cfg_tile_w == 16'd32)  ? |active_width_px[4:0] :
                                        (i_cfg_tile_w == 16'd64)  ? |active_width_px[5:0] :
                                        (i_cfg_tile_w == 16'd128) ? |active_width_px[6:0] :
                                        (i_cfg_tile_w == 16'd256) ? |active_width_px[7:0] :
                                                                    1'b0;
    assign active_height_rem          = (tile_h_u16 == 16'd1)   ? 1'b0 :
                                        (tile_h_u16 == 16'd2)   ? |plane_active_height_px[0:0] :
                                        (tile_h_u16 == 16'd4)   ? |plane_active_height_px[1:0] :
                                        (tile_h_u16 == 16'd8)   ? |plane_active_height_px[2:0] :
                                        (tile_h_u16 == 16'd16)  ? |plane_active_height_px[3:0] :
                                        (tile_h_u16 == 16'd32)  ? |plane_active_height_px[4:0] :
                                        (tile_h_u16 == 16'd64)  ? |plane_active_height_px[5:0] :
                                        (tile_h_u16 == 16'd128) ? |plane_active_height_px[6:0] :
                                        (tile_h_u16 == 16'd256) ? |plane_active_height_px[7:0] :
                                                                  1'b0;
    assign line_is_yuv420             = (line_tile_format == 5'd8)  || (line_tile_format == 5'd9) ||
                                        (line_tile_format == 5'd14) || (line_tile_format == 5'd15);
    assign line_is_uv_plane           = (line_tile_format == 5'd9)  || (line_tile_format == 5'd11) ||
                                        (line_tile_format == 5'd13) || (line_tile_format == 5'd15);
    assign plane_active_height_px     = (line_is_yuv420 && line_is_uv_plane) ? ((active_height_px + 16'd1) >> 1) : active_height_px;
    assign active_tile_cols           = active_tile_cols_div;
    assign active_tile_rows           = active_tile_rows_div;
    assign active_width_partial       = active_width_rem;
    assign active_height_partial      = active_height_rem;
    assign partial_right_tile         = active_width_partial &&
                                        (active_tile_cols != 16'd0) &&
                                        (line_tile_x == active_tile_cols - 16'd1);
    assign partial_bottom_tile        = active_height_partial &&
                                        (active_tile_rows != 16'd0) &&
                                        (line_tile_y == active_tile_rows - 16'd1);
    assign line_tile_forced_pcm       = partial_right_tile || partial_bottom_tile;
    assign data_push_ready            = !data_fifo_full;
    assign ci_push_ready              = !ci_fifo_full;
    assign line_tile_fire             = line_tile_vld && line_tile_rdy;
    assign pack_first_fire            = line_tile_fire && !half_valid_r;
    assign pack_second_fire           = line_tile_fire && half_valid_r && !half_last_r && data_push_ready;
    assign pack_in_ready              = !half_valid_r || (!half_last_r && data_push_ready);
    assign flush_half_only            = half_valid_r && half_last_r && data_push_ready;
    assign ci_push_needed             = tile_first_word_r && !tile_cmd_sent_r;
    assign half_valid_clear           = flush_half_only || pack_second_fire;
    assign start_fifo_wr_en           = i_start_pulse && !start_fifo_full;
    assign start_fifo_rd_en           = otf_frame_start;
    assign otf_input_enable           = start_fifo_valid || otf_frame_active;
    assign otf_vsync_gated            = otf_input_enable ? i_otf_vsync : 1'b0;
    assign otf_hsync_gated            = otf_input_enable ? i_otf_hsync : 1'b0;
    assign otf_de_gated               = otf_input_enable ? i_otf_de    : 1'b0;
    assign data_fifo_din              = flush_half_only ?
                                                          {half_fcnt_r, 1'b1, {16'd0, half_keep_r}, {128'd0, half_data_r}} :
                                                          {half_fcnt_r, line_tile_last, {line_tile_keep, half_keep_r}, {line_tile_data, half_data_r}};
    assign data_fifo_wr_en            = flush_half_only || pack_second_fire;
    assign data_fifo_rd_en            = data_fifo_valid && i_tile_rdy;
    assign ci_fifo_din                = {line_tile_forced_pcm, line_tile_format, line_tile_fcnt, line_tile_y, line_tile_x};
    assign ci_fifo_wr_en              = line_tile_vld && ci_push_needed && ci_push_ready;
    assign ci_fifo_rd_en              = ci_fifo_valid && i_ci_ready;
    assign line_tile_rdy              = pack_in_ready && !data_fifo_almost_full && (!ci_push_needed || ci_push_ready);
    assign o_tile_vld                 = data_fifo_valid;
    assign o_ci_valid                 = ci_fifo_valid;
    assign o_tile_data                = data_fifo_dout[0   +: 256];
    assign o_tile_keep                = data_fifo_dout[256 +: 32];
    assign o_tile_last                = data_fifo_dout[288];
    assign o_tile_fcnt                = data_fifo_dout[DATA_FIFO_W-1 -: 4];
    assign o_tile_stat_valid          = data_fifo_wr_en;
    assign o_tile_stat_last           = data_fifo_din[288];
    assign o_tile_stat_slot           = data_fifo_din[DATA_FIFO_W-4];
    assign ci_tile_x                  = ci_fifo_dout[0  +: 16];
    assign ci_tile_y                  = ci_fifo_dout[16 +: 16];
    assign ci_tile_fcnt               = ci_fifo_dout[32 +: 4];
    assign ci_tile_format             = ci_fifo_dout[36 +: 5];
    assign ci_tile_forced_pcm         = ci_fifo_dout[CI_FIFO_W-1];
    assign o_ci_forced_pcm            = ci_tile_forced_pcm;
    assign o_tile_format              = ci_tile_format;
    assign o_tile_y                   = ci_tile_y;
    assign o_tile_x                   = ci_tile_x;
    assign coord_fifo_wr_en           = ci_fifo_rd_en;
    assign coord_fifo_rd_en           = i_co_valid & i_co_ready;
    assign coord_fifo_din             = {ci_tile_format, ci_tile_fcnt, ci_tile_y[TH_DW-1:0], ci_tile_x[TW_DW-1:0]};
    assign o_co_tile_x                = coord_fifo_dout[0 +: TW_DW];
    assign o_co_tile_y                = coord_fifo_dout[TW_DW +: TH_DW];
    assign o_co_tile_fcnt             = coord_fifo_dout[TW_DW+TH_DW +: 4];
    assign o_co_tile_format           = coord_fifo_dout[TW_DW+TH_DW+4 +: 5];
    assign o_co_sb                    = {{(SB_WIDTH-1){1'b0}}, o_co_tile_fcnt[0]};
    assign o_coord_fifo_wr_en         = coord_fifo_wr_en;
    assign o_coord_fifo_rd_en         = coord_fifo_rd_en;
    assign coord_is_yuv420            = (o_co_tile_format == 5'd8)  ||
                                        (o_co_tile_format == 5'd9)  ||
                                        (o_co_tile_format == 5'd14) ||
                                        (o_co_tile_format == 5'd15);
    assign coord_is_uv_plane          = (o_co_tile_format == 5'd9) ||
                                        (o_co_tile_format == 5'd15);
    assign coord_plane_height_px      = (coord_is_yuv420 && coord_is_uv_plane) ?
                                        ({1'b0, i_cfg_height[15:1]} + {15'd0, i_cfg_height[0]}) :
                                                                                 i_cfg_height;
    assign coord_tile_cols            = coord_is_uv_plane ? i_cfg_uv_tile_cols : i_cfg_y_tile_cols;
    assign coord_tile_rows            = (tile_h_u16 == 16'd1)   ? coord_plane_height_px :
                                        (tile_h_u16 == 16'd2)   ? ({1'd0, coord_plane_height_px[15:1]} + {15'd0, |coord_plane_height_px[0:0]}) :
                                        (tile_h_u16 == 16'd4)   ? ({2'd0, coord_plane_height_px[15:2]} + {15'd0, |coord_plane_height_px[1:0]}) :
                                        (tile_h_u16 == 16'd8)   ? ({3'd0, coord_plane_height_px[15:3]} + {15'd0, |coord_plane_height_px[2:0]}) :
                                        (tile_h_u16 == 16'd16)  ? ({4'd0, coord_plane_height_px[15:4]} + {15'd0, |coord_plane_height_px[3:0]}) :
                                        (tile_h_u16 == 16'd32)  ? ({5'd0, coord_plane_height_px[15:5]} + {15'd0, |coord_plane_height_px[4:0]}) :
                                        (tile_h_u16 == 16'd64)  ? ({6'd0, coord_plane_height_px[15:6]} + {15'd0, |coord_plane_height_px[5:0]}) :
                                        (tile_h_u16 == 16'd128) ? ({7'd0, coord_plane_height_px[15:7]} + {15'd0, |coord_plane_height_px[6:0]}) :
                                        (tile_h_u16 == 16'd256) ? ({8'd0, coord_plane_height_px[15:8]} + {15'd0, |coord_plane_height_px[7:0]}) :
                                                                  16'd0;
    assign coord_tile_x_u16           = {{(16-TW_DW){1'b0}}, o_co_tile_x};
    assign coord_tile_y_u16           = {{(16-TH_DW){1'b0}}, o_co_tile_y};
    assign coord_last_col             = (coord_tile_cols != 16'd0) &&
                                        (coord_tile_x_u16 == (coord_tile_cols - 16'd1));
    assign coord_last_row             = (coord_tile_rows != 16'd0) &&
                                        (coord_tile_y_u16 == (coord_tile_rows - 16'd1));
    assign coord_frame_last           = coord_last_col &&
                                        coord_last_row &&
                                        (!coord_is_yuv420 || coord_is_uv_plane);
    assign o_addr_cfg_done_pulse      = coord_fifo_rd_en && coord_frame_last;
    assign o_addr_cfg_done_slot       = o_co_tile_fcnt[0];
    assign otf_frame_start            = i_otf_vsync & ~otf_vsync_d &
                                        start_fifo_valid & packer_otf_ready;
    assign otf_line_fire              = i_otf_hsync & ~otf_hsync_d & o_otf_ready;
    assign otf_de_fire                = i_otf_de & o_otf_ready;
    assign otf_slot                   = i_otf_fcnt[0];
    assign otf_count_snapshot_event   = otf_frame_start;
    assign otf_count_snapshot_pulse   = otf_count_snap_toggle_sync[2] ^
                                        otf_count_snap_toggle_sync[1];
    assign otf_de_count0_snap_data    = (otf_de_fire && !otf_slot) ?
                                        (otf_de_count0_r + 32'd1) :
                                                                     otf_de_count0_r;
    assign otf_de_count1_snap_data    = (otf_de_fire && otf_slot) ?
                                        (otf_de_count1_r + 32'd1) :
                                                                    otf_de_count1_r;
    assign otf_line_count0_snap_data  = (otf_line_fire && !otf_slot) ?
                                        (otf_line_count0_r + 32'd1) :
                                                                       otf_line_count0_r;
    assign otf_line_count1_snap_data  = (otf_line_fire && otf_slot) ?
                                        (otf_line_count1_r + 32'd1) :
                                                                      otf_line_count1_r;
    assign o_correct_irq_pulse        = o_addr_cfg_done_pulse;
    assign o_correct_irq_slot         = o_addr_cfg_done_slot;
    assign o_otf_de_count0            = otf_de_count0_clk;
    assign o_otf_de_count1            = otf_de_count1_clk;
    assign o_otf_line_count0          = otf_line_count0_clk;
    assign o_otf_line_count1          = otf_line_count1_clk;
    assign o_otf_ready                = otf_input_enable && packer_otf_ready;

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_vsync_d <= 1'b0;
        else
            otf_vsync_d <= i_otf_vsync;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_hsync_d <= 1'b0;
        else
            otf_hsync_d <= i_otf_hsync;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_de_count0_r <= 32'd0;
        else if (otf_de_fire && !otf_slot)
            otf_de_count0_r <= otf_de_count0_r + 32'd1;
        else if (otf_frame_start && !otf_slot)
            otf_de_count0_r <= 32'd0;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_de_count1_r <= 32'd0;
        else if (otf_de_fire && otf_slot)
            otf_de_count1_r <= otf_de_count1_r + 32'd1;
        else if (otf_frame_start && otf_slot)
            otf_de_count1_r <= 32'd0;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_line_count0_r <= 32'd0;
        else if (otf_line_fire && !otf_slot)
            otf_line_count0_r <= otf_line_count0_r + 32'd1;
        else if (otf_frame_start && !otf_slot)
            otf_line_count0_r <= 32'd0;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_line_count1_r <= 32'd0;
        else if (otf_line_fire && otf_slot)
            otf_line_count1_r <= otf_line_count1_r + 32'd1;
        else if (otf_frame_start && otf_slot)
            otf_line_count1_r <= 32'd0;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_count_snap_toggle <= 1'b0;
        else if (otf_count_snapshot_event)
            otf_count_snap_toggle <= ~otf_count_snap_toggle;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_de_count0_snap <= 32'd0;
        else if (otf_count_snapshot_event)
            otf_de_count0_snap <= otf_de_count0_snap_data;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_de_count1_snap <= 32'd0;
        else if (otf_count_snapshot_event)
            otf_de_count1_snap <= otf_de_count1_snap_data;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_line_count0_snap <= 32'd0;
        else if (otf_count_snapshot_event)
            otf_line_count0_snap <= otf_line_count0_snap_data;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_line_count1_snap <= 32'd0;
        else if (otf_count_snapshot_event)
            otf_line_count1_snap <= otf_line_count1_snap_data;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            otf_count_snap_toggle_sync <= 3'b000;
        else
            otf_count_snap_toggle_sync <= {otf_count_snap_toggle_sync[1:0],
                                           otf_count_snap_toggle};
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            otf_de_count0_clk <= 32'd0;
        else if (otf_count_snapshot_pulse)
            otf_de_count0_clk <= otf_de_count0_snap;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            otf_de_count1_clk <= 32'd0;
        else if (otf_count_snapshot_pulse)
            otf_de_count1_clk <= otf_de_count1_snap;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            otf_line_count0_clk <= 32'd0;
        else if (otf_count_snapshot_pulse)
            otf_line_count0_clk <= otf_line_count0_snap;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            otf_line_count1_clk <= 32'd0;
        else if (otf_count_snapshot_pulse)
            otf_line_count1_clk <= otf_line_count1_snap;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            half_valid_r <= 1'b0;
        else if (pack_first_fire)
            half_valid_r <= 1'b1;
        else if (half_valid_clear)
            half_valid_r <= 1'b0;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_data_r <= line_tile_data;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_keep_r <= line_tile_keep;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_last_r <= line_tile_last;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_x_r <= line_tile_x;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_y_r <= line_tile_y;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_fcnt_r <= line_tile_fcnt;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_format_r <= line_tile_format;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_forced_pcm_r <= line_tile_forced_pcm;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            tile_first_word_r <= 1'b1;
        else if (line_tile_fire)
            tile_first_word_r <= line_tile_last;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            tile_cmd_sent_r <= 1'b0;
        else if (line_tile_fire && tile_first_word_r)
            tile_cmd_sent_r <= 1'b0;
        else if (ci_fifo_wr_en)
            tile_cmd_sent_r <= 1'b1;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_frame_active <= 1'b0;
        else if ((i_otf_vsync & ~otf_vsync_d) && otf_frame_active && !start_fifo_valid)
            otf_frame_active <= 1'b0;
        else if (otf_frame_start)
            otf_frame_active <= 1'b1;
    end

    mg_async_fifo
    #(
        .AF                         ( 1                             ),
        .DATA_BITS                  ( 1                             ),
        .DEPTH_BITS                 ( 3                             ),
        .SHOW_AHEAD                 ( 1                             )
    )
    u_start_fifo
    (
        .wr_clk                     ( clk                           ),
        .wr_rstn                    ( rst_n_sys                     ),
        .wr_en                      ( start_fifo_wr_en              ),
        .din                        ( 1'b1                          ),
        .wr_data_count              (                               ),
        .prog_full                  (                               ),
        .full                       ( start_fifo_full               ),
        .rd_clk                     ( i_otf_clk                     ),
        .rd_rstn                    ( rst_n_otf                     ),
        .rd_en                      ( start_fifo_rd_en              ),
        .dout                       (                               ),
        .valid                      ( start_fifo_valid              ),
        .rd_data_count              (                               ),
        .pre_empty                  (                               ),
        .empty                      (                               )
    );

    mg_async_fifo
    #(
        .AF                         ( DATA_FIFO_PROG_DEPTH          ),
        .DATA_BITS                  ( DATA_FIFO_W                   ),
        .DEPTH_BITS                 ( DATA_FIFO_DEPTH_BITS          ),
        .SHOW_AHEAD                 ( 1                             )
    )
    u_data_fifo
    (
        .wr_clk                     ( clk                           ),
        .wr_rstn                    ( rst_n_sys                     ),
        .wr_en                      ( data_fifo_wr_en               ),
        .din                        ( data_fifo_din                 ),
        .wr_data_count              ( data_fifo_wr_data_count       ),
        .prog_full                  ( data_fifo_almost_full         ),
        .full                       ( data_fifo_full                ),
        .rd_clk                     ( i_vivo_clk                    ),
        .rd_rstn                    ( rst_n_vivo                    ),
        .rd_en                      ( data_fifo_rd_en               ),
        .dout                       ( data_fifo_dout                ),
        .valid                      ( data_fifo_valid               ),
        .rd_data_count              ( data_fifo_rd_data_count       ),
        .pre_empty                  ( data_fifo_pre_empty           ),
        .empty                      ( data_fifo_empty               )
    );

    mg_async_fifo
    #(
        .AF                         ( 1                             ),
        .DATA_BITS                  ( CI_FIFO_W                     ),
        .DEPTH_BITS                 ( CI_FIFO_DEPTH_BITS            ),
        .SHOW_AHEAD                 ( 1                             )
    )
    u_ci_fifo
    (
        .wr_clk                     ( clk                           ),
        .wr_rstn                    ( rst_n_sys                     ),
        .wr_en                      ( ci_fifo_wr_en                 ),
        .din                        ( ci_fifo_din                   ),
        .wr_data_count              ( ci_fifo_wr_data_count         ),
        .prog_full                  ( ci_fifo_prog_full             ),
        .full                       ( ci_fifo_full                  ),
        .rd_clk                     ( i_vivo_clk                    ),
        .rd_rstn                    ( rst_n_vivo                    ),
        .rd_en                      ( ci_fifo_rd_en                 ),
        .dout                       ( ci_fifo_dout                  ),
        .valid                      ( ci_fifo_valid                 ),
        .rd_data_count              ( ci_fifo_rd_data_count         ),
        .pre_empty                  ( ci_fifo_pre_empty             ),
        .empty                      ( ci_fifo_empty                 )
    );

    mg_async_fifo
    #(
        .AF                         ( 1                             ),
        .DATA_BITS                  ( COORD_FIFO_W                  ),
        .DEPTH_BITS                 ( COORD_FIFO_DEPTH_BITS         ),
        .SHOW_AHEAD                 ( 1                             )
    )
    u_coord_fifo
    (
        .wr_clk                     ( i_vivo_clk                    ),
        .wr_rstn                    ( rst_n_vivo                    ),
        .wr_en                      ( coord_fifo_wr_en              ),
        .din                        ( coord_fifo_din                ),
        .wr_data_count              ( coord_fifo_wr_data_count      ),
        .prog_full                  ( coord_fifo_prog_full          ),
        .full                       ( coord_fifo_full               ),
        .rd_clk                     ( clk                           ),
        .rd_rstn                    ( rst_n_sys                     ),
        .rd_en                      ( coord_fifo_rd_en              ),
        .dout                       ( coord_fifo_dout               ),
        .valid                      ( coord_fifo_valid              ),
        .rd_data_count              ( coord_fifo_rd_data_count      ),
        .pre_empty                  ( coord_fifo_pre_empty          ),
        .empty                      ( coord_fifo_empty              )
    );

    ubwc_enc_otf_data_packer u_otf_data_packer
    (
        .i_otf_clk                  ( i_otf_clk                     ),
        .i_clk                      ( clk                           ),
        .rst_n_sys                  ( rst_n_sys                     ),
        .rst_n_otf                  ( rst_n_otf                     ),

        .cfg_format                 ( i_cfg_format                  ),
        .cfg_width                  ( i_cfg_width                   ),
        .cfg_height                 ( i_cfg_height                  ),
        .err_bline                  ( o_err_bline                   ),
        .err_bframe                 ( o_err_bframe                  ),
        .err_fifo_ovf               ( o_err_fifo_ovf                ),
        .err_clear                  ( i_err_clear                   ),

        .otf_vsync                  ( otf_vsync_gated               ),
        .otf_hsync                  ( otf_hsync_gated               ),
        .otf_de                     ( otf_de_gated                  ),
        .otf_data                   ( i_otf_data                    ),
        .otf_fcnt                   ( i_otf_fcnt                    ),
        .otf_lcnt                   ( i_otf_lcnt                    ),
        .otf_ready                  ( packer_otf_ready              ),

        .fifo_a_vld                 ( pack_fifo_a_vld               ),
        .fifo_a_rdy                 ( pack_fifo_a_rdy               ),
        .fifo_a_data                ( pack_fifo_a_data              ),
        .fifo_b_vld                 ( pack_fifo_b_vld               ),
        .fifo_b_rdy                 ( pack_fifo_b_rdy               ),
        .fifo_b_data                ( pack_fifo_b_data              )
    );

    ubwc_enc_line_to_tile
    #(
        .ADDR_W                     ( ADDR_W                        )
    )
    u_line_to_tile
    (
        .clk                        ( clk                           ),
        .rst_n                      ( rst_n_sys                     ),

        .cfg_format                 ( i_cfg_format                  ),
        .cfg_y_tile_cols            ( i_cfg_y_tile_cols             ),
        .cfg_uv_tile_cols           ( i_cfg_uv_tile_cols            ),

        .fifo_a_vld                 ( pack_fifo_a_vld               ),
        .fifo_a_rdy                 ( pack_fifo_a_rdy               ),
        .fifo_a_data                ( pack_fifo_a_data              ),
        .fifo_b_vld                 ( pack_fifo_b_vld               ),
        .fifo_b_rdy                 ( pack_fifo_b_rdy               ),
        .fifo_b_data                ( pack_fifo_b_data              ),

        .bank0_en                   ( o_bank0_en                    ),
        .bank0_wen                  ( o_bank0_wen                   ),
        .bank0_addr                 ( o_bank0_addr                  ),
        .bank0_din                  ( o_bank0_din                   ),
        .bank0_dout                 ( i_bank0_dout                  ),
        .bank0_dout_vld             ( i_bank0_dout_vld              ),

        .bank1_en                   ( o_bank1_en                    ),
        .bank1_wen                  ( o_bank1_wen                   ),
        .bank1_addr                 ( o_bank1_addr                  ),
        .bank1_din                  ( o_bank1_din                   ),
        .bank1_dout                 ( i_bank1_dout                  ),
        .bank1_dout_vld             ( i_bank1_dout_vld              ),

        .o_tile_vld                 ( line_tile_vld                 ),
        .i_tile_rdy                 ( line_tile_rdy                 ),
        .o_tile_data                ( line_tile_data                ),
        .o_tile_keep                ( line_tile_keep                ),
        .o_tile_last                ( line_tile_last                ),
        .o_plane                    ( line_plane                    ),
        .o_tile_x                   ( line_tile_x                   ),
        .o_tile_y                   ( line_tile_y                   ),
        .o_tile_fcnt                ( line_tile_fcnt                )
    );

endmodule

`default_nettype wire
