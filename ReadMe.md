# tb_ubwc_dec_tile_to_otf_tajmahal_cases

Notes:

- Top-level `make ...` now automatically forwards to `vrf/sim/Makefile`
- Top-level `make ...` and `vrf/sim/ca_xxx` entry points now load `prj_setup.env`
- All verify artifacts are placed under `vrf/sim/build/`

`CASE_ID` mapping:

- `0`: `RGBA8888 tiled`
- `1`: `RGBA1010102 tiled`
- `2`: `RGBA8888 linear-in`
- `3`: `NV12 tiled`

 `tcsh` to load the project environment, Run TajMahal OTF case   `CASE_ID=3`(NV12)flow:

```bash
tcsh -c 'source prj_setup.env; make otf_tajmahal_cases_comp CASE_ID=3'
tcsh -c 'source prj_setup.env; make otf_tajmahal_cases_run CASE_ID=3'
tcsh -c 'source prj_setup.env; make compare_otf_tajmahal_cases CASE_ID=3'
tcsh -c 'source prj_setup.env; make otf_tajmahal_cases_verdi CASE_ID=3'
```

Notes:

- `comp`: Compile the testbench
- `run`: Run simulation
- `compare`: Compare the generated OTF output against golden
- `verdi`: Open waveform

# tb_ubwc_dec_meta_data_gen_tajmahal_cases

`CASE_ID` mapping:

- `0`: `RGBA8888`
- `1`: `RGBA1010102`
- `2`: `NV12`

Default small-window metadata regression:

```bash
tcsh -c 'source prj_setup.env; make meta_tajmahal_cases_all CASE_ID=0'
tcsh -c 'source prj_setup.env; make meta_tajmahal_cases_all CASE_ID=1'
tcsh -c 'source prj_setup.env; make meta_tajmahal_cases_all CASE_ID=2'
```

If you run `vcs` step by step, the following commands are recommended.
Do not directly run `source prj_setup.env` in `zsh`, because this environment script uses `tcsh/csh` syntax. Use `tcsh -c 'source prj_setup.env; ...'` instead:

```bash
tcsh -c 'source prj_setup.env; make meta_tajmahal_cases_comp CASE_ID=0'
tcsh -c 'source prj_setup.env; make meta_tajmahal_cases_run CASE_ID=0'
tcsh -c 'source prj_setup.env; make meta_tajmahal_cases_verdi CASE_ID=0'
```

Change `CASE_ID` to one of the following:

- `0`: `RGBA8888`
- `1`: `RGBA1010102`
- `2`: `NV12`

Full-window metadata regression:

```bash
tcsh -c 'source prj_setup.env; make meta_tajmahal_4096x600_rgba8888_full_all'
tcsh -c 'source prj_setup.env; make meta_tajmahal_4096x600_rgba1010102_full_all'
tcsh -c 'source prj_setup.env; make meta_tajmahal_4096x600_nv12_full_all'
```

If you want to run full-window with `vcs` step by step, you can also use:

```bash
tcsh -c 'source prj_setup.env; make TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 CASE_ID=0 CASE_TILE_X_NUMBERS=256 CASE_TILE_Y_NUMBERS=152 prepare_meta_tajmahal_case'
tcsh -c 'source prj_setup.env; make TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 CASE_TILE_X_NUMBERS=256 CASE_TILE_Y_NUMBERS=152 comp'
tcsh -c 'source prj_setup.env; make TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 CASE_TILE_X_NUMBERS=256 CASE_TILE_Y_NUMBERS=152 run'
tcsh -c 'source prj_setup.env; make TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba8888 CASE_TILE_X_NUMBERS=256 CASE_TILE_Y_NUMBERS=152 verdi'
```

For the other two full-window cases, directly replace `TOP` and the tile counts:

