//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-03-20  15:06:52
// Design Name       : 
// Module Name       : ubwc_enc_otf_tile_top.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
`default_nettype none

module ubwc_enc_otf_to_tile
    #(
        parameter ADDR_W = 16,
        parameter DATA_FIFO_DEPTH = 4,
        parameter CI_FIFO_DEPTH   = 16,
        parameter DATA_FIFO_AF_LEVEL = DATA_FIFO_DEPTH - 1,
        parameter COORD_FIFO_DEPTH = 32,
        parameter SB_WIDTH = 1,
        parameter TH_DW = 13,
        parameter TW_DW = 8
    )(
        input   wire                    clk,
        input   wire                    i_otf_clk,
        input   wire                    rst_n,
        
    // static config    
        input   wire    [3      -1:0]   i_cfg_format            ,
        input   wire    [16     -1:0]   i_cfg_width             ,
        input   wire    [16     -1:0]   i_cfg_height            ,
        input   wire    [16     -1:0]   i_cfg_active_width      ,
        input   wire    [16     -1:0]   i_cfg_active_height     ,
        input   wire    [16     -1:0]   i_cfg_tile_w            ,
        input   wire    [4      -1:0]   i_cfg_tile_h            ,
        input   wire    [16     -1:0]   i_cfg_y_tile_cols       ,
        input   wire    [16     -1:0]   i_cfg_uv_tile_cols       ,
        
    // error flags
        output  wire                    o_err_bline,
        output  wire                    o_err_bframe,
        output  wire                    o_err_fifo_ovf,
        input   wire                    i_err_clear,
        
    // OTF input
        input   wire                    i_otf_vsync,
        input   wire                    i_otf_hsync,
        input   wire                    i_otf_de,
        input   wire    [127:0]         i_otf_data,
        input   wire    [3:0]           i_otf_fcnt,
        input   wire    [11:0]          i_otf_lcnt,
        output  wire                    o_otf_ready,
        
    // SRAM bank0
        output  wire                    o_bank0_en,
        output  wire                    o_bank0_wen,
        output  wire    [ADDR_W-1:0]    o_bank0_addr,
        output  wire    [127:0]         o_bank0_din,
        input   wire    [127:0]         i_bank0_dout,
        input   wire                    i_bank0_dout_vld,
   
    // SRAM bank1
        output  wire                    o_bank1_en,
        output  wire                    o_bank1_wen,
        output  wire    [ADDR_W-1:0]    o_bank1_addr,
        output  wire    [127:0]         o_bank1_din,
        input   wire    [127:0]         i_bank1_dout,
        input   wire                    i_bank1_dout_vld,

    // final tile output
        output  wire                    o_tile_vld,
        input   wire                    i_tile_rdy,
        output  wire    [255:0]         o_tile_data,
        output  wire    [31:0]          o_tile_keep,
        output  wire                    o_tile_last,

        output  wire                    o_ci_valid,
        input   wire                    i_ci_ready,
        output  wire                    o_ci_forced_pcm,
        output  wire    [15:0]          o_tile_x,
        output  wire    [15:0]          o_tile_y,
        output  wire    [3:0]           o_tile_fcnt,
        output  wire    [4:0]           o_tile_format,

        input   wire                    i_co_valid,
        input   wire                    i_co_ready,
        output  wire    [TW_DW-1:0]     o_co_tile_x,
        output  wire    [TH_DW-1:0]     o_co_tile_y,
        output  wire    [3:0]           o_co_tile_fcnt,
        output  wire    [4:0]           o_co_tile_format,
        output  wire    [SB_WIDTH-1:0]  o_co_sb,
        output  wire                    o_coord_fifo_wr_en,
        output  wire                    o_coord_fifo_rd_en,

        output  wire                    o_correct_irq_pulse,
        output  wire                    o_correct_irq_slot,
        output  wire    [31:0]          o_otf_de_count0,
        output  wire    [31:0]          o_otf_de_count1,
        output  wire    [31:0]          o_otf_line_count0,
        output  wire    [31:0]          o_otf_line_count1
    );

    wire         pack_fifo_a_vld;
    wire         pack_fifo_a_rdy;
    wire [162:0] pack_fifo_a_data;

    wire         pack_fifo_b_vld;
    wire         pack_fifo_b_rdy;
    wire [162:0] pack_fifo_b_data;
    wire         line_tile_vld;
    wire         line_tile_rdy;
    wire [127:0] line_tile_data;
    wire [15:0]  line_tile_keep;
    wire         line_tile_last;
    wire         line_plane;
    wire [15:0]  line_tile_x;
    wire [15:0]  line_tile_y;
    wire [3:0]   line_tile_fcnt;

    localparam [2:0] FMT_RGBA8888  = 3'd0;
    localparam [2:0] FMT_RGBA10    = 3'd1;
    localparam [2:0] FMT_YUV420_8  = 3'd2;
    localparam [2:0] FMT_YUV420_10 = 3'd3;

    wire rst_n_otf;
    wire rst_n_sys;

    ubwc_enc_rst_mdl u_rst_mdl
    (
        .i_clk      ( clk        ),
        .i_otf_clk  ( i_otf_clk  ),
        .i_rstn     ( rst_n      ),
        .o_rst      (            ),
        .o_rst_n_sys( rst_n_sys  ),
        .o_rst_n_otf( rst_n_otf  ),
        .o_srst     (            )
    );

    reg          half_valid_r;
    reg  [127:0] half_data_r;
    reg  [15:0]  half_keep_r;
    reg          half_last_r;
    reg  [15:0]  half_x_r;
    reg  [15:0]  half_y_r;
    reg  [3:0]   half_fcnt_r;
    reg  [4:0]   half_format_r;
    reg          half_forced_pcm_r;

    reg          tile_first_word_r;

    localparam integer DATA_FIFO_W = 4 + 256 + 32 + 1;
    localparam integer CI_FIFO_W   = 1 + 16 + 16 + 4 + 5;
    localparam integer COORD_FIFO_W = 4 + 5 + TH_DW + TW_DW;

    wire                   data_fifo_full;
    wire                   data_fifo_almost_full;
    wire                   data_fifo_empty;
    wire                   data_fifo_valid;
    wire [DATA_FIFO_W-1:0] data_fifo_dout;
    wire [DATA_FIFO_W-1:0] data_fifo_din;
    wire                   data_fifo_wr_en;
    wire                   data_fifo_rd_en;

    wire                 ci_fifo_full;
    wire                 ci_fifo_empty;
    wire                 ci_fifo_valid;
    wire [CI_FIFO_W-1:0] ci_fifo_dout;
    wire [CI_FIFO_W-1:0] ci_fifo_din;
    wire                 ci_fifo_wr_en;
    wire                 ci_fifo_rd_en;
    wire                 ci_tile_forced_pcm;
    wire [4:0]           ci_tile_format;
    wire [3:0]           ci_tile_fcnt;
    wire [15:0]          ci_tile_y;
    wire [15:0]          ci_tile_x;
    wire                 coord_fifo_wr_en;
    wire                 coord_fifo_rd_en;
    wire [COORD_FIFO_W-1:0] coord_fifo_din;
    wire [COORD_FIFO_W-1:0] coord_fifo_dout;

    function automatic [4:0] calc_tile_format;
        input [2:0] cfg_format;
        input       plane;
        begin
            case (cfg_format)
                FMT_RGBA8888:                  calc_tile_format = 5'd0;
                FMT_RGBA10:                    calc_tile_format = 5'd1;
                FMT_YUV420_8:                  calc_tile_format = plane ? 5'd9  : 5'd8;
                FMT_YUV420_10:                 calc_tile_format = plane ? 5'd15 : 5'd14;
                default:                       calc_tile_format = 5'd0;
            endcase
        end
    endfunction

    function automatic [15:0] ceil_div_pow2_u16;
        input [15:0] dividend;
        input [15:0] divisor;
        begin
            case (divisor)
                16'd1:   ceil_div_pow2_u16 = dividend;
                16'd2:   ceil_div_pow2_u16 = {1'd0, dividend[15:1]} + {15'd0, |dividend[0:0]};
                16'd4:   ceil_div_pow2_u16 = {2'd0, dividend[15:2]} + {15'd0, |dividend[1:0]};
                16'd8:   ceil_div_pow2_u16 = {3'd0, dividend[15:3]} + {15'd0, |dividend[2:0]};
                16'd16:  ceil_div_pow2_u16 = {4'd0, dividend[15:4]} + {15'd0, |dividend[3:0]};
                16'd32:  ceil_div_pow2_u16 = {5'd0, dividend[15:5]} + {15'd0, |dividend[4:0]};
                16'd64:  ceil_div_pow2_u16 = {6'd0, dividend[15:6]} + {15'd0, |dividend[5:0]};
                16'd128: ceil_div_pow2_u16 = {7'd0, dividend[15:7]} + {15'd0, |dividend[6:0]};
                16'd256: ceil_div_pow2_u16 = {8'd0, dividend[15:8]} + {15'd0, |dividend[7:0]};
                default: ceil_div_pow2_u16 = 16'd0;
            endcase
        end
    endfunction

    function automatic rem_nonzero_pow2_u16;
        input [15:0] dividend;
        input [15:0] divisor;
        begin
            case (divisor)
                16'd1:   rem_nonzero_pow2_u16 = 1'b0;
                16'd2:   rem_nonzero_pow2_u16 = |dividend[0:0];
                16'd4:   rem_nonzero_pow2_u16 = |dividend[1:0];
                16'd8:   rem_nonzero_pow2_u16 = |dividend[2:0];
                16'd16:  rem_nonzero_pow2_u16 = |dividend[3:0];
                16'd32:  rem_nonzero_pow2_u16 = |dividend[4:0];
                16'd64:  rem_nonzero_pow2_u16 = |dividend[5:0];
                16'd128: rem_nonzero_pow2_u16 = |dividend[6:0];
                16'd256: rem_nonzero_pow2_u16 = |dividend[7:0];
                default: rem_nonzero_pow2_u16 = 1'b0;
            endcase
        end
    endfunction

    wire [4:0] line_tile_format;

    assign line_tile_format = calc_tile_format(i_cfg_format, line_plane);
    wire [15:0] tile_h_u16;
    assign tile_h_u16 = {12'd0, i_cfg_tile_h};
    wire [15:0] active_width_px;
    assign active_width_px = (i_cfg_active_width  != 16'd0) ? i_cfg_active_width  : i_cfg_width;
    wire [15:0] active_height_px;
    assign active_height_px = (i_cfg_active_height != 16'd0) ? i_cfg_active_height : i_cfg_height;
    wire [15:0] correct_irq_line;
    assign correct_irq_line = (active_height_px > 16'd4) ? (active_height_px - 16'd4) : 16'd0;
    wire        line_is_yuv420;
    assign line_is_yuv420 = (line_tile_format == 5'd8)  || (line_tile_format == 5'd9) ||
        (line_tile_format == 5'd14) || (line_tile_format == 5'd15);
    wire        line_is_uv_plane;
    assign line_is_uv_plane = (line_tile_format == 5'd9)  || (line_tile_format == 5'd11) ||
        (line_tile_format == 5'd13) || (line_tile_format == 5'd15);
    wire [15:0] plane_active_height_px;
    assign plane_active_height_px = (line_is_yuv420 && line_is_uv_plane) ? ((active_height_px + 16'd1) >> 1) : active_height_px;
    wire [15:0] active_tile_cols;
    assign active_tile_cols = ceil_div_pow2_u16(active_width_px, i_cfg_tile_w);
    wire [15:0] active_tile_rows;
    assign active_tile_rows = ceil_div_pow2_u16(plane_active_height_px, tile_h_u16);
    wire        active_width_partial;
    assign active_width_partial = rem_nonzero_pow2_u16(active_width_px, i_cfg_tile_w);
    wire        active_height_partial;
    assign active_height_partial = rem_nonzero_pow2_u16(plane_active_height_px, tile_h_u16);
    wire        partial_right_tile;
    assign partial_right_tile = active_width_partial &&
        (active_tile_cols != 16'd0) &&
        (line_tile_x == active_tile_cols - 16'd1);
    wire        partial_bottom_tile;
    assign partial_bottom_tile = active_height_partial &&
        (active_tile_rows != 16'd0) &&
        (line_tile_y == active_tile_rows - 16'd1);
    wire        line_tile_forced_pcm;
    assign line_tile_forced_pcm = partial_right_tile || partial_bottom_tile;
    wire       data_push_ready;
    assign data_push_ready = !data_fifo_full;
    wire       ci_push_ready;
    assign ci_push_ready = !ci_fifo_full;
    wire       line_tile_fire;
    assign line_tile_fire = line_tile_vld && line_tile_rdy;
    wire       pack_first_fire;
    assign pack_first_fire = line_tile_fire && !half_valid_r;
    wire       pack_second_fire;
    assign pack_second_fire = line_tile_fire && half_valid_r && !half_last_r && data_push_ready;
    wire       pack_in_ready;
    assign pack_in_ready = !half_valid_r || (!half_last_r && data_push_ready);
    wire       flush_half_only;
    assign flush_half_only = half_valid_r && half_last_r && data_push_ready;
    wire       ci_push_needed;
    assign ci_push_needed = tile_first_word_r;
    wire       half_valid_clear;
    assign half_valid_clear = flush_half_only || pack_second_fire;

    assign data_fifo_din   = flush_half_only ?
                             {half_fcnt_r, 1'b1, {16'd0, half_keep_r}, {128'd0, half_data_r}} :
                             {half_fcnt_r, line_tile_last, {line_tile_keep, half_keep_r}, {line_tile_data, half_data_r}};
    assign data_fifo_wr_en = flush_half_only || pack_second_fire;
    assign data_fifo_rd_en = data_fifo_valid && i_tile_rdy;

    assign ci_fifo_din     = {line_tile_forced_pcm, line_tile_format, line_tile_fcnt, line_tile_y, line_tile_x};
    assign ci_fifo_wr_en   = line_tile_fire && tile_first_word_r;
    assign ci_fifo_rd_en   = ci_fifo_valid && i_ci_ready;

    assign line_tile_rdy = pack_in_ready && !data_fifo_almost_full && (!ci_push_needed || ci_push_ready);
    assign o_tile_vld    = data_fifo_valid;
    assign o_ci_valid    = ci_fifo_valid;
    assign {o_tile_fcnt, o_tile_last, o_tile_keep, o_tile_data} = data_fifo_dout;
    assign {ci_tile_forced_pcm, ci_tile_format, ci_tile_fcnt, ci_tile_y, ci_tile_x} = ci_fifo_dout;
    assign o_ci_forced_pcm = ci_tile_forced_pcm;
    assign o_tile_format   = ci_tile_format;
    assign o_tile_y        = ci_tile_y;
    assign o_tile_x        = ci_tile_x;
    assign coord_fifo_wr_en = ci_fifo_rd_en;
    assign coord_fifo_rd_en = i_co_valid & i_co_ready;
    assign coord_fifo_din   = {ci_tile_format, ci_tile_fcnt, ci_tile_y[TH_DW-1:0], ci_tile_x[TW_DW-1:0]};
    assign o_co_tile_x      = coord_fifo_dout[0 +: TW_DW];
    assign o_co_tile_y      = coord_fifo_dout[TW_DW +: TH_DW];
    assign o_co_tile_fcnt   = coord_fifo_dout[TW_DW+TH_DW +: 4];
    assign o_co_tile_format = coord_fifo_dout[TW_DW+TH_DW+4 +: 5];
    assign o_co_sb          = {{(SB_WIDTH-1){1'b0}}, o_co_tile_fcnt[0]};
    assign o_coord_fifo_wr_en = coord_fifo_wr_en;
    assign o_coord_fifo_rd_en = coord_fifo_rd_en;

    reg         otf_vsync_d;
    reg         otf_hsync_d;
    reg         otf_correct_irq_toggle;
    reg         otf_correct_irq_slot;
    reg  [1:0]  otf_correct_irq_seen;
    reg  [31:0] otf_de_count0_r;
    reg  [31:0] otf_de_count1_r;
    reg  [31:0] otf_line_count0_r;
    reg  [31:0] otf_line_count1_r;
    reg         otf_count_snap_toggle;
    reg  [31:0] otf_de_count0_snap;
    reg  [31:0] otf_de_count1_snap;
    reg  [31:0] otf_line_count0_snap;
    reg  [31:0] otf_line_count1_snap;
    (* async_reg = "true" *) reg  [2:0]  correct_irq_toggle_sync;
    (* async_reg = "true" *) reg  [1:0]  correct_irq_slot_sync;
    (* async_reg = "true" *) reg  [2:0]  otf_count_snap_toggle_sync;
    reg  [31:0] otf_de_count0_clk;
    reg  [31:0] otf_de_count1_clk;
    reg  [31:0] otf_line_count0_clk;
    reg  [31:0] otf_line_count1_clk;

    wire        otf_frame_start;

    assign otf_frame_start = i_otf_vsync & ~otf_vsync_d & o_otf_ready;
    wire        otf_line_fire;
    assign otf_line_fire = i_otf_hsync & ~otf_hsync_d & o_otf_ready;
    wire        otf_de_fire;
    assign otf_de_fire = i_otf_de & o_otf_ready;
    wire        otf_slot;
    assign otf_slot = i_otf_fcnt[0];
    wire        correct_irq_hit;
    assign correct_irq_hit = otf_line_fire &&
                                  ({4'd0, i_otf_lcnt} == correct_irq_line) &&
                                  !otf_correct_irq_seen[otf_slot];
    wire        otf_count_snapshot_event;
    wire        otf_count_snapshot_pulse;
    wire [31:0] otf_de_count0_snap_data;
    wire [31:0] otf_de_count1_snap_data;
    wire [31:0] otf_line_count0_snap_data;
    wire [31:0] otf_line_count1_snap_data;

    assign otf_count_snapshot_event = correct_irq_hit || otf_frame_start;
    assign otf_count_snapshot_pulse = otf_count_snap_toggle_sync[2] ^
                                      otf_count_snap_toggle_sync[1];
    assign otf_de_count0_snap_data = (otf_de_fire && !otf_slot) ?
                                     (otf_de_count0_r + 32'd1) :
                                     otf_de_count0_r;
    assign otf_de_count1_snap_data = (otf_de_fire && otf_slot) ?
                                     (otf_de_count1_r + 32'd1) :
                                     otf_de_count1_r;
    assign otf_line_count0_snap_data = (otf_line_fire && !otf_slot) ?
                                       (otf_line_count0_r + 32'd1) :
                                       otf_line_count0_r;
    assign otf_line_count1_snap_data = (otf_line_fire && otf_slot) ?
                                       (otf_line_count1_r + 32'd1) :
                                       otf_line_count1_r;

    assign o_correct_irq_pulse = correct_irq_toggle_sync[2] ^ correct_irq_toggle_sync[1];
    assign o_correct_irq_slot  = correct_irq_slot_sync[1];
    assign o_otf_de_count0     = otf_de_count0_clk;
    assign o_otf_de_count1     = otf_de_count1_clk;
    assign o_otf_line_count0   = otf_line_count0_clk;
    assign o_otf_line_count1   = otf_line_count1_clk;

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_vsync_d <= 1'b0;
        else
            otf_vsync_d <= i_otf_vsync;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_hsync_d <= 1'b0;
        else
            otf_hsync_d <= i_otf_hsync;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_correct_irq_toggle <= 1'b0;
        else if (correct_irq_hit)
            otf_correct_irq_toggle <= ~otf_correct_irq_toggle;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_correct_irq_slot <= 1'b0;
        else if (correct_irq_hit)
            otf_correct_irq_slot <= otf_slot;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_correct_irq_seen <= 2'b00;
        else if (correct_irq_hit)
            otf_correct_irq_seen[otf_slot] <= 1'b1;
        else if (otf_frame_start)
            otf_correct_irq_seen[otf_slot] <= 1'b0;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_de_count0_r <= 32'd0;
        else if (otf_de_fire && !otf_slot)
            otf_de_count0_r <= otf_de_count0_r + 32'd1;
        else if (otf_frame_start && !otf_slot)
            otf_de_count0_r <= 32'd0;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_de_count1_r <= 32'd0;
        else if (otf_de_fire && otf_slot)
            otf_de_count1_r <= otf_de_count1_r + 32'd1;
        else if (otf_frame_start && otf_slot)
            otf_de_count1_r <= 32'd0;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_line_count0_r <= 32'd0;
        else if (otf_line_fire && !otf_slot)
            otf_line_count0_r <= otf_line_count0_r + 32'd1;
        else if (otf_frame_start && !otf_slot)
            otf_line_count0_r <= 32'd0;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_line_count1_r <= 32'd0;
        else if (otf_line_fire && otf_slot)
            otf_line_count1_r <= otf_line_count1_r + 32'd1;
        else if (otf_frame_start && otf_slot)
            otf_line_count1_r <= 32'd0;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_count_snap_toggle <= 1'b0;
        else if (otf_count_snapshot_event)
            otf_count_snap_toggle <= ~otf_count_snap_toggle;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_de_count0_snap <= 32'd0;
        else if (otf_count_snapshot_event)
            otf_de_count0_snap <= otf_de_count0_snap_data;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_de_count1_snap <= 32'd0;
        else if (otf_count_snapshot_event)
            otf_de_count1_snap <= otf_de_count1_snap_data;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_line_count0_snap <= 32'd0;
        else if (otf_count_snapshot_event)
            otf_line_count0_snap <= otf_line_count0_snap_data;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            otf_line_count1_snap <= 32'd0;
        else if (otf_count_snapshot_event)
            otf_line_count1_snap <= otf_line_count1_snap_data;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            correct_irq_toggle_sync <= 3'b000;
        else
            correct_irq_toggle_sync <= {correct_irq_toggle_sync[1:0],
                                        otf_correct_irq_toggle};
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            correct_irq_slot_sync <= 2'b00;
        else
            correct_irq_slot_sync <= {correct_irq_slot_sync[0],
                                      otf_correct_irq_slot};
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            otf_count_snap_toggle_sync <= 3'b000;
        else
            otf_count_snap_toggle_sync <= {otf_count_snap_toggle_sync[1:0],
                                           otf_count_snap_toggle};
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            otf_de_count0_clk <= 32'd0;
        else if (otf_count_snapshot_pulse)
            otf_de_count0_clk <= otf_de_count0_snap;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            otf_de_count1_clk <= 32'd0;
        else if (otf_count_snapshot_pulse)
            otf_de_count1_clk <= otf_de_count1_snap;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            otf_line_count0_clk <= 32'd0;
        else if (otf_count_snapshot_pulse)
            otf_line_count0_clk <= otf_line_count0_snap;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            otf_line_count1_clk <= 32'd0;
        else if (otf_count_snapshot_pulse)
            otf_line_count1_clk <= otf_line_count1_snap;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            half_valid_r <= 1'b0;
        else if (pack_first_fire)
            half_valid_r <= 1'b1;
        else if (half_valid_clear)
            half_valid_r <= 1'b0;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_data_r <= line_tile_data;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_keep_r <= line_tile_keep;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_last_r <= line_tile_last;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_x_r <= line_tile_x;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_y_r <= line_tile_y;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_fcnt_r <= line_tile_fcnt;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_format_r <= line_tile_format;
    end

    always @(posedge clk) begin
        if (pack_first_fire)
            half_forced_pcm_r <= line_tile_forced_pcm;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            tile_first_word_r <= 1'b1;
        else if (line_tile_fire)
            tile_first_word_r <= line_tile_last;
    end

    mg_sync_fifo #(
        .PROG_DEPTH (DATA_FIFO_DEPTH - DATA_FIFO_AF_LEVEL),
        .DWIDTH     (DATA_FIFO_W),
        .DEPTH      (DATA_FIFO_DEPTH),
        .SHOW_AHEAD (1)
    ) u_data_fifo (
        .clk         (clk),
        .rst_n       (rst_n_sys),
        .sclr        (1'b0),
        .wr_en       (data_fifo_wr_en),
        .din         (data_fifo_din),
        .prog_full   (data_fifo_almost_full),
        .full        (data_fifo_full),
        .rd_en       (data_fifo_rd_en),
        .empty       (data_fifo_empty),
        .dout        (data_fifo_dout),
        .valid       (data_fifo_valid),
        .data_count  ()
    );

    mg_sync_fifo #(
        .PROG_DEPTH (1),
        .DWIDTH     (CI_FIFO_W),
        .DEPTH      (CI_FIFO_DEPTH),
        .SHOW_AHEAD (1)
    ) u_ci_fifo (
        .clk         (clk),
        .rst_n       (rst_n_sys),
        .sclr        (1'b0),
        .wr_en       (ci_fifo_wr_en),
        .din         (ci_fifo_din),
        .prog_full   (),
        .full        (ci_fifo_full),
        .rd_en       (ci_fifo_rd_en),
        .empty       (ci_fifo_empty),
        .dout        (ci_fifo_dout),
        .valid       (ci_fifo_valid),
        .data_count  ()
    );

    mg_sync_fifo #(
        .PROG_DEPTH (1),
        .DWIDTH     (COORD_FIFO_W),
        .DEPTH      (COORD_FIFO_DEPTH),
        .SHOW_AHEAD (1)
    ) u_coord_fifo (
        .clk         (clk),
        .rst_n       (rst_n_sys),
        .sclr        (1'b0),
        .wr_en       (coord_fifo_wr_en),
        .din         (coord_fifo_din),
        .prog_full   (),
        .full        (),
        .rd_en       (coord_fifo_rd_en),
        .empty       (),
        .dout        (coord_fifo_dout),
        .valid       (),
        .data_count  ()
    );

    ubwc_enc_otf_data_packer u_otf_data_packer
    (
        .i_otf_clk          ( i_otf_clk                 ),
        .i_clk              ( clk						),
        .rst_n              ( rst_n_sys					),

        .cfg_format         ( i_cfg_format				),
        .cfg_width          ( i_cfg_width				),
        .cfg_height         ( i_cfg_height				),
        .err_bline          ( o_err_bline				),
        .err_bframe         ( o_err_bframe				),
        .err_fifo_ovf       ( o_err_fifo_ovf			),
        .err_clear          ( i_err_clear               ),

        .otf_vsync          ( i_otf_vsync				),
        .otf_hsync          ( i_otf_hsync				),
        .otf_de             ( i_otf_de					),
        .otf_data           ( i_otf_data				),
        .otf_fcnt           ( i_otf_fcnt				),
        .otf_lcnt           ( i_otf_lcnt				),
        .otf_ready          ( o_otf_ready				),

        .fifo_a_vld         ( pack_fifo_a_vld			),
        .fifo_a_rdy         ( pack_fifo_a_rdy			),
        .fifo_a_data        ( pack_fifo_a_data			),
        .fifo_b_vld         ( pack_fifo_b_vld			),
        .fifo_b_rdy         ( pack_fifo_b_rdy			),
        .fifo_b_data        ( pack_fifo_b_data          )
    );

    ubwc_enc_line_to_tile
    #(
        .ADDR_W             ( ADDR_W                    )
    )
    u_line_to_tile
    (
        .clk                ( clk						),
        .rst_n              ( rst_n_sys					),

        .cfg_format         ( i_cfg_format				),
        .cfg_y_tile_cols    ( i_cfg_y_tile_cols         ),
        .cfg_uv_tile_cols    ( i_cfg_uv_tile_cols         ),

        .fifo_a_vld         ( pack_fifo_a_vld			),
        .fifo_a_rdy         ( pack_fifo_a_rdy			),
        .fifo_a_data        ( pack_fifo_a_data			),
        .fifo_b_vld         ( pack_fifo_b_vld			),
        .fifo_b_rdy         ( pack_fifo_b_rdy			),
        .fifo_b_data        ( pack_fifo_b_data			),

        .bank0_en           ( o_bank0_en                ),
        .bank0_wen          ( o_bank0_wen               ),
        .bank0_addr         ( o_bank0_addr              ),
        .bank0_din          ( o_bank0_din               ),
        .bank0_dout         ( i_bank0_dout              ),
        .bank0_dout_vld     ( i_bank0_dout_vld          ),

        .bank1_en           ( o_bank1_en                ),
        .bank1_wen          ( o_bank1_wen               ),
        .bank1_addr         ( o_bank1_addr              ),
        .bank1_din          ( o_bank1_din               ),
        .bank1_dout         ( i_bank1_dout              ),
        .bank1_dout_vld     ( i_bank1_dout_vld          ),

        .o_tile_vld         ( line_tile_vld				),
        .i_tile_rdy         ( line_tile_rdy				),
        .o_tile_data        ( line_tile_data				),
        .o_tile_keep        ( line_tile_keep				),
        .o_tile_last        ( line_tile_last				),
        .o_plane            ( line_plane					),
        .o_tile_x           ( line_tile_x					),
        .o_tile_y           ( line_tile_y					),
        .o_tile_fcnt        ( line_tile_fcnt             )
    );

endmodule

`default_nettype wire
