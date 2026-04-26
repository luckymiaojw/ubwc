# HDL style helpers

`align_hdl_style.py` aligns simple Verilog/SystemVerilog declarations and module instance parameter/port lists to the column style used by `src/enc/ubwc_enc_wrapper_top.sv`.

Usage:

```sh
# Format currently modified HDL files
scripts/align_hdl_style.py

# Format selected files or directories
scripts/align_hdl_style.py src/dec/ubwc_dec_meta_data_gen.v src/dec/ubwc_dec_tile_arcmd_gen.v
scripts/align_hdl_style.py src/dec

# Check only, useful before commit
scripts/align_hdl_style.py --check

# Print diff without writing files
scripts/align_hdl_style.py --diff src/dec

# Format every HDL file under src and vrf/src
scripts/align_hdl_style.py --all-src
```

The tool is intentionally conservative: it only changes one-line declarations, parameter/localparam lines, and one-line `.port(expr)` / `.PARAM(expr)` connections.
