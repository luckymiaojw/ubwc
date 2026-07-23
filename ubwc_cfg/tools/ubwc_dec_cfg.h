#ifndef UBWC_DEC_CFG_H
#define UBWC_DEC_CFG_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

enum {
    UBWC_DEC_FMT_RGBA8888       = 0,
    UBWC_DEC_FMT_RGBA1010102    = 1,
    UBWC_DEC_FMT_YUV420_8_NV12  = 2,
    UBWC_DEC_FMT_YUV420_10_P010 = 3,
    UBWC_DEC_FMT_RGBA8888_L_2_1 = 4
};

enum {
    UBWC_DEC_REG_TILE_CFG0   = 0x0008,
    UBWC_DEC_REG_TILE_CFG1   = 0x000c,
    UBWC_DEC_REG_TILE_CFG2   = 0x0010,
    UBWC_DEC_REG_VIVO_CFG    = 0x0014,
    UBWC_DEC_REG_OTF_CFG0    = 0x0018,
    UBWC_DEC_REG_OTF_CFG1    = 0x001c,
    UBWC_DEC_REG_OTF_CFG2    = 0x0020,
    UBWC_DEC_REG_OTF_CFG3    = 0x0024,
    UBWC_DEC_REG_OTF_CFG4    = 0x0028,
    UBWC_DEC_REG_META_CFG0   = 0x002c,
    UBWC_DEC_REG_META_BASE_Y_LO  = 0x0030,
    UBWC_DEC_REG_META_BASE_Y_HI  = 0x0034,
    UBWC_DEC_REG_TILE_BASE_Y_LO  = 0x0038,
    UBWC_DEC_REG_TILE_BASE_Y_HI  = 0x003c,
    UBWC_DEC_REG_META_BASE_UV_LO = 0x0040,
    UBWC_DEC_REG_META_BASE_UV_HI = 0x0044,
    UBWC_DEC_REG_TILE_BASE_UV_LO = 0x0048,
    UBWC_DEC_REG_TILE_BASE_UV_HI = 0x004c,
    UBWC_DEC_REG_STATUS0         = 0x0050,
    UBWC_DEC_REG_STATUS1         = 0x0054,
    UBWC_DEC_REG_STATUS2         = 0x0058,
    UBWC_DEC_REG_STATUS3         = 0x005c,
    UBWC_DEC_REG_IRQ_CTRL        = 0x0060,
    UBWC_DEC_REG_STATUS4         = 0x0064,
    UBWC_DEC_REG_STAT_META       = 0x0068,
    UBWC_DEC_REG_STAT_TILE       = 0x006c,
    UBWC_DEC_REG_STAT_OTF_TILE   = 0x0070,
    UBWC_DEC_REG_STAT_OTF_LINE   = 0x0074,
    UBWC_DEC_REG_STAT_OTF_DE     = 0x0078
};

typedef struct {
    uint16_t addr;
    uint32_t data;
    const char *name;
} ubwc_dec_reg_write_t;

typedef struct {
    uint64_t tile_base_rgba_y;
    uint64_t tile_base_uv;
    uint64_t meta_base_rgba_y;
    uint64_t meta_base_uv;
} ubwc_dec_base_cfg_t;

typedef struct {
    uint32_t meta_y_size;
    uint32_t tile_y_size;
    uint32_t meta_uv_size;
    uint32_t tile_uv_size;
    uint32_t total_size;
} ubwc_dec_layout_size_t;

typedef struct {
    uint32_t format;
    uint32_t width_px;
    uint32_t height_px;
    ubwc_dec_base_cfg_t base;
    uint32_t h_total;
    uint32_t h_sync;
    uint32_t h_bp;
    uint32_t h_act;
    uint32_t v_total;
    uint32_t v_sync;
    uint32_t v_bp;
    uint32_t v_act;
    uint32_t rotate_mode;
    uint32_t lvl1_bank_swizzle_en;
    uint32_t lvl2_bank_swizzle_en;
    uint32_t lvl3_bank_swizzle_en;
    uint32_t highest_bank_bit;
    uint32_t bank_spread_en;
    uint32_t ci_input_type;
    uint32_t ci_lossy;
    uint32_t ci_alpha_mode;
    uint32_t ci_ubwc_ver;
    uint32_t vivo_ubwc_en;
    uint32_t vivo_sreset;
    uint32_t irq_enable;
    uint32_t do_start;
} ubwc_dec_config_t;

