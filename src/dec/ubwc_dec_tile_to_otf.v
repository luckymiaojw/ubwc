//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-04-01  23:15:14
// Design Name       : 
// Module Name       : ubwc_dec_tile_to_otf.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module ubwc_dec_tile_to_otf (
    // --- Clocks and reset ---
    input  wire           clk_sram,      // Write and memory-read clock, for example 200 MHz
    input  wire           clk_otf,       // Pixel output clock, for example 148.5 MHz for 1080p60
    input  wire           rst_n,
    input  wire           i_frame_start,

    // --- Frame config, keep stable for one frame ---
    input  wire [15:0]    cfg_img_width, // For example 1920
    input  wire [4:0]     cfg_format,    // Base frame format: RGBA / YUV420 / YUV422
    input  wire [15:0]    cfg_otf_h_total,
    input  wire [15:0]    cfg_otf_h_sync,
    input  wire [15:0]    cfg_otf_h_bp,
    input  wire [15:0]    cfg_otf_h_act,
    input  wire [15:0]    cfg_otf_v_total,
    input  wire [15:0]    cfg_otf_v_sync,
    input  wire [15:0]    cfg_otf_v_bp,
    input  wire [15:0]    cfg_otf_v_act,

    // --- Tile header input (clk_sram) ---
    // These ports can be driven either by the wrapper internal path or by a
    // standalone testbench that feeds tile headers directly.
    input  wire [4:0]     s_axis_format,     // Current tile or plane format for writer address mapping
    input  wire [15:0]    s_axis_tile_x,     // Tile x index in the current frame scan order
    input  wire [15:0]    s_axis_tile_y,     // Slice index; YUV420 expects full-width Y upper, then Y lower, then UV
    input  wire           s_axis_tile_valid, // One header beat per tile
    output wire           s_axis_tile_ready,

    // --- Tile data input (clk_sram) ---
    // These ports can be driven either by the wrapper internal path or by a
    // standalone testbench that feeds tile payload data directly.
    input  wire [255:0]   s_axis_tdata,
    input  wire           s_axis_tlast,      // End of one tile in the current full-width pass
    input  wire           s_axis_tvalid,
    output wire           s_axis_tready,

    // --- External SRAM bank interface (clk_sram) ---
    // The ping-pong SRAM instances are provided by the wrapper or testbench.
    output wire           sram_a_wen,
    output wire [12:0]    sram_a_waddr,
    output wire [127:0]   sram_a_wdata,
    output wire           sram_a_ren,
    output wire [12:0]    sram_a_raddr,
    input  wire [127:0]   sram_a_rdata,
    output wire           sram_b_wen,
    output wire [12:0]    sram_b_waddr,
    output wire [127:0]   sram_b_wdata,
    output wire           sram_b_ren,
    output wire [12:0]    sram_b_raddr,
    input  wire [127:0]   sram_b_rdata,

    // --- OTF Output (clk_otf) ---
    output wire           o_otf_vsync,
    output wire           o_otf_hsync,
    output wire           o_otf_de,
    output wire [127:0]   o_otf_data,
    output wire [3:0]     o_otf_fcnt,
    output wire [11:0]    o_otf_lcnt,
    input  wire           i_otf_ready,

    output wire           o_busy
);

    // =========================================================================
    // Internal signals
    // =========================================================================
    // 1. Handshake and bank status
    wire          writer_vld;
    wire          writer_bank; // 0: bank A just filled, 1: bank B just filled
    wire          fetcher_done;
    wire          fetcher_bank;// 0: bank A just drained, 1: bank B just drained
    
    reg           sram_a_free; // 1: writable, 0: owned by fetcher
    reg           sram_b_free;
    reg           pending_a;
    reg           pending_b;

    // 2. Async FIFO interface
    wire          fifo_wr_en, fifo_rd_en;
    wire [255:0]  fifo_wdata, fifo_rdata;
    wire          fifo_full, fifo_empty;
    wire          otf_driver_busy;
    wire          frame_start_sram = (i_frame_start == 1'b1);
    reg           frame_start_toggle_sram;
    reg  [1:0]    frame_start_toggle_otf_sync;
    wire          frame_start_otf;

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) begin
            frame_start_toggle_sram <= 1'b0;
        end else if (frame_start_sram) begin
            frame_start_toggle_sram <= ~frame_start_toggle_sram;
        end
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n) begin
            frame_start_toggle_otf_sync <= 2'b00;
        end else begin
            frame_start_toggle_otf_sync <= {frame_start_toggle_otf_sync[0], frame_start_toggle_sram};
        end
    end

    assign frame_start_otf = frame_start_toggle_otf_sync[1] ^ frame_start_toggle_otf_sync[0];

    // =========================================================================
    // Bank manager for ping-pong control
    // =========================================================================
    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) begin
            sram_a_free <= 1'b1;
            sram_b_free <= 1'b1;
            pending_a   <= 1'b0;
            pending_b   <= 1'b0;
        end else if (frame_start_sram) begin
            sram_a_free <= 1'b1;
            sram_b_free <= 1'b1;
            pending_a   <= 1'b0;
            pending_b   <= 1'b0;
        end else begin
            // Bank A state
            if (writer_vld && (writer_bank == 1'b0)) 
                sram_a_free <= 1'b0; // Writer filled bank A and handed it over
            else if (fetcher_done && (fetcher_bank == 1'b0)) 
                sram_a_free <= 1'b1; // Fetcher finished bank A and freed it

            // Bank B state
            if (writer_vld && (writer_bank == 1'b1)) 
                sram_b_free <= 1'b0;
            else if (fetcher_done && (fetcher_bank == 1'b1)) 
                sram_b_free <= 1'b1;

            if (writer_vld && (writer_bank == 1'b0))
                pending_a <= 1'b1;
            else if (fetcher_done && (fetcher_bank == 1'b0))
                pending_a <= 1'b0;

            if (writer_vld && (writer_bank == 1'b1))
                pending_b <= 1'b1;
            else if (fetcher_done && (fetcher_bank == 1'b1))
                pending_b <= 1'b0;
        end
    end

    wire fetcher_done_a = fetcher_done && (fetcher_bank == 1'b0);
    wire fetcher_done_b = fetcher_done && (fetcher_bank == 1'b1);
    wire pending_a_avail = pending_a && !fetcher_done_a;
    wire pending_b_avail = pending_b && !fetcher_done_b;
    wire fetcher_req  = pending_a_avail | pending_b_avail;
    wire fetcher_bank_sel = pending_a_avail ? 1'b0 : 1'b1;

    // =========================================================================
    // Module instances
    // =========================================================================
    
    tile_to_line_writer u_writer (
        .clk_sram       (clk_sram),
        .rst_n          (rst_n),
        .i_frame_start  (frame_start_sram),
        .cfg_img_width  (cfg_img_width),
        .i_sram_a_free  (sram_a_free),
        .i_sram_b_free  (sram_b_free),
        .s_axis_format  (s_axis_format),
        .s_axis_tile_x  (s_axis_tile_x),
        .s_axis_tile_y  (s_axis_tile_y),
        .s_axis_tile_valid(s_axis_tile_valid),
        .s_axis_tile_ready(s_axis_tile_ready),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .sram_a_wen     (sram_a_wen), .sram_a_waddr   (sram_a_waddr), .sram_a_wdata   (sram_a_wdata),
        .sram_b_wen     (sram_b_wen), .sram_b_waddr   (sram_b_waddr), .sram_b_wdata   (sram_b_wdata),
        .o_writer_bank  (writer_bank),
        .o_buffer_vld   (writer_vld)
    );

    sram_read_fetcher u_fetcher (
        .clk_sram       (clk_sram),
        .rst_n          (rst_n),
        .i_frame_start  (frame_start_sram),
        .cfg_img_width  (cfg_img_width),
        .cfg_format     (cfg_format),
        .i_buffer_vld   (fetcher_req),
        .i_writer_bank  (fetcher_bank_sel),
        .o_sram_a_ren   (sram_a_ren), .o_sram_a_raddr (sram_a_raddr), .i_sram_a_rdata (sram_a_rdata),
        .o_sram_b_ren   (sram_b_ren), .o_sram_b_raddr (sram_b_raddr), .i_sram_b_rdata (sram_b_rdata),
        .o_fifo_wr_en   (fifo_wr_en), .o_fifo_wdata   (fifo_wdata),   .i_fifo_full    (fifo_full),
        .o_fetcher_done (fetcher_done),
        .o_fetcher_bank (fetcher_bank)
    );

    // Async FIFO across clock domains.
    // It must use FWFT (First-Word Fall-Through) mode.
    async_fifo_fwft_256w #(
        .DATA_WIDTH (256),
        .ADDR_WIDTH (5),
        .DEPTH      (32)
    ) u_cdc_fifo (
        .wr_clk     (clk_sram),
        .wr_rst_n   (rst_n),
        .wr_clr     (frame_start_sram),
        .wr_en      (fifo_wr_en),
        .din        (fifo_wdata),
        .full       (fifo_full),
        .rd_clk     (clk_otf),
        .rd_rst_n   (rst_n),
        .rd_clr     (frame_start_otf),
        .rd_en      (fifo_rd_en),
        .dout       (fifo_rdata),
        .empty      (fifo_empty)
    );

    otf_driver u_otf_driver (
        .clk_otf        (clk_otf),
        .rst_n          (rst_n),
        .i_frame_start  (frame_start_otf),
        .cfg_format     (cfg_format),
        .cfg_otf_h_total(cfg_otf_h_total),
        .cfg_otf_h_sync (cfg_otf_h_sync),
        .cfg_otf_h_bp   (cfg_otf_h_bp),
        .cfg_otf_h_act  (cfg_otf_h_act),
        .cfg_otf_v_total(cfg_otf_v_total),
        .cfg_otf_v_sync (cfg_otf_v_sync),
        .cfg_otf_v_bp   (cfg_otf_v_bp),
        .cfg_otf_v_act  (cfg_otf_v_act),
        .i_otf_ready    (i_otf_ready),
        .i_fifo_empty   (fifo_empty),
        .i_fifo_rdata   (fifo_rdata),
        .o_fifo_rd_en   (fifo_rd_en),
        .o_busy         (otf_driver_busy),
        .o_otf_vsync    (o_otf_vsync),
        .o_otf_hsync    (o_otf_hsync),
        .o_otf_de       (o_otf_de),
        .o_otf_data     (o_otf_data),
        .o_otf_fcnt     (o_otf_fcnt),
        .o_otf_lcnt     (o_otf_lcnt)
    );

    assign o_busy = s_axis_tile_valid | s_axis_tvalid | writer_vld | fetcher_req |
                    !fifo_empty | pending_a | pending_b | !sram_a_free | !sram_b_free |
                    otf_driver_busy;

endmodule
