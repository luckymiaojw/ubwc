# UBWC Wrapper Usage Guide

This document applies to the following two top-level files:

- `ubwc_enc/ubwc_enc_wrapper_top.sv`
- `ubwc_dec_wrapper_top.v`

Additional output file:

- `docs/ubwc_reg_tables.xlsx`
- `docs/ubwc_enc_reg_table.csv`
- `docs/ubwc_dec_reg_table.csv`
- `scripts/gen_ubwc_reg_table_xlsx.py`

Note: the file you mentioned `ubwc_enc_wrapper_top.v`, is actually named in this repository as `ubwc_enc/ubwc_enc_wrapper_top.sv`.

## 1. ubwc_enc_wrapper_top Usage Guide

### 1.1 Module Responsibilities

`ubwc_enc_wrapper_top.sv`  data flow is:

- The APB side writes encoder configuration.
- OTF input enters from `i_otf_*` into `ubwc_enc_otf_to_tile`.
- Externally provided `bank0/bank1` SRAM SRAM is used in the middle to organize lines into tiles.
- `ubwc_enc_vivo_top` handles UBWC encoding.
- Main image data and metadata are output through the AXI write port.

The APB side of this wrapper only handles configuration and does not provide an explicit `start` bit.

### 1.2 Required Register Groups

- Tile address related:`0x0008 REG_TILE_CFG0`, `0x000c REG_TILE_CFG1`
- Encoder CI related:`0x0010 REG_ENC_CI_CFG0` ~ `0x001c REG_ENC_CI_CFG3`
- OTF input related:`0x0020 REG_OTF_CFG0` ~ `0x002c REG_OTF_CFG3`
- Main-image output address:`0x0030` ~ `0x003c`
- Metadata output address:`0x0040` ~ `0x004c`
- Metadata active area:`0x0050 REG_META_ACTIVE_SIZE`

### 1.3 Recommended Configuration Order

The current RTL has several designs that emit a valid pulse when a specific register is written, so the order should be fixed:

1. Write `REG_TILE_CFG1 (0x000c)`, then write `REG_TILE_CFG0 (0x0008)`.
2. Write the main-image/metadata base address.
3. Write `REG_ENC_CI_CFG1/2/3`, write last `REG_ENC_CI_CFG0 (0x0010)`.
4. Write `REG_OTF_CFG1/2/3` and `REG_META_ACTIVE_SIZE (0x0050)`, write last `REG_OTF_CFG0 (0x0020)`.

The corresponding testbench uses the same actual order because:

- Writing `REG_TILE_CFG0` triggers `o_tile_addr_gen_cfg_vld`
- Writing `REG_ENC_CI_CFG0` triggers `o_enc_ci_vld`
- Writing `REG_OTF_CFG0` triggers `o_otf_cfg_vld`

Among them, `tile_addr_gen_cfg_vld` is indeed used inside the wrapper;`o_enc_ci_vld` and `o_otf_cfg_vld` in the current `ubwc_enc_wrapper_top.sv` is not further propagated as a startup condition, so they are more like"compatibility-reserved pulses".

### 1.4 Startup Method

`ubwc_enc_wrapper_top.sv` has no separate"start-encoding"register.

The real startup conditions are:

- APB configuration has already been written
- The upstream source starts sending one frame of OTF input
- `o_otf_ready` successfully handshakes with the upstream source

In other words, encoding starts from the input video stream itself, not from writing another APB `start` bit.

The minimal flow can be understood as:

```text
1. Write registers
2. The upstream source sends i_otf_vsync / i_otf_hsync / i_otf_de / i_otf_data
3. The wrapper starts tiling, UBWC encoding, and AXI writeback
```

Example minimal APB configuration order:

