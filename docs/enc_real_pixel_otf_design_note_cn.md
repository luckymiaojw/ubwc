# ENC OTF 真实像素输入改造记录

日期：2026-05-27

## 背景

旧流程中，ENC OTF 输入侧更偏向按 stored/padded 画布推进，例如 720x1548 RGBA8888 需要外部补齐到 768x1552 后再送入。这个做法会把 padding 行/列变成输入契约的一部分，不利于软件和上游模块直接按真实像素输出。

本次讨论确定：ENC 输入数据应是真实有效像素，内部按照真实像素边界处理，padding 只作为 tile/layout 输出边界的 mask，而不是要求上游真实送入无效像素。

## 设计原则

1. `i_otf_de && o_otf_ready` 接收的应是真实像素数据。
2. 行结束可由两类事件确定：
   - `i_otf_lcnt` 切换，表示上游进入下一行；
   - 当前行累计像素达到配置的 active width，表示本行结束。
3. 当当前行未凑满一个 tile 或一个内部 packing group，但已经达到行尾时，立即 flush 当前 line/tile 数据。
4. 对超出 active width/height 的无效像素，不作为有效数据处理；输出到 `ubwc_enc_otf_to_tile` 后续链路时必须通过 `keep/mask` 屏蔽。
5. Metadata 的有效边界与 tile 数据一致，均由 active width/height 驱动 partial tile/forced PCM/keep 生成。
6. Stored width/height 仍用于 layout、tile 列数、pitch、metadata pitch 和最终 UBWC buffer 地址空间计算；但 OTF 输入流不再要求送 stored padding 数据。
7. 存储格式计算以 `vrf/src/ubwc_demo.cpp` 和 `vrf/vector/enc_from_mdss_zp_TajMahal_4096x600_nv12/Readme.txt` 为基准。
8. YUV420 的 stored height 按 UV plane 对齐后反推 Y plane：`stored_uv_height = align(ceil(active_height / 2), tile_h * 4)`，`stored_y_height = 2 * stored_uv_height`。例如 4096x600 NV12 中 UV stored height 为 320，Y stored height 为 640，与基准 ReadMe 一致。
9. Metadata plane size 先按需要的 meta 行数计算，再按 4KB 对齐；因此 ReadMe 中会出现 `Height for Meta Data P0 : 96 (need 80)` 这种“实际分配行数大于需要行数”的情况。

## RTL 执行方向

1. `ubwc_enc_otf_data_packer` 增加 active width/height 输入。
2. packer 在 OTF clock 域内用一拍 pending buffer 延迟提交 beat，从而可以在看到下一拍 `lcnt` 变化时给上一拍补上 `tlast`。
3. packer 根据当前行剩余有效像素计算 `tkeep`，在最后一拍屏蔽无效 lane。
4. `ubwc_enc_otf_to_tile` 将 `i_cfg_active_width/i_cfg_active_height` 传入 packer；active 为 0 时回退到 `i_cfg_width/i_cfg_height`。
5. `ubwc_enc_line_to_tile` 后续继续消费 `{fcnt,lcnt,vsync,hsync,tlast,tkeep,tdata}`，不再假设每行都有 stored padding beat。
6. 最后一个 tile/group 允许少于完整 tile 高度；RTL 根据 active height 推导最后一组 Y/UV 有效行数，行尾到达后直接允许读侧处理。
7. `ubwc_enc_otf_to_tile` 输出边界按 tile 坐标和 word 序号生成 byte mask，并与 line-to-tile 内部的半高 UV mask 相与后输出到 `o_tile_keep`。
8. YUV420 输入相位按“第一行带 UV、第二行不带 UV”处理，后续逐行交替。

## 验证要求

1. RGBA8888：720x1548 输入只送真实 720x1548 数据，确认不死锁，tile/meta 输出数量与 active tile 数一致，边界 keep 正确。
2. NV12/P010：验证第一行带 UV、第二行不带 UV 的输入组织；最后一行/最后一列 partial 时不能消耗无效 padding。
3. 回归既要覆盖 stored 对齐输入，也要覆盖真实像素输入，确保旧 case 不回退。
