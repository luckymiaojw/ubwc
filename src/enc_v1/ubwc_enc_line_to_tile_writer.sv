//////////////////////////////////////////////////////////////////////////////////
// Module Name       : ubwc_enc_line_to_tile_writer  (V1)
// Description       : 从 packer 的 fifo_a (Y/RGBA) 和 fifo_b (UV) 弹数据，
//                     合并 → ping-pong 写 bank0/1 SRAM，产 done_info → fetcher
//   内部拆 2 子块（详见 §3）：
//     writer_arb  — pop fifo_a/fifo_b + word 级合并 + ping-pong bank + UV slot
//                   + 算 SRAM 地址 + 推合并写小 FIFO
//     writer_ctl  — fcnt 维护（用 otf_monitor.frame_change_pulse）+ 写小 FIFO pop
//                   + 驱动 m_writer_* + done_info 生成 + release 跟踪 + partial 计数
//   fcnt 来源：otf_monitor.frame_change_pulse（与 OTF fcnt 解耦）
//   plane 分流：packer 已完成（fifo_a = Y, fifo_b = UV），writer 不需要看 lcnt[0]
// Reference         : docs/claude code/enc/ubwc_enc_line_to_tile_v1_design_cn.md §3
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
`default_nettype none

module ubwc_enc_line_to_tile_writer
    import ubwc_enc_v1_pkg::*;
#(
    parameter int ADDR_W = SRAM_ADDR_W      // 16
)(
    //==========================================================================
    // Clock & Reset (core_clk 域)
    //==========================================================================
    input  wire                       clk,
    input  wire                       rst_n,                      // = rst_n_sys

    //==========================================================================
    // Static config (帧间锁存)
    //==========================================================================
    input  wire [2:0]                 cfg_format,
    input  wire [15:0]                cfg_width,
    input  wire [15:0]                cfg_height,
    input  wire [15:0]                cfg_active_width,
    input  wire [15:0]                cfg_active_height,
    input  wire [3:0]                 cfg_tile_h,                 // Y tile 高度
    input  wire [15:0]                cfg_y_tile_cols,
    input  wire [15:0]                cfg_uv_tile_cols,

    //==========================================================================
    // Frame info ← otf_monitor (sys clk 域，2-FF 同步后)
    //==========================================================================
    input  otf_frame_info_t           i_frame_info,

    //==========================================================================
    // packer fifo_a (Y/RGBA) pop side
    //==========================================================================
    input  wire                       i_fifo_a_vld,
    output wire                       o_fifo_a_rdy,
    input  packer_fifo_entry_t        i_fifo_a_data,

    //==========================================================================
    // packer fifo_b (UV) pop side
    //==========================================================================
    input  wire                       i_fifo_b_vld,
    output wire                       o_fifo_b_rdy,
    input  packer_fifo_entry_t        i_fifo_b_data,

    //==========================================================================
    // SRAM Bank0 写侧（给顶层 mux，不直接驱动 SRAM）
    //==========================================================================
    output wire                       m_bank0_writer_en,
    output wire                       m_bank0_writer_wen,
    output wire [ADDR_W-1:0]          m_bank0_writer_addr,
    output wire [127:0]               m_bank0_writer_din,

    //==========================================================================
    // SRAM Bank1 写侧
    //==========================================================================
    output wire                       m_bank1_writer_en,
    output wire                       m_bank1_writer_wen,
    output wire [ADDR_W-1:0]          m_bank1_writer_addr,
    output wire [127:0]               m_bank1_writer_din,

    //==========================================================================
    // done_info → fetcher（每条 push 1 拍）
    //==========================================================================
    output done_info_t                m_done_info,
    output wire                       m_done_valid,
    input  wire                       i_done_ready,

    //==========================================================================
    // release ← fetcher（1 拍脉冲，按"一整行 tiles"粒度）
    //==========================================================================
    input  wire                       i_y_release_valid,
    input  wire                       i_y_release_bank,           // 0=bank0, 1=bank1
    input  wire                       i_uv_release_valid,
    input  wire                       i_uv_release_slot,          // 0=UV_A, 1=UV_B

    //==========================================================================
    // Error
    //==========================================================================
    output wire                       o_err                       // sticky（内部异常，如合并 FIFO 溢出）
);

    // -------------------------------------------------------------------------
    // FIFO IP 选型（CODE_STYLE.md "FIFO 选型"）：
    //   合并写小 FIFO → mg_sync_fifo
    //   不允许改动 IP
    //
    // 实现位置（占位）：
    //   writer_arb:
    //     - 从 fifo_a / fifo_b 按 word 级 round-robin 弹出（一侧空时另一侧连续）
    //     - 每拍 pop ≤ 1
    //     - 用 entry 内 lcnt / vsync 推位置 + cfg_format → 计算 SRAM 写地址
    //     - bank ping-pong：写完整组才切
    //     - UV slot：group_id[1] ? UV_B : UV_A
    //     - 推 {data, addr, bank_sel, wen=1} 到合并写小 FIFO
    //   writer_ctl:
    //     - 4-bit fcnt = i_frame_info.frame_change_pulse 累加（不用 entry.vsync）
    //     - per-bank-per-region release latch（Y×2 + UV×2）
    //     - 重写 bank 条件：bank.Y 已释放 AND 目标 UV slot 已释放
    //     - 写小 FIFO pop → m_writer_en/wen/addr/din
    //     - 跟踪写入进度，触发 done_info：
    //         · Y 写满 → DONE_Y
    //         · bank1.UV slot 写满 → DONE_UV
    //         · 末组孤立 → DONE_UV_ISO (frame_done)
    //     - partial 末组：累计 y_rows_actual / uv_rows_b0/b1_actual 一并 push
    // -------------------------------------------------------------------------

endmodule

`default_nettype wire