```text
write(0x000c, tile_cfg1);
write(0x0008, tile_cfg0);

write(0x0030, tile_base_y_lo);
write(0x0034, tile_base_y_hi);
write(0x0038, tile_base_uv_lo);
write(0x003c, tile_base_uv_hi);
write(0x0040, meta_base_y_lo);
write(0x0044, meta_base_y_hi);
write(0x0048, meta_base_uv_lo);
write(0x004c, meta_base_uv_hi);

write(0x0014, enc_ci_cfg1);
write(0x0018, enc_ci_cfg2);
write(0x001c, enc_ci_cfg3);
write(0x0010, enc_ci_cfg0);

write(0x0024, otf_cfg1);
write(0x0028, otf_cfg2);
write(0x002c, otf_cfg3);
write(0x0050, meta_active_size);
write(0x0020, otf_cfg0);

start_otf_input_stream();
```

### 1.5 Completion Detection

Pay special attention here:current `ubwc_enc_apb_reg_blk.v` exposes `REG_STATUS0 (0x0058)`:

- `bit0`: `enc_idle`
- `bit1`: `enc_error`
- `bit2`: `otf_to_tile_busy`
- `bit3`: `otf_to_tile_overflow`
- `bit4`: `otf_err_bline`
- `bit5`: `otf_err_bframe`
- `bit6`: `meta_err_0`, currently tied low
- `bit7`: `meta_err_1`, currently tied low
- `bit8`: `meta_frame_done`, currently tied low

These are live status bits, not sticky completion bits.

There are two safer completion-detection methods in the current version:

1. Simulation/integration method
   The upstream source confirms the input frame has been fully sent, then observe that the AXI write channel has no new `AW/W` activity for a period of time, or directly observe internal `enc_idle`
2. Production-driver method
   Poll `REG_STATUS0`, especially `enc_idle` plus error bits; add a sticky frame-done bit later if dec-style completion polling is required

The testbench uses this detection idea:

- The input source `otf_done` has arrived
- Then wait for a"no-output-activity"window
- In multi-frame scenarios, make sure the wrapper returns to idle before starting the next frame

So if you are writing a software driver, use `REG_STATUS0 (0x0058)` for basic live completion/error observation.

## 2. ubwc_dec_wrapper_top Usage Guide

### 2.1 Module Responsibilities

`ubwc_dec_wrapper_top.v`  data flow is:

- The APB side writes decoder configuration
- Reads metadata and tile data through AXI
- `ubwc_dec_vivo_top` performs UBWC decoding
- `ubwc_dec_tile_to_otf` reorganizes the output into an OTF video stream
- `o_otf_*` outputs the final video

It also depends on two external ping-pong SRAM blocks:

- `o_otf_sram_a_* / i_otf_sram_a_rdata`
- `o_otf_sram_b_* / i_otf_sram_b_rdata`

### 2.2 Required Register Groups

- Tile configuration:`0x0008`, `0x000c`, `0x0010`
- VIVO configuration:`0x0014`
- Metadata configuration:`0x0018` ~ `0x002c`
- OTF output timing:`0x0030` ~ `0x0040`
- Tile base address:`0x0044` ~ `0x0050`
- Status registers:`0x0054`, `0x0058`

### 2.3 Recommended Configuration Order

Recommended write order:

1. Write `TILE_CFG0/1/2`
2. Write `TILE_BASE0/1/2/3`
3. Write `VIVO_CFG`
4. Write `META_CFG1/2/3/4/5`
5. Write `OTF_CFG0/1/2/3/4`
6. write last `META_CFG0`, while setting `start` to 1

The key point is that `META_CFG0[0]` is not a normal hold bit; it is a start pulse bit.

### 2.4 Startup Method

`ubwc_dec_wrapper_top.v` starts with the final write to `META_CFG0 (0x0018)`:

```text
write(0x0018, (base_format << 4) | 1);
```

Meaning:

- `bit[0] = 1`:Trigger one start
- `bit[8:4]`:Write at the same time `meta_base_format`

RTL behavior:

