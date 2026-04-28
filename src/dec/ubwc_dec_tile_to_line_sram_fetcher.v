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

    localparam [1:0] ST_IDLE         = 2'd0;
    localparam [1:0] ST_ISSUE_FIRST  = 2'd1;
    localparam [1:0] ST_ISSUE_SECOND = 2'd2;
    localparam [1:0] ST_PUSH         = 2'd3;

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
    wire [12:0] w_limit_rgba = (|w_limit_rgba_full[16:13]) ? 13'h1fff : w_limit_rgba_full[12:0];
    wire [12:0] w_limit_yuv  = (|w_limit_yuv_full[16:13])  ? 13'h1fff : w_limit_yuv_full[12:0];
    wire [12:0] w_limit_p010 = (|w_limit_p010_full[16:13]) ? 13'h1fff : w_limit_p010_full[12:0];
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
    wire current_line_has_uv = has_uv && (!is_yuv420 || line_idx[0]);
    wire current_pair_has_second = current_line_has_uv | (is_rgba && (word_idx != (w_limit - 13'd1)));
    wire [1:0] current_pair_step = (is_rgba && current_pair_has_second) ? 2'd2 : 2'd1;

    reg [1:0] state;
    reg [127:0] first_data_reg;
    reg [127:0] second_data_reg;
    reg [1:0] pair_step_reg;
    reg pair_has_second_reg;
    reg second_hold_valid;
    wire frame_start = (i_frame_start == 1'b1);

    wire [13:0] pair_next_word_sum = {1'b0, word_idx} + {12'd0, pair_step_reg};
    wire pair_line_done = (pair_next_word_sum >= {1'b0, w_limit});
    wire pair_bank_done = pair_line_done && (line_idx == (tot_lines - 5'd1));
    wire [4:0] next_line_idx = pair_line_done ? (line_idx + 5'd1) : line_idx;
    wire [12:0] next_word_idx = pair_line_done ? 13'd0 : pair_next_word_sum[12:0];

    wire [2:0]  next_y_line_in_group = is_p010 ? {1'b0, next_line_idx[1:0]} : next_line_idx[2:0];
    wire [12:0] next_y_group_off = is_p010 ? (next_line_idx[2] ? 13'd2048 : 13'd0)
                                           : (next_line_idx[3] ? 13'd2048 : 13'd0);
    wire [12:0] next_y_off = is_y_stride_1k ? {next_y_line_in_group, 10'd0}
                                            : (is_p010 ? {1'b0, next_y_line_in_group, 9'd0}
                                                       : {2'd0, next_y_line_in_group, 8'd0});
    wire [12:0] next_addr_y = next_y_group_off + next_y_off + next_word_idx;
    wire next_line_has_uv = has_uv && (!is_yuv420 || next_line_idx[0]);
    wire next_pair_has_second = next_line_has_uv | (is_rgba && (next_word_idx != (w_limit - 13'd1)));
    wire [1:0] next_pair_step = (is_rgba && next_pair_has_second) ? 2'd2 : 2'd1;

    wire push_fire = (state == ST_PUSH) && !i_fifo_full;
    wire issue_next_first = push_fire && !pair_bank_done;
    wire issue_first = (state == ST_ISSUE_FIRST) && !i_fifo_full;
    wire issue_second = (state == ST_ISSUE_SECOND) && pair_has_second_reg;
    wire s_ren = issue_first | issue_second | issue_next_first;
    wire [12:0] s_addr =
        issue_second     ? (has_uv ? addr_uv : addr_y_p1) :
        issue_next_first ? next_addr_y :
                           addr_y;

    assign o_sram_a_ren = s_ren && (target_bank == 0);
    assign o_sram_b_ren = s_ren && (target_bank == 1);
    assign o_sram_a_raddr = s_addr; assign o_sram_b_raddr = s_addr;
    wire [127:0] s_rdata = (target_bank == 0) ? i_sram_a_rdata : i_sram_b_rdata;
    wire [127:0] pair_second_data = pair_has_second_reg ?
                                    (second_hold_valid ? second_data_reg : s_rdata) :
                                    128'd0;

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE; target_bank <= 0; line_idx <= 0; word_idx <= 0;
            first_data_reg <= 0; second_data_reg <= 0;
            pair_has_second_reg <= 1'b0; pair_step_reg <= 2'd1; second_hold_valid <= 1'b0;
            o_fifo_wr_en <= 0; o_fetcher_done <= 0; o_fetcher_bank <= 0;
        end else if (frame_start) begin
            state <= ST_IDLE; target_bank <= 0; line_idx <= 0; word_idx <= 0;
            first_data_reg <= 0; second_data_reg <= 0;
            pair_has_second_reg <= 1'b0; pair_step_reg <= 2'd1; second_hold_valid <= 1'b0;
            o_fifo_wr_en <= 0; o_fetcher_done <= 0; o_fetcher_bank <= 0;
        end else begin
            o_fifo_wr_en <= 0; o_fetcher_done <= 0;
            case (state)
                ST_IDLE: begin
                    if (i_buffer_vld && (w_limit != 0)) begin
                        target_bank <= i_writer_bank;
                        line_idx <= 0;
                        word_idx <= 0;
                        second_hold_valid <= 1'b0;
                        state <= ST_ISSUE_FIRST;
                    end
                end
                ST_ISSUE_FIRST: begin
                    if (!i_fifo_full) begin
                        pair_has_second_reg <= current_pair_has_second;
                        pair_step_reg <= current_pair_step;
                        second_hold_valid <= 1'b0;
                        state <= ST_ISSUE_SECOND;
                    end
                end
                ST_ISSUE_SECOND: begin
                    first_data_reg <= s_rdata;
                    state <= ST_PUSH;
                end
                ST_PUSH: begin
                    if (pair_has_second_reg && !second_hold_valid && i_fifo_full) begin
                        second_data_reg <= s_rdata;
                        second_hold_valid <= 1'b1;
                    end

                    if (!i_fifo_full) begin
                        o_fifo_wr_en <= 1'b1;
                        o_fifo_wdata <= {pair_second_data, first_data_reg};
                        second_hold_valid <= 1'b0;

                        if (pair_bank_done) begin
                            word_idx <= 0;
                            o_fetcher_done <= 1'b1;
                            o_fetcher_bank <= target_bank;
                            state <= ST_IDLE;
                        end else begin
                            line_idx <= next_line_idx;
                            word_idx <= next_word_idx;
                            pair_has_second_reg <= next_pair_has_second;
                            pair_step_reg <= next_pair_step;
                            state <= ST_ISSUE_SECOND;
                        end
                    end
                end
                default: begin
                    state <= ST_IDLE;
                    line_idx <= 0;
                    word_idx <= 0;
                    second_hold_valid <= 1'b0;
                end
            endcase
        end
    end
endmodule
