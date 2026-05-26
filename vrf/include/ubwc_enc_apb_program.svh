task automatic ubwc_enc_apb_program_full(
    input int unsigned format,
    input int unsigned active_width_px,
    input int unsigned active_height_px,
    input int unsigned otf_width_px,
    input int unsigned otf_height_px,
    input logic [63:0] tile_base_y,
    input logic [63:0] tile_base_uv,
    input logic [63:0] meta_base_y,
    input logic [63:0] meta_base_uv,
    input bit enc_ubwc_en,
    input bit lvl1_bank_swizzle_en,
    input bit lvl2_bank_swizzle_en,
    input bit lvl3_bank_swizzle_en,
    input int unsigned highest_bank_bit,
    input bit bank_spread_en,
    input bit ci_input_type,
    input logic [2:0] ci_alen,
    input bit ci_lossy,
    input logic [31:0] ci_cfg2,
    input logic [31:0] ci_cfg3,
    input bit irq_enable,
    input bit do_start,
    input bit vsync_reset_en = 1'b0
);
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_TILE_CFG1,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_tile_cfg1(format, active_width_px));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_TILE_CFG0,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_tile_cfg0(enc_ubwc_en,
                                                       lvl1_bank_swizzle_en,
                                                       lvl2_bank_swizzle_en,
                                                       lvl3_bank_swizzle_en,
                                                       highest_bank_bit,
                                                       bank_spread_en));

    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_META_BASE_Y_LO,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_base_lo(meta_base_y));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_META_BASE_Y_HI,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_base_hi(meta_base_y));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_TILE_BASE_Y_LO,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_base_lo(tile_base_y));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_TILE_BASE_Y_HI,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_base_hi(tile_base_y));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_META_BASE_UV_LO,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_base_lo(meta_base_uv));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_META_BASE_UV_HI,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_base_hi(meta_base_uv));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_TILE_BASE_UV_LO,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_base_lo(tile_base_uv));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_TILE_BASE_UV_HI,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_base_hi(tile_base_uv));

    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_ENC_CI_CFG1,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_enc_ci_cfg1(0, ci_lossy));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_ENC_CI_CFG2,
              ci_cfg2);
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_ENC_CI_CFG3,
              ci_cfg3);
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_ENC_CI_CFG0,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_enc_ci_cfg0(ci_input_type, ci_alen));

    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_OTF_CFG1,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_otf_cfg1(otf_width_px, otf_height_px));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_OTF_CFG2,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_otf_cfg2(format));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_OTF_CFG3,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_otf_cfg3(format, active_width_px));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_META_ACTIVE_SIZE,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_meta_active_size(active_width_px, active_height_px));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_META_PITCH,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_meta_pitch(format, active_width_px));

    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_OTF_CFG0,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_otf_cfg0(format));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_IRQ_CTRL,
              {25'd0, vsync_reset_en, do_start, 3'd0, 1'b0, irq_enable});
endtask

task automatic ubwc_enc_apb_program(
    input int unsigned format,
    input int unsigned width_px,
    input int unsigned height_px,
    input logic [63:0] tile_base_y,
    input logic [63:0] tile_base_uv,
    input logic [63:0] meta_base_y,
    input logic [63:0] meta_base_uv
);
    bit lossy_rgba_2_1;

    lossy_rgba_2_1 = (format == ubwc_enc_cfg_pkg::UBWC_ENC_FMT_RGBA8888_L_2_1);
    ubwc_enc_apb_program_full(format,
                              width_px,
                              height_px,
                              width_px,
                              height_px,
                              tile_base_y,
                              tile_base_uv,
                              meta_base_y,
                              meta_base_uv,
                              1'b1,
                              1'b0,
                              1'b1,
                              1'b1,
                              16,
                              1'b1,
                              1'b1,
                              3'd7,
                              lossy_rgba_2_1,
                              ubwc_enc_cfg_pkg::ubwc_enc_reg_enc_ci_cfg2(),
                              ubwc_enc_cfg_pkg::ubwc_enc_reg_enc_ci_cfg3(),
                              1'b1,
                              1'b1);
endtask

task automatic ubwc_enc_apb_program_simple(
    input int unsigned format,
    input int unsigned width_px,
    input int unsigned height_px,
    input logic [63:0] meta_y_base_addr
);
    ubwc_enc_cfg_pkg::ubwc_enc_base_cfg_t base;

    base = ubwc_enc_cfg_pkg::ubwc_enc_layout_bases(format, width_px, height_px,
                                                   meta_y_base_addr);
    ubwc_enc_apb_program(format, width_px, height_px,
                         base.tile_base_y,
                         base.tile_base_uv,
                         base.meta_base_y,
                         base.meta_base_uv);
endtask

task automatic ubwc_enc_apb_program_simple_full(
    input int unsigned format,
    input int unsigned active_width_px,
    input int unsigned active_height_px,
    input int unsigned otf_width_px,
    input int unsigned otf_height_px,
    input logic [63:0] meta_y_base_addr,
    input bit ci_lossy,
    input bit irq_enable,
    input bit do_start
);
    ubwc_enc_cfg_pkg::ubwc_enc_base_cfg_t base;

    base = ubwc_enc_cfg_pkg::ubwc_enc_layout_bases(format, active_width_px,
                                                   active_height_px,
                                                   meta_y_base_addr);
    ubwc_enc_apb_program_full(format,
                              active_width_px,
                              active_height_px,
                              otf_width_px,
                              otf_height_px,
                              base.tile_base_y,
                              base.tile_base_uv,
                              base.meta_base_y,
                              base.meta_base_uv,
                              1'b1,
                              1'b0,
                              1'b1,
                              1'b1,
                              16,
                              1'b1,
                              1'b1,
                              3'd7,
                              ci_lossy,
                              ubwc_enc_cfg_pkg::ubwc_enc_reg_enc_ci_cfg2(),
                              ubwc_enc_cfg_pkg::ubwc_enc_reg_enc_ci_cfg3(),
                              irq_enable,
                              do_start);
endtask
