//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-03-11  07:09:22
// Module Name       : ubwc_tile_enc_axi_wcmd_gen.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
//  
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module ubwc_tile_enc_axi_wcmd_gen #(
    parameter SB_WIDTH  = 1,
    parameter AXI_AW    = 64,
    parameter AXI_DW    = 256,
    parameter AXI_LENW  = 8,
    parameter AXI_IDW   = 6,
    parameter CMD_DEPTH = 8,
    parameter DATA_DEPTH = 16
) (
    input   wire                        i_aclk,
    input   wire                        i_aresetn,

    input   wire    [28 -1:0]           i_tile_addr,
    input   wire    [3  -1:0]           i_tile_alen,
    input   wire                        i_tile_addr_vld,

    input   wire                        i_cvo_valid,
    output  wire                        o_cvo_ready,
    input   wire    [255:0]             i_cvo_data,
    input   wire    [31:0]              i_cvo_mask,
    input   wire                        i_cvo_last,

    output  wire    [AXI_IDW-1:0]       o_m_axi_awid,
    output  wire    [AXI_AW -1:0]       o_m_axi_awaddr,
    output  wire    [AXI_LENW-1:0]      o_m_axi_awlen,
    output  wire    [2:0]               o_m_axi_awsize,
    output  wire    [1:0]               o_m_axi_awburst,
    output  wire    [1:0]               o_m_axi_awlock,
    output  wire    [3:0]               o_m_axi_awcache,
    output  wire    [2:0]               o_m_axi_awprot,
    output  wire                        o_m_axi_awvalid,
    input   wire                        i_m_axi_awready,

    output  wire    [AXI_DW-1:0]        o_m_axi_wdata,
    output  wire    [AXI_DW/8-1:0]      o_m_axi_wstrb,
    output  wire                        o_m_axi_wvalid,
    output  wire                        o_m_axi_wlast,
    input   wire                        i_m_axi_wready,

    input   wire    [AXI_IDW-1:0]       i_m_axi_bid,
    input   wire    [1:0]               i_m_axi_bresp,
    input   wire                        i_m_axi_bvalid,
    output  wire                        o_m_axi_bready
);
    localparam integer CMD_PTR_W        = $clog2(CMD_DEPTH);
    localparam integer DATA_PTR_W       = $clog2(DATA_DEPTH);
    localparam integer BEAT_BYTES       = AXI_DW / 8;
    localparam integer BEAT_BYTE_LG2    = $clog2(BEAT_BYTES);
    localparam integer BEATCNT_W        = AXI_LENW + 1;
    localparam [2:0]   AXI_SIZE_W       = 3'($clog2(AXI_DW / 8));
    localparam [12:0]  BEAT_BYTES_M1_W  = 13'(BEAT_BYTES - 1);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_AW   = 2'd1;
    localparam [1:0] ST_W    = 2'd2;

    reg [27:0] cmd_addr_mem [0:CMD_DEPTH-1];
    reg [3:0]  cmd_len_mem  [0:CMD_DEPTH-1];
    reg [CMD_PTR_W:0] cmd_count_r;
    reg [CMD_PTR_W-1:0] cmd_wr_ptr_r, cmd_rd_ptr_r;

    reg [255:0] data_mem [0:DATA_DEPTH-1];
    reg [31:0]  strb_mem [0:DATA_DEPTH-1];
    reg [DATA_PTR_W:0] data_count_r;
    reg [DATA_PTR_W-1:0] data_wr_ptr_r, data_rd_ptr_r;

    reg [1:0]               state_r;
    reg [AXI_AW-1:0]        burst_addr_r;
    reg [BEATCNT_W-1:0]     burst_beats_r;
    reg [BEATCNT_W-1:0]     burst_sent_beats_r;
    reg                     split_pending_r;
    reg [AXI_AW-1:0]        second_burst_addr_r;
    reg [BEATCNT_W-1:0]     second_burst_beats_r;

    wire cmd_push  = i_tile_addr_vld && (cmd_count_r < CMD_DEPTH);
    wire data_push = i_cvo_valid && o_cvo_ready;

    wire cmd_avail  = (cmd_count_r != 0);
    wire data_avail = (data_count_r != 0);

    wire [AXI_AW-1:0]    cmd_start_addr_w  = {{(AXI_AW-32){1'b0}}, cmd_addr_mem[cmd_rd_ptr_r], 4'b0000};
    wire [BEATCNT_W-1:0] cmd_total_beats_w = {{(BEATCNT_W-4){1'b0}}, cmd_len_mem[cmd_rd_ptr_r]} +
                                             {{(BEATCNT_W-1){1'b0}}, 1'b1};

    wire aw_fire_w = (state_r == ST_AW) && i_m_axi_awready;
    wire w_fire_w  = (state_r == ST_W)  && data_avail && i_m_axi_wready;

    wire [BEATCNT_W-1:0] one_beat_w             = {{(BEATCNT_W-1){1'b0}}, 1'b1};
    wire [13:0]          cmd_total_bytes_w      = {cmd_total_beats_w, {BEAT_BYTE_LG2{1'b0}}};
    wire [12:0]          bytes_to_4k_w          = 13'd4096 - {1'b0, cmd_start_addr_w[11:0]};
    wire [12:0]          bytes_to_4k_ceil_w     = bytes_to_4k_w + BEAT_BYTES_M1_W;
    wire [12:0]          first_burst_beats_calc_w =
                                                  (({1'b0, cmd_start_addr_w[11:0]} + cmd_total_bytes_w) > 14'd4096) ?
                                                  (bytes_to_4k_ceil_w >> BEAT_BYTE_LG2) :
                                                  {{(13-BEATCNT_W){1'b0}}, cmd_total_beats_w};
    wire [BEATCNT_W-1:0] first_burst_beats_w    = first_burst_beats_calc_w[BEATCNT_W-1:0];
    wire [BEATCNT_W-1:0] second_burst_beats_w   = cmd_total_beats_w - first_burst_beats_w;
    wire [AXI_AW-1:0]    first_burst_bytes_w    = {{(AXI_AW-BEATCNT_W){1'b0}}, first_burst_beats_w} << BEAT_BYTE_LG2;
    wire [AXI_AW-1:0]    second_burst_addr_w    = cmd_start_addr_w + first_burst_bytes_w;
    wire                 cmd_crosses_4k_w       = (second_burst_beats_w != {BEATCNT_W{1'b0}});
    wire                 burst_last_beat_w      = (burst_sent_beats_r == (burst_beats_r - one_beat_w));

    assign o_cvo_ready     = (data_count_r < DATA_DEPTH);
    assign o_m_axi_awid    = {AXI_IDW{1'b0}};
    assign o_m_axi_awaddr  = burst_addr_r;
    assign o_m_axi_awlen   = burst_beats_r[AXI_LENW-1:0] - {{(AXI_LENW-1){1'b0}}, 1'b1};
    assign o_m_axi_awsize  = AXI_SIZE_W;
    assign o_m_axi_awburst = 2'b01;
    assign o_m_axi_awlock  = 2'b00;
    assign o_m_axi_awcache = 4'b0011;
    assign o_m_axi_awprot  = 3'b000;
    assign o_m_axi_awvalid = (state_r == ST_AW);

    assign o_m_axi_wdata   = data_mem[data_rd_ptr_r];
    assign o_m_axi_wstrb   = strb_mem[data_rd_ptr_r];
    assign o_m_axi_wvalid  = (state_r == ST_W) && data_avail;
    assign o_m_axi_wlast   = (state_r == ST_W) && data_avail && burst_last_beat_w;
    assign o_m_axi_bready  = 1'b1;

    always @(posedge i_aclk or negedge i_aresetn) begin
        if (!i_aresetn) begin
            cmd_count_r        <= '0;
            cmd_wr_ptr_r       <= '0;
            cmd_rd_ptr_r       <= '0;
            data_count_r       <= '0;
            data_wr_ptr_r      <= '0;
            data_rd_ptr_r      <= '0;
            state_r            <= ST_IDLE;
            burst_addr_r       <= '0;
            burst_beats_r      <= '0;
            burst_sent_beats_r <= '0;
            split_pending_r    <= 1'b0;
            second_burst_addr_r<= '0;
            second_burst_beats_r <= '0;
        end else begin
            if (cmd_push) begin
                cmd_addr_mem[cmd_wr_ptr_r] <= i_tile_addr;
                cmd_len_mem [cmd_wr_ptr_r] <= {1'b0, i_tile_alen};
                cmd_wr_ptr_r               <= cmd_wr_ptr_r + 1'b1;
            end
            if ((state_r == ST_IDLE) && cmd_avail) begin
                cmd_rd_ptr_r <= cmd_rd_ptr_r + 1'b1;
            end

            case ({cmd_push, ((state_r == ST_IDLE) && cmd_avail)})
                2'b10: cmd_count_r <= cmd_count_r + 1'b1;
                2'b01: cmd_count_r <= cmd_count_r - 1'b1;
                default: cmd_count_r <= cmd_count_r;
            endcase

            if (data_push) begin
                data_mem [data_wr_ptr_r] <= i_cvo_data;
                strb_mem [data_wr_ptr_r] <= i_cvo_mask;
                data_wr_ptr_r            <= data_wr_ptr_r + 1'b1;
            end
            if (w_fire_w) begin
                data_rd_ptr_r <= data_rd_ptr_r + 1'b1;
            end

            case ({data_push, w_fire_w})
                2'b10: data_count_r <= data_count_r + 1'b1;
                2'b01: data_count_r <= data_count_r - 1'b1;
                default: data_count_r <= data_count_r;
            endcase

            case (state_r)
                ST_IDLE: begin
                    burst_sent_beats_r <= '0;
                    if (cmd_avail) begin
                        burst_addr_r         <= cmd_start_addr_w;
                        burst_beats_r        <= first_burst_beats_w;
                        split_pending_r      <= cmd_crosses_4k_w;
                        second_burst_addr_r  <= second_burst_addr_w;
                        second_burst_beats_r <= second_burst_beats_w;
                        state_r              <= ST_AW;
                    end
                end

                ST_AW: begin
                    if (aw_fire_w) begin
                        burst_sent_beats_r <= '0;
                        state_r            <= ST_W;
                    end
                end

                ST_W: begin
                    if (w_fire_w) begin
                        if (burst_last_beat_w) begin
                            if (split_pending_r) begin
                                burst_addr_r       <= second_burst_addr_r;
                                burst_beats_r      <= second_burst_beats_r;
                                burst_sent_beats_r <= '0;
                                split_pending_r    <= 1'b0;
                                state_r            <= ST_AW;
                            end else begin
                                burst_beats_r      <= '0;
                                burst_sent_beats_r <= '0;
                                state_r            <= ST_IDLE;
                            end
                        end else begin
                            burst_sent_beats_r <= burst_sent_beats_r + one_beat_w;
                        end
                    end
                end

                default: begin
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
