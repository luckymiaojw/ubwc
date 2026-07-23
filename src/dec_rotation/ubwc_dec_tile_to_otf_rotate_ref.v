//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-06-21
// Module Name       : ubwc_dec_tile_to_otf_rotate_ref.v
// Description       : DEC NV12 rotation path for dec_rotation bring-up.
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_dec_tile_to_otf_rotate_ref #(
    parameter   integer                             MAX_SRC_WIDTH                  = 1080,
    parameter   integer                             MAX_SRC_HEIGHT                 = 1088,
    parameter   integer                             OTF_FIFO_DEPTH_BITS            = 8
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

    localparam  integer                             MAX_TILE_COLS                  = ((MAX_SRC_WIDTH + 127) >> 7) << 2;
    localparam  integer                             MAX_Y_TILE_ROWS                = (MAX_SRC_HEIGHT + 7) / 8;
    localparam  integer                             MAX_UV_TILE_ROWS               = ((MAX_SRC_HEIGHT / 2) + 7) / 8;
    localparam  integer                             MAX_Y_TILE_WORDS               = MAX_TILE_COLS * MAX_Y_TILE_ROWS * 8;
    localparam  integer                             MAX_UV_TILE_WORDS              = MAX_TILE_COLS * MAX_UV_TILE_ROWS * 8;
    localparam  [4                      :0]         FMT_NV12_Y                     = 5'b01000;
    localparam  [4                      :0]         FMT_NV12_UV                    = 5'b01001;
    localparam  [4                      :0]         BASE_FMT_NV12                  = 5'b00010;
    localparam  [OTF_FIFO_DEPTH_BITS       :0]      OTF_FIFO_START_LEVEL           = 9'd32;

    wire                                            frame_start                    ;
    wire                                            rotate_90                      ;
    wire                                            rotate_270                     ;
    wire                                            rotate_nv12                    ;
    wire                                            tile_hdr_fire                  ;
    wire                                            tile_data_fire                 ;
    wire                                            tile_done_fire                 ;
    wire        [15                     :0]         src_width                      ;
    wire        [15                     :0]         src_height                     ;
    wire        [15                     :0]         src_chroma_width               ;
    wire        [15                     :0]         src_chroma_height              ;
    wire        [15                     :0]         y_tile_cols                    ;
    wire        [15                     :0]         y_tile_rows                    ;
    wire        [15                     :0]         uv_tile_rows                   ;
    wire        [31                     :0]         expect_tile_count              ;
    wire        [15                     :0]         emit_words_per_line            ;
    wire        [15                     :0]         y_tile_last_x                  ;
    wire        [15                     :0]         y_tile_last_y                  ;
    wire        [15                     :0]         uv_tile_last_y                 ;
    wire                                            y_last_tile_done_fire          ;
    wire                                            uv_last_tile_done_fire         ;
    wire                                            collect_done_fire              ;
    wire                                            fifo_wr_en                     ;
    wire        [255                    :0]         fifo_wdata                     ;
    wire                                            fifo_full                      ;
    wire                                            fifo_empty                     ;
    wire        [255                    :0]         fifo_rdata                     ;
    wire                                            fifo_rd_en                     ;
    wire        [OTF_FIFO_DEPTH_BITS       :0]      fifo_rd_count                  ;
    wire                                            fifo_start_ready               ;
    wire                                            frame_start_fifo_wr_en         ;
    wire                                            frame_start_fifo_rd_en         ;
    wire                                            frame_start_fifo_full          ;
    wire                                            frame_start_fifo_empty         ;
    wire        [3                      :0]         frame_start_fifo_rdata         ;
    wire                                            otf_frame_start                ;
    wire                                            otf_frame_start_ready          ;
    wire                                            otf_driver_busy                ;
    wire                                            otf_frame_done_pulse           ;
    wire                                            otf_correct_irq_pulse          ;
    wire                                            otf_underflow                  ;
    wire        [31                     :0]         otf_line_count_otf             ;
    wire        [31                     :0]         otf_de_count_otf               ;
    wire                                            frame_done_sram_raw            ;
    wire                                            correct_irq_sram_raw           ;
    wire                                            underflow_sram_raw             ;
    wire                                            direct_fifo_rd_en              ;
    wire                                            direct_output_fire             ;
    wire                                            direct_phase_last              ;
    wire        [1                      :0]         direct_word_last_phase         ;
    wire                                            direct_word_last               ;
    wire                                            direct_line_last               ;
    wire                                            direct_done_fire               ;
    wire                                            direct_line_has_uv             ;

    reg                                             tile_active                    ;
    reg         [4                      :0]         tile_format_r                  ;
    reg         [15                     :0]         tile_x_r                       ;
    reg         [15                     :0]         tile_y_r                       ;
    reg         [3                      :0]         tile_fcnt_r                    ;
    reg         [3                      :0]         tile_beat_idx                  ;
    reg         [31                     :0]         tile_done_count                ;
    reg                                             emit_active                    ;
    reg         [15                     :0]         emit_line                      ;
    reg         [15                     :0]         emit_word_idx                  ;
    reg         [255                    :0]         emit_word_data                 ;
    reg                                             frame_done_toggle_otf          ;
    reg         [1                      :0]         frame_done_toggle_sram_sync    ;
    reg                                             correct_irq_toggle_otf         ;
    reg         [1                      :0]         correct_irq_toggle_sram_sync   ;
    reg                                             underflow_toggle_otf           ;
    reg         [1                      :0]         underflow_toggle_sram_sync     ;
    reg                                             otf_underflow_d                ;
    reg         [31                     :0]         otf_line_count_sram            ;
    reg         [31                     :0]         otf_de_count_sram              ;
    reg                                             direct_started                 ;
    reg         [3                      :0]         direct_fcnt                    ;
    reg         [15                     :0]         direct_line                    ;
    reg         [15                     :0]         direct_word_idx                ;
    reg         [1                      :0]         direct_phase                   ;
    reg                                             direct_compact_valid           ;
    reg         [255                    :0]         direct_compact_data            ;
    reg         [255                    :0]         direct_data_source             ;
    reg         [31                     :0]         direct_y_word                  ;
    reg         [31                     :0]         direct_uv_word                 ;
    reg         [127                    :0]         direct_otf_data_comb           ;
    reg                                             direct_otf_vsync               ;
    reg                                             direct_otf_hsync               ;
    reg                                             direct_otf_de                  ;
    reg         [127                    :0]         direct_otf_data                ;
    reg         [3                      :0]         direct_otf_fcnt                ;
    reg         [11                     :0]         direct_otf_lcnt                ;
    reg                                             direct_frame_done_pulse        ;
    reg                                             direct_correct_irq_pulse       ;
    reg         [31                     :0]         direct_line_count              ;
    reg         [31                     :0]         direct_de_count                ;
    reg                                             fifo_not_empty_r               ;
    reg                                             fifo_start_ready_r             ;
    reg                                             frame_start_fifo_not_empty_r    ;
    reg                                             y_plane_done_seen              ;
    reg                                             uv_plane_done_seen             ;

    reg         [255                    :0]         y_tile_mem                     [0:MAX_Y_TILE_WORDS-1];
    reg         [255                    :0]         uv_tile_mem                    [0:MAX_UV_TILE_WORDS-1];

    integer                                         wr_i                           ;
    integer                                         src_x_int                      ;
    integer                                         src_y_int                      ;
    integer                                         src_uv_x_int                   ;
    integer                                         src_uv_y_int                   ;
    integer                                         src_uv_byte_int                ;
    integer                                         dst_x_int                      ;
    integer                                         dst_y_int                      ;
    integer                                         dst_uv_x_int                   ;
    integer                                         dst_uv_y_int                   ;
    integer                                         src_tile_x_int                 ;
    integer                                         src_tile_y_int                 ;
    integer                                         src_tile_idx_int               ;
    integer                                         src_tile_word_int              ;
    integer                                         src_tile_byte_int              ;
    integer                                         src_uv_tile_x_int              ;
    integer                                         src_uv_tile_y_int              ;
    integer                                         src_uv_tile_idx_int            ;
    integer                                         src_uv_tile_word_int           ;
    integer                                         emit_phase_i                   ;
    integer                                         emit_x_int                     ;
    integer                                         emit_y_idx_int                 ;
    integer                                         emit_uv_idx_int                ;
    reg         [31                     :0]         emit_y_word                    ;
    reg         [31                     :0]         emit_uv_word                   ;

    assign frame_start                 = i_frame_start;
    assign rotate_90                   = (i_rotate_mode == 2'd1);
    assign rotate_270                  = (i_rotate_mode == 2'd2);
    assign rotate_nv12                 = ((cfg_format == BASE_FMT_NV12) ||
                                          (cfg_format == FMT_NV12_Y)    ||
                                          (cfg_format == FMT_NV12_UV)) &&
                                         (rotate_90 || rotate_270);
    assign src_width                   = cfg_img_width;
    assign src_height                  = cfg_otf_h_act;
    assign src_chroma_width            = {1'b0, src_width[15:1]};
    assign src_chroma_height           = {1'b0, src_height[15:1]};
    assign y_tile_cols                 = ((src_width + 16'd127) >> 7) << 2;
    assign y_tile_rows                 = (src_height + 16'd7) >> 3;
    assign uv_tile_rows                = (src_chroma_height + 16'd7) >> 3;
    assign expect_tile_count           = tile_done_count;
    assign emit_words_per_line         = (cfg_otf_h_act + 16'd15) >> 4;
    assign y_tile_last_x               = (y_tile_cols == 16'd0) ? 16'd0 :
                                                                    (y_tile_cols - 16'd1);
    assign y_tile_last_y               = (y_tile_rows == 16'd0) ? 16'd0 :
                                                                    (y_tile_rows - 16'd1);
    assign uv_tile_last_y              = (uv_tile_rows == 16'd0) ? 16'd0 :
                                                                    (uv_tile_rows - 16'd1);
    assign tile_hdr_fire               = s_axis_tile_valid && s_axis_tile_ready;
    assign tile_data_fire              = s_axis_tvalid && s_axis_tready;
    assign tile_done_fire              = tile_data_fire && (s_axis_tlast || (tile_beat_idx == 4'd7));
    assign y_last_tile_done_fire       = tile_done_fire &&
                                         (tile_format_r == FMT_NV12_Y) &&
                                         (tile_x_r == y_tile_last_x) &&
                                         (tile_y_r == y_tile_last_y);
    assign uv_last_tile_done_fire      = tile_done_fire &&
                                         (tile_format_r == FMT_NV12_UV) &&
                                         (tile_x_r == y_tile_last_x) &&
                                         (tile_y_r == uv_tile_last_y);
    assign collect_done_fire           = (y_last_tile_done_fire && uv_plane_done_seen) ||
                                         (uv_last_tile_done_fire && y_plane_done_seen);
    assign s_axis_tile_ready           = rotate_nv12 && !tile_active && !emit_active;
    assign s_axis_tready               = rotate_nv12 && tile_active;
    assign fifo_wr_en                  = emit_active && !fifo_full;
    assign fifo_wdata                  = emit_word_data;
    assign fifo_start_ready            = fifo_rd_count >= OTF_FIFO_START_LEVEL;
    assign frame_start_fifo_wr_en      = collect_done_fire && !frame_start_fifo_full;
    assign frame_start_fifo_rd_en      = frame_start_fifo_not_empty_r &&
                                         otf_frame_start_ready &&
                                         fifo_start_ready_r;
    assign otf_frame_start             = frame_start_fifo_rd_en;
    assign frame_done_sram_raw         = frame_done_toggle_sram_sync[1] ^
                                         frame_done_toggle_sram_sync[0];
    assign correct_irq_sram_raw        = correct_irq_toggle_sram_sync[1] ^
                                         correct_irq_toggle_sram_sync[0];
    assign underflow_sram_raw          = underflow_toggle_sram_sync[1] ^
                                         underflow_toggle_sram_sync[0];
    assign o_correct_irq_pulse         = correct_irq_sram_raw;
    assign o_underflow                 = underflow_sram_raw;
    assign o_otf_line_count            = otf_line_count_sram;
    assign o_otf_de_count              = otf_de_count_sram;
    assign o_busy                      = tile_active | emit_active | !fifo_empty | otf_driver_busy;
    assign fifo_rd_en                  = direct_fifo_rd_en;
    assign otf_driver_busy             = direct_started;
    assign otf_frame_start_ready       = !direct_started;
    assign otf_frame_done_pulse        = direct_frame_done_pulse;
    assign otf_correct_irq_pulse       = direct_correct_irq_pulse;
    assign otf_underflow               = 1'b0;
    assign otf_line_count_otf          = direct_line_count;
    assign otf_de_count_otf            = direct_de_count;
    assign direct_fifo_rd_en           = direct_started &&
                                         i_otf_ready &&
                                         (direct_phase == 2'd0) &&
                                         !direct_compact_valid &&
                                         fifo_not_empty_r;
    assign direct_output_fire          = direct_started &&
                                         i_otf_ready &&
                                         direct_compact_valid;
    assign direct_word_last            = (direct_word_idx == (emit_words_per_line - 16'd1));
    assign direct_word_last_phase      = direct_word_last ?
                                         ((cfg_otf_h_act[3:2] == 2'd0) ?
                                          2'd3 : (cfg_otf_h_act[3:2] - 2'd1)) :
                                         2'd3;
    assign direct_phase_last           = (direct_phase == direct_word_last_phase);
    assign direct_line_last            = (direct_line == (cfg_otf_v_act - 16'd1));
    assign direct_done_fire            = direct_output_fire &&
                                         direct_phase_last &&
                                         direct_word_last &&
                                         direct_line_last;
    assign direct_line_has_uv          = !direct_line[0];
    assign o_otf_vsync                 = direct_otf_vsync;
    assign o_otf_hsync                 = direct_otf_hsync;
    assign o_otf_de                    = direct_otf_de;
    assign o_otf_data                  = direct_otf_data;
    assign o_otf_fcnt                  = direct_otf_fcnt;
    assign o_otf_lcnt                  = direct_otf_lcnt;

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
        else if (frame_start)
            y_plane_done_seen <= 1'b0;
        else if (y_last_tile_done_fire)
            y_plane_done_seen <= 1'b1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            uv_plane_done_seen <= 1'b0;
        else if (frame_start)
            uv_plane_done_seen <= 1'b0;
        else if (uv_last_tile_done_fire)
            uv_plane_done_seen <= 1'b1;
    end

    always @(posedge clk_sram) begin
        if (tile_data_fire && (tile_format_r == FMT_NV12_Y)) begin
            src_tile_idx_int = (tile_y_r << 8) +
                               (tile_y_r << 5) +
                               (tile_x_r << 3) +
                               tile_beat_idx;
            if ((src_tile_idx_int >= 0) && (src_tile_idx_int < MAX_Y_TILE_WORDS))
                y_tile_mem[src_tile_idx_int] <= s_axis_tdata;
        end
    end

    always @(posedge clk_sram) begin
        if (tile_data_fire && (tile_format_r == FMT_NV12_UV)) begin
            src_uv_tile_idx_int = (tile_y_r << 8) +
                                  (tile_y_r << 5) +
                                  (tile_x_r << 3) +
                                  tile_beat_idx;
            if ((src_uv_tile_idx_int >= 0) && (src_uv_tile_idx_int < MAX_UV_TILE_WORDS))
                uv_tile_mem[src_uv_tile_idx_int] <= s_axis_tdata;
        end
    end

    always @(*) begin
        emit_word_data = 256'd0;
        for (emit_phase_i = 0; emit_phase_i < 4; emit_phase_i = emit_phase_i + 1) begin
            emit_x_int      = (emit_word_idx * 16) + (emit_phase_i * 4);
            emit_y_word     = 32'd0;
            emit_uv_word    = 32'd0;

            for (wr_i = 0; wr_i < 4; wr_i = wr_i + 1) begin
                dst_x_int = emit_x_int + wr_i;
                dst_y_int = emit_line;
                if (dst_x_int < cfg_otf_h_act) begin
                    if (rotate_90) begin
                        src_x_int = dst_y_int;
                        src_y_int = src_height - 1 - dst_x_int;
                    end else begin
                        src_x_int = src_width - 1 - dst_y_int;
                        src_y_int = dst_x_int;
                    end
                    src_tile_x_int    = src_x_int >> 5;
                    src_tile_y_int    = src_y_int >> 3;
                    src_tile_word_int = (src_tile_y_int << 8) +
                                        (src_tile_y_int << 5) +
                                        (src_tile_x_int << 3) +
                                        (src_y_int & 7);
                    src_tile_byte_int = src_x_int & 31;
                    if ((src_tile_word_int >= 0) &&
                        (src_tile_word_int < MAX_Y_TILE_WORDS)) begin
                        emit_y_word[wr_i*8 +: 8] =
                            y_tile_mem[src_tile_word_int][src_tile_byte_int*8 +: 8];
                    end
                end
            end

            if (!emit_line[0]) begin
                for (wr_i = 0; wr_i < 4; wr_i = wr_i + 1) begin
                    dst_x_int      = emit_x_int + wr_i;
                    dst_uv_x_int   = dst_x_int >> 1;
                    dst_uv_y_int   = emit_line >> 1;
                    if (dst_x_int < cfg_otf_h_act) begin
                        if (rotate_90) begin
                            src_uv_x_int = dst_uv_y_int;
                            src_uv_y_int = src_chroma_height - 1 - dst_uv_x_int;
                        end else begin
                            src_uv_x_int = src_chroma_width - 1 - dst_uv_y_int;
                            src_uv_y_int = dst_uv_x_int;
                        end
                        src_uv_tile_x_int    = src_uv_x_int >> 4;
                        src_uv_tile_y_int    = src_uv_y_int >> 3;
                        src_uv_tile_word_int = (src_uv_tile_y_int << 8) +
                                               (src_uv_tile_y_int << 5) +
                                               (src_uv_tile_x_int << 3) +
                                               (src_uv_y_int & 7);
                        src_uv_byte_int      = ((src_uv_x_int & 15) * 2) +
                                               (dst_x_int & 1);
                        if ((src_uv_tile_word_int >= 0) &&
                            (src_uv_tile_word_int < MAX_UV_TILE_WORDS)) begin
                            emit_uv_word[wr_i*8 +: 8] =
                                uv_tile_mem[src_uv_tile_word_int][src_uv_byte_int*8 +: 8];
                        end
                    end
                end
            end

            emit_word_data[(emit_phase_i*32) +: 32]       = emit_y_word;
            emit_word_data[128+(emit_phase_i*32) +: 32]   = emit_uv_word;
        end
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            emit_active <= 1'b0;
        else if (frame_start)
            emit_active <= 1'b0;
        else if (collect_done_fire)
            emit_active <= 1'b1;
        else if (fifo_wr_en &&
                 (emit_line == (cfg_otf_v_act - 16'd1)) &&
                 (emit_word_idx == (emit_words_per_line - 16'd1)))
            emit_active <= 1'b0;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            emit_line <= 16'd0;
        else if (frame_start || collect_done_fire)
            emit_line <= 16'd0;
        else if (fifo_wr_en && (emit_word_idx == (emit_words_per_line - 16'd1)))
            emit_line <= emit_line + 16'd1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            emit_word_idx <= 16'd0;
        else if (frame_start || collect_done_fire)
            emit_word_idx <= 16'd0;
        else if (fifo_wr_en)
            emit_word_idx <= (emit_word_idx == (emit_words_per_line - 16'd1)) ?
                             16'd0 : (emit_word_idx + 16'd1);
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
        .din                            ( tile_fcnt_r                           ),
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

    always @(*) begin
        direct_data_source      = direct_compact_data;
        direct_y_word           = 32'd0;
        direct_uv_word          = 32'd0;
        direct_otf_data_comb    = 128'd0;

        case (direct_phase)
            2'd0: begin
                direct_y_word   = direct_data_source[31:0];
                direct_uv_word  = direct_data_source[159:128];
            end
            2'd1: begin
                direct_y_word   = direct_data_source[63:32];
                direct_uv_word  = direct_data_source[191:160];
            end
            2'd2: begin
                direct_y_word   = direct_data_source[95:64];
                direct_uv_word  = direct_data_source[223:192];
            end
            default: begin
                direct_y_word   = direct_data_source[127:96];
                direct_uv_word  = direct_data_source[255:224];
            end
        endcase

        direct_otf_data_comb[15:8]      = direct_y_word[7:0];
        direct_otf_data_comb[47:40]     = direct_y_word[15:8];
        direct_otf_data_comb[79:72]     = direct_y_word[23:16];
        direct_otf_data_comb[111:104]   = direct_y_word[31:24];

        if (direct_line_has_uv) begin
            direct_otf_data_comb[7:0]   = direct_uv_word[15:8];
            direct_otf_data_comb[23:16] = direct_uv_word[7:0];
            direct_otf_data_comb[71:64] = direct_uv_word[31:24];
            direct_otf_data_comb[87:80] = direct_uv_word[23:16];
        end
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_started <= 1'b0;
        else if (direct_done_fire)
            direct_started <= 1'b0;
        else if (otf_frame_start)
            direct_started <= 1'b1;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            fifo_not_empty_r <= 1'b0;
        else
            fifo_not_empty_r <= !fifo_empty;
    end

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
            direct_fcnt <= 4'd0;
        else if (otf_frame_start)
            direct_fcnt <= frame_start_fifo_rdata;
    end

    always @(posedge clk_otf) begin
        if (direct_fifo_rd_en)
            direct_compact_data <= fifo_rdata;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_compact_valid <= 1'b0;
        else if (otf_frame_start || direct_done_fire)
            direct_compact_valid <= 1'b0;
        else if (direct_fifo_rd_en)
            direct_compact_valid <= 1'b1;
        else if (direct_output_fire && direct_phase_last)
            direct_compact_valid <= 1'b0;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_phase <= 2'd0;
        else if (otf_frame_start || direct_done_fire)
            direct_phase <= 2'd0;
        else if (direct_output_fire)
            direct_phase <= direct_phase_last ? 2'd0 : (direct_phase + 2'd1);
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_word_idx <= 16'd0;
        else if (otf_frame_start || direct_done_fire)
            direct_word_idx <= 16'd0;
        else if (direct_output_fire && direct_phase_last)
            direct_word_idx <= direct_word_last ? 16'd0 : (direct_word_idx + 16'd1);
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_line <= 16'd0;
        else if (otf_frame_start || direct_done_fire)
            direct_line <= 16'd0;
        else if (direct_output_fire && direct_phase_last && direct_word_last)
            direct_line <= direct_line_last ? 16'd0 : (direct_line + 16'd1);
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_frame_done_pulse <= 1'b0;
        else
            direct_frame_done_pulse <= direct_done_fire;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_correct_irq_pulse <= 1'b0;
        else
            direct_correct_irq_pulse <= direct_done_fire;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_line_count <= 32'd0;
        else if (otf_frame_start)
            direct_line_count <= 32'd0;
        else if (direct_output_fire && direct_phase_last && direct_word_last)
            direct_line_count <= direct_line_count + 32'd1;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_de_count <= 32'd0;
        else if (otf_frame_start)
            direct_de_count <= 32'd0;
        else if (direct_output_fire)
            direct_de_count <= direct_de_count + 32'd1;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_otf_vsync <= 1'b0;
        else
            direct_otf_vsync <= otf_frame_start;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_otf_hsync <= 1'b0;
        else
            direct_otf_hsync <= direct_output_fire &&
                                (direct_phase == 2'd0) &&
                                (direct_word_idx == 16'd0);
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_otf_de <= 1'b0;
        else
            direct_otf_de <= direct_output_fire;
    end

    always @(posedge clk_otf) begin
        if (direct_output_fire)
            direct_otf_data <= direct_otf_data_comb;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_otf_fcnt <= 4'd0;
        else if (otf_frame_start)
            direct_otf_fcnt <= frame_start_fifo_rdata;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            direct_otf_lcnt <= 12'd0;
        else if (direct_output_fire)
            direct_otf_lcnt <= direct_line[11:0];
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            frame_done_toggle_otf <= 1'b0;
        else if (otf_frame_done_pulse)
            frame_done_toggle_otf <= ~frame_done_toggle_otf;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            correct_irq_toggle_otf <= 1'b0;
        else if (otf_correct_irq_pulse)
            correct_irq_toggle_otf <= ~correct_irq_toggle_otf;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            otf_underflow_d <= 1'b0;
        else
            otf_underflow_d <= otf_underflow;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            underflow_toggle_otf <= 1'b0;
        else if (otf_underflow && !otf_underflow_d)
            underflow_toggle_otf <= ~underflow_toggle_otf;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            frame_done_toggle_sram_sync <= 2'b00;
        else
            frame_done_toggle_sram_sync <= {frame_done_toggle_sram_sync[0],
                                            frame_done_toggle_otf};
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            correct_irq_toggle_sram_sync <= 2'b00;
        else
            correct_irq_toggle_sram_sync <= {correct_irq_toggle_sram_sync[0],
                                             correct_irq_toggle_otf};
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            underflow_toggle_sram_sync <= 2'b00;
        else
            underflow_toggle_sram_sync <= {underflow_toggle_sram_sync[0],
                                           underflow_toggle_otf};
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            otf_line_count_sram <= 32'd0;
        else
            otf_line_count_sram <= otf_line_count_otf;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            otf_de_count_sram <= 32'd0;
        else
            otf_de_count_sram <= otf_de_count_otf;
    end

endmodule
