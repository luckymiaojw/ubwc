//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-06-21
// Module Name       : ubwc_dec_meta_fifo16_rcmd_gen.v
// Description       : DEC metadata AXI read with 16-channel FIFO reorder buffer
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_dec_meta_fifo16_rcmd_gen #(
    parameter                                       ADDR_WIDTH                      = 32,
    parameter                                       ID_WIDTH                        = 4,
    parameter                                       DATA_WIDTH                      = 256,
    parameter                                       TW_DW                           = 16,
    parameter                                       TH_DW                           = 16,
    parameter                                       FIFO_AW                         = 5
)(
    input   wire                                        clk                             ,
    input   wire                                        rst_n                           ,
    input   wire                                        start                           ,
    input   wire    [1                      :0]         i_rotate_mode                   ,
    input   wire    [4                      :0]         base_format                     ,
    input   wire    [TW_DW               -1 :0]         tile_x_numbers                  ,
    input   wire    [TH_DW               -1 :0]         tile_y_numbers                  ,

    output  wire                                        m_axi_arvalid                   ,
    input   wire                                        m_axi_arready                   ,
    output  wire    [ADDR_WIDTH          -1 :0]         m_axi_araddr                    ,
    output  wire    [7                      :0]         m_axi_arlen                     ,
    output  wire    [2                      :0]         m_axi_arsize                    ,
    output  wire    [1                      :0]         m_axi_arburst                   ,
    output  wire    [ID_WIDTH            -1 :0]         m_axi_arid                      ,

    input   wire                                        m_axi_rvalid                    ,
    output  wire                                        m_axi_rready                    ,
    input   wire    [DATA_WIDTH          -1 :0]         m_axi_rdata                     ,
    input   wire    [ID_WIDTH            -1 :0]         m_axi_rid                       ,
    input   wire    [1                      :0]         m_axi_rresp                     ,
    input   wire                                        m_axi_rlast                     ,

    input   wire                                        meta_blk_valid                  ,
    output  wire                                        meta_blk_ready                  ,
    input   wire    [ADDR_WIDTH          -1 :0]         meta_blk_addr                   ,
    input   wire    [4                      :0]         meta_blk_format                 ,
    input   wire    [TW_DW               -1 :0]         meta_blk_xbase                  ,
    input   wire    [TH_DW               -1 :0]         meta_blk_ybase                  ,
    input   wire    [3                      :0]         meta_blk_cols_valid             ,
    input   wire    [3                      :0]         meta_blk_rows_valid             ,
    input   wire                                        meta_blk_is_uv                  ,
    input   wire    [3                      :0]         meta_blk_fcnt                   ,

    output  wire                                        meta_data_valid                 ,
    input   wire                                        meta_data_ready                 ,
    output  reg     [7                      :0]         meta_data                       ,
    output  wire    [4                      :0]         meta_data_format                ,
    output  wire    [TW_DW               -1 :0]         meta_data_xcoord                ,
    output  wire    [TH_DW               -1 :0]         meta_data_ycoord                ,
    output  wire    [3                      :0]         meta_data_fcnt                  ,

    output  reg     [31                     :0]         error_cnt                       ,
    output  reg     [31                     :0]         cmd_ok_cnt                      ,
    output  reg     [31                     :0]         cmd_fail_cnt
);

    localparam  integer                             BYTES_PER_BEAT                  = DATA_WIDTH / 8;
    localparam  integer                             ARSIZE_VALUE                    = $clog2(BYTES_PER_BEAT);
    localparam  integer                             FIFO_DEPTH                      = 1 << FIFO_AW;
    localparam  integer                             FIFO_CNT_W                      = FIFO_AW + 1;
    localparam  integer                             ENTRY_W                         = 64;
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

    wire                                            base_is_rgba                    ;
    wire                                            base_is_nv12                    ;
    wire                                            base_is_p010                    ;
    wire                                            base_is_yuv420                  ;
    wire                                            rotate_mode_requested           ;
    wire                                            rotate_nv12_mode                ;
    wire                                            rotate_270_mode                 ;
    wire                                            blk_accept_fire                 ;
    wire                                            ar_fire                         ;
    wire                                            r_fire                          ;
    wire                                            blk_push_fire                   ;
    wire                                            r_resp_ok                       ;
    wire                                            r_id_match                      ;
    wire                                            active_is_rgba                  ;
    wire                                            active_rgba_lane_hi             ;
    wire        [TW_DW                  :0]         tile_blk_cols_ext               ;
    wire        [TW_DW               -1 :0]         tile_blk_cols                   ;
    wire        [TH_DW                  :0]         uv_tile_y_numbers_ext           ;
    wire        [TH_DW               -1 :0]         uv_tile_y_numbers               ;
    wire        [TH_DW                  :0]         y_blk_rows_ext_calc             ;
    wire        [TH_DW                  :0]         uv_blk_rows_ext_calc            ;
    wire        [TH_DW               -1 :0]         y_blk_rows                      ;
    wire        [TH_DW               -1 :0]         uv_blk_rows                     ;
    wire        [TW_DW               -1 :0]         y_blk_rows_ext                  ;
    wire        [TW_DW               -1 :0]         uv_blk_rows_ext                 ;
    wire        [TW_DW               -1 :0]         y_tile_rows_ext                 ;
    wire        [TW_DW               -1 :0]         uv_tile_rows_ext                ;
    wire        [TW_DW               -1 :0]         rgba_lane0_cols                 ;
    wire        [TW_DW               -1 :0]         rgba_lane1_cols                 ;
    wire        [TW_DW               -1 :0]         active_blk_col_idx              ;
    wire        [ID_WIDTH             -1 :0]        active_axi_id                   ;
    wire        [3                      :0]         rd_rgba_channel                 ;
    wire        [3                      :0]         rd_rotate_channel               ;
    wire        [3                      :0]         rd_yuv_channel                  ;
    wire        [511                    :0]         blk_write_data                  ;
    wire        [ENTRY_W            -1 :0]          rd_entry                        ;
    wire        [63                     :0]         rd_entry_data                   ;
    wire        [3                      :0]         rd_channel                      ;
    wire                                            rd_channel_valid                ;
    wire                                            rd_entry_done_fire              ;
    wire                                            rd_line_done_fire               ;
    wire                                            rd_rgba_lane0_done              ;
    wire                                            rd_rgba_lane1_done              ;
    wire                                            rd_rgba_lane1_empty             ;
    wire                                            rd_rgba_row_done                ;
    wire        [TW_DW               -1 :0]         rd_line_target_entries          ;
    wire        [TW_DW               -1 :0]         rd_line_entry_next              ;
    wire        [TW_DW               -1 :0]         rd_rotate_x_start               ;
    wire        [TW_DW               -1 :0]         rd_rgba_entry_idx               ;
    wire        [TW_DW               -1 :0]         rd_meta_xbase                   ;
    wire        [TW_DW               -1 :0]         rd_meta_xcoord                  ;
    wire        [TH_DW               -1 :0]         rd_row_idx_ext                  ;
    wire        [TH_DW               -1 :0]         rd_yuv_y_pair_offset            ;
    wire        [TH_DW               -1 :0]         rd_yuv_y0_ycoord                ;
    wire        [TH_DW               -1 :0]         rd_yuv_y1_ycoord                ;
    wire        [TH_DW               -1 :0]         rd_yuv_uv_ycoord                ;
    wire        [TH_DW               -1 :0]         rd_rgba_ycoord                  ;
    wire        [TH_DW               -1 :0]         rd_rotate_ybase                 ;
    wire        [TH_DW               -1 :0]         rd_rotate_ycoord                ;
    wire        [TH_DW               -1 :0]         rd_meta_ycoord                  ;
    wire        [4                      :0]         rd_rgba_format                  ;
    wire        [4                      :0]         rd_yuv_y_format                 ;
    wire        [4                      :0]         rd_yuv_uv_format                ;
    wire        [4                      :0]         rd_meta_format                  ;
    wire        [2                      :0]         rd_yuv_y0_channel               ;
    wire        [2                      :0]         rd_yuv_y1_channel               ;
    wire        [15                     :0]         fifo_full                       ;
    wire        [15                     :0]         fifo_prog_full                  ;
    wire        [15                     :0]         fifo_empty                      ;
    wire        [15                     :0]         fifo_valid                      ;
    wire        [15                     :0]         fifo_wr_en                      ;
    wire        [15                     :0]         fifo_rd_en                      ;
    wire        [ENTRY_W            -1 :0]          fifo_din                        [0:15];
    wire        [ENTRY_W            -1 :0]          fifo_dout                       [0:15];
    wire        [FIFO_CNT_W         -1 :0]          fifo_count                      [0:15];

    reg                                             ar_active                       ;
    reg                                             r_active                        ;
    reg         [1                      :0]         r_beat_cnt                      ;
    reg         [255                    :0]         r_first_beat                    ;
    reg         [ADDR_WIDTH          -1 :0]         active_blk_addr                 ;
    reg         [4                      :0]         active_blk_format               ;
    reg         [TW_DW               -1 :0]         active_blk_xbase                ;
    reg         [TH_DW               -1 :0]         active_blk_ybase                ;
    reg         [3                      :0]         active_blk_rows_valid           ;
    reg                                             active_blk_is_uv                ;
    reg         [3                      :0]         active_blk_fcnt                 ;
    reg         [15                     :0]         active_wr_mask                  ;
    reg                                             r_burst_fail                    ;
    reg         [1                      :0]         rd_phase                        ;
    reg         [2                      :0]         rd_row_idx                      ;
    reg                                             rd_rgba_lane                    ;
    reg         [TW_DW               -1 :0]         rd_rotate_x_base                ;
    reg         [TH_DW               -1 :0]         rd_group_y_base                 ;
    reg         [TH_DW               -1 :0]         rd_group_uv_base                ;
    reg         [TW_DW               -1 :0]         rd_line_entry_idx               ;
    reg         [2                      :0]         rd_byte_idx                     ;
    reg         [3                      :0]         rd_frame_fcnt                   ;
    reg         [FIFO_CNT_W         -1 :0]          fifo_reserved                   [0:15];
    reg         [15                     :0]         target_mask                     ;
    reg                                             target_credit_block             ;
    reg         [15                     :0]         fifo_wr_en_r                    ;
    reg         [15                     :0]         fifo_rd_en_r                    ;
    reg         [ENTRY_W            -1 :0]          fifo_din_r                      [0:15];
    reg         [7                      :0]         rotate_lane_byte                [0:7];
    reg                                             rd_entry_pop_hold               ;

    integer                                         target_i                        ;
    integer                                         wr_i                            ;
    integer                                         rst_i                           ;
    integer                                         credit_i                        ;
    genvar                                          fifo_gen_i                      ;

    assign base_is_rgba                = (base_format == BASE_FMT_RGBA8888) ||
                                         (base_format == BASE_FMT_RGBA1010102);
    assign base_is_nv12                = (base_format == BASE_FMT_YUV420_8);
    assign base_is_p010                = (base_format == BASE_FMT_YUV420_10);
    assign base_is_yuv420              = base_is_nv12 || base_is_p010;
    assign rotate_mode_requested       = (|i_rotate_mode) && base_is_nv12;
    assign rotate_nv12_mode            = rotate_mode_requested;
    assign rotate_270_mode             = (i_rotate_mode == 2'd2) && base_is_nv12;
    assign tile_blk_cols_ext           = ({1'b0, tile_x_numbers} +
                                          {{(TW_DW-3){1'b0}}, 4'd7}) >> 3;
    assign tile_blk_cols               = tile_blk_cols_ext[TW_DW-1:0];
    assign uv_tile_y_numbers_ext       = {1'b0, tile_y_numbers} + {{TH_DW{1'b0}}, 1'b1};
    assign uv_tile_y_numbers           = uv_tile_y_numbers_ext[TH_DW:1];
    assign y_blk_rows_ext_calc         = ({1'b0, tile_y_numbers} +
                                          {{(TH_DW-3){1'b0}}, 4'd7}) >> 3;
    assign uv_blk_rows_ext_calc        = ({1'b0, uv_tile_y_numbers} +
                                          {{(TH_DW-3){1'b0}}, 4'd7}) >> 3;
    assign y_blk_rows                  = y_blk_rows_ext_calc[TH_DW-1:0];
    assign uv_blk_rows                 = uv_blk_rows_ext_calc[TH_DW-1:0];
    assign y_blk_rows_ext              = {{(TW_DW-TH_DW){1'b0}}, y_blk_rows};
    assign uv_blk_rows_ext             = {{(TW_DW-TH_DW){1'b0}}, uv_blk_rows};
    assign y_tile_rows_ext             = {{(TW_DW-TH_DW){1'b0}}, tile_y_numbers};
    assign uv_tile_rows_ext            = {{(TW_DW-TH_DW){1'b0}}, uv_tile_y_numbers};
    assign rgba_lane0_cols             = (tile_blk_cols + {{(TW_DW-1){1'b0}}, 1'b1}) >> 1;
    assign rgba_lane1_cols             = tile_blk_cols - rgba_lane0_cols;
    assign active_blk_col_idx          = active_blk_xbase >> 3;
    assign active_is_rgba              = (active_blk_format == BASE_FMT_RGBA8888) ||
                                         (active_blk_format == BASE_FMT_RGBA1010102);
    assign active_rgba_lane_hi         = active_is_rgba && (active_blk_col_idx >= rgba_lane0_cols);
    assign blk_accept_fire             = meta_blk_valid && meta_blk_ready;
    assign ar_fire                     = m_axi_arvalid && m_axi_arready;
    assign r_fire                      = m_axi_rvalid && m_axi_rready;
    assign blk_push_fire               = r_fire && m_axi_rlast;
    assign r_resp_ok                   = (m_axi_rresp == 2'b00) || (m_axi_rresp == 2'b01);
    assign active_axi_id               = ID_WIDTH'(active_blk_fcnt);
    assign r_id_match                  = (m_axi_rid == active_axi_id);
    assign blk_write_data              = {m_axi_rdata, r_first_beat};
    assign meta_blk_ready              = !start && !ar_active && !r_active &&
                                         !target_credit_block;
    assign m_axi_arvalid               = ar_active;
    assign m_axi_araddr                = active_blk_addr;
    assign m_axi_arlen                 = 8'd1;
    assign m_axi_arsize                = ARSIZE_VALUE[2:0];
    assign m_axi_arburst               = 2'b01;
    assign m_axi_arid                  = active_axi_id;
    assign m_axi_rready                = r_active;
    assign rd_yuv_y0_channel           = {rd_row_idx[1:0], 1'b0};
    assign rd_yuv_y1_channel           = {rd_row_idx[1:0], 1'b0} + 3'd1;
    assign rd_rgba_channel             = {1'b0, rd_row_idx} + (rd_rgba_lane ? 4'd8 : 4'd0);
    assign rd_rotate_channel           = (rd_phase == 2'd0) ? {1'b0, rd_line_entry_idx[2:0]} :
                                                              {1'b1, rd_line_entry_idx[2:0]};
    assign rd_yuv_channel              = (rd_phase == 2'd0) ? {1'b0, rd_row_idx} :
                                         (rd_phase == 2'd1) ? {1'b1, rd_yuv_y0_channel} :
                                                              {1'b1, rd_yuv_y1_channel};
    assign rd_channel                  = base_is_rgba ? rd_rgba_channel :
                                         rotate_nv12_mode ? rd_rotate_channel :
                                                            rd_yuv_channel;
    assign rd_entry                    = fifo_dout[rd_channel];
    assign rd_entry_data               = rd_entry;
    assign rd_channel_valid            = fifo_valid[rd_channel];
    assign meta_data_valid             = rd_channel_valid && !rd_entry_pop_hold;
    assign rd_rgba_entry_idx           = rd_rgba_lane ? (rgba_lane0_cols + rd_line_entry_idx) :
                                                        rd_line_entry_idx;
    assign rd_meta_xbase               = rotate_nv12_mode ? rd_rotate_x_base :
                                         base_is_rgba     ? {rd_rgba_entry_idx[TW_DW-4:0], 3'b000} :
                                                            {rd_line_entry_idx[TW_DW-4:0], 3'b000};
    assign rd_meta_xcoord              = rotate_nv12_mode ? rd_meta_xbase :
                                         (rd_meta_xbase + {{(TW_DW-3){1'b0}}, rd_byte_idx});
    assign rd_row_idx_ext              = {{(TH_DW-3){1'b0}}, rd_row_idx};
    assign rd_yuv_y_pair_offset        = {{(TH_DW-4){1'b0}}, rd_row_idx[2], rd_row_idx[1:0], 1'b0};
    assign rd_yuv_y0_ycoord            = rd_group_y_base + rd_yuv_y_pair_offset;
    assign rd_yuv_y1_ycoord            = rd_yuv_y0_ycoord + {{(TH_DW-1){1'b0}}, 1'b1};
    assign rd_yuv_uv_ycoord            = rd_group_uv_base + rd_row_idx_ext;
    assign rd_rgba_ycoord              = rd_group_y_base + rd_row_idx_ext;
    assign rd_rotate_ybase             = rd_line_entry_idx[TH_DW-1:0];
    assign rd_rotate_ycoord            = rd_rotate_ybase;
    assign rd_meta_ycoord              = base_is_rgba      ? rd_rgba_ycoord :
                                         rotate_nv12_mode  ? rd_rotate_ycoord :
                                         (rd_phase == 2'd0) ? rd_yuv_uv_ycoord :
                                         (rd_phase == 2'd1) ? rd_yuv_y0_ycoord :
                                                              rd_yuv_y1_ycoord;
    assign rd_rgba_format              = (base_format == BASE_FMT_RGBA1010102) ? META_FMT_RGBA1010102 :
                                                                                  META_FMT_RGBA8888;
    assign rd_yuv_y_format             = base_is_p010 ? META_FMT_P010_Y :
                                                        META_FMT_NV12_Y;
    assign rd_yuv_uv_format            = base_is_p010 ? META_FMT_P010_UV :
                                                        META_FMT_NV12_UV;
    assign rd_meta_format              = base_is_rgba      ? rd_rgba_format :
                                         (rd_phase == 2'd0) ? rd_yuv_uv_format :
                                                              rd_yuv_y_format;
    assign meta_data_format            = rd_meta_format;
    assign meta_data_xcoord            = rd_meta_xcoord;
    assign meta_data_ycoord            = rd_meta_ycoord;
    assign meta_data_fcnt              = rd_frame_fcnt;
    assign rd_entry_done_fire          = meta_data_valid && meta_data_ready &&
                                         (rotate_nv12_mode || (rd_byte_idx == 3'd7));
    assign rd_line_target_entries      = base_is_rgba ? (rd_rgba_lane ? rgba_lane1_cols : rgba_lane0_cols) :
                                         rotate_nv12_mode ? ((rd_phase == 2'd0) ? uv_tile_rows_ext :
                                                                                  y_tile_rows_ext) :
                                                             tile_blk_cols;
    assign rd_line_entry_next          = rd_line_entry_idx + {{(TW_DW-1){1'b0}}, 1'b1};
    assign rd_rotate_x_start           = rotate_270_mode ?
                                         (tile_x_numbers - {{(TW_DW-1){1'b0}}, 1'b1}) :
                                         {TW_DW{1'b0}};
    assign rd_line_done_fire           = rd_entry_done_fire && (rd_line_entry_next >= rd_line_target_entries);
    assign rd_rgba_lane0_done          = base_is_rgba && rd_line_done_fire && !rd_rgba_lane;
    assign rd_rgba_lane1_done          = base_is_rgba && rd_line_done_fire && rd_rgba_lane;
    assign rd_rgba_lane1_empty         = (rgba_lane1_cols == {TW_DW{1'b0}});
    assign rd_rgba_row_done            = rd_rgba_lane1_done ||
                                         (rd_rgba_lane0_done && rd_rgba_lane1_empty);

    always @* begin
        target_credit_block = 1'b0;
        for (credit_i = 0; credit_i < 16; credit_i = credit_i + 1) begin
            if (target_mask[credit_i] &&
                ((fifo_count[credit_i] + fifo_reserved[credit_i]) >= FIFO_CNT_W'(FIFO_DEPTH))) begin
                target_credit_block = 1'b1;
            end
        end
    end

    always @* begin
        for (target_i = 0; target_i < 16; target_i = target_i + 1)
            target_mask[target_i] = 1'b0;
        for (target_i = 0; target_i < 8; target_i = target_i + 1) begin
            if ((meta_blk_format == BASE_FMT_RGBA8888) ||
                (meta_blk_format == BASE_FMT_RGBA1010102)) begin
                target_mask[target_i + (((meta_blk_xbase >> 3) >= rgba_lane0_cols) ? 8 : 0)] = 1'b1;
            end else if (meta_blk_is_uv) begin
                target_mask[target_i] = 1'b1;
            end else begin
                target_mask[target_i + 8] = 1'b1;
            end
        end
    end

    always @* begin
        case (rd_byte_idx)
            3'd0: meta_data = rd_entry_data[ 7: 0];
            3'd1: meta_data = rd_entry_data[15: 8];
            3'd2: meta_data = rd_entry_data[23:16];
            3'd3: meta_data = rd_entry_data[31:24];
            3'd4: meta_data = rd_entry_data[39:32];
            3'd5: meta_data = rd_entry_data[47:40];
            3'd6: meta_data = rd_entry_data[55:48];
            default: meta_data = rd_entry_data[63:56];
        endcase
    end

    always @* begin
        for (wr_i = 0; wr_i < 8; wr_i = wr_i + 1) begin
            case (active_blk_xbase[2:0])
                3'd0:    rotate_lane_byte[wr_i] = blk_write_data[(wr_i*64) +  0 +: 8];
                3'd1:    rotate_lane_byte[wr_i] = blk_write_data[(wr_i*64) +  8 +: 8];
                3'd2:    rotate_lane_byte[wr_i] = blk_write_data[(wr_i*64) + 16 +: 8];
                3'd3:    rotate_lane_byte[wr_i] = blk_write_data[(wr_i*64) + 24 +: 8];
                3'd4:    rotate_lane_byte[wr_i] = blk_write_data[(wr_i*64) + 32 +: 8];
                3'd5:    rotate_lane_byte[wr_i] = blk_write_data[(wr_i*64) + 40 +: 8];
                3'd6:    rotate_lane_byte[wr_i] = blk_write_data[(wr_i*64) + 48 +: 8];
                default: rotate_lane_byte[wr_i] = blk_write_data[(wr_i*64) + 56 +: 8];
            endcase
        end

        for (wr_i = 0; wr_i < 16; wr_i = wr_i + 1) begin
            fifo_wr_en_r[wr_i] = 1'b0;
            fifo_rd_en_r[wr_i] = 1'b0;
            fifo_din_r[wr_i]   = {ENTRY_W{1'b0}};
        end

        for (wr_i = 0; wr_i < 8; wr_i = wr_i + 1) begin
            if (rotate_nv12_mode && active_blk_is_uv) begin
                fifo_wr_en_r[wr_i] = blk_push_fire && (4'(wr_i) < active_blk_rows_valid);
                fifo_din_r[wr_i]   = {{(ENTRY_W-8){1'b0}}, rotate_lane_byte[wr_i]};
            end else if (rotate_nv12_mode) begin
                fifo_wr_en_r[wr_i+8] = blk_push_fire && (4'(wr_i) < active_blk_rows_valid);
                fifo_din_r[wr_i+8]   = {{(ENTRY_W-8){1'b0}}, rotate_lane_byte[wr_i]};
            end else if (active_is_rgba) begin
                fifo_wr_en_r[wr_i + (active_rgba_lane_hi ? 8 : 0)] = blk_push_fire;
                fifo_din_r[wr_i + (active_rgba_lane_hi ? 8 : 0)]   = blk_write_data[(wr_i*64) +: 64];
            end else if (active_blk_is_uv) begin
                fifo_wr_en_r[wr_i] = blk_push_fire;
                fifo_din_r[wr_i]   = blk_write_data[(wr_i*64) +: 64];
            end else begin
                fifo_wr_en_r[wr_i+8] = blk_push_fire;
                fifo_din_r[wr_i+8]   = blk_write_data[(wr_i*64) +: 64];
            end
        end

        fifo_rd_en_r[rd_channel] = rd_entry_done_fire;
    end

    generate
        for (fifo_gen_i = 0; fifo_gen_i < 16; fifo_gen_i = fifo_gen_i + 1) begin : gen_meta_fifo
            assign fifo_wr_en[fifo_gen_i] = fifo_wr_en_r[fifo_gen_i];
            assign fifo_rd_en[fifo_gen_i] = fifo_rd_en_r[fifo_gen_i];
            assign fifo_din[fifo_gen_i]   = fifo_din_r[fifo_gen_i];

            ubwc_sync_sram_fifo #(
                .PROG_DEPTH                 ( 4                                     ),
                .DWIDTH                     ( ENTRY_W                               ),
                .DEPTH                      ( FIFO_DEPTH                            ),
                .AWIDTH                     ( FIFO_AW                               ),
                .CWIDTH                     ( FIFO_CNT_W                            )
            ) u_entry_fifo (
                .clk                        ( clk                                   ),
                .rst_n                      ( rst_n                                 ),
                .clear                      ( start                                 ),
                .wr_en                      ( fifo_wr_en[fifo_gen_i]                ),
                .din                        ( fifo_din[fifo_gen_i]                  ),
                .prog_full                  ( fifo_prog_full[fifo_gen_i]            ),
                .full                       ( fifo_full[fifo_gen_i]                 ),
                .rd_en                      ( fifo_rd_en[fifo_gen_i]                ),
                .empty                      ( fifo_empty[fifo_gen_i]                ),
                .dout                       ( fifo_dout[fifo_gen_i]                 ),
                .valid                      ( fifo_valid[fifo_gen_i]                ),
                .data_count                 ( fifo_count[fifo_gen_i]                )
            );
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ar_active <= 1'b0;
        else if (start)
            ar_active <= 1'b0;
        else if (blk_accept_fire)
            ar_active <= 1'b1;
        else if (ar_fire)
            ar_active <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            r_active <= 1'b0;
        else if (start)
            r_active <= 1'b0;
        else if (ar_fire)
            r_active <= 1'b1;
        else if (blk_push_fire)
            r_active <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            r_beat_cnt <= 2'd0;
        else if (start || ar_fire)
            r_beat_cnt <= 2'd0;
        else if (r_fire)
            r_beat_cnt <= r_beat_cnt + 2'd1;
    end

    always @(posedge clk) begin
        if (r_fire && (r_beat_cnt == 2'd0))
            r_first_beat <= m_axi_rdata;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_blk_addr <= {ADDR_WIDTH{1'b0}};
        else if (blk_accept_fire)
            active_blk_addr <= meta_blk_addr;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_blk_format <= 5'd0;
        else if (blk_accept_fire)
            active_blk_format <= meta_blk_format;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_blk_xbase <= {TW_DW{1'b0}};
        else if (blk_accept_fire)
            active_blk_xbase <= meta_blk_xbase;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_blk_ybase <= {TH_DW{1'b0}};
        else if (blk_accept_fire)
            active_blk_ybase <= meta_blk_ybase;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_blk_rows_valid <= 4'd0;
        else if (blk_accept_fire)
            active_blk_rows_valid <= meta_blk_rows_valid;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_blk_is_uv <= 1'b0;
        else if (blk_accept_fire)
            active_blk_is_uv <= meta_blk_is_uv;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_blk_fcnt <= 4'd0;
        else if (blk_accept_fire)
            active_blk_fcnt <= meta_blk_fcnt;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            active_wr_mask <= 16'd0;
        else if (blk_accept_fire)
            active_wr_mask <= target_mask;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            r_burst_fail <= 1'b0;
        else if (start || ar_fire)
            r_burst_fail <= 1'b0;
        else if (r_fire && (!r_resp_ok || !r_id_match))
            r_burst_fail <= 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_phase <= 2'd0;
        else if (start)
            rd_phase <= 2'd0;
        else if (rd_line_done_fire && !base_is_rgba) begin
            if (rotate_nv12_mode)
                rd_phase <= (rd_phase == 2'd0) ? 2'd1 : 2'd0;
            else if (rd_phase == 2'd0)
                rd_phase <= 2'd1;
            else if (rd_phase == 2'd1)
                rd_phase <= 2'd2;
            else
                rd_phase <= 2'd0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_row_idx <= 3'd0;
        else if (start)
            rd_row_idx <= 3'd0;
        else if (rd_rgba_row_done && (rd_row_idx != 3'd7))
            rd_row_idx <= rd_row_idx + 3'd1;
        else if (rd_rgba_row_done)
            rd_row_idx <= 3'd0;
        else if (rd_line_done_fire && rotate_nv12_mode)
            rd_row_idx <= 3'd0;
        else if (rd_line_done_fire && !rotate_nv12_mode && (rd_phase == 2'd2) && (rd_row_idx != 3'd7))
            rd_row_idx <= rd_row_idx + 3'd1;
        else if (rd_line_done_fire && !rotate_nv12_mode && (rd_phase == 2'd2))
            rd_row_idx <= 3'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_rgba_lane <= 1'b0;
        else if (start)
            rd_rgba_lane <= 1'b0;
        else if (rd_rgba_lane0_done && !rd_rgba_lane1_empty)
            rd_rgba_lane <= 1'b1;
        else if (rd_rgba_lane1_done || (rd_rgba_lane0_done && rd_rgba_lane1_empty))
            rd_rgba_lane <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_rotate_x_base <= {TW_DW{1'b0}};
        else if (start)
            rd_rotate_x_base <= rd_rotate_x_start;
        else if (rd_line_done_fire && rotate_nv12_mode && (rd_phase == 2'd1))
            rd_rotate_x_base <= rotate_270_mode ?
                                (rd_rotate_x_base - {{(TW_DW-1){1'b0}}, 1'b1}) :
                                (rd_rotate_x_base + {{(TW_DW-1){1'b0}}, 1'b1});
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_group_y_base <= {TH_DW{1'b0}};
        else if (start)
            rd_group_y_base <= {TH_DW{1'b0}};
        else if (rd_rgba_row_done && (rd_row_idx == 3'd7))
            rd_group_y_base <= rd_group_y_base + {{(TH_DW-4){1'b0}}, 4'd8};
        else if (rd_line_done_fire && !base_is_rgba && !rotate_nv12_mode &&
                 (rd_phase == 2'd2) && (rd_row_idx == 3'd7))
            rd_group_y_base <= rd_group_y_base + {{(TH_DW-5){1'b0}}, 5'd16};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_group_uv_base <= {TH_DW{1'b0}};
        else if (start)
            rd_group_uv_base <= {TH_DW{1'b0}};
        else if (rd_line_done_fire && !base_is_rgba && !rotate_nv12_mode &&
                 (rd_phase == 2'd2) && (rd_row_idx == 3'd7))
            rd_group_uv_base <= rd_group_uv_base + {{(TH_DW-4){1'b0}}, 4'd8};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_line_entry_idx <= {TW_DW{1'b0}};
        else if (start || rd_line_done_fire)
            rd_line_entry_idx <= {TW_DW{1'b0}};
        else if (rd_entry_done_fire)
            rd_line_entry_idx <= rd_line_entry_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_byte_idx <= 3'd0;
        else if (start)
            rd_byte_idx <= 3'd0;
        else if (rotate_nv12_mode)
            rd_byte_idx <= 3'd0;
        else if (meta_data_valid && meta_data_ready)
            rd_byte_idx <= (rd_byte_idx == 3'd7) ? 3'd0 :
                                                    (rd_byte_idx + 3'd1);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_entry_pop_hold <= 1'b0;
        else if (start)
            rd_entry_pop_hold <= 1'b0;
        else
            rd_entry_pop_hold <= rd_entry_done_fire;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_frame_fcnt <= 4'd0;
        else if (start)
            rd_frame_fcnt <= 4'd0;
        else if (blk_accept_fire)
            rd_frame_fcnt <= meta_blk_fcnt;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (rst_i = 0; rst_i < 16; rst_i = rst_i + 1) begin
                fifo_reserved[rst_i] <= {FIFO_CNT_W{1'b0}};
            end
        end else if (start) begin
            for (rst_i = 0; rst_i < 16; rst_i = rst_i + 1) begin
                fifo_reserved[rst_i] <= {FIFO_CNT_W{1'b0}};
            end
        end else begin
            for (wr_i = 0; wr_i < 16; wr_i = wr_i + 1) begin
                if (ar_fire && active_wr_mask[wr_i])
                    fifo_reserved[wr_i] <= fifo_reserved[wr_i] + FIFO_CNT_W'(1);
                if (blk_push_fire && active_wr_mask[wr_i]) begin
                    fifo_reserved[wr_i] <= fifo_reserved[wr_i] - FIFO_CNT_W'(1);
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            error_cnt <= 32'd0;
        else if (start)
            error_cnt <= 32'd0;
        else if (r_fire && (!r_resp_ok || !r_id_match))
            error_cnt <= error_cnt + 32'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cmd_ok_cnt <= 32'd0;
        else if (start)
            cmd_ok_cnt <= 32'd0;
        else if (blk_push_fire && !r_burst_fail && r_resp_ok && r_id_match)
            cmd_ok_cnt <= cmd_ok_cnt + 32'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cmd_fail_cnt <= 32'd0;
        else if (start)
            cmd_fail_cnt <= 32'd0;
        else if (blk_push_fire && (r_burst_fail || !r_resp_ok || !r_id_match))
            cmd_fail_cnt <= cmd_fail_cnt + 32'd1;
    end

endmodule
