//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : OpenAI Codex
// Module Name       : ubwc_axi_wr_256to64.v
// Description       :
//   Single-burst AXI write downsizer used by UBWC wrappers.
//
//   Core side stays at 256-bit beats.
//   External AXI master side is exposed as 64-bit beats.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_axi_wr_256to64 #(
    parameter integer ADDR_WIDTH  = 64,
    parameter integer ID_WIDTH    = 7,
    parameter integer AXI_LENW    = 8,
    parameter integer CORE_AXI_DW = 256,
    parameter integer M_AXI_DW    = 64
) (
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire [ID_WIDTH-1:0]          s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]        s_axi_awaddr,
    input  wire [AXI_LENW-1:0]          s_axi_awlen,
    input  wire [2:0]                   s_axi_awsize,
    input  wire [1:0]                   s_axi_awburst,
    input  wire [1:0]                   s_axi_awlock,
    input  wire [3:0]                   s_axi_awcache,
    input  wire [2:0]                   s_axi_awprot,
    input  wire                         s_axi_awvalid,
    output wire                         s_axi_awready,

    input  wire [CORE_AXI_DW-1:0]       s_axi_wdata,
    input  wire [(CORE_AXI_DW/8)-1:0]   s_axi_wstrb,
    input  wire                         s_axi_wlast,
    input  wire                         s_axi_wvalid,
    output wire                         s_axi_wready,

    output wire [ID_WIDTH-1:0]          s_axi_bid,
    output wire [1:0]                   s_axi_bresp,
    output wire                         s_axi_bvalid,
    input  wire                         s_axi_bready,

    output wire [ID_WIDTH-1:0]          m_axi_awid,
    output wire [ADDR_WIDTH-1:0]        m_axi_awaddr,
    output wire [AXI_LENW-1:0]          m_axi_awlen,
    output wire [2:0]                   m_axi_awsize,
    output wire [1:0]                   m_axi_awburst,
    output wire [1:0]                   m_axi_awlock,
    output wire [3:0]                   m_axi_awcache,
    output wire [2:0]                   m_axi_awprot,
    output wire                         m_axi_awvalid,
    input  wire                         m_axi_awready,

    output wire [M_AXI_DW-1:0]          m_axi_wdata,
    output wire [(M_AXI_DW/8)-1:0]      m_axi_wstrb,
    output wire                         m_axi_wvalid,
    output wire                         m_axi_wlast,
    input  wire                         m_axi_wready,

    input  wire [ID_WIDTH-1:0]          m_axi_bid,
    input  wire [1:0]                   m_axi_bresp,
    input  wire                         m_axi_bvalid,
    output wire                         m_axi_bready
);

    localparam integer RATIO           = CORE_AXI_DW / M_AXI_DW;
    localparam integer RATIO_W         = (RATIO <= 1) ? 1 : $clog2(RATIO);
    localparam integer CORE_BEAT_W     = AXI_LENW + 1;
    localparam integer EXT_BEAT_BYTES  = M_AXI_DW / 8;
    localparam integer EXT_SIZE_VALUE  = $clog2(EXT_BEAT_BYTES);
    localparam integer CORE_SIZE_VALUE = $clog2(CORE_AXI_DW / 8);
    localparam integer MAX_EXT_BEATS   = 32;
    localparam integer MAX_CORE_BEATS  = MAX_EXT_BEATS / RATIO;

    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_AW   = 3'd1;
    localparam [2:0] ST_W    = 3'd2;
    localparam [2:0] ST_B    = 3'd3;
    localparam [2:0] ST_RSP  = 3'd4;

    reg [2:0]                     state_r;
    reg [ID_WIDTH-1:0]            awid_r;
    reg [ADDR_WIDTH-1:0]          awaddr_r;
    reg [AXI_LENW-1:0]            awlen_r;
    reg [2:0]                     awsize_r;
    reg [1:0]                     awburst_r;
    reg [1:0]                     awlock_r;
    reg [3:0]                     awcache_r;
    reg [2:0]                     awprot_r;
    reg [CORE_BEAT_W-1:0]         core_beats_total_r;
    reg [CORE_BEAT_W-1:0]         core_beats_left_r;
    reg                           wbuf_valid_r;
    reg [CORE_AXI_DW-1:0]         wbuf_data_r;
    reg [(CORE_AXI_DW/8)-1:0]     wbuf_strb_r;
    reg                           wbuf_last_r;
    reg [RATIO_W-1:0]             lane_idx_r;
    reg                           s_bvalid_r;
    reg [ID_WIDTH-1:0]            s_bid_r;
    reg [1:0]                     s_bresp_r;

    wire                          s_aw_fire_w = s_axi_awvalid && s_axi_awready;
    wire                          m_aw_fire_w = m_axi_awvalid && m_axi_awready;
    wire                          s_w_fire_w  = s_axi_wvalid && s_axi_wready;
    wire                          m_w_fire_w  = m_axi_wvalid && m_axi_wready;
    wire                          m_b_fire_w  = m_axi_bvalid && m_axi_bready;
    wire                          s_b_fire_w  = s_bvalid_r && s_axi_bready;
    wire                          narrow_mode_w = (awsize_r == EXT_SIZE_VALUE[2:0]);
    wire [AXI_LENW+2:0]           ext_beats_total_w =
                                  narrow_mode_w ? core_beats_total_r : (core_beats_total_r * RATIO);
    wire [RATIO_W-1:0]            narrow_lane_idx_w;

    function automatic [RATIO_W-1:0] first_active_lane;
        input [(CORE_AXI_DW/8)-1:0] strb_bits;
        integer idx;
        reg found;
        begin
            first_active_lane = {RATIO_W{1'b0}};
            found = 1'b0;
            for (idx = 0; idx < RATIO; idx = idx + 1) begin
                if (!found && |strb_bits[idx*(M_AXI_DW/8) +: (M_AXI_DW/8)]) begin
                    first_active_lane = idx[RATIO_W-1:0];
                    found = 1'b1;
                end
            end
        end
    endfunction

    assign narrow_lane_idx_w = first_active_lane(wbuf_strb_r);

    assign s_axi_awready = (state_r == ST_IDLE);
    assign s_axi_wready  = (state_r == ST_W) && !wbuf_valid_r;
    assign s_axi_bid     = s_bid_r;
    assign s_axi_bresp   = s_bresp_r;
    assign s_axi_bvalid  = s_bvalid_r;

    assign m_axi_awid    = awid_r;
    assign m_axi_awaddr  = awaddr_r;
    assign m_axi_awlen   = ext_beats_total_w[AXI_LENW-1:0] - {{AXI_LENW-1{1'b0}}, 1'b1};
    assign m_axi_awsize  = EXT_SIZE_VALUE[2:0];
    assign m_axi_awburst = awburst_r;
    assign m_axi_awlock  = awlock_r;
    assign m_axi_awcache = awcache_r;
    assign m_axi_awprot  = awprot_r;
    assign m_axi_awvalid = (state_r == ST_AW);

    assign m_axi_wdata   = narrow_mode_w
                         ? wbuf_data_r[narrow_lane_idx_w*M_AXI_DW +: M_AXI_DW]
                         : wbuf_data_r[lane_idx_r*M_AXI_DW +: M_AXI_DW];
    assign m_axi_wstrb   = narrow_mode_w
                         ? wbuf_strb_r[narrow_lane_idx_w*(M_AXI_DW/8) +: (M_AXI_DW/8)]
                         : wbuf_strb_r[lane_idx_r*(M_AXI_DW/8) +: (M_AXI_DW/8)];
    assign m_axi_wvalid  = (state_r == ST_W) && wbuf_valid_r;
    assign m_axi_wlast   = (state_r == ST_W) && wbuf_valid_r &&
                           (core_beats_left_r == {{CORE_BEAT_W-1{1'b0}}, 1'b1}) &&
                           (narrow_mode_w || (lane_idx_r == (RATIO - 1)));
    assign m_axi_bready  = (state_r == ST_B) && !s_bvalid_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r           <= ST_IDLE;
            awid_r            <= {ID_WIDTH{1'b0}};
            awaddr_r          <= {ADDR_WIDTH{1'b0}};
            awlen_r           <= {AXI_LENW{1'b0}};
            awsize_r          <= EXT_SIZE_VALUE[2:0];
            awburst_r         <= 2'b01;
            awlock_r          <= 2'b00;
            awcache_r         <= 4'b0000;
            awprot_r          <= 3'b000;
            core_beats_total_r<= {CORE_BEAT_W{1'b0}};
            core_beats_left_r <= {CORE_BEAT_W{1'b0}};
            wbuf_valid_r      <= 1'b0;
            wbuf_data_r       <= {CORE_AXI_DW{1'b0}};
            wbuf_strb_r       <= {(CORE_AXI_DW/8){1'b0}};
            wbuf_last_r       <= 1'b0;
            lane_idx_r        <= {RATIO_W{1'b0}};
            s_bvalid_r        <= 1'b0;
            s_bid_r           <= {ID_WIDTH{1'b0}};
            s_bresp_r         <= 2'b00;
        end else begin
            if (s_b_fire_w) begin
                s_bvalid_r <= 1'b0;
                s_bid_r    <= {ID_WIDTH{1'b0}};
                s_bresp_r  <= 2'b00;
                state_r    <= ST_IDLE;
            end

            case (state_r)
                ST_IDLE: begin
                    lane_idx_r   <= {RATIO_W{1'b0}};
                    wbuf_valid_r <= 1'b0;
                    wbuf_last_r  <= 1'b0;
                    if (s_aw_fire_w) begin
                        awid_r             <= s_axi_awid;
                        awaddr_r           <= s_axi_awaddr;
                        awlen_r            <= s_axi_awlen;
                        awsize_r           <= s_axi_awsize;
                        awburst_r          <= s_axi_awburst;
                        awlock_r           <= s_axi_awlock;
                        awcache_r          <= s_axi_awcache;
                        awprot_r           <= s_axi_awprot;
                        core_beats_total_r <= {{1'b0}, s_axi_awlen} + {{CORE_BEAT_W-1{1'b0}}, 1'b1};
                        core_beats_left_r  <= {{1'b0}, s_axi_awlen} + {{CORE_BEAT_W-1{1'b0}}, 1'b1};
                        state_r            <= ST_AW;
                        if (({{1'b0}, s_axi_awlen} + {{AXI_LENW{1'b0}}, 1'b1}) > MAX_CORE_BEATS)
                            $display("[%0t] WARN: ubwc_axi_wr_256to64 saw core burst len=%0d (> %0d beats), external 64-bit burst may exceed 32 beats.",
                                     $time, s_axi_awlen, MAX_CORE_BEATS);
                        if ((s_axi_awsize != CORE_SIZE_VALUE[2:0]) &&
                            (s_axi_awsize != EXT_SIZE_VALUE[2:0]))
                            $display("[%0t] WARN: ubwc_axi_wr_256to64 core AWSIZE=%0d, expected %0d or %0d.",
                                     $time, s_axi_awsize, CORE_SIZE_VALUE, EXT_SIZE_VALUE);
                    end
                end

                ST_AW: begin
                    if (m_aw_fire_w) begin
                        lane_idx_r <= {RATIO_W{1'b0}};
                        state_r    <= ST_W;
                    end
                end

                ST_W: begin
                    if (s_w_fire_w) begin
                        wbuf_valid_r <= 1'b1;
                        wbuf_data_r  <= s_axi_wdata;
                        wbuf_strb_r  <= s_axi_wstrb;
                        wbuf_last_r  <= s_axi_wlast;
                        lane_idx_r   <= {RATIO_W{1'b0}};
                    end

                    if (m_w_fire_w) begin
                        if (narrow_mode_w) begin
                            wbuf_valid_r <= 1'b0;
                            lane_idx_r   <= {RATIO_W{1'b0}};
                            if (core_beats_left_r == {{CORE_BEAT_W-1{1'b0}}, 1'b1}) begin
                                core_beats_left_r <= {CORE_BEAT_W{1'b0}};
                                state_r           <= ST_B;
                                if (!wbuf_last_r)
                                    $display("[%0t] WARN: ubwc_axi_wr_256to64 expected core WLAST on final 256-bit beat.", $time);
                            end else begin
                                core_beats_left_r <= core_beats_left_r - {{CORE_BEAT_W-1{1'b0}}, 1'b1};
                            end
                        end else begin
                            if (lane_idx_r == (RATIO - 1)) begin
                                wbuf_valid_r <= 1'b0;
                                lane_idx_r   <= {RATIO_W{1'b0}};
                                if (core_beats_left_r == {{CORE_BEAT_W-1{1'b0}}, 1'b1}) begin
                                    core_beats_left_r <= {CORE_BEAT_W{1'b0}};
                                    state_r           <= ST_B;
                                    if (!wbuf_last_r)
                                        $display("[%0t] WARN: ubwc_axi_wr_256to64 expected core WLAST on final 256-bit beat.", $time);
                                end else begin
                                    core_beats_left_r <= core_beats_left_r - {{CORE_BEAT_W-1{1'b0}}, 1'b1};
                                end
                            end else begin
                                lane_idx_r <= lane_idx_r + {{RATIO_W-1{1'b0}}, 1'b1};
                            end
                        end
                    end
                end

                ST_B: begin
                    if (m_b_fire_w) begin
                        s_bvalid_r <= 1'b1;
                        s_bid_r    <= m_axi_bid;
                        s_bresp_r  <= m_axi_bresp;
                        state_r    <= ST_RSP;
                    end
                end

                ST_RSP: begin
                    if (!s_bvalid_r)
                        state_r <= ST_IDLE;
                end

                default: begin
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
