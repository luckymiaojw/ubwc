# ubwc_enc OTF→Tile 子系统 V1 重构设计讨论

> **V1 替换的是 `ubwc_enc_otf_to_tile_top`**（OTF 采集 → 行序整合 → bank SRAM → tile 读出 → 对外）
> 目录：`src/enc_v1/`
> 顶层 wrapper 对外接口**保持不变**（即 `ubwc_enc_otf_to_tile_top` 的端口）
>
> 不在 V1 范围内：tile → AXI 写出、meta 生成、APB 寄存器、reset FSM 等
>
> **时钟域 + 复位映射**（与现行 wrapper 一致）：
> | V1 内部命名 | wrapper 时钟端口 | 复位端口 | 用途 |
> |---|---|---|---|
> | OTF clk | `i_otf_clk` | `rst_n_otf` | otf_monitor |
> | 核心 clk | `clk`（sys/core） | `rst_n_sys` | writer + bank mux + fetcher + async FIFO 核心侧 |
> | 下游 clk | `i_vivo_clk` | `rst_n_vivo` | 对外 ci / tile（下游 ENC 主路） |
>
> **复位策略**：每个时钟域用自己的复位；async FIFO 跨域两侧各自被对应域复位（内部用标准 sync 处理 CDC）
>
> **接口端口保留但 V1 不实现**：
> - `i_start_pulse` — 软件启动脉冲，V1 暂不使用（writer 不依赖 start_pulse 启动，直接由 vsync 驱动）
> - `o_tile_stat_valid / o_tile_stat_last / o_tile_stat_slot` — 统计字段，V1 暂不实现（输出为 0）

---

## 1. 拆分目标

V1 由 **3 个模块 + 1 个复用模块** 构成，按"采集 / 写入 / 读出"三段组织：

| V1 模块 | 职责 | 时钟域 |
|---|---|---|
| `ubwc_enc_otf_data_packer` (**复用，不动**) | OTF 跨域 + 字节布局解析 (4 套 pack) + Y/UV plane 分流 + 三类异常检测 (bline/bframe/fifo_ovf) | otf_clk → 核心 clk |
| `ubwc_enc_otf_monitor` (V1 薄壳) | 仅做 **fcnt 连续性检测** → 输出 `err_fcnt` | otf_clk |
| `ubwc_enc_line_to_tile_writer` (V1) | 从 packer 的 fifo_a/fifo_b 弹 + 合并 + ping-pong 写 bank + 自维护 fcnt + done_info + release | 核心 clk |
| `ubwc_enc_tile_data_fetcher` (V1) | 按 tile 读 bank + mask + 坐标 + forced_pcm 检测 + 合并跨域输出 | 核心 clk → vivo_clk |

**关键边界**：
- `otf_monitor` **隔离 OTF 端 fcnt**：不让 OTF fcnt 进入下游通路；其唯一职责是连续性检测，输出独立 `err_fcnt`
- `packer` 的 `otf_fcnt` 输入端 **tie 0**（被 otf_monitor 隔离掉）→ packer 输出的 fifo_a/fifo_b entry 中 fcnt 字段为 0，writer 不使用
- writer **自维护 4-bit fcnt**（用 packer 输出 entry 中的 vsync 标志做帧边界，每帧 +1）

输出端的 `o_ci_*` 和 `o_tile_*` 合并成一路 async FIFO 跨到 vivo_clk 域。

---

## 2. otf_monitor（V1 薄壳 — 仅 fcnt 隔离）

**位于 OTF 时钟域。**

### 唯一职责
**隔离 OTF fcnt** —— OTF 端 fcnt 不参与下游任何数据通路；otf_monitor 只做连续性检测：
- 内部 latch 上一帧 fcnt
- 每帧 vsync 上升沿比对本帧 fcnt 是否 = 上一帧 +1
- 不连续 → 拉 `err_fcnt` sticky → 跨域同步到 sys clk → 顶层输出 `o_err_fcnt`

### 不做的事（已被 packer 覆盖）
| 检查 | 谁做 |
|---|---|
| 横向对齐 (cfg_width) | packer.err_bline |
| 帧高度对齐 (cfg_height) | packer.err_bframe |
| OTF 背压期间数据丢失 | packer.err_fifo_ovf |
| 字节布局解析 / plane 分流 | packer 内部 4 套 pack 路径 |
| 跨域 CDC | packer 内部 in_fifo |

### OTF 输入接口（端口转发，不深入处理）
- `i_otf_vsync` — 用于 fcnt latch 边沿
- `i_otf_fcnt[3:0]` — 仅 otf_monitor 内部用
- `i_otf_de`（可选，作为有效数据节拍）
- **不需要** lcnt / hsync / data —— 这些直接进 packer

### 错误处理
- `err_fcnt` **sticky** 一直保持，通过 `i_err_clear` 清
- 输出端口 **独立**：顶层 wrapper 新增 `o_err_fcnt`（不复用 bline/bframe/fifo_ovf）
- err 期间 writer 不停（与之前一致）；软件介入决定恢复策略

