//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Module Name       : ubwc_dec_apb_reg_blk.v
// Description       : APB register block for the current UBWC decode wrapper.
//                     It stores tile address configuration, metadata fetch
//                     configuration, and vivo control bits.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_dec_apb_reg_blk #(
    parameter                                       AW                              = 16,
    parameter                                       DW                              = 32,
    parameter                                       AXI_AW                          = 64,
    parameter                                       SB_WIDTH                        = 1
)(
    input   wire                                        PCLK                            ,
    input   wire                                        PRESETn                         ,
    input   wire                                        PSEL                            ,
    input   wire                                        PENABLE                         ,
    input   wire    [AW                  -1 :0]         PADDR                           ,
    input   wire                                        PWRITE                          ,
    input   wire    [DW                  -1 :0]         PWDATA                          ,
    output  wire                                        PREADY                          ,
    output  wire                                        PSLVERR                         ,
    output  wire    [DW                  -1 :0]         PRDATA                          ,

    input   wire                                        i_axi_clk                       ,
    input   wire                                        i_axi_rst_n                     ,
    input   wire                                        i_meta_busy_axi                 ,
    input   wire                                        i_tile_busy_axi                 ,
    input   wire                                        i_vivo_busy_axi                 ,
    input   wire                                        i_otf_busy_axi                  ,
    input   wire                                        i_frame_active_axi              ,
    input   wire                                        i_any_stage_busy_axi            ,
    input   wire    [3                      :0]         i_stage_seen_axi                ,
    input   wire    [4                      :0]         i_stage_done_axi                ,
    input   wire                                        i_vivo_idle_axi                 ,
    input   wire    [6                      :0]         i_vivo_error_axi                ,
    input   wire                                        i_irq_pending_axi               ,
    input   wire                                        i_irq_correct_pending_axi       ,
    input   wire                                        i_irq_error_pending_axi         ,
    input   wire    [31                     :0]         i_stat_meta_tile_cnt_axi        ,
    input   wire    [31                     :0]         i_stat_tile_addr_cnt_axi        ,
    input   wire    [31                     :0]         i_stat_otf_tile_cnt_axi         ,
    input   wire    [31                     :0]         i_stat_otf_line_cnt_axi         ,
    input   wire    [31                     :0]         i_stat_otf_de_cnt_axi           ,

    output  wire                                        o_tile_cfg_lvl2_bank_swizzle_en ,
    output  wire                                        o_tile_cfg_lvl3_bank_swizzle_en ,
    output  wire    [4                      :0]         o_tile_cfg_highest_bank_bit     ,
    output  wire                                        o_tile_cfg_bank_spread_en       ,
    output  wire                                        o_tile_cfg_is_lossy_rgba_2_1_format,
    output  wire    [11                     :0]         o_tile_cfg_pitch                ,
    output  wire                                        o_tile_cfg_ci_input_type        ,
    output  wire                                        o_tile_cfg_ci_lossy             ,
    output  wire    [1                      :0]         o_tile_cfg_ci_alpha_mode        ,
    output  wire    [3                      :0]         o_tile_cfg_ubwc_ver             ,
    output  wire    [AXI_AW              -1 :0]         o_tile_base_addr_rgba_y0        ,
    output  wire    [AXI_AW              -1 :0]         o_tile_base_addr_uv0            ,
    output  wire    [AXI_AW              -1 :0]         o_tile_base_addr_rgba_y1        ,
    output  wire    [AXI_AW              -1 :0]         o_tile_base_addr_uv1            ,

    output  wire                                        o_vivo_ubwc_en                  ,
    output  wire                                        o_vivo_sreset                   ,

    output  wire                                        o_frame_start_pulse_axi         ,
    output  wire                                        o_meta_start_pulse_axi          ,
    output  wire    [4                      :0]         o_meta_base_format              ,
    output  wire    [AXI_AW              -1 :0]         o_meta_base_addr_rgba_y0        ,
    output  wire    [AXI_AW              -1 :0]         o_meta_base_addr_uv0            ,
    output  wire    [AXI_AW              -1 :0]         o_meta_base_addr_rgba_y1        ,
    output  wire    [AXI_AW              -1 :0]         o_meta_base_addr_uv1            ,
    output  wire    [15                     :0]         o_meta_tile_x_numbers           ,
    output  wire    [15                     :0]         o_meta_tile_y_numbers           ,

    output  wire    [15                     :0]         o_otf_cfg_img_width             ,
    output  wire    [4                      :0]         o_otf_cfg_format                ,
    output  wire    [15                     :0]         o_otf_cfg_h_total               ,
    output  wire    [15                     :0]         o_otf_cfg_h_sync                ,
    output  wire    [15                     :0]         o_otf_cfg_h_bp                  ,
    output  wire    [15                     :0]         o_otf_cfg_h_act                 ,
    output  wire    [15                     :0]         o_otf_cfg_v_total               ,
    output  wire    [15                     :0]         o_otf_cfg_v_sync                ,
    output  wire    [15                     :0]         o_otf_cfg_v_bp                  ,
    output  wire    [15                     :0]         o_otf_cfg_v_act                 ,

    output  wire                                        o_irq_enable_axi                ,
    output  wire                                        o_irq_clear_pulse_axi
);

    localparam  [DW                  -1 :0]         REG_VERSION                     = 32'h0001_0000;
    localparam  [DW                  -1 :0]         REG_DATE                        = 32'h2026_0403;

    localparam  [4                      :0]         APB_ADDR_VERSION                = 5'h00; // 0x00
    localparam  [4                      :0]         APB_ADDR_DATE                   = 5'h01; // 0x04
    localparam  [4                      :0]         APB_ADDR_TILE_CFG0              = 5'h02; // 0x08
    localparam  [4                      :0]         APB_ADDR_TILE_CFG1              = 5'h03; // 0x0c
    localparam  [4                      :0]         APB_ADDR_TILE_CFG2              = 5'h04; // 0x10
    localparam  [4                      :0]         APB_ADDR_VIVO_CFG               = 5'h05; // 0x14
    localparam  [4                      :0]         APB_ADDR_OTF_CFG0               = 5'h06; // 0x18
    localparam  [4                      :0]         APB_ADDR_OTF_CFG1               = 5'h07; // 0x1c
    localparam  [4                      :0]         APB_ADDR_OTF_CFG2               = 5'h08; // 0x20
    localparam  [4                      :0]         APB_ADDR_OTF_CFG3               = 5'h09; // 0x24
    localparam  [4                      :0]         APB_ADDR_OTF_CFG4               = 5'h0a; // 0x28
    localparam  [4                      :0]         APB_ADDR_META_CFG0              = 5'h0b; // 0x2c
    localparam  [4                      :0]         REG_META_BASE_Y_LO              = 5'h0c; // 0x30
    localparam  [4                      :0]         REG_META_BASE_Y_HI              = 5'h0d; // 0x34
    localparam  [4                      :0]         REG_TILE_BASE_Y_LO              = 5'h0e; // 0x38
    localparam  [4                      :0]         REG_TILE_BASE_Y_HI              = 5'h0f; // 0x3c
    localparam  [4                      :0]         REG_META_BASE_UV_LO             = 5'h10; // 0x40
    localparam  [4                      :0]         REG_META_BASE_UV_HI             = 5'h11; // 0x44
    localparam  [4                      :0]         REG_TILE_BASE_UV_LO             = 5'h12; // 0x48
    localparam  [4                      :0]         REG_TILE_BASE_UV_HI             = 5'h13; // 0x4c
    localparam  [4                      :0]         APB_ADDR_STATUS0                = 5'h14; // 0x50
    localparam  [4                      :0]         APB_ADDR_STATUS1                = 5'h15; // 0x54
    localparam  [4                      :0]         APB_ADDR_STATUS2                = 5'h16; // 0x58
    localparam  [4                      :0]         APB_ADDR_STATUS3                = 5'h17; // 0x5c
    localparam  [4                      :0]         APB_ADDR_IRQ_CTRL               = 5'h18; // 0x60
    localparam  [4                      :0]         APB_ADDR_STATUS4                = 5'h19; // 0x64
    localparam  [4                      :0]         APB_ADDR_STAT_META              = 5'h1a; // 0x68
    localparam  [4                      :0]         APB_ADDR_STAT_TILE              = 5'h1b; // 0x6c
    localparam  [4                      :0]         APB_ADDR_STAT_OTF_TILE          = 5'h1c; // 0x70
    localparam  [4                      :0]         APB_ADDR_STAT_OTF_LINE          = 5'h1d; // 0x74
    localparam  [4                      :0]         APB_ADDR_STAT_OTF_DE            = 5'h1e; // 0x78
    localparam  integer                             IRQ_CTRL_START_BIT              = 5;
    localparam  integer                             STATUS_BUS_W                    = 24;
    localparam  integer                             BASE_FIFO_DEPTH                 = 4;
    localparam  integer                             BASE_FIFO_PTR_W                 = 2;
    localparam  integer                             BASE_FIFO_CNT_W                 = 3;
    localparam  [BASE_FIFO_CNT_W     -1 :0]         BASE_FIFO_DEPTH_COUNT           = 3'd4;

    reg                                             r_tile_cfg_lvl1_bank_swizzle_en ;
    reg                                             r_tile_cfg_lvl2_bank_swizzle_en ;
    reg                                             r_tile_cfg_lvl3_bank_swizzle_en ;
    reg         [4                      :0]         r_tile_cfg_highest_bank_bit     ;
    reg                                             r_tile_cfg_bank_spread_en       ;
    reg                                             r_tile_cfg_4line_format         ;
    reg                                             r_tile_cfg_is_lossy_rgba_2_1_format;
    reg         [11                     :0]         r_tile_cfg_pitch                ;
    reg                                             r_tile_cfg_ci_input_type        ;
    reg                                             r_tile_cfg_ci_lossy             ;
    reg         [1                      :0]         r_tile_cfg_ci_alpha_mode        ;
    reg         [3                      :0]         r_tile_cfg_ubwc_ver             ;
    reg         [AXI_AW              -1 :0]         r_tile_base_addr_rgba_y         ;
    reg         [AXI_AW              -1 :0]         r_tile_base_addr_uv             ;
    reg         [AXI_AW              -1 :0]         r_tile_base_addr_rgba_y0        ;
    reg         [AXI_AW              -1 :0]         r_tile_base_addr_uv0            ;
    reg         [AXI_AW              -1 :0]         r_meta_base_addr_rgba_y0        ;
    reg         [AXI_AW              -1 :0]         r_meta_base_addr_uv0            ;
    reg         [AXI_AW              -1 :0]         r_tile_base_addr_rgba_y1        ;
    reg         [AXI_AW              -1 :0]         r_tile_base_addr_uv1            ;
    reg         [AXI_AW              -1 :0]         r_meta_base_addr_rgba_y1        ;
    reg         [AXI_AW              -1 :0]         r_meta_base_addr_uv1            ;
    reg                                             r_base_addr_wr_slot             ;
    reg         [AXI_AW              -1 :0]         fifo_tile_base_addr_rgba_y [0:BASE_FIFO_DEPTH-1];
    reg         [AXI_AW              -1 :0]         fifo_tile_base_addr_uv       [0:BASE_FIFO_DEPTH-1];
    reg         [AXI_AW              -1 :0]         fifo_meta_base_addr_rgba_y  [0:BASE_FIFO_DEPTH-1];
    reg         [AXI_AW              -1 :0]         fifo_meta_base_addr_uv      [0:BASE_FIFO_DEPTH-1];
    reg         [BASE_FIFO_PTR_W     -1 :0]         fifo_tile_rgba_y_wr_ptr         ;
    reg         [BASE_FIFO_PTR_W     -1 :0]         fifo_tile_rgba_y_rd_ptr         ;
    reg         [BASE_FIFO_CNT_W     -1 :0]         fifo_tile_rgba_y_count          ;
    reg         [BASE_FIFO_PTR_W     -1 :0]         fifo_tile_uv_wr_ptr             ;
    reg         [BASE_FIFO_PTR_W     -1 :0]         fifo_tile_uv_rd_ptr             ;
    reg         [BASE_FIFO_CNT_W     -1 :0]         fifo_tile_uv_count              ;
    reg         [BASE_FIFO_PTR_W     -1 :0]         fifo_meta_y_wr_ptr              ;
    reg         [BASE_FIFO_PTR_W     -1 :0]         fifo_meta_y_rd_ptr              ;
    reg         [BASE_FIFO_CNT_W     -1 :0]         fifo_meta_y_count               ;
    reg         [BASE_FIFO_PTR_W     -1 :0]         fifo_meta_uv_wr_ptr             ;
    reg         [BASE_FIFO_PTR_W     -1 :0]         fifo_meta_uv_rd_ptr             ;
    reg         [BASE_FIFO_CNT_W     -1 :0]         fifo_meta_uv_count              ;
    reg                                             r_vivo_ubwc_en                  ;
    reg                                             r_vivo_sreset                   ;
    reg                                             r_meta_start_toggle             ;
    reg                                             r_start_wait_busy_seen          ;
    reg         [BASE_FIFO_CNT_W     -1 :0]         r_start_request_count           ;
    reg         [4                      :0]         r_meta_base_format              ;
    reg         [AXI_AW              -1 :0]         r_meta_base_addr_rgba_y         ;
    reg         [AXI_AW              -1 :0]         r_meta_base_addr_uv             ;
    reg         [4                      :0]         r_otf_cfg_format                ;
    reg         [15                     :0]         r_otf_cfg_h_total               ;
    reg         [15                     :0]         r_otf_cfg_h_sync                ;
    reg         [15                     :0]         r_otf_cfg_h_bp                  ;
    reg         [15                     :0]         r_otf_cfg_h_act                 ;
    reg         [15                     :0]         r_otf_cfg_v_total               ;
    reg         [15                     :0]         r_otf_cfg_v_sync                ;
    reg         [15                     :0]         r_otf_cfg_v_bp                  ;
    reg         [15                     :0]         r_otf_cfg_v_act                 ;
    reg                                             r_irq_enable                    ;
    reg                                             r_irq_clear_toggle              ;
    reg                                             r_meta_start_sync_ff1           ;
    reg                                             r_meta_start_sync_ff2           ;
    reg                                             r_frame_start_cfg_valid_axi     ;
    reg                                             r_frame_start_pulse_axi         ;
    reg                                             r_irq_enable_sync_ff1           ;
    reg                                             r_irq_enable_sync_ff2           ;
    reg                                             r_irq_clear_sync_ff1            ;
    reg                                             r_irq_clear_sync_ff2            ;
    reg         [STATUS_BUS_W        -1 :0]         r_status_sync_ff1               ;
    reg         [STATUS_BUS_W        -1 :0]         r_status_sync_ff2               ;
    reg         [1                      :0]         r_irq_type_sync_ff1             ;
    reg         [1                      :0]         r_irq_type_sync_ff2             ;
    reg         [31                     :0]         r_stat_meta_tile_sync_ff1       ;
    reg         [31                     :0]         r_stat_meta_tile_sync_ff2       ;
    reg         [31                     :0]         r_stat_tile_addr_sync_ff1       ;
    reg         [31                     :0]         r_stat_tile_addr_sync_ff2       ;
    reg         [31                     :0]         r_stat_otf_tile_sync_ff1        ;
    reg         [31                     :0]         r_stat_otf_tile_sync_ff2        ;
    reg         [31                     :0]         r_stat_otf_line_sync_ff1        ;
    reg         [31                     :0]         r_stat_otf_line_sync_ff2        ;
    reg         [31                     :0]         r_stat_otf_de_sync_ff1          ;
    reg         [31                     :0]         r_stat_otf_de_sync_ff2          ;

    reg                                             a_tile_cfg_lvl2_bank_swizzle_en ;
    reg                                             a_tile_cfg_lvl3_bank_swizzle_en ;
    reg         [4                      :0]         a_tile_cfg_highest_bank_bit     ;
    reg                                             a_tile_cfg_bank_spread_en       ;
    reg                                             a_tile_cfg_is_lossy_rgba_2_1_format;
    reg         [11                     :0]         a_tile_cfg_pitch                ;
    reg                                             a_tile_cfg_ci_input_type        ;
    reg                                             a_tile_cfg_ci_lossy             ;
    reg         [1                      :0]         a_tile_cfg_ci_alpha_mode        ;
    reg         [3                      :0]         a_tile_cfg_ubwc_ver             ;
    reg         [AXI_AW              -1 :0]         a_tile_base_addr_rgba_y0        ;
    reg         [AXI_AW              -1 :0]         a_tile_base_addr_uv0            ;
    reg         [AXI_AW              -1 :0]         a_tile_base_addr_rgba_y1        ;
    reg         [AXI_AW              -1 :0]         a_tile_base_addr_uv1            ;
    reg                                             a_vivo_ubwc_en                  ;
    reg                                             a_vivo_sreset                   ;
    reg         [4                      :0]         a_meta_base_format              ;
    reg         [AXI_AW              -1 :0]         a_meta_base_addr_rgba_y0        ;
    reg         [AXI_AW              -1 :0]         a_meta_base_addr_uv0            ;
    reg         [AXI_AW              -1 :0]         a_meta_base_addr_rgba_y1        ;
    reg         [AXI_AW              -1 :0]         a_meta_base_addr_uv1            ;
    reg         [15                     :0]         a_meta_tile_x_numbers           ;
    reg         [15                     :0]         a_meta_tile_y_numbers           ;
    reg         [4                      :0]         a_otf_cfg_format                ;
    reg         [15                     :0]         a_otf_cfg_h_total               ;
    reg         [15                     :0]         a_otf_cfg_h_sync                ;
    reg         [15                     :0]         a_otf_cfg_h_bp                  ;
    reg         [15                     :0]         a_otf_cfg_h_act                 ;
    reg         [15                     :0]         a_otf_cfg_v_total               ;
    reg         [15                     :0]         a_otf_cfg_v_sync                ;
    reg         [15                     :0]         a_otf_cfg_v_bp                  ;
    reg         [15                     :0]         a_otf_cfg_v_act                 ;
    reg         [DW                  -1 :0]         r_prdata                        ;

    wire                                            apb_access                      ;
    assign apb_access = PSEL && PENABLE;
    wire                                            apb_addr_aligned                ;
    assign apb_addr_aligned = (PADDR[1:0] == 2'b00);
    wire                                            apb_addr_in_rng                 ;
    assign apb_addr_in_rng = (PADDR[AW-1:7] == {(AW-7){1'b0}});
    wire                                            apb_decode_valid                ;
    assign apb_decode_valid = apb_addr_aligned && apb_addr_in_rng;
    wire        [4                      :0]         apb_addr                        ;
    assign apb_addr = PADDR[6:2];
    wire                                            fifo_tile_rgba_y_full           ;
    assign fifo_tile_rgba_y_full = (fifo_tile_rgba_y_count == BASE_FIFO_DEPTH_COUNT);
    wire                                            fifo_tile_uv_full               ;
    assign fifo_tile_uv_full = (fifo_tile_uv_count  == BASE_FIFO_DEPTH_COUNT);
    wire                                            fifo_meta_y_full                ;
    assign fifo_meta_y_full = (fifo_meta_y_count  == BASE_FIFO_DEPTH_COUNT);
    wire                                            fifo_meta_uv_full               ;
    assign fifo_meta_uv_full = (fifo_meta_uv_count == BASE_FIFO_DEPTH_COUNT);
    wire                                            fifo_tile_rgba_y_empty          ;
    assign fifo_tile_rgba_y_empty = (fifo_tile_rgba_y_count == {BASE_FIFO_CNT_W{1'b0}});
    wire                                            fifo_tile_uv_empty              ;
    assign fifo_tile_uv_empty = (fifo_tile_uv_count  == {BASE_FIFO_CNT_W{1'b0}});
    wire                                            fifo_meta_y_empty               ;
    assign fifo_meta_y_empty = (fifo_meta_y_count  == {BASE_FIFO_CNT_W{1'b0}});
    wire                                            fifo_meta_uv_empty              ;
    assign fifo_meta_uv_empty = (fifo_meta_uv_count == {BASE_FIFO_CNT_W{1'b0}});
    wire                                            base_fifo_low_write             ;
    assign base_fifo_low_write = (apb_addr == REG_TILE_BASE_Y_LO)  ||
               (apb_addr == REG_TILE_BASE_UV_LO) ||
               (apb_addr == REG_META_BASE_Y_LO)  ||
               (apb_addr == REG_META_BASE_UV_LO);
    wire                                            base_fifo_high_write            ;
    assign base_fifo_high_write = (apb_addr == REG_TILE_BASE_Y_HI)  ||
               (apb_addr == REG_TILE_BASE_UV_HI) ||
               (apb_addr == REG_META_BASE_Y_HI)  ||
               (apb_addr == REG_META_BASE_UV_HI);
    wire                                            base_fifo_addr_write            ;
    assign base_fifo_addr_write = base_fifo_low_write || base_fifo_high_write;
    wire                                            base_fifo_write_full            ;
    assign base_fifo_write_full = (((apb_addr == REG_TILE_BASE_Y_LO)  ||
                                    (apb_addr == REG_TILE_BASE_Y_HI))  && fifo_tile_rgba_y_full) ||
                                  (((apb_addr == REG_TILE_BASE_UV_LO) ||
                                    (apb_addr == REG_TILE_BASE_UV_HI)) && fifo_tile_uv_full)      ||
                                  (((apb_addr == REG_META_BASE_Y_LO)  ||
                                    (apb_addr == REG_META_BASE_Y_HI))  && fifo_meta_y_full)       ||
                                  (((apb_addr == REG_META_BASE_UV_LO) ||
                                    (apb_addr == REG_META_BASE_UV_HI)) && fifo_meta_uv_full);
    wire                                            frame_start_toggle_seen_axi     ;
    assign frame_start_toggle_seen_axi = r_meta_start_sync_ff1 ^ r_meta_start_sync_ff2;
    wire        [STATUS_BUS_W        -1 :0]         status_bus_axi                  ;
    wire        [6                      :0]         status_vivo_error_pclk          ;
    wire                                            status_vivo_idle_pclk           ;
    wire        [4                      :0]         status_stage_done_pclk          ;
    wire        [3                      :0]         status_stage_seen_pclk          ;
    wire                                            status_meta_busy_pclk           ;
    wire                                            status_tile_busy_pclk           ;
    wire                                            status_vivo_busy_pclk           ;
    wire                                            status_otf_busy_pclk            ;
    wire                                            status_frame_active_pclk        ;
    wire                                            status_any_stage_busy_pclk      ;
    wire                                            status_irq_pending_pclk         ;
    wire                                            status_irq_correct_pending_pclk ;
    wire                                            status_irq_error_pending_pclk   ;
    wire                                            base_fifo_all_valid_pclk        ;
    assign base_fifo_all_valid_pclk = !fifo_tile_rgba_y_empty && !fifo_tile_uv_empty &&
                                          !fifo_meta_y_empty && !fifo_meta_uv_empty;
    wire                                            meta_launch_slot_free_pclk      ;
    assign meta_launch_slot_free_pclk = !status_frame_active_pclk ||
                                            status_stage_done_pclk[0];
    wire                                            base_fifo_stall                 ;
    assign base_fifo_stall = apb_access &&
                              PWRITE &&
                              apb_decode_valid &&
                              base_fifo_addr_write &&
                              base_fifo_write_full;
    wire                                            apb_write                       ;
    assign apb_write = apb_access && PWRITE && apb_decode_valid && !base_fifo_stall;
    wire                                            start_request_pclk              ;
    assign start_request_pclk = apb_write &&
                                (apb_addr == APB_ADDR_IRQ_CTRL) &&
                                PWDATA[IRQ_CTRL_START_BIT];
    wire                                            start_request_full_pclk         ;
    assign start_request_full_pclk = (r_start_request_count == BASE_FIFO_DEPTH_COUNT);
    wire                                            start_request_push_pclk         ;
    assign start_request_push_pclk = start_request_pclk && !start_request_full_pclk;
    wire                                            start_request_available_pclk    ;
    assign start_request_available_pclk = (r_start_request_count != {BASE_FIFO_CNT_W{1'b0}}) ||
                                          start_request_push_pclk;
    wire                                            base_fifo_start_pclk            ;
    assign base_fifo_start_pclk = start_request_available_pclk &&
                                  base_fifo_all_valid_pclk &&
                                  !r_start_wait_busy_seen &&
                                  !status_meta_busy_pclk &&
                                  meta_launch_slot_free_pclk;
    wire                                            push_tile_rgba_y_fifo           ;
    assign push_tile_rgba_y_fifo = apb_write && (apb_addr == REG_TILE_BASE_Y_HI);
    wire                                            push_tile_uv_fifo               ;
    assign push_tile_uv_fifo = apb_write && (apb_addr == REG_TILE_BASE_UV_HI);
    wire                                            push_meta_y_fifo                ;
    assign push_meta_y_fifo = apb_write && (apb_addr == REG_META_BASE_Y_HI);
    wire                                            push_meta_uv_fifo               ;
    assign push_meta_uv_fifo = apb_write && (apb_addr == REG_META_BASE_UV_HI);
    wire                                            cfg_format_is_rgba              ;
    assign cfg_format_is_rgba = (r_otf_cfg_format == 5'b00000) ||
                                (r_otf_cfg_format == 5'b00001);
    wire                                            cfg_format_is_nv12              ;
    assign cfg_format_is_nv12 = (r_otf_cfg_format == 5'b00010);
    wire        [17                     :0]         cfg_h_act_ext                  ;
    assign cfg_h_act_ext = {2'b00, r_otf_cfg_h_act};
    wire        [17                     :0]         cfg_v_act_ext                  ;
    assign cfg_v_act_ext = {2'b00, r_otf_cfg_v_act};
    wire        [17                     :0]         cfg_tile_x_rgba_ext            ;
    assign cfg_tile_x_rgba_ext = ((cfg_h_act_ext + 18'd63) >> 6) << 2;
    wire        [17                     :0]         cfg_tile_x_yuv_ext             ;
    assign cfg_tile_x_yuv_ext = ((cfg_h_act_ext + 18'd127) >> 7) << 2;
    wire        [17                     :0]         cfg_tile_y_4line_ext           ;
    assign cfg_tile_y_4line_ext = (cfg_v_act_ext + 18'd3) >> 2;
    wire        [17                     :0]         cfg_tile_y_8line_ext           ;
    assign cfg_tile_y_8line_ext = (cfg_v_act_ext + 18'd7) >> 3;
    wire        [15                     :0]         cfg_meta_tile_x_numbers        ;
    assign cfg_meta_tile_x_numbers = cfg_format_is_rgba ? cfg_tile_x_rgba_ext[15:0] :
                                                          cfg_tile_x_yuv_ext[15:0];
    wire        [15                     :0]         cfg_meta_tile_y_numbers        ;
    assign cfg_meta_tile_y_numbers = cfg_format_is_nv12 ? cfg_tile_y_8line_ext[15:0] :
                                                         cfg_tile_y_4line_ext[15:0];

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            r_tile_cfg_lvl1_bank_swizzle_en     <= 1'b0;
            r_tile_cfg_lvl2_bank_swizzle_en     <= 1'b0;
            r_tile_cfg_lvl3_bank_swizzle_en     <= 1'b0;
            r_tile_cfg_highest_bank_bit         <= 5'd0;
            r_tile_cfg_bank_spread_en           <= 1'b0;
            r_tile_cfg_4line_format             <= 1'b0;
            r_tile_cfg_is_lossy_rgba_2_1_format <= 1'b0;
            r_tile_cfg_pitch                    <= 12'd0;
            r_tile_cfg_ci_input_type            <= 1'b0;
            r_tile_cfg_ci_lossy                 <= 1'b0;
            r_tile_cfg_ci_alpha_mode            <= 2'd0;
            r_tile_cfg_ubwc_ver                 <= 4'd7;
            r_tile_base_addr_rgba_y            <= {AXI_AW{1'b0}};
            r_tile_base_addr_uv                  <= {AXI_AW{1'b0}};
            r_tile_base_addr_rgba_y0           <= {AXI_AW{1'b0}};
            r_tile_base_addr_uv0                 <= {AXI_AW{1'b0}};
            r_meta_base_addr_rgba_y0            <= {AXI_AW{1'b0}};
            r_meta_base_addr_uv0                <= {AXI_AW{1'b0}};
            r_tile_base_addr_rgba_y1           <= {AXI_AW{1'b0}};
            r_tile_base_addr_uv1                 <= {AXI_AW{1'b0}};
            r_meta_base_addr_rgba_y1            <= {AXI_AW{1'b0}};
            r_meta_base_addr_uv1                <= {AXI_AW{1'b0}};
            r_base_addr_wr_slot                 <= 1'b0;
            fifo_tile_rgba_y_wr_ptr                 <= {BASE_FIFO_PTR_W{1'b0}};
            fifo_tile_rgba_y_rd_ptr                 <= {BASE_FIFO_PTR_W{1'b0}};
            fifo_tile_rgba_y_count                  <= {BASE_FIFO_CNT_W{1'b0}};
            fifo_tile_uv_wr_ptr                  <= {BASE_FIFO_PTR_W{1'b0}};
            fifo_tile_uv_rd_ptr                  <= {BASE_FIFO_PTR_W{1'b0}};
            fifo_tile_uv_count                   <= {BASE_FIFO_CNT_W{1'b0}};
            fifo_meta_y_wr_ptr                  <= {BASE_FIFO_PTR_W{1'b0}};
            fifo_meta_y_rd_ptr                  <= {BASE_FIFO_PTR_W{1'b0}};
            fifo_meta_y_count                   <= {BASE_FIFO_CNT_W{1'b0}};
            fifo_meta_uv_wr_ptr                 <= {BASE_FIFO_PTR_W{1'b0}};
            fifo_meta_uv_rd_ptr                 <= {BASE_FIFO_PTR_W{1'b0}};
            fifo_meta_uv_count                  <= {BASE_FIFO_CNT_W{1'b0}};
            r_vivo_ubwc_en                      <= 1'b0;
            r_vivo_sreset                       <= 1'b0;
            r_meta_start_toggle                 <= 1'b0;
            r_start_wait_busy_seen              <= 1'b0;
            r_start_request_count               <= {BASE_FIFO_CNT_W{1'b0}};
            r_meta_base_format                  <= 5'd0;
            r_meta_base_addr_rgba_y             <= {AXI_AW{1'b0}};
            r_meta_base_addr_uv                 <= {AXI_AW{1'b0}};
            r_otf_cfg_format                    <= 5'd0;
            r_otf_cfg_h_total                   <= 16'd0;
            r_otf_cfg_h_sync                    <= 16'd0;
            r_otf_cfg_h_bp                      <= 16'd0;
            r_otf_cfg_h_act                     <= 16'd0;
            r_otf_cfg_v_total                   <= 16'd0;
            r_otf_cfg_v_sync                    <= 16'd0;
            r_otf_cfg_v_bp                      <= 16'd0;
            r_otf_cfg_v_act                     <= 16'd0;
            r_irq_enable                        <= 1'b0;
            r_irq_clear_toggle                  <= 1'b0;
        end else begin
            if (base_fifo_start_pclk) begin
                if (r_base_addr_wr_slot) begin
                    r_tile_base_addr_rgba_y1 <= fifo_tile_base_addr_rgba_y[fifo_tile_rgba_y_rd_ptr];
                    r_tile_base_addr_uv1       <= fifo_tile_base_addr_uv[fifo_tile_uv_rd_ptr];
                    r_meta_base_addr_rgba_y1  <= fifo_meta_base_addr_rgba_y[fifo_meta_y_rd_ptr];
                    r_meta_base_addr_uv1      <= fifo_meta_base_addr_uv[fifo_meta_uv_rd_ptr];
                end else begin
                    r_tile_base_addr_rgba_y0 <= fifo_tile_base_addr_rgba_y[fifo_tile_rgba_y_rd_ptr];
                    r_tile_base_addr_uv0       <= fifo_tile_base_addr_uv[fifo_tile_uv_rd_ptr];
                    r_meta_base_addr_rgba_y0  <= fifo_meta_base_addr_rgba_y[fifo_meta_y_rd_ptr];
                    r_meta_base_addr_uv0      <= fifo_meta_base_addr_uv[fifo_meta_uv_rd_ptr];
                end
                fifo_tile_rgba_y_rd_ptr      <= fifo_tile_rgba_y_rd_ptr + 1'b1;
                fifo_tile_uv_rd_ptr       <= fifo_tile_uv_rd_ptr + 1'b1;
                fifo_meta_y_rd_ptr       <= fifo_meta_y_rd_ptr + 1'b1;
                fifo_meta_uv_rd_ptr      <= fifo_meta_uv_rd_ptr + 1'b1;
                r_base_addr_wr_slot      <= ~r_base_addr_wr_slot;
                r_meta_start_toggle      <= ~r_meta_start_toggle;
                r_start_wait_busy_seen   <= 1'b1;
            end else if (status_meta_busy_pclk || status_stage_done_pclk[0]) begin
                r_start_wait_busy_seen   <= 1'b0;
            end

            case ({start_request_push_pclk, base_fifo_start_pclk})
                2'b10: r_start_request_count <= r_start_request_count + 1'b1;
                2'b01: r_start_request_count <= r_start_request_count - 1'b1;
                default: r_start_request_count <= r_start_request_count;
            endcase

            if (push_tile_rgba_y_fifo) begin
                fifo_tile_base_addr_rgba_y[fifo_tile_rgba_y_wr_ptr] <= {PWDATA[AXI_AW-33:0], r_tile_base_addr_rgba_y[31:0]};
                fifo_tile_rgba_y_wr_ptr <= fifo_tile_rgba_y_wr_ptr + 1'b1;
            end
            case ({push_tile_rgba_y_fifo, base_fifo_start_pclk})
                2'b10: fifo_tile_rgba_y_count <= fifo_tile_rgba_y_count + 1'b1;
                2'b01: fifo_tile_rgba_y_count <= fifo_tile_rgba_y_count - 1'b1;
                default: fifo_tile_rgba_y_count <= fifo_tile_rgba_y_count;
            endcase

            if (push_tile_uv_fifo) begin
                fifo_tile_base_addr_uv[fifo_tile_uv_wr_ptr] <= {PWDATA[AXI_AW-33:0], r_tile_base_addr_uv[31:0]};
                fifo_tile_uv_wr_ptr <= fifo_tile_uv_wr_ptr + 1'b1;
            end
            case ({push_tile_uv_fifo, base_fifo_start_pclk})
                2'b10: fifo_tile_uv_count <= fifo_tile_uv_count + 1'b1;
                2'b01: fifo_tile_uv_count <= fifo_tile_uv_count - 1'b1;
                default: fifo_tile_uv_count <= fifo_tile_uv_count;
            endcase

            if (push_meta_y_fifo) begin
                fifo_meta_base_addr_rgba_y[fifo_meta_y_wr_ptr] <= {PWDATA[AXI_AW-33:0], r_meta_base_addr_rgba_y[31:0]};
                fifo_meta_y_wr_ptr <= fifo_meta_y_wr_ptr + 1'b1;
            end
            case ({push_meta_y_fifo, base_fifo_start_pclk})
                2'b10: fifo_meta_y_count <= fifo_meta_y_count + 1'b1;
                2'b01: fifo_meta_y_count <= fifo_meta_y_count - 1'b1;
                default: fifo_meta_y_count <= fifo_meta_y_count;
            endcase

            if (push_meta_uv_fifo) begin
                fifo_meta_base_addr_uv[fifo_meta_uv_wr_ptr] <= {PWDATA[AXI_AW-33:0], r_meta_base_addr_uv[31:0]};
                fifo_meta_uv_wr_ptr <= fifo_meta_uv_wr_ptr + 1'b1;
            end
            case ({push_meta_uv_fifo, base_fifo_start_pclk})
                2'b10: fifo_meta_uv_count <= fifo_meta_uv_count + 1'b1;
                2'b01: fifo_meta_uv_count <= fifo_meta_uv_count - 1'b1;
                default: fifo_meta_uv_count <= fifo_meta_uv_count;
            endcase

            if (apb_write) begin
                case (apb_addr)
                APB_ADDR_TILE_CFG0: begin
                    r_tile_cfg_lvl1_bank_swizzle_en     <= PWDATA[0];
                    r_tile_cfg_lvl2_bank_swizzle_en     <= PWDATA[1];
                    r_tile_cfg_lvl3_bank_swizzle_en     <= PWDATA[2];
                    r_tile_cfg_highest_bank_bit         <= PWDATA[8:4];
                    r_tile_cfg_bank_spread_en           <= PWDATA[9];
                    r_tile_cfg_4line_format             <= PWDATA[10];
                    r_tile_cfg_is_lossy_rgba_2_1_format <= PWDATA[11];
                    r_tile_cfg_ubwc_ver                 <= PWDATA[16 +: 4];
                end
                APB_ADDR_TILE_CFG1: begin
                    r_tile_cfg_pitch <= PWDATA[11:0];
                end
                APB_ADDR_TILE_CFG2: begin
                    r_tile_cfg_ci_input_type <= PWDATA[0];
                    r_tile_cfg_ci_lossy      <= PWDATA[8];
                    r_tile_cfg_ci_alpha_mode <= PWDATA[10:9];
                end
                REG_TILE_BASE_Y_LO: begin
                    r_tile_base_addr_rgba_y[31:0] <= PWDATA;
                end
                REG_TILE_BASE_Y_HI: begin
                    r_tile_base_addr_rgba_y[AXI_AW-1:32] <= PWDATA[AXI_AW-33:0];
                end
                REG_TILE_BASE_UV_LO: begin
                    r_tile_base_addr_uv[31:0] <= PWDATA;
                end
                REG_TILE_BASE_UV_HI: begin
                    r_tile_base_addr_uv[AXI_AW-1:32] <= PWDATA[AXI_AW-33:0];
                end
                APB_ADDR_VIVO_CFG: begin
                    r_vivo_ubwc_en <= PWDATA[0];
                    r_vivo_sreset  <= PWDATA[1];
                end
                REG_META_BASE_Y_LO: begin
                    r_meta_base_addr_rgba_y[31:0] <= PWDATA;
                end
                REG_META_BASE_Y_HI: begin
                    r_meta_base_addr_rgba_y[AXI_AW-1:32] <= PWDATA[AXI_AW-33:0];
                end
                REG_META_BASE_UV_LO: begin
                    r_meta_base_addr_uv[31:0] <= PWDATA;
                end
                REG_META_BASE_UV_HI: begin
                    r_meta_base_addr_uv[AXI_AW-1:32] <= PWDATA[AXI_AW-33:0];
                end
                APB_ADDR_META_CFG0: begin
                end
                APB_ADDR_OTF_CFG0: begin
                    r_otf_cfg_format    <= PWDATA[20:16];
                    r_meta_base_format  <= PWDATA[20:16];
                end
                APB_ADDR_OTF_CFG1: begin
                    r_otf_cfg_h_total <= PWDATA[15:0];
                    r_otf_cfg_h_sync  <= PWDATA[31:16];
                end
                APB_ADDR_OTF_CFG2: begin
                    r_otf_cfg_h_bp  <= PWDATA[15:0];
                    r_otf_cfg_h_act <= PWDATA[31:16];
                end
                APB_ADDR_OTF_CFG3: begin
                    r_otf_cfg_v_total <= PWDATA[15:0];
                    r_otf_cfg_v_sync  <= PWDATA[31:16];
                end
                APB_ADDR_OTF_CFG4: begin
                    r_otf_cfg_v_bp  <= PWDATA[15:0];
                    r_otf_cfg_v_act <= PWDATA[31:16];
                end
                APB_ADDR_IRQ_CTRL: begin
                    r_irq_enable <= PWDATA[0];
                    if (PWDATA[1]) begin
                        r_irq_clear_toggle <= ~r_irq_clear_toggle;
                    end
                end
                default: begin
                end
                endcase
            end
        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rst_n) begin
        if (!i_axi_rst_n) begin
            r_meta_start_sync_ff1 <= 1'b0;
            r_meta_start_sync_ff2 <= 1'b0;
            r_frame_start_cfg_valid_axi <= 1'b0;
            r_frame_start_pulse_axi <= 1'b0;
            r_irq_enable_sync_ff1 <= 1'b0;
            r_irq_enable_sync_ff2 <= 1'b0;
            r_irq_clear_sync_ff1 <= 1'b0;
            r_irq_clear_sync_ff2 <= 1'b0;
            a_tile_cfg_lvl2_bank_swizzle_en <= 1'b0;
            a_tile_cfg_lvl3_bank_swizzle_en <= 1'b0;
            a_tile_cfg_highest_bank_bit <= 5'd0;
            a_tile_cfg_bank_spread_en <= 1'b0;
            a_tile_cfg_is_lossy_rgba_2_1_format <= 1'b0;
            a_tile_cfg_pitch <= 12'd0;
            a_tile_cfg_ci_input_type <= 1'b0;
            a_tile_cfg_ci_lossy <= 1'b0;
            a_tile_cfg_ci_alpha_mode <= 2'd0;
            a_tile_cfg_ubwc_ver <= 4'd7;
            a_tile_base_addr_rgba_y0 <= {AXI_AW{1'b0}};
            a_tile_base_addr_uv0 <= {AXI_AW{1'b0}};
            a_tile_base_addr_rgba_y1 <= {AXI_AW{1'b0}};
            a_tile_base_addr_uv1 <= {AXI_AW{1'b0}};
            a_vivo_ubwc_en <= 1'b0;
            a_vivo_sreset <= 1'b0;
            a_meta_base_format <= 5'd0;
            a_meta_base_addr_rgba_y0 <= {AXI_AW{1'b0}};
            a_meta_base_addr_uv0 <= {AXI_AW{1'b0}};
            a_meta_base_addr_rgba_y1 <= {AXI_AW{1'b0}};
            a_meta_base_addr_uv1 <= {AXI_AW{1'b0}};
            a_meta_tile_x_numbers <= 16'd0;
            a_meta_tile_y_numbers <= 16'd0;
            a_otf_cfg_format <= 5'd0;
            a_otf_cfg_h_total <= 16'd0;
            a_otf_cfg_h_sync <= 16'd0;
            a_otf_cfg_h_bp <= 16'd0;
            a_otf_cfg_h_act <= 16'd0;
            a_otf_cfg_v_total <= 16'd0;
            a_otf_cfg_v_sync <= 16'd0;
            a_otf_cfg_v_bp <= 16'd0;
            a_otf_cfg_v_act <= 16'd0;
        end else begin
            r_meta_start_sync_ff1 <= r_meta_start_toggle;
            r_meta_start_sync_ff2 <= r_meta_start_sync_ff1;
            r_frame_start_cfg_valid_axi <= frame_start_toggle_seen_axi;
            r_frame_start_pulse_axi <= r_frame_start_cfg_valid_axi;
            r_irq_enable_sync_ff1 <= r_irq_enable;
            r_irq_enable_sync_ff2 <= r_irq_enable_sync_ff1;
            r_irq_clear_sync_ff1 <= r_irq_clear_toggle;
            r_irq_clear_sync_ff2 <= r_irq_clear_sync_ff1;

            if (frame_start_toggle_seen_axi) begin
                a_tile_cfg_lvl2_bank_swizzle_en <= r_tile_cfg_lvl2_bank_swizzle_en;
                a_tile_cfg_lvl3_bank_swizzle_en <= r_tile_cfg_lvl3_bank_swizzle_en;
                a_tile_cfg_highest_bank_bit <= r_tile_cfg_highest_bank_bit;
                a_tile_cfg_bank_spread_en <= r_tile_cfg_bank_spread_en;
                a_tile_cfg_is_lossy_rgba_2_1_format <= r_tile_cfg_is_lossy_rgba_2_1_format;
                a_tile_cfg_pitch <= r_tile_cfg_pitch;
                a_tile_cfg_ci_input_type <= r_tile_cfg_ci_input_type;
                a_tile_cfg_ci_lossy <= r_tile_cfg_ci_lossy;
                a_tile_cfg_ci_alpha_mode <= r_tile_cfg_ci_alpha_mode;
                a_tile_cfg_ubwc_ver <= r_tile_cfg_ubwc_ver;
                a_tile_base_addr_rgba_y0 <= r_tile_base_addr_rgba_y0;
                a_tile_base_addr_uv0 <= r_tile_base_addr_uv0;
                a_tile_base_addr_rgba_y1 <= r_tile_base_addr_rgba_y1;
                a_tile_base_addr_uv1 <= r_tile_base_addr_uv1;
                a_vivo_ubwc_en <= r_vivo_ubwc_en;
                a_vivo_sreset <= r_vivo_sreset;
                a_meta_base_format <= r_meta_base_format;
                a_meta_base_addr_rgba_y0 <= r_meta_base_addr_rgba_y0;
                a_meta_base_addr_uv0 <= r_meta_base_addr_uv0;
                a_meta_base_addr_rgba_y1 <= r_meta_base_addr_rgba_y1;
                a_meta_base_addr_uv1 <= r_meta_base_addr_uv1;
                a_meta_tile_x_numbers <= cfg_meta_tile_x_numbers;
                a_meta_tile_y_numbers <= cfg_meta_tile_y_numbers;
                a_otf_cfg_format <= r_otf_cfg_format;
                a_otf_cfg_h_total <= r_otf_cfg_h_total;
                a_otf_cfg_h_sync <= r_otf_cfg_h_sync;
                a_otf_cfg_h_bp <= r_otf_cfg_h_bp;
                a_otf_cfg_h_act <= r_otf_cfg_h_act;
                a_otf_cfg_v_total <= r_otf_cfg_v_total;
                a_otf_cfg_v_sync <= r_otf_cfg_v_sync;
                a_otf_cfg_v_bp <= r_otf_cfg_v_bp;
                a_otf_cfg_v_act <= r_otf_cfg_v_act;
            end
        end
    end

    assign status_bus_axi = {i_irq_pending_axi,
                             i_any_stage_busy_axi,
                             i_frame_active_axi,
                             i_otf_busy_axi,
                             i_vivo_busy_axi,
                             i_tile_busy_axi,
                             i_meta_busy_axi,
                             i_stage_seen_axi,
                             i_stage_done_axi,
                             i_vivo_idle_axi,
                             i_vivo_error_axi};

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            r_status_sync_ff1 <= {STATUS_BUS_W{1'b0}};
            r_status_sync_ff2 <= {STATUS_BUS_W{1'b0}};
            r_irq_type_sync_ff1 <= 2'b00;
            r_irq_type_sync_ff2 <= 2'b00;
            r_stat_meta_tile_sync_ff1 <= 32'd0;
            r_stat_meta_tile_sync_ff2 <= 32'd0;
            r_stat_tile_addr_sync_ff1 <= 32'd0;
            r_stat_tile_addr_sync_ff2 <= 32'd0;
            r_stat_otf_tile_sync_ff1 <= 32'd0;
            r_stat_otf_tile_sync_ff2 <= 32'd0;
            r_stat_otf_line_sync_ff1 <= 32'd0;
            r_stat_otf_line_sync_ff2 <= 32'd0;
            r_stat_otf_de_sync_ff1 <= 32'd0;
            r_stat_otf_de_sync_ff2 <= 32'd0;
        end else begin
            r_status_sync_ff1 <= status_bus_axi;
            r_status_sync_ff2 <= r_status_sync_ff1;
            r_irq_type_sync_ff1 <= {i_irq_correct_pending_axi, i_irq_error_pending_axi};
            r_irq_type_sync_ff2 <= r_irq_type_sync_ff1;
            r_stat_meta_tile_sync_ff1 <= i_stat_meta_tile_cnt_axi;
            r_stat_meta_tile_sync_ff2 <= r_stat_meta_tile_sync_ff1;
            r_stat_tile_addr_sync_ff1 <= i_stat_tile_addr_cnt_axi;
            r_stat_tile_addr_sync_ff2 <= r_stat_tile_addr_sync_ff1;
            r_stat_otf_tile_sync_ff1 <= i_stat_otf_tile_cnt_axi;
            r_stat_otf_tile_sync_ff2 <= r_stat_otf_tile_sync_ff1;
            r_stat_otf_line_sync_ff1 <= i_stat_otf_line_cnt_axi;
            r_stat_otf_line_sync_ff2 <= r_stat_otf_line_sync_ff1;
            r_stat_otf_de_sync_ff1 <= i_stat_otf_de_cnt_axi;
            r_stat_otf_de_sync_ff2 <= r_stat_otf_de_sync_ff1;
        end
    end

    assign status_vivo_error_pclk      = r_status_sync_ff2[6:0];
    assign status_vivo_idle_pclk       = r_status_sync_ff2[7];
    assign status_stage_done_pclk      = r_status_sync_ff2[12:8];
    assign status_stage_seen_pclk      = r_status_sync_ff2[16:13];
    assign status_meta_busy_pclk       = r_status_sync_ff2[17];
    assign status_tile_busy_pclk       = r_status_sync_ff2[18];
    assign status_vivo_busy_pclk       = r_status_sync_ff2[19];
    assign status_otf_busy_pclk        = r_status_sync_ff2[20];
    assign status_frame_active_pclk    = r_status_sync_ff2[21];
    assign status_any_stage_busy_pclk  = r_status_sync_ff2[22];
    assign status_irq_pending_pclk     = r_status_sync_ff2[23];
    assign status_irq_error_pending_pclk = r_irq_type_sync_ff2[0];
    assign status_irq_correct_pending_pclk = r_irq_type_sync_ff2[1];

    always @(*) begin
        r_prdata = {DW{1'b0}};
        case (apb_decode_valid ? apb_addr : 5'h1f)
            APB_ADDR_VERSION: begin
                r_prdata = REG_VERSION;
            end
            APB_ADDR_DATE: begin
                r_prdata = REG_DATE;
            end
            APB_ADDR_TILE_CFG0: begin
                r_prdata = {{(DW-20){1'b0}},
                            r_tile_cfg_ubwc_ver,
                            4'd0,
                            r_tile_cfg_is_lossy_rgba_2_1_format,
                            r_tile_cfg_4line_format,
                            r_tile_cfg_bank_spread_en,
                            r_tile_cfg_highest_bank_bit,
                            1'b0,
                            r_tile_cfg_lvl3_bank_swizzle_en,
                            r_tile_cfg_lvl2_bank_swizzle_en,
                            r_tile_cfg_lvl1_bank_swizzle_en};
            end
            APB_ADDR_TILE_CFG1: begin
                r_prdata = {{(DW-12){1'b0}}, r_tile_cfg_pitch};
            end
            APB_ADDR_TILE_CFG2: begin
                r_prdata = {{(DW-11){1'b0}},
                            r_tile_cfg_ci_alpha_mode,
                            r_tile_cfg_ci_lossy,
                            7'd0,
                            r_tile_cfg_ci_input_type};
            end
            REG_TILE_BASE_Y_LO: begin
                r_prdata = r_tile_base_addr_rgba_y[31:0];
            end
            REG_TILE_BASE_Y_HI: begin
                r_prdata = {{(DW-(AXI_AW-32)){1'b0}}, r_tile_base_addr_rgba_y[AXI_AW-1:32]};
            end
            REG_TILE_BASE_UV_LO: begin
                r_prdata = r_tile_base_addr_uv[31:0];
            end
            REG_TILE_BASE_UV_HI: begin
                r_prdata = {{(DW-(AXI_AW-32)){1'b0}}, r_tile_base_addr_uv[AXI_AW-1:32]};
            end
            APB_ADDR_VIVO_CFG: begin
                r_prdata = {{(DW-2){1'b0}}, r_vivo_sreset, r_vivo_ubwc_en};
            end
            REG_META_BASE_Y_LO: begin
                r_prdata = r_meta_base_addr_rgba_y[31:0];
            end
            REG_META_BASE_Y_HI: begin
                r_prdata = {{(DW-(AXI_AW-32)){1'b0}}, r_meta_base_addr_rgba_y[AXI_AW-1:32]};
            end
            REG_META_BASE_UV_LO: begin
                r_prdata = r_meta_base_addr_uv[31:0];
            end
            REG_META_BASE_UV_HI: begin
                r_prdata = {{(DW-(AXI_AW-32)){1'b0}}, r_meta_base_addr_uv[AXI_AW-1:32]};
            end
            APB_ADDR_META_CFG0: begin
                r_prdata = {cfg_meta_tile_y_numbers, cfg_meta_tile_x_numbers};
            end
            APB_ADDR_OTF_CFG0: begin
                r_prdata = {{(DW-21){1'b0}}, r_otf_cfg_format, 16'd0};
            end
            APB_ADDR_OTF_CFG1: begin
                r_prdata = {r_otf_cfg_h_sync, r_otf_cfg_h_total};
            end
            APB_ADDR_OTF_CFG2: begin
                r_prdata = {r_otf_cfg_h_act, r_otf_cfg_h_bp};
            end
            APB_ADDR_OTF_CFG3: begin
                r_prdata = {r_otf_cfg_v_sync, r_otf_cfg_v_total};
            end
            APB_ADDR_OTF_CFG4: begin
                r_prdata = {r_otf_cfg_v_act, r_otf_cfg_v_bp};
            end
            APB_ADDR_STATUS0: begin
                r_prdata = {{(DW-7){1'b0}},
                            (!status_any_stage_busy_pclk && !status_frame_active_pclk),
                            !status_any_stage_busy_pclk,
                            status_otf_busy_pclk,
                            status_vivo_busy_pclk,
                            status_tile_busy_pclk,
                            status_meta_busy_pclk,
                            status_frame_active_pclk};
            end
            APB_ADDR_STATUS1: begin
                r_prdata = {{(DW-9){1'b0}}, status_stage_seen_pclk, status_stage_done_pclk};
            end
            APB_ADDR_STATUS2: begin
                r_prdata = {{(DW-1){1'b0}}, status_vivo_idle_pclk};
            end
            APB_ADDR_STATUS3: begin
                r_prdata = {{(DW-7){1'b0}}, status_vivo_error_pclk};
            end
            APB_ADDR_IRQ_CTRL: begin
                r_prdata = {{(DW-6){1'b0}},
                            1'b0,
                            status_irq_correct_pending_pclk,
                            status_irq_error_pending_pclk,
                            status_irq_pending_pclk,
                            1'b0,
                            r_irq_enable};
            end
            APB_ADDR_STATUS4: begin
                r_prdata = {{(DW-3){1'b0}},
                            status_irq_correct_pending_pclk,
                            status_irq_error_pending_pclk,
                            status_irq_pending_pclk};
            end
            APB_ADDR_STAT_META: begin
                r_prdata = r_stat_meta_tile_sync_ff2;
            end
            APB_ADDR_STAT_TILE: begin
                r_prdata = r_stat_tile_addr_sync_ff2;
            end
            APB_ADDR_STAT_OTF_TILE: begin
                r_prdata = r_stat_otf_tile_sync_ff2;
            end
            APB_ADDR_STAT_OTF_LINE: begin
                r_prdata = r_stat_otf_line_sync_ff2;
            end
            APB_ADDR_STAT_OTF_DE: begin
                r_prdata = r_stat_otf_de_sync_ff2;
            end
            default: begin
                r_prdata = {DW{1'b0}};
            end
        endcase
    end

    assign PREADY  = !base_fifo_stall;
    assign PSLVERR = 1'b0;
    assign PRDATA  = r_prdata;

    assign o_tile_cfg_lvl2_bank_swizzle_en     = a_tile_cfg_lvl2_bank_swizzle_en;
    assign o_tile_cfg_lvl3_bank_swizzle_en     = a_tile_cfg_lvl3_bank_swizzle_en;
    assign o_tile_cfg_highest_bank_bit         = a_tile_cfg_highest_bank_bit;
    assign o_tile_cfg_bank_spread_en           = a_tile_cfg_bank_spread_en;
    assign o_tile_cfg_is_lossy_rgba_2_1_format = a_tile_cfg_is_lossy_rgba_2_1_format;
    assign o_tile_cfg_pitch                    = a_tile_cfg_pitch;
    assign o_tile_cfg_ci_input_type            = a_tile_cfg_ci_input_type;
    assign o_tile_cfg_ci_lossy                 = a_tile_cfg_ci_lossy;
    assign o_tile_cfg_ci_alpha_mode            = a_tile_cfg_ci_alpha_mode;
    assign o_tile_cfg_ubwc_ver                 = a_tile_cfg_ubwc_ver;
    assign o_tile_base_addr_rgba_y0           = a_tile_base_addr_rgba_y0;
    assign o_tile_base_addr_uv0                 = a_tile_base_addr_uv0;
    assign o_tile_base_addr_rgba_y1           = a_tile_base_addr_rgba_y1;
    assign o_tile_base_addr_uv1                 = a_tile_base_addr_uv1;
    assign o_vivo_ubwc_en                      = a_vivo_ubwc_en;
    assign o_vivo_sreset                       = a_vivo_sreset;
    assign o_frame_start_pulse_axi             = r_frame_start_pulse_axi;
    assign o_meta_start_pulse_axi              = r_frame_start_pulse_axi;
    assign o_meta_base_format                  = a_meta_base_format;
    assign o_meta_base_addr_rgba_y0            = a_meta_base_addr_rgba_y0;
    assign o_meta_base_addr_uv0                = a_meta_base_addr_uv0;
    assign o_meta_base_addr_rgba_y1            = a_meta_base_addr_rgba_y1;
    assign o_meta_base_addr_uv1                = a_meta_base_addr_uv1;
    assign o_meta_tile_x_numbers               = a_meta_tile_x_numbers;
    assign o_meta_tile_y_numbers               = a_meta_tile_y_numbers;
    assign o_otf_cfg_img_width                 = a_otf_cfg_h_act;
    assign o_otf_cfg_format                    = a_otf_cfg_format;
    assign o_otf_cfg_h_total                   = a_otf_cfg_h_total;
    assign o_otf_cfg_h_sync                    = a_otf_cfg_h_sync;
    assign o_otf_cfg_h_bp                      = a_otf_cfg_h_bp;
    assign o_otf_cfg_h_act                     = a_otf_cfg_h_act;
    assign o_otf_cfg_v_total                   = a_otf_cfg_v_total;
    assign o_otf_cfg_v_sync                    = a_otf_cfg_v_sync;
    assign o_otf_cfg_v_bp                      = a_otf_cfg_v_bp;
    assign o_otf_cfg_v_act                     = a_otf_cfg_v_act;
    assign o_irq_enable_axi                    = r_irq_enable_sync_ff2;
    assign o_irq_clear_pulse_axi               = r_irq_clear_sync_ff1 ^ r_irq_clear_sync_ff2;

endmodule