- The APB side writes `META_CFG0[0]=1`
- Internal `r_meta_start_toggle` toggles
- generates in the AXI clock domain `frame_start_pulse_axi`
- Metadata read, tile read, VIVO decode, and tile_to_otf output all start together

To run multiple frames continuously, write `META_CFG0[0]=1` once again for each frame.

### 2.5 Completion Detection

This `dec` version already has complete status registers, so software can poll directly.

Recommended detection method:

1. Issue one start first
2. Poll `STATUS1[4] == 1`
3. Also confirm `STATUS0[6] == 1`

The meanings of these two bits are:

- `STATUS1[4] = frame_done`
  This frame has really completed, and this bit is cleared on the next start
- `STATUS0[6] = frame_idle_done`
  All current stages are not busy, and `frame_active=0`

It is not recommended to only check `STATUS0[5]` or `STATUS0[6]`, because they may also be 1 before startup; the safest method is:

- Use an explicit start as the boundary
- ThenPoll `STATUS1[4]`
- Finally use `STATUS0[6]` to confirm the pipeline is fully idle

For video-stream-side detection, you can also use `o_otf_de` valid output to count up to `H_ACT x V_ACT`, but the software-driver layer is better served by direct status-register polling.

Minimal configuration and startup example:

```text
write(0x0008, tile_cfg0);
write(0x000c, tile_cfg1);
write(0x0010, tile_cfg2);

write(0x0044, tile_base_rgba_uv_lo);
write(0x0048, tile_base_rgba_uv_hi);
write(0x004c, tile_base_y_lo);
write(0x0050, tile_base_y_hi);

write(0x0014, vivo_cfg);

write(0x001c, meta_base_rgba_uv_lo);
write(0x0020, meta_base_rgba_uv_hi);
write(0x0024, meta_base_y_lo);
write(0x0028, meta_base_y_hi);
write(0x002c, meta_tile_num);

write(0x0030, otf_cfg0);
write(0x0034, otf_cfg1);
write(0x0038, otf_cfg2);
write(0x003c, otf_cfg3);
write(0x0040, otf_cfg4);

write(0x0018, (base_format << 4) | 1);

poll_until((read(0x0058) & (1 << 4)) != 0);
poll_until((read(0x0054) & (1 << 6)) != 0);
```

## 3. 128x128 RGBA8888 Complete Configuration Example

### 3.1 Part 1: Image Information, OTF Configuration, and Flow Information

The following is a minimal bring-up example based on the **current RTL**. The target image is:

- Format:`RGBA8888`
- Resolution:`128 x 128`
- Default assumptions: no lossy mode, `highest_bank_bit=16`, `lvl1/lvl2/lvl3 = 0/1/1`, `bank_spread=1`

First convert these image parameters into the geometry required by the current implementation:

- `RGBA8888` uses `16 x 4 tile`
- `tile_x_numbers = ceil(128 / 16) = 8`
- `tile_y_numbers = ceil(128 / 4) = 32`
- `tile_pitch(bytes) = 128 * 4 = 512`
- `stored_height = 128`, because `128` is already `4-line` aligned

Suggested example addresses:

- Encoder output main-image base address:`0x0000_0000_8100_0000`
- Encoder output metadata base address:`0x0000_0000_8200_0000`
- Decoder input main-image base address:`0x0000_0000_8100_0000`
- Decoder input metadata base address:`0x0000_0000_8200_0000`

Note one **current RTL naming difference**:

- `enc` side runs `RGBA8888` the main image and metadata both use `Y base / META_Y base`
- `dec` side runs `RGBA8888` the main image and metadata both use `RGBA_UV base / META_RGBA_UV base`

that is, although this is the same single-plane `RGBA8888`, `enc` and `dec` the base-register names used are not fully symmetric.

#### 3.1.1 ubwc_enc_wrapper_top OTF Configuration and Flow

OTF-related information used in this example:

