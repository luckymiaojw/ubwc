# UBWC Register Specification

This document describes the APB register map implemented by the current RTL:

- Encoder: `src/enc/ubwc_enc_apb_reg_blk.v`
- Decoder: `src/dec/ubwc_dec_apb_reg_blk.v`

The `*_reg_table_v2.csv` files are proposal tables for a cleaned-up future map. Software for the current RTL should use the v1-compatible map below.

## Common APB Behavior

- Register width is 32 bits.
- APB accesses are word-aligned.
- `PREADY` is always `1`.
- `PSLVERR` is always `0`.
- Address offsets below are byte offsets from the wrapper APB base.
- 64-bit AXI base addresses are programmed as low 32 bits first and high 32 bits second.

Access type:

| Type | Meaning |
| --- | --- |
| `RO` | Read-only |
| `RW` | Read/write |
| `W1P` | Write `1` to generate a pulse; readback may not hold the written `1` |

## Decoder Register Map

Module: `ubwc_dec_apb_reg_blk`

Recommended configuration order:

1. Program `TILE_CFG0/1/2`.
2. Program `TILE_BASE0/1/2/3`.
3. Program `VIVO_CFG`.
4. Program `META_CFG1/2/3/4/5`.
5. Program `OTF_CFG0/1/2/3/4`.
6. Write `META_CFG0[0]=1` last to start one frame.
7. Poll `STATUS1[4]`, then confirm `STATUS0[6]`.

### Decoder Register Summary

| Offset | Name | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| `0x0000` | `VERSION` | `RO` | `0x0001_0000` | IP version |
| `0x0004` | `DATE` | `RO` | `0x2026_0403` | RTL date |
| `0x0008` | `TILE_CFG0` | `RW` | `0x0000_0000` | Tile address swizzle and format configuration |
| `0x000c` | `TILE_CFG1` | `RW` | `0x0000_0000` | Tile pitch |
| `0x0010` | `TILE_CFG2` | `RW` | `0x0000_0000` | CI sideband/lossy/alpha configuration |
| `0x0014` | `VIVO_CFG` | `RW` | `0x0000_0001` | VIVO enable and soft reset |
| `0x0018` | `META_CFG0` | `W1P/RW` | `0x0000_0000` | Decoder start pulse and metadata format |
| `0x001c` | `META_CFG1` | `RW` | `0x0000_0000` | Metadata RGBA/Y base address low |
| `0x0020` | `META_CFG2` | `RW` | `0x0000_0000` | Metadata RGBA/Y base address high |
| `0x0024` | `META_CFG3` | `RW` | `0x0000_0000` | Metadata UV base address low |
| `0x0028` | `META_CFG4` | `RW` | `0x0000_0000` | Metadata UV base address high |
| `0x002c` | `META_CFG5` | `RW` | `0x0000_0000` | Metadata tile counts |
| `0x0030` | `OTF_CFG0` | `RW` | `0x0000_0000` | Output image width and format |
| `0x0034` | `OTF_CFG1` | `RW` | `0x0000_0000` | OTF horizontal total/sync |
| `0x0038` | `OTF_CFG2` | `RW` | `0x0000_0000` | OTF horizontal back porch/active |
| `0x003c` | `OTF_CFG3` | `RW` | `0x0000_0000` | OTF vertical total/sync |
| `0x0040` | `OTF_CFG4` | `RW` | `0x0000_0000` | OTF vertical back porch/active |
| `0x0044` | `TILE_BASE0` | `RW` | `0x0000_0000` | Tile RGBA/UV base address low |
| `0x0048` | `TILE_BASE1` | `RW` | `0x0000_0000` | Tile RGBA/UV base address high |
| `0x004c` | `TILE_BASE2` | `RW` | `0x0000_0000` | Tile Y base address low |
| `0x0050` | `TILE_BASE3` | `RW` | `0x0000_0000` | Tile Y base address high |
| `0x0054` | `STATUS0` | `RO` | dynamic | Live decoder status |
| `0x0058` | `STATUS1` | `RO` | dynamic | Stage-done and frame-done status |
| `0x005c` | `STATUS2` | `RO` | dynamic | Raw VIVO idle bitmap |
| `0x0060` | `STATUS3` | `RO` | dynamic | Raw VIVO error bitmap |
| `0x0064` | `IRQ_CTRL` | `RW/W1P` | `0x0000_0001` | IRQ enable, clear, and pending status |

