//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-03-11  07:19:23
// Module Name       : ubwc_enc_meta_axi_wcmd_gen.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//      Revision 1.00 - File Created by        : MiaoJiawang
//      Description                            :
//
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module ubwc_enc_meta_axi_wcmd_gen
#(
    parameter   AXI_AW          = 64,
    parameter   AXI_DW          = 256,
    parameter   AXI_LENW        = 8,
    parameter   AXI_IDW         = 6,
    parameter   META_DW         = 64,
    parameter   IN_FIFO_DEPTH   = 64,
    parameter   BEAT_FIFO_DEPTH = 32,
    parameter   PKT_FIFO_DEPTH  = 8,
    parameter   AXI_ID_VALUE    = 0
)(
    input   wire                                i_aclk,
    input   wire                                i_aresetn,

    input   wire                                i_meta_valid,
    input   wire                                i_meta_last,
    output  wire                                o_meta_ready,
    input   wire    [AXI_AW-1:0]                i_meta_addr,
    input   wire    [META_DW-1:0]               i_meta_data,

    output  wire    [AXI_IDW-1:0]               o_m_axi_awid,
    output  wire    [AXI_AW-1:0]                o_m_axi_awaddr,
    output  wire    [AXI_LENW-1:0]              o_m_axi_awlen,
    output  wire    [2:0]                       o_m_axi_awsize,
    output  wire    [1:0]                       o_m_axi_awburst,
    output  wire    [1:0]                       o_m_axi_awlock,
    output  wire    [3:0]                       o_m_axi_awcache,
    output  wire    [2:0]                       o_m_axi_awprot,
    output  wire                                o_m_axi_awvalid,
    input   wire                                i_m_axi_awready,

    output  wire    [AXI_DW-1:0]                o_m_axi_wdata,
    output  wire    [AXI_DW/8-1:0]              o_m_axi_wstrb,
    output  wire                                o_m_axi_wvalid,
    output  wire                                o_m_axi_wlast,
    input   wire                                i_m_axi_wready,

    input   wire    [AXI_IDW-1:0]               i_m_axi_bid,
    input   wire    [1:0]                       i_m_axi_bresp,
    input   wire                                i_m_axi_bvalid,
    output  wire                                o_m_axi_bready
);

localparam integer AXI_STRB_W      = AXI_DW/8;
localparam integer META_PER_BEAT   = AXI_DW/META_DW;
localparam integer PACK_IDX_W      = (META_PER_BEAT <= 1) ? 1 : $clog2(META_PER_BEAT);
localparam integer BYTE_PER_META   = META_DW/8;
localparam integer BEATCNT_W       = AXI_LENW + 1;
localparam integer BEAT_BYTES      = AXI_DW/8;
localparam integer BEAT_BYTE_LG2   = $clog2(BEAT_BYTES);
localparam integer WORDCNT_W       = AXI_LENW + PACK_IDX_W + 1;
localparam integer DATA_FIFO_W     = META_DW;
localparam integer CMD_FIFO_W      = AXI_AW + WORDCNT_W;
localparam integer AWCMD_FIFO_W    = AXI_AW + BEATCNT_W + WORDCNT_W;
localparam integer WDATA_FIFO_W    = 1 + AXI_STRB_W + AXI_DW;
localparam integer AW_FIFO_DEPTH   = (PKT_FIFO_DEPTH < 2) ? 2 : (PKT_FIFO_DEPTH * 2);
localparam [2:0]   AXI_SIZE_VALUE  = $clog2(AXI_DW/8);

localparam [1:0] ST_IDLE  = 2'd0;
localparam [1:0] ST_AW    = 2'd1;
localparam [1:0] ST_W     = 2'd2;
localparam [1:0] ST_B     = 2'd3;

assign o_m_axi_bready = 1'b1;

