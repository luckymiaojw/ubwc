# UBWC Wrapper 使用说明

本文对应以下两个顶层文件：

- `ubwc_enc/ubwc_enc_wrapper_top.sv`
- `ubwc_dec_wrapper_top.v`

补充输出文件：

- `docs/ubwc_reg_tables.xlsx`
- `docs/ubwc_enc_reg_table.csv`
- `docs/ubwc_dec_reg_table.csv`
- `scripts/gen_ubwc_reg_table_xlsx.py`

注意：你提到的 `ubwc_enc_wrapper_top.v`，仓库里实际文件名是 `ubwc_enc/ubwc_enc_wrapper_top.sv`。

## 1. ubwc_enc_wrapper_top 使用说明

### 1.1 模块职责

`ubwc_enc_wrapper_top.sv` 的数据流是：

- APB 侧写入编码配置。
- OTF 输入从 `i_otf_*` 进入 `ubwc_enc_otf_to_tile`。
- 中间使用外部 `bank0/bank1` SRAM 做行到tile的整理。
- `ubwc_enc_vivo_top` 负责UBWC编码。
- 主图数据和metadata通过 AXI 写口输出。

这个 wrapper 的 APB 侧只负责“配置”，不提供显式的 `start` 位。

### 1.2 必配寄存器分组

- Tile 地址相关：`0x0008 REG_TILE_CFG0`、`0x000c REG_TILE_CFG1`
- 编码 CI 相关：`0x0010 REG_ENC_CI_CFG0` ~ `0x001c REG_ENC_CI_CFG3`
- OTF 输入相关：`0x0020 REG_OTF_CFG0` ~ `0x002c REG_OTF_CFG3`
- 主图输出地址：`0x0030` ~ `0x003c`
- Metadata 输出地址：`0x0040` ~ `0x004c`
- Metadata 有效区域：`0x0050 REG_META_ACTIVE_SIZE`

### 1.3 推荐配置顺序

当前 RTL 里有几个“写某个寄存器就发一个 valid 脉冲”的设计，所以顺序最好固定：

1. 先写 `REG_TILE_CFG1 (0x000c)`，再写 `REG_TILE_CFG0 (0x0008)`。
2. 写主图/metadata base address。
3. 先写 `REG_ENC_CI_CFG1/2/3`，最后写 `REG_ENC_CI_CFG0 (0x0010)`。
4. 先写 `REG_OTF_CFG1/2/3` 和 `REG_META_ACTIVE_SIZE (0x0050)`，最后写 `REG_OTF_CFG0 (0x0020)`。

对应 testbench 里的实际顺序也是这样写的，原因是：

- 写 `REG_TILE_CFG0` 会触发 `o_tile_addr_gen_cfg_vld`
- 写 `REG_ENC_CI_CFG0` 会触发 `o_enc_ci_vld`
- 写 `REG_OTF_CFG0` 会触发 `o_otf_cfg_vld`

其中 `tile_addr_gen_cfg_vld` 在 wrapper 内部确实被使用；`o_enc_ci_vld` 和 `o_otf_cfg_vld` 在当前 `ubwc_enc_wrapper_top.sv` 里没有继续作为启动条件往下传，所以它们更像“兼容保留脉冲”。

### 1.4 启动方式

`ubwc_enc_wrapper_top.sv` 没有单独的“开始编码”寄存器。

真正的启动条件是：

- APB 配置已经写好
- 上游开始送入一帧 OTF 输入
- `o_otf_ready` 与上游握手成功

也就是说，编码开始依赖输入视频流本身，而不是 APB 再写一个 `start` 位。

最小流程可以理解成：

```text
1. 写寄存器
2. 上游送入 i_otf_vsync / i_otf_hsync / i_otf_de / i_otf_data
3. wrapper 开始做 tile 化、UBWC 编码、AXI 写回
```

一个最小 APB 配置顺序示意：

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

### 1.5 结束判断