### 关键约束
- otf_monitor **不传递** `otf_fcnt` 给 packer 或其他下游
- packer 的 `otf_fcnt` 输入端 **tie 0**（接地）
- 这样 OTF 端 fcnt 跳变完全不影响下游处理，writer 用自己的 fcnt

### 帧切换 info 通路（→ writer）
除 `o_err_fcnt` 外，otf_monitor 还向 writer 输出 **frame_info bus**：

| 信号 | 域 | 含义 |
|---|---|---|
| `o_frame_change_pulse` | sys clk (跨域同步) | OTF vsync 上升沿同步到 sys clk 的 **1 拍脉冲** —— writer 用它做 fcnt +1，无论 OTF fcnt 是否异常都触发 |
| `o_fcnt_seen[3:0]` | sys clk (跨域同步) | OTF 端最近一帧 fcnt 的 latch，**仅供 debug**（writer 不依赖它） |

跨域用 **2-FF + edge detect**（不用 FIFO，最简）。

这样保证：
- writer 的 fcnt 完全由 otf_monitor 拍板（与 packer 内部 vsync 透传时序解耦）
- OTF 端 fcnt 跳变异常时，writer 仍按"帧数"+1（异常只通过 err_fcnt 报）
- 软件 debug 时可读 `fcnt_seen` 与 writer 的 fcnt 对比

---

## 3. line_to_tile_writer

**位于核心时钟域；从 packer 的 `fifo_a / fifo_b` 弹数据。**

### 输入侧
- **不直接接 OTF**，输入来自 packer 的两路输出 FIFO：
  - `fifo_a[162:0]`：Y / RGBA 数据流（每 entry = `{fcnt[3:0], lcnt[11:0], vsync, hsync, tlast, tkeep[15:0], tdata[127:0]}`）
  - `fifo_b[162:0]`：UV 数据流（YUV420 时启用，RGBA 时永远 idle）
- writer 视角下，**plane 分流已经做好**（fifo_a = Y, fifo_b = UV），不需要再用 `lcnt[0]` 分

### 数据/地址整理
- writer 根据 entry 内 `lcnt` + `vsync` + `tlast` 推算当前行位置
- 按 `cfg_format` + 行位置算出 SRAM 写地址（Y 区 / UV_A / UV_B）
- 决定 ping-pong bank（写完整组才切）
- 决定 UV slot（A 或 B，由 `group_id[1]` 选）

### writer 自维护 fcnt
- 不使用 packer 输出 entry 中的 fcnt 字段（被 otf_monitor 隔离，永远为 0）
- **不**用 packer entry 的 vsync 标志（避免内部流水时序偏移）
- **使用 `otf_monitor.o_frame_change_pulse`**（跨域同步后的 1 拍脉冲）做帧边界 → fcnt +1
- 这是 V1 的"4-bit 自维护 fcnt"，与 OTF 端 fcnt 解耦，但帧边界严格由 otf_monitor 控制

### writer 内部拆分（2 个子块）
由于 plane 分流已经由 packer 完成，writer 内部仅需 2 子块：

| 子块 | 职责 |
|---|---|
| **writer_arb** | pop fifo_a / fifo_b → word 级 round-robin 合并 → 算 SRAM 地址（Y 区 / UV_A/B）→ 选 ping-pong bank → 推合并写小 FIFO |
| **writer_ctl** | 维护 4-bit fcnt（用 entry.vsync）+ 写小 FIFO pop → 驱动 `m_writer_*` 给顶层 mux + done_info 生成（含末组孤立）+ release 跟踪 + partial 行数计数 |

### 子块 1: writer_arb（合并 + 地址）
- 输入：fifo_a (Y) pop 接口 + fifo_b (UV) pop 接口
- 合并 FIFO 仲裁：**Y / UV word 级交替弹**；一侧空时另一侧连续弹
- **每拍合并 FIFO 出口至多 pop 1 个**（单端口 SRAM 一拍 1 个写）
- 选 bank（ping-pong）：写完一个 bank 整组再切
- 选 UV slot：UV 数据按 `group_id[1]` 进 UV_A 或 UV_B
- 输出 `{data, addr, bank_sel, wen=1}` 经合并写小 FIFO 给 writer_ctl

### 子块 2: writer_ctl（控制 + fcnt + done + release）
- 用 packer entry 的 `vsync` 边沿维护 4-bit fcnt（与 OTF fcnt 解耦）
- 从合并写小 FIFO 弹出 → 输出 `m_writer_en/wen/addr/din` 给顶层 mux
- 跟踪每 bank 写入进度（Y 行数、UV 行数 per slot）
- 产 done_info：
  - Y 区写完拉 `Y_done`
  - bank1 UV slot 写完拉 `UV_done`（正常情况）
  - 末组孤立 Y → 主动补发 `UV_done(last_uv_isolated)`
- 收 `Y_release / UV_release` → 更新 per bank per region 的可写状态
- partial 末组：记录 `y_rows_actual / uv_rows_b0_actual / uv_rows_b1_actual` 一并 push 进 done_info

### bank release 通路（fetcher → writer 反馈）
fetcher 读完一**整行** tile 数据后，把"该 bank 该区域可被重写"通知 writer。release 信号为 **1 拍脉冲**（writer 必须 latch）：

