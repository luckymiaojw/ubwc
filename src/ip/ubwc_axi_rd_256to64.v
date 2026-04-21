//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : OpenAI Codex
// Module Name       : ubwc_axi_rd_256to64.v
// Description       :
//   Single-burst AXI read downsizer used by UBWC wrappers.
//
//   Core side stays at 256-bit beats.
//   External AXI master side is exposed as 64-bit beats.
//
//   The wrapper read interconnect already guarantees only one inflight read, so
//   this adapter only needs to track a single burst at a time.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_axi_rd_256to64 #(
    parameter integer ADDR_WIDTH  = 64,
    parameter integer ID_WIDTH    = 7,
    parameter integer AXI_LENW    = 8,
    parameter integer CORE_AXI_DW = 256,
    parameter integer M_AXI_DW    = 64
) (
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire [ID_WIDTH-1:0]          s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]        s_axi_araddr,
    input  wire [AXI_LENW-1:0]          s_axi_arlen,
    input  wire [3:0]                   s_axi_arsize,
    input  wire [1:0]                   s_axi_arburst,
    input  wire                         s_axi_arvalid,
    output wire                         s_axi_arready,

    output wire [CORE_AXI_DW-1:0]       s_axi_rdata,
    output wire [1:0]                   s_axi_rresp,
    output wire                         s_axi_rlast,
    output wire                         s_axi_rvalid,
    input  wire                         s_axi_rready,

    output wire [ID_WIDTH-1:0]          m_axi_arid,
    output wire [ADDR_WIDTH-1:0]        m_axi_araddr,
    output wire [AXI_LENW-1:0]          m_axi_arlen,
    output wire [3:0]                   m_axi_arsize,
    output wire [1:0]                   m_axi_arburst,
    output wire                         m_axi_arvalid,
    input  wire                         m_axi_arready,

    input  wire [M_AXI_DW-1:0]          m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,
    input  wire                         m_axi_rvalid,
    output wire                         m_axi_rready
);

    localparam integer RATIO           = CORE_AXI_DW / M_AXI_DW;
    localparam integer RATIO_W         = (RATIO <= 1) ? 1 : $clog2(RATIO);
    localparam integer CORE_BEAT_W     = AXI_LENW + 1;
    localparam integer EXT_BEAT_BYTES  = M_AXI_DW / 8;
    localparam integer EXT_SIZE_VALUE  = $clog2(EXT_BEAT_BYTES);
    localparam integer MAX_EXT_BEATS   = 32;
    localparam integer MAX_CORE_BEATS  = MAX_EXT_BEATS / RATIO;

    reg [ID_WIDTH-1:0]            arid_r;
    reg [ADDR_WIDTH-1:0]          araddr_r;
    reg [AXI_LENW-1:0]            arlen_r;
    reg [1:0]                     arburst_r;
    reg                           arvalid_r;
    reg                           req_active_r;
    reg [CORE_BEAT_W-1:0]         core_beats_left_r;
    reg [RATIO_W-1:0]             lane_idx_r;
    reg [CORE_AXI_DW-1:0]         assemble_data_r;
    reg [1:0]                     assemble_resp_r;
    reg [CORE_AXI_DW-1:0]         rsp_data_r;
    reg [1:0]                     rsp_resp_r;
    reg                           rsp_last_r;
    reg                           rsp_valid_r;

    wire [CORE_BEAT_W-1:0]        core_beats_total_w = {{1'b0}, arlen_r} + {{CORE_BEAT_W-1{1'b0}}, 1'b1};
    wire [AXI_LENW+2:0]           ext_beats_total_w  = core_beats_total_w * RATIO;
    wire                          s_ar_fire_w        = s_axi_arvalid && s_axi_arready;
    wire                          m_ar_fire_w        = arvalid_r && m_axi_arready;
    wire                          m_r_fire_w         = req_active_r && !rsp_valid_r && m_axi_rvalid;
    wire                          s_r_fire_w         = rsp_valid_r && s_axi_rready;

    function automatic [CORE_AXI_DW-1:0] write_lane_data;
        input [CORE_AXI_DW-1:0] curr_data;
        input [M_AXI_DW-1:0]    lane_data;
        input integer           lane_idx;
        begin
            write_lane_data = curr_data;
            write_lane_data[lane_idx*M_AXI_DW +: M_AXI_DW] = lane_data;
        end
    endfunction

    assign s_axi_arready = !arvalid_r && !req_active_r && !rsp_valid_r;
    assign s_axi_rdata   = rsp_data_r;
    assign s_axi_rresp   = rsp_resp_r;
    assign s_axi_rlast   = rsp_last_r;
    assign s_axi_rvalid  = rsp_valid_r;

    assign m_axi_arid    = arid_r;
    assign m_axi_araddr  = araddr_r;
    assign m_axi_arlen   = ext_beats_total_w[AXI_LENW-1:0] - {{AXI_LENW-1{1'b0}}, 1'b1};
    assign m_axi_arsize  = EXT_SIZE_VALUE[3:0];
    assign m_axi_arburst = arburst_r;
    assign m_axi_arvalid = arvalid_r;
    assign m_axi_rready  = req_active_r && !rsp_valid_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arid_r           <= {ID_WIDTH{1'b0}};
            araddr_r         <= {ADDR_WIDTH{1'b0}};
            arlen_r          <= {AXI_LENW{1'b0}};
            arburst_r        <= 2'b01;
            arvalid_r        <= 1'b0;
            req_active_r     <= 1'b0;
            core_beats_left_r<= {CORE_BEAT_W{1'b0}};
            lane_idx_r       <= {RATIO_W{1'b0}};
            assemble_data_r  <= {CORE_AXI_DW{1'b0}};
            assemble_resp_r  <= 2'b00;
            rsp_data_r       <= {CORE_AXI_DW{1'b0}};
            rsp_resp_r       <= 2'b00;
            rsp_last_r       <= 1'b0;
            rsp_valid_r      <= 1'b0;
        end else begin
            if (s_r_fire_w) begin
                rsp_valid_r <= 1'b0;
                rsp_data_r  <= {CORE_AXI_DW{1'b0}};
                rsp_resp_r  <= 2'b00;
                rsp_last_r  <= 1'b0;
            end

            if (s_ar_fire_w) begin
                arid_r    <= s_axi_arid;
                araddr_r  <= s_axi_araddr;
                arlen_r   <= s_axi_arlen;
                arburst_r <= s_axi_arburst;
                arvalid_r <= 1'b1;
                if (({{1'b0}, s_axi_arlen} + {{AXI_LENW{1'b0}}, 1'b1}) > MAX_CORE_BEATS)
                    $display("[%0t] WARN: ubwc_axi_rd_256to64 saw core burst len=%0d (> %0d beats), external 64-bit burst may exceed 32 beats.",
                             $time, s_axi_arlen, MAX_CORE_BEATS);
                if (s_axi_arsize != $clog2(CORE_AXI_DW/8))
                    $display("[%0t] WARN: ubwc_axi_rd_256to64 core ARSIZE=%0d, expected %0d.",
                             $time, s_axi_arsize, $clog2(CORE_AXI_DW/8));
            end

            if (m_ar_fire_w) begin
                arvalid_r         <= 1'b0;
                req_active_r      <= 1'b1;
                core_beats_left_r <= core_beats_total_w;
                lane_idx_r        <= {RATIO_W{1'b0}};
                assemble_data_r   <= {CORE_AXI_DW{1'b0}};
                assemble_resp_r   <= 2'b00;
            end

            if (m_r_fire_w) begin
                if (lane_idx_r == (RATIO - 1)) begin
                    rsp_data_r      <= write_lane_data(assemble_data_r, m_axi_rdata, lane_idx_r);
                    rsp_resp_r      <= assemble_resp_r | m_axi_rresp;
                    rsp_last_r      <= (core_beats_left_r == {{CORE_BEAT_W-1{1'b0}}, 1'b1});
                    rsp_valid_r     <= 1'b1;
                    lane_idx_r      <= {RATIO_W{1'b0}};
                    assemble_data_r <= {CORE_AXI_DW{1'b0}};
                    assemble_resp_r <= 2'b00;

                    if (core_beats_left_r == {{CORE_BEAT_W-1{1'b0}}, 1'b1}) begin
                        req_active_r      <= 1'b0;
                        core_beats_left_r <= {CORE_BEAT_W{1'b0}};
                        if (!m_axi_rlast)
                            $display("[%0t] WARN: ubwc_axi_rd_256to64 expected external RLAST on final 64-bit beat.", $time);
                    end else begin
                        core_beats_left_r <= core_beats_left_r - {{CORE_BEAT_W-1{1'b0}}, 1'b1};
                    end
                end else begin
                    assemble_data_r <= write_lane_data(assemble_data_r, m_axi_rdata, lane_idx_r);
                    assemble_resp_r <= assemble_resp_r | m_axi_rresp;
                    lane_idx_r      <= lane_idx_r + {{RATIO_W-1{1'b0}}, 1'b1};
                end
            end
        end
    end

endmodule
