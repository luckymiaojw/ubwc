task automatic ubwc_enc_apb_program(
    input int unsigned format,
    input int unsigned width_px,
    input int unsigned height_px,
    input logic [63:0] tile_base_y,
    input logic [63:0] tile_base_uv,
    input logic [63:0] meta_base_y,
    input logic [63:0] meta_base_uv
);
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_TILE_CFG1,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_tile_cfg1(format, width_px));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_TILE_CFG0,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_tile_cfg0(1'b1, 1'b0, 1'b1, 1'b1, 16, 1'b1));

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
              ubwc_enc_cfg_pkg::ubwc_enc_reg_enc_ci_cfg1(0, format == ubwc_enc_cfg_pkg::UBWC_ENC_FMT_RGBA8888_L_2_1));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_ENC_CI_CFG2,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_enc_ci_cfg2());
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_ENC_CI_CFG3,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_enc_ci_cfg3());
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_ENC_CI_CFG0,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_enc_ci_cfg0(1'b1, 3'd7));

    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_OTF_CFG1,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_otf_cfg1(width_px, height_px));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_OTF_CFG2,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_otf_cfg2(format));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_OTF_CFG3,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_otf_cfg3(format, width_px));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_META_ACTIVE_SIZE,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_meta_active_size(width_px, height_px));
    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_META_PITCH,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_meta_pitch(format, width_px));

    apb_write(ubwc_enc_cfg_pkg::UBWC_ENC_REG_OTF_CFG0,
              ubwc_enc_cfg_pkg::ubwc_enc_reg_otf_cfg0(format));
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