### Decoder Field Detail

| Offset | Register | Bits | Field | Access | Description |
| --- | --- | --- | --- | --- | --- |
| `0x0000` | `VERSION` | `[31:0]` | `version` | `RO` | Fixed `32'h0001_0000` |
| `0x0004` | `DATE` | `[31:0]` | `date` | `RO` | Fixed `32'h2026_0403` |
| `0x0008` | `TILE_CFG0` | `[0]` | `lvl1_bank_swizzle_en` | `RW` | Level-1 bank swizzle enable. Current decoder output path does not forward this bit. |
| `0x0008` | `TILE_CFG0` | `[1]` | `lvl2_bank_swizzle_en` | `RW` | Level-2 bank swizzle enable |
| `0x0008` | `TILE_CFG0` | `[2]` | `lvl3_bank_swizzle_en` | `RW` | Level-3 bank swizzle enable |
| `0x0008` | `TILE_CFG0` | `[8:4]` | `highest_bank_bit` | `RW` | Highest bank bit configuration |
| `0x0008` | `TILE_CFG0` | `[9]` | `bank_spread_en` | `RW` | Bank spread enable |
| `0x0008` | `TILE_CFG0` | `[10]` | `4line_format` | `RW` | Stored/read back, but current decoder output path does not forward this bit |
| `0x0008` | `TILE_CFG0` | `[11]` | `is_lossy_rgba_2_1_format` | `RW` | RGBA 2:1 lossy format select |
| `0x000c` | `TILE_CFG1` | `[11:0]` | `pitch` | `RW` | Tile pitch configuration |
| `0x0010` | `TILE_CFG2` | `[0]` | `ci_input_type` | `RW` | CI input type |
| `0x0010` | `TILE_CFG2` | `[SB_WIDTH:1]` | `ci_sb` | `RW` | CI sideband; width is controlled by parameter `SB_WIDTH` |
| `0x0010` | `TILE_CFG2` | `[8]` | `ci_lossy` | `RW` | CI lossy enable |
| `0x0010` | `TILE_CFG2` | `[10:9]` | `ci_alpha_mode` | `RW` | CI alpha mode |
| `0x0014` | `VIVO_CFG` | `[0]` | `vivo_ubwc_en` | `RW` | VIVO UBWC decode enable; reset value is `1` |
| `0x0014` | `VIVO_CFG` | `[1]` | `vivo_sreset` | `RW` | VIVO submodule soft reset |
| `0x0018` | `META_CFG0` | `[0]` | `meta_start` | `W1P` | Write `1` to start one frame. This toggles across to AXI clock and generates `frame_start_pulse_axi`. Readback is `0`. |
| `0x0018` | `META_CFG0` | `[8:4]` | `meta_base_format` | `RW` | Metadata/base format. Usually written together with `meta_start`. |
| `0x001c` | `META_CFG1` | `[31:0]` | `meta_base_addr_rgba_y[31:0]` | `RW` | Low 32 bits of RGBA/Y metadata base address |
| `0x0020` | `META_CFG2` | `[31:0]` | `meta_base_addr_rgba_y[63:32]` | `RW` | High 32 bits of RGBA/Y metadata base address |
| `0x0024` | `META_CFG3` | `[31:0]` | `meta_base_addr_uv[31:0]` | `RW` | Low 32 bits of UV metadata base address |
| `0x0028` | `META_CFG4` | `[31:0]` | `meta_base_addr_uv[63:32]` | `RW` | High 32 bits of UV metadata base address |
| `0x002c` | `META_CFG5` | `[15:0]` | `meta_tile_x_numbers` | `RW` | Metadata tile count in horizontal direction |
| `0x002c` | `META_CFG5` | `[31:16]` | `meta_tile_y_numbers` | `RW` | Metadata tile count in vertical direction |
| `0x0030` | `OTF_CFG0` | `[15:0]` | `img_width` | `RW` | Output image width in pixels |
| `0x0030` | `OTF_CFG0` | `[20:16]` | `format` | `RW` | Output OTF format |
| `0x0034` | `OTF_CFG1` | `[15:0]` | `h_total` | `RW` | OTF horizontal total |
| `0x0034` | `OTF_CFG1` | `[31:16]` | `h_sync` | `RW` | OTF horizontal sync |
| `0x0038` | `OTF_CFG2` | `[15:0]` | `h_bp` | `RW` | OTF horizontal back porch |
| `0x0038` | `OTF_CFG2` | `[31:16]` | `h_act` | `RW` | OTF horizontal active |
| `0x003c` | `OTF_CFG3` | `[15:0]` | `v_total` | `RW` | OTF vertical total |
| `0x003c` | `OTF_CFG3` | `[31:16]` | `v_sync` | `RW` | OTF vertical sync |
| `0x0040` | `OTF_CFG4` | `[15:0]` | `v_bp` | `RW` | OTF vertical back porch |
| `0x0040` | `OTF_CFG4` | `[31:16]` | `v_act` | `RW` | OTF vertical active |
| `0x0044` | `TILE_BASE0` | `[31:0]` | `tile_base_addr_rgba_uv[31:0]` | `RW` | Low 32 bits of RGBA/UV tile base address |
| `0x0048` | `TILE_BASE1` | `[31:0]` | `tile_base_addr_rgba_uv[63:32]` | `RW` | High 32 bits of RGBA/UV tile base address |
| `0x004c` | `TILE_BASE2` | `[31:0]` | `tile_base_addr_y[31:0]` | `RW` | Low 32 bits of Y tile base address |
| `0x0050` | `TILE_BASE3` | `[31:0]` | `tile_base_addr_y[63:32]` | `RW` | High 32 bits of Y tile base address |
| `0x0054` | `STATUS0` | `[0]` | `frame_active` | `RO` | Current frame is active |
| `0x0054` | `STATUS0` | `[1]` | `meta_busy` | `RO` | Metadata read stage busy |
| `0x0054` | `STATUS0` | `[2]` | `tile_busy` | `RO` | Tile read stage busy |
| `0x0054` | `STATUS0` | `[3]` | `vivo_busy` | `RO` | VIVO decode stage busy |
| `0x0054` | `STATUS0` | `[4]` | `otf_busy` | `RO` | OTF output stage busy |
| `0x0054` | `STATUS0` | `[5]` | `all_stage_idle` | `RO` | All busy inputs are `0`; may be `1` before frame start |
| `0x0054` | `STATUS0` | `[6]` | `frame_idle_done` | `RO` | All stages idle and `frame_active=0`; use with `STATUS1[4]` for completion |
| `0x0058` | `STATUS1` | `[0]` | `meta_done` | `RO` | Metadata stage completed |
| `0x0058` | `STATUS1` | `[1]` | `tile_done` | `RO` | Tile stage completed |
| `0x0058` | `STATUS1` | `[2]` | `vivo_done` | `RO` | VIVO stage completed |
| `0x0058` | `STATUS1` | `[3]` | `otf_done` | `RO` | OTF stage completed |
| `0x0058` | `STATUS1` | `[4]` | `frame_done` | `RO` | Full-frame completion flag. This is the primary software polling bit. |
| `0x0058` | `STATUS1` | `[8:5]` | `stage_seen_busy` | `RO` | `{otf_seen, vivo_seen, tile_seen, meta_seen}` |
| `0x005c` | `STATUS2` | `[6:0]` | `vivo_idle_bits` | `RO` | Raw VIVO idle bitmap |
| `0x0060` | `STATUS3` | `[6:0]` | `vivo_error_bits` | `RO` | Raw VIVO error bitmap |
| `0x0064` | `IRQ_CTRL` | `[0]` | `irq_enable` | `RW` | IRQ enable. Reset value is `1`. |
| `0x0064` | `IRQ_CTRL` | `[1]` | `irq_clear` | `W1P` | Write `1` to generate an IRQ clear pulse in AXI clock domain |
| `0x0064` | `IRQ_CTRL` | `[2]` | `irq_pending` | `RO` | Current IRQ pending status |

