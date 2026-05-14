# UBWC ENC/DEC APB 配置说明

本文档说明当前 RTL 中 ENC/DEC APB 寄存器的推荐配置方式，重点区分：

- 上电后只需要配置一次的内容
- 图像格式、尺寸、layout 不变时可以复用的内容
- 每帧或每个 buffer 都必须重新配置的内容
- 连续帧模式下地址组、fcnt 和中断的使用方式

对应 RTL：

- ENC: `src/enc/ubwc_enc_apb_reg_blk.v`
- DEC: `src/dec/ubwc_dec_apb_reg_blk.v`

对应寄存器表：

- `docs/ubwc_enc_reg_table.xlsx`
- `docs/ubwc_dec_reg_table.xlsx`
- `docs/ubwc_reg_tables.xlsx`

## 1. 通用规则

APB 寄存器为 32 bit 宽，地址按 4 byte 对齐。所有 64 bit base address 都按低 32 bit、高 32 bit 的顺序写入。

当前回归和推荐集成时钟：

| 时钟域 | 频率 | ENC 端口 | DEC 端口 | 说明 |
| --- | ---: | --- | --- | --- |
| APB | 100 MHz | `PCLK` | `PCLK` | 寄存器访问 |
| AXI/control | 500 MHz | `i_clk` | `i_axi_clk` | AXI 读写和控制状态 |
| core/VIVO | 200 MHz | `i_vivo_clk` | `i_vivo_clk` | UBWC encode/decode core |
| OTF | 320 MHz | `i_otf_clk` | `i_otf_clk` | OTF 输入或输出 |

当前格式编码如下：

| 格式 | 编码 | tile_w | tile_h | 说明 |
| --- | ---: | ---: | ---: | --- |
| RGBA8888 | 0 | 16 | 4 | 单平面 RGBA |
| RGBA1010102 | 1 | 16 | 4 | 单平面 RGBA |
| YUV420_8 / NV12 | 2 | 32 | 8 | Y + UV 双平面 |
| YUV420_10 / P010 | 3 | 32 | 4 | Y + UV 双平面，16 bit component 存储 |

当前 RTL 不支持 YUV422_8 和 YUV422_10。

连续帧模式下，图像格式、分辨率、tile layout、OTF timing 不变时，不需要每帧重复写所有寄存器。每帧只需要更新本帧使用的 UBWC buffer base address，并保证下一帧地址组已经写完整。

## 2. 哪些寄存器需要反复配置

### 2.1 上电后通常只配置一次

| 模块 | 寄存器 | 说明 |
| --- | --- | --- |
| ENC/DEC | `VERSION/DATE` | 只读检查，用于确认 RTL 版本 |
| ENC | `REG_IRQ_CTRL[0]` @ `0x060` | IRQ enable，复位默认已经为 1 |
| DEC | `APB_ADDR_IRQ_CTRL[0]` @ `0x060` | IRQ enable，复位默认已经为 1 |
| DEC | `APB_ADDR_VIVO_CFG` @ `0x014` | 通常 `vivo_ubwc_en=1` 后保持不变 |

### 2.2 只有格式、尺寸或 layout 变化时才需要配置

| 模块 | 寄存器组 | 说明 |
| --- | --- | --- |
| ENC | `REG_TILE_CFG0/1` | bank swizzle、bank spread、4-line format、tile pitch |
| ENC | `REG_ENC_CI_CFG0/1/2/3` | CI 行为配置，通常 input_type=1、alen=7 |
| ENC | `REG_OTF_CFG0/1/2/3` | 输入格式、宽高、tile 尺寸、tile columns |
| ENC | `REG_META_ACTIVE_SIZE`、`REG_META_PITCH` | metadata active size 和 pitch |
| DEC | `APB_ADDR_TILE_CFG0/1/2` | tile layout、CI 配置 |
| DEC | `APB_ADDR_META_CFG0` | Y/RGBA metadata tile_x/tile_y 数量 |
| DEC | `APB_ADDR_OTF_CFG0/1/2/3/4` | 输出格式、宽度、OTF timing |