- `format = 0`, meaning `RGBA8888`
- `width = 128`
- `height = 128`
- `tile_w = 16`
- `tile_h = 4`
- `a_tile_cols = 8`
- `b_tile_cols = 0`
- `meta_active_width_px = 128`
- `meta_active_height_px = 128`

`enc` startup flow is:

```text
1. Write the TILE configuration
2. Write the main-image and metadata output addresses
3. Write the CI configuration
4. Write the OTF configuration
5. Finally start sending one frame of i_otf_* input
```

The most important points are:

- `enc` has no separate APB `start`
- startup relies on the input OTF video stream handshake
- When the upstream source starts sending `i_otf_vsync / i_otf_hsync / i_otf_de / i_otf_data`, and `o_otf_ready` successfully handshakes, encoding starts

#### 3.1.2 ubwc_dec_wrapper_top OTF Configuration and Flow

This example uses a simplified OTF timing setup for bring-up:

- `img_width = 128`
- `format = 0`, meaning `RGBA8888`
- `H_TOTAL = 160`
- `H_SYNC = 4`
- `H_BP = 8`
- `H_ACT = 128`
- `V_TOTAL = 140`
- `V_SYNC = 2`
- `V_BP = 4`
- `V_ACT = 128`

`dec` startup flow is:

```text
1. Write the TILE configuration
2. Write the tile base address
3. Write the VIVO configuration
4. Write the metadata configuration
5. Write the OTF configuration
6. write last META_CFG0[0]=1 to issue start
7. Poll STATUS1[4] and STATUS0[6]
```

The most important points are:

- `dec` must be started by writing `META_CFG0[0]=1` last
- For completion, check `STATUS1[4] = frame_done`
- then check `STATUS0[6] = frame_idle_done`

#### 3.1.3 Easy-to-Miss Points in This Example

- `RGBA8888` is `16x4 tile`, not `32x8 tile`
- `tile_pitch` is measured in **bytes**, `128x128 RGBA8888` needs `512`
- For `RGBA8888` on `enc`, the current address-selection logic uses `Y base / META_Y base`
- For `RGBA8888` on `dec`, the current address-selection logic uses `RGBA_UV base / META_RGBA_UV base`
- `dec` must be started by writing `META_CFG0[0]=1` last
- `enc` has no APB start, it starts from the OTF input stream

### 3.2 Part 2: Register Read/Write Information

#### 3.2.1 ubwc_enc_wrapper_top Register Writes

Key register values used in this example:

- `REG_TILE_CFG0 = 0x0001_100d`
  - `enc_ubwc_en = 1`
  - `lvl1/lvl2/lvl3 = 0/1/1`
  - `highest_bank_bit = 16`
  - `bank_spread_en = 1`
- `REG_TILE_CFG1 = 0x0200_0001`
  - `four_line_format = 1`
  - `is_lossy_rgba_2_1_format = 0`
  - `tile_pitch = 512`
- `REG_ENC_CI_CFG0 = 0x0000_0701`
  - `input_type = 1`
  - `alen = 7`
  - `format = 0` (`RGBA8888`)
  - forced PCM is generated dynamically by the OTF path
- `REG_ENC_CI_CFG1/2/3 = 0`
- `REG_OTF_CFG0 = 0x0000_0000`
- `REG_OTF_CFG1 = 0x0080_0080`
- `REG_OTF_CFG2 = 0x0004_0010`
- `REG_OTF_CFG3 = 0x0000_0008`
- `REG_META_ACTIVE_SIZE = 0x0080_0080`

Recommended register write order:

```text
1. Write REG_TILE_CFG1, then write REG_TILE_CFG0
2. Write the main-image/metadata base address
3. Write REG_ENC_CI_CFG1/2/3, write last REG_ENC_CI_CFG0
4. Write REG_OTF_CFG1/2/3 and REG_META_ACTIVE_SIZE, write last REG_OTF_CFG0
```

