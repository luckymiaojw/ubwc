#ifndef UBWC_ENC_CFG_H
#define UBWC_ENC_CFG_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

enum {
    UBWC_ENC_FMT_RGBA8888       = 0,
    UBWC_ENC_FMT_RGBA1010102    = 1,
    UBWC_ENC_FMT_YUV420_8_NV12  = 2,
    UBWC_ENC_FMT_YUV420_10_P010 = 3,
    UBWC_ENC_FMT_RGBA8888_L_2_1 = 4
};

enum {
    UBWC_ENC_REG_TILE_CFG0        = 0x0008,
    UBWC_ENC_REG_TILE_CFG1        = 0x000c,
    UBWC_ENC_REG_ENC_CI_CFG0      = 0x0010,
    UBWC_ENC_REG_ENC_CI_CFG1      = 0x0014,
    UBWC_ENC_REG_ENC_CI_CFG2      = 0x0018,
    UBWC_ENC_REG_ENC_CI_CFG3      = 0x001c,
    UBWC_ENC_REG_OTF_CFG0         = 0x0020,
    UBWC_ENC_REG_OTF_CFG1         = 0x0024,
    UBWC_ENC_REG_OTF_CFG2         = 0x0028,
    UBWC_ENC_REG_OTF_CFG3         = 0x002c,
    UBWC_ENC_REG_META_BASE_Y_LO   = 0x0030,
    UBWC_ENC_REG_META_BASE_Y_HI   = 0x0034,
    UBWC_ENC_REG_TILE_BASE_Y_LO   = 0x0038,
    UBWC_ENC_REG_TILE_BASE_Y_HI   = 0x003c,
    UBWC_ENC_REG_META_BASE_UV_LO  = 0x0040,
    UBWC_ENC_REG_META_BASE_UV_HI  = 0x0044,
    UBWC_ENC_REG_TILE_BASE_UV_LO  = 0x0048,
    UBWC_ENC_REG_TILE_BASE_UV_HI  = 0x004c,
    UBWC_ENC_REG_META_ACTIVE_SIZE = 0x0050,
    UBWC_ENC_REG_META_PITCH       = 0x0054,
    UBWC_ENC_REG_IRQ_CTRL         = 0x0060
};

typedef struct {
    uint16_t addr;
    uint32_t data;
    const char *name;
} ubwc_enc_reg_write_t;

typedef struct {
    uint64_t tile_base_y;
    uint64_t tile_base_uv;
    uint64_t meta_base_y;
    uint64_t meta_base_uv;
} ubwc_enc_base_cfg_t;

typedef struct {
    uint32_t meta_y_size;
    uint32_t tile_y_size;
    uint32_t meta_uv_size;
    uint32_t tile_uv_size;
    uint32_t total_size;
} ubwc_enc_layout_size_t;

typedef struct {
    uint32_t format;
    uint32_t active_width_px;
    uint32_t active_height_px;
    uint32_t otf_width_px;
    uint32_t otf_height_px;
    ubwc_enc_base_cfg_t base;
    uint32_t enc_ubwc_en;
    uint32_t lvl1_bank_swizzle_en;
    uint32_t lvl2_bank_swizzle_en;
    uint32_t lvl3_bank_swizzle_en;
    uint32_t highest_bank_bit;
    uint32_t bank_spread_en;
    uint32_t ci_input_type;
    uint32_t ci_alen;
    uint32_t ci_lossy;
    uint32_t ci_cfg2;
    uint32_t ci_cfg3;
    uint32_t irq_enable;
    uint32_t do_start;
    uint32_t vsync_reset_en;
} ubwc_enc_config_t;

static inline uint32_t ubwc_enc_align_up_u32(uint32_t value, uint32_t unit)
{
    return ((value + unit - 1u) / unit) * unit;
}

static inline uint32_t ubwc_enc_ceil_div_u32(uint32_t value, uint32_t unit)
{
    return (value + unit - 1u) / unit;
}

