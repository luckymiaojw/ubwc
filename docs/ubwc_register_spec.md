# UBWC Register Specification

This document describes the APB register map implemented by the current RTL:

- Encoder: `src/enc/ubwc_enc_apb_reg_blk.v`
- Decoder: `src/dec/ubwc_dec_apb_reg_blk.v`

Software should use the current RTL-compatible register map below. The CSV register tables in `docs/` follow this same map.

## Current Integration Baseline

The current wrapper-level integration assumes four independent clock domains:

| Clock domain | Regression frequency | ENC port | DEC port | Main usage |
| --- | --- | --- | --- | --- |
| APB | 100 MHz | `PCLK` | `PCLK` | Register access |
| AXI/control | 500 MHz | `i_clk` | `i_axi_clk` | AXI traffic, APB-synchronized control, status/statistics |
| Core/VIVO | 200 MHz | `i_vivo_clk` | `i_vivo_clk` | `ubwc_enc_vivo_top` / `ubwc_dec_vivo_top` |
| OTF | 320 MHz | `i_otf_clk` | `i_otf_clk` | OTF input/output video stream |

Clock-domain rules:

- APB register writes are synchronized before they are used by AXI/control logic.
- AXI/control, core/VIVO, and OTF data paths are separated by FIFO or explicit CDC logic.
- Multi-bit counters or payload buses must not cross clock domains by simple two-flop synchronization.
- Async reset release must be synchronized inside the destination clock domain.

Supported frame formats are `0=RGBA8888`, `1=RGBA1010102`, `2=YUV420_8/NV12`, and `3=YUV420_10/P010`. YUV422 formats are not supported by the current RTL.

The 2026-05-11 regression baseline used `OTF=320 MHz`, `core/VIVO=200 MHz`, and `AXI=500 MHz` on server `10.168.1.199:/home/eda/work/ubwc/trunk`:

```text
tcsh -c "source prj_setup.env; make -C vrf/sim random_if_fake_all"
log: vrf/sim/build/regress_logs/random_if_clk320_200_500_rerun_20260511_100738.log
Summary: pass=8 fail=0
```

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

1. Program static layout registers: `TILE_CFG0/1/2`, `VIVO_CFG`, `OTF_CFG0..4`, and `APB_ADDR_META_CFG0`.
2. For each input UBWC buffer, write the four 64-bit address pairs in this order: metadata Y/RGBA, tile Y/RGBA, metadata UV, tile UV.
3. Each 64-bit address is written low word first, high word second.
4. Write `IRQ_CTRL[5]=1` after the address entries required for one frame are valid. Address writes only fill the pending address queues; they no longer start a frame by themselves.
5. Poll `STATUS1[4]`, then confirm `STATUS0[6]` if software wants an idle-done check.

### Decoder Register Summary

