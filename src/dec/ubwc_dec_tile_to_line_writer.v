//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-04-01  23:15:40
// Design Name       : 
// Module Name       : 
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module tile_to_line_writer #(
    parameter MAX_W_PIXELS = 4096
)(
    input  wire           clk_sram,
    input  wire           rst_n,
    input  wire           i_frame_start,
    input  wire [15:0]    cfg_img_width,
    input  wire           i_sram_a_free,
    input  wire           i_sram_b_free,
    
    input  wire [4:0]     s_axis_format,
    input  wire [15:0]    s_axis_tile_x,
    input  wire [15:0]    s_axis_tile_y,
    input  wire           s_axis_tile_valid,
    output wire           s_axis_tile_ready,
    input  wire [255:0]   s_axis_tdata,
    input  wire           s_axis_tlast,
    input  wire           s_axis_tvalid,
    output wire           s_axis_tready,

    output wire           sram_a_wen,    
    output wire [12:0]    sram_a_waddr,  
    output wire [127:0]   sram_a_wdata,
    output wire           sram_b_wen,    
    output wire [12:0]    sram_b_waddr,  
    output wire [127:0]   sram_b_wdata,

    output reg            o_writer_bank, 
    output reg            o_buffer_vld     
);

    wire         hdr_fifo_empty, hdr_fifo_full, hdr_fifo_rd_en;
    wire [36:0]  hdr_fifo_dout;
    wire         data_fifo_empty, data_fifo_full, data_fifo_rd_en;
    wire [256:0] data_fifo_dout;
    wire         tile_ctx_available;

    assign s_axis_tile_ready = ~hdr_fifo_full;
    assign tile_ctx_available = !hdr_fifo_empty || (s_axis_tile_valid && s_axis_tile_ready);
    assign s_axis_tready = ~data_fifo_full && tile_ctx_available;
    wire frame_start = (i_frame_start == 1'b1);

    sync_fifo_fwft_262w_512d #(
        .DATA_WIDTH(37)
    ) u_hdr_fifo (
        .clk(clk_sram), .rst_n(rst_n), .clr(frame_start),
        .wr_en(s_axis_tile_valid && s_axis_tile_ready),
        .din({s_axis_format, s_axis_tile_x, s_axis_tile_y}),
        .rd_en(hdr_fifo_rd_en), .dout(hdr_fifo_dout), .full(hdr_fifo_full), .empty(hdr_fifo_empty)
    );

    sync_fifo_fwft_262w_512d #(
        .DATA_WIDTH(257)
    ) u_data_fifo (
        .clk(clk_sram), .rst_n(rst_n), .clr(frame_start),
        .wr_en(s_axis_tvalid && s_axis_tready),
        .din({s_axis_tlast, s_axis_tdata}),
        .rd_en(data_fifo_rd_en), .dout(data_fifo_dout), .full(data_fifo_full), .empty(data_fifo_empty)
    );

    wire [255:0] cur_tdata = data_fifo_dout[255:0];
    wire         cur_tlast = data_fifo_dout[256];
    wire [15:0]  cur_tile_x = hdr_fifo_dout[31:16];
    wire [4:0]   cur_fmt   = hdr_fifo_dout[36:32];

    reg is_y_stride_1k, is_row_len_2, is_uv_plane, is_yuv420, is_rgba, is_p010;

    always @(*) begin
        case (cur_fmt)
            5'b00000, 5'b00001: begin
                is_y_stride_1k = 1'b1; is_row_len_2 = 1'b0;
                is_uv_plane = 1'b0; is_yuv420 = 1'b0; is_rgba = 1'b1; is_p010 = 1'b0;
            end
            5'b01000: begin
                is_y_stride_1k = 1'b0; is_row_len_2 = 1'b1;
                is_uv_plane = 1'b0; is_yuv420 = 1'b1; is_rgba = 1'b0; is_p010 = 1'b0;
            end
            5'b01001: begin
                is_y_stride_1k = 1'b0; is_row_len_2 = 1'b1;
                is_uv_plane = 1'b1; is_yuv420 = 1'b1; is_rgba = 1'b0; is_p010 = 1'b0;
            end
            5'b01110: begin
                is_y_stride_1k = 1'b0; is_row_len_2 = 1'b0;
                is_uv_plane = 1'b0; is_yuv420 = 1'b1; is_rgba = 1'b0; is_p010 = 1'b1;
            end
            5'b01111: begin
                is_y_stride_1k = 1'b0; is_row_len_2 = 1'b0;
                is_uv_plane = 1'b1; is_yuv420 = 1'b1; is_rgba = 1'b0; is_p010 = 1'b1;
            end
            5'b01010: begin
                is_y_stride_1k = 1'b0; is_row_len_2 = 1'b1;
                is_uv_plane = 1'b0; is_yuv420 = 1'b0; is_rgba = 1'b0; is_p010 = 1'b0;
            end
            5'b01011: begin
                is_y_stride_1k = 1'b0; is_row_len_2 = 1'b1;
                is_uv_plane = 1'b1; is_yuv420 = 1'b0; is_rgba = 1'b0; is_p010 = 1'b0;
            end
            default:  begin
                is_y_stride_1k = 1'b1; is_row_len_2 = 1'b0;
                is_uv_plane = 1'b0; is_yuv420 = 1'b0; is_rgba = 1'b1; is_p010 = 1'b0;
            end
        endcase
    end

    reg wr_bank;
    // For YUV420, one slice is written as three full-width passes:
    // 1) Y upper 8 lines, 2) Y lower 8 lines, 3) UV 8 lines.
    // Track that internal order instead of assuming per-tile Y/Y/UV ordering.
    reg [1:0] y420_stage;

    wire target_bank_free = (~wr_bank) ? i_sram_a_free : i_sram_b_free;
    wire sram_wen_internal = (!hdr_fifo_empty) && (!data_fifo_empty) && target_bank_free;
    reg gearbox_sel;

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) gearbox_sel <= 1'b0;
        else if (frame_start) gearbox_sel <= 1'b0;
        else if (sram_wen_internal) gearbox_sel <= ~gearbox_sel;
    end
    assign data_fifo_rd_en = sram_wen_internal && gearbox_sel;

    reg [3:0] cnt_write;

    wire [12:0] p_base = is_uv_plane ? 13'd4096 : 13'd0;
    wire        group_row_sel = (!is_uv_plane && is_yuv420) ? (y420_stage == 2'd1) : 1'b0;
    wire [12:0] v_off  = group_row_sel ? 13'd2048 : 13'd0;
    wire [2:0]  y_in_t = is_row_len_2 ? cnt_write[3:1] : {1'b0, cnt_write[3:2]};
    wire [1:0]  x_w_off= is_row_len_2 ? {1'b0, cnt_write[0]} : cnt_write[1:0];
    wire [12:0] y_off  = is_y_stride_1k ? {y_in_t, 10'd0} :
                         (is_p010 ? {1'b0, y_in_t, 9'd0} : {2'd0, y_in_t, 8'd0});
    wire [16:0] tile_cols = is_rgba ?
                            (({1'b0, cfg_img_width} + 17'd15) >> 4) :
                            (({1'b0, cfg_img_width} + 17'd31) >> 5);
    wire [15:0] max_tile_x = (tile_cols == 0) ? 16'd0 : (tile_cols[15:0] - 1'b1);
    wire        last_tile_x = (cur_tile_x == max_tile_x);
    wire [12:0] tile_x_word_base = (is_rgba || is_p010) ? {cur_tile_x[10:0], 2'b00} : {cur_tile_x[11:0], 1'b0};
    wire [12:0] x_w_off_ext = {11'd0, x_w_off};

    wire [12:0] waddr = p_base + v_off + y_off + tile_x_word_base + x_w_off_ext;
    wire [127:0] wdata = gearbox_sel ? cur_tdata[255:128] : cur_tdata[127:0];
    wire tile_last_write = sram_wen_internal && cur_tlast && gearbox_sel;
    wire rowgroup_done = tile_last_write && last_tile_x;
    wire slice_done = tile_last_write && last_tile_x && (is_rgba || is_uv_plane);
    assign hdr_fifo_rd_en = tile_last_write;

    assign sram_a_wen = sram_wen_internal & (~wr_bank);
    assign sram_b_wen = sram_wen_internal & (wr_bank);
    assign sram_a_waddr = waddr; assign sram_b_waddr = waddr;
    assign sram_a_wdata = wdata; assign sram_b_wdata = wdata;

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) begin
            cnt_write <= 0;
            wr_bank <= 0; o_writer_bank <= 0; o_buffer_vld <= 0;
            y420_stage <= 2'd0;
        end else if (frame_start) begin
            cnt_write <= 0;
            wr_bank <= 0;
            o_writer_bank <= 0;
            o_buffer_vld <= 0;
            y420_stage <= 2'd0;
        end else begin
            o_buffer_vld <= 1'b0; 
            if (sram_wen_internal) begin
                cnt_write <= tile_last_write ? 4'd0 : cnt_write + 1'b1;
                if (rowgroup_done) begin
                    if (is_yuv420) begin
                        if (is_uv_plane) y420_stage <= 2'd0;
                        else if (y420_stage == 2'd0) y420_stage <= 2'd1;
                        else y420_stage <= 2'd2;
                    end else begin
                        y420_stage <= 2'd0;
                    end
                end
                if (slice_done) begin
                    o_writer_bank <= wr_bank;
                    wr_bank <= ~wr_bank;
                    o_buffer_vld  <= 1'b1;
                end
            end
        end
    end
endmodule