static inline uint32_t ubwc_enc_is_rgba_format(uint32_t format)
{
    return (format == UBWC_ENC_FMT_RGBA8888) ||
           (format == UBWC_ENC_FMT_RGBA1010102) ||
           (format == UBWC_ENC_FMT_RGBA8888_L_2_1);
}

static inline uint32_t ubwc_enc_tile_w(uint32_t format)
{
    return ubwc_enc_is_rgba_format(format) ? 16u : 32u;
}

static inline uint32_t ubwc_enc_tile_h(uint32_t format)
{
    if ((format == UBWC_ENC_FMT_RGBA8888) ||
        (format == UBWC_ENC_FMT_RGBA1010102) ||
        (format == UBWC_ENC_FMT_RGBA8888_L_2_1) ||
        (format == UBWC_ENC_FMT_YUV420_10_P010)) {
        return 4u;
    }
    return 8u;
}

static inline uint32_t ubwc_enc_bytes_per_pixel(uint32_t format)
{
    if ((format == UBWC_ENC_FMT_RGBA8888) ||
        (format == UBWC_ENC_FMT_RGBA1010102) ||
        (format == UBWC_ENC_FMT_RGBA8888_L_2_1)) {
        return 4u;
    }
    if (format == UBWC_ENC_FMT_YUV420_10_P010) {
        return 2u;
    }
    return 1u;
}

static inline uint32_t ubwc_enc_aligned_width_px(uint32_t format, uint32_t width_px)
{
    uint32_t tile_w = ubwc_enc_tile_w(format);
    return ubwc_enc_align_up_u32(width_px, tile_w * 4u);
}

static inline uint32_t ubwc_enc_tile_cols(uint32_t format, uint32_t width_px)
{
    uint32_t tile_w = ubwc_enc_tile_w(format);
    return ubwc_enc_ceil_div_u32(ubwc_enc_aligned_width_px(format, width_px), tile_w);
}

static inline uint32_t ubwc_enc_uv_height_px(uint32_t height_px)
{
    return ubwc_enc_ceil_div_u32(height_px, 2u);
}

static inline uint32_t ubwc_enc_stored_uv_height_px(uint32_t format, uint32_t height_px)
{
    if (ubwc_enc_is_rgba_format(format)) {
        return 0u;
    }
    return ubwc_enc_align_up_u32(ubwc_enc_uv_height_px(height_px),
                                 ubwc_enc_tile_h(format) * 4u);
}

static inline uint32_t ubwc_enc_stored_height_px(uint32_t format, uint32_t height_px)
{
    if (ubwc_enc_is_rgba_format(format)) {
        return ubwc_enc_align_up_u32(height_px, ubwc_enc_tile_h(format) * 4u);
    }
    return ubwc_enc_stored_uv_height_px(format, height_px) * 2u;
}

static inline uint32_t ubwc_enc_tile_rows(uint32_t format, uint32_t height_px)
{
    return ubwc_enc_stored_height_px(format, height_px) / ubwc_enc_tile_h(format);
}

static inline uint32_t ubwc_enc_uv_tile_rows(uint32_t format, uint32_t height_px)
{
    if (ubwc_enc_is_rgba_format(format)) {
        return 0u;
    }
    return ubwc_enc_stored_uv_height_px(format, height_px) / ubwc_enc_tile_h(format);
}

static inline uint32_t ubwc_enc_y_tile_cols(uint32_t format, uint32_t width_px)
{
    return ubwc_enc_tile_cols(format, width_px);
}

static inline uint32_t ubwc_enc_uv_tile_cols(uint32_t format, uint32_t width_px)
{
    return ubwc_enc_is_rgba_format(format) ? 0u : ubwc_enc_tile_cols(format, width_px);
}

static inline uint32_t ubwc_enc_meta_last_xcoord(uint32_t format, uint32_t width_px)
{
    uint32_t y_cols = ubwc_enc_y_tile_cols(format, width_px);
    uint32_t uv_cols = ubwc_enc_uv_tile_cols(format, width_px);
    uint32_t total_cols = (y_cols >= uv_cols) ? y_cols : uv_cols;
    return (total_cols == 0u) ? 0u : (total_cols - 1u);
}

