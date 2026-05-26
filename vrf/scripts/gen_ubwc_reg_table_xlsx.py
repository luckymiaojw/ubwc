#!/usr/bin/env python3
"""Generate the UBWC APB register workbook.

The first two sheets intentionally preserve the original register-table content
generated from docs/ubwc_enc_reg_table.csv and docs/ubwc_dec_reg_table.csv.
Additional sheets follow the organization style of rotation_apb_config.xlsx:
Overview, Programming_Guide, and Address_Rules.
"""

from __future__ import annotations

from datetime import datetime
import csv
from pathlib import Path
from xml.sax.saxutils import escape
import zipfile


ROOT = Path(__file__).resolve().parents[2]
DOCS_DIR = ROOT / "docs"
OUTPUT_XLSX = DOCS_DIR / "ubwc_reg_tables.xlsx"
ENC_OUTPUT_XLSX = DOCS_DIR / "ubwc_enc_reg_table.xlsx"
DEC_OUTPUT_XLSX = DOCS_DIR / "ubwc_dec_reg_table.xlsx"
CN_OUTPUT_XLSX = DOCS_DIR / "ubwc_reg_table_cn.xlsx"
CN_OUTPUT_CSV = DOCS_DIR / "ubwc_reg_table_cn.csv"
ENC_CSV = DOCS_DIR / "ubwc_enc_reg_table.csv"
DEC_CSV = DOCS_DIR / "ubwc_dec_reg_table.csv"


def h(value: int) -> str:
    return f"0x{value:03X}"


def h32(value: int) -> str:
    return f"0x{value:08X}"