An APB write sequence that can be copied directly:

```text
write(0x000c, 0x02000001);  // REG_TILE_CFG1
write(0x0008, 0x0001100d);  // REG_TILE_CFG0

write(0x0030, 0x81000000);  // REG_TILE_BASE_Y_LO
write(0x0034, 0x00000000);  // REG_TILE_BASE_Y_HI
write(0x0038, 0x00000000);  // REG_TILE_BASE_UV_LO
write(0x003c, 0x00000000);  // REG_TILE_BASE_UV_HI

write(0x0040, 0x82000000);  // REG_META_BASE_Y_LO
write(0x0044, 0x00000000);  // REG_META_BASE_Y_HI
write(0x0048, 0x00000000);  // REG_META_BASE_UV_LO
write(0x004c, 0x00000000);  // REG_META_BASE_UV_HI

write(0x0014, 0x00000000);  // REG_ENC_CI_CFG1
write(0x0018, 0x00000000);  // REG_ENC_CI_CFG2
write(0x001c, 0x00000000);  // REG_ENC_CI_CFG3
write(0x0010, 0x00000701);  // REG_ENC_CI_CFG0

write(0x0024, 0x00800080);  // REG_OTF_CFG1
write(0x0028, 0x00040010);  // REG_OTF_CFG2
write(0x002c, 0x00000008);  // REG_OTF_CFG3
write(0x0050, 0x00800080);  // REG_META_ACTIVE_SIZE
write(0x0020, 0x00000000);  // REG_OTF_CFG0
```

#### 3.2.2 ubwc_dec_wrapper_top Register Writes

Key register values used in this example:

- `TILE_CFG0 = 0x0000_0706`
  - `lvl1/lvl2/lvl3 = 0/1/1`
  - `highest_bank_bit = 16`
  - `bank_spread_en = 1`
  - `4line_format = 1`
  - `lossy_rgba_2_1 = 0`
- `TILE_CFG1 = 0x0000_0200`
  - `tile_pitch = 512`
- `TILE_CFG2 = 0x0000_000f`
- `VIVO_CFG = 0x0000_0001`
- `META_CFG5 = 0x0020_0008`
  - `meta_tile_x_numbers = 8`
  - `meta_tile_y_numbers = 32`
- `OTF_CFG0 = 0x0000_0080`
- `OTF_CFG1 = 0x0004_00a0`
- `OTF_CFG2 = 0x0080_0008`
- `OTF_CFG3 = 0x0002_008c`
- `OTF_CFG4 = 0x0080_0004`

Recommended register write order:

```text
1. Write TILE_CFG0/1/2
2. Write TILE_BASE0/1/2/3
3. Write VIVO_CFG
4. Write META_CFG1/2/3/4/5
5. Write OTF_CFG0/1/2/3/4
6. write last META_CFG0 = (base_format << 4) | 1
7. Poll STATUS1[4], then poll STATUS0[6]
```

An APB write sequence that can be copied directly:

```text
write(0x0008, 0x00000706);  // TILE_CFG0
write(0x000c, 0x00000200);  // TILE_CFG1
write(0x0010, 0x0000000f);  // TILE_CFG2
write(0x0014, 0x00000001);  // VIVO_CFG

write(0x001c, 0x82000000);  // META_CFG1
write(0x0020, 0x00000000);  // META_CFG2
write(0x0024, 0x00000000);  // META_CFG3
write(0x0028, 0x00000000);  // META_CFG4
write(0x002c, 0x00200008);  // META_CFG5

write(0x0030, 0x00000080);  // OTF_CFG0
write(0x0034, 0x000400a0);  // OTF_CFG1
write(0x0038, 0x00800008);  // OTF_CFG2
write(0x003c, 0x0002008c);  // OTF_CFG3
write(0x0040, 0x00800004);  // OTF_CFG4

write(0x0044, 0x81000000);  // TILE_BASE0
write(0x0048, 0x00000000);  // TILE_BASE1
write(0x004c, 0x00000000);  // TILE_BASE2
write(0x0050, 0x00000000);  // TILE_BASE3

write(0x0018, 0x00000001);  // META_CFG0: base_format=RGBA8888, start=1

poll_until((read(0x0058) & (1 << 4)) != 0);  // STATUS1.frame_done
poll_until((read(0x0054) & (1 << 6)) != 0);  // STATUS0.frame_idle_done
```