static inline uint32_t ubwc_enc_surface_pitch_bytes(uint32_t format, uint32_t width_px)
{
    uint32_t tile_w = ubwc_enc_tile_w(format);
    uint32_t bpp = ubwc_enc_bytes_per_pixel(format);
    return ubwc_enc_align_up_u32(width_px * bpp, tile_w * 4u * bpp);
}

static inline uint32_t ubwc_enc_tile_pitch(uint32_t format, uint32_t width_px)
{
    return ubwc_enc_surface_pitch_bytes(format, width_px) / 16u;
}

static inline uint32_t ubwc_enc_meta_data_plane_pitch(uint32_t format, uint32_t width_px)
{
    return ubwc_enc_align_up_u32(ubwc_enc_tile_cols(format, width_px), 64u);
}

static inline uint32_t ubwc_enc_meta_plane_size(uint32_t format,
                                                uint32_t width_px,
                                                uint32_t height_px)
{
    uint32_t meta_pitch = ubwc_enc_meta_data_plane_pitch(format, width_px);
    uint32_t meta_lines = ubwc_enc_align_up_u32(ubwc_enc_tile_rows(format, height_px), 16u);
    return ubwc_enc_align_up_u32(meta_pitch * meta_lines, 4096u);
}

static inline uint32_t ubwc_enc_tile_plane_size(uint32_t format,
                                                uint32_t width_px,
                                                uint32_t height_px)
{
    uint32_t pitch = ubwc_enc_surface_pitch_bytes(format, width_px);
    uint32_t stored_height = ubwc_enc_stored_height_px(format, height_px);
    return ubwc_enc_align_up_u32(pitch * stored_height, 4096u);
}

static inline uint32_t ubwc_enc_meta_uv_plane_size(uint32_t format,
                                                   uint32_t width_px,
                                                   uint32_t height_px)
{
    uint32_t meta_pitch = ubwc_enc_meta_data_plane_pitch(format, width_px);
    uint32_t meta_lines = ubwc_enc_align_up_u32(ubwc_enc_uv_tile_rows(format, height_px), 16u);
    return ubwc_enc_align_up_u32(meta_pitch * meta_lines, 4096u);
}

static inline uint32_t ubwc_enc_tile_uv_plane_size(uint32_t format,
                                                   uint32_t width_px,
                                                   uint32_t height_px)
{
    uint32_t pitch = ubwc_enc_surface_pitch_bytes(format, width_px);
    uint32_t stored_height = ubwc_enc_stored_uv_height_px(format, height_px);
    return ubwc_enc_align_up_u32(pitch * stored_height, 4096u);
}

static inline ubwc_enc_layout_size_t ubwc_enc_layout_sizes(uint32_t format,
                                                          uint32_t width_px,
                                                          uint32_t height_px)
{
    ubwc_enc_layout_size_t s;

    s.meta_y_size = ubwc_enc_meta_plane_size(format, width_px, height_px);
    s.tile_y_size = ubwc_enc_tile_plane_size(format, width_px, height_px);
    if (ubwc_enc_is_rgba_format(format)) {
        s.meta_uv_size = 0u;
        s.tile_uv_size = 0u;
    } else {
        s.meta_uv_size = ubwc_enc_meta_uv_plane_size(format, width_px, height_px);
        s.tile_uv_size = ubwc_enc_tile_uv_plane_size(format, width_px, height_px);
    }
    s.total_size = s.meta_y_size + s.tile_y_size + s.meta_uv_size + s.tile_uv_size;
    return s;
}

