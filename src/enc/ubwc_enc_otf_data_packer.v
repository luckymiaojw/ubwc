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
//      A Channel: RGBA or UV
//      B Channel: Y
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
        output reg          err_bline,
        output reg          err_bframe,
        output reg          err_fifo_ovf,
    
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
    localparam FMT_YUV422_8  = 3'd4;
    localparam FMT_YUV422_10 = 3'd5;

    wire is_rgba   = (cfg_format == FMT_RGBA8888) || (cfg_format == FMT_RGBA10);
    wire is_yuv_8  = (cfg_format == FMT_YUV420_8) || (cfg_format == FMT_YUV422_8);
    wire is_yuv_10 = (cfg_format == FMT_YUV420_10) || (cfg_format == FMT_YUV422_10);
    wire is_yuv422 = (cfg_format == FMT_YUV422_8) || (cfg_format == FMT_YUV422_10);
    wire need_b    = !is_rgba;

    reg  otf_vsync_d1, otf_hsync_d1;
    wire vsync_rising = otf_vsync & ~otf_vsync_d1;
    wire hsync_rising = otf_hsync & ~otf_hsync_d1;

    reg [3:0]  locked_fcnt;
    reg [11:0] locked_lcnt;
    reg [15:0] pixel_cnt_in;
    reg [15:0] line_cnt_in;

    wire in_fifo_full;
    assign otf_ready = ~in_fifo_full;
    wire otf_fire    = otf_de && otf_ready;
    wire in_fifo_wr_en = otf_fire;

    always @(posedge i_otf_clk or negedge rst_n) begin
        if (!rst_n) begin
            otf_vsync_d1 <= 1'b0;
            otf_hsync_d1 <= 1'b0;
            locked_fcnt  <= 4'd0;
            locked_lcnt  <= 12'd0;
            pixel_cnt_in <= 16'd0;
            line_cnt_in  <= 16'd0;
            err_bline    <= 1'b0;
            err_bframe   <= 1'b0;
            err_fifo_ovf <= 1'b0;
        end else begin
            otf_vsync_d1 <= otf_vsync;
            otf_hsync_d1 <= otf_hsync;

            if (vsync_rising) begin
                locked_fcnt  <= otf_fcnt;
                line_cnt_in  <= 16'd0;
                err_bline    <= 1'b0;
                err_bframe   <= 1'b0;
                err_fifo_ovf <= 1'b0;
            end

            if (hsync_rising) begin
                locked_lcnt  <= otf_lcnt;
                pixel_cnt_in <= 16'd0;
                line_cnt_in  <= line_cnt_in + 16'd1;

                if ((pixel_cnt_in > 0) && (pixel_cnt_in < cfg_width))
                    err_bline <= 1'b1;
            end else if (otf_fire) begin
                pixel_cnt_in <= pixel_cnt_in + 16'd4;
            end

            if (vsync_rising && (line_cnt_in > 0) && (line_cnt_in < cfg_height))
                err_bframe <= 1'b1;

            if (otf_de && in_fifo_full)
                err_fifo_ovf <= 1'b1;
        end
    end

    wire [15:0] effective_pixel_cnt = (otf_hsync || hsync_rising) ? 16'd0 : pixel_cnt_in;
    wire otf_last_beat = (effective_pixel_cnt + 16'd4 >= cfg_width);

    reg sticky_vsync, sticky_hsync;
    always @(posedge i_otf_clk or negedge rst_n) begin
        if (!rst_n) begin
            sticky_vsync <= 1'b0;
            sticky_hsync <= 1'b0;
        end else begin
            if (otf_vsync)      sticky_vsync <= 1'b1;
            else if (otf_fire)  sticky_vsync <= 1'b0;

            if (otf_hsync)      sticky_hsync <= 1'b1;
            else if (otf_fire)  sticky_hsync <= 1'b0;
        end
    end

    wire        din_vsync = sticky_vsync | otf_vsync;
    wire        din_hsync = sticky_hsync | otf_hsync;
    wire [3:0]  din_fcnt  = otf_vsync ? otf_fcnt : locked_fcnt;
    wire [11:0] din_lcnt  = otf_hsync ? otf_lcnt : locked_lcnt;

    wire         in_fifo_empty, in_fifo_rd;
    wire [146:0] in_fifo_din, in_fifo_dout;
    assign in_fifo_din = {otf_last_beat, din_fcnt, din_lcnt, din_vsync, din_hsync, otf_data};

    async_fifo_fwft_256w #(
        .DATA_WIDTH(147),
        .ADDR_WIDTH(4),
        .DEPTH(16)
    ) u_input_fifo (
        .wr_clk     (i_otf_clk),
        .wr_rst_n   (rst_n),
        .wr_clr     (1'b0),
        .wr_en      (in_fifo_wr_en),
        .din        (in_fifo_din),
        .full       (in_fifo_full),
        .rd_clk     (i_clk),
        .rd_rst_n   (rst_n),
        .rd_clr     (1'b0),
        .rd_en      (in_fifo_rd),
        .dout       (in_fifo_dout),
        .empty      (in_fifo_empty)
    );

    wire         inf_last_beat = in_fifo_dout[146];
    wire [17:0]  inf_sideband  = in_fifo_dout[145:128];
    wire [11:0]  inf_lcnt      = in_fifo_dout[141:130];
    wire [127:0] inf_data      = in_fifo_dout[127:0];
    wire         is_odd_line   = inf_lcnt[0];

    wire         fifo_a_empty, fifo_b_empty;
    wire         fifo_a_valid, fifo_b_valid;
    reg          out_fifo_a_wr, out_fifo_b_wr;
    reg  [162:0] out_fifo_a_din, out_fifo_b_din;
    wire         out_fifo_a_afull, out_fifo_b_afull;

    mg_sync_fifo #(
        .PROG_DEPTH (4),
        .DWIDTH     (163),
        .DEPTH      (16),
        .SHOW_AHEAD (1)
    ) u_out_fifo_a (
        .clk         (i_clk),
        .rst_n       (rst_n),
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
        .rst_n       (rst_n),
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

    wire pipe_stall = out_fifo_a_afull | (need_b && out_fifo_b_afull);
    assign in_fifo_rd = !in_fifo_empty && !pipe_stall;

    // data extract
    reg [127:0] ext_a_data128;
    reg [31:0]  ext_a_data32;
    reg [63:0]  ext_a_data64;
    reg         ext_a_vld_128, ext_a_vld_32, ext_a_vld_64;

    reg [31:0]  ext_b_data32;
    reg [63:0]  ext_b_data64;
    reg         ext_b_vld_32, ext_b_vld_64;

    always @(*) begin
        ext_a_data128 = 128'd0;
        ext_a_data32  = 32'd0;
        ext_a_data64  = 64'd0;
        ext_a_vld_128 = 1'b0;
        ext_a_vld_32  = 1'b0;
        ext_a_vld_64  = 1'b0;

        ext_b_data32  = 32'd0;
        ext_b_data64  = 64'd0;
        ext_b_vld_32  = 1'b0;
        ext_b_vld_64  = 1'b0;

        if (is_rgba) begin
            ext_a_data128 = inf_data;
            ext_a_vld_128 = 1'b1;
        end else if (is_yuv_8) begin
            ext_b_data32 = {inf_data[111:104], inf_data[79:72], inf_data[47:40], inf_data[15:8]};
            ext_b_vld_32 = 1'b1;

            if (is_yuv422 || !is_odd_line) begin
                // Output UV bytes in memory order {U0,V0,U1,V1}.
                ext_a_data32 = {inf_data[71:64], inf_data[87:80], inf_data[7:0], inf_data[23:16]};
                ext_a_vld_32 = 1'b1;
            end
        end else if (is_yuv_10) begin
            ext_b_data64 = {
                inf_data[115:106], 6'b0,
                inf_data[83:74],   6'b0,
                inf_data[51:42],   6'b0,
                inf_data[19:10],   6'b0
            };
            ext_b_vld_64 = 1'b1;

            if (is_yuv422 || !is_odd_line) begin
                ext_a_data64 = {
                    inf_data[73:64], 6'b0,
                    inf_data[93:84], 6'b0,
                    inf_data[9:0],   6'b0,
                    inf_data[29:20], 6'b0
                };
                ext_a_vld_64 = 1'b1;
            end
        end
    end

    // A path fixed-slot pack
    reg [127:0] a_pack32_data, a_pack64_data;
    reg [1:0]   a_pack32_cnt;
    reg         a_pack64_cnt;
    reg [17:0]  a_pack32_sb, a_pack64_sb;

    always @(posedge i_clk or negedge rst_n) begin
        if (!rst_n) begin
            out_fifo_a_wr   <= 1'b0;
            out_fifo_a_din  <= 163'd0;
            a_pack32_data   <= 128'd0;
            a_pack32_cnt    <= 2'd0;
            a_pack32_sb     <= 18'd0;
            a_pack64_data   <= 128'd0;
            a_pack64_cnt    <= 1'b0;
            a_pack64_sb     <= 18'd0;
        end else begin
            out_fifo_a_wr <= 1'b0;

            if (in_fifo_rd) begin
                if (ext_a_vld_128) begin
                    out_fifo_a_wr  <= 1'b1;
                    out_fifo_a_din <= {inf_sideband, inf_last_beat, 16'hFFFF, ext_a_data128};
                end else if (ext_a_vld_32) begin
                    if (a_pack32_cnt == 2'd0)
                        a_pack32_sb <= inf_sideband;

                    case (a_pack32_cnt)
                        2'd0: a_pack32_data[31:0]   <= ext_a_data32;
                        2'd1: a_pack32_data[63:32]  <= ext_a_data32;
                        2'd2: a_pack32_data[95:64]  <= ext_a_data32;
                        2'd3: a_pack32_data[127:96] <= ext_a_data32;
                        default: ;
                    endcase

                    if (a_pack32_cnt == 2'd3) begin
                        out_fifo_a_wr  <= 1'b1;
                        out_fifo_a_din <= {a_pack32_sb, inf_last_beat, 16'hFFFF, {ext_a_data32, a_pack32_data[95:0]}};
                        a_pack32_cnt   <= 2'd0;
                    end else if (inf_last_beat) begin
                        out_fifo_a_wr <= 1'b1;
                        case (a_pack32_cnt)
                            2'd0: out_fifo_a_din <= {a_pack32_sb, 1'b1, 16'h000F, {96'd0, ext_a_data32}};
                            2'd1: out_fifo_a_din <= {a_pack32_sb, 1'b1, 16'h00FF, {64'd0, ext_a_data32, a_pack32_data[31:0]}};
                            2'd2: out_fifo_a_din <= {a_pack32_sb, 1'b1, 16'h0FFF, {32'd0, ext_a_data32, a_pack32_data[63:0]}};
                            default: out_fifo_a_din <= 163'd0;
                        endcase
                        a_pack32_cnt  <= 2'd0;
                        a_pack32_data <= 128'd0;
                    end else begin
                        a_pack32_cnt <= a_pack32_cnt + 2'd1;
                    end
                end else if (ext_a_vld_64) begin
                    if (a_pack64_cnt == 1'b0)
                        a_pack64_sb <= inf_sideband;

                    if (a_pack64_cnt == 1'b0)
                        a_pack64_data[63:0] <= ext_a_data64;
                    else
                        a_pack64_data[127:64] <= ext_a_data64;

                    if (a_pack64_cnt == 1'b1) begin
                        out_fifo_a_wr  <= 1'b1;
                        out_fifo_a_din <= {a_pack64_sb, inf_last_beat, 16'hFFFF, {ext_a_data64, a_pack64_data[63:0]}};
                        a_pack64_cnt   <= 1'b0;
                    end else if (inf_last_beat) begin
                        out_fifo_a_wr  <= 1'b1;
                        out_fifo_a_din <= {a_pack64_sb, 1'b1, 16'h00FF, {64'd0, ext_a_data64}};
                        a_pack64_cnt   <= 1'b0;
                        a_pack64_data  <= 128'd0;
                    end else begin
                        a_pack64_cnt <= 1'b1;
                    end
                end
            end
        end
    end

    // B path fixed-slot pack
    reg [127:0] b_pack32_data, b_pack64_data;
    reg [1:0]   b_pack32_cnt;
    reg         b_pack64_cnt;
    reg [17:0]  b_pack32_sb, b_pack64_sb;

    always @(posedge i_clk or negedge rst_n) begin
        if (!rst_n) begin
            out_fifo_b_wr   <= 1'b0;
            out_fifo_b_din  <= 163'd0;
            b_pack32_data   <= 128'd0;
            b_pack32_cnt    <= 2'd0;
            b_pack32_sb     <= 18'd0;
            b_pack64_data   <= 128'd0;
            b_pack64_cnt    <= 1'b0;
            b_pack64_sb     <= 18'd0;
        end else begin
            out_fifo_b_wr <= 1'b0;

            if (in_fifo_rd && need_b) begin
                if (ext_b_vld_32) begin
                    if (b_pack32_cnt == 2'd0)
                        b_pack32_sb <= inf_sideband;

                    case (b_pack32_cnt)
                        2'd0: b_pack32_data[31:0]   <= ext_b_data32;
                        2'd1: b_pack32_data[63:32]  <= ext_b_data32;
                        2'd2: b_pack32_data[95:64]  <= ext_b_data32;
                        2'd3: b_pack32_data[127:96] <= ext_b_data32;
                        default: ;
                    endcase

                    if (b_pack32_cnt == 2'd3) begin
                        out_fifo_b_wr  <= 1'b1;
                        out_fifo_b_din <= {b_pack32_sb, inf_last_beat, 16'hFFFF, {ext_b_data32, b_pack32_data[95:0]}};
                        b_pack32_cnt   <= 2'd0;
                    end else if (inf_last_beat) begin
                        out_fifo_b_wr <= 1'b1;
                        case (b_pack32_cnt)
                            2'd0: out_fifo_b_din <= {b_pack32_sb, 1'b1, 16'h000F, {96'd0, ext_b_data32}};
                            2'd1: out_fifo_b_din <= {b_pack32_sb, 1'b1, 16'h00FF, {64'd0, ext_b_data32, b_pack32_data[31:0]}};
                            2'd2: out_fifo_b_din <= {b_pack32_sb, 1'b1, 16'h0FFF, {32'd0, ext_b_data32, b_pack32_data[63:0]}};
                            default: out_fifo_b_din <= 163'd0;
                        endcase
                        b_pack32_cnt  <= 2'd0;
                        b_pack32_data <= 128'd0;
                    end else begin
                        b_pack32_cnt <= b_pack32_cnt + 2'd1;
                    end
                end else if (ext_b_vld_64) begin
                    if (b_pack64_cnt == 1'b0)
                        b_pack64_sb <= inf_sideband;

                    if (b_pack64_cnt == 1'b0)
                        b_pack64_data[63:0] <= ext_b_data64;
                    else
                        b_pack64_data[127:64] <= ext_b_data64;

                    if (b_pack64_cnt == 1'b1) begin
                        out_fifo_b_wr  <= 1'b1;
                        out_fifo_b_din <= {b_pack64_sb, inf_last_beat, 16'hFFFF, {ext_b_data64, b_pack64_data[63:0]}};
                        b_pack64_cnt   <= 1'b0;
                    end else if (inf_last_beat) begin
                        out_fifo_b_wr  <= 1'b1;
                        out_fifo_b_din <= {b_pack64_sb, 1'b1, 16'h00FF, {64'd0, ext_b_data64}};
                        b_pack64_cnt   <= 1'b0;
                        b_pack64_data  <= 128'd0;
                    end else begin
                        b_pack64_cnt <= 1'b1;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