| Offset | Name | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| `0x0000` | `VERSION` | `RO` | `0x0001_0000` | IP version |
| `0x0004` | `DATE` | `RO` | `0x2026_0403` | RTL date |
| `0x0008` | `TILE_CFG0` | `RW` | `0x0000_0000` | Tile address swizzle and format configuration |
| `0x000c` | `TILE_CFG1` | `RW` | `0x0000_0000` | Tile pitch |
| `0x0010` | `TILE_CFG2` | `RW` | `0x0000_0000` | CI input/lossy/alpha configuration |
| `0x0014` | `VIVO_CFG` | `RW` | `0x0000_0001` | VIVO enable and soft reset |
| `0x0018` | `OTF_CFG0` | `RW` | `0x0000_0000` | Output image width and format |
| `0x001c` | `OTF_CFG1` | `RW` | `0x0000_0000` | OTF horizontal total/sync |
| `0x0020` | `OTF_CFG2` | `RW` | `0x0000_0000` | OTF horizontal back porch/active |
| `0x0024` | `OTF_CFG3` | `RW` | `0x0000_0000` | OTF vertical total/sync |
| `0x0028` | `OTF_CFG4` | `RW` | `0x0000_0000` | OTF vertical back porch/active |
| `0x002c` | `APB_ADDR_META_CFG0` | `RW` | `0x0000_0000` | Metadata tile counts |
| `0x0030` | `REG_META_BASE_Y_LO` | `RW` | `0x0000_0000` | Metadata RGBA/Y base address low |
| `0x0034` | `REG_META_BASE_Y_HI` | `RW` | `0x0000_0000` | Metadata RGBA/Y base address high |
| `0x0038` | `REG_TILE_BASE_Y_LO` | `RW` | `0x0000_0000` | Tile RGBA/Y base address low |
| `0x003c` | `REG_TILE_BASE_Y_HI` | `RW` | `0x0000_0000` | Tile RGBA/Y base address high |
| `0x0040` | `REG_META_BASE_UV_LO` | `RW` | `0x0000_0000` | Metadata UV base address low |
| `0x0044` | `REG_META_BASE_UV_HI` | `RW` | `0x0000_0000` | Metadata UV base address high |
| `0x0048` | `REG_TILE_BASE_UV_LO` | `RW` | `0x0000_0000` | Tile UV base address low |
| `0x004c` | `REG_TILE_BASE_UV_HI` | `RW` | `0x0000_0000` | Tile UV base address high |
| `0x0050` | `STATUS0` | `RO` | dynamic | Live decoder status |
| `0x0054` | `STATUS1` | `RO` | dynamic | Stage-done and frame-done status |
| `0x0058` | `STATUS2` | `RO` | dynamic | Raw VIVO idle bitmap |
| `0x005c` | `STATUS3` | `RO` | dynamic | Raw VIVO error bitmap |
| `0x0060` | `IRQ_CTRL` | `RW/W1P` | `0x0000_0001` | IRQ enable, clear, start pulse, and pending status |
| `0x0064` | `STATUS4` | `RO` | dynamic | IRQ status mirror |
| `0x0068` | `STAT_META` | `RO` | dynamic | Metadata valid tile count |
| `0x006c` | `STAT_TILE` | `RO` | dynamic | Tile address valid tile count |
| `0x0070` | `STAT_OTF_TILE` | `RO` | dynamic | Tile-to-OTF accepted tile count |
| `0x0074` | `STAT_OTF_LINE` | `RO` | dynamic | OTF output line count |
| `0x0078` | `STAT_OTF_DE` | `RO` | dynamic | OTF output `de && ready` beat count |

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
| `0x0010` | `TILE_CFG2` | `[8]` | `ci_lossy` | `RW` | Software writes `1` for lossy format and `0` for lossless format. |
| `0x0010` | `TILE_CFG2` | `[10:9]` | `ci_alpha_mode` | `RW` | Reserved. Software should write `0`. |
| `0x0014` | `VIVO_CFG` | `[0]` | `vivo_ubwc_en` | `RW` | VIVO UBWC decode enable; reset value is `1` |
| `0x0014` | `VIVO_CFG` | `[1]` | `vivo_sreset` | `RW` | VIVO submodule soft reset |
| `0x0018` | `OTF_CFG0` | `[15:0]` | `img_width` | `RW` | Active output image width in pixels. |
| `0x0018` | `OTF_CFG0` | `[20:16]` | `format` | `RW` | Frame-level output format. Codes: `0=RGBA8888`, `1=RGBA1010102`, `2=YUV420_8/NV12`, `3=YUV420_10/P010`. This also drives the decoder metadata/base format. |
| `0x001c` | `OTF_CFG1` | `[15:0]` | `h_total` | `RW` | Horizontal total in pixels. Must cover `h_sync + h_bp + h_act`. |
| `0x001c` | `OTF_CFG1` | `[31:16]` | `h_sync` | `RW` | Horizontal sync width in pixels. |
| `0x0020` | `OTF_CFG2` | `[15:0]` | `h_bp` | `RW` | Horizontal back porch in pixels. Active window starts after `h_sync + h_bp`. |
| `0x0020` | `OTF_CFG2` | `[31:16]` | `h_act` | `RW` | Horizontal active width in pixels. Usually program the visible output width. |
| `0x0024` | `OTF_CFG3` | `[15:0]` | `v_total` | `RW` | Vertical total in lines. Must cover `v_sync + v_bp + v_act`. |
| `0x0024` | `OTF_CFG3` | `[31:16]` | `v_sync` | `RW` | Vertical sync width in lines. |
| `0x0028` | `OTF_CFG4` | `[15:0]` | `v_bp` | `RW` | Vertical back porch in lines. |
| `0x0028` | `OTF_CFG4` | `[31:16]` | `v_act` | `RW` | Vertical active height in lines. |
| `0x002c` | `APB_ADDR_META_CFG0` | `[15:0]` | `meta_tile_x_numbers` | `RW` | Metadata tile count in horizontal direction. Shared by Y/RGBA and UV metadata scan. Program `ceil(width/tile_w)`: RGBA `tile_w=16`, YUV `tile_w=32`. Example 1996x1074: RGBA8888/RGBA1010102 => `round_up(1996/16)=125`; YUV420_8/YUV420_10 => `round_up(1996/32)=63`. |
| `0x002c` | `APB_ADDR_META_CFG0` | `[31:16]` | `meta_tile_y_numbers` | `RW` | Program Y/RGBA tile rows as `ceil(height/tile_h)`: RGBA `tile_h=4`, YUV `tile_h=8`. For YUV420, UV metadata rows are derived internally as `ceil(meta_tile_y_numbers/2)`. Example 1996x1074: RGBA8888/RGBA1010102 => `round_up(1074/4)=269`; YUV420_8/YUV420_10 => `round_up(1074/8)=135`; YUV420 internal UV rows=`round_up(135/2)=68`. |
| `0x0030` | `REG_META_BASE_Y_LO` | `[31:0]` | `meta_base_addr_rgba_y[31:0]` | `RW` | Low 32 bits of RGBA/Y metadata base address. |
| `0x0034` | `REG_META_BASE_Y_HI` | `[31:0]` | `meta_base_addr_rgba_y[63:32]` | `RW` | High 32 bits of RGBA/Y metadata base address. Write after `REG_META_BASE_Y_LO` to complete this 64-bit base address. |
| `0x0038` | `REG_TILE_BASE_Y_LO` | `[31:0]` | `tile_base_addr_rgba_y[31:0]` | `RW` | Low 32 bits of RGBA/Y compressed tile data base address. |
| `0x003c` | `REG_TILE_BASE_Y_HI` | `[31:0]` | `tile_base_addr_rgba_y[63:32]` | `RW` | High 32 bits of RGBA/Y compressed tile data base address. Write after `REG_TILE_BASE_Y_LO` to complete this 64-bit base address. |
| `0x0040` | `REG_META_BASE_UV_LO` | `[31:0]` | `meta_base_addr_uv[31:0]` | `RW` | Low 32 bits of UV metadata base address. RGBA formats do not use this address. |
| `0x0044` | `REG_META_BASE_UV_HI` | `[31:0]` | `meta_base_addr_uv[63:32]` | `RW` | High 32 bits of UV metadata base address. Write after `REG_META_BASE_UV_LO` to complete this 64-bit base address. |
| `0x0048` | `REG_TILE_BASE_UV_LO` | `[31:0]` | `tile_base_addr_uv[31:0]` | `RW` | Low 32 bits of UV compressed tile data base address. RGBA formats do not use this address. |
| `0x004c` | `REG_TILE_BASE_UV_HI` | `[31:0]` | `tile_base_addr_uv[63:32]` | `RW` | High 32 bits of UV compressed tile data base address. Write after `REG_TILE_BASE_UV_LO` to complete this 64-bit base address. |
| `0x0050` | `STATUS0` | `[0]` | `frame_active` | `RO` | Current frame is active |
| `0x0050` | `STATUS0` | `[1]` | `meta_busy` | `RO` | Metadata read stage busy |
| `0x0050` | `STATUS0` | `[2]` | `tile_busy` | `RO` | Tile read stage busy |
| `0x0050` | `STATUS0` | `[3]` | `vivo_busy` | `RO` | VIVO decode stage busy |
| `0x0050` | `STATUS0` | `[4]` | `otf_busy` | `RO` | OTF output stage busy |
| `0x0050` | `STATUS0` | `[5]` | `all_stage_idle` | `RO` | All busy inputs are `0`; may be `1` before frame start |
| `0x0050` | `STATUS0` | `[6]` | `frame_idle_done` | `RO` | All stages idle and `frame_active=0`; use with `STATUS1[4]` for completion |
| `0x0054` | `STATUS1` | `[0]` | `meta_done` | `RO` | Metadata stage completed |
| `0x0054` | `STATUS1` | `[1]` | `tile_done` | `RO` | Tile stage completed |
| `0x0054` | `STATUS1` | `[2]` | `reserved` | `RO` | Reserved; reads 0. VIVO completion is not latched as a done condition. |
| `0x0054` | `STATUS1` | `[3]` | `otf_done` | `RO` | OTF stage completed |
| `0x0054` | `STATUS1` | `[4]` | `frame_done` | `RO` | Full-frame completion flag. This is the primary software polling bit. |
| `0x0054` | `STATUS1` | `[8:5]` | `stage_seen_busy` | `RO` | `{otf_seen, vivo_seen, tile_seen, meta_seen}` |
| `0x0058` | `STATUS2` | `[6:0]` | `vivo_idle_bits` | `RO` | Raw VIVO idle bitmap |
| `0x005c` | `STATUS3` | `[6:0]` | `vivo_error_bits` | `RO` | Raw VIVO error bitmap |
| `0x0060` | `IRQ_CTRL` | `[0]` | `irq_enable` | `RW` | IRQ enable. Reset value is `1`. |
| `0x0060` | `IRQ_CTRL` | `[1]` | `irq_clear` | `W1P` | Write `1` to generate an IRQ clear pulse in AXI clock domain |
| `0x0060` | `IRQ_CTRL` | `[2]` | `irq_pending` | `RO` | Current IRQ pending status |
| `0x0060` | `IRQ_CTRL` | `[3]` | `irq_error_pending` | `RO` | Error IRQ pending status |
| `0x0060` | `IRQ_CTRL` | `[4]` | `irq_correct_pending` | `RO` | Correct/frame IRQ pending status |
| `0x0060` | `IRQ_CTRL` | `[5]` | `start` | `W1P` | Write `1` after one full input address group has been configured. Readback is `0`. |
| `0x0064` | `STATUS4` | `[2:0]` | `irq_status` | `RO` | Bit0 any IRQ, bit1 error IRQ, bit2 correct IRQ |
| `0x0068` | `STAT_META` | `[31:0]` | `stat_meta_tile_cnt` | `RO` | Metadata valid tile count |
| `0x006c` | `STAT_TILE` | `[31:0]` | `stat_tile_addr_cnt` | `RO` | Tile address valid tile count |
| `0x0070` | `STAT_OTF_TILE` | `[31:0]` | `stat_otf_tile_cnt` | `RO` | Tile-to-OTF accepted tile count |
| `0x0074` | `STAT_OTF_LINE` | `[31:0]` | `stat_otf_line_cnt` | `RO` | OTF output line count |
| `0x0078` | `STAT_OTF_DE` | `[31:0]` | `stat_otf_de_cnt` | `RO` | OTF output `de && ready` beat count |