static inline ubwc_enc_base_cfg_t ubwc_enc_layout_bases(uint32_t format,
                                                       uint32_t width_px,
                                                       uint32_t height_px,
                                                       uint64_t meta_y_base_addr)
{
    ubwc_enc_layout_size_t s = ubwc_enc_layout_sizes(format, width_px, height_px);
    ubwc_enc_base_cfg_t b;

    b.meta_base_y = meta_y_base_addr;
    b.tile_base_y = meta_y_base_addr + s.meta_y_size;
    if (ubwc_enc_is_rgba_format(format)) {
        b.meta_base_uv = 0u;
        b.tile_base_uv = 0u;
    } else {
        b.meta_base_uv = b.tile_base_y + s.tile_y_size;
        b.tile_base_uv = b.meta_base_uv + s.meta_uv_size;
    }
    return b;
}

static inline uint32_t ubwc_enc_reg_tile_cfg0(uint32_t enc_ubwc_en,
                                             uint32_t lvl1_bank_swizzle_en,
                                             uint32_t lvl2_bank_swizzle_en,
                                             uint32_t lvl3_bank_swizzle_en,
                                             uint32_t highest_bank_bit,
                                             uint32_t bank_spread_en)
{
    return ((enc_ubwc_en & 1u) << 0) |
           ((lvl1_bank_swizzle_en & 1u) << 1) |
           ((lvl2_bank_swizzle_en & 1u) << 2) |
           ((lvl3_bank_swizzle_en & 1u) << 3) |
           ((highest_bank_bit & 0x1fu) << 8) |
           ((bank_spread_en & 1u) << 16);
}

static inline uint32_t ubwc_enc_reg_tile_cfg1(uint32_t format, uint32_t width_px)
{
    uint32_t four_line_format = ubwc_enc_is_rgba_format(format) ? 1u : 0u;
    uint32_t lossy_rgba_2_1 = (format == UBWC_ENC_FMT_RGBA8888_L_2_1) ? 1u : 0u;
    uint32_t tile_pitch = ubwc_enc_tile_pitch(format, width_px);
    return (four_line_format << 0) |
           (lossy_rgba_2_1 << 1) |
           ((tile_pitch & 0x7ffu) << 16);
}

static inline uint32_t ubwc_enc_reg_enc_ci_cfg0(uint32_t input_type, uint32_t alen)
{
    return ((input_type & 1u) << 0) | ((alen & 7u) << 8);
}

static inline uint32_t ubwc_enc_reg_enc_ci_cfg1(uint32_t sb, uint32_t lossy)
{
    return (sb & 0xffffu) | ((lossy & 1u) << 16);
}

static inline uint32_t ubwc_enc_reg_enc_ci_cfg2(void)
{
    return 0u;
}

static inline uint32_t ubwc_enc_reg_enc_ci_cfg3(void)
{
    return 0u;
}

static inline uint32_t ubwc_enc_reg_otf_cfg0(uint32_t format)
{
    return format & 7u;
}

static inline uint32_t ubwc_enc_reg_otf_cfg1(uint32_t width_px, uint32_t height_px)
{
    return (width_px & 0xffffu) | ((height_px & 0xffffu) << 16);
}

static inline uint32_t ubwc_enc_reg_otf_cfg2(uint32_t format)
{
    return (ubwc_enc_tile_w(format) & 0xffffu) |
           ((ubwc_enc_tile_h(format) & 0xfu) << 16);
}

static inline uint32_t ubwc_enc_reg_otf_cfg3(uint32_t format, uint32_t width_px)
{
    return (ubwc_enc_y_tile_cols(format, width_px) & 0xffffu) |
           ((ubwc_enc_uv_tile_cols(format, width_px) & 0xffffu) << 16);
}

static inline uint32_t ubwc_enc_reg_meta_active_size(uint32_t width_px, uint32_t height_px)
{
    return (width_px & 0xffffu) | ((height_px & 0xffffu) << 16);
}

static inline uint32_t ubwc_enc_reg_meta_pitch(uint32_t format, uint32_t width_px)
{
    return ubwc_enc_meta_data_plane_pitch(format, width_px);
}

static inline uint32_t ubwc_enc_reg_base_lo(uint64_t base_addr)
{
    return (uint32_t)(base_addr & 0xffffffffull);
}

