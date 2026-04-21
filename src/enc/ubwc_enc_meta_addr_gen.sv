//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : OpenAI Codex
// Create Date       : 2026-04-17
// Module Name       : ubwc_enc_meta_addr_gen
// Description       :
//   Single-instance metadata generator.
//
//   The module accepts per-tile compression results and generates addressed
//   64-bit metadata words directly:
//     1. Every 8 tiles in the same tile row are packed into one 64-bit word.
//     2. If a tile row ends before 8 tiles are collected, the remaining bytes
//        in that word are padded with 0.
//     3. If a tile row ends before 16-tile alignment, one extra zero
//        64-bit word is emitted to complete the row.
//     4. When a plane ends, the metadata surface is extended with zero rows
//        until the metadata height is 32 tile rows aligned.
//
//   Y and UV are handled inside one instance according to i_format/i_xcoord/
//   i_ycoord. Output words carry independent addresses and are intended to feed
//   ubwc_enc_meta_axi_wcmd_gen_v2.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_enc_meta_addr_gen #(
    parameter   SB_WIDTH        = 1,
    parameter   META_AW         = 64,
    parameter   SRAM_AW         = 13,
    parameter   IN_FIFO_DEPTH   = 16,
    parameter   OUT_FIFO_DEPTH  = 64,
    parameter   PROCESS_UV      = 0
)(
    input   wire                        i_clk,
    input   wire                        i_rstn,

    input   wire    [32         -1:0]   i_meta_data_plane_pitch,
    input   wire    [SRAM_AW-5  -1:0]   i_total_x_units,
    input   wire    [28         -1:0]   i_pic_width_tiles,
    input   wire    [13         -1:0]   i_pic_height_tiles,
    input   wire    [28         -1:0]   i_active_pic_width_tiles,
    input   wire    [13         -1:0]   i_active_pic_height_tiles,

    input   wire    [64         -1:0]   i_meta_y_base_offset_addr,
    input   wire    [64         -1:0]   i_meta_uv_base_offset_addr,
    input   wire                        i_force_flush,

    input   wire                        i_co_valid,
    input   wire    [3          -1:0]   i_co_alen,
    input   wire    [SB_WIDTH   -1:0]   i_co_sb,
    input   wire                        i_co_pcm,
    input   wire    [5          -1:0]   i_format,
    input   wire    [13         -1:0]   i_ycoord,
    input   wire    [28         -1:0]   i_xcoord,

    output  logic                       o_meta_valid,
    input   logic                       i_meta_ready,
    output  logic                       o_meta_last,
    output  logic   [64         -1:0]   o_meta_data,
    output  logic   [META_AW    -1:0]   o_meta_addr,
    output  logic                       o_frame_done
);

    localparam [4:0] FMT_NV12_UV    = 5'd9;
    localparam [4:0] FMT_NV16_UV    = 5'd11;
    localparam [4:0] FMT_NV16_10_UV = 5'd13;
    localparam [4:0] FMT_P010_UV    = 5'd15;

    localparam integer IN_DATA_W  = 3 + SB_WIDTH + 1 + 5 + 13 + 28;
    localparam integer OUT_DATA_W = 1 + 64 + META_AW;

    wire [IN_DATA_W-1:0] in_fifo_push_data;
    wire                 in_fifo_push_ready;
    wire                 in_fifo_pop_valid;
    wire                 in_fifo_pop_ready;
    wire [IN_DATA_W-1:0] in_fifo_pop_data;

    wire [2:0]           int_co_alen;
    wire [SB_WIDTH-1:0]  int_co_sb;
    wire                 int_co_pcm;
    wire [4:0]           int_format;
    wire [12:0]          int_ycoord;
    wire [27:0]          int_xcoord;

    logic [63:0]         pack_reg [0:1];
    logic                row_extra_pending_r;
    logic [META_AW-1:0]  row_extra_addr_r;

    logic                frame_pad_active_r;
    logic                frame_pad_is_uv_r;
    logic                frame_pad_fill_nonzero_r;
    logic [12:0]         frame_pad_tile_y_r;
    logic [27:0]         frame_pad_width_tiles_r;
    logic [31:0]         frame_pad_row_words_r;
    logic [31:0]         frame_pad_word_idx_r;
    logic [31:0]         frame_pad_words_left_r;
    logic [63:0]         frame_pad_fill_word_r;

    logic                frame_done_pending_r;

    wire                 out_fifo_push_ready;
    logic                out_fifo_push_valid;
    logic [OUT_DATA_W-1:0] out_fifo_push_data;
    logic                out_fifo_push_is_tile;
    logic                out_fifo_push_is_row_extra;
    logic                out_fifo_push_is_frame_pad;
    wire [OUT_DATA_W-1:0] out_fifo_pop_data;

    wire                 tile_is_uv_w;
    wire                 tile_is_y_w;
    wire                 tile_plane_w;
    wire [28:0]          tile_width_tiles_w;
    wire [12:0]          tile_height_tiles_w;
    wire [28:0]          tile_active_width_tiles_w;
    wire [12:0]          tile_active_height_tiles_w;
    wire                 tile_inside_active_w;
    wire                 tile_end_of_line_w;
    wire                 tile_last_of_plane_w;
    wire [63:0]          tile_meta_word_w;
    wire [7:0]           tile_meta_byte_w;
    wire [7:0]           tile_meta_fill_byte_w;
    wire                 tile_emit_word_w;
    wire                 tile_need_row_extra_w;
    wire [META_AW-1:0]   tile_word_addr_w;
    wire [META_AW-1:0]   tile_row_extra_addr_w;
    wire [12:0]          tile_missing_rows_w;
    wire [31:0]          tile_frame_pad_words_w;
    wire [31:0]          tile_row_words_w;
    wire                 tile_pop_fire_w;

    wire [OUT_DATA_W-1:0] out_fifo_push_data_tile_w;
    wire [OUT_DATA_W-1:0] out_fifo_push_data_pad_w;

    wire unused_pitch_bits  = ^i_meta_data_plane_pitch;
    wire unused_force_flush = i_force_flush;
    wire unused_process_uv  = PROCESS_UV;
    wire unused_sb_bits     = ^int_co_sb;
    wire unused_pcm_bit     = int_co_pcm;
    wire unused_total_x_units = ^i_total_x_units;
    wire unused_active_w_tiles = ^i_active_pic_width_tiles;
    wire unused_active_h_tiles = ^i_active_pic_height_tiles;

    function automatic logic is_uv_format;
        input [4:0] fmt;
        begin
            case (fmt)
                FMT_NV12_UV,
                FMT_NV16_UV,
                FMT_NV16_10_UV,
                FMT_P010_UV: is_uv_format = 1'b1;
                default:     is_uv_format = 1'b0;
            endcase
        end
    endfunction

    function automatic [12:0] calc_surface_height_tiles;
        input [12:0] plane_y_tiles;
        input [4:0]  fmt;
        begin
            if (is_uv_format(fmt))
                calc_surface_height_tiles = (plane_y_tiles + 13'd1) >> 1;
            else
                calc_surface_height_tiles = plane_y_tiles;
        end
    endfunction

    function automatic [27:0] calc_total_x_units;
        input [27:0] width_tiles;
        begin
            calc_total_x_units = (width_tiles + 28'd15) >> 4;
        end
    endfunction

    function automatic [31:0] calc_row_words;
        input [27:0] width_tiles;
        reg [27:0] total_x_units_local;
        begin
            total_x_units_local = calc_total_x_units(width_tiles);
            calc_row_words = {4'd0, total_x_units_local, 1'b0};
        end
    endfunction

    function automatic [12:0] align_up_32;
        input [12:0] value;
        begin
            if (value[4:0] == 5'd0)
                align_up_32 = value;
            else
                align_up_32 = {value[12:5] + 8'd1, 5'd0};
        end
    endfunction

    function automatic [7:0] build_meta_byte;
        input [2:0] alen;
        begin
            build_meta_byte = {4'h1, alen, 1'b0};
        end
    endfunction

    function automatic [META_AW-1:0] calc_word_addr;
        input [META_AW-1:0] base_addr;
        input [27:0]        width_tiles;
        input [12:0]        tile_y;
        input [27:0]        tile_x;
        reg   [27:0]        total_x_units_local;
        reg   [META_AW-1:0] block_pitch_bytes_local;
        reg   [27:0]        x_unit_local;
        reg                 x_half_local;
        reg   [12:0]        y_block_local;
        reg                 y_half_local;
        reg   [2:0]         y_sub_local;
        reg   [META_AW-1:0] row_offset_local;
        reg   [META_AW-1:0] x_unit_offset_local;
        reg   [META_AW-1:0] y_half_offset_local;
        reg   [META_AW-1:0] word_offset_local;
        begin
            total_x_units_local   = calc_total_x_units(width_tiles);
            block_pitch_bytes_local = {{(META_AW-32){1'b0}}, total_x_units_local, 8'd0};
            x_unit_local          = tile_x[27:4];
            x_half_local          = tile_x[3];
            y_block_local         = tile_y[12:4];
            y_half_local          = tile_y[3];
            y_sub_local           = tile_y[2:0];
            row_offset_local      = {{(META_AW-13){1'b0}}, y_block_local} * block_pitch_bytes_local;
            x_unit_offset_local   = {{(META_AW-28){1'b0}}, x_unit_local, 8'd0};
            y_half_offset_local   = {{(META_AW-1){1'b0}}, y_half_local, 7'd0};
            word_offset_local     = {{(META_AW-7){1'b0}}, x_half_local, y_sub_local, 3'd0};
            calc_word_addr        = base_addr + row_offset_local + x_unit_offset_local +
                                    y_half_offset_local + word_offset_local;
        end
    endfunction

    assign in_fifo_push_data = {i_co_alen, i_co_sb, i_co_pcm, i_format, i_ycoord, i_xcoord};

    ubwc_sync_fifo_fwft #(
        .DATA_WIDTH (IN_DATA_W),
        .DEPTH      (IN_FIFO_DEPTH)
    ) u_in_fifo (
        .clk          (i_clk),
        .rstn         (i_rstn),
        .i_push_valid (i_co_valid),
        .o_push_ready (in_fifo_push_ready),
        .i_push_data  (in_fifo_push_data),
        .o_pop_valid  (in_fifo_pop_valid),
        .i_pop_ready  (in_fifo_pop_ready),
        .o_pop_data   (in_fifo_pop_data)
    );

    assign {int_co_alen, int_co_sb, int_co_pcm, int_format, int_ycoord, int_xcoord} = in_fifo_pop_data;

    assign tile_is_uv_w        = is_uv_format(int_format);
    assign tile_is_y_w         = ~tile_is_uv_w;
    assign tile_plane_w        = tile_is_uv_w;
    assign tile_width_tiles_w  = {1'b0, i_pic_width_tiles};
    assign tile_height_tiles_w = calc_surface_height_tiles(i_pic_height_tiles, int_format);
    assign tile_active_width_tiles_w  = {1'b0, i_active_pic_width_tiles};
    assign tile_active_height_tiles_w = calc_surface_height_tiles(i_active_pic_height_tiles, int_format);
    assign tile_inside_active_w =
        (int_xcoord < tile_active_width_tiles_w[27:0]) &&
        (int_ycoord < tile_active_height_tiles_w);
    assign tile_end_of_line_w  = in_fifo_pop_valid && (int_xcoord == (tile_width_tiles_w[27:0] - 28'd1));
    assign tile_last_of_plane_w= tile_end_of_line_w && (int_ycoord == (tile_height_tiles_w - 13'd1));
    assign tile_meta_fill_byte_w = build_meta_byte(int_co_alen);
    assign tile_meta_byte_w    = tile_inside_active_w ? tile_meta_fill_byte_w : 8'd0;
    assign tile_emit_word_w    = in_fifo_pop_valid && ((int_xcoord[2:0] == 3'd7) || tile_end_of_line_w);
    assign tile_need_row_extra_w = tile_end_of_line_w && (int_xcoord[3] == 1'b0);
    assign tile_word_addr_w    = tile_is_uv_w ?
                                 calc_word_addr(i_meta_uv_base_offset_addr[META_AW-1:0],
                                                tile_width_tiles_w[27:0],
                                                int_ycoord,
                                                int_xcoord) :
                                 calc_word_addr(i_meta_y_base_offset_addr[META_AW-1:0],
                                                tile_width_tiles_w[27:0],
                                                int_ycoord,
                                                int_xcoord);
    assign tile_row_extra_addr_w = tile_word_addr_w + {{(META_AW-7){1'b0}}, 7'd64};
    assign tile_missing_rows_w   = tile_last_of_plane_w ? (align_up_32(tile_height_tiles_w) - tile_height_tiles_w) : 13'd0;
    assign tile_row_words_w      = calc_row_words(tile_width_tiles_w[27:0]);
    assign tile_frame_pad_words_w = {19'd0, tile_missing_rows_w} * tile_row_words_w;

    assign tile_meta_word_w =
        tile_plane_w ?
        (pack_reg[1] | ({56'd0, tile_meta_byte_w} << (int_xcoord[2:0] * 8))) :
        (pack_reg[0] | ({56'd0, tile_meta_byte_w} << (int_xcoord[2:0] * 8)));

    assign out_fifo_push_data_tile_w = {1'b1, tile_meta_word_w, tile_word_addr_w};
    assign out_fifo_push_data_pad_w =
        {1'b1,
         row_extra_pending_r ? 64'd0 :
         (frame_pad_fill_nonzero_r ? frame_pad_fill_word_r : 64'd0),
         row_extra_pending_r ? row_extra_addr_r :
         (frame_pad_is_uv_r ?
          calc_word_addr(i_meta_uv_base_offset_addr[META_AW-1:0],
                         frame_pad_width_tiles_r,
                         frame_pad_tile_y_r,
                         {frame_pad_word_idx_r[24:0], 3'b111}) :
          calc_word_addr(i_meta_y_base_offset_addr[META_AW-1:0],
                         frame_pad_width_tiles_r,
                         frame_pad_tile_y_r,
                         {frame_pad_word_idx_r[24:0], 3'b111}))};

    // Flush synthetic row/frame padding words before consuming more tiles, so
    // Y-plane tail padding cannot be truncated by the next plane's traffic.
    assign in_fifo_pop_ready =
        in_fifo_pop_valid &&
        !row_extra_pending_r &&
        !frame_pad_active_r &&
        (!tile_emit_word_w || out_fifo_push_ready);

    assign tile_pop_fire_w = in_fifo_pop_valid && in_fifo_pop_ready;

    always @(*) begin
        out_fifo_push_valid = 1'b0;
        out_fifo_push_data  = {OUT_DATA_W{1'b0}};
        out_fifo_push_is_tile = 1'b0;
        out_fifo_push_is_row_extra = 1'b0;
        out_fifo_push_is_frame_pad = 1'b0;

        if (tile_pop_fire_w && tile_emit_word_w) begin
            out_fifo_push_valid = 1'b1;
            out_fifo_push_data  = out_fifo_push_data_tile_w;
            out_fifo_push_is_tile = 1'b1;
        end else if (row_extra_pending_r) begin
            out_fifo_push_valid = 1'b1;
            out_fifo_push_data  = out_fifo_push_data_pad_w;
            out_fifo_push_is_row_extra = 1'b1;
        end else if (frame_pad_active_r) begin
            out_fifo_push_valid = 1'b1;
            out_fifo_push_data  = out_fifo_push_data_pad_w;
            out_fifo_push_is_frame_pad = 1'b1;
        end
    end

    ubwc_sync_fifo_fwft #(
        .DATA_WIDTH (OUT_DATA_W),
        .DEPTH      (OUT_FIFO_DEPTH)
    ) u_out_fifo (
        .clk          (i_clk),
        .rstn         (i_rstn),
        .i_push_valid (out_fifo_push_valid),
        .o_push_ready (out_fifo_push_ready),
        .i_push_data  (out_fifo_push_data),
        .o_pop_valid  (o_meta_valid),
        .i_pop_ready  (i_meta_ready),
        .o_pop_data   (out_fifo_pop_data)
    );

    assign {o_meta_last, o_meta_data, o_meta_addr} = out_fifo_pop_data;

    always_ff @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            pack_reg[0]          <= 64'd0;
            pack_reg[1]          <= 64'd0;
            row_extra_pending_r  <= 1'b0;
            row_extra_addr_r     <= {META_AW{1'b0}};
            frame_pad_active_r   <= 1'b0;
            frame_pad_is_uv_r    <= 1'b0;
            frame_pad_fill_nonzero_r <= 1'b0;
            frame_pad_tile_y_r   <= 13'd0;
            frame_pad_width_tiles_r <= 28'd0;
            frame_pad_row_words_r<= 32'd0;
            frame_pad_word_idx_r <= 32'd0;
            frame_pad_words_left_r <= 32'd0;
            frame_pad_fill_word_r <= 64'd0;
            frame_done_pending_r <= 1'b0;
            o_frame_done         <= 1'b0;
        end else begin
            o_frame_done <= 1'b0;

            if (tile_pop_fire_w) begin
                if (tile_plane_w) begin
                    if (tile_emit_word_w)
                        pack_reg[1] <= 64'd0;
                    else
                        pack_reg[1] <= tile_meta_word_w;
                end else begin
                    if (tile_emit_word_w)
                        pack_reg[0] <= 64'd0;
                    else
                        pack_reg[0] <= tile_meta_word_w;
                end

                if (tile_need_row_extra_w) begin
                    row_extra_pending_r <= 1'b1;
                    row_extra_addr_r    <= tile_row_extra_addr_w;
                end

                if (tile_last_of_plane_w && (tile_frame_pad_words_w != 32'd0)) begin
                    frame_pad_active_r    <= 1'b1;
                    frame_pad_is_uv_r     <= tile_is_uv_w;
                    frame_pad_fill_nonzero_r <= (tile_is_y_w && int_ycoord[3]);
                    frame_pad_tile_y_r    <= tile_height_tiles_w;
                    frame_pad_width_tiles_r <= tile_width_tiles_w[27:0];
                    frame_pad_row_words_r <= tile_row_words_w;
                    frame_pad_word_idx_r  <= 32'd0;
                    frame_pad_words_left_r<= tile_frame_pad_words_w;
                    frame_pad_fill_word_r <= {8{tile_meta_fill_byte_w}};
                    frame_done_pending_r  <= 1'b1;
                end else if (tile_last_of_plane_w && !tile_need_row_extra_w) begin
                    o_frame_done <= tile_emit_word_w;
                end else if (tile_last_of_plane_w) begin
                    frame_done_pending_r <= 1'b1;
                end
            end

            if (out_fifo_push_valid && out_fifo_push_ready) begin
                if (out_fifo_push_is_row_extra) begin
                    row_extra_pending_r <= 1'b0;
                    if (frame_done_pending_r && !frame_pad_active_r) begin
                        frame_done_pending_r <= 1'b0;
                        o_frame_done         <= 1'b1;
                    end
                end else if (out_fifo_push_is_frame_pad) begin
                    if (frame_pad_words_left_r == 32'd1) begin
                        frame_pad_active_r    <= 1'b0;
                        frame_pad_fill_nonzero_r <= 1'b0;
                        frame_pad_words_left_r<= 32'd0;
                        frame_pad_word_idx_r  <= 32'd0;
                        frame_done_pending_r  <= 1'b0;
                        o_frame_done          <= 1'b1;
                    end else begin
                        frame_pad_words_left_r <= frame_pad_words_left_r - 32'd1;
                        if (frame_pad_word_idx_r == (frame_pad_row_words_r - 32'd1)) begin
                            frame_pad_word_idx_r <= 32'd0;
                            frame_pad_tile_y_r   <= frame_pad_tile_y_r + 13'd1;
                        end else begin
                            frame_pad_word_idx_r <= frame_pad_word_idx_r + 32'd1;
                        end
                    end
                end
            end
        end
    end

endmodule
