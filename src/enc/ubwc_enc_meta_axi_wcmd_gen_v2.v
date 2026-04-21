//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : OpenAI Codex
// Create Date       : 2026-04-17
// Module Name       : ubwc_enc_meta_axi_wcmd_gen_v2
// Description       :
//   V2 metadata AXI write command generator.
//
//   Compared with the original packet-oriented implementation, V2 treats every
//   incoming 64-bit metadata word as an independent addressed write:
//     - input stream carries {valid, addr, data}
//     - each accepted word is expanded to one AXI write beat
//     - AXI AWADDR is aligned to AXI beat bytes
//     - only the selected 64-bit lane is marked valid in WSTRB
//
//   This matches a single meta_addr_gen instance that may generate explicit zero
//   padding words anywhere in the metadata address space.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_enc_meta_axi_wcmd_gen_v2
#(
    parameter   AXI_AW          = 64,
    parameter   AXI_DW          = 256,
    parameter   AXI_LENW        = 8,
    parameter   AXI_IDW         = 6,
    parameter   META_DW         = 64,
    parameter   REQ_FIFO_DEPTH  = 64,
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

localparam integer AXI_STRB_W       = AXI_DW/8;
localparam integer AXI_BEAT_BYTES   = AXI_DW/8;
localparam integer META_BYTES       = META_DW/8;
localparam integer AXI_SIZE_VALUE   = $clog2(AXI_BEAT_BYTES);
localparam integer BEAT_BYTE_LG2    = $clog2(AXI_BEAT_BYTES);
localparam integer META_BYTE_LG2    = $clog2(META_BYTES);
localparam integer LANE_COUNT       = AXI_DW/META_DW;
localparam integer LANE_IDX_W       = (LANE_COUNT <= 1) ? 1 : $clog2(LANE_COUNT);
localparam integer REQ_FIFO_W       = AXI_AW + AXI_STRB_W + AXI_DW;

wire [LANE_IDX_W-1:0] req_lane_w;
wire [AXI_AW-1:0]     req_addr_aligned_w;
wire [AXI_DW-1:0]     req_wdata_w;
wire [AXI_STRB_W-1:0] req_wstrb_w;
wire [REQ_FIFO_W-1:0] req_fifo_push_data;
wire [REQ_FIFO_W-1:0] req_fifo_pop_data;
wire                  req_fifo_push_ready;
wire                  req_fifo_pop_valid;
wire                  req_fifo_pop_ready;
wire                  req_accept_w;
wire                  req_load_w;

reg                   curr_valid_r;
reg                   curr_aw_done_r;
reg                   curr_w_done_r;
reg  [AXI_AW-1:0]     curr_awaddr_r;
reg  [AXI_DW-1:0]     curr_wdata_r;
reg  [AXI_STRB_W-1:0] curr_wstrb_r;

wire                  aw_fire_w;
wire                  w_fire_w;
wire                  b_fire_w;