static inline uint32_t ubwc_dec_align_up_u32(uint32_t value, uint32_t unit)
{
    return ((value + unit - 1u) / unit) * unit;
}

static inline uint32_t ubwc_dec_ceil_div_u32(uint32_t value, uint32_t unit)
{
    return (value + unit - 1u) / unit;
}

static inline uint32_t ubwc_dec_base_format(uint32_t format)
{
    return (format == UBWC_DEC_FMT_RGBA8888_L_2_1) ? UBWC_DEC_FMT_RGBA8888 : (format & 0x1fu);
}

static inline uint32_t ubwc_dec_is_rgba_format(uint32_t format)
{
    return (format == UBWC_DEC_FMT_RGBA8888) ||
           (format == UBWC_DEC_FMT_RGBA1010102) ||
           (format == UBWC_DEC_FMT_RGBA8888_L_2_1);
}

static inline uint32_t ubwc_dec_tile_w(uint32_t format)
{
    return ubwc_dec_is_rgba_format(format) ? 16u : 32u;
}

static inline uint32_t ubwc_dec_tile_h(uint32_t format)
{
    if ((format == UBWC_DEC_FMT_RGBA8888) ||
        (format == UBWC_DEC_FMT_RGBA1010102) ||
        (format == UBWC_DEC_FMT_RGBA8888_L_2_1) ||
        (format == UBWC_DEC_FMT_YUV420_10_P010)) {
        return 4u;
    }
    return 8u;
}

static inline uint32_t ubwc_dec_bytes_per_pixel(uint32_t format)
{
    if (ubwc_dec_is_rgba_format(format)) {
        return 4u;
    }
    if (format == UBWC_DEC_FMT_YUV420_10_P010) {
        return 2u;
    }
    return 1u;
}

static inline uint32_t ubwc_dec_aligned_width_px(uint32_t format, uint32_t width_px)
{
    uint32_t tile_w = ubwc_dec_tile_w(format);
    return ubwc_dec_align_up_u32(width_px, tile_w * 4u);
}

static inline uint32_t ubwc_dec_uv_height_px(uint32_t height_px)
{
    return ubwc_dec_ceil_div_u32(height_px, 2u);
}

static inline uint32_t ubwc_dec_stored_uv_height_px(uint32_t format, uint32_t height_px)
{
    if (ubwc_dec_is_rgba_format(format)) {
        return 0u;
    }
    return ubwc_dec_align_up_u32(ubwc_dec_uv_height_px(height_px),
                                 ubwc_dec_tile_h(format) * 4u);
}

static inline uint32_t ubwc_dec_stored_height_px(uint32_t format, uint32_t height_px)
{
    if (ubwc_dec_is_rgba_format(format)) {
        return ubwc_dec_align_up_u32(height_px, ubwc_dec_tile_h(format) * 4u);
    }
    return ubwc_dec_stored_uv_height_px(format, height_px) * 2u;
}

static inline uint32_t ubwc_dec_tile_x_numbers(uint32_t format, uint32_t width_px)
{
    return ubwc_dec_ceil_div_u32(ubwc_dec_aligned_width_px(format, width_px),
                                 ubwc_dec_tile_w(format));
}

static inline uint32_t ubwc_dec_tile_y_numbers(uint32_t format, uint32_t height_px)
{
    return ubwc_dec_stored_height_px(format, height_px) / ubwc_dec_tile_h(format);
}

static inline uint32_t ubwc_dec_uv_tile_y_numbers(uint32_t format, uint32_t height_px)
{
    if (ubwc_dec_is_rgba_format(format)) {
        return 0u;
    }
    return ubwc_dec_stored_uv_height_px(format, height_px) / ubwc_dec_tile_h(format);
}

static inline uint32_t ubwc_dec_active_tile_y_numbers(uint32_t format, uint32_t height_px)
{
    return ubwc_dec_ceil_div_u32(height_px, ubwc_dec_tile_h(format));
}

static inline uint32_t ubwc_dec_is_nv12_format(uint32_t format)
{
    return format == UBWC_DEC_FMT_YUV420_8_NV12;
}

static inline uint32_t ubwc_dec_rotate_is_supported(uint32_t format,
                                                    uint32_t src_height_px,
                                                    uint32_t rotate_mode)
{
    return ((rotate_mode & 0x3u) != 0u) &&
           ubwc_dec_is_nv12_format(format) &&
           (src_height_px <= 1080u);
}