| 信号 | 触发时机 | 释放范围 |
|---|---|---|
| `Y_release(bank_sel)` | 该 bank 的 **一整行 Y tiles** 全部读完（tile_x 0..cfg_y_tile_cols-1） | 该 bank 的 Y 区可重写 |
| `UV_release(uv_slot)` | **一整行 UV tiles** 全部读完（跨 bank 拼读完成 N 个 UV tile） | **BANK0 和 BANK1 的该 slot 同时释放**（UV_A 或 UV_B 跨两 bank 是同一逻辑空间） |

**关键点**：
- release 粒度是"一整行 tiles"，不是单个 tile 读完
- UV slot (A 或 B) 是逻辑空间，物理上跨 bank0 和 bank1，所以 UV_release 同时释放两个 bank 对应 slot
- writer 用 1 个 latch 寄存器记每个区的状态（Y per bank 共 2 个，UV per slot 共 2 个）
- 状态机：`idle → writing → waiting_release → idle`

### writer 重用 bank 的严格条件
要在某个 bank 写新一组数据，必须满足：
```
(该 bank.Y 已释放) AND (该组目标 UV slot 已释放)
```
- 目标 UV slot 取决于新组的 `group_id[1]`：0 → UV_A，1 → UV_B
- 即同一 bank 的 Y 区和 UV slot 释放节奏不同步，writer 等两个都到位才启动
- RGBA：无 UV slot 条件，只看 Y 释放

### writer 自维护的 fcnt
- writer 内部维护 **4-bit fcnt 寄存器**，在 vsync / 帧边界时 +1
- fcnt 与 OTF 端 fcnt 解耦 — 即使 OTF fcnt 跳变，writer 仍按自己的节拍计数
- fcnt 随 done_info 一同传给 fetcher

### done_info 通路（Y / UV 分两类）
writer **分别**把 Y 完成和 UV 完成传给 fetcher：

| 类别 | 触发时机 | fetcher 动作 |
|---|---|---|
| **Y_done** | 某 bank 的一组 Y 写满 ① | 该 bank 的 Y tile 可独立被读 |
| **UV_done** | **bank1** 的一组 UV 写满（此时 bank0 早已写完，配对就绪）② | fetcher 跨 bank 拼读 UV tile（前半 bank0，后半 bank1） |
| **UV_done (末组特例)** | 帧结束且最后一个 Y 组是孤立 bank0（无配对 bank1）③ | fetcher 出"半 UV tile"，后半 keep=0 |
| **frame_done** | 该 bank 是本帧最后一组 | 与上面任一同时拉一拍 |

① RGBA：Y 即全部数据；YUV420：Y 8 行（YUV10 为 4 行）
② **UV_done 只在 bank1 完成时发**，不需要 fetcher 自己等"一对" — writer 已经替它做了配对仲裁
③ 末组若是孤立 Y 组（帧结束、无 bank1 配对），writer 在发完 Y_done 之后**主动**再发一个 UV_done（特例标志位置 1），让 fetcher 出半 tile

载荷：`{type, bank_sel, fcnt, uv_slot(A/B), y_rows_actual, uv_rows_b0_actual, uv_rows_b1_actual, frame_done, last_uv_isolated}`

**典型一帧 done_info 序列**（YUV420 标准情况）：
```
Y_done(b0,g0) → Y_done(b1,g1) → UV_done(b1) →
Y_done(b0,g2) → Y_done(b1,g3) → UV_done(b1) →
... →
Y_done(b0,gN) → Y_done(b1,gN+1) → UV_done(b1, frame_done)
```

**末组孤立情况**（最后 Y 组数为奇数）：
```
... → Y_done(b0,gN) → UV_done(b0, last_uv_isolated, frame_done)   // bank1 没有数据
```

### partial last group 处理（行不对齐）
当帧高度不是 tile 高度整数倍时，最后一组的 Y 或 UV 不会写满：

- **写完最后一行的最后一列就立刻拉 done**，不等满 tile
- done_info 载荷里携带 **实际写入的行数**：
  - `y_rows_actual`：该 bank 实际写入的 Y 行数 (0..Y 组高度)
  - `uv_rows_b0_actual` / `uv_rows_b1_actual`：bank0 / bank1 各自实际写入的 UV 行数
- fetcher 用这些实际行数 + cfg_active_width 一起算 mask（超出有效区域 keep=0）
- 例：YUV420-8 末组 Y 只写 6 行 + UV 只写 3 行 → done_info 带 `y_rows_actual=6, uv_rows_b1_actual=3` → fetcher 算 mask 时 Y tile 末 2 行 keep=0，UV tile 末 1 行 keep=0

### 为什么用三级 FIFO（Y 小 + UV 小 + 合并）
- 让"地址生成 → 合并仲裁 → SRAM 写"三段彼此解耦
- 每段处理逻辑只看自己的 FIFO，互不阻塞，时序更宽裕

### 完成 info 的语义
- 标记是 *哪个 bank 的哪个 plane (Y/RGBA 还是 UV)* 写完
- 附带 fcnt，使 fetcher 能正确产生 sb 和命令 metadata

---

## 4. tile_data_fetcher

**位于核心时钟域。从 bank SRAM 读 tile。**

