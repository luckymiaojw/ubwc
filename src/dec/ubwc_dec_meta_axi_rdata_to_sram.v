`timescale 1ns / 1ps

module ubwc_dec_meta_axi_rdata_to_sram #(
    parameter AXI_DATA_WIDTH = 256,
    parameter SRAM_ADDR_W    = 12,
    parameter META_DATA_W    = 8
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      start,

    // --- External configuration ---
    input  wire [4:0]                base_format,
    input  wire [15:0]               tile_x_numbers,
    input  wire [15:0]               tile_y_numbers,

    // --- 8-bit metadata stream from AXI read command generator ---
    input  wire                      meta_data_valid,
    output wire                      meta_data_ready,
    input  wire [META_DATA_W-1:0]    meta_data,
    input  wire [4:0]                meta_format,
    input  wire [15:0]               meta_xcoord,
    input  wire [15:0]               meta_ycoord,

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

    // base_format is a frame-level format selector.
    localparam [4:0] BASE_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] BASE_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] BASE_FMT_YUV420_8    = 5'b00010;
    localparam [4:0] BASE_FMT_YUV420_10   = 5'b00011;
    localparam [4:0] BASE_FMT_YUV422_8    = 5'b00100;
    localparam [4:0] BASE_FMT_YUV422_10   = 5'b00101;
    localparam [4:0] META_FMT_NV12_UV     = 5'b01001;
    localparam [4:0] META_FMT_NV16_UV     = 5'b01011;
    localparam [4:0] META_FMT_NV16_10_UV  = 5'b01101;
    localparam [4:0] META_FMT_P010_UV     = 5'b01111;

    wire base_is_rgba   = (base_format == BASE_FMT_RGBA8888) || (base_format == BASE_FMT_RGBA1010102);
    wire base_is_yuv420 = (base_format == BASE_FMT_YUV420_8) || (base_format == BASE_FMT_YUV420_10);
    wire base_is_yuv422 = (base_format == BASE_FMT_YUV422_8) || (base_format == BASE_FMT_YUV422_10);

    wire curr_is_yuv420_uv = (meta_format == META_FMT_NV12_UV) || (meta_format == META_FMT_P010_UV);
    wire curr_is_yuv422_uv = (meta_format == META_FMT_NV16_UV) || (meta_format == META_FMT_NV16_10_UV);
    wire curr_is_uv        = curr_is_yuv420_uv || curr_is_yuv422_uv;

    wire [15:0] curr_x_block_idx = {3'd0, meta_xcoord[15:3]};
    wire [15:0] curr_y_group_idx = {3'd0, meta_ycoord[15:3]};
    wire [2:0]  curr_byte_idx    = meta_xcoord[2:0];
    wire [2:0]  curr_row_phase   = meta_ycoord[2:0];

    wire [15:0] cmd_x_count = (tile_x_numbers + 16'd7) >> 3;
    wire [15:0] max_x_idx   = (cmd_x_count == 16'd0) ? 16'd0 : (cmd_x_count - 16'd1);
    wire [15:0] rgba_block_y_count = (tile_y_numbers + 16'd7) >> 3;
    wire [15:0] rgba_last_block_y  = (rgba_block_y_count == 16'd0) ? 16'd0 : (rgba_block_y_count - 16'd1);

    wire [15:0] bank_group_idx =
        base_is_yuv420 ? (curr_is_yuv420_uv ? curr_y_group_idx : {1'b0, curr_y_group_idx[15:1]}) :
        base_is_yuv422 ? curr_y_group_idx :
                         {1'b0, curr_y_group_idx[15:1]};
    wire active_pingpong_sel = bank_group_idx[0];
    wire target_bank_free    = active_pingpong_sel ? bank_b_free : bank_a_free;

    wire desc_row_start =
        (curr_row_phase == 3'd0);
    wire is_eol =
        (curr_x_block_idx == max_x_idx);
    wire is_last_pass =
        base_is_rgba   ? (curr_y_group_idx[0] || (curr_y_group_idx == rgba_last_block_y)) :
        base_is_yuv420 ? curr_is_yuv420_uv :
        base_is_yuv422 ? curr_is_yuv422_uv :
                         1'b0;
    wire is_group_start =
        (curr_x_block_idx == 16'd0) && desc_row_start &&
        (base_is_yuv420 ? (!curr_is_yuv420_uv && !curr_y_group_idx[0]) :
         base_is_rgba   ? !curr_y_group_idx[0] :
                          !curr_is_uv);
    wire bank_reuse_block = is_group_start && !target_bank_free;

    wire [1:0] sram_base_addr_offset =
        base_is_rgba   ? {1'b0, curr_y_group_idx[0]} :
        base_is_yuv420 ? (curr_is_yuv420_uv ? 2'b10 : {1'b0, curr_y_group_idx[0]}) :
        base_is_yuv422 ? (curr_is_yuv422_uv ? 2'b10 : 2'b00) :
                         2'b00;

    wire [SRAM_ADDR_W-1:0] sram_pass_base_addr =
        {{(SRAM_ADDR_W-10){1'b0}}, sram_base_addr_offset, 8'h00};
    wire [SRAM_ADDR_W-1:0] sram_tile_word_addr =
        {{(SRAM_ADDR_W-9){1'b0}}, curr_x_block_idx[7:0], curr_row_phase[2]};
    wire [3:0] sram_lane_we = 4'b0001 << curr_row_phase[1:0];
    wire internal_handshake = meta_data_valid && meta_data_ready;
    wire group_complete = (curr_byte_idx == 3'd7);

    reg [4:0] base_format_lock;
    reg       format_changed_error;
    reg [63:0] meta_pack_data;
    reg [63:0] meta_pack_data_next;

    always @* begin
        meta_pack_data_next = meta_pack_data;
        case (curr_byte_idx)
            3'd0: meta_pack_data_next[ 7: 0] = meta_data;
            3'd1: meta_pack_data_next[15: 8] = meta_data;
            3'd2: meta_pack_data_next[23:16] = meta_data;
            3'd3: meta_pack_data_next[31:24] = meta_data;
            3'd4: meta_pack_data_next[39:32] = meta_data;
            3'd5: meta_pack_data_next[47:40] = meta_data;
            3'd6: meta_pack_data_next[55:48] = meta_data;
            default: meta_pack_data_next[63:56] = meta_data;
        endcase
    end

    assign meta_data_ready = rst_n && !start && !bfifo_prog_full && !bank_reuse_block;
    assign sram_addr       = sram_pass_base_addr + sram_tile_word_addr;
    assign sram_wdata      = {4{meta_pack_data_next}};
    assign sram_we_a       = (internal_handshake && group_complete && !active_pingpong_sel) ? sram_lane_we : 4'h0;
    assign sram_we_b       = (internal_handshake && group_complete &&  active_pingpong_sel) ? sram_lane_we : 4'h0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            base_format_lock     <= BASE_FMT_RGBA8888;
            format_changed_error <= 1'b0;
            meta_pack_data       <= 64'd0;
        end else if (start) begin
            base_format_lock     <= BASE_FMT_RGBA8888;
            format_changed_error <= 1'b0;
            meta_pack_data       <= 64'd0;
        end else if (internal_handshake) begin
            meta_pack_data <= meta_pack_data_next;
            if (curr_x_block_idx == 16'd0 && meta_ycoord == 16'd0) begin
                base_format_lock     <= base_format;
                format_changed_error <= 1'b0;
            end else if (base_format != base_format_lock) begin
                format_changed_error <= 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bfifo_we         <= 1'b0;
            bfifo_wdata      <= 41'd0;
            bank_fill_valid  <= 1'b0;
            bank_fill_bank_b <= 1'b0;
        end else if (start) begin
            bfifo_we         <= 1'b0;
            bfifo_wdata      <= 41'd0;
            bank_fill_valid  <= 1'b0;
            bank_fill_bank_b <= 1'b0;
        end else begin
            bfifo_we         <= 1'b0;
            bank_fill_valid  <= 1'b0;
            if (internal_handshake && group_complete && desc_row_start) begin
                bfifo_we    <= 1'b1;
                bfifo_wdata <= {
                    active_pingpong_sel,
                    format_changed_error,
                    is_eol,
                    is_last_pass,
                    meta_format,
                    curr_x_block_idx,
                    curr_y_group_idx
                };
                if (is_eol && is_last_pass) begin
                    bank_fill_valid  <= 1'b1;
                    bank_fill_bank_b <= active_pingpong_sel;
                end
            end
        end
    end

endmodule
