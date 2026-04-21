`timescale 1ns/1ps

module tb_ubwc_dec_wrapper_top_tajmahal_core #(
    parameter integer CASE_ID = 0,
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0
);

    function automatic integer ceil_div;
        input integer value;
        input integer divisor;
        begin
            if (value <= 0) begin
                ceil_div = 0;
            end else begin
                ceil_div = (value + divisor - 1) / divisor;
            end
        end
    endfunction

    localparam integer CASE_RGBA8888    = 0;
    localparam integer CASE_RGBA1010102 = 1;
    localparam integer CASE_NV12        = 2;
    localparam integer CASE_G016        = 3;

    localparam integer APB_AW   = 16;
    localparam integer APB_DW   = 32;
    localparam integer AXI_AW   = 64;
    localparam integer AXI_DW   = 256;
    localparam integer M_AXI_DW = 64;
    localparam integer AXI_IDW  = 6;
    localparam integer AXI_LENW = 8;
    localparam integer SB_WIDTH = 3;

    localparam [4:0] BASE_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] BASE_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] BASE_FMT_YUV420_8    = 5'b00010;
    localparam [4:0] BASE_FMT_YUV420_10   = 5'b00011;

    localparam [4:0] META_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] META_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] META_FMT_NV12_Y      = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV     = 5'b01001;
    localparam [4:0] META_FMT_P010_Y      = 5'b01110;
    localparam [4:0] META_FMT_P010_UV     = 5'b01111;

    localparam integer IMG_W = 4096;

    localparam integer RGBA_ACTIVE_H       = 600;
    localparam integer RGBA_STORED_H       = 608;
    localparam integer RGBA_TILE_X_COUNT   = 256;
    localparam integer RGBA_TILE_Y_COUNT   = 152;
    localparam integer RGBA_META_PITCH     = 256;
    localparam integer RGBA_META_LINES     = 160;
    localparam integer RGBA_TILE_PITCH     = 16384;
    localparam integer RGBA_HIGHEST_BANK   = 16;
    localparam integer RGBA_META_WORDS64   = (RGBA_META_PITCH * RGBA_META_LINES) / 8;
    localparam integer RGBA_TILE_WORDS64   = (RGBA_TILE_PITCH * RGBA_STORED_H) / 8;

    localparam integer NV12_ACTIVE_H       = 600;
    localparam integer NV12_Y_STORED_H     = 640;
    localparam integer NV12_UV_STORED_H    = 320;
    localparam integer NV12_TILE_X_COUNT   = 128;
    localparam integer NV12_Y_TILE_Y_COUNT = 80;
    localparam integer NV12_UV_TILE_Y_COUNT= 40;
    localparam integer NV12_META_PITCH     = 128;
    localparam integer NV12_META_Y_LINES   = 96;
    localparam integer NV12_META_UV_LINES  = 64;
    localparam integer NV12_TILE_PITCH     = 4096;
    localparam integer NV12_HIGHEST_BANK   = 16;
    localparam integer NV12_Y_META_WORDS64 = (NV12_META_PITCH * NV12_META_Y_LINES) / 8;
    localparam integer NV12_UV_META_WORDS64= (NV12_META_PITCH * NV12_META_UV_LINES) / 8;
    localparam integer NV12_Y_TILE_WORDS64 = (NV12_TILE_PITCH * NV12_Y_STORED_H) / 8;
    localparam integer NV12_UV_TILE_WORDS64= (NV12_TILE_PITCH * NV12_UV_STORED_H) / 8;

    localparam integer G016_ACTIVE_H        = 600;
    localparam integer G016_Y_STORED_H      = 608;
    localparam integer G016_UV_STORED_H     = 304;
    localparam integer G016_TILE_X_COUNT    = 128;
    localparam integer G016_Y_TILE_Y_COUNT  = 152;
    localparam integer G016_UV_TILE_Y_COUNT = 76;
    localparam integer G016_META_PITCH      = 128;
    localparam integer G016_META_Y_LINES    = 160;
    localparam integer G016_META_UV_LINES   = 96;
    localparam integer G016_TILE_PITCH      = 8192;
    localparam integer G016_HIGHEST_BANK    = 16;
    localparam integer G016_Y_META_WORDS64  = (G016_META_PITCH * G016_META_Y_LINES) / 8;
    localparam integer G016_UV_META_WORDS64 = (G016_META_PITCH * G016_META_UV_LINES) / 8;
    localparam integer G016_Y_TILE_WORDS64  = (G016_TILE_PITCH * G016_Y_STORED_H) / 8;
    localparam integer G016_UV_TILE_WORDS64 = (G016_TILE_PITCH * G016_UV_STORED_H) / 8;

    localparam integer CASE_IS_NV12         = (CASE_ID == CASE_NV12);
    localparam integer CASE_IS_G016         = (CASE_ID == CASE_G016);
    localparam integer CASE_IS_RGBA1010102  = (CASE_ID == CASE_RGBA1010102);
    localparam integer CASE_HAS_PLANE1      = CASE_IS_NV12 || CASE_IS_G016;

    localparam [4:0] CASE_BASE_FORMAT = CASE_IS_G016
                                      ? BASE_FMT_YUV420_10
                                      : (CASE_IS_NV12
                                         ? BASE_FMT_YUV420_8
                                         : (CASE_IS_RGBA1010102 ? BASE_FMT_RGBA1010102 : BASE_FMT_RGBA8888));
    localparam integer CASE_TILE_X_NUMBERS = CASE_IS_G016 ? G016_TILE_X_COUNT :
                                             (CASE_IS_NV12 ? NV12_TILE_X_COUNT : RGBA_TILE_X_COUNT);
    localparam integer CASE_TILE_Y_NUMBERS = CASE_IS_G016 ? G016_Y_TILE_Y_COUNT :
                                             (CASE_IS_NV12 ? NV12_Y_TILE_Y_COUNT : RGBA_TILE_Y_COUNT);
    localparam integer CASE_EXPECTED_CI_CMDS = CASE_IS_G016
                                             ? (G016_TILE_X_COUNT * (G016_Y_TILE_Y_COUNT + G016_UV_TILE_Y_COUNT))
                                             : (CASE_IS_NV12
                                                ? (NV12_TILE_X_COUNT * (NV12_Y_TILE_Y_COUNT + NV12_UV_TILE_Y_COUNT))
                                                : (RGBA_TILE_X_COUNT * RGBA_TILE_Y_COUNT));
    localparam integer CASE_FULL_TILE_BEATS   = 8;
    localparam integer CASE_TILE_PITCH_BYTES = CASE_IS_G016 ? G016_TILE_PITCH :
                                               (CASE_IS_NV12 ? NV12_TILE_PITCH : RGBA_TILE_PITCH);
    localparam integer CASE_TILE_PITCH_UNITS = CASE_TILE_PITCH_BYTES / 16;
    localparam integer CASE_OTF_V_ACT        = CASE_IS_G016 ? G016_Y_STORED_H :
                                               (CASE_IS_NV12 ? NV12_Y_STORED_H : RGBA_STORED_H);
    localparam integer CASE_OTF_V_TOTAL      = CASE_IS_G016 ? 650 :
                                               (CASE_IS_NV12 ? 682 : 650);
    localparam integer CASE_EXPECTED_OTF_BEATS= (IMG_W / 4) * CASE_OTF_V_ACT;
    localparam integer CASE_TIMEOUT_CYCLES   = CASE_HAS_PLANE1 ? 12000000 : 16000000;
    // With OTF at 100MHz and full porch timing, active pixels can start
    // hundreds of microseconds after frame start, so the AXI-side watchdog
    // must allow a much longer no-progress window than the legacy single-clock TB.
    localparam integer CASE_IDLE_GAP_CYCLES  = 4000000;
    localparam integer CASE_META0_WORDS64    = CASE_IS_G016 ? G016_Y_META_WORDS64 :
                                               (CASE_IS_NV12 ? NV12_Y_META_WORDS64 : RGBA_META_WORDS64);
    localparam integer CASE_META1_WORDS64    = CASE_IS_G016 ? G016_UV_META_WORDS64 :
                                               (CASE_IS_NV12 ? NV12_UV_META_WORDS64 : 1);
    localparam integer CASE_TILE0_WORDS64    = CASE_IS_G016 ? G016_Y_TILE_WORDS64 :
                                               (CASE_IS_NV12 ? NV12_Y_TILE_WORDS64 : RGBA_TILE_WORDS64);
    localparam integer CASE_TILE1_WORDS64    = CASE_IS_G016 ? G016_UV_TILE_WORDS64 :
                                               (CASE_IS_NV12 ? NV12_UV_TILE_WORDS64 : 1);
    localparam [SB_WIDTH-1:0] CASE_CI_SB     = {SB_WIDTH{1'b1}};

    localparam [AXI_AW-1:0] CASE_TILE_BASE_ADDR_Y = CASE_IS_G016 ? 64'h0000_0000_8000_5000 :
                                                     (CASE_IS_NV12 ? 64'h0000_0000_0000_3000 : 64'h0000_0000_0028_5000);
    localparam [AXI_AW-1:0] CASE_TILE_BASE_ADDR_UV = CASE_IS_G016 ? 64'h0000_0000_804c_8000 :
                                                      64'h0000_0000_0028_5000;
    localparam [AXI_AW-1:0] CASE_DUMP_TILE_BASE_ADDR_Y = CASE_IS_G016 ? 64'h0000_0000_8000_5000 :
                                                          (CASE_IS_NV12 ? 64'h0000_0000_8000_3000 : CASE_TILE_BASE_ADDR_Y);
    localparam [AXI_AW-1:0] CASE_DUMP_TILE_BASE_ADDR_UV = CASE_IS_G016 ? 64'h0000_0000_804c_8000 :
                                                           64'h0000_0000_8028_5000;
    localparam [AXI_AW-1:0] CASE_META_BASE_ADDR_Y = 64'h0000_0000_8000_0000;
    localparam [AXI_AW-1:0] CASE_META_BASE_ADDR_UV = CASE_IS_G016 ? 64'h0000_0000_804c_5000 :
                                                      64'h0000_0000_8028_3000;
    localparam integer CASE_HIGHEST_BANK = CASE_IS_G016 ? G016_HIGHEST_BANK :
                                           (CASE_IS_NV12 ? NV12_HIGHEST_BANK : RGBA_HIGHEST_BANK);

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
    wire                      tb_otf_vsync;
    wire                      tb_otf_hsync;
    wire                      tb_otf_de;
    wire [127:0]              tb_otf_data;
    wire [3:0]                tb_otf_fcnt;
    wire [11:0]               tb_otf_lcnt;
    reg                       i_otf_ready;
    reg  [1:0]                otf_ready_div;

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

    wire                      fake_otf_sram_a_wen;
    wire [12:0]               fake_otf_sram_a_waddr;
    wire [127:0]              fake_otf_sram_a_wdata;
    wire                      fake_otf_sram_a_ren;
    wire [12:0]               fake_otf_sram_a_raddr;
    wire [127:0]              fake_otf_sram_a_rdata;
    wire                      fake_otf_sram_b_wen;
    wire [12:0]               fake_otf_sram_b_waddr;
    wire [127:0]              fake_otf_sram_b_wdata;
    wire                      fake_otf_sram_b_ren;
    wire [12:0]               fake_otf_sram_b_raddr;
    wire [127:0]              fake_otf_sram_b_rdata;
    wire                      fake_o_otf_vsync;
    wire                      fake_o_otf_hsync;
    wire                      fake_o_otf_de;
    wire [127:0]              fake_o_otf_data;
    wire [3:0]                fake_o_otf_fcnt;
    wire [11:0]               fake_o_otf_lcnt;
    wire                      inject_axis_tile_ready;
    wire                      inject_axis_tready;

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
    reg  [M_AXI_DW-1:0]       i_m_axi_rdata;
    reg                       i_m_axi_rvalid;
    reg  [1:0]                i_m_axi_rresp;
    reg                       i_m_axi_rlast;
    wire                      o_m_axi_rready;

    reg  [63:0]               meta_plane0_words [0:CASE_META0_WORDS64-1];
    reg  [63:0]               meta_plane1_words [0:CASE_META1_WORDS64-1];
    reg  [63:0]               tile_plane0_words [0:CASE_TILE0_WORDS64-1];
    reg  [63:0]               tile_plane1_words [0:CASE_TILE1_WORDS64-1];
    reg  [63:0]               ref_tile_plane0_words [0:CASE_TILE0_WORDS64-1];
    reg  [63:0]               ref_tile_plane1_words [0:CASE_TILE1_WORDS64-1];
    reg  [63:0]               actual_rvo_plane0_words [0:CASE_TILE0_WORDS64-1];
    reg  [63:0]               actual_rvo_plane1_words [0:CASE_TILE1_WORDS64-1];
    reg  [127:0]              expected_otf_beats [0:CASE_EXPECTED_OTF_BEATS-1];

    reg  [4:0]                tile_fmt_queue [0:CASE_EXPECTED_CI_CMDS-1];
    reg  [11:0]               tile_x_queue   [0:CASE_EXPECTED_CI_CMDS-1];
    reg  [9:0]                tile_y_queue   [0:CASE_EXPECTED_CI_CMDS-1];
    reg  [2:0]                tile_alen_queue[0:CASE_EXPECTED_CI_CMDS-1];
    reg  [AXI_AW-1:0]         tile_addr_queue[0:CASE_EXPECTED_CI_CMDS-1];
    reg  [4:0]                ci_fmt_queue   [0:CASE_EXPECTED_CI_CMDS-1];
    reg  [11:0]               ci_x_queue     [0:CASE_EXPECTED_CI_CMDS-1];
    reg  [9:0]                ci_y_queue     [0:CASE_EXPECTED_CI_CMDS-1];
    reg                       ci_input_type_queue [0:CASE_EXPECTED_CI_CMDS-1];
    reg  [2:0]                ci_alen_queue      [0:CASE_EXPECTED_CI_CMDS-1];
    reg  [3:0]                ci_metadata_queue  [0:CASE_EXPECTED_CI_CMDS-1];
    reg                       ci_lossy_queue     [0:CASE_EXPECTED_CI_CMDS-1];
    reg  [1:0]                ci_alpha_mode_queue[0:CASE_EXPECTED_CI_CMDS-1];
    reg  [SB_WIDTH-1:0]       ci_sb_queue        [0:CASE_EXPECTED_CI_CMDS-1];

    reg                       axi_rsp_active;
    reg                       axi_rsp_is_meta;
    reg                       axi_rsp_meta_plane1;
    reg  [AXI_AW-1:0]         axi_rsp_addr;
    reg  [7:0]                axi_rsp_beats_left;
    reg  [7:0]                axi_rsp_beat_idx;
    reg  [4:0]                axi_rsp_tile_fmt;
    reg  [11:0]               axi_rsp_tile_x;
    reg  [9:0]                axi_rsp_tile_y;
    integer                   tile_queue_wr_ptr;
    integer                   tile_queue_rd_ptr;
    integer                   ci_queue_wr_ptr;
    integer                   fake_ci_queue_rd_ptr;
    integer                   cmp_tile_rd_ptr;
    integer                   cmp_tile_beat_idx;
    integer                   meta_ar_cnt;
    integer                   meta_ar_plane0_cnt;
    integer                   meta_ar_plane1_cnt;
    integer                   tile_ar_cnt;
    integer                   axi_rbeat_cnt;
    integer                   meta_rbeat_cnt;
    integer                   tile_rbeat_cnt;
    integer                   tile_rbeat_no_rvo_cnt;
    integer                   ci_accept_cnt;
    integer                   payload_cmd_cnt;
    integer                   expected_rvo_beats_total;
    integer                   rvo_beat_cnt;
    integer                   rvo_last_cnt;
    integer                   co_active_cycle_cnt;
    integer                   ar_addr_mismatch_cnt;
    integer                   ar_len_mismatch_cnt;
    integer                   rvo_data_mismatch_cnt;
    integer                   rvo_last_mismatch_cnt;
    integer                   co_mismatch_cnt;
    integer                   tile_queue_underflow_cnt;
    integer                   writer_vld_cnt;
    integer                   fetcher_done_cnt;
    integer                   fifo_wr_cnt;
    integer                   fifo_rd_cnt;
    integer                   otf_fifo_empty_need_cnt;
    integer                   first_otf_fifo_empty_need_beat;
    integer                   fake_writer_vld_cnt;
    integer                   fake_fetcher_done_cnt;
    integer                   fake_fifo_wr_cnt;
    integer                   fake_fifo_rd_cnt;
    integer                   fake_hdr_hs_cnt;
    integer                   fake_data_hs_cnt;
    integer                   fake_sram_wen_cnt;
    integer                   fake_tile_last_write_cnt;
    integer                   fake_slice_done_cnt;
    integer                   fake_hdr_last_x_hs_cnt;
    integer                   fake_hdr_x_max_seen;
    integer                   m_rhandshake_cnt;
    integer                   m_r_nosink_cnt;
    integer                   m_r_nosink_meta_cnt;
    integer                   m_r_nosink_tile_cnt;
    integer                   rbuf_meta_drain_cnt;
    integer                   rbuf_tile_drain_cnt;
    integer                   axi_rdata_cccc_cnt;
    integer                   axi_rdata_cccc_meta_cnt;
    integer                   axi_rdata_cccc_tile_cnt;
    integer                   first_axi_rdata_cccc_cycle;
    integer                   first_axi_rdata_cccc_lane;
    integer                   stream_fd;
    integer                   expected_stream_fd;
    integer                   stream_plane0_fd;
    integer                   expected_stream_plane0_fd;
    integer                   stream_plane1_fd;
    integer                   expected_stream_plane1_fd;
    integer                   otf_fd;
    integer                   compressed_tile_in_fd;
    integer                   summary_fd;
    integer                   cycle_cnt;
    integer                   last_progress_cycle;
    integer                   last_otf_progress_cycle;
    integer                   timeout_cycles;
    integer                   tb_timeout_limit_cycles;
    integer                   tb_idle_gap_limit_cycles;
    reg [4:0]                 first_rvo_mismatch_fmt;
    reg [11:0]                first_rvo_mismatch_x;
    reg [9:0]                 first_rvo_mismatch_y;
    integer                   first_rvo_mismatch_beat;
    reg [AXI_DW-1:0]          first_rvo_expected_data;
    reg [AXI_DW-1:0]          first_rvo_actual_data;
    reg [2:0]                 first_rvo_expected_alen;
    reg                       first_rvo_actual_last;
    reg [4:0]                 first_ar_mismatch_fmt;
    reg [11:0]                first_ar_mismatch_x;
    reg [9:0]                 first_ar_mismatch_y;
    reg [AXI_AW-1:0]          first_ar_expected_addr;
    reg [AXI_AW-1:0]          first_ar_actual_addr;
    reg [AXI_AW-1:0]          first_axi_rdata_cccc_addr;
    reg                       first_axi_rdata_cccc_is_meta;
    reg [M_AXI_DW-1:0]        first_axi_rdata_cccc_data;
    integer                   first_m_r_nosink_cycle;
    reg                       first_m_r_nosink_owner_s0;
    reg                       first_m_r_nosink_rlast;
    reg                       first_m_r_nosink_rbuf_valid;
    reg [7:0]                 first_m_r_nosink_payload_left;
    reg [7:0]                 first_m_r_nosink_ar_left;
    integer                   otf_beat_cnt;
    integer                   otf_mismatch_cnt;
    integer                   first_otf_mismatch_beat;
    integer                   first_otf_mismatch_x;
    integer                   first_otf_mismatch_y;
    reg [127:0]               first_otf_expected_data;
    reg [127:0]               first_otf_actual_data;
    integer                   inject_tile_cnt;
    reg                       otf_frame_done;
    integer                   otf_active_x;
    integer                   otf_active_y;
    integer                   compressed_tile_hs_cnt;
    integer                   compressed_tile_last_cnt;
    integer                   fake_ci_fifo_wr_cnt;
    integer                   fake_ci_fifo_rd_cnt;
    reg                       fake_vivo_tile_active;
    integer                   fake_vivo_beat_idx;
    reg                       fake_vivo_rvo_valid;
    reg  [255:0]              fake_vivo_rvo_data;
    reg                       fake_vivo_rvo_last;
    reg                       axi_r_cccc_seen_curr_beat;

    reg [4:0]                 inject_axis_format;
    reg [15:0]                inject_axis_tile_x;
    reg [15:0]                inject_axis_tile_y;
    reg                       inject_axis_tile_valid;
    reg [255:0]               inject_axis_tdata;
    reg                       inject_axis_tlast;
    reg                       inject_axis_tvalid;

    reg [8*96-1:0]            case_name;
    reg [8*128-1:0]           stream_file;
    reg [8*128-1:0]           expected_stream_file;
    reg [8*128-1:0]           stream_plane0_file;
    reg [8*128-1:0]           expected_stream_plane0_file;
    reg [8*128-1:0]           stream_plane1_file;
    reg [8*128-1:0]           expected_stream_plane1_file;
    reg [8*128-1:0]           summary_file;

    assign tb_otf_vsync = o_otf_vsync;
    assign tb_otf_hsync = o_otf_hsync;
    assign tb_otf_de    = o_otf_de;
    assign tb_otf_data  = o_otf_data;
    assign tb_otf_fcnt  = o_otf_fcnt;
    assign tb_otf_lcnt  = o_otf_lcnt;
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

    function automatic has_cccc_lane;
        input [M_AXI_DW-1:0] data_word;
        integer lane_idx;
        begin
            has_cccc_lane = 1'b0;
            for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                if (data_word[lane_idx*64 +: 64] == 64'hcccccccccccccccc)
                    has_cccc_lane = 1'b1;
            end
        end
    endfunction

    function automatic integer first_cccc_lane_idx;
        input [M_AXI_DW-1:0] data_word;
        integer lane_idx;
        begin
            first_cccc_lane_idx = -1;
            for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                if ((first_cccc_lane_idx < 0) &&
                    (data_word[lane_idx*64 +: 64] == 64'hcccccccccccccccc))
                    first_cccc_lane_idx = lane_idx;
            end
        end
    endfunction

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

    function automatic is_plane1_fmt;
        input [4:0] fmt;
        begin
            is_plane1_fmt = (fmt == META_FMT_NV12_UV) ||
                            (fmt == META_FMT_P010_UV);
        end
    endfunction

    function automatic integer rvo_plane_word_base;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        begin
            if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102)) begin
                rvo_plane_word_base = rgba_tile_base_word(tile_x, tile_y);
            end else if (fmt == META_FMT_NV12_Y) begin
                rvo_plane_word_base = plane_tile_base_word(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1);
            end else if (fmt == META_FMT_P010_Y) begin
                rvo_plane_word_base = plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2);
            end else begin
                rvo_plane_word_base = CASE_IS_G016
                                    ? plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2)
                                    : plane_tile_base_word(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1);
            end
        end
    endfunction

    task automatic write_rvo_beat_words;
        input integer fd;
        input [AXI_DW-1:0] beat_data;
        begin
            if (fd != 0) begin
                $fwrite(fd, "%016h\n", beat_data[63:0]);
                $fwrite(fd, "%016h\n", beat_data[127:64]);
                $fwrite(fd, "%016h\n", beat_data[191:128]);
                $fwrite(fd, "%016h\n", beat_data[255:192]);
            end
        end
    endtask

    task automatic capture_rvo_beat_to_plane_mem;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer beat_idx;
        input [AXI_DW-1:0] beat_data;
        integer word_idx;
        begin
            word_idx = rvo_plane_word_base(fmt, tile_x, tile_y) + beat_idx * 4;
            if (is_plane1_fmt(fmt)) begin
                if (word_idx + 0 < CASE_TILE1_WORDS64) actual_rvo_plane1_words[word_idx + 0] = beat_data[63:0];
                if (word_idx + 1 < CASE_TILE1_WORDS64) actual_rvo_plane1_words[word_idx + 1] = beat_data[127:64];
                if (word_idx + 2 < CASE_TILE1_WORDS64) actual_rvo_plane1_words[word_idx + 2] = beat_data[191:128];
                if (word_idx + 3 < CASE_TILE1_WORDS64) actual_rvo_plane1_words[word_idx + 3] = beat_data[255:192];
            end else begin
                if (word_idx + 0 < CASE_TILE0_WORDS64) actual_rvo_plane0_words[word_idx + 0] = beat_data[63:0];
                if (word_idx + 1 < CASE_TILE0_WORDS64) actual_rvo_plane0_words[word_idx + 1] = beat_data[127:64];
                if (word_idx + 2 < CASE_TILE0_WORDS64) actual_rvo_plane0_words[word_idx + 2] = beat_data[191:128];
                if (word_idx + 3 < CASE_TILE0_WORDS64) actual_rvo_plane0_words[word_idx + 3] = beat_data[255:192];
            end
        end
    endtask

    function automatic integer rgba_tile_base_word;
        input integer tile_x;
        input integer tile_y;
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

            addr_bytes = (RGBA_TILE_PITCH * (macro_tile_y * 4) * 4) +
                         (macro_tile_x * 4096) +
                         (macro_tile_slot(temp_tile_x, temp_tile_y) * 256);

            if (((16 * RGBA_TILE_PITCH) % (1 << RGBA_HIGHEST_BANK)) == 0) begin
                tile_row_pixels = tile_y * 4;
                bit_val = ((addr_bytes >> (RGBA_HIGHEST_BANK - 1)) & 1) ^ ((tile_row_pixels >> 4) & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (1 << (RGBA_HIGHEST_BANK - 1));
                end else begin
                    addr_bytes = addr_bytes & ~(1 << (RGBA_HIGHEST_BANK - 1));
                end
            end

            if (((16 * RGBA_TILE_PITCH) % (1 << (RGBA_HIGHEST_BANK + 1))) == 0) begin
                tile_row_pixels = tile_y * 4;
                bit_val = ((addr_bytes >> RGBA_HIGHEST_BANK) & 1) ^ ((tile_row_pixels >> 5) & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (1 << RGBA_HIGHEST_BANK);
                end else begin
                    addr_bytes = addr_bytes & ~(1 << RGBA_HIGHEST_BANK);
                end
            end

            rgba_tile_base_word = addr_bytes >> 3;
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
                if (((bpp == 1) && (tile_width == 32) && (tile_height == 8)) ||
                    ((bpp == 2) && (tile_width == 16) && (tile_height == 8))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 4;
                end
                bit_val = ((addr_bytes >> (highest_bank_bit - 1)) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (1 << (highest_bank_bit - 1));
                end else begin
                    addr_bytes = addr_bytes & ~(1 << (highest_bank_bit - 1));
                end
            end

            if (((16 * surface_pitch_bytes) % (1 << (highest_bank_bit + 1))) == 0) begin
                if (((bpp == 1) && (tile_width == 32) && (tile_height == 8)) ||
                    ((bpp == 2) && (tile_width == 16) && (tile_height == 8))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 6;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end
                bit_val = ((addr_bytes >> highest_bank_bit) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (1 << highest_bank_bit);
                end else begin
                    addr_bytes = addr_bytes & ~(1 << highest_bank_bit);
                end
            end

            plane_tile_base_word = addr_bytes >> 3;
        end
    endfunction

    function automatic [AXI_AW-1:0] rgba_tile_addr_bytes;
        input integer tile_x;
        input integer tile_y;
        input [AXI_AW-1:0] base_addr;
        reg [AXI_AW-1:0] addr_bytes;
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

            addr_bytes = (RGBA_TILE_PITCH * (macro_tile_y * 4) * 4) +
                         (macro_tile_x * 4096) +
                         (macro_tile_slot(temp_tile_x, temp_tile_y) * 256);

            if (((16 * RGBA_TILE_PITCH) % (1 << RGBA_HIGHEST_BANK)) == 0) begin
                tile_row_pixels = tile_y * 4;
                bit_val = ((addr_bytes >> (RGBA_HIGHEST_BANK - 1)) & 1) ^ ((tile_row_pixels >> 4) & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | ({{(AXI_AW-1){1'b0}}, 1'b1} << (RGBA_HIGHEST_BANK - 1));
                end else begin
                    addr_bytes = addr_bytes & ~( {{(AXI_AW-1){1'b0}}, 1'b1} << (RGBA_HIGHEST_BANK - 1));
                end
            end

            if (((16 * RGBA_TILE_PITCH) % (1 << (RGBA_HIGHEST_BANK + 1))) == 0) begin
                tile_row_pixels = tile_y * 4;
                bit_val = ((addr_bytes >> RGBA_HIGHEST_BANK) & 1) ^ ((tile_row_pixels >> 5) & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | ({{(AXI_AW-1){1'b0}}, 1'b1} << RGBA_HIGHEST_BANK);
                end else begin
                    addr_bytes = addr_bytes & ~( {{(AXI_AW-1){1'b0}}, 1'b1} << RGBA_HIGHEST_BANK);
                end
            end

            rgba_tile_addr_bytes = addr_bytes + base_addr;
        end
    endfunction

    function automatic [AXI_AW-1:0] plane_tile_addr_bytes;
        input integer tile_x;
        input integer tile_y;
        input integer tile_width;
        input integer tile_height;
        input integer surface_pitch_bytes;
        input integer highest_bank_bit;
        input integer bpp;
        input [AXI_AW-1:0] base_addr;
        reg [AXI_AW-1:0] addr_bytes;
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
                if (((bpp == 1) && (tile_width == 32) && (tile_height == 8)) ||
                    ((bpp == 2) && (tile_width == 16) && (tile_height == 8))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 4;
                end
                bit_val = ((addr_bytes >> (highest_bank_bit - 1)) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | ({{(AXI_AW-1){1'b0}}, 1'b1} << (highest_bank_bit - 1));
                end else begin
                    addr_bytes = addr_bytes & ~( {{(AXI_AW-1){1'b0}}, 1'b1} << (highest_bank_bit - 1));
                end
            end

            if (((16 * surface_pitch_bytes) % (1 << (highest_bank_bit + 1))) == 0) begin
                if (((bpp == 1) && (tile_width == 32) && (tile_height == 8)) ||
                    ((bpp == 2) && (tile_width == 16) && (tile_height == 8))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 6;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end
                bit_val = ((addr_bytes >> highest_bank_bit) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | ({{(AXI_AW-1){1'b0}}, 1'b1} << highest_bank_bit);
                end else begin
                    addr_bytes = addr_bytes & ~( {{(AXI_AW-1){1'b0}}, 1'b1} << highest_bank_bit);
                end
            end

            plane_tile_addr_bytes = addr_bytes + base_addr;
        end
    endfunction

    function automatic [AXI_AW-1:0] expected_tile_addr;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer has_payload;
        input integer alen;
        reg [AXI_AW-1:0] addr_bytes;
        integer payload_bytes;
        begin
            if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102)) begin
                addr_bytes = rgba_tile_addr_bytes(tile_x, tile_y, CASE_TILE_BASE_ADDR_UV);
            end else if (fmt == META_FMT_NV12_Y) begin
                addr_bytes = plane_tile_addr_bytes(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1,
                                                   CASE_TILE_BASE_ADDR_Y);
            end else if (fmt == META_FMT_NV12_UV) begin
                addr_bytes = plane_tile_addr_bytes(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1,
                                                   CASE_TILE_BASE_ADDR_UV);
            end else if (fmt == META_FMT_P010_Y) begin
                addr_bytes = plane_tile_addr_bytes(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2,
                                                   CASE_TILE_BASE_ADDR_Y);
            end else begin
                addr_bytes = plane_tile_addr_bytes(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2,
                                                   CASE_TILE_BASE_ADDR_UV);
            end

            payload_bytes = (alen + 1) << 5;
            if ((has_payload != 0) && (payload_bytes <= 128) && (addr_bytes[8] ^ addr_bytes[9])) begin
                addr_bytes = addr_bytes + 128;
            end

            expected_tile_addr = addr_bytes;
        end
    endfunction

    function automatic [M_AXI_DW-1:0] pack_meta_axi_word;
        input integer is_plane1;
        input [AXI_AW-1:0] addr;
        input integer beat_idx;
        integer word64_base;
        integer lane_idx;
        begin
            pack_meta_axi_word = {M_AXI_DW{1'b0}};
            if (is_plane1 != 0) begin
                word64_base = ((addr - CASE_META_BASE_ADDR_UV) >> 3) + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word64_base + lane_idx) < CASE_META1_WORDS64)
                        pack_meta_axi_word[lane_idx*64 +: 64] = meta_plane1_words[word64_base + lane_idx];
                end
            end else begin
                word64_base = ((addr - CASE_META_BASE_ADDR_Y) >> 3) + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word64_base + lane_idx) < CASE_META0_WORDS64)
                        pack_meta_axi_word[lane_idx*64 +: 64] = meta_plane0_words[word64_base + lane_idx];
                end
            end
        end
    endfunction

    function automatic [M_AXI_DW-1:0] pack_tile_axi_word;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer beat_idx;
        integer word64_base;
        integer word_idx;
        integer lane_idx;
        begin
            pack_tile_axi_word = {M_AXI_DW{1'b0}};
            if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102)) begin
                word64_base = rgba_tile_base_word(tile_x, tile_y);
                word_idx    = word64_base + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word_idx + lane_idx) < CASE_TILE0_WORDS64)
                        pack_tile_axi_word[lane_idx*64 +: 64] = tile_plane0_words[word_idx + lane_idx];
                end
            end else if (fmt == META_FMT_NV12_Y) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1);
                word_idx    = word64_base + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word_idx + lane_idx) < CASE_TILE0_WORDS64)
                        pack_tile_axi_word[lane_idx*64 +: 64] = tile_plane0_words[word_idx + lane_idx];
                end
            end else if (fmt == META_FMT_P010_Y) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2);
                word_idx    = word64_base + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word_idx + lane_idx) < CASE_TILE0_WORDS64)
                        pack_tile_axi_word[lane_idx*64 +: 64] = tile_plane0_words[word_idx + lane_idx];
                end
            end else begin
                word64_base = CASE_IS_G016
                            ? plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2)
                            : plane_tile_base_word(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1);
                word_idx    = word64_base + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word_idx + lane_idx) < CASE_TILE1_WORDS64)
                        pack_tile_axi_word[lane_idx*64 +: 64] = tile_plane1_words[word_idx + lane_idx];
                end
            end
        end
    endfunction

    function automatic [AXI_DW-1:0] pack_ref_tile_axi_word;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer beat_idx;
        integer word64_base;
        integer word_idx;
        reg [63:0] w0;
        reg [63:0] w1;
        reg [63:0] w2;
        reg [63:0] w3;
        begin
            if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102)) begin
                word64_base = rgba_tile_base_word(tile_x, tile_y);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 3] : 64'd0;
            end else if (fmt == META_FMT_NV12_Y) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 3] : 64'd0;
            end else if (fmt == META_FMT_P010_Y) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 3] : 64'd0;
            end else begin
                word64_base = CASE_IS_G016
                            ? plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2)
                            : plane_tile_base_word(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE1_WORDS64) ? ref_tile_plane1_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE1_WORDS64) ? ref_tile_plane1_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE1_WORDS64) ? ref_tile_plane1_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE1_WORDS64) ? ref_tile_plane1_words[word_idx + 3] : 64'd0;
            end
            pack_ref_tile_axi_word = {w3, w2, w1, w0};
        end
    endfunction

    function automatic [M_AXI_DW-1:0] pack_raw_tile_axi_word;
        input [4:0] fmt;
        input [AXI_AW-1:0] addr;
        input integer beat_idx;
        integer word64_base;
        reg [AXI_AW-1:0] tile_addr_offset;
        integer lane_idx;
        begin
            pack_raw_tile_axi_word = {M_AXI_DW{1'b0}};
            if ((fmt == META_FMT_NV12_Y) || (fmt == META_FMT_P010_Y)) begin
                tile_addr_offset = addr - CASE_TILE_BASE_ADDR_Y;
            end else begin
                tile_addr_offset = addr - CASE_TILE_BASE_ADDR_UV;
            end
            word64_base = (tile_addr_offset >> 3) + beat_idx * (M_AXI_DW / 64);
            if ((fmt == META_FMT_NV12_UV) || (fmt == META_FMT_P010_UV)) begin
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word64_base + lane_idx) < CASE_TILE1_WORDS64)
                        pack_raw_tile_axi_word[lane_idx*64 +: 64] = tile_plane1_words[word64_base + lane_idx];
                end
            end else begin
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word64_base + lane_idx) < CASE_TILE0_WORDS64)
                        pack_raw_tile_axi_word[lane_idx*64 +: 64] = tile_plane0_words[word64_base + lane_idx];
                end
            end
        end
    endfunction

    task automatic inject_axis_idle;
        begin
            @(negedge i_axi_clk);
            inject_axis_format     = 5'd0;
            inject_axis_tile_x     = 16'd0;
            inject_axis_tile_y     = 16'd0;
            inject_axis_tile_valid = 1'b0;
            inject_axis_tdata      = 256'd0;
            inject_axis_tlast      = 1'b0;
            inject_axis_tvalid     = 1'b0;
        end
    endtask

    task automatic drive_injected_header;
        input [4:0] fmt;
        input [11:0] tile_x;
        input [9:0] tile_y;
        begin
            @(negedge i_axi_clk);
            inject_axis_format     = fmt;
            inject_axis_tile_x     = {4'd0, tile_x};
            inject_axis_tile_y     = {6'd0, tile_y};
            inject_axis_tile_valid = 1'b1;
            while (inject_axis_tile_ready !== 1'b1) @(negedge i_axi_clk);
            @(negedge i_axi_clk);
            inject_axis_tile_valid = 1'b0;
        end
    endtask

    task automatic drive_injected_beat;
        input [255:0] beat_data;
        input         is_last;
        begin
            @(negedge i_axi_clk);
            inject_axis_tvalid = 1'b1;
            inject_axis_tdata  = beat_data;
            inject_axis_tlast  = is_last;
            while (inject_axis_tready !== 1'b1) @(negedge i_axi_clk);
        end
    endtask

    task automatic send_injected_tile;
        input [4:0] fmt;
        input [11:0] tile_x;
        input [9:0] tile_y;
        integer beat_idx;
        reg [255:0] beat_data;
        begin
            drive_injected_header(fmt, tile_x, tile_y);
            for (beat_idx = 0; beat_idx < CASE_FULL_TILE_BEATS; beat_idx = beat_idx + 1) begin
                beat_data = pack_ref_tile_axi_word(fmt, tile_x, tile_y, beat_idx);
                if (TB_REAL_VIVO_MODE == 0) begin
                    if (stream_fd != 0) begin
                        $fwrite(stream_fd, "%0d %0d %0d %0d %064h\n",
                                fmt, tile_x, tile_y, beat_idx, beat_data);
                    end
                    if (expected_stream_fd != 0) begin
                        $fwrite(expected_stream_fd, "%0d %0d %0d %0d %064h\n",
                                fmt, tile_x, tile_y, beat_idx, beat_data);
                    end
                end
                drive_injected_beat(beat_data, (beat_idx == (CASE_FULL_TILE_BEATS - 1)));
            end
            inject_tile_cnt = inject_tile_cnt + 1;
            inject_axis_idle();
        end
    endtask

    task automatic send_fake_otf_frame;
        integer tile_x;
        integer tile_y;
        integer slice_idx;
        integer y_upper_tile_y;
        integer y_lower_tile_y;
        integer uv_tile_y;
        reg [4:0] rgba_fmt;
        begin
            rgba_fmt = CASE_IS_RGBA1010102 ? META_FMT_RGBA1010102 : META_FMT_RGBA8888;
            if (CASE_IS_NV12) begin
                for (slice_idx = 0; slice_idx < (NV12_Y_STORED_H / 16); slice_idx = slice_idx + 1) begin
                    y_upper_tile_y = slice_idx * 2;
                    y_lower_tile_y = slice_idx * 2 + 1;
                    uv_tile_y      = slice_idx;

                    for (tile_x = 0; tile_x < NV12_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_injected_tile(META_FMT_NV12_Y, tile_x[11:0], y_upper_tile_y[9:0]);
                    end
                    for (tile_x = 0; tile_x < NV12_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_injected_tile(META_FMT_NV12_Y, tile_x[11:0], y_lower_tile_y[9:0]);
                    end
                    for (tile_x = 0; tile_x < NV12_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_injected_tile(META_FMT_NV12_UV, tile_x[11:0], uv_tile_y[9:0]);
                    end
                end
            end else if (CASE_IS_G016) begin
                for (slice_idx = 0; slice_idx < (G016_Y_STORED_H / 8); slice_idx = slice_idx + 1) begin
                    y_upper_tile_y = slice_idx * 2;
                    y_lower_tile_y = slice_idx * 2 + 1;
                    uv_tile_y      = slice_idx;

                    for (tile_x = 0; tile_x < G016_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_injected_tile(META_FMT_P010_Y, tile_x[11:0], y_upper_tile_y[9:0]);
                    end
                    for (tile_x = 0; tile_x < G016_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_injected_tile(META_FMT_P010_Y, tile_x[11:0], y_lower_tile_y[9:0]);
                    end
                    for (tile_x = 0; tile_x < G016_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_injected_tile(META_FMT_P010_UV, tile_x[11:0], uv_tile_y[9:0]);
                    end
                end
            end else begin
                for (tile_y = 0; tile_y < RGBA_TILE_Y_COUNT; tile_y = tile_y + 1) begin
                    for (tile_x = 0; tile_x < RGBA_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_injected_tile(rgba_fmt, tile_x[11:0], tile_y[9:0]);
                    end
                end
            end
        end
    endtask

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

    task automatic program_wrapper_regs;
        reg cfg_4line_format;
        reg [AXI_AW-1:0] meta_plane_rgba_uv_base;
        begin
            cfg_4line_format = CASE_IS_NV12 ? 1'b0 : 1'b1;
            meta_plane_rgba_uv_base = CASE_HAS_PLANE1 ? CASE_META_BASE_ADDR_UV : CASE_META_BASE_ADDR_Y;

            apb_write(16'h0008, {20'd0, 1'b0, cfg_4line_format, 1'b1, 5'd16, 1'b0, 1'b1, 1'b1, 1'b0});
            apb_write(16'h000c, CASE_TILE_PITCH_UNITS);
            apb_write(16'h0010, 32'h0000_000f);
            apb_write(16'h0014, 32'h0000_0001);

            apb_write(16'h001c, meta_plane_rgba_uv_base[31:0]);
            apb_write(16'h0020, meta_plane_rgba_uv_base[63:32]);
            apb_write(16'h0024, CASE_META_BASE_ADDR_Y[31:0]);
            apb_write(16'h0028, CASE_META_BASE_ADDR_Y[63:32]);
            apb_write(16'h002c, {CASE_TILE_Y_NUMBERS[15:0], CASE_TILE_X_NUMBERS[15:0]});

            apb_write(16'h0030, {11'd0, CASE_BASE_FORMAT, 16'd4096});
            apb_write(16'h0034, {16'd44, 16'd4400});
            apb_write(16'h0038, {16'd4096, 16'd148});
            apb_write(16'h003c, {16'd5, CASE_OTF_V_TOTAL[15:0]});
            apb_write(16'h0040, {CASE_OTF_V_ACT[15:0], 16'd36});
            apb_write(16'h0044, CASE_TILE_BASE_ADDR_UV[31:0]);
            apb_write(16'h0048, CASE_TILE_BASE_ADDR_UV[63:32]);
            apb_write(16'h004c, CASE_TILE_BASE_ADDR_Y[31:0]);
            apb_write(16'h0050, CASE_TILE_BASE_ADDR_Y[63:32]);

            apb_write(16'h0018, {23'd0, CASE_BASE_FORMAT, 3'd0, 1'b1});
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

    sram_pdp_8192x128 u_fake_otf_sram_bank_a (
        .clk   (i_axi_clk),
        .wen   (fake_otf_sram_a_wen),
        .waddr (fake_otf_sram_a_waddr),
        .wdata (fake_otf_sram_a_wdata),
        .ren   (fake_otf_sram_a_ren),
        .raddr (fake_otf_sram_a_raddr),
        .rdata (fake_otf_sram_a_rdata)
    );

    sram_pdp_8192x128 u_fake_otf_sram_bank_b (
        .clk   (i_axi_clk),
        .wen   (fake_otf_sram_b_wen),
        .waddr (fake_otf_sram_b_waddr),
        .wdata (fake_otf_sram_b_wdata),
        .ren   (fake_otf_sram_b_ren),
        .raddr (fake_otf_sram_b_raddr),
        .rdata (fake_otf_sram_b_rdata)
    );

    ubwc_dec_wrapper_top #(
        .APB_AW   (APB_AW),
        .APB_DW   (APB_DW),
        .AXI_AW   (AXI_AW),
        .AXI_DW   (M_AXI_DW),
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
        .i_m_axi_rdata     (i_m_axi_rdata),
        .i_m_axi_rvalid    (i_m_axi_rvalid),
        .i_m_axi_rresp     (i_m_axi_rresp),
        .i_m_axi_rlast     (i_m_axi_rlast),
        .o_m_axi_rready    (o_m_axi_rready)
    );

    ubwc_dec_tile_to_otf u_fake_tile_to_otf (
        .clk_sram         (i_axi_clk),
        .clk_otf          (i_otf_clk),
        .rst_n            (i_axi_rstn),
        .i_frame_start    (1'b0),
        .cfg_img_width    (16'd4096),
        .cfg_format       (CASE_BASE_FORMAT),
        .cfg_otf_h_total  (16'd4400),
        .cfg_otf_h_sync   (16'd44),
        .cfg_otf_h_bp     (16'd148),
        .cfg_otf_h_act    (16'd4096),
        .cfg_otf_v_total  (CASE_OTF_V_TOTAL[15:0]),
        .cfg_otf_v_sync   (16'd5),
        .cfg_otf_v_bp     (16'd36),
        .cfg_otf_v_act    (CASE_OTF_V_ACT[15:0]),
        .s_axis_format    (inject_axis_format),
        .s_axis_tile_x    (inject_axis_tile_x),
        .s_axis_tile_y    (inject_axis_tile_y),
        .s_axis_tile_valid(inject_axis_tile_valid),
        .s_axis_tile_ready(inject_axis_tile_ready),
        .s_axis_tdata     (inject_axis_tdata),
        .s_axis_tlast     (inject_axis_tlast),
        .s_axis_tvalid    (inject_axis_tvalid),
        .s_axis_tready    (inject_axis_tready),
        .sram_a_wen       (fake_otf_sram_a_wen),
        .sram_a_waddr     (fake_otf_sram_a_waddr),
        .sram_a_wdata     (fake_otf_sram_a_wdata),
        .sram_a_ren       (fake_otf_sram_a_ren),
        .sram_a_raddr     (fake_otf_sram_a_raddr),
        .sram_a_rdata     (fake_otf_sram_a_rdata),
        .sram_b_wen       (fake_otf_sram_b_wen),
        .sram_b_waddr     (fake_otf_sram_b_waddr),
        .sram_b_wdata     (fake_otf_sram_b_wdata),
        .sram_b_ren       (fake_otf_sram_b_ren),
        .sram_b_raddr     (fake_otf_sram_b_raddr),
        .sram_b_rdata     (fake_otf_sram_b_rdata),
        .o_otf_vsync      (fake_o_otf_vsync),
        .o_otf_hsync      (fake_o_otf_hsync),
        .o_otf_de         (fake_o_otf_de),
        .o_otf_data       (fake_o_otf_data),
        .o_otf_fcnt       (fake_o_otf_fcnt),
        .o_otf_lcnt       (fake_o_otf_lcnt),
        .i_otf_ready      (i_otf_ready),
        .o_busy           ()
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

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        if (!i_otf_rstn) begin
            otf_ready_div <= 2'd0;
            i_otf_ready   <= 1'b0;
        end else if (CASE_IS_G016) begin
            // G016/P010 needs light sink-side backpressure in this TB so the
            // tile-to-OTF path can drain cleanly at the current clock ratio.
            otf_ready_div <= otf_ready_div + 1'b1;
            i_otf_ready   <= (otf_ready_div != 2'd3);
        end else begin
            otf_ready_div <= 2'd0;
            i_otf_ready   <= 1'b1;
        end
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

    initial begin : fake_vivo_force_block
        fake_vivo_rvo_valid = 1'b0;
        fake_vivo_rvo_data  = 256'd0;
        fake_vivo_rvo_last  = 1'b0;
        if (TB_REAL_VIVO_MODE == 0) begin
            force dut.u_dec_vivo_top.o_rvo_valid = fake_vivo_rvo_valid;
            force dut.u_dec_vivo_top.o_rvo_data  = fake_vivo_rvo_data;
            force dut.u_dec_vivo_top.o_rvo_last  = fake_vivo_rvo_last;
        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            tile_queue_wr_ptr       <= 0;
            ci_queue_wr_ptr         <= 0;
            payload_cmd_cnt         <= 0;
            expected_rvo_beats_total<= 0;
            ci_accept_cnt           <= 0;
            tile_rbeat_no_rvo_cnt   <= 0;
            rvo_beat_cnt            <= 0;
            rvo_last_cnt            <= 0;
            co_active_cycle_cnt     <= 0;
            rvo_data_mismatch_cnt   <= 0;
            rvo_last_mismatch_cnt   <= 0;
            co_mismatch_cnt         <= 0;
            first_rvo_mismatch_fmt  <= 5'd0;
            first_rvo_mismatch_x    <= 12'd0;
            first_rvo_mismatch_y    <= 10'd0;
            first_rvo_mismatch_beat <= 0;
            first_rvo_expected_data <= {AXI_DW{1'b0}};
            first_rvo_actual_data   <= {AXI_DW{1'b0}};
            first_rvo_expected_alen <= 3'd0;
            first_rvo_actual_last   <= 1'b0;
            first_ar_mismatch_fmt   <= 5'd0;
            first_ar_mismatch_x     <= 12'd0;
            first_ar_mismatch_y     <= 10'd0;
            first_ar_expected_addr  <= {AXI_AW{1'b0}};
            first_ar_actual_addr    <= {AXI_AW{1'b0}};
            writer_vld_cnt          <= 0;
            fetcher_done_cnt        <= 0;
            fifo_wr_cnt             <= 0;
            fifo_rd_cnt             <= 0;
            otf_fifo_empty_need_cnt <= 0;
            first_otf_fifo_empty_need_beat <= -1;
            fake_writer_vld_cnt     <= 0;
            fake_fetcher_done_cnt   <= 0;
            fake_fifo_wr_cnt        <= 0;
            fake_fifo_rd_cnt        <= 0;
            fake_hdr_hs_cnt         <= 0;
            fake_data_hs_cnt        <= 0;
            fake_sram_wen_cnt       <= 0;
            fake_tile_last_write_cnt<= 0;
            fake_slice_done_cnt     <= 0;
            fake_hdr_last_x_hs_cnt  <= 0;
            fake_hdr_x_max_seen     <= 0;
            m_rhandshake_cnt        <= 0;
            m_r_nosink_cnt          <= 0;
            m_r_nosink_meta_cnt     <= 0;
            m_r_nosink_tile_cnt     <= 0;
            rbuf_meta_drain_cnt     <= 0;
            rbuf_tile_drain_cnt     <= 0;
            compressed_tile_hs_cnt  <= 0;
            compressed_tile_last_cnt<= 0;
            fake_ci_fifo_wr_cnt     <= 0;
            fake_ci_fifo_rd_cnt     <= 0;
            axi_r_cccc_seen_curr_beat <= 1'b0;
            axi_rdata_cccc_cnt      <= 0;
            axi_rdata_cccc_meta_cnt <= 0;
            axi_rdata_cccc_tile_cnt <= 0;
            first_axi_rdata_cccc_cycle <= -1;
            first_axi_rdata_cccc_lane  <= -1;
            first_axi_rdata_cccc_addr  <= {AXI_AW{1'b0}};
            first_axi_rdata_cccc_is_meta <= 1'b0;
            first_axi_rdata_cccc_data <= {M_AXI_DW{1'b0}};
            first_m_r_nosink_cycle  <= -1;
            first_m_r_nosink_owner_s0 <= 1'b0;
            first_m_r_nosink_rlast  <= 1'b0;
            first_m_r_nosink_rbuf_valid <= 1'b0;
            first_m_r_nosink_payload_left <= 8'd0;
            first_m_r_nosink_ar_left <= 8'd0;
        end else begin
            if (dut.u_tile_arcmd_gen.tile_cmd_valid &&
                dut.u_tile_arcmd_gen.tile_cmd_ready &&
                dut.u_tile_arcmd_gen.tile_cmd_has_payload) begin
                tile_fmt_queue[tile_queue_wr_ptr]  <= dut.u_tile_arcmd_gen.tile_cmd_format;
                tile_x_queue[tile_queue_wr_ptr]    <= dut.u_tile_arcmd_gen.dec_meta_x;
                tile_y_queue[tile_queue_wr_ptr]    <= dut.u_tile_arcmd_gen.dec_meta_y;
                tile_alen_queue[tile_queue_wr_ptr] <= dut.u_tile_arcmd_gen.tile_cmd_alen;
                tile_addr_queue[tile_queue_wr_ptr] <= expected_tile_addr(dut.u_tile_arcmd_gen.tile_cmd_format,
                                                                         dut.u_tile_arcmd_gen.dec_meta_x,
                                                                         dut.u_tile_arcmd_gen.dec_meta_y,
                                                                         dut.u_tile_arcmd_gen.tile_cmd_has_payload,
                                                                         dut.u_tile_arcmd_gen.tile_cmd_alen);
                tile_queue_wr_ptr        <= tile_queue_wr_ptr + 1;
                payload_cmd_cnt          <= payload_cmd_cnt + 1;
                last_progress_cycle      <= cycle_cnt;
            end

            if (dut.tile_ci_valid_int && dut.tile_ci_ready_int) begin
                ci_accept_cnt        <= ci_accept_cnt + 1;
                ci_fmt_queue[ci_queue_wr_ptr] <= dut.tile_ci_format_int;
                ci_x_queue[ci_queue_wr_ptr]   <= dut.tile_x_coord_int;
                ci_y_queue[ci_queue_wr_ptr]   <= dut.tile_y_coord_int;
                ci_input_type_queue[ci_queue_wr_ptr] <= dut.tile_ci_input_type_int;
                ci_alen_queue[ci_queue_wr_ptr]       <= dut.tile_ci_alen_int;
                ci_metadata_queue[ci_queue_wr_ptr]   <= dut.tile_ci_metadata_int;
                ci_lossy_queue[ci_queue_wr_ptr]      <= dut.tile_ci_lossy_int;
                ci_alpha_mode_queue[ci_queue_wr_ptr] <= dut.tile_ci_alpha_mode_int;
                ci_sb_queue[ci_queue_wr_ptr]         <= dut.tile_ci_sb_int;
                ci_queue_wr_ptr               <= ci_queue_wr_ptr + 1;
                expected_rvo_beats_total      <= expected_rvo_beats_total + CASE_FULL_TILE_BEATS;
                if (TB_REAL_VIVO_MODE == 0) begin
                    fake_ci_fifo_wr_cnt <= fake_ci_fifo_wr_cnt + 1;
                end
                last_progress_cycle  <= cycle_cnt;
            end

            if ((TB_REAL_VIVO_MODE == 0) &&
                dut.tile_cvi_valid_int && dut.tile_cvi_ready_int) begin
                compressed_tile_hs_cnt <= compressed_tile_hs_cnt + 1;
                if (compressed_tile_in_fd != 0) begin
                    $fwrite(compressed_tile_in_fd, "%064h\n", dut.tile_cvi_data_int);
                    if (dut.tile_cvi_last_int) begin
                        $fwrite(compressed_tile_in_fd, "\n");
                    end
                end
                if (dut.tile_cvi_last_int) begin
                    compressed_tile_last_cnt <= compressed_tile_last_cnt + 1;
                end
                last_progress_cycle <= cycle_cnt;
            end

            if (dut.vivo_co_valid_unused) begin
                co_active_cycle_cnt <= co_active_cycle_cnt + 1;
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
            if (dut.u_tile_to_otf.u_otf_driver.need_data &&
                dut.u_tile_to_otf.fifo_empty) begin
                otf_fifo_empty_need_cnt <= otf_fifo_empty_need_cnt + 1;
                if (first_otf_fifo_empty_need_beat < 0) begin
                    first_otf_fifo_empty_need_beat <= otf_beat_cnt;
                end
            end
            if (u_fake_tile_to_otf.writer_vld) begin
                fake_writer_vld_cnt <= fake_writer_vld_cnt + 1;
            end
            if (u_fake_tile_to_otf.fetcher_done) begin
                fake_fetcher_done_cnt <= fake_fetcher_done_cnt + 1;
            end
            if (u_fake_tile_to_otf.fifo_wr_en) begin
                fake_fifo_wr_cnt <= fake_fifo_wr_cnt + 1;
            end
            if (u_fake_tile_to_otf.fifo_rd_en) begin
                fake_fifo_rd_cnt <= fake_fifo_rd_cnt + 1;
            end
            if (inject_axis_tile_valid && inject_axis_tile_ready) begin
                fake_hdr_hs_cnt <= fake_hdr_hs_cnt + 1;
                if (inject_axis_tile_x == 16'd255) begin
                    fake_hdr_last_x_hs_cnt <= fake_hdr_last_x_hs_cnt + 1;
                end
                if (inject_axis_tile_x > fake_hdr_x_max_seen) begin
                    fake_hdr_x_max_seen <= inject_axis_tile_x;
                end
            end
            if (inject_axis_tvalid && inject_axis_tready) begin
                fake_data_hs_cnt <= fake_data_hs_cnt + 1;
            end
            if (u_fake_tile_to_otf.u_writer.sram_wen_internal) begin
                fake_sram_wen_cnt <= fake_sram_wen_cnt + 1;
            end
            if (u_fake_tile_to_otf.u_writer.tile_last_write) begin
                fake_tile_last_write_cnt <= fake_tile_last_write_cnt + 1;
            end
            if (u_fake_tile_to_otf.u_writer.slice_done) begin
                fake_slice_done_cnt <= fake_slice_done_cnt + 1;
            end
            if (dut.meta_m_axi_rvalid && dut.meta_m_axi_rready) begin
                meta_rbeat_cnt <= meta_rbeat_cnt + 1;
            end
            if (dut.tile_m_axi_rvalid && dut.tile_m_axi_rready) begin
                tile_rbeat_cnt <= tile_rbeat_cnt + 1;
            end
            if (!dut.i_m_axi_rvalid) begin
                axi_r_cccc_seen_curr_beat <= 1'b0;
            end else begin
                if (has_cccc_lane(dut.i_m_axi_rdata) && !axi_r_cccc_seen_curr_beat) begin
                    axi_rdata_cccc_cnt <= axi_rdata_cccc_cnt + 1;
                    if (dut.u_axi_rd_interconnect.owner_s0) begin
                        axi_rdata_cccc_meta_cnt <= axi_rdata_cccc_meta_cnt + 1;
                    end else begin
                        axi_rdata_cccc_tile_cnt <= axi_rdata_cccc_tile_cnt + 1;
                    end
                    axi_r_cccc_seen_curr_beat <= 1'b1;
                    if (first_axi_rdata_cccc_cycle < 0) begin
                        first_axi_rdata_cccc_cycle   <= cycle_cnt;
                        first_axi_rdata_cccc_lane    <= first_cccc_lane_idx(dut.i_m_axi_rdata);
                        first_axi_rdata_cccc_addr    <= axi_rsp_addr + (axi_rsp_beat_idx * (M_AXI_DW / 8));
                        first_axi_rdata_cccc_is_meta <= dut.u_axi_rd_interconnect.owner_s0;
                        first_axi_rdata_cccc_data    <= dut.i_m_axi_rdata;
                        $display("WARN: suspicious AXI RDATA contains 64'hcccccccccccccccc while axi_rvalid=1 at cycle=%0d owner=%0s addr=%016h lane=%0d data=%064h",
                                 cycle_cnt,
                                 dut.u_axi_rd_interconnect.owner_s0 ? "meta" : "tile",
                                 axi_rsp_addr + (axi_rsp_beat_idx * (M_AXI_DW / 8)),
                                 first_cccc_lane_idx(dut.i_m_axi_rdata),
                                 dut.i_m_axi_rdata);
                    end
                end
                if (dut.o_m_axi_rready) begin
                    axi_r_cccc_seen_curr_beat <= 1'b0;
                end
            end

            if (dut.i_m_axi_rvalid && dut.o_m_axi_rready) begin
                m_rhandshake_cnt <= m_rhandshake_cnt + 1;
                if (!(dut.meta_m_axi_rvalid && dut.meta_m_axi_rready) &&
                    !(dut.tile_m_axi_rvalid && dut.tile_m_axi_rready)) begin
                    m_r_nosink_cnt <= m_r_nosink_cnt + 1;
                    if (dut.u_axi_rd_interconnect.owner_s0) begin
                        m_r_nosink_meta_cnt <= m_r_nosink_meta_cnt + 1;
                    end else begin
                        m_r_nosink_tile_cnt <= m_r_nosink_tile_cnt + 1;
                    end
                    if (first_m_r_nosink_cycle < 0) begin
                        first_m_r_nosink_cycle      <= cycle_cnt;
                        first_m_r_nosink_owner_s0   <= dut.u_axi_rd_interconnect.owner_s0;
                        first_m_r_nosink_rlast      <= dut.i_m_axi_rlast;
                        first_m_r_nosink_rbuf_valid <= dut.u_axi_rd_interconnect.rbuf_valid;
                        first_m_r_nosink_payload_left <= dut.u_tile_arcmd_gen.payload_beats_left_reg;
                        first_m_r_nosink_ar_left    <= dut.u_tile_arcmd_gen.ar_req_beats_left_reg;
                    end
                end
            end
            if (dut.u_axi_rd_interconnect.rbuf_valid &&
                dut.meta_m_axi_rvalid && dut.meta_m_axi_rready) begin
                rbuf_meta_drain_cnt <= rbuf_meta_drain_cnt + 1;
            end
            if (dut.u_axi_rd_interconnect.rbuf_valid &&
                dut.tile_m_axi_rvalid && dut.tile_m_axi_rready) begin
                rbuf_tile_drain_cnt <= rbuf_tile_drain_cnt + 1;
            end

            if (dut.tile_m_axi_rvalid && dut.tile_m_axi_rready &&
                !(dut.vivo_rvo_valid && dut.vivo_rvo_ready)) begin
                tile_rbeat_no_rvo_cnt <= tile_rbeat_no_rvo_cnt + 1;
            end

            if (dut.vivo_rvo_valid && dut.vivo_rvo_ready) begin
                rvo_beat_cnt       <= rvo_beat_cnt + 1;
                last_progress_cycle<= cycle_cnt;
                if (cmp_tile_rd_ptr >= ci_queue_wr_ptr) begin
                    rvo_data_mismatch_cnt <= rvo_data_mismatch_cnt + 1;
                    if (rvo_data_mismatch_cnt == 0) begin
                        first_rvo_mismatch_fmt  <= 5'd0;
                        first_rvo_mismatch_x    <= 12'd0;
                        first_rvo_mismatch_y    <= 10'd0;
                        first_rvo_mismatch_beat <= cmp_tile_beat_idx;
                        first_rvo_expected_data <= {AXI_DW{1'b0}};
                        first_rvo_actual_data   <= dut.vivo_rvo_data;
                        first_rvo_expected_alen <= 3'd7;
                        first_rvo_actual_last   <= dut.vivo_rvo_last;
                    end
                end else begin
                    if (dut.vivo_rvo_data !== pack_ref_tile_axi_word(ci_fmt_queue[cmp_tile_rd_ptr],
                                                                     ci_x_queue[cmp_tile_rd_ptr],
                                                                     ci_y_queue[cmp_tile_rd_ptr],
                                                                     cmp_tile_beat_idx)) begin
                        rvo_data_mismatch_cnt <= rvo_data_mismatch_cnt + 1;
                        if (rvo_data_mismatch_cnt == 0) begin
                            first_rvo_mismatch_fmt  <= ci_fmt_queue[cmp_tile_rd_ptr];
                            first_rvo_mismatch_x    <= ci_x_queue[cmp_tile_rd_ptr];
                            first_rvo_mismatch_y    <= ci_y_queue[cmp_tile_rd_ptr];
                            first_rvo_mismatch_beat <= cmp_tile_beat_idx;
                            first_rvo_expected_data <= pack_ref_tile_axi_word(ci_fmt_queue[cmp_tile_rd_ptr],
                                                                               ci_x_queue[cmp_tile_rd_ptr],
                                                                               ci_y_queue[cmp_tile_rd_ptr],
                                                                               cmp_tile_beat_idx);
                            first_rvo_actual_data   <= dut.vivo_rvo_data;
                            first_rvo_expected_alen <= 3'd7;
                            first_rvo_actual_last   <= dut.vivo_rvo_last;
                        end
                    end
                    if (dut.vivo_rvo_last !== (cmp_tile_beat_idx == (CASE_FULL_TILE_BEATS - 1))) begin
                        rvo_last_mismatch_cnt <= rvo_last_mismatch_cnt + 1;
                        if ((rvo_data_mismatch_cnt == 0) && (rvo_last_mismatch_cnt == 0)) begin
                            first_rvo_mismatch_fmt  <= ci_fmt_queue[cmp_tile_rd_ptr];
                            first_rvo_mismatch_x    <= ci_x_queue[cmp_tile_rd_ptr];
                            first_rvo_mismatch_y    <= ci_y_queue[cmp_tile_rd_ptr];
                            first_rvo_mismatch_beat <= cmp_tile_beat_idx;
                            first_rvo_expected_data <= pack_ref_tile_axi_word(ci_fmt_queue[cmp_tile_rd_ptr],
                                                                               ci_x_queue[cmp_tile_rd_ptr],
                                                                               ci_y_queue[cmp_tile_rd_ptr],
                                                                               cmp_tile_beat_idx);
                            first_rvo_actual_data   <= dut.vivo_rvo_data;
                            first_rvo_expected_alen <= 3'd7;
                            first_rvo_actual_last   <= dut.vivo_rvo_last;
                        end
                    end
                    if (dut.vivo_rvo_last) begin
                        rvo_last_cnt <= rvo_last_cnt + 1;
                    end

                    if (stream_fd != 0) begin
                        $fwrite(stream_fd, "%0d %0d %0d %0d %064h\n",
                                ci_fmt_queue[cmp_tile_rd_ptr], ci_x_queue[cmp_tile_rd_ptr], ci_y_queue[cmp_tile_rd_ptr],
                                cmp_tile_beat_idx, dut.vivo_rvo_data);
                    end
                    capture_rvo_beat_to_plane_mem(ci_fmt_queue[cmp_tile_rd_ptr],
                                                  ci_x_queue[cmp_tile_rd_ptr],
                                                  ci_y_queue[cmp_tile_rd_ptr],
                                                  cmp_tile_beat_idx,
                                                  dut.vivo_rvo_data);
                    if (expected_stream_fd != 0) begin
                        $fwrite(expected_stream_fd, "%0d %0d %0d %0d %064h\n",
                                ci_fmt_queue[cmp_tile_rd_ptr], ci_x_queue[cmp_tile_rd_ptr], ci_y_queue[cmp_tile_rd_ptr],
                                cmp_tile_beat_idx,
                                pack_ref_tile_axi_word(ci_fmt_queue[cmp_tile_rd_ptr],
                                                       ci_x_queue[cmp_tile_rd_ptr],
                                                       ci_y_queue[cmp_tile_rd_ptr],
                                                       cmp_tile_beat_idx));
                    end

                    if (cmp_tile_beat_idx == (CASE_FULL_TILE_BEATS - 1)) begin
                        cmp_tile_rd_ptr   <= cmp_tile_rd_ptr + 1;
                        cmp_tile_beat_idx <= 0;
                    end else begin
                        cmp_tile_beat_idx <= cmp_tile_beat_idx + 1;
                    end
                end
            end

        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            fake_ci_queue_rd_ptr <= 0;
            fake_vivo_tile_active<= 1'b0;
            fake_vivo_beat_idx   <= 0;
            fake_vivo_rvo_valid  <= 1'b0;
            fake_vivo_rvo_data   <= 256'd0;
            fake_vivo_rvo_last   <= 1'b0;
        end else if (TB_REAL_VIVO_MODE == 0) begin
            if (!fake_vivo_tile_active) begin
                fake_vivo_rvo_valid <= 1'b0;
                fake_vivo_rvo_data  <= 256'd0;
                fake_vivo_rvo_last  <= 1'b0;
                if (fake_ci_queue_rd_ptr < ci_queue_wr_ptr) begin
                    fake_vivo_tile_active <= 1'b1;
                    fake_vivo_beat_idx    <= 0;
                    fake_vivo_rvo_valid   <= 1'b1;
                    fake_vivo_rvo_data    <= pack_ref_tile_axi_word(ci_fmt_queue[fake_ci_queue_rd_ptr],
                                                                     ci_x_queue[fake_ci_queue_rd_ptr],
                                                                     ci_y_queue[fake_ci_queue_rd_ptr],
                                                                     0);
                    fake_vivo_rvo_last    <= (CASE_FULL_TILE_BEATS == 1);
                end
            end else if (fake_vivo_rvo_valid && dut.otf_axis_tready_int) begin
                if (fake_vivo_beat_idx == (CASE_FULL_TILE_BEATS - 1)) begin
                    fake_ci_queue_rd_ptr <= fake_ci_queue_rd_ptr + 1;
                    fake_ci_fifo_rd_cnt  <= fake_ci_fifo_rd_cnt + 1;
                    fake_vivo_tile_active<= 1'b0;
                    fake_vivo_beat_idx   <= 0;
                    fake_vivo_rvo_valid  <= 1'b0;
                    fake_vivo_rvo_data   <= 256'd0;
                    fake_vivo_rvo_last   <= 1'b0;
                end else begin
                    fake_vivo_beat_idx <= fake_vivo_beat_idx + 1;
                    fake_vivo_rvo_data <= pack_ref_tile_axi_word(ci_fmt_queue[fake_ci_queue_rd_ptr],
                                                                  ci_x_queue[fake_ci_queue_rd_ptr],
                                                                  ci_y_queue[fake_ci_queue_rd_ptr],
                                                                  fake_vivo_beat_idx + 1);
                    fake_vivo_rvo_last <= ((fake_vivo_beat_idx + 1) == (CASE_FULL_TILE_BEATS - 1));
                end
            end
        end else begin
            fake_ci_queue_rd_ptr <= 0;
            fake_vivo_tile_active<= 1'b0;
            fake_vivo_beat_idx   <= 0;
            fake_vivo_rvo_valid  <= 1'b0;
            fake_vivo_rvo_data   <= 256'd0;
            fake_vivo_rvo_last   <= 1'b0;
        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            i_m_axi_arready        <= 1'b1;
            i_m_axi_rvalid         <= 1'b0;
            i_m_axi_rdata          <= {M_AXI_DW{1'b0}};
            i_m_axi_rresp          <= 2'b00;
            i_m_axi_rlast          <= 1'b0;
            axi_rsp_active         <= 1'b0;
            axi_rsp_is_meta        <= 1'b0;
            axi_rsp_meta_plane1    <= 1'b0;
            axi_rsp_addr           <= {AXI_AW{1'b0}};
            axi_rsp_beats_left     <= 8'd0;
            axi_rsp_beat_idx       <= 8'd0;
            axi_rsp_tile_fmt       <= 5'd0;
            axi_rsp_tile_x         <= 12'd0;
            axi_rsp_tile_y         <= 10'd0;
            tile_queue_rd_ptr      <= 0;
            meta_ar_cnt            <= 0;
            meta_ar_plane0_cnt     <= 0;
            meta_ar_plane1_cnt     <= 0;
            tile_ar_cnt            <= 0;
            axi_rbeat_cnt          <= 0;
            meta_rbeat_cnt         <= 0;
            tile_rbeat_cnt         <= 0;
            ar_addr_mismatch_cnt   <= 0;
            ar_len_mismatch_cnt    <= 0;
            tile_queue_underflow_cnt <= 0;
            last_progress_cycle    <= 0;
        end else begin
            if (!axi_rsp_active) begin
                i_m_axi_rvalid <= 1'b0;
                i_m_axi_rlast  <= 1'b0;
                if (o_m_axi_arvalid && i_m_axi_arready) begin
                    if (((o_m_axi_araddr >= CASE_META_BASE_ADDR_Y) &&
                         (o_m_axi_araddr < (CASE_META_BASE_ADDR_Y + (CASE_META0_WORDS64 * 8)))) ||
                        (CASE_HAS_PLANE1 &&
                         (o_m_axi_araddr >= CASE_META_BASE_ADDR_UV) &&
                         (o_m_axi_araddr < (CASE_META_BASE_ADDR_UV + (CASE_META1_WORDS64 * 8))))) begin
                        axi_rsp_active      <= 1'b1;
                        axi_rsp_is_meta     <= 1'b1;
                        axi_rsp_meta_plane1 <= CASE_HAS_PLANE1 &&
                                               (o_m_axi_araddr >= CASE_META_BASE_ADDR_UV) &&
                                               (o_m_axi_araddr < (CASE_META_BASE_ADDR_UV + (CASE_META1_WORDS64 * 8)));
                        axi_rsp_addr        <= o_m_axi_araddr;
                        axi_rsp_beats_left  <= o_m_axi_arlen + 1'b1;
                        axi_rsp_beat_idx    <= 8'd0;
                        meta_ar_cnt         <= meta_ar_cnt + 1;
                        if (CASE_HAS_PLANE1 &&
                            (o_m_axi_araddr >= CASE_META_BASE_ADDR_UV) &&
                            (o_m_axi_araddr < (CASE_META_BASE_ADDR_UV + (CASE_META1_WORDS64 * 8)))) begin
                            meta_ar_plane1_cnt <= meta_ar_plane1_cnt + 1;
                        end else begin
                            meta_ar_plane0_cnt <= meta_ar_plane0_cnt + 1;
                        end
                        last_progress_cycle <= cycle_cnt;
                    end else begin
                        if (tile_queue_rd_ptr >= tile_queue_wr_ptr) begin
                            tile_queue_underflow_cnt <= tile_queue_underflow_cnt + 1;
                        end else begin
                            axi_rsp_active     <= 1'b1;
                            axi_rsp_is_meta    <= 1'b0;
                            axi_rsp_addr       <= o_m_axi_araddr;
                            axi_rsp_beats_left <= ((tile_alen_queue[tile_queue_rd_ptr] + 1) * (AXI_DW / M_AXI_DW));
                            axi_rsp_beat_idx   <= 8'd0;
                            axi_rsp_tile_fmt   <= tile_fmt_queue[tile_queue_rd_ptr];
                            axi_rsp_tile_x     <= tile_x_queue[tile_queue_rd_ptr];
                            axi_rsp_tile_y     <= tile_y_queue[tile_queue_rd_ptr];
                            if (o_m_axi_araddr !== tile_addr_queue[tile_queue_rd_ptr]) begin
                                ar_addr_mismatch_cnt <= ar_addr_mismatch_cnt + 1;
                                if (ar_addr_mismatch_cnt == 0) begin
                                    first_ar_mismatch_fmt  <= tile_fmt_queue[tile_queue_rd_ptr];
                                    first_ar_mismatch_x    <= tile_x_queue[tile_queue_rd_ptr];
                                    first_ar_mismatch_y    <= tile_y_queue[tile_queue_rd_ptr];
                                    first_ar_expected_addr <= tile_addr_queue[tile_queue_rd_ptr];
                                    first_ar_actual_addr   <= o_m_axi_araddr;
                                end
                            end
                            if (o_m_axi_arlen !== (((tile_alen_queue[tile_queue_rd_ptr] + 1) * (AXI_DW / M_AXI_DW)) - 1)) begin
                                ar_len_mismatch_cnt <= ar_len_mismatch_cnt + 1;
                            end
                            tile_queue_rd_ptr  <= tile_queue_rd_ptr + 1;
                            tile_ar_cnt        <= tile_ar_cnt + 1;
                            last_progress_cycle<= cycle_cnt;
                        end
                    end
                end
            end else if (!i_m_axi_rvalid) begin
                i_m_axi_rvalid <= 1'b1;
                i_m_axi_rresp  <= 2'b00;
                i_m_axi_rlast  <= (axi_rsp_beats_left == 8'd1);
                if (axi_rsp_is_meta) begin
                        i_m_axi_rdata <= pack_meta_axi_word(axi_rsp_meta_plane1, axi_rsp_addr, axi_rsp_beat_idx);
                    end else begin
                        i_m_axi_rdata <= pack_raw_tile_axi_word(axi_rsp_tile_fmt, axi_rsp_addr, axi_rsp_beat_idx);
                    end
                end else if (o_m_axi_rready) begin
                axi_rbeat_cnt       <= axi_rbeat_cnt + 1;
                last_progress_cycle <= cycle_cnt;
                if (axi_rsp_beats_left == 8'd1) begin
                    i_m_axi_rvalid     <= 1'b0;
                    i_m_axi_rlast      <= 1'b0;
                    axi_rsp_active     <= 1'b0;
                    axi_rsp_beats_left <= 8'd0;
                    axi_rsp_beat_idx   <= 8'd0;
                end else begin
                    axi_rsp_beats_left <= axi_rsp_beats_left - 1'b1;
                    axi_rsp_beat_idx   <= axi_rsp_beat_idx + 1'b1;
                    i_m_axi_rvalid     <= 1'b1;
                    i_m_axi_rresp      <= 2'b00;
                    i_m_axi_rlast      <= (axi_rsp_beats_left == 8'd2);
                    if (axi_rsp_is_meta) begin
                        i_m_axi_rdata <= pack_meta_axi_word(axi_rsp_meta_plane1, axi_rsp_addr, axi_rsp_beat_idx + 1'b1);
                    end else begin
                        i_m_axi_rdata <= pack_raw_tile_axi_word(axi_rsp_tile_fmt, axi_rsp_addr, axi_rsp_beat_idx + 1'b1);
                    end
                end
            end
        end
    end

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        reg [127:0] exp_data_word;
        if (!i_otf_rstn) begin
            otf_beat_cnt            <= 0;
            otf_mismatch_cnt        <= 0;
            first_otf_mismatch_beat <= -1;
            first_otf_mismatch_x    <= -1;
            first_otf_mismatch_y    <= -1;
            first_otf_expected_data <= 128'd0;
            first_otf_actual_data   <= 128'd0;
            otf_frame_done          <= 1'b0;
            otf_active_x            <= 0;
            otf_active_y            <= 0;
            last_otf_progress_cycle <= 0;
        end else if (i_otf_ready && tb_otf_de && !otf_frame_done) begin
            if (otf_beat_cnt >= CASE_EXPECTED_OTF_BEATS) begin
                $fatal(1, "Observed extra OTF beat beyond expected stream. beat=%0d data=%032h",
                       otf_beat_cnt, tb_otf_data);
            end
            exp_data_word = expected_otf_beats[otf_beat_cnt];
            if (otf_fd != 0) begin
                $fwrite(otf_fd, "%032h\n", tb_otf_data);
            end
            if (tb_otf_data !== exp_data_word) begin
                otf_mismatch_cnt <= otf_mismatch_cnt + 1;
                if (first_otf_mismatch_beat < 0) begin
                    first_otf_mismatch_beat <= otf_beat_cnt;
                    first_otf_mismatch_x    <= otf_active_x;
                    first_otf_mismatch_y    <= otf_active_y;
                    first_otf_expected_data <= exp_data_word;
                    first_otf_actual_data   <= tb_otf_data;
                end
            end

            otf_beat_cnt            <= otf_beat_cnt + 1;
            last_progress_cycle     <= cycle_cnt;
            last_otf_progress_cycle <= cycle_cnt;

            if (otf_active_x == (IMG_W - 4)) begin
                otf_active_x <= 0;
                if (otf_active_y == (CASE_OTF_V_ACT - 1)) begin
                    otf_active_y   <= 0;
                    otf_frame_done <= 1'b1;
                end else begin
                    otf_active_y <= otf_active_y + 1;
                end
            end else begin
                otf_active_x <= otf_active_x + 4;
            end
        end
    end

    initial begin
        integer init_idx;
        case (CASE_ID)
            CASE_RGBA1010102: begin
                case_name            = "TajMahal RGBA1010102";
                stream_plane0_file   = "";
                expected_stream_plane0_file = "";
                stream_plane1_file   = "";
                expected_stream_plane1_file = "";
                if (TB_REAL_VIVO_MODE != 0) begin
                    stream_file          = "wrapper_tajmahal_vivo_rgba1010102.txt";
                    expected_stream_file = "wrapper_tajmahal_vivo_expected_rgba1010102.txt";
                end else begin
                    stream_file          = "wrapper_tajmahal_fake_vivo_rgba1010102.txt";
                    expected_stream_file = "wrapper_tajmahal_fake_vivo_expected_rgba1010102.txt";
                end
            end
            CASE_NV12: begin
                case_name            = "TajMahal NV12";
                if (TB_REAL_VIVO_MODE != 0) begin
                    stream_file          = "wrapper_tajmahal_vivo_nv12.txt";
                    expected_stream_file = "wrapper_tajmahal_vivo_expected_nv12.txt";
                    stream_plane0_file   = "wrapper_tajmahal_vivo_nv12_y.txt";
                    expected_stream_plane0_file = "wrapper_tajmahal_vivo_expected_nv12_y.txt";
                    stream_plane1_file   = "wrapper_tajmahal_vivo_nv12_uv.txt";
                    expected_stream_plane1_file = "wrapper_tajmahal_vivo_expected_nv12_uv.txt";
                end else begin
                    stream_file          = "wrapper_tajmahal_fake_vivo_nv12.txt";
                    expected_stream_file = "wrapper_tajmahal_fake_vivo_expected_nv12.txt";
                    stream_plane0_file   = "wrapper_tajmahal_fake_vivo_nv12_y.txt";
                    expected_stream_plane0_file = "wrapper_tajmahal_fake_vivo_expected_nv12_y.txt";
                    stream_plane1_file   = "wrapper_tajmahal_fake_vivo_nv12_uv.txt";
                    expected_stream_plane1_file = "wrapper_tajmahal_fake_vivo_expected_nv12_uv.txt";
                end
            end
            CASE_G016: begin
                case_name            = "K Outdoor61 G016";
                if (TB_REAL_VIVO_MODE != 0) begin
                    stream_file          = "wrapper_k_outdoor61_vivo_g016.txt";
                    expected_stream_file = "wrapper_k_outdoor61_vivo_expected_g016.txt";
                    stream_plane0_file   = "wrapper_k_outdoor61_vivo_g016_y.txt";
                    expected_stream_plane0_file = "wrapper_k_outdoor61_vivo_expected_g016_y.txt";
                    stream_plane1_file   = "wrapper_k_outdoor61_vivo_g016_uv.txt";
                    expected_stream_plane1_file = "wrapper_k_outdoor61_vivo_expected_g016_uv.txt";
                end else begin
                    stream_file          = "wrapper_k_outdoor61_fake_vivo_g016.txt";
                    expected_stream_file = "wrapper_k_outdoor61_fake_vivo_expected_g016.txt";
                    stream_plane0_file   = "wrapper_k_outdoor61_fake_vivo_g016_y.txt";
                    expected_stream_plane0_file = "wrapper_k_outdoor61_fake_vivo_expected_g016_y.txt";
                    stream_plane1_file   = "wrapper_k_outdoor61_fake_vivo_g016_uv.txt";
                    expected_stream_plane1_file = "wrapper_k_outdoor61_fake_vivo_expected_g016_uv.txt";
                end
            end
            default: begin
                case_name            = "TajMahal RGBA8888";
                stream_plane0_file   = "";
                expected_stream_plane0_file = "";
                stream_plane1_file   = "";
                expected_stream_plane1_file = "";
                if (TB_REAL_VIVO_MODE != 0) begin
                    stream_file          = "wrapper_tajmahal_vivo_rgba8888.txt";
                    expected_stream_file = "wrapper_tajmahal_vivo_expected_rgba8888.txt";
                end else begin
                    stream_file          = "wrapper_tajmahal_fake_vivo_rgba8888.txt";
                    expected_stream_file = "wrapper_tajmahal_fake_vivo_expected_rgba8888.txt";
                end
            end
        endcase
        summary_file = "wrapper_compare_summary.txt";

        $readmemh("expected_otf_stream.txt", expected_otf_beats);
        $readmemh("input_meta_plane0.txt", meta_plane0_words);
        $readmemh("input_tile_plane0.txt", tile_plane0_words);
        $readmemh("inject_tile_plane0.txt", ref_tile_plane0_words);
        if (CASE_HAS_PLANE1) begin
            $readmemh("input_meta_plane1.txt", meta_plane1_words);
            $readmemh("input_tile_plane1.txt", tile_plane1_words);
            $readmemh("inject_tile_plane1.txt", ref_tile_plane1_words);
        end

        if (^expected_otf_beats[0] === 1'bx) begin
            $fatal(1, "Failed to load expected_otf_stream.txt");
        end
        if (^meta_plane0_words[0] === 1'bx) begin
            $fatal(1, "Failed to load input_meta_plane0.txt");
        end
        if (^tile_plane0_words[0] === 1'bx) begin
            $fatal(1, "Failed to load input_tile_plane0.txt");
        end
        if (^ref_tile_plane0_words[0] === 1'bx) begin
            $fatal(1, "Failed to load inject_tile_plane0.txt");
        end
        if (CASE_HAS_PLANE1) begin
            if (^meta_plane1_words[0] === 1'bx) begin
                $fatal(1, "Failed to load input_meta_plane1.txt");
            end
            if (^tile_plane1_words[0] === 1'bx) begin
                $fatal(1, "Failed to load input_tile_plane1.txt");
            end
            if (^ref_tile_plane1_words[0] === 1'bx) begin
                $fatal(1, "Failed to load inject_tile_plane1.txt");
            end
        end

        for (init_idx = 0; init_idx < CASE_TILE0_WORDS64; init_idx = init_idx + 1) begin
            actual_rvo_plane0_words[init_idx] = 64'hcccccccccccccccc;
        end
        for (init_idx = 0; init_idx < CASE_TILE1_WORDS64; init_idx = init_idx + 1) begin
            actual_rvo_plane1_words[init_idx] = 64'hcccccccccccccccc;
        end

        PRESETn         = 1'b0;
        i_axi_rstn      = 1'b0;
        i_otf_rstn      = 1'b0;
        PSEL            = 1'b0;
        PENABLE         = 1'b0;
        PADDR           = {APB_AW{1'b0}};
        PWRITE          = 1'b0;
        PWDATA          = {APB_DW{1'b0}};
        i_otf_ready     = 1'b0;
        otf_ready_div   = 2'd0;
        i_m_axi_arready = 1'b1;
        i_m_axi_rdata   = {M_AXI_DW{1'b0}};
        i_m_axi_rvalid  = 1'b0;
        i_m_axi_rresp   = 2'b00;
        i_m_axi_rlast   = 1'b0;
        axi_rsp_active  = 1'b0;
        cycle_cnt       = 0;
        last_progress_cycle = 0;
        stream_fd       = 0;
        expected_stream_fd = 0;
        stream_plane0_fd = 0;
        expected_stream_plane0_fd = 0;
        stream_plane1_fd = 0;
        expected_stream_plane1_fd = 0;
        otf_fd          = 0;
        compressed_tile_in_fd = 0;
        summary_fd      = 0;
        tb_timeout_limit_cycles = CASE_TIMEOUT_CYCLES;
        tb_idle_gap_limit_cycles = CASE_IDLE_GAP_CYCLES;
        fake_ci_queue_rd_ptr = 0;
        cmp_tile_rd_ptr     = 0;
        cmp_tile_beat_idx   = 0;
        inject_tile_cnt     = 0;
        inject_axis_format     = 5'd0;
        inject_axis_tile_x     = 16'd0;
        inject_axis_tile_y     = 16'd0;
        inject_axis_tile_valid = 1'b0;
        inject_axis_tdata      = 256'd0;
        inject_axis_tlast      = 1'b0;
        inject_axis_tvalid     = 1'b0;
        void'($value$plusargs("tb_timeout_cycles=%d", tb_timeout_limit_cycles));
        void'($value$plusargs("tb_idle_gap_cycles=%d", tb_idle_gap_limit_cycles));

        repeat (8) @(posedge i_axi_clk);
        PRESETn    = 1'b1;
        i_axi_rstn = 1'b1;
        i_otf_rstn = 1'b1;
        repeat (4) @(posedge i_axi_clk);

        stream_fd = $fopen(stream_file, "w");
        if (stream_fd == 0) begin
            $fatal(1, "Failed to open %0s", stream_file);
        end
        expected_stream_fd = $fopen(expected_stream_file, "w");
        if (expected_stream_fd == 0) begin
            $fatal(1, "Failed to open %0s", expected_stream_file);
        end
        if (CASE_HAS_PLANE1) begin
            stream_plane0_fd = $fopen(stream_plane0_file, "w");
            if (stream_plane0_fd == 0) begin
                $fatal(1, "Failed to open %0s", stream_plane0_file);
            end
            expected_stream_plane0_fd = $fopen(expected_stream_plane0_file, "w");
            if (expected_stream_plane0_fd == 0) begin
                $fatal(1, "Failed to open %0s", expected_stream_plane0_file);
            end
            stream_plane1_fd = $fopen(stream_plane1_file, "w");
            if (stream_plane1_fd == 0) begin
                $fatal(1, "Failed to open %0s", stream_plane1_file);
            end
            expected_stream_plane1_fd = $fopen(expected_stream_plane1_file, "w");
            if (expected_stream_plane1_fd == 0) begin
                $fatal(1, "Failed to open %0s", expected_stream_plane1_file);
            end
        end
        otf_fd = $fopen("actual_otf_stream.txt", "w");
        if (otf_fd == 0) begin
            $fatal(1, "Failed to open actual_otf_stream.txt");
        end
        compressed_tile_in_fd = $fopen("compressed_tile_in.txt", "w");
        if (compressed_tile_in_fd == 0) begin
            $fatal(1, "Failed to open compressed_tile_in.txt");
        end
        summary_fd = $fopen(summary_file, "w");
        if (summary_fd == 0) begin
            $fatal(1, "Failed to open %0s", summary_file);
        end

        $display("");
        $display("==============================================================");
        $display("TB: ubwc_dec_wrapper_top unified check %0s", case_name);
        $display("Vivo mode   : %s", (TB_REAL_VIVO_MODE != 0) ? "real/rvo-compare" : "fake/ref-playback+rvo-compare");
        $display("Metadata plane0 : input_meta_plane0.txt");
        if (CASE_HAS_PLANE1) $display("Metadata plane1 : input_meta_plane1.txt");
        $display("Tile plane0 : input_tile_plane0.txt");
        if (CASE_HAS_PLANE1) $display("Tile plane1 : input_tile_plane1.txt");
        $display("Ref tile0   : inject_tile_plane0.txt");
        if (CASE_HAS_PLANE1) $display("Ref tile1   : inject_tile_plane1.txt");
        if (TB_REAL_VIVO_MODE != 0) begin
            $display("Actual RVO  : %0s", stream_file);
            $display("Expect RVO  : %0s", expected_stream_file);
        end else begin
            $display("Actual RVO  : %0s", stream_file);
            $display("Expect RVO  : %0s", expected_stream_file);
        end
        if (CASE_HAS_PLANE1) begin
            $display("Actual RVO Y: %0s", stream_plane0_file);
            $display("Expect RVO Y: %0s", expected_stream_plane0_file);
            $display("Actual RVO U: %0s", stream_plane1_file);
            $display("Expect RVO U: %0s", expected_stream_plane1_file);
        end
        $display("Comp Tile In: compressed_tile_in.txt");
        $display("Actual OTF  : actual_otf_stream.txt");
        $display("Expected OTF: expected_otf_stream.txt");
        $display("Summary     : %0s", summary_file);
        $display("Tile counts : x=%0d y=%0d", CASE_TILE_X_NUMBERS, CASE_TILE_Y_NUMBERS);
        $display("==============================================================");

        program_wrapper_regs();
    end

    initial begin : fake_otf_injector
        inject_axis_idle();
    end

    initial begin : finish_block
        integer dump_idx;
        integer fail_check_cnt;
        timeout_cycles = 0;
        fail_check_cnt = 0;
        wait (PRESETn && i_axi_rstn && i_otf_rstn);
        repeat (100) @(posedge i_axi_clk);
        while ((ci_accept_cnt < CASE_EXPECTED_CI_CMDS ||
                axi_rsp_active ||
                (tile_queue_rd_ptr < tile_queue_wr_ptr) ||
                (cmp_tile_rd_ptr < CASE_EXPECTED_CI_CMDS) ||
                ((TB_REAL_VIVO_MODE == 0) && ((fake_ci_queue_rd_ptr < ci_queue_wr_ptr) || fake_vivo_tile_active || fake_vivo_rvo_valid)) ||
                !otf_frame_done) &&
               ((cycle_cnt - last_progress_cycle) <= tb_idle_gap_limit_cycles) &&
               (timeout_cycles < tb_timeout_limit_cycles)) begin
            @(posedge i_axi_clk);
            timeout_cycles = timeout_cycles + 1;
        end

        $display("Wrapper vivo run summary:");
        $display("  meta AR count        : %0d", meta_ar_cnt);
        $display("  meta plane0 AR count : %0d", meta_ar_plane0_cnt);
        $display("  meta plane1 AR count : %0d", meta_ar_plane1_cnt);
        $display("  tile AR count        : %0d", tile_ar_cnt);
        $display("  payload tile cmds    : %0d", payload_cmd_cnt);
        $display("  CI accepted count    : %0d", ci_accept_cnt);
        $display("  AXI R beat count     : %0d", axi_rbeat_cnt);
        $display("  AXI R handshakes     : %0d", m_rhandshake_cnt);
        $display("  meta R beat count    : %0d", meta_rbeat_cnt);
        $display("  tile R beat count    : %0d", tile_rbeat_cnt);
        $display("  Tile R no-RVO beats  : %0d", tile_rbeat_no_rvo_cnt);
        $display("  R no-sink count      : %0d", m_r_nosink_cnt);
        $display("  R no-sink meta/tile  : %0d / %0d", m_r_nosink_meta_cnt, m_r_nosink_tile_cnt);
        $display("  rbuf drain meta/tile : %0d / %0d", rbuf_meta_drain_cnt, rbuf_tile_drain_cnt);
        $display("  AXI RDATA cccc hits  : %0d (meta=%0d tile=%0d)",
                 axi_rdata_cccc_cnt, axi_rdata_cccc_meta_cnt, axi_rdata_cccc_tile_cnt);
        $display("  RVO beat count       : %0d", rvo_beat_cnt);
        $display("  RVO last count       : %0d", rvo_last_cnt);
        $display("  CO active cycles     : %0d", co_active_cycle_cnt);
        $display("  writer_vld count     : %0d", writer_vld_cnt);
        $display("  fetcher_done count   : %0d", fetcher_done_cnt);
        $display("  fifo_wr count        : %0d", fifo_wr_cnt);
        $display("  fifo_rd count        : %0d", fifo_rd_cnt);
        $display("  otf need+empty cnt   : %0d first=%0d", otf_fifo_empty_need_cnt, first_otf_fifo_empty_need_beat);
        if (TB_REAL_VIVO_MODE == 0) begin
            $display("  fake CI fifo wr/rd   : %0d / %0d", fake_ci_fifo_wr_cnt, fake_ci_fifo_rd_cnt);
            $display("  fake tile state      : active=%0b beat_idx=%0d rd_ptr=%0d wr_ptr=%0d",
                     fake_vivo_tile_active, fake_vivo_beat_idx, fake_ci_queue_rd_ptr, ci_queue_wr_ptr);
            $display("  fake RVO vld/last    : %0b / %0b", fake_vivo_rvo_valid, fake_vivo_rvo_last);
            $display("  comp tile hs/last    : %0d / %0d", compressed_tile_hs_cnt, compressed_tile_last_cnt);
        end
        $display("  dbg bank state       : a_free=%0b b_free=%0b pending_a=%0b pending_b=%0b",
                 dut.u_tile_to_otf.sram_a_free, dut.u_tile_to_otf.sram_b_free,
                 dut.u_tile_to_otf.pending_a, dut.u_tile_to_otf.pending_b);
        $display("  dbg writer state     : wr_bank=%0b cnt_write=%0d gearbox_sel=%0b hdr_empty=%0b hdr_full=%0b data_empty=%0b data_full=%0b",
                 dut.u_tile_to_otf.u_writer.wr_bank, dut.u_tile_to_otf.u_writer.cnt_write,
                 dut.u_tile_to_otf.u_writer.gearbox_sel, dut.u_tile_to_otf.u_writer.hdr_fifo_empty,
                 dut.u_tile_to_otf.u_writer.hdr_fifo_full, dut.u_tile_to_otf.u_writer.data_fifo_empty,
                 dut.u_tile_to_otf.u_writer.data_fifo_full);
        $display("  dbg fetcher state    : state=%0d bank=%0b line=%0d word=%0d fifo_full=%0b",
                 dut.u_tile_to_otf.u_fetcher.state, dut.u_tile_to_otf.u_fetcher.target_bank,
                 dut.u_tile_to_otf.u_fetcher.line_idx, dut.u_tile_to_otf.u_fetcher.word_idx,
                 dut.u_tile_to_otf.u_fetcher.i_fifo_full);
        $display("  dbg vivo state       : tile_active=%0b out_left=%0d in_left=%0d ci_ready=%0b cvi_ready=%0b",
                 dut.u_dec_vivo_top.r_tile_active,
                 dut.u_dec_vivo_top.r_out_beats_left,
                 dut.u_dec_vivo_top.r_in_beats_left,
                 dut.vivo_ci_ready_raw, dut.tile_cvi_ready_int);
        $display("  OTF beat count       : %0d", otf_beat_cnt);
        $display("  OTF mismatches       : %0d", otf_mismatch_cnt);
        $display("  dbg arcmd state      : payload_left=%0d ar_left=%0d ci_fifo_empty=%0b ci_fifo_full=%0b",
                 dut.u_tile_arcmd_gen.payload_beats_left_reg,
                 dut.u_tile_arcmd_gen.ar_req_beats_left_reg,
                 dut.u_tile_arcmd_gen.ci_fifo_empty,
                 dut.u_tile_arcmd_gen.ci_fifo_full);
        $display("  dbg tile cfg         : lvl1=%0b lvl2=%0b lvl3=%0b highest=%0d spread=%0b pitch=0x%0h 4line=%0b",
                 dut.r_tile_cfg_lvl1_bank_swizzle_en,
                 dut.r_tile_cfg_lvl2_bank_swizzle_en,
                 dut.r_tile_cfg_lvl3_bank_swizzle_en,
                 dut.r_tile_cfg_highest_bank_bit,
                 dut.r_tile_cfg_bank_spread_en,
                 dut.r_tile_cfg_pitch,
                 dut.r_tile_cfg_4line_format);
        $display("  dbg tile axi state   : rvalid=%0b rready=%0b rlast=%0b",
                 dut.tile_m_axi_rvalid,
                 dut.tile_m_axi_rready,
                 dut.tile_m_axi_rlast);
        $display("  dbg axi ic state     : inflight=%0b owner_s0=%0b rbuf_valid=%0b m_rvalid=%0b m_rready=%0b m_rlast=%0b",
                 dut.u_axi_rd_interconnect.inflight,
                 dut.u_axi_rd_interconnect.owner_s0,
                 dut.u_axi_rd_interconnect.rbuf_valid,
                 dut.i_m_axi_rvalid,
                 dut.o_m_axi_rready,
                 dut.i_m_axi_rlast);
        $display("  AR addr mismatches   : %0d", ar_addr_mismatch_cnt);
        $display("  AR len mismatches    : %0d", ar_len_mismatch_cnt);
        $display("  RVO data mismatches  : %0d", rvo_data_mismatch_cnt);
        $display("  RVO last mismatches  : %0d", rvo_last_mismatch_cnt);
        $display("  CO mismatches        : %0d", co_mismatch_cnt);
        $display("  Queue underflows     : %0d", tile_queue_underflow_cnt);
        if ((rvo_data_mismatch_cnt != 0) || (rvo_last_mismatch_cnt != 0)) begin
            $display("  First RVO mismatch   : fmt=%0d x=%0d y=%0d beat=%0d alen=%0d last=%0d",
                     first_rvo_mismatch_fmt, first_rvo_mismatch_x, first_rvo_mismatch_y,
                     first_rvo_mismatch_beat, first_rvo_expected_alen, first_rvo_actual_last);
            $display("  First RVO exp data   : %064h", first_rvo_expected_data);
            $display("  First RVO act data   : %064h", first_rvo_actual_data);
        end
        if (ar_addr_mismatch_cnt != 0) begin
            $display("  First AR mismatch    : fmt=%0d x=%0d y=%0d", first_ar_mismatch_fmt,
                     first_ar_mismatch_x, first_ar_mismatch_y);
            $display("  First AR exp/act     : %016h / %016h",
                     first_ar_expected_addr, first_ar_actual_addr);
        end
        if (first_axi_rdata_cccc_cycle >= 0) begin
            $display("  First AXI cccc hit   : cycle=%0d owner=%0s addr=%016h lane=%0d",
                     first_axi_rdata_cccc_cycle,
                     first_axi_rdata_cccc_is_meta ? "meta" : "tile",
                     first_axi_rdata_cccc_addr,
                     first_axi_rdata_cccc_lane);
            $display("  First AXI cccc data  : %064h", first_axi_rdata_cccc_data);
        end
        if (first_m_r_nosink_cycle >= 0) begin
            $display("  First R no-sink cyc  : %0d owner_s0=%0b rlast=%0b rbuf_valid=%0b payload_left=%0d ar_left=%0d",
                     first_m_r_nosink_cycle, first_m_r_nosink_owner_s0,
                     first_m_r_nosink_rlast, first_m_r_nosink_rbuf_valid,
                     first_m_r_nosink_payload_left, first_m_r_nosink_ar_left);
        end

        if (meta_ar_cnt == 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: No metadata AXI reads were observed.");
        end
        if (tile_ar_cnt == 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: No tile AXI reads were observed.");
        end
        if (ci_accept_cnt != CASE_EXPECTED_CI_CMDS) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Unexpected CI count. got=%0d exp=%0d", ci_accept_cnt, CASE_EXPECTED_CI_CMDS);
        end
        if (tile_ar_cnt != payload_cmd_cnt) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Tile AR count does not match payload tile command count. ar=%0d payload=%0d",
                     tile_ar_cnt, payload_cmd_cnt);
        end
        if (tile_queue_rd_ptr != tile_queue_wr_ptr) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Tile queue not fully drained. rd=%0d wr=%0d", tile_queue_rd_ptr, tile_queue_wr_ptr);
        end
        if (ar_addr_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Tile AXI address mismatches were observed.");
        end
        if (ar_len_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Tile AXI len mismatches were observed.");
        end
        if (!otf_frame_done) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Wrapper OTF frame did not finish before timeout.");
        end
        if (otf_beat_cnt != CASE_EXPECTED_OTF_BEATS) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Unexpected OTF beat count. got=%0d exp=%0d", otf_beat_cnt, CASE_EXPECTED_OTF_BEATS);
        end
        if (otf_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Wrapper OTF mismatches were observed. first mismatch beat=%0d x=%0d y=%0d",
                     first_otf_mismatch_beat, first_otf_mismatch_x, first_otf_mismatch_y);
        end
        if (rvo_beat_cnt != expected_rvo_beats_total) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Unexpected RVO beat count. got=%0d exp=%0d", rvo_beat_cnt, expected_rvo_beats_total);
        end
        if (rvo_last_cnt != CASE_EXPECTED_CI_CMDS) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Unexpected RVO last count. got=%0d exp=%0d", rvo_last_cnt, CASE_EXPECTED_CI_CMDS);
        end
        if (rvo_data_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Vivo raw output data mismatches were observed.");
        end
        if (rvo_last_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Vivo raw output last mismatches were observed.");
        end
        if ((TB_REAL_VIVO_MODE == 0) && (fake_ci_queue_rd_ptr != ci_queue_wr_ptr)) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Fake CI FIFO not fully drained. rd=%0d wr=%0d", fake_ci_queue_rd_ptr, ci_queue_wr_ptr);
        end
        if (tile_queue_underflow_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Tile command queue underflows were observed.");
        end

        if (CASE_HAS_PLANE1) begin
            if (stream_plane0_fd != 0) begin
                $fwrite(stream_plane0_fd, "@%016h\n", CASE_DUMP_TILE_BASE_ADDR_Y);
                for (dump_idx = 0; dump_idx < CASE_TILE0_WORDS64; dump_idx = dump_idx + 1) begin
                    $fwrite(stream_plane0_fd, "%016h\n", actual_rvo_plane0_words[dump_idx]);
                end
            end
            if (expected_stream_plane0_fd != 0) begin
                $fwrite(expected_stream_plane0_fd, "@%016h\n", CASE_DUMP_TILE_BASE_ADDR_Y);
                for (dump_idx = 0; dump_idx < CASE_TILE0_WORDS64; dump_idx = dump_idx + 1) begin
                    $fwrite(expected_stream_plane0_fd, "%016h\n", ref_tile_plane0_words[dump_idx]);
                end
            end
            if (stream_plane1_fd != 0) begin
                $fwrite(stream_plane1_fd, "@%016h\n", CASE_DUMP_TILE_BASE_ADDR_UV);
                for (dump_idx = 0; dump_idx < CASE_TILE1_WORDS64; dump_idx = dump_idx + 1) begin
                    $fwrite(stream_plane1_fd, "%016h\n", actual_rvo_plane1_words[dump_idx]);
                end
            end
            if (expected_stream_plane1_fd != 0) begin
                $fwrite(expected_stream_plane1_fd, "@%016h\n", CASE_DUMP_TILE_BASE_ADDR_UV);
                for (dump_idx = 0; dump_idx < CASE_TILE1_WORDS64; dump_idx = dump_idx + 1) begin
                    $fwrite(expected_stream_plane1_fd, "%016h\n", ref_tile_plane1_words[dump_idx]);
                end
            end
        end

        if (summary_fd != 0) begin
            $fwrite(summary_fd, "case=%0s\n", case_name);
            $fwrite(summary_fd, "mode=%0s\n", (TB_REAL_VIVO_MODE != 0) ? "real" : "fake");
            $fwrite(summary_fd, "fail_check_cnt=%0d\n", fail_check_cnt);
            $fwrite(summary_fd, "result=%0s\n", (fail_check_cnt == 0) ? "PASS" : "FAIL");
            $fwrite(summary_fd, "actual_rvo=%0s\n", stream_file);
            $fwrite(summary_fd, "expected_rvo=%0s\n", expected_stream_file);
            if (CASE_HAS_PLANE1) begin
                $fwrite(summary_fd, "actual_rvo_plane0=%0s\n", stream_plane0_file);
                $fwrite(summary_fd, "expected_rvo_plane0=%0s\n", expected_stream_plane0_file);
                $fwrite(summary_fd, "actual_rvo_plane1=%0s\n", stream_plane1_file);
                $fwrite(summary_fd, "expected_rvo_plane1=%0s\n", expected_stream_plane1_file);
            end
            $fwrite(summary_fd, "compressed_tile_in=compressed_tile_in.txt\n");
            $fwrite(summary_fd, "actual_otf=actual_otf_stream.txt\n");
            $fwrite(summary_fd, "expected_otf=expected_otf_stream.txt\n");
            $fwrite(summary_fd, "meta_ar_cnt=%0d\n", meta_ar_cnt);
            $fwrite(summary_fd, "tile_ar_cnt=%0d\n", tile_ar_cnt);
            $fwrite(summary_fd, "ci_accept_cnt=%0d\n", ci_accept_cnt);
            $fwrite(summary_fd, "fake_ci_fifo_wr_cnt=%0d\n", fake_ci_fifo_wr_cnt);
            $fwrite(summary_fd, "fake_ci_fifo_rd_cnt=%0d\n", fake_ci_fifo_rd_cnt);
            $fwrite(summary_fd, "compressed_tile_hs_cnt=%0d\n", compressed_tile_hs_cnt);
            $fwrite(summary_fd, "compressed_tile_last_cnt=%0d\n", compressed_tile_last_cnt);
            $fwrite(summary_fd, "axi_rdata_cccc_cnt=%0d\n", axi_rdata_cccc_cnt);
            $fwrite(summary_fd, "axi_rdata_cccc_meta_cnt=%0d\n", axi_rdata_cccc_meta_cnt);
            $fwrite(summary_fd, "axi_rdata_cccc_tile_cnt=%0d\n", axi_rdata_cccc_tile_cnt);
            $fwrite(summary_fd, "rvo_beat_cnt=%0d\n", rvo_beat_cnt);
            $fwrite(summary_fd, "rvo_last_cnt=%0d\n", rvo_last_cnt);
            $fwrite(summary_fd, "rvo_data_mismatch_cnt=%0d\n", rvo_data_mismatch_cnt);
            $fwrite(summary_fd, "rvo_last_mismatch_cnt=%0d\n", rvo_last_mismatch_cnt);
            $fwrite(summary_fd, "otf_beat_cnt=%0d\n", otf_beat_cnt);
            $fwrite(summary_fd, "otf_mismatch_cnt=%0d\n", otf_mismatch_cnt);
            if (first_axi_rdata_cccc_cycle >= 0) begin
                $fwrite(summary_fd, "first_axi_rdata_cccc=cycle:%0d owner:%0s addr:%016h lane:%0d\n",
                        first_axi_rdata_cccc_cycle,
                        first_axi_rdata_cccc_is_meta ? "meta" : "tile",
                        first_axi_rdata_cccc_addr,
                        first_axi_rdata_cccc_lane);
                $fwrite(summary_fd, "first_axi_rdata_cccc_data=%064h\n", first_axi_rdata_cccc_data);
            end
            if ((rvo_data_mismatch_cnt != 0) || (rvo_last_mismatch_cnt != 0)) begin
                $fwrite(summary_fd, "first_rvo_mismatch=fmt:%0d x:%0d y:%0d beat:%0d alen:%0d last:%0d\n",
                        first_rvo_mismatch_fmt, first_rvo_mismatch_x, first_rvo_mismatch_y,
                        first_rvo_mismatch_beat, first_rvo_expected_alen, first_rvo_actual_last);
                $fwrite(summary_fd, "first_rvo_expected=%064h\n", first_rvo_expected_data);
                $fwrite(summary_fd, "first_rvo_actual=%064h\n", first_rvo_actual_data);
            end
            if (otf_mismatch_cnt != 0) begin
                $fwrite(summary_fd, "first_otf_mismatch=beat:%0d x:%0d y:%0d\n",
                        first_otf_mismatch_beat, first_otf_mismatch_x, first_otf_mismatch_y);
                $fwrite(summary_fd, "first_otf_expected=%032h\n", first_otf_expected_data);
                $fwrite(summary_fd, "first_otf_actual=%032h\n", first_otf_actual_data);
            end
        end

        if (stream_fd != 0) begin
            $fclose(stream_fd);
        end
        if (expected_stream_fd != 0) begin
            $fclose(expected_stream_fd);
        end
        if (stream_plane0_fd != 0) begin
            $fclose(stream_plane0_fd);
        end
        if (expected_stream_plane0_fd != 0) begin
            $fclose(expected_stream_plane0_fd);
        end
        if (stream_plane1_fd != 0) begin
            $fclose(stream_plane1_fd);
        end
        if (expected_stream_plane1_fd != 0) begin
            $fclose(expected_stream_plane1_fd);
        end
        if (otf_fd != 0) begin
            $fclose(otf_fd);
        end
        if (compressed_tile_in_fd != 0) begin
            $fclose(compressed_tile_in_fd);
        end
        if (summary_fd != 0) begin
            $fclose(summary_fd);
        end

        if (fail_check_cnt == 0) begin
            $display("PASS: wrapper_top %0s path checks passed and OTF matches linear golden.",
                     (TB_REAL_VIVO_MODE != 0) ? "real" : "fake");
        end else begin
            $display("FAIL: wrapper_top %0s completed with %0d check failures. dumps and summary were still written.",
                     (TB_REAL_VIVO_MODE != 0) ? "real" : "fake", fail_check_cnt);
        end
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        case (CASE_ID)
            CASE_RGBA1010102: $fsdbDumpfile("tb_ubwc_dec_wrapper_top_tajmahal_rgba1010102.fsdb");
            CASE_NV12:        $fsdbDumpfile("tb_ubwc_dec_wrapper_top_tajmahal_nv12.fsdb");
            CASE_G016:        $fsdbDumpfile("tb_ubwc_dec_wrapper_top_k_outdoor61_g016.fsdb");
            default:          $fsdbDumpfile("tb_ubwc_dec_wrapper_top_tajmahal_rgba8888.fsdb");
        endcase
        $fsdbDumpvars(0, tb_ubwc_dec_wrapper_top_tajmahal_core);
        $fsdbDumpMDA(0, tb_ubwc_dec_wrapper_top_tajmahal_core);
`else
        case (CASE_ID)
            CASE_RGBA1010102: $dumpfile("tb_ubwc_dec_wrapper_top_tajmahal_rgba1010102.vcd");
            CASE_NV12:        $dumpfile("tb_ubwc_dec_wrapper_top_tajmahal_nv12.vcd");
            CASE_G016:        $dumpfile("tb_ubwc_dec_wrapper_top_k_outdoor61_g016.vcd");
            default:          $dumpfile("tb_ubwc_dec_wrapper_top_tajmahal_rgba8888.vcd");
        endcase
        $dumpvars(0, tb_ubwc_dec_wrapper_top_tajmahal_core);