Decoder completion polling:

```text
write(0x0018, (base_format << 4) | 1);
poll_until((read(0x0058) & (1 << 4)) != 0);  // STATUS1.frame_done
poll_until((read(0x0054) & (1 << 6)) != 0);  // STATUS0.frame_idle_done
```

## Encoder Register Map

Module: `ubwc_enc_apb_reg_blk`

The encoder has no APB `start` bit in the current RTL. It starts when configuration has been programmed and the upstream OTF input stream begins handshaking.

Recommended configuration order:

1. Program `TILE_CFG1`, then `TILE_CFG0`.
2. Program tile and metadata base addresses.
3. Program `ENC_CI_CFG1/2/3`, then `ENC_CI_CFG0`.
4. Program `OTF_CFG1/2/3`, `META_ACTIVE_SIZE`, and `META_PITCH`, then `OTF_CFG0`.
5. Start sending `i_otf_*`.

### Encoder Register Summary

| Offset | Name | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| `0x0000` | `VERSION` | `RO` | `0x0001_0000` | IP version |
| `0x0004` | `DATE` | `RO` | `0x2026_0406` | RTL date |
| `0x0008` | `TILE_CFG0` | `RW` | `0x0000_0000` | UBWC enable and swizzle configuration |
| `0x000c` | `TILE_CFG1` | `RW` | `0x0000_0000` | 4-line/lossy/pitch configuration |
| `0x0010` | `ENC_CI_CFG0` | `RW` | `0x0000_0000` | CI input type, alen, format |
| `0x0014` | `ENC_CI_CFG1` | `RW` | `0x0000_0000` | CI sideband and lossy |
| `0x0018` | `ENC_CI_CFG2` | `RW` | `0x0000_0000` | UBWC CI configuration 0-9 |
| `0x001c` | `ENC_CI_CFG3` | `RW` | `0x0000_0000` | UBWC CI configuration 10-11 |
| `0x0020` | `OTF_CFG0` | `RW` | `0x0000_0000` | Input OTF format |
| `0x0024` | `OTF_CFG1` | `RW` | `0x0000_0000` | Input image width/height |
| `0x0028` | `OTF_CFG2` | `RW` | `0x0000_0000` | Tile width/height |
| `0x002c` | `OTF_CFG3` | `RW` | `0x0000_0000` | A/B-plane tile columns |
| `0x0030` | `TILE_BASE_Y_LO` | `RW` | `0x0000_0000` | Y compressed-data base address low |
| `0x0034` | `TILE_BASE_Y_HI` | `RW` | `0x0000_0000` | Y compressed-data base address high |
| `0x0038` | `TILE_BASE_UV_LO` | `RW` | `0x0000_0000` | UV/RGBA compressed-data base address low |
| `0x003c` | `TILE_BASE_UV_HI` | `RW` | `0x0000_0000` | UV/RGBA compressed-data base address high |
| `0x0040` | `META_BASE_Y_LO` | `RW` | `0x0000_0000` | Y metadata base address low |
| `0x0044` | `META_BASE_Y_HI` | `RW` | `0x0000_0000` | Y metadata base address high |
| `0x0048` | `META_BASE_UV_LO` | `RW` | `0x0000_0000` | UV/RGBA metadata base address low |
| `0x004c` | `META_BASE_UV_HI` | `RW` | `0x0000_0000` | UV/RGBA metadata base address high |
| `0x0050` | `META_ACTIVE_SIZE` | `RW` | `0x0000_0000` | Metadata active width/height |
| `0x0054` | `META_PITCH` | `RW` | `0x0000_0000` | Metadata plane pitch in bytes |
| `0x0058` | `STATUS0` | `RO` | dynamic | Encoder live status |
| `0x005c` | `STATUS1` | `RO` | dynamic | Stage done bitmap |
| `0x0060` | `IRQ_CTRL` | `RW/W1P` | `0x0000_0001` | IRQ enable, clear, and pending status |

