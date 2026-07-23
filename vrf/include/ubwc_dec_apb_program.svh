task automatic ubwc_dec_apb_program_full(
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
    input int unsigned v_act,
    input bit lvl1_bank_swizzle_en,
    input bit lvl2_bank_swizzle_en,
    input bit lvl3_bank_swizzle_en,
    input int unsigned highest_bank_bit,
    input bit bank_spread_en,
    input bit ci_input_type,
    input bit ci_lossy,
    input logic [1:0] ci_alpha_mode,
    input bit vivo_ubwc_en,
    input bit vivo_sreset,
    input bit irq_enable,
    input bit do_start,
    input logic [3:0] ubwc_ver = 4'd7
);
    bit four_line_format;
    bit lossy_rgba_2_1;

    four_line_format = ubwc_dec_cfg_pkg::ubwc_dec_is_rgba_format(format);
    lossy_rgba_2_1 = (format == ubwc_dec_cfg_pkg::UBWC_DEC_FMT_RGBA8888_L_2_1);

    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_TILE_CFG0,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_tile_cfg0(lvl1_bank_swizzle_en,
                                                       lvl2_bank_swizzle_en,
                                                       lvl3_bank_swizzle_en,
                                                       highest_bank_bit,
                                                       bank_spread_en,
                                                       four_line_format, lossy_rgba_2_1));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_TILE_CFG1,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_tile_cfg1(format, width_px));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_TILE_CFG2,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_tile_cfg2_fields(ci_input_type,
                                                              ci_lossy,
                                                              ci_alpha_mode,
                                                              ubwc_ver));
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_VIVO_CFG,
              ubwc_dec_cfg_pkg::ubwc_dec_reg_vivo_cfg(vivo_ubwc_en, vivo_sreset));

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
    apb_write(ubwc_dec_cfg_pkg::UBWC_DEC_REG_IRQ_CTRL,
              {26'd0, do_start, 3'd0, 1'b0, irq_enable});
endtask

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
    input int unsigned v_act,
    input logic [3:0] ubwc_ver = 4'd7
);
    bit lossy_rgba_2_1;

    lossy_rgba_2_1 = (format == ubwc_dec_cfg_pkg::UBWC_DEC_FMT_RGBA8888_L_2_1);
    ubwc_dec_apb_program_full(format,
                              width_px,
                              height_px,
                              tile_base_rgba_y,
                              tile_base_uv,
                              meta_base_rgba_y,
                              meta_base_uv,
                              h_total,
                              h_sync,
                              h_bp,
                              h_act,
                              v_total,
                              v_sync,
                              v_bp,
                              v_act,
                              1'b0,
                              1'b1,
                              1'b1,
                              16,
                              1'b1,
                              1'b1,
                              lossy_rgba_2_1,
                              2'd0,
                              1'b1,
                              1'b0,
                              1'b1,
                              1'b1,
                              ubwc_ver);
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

task automatic ubwc_dec_apb_program_simple_full(
    input int unsigned format,
    input int unsigned width_px,
    input int unsigned height_px,
    input logic [63:0] meta_y_base_addr,
    input int unsigned h_total,
    input int unsigned h_sync,
    input int unsigned h_bp,
    input int unsigned h_act,
    input int unsigned v_total,
    input int unsigned v_sync,
    input int unsigned v_bp,
    input int unsigned v_act,
    input bit ci_lossy,
    input bit irq_enable,
    input bit do_start,
    input logic [3:0] ubwc_ver = 4'd7
);
    ubwc_dec_cfg_pkg::ubwc_dec_base_cfg_t base;

    base = ubwc_dec_cfg_pkg::ubwc_dec_layout_bases(format, width_px, height_px,
                                                   meta_y_base_addr);
    ubwc_dec_apb_program_full(format,
                              width_px,
                              height_px,
                              base.tile_base_rgba_y,
                              base.tile_base_uv,
                              base.meta_base_rgba_y,
                              base.meta_base_uv,
                              h_total,
                              h_sync,
                              h_bp,
                              h_act,
                              v_total,
                              v_sync,
                              v_bp,
                              v_act,
                              1'b0,
                              1'b1,
                              1'b1,
                              16,
                              1'b1,
                              1'b1,
                              ci_lossy,
                              2'd0,
                              1'b1,
                              1'b0,
                              irq_enable,
                              do_start,
                              ubwc_ver);
endtask