`endif
`endif
    end

endmodule

module tb_ubwc_dec_wrapper_top_tajmahal_cases #(
    parameter integer CASE_ID = 0,
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0
);
    tb_ubwc_dec_wrapper_top_tajmahal_core #(
        .CASE_ID (CASE_ID),
        .TB_REAL_VIVO_MODE (TB_REAL_VIVO_MODE),
        .FORCE_FULL_PAYLOAD_CASE (0)
    ) u_core ();
endmodule

module tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888 #(
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0
);
    tb_ubwc_dec_wrapper_top_tajmahal_core #(
        .CASE_ID (0),
        .TB_REAL_VIVO_MODE (TB_REAL_VIVO_MODE),
        .FORCE_FULL_PAYLOAD_CASE (0)
    ) u_core ();
endmodule

module tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102 #(
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0
);
    tb_ubwc_dec_wrapper_top_tajmahal_core #(
        .CASE_ID (1),
        .TB_REAL_VIVO_MODE (TB_REAL_VIVO_MODE),
        .FORCE_FULL_PAYLOAD_CASE (0)
    ) u_core ();
endmodule

module tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 #(
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0
);
    tb_ubwc_dec_wrapper_top_tajmahal_core #(
        .CASE_ID (2),
        .TB_REAL_VIVO_MODE (TB_REAL_VIVO_MODE),
        .FORCE_FULL_PAYLOAD_CASE (0)
    ) u_core ();
endmodule

module tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016 #(
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0
);
    tb_ubwc_dec_wrapper_top_tajmahal_core #(
        .CASE_ID (3),
        .TB_REAL_VIVO_MODE (TB_REAL_VIVO_MODE),
        .FORCE_FULL_PAYLOAD_CASE (0)
    ) u_core ();
endmodule
