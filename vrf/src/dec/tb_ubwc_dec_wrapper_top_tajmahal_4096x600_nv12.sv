`timescale 1ns/1ps

module tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 #(
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0
);

    localparam integer APB_AW   = 16;
    localparam integer APB_DW   = 32;
    localparam integer AXI_AW   = 64;
    localparam integer AXI_DW   = 64;
    localparam integer AXI_IDW  = 4;
    localparam integer AXI_LENW = 8;
    localparam integer SB_WIDTH = 3;

    localparam integer IMG_W              = 4096;
    localparam integer IMG_H_ACTIVE       = 600;
    localparam integer Y_H_STORED         = 640;
    localparam integer UV_H_STORED        = 320;
    localparam integer TILE_W             = 32;
    localparam integer TILE_H             = 8;
    localparam integer TILE_X_COUNT       = IMG_W / TILE_W;
    localparam integer Y_TILE_Y_COUNT     = Y_H_STORED / TILE_H;
    localparam integer UV_TILE_Y_COUNT    = UV_H_STORED / TILE_H;
    localparam integer WORDS64_PER_Y_LINE = IMG_W / 8;
    localparam integer WORDS64_PER_UV_LINE= IMG_W / 8;
    localparam integer Y_WORDS64_TOTAL    = WORDS64_PER_Y_LINE * Y_H_STORED;
    localparam integer UV_WORDS64_TOTAL   = WORDS64_PER_UV_LINE * UV_H_STORED;
    localparam integer Y_META_PITCH_BYTES = 128;
    localparam integer Y_META_LINES       = 96;
    localparam integer UV_META_PITCH_BYTES= 128;
    localparam integer UV_META_LINES      = 64;
    localparam integer Y_META_WORDS64     = (Y_META_PITCH_BYTES * Y_META_LINES) / 8;
    localparam integer UV_META_WORDS64    = (UV_META_PITCH_BYTES * UV_META_LINES) / 8;
    localparam integer HIGHEST_BANK_BIT   = 16;
    // Matches ubwc_tileaddr.v bank spread behavior (adds +128B for small payload tiles
    // when addr_bytes[8] ^ addr_bytes[9] is true). In this bench the config always
    // enables bank spread via TILE_CFG0.
    localparam integer CFG_BANK_SPREAD_EN = 1;
    localparam integer EXPECTED_OTF_BEATS = (IMG_W / 4) * Y_H_STORED;
    localparam integer EXPECTED_TILE_CMDS = TILE_X_COUNT * (Y_TILE_Y_COUNT + UV_TILE_Y_COUNT);
    localparam integer MAX_FRAME_REPEAT   = 8;
    localparam integer TILE_QUEUE_CAPACITY= EXPECTED_TILE_CMDS * MAX_FRAME_REPEAT;
    localparam integer TIMEOUT_CYCLES     = 40000000;
    localparam integer DEBUG_LOG          = 0;

    localparam [4:0] BASE_FMT_YUV420_8 = 5'b00010;
    localparam [4:0] META_FMT_NV12_Y   = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV  = 5'b01001;
    localparam [AXI_AW-1:0] META_BASE_ADDR_Y  = 64'h0000_0000_8000_0000;
    localparam [AXI_AW-1:0] META_BASE_ADDR_UV = 64'h0000_0000_8028_3000;
    localparam [AXI_AW-1:0] TILE_BASE_ADDR_Y  = 64'h0000_0000_8000_3000;
    localparam [AXI_AW-1:0] TILE_BASE_ADDR_UV = 64'h0000_0000_8028_5000;
    localparam [AXI_AW-1:0] META_END_ADDR_Y   = META_BASE_ADDR_Y  + (Y_META_WORDS64  * 8);
    localparam [AXI_AW-1:0] META_END_ADDR_UV  = META_BASE_ADDR_UV + (UV_META_WORDS64 * 8);

    reg                       PCLK;
    reg                       PRESETn;
    reg                       PSEL;
    reg                       PENABLE;
    reg  [APB_AW-1:0]         PADDR;
    reg                       PWRITE;
    reg  [APB_DW-1:0]         PWDATA;
    wire                      PREADY;
    wire                      PSLVERR;
    wire [APB_DW-1:0]         PRDATA;

    reg                       i_axi_clk;
    reg                       i_axi_rstn;
    reg                       i_otf_clk;
    reg                       i_otf_rstn;

    wire                      o_otf_vsync;
    wire                      o_otf_hsync;
    wire                      o_otf_de;
    wire [127:0]              o_otf_data;
    wire [3:0]                o_otf_fcnt;
    wire [11:0]               o_otf_lcnt;
    reg                       i_otf_ready;

    wire                      o_otf_sram_a_wen;
    wire [12:0]               o_otf_sram_a_waddr;
    wire [127:0]              o_otf_sram_a_wdata;
    wire                      o_otf_sram_a_ren;
    wire [12:0]               o_otf_sram_a_raddr;
    wire [127:0]              i_otf_sram_a_rdata;
    wire                      o_otf_sram_b_wen;
    wire [12:0]               o_otf_sram_b_waddr;
    wire [127:0]              o_otf_sram_b_wdata;
    wire                      o_otf_sram_b_ren;
    wire [12:0]               o_otf_sram_b_raddr;
    wire [127:0]              i_otf_sram_b_rdata;
    wire                      o_bank0_en;
    wire                      o_bank0_wen;
    wire [12:0]               o_bank0_addr;
    wire [127:0]              o_bank0_din;
    wire [127:0]              i_bank0_dout;
    reg                       i_bank0_dout_vld;
    wire                      o_bank1_en;
    wire                      o_bank1_wen;
    wire [12:0]               o_bank1_addr;
    wire [127:0]              o_bank1_din;
    wire [127:0]              i_bank1_dout;
    reg                       i_bank1_dout_vld;

    wire [AXI_IDW:0]          o_m_axi_arid;
    wire [AXI_AW-1:0]         o_m_axi_araddr;
    wire [AXI_LENW-1:0]       o_m_axi_arlen;
    wire [3:0]                o_m_axi_arsize;
    wire [1:0]                o_m_axi_arburst;
    wire [0:0]                o_m_axi_arlock;
    wire [3:0]                o_m_axi_arcache;
    wire [2:0]                o_m_axi_arprot;
    wire                      o_m_axi_arvalid;
    reg                       i_m_axi_arready;
    wire [AXI_IDW:0]          i_m_axi_rid;
    wire [AXI_DW-1:0]         i_m_axi_rdata;
    wire                      i_m_axi_rvalid;
    wire [1:0]                i_m_axi_rresp;
    wire                      i_m_axi_rlast;
    wire                      o_m_axi_rready;
    wire [4:0]                o_stage_done;
    wire                      o_frame_done;
    wire                      o_irq;
    assign o_otf_sram_a_wen   = o_bank0_en && o_bank0_wen;
    assign o_otf_sram_a_waddr = o_bank0_addr;
    assign o_otf_sram_a_wdata = o_bank0_din;
    assign o_otf_sram_a_ren   = o_bank0_en && !o_bank0_wen;
    assign o_otf_sram_a_raddr = o_bank0_addr;
    assign i_bank0_dout       = i_otf_sram_a_rdata;
    assign o_otf_sram_b_wen   = o_bank1_en && o_bank1_wen;
    assign o_otf_sram_b_waddr = o_bank1_addr;
    assign o_otf_sram_b_wdata = o_bank1_din;
    assign o_otf_sram_b_ren   = o_bank1_en && !o_bank1_wen;
    assign o_otf_sram_b_raddr = o_bank1_addr;
    assign i_bank1_dout       = i_otf_sram_b_rdata;

    reg  [63:0]               meta_y_words  [0:Y_META_WORDS64-1];
    reg  [63:0]               meta_uv_words [0:UV_META_WORDS64-1];
    reg  [63:0]               tile_y_words  [0:Y_WORDS64_TOTAL-1];
    reg  [63:0]               tile_uv_words [0:UV_WORDS64_TOTAL-1];
    reg  [63:0]               linear_y_words [0:Y_WORDS64_TOTAL-1];
    reg  [63:0]               linear_uv_words[0:UV_WORDS64_TOTAL-1];

    reg  [4:0]                tile_fmt_queue  [0:TILE_QUEUE_CAPACITY-1];
    reg  [11:0]               tile_x_queue    [0:TILE_QUEUE_CAPACITY-1];
    reg  [9:0]                tile_y_queue    [0:TILE_QUEUE_CAPACITY-1];
    reg  [2:0]                tile_alen_queue [0:TILE_QUEUE_CAPACITY-1];
    reg  [AXI_AW-1:0]         tile_addr_queue [0:TILE_QUEUE_CAPACITY-1];

    reg                       axi_rsp_active;
    reg                       axi_rsp_is_meta;
    reg                       axi_rsp_meta_plane1;
    reg  [AXI_AW-1:0]         axi_rsp_addr;
    reg  [AXI_IDW:0]          axi_rsp_id;
    reg  [7:0]                axi_rsp_beats_left;
    reg  [7:0]                axi_rsp_beat_idx;
    reg  [4:0]                axi_rsp_tile_fmt;
    reg  [11:0]               axi_rsp_tile_x;
    reg  [9:0]                axi_rsp_tile_y;

    integer                   tile_queue_wr_ptr;
    integer                   tile_queue_rd_ptr;
    integer                   meta_ar_cnt;
    integer                   meta_y_ar_cnt;
    integer                   meta_uv_ar_cnt;
    integer                   tile_ar_cnt;
    integer                   axi_rbeat_cnt;
    integer                   meta_rbeat_cnt;
    integer                   tile_rbeat_cnt;
    integer                   tile_rbeat_no_rvo_cnt;
    integer                   ar_addr_mismatch_cnt;
    integer                   ar_len_mismatch_cnt;
    integer                   tile_queue_underflow_cnt;
    integer                   tb_frame_repeat;
    integer                   frames_started;
    integer                   frames_completed;
    integer                   expected_otf_beats_total;
    integer                   otf_beat_cnt;
    integer                   otf_mismatch_cnt;
    integer                   first_mismatch_x;
    integer                   first_mismatch_y;
    integer                   last_progress_cycle;
    integer                   last_otf_progress_cycle;
    integer                   cycle_cnt;
    integer                   timeout_cycles;
    integer                   otf_fd;
    integer                   active_x;
    integer                   active_y;
    integer                   dbg_trace_cycles;
    integer                   ci_fire_cnt;
    integer                   tile_hdr_fire_cnt;
    integer                   rvo_fire_cnt;
    integer                   writer_vld_cnt;
    integer                   fetcher_done_cnt;
    integer                   fifo_wr_cnt;
    integer                   fifo_rd_cnt;
    integer                   dbg_tile_idx_started;
    integer                   dbg_tile_beats_seen;
    integer                   dbg_stuck_tile_x;
    integer                   dbg_stuck_tile_y;
    integer                   dbg_stuck_tile_fmt;
    integer                   dbg_frame_start_cnt;
    reg                       frame_done;
    event                     frame_complete_ev;

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

    // Calculate the swizzled plane-local tile base address in 64-bit word units.
    // This is used to index the pre-loaded swizzled tile memory arrays in fake mode.
    function automatic integer plane_tile_base_word;
        input integer tile_x;
        input integer tile_y;
        input integer tile_width;
        input integer tile_height;
        input integer surface_pitch_bytes;
        input integer highest_bank_bit;
        input integer bpp;
        integer macro_tile_x;
        integer macro_tile_y;
        integer temp_tile_x;
        integer temp_tile_y;
        integer tile_row_pixels;
        integer bit_val;
        longint unsigned addr_bytes;
        begin
            macro_tile_x = tile_x / 4;
            macro_tile_y = tile_y / 4;
            temp_tile_x  = tile_x % 8;
            temp_tile_y  = tile_y % 8;

            addr_bytes = ((64'd1 * surface_pitch_bytes) * (macro_tile_y * 4) * tile_height) +
                         (64'd4096 * macro_tile_x) +
                         (64'd256  * macro_tile_slot(temp_tile_x, temp_tile_y));

            if (((64'd16 * surface_pitch_bytes) % (64'd1 << highest_bank_bit)) == 0) begin
                if (((bpp == 1) && (tile_width * 4 == 128) && (tile_height * 4 == 32)) ||
                    ((bpp == 2) && (tile_width * 4 == 64)  && (tile_height * 4 == 32))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 4;
                end
                bit_val = ((addr_bytes >> (highest_bank_bit - 1)) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (64'd1 << (highest_bank_bit - 1));
                end else begin
                    addr_bytes = addr_bytes & ~(64'd1 << (highest_bank_bit - 1));
                end
            end

            if (((64'd16 * surface_pitch_bytes) % (64'd1 << (highest_bank_bit + 1))) == 0) begin
                if (((bpp == 1) && (tile_width * 4 == 128) && (tile_height * 4 == 32)) ||
                    ((bpp == 2) && (tile_width * 4 == 64)  && (tile_height * 4 == 32))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 6;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end
                bit_val = ((addr_bytes >> highest_bank_bit) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (64'd1 << highest_bank_bit);
                end else begin
                    addr_bytes = addr_bytes & ~(64'd1 << highest_bank_bit);
                end
            end

            plane_tile_base_word = addr_bytes >> 3;
        end
    endfunction

    function automatic [AXI_AW-1:0] expected_tile_addr;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        integer macro_tile_x;
        integer macro_tile_y;
        integer temp_tile_x;
        integer temp_tile_y;
        integer tile_row_pixels;
        integer bit_val;
        longint unsigned addr_bytes;
        longint unsigned base_addr_bytes;
        longint unsigned surface_pitch_bytes;
        begin
            surface_pitch_bytes = 4096;
            base_addr_bytes = 64'd0;
            if (TB_REAL_VIVO_MODE != 0) begin
                base_addr_bytes = (fmt == META_FMT_NV12_UV) ? TILE_BASE_ADDR_UV : TILE_BASE_ADDR_Y;
            end

            macro_tile_x = tile_x / 4;
            macro_tile_y = tile_y / 4;
            temp_tile_x  = tile_x % 8;
            temp_tile_y  = tile_y % 8;

            // Match ubwc_tileaddr.v / ubwc_demo.cpp behavior: swizzle the plane-local
            // address first, then add the plane base afterwards.
            addr_bytes = (surface_pitch_bytes * (macro_tile_y * 4) * TILE_H) +
                         (64'd4096 * macro_tile_x) +
                         (64'd256  * macro_tile_slot(temp_tile_x, temp_tile_y));

            if (((64'd16 * surface_pitch_bytes) % (64'd1 << HIGHEST_BANK_BIT)) == 0) begin
                // Special swizzle tap set for NV12 32x8 tiles.
                tile_row_pixels = (tile_y * TILE_H) >> 5;
                bit_val = ((addr_bytes >> (HIGHEST_BANK_BIT - 1)) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (64'd1 << (HIGHEST_BANK_BIT - 1));
                end else begin
                    addr_bytes = addr_bytes & ~(64'd1 << (HIGHEST_BANK_BIT - 1));
                end
            end

            if (((64'd16 * surface_pitch_bytes) % (64'd1 << (HIGHEST_BANK_BIT + 1))) == 0) begin
                tile_row_pixels = (tile_y * TILE_H) >> 6;
                bit_val = ((addr_bytes >> HIGHEST_BANK_BIT) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (64'd1 << HIGHEST_BANK_BIT);
                end else begin
                    addr_bytes = addr_bytes & ~(64'd1 << HIGHEST_BANK_BIT);
                end
            end

            expected_tile_addr = addr_bytes + base_addr_bytes;
        end
    endfunction

    function automatic integer addr_is_meta;
        input [AXI_AW-1:0] addr;
        begin
            addr_is_meta =
                ((addr >= META_BASE_ADDR_Y)  && (addr < META_END_ADDR_Y)) ||
                ((addr >= META_BASE_ADDR_UV) && (addr < META_END_ADDR_UV));
        end
    endfunction

    function automatic integer addr_is_meta_uv;
        input [AXI_AW-1:0] addr;
        begin
            addr_is_meta_uv = (addr >= META_BASE_ADDR_UV) && (addr < META_END_ADDR_UV);
        end
    endfunction

    function automatic [AXI_DW-1:0] pack_meta_axi_word;
        input integer is_uv_plane;
        input [AXI_AW-1:0] addr;
        input integer beat_idx;
        integer word64_base;
        integer lane_idx;
        begin
            pack_meta_axi_word = {AXI_DW{1'b0}};
            if (is_uv_plane != 0) begin
                word64_base = ((addr - META_BASE_ADDR_UV) >> 3) + beat_idx * (AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word64_base + lane_idx) < UV_META_WORDS64)
                        pack_meta_axi_word[lane_idx*64 +: 64] = meta_uv_words[word64_base + lane_idx];
                end
            end else begin
                word64_base = ((addr - META_BASE_ADDR_Y) >> 3) + beat_idx * (AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word64_base + lane_idx) < Y_META_WORDS64)
                        pack_meta_axi_word[lane_idx*64 +: 64] = meta_y_words[word64_base + lane_idx];
                end
            end
        end
    endfunction

    function automatic [AXI_DW-1:0] pack_tile_axi_word;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer beat_idx;
        integer word64_base;
        integer word_idx;
        integer lane_idx;
        begin
            pack_tile_axi_word = {AXI_DW{1'b0}};
            word64_base = plane_tile_base_word(tile_x, tile_y, TILE_W, TILE_H, 4096, HIGHEST_BANK_BIT, 1);
            word_idx    = word64_base + beat_idx * (AXI_DW / 64);
            if (fmt == META_FMT_NV12_UV) begin
                for (lane_idx = 0; lane_idx < (AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word_idx + lane_idx) < UV_WORDS64_TOTAL)
                        pack_tile_axi_word[lane_idx*64 +: 64] = tile_uv_words[word_idx + lane_idx];
                end
            end else begin
                for (lane_idx = 0; lane_idx < (AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word_idx + lane_idx) < Y_WORDS64_TOTAL)
                        pack_tile_axi_word[lane_idx*64 +: 64] = tile_y_words[word_idx + lane_idx];
                end
            end
        end
    endfunction

    function automatic [AXI_DW-1:0] pack_raw_tile_axi_word;
        input [4:0] fmt;
        input [AXI_AW-1:0] addr;
        input integer beat_idx;
        integer word64_base;
        integer lane_idx;
        begin
            pack_raw_tile_axi_word = {AXI_DW{1'b0}};
            if (fmt == META_FMT_NV12_UV) begin
                word64_base = ((addr - TILE_BASE_ADDR_UV) >> 3) + beat_idx * (AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word64_base + lane_idx) < UV_WORDS64_TOTAL)
                        pack_raw_tile_axi_word[lane_idx*64 +: 64] = tile_uv_words[word64_base + lane_idx];
                end
            end else begin
                word64_base = ((addr - TILE_BASE_ADDR_Y) >> 3) + beat_idx * (AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word64_base + lane_idx) < Y_WORDS64_TOTAL)
                        pack_raw_tile_axi_word[lane_idx*64 +: 64] = tile_y_words[word64_base + lane_idx];
                end
            end
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

    wire [AXI_DW-1:0] axi_rsp_rdata =
        axi_rsp_is_meta ? pack_meta_axi_word(axi_rsp_meta_plane1, axi_rsp_addr, axi_rsp_beat_idx) :
        ((TB_REAL_VIVO_MODE != 0) ?
            pack_raw_tile_axi_word(axi_rsp_tile_fmt, axi_rsp_addr, axi_rsp_beat_idx) :
            pack_tile_axi_word(axi_rsp_tile_fmt, axi_rsp_tile_x, axi_rsp_tile_y, axi_rsp_beat_idx));

    assign i_m_axi_rvalid = axi_rsp_active;
    assign i_m_axi_rid    = axi_rsp_active ? axi_rsp_id : {(AXI_IDW+1){1'b0}};
    assign i_m_axi_rdata  = axi_rsp_active ? axi_rsp_rdata : {AXI_DW{1'b0}};
    assign i_m_axi_rresp  = 2'b00;
    assign i_m_axi_rlast  = axi_rsp_active && (axi_rsp_beats_left == 8'd1);

    task automatic apb_write;
        input [APB_AW-1:0] addr;
        input [APB_DW-1:0] data;
        begin
            @(posedge PCLK);
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b1;
            PADDR   <= addr;
            PWDATA  <= data;
            @(posedge PCLK);
            PENABLE <= 1'b1;
            @(posedge PCLK);
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
            PADDR   <= {APB_AW{1'b0}};
            PWDATA  <= {APB_DW{1'b0}};
        end
    endtask

    task automatic apb_read;
        input  [APB_AW-1:0] addr;
        output [APB_DW-1:0] data;
        begin
            @(posedge PCLK);
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
            PADDR   <= addr;
            PWDATA  <= {APB_DW{1'b0}};
            @(posedge PCLK);
            PENABLE <= 1'b1;
            @(posedge PCLK);
            data    = PRDATA;
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PADDR   <= {APB_AW{1'b0}};
        end
    endtask

    task automatic program_wrapper_cfg;
        begin
            // TILE_CFG0:
            // lvl1=0, lvl2=1, lvl3=1, highest_bank_bit=16,
            // bank_spread=1, 4line_format=0, lossy_rgba_2_1=0
            apb_write(16'h0008, 32'h0000_0306);
            apb_write(16'h000c, 32'd256);
            apb_write(16'h0010, 32'h0000_000f);
            if (TB_REAL_VIVO_MODE != 0) begin
                apb_write(16'h0044, TILE_BASE_ADDR_UV[31:0]);
                apb_write(16'h0048, TILE_BASE_ADDR_UV[63:32]);
                apb_write(16'h004c, TILE_BASE_ADDR_Y[31:0]);
                apb_write(16'h0050, TILE_BASE_ADDR_Y[63:32]);
            end else begin
                apb_write(16'h0044, 32'd0);
                apb_write(16'h0048, 32'd0);
                apb_write(16'h004c, 32'd0);
                apb_write(16'h0050, 32'd0);
            end
            apb_write(16'h0014, 32'h0000_0001);

            apb_write(16'h001c, META_BASE_ADDR_Y[31:0]);
            apb_write(16'h0020, META_BASE_ADDR_Y[63:32]);
            apb_write(16'h0024, META_BASE_ADDR_UV[31:0]);
            apb_write(16'h0028, META_BASE_ADDR_UV[63:32]);
            apb_write(16'h002c, {16'd80, 16'd128});

            apb_write(16'h0030, {11'd0, BASE_FMT_YUV420_8, 16'd4096});
            apb_write(16'h0034, {16'd44, 16'd4400});
            apb_write(16'h0038, {16'd4096, 16'd148});
            apb_write(16'h003c, {16'd5, 16'd682});
            apb_write(16'h0040, {16'd640, 16'd36});

            apb_write(16'h0018, 32'h0000_0020);
        end
    endtask

    task automatic trigger_meta_start;
        begin
            repeat (16) @(posedge i_axi_clk);
            apb_write(16'h0018, 32'h0000_0021);
        end
    endtask

    task automatic wait_wrapper_idle;
        integer settle_cycles;
        reg [31:0] status0;
        reg [31:0] status1;
        begin
            settle_cycles = 0;
            status0 = 32'd0;
            status1 = 32'd0;
            while (settle_cycles < 200000) begin
                apb_read(16'h0054, status0);
                apb_read(16'h0058, status1);
                if (status0[6] && status1[4] && !axi_rsp_active && !i_m_axi_rvalid) begin
                    settle_cycles = 200000;
                end else begin
                    @(posedge i_axi_clk);
                    settle_cycles = settle_cycles + 1;
                end
            end

            if (!(status0[6] && status1[4] && !axi_rsp_active && !i_m_axi_rvalid)) begin
                $display("TB: STATUS0=0x%08h STATUS1=0x%08h", status0, status1);
                $display("TB: live busy meta=%0b tile=%0b vivo=%0b otf=%0b frame_active=%0b",
                         status0[1], status0[2], status0[3], status0[4], status0[0]);
                $display("TB: done meta=%0b tile=%0b vivo=%0b otf=%0b frame=%0b",
                         status1[0], status1[1], status1[2], status1[3], status1[4]);
                $display("TB: seen meta=%0b tile=%0b vivo=%0b otf=%0b",
                         status1[5], status1[6], status1[7], status1[8]);
                $display("TB: axi_rsp_active=%0b i_m_axi_rvalid=%0b beats_left=%0d",
                         axi_rsp_active, i_m_axi_rvalid, axi_rsp_beats_left);
                $fatal(1, "Wrapper did not report ready_for_next_start before the next frame start.");
            end

            repeat (32) @(posedge i_axi_clk);
        end
    endtask

    sram_pdp_8192x128 u_otf_sram_bank_a (
        .clk   (i_axi_clk),
        .wen   (o_otf_sram_a_wen),
        .waddr (o_otf_sram_a_waddr),
        .wdata (o_otf_sram_a_wdata),
        .ren   (o_otf_sram_a_ren),
        .raddr (o_otf_sram_a_raddr),
        .rdata (i_otf_sram_a_rdata)
    );

    sram_pdp_8192x128 u_otf_sram_bank_b (
        .clk   (i_axi_clk),
        .wen   (o_otf_sram_b_wen),
        .waddr (o_otf_sram_b_waddr),
        .wdata (o_otf_sram_b_wdata),
        .ren   (o_otf_sram_b_ren),
        .raddr (o_otf_sram_b_raddr),
        .rdata (i_otf_sram_b_rdata)
    );

    ubwc_dec_wrapper_top #(
        .APB_AW   (APB_AW),
        .APB_DW   (APB_DW),
        .AXI_AW   (AXI_AW),
        .AXI_DW   (AXI_DW),
        .AXI_IDW  (AXI_IDW),
        .AXI_LENW (AXI_LENW),
        .SB_WIDTH (SB_WIDTH),
        .FORCE_FULL_PAYLOAD (FORCE_FULL_PAYLOAD_CASE)
    ) dut (
        .PCLK              (PCLK),
        .PRESETn           (PRESETn),
        .PSEL              (PSEL),
        .PENABLE           (PENABLE),
        .PADDR             (PADDR),
        .PWRITE            (PWRITE),
        .PWDATA            (PWDATA),
        .PREADY            (PREADY),
        .PSLVERR           (PSLVERR),
        .PRDATA            (PRDATA),
        .i_otf_clk         (i_otf_clk),
        .i_otf_rstn        (i_otf_rstn),
        .o_otf_vsync       (o_otf_vsync),
        .o_otf_hsync       (o_otf_hsync),
        .o_otf_de          (o_otf_de),
        .o_otf_data        (o_otf_data),
        .o_otf_fcnt        (o_otf_fcnt),
        .o_otf_lcnt        (o_otf_lcnt),
        .i_otf_ready       (i_otf_ready),
        .o_bank0_en        (o_bank0_en),
        .o_bank0_wen       (o_bank0_wen),
        .o_bank0_addr      (o_bank0_addr),
        .o_bank0_din       (o_bank0_din),
        .i_bank0_dout      (i_bank0_dout),
        .i_bank0_dout_vld  (i_bank0_dout_vld),
        .o_bank1_en        (o_bank1_en),
        .o_bank1_wen       (o_bank1_wen),
        .o_bank1_addr      (o_bank1_addr),
        .o_bank1_din       (o_bank1_din),
        .i_bank1_dout      (i_bank1_dout),
        .i_bank1_dout_vld  (i_bank1_dout_vld),
        .i_axi_clk         (i_axi_clk),
        .i_axi_rstn        (i_axi_rstn),
        .o_m_axi_arid      (o_m_axi_arid),
        .o_m_axi_araddr    (o_m_axi_araddr),
        .o_m_axi_arlen     (o_m_axi_arlen),
        .o_m_axi_arsize    (o_m_axi_arsize),
        .o_m_axi_arburst   (o_m_axi_arburst),
        .o_m_axi_arlock    (o_m_axi_arlock),
        .o_m_axi_arcache   (o_m_axi_arcache),
        .o_m_axi_arprot    (o_m_axi_arprot),
        .o_m_axi_arvalid   (o_m_axi_arvalid),
        .i_m_axi_arready   (i_m_axi_arready),
        .i_m_axi_rid       (i_m_axi_rid),
        .i_m_axi_rdata     (i_m_axi_rdata),
        .i_m_axi_rvalid    (i_m_axi_rvalid),
        .i_m_axi_rresp     (i_m_axi_rresp),
        .i_m_axi_rlast     (i_m_axi_rlast),
        .o_m_axi_rready    (o_m_axi_rready),
        .o_stage_done      (o_stage_done),
        .o_frame_done      (o_frame_done),
        .o_irq             (o_irq)
    );

    initial begin
        PCLK = 1'b0;
        forever #5 PCLK = ~PCLK;
    end

    initial begin
        i_axi_clk = 1'b0;
        forever #1 i_axi_clk = ~i_axi_clk;
    end

    initial begin
        i_otf_clk = 1'b0;
        forever #5 i_otf_clk = ~i_otf_clk;
    end

    always @(posedge i_axi_clk) begin
        cycle_cnt <= cycle_cnt + 1;
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            i_bank0_dout_vld <= 1'b0;
            i_bank1_dout_vld <= 1'b0;
        end else begin
            i_bank0_dout_vld <= o_otf_sram_a_ren;
            i_bank1_dout_vld <= o_otf_sram_b_ren;
        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            tile_queue_wr_ptr <= 0;
        end else begin
            if (dut.u_tile_arcmd_gen.tile_cmd_valid &&
                dut.u_tile_arcmd_gen.tile_cmd_ready &&
                dut.u_tile_arcmd_gen.tile_cmd_has_payload) begin
                reg [AXI_AW-1:0] exp_addr;
                tile_fmt_queue[tile_queue_wr_ptr]  <= dut.u_tile_arcmd_gen.tile_cmd_format;
                tile_x_queue[tile_queue_wr_ptr]    <= dut.u_tile_arcmd_gen.dec_meta_x;
                tile_y_queue[tile_queue_wr_ptr]    <= dut.u_tile_arcmd_gen.dec_meta_y;
                tile_alen_queue[tile_queue_wr_ptr] <= dut.u_tile_arcmd_gen.tile_cmd_alen;
                exp_addr = expected_tile_addr(dut.u_tile_arcmd_gen.tile_cmd_format,
                                              dut.u_tile_arcmd_gen.dec_meta_x,
                                              dut.u_tile_arcmd_gen.dec_meta_y);
                // Bank spread only affects compressed tiles <= 128B (alen <= 3) that carry payload.
                if (CFG_BANK_SPREAD_EN &&
                    (dut.u_tile_arcmd_gen.tile_cmd_alen <= 3) &&
                    (exp_addr[8] ^ exp_addr[9])) begin
                    exp_addr = exp_addr + 64'd128;
                end
                tile_addr_queue[tile_queue_wr_ptr] <= exp_addr;
                tile_queue_wr_ptr     <= tile_queue_wr_ptr + 1;
                last_progress_cycle   <= cycle_cnt;
            end
        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            i_m_axi_arready          <= 1'b1;
            axi_rsp_active           <= 1'b0;
            axi_rsp_is_meta          <= 1'b0;
            axi_rsp_meta_plane1      <= 1'b0;
            axi_rsp_addr             <= {AXI_AW{1'b0}};
            axi_rsp_id               <= {(AXI_IDW+1){1'b0}};
            axi_rsp_beats_left       <= 8'd0;
            axi_rsp_beat_idx         <= 8'd0;
            axi_rsp_tile_fmt         <= 5'd0;
            axi_rsp_tile_x           <= 12'd0;
            axi_rsp_tile_y           <= 10'd0;
            tile_queue_rd_ptr        <= 0;
            meta_ar_cnt              <= 0;
            meta_y_ar_cnt            <= 0;
            meta_uv_ar_cnt           <= 0;
            tile_ar_cnt              <= 0;
            axi_rbeat_cnt            <= 0;
            meta_rbeat_cnt           <= 0;
            tile_rbeat_cnt           <= 0;
            tile_rbeat_no_rvo_cnt    <= 0;
            ar_addr_mismatch_cnt     <= 0;
            ar_len_mismatch_cnt      <= 0;
            tile_queue_underflow_cnt <= 0;
            last_progress_cycle      <= 0;
            last_otf_progress_cycle  <= 0;
            ci_fire_cnt              <= 0;
            tile_hdr_fire_cnt        <= 0;
            rvo_fire_cnt             <= 0;
            writer_vld_cnt           <= 0;
            fetcher_done_cnt         <= 0;
            fifo_wr_cnt              <= 0;
            fifo_rd_cnt              <= 0;
            dbg_tile_idx_started     <= 0;
            dbg_tile_beats_seen      <= 0;
            dbg_stuck_tile_x         <= 0;
            dbg_stuck_tile_y         <= 0;
            dbg_stuck_tile_fmt       <= 0;
            dbg_frame_start_cnt      <= 0;
        end else if (dut.frame_start_pulse_axi) begin
            i_m_axi_arready          <= 1'b1;
            axi_rsp_active           <= 1'b0;
            axi_rsp_is_meta          <= 1'b0;
            axi_rsp_meta_plane1      <= 1'b0;
            axi_rsp_addr             <= {AXI_AW{1'b0}};
            axi_rsp_id               <= {(AXI_IDW+1){1'b0}};
            axi_rsp_beats_left       <= 8'd0;
            axi_rsp_beat_idx         <= 8'd0;
            axi_rsp_tile_fmt         <= 5'd0;
            axi_rsp_tile_x           <= 12'd0;
            axi_rsp_tile_y           <= 10'd0;
            dbg_frame_start_cnt      <= dbg_frame_start_cnt + 1;
        end else begin
            if (dut.tile_ci_valid_int && dut.tile_ci_ready_int) begin
                ci_fire_cnt <= ci_fire_cnt + 1;
                dbg_tile_idx_started <= dbg_tile_idx_started + 1;
                dbg_tile_beats_seen  <= 0;
                dbg_stuck_tile_fmt   <= dut.tile_ci_format_int;
                dbg_stuck_tile_x     <= dut.tile_x_coord_int;
                dbg_stuck_tile_y     <= dut.tile_y_coord_int;
                if (DEBUG_LOG &&
                    (dut.tile_x_coord_int == 12'd79 || dut.tile_x_coord_int == 12'd80) &&
                    (dut.tile_y_coord_int == 10'd1)) begin
                    $display("DBG: CI fire cycle=%0d idx=%0d fmt=0x%0h x=%0d y=%0d alen=%0d",
                             cycle_cnt,
                             dbg_tile_idx_started + 1,
                             dut.tile_ci_format_int,
                             dut.tile_x_coord_int,
                             dut.tile_y_coord_int,
                             dut.tile_ci_alen_int);
                end
            end
            if (dut.otf_axis_tile_valid && dut.otf_axis_tile_ready_int) begin
                tile_hdr_fire_cnt <= tile_hdr_fire_cnt + 1;
            end
            if (dut.vivo_rvo_valid && dut.vivo_rvo_ready) begin
                rvo_fire_cnt <= rvo_fire_cnt + 1;
                dbg_tile_beats_seen <= dbg_tile_beats_seen + 1;
                if (DEBUG_LOG &&
                    (dbg_stuck_tile_x == 79 || dbg_stuck_tile_x == 80) &&
                    (dbg_stuck_tile_y == 1)) begin
                    $display("DBG: tile beat cycle=%0d idx=%0d x=%0d y=%0d beat=%0d last=%0b",
                             cycle_cnt,
                             dbg_tile_idx_started,
                             dbg_stuck_tile_x,
                             dbg_stuck_tile_y,
                             dbg_tile_beats_seen + 1,
                             dut.vivo_rvo_last);
                end
            end
            if (dut.meta_m_axi_rvalid && dut.meta_m_axi_rready) begin
                meta_rbeat_cnt <= meta_rbeat_cnt + 1;
            end
            if (dut.tile_m_axi_rvalid && dut.tile_m_axi_rready) begin
                tile_rbeat_cnt <= tile_rbeat_cnt + 1;
                if (DEBUG_LOG && !(dut.vivo_rvo_valid && dut.vivo_rvo_ready)) begin
                    tile_rbeat_no_rvo_cnt <= tile_rbeat_no_rvo_cnt + 1;
                    $display("DBG: tile beat accepted without rvo fire at cycle=%0d tile_active=%0b out_left=%0d in_left=%0d ci_ready=%0b tready=%0b rvalid=%0b rlast=%0b",
                             cycle_cnt,
                             dut.u_dec_vivo_top.r_tile_active,
                             dut.u_dec_vivo_top.r_out_beats_left,
                             dut.u_dec_vivo_top.r_in_beats_left,
                             dut.vivo_ci_ready_raw,
                             dut.vivo_rvo_ready,
                             dut.tile_m_axi_rvalid,
                             dut.tile_m_axi_rlast);
                end
            end
            if (dut.u_tile_to_otf.writer_vld) begin
                writer_vld_cnt <= writer_vld_cnt + 1;
            end
            if (dut.u_tile_to_otf.fetcher_done) begin
                fetcher_done_cnt <= fetcher_done_cnt + 1;
            end
            if (dut.u_tile_to_otf.fifo_wr_en) begin
                fifo_wr_cnt <= fifo_wr_cnt + 1;
            end
            if (dut.u_tile_to_otf.fifo_rd_en) begin
                fifo_rd_cnt <= fifo_rd_cnt + 1;
            end
            if (DEBUG_LOG && (cycle_cnt >= 3329) && (cycle_cnt <= 3346)) begin
                $display("DBG: cyc=%0d m_rvalid=%0b m_rready=%0b m_rlast=%0b inflight=%0b owner_s0=%0b rbuf_valid=%0b s1_rvalid=%0b s1_rready=%0b s1_rlast=%0b ci_ready=%0b tile_active=%0b out_left=%0d in_left=%0d",
                         cycle_cnt,
                         i_m_axi_rvalid,
                         o_m_axi_rready,
                         i_m_axi_rlast,
                         dut.rd_interconnect_core_busy_int,
                         (!dut.core_m_axi_rid_r[AXI_IDW]),
                         1'b0,
                         dut.tile_m_axi_rvalid,
                         dut.tile_m_axi_rready,
                         dut.tile_m_axi_rlast,
                         dut.tile_ci_ready_int,
                         dut.u_dec_vivo_top.r_tile_active,
                         dut.u_dec_vivo_top.r_out_beats_left,
                         dut.u_dec_vivo_top.r_in_beats_left);
            end

            if (!axi_rsp_active) begin
                i_m_axi_arready <= 1'b1;
                if (o_m_axi_arvalid && i_m_axi_arready) begin
                    i_m_axi_arready <= 1'b0;
                    if (addr_is_meta(o_m_axi_araddr)) begin
                        axi_rsp_active      <= 1'b1;
                        axi_rsp_is_meta     <= 1'b1;
                        axi_rsp_meta_plane1 <= addr_is_meta_uv(o_m_axi_araddr);
                        axi_rsp_addr        <= o_m_axi_araddr;
                        axi_rsp_id          <= o_m_axi_arid;
                        axi_rsp_beats_left  <= o_m_axi_arlen + 1'b1;
                        axi_rsp_beat_idx    <= 8'd0;
                        meta_ar_cnt         <= meta_ar_cnt + 1;
                        if (addr_is_meta_uv(o_m_axi_araddr)) begin
                            meta_uv_ar_cnt <= meta_uv_ar_cnt + 1;
                        end else begin
                            meta_y_ar_cnt <= meta_y_ar_cnt + 1;
                        end
                        last_progress_cycle <= cycle_cnt;
                    end else begin
                        if (tile_queue_rd_ptr >= tile_queue_wr_ptr) begin
                            tile_queue_underflow_cnt <= tile_queue_underflow_cnt + 1;
                        end else begin
                            if (DEBUG_LOG &&
                                (tile_x_queue[tile_queue_rd_ptr] == 12'd79 ||
                                 tile_x_queue[tile_queue_rd_ptr] == 12'd80) &&
                                (tile_y_queue[tile_queue_rd_ptr] == 10'd1)) begin
                                $display("DBG: tile AR cycle=%0d qidx=%0d fmt=0x%0h x=%0d y=%0d addr=0x%0h len=%0d",
                                         cycle_cnt,
                                         tile_queue_rd_ptr,
                                         tile_fmt_queue[tile_queue_rd_ptr],
                                         tile_x_queue[tile_queue_rd_ptr],
                                         tile_y_queue[tile_queue_rd_ptr],
                                         o_m_axi_araddr,
                                         tile_alen_queue[tile_queue_rd_ptr]);
                            end
                            axi_rsp_active     <= 1'b1;
                            axi_rsp_is_meta    <= 1'b0;
                            axi_rsp_addr       <= o_m_axi_araddr;
                            axi_rsp_id         <= o_m_axi_arid;
                            axi_rsp_beats_left <= ((tile_alen_queue[tile_queue_rd_ptr] + 1) * (256 / AXI_DW));
                            axi_rsp_beat_idx   <= 8'd0;
                            axi_rsp_tile_fmt   <= tile_fmt_queue[tile_queue_rd_ptr];
                            axi_rsp_tile_x     <= tile_x_queue[tile_queue_rd_ptr];
                            axi_rsp_tile_y     <= tile_y_queue[tile_queue_rd_ptr];
                            if (o_m_axi_araddr !== tile_addr_queue[tile_queue_rd_ptr]) begin
                                if ((TB_REAL_VIVO_MODE != 0) && (ar_addr_mismatch_cnt < 8)) begin
                                    reg [AXI_AW-1:0] exp_addr_base;
                                    reg [AXI_AW-1:0] exp_addr_final;
                                    reg              exp_spread;
                                    exp_addr_base = expected_tile_addr(tile_fmt_queue[tile_queue_rd_ptr],
                                                                       tile_x_queue[tile_queue_rd_ptr],
                                                                       tile_y_queue[tile_queue_rd_ptr]);
                                    exp_spread = CFG_BANK_SPREAD_EN &&
                                                 (tile_alen_queue[tile_queue_rd_ptr] <= 3) &&
                                                 (exp_addr_base[8] ^ exp_addr_base[9]);
                                    exp_addr_final = exp_addr_base + (exp_spread ? 64'd128 : 64'd0);
                                    $display("DBG: AR mismatch qidx=%0d fmt=0x%0h x=%0d y=%0d alen=%0d spread=%0b actual=0x%0h expected=0x%0h base=0x%0h",
                                             tile_queue_rd_ptr,
                                             tile_fmt_queue[tile_queue_rd_ptr],
                                             tile_x_queue[tile_queue_rd_ptr],
                                             tile_y_queue[tile_queue_rd_ptr],
                                             tile_alen_queue[tile_queue_rd_ptr],
                                             exp_spread,
                                             o_m_axi_araddr,
                                             exp_addr_final,
                                             exp_addr_base);
                                end
                                ar_addr_mismatch_cnt <= ar_addr_mismatch_cnt + 1;
                            end
                            if (o_m_axi_arlen !== (((tile_alen_queue[tile_queue_rd_ptr] + 1) * (256 / AXI_DW)) - 1)) begin
                                ar_len_mismatch_cnt <= ar_len_mismatch_cnt + 1;
                            end
                            tile_queue_rd_ptr   <= tile_queue_rd_ptr + 1;
                            tile_ar_cnt         <= tile_ar_cnt + 1;
                            last_progress_cycle <= cycle_cnt;
                        end
                    end
                end
            end else begin
                i_m_axi_arready <= 1'b0;
                if (i_m_axi_rvalid && o_m_axi_rready) begin
                    axi_rbeat_cnt       <= axi_rbeat_cnt + 1;
                    last_progress_cycle <= cycle_cnt;
                    if (axi_rsp_beats_left == 8'd1) begin
                        axi_rsp_active     <= 1'b0;
                        axi_rsp_beats_left <= 8'd0;
                        axi_rsp_beat_idx   <= 8'd0;
                    end else begin
                        axi_rsp_beats_left <= axi_rsp_beats_left - 1'b1;
                        axi_rsp_beat_idx   <= axi_rsp_beat_idx + 1'b1;
                    end
                end
            end
        end
    end

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        reg [127:0] exp_word;
        if (!i_otf_rstn) begin
            otf_beat_cnt       <= 0;
            otf_mismatch_cnt   <= 0;
            first_mismatch_x   <= -1;
            first_mismatch_y   <= -1;
            active_x           <= 0;
            active_y           <= 0;
            frame_done         <= 1'b0;
            last_otf_progress_cycle <= 0;
        end else if (i_otf_ready && o_otf_de && !frame_done) begin
            exp_word = expected_otf_word(active_x, active_y);
            if (o_otf_data !== exp_word) begin
                otf_mismatch_cnt <= otf_mismatch_cnt + 1;
                if (first_mismatch_x < 0) begin
                    first_mismatch_x <= active_x;
                    first_mismatch_y <= active_y;
                end
            end
            if (otf_fd != 0) begin
                $fwrite(otf_fd, "%032h\n", o_otf_data);
            end
            otf_beat_cnt <= otf_beat_cnt + 1;
            last_progress_cycle <= cycle_cnt;
            last_otf_progress_cycle <= cycle_cnt;

            if (active_x == (IMG_W - 4)) begin
                active_x <= 0;
                if (active_y == (Y_H_STORED - 1)) begin
                    active_y         <= 0;
                    frames_completed <= frames_completed + 1;
                    if ((frames_completed + 1) >= tb_frame_repeat) begin
                        frame_done <= 1'b1;
                    end
                    -> frame_complete_ev;
                end else begin
                    active_y <= active_y + 1;
                end
            end else begin
                active_x <= active_x + 4;
            end

            if ((active_y[5:0] == 6'd0) && (active_x == 0)) begin
                $display("Wrapper OTF progress: line %0d / %0d", active_y, Y_H_STORED);
            end
        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
        end else if ((frames_started > frames_completed) &&
                     (frames_completed > 0) &&
                     ((cycle_cnt - last_otf_progress_cycle) > 400000)) begin
            $display("TB: multiframe OTF restart timeout at cycle=%0d", cycle_cnt);
            $display("  frames started     : %0d", frames_started);
            $display("  frames completed   : %0d", frames_completed);
            $display("  dbg frame_start_cnt: %0d", dbg_frame_start_cnt);
            $display("  dbg wrapper ready  : ci_ready=%0b tile_ready=%0b tready=%0b",
                     dut.tile_ci_ready_int, dut.otf_axis_tile_ready_int, dut.otf_axis_tready_int);
            $display("  dbg wrapper valid  : ci_valid=%0b tile_valid=%0b tvalid=%0b rvo_valid=%0b",
                     dut.tile_ci_valid_int, dut.otf_axis_tile_valid, dut.otf_axis_tvalid, dut.vivo_rvo_valid);
            $display("  dbg vivo state     : tile_active=%0b out_left=%0d in_left=%0d ci_ready_raw=%0b cvi_ready=%0b",
                     dut.u_dec_vivo_top.r_tile_active, dut.u_dec_vivo_top.r_out_beats_left, dut.u_dec_vivo_top.r_in_beats_left,
                     dut.vivo_ci_ready_raw, dut.tile_cvi_ready_int);
            $display("  dbg otf core       : writer_vld=%0b fetcher_req=%0b fetcher_done=%0b fifo_empty=%0b stream_started=%0b phase=%0d",
                     dut.u_tile_to_otf.writer_vld, dut.u_tile_to_otf.fetcher_req, dut.u_tile_to_otf.fetcher_done,
                     dut.u_tile_to_otf.fifo_empty, dut.u_tile_to_otf.u_otf_driver.stream_started,
                     dut.u_tile_to_otf.u_otf_driver.phase);
            $display("  dbg otf hv         : h_cnt=%0d v_cnt=%0d",
                     dut.u_tile_to_otf.u_otf_driver.h_cnt,
                     dut.u_tile_to_otf.u_otf_driver.v_cnt);
            $display("  dbg tile axi       : arvalid=%0b arready=%0b rvalid=%0b rready=%0b rlast=%0b",
                     dut.tile_m_axi_arvalid, dut.tile_m_axi_arready, dut.tile_m_axi_rvalid,
                     dut.tile_m_axi_rready, dut.tile_m_axi_rlast);
            $display("  dbg axi ic         : inflight=%0b owner_s0=%0b rbuf_valid=%0b m_rvalid=%0b m_rready=%0b m_rlast=%0b",
                     dut.rd_interconnect_core_busy_int, (!dut.core_m_axi_rid_r[AXI_IDW]),
                     1'b0, i_m_axi_rvalid, o_m_axi_rready, i_m_axi_rlast);
            $display("  dbg tile fifo      : ci_empty=%0b ar_beats_left=%0d payload_beats_left=%0d ci_valid=%0b tile_cmd_valid=%0b tile_cmd_ready=%0b",
                     dut.u_tile_arcmd_gen.ci_fifo_empty, dut.u_tile_arcmd_gen.ar_req_beats_left_reg,
                     dut.u_tile_arcmd_gen.payload_beats_left_reg, dut.u_tile_arcmd_gen.o_ci_valid,
                     dut.u_tile_arcmd_gen.tile_cmd_valid, dut.u_tile_arcmd_gen.tile_cmd_ready);
            $fatal(1, "Multiframe OTF did not restart after the next frame start.");
        end
    end

    initial begin
        integer init_word_idx;
        for (init_word_idx = 0; init_word_idx < Y_META_WORDS64; init_word_idx = init_word_idx + 1) begin
            meta_y_words[init_word_idx] = 64'd0;
        end
        for (init_word_idx = 0; init_word_idx < UV_META_WORDS64; init_word_idx = init_word_idx + 1) begin
            meta_uv_words[init_word_idx] = 64'd0;
        end
        for (init_word_idx = 0; init_word_idx < Y_WORDS64_TOTAL; init_word_idx = init_word_idx + 1) begin
            tile_y_words[init_word_idx]   = 64'd0;
            linear_y_words[init_word_idx] = 64'd0;
        end
        for (init_word_idx = 0; init_word_idx < UV_WORDS64_TOTAL; init_word_idx = init_word_idx + 1) begin
            tile_uv_words[init_word_idx]   = 64'd0;
            linear_uv_words[init_word_idx] = 64'd0;
        end

        tb_frame_repeat = 1;
        if (!$value$plusargs("tb_frame_repeat=%d", tb_frame_repeat)) begin
            tb_frame_repeat = 1;
        end
        if (tb_frame_repeat < 1) begin
            tb_frame_repeat = 1;
        end
        if (tb_frame_repeat > MAX_FRAME_REPEAT) begin
            $fatal(1, "tb_frame_repeat=%0d exceeds MAX_FRAME_REPEAT=%0d", tb_frame_repeat, MAX_FRAME_REPEAT);
        end
        expected_otf_beats_total = EXPECTED_OTF_BEATS * tb_frame_repeat;

        $readmemh("input_meta_plane0.txt", meta_y_words);
        $readmemh("input_meta_plane1.txt", meta_uv_words);
        $readmemh("input_tile_plane0.txt", tile_y_words);
        $readmemh("input_tile_plane1.txt", tile_uv_words);
        $readmemh("golden_nv12_y_linear.memh", linear_y_words);
        $readmemh("golden_nv12_uv_linear.memh", linear_uv_words);

        if (^meta_y_words[0] === 1'bx)  $fatal(1, "Failed to load input_meta_plane0.txt");
        if (^meta_uv_words[0] === 1'bx) $fatal(1, "Failed to load input_meta_plane1.txt");
        if (^tile_y_words[0] === 1'bx)  $fatal(1, "Failed to load input_tile_plane0.txt");
        if (^tile_uv_words[0] === 1'bx) $fatal(1, "Failed to load input_tile_plane1.txt");
        if (^linear_y_words[0] === 1'bx)  $fatal(1, "Failed to load golden_nv12_y_linear.memh");
        if (^linear_uv_words[0] === 1'bx) $fatal(1, "Failed to load golden_nv12_uv_linear.memh");

        PRESETn         = 1'b0;
        i_axi_rstn      = 1'b0;
        i_otf_rstn      = 1'b0;
        PSEL            = 1'b0;
        PENABLE         = 1'b0;
        PADDR           = {APB_AW{1'b0}};
        PWRITE          = 1'b0;
        PWDATA          = {APB_DW{1'b0}};
        i_otf_ready     = 1'b1;
        i_m_axi_arready = 1'b1;
        cycle_cnt       = 0;
        dbg_trace_cycles= 0;
        otf_fd          = 0;
        frames_started  = 0;
        frames_completed= 0;

        repeat (8) @(posedge i_axi_clk);
        PRESETn    = 1'b1;
        i_axi_rstn = 1'b1;
        i_otf_rstn = 1'b1;
        repeat (8) @(posedge i_axi_clk);

        otf_fd = $fopen("actual_otf_stream.txt", "w");
        if (otf_fd == 0) begin
            $fatal(1, "Failed to open actual_otf_stream.txt");
        end

        $display("");
        $display("==============================================================");
        $display("TB: ubwc_dec_wrapper_top TajMahal NV12 OTF compare");
        $display("Vivo mode     : %s", (TB_REAL_VIVO_MODE != 0) ? "real/compressed-tile" : "fake/uncompressed-tile");
        $display("Frame repeat  : %0d", tb_frame_repeat);
        $display("Meta Y vector : input_meta_plane0.txt");
        $display("Meta UV vector: input_meta_plane1.txt");
        $display("Tile Y vector : input_tile_plane0.txt");
        $display("Tile UV vector: input_tile_plane1.txt");
        $display("Golden Y line : golden_nv12_y_linear.memh");
        $display("Golden UV line: golden_nv12_uv_linear.memh");
        $display("==============================================================");

        program_wrapper_cfg();
        trigger_meta_start();
        frames_started = 1;
    end

    initial begin : multi_frame_driver
        integer frame_idx;
        wait (PRESETn && i_axi_rstn && i_otf_rstn);
        wait (frames_started > 0);
        for (frame_idx = 1; frame_idx < tb_frame_repeat; frame_idx = frame_idx + 1) begin
            @(frame_complete_ev);
            wait_wrapper_idle();
            $display("TB: frame %0d / %0d complete, scheduling next frame.", frame_idx, tb_frame_repeat);
            trigger_meta_start();
            frames_started = frames_started + 1;
        end
    end

    initial begin : finish_block
        timeout_cycles = 0;
        wait (PRESETn && i_axi_rstn && i_otf_rstn);
        repeat (100) @(posedge i_axi_clk);
        while (!frame_done &&
               ((cycle_cnt - last_progress_cycle) <= 200000) &&
               (timeout_cycles < TIMEOUT_CYCLES)) begin
            @(posedge i_axi_clk);
            timeout_cycles = timeout_cycles + 1;
        end

        if (otf_fd != 0) begin
            $fclose(otf_fd);
        end

        $display("Wrapper NV12 summary:");
        $display("  frames started     : %0d", frames_started);
        $display("  frames completed   : %0d", frames_completed);
        $display("  meta AR count      : %0d", meta_ar_cnt);
        $display("  meta Y AR count    : %0d", meta_y_ar_cnt);
        $display("  meta UV AR count   : %0d", meta_uv_ar_cnt);
        $display("  tile AR count      : %0d", tile_ar_cnt);
        $display("  AXI R beat count   : %0d", axi_rbeat_cnt);
        $display("  meta R beat count  : %0d", meta_rbeat_cnt);
        $display("  tile R beat count  : %0d", tile_rbeat_cnt);
        $display("  OTF beat count     : %0d", otf_beat_cnt);
        $display("  OTF mismatches     : %0d", otf_mismatch_cnt);
        $display("  AR addr mismatches : %0d", ar_addr_mismatch_cnt);
        $display("  AR len mismatches  : %0d", ar_len_mismatch_cnt);
        $display("  Queue underflows   : %0d", tile_queue_underflow_cnt);
        $display("  dbg ci fires       : %0d", ci_fire_cnt);
        $display("  dbg tile hdr fires : %0d", tile_hdr_fire_cnt);
        $display("  dbg rvo fires      : %0d", rvo_fire_cnt);
        $display("  dbg tile-no-rvo    : %0d", tile_rbeat_no_rvo_cnt);
        $display("  dbg writer_vld cnt : %0d", writer_vld_cnt);
        $display("  dbg fetcher_done   : %0d", fetcher_done_cnt);
        $display("  dbg fifo_wr cnt    : %0d", fifo_wr_cnt);
        $display("  dbg fifo_rd cnt    : %0d", fifo_rd_cnt);
        $display("  dbg meta_start     : %0b", dut.meta_start_pulse_axi);
        $display("  dbg meta_arvalid   : %0b", dut.meta_m_axi_arvalid);
        $display("  dbg meta_grp_valid : %0b", dut.u_meta_data_gen.meta_grp_valid);
        $display("  dbg meta_grp_ready : %0b", dut.u_meta_data_gen.meta_grp_ready);
        $display("  dbg meta_state     : %0d", dut.u_meta_data_gen.u_meta_get_cmd_gen.frame_done);
        $display("  dbg meta_base_fmt  : 0x%0h", dut.r_meta_base_format);
        $display("  dbg meta_base_y    : 0x%0h", dut.r_meta_base_addr_rgba_y);
        $display("  dbg meta_base_uv   : 0x%0h", dut.r_meta_base_addr_uv);
        $display("  dbg meta_tile_xy   : x=%0d y=%0d", dut.r_meta_tile_x_numbers, dut.r_meta_tile_y_numbers);
        $display("  dbg meta counters  : x=%0d y=%0d uv_y=%0d is_uv=%0b",
                 dut.u_meta_data_gen.u_meta_get_cmd_gen.xcoord_cnt,
                 dut.u_meta_data_gen.u_meta_get_cmd_gen.y_row_cnt,
                 dut.u_meta_data_gen.u_meta_get_cmd_gen.uv_row_cnt,
                 dut.u_meta_data_gen.u_meta_get_cmd_gen.scan_is_uv_plane);
        $display("  dbg grp addr/meta  : addr=0x%0h meta_x=%0d meta_y=%0d",
                 dut.u_meta_data_gen.meta_grp_addr,
                 dut.u_meta_data_gen.meta_xcoord,
                 dut.u_meta_data_gen.meta_ycoord);
        $display("  dbg wrapper ready  : ci_ready=%0b tile_ready=%0b tready=%0b",
                 dut.tile_ci_ready_int,
                 dut.otf_axis_tile_ready_int,
                 dut.otf_axis_tready_int);
        $display("  dbg wrapper valid  : ci_valid=%0b tile_valid=%0b tvalid=%0b rvo_valid=%0b",
                 dut.tile_ci_valid_int,
                 dut.otf_axis_tile_valid,
                 dut.otf_axis_tvalid,
                 dut.vivo_rvo_valid);
        $display("  dbg vivo state     : tile_active=%0b out_left=%0d in_left=%0d ci_ready_raw=%0b cvi_ready=%0b",
                 dut.u_dec_vivo_top.r_tile_active,
                 dut.u_dec_vivo_top.r_out_beats_left,
                 dut.u_dec_vivo_top.r_in_beats_left,
                 dut.vivo_ci_ready_raw,
                 dut.tile_cvi_ready_int);
        $display("  dbg otf core       : writer_vld=%0b fetcher_req=%0b fetcher_done=%0b fifo_empty=%0b stream_started=%0b phase=%0d",
                 dut.u_tile_to_otf.writer_vld,
                 dut.u_tile_to_otf.fetcher_req,
                 dut.u_tile_to_otf.fetcher_done,
                 dut.u_tile_to_otf.fifo_empty,
                 dut.u_tile_to_otf.u_otf_driver.stream_started,
                 dut.u_tile_to_otf.u_otf_driver.phase);
        $display("  dbg otf hv         : h_cnt=%0d v_cnt=%0d",
                 dut.u_tile_to_otf.u_otf_driver.h_cnt,
                 dut.u_tile_to_otf.u_otf_driver.v_cnt);
        $display("  dbg tile axi       : arvalid=%0b arready=%0b rvalid=%0b rready=%0b rlast=%0b",
                 dut.tile_m_axi_arvalid,
                 dut.tile_m_axi_arready,
                 dut.tile_m_axi_rvalid,
                 dut.tile_m_axi_rready,
                 dut.tile_m_axi_rlast);
        $display("  dbg axi ic         : inflight=%0b owner_s0=%0b rbuf_valid=%0b m_rvalid=%0b m_rready=%0b m_rlast=%0b",
                 dut.rd_interconnect_core_busy_int,
                 (!dut.core_m_axi_rid_r[AXI_IDW]),
                 1'b0,
                 dut.i_m_axi_rvalid,
                 dut.o_m_axi_rready,
                 dut.i_m_axi_rlast);
        $display("  dbg tile fifo      : ci_empty=%0b ar_beats_left=%0d payload_beats_left=%0d ci_valid=%0b tile_cmd_valid=%0b tile_cmd_ready=%0b",
                 dut.u_tile_arcmd_gen.ci_fifo_empty,
                 dut.u_tile_arcmd_gen.ar_req_beats_left_reg,
                 dut.u_tile_arcmd_gen.payload_beats_left_reg,
                 dut.u_tile_arcmd_gen.o_ci_valid,
                 dut.u_tile_arcmd_gen.tile_cmd_valid,
                 dut.u_tile_arcmd_gen.tile_cmd_ready);
        $display("  dbg stuck tile     : idx=%0d fmt=0x%0h x=%0d y=%0d beats_seen=%0d",
                 dbg_tile_idx_started,
                 dbg_stuck_tile_fmt,
                 dbg_stuck_tile_x,
                 dbg_stuck_tile_y,
                 dbg_tile_beats_seen);

        if (meta_ar_cnt == 0) begin
            $fatal(1, "No metadata AXI reads were observed.");
        end
        if (tile_ar_cnt == 0) begin
            $fatal(1, "No tile AXI reads were observed.");
        end
        if (!frame_done) begin
            $fatal(1, "Wrapper OTF frame did not finish before timeout.");
        end
        if (frames_completed != tb_frame_repeat) begin
            $fatal(1, "Unexpected completed frame count. got=%0d exp=%0d", frames_completed, tb_frame_repeat);
        end
        if (otf_beat_cnt != expected_otf_beats_total) begin
            $fatal(1, "Unexpected OTF beat count. got=%0d exp=%0d", otf_beat_cnt, expected_otf_beats_total);
        end
        if (otf_mismatch_cnt != 0) begin
            $fatal(1, "OTF compare mismatches found. first mismatch at x=%0d y=%0d",
                   first_mismatch_x, first_mismatch_y);
        end
        if (ar_addr_mismatch_cnt != 0) begin
            $fatal(1, "Tile AXI address mismatches were observed.");
        end
        if (ar_len_mismatch_cnt != 0) begin
            $fatal(1, "Tile AXI length mismatches were observed.");
        end
        if (tile_queue_underflow_cnt != 0) begin
            $fatal(1, "Tile command queue underflows were observed.");
        end

        $display("PASS: wrapper_top NV12 OTF output matches linear golden data for %0d frame(s).", tb_frame_repeat);
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12);
        $fsdbDumpMDA(0, tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12);
`else
        $dumpfile("tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12.vcd");
        $dumpvars(0, tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12);