### Encoder Field Detail

| Offset | Register | Bits | Field | Access | Description |
| --- | --- | --- | --- | --- | --- |
| `0x0000` | `VERSION` | `[31:0]` | `version` | `RO` | Fixed `32'h0001_0000` |
| `0x0004` | `DATE` | `[31:0]` | `date` | `RO` | Fixed `32'h2026_0406` |
| `0x0008` | `TILE_CFG0` | `[0]` | `enc_ubwc_en` | `RW` | UBWC encode enable |
| `0x0008` | `TILE_CFG0` | `[1]` | `lvl1_bank_swizzle_en` | `RW` | Level-1 bank swizzle enable |
| `0x0008` | `TILE_CFG0` | `[2]` | `lvl2_bank_swizzle_en` | `RW` | Level-2 bank swizzle enable |
| `0x0008` | `TILE_CFG0` | `[3]` | `lvl3_bank_swizzle_en` | `RW` | Level-3 bank swizzle enable |
| `0x0008` | `TILE_CFG0` | `[12:8]` | `highest_bank_bit` | `RW` | Highest bank bit configuration |
| `0x0008` | `TILE_CFG0` | `[16]` | `bank_spread_en` | `RW` | Bank spread enable |
| `0x000c` | `TILE_CFG1` | `[0]` | `four_line_format` | `RW` | 4-line tile format enable |
| `0x000c` | `TILE_CFG1` | `[1]` | `is_lossy_rgba_2_1_format` | `RW` | RGBA 2:1 lossy format select |
| `0x000c` | `TILE_CFG1` | `[26:16]` | `tile_pitch` | `RW` | Effective width is 11 bits; output is zero-extended to 12 bits |
| `0x0010` | `ENC_CI_CFG0` | `[0]` | `input_type` | `RW` | CI input type |
| `0x0010` | `ENC_CI_CFG0` | `[10:8]` | `alen` | `RW` | CI AXI length configuration |
| `0x0010` | `ENC_CI_CFG0` | `[20:16]` | `format` | `RW` | CI format field in legacy table; current output format for OTF path is from `OTF_CFG0[2:0]` |
| `0x0010` | `ENC_CI_CFG0` | `[24]` | `reserved` | `RW` | Stored but not used as forced PCM by current assignments |
| `0x0014` | `ENC_CI_CFG1` | `[SB_WIDTH-1:0]` | `sb` | `RW` | CI sideband; width is controlled by parameter `SB_WIDTH` |
| `0x0014` | `ENC_CI_CFG1` | `[16]` | `lossy` | `RW` | CI lossy enable |
| `0x0018` | `ENC_CI_CFG2` | `[2:0]` | `ubwc_cfg_0` | `RW` | UBWC CI configuration 0 |
| `0x0018` | `ENC_CI_CFG2` | `[5:3]` | `ubwc_cfg_1` | `RW` | UBWC CI configuration 1 |
| `0x0018` | `ENC_CI_CFG2` | `[9:6]` | `ubwc_cfg_2` | `RW` | UBWC CI configuration 2 |
| `0x0018` | `ENC_CI_CFG2` | `[13:10]` | `ubwc_cfg_3` | `RW` | UBWC CI configuration 3 |
| `0x0018` | `ENC_CI_CFG2` | `[17:14]` | `ubwc_cfg_4` | `RW` | UBWC CI configuration 4 |
| `0x0018` | `ENC_CI_CFG2` | `[21:18]` | `ubwc_cfg_5` | `RW` | UBWC CI configuration 5 |
| `0x0018` | `ENC_CI_CFG2` | `[23:22]` | `ubwc_cfg_6` | `RW` | UBWC CI configuration 6 |
| `0x0018` | `ENC_CI_CFG2` | `[25:24]` | `ubwc_cfg_7` | `RW` | UBWC CI configuration 7 |
| `0x0018` | `ENC_CI_CFG2` | `[27:26]` | `ubwc_cfg_8` | `RW` | UBWC CI configuration 8 |
| `0x0018` | `ENC_CI_CFG2` | `[30:28]` | `ubwc_cfg_9` | `RW` | UBWC CI configuration 9 |
| `0x001c` | `ENC_CI_CFG3` | `[5:0]` | `ubwc_cfg_10` | `RW` | UBWC CI configuration 10 |
| `0x001c` | `ENC_CI_CFG3` | `[13:8]` | `ubwc_cfg_11` | `RW` | UBWC CI configuration 11 |
| `0x0020` | `OTF_CFG0` | `[2:0]` | `format` | `RW` | Input OTF format |
| `0x0024` | `OTF_CFG1` | `[15:0]` | `width` | `RW` | Input image width in pixels |
| `0x0024` | `OTF_CFG1` | `[31:16]` | `height` | `RW` | Input image height in pixels |
| `0x0028` | `OTF_CFG2` | `[15:0]` | `tile_w` | `RW` | Tile width in pixels |
| `0x0028` | `OTF_CFG2` | `[19:16]` | `tile_h` | `RW` | Tile height in pixels |
| `0x002c` | `OTF_CFG3` | `[15:0]` | `a_tile_cols` | `RW` | A-plane tile column count |
| `0x002c` | `OTF_CFG3` | `[31:16]` | `b_tile_cols` | `RW` | B-plane tile column count |
| `0x0030` | `TILE_BASE_Y_LO` | `[31:0]` | `y_base_addr[31:0]` | `RW` | Low 32 bits of Y compressed-data base address |
| `0x0034` | `TILE_BASE_Y_HI` | `[31:0]` | `y_base_addr[63:32]` | `RW` | High 32 bits of Y compressed-data base address |
| `0x0038` | `TILE_BASE_UV_LO` | `[31:0]` | `uv_base_addr[31:0]` | `RW` | Low 32 bits of UV/RGBA compressed-data base address |
| `0x003c` | `TILE_BASE_UV_HI` | `[31:0]` | `uv_base_addr[63:32]` | `RW` | High 32 bits of UV/RGBA compressed-data base address |
| `0x0040` | `META_BASE_Y_LO` | `[31:0]` | `meta_y_base_addr[31:0]` | `RW` | Low 32 bits of Y metadata base address |
| `0x0044` | `META_BASE_Y_HI` | `[31:0]` | `meta_y_base_addr[63:32]` | `RW` | High 32 bits of Y metadata base address |
| `0x0048` | `META_BASE_UV_LO` | `[31:0]` | `meta_uv_base_addr[31:0]` | `RW` | Low 32 bits of UV/RGBA metadata base address |
| `0x004c` | `META_BASE_UV_HI` | `[31:0]` | `meta_uv_base_addr[63:32]` | `RW` | High 32 bits of UV/RGBA metadata base address |
| `0x0050` | `META_ACTIVE_SIZE` | `[15:0]` | `active_width_px` | `RW` | Metadata active-area width in pixels |
| `0x0050` | `META_ACTIVE_SIZE` | `[31:16]` | `active_height_px` | `RW` | Metadata active-area height in pixels |
| `0x0054` | `META_PITCH` | `[31:0]` | `meta_data_plane_pitch` | `RW` | Metadata plane pitch in bytes |
| `0x0058` | `STATUS0` | `[0]` | `enc_idle` | `RO` | Encoder core idle |
| `0x0058` | `STATUS0` | `[1]` | `enc_error` | `RO` | Encoder core error |
| `0x0058` | `STATUS0` | `[2]` | `otf_to_tile_busy` | `RO` | OTF-to-tile stage busy |
| `0x0058` | `STATUS0` | `[3]` | `otf_to_tile_overflow` | `RO` | OTF-to-tile FIFO overflow |
| `0x0058` | `STATUS0` | `[4]` | `otf_err_bline` | `RO` | OTF bad-line error |
| `0x0058` | `STATUS0` | `[5]` | `otf_err_bframe` | `RO` | OTF bad-frame error |
| `0x0058` | `STATUS0` | `[6]` | `meta_err_0` | `RO` | Metadata generator error 0 |
| `0x0058` | `STATUS0` | `[7]` | `meta_err_1` | `RO` | Metadata generator error 1 |
| `0x0058` | `STATUS0` | `[8]` | `frame_done` | `RO` | Frame-done status from encoder wrapper |
| `0x005c` | `STATUS1` | `[7:0]` | `stage_done` | `RO` | Encoder stage-done bitmap |
| `0x0060` | `IRQ_CTRL` | `[0]` | `irq_enable` | `RW` | IRQ enable. Reset value is `1`. |
| `0x0060` | `IRQ_CTRL` | `[1]` | `irq_clear` | `W1P` | Write `1` to generate an IRQ clear pulse in encoder clock domain |
| `0x0060` | `IRQ_CTRL` | `[2]` | `irq_pending` | `RO` | Current IRQ pending status |

Encoder completion hint:

```text
start_otf_input_stream();
poll_until((read(0x0058) & (1 << 0)) != 0);  // STATUS0.enc_idle
check((read(0x0058) & 0x0000007e) == 0);     // no error bits
```

The current encoder RTL exposes live status bits. If the integration needs a sticky software completion flag, add one in RTL or use an external frame-output/activity monitor.
