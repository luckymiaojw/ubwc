`timescale 1ns/1ps

module ubwc_dec_meta_data_gen #(
    parameter ADDR_WIDTH     = 32,
    parameter ID_WIDTH       = 4,
    parameter AXI_DATA_WIDTH = 256,
    parameter SRAM_ADDR_W    = 12,
    parameter SRAM_RD_DW     = 64,
    parameter SRAM_NUM_LANES = 4
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      start,

    // --- External configuration ---
    input  wire [4:0]                base_format,            // Frame-level format: RGBA8888/RGBA1010102/YUV420 8/10/YUV422 8/10
    input  wire [ADDR_WIDTH-1:0]     meta_base_addr_rgba_uv,
    input  wire [ADDR_WIDTH-1:0]     meta_base_addr_y,
    input  wire [15:0]               tile_x_numbers,          // Image tile columns, one metadata byte per tile
    input  wire [15:0]               tile_y_numbers,          // Image tile rows, one metadata byte per tile

    // --- AXI AR channel ---
    output wire                      m_axi_arvalid,
    input  wire                      m_axi_arready,
    output wire [ADDR_WIDTH-1:0]     m_axi_araddr,
    output wire [7:0]                m_axi_arlen,
    output wire [2:0]                m_axi_arsize,
    output wire [1:0]                m_axi_arburst,
    output wire [ID_WIDTH-1:0]       m_axi_arid,

    // --- AXI R channel ---
    input  wire                      m_axi_rvalid,
    output wire                      m_axi_rready,
    input  wire [AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input  wire [ID_WIDTH-1:0]       m_axi_rid,
    input  wire [1:0]                m_axi_rresp,
    input  wire                      m_axi_rlast,

    // --- Downstream output FIFO ---
    output wire [37:0]               fifo_wdata,
    output wire                      fifo_vld,
    input  wire                      fifo_rdy,

    output wire                      o_busy,

    // --- Status outputs ---
    output wire [31:0]               error_cnt,
    output wire [31:0]               cmd_ok_cnt,
    output wire [31:0]               cmd_fail_cnt
);

    // Internal bfifo descriptor:
    // {pingpong, error, is_eol, is_last_pass, meta_format[4:0], xcoord[15:0], ycoord[15:0]}
    wire        bfifo_we;
    wire [40:0] bfifo_wdata;
    wire        bfifo_prog_full;
    wire                      cmd_valid;
    wire                      cmd_ready;
    wire [ADDR_WIDTH-1:0]     cmd_addr;
    wire [7:0]                cmd_len;
    wire                      meta_valid;
    wire                      meta_ready;
    wire [4:0]                meta_format;
    wire [15:0]               meta_xcoord;
    wire [15:0]               meta_ycoord;
    wire                      meta_bank_fill_valid;
    wire                      meta_bank_fill_bank_b;
    wire                      meta_bank_release_valid;
    wire                      meta_bank_release_bank_b;
    reg                       meta_bank_a_free;
    reg                       meta_bank_b_free;
    wire [SRAM_NUM_LANES-1:0] sram_wr_we_a_int;
    wire [SRAM_NUM_LANES-1:0] sram_wr_we_b_int;
    wire [SRAM_ADDR_W-1:0]    sram_wr_addr_int;
    wire [AXI_DATA_WIDTH-1:0] sram_wr_wdata_int;
    wire [SRAM_NUM_LANES-1:0] sram_rd_re_a_int;
    wire [SRAM_NUM_LANES-1:0] sram_rd_re_b_int;
    wire [SRAM_ADDR_W-1:0]    sram_rd_addr_int;
    wire [SRAM_RD_DW-1:0]     sram_rd_rdata_int;
    wire                      sram_rd_rvalid_int;
    wire                      sram_dbg_rd_rsp_bank_b_unused;
    wire [$clog2(SRAM_NUM_LANES)-1:0] sram_dbg_rd_rsp_lane_unused;
    wire [SRAM_ADDR_W-1:0]    sram_dbg_rd_rsp_addr_unused;
    wire                      sram_dbg_rd_rsp_hit_unused;
    wire [31:0]               sram_dbg_wr_cnt_unused;
    wire [31:0]               sram_dbg_rd_req_cnt_unused;
    wire [31:0]               sram_dbg_rd_rsp_cnt_unused;
    wire [31:0]               sram_dbg_rd_miss_cnt_unused;

    ubwc_enc_meta_get_cmd_gen #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_meta_get_cmd_gen (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .start                  (start),
        .base_format            (base_format),
        .meta_base_addr_rgba_uv (meta_base_addr_rgba_uv),
        .meta_base_addr_y       (meta_base_addr_y),
        .tile_x_numbers         (tile_x_numbers),
        .tile_y_numbers         (tile_y_numbers),
        .cmd_valid              (cmd_valid),
        .cmd_ready              (cmd_ready),
        .cmd_addr               (cmd_addr),
        .cmd_len                (cmd_len),
        .meta_valid             (meta_valid),
        .meta_ready             (meta_ready),
        .meta_format            (meta_format),
        .meta_xcoord            (meta_xcoord),
        .meta_ycoord            (meta_ycoord)
    );

    ubwc_dec_meta_axi_rcmd_gen #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .ID_WIDTH   (ID_WIDTH),
        .DATA_WIDTH (AXI_DATA_WIDTH)
    ) u_axi_rcmd_gen (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .m_axi_arvalid (m_axi_arvalid),
        .m_axi_arready (m_axi_arready),
        .m_axi_araddr  (m_axi_araddr),
        .m_axi_arlen   (m_axi_arlen),
        .m_axi_arsize  (m_axi_arsize),
        .m_axi_arburst (m_axi_arburst),
        .m_axi_arid    (m_axi_arid),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready),
        .m_axi_rid     (m_axi_rid),
        .m_axi_rresp   (m_axi_rresp),
        .m_axi_rlast   (m_axi_rlast),
        .in_cmd_en     (cmd_valid),
        .in_cmd_ready  (cmd_ready),
        .in_cmd_addr   (cmd_addr),
        .in_cmd_len    (cmd_len),
        .error_cnt     (error_cnt),
        .cmd_ok_cnt    (cmd_ok_cnt),
        .cmd_fail_cnt  (cmd_fail_cnt)
    );

    ubwc_dec_meta_axi_rdata_to_sram #(
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .SRAM_ADDR_W    (SRAM_ADDR_W)
    ) u_axi_rdata_to_sram (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (start),
        .base_format     (base_format),
        .tile_x_numbers  (tile_x_numbers),
        .tile_y_numbers  (tile_y_numbers),
        .meta_valid      (meta_valid),
        .meta_ready      (meta_ready),
        .meta_format     (meta_format),
        .meta_xcoord     (meta_xcoord),
        .meta_ycoord     (meta_ycoord),
        .axi_rvalid      (m_axi_rvalid),
        .axi_rready      (m_axi_rready),
        .axi_rdata       (m_axi_rdata),
        .axi_rlast       (m_axi_rlast),
        .bank_a_free     (meta_bank_a_free),
        .bank_b_free     (meta_bank_b_free),
        .sram_we_a       (sram_wr_we_a_int),
        .sram_we_b       (sram_wr_we_b_int),
        .sram_addr       (sram_wr_addr_int),
        .sram_wdata      (sram_wr_wdata_int),
        .bfifo_prog_full (bfifo_prog_full),
        .bfifo_we        (bfifo_we),
        .bfifo_wdata     (bfifo_wdata),
        .bank_fill_valid (meta_bank_fill_valid),
        .bank_fill_bank_b(meta_bank_fill_bank_b)
    );

    ubwc_dec_meta_data_from_sram #(
        .SRAM_ADDR_W    (SRAM_ADDR_W),
        .SRAM_DW        (SRAM_RD_DW)
    ) u_meta_data_from_sram (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (start),
        .base_format     (base_format),
        .tile_x_numbers  (tile_x_numbers),
        .tile_y_numbers  (tile_y_numbers),
        .sram_re_a       (sram_rd_re_a_int),
        .sram_re_b       (sram_rd_re_b_int),
        .sram_addr       (sram_rd_addr_int),
        .sram_rdata      (sram_rd_rdata_int),
        .sram_rvalid     (sram_rd_rvalid_int),
        .bfifo_we        (bfifo_we),
        .bfifo_wdata     (bfifo_wdata),
        .bfifo_prog_full (bfifo_prog_full),
        .fifo_wdata      (fifo_wdata),
        .fifo_vld        (fifo_vld),
        .fifo_rdy        (fifo_rdy),
        .bank_release_valid (meta_bank_release_valid),
        .bank_release_bank_b(meta_bank_release_bank_b)
    );

    ubwc_dec_meta_pingpong_sram #(
        .WR_DATA_W (AXI_DATA_WIDTH),
        .RD_DATA_W (SRAM_RD_DW),
        .ADDR_W    (SRAM_ADDR_W),
        .NUM_LANES (SRAM_NUM_LANES),
        .DEPTH     (1 << SRAM_ADDR_W)
    ) u_meta_pingpong_sram (
        .clk           (clk),
        .rst_n         (rst_n),
        .wr_we_a       (sram_wr_we_a_int),
        .wr_we_b       (sram_wr_we_b_int),
        .wr_addr       (sram_wr_addr_int),
        .wr_wdata      (sram_wr_wdata_int),
        .rd_re_a       (sram_rd_re_a_int),
        .rd_re_b       (sram_rd_re_b_int),
        .rd_addr       (sram_rd_addr_int),
        .rd_rdata      (sram_rd_rdata_int),
        .rd_rvalid     (sram_rd_rvalid_int),
        .rd_rsp_bank_b (sram_dbg_rd_rsp_bank_b_unused),
        .rd_rsp_lane   (sram_dbg_rd_rsp_lane_unused),
        .rd_rsp_addr   (sram_dbg_rd_rsp_addr_unused),
        .rd_rsp_hit    (sram_dbg_rd_rsp_hit_unused),
        .wr_cnt        (sram_dbg_wr_cnt_unused),
        .rd_req_cnt    (sram_dbg_rd_req_cnt_unused),
        .rd_rsp_cnt    (sram_dbg_rd_rsp_cnt_unused),
        .rd_miss_cnt   (sram_dbg_rd_miss_cnt_unused)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            meta_bank_a_free <= 1'b1;
            meta_bank_b_free <= 1'b1;
        end else if (start) begin
            meta_bank_a_free <= 1'b1;
            meta_bank_b_free <= 1'b1;
        end else begin
            if (meta_bank_fill_valid && !meta_bank_fill_bank_b) begin
                meta_bank_a_free <= 1'b0;
            end else if (meta_bank_release_valid && !meta_bank_release_bank_b) begin
                meta_bank_a_free <= 1'b1;
            end

            if (meta_bank_fill_valid && meta_bank_fill_bank_b) begin
                meta_bank_b_free <= 1'b0;
            end else if (meta_bank_release_valid && meta_bank_release_bank_b) begin
                meta_bank_b_free <= 1'b1;
            end
        end
    end

    assign o_busy = cmd_valid | meta_valid | m_axi_arvalid | m_axi_rvalid | fifo_vld |
                    bfifo_we | (|sram_wr_we_a_int) | (|sram_wr_we_b_int) |
                    (|sram_rd_re_a_int) | (|sram_rd_re_b_int) | sram_rd_rvalid_int |
                    !meta_bank_a_free | !meta_bank_b_free;

endmodule
