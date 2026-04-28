# UBWC Verification Quick Start

本文只保留当前常用的 wrapper 级仿真入口，并把 decoder / encoder 分开说明。历史 standalone 单元用例、metadata 单元用例和手工 VCS 分步说明不再放在根目录 README；需要时直接查看 `vrf/sim/Makefile`。

## 环境

工程环境脚本是 `prj_setup.env`，它使用 `tcsh/csh` 语法。不要在 `zsh/bash` 里直接 `source prj_setup.env`，推荐以下两种方式：

```bash
# 在工程根目录执行，顶层 Makefile 会自动进入 vrf/sim 并加载环境
make <target>

# 或显式进入仿真目录
tcsh -c 'source prj_setup.env; make -C vrf/sim <target>'
```

所有仿真产物默认放在：

```text
vrf/sim/build/
```

VCS 默认打开 `+define+FSDB`，对应 case 的 `.fsdb` 会留在各自 build 子目录中。`verdi` 目标会优先打开该目录下已有的 `.fsdb`。

## 一键回归

常用 fake-mode 回归脚本：

```bash
./vrf/sim/run_fake_all.sh          # DEC fake + ENC fake
./vrf/sim/run_fake_all.sh dec      # 只跑 decoder fake
./vrf/sim/run_fake_all.sh enc      # 只跑 encoder fake
./vrf/sim/run_fake_all.sh dec --dry-run
```

当前 fake-all 范围：

- DEC: `RGBA8888`、`RGBA1010102`、`NV12`、`G016`、`NV12 OTF`
- ENC: `RGBA8888`、`RGBA1010102`、`NV12`、`G016`

## Decoder 仿真

Decoder wrapper 支持 `fake` 和 `real` 两种模式：

- `fake`: 使用未压缩 tile 数据，适合当前主回归。
- `real`: 使用压缩数据路径；当前 vivo decompressor 仍是 fake/stub 时，可能能跑到 compare，但内容比较不代表最终真实解压能力。

### DEC Fake

```bash
make wrapper_tajmahal_4096x600_rgba8888_vivo_fake_all
make wrapper_tajmahal_4096x600_rgba1010102_vivo_fake_all
make wrapper_tajmahal_4096x600_nv12_vivo_fake_all
make wrapper_k_outdoor61_4096x600_g016_vivo_fake_all
make wrapper_tajmahal_4096x600_nv12_otf_fake_all
```

### DEC Real

```bash
make wrapper_tajmahal_4096x600_rgba8888_vivo_real_all
make wrapper_tajmahal_4096x600_rgba1010102_vivo_real_all
make wrapper_tajmahal_4096x600_nv12_vivo_real_all
make wrapper_k_outdoor61_4096x600_g016_vivo_real_all
make wrapper_tajmahal_4096x600_nv12_otf_real_all
```

### DEC 波形

```bash
make wrapper_tajmahal_4096x600_rgba8888_vivo_verdi
make wrapper_tajmahal_4096x600_rgba1010102_vivo_verdi
make wrapper_tajmahal_4096x600_nv12_vivo_verdi
make wrapper_k_outdoor61_4096x600_g016_vivo_verdi
make wrapper_tajmahal_4096x600_nv12_otf_verdi
```

也可以使用脚本打开常用波形：

```bash
./vrf/sim/open_wave.sh dec rgba8888 fake
./vrf/sim/open_wave.sh dec rgba1010102 fake
./vrf/sim/open_wave.sh dec nv12 fake
./vrf/sim/open_wave.sh dec g016 fake
./vrf/sim/open_wave.sh dec nv12_otf fake
```

## Encoder 仿真

Encoder wrapper 支持 `fake` 和 `nonfake` 两种模式：

- `fake`: wrapper 主回归模式，输入 OTF stream，检查 tile / metadata 地址、计数、strobe 和输出一致性。
- `nonfake`: 打开 `+tb_non_fake_mode`；当前 vivo encoder 仍是 passthrough/fake 时，compressed data / metadata 内容比较可能失败。

### ENC Fake

```bash
make enc_wrapper_tajmahal_4096x600_rgba8888_fake_all
make enc_wrapper_tajmahal_4096x600_rgba1010102_fake_all
make enc_wrapper_tajmahal_4096x600_nv12_fake_all
make enc_wrapper_k_outdoor61_4096x600_g016_fake_all
```

### ENC Nonfake

```bash
make enc_wrapper_tajmahal_4096x600_rgba8888_nonfake_all
make enc_wrapper_tajmahal_4096x600_rgba1010102_nonfake_all
make enc_wrapper_tajmahal_4096x600_nv12_nonfake_all
make enc_wrapper_k_outdoor61_4096x600_g016_nonfake_all
```

### ENC 波形

```bash
make enc_wrapper_tajmahal_4096x600_rgba8888_verdi
make enc_wrapper_tajmahal_4096x600_rgba1010102_verdi
make enc_wrapper_tajmahal_4096x600_nv12_verdi
make enc_wrapper_k_outdoor61_4096x600_g016_verdi
```

也可以使用脚本打开常用波形：

```bash
./vrf/sim/open_wave.sh enc rgba8888 fake
./vrf/sim/open_wave.sh enc rgba1010102 fake
./vrf/sim/open_wave.sh enc nv12 fake
./vrf/sim/open_wave.sh enc g016 fake
```

## ENC-DEC 联合用例

当前保留一个 NV12 wrapper 级联通用例：

```bash
make encdec_wrapper_tajmahal_4096x600_nv12_all
make encdec_wrapper_tajmahal_4096x600_nv12_verdi
```

## 常用文件

- `vrf/sim/Makefile`: 仿真目标定义。
- `vrf/sim/run_fake_all.sh`: DEC/ENC fake-mode 批量回归脚本。
- `vrf/sim/open_wave.sh`: 常用波形打开脚本。
- `src/flist/filelist.f`: Decoder wrapper 默认 RTL filelist。
- `src/flist/filelist_enc.f`: Encoder wrapper RTL filelist。
- `src/flist/filelist_encdec.f`: ENC-DEC 联合用例 filelist。
