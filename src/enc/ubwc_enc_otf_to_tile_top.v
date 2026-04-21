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
        parameter DATA_FIFO_AF_LEVEL = DATA_FIFO_DEPTH - 1
    )(
        input   wire                    clk,
        input   wire                    rst_n,
        
    // static config    
        input   wire    [3      -1:0]   i_cfg_format            ,
        input   wire    [16     -1:0]   i_cfg_width             ,
        input   wire    [16     -1:0]   i_cfg_height            ,
        input   wire    [16     -1:0]   i_cfg_active_width      ,
        input   wire    [16     -1:0]   i_cfg_active_height     ,
        input   wire    [16     -1:0]   i_cfg_tile_w            ,
        input   wire    [4      -1:0]   i_cfg_tile_h            ,
        input   wire    [16     -1:0]   i_cfg_a_tile_cols       ,
        input   wire    [16     -1:0]   i_cfg_b_tile_cols       ,
        
    // error flags
        output  wire                    o_err_bline,
        output  wire                    o_err_bframe,
        output  wire                    o_err_fifo_ovf,
        
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
        output  wire    [4:0]           o_tile_format
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
    localparam [2:0] FMT_YUV422_8  = 3'd4;
    localparam [2:0] FMT_YUV422_10 = 3'd5;

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

    localparam integer DATA_FIFO_W = 256 + 32 + 1;
    localparam integer CI_FIFO_W   = 1 + 16 + 16 + 4 + 5;

    wire                   data_fifo_full;
    wire                   data_fifo_almost_full;
    wire                   data_fifo_empty;
    wire [DATA_FIFO_W-1:0] data_fifo_dout;
    wire [DATA_FIFO_W-1:0] data_fifo_din;
    wire                   data_fifo_wr_en;
    wire                   data_fifo_rd_en;

    wire                 ci_fifo_full;
    wire                 ci_fifo_empty;
    wire [CI_FIFO_W-1:0] ci_fifo_dout;
    wire [CI_FIFO_W-1:0] ci_fifo_din;
    wire                 ci_fifo_wr_en;
    wire                 ci_fifo_rd_en;

    function automatic [4:0] calc_tile_format;
        input [2:0] cfg_format;
        input       plane;
        begin
            case (cfg_format)
                FMT_RGBA8888:                  calc_tile_format = 5'd0;
                FMT_RGBA10:                    calc_tile_format = 5'd1;
                FMT_YUV420_8,  FMT_YUV422_8:   calc_tile_format = plane ? 5'd8  : 5'd9;
                FMT_YUV420_10, FMT_YUV422_10:  calc_tile_format = plane ? 5'd14 : 5'd15;
                default:                       calc_tile_format = 5'd0;
            endcase
        end
    endfunction

    function automatic [15:0] ceil_div_u16;
        input [15:0] dividend;
        input [15:0] divisor;
        begin
            if (divisor == 16'd0)
                ceil_div_u16 = 16'd0;
            else
                ceil_div_u16 = (dividend + divisor - 16'd1) / divisor;
        end
    endfunction

    wire [4:0] line_tile_format = calc_tile_format(i_cfg_format, line_plane);
    wire [15:0] tile_h_u16 = {12'd0, i_cfg_tile_h};
    wire [15:0] active_width_px =
        (i_cfg_active_width  != 16'd0) ? i_cfg_active_width  : i_cfg_width;
    wire [15:0] active_height_px =
        (i_cfg_active_height != 16'd0) ? i_cfg_active_height : i_cfg_height;
    wire        line_is_yuv420 =
        (line_tile_format == 5'd8)  || (line_tile_format == 5'd9) ||
        (line_tile_format == 5'd14) || (line_tile_format == 5'd15);
    wire        line_is_uv_plane =
        (line_tile_format == 5'd9)  || (line_tile_format == 5'd11) ||
        (line_tile_format == 5'd13) || (line_tile_format == 5'd15);
    wire [15:0] plane_active_height_px =
        (line_is_yuv420 && line_is_uv_plane) ? ((active_height_px + 16'd1) >> 1) : active_height_px;
    wire [15:0] active_tile_cols =
        ceil_div_u16(active_width_px, i_cfg_tile_w);
    wire [15:0] active_tile_rows =
        ceil_div_u16(plane_active_height_px, tile_h_u16);
    wire        active_width_partial =
        (i_cfg_tile_w != 16'd0) && ((active_width_px % i_cfg_tile_w) != 16'd0);
    wire        active_height_partial =
        (tile_h_u16 != 16'd0) && ((plane_active_height_px % tile_h_u16) != 16'd0);
    wire        partial_right_tile =
        active_width_partial &&
        (active_tile_cols != 16'd0) &&
        (line_tile_x == active_tile_cols - 16'd1);
    wire        partial_bottom_tile =
        active_height_partial &&
        (active_tile_rows != 16'd0) &&
        (line_tile_y == active_tile_rows - 16'd1);
    wire        line_tile_forced_pcm = partial_right_tile || partial_bottom_tile;
    wire       data_push_ready  = !data_fifo_full;
    wire       ci_push_ready    = !ci_fifo_full;
    wire       line_tile_fire   = line_tile_vld && line_tile_rdy;
    wire       pack_first_fire  = line_tile_fire && !half_valid_r;
    wire       pack_second_fire = line_tile_fire && half_valid_r && !half_last_r && data_push_ready;
    wire       pack_in_ready    = !half_valid_r || (!half_last_r && data_push_ready);
    wire       flush_half_only  = half_valid_r && half_last_r && data_push_ready;
    wire       ci_push_needed   = tile_first_word_r;

    assign data_fifo_din   = flush_half_only ?
                             {1'b1, (half_forced_pcm_r ? 32'd0 : {16'd0, half_keep_r}), {128'd0, half_data_r}} :
                             {line_tile_last, (half_forced_pcm_r ? 32'd0 : {line_tile_keep, half_keep_r}), {line_tile_data, half_data_r}};
    assign data_fifo_wr_en = flush_half_only || pack_second_fire;
    assign data_fifo_rd_en = !data_fifo_empty && i_tile_rdy;

    assign ci_fifo_din     = {line_tile_forced_pcm, line_tile_format, line_tile_fcnt, line_tile_y, line_tile_x};
    assign ci_fifo_wr_en   = line_tile_fire && tile_first_word_r;
    assign ci_fifo_rd_en   = !ci_fifo_empty && i_ci_ready;

    assign line_tile_rdy = pack_in_ready && !data_fifo_almost_full && (!ci_push_needed || ci_push_ready);
    assign o_tile_vld    = !data_fifo_empty;
    assign o_ci_valid    = !ci_fifo_empty;
    assign {o_tile_last, o_tile_keep, o_tile_data} = data_fifo_dout;
    assign {o_ci_forced_pcm, o_tile_format, o_tile_fcnt, o_tile_y, o_tile_x} = ci_fifo_dout;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            half_valid_r  <= 1'b0;
            half_data_r   <= 128'd0;
            half_keep_r   <= 16'd0;
            half_last_r   <= 1'b0;
            half_x_r      <= 16'd0;
            half_y_r      <= 16'd0;
            half_fcnt_r   <= 4'd0;
            half_format_r <= 5'd0;
            half_forced_pcm_r <= 1'b0;
            tile_first_word_r <= 1'b1;
        end else begin
            if (flush_half_only) begin
                half_valid_r  <= 1'b0;
                half_data_r   <= 128'd0;
                half_keep_r   <= 16'd0;
                half_last_r   <= 1'b0;
                half_x_r      <= 16'd0;
                half_y_r      <= 16'd0;
                half_fcnt_r   <= 4'd0;
                half_format_r <= 5'd0;
                half_forced_pcm_r <= 1'b0;
            end

            if (line_tile_fire)
                tile_first_word_r <= line_tile_last;

            if (pack_first_fire) begin
                half_valid_r  <= 1'b1;
                half_data_r   <= line_tile_data;
                half_keep_r   <= line_tile_keep;
                half_last_r   <= line_tile_last;
                half_x_r      <= line_tile_x;
                half_y_r      <= line_tile_y;
                half_fcnt_r   <= line_tile_fcnt;
                half_format_r <= line_tile_format;
                half_forced_pcm_r <= line_tile_forced_pcm;
            end else if (pack_second_fire) begin
                half_valid_r  <= 1'b0;
                half_data_r   <= 128'd0;
                half_keep_r   <= 16'd0;
                half_last_r   <= 1'b0;
                half_x_r      <= 16'd0;
                half_y_r      <= 16'd0;
                half_fcnt_r   <= 4'd0;
                half_format_r <= 5'd0;
                half_forced_pcm_r <= 1'b0;
            end
        end
    end

    sync_fifo_af #(
        .DATA_WIDTH (DATA_FIFO_W),
        .DEPTH      (DATA_FIFO_DEPTH),
        .AF_LEVEL   (DATA_FIFO_AF_LEVEL)
    ) u_data_fifo (
        .clk         (clk),
        .rst_n       (rst_n),
        .wr_en       (data_fifo_wr_en),
        .din         (data_fifo_din),
        .full        (data_fifo_full),
        .almost_full (data_fifo_almost_full),
        .rd_en       (data_fifo_rd_en),
        .dout        (data_fifo_dout),
        .empty       (data_fifo_empty)
    );

    sync_fifo_af #(
        .DATA_WIDTH (CI_FIFO_W),
        .DEPTH      (CI_FIFO_DEPTH),
        .AF_LEVEL   (CI_FIFO_DEPTH-1)
    ) u_ci_fifo (
        .clk         (clk),
        .rst_n       (rst_n),
        .wr_en       (ci_fifo_wr_en),
        .din         (ci_fifo_din),
        .full        (ci_fifo_full),
        .almost_full (),
        .rd_en       (ci_fifo_rd_en),
        .dout        (ci_fifo_dout),
        .empty       (ci_fifo_empty)
    );

    ubwc_enc_otf_data_packer u_otf_data_packer
    (
        .clk                ( clk						),
        .rst_n              ( rst_n						),

        .cfg_format         ( i_cfg_format				),
        .cfg_width          ( i_cfg_width				),
        .cfg_height         ( i_cfg_height				),
        .err_bline          ( o_err_bline				),
        .err_bframe         ( o_err_bframe				),
        .err_fifo_ovf       ( o_err_fifo_ovf			),

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
        .rst_n              ( rst_n						),

        .cfg_format         ( i_cfg_format				),
        .cfg_a_tile_cols    ( i_cfg_a_tile_cols         ),
        .cfg_b_tile_cols    ( i_cfg_b_tile_cols         ),

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
