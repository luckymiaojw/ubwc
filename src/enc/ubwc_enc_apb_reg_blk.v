//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-04-06
// Module Name       : ubwc_enc_apb_reg_blk.v
// Description       : APB register block for ubwc_enc_wrapper_top.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_enc_apb_reg_blk
    #(
        parameter                                       AW                              = 16,
        parameter                                       DW                              = 32,
        parameter                                       NREG                            = 64,
        parameter                                       TW_DW                           = 8
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

        input   wire                                        i_clk                           ,
        input   wire                                        i_rstn                          ,

        output  wire    [2                      :0]         o_otf_cfg_format                ,
        output  wire    [15                     :0]         o_otf_cfg_width                 ,
        output  wire    [15                     :0]         o_otf_cfg_height                ,
        output  wire    [15                     :0]         o_otf_cfg_tile_w                ,
        output  wire    [3                      :0]         o_otf_cfg_tile_h                ,
        output  wire    [15                     :0]         o_otf_cfg_y_tile_cols           ,
        output  wire    [15                     :0]         o_otf_cfg_uv_tile_cols          ,

        output  wire    [TW_DW               -1 :0]         o_meta_last_xcoord              ,
        output  wire    [15                     :0]         o_meta_active_width_px          ,
        output  wire    [15                     :0]         o_meta_active_height_px         ,
        output  wire    [31                     :0]         o_meta_data_plane_pitch         ,

        output  wire                                        o_enc_ubwc_en                   ,
        output  wire                                        o_enc_ci_input_type             ,
        output  wire    [2                      :0]         o_enc_ci_alen                   ,
        output  wire                                        o_enc_ci_lossy                  ,
        output  wire    [2                      :0]         o_enc_ci_ubwc_cfg_0             ,
        output  wire    [2                      :0]         o_enc_ci_ubwc_cfg_1             ,
        output  wire    [3                      :0]         o_enc_ci_ubwc_cfg_2             ,
        output  wire    [3                      :0]         o_enc_ci_ubwc_cfg_3             ,
        output  wire    [3                      :0]         o_enc_ci_ubwc_cfg_4             ,
        output  wire    [3                      :0]         o_enc_ci_ubwc_cfg_5             ,
        output  wire    [1                      :0]         o_enc_ci_ubwc_cfg_6             ,
        output  wire    [1                      :0]         o_enc_ci_ubwc_cfg_7             ,
        output  wire    [1                      :0]         o_enc_ci_ubwc_cfg_8             ,
        output  wire    [2                      :0]         o_enc_ci_ubwc_cfg_9             ,
        output  wire    [5                      :0]         o_enc_ci_ubwc_cfg_10            ,
        output  wire    [5                      :0]         o_enc_ci_ubwc_cfg_11            ,
        output  wire    [3                      :0]         o_enc_ci_ubwc_ver               ,

        input   wire                                        i_enc_idle                      ,
        input   wire                                        i_enc_error                     ,

        output  wire                                        o_lvl1_bank_swizzle_en          ,
        output  wire                                        o_lvl2_bank_swizzle_en          ,
        output  wire                                        o_lvl3_bank_swizzle_en          ,
        output  wire    [4                      :0]         o_highest_bank_bit              ,
        output  wire                                        o_bank_spread_en                ,
        output  wire                                        o_4line_format                  ,
        output  wire                                        o_is_lossy_rgba_2_1_format      ,
        output  wire    [11                     :0]         o_tile_pitch                    ,
        output  wire    [63                     :0]         o_y_base_offset_addr            ,
        output  wire    [63                     :0]         o_uv_base_offset_addr           ,
        output  wire    [63                     :0]         o_meta_y_base_offset_addr       ,
        output  wire    [63                     :0]         o_meta_uv_base_offset_addr      ,
        output  wire                                        o_addr_cfg_valid                ,
        input   wire                                        i_addr_cfg_check_valid          ,
        output  wire                                        o_addr_cfg_invalid              ,
        output  wire                                        o_error_irq_event               ,

        input   wire                                        i_otf_to_tile_busy              ,
        input   wire                                        i_otf_to_tile_overflow          ,
        input   wire                                        i_otf_err_bline                 ,
        input   wire                                        i_otf_err_bframe                ,
        input   wire                                        i_meta_err_0                    ,
        input   wire                                        i_meta_err_1                    ,
        input   wire                                        i_rst_drain_timeout             ,
        input   wire                                        i_frame_done                    ,
        input   wire    [7                      :0]         i_stage_done                    ,
        input   wire                                        i_irq_pending                   ,
        input   wire                                        i_irq_correct_pending           ,
        input   wire                                        i_irq_error_pending             ,
        input   wire    [31                     :0]         i_meta_count0                   ,
        input   wire    [31                     :0]         i_meta_count1                   ,
        input   wire    [31                     :0]         i_tile_addr_count0              ,
        input   wire    [31                     :0]         i_tile_addr_count1              ,
        input   wire    [31                     :0]         i_otf_tile_count0               ,
        input   wire    [31                     :0]         i_otf_tile_count1               ,
        input   wire    [31                     :0]         i_otf_de_count0                 ,
        input   wire    [31                     :0]         i_otf_de_count1                 ,
        input   wire    [31                     :0]         i_otf_line_count0               ,
        input   wire    [31                     :0]         i_otf_line_count1               ,
        input   wire    [31                     :0]         i_tile_axi_w_count0             ,
        input   wire    [31                     :0]         i_tile_axi_w_count1             ,
        input   wire    [31                     :0]         i_meta_axi_w_count0             ,
        input   wire    [31                     :0]         i_meta_axi_w_count1             ,
        output  wire                                        o_cfg_valid                     ,
        output  wire                                        o_irq_enable                    ,
        output  wire                                        o_irq_clear_pulse
    );

    localparam  [DW                  -1 :0]         REG_VERSION                     = 32'h0001_0000;
    localparam  [DW                  -1 :0]         REG_DATE                        = 32'h2026_0406;

    localparam  integer                             REG_VERSION_IDX                 = 0;
    localparam  integer                             REG_DATE_IDX                    = 1;
    localparam  integer                             REG_TILE_CFG0                   = 2;
    localparam  integer                             REG_TILE_CFG1                   = 3;
    localparam  integer                             REG_ENC_CI_CFG0                 = 4;
    localparam  integer                             REG_ENC_CI_CFG1                 = 5;
    localparam  integer                             REG_ENC_CI_CFG2                 = 6;
    localparam  integer                             REG_ENC_CI_CFG3                 = 7;
    localparam  integer                             REG_OTF_CFG0                    = 8;
    localparam  integer                             REG_OTF_CFG1                    = 9;
    localparam  integer                             REG_OTF_CFG2                    = 10;
    localparam  integer                             REG_OTF_CFG3                    = 11;
    localparam  integer                             REG_META_BASE_Y_LO              = 12; // 0x030
    localparam  integer                             REG_META_BASE_Y_HI              = 13; // 0x034
    localparam  integer                             REG_TILE_BASE_Y_LO              = 14; // 0x038
    localparam  integer                             REG_TILE_BASE_Y_HI              = 15; // 0x03C
    localparam  integer                             REG_META_BASE_UV_LO             = 16; // 0x040
    localparam  integer                             REG_META_BASE_UV_HI             = 17; // 0x044
    localparam  integer                             REG_TILE_BASE_UV_LO             = 18; // 0x048
    localparam  integer                             REG_TILE_BASE_UV_HI             = 19; // 0x04C
    localparam  integer                             REG_META_ACTIVE_SIZE            = 20;
    localparam  integer                             REG_META_PITCH                  = 21;
    localparam  integer                             REG_STATUS0                     = 22;
    localparam  integer                             REG_STATUS1                     = 23;
    localparam  integer                             REG_IRQ_CTRL                    = 24;
    localparam  integer                             REG_STATUS2                     = 25;
    localparam  integer                             REG_META_COUNT0                 = 26;
    localparam  integer                             REG_META_COUNT1                 = 27;
    localparam  integer                             REG_TILEADDR_COUNT0             = 28;
    localparam  integer                             REG_TILEADDR_COUNT1             = 29;
    localparam  integer                             REG_OTF_TILE_COUNT0             = 30;
    localparam  integer                             REG_OTF_TILE_COUNT1             = 31;
    localparam  integer                             REG_OTF_DE_COUNT0               = 32;
    localparam  integer                             REG_OTF_DE_COUNT1               = 33;
    localparam  integer                             REG_OTF_LINE_COUNT0             = 34;
    localparam  integer                             REG_OTF_LINE_COUNT1             = 35;
    localparam  integer                             REG_TILE_AXI_W_CNT0             = 36;
    localparam  integer                             REG_TILE_AXI_W_CNT1             = 37;
    localparam  integer                             REG_META_AXI_W_CNT0             = 38;
    localparam  integer                             REG_META_AXI_W_CNT1             = 39;
    localparam  integer                             IRQ_CTRL_START_BIT              = 5;
    localparam  integer                             REG_IDX_W                       = $clog2(NREG);
    localparam  integer                             ADDR_CFG_W                      = 256;
    localparam  [2                      :0]         FMT_RGBA8888                    = 3'd0;
    localparam  [2                      :0]         FMT_RGBA10                      = 3'd1;
    localparam  [2                      :0]         FMT_YUV420_8                    = 3'd2;
    localparam  [2                      :0]         FMT_YUV420_10                   = 3'd3;

    reg         [DW                  -1 :0]         regs [0:NREG-1]                 ;
    reg         [DW                  -1 :0]         r_prdata                        ;
    reg         [DW                  -1 :0]         cfg_tile_cfg0_r                 ;
    reg         [DW                  -1 :0]         cfg_tile_cfg1_r                 ;
    reg         [DW                  -1 :0]         cfg_enc_ci_cfg0_r               ;
    reg         [DW                  -1 :0]         cfg_enc_ci_cfg1_r               ;
    reg         [DW                  -1 :0]         cfg_enc_ci_cfg2_r               ;
    reg         [DW                  -1 :0]         cfg_enc_ci_cfg3_r               ;
    reg         [DW                  -1 :0]         cfg_otf_cfg0_r                  ;
    reg         [DW                  -1 :0]         cfg_otf_cfg1_r                  ;
    reg         [DW                  -1 :0]         cfg_otf_cfg2_r                  ;
    reg         [DW                  -1 :0]         cfg_otf_cfg3_r                  ;
    reg         [DW                  -1 :0]         cfg_meta_active_size_r          ;
    reg         [DW                  -1 :0]         cfg_meta_pitch_r                ;
    reg         [ADDR_CFG_W          -1 :0]         cfg_addr_r                      ;
    reg                                             cfg_addr_valid_r                ;
    reg                                             cfg_valid_r                     ;
    reg                                             start_toggle_pclk               ;
    reg                                             start_sync_ff1                  ;
    reg                                             start_sync_ff2                  ;
    reg                                             irq_clear_toggle_pclk           ;
    reg                                             irq_enable_sync_ff1             ;
    reg                                             irq_enable_sync_ff2             ;
    reg                                             irq_clear_sync_ff1              ;
    reg                                             irq_clear_sync_ff2              ;
    reg                                             cfg_valid_pclk_ff1              ;
    reg                                             cfg_valid_pclk_ff2              ;
    reg                                             cfg_addr_valid_pclk_ff1         ;
    reg                                             cfg_addr_valid_pclk_ff2         ;
    reg                                             irq_pending_pclk_ff1            ;
    reg                                             irq_pending_pclk_ff2            ;
    reg                                             irq_correct_pclk_ff1            ;
    reg                                             irq_correct_pclk_ff2            ;
    reg                                             irq_error_pclk_ff1              ;
    reg                                             irq_error_pclk_ff2              ;
    reg         [31                     :0]         meta_count0_pclk_ff1            ;
    reg         [31                     :0]         meta_count0_pclk_ff2            ;
    reg         [31                     :0]         meta_count1_pclk_ff1            ;
    reg         [31                     :0]         meta_count1_pclk_ff2            ;
    reg         [31                     :0]         tile_addr_count0_pclk_ff1       ;
    reg         [31                     :0]         tile_addr_count0_pclk_ff2       ;
    reg         [31                     :0]         tile_addr_count1_pclk_ff1       ;
    reg         [31                     :0]         tile_addr_count1_pclk_ff2       ;
    reg         [31                     :0]         otf_tile_count0_pclk_ff1        ;
    reg         [31                     :0]         otf_tile_count0_pclk_ff2        ;
    reg         [31                     :0]         otf_tile_count1_pclk_ff1        ;
    reg         [31                     :0]         otf_tile_count1_pclk_ff2        ;
    reg         [31                     :0]         otf_de_count0_pclk_ff1          ;
    reg         [31                     :0]         otf_de_count0_pclk_ff2          ;
    reg         [31                     :0]         otf_de_count1_pclk_ff1          ;
    reg         [31                     :0]         otf_de_count1_pclk_ff2          ;
    reg         [31                     :0]         otf_line_count0_pclk_ff1        ;
    reg         [31                     :0]         otf_line_count0_pclk_ff2        ;
    reg         [31                     :0]         otf_line_count1_pclk_ff1        ;
    reg         [31                     :0]         otf_line_count1_pclk_ff2        ;
    reg         [31                     :0]         tile_axi_w_count0_pclk_ff1      ;
    reg         [31                     :0]         tile_axi_w_count0_pclk_ff2      ;
    reg         [31                     :0]         tile_axi_w_count1_pclk_ff1      ;
    reg         [31                     :0]         tile_axi_w_count1_pclk_ff2      ;
    reg         [31                     :0]         meta_axi_w_count0_pclk_ff1      ;
    reg         [31                     :0]         meta_axi_w_count0_pclk_ff2      ;
    reg         [31                     :0]         meta_axi_w_count1_pclk_ff1      ;
    reg         [31                     :0]         meta_axi_w_count1_pclk_ff2      ;
    reg                                             enc_ubwc_en_axi_ff1             ;
    reg                                             enc_ubwc_en_axi_ff2             ;
    reg                                             addr_cfg_invalid_r              ;
    reg                                             addr_cfg_work_valid_r           ;
    reg                                             addr_cfg_work_valid_axi_ff1     ;
    reg                                             addr_cfg_work_valid_axi_ff2     ;

    wire                                            apb_access                      ;

    assign apb_access = PSEL && PENABLE;
    wire                                            apb_write                       ;
    assign apb_write = apb_access && PWRITE;
    wire        [AW                  -3 :0]         reg_addr                        ;
    assign reg_addr = PADDR[AW-1:2];
    wire        [REG_IDX_W           -1 :0]         reg_idx                         ;
    assign reg_idx = reg_addr[REG_IDX_W-1:0];
    wire        [15                     :0]         meta_active_width_px            ;
    wire        [15                     :0]         meta_active_height_px           ;
    wire        [15                     :0]         total_x_units                   ;
    wire        [DW                  -1 :0]         status0                         ;
    wire        [DW                  -1 :0]         status1                         ;
    wire        [DW                  -1 :0]         status2                         ;
    wire                                            addr_cfg_reg_write              ;
    wire                                            addr_cfg_invalid                ;
    wire                                            error_irq_event                 ;
    wire                                            enc_ubwc_en                     ;
    wire                                            enc_ubwc_en_axi                 ;
    wire                                            enc_irq_clear_pulse             ;
    wire                                            irq_clear_pulse_axi             ;
    wire                                            start_pulse_axi                 ;
    wire                                            cfg_format_supported            ;
    wire                                            cfg_is_yuv420                   ;
    wire                                            cfg_geometry_valid              ;
    wire                                            cfg_address_valid               ;
    wire                                            cfg_commit_valid                ;
    wire        [63                     :0]         addr_cfg_y_base                 ;
    wire        [63                     :0]         addr_cfg_uv_base                ;
    wire        [63                     :0]         addr_cfg_meta_y_base            ;
    wire        [63                     :0]         addr_cfg_meta_uv_base           ;
    wire        [ADDR_CFG_W          -1 :0]         addr_cfg_work_data              ;

    integer i;

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;
    assign PRDATA  = r_prdata;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            for (i = 0; i < NREG; i = i + 1) begin
                if (i == REG_VERSION_IDX)
                    regs[i] <= REG_VERSION;
                else if (i == REG_DATE_IDX)
                    regs[i] <= REG_DATE;
                else if (i == REG_IRQ_CTRL)
                    regs[i] <= {{(DW-1){1'b0}}, 1'b1};
                else if (i == REG_ENC_CI_CFG3)
                    regs[i] <= {12'd0,4'd7,16'd0};
                else
                    regs[i] <= {DW{1'b0}};
            end
        end else if (apb_write) begin
            if (reg_addr == REG_IRQ_CTRL[AW-3:0])
                regs[REG_IRQ_CTRL] <= {{(DW-1){1'b0}}, PWDATA[0]};
            else if ((reg_addr > REG_DATE_IDX[AW-3:0]) && (reg_addr < NREG) &&
                (reg_addr != REG_STATUS0[AW-3:0]) &&
                (reg_addr != REG_STATUS1[AW-3:0]))
                regs[reg_idx] <= PWDATA;
        end
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            start_toggle_pclk <= 1'b0;
        else if (apb_write && (reg_addr == REG_IRQ_CTRL[AW-3:0]) &&
                 PWDATA[IRQ_CTRL_START_BIT])
            start_toggle_pclk <= ~start_toggle_pclk;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            irq_clear_toggle_pclk <= 1'b0;
        else if (apb_write && (reg_addr == REG_IRQ_CTRL[AW-3:0]) && PWDATA[1])
            irq_clear_toggle_pclk <= ~irq_clear_toggle_pclk;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            addr_cfg_work_valid_r <= 1'b0;
        else if (addr_cfg_reg_write)
            addr_cfg_work_valid_r <= (reg_addr == REG_TILE_BASE_UV_HI[AW-3:0]);
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            irq_pending_pclk_ff1 <= 1'b0;
        else
            irq_pending_pclk_ff1 <= i_irq_pending;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            irq_pending_pclk_ff2 <= 1'b0;
        else
            irq_pending_pclk_ff2 <= irq_pending_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            irq_correct_pclk_ff1 <= 1'b0;
        else
            irq_correct_pclk_ff1 <= i_irq_correct_pending;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            irq_correct_pclk_ff2 <= 1'b0;
        else
            irq_correct_pclk_ff2 <= irq_correct_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            irq_error_pclk_ff1 <= 1'b0;
        else
            irq_error_pclk_ff1 <= i_irq_error_pending;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            irq_error_pclk_ff2 <= 1'b0;
        else
            irq_error_pclk_ff2 <= irq_error_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            meta_count0_pclk_ff1 <= 32'd0;
        else
            meta_count0_pclk_ff1 <= i_meta_count0;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            meta_count0_pclk_ff2 <= 32'd0;
        else
            meta_count0_pclk_ff2 <= meta_count0_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            meta_count1_pclk_ff1 <= 32'd0;
        else
            meta_count1_pclk_ff1 <= i_meta_count1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            meta_count1_pclk_ff2 <= 32'd0;
        else
            meta_count1_pclk_ff2 <= meta_count1_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            tile_addr_count0_pclk_ff1 <= 32'd0;
        else
            tile_addr_count0_pclk_ff1 <= i_tile_addr_count0;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            tile_addr_count0_pclk_ff2 <= 32'd0;
        else
            tile_addr_count0_pclk_ff2 <= tile_addr_count0_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            tile_addr_count1_pclk_ff1 <= 32'd0;
        else
            tile_addr_count1_pclk_ff1 <= i_tile_addr_count1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            tile_addr_count1_pclk_ff2 <= 32'd0;
        else
            tile_addr_count1_pclk_ff2 <= tile_addr_count1_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            otf_tile_count0_pclk_ff1 <= 32'd0;
        else
            otf_tile_count0_pclk_ff1 <= i_otf_tile_count0;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            otf_tile_count0_pclk_ff2 <= 32'd0;
        else
            otf_tile_count0_pclk_ff2 <= otf_tile_count0_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            otf_tile_count1_pclk_ff1 <= 32'd0;
        else
            otf_tile_count1_pclk_ff1 <= i_otf_tile_count1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            otf_tile_count1_pclk_ff2 <= 32'd0;
        else
            otf_tile_count1_pclk_ff2 <= otf_tile_count1_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            otf_de_count0_pclk_ff1 <= 32'd0;
        else
            otf_de_count0_pclk_ff1 <= i_otf_de_count0;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            otf_de_count0_pclk_ff2 <= 32'd0;
        else
            otf_de_count0_pclk_ff2 <= otf_de_count0_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            otf_de_count1_pclk_ff1 <= 32'd0;
        else
            otf_de_count1_pclk_ff1 <= i_otf_de_count1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            otf_de_count1_pclk_ff2 <= 32'd0;
        else
            otf_de_count1_pclk_ff2 <= otf_de_count1_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            otf_line_count0_pclk_ff1 <= 32'd0;
        else
            otf_line_count0_pclk_ff1 <= i_otf_line_count0;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            otf_line_count0_pclk_ff2 <= 32'd0;
        else
            otf_line_count0_pclk_ff2 <= otf_line_count0_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            otf_line_count1_pclk_ff1 <= 32'd0;
        else
            otf_line_count1_pclk_ff1 <= i_otf_line_count1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            otf_line_count1_pclk_ff2 <= 32'd0;
        else
            otf_line_count1_pclk_ff2 <= otf_line_count1_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            tile_axi_w_count0_pclk_ff1 <= 32'd0;
        else
            tile_axi_w_count0_pclk_ff1 <= i_tile_axi_w_count0;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            tile_axi_w_count0_pclk_ff2 <= 32'd0;
        else
            tile_axi_w_count0_pclk_ff2 <= tile_axi_w_count0_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            tile_axi_w_count1_pclk_ff1 <= 32'd0;
        else
            tile_axi_w_count1_pclk_ff1 <= i_tile_axi_w_count1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            tile_axi_w_count1_pclk_ff2 <= 32'd0;
        else
            tile_axi_w_count1_pclk_ff2 <= tile_axi_w_count1_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            meta_axi_w_count0_pclk_ff1 <= 32'd0;
        else
            meta_axi_w_count0_pclk_ff1 <= i_meta_axi_w_count0;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            meta_axi_w_count0_pclk_ff2 <= 32'd0;
        else
            meta_axi_w_count0_pclk_ff2 <= meta_axi_w_count0_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            meta_axi_w_count1_pclk_ff1 <= 32'd0;
        else
            meta_axi_w_count1_pclk_ff1 <= i_meta_axi_w_count1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            meta_axi_w_count1_pclk_ff2 <= 32'd0;
        else
            meta_axi_w_count1_pclk_ff2 <= meta_axi_w_count1_pclk_ff1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            start_sync_ff1 <= 1'b0;
        else
            start_sync_ff1 <= start_toggle_pclk;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            start_sync_ff2 <= 1'b0;
        else
            start_sync_ff2 <= start_sync_ff1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            cfg_tile_cfg0_r        <= {DW{1'b0}};
            cfg_tile_cfg1_r        <= {DW{1'b0}};
            cfg_enc_ci_cfg0_r      <= {DW{1'b0}};
            cfg_enc_ci_cfg1_r      <= {DW{1'b0}};
            cfg_enc_ci_cfg2_r      <= {DW{1'b0}};
            cfg_enc_ci_cfg3_r      <= {DW{1'b0}};
            cfg_otf_cfg0_r         <= {DW{1'b0}};
            cfg_otf_cfg1_r         <= {DW{1'b0}};
            cfg_otf_cfg2_r         <= {DW{1'b0}};
            cfg_otf_cfg3_r         <= {DW{1'b0}};
            cfg_meta_active_size_r <= {DW{1'b0}};
            cfg_meta_pitch_r       <= {DW{1'b0}};
            cfg_addr_r             <= {ADDR_CFG_W{1'b0}};
            cfg_addr_valid_r       <= 1'b0;
            cfg_valid_r            <= 1'b0;
        end else if (start_pulse_axi) begin
            cfg_tile_cfg0_r        <= regs[REG_TILE_CFG0];
            cfg_tile_cfg1_r        <= regs[REG_TILE_CFG1];
            cfg_enc_ci_cfg0_r      <= regs[REG_ENC_CI_CFG0];
            cfg_enc_ci_cfg1_r      <= regs[REG_ENC_CI_CFG1];
            cfg_enc_ci_cfg2_r      <= regs[REG_ENC_CI_CFG2];
            cfg_enc_ci_cfg3_r      <= regs[REG_ENC_CI_CFG3];
            cfg_otf_cfg0_r         <= regs[REG_OTF_CFG0];
            cfg_otf_cfg1_r         <= regs[REG_OTF_CFG1];
            cfg_otf_cfg2_r         <= regs[REG_OTF_CFG2];
            cfg_otf_cfg3_r         <= regs[REG_OTF_CFG3];
            cfg_meta_active_size_r <= regs[REG_META_ACTIVE_SIZE];
            cfg_meta_pitch_r       <= regs[REG_META_PITCH];
            cfg_addr_r             <= addr_cfg_work_data;
            cfg_addr_valid_r       <= cfg_address_valid;
            cfg_valid_r            <= cfg_commit_valid;
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            irq_enable_sync_ff1 <= 1'b1;
        else
            irq_enable_sync_ff1 <= regs[REG_IRQ_CTRL][0];
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            irq_enable_sync_ff2 <= 1'b1;
        else
            irq_enable_sync_ff2 <= irq_enable_sync_ff1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            irq_clear_sync_ff1 <= 1'b0;
        else
            irq_clear_sync_ff1 <= irq_clear_toggle_pclk;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            irq_clear_sync_ff2 <= 1'b0;
        else
            irq_clear_sync_ff2 <= irq_clear_sync_ff1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            enc_ubwc_en_axi_ff1 <= 1'b0;
        else
            enc_ubwc_en_axi_ff1 <= enc_ubwc_en;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            enc_ubwc_en_axi_ff2 <= 1'b0;
        else
            enc_ubwc_en_axi_ff2 <= enc_ubwc_en_axi_ff1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            addr_cfg_work_valid_axi_ff1 <= 1'b0;
        else
            addr_cfg_work_valid_axi_ff1 <= addr_cfg_work_valid_r;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            addr_cfg_work_valid_axi_ff2 <= 1'b0;
        else
            addr_cfg_work_valid_axi_ff2 <= addr_cfg_work_valid_axi_ff1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            addr_cfg_invalid_r <= 1'b0;
        else if (!enc_ubwc_en_axi || enc_irq_clear_pulse)
            addr_cfg_invalid_r <= 1'b0;
        else if (addr_cfg_invalid)
            addr_cfg_invalid_r <= 1'b1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            cfg_valid_pclk_ff1 <= 1'b0;
        else
            cfg_valid_pclk_ff1 <= cfg_valid_r;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            cfg_valid_pclk_ff2 <= 1'b0;
        else
            cfg_valid_pclk_ff2 <= cfg_valid_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            cfg_addr_valid_pclk_ff1 <= 1'b0;
        else
            cfg_addr_valid_pclk_ff1 <= cfg_addr_valid_r;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            cfg_addr_valid_pclk_ff2 <= 1'b0;
        else
            cfg_addr_valid_pclk_ff2 <= cfg_addr_valid_pclk_ff1;
    end

    always @(*) begin
        if (reg_addr == REG_STATUS0[AW-3:0])
            r_prdata = status0;
        else if (reg_addr == REG_STATUS1[AW-3:0])
            r_prdata = status1;
        else if (reg_addr == REG_IRQ_CTRL[AW-3:0])
            r_prdata = {{(DW-5){1'b0}}, irq_error_pclk_ff2, irq_correct_pclk_ff2,
                        irq_pending_pclk_ff2, 1'b0, regs[REG_IRQ_CTRL][0]};
        else if (reg_addr == REG_STATUS2[AW-3:0])
            r_prdata = status2;
        else if (reg_addr == REG_META_COUNT0[AW-3:0])
            r_prdata = meta_count0_pclk_ff2;
        else if (reg_addr == REG_META_COUNT1[AW-3:0])
            r_prdata = meta_count1_pclk_ff2;
        else if (reg_addr == REG_TILEADDR_COUNT0[AW-3:0])
            r_prdata = tile_addr_count0_pclk_ff2;
        else if (reg_addr == REG_TILEADDR_COUNT1[AW-3:0])
            r_prdata = tile_addr_count1_pclk_ff2;
        else if (reg_addr == REG_OTF_TILE_COUNT0[AW-3:0])
            r_prdata = otf_tile_count0_pclk_ff2;
        else if (reg_addr == REG_OTF_TILE_COUNT1[AW-3:0])
            r_prdata = otf_tile_count1_pclk_ff2;
        else if (reg_addr == REG_OTF_DE_COUNT0[AW-3:0])
            r_prdata = otf_de_count0_pclk_ff2;
        else if (reg_addr == REG_OTF_DE_COUNT1[AW-3:0])
            r_prdata = otf_de_count1_pclk_ff2;
        else if (reg_addr == REG_OTF_LINE_COUNT0[AW-3:0])
            r_prdata = otf_line_count0_pclk_ff2;
        else if (reg_addr == REG_OTF_LINE_COUNT1[AW-3:0])
            r_prdata = otf_line_count1_pclk_ff2;
        else if (reg_addr == REG_TILE_AXI_W_CNT0[AW-3:0])
            r_prdata = tile_axi_w_count0_pclk_ff2;
        else if (reg_addr == REG_TILE_AXI_W_CNT1[AW-3:0])
            r_prdata = tile_axi_w_count1_pclk_ff2;
        else if (reg_addr == REG_META_AXI_W_CNT0[AW-3:0])
            r_prdata = meta_axi_w_count0_pclk_ff2;
        else if (reg_addr == REG_META_AXI_W_CNT1[AW-3:0])
            r_prdata = meta_axi_w_count1_pclk_ff2;
        else if (reg_addr < NREG)
            r_prdata = regs[reg_idx];
        else
            r_prdata = {DW{1'b0}};
    end

    assign status0                    = {{(DW-15){1'b0}},
                                         cfg_valid_pclk_ff2,
                                         i_rst_drain_timeout,
                                         2'b00,
                                         cfg_addr_valid_pclk_ff2,
                                         addr_cfg_invalid_r,
                                         i_frame_done,
                                         i_meta_err_1,
                                         i_meta_err_0,
                                         i_otf_err_bframe,
                                         i_otf_err_bline,
                                         i_otf_to_tile_overflow,
                                         i_otf_to_tile_busy,
                                         i_enc_error,
                                         i_enc_idle};
    assign status1                    = {{(DW-8){1'b0}}, i_stage_done};
    assign status2                    = {{(DW-3){1'b0}}, irq_error_pclk_ff2,
                                         irq_correct_pclk_ff2, irq_pending_pclk_ff2};

    assign o_enc_ci_input_type         = cfg_enc_ci_cfg0_r[0];
    assign o_enc_ci_alen               = cfg_enc_ci_cfg0_r[10:8];

    assign o_enc_ci_lossy              = cfg_enc_ci_cfg1_r[16];

    assign o_enc_ci_ubwc_cfg_0         = cfg_enc_ci_cfg2_r[0  +: 3];
    assign o_enc_ci_ubwc_cfg_1         = cfg_enc_ci_cfg2_r[3  +: 3];
    assign o_enc_ci_ubwc_cfg_2         = cfg_enc_ci_cfg2_r[6  +: 4];
    assign o_enc_ci_ubwc_cfg_3         = cfg_enc_ci_cfg2_r[10 +: 4];
    assign o_enc_ci_ubwc_cfg_4         = cfg_enc_ci_cfg2_r[14 +: 4];
    assign o_enc_ci_ubwc_cfg_5         = cfg_enc_ci_cfg2_r[18 +: 4];
    assign o_enc_ci_ubwc_cfg_6         = cfg_enc_ci_cfg2_r[22 +: 2];
    assign o_enc_ci_ubwc_cfg_7         = cfg_enc_ci_cfg2_r[24 +: 2];
    assign o_enc_ci_ubwc_cfg_8         = cfg_enc_ci_cfg2_r[26 +: 2];
    assign o_enc_ci_ubwc_cfg_9         = cfg_enc_ci_cfg2_r[28 +: 3];
    assign o_enc_ci_ubwc_cfg_10        = cfg_enc_ci_cfg3_r[0  +: 6];
    assign o_enc_ci_ubwc_cfg_11        = cfg_enc_ci_cfg3_r[8  +: 6];
    assign o_enc_ci_ubwc_ver           = cfg_enc_ci_cfg3_r[16 +: 4];

    assign enc_ubwc_en                 = regs[REG_TILE_CFG0][0];
    assign enc_ubwc_en_axi             = enc_ubwc_en_axi_ff2;
    assign o_enc_ubwc_en               = cfg_tile_cfg0_r[0];
    assign o_lvl1_bank_swizzle_en      = cfg_tile_cfg0_r[1];
    assign o_lvl2_bank_swizzle_en      = cfg_tile_cfg0_r[2];
    assign o_lvl3_bank_swizzle_en      = cfg_tile_cfg0_r[3];
    assign o_highest_bank_bit          = cfg_tile_cfg0_r[8  +: 5];
    assign o_bank_spread_en            = cfg_tile_cfg0_r[16];
    assign o_4line_format              = cfg_tile_cfg1_r[0];
    assign o_is_lossy_rgba_2_1_format  = cfg_tile_cfg1_r[1];
    assign o_tile_pitch                = {1'b0, cfg_tile_cfg1_r[16 +: 11]};
    assign addr_cfg_reg_write          = apb_write &&
                                         (reg_addr >= REG_META_BASE_Y_LO[AW-3:0]) &&
                                         (reg_addr <= REG_TILE_BASE_UV_HI[AW-3:0]);
    assign addr_cfg_y_base             = {regs[REG_TILE_BASE_Y_HI],  regs[REG_TILE_BASE_Y_LO]};
    assign addr_cfg_uv_base            = {regs[REG_TILE_BASE_UV_HI], regs[REG_TILE_BASE_UV_LO]};
    assign addr_cfg_meta_y_base        = {regs[REG_META_BASE_Y_HI],  regs[REG_META_BASE_Y_LO]};
    assign addr_cfg_meta_uv_base       = {regs[REG_META_BASE_UV_HI], regs[REG_META_BASE_UV_LO]};
    assign addr_cfg_work_data          = {addr_cfg_meta_uv_base,
                                          addr_cfg_meta_y_base,
                                          addr_cfg_uv_base,
                                          addr_cfg_y_base};
    assign addr_cfg_invalid            = i_addr_cfg_check_valid & ~cfg_addr_valid_r;
    assign error_irq_event             = addr_cfg_invalid | i_otf_to_tile_overflow |
                                         i_otf_err_bline | i_otf_err_bframe |
                                         i_meta_err_0 | i_meta_err_1 |
                                         i_rst_drain_timeout | i_enc_error;
    assign o_y_base_offset_addr        = cfg_addr_valid_r ? cfg_addr_r[0   +: 64] : 64'd0;
    assign o_uv_base_offset_addr       = cfg_addr_valid_r ? cfg_addr_r[64  +: 64] : 64'd0;
    assign o_meta_y_base_offset_addr   = cfg_addr_valid_r ? cfg_addr_r[128 +: 64] : 64'd0;
    assign o_meta_uv_base_offset_addr  = cfg_addr_valid_r ? cfg_addr_r[192 +: 64] : 64'd0;
    assign o_addr_cfg_valid            = cfg_addr_valid_r;
    assign o_addr_cfg_invalid          = addr_cfg_invalid;
    assign o_error_irq_event           = error_irq_event;
    assign o_meta_data_plane_pitch     = cfg_meta_pitch_r;
    assign start_pulse_axi             = start_sync_ff1 ^ start_sync_ff2;
    assign cfg_format_supported        = (regs[REG_OTF_CFG0][2:0] == FMT_RGBA8888) ||
                                         (regs[REG_OTF_CFG0][2:0] == FMT_RGBA10)   ||
                                         (regs[REG_OTF_CFG0][2:0] == FMT_YUV420_8) ||
                                         (regs[REG_OTF_CFG0][2:0] == FMT_YUV420_10);
    assign cfg_is_yuv420               = (regs[REG_OTF_CFG0][2:0] == FMT_YUV420_8) ||
                                         (regs[REG_OTF_CFG0][2:0] == FMT_YUV420_10);
    assign cfg_geometry_valid          = (regs[REG_OTF_CFG1][15:0]  != 16'd0) &&
                                         (regs[REG_OTF_CFG1][31:16] != 16'd0) &&
                                         (regs[REG_OTF_CFG2][15:0]  != 16'd0) &&
                                         (regs[REG_OTF_CFG2][19:16] != 4'd0)  &&
                                         (regs[REG_OTF_CFG3][15:0]  != 16'd0) &&
                                         (!cfg_is_yuv420 || (regs[REG_OTF_CFG3][31:16] != 16'd0)) &&
                                         (regs[REG_META_ACTIVE_SIZE][15:0]  != 16'd0) &&
                                         (regs[REG_META_ACTIVE_SIZE][31:16] != 16'd0) &&
                                         (regs[REG_META_PITCH] != {DW{1'b0}}) &&
                                         (regs[REG_TILE_CFG1][26:16] != 11'd0);
    assign cfg_address_valid           = addr_cfg_work_valid_axi_ff2;
    assign cfg_commit_valid            = enc_ubwc_en && cfg_format_supported &&
                                         cfg_geometry_valid && cfg_address_valid;
    assign o_cfg_valid                 = cfg_valid_r;

    assign o_otf_cfg_format            = cfg_otf_cfg0_r[0  +: 3];
    assign o_otf_cfg_width             = cfg_otf_cfg1_r[0  +: 16];
    assign o_otf_cfg_height            = cfg_otf_cfg1_r[16 +: 16];
    assign o_otf_cfg_tile_w            = cfg_otf_cfg2_r[0  +: 16];
    assign o_otf_cfg_tile_h            = cfg_otf_cfg2_r[16 +: 4];
    assign o_otf_cfg_y_tile_cols       = cfg_otf_cfg3_r[0  +: 16];
    assign o_otf_cfg_uv_tile_cols      = cfg_otf_cfg3_r[16 +: 16];
    assign total_x_units               = (o_otf_cfg_y_tile_cols >= o_otf_cfg_uv_tile_cols) ? o_otf_cfg_y_tile_cols : o_otf_cfg_uv_tile_cols;
    assign o_meta_last_xcoord          = (total_x_units == 16'd0) ? {TW_DW{1'b0}} :
                                         (total_x_units[TW_DW-1:0] - {{(TW_DW-1){1'b0}}, 1'b1});
    assign meta_active_width_px        = cfg_meta_active_size_r[15:0];
    assign meta_active_height_px       = cfg_meta_active_size_r[31:16];
    assign o_meta_active_width_px      = meta_active_width_px;
    assign o_meta_active_height_px     = meta_active_height_px;
    assign irq_clear_pulse_axi         = irq_clear_sync_ff1 ^ irq_clear_sync_ff2;
    assign enc_irq_clear_pulse         = irq_clear_pulse_axi;
    assign o_irq_enable                = irq_enable_sync_ff2;
    assign o_irq_clear_pulse           = irq_clear_pulse_axi;

endmodule
