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
        parameter                                       SB_WIDTH                        = 1,
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
        output  wire    [63                     :0]         o_y_base_offset_addr0           ,
        output  wire    [63                     :0]         o_uv_base_offset_addr0          ,
        output  wire    [63                     :0]         o_meta_y_base_offset_addr0      ,
        output  wire    [63                     :0]         o_meta_uv_base_offset_addr0     ,
        output  wire    [63                     :0]         o_y_base_offset_addr1           ,
        output  wire    [63                     :0]         o_uv_base_offset_addr1          ,
        output  wire    [63                     :0]         o_meta_y_base_offset_addr1      ,
        output  wire    [63                     :0]         o_meta_uv_base_offset_addr1     ,
        output  wire    [1                      :0]         o_addr_cfg_valid                ,
        input   wire                                        i_addr_cfg_slot                 ,
        input   wire                                        i_addr_cfg_check_valid          ,
        output  wire                                        o_active_addr_cfg_valid         ,
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
        input   wire                                        i_addr_cfg_pop_toggle           ,
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
        output  wire                                        o_start_pulse                   ,
        output  wire                                        o_irq_enable                    ,
        output  wire                                        o_irq_clear_pulse               ,
        output  wire                                        o_vsync_reset_en
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
    localparam  integer                             IRQ_CTRL_VSYNC_RESET_EN_BIT     = 6;
    localparam  integer                             REG_IDX_W                       = $clog2(NREG);
    localparam  integer                             ADDR_CFG_FIFO_DEPTH             = 4;
    localparam  integer                             ADDR_CFG_FIFO_PTR_W             = 2;
    localparam  integer                             ADDR_CFG_FIFO_CNT_W             = 3;
    localparam  integer                             ADDR_CFG_W                      = 256;

    reg         [DW                  -1 :0]         regs [0:NREG-1]                 ;
    reg         [DW                  -1 :0]         r_prdata                        ;
    reg                                             start_toggle_pclk               ;
    reg                                             start_sync_ff1                  ;
    reg                                             start_sync_ff2                  ;
    reg                                             irq_clear_toggle_pclk           ;
    reg                                             irq_enable_sync_ff1             ;
    reg                                             irq_enable_sync_ff2             ;
    reg                                             irq_clear_sync_ff1              ;
    reg                                             irq_clear_sync_ff2              ;
    reg                                             vsync_reset_en_sync_ff1         ;
    reg                                             vsync_reset_en_sync_ff2         ;
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
    reg                                             addr_cfg_overflow_r             ;
    reg                                             addr_cfg_overflow_axi_ff1       ;
    reg                                             addr_cfg_overflow_axi_ff2       ;
    reg                                             addr_cfg_pop_pclk_ff1           ;
    reg                                             addr_cfg_pop_pclk_ff2           ;
    reg                                             addr_cfg_pop_pclk_ff3           ;
    reg                                             addr_cfg_push_sel               ;
    reg                                             addr_cfg_pop_sel                ;
    reg         [ADDR_CFG_FIFO_PTR_W -1 :0]         addr_cfg0_wr_ptr                ;
    reg         [ADDR_CFG_FIFO_PTR_W -1 :0]         addr_cfg0_rd_ptr                ;
    reg         [ADDR_CFG_FIFO_CNT_W -1 :0]         addr_cfg0_count                 ;
    reg         [ADDR_CFG_FIFO_PTR_W -1 :0]         addr_cfg1_wr_ptr                ;
    reg         [ADDR_CFG_FIFO_PTR_W -1 :0]         addr_cfg1_rd_ptr                ;
    reg         [ADDR_CFG_FIFO_CNT_W -1 :0]         addr_cfg1_count                 ;
    reg         [ADDR_CFG_W          -1 :0]         addr_cfg_fifo0 [0:ADDR_CFG_FIFO_DEPTH-1];
    reg         [ADDR_CFG_W          -1 :0]         addr_cfg_fifo1 [0:ADDR_CFG_FIFO_DEPTH-1];

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
    wire                                            addr_cfg_push                   ;
    wire                                            addr_cfg_pop                    ;
    wire                                            addr_cfg0_push                  ;
    wire                                            addr_cfg1_push                  ;
    wire                                            addr_cfg0_pop                   ;
    wire                                            addr_cfg1_pop                   ;
    wire                                            addr_cfg0_overflow              ;
    wire                                            addr_cfg1_overflow              ;
    wire                                            addr_cfg_overflow               ;
    wire                                            addr_cfg0_full                  ;
    wire                                            addr_cfg1_full                  ;
    wire                                            addr_cfg0_valid                 ;
    wire                                            addr_cfg1_valid                 ;
    wire                                            active_addr_cfg_valid           ;
    wire                                            addr_cfg_invalid                ;
    wire                                            error_irq_event                 ;
    wire                                            enc_ubwc_en                     ;
    wire                                            enc_ubwc_en_axi                 ;
    wire                                            enc_irq_clear_pulse             ;
    wire                                            irq_clear_pulse_axi             ;
    wire        [63                     :0]         addr_cfg_push_y_base            ;
    wire        [63                     :0]         addr_cfg_push_uv_base           ;
    wire        [63                     :0]         addr_cfg_push_meta_y_base       ;
    wire        [63                     :0]         addr_cfg_push_meta_uv_base      ;
    wire        [ADDR_CFG_W          -1 :0]         addr_cfg_push_data              ;
    wire        [ADDR_CFG_W          -1 :0]         addr_cfg0_head                  ;
    wire        [ADDR_CFG_W          -1 :0]         addr_cfg1_head                  ;

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
                else
                    regs[i] <= {DW{1'b0}};
            end
        end else if (apb_write) begin
            if (reg_addr == REG_IRQ_CTRL[AW-3:0])
                regs[REG_IRQ_CTRL] <= {{(DW-7){1'b0}}, PWDATA[IRQ_CTRL_VSYNC_RESET_EN_BIT],
                                       5'd0, PWDATA[0]};
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
            addr_cfg_pop_pclk_ff1 <= 1'b0;
        else
            addr_cfg_pop_pclk_ff1 <= i_addr_cfg_pop_toggle;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            addr_cfg_pop_pclk_ff2 <= 1'b0;
        else
            addr_cfg_pop_pclk_ff2 <= addr_cfg_pop_pclk_ff1;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            addr_cfg_pop_pclk_ff3 <= 1'b0;
        else
            addr_cfg_pop_pclk_ff3 <= addr_cfg_pop_pclk_ff2;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            addr_cfg_push_sel <= 1'b0;
        else if (addr_cfg_push && ((~addr_cfg_push_sel && !addr_cfg0_full) ||
                                   ( addr_cfg_push_sel && !addr_cfg1_full)))
            addr_cfg_push_sel <= ~addr_cfg_push_sel;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            addr_cfg_pop_sel <= 1'b0;
        else if (addr_cfg_pop && ((~addr_cfg_pop_sel && addr_cfg0_valid) ||
                                  ( addr_cfg_pop_sel && addr_cfg1_valid)))
            addr_cfg_pop_sel <= ~addr_cfg_pop_sel;
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            for (i = 0; i < ADDR_CFG_FIFO_DEPTH; i = i + 1)
                addr_cfg_fifo0[i] <= {ADDR_CFG_W{1'b0}};
        end else if (addr_cfg0_push) begin
            addr_cfg_fifo0[addr_cfg0_wr_ptr] <= addr_cfg_push_data;
        end
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            addr_cfg0_wr_ptr <= {ADDR_CFG_FIFO_PTR_W{1'b0}};
        else if (addr_cfg0_push)
            addr_cfg0_wr_ptr <= addr_cfg0_wr_ptr + {{(ADDR_CFG_FIFO_PTR_W-1){1'b0}}, 1'b1};
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            addr_cfg0_rd_ptr <= {ADDR_CFG_FIFO_PTR_W{1'b0}};
        else if (addr_cfg0_pop)
            addr_cfg0_rd_ptr <= addr_cfg0_rd_ptr + {{(ADDR_CFG_FIFO_PTR_W-1){1'b0}}, 1'b1};
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            addr_cfg0_count <= {ADDR_CFG_FIFO_CNT_W{1'b0}};
        else
            addr_cfg0_count <= addr_cfg0_count +
                               {{(ADDR_CFG_FIFO_CNT_W-1){1'b0}}, addr_cfg0_push} -
                               {{(ADDR_CFG_FIFO_CNT_W-1){1'b0}}, addr_cfg0_pop};
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            for (i = 0; i < ADDR_CFG_FIFO_DEPTH; i = i + 1)
                addr_cfg_fifo1[i] <= {ADDR_CFG_W{1'b0}};
        end else if (addr_cfg1_push) begin
            addr_cfg_fifo1[addr_cfg1_wr_ptr] <= addr_cfg_push_data;
        end
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            addr_cfg1_wr_ptr <= {ADDR_CFG_FIFO_PTR_W{1'b0}};
        else if (addr_cfg1_push)
            addr_cfg1_wr_ptr <= addr_cfg1_wr_ptr + {{(ADDR_CFG_FIFO_PTR_W-1){1'b0}}, 1'b1};
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            addr_cfg1_rd_ptr <= {ADDR_CFG_FIFO_PTR_W{1'b0}};
        else if (addr_cfg1_pop)
            addr_cfg1_rd_ptr <= addr_cfg1_rd_ptr + {{(ADDR_CFG_FIFO_PTR_W-1){1'b0}}, 1'b1};
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            addr_cfg1_count <= {ADDR_CFG_FIFO_CNT_W{1'b0}};
        else
            addr_cfg1_count <= addr_cfg1_count +
                               {{(ADDR_CFG_FIFO_CNT_W-1){1'b0}}, addr_cfg1_push} -
                               {{(ADDR_CFG_FIFO_CNT_W-1){1'b0}}, addr_cfg1_pop};
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            addr_cfg_overflow_r <= 1'b0;
        else if (!enc_ubwc_en || (apb_write && (reg_addr == REG_IRQ_CTRL[AW-3:0]) && PWDATA[1]))
            addr_cfg_overflow_r <= 1'b0;
        else if (addr_cfg_overflow)
            addr_cfg_overflow_r <= 1'b1;
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
        if (!i_rstn)
            irq_enable_sync_ff1 <= 1'b0;
        else
            irq_enable_sync_ff1 <= regs[REG_IRQ_CTRL][0];
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            irq_enable_sync_ff2 <= 1'b0;
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
            vsync_reset_en_sync_ff1 <= 1'b0;
        else
            vsync_reset_en_sync_ff1 <= regs[REG_IRQ_CTRL][IRQ_CTRL_VSYNC_RESET_EN_BIT];
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            vsync_reset_en_sync_ff2 <= 1'b0;
        else
            vsync_reset_en_sync_ff2 <= vsync_reset_en_sync_ff1;
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
            addr_cfg_overflow_axi_ff1 <= 1'b0;
        else
            addr_cfg_overflow_axi_ff1 <= addr_cfg_overflow_r;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            addr_cfg_overflow_axi_ff2 <= 1'b0;
        else
            addr_cfg_overflow_axi_ff2 <= addr_cfg_overflow_axi_ff1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            addr_cfg_invalid_r <= 1'b0;
        else if (!enc_ubwc_en_axi || enc_irq_clear_pulse)
            addr_cfg_invalid_r <= 1'b0;
        else if (addr_cfg_invalid)
            addr_cfg_invalid_r <= 1'b1;
    end

    always @(*) begin
        if (reg_addr == REG_STATUS0[AW-3:0])
            r_prdata = status0;
        else if (reg_addr == REG_STATUS1[AW-3:0])
            r_prdata = status1;
        else if (reg_addr == REG_IRQ_CTRL[AW-3:0])
            r_prdata = {{(DW-7){1'b0}}, regs[REG_IRQ_CTRL][IRQ_CTRL_VSYNC_RESET_EN_BIT],
                        1'b0, irq_error_pclk_ff2, irq_correct_pclk_ff2,
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

    assign status0                    = {{(DW-14){1'b0}},
                                         i_rst_drain_timeout,
                                         addr_cfg_overflow_r,
                                         o_addr_cfg_valid,
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

    assign o_enc_ci_input_type         = regs[REG_ENC_CI_CFG0][0];
    assign o_enc_ci_alen               = regs[REG_ENC_CI_CFG0][10:8];

    assign o_enc_ci_lossy              = regs[REG_ENC_CI_CFG1][16];

    assign o_enc_ci_ubwc_cfg_0         = regs[REG_ENC_CI_CFG2][0  +: 3];
    assign o_enc_ci_ubwc_cfg_1         = regs[REG_ENC_CI_CFG2][3  +: 3];
    assign o_enc_ci_ubwc_cfg_2         = regs[REG_ENC_CI_CFG2][6  +: 4];
    assign o_enc_ci_ubwc_cfg_3         = regs[REG_ENC_CI_CFG2][10 +: 4];
    assign o_enc_ci_ubwc_cfg_4         = regs[REG_ENC_CI_CFG2][14 +: 4];
    assign o_enc_ci_ubwc_cfg_5         = regs[REG_ENC_CI_CFG2][18 +: 4];
    assign o_enc_ci_ubwc_cfg_6         = regs[REG_ENC_CI_CFG2][22 +: 2];
    assign o_enc_ci_ubwc_cfg_7         = regs[REG_ENC_CI_CFG2][24 +: 2];
    assign o_enc_ci_ubwc_cfg_8         = regs[REG_ENC_CI_CFG2][26 +: 2];
    assign o_enc_ci_ubwc_cfg_9         = regs[REG_ENC_CI_CFG2][28 +: 3];
    assign o_enc_ci_ubwc_cfg_10        = regs[REG_ENC_CI_CFG3][0  +: 6];
    assign o_enc_ci_ubwc_cfg_11        = regs[REG_ENC_CI_CFG3][8  +: 6];

    assign enc_ubwc_en                 = regs[REG_TILE_CFG0][0];
    assign enc_ubwc_en_axi             = enc_ubwc_en_axi_ff2;
    assign o_enc_ubwc_en               = enc_ubwc_en;
    assign o_lvl1_bank_swizzle_en      = regs[REG_TILE_CFG0][1];
    assign o_lvl2_bank_swizzle_en      = regs[REG_TILE_CFG0][2];
    assign o_lvl3_bank_swizzle_en      = regs[REG_TILE_CFG0][3];
    assign o_highest_bank_bit          = regs[REG_TILE_CFG0][8  +: 5];
    assign o_bank_spread_en            = regs[REG_TILE_CFG0][16];
    assign o_4line_format              = regs[REG_TILE_CFG1][0];
    assign o_is_lossy_rgba_2_1_format  = regs[REG_TILE_CFG1][1];
    assign o_tile_pitch                = {1'b0, regs[REG_TILE_CFG1][16 +: 11]};
    assign addr_cfg_push               = apb_write && (reg_addr == REG_TILE_BASE_UV_HI[AW-3:0]);
    assign addr_cfg_pop                = addr_cfg_pop_pclk_ff2 ^ addr_cfg_pop_pclk_ff3;
    assign addr_cfg0_full              = (addr_cfg0_count == ADDR_CFG_FIFO_DEPTH[ADDR_CFG_FIFO_CNT_W-1:0]);
    assign addr_cfg1_full              = (addr_cfg1_count == ADDR_CFG_FIFO_DEPTH[ADDR_CFG_FIFO_CNT_W-1:0]);
    assign addr_cfg0_valid             = (addr_cfg0_count != {ADDR_CFG_FIFO_CNT_W{1'b0}});
    assign addr_cfg1_valid             = (addr_cfg1_count != {ADDR_CFG_FIFO_CNT_W{1'b0}});
    assign addr_cfg0_overflow          = addr_cfg_push && !addr_cfg_push_sel && addr_cfg0_full;
    assign addr_cfg1_overflow          = addr_cfg_push &&  addr_cfg_push_sel && addr_cfg1_full;
    assign addr_cfg_overflow           = addr_cfg0_overflow | addr_cfg1_overflow;
    assign addr_cfg0_push              = addr_cfg_push && !addr_cfg_push_sel && !addr_cfg0_full;
    assign addr_cfg1_push              = addr_cfg_push &&  addr_cfg_push_sel && !addr_cfg1_full;
    assign addr_cfg0_pop               = addr_cfg_pop && !addr_cfg_pop_sel && addr_cfg0_valid;
    assign addr_cfg1_pop               = addr_cfg_pop &&  addr_cfg_pop_sel && addr_cfg1_valid;
    assign addr_cfg_push_y_base        = {regs[REG_TILE_BASE_Y_HI],   regs[REG_TILE_BASE_Y_LO]};
    assign addr_cfg_push_uv_base       = {PWDATA,                     regs[REG_TILE_BASE_UV_LO]};
    assign addr_cfg_push_meta_y_base   = {regs[REG_META_BASE_Y_HI],   regs[REG_META_BASE_Y_LO]};
    assign addr_cfg_push_meta_uv_base  = {regs[REG_META_BASE_UV_HI],  regs[REG_META_BASE_UV_LO]};
    assign addr_cfg_push_data          = {addr_cfg_push_meta_uv_base,
                                          addr_cfg_push_meta_y_base,
                                          addr_cfg_push_uv_base,
                                          addr_cfg_push_y_base};
    assign addr_cfg0_head              = addr_cfg_fifo0[addr_cfg0_rd_ptr];
    assign addr_cfg1_head              = addr_cfg_fifo1[addr_cfg1_rd_ptr];
    assign active_addr_cfg_valid       = i_addr_cfg_slot ? addr_cfg1_valid : addr_cfg0_valid;
    assign addr_cfg_invalid            = i_addr_cfg_check_valid & ~active_addr_cfg_valid;
    assign error_irq_event             = addr_cfg_invalid | i_otf_to_tile_overflow |
                                         i_otf_err_bline | i_otf_err_bframe |
                                         i_meta_err_0 | i_meta_err_1 |
                                         addr_cfg_overflow_axi_ff2 |
                                         i_rst_drain_timeout | i_enc_error;
    assign o_y_base_offset_addr0       = addr_cfg0_valid ? addr_cfg0_head[0   +: 64] : 64'd0;
    assign o_uv_base_offset_addr0      = addr_cfg0_valid ? addr_cfg0_head[64  +: 64] : 64'd0;
    assign o_meta_y_base_offset_addr0  = addr_cfg0_valid ? addr_cfg0_head[128 +: 64] : 64'd0;
    assign o_meta_uv_base_offset_addr0 = addr_cfg0_valid ? addr_cfg0_head[192 +: 64] : 64'd0;
    assign o_y_base_offset_addr1       = addr_cfg1_valid ? addr_cfg1_head[0   +: 64] : 64'd0;
    assign o_uv_base_offset_addr1      = addr_cfg1_valid ? addr_cfg1_head[64  +: 64] : 64'd0;
    assign o_meta_y_base_offset_addr1  = addr_cfg1_valid ? addr_cfg1_head[128 +: 64] : 64'd0;
    assign o_meta_uv_base_offset_addr1 = addr_cfg1_valid ? addr_cfg1_head[192 +: 64] : 64'd0;
    assign o_addr_cfg_valid            = {addr_cfg1_valid, addr_cfg0_valid};
    assign o_active_addr_cfg_valid     = active_addr_cfg_valid;
    assign o_addr_cfg_invalid          = addr_cfg_invalid;
    assign o_error_irq_event           = error_irq_event;
    assign o_meta_data_plane_pitch     = regs[REG_META_PITCH];
    assign o_start_pulse               = start_sync_ff1 ^ start_sync_ff2;

    assign o_otf_cfg_format            = regs[REG_OTF_CFG0][0  +: 3];
    assign o_otf_cfg_width             = regs[REG_OTF_CFG1][0  +: 16];
    assign o_otf_cfg_height            = regs[REG_OTF_CFG1][16 +: 16];
    assign o_otf_cfg_tile_w            = regs[REG_OTF_CFG2][0  +: 16];
    assign o_otf_cfg_tile_h            = regs[REG_OTF_CFG2][16 +: 4];
    assign o_otf_cfg_y_tile_cols       = regs[REG_OTF_CFG3][0  +: 16];
    assign o_otf_cfg_uv_tile_cols       = regs[REG_OTF_CFG3][16 +: 16];
    assign total_x_units               = (o_otf_cfg_y_tile_cols >= o_otf_cfg_uv_tile_cols) ? o_otf_cfg_y_tile_cols : o_otf_cfg_uv_tile_cols;
    assign o_meta_last_xcoord          = (total_x_units == 16'd0) ? {TW_DW{1'b0}} :
                                         (total_x_units[TW_DW-1:0] - {{(TW_DW-1){1'b0}}, 1'b1});
    assign meta_active_width_px        = regs[REG_META_ACTIVE_SIZE][15:0];
    assign meta_active_height_px       = regs[REG_META_ACTIVE_SIZE][31:16];
    assign o_meta_active_width_px      = meta_active_width_px;
    assign o_meta_active_height_px     = meta_active_height_px;
    assign irq_clear_pulse_axi         = irq_clear_sync_ff1 ^ irq_clear_sync_ff2;
    assign enc_irq_clear_pulse         = irq_clear_pulse_axi;
    assign o_irq_enable                = irq_enable_sync_ff2;
    assign o_irq_clear_pulse           = irq_clear_pulse_axi;
    assign o_vsync_reset_en            = vsync_reset_en_sync_ff2;

endmodule
