//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : OpenAI Codex
// Module Name       : ubwc_axi_wr_64to256.v
// Description       :
//   AXI write upsizer used by the UBWC metadata path.
//
//   The source side stays in 64-bit metadata semantics.
//   The destination side exposes a 256-bit AXI bus, but no write packing is
//   performed here. Each incoming 64-bit beat is mapped into the matching
//   256-bit lane and only the corresponding WSTRB bytes are asserted.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_axi_wr_64to256 #(
    parameter integer ADDR_WIDTH = 64,
    parameter integer ID_WIDTH   = 6,
    parameter integer AXI_LENW   = 8,
    parameter integer S_AXI_DW   = 64,
    parameter integer M_AXI_DW   = 256
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

    input  wire [S_AXI_DW-1:0]          s_axi_wdata,
    input  wire [(S_AXI_DW/8)-1:0]      s_axi_wstrb,
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

    localparam integer RATIO          = M_AXI_DW / S_AXI_DW;
    localparam integer RATIO_W        = (RATIO <= 1) ? 1 : $clog2(RATIO);
    localparam integer S_BYTE_LG2     = $clog2(S_AXI_DW / 8);
    localparam integer M_BYTE_LG2     = $clog2(M_AXI_DW / 8);
    localparam integer BEATCNT_W      = AXI_LENW + 1;
    localparam [2:0] S_SIZE_VALUE     = 3'($clog2(S_AXI_DW / 8));

    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_AW   = 3'd1;
    localparam [2:0] ST_W    = 3'd2;
    localparam [2:0] ST_B    = 3'd3;
    localparam [2:0] ST_RSP  = 3'd4;

    reg [2:0]                 state_r;
    reg [ID_WIDTH-1:0]        awid_r;
    reg [ADDR_WIDTH-1:0]      awaddr_r;
    reg [AXI_LENW-1:0]        awlen_r;
    reg [2:0]                 awsize_r;
    reg [1:0]                 awburst_r;
    reg [1:0]                 awlock_r;
    reg [3:0]                 awcache_r;
    reg [2:0]                 awprot_r;
    reg [BEATCNT_W-1:0]       beats_left_r;
    reg [RATIO_W-1:0]         lane_idx_r;
    reg                       wbuf_valid_r;
    reg [S_AXI_DW-1:0]        wbuf_data_r;
    reg [(S_AXI_DW/8)-1:0]    wbuf_strb_r;
    reg                       wbuf_last_r;
    reg                       s_bvalid_r;
    reg [ID_WIDTH-1:0]        s_bid_r;
    reg [1:0]                 s_bresp_r;

    wire                      s_aw_fire_w = s_axi_awvalid && s_axi_awready;
    wire                      m_aw_fire_w = m_axi_awvalid && m_axi_awready;
    wire                      s_w_fire_w  = s_axi_wvalid && s_axi_wready;
    wire                      m_w_fire_w  = m_axi_wvalid && m_axi_wready;
    wire                      m_b_fire_w  = m_axi_bvalid && m_axi_bready;
    wire                      s_b_fire_w  = s_bvalid_r && s_axi_bready;

    function automatic [RATIO_W-1:0] lane_from_addr;
        input [ADDR_WIDTH-1:0] addr;
        begin
            if (RATIO <= 1)
                lane_from_addr = {RATIO_W{1'b0}};
            else
                lane_from_addr = addr[S_BYTE_LG2 +: RATIO_W];
        end
    endfunction

    function automatic [M_AXI_DW-1:0] place_lane_data;
        input [RATIO_W-1:0] lane_idx;
        input [S_AXI_DW-1:0] lane_data;
        reg   [M_AXI_DW-1:0] tmp;
        begin
            tmp = {M_AXI_DW{1'b0}};
            tmp[lane_idx*S_AXI_DW +: S_AXI_DW] = lane_data;
            place_lane_data = tmp;
        end
    endfunction

    function automatic [(M_AXI_DW/8)-1:0] place_lane_strb;
        input [RATIO_W-1:0] lane_idx;
        input [(S_AXI_DW/8)-1:0] lane_strb;
        reg   [(M_AXI_DW/8)-1:0] tmp;
        begin
            tmp = {(M_AXI_DW/8){1'b0}};
            tmp[lane_idx*(S_AXI_DW/8) +: (S_AXI_DW/8)] = lane_strb;
            place_lane_strb = tmp;
        end
    endfunction

    assign s_axi_awready = (state_r == ST_IDLE);
    assign s_axi_wready  = (state_r == ST_W) && !wbuf_valid_r;
    assign s_axi_bid     = s_bid_r;
    assign s_axi_bresp   = s_bresp_r;
    assign s_axi_bvalid  = s_bvalid_r;

    assign m_axi_awid    = awid_r;
    assign m_axi_awaddr  = awaddr_r;
    assign m_axi_awlen   = awlen_r;
    assign m_axi_awsize  = awsize_r;
    assign m_axi_awburst = awburst_r;
    assign m_axi_awlock  = awlock_r;
    assign m_axi_awcache = awcache_r;
    assign m_axi_awprot  = awprot_r;
    assign m_axi_awvalid = (state_r == ST_AW);

    assign m_axi_wdata   = place_lane_data(lane_idx_r, wbuf_data_r);
    assign m_axi_wstrb   = place_lane_strb(lane_idx_r, wbuf_strb_r);
    assign m_axi_wvalid  = (state_r == ST_W) && wbuf_valid_r;
    assign m_axi_wlast   = (state_r == ST_W) && wbuf_valid_r && wbuf_last_r;
    assign m_axi_bready  = (state_r == ST_B) && !s_bvalid_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r      <= ST_IDLE;
            awid_r       <= {ID_WIDTH{1'b0}};
            awaddr_r     <= {ADDR_WIDTH{1'b0}};
            awlen_r      <= {AXI_LENW{1'b0}};
            awsize_r     <= S_SIZE_VALUE;
            awburst_r    <= 2'b01;
            awlock_r     <= 2'b00;
            awcache_r    <= 4'b0000;
            awprot_r     <= 3'b000;
            beats_left_r <= {BEATCNT_W{1'b0}};
            lane_idx_r   <= {RATIO_W{1'b0}};
            wbuf_valid_r <= 1'b0;
            wbuf_data_r  <= {S_AXI_DW{1'b0}};
            wbuf_strb_r  <= {(S_AXI_DW/8){1'b0}};
            wbuf_last_r  <= 1'b0;
            s_bvalid_r   <= 1'b0;
            s_bid_r      <= {ID_WIDTH{1'b0}};
            s_bresp_r    <= 2'b00;
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
                        awid_r       <= s_axi_awid;
                        awaddr_r     <= s_axi_awaddr;
                        awlen_r      <= s_axi_awlen;
                        awsize_r     <= s_axi_awsize;
                        awburst_r    <= s_axi_awburst;
                        awlock_r     <= s_axi_awlock;
                        awcache_r    <= s_axi_awcache;
                        awprot_r     <= s_axi_awprot;
                        beats_left_r <= {{1'b0}, s_axi_awlen} + {{BEATCNT_W-1{1'b0}}, 1'b1};
                        lane_idx_r   <= lane_from_addr(s_axi_awaddr);
                        state_r      <= ST_AW;
`ifndef SYNTHESIS
                        if (s_axi_awsize != S_SIZE_VALUE)
                            $display("[%0t] WARN: ubwc_axi_wr_64to256 expected 64-bit AWSIZE=%0d, got %0d.",
                                     $time, S_SIZE_VALUE, s_axi_awsize);
`endif
                    end
                end

                ST_AW: begin
                    if (m_aw_fire_w)
                        state_r <= ST_W;
                end

                ST_W: begin
                    if (s_w_fire_w) begin
                        wbuf_valid_r <= 1'b1;
                        wbuf_data_r  <= s_axi_wdata;
                        wbuf_strb_r  <= s_axi_wstrb;
                        wbuf_last_r  <= s_axi_wlast;
                    end

                    if (m_w_fire_w) begin
                        wbuf_valid_r <= 1'b0;
                        if (beats_left_r == {{BEATCNT_W-1{1'b0}}, 1'b1}) begin
                            beats_left_r <= {BEATCNT_W{1'b0}};
                            state_r      <= ST_B;
`ifndef SYNTHESIS
                            if (!wbuf_last_r)
                                $display("[%0t] WARN: ubwc_axi_wr_64to256 expected WLAST on final 64-bit beat.", $time);
`endif
                        end else begin
                            beats_left_r <= beats_left_r - {{BEATCNT_W-1{1'b0}}, 1'b1};
                            lane_idx_r   <= lane_idx_r + {{RATIO_W-1{1'b0}}, 1'b1};
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