ENC_FIELDS = [
    ("ENC", h(0x000), "REG_VERSION", "31:0", "version", "RO", h32(0x00010000), "IP version register."),
    ("ENC", h(0x004), "REG_DATE", "31:0", "date", "RO", h32(0x20260406), "RTL date register."),
    ("ENC", h(0x008), "REG_TILE_CFG0", "0", "enc_ubwc_en", "RW", "0", "Encoder UBWC enable."),
    ("ENC", h(0x008), "REG_TILE_CFG0", "1", "lvl1_bank_swizzle_en", "RW", "0", "Level-1 bank swizzle enable."),
    ("ENC", h(0x008), "REG_TILE_CFG0", "2", "lvl2_bank_swizzle_en", "RW", "0", "Level-2 bank swizzle enable."),
    ("ENC", h(0x008), "REG_TILE_CFG0", "3", "lvl3_bank_swizzle_en", "RW", "0", "Level-3 bank swizzle enable."),
    ("ENC", h(0x008), "REG_TILE_CFG0", "12:8", "highest_bank_bit", "RW", "0", "Highest bank bit."),
    ("ENC", h(0x008), "REG_TILE_CFG0", "16", "bank_spread_en", "RW", "0", "Bank spread enable."),
    ("ENC", h(0x00C), "REG_TILE_CFG1", "0", "four_line_format", "RW", "0", "4-line tile format enable. RGBA=1, YUV420=0."),
    ("ENC", h(0x00C), "REG_TILE_CFG1", "1", "is_lossy_rgba_2_1_format", "RW", "0", "RGBA8888 lossy 2:1 layout select."),
    ("ENC", h(0x00C), "REG_TILE_CFG1", "26:16", "tile_pitch", "RW", "0", "Tile pitch in 16-byte units. RTL exports {1'b0, bits[26:16]}."),
    ("ENC", h(0x010), "REG_ENC_CI_CFG0", "0", "enc_ci_input_type", "RW", "0", "CI input type. 1=tiled data, 0=linear data. Register reset is 0; software should write 1 for the normal tiled UBWC path."),
    ("ENC", h(0x010), "REG_ENC_CI_CFG0", "10:8", "enc_ci_alen", "RW", "0", "CI ALEN setting. Register reset is 0; software should write 7 for the normal VIVO_ENC configuration."),
    ("ENC", h(0x014), "REG_ENC_CI_CFG1", "16", "enc_ci_lossy", "RW", "0", "CI lossy enable."),
    ("ENC", h(0x018), "REG_ENC_CI_CFG2", "2:0", "enc_ci_ubwc_cfg_0", "RW", "0", "Reserved UBWC CI configuration; software writes 0."),
    ("ENC", h(0x018), "REG_ENC_CI_CFG2", "5:3", "enc_ci_ubwc_cfg_1", "RW", "0", "Reserved UBWC CI configuration; software writes 0."),
    ("ENC", h(0x018), "REG_ENC_CI_CFG2", "9:6", "enc_ci_ubwc_cfg_2", "RW", "0", "Reserved UBWC CI configuration; software writes 0."),
    ("ENC", h(0x018), "REG_ENC_CI_CFG2", "13:10", "enc_ci_ubwc_cfg_3", "RW", "0", "Reserved UBWC CI configuration; software writes 0."),
    ("ENC", h(0x018), "REG_ENC_CI_CFG2", "17:14", "enc_ci_ubwc_cfg_4", "RW", "0", "Reserved UBWC CI configuration; software writes 0."),
    ("ENC", h(0x018), "REG_ENC_CI_CFG2", "21:18", "enc_ci_ubwc_cfg_5", "RW", "0", "Reserved UBWC CI configuration; software writes 0."),
    ("ENC", h(0x018), "REG_ENC_CI_CFG2", "23:22", "enc_ci_ubwc_cfg_6", "RW", "0", "Reserved UBWC CI configuration; software writes 0."),
    ("ENC", h(0x018), "REG_ENC_CI_CFG2", "25:24", "enc_ci_ubwc_cfg_7", "RW", "0", "Reserved UBWC CI configuration; software writes 0."),
    ("ENC", h(0x018), "REG_ENC_CI_CFG2", "27:26", "enc_ci_ubwc_cfg_8", "RW", "0", "Reserved UBWC CI configuration; software writes 0."),
    ("ENC", h(0x018), "REG_ENC_CI_CFG2", "30:28", "enc_ci_ubwc_cfg_9", "RW", "0", "Reserved UBWC CI configuration; software writes 0."),
    ("ENC", h(0x01C), "REG_ENC_CI_CFG3", "5:0", "enc_ci_ubwc_cfg_10", "RW", "0", "Reserved UBWC CI configuration; software writes 0."),
    ("ENC", h(0x01C), "REG_ENC_CI_CFG3", "13:8", "enc_ci_ubwc_cfg_11", "RW", "0", "Reserved UBWC CI configuration; software writes 0."),
    ("ENC", h(0x020), "REG_OTF_CFG0", "2:0", "otf_cfg_format", "RW", "0", "Input format: 0=RGBA8888, 1=RGBA1010102, 2=YUV420_8/NV12, 3=YUV420_10/P010."),
    ("ENC", h(0x024), "REG_OTF_CFG1", "15:0", "otf_cfg_width", "RW", "0", "Input image width in pixels."),
    ("ENC", h(0x024), "REG_OTF_CFG1", "31:16", "otf_cfg_height", "RW", "0", "Input/stored image height in pixels."),
    ("ENC", h(0x028), "REG_OTF_CFG2", "15:0", "otf_cfg_tile_w", "RW", "0", "Tile width in pixels. RGBA=16, YUV420=32."),
    ("ENC", h(0x028), "REG_OTF_CFG2", "19:16", "otf_cfg_tile_h", "RW", "0", "Tile height in pixels. RGBA=4, NV12=8, P010=4."),
    ("ENC", h(0x02C), "REG_OTF_CFG3", "15:0", "otf_cfg_y_tile_cols", "RW", "0", "Y tile column count. RGBA formats use this field for RGBA tile columns."),
    ("ENC", h(0x02C), "REG_OTF_CFG3", "31:16", "otf_cfg_uv_tile_cols", "RW", "0", "UV tile column count. RGBA formats write 0."),
    ("ENC", h(0x030), "REG_META_BASE_Y_LO", "31:0", "meta_y_base_offset_addr[31:0]", "RW", "0", "Y metadata base address low word. RGBA formats use this slot for RGBA metadata."),
    ("ENC", h(0x034), "REG_META_BASE_Y_HI", "31:0", "meta_y_base_offset_addr[63:32]", "RW", "0", "Y metadata base address high word. RGBA formats use this slot for RGBA metadata."),
    ("ENC", h(0x038), "REG_TILE_BASE_Y_LO", "31:0", "y_base_offset_addr[31:0]", "RW", "0", "Y compressed tile/pixel data base address low word. RGBA formats use this slot for RGBA data."),
    ("ENC", h(0x03C), "REG_TILE_BASE_Y_HI", "31:0", "y_base_offset_addr[63:32]", "RW", "0", "Y compressed tile/pixel data base address high word. RGBA formats use this slot for RGBA data."),
    ("ENC", h(0x040), "REG_META_BASE_UV_LO", "31:0", "meta_uv_base_offset_addr[31:0]", "RW", "0", "UV metadata base address low word. RGBA formats write 0."),
    ("ENC", h(0x044), "REG_META_BASE_UV_HI", "31:0", "meta_uv_base_offset_addr[63:32]", "RW", "0", "UV metadata base address high word. RGBA formats write 0."),
    ("ENC", h(0x048), "REG_TILE_BASE_UV_LO", "31:0", "uv_base_offset_addr[31:0]", "RW", "0", "UV compressed tile/pixel data base address low word. RGBA formats write 0."),
    ("ENC", h(0x04C), "REG_TILE_BASE_UV_HI", "31:0", "uv_base_offset_addr[63:32]", "RW", "0", "UV compressed tile/pixel data base address high word. Writing this register commits the current four base addresses as one frame address set."),
    ("ENC", h(0x050), "REG_META_ACTIVE_SIZE", "15:0", "meta_active_width_px", "RW", "0", "Metadata active width in pixels."),
    ("ENC", h(0x050), "REG_META_ACTIVE_SIZE", "31:16", "meta_active_height_px", "RW", "0", "Metadata active height in pixels."),
    ("ENC", h(0x054), "REG_META_PITCH", "31:0", "meta_data_plane_pitch", "RW", "0", "Metadata plane pitch configuration."),
    ("ENC", h(0x058), "REG_STATUS0", "0", "enc_idle", "RO", "dynamic", "Encoder idle input."),
    ("ENC", h(0x058), "REG_STATUS0", "1", "enc_error", "RO", "dynamic", "Encoder error input."),
    ("ENC", h(0x058), "REG_STATUS0", "2", "otf_to_tile_busy", "RO", "dynamic", "OTF-to-tile stage busy."),
    ("ENC", h(0x058), "REG_STATUS0", "3", "otf_to_tile_overflow", "RO", "dynamic", "OTF-to-tile FIFO overflow."),
    ("ENC", h(0x058), "REG_STATUS0", "4", "otf_err_bline", "RO", "dynamic", "Bad-line error."),
    ("ENC", h(0x058), "REG_STATUS0", "5", "otf_err_bframe", "RO", "dynamic", "Bad-frame error."),
    ("ENC", h(0x058), "REG_STATUS0", "6", "meta_err_0", "RO", "dynamic", "Metadata co-buffer overflow error."),
    ("ENC", h(0x058), "REG_STATUS0", "7", "meta_err_1", "RO", "dynamic", "Metadata tile-order error."),
    ("ENC", h(0x058), "REG_STATUS0", "8", "frame_done", "RO", "dynamic", "Frame done status from wrapper."),
    ("ENC", h(0x058), "REG_STATUS0", "9", "addr_cfg_invalid", "RO", "dynamic", "Sticky current-slot address-not-configured error. The ENC data path selects address slot0 or slot1 from the current frame fcnt[0]. When hardware checks the current slot address validity and the selected address FIFO is empty, active_addr_cfg_valid is 0, this bit is set and held, and the condition contributes to error IRQ. This means the current frame has no usable META/TILE base addresses. Software must submit the per-frame address group for the corresponding slot, confirm that the software buffer queue is aligned with fcnt[0], then clear the sticky status with REG_IRQ_CTRL[1] irq_clear; disabling enc_ubwc_en or hard reset also clears it."),
    ("ENC", h(0x058), "REG_STATUS0", "10", "addr_cfg_valid0", "RO", "dynamic", "Address slot 0 has a configured entry."),
    ("ENC", h(0x058), "REG_STATUS0", "11", "addr_cfg_valid1", "RO", "dynamic", "Address slot 1 has a configured entry."),
    ("ENC", h(0x058), "REG_STATUS0", "12", "addr_cfg_overflow", "RO", "dynamic", "Sticky address-configuration FIFO overflow status. One frame address group contains four 64-bit base addresses: META Y, TILE Y, META UV, and TILE UV. Software commits one address group by writing REG_TILE_BASE_UV_HI. The APB block alternates committed groups into slot0/slot1 address FIFOs; each slot FIFO depth is 4. If the selected slot FIFO is full when the commit write occurs, the current address group is not pushed, this bit is set and held, and the condition contributes to error IRQ. Software should stop submitting new address groups, wait for existing frames to consume FIFO entries, clear the sticky bit with REG_IRQ_CTRL[1] irq_clear, and make sure the software buffer queue is aligned with the hardware address queue; if needed, disable enc_ubwc_en and reconfigure."),
    ("ENC", h(0x058), "REG_STATUS0", "13", "rst_drain_timeout", "RO", "dynamic", "Sticky AXI drain timeout during encoder soft reset. Before asserting the internal soft reset, ENC stops issuing new AXI writes and waits for tile/meta AXI write outstanding transactions to drain. If idle is not reached within 16'hffff i_axi_clk cycles, this bit is set and held until REG_IRQ_CTRL[1] irq_clear or hard reset."),
    ("ENC", h(0x05C), "REG_STATUS1", "7:0", "stage_done", "RO", "dynamic", "Encoder stage done bitmap."),
    ("ENC", h(0x060), "REG_IRQ_CTRL", "0", "irq_enable", "RW", "0", "Interrupt enable. Register reset is 0; software should write 1 when IRQ output is required."),
    ("ENC", h(0x060), "REG_IRQ_CTRL", "1", "irq_clear", "W1P", "0", "Write 1 to generate an interrupt clear pulse; readback is 0."),
    ("ENC", h(0x060), "REG_IRQ_CTRL", "2", "irq_pending", "RO", "dynamic", "Any pending interrupt."),
    ("ENC", h(0x060), "REG_IRQ_CTRL", "3", "irq_correct_pending", "RO", "dynamic", "Correct/frame-done interrupt pending."),
    ("ENC", h(0x060), "REG_IRQ_CTRL", "4", "irq_error_pending", "RO", "dynamic", "Error interrupt pending."),
    ("ENC", h(0x060), "REG_IRQ_CTRL", "5", "start", "W1P", "0", "Write 1 after one full output address group has been configured. Address writes only fill the pending address queues; start is a separate frame token."),
    ("ENC", h(0x060), "REG_IRQ_CTRL", "6", "vsync_reset_en", "RW", "0", "When set, an input OTF VSYNC rising edge requests an encoder soft reset through the AXI-drain reset sequencer and re-arms the frame start token after reset release."),
    ("ENC", h(0x064), "REG_STATUS2", "2:0", "irq_status", "RO", "dynamic", "Bit0 any IRQ, bit1 correct IRQ, bit2 error IRQ."),
]

for idx, name in enumerate(
    [
        "REG_META_COUNT0", "REG_META_COUNT1", "REG_TILEADDR_COUNT0", "REG_TILEADDR_COUNT1",
        "REG_OTF_TILE_COUNT0", "REG_OTF_TILE_COUNT1", "REG_OTF_DE_COUNT0", "REG_OTF_DE_COUNT1",
        "REG_OTF_LINE_COUNT0", "REG_OTF_LINE_COUNT1", "REG_TILE_AXI_W_CNT0", "REG_TILE_AXI_W_CNT1",
        "REG_META_AXI_W_CNT0", "REG_META_AXI_W_CNT1",
    ]
):
    addr = 0x068 + (idx * 4)
    desc = name.replace("REG_", "").lower() + " statistic counter; suffix 0/1 follows fcnt[0] address slot."
    ENC_FIELDS.append(("ENC", h(addr), name, "31:0", name[4:].lower(), "RO", "dynamic", desc))