static inline uint32_t ubwc_dec_surface_pitch_bytes(uint32_t format, uint32_t width_px)
{
    uint32_t tile_w = ubwc_dec_tile_w(format);
    uint32_t bpp = ubwc_dec_bytes_per_pixel(format);
    return ubwc_dec_align_up_u32(width_px * bpp, tile_w * 4u * bpp);
}

static inline uint32_t ubwc_dec_tile_pitch(uint32_t format, uint32_t width_px)
{
    return ubwc_dec_surface_pitch_bytes(format, width_px) / 16u;
}

static inline uint32_t ubwc_dec_meta_data_plane_pitch(uint32_t format, uint32_t width_px)
{
    return ubwc_dec_align_up_u32(ubwc_dec_tile_x_numbers(format, width_px), 64u);
}

static inline uint32_t ubwc_dec_meta_plane_size(uint32_t format,
                                                uint32_t width_px,
                                                uint32_t height_px)
{
    uint32_t meta_pitch = ubwc_dec_meta_data_plane_pitch(format, width_px);
    uint32_t meta_lines = ubwc_dec_align_up_u32(ubwc_dec_tile_y_numbers(format, height_px), 16u);
    return ubwc_dec_align_up_u32(meta_pitch * meta_lines, 4096u);
}

static inline uint32_t ubwc_dec_tile_plane_size(uint32_t format,
                                                uint32_t width_px,
                                                uint32_t height_px)
{
    uint32_t pitch = ubwc_dec_surface_pitch_bytes(format, width_px);
    uint32_t stored_height = ubwc_dec_stored_height_px(format, height_px);
    return ubwc_dec_align_up_u32(pitch * stored_height, 4096u);
}

static inline uint32_t ubwc_dec_meta_uv_plane_size(uint32_t format,
                                                   uint32_t width_px,
                                                   uint32_t height_px)
{
    uint32_t meta_pitch = ubwc_dec_meta_data_plane_pitch(format, width_px);
    uint32_t meta_lines = ubwc_dec_align_up_u32(ubwc_dec_uv_tile_y_numbers(format, height_px), 16u);
    return ubwc_dec_align_up_u32(meta_pitch * meta_lines, 4096u);
}

static inline uint32_t ubwc_dec_tile_uv_plane_size(uint32_t format,
                                                   uint32_t width_px,
                                                   uint32_t height_px)
{
    uint32_t pitch = ubwc_dec_surface_pitch_bytes(format, width_px);
    uint32_t stored_height = ubwc_dec_stored_uv_height_px(format, height_px);
    return ubwc_dec_align_up_u32(pitch * stored_height, 4096u);
}

static inline ubwc_dec_layout_size_t ubwc_dec_layout_sizes(uint32_t format,
                                                          uint32_t width_px,
                                                          uint32_t height_px)
{
    ubwc_dec_layout_size_t s;

    s.meta_y_size = ubwc_dec_meta_plane_size(format, width_px, height_px);
    s.tile_y_size = ubwc_dec_tile_plane_size(format, width_px, height_px);
    if (ubwc_dec_is_rgba_format(format)) {
        s.meta_uv_size = 0u;
        s.tile_uv_size = 0u;
    } else {
        s.meta_uv_size = ubwc_dec_meta_uv_plane_size(format, width_px, height_px);
        s.tile_uv_size = ubwc_dec_tile_uv_plane_size(format, width_px, height_px);
    }
    s.total_size = s.meta_y_size + s.tile_y_size + s.meta_uv_size + s.tile_uv_size;
    return s;
}

static inline ubwc_dec_base_cfg_t ubwc_dec_layout_bases(uint32_t format,
                                                       uint32_t width_px,
                                                       uint32_t height_px,
                                                       uint64_t meta_y_base_addr)
{
    ubwc_dec_layout_size_t s = ubwc_dec_layout_sizes(format, width_px, height_px);
    ubwc_dec_base_cfg_t b;

    b.meta_base_rgba_y = meta_y_base_addr;
    if (ubwc_dec_is_rgba_format(format)) {
        b.tile_base_rgba_y = meta_y_base_addr + s.meta_y_size;
        b.meta_base_uv = 0u;
        b.tile_base_uv = 0u;
    } else {
        b.tile_base_rgba_y = meta_y_base_addr + s.meta_y_size;
        b.meta_base_uv = b.tile_base_rgba_y + s.tile_y_size;
        b.tile_base_uv = b.meta_base_uv + s.meta_uv_size;
    }
    return b;
}