`endif
`endif
    end

    always @(posedge i_axi_clk) begin
        if (DEBUG_LOG && dut.meta_start_pulse_axi) begin
            $display("DBG: meta_start_pulse_axi asserted at cycle=%0d", cycle_cnt);
            dbg_trace_cycles <= 12;
        end
        if (DEBUG_LOG && dut.meta_m_axi_arvalid && dut.meta_m_axi_arready) begin
            $display("DBG: meta AR addr=0x%0h len=%0d cycle=%0d", dut.meta_m_axi_araddr, dut.meta_m_axi_arlen, cycle_cnt);
        end
        if (DEBUG_LOG && (dbg_trace_cycles > 0)) begin
            $display("DBG: cyc=%0d done=%0d meta_grp_ready=%0b meta_grp_valid=%0b base_fmt=0x%0h base_y=0x%0h base_uv=0x%0h x=%0d y=%0d uv_y=%0d grp_addr=0x%0h meta_x=%0d meta_y=%0d",
                     cycle_cnt,
                     dut.u_meta_data_gen.u_meta_get_cmd_gen.frame_done,
                     dut.u_meta_data_gen.meta_grp_ready,
                     dut.u_meta_data_gen.meta_grp_valid,
                     dut.r_meta_base_format,
                     dut.r_meta_base_addr_rgba_y,
                     dut.r_meta_base_addr_uv,
                     dut.u_meta_data_gen.u_meta_get_cmd_gen.xcoord_cnt,
                     dut.u_meta_data_gen.u_meta_get_cmd_gen.y_row_cnt,
                     dut.u_meta_data_gen.u_meta_get_cmd_gen.uv_row_cnt,
                     dut.u_meta_data_gen.meta_grp_addr,
                     dut.u_meta_data_gen.meta_xcoord,
                     dut.u_meta_data_gen.meta_ycoord);
            $display("DBG: geom pitch=%0d current_y=%0d current_addr=0x%0h",
                     dut.u_meta_data_gen.u_meta_get_cmd_gen.meta_pitch_bytes,
                     dut.u_meta_data_gen.u_meta_get_cmd_gen.current_ycoord,
                     dut.u_meta_data_gen.meta_grp_addr);
            dbg_trace_cycles <= dbg_trace_cycles - 1;
        end
    end

endmodule
