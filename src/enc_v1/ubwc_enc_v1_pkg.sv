//////////////////////////////////////////////////////////////////////////////////
// Module Name       : ubwc_enc_v1_pkg
// Description       : V1 重构（替换 ubwc_enc_otf_to_tile_top）公共类型 / 常量
//                     - format 编码
//                     - done_info / async FIFO / read meta 等结构体
//                     - SRAM 布局 / FIFO 深度常量
// Reference         : docs/claude code/enc/ubwc_enc_line_to_tile_v1_design_cn.md
//////////////////////////////////////////////////////////////////////////////////
`ifndef UBWC_ENC_V1_PKG_SV
`define UBWC_ENC_V1_PKG_SV

`timescale 1ns/1ps

package ubwc_enc_v1_pkg;

    //--------------------------------------------------------------------------
    // Format 编码（与现行 line_to_tile 一致）
    //--------------------------------------------------------------------------
    typedef enum logic [2:0] {
        FMT_RGBA8888  = 3'd0,
        FMT_RGBA10    = 3'd1,
        FMT_YUV420_8  = 3'd2,
        FMT_YUV420_10 = 3'd3
    } cfg_format_e;

    // o_tile_format[4:0]：对外编码，沿用现行 ubwc_enc_otf_to_tile_top 映射
    typedef logic [4:0] tile_format_t;

    //--------------------------------------------------------------------------
    // done_info：writer → fetcher
    //--------------------------------------------------------------------------
    // kind 编码：
    //   DONE_Y      — 某 bank 的 Y 区一组写完，fetcher 可独立读 Y tile 行
    //   DONE_UV     — bank1 的 UV slot 写完（配对就绪），fetcher 跨 bank 拼读 UV tile 行
    //   DONE_UV_ISO — 末组孤立 Y（无配对 bank1），仍按完整 tile 读，mask 处理后半
    typedef enum logic [1:0] {
        DONE_Y      = 2'd0,
        DONE_UV     = 2'd1,
        DONE_UV_ISO = 2'd2
    } done_kind_e;

    typedef struct packed {
        done_kind_e   kind;                 // 2 bit
        logic         bank_sel;             // 0=bank0, 1=bank1 (DONE_Y 用)
        logic         uv_slot;              // 0=UV_A, 1=UV_B (DONE_UV / DONE_UV_ISO 用)
        logic [3:0]   fcnt;                 // writer 自维护，每帧 +1
        logic [3:0]   y_rows_actual;        // 末组 Y 实际行数 (0..8) — partial 用
        logic [3:0]   uv_rows_b0_actual;    // bank0 UV 实际行数 (0..4)
        logic [3:0]   uv_rows_b1_actual;    // bank1 UV 实际行数 (0..4)
        logic         frame_done;           // 该 bank 是本帧最后一组
    } done_info_t;

    //--------------------------------------------------------------------------
    // packer 输出 FIFO entry（fifo_a / fifo_b）163-bit
    //   复用现行 ubwc_enc_otf_data_packer.v 的输出格式
    //   每 entry = {fcnt[3:0], lcnt[11:0], vsync, hsync, tlast, tkeep[15:0], tdata[127:0]}
    //   备注：fcnt 字段被 otf_monitor 隔离 → packer 输入 otf_fcnt tie 0 → 此处永远为 0
    //--------------------------------------------------------------------------
    typedef struct packed {
        logic [3:0]   fcnt;        // 永远 = 0（被 otf_monitor 隔离）
        logic [11:0]  lcnt;
        logic         vsync;
        logic         hsync;
        logic         tlast;
        logic [15:0]  tkeep;
        logic [127:0] tdata;
    } packer_fifo_entry_t;         // 163 bit, 与现行 fifo_a/b_data[162:0] 一致

    //--------------------------------------------------------------------------
    // otf_monitor → writer 的 frame info bus（sys clk，跨域同步后）
    //   2-FF 同步即可，不走 FIFO；writer 用 frame_change_pulse 做 fcnt +1
    //--------------------------------------------------------------------------
    typedef struct packed {
        logic         frame_change_pulse;  // 1 拍脉冲，OTF vsync 上升沿同步
        logic [3:0]   fcnt_seen;           // OTF 端最近一帧 fcnt latch（debug 用，writer 不依赖）
    } otf_frame_info_t;

    //--------------------------------------------------------------------------
    // Async FIFO #2 载荷：fetcher → 下游（core_clk → vivo_clk）
    //   sof=1 拍同时驱动 ci 通道和 tile 通道；sof=0 拍只驱动 tile 通道
    //   下游协议：i_ci_ready & i_tile_rdy 同时 high 才 pop
    //--------------------------------------------------------------------------
    typedef struct packed {
        logic         sof;                 // 1 = tile 首拍（携带 ci 字段）
        // TILE 字段（每拍有效）
        logic [255:0] tile_data;
        logic [31:0]  tile_keep;
        logic         tile_last;
        logic         stat_valid;          // V1 暂不实现 → 0
        logic         stat_last;           // V1 暂不实现 → 0
        logic         stat_slot;           // V1 暂不实现 → 0
        // CI 字段（仅 sof=1 拍有效）
        logic         forced_pcm;
        logic         sb;                  // = fcnt[0]，同帧固定
        logic [15:0]  tile_x;
        logic [15:0]  tile_y;
        logic [3:0]   tile_fcnt;
        tile_format_t tile_format;
    } out_fifo_entry_t;

    //--------------------------------------------------------------------------
    // read meta FIFO 载荷（fetcher 内部）
    //   每 entry ↔ 1 个 256-bit 输出 beat（含 2 次 128-bit SRAM 读的拼接）
    //   push 时机：在发完 addr_hi 那拍 push
    //--------------------------------------------------------------------------
    typedef struct packed {
        logic         is_uv;               // 0=Y tile, 1=UV tile
        logic         bank_sel;            // 该 beat 的 SRAM bank
        logic [15:0]  tile_x;
        logic [15:0]  tile_y;
        logic [31:0]  mask;                // 预计算 keep[31:0]
        logic         forced_pcm;          // 预计算 OR(~mask) 仅 first_word 用
        logic         first_word;          // = sof（tile 首 beat）
        logic         last_word;           // tile 末 beat
        logic         stat_valid;
        logic         stat_last;
        logic         stat_slot;
        logic [3:0]   fcnt;
        tile_format_t tile_format;
    } meta_fifo_entry_t;

    //--------------------------------------------------------------------------
    // SRAM 布局常量（4096 word × 128 bit/word = 64 KiB per bank）
    //   详见 docs/claude code/enc/ubwc_enc_sram_layout_cn.svg
    //--------------------------------------------------------------------------
    localparam int          SRAM_ADDR_W       = 16;
    localparam int          SRAM_DEPTH        = 4096;        // 4096 word/bank
    localparam logic [15:0] SRAM_Y_BASE       = 16'd0;       // Y 区 0..2048
    localparam logic [15:0] SRAM_UV_A_BASE    = 16'd2048;    // UV_A 2048..3072
    localparam logic [15:0] SRAM_UV_B_BASE    = 16'd3072;    // UV_B 3072..4096
    localparam int          SRAM_UV_SLOT_SIZE = 1024;

    //--------------------------------------------------------------------------
    // FIFO 深度（参见 §9）
    //--------------------------------------------------------------------------
    localparam int ASYNC_FIFO1_DEPTH      = 16;   // otf_monitor → writer
    localparam int ASYNC_FIFO2_DEPTH      = 16;   // fetcher → 下游
    localparam int Y_SMALL_FIFO_DEPTH     = 4;
    localparam int UV_SMALL_FIFO_DEPTH    = 4;
    localparam int MERGE_FIFO_DEPTH       = 4;
    localparam int READ_META_FIFO_DEPTH   = 4;
    localparam int DOUT_PAIR_HOLDER_DEPTH = 4;
    localparam int DONE_INFO_FIFO_DEPTH   = 8;    // writer → fetcher 缓冲

    //--------------------------------------------------------------------------
    // 其他
    //--------------------------------------------------------------------------
    localparam int OUT_BEATS_PER_TILE = 8;        // 256 byte / 32 byte = 8 拍
    localparam int SRAM_READS_PER_BEAT = 2;       // 2 × 128b = 256b

endpackage : ubwc_enc_v1_pkg

`endif // UBWC_ENC_V1_PKG_SV
