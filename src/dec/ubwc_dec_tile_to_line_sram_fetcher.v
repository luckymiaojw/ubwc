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

module sram_read_fetcher #(
    parameter integer SRAM_ADDR_W = 12
)(
    input  wire           clk_sram,
    input  wire           rst_n,
    input  wire           i_frame_start,
    input  wire [15:0]    cfg_img_width,
    input  wire [4:0]     cfg_format,
    input  wire           i_buffer_vld,
    input  wire           i_writer_bank,
    input  wire [3:0]     i_buffer_fcnt,
    
    output wire           o_sram_a_ren,
    output wire [SRAM_ADDR_W-1:0] o_sram_a_raddr,
    input  wire [127:0]   i_sram_a_rdata,
    output wire           o_sram_b_ren,
    output wire [SRAM_ADDR_W-1:0] o_sram_b_raddr,
    input  wire [127:0]   i_sram_b_rdata,

    output reg            o_fifo_wr_en,
    output reg  [255:0]   o_fifo_wdata,
    output reg  [3:0]     o_fifo_fcnt,
    input  wire           i_fifo_full,
    
    output reg            o_fetcher_done,
    output reg            o_fetcher_bank,
    output reg  [3:0]     o_fetcher_fcnt
);

    localparam [1:0] ST_IDLE         = 2'd0;
    localparam [1:0] ST_ISSUE_FIRST  = 2'd1;
    localparam [1:0] ST_ISSUE_SECOND = 2'd2;
    localparam [1:0] ST_PUSH         = 2'd3;
    localparam integer SRAM_RGBA_ROW_SHIFT       = (SRAM_ADDR_W <= 12) ? 9 : 10;
    localparam integer SRAM_YUV8_ROW_SHIFT       = (SRAM_ADDR_W <= 12) ? 7 : 8;
    localparam integer SRAM_P010_ROW_SHIFT       = (SRAM_ADDR_W <= 12) ? 8 : 9;
    localparam integer SRAM_Y_LOWER_BASE_WORDS   = (SRAM_ADDR_W <= 12) ? 1024 : 2048;
    localparam integer SRAM_UV_BASE_WORDS        = (SRAM_ADDR_W <= 12) ? 2048 : 4096;

    reg [4:0] tot_lines;
    reg has_uv;
    reg is_yuv420;
    reg is_y_stride_1k;
    reg is_p010;
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
            default:  begin
                tot_lines=5'd4;  has_uv=1'b0; is_yuv420=1'b0; is_y_stride_1k=1'b1; is_p010=1'b0;
            end
        endcase
    end

    wire is_rgba;
    assign is_rgba = !has_uv;
    wire [16:0] w_limit_rgba_full;
    assign w_limit_rgba_full = ({1'b0, cfg_img_width} + 17'd3) >> 2;
    wire [16:0] w_limit_yuv_full;
    assign w_limit_yuv_full = ({1'b0, cfg_img_width} + 17'd15) >> 4;
    wire [16:0] w_limit_p010_full;
    assign w_limit_p010_full = ({1'b0, cfg_img_width} + 17'd7) >> 3;
    wire [12:0] w_limit_rgba;
    assign w_limit_rgba = (|w_limit_rgba_full[16:13]) ? 13'h1fff : w_limit_rgba_full[12:0];
    wire [12:0] w_limit_yuv;
    assign w_limit_yuv = (|w_limit_yuv_full[16:13])  ? 13'h1fff : w_limit_yuv_full[12:0];
    wire [12:0] w_limit_p010;
    assign w_limit_p010 = (|w_limit_p010_full[16:13]) ? 13'h1fff : w_limit_p010_full[12:0];
    wire [12:0] w_limit;
    assign w_limit = is_rgba ? w_limit_rgba : (is_p010 ? w_limit_p010 : w_limit_yuv);
    reg [4:0] line_idx;
    reg [12:0] word_idx;
    reg target_bank;
    reg [3:0] target_fcnt;

    wire [2:0]  y_line_in_group;
    assign y_line_in_group = is_p010 ? {1'b0, line_idx[1:0]} : line_idx[2:0];
    wire [16:0] y_group_off_full;
    assign y_group_off_full = is_p010 ? (line_idx[2] ? 17'(SRAM_Y_LOWER_BASE_WORDS) : 17'd0)
                                           : (line_idx[3] ? 17'(SRAM_Y_LOWER_BASE_WORDS) : 17'd0);
    wire [16:0] y_off_full;
    assign y_off_full = {14'd0, y_line_in_group} <<
                             (is_y_stride_1k ? SRAM_RGBA_ROW_SHIFT :
                              (is_p010 ? SRAM_P010_ROW_SHIFT : SRAM_YUV8_ROW_SHIFT));
    wire [16:0] addr_y_full;
    assign addr_y_full = y_group_off_full + y_off_full + {4'd0, word_idx};
    wire [SRAM_ADDR_W-1:0] addr_y;
    assign addr_y = addr_y_full[SRAM_ADDR_W-1:0];
    wire [SRAM_ADDR_W-1:0] addr_y_p1;
    assign addr_y_p1 = addr_y + SRAM_ADDR_W'(1);
    wire [2:0]  uv_l;
    assign uv_l = is_yuv420 ? (is_p010 ? {1'b0, line_idx[2:1]} : line_idx[3:1]) : line_idx[2:0];
    wire [16:0] uv_row_off_full;
    assign uv_row_off_full = {14'd0, uv_l} <<
                                  (is_p010 ? SRAM_P010_ROW_SHIFT : SRAM_YUV8_ROW_SHIFT);
    wire [16:0] addr_uv_full;
    assign addr_uv_full = 17'(SRAM_UV_BASE_WORDS) + uv_row_off_full + {4'd0, word_idx};
    wire [SRAM_ADDR_W-1:0] addr_uv;
    assign addr_uv = addr_uv_full[SRAM_ADDR_W-1:0];
    wire current_line_has_uv;
    assign current_line_has_uv = has_uv && (!is_yuv420 || line_idx[0]);
    wire current_pair_has_second;
    assign current_pair_has_second = current_line_has_uv | (is_rgba && (word_idx != (w_limit - 13'd1)));
    wire [1:0] current_pair_step;
    assign current_pair_step = (is_rgba && current_pair_has_second) ? 2'd2 : 2'd1;

    reg [1:0] state;
    reg [127:0] first_data_reg;
    reg [127:0] second_data_reg;
    reg [1:0] pair_step_reg;
    reg pair_has_second_reg;
    reg second_hold_valid;
    wire frame_start;
    assign frame_start = (i_frame_start == 1'b1);

    wire [13:0] pair_next_word_sum;
    assign pair_next_word_sum = {1'b0, word_idx} + {12'd0, pair_step_reg};
    wire pair_line_done;
    assign pair_line_done = (pair_next_word_sum >= {1'b0, w_limit});
    wire pair_bank_done;
    assign pair_bank_done = pair_line_done && (line_idx == (tot_lines - 5'd1));
    wire [4:0] next_line_idx;
    assign next_line_idx = pair_line_done ? (line_idx + 5'd1) : line_idx;
    wire [12:0] next_word_idx;
    assign next_word_idx = pair_line_done ? 13'd0 : pair_next_word_sum[12:0];

    wire [2:0]  next_y_line_in_group;
    assign next_y_line_in_group = is_p010 ? {1'b0, next_line_idx[1:0]} : next_line_idx[2:0];
    wire [16:0] next_y_group_off_full;
    assign next_y_group_off_full = is_p010 ? (next_line_idx[2] ? 17'(SRAM_Y_LOWER_BASE_WORDS) : 17'd0)
                : (next_line_idx[3] ? 17'(SRAM_Y_LOWER_BASE_WORDS) : 17'd0);
    wire [16:0] next_y_off_full;
    assign next_y_off_full = {14'd0, next_y_line_in_group} <<
                                  (is_y_stride_1k ? SRAM_RGBA_ROW_SHIFT :
                                   (is_p010 ? SRAM_P010_ROW_SHIFT : SRAM_YUV8_ROW_SHIFT));
    wire [16:0] next_addr_y_full;
    assign next_addr_y_full = next_y_group_off_full + next_y_off_full + {4'd0, next_word_idx};
    wire [SRAM_ADDR_W-1:0] next_addr_y;
    assign next_addr_y = next_addr_y_full[SRAM_ADDR_W-1:0];
    wire next_line_has_uv;
    assign next_line_has_uv = has_uv && (!is_yuv420 || next_line_idx[0]);
    wire next_pair_has_second;
    assign next_pair_has_second = next_line_has_uv | (is_rgba && (next_word_idx != (w_limit - 13'd1)));
    wire [1:0] next_pair_step;
    assign next_pair_step = (is_rgba && next_pair_has_second) ? 2'd2 : 2'd1;

    wire push_fire;
    assign push_fire = (state == ST_PUSH) && !i_fifo_full;
    wire start_fetch_fire;
    assign start_fetch_fire = (state == ST_IDLE) && i_buffer_vld && (w_limit != 13'd0);
    wire issue_first_fire;
    assign issue_first_fire = (state == ST_ISSUE_FIRST) && !i_fifo_full;
    wire issue_second_fire;
    assign issue_second_fire = (state == ST_ISSUE_SECOND);
    wire push_accept_fire;
    assign push_accept_fire = (state == ST_PUSH) && !i_fifo_full;
    wire push_hold_second_fire;
    assign push_hold_second_fire = (state == ST_PUSH) && pair_has_second_reg &&
                                   !second_hold_valid && i_fifo_full;
    wire invalid_state;
    assign invalid_state = (state != ST_IDLE) && (state != ST_ISSUE_FIRST) &&
                           (state != ST_ISSUE_SECOND) && (state != ST_PUSH);
    wire issue_next_first;
    assign issue_next_first = push_fire && !pair_bank_done;
    wire issue_first;
    assign issue_first = (state == ST_ISSUE_FIRST) && !i_fifo_full;
    wire issue_second;
    assign issue_second = (state == ST_ISSUE_SECOND) && pair_has_second_reg;
    wire s_ren;
    assign s_ren = issue_first | issue_second | issue_next_first;
    wire [SRAM_ADDR_W-1:0] s_addr;
    assign s_addr = issue_second     ? (has_uv ? addr_uv : addr_y_p1) :
        issue_next_first ? next_addr_y :
                           addr_y;

    assign o_sram_a_ren = s_ren && (target_bank == 0);
    assign o_sram_b_ren = s_ren && (target_bank == 1);
    assign o_sram_a_raddr = s_addr; assign o_sram_b_raddr = s_addr;
    wire [127:0] s_rdata;
    assign s_rdata = (target_bank == 0) ? i_sram_a_rdata : i_sram_b_rdata;
    wire [127:0] pair_second_data;
    assign pair_second_data = pair_has_second_reg ?
                                    (second_hold_valid ? second_data_reg : s_rdata) :
                                    128'd0;

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            state <= ST_IDLE;
        else if (frame_start)
            state <= ST_IDLE;
        else begin
            case (state)
                ST_IDLE: begin
                    if (start_fetch_fire)
                        state <= ST_ISSUE_FIRST;
                end
                ST_ISSUE_FIRST: begin
                    if (!i_fifo_full)
                        state <= ST_ISSUE_SECOND;
                end
                ST_ISSUE_SECOND: begin
                    state <= ST_PUSH;
                end
                ST_PUSH: begin
                    if (!i_fifo_full)
                        state <= pair_bank_done ? ST_IDLE : ST_ISSUE_SECOND;
                end
                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            target_bank <= 1'b0;
        else if (frame_start)
            target_bank <= 1'b0;
        else if (start_fetch_fire)
            target_bank <= i_writer_bank;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            target_fcnt <= 4'd0;
        else if (frame_start)
            target_fcnt <= 4'd0;
        else if (start_fetch_fire)
            target_fcnt <= i_buffer_fcnt;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            line_idx <= 5'd0;
        else if (frame_start)
            line_idx <= 5'd0;
        else if (start_fetch_fire || invalid_state)
            line_idx <= 5'd0;
        else if (push_accept_fire && !pair_bank_done)
            line_idx <= next_line_idx;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            word_idx <= 13'd0;
        else if (frame_start)
            word_idx <= 13'd0;
        else if (start_fetch_fire || invalid_state)
            word_idx <= 13'd0;
        else if (push_accept_fire)
            word_idx <= pair_bank_done ? 13'd0 : next_word_idx;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            first_data_reg <= 128'd0;
        else if (frame_start)
            first_data_reg <= 128'd0;
        else if (issue_second_fire)
            first_data_reg <= s_rdata;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            second_data_reg <= 128'd0;
        else if (frame_start)
            second_data_reg <= 128'd0;
        else if (push_hold_second_fire)
            second_data_reg <= s_rdata;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            pair_has_second_reg <= 1'b0;
        else if (frame_start)
            pair_has_second_reg <= 1'b0;
        else if (issue_first_fire)
            pair_has_second_reg <= current_pair_has_second;
        else if (push_accept_fire && !pair_bank_done)
            pair_has_second_reg <= next_pair_has_second;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            pair_step_reg <= 2'd1;
        else if (frame_start)
            pair_step_reg <= 2'd1;
        else if (issue_first_fire)
            pair_step_reg <= current_pair_step;
        else if (push_accept_fire && !pair_bank_done)
            pair_step_reg <= next_pair_step;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            second_hold_valid <= 1'b0;
        else if (frame_start || start_fetch_fire || issue_first_fire || invalid_state)
            second_hold_valid <= 1'b0;
        else if (push_accept_fire)
            second_hold_valid <= 1'b0;
        else if (push_hold_second_fire)
            second_hold_valid <= 1'b1;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_fifo_wr_en <= 1'b0;
        else if (frame_start)
            o_fifo_wr_en <= 1'b0;
        else
            o_fifo_wr_en <= push_accept_fire;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_fifo_fcnt <= 4'd0;
        else if (frame_start)
            o_fifo_fcnt <= 4'd0;
        else if (start_fetch_fire)
            o_fifo_fcnt <= i_buffer_fcnt;
        else if (state != ST_IDLE)
            o_fifo_fcnt <= target_fcnt;
    end

    always @(posedge clk_sram) begin
        if (push_accept_fire)
            o_fifo_wdata <= {pair_second_data, first_data_reg};
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_fetcher_done <= 1'b0;
        else if (frame_start)
            o_fetcher_done <= 1'b0;
        else
            o_fetcher_done <= push_accept_fire && pair_bank_done;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_fetcher_bank <= 1'b0;
        else if (frame_start)
            o_fetcher_bank <= 1'b0;
        else if (push_accept_fire && pair_bank_done)
            o_fetcher_bank <= target_bank;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_fetcher_fcnt <= 4'd0;
        else if (frame_start)
            o_fetcher_fcnt <= 4'd0;
        else if (push_accept_fire && pair_bank_done)
            o_fetcher_fcnt <= target_fcnt;
    end
endmodule