### 写优先与读条件（fetcher 内部自己门控）
- bank SRAM 的 enable 模型：`en = ren || wen`
- **fetcher 直接监听 writer 模块的 `wen` 输出**（跨模块组合信号），用它自己决定本拍是否发 `ren`：
  - `writer_wen == 1` → fetcher 不发 ren，**不 push meta entry**
  - `writer_wen == 0` → fetcher 可发 ren，**push meta entry**
- 这样 meta entry 与实际 SRAM 读发起严格 1:1，**不需要 mux 反馈 ren_accepted**
- mux 也会做同样的门控（保险），但 fetcher 自己已经确保不发"会被 mask 的 ren"
- **同 bank 跨区（Y / UV_A / UV_B）共享同一个 wen**：writer 写该 bank 任何区时，fetcher 不可读该 bank 任何区

### bank SRAM 接口 mux 归属
- **mux 在顶层 `ubwc_enc_otf_to_tile_top` 内做**，不在 writer 或 fetcher 内部
- **mux 对 SRAM 侧输出寄存一拍**（解时序，避免跨模块组合路径过长）
- writer 暴露：`m_writer_en / m_writer_wen / m_writer_addr / m_writer_din` per bank
- fetcher 暴露：`m_fetcher_ren / m_fetcher_addr` per bank；`s_fetcher_dout / s_fetcher_dout_vld` 收取返回
- 顶层 mux 逻辑（per bank）：
  ```
  // 组合仲裁
  sel_en_c   = writer_en | fetcher_ren
  sel_wen_c  = writer_wen
  sel_addr_c = writer_en ? writer_addr : fetcher_addr   // 写优先
  sel_din_c  = writer_din

  // 寄存一拍后驱动 SRAM
  bank_en   <= sel_en_c
  bank_wen  <= sel_wen_c
  bank_addr <= sel_addr_c
  bank_din  <= sel_din_c

  // SRAM 自己产出 dout_vld
  fetcher_dout     = bank_dout
  fetcher_dout_vld = bank_dout_vld    // SRAM macro 提供
  ```
- **SRAM 读延迟 ≤4 拍最长**（不固定），所以 `dout_vld` 不能用 pipe 算，**必须由 SRAM macro 自身产出**
- writer/fetcher 模块边界干净，时序宽裕

### 连续读 & fetch FIFO 流控
- bank SRAM 支持**连续 pipeline 读**：fetcher 可逐拍发 ren，SRAM 返回时用 `dout_vld` 标记
- fetcher 维护一个 **outstanding 计数器**，跟踪已发出但尚未返回的读
- 每次准备发新读时，**额外检查 fetch FIFO 剩余容量**：
  - `fetch_fifo_free_space >= outstanding + 1`
  - 不满足则停发，等 dout_vld 返回腾出空间
- 综合：读发起条件 =
  ```
  (writer_wen == 0)             // 写优先避让
  && (fetch_fifo_credit > 0)    // 容量节流
  && (有 tile 待读)
  ```

### 读数据通路 & read meta FIFO
- **SRAM 是 128-bit/word**；V1 对外输出是 256-bit/word：
  - fetcher **连续发 2 个 128-bit SRAM 读**（addr_lo 然后 addr_hi）
  - 等 2 个 dout（dout_vld 标）回来后拼成 1 个 256-bit beat
  - 送入合并 async FIFO #2
- **read meta FIFO 每 entry 对应 1 个 256-bit 输出 beat**：
  - push 时机：在发完 addr_hi 那拍 push（一对读发完才 push 1 entry）
  - 载荷：
    ```
    {tile_x, tile_y, mask[31:0], forced_pcm_Y/UV, bank_sel,
     first_word_in_tile (= sof), last_word_in_tile, stat_*}
    ```
- mask 与 forced_pcm 都是**预计算**（基于 cfg + tile 坐标 + done_info 实际行数）

### dout pair holder（≥ 4 entry）
- SRAM 读延迟 ≤4 拍最长（变长），所以发 ren 后 dout 不一定立即回
- 同时可能有多对 (addr_lo, addr_hi) 在飞 → 需要 **≥4 entry 的 pair holder**（FIFO 形式）
- 每拍 dout_vld=1 时：
  - 若是 pair 的第一个 → 缓存到 holder
  - 若是 pair 的第二个 → 与 holder 弹出的第一个拼成 256-bit + pop meta entry → 合成 beat 入合并 async FIFO #2
- SRAM 保证 dout 顺序与发读顺序一致（FIFO 保序）

### 流控
- fetch 发 ren 的条件（全部满足）：
  - 有 tile 待读（done_info 队列非空 + 当前 tile 未读完）
  - 当前周期 `writer_wen == 0`（写优先）
  - read meta FIFO 不满
  - 合并 async FIFO #2 写侧 credit > 0（容量节流）

### tile word 数说明
- UBWC tile 固定 = 256 byte
- SRAM 内存储：16 × 128-bit word
- V1 输出：8 × 256-bit beat（每 beat = 2 SRAM word）
- 所以一个 tile 在 V1 输出端 = **8 拍 256-bit data**（不是 16 拍）
- `o_tile_last` 在第 8 拍拉起