## 4. Current Register Table

The following is a concise table based on the **current RTL**; see the detailed bit fields below:

- [ubwc_enc_reg_table.csv](/Users/magic.jw/Desktop/ubwc_dec/docs/ubwc_enc_reg_table.csv)
- [ubwc_dec_reg_table.csv](/Users/magic.jw/Desktop/ubwc_dec/docs/ubwc_dec_reg_table.csv)

### 4.1 ubwc_enc_wrapper_top Current Register Table

| Address | Register Name | Key Fields / Purpose | Notes |
|---|---|---|---|
| `0x0000` | `REG_VERSION` | Version number | Read-only |
| `0x0004` | `REG_DATE` | RTL date | Read-only |
| `0x0008` | `REG_TILE_CFG0` | `enc_ubwc_en`, `lvl1/2/3`, `highest_bank_bit`, `bank_spread_en` | Writing this register emits `o_tile_addr_gen_cfg_vld` |
| `0x000c` | `REG_TILE_CFG1` | `four_line_format`, `is_lossy_rgba_2_1_format`, `tile_pitch` | Recommended to write this register first |
| `0x0010` | `REG_ENC_CI_CFG0` | `input_type`, `alen`, `format` | `forced_pcm` is generated dynamically by the OTF path |
| `0x0014` | `REG_ENC_CI_CFG1` | `sb`, `lossy` | Other bits may default to `0` |
| `0x0018` | `REG_ENC_CI_CFG2` | `ubwc_cfg_0 ~ ubwc_cfg_9` | This example may write `0` |
| `0x001c` | `REG_ENC_CI_CFG3` | `ubwc_cfg_10 ~ ubwc_cfg_11` | This example may write `0` |
| `0x0020` | `REG_OTF_CFG0` | `otf_cfg_format` | Writing this register emits `o_otf_cfg_vld` |
| `0x0024` | `REG_OTF_CFG1` | `width`, `height` | Pixel units |
| `0x0028` | `REG_OTF_CFG2` | `tile_w`, `tile_h` | Pixel units |
| `0x002c` | `REG_OTF_CFG3` | `a_tile_cols`, `b_tile_cols` | `RGBA8888` is commonly `a=tile_cols, b=0` |
| `0x0030` | `REG_TILE_BASE_Y_LO` | Low 32 bits of the main-image base address | Current `RGBA8888` uses this base |
| `0x0034` | `REG_TILE_BASE_Y_HI` | High 32 bits of the main-image base address |  |
| `0x0038` | `REG_TILE_BASE_UV_LO` | Low 32 bits of the UV base address | Single-plane `RGBA8888` can write `0` |
| `0x003c` | `REG_TILE_BASE_UV_HI` | High 32 bits of the UV base address | Single-plane `RGBA8888` can write `0` |
| `0x0040` | `REG_META_BASE_Y_LO` | Low 32 bits of the metadata base address | Current `RGBA8888` uses this base |
| `0x0044` | `REG_META_BASE_Y_HI` | High 32 bits of the metadata base address |  |
| `0x0048` | `REG_META_BASE_UV_LO` | Low 32 bits of the UV metadata base address | Single-plane `RGBA8888` can write `0` |
| `0x004c` | `REG_META_BASE_UV_HI` | High 32 bits of the UV metadata base address | Single-plane `RGBA8888` can write `0` |
| `0x0050` | `REG_META_ACTIVE_SIZE` | `active_width_px`, `active_height_px` | Writing `0` means using the full frame |
| `0x0054` | `REG_META_PITCH` | `meta_data_plane_pitch` | Metadata pitch in bytes, separate from pixel-data pitch |
| `0x0058` | `REG_STATUS0` | `enc/otf/meta` live status bits | Metadata bits are currently tied low |

