# tb_ubwc_dec_tile_to_otf_tajmahal_cases

说明：

- 顶层 `make ...` 现在会自动转发到 `vrf/sim/Makefile`
- 顶层 `make ...` 和 `vrf/sim/ca_xxx` 入口现在都会先加载 `prj_setup.env`
- 所有 verify 产物统一落在 `vrf/sim/build/`

`CASE_ID` 对应关系：

- `0`: `RGBA8888 tiled`
- `1`: `RGBA1010102 tiled`
- `2`: `RGBA8888 linear-in`
- `3`: `NV12 tiled`

使用 `tcsh` 加载工程环境后，运行 TajMahal OTF case 的 `CASE_ID=3`（NV12）流程：

```bash
tcsh -c 'source prj_setup.env; make otf_tajmahal_cases_comp CASE_ID=3'
tcsh -c 'source prj_setup.env; make otf_tajmahal_cases_run CASE_ID=3'
tcsh -c 'source prj_setup.env; make compare_otf_tajmahal_cases CASE_ID=3'
tcsh -c 'source prj_setup.env; make otf_tajmahal_cases_verdi CASE_ID=3'
```

说明：

- `comp`: 编译 testbench
- `run`: 运行仿真
- `compare`: 比较生成的 OTF 输出和 golden
- `verdi`: 打开波形

# tb_ubwc_dec_meta_data_gen_tajmahal_cases

`CASE_ID` 对应关系：

- `0`: `RGBA8888`
- `1`: `RGBA1010102`
- `2`: `NV12`

默认小窗口 metadata 回归：

```bash
tcsh -c 'source prj_setup.env; make meta_tajmahal_cases_all CASE_ID=0'
tcsh -c 'source prj_setup.env; make meta_tajmahal_cases_all CASE_ID=1'
tcsh -c 'source prj_setup.env; make meta_tajmahal_cases_all CASE_ID=2'
```

如果你在自己的机器上用 `vcs` 分步跑，建议直接走下面这组命令。
在 `zsh` 里不要直接 `source prj_setup.env`，因为这个环境脚本是 `tcsh/csh` 语法，所以统一用 `tcsh -c 'source prj_setup.env; ...'`：

```bash
tcsh -c 'source prj_setup.env; make meta_tajmahal_cases_comp CASE_ID=0'
tcsh -c 'source prj_setup.env; make meta_tajmahal_cases_run CASE_ID=0'
tcsh -c 'source prj_setup.env; make meta_tajmahal_cases_verdi CASE_ID=0'
```

把 `CASE_ID` 改成下面之一即可：

- `0`: `RGBA8888`
- `1`: `RGBA1010102`
- `2`: `NV12`

full-window metadata 回归：

```bash
tcsh -c 'source prj_setup.env; make meta_tajmahal_4096x600_rgba8888_full_all'
tcsh -c 'source prj_setup.env; make meta_tajmahal_4096x600_rgba1010102_full_all'
tcsh -c 'source prj_setup.env; make meta_tajmahal_4096x600_nv12_full_all'
```

如果你想用 `vcs` 分步跑 full-window，也可以这样：

```bash
tcsh -c 'source prj_setup.env; make TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 CASE_ID=0 CASE_TILE_X_NUMBERS=256 CASE_TILE_Y_NUMBERS=152 prepare_meta_tajmahal_case'
tcsh -c 'source prj_setup.env; make TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 CASE_TILE_X_NUMBERS=256 CASE_TILE_Y_NUMBERS=152 comp'
tcsh -c 'source prj_setup.env; make TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 CASE_TILE_X_NUMBERS=256 CASE_TILE_Y_NUMBERS=152 run'
tcsh -c 'source prj_setup.env; make TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 CASE_TILE_X_NUMBERS=256 CASE_TILE_Y_NUMBERS=152 verdi'
```

另外两组 full-window 直接替换 `TOP` 和 tile 数：

- `RGBA1010102`: `TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102`，`CASE_TILE_X_NUMBERS=256`，`CASE_TILE_Y_NUMBERS=152`
- `NV12`: `TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12`，`CASE_TILE_X_NUMBERS=128`，`CASE_TILE_Y_NUMBERS=80`

说明：

