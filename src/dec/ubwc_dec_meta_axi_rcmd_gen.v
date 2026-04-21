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
    parameter DATA_WIDTH = 256  // Data width: 256-bit
)(
    input  wire                   clk,
    input  wire                   rst_n,
    
    // Control signal
    input  wire                   start,    // start=1 pulse resets internal state and clears counters

    // --- AXI read address channel (Master interface) ---
    output wire                   m_axi_arvalid,
    input  wire                   m_axi_arready,
    output wire [ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]             m_axi_arlen,
    output wire [2:0]             m_axi_arsize,  // Fixed at 3'b101 (32 Bytes)
    output wire [1:0]             m_axi_arburst, // Fixed at 2'b01 (INCR)
    output wire [ID_WIDTH-1:0]    m_axi_arid,

    // --- AXI read data channel (monitor-only input) ---
    input  wire                   m_axi_rvalid,
    input  wire                   m_axi_rready,  // Driven by another module, monitored here only
    input  wire [ID_WIDTH-1:0]    m_axi_rid,
    input  wire [1:0]             m_axi_rresp,   // 00:OKAY, 01:EXOKAY, 10:SLVERR, 11:DECERR
    input  wire                   m_axi_rlast,

    // --- Internal command input ---
    input  wire                   in_cmd_en,
    output wire                   in_cmd_ready,
    input  wire [ADDR_WIDTH-1:0]  in_cmd_addr,
    input  wire [7:0]             in_cmd_len,

    // -- status interface
    output reg  [31:0]            error_cnt,     // Incremented if FIFO is not empty when start pulses
    output reg  [31:0]            cmd_ok_cnt,    // Successful AXI read transaction count
    output reg  [31:0]            cmd_fail_cnt   // Failed AXI read transaction count
);

    // --- Internal signals ---
    localparam integer BYTES_PER_BEAT = DATA_WIDTH / 8;
    localparam integer ARSIZE_VALUE   = $clog2(BYTES_PER_BEAT);

    wire        fifo_empty;
    wire        fifo_full;
    wire        fifo_rd_en;
    wire [ADDR_WIDTH+7:0] fifo_dout;
    wire [ADDR_WIDTH-1:0] fifo_cmd_addr;
    wire [7:0]            fifo_cmd_len_bytes;
    wire                  rid_match;
    
    // --- 1. FIFO storage logic ---
    // The start pulse acts as a synchronous clear for the FIFO pointers
    sync_fifo #(
        .DATA_WIDTH(ADDR_WIDTH + 8),
        .DEPTH(16)
    ) u_cmd_fifo (
        .clk      (clk),
        .rst_n    (rst_n),
        .clr      (start),
        .wr_en    (in_cmd_en && in_cmd_ready),
        .din      ({in_cmd_addr, in_cmd_len}),
        .rd_en    (fifo_rd_en),
        .dout     (fifo_dout),
        .empty    (fifo_empty),
        .full     (fifo_full)
    );

    // --- 2. AXI AR channel drive ---
    assign in_cmd_ready  = rst_n && !start && !fifo_full;
    assign m_axi_arvalid = rst_n && !start && !fifo_empty;
    assign {fifo_cmd_addr, fifo_cmd_len_bytes} = fifo_dout;
    assign m_axi_araddr = fifo_cmd_addr;
    assign m_axi_arlen  = (fifo_cmd_len_bytes == 8'd0) ? 8'd0 :
                          ((fifo_cmd_len_bytes - 8'd1) >> ARSIZE_VALUE);
    
    // AXI parameter configuration
    assign m_axi_arsize  = ARSIZE_VALUE[2:0];
    assign m_axi_arburst = 2'b01;            // INCR mode
    assign m_axi_arid    = {ID_WIDTH{1'b0}}; 
    
    // Pop the next FIFO command when the handshake succeeds
    assign fifo_rd_en    = m_axi_arvalid && m_axi_arready;

    assign rid_match = (m_axi_rid == {ID_WIDTH{1'b0}});

    // --- 3. Status evaluation and counter control ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_cnt    <= 32'd0;
            cmd_ok_cnt   <= 32'd0;
            cmd_fail_cnt <= 32'd0;
        end else if (start) begin
            // When the start pulse arrives:
            // 1. Force-clear the AXI success/failure counters
            cmd_ok_cnt   <= 32'd0;
            cmd_fail_cnt <= 32'd0;
            // 2. Error check: increment error_cnt if FIFO still contains pending data
            if (!fifo_empty) begin
                error_cnt <= error_cnt + 1'b1;
            end
        end else begin
            // Normal operation: monitor the R channel to determine transaction result
            // This module does not drive rready, but it uses (valid & ready) and rlast to detect completion
            if (m_axi_rvalid && m_axi_rready && m_axi_rlast && rid_match) begin
                if (m_axi_rresp == 2'b00 || m_axi_rresp == 2'b01) begin
                    cmd_ok_cnt <= cmd_ok_cnt + 1'b1;
                end else begin
                    // Capture SLVERR (10) or DECERR (11)
                    cmd_fail_cnt <= cmd_fail_cnt + 1'b1;
                end
            end
        end
    end

endmodule
