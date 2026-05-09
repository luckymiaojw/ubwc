//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-04-24  03:42:51
// Module Name       : ubwc_enc_line_to_tile.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//      Revision 1.00 - File Created by      : MiaoJiawang
//      Description                           :
//
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

`default_nettype none

module ubwc_enc_line_to_tile#(
    parameter                                       ADDR_W                          = 16
)(
    input   wire                                        clk                             ,
    input   wire                                        rst_n                           ,

    // static config
    input   wire    [2                      :0]         cfg_format                      ,
    input   wire    [15                     :0]         cfg_y_tile_cols                 ,
    input   wire    [15                     :0]         cfg_uv_tile_cols                ,

    // A FIFO input
    // {fcnt[3:0], lcnt[11:0], vsync, hsync, tlast, tkeep[15:0], tdata[127:0]}
    input   wire                                        fifo_a_vld                      ,
    output  reg                                         fifo_a_rdy                      ,
    input   wire    [162                    :0]         fifo_a_data                     ,

    // B FIFO input
    input   wire                                        fifo_b_vld                      ,
    output  reg                                         fifo_b_rdy                      ,
    input   wire    [162                    :0]         fifo_b_data                     ,

    // bank0 single-port SRAM
    output  reg                                         bank0_en                        ,
    output  reg                                         bank0_wen                       ,
    output  reg     [ADDR_W              -1 :0]         bank0_addr                      ,
    output  reg     [127                    :0]         bank0_din                       ,
    input   wire    [127                    :0]         bank0_dout                      ,
    input   wire                                        bank0_dout_vld                  ,

    // bank1 single-port SRAM
    output  reg                                         bank1_en                        ,
    output  reg                                         bank1_wen                       ,
    output  reg     [ADDR_W              -1 :0]         bank1_addr                      ,
    output  reg     [127                    :0]         bank1_din                       ,
    input   wire    [127                    :0]         bank1_dout                      ,
    input   wire                                        bank1_dout_vld                  ,

    // tile output: 128bit
    output  wire                                        o_tile_vld                      ,
    input   wire                                        i_tile_rdy                      ,
    output  wire    [127                    :0]         o_tile_data                     ,
    output  wire    [15                     :0]         o_tile_keep                     ,
    output  wire                                        o_tile_last                     ,
    output  wire                                        o_plane                         , // 0:A 1:B
    output  wire    [15                     :0]         o_tile_x                        ,
    output  wire    [15                     :0]         o_tile_y                        , // Internally auto-counted Tile Y coordinate (0,1,2,3...)
    output  wire    [3                      :0]         o_tile_fcnt
);

    localparam                                      FMT_RGBA8888                    = 3'd0;
    localparam                                      FMT_RGBA10                      = 3'd1;
    localparam                                      FMT_YUV420_8                    = 3'd2;
    localparam                                      FMT_YUV420_10                   = 3'd3;
    localparam  [16                     :0]         SRAM_Y_LOWER_BASE_FULL          = (ADDR_W <= 12) ? 17'd1024 : 17'd2048;
    localparam  [16                     :0]         SRAM_UV_BASE_FULL               = (ADDR_W <= 12) ? 17'd2048 : 17'd4096;
    localparam                                      RD_IDLE                         = 2'd0;
    localparam                                      RD_ACT                          = 2'd1;
    localparam                                      RD_FIN                          = 2'd2;
    localparam  integer                             READ_META_FIFO_W                = 4 + 16 + 16 + 1 + 1 + 1;
    localparam  integer                             READ_META_FIFO_DEPTH            = 16;
    localparam  integer                             READ_META_FIFO_PROG_DEPTH       = 4;
    localparam  integer                             RESP_FIFO_W                     = 128 + 16 + 1 + 1 + 16 + 16 + 4;
    localparam  integer                             RESP_FIFO_DEPTH                 = 8;
    localparam  integer                             RESP_FIFO_AF_LEVEL              = RESP_FIFO_DEPTH - 2;
    localparam  integer                             RESP_FIFO_PROG_DEPTH            = RESP_FIFO_DEPTH - RESP_FIFO_AF_LEVEL;

    wire                                            is_rgba                         ;
    wire                                            is_yuv420                       ;
    wire                                            is_yuv420_10                    ;
    wire                                            need_b                          ;
    wire                                            format_supported                ;
    wire        [ADDR_W              -1 :0]         sram_y_lower_base               ;
    wire        [ADDR_W              -1 :0]         sram_uv_base                    ;
    wire                                            is_rgba_format                  ;
    wire                                            is_g016_format                  ;
    wire                                            is_yuv_8_format                 ;
    wire        [15                     :0]         a_tile_row_words                ;
    wire        [15                     :0]         b_tile_row_words                ;
    wire        [1                      :0]         a_tile_row_words_shift          ;
    wire        [1                      :0]         b_tile_row_words_shift          ;
    wire        [15                     :0]         cfg_tile_h_act                  ;
    wire        [15                     :0]         a_total_lines                   ;
    wire        [15                     :0]         b_total_lines                   ;
    wire                                            fifo_a_skid_vld                 ;
    wire                                            fifo_b_skid_vld                 ;
    wire        [162                    :0]         fifo_a_skid_data                ;
    wire        [162                    :0]         fifo_b_skid_data                ;
    wire                                            fifo_a_dec_accept               ;
    wire                                            fifo_b_dec_accept               ;
    wire                                            fifo_a_dec_load                 ;
    wire                                            fifo_b_dec_load                 ;
    wire                                            fifo_a_dec_vld_next             ;
    wire                                            fifo_b_dec_vld_next             ;
    wire        [11                     :0]         fifo_a_skid_lcnt                ;
    wire        [11                     :0]         fifo_b_skid_lcnt                ;
    wire        [15                     :0]         fifo_a_dec_group_id_next        ;
    wire        [15                     :0]         fifo_b_dec_group_id_next        ;
    wire        [3                      :0]         a_fcnt                          ;
    wire        [11                     :0]         a_lcnt                          ;
    wire                                            a_vsync                         ;
    wire                                            a_tlast                         ;
    wire        [127                    :0]         a_tdata                         ;
    wire        [3                      :0]         b_fcnt                          ;
    wire        [11                     :0]         b_lcnt                          ;
    wire                                            b_vsync                         ;
    wire                                            b_tlast                         ;
    wire        [127                    :0]         b_tdata                         ;
    wire        [15                     :0]         a_group_id                      ;
    wire        [15                     :0]         b_group_id                      ;
    wire                                            bank0_next_group_waiting_next   ;
    wire                                            bank1_next_group_waiting_next   ;
    wire                                            bank0_a_done_set                ;
    wire                                            bank0_b_done_set                ;
    wire                                            bank1_a_done_set                ;
    wire                                            bank1_b_done_set                ;
    wire                                            bank0_a_done_eff_next           ;
    wire                                            bank1_a_done_eff_next           ;
    wire                                            bank0_ready_for_read_next       ;
    wire                                            bank1_ready_for_read_next       ;
    wire                                            bank0_group_start               ;
    wire                                            bank1_group_start               ;
    wire                                            bank0_ready_for_read            ;
    wire                                            bank1_ready_for_read            ;
    wire                                            cur_bank_ready_for_read         ;
    wire                                            oth_bank_sel                    ;
    wire                                            oth_bank_ready_for_read         ;
    wire                                            oth_bank_is_reading             ;
    wire                                            oth_bank_free_for_write         ;
    wire                                            write_side_block                ;
    wire                                            wr_bank_switch                  ;
    wire                                            wr_bank_sel_eff                 ;
    wire                                            sel_group_vld                   ;
    wire        [15                     :0]         sel_group_id                    ;
    wire        [3                      :0]         sel_bank_fcnt                   ;
    wire                                            sel_group_start                 ;
    wire                                            sel_a_done                      ;
    wire                                            sel_b_done                      ;
    wire                                            fifo_a_bank_ok                  ;
    wire                                            fifo_b_bank_ok                  ;
    wire                                            fifo_a_group_ok                 ;
    wire                                            fifo_b_group_ok                 ;
    wire                                            fifo_a_can_fire                 ;
    wire                                            fifo_b_can_fire                 ;
    wire                                            fire_a                          ;
    wire                                            fire_b                          ;
    wire                                            write_input_seen                ;
    wire                                            bank0_safe_for_read             ;
    wire                                            bank1_safe_for_read             ;
    wire                                            fifo_a_skid_push                ;
    wire                                            fifo_b_skid_push                ;
    wire                                            fifo_a_skid_pop                 ;
    wire                                            fifo_b_skid_pop                 ;
    wire        [2                      :0]         fifo_a_skid_count_calc          ;
    wire        [2                      :0]         fifo_b_skid_count_calc          ;
    wire        [1                      :0]         fifo_a_skid_count_next          ;
    wire        [1                      :0]         fifo_b_skid_count_next          ;
    wire        [ADDR_W              -1 :0]         addr_inc_one                    ;
    wire        [ADDR_W              -1 :0]         addr_inc_two                    ;
    wire        [ADDR_W              -1 :0]         addr_inc_four                   ;
    wire        [ADDR_W              -1 :0]         addr_inc_thirteen               ;
    wire        [ADDR_W              -1 :0]         addr_inc_fifteen                ;
    wire        [ADDR_W              -1 :0]         a_wr_line_step                  ;
    wire        [ADDR_W              -1 :0]         b_wr_line_step                  ;
    wire        [ADDR_W              -1 :0]         a_wr_next_tile_step             ;
    wire        [ADDR_W              -1 :0]         b_wr_next_tile_step             ;
    wire                                            bank0_a_word_end                ;
    wire                                            bank0_b_word_end                ;
    wire                                            bank1_a_word_end                ;
    wire                                            bank1_b_word_end                ;
    wire                                            bank0_a_lower_base_next         ;
    wire                                            bank1_a_lower_base_next         ;
    wire        [ADDR_W              -1 :0]         bank0_a_wr_line_base_next       ;
    wire        [ADDR_W              -1 :0]         bank1_a_wr_line_base_next       ;
    wire        [ADDR_W              -1 :0]         bank0_b_wr_line_base_next       ;
    wire        [ADDR_W              -1 :0]         bank1_b_wr_line_base_next       ;
    wire        [ADDR_W              -1 :0]         a_wr_addr_cur                   ;
    wire        [ADDR_W              -1 :0]         b_wr_addr_cur                   ;
    wire        [15                     :0]         cur_tile_cols                   ;
    wire        [15                     :0]         rd_read_y                       ;
    wire                                            last_word_in_tile               ;
    wire                                            read_meta_fifo_full             ;
    wire                                            read_meta_fifo_almost_full      ;
    wire                                            read_meta_fifo_empty            ;
    wire                                            read_meta_fifo_valid            ;
    wire        [READ_META_FIFO_W    -1 :0]         read_meta_fifo_din              ;
    wire        [READ_META_FIFO_W    -1 :0]         read_meta_fifo_dout             ;
    wire                                            read_meta_fifo_wr_en            ;
    wire                                            read_meta_fifo_rd_en            ;
    wire                                            read_meta_bank_sel              ;
    wire                                            read_meta_last                  ;
    wire                                            read_meta_plane                 ;
    wire        [15                     :0]         read_meta_x                     ;
    wire        [15                     :0]         read_meta_y                     ;
    wire        [3                      :0]         read_meta_fcnt                  ;
    wire                                            resp_fifo_full                  ;
    wire                                            resp_fifo_almost_full           ;
    wire                                            resp_fifo_empty                 ;
    wire                                            resp_fifo_valid                 ;
    wire        [RESP_FIFO_W         -1 :0]         resp_fifo_din                   ;
    wire        [RESP_FIFO_W         -1 :0]         resp_fifo_dout                  ;
    wire                                            resp_fifo_wr_en                 ;
    wire                                            resp_fifo_rd_en                 ;
    wire                                            issue_read                      ;
    wire                                            read_grant                      ;
    wire                                            read_data_vld                   ;
    wire        [127                    :0]         read_data                       ;
    wire                                            a_wr_bank0                      ;
    wire                                            b_wr_bank0                      ;
    wire                                            a_wr_bank1                      ;
    wire                                            b_wr_bank1                      ;
    wire                                            do_wr_bank0                     ;
    wire                                            do_wr_bank1                     ;
    wire        [ADDR_W              -1 :0]         wr_addr_bank0                   ;
    wire        [ADDR_W              -1 :0]         wr_addr_bank1                   ;
    wire        [127                    :0]         wr_data_bank0                   ;
    wire        [127                    :0]         wr_data_bank1                   ;
    wire                                            rd_bank0                        ;
    wire                                            rd_bank1                        ;
    wire                                            bank0_en_next                   ;
    wire                                            bank0_wen_next                  ;
    wire        [ADDR_W              -1 :0]         bank0_addr_next                 ;
    wire        [127                    :0]         bank0_din_next                  ;
    wire                                            bank1_en_next                   ;
    wire                                            bank1_wen_next                  ;
    wire        [ADDR_W              -1 :0]         bank1_addr_next                 ;
    wire        [127                    :0]         bank1_din_next                  ;
    wire                                            rd_bank_release                 ;
    wire                                            bank0_release                   ;
    wire                                            bank1_release                   ;
    wire                                            bank0_fire_a                    ;
    wire                                            bank0_fire_b                    ;
    wire                                            bank0_fire                      ;
    wire                                            bank0_fire_vsync                ;
    wire        [3                      :0]         bank0_fire_fcnt                 ;
    wire        [15                     :0]         bank0_fire_group                ;
    wire                                            bank0_group_load                ;
    wire                                            bank1_fire_a                    ;
    wire                                            bank1_fire_b                    ;
    wire                                            bank1_fire                      ;
    wire                                            bank1_fire_vsync                ;
    wire        [3                      :0]         bank1_fire_fcnt                 ;
    wire        [15                     :0]         bank1_fire_group                ;
    wire                                            bank1_group_load                ;
    wire                                            rd_state_idle                   ;
    wire                                            rd_state_act                    ;
    wire                                            rd_state_fin                    ;
    wire                                            rd_state_invalid                ;
    wire                                            rd_start_bank0                  ;
    wire                                            rd_start_bank1                  ;
    wire                                            rd_start                        ;
    wire                                            rd_start_vsync                  ;
    wire        [3                      :0]         rd_start_fcnt                   ;
    wire        [15                     :0]         rd_start_group_y                ;
    wire                                            rd_read_advance                 ;
    wire                                            rd_last_col                     ;
    wire                                            rd_last_tile_word               ;
    wire                                            rd_advance_word                 ;
    wire                                            rd_advance_tile                 ;
    wire                                            rd_yuv_y_first_subrow_done      ;
    wire                                            rd_yuv_y_second_subrow_done     ;
    wire                                            rd_non_yuv_to_b                 ;
    wire                                            rd_frame_read_done              ;
    wire                                            rd_return_idle                  ;
    wire                                            rd_reset_tile_x                 ;
    wire                                            rd_reset_word                   ;
    wire                                            rd_load_y_lower_addr            ;
    wire                                            rd_load_uv_addr                 ;
    wire                                            rd_load_region_addr             ;
    wire        [ADDR_W              -1 :0]         rd_region_addr_next             ;

    reg         [1                      :0]         fifo_a_skid_count               ;
    reg         [162                    :0]         fifo_a_skid_data0               ;
    reg         [162                    :0]         fifo_a_skid_data1               ;
    reg         [1                      :0]         fifo_b_skid_count               ;
    reg         [162                    :0]         fifo_b_skid_data0               ;
    reg         [162                    :0]         fifo_b_skid_data1               ;
    reg                                             fifo_a_dec_vld                  ;
    reg         [162                    :0]         fifo_a_dec_data                 ;
    reg         [15                     :0]         fifo_a_dec_group_id             ;
    reg                                             fifo_b_dec_vld                  ;
    reg         [162                    :0]         fifo_b_dec_data                 ;
    reg         [15                     :0]         fifo_b_dec_group_id             ;
    reg                                             wr_bank_sel                     ;
    reg                                             rd_bank_sel_act                 ;
    reg         [1                      :0]         rd_state                        ;
    reg         [15                     :0]         bank0_a_line_idx                ;
    reg         [15                     :0]         bank0_a_tile_x                  ;
    reg         [15                     :0]         bank0_a_word_in_tile            ;
    reg         [15                     :0]         bank0_b_line_idx                ;
    reg         [15                     :0]         bank0_b_tile_x                  ;
    reg         [15                     :0]         bank0_b_word_in_tile            ;
    reg                                             bank0_a_done                    ;
    reg                                             bank0_b_done                    ;
    reg                                             bank0_meta_vld                  ;
    reg         [15                     :0]         bank0_group_id                  ;
    reg                                             bank0_group_vld                 ;
    reg                                             bank0_next_group_waiting_r      ;
    reg                                             bank0_a_done_eff_r              ;
    reg                                             bank0_ready_for_read_r          ;
    reg         [3                      :0]         bank0_fcnt                      ;
    reg                                             bank0_vsync                     ; // Latch vsync
    reg         [ADDR_W              -1 :0]         bank0_a_wr_addr                 ;
    reg         [ADDR_W              -1 :0]         bank0_a_wr_line_base            ;
    reg         [ADDR_W              -1 :0]         bank0_b_wr_addr                 ;
    reg         [ADDR_W              -1 :0]         bank0_b_wr_line_base            ;
    reg         [15                     :0]         bank1_a_line_idx                ;
    reg         [15                     :0]         bank1_a_tile_x                  ;
    reg         [15                     :0]         bank1_a_word_in_tile            ;
    reg         [15                     :0]         bank1_b_line_idx                ;
    reg         [15                     :0]         bank1_b_tile_x                  ;
    reg         [15                     :0]         bank1_b_word_in_tile            ;
    reg                                             bank1_a_done                    ;
    reg                                             bank1_b_done                    ;
    reg                                             bank1_meta_vld                  ;
    reg         [15                     :0]         bank1_group_id                  ;
    reg                                             bank1_group_vld                 ;
    reg                                             bank1_next_group_waiting_r      ;
    reg                                             bank1_a_done_eff_r              ;
    reg                                             bank1_ready_for_read_r          ;
    reg         [3                      :0]         bank1_fcnt                      ;
    reg                                             bank1_vsync                     ; // Latch vsync
    reg         [ADDR_W              -1 :0]         bank1_a_wr_addr                 ;
    reg         [ADDR_W              -1 :0]         bank1_a_wr_line_base            ;
    reg         [ADDR_W              -1 :0]         bank1_b_wr_addr                 ;
    reg         [ADDR_W              -1 :0]         bank1_b_wr_line_base            ;
    reg                                             rd_plane                        ;
    reg                                             rd_y_subrow                     ;
    reg         [15                     :0]         rd_tile_x                       ;
    reg         [15                     :0]         rd_word_in_tile                 ;
    reg         [15                     :0]         rd_group_y                      ;
    reg         [3                      :0]         rd_fcnt                         ;
    reg         [ADDR_W              -1 :0]         rd_addr_cur                     ;
    reg         [15                     :0]         rd_tile_grp_y_cnt               ; // Read-side core Tile Y row counter

    // ------------------------------------------------------------------------
    // Format MUX (lookup-table based, eliminating runtime calculations)
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // Registered input skid buffers
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // Decode stage.  This cuts skid-payload decode out of the write fire path.
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // Bank Bookkeeping & 2D Counters
    // ------------------------------------------------------------------------

    assign is_rgba                       = (cfg_format == FMT_RGBA8888) || (cfg_format == FMT_RGBA10);
    assign is_yuv420                     = (cfg_format == FMT_YUV420_8) || (cfg_format == FMT_YUV420_10);
    assign is_yuv420_10                  = (cfg_format == FMT_YUV420_10);
    assign need_b                        = is_yuv420;
    assign format_supported              = is_rgba || is_yuv420;
    assign sram_y_lower_base             = SRAM_Y_LOWER_BASE_FULL[ADDR_W-1:0];
    assign sram_uv_base                  = SRAM_UV_BASE_FULL[ADDR_W-1:0];
    assign is_rgba_format                = is_rgba;
    assign is_g016_format                = is_yuv420_10;
    assign is_yuv_8_format               = (cfg_format == FMT_YUV420_8);
    assign a_tile_row_words              = (is_rgba_format || is_g016_format) ? 16'd4 :
                                           is_yuv_8_format                    ? 16'd2 :
                                                                                16'd0;
    assign b_tile_row_words              = is_rgba_format  ? 16'd0 :
                                           is_g016_format  ? 16'd4 :
                                           is_yuv_8_format ? 16'd2 :
                                                             16'd0;
    assign a_tile_row_words_shift        = (is_rgba_format || is_g016_format) ? 2'd2 :
                                           is_yuv_8_format                    ? 2'd1 :
                                                                                2'd0;
    assign b_tile_row_words_shift        = is_rgba_format  ? 2'd0 :
                                           is_g016_format  ? 2'd2 :
                                           is_yuv_8_format ? 2'd1 :
                                                             2'd0;
    assign cfg_tile_h_act                = (is_rgba_format || is_g016_format) ? 16'd4 :
                                           is_yuv_8_format                    ? 16'd8 :
                                                                                16'd0;
    assign a_total_lines                 = is_yuv420 ? {cfg_tile_h_act[14:0], 1'b0} : cfg_tile_h_act;
    assign b_total_lines                 = cfg_tile_h_act;
    assign fifo_a_skid_vld               = (fifo_a_skid_count != 2'd0);
    assign fifo_b_skid_vld               = (fifo_b_skid_count != 2'd0);
    assign fifo_a_skid_data              = fifo_a_skid_data0;
    assign fifo_b_skid_data              = fifo_b_skid_data0;
    assign fifo_a_skid_lcnt              = fifo_a_skid_data[158:147];
    assign fifo_b_skid_lcnt              = fifo_b_skid_data[158:147];
    assign fifo_a_dec_group_id_next      = is_yuv420_10 ? {7'd0, fifo_a_skid_lcnt[11:3]} :
                                                          {8'd0, fifo_a_skid_lcnt[11:4]};
    assign fifo_b_dec_group_id_next      = is_yuv420_10 ? {7'd0, fifo_b_skid_lcnt[11:3]} :
                                                          {8'd0, fifo_b_skid_lcnt[11:4]};
    assign a_fcnt                        = fifo_a_dec_data[162:159];
    assign a_lcnt                        = fifo_a_dec_data[158:147];
    assign a_vsync                       = fifo_a_dec_data[146];
    assign a_tlast                       = fifo_a_dec_data[144];
    assign a_tdata                       = fifo_a_dec_data[127:0];
    assign b_fcnt                        = fifo_b_dec_data[162:159];
    assign b_lcnt                        = fifo_b_dec_data[158:147];
    assign b_vsync                       = fifo_b_dec_data[146];
    assign b_tlast                       = fifo_b_dec_data[144];
    assign b_tdata                       = fifo_b_dec_data[127:0];
    assign a_group_id                    = fifo_a_dec_group_id;
    assign b_group_id                    = fifo_b_dec_group_id;
    assign bank0_next_group_waiting_next = is_yuv420 && (wr_bank_sel == 1'b0) &&
                                           bank0_group_vld &&
                                           ((fifo_a_dec_vld && (a_group_id != bank0_group_id)) ||
                                           (need_b && fifo_b_dec_vld && (b_group_id != bank0_group_id)));
    assign bank1_next_group_waiting_next = is_yuv420 && (wr_bank_sel == 1'b1) &&
                                           bank1_group_vld &&
                                           ((fifo_a_dec_vld && (a_group_id != bank1_group_id)) ||
                                           (need_b && fifo_b_dec_vld && (b_group_id != bank1_group_id)));
    assign bank0_group_start             = (bank0_a_line_idx == 16'd0) &&
                                           (bank0_a_tile_x == 16'd0) &&
                                           (bank0_a_word_in_tile == 16'd0) &&
                                           (bank0_b_line_idx == 16'd0) &&
                                           (bank0_b_tile_x == 16'd0) &&
                                           (bank0_b_word_in_tile == 16'd0) &&
                                           !bank0_a_done &&
                                           !bank0_b_done;
    assign bank1_group_start             = (bank1_a_line_idx == 16'd0) &&
                                           (bank1_a_tile_x == 16'd0) &&
                                           (bank1_a_word_in_tile == 16'd0) &&
                                           (bank1_b_line_idx == 16'd0) &&
                                           (bank1_b_tile_x == 16'd0) &&
                                           (bank1_b_word_in_tile == 16'd0) &&
                                           !bank1_a_done &&
                                           !bank1_b_done;
    assign cur_bank_ready_for_read       = (wr_bank_sel == 1'b0) ? bank0_ready_for_read :
                                                                   bank1_ready_for_read;
    assign oth_bank_sel                  = ~wr_bank_sel;
    assign oth_bank_ready_for_read       = (oth_bank_sel == 1'b0) ? bank0_ready_for_read :
                                                                    bank1_ready_for_read;
    assign oth_bank_is_reading           = (rd_state != RD_IDLE) && (rd_bank_sel_act == oth_bank_sel);
    assign oth_bank_free_for_write       = (!oth_bank_ready_for_read) && (!oth_bank_is_reading);
    assign write_side_block              = cur_bank_ready_for_read && !oth_bank_free_for_write;
    assign wr_bank_switch                = cur_bank_ready_for_read && oth_bank_free_for_write;
    assign wr_bank_sel_eff               = wr_bank_switch ? ~wr_bank_sel : wr_bank_sel;
    assign sel_group_vld                 = (wr_bank_sel_eff == 1'b0) ? (bank0_group_vld && bank0_meta_vld) :
                                           (bank1_group_vld && bank1_meta_vld);
    assign sel_group_id                  = (wr_bank_sel_eff == 1'b0) ? bank0_group_id : bank1_group_id;
    assign sel_bank_fcnt                 = (wr_bank_sel_eff == 1'b0) ? bank0_fcnt : bank1_fcnt;
    assign sel_group_start               = (wr_bank_sel_eff == 1'b0) ? bank0_group_start : bank1_group_start;
    assign sel_a_done                    = (wr_bank_sel_eff == 1'b0) ? bank0_a_done : bank1_a_done;
    assign sel_b_done                    = (wr_bank_sel_eff == 1'b0) ? bank0_b_done : bank1_b_done;
    assign fifo_a_bank_ok                = !(is_yuv420 && need_b && sel_a_done && !sel_b_done);
    assign fifo_b_bank_ok                = !(is_yuv420 && need_b && sel_b_done && !sel_a_done);
    assign fifo_a_group_ok               = !is_yuv420 || !sel_group_vld ||
                                           a_vsync ||
                                           (a_fcnt != sel_bank_fcnt) ||
                                           (sel_group_start && (a_group_id > sel_group_id)) ||
                                           (a_group_id <= sel_group_id);
    assign fifo_b_group_ok               = !is_yuv420 || !sel_group_vld ||
                                           b_vsync ||
                                           (b_fcnt != sel_bank_fcnt) ||
                                           (sel_group_start && (b_group_id > sel_group_id)) ||
                                           (b_group_id <= sel_group_id);
    assign bank0_ready_for_read          = bank0_ready_for_read_r;
    assign bank1_ready_for_read          = bank1_ready_for_read_r;
    assign fifo_a_dec_accept             = !fifo_a_dec_vld || fire_a;
    assign fifo_b_dec_accept             = !fifo_b_dec_vld || fire_b;
    assign fifo_a_dec_load               = fifo_a_skid_vld && fifo_a_dec_accept;
    assign fifo_b_dec_load               = need_b && fifo_b_skid_vld && fifo_b_dec_accept;
    assign fifo_a_dec_vld_next           = (fifo_a_dec_vld && !fire_a) || fifo_a_dec_load;
    assign fifo_b_dec_vld_next           = (fifo_b_dec_vld && !fire_b) || fifo_b_dec_load;
    assign fifo_a_skid_pop               = fifo_a_dec_load;
    assign fifo_b_skid_pop               = fifo_b_dec_load;
    assign fifo_a_can_fire               = format_supported && fifo_a_dec_vld &&
                                           fifo_a_bank_ok && fifo_a_group_ok;
    assign fifo_b_can_fire               = need_b && fifo_b_dec_vld &&
                                           fifo_b_bank_ok && fifo_b_group_ok;
    assign fire_a                        = !write_side_block && fifo_a_can_fire;
    assign fire_b                        = !write_side_block && !fifo_a_can_fire && fifo_b_can_fire;
    assign write_input_seen              = fifo_a_dec_vld || fifo_a_skid_vld ||
                                           (need_b && (fifo_b_dec_vld || fifo_b_skid_vld));
    assign bank0_safe_for_read           = bank0_ready_for_read &&
                                           ((wr_bank_sel != 1'b0) || !write_input_seen);
    assign bank1_safe_for_read           = bank1_ready_for_read &&
                                           ((wr_bank_sel != 1'b1) || !write_input_seen);
    assign fifo_a_skid_push              = fifo_a_vld && fifo_a_rdy;
    assign fifo_b_skid_push              = fifo_b_vld && fifo_b_rdy;
    assign fifo_a_skid_count_calc        = {1'b0, fifo_a_skid_count} +
                                            {2'd0, fifo_a_skid_push} -
                                            {2'd0, fifo_a_skid_pop};
    assign fifo_b_skid_count_calc        = {1'b0, fifo_b_skid_count} +
                                            {2'd0, fifo_b_skid_push} -
                                            {2'd0, fifo_b_skid_pop};
    assign fifo_a_skid_count_next        = fifo_a_skid_count_calc[1:0];
    assign fifo_b_skid_count_next        = fifo_b_skid_count_calc[1:0];
    assign addr_inc_one                  = {{(ADDR_W-1){1'b0}}, 1'b1};
    assign addr_inc_two                  = {{(ADDR_W-2){1'b0}}, 2'd2};
    assign addr_inc_four                 = {{(ADDR_W-3){1'b0}}, 3'd4};
    assign addr_inc_thirteen             = {{(ADDR_W-4){1'b0}}, 4'd13};
    assign addr_inc_fifteen              = {{(ADDR_W-4){1'b0}}, 4'd15};
    assign a_wr_line_step                = (a_tile_row_words_shift == 2'd2) ? addr_inc_four :
                                           (a_tile_row_words_shift == 2'd1) ? addr_inc_two  :
                                                                              {ADDR_W{1'b0}};
    assign b_wr_line_step                = (b_tile_row_words_shift == 2'd2) ? addr_inc_four :
                                           (b_tile_row_words_shift == 2'd1) ? addr_inc_two  :
                                                                              {ADDR_W{1'b0}};
    assign a_wr_next_tile_step           = (a_tile_row_words_shift == 2'd2) ? addr_inc_thirteen :
                                           (a_tile_row_words_shift == 2'd1) ? addr_inc_fifteen  :
                                                                              addr_inc_one;
    assign b_wr_next_tile_step           = (b_tile_row_words_shift == 2'd2) ? addr_inc_thirteen :
                                           (b_tile_row_words_shift == 2'd1) ? addr_inc_fifteen  :
                                                                              addr_inc_one;
    assign bank0_a_word_end              = (bank0_a_word_in_tile + 16'd1 >= a_tile_row_words);
    assign bank0_b_word_end              = (bank0_b_word_in_tile + 16'd1 >= b_tile_row_words);
    assign bank1_a_word_end              = (bank1_a_word_in_tile + 16'd1 >= a_tile_row_words);
    assign bank1_b_word_end              = (bank1_b_word_in_tile + 16'd1 >= b_tile_row_words);
    assign bank0_a_lower_base_next       = is_yuv420_10 ? (bank0_a_line_idx == 16'd3) :
                                           (is_yuv420 && (bank0_a_line_idx == 16'd7));
    assign bank1_a_lower_base_next       = is_yuv420_10 ? (bank1_a_line_idx == 16'd3) :
                                           (is_yuv420 && (bank1_a_line_idx == 16'd7));
    assign bank0_a_wr_line_base_next     = bank0_a_lower_base_next ? sram_y_lower_base :
                                           (bank0_a_wr_line_base + a_wr_line_step);
    assign bank1_a_wr_line_base_next     = bank1_a_lower_base_next ? sram_y_lower_base :
                                           (bank1_a_wr_line_base + a_wr_line_step);
    assign bank0_b_wr_line_base_next     = bank0_b_wr_line_base + b_wr_line_step;
    assign bank1_b_wr_line_base_next     = bank1_b_wr_line_base + b_wr_line_step;
    assign a_wr_addr_cur                 = (wr_bank_sel_eff == 1'b0) ? bank0_a_wr_addr :
                                                                       bank1_a_wr_addr;
    assign b_wr_addr_cur                 = (wr_bank_sel_eff == 1'b0) ? bank0_b_wr_addr :
                                                                       bank1_b_wr_addr;
    assign cur_tile_cols                 = (rd_plane == 1'b0) ? cfg_y_tile_cols : cfg_uv_tile_cols;
    assign rd_read_y                     = (is_yuv420 && !rd_plane) ?
                                                                      {rd_group_y[14:0], rd_y_subrow} :
                                                                      rd_group_y;
    assign issue_read                    = (rd_state == RD_ACT) &&
                                           !resp_fifo_almost_full &&
                                           !read_meta_fifo_almost_full;
    assign read_meta_fifo_din            = {rd_fcnt, rd_read_y, rd_tile_x,
                                            rd_plane, last_word_in_tile, rd_bank_sel_act};
    assign read_meta_fifo_wr_en          = read_grant;
    assign read_meta_bank_sel            = read_meta_fifo_dout[0];
    assign read_meta_last                = read_meta_fifo_dout[1];
    assign read_meta_plane               = read_meta_fifo_dout[2];
    assign read_meta_x                   = read_meta_fifo_dout[3  +: 16];
    assign read_meta_y                   = read_meta_fifo_dout[19 +: 16];
    assign read_meta_fcnt                = read_meta_fifo_dout[READ_META_FIFO_W-1 -: 4];
    assign read_data_vld                 = read_meta_fifo_valid &&
                                           (read_meta_bank_sel ? bank1_dout_vld : bank0_dout_vld);
    assign read_data                     = read_meta_bank_sel ? bank1_dout : bank0_dout;
    assign read_meta_fifo_rd_en          = read_data_vld;
    assign resp_fifo_din                 = {read_meta_fcnt, read_meta_y, read_meta_x,
                                            read_meta_plane, read_meta_last, 16'hFFFF, read_data};
    assign resp_fifo_wr_en               = read_data_vld;
    assign resp_fifo_rd_en               = resp_fifo_valid && i_tile_rdy;
    assign o_tile_vld                    = resp_fifo_valid;
    assign o_tile_data                   = resp_fifo_dout[0   +: 128];
    assign o_tile_keep                   = resp_fifo_dout[128 +: 16];
    assign o_tile_last                   = resp_fifo_dout[144];
    assign o_plane                       = resp_fifo_dout[145];
    assign o_tile_x                      = resp_fifo_dout[146 +: 16];
    assign o_tile_y                      = resp_fifo_dout[162 +: 16];
    assign o_tile_fcnt                   = resp_fifo_dout[RESP_FIFO_W-1 -: 4];
    assign a_wr_bank0                    = fire_a && (wr_bank_sel_eff == 1'b0);
    assign b_wr_bank0                    = fire_b && (wr_bank_sel_eff == 1'b0);
    assign a_wr_bank1                    = fire_a && (wr_bank_sel_eff == 1'b1);
    assign b_wr_bank1                    = fire_b && (wr_bank_sel_eff == 1'b1);
    assign do_wr_bank0                   = a_wr_bank0 || b_wr_bank0;
    assign do_wr_bank1                   = a_wr_bank1 || b_wr_bank1;
    assign wr_addr_bank0                 = a_wr_bank0 ? a_wr_addr_cur :
                                           b_wr_bank0 ? b_wr_addr_cur :
                                                        {ADDR_W{1'b0}};
    assign wr_addr_bank1                 = a_wr_bank1 ? a_wr_addr_cur :
                                           b_wr_bank1 ? b_wr_addr_cur :
                                                        {ADDR_W{1'b0}};
    assign wr_data_bank0                 = a_wr_bank0 ? a_tdata :
                                           b_wr_bank0 ? b_tdata :
                                                        128'd0;
    assign wr_data_bank1                 = a_wr_bank1 ? a_tdata :
                                           b_wr_bank1 ? b_tdata :
                                                        128'd0;
    assign read_grant                    = issue_read;
    assign rd_bank0                      = read_grant && (rd_bank_sel_act == 1'b0);
    assign rd_bank1                      = read_grant && (rd_bank_sel_act == 1'b1);
    assign bank0_en_next                 = do_wr_bank0 || rd_bank0;
    assign bank0_wen_next                = do_wr_bank0;
    assign bank0_addr_next               = do_wr_bank0 ? wr_addr_bank0 :
                                           rd_bank0    ? rd_addr_cur :
                                                         {ADDR_W{1'b0}};
    assign bank0_din_next                = do_wr_bank0 ? wr_data_bank0 : 128'd0;
    assign bank1_en_next                 = do_wr_bank1 || rd_bank1;
    assign bank1_wen_next                = do_wr_bank1;
    assign bank1_addr_next               = do_wr_bank1 ? wr_addr_bank1 :
                                           rd_bank1    ? rd_addr_cur :
                                                         {ADDR_W{1'b0}};
    assign bank1_din_next                = do_wr_bank1 ? wr_data_bank1 : 128'd0;
    assign last_word_in_tile             = (rd_word_in_tile == 16'd15);
    assign rd_bank_release               = (rd_state == RD_FIN) && resp_fifo_empty && read_meta_fifo_empty;
    assign bank0_release                 = rd_bank_release && (rd_bank_sel_act == 1'b0);
    assign bank1_release                 = rd_bank_release && (rd_bank_sel_act == 1'b1);
    assign bank0_fire_a                  = fire_a && (wr_bank_sel_eff == 1'b0);
    assign bank0_fire_b                  = fire_b && (wr_bank_sel_eff == 1'b0);
    assign bank0_fire                    = bank0_fire_a || bank0_fire_b;
    assign bank0_fire_vsync              = (bank0_fire_a && a_vsync) ||
                                           (bank0_fire_b && b_vsync);
    assign bank0_fire_fcnt               = bank0_fire_a ? a_fcnt : b_fcnt;
    assign bank0_fire_group              = bank0_fire_a ? a_group_id : b_group_id;
    assign bank0_group_load              = bank0_fire && is_yuv420 &&
                                           (bank0_fire_vsync ||
                                           !bank0_group_vld ||
                                           !bank0_meta_vld ||
                                           (bank0_group_start && (bank0_fire_group > bank0_group_id)) ||
                                           (bank0_fire_group < bank0_group_id) ||
                                           (bank0_fcnt != bank0_fire_fcnt));
    assign bank1_fire_a                  = fire_a && (wr_bank_sel_eff == 1'b1);
    assign bank1_fire_b                  = fire_b && (wr_bank_sel_eff == 1'b1);
    assign bank1_fire                    = bank1_fire_a || bank1_fire_b;
    assign bank1_fire_vsync              = (bank1_fire_a && a_vsync) ||
                                           (bank1_fire_b && b_vsync);
    assign bank1_fire_fcnt               = bank1_fire_a ? a_fcnt : b_fcnt;
    assign bank1_fire_group              = bank1_fire_a ? a_group_id : b_group_id;
    assign bank1_group_load              = bank1_fire && is_yuv420 &&
                                           (bank1_fire_vsync ||
                                           !bank1_group_vld ||
                                           !bank1_meta_vld ||
                                           (bank1_group_start && (bank1_fire_group > bank1_group_id)) ||
                                           (bank1_fire_group < bank1_group_id) ||
                                           (bank1_fcnt != bank1_fire_fcnt));
    assign bank0_a_done_set              = bank0_fire_a && a_tlast &&
                                           (bank0_a_line_idx + 16'd1 >= a_total_lines);
    assign bank0_b_done_set              = bank0_fire_b && b_tlast &&
                                           (bank0_b_line_idx + 16'd1 >= b_total_lines);
    assign bank1_a_done_set              = bank1_fire_a && a_tlast &&
                                           (bank1_a_line_idx + 16'd1 >= a_total_lines);
    assign bank1_b_done_set              = bank1_fire_b && b_tlast &&
                                           (bank1_b_line_idx + 16'd1 >= b_total_lines);
    assign bank0_a_done_eff_next         = bank0_a_done_eff_r ||
                                           bank0_a_done ||
                                           bank0_a_done_set ||
                                           (bank0_next_group_waiting_r &&
                                           (bank0_a_line_idx + 16'd1 >= a_total_lines));
    assign bank1_a_done_eff_next         = bank1_a_done_eff_r ||
                                           bank1_a_done ||
                                           bank1_a_done_set ||
                                           (bank1_next_group_waiting_r &&
                                           (bank1_a_line_idx + 16'd1 >= a_total_lines));
    assign bank0_ready_for_read_next     = bank0_ready_for_read_r ||
                                           (bank0_a_done_eff_next &&
                                           (!need_b || bank0_b_done || bank0_b_done_set));
    assign bank1_ready_for_read_next     = bank1_ready_for_read_r ||
                                           (bank1_a_done_eff_next &&
                                           (!need_b || bank1_b_done || bank1_b_done_set));
    assign rd_state_idle                 = (rd_state == RD_IDLE);
    assign rd_state_act                  = (rd_state == RD_ACT);
    assign rd_state_fin                  = (rd_state == RD_FIN);
    assign rd_state_invalid              = !rd_state_idle && !rd_state_act && !rd_state_fin;
    assign rd_start_bank0                = rd_state_idle && bank0_safe_for_read;
    assign rd_start_bank1                = rd_state_idle && !bank0_safe_for_read && bank1_safe_for_read;
    assign rd_start                      = rd_start_bank0 || rd_start_bank1;
    assign rd_start_vsync                = rd_start_bank0 ? bank0_vsync : bank1_vsync;
    assign rd_start_fcnt                 = rd_start_bank0 ? bank0_fcnt : bank1_fcnt;
    assign rd_start_group_y              = rd_start_vsync ? 16'd0 : rd_tile_grp_y_cnt;
    assign rd_read_advance               = rd_state_act && read_grant;
    assign rd_last_col                   = (rd_tile_x + 16'd1 >= cur_tile_cols);
    assign rd_last_tile_word             = rd_read_advance && last_word_in_tile;
    assign rd_advance_word               = rd_read_advance && !last_word_in_tile;
    assign rd_advance_tile               = rd_last_tile_word && !rd_last_col;
    assign rd_yuv_y_first_subrow_done    = rd_last_tile_word && rd_last_col &&
                                           is_yuv420 && !rd_plane && !rd_y_subrow;
    assign rd_yuv_y_second_subrow_done   = rd_last_tile_word && rd_last_col &&
                                           is_yuv420 && !rd_plane && rd_y_subrow;
    assign rd_non_yuv_to_b               = rd_last_tile_word && rd_last_col &&
                                           !is_yuv420 && !rd_plane && need_b;
    assign rd_frame_read_done            = rd_last_tile_word && rd_last_col &&
                                           ((is_yuv420 && rd_plane) ||
                                           (!is_yuv420 && (rd_plane || !need_b)));
    assign rd_return_idle                = rd_state_fin && rd_bank_release;
    assign rd_reset_tile_x               = rd_yuv_y_first_subrow_done ||
                                           rd_yuv_y_second_subrow_done ||
                                           rd_non_yuv_to_b;
    assign rd_reset_word                 = rd_reset_tile_x || rd_advance_tile;
    assign rd_load_y_lower_addr          = rd_yuv_y_first_subrow_done;
    assign rd_load_uv_addr               = rd_yuv_y_second_subrow_done || rd_non_yuv_to_b;
    assign rd_load_region_addr           = rd_load_y_lower_addr || rd_load_uv_addr;
    assign rd_region_addr_next           = rd_load_y_lower_addr ? sram_y_lower_base :
                                           rd_load_uv_addr      ? sram_uv_base :
                                                                  {ADDR_W{1'b0}};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            fifo_a_rdy <= 1'b1;
        else
            fifo_a_rdy <= (fifo_a_skid_count_calc < 3'd2);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            fifo_b_rdy <= 1'b0;
        else
            fifo_b_rdy <= need_b && (fifo_b_skid_count_calc < 3'd2);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            fifo_a_skid_count <= 2'd0;
        else
            fifo_a_skid_count <= fifo_a_skid_count_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            fifo_b_skid_count <= 2'd0;
        else if (!need_b)
            fifo_b_skid_count <= 2'd0;
        else
            fifo_b_skid_count <= fifo_b_skid_count_next;
    end

    always @(posedge clk) begin
        if (fifo_a_skid_pop && (fifo_a_skid_count == 2'd2))
            fifo_a_skid_data0 <= fifo_a_skid_data1;
        else if (fifo_a_skid_pop && fifo_a_skid_push && (fifo_a_skid_count == 2'd1))
            fifo_a_skid_data0 <= fifo_a_data;
        else if (!fifo_a_skid_pop && fifo_a_skid_push && (fifo_a_skid_count == 2'd0))
            fifo_a_skid_data0 <= fifo_a_data;
    end

    always @(posedge clk) begin
        if (fifo_b_skid_pop && (fifo_b_skid_count == 2'd2))
            fifo_b_skid_data0 <= fifo_b_skid_data1;
        else if (fifo_b_skid_pop && fifo_b_skid_push && (fifo_b_skid_count == 2'd1))
            fifo_b_skid_data0 <= fifo_b_data;
        else if (!fifo_b_skid_pop && fifo_b_skid_push && (fifo_b_skid_count == 2'd0))
            fifo_b_skid_data0 <= fifo_b_data;
    end

    always @(posedge clk) begin
        if (fifo_a_skid_push && (fifo_a_skid_count == 2'd1) && !fifo_a_skid_pop)
            fifo_a_skid_data1 <= fifo_a_data;
    end

    always @(posedge clk) begin
        if (fifo_b_skid_push && (fifo_b_skid_count == 2'd1) && !fifo_b_skid_pop)
            fifo_b_skid_data1 <= fifo_b_data;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            fifo_a_dec_vld <= 1'b0;
        else
            fifo_a_dec_vld <= fifo_a_dec_vld_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            fifo_b_dec_vld <= 1'b0;
        else if (!need_b)
            fifo_b_dec_vld <= 1'b0;
        else
            fifo_b_dec_vld <= fifo_b_dec_vld_next;
    end

    always @(posedge clk) begin
        if (fifo_a_dec_load)
            fifo_a_dec_data <= fifo_a_skid_data;
    end

    always @(posedge clk) begin
        if (fifo_b_dec_load)
            fifo_b_dec_data <= fifo_b_skid_data;
    end

    always @(posedge clk) begin
        if (fifo_a_dec_load)
            fifo_a_dec_group_id <= fifo_a_dec_group_id_next;
    end

    always @(posedge clk) begin
        if (fifo_b_dec_load)
            fifo_b_dec_group_id <= fifo_b_dec_group_id_next;
    end

    // ------------------------------------------------------------------------
    // Write address increment controls
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // Read Side Signals & Counters
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // SRAM MUX & Combinational Data Output
    // ------------------------------------------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_en <= 1'b0;
        else
            bank0_en <= bank0_en_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_wen <= 1'b0;
        else
            bank0_wen <= bank0_wen_next;
    end

    always @(posedge clk) begin
        if (bank0_en_next)
            bank0_addr <= bank0_addr_next;
    end

    always @(posedge clk) begin
        if (bank0_wen_next)
            bank0_din <= bank0_din_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_en <= 1'b0;
        else
            bank1_en <= bank1_en_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_wen <= 1'b0;
        else
            bank1_wen <= bank1_wen_next;
    end

    always @(posedge clk) begin
        if (bank1_en_next)
            bank1_addr <= bank1_addr_next;
    end

    always @(posedge clk) begin
        if (bank1_wen_next)
            bank1_din <= bank1_din_next;
    end

    mg_sync_fifo
    #(
        .PROG_DEPTH                 ( READ_META_FIFO_PROG_DEPTH     ),
        .DWIDTH                     ( READ_META_FIFO_W              ),
        .DEPTH                      ( READ_META_FIFO_DEPTH          ),
        .SHOW_AHEAD                 ( 1                             )
    )
    u_read_meta_fifo
    (
        .clk                        ( clk                           ),
        .rst_n                      ( rst_n                         ),
        .sclr                       ( 1'b0                          ),
        .wr_en                      ( read_meta_fifo_wr_en          ),
        .din                        ( read_meta_fifo_din            ),
        .prog_full                  ( read_meta_fifo_almost_full    ),
        .full                       ( read_meta_fifo_full           ),
        .rd_en                      ( read_meta_fifo_rd_en          ),
        .empty                      ( read_meta_fifo_empty          ),
        .dout                       ( read_meta_fifo_dout           ),
        .valid                      ( read_meta_fifo_valid          ),
        .data_count                 (                               )
    );

    mg_sync_fifo
    #(
        .PROG_DEPTH                 ( RESP_FIFO_PROG_DEPTH          ),
        .DWIDTH                     ( RESP_FIFO_W                   ),
        .DEPTH                      ( RESP_FIFO_DEPTH               ),
        .SHOW_AHEAD                 ( 1                             )
    )
    u_resp_fifo
    (
        .clk                        ( clk                           ),
        .rst_n                      ( rst_n                         ),
        .sclr                       ( 1'b0                          ),
        .wr_en                      ( resp_fifo_wr_en               ),
        .din                        ( resp_fifo_din                 ),
        .prog_full                  ( resp_fifo_almost_full         ),
        .full                       ( resp_fifo_full                ),
        .rd_en                      ( resp_fifo_rd_en               ),
        .empty                      ( resp_fifo_empty               ),
        .dout                       ( resp_fifo_dout                ),
        .valid                      ( resp_fifo_valid               ),
        .data_count                 (                               )
    );

    // ------------------------------------------------------------------------
    // Write bank ownership
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_bank_sel <= 1'b0;
        end else if (wr_bank_switch) begin
            wr_bank_sel <= ~wr_bank_sel;
        end
    end

    // ------------------------------------------------------------------------
    // Bank write accept qualifiers
    // ------------------------------------------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_next_group_waiting_r <= 1'b0;
        else if (bank0_release)
            bank0_next_group_waiting_r <= 1'b0;
        else
            bank0_next_group_waiting_r <= bank0_next_group_waiting_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_next_group_waiting_r <= 1'b0;
        else if (bank1_release)
            bank1_next_group_waiting_r <= 1'b0;
        else
            bank1_next_group_waiting_r <= bank1_next_group_waiting_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_a_done_eff_r <= 1'b0;
        else if (bank0_release)
            bank0_a_done_eff_r <= 1'b0;
        else
            bank0_a_done_eff_r <= bank0_a_done_eff_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_a_done_eff_r <= 1'b0;
        else if (bank1_release)
            bank1_a_done_eff_r <= 1'b0;
        else
            bank1_a_done_eff_r <= bank1_a_done_eff_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_ready_for_read_r <= 1'b0;
        else if (bank0_release)
            bank0_ready_for_read_r <= 1'b0;
        else
            bank0_ready_for_read_r <= bank0_ready_for_read_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_ready_for_read_r <= 1'b0;
        else if (bank1_release)
            bank1_ready_for_read_r <= 1'b0;
        else
            bank1_ready_for_read_r <= bank1_ready_for_read_next;
    end

    // ------------------------------------------------------------------------
    // Bank0 incremental write addresses
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_a_wr_line_base <= {ADDR_W{1'b0}};
        else if (bank0_release)
            bank0_a_wr_line_base <= {ADDR_W{1'b0}};
        else if (bank0_fire_a && a_tlast)
            bank0_a_wr_line_base <= bank0_a_wr_line_base_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_a_wr_addr <= {ADDR_W{1'b0}};
        else if (bank0_release)
            bank0_a_wr_addr <= {ADDR_W{1'b0}};
        else if (bank0_fire_a && a_tlast)
            bank0_a_wr_addr <= bank0_a_wr_line_base_next;
        else if (bank0_fire_a && bank0_a_word_end)
            bank0_a_wr_addr <= bank0_a_wr_addr + a_wr_next_tile_step;
        else if (bank0_fire_a)
            bank0_a_wr_addr <= bank0_a_wr_addr + addr_inc_one;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_b_wr_line_base <= sram_uv_base;
        else if (bank0_release)
            bank0_b_wr_line_base <= sram_uv_base;
        else if (bank0_fire_b && b_tlast)
            bank0_b_wr_line_base <= bank0_b_wr_line_base_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_b_wr_addr <= sram_uv_base;
        else if (bank0_release)
            bank0_b_wr_addr <= sram_uv_base;
        else if (bank0_fire_b && b_tlast)
            bank0_b_wr_addr <= bank0_b_wr_line_base_next;
        else if (bank0_fire_b && bank0_b_word_end)
            bank0_b_wr_addr <= bank0_b_wr_addr + b_wr_next_tile_step;
        else if (bank0_fire_b)
            bank0_b_wr_addr <= bank0_b_wr_addr + addr_inc_one;
    end

    // ------------------------------------------------------------------------
    // Bank1 incremental write addresses
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_a_wr_line_base <= {ADDR_W{1'b0}};
        else if (bank1_release)
            bank1_a_wr_line_base <= {ADDR_W{1'b0}};
        else if (bank1_fire_a && a_tlast)
            bank1_a_wr_line_base <= bank1_a_wr_line_base_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_a_wr_addr <= {ADDR_W{1'b0}};
        else if (bank1_release)
            bank1_a_wr_addr <= {ADDR_W{1'b0}};
        else if (bank1_fire_a && a_tlast)
            bank1_a_wr_addr <= bank1_a_wr_line_base_next;
        else if (bank1_fire_a && bank1_a_word_end)
            bank1_a_wr_addr <= bank1_a_wr_addr + a_wr_next_tile_step;
        else if (bank1_fire_a)
            bank1_a_wr_addr <= bank1_a_wr_addr + addr_inc_one;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_b_wr_line_base <= sram_uv_base;
        else if (bank1_release)
            bank1_b_wr_line_base <= sram_uv_base;
        else if (bank1_fire_b && b_tlast)
            bank1_b_wr_line_base <= bank1_b_wr_line_base_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_b_wr_addr <= sram_uv_base;
        else if (bank1_release)
            bank1_b_wr_addr <= sram_uv_base;
        else if (bank1_fire_b && b_tlast)
            bank1_b_wr_addr <= bank1_b_wr_line_base_next;
        else if (bank1_fire_b && bank1_b_word_end)
            bank1_b_wr_addr <= bank1_b_wr_addr + b_wr_next_tile_step;
        else if (bank1_fire_b)
            bank1_b_wr_addr <= bank1_b_wr_addr + addr_inc_one;
    end

    // ------------------------------------------------------------------------
    // Bank0 A-channel counters
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_a_line_idx <= 16'd0;
        else if (bank0_release)
            bank0_a_line_idx <= 16'd0;
        else if (bank0_fire_a && a_tlast &&
                 (bank0_a_line_idx + 16'd1 < a_total_lines))
            bank0_a_line_idx <= bank0_a_line_idx + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_a_tile_x <= 16'd0;
        else if (bank0_release)
            bank0_a_tile_x <= 16'd0;
        else if (bank0_fire_a && a_tlast)
            bank0_a_tile_x <= 16'd0;
        else if (bank0_fire_a && bank0_a_word_end)
            bank0_a_tile_x <= bank0_a_tile_x + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_a_word_in_tile <= 16'd0;
        else if (bank0_release)
            bank0_a_word_in_tile <= 16'd0;
        else if (bank0_fire_a && a_tlast)
            bank0_a_word_in_tile <= 16'd0;
        else if (bank0_fire_a && bank0_a_word_end)
            bank0_a_word_in_tile <= 16'd0;
        else if (bank0_fire_a)
            bank0_a_word_in_tile <= bank0_a_word_in_tile + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_a_done <= 1'b0;
        else if (bank0_release)
            bank0_a_done <= 1'b0;
        else if (bank0_a_done_set)
            bank0_a_done <= 1'b1;
    end

    // ------------------------------------------------------------------------
    // Bank0 B-channel counters
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_b_line_idx <= 16'd0;
        else if (bank0_release)
            bank0_b_line_idx <= 16'd0;
        else if (bank0_fire_b && b_tlast &&
                 (bank0_b_line_idx + 16'd1 < b_total_lines))
            bank0_b_line_idx <= bank0_b_line_idx + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_b_tile_x <= 16'd0;
        else if (bank0_release)
            bank0_b_tile_x <= 16'd0;
        else if (bank0_fire_b && b_tlast)
            bank0_b_tile_x <= 16'd0;
        else if (bank0_fire_b && bank0_b_word_end)
            bank0_b_tile_x <= bank0_b_tile_x + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_b_word_in_tile <= 16'd0;
        else if (bank0_release)
            bank0_b_word_in_tile <= 16'd0;
        else if (bank0_fire_b && b_tlast)
            bank0_b_word_in_tile <= 16'd0;
        else if (bank0_fire_b && bank0_b_word_end)
            bank0_b_word_in_tile <= 16'd0;
        else if (bank0_fire_b)
            bank0_b_word_in_tile <= bank0_b_word_in_tile + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_b_done <= 1'b0;
        else if (bank0_release)
            bank0_b_done <= 1'b0;
        else if (bank0_b_done_set)
            bank0_b_done <= 1'b1;
    end

    // ------------------------------------------------------------------------
    // Bank0 metadata and frame identity
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_meta_vld <= 1'b0;
        else if (bank0_release)
            bank0_meta_vld <= 1'b0;
        else if (bank0_fire && !bank0_meta_vld)
            bank0_meta_vld <= 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_fcnt <= 4'd0;
        else if (bank0_release)
            bank0_fcnt <= 4'd0;
        else if (bank0_fire && !bank0_meta_vld)
            bank0_fcnt <= bank0_fire_fcnt;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_group_vld <= 1'b0;
        else if (bank0_release)
            bank0_group_vld <= 1'b0;
        else if (bank0_group_load)
            bank0_group_vld <= 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_group_id <= 16'd0;
        else if (bank0_release)
            bank0_group_id <= 16'd0;
        else if (bank0_group_load)
            bank0_group_id <= bank0_fire_group;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank0_vsync <= 1'b0;
        else if (bank0_release)
            bank0_vsync <= 1'b0;
        else if (bank0_fire_vsync)
            bank0_vsync <= 1'b1;
    end

    // ------------------------------------------------------------------------
    // Bank1 A-channel counters
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_a_line_idx <= 16'd0;
        else if (bank1_release)
            bank1_a_line_idx <= 16'd0;
        else if (bank1_fire_a && a_tlast &&
                 (bank1_a_line_idx + 16'd1 < a_total_lines))
            bank1_a_line_idx <= bank1_a_line_idx + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_a_tile_x <= 16'd0;
        else if (bank1_release)
            bank1_a_tile_x <= 16'd0;
        else if (bank1_fire_a && a_tlast)
            bank1_a_tile_x <= 16'd0;
        else if (bank1_fire_a && bank1_a_word_end)
            bank1_a_tile_x <= bank1_a_tile_x + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_a_word_in_tile <= 16'd0;
        else if (bank1_release)
            bank1_a_word_in_tile <= 16'd0;
        else if (bank1_fire_a && a_tlast)
            bank1_a_word_in_tile <= 16'd0;
        else if (bank1_fire_a && bank1_a_word_end)
            bank1_a_word_in_tile <= 16'd0;
        else if (bank1_fire_a)
            bank1_a_word_in_tile <= bank1_a_word_in_tile + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_a_done <= 1'b0;
        else if (bank1_release)
            bank1_a_done <= 1'b0;
        else if (bank1_a_done_set)
            bank1_a_done <= 1'b1;
    end

    // ------------------------------------------------------------------------
    // Bank1 B-channel counters
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_b_line_idx <= 16'd0;
        else if (bank1_release)
            bank1_b_line_idx <= 16'd0;
        else if (bank1_fire_b && b_tlast &&
                 (bank1_b_line_idx + 16'd1 < b_total_lines))
            bank1_b_line_idx <= bank1_b_line_idx + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_b_tile_x <= 16'd0;
        else if (bank1_release)
            bank1_b_tile_x <= 16'd0;
        else if (bank1_fire_b && b_tlast)
            bank1_b_tile_x <= 16'd0;
        else if (bank1_fire_b && bank1_b_word_end)
            bank1_b_tile_x <= bank1_b_tile_x + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_b_word_in_tile <= 16'd0;
        else if (bank1_release)
            bank1_b_word_in_tile <= 16'd0;
        else if (bank1_fire_b && b_tlast)
            bank1_b_word_in_tile <= 16'd0;
        else if (bank1_fire_b && bank1_b_word_end)
            bank1_b_word_in_tile <= 16'd0;
        else if (bank1_fire_b)
            bank1_b_word_in_tile <= bank1_b_word_in_tile + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_b_done <= 1'b0;
        else if (bank1_release)
            bank1_b_done <= 1'b0;
        else if (bank1_b_done_set)
            bank1_b_done <= 1'b1;
    end

    // ------------------------------------------------------------------------
    // Bank1 metadata and frame identity
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_meta_vld <= 1'b0;
        else if (bank1_release)
            bank1_meta_vld <= 1'b0;
        else if (bank1_fire && !bank1_meta_vld)
            bank1_meta_vld <= 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_fcnt <= 4'd0;
        else if (bank1_release)
            bank1_fcnt <= 4'd0;
        else if (bank1_fire && !bank1_meta_vld)
            bank1_fcnt <= bank1_fire_fcnt;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_group_vld <= 1'b0;
        else if (bank1_release)
            bank1_group_vld <= 1'b0;
        else if (bank1_group_load)
            bank1_group_vld <= 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_group_id <= 16'd0;
        else if (bank1_release)
            bank1_group_id <= 16'd0;
        else if (bank1_group_load)
            bank1_group_id <= bank1_fire_group;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank1_vsync <= 1'b0;
        else if (bank1_release)
            bank1_vsync <= 1'b0;
        else if (bank1_fire_vsync)
            bank1_vsync <= 1'b1;
    end

    // ------------------------------------------------------------------------
    // Read-side events
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // Read-side FSM and tile coordinate state
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_state <= RD_IDLE;
        else if (rd_state_invalid)
            rd_state <= RD_IDLE;
        else if (rd_start)
            rd_state <= RD_ACT;
        else if (rd_frame_read_done)
            rd_state <= RD_FIN;
        else if (rd_return_idle)
            rd_state <= RD_IDLE;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_bank_sel_act <= 1'b1;
        else if (rd_start_bank0)
            rd_bank_sel_act <= 1'b0;
        else if (rd_start_bank1)
            rd_bank_sel_act <= 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_tile_grp_y_cnt <= 16'd0;
        else if (rd_start && rd_start_vsync)
            rd_tile_grp_y_cnt <= 16'd0;
        else if (rd_return_idle)
            rd_tile_grp_y_cnt <= rd_tile_grp_y_cnt + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_plane <= 1'b0;
        else if (rd_start)
            rd_plane <= 1'b0;
        else if (rd_yuv_y_second_subrow_done || rd_non_yuv_to_b)
            rd_plane <= 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_y_subrow <= 1'b0;
        else if (rd_start)
            rd_y_subrow <= 1'b0;
        else if (rd_yuv_y_first_subrow_done)
            rd_y_subrow <= 1'b1;
        else if (rd_yuv_y_second_subrow_done)
            rd_y_subrow <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_tile_x <= 16'd0;
        else if (rd_start || rd_reset_tile_x)
            rd_tile_x <= 16'd0;
        else if (rd_advance_tile)
            rd_tile_x <= rd_tile_x + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_word_in_tile <= 16'd0;
        else if (rd_start || rd_reset_word)
            rd_word_in_tile <= 16'd0;
        else if (rd_advance_word)
            rd_word_in_tile <= rd_word_in_tile + 16'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_addr_cur <= {ADDR_W{1'b0}};
        else if (rd_start)
            rd_addr_cur <= {ADDR_W{1'b0}};
        else if (rd_load_region_addr)
            rd_addr_cur <= rd_region_addr_next;
        else if (rd_read_advance)
            rd_addr_cur <= rd_addr_cur + addr_inc_one;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_group_y <= 16'd0;
        else if (rd_start)
            rd_group_y <= rd_start_group_y;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_fcnt <= 4'd0;
        else if (rd_start)
            rd_fcnt <= rd_start_fcnt;
    end

endmodule
`default_nettype wire