- `CASE_TILE_X_NUMBERS` / `CASE_TILE_Y_NUMBERS` 现在表示真实 image tile 数，不再是旧的 8x8 command/group 数
- `RGBA8888 full-window`: `CASE_TILE_X_NUMBERS=256`，`CASE_TILE_Y_NUMBERS=152`
- `RGBA1010102 full-window`: `CASE_TILE_X_NUMBERS=256`，`CASE_TILE_Y_NUMBERS=152`
- `NV12 full-window`: `CASE_TILE_X_NUMBERS=128`，`CASE_TILE_Y_NUMBERS=80`
- `NV12` 这组里 `CASE_TILE_Y_NUMBERS` 表示 Y plane 的 tile 行数，UV plane 会在 testbench / expected model 里按 `ceil(Y/2)` 推导
- full-window 模式保留了 `expected_fifo_stream.txt` 文件级 compare

# Wrapper All 命令总表

如果你现在只想跑 `all` 版本，推荐直接用这一节。

说明：

- 所有命令都默认用 `tcsh` 加载 `prj_setup.env`
- 如果你在远端服务器上需要显式指定 Python，可写成：
  `tcsh -c 'source prj_setup.env; make PYTHON=python3.11 ...'`
- `dec` 这边用 `fake/real`
- `enc` 这边用 `fake/non-fake`

## DEC wrapper

fake mode：

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_rgba8888_vivo_fake_all'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_rgba1010102_vivo_fake_all'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_vivo_fake_all'
tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_fake_all'
```

real mode：

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_rgba8888_vivo_real_all'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_rgba1010102_vivo_real_all'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_vivo_real_all'
tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_real_all'
```

当前状态：

- `fake`：4 个 vector 都通过
- `real`：4 个 vector 都能跑到 compare，但当前 `ubwc_dec_vivo_top` 还是 fake decompressor，所以 `RVO/OTF` 内容比对不过

## ENC wrapper

fake mode：

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_fake_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba1010102_fake_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_nv12_fake_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_fake_all'
```

non-fake mode：

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_nonfake_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba1010102_nonfake_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_nv12_nonfake_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_nonfake_all'
```

当前状态：

- `fake`：4 个 vector 都通过
- `non-fake`：4 个 vector 都能跑到 compare，但当前 `ubwc_enc_vivo_top` 还是 passthrough/fake encoder，所以 `compressed data / metadata` 内容比对不过

## NV12 单独跑法

如果你现在只想单独跑 `NV12` 的 `dec` 和 `enc`，直接用这一节就够了。

DEC NV12：

```bash
# fake all
tcsh -c 'source prj_setup.env; make -C vrf/sim wrapper_tajmahal_4096x600_nv12_vivo_fake_all'

# real all
tcsh -c 'source prj_setup.env; make -C vrf/sim wrapper_tajmahal_4096x600_nv12_vivo_real_all'

# fake verdi
tcsh -c 'source prj_setup.env; make -C vrf/sim WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_vivo_verdi'

# real verdi
tcsh -c 'source prj_setup.env; make -C vrf/sim WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_nv12_vivo_verdi'
```

如果你看的是 `NV12 OTF` 那条专门 compare flow：

```bash
# fake all
tcsh -c 'source prj_setup.env; make -C vrf/sim wrapper_tajmahal_4096x600_nv12_otf_fake_all'

# fake verdi
tcsh -c 'source prj_setup.env; make -C vrf/sim wrapper_tajmahal_4096x600_nv12_otf_fake_verdi'
```

ENC NV12：

```bash
# fake all
tcsh -c 'source prj_setup.env; make -C vrf/sim enc_wrapper_tajmahal_4096x600_nv12_fake_all'

# nonfake all
tcsh -c 'source prj_setup.env; make -C vrf/sim enc_wrapper_tajmahal_4096x600_nv12_nonfake_all'

# fake verdi
tcsh -c 'source prj_setup.env; make -C vrf/sim TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 verdi'

# nonfake verdi
tcsh -c 'source prj_setup.env; make -C vrf/sim enc_wrapper_tajmahal_4096x600_nv12_verdi'
```

如果你更喜欢脚本方式，也可以这样：