static inline uint32_t ubwc_dec_reg_tile_cfg0(uint32_t lvl1_bank_swizzle_en,
                                             uint32_t lvl2_bank_swizzle_en,
                                             uint32_t lvl3_bank_swizzle_en,
                                             uint32_t highest_bank_bit,
                                             uint32_t bank_spread_en,
                                             uint32_t four_line_format,
                                             uint32_t lossy_rgba_2_1,
                                             uint32_t ubwc_ver)
{
    return ((lvl1_bank_swizzle_en & 1u) << 0) |
           ((lvl2_bank_swizzle_en & 1u) << 1) |
           ((lvl3_bank_swizzle_en & 1u) << 2) |
           ((highest_bank_bit & 0x1fu) << 4) |
           ((bank_spread_en & 1u) << 9) |
           ((four_line_format & 1u) << 10) |
           ((lossy_rgba_2_1 & 1u) << 11) |
           ((ubwc_ver & 0xfu) << 16);
}

static inline uint32_t ubwc_dec_reg_tile_cfg1(uint32_t format, uint32_t width_px)
{
    return ubwc_dec_tile_pitch(format, width_px) & 0xfffu;
}

static inline uint32_t ubwc_dec_reg_tile_cfg2_fields(uint32_t ci_input_type,
                                                    uint32_t ci_lossy,
                                                    uint32_t ci_alpha_mode)
{
    return ((ci_input_type & 1u) << 0) |
           ((ci_lossy & 1u) << 8) |
           ((ci_alpha_mode & 0x3u) << 9);
}

static inline uint32_t ubwc_dec_reg_tile_cfg2(uint32_t ci_input_type,
                                             uint32_t ci_lossy,
                                             uint32_t ci_alpha_mode)
{
    return ubwc_dec_reg_tile_cfg2_fields(ci_input_type,
                                         ci_lossy,
                                         ci_alpha_mode);
}

static inline uint32_t ubwc_dec_reg_vivo_cfg(uint32_t ubwc_en, uint32_t sreset)
{
    return (ubwc_en & 1u) | ((sreset & 1u) << 1);
}

static inline uint32_t ubwc_dec_reg_meta_cfg0(uint32_t format, uint32_t width_px, uint32_t height_px)
{
    return (ubwc_dec_tile_x_numbers(format, width_px) & 0xffffu) |
           ((ubwc_dec_active_tile_y_numbers(format, height_px) & 0xffffu) << 16);
}

static inline uint32_t ubwc_dec_reg_meta_cfg0_from_otf(uint32_t format,
                                                      uint32_t img_width_px,
                                                      uint32_t h_act,
                                                      uint32_t v_act,
                                                      uint32_t rotate_mode)
{
    uint32_t rotate_active = ubwc_dec_rotate_is_supported(format, h_act, rotate_mode);
    uint32_t src_width = rotate_active ? img_width_px : h_act;
    uint32_t src_height = rotate_active ? h_act : v_act;
    uint32_t tile_x = ubwc_dec_is_rgba_format(format) ?
                      (((src_width + 63u) >> 6) << 2) :
                      (((src_width + 127u) >> 7) << 2);
    uint32_t tile_y = ubwc_dec_is_nv12_format(format) ?
                      ((src_height + 7u) >> 3) :
                      ((src_height + 3u) >> 2);

    return (tile_x & 0xffffu) | ((tile_y & 0xffffu) << 16);
}

static inline uint32_t ubwc_dec_reg_otf_cfg0_ex(uint32_t format,
                                               uint32_t width_px,
                                               uint32_t rotate_mode)
{
    return (width_px & 0xffffu) |
           ((ubwc_dec_base_format(format) & 0x1fu) << 16) |
           ((rotate_mode & 0x3u) << 21);
}

static inline uint32_t ubwc_dec_reg_otf_cfg0(uint32_t format, uint32_t width_px)
{
    return ubwc_dec_reg_otf_cfg0_ex(format, width_px, 0u);
}

static inline uint32_t ubwc_dec_reg_otf_cfg1(uint32_t h_total, uint32_t h_sync)
{
    return (h_total & 0xffffu) | ((h_sync & 0xffffu) << 16);
}

static inline uint32_t ubwc_dec_reg_otf_cfg2(uint32_t h_bp, uint32_t h_act)
{
    return (h_bp & 0xffffu) | ((h_act & 0xffffu) << 16);
}

