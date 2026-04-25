## 3. Complete 128x128 RGBA8888 Configuration Example

### 3.1 Part 1: Image Information, OTF Configuration, and Flow Information

The following is a minimal bring-up example based on the **current RTL**. The target image is:

- Format: `RGBA8888`
- Resolution: `128 x 128`
- Default assumptions: no lossy mode, `highest_bank_bit=16`, `lvl1/lvl2/lvl3 = 0/1/1`, `bank_spread=1`

First convert these image parameters into the geometry required by the current implementation:

- `RGBA8888` uses a `16 x 4 tile` in the current implementation
- `tile_x_numbers = ceil(128 / 16) = 8`
- `tile_y_numbers = ceil(128 / 4) = 32`
- `pitch(bytes) = 128 * 4 = 512`
- `stored_height = 128`, because `128` is already aligned to `4-line`

Suggested example addresses:

- Encoder output main-image base address: `0x0000_0000_8100_0000`
- Encoder output metadata base address: `0x0000_0000_8200_0000`
- Decoder input main-image base address: `0x0000_0000_8100_0000`
- Decoder input metadata base address: `0x0000_0000_8200_0000`

Note one **current RTL naming difference**:

- On the `enc` side, `RGBA8888` uses `Y base / META_Y base` for both the main image and metadata
- On the `dec` side, `RGBA8888` uses `RGBA_UV base / META_RGBA_UV base` for both the main image and metadata

In other words, although `RGBA8888` is a single-plane format, the base-register names used by `enc` and `dec` are not fully symmetric.

#### 3.1.1 OTF Configuration and Flow for ubwc_enc_wrapper_top

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

The `enc` startup flow is:

```text
1. Write the TILE configuration first
2. Write the main-image and metadata output addresses
3. Write the CI configuration
4. Write the OTF configuration
5. Finally start sending one frame of i_otf_* input
```

The most important points are:

- `enc` has no separate APB `start`
- Startup relies on the input OTF video stream handshake
- Encoding starts when the upstream source begins sending `i_otf_vsync / i_otf_hsync / i_otf_de / i_otf_data` and successfully handshakes with `o_otf_ready`

#### 3.1.2 OTF Configuration and Flow for ubwc_dec_wrapper_top

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

The `dec` startup flow is:

```text
1. Write the TILE configuration
2. Write the tile base address
3. Write the VIVO configuration
4. Write the metadata configuration
5. Write the OTF configuration
6. Finally write META_CFG0[0]=1 to issue start
7. Poll STATUS1[4] and STATUS0[6]
```

The most important points are:

- `dec` must be started by writing `META_CFG0[0]=1` last
- For completion, check `STATUS1[4] = frame_done` first
- Then check `STATUS0[6] = frame_idle_done`

#### 3.1.3 Easy-to-Miss Points in This Example

- `RGBA8888` is `16x4 tile` in the current implementation, not `32x8 tile`
- `pitch` is measured in **bytes**, so `128x128 RGBA8888` needs `512`
- For `RGBA8888` on `enc`, the current address-selection logic uses `Y base / META_Y base`
- For `RGBA8888` on `dec`, the current address-selection logic uses `RGBA_UV base / META_RGBA_UV base`
- `dec` must be started by writing `META_CFG0[0]=1` last
- `enc` has no APB start; it starts from the OTF input stream

### 3.2 Part 2: Register Read/Write Information

#### 3.2.1 Register Writes for ubwc_enc_wrapper_top

Key register values used in this example:

- `REG_TILE_CFG0 = 0x0001_100d`
  - `enc_ubwc_en = 1`
  - `lvl1/lvl2/lvl3 = 0/1/1`
  - `highest_bank_bit = 16`
  - `bank_spread_en = 1`
- `REG_TILE_CFG1 = 0x0200_0001`
  - `four_line_format = 1`
  - `is_lossy_rgba_2_1_format = 0`
  - `pitch = 512`
- `REG_ENC_CI_CFG0 = 0x0000_0701`
  - `input_type = 1`
  - `alen = 7`
  - `format = 0` (`RGBA8888`)
  - `forced_pcm = 0`
- `REG_ENC_CI_CFG1/2/3 = 0`
- `REG_OTF_CFG0 = 0x0000_0000`
- `REG_OTF_CFG1 = 0x0080_0080`
- `REG_OTF_CFG2 = 0x0004_0010`
- `REG_OTF_CFG3 = 0x0000_0008`
- `REG_META_ACTIVE_SIZE = 0x0080_0080`

Recommended register write order:

```text
1. Write REG_TILE_CFG1 first, then REG_TILE_CFG0
2. Write the main-image/metadata base addresses
3. Write REG_ENC_CI_CFG1/2/3 first, then REG_ENC_CI_CFG0 last
4. Write REG_OTF_CFG1/2/3 and REG_META_ACTIVE_SIZE first, then REG_OTF_CFG0 last
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

#### 3.2.2 Register Writes for ubwc_dec_wrapper_top

Key register values used in this example:

- `TILE_CFG0 = 0x0000_0706`
  - `lvl1/lvl2/lvl3 = 0/1/1`
  - `highest_bank_bit = 16`
  - `bank_spread_en = 1`
  - `4line_format = 1`
  - `lossy_rgba_2_1 = 0`
- `TILE_CFG1 = 0x0000_0200`
  - `pitch = 512`
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
6. Finally write META_CFG0 = (base_format << 4) | 1
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