### mask 生成（预计算）
- 输入：
  - `i_cfg_width / i_cfg_height` 按 tile 对齐后的尺寸（fixed tile 存储）
  - `i_cfg_active_width / i_cfg_active_height` 真实图像尺寸
  - `done_info.y_rows_actual / uv_rows_b0/b1_actual` 末组实际行数（partial 情形）
- 算法：超出 active 范围 **或** 超出 actual_rows 的像素位 → keep=0
- **mask 字节粒度**：`o_tile_keep[31:0]` 共 32 bit，对应 256-bit 数据 = 32 byte，**1 bit 控制 1 byte 的有效性**
- mask 完全由 cfg + 当前 tile 坐标 + done_info 行数决定，与数据无关 → 发读时即可算出

### forced_pcm（预计算，分 Y / UV 两路）
- **Y tile**：`forced_pcm = OR(~mask_of_Y_tile)`
- **UV tile**：`forced_pcm = OR(~mask_of_UV_tile)`
- 各 tile 自己的 ci 命令携带自己的 forced_pcm（一个 tile 出一笔 ci）
- 在发读拍即可算出，**不需要等到数据回来再判定**

### ci / tile 输出粒度
- **1 个 tile ⇔ 1 笔 ci 命令 + 1 个 tile data 帧（即 1 个 rvi 帧）**
- 1 个 tile data 帧 = 8 拍 256-bit data（256 byte / 32 byte）
- ci 命令搭载在 tile 首拍（sof=1），与 tile 数据走同一个合并 async FIFO
- Y tile 和 UV tile 是**两个独立 tile**，各自一笔 ci + 一帧 rvi

### tile 坐标
- 在发读时同步算出 `o_tile_x / o_tile_y`
- 与 mask、forced_pcm 一起推入 read meta FIFO

### UV tile 跨 bank 拼读（YUV420 only）
- fetcher 收到 **单个 UV_done（在 bank1 写完时发出）**即触发 UV tile 读 — writer 已替 fetcher 做完配对，不需要 fetcher 自己等"一对"
- **UV tile 跨 2 个 Y 行组**：
  - YUV420_8：UV tile = 8 UV 行 = 16 Y 行 = 2 个 Y 行组
  - YUV420_10：UV tile = 4 UV 行 = 8 Y 行 = 2 个 Y 行组
- 读策略：
  - 前半 tile：从 bank0 读 UV slot
  - 后半 tile：从 bank1 读 UV slot
  - 实际 slot 是 UV_A 还是 UV_B：与 writer 写入时一致（uv_slot 字段随 done_info 一起到来）
- **末组孤立处理**（最后 Y 组是奇数 → 没有配对 bank1）：
  - **仍按完整 tile SRAM 读发起**（前半 bank0，后半 bank1）
  - bank1 没数据 → 读出 garbage，但 mask 已把这部分 keep=0
  - 这样 fetcher 路径无需特殊分支，逻辑更顺

### Y tile / UV tile 输出顺序
- **按 done_info FIFO 顺序消费 → 输出 Y Y UV 三联模式**：
  - bank0 写完 Y → Y_done(bank0) → 出 Y tile
  - bank1 写完 Y → Y_done(bank1) → 出 Y tile
  - bank1 写完 UV → UV_done → 出跨 bank UV tile
  - 下一对：Y Y UV ...
- fetcher 内部维护 done_info 接收 FIFO，串行消费
- 同一时刻只输出一个 tile（一个 ci + 8 拍 256-bit data 走完才下一个）

### Y / UV tile_y 坐标系
- `o_tile_y`：tile 在垂直方向的索引
- **Y tile_y**：Y 行组数（每组 8 行 Y），即 Y tile 行号
- **UV tile_y**：UV 行组数（每 UV tile = 8 UV 行 = 2 Y 行组）
- 关系：**UV tile_y = Y tile_y / 2**（因为 1 个 UV tile 跨 2 个 Y 行组）

### fcnt 与 sb
- fcnt 由 **writer 维护并通过 done_info 传入**（fetcher 不自己计数）
- fetcher 直接使用 `done_info.fcnt` 作为 `o_tile_fcnt`
- `o_ci_sb = fcnt[0]`（最低位作为 ping-pong 标识传给下游）
- **sb 在帧内所有 tile 之间是常数**（同一帧的所有 ci 命令 sb 都相同），帧间切换

### 帧边界（下游侧）
- V1 **不显式输出 frame_done 信号**给下游
- 下游用 `tile_x` / `tile_y` 坐标自行判断帧结束：
  - 当 tile_y 越过 max_y 或 tile_x/tile_y 回到 (0, 0) 时 → 帧切换
  - 结合 fcnt 变化（下一帧首 tile 的 fcnt 已 +1）做确认
- 简化 V1 接口，避免额外控制线

### 读地址推进
- 严格按 `i_cfg_y_tile_cols` 和 `i_cfg_uv_tile_cols` 推进
- 每个 tile 内按固定 word 数推进（256-bit / word × tile 列数）

---

## 5. 输出接口（合并 1 个跨域 FIFO + SOF）

CI 命令与 TILE 数据**合并到一个跨域 async FIFO**，用 SOF（start-of-tile）标志区分：