DEC_FIELDS = [
    ("DEC", h(0x000), "REG_VERSION", "31:0", "version", "RO", h32(0x00010000), "IP version register."),
    ("DEC", h(0x004), "REG_DATE", "31:0", "date", "RO", h32(0x20260403), "RTL date register."),
    ("DEC", h(0x008), "APB_ADDR_TILE_CFG0", "0", "tile_cfg_lvl1_bank_swizzle_en", "RW", "0", "Level-1 bank swizzle enable; stored for readback."),
    ("DEC", h(0x008), "APB_ADDR_TILE_CFG0", "1", "tile_cfg_lvl2_bank_swizzle_en", "RW", "0", "Level-2 bank swizzle enable; latched to AXI domain at frame start."),
    ("DEC", h(0x008), "APB_ADDR_TILE_CFG0", "2", "tile_cfg_lvl3_bank_swizzle_en", "RW", "0", "Level-3 bank swizzle enable; latched to AXI domain at frame start."),
    ("DEC", h(0x008), "APB_ADDR_TILE_CFG0", "8:4", "tile_cfg_highest_bank_bit", "RW", "0", "Highest bank bit."),
    ("DEC", h(0x008), "APB_ADDR_TILE_CFG0", "9", "tile_cfg_bank_spread_en", "RW", "0", "Bank spread enable."),
    ("DEC", h(0x008), "APB_ADDR_TILE_CFG0", "10", "tile_cfg_4line_format", "RW", "0", "4-line tile format; stored for readback."),
    ("DEC", h(0x008), "APB_ADDR_TILE_CFG0", "11", "tile_cfg_is_lossy_rgba_2_1_format", "RW", "0", "RGBA8888 lossy 2:1 layout select."),
    ("DEC", h(0x00C), "APB_ADDR_TILE_CFG1", "11:0", "tile_cfg_pitch", "RW", "0", "Tile pitch in 16-byte units."),
    ("DEC", h(0x010), "APB_ADDR_TILE_CFG2", "0", "tile_cfg_ci_input_type", "RW", "0", "CI input type. 1=tiled data, 0=linear data. Register reset is 0; software should write 1 for the normal tiled UBWC path."),
    ("DEC", h(0x010), "APB_ADDR_TILE_CFG2", "8", "tile_cfg_ci_lossy", "RW", "0", "CI lossy enable."),
    ("DEC", h(0x010), "APB_ADDR_TILE_CFG2", "10:9", "tile_cfg_ci_alpha_mode", "RW", "0", "CI alpha mode."),
    ("DEC", h(0x014), "APB_ADDR_VIVO_CFG", "0", "vivo_ubwc_en", "RW", "0", "VIVO UBWC path enable. Register reset is 0; software should write 1 before starting decode."),
    ("DEC", h(0x014), "APB_ADDR_VIVO_CFG", "1", "vivo_sreset", "RW", "0", "VIVO soft reset."),
    ("DEC", h(0x018), "APB_ADDR_OTF_CFG0", "15:0", "otf_cfg_img_width", "RW", "0", "Valid output image width in pixels."),
    ("DEC", h(0x018), "APB_ADDR_OTF_CFG0", "20:16", "otf_cfg_format", "RW", "0", "Output OTF format; also drives meta_base_format."),
    ("DEC", h(0x01C), "APB_ADDR_OTF_CFG1", "15:0", "otf_cfg_h_total", "RW", "0", "Horizontal total."),
    ("DEC", h(0x01C), "APB_ADDR_OTF_CFG1", "31:16", "otf_cfg_h_sync", "RW", "0", "Horizontal sync width."),
    ("DEC", h(0x020), "APB_ADDR_OTF_CFG2", "15:0", "otf_cfg_h_bp", "RW", "0", "Horizontal back porch."),
    ("DEC", h(0x020), "APB_ADDR_OTF_CFG2", "31:16", "otf_cfg_h_act", "RW", "0", "Horizontal active width."),
    ("DEC", h(0x024), "APB_ADDR_OTF_CFG3", "15:0", "otf_cfg_v_total", "RW", "0", "Vertical total."),
    ("DEC", h(0x024), "APB_ADDR_OTF_CFG3", "31:16", "otf_cfg_v_sync", "RW", "0", "Vertical sync width."),
    ("DEC", h(0x028), "APB_ADDR_OTF_CFG4", "15:0", "otf_cfg_v_bp", "RW", "0", "Vertical back porch."),
    ("DEC", h(0x028), "APB_ADDR_OTF_CFG4", "31:16", "otf_cfg_v_act", "RW", "0", "Vertical active height."),
    ("DEC", h(0x02C), "APB_ADDR_META_CFG0", "15:0", "meta_tile_x_numbers", "RW", "0", "Y/RGBA metadata tile columns; YUV420 UV columns are derived by format."),
    ("DEC", h(0x02C), "APB_ADDR_META_CFG0", "31:16", "meta_tile_y_numbers", "RW", "0", "Y/RGBA metadata tile rows; YUV420 UV rows are derived internally."),
    ("DEC", h(0x030), "REG_META_BASE_Y_LO", "31:0", "meta_base_addr_rgba_y[31:0]", "RW", "0", "RGBA/Y metadata base address low word."),
    ("DEC", h(0x034), "REG_META_BASE_Y_HI", "31:0", "meta_base_addr_rgba_y[63:32]", "RW", "0", "RGBA/Y metadata base address high word."),
    ("DEC", h(0x038), "REG_TILE_BASE_Y_LO", "31:0", "tile_base_addr_rgba_y[31:0]", "RW", "0", "RGBA/Y compressed tile data base address low word."),
    ("DEC", h(0x03C), "REG_TILE_BASE_Y_HI", "31:0", "tile_base_addr_rgba_y[63:32]", "RW", "0", "RGBA/Y compressed tile data base address high word."),
    ("DEC", h(0x040), "REG_META_BASE_UV_LO", "31:0", "meta_base_addr_uv[31:0]", "RW", "0", "UV metadata base address low word."),
    ("DEC", h(0x044), "REG_META_BASE_UV_HI", "31:0", "meta_base_addr_uv[63:32]", "RW", "0", "UV metadata base address high word."),
    ("DEC", h(0x048), "REG_TILE_BASE_UV_LO", "31:0", "tile_base_addr_uv[31:0]", "RW", "0", "UV compressed tile data base address low word. RGBA format does not use this address."),
    ("DEC", h(0x04C), "REG_TILE_BASE_UV_HI", "31:0", "tile_base_addr_uv[63:32]", "RW", "0", "UV compressed tile data base address high word. RGBA format does not use this address."),
    ("DEC", h(0x050), "APB_ADDR_STATUS0", "0", "frame_active", "RO", "dynamic", "Current frame active."),
    ("DEC", h(0x050), "APB_ADDR_STATUS0", "1", "meta_busy", "RO", "dynamic", "Metadata stage busy."),
    ("DEC", h(0x050), "APB_ADDR_STATUS0", "2", "tile_busy", "RO", "dynamic", "Tile address/read stage busy."),
    ("DEC", h(0x050), "APB_ADDR_STATUS0", "3", "vivo_busy", "RO", "dynamic", "VIVO stage busy."),
    ("DEC", h(0x050), "APB_ADDR_STATUS0", "4", "otf_busy", "RO", "dynamic", "Tile-to-OTF stage busy."),
    ("DEC", h(0x050), "APB_ADDR_STATUS0", "5", "all_stage_idle", "RO", "dynamic", "No current busy stage."),
    ("DEC", h(0x050), "APB_ADDR_STATUS0", "6", "frame_idle_done", "RO", "dynamic", "No busy stage and frame_active=0."),
    ("DEC", h(0x054), "APB_ADDR_STATUS1", "4:0", "stage_done", "RO", "dynamic", "Done bitmap: bit0 meta, bit1 tile address, bit2 reserved, bit3 otf, bit4 frame."),
    ("DEC", h(0x054), "APB_ADDR_STATUS1", "8:5", "stage_seen", "RO", "dynamic", "Stage-seen-busy bitmap for meta/tile/vivo/otf."),
    ("DEC", h(0x058), "APB_ADDR_STATUS2", "0", "vivo_idle", "RO", "dynamic", "VIVO idle status."),
    ("DEC", h(0x05C), "APB_ADDR_STATUS3", "0", "vivo_error", "RO", "dynamic", "VIVO error status."),
    ("DEC", h(0x060), "APB_ADDR_IRQ_CTRL", "0", "irq_enable", "RW", "0", "Interrupt enable. Register reset is 0; software should write 1 when IRQ output is required."),
    ("DEC", h(0x060), "APB_ADDR_IRQ_CTRL", "1", "irq_clear", "W1P", "0", "Write 1 to clear latched correct/error interrupt status."),
    ("DEC", h(0x060), "APB_ADDR_IRQ_CTRL", "2", "irq_pending", "RO", "dynamic", "Any pending interrupt."),
    ("DEC", h(0x060), "APB_ADDR_IRQ_CTRL", "3", "irq_error_pending", "RO", "dynamic", "Error interrupt pending."),
    ("DEC", h(0x060), "APB_ADDR_IRQ_CTRL", "4", "irq_correct_pending", "RO", "dynamic", "Correct/frame interrupt pending."),
    ("DEC", h(0x060), "APB_ADDR_IRQ_CTRL", "5", "start", "W1P", "0", "Write 1 after one full input UBWC address group has been configured. Address writes only fill the pending address queues; start is a separate frame token."),
    ("DEC", h(0x064), "APB_ADDR_STATUS4", "2:0", "irq_status", "RO", "dynamic", "Bit0 any IRQ, bit1 error IRQ, bit2 correct IRQ."),
    ("DEC", h(0x068), "APB_ADDR_STAT_META", "31:0", "stat_meta_tile_cnt", "RO", "dynamic", "Metadata valid tile count for the current/last frame."),
    ("DEC", h(0x06C), "APB_ADDR_STAT_TILE", "31:0", "stat_tile_addr_cnt", "RO", "dynamic", "Tile address generator valid tile count."),
    ("DEC", h(0x070), "APB_ADDR_STAT_OTF_TILE", "31:0", "stat_otf_tile_cnt", "RO", "dynamic", "Tile-to-OTF accepted tile count."),
    ("DEC", h(0x074), "APB_ADDR_STAT_OTF_LINE", "31:0", "stat_otf_line_cnt", "RO", "dynamic", "OTF output line count."),
    ("DEC", h(0x078), "APB_ADDR_STAT_OTF_DE", "31:0", "stat_otf_de_cnt", "RO", "dynamic", "OTF output data-enable beat count."),
]