// -----------------------------------------------------------------------------
// 0) Input side
//    - 64-bit data goes into data FIFO.
//    - Packet boundary writes one command {start_addr, word_count} into cmd FIFO.
// -----------------------------------------------------------------------------
wire [DATA_FIFO_W-1:0] data_fifo_pop_data;
wire                   data_fifo_push_ready;
wire                   data_fifo_pop_valid;
wire                   data_fifo_pop_ready;
wire                   meta_accept_w;

wire [CMD_FIFO_W-1:0]  cmd_fifo_pop_data;
wire                   cmd_fifo_push_ready;
wire                   cmd_fifo_pop_valid;
wire                   cmd_fifo_pop_ready;

reg                    pkt_open_r;
reg  [AXI_AW-1:0]      pkt_start_addr_r;
reg  [WORDCNT_W-1:0]   pkt_word_cnt_r;

wire [WORDCNT_W-1:0]   pkt_word_cnt_next_w = pkt_word_cnt_r + {{(WORDCNT_W-1){1'b0}}, 1'b1};
wire [AXI_AW-1:0]      cmd_push_addr_w     = pkt_open_r ? pkt_start_addr_r : i_meta_addr;
wire [CMD_FIFO_W-1:0]  cmd_fifo_push_data  = {cmd_push_addr_w, pkt_word_cnt_next_w};
wire                   cmd_fifo_push_valid = meta_accept_w && i_meta_last;

assign o_meta_ready = data_fifo_push_ready && (!i_meta_last || cmd_fifo_push_ready);
assign meta_accept_w = i_meta_valid && o_meta_ready;

ubwc_sync_fifo_fwft #(
    .DATA_WIDTH (DATA_FIFO_W),
    .DEPTH      (IN_FIFO_DEPTH)
) u_data_fifo (
    .clk            (i_aclk),
    .rstn           (i_aresetn),
    .i_push_valid   (meta_accept_w),
    .o_push_ready   (data_fifo_push_ready),
    .i_push_data    (i_meta_data),
    .o_pop_valid    (data_fifo_pop_valid),
    .i_pop_ready    (data_fifo_pop_ready),
    .o_pop_data     (data_fifo_pop_data)
);

ubwc_sync_fifo_fwft #(
    .DATA_WIDTH (CMD_FIFO_W),
    .DEPTH      (PKT_FIFO_DEPTH)
) u_cmd_fifo (
    .clk            (i_aclk),
    .rstn           (i_aresetn),
    .i_push_valid   (cmd_fifo_push_valid),
    .o_push_ready   (cmd_fifo_push_ready),
    .i_push_data    (cmd_fifo_push_data),
    .o_pop_valid    (cmd_fifo_pop_valid),
    .i_pop_ready    (cmd_fifo_pop_ready),
    .o_pop_data     (cmd_fifo_pop_data)
);

wire [AXI_AW-1:0]    cmd_addr_w;
wire [WORDCNT_W-1:0] cmd_words_w;
assign {cmd_addr_w, cmd_words_w} = cmd_fifo_pop_data;