static inline uint32_t ubwc_enc_reg_base_hi(uint64_t base_addr)
{
    return (uint32_t)((base_addr >> 32) & 0xffffffffull);
}

static inline uint32_t ubwc_enc_reg_irq_ctrl(uint32_t irq_enable,
                                             uint32_t do_start,
                                             uint32_t vsync_reset_en)
{
    return (irq_enable & 1u) |
           ((do_start & 1u) << 5) |
           ((vsync_reset_en & 1u) << 6);
}

static inline ubwc_enc_config_t ubwc_enc_default_config(uint32_t format,
                                                       uint32_t width_px,
                                                       uint32_t height_px,
                                                       const ubwc_enc_base_cfg_t *base)
{
    ubwc_enc_base_cfg_t zero_base = {0u, 0u, 0u, 0u};
    const ubwc_enc_base_cfg_t *b = (base == 0) ? &zero_base : base;
    ubwc_enc_config_t cfg;
    uint32_t lossy = (format == UBWC_ENC_FMT_RGBA8888_L_2_1) ? 1u : 0u;

    cfg.format = format;
    cfg.active_width_px = width_px;
    cfg.active_height_px = height_px;
    cfg.otf_width_px = width_px;
    cfg.otf_height_px = height_px;
    cfg.base = *b;
    cfg.enc_ubwc_en = 1u;
    cfg.lvl1_bank_swizzle_en = 0u;
    cfg.lvl2_bank_swizzle_en = 1u;
    cfg.lvl3_bank_swizzle_en = 1u;
    cfg.highest_bank_bit = 16u;
    cfg.bank_spread_en = 1u;
    cfg.ci_input_type = 1u;
    cfg.ci_alen = 7u;
    cfg.ci_lossy = lossy;
    cfg.ci_cfg2 = ubwc_enc_reg_enc_ci_cfg2();
    cfg.ci_cfg3 = ubwc_enc_reg_enc_ci_cfg3();
    cfg.irq_enable = 1u;
    cfg.do_start = 1u;
    cfg.vsync_reset_en = 0u;
    return cfg;
}

