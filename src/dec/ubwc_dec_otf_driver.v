//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-04-01  23:17:26
// Design Name       :
// Module Name       : ubwc_dec_otf_driver.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							:
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module otf_driver (
    input   wire                                        clk_otf                         ,
    input   wire                                        rst_n                           ,
    input   wire                                        i_frame_start                   ,
    input   wire    [3                      :0]         i_frame_fcnt                    ,
    input   wire    [4                      :0]         cfg_format                      ,
    input   wire    [15                     :0]         cfg_otf_h_total                 ,
    input   wire    [15                     :0]         cfg_otf_h_sync                  ,
    input   wire    [15                     :0]         cfg_otf_h_bp                    ,
    input   wire    [15                     :0]         cfg_otf_h_act                   ,
    input   wire    [15                     :0]         cfg_otf_v_total                 ,
    input   wire    [15                     :0]         cfg_otf_v_sync                  ,
    input   wire    [15                     :0]         cfg_otf_v_bp                    ,
    input   wire    [15                     :0]         cfg_otf_v_act                   ,
    input   wire                                        i_otf_ready                     ,

    input   wire                                        i_fifo_empty0                   ,
    input   wire    [255                    :0]         i_fifo_rdata0                   ,
    output  wire                                        o_fifo_rd_en0                   ,
    output  wire                                        o_busy                          ,
    output  wire    [3                      :0]         o_active_fcnt                   ,
    output  reg                                         o_frame_done_pulse              ,
    output  reg                                         o_correct_irq_pulse             ,
    output  reg     [31                     :0]         o_otf_line_count                ,
    output  reg     [31                     :0]         o_otf_de_count                  ,

    output  reg                                         o_otf_vsync                     ,
    output  reg                                         o_otf_hsync                     ,
    output  reg                                         o_otf_de                        ,
    output  reg     [127                    :0]         o_otf_data                      ,
    output  reg     [3                      :0]         o_otf_fcnt                      ,
    output  reg     [11                     :0]         o_otf_lcnt
);

    wire        [15                     :0]         h_total_beats                   ;
    wire        [15                     :0]         h_sync_beats                    ;
    wire        [15                     :0]         h_bp_beats                      ;
    wire        [15                     :0]         h_act_beats                     ;
    wire        [15                     :0]         h_act_start                     ;
    wire        [15                     :0]         h_act_end                       ;
    wire        [15                     :0]         v_act_start                     ;
    wire        [15                     :0]         v_act_end                       ;
    wire                                            frame_start                     ;
    wire                                            is_active_line                  ;
    wire                                            is_hsync                        ;
    wire                                            is_act                          ;
    wire        [15                     :0]         active_line_raw                 ;
    wire                                            otf_line_fire                   ;
    wire                                            otf_de_fire                     ;
    wire                                            otf_last_active_col             ;
    wire                                            otf_last_active_row             ;
    wire                                            otf_last_de_fire                ;
    wire        [11                     :0]         active_line                     ;
    wire                                            line_has_uv                     ;
    wire                                            is_rgba                         ;
    wire                                            is_yuv420_10                    ;
    wire                                            fifo_empty_sel                  ;
    wire        [255                    :0]         fifo_rdata_sel                  ;
    wire                                            active_data_stall               ;
    wire                                            h_last                          ;
    wire                                            v_last                          ;
    wire                                            frame_start_idle                ;
    wire                                            stream_wait_start               ;
    wire                                            otf_step_fire                   ;
    wire                                            otf_frame_end_fire              ;
    wire                                            otf_output_update               ;
    wire                                            phase_busy                      ;
    wire                                            fifo_busy                       ;
    wire                                            stream_busy                     ;
    wire                                            need_data                       ;
    wire        [1                      :0]         phase_out                       ;
    wire        [9                      :0]         Y0_10                           ;
    wire        [9                      :0]         Y1_10                           ;
    wire        [9                      :0]         Y2_10                           ;
    wire        [9                      :0]         Y3_10                           ;
    wire        [9                      :0]         U0_10                           ;
    wire        [9                      :0]         V0_10                           ;
    wire        [9                      :0]         U1_10                           ;
    wire        [9                      :0]         V1_10                           ;
    wire        [7                      :0]         Y0                              ;
    wire        [7                      :0]         Y1                              ;
    wire        [7                      :0]         Y2                              ;
    wire        [7                      :0]         Y3                              ;
    wire        [7                      :0]         U0                              ;
    wire        [7                      :0]         V0                              ;
    wire        [7                      :0]         U1                              ;
    wire        [7                      :0]         V1                              ;

    reg         [15                     :0]         h_cnt                           ;
    reg         [15                     :0]         v_cnt                           ;
    reg                                             stream_started                  ;
    reg         [3                      :0]         pending_frame_fcnt              ;
    reg                                             frame_done_pulse_core           ;
    reg                                             correct_irq_pulse_core          ;
    reg                                             otf_vsync_core                  ;
    reg                                             otf_hsync_core                  ;
    reg                                             otf_de_core                     ;
    reg         [3                      :0]         otf_fcnt_core                   ;
    reg         [11                     :0]         otf_lcnt_core                   ;
    reg         [127                    :0]         otf_data_comb                   ;
    reg         [1                      :0]         phase                           ;
    reg         [255                    :0]         compact_data                    ;
    reg         [31                     :0]         cur_y                           ;
    reg         [31                     :0]         cur_u                           ;

    function [15                     :0] div_up4_u16;
        input   [15                     :0]         value                           ;
        reg         [15                     :0]         value_div4                      ;
        begin
            value_div4 = (value + 3) >> 2;
            div_up4_u16 = value_div4;
        end
    endfunction

    // Match the YUV420 table where the first active line uses the ODD layout
    // without chroma bytes, and the second active line uses the EVEN layout.

    assign h_total_beats              = div_up4_u16(cfg_otf_h_total);
    assign h_sync_beats               = div_up4_u16(cfg_otf_h_sync);
    assign h_bp_beats                 = div_up4_u16(cfg_otf_h_bp);
    assign h_act_beats                = div_up4_u16(cfg_otf_h_act);
    assign h_act_start                = h_sync_beats + h_bp_beats;
    assign h_act_end                  = h_act_start + h_act_beats;
    assign v_act_start                = cfg_otf_v_sync + cfg_otf_v_bp;
    assign v_act_end                  = v_act_start + cfg_otf_v_act;
    assign frame_start                = (i_frame_start == 1'b1);
    assign is_active_line             = (v_cnt >= v_act_start) && (v_cnt < v_act_end);
    assign is_hsync                   = is_active_line && (h_cnt < h_sync_beats);
    assign is_act                     = is_active_line && (h_cnt >= h_act_start) && (h_cnt < h_act_end);
    assign active_line_raw            = v_cnt - v_act_start;
    assign otf_line_fire              = stream_started && i_otf_ready && is_active_line && (h_cnt == 16'd0);
    assign otf_de_fire                = stream_started && i_otf_ready && is_act;
    assign otf_last_active_col        = (h_act_beats != 16'd0) &&
                                        (h_cnt == (h_act_end - 16'd1));
    assign otf_last_active_row        = (cfg_otf_v_act != 16'd0) &&
                                        (active_line_raw == (cfg_otf_v_act - 16'd1));
    assign otf_last_de_fire           = otf_step_fire && is_act &&
                                        otf_last_active_col &&
                                        otf_last_active_row;
    assign active_line                = (v_cnt >= v_act_start) ?
                                        ((|active_line_raw[15:12]) ? 12'hfff : active_line_raw[11:0]) :
                                                                 12'd0;
    assign line_has_uv                = active_line[0];
    assign is_rgba                    = (cfg_format == 5'b00000) || (cfg_format == 5'b00001);
    assign is_yuv420_10               = (cfg_format == 5'b00011);
    assign fifo_empty_sel             = i_fifo_empty0;
    assign fifo_rdata_sel             = i_fifo_rdata0;
    assign active_data_stall          = stream_started && is_act && i_otf_ready &&
                                        (phase == 2'd0) && fifo_empty_sel;
    assign h_last                     = (h_cnt == (h_total_beats - 16'd1));
    assign v_last                     = (v_cnt == (cfg_otf_v_total - 16'd1));
    assign frame_start_idle           = frame_start && !stream_started;
    assign stream_wait_start          = !stream_started && !frame_start;
    assign otf_step_fire              = stream_started && !active_data_stall && i_otf_ready;
    assign otf_frame_end_fire         = otf_step_fire && h_last && v_last;
    assign otf_output_update          = i_otf_ready;
    assign phase_busy                 = (phase != 2'd0);
    assign fifo_busy                  = !i_fifo_empty0;
    assign stream_busy                = stream_started;
    assign need_data                  = stream_started && is_act && i_otf_ready && (phase == 0);
    assign o_fifo_rd_en0              = need_data && !i_fifo_empty0;
    assign o_active_fcnt              = stream_started ? otf_fcnt_core : pending_frame_fcnt;
    assign o_busy                     = stream_busy | fifo_busy | phase_busy;
    assign phase_out                  = phase - 2'd1;
    assign Y0                         = cur_y[7:0];
    assign Y1                         = cur_y[15:8];
    assign Y2                         = cur_y[23:16];
    assign Y3                         = cur_y[31:24];
    assign U0                         = cur_u[7:0];
    assign V0                         = cur_u[15:8];
    assign U1                         = cur_u[23:16];
    assign V1                         = cur_u[31:24];
    assign Y0_10                      = (phase == 2'd1) ? compact_data[15:6]    : compact_data[79:70];
    assign Y1_10                      = (phase == 2'd1) ? compact_data[31:22]   : compact_data[95:86];
    assign Y2_10                      = (phase == 2'd1) ? compact_data[47:38]   : compact_data[111:102];
    assign Y3_10                      = (phase == 2'd1) ? compact_data[63:54]   : compact_data[127:118];
    assign U0_10                      = (phase == 2'd1) ? compact_data[143:134] : compact_data[207:198];
    assign V0_10                      = (phase == 2'd1) ? compact_data[159:150] : compact_data[223:214];
    assign U1_10                      = (phase == 2'd1) ? compact_data[175:166] : compact_data[239:230];
    assign V1_10                      = (phase == 2'd1) ? compact_data[191:182] : compact_data[255:246];

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            h_cnt <= 16'd0;
        else if (frame_start_idle || !stream_started)
            h_cnt <= 16'd0;
        else if (otf_step_fire)
            h_cnt <= h_last ? 16'd0 : (h_cnt + 16'd1);
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            v_cnt <= 16'd0;
        else if (frame_start_idle || !stream_started)
            v_cnt <= 16'd0;
        else if (otf_step_fire && h_last)
            v_cnt <= v_last ? 16'd0 : (v_cnt + 16'd1);
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            pending_frame_fcnt <= 4'd0;
        else if (frame_start)
            pending_frame_fcnt <= i_frame_fcnt;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            stream_started <= 1'b0;
        else if (stream_wait_start && !fifo_empty_sel)
            stream_started <= 1'b1;
        else if (otf_frame_end_fire)
            stream_started <= 1'b0;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            frame_done_pulse_core <= 1'b0;
        else
            frame_done_pulse_core <= otf_last_de_fire;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            correct_irq_pulse_core <= 1'b0;
        else
            correct_irq_pulse_core <= otf_last_de_fire;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            o_otf_line_count <= 32'd0;
        else if (frame_start_idle)
            o_otf_line_count <= 32'd0;
        else if (otf_step_fire && otf_line_fire)
            o_otf_line_count <= o_otf_line_count + 1'b1;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            o_otf_de_count <= 32'd0;
        else if (frame_start_idle)
            o_otf_de_count <= 32'd0;
        else if (otf_step_fire && otf_de_fire)
            o_otf_de_count <= o_otf_de_count + 1'b1;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            otf_vsync_core <= 1'b0;
        else if (frame_start_idle || !stream_started)
            otf_vsync_core <= 1'b0;
        else if (active_data_stall || otf_step_fire)
            otf_vsync_core <= (v_cnt < cfg_otf_v_sync);
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            otf_hsync_core <= 1'b0;
        else if (frame_start_idle || !stream_started)
            otf_hsync_core <= 1'b0;
        else if (active_data_stall || otf_step_fire)
            otf_hsync_core <= is_hsync;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            otf_de_core <= 1'b0;
        else if (frame_start_idle || !stream_started || active_data_stall)
            otf_de_core <= 1'b0;
        else if (otf_step_fire)
            otf_de_core <= is_act;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            otf_fcnt_core <= 4'd0;
        else if (frame_start_idle)
            otf_fcnt_core <= i_frame_fcnt;
        else if (stream_wait_start && !fifo_empty_sel)
            otf_fcnt_core <= pending_frame_fcnt;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            otf_lcnt_core <= 12'd0;
        else if (frame_start_idle || !stream_started)
            otf_lcnt_core <= 12'd0;
        else if (active_data_stall || otf_step_fire)
            otf_lcnt_core <= active_line;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            phase <= 2'd0;
        else if (frame_start_idle || !stream_started || !is_act)
            phase <= 2'd0;
        else if (i_otf_ready && (is_rgba || is_yuv420_10)) begin
            if ((phase == 2'd0) && !fifo_empty_sel)
                phase <= 2'd1;
            else if (phase != 2'd0)
                phase <= 2'd0;
        end else if (i_otf_ready) begin
            if ((phase == 2'd0) && !fifo_empty_sel)
                phase <= phase + 1'b1;
            else if (phase == 2'd3)
                phase <= 2'd0;
            else if (phase != 2'd0)
                phase <= phase + 1'b1;
        end
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            compact_data <= 256'd0;
        else if (frame_start_idle || !stream_started)
            compact_data <= 256'd0;
        else if (i_otf_ready && is_act && (phase == 2'd0) && !fifo_empty_sel)
            compact_data <= fifo_rdata_sel;
    end

    always @(*) begin
        cur_y = 32'd0;
        if (!is_yuv420_10) begin
            case (phase_out)
                2'd0: cur_y = compact_data[31:0];
                2'd1: cur_y = compact_data[63:32];
                2'd2: cur_y = compact_data[95:64];
                default: cur_y = compact_data[127:96];
            endcase
        end
    end

    always @(*) begin
        cur_u = 32'd0;
        if (!is_yuv420_10) begin
            case (phase_out)
                2'd0: cur_u = compact_data[159:128];
                2'd1: cur_u = compact_data[191:160];
                2'd2: cur_u = compact_data[223:192];
                default: cur_u = compact_data[255:224];
            endcase
        end
    end

    always @(*) begin
        otf_data_comb = 128'h0;
        if (otf_de_core) begin
            case (cfg_format)
                5'b00000, 5'b00001: otf_data_comb = phase[0] ? compact_data[127:0] : compact_data[255:128];
                5'b00011: begin // YUV420 10-bit packed
                    otf_data_comb[19:10]    = Y0_10;
                    otf_data_comb[51:42]    = Y1_10;
                    otf_data_comb[83:74]    = Y2_10;
                    otf_data_comb[115:106]  = Y3_10;
                    if (line_has_uv) begin
                        otf_data_comb[9:0]   = V0_10;
                        otf_data_comb[29:20] = U0_10;
                        otf_data_comb[73:64] = V1_10;
                        otf_data_comb[93:84] = U1_10;
                    end
                end
                5'b00010,
                5'b01000, 5'b01001, 5'b01110, 5'b01111: begin // YUV420
                    otf_data_comb[15:8]    = Y0;
                    otf_data_comb[47:40]   = Y1;
                    otf_data_comb[79:72]   = Y2;
                    otf_data_comb[111:104] = Y3;
                    if (line_has_uv) begin
                        otf_data_comb[7:0]   = V0;
                        otf_data_comb[23:16] = U0;
                        otf_data_comb[71:64] = V1;
                        otf_data_comb[87:80] = U1;
                    end
                end
                default: begin
                    otf_data_comb = 128'h0;
                end
            endcase
        end
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            o_frame_done_pulse <= 1'b0;
        else
            o_frame_done_pulse <= frame_done_pulse_core;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            o_correct_irq_pulse <= 1'b0;
        else
            o_correct_irq_pulse <= correct_irq_pulse_core;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            o_otf_vsync <= 1'b0;
        else if (otf_output_update)
            o_otf_vsync <= otf_vsync_core;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            o_otf_hsync <= 1'b0;
        else if (otf_output_update)
            o_otf_hsync <= otf_hsync_core;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            o_otf_de <= 1'b0;
        else if (otf_output_update)
            o_otf_de <= otf_de_core;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            o_otf_data <= 128'd0;
        else if (otf_output_update)
            o_otf_data <= otf_data_comb;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            o_otf_fcnt <= 4'd0;
        else if (otf_output_update)
            o_otf_fcnt <= otf_fcnt_core;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n)
            o_otf_lcnt <= 12'd0;
        else if (otf_output_update)
            o_otf_lcnt <= otf_lcnt_core;
    end
endmodule
