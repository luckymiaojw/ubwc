//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-06-24
// Module Name       : ubwc_dec_tile_to_otf_rotate.v
// Description       : NV12 90/270 rotation tile-to-OTF path using external
//                     bank0/bank1 ping-pong SRAM. One bank stores one source
//                     x-stripe, with Y and UV in different regions of the same
//                     bank.
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_dec_tile_to_otf_rotate #(
    parameter   integer                             SRAM_ADDR_W                    = 12,
    parameter   integer                             OTF_FIFO_DEPTH_BITS            = 5
)(
    input   wire                                        clk_sram                       ,
    input   wire                                        clk_otf                        ,
    input   wire                                        rst_sram_n                     ,
    input   wire                                        rst_otf_n                      ,
    input   wire                                        i_frame_start                  ,
    input   wire    [3                      :0]         i_frame_fcnt                   ,
    input   wire    [1                      :0]         i_rotate_mode                  ,
    input   wire    [4                      :0]         cfg_format                     ,
    input   wire    [15                     :0]         cfg_img_width                  ,
    input   wire    [15                     :0]         cfg_otf_h_total                ,
    input   wire    [15                     :0]         cfg_otf_h_sync                 ,
    input   wire    [15                     :0]         cfg_otf_h_bp                   ,
    input   wire    [15                     :0]         cfg_otf_h_act                  ,
    input   wire    [15                     :0]         cfg_otf_v_total                ,
    input   wire    [15                     :0]         cfg_otf_v_sync                 ,
    input   wire    [15                     :0]         cfg_otf_v_bp                   ,
    input   wire    [15                     :0]         cfg_otf_v_act                  ,

    input   wire    [4                      :0]         s_axis_format                  ,
    input   wire    [15                     :0]         s_axis_tile_x                  ,
    input   wire    [15                     :0]         s_axis_tile_y                  ,
    input   wire    [3                      :0]         s_axis_tile_fcnt               ,
    input   wire                                        s_axis_tile_valid              ,
    output  wire                                        s_axis_tile_ready              ,
    input   wire    [255                    :0]         s_axis_tdata                   ,
    input   wire                                        s_axis_tlast                   ,
    input   wire                                        s_axis_tvalid                  ,
    output  wire                                        s_axis_tready                  ,

    output  wire                                        sram_a_wen                     ,
    output  wire    [SRAM_ADDR_W         -1 :0]         sram_a_waddr                   ,
    output  wire    [127                    :0]         sram_a_wdata                   ,
    output  wire                                        sram_a_ren                     ,
    output  wire    [SRAM_ADDR_W         -1 :0]         sram_a_raddr                   ,
    input   wire    [127                    :0]         sram_a_rdata                   ,
    input   wire                                        sram_a_rvalid                  ,
    output  wire                                        sram_b_wen                     ,
    output  wire    [SRAM_ADDR_W         -1 :0]         sram_b_waddr                   ,
    output  wire    [127                    :0]         sram_b_wdata                   ,
    output  wire                                        sram_b_ren                     ,
    output  wire    [SRAM_ADDR_W         -1 :0]         sram_b_raddr                   ,
    input   wire    [127                    :0]         sram_b_rdata                   ,
    input   wire                                        sram_b_rvalid                  ,

    output  wire                                        o_otf_vsync                    ,
    output  wire                                        o_otf_hsync                    ,
    output  wire                                        o_otf_de                       ,
    output  wire    [127                    :0]         o_otf_data                     ,
    output  wire    [3                      :0]         o_otf_fcnt                     ,
    output  wire    [11                     :0]         o_otf_lcnt                     ,
    input   wire                                        i_otf_ready                    ,

    output  wire                                        o_busy                         ,
    output  wire                                        o_correct_irq_pulse            ,
    output  wire                                        o_underflow                    ,
    output  wire    [31                     :0]         o_otf_line_count               ,
    output  wire    [31                     :0]         o_otf_de_count
);

    localparam  [4                      :0]         BASE_FMT_NV12                  = 5'b00010;
    localparam  [4                      :0]         FMT_NV12_Y                     = 5'b01000;
    localparam  [4                      :0]         FMT_NV12_UV                    = 5'b01001;
    localparam  [SRAM_ADDR_W         -1 :0]         Y_BASE_ADDR                    = {SRAM_ADDR_W{1'b0}};
    localparam  [SRAM_ADDR_W         -1 :0]         UV_BASE_ADDR                   = SRAM_ADDR_W'(2176);
    localparam  [SRAM_ADDR_W         -1 :0]         ROT_LINE_STRIDE_WORDS          = SRAM_ADDR_W'(68);
    localparam  [OTF_FIFO_DEPTH_BITS    :0]         OTF_FIFO_START_LEVEL           = {1'b0, {OTF_FIFO_DEPTH_BITS{1'b1}}};

    wire                                            rotate_nv12                    ;
    wire                                            rotate_90                      ;
    wire                                            rotate_270                     ;
    wire                                            frame_start                    ;
    wire                                            tile_hdr_fire                  ;
    wire                                            tile_data_fire                 ;
    wire                                            tile_done_fire                 ;
    wire                                            y_last_tile_done_fire          ;
    wire                                            uv_last_tile_done_fire         ;
    wire                                            stripe_done_fire               ;
    wire                                            write_bank_full                ;
    wire                                            flush_done_fire                ;
    wire                                            flush_is_y                     ;
    wire                                            flush_is_uv                    ;
    wire                                            fifo_wr_en                     ;
    wire        [255                    :0]         fifo_wdata                     ;
    wire                                            fifo_full                      ;
    wire                                            fifo_empty                     ;
    wire        [255                    :0]         fifo_rdata                     ;
    wire                                            fifo_rd_en                     ;
    wire        [OTF_FIFO_DEPTH_BITS    :0]         fifo_rd_count                  ;
    wire                                            fifo_start_ready               ;
    wire                                            frame_start_fifo_wr_en         ;
    wire                                            frame_start_fifo_rd_en         ;
    wire                                            frame_start_fifo_full          ;
    wire                                            frame_start_fifo_empty         ;
    wire        [3                      :0]         frame_start_fifo_rdata         ;
    wire                                            otf_fifo_rd_en                 ;
    wire                                            otf_driver_busy                ;
    wire                                            otf_frame_start_ready          ;
    wire                                            otf_correct_irq_pulse          ;
    wire                                            otf_underflow                  ;
    wire        [31                     :0]         otf_line_count                 ;
    wire        [31                     :0]         otf_de_count                   ;
    wire                                            otf_vsync                      ;
    wire                                            otf_hsync                      ;
    wire                                            otf_de                         ;
    wire        [127                    :0]         otf_data                       ;
    wire        [3                      :0]         otf_fcnt                       ;
    wire        [11                     :0]         otf_lcnt                       ;
    wire                                            emit_active                    ;
    wire        [15                     :0]         emit_line                      ;
    wire        [15                     :0]         emit_word_idx                  ;
    wire        [31                     :0]         expect_tile_count              ;
    wire        [31                     :0]         otf_de_count_sram              ;
    wire                                            read_bank_valid                ;
    wire                                            read_is_even_line              ;
    wire                                            read_need_uv                   ;
    wire                                            read_y_rvalid                  ;
    wire                                            read_uv_rvalid                 ;
    wire        [127                    :0]         read_y_rdata                   ;
    wire        [127                    :0]         read_uv_rdata                  ;
    wire        [15                     :0]         y_tile_last_y                  ;
    wire        [15                     :0]         uv_tile_last_y                 ;
    wire        [15                     :0]         words_per_line                 ;
    wire        [15                     :0]         src_height_m1                  ;
    wire        [15                     :0]         y_src_row                      ;
    wire        [15                     :0]         uv_src_row                     ;
    wire                                            y_src_row_active               ;
    wire                                            uv_src_row_active              ;
    wire        [15                     :0]         y_rot_x                        ;
    wire        [16                     :0]         uv_rot_x_byte_ext              ;
    wire        [15                     :0]         uv_rot_x_byte                  ;
    wire        [16                     :0]         cfg_otf_h_act_ext              ;
    wire        [3                      :0]         y_word_byte_idx                ;
    wire        [3                      :0]         uv_word_byte_idx               ;
    wire        [15                     :0]         y_word_idx                     ;
    wire        [15                     :0]         uv_word_idx                    ;
    wire                                            y_flush_word_done              ;
    wire                                            uv_flush_word_done             ;
    wire        [20                     :0]         tile_x_line_base_ext           ;
    wire        [20                     :0]         cfg_otf_v_act_ext              ;
    wire        [20                     :0]         stripe_line_left_ext           ;
    wire        [5                      :0]         stripe_valid_lines             ;
    wire        [5                      :0]         stripe_valid_uv_lines          ;

    reg                                             tile_active                    ;
    reg         [4                      :0]         tile_format_r                  ;
    reg         [15                     :0]         tile_x_r                       ;
    reg         [15                     :0]         tile_y_r                       ;
    reg         [3                      :0]         tile_fcnt_r                    ;
    reg         [3                      :0]         tile_beat_idx                  ;
    reg         [31                     :0]         tile_done_count                ;
    reg                                             y_plane_done_seen              ;
    reg                                             uv_plane_done_seen             ;
    reg                                             wr_bank                        ;
    reg                                             bank_full0                     ;
    reg                                             bank_full1                     ;
    reg         [3                      :0]         bank_fcnt0                     ;
    reg         [3                      :0]         bank_fcnt1                     ;
    reg         [5                      :0]         bank_lines0                    ;
    reg         [5                      :0]         bank_lines1                    ;
    reg                                             frame_token_sent               ;
    reg                                             flush_active                   ;
    reg                                             flush_plane                    ;
    reg                                             flush_bank                     ;
    reg         [5                      :0]         flush_line_idx                 ;
    reg         [SRAM_ADDR_W         -1 :0]         flush_addr                     ;
    reg         [15                     :0]         flush_word_idx                 ;
    reg         [127                    :0]         y_acc                          [0:31];
    reg         [127                    :0]         uv_acc                         [0:15];
    reg         [2                      :0]         rd_state                       ;
    reg                                             rd_bank                        ;
    reg         [5                      :0]         rd_line_count                  ;
    reg         [5                      :0]         rd_line_idx                    ;
    reg         [15                     :0]         rd_word_idx                    ;
    reg         [SRAM_ADDR_W         -1 :0]         rd_y_addr                      ;
    reg         [SRAM_ADDR_W         -1 :0]         rd_uv_addr                     ;
    reg         [SRAM_ADDR_W         -1 :0]         rd_y_line_base                 ;
    reg         [SRAM_ADDR_W         -1 :0]         rd_uv_line_base                ;
    reg         [127                    :0]         rd_y_data                      ;
    reg         [127                    :0]         rd_uv_data                     ;
    reg         [3                      :0]         rd_fcnt                        ;
    reg                                             fifo_start_ready_r             ;
    reg                                             frame_start_fifo_not_empty_r    ;
    reg                                             frame_start_otf_reg            ;
    reg         [3                      :0]         frame_fcnt_otf_r               ;

    integer                                         init_i                          ;
    integer                                         byte_i                          ;

    assign rotate_90                   = (i_rotate_mode == 2'd1);
    assign rotate_270                  = (i_rotate_mode == 2'd2);
    assign rotate_nv12                 = ((cfg_format == BASE_FMT_NV12) ||
                                          (cfg_format == FMT_NV12_Y)    ||
                                          (cfg_format == FMT_NV12_UV)) &&
                                         (rotate_90 || rotate_270);
    assign frame_start                 = i_frame_start;
    assign src_height_m1               = (cfg_otf_h_act == 16'd0) ? 16'd0 :
                                                                          (cfg_otf_h_act - 16'd1);
    assign words_per_line              = (cfg_otf_h_act + 16'd15) >> 4;
    assign y_tile_last_y               = (cfg_otf_h_act == 16'd0) ? 16'd0 :
                                         ((cfg_otf_h_act + 16'd7) >> 3) - 16'd1;
    assign uv_tile_last_y              = (cfg_otf_h_act <= 16'd1) ? 16'd0 :
                                         ((((cfg_otf_h_act >> 1) + 16'd7) >> 3) - 16'd1);
    assign write_bank_full             = wr_bank ? bank_full1 : bank_full0;
    assign tile_hdr_fire               = s_axis_tile_valid && s_axis_tile_ready;
    assign tile_data_fire              = s_axis_tvalid && s_axis_tready;
    assign tile_done_fire              = tile_data_fire && (s_axis_tlast || (tile_beat_idx == 4'd7));
    assign y_last_tile_done_fire       = tile_done_fire &&
                                         (tile_format_r == FMT_NV12_Y) &&
                                         (tile_y_r == y_tile_last_y);
    assign uv_last_tile_done_fire      = tile_done_fire &&
                                         (tile_format_r == FMT_NV12_UV) &&
                                         (tile_y_r == uv_tile_last_y);
    assign stripe_done_fire            = (y_last_tile_done_fire && uv_plane_done_seen) ||
                                         (uv_last_tile_done_fire && y_plane_done_seen);
    assign s_axis_tile_ready           = rotate_nv12 && !tile_active && !flush_active && !write_bank_full;
    assign s_axis_tready               = rotate_nv12 && tile_active && !flush_active;
    assign flush_is_y                  = flush_active && (flush_plane == 1'b0);
    assign flush_is_uv                 = flush_active && (flush_plane == 1'b1);
    assign flush_done_fire             = flush_active &&
                                         (flush_line_idx == (flush_is_y ? 6'd31 : 6'd15));
    assign y_src_row                   = {tile_y_r[12:0], 3'b000} + {12'd0, tile_beat_idx[2:0]};
    assign uv_src_row                  = {tile_y_r[12:0], 3'b000} + {12'd0, tile_beat_idx[2:0]};
    assign y_src_row_active            = y_src_row < cfg_otf_h_act;
    assign uv_src_row_active           = {uv_src_row, 1'b0} < cfg_otf_h_act_ext;
    assign y_rot_x                     = rotate_90 ? (src_height_m1 - y_src_row) :
                                                     y_src_row;
    assign uv_rot_x_byte_ext           = rotate_90 ? ({1'b0, src_height_m1[15:1], 1'b0} -
                                                       {1'b0, uv_src_row[14:0], 1'b0}) :
                                                     {1'b0, uv_src_row[14:0], 1'b0};
    assign uv_rot_x_byte               = uv_rot_x_byte_ext[15:0];
    assign cfg_otf_h_act_ext           = {1'b0, cfg_otf_h_act};
    assign y_word_idx                  = y_rot_x >> 4;
    assign uv_word_idx                 = uv_rot_x_byte >> 4;
    assign y_word_byte_idx             = y_rot_x[3:0];
    assign uv_word_byte_idx            = uv_rot_x_byte[3:0];
    assign y_flush_word_done           = rotate_90 ? (y_word_byte_idx == 4'd0) :
                                                     (y_word_byte_idx == 4'd15);
    assign uv_flush_word_done          = rotate_90 ? (uv_word_byte_idx == 4'd0) :
                                                     (uv_word_byte_idx == 4'd14);
    assign tile_x_line_base_ext        = {tile_x_r, 5'b00000};
    assign cfg_otf_v_act_ext           = {5'd0, cfg_otf_v_act};
    assign stripe_line_left_ext        = cfg_otf_v_act_ext - tile_x_line_base_ext;
    assign stripe_valid_lines          = (cfg_otf_v_act_ext <= tile_x_line_base_ext) ? 6'd0 :
                                         (stripe_line_left_ext >= 21'd32) ? 6'd32 :
                                                                            stripe_line_left_ext[5:0];
    assign stripe_valid_uv_lines       = {1'b0, stripe_valid_lines[5:1]} +
                                         {5'd0, stripe_valid_lines[0]};
    assign fifo_wr_en                  = (rd_state == 3'd4) && !fifo_full;
    assign fifo_wdata                  = {rd_uv_data, rd_y_data};
    assign fifo_start_ready            = fifo_rd_count >= OTF_FIFO_START_LEVEL;
    assign frame_start_fifo_wr_en      = fifo_wr_en && !frame_token_sent && !frame_start_fifo_full;
    assign frame_start_fifo_rd_en      = frame_start_fifo_not_empty_r && otf_frame_start_ready &&
                                         fifo_start_ready_r;
    assign read_bank_valid             = (rd_bank ? bank_full1 : bank_full0) &&
                                         !flush_active;
    assign read_is_even_line           = !rd_line_idx[0];
    assign read_need_uv                = read_is_even_line;
    assign read_y_rvalid               = (rd_state == 3'd2) &&
                                         (rd_bank ? sram_b_rvalid : sram_a_rvalid);
    assign read_uv_rvalid              = (rd_state == 3'd6) &&
                                         (rd_bank ? sram_b_rvalid : sram_a_rvalid);
    assign read_y_rdata                = rd_bank ? sram_b_rdata : sram_a_rdata;
    assign read_uv_rdata               = rd_bank ? sram_b_rdata : sram_a_rdata;
    assign sram_a_wen                  = flush_active && (flush_bank == 1'b0);
    assign sram_b_wen                  = flush_active && (flush_bank == 1'b1);
    assign sram_a_waddr                = flush_addr;
    assign sram_b_waddr                = flush_addr;
    assign sram_a_wdata                = flush_is_y ? y_acc[flush_line_idx[4:0]] :
                                                      uv_acc[flush_line_idx[3:0]];
    assign sram_b_wdata                = sram_a_wdata;
    assign sram_a_ren                  = (rd_state == 3'd1) && (rd_bank == 1'b0) ||
                                         (rd_state == 3'd3) && (rd_bank == 1'b0) && read_need_uv;
    assign sram_b_ren                  = (rd_state == 3'd1) && (rd_bank == 1'b1) ||
                                         (rd_state == 3'd3) && (rd_bank == 1'b1) && read_need_uv;
    assign sram_a_raddr                = (rd_state == 3'd3) ? rd_uv_addr :
                                                               rd_y_addr;
    assign sram_b_raddr                = sram_a_raddr;
    assign o_busy                      = tile_active | flush_active | bank_full0 | bank_full1 |
                                         !fifo_empty | otf_driver_busy;
    assign o_correct_irq_pulse         = otf_correct_irq_pulse;
    assign o_underflow                 = otf_underflow;
    assign o_otf_line_count            = otf_line_count;
    assign o_otf_de_count              = otf_de_count;
    assign o_otf_vsync                 = otf_vsync;
    assign o_otf_hsync                 = otf_hsync;
    assign o_otf_de                    = otf_de;
    assign o_otf_data                  = otf_data;
    assign o_otf_fcnt                  = otf_fcnt;
    assign o_otf_lcnt                  = otf_lcnt;
    assign fifo_rd_en                  = otf_fifo_rd_en;
    assign emit_active                 = otf_de;
    assign emit_line                   = {4'd0, otf_lcnt};
    assign emit_word_idx               = otf_de_count[15:0];
    assign expect_tile_count           = tile_done_count;
    assign otf_de_count_sram           = otf_de_count;

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n) begin
            for (init_i = 0; init_i < 32; init_i = init_i + 1)
                y_acc[init_i] <= 128'd0;
            for (init_i = 0; init_i < 16; init_i = init_i + 1)
                uv_acc[init_i] <= 128'd0;
        end else if (frame_start) begin
            for (init_i = 0; init_i < 32; init_i = init_i + 1)
                y_acc[init_i] <= 128'd0;
            for (init_i = 0; init_i < 16; init_i = init_i + 1)
                uv_acc[init_i] <= 128'd0;
        end else if (flush_done_fire && !flush_plane) begin
            for (init_i = 0; init_i < 32; init_i = init_i + 1)
                y_acc[init_i] <= 128'd0;
        end else if (flush_done_fire && flush_plane) begin
            for (init_i = 0; init_i < 16; init_i = init_i + 1)
                uv_acc[init_i] <= 128'd0;
        end else if (tile_data_fire && (tile_format_r == FMT_NV12_Y) && y_src_row_active) begin
            for (byte_i = 0; byte_i < 32; byte_i = byte_i + 1) begin
                if (rotate_90)
                    y_acc[byte_i][y_word_byte_idx*8 +: 8] <= s_axis_tdata[byte_i*8 +: 8];
                else if (byte_i < stripe_valid_lines)
                    y_acc[stripe_valid_lines[4:0] - byte_i[4:0] - 5'd1][y_word_byte_idx*8 +: 8] <= s_axis_tdata[byte_i*8 +: 8];
            end
        end else if (tile_data_fire && (tile_format_r == FMT_NV12_UV) && uv_src_row_active) begin
            for (byte_i = 0; byte_i < 16; byte_i = byte_i + 1) begin
                if (rotate_90) begin
                    uv_acc[byte_i][uv_word_byte_idx*8 +: 8]       <= s_axis_tdata[(byte_i*16) + 0 +: 8];
                    uv_acc[byte_i][(uv_word_byte_idx+4'd1)*8 +: 8] <= s_axis_tdata[(byte_i*16) + 8 +: 8];
                end else if (byte_i < stripe_valid_uv_lines) begin
                    uv_acc[stripe_valid_uv_lines[3:0] - byte_i[3:0] - 4'd1][uv_word_byte_idx*8 +: 8]       <= s_axis_tdata[(byte_i*16) + 0 +: 8];
                    uv_acc[stripe_valid_uv_lines[3:0] - byte_i[3:0] - 4'd1][(uv_word_byte_idx+4'd1)*8 +: 8] <= s_axis_tdata[(byte_i*16) + 8 +: 8];
                end
            end
        end
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            flush_active <= 1'b0;
        else if (frame_start)
            flush_active <= 1'b0;
        else if (flush_done_fire)
            flush_active <= 1'b0;
        else if (tile_data_fire && (tile_format_r == FMT_NV12_Y) && y_src_row_active &&
                 (y_flush_word_done || (y_src_row == src_height_m1)))
            flush_active <= 1'b1;
        else if (tile_data_fire && (tile_format_r == FMT_NV12_UV) && uv_src_row_active &&
                 (uv_flush_word_done || ({uv_src_row, 1'b0} >= (src_height_m1 - 16'd1))))
            flush_active <= 1'b1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            flush_plane <= 1'b0;
        else if (tile_data_fire && (tile_format_r == FMT_NV12_Y))
            flush_plane <= 1'b0;
        else if (tile_data_fire && (tile_format_r == FMT_NV12_UV))
            flush_plane <= 1'b1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            flush_bank <= 1'b0;
        else if (tile_data_fire)
            flush_bank <= wr_bank;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            flush_word_idx <= 16'd0;
        else if (tile_data_fire && (tile_format_r == FMT_NV12_Y))
            flush_word_idx <= y_word_idx;
        else if (tile_data_fire && (tile_format_r == FMT_NV12_UV))
            flush_word_idx <= uv_word_idx;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            flush_line_idx <= 6'd0;
        else if (!flush_active)
            flush_line_idx <= 6'd0;
        else
            flush_line_idx <= flush_line_idx + 6'd1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            flush_addr <= {SRAM_ADDR_W{1'b0}};
        else if (!flush_active && tile_data_fire && (tile_format_r == FMT_NV12_Y))
            flush_addr <= Y_BASE_ADDR + y_word_idx[SRAM_ADDR_W-1:0];
        else if (!flush_active && tile_data_fire && (tile_format_r == FMT_NV12_UV))
            flush_addr <= UV_BASE_ADDR + uv_word_idx[SRAM_ADDR_W-1:0];
        else if (flush_active)
            flush_addr <= flush_addr + ROT_LINE_STRIDE_WORDS;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            tile_active <= 1'b0;
        else if (frame_start)
            tile_active <= 1'b0;
        else if (tile_hdr_fire)
            tile_active <= 1'b1;
        else if (tile_done_fire)
            tile_active <= 1'b0;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            tile_format_r <= 5'd0;
        else if (tile_hdr_fire)
            tile_format_r <= s_axis_format;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            tile_x_r <= 16'd0;
        else if (tile_hdr_fire)
            tile_x_r <= s_axis_tile_x;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            tile_y_r <= 16'd0;
        else if (tile_hdr_fire)
            tile_y_r <= s_axis_tile_y;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            tile_fcnt_r <= 4'd0;
        else if (tile_hdr_fire)
            tile_fcnt_r <= s_axis_tile_fcnt;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            tile_beat_idx <= 4'd0;
        else if (frame_start || tile_hdr_fire || tile_done_fire)
            tile_beat_idx <= 4'd0;
        else if (tile_data_fire)
            tile_beat_idx <= tile_beat_idx + 4'd1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            tile_done_count <= 32'd0;
        else if (frame_start)
            tile_done_count <= 32'd0;
        else if (tile_done_fire)
            tile_done_count <= tile_done_count + 32'd1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            y_plane_done_seen <= 1'b0;
        else if (frame_start || stripe_done_fire)
            y_plane_done_seen <= 1'b0;
        else if (y_last_tile_done_fire)
            y_plane_done_seen <= 1'b1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            uv_plane_done_seen <= 1'b0;
        else if (frame_start || stripe_done_fire)
            uv_plane_done_seen <= 1'b0;
        else if (uv_last_tile_done_fire)
            uv_plane_done_seen <= 1'b1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            wr_bank <= 1'b0;
        else if (frame_start)
            wr_bank <= 1'b0;
        else if (stripe_done_fire)
            wr_bank <= ~wr_bank;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            bank_full0 <= 1'b0;
        else if (frame_start)
            bank_full0 <= 1'b0;
        else if (stripe_done_fire && (wr_bank == 1'b0) && (stripe_valid_lines != 6'd0))
            bank_full0 <= 1'b1;
        else if ((rd_state == 3'd5) && (rd_bank == 1'b0))
            bank_full0 <= 1'b0;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            bank_full1 <= 1'b0;
        else if (frame_start)
            bank_full1 <= 1'b0;
        else if (stripe_done_fire && (wr_bank == 1'b1) && (stripe_valid_lines != 6'd0))
            bank_full1 <= 1'b1;
        else if ((rd_state == 3'd5) && (rd_bank == 1'b1))
            bank_full1 <= 1'b0;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            bank_fcnt0 <= 4'd0;
        else if (stripe_done_fire && (wr_bank == 1'b0))
            bank_fcnt0 <= tile_fcnt_r;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            bank_fcnt1 <= 4'd0;
        else if (stripe_done_fire && (wr_bank == 1'b1))
            bank_fcnt1 <= tile_fcnt_r;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            bank_lines0 <= 6'd0;
        else if (stripe_done_fire && (wr_bank == 1'b0))
            bank_lines0 <= stripe_valid_lines;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            bank_lines1 <= 6'd0;
        else if (stripe_done_fire && (wr_bank == 1'b1))
            bank_lines1 <= stripe_valid_lines;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            frame_token_sent <= 1'b0;
        else if (frame_start)
            frame_token_sent <= 1'b0;
        else if (frame_start_fifo_wr_en)
            frame_token_sent <= 1'b1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            rd_state <= 3'd0;
        else if (frame_start)
            rd_state <= 3'd0;
        else begin
            case (rd_state)
                3'd0:    rd_state <= read_bank_valid ? 3'd1 : 3'd0;
                3'd1:    rd_state <= 3'd2;
                3'd2:    rd_state <= read_y_rvalid ? (read_need_uv ? 3'd3 : 3'd4) : 3'd2;
                3'd3:    rd_state <= 3'd6;
                3'd6:    rd_state <= read_uv_rvalid ? 3'd4 : 3'd6;
                3'd4:    rd_state <= fifo_full ? 3'd4 :
                                        ((rd_line_idx == (rd_line_count - 6'd1)) &&
                                         (rd_word_idx == (words_per_line - 16'd1))) ? 3'd5 : 3'd1;
                3'd5:    rd_state <= 3'd0;
                default: rd_state <= 3'd0;
            endcase
        end
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            rd_bank <= 1'b0;
        else if (frame_start)
            rd_bank <= 1'b0;
        else if (rd_state == 3'd0) begin
            if (bank_full0)
                rd_bank <= 1'b0;
            else if (bank_full1)
                rd_bank <= 1'b1;
        end
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            rd_line_count <= 6'd0;
        else if (rd_state == 3'd0)
            rd_line_count <= bank_full0 ? bank_lines0 : bank_lines1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            rd_fcnt <= 4'd0;
        else if (rd_state == 3'd0)
            rd_fcnt <= bank_full0 ? bank_fcnt0 : bank_fcnt1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            rd_line_idx <= 6'd0;
        else if (frame_start || (rd_state == 3'd5))
            rd_line_idx <= 6'd0;
        else if ((rd_state == 3'd4) && fifo_wr_en && (rd_word_idx == (words_per_line - 16'd1)))
            rd_line_idx <= rd_line_idx + 6'd1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            rd_word_idx <= 16'd0;
        else if (frame_start || (rd_state == 3'd5))
            rd_word_idx <= 16'd0;
        else if ((rd_state == 3'd4) && fifo_wr_en)
            rd_word_idx <= (rd_word_idx == (words_per_line - 16'd1)) ? 16'd0 :
                                                                    (rd_word_idx + 16'd1);
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            rd_y_addr <= {SRAM_ADDR_W{1'b0}};
        else if (rd_state == 3'd0)
            rd_y_addr <= Y_BASE_ADDR;
        else if ((rd_state == 3'd4) && fifo_wr_en)
            rd_y_addr <= (rd_word_idx == (words_per_line - 16'd1)) ?
                         (rd_y_line_base + ROT_LINE_STRIDE_WORDS) :
                         (rd_y_addr + SRAM_ADDR_W'(1));
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            rd_uv_addr <= UV_BASE_ADDR;
        else if (rd_state == 3'd0)
            rd_uv_addr <= UV_BASE_ADDR;
        else if ((rd_state == 3'd4) && fifo_wr_en)
            rd_uv_addr <= (rd_word_idx == (words_per_line - 16'd1)) ?
                          (read_is_even_line ? (rd_uv_line_base + ROT_LINE_STRIDE_WORDS) :
                                               rd_uv_line_base) :
                          (rd_uv_addr + SRAM_ADDR_W'(1));
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            rd_y_line_base <= Y_BASE_ADDR;
        else if (rd_state == 3'd0)
            rd_y_line_base <= Y_BASE_ADDR;
        else if ((rd_state == 3'd4) && fifo_wr_en &&
                 (rd_word_idx == (words_per_line - 16'd1)))
            rd_y_line_base <= rd_y_line_base + ROT_LINE_STRIDE_WORDS;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            rd_uv_line_base <= UV_BASE_ADDR;
        else if (rd_state == 3'd0)
            rd_uv_line_base <= UV_BASE_ADDR;
        else if ((rd_state == 3'd4) && fifo_wr_en &&
                 (rd_word_idx == (words_per_line - 16'd1)) &&
                 read_is_even_line)
            rd_uv_line_base <= rd_uv_line_base + ROT_LINE_STRIDE_WORDS;
    end

    always @(posedge clk_sram) begin
        if (read_y_rvalid)
            rd_y_data <= read_y_rdata;
    end

    always @(posedge clk_sram) begin
        if (read_uv_rvalid)
            rd_uv_data <= read_uv_rdata;
        else if ((rd_state == 3'd2) && read_y_rvalid && !read_need_uv)
            rd_uv_data <= 128'd0;
    end

    mg_async_fifo #(
        .AF                             ( 1                                     ),
        .DATA_BITS                      ( 4                                     ),
        .DEPTH_BITS                     ( 3                                     ),
        .SHOW_AHEAD                     ( 1                                     ),
        .RAM_STYLE                      ( "distributed"                         )
    ) u_frame_start_fifo (
        .wr_clk                         ( clk_sram                              ),
        .wr_rstn                        ( rst_sram_n                            ),
        .wr_en                          ( frame_start_fifo_wr_en                ),
        .din                            ( rd_fcnt                                ),
        .wr_data_count                  (                                       ),
        .prog_full                      (                                       ),
        .full                           ( frame_start_fifo_full                 ),
        .rd_clk                         ( clk_otf                               ),
        .rd_rstn                        ( rst_otf_n                             ),
        .rd_en                          ( frame_start_fifo_rd_en                ),
        .dout                           ( frame_start_fifo_rdata                ),
        .valid                          (                                       ),
        .rd_data_count                  (                                       ),
        .pre_empty                      (                                       ),
        .empty                          ( frame_start_fifo_empty                )
    );

    mg_async_fifo #(
        .AF                             ( 1                                     ),
        .DATA_BITS                      ( 256                                   ),
        .DEPTH_BITS                     ( OTF_FIFO_DEPTH_BITS                   ),
        .SHOW_AHEAD                     ( 1                                     ),
        .RAM_STYLE                      ( "block"                               )
    ) u_cdc_fifo (
        .wr_clk                         ( clk_sram                              ),
        .wr_rstn                        ( rst_sram_n                            ),
        .wr_en                          ( fifo_wr_en                            ),
        .din                            ( fifo_wdata                            ),
        .wr_data_count                  (                                       ),
        .prog_full                      (                                       ),
        .full                           ( fifo_full                             ),
        .rd_clk                         ( clk_otf                               ),
        .rd_rstn                        ( rst_otf_n                             ),
        .rd_en                          ( fifo_rd_en                            ),
        .dout                           ( fifo_rdata                            ),
        .valid                          (                                       ),
        .rd_data_count                  ( fifo_rd_count                         ),
        .pre_empty                      (                                       ),
        .empty                          ( fifo_empty                            )
    );

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            fifo_start_ready_r <= 1'b0;
        else
            fifo_start_ready_r <= fifo_start_ready;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            frame_start_fifo_not_empty_r <= 1'b0;
        else
            frame_start_fifo_not_empty_r <= !frame_start_fifo_empty;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            frame_start_otf_reg <= 1'b0;
        else
            frame_start_otf_reg <= frame_start_fifo_rd_en;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            frame_fcnt_otf_r <= 4'd0;
        else if (frame_start_fifo_rd_en)
            frame_fcnt_otf_r <= frame_start_fifo_rdata;
    end

    otf_driver u_rotate_otf_driver (
        .clk_otf                    ( clk_otf                    ),
        .rst_n                      ( rst_otf_n                  ),
        .i_frame_start              ( frame_start_otf_reg        ),
        .i_frame_fcnt               ( frame_fcnt_otf_r           ),
        .cfg_format                 ( BASE_FMT_NV12              ),
        .cfg_otf_h_total            ( cfg_otf_h_total            ),
        .cfg_otf_h_sync             ( cfg_otf_h_sync             ),
        .cfg_otf_h_bp               ( cfg_otf_h_bp               ),
        .cfg_otf_h_act              ( cfg_otf_h_act              ),
        .cfg_otf_v_total            ( cfg_otf_v_total            ),
        .cfg_otf_v_sync             ( cfg_otf_v_sync             ),
        .cfg_otf_v_bp               ( cfg_otf_v_bp               ),
        .cfg_otf_v_act              ( cfg_otf_v_act              ),
        .i_otf_ready                ( i_otf_ready                ),
        .i_fifo_empty0              ( fifo_empty                 ),
        .i_fifo_rdata0              ( fifo_rdata                 ),
        .i_fifo_start_ready         ( fifo_start_ready           ),
        .o_fifo_rd_en0              ( otf_fifo_rd_en             ),
        .o_busy                     ( otf_driver_busy            ),
        .o_frame_start_ready        ( otf_frame_start_ready      ),
        .o_active_fcnt              (                            ),
        .o_frame_done_pulse         (                            ),
        .o_correct_irq_pulse        ( otf_correct_irq_pulse      ),
        .o_underflow                ( otf_underflow              ),
        .o_otf_line_count           ( otf_line_count             ),
        .o_otf_de_count             ( otf_de_count               ),
        .o_otf_vsync                ( otf_vsync                  ),
        .o_otf_hsync                ( otf_hsync                  ),
        .o_otf_de                   ( otf_de                     ),
        .o_otf_data                 ( otf_data                   ),
        .o_otf_fcnt                 ( otf_fcnt                   ),
        .o_otf_lcnt                 ( otf_lcnt                   )
    );

endmodule