### 4.2 ubwc_dec_wrapper_top Current Register Table

| Address | Register Name | Key Fields / Purpose | Notes |
|---|---|---|---|
| `0x0000` | `REG_VERSION` | Version number | Read-only |
| `0x0004` | `REG_DATE` | RTL date | Read-only |
| `0x0008` | `TILE_CFG0` | `lvl1/2/3`, `highest_bank_bit`, `bank_spread_en`, `4line_format`, `lossy_rgba_2_1` | The `RGBA8888` example writes `0x00000706` |
| `0x000c` | `TILE_CFG1` | `tile_pitch` | Unit is bytes |
| `0x0010` | `TILE_CFG2` | `ci_input_type`, `ci_sb`, `ci_lossy`, `ci_alpha_mode` | This example keeps the TB default value |
| `0x0014` | `VIVO_CFG` | `vivo_ubwc_en`, `vivo_sreset` | Usually `vivo_ubwc_en=1` |
| `0x0018` | `META_CFG0` | `start(W1P)`, `meta_base_format` | Write last; `bit0` is the start pulse |
| `0x001c` | `META_CFG1` | `meta_base_addr_rgba_y[31:0]` | `RGBA8888/NV12/P010 Y` uses this base |
| `0x0020` | `META_CFG2` | `meta_base_addr_rgba_y[63:32]` |  |
| `0x0024` | `META_CFG3` | `meta_base_addr_uv[31:0]` | `NV12/P010 UV` uses this base |
| `0x0028` | `META_CFG4` | `meta_base_addr_uv[63:32]` |  |
| `0x002c` | `META_CFG5` | `meta_tile_x_numbers`, `meta_tile_y_numbers` | This example uses `8 x 32` |
| `0x0030` | `OTF_CFG0` | `img_width`, `format` | `format=0` means `RGBA8888` |
| `0x0034` | `OTF_CFG1` | `h_total`, `h_sync` | OTF timing |
| `0x0038` | `OTF_CFG2` | `h_bp`, `h_act` | OTF timing |
| `0x003c` | `OTF_CFG3` | `v_total`, `v_sync` | OTF timing |
| `0x0040` | `OTF_CFG4` | `v_bp`, `v_act` | OTF timing |
| `0x0044` | `TILE_BASE0` | `tile_base_addr_rgba_uv[31:0]` | `RGBA8888` uses this base |
| `0x0048` | `TILE_BASE1` | `tile_base_addr_rgba_uv[63:32]` |  |
| `0x004c` | `TILE_BASE2` | `tile_base_addr_y[31:0]` | `NV12/P010 Y` uses this base |
| `0x0050` | `TILE_BASE3` | `tile_base_addr_y[63:32]` |  |
| `0x0054` | `STATUS0` | `frame_active`, `meta/tile/vivo/otf_busy`, `frame_idle_done` | Recommended to use together with `STATUS1`  |
| `0x0058` | `STATUS1` | `meta_done`, `tile_done`, `vivo_done`, `otf_done`, `frame_done` | `bit4 frame_done` is the best polling bit |

## 5. Summary of Differences Between the Two Wrappers

- `enc`: the APB side mainly provides configuration registers plus a basic live `REG_STATUS0`
- `dec`: the APB side has both configuration registers and complete `STATUS0/STATUS1` registers
- `enc` starts from"the input frame beginning to arrive"
- `dec` starts from"writing `META_CFG0[0]=1`"
- `enc` can add sticky frame-done/status registers later for long-term software-driver use
- `dec` can already poll registers directly for completion