这里要特别注意：当前 `ubwc_enc_apb_reg_blk.v` 虽然有这些输入：

- `i_enc_idle`
- `i_enc_error`
- `i_otf_to_tile_busy`
- `i_otf_to_tile_overflow`

但这几个状态并没有被映射到 `PRDATA`，也就是说：

- 当前 APB 版本没有 `STATUS0/STATUS1`
- 软件侧不能只靠读寄存器轮询判断一帧是否结束

当前版本比较稳妥的结束判断方式有两种：

1. 仿真/联调方式
   上游确认输入帧已经送完，再观察 AXI 写通道没有新的 `AW/W` 活动持续一段时间，或者直接观察内部 `enc_idle`
2. 工程化驱动方式
   建议补一个状态寄存器，把 `enc_idle`、`enc_error`、`otf_to_tile_overflow`、AXI outstanding 状态导出来

testbench 里采用的判断思路是：

- 输入源 `otf_done` 已经到达
- 然后等待一段“无输出活动”窗口
- 多帧场景下，必须确认 wrapper 回到 idle 再启动下一帧

所以如果你是做软件驱动，`enc` 这版目前最缺的是“可读完成状态”。

## 2. ubwc_dec_wrapper_top 使用说明

### 2.1 模块职责

`ubwc_dec_wrapper_top.v` 的数据流是：

- APB 侧写入解码配置
- 通过 AXI 读 metadata 和 tile 数据
- `ubwc_dec_vivo_top` 做 UBWC 解码
- `ubwc_dec_tile_to_otf` 把输出重新组织成 OTF 视频流
- `o_otf_*` 输出最终视频

另外它还依赖两块外部 ping-pong SRAM：

- `o_otf_sram_a_* / i_otf_sram_a_rdata`
- `o_otf_sram_b_* / i_otf_sram_b_rdata`

### 2.2 必配寄存器分组

- Tile 配置：`0x0008`、`0x000c`、`0x0010`
- VIVO 配置：`0x0014`
- Metadata 配置：`0x0018` ~ `0x002c`
- OTF 输出时序：`0x0030` ~ `0x0040`
- Tile base address：`0x0044` ~ `0x0050`
- 状态寄存器：`0x0054`、`0x0058`

### 2.3 推荐配置顺序

推荐按下面顺序写：

1. 写 `TILE_CFG0/1/2`
2. 写 `TILE_BASE0/1/2/3`
3. 写 `VIVO_CFG`
4. 写 `META_CFG1/2/3/4/5`
5. 写 `OTF_CFG0/1/2/3/4`
6. 最后写 `META_CFG0`，同时把 `start` 位置 1

这里的关键点是：`META_CFG0[0]` 不是普通保持位，而是启动脉冲位。

### 2.4 启动方式

`ubwc_dec_wrapper_top.v` 的启动动作就是最后一次写 `META_CFG0 (0x0018)`：

```text
write(0x0018, (base_format << 4) | 1);
```

含义是：

- `bit[0] = 1`：触发一次 start
- `bit[8:4]`：同时写入 `meta_base_format`

RTL 行为是：

- APB 侧写 `META_CFG0[0]=1`
- 内部 `r_meta_start_toggle` 翻转
- 到 AXI 时钟域后生成 `frame_start_pulse_axi`
- metadata 读取、tile 读取、vivo 解码、tile_to_otf 输出一起开始跑

如果你要连续跑多帧，每一帧都要重新写一次 `META_CFG0[0]=1`。

### 2.5 结束判断

`dec` 这版已经做了完整的状态寄存器，软件侧可以直接轮询。

推荐判断方法：

1. 先发起一次 start
2. 轮询 `STATUS1[4] == 1`
3. 同时确认 `STATUS0[6] == 1`

这两个位的意义分别是：

- `STATUS1[4] = frame_done`
  这一帧真正完成，且会在下一次 start 时清零