- `RGBA1010102`: `TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_rgba1010102`, `CASE_TILE_X_NUMBERS=256`, `CASE_TILE_Y_NUMBERS=152`
- `NV12`: `TOP=tb_ubwc_dec_meta_data_gen_tajmahal_4096x600_nv12`, `CASE_TILE_X_NUMBERS=128`, `CASE_TILE_Y_NUMBERS=80`

Notes:

- `CASE_TILE_X_NUMBERS` / `CASE_TILE_Y_NUMBERS` now represent the real image tile counts, rather than the old 8x8 command/group counts
- `RGBA8888 full-window`: `CASE_TILE_X_NUMBERS=256`, `CASE_TILE_Y_NUMBERS=152`
- `RGBA1010102 full-window`: `CASE_TILE_X_NUMBERS=256`, `CASE_TILE_Y_NUMBERS=152`
- `NV12 full-window`: `CASE_TILE_X_NUMBERS=128`, `CASE_TILE_Y_NUMBERS=80`
- `NV12` case `CASE_TILE_Y_NUMBERS` represents the Y-plane tile row count, UV plane is derived in the testbench / expected model using `ceil(Y/2)`
- full-window mode keeps `expected_fifo_stream.txt` file-level compare

# Wrapper All Command Summary

If you only want to run the `all` targets, use this section.

Notes:

- All commands use `tcsh` to load `prj_setup.env`
- If you need to explicitly specify Python on the remote server, write:
  `tcsh -c 'source prj_setup.env; make PYTHON=python3.11 ...'`
- `dec` uses `fake/real`
- `enc` uses `fake/non-fake`

## DEC wrapper

fake mode:

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_rgba8888_vivo_fake_all'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_rgba1010102_vivo_fake_all'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_vivo_fake_all'
tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_fake_all'
```

real mode:

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_rgba8888_vivo_real_all'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_rgba1010102_vivo_real_all'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_vivo_real_all'
tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_real_all'
```

Current status:

- `fake`:4 vectors pass
- `real`:4 vectors can reach compare, but the current `ubwc_dec_vivo_top` is still fake decompressor, so `RVO/OTF` content comparison fails

## ENC wrapper

fake mode:

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_fake_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba1010102_fake_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_nv12_fake_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_fake_all'
```

non-fake mode:

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_nonfake_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba1010102_nonfake_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_nv12_nonfake_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_nonfake_all'
```

Current status:

- `fake`:4 vectors pass
- `non-fake`:4 vectors can reach compare, but the current `ubwc_enc_vivo_top` is still passthrough/fake encoder, so `compressed data / metadata` content comparison fails

## NV12 Standalone Run Method

If you only want to run `NV12`   `dec` and `enc`, this section is enough.

DEC NV12:

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

If you are looking at `NV12 OTF` dedicated compare flow:

```bash
# fake all
tcsh -c 'source prj_setup.env; make -C vrf/sim wrapper_tajmahal_4096x600_nv12_otf_fake_all'

# fake verdi
tcsh -c 'source prj_setup.env; make -C vrf/sim wrapper_tajmahal_4096x600_nv12_otf_fake_verdi'
```

ENC NV12:

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

If you prefer scripts, you can also use:

```bash
./vrf/sim/open_wave.sh dec nv12 fake
./vrf/sim/open_wave.sh dec nv12 real
./vrf/sim/open_wave.sh dec nv12_otf fake
./vrf/sim/open_wave.sh enc nv12 fake
./vrf/sim/open_wave.sh enc nv12 nonfake
```

Mode mapping:

- `dec`:`fake / real`
- `enc`:`fake / nonfake`

## Convenience Scripts

If you do not want to type the full `make`, you can now directly use these two scripts:

```bash
./vrf/sim/run_fake_all.sh
./vrf/sim/open_wave.sh dec nv12 fake
```

`run_fake_all.sh`:

```bash
./vrf/sim/run_fake_all.sh
./vrf/sim/run_fake_all.sh dec
./vrf/sim/run_fake_all.sh enc
./vrf/sim/run_fake_all.sh dec --dry-run
```

Notes:

- `all`:runs in order `DEC fake + ENC fake`
- `dec`:runs only decoder fake `_all`
- `enc`:runs only encoder fake `_all`
- `--dry-run`: prints commands only and does not execute them

`open_wave.sh`:

```bash
./vrf/sim/open_wave.sh dec rgba8888 fake
./vrf/sim/open_wave.sh dec nv12_otf fake
./vrf/sim/open_wave.sh enc nv12 fake
./vrf/sim/open_wave.sh enc g016 nonfake
./vrf/sim/open_wave.sh encdec nv12
```

Notes:

- `dec` supports:`rgba8888` / `rgba1010102` / `nv12` / `g016` / `nv12_otf`
- `enc` supports:`rgba8888` / `rgba1010102` / `nv12` / `g016`
- `encdec` currently supports only:`nv12`
- `dec` mode options are:`fake` / `real`
- `enc` mode options are:`fake` / `nonfake`
- The script automatically locates the project root and uses `tcsh/csh` to load `prj_setup.env`

# tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12

This wrapper testbench the following vectors:

- metadata Y: `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out2.txt`
- metadata UV: `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out3.txt`
- tiled Y: `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in0.txt`
- tiled UV: `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in1.txt`
- linear golden Y: `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_pack10_out0.txt`
- linear golden UV: `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_pack10_out1.txt`

In this flow:

- metadata through `ubwc_dec_meta_data_gen -> ubwc_dec_tile_arcmd_gen`
- tile payload is forced to read in `full-payload` mode
- `ubwc_dec_vivo_top` export CI/CVI directly sends to `ubwc_dec_tile_to_otf`
- Finallyexport OTF output is compared against the linear golden

Single-frame fake mode direct run:

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_fake_all'
```

Single-frame non-fake mode direct run:

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_real_all'
```

If you prefer using variables, you can also write:

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_otf_all'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_nv12_otf_all'
```

Among them,:

- `fake` switches tile input to `Tiled Uncompressed`
- `real` switches tile input to `Tiled Compressed`
- Both modes compare the decoder OTF output against the linear golden

If you want to run step by step:

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_prepare'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_comp'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_fake_run'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_real_run'
tcsh -c 'source prj_setup.env; make compare_wrapper_tajmahal_4096x600_nv12_otf'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_fake_verdi'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_real_verdi'
```

For continuous multi-frame regression, pass directly to the bench `tb_frame_repeat`:

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_otf_run RUN_ARGS=\"+tb_frame_repeat=3\"'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_nv12_otf_run RUN_ARGS=\"+tb_frame_repeat=3\"'
```

If you want to directly run [tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12.sv](/Users/magic.jw/Desktop/ubwc_dec/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12.sv), it essentially uses the command set above:

- Single-frame fake:`tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_fake_all'`
- Single-frame non-fake:`tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_otf_real_all'`
- Reproduce the multi-frame issue:`tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_otf_run RUN_ARGS=\"+tb_frame_repeat=3\"'`

