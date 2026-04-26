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
        parameter AW       = 16,
        parameter DW       = 32,
        parameter NREG     = 64,
        parameter SB_WIDTH = 1,
        parameter TW_DW    = 8
    )(
        input   wire                    PCLK,
        input   wire                    PRESETn,
        input   wire                    PSEL,
        input   wire                    PENABLE,
        input   wire    [AW-1:0]        PADDR,
        input   wire                    PWRITE,
        input   wire    [DW-1:0]        PWDATA,
        output  wire                    PREADY,
        output  wire                    PSLVERR,
        output  wire    [DW-1:0]        PRDATA,

        output  wire    [2:0]           o_otf_cfg_format,
        output  wire    [15:0]          o_otf_cfg_width,
        output  wire    [15:0]          o_otf_cfg_height,
        output  wire    [15:0]          o_otf_cfg_tile_w,
        output  wire    [3:0]           o_otf_cfg_tile_h,
        output  wire    [15:0]          o_otf_cfg_a_tile_cols,
        output  wire    [15:0]          o_otf_cfg_b_tile_cols,
        output  wire    [TW_DW-1:0]     o_meta_last_xcoord,
        output  wire    [15:0]          o_meta_active_width_px,
        output  wire    [15:0]          o_meta_active_height_px,
        output  wire    [31:0]          o_meta_data_plane_pitch,

        output  wire                    o_enc_ubwc_en,
        output  wire                    o_enc_ci_input_type,
        output  wire    [2:0]           o_enc_ci_alen,
        output  wire    [SB_WIDTH-1:0]  o_enc_ci_sb,
        output  wire                    o_enc_ci_lossy,
        output  wire    [2:0]           o_enc_ci_ubwc_cfg_0,
        output  wire    [2:0]           o_enc_ci_ubwc_cfg_1,
        output  wire    [3:0]           o_enc_ci_ubwc_cfg_2,
        output  wire    [3:0]           o_enc_ci_ubwc_cfg_3,
        output  wire    [3:0]           o_enc_ci_ubwc_cfg_4,
        output  wire    [3:0]           o_enc_ci_ubwc_cfg_5,
        output  wire    [1:0]           o_enc_ci_ubwc_cfg_6,
        output  wire    [1:0]           o_enc_ci_ubwc_cfg_7,
        output  wire    [1:0]           o_enc_ci_ubwc_cfg_8,
        output  wire    [2:0]           o_enc_ci_ubwc_cfg_9,
        output  wire    [5:0]           o_enc_ci_ubwc_cfg_10,
        output  wire    [5:0]           o_enc_ci_ubwc_cfg_11,

        input   wire                    i_enc_idle,
        input   wire                    i_enc_error,

        output  wire                    o_lvl1_bank_swizzle_en,
        output  wire                    o_lvl2_bank_swizzle_en,
        output  wire                    o_lvl3_bank_swizzle_en,
        output  wire    [4:0]           o_highest_bank_bit,
        output  wire                    o_bank_spread_en,
        output  wire                    o_4line_format,
        output  wire                    o_is_lossy_rgba_2_1_format,
        output  wire    [11:0]          o_tile_pitch,
        output  wire    [63:0]          o_y_base_offset_addr,
        output  wire    [63:0]          o_uv_base_offset_addr,
        output  wire    [63:0]          o_meta_y_base_offset_addr,
        output  wire    [63:0]          o_meta_uv_base_offset_addr,

        input   wire                    i_otf_to_tile_busy,
        input   wire                    i_otf_to_tile_overflow,
        input   wire                    i_otf_err_bline,
        input   wire                    i_otf_err_bframe,
        input   wire                    i_meta_err_0,
        input   wire                    i_meta_err_1,
        input   wire                    i_meta_frame_done
    );

    localparam [DW-1:0] REG_VERSION = 32'h0001_0000;
    localparam [DW-1:0] REG_DATE    = 32'h2026_0406;

    localparam integer REG_VERSION_IDX  = 0;
    localparam integer REG_DATE_IDX     = 1;
    localparam integer REG_TILE_CFG0    = 2;
    localparam integer REG_TILE_CFG1    = 3;
    localparam integer REG_ENC_CI_CFG0  = 4;
    localparam integer REG_ENC_CI_CFG1  = 5;
    localparam integer REG_ENC_CI_CFG2  = 6;
    localparam integer REG_ENC_CI_CFG3  = 7;
    localparam integer REG_OTF_CFG0     = 8;
    localparam integer REG_OTF_CFG1     = 9;
    localparam integer REG_OTF_CFG2     = 10;
    localparam integer REG_OTF_CFG3     = 11;
    localparam integer REG_TILE_BASE_Y_LO  = 12;
    localparam integer REG_TILE_BASE_Y_HI  = 13;
    localparam integer REG_TILE_BASE_UV_LO = 14;
    localparam integer REG_TILE_BASE_UV_HI = 15;
    localparam integer REG_META_BASE_Y_LO  = 16;
    localparam integer REG_META_BASE_Y_HI  = 17;
    localparam integer REG_META_BASE_UV_LO = 18;
    localparam integer REG_META_BASE_UV_HI = 19;
    localparam integer REG_META_ACTIVE_SIZE = 20;
    localparam integer REG_META_PITCH       = 21;
    localparam integer REG_STATUS0          = 22;
    localparam integer REG_IDX_W            = $clog2(NREG);

    reg [DW-1:0] regs [0:NREG-1];
    reg [DW-1:0] r_prdata;

    wire apb_access = PSEL && PENABLE;
    wire apb_write  = apb_access && PWRITE;
    wire [AW-3:0] reg_addr = PADDR[AW-1:2];
    wire [REG_IDX_W-1:0] reg_idx = reg_addr[REG_IDX_W-1:0];
    wire [15:0] meta_active_width_px;
    wire [15:0] meta_active_height_px;
    wire [15:0] total_x_units;
    wire [DW-1:0] status0;

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
            if ((reg_addr > REG_DATE_IDX[AW-3:0]) && (reg_addr < NREG) && (reg_addr != REG_STATUS0[AW-3:0]))
                regs[reg_idx] <= PWDATA;
        end
    end

    always @(*) begin
        if (reg_addr == REG_STATUS0[AW-3:0])
            r_prdata = status0;
        else if (reg_addr < NREG)
            r_prdata = regs[reg_idx];
        else
            r_prdata = {DW{1'b0}};
    end

    assign status0                    = {{(DW-9){1'b0}},
                                         i_meta_frame_done,
                                         i_meta_err_1,
                                         i_meta_err_0,
                                         i_otf_err_bframe,
                                         i_otf_err_bline,
                                         i_otf_to_tile_overflow,
                                         i_otf_to_tile_busy,
                                         i_enc_error,
                                         i_enc_idle};

    assign o_enc_ci_input_type         = regs[REG_ENC_CI_CFG0][0];
    assign o_enc_ci_alen               = regs[REG_ENC_CI_CFG0][10:8];

    assign o_enc_ci_sb                 = regs[REG_ENC_CI_CFG1][0 +: SB_WIDTH];
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

    assign o_enc_ubwc_en               = regs[REG_TILE_CFG0][0];
    assign o_lvl1_bank_swizzle_en      = regs[REG_TILE_CFG0][1];
    assign o_lvl2_bank_swizzle_en      = regs[REG_TILE_CFG0][2];
    assign o_lvl3_bank_swizzle_en      = regs[REG_TILE_CFG0][3];
    assign o_highest_bank_bit          = regs[REG_TILE_CFG0][8  +: 5];
    assign o_bank_spread_en            = regs[REG_TILE_CFG0][16];
    assign o_4line_format              = regs[REG_TILE_CFG1][0];
    assign o_is_lossy_rgba_2_1_format  = regs[REG_TILE_CFG1][1];
    assign o_tile_pitch                = {1'b0, regs[REG_TILE_CFG1][16 +: 11]};
    assign o_y_base_offset_addr        = {regs[REG_TILE_BASE_Y_HI],  regs[REG_TILE_BASE_Y_LO]};
    assign o_uv_base_offset_addr       = {regs[REG_TILE_BASE_UV_HI], regs[REG_TILE_BASE_UV_LO]};
    assign o_meta_y_base_offset_addr   = {regs[REG_META_BASE_Y_HI],  regs[REG_META_BASE_Y_LO]};
    assign o_meta_uv_base_offset_addr  = {regs[REG_META_BASE_UV_HI], regs[REG_META_BASE_UV_LO]};
    assign o_meta_data_plane_pitch     = regs[REG_META_PITCH];

    assign o_otf_cfg_format            = regs[REG_OTF_CFG0][0  +: 3];
    assign o_otf_cfg_width             = regs[REG_OTF_CFG1][0  +: 16];
    assign o_otf_cfg_height            = regs[REG_OTF_CFG1][16 +: 16];
    assign o_otf_cfg_tile_w            = regs[REG_OTF_CFG2][0  +: 16];
    assign o_otf_cfg_tile_h            = regs[REG_OTF_CFG2][16 +: 4];
    assign o_otf_cfg_a_tile_cols       = regs[REG_OTF_CFG3][0  +: 16];
    assign o_otf_cfg_b_tile_cols       = regs[REG_OTF_CFG3][16 +: 16];
    assign total_x_units               = (o_otf_cfg_a_tile_cols >= o_otf_cfg_b_tile_cols) ? o_otf_cfg_a_tile_cols : o_otf_cfg_b_tile_cols;
    assign o_meta_last_xcoord          = (total_x_units == 16'd0) ? {TW_DW{1'b0}} :
                                         (total_x_units[TW_DW-1:0] - {{(TW_DW-1){1'b0}}, 1'b1});
    assign meta_active_width_px        = regs[REG_META_ACTIVE_SIZE][15:0];
    assign meta_active_height_px       = regs[REG_META_ACTIVE_SIZE][31:16];
    assign o_meta_active_width_px      = meta_active_width_px;
    assign o_meta_active_height_px     = meta_active_height_px;

endmodule