- `STATUS0[6] = frame_idle_done`
  当前所有阶段都不 busy，并且 `frame_active=0`

不建议只看 `STATUS0[5]` 或 `STATUS0[6]`，原因是它们在“还没启动之前”也可能为 1；最稳妥的办法是：

- 用一次明确的 start 作为边界
- 然后轮询 `STATUS1[4]`
- 最后再用 `STATUS0[6]` 确认管线已经彻底空闲

如果是视频流侧判断，也可以按 `o_otf_de` 的有效输出去数满 `H_ACT x V_ACT`，但软件驱动层更建议直接用状态寄存器。

一个最小配置和启动示意：

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
```

## 4. 当前寄存器表

下面是按**当前 RTL**整理的简表，详细位段请继续看：

- [ubwc_enc_reg_table.csv](/Users/magic.jw/Desktop/ubwc_dec/docs/ubwc_enc_reg_table.csv)
- [ubwc_dec_reg_table.csv](/Users/magic.jw/Desktop/ubwc_dec/docs/ubwc_dec_reg_table.csv)

### 4.1 ubwc_enc_wrapper_top 当前寄存器表

| 地址 | 寄存器名 | 关键字段/用途 | 备注 |
|---|---|---|---|
| `0x0000` | `REG_VERSION` | 版本号 | 只读 |
| `0x0004` | `REG_DATE` | RTL 日期 | 只读 |
| `0x0008` | `REG_TILE_CFG0` | `enc_ubwc_en`、`lvl1/2/3`、`highest_bank_bit`、`bank_spread_en` | 写该寄存器会发 `o_tile_addr_gen_cfg_vld` |
| `0x000c` | `REG_TILE_CFG1` | `four_line_format`、`is_lossy_rgba_2_1_format`、`pitch` | 建议先写本寄存器 |
| `0x0010` | `REG_ENC_CI_CFG0` | `input_type`、`alen`、`format`、`forced_pcm` | 写该寄存器会发 `o_enc_ci_vld` |
| `0x0014` | `REG_ENC_CI_CFG1` | `sb`、`lossy` | 其余位默认可写 `0` |
| `0x0018` | `REG_ENC_CI_CFG2` | `ubwc_cfg_0 ~ ubwc_cfg_9` | 当前例子可写 `0` |
| `0x001c` | `REG_ENC_CI_CFG3` | `ubwc_cfg_10 ~ ubwc_cfg_11` | 当前例子可写 `0` |
| `0x0020` | `REG_OTF_CFG0` | `otf_cfg_format` | 写该寄存器会发 `o_otf_cfg_vld` |
| `0x0024` | `REG_OTF_CFG1` | `width`、`height` | 像素单位 |
| `0x0028` | `REG_OTF_CFG2` | `tile_w`、`tile_h` | 像素单位 |
| `0x002c` | `REG_OTF_CFG3` | `a_tile_cols`、`b_tile_cols` | `RGBA8888` 常见是 `a=tile_cols, b=0` |
| `0x0030` | `REG_TILE_BASE_Y_LO` | 主图基地址低 32bit | 当前 `RGBA8888` 走这个 base |
| `0x0034` | `REG_TILE_BASE_Y_HI` | 主图基地址高 32bit |  |
| `0x0038` | `REG_TILE_BASE_UV_LO` | UV 基地址低 32bit | 单平面 `RGBA8888` 可写 `0` |
| `0x003c` | `REG_TILE_BASE_UV_HI` | UV 基地址高 32bit | 单平面 `RGBA8888` 可写 `0` |
| `0x0040` | `REG_META_BASE_Y_LO` | metadata 基地址低 32bit | 当前 `RGBA8888` 走这个 base |
| `0x0044` | `REG_META_BASE_Y_HI` | metadata 基地址高 32bit |  |
| `0x0048` | `REG_META_BASE_UV_LO` | UV metadata 基地址低 32bit | 单平面 `RGBA8888` 可写 `0` |
| `0x004c` | `REG_META_BASE_UV_HI` | UV metadata 基地址高 32bit | 单平面 `RGBA8888` 可写 `0` |
| `0x0050` | `REG_META_ACTIVE_SIZE` | `active_width_px`、`active_height_px` | 写 `0` 表示沿用整帧 |

### 4.2 ubwc_dec_wrapper_top 当前寄存器表

| 地址 | 寄存器名 | 关键字段/用途 | 备注 |
|---|---|---|---|
| `0x0000` | `REG_VERSION` | 版本号 | 只读 |
| `0x0004` | `REG_DATE` | RTL 日期 | 只读 |
| `0x0008` | `TILE_CFG0` | `lvl1/2/3`、`highest_bank_bit`、`bank_spread_en`、`4line_format`、`lossy_rgba_2_1` | `RGBA8888` 例子里写 `0x00000706` |
| `0x000c` | `TILE_CFG1` | `pitch` | 单位是字节 |
| `0x0010` | `TILE_CFG2` | `ci_input_type`、`ci_sb`、`ci_lossy`、`ci_alpha_mode` | 当前例子沿用 tb 默认值 |
| `0x0014` | `VIVO_CFG` | `vivo_ubwc_en`、`vivo_sreset` | 一般 `vivo_ubwc_en=1` |
| `0x0018` | `META_CFG0` | `start(W1P)`、`meta_base_format` | 最后写；`bit0` 为启动脉冲 |
| `0x001c` | `META_CFG1` | `meta_base_addr_rgba_uv[31:0]` | `RGBA8888` 走这个 base |
| `0x0020` | `META_CFG2` | `meta_base_addr_rgba_uv[63:32]` |  |
| `0x0024` | `META_CFG3` | `meta_base_addr_y[31:0]` | `NV12/P010 Y` 走这个 base |
| `0x0028` | `META_CFG4` | `meta_base_addr_y[63:32]` |  |
| `0x002c` | `META_CFG5` | `meta_tile_x_numbers`、`meta_tile_y_numbers` | 本例为 `8 x 32` |
| `0x0030` | `OTF_CFG0` | `img_width`、`format` | `format=0` 代表 `RGBA8888` |
| `0x0034` | `OTF_CFG1` | `h_total`、`h_sync` | OTF 时序 |
| `0x0038` | `OTF_CFG2` | `h_bp`、`h_act` | OTF 时序 |
| `0x003c` | `OTF_CFG3` | `v_total`、`v_sync` | OTF 时序 |
| `0x0040` | `OTF_CFG4` | `v_bp`、`v_act` | OTF 时序 |
| `0x0044` | `TILE_BASE0` | `tile_base_addr_rgba_uv[31:0]` | `RGBA8888` 走这个 base |
| `0x0048` | `TILE_BASE1` | `tile_base_addr_rgba_uv[63:32]` |  |
| `0x004c` | `TILE_BASE2` | `tile_base_addr_y[31:0]` | `NV12/P010 Y` 走这个 base |
| `0x0050` | `TILE_BASE3` | `tile_base_addr_y[63:32]` |  |
| `0x0054` | `STATUS0` | `frame_active`、`meta/tile/vivo/otf_busy`、`frame_idle_done` | 推荐配合 `STATUS1` 使用 |
| `0x0058` | `STATUS1` | `meta_done`、`tile_done`、`vivo_done`、`otf_done`、`frame_done` | `bit4 frame_done` 最适合轮询 |

## 5. 两个 wrapper 的差异总结

- `enc`：APB 侧主要是配置寄存器，没有现成的“完成状态寄存器”
- `dec`：APB 侧既有配置寄存器，也有完整的 `STATUS0/STATUS1`
- `enc` 启动靠“输入帧开始送入”
- `dec` 启动靠“写 `META_CFG0[0]=1`”
- `enc` 如果要给软件驱动长期使用，建议补状态寄存器
- `dec` 当前已经可以直接按寄存器轮询完成
