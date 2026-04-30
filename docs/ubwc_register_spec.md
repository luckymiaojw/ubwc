# UBWC Register Specification

This document describes the APB register map implemented by the current RTL:

- Encoder: `src/enc/ubwc_enc_apb_reg_blk.v`
- Decoder: `src/dec/ubwc_dec_apb_reg_blk.v`

Software should use the current RTL-compatible register map below. The CSV register tables in `docs/` follow this same map.

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
| `0x0008` | `TILE_CFG0` | `[0]` | `lvl1_bank_swizzle_en` | `RW` | Level-1 bank swizzle enable. Software default writes `0`; combined bank swizzle default `[2:0]=3'b110`. Current decoder output path does not forward this bit. |
| `0x0008` | `TILE_CFG0` | `[1]` | `lvl2_bank_swizzle_en` | `RW` | Level-2 bank swizzle enable. Software default writes `1`; combined bank swizzle default `[2:0]=3'b110`. |
| `0x0008` | `TILE_CFG0` | `[2]` | `lvl3_bank_swizzle_en` | `RW` | Level-3 bank swizzle enable. Software default writes `1`; combined bank swizzle default `[2:0]=3'b110`. |
| `0x0008` | `TILE_CFG0` | `[8:4]` | `highest_bank_bit` | `RW` | Highest bank bit configuration |
| `0x0008` | `TILE_CFG0` | `[9]` | `bank_spread_en` | `RW` | Bank spread enable. Software default writes `1`. |
| `0x0008` | `TILE_CFG0` | `[11]` | `is_lossy_rgba_2_1_format` | `RW` | Only applies to RGBA8888 metadata/tile address path. `0=normal RGBA/lossless layout`, `1=RGBA8888 lossy 2:1 layout`. When `1`, decoder halves the effective `tile_y` for address calculation, adds a 128-byte offset for odd `tile_y`, disables bank spread for this path, and treats 256-byte metadata payload as 128 bytes. |
| `0x000c` | `TILE_CFG1` | `[11:0]` | `pitch` | `RW` | Tile surface pitch in 16-byte units. Program `tile_cfg_pitch = align_up(width*bpp, tile_w*4*bpp)/16`. `bpp`: RGBA8888/RGBA1010102=4, YUV420_8=1, YUV420_10=2. `tile_w`: RGBA=16, YUV=32. RTL uses `tile_cfg_pitch << 4` as byte pitch. Example NV12 1996x1074: `align_up(1996*1,32*4*1)=2048` bytes, `tile_cfg_pitch=2048/16=128`. |
| `0x0010` | `TILE_CFG2` | `[0]` | `ci_input_type` | `RW` | `0=linear data`, `1=tiled data`. Software default writes `1`. |
| `0x0010` | `TILE_CFG2` | `[SB_WIDTH:1]` | `ci_sb` | `RW` | Reserved. Software should write `0`. |
| `0x0010` | `TILE_CFG2` | `[8]` | `ci_lossy` | `RW` | Software writes `1` for lossy format and `0` for lossless format. |
| `0x0010` | `TILE_CFG2` | `[10:9]` | `ci_alpha_mode` | `RW` | Reserved. Software should write `0`. |
| `0x0014` | `VIVO_CFG` | `[0]` | `vivo_ubwc_en` | `RW` | VIVO UBWC decode enable; reset value is `1` |
| `0x0014` | `VIVO_CFG` | `[1]` | `vivo_sreset` | `RW` | VIVO submodule soft reset |
| `0x0018` | `META_CFG0` | `[0]` | `meta_start` | `W1P` | Write `1` to start one frame. This toggles across to AXI clock and generates `frame_start_pulse_axi`. Readback is `0`. |
| `0x0018` | `META_CFG0` | `[8:4]` | `meta_base_format` | `RW` | Metadata/base format. Usually written together with `meta_start`. |
| `0x001c` | `META_CFG1` | `[31:0]` | `meta_base_addr_rgba_y[31:0]` | `RW` | Low 32 bits of RGBA/Y metadata base address. For contiguous UBWC buffer, program Y/RGBA metadata start. Metadata size: `meta_pitch=align_up(ceil(plane_width/tile_w),64)`, `meta_size=align_up(meta_pitch*align_up(ceil(plane_height/tile_h),16),4KB)`. Example NV12 1996x1074 base=0xA00000: Y `meta_base=0xA00000`, `meta_pitch=64`, `meta_size=0x3000`. |
| `0x0020` | `META_CFG2` | `[31:0]` | `meta_base_addr_rgba_y[63:32]` | `RW` | High 32 bits of RGBA/Y metadata base address |
| `0x0024` | `META_CFG3` | `[31:0]` | `meta_base_addr_uv[31:0]` | `RW` | Low 32 bits of UV metadata base address. Example NV12 1996x1074 contiguous layout: `meta_base_uv = tile_base_y + Y_pixel_size = 0xA03000 + 0x220000 = 0xC23000`; UV `meta_pitch=64`, UV `meta_size=0x2000`. |
| `0x0028` | `META_CFG4` | `[31:0]` | `meta_base_addr_uv[63:32]` | `RW` | High 32 bits of UV metadata base address |
| `0x002c` | `META_CFG5` | `[15:0]` | `meta_tile_x_numbers` | `RW` | Metadata tile count in horizontal direction. Shared by Y/RGBA and UV metadata scan. Program `ceil(width/tile_w)`: RGBA `tile_w=16`, YUV `tile_w=32`. Example 1996x1074: RGBA8888/RGBA1010102 => `round_up(1996/16)=125`; YUV420_8/YUV420_10 => `round_up(1996/32)=63`. |
| `0x002c` | `META_CFG5` | `[31:16]` | `meta_tile_y_numbers` | `RW` | Program Y/RGBA tile rows as `ceil(height/tile_h)`: RGBA `tile_h=4`, YUV `tile_h=8`. For YUV420, UV metadata rows are derived internally as `ceil(meta_tile_y_numbers/2)`. Example 1996x1074: RGBA8888/RGBA1010102 => `round_up(1074/4)=269`; YUV420_8/YUV420_10 => `round_up(1074/8)=135`; YUV420 internal UV rows=`round_up(135/2)=68`. |
| `0x0030` | `OTF_CFG0` | `[15:0]` | `img_width` | `RW` | Active output image width in pixels. Used to limit line unpacking: RGBA words=`ceil(width/4)`, YUV420_8/NV12 words=`ceil(width/16)`, YUV420_10/P010 words=`ceil(width/8)`. |
| `0x0030` | `OTF_CFG0` | `[20:16]` | `format` | `RW` | Frame-level output format. Codes: `0=RGBA8888`, `1=RGBA1010102`, `2=YUV420_8/NV12`, `3=YUV420_10/P010`. |
| `0x0034` | `OTF_CFG1` | `[15:0]` | `h_total` | `RW` | Horizontal total in pixels. RTL converts to OTF beats with `ceil(h_total/4)`. Must cover `h_sync + h_bp + h_act`. |
| `0x0034` | `OTF_CFG1` | `[31:16]` | `h_sync` | `RW` | Horizontal sync width in pixels. RTL converts to OTF beats with `ceil(h_sync/4)`. |
| `0x0038` | `OTF_CFG2` | `[15:0]` | `h_bp` | `RW` | Horizontal back porch in pixels. RTL converts to OTF beats with `ceil(h_bp/4)`. Active window starts after `h_sync + h_bp`. |
| `0x0038` | `OTF_CFG2` | `[31:16]` | `h_act` | `RW` | Horizontal active width in pixels. Usually program the visible output width; should match `img_width` unless blanking/active width is intentionally different. |
| `0x003c` | `OTF_CFG3` | `[15:0]` | `v_total` | `RW` | Vertical total in lines. Must cover `v_sync + v_bp + v_act`. |
| `0x003c` | `OTF_CFG3` | `[31:16]` | `v_sync` | `RW` | Vertical sync width in lines. |
| `0x0040` | `OTF_CFG4` | `[15:0]` | `v_bp` | `RW` | Vertical back porch in lines. Active window starts after `v_sync + v_bp`. |
| `0x0040` | `OTF_CFG4` | `[31:16]` | `v_act` | `RW` | Vertical active height in lines. Program the visible output height. |
| `0x0044` | `TILE_BASE0` | `[31:0]` | `tile_base_addr_rgba_uv[31:0]` | `RW` | Low 32 bits of RGBA/UV tile base address. For RGBA, program RGBA pixel/tile data start. For YUV, program UV pixel/tile data start. Example NV12 1996x1074: `UV tile_base = meta_base_uv + UV_meta_size = 0xC23000 + 0x2000 = 0xC25000`; UV pixel size `align_up(2*align_up(998,64)*align_up(537,32),4KB)=0x110000`. |
| `0x0048` | `TILE_BASE1` | `[31:0]` | `tile_base_addr_rgba_uv[63:32]` | `RW` | High 32 bits of RGBA/UV tile base address |
| `0x004c` | `TILE_BASE2` | `[31:0]` | `tile_base_addr_y[31:0]` | `RW` | Low 32 bits of Y tile base address. Pixel size: `pixel_pitch=align_up(width*bpp,tile_w*4*bpp)`, `aligned_height=align_up(height,32)`, `pixel_size=align_up(pixel_pitch*aligned_height,4KB)`. Example NV12 1996x1074: `Y tile_base = Y_meta_base + Y_meta_size = 0xA00000 + 0x3000 = 0xA03000`; `Y_pixel_size=0x220000`. |
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
| `0x0010` | `ENC_CI_CFG0` | `RW` | `0x0000_0000` | CI input type, alen, and reserved fields |
| `0x0014` | `ENC_CI_CFG1` | `RW` | `0x0000_0000` | CI sideband and lossy |
| `0x0018` | `ENC_CI_CFG2` | `RW` | `0x0000_0000` | Reserved |
| `0x001c` | `ENC_CI_CFG3` | `RW` | `0x0000_0000` | Reserved |
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
| `0x000c` | `TILE_CFG1` | `[0]` | `four_line_format` | `RW` | 4-line tile format enable. Program `1` for RGBA8888/RGBA1010102 and `0` for YUV420 formats. |
| `0x000c` | `TILE_CFG1` | `[1]` | `is_lossy_rgba_2_1_format` | `RW` | RGBA 2:1 lossy format select |
| `0x000c` | `TILE_CFG1` | `[26:16]` | `tile_pitch` | `RW` | Tile pitch in 16-byte units. Program `pitch_reg = align_up(width * bytes_per_pixel, tile_w * 4 * bytes_per_pixel) / 16`; effective width is 11 bits and output is zero-extended to 12 bits. Example NV12 1996x1074: `align_up(1996*1,32*4*1)=2048` bytes, `tile_pitch=2048/16=128`. |
| `0x0010` | `ENC_CI_CFG0` | `[0]` | `input_type` | `RW` | Encoding: `0` = linear data, `1` = tiled data. Fixed value for current encoder path: software should write `1`. |
| `0x0010` | `ENC_CI_CFG0` | `[10:8]` | `alen` | `RW` | Fixed value. Software should write `3'd7`. |
| `0x0010` | `ENC_CI_CFG0` | `[20:16]` | `reserved` | `RW` | Reserved. Software should write `0`; current encoder format is configured by `OTF_CFG0[2:0]`. |
| `0x0010` | `ENC_CI_CFG0` | `[24]` | `reserved` | `RW` | Reserved. Software should write `0`; forced PCM is generated dynamically by the OTF path. |
| `0x0014` | `ENC_CI_CFG1` | `[SB_WIDTH-1:0]` | `sb` | `RW` | Reserved. Software should write `0`. |
| `0x0014` | `ENC_CI_CFG1` | `[16]` | `lossy` | `RW` | CI lossy enable |
| `0x0018` | `ENC_CI_CFG2` | `[2:0]` | `ubwc_cfg_0` | `RW` | Reserved. Software should write `0`. |
| `0x0018` | `ENC_CI_CFG2` | `[5:3]` | `ubwc_cfg_1` | `RW` | Reserved. Software should write `0`. |
| `0x0018` | `ENC_CI_CFG2` | `[9:6]` | `ubwc_cfg_2` | `RW` | Reserved. Software should write `0`. |
| `0x0018` | `ENC_CI_CFG2` | `[13:10]` | `ubwc_cfg_3` | `RW` | Reserved. Software should write `0`. |
| `0x0018` | `ENC_CI_CFG2` | `[17:14]` | `ubwc_cfg_4` | `RW` | Reserved. Software should write `0`. |
| `0x0018` | `ENC_CI_CFG2` | `[21:18]` | `ubwc_cfg_5` | `RW` | Reserved. Software should write `0`. |
| `0x0018` | `ENC_CI_CFG2` | `[23:22]` | `ubwc_cfg_6` | `RW` | Reserved. Software should write `0`. |
| `0x0018` | `ENC_CI_CFG2` | `[25:24]` | `ubwc_cfg_7` | `RW` | Reserved. Software should write `0`. |
| `0x0018` | `ENC_CI_CFG2` | `[27:26]` | `ubwc_cfg_8` | `RW` | Reserved. Software should write `0`. |
| `0x0018` | `ENC_CI_CFG2` | `[30:28]` | `ubwc_cfg_9` | `RW` | Reserved. Software should write `0`. |
| `0x001c` | `ENC_CI_CFG3` | `[5:0]` | `ubwc_cfg_10` | `RW` | Reserved. Software should write `0`. |
| `0x001c` | `ENC_CI_CFG3` | `[13:8]` | `ubwc_cfg_11` | `RW` | Reserved. Software should write `0`. |
| `0x0020` | `OTF_CFG0` | `[2:0]` | `format` | `RW` | Input OTF format |
| `0x0024` | `OTF_CFG1` | `[15:0]` | `width` | `RW` | Input image width in pixels |
| `0x0024` | `OTF_CFG1` | `[31:16]` | `height` | `RW` | Input image height in pixels |
| `0x0028` | `OTF_CFG2` | `[15:0]` | `tile_w` | `RW` | Tile width in pixels |
| `0x0028` | `OTF_CFG2` | `[19:16]` | `tile_h` | `RW` | Tile height in pixels |
| `0x002c` | `OTF_CFG3` | `[15:0]` | `a_tile_cols` | `RW` | A-plane tile column count |
| `0x002c` | `OTF_CFG3` | `[31:16]` | `b_tile_cols` | `RW` | B-plane tile column count |
| `0x0030` | `TILE_BASE_Y_LO` | `[31:0]` | `y_base_addr[31:0]` | `RW` | Low 32 bits of Y compressed-data base address. For YUV formats, program Y pixel/tile data start. Example NV12 1996x1074 base=0xA00000: `Y tile_base=0xA03000`; `Y pixel_pitch=2048`, `aligned_height=1088`, `Y_pixel_size=0x220000`. |
| `0x0034` | `TILE_BASE_Y_HI` | `[31:0]` | `y_base_addr[63:32]` | `RW` | High 32 bits of Y compressed-data base address |
| `0x0038` | `TILE_BASE_UV_LO` | `[31:0]` | `uv_base_addr[31:0]` | `RW` | Low 32 bits of UV/RGBA compressed-data base address. For RGBA, program RGBA pixel/tile data start. For YUV, program UV pixel/tile data start. Example NV12 1996x1074: `UV tile_base=0xC25000`; UV pixel size `0x110000`. |
| `0x003c` | `TILE_BASE_UV_HI` | `[31:0]` | `uv_base_addr[63:32]` | `RW` | High 32 bits of UV/RGBA compressed-data base address |
| `0x0040` | `META_BASE_Y_LO` | `[31:0]` | `meta_y_base_addr[31:0]` | `RW` | Low 32 bits of Y metadata base address. For contiguous UBWC buffer, program Y metadata start address. Metadata size: `meta_pitch=align_up(ceil(plane_width/tile_w),64)`, `meta_size=align_up(meta_pitch*align_up(ceil(plane_height/tile_h),16),4KB)`. Example NV12 1996x1074: `Y meta_base=0xA00000`, `Y meta_pitch=64`, `Y meta_size=0x3000`. |
| `0x0044` | `META_BASE_Y_HI` | `[31:0]` | `meta_y_base_addr[63:32]` | `RW` | High 32 bits of Y metadata base address |
| `0x0048` | `META_BASE_UV_LO` | `[31:0]` | `meta_uv_base_addr[31:0]` | `RW` | Low 32 bits of UV/RGBA metadata base address. Example NV12 1996x1074: `UV_meta_base = Y_tile_base + Y_pixel_size = 0xA03000 + 0x220000 = 0xC23000`; UV `meta_pitch=64`, UV `meta_size=0x2000`. |
| `0x004c` | `META_BASE_UV_HI` | `[31:0]` | `meta_uv_base_addr[63:32]` | `RW` | High 32 bits of UV/RGBA metadata base address |
| `0x0050` | `META_ACTIVE_SIZE` | `[15:0]` | `active_width_px` | `RW` | Metadata active-area width in pixels |
| `0x0050` | `META_ACTIVE_SIZE` | `[31:16]` | `active_height_px` | `RW` | Metadata active-area height in pixels |
| `0x0054` | `META_PITCH` | `[31:0]` | `meta_data_plane_pitch` | `RW` | Metadata pitch. Program `align_up((align_up(width, tile_w * 4) + tile_w - 1) / tile_w, 64)`, matching `ubwc_demo.cpp`; current encoder metadata address path uses `meta_data_plane_pitch << 4` as byte stride. Example NV12 1996x1074 Y plane: `align_up((align_up(1996,128)+32-1)/32,64)=64`; UV plane example also uses `meta_pitch=64`. |
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