static inline uint32_t ubwc_dec_reg_otf_cfg3(uint32_t v_total, uint32_t v_sync)
{
    return (v_total & 0xffffu) | ((v_sync & 0xffffu) << 16);
}

static inline uint32_t ubwc_dec_reg_otf_cfg4(uint32_t v_bp, uint32_t v_act)
{
    return (v_bp & 0xffffu) | ((v_act & 0xffffu) << 16);
}

static inline uint32_t ubwc_dec_reg_base_lo(uint64_t base_addr)
{
    return (uint32_t)(base_addr & 0xffffffffull);
}

static inline uint32_t ubwc_dec_reg_base_hi(uint64_t base_addr)
{
    return (uint32_t)((base_addr >> 32) & 0xffffffffull);
}

static inline uint32_t ubwc_dec_reg_irq_ctrl(uint32_t irq_enable, uint32_t do_start)
{
    return (irq_enable & 1u) | ((do_start & 1u) << 5);
}

static inline ubwc_dec_config_t ubwc_dec_default_config(uint32_t format,
                                                       uint32_t width_px,
                                                       uint32_t height_px,
                                                       const ubwc_dec_base_cfg_t *base)
{
    ubwc_dec_base_cfg_t zero_base = {0u, 0u, 0u, 0u};
    const ubwc_dec_base_cfg_t *b = (base == 0) ? &zero_base : base;
    uint32_t lossy = (format == UBWC_DEC_FMT_RGBA8888_L_2_1) ? 1u : 0u;
    ubwc_dec_config_t cfg;

    cfg.format = format;
    cfg.width_px = width_px;
    cfg.height_px = height_px;
    cfg.base = *b;
    cfg.h_total = width_px;
    cfg.h_sync = 0u;
    cfg.h_bp = 0u;
    cfg.h_act = width_px;
    cfg.v_total = height_px;
    cfg.v_sync = 0u;
    cfg.v_bp = 0u;
    cfg.v_act = height_px;
    cfg.rotate_mode = 0u;
    cfg.lvl1_bank_swizzle_en = 0u;
    cfg.lvl2_bank_swizzle_en = 1u;
    cfg.lvl3_bank_swizzle_en = 1u;
    cfg.highest_bank_bit = 16u;
    cfg.bank_spread_en = 1u;
    cfg.ci_input_type = 1u;
    cfg.ci_lossy = lossy;
    cfg.ci_alpha_mode = 0u;
    cfg.ci_ubwc_ver = 7u;
    cfg.vivo_ubwc_en = 1u;
    cfg.vivo_sreset = 0u;
    cfg.irq_enable = 1u;
    cfg.do_start = 1u;
    return cfg;
}

static inline void ubwc_dec_apply_rotate_mode(ubwc_dec_config_t *cfg, uint32_t rotate_mode)
{
    uint32_t rotate_enable;

    if (cfg == 0) {
        return;
    }

    rotate_enable = ubwc_dec_rotate_is_supported(cfg->format, cfg->height_px, rotate_mode);
    cfg->rotate_mode = rotate_enable ? (rotate_mode & 0x3u) : 0u;
    if (rotate_enable) {
        cfg->h_total = cfg->height_px;
        cfg->h_act = cfg->height_px;
        cfg->v_total = cfg->width_px;
        cfg->v_act = cfg->width_px;
    }
}