PROGRAMMING = [
    ["阶段", "模块", "配置频率", "步骤", "APB 操作", "说明"],
    ["上电检查", "ENC/DEC", "上电后一次", "1", "READ 0x000", "读取 VERSION，当前期望值为 0x00010000。"],
    ["上电检查", "ENC/DEC", "上电后一次", "2", "READ 0x004", "读取 DATE。当前 ENC 为 0x20260406，DEC 为 0x20260403。"],
    ["中断初始化", "ENC/DEC", "图像格式发生变化时配置", "3", "WRITE IRQ_CTRL[0]=1", "使能中断。ENC IRQ_CTRL 地址为 0x060，DEC IRQ_CTRL 地址为 0x060。寄存器复位值为 0，软件需要写 1 才使能 IRQ。"],
    ["公共计算", "ENC/DEC", "图像格式发生变化时配置", "4", "软件计算 layout", "根据 format、width、height 计算 tile_w、tile_h、tile_cols、tile_rows、tile_pitch、meta_pitch 和各 plane base address。若只切换 frame buffer 地址，本步骤不需要重复。"],
    ["公共计算", "ENC/DEC", "图像格式发生变化时配置", "5", "选择 format code", "0=RGBA8888，1=RGBA1010102，2=YUV420_8/NV12，3=YUV420_10/P010。"],
    ["ENC 静态配置", "ENC", "图像格式发生变化时配置", "6", "WRITE 0x00C REG_TILE_CFG1", "配置 four_line_format、lossy_rgba_2_1_format、tile_pitch。RGBA 写 four_line_format=1，YUV420 写 four_line_format=0。"],
    ["ENC 静态配置", "ENC", "图像格式发生变化时配置", "7", "WRITE 0x008 REG_TILE_CFG0", "配置 ubwc_en、bank swizzle、bank spread。相同格式和 layout 的连续帧不需要重复写。"],
    ["ENC CI 配置", "ENC", "图像格式发生变化时配置", "8", "WRITE 0x014/0x018/0x01C", "先写 CI_CFG1/2/3。保留 cfg bit 建议写 0。"],
    ["ENC CI 配置", "ENC", "图像格式发生变化时配置", "9", "WRITE 0x010 REG_ENC_CI_CFG0", "最后写 CI_CFG0；寄存器复位值为 0，普通 tiled UBWC 路径软件应配置 enc_ci_input_type=1、enc_ci_alen=7。"],
    ["ENC 几何配置", "ENC", "图像格式发生变化时配置", "10", "WRITE 0x024 REG_OTF_CFG1", "配置 width[15:0] 和 height[31:16]。连续帧尺寸不变时不需要重写。"],
    ["ENC 几何配置", "ENC", "图像格式发生变化时配置", "11", "WRITE 0x028 REG_OTF_CFG2", "配置 tile_w 和 tile_h。RGBA=16x4，YUV420_8=32x8，YUV420_10=32x4。"],
    ["ENC 几何配置", "ENC", "图像格式发生变化时配置", "12", "WRITE 0x02C REG_OTF_CFG3", "配置 y_tile_cols 和 uv_tile_cols。RGBA: y=ceil(width/16), uv=0；YUV: y=ceil(width/32), uv=ceil(width/32)。"],
    ["ENC 几何配置", "ENC", "图像格式发生变化时配置", "13", "WRITE 0x050 REG_META_ACTIVE_SIZE", "配置 metadata active width/height。active 尺寸不变时不需要重写。"],
    ["ENC 几何配置", "ENC", "图像格式发生变化时配置", "14", "WRITE 0x054 REG_META_PITCH", "配置 metadata pitch。宽度和格式不变时不需要重写。"],
    ["ENC 几何配置", "ENC", "图像格式发生变化时配置", "15", "WRITE 0x020 REG_OTF_CFG0", "配置 otf_cfg_format。建议作为 OTF/metadata geometry 组的最后一笔写。"],
    ["ENC 每帧地址", "ENC", "每帧都要配置", "16", "WRITE 0x030/0x034", "配置下一帧地址组的 Y metadata base 低/高 32 bit；RGBA 使用该槽位存 RGBA metadata。"],
    ["ENC 每帧地址", "ENC", "每帧都要配置", "17", "WRITE 0x038/0x03C", "配置下一帧地址组的 Y tile data base 低/高 32 bit；RGBA 使用该槽位存 RGBA tile data。"],
    ["ENC 每帧地址", "ENC", "每帧都要配置", "18", "WRITE 0x040/0x044", "配置 UV metadata base 低/高 32 bit，RGBA 写 0。"],
    ["ENC 每帧地址", "ENC", "每帧都要配置", "19", "WRITE 0x048", "配置 UV tile data base 低 32 bit，RGBA 写 0。"],
    ["ENC 每帧地址", "ENC", "每帧都要配置", "20", "WRITE 0x04C REG_TILE_BASE_UV_HI", "配置 UV tile data base 高 32 bit，RGBA 写 0。本写入会提交当前四个 64 bit base address 为一组帧地址，必须最后写。"],
    ["ENC 启动", "ENC", "每帧", "21", "WRITE 0x060 bit[5]=1", "写 START token。地址写入只填充地址队列，不再作为 start 标志；写 START 后再送入对应 OTF vsync/hsync/de/data。"],
    ["ENC 监控", "ENC", "运行中", "22", "READ 0x058/0x05C/0x060/0x064", "读取 STATUS0、STATUS1、IRQ_CTRL、STATUS2。addr_cfg_invalid 表示当前 fcnt[0] 对应 slot 没有可用地址配置，是 sticky 错误状态；软件补齐地址并确认队列对齐后，通过 REG_IRQ_CTRL[1] irq_clear 清除。IRQ bit 区分 correct/error pending。"],
    ["ENC 清中断", "ENC", "软件处理中断后", "23", "WRITE 0x060 bit[1]=1", "清除 ENC 中断 pending。统计计数仍可用于调试。"],
    ["DEC 静态配置", "DEC", "图像格式发生变化时配置", "24", "WRITE 0x008 APB_ADDR_TILE_CFG0", "配置 bank swizzle、bank spread、4-line format、lossy_rgba_2_1_format。这些配置在 frame start 时锁存到 AXI 域。"],
    ["DEC 静态配置", "DEC", "图像格式发生变化时配置", "25", "WRITE 0x00C APB_ADDR_TILE_CFG1", "配置 tile_cfg_pitch，单位 16 byte。"],
    ["DEC CI 配置", "DEC", "图像格式发生变化时配置", "26", "WRITE 0x010 APB_ADDR_TILE_CFG2", "配置 CI input type、lossy、alpha mode。寄存器复位值为 0，普通 tiled UBWC 路径软件应配置 ci_input_type=1。"],
    ["DEC VIVO 配置", "DEC", "图像格式发生变化时配置", "27", "WRITE 0x014 APB_ADDR_VIVO_CFG", "配置 vivo_ubwc_en 和 vivo_sreset。寄存器复位值为 0，启动 decode 前软件应配置 vivo_ubwc_en=1。"],
    ["DEC 几何配置", "DEC", "图像格式发生变化时配置", "28", "WRITE 0x018 APB_ADDR_OTF_CFG0", "配置输出 img_width 和 format，同时更新 meta_base_format。"],
    ["DEC OTF timing", "DEC", "图像格式发生变化时配置", "29", "WRITE 0x01C/0x020", "配置 h_total、h_sync、h_bp、h_act。输出 timing 不变时连续帧不需要重写。"],
    ["DEC OTF timing", "DEC", "图像格式发生变化时配置", "30", "WRITE 0x024/0x028", "配置 v_total、v_sync、v_bp、v_act。输出 timing 不变时连续帧不需要重写。"],
    ["DEC 几何配置", "DEC", "图像格式发生变化时配置", "31", "WRITE 0x02C APB_ADDR_META_CFG0", "配置 Y/RGBA 基准 metadata tile_x_numbers 和 tile_y_numbers；YUV420 的 UV metadata tile 数由格式内部推导。"],
    ["DEC 每帧地址", "DEC", "每帧都要配置", "32", "WRITE 0x030 then 0x034", "配置 RGBA/Y metadata base 低/高 32 bit。"],
    ["DEC 每帧地址", "DEC", "每帧都要配置", "33", "WRITE 0x038 then 0x03C", "配置 RGBA/Y compressed tile base 低/高 32 bit。"],
    ["DEC 每帧地址", "DEC", "每帧都要配置", "34", "WRITE 0x040 then 0x044", "配置 UV metadata base 低/高 32 bit。"],
    ["DEC 每帧地址", "DEC", "每帧都要配置", "35", "WRITE 0x048 then 0x04C", "配置 UV compressed tile base 低/高 32 bit，RGBA 图像不关心。"],
    ["DEC 启动", "DEC", "每帧", "36", "WRITE 0x060 bit[5]=1", "写 START token。完整地址组和 START token 都有效，且 metadata stage 可接受新帧时，硬件锁存本帧地址并启动 decode。"],
    ["DEC 监控", "DEC", "运行中", "37", "READ 0x050/0x054/0x060/0x064", "读取 STATUS0、STATUS1、IRQ_CTRL、STATUS4。STATUS1[4] 是 frame_done。STATUS4/IRQ_CTRL 区分 correct/error pending。"],
    ["DEC 统计", "DEC", "运行中调试", "38", "READ 0x068/0x06C/0x070/0x074/0x078", "读取 metadata tile count、tile address count、OTF tile count、OTF line count、OTF de beat count。"],
    ["DEC 清中断", "DEC", "软件处理中断后", "39", "WRITE 0x060 bit[1]=1", "清除 DEC 中断 pending。VIVO idle/error 状态和统计计数仍可读。"],
    [],
    ["格式", "编码", "tile_w", "tile_h", "bpp", "配置复用说明"],
    ["RGBA8888", "0", "16", "4", "4", "格式和尺寸不变时，tile/OTF/meta geometry 可复用；每帧只更新 base address。"],
    ["RGBA1010102", "1", "16", "4", "4", "几何规则同 RGBA8888；只换 buffer 地址时不需要重配 geometry。"],
    ["YUV420_8/NV12", "2", "32", "8", "1(Y),2(UV pair)", "Y/UV 有独立 metadata/tile base；新 buffer 必须写每帧地址。"],
    ["YUV420_10/P010", "3", "32", "4", "2(Y),4(UV pair)", "tile count 规则按 P010 tile_h=4 计算，pitch 使用 16 bit component 存储计算。"],
]


