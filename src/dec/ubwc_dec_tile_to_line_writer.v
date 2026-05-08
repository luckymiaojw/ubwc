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
    parameter integer SRAM_ADDR_W = 12
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
    input  wire [3:0]     s_axis_tile_fcnt,
    input  wire           s_axis_tile_valid,
    output wire           s_axis_tile_ready,
    input  wire [255:0]   s_axis_tdata,
    input  wire           s_axis_tlast,
    input  wire           s_axis_tvalid,
    output wire           s_axis_tready,

    output wire           sram_a_wen,    
    output wire [SRAM_ADDR_W-1:0] sram_a_waddr,
    output wire [127:0]   sram_a_wdata,
    output wire           sram_b_wen,    
    output wire [SRAM_ADDR_W-1:0] sram_b_waddr,
    output wire [127:0]   sram_b_wdata,

    output reg            o_writer_bank, 
    output reg  [3:0]     o_writer_fcnt,
    output reg            o_buffer_vld     
);

    localparam integer                  TILE_WRITER_FIFO_DEPTH     = 16;
    localparam integer                  TILE_DATA_BEATS            = 8;
    localparam integer                  DATA_CREDIT_W             = 6;
    localparam integer                  SRAM_RGBA_ROW_SHIFT       = (SRAM_ADDR_W <= 12) ? 9 : 10;
    localparam integer                  SRAM_YUV8_ROW_SHIFT       = (SRAM_ADDR_W <= 12) ? 7 : 8;
    localparam integer                  SRAM_P010_ROW_SHIFT       = (SRAM_ADDR_W <= 12) ? 8 : 9;
    localparam integer                  SRAM_Y_LOWER_BASE_WORDS   = (SRAM_ADDR_W <= 12) ? 1024 : 2048;
    localparam integer                  SRAM_UV_BASE_WORDS        = (SRAM_ADDR_W <= 12) ? 2048 : 4096;

    wire                                hdr_fifo_empty             ;
    wire                                hdr_fifo_full              ;
    wire                                hdr_fifo_rd_en             ;
    wire    [41             -1:0]       hdr_fifo_dout              ;
    wire                                data_fifo_empty            ;
    wire                                data_fifo_full             ;
    wire                                data_fifo_rd_en            ;
    wire    [257            -1:0]       data_fifo_dout             ;
    wire                                tile_ctx_available         ;
    wire                                frame_start;
    assign frame_start = (i_frame_start == 1'b1);
    wire                                hdr_fifo_prog_full         ;
    wire                                hdr_fifo_valid             ;
    wire    [5              -1:0]       hdr_fifo_data_count        ;
    wire                                data_fifo_prog_full        ;
    wire                                data_fifo_valid            ;
    wire    [5              -1:0]       data_fifo_data_count       ;
    wire                                fifo_status_seen           ;
    wire                                tile_hdr_fire              ;
    wire                                data_credit_has_room       ;
    reg     [DATA_CREDIT_W -1:0]        data_credit_used           ;

    wire [15:0] hdr_fifo_tile_y;
    assign hdr_fifo_tile_y = hdr_fifo_dout[15:0];

    assign fifo_status_seen = hdr_fifo_prog_full | hdr_fifo_valid | (|hdr_fifo_data_count) |
                              (|hdr_fifo_tile_y) |
                              data_fifo_prog_full | data_fifo_valid | (|data_fifo_data_count);
    assign data_credit_has_room = (data_credit_used <= DATA_CREDIT_W'(TILE_WRITER_FIFO_DEPTH - TILE_DATA_BEATS));
    assign s_axis_tile_ready = ~hdr_fifo_full && data_credit_has_room;
    assign tile_hdr_fire = s_axis_tile_valid && s_axis_tile_ready;
    assign tile_ctx_available = !hdr_fifo_empty || (s_axis_tile_valid && s_axis_tile_ready);
    assign s_axis_tready = ~data_fifo_full && tile_ctx_available && !(fifo_status_seen & 1'b0);

    mg_sync_fifo #(
        .PROG_DEPTH                    ( 1                                     ),
        .DWIDTH                        ( 41                                    ),
        .DEPTH                         ( TILE_WRITER_FIFO_DEPTH                ),
        .SHOW_AHEAD                    ( 1                                     ),
        .RAM_STYLE                     ( "distributed"                         )
    ) u_hdr_fifo (
        .clk                           ( clk_sram                              ),
        .rst_n                         ( rst_n                                 ),
        .sclr                          ( frame_start                           ),
        .wr_en                         ( tile_hdr_fire                         ),
        .din                           ( {s_axis_tile_fcnt, s_axis_format, s_axis_tile_x, s_axis_tile_y} ),
        .prog_full                     ( hdr_fifo_prog_full                    ),
        .full                          ( hdr_fifo_full                         ),
        .rd_en                         ( hdr_fifo_rd_en                        ),
        .empty                         ( hdr_fifo_empty                        ),
        .dout                          ( hdr_fifo_dout                         ),
        .valid                         ( hdr_fifo_valid                        ),
        .data_count                    ( hdr_fifo_data_count                   )
    );

    mg_sync_fifo #(
        .PROG_DEPTH                    ( 1                                     ),
        .DWIDTH                        ( 257                                   ),
        .DEPTH                         ( TILE_WRITER_FIFO_DEPTH                ),
        .SHOW_AHEAD                    ( 1                                     ),
        .RAM_STYLE                     ( "distributed"                         )
    ) u_data_fifo (
        .clk                           ( clk_sram                              ),
        .rst_n                         ( rst_n                                 ),
        .sclr                          ( frame_start                           ),
        .wr_en                         ( s_axis_tvalid && s_axis_tready        ),
        .din                           ( {s_axis_tlast, s_axis_tdata}          ),
        .prog_full                     ( data_fifo_prog_full                   ),
        .full                          ( data_fifo_full                        ),
        .rd_en                         ( data_fifo_rd_en                       ),
        .empty                         ( data_fifo_empty                       ),
        .dout                          ( data_fifo_dout                        ),
        .valid                         ( data_fifo_valid                       ),
        .data_count                    ( data_fifo_data_count                  )
    );

    wire [255:0] cur_tdata;
    assign cur_tdata = data_fifo_dout[255:0];
    wire         cur_tlast;
    assign cur_tlast = data_fifo_dout[256];
    wire [15:0]  cur_tile_x;
    assign cur_tile_x = hdr_fifo_dout[31:16];
    wire [4:0]   cur_fmt;
    assign cur_fmt = hdr_fifo_dout[36:32];
    wire [3:0]   cur_fcnt;
    assign cur_fcnt = hdr_fifo_dout[40:37];

    reg is_y_stride_1k;
    reg is_row_len_2;
    reg is_uv_plane;
    reg is_yuv420;
    reg is_rgba;
    reg is_p010;

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

    wire target_bank_free;
    assign target_bank_free = (~wr_bank) ? i_sram_a_free : i_sram_b_free;
    wire sram_wen_internal;
    assign sram_wen_internal = (!hdr_fifo_empty) && (!data_fifo_empty) && target_bank_free;
    reg gearbox_sel;

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) gearbox_sel <= 1'b0;
        else if (frame_start) gearbox_sel <= 1'b0;
        else if (sram_wen_internal) gearbox_sel <= ~gearbox_sel;
    end
    assign data_fifo_rd_en = sram_wen_internal && gearbox_sel;

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) begin
            data_credit_used <= {DATA_CREDIT_W{1'b0}};
        end else if (frame_start) begin
            data_credit_used <= {DATA_CREDIT_W{1'b0}};
        end else begin
            case ({tile_hdr_fire, data_fifo_rd_en})
                2'b10: data_credit_used <= data_credit_used + DATA_CREDIT_W'(TILE_DATA_BEATS);
                2'b01: data_credit_used <= data_credit_used - {{(DATA_CREDIT_W-1){1'b0}}, 1'b1};
                2'b11: data_credit_used <= data_credit_used + DATA_CREDIT_W'(TILE_DATA_BEATS - 1);
                default: data_credit_used <= data_credit_used;
            endcase
        end
    end

    reg [3:0] cnt_write;

    wire [16:0] p_base_full;
    assign p_base_full = is_uv_plane ? 17'(SRAM_UV_BASE_WORDS) : 17'd0;
    wire        group_row_sel;
    assign group_row_sel = (!is_uv_plane && is_yuv420) ? (y420_stage == 2'd1) : 1'b0;
    wire [16:0] v_off_full;
    assign v_off_full = group_row_sel ? 17'(SRAM_Y_LOWER_BASE_WORDS) : 17'd0;
    wire [2:0]  y_in_t;
    assign y_in_t = is_row_len_2 ? cnt_write[3:1] : {1'b0, cnt_write[3:2]};
    wire [1:0]  x_w_off;
    assign x_w_off = is_row_len_2 ? {1'b0, cnt_write[0]} : cnt_write[1:0];
    wire [16:0] y_off_full;
    assign y_off_full = {14'd0, y_in_t} <<
                             (is_y_stride_1k ? SRAM_RGBA_ROW_SHIFT :
                              (is_p010 ? SRAM_P010_ROW_SHIFT : SRAM_YUV8_ROW_SHIFT));
    wire [16:0] tile_cols;
    assign tile_cols = is_rgba ?
                            (({1'b0, cfg_img_width} + 17'd15) >> 4) :
                            (({1'b0, cfg_img_width} + 17'd31) >> 5);
    wire [15:0] max_tile_x;
    assign max_tile_x = (tile_cols == 0) ? 16'd0 : (tile_cols[15:0] - 1'b1);
    wire        last_tile_x;
    assign last_tile_x = (cur_tile_x == max_tile_x);
    wire [16:0] tile_x_word_base_full;
    assign tile_x_word_base_full = (is_rgba || is_p010) ?
                                        ({1'b0, cur_tile_x} << 2) :
                                        ({1'b0, cur_tile_x} << 1);
    wire [16:0] x_w_off_ext_full;
    assign x_w_off_ext_full = {15'd0, x_w_off};

    wire [16:0] waddr_full;
    assign waddr_full = p_base_full + v_off_full + y_off_full +
                              tile_x_word_base_full + x_w_off_ext_full;
    wire [SRAM_ADDR_W-1:0] waddr;
    assign waddr = waddr_full[SRAM_ADDR_W-1:0];
    wire [127:0] wdata;
    assign wdata = gearbox_sel ? cur_tdata[255:128] : cur_tdata[127:0];
    wire tile_last_write;
    assign tile_last_write = sram_wen_internal && cur_tlast && gearbox_sel;
    wire rowgroup_done;
    assign rowgroup_done = tile_last_write && last_tile_x;
    wire slice_done;
    assign slice_done = tile_last_write && last_tile_x && (is_rgba || is_uv_plane);
    assign hdr_fifo_rd_en = tile_last_write;

    assign sram_a_wen = sram_wen_internal & (~wr_bank);
    assign sram_b_wen = sram_wen_internal & (wr_bank);
    assign sram_a_waddr = waddr;
    assign sram_b_waddr = waddr;
    assign sram_a_wdata = wdata;
    assign sram_b_wdata = wdata;

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            cnt_write <= 0;
        else if (frame_start)
            cnt_write <= 0;
        else if (sram_wen_internal)
            cnt_write <= tile_last_write ? 4'd0 : cnt_write + 1'b1;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            wr_bank <= 0;
        else if (frame_start)
            wr_bank <= 0;
        else if (sram_wen_internal && slice_done)
            wr_bank <= ~wr_bank;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_writer_bank <= 0;
        else if (frame_start)
            o_writer_bank <= 0;
        else if (sram_wen_internal && slice_done)
            o_writer_bank <= wr_bank;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_writer_fcnt <= 4'd0;
        else if (frame_start)
            o_writer_fcnt <= 4'd0;
        else if (sram_wen_internal && slice_done)
            o_writer_fcnt <= cur_fcnt;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_buffer_vld <= 0;
        else if (frame_start)
            o_buffer_vld <= 0;
        else
            o_buffer_vld <= sram_wen_internal && slice_done;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            y420_stage <= 2'd0;
        else if (frame_start)
            y420_stage <= 2'd0;
        else if (sram_wen_internal && rowgroup_done && !is_yuv420)
            y420_stage <= 2'd0;
        else if (sram_wen_internal && rowgroup_done && is_uv_plane)
            y420_stage <= 2'd0;
        else if (sram_wen_internal && rowgroup_done && (y420_stage == 2'd0))
            y420_stage <= 2'd1;
        else if (sram_wen_internal && rowgroup_done)
            y420_stage <= 2'd2;
    end
endmodule