Decoder completion polling:

```text
poll_until((read(0x0054) & (1 << 4)) != 0);  // STATUS1.frame_done
poll_until((read(0x0050) & (1 << 6)) != 0);  // STATUS0.frame_idle_done
```

## Encoder Register Map

Module: `ubwc_enc_apb_reg_blk`

The encoder now uses `IRQ_CTRL[5]` as the APB start token. Software should program one output address group, write `IRQ_CTRL[5]=1`, then send the matching upstream OTF frame. Address writes only queue addresses; they no longer start a frame by themselves.

Recommended configuration order:

1. Program `TILE_CFG1`, then `TILE_CFG0`.
2. Program tile and metadata base addresses.
3. Program `ENC_CI_CFG1/2/3`, then `ENC_CI_CFG0`.
4. Program `OTF_CFG1/2/3`, `META_ACTIVE_SIZE`, and `META_PITCH`, then `OTF_CFG0`.
5. Write `IRQ_CTRL[5]=1`, then start sending `i_otf_*`.

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
| `0x002c` | `OTF_CFG3` | `RW` | `0x0000_0000` | Y/UV tile columns |
| `0x0030` | `META_BASE_Y_LO` | `RW` | `0x0000_0000` | Y metadata base address low |
| `0x0034` | `META_BASE_Y_HI` | `RW` | `0x0000_0000` | Y metadata base address high |
| `0x0038` | `TILE_BASE_Y_LO` | `RW` | `0x0000_0000` | Y compressed-data base address low |
| `0x003c` | `TILE_BASE_Y_HI` | `RW` | `0x0000_0000` | Y compressed-data base address high |
| `0x0040` | `META_BASE_UV_LO` | `RW` | `0x0000_0000` | UV metadata base address low |
| `0x0044` | `META_BASE_UV_HI` | `RW` | `0x0000_0000` | UV metadata base address high |
| `0x0048` | `TILE_BASE_UV_LO` | `RW` | `0x0000_0000` | UV compressed-data base address low |
| `0x004c` | `TILE_BASE_UV_HI` | `RW` | `0x0000_0000` | UV compressed-data base address high |
| `0x0050` | `META_ACTIVE_SIZE` | `RW` | `0x0000_0000` | Metadata active width/height |
| `0x0054` | `META_PITCH` | `RW` | `0x0000_0000` | Metadata plane pitch in bytes |
| `0x0058` | `STATUS0` | `RO` | dynamic | Encoder live status |
| `0x005c` | `STATUS1` | `RO` | dynamic | Stage done bitmap |
| `0x0060` | `IRQ_CTRL` | `RW/W1P` | `0x0000_0001` | IRQ enable, clear, start pulse, and pending status |

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
| `0x002c` | `OTF_CFG3` | `[15:0]` | `y_tile_cols` | `RW` | Y tile column count; RGBA formats use this field for RGBA tile columns |
| `0x002c` | `OTF_CFG3` | `[31:16]` | `uv_tile_cols` | `RW` | UV tile column count; RGBA formats write 0 |
| `0x0030` | `META_BASE_Y_LO` | `[31:0]` | `meta_y_base_addr[31:0]` | `RW` | Low 32 bits of Y metadata base address. RGBA formats use this slot for RGBA metadata. |
| `0x0034` | `META_BASE_Y_HI` | `[31:0]` | `meta_y_base_addr[63:32]` | `RW` | High 32 bits of Y metadata base address |
| `0x0038` | `TILE_BASE_Y_LO` | `[31:0]` | `y_base_addr[31:0]` | `RW` | Low 32 bits of Y compressed-data base address. RGBA formats use this slot for RGBA compressed data. |
| `0x003c` | `TILE_BASE_Y_HI` | `[31:0]` | `y_base_addr[63:32]` | `RW` | High 32 bits of Y compressed-data base address |
| `0x0040` | `META_BASE_UV_LO` | `[31:0]` | `meta_uv_base_addr[31:0]` | `RW` | Low 32 bits of UV metadata base address; RGBA formats write 0 |
| `0x0044` | `META_BASE_UV_HI` | `[31:0]` | `meta_uv_base_addr[63:32]` | `RW` | High 32 bits of UV metadata base address |
| `0x0048` | `TILE_BASE_UV_LO` | `[31:0]` | `uv_base_addr[31:0]` | `RW` | Low 32 bits of UV compressed-data base address; RGBA formats write 0 |
| `0x004c` | `TILE_BASE_UV_HI` | `[31:0]` | `uv_base_addr[63:32]` | `RW` | High 32 bits of UV compressed-data base address. Address set becomes eligible only after software writes `IRQ_CTRL[5]=1`. |
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
| `0x0060` | `IRQ_CTRL` | `[3]` | `irq_correct_pending` | `RO` | Correct/frame IRQ pending status |
| `0x0060` | `IRQ_CTRL` | `[4]` | `irq_error_pending` | `RO` | Error IRQ pending status |
| `0x0060` | `IRQ_CTRL` | `[5]` | `start` | `W1P` | Write `1` after one full output address group has been configured. Readback is `0`. |

Encoder completion hint:

```text
write(0x0060, (1 << 5) | irq_enable);
start_otf_input_stream();
poll_until((read(0x0058) & (1 << 0)) != 0);  // STATUS0.enc_idle
check((read(0x0058) & 0x0000007e) == 0);     // no error bits
```

The current encoder RTL exposes live status bits. If the integration needs a sticky software completion flag, add one in RTL or use an external frame-output/activity monitor.
