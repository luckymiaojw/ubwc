`timescale 1ns/1ps
`default_nettype none

module tb_enc_sync_sram_1rw #(
    parameter ADDR_W = 13,
    parameter DATA_W = 128
) (
    input  wire               clk,
    input  wire               en,
    input  wire               wen,
    input  wire [ADDR_W-1:0]  addr,
    input  wire [DATA_W-1:0]  din,
    output reg  [DATA_W-1:0]  dout,
    output reg                dout_vld
);
    reg [DATA_W-1:0] mem [0:(1 << ADDR_W)-1];
    integer idx;

    initial begin
        dout     = {DATA_W{1'b0}};
        dout_vld = 1'b0;
        for (idx = 0; idx < (1 << ADDR_W); idx = idx + 1)
            mem[idx] = {DATA_W{1'b0}};
    end

    always @(posedge clk) begin
        dout_vld <= 1'b0;
        if (en) begin
            if (wen) begin
                mem[addr] <= din;
            end else begin
                dout     <= mem[addr];
                dout_vld <= 1'b1;
            end
        end
    end
endmodule

module tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12;
    localparam integer APB_AW   = 16;
    localparam integer APB_DW   = 32;
    localparam integer AXI_AW   = 64;
    localparam integer AXI_DW   = 256;
    localparam integer AXI_LENW = 8;
    localparam integer AXI_IDW  = 6;
    localparam integer ENC_SB_WIDTH = 1;
    localparam integer DEC_SB_WIDTH = 3;
    localparam integer COM_BUF_AW = 13;
    localparam integer COM_BUF_DW = 128;

    localparam integer IMG_W           = 4096;
    localparam integer IMG_H_ACTIVE    = 600;
    localparam integer Y_H_STORED      = 640;
    localparam integer UV_H_STORED     = 320;
    localparam integer TILE_W          = 32;
    localparam integer TILE_H          = 8;
    localparam integer TILE_X_COUNT    = IMG_W / TILE_W;
    localparam integer Y_TILE_Y_COUNT  = Y_H_STORED / TILE_H;
    localparam integer UV_TILE_Y_COUNT = UV_H_STORED / TILE_H;
    localparam integer EXPECTED_TILE_CMDS  = TILE_X_COUNT * (Y_TILE_Y_COUNT + UV_TILE_Y_COUNT);
    localparam integer EXPECTED_TILE_BEATS = EXPECTED_TILE_CMDS * 8;

    localparam integer WORDS64_PER_Y_LINE  = IMG_W / 8;
    localparam integer WORDS64_PER_UV_LINE = IMG_W / 8;
    localparam integer Y_WORDS64_TOTAL     = WORDS64_PER_Y_LINE * Y_H_STORED;
    localparam integer UV_WORDS64_TOTAL    = WORDS64_PER_UV_LINE * UV_H_STORED;
    localparam integer Y_META_PITCH_BYTES  = 128;
    localparam integer Y_META_LINES        = 96;
    localparam integer UV_META_PITCH_BYTES = 128;
    localparam integer UV_META_LINES       = 64;
    localparam integer Y_META_WORDS64      = (Y_META_PITCH_BYTES * Y_META_LINES) / 8;
    localparam integer UV_META_WORDS64     = (UV_META_PITCH_BYTES * UV_META_LINES) / 8;
    localparam integer HIGHEST_BANK_BIT    = 16;
    localparam integer TIMEOUT_CYCLES      = 40000000;

    localparam [4:0] BASE_FMT_YUV420_8 = 5'b00010;
    localparam [4:0] META_FMT_NV12_Y   = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV  = 5'b01001;
    localparam [AXI_AW-1:0] META_BASE_ADDR_Y  = 64'h0000_0000_8000_0000;
    localparam [AXI_AW-1:0] META_BASE_ADDR_UV = 64'h0000_0000_8028_3000;

    reg                       clk;
    reg                       i_otf_clk;

    reg                       enc_rst_n;
    reg                       dec_presetn;
    reg                       dec_axi_rstn;
    reg                       dec_otf_rstn;

    reg                       enc_PSEL;
    reg                       enc_PENABLE;
    reg  [APB_AW-1:0]         enc_PADDR;
    reg                       enc_PWRITE;
    reg  [APB_DW-1:0]         enc_PWDATA;
    wire                      enc_PREADY;
    wire                      enc_PSLVERR;
    wire [APB_DW-1:0]         enc_PRDATA;

    reg                       dec_PSEL;
    reg                       dec_PENABLE;
    reg  [APB_AW-1:0]         dec_PADDR;
    reg                       dec_PWRITE;
    reg  [APB_DW-1:0]         dec_PWDATA;
    wire                      dec_PREADY;
    wire                      dec_PSLVERR;
    wire [APB_DW-1:0]         dec_PRDATA;

    reg                       start_enc_otf;
    wire                      enc_otf_done;
    wire                      enc_otf_error;
    wire                      enc_i_otf_vsync;
    wire                      enc_i_otf_hsync;
    wire                      enc_i_otf_de;
    wire [127:0]              enc_i_otf_data;
    wire [3:0]                enc_i_otf_fcnt;
    wire [11:0]               enc_i_otf_lcnt;
    wire                      enc_o_otf_ready;

    wire                      enc_bank0_en;
    wire                      enc_bank0_wen;
    wire [COM_BUF_AW-1:0]     enc_bank0_addr;
    wire [COM_BUF_DW-1:0]     enc_bank0_din;
    wire [COM_BUF_DW-1:0]     enc_bank0_dout;
    wire                      enc_bank0_dout_vld;
    wire                      enc_bank1_en;
    wire                      enc_bank1_wen;
    wire [COM_BUF_AW-1:0]     enc_bank1_addr;
    wire [COM_BUF_DW-1:0]     enc_bank1_din;
    wire [COM_BUF_DW-1:0]     enc_bank1_dout;
    wire                      enc_bank1_dout_vld;

    wire [AXI_IDW:0]          enc_o_m_axi_awid;
    wire [AXI_AW-1:0]         enc_o_m_axi_awaddr;
    wire [AXI_LENW-1:0]       enc_o_m_axi_awlen;
    wire [2:0]                enc_o_m_axi_awsize;
    wire [1:0]                enc_o_m_axi_awburst;
    wire [1:0]                enc_o_m_axi_awlock;
    wire [3:0]                enc_o_m_axi_awcache;
    wire [2:0]                enc_o_m_axi_awprot;
    wire                      enc_o_m_axi_awvalid;
    reg                       enc_i_m_axi_awready;
    wire [AXI_DW-1:0]         enc_o_m_axi_wdata;
    wire [(AXI_DW/8)-1:0]     enc_o_m_axi_wstrb;
    wire                      enc_o_m_axi_wvalid;
    wire                      enc_o_m_axi_wlast;
    reg                       enc_i_m_axi_wready;
    reg  [AXI_IDW:0]          enc_i_m_axi_bid;
    reg  [1:0]                enc_i_m_axi_bresp;
    reg                       enc_i_m_axi_bvalid;
    wire                      enc_o_m_axi_bready;

    wire                      dec_o_otf_vsync;
    wire                      dec_o_otf_hsync;
    wire                      dec_o_otf_de;
    wire [127:0]              dec_o_otf_data;
    wire [3:0]                dec_o_otf_fcnt;
    wire [11:0]               dec_o_otf_lcnt;
    reg                       dec_i_otf_ready;

    wire                      dec_o_otf_sram_a_wen;
    wire [12:0]               dec_o_otf_sram_a_waddr;
    wire [127:0]              dec_o_otf_sram_a_wdata;
    wire                      dec_o_otf_sram_a_ren;
    wire [12:0]               dec_o_otf_sram_a_raddr;
    wire [127:0]              dec_i_otf_sram_a_rdata;
    wire                      dec_o_otf_sram_b_wen;
    wire [12:0]               dec_o_otf_sram_b_waddr;
    wire [127:0]              dec_o_otf_sram_b_wdata;
    wire                      dec_o_otf_sram_b_ren;
    wire [12:0]               dec_o_otf_sram_b_raddr;
    wire [127:0]              dec_i_otf_sram_b_rdata;
    wire                      dec_o_bank0_en;
    wire                      dec_o_bank0_wen;
    wire [12:0]               dec_o_bank0_addr;
    wire [127:0]              dec_o_bank0_din;
    wire [127:0]              dec_i_bank0_dout;
    reg                       dec_i_bank0_dout_vld;
    wire                      dec_o_bank1_en;
    wire                      dec_o_bank1_wen;
    wire [12:0]               dec_o_bank1_addr;
    wire [127:0]              dec_o_bank1_din;
    wire [127:0]              dec_i_bank1_dout;
    reg                       dec_i_bank1_dout_vld;

    wire [AXI_IDW:0]          dec_o_m_axi_arid;
    wire [AXI_AW-1:0]         dec_o_m_axi_araddr;
    wire [AXI_LENW-1:0]       dec_o_m_axi_arlen;
    wire [3:0]                dec_o_m_axi_arsize;
    wire [1:0]                dec_o_m_axi_arburst;
    wire [0:0]                dec_o_m_axi_arlock;
    wire [3:0]                dec_o_m_axi_arcache;
    wire [2:0]                dec_o_m_axi_arprot;
    wire                      dec_o_m_axi_arvalid;
    reg                       dec_i_m_axi_arready;
    wire [AXI_DW-1:0]         dec_i_m_axi_rdata;
    wire                      dec_i_m_axi_rvalid;
    wire [1:0]                dec_i_m_axi_rresp;
    wire                      dec_i_m_axi_rlast;
    wire                      dec_o_m_axi_rready;
    assign dec_o_otf_sram_a_wen   = dec_o_bank0_en && dec_o_bank0_wen;
    assign dec_o_otf_sram_a_waddr = dec_o_bank0_addr;
    assign dec_o_otf_sram_a_wdata = dec_o_bank0_din;
    assign dec_o_otf_sram_a_ren   = dec_o_bank0_en && !dec_o_bank0_wen;
    assign dec_o_otf_sram_a_raddr = dec_o_bank0_addr;
    assign dec_i_bank0_dout       = dec_i_otf_sram_a_rdata;
    assign dec_o_otf_sram_b_wen   = dec_o_bank1_en && dec_o_bank1_wen;
    assign dec_o_otf_sram_b_waddr = dec_o_bank1_addr;
    assign dec_o_otf_sram_b_wdata = dec_o_bank1_din;
    assign dec_o_otf_sram_b_ren   = dec_o_bank1_en && !dec_o_bank1_wen;
    assign dec_o_otf_sram_b_raddr = dec_o_bank1_addr;
    assign dec_i_bank1_dout       = dec_i_otf_sram_b_rdata;

    reg  [63:0]               meta_y_words   [0:Y_META_WORDS64-1];
    reg  [63:0]               meta_uv_words  [0:UV_META_WORDS64-1];
    reg  [63:0]               tile_y_words   [0:Y_WORDS64_TOTAL-1];
    reg  [63:0]               tile_uv_words  [0:UV_WORDS64_TOTAL-1];
    reg  [63:0]               linear_y_words [0:Y_WORDS64_TOTAL-1];
    reg  [63:0]               linear_uv_words[0:UV_WORDS64_TOTAL-1];

    reg  [4:0]                enc_cmd_fmt_queue [0:EXPECTED_TILE_CMDS-1];
    reg  [15:0]               enc_cmd_x_queue   [0:EXPECTED_TILE_CMDS-1];
    reg  [15:0]               enc_cmd_y_queue   [0:EXPECTED_TILE_CMDS-1];

    reg  [4:0]                dec_tile_fmt_queue  [0:EXPECTED_TILE_CMDS-1];
    reg  [11:0]               dec_tile_x_queue    [0:EXPECTED_TILE_CMDS-1];
    reg  [9:0]                dec_tile_y_queue    [0:EXPECTED_TILE_CMDS-1];
    reg  [2:0]                dec_tile_alen_queue [0:EXPECTED_TILE_CMDS-1];
    reg  [AXI_AW-1:0]         dec_tile_addr_queue [0:EXPECTED_TILE_CMDS-1];

    integer                   enc_cmd_wr_ptr;
    integer                   enc_cmd_rd_ptr;
    reg                       enc_active_cmd_valid;
    reg  [4:0]                enc_active_cmd_fmt;
    reg  [15:0]               enc_active_cmd_x;
    reg  [15:0]               enc_active_cmd_y;
    reg  [31:0]               enc_active_cmd_addr;
    integer                   enc_active_cmd_beat_idx;
    reg  [AXI_IDW:0]          enc_last_awid;

    integer                   dec_tile_queue_wr_ptr;
    integer                   dec_tile_queue_rd_ptr;

    reg                       dec_axi_rsp_active;
    reg                       dec_axi_rsp_is_meta;
    reg                       dec_axi_rsp_meta_plane1;
    reg  [AXI_AW-1:0]         dec_axi_rsp_addr;
    reg  [7:0]                dec_axi_rsp_beats_left;
    reg  [7:0]                dec_axi_rsp_beat_idx;
    reg  [4:0]                dec_axi_rsp_tile_fmt;
    reg  [11:0]               dec_axi_rsp_tile_x;
    reg  [9:0]                dec_axi_rsp_tile_y;

    integer                   cycle_cnt;
    integer                   enc_coord_count;
    integer                   enc_aw_count;
    integer                   enc_w_count;
    integer                   enc_queue_underflow_cnt;
    integer                   enc_aw_addr_mismatch_cnt;
    integer                   enc_wlast_mismatch_cnt;
    integer                   enc_idle_cycles_after_done;
    integer                   dec_meta_ar_cnt;
    integer                   dec_meta_y_ar_cnt;
    integer                   dec_meta_uv_ar_cnt;
    integer                   dec_tile_ar_cnt;
    integer                   dec_axi_rbeat_cnt;
    integer                   dec_tile_queue_underflow_cnt;
    integer                   dec_ar_addr_mismatch_cnt;
    integer                   dec_ar_len_mismatch_cnt;
    integer                   otf_beat_cnt;
    integer                   otf_mismatch_cnt;
    integer                   first_mismatch_x;
    integer                   first_mismatch_y;
    integer                   timeout_cycles;
    integer                   otf_fd;
    integer                   active_x;
    integer                   active_y;
    reg                       frame_done;
    reg                       encoder_done_ok;
    integer                   idx;

    function automatic integer macro_tile_slot;
        input integer tile_x_mod8;
        input integer tile_y_mod8;
        begin
            case (tile_x_mod8)
                0: case (tile_y_mod8) 0: macro_tile_slot = 0; 1: macro_tile_slot = 6; 2: macro_tile_slot = 3; 3: macro_tile_slot = 5; 4: macro_tile_slot = 4; 5: macro_tile_slot = 2; 6: macro_tile_slot = 7; default: macro_tile_slot = 1; endcase
                1: case (tile_y_mod8) 0: macro_tile_slot = 7; 1: macro_tile_slot = 1; 2: macro_tile_slot = 4; 3: macro_tile_slot = 2; 4: macro_tile_slot = 3; 5: macro_tile_slot = 5; 6: macro_tile_slot = 0; default: macro_tile_slot = 6; endcase
                2: case (tile_y_mod8) 0: macro_tile_slot = 10; 1: macro_tile_slot = 12; 2: macro_tile_slot = 9; 3: macro_tile_slot = 15; 4: macro_tile_slot = 14; 5: macro_tile_slot = 8; 6: macro_tile_slot = 13; default: macro_tile_slot = 11; endcase
                3: case (tile_y_mod8) 0: macro_tile_slot = 13; 1: macro_tile_slot = 11; 2: macro_tile_slot = 14; 3: macro_tile_slot = 8; 4: macro_tile_slot = 9; 5: macro_tile_slot = 15; 6: macro_tile_slot = 10; default: macro_tile_slot = 12; endcase
                4: case (tile_y_mod8) 0: macro_tile_slot = 4; 1: macro_tile_slot = 2; 2: macro_tile_slot = 7; 3: macro_tile_slot = 1; 4: macro_tile_slot = 0; 5: macro_tile_slot = 6; 6: macro_tile_slot = 3; default: macro_tile_slot = 5; endcase
                5: case (tile_y_mod8) 0: macro_tile_slot = 3; 1: macro_tile_slot = 5; 2: macro_tile_slot = 0; 3: macro_tile_slot = 6; 4: macro_tile_slot = 7; 5: macro_tile_slot = 1; 6: macro_tile_slot = 4; default: macro_tile_slot = 2; endcase
                6: case (tile_y_mod8) 0: macro_tile_slot = 14; 1: macro_tile_slot = 8; 2: macro_tile_slot = 13; 3: macro_tile_slot = 11; 4: macro_tile_slot = 10; 5: macro_tile_slot = 12; 6: macro_tile_slot = 9; default: macro_tile_slot = 15; endcase
                default: case (tile_y_mod8) 0: macro_tile_slot = 9; 1: macro_tile_slot = 15; 2: macro_tile_slot = 10; 3: macro_tile_slot = 12; 4: macro_tile_slot = 13; 5: macro_tile_slot = 11; 6: macro_tile_slot = 14; default: macro_tile_slot = 8; endcase
            endcase
        end
    endfunction

    function automatic integer plane_tile_base_word;
        input integer tile_x;
        input integer tile_y;
        input integer tile_width;
        input integer tile_height;
        input integer surface_pitch_bytes;
        input integer highest_bank_bit;
        input integer bpp;
        integer addr_bytes;
        integer macro_tile_x;
        integer macro_tile_y;
        integer temp_tile_x;
        integer temp_tile_y;
        integer tile_row_pixels;
        integer bit_val;
        begin
            macro_tile_x = tile_x / 4;
            macro_tile_y = tile_y / 4;
            temp_tile_x  = tile_x % 8;
            temp_tile_y  = tile_y % 8;

            addr_bytes = (surface_pitch_bytes * (macro_tile_y * 4) * tile_height) +
                         (macro_tile_x * 4096) +
                         (macro_tile_slot(temp_tile_x, temp_tile_y) * 256);

            if (((16 * surface_pitch_bytes) % (1 << highest_bank_bit)) == 0) begin
                if (((bpp == 1) && (tile_width * 4 == 128) && (tile_height * 4 == 32)) ||
                    ((bpp == 2) && (tile_width * 4 == 64)  && (tile_height * 4 == 32))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 4;
                end
                bit_val = ((addr_bytes >> (highest_bank_bit - 1)) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0)
                    addr_bytes = addr_bytes | (1 << (highest_bank_bit - 1));
                else
                    addr_bytes = addr_bytes & ~(1 << (highest_bank_bit - 1));
            end

            if (((16 * surface_pitch_bytes) % (1 << (highest_bank_bit + 1))) == 0) begin
                if (((bpp == 1) && (tile_width * 4 == 128) && (tile_height * 4 == 32)) ||
                    ((bpp == 2) && (tile_width * 4 == 64)  && (tile_height * 4 == 32))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 6;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end
                bit_val = ((addr_bytes >> highest_bank_bit) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0)
                    addr_bytes = addr_bytes | (1 << highest_bank_bit);
                else
                    addr_bytes = addr_bytes & ~(1 << highest_bank_bit);
            end

            plane_tile_base_word = addr_bytes >> 3;
        end
    endfunction

    function automatic [AXI_AW-1:0] expected_dec_tile_addr;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        integer base_word;
        begin
            base_word = plane_tile_base_word(tile_x, tile_y, TILE_W, TILE_H, 4096, HIGHEST_BANK_BIT, 1);
            expected_dec_tile_addr = base_word << 3;
        end
    endfunction

    function automatic [AXI_AW-1:0] expected_enc_tile_addr;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        integer base_word;
        begin
            if (fmt == META_FMT_NV12_UV)
                base_word = plane_tile_base_word(tile_x, tile_y, 16, 8, 4096, HIGHEST_BANK_BIT, 2);
            else
                base_word = plane_tile_base_word(tile_x, tile_y, 32, 8, 4096, HIGHEST_BANK_BIT, 1);
            expected_enc_tile_addr = base_word << 3;
        end
    endfunction

    function automatic [31:0] expected_enc_tile_addr32;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        begin
            expected_enc_tile_addr32 = expected_enc_tile_addr(fmt, tile_x, tile_y);
        end
    endfunction

    function automatic [AXI_DW-1:0] pack_meta_axi_word;
        input integer is_uv_plane;
        input [AXI_AW-1:0] addr;
        input integer beat_idx;
        integer word64_base;
        reg [63:0] w0;
        reg [63:0] w1;
        reg [63:0] w2;
        reg [63:0] w3;
        begin
            if (is_uv_plane != 0) begin
                word64_base = ((addr - META_BASE_ADDR_UV) >> 3) + beat_idx * 4;
                w0 = (word64_base + 0 < UV_META_WORDS64) ? meta_uv_words[word64_base + 0] : 64'd0;
                w1 = (word64_base + 1 < UV_META_WORDS64) ? meta_uv_words[word64_base + 1] : 64'd0;
                w2 = (word64_base + 2 < UV_META_WORDS64) ? meta_uv_words[word64_base + 2] : 64'd0;
                w3 = (word64_base + 3 < UV_META_WORDS64) ? meta_uv_words[word64_base + 3] : 64'd0;
            end else begin
                word64_base = ((addr - META_BASE_ADDR_Y) >> 3) + beat_idx * 4;
                w0 = (word64_base + 0 < Y_META_WORDS64) ? meta_y_words[word64_base + 0] : 64'd0;
                w1 = (word64_base + 1 < Y_META_WORDS64) ? meta_y_words[word64_base + 1] : 64'd0;
                w2 = (word64_base + 2 < Y_META_WORDS64) ? meta_y_words[word64_base + 2] : 64'd0;
                w3 = (word64_base + 3 < Y_META_WORDS64) ? meta_y_words[word64_base + 3] : 64'd0;
            end
            pack_meta_axi_word = {w3, w2, w1, w0};
        end
    endfunction

    function automatic [AXI_DW-1:0] pack_tile_axi_word;
        input [4:0] fmt;
        input [AXI_AW-1:0] addr;
        input integer beat_idx;
        integer word_idx;
        reg [63:0] w0;
        reg [63:0] w1;
        reg [63:0] w2;
        reg [63:0] w3;
        begin
            word_idx = (addr >> 3) + beat_idx * 4;
            if (fmt == META_FMT_NV12_UV) begin
                w0 = (word_idx + 0 < UV_WORDS64_TOTAL) ? tile_uv_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < UV_WORDS64_TOTAL) ? tile_uv_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < UV_WORDS64_TOTAL) ? tile_uv_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < UV_WORDS64_TOTAL) ? tile_uv_words[word_idx + 3] : 64'd0;
            end else begin
                w0 = (word_idx + 0 < Y_WORDS64_TOTAL) ? tile_y_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < Y_WORDS64_TOTAL) ? tile_y_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < Y_WORDS64_TOTAL) ? tile_y_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < Y_WORDS64_TOTAL) ? tile_y_words[word_idx + 3] : 64'd0;
            end
            pack_tile_axi_word = {w3, w2, w1, w0};
        end
    endfunction

    function automatic [7:0] y_byte;
        input integer x;
        input integer y;
        integer word_idx;
        integer byte_lane;
        reg [63:0] word64;
        begin
            word_idx = y * WORDS64_PER_Y_LINE + (x >> 3);
            byte_lane = x & 7;
            word64 = linear_y_words[word_idx];
            y_byte = word64[byte_lane * 8 +: 8];
        end
    endfunction

    function automatic [7:0] uv_byte;
        input integer x_byte;
        input integer uv_line;
        integer word_idx;
        integer byte_lane;
        reg [63:0] word64;
        begin
            word_idx = uv_line * WORDS64_PER_UV_LINE + (x_byte >> 3);
            byte_lane = x_byte & 7;
            word64 = linear_uv_words[word_idx];
            uv_byte = word64[byte_lane * 8 +: 8];
        end
    endfunction

    function automatic [127:0] expected_otf_word;
        input integer x;
        input integer y;
        integer uv_line;
        reg [127:0] exp_word;
        begin
            exp_word = 128'd0;
            exp_word[15:8]    = y_byte(x + 0, y);
            exp_word[47:40]   = y_byte(x + 1, y);
            exp_word[79:72]   = y_byte(x + 2, y);
            exp_word[111:104] = y_byte(x + 3, y);

            if ((y & 1) == 1) begin
                uv_line = y >> 1;
                exp_word[7:0]   = uv_byte(x + 1, uv_line);
                exp_word[23:16] = uv_byte(x + 0, uv_line);
                exp_word[71:64] = uv_byte(x + 3, uv_line);
                exp_word[87:80] = uv_byte(x + 2, uv_line);
            end

            expected_otf_word = exp_word;
        end
    endfunction

    task automatic store_encoder_tile_axi_word;
        input [4:0] fmt;
        input [31:0] awaddr;
        input integer beat_idx;
        input [AXI_DW-1:0] data_word;
        integer word_idx;
        begin
            word_idx = (awaddr >> 3) + beat_idx * 4;
            if (fmt == META_FMT_NV12_UV) begin
                if (word_idx + 0 < UV_WORDS64_TOTAL) tile_uv_words[word_idx + 0] = data_word[63:0];
                if (word_idx + 1 < UV_WORDS64_TOTAL) tile_uv_words[word_idx + 1] = data_word[127:64];
                if (word_idx + 2 < UV_WORDS64_TOTAL) tile_uv_words[word_idx + 2] = data_word[191:128];
                if (word_idx + 3 < UV_WORDS64_TOTAL) tile_uv_words[word_idx + 3] = data_word[255:192];
            end else begin
                if (word_idx + 0 < Y_WORDS64_TOTAL) tile_y_words[word_idx + 0] = data_word[63:0];
                if (word_idx + 1 < Y_WORDS64_TOTAL) tile_y_words[word_idx + 1] = data_word[127:64];
                if (word_idx + 2 < Y_WORDS64_TOTAL) tile_y_words[word_idx + 2] = data_word[191:128];
                if (word_idx + 3 < Y_WORDS64_TOTAL) tile_y_words[word_idx + 3] = data_word[255:192];
            end
        end
    endtask

    task automatic enc_apb_write;
        input [APB_AW-1:0] addr;
        input [APB_DW-1:0] data;
        begin
            @(posedge clk);
            enc_PSEL    <= 1'b1;
            enc_PENABLE <= 1'b0;
            enc_PWRITE  <= 1'b1;
            enc_PADDR   <= addr;
            enc_PWDATA  <= data;
            @(posedge clk);
            enc_PENABLE <= 1'b1;
            @(posedge clk);
            enc_PSEL    <= 1'b0;
            enc_PENABLE <= 1'b0;
            enc_PWRITE  <= 1'b0;
            enc_PADDR   <= {APB_AW{1'b0}};
            enc_PWDATA  <= {APB_DW{1'b0}};
        end
    endtask

    task automatic program_enc_wrapper_regs;
        reg [31:0] reg2_data;
        reg [31:0] reg3_data;
        reg [31:0] reg4_data;
        reg [31:0] reg8_data;
        reg [31:0] reg9_data;
        reg [31:0] reg10_data;
        reg [31:0] reg11_data;
        begin
            reg2_data = 32'd0;
            reg2_data[0]     = 1'b1;
            reg2_data[1]     = 1'b0;
            reg2_data[2]     = 1'b1;
            reg2_data[3]     = 1'b1;
            reg2_data[12:8]  = 5'd16;
            reg2_data[16]    = 1'b1;

            reg3_data = 32'd0;
            reg3_data[0]      = 1'b0;
            reg3_data[1]      = 1'b0;
            reg3_data[26:16]  = 11'd256;

            reg4_data = 32'd0;
            reg4_data[0]      = 1'b1;
            reg4_data[10:8]   = 3'd7;
            reg4_data[20:16]  = META_FMT_NV12_Y;
            reg4_data[24]     = 1'b0;

            reg8_data  = 32'd0;
            reg8_data[2:0] = 3'd2;

            reg9_data  = {16'd640, 16'd4096};
            reg10_data = {16'd8, 16'd32};
            reg11_data = {16'd128, 16'd128};

            enc_apb_write(16'h000c, reg3_data);
            enc_apb_write(16'h0008, reg2_data);
            enc_apb_write(16'h0014, 32'd0);
            enc_apb_write(16'h0018, 32'd0);
            enc_apb_write(16'h001c, 32'd0);
            enc_apb_write(16'h0010, reg4_data);
            enc_apb_write(16'h0024, reg9_data);
            enc_apb_write(16'h0028, reg10_data);
            enc_apb_write(16'h002c, reg11_data);
            enc_apb_write(16'h0020, reg8_data);
        end
    endtask

    task automatic dec_apb_write;
        input [APB_AW-1:0] addr;
        input [APB_DW-1:0] data;
        begin
            @(posedge clk);
            dec_PSEL    <= 1'b1;
            dec_PENABLE <= 1'b0;
            dec_PWRITE  <= 1'b1;
            dec_PADDR   <= addr;
            dec_PWDATA  <= data;
            @(posedge clk);
            dec_PENABLE <= 1'b1;
            @(posedge clk);
            dec_PSEL    <= 1'b0;
            dec_PENABLE <= 1'b0;
            dec_PWRITE  <= 1'b0;
            dec_PADDR   <= {APB_AW{1'b0}};
            dec_PWDATA  <= {APB_DW{1'b0}};
        end
    endtask

    task automatic program_dec_wrapper_cfg;
        begin
            dec_apb_write(16'h0008, 32'h0000_0306);
            dec_apb_write(16'h000c, 32'd256);
            dec_apb_write(16'h0010, 32'h0000_000f);
            dec_apb_write(16'h0044, 32'd0);
            dec_apb_write(16'h0048, 32'd0);
            dec_apb_write(16'h004c, 32'd0);
            dec_apb_write(16'h0050, 32'd0);
            dec_apb_write(16'h0014, 32'h0000_0001);

            dec_apb_write(16'h001c, META_BASE_ADDR_UV[31:0]);
            dec_apb_write(16'h0020, META_BASE_ADDR_UV[63:32]);
            dec_apb_write(16'h0024, META_BASE_ADDR_Y[31:0]);
            dec_apb_write(16'h0028, META_BASE_ADDR_Y[63:32]);
            dec_apb_write(16'h002c, {16'd80, 16'd128});

            dec_apb_write(16'h0030, {11'd0, BASE_FMT_YUV420_8, 16'd4096});
            dec_apb_write(16'h0034, {16'd44, 16'd4400});
            dec_apb_write(16'h0038, {16'd4096, 16'd148});
            dec_apb_write(16'h003c, {16'd5, 16'd682});
            dec_apb_write(16'h0040, {16'd640, 16'd36});

            dec_apb_write(16'h0018, 32'h0000_0020);
        end
    endtask

    task automatic trigger_dec_meta_start;
        begin
            repeat (16) @(posedge clk);
            dec_apb_write(16'h0018, 32'h0000_0021);
        end
    endtask

    wire [AXI_DW-1:0] dec_axi_rsp_rdata =
        dec_axi_rsp_is_meta ? pack_meta_axi_word(dec_axi_rsp_meta_plane1, dec_axi_rsp_addr, dec_axi_rsp_beat_idx) :
                              pack_tile_axi_word(dec_axi_rsp_tile_fmt, dec_axi_rsp_addr, dec_axi_rsp_beat_idx);

    assign dec_i_m_axi_rvalid = dec_axi_rsp_active;
    assign dec_i_m_axi_rdata  = dec_axi_rsp_active ? dec_axi_rsp_rdata : {AXI_DW{1'b0}};
    assign dec_i_m_axi_rresp  = 2'b00;
    assign dec_i_m_axi_rlast  = dec_axi_rsp_active && (dec_axi_rsp_beats_left == 8'd1);

    initial begin
        clk = 1'b0;
        forever #2 clk = ~clk;
    end

    initial begin
        i_otf_clk = 1'b0;
        forever #3 i_otf_clk = ~i_otf_clk;
    end

    always @(posedge clk) begin
        cycle_cnt <= cycle_cnt + 1;
    end

    always @(posedge clk or negedge dec_axi_rstn) begin
        if (!dec_axi_rstn) begin
            dec_i_bank0_dout_vld <= 1'b0;
            dec_i_bank1_dout_vld <= 1'b0;
        end else begin
            dec_i_bank0_dout_vld <= dec_o_otf_sram_a_ren;
            dec_i_bank1_dout_vld <= dec_o_otf_sram_b_ren;
        end
    end

    enc_otf_driver #(
        .INPUT_FILE ("input_otf_stream.txt")
    ) u_otf_driver (
        .clk        (clk),
        .rst_n      (enc_rst_n),
        .start      (start_enc_otf),
        .done       (enc_otf_done),
        .error_flag (enc_otf_error),
        .img_width  (IMG_W[15:0]),
        .img_height (Y_H_STORED[15:0]),
        .otf_vsync  (enc_i_otf_vsync),
        .otf_hsync  (enc_i_otf_hsync),
        .otf_de     (enc_i_otf_de),
        .otf_data   (enc_i_otf_data),
        .otf_fcnt   (enc_i_otf_fcnt),
        .otf_lcnt   (enc_i_otf_lcnt),
        .otf_ready  (enc_o_otf_ready)
    );

    tb_enc_sync_sram_1rw #(
        .ADDR_W (COM_BUF_AW),
        .DATA_W (COM_BUF_DW)
    ) u_enc_bank0 (
        .clk      (clk),
        .en       (enc_bank0_en),
        .wen      (enc_bank0_wen),
        .addr     (enc_bank0_addr),
        .din      (enc_bank0_din),
        .dout     (enc_bank0_dout),
        .dout_vld (enc_bank0_dout_vld)
    );

    tb_enc_sync_sram_1rw #(
        .ADDR_W (COM_BUF_AW),
        .DATA_W (COM_BUF_DW)
    ) u_enc_bank1 (
        .clk      (clk),
        .en       (enc_bank1_en),
        .wen      (enc_bank1_wen),
        .addr     (enc_bank1_addr),
        .din      (enc_bank1_din),
        .dout     (enc_bank1_dout),
        .dout_vld (enc_bank1_dout_vld)
    );

    sram_pdp_8192x128 u_dec_otf_sram_bank_a (
        .clk   (clk),
        .wen   (dec_o_otf_sram_a_wen),
        .waddr (dec_o_otf_sram_a_waddr),
        .wdata (dec_o_otf_sram_a_wdata),
        .ren   (dec_o_otf_sram_a_ren),
        .raddr (dec_o_otf_sram_a_raddr),
        .rdata (dec_i_otf_sram_a_rdata)
    );

    sram_pdp_8192x128 u_dec_otf_sram_bank_b (
        .clk   (clk),
        .wen   (dec_o_otf_sram_b_wen),
        .waddr (dec_o_otf_sram_b_waddr),
        .wdata (dec_o_otf_sram_b_wdata),
        .ren   (dec_o_otf_sram_b_ren),
        .raddr (dec_o_otf_sram_b_raddr),
        .rdata (dec_i_otf_sram_b_rdata)
    );

    ubwc_enc_wrapper_top #(
        .SB_WIDTH    (ENC_SB_WIDTH),
        .APB_AW      (APB_AW),
        .APB_DW      (APB_DW),
        .AXI_AW      (32),
        .AXI_DW      (AXI_DW),
        .AXI_LENW    (AXI_LENW),
        .AXI_IDW     (AXI_IDW),
        .COM_BUF_AW  (COM_BUF_AW),
        .COM_BUF_DW  (COM_BUF_DW)
    ) enc_dut (
        .PCLK            (clk),
        .PRESETn         (enc_rst_n),
        .PSEL            (enc_PSEL),
        .PENABLE         (enc_PENABLE),
        .PADDR           (enc_PADDR),
        .PWRITE          (enc_PWRITE),
        .PWDATA          (enc_PWDATA),
        .PREADY          (enc_PREADY),
        .PSLVERR         (enc_PSLVERR),
        .PRDATA          (enc_PRDATA),
        .i_clk           (clk),
        .i_rstn          (enc_rst_n),
        .i_otf_vsync     (enc_i_otf_vsync),
        .i_otf_hsync     (enc_i_otf_hsync),
        .i_otf_de        (enc_i_otf_de),
        .i_otf_data      (enc_i_otf_data),
        .i_otf_fcnt      (enc_i_otf_fcnt),
        .i_otf_lcnt      (enc_i_otf_lcnt),
        .o_otf_ready     (enc_o_otf_ready),
        .o_bank0_en      (enc_bank0_en),
        .o_bank0_wen     (enc_bank0_wen),
        .o_bank0_addr    (enc_bank0_addr),
        .o_bank0_din     (enc_bank0_din),
        .i_bank0_dout    (enc_bank0_dout),
        .i_bank0_dout_vld(enc_bank0_dout_vld),
        .o_bank1_en      (enc_bank1_en),
        .o_bank1_wen     (enc_bank1_wen),
        .o_bank1_addr    (enc_bank1_addr),
        .o_bank1_din     (enc_bank1_din),
        .i_bank1_dout    (enc_bank1_dout),
        .i_bank1_dout_vld(enc_bank1_dout_vld),
        .o_m_axi_awid    (enc_o_m_axi_awid),
        .o_m_axi_awaddr  (enc_o_m_axi_awaddr[31:0]),
        .o_m_axi_awlen   (enc_o_m_axi_awlen),
        .o_m_axi_awsize  (enc_o_m_axi_awsize),
        .o_m_axi_awburst (enc_o_m_axi_awburst),
        .o_m_axi_awlock  (enc_o_m_axi_awlock),
        .o_m_axi_awcache (enc_o_m_axi_awcache),
        .o_m_axi_awprot  (enc_o_m_axi_awprot),
        .o_m_axi_awvalid (enc_o_m_axi_awvalid),
        .i_m_axi_awready (enc_i_m_axi_awready),
        .o_m_axi_wdata   (enc_o_m_axi_wdata),
        .o_m_axi_wstrb   (enc_o_m_axi_wstrb),
        .o_m_axi_wvalid  (enc_o_m_axi_wvalid),
        .o_m_axi_wlast   (enc_o_m_axi_wlast),
        .i_m_axi_wready  (enc_i_m_axi_wready),
        .i_m_axi_bid     (enc_i_m_axi_bid),
        .i_m_axi_bresp   (enc_i_m_axi_bresp),
        .i_m_axi_bvalid  (enc_i_m_axi_bvalid),
        .o_m_axi_bready  (enc_o_m_axi_bready)
    );

    ubwc_dec_wrapper_top #(
        .APB_AW   (APB_AW),
        .APB_DW   (APB_DW),
        .AXI_AW   (AXI_AW),
        .AXI_DW   (AXI_DW),
        .AXI_IDW  (AXI_IDW),
        .AXI_LENW (AXI_LENW),
        .SB_WIDTH (DEC_SB_WIDTH),
        .FORCE_FULL_PAYLOAD (0)
    ) dec_dut (
        .PCLK              (clk),
        .PRESETn           (dec_presetn),
        .PSEL              (dec_PSEL),
        .PENABLE           (dec_PENABLE),
        .PADDR             (dec_PADDR),
        .PWRITE            (dec_PWRITE),
        .PWDATA            (dec_PWDATA),
        .PREADY            (dec_PREADY),
        .PSLVERR           (dec_PSLVERR),
        .PRDATA            (dec_PRDATA),
        .i_otf_clk         (i_otf_clk),
        .i_otf_rstn        (dec_otf_rstn),
        .o_otf_vsync       (dec_o_otf_vsync),
        .o_otf_hsync       (dec_o_otf_hsync),
        .o_otf_de          (dec_o_otf_de),
        .o_otf_data        (dec_o_otf_data),
        .o_otf_fcnt        (dec_o_otf_fcnt),
        .o_otf_lcnt        (dec_o_otf_lcnt),
        .i_otf_ready       (dec_i_otf_ready),
        .o_bank0_en        (dec_o_bank0_en),
        .o_bank0_wen       (dec_o_bank0_wen),
        .o_bank0_addr      (dec_o_bank0_addr),
        .o_bank0_din       (dec_o_bank0_din),
        .i_bank0_dout      (dec_i_bank0_dout),
        .i_bank0_dout_vld  (dec_i_bank0_dout_vld),
        .o_bank1_en        (dec_o_bank1_en),
        .o_bank1_wen       (dec_o_bank1_wen),
        .o_bank1_addr      (dec_o_bank1_addr),
        .o_bank1_din       (dec_o_bank1_din),
        .i_bank1_dout      (dec_i_bank1_dout),
        .i_bank1_dout_vld  (dec_i_bank1_dout_vld),
        .i_axi_clk         (clk),
        .i_axi_rstn        (dec_axi_rstn),
        .o_m_axi_arid      (dec_o_m_axi_arid),
        .o_m_axi_araddr    (dec_o_m_axi_araddr),
        .o_m_axi_arlen     (dec_o_m_axi_arlen),
        .o_m_axi_arsize    (dec_o_m_axi_arsize),
        .o_m_axi_arburst   (dec_o_m_axi_arburst),
        .o_m_axi_arlock    (dec_o_m_axi_arlock),
        .o_m_axi_arcache   (dec_o_m_axi_arcache),
        .o_m_axi_arprot    (dec_o_m_axi_arprot),
        .o_m_axi_arvalid   (dec_o_m_axi_arvalid),
        .i_m_axi_arready   (dec_i_m_axi_arready),
        .i_m_axi_rdata     (dec_i_m_axi_rdata),
        .i_m_axi_rvalid    (dec_i_m_axi_rvalid),
        .i_m_axi_rresp     (dec_i_m_axi_rresp),
        .i_m_axi_rlast     (dec_i_m_axi_rlast),
        .o_m_axi_rready    (dec_o_m_axi_rready)
    );

    initial begin
        for (idx = 0; idx < Y_WORDS64_TOTAL; idx = idx + 1)
            tile_y_words[idx] = 64'd0;
        for (idx = 0; idx < UV_WORDS64_TOTAL; idx = idx + 1)
            tile_uv_words[idx] = 64'd0;

        $readmemh("input_meta_plane0.txt", meta_y_words);
        $readmemh("input_meta_plane1.txt", meta_uv_words);
        $readmemh("golden_nv12_y_linear.memh", linear_y_words);
        $readmemh("golden_nv12_uv_linear.memh", linear_uv_words);

        if (^meta_y_words[0] === 1'bx)  $fatal(1, "Failed to load input_meta_plane0.txt");
        if (^meta_uv_words[0] === 1'bx) $fatal(1, "Failed to load input_meta_plane1.txt");
        if (^linear_y_words[0] === 1'bx)  $fatal(1, "Failed to load golden_nv12_y_linear.memh");
        if (^linear_uv_words[0] === 1'bx) $fatal(1, "Failed to load golden_nv12_uv_linear.memh");

        enc_rst_n              = 1'b0;
        dec_presetn            = 1'b0;
        dec_axi_rstn           = 1'b0;
        dec_otf_rstn           = 1'b0;
        enc_PSEL               = 1'b0;
        enc_PENABLE            = 1'b0;
        enc_PADDR              = {APB_AW{1'b0}};
        enc_PWRITE             = 1'b0;
        enc_PWDATA             = {APB_DW{1'b0}};
        dec_PSEL               = 1'b0;
        dec_PENABLE            = 1'b0;
        dec_PADDR              = {APB_AW{1'b0}};
        dec_PWRITE             = 1'b0;
        dec_PWDATA             = {APB_DW{1'b0}};
        start_enc_otf          = 1'b0;
        enc_i_m_axi_awready    = 1'b1;
        enc_i_m_axi_wready     = 1'b1;
        enc_i_m_axi_bid        = {(AXI_IDW+1){1'b0}};
        enc_i_m_axi_bresp      = 2'b00;
        enc_i_m_axi_bvalid     = 1'b0;
        dec_i_otf_ready        = 1'b1;
        dec_i_m_axi_arready    = 1'b1;
        cycle_cnt              = 0;
        otf_fd                 = 0;
        encoder_done_ok        = 1'b0;
        frame_done             = 1'b0;

        enc_cmd_wr_ptr         = 0;
        enc_cmd_rd_ptr         = 0;
        enc_active_cmd_valid   = 1'b0;
        enc_active_cmd_fmt     = 5'd0;
        enc_active_cmd_x       = 16'd0;
        enc_active_cmd_y       = 16'd0;
        enc_active_cmd_addr    = 32'd0;
        enc_active_cmd_beat_idx= 0;
        enc_last_awid          = {(AXI_IDW+1){1'b0}};

        dec_tile_queue_wr_ptr  = 0;
        dec_tile_queue_rd_ptr  = 0;
        dec_axi_rsp_active     = 1'b0;
        dec_axi_rsp_is_meta    = 1'b0;
        dec_axi_rsp_meta_plane1= 1'b0;
        dec_axi_rsp_addr       = {AXI_AW{1'b0}};
        dec_axi_rsp_beats_left = 8'd0;
        dec_axi_rsp_beat_idx   = 8'd0;
        dec_axi_rsp_tile_fmt   = 5'd0;
        dec_axi_rsp_tile_x     = 12'd0;
        dec_axi_rsp_tile_y     = 10'd0;

        repeat (8) @(posedge clk);
        enc_rst_n    = 1'b1;
        dec_presetn  = 1'b1;
        dec_axi_rstn = 1'b1;
        dec_otf_rstn = 1'b1;
        repeat (8) @(posedge clk);

        $display("");
        $display("==============================================================");
        $display("TB: ubwc_enc_wrapper_top -> ubwc_dec_wrapper_top NV12");
        $display("Encoder input : input_otf_stream.txt");
        $display("Decoder meta  : input_meta_plane0.txt / input_meta_plane1.txt");
        $display("Golden linear : golden_nv12_y_linear.memh / golden_nv12_uv_linear.memh");
        $display("Tile path     : decoder reads encoder-written tiled-uncompressed data");
        $display("==============================================================");

        program_enc_wrapper_regs();
        repeat (4) @(posedge clk);
        start_enc_otf = 1'b1;
        @(posedge clk);
        start_enc_otf = 1'b0;

        timeout_cycles = 0;
        while ((enc_idle_cycles_after_done < 50) && (timeout_cycles < TIMEOUT_CYCLES)) begin
            @(posedge clk);
            timeout_cycles = timeout_cycles + 1;
        end

        if (enc_otf_error) begin
            $fatal(1, "Encoder OTF driver reported input-stream error.");
        end
        if (timeout_cycles >= TIMEOUT_CYCLES) begin
            $fatal(1, "Timeout waiting encoder wrapper flow to finish.");
        end
        if (enc_coord_count != EXPECTED_TILE_CMDS) begin
            $fatal(1, "Encoder tile_coord mismatch: got=%0d exp=%0d", enc_coord_count, EXPECTED_TILE_CMDS);
        end
        if (enc_aw_count != EXPECTED_TILE_CMDS) begin
            $fatal(1, "Encoder AW count mismatch: got=%0d exp=%0d", enc_aw_count, EXPECTED_TILE_CMDS);
        end
        if (enc_w_count != EXPECTED_TILE_BEATS) begin
            $fatal(1, "Encoder W count mismatch: got=%0d exp=%0d", enc_w_count, EXPECTED_TILE_BEATS);
        end
        if (enc_queue_underflow_cnt != 0) begin
            $fatal(1, "Encoder queue underflow count = %0d", enc_queue_underflow_cnt);
        end
        if (enc_aw_addr_mismatch_cnt != 0) begin
            $fatal(1, "Encoder AW address mismatches = %0d", enc_aw_addr_mismatch_cnt);
        end
        if (enc_wlast_mismatch_cnt != 0) begin
            $fatal(1, "Encoder WLAST mismatches = %0d", enc_wlast_mismatch_cnt);
        end
        encoder_done_ok = 1'b1;

        otf_fd = $fopen("actual_otf_stream.txt", "w");
        if (otf_fd == 0)
            $fatal(1, "Failed to open actual_otf_stream.txt");

        program_dec_wrapper_cfg();
        trigger_dec_meta_start();
    end

    always @(posedge clk or negedge enc_rst_n) begin
        if (!enc_rst_n) begin
            enc_i_m_axi_awready      <= 1'b1;
            enc_i_m_axi_wready       <= 1'b1;
            enc_i_m_axi_bid          <= {(AXI_IDW+1){1'b0}};
            enc_i_m_axi_bresp        <= 2'b00;
            enc_i_m_axi_bvalid       <= 1'b0;
            enc_cmd_wr_ptr           <= 0;
            enc_cmd_rd_ptr           <= 0;
            enc_active_cmd_valid     <= 1'b0;
            enc_active_cmd_fmt       <= 5'd0;
            enc_active_cmd_x         <= 16'd0;
            enc_active_cmd_y         <= 16'd0;
            enc_active_cmd_addr      <= 32'd0;
            enc_active_cmd_beat_idx  <= 0;
            enc_last_awid            <= {(AXI_IDW+1){1'b0}};
            enc_coord_count          <= 0;
            enc_aw_count             <= 0;
            enc_w_count              <= 0;
            enc_queue_underflow_cnt  <= 0;
            enc_aw_addr_mismatch_cnt <= 0;
            enc_wlast_mismatch_cnt   <= 0;
            enc_idle_cycles_after_done <= 0;
        end else begin
            enc_i_m_axi_awready <= 1'b1;
            enc_i_m_axi_wready  <= 1'b1;

            if (enc_i_m_axi_bvalid && enc_o_m_axi_bready)
                enc_i_m_axi_bvalid <= 1'b0;

            if (enc_dut.tile_coord_vld) begin
                if (enc_cmd_wr_ptr < EXPECTED_TILE_CMDS) begin
                    enc_cmd_fmt_queue[enc_cmd_wr_ptr] <= enc_dut.enc_ci_format;
                    enc_cmd_x_queue[enc_cmd_wr_ptr]   <= enc_dut.tile_xcoord_raw;
                    enc_cmd_y_queue[enc_cmd_wr_ptr]   <= enc_dut.tile_ycoord_raw;
                    enc_cmd_wr_ptr                    <= enc_cmd_wr_ptr + 1;
                end
                enc_coord_count <= enc_coord_count + 1;
            end

            if (enc_o_m_axi_awvalid && enc_i_m_axi_awready) begin
                enc_aw_count  <= enc_aw_count + 1;
                enc_last_awid <= enc_o_m_axi_awid;
                if (enc_cmd_rd_ptr >= enc_cmd_wr_ptr) begin
                    enc_queue_underflow_cnt <= enc_queue_underflow_cnt + 1;
                end else begin
                    enc_active_cmd_valid    <= 1'b1;
                    enc_active_cmd_fmt      <= enc_cmd_fmt_queue[enc_cmd_rd_ptr];
                    enc_active_cmd_x        <= enc_cmd_x_queue[enc_cmd_rd_ptr];
                    enc_active_cmd_y        <= enc_cmd_y_queue[enc_cmd_rd_ptr];
                    enc_active_cmd_addr     <= enc_o_m_axi_awaddr[31:0];
                    enc_active_cmd_beat_idx <= 0;
                    if (enc_o_m_axi_awaddr[31:0] !== expected_enc_tile_addr32(enc_cmd_fmt_queue[enc_cmd_rd_ptr],
                                                                              enc_cmd_x_queue[enc_cmd_rd_ptr],
                                                                              enc_cmd_y_queue[enc_cmd_rd_ptr])) begin
                        if (enc_aw_addr_mismatch_cnt == 0) begin
                            $display("First enc AW mismatch: fmt=0x%0h x=%0d y=%0d exp=0x%08h act=0x%08h",
                                     enc_cmd_fmt_queue[enc_cmd_rd_ptr],
                                     enc_cmd_x_queue[enc_cmd_rd_ptr],
                                     enc_cmd_y_queue[enc_cmd_rd_ptr],
                                     expected_enc_tile_addr32(enc_cmd_fmt_queue[enc_cmd_rd_ptr],
                                                              enc_cmd_x_queue[enc_cmd_rd_ptr],
                                                              enc_cmd_y_queue[enc_cmd_rd_ptr]),
                                     enc_o_m_axi_awaddr[31:0]);
                        end
                        enc_aw_addr_mismatch_cnt <= enc_aw_addr_mismatch_cnt + 1;
                    end
                    enc_cmd_rd_ptr <= enc_cmd_rd_ptr + 1;
                end
            end

            if (enc_o_m_axi_wvalid && enc_i_m_axi_wready) begin
                enc_w_count <= enc_w_count + 1;
                if (!enc_active_cmd_valid) begin
                    enc_queue_underflow_cnt <= enc_queue_underflow_cnt + 1;
                end else begin
                    store_encoder_tile_axi_word(enc_active_cmd_fmt,
                                                enc_active_cmd_addr,
                                                enc_active_cmd_beat_idx,
                                                enc_o_m_axi_wdata);
                    if (enc_o_m_axi_wlast !== (enc_active_cmd_beat_idx == 7))
                        enc_wlast_mismatch_cnt <= enc_wlast_mismatch_cnt + 1;

                    if (enc_o_m_axi_wlast) begin
                        enc_i_m_axi_bvalid     <= 1'b1;
                        enc_i_m_axi_bid        <= enc_last_awid;
                        enc_i_m_axi_bresp      <= 2'b00;
                        enc_active_cmd_valid   <= 1'b0;
                        enc_active_cmd_beat_idx<= 0;
                    end else begin
                        enc_active_cmd_beat_idx<= enc_active_cmd_beat_idx + 1;
                    end
                end
            end

            if ((enc_aw_count == EXPECTED_TILE_CMDS) && (enc_w_count == EXPECTED_TILE_BEATS) && !enc_active_cmd_valid)
                enc_idle_cycles_after_done <= enc_idle_cycles_after_done + 1;
            else
                enc_idle_cycles_after_done <= 0;
        end
    end

    always @(posedge clk or negedge dec_axi_rstn) begin
        if (!dec_axi_rstn) begin
            dec_i_m_axi_arready          <= 1'b1;
            dec_tile_queue_wr_ptr        <= 0;
            dec_tile_queue_rd_ptr        <= 0;
            dec_axi_rsp_active           <= 1'b0;
            dec_axi_rsp_is_meta          <= 1'b0;
            dec_axi_rsp_meta_plane1      <= 1'b0;
            dec_axi_rsp_addr             <= {AXI_AW{1'b0}};
            dec_axi_rsp_beats_left       <= 8'd0;
            dec_axi_rsp_beat_idx         <= 8'd0;
            dec_axi_rsp_tile_fmt         <= 5'd0;
            dec_axi_rsp_tile_x           <= 12'd0;
            dec_axi_rsp_tile_y           <= 10'd0;
            dec_meta_ar_cnt              <= 0;
            dec_meta_y_ar_cnt            <= 0;
            dec_meta_uv_ar_cnt           <= 0;
            dec_tile_ar_cnt              <= 0;
            dec_axi_rbeat_cnt            <= 0;
            dec_tile_queue_underflow_cnt <= 0;
            dec_ar_addr_mismatch_cnt     <= 0;
            dec_ar_len_mismatch_cnt      <= 0;
        end else begin
            if (dec_dut.u_tile_arcmd_gen.tile_cmd_valid &&
                dec_dut.u_tile_arcmd_gen.tile_cmd_ready &&
                dec_dut.u_tile_arcmd_gen.tile_cmd_has_payload) begin
                dec_tile_fmt_queue[dec_tile_queue_wr_ptr]  <= dec_dut.u_tile_arcmd_gen.tile_cmd_format;
                dec_tile_x_queue[dec_tile_queue_wr_ptr]    <= dec_dut.u_tile_arcmd_gen.dec_meta_x;
                dec_tile_y_queue[dec_tile_queue_wr_ptr]    <= dec_dut.u_tile_arcmd_gen.dec_meta_y;
                dec_tile_alen_queue[dec_tile_queue_wr_ptr] <= dec_dut.u_tile_arcmd_gen.tile_cmd_alen;
                dec_tile_addr_queue[dec_tile_queue_wr_ptr] <= expected_dec_tile_addr(dec_dut.u_tile_arcmd_gen.tile_cmd_format,
                                                                                      dec_dut.u_tile_arcmd_gen.dec_meta_x,
                                                                                      dec_dut.u_tile_arcmd_gen.dec_meta_y);
                dec_tile_queue_wr_ptr <= dec_tile_queue_wr_ptr + 1;
            end

            if (!dec_axi_rsp_active) begin
                if (dec_o_m_axi_arvalid && dec_i_m_axi_arready) begin
                    if (dec_o_m_axi_araddr >= META_BASE_ADDR_Y) begin
                        dec_axi_rsp_active      <= 1'b1;
                        dec_axi_rsp_is_meta     <= 1'b1;
                        dec_axi_rsp_meta_plane1 <= (dec_o_m_axi_araddr >= META_BASE_ADDR_UV);
                        dec_axi_rsp_addr        <= dec_o_m_axi_araddr;
                        dec_axi_rsp_beats_left  <= dec_o_m_axi_arlen + 1'b1;
                        dec_axi_rsp_beat_idx    <= 8'd0;
                        dec_meta_ar_cnt         <= dec_meta_ar_cnt + 1;
                        if (dec_o_m_axi_araddr >= META_BASE_ADDR_UV)
                            dec_meta_uv_ar_cnt <= dec_meta_uv_ar_cnt + 1;
                        else
                            dec_meta_y_ar_cnt <= dec_meta_y_ar_cnt + 1;
                    end else begin
                        if (dec_tile_queue_rd_ptr >= dec_tile_queue_wr_ptr) begin
                            dec_tile_queue_underflow_cnt <= dec_tile_queue_underflow_cnt + 1;
                        end else begin
                            dec_axi_rsp_active     <= 1'b1;
                            dec_axi_rsp_is_meta    <= 1'b0;
                            dec_axi_rsp_addr       <= dec_o_m_axi_araddr;
                            dec_axi_rsp_beats_left <= dec_tile_alen_queue[dec_tile_queue_rd_ptr] + 1;
                            dec_axi_rsp_beat_idx   <= 8'd0;
                            dec_axi_rsp_tile_fmt   <= dec_tile_fmt_queue[dec_tile_queue_rd_ptr];
                            dec_axi_rsp_tile_x     <= dec_tile_x_queue[dec_tile_queue_rd_ptr];
                            dec_axi_rsp_tile_y     <= dec_tile_y_queue[dec_tile_queue_rd_ptr];
                            if (dec_o_m_axi_araddr !== dec_tile_addr_queue[dec_tile_queue_rd_ptr])
                                dec_ar_addr_mismatch_cnt <= dec_ar_addr_mismatch_cnt + 1;
                            if (dec_o_m_axi_arlen !== dec_tile_alen_queue[dec_tile_queue_rd_ptr])
                                dec_ar_len_mismatch_cnt <= dec_ar_len_mismatch_cnt + 1;
                            dec_tile_queue_rd_ptr <= dec_tile_queue_rd_ptr + 1;
                            dec_tile_ar_cnt       <= dec_tile_ar_cnt + 1;
                        end
                    end
                end
            end else begin
                if (dec_i_m_axi_rvalid && dec_o_m_axi_rready) begin
                    dec_axi_rbeat_cnt <= dec_axi_rbeat_cnt + 1;
                    if (dec_axi_rsp_beats_left == 8'd1) begin
                        dec_axi_rsp_active     <= 1'b0;
                        dec_axi_rsp_beats_left <= 8'd0;
                        dec_axi_rsp_beat_idx   <= 8'd0;
                    end else begin
                        dec_axi_rsp_beats_left <= dec_axi_rsp_beats_left - 1'b1;
                        dec_axi_rsp_beat_idx   <= dec_axi_rsp_beat_idx + 1'b1;
                    end
                end
            end
        end
    end

    always @(posedge i_otf_clk or negedge dec_otf_rstn) begin
        reg [127:0] exp_word;
        if (!dec_otf_rstn) begin
            otf_beat_cnt     <= 0;
            otf_mismatch_cnt <= 0;
            first_mismatch_x <= -1;
            first_mismatch_y <= -1;
            active_x         <= 0;
            active_y         <= 0;
            frame_done       <= 1'b0;
        end else if (encoder_done_ok && dec_i_otf_ready && dec_o_otf_de && !frame_done) begin
            exp_word = expected_otf_word(active_x, active_y);
            if (dec_o_otf_data !== exp_word) begin
                otf_mismatch_cnt <= otf_mismatch_cnt + 1;
                if (first_mismatch_x < 0) begin
                    first_mismatch_x <= active_x;
                    first_mismatch_y <= active_y;
                end
            end
            if (otf_fd != 0)
                $fwrite(otf_fd, "%032h\n", dec_o_otf_data);

            otf_beat_cnt <= otf_beat_cnt + 1;
            if (active_x == (IMG_W - 4)) begin
                active_x <= 0;
                if (active_y == (Y_H_STORED - 1)) begin
                    active_y   <= 0;
                    frame_done <= 1'b1;
                end else begin
                    active_y <= active_y + 1;
                end
            end else begin
                active_x <= active_x + 4;
            end

            if ((active_y[5:0] == 6'd0) && (active_x == 0))
                $display("Enc->Dec OTF progress: line %0d / %0d", active_y, Y_H_STORED);
        end
    end

    initial begin : finish_block
        timeout_cycles = 0;
        wait (encoder_done_ok);
        while (!frame_done && (timeout_cycles < TIMEOUT_CYCLES)) begin
            @(posedge clk);
            timeout_cycles = timeout_cycles + 1;
        end

        if (otf_fd != 0)
            $fclose(otf_fd);

        $display("Enc->Dec wrapper NV12 summary:");
        $display("  enc coord count      : %0d", enc_coord_count);
        $display("  enc tile AW count    : %0d", enc_aw_count);
        $display("  enc tile W count     : %0d", enc_w_count);
        $display("  enc queue underflow  : %0d", enc_queue_underflow_cnt);
        $display("  enc AW addr mismatch : %0d", enc_aw_addr_mismatch_cnt);
        $display("  enc WLAST mismatch   : %0d", enc_wlast_mismatch_cnt);
        $display("  dec meta AR count    : %0d", dec_meta_ar_cnt);
        $display("  dec tile AR count    : %0d", dec_tile_ar_cnt);
        $display("  dec AXI R beat count : %0d", dec_axi_rbeat_cnt);
        $display("  dec queue underflow  : %0d", dec_tile_queue_underflow_cnt);
        $display("  dec AR addr mismatch : %0d", dec_ar_addr_mismatch_cnt);
        $display("  dec AR len mismatch  : %0d", dec_ar_len_mismatch_cnt);
        $display("  otf beat count       : %0d", otf_beat_cnt);
        $display("  otf mismatch count   : %0d", otf_mismatch_cnt);

        if (timeout_cycles >= TIMEOUT_CYCLES)
            $fatal(1, "Timeout waiting decoder OTF output to finish.");
        if (dec_meta_ar_cnt == 0)
            $fatal(1, "Decoder never issued metadata reads.");
        if (dec_tile_ar_cnt != EXPECTED_TILE_CMDS)
            $fatal(1, "Decoder tile AR count mismatch: got=%0d exp=%0d", dec_tile_ar_cnt, EXPECTED_TILE_CMDS);
        if (dec_tile_queue_underflow_cnt != 0)
            $fatal(1, "Decoder tile queue underflow count = %0d", dec_tile_queue_underflow_cnt);
        if (dec_ar_addr_mismatch_cnt != 0)
            $fatal(1, "Decoder AR address mismatches = %0d", dec_ar_addr_mismatch_cnt);
        if (dec_ar_len_mismatch_cnt != 0)
            $fatal(1, "Decoder AR len mismatches = %0d", dec_ar_len_mismatch_cnt);
        if (otf_mismatch_cnt != 0)
            $fatal(1, "OTF mismatch count = %0d, first at x=%0d y=%0d", otf_mismatch_cnt, first_mismatch_x, first_mismatch_y);

        $display("PASS: enc_wrapper + dec_wrapper NV12 chain matched golden OTF output.");
        #50;
        $finish;
    end
endmodule

`default_nettype wire