```
FIFO entry 载荷：
  sof           (1 bit, =1 表示本拍是该 tile 第一拍，搭载 ci 命令字段)
  tile_data     (256 bit)
  tile_keep     (32 bit)
  tile_last     (1 bit)
  tile_stat_*   (3 bit)
  --- ci 字段（仅 sof=1 时有效）---
  forced_pcm    (1 bit)
  sb            (SB_WIDTH bit)
  tile_x / y    (16+16 bit)
  fcnt / format (4+5 bit)
```

下游侧从 FIFO 弹出后 demux：
- `sof==1` 拍：把 ci 字段 latch 出来驱动 `o_ci_*`，同时 tile 数据走 `o_tile_*`
- `sof==0` 拍：只驱动 `o_tile_*`

### 下游握手约束
- **下游必须保证 `i_ci_ready` 与 `i_tile_rdy` 同时 high** 才会发生 pop
- 即：sof=1 拍上 demux 只在 `i_ci_ready & i_tile_rdy` 都 1 时 pop FIFO entry
- sof=0 拍上只看 `i_tile_rdy`
- 这是 V1 对下游的协议要求；下游 ENC 主路保证这一点

### 顶层端口（保持 wrapper 接口不变）
| 组 | 信号 | 宽度 |
|---|---|---|
| CI | `o_ci_valid / i_ci_ready / o_ci_forced_pcm / o_ci_sb` | 1/1/1/SB_WIDTH |
| CI | `o_tile_x / o_tile_y / o_tile_fcnt / o_tile_format` | 16/16/4/5 |
| TILE | `o_tile_vld / i_tile_rdy / o_tile_data / o_tile_keep / o_tile_last` | 1/1/256/32/1 |
| TILE | `o_tile_stat_valid / o_tile_stat_last / o_tile_stat_slot` | 1/1/1 |

---

## 6. 时钟域汇总

```
┌─────────────────┐  async FIFO #1   ┌──────────────────────────────────────┐  async FIFO #2     ┌────────────┐
│  otf_clk        │  data + lcnt    │  core_clk                            │  ci + tile + sof   │            │
│  otf_monitor    │ ──────────────► │  writer (维护 fcnt) + bank0/1 +      │ ─────────────────► │  axi_clk   │
│  (OTF fcnt 内部)│  (fcnt 不入)    │  fetcher (使用 writer 的 fcnt)       │  (合并 1 路)       │  ci+tile   │
│  err → 中断     │                 │  (writer ↔ bank ↔ fetcher 同域)       │                    │  demux     │
└─────────────────┘                 └──────────────────────────────────────┘                    └────────────┘
```

时钟域命名与现行 `ubwc_enc_otf_to_tile_top` wrapper 端口一致。

跨域 FIFO 仅 2 个：
- #1：OTF clk → 核心 clk，载荷 = data + lcnt + vsync + tlast
- #2：核心 clk → 下游 clk，载荷 = ci 字段 + tile 字段 + sof

---

## 7. 与现行实现的差异

| 现行 (`ubwc_enc_otf_to_tile_top` + `ubwc_enc_line_to_tile`) | V1 |
|---|---|
| OTF 采集、地址生成、ping-pong 写、tile 读出耦合在一个大模块 | 拆三个子模块，各管一段 |
| 帧连续性无显式检测 | otf_monitor 显式监测 fcnt 跳变并定位 |
| OTF 端 fcnt 直接透传，OTF fcnt 不连续会引起下游异常 | OTF fcnt 不外传，下游用自维护 4-bit fcnt，OTF 端容错 |
| Y/UV 数据共用同一个 fire 仲裁路径 | Y/RGBA 与 UV 走两个独立小 FIFO，再合并到 1 个写小 FIFO |
| 读侧没有专门的 fetch FIFO（直连 SRAM dout） | fetcher 显式 read meta FIFO + fetch FIFO，配对预计算 metadata |
| mask 在数据采集阶段做，分散 | mask 集中到 fetcher 发读时**预计算** |
| forced_pcm 由数据驱动判定 | forced_pcm **预计算**，与 ci 命令同拍出 |
| 输出 ci/tile 在 wrapper 内同步对齐 | ci+tile 合并 1 个跨域 FIFO，用 sof 标志 — 不存在跨域错位风险 |

---

## 8. SRAM 存储布局（与现行设计一致）

详见配套图：[ubwc_enc_sram_layout_cn.svg](./ubwc_enc_sram_layout_cn.svg)

外部工作 SRAM：bank0 / bank1 同规格，单 bank = 4096 word × 128 bit = 64 KiB，两 bank 合计 128 KiB。SRAM 容量由最大支持宽度（4096 px）决定，图像高度通过多次行组处理复用同一组 SRAM。

### 格式映射（4096 px 宽度时的 word 占用）