static inline size_t ubwc_dec_make_reg_writes_ex(const ubwc_dec_config_t *cfg,
                                                 ubwc_dec_reg_write_t *out,
                                                 size_t out_count)
{
    ubwc_dec_config_t zero_cfg = ubwc_dec_default_config(UBWC_DEC_FMT_RGBA8888,
                                                        0u,
                                                        0u,
                                                        0);
    const ubwc_dec_config_t *c = (cfg == 0) ? &zero_cfg : cfg;
    uint32_t four_line = ubwc_dec_is_rgba_format(c->format) ? 1u : 0u;
    uint32_t lossy = (c->format == UBWC_DEC_FMT_RGBA8888_L_2_1) ? 1u : 0u;
    ubwc_dec_reg_write_t regs[] = {
        {UBWC_DEC_REG_TILE_CFG0, ubwc_dec_reg_tile_cfg0(c->lvl1_bank_swizzle_en, c->lvl2_bank_swizzle_en, c->lvl3_bank_swizzle_en, c->highest_bank_bit, c->bank_spread_en, four_line, lossy, c->ci_ubwc_ver), "APB_ADDR_TILE_CFG0"},
        {UBWC_DEC_REG_TILE_CFG1, ubwc_dec_reg_tile_cfg1(c->format, c->h_act), "APB_ADDR_TILE_CFG1"},
        {UBWC_DEC_REG_TILE_CFG2, ubwc_dec_reg_tile_cfg2_fields(c->ci_input_type, c->ci_lossy, c->ci_alpha_mode), "APB_ADDR_TILE_CFG2"},
        {UBWC_DEC_REG_VIVO_CFG,  ubwc_dec_reg_vivo_cfg(c->vivo_ubwc_en, c->vivo_sreset), "APB_ADDR_VIVO_CFG"},
        {UBWC_DEC_REG_OTF_CFG0,  ubwc_dec_reg_otf_cfg0_ex(c->format, c->width_px, c->rotate_mode), "APB_ADDR_OTF_CFG0"},
        {UBWC_DEC_REG_OTF_CFG1,  ubwc_dec_reg_otf_cfg1(c->h_total, c->h_sync), "APB_ADDR_OTF_CFG1"},
        {UBWC_DEC_REG_OTF_CFG2,  ubwc_dec_reg_otf_cfg2(c->h_bp, c->h_act), "APB_ADDR_OTF_CFG2"},
        {UBWC_DEC_REG_OTF_CFG3,  ubwc_dec_reg_otf_cfg3(c->v_total, c->v_sync), "APB_ADDR_OTF_CFG3"},
        {UBWC_DEC_REG_OTF_CFG4,  ubwc_dec_reg_otf_cfg4(c->v_bp, c->v_act), "APB_ADDR_OTF_CFG4"},
        {UBWC_DEC_REG_META_BASE_Y_LO, ubwc_dec_reg_base_lo(c->base.meta_base_rgba_y), "REG_META_BASE_Y_LO"},
        {UBWC_DEC_REG_META_BASE_Y_HI, ubwc_dec_reg_base_hi(c->base.meta_base_rgba_y), "REG_META_BASE_Y_HI"},
        {UBWC_DEC_REG_TILE_BASE_Y_LO, ubwc_dec_reg_base_lo(c->base.tile_base_rgba_y), "REG_TILE_BASE_Y_LO"},
        {UBWC_DEC_REG_TILE_BASE_Y_HI, ubwc_dec_reg_base_hi(c->base.tile_base_rgba_y), "REG_TILE_BASE_Y_HI"},
        {UBWC_DEC_REG_META_BASE_UV_LO, ubwc_dec_reg_base_lo(c->base.meta_base_uv), "REG_META_BASE_UV_LO"},
        {UBWC_DEC_REG_META_BASE_UV_HI, ubwc_dec_reg_base_hi(c->base.meta_base_uv), "REG_META_BASE_UV_HI"},
        {UBWC_DEC_REG_TILE_BASE_UV_LO, ubwc_dec_reg_base_lo(c->base.tile_base_uv), "REG_TILE_BASE_UV_LO"},
        {UBWC_DEC_REG_TILE_BASE_UV_HI, ubwc_dec_reg_base_hi(c->base.tile_base_uv), "REG_TILE_BASE_UV_HI"},
        {UBWC_DEC_REG_IRQ_CTRL, ubwc_dec_reg_irq_ctrl(c->irq_enable, c->do_start), "APB_ADDR_IRQ_CTRL"}
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

static inline size_t ubwc_dec_make_reg_writes(uint32_t format,
                                              uint32_t width_px,
                                              uint32_t height_px,
                                              const ubwc_dec_base_cfg_t *base,
                                              ubwc_dec_reg_write_t *out,
                                              size_t out_count)
{
    ubwc_dec_config_t cfg = ubwc_dec_default_config(format, width_px, height_px, base);
    return ubwc_dec_make_reg_writes_ex(&cfg, out, out_count);
}

static inline size_t ubwc_dec_make_reg_writes_from_base(uint32_t format,
                                                       uint32_t width_px,
                                                       uint32_t height_px,
                                                       uint64_t meta_y_base_addr,
                                                       ubwc_dec_reg_write_t *out,
                                                       size_t out_count)
{
    ubwc_dec_base_cfg_t base = ubwc_dec_layout_bases(format, width_px, height_px,
                                                    meta_y_base_addr);
    return ubwc_dec_make_reg_writes(format, width_px, height_px, &base, out, out_count);
}

#ifdef __cplusplus
}
#endif

#endif
