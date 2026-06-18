# UBWC ENC/DEC VIVO Function Coverage Test Plan

本文定义 `ubwc_enc_vivo_top` 和 `ubwc_dec_vivo_top` 的功能覆盖与 directed test plan。覆盖模型以功能行为为中心，不按坐标点做覆盖。

## 1. 覆盖范围

| 模块 | 采样位置 | 主要检查 |
|---|---|---|
| ENC | `ubwc_enc_wrapper_top.sv` 内部 VIVO 接口侧 | OTF 进入后形成的 CI/RVI 是否正确，VIVO 输出的 CO/CVO 是否与 metadata/compressed golden 一致 |
| DEC | `ubwc_dec_wrapper_top.v` 内部 VIVO 接口侧 | AXI 读出的 metadata/compressed data 进入 VIVO 后，CO/RVO 是否与 decoder golden 一致 |

Checker 只采样 VIVO 端口，不引用 fake VIVO 内部 memory、reg 或 wire。这样后续替换真实 VIVO 代码时，测试结构仍然可复用。

## 2. 功能覆盖模型

| Coverpoint | 范围 | 覆盖 bins | 通过标准 |
|---|---|---|---|
| Format | ENC/DEC | RGBA8888、RGBA1010102、NV12 Y、NV12 UV、P010/G016 Y、P010/G016 UV | 每个格式/plane 在对应 VIVO valid&&ready 事务中至少命中一次 |
| Alen | ENC/DEC | `alen=0..7` | 每个 alen bin 至少命中一次；payload beat、mask、last 与 alen 规则一致 |
| Meta flag | DEC 主覆盖，ENC metadata compare 辅助覆盖 | normal、padding/invalid、force-full、fastclear、solid color | flag 与 metadata decode 结果一致，并驱动正确的 alen/payload 行为 |
| DEC solid color | DEC | raw metadata `[7:6] != 0` | 有效 tile 命中 SC；decode 后 flag/alen 行为正确，RVO 与 decoder golden 一致 |
| DEC fastclear | DEC | raw metadata `[7:6]==0 && [4]==0` | 有效 tile 命中 FC；不误取普通 compressed payload，RVO 与 decoder golden 一致 |
| DEC constant alpha | DEC RGBA | `alpha_mode=00/01/10/11`，constant alpha 与 non-constant alpha | `i_ci_alpha_mode` 与 metadata decode 一致；RGBA PCM/constant-alpha 的 alen 和 payload 行为正确 |
| Resolution | ENC/DEC | small、非整 tile、max width、large lossy 等分辨率类别 | 每类分辨率至少 ENC/DEC 各跑一帧；非整 tile 不死锁，padding 不进入有效输出 |
| Lossy mode | ENC/DEC | lossless、NV12 lossy、RGBA8888 lossy 2:1 | lossy 地址、metadata、payload 与对应 golden/规则一致 |

## 3. 坐标口径

`xcoord/ycoord/fcnt` 不作为 functional coverage bin。它们只用于：

| 用途 | 说明 |
|---|---|
| Golden lookup | 根据 format、plane、x/y 找 metadata、compressed tile、uncompressed tile |
| 地址计算校验 | 定位 tile address、meta address、4KB split 等错误 |
| Debug dump | 对比失败时打印 first mismatch 的时间、frame、x、y、beat、expected、actual |

坐标覆盖不作为 closure 条件，避免把测试目标变成“穷举每个 tile 坐标”。

## 4. ENC Directed Tests

| TC ID | 测试目标 | 覆盖项 | 推荐 case/vector | 通过标准 |
|---|---|---|---|---|
| ENC-FUNC-001 | 覆盖所有 format | Format | 0055-0058、0061-0066 | CI/RVI/CVO format 命中所有格式和 Y/UV plane |
| ENC-FUNC-002 | CO alen 与 CVO payload 长度 | Alen | metadata 覆盖集 | 每个 alen bin 的 CVO beat/mask/last 与规则一致 |
| ENC-FUNC-003 | Metadata 写出 | Meta flag | 0061-0066 | AXI metadata dump 与 golden/规则一致；padding 区域不误报特殊模式 |
| ENC-FUNC-004 | NV12 lossy | Format、Lossy | NV12 lossy vector | 地址仍按 NV12 Y/UV layout，不走 RGBA2:1 分支 |
| ENC-FUNC-005 | RGBA8888 lossy 2:1 | Lossy、Alen | RGBA8888 lossy vector | 地址按 RGBA2:1 规则；payload 与 compressed golden 一致 |
| ENC-FUNC-006 | 分辨率类别 | Resolution | 128x128、256x160、720x1548、4096x600、3840x2016 | active size、边界 mask、frame done/idle 正确 |
| ENC-FUNC-007 | Backpressure smoke | 协议辅助检查 | 任意两种格式 | ready 拉低时 data/control stable，无丢 tile、无重复 tile |

## 5. DEC Directed Tests

| TC ID | 测试目标 | 覆盖项 | 推荐 case/vector | 通过标准 |
|---|---|---|---|---|
| DEC-FUNC-001 | 覆盖所有 format | Format | 0055-0058、0061-0066 | CI/CVI/RVO format 命中所有格式和 Y/UV plane |
| DEC-FUNC-002 | Metadata decode 到 alen | Alen、Meta flag | metadata 覆盖集 | `i_ci_alen=0..7` 命中；CVI/RVO payload 行为正确 |
| DEC-FUNC-003 | Solid color | DEC solid color | 含有效 SC tile 的 vector | SC tile flag/alen 正确，RVO 与 decoder golden 一致 |
| DEC-FUNC-004 | Fastclear | DEC fastclear | 含有效 FC tile 的 vector | FC tile 不误取普通 payload，RVO 与 decoder golden 一致 |
| DEC-FUNC-005 | Constant alpha | DEC constant alpha | RGBA metadata 覆盖集 | `i_ci_alpha_mode` 与 metadata decode 一致；constant/non-constant alpha 行为正确 |
| DEC-FUNC-006 | Lossy decoder | Lossy | NV12 lossy、RGBA8888 lossy vector | 使用 decoder golden 比较，不与 encoder 原始 linear 做错误 bit-exact 比较 |
| DEC-FUNC-007 | 分辨率类别 | Resolution | 128x128、256x160、720x1548、4096x600、3840x2016 | OTF 输出有效宽高正确；最后一行后 FIFO/status idle |
| DEC-FUNC-008 | Backpressure / AXI delay smoke | 协议辅助检查 | 任意两种格式 | CI/CVI/RVO 不丢不重，last 不提前 |

## 6. Closure 条件

| 项目 | 关闭条件 |
|---|---|
| Format | ENC/DEC 各自命中所有 format bins，Y/UV plane 分开统计 |
| Alen | `alen=0..7` 全部命中，且 payload beat/mask/last 检查通过 |
| Meta flag | normal、padding/invalid、force-full、fastclear、solid color 全部命中 |
| DEC 特殊模式 | solid color、fastclear、constant alpha 都必须在有效 tile 中命中 |
| Resolution | 每个分辨率类别至少 ENC/DEC 各一帧通过 |
| Lossy | NV12 lossy 和 RGBA8888 lossy 2:1 均通过对应 golden/规则 |
| Coordinates | 不要求覆盖率；只作为 lookup/debug 信息输出 |
