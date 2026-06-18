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

int main(int argc, char **argv)
{
    int format;
    uint32_t width_px;
    uint32_t height_px;
    uint64_t base_addr;
    ubwc_dec_layout_size_t sizes;
    ubwc_dec_base_cfg_t bases;
    ubwc_dec_reg_write_t regs[32];
    size_t n;
    size_t i;

    if (argc != 4 && argc != 5) {
        fprintf(stderr, "Usage: %s <format> <width_px> <height_px> [meta_y_base_addr]\n", argv[0]);
        return 1;
    }

    format = parse_format(argv[1]);
    if (format < 0) {
        fprintf(stderr, "Unsupported format: %s\n", argv[1]);
        return 1;
    }

    width_px = (uint32_t)strtoul(argv[2], 0, 0);
    height_px = (uint32_t)strtoul(argv[3], 0, 0);
    base_addr = (argc == 5) ? strtoull(argv[4], 0, 0) : 0ull;

    sizes = ubwc_dec_layout_sizes((uint32_t)format, width_px, height_px);
    bases = ubwc_dec_layout_bases((uint32_t)format, width_px, height_px, base_addr);

    printf("UBWC DEC config: format=%d width=%u height=%u base=0x%llx\n",
           format, width_px, height_px, (unsigned long long)base_addr);
    printf("tile_w=%u tile_h=%u bpp=%u stored_y_height=%u stored_uv_height=%u\n",
           ubwc_dec_tile_w((uint32_t)format),
           ubwc_dec_tile_h((uint32_t)format),
           ubwc_dec_bytes_per_pixel((uint32_t)format),
           ubwc_dec_stored_height_px((uint32_t)format, height_px),
           ubwc_dec_stored_uv_height_px((uint32_t)format, height_px));
    printf("surface_pitch_bytes=%u tile_pitch=%u\n",
           ubwc_dec_surface_pitch_bytes((uint32_t)format, width_px),
           ubwc_dec_tile_pitch((uint32_t)format, width_px));
    printf("meta_tile_x_numbers=%u meta_tile_y_numbers=%u\n\n",
           ubwc_dec_tile_x_numbers((uint32_t)format, width_px),
           ubwc_dec_active_tile_y_numbers((uint32_t)format, height_px));
    printf("layout sizes: meta_y=0x%x tile_y=0x%x meta_uv=0x%x tile_uv=0x%x total=0x%x\n",
           sizes.meta_y_size, sizes.tile_y_size, sizes.meta_uv_size,
           sizes.tile_uv_size, sizes.total_size);
    printf("layout bases: meta_rgba_y=0x%llx tile_rgba_y=0x%llx meta_uv=0x%llx tile_uv=0x%llx\n\n",
           (unsigned long long)bases.meta_base_rgba_y,
           (unsigned long long)bases.tile_base_rgba_y,
           (unsigned long long)bases.meta_base_uv,
           (unsigned long long)bases.tile_base_uv);

    n = ubwc_dec_make_reg_writes((uint32_t)format, width_px, height_px, &bases, regs, 32);
    for (i = 0; i < n; ++i) {
        printf("write(0x%04x, 0x%08x);  // %s\n",
               regs[i].addr, regs[i].data, regs[i].name);
    }

    return 0;
}
