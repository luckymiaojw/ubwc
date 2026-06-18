// ============================================================================
// UBWC ENC V1 子系统 filelist
//   顶层模块：ubwc_enc_otf_to_tile_top（保留原名）
//   文件路径：相对 trunk 根目录
//   语法检查命令：
//     verilator --lint-only -sv -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
//       --top-module ubwc_enc_otf_to_tile_top -y src/ip -y src/enc -y src/enc_v1 \
//       -f src/enc_v1/enc_v1.f
// ============================================================================

// V1 公共 pkg（必须先编）
src/enc_v1/ubwc_enc_v1_pkg.sv

// V1 子模块
src/enc_v1/ubwc_enc_otf_monitor.sv
src/enc_v1/ubwc_enc_line_to_tile_writer.sv
src/enc_v1/ubwc_enc_tile_data_fetcher.sv

// V1 顶层 wrapper（含 mux + err 汇聚）
src/enc_v1/ubwc_enc_otf_to_tile_top_v1.sv

// 复用模块（来自 src/enc，不修改）
src/enc/ubwc_enc_otf_data_packer.v

// FIFO IP（不修改）
src/ip/mg_async_fifo.v
src/ip/mg_sync_fifo.v