If you specifically want to reproduce the `wait_wrapper_idle` error at [tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12.sv:492](/Users/magic.jw/Desktop/ubwc_dec/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12.sv#L492), directly run the previous fake 3-frame command.

Notes:

- In multi-frame mode, bench continuously triggers multiple `meta_start`
- `run` stage testbench performs internal compare beat by beat
- `compare_wrapper_tajmahal_4096x600_nv12_otf` currently still handles single-frame `actual_otf_stream.txt` processing, sofor multi-frame runs, check `run.log` PASS/FAIL

Result file locations:

- Simulation output: `build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12/actual_otf_stream.txt`
- Compare result directory: `build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12/compare`
- Run log: `build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12/run.log`

This wrapper NV12 OTF regression has been verified to pass:

- `OTF mismatches : 0`
- `AR addr mismatches : 0`

# tb_ubwc_dec_wrapper_top_tajmahal_cases / 4096x600 aliases

This is the currently recommended `ubwc_dec_wrapper_top` TajMahal unified regression entry, corresponding to:

- `tb_ubwc_dec_wrapper_top_tajmahal_cases`
- `tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888`
- `tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102`
- `tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12`

`CASE_ID` mapping:

- `0`: `RGBA8888`
- `1`: `RGBA1010102`
- `2`: `NV12`

The current semantics of this unified flow are:

- `AXI READ` input is fixed `Metadata` + `Tiled Compressed Image`
- fake mode: additionally sends `Tiled Uncompressed Image` directly to `ubwc_dec_tile_to_otf`, and compares the `OTF` output against `Linear Image`
- real mode:keeps `AXI READ` as compressed, additionally sends `Tiled Uncompressed Image` as `ubwc_dec_vivo_top` output reference, and `OTF` output with `Linear Image` compare

Notes:

- fake / real mode switch variable still uses `WRAPPER_NV12_VIVO_MODE=fake|real`
- `wrapper_tajmahal_cases_prepare` automatically prepares:
- `input_meta_plane*.txt` ← `ubwc_enc_out2/out3`
- `input_tile_plane*.txt` ← `ubwc_enc_out0/out1`
- `inject_tile_plane*.txt` ← `ubwc_enc_in0/in1`
- `expected_otf_stream.txt` ← `Linear Image`

Directly run the unified case bench:

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=1'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=2'
```

real mode corresponding to:

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=1'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=2'
```

If you just want to run real mode directly, use the following order:

```bash
# 1) RGBA8888
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=0'

# 2) RGBA1010102
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=1'

# 3) NV12
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real TOP=tb_ubwc_dec_wrapper_top_tajmahal_cases wrapper_tajmahal_cases_all CASE_ID=2'
```

You can alsostep by step real mode:

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_cases_prepare CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_cases_comp CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_cases_run CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_cases_verdi CASE_ID=0'
```

Change `CASE_ID` to `1/2`, meaning `RGBA1010102 / NV12`. After real mode finishes, check these output files first:

- `wrapper_compare_summary.txt`
- `wrapper_tajmahal_vivo_*.txt`
- `wrapper_tajmahal_vivo_expected_*.txt`
- `actual_otf_stream.txt`
- `expected_otf_stream.txt`

If you prefer directly running the alias bench, you can also use:

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_rgba8888_vivo_all'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_rgba8888_vivo_all'

tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_rgba1010102_vivo_all'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_rgba1010102_vivo_all'

tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_4096x600_nv12_vivo_all'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=real wrapper_tajmahal_4096x600_nv12_vivo_all'
```

Step-by-step unified flow:

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_cases_prepare CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_cases_comp CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_cases_run CASE_ID=0'
tcsh -c 'source prj_setup.env; make WRAPPER_NV12_VIVO_MODE=fake wrapper_tajmahal_cases_verdi CASE_ID=0'
```

Change `CASE_ID` to `1/2`; for real mode, just set `WRAPPER_NV12_VIVO_MODE=real`.

Key compare output files:

- fake mode:
- injected tile trace:`wrapper_tajmahal_inject_*.txt`
- injected tile expected:`wrapper_tajmahal_inject_expected_*.txt`
- actual OTF:`actual_otf_stream.txt`
- expected OTF:`expected_otf_stream.txt`
- summary:`wrapper_compare_summary.txt`
- real mode:
- actual RVO:`wrapper_tajmahal_vivo_*.txt`
- expected RVO:`wrapper_tajmahal_vivo_expected_*.txt`
- actual OTF:`actual_otf_stream.txt`
- expected OTF:`expected_otf_stream.txt`
- summary:`wrapper_compare_summary.txt`

Additional notes:

- `NV12 / G016(P010)` now additionally dumps `RVO` separately by plane, for easy direct comparison with vectors
- For example `NV12` generates:
  - `wrapper_tajmahal_vivo_nv12_y.txt`
  - `wrapper_tajmahal_vivo_nv12_uv.txt`
  - `wrapper_tajmahal_vivo_expected_nv12_y.txt`
  - `wrapper_tajmahal_vivo_expected_nv12_uv.txt`
- `G016` generates:
  - `wrapper_k_outdoor61_vivo_g016_y.txt`
  - `wrapper_k_outdoor61_vivo_g016_uv.txt`
  - `wrapper_k_outdoor61_vivo_expected_g016_y.txt`
  - `wrapper_k_outdoor61_vivo_expected_g016_uv.txt`
- fake mode also generates the corresponding `fake_vivo_*_y.txt / fake_vivo_*_uv.txt`

Most common confusion points:

- When running `NV12`, only check `NV12` output files; do not use `G016` commands to verify `NV12`
- For fake mode, check file names containing `fake`
- For real mode, check file names without `fake`
- `expected_*_y/uv.txt` is now exported as a full tiled memory image, soso it can be directly compared with the original vector

Direct mapping:

- `NV12 fake`
  - Command:`tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_vivo_fake_all'`
  - Directory:`build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12_fake/`
  - Y compare:
    - `wrapper_tajmahal_fake_vivo_expected_nv12_y.txt`
    - `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in0.txt`
  - UV compare:
    - `wrapper_tajmahal_fake_vivo_expected_nv12_uv.txt`
    - `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in1.txt`

- `NV12 real`
  - Command:`tcsh -c 'source prj_setup.env; make wrapper_tajmahal_4096x600_nv12_vivo_real_all'`
  - Directory:`build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12_real/`
  - Y compare:
    - `wrapper_tajmahal_vivo_expected_nv12_y.txt`
    - `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in0.txt`
  - UV compare:
    - `wrapper_tajmahal_vivo_expected_nv12_uv.txt`
    - `enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in1.txt`

- `G016 fake`
  - Command:`tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_fake_all'`
  - Directory:`build/tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016_fake/`
  - Y compare:
    - `wrapper_k_outdoor61_fake_vivo_expected_g016_y.txt`
    - `enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_in0.txt`
  - UV compare:
    - `wrapper_k_outdoor61_fake_vivo_expected_g016_uv.txt`
    - `enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_in1.txt`

- `G016 real`
  - Command:`tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_real_all'`
  - Directory:`build/tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016_real/`
  - Y compare:
    - `wrapper_k_outdoor61_vivo_expected_g016_y.txt`
    - `enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_in0.txt`
  - UV compare:
    - `wrapper_k_outdoor61_vivo_expected_g016_uv.txt`
    - `enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_in1.txt`

These files are generated under the corresponding build directory, For example:

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

Current status:

- fake mode has been verified locally:
- `RGBA8888`: pass
- `RGBA1010102`: pass
- `NV12`: pass
- real mode commands, vector preparation, and compare paths are all connected
- If the current `ubwc_dec_vivo_top.v` is still a fake packer, implementation-level real compare results will be affected by it

# tb_ubwc_dec_wrapper_top_tajmahal_rgba8888

This is an earlier standalone wrapper bench, kept for inspecting `RGBA8888`   OTF dump.

Direct run:

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_rgba8888_all'
```

step by step:

```bash
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_rgba8888_comp'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_rgba8888_run'
tcsh -c 'source prj_setup.env; make wrapper_tajmahal_rgba8888_verdi'
```

Notes:

- This old flow reads fixed inputs:
- metadata:`visual_from_mdss_writeback_4_wb_2_rec_0_verify_ubwc_enc_out2.txt`
- tile:`visual_from_mdss_writeback_4_wb_2_rec_0_verify_ubwc_enc_in0.txt`
- It has no independent fake / real mode switch, and does not run the current unified `vivo + OTF + linear` dual compare
- If you want to run the currently recommended fake / real wrapper regression, prefer the previous section, `tb_ubwc_dec_wrapper_top_tajmahal_cases`, or `wrapper_tajmahal_4096x600_rgba8888_vivo_all`

# tb_ubwc_enc_wrapper_top_tajmahal_cases

This encoder wrapper bench uses this flow:

- `Linear data` is first converted to `OTF stream`
- through `ubwc_enc_wrapper_top`
- fake mode mode, current `ubwc_enc_vivo_top` output is checked against `Tiled Uncompressed` check
- non-fake mode mode, testbench switches to:
- `Meta` output compares `Metadata RGB/Y-plane` and `Metadata UV-plane`
- `Compressed data` output compares `Tiled Compressed Image RGB/Y-plane` and `Tiled Compressed Image UV-plane`

fake mode Recommended direct run:

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba1010102_all'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_nv12_all'
```

fake mode Step-by-step run is also available:

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_comp'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_run'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_verdi'
```

To switch to non-fake mode, pass `RUN_ARGS="+tb_non_fake_mode"` through `run/all`:

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_all RUN_ARGS="+tb_non_fake_mode"'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba1010102_all RUN_ARGS="+tb_non_fake_mode"'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_nv12_all RUN_ARGS="+tb_non_fake_mode"'
```

non-fake mode step by stepexample:

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_comp'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_run RUN_ARGS="+tb_non_fake_mode"'
tcsh -c 'source prj_setup.env; make enc_wrapper_tajmahal_4096x600_rgba8888_verdi'
```

Notes:

- `comp` only compiles and does not distinguish fake / non-fake
- After `run` or `all` uses `RUN_ARGS="+tb_non_fake_mode"`, the TB automatically loads the compressed / metadata references for the corresponding TajMahal vector
- `RGBA8888` and `RGBA1010102` only compares `Y/RGB` compressed and metadata path
- `NV12` simultaneously compares `Y` / `UV` compressed paths, and `Y` / `UV` metadata paths

Current verification results:

- fake mode
- `RGBA8888`: pass
- `RGBA1010102`: pass
- `NV12`: pass
- non-fake mode
- testbench   compressed / metadata checker is connected
- If the current `ubwc_enc_vivo_top` is still a fake implementation, non-fake mode reports mismatch as expected

# tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016

This encoder wrapper bench uses:

- Vector directory:`enc_from_mdss_01000007_k_outdoor61_4096x600_g016`
- Image format:`G016 / YUV420 10bit`
- `Actual Image Size`: `4096x600`
- `Aligned Height for Pixel Data P0`: `608`
- `Aligned Height for Pixel Data P1`: `304`
- `Pitch for Pixel Data P0/P1`: `8192 bytes`

This case is currently connected into:

- `TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016`
- `Makefile` Target:`enc_wrapper_k_outdoor61_4096x600_g016_*`

Recommended direct run:

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_all'
```

step by step:

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_comp'
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_run'
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_verdi'
```

To directly run fake mode, the current recommendation is:

```bash
tcsh -c 'source prj_setup.env; make TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 enc_wrapper_tajmahal_cases_prepare'
tcsh -c 'source prj_setup.env; make TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 all'
```

To explicitly run non-fake mode:

```bash
tcsh -c 'source prj_setup.env; make enc_wrapper_k_outdoor61_4096x600_g016_all RUN_ARGS="+tb_non_fake_mode"'
```

Current verification results:

- fake mode
- `coord_count = 29184`
- `aw_mismatch_count = 0`
- `range_mismatch_cnt = 0`
- `meta_aw_count_y/uv = 2560 / 1536`
- `rvi_data_mismatch = 0`
- `cvo_data_mismatch = 0`
- fake mode has passed `layout / address / count` check
- non-fake mode
- `rvi -> uncompressed tile` passes
- `cvo -> compressed tile` checker is connected
- The current `ubwc_enc_vivo_top` is still passthrough/fake, so it is not a real encoder implementation yet; non-fake mode reports `compressed / metadata` mismatch as expected

Result file locations:

- fake: `build/tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016/`
- non-fake: `build/tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016/`
- main Y dump: `tb_ubwc_enc_wrapper_top_k_outdoor61_g016_*_main_y_mem.txt`
- main UV dump: `tb_ubwc_enc_wrapper_top_k_outdoor61_g016_*_main_uv_mem.txt`
- meta Y dump: `tb_ubwc_enc_wrapper_top_k_outdoor61_g016_*_meta_y_mem.txt`
- meta UV dump: `tb_ubwc_enc_wrapper_top_k_outdoor61_g016_*_meta_uv_mem.txt`

# tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12

This integration bench uses this flow:

- `Linear data -> OTF -> ubwc_enc_wrapper_top`
- The current encoder `fake ubwc_enc_vivo_top` outputs `Tiled Uncompressed`
- decoder uses `enc_from_mdss_zp_TajMahal_4096x600_nv12`   metadata
- `ubwc_dec_wrapper_top` directly reads the `tile Y/UV` memory written by the encoder
- Finallyexport decoder OTF output is compared against the linear golden

Recommended direct run:

```bash
tcsh -c 'source prj_setup.env; make encdec_wrapper_tajmahal_4096x600_nv12_all'
```

step by step:

```bash
tcsh -c 'source prj_setup.env; make encdec_wrapper_tajmahal_4096x600_nv12_prepare'
tcsh -c 'source prj_setup.env; make encdec_wrapper_tajmahal_4096x600_nv12_comp'
tcsh -c 'source prj_setup.env; make encdec_wrapper_tajmahal_4096x600_nv12_run'
tcsh -c 'source prj_setup.env; make compare_encdec_wrapper_tajmahal_4096x600_nv12_otf'
tcsh -c 'source prj_setup.env; make encdec_wrapper_tajmahal_4096x600_nv12_verdi'
```

Result file locations:

- Simulation output: `build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/actual_otf_stream.txt`
- Compare result directory: `build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/compare`
- Run log: `build/tb_ubwc_enc_dec_wrapper_top_tajmahal_4096x600_nv12/run.log`

This `NV12 enc+dec wrapper` integration has been verified to pass:

- `enc AW addr mismatch : 0`
- `dec AR addr mismatch : 0`
- `otf mismatch count : 0`
- `compare mismatch beats : 0`

# tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016

This decoder wrapper case uses:

- Vector directory:`enc_from_mdss_01000007_k_outdoor61_4096x600_g016`
- base format:`YUV420 10bit / P010-like packed OTF`
- Image width:`4096`
- Y stored height:`608`
- UV stored height:`304`
- tile pitch:`8192 bytes`
- 4-line format:`enable`

Recommended direct run fake mode:

```bash
tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_all'
```

To explicitly run real mode:

```bash
tcsh -c 'source prj_setup.env; make WRAPPER_CASES_TB_REAL_VIVO_MODE=1 wrapper_k_outdoor61_4096x600_g016_vivo_all'
```

Step-by-step commands:

```bash
tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_comp'
tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_run'
tcsh -c 'source prj_setup.env; make wrapper_k_outdoor61_4096x600_g016_vivo_verdi'
```

Current verification results:

- fake mode
- `AR addr mismatches = 0`
- `AR len mismatches = 0`
- `RVO data mismatches = 0`
- `RVO last mismatches = 0`
- `OTF mismatches = 0`
- This case adds mild G016/P010 backpressure for `i_otf_ready` backpressure, fake mode has passed

- real mode
- `AR addr mismatches = 0`
- `AR len mismatches = 0`
- `RVO data mismatches = 230400`
- `OTF mismatches = 622592`
- The current `ubwc_dec_vivo_top` is not a real decompressor implementation yet, so real mode `RVO/OTF` content compare fails as expected

Result file locations:

- fake / real output directory:`build/tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016/`
- fake RVO dump:`wrapper_k_outdoor61_fake_vivo_g016.txt`
- fake OTF dump:`actual_otf_stream.txt`
- real RVO dump:`wrapper_k_outdoor61_vivo_g016.txt`
- compare summary:`wrapper_compare_summary.txt`