| 格式 | 每行字节/字 | 行组（rows × words） | Y 子区 | UV_A | UV_B | 利用率 |
|---|---|---|---|---|---|---|
| RGBA8888 / RGBA10 | 16 KiB / 1024w | 4 行 × 1024w | — | — | — | 4096w（占满，无 UV 子区） |
| YUV420_8 (NV12)   | Y: 4 KiB / 256w · UV: 4 KiB / 256w | Y 8 行 + UV 4 行 | 2048w (0..2048) | 1024w (2048..3072) | 1024w (3072..4096) | 4096w（占满） |
| YUV420_10 (P010/G016) | Y: 8 KiB / 512w · UV: 8 KiB / 512w | Y 4 行 + UV 2 行 | 2048w (0..2048) | 1024w (2048..3072) | 1024w (3072..4096) | 4096w（占满，区域同 YUV8） |

### 关键调度

- **RGBA**：4 行行组占满一个 bank，bank0/bank1 轮流为当前工作 bank；bank 不固定为某个 plane
- **YUV420**（8/10 共用同一布局）：
  - Y 固定在 0..2048 区
  - UV_A (2048..3072) 与 UV_B (3072..4096) 双 slot
  - **每个 bank 装一个 Y 行组的 Y + 对应的 UV**
    - YUV420_8：bank 存 8 行 Y + 4 行 UV；Y tile = 32 × 8 行；UV tile（cross-bank）= 32 × 8 行
    - YUV420_10 (P010)：bank 存 4 行 Y + 2 行 UV；**Y tile = 16 × 4 行；UV tile（cross-bank）= 16 × 4 行**
  - **UV tile 必须跨 2 个 bank 拼读**（每 bank 只存 UV tile 的一半 = 行组高度的 UV）
  - **UV_A / UV_B**：相邻两对 Y 组的 UV 占用不同 slot — 当 UV_A 还在被读时，UV_B 已开始写下一对 UV
  - UV slot 选择由 `group_id[1]` 决定（与现行 line_to_tile 一致）
  - **fetcher 默认**：UV_done 到达 → 跨 bank 拼读 UV tile（前半从 bank0，后半从 bank1）
  - 软件**不需要**配置 UV_A/UV_B；只需配置每帧 UBWC base address，配对读 / 交替写由硬件自调度
- YUV420_10 与 YUV420_8 区域大小**完全一致**（单 bank 4096w），仅 tile 行数减半（每行字数翻倍）

## 9. FIFO 深度与 IP 选型

### FIFO IP 选型（与 `CODE_STYLE.md` 一致）
- **跨域 FIFO 全部用 `mg_async_fifo`**
- **同域 FIFO 全部用 `mg_sync_fifo`**
- 这两个 IP 源码不允许改动；不允许自写或引入其他 FIFO

### 深度

| FIFO | IP | 深度 | 备注 |
|---|---|---|---|
| Async FIFO #1（otf_clk→core_clk） | `mg_async_fifo` | 16 | 吸收 OTF 突发与 core 处理节奏差 |
| Y / UV 小 FIFO | `mg_sync_fifo` | ≥ 4 | 解耦地址生成与合并仲裁的处理段 |
| 合并写小 FIFO | `mg_sync_fifo` | ≥ 4 | 吸收 Y/UV 合并的瞬时不均衡 |
| read meta FIFO | `mg_sync_fifo` | ≥ 4 | 配合 SRAM 读延迟 ≤4 变长 |
| dout pair holder | `mg_sync_fifo` | ≥ 4 entry | 多对 (addr_lo, addr_hi) 在飞 + 变长延迟 |
| done_info FIFO（writer→fetcher） | `mg_sync_fifo` | 8 | 缓冲 done_info 序列 |
| Async FIFO #2（core_clk→vivo_clk） | `mg_async_fifo` | 16 | 吸收下游背压；按 tile=8 输出 beat 估 |

**注**：SRAM 读延迟 ≤4 拍**最长**（变长），dout_vld 由 SRAM macro 自身产出。

## 9.5 V1 顶层端口处理总览（与现行 `ubwc_enc_otf_to_tile_top` 接口）

| 端口 | V1 处理 |
|---|---|
| `clk / i_otf_clk / i_vivo_clk` | 对应三时钟域 |
| `rst_n_sys / rst_n_otf / rst_n_vivo` | 各自时钟域复位 |
| `i_start_pulse` | **保留，V1 不使用**（writer 由 vsync 自驱动） |
| `i_cfg_*` | 各模块**按需引入**（otf_monitor 用 width/active_*；writer 用 format/tile_h/width/active；fetcher 用 active/tile_cols） |
| `i_cfg_*` 更新时机 | **帧间锁存**（vsync 之间） |
| `o_err_bline / o_err_bframe / o_err_fifo_ovf` | V1 内部统一 → 任何错误触发同一中断（**不细分类型**） |
| `o_err_*` 性质 | **sticky**，软件通过 `i_err_clear` 清 |
| `i_err_clear` | 1 拍脉冲清 err latch |
| OTF 接口 (vsync/hsync/de/data/fcnt/lcnt/ready) | 全部 otf_monitor 处理 |
| Bank0/1 接口 (en/wen/addr/din/dout/dout_vld) | **顶层 mux** 仲裁；`dout_vld` 由 SRAM macro 给 |
| `o_tile_* / o_ci_*` | fetcher 产生 → 合并 async FIFO #2 → vivo_clk 域输出 |
| `o_tile_stat_valid / stat_last / stat_slot` | **V1 暂不实现**，输出 0 |
| `i_co_valid` | **保留并使用**（vivo 端同步信号） |
| 参数 SB_WIDTH / TH_DW / TW_DW | 保留默认值，与现行一致 |

