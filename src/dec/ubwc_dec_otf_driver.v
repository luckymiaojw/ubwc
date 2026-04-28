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
    input  wire           clk_otf,
    input  wire           rst_n,
    input  wire           i_frame_start,
    input  wire [4:0]     cfg_format,
    input  wire [15:0]    cfg_otf_h_total,
    input  wire [15:0]    cfg_otf_h_sync,
    input  wire [15:0]    cfg_otf_h_bp,
    input  wire [15:0]    cfg_otf_h_act,
    input  wire [15:0]    cfg_otf_v_total,
    input  wire [15:0]    cfg_otf_v_sync,
    input  wire [15:0]    cfg_otf_v_bp,
    input  wire [15:0]    cfg_otf_v_act,
    input  wire           i_otf_ready,
    
    input  wire           i_fifo_empty,
    input  wire [255:0]   i_fifo_rdata,
    output wire           o_fifo_rd_en,
    output wire           o_busy,

    output reg            o_otf_vsync, o_otf_hsync, o_otf_de,
    output reg  [127:0]   o_otf_data,
    output reg  [3:0]     o_otf_fcnt,
    output reg  [11:0]    o_otf_lcnt
);

    function [15:0] div_up4_u16;
        input [15:0] value;
        reg [15:0] value_div4;
        begin
            value_div4 = (value + 3) >> 2;
            div_up4_u16 = value_div4;
        end
    endfunction

    wire [15:0] h_total_beats = div_up4_u16(cfg_otf_h_total);
    wire [15:0] h_sync_beats  = div_up4_u16(cfg_otf_h_sync);
    wire [15:0] h_bp_beats    = div_up4_u16(cfg_otf_h_bp);
    wire [15:0] h_act_beats   = div_up4_u16(cfg_otf_h_act);
    wire [15:0] h_act_start   = h_sync_beats + h_bp_beats;
    wire [15:0] h_act_end     = h_act_start + h_act_beats;
    wire [15:0] v_act_start   = cfg_otf_v_sync + cfg_otf_v_bp;
    wire [15:0] v_act_end     = v_act_start + cfg_otf_v_act;

    reg [15:0] h_cnt, v_cnt;
    reg        stream_started;
    wire       frame_start = (i_frame_start == 1'b1);
    wire is_active_line = (v_cnt >= v_act_start) && (v_cnt < v_act_end);
    wire is_hsync       = is_active_line && (h_cnt < h_sync_beats);
    wire is_act         = is_active_line && (h_cnt >= h_act_start) && (h_cnt < h_act_end);
    wire [15:0] active_line_raw = v_cnt - v_act_start;
    wire [11:0] active_line = (v_cnt >= v_act_start) ?
                              ((|active_line_raw[15:12]) ? 12'hfff : active_line_raw[11:0]) :
                              12'd0;
    // Match the YUV420 table where the first active line uses the ODD layout
    // without chroma bytes, and the second active line uses the EVEN layout.
    wire line_has_uv = active_line[0];
    wire is_rgba = (cfg_format == 5'b00000) || (cfg_format == 5'b00001);
    wire is_yuv420_10 = (cfg_format == 5'b00011);
    reg [1:0] phase;
    wire active_data_stall = stream_started && is_act && i_otf_ready &&
                             (phase == 2'd0) && i_fifo_empty;

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 0; v_cnt <= 0; o_otf_fcnt <= 0; o_otf_lcnt <= 0;
            stream_started <= 1'b0;
            o_otf_vsync <= 0; o_otf_hsync <= 0; o_otf_de <= 0;
        end else if (frame_start) begin
            h_cnt <= 0; v_cnt <= 0; o_otf_lcnt <= 0;
            stream_started <= 1'b0;
            o_otf_vsync <= 1'b0; o_otf_hsync <= 1'b0; o_otf_de <= 1'b0;
        end else if (!stream_started) begin
            h_cnt <= 0;
            v_cnt <= 0;
            o_otf_lcnt <= 0;
            o_otf_vsync <= 1'b0;
            o_otf_hsync <= 1'b0;
            o_otf_de <= 1'b0;
            if (!i_fifo_empty) begin
                stream_started <= 1'b1;
            end
        end else if (active_data_stall) begin
            o_otf_hsync <= is_hsync;
            o_otf_vsync <= (v_cnt < cfg_otf_v_sync);
            o_otf_de    <= 1'b0;
            o_otf_lcnt  <= active_line;
        end else if (i_otf_ready) begin
            if (h_cnt == h_total_beats - 1'b1) begin
                h_cnt <= 0;
                if (v_cnt == cfg_otf_v_total - 1'b1) begin
                    v_cnt <= 0;
                    o_otf_fcnt <= o_otf_fcnt + 1;
                    // Stop after one full timing frame. The next frame must be
                    // re-armed explicitly by a new frame start / payload fill.
                    stream_started <= 1'b0;
                end else begin
                    v_cnt <= v_cnt + 1;
                end
            end else h_cnt <= h_cnt + 1;

            o_otf_hsync <= is_hsync;
            o_otf_vsync <= (v_cnt < cfg_otf_v_sync);
            o_otf_de <= is_act;
            o_otf_lcnt  <= active_line;
        end
    end

    reg [255:0] compact_data;
    wire phase_busy = (phase != 2'd0);
    wire fifo_busy = !i_fifo_empty;
    wire stream_busy = stream_started;
    wire need_data = stream_started && is_act && i_otf_ready && (phase == 0);
    assign o_fifo_rd_en = need_data && !i_fifo_empty;

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 0;
            compact_data <= 0;
        end else if (frame_start) begin
            phase <= 0;
            compact_data <= 0;
        end else if (!stream_started) begin
            phase <= 0;
            compact_data <= 0;
        end else if (!is_act) begin
            phase <= 0;
        end else if (i_otf_ready) begin
            if (is_rgba || is_yuv420_10) begin
                if (phase == 0) begin
                    if (!i_fifo_empty) begin
                        compact_data <= i_fifo_rdata;
                        phase <= 2'd1;
                    end
                end else begin
                    phase <= 2'd0;
                end
            end else begin
                if (phase == 0) begin
                    if (!i_fifo_empty) begin
                        compact_data <= i_fifo_rdata;
                        phase <= phase + 1'b1;
                    end
                end else begin
                    if (phase == 2'd3) phase <= 2'd0;
                    else phase <= phase + 1'b1;
                end
            end
        end
    end

    assign o_busy = stream_busy | fifo_busy | phase_busy;

    wire [1:0]  phase_out = phase - 2'd1;
    reg  [31:0] cur_y;
    reg  [31:0] cur_u;
    wire [7:0] Y0=cur_y[7:0], Y1=cur_y[15:8], Y2=cur_y[23:16], Y3=cur_y[31:24];
    wire [7:0] U0=cur_u[7:0], V0=cur_u[15:8], U1=cur_u[23:16], V1=cur_u[31:24];
    wire [9:0] Y0_10 = (phase == 2'd1) ? compact_data[15:6]    : compact_data[79:70];
    wire [9:0] Y1_10 = (phase == 2'd1) ? compact_data[31:22]   : compact_data[95:86];
    wire [9:0] Y2_10 = (phase == 2'd1) ? compact_data[47:38]   : compact_data[111:102];
    wire [9:0] Y3_10 = (phase == 2'd1) ? compact_data[63:54]   : compact_data[127:118];
    wire [9:0] U0_10 = (phase == 2'd1) ? compact_data[143:134] : compact_data[207:198];
    wire [9:0] V0_10 = (phase == 2'd1) ? compact_data[159:150] : compact_data[223:214];
    wire [9:0] U1_10 = (phase == 2'd1) ? compact_data[175:166] : compact_data[239:230];
    wire [9:0] V1_10 = (phase == 2'd1) ? compact_data[191:182] : compact_data[255:246];

    always @(*) begin
        cur_y = 32'd0;
        cur_u = 32'd0;
        if (!is_yuv420_10) begin
            case (phase_out)
                2'd0: begin
                    cur_y = compact_data[31:0];
                    cur_u = compact_data[159:128];
                end
                2'd1: begin
                    cur_y = compact_data[63:32];
                    cur_u = compact_data[191:160];
                end
                2'd2: begin
                    cur_y = compact_data[95:64];
                    cur_u = compact_data[223:192];
                end
                default: begin
                    cur_y = compact_data[127:96];
                    cur_u = compact_data[255:224];
                end
            endcase
        end
    end

    always @(*) begin
        o_otf_data = 128'h0;
        if (o_otf_de) begin
            case (cfg_format)
                5'b00000, 5'b00001: o_otf_data = phase[0] ? compact_data[127:0] : compact_data[255:128];
                5'b00011: begin // YUV420 10-bit packed
                    o_otf_data[19:10]    = Y0_10;
                    o_otf_data[51:42]    = Y1_10;
                    o_otf_data[83:74]    = Y2_10;
                    o_otf_data[115:106]  = Y3_10;
                    if (line_has_uv) begin
                        o_otf_data[9:0]   = V0_10;
                        o_otf_data[29:20] = U0_10;
                        o_otf_data[73:64] = V1_10;
                        o_otf_data[93:84] = U1_10;
                    end
                end
                5'b00010,
                5'b01000, 5'b01001, 5'b01110, 5'b01111: begin // YUV420
                    o_otf_data[15:8]   = Y0;
                    o_otf_data[47:40]  = Y1;
                    o_otf_data[79:72]  = Y2;
                    o_otf_data[111:104]= Y3;
                    if (line_has_uv) begin
                        o_otf_data[7:0]   = V0;
                        o_otf_data[23:16] = U0;
                        o_otf_data[71:64] = V1;
                        o_otf_data[87:80] = U1;
                    end
                end
                5'b00100, 5'b00101,
                5'b01010, 5'b01011, 5'b01100, 5'b01101: begin // YUV422
                    o_otf_data[7:0]    = V0;
                    o_otf_data[15:8]   = Y0;
                    o_otf_data[23:16]  = U0;
                    o_otf_data[39:32]  = V0;
                    o_otf_data[47:40]  = Y1;
                    o_otf_data[55:48]  = U0;
                    o_otf_data[71:64]  = V1;
                    o_otf_data[79:72]  = Y2;
                    o_otf_data[87:80]  = U1;
                    o_otf_data[103:96] = V1;
                    o_otf_data[111:104]= Y3;
                    o_otf_data[119:112]= U1;
                end
                default: begin
                    o_otf_data = 128'h0;
                end
            endcase
        end
    end
endmodule
