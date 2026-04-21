//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-04-01  23:16:49
// Design Name       : 
// Module Name       : ubwc_dec_tile_to_line_sram_fetcher.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module sram_read_fetcher (
    input  wire           clk_sram,
    input  wire           rst_n,
    input  wire           i_frame_start,
    input  wire [15:0]    cfg_img_width,
    input  wire [4:0]     cfg_format,
    input  wire           i_buffer_vld,
    input  wire           i_writer_bank,
    
    output wire           o_sram_a_ren,
    output wire [12:0]    o_sram_a_raddr,
    input  wire [127:0]   i_sram_a_rdata,
    output wire           o_sram_b_ren,
    output wire [12:0]    o_sram_b_raddr,
    input  wire [127:0]   i_sram_b_rdata,

    output reg            o_fifo_wr_en,
    output reg  [255:0]   o_fifo_wdata,
    input  wire           i_fifo_full,
    
    output reg            o_fetcher_done,
    output reg            o_fetcher_bank
);

    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_ISSUE_Y    = 3'd1;
    localparam [2:0] ST_CAP_Y_UV   = 3'd2;
    localparam [2:0] ST_CAP_Y_ONLY = 3'd3;
    localparam [2:0] ST_CAP_UV     = 3'd4;
    localparam [2:0] ST_PUSH       = 3'd5;
    localparam [2:0] ST_CAP_RGBA1  = 3'd6;

    reg [4:0] tot_lines; reg has_uv, is_yuv420, is_y_stride_1k, is_p010;
    always @(*) begin
        case (cfg_format)
            5'b00000, 5'b00001: begin
                tot_lines=5'd4;  has_uv=1'b0; is_yuv420=1'b0; is_y_stride_1k=1'b1; is_p010=1'b0;
            end
            5'b00010,
            5'b01000, 5'b01001: begin
                tot_lines=5'd16; has_uv=1'b1; is_yuv420=1'b1; is_y_stride_1k=1'b0; is_p010=1'b0;
            end
            5'b00011,
            5'b01110, 5'b01111: begin
                tot_lines=5'd8;  has_uv=1'b1; is_yuv420=1'b1; is_y_stride_1k=1'b0; is_p010=1'b1;
            end
            5'b00100, 5'b00101,
            5'b01010, 5'b01011, 5'b01100, 5'b01101: begin
                tot_lines=5'd8;  has_uv=1'b1; is_yuv420=1'b0; is_y_stride_1k=1'b0; is_p010=1'b0;
            end
            default:  begin
                tot_lines=5'd4;  has_uv=1'b0; is_yuv420=1'b0; is_y_stride_1k=1'b1; is_p010=1'b0;
            end
        endcase
    end

    wire is_rgba = !has_uv;
    wire [16:0] w_limit_rgba_full = ({1'b0, cfg_img_width} + 17'd3) >> 2;
    wire [16:0] w_limit_yuv_full  = ({1'b0, cfg_img_width} + 17'd15) >> 4;
    wire [16:0] w_limit_p010_full = ({1'b0, cfg_img_width} + 17'd7) >> 3;
    wire [12:0] w_limit_rgba = w_limit_rgba_full[12:0];
    wire [12:0] w_limit_yuv  = w_limit_yuv_full[12:0];
    wire [12:0] w_limit_p010 = w_limit_p010_full[12:0];
    wire [12:0] w_limit = is_rgba ? w_limit_rgba : (is_p010 ? w_limit_p010 : w_limit_yuv);
    reg [4:0] line_idx; reg [12:0] word_idx; reg target_bank;

    wire [2:0]  y_line_in_group = is_p010 ? {1'b0, line_idx[1:0]} : line_idx[2:0];
    wire [12:0] y_group_off = is_p010 ? (line_idx[2] ? 13'd2048 : 13'd0)
                                      : (line_idx[3] ? 13'd2048 : 13'd0);
    wire [12:0] y_off = is_y_stride_1k ? {y_line_in_group, 10'd0}
                                       : (is_p010 ? {1'b0, y_line_in_group, 9'd0}
                                                  : {2'd0, y_line_in_group, 8'd0});
    wire [12:0] addr_y = y_group_off + y_off + word_idx;
    wire [12:0] addr_y_p1 = addr_y + 13'd1;
    wire [2:0]  uv_l  = is_yuv420 ? (is_p010 ? {1'b0, line_idx[2:1]} : line_idx[3:1]) : line_idx[2:0];
    wire [12:0] uv_row_off = is_p010 ? {1'b0, uv_l[2:0], 9'd0} : {2'd0, uv_l[2:0], 8'd0};
    wire [12:0] addr_uv= 13'd4096 + uv_row_off + word_idx;
    // For YUV420, odd/even luma lines share the same UV row. Re-reading the same
    // UV row on the odd line keeps word_idx aligned without requiring a UV line buffer.
    wire need_uv = has_uv;

    reg [2:0] state; reg [127:0] reg_y, reg_uv;
    reg rgba_pair_pending;
    wire frame_start = (i_frame_start == 1'b1);
    wire s_ren = (state == ST_ISSUE_Y) || (state == ST_CAP_Y_UV) || (is_rgba && (state == ST_CAP_Y_ONLY));
    wire [12:0] s_addr =
        (state == ST_CAP_Y_UV) ? addr_uv :
        ((is_rgba && (state == ST_CAP_Y_ONLY)) ? addr_y_p1 : addr_y);

    assign o_sram_a_ren = s_ren && (target_bank == 0);
    assign o_sram_b_ren = s_ren && (target_bank == 1);
    assign o_sram_a_raddr = s_addr; assign o_sram_b_raddr = s_addr;
    wire [127:0] s_rdata = (target_bank == 0) ? i_sram_a_rdata : i_sram_b_rdata;

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE; target_bank <= 0; line_idx <= 0; word_idx <= 0;
            reg_y <= 0; reg_uv <= 0;
            rgba_pair_pending <= 1'b0;
            o_fifo_wr_en <= 0; o_fetcher_done <= 0; o_fetcher_bank <= 0;
        end else if (frame_start) begin
            state <= ST_IDLE; target_bank <= 0; line_idx <= 0; word_idx <= 0;
            reg_y <= 0; reg_uv <= 0;
            rgba_pair_pending <= 1'b0;
            o_fifo_wr_en <= 0; o_fetcher_done <= 0; o_fetcher_bank <= 0;
        end else begin
            o_fifo_wr_en <= 0; o_fetcher_done <= 0;
            case (state)
                ST_IDLE: begin
                    if (i_buffer_vld && (w_limit != 0)) begin
                        target_bank <= i_writer_bank;
                        line_idx <= 0;
                        word_idx <= 0;
                        rgba_pair_pending <= 1'b0;
                        state <= ST_ISSUE_Y;
                    end
                end
                ST_ISSUE_Y: begin
                    if (!i_fifo_full) state <= need_uv ? ST_CAP_Y_UV : ST_CAP_Y_ONLY;
                end
                ST_CAP_Y_UV: begin
                    reg_y <= s_rdata;
                    state <= ST_CAP_UV;
                end
                ST_CAP_Y_ONLY: begin
                    reg_y <= s_rdata;
                    if (is_rgba) begin
                        if (word_idx == w_limit - 1'b1) begin
                            reg_uv <= 128'd0;
                            rgba_pair_pending <= 1'b0;
                            state <= ST_PUSH;
                        end else begin
                            rgba_pair_pending <= 1'b1;
                            state <= ST_CAP_RGBA1;
                        end
                    end else begin
                        reg_uv <= 128'd0;
                        state <= ST_PUSH;
                    end
                end
                ST_CAP_UV: begin
                    reg_uv <= s_rdata;
                    state <= ST_PUSH;
                end
                ST_CAP_RGBA1: begin
                    if (!i_fifo_full) begin
                        o_fifo_wr_en <= 1'b1;
                        o_fifo_wdata <= {s_rdata, reg_y};
                        rgba_pair_pending <= 1'b0;
                        if (word_idx + 13'd2 >= w_limit) begin
                            word_idx <= 0;
                            if (line_idx == tot_lines - 1) begin
                                o_fetcher_done <= 1'b1;
                                o_fetcher_bank <= target_bank;
                                state <= ST_IDLE;
                            end else begin
                                line_idx <= line_idx + 1'b1;
                                state <= ST_ISSUE_Y;
                            end
                        end else begin
                            word_idx <= word_idx + 13'd2;
                            state <= ST_ISSUE_Y;
                        end
                    end else begin
                        reg_uv <= s_rdata;
                        state <= ST_PUSH;
                    end
                end
                ST_PUSH: begin
                    if (!i_fifo_full) begin
                        o_fifo_wr_en <= 1;
                        o_fifo_wdata <= {reg_uv, reg_y};
                        if (word_idx + ((is_rgba && rgba_pair_pending) ? 13'd2 : 13'd1) >= w_limit) begin
                            word_idx <= 0;
                            rgba_pair_pending <= 1'b0;
                            if (line_idx == tot_lines - 1) begin
                                o_fetcher_done <= 1'b1;
                                o_fetcher_bank <= target_bank;
                                state <= ST_IDLE;
                            end else begin
                                line_idx <= line_idx + 1'b1;
                                state <= ST_ISSUE_Y;
                            end
                        end else begin
                            word_idx <= word_idx + ((is_rgba && rgba_pair_pending) ? 13'd2 : 13'd1);
                            rgba_pair_pending <= 1'b0;
                            state <= ST_ISSUE_Y;
                        end
                    end
                end
                default: begin
                    state <= ST_IDLE;
                    line_idx <= 0;
                    word_idx <= 0;
                    rgba_pair_pending <= 1'b0;
                end
            endcase
        end
    end
endmodule
