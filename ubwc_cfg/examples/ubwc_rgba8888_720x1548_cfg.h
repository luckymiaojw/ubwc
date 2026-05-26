#ifndef UBWC_RGBA8888_720X1548_CFG_H
#define UBWC_RGBA8888_720X1548_CFG_H

#include "../tools/ubwc_enc_cfg.h"
#include "../tools/ubwc_dec_cfg.h"

/*
 * RGBA8888 720x1548 reference configuration.
 *
 * Base address              : 0x80000000
 * Format                    : 0, RGBA8888
 * Tile size                 : 16 x 4 pixels
 * Aligned width             : align(720, 64) = 768 pixels
 * Surface pitch             : align(720 * 4, 256) = 3072 bytes
 * Stored height             : align(1548, 16) = 1552 lines
 * Tile columns              : 48
 * Tile rows                 : 388
 * Metadata pitch            : align(48, 64) = 64 bytes
 * Tile data pitch register  : 3072 / 16 = 192
 *
 * Layout order:
 *   meta RGBA/Y -> compressed tile RGBA/Y
 *
 * RGBA has no UV plane. The UV address registers are written as 0 only to
 * keep the address programming sequence consistent.
 */

#define UBWC_RGBA8888_720X1548_FORMAT           UBWC_ENC_FMT_RGBA8888
#define UBWC_RGBA8888_720X1548_WIDTH            720u
#define UBWC_RGBA8888_720X1548_HEIGHT           1548u
#define UBWC_RGBA8888_720X1548_ALIGNED_WIDTH    768u
#define UBWC_RGBA8888_720X1548_STORED_HEIGHT    1552u
#define UBWC_RGBA8888_720X1548_TILE_W           16u
#define UBWC_RGBA8888_720X1548_TILE_H           4u
#define UBWC_RGBA8888_720X1548_TILE_COLS        48u
#define UBWC_RGBA8888_720X1548_TILE_ROWS        388u
#define UBWC_RGBA8888_720X1548_META_PITCH       64u
#define UBWC_RGBA8888_720X1548_TILE_PITCH       192u

#define UBWC_RGBA8888_720X1548_META_Y_SIZE      0x00007000u
#define UBWC_RGBA8888_720X1548_TILE_Y_SIZE      0x0048c000u
#define UBWC_RGBA8888_720X1548_META_UV_SIZE     0x00000000u
#define UBWC_RGBA8888_720X1548_TILE_UV_SIZE     0x00000000u
#define UBWC_RGBA8888_720X1548_TOTAL_SIZE       0x00493000u

#define UBWC_RGBA8888_720X1548_META_Y_BASE      0x80000000ull
#define UBWC_RGBA8888_720X1548_TILE_Y_BASE      0x80007000ull
#define UBWC_RGBA8888_720X1548_META_UV_BASE     0x00000000ull
#define UBWC_RGBA8888_720X1548_TILE_UV_BASE     0x00000000ull

static const ubwc_enc_reg_write_t ubwc_rgba8888_720x1548_enc_reg_writes[] = {
    {0x000c, 0x00c00001u, "REG_TILE_CFG1"},
    {0x0008, 0x0001100du, "REG_TILE_CFG0"},
    {0x0030, 0x80000000u, "REG_META_BASE_Y_LO"},
    {0x0034, 0x00000000u, "REG_META_BASE_Y_HI"},
    {0x0038, 0x80007000u, "REG_TILE_BASE_Y_LO"},
    {0x003c, 0x00000000u, "REG_TILE_BASE_Y_HI"},
    {0x0040, 0x00000000u, "REG_META_BASE_UV_LO"},
    {0x0044, 0x00000000u, "REG_META_BASE_UV_HI"},
    {0x0048, 0x00000000u, "REG_TILE_BASE_UV_LO"},
    {0x004c, 0x00000000u, "REG_TILE_BASE_UV_HI"},
    {0x0014, 0x00000000u, "REG_ENC_CI_CFG1"},
    {0x0018, 0x00000000u, "REG_ENC_CI_CFG2"},
    {0x001c, 0x00000000u, "REG_ENC_CI_CFG3"},
    {0x0010, 0x00000701u, "REG_ENC_CI_CFG0"},
    {0x0024, 0x060c02d0u, "REG_OTF_CFG1"},
    {0x0028, 0x00040010u, "REG_OTF_CFG2"},
    {0x002c, 0x00000030u, "REG_OTF_CFG3"},
    {0x0050, 0x060c02d0u, "REG_META_ACTIVE_SIZE"},
    {0x0054, 0x00000040u, "REG_META_PITCH"},
    {0x0020, 0x00000000u, "REG_OTF_CFG0"},
    {0x0060, 0x00000021u, "REG_IRQ_CTRL"}
};

static const ubwc_dec_reg_write_t ubwc_rgba8888_720x1548_dec_reg_writes[] = {
    {0x0008, 0x00000706u, "APB_ADDR_TILE_CFG0"},
    {0x000c, 0x000000c0u, "APB_ADDR_TILE_CFG1"},
    {0x0010, 0x00000001u, "APB_ADDR_TILE_CFG2"},
    {0x0014, 0x00000001u, "APB_ADDR_VIVO_CFG"},
    {0x0018, 0x000002d0u, "APB_ADDR_OTF_CFG0"},
    {0x001c, 0x000002d0u, "APB_ADDR_OTF_CFG1"},
    {0x0020, 0x02d00000u, "APB_ADDR_OTF_CFG2"},
    {0x0024, 0x0000060cu, "APB_ADDR_OTF_CFG3"},
    {0x0028, 0x060c0000u, "APB_ADDR_OTF_CFG4"},
    {0x002c, 0x01840030u, "APB_ADDR_META_CFG0"},
    {0x0030, 0x80000000u, "REG_META_BASE_Y_LO"},
    {0x0034, 0x00000000u, "REG_META_BASE_Y_HI"},
    {0x0038, 0x80007000u, "REG_TILE_BASE_Y_LO"},
    {0x003c, 0x00000000u, "REG_TILE_BASE_Y_HI"},
    {0x0040, 0x00000000u, "REG_META_BASE_UV_LO"},
    {0x0044, 0x00000000u, "REG_META_BASE_UV_HI"},
    {0x0048, 0x00000000u, "REG_TILE_BASE_UV_LO"},
    {0x004c, 0x00000000u, "REG_TILE_BASE_UV_HI"},
    {0x0060, 0x00000021u, "APB_ADDR_IRQ_CTRL"}
};

#endif
