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
    parameter AW       = 16,
    parameter DW       = 32,
    parameter AXI_AW   = 64,
    parameter SB_WIDTH = 1
)(
    input  wire                 PCLK,
    input  wire                 PRESETn,
    input  wire                 PSEL,
    input  wire                 PENABLE,
    input  wire [AW-1:0]        PADDR,
    input  wire                 PWRITE,
    input  wire [DW-1:0]        PWDATA,
    output wire                 PREADY,
    output wire                 PSLVERR,
    output wire [DW-1:0]        PRDATA,

    input  wire                 i_axi_clk,
    input  wire                 i_axi_rst_n,
    input  wire                 i_meta_busy_axi,
    input  wire                 i_tile_busy_axi,
    input  wire                 i_vivo_busy_axi,
    input  wire                 i_otf_busy_axi,
    input  wire [6:0]           i_vivo_idle_bits_axi,
    input  wire [6:0]           i_vivo_error_bits_axi,

    output wire                 o_tile_cfg_lvl2_bank_swizzle_en,
    output wire                 o_tile_cfg_lvl3_bank_swizzle_en,
    output wire [4:0]           o_tile_cfg_highest_bank_bit,
    output wire                 o_tile_cfg_bank_spread_en,
    output wire                 o_tile_cfg_is_lossy_rgba_2_1_format,
    output wire [11:0]          o_tile_cfg_pitch,
    output wire                 o_tile_cfg_ci_input_type,
    output wire [SB_WIDTH-1:0]  o_tile_cfg_ci_sb,
    output wire                 o_tile_cfg_ci_lossy,
    output wire [1:0]           o_tile_cfg_ci_alpha_mode,
    output wire [AXI_AW-1:0]    o_tile_base_addr_rgba_uv,
    output wire [AXI_AW-1:0]    o_tile_base_addr_y,

    output wire                 o_vivo_ubwc_en,
    output wire                 o_vivo_sreset,

    output wire                 o_frame_start_pulse_axi,
    output wire                 o_meta_start_pulse_axi,
    output wire [4:0]           o_meta_base_format,
    output wire [AXI_AW-1:0]    o_meta_base_addr_rgba_y,
    output wire [AXI_AW-1:0]    o_meta_base_addr_uv,
    output wire [15:0]          o_meta_tile_x_numbers,
    output wire [15:0]          o_meta_tile_y_numbers,

    output wire [15:0]          o_otf_cfg_img_width,
    output wire [4:0]           o_otf_cfg_format,
    output wire [15:0]          o_otf_cfg_h_total,
    output wire [15:0]          o_otf_cfg_h_sync,
    output wire [15:0]          o_otf_cfg_h_bp,
    output wire [15:0]          o_otf_cfg_h_act,
    output wire [15:0]          o_otf_cfg_v_total,
    output wire [15:0]          o_otf_cfg_v_sync,
    output wire [15:0]          o_otf_cfg_v_bp,
    output wire [15:0]          o_otf_cfg_v_act
);

    localparam [DW-1:0] REG_VERSION = 32'h0001_0000;
    localparam [DW-1:0] REG_DATE    = 32'h2026_0403;

    localparam [4:0] APB_ADDR_VERSION   = 5'h00; // 0x00
    localparam [4:0] APB_ADDR_DATE      = 5'h01; // 0x04
    localparam [4:0] APB_ADDR_TILE_CFG0 = 5'h02; // 0x08
    localparam [4:0] APB_ADDR_TILE_CFG1 = 5'h03; // 0x0c
    localparam [4:0] APB_ADDR_TILE_CFG2 = 5'h04; // 0x10
    localparam [4:0] APB_ADDR_VIVO_CFG  = 5'h05; // 0x14
    localparam [4:0] APB_ADDR_META_CFG0 = 5'h06; // 0x18
    localparam [4:0] APB_ADDR_META_CFG1 = 5'h07; // 0x1c
    localparam [4:0] APB_ADDR_META_CFG2 = 5'h08; // 0x20
    localparam [4:0] APB_ADDR_META_CFG3 = 5'h09; // 0x24
    localparam [4:0] APB_ADDR_META_CFG4 = 5'h0a; // 0x28
    localparam [4:0] APB_ADDR_META_CFG5 = 5'h0b; // 0x2c
    localparam [4:0] APB_ADDR_OTF_CFG0  = 5'h0c; // 0x30
    localparam [4:0] APB_ADDR_OTF_CFG1  = 5'h0d; // 0x34
    localparam [4:0] APB_ADDR_OTF_CFG2  = 5'h0e; // 0x38
    localparam [4:0] APB_ADDR_OTF_CFG3  = 5'h0f; // 0x3c
    localparam [4:0] APB_ADDR_OTF_CFG4  = 5'h10; // 0x40
    localparam [4:0] APB_ADDR_TILE_BASE0 = 5'h11; // 0x44
    localparam [4:0] APB_ADDR_TILE_BASE1 = 5'h12; // 0x48
    localparam [4:0] APB_ADDR_TILE_BASE2 = 5'h13; // 0x4c
    localparam [4:0] APB_ADDR_TILE_BASE3 = 5'h14; // 0x50
    localparam [4:0] APB_ADDR_STATUS0   = 5'h15; // 0x54
    localparam [4:0] APB_ADDR_STATUS1   = 5'h16; // 0x58
    localparam [4:0] APB_ADDR_STATUS2   = 5'h17; // 0x5c
    localparam [4:0] APB_ADDR_STATUS3   = 5'h18; // 0x60

    reg                 r_tile_cfg_lvl1_bank_swizzle_en;
    reg                 r_tile_cfg_lvl2_bank_swizzle_en;
    reg                 r_tile_cfg_lvl3_bank_swizzle_en;
    reg [4:0]           r_tile_cfg_highest_bank_bit;
    reg                 r_tile_cfg_bank_spread_en;
    reg                 r_tile_cfg_4line_format;
    reg                 r_tile_cfg_is_lossy_rgba_2_1_format;
    reg [11:0]          r_tile_cfg_pitch;
    reg                 r_tile_cfg_ci_input_type;
    reg [SB_WIDTH-1:0]  r_tile_cfg_ci_sb;
    reg                 r_tile_cfg_ci_lossy;
    reg [1:0]           r_tile_cfg_ci_alpha_mode;
    reg [AXI_AW-1:0]    r_tile_base_addr_rgba_uv;
    reg [AXI_AW-1:0]    r_tile_base_addr_y;
    reg                 r_vivo_ubwc_en;
    reg                 r_vivo_sreset;
    reg                 r_meta_start_toggle;
    reg [4:0]           r_meta_base_format;
    reg [AXI_AW-1:0]    r_meta_base_addr_rgba_y;
    reg [AXI_AW-1:0]    r_meta_base_addr_uv;
    reg [15:0]          r_meta_tile_x_numbers;
    reg [15:0]          r_meta_tile_y_numbers;
    reg [15:0]          r_otf_cfg_img_width;
    reg [4:0]           r_otf_cfg_format;
    reg [15:0]          r_otf_cfg_h_total;
    reg [15:0]          r_otf_cfg_h_sync;
    reg [15:0]          r_otf_cfg_h_bp;
    reg [15:0]          r_otf_cfg_h_act;
    reg [15:0]          r_otf_cfg_v_total;
    reg [15:0]          r_otf_cfg_v_sync;
    reg [15:0]          r_otf_cfg_v_bp;
    reg [15:0]          r_otf_cfg_v_act;
    reg                 r_meta_start_sync_ff1;
    reg                 r_meta_start_sync_ff2;
    reg                 r_frame_active_axi;
    reg [3:0]           r_stage_seen_busy_axi;
    reg [4:0]           r_stage_done_axi;

    reg  [DW-1:0] r_prdata;

    wire       apb_access       = PSEL && PENABLE;
    wire       apb_addr_aligned = (PADDR[1:0] == 2'b00);
    wire       apb_addr_in_rng  = (PADDR[AW-1:7] == {(AW-7){1'b0}});
    wire       apb_decode_valid = apb_addr_aligned && apb_addr_in_rng;
    wire       apb_write        = apb_access && PWRITE && apb_decode_valid;
    wire [4:0] apb_addr         = PADDR[6:2];
    wire       frame_start_pulse_axi = r_meta_start_sync_ff1 ^ r_meta_start_sync_ff2;
    wire       any_stage_busy_axi    = i_meta_busy_axi | i_tile_busy_axi | i_vivo_busy_axi | i_otf_busy_axi;
    wire       meta_done_next_axi    = r_stage_done_axi[0] | (r_stage_seen_busy_axi[0] && !i_meta_busy_axi);
    wire       tile_done_next_axi    = r_stage_done_axi[1] | (r_stage_seen_busy_axi[1] && !i_tile_busy_axi);
    wire       vivo_done_next_axi    = r_stage_done_axi[2] | (r_stage_seen_busy_axi[2] && !i_vivo_busy_axi);
    wire       otf_done_next_axi     = r_stage_done_axi[3] | (r_stage_seen_busy_axi[3] && !i_otf_busy_axi);
    wire       frame_done_next_axi   = meta_done_next_axi && tile_done_next_axi &&
                                       vivo_done_next_axi && otf_done_next_axi &&
                                       !any_stage_busy_axi;

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
            r_tile_cfg_ci_sb                    <= {SB_WIDTH{1'b0}};
            r_tile_cfg_ci_lossy                 <= 1'b0;
            r_tile_cfg_ci_alpha_mode            <= 2'd0;
            r_tile_base_addr_rgba_uv            <= {AXI_AW{1'b0}};
            r_tile_base_addr_y                  <= {AXI_AW{1'b0}};
            r_vivo_ubwc_en                      <= 1'b1;
            r_vivo_sreset                       <= 1'b0;
            r_meta_start_toggle                 <= 1'b0;
            r_meta_base_format                  <= 5'd0;
            r_meta_base_addr_rgba_y             <= {AXI_AW{1'b0}};
            r_meta_base_addr_uv                 <= {AXI_AW{1'b0}};
            r_meta_tile_x_numbers               <= 16'd0;
            r_meta_tile_y_numbers               <= 16'd0;
            r_otf_cfg_img_width                 <= 16'd0;
            r_otf_cfg_format                    <= 5'd0;
            r_otf_cfg_h_total                   <= 16'd0;
            r_otf_cfg_h_sync                    <= 16'd0;
            r_otf_cfg_h_bp                      <= 16'd0;
            r_otf_cfg_h_act                     <= 16'd0;
            r_otf_cfg_v_total                   <= 16'd0;
            r_otf_cfg_v_sync                    <= 16'd0;
            r_otf_cfg_v_bp                      <= 16'd0;
            r_otf_cfg_v_act                     <= 16'd0;
        end else if (apb_write) begin
            case (apb_addr)
                APB_ADDR_TILE_CFG0: begin
                    r_tile_cfg_lvl1_bank_swizzle_en     <= PWDATA[0];
                    r_tile_cfg_lvl2_bank_swizzle_en     <= PWDATA[1];
                    r_tile_cfg_lvl3_bank_swizzle_en     <= PWDATA[2];
                    r_tile_cfg_highest_bank_bit         <= PWDATA[8:4];
                    r_tile_cfg_bank_spread_en           <= PWDATA[9];
                    r_tile_cfg_4line_format             <= PWDATA[10];
                    r_tile_cfg_is_lossy_rgba_2_1_format <= PWDATA[11];
                end
                APB_ADDR_TILE_CFG1: begin
                    r_tile_cfg_pitch <= PWDATA[11:0];
                end
                APB_ADDR_TILE_CFG2: begin
                    r_tile_cfg_ci_input_type <= PWDATA[0];
                    r_tile_cfg_ci_sb         <= PWDATA[SB_WIDTH:1];
                    r_tile_cfg_ci_lossy      <= PWDATA[8];
                    r_tile_cfg_ci_alpha_mode <= PWDATA[10:9];
                end
                APB_ADDR_TILE_BASE0: begin
                    r_tile_base_addr_rgba_uv[31:0] <= PWDATA;
                end
                APB_ADDR_TILE_BASE1: begin
                    r_tile_base_addr_rgba_uv[AXI_AW-1:32] <= PWDATA[AXI_AW-33:0];
                end
                APB_ADDR_TILE_BASE2: begin
                    r_tile_base_addr_y[31:0] <= PWDATA;
                end
                APB_ADDR_TILE_BASE3: begin
                    r_tile_base_addr_y[AXI_AW-1:32] <= PWDATA[AXI_AW-33:0];
                end
                APB_ADDR_VIVO_CFG: begin
                    r_vivo_ubwc_en <= PWDATA[0];
                    r_vivo_sreset  <= PWDATA[1];
                end
                APB_ADDR_META_CFG0: begin
                    if (PWDATA[0]) begin
                        r_meta_start_toggle <= ~r_meta_start_toggle;
                    end
                    r_meta_base_format <= PWDATA[8:4];
                end
                APB_ADDR_META_CFG1: begin
                    r_meta_base_addr_rgba_y[31:0] <= PWDATA;
                end
                APB_ADDR_META_CFG2: begin
                    r_meta_base_addr_rgba_y[AXI_AW-1:32] <= PWDATA[AXI_AW-33:0];
                end
                APB_ADDR_META_CFG3: begin
                    r_meta_base_addr_uv[31:0] <= PWDATA;
                end
                APB_ADDR_META_CFG4: begin
                    r_meta_base_addr_uv[AXI_AW-1:32] <= PWDATA[AXI_AW-33:0];
                end
                APB_ADDR_META_CFG5: begin
                    r_meta_tile_x_numbers <= PWDATA[15:0];
                    r_meta_tile_y_numbers <= PWDATA[31:16];
                end
                APB_ADDR_OTF_CFG0: begin
                    r_otf_cfg_img_width <= PWDATA[15:0];
                    r_otf_cfg_format    <= PWDATA[20:16];
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
                default: begin
                end
            endcase
        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rst_n) begin
        if (!i_axi_rst_n) begin
            r_meta_start_sync_ff1 <= 1'b0;
            r_meta_start_sync_ff2 <= 1'b0;
            r_frame_active_axi    <= 1'b0;
            r_stage_seen_busy_axi <= 4'd0;
            r_stage_done_axi      <= 5'd0;
        end else begin
            r_meta_start_sync_ff1 <= r_meta_start_toggle;
            r_meta_start_sync_ff2 <= r_meta_start_sync_ff1;
            if (frame_start_pulse_axi) begin
                r_frame_active_axi    <= 1'b1;
                r_stage_seen_busy_axi <= 4'd0;
                r_stage_done_axi      <= 5'd0;
            end else if (r_frame_active_axi) begin
                if (i_meta_busy_axi) begin
                    r_stage_seen_busy_axi[0] <= 1'b1;
                end
                if (i_tile_busy_axi) begin
                    r_stage_seen_busy_axi[1] <= 1'b1;
                end
                if (i_vivo_busy_axi) begin
                    r_stage_seen_busy_axi[2] <= 1'b1;
                end
                if (i_otf_busy_axi) begin
                    r_stage_seen_busy_axi[3] <= 1'b1;
                end

                r_stage_done_axi[0] <= meta_done_next_axi;
                r_stage_done_axi[1] <= tile_done_next_axi;
                r_stage_done_axi[2] <= vivo_done_next_axi;
                r_stage_done_axi[3] <= otf_done_next_axi;
                r_stage_done_axi[4] <= frame_done_next_axi;

                if (frame_done_next_axi) begin
                    r_frame_active_axi <= 1'b0;
                end
            end
        end
    end

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
                r_prdata = {{(DW-12){1'b0}},
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
                            {(7-SB_WIDTH){1'b0}},
                            r_tile_cfg_ci_sb,
                            r_tile_cfg_ci_input_type};
            end
            APB_ADDR_TILE_BASE0: begin
                r_prdata = r_tile_base_addr_rgba_uv[31:0];
            end
            APB_ADDR_TILE_BASE1: begin
                r_prdata = {{(DW-(AXI_AW-32)){1'b0}}, r_tile_base_addr_rgba_uv[AXI_AW-1:32]};
            end
            APB_ADDR_TILE_BASE2: begin
                r_prdata = r_tile_base_addr_y[31:0];
            end
            APB_ADDR_TILE_BASE3: begin
                r_prdata = {{(DW-(AXI_AW-32)){1'b0}}, r_tile_base_addr_y[AXI_AW-1:32]};
            end
            APB_ADDR_VIVO_CFG: begin
                r_prdata = {{(DW-2){1'b0}}, r_vivo_sreset, r_vivo_ubwc_en};
            end
            APB_ADDR_META_CFG0: begin
                r_prdata = {{(DW-9){1'b0}}, r_meta_base_format, 3'b000, 1'b0};
            end
            APB_ADDR_META_CFG1: begin
                r_prdata = r_meta_base_addr_rgba_y[31:0];
            end
            APB_ADDR_META_CFG2: begin
                r_prdata = {{(DW-(AXI_AW-32)){1'b0}}, r_meta_base_addr_rgba_y[AXI_AW-1:32]};
            end
            APB_ADDR_META_CFG3: begin
                r_prdata = r_meta_base_addr_uv[31:0];
            end
            APB_ADDR_META_CFG4: begin
                r_prdata = {{(DW-(AXI_AW-32)){1'b0}}, r_meta_base_addr_uv[AXI_AW-1:32]};
            end
            APB_ADDR_META_CFG5: begin
                r_prdata = {r_meta_tile_y_numbers, r_meta_tile_x_numbers};
            end
            APB_ADDR_OTF_CFG0: begin
                r_prdata = {{(DW-21){1'b0}}, r_otf_cfg_format, r_otf_cfg_img_width};
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
                            (!any_stage_busy_axi && !r_frame_active_axi),
                            !any_stage_busy_axi,
                            i_otf_busy_axi,
                            i_vivo_busy_axi,
                            i_tile_busy_axi,
                            i_meta_busy_axi,
                            r_frame_active_axi};
            end
            APB_ADDR_STATUS1: begin
                r_prdata = {{(DW-9){1'b0}}, r_stage_seen_busy_axi, r_stage_done_axi};
            end
            APB_ADDR_STATUS2: begin
                r_prdata = {{(DW-7){1'b0}}, i_vivo_idle_bits_axi};
            end
            APB_ADDR_STATUS3: begin
                r_prdata = {{(DW-7){1'b0}}, i_vivo_error_bits_axi};
            end
            default: begin
                r_prdata = {DW{1'b0}};
            end
        endcase
    end

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;
    assign PRDATA  = r_prdata;

    assign o_tile_cfg_lvl2_bank_swizzle_en     = r_tile_cfg_lvl2_bank_swizzle_en;
    assign o_tile_cfg_lvl3_bank_swizzle_en     = r_tile_cfg_lvl3_bank_swizzle_en;
    assign o_tile_cfg_highest_bank_bit         = r_tile_cfg_highest_bank_bit;
    assign o_tile_cfg_bank_spread_en           = r_tile_cfg_bank_spread_en;
    assign o_tile_cfg_is_lossy_rgba_2_1_format = r_tile_cfg_is_lossy_rgba_2_1_format;
    assign o_tile_cfg_pitch                    = r_tile_cfg_pitch;
    assign o_tile_cfg_ci_input_type            = r_tile_cfg_ci_input_type;
    assign o_tile_cfg_ci_sb                    = r_tile_cfg_ci_sb;
    assign o_tile_cfg_ci_lossy                 = r_tile_cfg_ci_lossy;
    assign o_tile_cfg_ci_alpha_mode            = r_tile_cfg_ci_alpha_mode;
    assign o_tile_base_addr_rgba_uv            = r_tile_base_addr_rgba_uv;
    assign o_tile_base_addr_y                  = r_tile_base_addr_y;
    assign o_vivo_ubwc_en                      = r_vivo_ubwc_en;
    assign o_vivo_sreset                       = r_vivo_sreset;
    assign o_frame_start_pulse_axi             = frame_start_pulse_axi;
    assign o_meta_start_pulse_axi              = frame_start_pulse_axi;
    assign o_meta_base_format                  = r_meta_base_format;
    assign o_meta_base_addr_rgba_y             = r_meta_base_addr_rgba_y;
    assign o_meta_base_addr_uv                 = r_meta_base_addr_uv;
    assign o_meta_tile_x_numbers               = r_meta_tile_x_numbers;
    assign o_meta_tile_y_numbers               = r_meta_tile_y_numbers;
    assign o_otf_cfg_img_width                 = r_otf_cfg_img_width;
    assign o_otf_cfg_format                    = r_otf_cfg_format;
    assign o_otf_cfg_h_total                   = r_otf_cfg_h_total;
    assign o_otf_cfg_h_sync                    = r_otf_cfg_h_sync;
    assign o_otf_cfg_h_bp                      = r_otf_cfg_h_bp;
    assign o_otf_cfg_h_act                     = r_otf_cfg_h_act;
    assign o_otf_cfg_v_total                   = r_otf_cfg_v_total;
    assign o_otf_cfg_v_sync                    = r_otf_cfg_v_sync;
    assign o_otf_cfg_v_bp                      = r_otf_cfg_v_bp;
    assign o_otf_cfg_v_act                     = r_otf_cfg_v_act;

endmodule