ADDRESS_RULES = [
    ["Item", "Rule"],
    ["Address map", "APB registers are 32-bit word aligned. ENC defined range is 0x000..0x09C. DEC defined range is 0x000..0x078."],
    ["ENC address slots", "Two alternating address slots hold frame address sets for fcnt[0]=0/1. Each entry contains Y metadata base, Y tile base, UV metadata base, and UV tile base."],
    ["ENC address commit", "Write REG_TILE_BASE_UV_HI @0x04C last. That write snapshots the current META_BASE_Y, TILE_BASE_Y, META_BASE_UV and the just-written TILE_BASE_UV value. A separate IRQ_CTRL[5] start write is still required for the frame."],
    ["DEC address set", "Software writes metadata/tile bases for RGBA/Y and UV. A complete address set plus a separate IRQ_CTRL[5] start write is required for each frame."],
    ["DEC start token", "A decode frame starts when a complete DEC address set and a START token are both valid, metadata is not busy, and the metadata launch slot is free."],
    ["Contiguous UBWC layout", "For YUV: Y metadata, Y tile data, UV metadata, UV tile data. For RGBA: RGBA metadata and RGBA tile data are enough; unused Y/UV partner bases may be written 0 as required by the wrapper path."],
    ["Metadata pitch", "meta_pitch=align_up(ceil(plane_width/tile_w),64). Metadata size aligns meta_pitch*align_up(tile_rows,16) to 4KB."],
    ["Tile pitch", "tile_pitch register is in 16-byte units. pixel_pitch=align_up(width*bpp,tile_w*4*bpp); tile_pitch=pixel_pitch/16."],
    ["IRQ timing", "Correct IRQ/frame_done is produced after the final valid frame output/data completion event. Error IRQ is produced when an error condition is latched."],
]


CN_HEADER = ["模块", "寄存器地址", "寄存器名称", "访问类型", "复位值", "位域", "字段名", "说明", "备注"]


ACCESS_CN = {
    "RO": "只读",
    "RW": "读写",
    "W1P": "写 1 脉冲",
}


def access_cn(access: str) -> str:
    return "/".join(ACCESS_CN.get(part, part) for part in access.split("/"))


def cfg_note(block: str, addr: str, field: str, access: str) -> str:
    addr_i = int(addr, 16)
    if field in {"version", "date"}:
        return "上电后读取一次，用于确认软件和 RTL 版本匹配。"
    if field == "start":
        return "每帧地址组写完整后写 1；读回为 0。地址写入不再单独启动帧。"
    if field == "vsync_reset_en":
        return "按系统策略配置；置 1 后 ENC 输入 VSYNC 上升沿会触发软复位并重新 arm frame start。"
    if "irq_enable" in field:
        return "上电后或中断策略变化时配置。"
    if "irq_clear" in field:
        return "软件处理中断后写 1；读回为 0。"
    if "irq_" in field or field.startswith("stat_") or field.endswith("_cnt") or "status" in field:
        return "运行中或中断后读取，用于调试和状态确认。"
    if block == "ENC" and 0x030 <= addr_i <= 0x04C:
        if addr == h(0x04C):
            return "每帧配置；该高 32 bit 写入必须最后写，会提交当前四个 base 地址为一组帧地址。"
        return "每帧配置，低/高 32 bit 共同组成 64 bit base 地址。"
    if block == "DEC" and addr_i in {0x030, 0x034, 0x038, 0x03C, 0x040, 0x044, 0x048, 0x04C}:
        if addr_i in {0x034, 0x03C, 0x044, 0x04C}:
            return "每帧配置；低/高 32 bit 写完整后形成该 base 地址。"
        return "每帧配置，低/高 32 bit 共同组成 64 bit base 地址。"
    if "pending" in field or "busy" in field or "idle" in field or "error" in field or "done" in field:
        return "运行中读取。"
    if access == "RO":
        return "只读状态或统计信息。"
    return "图像格式、尺寸、layout 或 timing 变化时配置；连续帧只换 buffer 地址时通常不需要重写。"


