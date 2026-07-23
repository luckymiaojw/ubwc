#ifndef UBWC_NV12_720X1548_CFG_H
#define UBWC_NV12_720X1548_CFG_H

#include "../tools/ubwc_enc_cfg.h"
#include "../tools/ubwc_dec_cfg.h"

/*
 * NV12 720x1548 reference configuration.
 *
 * Base address              : 0x80000000
 * Format                    : 2, NV12 / YUV420 8-bit
 * Tile size                 : 32 x 8 pixels
 * Aligned width             : align(720, 128) = 768 bytes
 * Stored UV height          : align(ceil(1548 / 2), 32) = 800 lines
 * Stored Y height           : 2 * 800 = 1600 lines
 * Y/UV tile columns         : 24 / 24
 * Stored Y tile rows        : 200
 * DEC active Y tile rows    : ceil(1548 / 8) = 194
 * Metadata pitch            : align(24, 64) = 64 bytes
 * Tile data pitch register  : 768 / 16 = 48
 * DEC META_CFG0             : read-only, derived from OTF H_ACT/V_ACT/format/rotate_mode
 *
 * Layout order:
 *   meta Y -> compressed tile Y -> meta UV -> compressed tile UV
 */

#define UBWC_NV12_720X1548_FORMAT              UBWC_ENC_FMT_YUV420_8_NV12
#define UBWC_NV12_720X1548_WIDTH               720u
#define UBWC_NV12_720X1548_HEIGHT              1548u
#define UBWC_NV12_720X1548_ALIGNED_WIDTH       768u
#define UBWC_NV12_720X1548_STORED_Y_HEIGHT     1600u
#define UBWC_NV12_720X1548_STORED_UV_HEIGHT    800u
#define UBWC_NV12_720X1548_TILE_W              32u
#define UBWC_NV12_720X1548_TILE_H              8u
#define UBWC_NV12_720X1548_Y_TILE_COLS         24u
#define UBWC_NV12_720X1548_UV_TILE_COLS        24u
#define UBWC_NV12_720X1548_Y_TILE_ROWS         200u
#define UBWC_NV12_720X1548_META_PITCH          64u
#define UBWC_NV12_720X1548_TILE_PITCH          48u

#define UBWC_NV12_720X1548_META_Y_SIZE         0x00004000u
#define UBWC_NV12_720X1548_TILE_Y_SIZE         0x0012c000u
#define UBWC_NV12_720X1548_META_UV_SIZE        0x00002000u
#define UBWC_NV12_720X1548_TILE_UV_SIZE        0x00096000u
#define UBWC_NV12_720X1548_TOTAL_SIZE          0x001c8000u

#define UBWC_NV12_720X1548_META_Y_BASE         0x80000000ull
#define UBWC_NV12_720X1548_TILE_Y_BASE         0x80004000ull
#define UBWC_NV12_720X1548_META_UV_BASE        0x80130000ull
#define UBWC_NV12_720X1548_TILE_UV_BASE        0x80132000ull

static const ubwc_enc_reg_write_t ubwc_nv12_720x1548_enc_reg_writes[] = {
    {0x000c, 0x00300000u, "REG_TILE_CFG1"},
    {0x0008, 0x0001100du, "REG_TILE_CFG0"},
    {0x0030, 0x80000000u, "REG_META_BASE_Y_LO"},
    {0x0034, 0x00000000u, "REG_META_BASE_Y_HI"},
    {0x0038, 0x80004000u, "REG_TILE_BASE_Y_LO"},
    {0x003c, 0x00000000u, "REG_TILE_BASE_Y_HI"},
    {0x0040, 0x80130000u, "REG_META_BASE_UV_LO"},
    {0x0044, 0x00000000u, "REG_META_BASE_UV_HI"},
    {0x0048, 0x80132000u, "REG_TILE_BASE_UV_LO"},
    {0x004c, 0x00000000u, "REG_TILE_BASE_UV_HI"},
    {0x0014, 0x00000000u, "REG_ENC_CI_CFG1"},
    {0x0018, 0x00000000u, "REG_ENC_CI_CFG2"},
    {0x001c, 0x00070000u, "REG_ENC_CI_CFG3"},
    {0x0010, 0x00000701u, "REG_ENC_CI_CFG0"},
    {0x0024, 0x060c02d0u, "REG_OTF_CFG1"},
    {0x0028, 0x00080020u, "REG_OTF_CFG2"},
    {0x002c, 0x00180018u, "REG_OTF_CFG3"},
    {0x0050, 0x060c02d0u, "REG_META_ACTIVE_SIZE"},
    {0x0054, 0x00000040u, "REG_META_PITCH"},
    {0x0020, 0x00000002u, "REG_OTF_CFG0"},
    {0x0060, 0x00000021u, "REG_IRQ_CTRL"}
};

static const ubwc_dec_reg_write_t ubwc_nv12_720x1548_dec_reg_writes[] = {
    {0x0008, 0x00070306u, "APB_ADDR_TILE_CFG0"},
    {0x000c, 0x00000030u, "APB_ADDR_TILE_CFG1"},
    {0x0010, 0x00000001u, "APB_ADDR_TILE_CFG2"},
    {0x0014, 0x00000001u, "APB_ADDR_VIVO_CFG"},
    {0x0018, 0x000202d0u, "APB_ADDR_OTF_CFG0"},
    {0x001c, 0x000002d0u, "APB_ADDR_OTF_CFG1"},
    {0x0020, 0x02d00000u, "APB_ADDR_OTF_CFG2"},
    {0x0024, 0x0000060cu, "APB_ADDR_OTF_CFG3"},
    {0x0028, 0x060c0000u, "APB_ADDR_OTF_CFG4"},
    {0x0030, 0x80000000u, "REG_META_BASE_Y_LO"},
    {0x0034, 0x00000000u, "REG_META_BASE_Y_HI"},
    {0x0038, 0x80004000u, "REG_TILE_BASE_Y_LO"},
    {0x003c, 0x00000000u, "REG_TILE_BASE_Y_HI"},
    {0x0040, 0x80130000u, "REG_META_BASE_UV_LO"},
    {0x0044, 0x00000000u, "REG_META_BASE_UV_HI"},
    {0x0048, 0x80132000u, "REG_TILE_BASE_UV_LO"},
    {0x004c, 0x00000000u, "REG_TILE_BASE_UV_HI"},
    {0x0060, 0x00000021u, "APB_ADDR_IRQ_CTRL"}
};

#endif