// -----------------------------------------------------------------------------
// 1) Command split
//    Split a packet command into one or two AXI bursts if it crosses 4KB.
// -----------------------------------------------------------------------------
wire [BEATCNT_W-1:0] cmd_beats_w = (cmd_words_w + META_PER_BEAT - 1) / META_PER_BEAT;
wire [13:0]          cmd_total_bytes_w = {cmd_beats_w, {BEAT_BYTE_LG2{1'b0}}};
wire [12:0]          bytes_to_4k_w      = 13'd4096 - {1'b0, cmd_addr_w[11:0]};
wire [12:0]          bytes_to_4k_ceil_w = bytes_to_4k_w + (BEAT_BYTES - 1);
wire [BEATCNT_W-1:0] first_burst_beats_w =
    (({1'b0, cmd_addr_w[11:0]} + cmd_total_bytes_w) > 14'd4096) ?
    (bytes_to_4k_ceil_w >> BEAT_BYTE_LG2) :
    cmd_beats_w;
wire [BEATCNT_W-1:0] second_burst_beats_w = cmd_beats_w - first_burst_beats_w;
wire [AXI_AW-1:0]    second_burst_addr_w  = cmd_addr_w + (first_burst_beats_w << BEAT_BYTE_LG2);
wire                 cmd_crosses_4k_w     = (second_burst_beats_w != {BEATCNT_W{1'b0}});

wire [WORDCNT_W-1:0] first_burst_word_cap_w = first_burst_beats_w * META_PER_BEAT;
wire [WORDCNT_W-1:0] first_burst_words_w =
    (cmd_words_w > first_burst_word_cap_w) ? first_burst_word_cap_w : cmd_words_w;
wire [WORDCNT_W-1:0] second_burst_words_w = cmd_words_w - first_burst_words_w;

wire [AWCMD_FIFO_W-1:0] aw_fifo_pop_data;
wire                    aw_fifo_push_ready;
wire                    aw_fifo_pop_valid;
wire                    aw_fifo_pop_ready;

reg                     split_second_pending_r;
reg [AXI_AW-1:0]        split_second_addr_r;
reg [BEATCNT_W-1:0]     split_second_beats_r;
reg [WORDCNT_W-1:0]     split_second_words_r;

wire                    aw_fifo_push_valid =
    split_second_pending_r || (!split_second_pending_r && cmd_fifo_pop_valid);
wire [AWCMD_FIFO_W-1:0] aw_fifo_push_data =
    split_second_pending_r ?
    {split_second_addr_r, split_second_beats_r, split_second_words_r} :
    {cmd_addr_w, first_burst_beats_w, first_burst_words_w};
wire                    cmd_fifo_pop_fire_w =
    !split_second_pending_r && cmd_fifo_pop_valid && aw_fifo_push_ready;

assign cmd_fifo_pop_ready = !split_second_pending_r && aw_fifo_push_ready;

ubwc_sync_fifo_fwft #(
    .DATA_WIDTH (AWCMD_FIFO_W),
    .DEPTH      (AW_FIFO_DEPTH)
) u_aw_fifo (
    .clk            (i_aclk),
    .rstn           (i_aresetn),
    .i_push_valid   (aw_fifo_push_valid),
    .o_push_ready   (aw_fifo_push_ready),
    .i_push_data    (aw_fifo_push_data),
    .o_pop_valid    (aw_fifo_pop_valid),
    .i_pop_ready    (aw_fifo_pop_ready),
    .o_pop_data     (aw_fifo_pop_data)
);

wire [AXI_AW-1:0]    aw_cmd_addr_w;
wire [BEATCNT_W-1:0] aw_cmd_beats_w;
wire [WORDCNT_W-1:0] aw_cmd_words_w;
assign {aw_cmd_addr_w, aw_cmd_beats_w, aw_cmd_words_w} = aw_fifo_pop_data;

// -----------------------------------------------------------------------------
// 2) Active burst context
// -----------------------------------------------------------------------------
reg [1:0]               state_r;
reg [AXI_AW-1:0]        burst_addr_r;
reg [BEATCNT_W-1:0]     burst_beats_r;
reg [WORDCNT_W-1:0]     burst_words_left_r;

// -----------------------------------------------------------------------------
// 3) Data FIFO -> WDATA FIFO
// -----------------------------------------------------------------------------
wire                    wdata_fifo_push_ready;
wire                    wdata_fifo_pop_valid;
wire                    wdata_fifo_pop_ready;
wire [WDATA_FIFO_W-1:0] wdata_fifo_pop_data;
wire                    wdata_fifo_out_last_w;
wire [AXI_STRB_W-1:0]   wdata_fifo_out_strb_w;
wire [AXI_DW-1:0]       wdata_fifo_out_data_w;

reg  [AXI_DW-1:0]       pack_data_r;
reg  [AXI_STRB_W-1:0]   pack_strb_r;
reg  [PACK_IDX_W-1:0]   pack_idx_r;
reg                     pack_active_r;

wire [AXI_DW-1:0]       pack_data_base_w =
    pack_active_r ? pack_data_r : {AXI_DW{1'b0}};
wire [AXI_STRB_W-1:0]   pack_strb_base_w =
    pack_active_r ? pack_strb_r : {AXI_STRB_W{1'b0}};
wire [AXI_DW-1:0]       pack_data_insert_w =
    pack_data_base_w | ({ {(AXI_DW-META_DW){1'b0}}, data_fifo_pop_data } << (pack_idx_r * META_DW));
wire [AXI_STRB_W-1:0]   pack_strb_insert_w =
    pack_strb_base_w | ({ {(AXI_STRB_W-BYTE_PER_META){1'b0}}, {BYTE_PER_META{1'b1}} } << (pack_idx_r * BYTE_PER_META));

wire                    pack_flush_w =
    data_fifo_pop_valid &&
    ((pack_active_r && (pack_idx_r == META_PER_BEAT-1)) ||
     (burst_words_left_r == {{(WORDCNT_W-1){1'b0}}, 1'b1}));
wire                    data_fifo_accept_w =
    (state_r == ST_W) &&
    (burst_words_left_r != {WORDCNT_W{1'b0}}) &&
    data_fifo_pop_valid &&
    (!pack_flush_w || wdata_fifo_push_ready);
wire                    wdata_fifo_push_valid = data_fifo_accept_w && pack_flush_w;
wire                    wdata_fifo_push_last_w =
    data_fifo_accept_w &&
    (burst_words_left_r == {{(WORDCNT_W-1){1'b0}}, 1'b1});
wire [WDATA_FIFO_W-1:0] wdata_fifo_push_data =
    {wdata_fifo_push_last_w, pack_strb_insert_w, pack_data_insert_w};

assign data_fifo_pop_ready = data_fifo_accept_w;

ubwc_sync_fifo_fwft #(
    .DATA_WIDTH (WDATA_FIFO_W),
    .DEPTH      (BEAT_FIFO_DEPTH)
) u_wdata_fifo (
    .clk            (i_aclk),
    .rstn           (i_aresetn),
    .i_push_valid   (wdata_fifo_push_valid),
    .o_push_ready   (wdata_fifo_push_ready),
    .i_push_data    (wdata_fifo_push_data),
    .o_pop_valid    (wdata_fifo_pop_valid),
    .i_pop_ready    (wdata_fifo_pop_ready),
    .o_pop_data     (wdata_fifo_pop_data)
);

// -----------------------------------------------------------------------------
// 4) AXI W channel
//    The packed-beat FIFO is the output FIFO. LAST is generated on push and
//    the FIFO head directly drives the AXI W channel.
// -----------------------------------------------------------------------------
wire                    aw_fire_w;
wire                    w_fire_w;
wire                    b_fire_w;

assign aw_fifo_pop_ready = (state_r == ST_IDLE);
assign aw_fire_w         = (state_r == ST_AW) && i_m_axi_awready;
assign w_fire_w          = wdata_fifo_pop_valid && i_m_axi_wready;
assign b_fire_w          = (state_r == ST_B) && i_m_axi_bvalid;

assign {wdata_fifo_out_last_w, wdata_fifo_out_strb_w, wdata_fifo_out_data_w} = wdata_fifo_pop_data;
assign wdata_fifo_pop_ready = i_m_axi_wready;

always @(posedge i_aclk or negedge i_aresetn) begin
    if (!i_aresetn) begin
        pkt_open_r             <= 1'b0;
        pkt_start_addr_r       <= {AXI_AW{1'b0}};
        pkt_word_cnt_r         <= {WORDCNT_W{1'b0}};
        split_second_pending_r <= 1'b0;
        split_second_addr_r    <= {AXI_AW{1'b0}};
        split_second_beats_r   <= {BEATCNT_W{1'b0}};
        split_second_words_r   <= {WORDCNT_W{1'b0}};
        state_r                <= ST_IDLE;
        burst_addr_r           <= {AXI_AW{1'b0}};
        burst_beats_r          <= {BEATCNT_W{1'b0}};
        burst_words_left_r     <= {WORDCNT_W{1'b0}};
        pack_data_r            <= {AXI_DW{1'b0}};
        pack_strb_r            <= {AXI_STRB_W{1'b0}};
        pack_idx_r             <= {PACK_IDX_W{1'b0}};
        pack_active_r          <= 1'b0;
    end else begin
        if (meta_accept_w) begin
            if (i_meta_last) begin
                pkt_open_r     <= 1'b0;
                pkt_word_cnt_r <= {WORDCNT_W{1'b0}};
            end else begin
                if (!pkt_open_r)
                    pkt_start_addr_r <= i_meta_addr;
                pkt_open_r     <= 1'b1;
                pkt_word_cnt_r <= pkt_word_cnt_next_w;
            end
        end

        if (split_second_pending_r && aw_fifo_push_ready)
            split_second_pending_r <= 1'b0;

        if (cmd_fifo_pop_fire_w && cmd_crosses_4k_w) begin
            split_second_pending_r <= 1'b1;
            split_second_addr_r    <= second_burst_addr_w;
            split_second_beats_r   <= second_burst_beats_w;
            split_second_words_r   <= second_burst_words_w;
        end

        if (data_fifo_accept_w) begin
            burst_words_left_r <= burst_words_left_r - {{(WORDCNT_W-1){1'b0}}, 1'b1};
            if (pack_flush_w) begin
                pack_data_r   <= {AXI_DW{1'b0}};
                pack_strb_r   <= {AXI_STRB_W{1'b0}};
                pack_idx_r    <= {PACK_IDX_W{1'b0}};
                pack_active_r <= 1'b0;
            end else begin
                pack_data_r   <= pack_data_insert_w;
                pack_strb_r   <= pack_strb_insert_w;
                pack_idx_r    <= pack_idx_r + {{(PACK_IDX_W-1){1'b0}}, 1'b1};
                pack_active_r <= 1'b1;
            end
        end

        case (state_r)
            ST_IDLE: begin
                if (aw_fifo_pop_valid) begin
                    burst_addr_r       <= aw_cmd_addr_w;
                    burst_beats_r      <= aw_cmd_beats_w;
                    burst_words_left_r <= aw_cmd_words_w;
                    pack_data_r        <= {AXI_DW{1'b0}};
                    pack_strb_r        <= {AXI_STRB_W{1'b0}};
                    pack_idx_r         <= {PACK_IDX_W{1'b0}};
                    pack_active_r      <= 1'b0;
                    state_r            <= ST_AW;
                end
            end

            ST_AW: begin
                if (aw_fire_w)
                    state_r <= ST_W;
            end

            ST_W: begin
                if (w_fire_w && wdata_fifo_out_last_w)
                    state_r <= ST_B;
            end

            ST_B: begin
                if (b_fire_w) begin
                    burst_beats_r   <= {BEATCNT_W{1'b0}};
                    state_r         <= ST_IDLE;
                end
            end

            default: begin
                state_r <= ST_IDLE;
            end
        endcase
    end
end

// -----------------------------------------------------------------------------
// 5) AXI outputs
// -----------------------------------------------------------------------------
assign o_m_axi_awid    = AXI_ID_VALUE[AXI_IDW-1:0];
assign o_m_axi_awaddr  = burst_addr_r;
assign o_m_axi_awlen   = burst_beats_r[AXI_LENW-1:0] - {{(AXI_LENW-1){1'b0}}, 1'b1};
assign o_m_axi_awsize  = AXI_SIZE_VALUE;
assign o_m_axi_awburst = 2'b01;
assign o_m_axi_awlock  = 2'b00;
assign o_m_axi_awcache = 4'b0011;
assign o_m_axi_awprot  = 3'b000;
assign o_m_axi_awvalid = (state_r == ST_AW);

assign o_m_axi_wdata   = wdata_fifo_out_data_w;
assign o_m_axi_wstrb   = wdata_fifo_out_strb_w;
assign o_m_axi_wvalid  = wdata_fifo_pop_valid;
assign o_m_axi_wlast   = wdata_fifo_out_last_w;

endmodule
