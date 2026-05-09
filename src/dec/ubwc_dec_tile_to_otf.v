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

module ubwc_dec_tile_to_otf #(
    parameter   integer                             SRAM_ADDR_W                     = 12
)(
    // --- Clocks and reset ---
    input   wire                                        clk_sram                        , // Write and memory-read clock, for example 200 MHz
    input   wire                                        clk_otf                         , // Pixel output clock, for example 148.5 MHz for 1080p60
    input   wire                                        rst_sram_n                      ,
    input   wire                                        rst_otf_n                       ,
    input   wire                                        i_frame_start                   ,
    input   wire    [3                      :0]         i_frame_fcnt                    ,

    // --- Frame config, keep stable for one frame ---
    input   wire    [15                     :0]         cfg_img_width                   , // For example 1920
    input   wire    [4                      :0]         cfg_format                      , // Base frame format: RGBA / YUV420
    input   wire    [15                     :0]         cfg_otf_h_total                 ,
    input   wire    [15                     :0]         cfg_otf_h_sync                  ,
    input   wire    [15                     :0]         cfg_otf_h_bp                    ,
    input   wire    [15                     :0]         cfg_otf_h_act                   ,
    input   wire    [15                     :0]         cfg_otf_v_total                 ,
    input   wire    [15                     :0]         cfg_otf_v_sync                  ,
    input   wire    [15                     :0]         cfg_otf_v_bp                    ,
    input   wire    [15                     :0]         cfg_otf_v_act                   ,

    // --- Tile header input (clk_sram) ---
    // These ports can be driven either by the wrapper internal path or by a
    // standalone testbench that feeds tile headers directly.
    input   wire    [4                      :0]         s_axis_format                   , // Current tile or plane format for writer address mapping
    input   wire    [15                     :0]         s_axis_tile_x                   , // Tile x index in the current frame scan order
    input   wire    [15                     :0]         s_axis_tile_y                   , // Slice index; YUV420 expects full-width Y upper, then Y lower, then UV
    input   wire    [3                      :0]         s_axis_tile_fcnt                ,
    input   wire                                        s_axis_tile_valid               , // One header beat per tile
    output  wire                                        s_axis_tile_ready               ,

    // --- Tile data input (clk_sram) ---
    // These ports can be driven either by the wrapper internal path or by a
    // standalone testbench that feeds tile payload data directly.
    input   wire    [255                    :0]         s_axis_tdata                    ,
    input   wire                                        s_axis_tlast                    , // End of one tile in the current full-width pass
    input   wire                                        s_axis_tvalid                   ,
    output  wire                                        s_axis_tready                   ,

    // --- External SRAM bank interface (clk_sram) ---
    // The ping-pong SRAM instances are provided by the wrapper or testbench.
    output  wire                                        sram_a_wen                      ,
    output  wire    [SRAM_ADDR_W         -1 :0]         sram_a_waddr                    ,
    output  wire    [127                    :0]         sram_a_wdata                    ,
    output  wire                                        sram_a_ren                      ,
    output  wire    [SRAM_ADDR_W         -1 :0]         sram_a_raddr                    ,
    input   wire    [127                    :0]         sram_a_rdata                    ,
    input   wire                                        sram_a_rvalid                   ,
    output  wire                                        sram_b_wen                      ,
    output  wire    [SRAM_ADDR_W         -1 :0]         sram_b_waddr                    ,
    output  wire    [127                    :0]         sram_b_wdata                    ,
    output  wire                                        sram_b_ren                      ,
    output  wire    [SRAM_ADDR_W         -1 :0]         sram_b_raddr                    ,
    input   wire    [127                    :0]         sram_b_rdata                    ,
    input   wire                                        sram_b_rvalid                   ,

    // --- OTF Output (clk_otf) ---
    output  wire                                        o_otf_vsync                     ,
    output  wire                                        o_otf_hsync                     ,
    output  wire                                        o_otf_de                        ,
    output  wire    [127                    :0]         o_otf_data                      ,
    output  wire    [3                      :0]         o_otf_fcnt                      ,
    output  wire    [11                     :0]         o_otf_lcnt                      ,
    input   wire                                        i_otf_ready                     ,

    output  wire                                        o_busy                          ,
    output  wire                                        o_correct_irq_pulse             ,
    output  wire    [31                     :0]         o_otf_line_count                ,
    output  wire    [31                     :0]         o_otf_de_count
);

    wire                                            writer_vld                      ;
    wire                                            writer_bank                     ;
    wire        [3                      :0]         writer_fcnt                     ;
    wire                                            fetcher_req                     ;
    wire                                            fetcher_done                    ;
    wire                                            fetcher_bank                    ;
    wire        [3                      :0]         fetcher_fcnt                    ;
    wire        [3                      :0]         fetcher_fifo_fcnt               ;
    wire                                            fifo_wr_en                      ;
    wire                                            fifo_rd_en0                     ;
    wire                                            fifo_rd_en1                     ;
    wire        [255                    :0]         fifo_wdata                      ;
    wire        [255                    :0]         fifo_rdata0                     ;
    wire        [255                    :0]         fifo_rdata1                     ;
    wire                                            fifo_full0                      ;
    wire                                            fifo_full1                      ;
    wire                                            fifo_empty0                     ;
    wire                                            fifo_empty1                     ;
    wire                                            otf_driver_busy                 ;
    wire                                            otf_frame_done_pulse            ;
    wire                                            otf_correct_irq_pulse           ;
    wire        [31                     :0]         otf_line_count_otf              ;
    wire        [31                     :0]         otf_de_count_otf                ;
    wire                                            frame_start_sram                ;
    wire                                            frame_start_otf_raw             ;
    wire                                            frame_start_otf                 ;
    wire                                            frame_done_sram                 ;
    wire                                            tile_fcnt_accept                ;
    wire                                            writer_axis_tile_ready          ;
    wire                                            fetcher_done_a                  ;
    wire                                            fetcher_done_b                  ;
    wire                                            pending_a_avail                 ;
    wire                                            pending_b_avail                 ;
    wire                                            pending_a_fifo_full             ;
    wire                                            pending_b_fifo_full             ;
    wire                                            writer_axis_tile_valid          ;
    wire                                            pending_a_can_fetch             ;
    wire                                            pending_b_can_fetch             ;
    wire                                            fetcher_bank_sel                ;
    wire        [3                      :0]         fetcher_req_fcnt                ;
    wire                                            fetcher_req_fifo_full           ;

    reg                                             sram_a_free                     ;
    reg                                             sram_b_free                     ;
    reg         [3                      :0]         sram_a_fcnt                     ;
    reg         [3                      :0]         sram_b_fcnt                     ;
    reg                                             pending_a                       ;
    reg                                             pending_b                       ;
    reg                                             frame_start_toggle_sram         ;
    reg         [1                      :0]         frame_start_toggle_otf_sync     ;
    reg         [3                      :0]         frame_fcnt_sram                 ;
    reg         [3                      :0]         frame_fcnt_otf_meta             ;
    reg         [3                      :0]         frame_fcnt_otf_sync             ;
    reg                                             frame_start_otf_reg             ;
    reg                                             frame_done_toggle_otf           ;
    reg         [1                      :0]         frame_done_toggle_sram_sync     ;
    reg                                             correct_irq_toggle_otf          ;
    reg         [1                      :0]         correct_irq_toggle_sram_sync    ;
    reg         [31                     :0]         otf_line_count_sram             ;
    reg         [31                     :0]         otf_de_count_sram               ;
    reg                                             accept_fcnt_valid_sram          ;
    reg         [3                      :0]         accept_fcnt_sram                ;

    // =========================================================================
    // Internal signals
    // =========================================================================
    // 1. Ping-pong buffer status

    // 2. Async FIFO interface

    assign frame_start_sram           = (i_frame_start == 1'b1);
    assign frame_start_otf_raw        = frame_start_toggle_otf_sync[1] ^ frame_start_toggle_otf_sync[0];
    assign frame_start_otf            = frame_start_otf_reg;
    assign frame_done_sram            = frame_done_toggle_sram_sync[1] ^ frame_done_toggle_sram_sync[0];
    assign o_correct_irq_pulse        = correct_irq_toggle_sram_sync[1] ^ correct_irq_toggle_sram_sync[0];
    assign o_otf_line_count           = otf_line_count_sram;
    assign o_otf_de_count             = otf_de_count_sram;
    assign tile_fcnt_accept           = !accept_fcnt_valid_sram || (s_axis_tile_fcnt == accept_fcnt_sram);
    assign s_axis_tile_ready          = writer_axis_tile_ready && tile_fcnt_accept;
    assign fetcher_done_a             = fetcher_done && (fetcher_bank == 1'b0);
    assign fetcher_done_b             = fetcher_done && (fetcher_bank == 1'b1);
    assign pending_a_avail            = pending_a && !fetcher_done_a;
    assign pending_b_avail            = pending_b && !fetcher_done_b;
    assign pending_a_fifo_full        = fifo_full0;
    assign pending_b_fifo_full        = fifo_full0;
    assign pending_a_can_fetch        = pending_a_avail && !pending_a_fifo_full;
    assign pending_b_can_fetch        = pending_b_avail && !pending_b_fifo_full;
    assign writer_axis_tile_valid     = s_axis_tile_valid && tile_fcnt_accept;
    assign fetcher_bank_sel           = pending_a_can_fetch ? 1'b0 : 1'b1;
    assign fetcher_req_fcnt           = pending_a_can_fetch ? sram_a_fcnt : sram_b_fcnt;
    assign fetcher_req_fifo_full      = fifo_full0;
    assign fetcher_req                = pending_a_can_fetch | pending_b_can_fetch;
    assign o_busy                     = s_axis_tile_valid | s_axis_tvalid | writer_vld | fetcher_req |
                                        !fifo_empty0 | !fifo_empty1 | pending_a | pending_b |
                                        !sram_a_free | !sram_b_free | otf_driver_busy;

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            frame_start_toggle_sram <= 1'b0;
        else if (frame_start_sram)
            frame_start_toggle_sram <= ~frame_start_toggle_sram;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            frame_fcnt_sram <= 4'd0;
        else if (frame_start_sram)
            frame_fcnt_sram <= i_frame_fcnt;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            frame_start_toggle_otf_sync <= 2'b00;
        else
            frame_start_toggle_otf_sync <= {frame_start_toggle_otf_sync[0],
                                            frame_start_toggle_sram};
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            frame_fcnt_otf_meta <= 4'd0;
        else
            frame_fcnt_otf_meta <= frame_fcnt_sram;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            frame_fcnt_otf_sync <= 4'd0;
        else
            frame_fcnt_otf_sync <= frame_fcnt_otf_meta;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n)
            frame_start_otf_reg <= 1'b0;
        else
            frame_start_otf_reg <= frame_start_otf_raw;
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n) begin
            frame_done_toggle_otf <= 1'b0;
        end else if (otf_frame_done_pulse) begin
            frame_done_toggle_otf <= ~frame_done_toggle_otf;
        end
    end

    always @(posedge clk_otf or negedge rst_otf_n) begin
        if (!rst_otf_n) begin
            correct_irq_toggle_otf <= 1'b0;
        end else if (otf_correct_irq_pulse) begin
            correct_irq_toggle_otf <= ~correct_irq_toggle_otf;
        end
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            frame_done_toggle_sram_sync <= 2'b00;
        else
            frame_done_toggle_sram_sync <= {frame_done_toggle_sram_sync[0],
                                            frame_done_toggle_otf};
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            correct_irq_toggle_sram_sync <= 2'b00;
        else
            correct_irq_toggle_sram_sync <= {correct_irq_toggle_sram_sync[0],
                                             correct_irq_toggle_otf};
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            otf_line_count_sram <= 32'd0;
        else
            otf_line_count_sram <= otf_line_count_otf;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            otf_de_count_sram <= 32'd0;
        else
            otf_de_count_sram <= otf_de_count_otf;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            accept_fcnt_valid_sram <= 1'b0;
        else if (!accept_fcnt_valid_sram && frame_start_sram)
            accept_fcnt_valid_sram <= 1'b1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            accept_fcnt_sram <= 4'd0;
        else if (!accept_fcnt_valid_sram && frame_start_sram)
            accept_fcnt_sram <= i_frame_fcnt;
        else if (frame_done_sram)
            accept_fcnt_sram <= accept_fcnt_sram + 4'd1;
    end

    // =========================================================================
    // Module instances
    // =========================================================================

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            sram_a_free <= 1'b1;
        else if (fetcher_done_a)
            sram_a_free <= 1'b1;
        else if (writer_vld && (writer_bank == 1'b0))
            sram_a_free <= 1'b0;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            sram_b_free <= 1'b1;
        else if (fetcher_done_b)
            sram_b_free <= 1'b1;
        else if (writer_vld && (writer_bank == 1'b1))
            sram_b_free <= 1'b0;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            sram_a_fcnt <= 4'd0;
        else if (writer_vld && (writer_bank == 1'b0))
            sram_a_fcnt <= writer_fcnt;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            sram_b_fcnt <= 4'd0;
        else if (writer_vld && (writer_bank == 1'b1))
            sram_b_fcnt <= writer_fcnt;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            pending_a <= 1'b0;
        else if (fetcher_done_a)
            pending_a <= 1'b0;
        else if (writer_vld && (writer_bank == 1'b0))
            pending_a <= 1'b1;
    end

    always @(posedge clk_sram or negedge rst_sram_n) begin
        if (!rst_sram_n)
            pending_b <= 1'b0;
        else if (fetcher_done_b)
            pending_b <= 1'b0;
        else if (writer_vld && (writer_bank == 1'b1))
            pending_b <= 1'b1;
    end

    tile_to_line_writer #(
        .SRAM_ADDR_W                   ( SRAM_ADDR_W                          )
    ) u_writer (
        .clk_sram                      ( clk_sram                              ),
        .rst_n                         ( rst_sram_n                            ),
        .i_frame_start                 ( 1'b0                                  ),
        .cfg_img_width                 ( cfg_img_width                         ),
        .i_sram_a_free                 ( sram_a_free                           ),
        .i_sram_b_free                 ( sram_b_free                           ),
        .s_axis_format                 ( s_axis_format                         ),
        .s_axis_tile_x                 ( s_axis_tile_x                         ),
        .s_axis_tile_y                 ( s_axis_tile_y                         ),
        .s_axis_tile_fcnt              ( s_axis_tile_fcnt                      ),
        .s_axis_tile_valid             ( writer_axis_tile_valid                ),
        .s_axis_tile_ready             ( writer_axis_tile_ready                ),
        .s_axis_tdata                  ( s_axis_tdata                          ),
        .s_axis_tlast                  ( s_axis_tlast                          ),
        .s_axis_tvalid                 ( s_axis_tvalid                         ),
        .s_axis_tready                 ( s_axis_tready                         ),
        .sram_a_wen                    ( sram_a_wen                            ),
        .sram_a_waddr                  ( sram_a_waddr                          ),
        .sram_a_wdata                  ( sram_a_wdata                          ),
        .sram_b_wen                    ( sram_b_wen                            ),
        .sram_b_waddr                  ( sram_b_waddr                          ),
        .sram_b_wdata                  ( sram_b_wdata                          ),
        .o_writer_bank                 ( writer_bank                           ),
        .o_writer_fcnt                 ( writer_fcnt                           ),
        .o_buffer_vld                  ( writer_vld                            )
    );

    sram_read_fetcher #(
        .SRAM_ADDR_W                   ( SRAM_ADDR_W                          )
    ) u_fetcher (
        .clk_sram                      ( clk_sram                              ),
        .rst_n                         ( rst_sram_n                            ),
        .i_frame_start                 ( 1'b0                                  ),
        .cfg_img_width                 ( cfg_img_width                         ),
        .cfg_format                    ( cfg_format                            ),
        .i_buffer_vld                  ( fetcher_req                           ),
        .i_writer_bank                 ( fetcher_bank_sel                      ),
        .i_buffer_fcnt                 ( fetcher_req_fcnt                      ),
        .o_sram_a_ren                  ( sram_a_ren                            ),
        .o_sram_a_raddr                ( sram_a_raddr                          ),
        .i_sram_a_rdata                ( sram_a_rdata                          ),
        .o_sram_b_ren                  ( sram_b_ren                            ),
        .o_sram_b_raddr                ( sram_b_raddr                          ),
        .i_sram_b_rdata                ( sram_b_rdata                          ),
        .o_fifo_wr_en                  ( fifo_wr_en                            ),
        .o_fifo_wdata                  ( fifo_wdata                            ),
        .o_fifo_fcnt                   ( fetcher_fifo_fcnt                     ),
        .i_fifo_full                   ( fetcher_req_fifo_full                 ),
        .o_fetcher_done                ( fetcher_done                          ),
        .o_fetcher_bank                ( fetcher_bank                          ),
        .o_fetcher_fcnt                ( fetcher_fcnt                          )
    );

    // Async FIFO across clock domains.
    mg_async_fifo #(
        .AF         (1),
        .DATA_BITS  (256),
        .DEPTH_BITS (5),
        .SHOW_AHEAD (1),
        .RAM_STYLE  ("block")
    ) u_cdc_fifo0 (
        .wr_clk        (clk_sram),
        .wr_rstn       (rst_sram_n),
        .wr_en         (fifo_wr_en),
        .din           (fifo_wdata),
        .wr_data_count (),
        .prog_full     (),
        .full          (fifo_full0),
        .rd_clk        (clk_otf),
        .rd_rstn       (rst_otf_n),
        .rd_en         (fifo_rd_en0),
        .dout          (fifo_rdata0),
        .valid         (),
        .rd_data_count (),
        .pre_empty     (),
        .empty         (fifo_empty0)
    );

    mg_async_fifo #(
        .AF         (1),
        .DATA_BITS  (256),
        .DEPTH_BITS (5),
        .SHOW_AHEAD (1),
        .RAM_STYLE  ("block")
    ) u_cdc_fifo1 (
        .wr_clk        (clk_sram),
        .wr_rstn       (rst_sram_n),
        .wr_en         (1'b0),
        .din           (fifo_wdata),
        .wr_data_count (),
        .prog_full     (),
        .full          (fifo_full1),
        .rd_clk        (clk_otf),
        .rd_rstn       (rst_otf_n),
        .rd_en         (fifo_rd_en1),
        .dout          (fifo_rdata1),
        .valid         (),
        .rd_data_count (),
        .pre_empty     (),
        .empty         (fifo_empty1)
    );

    otf_driver u_otf_driver (
        .clk_otf        (clk_otf),
        .rst_n          (rst_otf_n),
        .i_frame_start  (frame_start_otf),
        .i_frame_fcnt   (frame_fcnt_otf_sync),
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
        .i_fifo_empty0  (fifo_empty0),
        .i_fifo_rdata0  (fifo_rdata0),
        .o_fifo_rd_en0  (fifo_rd_en0),
        .i_fifo_empty1  (fifo_empty1),
        .i_fifo_rdata1  (fifo_rdata1),
        .o_fifo_rd_en1  (fifo_rd_en1),
        .o_busy         (otf_driver_busy),
        .o_active_fcnt  (),
        .o_frame_done_pulse(otf_frame_done_pulse),
        .o_correct_irq_pulse(otf_correct_irq_pulse),
        .o_otf_line_count(otf_line_count_otf),
        .o_otf_de_count (otf_de_count_otf),
        .o_otf_vsync    (o_otf_vsync),
        .o_otf_hsync    (o_otf_hsync),
        .o_otf_de       (o_otf_de),
        .o_otf_data     (o_otf_data),
        .o_otf_fcnt     (o_otf_fcnt),
        .o_otf_lcnt     (o_otf_lcnt)
    );

endmodule
