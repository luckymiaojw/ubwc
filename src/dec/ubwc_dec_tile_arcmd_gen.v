`timescale 1ns/1ps

module ubwc_dec_tile_arcmd_gen #(
    parameter AXI_AW   = 64,
    parameter AXI_DW   = 256,
    parameter AXI_IDW  = 6,
    parameter SB_WIDTH = 1,
    parameter FORCE_FULL_PAYLOAD = 0
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      i_frame_start,

    input  wire                      i_cfg_lvl1_bank_swizzle_en,
    input  wire                      i_cfg_lvl2_bank_swizzle_en,
    input  wire                      i_cfg_lvl3_bank_swizzle_en,
    input  wire [4:0]                i_cfg_highest_bank_bit,
    input  wire                      i_cfg_bank_spread_en,
    input  wire                      i_cfg_4line_format,
    input  wire                      i_cfg_is_lossy_rgba_2_1_format,
    input  wire [11:0]               i_cfg_pitch,

    input  wire                      i_cfg_ci_input_type,
    input  wire [SB_WIDTH-1:0]       i_cfg_ci_sb,
    input  wire                      i_cfg_ci_lossy,
    input  wire [1:0]                i_cfg_ci_alpha_mode,
    input  wire [AXI_AW-1:0]         i_cfg_base_addr_rgba_uv,
    input  wire [AXI_AW-1:0]         i_cfg_base_addr_y,

    // fifo_wdata comes from ubwc_dec_meta_data_gen:
    // {error, is_eol, is_last_pass, meta_data[7:0], meta_format[4:0], x_byte[11:0], y_row[9:0]}
    input  wire [37:0]               fifo_wdata,
    input  wire                      fifo_vld,
    output wire                      fifo_rdy,

    output wire                      m_axi_arvalid,
    input  wire                      m_axi_arready,
    output wire [AXI_AW-1:0]         m_axi_araddr,
    output wire [7:0]                m_axi_arlen,
    output wire [2:0]                m_axi_arsize,
    output wire [1:0]                m_axi_arburst,
    output wire [AXI_IDW-1:0]        m_axi_arid,

    input  wire                      m_axi_rvalid,
    input  wire [AXI_IDW-1:0]        m_axi_rid,
    input  wire [AXI_DW-1:0]         m_axi_rdata,
    input  wire [1:0]                m_axi_rresp,
    input  wire                      m_axi_rlast,
    output wire                      m_axi_rready,

    output wire                      o_ci_valid,
    input  wire                      i_ci_ready,
    output wire                      o_ci_input_type,
    output wire [2:0]                o_ci_alen,
    output wire [4:0]                o_ci_format,
    output wire [3:0]                o_ci_metadata,
    output wire                      o_ci_lossy,
    output wire [1:0]                o_ci_alpha_mode,
    output wire [SB_WIDTH-1:0]       o_ci_sb,

    output wire                      o_tile_coord_vld,
    output wire [4:0]                o_tile_format,
    output wire [11:0]               o_tile_x_coord,
    output wire [9:0]                o_tile_y_coord,

    output wire                      o_cvi_valid,
    output wire [255:0]              o_cvi_data,
    output wire                      o_cvi_last,
    input  wire                      i_cvi_ready,

    output wire                      o_busy
);

    localparam [4:0] META_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] META_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] META_FMT_NV12_Y      = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV     = 5'b01001;
    localparam [4:0] META_FMT_NV16_Y      = 5'b01010;
    localparam [4:0] META_FMT_NV16_UV     = 5'b01011;
    localparam [4:0] META_FMT_NV16_10_Y   = 5'b01100;
    localparam [4:0] META_FMT_NV16_10_UV  = 5'b01101;
    localparam [4:0] META_FMT_P010_Y      = 5'b01110;
    localparam [4:0] META_FMT_P010_UV     = 5'b01111;

    localparam integer AR_ADDR_W      = AXI_AW - 4;
    localparam integer CI_Y_LSB       = 0;
    localparam integer CI_Y_MSB       = 9;
    localparam integer CI_X_LSB       = 10;
    localparam integer CI_X_MSB       = 21;
    localparam integer CI_ALEN_LSB    = 22;
    localparam integer CI_ALEN_MSB    = 24;
    localparam integer CI_META_LSB    = 25;
    localparam integer CI_META_MSB    = 28;
    localparam integer CI_FORMAT_LSB  = 29;
    localparam integer CI_FORMAT_MSB  = 33;
    localparam integer CI_PAYLOAD_BIT = 34;
    localparam integer CI_ADDR_LSB    = 35;
    localparam integer CI_ADDR_MSB    = CI_ADDR_LSB + AXI_AW - 1;
    localparam integer CI_FIFO_W      = CI_ADDR_MSB + 1;
    localparam [2:0]   AXI_ARSIZE = $clog2(AXI_DW / 8);

    wire        fifo_meta_error     = fifo_wdata[37];
    wire        fifo_meta_eol       = fifo_wdata[36];
    wire        fifo_meta_last_pass = fifo_wdata[35];
    wire [7:0]  fifo_meta_data      = fifo_wdata[34:27];
    wire [4:0]  fifo_meta_format    = fifo_wdata[26:22];
    wire [11:0] fifo_meta_x         = fifo_wdata[21:10];
    wire [9:0]  fifo_meta_y         = fifo_wdata[9:0];

    wire        dec_meta_valid;
    wire        dec_meta_ready;
    wire [4:0]  dec_meta_format;
    wire [3:0]  dec_meta_flag;
    wire [2:0]  dec_meta_alen;
    wire        dec_meta_has_payload;
    wire [11:0] dec_meta_x;
    wire [9:0]  dec_meta_y;

    ubwc_dec_meta_data_decode #(
        .FORCE_FULL_PAYLOAD (FORCE_FULL_PAYLOAD)
    ) u_decode_metadata (
        .clk                             (clk),
        .rst_n                           (rst_n),
        .i_cfg_is_lossy_rgba_2_1_format  (i_cfg_is_lossy_rgba_2_1_format),
        .i_meta_valid                    (fifo_vld),
        .o_meta_ready                    (fifo_rdy),
        .i_meta_format                   (fifo_meta_format),
        .i_meta_data                     (fifo_meta_data),
        .i_meta_error                    (fifo_meta_error),
        .i_meta_eol                      (fifo_meta_eol),
        .i_meta_last_pass                (fifo_meta_last_pass),
        .i_meta_x                        (fifo_meta_x),
        .i_meta_y                        (fifo_meta_y),
        .o_dec_valid                     (dec_meta_valid),
        .i_dec_ready                     (dec_meta_ready),
        .o_dec_format                    (dec_meta_format),
        .o_dec_flag                      (dec_meta_flag),
        .o_dec_alen                      (dec_meta_alen),
        .o_dec_has_payload               (dec_meta_has_payload),
        .o_dec_x                         (dec_meta_x),
        .o_dec_y                         (dec_meta_y)
    );

    wire                tile_cmd_valid;
    wire                tile_cmd_ready;
    wire [AR_ADDR_W-1:0]tile_cmd_addr;
    wire [4:0]          tile_cmd_format;
    wire [3:0]          tile_cmd_meta;
    wire [2:0]          tile_cmd_alen;
    wire                tile_cmd_has_payload;

    ubwc_tile_addr #(
        .ADDR_W (AXI_AW)
    ) u_ubwc_tile_addr (
        .clk                             (clk),
        .rst_n                           (rst_n),
        .i_cfg_lvl1_bank_swizzle_en      (i_cfg_lvl1_bank_swizzle_en),
        .i_cfg_lvl2_bank_swizzle_en      (i_cfg_lvl2_bank_swizzle_en),
        .i_cfg_lvl3_bank_swizzle_en      (i_cfg_lvl3_bank_swizzle_en),
        .i_cfg_highest_bank_bit          (i_cfg_highest_bank_bit),
        .i_cfg_bank_spread_en            (i_cfg_bank_spread_en),
        .i_cfg_4line_format              (i_cfg_4line_format),
        .i_cfg_is_lossy_rgba_2_1_format  (i_cfg_is_lossy_rgba_2_1_format),
        .i_cfg_pitch                     (i_cfg_pitch),
        .i_cfg_base_addr_rgba_uv         (i_cfg_base_addr_rgba_uv),
        .i_cfg_base_addr_y               (i_cfg_base_addr_y),
        .i_meta_valid                    (dec_meta_valid),
        .o_meta_ready                    (dec_meta_ready),
        .i_meta_format                   (dec_meta_format),
        .i_meta_flag                     (dec_meta_flag),
        .i_meta_alen                     (dec_meta_alen),
        .i_meta_has_payload              (dec_meta_has_payload),
        .i_meta_x                        (dec_meta_x),
        .i_meta_y                        (dec_meta_y),
        .o_cmd_valid                     (tile_cmd_valid),
        .i_cmd_ready                     (tile_cmd_ready),
        .o_cmd_addr                      (tile_cmd_addr),
        .o_cmd_format                    (tile_cmd_format),
        .o_cmd_meta                      (tile_cmd_meta),
        .o_cmd_alen                      (tile_cmd_alen),
        .o_cmd_has_payload               (tile_cmd_has_payload)
    );

    wire [AXI_AW-1:0] tile_cmd_addr_full = {tile_cmd_addr, 4'b0000};
    wire              frame_start        = (i_frame_start == 1'b1);

    wire [CI_FIFO_W-1:0] ci_fifo_din  = {tile_cmd_addr_full, tile_cmd_has_payload, tile_cmd_format, tile_cmd_meta, tile_cmd_alen, dec_meta_x, dec_meta_y};
    wire [CI_FIFO_W-1:0] ci_fifo_dout;
    wire                 ci_fifo_full;
    wire                 ci_fifo_empty;
    wire                 ci_fifo_valid;
    wire                 ci_fifo_wr_en = tile_cmd_valid && tile_cmd_ready;
    wire                 ci_fifo_rd_en = o_ci_valid && i_ci_ready;
    wire                 ci_fifo_has_payload = ci_fifo_dout[CI_PAYLOAD_BIT];
    wire [AXI_AW-1:0]    ci_fifo_addr        = ci_fifo_dout[CI_ADDR_MSB:CI_ADDR_LSB];
    wire [2:0]           ci_fifo_alen        = ci_fifo_dout[CI_ALEN_MSB:CI_ALEN_LSB];

    mg_sync_fifo #(
        .PROG_DEPTH (1),
        .DWIDTH     (CI_FIFO_W),
        .DEPTH      (64),
        .SHOW_AHEAD (1)
    ) u_ci_fifo (
        .clk        (clk),
        .rst_n      (rst_n && !frame_start),
        .wr_en      (ci_fifo_wr_en),
        .din        (ci_fifo_din),
        .prog_full  (),
        .full       (ci_fifo_full),
        .rd_en      (ci_fifo_rd_en),
        .empty      (ci_fifo_empty),
        .dout       (ci_fifo_dout),
        .valid      (ci_fifo_valid),
        .data_count ()
    );

    reg  [AXI_AW-1:0]       ar_req_addr_reg;
    reg  [3:0]              ar_req_beats_left_reg;
    reg  [3:0]              payload_beats_left_reg;

    wire [12:0]             ar_bytes_to_4k      = 13'd4096 - {1'b0, ar_req_addr_reg[11:0]};
    wire [7:0]              ar_boundary_beats   = ar_bytes_to_4k[12:5];
    wire [3:0]              ar_issue_beats      = (ar_boundary_beats[7:4] != 4'd0) ? ar_req_beats_left_reg :
                                                  ((ar_req_beats_left_reg <= ar_boundary_beats[3:0]) ? ar_req_beats_left_reg : ar_boundary_beats[3:0]);
    wire [3:0]              ci_payload_beats    = {1'b0, ci_fifo_alen} + 4'd1;
    wire                    ar_fire             = m_axi_arvalid && m_axi_arready;
    wire                    payload_active      = (payload_beats_left_reg != 4'd0);
    wire                    r_fire              = m_axi_rvalid && m_axi_rready && payload_active;

    assign tile_cmd_ready = !ci_fifo_full;

    assign o_ci_valid       = ci_fifo_valid && (payload_beats_left_reg == 4'd0);
    assign o_ci_input_type  = i_cfg_ci_input_type;
    assign o_ci_format      = ci_fifo_dout[CI_FORMAT_MSB:CI_FORMAT_LSB];
    assign o_ci_metadata    = ci_fifo_dout[CI_META_MSB:CI_META_LSB];
    assign o_ci_alen        = ci_fifo_dout[CI_ALEN_MSB:CI_ALEN_LSB];
    assign o_ci_lossy       = i_cfg_ci_lossy;
    assign o_ci_alpha_mode  = i_cfg_ci_alpha_mode;
    assign o_ci_sb          = i_cfg_ci_sb;
    assign o_tile_coord_vld = ci_fifo_rd_en;
    assign o_tile_format    = ci_fifo_dout[CI_FORMAT_MSB:CI_FORMAT_LSB];
    assign o_tile_x_coord   = ci_fifo_dout[CI_X_MSB:CI_X_LSB];
    assign o_tile_y_coord   = ci_fifo_dout[CI_Y_MSB:CI_Y_LSB];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_req_addr_reg         <= {AXI_AW{1'b0}};
            ar_req_beats_left_reg   <= 4'd0;
            payload_beats_left_reg  <= 4'd0;
        end else if (frame_start) begin
            ar_req_addr_reg         <= {AXI_AW{1'b0}};
            ar_req_beats_left_reg   <= 4'd0;
            payload_beats_left_reg  <= 4'd0;
        end else begin
            if (ci_fifo_rd_en && ci_fifo_has_payload) begin
                // Start the payload read only after the matching CI/header entry
                // has been consumed, so payload beats can never outrun headers.
                ar_req_addr_reg        <= ci_fifo_addr;
                ar_req_beats_left_reg  <= ci_payload_beats;
                payload_beats_left_reg <= ci_payload_beats;
            end else begin
                if (ar_fire) begin
                    ar_req_addr_reg       <= ar_req_addr_reg + {{(AXI_AW-9){1'b0}}, ar_issue_beats, 5'b0};
                    ar_req_beats_left_reg <= ar_req_beats_left_reg - ar_issue_beats;
                end

                if (r_fire) begin
                    if (payload_beats_left_reg <= 4'd1) begin
                        payload_beats_left_reg <= 4'd0;
                    end else begin
                        payload_beats_left_reg <= payload_beats_left_reg - 4'd1;
                    end
                end
            end
        end
    end

    assign m_axi_arvalid    = (ar_req_beats_left_reg != 4'd0);
    assign m_axi_araddr     = ar_req_addr_reg;
    assign m_axi_arlen      = {4'd0, ar_issue_beats} - 8'd1;
    assign m_axi_arsize     = AXI_ARSIZE;
    assign m_axi_arburst    = 2'b01;
    assign m_axi_arid       = {AXI_IDW{1'b0}};

    // Drain any stale return beats that can appear across frame boundaries,
    // but only forward beats when a tile payload is actually outstanding.
    assign m_axi_rready     = payload_active ? i_cvi_ready : 1'b1;
    assign o_cvi_valid      = m_axi_rvalid && payload_active;
    assign o_cvi_data       = m_axi_rdata;
    assign o_cvi_last       = m_axi_rlast && payload_active;
    assign o_busy           = dec_meta_valid | tile_cmd_valid | !ci_fifo_empty |
                              (ar_req_beats_left_reg != 4'd0) |
                              (payload_beats_left_reg != 4'd0) |
                              m_axi_arvalid | m_axi_rvalid | o_ci_valid | o_cvi_valid;

    wire unused_meta_error = fifo_meta_error;
    wire unused_meta_eol = fifo_meta_eol;
    wire unused_meta_last_pass = fifo_meta_last_pass;
    wire unused_meta_format_match = (fifo_meta_format == META_FMT_NV12_Y) ||
                                    (fifo_meta_format == META_FMT_NV12_UV) ||
                                    (fifo_meta_format == META_FMT_NV16_Y) ||
                                    (fifo_meta_format == META_FMT_NV16_UV) ||
                                    (fifo_meta_format == META_FMT_NV16_10_Y) ||
                                    (fifo_meta_format == META_FMT_NV16_10_UV) ||
                                    (fifo_meta_format == META_FMT_P010_Y) ||
                                    (fifo_meta_format == META_FMT_P010_UV) ||
                                    (fifo_meta_format == META_FMT_RGBA8888) ||
                                    (fifo_meta_format == META_FMT_RGBA1010102);
    wire unused_axi_rside = |m_axi_rid | |m_axi_rresp | m_axi_rlast | unused_meta_error |
                            unused_meta_eol | unused_meta_last_pass | unused_meta_format_match;

endmodule
