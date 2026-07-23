#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ubwc_dec_cfg.h"

static int parse_format(const char *s)
{
    if (strcmp(s, "0") == 0 || strcmp(s, "rgba8888") == 0) return UBWC_DEC_FMT_RGBA8888;
    if (strcmp(s, "1") == 0 || strcmp(s, "rgba1010102") == 0) return UBWC_DEC_FMT_RGBA1010102;
    if (strcmp(s, "2") == 0 || strcmp(s, "nv12") == 0 || strcmp(s, "yuv420_8") == 0) return UBWC_DEC_FMT_YUV420_8_NV12;
    if (strcmp(s, "3") == 0 || strcmp(s, "p010") == 0 || strcmp(s, "yuv420_10") == 0) return UBWC_DEC_FMT_YUV420_10_P010;
    if (strcmp(s, "4") == 0 || strcmp(s, "rgba8888_l_2_1") == 0) return UBWC_DEC_FMT_RGBA8888_L_2_1;
    return -1;
}

static void print_status_read_map(void)
{
    printf("\nDEC read/status registers from dec_rotation:\n");
    printf("read(0x%04x);  // STATUS0: frame/busy/idle realtime status\n",
           UBWC_DEC_REG_STATUS0);
    printf("read(0x%04x);  // STATUS1: stage_done and stage_seen sticky status\n",
           UBWC_DEC_REG_STATUS1);
    printf("read(0x%04x);  // STATUS2: vivo idle status\n",
           UBWC_DEC_REG_STATUS2);
    printf("read(0x%04x);  // STATUS3: vivo error bits\n",
           UBWC_DEC_REG_STATUS3);
    printf("read(0x%04x);  // IRQ_CTRL: enable/start write bits and pending read bits\n",
           UBWC_DEC_REG_IRQ_CTRL);
    printf("read(0x%04x);  // STATUS4: irq_pending/error_pending/correct_pending\n",
           UBWC_DEC_REG_STATUS4);
    printf("read(0x%04x);  // STAT_META: metadata tile count\n",
           UBWC_DEC_REG_STAT_META);
    printf("read(0x%04x);  // STAT_TILE: tile address/read command count\n",
           UBWC_DEC_REG_STAT_TILE);
    printf("read(0x%04x);  // STAT_OTF_TILE: OTF tile count\n",
           UBWC_DEC_REG_STAT_OTF_TILE);
    printf("read(0x%04x);  // STAT_OTF_LINE: OTF line count\n",
           UBWC_DEC_REG_STAT_OTF_LINE);
    printf("read(0x%04x);  // STAT_OTF_DE: OTF valid data beat count\n",
           UBWC_DEC_REG_STAT_OTF_DE);
}

int main(int argc, char **argv)
{
    int format;
    uint32_t width_px;
    uint32_t height_px;
    uint32_t rotate_mode;
    uint64_t base_addr;
    ubwc_dec_layout_size_t sizes;
    ubwc_dec_base_cfg_t bases;
    ubwc_dec_config_t cfg;
    ubwc_dec_reg_write_t regs[32];
    uint32_t meta_cfg0_readback;
    size_t n;
    size_t i;

    if (argc < 4 || argc > 6) {
        fprintf(stderr, "Usage: %s <format> <width_px> <height_px> [meta_y_base_addr] [rotate_mode]\n", argv[0]);
        return 1;
    }

    format = parse_format(argv[1]);
    if (format < 0) {
        fprintf(stderr, "Unsupported format: %s\n", argv[1]);
        return 1;
    }

    width_px = (uint32_t)strtoul(argv[2], 0, 0);
    height_px = (uint32_t)strtoul(argv[3], 0, 0);
    base_addr = (argc >= 5) ? strtoull(argv[4], 0, 0) : 0ull;
    rotate_mode = (argc == 6) ? (uint32_t)strtoul(argv[5], 0, 0) : 0u;

    sizes = ubwc_dec_layout_sizes((uint32_t)format, width_px, height_px);
    bases = ubwc_dec_layout_bases((uint32_t)format, width_px, height_px, base_addr);
    cfg = ubwc_dec_default_config((uint32_t)format, width_px, height_px, &bases);
    ubwc_dec_apply_rotate_mode(&cfg, rotate_mode);
    meta_cfg0_readback = ubwc_dec_reg_meta_cfg0_from_otf((uint32_t)format,
                                                         cfg.width_px,
                                                         cfg.h_act,
                                                         cfg.v_act,
                                                         cfg.rotate_mode);

    printf("UBWC DEC config: format=%d width=%u height=%u base=0x%llx rotate_req=%u rotate_eff=%u\n",
           format, width_px, height_px, (unsigned long long)base_addr,
           rotate_mode, cfg.rotate_mode);
    if ((rotate_mode & 0x3u) != 0u && cfg.rotate_mode == 0u) {
        printf("rotation disabled: dec_rotation only enables rotation for NV12 with source height <= 1080\n");
    }
    printf("tile_w=%u tile_h=%u bpp=%u stored_y_height=%u stored_uv_height=%u\n",
           ubwc_dec_tile_w((uint32_t)format),
           ubwc_dec_tile_h((uint32_t)format),
           ubwc_dec_bytes_per_pixel((uint32_t)format),
           ubwc_dec_stored_height_px((uint32_t)format, height_px),
           ubwc_dec_stored_uv_height_px((uint32_t)format, height_px));
    printf("surface_pitch_bytes=%u tile_pitch=%u\n",
           ubwc_dec_surface_pitch_bytes((uint32_t)format, width_px),
           ubwc_dec_tile_pitch((uint32_t)format, width_px));
    printf("ci_ubwc_ver=%u\n", cfg.ci_ubwc_ver);
    printf("meta_tile_x_numbers=%u meta_tile_y_numbers=%u  // APB 0x002c is hardware-derived RO\n\n",
           meta_cfg0_readback & 0xffffu,
           (meta_cfg0_readback >> 16) & 0xffffu);
    printf("layout sizes: meta_y=0x%x tile_y=0x%x meta_uv=0x%x tile_uv=0x%x total=0x%x\n",
           sizes.meta_y_size, sizes.tile_y_size, sizes.meta_uv_size,
           sizes.tile_uv_size, sizes.total_size);
    printf("layout bases: meta_rgba_y=0x%llx tile_rgba_y=0x%llx meta_uv=0x%llx tile_uv=0x%llx\n\n",
           (unsigned long long)bases.meta_base_rgba_y,
           (unsigned long long)bases.tile_base_rgba_y,
           (unsigned long long)bases.meta_base_uv,
           (unsigned long long)bases.tile_base_uv);

    n = ubwc_dec_make_reg_writes_ex(&cfg, regs, 32);
    for (i = 0; i < n; ++i) {
        printf("write(0x%04x, 0x%08x);  // %s\n",
               regs[i].addr, regs[i].data, regs[i].name);
    }

    print_status_read_map();

    return 0;
}
