//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-02-26  22:11:51
// Module Name       : ubwc_enc_wrapper_top.sv
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//        Revision 1.00 - File Created by        : MiaoJiawang
//        Description                            :
//
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module ubwc_enc_wrapper_top
    #(
        parameter                                       SB_WIDTH                        = 1,
        parameter                                       APB_AW                          = 16,
        parameter                                       APB_DW                          = 32,
        parameter                                       APB_BLK_NREG                    = 64,
        parameter                                       AXI_AW                          = 64,
        parameter                                       AXI_DW                          = 64,
        parameter                                       AXI_LENW                        = 8,
        parameter                                       AXI_IDW                         = 4,
        parameter                                       COM_BUF_AW                      = 12,
        parameter                                       COM_BUF_DW                      = 128
    )(
        input   wire                                        PCLK                            ,
        input   wire                                        PRESETn                         ,
        input   wire                                        PSEL                            ,
        input   wire                                        PENABLE                         ,
        input   wire    [APB_AW              -1 :0]         PADDR                           ,
        input   wire                                        PWRITE                          ,
        input   wire    [APB_DW              -1 :0]         PWDATA                          ,
        output  wire                                        PREADY                          ,
        output  wire                                        PSLVERR                         ,
        output  wire    [APB_DW              -1 :0]         PRDATA                          ,

    // clock/reset
        input   wire                                        i_clk                           ,
        input   wire                                        i_otf_clk                       ,
        input   wire                                        i_rstn                          ,

    // OTF input
        input   wire                                        i_otf_vsync                     ,
        input   wire                                        i_otf_hsync                     ,
        input   wire                                        i_otf_de                        ,
        input   wire    [128                 -1 :0]         i_otf_data                      ,
        input   wire    [4                   -1 :0]         i_otf_fcnt                      ,
        input   wire    [12                  -1 :0]         i_otf_lcnt                      ,
        output  wire                                        o_otf_ready                     ,

    // SRAM bank0
        output  wire                                        o_bank0_en                      ,
        output  wire                                        o_bank0_wen                     ,
        output  wire    [COM_BUF_AW          -1 :0]         o_bank0_addr                    ,
        output  wire    [COM_BUF_DW          -1 :0]         o_bank0_din                     ,
        input   wire    [COM_BUF_DW          -1 :0]         i_bank0_dout                    ,
        input   wire                                        i_bank0_dout_vld                ,

    // SRAM bank1
        output  wire                                        o_bank1_en                      ,
        output  wire                                        o_bank1_wen                     ,
        output  wire    [COM_BUF_AW          -1 :0]         o_bank1_addr                    ,
        output  wire    [COM_BUF_DW          -1 :0]         o_bank1_din                     ,
        input   wire    [COM_BUF_DW          -1 :0]         i_bank1_dout                    ,
        input   wire                                        i_bank1_dout_vld                ,

    //AXI master interface
        output  wire    [AXI_IDW                :0]         o_m_axi_awid                    ,
        output  wire    [AXI_AW              -1 :0]         o_m_axi_awaddr                  ,
        output  wire    [AXI_LENW            -1 :0]         o_m_axi_awlen                   ,
        output  wire    [3                   -1 :0]         o_m_axi_awsize                  ,
        output  wire    [2                   -1 :0]         o_m_axi_awburst                 ,
        output  wire    [2                   -1 :0]         o_m_axi_awlock                  ,
        output  wire    [4                   -1 :0]         o_m_axi_awcache                 ,
        output  wire    [3                   -1 :0]         o_m_axi_awprot                  ,
        output  wire                                        o_m_axi_awvalid                 ,
        input   wire                                        i_m_axi_awready                 ,

        output  wire    [AXI_DW              -1 :0]         o_m_axi_wdata                   ,
        output  wire    [AXI_DW/8            -1 :0]         o_m_axi_wstrb                   ,
        output  wire                                        o_m_axi_wvalid                  ,
        output  wire                                        o_m_axi_wlast                   ,
        input   wire                                        i_m_axi_wready                  ,

        input   wire    [AXI_IDW                :0]         i_m_axi_bid                     ,
        input   wire    [2                   -1 :0]         i_m_axi_bresp                   ,
        input   wire                                        i_m_axi_bvalid                  ,
        output  wire                                        o_m_axi_bready                  ,

    // done/interrupt
        output  wire    [8                   -1 :0]         o_stage_done                    ,
        output  wire                                        o_frame_done                    ,
        output  wire                                        o_irq
    );

    localparam  integer                             CORE_AXI_DW                     = 256;
    localparam  integer                             COORD_FIFO_DEPTH                = 32;
    localparam  integer                             TH_DW                           = 13;
    localparam  integer                             TW_DW                           = 8;

    wire        [3                   -1 :0]         otf_cfg_format                  ;
    wire        [16                  -1 :0]         otf_cfg_width                   ;
    wire        [16                  -1 :0]         otf_cfg_height                  ;
    wire        [16                  -1 :0]         meta_active_width_px            ;
    wire        [16                  -1 :0]         meta_active_height_px           ;
    wire        [16                  -1 :0]         otf_cfg_tile_w                  ;
    wire        [4                   -1 :0]         otf_cfg_tile_h                  ;
    wire        [16                  -1 :0]         otf_cfg_y_tile_cols             ;
    wire        [16                  -1 :0]         otf_cfg_uv_tile_cols            ;
    wire                                            enc_ubwc_en                     ;
    wire                                            enc_ci_valid                    ;
    wire                                            enc_ci_ready                    ;
    wire                                            enc_ci_input_type               ;
    wire        [3                   -1 :0]         enc_ci_alen                     ;
    wire                                            enc_ci_forced_pcm               ;
    wire                                            enc_ci_lossy                    ;
    wire        [3                   -1 :0]         enc_ci_ubwc_cfg_0               ;
    wire        [3                   -1 :0]         enc_ci_ubwc_cfg_1               ;
    wire        [4                   -1 :0]         enc_ci_ubwc_cfg_2               ;
    wire        [4                   -1 :0]         enc_ci_ubwc_cfg_3               ;
    wire        [4                   -1 :0]         enc_ci_ubwc_cfg_4               ;
    wire        [4                   -1 :0]         enc_ci_ubwc_cfg_5               ;
    wire        [2                   -1 :0]         enc_ci_ubwc_cfg_6               ;
    wire        [2                   -1 :0]         enc_ci_ubwc_cfg_7               ;
    wire        [2                   -1 :0]         enc_ci_ubwc_cfg_8               ;
    wire        [3                   -1 :0]         enc_ci_ubwc_cfg_9               ;
    wire        [6                   -1 :0]         enc_ci_ubwc_cfg_10              ;
    wire        [6                   -1 :0]         enc_ci_ubwc_cfg_11              ;
    wire                                            lvl1_bank_swizzle_en            ;
    wire                                            lvl2_bank_swizzle_en            ;
    wire                                            lvl3_bank_swizzle_en            ;
    wire        [5                   -1 :0]         highest_bank_bit                ;
    wire                                            bank_spread_en                  ;
    wire                                            four_line_format                ;
    wire                                            is_lossy_rgba_2_1_format        ;
    wire        [12                  -1 :0]         tile_pitch                      ;
    wire        [64                  -1 :0]         y_base_offset_addr0             ;
    wire        [64                  -1 :0]         uv_base_offset_addr0            ;
    wire        [64                  -1 :0]         meta_y_base_offset_addr0        ;
    wire        [64                  -1 :0]         meta_uv_base_offset_addr0       ;
    wire        [64                  -1 :0]         y_base_offset_addr1             ;
    wire        [64                  -1 :0]         uv_base_offset_addr1            ;
    wire        [64                  -1 :0]         meta_y_base_offset_addr1        ;
    wire        [64                  -1 :0]         meta_uv_base_offset_addr1       ;
    wire        [2                   -1 :0]         addr_cfg_valid                  ;
    wire                                            active_addr_cfg_valid           ;
    wire                                            addr_cfg_invalid                ;
    wire                                            otf_err_bline                   ;
    wire                                            otf_err_bframe                  ;
    wire                                            meta_err_0                      ;
    wire                                            meta_err_1                      ;
    wire                                            enc_irq_pending                 ;
    wire                                            enc_irq_correct_pending         ;
    wire                                            enc_irq_error_pending           ;
    wire                                            enc_irq_enable                  ;
    wire                                            enc_irq_clear_pulse             ;
    wire                                            enc_correct_irq_pulse           ;
    wire                                            enc_correct_irq_slot            ;
    wire                                            enc_addr_cfg_done_pulse         ;
    wire                                            enc_addr_cfg_done_slot          ;
    wire                                            enc_error_irq_event             ;
    wire                                            enc_addr_cfg_pop_toggle         ;
    wire        [32                  -1 :0]         enc_meta_count0                 ;
    wire        [32                  -1 :0]         enc_meta_count1                 ;
    wire        [32                  -1 :0]         enc_tile_addr_count0            ;
    wire        [32                  -1 :0]         enc_tile_addr_count1            ;
    wire        [32                  -1 :0]         enc_otf_tile_count0             ;
    wire        [32                  -1 :0]         enc_otf_tile_count1             ;
    wire        [32                  -1 :0]         enc_otf_de_count0               ;
    wire        [32                  -1 :0]         enc_otf_de_count1               ;
    wire        [32                  -1 :0]         enc_otf_line_count0             ;
    wire        [32                  -1 :0]         enc_otf_line_count1             ;
    wire        [32                  -1 :0]         enc_stat_otf_de_count0          ;
    wire        [32                  -1 :0]         enc_stat_otf_de_count1          ;
    wire        [32                  -1 :0]         enc_stat_otf_line_count0        ;
    wire        [32                  -1 :0]         enc_stat_otf_line_count1        ;
    wire        [32                  -1 :0]         enc_tile_axi_w_count0           ;
    wire        [32                  -1 :0]         enc_tile_axi_w_count1           ;
    wire        [32                  -1 :0]         enc_meta_axi_w_count0           ;
    wire        [32                  -1 :0]         enc_meta_axi_w_count1           ;
    wire                                            rvi_valid                       ;
    wire                                            rvi_ready                       ;
    wire                                            rvi_last                        ;
    wire        [4                   -1 :0]         rvi_fcnt                        ;
    wire                                            coord_fifo_wr_en                ;
    wire                                            coord_fifo_rd_en                ;
    wire        [5                   -1 :0]         b_tile_format                   ;
    wire        [4                   -1 :0]         b_tile_fcnt                     ;
    wire        [TH_DW               -1 :0]         b_tile_ycoord                   ;
    wire        [TW_DW               -1 :0]         b_tile_xcoord                   ;
    wire        [5                   -1 :0]         tile_format                     ;
    wire        [28                  -1 :0]         tile_addr                       ;
    wire        [3                   -1 :0]         tile_alen                       ;
    wire        [4                   -1 :0]         tile_addr_fcnt                  ;
    wire                                            tile_addr_vld                   ;
    wire                                            enc_co_valid                    ;
    wire                                            enc_co_ready                    ;
    wire                                            enc_co_fire                     ;
    wire        [3                   -1 :0]         enc_co_alen                     ;
    wire        [SB_WIDTH            -1 :0]         enc_co_sb                       ;
    wire                                            enc_co_pcm                      ;
    wire                                            enc_cvo_valid                   ;
    wire                                            enc_cvo_ready                   ;
    wire        [256                 -1 :0]         enc_cvo_data                    ;
    wire        [32                  -1 :0]         enc_cvo_mask                    ;
    wire                                            enc_cvo_last                    ;
    wire                                            enc_idle                        ;
    wire                                            enc_error                       ;
    wire        [66                  -1 :0]         meta_data                       ;
    wire        [AXI_AW              -1 :0]         meta_addr                       ;
    wire        [4                   -1 :0]         meta_fcnt                       ;
    wire                                            meta_data_valid                 ;
    wire                                            meta_data_ready                 ;
    wire                                            meta_addr_valid                 ;
    wire                                            meta_addr_ready                 ;
    wire        [32                  -1 :0]         meta_data_plane_pitch           ;
    wire        [TW_DW               -1 :0]         meta_last_xcoord                ;
    wire                                            err_fifo_ovf                    ;
    wire                                            rst                             ;
    wire                                            rst_n_sys                       ;
    wire                                            rst_n_otf                       ;
    wire                                            srst                            ;
    wire                                            enc_meta_srstn                  ;
    wire                                            rvi_slot                        ;
    wire                                            b_tile_slot                     ;
    wire                                            tile_addr_slot                  ;
    wire                                            meta_slot                       ;
    wire                                            enc_axi_awslot                  ;
    wire                                            meta_axi_awslot                 ;
    wire                                            enc_axi_awlock_bit              ;
    wire                                            meta_axi_awlock_bit             ;
    wire        [2                      :0]         core_m_axi_awsize_3b            ;
    wire        [AXI_IDW             -1 :0]         axi_id_zero                     ;
    wire        [AXI_IDW                :0]         axi_id_ext_zero                 ;
    wire        [AXI_AW              -1 :0]         axi_aw_zero                     ;
    wire        [AXI_LENW            -1 :0]         axi_len_zero                    ;
    wire        [3                      :0]         axi_cache_zero                  ;
    wire        [2                      :0]         axi_size_zero                   ;
    wire        [2                      :0]         axi_prot_zero                   ;
    wire        [1                      :0]         axi_burst_zero                  ;
    wire        [CORE_AXI_DW         -1 :0]         core_axi_data_zero              ;
    wire        [AXI_DW              -1 :0]         axi_data_zero                   ;
    wire        [AXI_IDW                :0]         core_m_axi_awid                 ;
    wire        [AXI_AW              -1 :0]         core_m_axi_awaddr               ;
    wire        [AXI_LENW            -1 :0]         core_m_axi_awlen                ;
    wire        [2                   -1 :0]         core_m_axi_awburst              ;
    wire        [2                   -1 :0]         core_m_axi_awlock               ;
    wire                                            core_m_axi_awlock_int           ;
    wire        [4                   -1 :0]         core_m_axi_awcache              ;
    wire        [3                   -1 :0]         core_m_axi_awprot               ;
    wire        [3                   -1 :0]         core_m_axi_awsize               ;
    wire                                            core_m_axi_awvalid              ;
    wire                                            core_m_axi_awready              ;
    wire        [CORE_AXI_DW         -1 :0]         core_m_axi_wdata                ;
    wire        [CORE_AXI_DW/8       -1 :0]         core_m_axi_wstrb                ;
    wire                                            core_m_axi_wlast                ;
    wire                                            core_m_axi_wvalid               ;
    wire                                            core_m_axi_wready               ;
    wire        [AXI_IDW                :0]         core_m_axi_bid                  ;
    wire        [2                   -1 :0]         core_m_axi_bresp                ;
    wire                                            core_m_axi_bvalid               ;
    wire                                            core_m_axi_bready               ;
    wire        [AXI_IDW             -1 :0]         enc_axi_awid                    ;
    wire        [AXI_AW              -1 :0]         enc_axi_awaddr                  ;
    wire        [AXI_LENW            -1 :0]         enc_axi_awlen                   ;
    wire        [3                   -1 :0]         enc_axi_awsize                  ;
    wire        [2                   -1 :0]         enc_axi_awburst                 ;
    wire        [2                   -1 :0]         enc_axi_awlock                  ;
    wire        [4                   -1 :0]         enc_axi_awcache                 ;
    wire        [3                   -1 :0]         enc_axi_awprot                  ;
    wire                                            enc_axi_awvalid                 ;
    wire                                            enc_axi_awready                 ;
    wire        [CORE_AXI_DW         -1 :0]         enc_axi_wdata                   ;
    wire        [CORE_AXI_DW/8       -1 :0]         enc_axi_wstrb                   ;
    wire                                            enc_axi_wlast                   ;
    wire                                            enc_axi_wvalid                  ;
    wire                                            enc_axi_wready                  ;
    wire        [AXI_IDW             -1 :0]         enc_axi_bid                     ;
    wire        [2                   -1 :0]         enc_axi_bresp                   ;
    wire                                            enc_axi_bvalid                  ;
    wire                                            enc_axi_bready                  ;
    wire        [AXI_IDW             -1 :0]         meta_axi_awid                   ;
    wire        [AXI_AW              -1 :0]         meta_axi_awaddr                 ;
    wire        [AXI_LENW            -1 :0]         meta_axi_awlen                  ;
    wire        [3                   -1 :0]         meta_axi_awsize                 ;
    wire        [2                   -1 :0]         meta_axi_awburst                ;
    wire        [2                   -1 :0]         meta_axi_awlock                 ;
    wire        [4                   -1 :0]         meta_axi_awcache                ;
    wire        [3                   -1 :0]         meta_axi_awprot                 ;
    wire                                            meta_axi_awvalid                ;
    wire                                            meta_axi_awready                ;
    wire        [CORE_AXI_DW         -1 :0]         meta_axi_wdata                  ;
    wire        [CORE_AXI_DW/8       -1 :0]         meta_axi_wstrb                  ;
    wire                                            meta_axi_wlast                  ;
    wire                                            meta_axi_wvalid                 ;
    wire                                            meta_axi_wready                 ;
    wire        [AXI_IDW             -1 :0]         meta_axi_bid                    ;
    wire        [2                   -1 :0]         meta_axi_bresp                  ;
    wire                                            meta_axi_bvalid                 ;
    wire                                            meta_axi_bready                 ;

    wire        [256                 -1 :0]         rvi_data                        ;
    wire        [32                  -1 :0]         rvi_mask                        ;

    assign rst                = ~rst_n_sys;
    assign enc_meta_srstn     = ~srst;
    assign rvi_slot           = rvi_fcnt[0];
    assign b_tile_slot        = b_tile_fcnt[0];
    assign tile_addr_slot     = tile_addr_fcnt[0];
    assign meta_slot          = meta_fcnt[0];
    assign enc_axi_awslot     = enc_axi_awid[0];
    assign meta_axi_awslot    = meta_axi_awid[0];
    assign enc_axi_awlock_bit = enc_axi_awlock[0];
    assign meta_axi_awlock_bit = meta_axi_awlock[0];
    assign core_m_axi_awsize_3b = core_m_axi_awsize[2:0];
    assign enc_co_fire        = enc_co_valid & enc_co_ready;
    assign core_m_axi_awlock  = {1'b0, core_m_axi_awlock_int};
    assign axi_id_zero        = {AXI_IDW{1'b0}};
    assign axi_id_ext_zero    = {(AXI_IDW+1){1'b0}};
    assign axi_aw_zero        = {AXI_AW{1'b0}};
    assign axi_len_zero       = {AXI_LENW{1'b0}};
    assign axi_cache_zero     = 4'd0;
    assign axi_size_zero      = 3'd0;
    assign axi_prot_zero      = 3'd0;
    assign axi_burst_zero     = 2'd0;
    assign core_axi_data_zero = {CORE_AXI_DW{1'b0}};
    assign axi_data_zero      = {AXI_DW{1'b0}};

    ubwc_enc_status u_enc_status
    (
        .i_clk                           ( i_clk                           ),
        .i_rstn                          ( rst_n_sys                       ),
        .i_enc_ubwc_en                   ( enc_ubwc_en                     ),

        .i_correct_irq_event             ( enc_correct_irq_pulse           ),
        .i_correct_irq_slot              ( enc_correct_irq_slot            ),
        .i_addr_cfg_done_event           ( enc_addr_cfg_done_pulse         ),
        .i_addr_cfg_done_slot            ( enc_addr_cfg_done_slot          ),
        .i_error_irq_event               ( enc_error_irq_event             ),
        .i_addr_cfg_invalid              ( addr_cfg_invalid                ),

        .i_rvi_valid                     ( rvi_valid                       ),
        .i_rvi_ready                     ( rvi_ready                       ),
        .i_rvi_last                      ( rvi_last                        ),
        .i_rvi_slot                      ( rvi_slot                        ),
        .i_tile_addr_vld                 ( tile_addr_vld                   ),
        .i_tile_addr_slot                ( tile_addr_slot                  ),
        .i_meta_addr_valid               ( meta_addr_valid                 ),
        .i_meta_addr_ready               ( meta_addr_ready                 ),
        .i_meta_slot                     ( meta_slot                       ),

        .i_tile_axi_awvalid              ( enc_axi_awvalid                 ),
        .i_tile_axi_awready              ( enc_axi_awready                 ),
        .i_tile_axi_awslot               ( enc_axi_awslot                  ),
        .i_tile_axi_wvalid               ( enc_axi_wvalid                  ),
        .i_tile_axi_wready               ( enc_axi_wready                  ),
        .i_meta_axi_awvalid              ( meta_axi_awvalid                ),
        .i_meta_axi_awready              ( meta_axi_awready                ),
        .i_meta_axi_awslot               ( meta_axi_awslot                 ),
        .i_meta_axi_wvalid               ( meta_axi_wvalid                 ),
        .i_meta_axi_wready               ( meta_axi_wready                 ),

        .i_otf_de_count0                 ( enc_otf_de_count0               ),
        .i_otf_de_count1                 ( enc_otf_de_count1               ),
        .i_otf_line_count0               ( enc_otf_line_count0             ),
        .i_otf_line_count1               ( enc_otf_line_count1             ),

        .i_irq_enable                    ( enc_irq_enable                  ),
        .i_irq_clear                     ( enc_irq_clear_pulse             ),

        .o_stage_done                    ( o_stage_done                    ),
        .o_frame_done                    ( o_frame_done                    ),
        .o_irq_pending                   ( enc_irq_pending                 ),
        .o_irq_correct_pending           ( enc_irq_correct_pending         ),
        .o_irq_error_pending             ( enc_irq_error_pending           ),
        .o_irq                           ( o_irq                           ),
        .o_addr_cfg_pop_toggle           ( enc_addr_cfg_pop_toggle         ),

        .o_meta_count0                   ( enc_meta_count0                 ),
        .o_meta_count1                   ( enc_meta_count1                 ),
        .o_tile_addr_count0              ( enc_tile_addr_count0            ),
        .o_tile_addr_count1              ( enc_tile_addr_count1            ),
        .o_otf_tile_count0               ( enc_otf_tile_count0             ),
        .o_otf_tile_count1               ( enc_otf_tile_count1             ),
        .o_otf_de_count0                 ( enc_stat_otf_de_count0          ),
        .o_otf_de_count1                 ( enc_stat_otf_de_count1          ),
        .o_otf_line_count0               ( enc_stat_otf_line_count0        ),
        .o_otf_line_count1               ( enc_stat_otf_line_count1        ),
        .o_tile_axi_w_count0             ( enc_tile_axi_w_count0           ),
        .o_tile_axi_w_count1             ( enc_tile_axi_w_count1           ),
        .o_meta_axi_w_count0             ( enc_meta_axi_w_count0           ),
        .o_meta_axi_w_count1             ( enc_meta_axi_w_count1           )
    );

    ubwc_enc_rst_mdl u_enc_rst_mdl
    (
        .i_clk                           ( i_clk                           ),
        .i_otf_clk                       ( i_otf_clk                       ),
        .i_rstn                          ( i_rstn                          ),
        .o_rst                           (                                 ),
        .o_rst_n_sys                     ( rst_n_sys                       ),
        .o_rst_n_otf                     ( rst_n_otf                       ),
        .o_srst                          ( srst                            )
    );

    ubwc_enc_apb_reg_blk
    #(
        .AW                              ( APB_AW                          ),
        .DW                              ( APB_DW                          ),
        .NREG                            ( APB_BLK_NREG                    ),
        .SB_WIDTH                        ( SB_WIDTH                        ),
        .TW_DW                           ( TW_DW                           )
    )
    ubwc_enc_apb_reg_blk
    (
        .PCLK                            ( PCLK                            ),
        .PRESETn                         ( PRESETn                         ),
        .PSEL                            ( PSEL                            ),
        .PENABLE                         ( PENABLE                         ),
        .PADDR                           ( PADDR                           ),
        .PWRITE                          ( PWRITE                          ),
        .PWDATA                          ( PWDATA                          ),
        .PREADY                          ( PREADY                          ),
        .PSLVERR                         ( PSLVERR                         ),
        .PRDATA                          ( PRDATA                          ),
        .i_clk                           ( i_clk                           ),
        .i_rstn                          ( rst_n_sys                       ),

        .o_otf_cfg_format                ( otf_cfg_format                  ),
        .o_otf_cfg_width                 ( otf_cfg_width                   ),
        .o_otf_cfg_height                ( otf_cfg_height                  ),
        .o_meta_active_width_px          ( meta_active_width_px            ),
        .o_meta_active_height_px         ( meta_active_height_px           ),
        .o_otf_cfg_tile_w                ( otf_cfg_tile_w                  ),
        .o_otf_cfg_tile_h                ( otf_cfg_tile_h                  ),
        .o_otf_cfg_y_tile_cols           ( otf_cfg_y_tile_cols             ),
        .o_otf_cfg_uv_tile_cols          ( otf_cfg_uv_tile_cols            ),
        .o_meta_last_xcoord              ( meta_last_xcoord                ),
        .o_meta_data_plane_pitch         ( meta_data_plane_pitch           ),

        .o_enc_ubwc_en                   ( enc_ubwc_en                     ),
        .o_enc_ci_alen                   ( enc_ci_alen                     ),
        .o_enc_ci_input_type             ( enc_ci_input_type               ),
        .o_enc_ci_lossy                  ( enc_ci_lossy                    ),
        .o_enc_ci_ubwc_cfg_0             ( enc_ci_ubwc_cfg_0               ),
        .o_enc_ci_ubwc_cfg_1             ( enc_ci_ubwc_cfg_1               ),
        .o_enc_ci_ubwc_cfg_2             ( enc_ci_ubwc_cfg_2               ),
        .o_enc_ci_ubwc_cfg_3             ( enc_ci_ubwc_cfg_3               ),
        .o_enc_ci_ubwc_cfg_4             ( enc_ci_ubwc_cfg_4               ),
        .o_enc_ci_ubwc_cfg_5             ( enc_ci_ubwc_cfg_5               ),
        .o_enc_ci_ubwc_cfg_6             ( enc_ci_ubwc_cfg_6               ),
        .o_enc_ci_ubwc_cfg_7             ( enc_ci_ubwc_cfg_7               ),
        .o_enc_ci_ubwc_cfg_8             ( enc_ci_ubwc_cfg_8               ),
        .o_enc_ci_ubwc_cfg_9             ( enc_ci_ubwc_cfg_9               ),
        .o_enc_ci_ubwc_cfg_10            ( enc_ci_ubwc_cfg_10              ),
        .o_enc_ci_ubwc_cfg_11            ( enc_ci_ubwc_cfg_11              ),

        .i_enc_idle                      ( enc_idle                        ),
        .i_enc_error                     ( enc_error                       ),

        .o_lvl1_bank_swizzle_en          ( lvl1_bank_swizzle_en            ),
        .o_lvl2_bank_swizzle_en          ( lvl2_bank_swizzle_en            ),
        .o_lvl3_bank_swizzle_en          ( lvl3_bank_swizzle_en            ),
        .o_highest_bank_bit              ( highest_bank_bit                ),
        .o_bank_spread_en                ( bank_spread_en                  ),
        .o_4line_format                  ( four_line_format                ),
        .o_is_lossy_rgba_2_1_format      ( is_lossy_rgba_2_1_format        ),
        .o_tile_pitch                    ( tile_pitch                      ),
        .o_y_base_offset_addr0           ( y_base_offset_addr0             ),
        .o_uv_base_offset_addr0          ( uv_base_offset_addr0            ),
        .o_meta_y_base_offset_addr0      ( meta_y_base_offset_addr0        ),
        .o_meta_uv_base_offset_addr0     ( meta_uv_base_offset_addr0       ),
        .o_y_base_offset_addr1           ( y_base_offset_addr1             ),
        .o_uv_base_offset_addr1          ( uv_base_offset_addr1            ),
        .o_meta_y_base_offset_addr1      ( meta_y_base_offset_addr1        ),
        .o_meta_uv_base_offset_addr1     ( meta_uv_base_offset_addr1       ),
        .o_addr_cfg_valid                ( addr_cfg_valid                  ),
        .i_addr_cfg_slot                 ( b_tile_slot                     ),
        .i_addr_cfg_check_valid          ( enc_co_valid                    ),
        .o_active_addr_cfg_valid         ( active_addr_cfg_valid           ),
        .o_addr_cfg_invalid              ( addr_cfg_invalid                ),
        .o_error_irq_event               ( enc_error_irq_event             ),

        .i_otf_to_tile_busy              ( rvi_valid                       ),
        .i_otf_to_tile_overflow          ( err_fifo_ovf                    ),
        .i_otf_err_bline                 ( otf_err_bline                   ),
        .i_otf_err_bframe                ( otf_err_bframe                  ),
        .i_meta_err_0                    ( meta_err_0                      ),
        .i_meta_err_1                    ( meta_err_1                      ),
        .i_frame_done                    ( o_frame_done                    ),
        .i_addr_cfg_pop_toggle           ( enc_addr_cfg_pop_toggle         ),
        .i_stage_done                    ( o_stage_done                    ),
        .i_irq_pending                   ( enc_irq_pending                 ),
        .i_irq_correct_pending           ( enc_irq_correct_pending         ),
        .i_irq_error_pending             ( enc_irq_error_pending           ),
        .i_meta_count0                   ( enc_meta_count0                 ),
        .i_meta_count1                   ( enc_meta_count1                 ),
        .i_tile_addr_count0              ( enc_tile_addr_count0            ),
        .i_tile_addr_count1              ( enc_tile_addr_count1            ),
        .i_otf_tile_count0               ( enc_otf_tile_count0             ),
        .i_otf_tile_count1               ( enc_otf_tile_count1             ),
        .i_otf_de_count0                 ( enc_stat_otf_de_count0          ),
        .i_otf_de_count1                 ( enc_stat_otf_de_count1          ),
        .i_otf_line_count0               ( enc_stat_otf_line_count0        ),
        .i_otf_line_count1               ( enc_stat_otf_line_count1        ),
        .i_tile_axi_w_count0             ( enc_tile_axi_w_count0           ),
        .i_tile_axi_w_count1             ( enc_tile_axi_w_count1           ),
        .i_meta_axi_w_count0             ( enc_meta_axi_w_count0           ),
        .i_meta_axi_w_count1             ( enc_meta_axi_w_count1           ),
        .o_irq_enable                    ( enc_irq_enable                  ),
        .o_irq_clear_pulse               ( enc_irq_clear_pulse             )
    );

    ubwc_enc_otf_to_tile
    #(
        .ADDR_W                          ( COM_BUF_AW                      ),
        .COORD_FIFO_DEPTH                ( COORD_FIFO_DEPTH                ),
        .SB_WIDTH                        ( SB_WIDTH                        ),
        .TH_DW                           ( TH_DW                           ),
        .TW_DW                           ( TW_DW                           )
    )
    ubwc_enc_otf_to_tile_inst
    (
        .clk                             ( i_clk                           ),
        .i_otf_clk                       ( i_otf_clk                       ),
        .rst_n_sys                       ( rst_n_sys                       ),
        .rst_n_otf                       ( rst_n_otf                       ),

        .i_cfg_format                    ( otf_cfg_format                  ),
        .i_cfg_width                     ( otf_cfg_width                   ),
        .i_cfg_height                    ( otf_cfg_height                  ),
        .i_cfg_active_width              ( meta_active_width_px            ),
        .i_cfg_active_height             ( meta_active_height_px           ),
        .i_cfg_tile_w                    ( otf_cfg_tile_w                  ),
        .i_cfg_tile_h                    ( otf_cfg_tile_h                  ),
        .i_cfg_y_tile_cols               ( otf_cfg_y_tile_cols             ),
        .i_cfg_uv_tile_cols              ( otf_cfg_uv_tile_cols            ),

        .o_err_bline                     ( otf_err_bline                   ),
        .o_err_bframe                    ( otf_err_bframe                  ),
        .o_err_fifo_ovf                  ( err_fifo_ovf                    ),
        .i_err_clear                     ( enc_irq_clear_pulse             ),

        .i_otf_vsync                     ( i_otf_vsync                     ),
        .i_otf_hsync                     ( i_otf_hsync                     ),
        .i_otf_de                        ( i_otf_de                        ),
        .i_otf_data                      ( i_otf_data                      ),
        .i_otf_fcnt                      ( i_otf_fcnt                      ),
        .i_otf_lcnt                      ( i_otf_lcnt                      ),
        .o_otf_ready                     ( o_otf_ready                     ),

        .o_bank0_en                      ( o_bank0_en                      ),
        .o_bank0_wen                     ( o_bank0_wen                     ),
        .o_bank0_addr                    ( o_bank0_addr                    ),
        .o_bank0_din                     ( o_bank0_din                     ),
        .i_bank0_dout                    ( i_bank0_dout                    ),
        .i_bank0_dout_vld                ( i_bank0_dout_vld                ),

        .o_bank1_en                      ( o_bank1_en                      ),
        .o_bank1_wen                     ( o_bank1_wen                     ),
        .o_bank1_addr                    ( o_bank1_addr                    ),
        .o_bank1_din                     ( o_bank1_din                     ),
        .i_bank1_dout                    ( i_bank1_dout                    ),
        .i_bank1_dout_vld                ( i_bank1_dout_vld                ),

        .o_tile_vld                      ( rvi_valid                       ),
        .i_tile_rdy                      ( rvi_ready                       ),
        .o_tile_data                     ( rvi_data                        ),
        .o_tile_keep                     ( rvi_mask                        ),
        .o_tile_last                     ( rvi_last                        ),

        .o_ci_valid                      ( enc_ci_valid                    ),
        .i_ci_ready                      ( enc_ci_ready                    ),
        .o_ci_forced_pcm                 ( enc_ci_forced_pcm               ),
        .o_tile_x                        (                                 ),
        .o_tile_y                        (                                 ),
        .o_tile_fcnt                     ( rvi_fcnt                        ),
        .o_tile_format                   ( tile_format                     ),

        .i_co_valid                      ( enc_co_valid                    ),
        .i_co_ready                      ( enc_co_ready                    ),
        .o_co_tile_x                     ( b_tile_xcoord                   ),
        .o_co_tile_y                     ( b_tile_ycoord                   ),
        .o_co_tile_fcnt                  ( b_tile_fcnt                     ),
        .o_co_tile_format                ( b_tile_format                   ),
        .o_co_sb                         ( enc_co_sb                       ),
        .o_coord_fifo_wr_en              ( coord_fifo_wr_en                ),
        .o_coord_fifo_rd_en              ( coord_fifo_rd_en                ),
        .o_addr_cfg_done_pulse           ( enc_addr_cfg_done_pulse         ),
        .o_addr_cfg_done_slot            ( enc_addr_cfg_done_slot          ),
        .o_correct_irq_pulse             ( enc_correct_irq_pulse           ),
        .o_correct_irq_slot              ( enc_correct_irq_slot            ),
        .o_otf_de_count0                 ( enc_otf_de_count0               ),
        .o_otf_de_count1                 ( enc_otf_de_count1               ),
        .o_otf_line_count0               ( enc_otf_line_count0             ),
        .o_otf_line_count1               ( enc_otf_line_count1             )
    );

    ubwc_enc_vivo_top
    #(
        .SB_WIDTH                        ( SB_WIDTH                        )
    )
    ubwc_enc_vivo_top_inst
    (
        .i_clk                           ( i_clk                           ),

        .i_reset                         ( rst                             ),
        .i_sreset                        ( srst                            ),

        .i_ubwc_en                       ( enc_ubwc_en                     ),
        .i_ci_alen                       ( enc_ci_alen                     ),
        .i_ci_input_type                 ( enc_ci_input_type               ),
        .i_ci_forced_pcm                 ( enc_ci_forced_pcm               ),
        .i_ci_lossy                      ( enc_ci_lossy                    ),
        .i_ci_ubwc_cfg_0                 ( enc_ci_ubwc_cfg_0               ),
        .i_ci_ubwc_cfg_1                 ( enc_ci_ubwc_cfg_1               ),
        .i_ci_ubwc_cfg_2                 ( enc_ci_ubwc_cfg_2               ),
        .i_ci_ubwc_cfg_3                 ( enc_ci_ubwc_cfg_3               ),
        .i_ci_ubwc_cfg_4                 ( enc_ci_ubwc_cfg_4               ),
        .i_ci_ubwc_cfg_5                 ( enc_ci_ubwc_cfg_5               ),
        .i_ci_ubwc_cfg_6                 ( enc_ci_ubwc_cfg_6               ),
        .i_ci_ubwc_cfg_7                 ( enc_ci_ubwc_cfg_7               ),
        .i_ci_ubwc_cfg_8                 ( enc_ci_ubwc_cfg_8               ),
        .i_ci_ubwc_cfg_9                 ( enc_ci_ubwc_cfg_9               ),
        .i_ci_ubwc_cfg_10                ( enc_ci_ubwc_cfg_10              ),
        .i_ci_ubwc_cfg_11                ( enc_ci_ubwc_cfg_11              ),

        .i_ci_valid                      ( enc_ci_valid                    ),
        .o_ci_ready                      ( enc_ci_ready                    ),
        .i_ci_format                     ( tile_format                     ),

        .i_rvi_valid                     ( rvi_valid                       ),
        .o_rvi_ready                     ( rvi_ready                       ),
        .i_rvi_data                      ( rvi_data                        ),
        .i_rvi_mask                      ( rvi_mask                        ),

        .o_co_valid                      ( enc_co_valid                    ),
        .i_co_ready                      ( enc_co_ready                    ),
        .o_co_alen                       ( enc_co_alen                     ),
        .o_co_pcm                        ( enc_co_pcm                      ),

        .o_cvo_valid                     ( enc_cvo_valid                   ),
        .i_cvo_ready                     ( enc_cvo_ready                   ),
        .o_cvo_data                      ( enc_cvo_data                    ),
        .o_cvo_mask                      ( enc_cvo_mask                    ),
        .o_cvo_last                      ( enc_cvo_last                    ),

        .o_idle                          ( enc_idle                        ),
        .o_error                         ( enc_error                       )
    );

    ubwc_enc_tile_addr
    #(
        .SB_WIDTH                        ( SB_WIDTH                        ),
        .TH_DW                           ( TH_DW                           ),
        .TW_DW                           ( TW_DW                           )
    )
    ubwc_tile_addr_inst
    (
        .i_clk                           ( i_clk                           ),
        .i_rstn                          ( rst_n_sys                       ),

        .i_lvl1_bank_swizzle_en          ( lvl1_bank_swizzle_en            ),
        .i_lvl2_bank_swizzle_en          ( lvl2_bank_swizzle_en            ),
        .i_lvl3_bank_swizzle_en          ( lvl3_bank_swizzle_en            ),
        .i_highest_bank_bit              ( highest_bank_bit                ),
        .i_bank_spread_en                ( bank_spread_en                  ),
        .i_4line_format                  ( four_line_format                ),
        .i_is_lossy_rgba_2_1_format      ( is_lossy_rgba_2_1_format        ),
        .i_tile_pitch                    ( tile_pitch                      ),
        .i_y_base_offset_addr0           ( y_base_offset_addr0             ),
        .i_uv_base_offset_addr0          ( uv_base_offset_addr0            ),
        .i_y_base_offset_addr1           ( y_base_offset_addr1             ),
        .i_uv_base_offset_addr1          ( uv_base_offset_addr1            ),
        .i_addr_cfg_valid                ( active_addr_cfg_valid           ),

        .i_co_valid                      ( enc_co_fire                    ),
        .o_co_ready                      ( enc_co_ready                    ),
        .i_co_alen                       ( enc_co_alen                     ),
        .i_co_sb                         ( enc_co_sb                       ),
        .i_co_pcm                        ( enc_co_pcm                      ),
        .i_format                        ( b_tile_format                   ),
        .i_fcnt                          ( b_tile_fcnt                     ),
        .i_ycoord                        ( b_tile_ycoord                   ),
        .i_xcoord                        ( b_tile_xcoord                   ),

        .o_tile_alen                     ( tile_alen                       ),
        .o_tile_fcnt                     ( tile_addr_fcnt                  ),
        .o_tile_addr_vld                 ( tile_addr_vld                   ),
        .o_tile_addr                     ( tile_addr                       )
    );

    ubwc_enc_meta_addr_gen
    #(
        .SB_WIDTH                        ( SB_WIDTH                        ),
        .META_AW                         ( AXI_AW                          ),
        .TH_DW                           ( TH_DW                           ),
        .TW_DW                           ( TW_DW                           ),
        .IN_FIFO_DEPTH                   ( 32                              )
    )
    ubwc_enc_meta_addr_gen_inst
    (
        .i_clk                           ( i_clk                           ),
        .i_rstn                          ( rst_n_sys                       ),
        .i_srstn                         ( enc_meta_srstn                  ),
        .i_meta_data_plane_pitch         ( meta_data_plane_pitch           ),
        .i_meta_last_xcoord              ( meta_last_xcoord                ),

        .i_meta_y_base_offset_addr0      ( meta_y_base_offset_addr0        ),
        .i_meta_uv_base_offset_addr0     ( meta_uv_base_offset_addr0       ),
        .i_meta_y_base_offset_addr1      ( meta_y_base_offset_addr1        ),
        .i_meta_uv_base_offset_addr1     ( meta_uv_base_offset_addr1       ),

        .i_co_valid                      ( enc_co_fire                    ),
        .i_co_alen                       ( enc_co_alen                     ),
        .i_co_sb                         ( enc_co_sb                       ),
        .i_co_pcm                        ( enc_co_pcm                      ),
        .i_format                        ( b_tile_format                   ),
        .i_fcnt                          ( b_tile_fcnt                     ),
        .i_ycoord                        ( b_tile_ycoord                   ),
        .i_xcoord                        ( b_tile_xcoord                   ),

        .o_meta_data_valid               ( meta_data_valid                 ),
        .o_meta_data                     ( meta_data                       ),
        .i_meta_data_ready               ( meta_data_ready                 ),
        .o_meta_addr_valid               ( meta_addr_valid                 ),
        .o_meta_addr                     ( meta_addr                       ),
        .o_meta_fcnt                     ( meta_fcnt                       ),
        .i_meta_addr_ready               ( meta_addr_ready                 ),
        .o_meta_err_0                    ( meta_err_0                      ),
        .o_meta_err_1                    ( meta_err_1                      ),
        .o_frame_done                    (                                 )
    );

    ubwc_tile_enc_axi_wcmd_gen
    #(
        .AXI_AW                          ( AXI_AW                          ),
        .AXI_DW                          ( CORE_AXI_DW                     ),
        .AXI_LENW                        ( AXI_LENW                        ),
        .AXI_IDW                         ( AXI_IDW                         )
    )
    ubwc_tile_enc_axi_wcmd_gen_inst
    (
        .i_aclk                          ( i_clk                           ),
        .i_aresetn                       ( rst_n_sys                       ),

        .i_tile_addr                     ( tile_addr                       ),
        .i_tile_alen                     ( tile_alen                       ),
        .i_tile_addr_vld                 ( tile_addr_vld                   ),
        .i_axi_id                        ( tile_addr_fcnt                  ),

        .i_cvo_valid                     ( enc_cvo_valid                   ),
        .o_cvo_ready                     ( enc_cvo_ready                   ),
        .i_cvo_data                      ( enc_cvo_data                    ),
        .i_cvo_mask                      ( enc_cvo_mask                    ),
        .i_cvo_last                      ( enc_cvo_last                    ),

        .o_m_axi_awid                    ( enc_axi_awid                    ),
        .o_m_axi_awaddr                  ( enc_axi_awaddr                  ),
        .o_m_axi_awlen                   ( enc_axi_awlen                   ),
        .o_m_axi_awsize                  ( enc_axi_awsize                  ),
        .o_m_axi_awburst                 ( enc_axi_awburst                 ),
        .o_m_axi_awlock                  ( enc_axi_awlock                  ),
        .o_m_axi_awcache                 ( enc_axi_awcache                 ),
        .o_m_axi_awprot                  ( enc_axi_awprot                  ),
        .o_m_axi_awvalid                 ( enc_axi_awvalid                 ),
        .i_m_axi_awready                 ( enc_axi_awready                 ),

        .o_m_axi_wdata                   ( enc_axi_wdata                   ),
        .o_m_axi_wstrb                   ( enc_axi_wstrb                   ),
        .o_m_axi_wvalid                  ( enc_axi_wvalid                  ),
        .o_m_axi_wlast                   ( enc_axi_wlast                   ),
        .i_m_axi_wready                  ( enc_axi_wready                  ),

        .i_m_axi_bid                     ( enc_axi_bid                     ),
        .i_m_axi_bresp                   ( enc_axi_bresp                   ),
        .i_m_axi_bvalid                  ( enc_axi_bvalid                  ),
        .o_m_axi_bready                  ( enc_axi_bready                  )
    );

    ubwc_enc_meta_axi_wcmd_gen
    #(
        .AXI_AW                          ( AXI_AW                          ),
        .AXI_DW                          ( CORE_AXI_DW                     ),
        .AXI_LENW                        ( AXI_LENW                        ),
        .AXI_IDW                         ( AXI_IDW                         ),
        .META_DW                         ( 66                              )
    )
    ubwc_enc_meta_axi_wcmd_gen_inst
    (
        .i_aclk                          ( i_clk                           ),
        .i_aresetn                       ( rst_n_sys                       ),

        .i_meta_data_valid               ( meta_data_valid                 ),
        .o_meta_data_ready               ( meta_data_ready                 ),
        .i_meta_data                     ( meta_data                       ),
        .i_meta_addr_valid               ( meta_addr_valid                 ),
        .o_meta_addr_ready               ( meta_addr_ready                 ),
        .i_meta_addr                     ( meta_addr                       ),
        .i_axi_id                        ( meta_fcnt                       ),

        .o_m_axi_awid                    ( meta_axi_awid                   ),
        .o_m_axi_awaddr                  ( meta_axi_awaddr                 ),
        .o_m_axi_awlen                   ( meta_axi_awlen                  ),
        .o_m_axi_awsize                  ( meta_axi_awsize                 ),
        .o_m_axi_awburst                 ( meta_axi_awburst                ),
        .o_m_axi_awlock                  ( meta_axi_awlock                 ),
        .o_m_axi_awcache                 ( meta_axi_awcache                ),
        .o_m_axi_awprot                  ( meta_axi_awprot                 ),
        .o_m_axi_awvalid                 ( meta_axi_awvalid                ),
        .i_m_axi_awready                 ( meta_axi_awready                ),

        .o_m_axi_wdata                   ( meta_axi_wdata                  ),
        .o_m_axi_wstrb                   ( meta_axi_wstrb                  ),
        .o_m_axi_wvalid                  ( meta_axi_wvalid                 ),
        .o_m_axi_wlast                   ( meta_axi_wlast                  ),
        .i_m_axi_wready                  ( meta_axi_wready                 ),

        .i_m_axi_bid                     ( meta_axi_bid                    ),
        .i_m_axi_bresp                   ( meta_axi_bresp                  ),
        .i_m_axi_bvalid                  ( meta_axi_bvalid                 ),
        .o_m_axi_bready                  ( meta_axi_bready                 )
    );

    axi_2t1_int_DW_axi axi_2t1_int_DW_axi_inst
    (
        .aclk                            ( i_clk                           ),
        .aresetn                         ( rst_n_sys                       ),

        .awvalid_m1                      ( enc_axi_awvalid                 ),
        .awaddr_m1                       ( enc_axi_awaddr                  ),
        .awid_m1                         ( enc_axi_awid                    ),
        .awlen_m1                        ( enc_axi_awlen                   ),
        .awsize_m1                       ( enc_axi_awsize                  ),
        .awburst_m1                      ( enc_axi_awburst                 ),
        .awlock_m1                       ( enc_axi_awlock_bit              ),
        .awcache_m1                      ( enc_axi_awcache                 ),
        .awprot_m1                       ( enc_axi_awprot                  ),
        .awready_m1                      ( enc_axi_awready                 ),
        .wvalid_m1                       ( enc_axi_wvalid                  ),
        .wdata_m1                        ( enc_axi_wdata                   ),
        .wstrb_m1                        ( enc_axi_wstrb                   ),
        .wlast_m1                        ( enc_axi_wlast                   ),
        .wready_m1                       ( enc_axi_wready                  ),
        .bvalid_m1                       ( enc_axi_bvalid                  ),
        .bid_m1                          ( enc_axi_bid                     ),
        .bresp_m1                        ( enc_axi_bresp                   ),
        .bready_m1                       ( enc_axi_bready                  ),

        .arvalid_m1                      ( 1'b0                            ),
        .arid_m1                         ( axi_id_zero                ),
        .araddr_m1                       ( axi_aw_zero                ),
        .arlen_m1                        ( axi_len_zero                ),
        .arsize_m1                       ( axi_size_zero                ),
        .arburst_m1                      ( axi_burst_zero                ),
        .arlock_m1                       ( 1'b0                            ),
        .arcache_m1                      ( axi_cache_zero                ),
        .arprot_m1                       ( axi_prot_zero                ),
        .arready_m1                      (                                 ),
        .rvalid_m1                       (                                 ),
        .rid_m1                          (                                 ),
        .rdata_m1                        (                                 ),
        .rresp_m1                        (                                 ),
        .rlast_m1                        (                                 ),
        .rready_m1                       ( 1'b1                            ),

        .awvalid_m2                      ( meta_axi_awvalid                ),
        .awaddr_m2                       ( meta_axi_awaddr                 ),
        .awid_m2                         ( meta_axi_awid                   ),
        .awlen_m2                        ( meta_axi_awlen                  ),
        .awsize_m2                       ( meta_axi_awsize                 ),
        .awburst_m2                      ( meta_axi_awburst                ),
        .awlock_m2                       ( meta_axi_awlock_bit             ),
        .awcache_m2                      ( meta_axi_awcache                ),
        .awprot_m2                       ( meta_axi_awprot                 ),
        .awready_m2                      ( meta_axi_awready                ),
        .wvalid_m2                       ( meta_axi_wvalid                 ),
        .wdata_m2                        ( meta_axi_wdata                  ),
        .wstrb_m2                        ( meta_axi_wstrb                  ),
        .wlast_m2                        ( meta_axi_wlast                  ),
        .wready_m2                       ( meta_axi_wready                 ),
        .bvalid_m2                       ( meta_axi_bvalid                 ),
        .bid_m2                          ( meta_axi_bid                    ),
        .bresp_m2                        ( meta_axi_bresp                  ),
        .bready_m2                       ( meta_axi_bready                 ),
        .arvalid_m2                      ( 1'b0                            ),
        .arid_m2                         ( axi_id_zero                ),
        .araddr_m2                       ( axi_aw_zero                ),
        .arlen_m2                        ( axi_len_zero                ),
        .arsize_m2                       ( axi_size_zero                ),
        .arburst_m2                      ( axi_burst_zero                ),
        .arlock_m2                       ( 1'b0                            ),
        .arcache_m2                      ( axi_cache_zero                ),
        .arprot_m2                       ( axi_prot_zero                ),
        .arready_m2                      (                                 ),
        .rvalid_m2                       (                                 ),
        .rid_m2                          (                                 ),
        .rdata_m2                        (                                 ),
        .rresp_m2                        (                                 ),
        .rlast_m2                        (                                 ),
        .rready_m2                       ( 1'b1                            ),

        .awvalid_s1                      ( core_m_axi_awvalid              ),
        .awaddr_s1                       ( core_m_axi_awaddr               ),
        .awid_s1                         ( core_m_axi_awid                 ),
        .awlen_s1                        ( core_m_axi_awlen                ),
        .awsize_s1                       ( core_m_axi_awsize               ),
        .awburst_s1                      ( core_m_axi_awburst              ),
        .awlock_s1                       ( core_m_axi_awlock_int           ),
        .awcache_s1                      ( core_m_axi_awcache              ),
        .awprot_s1                       ( core_m_axi_awprot               ),
        .awready_s1                      ( core_m_axi_awready              ),
        .wvalid_s1                       ( core_m_axi_wvalid               ),
        .wdata_s1                        ( core_m_axi_wdata                ),
        .wstrb_s1                        ( core_m_axi_wstrb                ),
        .wlast_s1                        ( core_m_axi_wlast                ),
        .wready_s1                       ( core_m_axi_wready               ),

        .bvalid_s1                       ( core_m_axi_bvalid               ),
        .bid_s1                          ( core_m_axi_bid                  ),
        .bresp_s1                        ( core_m_axi_bresp                ),
        .bready_s1                       ( core_m_axi_bready               ),

        .arvalid_s1                      (                                 ),
        .arid_s1                         (                                 ),
        .araddr_s1                       (                                 ),
        .arlen_s1                        (                                 ),
        .arsize_s1                       (                                 ),
        .arburst_s1                      (                                 ),
        .arlock_s1                       (                                 ),
        .arcache_s1                      (                                 ),
        .arprot_s1                       (                                 ),
        .arready_s1                      ( 1'b0                            ),

        .rvalid_s1                       ( 1'b0                            ),
        .rid_s1                          ( axi_id_ext_zero             ),
        .rdata_s1                        ( core_axi_data_zero             ),
        .rresp_s1                        ( 2'd0                            ),
        .rlast_s1                        ( 1'b0                            ),
        .rready_s1                       (                                 ),

        .dbg_awid_s0                     (                                 ),
        .dbg_awaddr_s0                   (                                 ),
        .dbg_awlen_s0                    (                                 ),
        .dbg_awsize_s0                   (                                 ),
        .dbg_awburst_s0                  (                                 ),
        .dbg_awlock_s0                   (                                 ),
        .dbg_awcache_s0                  (                                 ),
        .dbg_awprot_s0                   (                                 ),
        .dbg_awvalid_s0                  (                                 ),
        .dbg_awready_s0                  (                                 ),
        .dbg_wid_s0                      (                                 ),
        .dbg_wdata_s0                    (                                 ),
        .dbg_wstrb_s0                    (                                 ),
        .dbg_wlast_s0                    (                                 ),
        .dbg_wvalid_s0                   (                                 ),
        .dbg_wready_s0                   (                                 ),
        .dbg_bid_s0                      (                                 ),
        .dbg_bresp_s0                    (                                 ),
        .dbg_bvalid_s0                   (                                 ),
        .dbg_bready_s0                   (                                 ),
        .dbg_arid_s0                     (                                 ),
        .dbg_araddr_s0                   (                                 ),
        .dbg_arlen_s0                    (                                 ),
        .dbg_arsize_s0                   (                                 ),
        .dbg_arburst_s0                  (                                 ),
        .dbg_arlock_s0                   (                                 ),
        .dbg_arcache_s0                  (                                 ),
        .dbg_arprot_s0                   (                                 ),
        .dbg_arvalid_s0                  (                                 ),
        .dbg_arready_s0                  (                                 ),
        .dbg_rid_s0                      (                                 ),
        .dbg_rdata_s0                    (                                 ),
        .dbg_rresp_s0                    (                                 ),
        .dbg_rvalid_s0                   (                                 ),
        .dbg_rlast_s0                    (                                 ),
        .dbg_rready_s0                   (                                 )
    );

    ubwc_x2x_DW_axi_x2x u_axi_wr_x2x
    (
        .aclk_m                          ( i_clk                           ),
        .aresetn_m                       ( rst_n_sys                       ),

        .awvalid_m                       ( core_m_axi_awvalid              ),
        .awaddr_m                        ( core_m_axi_awaddr               ),
        .awid_m                          ( core_m_axi_awid                 ),
        .awlen_m                         ( core_m_axi_awlen                ),
        .awsize_m                        ( core_m_axi_awsize_3b            ),
        .awburst_m                       ( core_m_axi_awburst              ),
        .awlock_m                        ( core_m_axi_awlock               ),
        .awcache_m                       ( core_m_axi_awcache              ),
        .awprot_m                        ( core_m_axi_awprot               ),
        .awready_m                       ( core_m_axi_awready              ),
        .wvalid_m                        ( core_m_axi_wvalid               ),
        .wid_m                           ( core_m_axi_awid                 ),
        .wdata_m                         ( core_m_axi_wdata                ),
        .wstrb_m                         ( core_m_axi_wstrb                ),
        .wlast_m                         ( core_m_axi_wlast                ),
        .wready_m                        ( core_m_axi_wready               ),
        .bvalid_m                        ( core_m_axi_bvalid               ),
        .bid_m                           ( core_m_axi_bid                  ),
        .bresp_m                         ( core_m_axi_bresp                ),
        .bready_m                        ( core_m_axi_bready               ),

        .arvalid_m                       ( 1'b0                            ),
        .arid_m                          ( axi_id_ext_zero             ),
        .araddr_m                        ( axi_aw_zero                  ),
        .arlen_m                         ( axi_len_zero                ),
        .arsize_m                        ( 3'd0                            ),
        .arburst_m                       ( 2'd0                            ),
        .arlock_m                        ( 2'd0                            ),
        .arcache_m                       ( 4'd0                            ),
        .arprot_m                        ( 3'd0                            ),
        .arready_m                       (                                 ),
        .rvalid_m                        (                                 ),
        .rid_m                           (                                 ),
        .rdata_m                         (                                 ),
        .rresp_m                         (                                 ),
        .rlast_m                         (                                 ),
        .rready_m                        ( 1'b1                            ),

        .awvalid_s1                      ( o_m_axi_awvalid                 ),
        .awaddr_s1                       ( o_m_axi_awaddr                  ),
        .awid_s1                         ( o_m_axi_awid                    ),
        .awlen_s1                        ( o_m_axi_awlen                   ),
        .awsize_s1                       ( o_m_axi_awsize                  ),
        .awburst_s1                      ( o_m_axi_awburst                 ),
        .awlock_s1                       ( o_m_axi_awlock                  ),
        .awcache_s1                      ( o_m_axi_awcache                 ),
        .awprot_s1                       ( o_m_axi_awprot                  ),
        .awready_s1                      ( i_m_axi_awready                 ),
        .wvalid_s1                       ( o_m_axi_wvalid                  ),
        .wid_s1                          (                                 ),
        .wdata_s1                        ( o_m_axi_wdata                   ),
        .wstrb_s1                        ( o_m_axi_wstrb                   ),
        .wlast_s1                        ( o_m_axi_wlast                   ),
        .wready_s1                       ( i_m_axi_wready                  ),
        .bvalid_s1                       ( i_m_axi_bvalid                  ),
        .bid_s1                          ( i_m_axi_bid                     ),
        .bresp_s1                        ( i_m_axi_bresp                   ),
        .bready_s1                       ( o_m_axi_bready                  ),

        .arvalid_s                       (                                 ),
        .arid_s                          (                                 ),
        .araddr_s                        (                                 ),
        .arlen_s                         (                                 ),
        .arsize_s                        (                                 ),
        .arburst_s                       (                                 ),
        .arlock_s                        (                                 ),
        .arcache_s                       (                                 ),
        .arprot_s                        (                                 ),
        .arready_s                       ( 1'b0                            ),
        .rvalid_s                        ( 1'b0                            ),
        .rid_s                           ( axi_id_ext_zero             ),
        .rdata_s                         ( axi_data_zero                  ),
        .rresp_s                         ( 2'd0                            ),
        .rlast_s                         ( 1'b0                            ),
        .rready_s                        (                                 )
    );

endmodule
