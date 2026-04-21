## 3. 128x128 RGBA8888 完整配置例子

### 3.1 第一段：图像信息、OTF 配置信息、流程信息

下面给一个基于**当前 RTL**的最小 bring-up 例子，目标图像是：

- 格式：`RGBA8888`
- 分辨率：`128 x 128`
- 默认假设：无 lossy，`highest_bank_bit=16`，`lvl1/lvl2/lvl3 = 0/1/1`，`bank_spread=1`

先把这组图像参数换成当前实现需要的几何量：

- `RGBA8888` 在当前实现里使用 `16 x 4 tile`
- `tile_x_numbers = ceil(128 / 16) = 8`
- `tile_y_numbers = ceil(128 / 4) = 32`
- `pitch(bytes) = 128 * 4 = 512`
- `stored_height = 128`，因为 `128` 本身已经是 `4-line` 对齐

建议的示例地址：

- 编码输出主图基地址：`0x0000_0000_8100_0000`
- 编码输出 metadata 基地址：`0x0000_0000_8200_0000`
- 解码输入主图基地址：`0x0000_0000_8100_0000`
- 解码输入 metadata 基地址：`0x0000_0000_8200_0000`

注意一个**当前 RTL 的命名差异**：

- `enc` 侧做 `RGBA8888` 时，主图和 metadata 都走 `Y base / META_Y base`
- `dec` 侧做 `RGBA8888` 时，主图和 metadata 都走 `RGBA_UV base / META_RGBA_UV base`

也就是说，同样是单平面 `RGBA8888`，`enc` 和 `dec` 走的 base 寄存器名字并不完全对称。

#### 3.1.1 ubwc_enc_wrapper_top 的 OTF 配置和流程

本例使用的 OTF 相关信息：

- `format = 0`，表示 `RGBA8888`
- `width = 128`
- `height = 128`
- `tile_w = 16`
- `tile_h = 4`
- `a_tile_cols = 8`
- `b_tile_cols = 0`
- `meta_active_width_px = 128`
- `meta_active_height_px = 128`

`enc` 的启动流程是：

```text
1. 先写 TILE 配置
2. 再写主图和 metadata 输出地址
3. 再写 CI 配置
4. 再写 OTF 配置
5. 最后开始送入一帧 i_otf_* 输入
```

这里最重要的点是：

- `enc` 没有单独的 APB `start`
- 最后是靠输入 OTF 视频流开始握手来启动
- 当上游开始送 `i_otf_vsync / i_otf_hsync / i_otf_de / i_otf_data`，并且与 `o_otf_ready` 握手成功后，就开始编码

#### 3.1.2 ubwc_dec_wrapper_top 的 OTF 配置和流程

本例给一组 bring-up 用的简化 OTF 时序：

- `img_width = 128`
- `format = 0`，表示 `RGBA8888`
- `H_TOTAL = 160`
- `H_SYNC = 4`
- `H_BP = 8`
- `H_ACT = 128`
- `V_TOTAL = 140`
- `V_SYNC = 2`
- `V_BP = 4`
- `V_ACT = 128`

`dec` 的启动流程是：

```text
1. 写 TILE 配置
2. 写 tile base address
3. 写 VIVO 配置
4. 写 metadata 配置
5. 写 OTF 配置
6. 最后写 META_CFG0[0]=1 发起 start
7. 轮询 STATUS1[4] 和 STATUS0[6]
```

这里最重要的点是：

- `dec` 的启动一定是最后写 `META_CFG0[0]=1`
- 结束建议先看 `STATUS1[4] = frame_done`
- 再看 `STATUS0[6] = frame_idle_done`

#### 3.1.3 这个例子里最容易写错的点

- `RGBA8888` 在当前实现里是 `16x4 tile`，不是 `32x8 tile`
- `pitch` 是**字节数**，`128x128 RGBA8888` 要写 `512`
- `enc` 做 `RGBA8888` 时，当前地址选择逻辑走 `Y base / META_Y base`
- `dec` 做 `RGBA8888` 时，当前地址选择逻辑走 `RGBA_UV base / META_RGBA_UV base`
- `dec` 的启动一定是最后写 `META_CFG0[0]=1`
- `enc` 没有 APB start，最后是靠 OTF 输入流启动

### 3.2 第二段：寄存器读写信息

#### 3.2.1 ubwc_enc_wrapper_top 寄存器写法

本例使用的关键寄存器值：

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

推荐写寄存器顺序：

```text
1. 先写 REG_TILE_CFG1，再写 REG_TILE_CFG0
2. 写主图/metadata base address
3. 先写 REG_ENC_CI_CFG1/2/3，最后写 REG_ENC_CI_CFG0
4. 先写 REG_OTF_CFG1/2/3 和 REG_META_ACTIVE_SIZE，最后写 REG_OTF_CFG0
```

一组可直接照抄的 APB 写序列：

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

#### 3.2.2 ubwc_dec_wrapper_top 寄存器写法

本例使用的关键寄存器值：

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

推荐写寄存器顺序：

```text
1. 写 TILE_CFG0/1/2
2. 写 TILE_BASE0/1/2/3
3. 写 VIVO_CFG
4. 写 META_CFG1/2/3/4/5
5. 写 OTF_CFG0/1/2/3/4
6. 最后写 META_CFG0 = (base_format << 4) | 1
7. 轮询 STATUS1[4]，再轮询 STATUS0[6]
```

一组可直接照抄的 APB 写序列：

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