### 2.3 每帧或每个新 buffer 都需要配置

| 模块 | 寄存器组 | 说明 |
| --- | --- | --- |
| ENC | `REG_TILE_BASE_*`、`REG_META_BASE_*` | 每帧写入一组输出 buffer 地址 |
| DEC | `REG_META_BASE_Y_*`、`REG_TILE_BASE_Y_*`、`REG_META_BASE_UV_*`、`REG_TILE_BASE_UV_*` | 每帧写入一组输入 UBWC buffer 地址 |

如果连续多帧使用 ping-pong buffer，则每帧至少要提前写好对应 slot 的地址。当前设计中 `fcnt[0]` 用于区分相邻两帧的数据路径和地址 slot。

## 3. ENC 配置流程

ENC 通过 `IRQ_CTRL[5]` 写 1 产生 START token。软件写好本帧地址后，先写 `IRQ_CTRL[5]=1`，再送入对应的 `vsync/hsync/de/data`。

### 3.1 ENC 静态配置

下面这些配置在格式和尺寸不变时可以保持不变。

1. 读取版本：

```text
read(0x000); // REG_VERSION
read(0x004); // REG_DATE
```

2. 配置 tile layout：

```text
write(0x00c, REG_TILE_CFG1); // four_line_format, lossy_rgba_2_1, tile_pitch
write(0x008, REG_TILE_CFG0); // ubwc_en, bank swizzle, bank spread
```

`REG_TILE_CFG1[0] four_line_format` 推荐：

| 格式 | four_line_format |
| --- | ---: |
| RGBA8888 / RGBA1010102 | 1 |
| NV12 / P010 | 0 |

`tile_pitch` 单位是 16 byte：

```text
pixel_pitch = align_up(width * bpp, tile_w * 4 * bpp)
tile_pitch  = pixel_pitch / 16
```

3. 配置 CI：

```text
write(0x014, REG_ENC_CI_CFG1);
write(0x018, REG_ENC_CI_CFG2);
write(0x01c, REG_ENC_CI_CFG3);
write(0x010, REG_ENC_CI_CFG0); // input_type 和 alen
```

当前软件通常写：

```text
enc_ci_input_type = 1;
enc_ci_alen       = 7;
reserved cfg bits = 0;
```

4. 配置 OTF 和 metadata geometry：

```text
write(0x024, REG_OTF_CFG1);         // width, height
write(0x028, REG_OTF_CFG2);         // tile_w, tile_h
write(0x02c, REG_OTF_CFG3);         // y_tile_cols, uv_tile_cols
write(0x050, REG_META_ACTIVE_SIZE); // active width/height
write(0x054, REG_META_PITCH);       // metadata pitch
write(0x020, REG_OTF_CFG0);         // format，建议作为 geometry 组最后一笔
```

tile column 计算：

```text
RGBA: y_tile_cols = ceil(width / 16), uv_tile_cols = 0
YUV : y_tile_cols = ceil(width / 32), uv_tile_cols = ceil(width / 32)
```

`o_meta_last_xcoord` 由 RTL 根据 `max(y_tile_cols,uv_tile_cols)-1` 计算，不再需要软件单独配置。

### 3.2 ENC 每帧地址配置

ENC 使用两组交替地址 slot，对应 `fcnt[0]=0/1`。每次需要写入 4 个 64 bit 地址：

- Y metadata base，RGBA 图像使用该槽位
- Y tile base，RGBA 图像使用该槽位
- UV metadata base，RGBA 图像写 0
- UV tile base，RGBA 图像写 0

推荐写入顺序：

```text
write(0x030, meta_base_y_lo);
write(0x034, meta_base_y_hi);

write(0x038, tile_base_y_lo);
write(0x03c, tile_base_y_hi);

write(0x040, meta_base_uv_lo);
write(0x044, meta_base_uv_hi);

write(0x048, tile_base_uv_lo);
write(0x04c, tile_base_uv_hi);
write(0x060, irq_enable | (1 << 5)); // start
```