def cfg_note_en(block: str, addr: str, field: str, access: str) -> str:
    addr_i = int(addr, 16)
    if field in {"version", "date"}:
        return "Read once after reset to confirm software/RTL compatibility."
    if field == "start":
        return "Write 1 after the per-frame address group is complete; readback is 0. Address writes do not start a frame by themselves."
    if field == "vsync_reset_en":
        return "Configure according to the system policy. When set, ENC input VSYNC rising edges trigger a soft reset and re-arm frame start."
    if "irq_enable" in field:
        return "Configure after reset or when the interrupt policy changes."
    if "irq_clear" in field:
        return "Write 1 after software handles the interrupt; readback is 0."
    if "irq_" in field or field.startswith("stat_") or field.endswith("_cnt") or "status" in field:
        return "Read during runtime or after interrupt handling for status/debug."
    if block == "ENC" and 0x030 <= addr_i <= 0x04C:
        if addr == h(0x04C):
            return "Per-frame configuration. This high-word write must be last and commits the four base addresses as one frame address group."
        return "Per-frame configuration. Low/high words form one 64-bit base address."
    if block == "DEC" and addr_i in {0x030, 0x034, 0x038, 0x03C, 0x040, 0x044, 0x048, 0x04C}:
        if addr_i in {0x034, 0x03C, 0x044, 0x04C}:
            return "Per-frame configuration. Low/high words complete this base address."
        return "Per-frame configuration. Low/high words form one 64-bit base address."
    if "pending" in field or "busy" in field or "idle" in field or "error" in field or "done" in field:
        return "Read during runtime."
    if access == "RO":
        return "Read-only status or statistic information."
    return "Configure when image format, size, layout, or timing changes. Reuse when only frame buffer addresses change."


def desc_cn(block: str, reg: str, field: str, desc: str) -> str:
    lower = field.lower()
    if field == "version":
        return "IP 版本号。"
    if field == "date":
        return "RTL 日期。"
    if "ubwc_en" in lower:
        return "UBWC 数据路径使能。"
    if "lvl1_bank_swizzle" in lower:
        return "一级 bank swizzle 使能。"
    if "lvl2_bank_swizzle" in lower:
        return "二级 bank swizzle 使能。"
    if "lvl3_bank_swizzle" in lower:
        return "三级 bank swizzle 使能。"
    if "highest_bank_bit" in lower:
        return "最高 bank bit 配置。"
    if "bank_spread" in lower:
        return "bank spread 使能。"
    if "4line" in lower or "four_line" in lower:
        return "4-line tile format 选择；RGBA 通常为 1，YUV420 通常为 0。"
    if "lossy_rgba_2_1" in lower:
        return "RGBA8888 2:1 有损 layout 选择。"
    if lower.endswith("tile_pitch") or lower == "tile_cfg_pitch":
        return "tile surface pitch 配置，单位为 16 byte。"
    if "ci_input_type" in lower:
        return "CI input type 配置；1=tiled data，0=linear data；寄存器复位值为 0，普通 tiled UBWC 路径软件应配置为 1。"
    if "ci_alen" in lower:
        return "CI alen 配置；寄存器复位值为 0，普通 VIVO_ENC 配置软件应写 7。"
    if "ci_lossy" in lower:
        return "CI 有损模式使能。"
    if "ci_alpha" in lower:
        return "CI alpha mode 配置。"
    if "ubwc_cfg" in lower:
        return "保留 UBWC CI 配置位，软件建议写 0。"
    if "otf_cfg_format" in lower or lower == "otf_cfg_format":
        return "OTF 图像格式编码：0=RGBA8888，1=RGBA1010102，2=YUV420_8/NV12，3=YUV420_10/P010。"
    if "base_format" in lower:
        return "metadata/base 地址生成格式编码。"
    if "width" in lower and "active" not in lower:
        return "图像宽度，单位像素。"
    if "height" in lower and "active" not in lower:
        return "图像高度，单位像素。"
    if "tile_w" in lower:
        return "tile 宽度，单位像素；RGBA=16，YUV420=32。"
    if "tile_h" in lower:
        return "tile 高度，单位像素；RGBA=4，YUV420_8=8，YUV420_10=4。"
    if "y_tile_cols" in lower:
        return "Y tile 列数；RGBA 格式使用该字段表示 RGBA tile 列数。"
    if "uv_tile_cols" in lower:
        return "UV tile 列数；RGBA 格式通常写 0。"
    if "tile_x_numbers" in lower:
        return "Y/RGBA metadata 水平方向 tile 数量；YUV420 的 UV metadata tile 数由格式内部推导。"
    if "tile_y_numbers" in lower:
        return "Y/RGBA metadata 垂直方向 tile 数量；YUV420 的 UV metadata 行数由格式内部推导。"
    if "active_width" in lower:
        return "metadata active 区域宽度，单位像素。"
    if "active_height" in lower:
        return "metadata active 区域高度，单位像素。"
    if "meta_data_plane_pitch" in lower:
        return "metadata plane pitch 配置。"
    if "meta_y_base_offset_addr" in lower:
        return "ENC Y/RGBA metadata base 地址。"
    if "meta_uv_base_offset_addr" in lower:
        return "ENC UV metadata base 地址。"
    if "y_base_offset_addr" in lower:
        return "ENC Y tile/pixel 数据 base 地址。"
    if "uv_base_offset_addr" in lower:
        return "ENC UV tile/pixel 数据 base 地址，RGBA 图像不关心。"
    if "tile_base_addr_rgba_y" in lower:
        return "DEC RGBA 或 Y tile 数据 base 地址。"
    if "tile_base_addr_uv" in lower:
        return "DEC UV tile 数据 base 地址，RGBA 图像不关心。"
    if "meta_base_addr_rgba_y" in lower:
        return "DEC RGBA 或 Y metadata base 地址。"
    if "meta_base_addr_uv" in lower:
        return "DEC UV metadata base 地址。"
    if "vivo_ubwc_en" in lower:
        return "VIVO UBWC path 使能；寄存器复位值为 0，启动 decode 前软件应配置为 1。"
    if "vivo_sreset" in lower:
        return "VIVO 子模块软复位。"
    if "h_total" in lower:
        return "OTF 水平 total，单位像素。"
    if "h_sync" in lower:
        return "OTF 水平 sync 宽度，单位像素。"
    if "h_bp" in lower:
        return "OTF 水平 back porch，单位像素。"
    if "h_act" in lower:
        return "OTF 水平 active 宽度，单位像素。"
    if "v_total" in lower:
        return "OTF 垂直 total，单位行。"
    if "v_sync" in lower:
        return "OTF 垂直 sync 宽度，单位行。"
    if "v_bp" in lower:
        return "OTF 垂直 back porch，单位行。"
    if "v_act" in lower:
        return "OTF 垂直 active 高度，单位行。"
    if "frame_active" in lower:
        return "DEC 当前是否有 frame active。"
    if lower == "vivo_idle":
        return "VIVO idle 状态。"
    if lower == "vivo_error":
        return "VIVO error 状态。"
    if lower == "meta_err_0":
        return "metadata co-buffer overflow 错误状态。"
    if lower == "meta_err_1":
        return "metadata tile order 错误状态。"
    if "addr_cfg_overflow" in lower:
        return "地址配置 FIFO overflow sticky 状态；ENC 每帧地址由 META Y、TILE Y、META UV、TILE UV 四个 64-bit 基地址组成，软件写 REG_TILE_BASE_UV_HI 作为一次地址组 commit。APB block 会按 slot0/slot1 轮流把地址组写入对应地址 FIFO，每个 slot FIFO 深度为 4。当 commit 时选中的 slot FIFO 已满，当前地址组不会 push 进 FIFO，该 bit 置 1 并保持，同时参与 error IRQ。软件应停止继续提交地址，等待已有帧消耗地址 FIFO；若已发生 overflow，应写 REG_IRQ_CTRL[1] irq_clear 清 sticky 状态，并确认软件 buffer 队列与硬件地址队列重新对齐，必要时关闭 enc_ubwc_en 后重新配置。"
    if "rst_drain_timeout" in lower:
        return "软复位等待 AXI drain 超时 sticky 状态；ENC 进入 soft reset 前会停止发起新的 AXI 写事务，并等待 tile/meta AXI 写通路 outstanding 清空。如果等待超过 16'hffff 个 i_axi_clk 周期仍未进入 idle，则该 bit 置 1 并保持；软件写 REG_IRQ_CTRL[1] irq_clear 或硬复位后清零。"
    if "busy" in lower:
        return "对应处理 stage 的 busy 状态。"
    if "idle" in lower:
        return "对应模块或整体流水线 idle 状态。"
    if "overflow" in lower:
        return "FIFO overflow 错误状态。"
    if "bline" in lower:
        return "OTF 输入 bad-line 错误状态。"
    if "bframe" in lower:
        return "OTF 输入 bad-frame 错误状态。"
    if "error" in lower or "err_" in lower:
        return "错误状态位。"
    if "frame_done" in lower:
        return "当前/上一帧处理完成状态。"
    if "addr_cfg_invalid" in lower:
        return "当前 slot 地址未配置错误 sticky 状态；ENC 数据链路按当前帧 fcnt[0] 选择 slot0 或 slot1 的地址配置。当硬件检查当前 slot 地址有效性时，如果被选中的地址 FIFO 为空，则 active_addr_cfg_valid 为 0，该 bit 置 1 并保持，同时参与 error IRQ。该状态表示当前帧没有可用的 META/TILE 基地址，软件必须先补齐对应 slot 的每帧地址组，确认 buffer 队列与 fcnt[0] 对齐后，再写 REG_IRQ_CTRL[1] irq_clear 清 sticky 状态；关闭 enc_ubwc_en 或硬复位也会清零。"
    if "addr_cfg_valid0" in lower:
        return "ENC 地址 slot0 中存在已配置地址。"
    if "addr_cfg_valid1" in lower:
        return "ENC 地址 slot1 中存在已配置地址。"
    if "stage_done" in lower:
        return "stage done 位图。"
    if "stage_seen" in lower:
        return "stage 曾经 busy 的记录位图。"
    if "irq_enable" in lower:
        return "中断使能；寄存器复位值为 0，需要中断输出时软件应配置为 1。"
    if "irq_clear" in lower:
        return "中断清除写 1 脉冲。"
    if lower == "start":
        return "帧 START 写 1 脉冲；地址组写完后再写该 bit 启动本帧。"
    if lower == "vsync_reset_en":
        return "ENC 输入 VSYNC 上升沿触发整条 ENC 链路软复位；复位通过 AXI drain reset sequencer 执行。"
    if "irq_pending" in lower:
        return "任意中断 pending 状态。"
    if "irq_correct_pending" in lower:
        return "正确完成中断 pending 状态。"
    if "irq_error_pending" in lower:
        return "错误中断 pending 状态。"
    if "irq_status" in lower:
        return "中断状态位图。"
    if lower.startswith("stat_"):
        if "meta" in lower:
            return "DEC metadata 有效 tile 计数。"
        if "tile_addr" in lower or lower == "stat_tile_addr_cnt":
            return "DEC tile 地址生成有效 tile 计数。"
        if "otf_tile" in lower:
            return "DEC tile-to-OTF 接收 tile 计数。"
        if "otf_line" in lower:
            return "DEC OTF 输出行计数。"
        if "otf_de" in lower:
            return "DEC OTF 输出 de && ready 有效 beat 计数。"
        return "DEC 统计计数器。"
    if lower.endswith("_cnt") or "_cnt" in lower or "count" in lower:
        return "ENC 统计计数器；后缀 0/1 对应 fcnt[0] 地址 slot。"
    return desc


