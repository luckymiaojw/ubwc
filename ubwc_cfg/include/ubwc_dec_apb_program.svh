task automatic ubwc_dec_apb_program(
    input int unsigned format,
    input int unsigned width_px,
    input int unsigned height_px,
    input logic [63:0] tile_base_rgba_y,
    input logic [63:0] tile_base_uv,
    input logic [63:0] meta_base_rgba_y,
    input logic [63:0] meta_base_uv,
    input int unsigned h_total,
    input int unsigned h_sync,
    input int unsigned h_bp,
    input int unsigned h_act,
    input int unsigned v_total,
    input int unsigned v_sync,
    input int unsigned v_bp,
    input int unsigned v_act
);
    bit four_line_format;
    bit lossy_rgba_2_1;

    four_line_format = ubwc_dec_cfg_pkg::ubwc_dec_is_rgba_format(format);
    lossy_rgba_2_1 = (format == ubwc_dec_cfg_pkg::UBWC_DEC_FMT_RGBA8888_L_2_1);

    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_TILE_CFG0,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_tile_cfg0(1'b0, 1'b1, 1'b1, 16, 1'b1,
                                                       four_line_format, lossy_rgba_2_1));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_TILE_CFG1,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_tile_cfg1(format, width_px));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_TILE_CFG2,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_tile_cfg2(1'b1, lossy_rgba_2_1, 2'd0));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_VIVO_CFG,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_vivo_cfg(1'b1, 1'b0));

    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_OTF_CFG0,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_otf_cfg0(format, width_px));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_OTF_CFG1,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_otf_cfg1(h_total, h_sync));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_OTF_CFG2,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_otf_cfg2(h_bp, h_act));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_OTF_CFG3,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_otf_cfg3(v_total, v_sync));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_OTF_CFG4,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_otf_cfg4(v_bp, v_act));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_META_CFG0,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_meta_cfg0(format, width_px, height_px));

    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_META_BASE_Y_LO,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_base_lo(meta_base_rgba_y));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_META_BASE_Y_HI,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_base_hi(meta_base_rgba_y));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_TILE_BASE_Y_LO,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_base_lo(tile_base_rgba_y));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_TILE_BASE_Y_HI,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_base_hi(tile_base_rgba_y));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_META_BASE_UV_LO,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_base_lo(meta_base_uv));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_META_BASE_UV_HI,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_base_hi(meta_base_uv));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_TILE_BASE_UV_LO,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_base_lo(tile_base_uv));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_TILE_BASE_UV_HI,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_base_hi(tile_base_uv));
endtask

task automatic ubwc_dec_apb_program_simple(
    input int unsigned format,
    input int unsigned width_px,
    input int unsigned height_px,
    input logic [63:0] meta_y_base_addr
);
    ubwc_dec_cfg_pkg::ubwc_dec_base_cfg_t base;
    int unsigned stored_height_px;

    base = ubwc_dec_cfg_pkg::ubwc_dec_layout_bases(format, width_px, height_px,
                                                   meta_y_base_addr);
    stored_height_px = ubwc_dec_cfg_pkg::ubwc_dec_stored_height_px(format, height_px);
    ubwc_dec_apb_program(format, width_px, height_px,
                         base.tile_base_rgba_y,
                         base.tile_base_uv,
                         base.meta_base_rgba_y,
                         base.meta_base_uv,
                         width_px, 0, 0, width_px,
                         stored_height_px, 0, 0, stored_height_px);
endtask