注意：地址写入只负责填充地址队列，不再作为 start 标志。四个 base address 写完后，软件写 `REG_IRQ_CTRL[5]=1` 作为本帧 START。

如果当前输入帧对应的 `fcnt[0]` 地址还没有配置好，数据会被阻塞，并产生地址配置无效相关状态/中断。

### 3.3 ENC 运行和中断

地址和静态配置准备好后，先写 START，再启动上游 OTF 输入：

```text
write(0x060, irq_enable | (1 << 5)); // IRQ_CTRL[5] = start
start_otf_input_stream();
```

ENC 正确中断在最后一个有效输出数据完成后产生，错误中断在错误发生时产生。软件可读：

```text
read(0x058); // REG_STATUS0
read(0x05c); // REG_STATUS1 stage_done
read(0x060); // REG_IRQ_CTRL
read(0x064); // REG_STATUS2
```

清中断：

```text
write(0x060, old_irq_enable | (1 << 1)); // IRQ_CTRL[1] = irq_clear
```

调试计数寄存器：

| 地址 | 说明 |
| --- | --- |
| `0x068/0x06c` | metadata 处理计数 slot0/slot1 |
| `0x070/0x074` | tileaddr 处理计数 slot0/slot1 |
| `0x078/0x07c` | OTF tile 计数 slot0/slot1 |
| `0x080/0x084` | OTF de beat 计数 slot0/slot1 |
| `0x088/0x08c` | OTF line 计数 slot0/slot1 |
| `0x090/0x094` | tile AXI W 计数 slot0/slot1 |
| `0x098/0x09c` | meta AXI W 计数 slot0/slot1 |

## 4. DEC 配置流程

当前 DEC 已改为寄存器 START 模式。软件不再依赖旧的 `META_CFG0[0] meta_start`，也不使用地址写入作为 start。软件每帧写完整一组输入 UBWC base address 后，需要写 `IRQ_CTRL[5]=1`。

当完整地址组和 START token 都有效，且 metadata stage 可以接受新帧时，硬件锁存本帧地址并产生新的 frame start。

### 4.1 DEC 静态配置

下面这些配置在格式、尺寸、timing 不变时可以保持不变。

1. 读取版本：

```text
read(0x000); // REG_VERSION
read(0x004); // REG_DATE
```

2. 配置 tile layout 和 CI：

```text
write(0x008, APB_ADDR_TILE_CFG0); // swizzle, spread, 4line, lossy_rgba_2_1
write(0x00c, APB_ADDR_TILE_CFG1); // tile_cfg_pitch
write(0x010, APB_ADDR_TILE_CFG2); // ci_input_type, ci_lossy, alpha
```

3. 配置 VIVO：

```text
write(0x014, APB_ADDR_VIVO_CFG); // 通常 vivo_ubwc_en=1
```

4. 配置 metadata tile 数量：

```text
write(0x02c, APB_ADDR_META_CFG0); // {tile_y_numbers, tile_x_numbers}
```

tile number 计算：

```text
RGBA tile_x = ceil(width / 16)
RGBA tile_y = ceil(height / 4)

YUV  tile_x = ceil(width / 32)
YUV  tile_y = ceil(height / 8)
```

5. 配置 OTF 输出 timing：

```text
write(0x018, APB_ADDR_OTF_CFG0); // img_width, format
write(0x01c, APB_ADDR_OTF_CFG1); // h_total, h_sync
write(0x020, APB_ADDR_OTF_CFG2); // h_bp, h_act
write(0x024, APB_ADDR_OTF_CFG3); // v_total, v_sync
write(0x028, APB_ADDR_OTF_CFG4); // v_bp, v_act
```

如果输出 timing 不变，连续帧不需要重复写这些 OTF_CFG 寄存器。

### 4.2 DEC 每帧地址配置

每帧需要写入四类地址。每类地址都按 low word、high word 的顺序写入。

推荐顺序：

