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
//`timescale 1ns/1ps

module ubwc_enc_meta_get_cmd_gen#(
    parameter ADDR_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // --- Control and configuration interface ---
    input  wire                   start,
    input  wire [4:0]             base_format,              // Frame-level format only
    input  wire [ADDR_WIDTH-1:0]  meta_base_addr_rgba_uv,  // Start base address for RGBA or UV
    input  wire [ADDR_WIDTH-1:0]  meta_base_addr_y,        // Start base address for Y plane
    input  wire [15:0]            tile_x_numbers,          // Image tile columns, one metadata byte per tile
    input  wire [15:0]            tile_y_numbers,          // Image tile rows, one metadata byte per tile

    // --- AXI read command interface (to mem_control) ---
    output reg                    cmd_valid,
    input  wire                   cmd_ready,
    output reg  [ADDR_WIDTH-1:0]  cmd_addr,
    output reg  [7:0]             cmd_len,

    // --- Metadata interface (to B FIFO) ---
    output reg                    meta_valid,
    input  wire                   meta_ready,
    output reg  [4:0]             meta_format,
    output reg  [15:0]            meta_xcoord,
    output reg  [15:0]            meta_ycoord
);

    // --- State encoding ---
    localparam S_IDLE        = 4'd0;
    localparam S_INIT_FRAME  = 4'd1;
    localparam S_INIT_PASS   = 4'd2; 
    localparam S_META        = 4'd3;
    localparam S_CMD         = 4'd4;
    localparam S_NEXT_X      = 4'd5; 
    localparam S_NEXT_PASS   = 4'd6; 
    localparam S_NEXT_ROW    = 4'd7; 
    localparam S_DONE        = 4'd8;

    reg [3:0]  state;
    reg [15:0] tile_x_cnt;
    reg [15:0] tile_y_cnt;
    
    // Scan-pass control
    reg [2:0]  pass_cnt;
    reg [2:0]  max_pass;

    // base_format is a frame-level format selector.
    localparam [4:0] BASE_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] BASE_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] BASE_FMT_YUV420_8    = 5'b00010;
    localparam [4:0] BASE_FMT_YUV420_10   = 5'b00011;
    localparam [4:0] BASE_FMT_YUV422_8    = 5'b00100;
    localparam [4:0] BASE_FMT_YUV422_10   = 5'b00101;

    // meta_format is a tile-level format selector and keeps Y/UV split codes.
    localparam [4:0] META_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] META_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] META_FMT_NV12_Y      = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV     = 5'b01001;
    localparam [4:0] META_FMT_NV16_Y      = 5'b01010;
    localparam [4:0] META_FMT_NV16_UV     = 5'b01011;
    localparam [4:0] META_FMT_NV16_10_Y   = 5'b01100;
    localparam [4:0] META_FMT_NV16_10_UV  = 5'b01101;
    localparam [4:0] META_FMT_P010_Y      = 5'b01110;
    localparam [4:0] META_FMT_P010_UV     = 5'b01111;

    wire base_is_rgba    = (base_format == BASE_FMT_RGBA8888) || (base_format == BASE_FMT_RGBA1010102);
    wire base_is_yuv420  = (base_format == BASE_FMT_YUV420_8) || (base_format == BASE_FMT_YUV420_10);
    wire base_is_yuv422  = (base_format == BASE_FMT_YUV422_8) || (base_format == BASE_FMT_YUV422_10);
    wire base_is_rgba101 = (base_format == BASE_FMT_RGBA1010102);
    wire base_is_p010    = (base_format == BASE_FMT_YUV420_10);
    wire base_is_nv16_10 = (base_format == BASE_FMT_YUV422_10);

    // Metadata scan geometry:
    // - tile_x_numbers / tile_y_numbers are real image tile counts
    // - one metadata byte represents one tile
    // - one 64-byte fetch covers one 8x8 metadata block
    // Metadata address mapping follows ubwc_demo.cpp::get_metadata_address():
    //   meta_tile_row         = y_block_idx / 2
    //   meta_tile_col         = x_block_idx / 2
    //   meta_tile_sub_row     = y_block_idx % 2
    //   meta_tile_sub_col     = x_block_idx % 2
    //   addr = meta_tile_row * (16 * meta_pitch_bytes)
    //        + meta_tile_col * 256
    //        + meta_tile_sub_row * 128
    //        + meta_tile_sub_col * 64
    //
    // Here x_block_idx / y_block_idx are 8x8 metadata fetch indices.
    function [ADDR_WIDTH-1:0] meta_cmd_offset;
        input [15:0] x_block_idx;
        input [15:0] y_block_idx;
        input [15:0] meta_pitch_bytes;
        reg [ADDR_WIDTH-1:0] meta_tile_row;
        reg [ADDR_WIDTH-1:0] meta_tile_col;
        reg [ADDR_WIDTH-1:0] offset_val;
        begin
            meta_tile_row = y_block_idx >> 1;
            meta_tile_col = x_block_idx >> 1;
            offset_val =
                ((meta_tile_row * meta_pitch_bytes) << 4) +
                (meta_tile_col << 8) +
                (y_block_idx[0] ? {{(ADDR_WIDTH-8){1'b0}}, 8'd128} : {ADDR_WIDTH{1'b0}}) +
                (x_block_idx[0] ? {{(ADDR_WIDTH-7){1'b0}}, 7'd64}  : {ADDR_WIDTH{1'b0}});
            meta_cmd_offset = offset_val;
        end
    endfunction

    wire [15:0] meta_pitch_bytes = (tile_x_numbers + 16'd63) & 16'hffc0;
    wire [15:0] x_cmd_count      = (tile_x_numbers + 16'd7) >> 3;
    wire [15:0] x_cmd_last       = (x_cmd_count == 16'd0) ? 16'd0 : (x_cmd_count - 16'd1);

    wire [15:0] rgba_group_count = (tile_y_numbers + 16'd15) >> 4;
    wire [16:0] rgba_rows_consumed = ({1'b0, tile_y_cnt} << 4);
    wire [16:0] rgba_rows_remaining =
        ({1'b0, tile_y_numbers} > rgba_rows_consumed) ?
            ({1'b0, tile_y_numbers} - rgba_rows_consumed) : 17'd0;
    wire        rgba_pass0_valid = (rgba_rows_remaining != 17'd0);
    wire        rgba_pass1_valid = (rgba_rows_remaining > 17'd8);

    wire [15:0] yuv420_uv_tile_y_count = (tile_y_numbers + 16'd1) >> 1;
    wire [15:0] yuv420_group_count     = (tile_y_numbers + 16'd15) >> 4;
    wire [16:0] yuv420_y_rows_consumed = ({1'b0, tile_y_cnt} << 4);
    wire [16:0] yuv420_y_rows_remaining =
        ({1'b0, tile_y_numbers} > yuv420_y_rows_consumed) ?
            ({1'b0, tile_y_numbers} - yuv420_y_rows_consumed) : 17'd0;
    wire [16:0] yuv420_uv_rows_consumed = ({1'b0, tile_y_cnt} << 3);
    wire [16:0] yuv420_uv_rows_remaining =
        ({1'b0, yuv420_uv_tile_y_count} > yuv420_uv_rows_consumed) ?
            ({1'b0, yuv420_uv_tile_y_count} - yuv420_uv_rows_consumed) : 17'd0;
    wire        yuv420_pass0_valid = (yuv420_y_rows_remaining != 17'd0);
    wire        yuv420_pass1_valid = (yuv420_y_rows_remaining > 17'd8);
    wire        yuv420_pass2_valid = (yuv420_uv_rows_remaining != 17'd0);

    wire [15:0] yuv422_group_count = (tile_y_numbers + 16'd7) >> 3;
    wire [16:0] yuv422_rows_consumed = ({1'b0, tile_y_cnt} << 3);
    wire [16:0] yuv422_rows_remaining =
        ({1'b0, tile_y_numbers} > yuv422_rows_consumed) ?
            ({1'b0, tile_y_numbers} - yuv422_rows_consumed) : 17'd0;
    wire        yuv422_pass0_valid = (yuv422_rows_remaining != 17'd0);
    wire        yuv422_pass1_valid = (yuv422_rows_remaining != 17'd0);

    wire [15:0] frame_group_count =
        base_is_rgba   ? rgba_group_count   :
        base_is_yuv420 ? yuv420_group_count :
                         yuv422_group_count;
    wire [15:0] frame_group_last = (frame_group_count == 16'd0) ? 16'd0 : (frame_group_count - 16'd1);
    wire        frame_empty      = (x_cmd_count == 16'd0) || (frame_group_count == 16'd0);

    wire        curr_pass_valid =
        base_is_rgba   ? ((pass_cnt == 3'd0) ? rgba_pass0_valid :
                          (pass_cnt == 3'd1) ? rgba_pass1_valid : 1'b0) :
        base_is_yuv420 ? ((pass_cnt == 3'd0) ? yuv420_pass0_valid :
                          (pass_cnt == 3'd1) ? yuv420_pass1_valid :
                          (pass_cnt == 3'd2) ? yuv420_pass2_valid : 1'b0) :
                         ((pass_cnt == 3'd0) ? yuv422_pass0_valid :
                          (pass_cnt == 3'd1) ? yuv422_pass1_valid : 1'b0);

    wire [15:0] rgba_y_block_idx   = (tile_y_cnt << 1) + {15'd0, pass_cnt[0]};
    wire [15:0] yuv420_y_block_idx = (tile_y_cnt << 1) + {15'd0, pass_cnt[0]};
    wire [15:0] yuv420_uv_block_idx = tile_y_cnt;
    wire [15:0] yuv422_block_idx   = tile_y_cnt;

    wire [ADDR_WIDTH-1:0] rgba_cmd_addr =
        meta_base_addr_rgba_uv + meta_cmd_offset(tile_x_cnt, rgba_y_block_idx, meta_pitch_bytes);
    wire [ADDR_WIDTH-1:0] yuv420_y_cmd_addr =
        meta_base_addr_y + meta_cmd_offset(tile_x_cnt, yuv420_y_block_idx, meta_pitch_bytes);
    wire [ADDR_WIDTH-1:0] yuv420_uv_cmd_addr =
        meta_base_addr_rgba_uv + meta_cmd_offset(tile_x_cnt, yuv420_uv_block_idx, meta_pitch_bytes);
    wire [ADDR_WIDTH-1:0] yuv422_y_cmd_addr =
        meta_base_addr_y + meta_cmd_offset(tile_x_cnt, yuv422_block_idx, meta_pitch_bytes);
    wire [ADDR_WIDTH-1:0] yuv422_uv_cmd_addr =
        meta_base_addr_rgba_uv + meta_cmd_offset(tile_x_cnt, yuv422_block_idx, meta_pitch_bytes);

    wire [ADDR_WIDTH-1:0] current_cmd_addr =
        base_is_rgba   ? rgba_cmd_addr :
        base_is_yuv420 ? ((pass_cnt == 3'd2) ? yuv420_uv_cmd_addr : yuv420_y_cmd_addr) :
                         ((pass_cnt == 3'd1) ? yuv422_uv_cmd_addr : yuv422_y_cmd_addr);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= S_IDLE;
            cmd_valid        <= 1'b0;
            cmd_addr         <= {ADDR_WIDTH{1'b0}};
            cmd_len          <= 8'd0;
            meta_valid       <= 1'b0;
            meta_format      <= META_FMT_RGBA8888;
            meta_xcoord      <= 16'd0;
            meta_ycoord      <= 16'd0;
            tile_x_cnt       <= 16'd0;
            tile_y_cnt       <= 16'd0;
            pass_cnt         <= 3'd0;
            max_pass         <= 3'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    cmd_valid  <= 1'b0;
                    meta_valid <= 1'b0;
                    if (start) state <= S_INIT_FRAME;
                end

                S_INIT_FRAME: begin
                    tile_y_cnt <= 16'd0;
                    pass_cnt   <= 3'd0;

                    if (base_is_yuv420)      max_pass <= 3'd2;
                    else                      max_pass <= 3'd1;

                    if (frame_empty) state <= S_DONE;
                    else             state <= S_INIT_PASS;
                end

                S_INIT_PASS: begin
                    tile_x_cnt <= 16'd0;
                    if (!curr_pass_valid) begin
                        if (pass_cnt == max_pass) begin
                            state <= S_NEXT_ROW;
                        end else begin
                            pass_cnt <= pass_cnt + 1'b1;
                            state    <= S_INIT_PASS;
                        end
                    end else begin
                        state <= S_META;
                    end
                end

                // ========================================================
                // Coordinate mapping logic
                // ========================================================
                S_META: begin
                    meta_valid  <= 1'b1;
                    meta_xcoord <= tile_x_cnt;

                    if (base_is_yuv420) begin
                        if (pass_cnt == 0) begin
                            meta_format <= base_is_p010 ? META_FMT_P010_Y : META_FMT_NV12_Y;
                            meta_ycoord <= (tile_y_cnt << 1);
                        end else if (pass_cnt == 1) begin
                            meta_format <= base_is_p010 ? META_FMT_P010_Y : META_FMT_NV12_Y;
                            meta_ycoord <= (tile_y_cnt << 1) + 1;
                        end else begin
                            meta_format <= base_is_p010 ? META_FMT_P010_UV : META_FMT_NV12_UV;
                            meta_ycoord <= tile_y_cnt;
                        end
                    end 
                    else if (base_is_yuv422) begin
                        if (pass_cnt == 0) begin
                            meta_format <= base_is_nv16_10 ? META_FMT_NV16_10_Y : META_FMT_NV16_Y;
                            meta_ycoord <= tile_y_cnt;
                        end else begin
                            meta_format <= base_is_nv16_10 ? META_FMT_NV16_10_UV : META_FMT_NV16_UV;
                            meta_ycoord <= tile_y_cnt;
                        end
                    end
                    else begin
                        meta_format <= base_is_rgba101 ? META_FMT_RGBA1010102 : META_FMT_RGBA8888;
                        meta_ycoord <= (pass_cnt == 0) ? (tile_y_cnt << 1) : ((tile_y_cnt << 1) + 1);
                    end
                    
                    if (meta_ready) state <= S_CMD;
                end

                S_CMD: begin
                    meta_valid <= 1'b0;
                    cmd_valid  <= 1'b1;
                    cmd_addr   <= current_cmd_addr;
                    cmd_len    <= 8'd64;
                    if (cmd_ready && cmd_valid) begin
                        cmd_valid <= 1'b0;
                        state     <= S_NEXT_X;
                    end
                end

                S_NEXT_X: begin
                    if (tile_x_cnt == x_cmd_last) begin
                        state <= S_NEXT_PASS;
                    end else begin
                        tile_x_cnt <= tile_x_cnt + 16'd1;
                        state      <= S_META;
                    end
                end

                S_NEXT_PASS: begin
                    if (pass_cnt == max_pass) begin
                        state <= S_NEXT_ROW;
                    end else begin
                        pass_cnt <= pass_cnt + 1;
                        state    <= S_INIT_PASS;
                    end
                end

                S_NEXT_ROW: begin
                    if (tile_y_cnt == frame_group_last) begin
                        state <= S_DONE;
                    end else begin
                        tile_y_cnt <= tile_y_cnt + 1'b1;
                        pass_cnt   <= 3'd0;
                        state      <= S_INIT_PASS;
                    end
                end

                S_DONE: begin
                    state <= S_IDLE; 
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
