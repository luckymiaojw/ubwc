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
        input   wire                                        i_otf_clk                       ,
        input   wire                                        i_clk                           ,
        input   wire                                        rst_n_sys                       ,
        input   wire                                        rst_n_otf                       ,

        // static config
        input   wire    [2                      :0]         cfg_format                      ,
        input   wire    [15                     :0]         cfg_width                       ,
        input   wire    [15                     :0]         cfg_height                      ,

        // error flags
        output  wire                                        err_bline                       ,
        output  wire                                        err_bframe                      ,
        output  wire                                        err_fifo_ovf                    ,
        input   wire                                        err_clear                       ,

        // OTF input
        input   wire                                        otf_vsync                       ,
        input   wire                                        otf_hsync                       ,
        input   wire                                        otf_de                          ,
        input   wire    [127                    :0]         otf_data                        ,
        input   wire    [3                      :0]         otf_fcnt                        ,
        input   wire    [11                     :0]         otf_lcnt                        ,
        output  wire                                        otf_ready                       ,

        // FIFO A output
        output  wire                                        fifo_a_vld                      ,
        input   wire                                        fifo_a_rdy                      ,
        output  wire    [162                    :0]         fifo_a_data                     ,

        // FIFO B output
        output  wire                                        fifo_b_vld                      ,
        input   wire                                        fifo_b_rdy                      ,
        output  wire    [162                    :0]         fifo_b_data
    );

    localparam                                      FMT_RGBA8888                    = 3'd0;
    localparam                                      FMT_RGBA10                      = 3'd1;
    localparam                                      FMT_YUV420_8                    = 3'd2;
    localparam                                      FMT_YUV420_10                   = 3'd3;

    wire                                            is_rgba                         ;
    wire                                            is_yuv_8                        ;
    wire                                            is_yuv_10                       ;
    wire                                            need_b                          ;
    wire                                            format_supported                ;
    wire                                            vsync_rising                    ;
    wire                                            hsync_rising                    ;
    wire                                            in_fifo_full                    ;
    wire                                            otf_fire                        ;
    wire                                            in_fifo_wr_en                   ;
    wire                                            locked_lcnt_load_vsync          ;
    wire                                            locked_lcnt_load_hsync          ;
    wire        [11                     :0]         locked_lcnt_hsync_value         ;
    wire                                            line_cnt_clear                  ;
    wire                                            line_cnt_inc                    ;
    wire                                            pixel_cnt_clear                 ;
    wire                                            pixel_cnt_inc                   ;
    wire                                            otf_stall                       ;
    wire        [146                    :0]         otf_stall_sig                   ;
    wire                                            otf_stall_sig_changed           ;
    wire                                            err_bline_set_otf               ;
    wire                                            err_bframe_set_otf              ;
    wire                                            err_fifo_ovf_set_otf            ;
    wire                                            err_clear_otf                   ;
    wire                                            err_bline_new_otf               ;
    wire                                            err_bframe_new_otf              ;
    wire                                            err_fifo_ovf_new_otf            ;
    wire                                            err_bline_event_sys             ;
    wire                                            err_bframe_event_sys            ;
    wire                                            err_fifo_ovf_event_sys          ;
    wire        [15                     :0]         effective_pixel_cnt             ;
    wire                                            otf_last_beat                   ;
    wire                                            din_vsync                       ;
    wire                                            din_hsync                       ;
    wire        [3                      :0]         din_fcnt                        ;
    wire        [11                     :0]         din_lcnt                        ;
    wire                                            in_fifo_empty                   ;
    wire                                            in_fifo_rd                      ;
    wire        [146                    :0]         in_fifo_din                     ;
    wire        [146                    :0]         in_fifo_dout                    ;
    wire                                            inf_last_beat                   ;
    wire        [17                     :0]         inf_sideband                    ;
    wire        [11                     :0]         inf_lcnt                        ;
    wire        [127                    :0]         inf_data                        ;
    wire                                            is_odd_line                     ;
    wire                                            fifo_a_empty                    ;
    wire                                            fifo_b_empty                    ;
    wire                                            fifo_a_rd_en                    ;
    wire                                            fifo_b_rd_en                    ;
    wire                                            out_fifo_a_afull                ;
    wire                                            out_fifo_b_afull                ;
    wire                                            pipe_stall                      ;
    wire        [127                    :0]         ext_a_data128                   ;
    wire        [31                     :0]         ext_a_data32                    ;
    wire        [63                     :0]         ext_a_data64                    ;
    wire                                            ext_a_vld_128                   ;
    wire                                            ext_a_vld_32                    ;
    wire                                            ext_a_vld_64                    ;
    wire        [31                     :0]         ext_b_data32                    ;
    wire        [63                     :0]         ext_b_data64                    ;
    wire                                            ext_b_vld_32                    ;
    wire                                            ext_b_vld_64                    ;
    wire                                            a_take_128                      ;
    wire                                            a_take_32                       ;
    wire                                            a_take_64                       ;
    wire                                            a_pack32_full                   ;
    wire                                            a_pack32_flush                  ;
    wire                                            a_pack64_full                   ;
    wire                                            a_pack64_flush                  ;
    wire                                            a_out_fifo_wr_next              ;
    wire                                            a_pack32_done                   ;
    wire                                            a_pack64_done                   ;
    wire        [17                     :0]         a_pack32_sb_out                 ;
    wire        [17                     :0]         a_pack64_sb_out                 ;
    wire                                            b_take_32                       ;
    wire                                            b_take_64                       ;
    wire                                            b_pack32_full                   ;
    wire                                            b_pack32_flush                  ;
    wire                                            b_pack64_full                   ;
    wire                                            b_pack64_flush                  ;
    wire                                            b_out_fifo_wr_next              ;
    wire                                            b_pack32_done                   ;
    wire                                            b_pack64_done                   ;
    wire        [17                     :0]         b_pack32_sb_out                 ;
    wire        [17                     :0]         b_pack64_sb_out                 ;

    reg                                             otf_vsync_d1                    ;
    reg                                             otf_hsync_d1                    ;
    reg         [3                      :0]         locked_fcnt                     ;
    reg         [11                     :0]         locked_lcnt                     ;
    reg         [15                     :0]         pixel_cnt_in                    ;
    reg         [15                     :0]         line_cnt_in                     ;
    reg                                             err_bline_pending_otf           ;
    reg                                             err_bframe_pending_otf          ;
    reg                                             err_fifo_ovf_pending_otf        ;
    reg                                             otf_stall_hold_valid            ;
    reg         [146                    :0]         otf_stall_hold_sig              ;
    reg                                             err_bline_toggle_otf            ;
    reg                                             err_bframe_toggle_otf           ;
    reg                                             err_fifo_ovf_toggle_otf         ;
    reg                                             err_clear_toggle_sys            ;
    reg                                             err_clear_otf_ff3               ;
    reg                                             err_bline_sys_ff3               ;
    reg                                             err_bframe_sys_ff3              ;
    reg                                             err_fifo_ovf_sys_ff3            ;
    reg                                             err_bline_sticky_sys            ;
    reg                                             err_bframe_sticky_sys           ;
    reg                                             err_fifo_ovf_sticky_sys         ;
    reg                                             sticky_vsync                    ;
    reg                                             sticky_hsync                    ;
    reg                                             out_fifo_a_wr                   ;
    reg                                             out_fifo_b_wr                   ;
    reg         [162                    :0]         out_fifo_a_din                  ;
    reg         [162                    :0]         out_fifo_b_din                  ;
    reg         [127                    :0]         a_pack32_data                   ;
    reg         [127                    :0]         a_pack64_data                   ;
    reg         [1                      :0]         a_pack32_cnt                    ;
    reg                                             a_pack64_cnt                    ;
    reg         [17                     :0]         a_pack32_sb                     ;
    reg         [17                     :0]         a_pack64_sb                     ;
    reg         [127                    :0]         b_pack32_data                   ;
    reg         [127                    :0]         b_pack64_data                   ;
    reg         [1                      :0]         b_pack32_cnt                    ;
    reg                                             b_pack64_cnt                    ;
    reg         [17                     :0]         b_pack32_sb                     ;
    reg         [17                     :0]         b_pack64_sb                     ;

    (* async_reg = "true" *) reg                                         err_clear_otf_ff1               ;
    (* async_reg = "true" *) reg                                         err_clear_otf_ff2               ;
    (* async_reg = "true" *) reg                                         err_bline_sys_ff1               ;
    (* async_reg = "true" *) reg                                         err_bline_sys_ff2               ;
    (* async_reg = "true" *) reg                                         err_bframe_sys_ff1              ;
    (* async_reg = "true" *) reg                                         err_bframe_sys_ff2              ;
    (* async_reg = "true" *) reg                                         err_fifo_ovf_sys_ff1            ;
    (* async_reg = "true" *) reg                                         err_fifo_ovf_sys_ff2            ;

    assign is_rgba                    = (cfg_format == FMT_RGBA8888) || (cfg_format == FMT_RGBA10);
    assign is_yuv_8                   = (cfg_format == FMT_YUV420_8);
    assign is_yuv_10                  = (cfg_format == FMT_YUV420_10);
    assign need_b                     = is_yuv_8 || is_yuv_10;
    assign format_supported           = is_rgba || need_b;
    assign vsync_rising               = otf_vsync & ~otf_vsync_d1;
    assign hsync_rising               = otf_hsync & ~otf_hsync_d1;
    assign otf_ready                  = format_supported && ~in_fifo_full;
    assign otf_fire                   = otf_de && otf_ready;
    assign in_fifo_wr_en              = otf_fire;
    assign locked_lcnt_load_vsync     = vsync_rising && !hsync_rising;
    assign locked_lcnt_load_hsync     = hsync_rising;
    assign locked_lcnt_hsync_value    = vsync_rising ? 12'd0 : otf_lcnt;
    assign line_cnt_clear             = vsync_rising && !hsync_rising;
    assign line_cnt_inc               = hsync_rising;
    assign pixel_cnt_clear            = hsync_rising;
    assign pixel_cnt_inc              = !hsync_rising && otf_fire;
    assign otf_stall                  = otf_de && !otf_ready;
    assign otf_stall_sig              = {otf_vsync, otf_hsync, otf_de, otf_fcnt, otf_lcnt, otf_data};
    assign otf_stall_sig_changed      = otf_stall_hold_valid &&
                                        otf_stall &&
                                        (otf_stall_sig != otf_stall_hold_sig);
    assign err_bline_set_otf          = hsync_rising && (pixel_cnt_in > 0) &&
                                        (pixel_cnt_in != cfg_width);
    assign err_bframe_set_otf         = vsync_rising && (line_cnt_in > 0) &&
                                        (line_cnt_in != cfg_height);
    assign err_fifo_ovf_set_otf       = otf_stall_sig_changed;
    assign err_clear_otf              = err_clear_otf_ff2 ^ err_clear_otf_ff3;
    assign err_bline_new_otf          = err_bline_set_otf &&
                                        !err_bline_pending_otf &&
                                        !err_clear_otf;
    assign err_bframe_new_otf         = err_bframe_set_otf &&
                                        !err_bframe_pending_otf &&
                                        !err_clear_otf;
    assign err_fifo_ovf_new_otf       = err_fifo_ovf_set_otf &&
                                        !err_fifo_ovf_pending_otf &&
                                        !err_clear_otf;
    assign err_bline_event_sys        = err_bline_sys_ff2 ^ err_bline_sys_ff3;
    assign err_bframe_event_sys       = err_bframe_sys_ff2 ^ err_bframe_sys_ff3;
    assign err_fifo_ovf_event_sys     = err_fifo_ovf_sys_ff2 ^ err_fifo_ovf_sys_ff3;
    assign err_bline                  = err_bline_sticky_sys;
    assign err_bframe                 = err_bframe_sticky_sys;
    assign err_fifo_ovf               = err_fifo_ovf_sticky_sys;
    assign effective_pixel_cnt        = (otf_hsync || hsync_rising) ? 16'd0 : pixel_cnt_in;
    assign otf_last_beat              = (effective_pixel_cnt + 16'd4 >= cfg_width);
    assign din_vsync                  = sticky_vsync | otf_vsync;
    assign din_hsync                  = sticky_hsync | otf_hsync;
    assign din_fcnt                   = otf_vsync ? otf_fcnt : locked_fcnt;
    assign din_lcnt                   = otf_hsync ? otf_lcnt : locked_lcnt;
    assign in_fifo_din                = {otf_last_beat, din_fcnt, din_lcnt, din_vsync, din_hsync, otf_data};
    assign inf_last_beat              = in_fifo_dout[146];
    assign inf_sideband               = in_fifo_dout[145:128];
    assign inf_lcnt                   = in_fifo_dout[141:130];
    assign inf_data                   = in_fifo_dout[127:0];
    assign is_odd_line                = inf_lcnt[0];
    assign fifo_a_rd_en               = fifo_a_vld && fifo_a_rdy;
    assign fifo_b_rd_en               = fifo_b_vld && fifo_b_rdy;
    assign pipe_stall                 = out_fifo_a_afull | (need_b && !is_odd_line && out_fifo_b_afull);
    assign in_fifo_rd                 = !in_fifo_empty && !pipe_stall;
    assign ext_a_data128              = is_rgba ? inf_data : 128'd0;
    assign ext_a_data32               = is_yuv_8 ?
                                                   {inf_data[111:104], inf_data[79:72],
                                                   inf_data[47:40],   inf_data[15:8]} :
                                                   32'd0;
    assign ext_a_data64               = is_yuv_10 ?
                                                    {inf_data[115:106], 6'b0,
                                                    inf_data[83:74],   6'b0,
                                                    inf_data[51:42],   6'b0,
                                                    inf_data[19:10],   6'b0} :
                                                    64'd0;
    assign ext_a_vld_128              = is_rgba;
    assign ext_a_vld_32               = is_yuv_8;
    assign ext_a_vld_64               = is_yuv_10;
    assign ext_b_data32               = (is_yuv_8 && !is_odd_line) ?
                                                                     {inf_data[71:64], inf_data[87:80],
                                                                     inf_data[7:0],   inf_data[23:16]} :
                                                                     32'd0;
    assign ext_b_data64               = (is_yuv_10 && !is_odd_line) ?
                                                                      {inf_data[73:64], 6'b0,
                                                                      inf_data[93:84], 6'b0,
                                                                      inf_data[9:0],   6'b0,
                                                                      inf_data[29:20], 6'b0} :
                                                                      64'd0;
    assign ext_b_vld_32               = is_yuv_8 && !is_odd_line;
    assign ext_b_vld_64               = is_yuv_10 && !is_odd_line;
    assign a_take_128                 = in_fifo_rd && ext_a_vld_128;
    assign a_take_32                  = in_fifo_rd && ext_a_vld_32;
    assign a_take_64                  = in_fifo_rd && ext_a_vld_64;
    assign a_pack32_full              = a_take_32 && (a_pack32_cnt == 2'd3);
    assign a_pack32_flush             = a_take_32 && inf_last_beat && (a_pack32_cnt != 2'd3);
    assign a_pack64_full              = a_take_64 && a_pack64_cnt;
    assign a_pack64_flush             = a_take_64 && inf_last_beat && !a_pack64_cnt;
    assign a_out_fifo_wr_next         = a_take_128 || a_pack32_full ||
                                        a_pack32_flush || a_pack64_full ||
                                        a_pack64_flush;
    assign a_pack32_done              = a_pack32_full || a_pack32_flush;
    assign a_pack64_done              = a_pack64_full || a_pack64_flush;
    assign a_pack32_sb_out            = (a_pack32_cnt == 2'd0) ? inf_sideband : a_pack32_sb;
    assign a_pack64_sb_out            = (a_pack64_cnt == 1'b0) ? inf_sideband : a_pack64_sb;
    assign b_take_32                  = in_fifo_rd && need_b && ext_b_vld_32;
    assign b_take_64                  = in_fifo_rd && need_b && ext_b_vld_64;
    assign b_pack32_full              = b_take_32 && (b_pack32_cnt == 2'd3);
    assign b_pack32_flush             = b_take_32 && inf_last_beat && (b_pack32_cnt != 2'd3);
    assign b_pack64_full              = b_take_64 && b_pack64_cnt;
    assign b_pack64_flush             = b_take_64 && inf_last_beat && !b_pack64_cnt;
    assign b_out_fifo_wr_next         = b_pack32_full || b_pack32_flush ||
                                        b_pack64_full || b_pack64_flush;
    assign b_pack32_done              = b_pack32_full || b_pack32_flush;
    assign b_pack64_done              = b_pack64_full || b_pack64_flush;
    assign b_pack32_sb_out            = (b_pack32_cnt == 2'd0) ? inf_sideband : b_pack32_sb;
    assign b_pack64_sb_out            = (b_pack64_cnt == 1'b0) ? inf_sideband : b_pack64_sb;

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
            otf_stall_hold_valid <= 1'b0;
        else if (!otf_stall)
            otf_stall_hold_valid <= 1'b0;
        else
            otf_stall_hold_valid <= 1'b1;
    end

    always @(posedge i_otf_clk) begin
        if (otf_stall && !otf_stall_hold_valid)
            otf_stall_hold_sig <= otf_stall_sig;
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

    mg_async_fifo
    #(
        .AF                         ( 1                             ),
        .DATA_BITS                  ( 147                           ),
        .DEPTH_BITS                 ( 4                             ),
        .SHOW_AHEAD                 ( 1                             ),
        .RAM_STYLE                  ( "block"                       )
    )
    u_input_fifo
    (
        .wr_clk                     ( i_otf_clk                     ),
        .wr_rstn                    ( rst_n_otf                     ),
        .wr_en                      ( in_fifo_wr_en                 ),
        .din                        ( in_fifo_din                   ),
        .wr_data_count              (                               ),
        .prog_full                  (                               ),
        .full                       ( in_fifo_full                  ),
        .rd_clk                     ( i_clk                         ),
        .rd_rstn                    ( rst_n_sys                     ),
        .rd_en                      ( in_fifo_rd                    ),
        .dout                       ( in_fifo_dout                  ),
        .valid                      (                               ),
        .rd_data_count              (                               ),
        .pre_empty                  (                               ),
        .empty                      ( in_fifo_empty                 )
    );

    mg_sync_fifo
    #(
        .PROG_DEPTH                 ( 4                             ),
        .DWIDTH                     ( 163                           ),
        .DEPTH                      ( 16                            ),
        .SHOW_AHEAD                 ( 1                             )
    )
    u_out_fifo_a
    (
        .clk                        ( i_clk                         ),
        .rst_n                      ( rst_n_sys                     ),
        .wr_en                      ( out_fifo_a_wr                 ),
        .din                        ( out_fifo_a_din                ),
        .prog_full                  ( out_fifo_a_afull              ),
        .full                       (                               ),
        .rd_en                      ( fifo_a_rd_en                  ),
        .empty                      ( fifo_a_empty                  ),
        .dout                       ( fifo_a_data                   ),
        .valid                      ( fifo_a_vld                    ),
        .data_count                 (                               )
    );

    mg_sync_fifo
    #(
        .PROG_DEPTH                 ( 4                             ),
        .DWIDTH                     ( 163                           ),
        .DEPTH                      ( 16                            ),
        .SHOW_AHEAD                 ( 1                             )
    )
    u_out_fifo_b
    (
        .clk                        ( i_clk                         ),
        .rst_n                      ( rst_n_sys                     ),
        .wr_en                      ( out_fifo_b_wr                 ),
        .din                        ( out_fifo_b_din                ),
        .prog_full                  ( out_fifo_b_afull              ),
        .full                       (                               ),
        .rd_en                      ( fifo_b_rd_en                  ),
        .empty                      ( fifo_b_empty                  ),
        .dout                       ( fifo_b_data                   ),
        .valid                      ( fifo_b_vld                    ),
        .data_count                 (                               )
    );

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