function automatic [AXI_DW-1:0] place_meta_word;
    input [META_DW-1:0]           meta_word;
    input [LANE_IDX_W-1:0]        lane_idx;
    integer                       idx;
    reg   [AXI_DW-1:0]            data_out;
    begin
        data_out = {AXI_DW{1'b0}};
        for (idx = 0; idx < LANE_COUNT; idx = idx + 1) begin
            if (lane_idx == idx[LANE_IDX_W-1:0])
                data_out[idx*META_DW +: META_DW] = meta_word;
        end
        place_meta_word = data_out;
    end
endfunction

function automatic [AXI_STRB_W-1:0] place_meta_strb;
    input [LANE_IDX_W-1:0]         lane_idx;
    integer                        idx;
    reg   [AXI_STRB_W-1:0]         strb_out;
    begin
        strb_out = {AXI_STRB_W{1'b0}};
        for (idx = 0; idx < LANE_COUNT; idx = idx + 1) begin
            if (lane_idx == idx[LANE_IDX_W-1:0])
                strb_out[idx*META_BYTES +: META_BYTES] = {META_BYTES{1'b1}};
        end
        place_meta_strb = strb_out;
    end
endfunction

assign req_lane_w         = i_meta_addr[BEAT_BYTE_LG2-1:META_BYTE_LG2];
assign req_addr_aligned_w = {i_meta_addr[AXI_AW-1:BEAT_BYTE_LG2], {BEAT_BYTE_LG2{1'b0}}};
assign req_wdata_w        = place_meta_word(i_meta_data, req_lane_w);
assign req_wstrb_w        = place_meta_strb(req_lane_w);
assign req_fifo_push_data = {req_addr_aligned_w, req_wstrb_w, req_wdata_w};

assign o_meta_ready = req_fifo_push_ready;
assign req_accept_w = i_meta_valid && o_meta_ready;

ubwc_sync_fifo_fwft #(
    .DATA_WIDTH (REQ_FIFO_W),
    .DEPTH      (REQ_FIFO_DEPTH)
) u_req_fifo (
    .clk          (i_aclk),
    .rstn         (i_aresetn),
    .i_push_valid (req_accept_w),
    .o_push_ready (req_fifo_push_ready),
    .i_push_data  (req_fifo_push_data),
    .o_pop_valid  (req_fifo_pop_valid),
    .i_pop_ready  (req_fifo_pop_ready),
    .o_pop_data   (req_fifo_pop_data)
);

assign req_fifo_pop_ready = ~curr_valid_r;
assign req_load_w         = req_fifo_pop_valid && req_fifo_pop_ready;

assign aw_fire_w = curr_valid_r && ~curr_aw_done_r && i_m_axi_awready;
assign w_fire_w  = curr_valid_r && ~curr_w_done_r  && i_m_axi_wready;
assign b_fire_w  = curr_valid_r &&  curr_aw_done_r && curr_w_done_r && i_m_axi_bvalid;

always @(posedge i_aclk or negedge i_aresetn) begin
    if (!i_aresetn) begin
        curr_valid_r  <= 1'b0;
        curr_aw_done_r<= 1'b0;
        curr_w_done_r <= 1'b0;
        curr_awaddr_r <= {AXI_AW{1'b0}};
        curr_wdata_r  <= {AXI_DW{1'b0}};
        curr_wstrb_r  <= {AXI_STRB_W{1'b0}};
    end else begin
        if (b_fire_w) begin
            curr_valid_r   <= 1'b0;
            curr_aw_done_r <= 1'b0;
            curr_w_done_r  <= 1'b0;
            curr_awaddr_r  <= {AXI_AW{1'b0}};
            curr_wdata_r   <= {AXI_DW{1'b0}};
            curr_wstrb_r   <= {AXI_STRB_W{1'b0}};
        end else if (req_load_w) begin
            curr_valid_r   <= 1'b1;
            curr_aw_done_r <= 1'b0;
            curr_w_done_r  <= 1'b0;
            curr_awaddr_r  <= req_fifo_pop_data[REQ_FIFO_W-1 -: AXI_AW];
            curr_wstrb_r   <= req_fifo_pop_data[AXI_DW + AXI_STRB_W-1 -: AXI_STRB_W];
            curr_wdata_r   <= req_fifo_pop_data[AXI_DW-1:0];
        end else begin
            if (aw_fire_w)
                curr_aw_done_r <= 1'b1;
            if (w_fire_w)
                curr_w_done_r <= 1'b1;
        end
    end
end

assign o_m_axi_awid    = AXI_ID_VALUE[AXI_IDW-1:0];
assign o_m_axi_awaddr  = curr_awaddr_r;
assign o_m_axi_awlen   = {AXI_LENW{1'b0}};
assign o_m_axi_awsize  = AXI_SIZE_VALUE[2:0];
assign o_m_axi_awburst = 2'b01;
assign o_m_axi_awlock  = 2'b00;
assign o_m_axi_awcache = 4'b0011;
assign o_m_axi_awprot  = 3'b000;
assign o_m_axi_awvalid = curr_valid_r && ~curr_aw_done_r;

assign o_m_axi_wdata   = curr_wdata_r;
assign o_m_axi_wstrb   = curr_wstrb_r;
assign o_m_axi_wvalid  = curr_valid_r && ~curr_w_done_r;
assign o_m_axi_wlast   = 1'b1;

assign o_m_axi_bready  = 1'b1;

wire unused_meta_last = i_meta_last;
wire unused_bid_bits  = ^i_m_axi_bid;
wire unused_bresp_bits= ^i_m_axi_bresp;

endmodule
