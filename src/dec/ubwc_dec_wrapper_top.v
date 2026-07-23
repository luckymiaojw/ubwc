//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Module Name       : ubwc_dec_wrapper_top.v
// Description       : Integration top for the available UBWC decode blocks.
//                     Tile address configuration is stored in local APB registers.
//                     Tile CI/CVI traffic is routed into ubwc_dec_vivo_top, and
//                     the vivo raw output is routed into ubwc_dec_tile_to_otf.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_dec_wrapper_top #(
    parameter   integer                  APB_AW                      = 16    ,
    parameter   integer                  APB_DW                      = 32    ,
    parameter   integer                  AXI_AW                      = 64    ,
    parameter   integer                  AXI_DW                      = 128   ,
    parameter   integer                  AXI_IDW                     = 4     ,
    parameter   integer                  AXI_LENW                    = 5     ,
    parameter   integer                  SB_WIDTH                    = 1     ,
    parameter   integer                  COM_BUF_AW                  = 12    ,
    parameter   integer                  COM_BUF_DW                  = 128   ,
    parameter   integer                  FORCE_FULL_PAYLOAD          = 0     ,
    parameter   integer                  DEC_VIVO_FAKE_MODEL_EN      = 0     ,
    parameter   integer                  DEC_VIVO_FAKE_TILE_EXPECT_LINEAR = 0,
    parameter   integer                  DEC_VIVO_FAKE_IMG_W         = 4096  ,
    parameter   integer                  DEC_VIVO_FAKE_RGBA_ACTIVE_H = 600   ,
    parameter   integer                  DEC_VIVO_FAKE_RGBA_TILE_PITCH = 16384,
    parameter   integer                  DEC_VIVO_FAKE_RGBA_TILE_COLS = 256  ,
    parameter   integer                  DEC_VIVO_FAKE_RGBA_TILE_ROWS = 152  ,
    parameter   integer                  DEC_VIVO_FAKE_NV12_ACTIVE_H = 600   ,
    parameter   integer                  DEC_VIVO_FAKE_NV12_UV_ACTIVE_H = 300,
    parameter   integer                  DEC_VIVO_FAKE_NV12_TILE_PITCH = 4096,
    parameter   integer                  DEC_VIVO_FAKE_NV12_Y_TILE_COLS = 128,
    parameter   integer                  DEC_VIVO_FAKE_NV12_UV_TILE_COLS = 128,
    parameter   integer                  DEC_VIVO_FAKE_NV12_Y_TILE_ROWS = 80,
    parameter   integer                  DEC_VIVO_FAKE_NV12_UV_TILE_ROWS = 40,
    parameter   integer                  DEC_VIVO_FAKE_G016_ACTIVE_H = 600,
    parameter   integer                  DEC_VIVO_FAKE_G016_UV_ACTIVE_H = 300,
    parameter   integer                  DEC_VIVO_FAKE_G016_TILE_PITCH = 8192,
    parameter   integer                  DEC_VIVO_FAKE_G016_Y_TILE_COLS = 128,
    parameter   integer                  DEC_VIVO_FAKE_G016_UV_TILE_COLS = 128,
    parameter   integer                  DEC_VIVO_FAKE_G016_Y_TILE_ROWS = 152,
    parameter   integer                  DEC_VIVO_FAKE_G016_UV_TILE_ROWS = 76,
    parameter   integer                  DEC_VIVO_FAKE_META_PITCH_BYTES = 512,
    parameter   [63                :0]   DEC_VIVO_FAKE_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter   [63                :0]   DEC_VIVO_FAKE_TILE_BASE_UV_ADDR = 64'h0000_0000_8020_0000,
    parameter   [63                :0]   DEC_VIVO_FAKE_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter   [63                :0]   DEC_VIVO_FAKE_META_BASE_UV_ADDR = 64'h0000_0000_8020_0000,
    parameter   integer                  DEC_VIVO_FAKE_TILE0_WORDS64 = 1,
    parameter   integer                  DEC_VIVO_FAKE_TILE1_WORDS64 = 1,
    parameter   integer                  DEC_VIVO_FAKE_CMP0_WORDS64  = 1,
    parameter   integer                  DEC_VIVO_FAKE_CMP1_WORDS64  = 1,
    parameter   integer                  DEC_VIVO_FAKE_META0_WORDS64 = 1,
    parameter   integer                  DEC_VIVO_FAKE_META1_WORDS64 = 1
)(
    // ---------------------------------------------------------------------
    // APB slave interface
    // ---------------------------------------------------------------------
    input   wire                                PCLK                          ,
    input   wire                                PRESETn                       ,
    input   wire                                PSEL                          ,
    input   wire                                PENABLE                       ,
    input   wire    [APB_AW              -1 :0] PADDR                         ,
    input   wire                                PWRITE                        ,
    input   wire    [APB_DW              -1 :0] PWDATA                        ,
    output  wire                                PREADY                        ,
    output  wire                                PSLVERR                       ,
    output  wire    [APB_DW              -1 :0] PRDATA                        ,

    // ---------------------------------------------------------------------
    // Direct configuration: OTF backend
    // ---------------------------------------------------------------------
    input   wire                                i_otf_clk                     ,
    input   wire                                i_vivo_clk                    ,
    input   wire                                i_otf_rstn                    ,
    input   wire                                i_vivo_rstn                   ,
    output  wire                                o_otf_vsync                   ,
    output  wire                                o_otf_hsync                   ,
    output  wire                                o_otf_de                      ,
    output  wire    [127                    :0] o_otf_data                    ,
    output  wire    [3                      :0] o_otf_fcnt                    ,
    output  wire    [11                     :0] o_otf_lcnt                    ,
    input   wire                                i_otf_ready                   ,

    // ---------------------------------------------------------------------
    // External OTF ping-pong SRAM banks
    // ---------------------------------------------------------------------
    output  wire                                o_bank0_en                    ,
    output  wire                                o_bank0_wen                   ,
    output  wire    [COM_BUF_AW          -1 :0] o_bank0_addr                  ,
    output  wire    [COM_BUF_DW          -1 :0] o_bank0_din                   ,
    input   wire    [COM_BUF_DW          -1 :0] i_bank0_dout                  ,
    input   wire                                i_bank0_dout_vld              ,
    output  wire                                o_bank1_en                    ,
    output  wire                                o_bank1_wen                   ,
    output  wire    [COM_BUF_AW          -1 :0] o_bank1_addr                  ,
    output  wire    [COM_BUF_DW          -1 :0] o_bank1_din                   ,
    input   wire    [COM_BUF_DW          -1 :0] i_bank1_dout                  ,
    input   wire                                i_bank1_dout_vld              ,

    // ---------------------------------------------------------------------
    // Shared AXI read master interface on i_axi_clk
    // ---------------------------------------------------------------------
    input   wire                                i_axi_clk                     ,
    input   wire                                i_axi_rstn                    ,
    output  wire    [AXI_IDW                :0] o_m_axi_arid                  ,
    output  wire    [AXI_AW              -1 :0] o_m_axi_araddr                ,
    output  wire    [AXI_LENW            -1 :0] o_m_axi_arlen                 ,
    output  wire    [3                      :0] o_m_axi_arsize                ,
    output  wire    [1                      :0] o_m_axi_arburst               ,
    output  wire    [0                      :0] o_m_axi_arlock                ,
    output  wire    [3                      :0] o_m_axi_arcache               ,
    output  wire    [2                      :0] o_m_axi_arprot                ,
    output  wire                                o_m_axi_arvalid               ,
    input   wire                                i_m_axi_arready               ,
    input   wire    [AXI_IDW                :0] i_m_axi_rid                   ,
    input   wire    [AXI_DW              -1 :0] i_m_axi_rdata                 ,
    input   wire                                i_m_axi_rvalid                ,
    input   wire    [1                      :0] i_m_axi_rresp                 ,
    input   wire                                i_m_axi_rlast                 ,
    output  wire                                o_m_axi_rready                ,

    // ---------------------------------------------------------------------
    // Done/interrupt
    // ---------------------------------------------------------------------
    output  wire    [4                      :0] o_stage_done                  ,
    output  wire                                o_frame_done                  ,
    output  wire                                o_irq
);

    localparam integer                  CORE_AXI_DW                 = 256   ;
    localparam integer                  VIVO_CI_FIFO_W              = 1 + 3 + 5 + 4 + 1 + 2 + 4 + 12 + 10 + 4;
    localparam integer                  VIVO_CVI_FIFO_W             = 256 + 1 + 5 + 12 + 10 + 4;
    localparam integer                  VIVO_CO_FIFO_W              = 3;
    localparam integer                  VIVO_COORD_FIFO_W           = 5 + 12 + 10 + 4;
    localparam integer                  VIVO_RVO_FIFO_W             = 256 + 1;
    localparam integer                  VIVO_CI_FIFO_DEPTH_BITS     = 4;
    localparam integer                  VIVO_CVI_FIFO_DEPTH_BITS    = 4;
    localparam integer                  VIVO_CO_FIFO_DEPTH_BITS     = 4;
    localparam integer                  VIVO_COORD_FIFO_DEPTH       = 16;
    localparam integer                  VIVO_RVO_FIFO_DEPTH_BITS    = 4;
    localparam integer                  IP_AXI_LENW                 = 8;

    wire                                ctrl_rst_n                             ;
    wire                                sram_rst_n                             ;
    wire                                otf_rst_n                              ;
    wire                                vivo_rst_n                             ;
    wire                                r_tile_cfg_lvl2_bank_swizzle_en        ;
    wire                                r_tile_cfg_lvl3_bank_swizzle_en        ;
    wire    [5                   -1 :0] r_tile_cfg_highest_bank_bit            ;
    wire                                r_tile_cfg_bank_spread_en              ;
    wire                                r_tile_cfg_is_lossy_rgba_2_1_format    ;
    wire    [12                  -1 :0] r_tile_cfg_pitch                       ;
    wire                                r_tile_cfg_ci_input_type               ;
    wire                                r_tile_cfg_ci_lossy                    ;
    wire    [2                   -1 :0] r_tile_cfg_ci_alpha_mode               ;
    wire    [4                   -1 :0] r_tile_cfg_ubwc_ver                    ;
    wire    [AXI_AW              -1 :0] r_tile_base_addr_rgba_y0               ;
    wire    [AXI_AW              -1 :0] r_tile_base_addr_uv0                   ;
    wire    [AXI_AW              -1 :0] r_tile_base_addr_rgba_y1               ;
    wire    [AXI_AW              -1 :0] r_tile_base_addr_uv1                   ;
    wire                                r_vivo_ubwc_en                         ;
    wire                                r_vivo_sreset                          ;
    wire                                frame_start_pulse_axi                  ;
    wire                                meta_start_pulse_axi                   ;
    wire    [5                   -1 :0] r_meta_base_format                     ;
    wire    [AXI_AW              -1 :0] r_meta_base_addr_rgba_y0               ;
    wire    [AXI_AW              -1 :0] r_meta_base_addr_uv0                   ;
    wire    [AXI_AW              -1 :0] r_meta_base_addr_rgba_y1               ;
    wire    [AXI_AW              -1 :0] r_meta_base_addr_uv1                   ;
    wire    [16                  -1 :0] r_meta_tile_x_numbers                  ;
    wire    [16                  -1 :0] r_meta_tile_y_numbers                  ;
    wire    [5                   -1 :0] r_otf_cfg_format                       ;
    wire    [16                  -1 :0] r_otf_cfg_h_total                      ;
    wire    [16                  -1 :0] r_otf_cfg_h_sync                       ;
    wire    [16                  -1 :0] r_otf_cfg_h_bp                         ;
    wire    [16                  -1 :0] r_otf_cfg_h_act                        ;
    wire    [16                  -1 :0] r_otf_cfg_v_total                      ;
    wire    [16                  -1 :0] r_otf_cfg_v_sync                       ;
    wire    [16                  -1 :0] r_otf_cfg_v_bp                         ;
    wire    [16                  -1 :0] r_otf_cfg_v_act                        ;
    wire                                meta_stage_busy_int                    ;
    wire                                tile_stage_busy_int                    ;
    wire                                meta_stage_busy_core_int               ;
    wire                                tile_stage_busy_core_int               ;
    wire                                vivo_stage_busy_int                    ;
    wire                                otf_stage_busy_int                     ;
    wire                                rd_interconnect_busy_int               ;
    wire                                rd_interconnect_core_busy_int          ;
    wire                                dec_frame_active_int                   ;
    wire                                dec_any_stage_busy_int                 ;
    wire    [4                   -1 :0] dec_stage_seen_int                     ;
    wire    [5                   -1 :0] dec_stage_done_int                     ;
    wire                                dec_frame_done_int                     ;
    wire                                dec_irq_int                            ;
    wire                                dec_irq_pending_int                    ;
    wire                                dec_irq_correct_pending_int            ;
    wire                                dec_irq_error_pending_int              ;
    wire                                dec_irq_enable_axi                     ;
    wire                                dec_irq_clear_pulse_axi                ;
    wire                                vivo_idle_int                          ;
    wire    [6                      :0] vivo_error_int                         ;
    wire    [32                  -1 :0] meta_error_cnt_int                     ;
    wire    [32                  -1 :0] meta_cmd_fail_cnt_int                  ;
    wire    [32                  -1 :0] tile_cmd_fail_cnt_int                  ;
    wire                                dec_correct_irq_event_int              ;
    wire                                dec_error_irq_event_int                ;
    wire                                otf_underflow_int                      ;
    wire                                stat_meta_tile_fire_int                ;
    wire                                stat_tile_addr_fire_int                ;
    wire                                stat_otf_tile_fire_int                 ;
    wire    [32                  -1 :0] stat_meta_tile_cnt_int                 ;
    wire    [32                  -1 :0] stat_tile_addr_cnt_int                 ;
    wire    [32                  -1 :0] stat_otf_tile_cnt_int                  ;
    wire    [32                  -1 :0] stat_otf_line_cnt_int                  ;
    wire    [32                  -1 :0] stat_otf_de_cnt_int                    ;
    wire    [32                  -1 :0] otf_line_cnt_raw_int                   ;
    wire    [32                  -1 :0] otf_de_cnt_raw_int                     ;
    wire    [4                   -1 :0] dec_frame_fcnt_active                  ;
    wire    [4                   -1 :0] meta_dec_fcnt                          ;
    wire                                meta_dec_valid                         ;
    wire                                meta_dec_ready                         ;
    wire    [5                   -1 :0] meta_dec_format                        ;
    wire    [4                   -1 :0] meta_dec_flag                          ;
    wire    [3                   -1 :0] meta_dec_alen                          ;
    wire    [2                   -1 :0] meta_dec_alpha_mode                    ;
    wire    [12                  -1 :0] meta_dec_x                             ;
    wire    [10                  -1 :0] meta_dec_y                             ;
    wire    [AXI_IDW                :0] core_m_axi_arid                        ;
    wire    [AXI_AW              -1 :0] core_m_axi_araddr                      ;
    wire    [IP_AXI_LENW         -1 :0] core_m_axi_arlen                       ;
    wire    [3                   -1 :0] core_m_axi_arsize                      ;
    wire    [2                   -1 :0] core_m_axi_arburst                     ;
    wire                                core_m_axi_arvalid                     ;
    wire                                core_m_axi_arready                     ;
    wire    [CORE_AXI_DW         -1 :0] core_m_axi_rdata                       ;
    wire                                core_m_axi_rvalid                      ;
    wire    [2                   -1 :0] core_m_axi_rresp                       ;
    wire                                core_m_axi_rlast                       ;
    wire                                core_m_axi_rready                      ;
    wire                                meta_m_axi_arvalid                     ;
    wire                                meta_m_axi_arready                     ;
    wire    [AXI_AW              -1 :0] meta_m_axi_araddr                      ;
    wire    [8                   -1 :0] meta_m_axi_arlen                       ;
    wire    [3                   -1 :0] meta_m_axi_arsize                      ;
    wire    [2                   -1 :0] meta_m_axi_arburst                     ;
    wire    [AXI_IDW             -1 :0] meta_m_axi_arid                        ;
    wire    [AXI_IDW             -1 :0] meta_m_axi_rid                         ;
    wire                                meta_m_axi_rvalid                      ;
    wire                                meta_m_axi_rready                      ;
    wire    [CORE_AXI_DW         -1 :0] meta_m_axi_rdata                       ;
    wire    [2                   -1 :0] meta_m_axi_rresp                       ;
    wire                                meta_m_axi_rlast                       ;
    wire                                tile_m_axi_arvalid                     ;
    wire                                tile_m_axi_arready                     ;
    wire    [AXI_AW              -1 :0] tile_m_axi_araddr                      ;
    wire    [8                   -1 :0] tile_m_axi_arlen                       ;
    wire    [3                   -1 :0] tile_m_axi_arsize                      ;
    wire    [2                   -1 :0] tile_m_axi_arburst                     ;
    wire    [AXI_IDW             -1 :0] tile_m_axi_arid                        ;
    wire    [AXI_IDW             -1 :0] tile_m_axi_rid                         ;
    wire                                tile_m_axi_rvalid                      ;
    wire                                tile_m_axi_rready                      ;
    wire    [CORE_AXI_DW         -1 :0] tile_m_axi_rdata                       ;
    wire    [2                   -1 :0] tile_m_axi_rresp                       ;
    wire                                tile_m_axi_rlast                       ;
    wire                                tile_ci_valid_int                      ;
    wire                                tile_ci_ready_int                      ;
    wire                                tile_ci_input_type_int                 ;
    wire    [3                   -1 :0] tile_ci_alen_int                       ;
    wire    [5                   -1 :0] tile_ci_format_int                     ;
    wire    [4                   -1 :0] tile_ci_metadata_int                   ;
    wire                                tile_ci_lossy_int                      ;
    wire    [2                   -1 :0] tile_ci_alpha_mode_int                 ;
    wire                                tile_coord_vld_int                     ;
    wire    [5                   -1 :0] tile_format_int                        ;
    wire    [12                  -1 :0] tile_x_coord_int                       ;
    wire    [10                  -1 :0] tile_y_coord_int                       ;
    wire    [4                   -1 :0] tile_fcnt_int                          ;
    wire                                tile_cvi_valid_int                     ;
    wire    [256                 -1 :0] tile_cvi_data_int                      ;
    wire                                tile_cvi_last_int                      ;
    wire    [5                   -1 :0] tile_cvi_format_int                    ;
    wire    [12                  -1 :0] tile_cvi_x_coord_int                   ;
    wire    [10                  -1 :0] tile_cvi_y_coord_int                   ;
    wire    [4                   -1 :0] tile_cvi_fcnt_int                      ;
    wire                                tile_cvi_ready_int                     ;
    wire    [AXI_IDW                :0] core_m_axi_rid_r                       ;
    wire    [AXI_IDW                :0] rd_x2x_rid_m                           ;
    wire    [AXI_IDW                :0] rd_x2x_arid_s                          ;
    wire    [IP_AXI_LENW         -1 :0] rd_x2x_arlen_s                         ;
    wire    [2                      :0] rd_x2x_arsize_s                        ;
    wire    [1                      :0] rd_x2x_arlock_s                        ;
    wire    [AXI_AW              -1 :0] axi_aw_zero                            ;
    wire    [AXI_IDW             -1 :0] axi_id_zero                            ;
    wire    [AXI_IDW                :0] axi_id_ext_zero                        ;
    wire    [IP_AXI_LENW         -1 :0] axi_len_zero                           ;
    wire    [CORE_AXI_DW         -1 :0] core_axi_data_zero                     ;
    wire    [CORE_AXI_DW/8       -1 :0] core_axi_strb_zero                     ;
    wire    [3                      :0] o_m_axi_arsize_int                     ;
    wire                                o_m_axi_arlock_int                     ;
    wire                                dec_vivo_reset                         ;
    wire                                vivo_ci_ready_raw                      ;
    wire                                vivo_ci_valid_int                      ;
    wire                                vivo_ci_fire_vivo                      ;
    wire                                vivo_ci_input_type_int                 ;
    wire    [3                   -1 :0] vivo_ci_alen_int                       ;
    wire    [5                   -1 :0] vivo_ci_format_int                     ;
    wire    [4                   -1 :0] vivo_ci_metadata_int                   ;
    wire                                vivo_ci_lossy_int                      ;
    wire    [2                   -1 :0] vivo_ci_alpha_mode_int                 ;
    wire    [4                   -1 :0] vivo_ci_ubwc_ver_int                   ;
    wire    [12                  -1 :0] vivo_ci_x_coord_int                    ;
    wire    [10                  -1 :0] vivo_ci_y_coord_int                    ;
    wire    [4                   -1 :0] vivo_ci_fcnt_int                       ;
    wire                                vivo_ci_has_payload                    ;
    wire                                vivo_ci_payload_ready                  ;
    wire                                vivo_ci_payload_fire                   ;
    wire                                vivo_cvi_valid_int                     ;
    wire                                vivo_cvi_fire_vivo                     ;
    wire                                vivo_cvi_last_fire                     ;
    wire    [256                 -1 :0] vivo_cvi_data_int                      ;
    wire                                vivo_cvi_last_int                      ;
    wire    [5                   -1 :0] vivo_cvi_format_int                    ;
    wire    [12                  -1 :0] vivo_cvi_x_coord_int                   ;
    wire    [10                  -1 :0] vivo_cvi_y_coord_int                   ;
    wire    [4                   -1 :0] vivo_cvi_fcnt_int                      ;
    wire                                vivo_cvi_ready_int                     ;
    wire                                vivo_rvo_valid                         ;
    wire    [255                    :0] vivo_rvo_data                          ;
    wire                                vivo_rvo_last                          ;
    wire                                vivo_rvo_ready                         ;
    wire                                vivo_co_valid                          ;
    wire                                vivo_co_ready                          ;
    wire    [2                   :0]    vivo_co_alen                           ;
    wire                                vivo_idle_vivo                         ;
    wire    [6                      :0] vivo_error_vivo                        ;
    wire                                vivo_ci_fifo_full                      ;
    wire                                vivo_ci_fifo_empty                     ;
    wire        [VIVO_CI_FIFO_W      -1 :0] vivo_ci_fifo_din                   ;
    wire        [VIVO_CI_FIFO_W      -1 :0] vivo_ci_fifo_dout                  ;
    wire                                vivo_ci_fifo_wr_en                     ;
    wire                                vivo_ci_fifo_rd_en                     ;
    wire                                vivo_cvi_fifo_full                     ;
    wire                                vivo_cvi_fifo_empty                    ;
    wire        [VIVO_CVI_FIFO_W     -1 :0] vivo_cvi_fifo_din                  ;
    wire        [VIVO_CVI_FIFO_W     -1 :0] vivo_cvi_fifo_dout                 ;
    wire                                vivo_cvi_fifo_wr_en                    ;
    wire                                vivo_cvi_fifo_rd_en                    ;
    wire                                vivo_co_fifo_full                      ;
    wire                                vivo_co_fifo_empty                     ;
    wire        [VIVO_CO_FIFO_W      -1 :0] vivo_co_fifo_din                   ;
    wire        [VIVO_CO_FIFO_W      -1 :0] vivo_co_fifo_dout                  ;
    wire                                vivo_co_fifo_wr_en                     ;
    wire                                vivo_co_fifo_rd_en                     ;
    wire                                vivo_co_axi_valid                      ;
    wire                                vivo_coord_fifo_full                   ;
    wire                                vivo_coord_fifo_valid                  ;
    wire        [VIVO_COORD_FIFO_W   -1 :0] vivo_coord_fifo_din                ;
    wire        [VIVO_COORD_FIFO_W   -1 :0] vivo_coord_fifo_dout               ;
    wire                                vivo_coord_fifo_wr_en                  ;
    wire                                vivo_coord_fifo_rd_en                  ;
    wire    [5                   -1 :0] vivo_coord_format_axi                  ;
    wire    [12                  -1 :0] vivo_coord_x_axi                       ;
    wire    [10                  -1 :0] vivo_coord_y_axi                       ;
    wire    [4                   -1 :0] vivo_coord_fcnt_axi                    ;
    wire                                otf_axis_tile_fire                     ;
    wire                                vivo_rvo_fifo_full                     ;
    wire                                vivo_rvo_fifo_empty                    ;
    wire        [VIVO_RVO_FIFO_W     -1 :0] vivo_rvo_fifo_din                  ;
    wire        [VIVO_RVO_FIFO_W     -1 :0] vivo_rvo_fifo_dout                 ;
    wire                                vivo_rvo_fifo_wr_en                    ;
    wire                                vivo_rvo_fifo_rd_en                    ;
    wire                                tile_ci_fire_int                       ;
    wire                                tile_cvi_fire_int                      ;
    wire                                otf_axis_tile_ready_int                ;
    wire                                otf_axis_tready_int                    ;
    wire    [4                      :0] otf_axis_format                        ;
    wire    [15                     :0] otf_axis_tile_x                        ;
    wire    [15                     :0] otf_axis_tile_y                        ;
    wire    [3                      :0] otf_axis_tile_fcnt                     ;
    wire                                otf_axis_tile_valid                    ;
    wire    [255                    :0] otf_axis_tdata                         ;
    wire                                otf_axis_tlast                         ;
    wire                                otf_axis_tvalid                        ;
    wire                                otf_sram_a_wen_int                     ;
    wire    [COM_BUF_AW          -1 :0] otf_sram_a_waddr_int                   ;
    wire    [127                    :0] otf_sram_a_wdata_int                   ;
    wire                                otf_sram_a_ren_int                     ;
    wire    [COM_BUF_AW          -1 :0] otf_sram_a_raddr_int                   ;
    wire    [127                    :0] otf_sram_a_rdata_int                   ;
    wire                                otf_sram_b_wen_int                     ;
    wire    [COM_BUF_AW          -1 :0] otf_sram_b_waddr_int                   ;
    wire    [127                    :0] otf_sram_b_wdata_int                   ;
    wire                                otf_sram_b_ren_int                     ;
    wire    [COM_BUF_AW          -1 :0] otf_sram_b_raddr_int                   ;
    wire    [127                    :0] otf_sram_b_rdata_int                   ;

    reg     [32                  -1 :0] meta_error_cnt_d              ;
    reg     [32                  -1 :0] meta_cmd_fail_cnt_d           ;
    reg     [32                  -1 :0] tile_cmd_fail_cnt_d           ;
    reg     [6                      :0] vivo_error_d                  ;
    reg     [4                   -1 :0] dec_frame_fcnt_active_r       ;
    reg     [4                   -1 :0] dec_frame_fcnt_next           ;
    reg                                 vivo_idle_meta                ;
    reg                                 vivo_idle_sync                ;
    reg     [6                      :0] vivo_error_meta               ;
    reg     [6                      :0] vivo_error_sync               ;
    reg                                vivo_ubwc_en_meta              ;
    reg                                vivo_ubwc_en_sync              ;
    reg                                vivo_sreset_meta               ;
    reg                                vivo_sreset_sync               ;
    reg                                vivo_cvi_gate_active           ;

    assign dec_frame_fcnt_active         = frame_start_pulse_axi ? dec_frame_fcnt_next :
                                                                 dec_frame_fcnt_active_r;
    assign axi_aw_zero                   = {AXI_AW{1'b0}};
    assign axi_id_zero                   = {AXI_IDW{1'b0}};
    assign axi_id_ext_zero               = {(AXI_IDW+1){1'b0}};
    assign axi_len_zero                  = {IP_AXI_LENW{1'b0}};
    assign core_axi_data_zero            = {CORE_AXI_DW{1'b0}};
    assign core_axi_strb_zero            = {(CORE_AXI_DW/8){1'b0}};
    assign o_m_axi_arsize_int            = {1'b0, rd_x2x_arsize_s};
    assign o_m_axi_arlock_int            = rd_x2x_arlock_s[0];
    assign ctrl_rst_n                    = i_axi_rstn;
    assign sram_rst_n                    = i_axi_rstn;
    assign otf_rst_n                     = i_otf_rstn;
    assign vivo_rst_n                    = i_vivo_rstn;
    assign dec_vivo_reset                = ~vivo_rst_n;
    assign core_m_axi_rid_r              = rd_x2x_rid_m;
    assign o_m_axi_arid                  = rd_x2x_arid_s;
    assign o_m_axi_arlen                 = rd_x2x_arlen_s[AXI_LENW-1:0];
    assign o_m_axi_arsize                = o_m_axi_arsize_int;
    assign o_m_axi_arlock                = o_m_axi_arlock_int;
    assign rd_interconnect_core_busy_int = meta_m_axi_arvalid | tile_m_axi_arvalid |
                                           core_m_axi_arvalid | core_m_axi_rvalid |
                                           meta_m_axi_rvalid | tile_m_axi_rvalid;
    assign rd_interconnect_busy_int      = rd_interconnect_core_busy_int |
                                           core_m_axi_arvalid |
                                           core_m_axi_rvalid |
                                           o_m_axi_arvalid |
                                           i_m_axi_rvalid;
    assign meta_stage_busy_int           = meta_stage_busy_core_int | rd_interconnect_busy_int;
    assign tile_stage_busy_int           = tile_stage_busy_core_int | rd_interconnect_busy_int;
    assign stat_meta_tile_fire_int       = meta_dec_valid & meta_dec_ready;
    assign stat_tile_addr_fire_int       = tile_coord_vld_int;
    assign dec_error_irq_event_int       = ((meta_error_cnt_int != meta_error_cnt_d) && (|meta_error_cnt_int)) ||
                                           ((meta_cmd_fail_cnt_int != meta_cmd_fail_cnt_d) && (|meta_cmd_fail_cnt_int)) ||
                                           ((tile_cmd_fail_cnt_int != tile_cmd_fail_cnt_d) && (|tile_cmd_fail_cnt_int)) ||
                                           (|(vivo_error_int & ~vivo_error_d)) ||
                                           otf_underflow_int;
    assign o_stage_done                  = dec_stage_done_int;
    assign o_frame_done                  = dec_frame_done_int;
    assign o_irq                         = dec_irq_int;
    assign vivo_idle_int                 = vivo_idle_sync;
    assign vivo_error_int                = vivo_error_sync;
    assign stat_otf_tile_fire_int        = otf_axis_tile_fire;
    assign tile_ci_fire_int              = tile_ci_valid_int & tile_ci_ready_int;
    assign tile_cvi_fire_int             = tile_cvi_valid_int & tile_cvi_ready_int;
    assign otf_axis_tile_fire            = otf_axis_tile_valid & otf_axis_tile_ready_int;
    assign vivo_ci_fifo_din              = {tile_ci_input_type_int,
                                            tile_ci_alen_int,
                                            tile_ci_format_int,
                                            tile_ci_metadata_int,
                                            tile_ci_lossy_int,
                                            tile_ci_alpha_mode_int,
                                            r_tile_cfg_ubwc_ver,
                                            tile_x_coord_int,
                                            tile_y_coord_int,
                                            tile_fcnt_int};
    assign vivo_ci_fifo_wr_en            = tile_ci_fire_int;
    assign vivo_ci_fire_vivo             = vivo_ci_valid_int & vivo_ci_ready_raw;
    assign vivo_ci_fifo_rd_en            = vivo_ci_fire_vivo;
    assign vivo_ci_valid_int             = !vivo_ci_fifo_empty & vivo_ci_payload_ready;
    assign vivo_ci_input_type_int        = vivo_ci_fifo_dout[45];
    assign vivo_ci_alen_int              = vivo_ci_fifo_dout[42 +: 3];
    assign vivo_ci_format_int            = vivo_ci_fifo_dout[37 +: 5];
    assign vivo_ci_metadata_int          = vivo_ci_fifo_dout[33 +: 4];
    assign vivo_ci_lossy_int             = vivo_ci_fifo_dout[32];
    assign vivo_ci_alpha_mode_int        = vivo_ci_fifo_dout[30 +: 2];
    assign vivo_ci_ubwc_ver_int          = vivo_ci_fifo_dout[26 +: 4];
    assign vivo_ci_x_coord_int           = vivo_ci_fifo_dout[14 +: 12];
    assign vivo_ci_y_coord_int           = vivo_ci_fifo_dout[4  +: 10];
    assign vivo_ci_fcnt_int              = vivo_ci_fifo_dout[0  +: 4];
    assign vivo_ci_has_payload           = !vivo_ci_metadata_int[3];
    assign vivo_ci_payload_ready         = !vivo_ci_has_payload | !vivo_cvi_fifo_empty;
    assign vivo_ci_payload_fire          = vivo_ci_fire_vivo & vivo_ci_has_payload;
    assign tile_ci_ready_int             = !vivo_ci_fifo_full & !vivo_coord_fifo_full;
    assign vivo_coord_fifo_din           = {tile_format_int,
                                            tile_x_coord_int,
                                            tile_y_coord_int,
                                            tile_fcnt_int};
    assign vivo_coord_fifo_wr_en         = tile_ci_fire_int;
    assign vivo_coord_fifo_rd_en         = otf_axis_tile_fire;
    assign vivo_coord_format_axi         = vivo_coord_fifo_dout[26 +: 5];
    assign vivo_coord_x_axi              = vivo_coord_fifo_dout[14 +: 12];
    assign vivo_coord_y_axi              = vivo_coord_fifo_dout[4  +: 10];
    assign vivo_coord_fcnt_axi           = vivo_coord_fifo_dout[0  +: 4];
    assign vivo_co_ready                 = !vivo_co_fifo_full;
    assign vivo_co_fifo_din              = vivo_co_alen;
    assign vivo_co_fifo_wr_en            = vivo_co_valid & vivo_co_ready;
    assign vivo_co_fifo_rd_en            = otf_axis_tile_fire;
    assign vivo_co_axi_valid             = !vivo_co_fifo_empty;
    assign vivo_cvi_fifo_din             = {tile_cvi_format_int,
                                            tile_cvi_x_coord_int,
                                            tile_cvi_y_coord_int,
                                            tile_cvi_fcnt_int,
                                            tile_cvi_last_int,
                                            tile_cvi_data_int};
    assign vivo_cvi_fifo_wr_en           = tile_cvi_fire_int;
    assign vivo_cvi_fire_vivo            = vivo_cvi_valid_int & vivo_cvi_ready_int;
    assign vivo_cvi_fifo_rd_en           = vivo_cvi_fire_vivo;
    assign vivo_cvi_valid_int            = (vivo_cvi_gate_active |
                                           (vivo_ci_valid_int & vivo_ci_has_payload)) &
                                           !vivo_cvi_fifo_empty;
    assign vivo_cvi_data_int             = vivo_cvi_fifo_dout[0 +: 256];
    assign vivo_cvi_last_int             = vivo_cvi_fifo_dout[256];
    assign vivo_cvi_fcnt_int             = vivo_cvi_fifo_dout[257 +: 4];
    assign vivo_cvi_y_coord_int          = vivo_cvi_fifo_dout[261 +: 10];
    assign vivo_cvi_x_coord_int          = vivo_cvi_fifo_dout[271 +: 12];
    assign vivo_cvi_format_int           = vivo_cvi_fifo_dout[283 +: 5];
    assign vivo_cvi_last_fire            = vivo_cvi_fire_vivo & vivo_cvi_last_int;
    assign tile_cvi_ready_int            = !vivo_cvi_fifo_full;
    assign vivo_rvo_fifo_din             = {vivo_rvo_last, vivo_rvo_data};
    assign vivo_rvo_fifo_wr_en           = vivo_rvo_valid & vivo_rvo_ready;
    assign vivo_rvo_fifo_rd_en           = otf_axis_tvalid & otf_axis_tready_int;
    assign vivo_rvo_ready                = !vivo_rvo_fifo_full;
    assign otf_axis_format               = vivo_coord_format_axi;
    assign otf_axis_tile_x               = {4'd0, vivo_coord_x_axi};
    assign otf_axis_tile_y               = {6'd0, vivo_coord_y_axi};
    assign otf_axis_tile_fcnt            = vivo_coord_fcnt_axi;
    assign otf_axis_tile_valid           = vivo_coord_fifo_valid & vivo_co_axi_valid;
    assign otf_axis_tdata                = vivo_rvo_fifo_dout[0 +: 256];
    assign otf_axis_tlast                = vivo_rvo_fifo_dout[256];
    assign otf_axis_tvalid               = !vivo_rvo_fifo_empty;
    assign vivo_stage_busy_int           = !vivo_idle_int;
    assign o_bank0_en                    = otf_sram_a_wen_int | otf_sram_a_ren_int;
    assign o_bank0_wen                   = otf_sram_a_wen_int;
    assign o_bank0_addr                  = otf_sram_a_wen_int ? otf_sram_a_waddr_int : otf_sram_a_raddr_int;
    assign o_bank0_din                   = otf_sram_a_wdata_int;
    assign o_bank1_en                    = otf_sram_b_wen_int | otf_sram_b_ren_int;
    assign o_bank1_wen                   = otf_sram_b_wen_int;
    assign o_bank1_addr                  = otf_sram_b_wen_int ? otf_sram_b_waddr_int : otf_sram_b_raddr_int;
    assign o_bank1_din                   = otf_sram_b_wdata_int;
    assign otf_sram_a_rdata_int          = i_bank0_dout[127:0];
    assign otf_sram_b_rdata_int          = i_bank1_dout[127:0];

    always @(posedge i_axi_clk or negedge ctrl_rst_n) begin
        if (!ctrl_rst_n) begin
            dec_frame_fcnt_active_r <= 4'd0;
            dec_frame_fcnt_next     <= 4'd0;
        end else if (frame_start_pulse_axi) begin
            dec_frame_fcnt_active_r <= dec_frame_fcnt_next;
            dec_frame_fcnt_next     <= dec_frame_fcnt_next + 4'd1;
        end
    end

    always @(posedge i_vivo_clk or negedge vivo_rst_n) begin
        if (!vivo_rst_n)
            vivo_ubwc_en_meta <= 1'b0;
        else
            vivo_ubwc_en_meta <= r_vivo_ubwc_en;
    end

    always @(posedge i_vivo_clk or negedge vivo_rst_n) begin
        if (!vivo_rst_n)
            vivo_ubwc_en_sync <= 1'b0;
        else
            vivo_ubwc_en_sync <= vivo_ubwc_en_meta;
    end

    always @(posedge i_vivo_clk or negedge vivo_rst_n) begin
        if (!vivo_rst_n)
            vivo_sreset_meta <= 1'b1;
        else
            vivo_sreset_meta <= r_vivo_sreset;
    end

    always @(posedge i_vivo_clk or negedge vivo_rst_n) begin
        if (!vivo_rst_n)
            vivo_sreset_sync <= 1'b1;
        else
            vivo_sreset_sync <= vivo_sreset_meta;
    end

    always @(posedge i_vivo_clk or negedge vivo_rst_n) begin
        if (!vivo_rst_n)
            vivo_cvi_gate_active <= 1'b0;
        else if (vivo_ci_payload_fire & !vivo_cvi_last_fire)
            vivo_cvi_gate_active <= 1'b1;
        else if (vivo_cvi_last_fire)
            vivo_cvi_gate_active <= 1'b0;
    end

    always @(posedge i_axi_clk or negedge ctrl_rst_n) begin
        if (!ctrl_rst_n)
            vivo_idle_meta <= 1'b0;
        else
            vivo_idle_meta <= vivo_idle_vivo;
    end

    always @(posedge i_axi_clk or negedge ctrl_rst_n) begin
        if (!ctrl_rst_n)
            vivo_idle_sync <= 1'b0;
        else
            vivo_idle_sync <= vivo_idle_meta;
    end

    always @(posedge i_axi_clk or negedge ctrl_rst_n) begin
        if (!ctrl_rst_n)
            vivo_error_meta <= 7'd0;
        else
            vivo_error_meta <= vivo_error_vivo;
    end

    always @(posedge i_axi_clk or negedge ctrl_rst_n) begin
        if (!ctrl_rst_n)
            vivo_error_sync <= 7'd0;
        else
            vivo_error_sync <= vivo_error_meta;
    end

    ubwc_dec_apb_reg_blk #(
        .AW                         ( APB_AW                        ),
        .DW                         ( APB_DW                        ),
        .AXI_AW                     ( AXI_AW                        ),
        .SB_WIDTH                   ( SB_WIDTH                      )
    ) u_apb_dec_reg_blk (
        .PCLK                                   ( PCLK                                ),
        .PRESETn                                ( PRESETn                             ),
        .PSEL                                   ( PSEL                                ),
        .PENABLE                                ( PENABLE                             ),
        .PADDR                                  ( PADDR                               ),
        .PWRITE                                 ( PWRITE                              ),
        .PWDATA                                 ( PWDATA                              ),
        .i_axi_clk                              ( i_axi_clk                           ),
        .i_axi_rst_n                            ( ctrl_rst_n                          ),
        .i_meta_busy_axi                        ( meta_stage_busy_int                 ),
        .i_tile_busy_axi                        ( tile_stage_busy_int                 ),
        .i_vivo_busy_axi                        ( vivo_stage_busy_int                 ),
        .i_otf_busy_axi                         ( otf_stage_busy_int                  ),
        .i_frame_active_axi                     ( dec_frame_active_int                ),
        .i_any_stage_busy_axi                   ( dec_any_stage_busy_int              ),
        .i_stage_seen_axi                       ( dec_stage_seen_int                  ),
        .i_stage_done_axi                       ( dec_stage_done_int                  ),
        .i_vivo_idle_axi                        ( vivo_idle_int                       ),
        .i_vivo_error_axi                       ( vivo_error_int                      ),
        .i_irq_pending_axi                      ( dec_irq_pending_int                 ),
        .i_irq_correct_pending_axi              ( dec_irq_correct_pending_int         ),
        .i_irq_error_pending_axi                ( dec_irq_error_pending_int           ),
        .i_stat_meta_tile_cnt_axi               ( stat_meta_tile_cnt_int              ),
        .i_stat_tile_addr_cnt_axi               ( stat_tile_addr_cnt_int              ),
        .i_stat_otf_tile_cnt_axi                ( stat_otf_tile_cnt_int               ),
        .i_stat_otf_line_cnt_axi                ( stat_otf_line_cnt_int               ),
        .i_stat_otf_de_cnt_axi                  ( stat_otf_de_cnt_int                 ),
        .PREADY                                 ( PREADY                              ),
        .PSLVERR                                ( PSLVERR                             ),
        .PRDATA                                 ( PRDATA                              ),
        .o_tile_cfg_lvl2_bank_swizzle_en        ( r_tile_cfg_lvl2_bank_swizzle_en     ),
        .o_tile_cfg_lvl3_bank_swizzle_en        ( r_tile_cfg_lvl3_bank_swizzle_en     ),
        .o_tile_cfg_highest_bank_bit            ( r_tile_cfg_highest_bank_bit         ),
        .o_tile_cfg_bank_spread_en              ( r_tile_cfg_bank_spread_en           ),
        .o_tile_cfg_is_lossy_rgba_2_1_format    ( r_tile_cfg_is_lossy_rgba_2_1_format ),
        .o_tile_cfg_pitch                       ( r_tile_cfg_pitch                    ),
        .o_tile_cfg_ci_input_type               ( r_tile_cfg_ci_input_type            ),
        .o_tile_cfg_ci_lossy                    ( r_tile_cfg_ci_lossy                 ),
        .o_tile_cfg_ci_alpha_mode               ( r_tile_cfg_ci_alpha_mode            ),
        .o_tile_cfg_ubwc_ver                    ( r_tile_cfg_ubwc_ver                 ),
        .o_tile_base_addr_rgba_y0               ( r_tile_base_addr_rgba_y0            ),
        .o_tile_base_addr_uv0                   ( r_tile_base_addr_uv0                ),
        .o_tile_base_addr_rgba_y1               ( r_tile_base_addr_rgba_y1            ),
        .o_tile_base_addr_uv1                   ( r_tile_base_addr_uv1                ),
        .o_vivo_ubwc_en                         ( r_vivo_ubwc_en                      ),
        .o_vivo_sreset                          ( r_vivo_sreset                       ),
        .o_frame_start_pulse_axi                ( frame_start_pulse_axi               ),
        .o_meta_start_pulse_axi                 ( meta_start_pulse_axi                ),
        .o_meta_base_format                     ( r_meta_base_format                  ),
        .o_meta_base_addr_rgba_y0               ( r_meta_base_addr_rgba_y0            ),
        .o_meta_base_addr_uv0                   ( r_meta_base_addr_uv0                ),
        .o_meta_base_addr_rgba_y1               ( r_meta_base_addr_rgba_y1            ),
        .o_meta_base_addr_uv1                   ( r_meta_base_addr_uv1                ),
        .o_meta_tile_x_numbers                  ( r_meta_tile_x_numbers               ),
        .o_meta_tile_y_numbers                  ( r_meta_tile_y_numbers               ),
        .o_otf_cfg_img_width                    (                                 ),
        .o_otf_cfg_format                       ( r_otf_cfg_format                    ),
        .o_otf_cfg_h_total                      ( r_otf_cfg_h_total                   ),
        .o_otf_cfg_h_sync                       ( r_otf_cfg_h_sync                    ),
        .o_otf_cfg_h_bp                         ( r_otf_cfg_h_bp                      ),
        .o_otf_cfg_h_act                        ( r_otf_cfg_h_act                     ),
        .o_otf_cfg_v_total                      ( r_otf_cfg_v_total                   ),
        .o_otf_cfg_v_sync                       ( r_otf_cfg_v_sync                    ),
        .o_otf_cfg_v_bp                         ( r_otf_cfg_v_bp                      ),
        .o_otf_cfg_v_act                        ( r_otf_cfg_v_act                     ),
        .o_irq_enable_axi                       ( dec_irq_enable_axi                  ),
        .o_irq_clear_pulse_axi                  ( dec_irq_clear_pulse_axi             )
    );

    // ---------------------------------------------------------------------
    // Metadata path -> tile command path
    // ---------------------------------------------------------------------

    ubwc_dec_meta_data_gen #(
        .ADDR_WIDTH                 ( AXI_AW                        ),
        .ID_WIDTH                   ( AXI_IDW                       ),
        .AXI_DATA_WIDTH             ( CORE_AXI_DW                   ),
        .FORCE_FULL_PAYLOAD         ( FORCE_FULL_PAYLOAD            )
    ) u_meta_data_gen (
        .clk                               ( i_axi_clk                           ),
        .rst_n                             ( ctrl_rst_n                          ),
        .start                             ( meta_start_pulse_axi                ),
        .i_fcnt                            ( dec_frame_fcnt_active               ),
        .base_format                       ( r_meta_base_format                  ),
        .meta_base_addr_rgba_y0            ( r_meta_base_addr_rgba_y0            ),
        .meta_base_addr_uv0                ( r_meta_base_addr_uv0                ),
        .meta_base_addr_rgba_y1            ( r_meta_base_addr_rgba_y1            ),
        .meta_base_addr_uv1                ( r_meta_base_addr_uv1                ),
        .tile_x_numbers                    ( r_meta_tile_x_numbers               ),
        .tile_y_numbers                    ( r_meta_tile_y_numbers               ),
        .i_cfg_is_lossy_rgba_2_1_format    ( r_tile_cfg_is_lossy_rgba_2_1_format ),
        .m_axi_arvalid                     ( meta_m_axi_arvalid                  ),
        .m_axi_arready                     ( meta_m_axi_arready                  ),
        .m_axi_araddr                      ( meta_m_axi_araddr                   ),
        .m_axi_arlen                       ( meta_m_axi_arlen                    ),
        .m_axi_arsize                      ( meta_m_axi_arsize                   ),
        .m_axi_arburst                     ( meta_m_axi_arburst                  ),
        .m_axi_arid                        ( meta_m_axi_arid                     ),
        .m_axi_rvalid                      ( meta_m_axi_rvalid                   ),
        .m_axi_rready                      ( meta_m_axi_rready                   ),
        .m_axi_rdata                       ( meta_m_axi_rdata                    ),
        .m_axi_rid                         ( meta_m_axi_rid                      ),
        .m_axi_rresp                       ( meta_m_axi_rresp                    ),
        .m_axi_rlast                       ( meta_m_axi_rlast                    ),
        .o_dec_valid                       ( meta_dec_valid                      ),
        .i_dec_ready                       ( meta_dec_ready                      ),
        .o_dec_format                      ( meta_dec_format                     ),
        .o_dec_flag                        ( meta_dec_flag                       ),
        .o_dec_alen                        ( meta_dec_alen                       ),
        .o_dec_alpha_mode                  ( meta_dec_alpha_mode                 ),
        .o_dec_x                           ( meta_dec_x                          ),
        .o_dec_y                           ( meta_dec_y                          ),
        .o_dec_fcnt                        ( meta_dec_fcnt                       ),
        .o_busy                            ( meta_stage_busy_core_int            ),
        .error_cnt                         ( meta_error_cnt_int                  ),
        .cmd_ok_cnt                        (                                     ),
        .cmd_fail_cnt                      ( meta_cmd_fail_cnt_int               )
    );

    ubwc_dec_tile_arcmd_gen #(
        .AXI_AW                     ( AXI_AW                        ),
        .AXI_DW                     ( CORE_AXI_DW                   ),
        .AXI_IDW                    ( AXI_IDW                       ),
        .SB_WIDTH                   ( SB_WIDTH                      )
    ) u_tile_arcmd_gen (
        .clk                               ( i_axi_clk                           ),
        .rst_n                             ( ctrl_rst_n                          ),
        .i_frame_start                     ( frame_start_pulse_axi               ),
        .i_cfg_lvl2_bank_swizzle_en        ( r_tile_cfg_lvl2_bank_swizzle_en     ),
        .i_cfg_lvl3_bank_swizzle_en        ( r_tile_cfg_lvl3_bank_swizzle_en     ),
        .i_cfg_highest_bank_bit            ( r_tile_cfg_highest_bank_bit         ),
        .i_cfg_bank_spread_en              ( r_tile_cfg_bank_spread_en           ),
        .i_cfg_is_lossy_rgba_2_1_format    ( r_tile_cfg_is_lossy_rgba_2_1_format ),
        .i_cfg_pitch                       ( r_tile_cfg_pitch                    ),
        .i_cfg_ci_input_type               ( r_tile_cfg_ci_input_type            ),
        .i_cfg_ci_lossy                    ( r_tile_cfg_ci_lossy                 ),
        .i_cfg_ci_alpha_mode               ( r_tile_cfg_ci_alpha_mode            ),
        .i_cfg_base_addr_rgba_y0           ( r_tile_base_addr_rgba_y0            ),
        .i_cfg_base_addr_uv0               ( r_tile_base_addr_uv0                ),
        .i_cfg_base_addr_rgba_y1           ( r_tile_base_addr_rgba_y1            ),
        .i_cfg_base_addr_uv1               ( r_tile_base_addr_uv1                ),
        .dec_meta_valid                    ( meta_dec_valid                      ),
        .dec_meta_ready                    ( meta_dec_ready                      ),
        .dec_meta_format                   ( meta_dec_format                     ),
        .dec_meta_flag                     ( meta_dec_flag                       ),
        .dec_meta_alen                     ( meta_dec_alen                       ),
        .dec_meta_alpha_mode               ( meta_dec_alpha_mode                 ),
        .dec_meta_x                        ( meta_dec_x                          ),
        .dec_meta_y                        ( meta_dec_y                          ),
        .dec_meta_fcnt                     ( meta_dec_fcnt                       ),
        .m_axi_arvalid                     ( tile_m_axi_arvalid                  ),
        .m_axi_arready                     ( tile_m_axi_arready                  ),
        .m_axi_araddr                      ( tile_m_axi_araddr                   ),
        .m_axi_arlen                       ( tile_m_axi_arlen                    ),
        .m_axi_arsize                      ( tile_m_axi_arsize                   ),
        .m_axi_arburst                     ( tile_m_axi_arburst                  ),
        .m_axi_arid                        ( tile_m_axi_arid                     ),
        .m_axi_rvalid                      ( tile_m_axi_rvalid                   ),
        .m_axi_rid                         ( tile_m_axi_rid                      ),
        .m_axi_rdata                       ( tile_m_axi_rdata                    ),
        .m_axi_rresp                       ( tile_m_axi_rresp                    ),
        .m_axi_rlast                       ( tile_m_axi_rlast                    ),
        .m_axi_rready                      ( tile_m_axi_rready                   ),
        .o_ci_valid                        ( tile_ci_valid_int                   ),
        .i_ci_ready                        ( tile_ci_ready_int                   ),
        .o_ci_input_type                   ( tile_ci_input_type_int              ),
        .o_ci_alen                         ( tile_ci_alen_int                    ),
        .o_ci_format                       ( tile_ci_format_int                  ),
        .o_ci_metadata                     ( tile_ci_metadata_int                ),
        .o_ci_lossy                        ( tile_ci_lossy_int                   ),
        .o_ci_alpha_mode                   ( tile_ci_alpha_mode_int              ),
        .o_ci_sb                           (                                  ),
        .o_tile_coord_vld                  ( tile_coord_vld_int                  ),
        .o_tile_format                     ( tile_format_int                     ),
        .o_tile_x_coord                    ( tile_x_coord_int                    ),
        .o_tile_y_coord                    ( tile_y_coord_int                    ),
        .o_tile_fcnt                       ( tile_fcnt_int                       ),
        .o_cvi_valid                       ( tile_cvi_valid_int                  ),
        .o_cvi_data                        ( tile_cvi_data_int                   ),
        .o_cvi_last                        ( tile_cvi_last_int                   ),
        .o_cvi_format                      ( tile_cvi_format_int                 ),
        .o_cvi_x_coord                     ( tile_cvi_x_coord_int                ),
        .o_cvi_y_coord                     ( tile_cvi_y_coord_int                ),
        .o_cvi_fcnt                        ( tile_cvi_fcnt_int                   ),
        .i_cvi_ready                       ( tile_cvi_ready_int                  ),
        .o_busy                            ( tile_stage_busy_core_int            ),
        .cmd_fail_cnt                      ( tile_cmd_fail_cnt_int               )
    );

    // ---------------------------------------------------------------------
    // Shared AXI read interconnect
    // ---------------------------------------------------------------------

    axi_2t1_int_DW_axi u_axi_rd_interconnect (
        .aclk                       ( i_axi_clk                     ),
        .aresetn                    ( ctrl_rst_n                    ),

        .awvalid_m1                 ( 1'b0                          ),
        .awaddr_m1                  ( axi_aw_zero                   ),
        .awid_m1                    ( axi_id_zero                   ),
        .awlen_m1                   ( axi_len_zero                  ),
        .awsize_m1                  ( 3'd0                          ),
        .awburst_m1                 ( 2'd0                          ),
        .awlock_m1                  ( 1'b0                          ),
        .awcache_m1                 ( 4'd0                          ),
        .awprot_m1                  ( 3'd0                          ),
        .awready_m1                 (                               ),
        .wvalid_m1                  ( 1'b0                          ),
        .wdata_m1                   ( core_axi_data_zero            ),
        .wstrb_m1                   ( core_axi_strb_zero            ),
        .wlast_m1                   ( 1'b0                          ),
        .wready_m1                  (                               ),
        .bvalid_m1                  (                               ),
        .bid_m1                     (                               ),
        .bresp_m1                   (                               ),
        .bready_m1                  ( 1'b1                          ),

        .arvalid_m1                 ( meta_m_axi_arvalid            ),
        .arid_m1                    ( meta_m_axi_arid               ),
        .araddr_m1                  ( meta_m_axi_araddr             ),
        .arlen_m1                   ( meta_m_axi_arlen              ),
        .arsize_m1                  ( meta_m_axi_arsize             ),
        .arburst_m1                 ( meta_m_axi_arburst            ),
        .arlock_m1                  ( 1'b0                          ),
        .arcache_m1                 ( 4'd0                          ),
        .arprot_m1                  ( 3'd0                          ),
        .arready_m1                 ( meta_m_axi_arready            ),
        .rvalid_m1                  ( meta_m_axi_rvalid             ),
        .rid_m1                     ( meta_m_axi_rid                ),
        .rdata_m1                   ( meta_m_axi_rdata              ),
        .rresp_m1                   ( meta_m_axi_rresp              ),
        .rlast_m1                   ( meta_m_axi_rlast              ),
        .rready_m1                  ( meta_m_axi_rready             ),

        .awvalid_m2                 ( 1'b0                          ),
        .awaddr_m2                  ( axi_aw_zero                   ),
        .awid_m2                    ( axi_id_zero                   ),
        .awlen_m2                   ( axi_len_zero                  ),
        .awsize_m2                  ( 3'd0                          ),
        .awburst_m2                 ( 2'd0                          ),
        .awlock_m2                  ( 1'b0                          ),
        .awcache_m2                 ( 4'd0                          ),
        .awprot_m2                  ( 3'd0                          ),
        .awready_m2                 (                               ),
        .wvalid_m2                  ( 1'b0                          ),
        .wdata_m2                   ( core_axi_data_zero            ),
        .wstrb_m2                   ( core_axi_strb_zero            ),
        .wlast_m2                   ( 1'b0                          ),
        .wready_m2                  (                               ),
        .bvalid_m2                  (                               ),
        .bid_m2                     (                               ),
        .bresp_m2                   (                               ),
        .bready_m2                  ( 1'b1                          ),

        .arvalid_m2                 ( tile_m_axi_arvalid            ),
        .arid_m2                    ( tile_m_axi_arid               ),
        .araddr_m2                  ( tile_m_axi_araddr             ),
        .arlen_m2                   ( tile_m_axi_arlen              ),
        .arsize_m2                  ( tile_m_axi_arsize             ),
        .arburst_m2                 ( tile_m_axi_arburst            ),
        .arlock_m2                  ( 1'b0                          ),
        .arcache_m2                 ( 4'd0                          ),
        .arprot_m2                  ( 3'd0                          ),
        .arready_m2                 ( tile_m_axi_arready            ),
        .rvalid_m2                  ( tile_m_axi_rvalid             ),
        .rid_m2                     ( tile_m_axi_rid                ),
        .rdata_m2                   ( tile_m_axi_rdata              ),
        .rresp_m2                   ( tile_m_axi_rresp              ),
        .rlast_m2                   ( tile_m_axi_rlast              ),
        .rready_m2                  ( tile_m_axi_rready             ),

        .awvalid_s1                 (                               ),
        .awaddr_s1                  (                               ),
        .awid_s1                    (                               ),
        .awlen_s1                   (                               ),
        .awsize_s1                  (                               ),
        .awburst_s1                 (                               ),
        .awlock_s1                  (                               ),
        .awcache_s1                 (                               ),
        .awprot_s1                  (                               ),
        .awready_s1                 ( 1'b0                          ),
        .wvalid_s1                  (                               ),
        .wdata_s1                   (                               ),
        .wstrb_s1                   (                               ),
        .wlast_s1                   (                               ),
        .wready_s1                  ( 1'b0                          ),
        .bvalid_s1                  ( 1'b0                          ),
        .bid_s1                     ( axi_id_ext_zero               ),
        .bresp_s1                   ( 2'd0                          ),
        .bready_s1                  (                               ),

        .arvalid_s1                 ( core_m_axi_arvalid            ),
        .arid_s1                    ( core_m_axi_arid               ),
        .araddr_s1                  ( core_m_axi_araddr             ),
        .arlen_s1                   ( core_m_axi_arlen              ),
        .arsize_s1                  ( core_m_axi_arsize             ),
        .arburst_s1                 ( core_m_axi_arburst            ),
        .arlock_s1                  (                               ),
        .arcache_s1                 (                               ),
        .arprot_s1                  (                               ),
        .arready_s1                 ( core_m_axi_arready            ),
        .rvalid_s1                  ( core_m_axi_rvalid             ),
        .rid_s1                     ( core_m_axi_rid_r              ),
        .rdata_s1                   ( core_m_axi_rdata              ),
        .rresp_s1                   ( core_m_axi_rresp              ),
        .rlast_s1                   ( core_m_axi_rlast              ),
        .rready_s1                  ( core_m_axi_rready             ),

        .dbg_awid_s0                (                               ),
        .dbg_awaddr_s0              (                               ),
        .dbg_awlen_s0               (                               ),
        .dbg_awsize_s0              (                               ),
        .dbg_awburst_s0             (                               ),
        .dbg_awlock_s0              (                               ),
        .dbg_awcache_s0             (                               ),
        .dbg_awprot_s0              (                               ),
        .dbg_awvalid_s0             (                               ),
        .dbg_awready_s0             (                               ),
        .dbg_wid_s0                 (                               ),
        .dbg_wdata_s0               (                               ),
        .dbg_wstrb_s0               (                               ),
        .dbg_wlast_s0               (                               ),
        .dbg_wvalid_s0              (                               ),
        .dbg_wready_s0              (                               ),
        .dbg_bid_s0                 (                               ),
        .dbg_bresp_s0               (                               ),
        .dbg_bvalid_s0              (                               ),
        .dbg_bready_s0              (                               ),
        .dbg_arid_s0                (                               ),
        .dbg_araddr_s0              (                               ),
        .dbg_arlen_s0               (                               ),
        .dbg_arsize_s0              (                               ),
        .dbg_arburst_s0             (                               ),
        .dbg_arlock_s0              (                               ),
        .dbg_arcache_s0             (                               ),
        .dbg_arprot_s0              (                               ),
        .dbg_arvalid_s0             (                               ),
        .dbg_arready_s0             (                               ),
        .dbg_rid_s0                 (                               ),
        .dbg_rdata_s0               (                               ),
        .dbg_rresp_s0               (                               ),
        .dbg_rvalid_s0              (                               ),
        .dbg_rlast_s0               (                               ),
        .dbg_rready_s0              (                               )
    );

    ubwc_x2x_DW_axi_x2x u_axi_rd_x2x (
        .aclk_m                     ( i_axi_clk                     ),
        .aresetn_m                  ( ctrl_rst_n                    ),

        .awvalid_m                  ( 1'b0                          ),
        .awaddr_m                   ( axi_aw_zero                   ),
        .awid_m                     ( axi_id_ext_zero               ),
        .awlen_m                    ( axi_len_zero                  ),
        .awsize_m                   ( 3'd0                          ),
        .awburst_m                  ( 2'd0                          ),
        .awlock_m                   ( 2'd0                          ),
        .awcache_m                  ( 4'd0                          ),
        .awprot_m                   ( 3'd0                          ),
        .awready_m                  (                               ),
        .wvalid_m                   ( 1'b0                          ),
        .wid_m                      ( axi_id_ext_zero               ),
        .wdata_m                    ( core_axi_data_zero            ),
        .wstrb_m                    ( core_axi_strb_zero            ),
        .wlast_m                    ( 1'b0                          ),
        .wready_m                   (                               ),
        .bvalid_m                   (                               ),
        .bid_m                      (                               ),
        .bresp_m                    (                               ),
        .bready_m                   ( 1'b1                          ),

        .arvalid_m                  ( core_m_axi_arvalid            ),
        .arid_m                     ( core_m_axi_arid               ),
        .araddr_m                   ( core_m_axi_araddr             ),
        .arlen_m                    ( core_m_axi_arlen              ),
        .arsize_m                   ( core_m_axi_arsize             ),
        .arburst_m                  ( core_m_axi_arburst            ),
        .arlock_m                   ( 2'd0                          ),
        .arcache_m                  ( 4'd0                          ),
        .arprot_m                   ( 3'd0                          ),
        .arready_m                  ( core_m_axi_arready            ),
        .rvalid_m                   ( core_m_axi_rvalid             ),
        .rid_m                      ( rd_x2x_rid_m                  ),
        .rdata_m                    ( core_m_axi_rdata              ),
        .rresp_m                    ( core_m_axi_rresp              ),
        .rlast_m                    ( core_m_axi_rlast              ),
        .rready_m                   ( core_m_axi_rready             ),

        .awvalid_s1                 (                               ),
        .awaddr_s1                  (                               ),
        .awid_s1                    (                               ),
        .awlen_s1                   (                               ),
        .awsize_s1                  (                               ),
        .awburst_s1                 (                               ),
        .awlock_s1                  (                               ),
        .awcache_s1                 (                               ),
        .awprot_s1                  (                               ),
        .awready_s1                 ( 1'b0                          ),
        .wvalid_s1                  (                               ),
        .wid_s1                     (                               ),
        .wdata_s1                   (                               ),
        .wstrb_s1                   (                               ),
        .wlast_s1                   (                               ),
        .wready_s1                  ( 1'b0                          ),
        .bvalid_s1                  ( 1'b0                          ),
        .bid_s1                     ( axi_id_ext_zero               ),
        .bresp_s1                   ( 2'd0                          ),
        .bready_s1                  (                               ),

        .arvalid_s                  ( o_m_axi_arvalid               ),
        .arid_s                     ( rd_x2x_arid_s                 ),
        .araddr_s                   ( o_m_axi_araddr                ),
        .arlen_s                    ( rd_x2x_arlen_s                ),
        .arsize_s                   ( rd_x2x_arsize_s               ),
        .arburst_s                  ( o_m_axi_arburst               ),
        .arlock_s                   ( rd_x2x_arlock_s               ),
        .arcache_s                  ( o_m_axi_arcache               ),
        .arprot_s                   ( o_m_axi_arprot                ),
        .arready_s                  ( i_m_axi_arready               ),
        .rvalid_s                   ( i_m_axi_rvalid                ),
        .rid_s                      ( i_m_axi_rid                   ),
        .rdata_s                    ( i_m_axi_rdata                 ),
        .rresp_s                    ( i_m_axi_rresp                 ),
        .rlast_s                    ( i_m_axi_rlast                 ),
        .rready_s                   ( o_m_axi_rready                )
    );

    always @(posedge i_axi_clk or negedge ctrl_rst_n) begin
        if (!ctrl_rst_n)
            meta_error_cnt_d <= 32'd0;
        else
            meta_error_cnt_d <= meta_error_cnt_int;
    end

    always @(posedge i_axi_clk or negedge ctrl_rst_n) begin
        if (!ctrl_rst_n)
            meta_cmd_fail_cnt_d <= 32'd0;
        else
            meta_cmd_fail_cnt_d <= meta_cmd_fail_cnt_int;
    end

    always @(posedge i_axi_clk or negedge ctrl_rst_n) begin
        if (!ctrl_rst_n)
            tile_cmd_fail_cnt_d <= 32'd0;
        else
            tile_cmd_fail_cnt_d <= tile_cmd_fail_cnt_int;
    end

    always @(posedge i_axi_clk or negedge ctrl_rst_n) begin
        if (!ctrl_rst_n)
            vivo_error_d <= 7'd0;
        else
            vivo_error_d <= vivo_error_int;
    end

    ubwc_dec_status u_dec_status
    (
        .i_clk                      ( i_axi_clk                     ),
        .i_rstn                     ( ctrl_rst_n                    ),
        .i_frame_start              ( frame_start_pulse_axi         ),

        .i_meta_busy                ( meta_stage_busy_int           ),
        .i_tile_busy                ( tile_stage_busy_int           ),
        .i_vivo_busy                ( vivo_stage_busy_int           ),
        .i_otf_busy                 ( otf_stage_busy_int            ),
        .i_correct_irq_event        ( dec_correct_irq_event_int     ),
        .i_error_irq_event          ( dec_error_irq_event_int       ),
        .i_meta_tile_fire           ( stat_meta_tile_fire_int       ),
        .i_tile_addr_fire           ( stat_tile_addr_fire_int       ),
        .i_otf_tile_fire            ( stat_otf_tile_fire_int        ),
        .i_otf_line_count           ( otf_line_cnt_raw_int          ),
        .i_otf_de_count             ( otf_de_cnt_raw_int            ),
        .i_irq_enable               ( dec_irq_enable_axi            ),
        .i_irq_clear                ( dec_irq_clear_pulse_axi       ),

        .o_frame_active             ( dec_frame_active_int          ),
        .o_any_stage_busy           ( dec_any_stage_busy_int        ),
        .o_stage_seen               ( dec_stage_seen_int            ),
        .o_stage_done               ( dec_stage_done_int            ),
        .o_frame_done               ( dec_frame_done_int            ),
        .o_irq_correct_pending      ( dec_irq_correct_pending_int   ),
        .o_irq_error_pending        ( dec_irq_error_pending_int     ),
        .o_irq_pending              ( dec_irq_pending_int           ),
        .o_irq                      ( dec_irq_int                   ),
        .o_meta_tile_count          ( stat_meta_tile_cnt_int        ),
        .o_tile_addr_count          ( stat_tile_addr_cnt_int        ),
        .o_otf_tile_count           ( stat_otf_tile_cnt_int         ),
        .o_otf_line_count           ( stat_otf_line_cnt_int         ),
        .o_otf_de_count             ( stat_otf_de_cnt_int           )
    );

    // ---------------------------------------------------------------------
    // ubwc_dec_vivo_top integration
    // ---------------------------------------------------------------------

    // Tile header and CI command now share the same ready chain. This keeps
    // format/x/y aligned with the CI acceptance point and removes the need
    // for extra wrapper-side header FIFOs.

    mg_sync_fifo
    #(
        .PROG_DEPTH                ( 1                             ),
        .DWIDTH                    ( VIVO_COORD_FIFO_W             ),
        .DEPTH                     ( VIVO_COORD_FIFO_DEPTH         ),
        .SHOW_AHEAD                ( 1                             )
    )
    u_vivo_coord_fifo
    (
        .clk                       ( i_axi_clk                     ),
        .rst_n                     ( ctrl_rst_n                    ),
        .wr_en                     ( vivo_coord_fifo_wr_en         ),
        .din                       ( vivo_coord_fifo_din           ),
        .prog_full                 (                               ),
        .full                      ( vivo_coord_fifo_full          ),
        .rd_en                     ( vivo_coord_fifo_rd_en         ),
        .empty                     (                               ),
        .dout                      ( vivo_coord_fifo_dout          ),
        .valid                     ( vivo_coord_fifo_valid         ),
        .data_count                (                               )
    );

    mg_async_fifo
    #(
        .AF                         ( 1                             ),
        .DATA_BITS                  ( VIVO_CI_FIFO_W                ),
        .DEPTH_BITS                 ( VIVO_CI_FIFO_DEPTH_BITS       ),
        .SHOW_AHEAD                 ( 1                             )
    )
    u_vivo_ci_async_fifo
    (
        .wr_clk                     ( i_axi_clk                     ),
        .wr_rstn                    ( ctrl_rst_n                    ),
        .wr_en                      ( vivo_ci_fifo_wr_en            ),
        .din                        ( vivo_ci_fifo_din              ),
        .wr_data_count              (                               ),
        .prog_full                  (                               ),
        .full                       ( vivo_ci_fifo_full             ),
        .rd_clk                     ( i_vivo_clk                    ),
        .rd_rstn                    ( vivo_rst_n                    ),
        .rd_en                      ( vivo_ci_fifo_rd_en            ),
        .dout                       ( vivo_ci_fifo_dout             ),
        .valid                      (                               ),
        .rd_data_count              (                               ),
        .pre_empty                  (                               ),
        .empty                      ( vivo_ci_fifo_empty            )
    );

    mg_async_fifo
    #(
        .AF                         ( 1                             ),
        .DATA_BITS                  ( VIVO_CVI_FIFO_W               ),
        .DEPTH_BITS                 ( VIVO_CVI_FIFO_DEPTH_BITS      ),
        .SHOW_AHEAD                 ( 1                             )
    )
    u_vivo_cvi_async_fifo
    (
        .wr_clk                     ( i_axi_clk                     ),
        .wr_rstn                    ( ctrl_rst_n                    ),
        .wr_en                      ( vivo_cvi_fifo_wr_en           ),
        .din                        ( vivo_cvi_fifo_din             ),
        .wr_data_count              (                               ),
        .prog_full                  (                               ),
        .full                       ( vivo_cvi_fifo_full            ),
        .rd_clk                     ( i_vivo_clk                    ),
        .rd_rstn                    ( vivo_rst_n                    ),
        .rd_en                      ( vivo_cvi_fifo_rd_en           ),
        .dout                       ( vivo_cvi_fifo_dout            ),
        .valid                      (                               ),
        .rd_data_count              (                               ),
        .pre_empty                  (                               ),
        .empty                      ( vivo_cvi_fifo_empty           )
    );

    mg_async_fifo
    #(
        .AF                         ( 1                             ),
        .DATA_BITS                  ( VIVO_CO_FIFO_W                ),
        .DEPTH_BITS                 ( VIVO_CO_FIFO_DEPTH_BITS       ),
        .SHOW_AHEAD                 ( 1                             )
    )
    u_vivo_co_async_fifo
    (
        .wr_clk                     ( i_vivo_clk                    ),
        .wr_rstn                    ( vivo_rst_n                    ),
        .wr_en                      ( vivo_co_fifo_wr_en            ),
        .din                        ( vivo_co_fifo_din              ),
        .wr_data_count              (                               ),
        .prog_full                  (                               ),
        .full                       ( vivo_co_fifo_full             ),
        .rd_clk                     ( i_axi_clk                     ),
        .rd_rstn                    ( ctrl_rst_n                    ),
        .rd_en                      ( vivo_co_fifo_rd_en            ),
        .dout                       ( vivo_co_fifo_dout             ),
        .valid                      (                               ),
        .rd_data_count              (                               ),
        .pre_empty                  (                               ),
        .empty                      ( vivo_co_fifo_empty            )
    );

    mg_async_fifo
    #(
        .AF                         ( 1                             ),
        .DATA_BITS                  ( VIVO_RVO_FIFO_W               ),
        .DEPTH_BITS                 ( VIVO_RVO_FIFO_DEPTH_BITS      ),
        .SHOW_AHEAD                 ( 1                             )
    )
    u_vivo_rvo_async_fifo
    (
        .wr_clk                     ( i_vivo_clk                    ),
        .wr_rstn                    ( vivo_rst_n                    ),
        .wr_en                      ( vivo_rvo_fifo_wr_en           ),
        .din                        ( vivo_rvo_fifo_din             ),
        .wr_data_count              (                               ),
        .prog_full                  (                               ),
        .full                       ( vivo_rvo_fifo_full            ),
        .rd_clk                     ( i_axi_clk                     ),
        .rd_rstn                    ( ctrl_rst_n                    ),
        .rd_en                      ( vivo_rvo_fifo_rd_en           ),
        .dout                       ( vivo_rvo_fifo_dout            ),
        .valid                      (                               ),
        .rd_data_count              (                               ),
        .pre_empty                  (                               ),
        .empty                      ( vivo_rvo_fifo_empty           )
    );

    ubwc_dec_vivo_top
    #(
        .SB_WIDTH                  ( SB_WIDTH                      ),
        .FAKE_MODEL_EN             ( DEC_VIVO_FAKE_MODEL_EN        ),
        .FAKE_TILE_EXPECT_LINEAR   ( DEC_VIVO_FAKE_TILE_EXPECT_LINEAR ),
        .FAKE_IMG_W                ( DEC_VIVO_FAKE_IMG_W           ),
        .FAKE_RGBA_ACTIVE_H        ( DEC_VIVO_FAKE_RGBA_ACTIVE_H   ),
        .FAKE_RGBA_TILE_PITCH      ( DEC_VIVO_FAKE_RGBA_TILE_PITCH ),
        .FAKE_RGBA_TILE_COLS       ( DEC_VIVO_FAKE_RGBA_TILE_COLS  ),
        .FAKE_RGBA_TILE_ROWS       ( DEC_VIVO_FAKE_RGBA_TILE_ROWS  ),
        .FAKE_NV12_ACTIVE_H        ( DEC_VIVO_FAKE_NV12_ACTIVE_H   ),
        .FAKE_NV12_UV_ACTIVE_H     ( DEC_VIVO_FAKE_NV12_UV_ACTIVE_H ),
        .FAKE_NV12_TILE_PITCH      ( DEC_VIVO_FAKE_NV12_TILE_PITCH ),
        .FAKE_NV12_Y_TILE_COLS     ( DEC_VIVO_FAKE_NV12_Y_TILE_COLS ),
        .FAKE_NV12_UV_TILE_COLS    ( DEC_VIVO_FAKE_NV12_UV_TILE_COLS ),
        .FAKE_NV12_Y_TILE_ROWS     ( DEC_VIVO_FAKE_NV12_Y_TILE_ROWS ),
        .FAKE_NV12_UV_TILE_ROWS    ( DEC_VIVO_FAKE_NV12_UV_TILE_ROWS ),
        .FAKE_G016_ACTIVE_H        ( DEC_VIVO_FAKE_G016_ACTIVE_H   ),
        .FAKE_G016_UV_ACTIVE_H     ( DEC_VIVO_FAKE_G016_UV_ACTIVE_H ),
        .FAKE_G016_TILE_PITCH      ( DEC_VIVO_FAKE_G016_TILE_PITCH ),
        .FAKE_G016_Y_TILE_COLS     ( DEC_VIVO_FAKE_G016_Y_TILE_COLS ),
        .FAKE_G016_UV_TILE_COLS    ( DEC_VIVO_FAKE_G016_UV_TILE_COLS ),
        .FAKE_G016_Y_TILE_ROWS     ( DEC_VIVO_FAKE_G016_Y_TILE_ROWS ),
        .FAKE_G016_UV_TILE_ROWS    ( DEC_VIVO_FAKE_G016_UV_TILE_ROWS ),
        .FAKE_META_PITCH_BYTES     ( DEC_VIVO_FAKE_META_PITCH_BYTES ),
        .FAKE_TILE_BASE_Y_ADDR     ( DEC_VIVO_FAKE_TILE_BASE_Y_ADDR ),
        .FAKE_TILE_BASE_UV_ADDR    ( DEC_VIVO_FAKE_TILE_BASE_UV_ADDR ),
        .FAKE_META_BASE_Y_ADDR     ( DEC_VIVO_FAKE_META_BASE_Y_ADDR ),
        .FAKE_META_BASE_UV_ADDR    ( DEC_VIVO_FAKE_META_BASE_UV_ADDR ),
        .FAKE_TILE0_WORDS64        ( DEC_VIVO_FAKE_TILE0_WORDS64    ),
        .FAKE_TILE1_WORDS64        ( DEC_VIVO_FAKE_TILE1_WORDS64    ),
        .FAKE_CMP0_WORDS64         ( DEC_VIVO_FAKE_CMP0_WORDS64     ),
        .FAKE_CMP1_WORDS64         ( DEC_VIVO_FAKE_CMP1_WORDS64     ),
        .FAKE_META0_WORDS64        ( DEC_VIVO_FAKE_META0_WORDS64    ),
        .FAKE_META1_WORDS64        ( DEC_VIVO_FAKE_META1_WORDS64    )
    )
    u_dec_vivo_top (
        .i_clk                      ( i_vivo_clk                    ),
        .i_reset                    ( dec_vivo_reset                ),
        .i_sreset                   ( vivo_sreset_sync              ),
        .i_ubwc_en                  ( vivo_ubwc_en_sync             ),
        .i_ci_valid                 ( vivo_ci_valid_int             ),
        .o_ci_ready                 ( vivo_ci_ready_raw             ),
        .i_ci_input_type            ( vivo_ci_input_type_int        ),
        .i_ci_alen                  ( vivo_ci_alen_int              ),
        .i_ci_format                ( vivo_ci_format_int            ),
        .i_ci_metadata              ( vivo_ci_metadata_int          ),
        .i_ci_lossy                 ( vivo_ci_lossy_int             ),
        .i_ci_alpha_mode            ( vivo_ci_alpha_mode_int        ),
        .i_ci_ubwc_ver              ( vivo_ci_ubwc_ver_int          ),
        .i_ci_sb                    ( {SB_WIDTH{1'b0}}              ),
        .i_ci_xcoord                ( vivo_ci_x_coord_int           ),
        .i_ci_ycoord                ( vivo_ci_y_coord_int           ),
        .i_ci_fcnt                  ( vivo_ci_fcnt_int              ),
        .i_cvi_valid                ( vivo_cvi_valid_int            ),
        .i_cvi_data                 ( vivo_cvi_data_int             ),
        .i_cvi_last                 ( vivo_cvi_last_int             ),
        .i_cvi_format               ( vivo_cvi_format_int           ),
        .i_cvi_xcoord               ( vivo_cvi_x_coord_int          ),
        .i_cvi_ycoord               ( vivo_cvi_y_coord_int          ),
        .i_cvi_fcnt                 ( vivo_cvi_fcnt_int             ),
        .o_cvi_ready                ( vivo_cvi_ready_int            ),
        .o_co_valid                 ( vivo_co_valid                 ),
        .o_co_alen                  ( vivo_co_alen                  ),
        .i_co_ready                 ( vivo_co_ready                 ),
        .o_co_sb                    (                               ),
        .o_rvo_valid                ( vivo_rvo_valid                ),
        .o_rvo_data                 ( vivo_rvo_data                 ),
        .o_rvo_last                 ( vivo_rvo_last                 ),
        .i_rvo_ready                ( vivo_rvo_ready                ),
        .o_idle                     ( vivo_idle_vivo                ),
        .o_error                    ( vivo_error_vivo               )
    );

    ubwc_dec_tile_to_otf #(
        .SRAM_ADDR_W                ( COM_BUF_AW                    )
    ) u_tile_to_otf (
        .clk_sram                   ( i_axi_clk                     ),
        .clk_otf                    ( i_otf_clk                     ),
        .rst_sram_n                 ( sram_rst_n                    ),
        .rst_otf_n                  ( otf_rst_n                     ),
        .i_frame_start              ( frame_start_pulse_axi         ),
        .i_frame_fcnt               ( dec_frame_fcnt_active         ),
        .cfg_img_width              ( r_otf_cfg_h_act               ),
        .cfg_format                 ( r_otf_cfg_format              ),
        .cfg_otf_h_total            ( r_otf_cfg_h_total             ),
        .cfg_otf_h_sync             ( r_otf_cfg_h_sync              ),
        .cfg_otf_h_bp               ( r_otf_cfg_h_bp                ),
        .cfg_otf_h_act              ( r_otf_cfg_h_act               ),
        .cfg_otf_v_total            ( r_otf_cfg_v_total             ),
        .cfg_otf_v_sync             ( r_otf_cfg_v_sync              ),
        .cfg_otf_v_bp               ( r_otf_cfg_v_bp                ),
        .cfg_otf_v_act              ( r_otf_cfg_v_act               ),
        .s_axis_format              ( otf_axis_format               ),
        .s_axis_tile_x              ( otf_axis_tile_x               ),
        .s_axis_tile_y              ( otf_axis_tile_y               ),
        .s_axis_tile_fcnt           ( otf_axis_tile_fcnt            ),
        .s_axis_tile_valid          ( otf_axis_tile_valid           ),
        .s_axis_tile_ready          ( otf_axis_tile_ready_int       ),
        .s_axis_tdata               ( otf_axis_tdata                ),
        .s_axis_tlast               ( otf_axis_tlast                ),
        .s_axis_tvalid              ( otf_axis_tvalid               ),
        .s_axis_tready              ( otf_axis_tready_int           ),
        .sram_a_wen                 ( otf_sram_a_wen_int            ),
        .sram_a_waddr               ( otf_sram_a_waddr_int          ),
        .sram_a_wdata               ( otf_sram_a_wdata_int          ),
        .sram_a_ren                 ( otf_sram_a_ren_int            ),
        .sram_a_raddr               ( otf_sram_a_raddr_int          ),
        .sram_a_rdata               ( otf_sram_a_rdata_int          ),
        .sram_a_rvalid              ( i_bank0_dout_vld              ),
        .sram_b_wen                 ( otf_sram_b_wen_int            ),
        .sram_b_waddr               ( otf_sram_b_waddr_int          ),
        .sram_b_wdata               ( otf_sram_b_wdata_int          ),
        .sram_b_ren                 ( otf_sram_b_ren_int            ),
        .sram_b_raddr               ( otf_sram_b_raddr_int          ),
        .sram_b_rdata               ( otf_sram_b_rdata_int          ),
        .sram_b_rvalid              ( i_bank1_dout_vld              ),
        .o_otf_vsync                ( o_otf_vsync                   ),
        .o_otf_hsync                ( o_otf_hsync                   ),
        .o_otf_de                   ( o_otf_de                      ),
        .o_otf_data                 ( o_otf_data                    ),
        .o_otf_fcnt                 ( o_otf_fcnt                    ),
        .o_otf_lcnt                 ( o_otf_lcnt                    ),
        .i_otf_ready                ( i_otf_ready                   ),
        .o_busy                     ( otf_stage_busy_int            ),
        .o_correct_irq_pulse        ( dec_correct_irq_event_int     ),
        .o_underflow                ( otf_underflow_int             ),
        .o_otf_line_count           ( otf_line_cnt_raw_int          ),
        .o_otf_de_count             ( otf_de_cnt_raw_int            )
    );

endmodule