def reset_cn(reset: str) -> str:
    if reset == "dynamic":
        return h32(0)
    if reset == "0":
        return h32(0)
    if reset == "1":
        return h32(1)
    return reset


def reset_doc(field: str, reset: str) -> str:
    if field in {"version", "date"}:
        return reset_cn(reset)
    return h32(0)


def field_doc_name(field: str) -> str:
    text = field.replace("[", "_").replace(":", "_").replace("]", "_")
    while "__" in text:
        text = text.replace("__", "_")
    return text.strip("_")


ENG_HEADER = ["Module", "Register Address", "Register Name", "Access", "Reset Value", "Bit Field", "Field Name", "Description", "Notes"]


def addr4(addr: str) -> str:
    return f"0x{int(addr, 16):04x}"


def english_table_rows(block: str, fields: list[tuple[str, str, str, str, str, str, str, str]]) -> list[list[str]]:
    module = "ubwc_enc_apb_reg_blk" if block == "ENC" else "ubwc_dec_apb_reg_blk"
    rows = [ENG_HEADER]
    for _, addr, reg, bits, field, access, reset, desc in fields:
        rows.append([
            module,
            addr4(addr),
            reg,
            access,
            reset_doc(field, reset),
            bits,
            field_doc_name(field),
            desc,
            cfg_note_en(block, addr, field, access),
        ])
    return rows


def write_rows_csv(path: Path, rows: list[list[str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerows(rows)
    print(f"wrote {path}")


def cn_table_rows(block: str, fields: list[tuple[str, str, str, str, str, str, str, str]]) -> list[list[str]]:
    module = "ubwc_enc_apb_reg_blk" if block == "ENC" else "ubwc_dec_apb_reg_blk"
    rows = [CN_HEADER]
    for _, addr, reg, bits, field, access, reset, desc in fields:
        rows.append([
            module,
            addr4(addr),
            reg,
            access_cn(access),
            reset_doc(field, reset),
            bits,
            field_doc_name(field),
            desc_cn(block, reg, field, desc),
            cfg_note(block, addr, field, access),
        ])
    return rows


def write_cn_csv(path: Path) -> None:
    rows = cn_table_rows("ENC", ENC_FIELDS) + [[""], ["模块", "寄存器地址", "寄存器名称", "访问类型", "复位值", "位域", "字段名", "说明", "备注"]] + cn_table_rows("DEC", DEC_FIELDS)[1:]
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerows(rows)
    print(f"wrote {path}")


def load_csv_rows(path: Path) -> list[list[str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return [row for row in csv.reader(f)]


def overview_rows() -> list[list[str]]:
    generated = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    enc_addrs = ",".join(h(v) for v in range(0, 0x0A0, 4))
    dec_addrs = ",".join(h(v) for v in range(0, 0x07C, 4))
    return [
        ["UBWC ENC/DEC APB Configuration Workbook"],
        ["Generated", generated],
        ["RTL sources", "src/enc/ubwc_enc_apb_reg_blk.v; src/dec/ubwc_dec_apb_reg_blk.v"],
        ["Style reference", "rotation_apb_config.xlsx"],
        ["ENC APB valid addresses", enc_addrs],
        ["DEC APB valid addresses", dec_addrs],
        ["APB alignment", "32-bit aligned accesses only; DEC may stall PREADY when the per-frame address path cannot accept a new write."],
        [],
        ["Format", "Value"],
        ["RGBA8888", "0"],
        ["RGBA1010102", "1"],
        ["YUV420_8 / NV12", "2"],
        ["YUV420_10 / P010", "3"],
    ]


def col_letter(index: int) -> str:
    result = []
    while index:
        index, rem = divmod(index - 1, 26)
        result.append(chr(ord("A") + rem))
    return "".join(reversed(result))


def make_sheet_xml(rows: list[list[str]], col_widths: list[int], title_rows: set[int] | None = None) -> str:
    title_rows = title_rows or {1}
    if not rows:
        rows = [["empty"]]
    max_cols = max(len(row) for row in rows)
    last_ref = f"{col_letter(max_cols)}{len(rows)}"
    parts = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
        f'<dimension ref="A1:{last_ref}"/>',
        '<sheetViews><sheetView workbookViewId="0">'
        '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
        '</sheetView></sheetViews>',
        "<cols>",
    ]
    for idx, width in enumerate(col_widths, start=1):
        parts.append(f'<col min="{idx}" max="{idx}" width="{width}" customWidth="1"/>')
    if len(col_widths) < max_cols:
        parts.append(f'<col min="{len(col_widths)+1}" max="{max_cols}" width="20" customWidth="1"/>')
    parts.extend(["</cols>", '<sheetFormatPr defaultRowHeight="15"/>', "<sheetData>"])
    for r_idx, row in enumerate(rows, start=1):
        parts.append(f'<row r="{r_idx}">')
        for c_idx, value in enumerate(row, start=1):
            cell_ref = f"{col_letter(c_idx)}{r_idx}"
            style = ' s="1"' if r_idx in title_rows else (' s="2"' if str(value).startswith("0x") else "")
            text = "" if value is None else str(value)
            preserve = ' xml:space="preserve"' if text.startswith(" ") or text.endswith(" ") or "\n" in text else ""
            parts.append(
                f'<c r="{cell_ref}"{style} t="inlineStr"><is><t{preserve}>{escape(text)}</t></is></c>'
            )
        parts.append("</row>")
    parts.extend([
        "</sheetData>",
        f'<autoFilter ref="A1:{last_ref}"/>',
        '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>',
        "</worksheet>",
    ])
    return "".join(parts)


def make_styles() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="3"><font><sz val="11"/><name val="Calibri"/></font>'
        '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
        '<font><name val="Consolas"/><sz val="10"/></font></fonts>'
        '<fills count="3"><fill><patternFill patternType="none"/></fill>'
        '<fill><patternFill patternType="gray125"/></fill>'
        '<fill><patternFill patternType="solid"><fgColor rgb="FF1F4E78"/></patternFill></fill></fills>'
        '<borders count="2"><border/><border><left style="thin"/><right style="thin"/><top style="thin"/><bottom style="thin"/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>'
        '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" applyFill="1" applyFont="1" applyBorder="1"/>'
        '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" applyFont="1"/></cellXfs>'
        '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        '</styleSheet>'
    )


def make_content_types(sheet_count: int) -> str:
    sheet_overrides = "".join(
        f'<Override PartName="/xl/worksheets/sheet{i}.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        for i in range(1, sheet_count + 1)
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        + sheet_overrides +
        '</Types>'
    )


def make_rels() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>'
    )


def make_workbook(sheet_names: list[str]) -> str:
    sheets = "".join(
        f'<sheet name="{escape(name)}" sheetId="{idx}" r:id="rId{idx}"/>'
        for idx, name in enumerate(sheet_names, start=1)
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        f'<sheets>{sheets}</sheets></workbook>'
    )


def make_workbook_rels(sheet_count: int) -> str:
    rels = "".join(
        f'<Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{i}.xml"/>'
        for i in range(1, sheet_count + 1)
    )
    rels += f'<Relationship Id="rId{sheet_count + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        + rels + '</Relationships>'
    )


def make_core_props() -> str:
    now = datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>UBWC ENC/DEC APB register tables</dc:title><dc:creator>Codex</dc:creator>'
        f'<dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>'
        f'<dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>'
        '</cp:coreProperties>'
    )


