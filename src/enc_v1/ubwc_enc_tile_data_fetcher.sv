//////////////////////////////////////////////////////////////////////////////////
// Module Name       : ubwc_enc_tile_data_fetcher
// Description       : 按 tile 从 bank0/1 SRAM 读 + mask/forced_pcm 预计算 +
//                     128→256 拼接 + 合并 async FIFO #2 输出 + release 反馈
//   关键设计：
//     - 写优先：fetcher 监听 writer_wen，wen=1 时不发 ren 不 push meta
//     - 1 个 256-bit 输出 beat = 2 个 128-bit SRAM 读 (addr_lo / addr_hi)
//     - dout pair holder：≥4 entry FIFO 覆盖变长 SRAM 延迟 (≤4 拍)
//     - 输出顺序：done_info FIFO 序 → Y Y UV 三联
//     - UV tile 跨 bank 拼读：前 8 word 从 bank0，后 8 word 从 bank1
//     - 末组孤立：按完整 tile 16 读发起，mask 处理后半
// Reference         : docs/claude code/enc/ubwc_enc_line_to_tile_v1_design_cn.md §3.3 §4
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
`default_nettype none

module ubwc_enc_tile_data_fetcher
    import ubwc_enc_v1_pkg::*;
#(
    parameter int ADDR_W   = SRAM_ADDR_W,    // 16
    parameter int SB_WIDTH = 1
)(
    //==========================================================================
    // Clock & Reset
    //==========================================================================
    input  wire                       clk,                        // core_clk
    input  wire                       rst_n,                      // rst_n_sys

    input  wire                       i_vivo_clk,                 // async FIFO #2 读侧
    input  wire                       rst_n_vivo,                 // vivo_clk 域复位

    //==========================================================================
    // Static config (帧间锁存)
    //==========================================================================
    input  wire [2:0]                 cfg_format,
    input  wire [15:0]                cfg_width,
    input  wire [15:0]                cfg_active_width,
    input  wire [15:0]                cfg_active_height,
    input  wire [15:0]                cfg_y_tile_cols,
    input  wire [15:0]                cfg_uv_tile_cols,

    //==========================================================================
    // done_info ← writer（fetcher 内部用 FIFO 缓冲，按序消费）
    //==========================================================================
    input  done_info_t                i_done_info,
    input  wire                       i_done_valid,
    output wire                       o_done_ready,               // FIFO 不满

    //==========================================================================
    // release → writer（一整行 tiles 读完，1 拍脉冲）
    //==========================================================================
    output wire                       o_y_release_valid,
    output wire                       o_y_release_bank,
    output wire                       o_uv_release_valid,
    output wire                       o_uv_release_slot,

    //==========================================================================
    // SRAM Bank0 读侧（给顶层 mux）
    //==========================================================================
    output wire                       m_bank0_fetcher_ren,
    output wire [ADDR_W-1:0]          m_bank0_fetcher_addr,
    input  wire                       i_bank0_writer_wen,         // 写优先门控用
    input  wire [127:0]               i_bank0_dout,               // SRAM 出
    input  wire                       i_bank0_dout_vld,           // SRAM macro 给

    //==========================================================================
    // SRAM Bank1 读侧
    //==========================================================================
    output wire                       m_bank1_fetcher_ren,
    output wire [ADDR_W-1:0]          m_bank1_fetcher_addr,
    input  wire                       i_bank1_writer_wen,
    input  wire [127:0]               i_bank1_dout,
    input  wire                       i_bank1_dout_vld,

    //==========================================================================
    // 最终 tile 数据通道（vivo_clk 域）
    //==========================================================================
    output wire                       o_tile_vld,
    input  wire                       i_tile_rdy,
    output wire [255:0]               o_tile_data,
    output wire [31:0]                o_tile_keep,
    output wire                       o_tile_last,
    output wire                       o_tile_stat_valid,          // V1 暂为 0
    output wire                       o_tile_stat_last,           // V1 暂为 0
    output wire                       o_tile_stat_slot,           // V1 暂为 0

    //==========================================================================
    // CI 命令通道（vivo_clk 域，与 tile 同源 async FIFO，sof 标识）
    //   下游协议：i_ci_ready & i_tile_rdy 同时 high 才 pop
    //==========================================================================
    output wire                       o_ci_valid,
    input  wire                       i_ci_ready,
    output wire                       o_ci_forced_pcm,
    output wire [SB_WIDTH-1:0]        o_ci_sb,                    // = fcnt[0]
    output wire [15:0]                o_tile_x,
    output wire [15:0]                o_tile_y,
    output wire [3:0]                 o_tile_fcnt,
    output wire [4:0]                 o_tile_format,

    //==========================================================================
    // vivo 同步（与现行 wrapper 一致）
    //==========================================================================
    input  wire                       i_co_valid,

    //==========================================================================
    // Error
    //==========================================================================
    output wire                       o_err
);

    // -------------------------------------------------------------------------
    // FIFO IP 选型（CODE_STYLE.md "FIFO 选型"）：
    //   - 跨域 FIFO（async FIFO #2） → mg_async_fifo
    //   - 同域 FIFO（done_info / meta / dout pair holder） → mg_sync_fifo
    //   - 不允许改动这两个 IP
    //
    // 实现位置（占位）：
    //   done_info 接收：mg_sync_fifo（深 ≥8），按序消费
    //   读发起门控：
    //     - 看 writer_wen（本拍组合），wen=1 → 不发 ren，不 push meta
    //     - meta FIFO 不满 + async FIFO #2 写侧 credit > 0
    //   读地址生成（per tile）：
    //     - DONE_Y：bank.Y 区起始 addr 0；每 tile 16 读 (addr_lo addr_hi 交替)
    //     - DONE_UV / DONE_UV_ISO：前 8 word 从 bank0.UV_slot，后 8 word 从 bank1.UV_slot
    //     - 推进 tile_x 0..cfg_*_tile_cols-1，整行读完发 release
    //   mask / forced_pcm 预计算：
    //     - 基于 cfg_active_* + (tile_x, tile_y) + done_info.{y_rows/uv_rows}_actual
    //     - 1 bit/byte → keep[31:0]；forced_pcm_Y = OR(~mask) on Y tiles; 同理 fp_UV
    //   read meta FIFO：
    //     - 每 entry ↔ 1 输出 beat，push 在 addr_hi 那拍
    //   dout pair holder (≥4 entry FIFO)：
    //     - dout_vld 拍：第 1 个进 holder，第 2 个出 + pop meta → 256-bit beat
    //   合并 async FIFO #2（深 16，core_clk → vivo_clk）：
    //     - sof=1 拍载 ci 字段；下游侧 demux 到 o_ci_* / o_tile_*
    //   release 输出：
    //     - tile_x 达到 cfg_*_tile_cols-1 且最后一 beat 弹完 → 拉 release 1 拍
    //     - UV_release 同时释放 bank0 + bank1 该 slot
    //   fcnt 直接来自 done_info.fcnt；sb = fcnt[0]
    // -------------------------------------------------------------------------

endmodule

`default_nettype wire
