//////////////////////////////////////////////////////////////////////////////////
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-03-29  15:57:57
// Module Name       : ubwc_dec_meta_axi_rcmd_gen.v
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_dec_meta_axi_rcmd_gen #(
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter DATA_WIDTH = 256,
    parameter TW_DW      = 16,
    parameter TH_DW      = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Control signal
    input  wire                   start,

    // --- AXI read address channel (Master interface) ---
    output wire                   m_axi_arvalid,
    input  wire                   m_axi_arready,
    output wire [ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]             m_axi_arlen,
    output wire [2:0]             m_axi_arsize,
    output wire [1:0]             m_axi_arburst,
    output wire [ID_WIDTH-1:0]    m_axi_arid,

    // --- AXI read data channel ---
    input  wire                   m_axi_rvalid,
    output wire                   m_axi_rready,
    input  wire [DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [ID_WIDTH-1:0]    m_axi_rid,
    input  wire [1:0]             m_axi_rresp,
    input  wire                   m_axi_rlast,

    // --- Metadata group input ---
    input  wire                   meta_grp_valid,
    output wire                   meta_grp_ready,
    input  wire [ADDR_WIDTH-1:0]  meta_grp_addr,
    input  wire [4:0]             meta_format,
    input  wire [TW_DW-1:0]       meta_xcoord,
    input  wire [TH_DW-1:0]       meta_ycoord,

    // --- 8-bit metadata output stream ---
    output wire                   meta_data_valid,
    input  wire                   meta_data_ready,
    output reg  [7:0]             meta_data,
    output wire [4:0]             meta_data_format,
    output wire [TW_DW-1:0]       meta_data_xcoord,
    output wire [TH_DW-1:0]       meta_data_ycoord,

    // -- status interface
    output reg  [31:0]            error_cnt,
    output reg  [31:0]            cmd_ok_cnt,
    output reg  [31:0]            cmd_fail_cnt
);

    localparam integer BYTES_PER_BEAT = DATA_WIDTH / 8;
    localparam integer ARSIZE_VALUE   = $clog2(BYTES_PER_BEAT);
    localparam integer META_DESC_W    = 5 + TW_DW + TH_DW;
    localparam integer CMD_FIFO_W     = ADDR_WIDTH + 2 + META_DESC_W;
    localparam integer RSP_FIFO_W     = 2 + META_DESC_W;
    localparam integer OUT_FIFO_W     = 64 + META_DESC_W;

    wire                  cmd_fifo_empty;
    wire                  cmd_fifo_full;
    wire                  cmd_fifo_prog_full;
    wire                  cmd_fifo_valid;
    wire                  cmd_fifo_rd_en;
    wire [CMD_FIFO_W-1:0] cmd_fifo_dout;
    wire [4:0]            cmd_fifo_data_count;
    wire [ADDR_WIDTH-1:0] cmd_fifo_addr;
    wire [1:0]            cmd_fifo_lane_sel;
    wire [4:0]            cmd_fifo_meta_format;
    wire [TW_DW-1:0]      cmd_fifo_meta_xcoord;
    wire [TH_DW-1:0]      cmd_fifo_meta_ycoord;

    wire                  rsp_fifo_empty;
    wire                  rsp_fifo_full;
    wire                  rsp_fifo_prog_full;
    wire                  rsp_fifo_valid;
    wire                  rsp_fifo_wr_en;
    wire                  rsp_fifo_rd_en;
    wire [RSP_FIFO_W-1:0] rsp_fifo_dout;
    wire [4:0]            rsp_fifo_data_count;
    wire [1:0]            rsp_lane_sel;
    wire [4:0]            rsp_meta_format;
    wire [TW_DW-1:0]      rsp_meta_xcoord;
    wire [TH_DW-1:0]      rsp_meta_ycoord;

    wire                  out_fifo_empty;
    wire                  out_fifo_full;
    wire                  out_fifo_prog_full;
    wire                  out_fifo_valid;
    wire                  out_fifo_wr_en;
    wire                  out_fifo_rd_en;
    wire [OUT_FIFO_W-1:0] out_fifo_dout;
    wire [5:0]            out_fifo_data_count;
    wire [63:0]           out_meta_group_data;
    wire [4:0]            out_meta_format;
    wire [TW_DW-1:0]      out_meta_xcoord;
    wire [TH_DW-1:0]      out_meta_ycoord;

    wire [ADDR_WIDTH-1:0] aligned_cmd_addr;
    wire [1:0]            cmd_lane_sel;
    wire                  cmd_addr_unaligned;
    wire                  meta_fetch_ready;
    wire [63:0]           selected_rdata;
    wire                  rid_match;
    wire                  r_fire;
    wire                  fifo_status_seen;
    reg  [2:0]            byte_idx;

    assign aligned_cmd_addr = {meta_grp_addr[ADDR_WIDTH-1:5], 5'd0};
    assign cmd_lane_sel     = meta_grp_addr[4:3];
    assign cmd_addr_unaligned = |meta_grp_addr[2:0];
    assign fifo_status_seen = cmd_fifo_prog_full | (|cmd_fifo_data_count) |
                              rsp_fifo_prog_full | (|rsp_fifo_data_count) |
                              out_fifo_prog_full | (|out_fifo_data_count);

    assign meta_fetch_ready = meta_data_ready && cmd_fifo_empty && rsp_fifo_empty && out_fifo_empty;
    assign meta_grp_ready = rst_n && !start && meta_fetch_ready &&
                            !cmd_fifo_full && !rsp_fifo_full && !out_fifo_full;

    mg_sync_fifo #(
        .PROG_DEPTH (1),
        .DWIDTH     (CMD_FIFO_W),
        .DEPTH      (16),
        .SHOW_AHEAD (1)
    ) u_cmd_fifo (
        .clk        (clk),
        .rst_n      (rst_n && !start),
        .wr_en      (meta_grp_valid && meta_grp_ready),
        .din        ({aligned_cmd_addr, cmd_lane_sel, meta_format, meta_xcoord, meta_ycoord}),
        .prog_full  (cmd_fifo_prog_full),
        .full       (cmd_fifo_full),
        .rd_en      (cmd_fifo_rd_en),
        .empty      (cmd_fifo_empty),
        .dout       (cmd_fifo_dout),
        .valid      (cmd_fifo_valid),
        .data_count (cmd_fifo_data_count)
    );

    assign {
        cmd_fifo_addr,
        cmd_fifo_lane_sel,
        cmd_fifo_meta_format,
        cmd_fifo_meta_xcoord,
        cmd_fifo_meta_ycoord
    } = cmd_fifo_dout;

    assign m_axi_arvalid = rst_n && !start && cmd_fifo_valid && !rsp_fifo_full;
    assign m_axi_araddr  = cmd_fifo_addr;
    assign m_axi_arlen   = 8'd0;
    assign m_axi_arsize  = ARSIZE_VALUE[2:0];
    assign m_axi_arburst = 2'b01;
    assign m_axi_arid    = {ID_WIDTH{1'b0}};
    assign cmd_fifo_rd_en = m_axi_arvalid && m_axi_arready;
    assign rsp_fifo_wr_en = cmd_fifo_rd_en;

    mg_sync_fifo #(
        .PROG_DEPTH (1),
        .DWIDTH     (RSP_FIFO_W),
        .DEPTH      (16),
        .SHOW_AHEAD (1)
    ) u_rsp_info_fifo (
        .clk        (clk),
        .rst_n      (rst_n && !start),
        .wr_en      (rsp_fifo_wr_en),
        .din        ({cmd_fifo_lane_sel, cmd_fifo_meta_format, cmd_fifo_meta_xcoord, cmd_fifo_meta_ycoord}),
        .prog_full  (rsp_fifo_prog_full),
        .full       (rsp_fifo_full),
        .rd_en      (rsp_fifo_rd_en),
        .empty      (rsp_fifo_empty),
        .dout       (rsp_fifo_dout),
        .valid      (rsp_fifo_valid),
        .data_count (rsp_fifo_data_count)
    );

    assign {
        rsp_lane_sel,
        rsp_meta_format,
        rsp_meta_xcoord,
        rsp_meta_ycoord
    } = rsp_fifo_dout;

    assign rid_match    = (m_axi_rid == {ID_WIDTH{1'b0}});
    assign m_axi_rready = rst_n && !start && rsp_fifo_valid && !out_fifo_full;
    assign r_fire       = m_axi_rvalid && m_axi_rready;
    assign rsp_fifo_rd_en = r_fire;

    assign selected_rdata =
        (rsp_lane_sel == 2'd0) ? m_axi_rdata[ 63:  0] :
        (rsp_lane_sel == 2'd1) ? m_axi_rdata[127: 64] :
        (rsp_lane_sel == 2'd2) ? m_axi_rdata[191:128] :
                                 m_axi_rdata[255:192];

    assign out_fifo_wr_en = r_fire;

    mg_sync_fifo #(
        .PROG_DEPTH (1),
        .DWIDTH     (OUT_FIFO_W),
        .DEPTH      (32),
        .SHOW_AHEAD (1)
    ) u_meta_data_fifo (
        .clk        (clk),
        .rst_n      (rst_n && !start),
        .wr_en      (out_fifo_wr_en),
        .din        ({selected_rdata, rsp_meta_format, rsp_meta_xcoord, rsp_meta_ycoord}),
        .prog_full  (out_fifo_prog_full),
        .full       (out_fifo_full),
        .rd_en      (out_fifo_rd_en),
        .empty      (out_fifo_empty),
        .dout       (out_fifo_dout),
        .valid      (out_fifo_valid),
        .data_count (out_fifo_data_count)
    );

    assign meta_data_valid = out_fifo_valid;
    assign out_fifo_rd_en  = meta_data_valid && meta_data_ready && (byte_idx == 3'd7);
    assign {
        out_meta_group_data,
        out_meta_format,
        out_meta_xcoord,
        out_meta_ycoord
    } = out_fifo_dout;
    assign meta_data_format = out_meta_format;
    assign meta_data_xcoord = out_meta_xcoord + {{(TW_DW-3){1'b0}}, byte_idx};
    assign meta_data_ycoord = out_meta_ycoord;

    always @* begin
        case (byte_idx)
            3'd0: meta_data = out_meta_group_data[ 7: 0];
            3'd1: meta_data = out_meta_group_data[15: 8];
            3'd2: meta_data = out_meta_group_data[23:16];
            3'd3: meta_data = out_meta_group_data[31:24];
            3'd4: meta_data = out_meta_group_data[39:32];
            3'd5: meta_data = out_meta_group_data[47:40];
            3'd6: meta_data = out_meta_group_data[55:48];
            default: meta_data = out_meta_group_data[63:56];
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_idx <= 3'd0;
        end else if (start) begin
            byte_idx <= 3'd0;
        end else if (meta_data_valid && meta_data_ready) begin
            byte_idx <= (byte_idx == 3'd7) ? 3'd0 : (byte_idx + 1'b1);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_cnt    <= 32'd0;
            cmd_ok_cnt   <= 32'd0;
            cmd_fail_cnt <= 32'd0;
        end else if (start) begin
            cmd_ok_cnt   <= 32'd0;
            cmd_fail_cnt <= 32'd0;
            if (!cmd_fifo_empty || !rsp_fifo_empty || !out_fifo_empty) begin
                error_cnt <= error_cnt + 1'b1;
            end
        end else if (meta_grp_valid && meta_grp_ready && (cmd_addr_unaligned | (fifo_status_seen & 1'b0))) begin
            error_cnt <= error_cnt + 32'd1;
        end else if (r_fire && m_axi_rlast && rid_match) begin
            if (m_axi_rresp == 2'b00 || m_axi_rresp == 2'b01) begin
                cmd_ok_cnt <= cmd_ok_cnt + 1'b1;
            end else begin
                cmd_fail_cnt <= cmd_fail_cnt + 1'b1;
            end
        end else if (r_fire && m_axi_rlast && !rid_match) begin
            cmd_fail_cnt <= cmd_fail_cnt + 1'b1;
        end
    end

endmodule
