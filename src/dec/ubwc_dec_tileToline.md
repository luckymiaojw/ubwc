# 代码实现思路详解 (Implementation Strategy)

本设计的核心思想是**“数据流驱动 (Data-flow Driven)”**与**“解耦映射 (Decoupled Mapping)”**。通过将数据的接收、解析、地址映射和同步触发分层，实现了一个无乘法器的高吞吐流水线。

## 1. 异步缓冲与格式捆绑 (FIFO & Format Bundling)

在多平面视频流（如 YUV 交织）中，直接使用顶层的 Sideband 信号控制核心状态机会导致时序错乱。因此，我们将 256-bit 的 Tile 数据、`TLAST` 信号以及 5-bit 的 `i_ci_format` 信号拼接成 262-bit 的宽总线，统一推入同步 FIFO。

当数据从 FIFO 弹出时，伴随的 Format 信号天然就是和当前 Tile 严格对齐的。Format Decoder 作为纯组合逻辑，瞬间解析出当前 Tile 的物理属性（长宽、位移参数等），供后续流水线使用。

## 2. 无乘法器地址生成 (DSP-Free Address Mapping)

将二维的 Tile 数据打散到一维 SRAM 中，传统的做法是 $Addr = Base + Y \times Stride + X$，这通常需要消耗 DSP（硬件乘法器）。

为了优化面积并冲击极高的时钟频率，设计中采用了**硬连线移位法**：

* 所有格式在 128-bit SRAM 接口下，一个 Tile 永远等于 16 次写入。
* 通过 Format Decoder 输出的 `px_shift` 和 `is_y_stride_1k` 控制位，将行跨度（Stride）固定为 1024 Words 或 256 Words（$2^{10}$ 或 $2^{8}$）。
* 计算地址时，直接用 `y_in_tile` 拼接 `10'd0` 代替乘法，用 `px_cnt >> px_shift` 代替除法。组合逻辑延迟极低。

## 3. 稳健的非对齐裁切机制 (Unaligned Cropping & TLAST Safeguard)

真实场景中，`cfg_img_width`（如 1920）往往不能被 Tile 宽度（如 32）整除。

设计中并未增加复杂的 Padding 剔除逻辑，而是**照单全收**，将冗余的 Padding 直接写入 SRAM 每行末尾的闲置区域。

核心状态机通过判定 `(px_cnt + tile_w_pixels >= cfg_img_width)` 来强制换行。同时引入 `current_tlast` 作为“Tile 结束对齐哨兵”，即使上游发生单 bit 错位，也能在下一个 Tile 自动恢复，确保状态机永不死锁。

## 4. 多平面协同同步 (Multi-Planar Synchronization)

对于 YUV420 和 YUV422 格式，必须等待多个平面（Plane）凑齐才能进行行输出。

我们引入了独立的行累加器 `y_row_cnt` 和 `uv_row_cnt`。Format Decoder 会动态吐出当前格式的“通关条件”（`req_y_rows` 和 `req_uv_rows`）。

每次写满一整行 Tile 时，只增加对应平面的计数器。唯有当 Y 和 UV 的行数同时达到各自的目标时，`trigger_switch` 才会拉高，触发 Ping-Pong 切换并拉高 `buffer_vld`。这种事件驱动机制完美免疫了 AXI 总线上 Y 和 UV 包乱序或交织发送的问题。