def write_workbook(path: Path, sheets: list[tuple[str, list[list[str]], list[int], set[int]]]) -> None:
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", make_content_types(len(sheets)))
        zf.writestr("_rels/.rels", make_rels())
        zf.writestr("xl/workbook.xml", make_workbook([name for name, *_ in sheets]))
        zf.writestr("xl/_rels/workbook.xml.rels", make_workbook_rels(len(sheets)))
        zf.writestr("xl/styles.xml", make_styles())
        zf.writestr("docProps/core.xml", make_core_props())
        for idx, (_, rows, widths, title_rows) in enumerate(sheets, start=1):
            zf.writestr(f"xl/worksheets/sheet{idx}.xml", make_sheet_xml(rows, widths, title_rows))
    print(f"wrote {path}")


def guide_rows_for(block: str) -> list[list[str]]:
    rows: list[list[str]] = []
    in_format_table = False
    for row in PROGRAMMING:
        if not row:
            if rows and rows[-1]:
                rows.append(row)
            continue
        if row[0] == "格式":
            in_format_table = True
            if rows and rows[-1]:
                rows.append([])
            rows.append(row)
            continue
        if in_format_table:
            rows.append(row)
            continue
        if row[0] == "阶段":
            rows.append(row)
            continue
        if len(row) > 1 and (row[1] in (block, "ENC/DEC")):
            rows.append(row)
    return rows


def address_rules_for(block: str) -> list[list[str]]:
    rows = [ADDRESS_RULES[0]]
    for row in ADDRESS_RULES[1:]:
        item = row[0]
        if item.startswith(block) or item in {"Address map", "Contiguous UBWC layout", "Metadata pitch", "Tile pitch", "IRQ timing"}:
            rows.append(row)
    return rows


def main() -> None:
    enc_rows = english_table_rows("ENC", ENC_FIELDS)
    dec_rows = english_table_rows("DEC", DEC_FIELDS)
    write_rows_csv(ENC_CSV, enc_rows)
    write_rows_csv(DEC_CSV, dec_rows)
    table_widths = [24, 18, 26, 12, 16, 18, 34, 70, 90]
    combined_sheets = [
        ("ubwc_enc_apb", enc_rows, table_widths, {1}),
        ("ubwc_dec_apb", dec_rows, table_widths, {1}),
        ("Overview", overview_rows(), [34, 120], {1}),
        ("Programming_Guide", PROGRAMMING, [24, 10, 36, 8, 34, 110], {1, 42}),
        ("Address_Rules", ADDRESS_RULES, [28, 120], {1}),
    ]
    enc_sheets = [
        ("ubwc_enc_apb", enc_rows, table_widths, {1}),
        ("Overview", overview_rows(), [34, 120], {1}),
        ("Programming_Guide", guide_rows_for("ENC"), [24, 10, 36, 8, 34, 110], {1}),
        ("Address_Rules", address_rules_for("ENC"), [28, 120], {1}),
    ]
    dec_sheets = [
        ("ubwc_dec_apb", dec_rows, table_widths, {1}),
        ("Overview", overview_rows(), [34, 120], {1}),
        ("Programming_Guide", guide_rows_for("DEC"), [24, 10, 36, 8, 34, 110], {1}),
        ("Address_Rules", address_rules_for("DEC"), [28, 120], {1}),
    ]
    cn_sheets = [
        ("ENC寄存器表", cn_table_rows("ENC", ENC_FIELDS), table_widths, {1}),
        ("DEC寄存器表", cn_table_rows("DEC", DEC_FIELDS), table_widths, {1}),
        ("概览", [
            ["UBWC ENC/DEC APB 中文寄存器表"],
            ["生成时间", datetime.now().strftime("%Y-%m-%d %H:%M:%S")],
            ["说明", "本 workbook 是中文版寄存器表；ENC/DEC 地址组、连续帧、中断和统计寄存器已按当前 RTL 语义更新。"],
            ["配置频率", "静态/几何/CI/VIVO/OTF timing 在图像格式、尺寸、layout 或 timing 变化时配置；地址组每帧配置。"],
        ], [34, 120], {1}),
        ("配置流程", PROGRAMMING, [24, 10, 36, 8, 34, 110], {1, 42}),
        ("地址规则", [
            ["项目", "规则"],
            ["地址映射", "APB 寄存器为 32-bit 对齐访问。ENC 当前范围 0x000..0x09C，DEC 当前范围 0x000..0x078。"],
            ["ENC 地址 slot", "ENC 使用两个交替地址 slot，对应 fcnt[0]=0/1。每项包含 Y metadata base、Y tile base、UV metadata base、UV tile base。"],
            ["ENC 地址提交", "每帧写完四个 64-bit base 后，最后写 REG_TILE_BASE_UV_HI @0x04C。该写入会提交当前四个 base 为一组帧地址。"],
            ["DEC 地址组", "DEC 每帧写 metadata/tile 的 RGBA/Y 与 UV base 地址。完整地址组有效后可启动 decode。"],
            ["DEC START", "完整 DEC 地址组和 START token 都有效、metadata 不 busy、launch slot 可用时，硬件锁存本帧地址并启动 decode。"],
            ["连续 layout", "YUV 通常按 Y metadata、Y tile data、UV metadata、UV tile data 连续排列。RGBA 只需要 RGBA metadata 和 RGBA tile data。"],
            ["中断", "correct IRQ/frame_done 在最后一个有效帧输出/数据完成事件后产生；error IRQ 在错误条件锁存时产生。"],
        ], [28, 120], {1}),
    ]
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    write_workbook(OUTPUT_XLSX, combined_sheets)
    write_workbook(ENC_OUTPUT_XLSX, enc_sheets)
    write_workbook(DEC_OUTPUT_XLSX, dec_sheets)
    write_cn_csv(CN_OUTPUT_CSV)
    write_workbook(CN_OUTPUT_XLSX, cn_sheets)


if __name__ == "__main__":
    main()
