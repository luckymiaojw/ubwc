# HDL style helpers

Coding style is defined in `../CODE_STYLE.md` and `../docs/ubwc_rtl_coding_style_cn.md`. In particular, project-owned RTL must follow the "one variable, one always block" rule for sequential registers, and wire declarations must be separated from continuous assignments.

`align_hdl_style.py` aligns simple Verilog/SystemVerilog declarations, continuous `assign` blocks, and module instance parameter/port lists to the column style used by `src/enc/ubwc_enc_wrapper_top.sv`.

Usage:

```sh
# Format currently modified HDL files
scripts/align_hdl_style.py

# Format selected files or directories
scripts/align_hdl_style.py src/dec/ubwc_dec_meta_data_gen.v src/dec/ubwc_dec_tile_arcmd_gen.v
scripts/align_hdl_style.py src/dec

# Check only, useful before commit
scripts/align_hdl_style.py --check

# Only align assign blocks, useful for small low-risk formatting fixes
scripts/align_hdl_style.py --assign-only src/dec/ubwc_dec_meta_axi_rcmd_gen.v
scripts/align_hdl_style.py --assign-only --check src/enc src/dec

# Only align instance parameter/port connection blocks
scripts/align_hdl_style.py --conn-only src/dec/ubwc_dec_wrapper_top.v
scripts/align_hdl_style.py --conn-only --check src/enc src/dec

# Print diff without writing files
scripts/align_hdl_style.py --diff src/dec

# Format every HDL file under src and vrf/src
scripts/align_hdl_style.py --all-src
```

The tool is intentionally conservative: it only changes simple declarations, parameter/localparam lines, continuous assign statement blocks, and one-line `.port(expr)` / `.PARAM(expr)` connections.
