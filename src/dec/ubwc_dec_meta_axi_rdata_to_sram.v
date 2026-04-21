`timescale 1ns / 1ps

module ubwc_dec_meta_axi_rdata_to_sram #(
    parameter AXI_DATA_WIDTH = 256, 
    parameter SRAM_ADDR_W    = 12   
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      start,

    // --- External configuration ---
    input  wire [4:0]                base_format,            // Frame-level format only
    input  wire [15:0]               tile_x_numbers,         // Image tile columns
    input  wire [15:0]               tile_y_numbers,         // Image tile rows

    // --- Meta input interface ---
    input  wire                      meta_valid,
    output wire                      meta_ready,    
    input  wire [4:0]                meta_format,
    input  wire [15:0]               meta_xcoord,
    input  wire [15:0]               meta_ycoord,

    // --- AXI R input channel ---
    input  wire                      axi_rvalid,
    output wire                      axi_rready,   
    input  wire [AXI_DATA_WIDTH-1:0] axi_rdata,
    input  wire                      axi_rlast,

    // --- SRAM control interface ---
    input  wire                      bank_a_free,
    input  wire                      bank_b_free,
    output wire [3:0]                sram_we_a,   
    output wire [3:0]                sram_we_b,   
    output wire [SRAM_ADDR_W-1:0]    sram_addr,   
    output wire [AXI_DATA_WIDTH-1:0] sram_wdata,  

    // --- Downstream bfifo interface ---
    input  wire                      bfifo_prog_full, 
    output reg                       bfifo_we,
    output reg  [40:0]               bfifo_wdata,

    // --- Bank lifecycle ---
    output reg                       bank_fill_valid,
    output reg                       bank_fill_bank_b
);

    // -------------------------------------------------------------------------
    // 1. Internal signal definitions (data packing and handshake logic)
    // -------------------------------------------------------------------------
    
    // Meta FIFO signals
    wire [36:0] m_fifo_din;
    wire [36:0] m_fifo_dout;
    wire        m_fifo_wr_en;
    wire        m_fifo_rd_en;
    wire        m_fifo_empty;
    wire        m_fifo_full;

    // Data FIFO signals
    wire [AXI_DATA_WIDTH:0] d_fifo_din;
    wire [AXI_DATA_WIDTH:0] d_fifo_dout;
    wire        d_fifo_wr_en;
    wire        d_fifo_rd_en;
    wire        d_fifo_empty;
    wire        d_fifo_full;

    // Handshake and control logic extraction
    assign meta_ready   = rst_n && !start && !m_fifo_full;
    assign axi_rready   = rst_n && !start && !d_fifo_full;
    
    assign m_fifo_din   = {meta_format, meta_xcoord, meta_ycoord};
    assign m_fifo_wr_en = meta_valid && meta_ready;
    
    assign d_fifo_din   = {axi_rlast, axi_rdata};
    assign d_fifo_wr_en = axi_rvalid && axi_rready;

    // Core read control: both Data/Meta FIFOs contain data and downstream is not throttling
    wire target_bank_free;
    wire is_group_start;
    wire bank_reuse_block;
    assign d_fifo_rd_en = !d_fifo_empty && !m_fifo_empty && !bfifo_prog_full &&
                          !bank_reuse_block;
    
    // Decode Data FIFO output
    wire dout_rlast      = d_fifo_dout[AXI_DATA_WIDTH];
    wire [AXI_DATA_WIDTH-1:0] dout_rdata = d_fifo_dout[AXI_DATA_WIDTH-1:0];
    
    // -------------------------------------------------------------------------
    // 2. FIFO instantiation (pure signal wiring only)
    // -------------------------------------------------------------------------
    
    sync_fifo #(.DATA_WIDTH(37), .DEPTH(16)) u_meta_fifo (
        .clk    (clk),
        .rst_n  (rst_n && !start),
        .clr    (1'b0),
        .din    (m_fifo_din),
        .wr_en  (m_fifo_wr_en),
        .full   (m_fifo_full),
        .dout   (m_fifo_dout),
        .rd_en  (m_fifo_rd_en),
        .empty  (m_fifo_empty)
    );

    sync_fifo #(.DATA_WIDTH(AXI_DATA_WIDTH + 1), .DEPTH(32)) u_data_fifo (
        .clk    (clk),
        .rst_n  (rst_n && !start),
        .clr    (1'b0),
        .din    (d_fifo_din),
        .wr_en  (d_fifo_wr_en),
        .full   (d_fifo_full),
        .dout   (d_fifo_dout),
        .rd_en  (d_fifo_rd_en),
        .empty  (d_fifo_empty)
    );

    // -------------------------------------------------------------------------
    // 3. Internal processing logic (using decoded signals)
    // -------------------------------------------------------------------------
    
    wire [4:0]  curr_meta_format = m_fifo_dout[36:32];
    wire [15:0] curr_meta_xcoord = m_fifo_dout[31:16];
    wire [15:0] curr_meta_ycoord = m_fifo_dout[15:0];

    wire internal_handshake = d_fifo_rd_en;
    wire [SRAM_ADDR_W-1:0] next_sram_addr;

    // State registers
    reg [1:0]  scan_pass;
    reg [4:0]  base_format_lock;
    reg        format_changed_error;
    reg        beat_cnt;

    // base_format is a frame-level format selector.
    localparam [4:0] BASE_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] BASE_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] BASE_FMT_YUV420_8    = 5'b00010;
    localparam [4:0] BASE_FMT_YUV420_10   = 5'b00011;
    localparam [4:0] BASE_FMT_YUV422_8    = 5'b00100;
    localparam [4:0] BASE_FMT_YUV422_10   = 5'b00101;
    localparam [4:0] META_FMT_NV12_Y      = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV     = 5'b01001;
    localparam [4:0] META_FMT_NV16_Y      = 5'b01010;
    localparam [4:0] META_FMT_NV16_UV     = 5'b01011;
    localparam [4:0] META_FMT_NV16_10_Y   = 5'b01100;
    localparam [4:0] META_FMT_NV16_10_UV  = 5'b01101;
    localparam [4:0] META_FMT_P010_Y      = 5'b01110;
    localparam [4:0] META_FMT_P010_UV     = 5'b01111;

    wire base_lock_is_rgba   = (base_format_lock == BASE_FMT_RGBA8888) || (base_format_lock == BASE_FMT_RGBA1010102);
    wire base_lock_is_yuv420 = (base_format_lock == BASE_FMT_YUV420_8) || (base_format_lock == BASE_FMT_YUV420_10);
    wire base_lock_is_yuv422 = (base_format_lock == BASE_FMT_YUV422_8) || (base_format_lock == BASE_FMT_YUV422_10);
    wire curr_is_yuv420_uv = (curr_meta_format == META_FMT_NV12_UV) || (curr_meta_format == META_FMT_P010_UV);
    wire curr_is_yuv422_uv = (curr_meta_format == META_FMT_NV16_UV) || (curr_meta_format == META_FMT_NV16_10_UV);

    // Decision logic
    wire [15:0] cmd_x_count = (tile_x_numbers + 16'd7) >> 3;
    wire [15:0] max_x_idx   = (cmd_x_count == 16'd0) ? 16'd0 : (cmd_x_count - 16'd1);
    wire [15:0] rgba_block_y_count = (tile_y_numbers + 16'd7) >> 3;
    wire [15:0] rgba_last_block_y  = (rgba_block_y_count == 16'd0) ? 16'd0 : (rgba_block_y_count - 16'd1);
    wire is_eol = (curr_meta_xcoord == max_x_idx);
    wire is_last_pass = base_lock_is_rgba   ? (curr_meta_ycoord[0] || (curr_meta_ycoord == rgba_last_block_y)) :
                        base_lock_is_yuv420 ? curr_is_yuv420_uv :
                        base_lock_is_yuv422 ? curr_is_yuv422_uv :
                                              1'b0;

    wire [SRAM_ADDR_W-1:0] sram_pass_base_addr =
        (base_lock_is_rgba || (base_lock_is_yuv420 && !curr_is_yuv420_uv)) ?
            {{(SRAM_ADDR_W-10){1'b0}}, curr_meta_ycoord[0], 8'h00} :
        (base_lock_is_yuv420 && curr_is_yuv420_uv) ?
            {{(SRAM_ADDR_W-10){1'b0}}, 2'b10, 8'h00} :
        (base_lock_is_yuv422 && !curr_is_yuv422_uv) ?
            {SRAM_ADDR_W{1'b0}} :
            {{(SRAM_ADDR_W-10){1'b0}}, 2'b10, 8'h00};

    wire [15:0] group_idx =
        base_lock_is_rgba   ? {1'b0, curr_meta_ycoord[15:1]} :
        base_lock_is_yuv420 ? (curr_is_yuv420_uv ? curr_meta_ycoord : {1'b0, curr_meta_ycoord[15:1]}) :
                              curr_meta_ycoord;
    wire active_pingpong_sel = group_idx[0];
    assign target_bank_free = active_pingpong_sel ? bank_b_free : bank_a_free;
    assign is_group_start =
        base_lock_is_rgba   ? ((curr_meta_xcoord == 16'd0) && (curr_meta_ycoord[0] == 1'b0)) :
        base_lock_is_yuv420 ? ((curr_meta_xcoord == 16'd0) && !curr_is_yuv420_uv && (curr_meta_ycoord[0] == 1'b0)) :
        base_lock_is_yuv422 ? ((curr_meta_xcoord == 16'd0) && !curr_is_yuv422_uv) :
                              (curr_meta_xcoord == 16'd0);
    // Stall the first descriptor of a new group until the target bank has been
    // fully consumed by the read side. This prevents bank A/B from being
    // overwritten while older metadata in that bank is still in use.
    assign bank_reuse_block = (beat_cnt == 1'b0) && is_group_start && !target_bank_free;

    // Each meta command always maps to 64B / 2 beats, and the meta descriptor is popped on beat 2
    assign m_fifo_rd_en = internal_handshake && (beat_cnt == 1'b1);

    // Configuration lock
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            base_format_lock     <= BASE_FMT_RGBA8888;
            format_changed_error <= 1'b0;
            scan_pass            <= 2'd0;
        end else if (start) begin
            base_format_lock     <= BASE_FMT_RGBA8888;
            format_changed_error <= 1'b0;
            scan_pass            <= 2'd0;
        end else if (internal_handshake && beat_cnt == 1'b0) begin
            if (curr_meta_xcoord == 16'd0 && curr_meta_ycoord == 16'd0 && scan_pass == 2'd0) begin
                base_format_lock     <= base_format;
                format_changed_error <= 1'b0;
            end else if (base_format != base_format_lock) begin
                format_changed_error <= 1'b1;
            end

            if (base_lock_is_yuv420 && curr_is_yuv420_uv) begin
                scan_pass <= 2'd2;
            end else if (base_lock_is_yuv422 && curr_is_yuv422_uv) begin
                scan_pass <= 2'd2;
            end else if (base_lock_is_rgba || base_lock_is_yuv420) begin
                scan_pass <= {1'b0, curr_meta_ycoord[0]};
            end else begin
                scan_pass <= 2'd0;
            end
        end
    end

    // SRAM control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) beat_cnt <= 1'b0;
        else if (start) beat_cnt <= 1'b0;
        else if (internal_handshake) beat_cnt <= dout_rlast ? 1'b0 : ~beat_cnt;
    end

    assign next_sram_addr = sram_pass_base_addr + {{(SRAM_ADDR_W-9){1'b0}}, curr_meta_xcoord[7:0], beat_cnt};
    assign sram_addr  = next_sram_addr;
    assign sram_wdata = dout_rdata;
    assign sram_we_a  = (internal_handshake && !active_pingpong_sel) ? 4'hf : 4'h0;
    assign sram_we_b  = (internal_handshake &&  active_pingpong_sel) ? 4'hf : 4'h0;

    // Downstream bfifo write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bfifo_we    <= 1'b0;
            bfifo_wdata <= 41'd0;
            bank_fill_valid  <= 1'b0;
            bank_fill_bank_b <= 1'b0;
        end else if (start) begin
            bfifo_we    <= 1'b0;
            bfifo_wdata <= 41'd0;
            bank_fill_valid  <= 1'b0;
            bank_fill_bank_b <= 1'b0;
        end else begin
            bfifo_we   <= 1'b0;
            bank_fill_valid  <= 1'b0;
            if (internal_handshake && beat_cnt == 1'b1) begin
                bfifo_we    <= 1'b1;
                bfifo_wdata <= {active_pingpong_sel, format_changed_error, is_eol, is_last_pass, 
                                curr_meta_format, curr_meta_xcoord, curr_meta_ycoord};
                if (is_eol && is_last_pass) begin
                    bank_fill_valid  <= 1'b1;
                    bank_fill_bank_b <= active_pingpong_sel;
                end
            end
        end
    end

endmodule
