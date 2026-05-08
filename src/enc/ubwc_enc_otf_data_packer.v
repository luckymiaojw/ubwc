//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-03-19  23:32:15
// Design Name       : 
// Module Name       : ubwc_enc_otf_data_packer.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
//      Primary channel: RGBA or Y
//      UV channel: UV
//      
//      Output Format:
//      {fcnt[3:0], lcnt[11:0], vsync, hsync, tlast, tkeep[15:0], tdata[127:0]}
//      Width = 4 + 12 + 1 + 1 + 1 + 16 + 128 = 163 bits
//
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
`default_nettype none

module ubwc_enc_otf_data_packer
    (
        input  wire         i_otf_clk,
        input  wire         i_clk,
        input  wire         rst_n,
    
        // static config
        input  wire [2:0]   cfg_format,
        input  wire [15:0]  cfg_width,
        input  wire [15:0]  cfg_height,
    
        // error flags
        output wire         err_bline,
        output wire         err_bframe,
        output wire         err_fifo_ovf,
        input  wire         err_clear,
    
        // OTF input
        input  wire         otf_vsync,
        input  wire         otf_hsync,
        input  wire         otf_de,
        input  wire [127:0] otf_data,
        input  wire [3:0]   otf_fcnt,
        input  wire [11:0]  otf_lcnt,
        output wire         otf_ready,
    
        // FIFO A output
        output wire         fifo_a_vld,
        input  wire         fifo_a_rdy,
        output wire [162:0] fifo_a_data,
    
        // FIFO B output
        output wire         fifo_b_vld,
        input  wire         fifo_b_rdy,
        output wire [162:0] fifo_b_data
    );

    localparam FMT_RGBA8888  = 3'd0;
    localparam FMT_RGBA10    = 3'd1;
    localparam FMT_YUV420_8  = 3'd2;
    localparam FMT_YUV420_10 = 3'd3;

    wire rst_n_otf;
    wire rst_n_sys;

    ubwc_enc_rst_mdl u_rst_mdl
    (
        .i_clk      ( i_clk      ),
        .i_otf_clk  ( i_otf_clk  ),
        .i_rstn     ( rst_n      ),
        .o_rst      (            ),
        .o_rst_n_sys( rst_n_sys  ),
        .o_rst_n_otf( rst_n_otf  ),
        .o_srst     (            )
    );

    wire is_rgba;

    assign is_rgba = (cfg_format == FMT_RGBA8888) || (cfg_format == FMT_RGBA10);
    wire is_yuv_8;
    assign is_yuv_8 = (cfg_format == FMT_YUV420_8);
    wire is_yuv_10;
    assign is_yuv_10 = (cfg_format == FMT_YUV420_10);
    wire need_b;
    assign need_b = is_yuv_8 || is_yuv_10;
    wire format_supported;
    assign format_supported = is_rgba || need_b;

    reg otf_vsync_d1;
    reg otf_hsync_d1;
    wire vsync_rising;
    assign vsync_rising = otf_vsync & ~otf_vsync_d1;
    wire hsync_rising;
    assign hsync_rising = otf_hsync & ~otf_hsync_d1;

    reg [3:0]  locked_fcnt;
    reg [11:0] locked_lcnt;
    reg [15:0] pixel_cnt_in;
    reg [15:0] line_cnt_in;
    reg        err_bline_pending_otf;
    reg        err_bframe_pending_otf;
    reg        err_fifo_ovf_pending_otf;
    reg        err_bline_toggle_otf;
    reg        err_bframe_toggle_otf;
    reg        err_fifo_ovf_toggle_otf;
    reg        err_clear_toggle_sys;
    (* async_reg = "true" *) reg err_clear_otf_ff1;
    (* async_reg = "true" *) reg err_clear_otf_ff2;
    reg        err_clear_otf_ff3;
    (* async_reg = "true" *) reg err_bline_sys_ff1;
    (* async_reg = "true" *) reg err_bline_sys_ff2;
    reg        err_bline_sys_ff3;
    (* async_reg = "true" *) reg err_bframe_sys_ff1;
    (* async_reg = "true" *) reg err_bframe_sys_ff2;
    reg        err_bframe_sys_ff3;
    (* async_reg = "true" *) reg err_fifo_ovf_sys_ff1;
    (* async_reg = "true" *) reg err_fifo_ovf_sys_ff2;
    reg        err_fifo_ovf_sys_ff3;
    reg        err_bline_sticky_sys;
    reg        err_bframe_sticky_sys;
    reg        err_fifo_ovf_sticky_sys;

    wire in_fifo_full;
    assign otf_ready = format_supported && ~in_fifo_full;
    wire otf_fire;
    assign otf_fire = otf_de && otf_ready;
    wire in_fifo_wr_en;
    assign in_fifo_wr_en = otf_fire;
    wire locked_lcnt_load_vsync;
    assign locked_lcnt_load_vsync = vsync_rising && !hsync_rising;
    wire locked_lcnt_load_hsync;
    assign locked_lcnt_load_hsync = hsync_rising;
    wire [11:0] locked_lcnt_hsync_value;
    assign locked_lcnt_hsync_value = vsync_rising ? 12'd0 : otf_lcnt;
    wire line_cnt_clear;
    assign line_cnt_clear = vsync_rising && !hsync_rising;
    wire line_cnt_inc;
    assign line_cnt_inc = hsync_rising;
    wire pixel_cnt_clear;
    assign pixel_cnt_clear = hsync_rising;
    wire pixel_cnt_inc;
    assign pixel_cnt_inc = !hsync_rising && otf_fire;
    wire err_bline_set_otf;
    assign err_bline_set_otf = hsync_rising && (pixel_cnt_in > 0) &&
                               (pixel_cnt_in != cfg_width);
    wire err_bframe_set_otf;
    assign err_bframe_set_otf = vsync_rising && (line_cnt_in > 0) &&
                                (line_cnt_in != cfg_height);
    wire err_fifo_ovf_set_otf;
    assign err_fifo_ovf_set_otf = otf_de && in_fifo_full;
    wire err_clear_otf;
    assign err_clear_otf = err_clear_otf_ff2 ^ err_clear_otf_ff3;
    wire err_bline_new_otf;
    assign err_bline_new_otf = err_bline_set_otf &&
                               !err_bline_pending_otf &&
                               !err_clear_otf;
    wire err_bframe_new_otf;
    assign err_bframe_new_otf = err_bframe_set_otf &&
                                !err_bframe_pending_otf &&
                                !err_clear_otf;
    wire err_fifo_ovf_new_otf;
    assign err_fifo_ovf_new_otf = err_fifo_ovf_set_otf &&
                                  !err_fifo_ovf_pending_otf &&
                                  !err_clear_otf;
    wire err_bline_event_sys;
    assign err_bline_event_sys = err_bline_sys_ff2 ^ err_bline_sys_ff3;
    wire err_bframe_event_sys;
    assign err_bframe_event_sys = err_bframe_sys_ff2 ^ err_bframe_sys_ff3;
    wire err_fifo_ovf_event_sys;
    assign err_fifo_ovf_event_sys = err_fifo_ovf_sys_ff2 ^ err_fifo_ovf_sys_ff3;

    assign err_bline = err_bline_sticky_sys;
    assign err_bframe = err_bframe_sticky_sys;
    assign err_fifo_ovf = err_fifo_ovf_sticky_sys;

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_vsync_d1 <= 1'b0;
        else
            otf_vsync_d1 <= otf_vsync;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_hsync_d1 <= 1'b0;
        else
            otf_hsync_d1 <= otf_hsync;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            locked_fcnt <= 4'd0;
        else if (vsync_rising)
            locked_fcnt <= otf_fcnt;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            locked_lcnt <= 12'd0;
        else if (locked_lcnt_load_hsync)
            locked_lcnt <= locked_lcnt_hsync_value;
        else if (locked_lcnt_load_vsync)
            locked_lcnt <= 12'd0;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            pixel_cnt_in <= 16'd0;
        else if (pixel_cnt_clear)
            pixel_cnt_in <= 16'd0;
        else if (pixel_cnt_inc)
            pixel_cnt_in <= pixel_cnt_in + 16'd4;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            line_cnt_in <= 16'd0;
        else if (line_cnt_inc)
            line_cnt_in <= line_cnt_in + 16'd1;
        else if (line_cnt_clear)
            line_cnt_in <= 16'd0;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_clear_toggle_sys <= 1'b0;
        else if (err_clear)
            err_clear_toggle_sys <= ~err_clear_toggle_sys;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            err_clear_otf_ff1 <= 1'b0;
        else
            err_clear_otf_ff1 <= err_clear_toggle_sys;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            err_clear_otf_ff2 <= 1'b0;
        else
            err_clear_otf_ff2 <= err_clear_otf_ff1;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            err_clear_otf_ff3 <= 1'b0;
        else
            err_clear_otf_ff3 <= err_clear_otf_ff2;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            err_bline_pending_otf <= 1'b0;
        else if (err_clear_otf)
            err_bline_pending_otf <= 1'b0;
        else if (err_bline_set_otf)
            err_bline_pending_otf <= 1'b1;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            err_bframe_pending_otf <= 1'b0;
        else if (err_clear_otf)
            err_bframe_pending_otf <= 1'b0;
        else if (err_bframe_set_otf)
            err_bframe_pending_otf <= 1'b1;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            err_fifo_ovf_pending_otf <= 1'b0;
        else if (err_clear_otf)
            err_fifo_ovf_pending_otf <= 1'b0;
        else if (err_fifo_ovf_set_otf)
            err_fifo_ovf_pending_otf <= 1'b1;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            err_bline_toggle_otf <= 1'b0;
        else if (err_bline_new_otf)
            err_bline_toggle_otf <= ~err_bline_toggle_otf;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            err_bframe_toggle_otf <= 1'b0;
        else if (err_bframe_new_otf)
            err_bframe_toggle_otf <= ~err_bframe_toggle_otf;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            err_fifo_ovf_toggle_otf <= 1'b0;
        else if (err_fifo_ovf_new_otf)
            err_fifo_ovf_toggle_otf <= ~err_fifo_ovf_toggle_otf;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_bline_sys_ff1 <= 1'b0;
        else
            err_bline_sys_ff1 <= err_bline_toggle_otf;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_bline_sys_ff2 <= 1'b0;
        else
            err_bline_sys_ff2 <= err_bline_sys_ff1;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_bline_sys_ff3 <= 1'b0;
        else
            err_bline_sys_ff3 <= err_bline_sys_ff2;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_bframe_sys_ff1 <= 1'b0;
        else
            err_bframe_sys_ff1 <= err_bframe_toggle_otf;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_bframe_sys_ff2 <= 1'b0;
        else
            err_bframe_sys_ff2 <= err_bframe_sys_ff1;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_bframe_sys_ff3 <= 1'b0;
        else
            err_bframe_sys_ff3 <= err_bframe_sys_ff2;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_fifo_ovf_sys_ff1 <= 1'b0;
        else
            err_fifo_ovf_sys_ff1 <= err_fifo_ovf_toggle_otf;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_fifo_ovf_sys_ff2 <= 1'b0;
        else
            err_fifo_ovf_sys_ff2 <= err_fifo_ovf_sys_ff1;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_fifo_ovf_sys_ff3 <= 1'b0;
        else
            err_fifo_ovf_sys_ff3 <= err_fifo_ovf_sys_ff2;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_bline_sticky_sys <= 1'b0;
        else if (err_bline_event_sys)
            err_bline_sticky_sys <= 1'b1;
        else if (err_clear)
            err_bline_sticky_sys <= 1'b0;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_bframe_sticky_sys <= 1'b0;
        else if (err_bframe_event_sys)
            err_bframe_sticky_sys <= 1'b1;
        else if (err_clear)
            err_bframe_sticky_sys <= 1'b0;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_fifo_ovf_sticky_sys <= 1'b0;
        else if (err_fifo_ovf_event_sys)
            err_fifo_ovf_sticky_sys <= 1'b1;
        else if (err_clear)
            err_fifo_ovf_sticky_sys <= 1'b0;
    end

    wire [15:0] effective_pixel_cnt;

    assign effective_pixel_cnt = (otf_hsync || hsync_rising) ? 16'd0 : pixel_cnt_in;
    wire otf_last_beat;
    assign otf_last_beat = (effective_pixel_cnt + 16'd4 >= cfg_width);

    reg sticky_vsync;
    reg sticky_hsync;

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            sticky_vsync <= 1'b0;
        else begin
            if (otf_vsync)      sticky_vsync <= 1'b1;
            else if (otf_fire)  sticky_vsync <= 1'b0;
        end
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            sticky_hsync <= 1'b0;
        else begin
            if (otf_hsync)      sticky_hsync <= 1'b1;
            else if (otf_fire)  sticky_hsync <= 1'b0;
        end
    end

    wire        din_vsync;

    assign din_vsync = sticky_vsync | otf_vsync;
    wire        din_hsync;
    assign din_hsync = sticky_hsync | otf_hsync;
    wire [3:0]  din_fcnt;
    assign din_fcnt = otf_vsync ? otf_fcnt : locked_fcnt;
    wire [11:0] din_lcnt;
    assign din_lcnt = otf_hsync ? otf_lcnt : locked_lcnt;

    wire         in_fifo_empty;
    wire         in_fifo_rd;
    wire [146:0] in_fifo_din;
    wire [146:0] in_fifo_dout;
    assign in_fifo_din = {otf_last_beat, din_fcnt, din_lcnt, din_vsync, din_hsync, otf_data};

    mg_async_fifo #(
        .AF         (1),
        .DATA_BITS  (147),
        .DEPTH_BITS (4),
        .SHOW_AHEAD (1),
        .RAM_STYLE  ("block")
    ) u_input_fifo (
        .wr_clk        (i_otf_clk),
        .wr_rstn       (rst_n_otf),
        .wr_en         (in_fifo_wr_en),
        .din           (in_fifo_din),
        .wr_data_count (),
        .prog_full     (),
        .full          (in_fifo_full),
        .rd_clk        (i_clk),
        .rd_rstn       (rst_n_sys),
        .rd_en         (in_fifo_rd),
        .dout          (in_fifo_dout),
        .valid         (),
        .rd_data_count (),
        .pre_empty     (),
        .empty         (in_fifo_empty)
    );

    wire         inf_last_beat;

    assign inf_last_beat = in_fifo_dout[146];
    wire [17:0]  inf_sideband;
    assign inf_sideband = in_fifo_dout[145:128];
    wire [11:0]  inf_lcnt;
    assign inf_lcnt = in_fifo_dout[141:130];
    wire [127:0] inf_data;
    assign inf_data = in_fifo_dout[127:0];
    wire         is_odd_line;
    assign is_odd_line = inf_lcnt[0];

    wire         fifo_a_empty;
    wire         fifo_b_empty;
    wire         fifo_a_valid;
    wire         fifo_b_valid;
    reg          out_fifo_a_wr;
    reg          out_fifo_b_wr;
    reg  [162:0] out_fifo_a_din;
    reg  [162:0] out_fifo_b_din;
    wire         out_fifo_a_afull;
    wire         out_fifo_b_afull;

    mg_sync_fifo #(
        .PROG_DEPTH (4),
        .DWIDTH     (163),
        .DEPTH      (16),
        .SHOW_AHEAD (1)
    ) u_out_fifo_a (
        .clk         (i_clk),
        .rst_n       (rst_n_sys),
        .sclr        (1'b0),
        .wr_en       (out_fifo_a_wr),
        .din         (out_fifo_a_din),
        .prog_full   (out_fifo_a_afull),
        .full        (),
        .rd_en       (fifo_a_vld && fifo_a_rdy),
        .empty       (fifo_a_empty),
        .dout        (fifo_a_data),
        .valid       (fifo_a_valid),
        .data_count  ()
    );
    assign fifo_a_vld = fifo_a_valid;

    mg_sync_fifo #(
        .PROG_DEPTH (4),
        .DWIDTH     (163),
        .DEPTH      (16),
        .SHOW_AHEAD (1)
    ) u_out_fifo_b (
        .clk         (i_clk),
        .rst_n       (rst_n_sys),
        .sclr        (1'b0),
        .wr_en       (out_fifo_b_wr),
        .din         (out_fifo_b_din),
        .prog_full   (out_fifo_b_afull),
        .full        (),
        .rd_en       (fifo_b_vld && fifo_b_rdy),
        .empty       (fifo_b_empty),
        .dout        (fifo_b_data),
        .valid       (fifo_b_valid),
        .data_count  ()
    );
    assign fifo_b_vld = fifo_b_valid;

    wire pipe_stall;

    assign pipe_stall = out_fifo_a_afull | (need_b && !is_odd_line && out_fifo_b_afull);
    assign in_fifo_rd = !in_fifo_empty && !pipe_stall;

    wire [127:0] ext_a_data128;
    assign ext_a_data128 = is_rgba ? inf_data : 128'd0;
    wire [31:0] ext_a_data32;
    assign ext_a_data32 = is_yuv_8 ?
                          {inf_data[111:104], inf_data[79:72],
                           inf_data[47:40],   inf_data[15:8]} :
                          32'd0;
    wire [63:0] ext_a_data64;
    assign ext_a_data64 = is_yuv_10 ?
                          {inf_data[115:106], 6'b0,
                           inf_data[83:74],   6'b0,
                           inf_data[51:42],   6'b0,
                           inf_data[19:10],   6'b0} :
                          64'd0;
    wire ext_a_vld_128;
    assign ext_a_vld_128 = is_rgba;
    wire ext_a_vld_32;
    assign ext_a_vld_32 = is_yuv_8;
    wire ext_a_vld_64;
    assign ext_a_vld_64 = is_yuv_10;

    wire [31:0] ext_b_data32;
    assign ext_b_data32 = (is_yuv_8 && !is_odd_line) ?
                          {inf_data[71:64], inf_data[87:80],
                           inf_data[7:0],   inf_data[23:16]} :
                          32'd0;
    wire [63:0] ext_b_data64;
    assign ext_b_data64 = (is_yuv_10 && !is_odd_line) ?
                          {inf_data[73:64], 6'b0,
                           inf_data[93:84], 6'b0,
                           inf_data[9:0],   6'b0,
                           inf_data[29:20], 6'b0} :
                          64'd0;
    wire ext_b_vld_32;
    assign ext_b_vld_32 = is_yuv_8 && !is_odd_line;
    wire ext_b_vld_64;
    assign ext_b_vld_64 = is_yuv_10 && !is_odd_line;

    reg [127:0] a_pack32_data;
    reg [127:0] a_pack64_data;
    reg [1:0]   a_pack32_cnt;
    reg         a_pack64_cnt;
    reg [17:0]  a_pack32_sb;
    reg [17:0]  a_pack64_sb;

    wire a_take_128;
    assign a_take_128 = in_fifo_rd && ext_a_vld_128;
    wire a_take_32;
    assign a_take_32 = in_fifo_rd && ext_a_vld_32;
    wire a_take_64;
    assign a_take_64 = in_fifo_rd && ext_a_vld_64;
    wire a_pack32_full;
    assign a_pack32_full = a_take_32 && (a_pack32_cnt == 2'd3);
    wire a_pack32_flush;
    assign a_pack32_flush = a_take_32 && inf_last_beat && (a_pack32_cnt != 2'd3);
    wire a_pack64_full;
    assign a_pack64_full = a_take_64 && a_pack64_cnt;
    wire a_pack64_flush;
    assign a_pack64_flush = a_take_64 && inf_last_beat && !a_pack64_cnt;
    wire a_out_fifo_wr_next;
    assign a_out_fifo_wr_next = a_take_128 || a_pack32_full ||
                                a_pack32_flush || a_pack64_full ||
                                a_pack64_flush;
    wire a_pack32_done;
    assign a_pack32_done = a_pack32_full || a_pack32_flush;
    wire a_pack64_done;
    assign a_pack64_done = a_pack64_full || a_pack64_flush;
    wire [17:0] a_pack32_sb_out;
    assign a_pack32_sb_out = (a_pack32_cnt == 2'd0) ? inf_sideband : a_pack32_sb;
    wire [17:0] a_pack64_sb_out;
    assign a_pack64_sb_out = (a_pack64_cnt == 1'b0) ? inf_sideband : a_pack64_sb;

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            out_fifo_a_wr <= 1'b0;
        else
            out_fifo_a_wr <= a_out_fifo_wr_next;
    end

    always @(posedge i_clk) begin
        if (a_take_128)
            out_fifo_a_din <= {inf_sideband, inf_last_beat, 16'hFFFF,
                               ext_a_data128};
        else if (a_pack32_full)
            out_fifo_a_din <= {a_pack32_sb, inf_last_beat, 16'hFFFF,
                               {ext_a_data32, a_pack32_data[95:0]}};
        else if (a_pack32_flush) begin
            case (a_pack32_cnt)
                2'd0: out_fifo_a_din <= {a_pack32_sb_out, 1'b1, 16'h000F,
                                          {96'd0, ext_a_data32}};
                2'd1: out_fifo_a_din <= {a_pack32_sb_out, 1'b1, 16'h00FF,
                                          {64'd0, ext_a_data32,
                                           a_pack32_data[31:0]}};
                2'd2: out_fifo_a_din <= {a_pack32_sb_out, 1'b1, 16'h0FFF,
                                          {32'd0, ext_a_data32,
                                           a_pack32_data[63:0]}};
                default: ;
            endcase
        end else if (a_pack64_full)
            out_fifo_a_din <= {a_pack64_sb, inf_last_beat, 16'hFFFF,
                               {ext_a_data64, a_pack64_data[63:0]}};
        else if (a_pack64_flush)
            out_fifo_a_din <= {a_pack64_sb_out, 1'b1, 16'h00FF,
                               {64'd0, ext_a_data64}};
    end

    always @(posedge i_clk) begin
        if (a_take_32) begin
            case (a_pack32_cnt)
                2'd0: a_pack32_data[31:0]   <= ext_a_data32;
                2'd1: a_pack32_data[63:32]  <= ext_a_data32;
                2'd2: a_pack32_data[95:64]  <= ext_a_data32;
                2'd3: a_pack32_data[127:96] <= ext_a_data32;
                default: ;
            endcase
        end
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            a_pack32_cnt <= 2'd0;
        else if (a_take_32) begin
            if (a_pack32_done)
                a_pack32_cnt <= 2'd0;
            else
                a_pack32_cnt <= a_pack32_cnt + 2'd1;
        end
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            a_pack32_sb <= 18'd0;
        else if (a_take_32 && (a_pack32_cnt == 2'd0))
            a_pack32_sb <= inf_sideband;
    end

    always @(posedge i_clk) begin
        if (a_take_64) begin
            if (a_pack64_cnt == 1'b0)
                a_pack64_data[63:0] <= ext_a_data64;
            else
                a_pack64_data[127:64] <= ext_a_data64;
        end
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            a_pack64_cnt <= 1'b0;
        else if (a_take_64) begin
            if (a_pack64_done)
                a_pack64_cnt <= 1'b0;
            else
                a_pack64_cnt <= 1'b1;
        end
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            a_pack64_sb <= 18'd0;
        else if (a_take_64 && (a_pack64_cnt == 1'b0))
            a_pack64_sb <= inf_sideband;
    end

    reg [127:0] b_pack32_data;
    reg [127:0] b_pack64_data;
    reg [1:0]   b_pack32_cnt;
    reg         b_pack64_cnt;
    reg [17:0]  b_pack32_sb;
    reg [17:0]  b_pack64_sb;

    wire b_take_32;
    assign b_take_32 = in_fifo_rd && need_b && ext_b_vld_32;
    wire b_take_64;
    assign b_take_64 = in_fifo_rd && need_b && ext_b_vld_64;
    wire b_pack32_full;
    assign b_pack32_full = b_take_32 && (b_pack32_cnt == 2'd3);
    wire b_pack32_flush;
    assign b_pack32_flush = b_take_32 && inf_last_beat && (b_pack32_cnt != 2'd3);
    wire b_pack64_full;
    assign b_pack64_full = b_take_64 && b_pack64_cnt;
    wire b_pack64_flush;
    assign b_pack64_flush = b_take_64 && inf_last_beat && !b_pack64_cnt;
    wire b_out_fifo_wr_next;
    assign b_out_fifo_wr_next = b_pack32_full || b_pack32_flush ||
                                b_pack64_full || b_pack64_flush;
    wire b_pack32_done;
    assign b_pack32_done = b_pack32_full || b_pack32_flush;
    wire b_pack64_done;
    assign b_pack64_done = b_pack64_full || b_pack64_flush;
    wire [17:0] b_pack32_sb_out;
    assign b_pack32_sb_out = (b_pack32_cnt == 2'd0) ? inf_sideband : b_pack32_sb;
    wire [17:0] b_pack64_sb_out;
    assign b_pack64_sb_out = (b_pack64_cnt == 1'b0) ? inf_sideband : b_pack64_sb;

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            out_fifo_b_wr <= 1'b0;
        else
            out_fifo_b_wr <= b_out_fifo_wr_next;
    end

    always @(posedge i_clk) begin
        if (b_pack32_full)
            out_fifo_b_din <= {b_pack32_sb, inf_last_beat, 16'hFFFF,
                               {ext_b_data32, b_pack32_data[95:0]}};
        else if (b_pack32_flush) begin
            case (b_pack32_cnt)
                2'd0: out_fifo_b_din <= {b_pack32_sb_out, 1'b1, 16'h000F,
                                          {96'd0, ext_b_data32}};
                2'd1: out_fifo_b_din <= {b_pack32_sb_out, 1'b1, 16'h00FF,
                                          {64'd0, ext_b_data32,
                                           b_pack32_data[31:0]}};
                2'd2: out_fifo_b_din <= {b_pack32_sb_out, 1'b1, 16'h0FFF,
                                          {32'd0, ext_b_data32,
                                           b_pack32_data[63:0]}};
                default: ;
            endcase
        end else if (b_pack64_full)
            out_fifo_b_din <= {b_pack64_sb, inf_last_beat, 16'hFFFF,
                               {ext_b_data64, b_pack64_data[63:0]}};
        else if (b_pack64_flush)
            out_fifo_b_din <= {b_pack64_sb_out, 1'b1, 16'h00FF,
                               {64'd0, ext_b_data64}};
    end

    always @(posedge i_clk) begin
        if (b_take_32) begin
            case (b_pack32_cnt)
                2'd0: b_pack32_data[31:0]   <= ext_b_data32;
                2'd1: b_pack32_data[63:32]  <= ext_b_data32;
                2'd2: b_pack32_data[95:64]  <= ext_b_data32;
                2'd3: b_pack32_data[127:96] <= ext_b_data32;
                default: ;
            endcase
        end
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            b_pack32_cnt <= 2'd0;
        else if (b_take_32) begin
            if (b_pack32_done)
                b_pack32_cnt <= 2'd0;
            else
                b_pack32_cnt <= b_pack32_cnt + 2'd1;
        end
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            b_pack32_sb <= 18'd0;
        else if (b_take_32 && (b_pack32_cnt == 2'd0))
            b_pack32_sb <= inf_sideband;
    end

    always @(posedge i_clk) begin
        if (b_take_64) begin
            if (b_pack64_cnt == 1'b0)
                b_pack64_data[63:0] <= ext_b_data64;
            else
                b_pack64_data[127:64] <= ext_b_data64;
        end
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            b_pack64_cnt <= 1'b0;
        else if (b_take_64) begin
            if (b_pack64_done)
                b_pack64_cnt <= 1'b0;
            else
                b_pack64_cnt <= 1'b1;
        end
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            b_pack64_sb <= 18'd0;
        else if (b_take_64 && (b_pack64_cnt == 1'b0))
            b_pack64_sb <= inf_sideband;
    end

endmodule

`default_nettype wire