```bash
./vrf/sim/open_wave.sh dec nv12 fake
./vrf/sim/open_wave.sh dec nv12 real
./vrf/sim/open_wave.sh dec nv12_otf fake
./vrf/sim/open_wave.sh enc nv12 fake
./vrf/sim/open_wave.sh enc nv12 nonfake
```

模式对应关系：

- `dec`：`fake / real`
- `enc`：`fake / nonfake`

## 便捷脚本

如果你不想每次手敲整串 `make`，现在可以直接用这两个脚本：

```bash
./vrf/sim/run_fake_all.sh
./vrf/sim/open_wave.sh dec nv12 fake
```

`run_fake_all.sh`：

```bash
./vrf/sim/run_fake_all.sh
./vrf/sim/run_fake_all.sh dec
./vrf/sim/run_fake_all.sh enc
./vrf/sim/run_fake_all.sh dec --dry-run
```

说明：

- `all`：按顺序跑 `DEC fake + ENC fake`
- `dec`：只跑 decoder fake `_all`
- `enc`：只跑 encoder fake `_all`
- `--dry-run`：只打印命令，不真正执行

`open_wave.sh`：

```bash
./vrf/sim/open_wave.sh dec rgba8888 fake
./vrf/sim/open_wave.sh dec nv12_otf fake
./vrf/sim/open_wave.sh enc nv12 fake
./vrf/sim/open_wave.sh enc g016 nonfake
./vrf/sim/open_wave.sh encdec nv12
```

说明：

- `dec` 支持：`rgba8888` / `rgba1010102` / `nv12` / `g016` / `nv12_otf`
- `enc` 支持：`rgba8888` / `rgba1010102` / `nv12` / `g016`
- `encdec` 目前只支持：`nv12`
- `dec` 的模式可选：`fake` / `real`
- `enc` 的模式可选：`fake` / `nonfake`
- 脚本内部会自动定位工程根目录，并用 `tcsh/csh` 加载 `prj_setup.env`

# tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12

这组 wrapper testbench 使用下面这些 vector：

- metadata Y: `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out2.txt`
- metadata UV: `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out3.txt`
- tiled Y: `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in0.txt`
- tiled UV: `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in1.txt`
- linear golden Y: `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_pack10_out0.txt`
- linear golden UV: `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_pack10_out1.txt`

这条 flow 里：

- metadata 通过 `ubwc_dec_meta_data_gen -> ubwc_dec_tile_arcmd_gen`
- tile payload 强制按 `full-payload` 方式读出
- `ubwc_dec_vivo_top` 把 CI/CVI 直接送给 `ubwc_dec_tile_to_otf`
- 最后把 OTF 输出和 linear golden 做 compare

单帧 fake mode 直接跑：

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_fake_all'
```

单帧 non-fake mode 直接跑：

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_real_all'
```

如果你更习惯带变量，也可以写成：

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_otf_all'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_nv12_otf_all'
```

其中：

- `fake` 会把 tile 输入切到 `Tiled Uncompressed`
- `real` 会把 tile 输入切到 `Tiled Compressed`
- 两种模式都会把 decoder OTF 输出和 linear golden 对比

如果你想分步跑：

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_prepare'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_comp'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_fake_run'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_real_run'
tcsh -c 'source prj_setup.env; make compare_wrapper_tajmahal_4096x600_nv12_otf'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_fake_verdi'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_real_verdi'
```

连续多帧回归可以直接给 bench 透传 `tb_frame_repeat`：

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_otf_run RUN_ARGS=\"+tb_frame_repeat=3\"'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_nv12_otf_run RUN_ARGS=\"+tb_frame_repeat=3\"'
```

如果你是想直接跑 [tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12.sv](/Users/magic.jw/Desktop/ubwc_dec/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12.sv) 这个 case，本质上就用上面这组命令：

- 单帧 fake：`tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_fake_all'`
- 单帧 non-fake：`tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_real_all'`
- 复现多帧问题：`tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_otf_run RUN_ARGS=\"+tb_frame_repeat=3\"'`