## 10. 已敲定项汇总

| 项 | 结论 |
|---|---|
| V1 范围 | 替换 `ubwc_enc_otf_to_tile_top`；接口不变 |
| 时钟域 | otf_clk / core_clk / axi_clk |
| OTF 接口 | `i_otf_data[127:0]` · 128-bit/拍 · vsync/hsync/de · fcnt[3:0] · lcnt[11:0] · ready |
| OTF 字节排布 | **与现行 `ubwc_enc_otf_to_tile_top.v` 完全一致**，V1 不引入新约定 |
| OTF plane | `lcnt[0]` 分流：偶带 UV / 奇仅 Y |
| otf_monitor 定位 | **OTF 异常隔离层**：fcnt / lcnt / 横向对齐 等异常全部在此检出 |
| 横向对齐 | 必须对齐，不对齐 = 错误 → otf_monitor 起中断 |
| err 起中断 | otf_monitor 检出异常拉 `o_err`；**writer 不停**，等软件处理 |
| fcnt 归属 | writer 自维护（vsync +1），随 done_info 传 fetcher |
| sb 与帧 | `sb = fcnt[0]`，**同帧内所有 tile sb 相同**，帧间切换 |
| cfg 锁存 | **帧间改**（vsync 之间），不在帧中改 |
| Y/UV 合并仲裁 | word 级交替；每拍 pop ≤1 |
| bank mux 位置 | 顶层 `otf_to_tile_top` 内；对 SRAM 侧输出寄存 1 拍 |
| **写优先门控** | **fetcher 自己看 writer_wen，wen=1 时不发 ren 不 push meta**（meta 与读 1:1） |
| **dout_vld 来源** | **SRAM macro 自身产出**（不能用 pipe 算，因延迟 ≤4 变长） |
| bank release | **1 拍脉冲**（writer latch）；按**一整行 tiles** 读完才发 |
| Y_release | 一行 Y tiles（tile_x 0..cfg_y_tile_cols-1）全读完 → 释放该 bank Y 区 |
| UV_release | 一行 UV tiles 全读完 → **同时释放 BANK0 + BANK1 的该 slot**（A 或 B） |
| SRAM 宽度 | 128-bit/word；fetcher 2 次读拼 256-bit 输出 beat |
| SRAM 读延迟 | ≤4 拍**最长**（变长，不固定）+ mux 1 拍寄存 |
| **dout pair holder** | **≥4 entry**（FIFO 形式，覆盖多对在飞 + 变长延迟） |
| 每 tile 输出 | 8 拍 256-bit data + 1 笔 ci（首拍 sof=1） |
| 下游握手 | `i_ci_ready & i_tile_rdy` 同时 high 才 pop |
| tile 输出顺序 | 按 done_info FIFO 序：Y Y UV 三联 |
| **末组孤立 UV tile** | **按完整 tile 16 SRAM 读发起**（bank1 那 8 读 garbage，mask 处理）；逻辑顺，无特殊分支 |
| mask 粒度 | 1 bit / byte（32 bit ↔ 32 byte） |
| forced_pcm | 分 Y / UV 两路；每 tile 一笔 ci 各带 |
| SOF | tile 首拍 sof=1 |
| frame_start | 暂保留不用 |
| 帧边界 | 下游用 tile_x / tile_y 自己判断，V1 不显式给 frame_done |
| UV tile_y | Y tile_y / 2 |
| UV tile_x 对齐 | 必须对齐 cfg_uv_tile_cols；不对齐 → otf_monitor 错 |
| writer 拆 3 子块 | writer_in / writer_addr / writer_ctl |
| format 编码 | 参照现行 `ubwc_enc_otf_to_tile_top.v` 的 `o_tile_format[4:0]` |
| read meta entry | 1 entry ↔ 1 个 256-bit 输出 beat；push 在 addr_hi 那拍 |
| **复位** | 每个时钟域用自己的复位（rst_n_otf / rst_n_sys / rst_n_vivo） |
| **err 类型** | 不细分，**任意错误统一触发 1 个中断**，sticky，软件 i_err_clear 清 |
| **err 期间** | writer 硬件不主动停；fetcher 不发新读，backpressure 自然卡 writer；软件介入 rst_n_sys 复位 core 域 |
| **start_pulse** | 保留但 V1 不使用；writer 由 vsync 直接驱动 |
| **stat_*** | V1 暂不实现，输出 0 |
| **co_valid** | 保留并使用（vivo 端同步） |
| **cfg 端口** | 各模块按需引入；**帧间锁存** |
| **writer 重用 bank 条件** | `(bank.Y 已释放) AND (目标 UV slot 已释放)`；目标 slot 由新组 group_id[1] 决定 |
| **Async FIFO 深度** | #1 (otf→core) = 16；#2 (core→vivo) = 16 |

## 11. 后续讨论（未来扩展）

- 如果需要扩到 4 bank 提高 throughput，bank-writer 仲裁逻辑需要同步调整