static inline size_t ubwc_enc_make_reg_writes_ex(const ubwc_enc_config_t *cfg,
                                                 ubwc_enc_reg_write_t *out,
                                                 size_t out_count)
{
    ubwc_enc_config_t zero_cfg = ubwc_enc_default_config(UBWC_ENC_FMT_RGBA8888,
                                                        0u,
                                                        0u,
                                                        0);
    const ubwc_enc_config_t *c = (cfg == 0) ? &zero_cfg : cfg;
    ubwc_enc_reg_write_t regs[] = {
        {UBWC_ENC_REG_TILE_CFG1,        ubwc_enc_reg_tile_cfg1(c->format, c->active_width_px), "REG_TILE_CFG1"},
        {UBWC_ENC_REG_TILE_CFG0,        ubwc_enc_reg_tile_cfg0(c->enc_ubwc_en, c->lvl1_bank_swizzle_en, c->lvl2_bank_swizzle_en, c->lvl3_bank_swizzle_en, c->highest_bank_bit, c->bank_spread_en), "REG_TILE_CFG0"},
        {UBWC_ENC_REG_META_BASE_Y_LO,   ubwc_enc_reg_base_lo(c->base.meta_base_y), "REG_META_BASE_Y_LO"},
        {UBWC_ENC_REG_META_BASE_Y_HI,   ubwc_enc_reg_base_hi(c->base.meta_base_y), "REG_META_BASE_Y_HI"},
        {UBWC_ENC_REG_TILE_BASE_Y_LO,   ubwc_enc_reg_base_lo(c->base.tile_base_y), "REG_TILE_BASE_Y_LO"},
        {UBWC_ENC_REG_TILE_BASE_Y_HI,   ubwc_enc_reg_base_hi(c->base.tile_base_y), "REG_TILE_BASE_Y_HI"},
        {UBWC_ENC_REG_META_BASE_UV_LO,  ubwc_enc_reg_base_lo(c->base.meta_base_uv), "REG_META_BASE_UV_LO"},
        {UBWC_ENC_REG_META_BASE_UV_HI,  ubwc_enc_reg_base_hi(c->base.meta_base_uv), "REG_META_BASE_UV_HI"},
        {UBWC_ENC_REG_TILE_BASE_UV_LO,  ubwc_enc_reg_base_lo(c->base.tile_base_uv), "REG_TILE_BASE_UV_LO"},
        {UBWC_ENC_REG_TILE_BASE_UV_HI,  ubwc_enc_reg_base_hi(c->base.tile_base_uv), "REG_TILE_BASE_UV_HI"},
        {UBWC_ENC_REG_ENC_CI_CFG1,      ubwc_enc_reg_enc_ci_cfg1(0u, c->ci_lossy), "REG_ENC_CI_CFG1"},
        {UBWC_ENC_REG_ENC_CI_CFG2,      c->ci_cfg2, "REG_ENC_CI_CFG2"},
        {UBWC_ENC_REG_ENC_CI_CFG3,      c->ci_cfg3, "REG_ENC_CI_CFG3"},
        {UBWC_ENC_REG_ENC_CI_CFG0,      ubwc_enc_reg_enc_ci_cfg0(c->ci_input_type, c->ci_alen), "REG_ENC_CI_CFG0"},
        {UBWC_ENC_REG_OTF_CFG1,         ubwc_enc_reg_otf_cfg1(c->otf_width_px, c->otf_height_px), "REG_OTF_CFG1"},
        {UBWC_ENC_REG_OTF_CFG2,         ubwc_enc_reg_otf_cfg2(c->format), "REG_OTF_CFG2"},
        {UBWC_ENC_REG_OTF_CFG3,         ubwc_enc_reg_otf_cfg3(c->format, c->active_width_px), "REG_OTF_CFG3"},
        {UBWC_ENC_REG_META_ACTIVE_SIZE, ubwc_enc_reg_meta_active_size(c->active_width_px, c->active_height_px), "REG_META_ACTIVE_SIZE"},
        {UBWC_ENC_REG_META_PITCH,       ubwc_enc_reg_meta_pitch(c->format, c->active_width_px), "REG_META_PITCH"},
        {UBWC_ENC_REG_OTF_CFG0,         ubwc_enc_reg_otf_cfg0(c->format), "REG_OTF_CFG0"},
        {UBWC_ENC_REG_IRQ_CTRL,         ubwc_enc_reg_irq_ctrl(c->irq_enable, c->do_start, c->vsync_reset_en), "REG_IRQ_CTRL"}
    };
    size_t n = sizeof(regs) / sizeof(regs[0]);
    size_t i;

    if (out != 0) {
        size_t copy_n = (out_count < n) ? out_count : n;
        for (i = 0; i < copy_n; ++i) {
            out[i] = regs[i];
        }
    }
    return n;
}

static inline size_t ubwc_enc_make_reg_writes(uint32_t format,
                                              uint32_t width_px,
                                              uint32_t height_px,
                                              const ubwc_enc_base_cfg_t *base,
                                              ubwc_enc_reg_write_t *out,
                                              size_t out_count)
{
    ubwc_enc_config_t cfg = ubwc_enc_default_config(format, width_px, height_px, base);
    return ubwc_enc_make_reg_writes_ex(&cfg, out, out_count);
}

static inline size_t ubwc_enc_make_reg_writes_from_base(uint32_t format,
                                                       uint32_t width_px,
                                                       uint32_t height_px,
                                                       uint64_t meta_y_base_addr,
                                                       ubwc_enc_reg_write_t *out,
                                                       size_t out_count)
{
    ubwc_enc_base_cfg_t base = ubwc_enc_layout_bases(format, width_px, height_px,
                                                    meta_y_base_addr);
    return ubwc_enc_make_reg_writes(format, width_px, height_px, &base, out, out_count);
}

#ifdef __cplusplus
}
#endif

#endif