如果你是要专门复现 [tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12.sv:492](/Users/magic.jw/Desktop/ubwc_dec/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12.sv#L492) 的 `wait_wrapper_idle` 报错，推荐直接跑上一条 fake 3-frame 命令。

说明：

- 多帧模式下，bench 会连续触发多次 `meta_start`
- `run` 阶段的 testbench 会逐 beat 做内部 compare
- `compare_wrapper_tajmahal_4096x600_nv12_otf` 目前仍按单帧 `actual_otf_stream.txt` 处理，所以多帧推荐看 `run.log` 里的 PASS/FAIL

结果文件位置：

- 仿真输出: `build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12/actual_otf_stream.txt`
- compare 结果目录: `build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12/compare`
- 运行日志: `build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12/run.log`

当前这条 wrapper NV12 OTF 回归已经验证通过：

- `OTF mismatches : 0`
- `AR addr mismatches : 0`

# tb_ubwc_dec_wrapper_top_tajmahal_cases / 4096x600 aliases

这组是现在推荐的 `ubwc_dec_wrapper_top` TajMahal 统一回归入口，对应：

- `tb_ubwc_dec_wrapper_top_tajmahal_cases`
- `tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888`
- `tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102`
- `tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12`

`CASE_ID` 对应关系：

- `0`: `RGBA8888`
- `1`: `RGBA1010102`
- `2`: `NV12`

这条统一 flow 现在的语义是：

- `AXI READ` 输入固定使用 `Metadata` + `Tiled Compressed Image`
- fake mode：另外把 `Tiled Uncompressed Image` 直接送到 `ubwc_dec_tile_to_otf`，并把 `OTF` 输出与 `Linear Image` 比较
- real mode：保留 `AXI READ` 为 compressed，另外把 `Tiled Uncompressed Image` 作为 `ubwc_dec_vivo_top` 输出参考，并把 `OTF` 输出与 `Linear Image` 比较

说明：

- fake / real 的切换变量仍然沿用 `WRAPPER_NV12_VIVO_MODE=fake|real`
- `wrapper_tajmahal_cases_prepare` 会自动准备：
- `input_meta_plane*.txt` ← `ubwc_enc_out2/out3`
- `input_tile_plane*.txt` ← `ubwc_enc_out0/out1`
- `inject_tile_plane*.txt` ← `ubwc_enc_in0/in1`
- `expected_otf_stream.txt` ← `Linear Image`

直接跑统一 case bench：

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=1'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=2'
```

real mode 对应：

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=1'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=2'
```

如果你只是想直接照着跑 real mode，推荐按下面这个顺序：

```bash
# 1) RGBA8888
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=0'

# 2) RGBA1010102
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=1'

# 3) NV12
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=2'
```

也可以分步跑 real mode：

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_cases_prepare CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_cases_comp CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_cases_run CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_cases_verdi CASE_ID=0'
```

把 `CASE_ID` 改成 `1/2` 就是 `RGBA1010102 / NV12`。real mode 跑完后，建议优先看这些输出文件：

- `wrapper_compare_summary.txt`
- `wrapper_tajmahal_vivo_*.txt`
- `wrapper_tajmahal_vivo_expected_*.txt`
- `actual_otf_stream.txt`
- `expected_otf_stream.txt`

如果你更喜欢直接跑 alias bench，也可以这样：

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_rgba8888_vivo_all'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_rgba8888_vivo_all'

tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_rgba1010102_vivo_all'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_rgba1010102_vivo_all'

tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_vivo_all'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_nv12_vivo_all'
```

分步跑统一 flow：

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_cases_prepare CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_cases_comp CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_cases_run CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_cases_verdi CASE_ID=0'
```

把 `CASE_ID` 改成 `1/2` 即可；real mode 只要把变量换成 `WRAPPER_NV12_VIVO_MODE=real`。

关键 compare 输出文件：

- fake mode：
- injected tile trace：`wrapper_tajmahal_inject_*.txt`
- injected tile expected：`wrapper_tajmahal_inject_expected_*.txt`
- actual OTF：`actual_otf_stream.txt`
- expected OTF：`expected_otf_stream.txt`
- summary：`wrapper_compare_summary.txt`
- real mode：
- actual RVO：`wrapper_tajmahal_vivo_*.txt`
- expected RVO：`wrapper_tajmahal_vivo_expected_*.txt`
- actual OTF：`actual_otf_stream.txt`
- expected OTF：`expected_otf_stream.txt`
- summary：`wrapper_compare_summary.txt`

补充：

- `NV12 / G016(P010)` 现在会额外把 `RVO` 按 plane 分开落盘，方便直接和 vector 比较
- 例如 `NV12` 会生成：
  - `wrapper_tajmahal_vivo_nv12_y.txt`
  - `wrapper_tajmahal_vivo_nv12_uv.txt`
  - `wrapper_tajmahal_vivo_expected_nv12_y.txt`
  - `wrapper_tajmahal_vivo_expected_nv12_uv.txt`
- `G016` 会生成：
  - `wrapper_k_outdoor61_vivo_g016_y.txt`
  - `wrapper_k_outdoor61_vivo_g016_uv.txt`
  - `wrapper_k_outdoor61_vivo_expected_g016_y.txt`
  - `wrapper_k_outdoor61_vivo_expected_g016_uv.txt`
- fake mode 同样会生成对应的 `fake_vivo_*_y.txt / fake_vivo_*_uv.txt`

最容易混的地方：

- 跑 `NV12` 时，只能看 `NV12` 自己的输出文件；不要用 `G016` 的命令去验证 `NV12`
- fake mode 要看带 `fake` 的文件名
- real mode 才看不带 `fake` 的文件名
- `expected_*_y/uv.txt` 现在是按整面 tiled memory image 导出的，所以可以直接和原始 vector 比

直接对照关系：

- `NV12 fake`
  - 命令：`tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_vivo_fake_all'`
  - 目录：`build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12_fake/`
  - Y compare：
    - `wrapper_tajmahal_fake_vivo_expected_nv12_y.txt`
    - `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in0.txt`
  - UV compare：
    - `wrapper_tajmahal_fake_vivo_expected_nv12_uv.txt`
    - `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in1.txt`

- `NV12 real`
  - 命令：`tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_vivo_real_all'`
  - 目录：`build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12_real/`
  - Y compare：
    - `wrapper_tajmahal_vivo_expected_nv12_y.txt`
    - `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in0.txt`
  - UV compare：
    - `wrapper_tajmahal_vivo_expected_nv12_uv.txt`
    - `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in1.txt`

- `G016 fake`
  - 命令：`tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_fake_all'`
  - 目录：`build/tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016_fake/`
  - Y compare：
    - `wrapper_k_outdoor61_fake_vivo_expected_g016_y.txt`
    - `enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_in0.txt`
  - UV compare：
    - `wrapper_k_outdoor61_fake_vivo_expected_g016_uv.txt`
    - `enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_in1.txt`

- `G016 real`
  - 命令：`tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_real_all'`
  - 目录：`build/tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016_real/`
  - Y compare：
    - `wrapper_k_outdoor61_vivo_expected_g016_y.txt`
    - `enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_in0.txt`
  - UV compare：
    - `wrapper_k_outdoor61_vivo_expected_g016_uv.txt`
    - `enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_in1.txt`

这些文件都生成在对应 build 目录下，例如：

- `build/tb_ubwc_dec_wrapper_top_tajmahal_cases_fake/`
- `build/tb_ubwc_dec_wrapper_top_tajmahal_cases_real/`
- `build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888_fake/`
- `build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888_real/`
- `build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102_fake/`
- `build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102_real/`
- `build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12_fake/`
- `build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12_real/`
- `build/tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016_fake/`
- `build/tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016_real/`

当前状态：

- fake mode 已本地验证通过：
- `RGBA8888`: pass
- `RGBA1010102`: pass
- `NV12`: pass
- real mode 的命令、向量准备和 compare 通路都已经接好
- 如果当前 `ubwc_dec_vivo_top.v` 仍然是 fake packer，实现级 real compare 结果会受它影响

# tb_ubwc_dec_wrapper_top_tajmahal_rgba8888

这是较早的单独 wrapper bench，保留用于看 `RGBA8888` 的 OTF dump。

直接跑：

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_rgba8888_all'
```

分步跑：

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_rgba8888_comp'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_rgba8888_run'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_rgba8888_verdi'
```

说明：

- 这条旧 flow 固定读取：
- metadata：`visual_from_mdss_writeback_4_wb_2_rec_0_verify_ubwc_enc_out2.txt`
- tile：`visual_from_mdss_writeback_4_wb_2_rec_0_verify_ubwc_enc_in0.txt`
- 它没有独立的 fake / real mode 开关，也不做现在这套统一的 `vivo + OTF + linear` 双 compare
- 如果你要跑当前推荐的 fake / real wrapper 回归，请优先用上一节的 `tb_ubwc_dec_wrapper_top_tajmahal_cases` 或 `wrapper_tajmahal_4096x600_rgba8888_vivo_all`

# tb_ubwc_enc_wrapper_top_tajmahal_cases

这组 encoder wrapper bench 走的是：

- `Linear data` 先转成 `OTF stream`
- 通过 `ubwc_enc_wrapper_top`
- fake mode 下，当前 `ubwc_enc_vivo_top` 输出按 `Tiled Uncompressed` 检查
- non-fake mode 下，testbench 会改为：
- `Meta` 输出对比 `Metadata RGB/Y-plane` 和 `Metadata UV-plane`
- `Compressed data` 输出对比 `Tiled Compressed Image RGB/Y-plane` 和 `Tiled Compressed Image UV-plane`

fake mode 推荐直接跑：

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba1010102_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_nv12_all'
```

fake mode 分步跑也可以：

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_comp'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_run'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_verdi'
```

如果要切到 non-fake mode，给 `run/all` 透传 `RUN_ARGS="+tb_non_fake_mode"` 即可：

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_all RUN_ARGS="+tb_non_fake_mode"'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba1010102_all RUN_ARGS="+tb_non_fake_mode"'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_nv12_all RUN_ARGS="+tb_non_fake_mode"'
```

non-fake mode 分步跑示例：

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_comp'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_run RUN_ARGS="+tb_non_fake_mode"'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_verdi'
```

说明：

- `comp` 只编译，不区分 fake / non-fake
- `run` 或 `all` 带上 `RUN_ARGS="+tb_non_fake_mode"` 后，TB 会自动装载对应 TajMahal vector 的 compressed / metadata reference
- `RGBA8888` 和 `RGBA1010102` 只比较 `Y/RGB` 一路 compressed 和 metadata
- `NV12` 会同时比较 `Y` / `UV` 两路 compressed，以及 `Y` / `UV` 两路 metadata

当前验证结果：

- fake mode
- `RGBA8888`: pass
- `RGBA1010102`: pass
- `NV12`: pass
- non-fake mode
- testbench 的 compressed / metadata checker 已接好
- 当前如果 `ubwc_enc_vivo_top` 仍然是 fake 实现，non-fake mode 会按预期报 mismatch

# tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016

这组 encoder wrapper bench 使用：

- vector 目录：`enc_from_mdss_01000007_k_outdoor61_4096x600_g016`
- 图像格式：`G016 / YUV420 10bit`
- `Actual Image Size`: `4096x600`
- `Aligned Height for Pixel Data P0`: `608`
- `Aligned Height for Pixel Data P1`: `304`
- `Pitch for Pixel Data P0/P1`: `8192 bytes`

这组 case 当前已经接进：

- `TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016`
- `Makefile` 目标：`enc_wrapper_k_outdoor61_4096x600_g016_*`

推荐直接跑：

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_all'
```

分步跑：

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_comp'
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_run'
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_verdi'
```

如果要直接跑 fake mode，当前建议这样：

```bash
tcsh -c 'source prj_setup.env; make TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 enc_wrapper_tajmahal_cases_prepare'
tcsh -c 'source prj_setup.env; make TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 all'
```

如果要显式跑 non-fake mode：

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_all RUN_ARGS="+tb_non_fake_mode"'
```

当前验证结果：

- fake mode
- `coord_count = 29184`
- `aw_mismatch_count = 0`
- `range_mismatch_cnt = 0`
- `meta_aw_count_y/uv = 2560 / 1536`
- `rvi_data_mismatch = 0`
- `cvo_data_mismatch = 0`
- fake mode 已通过 `layout / address / count` 检查
- non-fake mode
- `rvi -> uncompressed tile` 能过
- `cvo -> compressed tile` checker 已接好
- 当前 `ubwc_enc_vivo_top` 仍是 passthrough/fake，实现上还不是真实 encoder，所以 non-fake mode 会按预期报 `compressed / metadata` mismatch

结果文件位置：

- fake: `build/tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016/`
- non-fake: `build/tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016/`
- main Y dump: `tb_ubwc_enc_wrapper_top_k_outdoor61_g016_*_main_y_mem.txt`
- main UV dump: `tb_ubwc_enc_wrapper_top_k_outdoor61_g016_*_main_uv_mem.txt`
- meta Y dump: `tb_ubwc_enc_wrapper_top_k_outdoor61_g016_*_meta_y_mem.txt`
- meta UV dump: `tb_ubwc_enc_wrapper_top_k_outdoor61_g016_*_meta_uv_mem.txt`

# tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12

这组联调 bench 走的是：

- `Linear data -> OTF -> ubwc_enc_wrapper_top`
- encoder 当前 `fake ubwc_enc_vivo_top` 输出 `Tiled Uncompressed`
- decoder 用 `enc_from_mdss_zp_TajMahal_4096x600_nv12` 的 metadata
- `ubwc_dec_wrapper_top` 直接从 encoder 写出的 `tile Y/UV` memory 读回
- 最后把 decoder OTF 输出和 linear golden 做 compare

推荐直接跑：

```bash
tcsh -c 'source prj_setup.env; make encdec_wrapper_tajmahal_4096x600_nv12_all'
```

分步跑：

```bash
tcsh -c 'source prj_setup.env; make encdec_wrapper_tajmahal_4096x600_nv12_prepare'
tcsh -c 'source prj_setup.env; make encdec_wrapper_tajmahal_4096x600_nv12_comp'
tcsh -c 'source prj_setup.env; make encdec_wrapper_tajmahal_4096x600_nv12_run'
tcsh -c 'source prj_setup.env; make compare_encdec_wrapper_tajmahal_4096x600_nv12_otf'
tcsh -c 'source prj_setup.env; make encdec_wrapper_tajmahal_4096x600_nv12_verdi'
```

结果文件位置：

- 仿真输出: `build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/actual_otf_stream.txt`
- compare 结果目录: `build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/compare`
- 运行日志: `build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/run.log`

当前这条 `NV12 enc+dec wrapper` 联调已经验证通过：

- `enc AW addr mismatch : 0`
- `dec AR addr mismatch : 0`
- `otf mismatch count : 0`
- `compare mismatch beats : 0`

# tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016

这组 decoder wrapper case 使用：

- vector 目录：`enc_from_mdss_01000007_k_outdoor61_4096x600_g016`
- base format：`YUV420 10bit / P010-like packed OTF`
- 图像宽度：`4096`
- Y stored height：`608`
- UV stored height：`304`
- tile pitch：`8192 bytes`
- 4-line format：`enable`

推荐直接跑 fake mode：

```bash
tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_all'
```

如果要显式跑 real mode：

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_CASES_TB_REAL_VIVO_MODE=1 wrapper_k_outdoor61_4096x600_g016_vivo_all'
```

分步命令：

```bash
tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_comp'
tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_run'
tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_verdi'
```

当前验证结果：

- fake mode
- `AR addr mismatches = 0`
- `AR len mismatches = 0`
- `RVO data mismatches = 0`
- `RVO last mismatches = 0`
- `OTF mismatches = 0`
- 这条 case 在当前 TB 里对 G016/P010 加了轻微 `i_otf_ready` backpressure，fake mode 已通过

- real mode
- `AR addr mismatches = 0`
- `AR len mismatches = 0`
- `RVO data mismatches = 230400`
- `OTF mismatches = 622592`
- 当前 `ubwc_dec_vivo_top` 还不是实际解压实现，所以 real mode 的 `RVO/OTF` 内容 compare 会按预期失败

结果文件位置：

- fake / real 输出目录：`build/tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016/`
- fake RVO dump：`wrapper_k_outdoor61_fake_vivo_g016.txt`
- fake OTF dump：`actual_otf_stream.txt`
- real RVO dump：`wrapper_k_outdoor61_vivo_g016.txt`
- compare summary：`wrapper_compare_summary.txt`