```text
// RGBA/Y metadata base
write(0x030, meta_base_rgba_y_lo);
write(0x034, meta_base_rgba_y_hi);

// RGBA/Y tile base
write(0x038, tile_base_rgba_y_lo);
write(0x03c, tile_base_rgba_y_hi);

// UV metadata base
write(0x040, meta_base_uv_lo);
write(0x044, meta_base_uv_hi);

// UV tile base，RGBA 图像不关心
write(0x048, tile_base_uv_lo);
write(0x04c, tile_base_uv_hi);
```

当四类地址都写完整后，软件写 `IRQ_CTRL[5]=1` 启动一帧 decode。

对 RGBA 单平面格式：

- DEC 主数据路径使用 `tile_base_addr_rgba_y`
- DEC metadata 路径使用 `meta_base_addr_rgba_y`
- 不使用的 UV partner 地址仍可以按软件封装要求写 0 或写入合法占位地址

对 NV12/P010：

- `tile_base_addr_rgba_y` 是 Y tile data 起始地址
- `tile_base_addr_uv` 是 UV tile data 起始地址
- `meta_base_addr_rgba_y` 是 Y metadata 起始地址
- `meta_base_addr_uv` 是 UV metadata 起始地址

### 4.3 DEC 状态、中断和统计

常用状态：

```text
read(0x050); // STATUS0: frame_active/meta_busy/tile_busy/vivo_busy/otf_busy
read(0x054); // STATUS1: stage_done/stage_seen
read(0x060); // IRQ_CTRL: irq_enable/clear/pending/error/correct
read(0x064); // STATUS4: irq pending mirror
```

`STATUS1[4]` 表示 frame_done。正确中断和错误中断分开锁存：

- correct pending：正常帧输出到指定位置后产生
- error pending：错误发生时产生

清中断：

```text
write(0x060, old_irq_enable | (1 << 1)); // IRQ_CTRL[1] = irq_clear
```

统计寄存器：

| 地址 | 说明 |
| --- | --- |
| `0x068` | metadata valid tile count |
| `0x06c` | tile address generator valid tile count |
| `0x070` | tile-to-OTF accepted tile count |
| `0x074` | OTF output line count |
| `0x078` | OTF output de beat count |

## 5. UBWC buffer 地址排列规则

推荐连续 UBWC buffer 排列：

```text
Y/RGBA metadata
Y/RGBA tile data
UV metadata
UV tile data
```

Metadata pitch：

```text
meta_pitch = align_up(ceil(plane_width / tile_w), 64)
meta_rows  = align_up(ceil(plane_height / tile_h), 16)
meta_size  = align_up(meta_pitch * meta_rows, 4KB)
```

Pixel/tile data pitch：

```text
pixel_pitch    = align_up(width * bpp, tile_w * 4 * bpp)
aligned_height = align_up(height, 32)
pixel_size     = align_up(pixel_pitch * aligned_height, 4KB)
```

NV12/P010 的 UV plane 使用半宽、半高语义，但 UV 一个 sample pair 包含 U/V 两个分量，因此计算 bpp 时要注意使用当前工具函数中的定义。

## 6. 连续帧配置建议

连续帧下推荐软件维护一个队列：

1. 初始化时写一次格式、尺寸、tile、OTF timing、CI、VIVO 等静态配置。
2. 每来一个新输出/输入 buffer，就写一组 base address。
3. 保证至少提前写好两帧地址，使 slot0/slot1 都有有效地址。
4. 每组地址写完后写 `IRQ_CTRL[5]=1` 作为 START。ENC 随后送入对应 OTF 帧；DEC 在 START token 和地址组都有效时启动。
5. 每帧结束后处理中断，读取必要统计，再清中断。

如果图像格式和尺寸不变，只换 buffer 地址，则不需要重复写 tile/OTF/meta geometry 寄存器。

如果图像格式、分辨率、tile layout 或 OTF timing 发生变化，必须先等当前帧处理安全结束，再重新写对应静态配置，然后再写新帧地址。
