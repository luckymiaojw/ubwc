`timescale 1ns/1ps
`default_nettype none

module tb_enc_sync_sram_1rw #(
    parameter ADDR_W = 13,
    parameter DATA_W = 128
) (
    input  wire               clk,
    input  wire               en,
    input  wire               wen,
    input  wire [ADDR_W-1:0]  addr,
    input  wire [DATA_W-1:0]  din,
    output reg  [DATA_W-1:0]  dout,
    output reg                dout_vld
);
    reg [DATA_W-1:0] mem [0:(1 << ADDR_W)-1];
    integer idx;

    initial begin
        dout     = {DATA_W{1'b0}};
        dout_vld = 1'b0;
        for (idx = 0; idx < (1 << ADDR_W); idx = idx + 1)
            mem[idx] = {DATA_W{1'b0}};
    end

    always @(posedge clk) begin
        dout_vld <= 1'b0;
        if (en) begin
            if (wen) begin
                mem[addr] <= din;
            end else begin
                dout     <= mem[addr];
                dout_vld <= 1'b1;
            end
        end
    end
endmodule

module tb_enc_axi_write_sink #(
    parameter AXI_ID_WIDTH = 7,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 256,
    parameter [AXI_ADDR_WIDTH-1:0] MEM_BASE_ADDR = 64'h0000_0000_8000_0000,
    parameter integer MEM_WORDS64 = 1250304
) (
    input  wire                      aclk,
    input  wire                      aresetn,
    input  wire [AXI_ID_WIDTH-1:0]   awid,
    input  wire [AXI_ADDR_WIDTH-1:0] awaddr,
    input  wire [7:0]                awlen,
    input  wire [2:0]                awsize,
    input  wire [1:0]                awburst,
    input  wire                      awvalid,
    output reg                       awready,
    input  wire [AXI_DATA_WIDTH-1:0] wdata,
    input  wire [(AXI_DATA_WIDTH/8)-1:0] wstrb,
    input  wire                      wlast,
    input  wire                      wvalid,
    output reg                       wready,
    output reg  [AXI_ID_WIDTH-1:0]   bid,
    output reg  [1:0]                bresp,
    output reg                       bvalid,
    input  wire                      bready
);
    localparam integer BURST_BEAT_W = 9;
    localparam integer AW_FIFO_DEPTH = 256;
    localparam integer B_FIFO_DEPTH = 256;

    reg [63:0] mem_words64 [0:MEM_WORDS64-1];
    reg [7:0]  mem_valid64 [0:MEM_WORDS64-1];

    reg                      aw_fifo_is_meta [0:AW_FIFO_DEPTH-1];
    reg [AXI_ID_WIDTH-1:0]   aw_fifo_id      [0:AW_FIFO_DEPTH-1];
    reg [AXI_ADDR_WIDTH-1:0] aw_fifo_addr    [0:AW_FIFO_DEPTH-1];
    reg [BURST_BEAT_W-1:0]   aw_fifo_beats   [0:AW_FIFO_DEPTH-1];
    reg [2:0]                aw_fifo_size    [0:AW_FIFO_DEPTH-1];

    reg [AXI_ID_WIDTH-1:0]   b_fifo_id     [0:B_FIFO_DEPTH-1];

    reg                      burst_active;
    reg                      burst_is_meta;
    reg [AXI_ADDR_WIDTH-1:0] burst_addr;
    reg [BURST_BEAT_W-1:0]   burst_beats_total;
    reg [BURST_BEAT_W-1:0]   burst_beat_idx;
    reg [2:0]                burst_size;
    reg [AXI_ID_WIDTH-1:0]   burst_id;

    integer aw_wr_ptr;
    integer aw_rd_ptr;
    integer aw_count;
    integer b_wr_ptr;
    integer b_rd_ptr;
    integer b_count;
    integer idx;
    reg dbg_meta_sink_en;
    reg dbg_meta_sink_fatal_en;

    wire aw_is_meta_w;
    wire aw_fire_w;
    wire aw_fifo_valid_w;
    wire aw_fifo_full_w;
    wire direct_w;
    wire aw_queue_push_w;
    wire aw_queue_pop_w;
    wire curr_is_meta_w;
    wire [AXI_ADDR_WIDTH-1:0] curr_addr_w;
    wire [BURST_BEAT_W-1:0]   curr_beats_w;
    wire [BURST_BEAT_W-1:0]   curr_beat_idx_w;
    wire [2:0]                curr_size_w;
    wire [AXI_ID_WIDTH-1:0]   curr_id_w;
    wire [AXI_ADDR_WIDTH-1:0] curr_beat_addr_w;
    wire curr_last_w;
    wire w_fire_w;
    wire b_fifo_push_w;
    wire b_fifo_pop_w;

    function automatic [AXI_ADDR_WIDTH-1:0] calc_beat_addr;
        input [AXI_ADDR_WIDTH-1:0] base_addr;
        input [BURST_BEAT_W-1:0]   beat_idx;
        input [2:0]                beat_size;
        reg [AXI_ADDR_WIDTH-1:0]   beat_bytes;
        begin
            beat_bytes     = {{(AXI_ADDR_WIDTH-1){1'b0}}, 1'b1};
            beat_bytes     = beat_bytes << beat_size;
            calc_beat_addr = base_addr + (beat_idx * beat_bytes);
        end
    endfunction

    task automatic clear_mem;
        integer clear_idx;
        begin
            for (clear_idx = 0; clear_idx < MEM_WORDS64; clear_idx = clear_idx + 1) begin
                mem_words64[clear_idx] = 64'hcccc_cccc_cccc_cccc;
                mem_valid64[clear_idx] = 8'd0;
            end
        end
    endtask

    task automatic write_beat_to_mem;
        input [AXI_ADDR_WIDTH-1:0] beat_addr;
        input [AXI_DATA_WIDTH-1:0] beat_data;
        input [(AXI_DATA_WIDTH/8)-1:0] beat_strb;
        integer byte_idx;
        integer word_idx;
        integer byte_off;
        reg [AXI_ADDR_WIDTH-1:0] byte_addr;
        reg [AXI_ADDR_WIDTH-1:0] mem_span_bytes;
        begin
            mem_span_bytes = MEM_WORDS64 * 8;
            for (byte_idx = 0; byte_idx < (AXI_DATA_WIDTH/8); byte_idx = byte_idx + 1) begin
                if (beat_strb[byte_idx]) begin
                    byte_addr = beat_addr + byte_idx;
                    if ((byte_addr >= MEM_BASE_ADDR) &&
                        (byte_addr < (MEM_BASE_ADDR + mem_span_bytes))) begin
                        word_idx = (byte_addr - MEM_BASE_ADDR) >> 3;
                        byte_off = (byte_addr - MEM_BASE_ADDR) & 7;
                        mem_words64[word_idx][byte_off*8 +: 8] = beat_data[byte_idx*8 +: 8];
                        mem_valid64[word_idx][byte_off]        = 1'b1;
                    end
                end
            end
        end
    endtask

    task automatic dump_range64;
        input integer               fd;
        input [AXI_ADDR_WIDTH-1:0]  start_addr;
        input integer               word_count;
        input                       zero_invalid_bytes;
        inout reg                   has_prev_addr;
        inout reg [AXI_ADDR_WIDTH-1:0] next_addr;
        integer                     dump_idx;
        integer                     word_idx;
        integer                     byte_idx;
        reg [AXI_ADDR_WIDTH-1:0]    word_addr;
        reg [63:0]                  word_data;
        reg [AXI_ADDR_WIDTH-1:0]    mem_span_bytes;
        begin
            if (fd != 0) begin
                mem_span_bytes = MEM_WORDS64 * 8;
                for (dump_idx = 0; dump_idx < word_count; dump_idx = dump_idx + 1) begin
                    word_addr = start_addr + (dump_idx * 8);
                    if (!has_prev_addr || (word_addr !== next_addr))
                        $fdisplay(fd, "@%016x", word_addr);

                    if ((word_addr >= MEM_BASE_ADDR) &&
                        (word_addr < (MEM_BASE_ADDR + mem_span_bytes))) begin
                        word_idx  = (word_addr - MEM_BASE_ADDR) >> 3;
                        word_data = mem_words64[word_idx];
                        if (zero_invalid_bytes) begin
                            for (byte_idx = 0; byte_idx < 8; byte_idx = byte_idx + 1) begin
                                if (!mem_valid64[word_idx][byte_idx])
                                    word_data[byte_idx*8 +: 8] = 8'h00;
                            end
                        end
                    end else begin
                        word_data = zero_invalid_bytes ? 64'd0 : 64'hcccc_cccc_cccc_cccc;
                    end

                    $fdisplay(fd, "%016x", word_data);
                    has_prev_addr = 1'b1;
                    next_addr     = word_addr + {{(AXI_ADDR_WIDTH-4){1'b0}}, 4'd8};
                end
            end
        end
    endtask

    task automatic log_beat_words64;
        input [AXI_ADDR_WIDTH-1:0] beat_addr;
        integer                     dump_idx;
        integer                     word_idx;
        reg [AXI_ADDR_WIDTH-1:0]    word_addr;
        reg [AXI_ADDR_WIDTH-1:0]    mem_span_bytes;
        begin
            mem_span_bytes = MEM_WORDS64 * 8;
            for (dump_idx = 0; dump_idx < (AXI_DATA_WIDTH/64); dump_idx = dump_idx + 1) begin
                word_addr = beat_addr + (dump_idx * 8);
                if ((word_addr >= MEM_BASE_ADDR) &&
                    (word_addr < (MEM_BASE_ADDR + mem_span_bytes))) begin
                    word_idx = (word_addr - MEM_BASE_ADDR) >> 3;
                    $display("[TB_META_SINK] mem[%0d] @%016x = %016x valid=%02x",
                             dump_idx, word_addr, mem_words64[word_idx], mem_valid64[word_idx]);
                end else begin
                    $display("[TB_META_SINK] mem[%0d] @%016x = <out_of_range>",
                             dump_idx, word_addr);
                end
            end
        end
    endtask

    assign aw_is_meta_w        = awid[AXI_ID_WIDTH-1];
    assign aw_fire_w           = awvalid && awready;
    assign aw_fifo_valid_w     = (aw_count != 0);
    assign aw_fifo_full_w      = (aw_count == AW_FIFO_DEPTH);
    assign w_fire_w            = wvalid && wready;

    assign direct_w            = w_fire_w && aw_fire_w && !burst_active && !aw_fifo_valid_w;
    assign aw_queue_push_w     = aw_fire_w && !direct_w;
    assign aw_queue_pop_w      = w_fire_w && !burst_active && aw_fifo_valid_w;

    assign curr_is_meta_w      = burst_active ? burst_is_meta :
                                 (aw_fifo_valid_w ? aw_fifo_is_meta[aw_rd_ptr] : aw_is_meta_w);
    assign curr_addr_w         = burst_active ? burst_addr :
                                 (aw_fifo_valid_w ? aw_fifo_addr[aw_rd_ptr] : awaddr);
    assign curr_beats_w        = burst_active ? burst_beats_total :
                                 (aw_fifo_valid_w ? aw_fifo_beats[aw_rd_ptr] :
                                  ({1'b0, awlen} + {{(BURST_BEAT_W-1){1'b0}}, 1'b1}));
    assign curr_beat_idx_w     = burst_active ? burst_beat_idx : {BURST_BEAT_W{1'b0}};
    assign curr_size_w         = burst_active ? burst_size :
                                 (aw_fifo_valid_w ? aw_fifo_size[aw_rd_ptr] : awsize);
    assign curr_id_w           = burst_active ? burst_id :
                                 (aw_fifo_valid_w ? aw_fifo_id[aw_rd_ptr] : awid);
    assign curr_beat_addr_w    = calc_beat_addr(curr_addr_w, curr_beat_idx_w, curr_size_w);
    assign curr_last_w         = (curr_beat_idx_w == (curr_beats_w - {{(BURST_BEAT_W-1){1'b0}}, 1'b1}));
    assign b_fifo_push_w       = w_fire_w && (curr_last_w || wlast);
    assign b_fifo_pop_w        = bvalid && bready;

    always @(*) begin
        awready = aresetn && !aw_fifo_full_w;
        wready  = aresetn && (burst_active || aw_fifo_valid_w || (awvalid && awready));

        bresp = 2'b00;
        if (aresetn && (b_count != 0)) begin
            bid    = b_fifo_id[b_rd_ptr];
            bvalid = 1'b1;
        end else begin
            bid    = {AXI_ID_WIDTH{1'b0}};
            bvalid = 1'b0;
        end
    end

    initial begin
        burst_active      = 1'b0;
        burst_is_meta     = 1'b0;
        burst_addr        = {AXI_ADDR_WIDTH{1'b0}};
        burst_beats_total = {BURST_BEAT_W{1'b0}};
        burst_beat_idx    = {BURST_BEAT_W{1'b0}};
        burst_size        = 3'd0;
        burst_id          = {AXI_ID_WIDTH{1'b0}};
        aw_wr_ptr         = 0;
        aw_rd_ptr         = 0;
        aw_count          = 0;
        b_wr_ptr          = 0;
        b_rd_ptr          = 0;
        b_count           = 0;
        dbg_meta_sink_en        = 1'b0;
        dbg_meta_sink_fatal_en  = 1'b0;
        if ($test$plusargs("dbg_meta_sink"))
            dbg_meta_sink_en = 1'b1;
        if ($test$plusargs("dbg_meta_sink_fatal"))
            dbg_meta_sink_fatal_en = 1'b1;
        clear_mem();
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            burst_active      <= 1'b0;
            burst_is_meta     <= 1'b0;
            burst_addr        <= {AXI_ADDR_WIDTH{1'b0}};
            burst_beats_total <= {BURST_BEAT_W{1'b0}};
            burst_beat_idx    <= {BURST_BEAT_W{1'b0}};
            burst_size        <= 3'd0;
            burst_id          <= {AXI_ID_WIDTH{1'b0}};
            aw_wr_ptr         <= 0;
            aw_rd_ptr         <= 0;
            aw_count          <= 0;
            b_wr_ptr          <= 0;
            b_rd_ptr          <= 0;
            b_count           <= 0;
        end else begin
            if (aw_queue_push_w) begin
                aw_fifo_is_meta[aw_wr_ptr] <= aw_is_meta_w;
                aw_fifo_id[aw_wr_ptr]      <= awid;
                aw_fifo_addr[aw_wr_ptr]    <= awaddr;
                aw_fifo_beats[aw_wr_ptr]   <= {1'b0, awlen} + {{(BURST_BEAT_W-1){1'b0}}, 1'b1};
                aw_fifo_size[aw_wr_ptr]    <= awsize;
                if (aw_wr_ptr == (AW_FIFO_DEPTH - 1))
                    aw_wr_ptr <= 0;
                else
                    aw_wr_ptr <= aw_wr_ptr + 1;
            end

            if (aw_fire_w && aw_is_meta_w && dbg_meta_sink_en) begin
                $display("[TB_META_SINK] t=%0t aw addr=%016x beats=%0d size=%0d direct=%0b queue_push=%0b",
                         $time,
                         awaddr,
                         ({1'b0, awlen} + {{(BURST_BEAT_W-1){1'b0}}, 1'b1}),
                         awsize,
                         direct_w,
                         aw_queue_push_w);
            end

            if (w_fire_w) begin
                write_beat_to_mem(curr_beat_addr_w, wdata, wstrb);

                if (curr_is_meta_w && dbg_meta_sink_en) begin
                    $display("[TB_META_SINK] t=%0t w addr=%016x base=%016x beat=%0d/%0d wlast=%0b exp_last=%0b active=%0b aw_pop=%0b data=%064x",
                             $time,
                             curr_beat_addr_w,
                             curr_addr_w,
                             curr_beat_idx_w,
                             curr_beats_w,
                             wlast,
                             curr_last_w,
                             burst_active,
                             aw_queue_pop_w,
                             wdata);
                    log_beat_words64(curr_beat_addr_w);
                end

                if (curr_is_meta_w && !burst_active &&
                    !aw_fifo_valid_w && !aw_fire_w) begin
                    $display("[TB_META_SINK][WARN] meta w_fire without visible burst head t=%0t addr=%016x beat=%0d",
                             $time, curr_beat_addr_w, curr_beat_idx_w);
                    if (dbg_meta_sink_fatal_en)
                        $fatal(1, "[TB_META_SINK] meta w_fire without visible burst head");
                end

                if (curr_is_meta_w && (wlast !== curr_last_w)) begin
                    $display("[TB_META_SINK][WARN] meta wlast mismatch t=%0t addr=%016x beat=%0d/%0d wlast=%0b exp_last=%0b",
                             $time, curr_beat_addr_w, curr_beat_idx_w, curr_beats_w, wlast, curr_last_w);
                    if (dbg_meta_sink_fatal_en)
                        $fatal(1, "[TB_META_SINK] meta wlast mismatch");
                end

                if (aw_queue_pop_w) begin
                    if (aw_rd_ptr == (AW_FIFO_DEPTH - 1))
                        aw_rd_ptr <= 0;
                    else
                        aw_rd_ptr <= aw_rd_ptr + 1;
                end

                if (b_fifo_push_w) begin
                    b_fifo_id[b_wr_ptr] <= curr_id_w;
                    if (b_wr_ptr == (B_FIFO_DEPTH - 1))
                        b_wr_ptr <= 0;
                    else
                        b_wr_ptr <= b_wr_ptr + 1;
                end

                if (b_fifo_push_w) begin
                    burst_active   <= 1'b0;
                    burst_beat_idx <= {BURST_BEAT_W{1'b0}};
                end else if (burst_active) begin
                    burst_beat_idx <= burst_beat_idx + {{(BURST_BEAT_W-1){1'b0}}, 1'b1};
                end else begin
                    burst_active      <= 1'b1;
                    burst_is_meta     <= curr_is_meta_w;
                    burst_addr        <= curr_addr_w;
                    burst_beats_total <= curr_beats_w;
                    burst_beat_idx    <= {{(BURST_BEAT_W-1){1'b0}}, 1'b1};
                    burst_size        <= curr_size_w;
                    burst_id          <= curr_id_w;
                end
            end

            if (b_fifo_pop_w) begin
                if (b_rd_ptr == (B_FIFO_DEPTH - 1))
                    b_rd_ptr <= 0;
                else
                    b_rd_ptr <= b_rd_ptr + 1;
            end

            case ({aw_queue_push_w, aw_queue_pop_w})
                2'b10: aw_count <= aw_count + 1;
                2'b01: aw_count <= aw_count - 1;
                default: aw_count <= aw_count;
            endcase

            case ({b_fifo_push_w, b_fifo_pop_w})
                2'b10: b_count <= b_count + 1;
                2'b01: b_count <= b_count - 1;
                default: b_count <= b_count;
            endcase
        end
    end
endmodule

module tb_ubwc_enc_wrapper_top_tajmahal_core #(
    parameter integer CASE_ID = 0
) ();
    localparam integer CASE_RGBA8888    = 0;
    localparam integer CASE_RGBA1010102 = 1;
    localparam integer CASE_NV12        = 2;
    localparam integer CASE_G016        = 3;

    localparam integer APB_AW          = 16;
    localparam integer APB_DW          = 32;
    localparam integer AXI_AW          = 64;
    localparam integer AXI_DW          = 256;
    localparam integer AXI_LENW        = 8;
    localparam integer AXI_IDW         = 6;
    localparam integer COM_BUF_AW      = 13;
    localparam integer COM_BUF_DW      = 128;
    localparam integer SB_WIDTH        = 1;

    localparam integer IMG_W           = 4096;
    localparam integer RGBA_ACTIVE_H   = 600;
    localparam integer RGBA_STORED_H   = 608;
    localparam integer RGBA_TILE_PITCH = 16384;
    localparam integer RGBA_TILE_COLS  = 256;
    localparam integer RGBA_TILE_ROWS  = 152;

    localparam integer NV12_ACTIVE_H   = 600;
    localparam integer NV12_Y_STORED_H = 640;
    localparam integer NV12_UV_STORED_H= 320;
    localparam integer NV12_TILE_PITCH   = 4096;
    localparam integer NV12_Y_TILE_COLS  = 128;
    localparam integer NV12_UV_TILE_COLS = 128;
    localparam integer NV12_Y_TILE_ROWS  = 80;
    localparam integer NV12_UV_TILE_ROWS = 40;
    localparam integer NV12_COMP_Y_WORDS64  = 311296;
    localparam integer NV12_COMP_UV_WORDS64 = 163840;

    localparam integer G016_ACTIVE_H      = 600;
    localparam integer G016_Y_STORED_H    = 608;
    localparam integer G016_UV_STORED_H   = 304;
    localparam integer G016_TILE_PITCH    = 8192;
    localparam integer G016_Y_TILE_COLS   = 128;
    localparam integer G016_UV_TILE_COLS  = 128;
    localparam integer G016_Y_TILE_ROWS   = 152;
    localparam integer G016_UV_TILE_ROWS  = 76;

    localparam integer CASE_IS_NV12       = (CASE_ID == CASE_NV12);
    localparam integer CASE_IS_G016       = (CASE_ID == CASE_G016);
    localparam integer CASE_HAS_PLANE1    = CASE_IS_NV12 || CASE_IS_G016;
    localparam integer CASE_IS_RGBA10     = (CASE_ID == CASE_RGBA1010102);
    localparam integer CASE_OTF_FMT       = CASE_IS_G016 ? 3'd3 :
                                            (CASE_IS_NV12 ? 3'd2 :
                                             (CASE_IS_RGBA10 ? 3'd1 : 3'd0));
    localparam integer CASE_CI_FMT        = CASE_IS_G016 ? 5'd14 :
                                            (CASE_IS_NV12 ? 5'd8 :
                                             (CASE_IS_RGBA10 ? 5'd1 : 5'd0));
    localparam integer CASE_STORED_H      = CASE_IS_G016 ? G016_Y_STORED_H :
                                            (CASE_IS_NV12 ? NV12_Y_STORED_H : RGBA_STORED_H);
    localparam integer CASE_TILE_W        = CASE_IS_G016 ? 32 :
                                            (CASE_IS_NV12 ? 32 : 16);
    localparam integer CASE_TILE_H        = CASE_IS_G016 ? 4 :
                                            (CASE_IS_NV12 ? 8 : 4);
    localparam integer CASE_A_TILE_COLS   = CASE_IS_G016 ? G016_UV_TILE_COLS :
                                            (CASE_IS_NV12 ? NV12_UV_TILE_COLS : RGBA_TILE_COLS);
    localparam integer CASE_B_TILE_COLS   = CASE_HAS_PLANE1 ? (CASE_IS_G016 ? G016_Y_TILE_COLS : NV12_Y_TILE_COLS) : 0;
    localparam integer CASE_PITCH_BYTES   = CASE_IS_G016 ? G016_TILE_PITCH :
                                            (CASE_IS_NV12 ? NV12_TILE_PITCH : RGBA_TILE_PITCH);
    localparam integer CASE_PITCH_UNITS = CASE_PITCH_BYTES / 16;
    localparam integer CASE_TILE0_WORDS64 = CASE_IS_G016 ? ((G016_TILE_PITCH * G016_Y_STORED_H) / 8) :
                                            (CASE_IS_NV12 ? ((NV12_TILE_PITCH * NV12_Y_STORED_H) / 8)
                                                          : ((RGBA_TILE_PITCH * RGBA_STORED_H) / 8));
    localparam integer CASE_TILE1_WORDS64 = CASE_IS_G016 ? ((G016_TILE_PITCH * G016_UV_STORED_H) / 8) :
                                            (CASE_IS_NV12 ? ((NV12_TILE_PITCH * NV12_UV_STORED_H) / 8) : 1);
    localparam integer CASE_EXPECTED_TILES = CASE_IS_G016 ? ((G016_Y_TILE_COLS  * G016_Y_TILE_ROWS) +
                                                             (G016_UV_TILE_COLS * G016_UV_TILE_ROWS)) :
                                             (CASE_IS_NV12 ? ((NV12_Y_TILE_COLS  * NV12_Y_TILE_ROWS) +
                                                              (NV12_UV_TILE_COLS * NV12_UV_TILE_ROWS))
                                                           : (RGBA_TILE_COLS * RGBA_TILE_ROWS));
    localparam integer CASE_EXPECTED_BEATS = CASE_EXPECTED_TILES * 8;
    localparam integer MAX_FRAME_REPEAT    = 8;
    localparam integer TILE_QUEUE_CAPACITY = CASE_EXPECTED_TILES * MAX_FRAME_REPEAT;
    localparam integer CASE_TIMEOUT_CYCLES = CASE_IS_NV12 ? 3000000 : 3000000;
    localparam integer CASE_ADDR_CHECK_EN  = 1;
    localparam [63:0]  CASE_TILE_BASE_Y_ADDR   = CASE_IS_G016 ? 64'h0000_0000_8000_5000 :
                                                  (CASE_IS_NV12 ? 64'h0000_0000_8000_3000 : 64'h0000_0000_8000_A000);
    localparam [63:0]  CASE_TILE_BASE_UV_ADDR  = CASE_IS_G016 ? 64'h0000_0000_804C_8000 :
                                                  (CASE_IS_NV12 ? 64'h0000_0000_8028_5000 : 64'h0000_0000_0000_0000);
    localparam [63:0]  CASE_META_BASE_Y_ADDR   = 64'h0000_0000_8000_0000;
    localparam [63:0]  CASE_META_BASE_UV_ADDR  = CASE_IS_G016 ? 64'h0000_0000_804C_5000 :
                                                  (CASE_IS_NV12 ? 64'h0000_0000_8028_3000 : 64'h0000_0000_0000_0000);
    localparam integer CASE_CMP0_WORDS64       = CASE_IS_NV12 ? NV12_COMP_Y_WORDS64 : CASE_TILE0_WORDS64;
    localparam integer CASE_CMP1_WORDS64       = CASE_HAS_PLANE1 ? (CASE_IS_NV12 ? NV12_COMP_UV_WORDS64 : CASE_TILE1_WORDS64) : 1;
    localparam integer CASE_FAKE_CMP0_WORDS64  = CASE_IS_G016 ? (G016_Y_TILE_COLS  * G016_Y_TILE_ROWS  * 32) :
                                                  (CASE_IS_NV12 ? (NV12_Y_TILE_COLS  * NV12_Y_TILE_ROWS  * 32)
                                                                : (RGBA_TILE_COLS    * RGBA_TILE_ROWS    * 32));
    localparam integer CASE_FAKE_CMP1_WORDS64  = CASE_HAS_PLANE1 ? (CASE_IS_G016 ? (G016_UV_TILE_COLS * G016_UV_TILE_ROWS * 32)
                                                                                  : (NV12_UV_TILE_COLS * NV12_UV_TILE_ROWS * 32))
                                                                  : 0;
    localparam integer CASE_META0_WORDS64      = CASE_IS_G016 ? 2560 :
                                                  (CASE_IS_NV12 ? 1536 : 5120);
    localparam integer CASE_META1_WORDS64      = CASE_IS_G016 ? 1536 :
                                                  (CASE_IS_NV12 ? 1024 : 1);
    localparam integer CASE_META_TOTAL_WORDS64 = CASE_META0_WORDS64 + (CASE_HAS_PLANE1 ? CASE_META1_WORDS64 : 0);
    localparam integer CASE_EXPECTED_META_W    = CASE_META_TOTAL_WORDS64;
    localparam integer CASE_EXPECTED_META_AW   = CASE_META_TOTAL_WORDS64;
    localparam integer CASE_EXPECTED_META0_W   = CASE_META0_WORDS64;
    localparam integer CASE_EXPECTED_META0_AW  = CASE_META0_WORDS64;
    localparam integer CASE_EXPECTED_META1_W   = CASE_HAS_PLANE1 ? CASE_META1_WORDS64 : 0;
    localparam integer CASE_EXPECTED_META1_AW  = CASE_HAS_PLANE1 ? CASE_META1_WORDS64 : 0;
    localparam integer CASE_FAKE_META0_WORDS64 = CASE_META0_WORDS64;
    localparam integer CASE_FAKE_META1_WORDS64 = CASE_HAS_PLANE1 ? CASE_META1_WORDS64 : 0;
    localparam integer CASE_FAKE_META_TOTAL_WORDS64 = CASE_FAKE_META0_WORDS64 +
                                                      (CASE_HAS_PLANE1 ? CASE_FAKE_META1_WORDS64 : 0);
    localparam integer CASE_FAKE_EXPECTED_META_W    = CASE_FAKE_META_TOTAL_WORDS64;
    localparam integer CASE_FAKE_EXPECTED_META_AW   = CASE_FAKE_META_TOTAL_WORDS64;
    localparam integer CASE_FAKE_EXPECTED_META0_W   = CASE_FAKE_META0_WORDS64;
    localparam integer CASE_FAKE_EXPECTED_META0_AW  = CASE_FAKE_META0_WORDS64;
    localparam integer CASE_FAKE_EXPECTED_META1_W   = CASE_HAS_PLANE1 ? CASE_FAKE_META1_WORDS64 : 0;
    localparam integer CASE_FAKE_EXPECTED_META1_AW  = CASE_HAS_PLANE1 ? CASE_FAKE_META1_WORDS64 : 0;
    localparam [63:0]  CASE_MAIN_BASE_MIN      = CASE_TILE_BASE_Y_ADDR;
    localparam [63:0]  CASE_META_BASE_MIN      = 64'h0000_0000_8000_0000;
    localparam integer CASE_MAIN_REF_WORDS64   = CASE_HAS_PLANE1 ?
                                                 (((CASE_TILE_BASE_UV_ADDR + (CASE_CMP1_WORDS64 * 8)) - CASE_MAIN_BASE_MIN) >> 3) :
                                                 CASE_CMP0_WORDS64;
    localparam integer CASE_META_REF_WORDS64   = CASE_HAS_PLANE1 ?
                                                 (((CASE_META_BASE_UV_ADDR + (CASE_META1_WORDS64 * 8)) - CASE_META_BASE_MIN) >> 3) :
                                                 CASE_META0_WORDS64;
    localparam [63:0]  CASE_MAIN_END_ADDR      = CASE_HAS_PLANE1 ? (CASE_TILE_BASE_UV_ADDR + (CASE_CMP1_WORDS64 * 8))
                                                                 : (CASE_TILE_BASE_Y_ADDR  + (CASE_CMP0_WORDS64 * 8));
    localparam [63:0]  CASE_META_END_ADDR      = CASE_HAS_PLANE1 ? (CASE_META_BASE_UV_ADDR + (CASE_META1_WORDS64 * 8))
                                                                 : (CASE_META_BASE_Y_ADDR  + (CASE_META0_WORDS64 * 8));
    localparam [63:0]  CASE_OUTPUT_MEM_END_ADDR = (CASE_MAIN_END_ADDR > CASE_META_END_ADDR) ?
                                                  CASE_MAIN_END_ADDR : CASE_META_END_ADDR;
    localparam integer CASE_OUTPUT_MEM_WORDS64 = (CASE_OUTPUT_MEM_END_ADDR - CASE_META_BASE_MIN) >> 3;

    reg                         clk;
    reg                         rst_n;

    reg                         PSEL;
    reg                         PENABLE;
    reg  [APB_AW-1:0]           PADDR;
    reg                         PWRITE;
    reg  [APB_DW-1:0]           PWDATA;
    wire                        PREADY;
    wire                        PSLVERR;
    wire [APB_DW-1:0]           PRDATA;

    reg                         start_otf;
    wire                        otf_done;
    wire                        otf_error;
    wire                        i_otf_vsync;
    wire                        i_otf_hsync;
    wire                        i_otf_de;
    wire [127:0]                i_otf_data;
    wire [3:0]                  i_otf_fcnt;
    wire [11:0]                 i_otf_lcnt;
    wire                        o_otf_ready;

    wire                        o_bank0_en;
    wire                        o_bank0_wen;
    wire [COM_BUF_AW-1:0]       o_bank0_addr;
    wire [COM_BUF_DW-1:0]       o_bank0_din;
    wire [COM_BUF_DW-1:0]       i_bank0_dout;
    wire                        i_bank0_dout_vld;
    wire                        o_bank1_en;
    wire                        o_bank1_wen;
    wire [COM_BUF_AW-1:0]       o_bank1_addr;
    wire [COM_BUF_DW-1:0]       o_bank1_din;
    wire [COM_BUF_DW-1:0]       i_bank1_dout;
    wire                        i_bank1_dout_vld;

    wire [AXI_IDW:0]            o_m_axi_awid;
    wire [AXI_AW-1:0]           o_m_axi_awaddr;
    wire [AXI_LENW-1:0]         o_m_axi_awlen;
    wire [2:0]                  o_m_axi_awsize;
    wire [1:0]                  o_m_axi_awburst;
    wire [1:0]                  o_m_axi_awlock;
    wire [3:0]                  o_m_axi_awcache;
    wire [2:0]                  o_m_axi_awprot;
    wire                        o_m_axi_awvalid;
    wire                        i_m_axi_awready;
    wire [AXI_DW-1:0]           o_m_axi_wdata;
    wire [(AXI_DW/8)-1:0]       o_m_axi_wstrb;
    wire                        o_m_axi_wvalid;
    wire                        o_m_axi_wlast;
    wire                        i_m_axi_wready;
    wire [AXI_IDW:0]            i_m_axi_bid;
    wire [1:0]                  i_m_axi_bresp;
    wire                        i_m_axi_bvalid;
    wire                        o_m_axi_bready;

    reg  [63:0]                 tile_plane0_words [0:CASE_TILE0_WORDS64-1];
    reg  [63:0]                 tile_plane1_words [0:CASE_TILE1_WORDS64-1];
    reg  [63:0]                 exp_main_words [0:CASE_MAIN_REF_WORDS64-1];
    reg  [63:0]                 exp_meta_words [0:CASE_META_REF_WORDS64-1];

    reg  [4:0]                  cmd_fmt_queue [0:TILE_QUEUE_CAPACITY-1];
    reg  [15:0]                 cmd_x_queue   [0:TILE_QUEUE_CAPACITY-1];
    reg  [15:0]                 cmd_y_queue   [0:TILE_QUEUE_CAPACITY-1];
    reg  [4:0]                  rvi_fmt_queue [0:TILE_QUEUE_CAPACITY-1];
    reg  [15:0]                 rvi_x_queue   [0:TILE_QUEUE_CAPACITY-1];
    reg  [15:0]                 rvi_y_queue   [0:TILE_QUEUE_CAPACITY-1];
    reg  [4:0]                  cvo_fmt_queue [0:TILE_QUEUE_CAPACITY-1];
    reg  [15:0]                 cvo_x_queue   [0:TILE_QUEUE_CAPACITY-1];
    reg  [15:0]                 cvo_y_queue   [0:TILE_QUEUE_CAPACITY-1];
    reg  [AXI_AW-1:0]           cvo_addr_queue[0:TILE_QUEUE_CAPACITY-1];
    reg  [3:0]                  cvo_beats_queue[0:TILE_QUEUE_CAPACITY-1];

    integer                     cmd_wr_ptr;
    integer                     cmd_rd_ptr;
    integer                     rvi_cmd_wr_ptr;
    integer                     cvo_cmd_wr_ptr;
    integer                     cvo_cmd_rd_ptr;
    reg                         active_cmd_valid;
    reg  [4:0]                  active_cmd_fmt;
    reg  [15:0]                 active_cmd_x;
    reg  [15:0]                 active_cmd_y;
    integer                     active_cmd_beat_idx;

    integer                     coord_count;
    integer                     aw_count;
    integer                     w_count;
    integer                     meta_aw_count;
    integer                     meta_aw_count_plane0;
    integer                     meta_aw_count_plane1;
    integer                     aw_mismatch_count;
    integer                     data_mismatch_count;
    integer                     strb_mismatch_count;
    integer                     wlast_mismatch_count;
    integer                     queue_underflow_count;
    integer                     fail_count;
    integer                     timeout_count;
    integer                     idle_cycles_after_done;
    integer                     case_timeout_cycles;
    integer                     tb_frame_repeat;
    integer                     frames_started;
    integer                     frames_completed;
    integer                     expected_tiles_total;
    integer                     expected_beats_total;
    integer                     expected_meta_aw_total;
    integer                     expected_meta_w_total;
    integer                     expected_meta_aw_plane0_total;
    integer                     expected_meta_aw_plane1_total;
    integer                     expected_meta_w_plane0_total;
    integer                     expected_meta_w_plane1_total;
    integer                     otf_done_count;
    integer                     rvi_beat_count;
    integer                     rvi_beat_idx;
    integer                     rvi_cmd_rd_ptr;
    integer                     cvo_beat_count;
    integer                     rvi_data_mismatch_count;
    integer                     cvo_data_mismatch_count;
    reg                         rvi_active_cmd_valid;
    reg  [4:0]                  rvi_active_cmd_fmt;
    reg  [15:0]                 rvi_active_cmd_x;
    reg  [15:0]                 rvi_active_cmd_y;
    reg                         cvo_active_cmd_valid;
    reg  [4:0]                  cvo_active_cmd_fmt;
    reg  [15:0]                 cvo_active_cmd_x;
    reg  [15:0]                 cvo_active_cmd_y;
    reg  [AXI_AW-1:0]           cvo_active_cmd_addr;
    reg  [3:0]                  cvo_active_cmd_beats;
    integer                     cvo_beat_idx;
    reg                         first_rvi_data_mismatch_seen;
    reg  [4:0]                  first_rvi_data_fmt;
    reg  [15:0]                 first_rvi_data_x;
    reg  [15:0]                 first_rvi_data_y;
    integer                     first_rvi_data_beat;
    reg  [AXI_DW-1:0]           first_rvi_data_expected;
    reg  [AXI_DW-1:0]           first_rvi_data_actual;
    reg                         first_cvo_data_mismatch_seen;
    reg  [4:0]                  first_cvo_data_fmt;
    reg  [15:0]                 first_cvo_data_x;
    reg  [15:0]                 first_cvo_data_y;
    integer                     first_cvo_data_beat;
    reg  [AXI_DW-1:0]           first_cvo_data_expected;
    reg  [AXI_DW-1:0]           first_cvo_data_actual;
    reg                         first_aw_mismatch_seen;
    reg  [AXI_AW-1:0]           first_aw_actual;
    reg  [AXI_AW-1:0]           first_aw_expected;
    reg  [4:0]                  first_aw_fmt;
    reg  [15:0]                 first_aw_x;
    reg  [15:0]                 first_aw_y;
    reg                         first_data_mismatch_seen;
    reg  [4:0]                  first_data_fmt;
    reg  [15:0]                 first_data_x;
    reg  [15:0]                 first_data_y;
    integer                     first_data_beat;
    reg  [AXI_DW-1:0]           first_data_expected;
    reg  [AXI_DW-1:0]           first_data_actual;
    wire                        dbg_otf_to_tile_ci_valid;
    wire                        dbg_otf_to_tile_ci_ready;
    wire                        dbg_otf_to_tile_last;
    wire                        dbg_otf_to_tile_coord_vld;
    wire [15:0]                 dbg_otf_to_tile_x;
    wire [15:0]                 dbg_otf_to_tile_y;
    wire [3:0]                  dbg_otf_to_tile_fcnt;
    wire [4:0]                  dbg_otf_to_tile_format;
    reg                         dbg_line_tile_en;
    reg                         tb_fake_mode_en;
    integer                     out_aw_count;
    integer                     out_w_count;
    integer                     main_mem_mismatch_count;
    integer                     meta_mem_mismatch_count;
    integer                     main_plane0_mem_mismatch_count;
    integer                     main_plane1_mem_mismatch_count;
    integer                     meta_plane0_mem_mismatch_count;
    integer                     meta_plane1_mem_mismatch_count;
    integer                     out_range_mismatch_count;
    integer                     out_wlast_mismatch_count;
    integer                     meta_w_count;
    integer                     meta_w_count_plane0;
    integer                     meta_w_count_plane1;
    integer                     meta_dump_mismatch_count;
    integer                     meta_dump_mismatch_plane0_count;
    integer                     meta_dump_mismatch_plane1_count;
    integer                     meta_dump_word_count_error_count;
    integer                     meta_in_fifo_drop_count;
    integer                     meta_gen_fire_count;
    integer                     meta_gen_fire_count_plane0;
    integer                     meta_gen_fire_count_plane1;
    integer                     meta_gen_y_active_count;
    integer                     meta_gen_y_pad_count;
    reg                         first_out_range_seen;
    reg  [2:0]                  first_out_range_kind;
    reg  [AXI_AW-1:0]           first_out_range_addr;
    reg  [AXI_LENW:0]           first_out_range_beat_idx;
    reg  [AXI_LENW:0]           first_out_range_beats_total;
    reg                         first_meta_aw_seen;
    reg  [AXI_AW-1:0]           first_meta_aw_addr;
    reg  [AXI_AW-1:0]           last_meta_aw_addr_y;
    reg  [AXI_AW-1:0]           last_meta_aw_addr_uv;
    reg  [AXI_AW-1:0]           first_meta_aw_y_base;
    reg  [AXI_AW-1:0]           first_meta_aw_uv_base;
    reg  [AXI_AW-1:0]           first_meta_aw_y_meta_addr;
    reg  [AXI_AW-1:0]           first_meta_aw_uv_meta_addr;
    reg                         first_meta_aw_sel_uv;
    reg                         out_burst_active;
    reg                         out_burst_is_meta;
    reg  [AXI_AW-1:0]           out_burst_addr;
    reg  [AXI_LENW:0]           out_burst_beats_total;
    reg  [AXI_LENW:0]           out_burst_beat_idx;
    reg                         main_burst_active;
    reg  [AXI_AW-1:0]           main_burst_addr;
    reg  [AXI_LENW:0]           main_burst_beats_total;
    reg  [AXI_LENW:0]           main_burst_beat_idx;
    reg                         meta_burst_active;
    reg  [AXI_AW-1:0]           meta_burst_addr;
    reg  [AXI_LENW:0]           meta_burst_beats_total;
    reg  [AXI_LENW:0]           meta_burst_beat_idx;
    reg                         first_main_mem_mismatch_seen;
    reg                         first_meta_mem_mismatch_seen;
    reg                         first_meta_dump_mismatch_seen;
    reg  [AXI_AW-1:0]           first_main_mem_addr;
    reg  [AXI_AW-1:0]           first_meta_mem_addr;
    reg  [AXI_AW-1:0]           first_meta_dump_addr;
    reg  [AXI_DW-1:0]           first_main_mem_expected;
    reg  [AXI_DW-1:0]           first_main_mem_actual;
    reg  [AXI_DW-1:0]           first_meta_mem_expected;
    reg  [AXI_DW-1:0]           first_meta_mem_actual;
    reg  [63:0]                 first_meta_dump_expected;
    reg  [63:0]                 first_meta_dump_actual;
    reg                         first_meta_in_fifo_drop_seen;
    reg  [4:0]                  first_meta_in_fifo_drop_fmt;
    reg  [27:0]                 first_meta_in_fifo_drop_x;
    reg  [12:0]                 first_meta_in_fifo_drop_y;
    reg  [AXI_DW/8-1:0]         first_main_mem_strb;
    reg  [AXI_DW/8-1:0]         first_meta_mem_strb;
    reg                         ref_cmp_mismatch;
    reg                         ref_cmp_range_error;
    reg  [AXI_DW-1:0]           ref_cmp_expected_word;
    wire                        tb_output_activity;
    wire                        meta_aw_fire_w;
    wire                        meta_w_fire_w;
    wire                        meta_use_curr_aw_w;
    wire [AXI_AW-1:0]           meta_write_beat_addr_w;
    wire                        meta_write_underflow_w;
    wire                        rvi_start_direct_w;
    wire                        cvo_start_direct_w;
    integer                     main_dump_fd;
    integer                     main_dump_fd_plane1;
    integer                     meta_dump_fd;
    integer                     meta_dump_fd_plane1;
    string                      main_dump_file;
    string                      main_dump_file_plane1;
    string                      meta_dump_file;
    string                      meta_dump_file_plane1;
    reg                         main_dump_has_prev_addr;
    reg                         meta_dump_has_prev_addr;
    reg  [AXI_AW-1:0]           main_dump_next_addr;
    reg  [AXI_AW-1:0]           meta_dump_next_addr;

    function automatic integer macro_tile_slot;
        input integer tile_x_mod8;
        input integer tile_y_mod8;
        begin
            case (tile_x_mod8)
                0: case (tile_y_mod8) 0: macro_tile_slot = 0; 1: macro_tile_slot = 6; 2: macro_tile_slot = 3; 3: macro_tile_slot = 5; 4: macro_tile_slot = 4; 5: macro_tile_slot = 2; 6: macro_tile_slot = 7; default: macro_tile_slot = 1; endcase
                1: case (tile_y_mod8) 0: macro_tile_slot = 7; 1: macro_tile_slot = 1; 2: macro_tile_slot = 4; 3: macro_tile_slot = 2; 4: macro_tile_slot = 3; 5: macro_tile_slot = 5; 6: macro_tile_slot = 0; default: macro_tile_slot = 6; endcase
                2: case (tile_y_mod8) 0: macro_tile_slot = 10; 1: macro_tile_slot = 12; 2: macro_tile_slot = 9; 3: macro_tile_slot = 15; 4: macro_tile_slot = 14; 5: macro_tile_slot = 8; 6: macro_tile_slot = 13; default: macro_tile_slot = 11; endcase
                3: case (tile_y_mod8) 0: macro_tile_slot = 13; 1: macro_tile_slot = 11; 2: macro_tile_slot = 14; 3: macro_tile_slot = 8; 4: macro_tile_slot = 9; 5: macro_tile_slot = 15; 6: macro_tile_slot = 10; default: macro_tile_slot = 12; endcase
                4: case (tile_y_mod8) 0: macro_tile_slot = 4; 1: macro_tile_slot = 2; 2: macro_tile_slot = 7; 3: macro_tile_slot = 1; 4: macro_tile_slot = 0; 5: macro_tile_slot = 6; 6: macro_tile_slot = 3; default: macro_tile_slot = 5; endcase
                5: case (tile_y_mod8) 0: macro_tile_slot = 3; 1: macro_tile_slot = 5; 2: macro_tile_slot = 0; 3: macro_tile_slot = 6; 4: macro_tile_slot = 7; 5: macro_tile_slot = 1; 6: macro_tile_slot = 4; default: macro_tile_slot = 2; endcase
                6: case (tile_y_mod8) 0: macro_tile_slot = 14; 1: macro_tile_slot = 8; 2: macro_tile_slot = 13; 3: macro_tile_slot = 11; 4: macro_tile_slot = 10; 5: macro_tile_slot = 12; 6: macro_tile_slot = 9; default: macro_tile_slot = 15; endcase
                default: case (tile_y_mod8) 0: macro_tile_slot = 9; 1: macro_tile_slot = 15; 2: macro_tile_slot = 10; 3: macro_tile_slot = 12; 4: macro_tile_slot = 13; 5: macro_tile_slot = 11; 6: macro_tile_slot = 14; default: macro_tile_slot = 8; endcase
            endcase
        end
    endfunction

    function automatic integer rgba_tile_base_word;
        input integer tile_x;
        input integer tile_y;
        integer addr_bytes;
        integer macro_tile_x;
        integer macro_tile_y;
        integer temp_tile_x;
        integer temp_tile_y;
        integer tile_row_pixels;
        integer bit_val;
        begin
            macro_tile_x = tile_x / 4;
            macro_tile_y = tile_y / 4;
            temp_tile_x  = tile_x % 8;
            temp_tile_y  = tile_y % 8;

            addr_bytes = (RGBA_TILE_PITCH * (macro_tile_y * 4) * 4) +
                         (macro_tile_x * 4096) +
                         (macro_tile_slot(temp_tile_x, temp_tile_y) * 256);

            if (((16 * RGBA_TILE_PITCH) % (1 << 16)) == 0) begin
                tile_row_pixels = tile_y * 4;
                bit_val = ((addr_bytes >> 15) & 1) ^ ((tile_row_pixels >> 4) & 1);
                if (bit_val != 0)
                    addr_bytes = addr_bytes | (1 << 15);
                else
                    addr_bytes = addr_bytes & ~(1 << 15);
            end

            if (((16 * RGBA_TILE_PITCH) % (1 << 17)) == 0) begin
                tile_row_pixels = tile_y * 4;
                bit_val = ((addr_bytes >> 16) & 1) ^ ((tile_row_pixels >> 5) & 1);
                if (bit_val != 0)
                    addr_bytes = addr_bytes | (1 << 16);
                else
                    addr_bytes = addr_bytes & ~(1 << 16);
            end

            rgba_tile_base_word = addr_bytes >> 3;
        end
    endfunction

    function automatic integer plane_tile_base_word;
        input integer tile_x;
        input integer tile_y;
        input integer tile_width;
        input integer tile_height;
        input integer surface_pitch_bytes;
        input integer bpp;
        integer addr_bytes;
        integer macro_tile_x;
        integer macro_tile_y;
        integer temp_tile_x;
        integer temp_tile_y;
        integer tile_row_pixels;
        integer bit_val;
        begin
            macro_tile_x = tile_x / 4;
            macro_tile_y = tile_y / 4;
            temp_tile_x  = tile_x % 8;
            temp_tile_y  = tile_y % 8;

            addr_bytes = (surface_pitch_bytes * (macro_tile_y * 4) * tile_height) +
                         (macro_tile_x * 4096) +
                         (macro_tile_slot(temp_tile_x, temp_tile_y) * 256);

            if (((16 * surface_pitch_bytes) % (1 << 16)) == 0) begin
                if (((bpp == 1) && (tile_width == 32) && (tile_height == 8)) ||
                    ((bpp == 2) && (tile_width == 16) && (tile_height == 8))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 4;
                end
                bit_val = ((addr_bytes >> 15) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0)
                    addr_bytes = addr_bytes | (1 << 15);
                else
                    addr_bytes = addr_bytes & ~(1 << 15);
            end

            if (((16 * surface_pitch_bytes) % (1 << 17)) == 0) begin
                if (((bpp == 1) && (tile_width == 32) && (tile_height == 8)) ||
                    ((bpp == 2) && (tile_width == 16) && (tile_height == 8))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 6;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end
                bit_val = ((addr_bytes >> 16) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0)
                    addr_bytes = addr_bytes | (1 << 16);
                else
                    addr_bytes = addr_bytes & ~(1 << 16);
            end

            plane_tile_base_word = addr_bytes >> 3;
        end
    endfunction

    function automatic [AXI_AW-1:0] expected_tile_addr;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        integer base_word;
        reg [AXI_AW-1:0] base_addr_local;
        begin
            if ((fmt == 5'd0) || (fmt == 5'd1)) begin
                base_word = rgba_tile_base_word(tile_x, tile_y);
                base_addr_local = CASE_TILE_BASE_Y_ADDR;
            end else if (fmt == 5'd8) begin
                base_word = plane_tile_base_word(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, 1);
                base_addr_local = CASE_TILE_BASE_Y_ADDR;
            end else if (fmt == 5'd14) begin
                base_word = plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, 2);
                base_addr_local = CASE_TILE_BASE_Y_ADDR;
            end else if (fmt == 5'd15) begin
                base_word = plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, 2);
                base_addr_local = CASE_TILE_BASE_UV_ADDR;
            end else begin
                base_word = plane_tile_base_word(tile_x, tile_y, 16, 8, NV12_TILE_PITCH, 2);
                base_addr_local = CASE_TILE_BASE_UV_ADDR;
            end
            expected_tile_addr = base_addr_local + (base_word << 3);
        end
    endfunction

    function automatic [AXI_DW-1:0] pack_expected_tile_axi_word;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer beat_idx;
        integer word64_base;
        integer word_idx;
        reg [63:0] w0;
        reg [63:0] w1;
        reg [63:0] w2;
        reg [63:0] w3;
        begin
            if ((fmt == 5'd0) || (fmt == 5'd1)) begin
                word64_base = rgba_tile_base_word(tile_x, tile_y);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE0_WORDS64) ? tile_plane0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE0_WORDS64) ? tile_plane0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE0_WORDS64) ? tile_plane0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE0_WORDS64) ? tile_plane0_words[word_idx + 3] : 64'd0;
            end else if (fmt == 5'd8) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, 1);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE0_WORDS64) ? tile_plane0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE0_WORDS64) ? tile_plane0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE0_WORDS64) ? tile_plane0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE0_WORDS64) ? tile_plane0_words[word_idx + 3] : 64'd0;
            end else if (fmt == 5'd14) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, 2);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE0_WORDS64) ? tile_plane0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE0_WORDS64) ? tile_plane0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE0_WORDS64) ? tile_plane0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE0_WORDS64) ? tile_plane0_words[word_idx + 3] : 64'd0;
            end else if (fmt == 5'd15) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, 2);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE1_WORDS64) ? tile_plane1_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE1_WORDS64) ? tile_plane1_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE1_WORDS64) ? tile_plane1_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE1_WORDS64) ? tile_plane1_words[word_idx + 3] : 64'd0;
            end else begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 16, 8, NV12_TILE_PITCH, 2);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE1_WORDS64) ? tile_plane1_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE1_WORDS64) ? tile_plane1_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE1_WORDS64) ? tile_plane1_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE1_WORDS64) ? tile_plane1_words[word_idx + 3] : 64'd0;
            end
            pack_expected_tile_axi_word = {w3, w2, w1, w0};
        end
    endfunction

    function automatic [AXI_DW-1:0] pack_main_ref_axi_word;
        input [AXI_AW-1:0] beat_addr;
        integer word_idx;
        reg [63:0] w0;
        reg [63:0] w1;
        reg [63:0] w2;
        reg [63:0] w3;
        begin
            word_idx = (beat_addr - CASE_MAIN_BASE_MIN) >> 3;
            w0 = (word_idx + 0 < CASE_MAIN_REF_WORDS64) ? exp_main_words[word_idx + 0] : 64'd0;
            w1 = (word_idx + 1 < CASE_MAIN_REF_WORDS64) ? exp_main_words[word_idx + 1] : 64'd0;
            w2 = (word_idx + 2 < CASE_MAIN_REF_WORDS64) ? exp_main_words[word_idx + 2] : 64'd0;
            w3 = (word_idx + 3 < CASE_MAIN_REF_WORDS64) ? exp_main_words[word_idx + 3] : 64'd0;
            pack_main_ref_axi_word = {w3, w2, w1, w0};
        end
    endfunction

    function automatic masked_axi_word_mismatch;
        input [AXI_DW-1:0] actual_data;
        input [AXI_DW/8-1:0] actual_mask;
        input [AXI_DW-1:0] expected_data;
        integer byte_idx;
        begin
            masked_axi_word_mismatch = 1'b0;
            for (byte_idx = 0; byte_idx < (AXI_DW/8); byte_idx = byte_idx + 1) begin
                if (actual_mask[byte_idx] &&
                    (actual_data[byte_idx*8 +: 8] !== expected_data[byte_idx*8 +: 8]))
                    masked_axi_word_mismatch = 1'b1;
            end
        end
    endfunction

    function automatic main_word_addr_valid;
        input [AXI_AW-1:0] byte_addr;
        integer main_y_words64;
        integer main_uv_words64;
        begin
            if (tb_fake_mode_en) begin
                main_y_words64  = CASE_FAKE_CMP0_WORDS64;
                main_uv_words64 = CASE_HAS_PLANE1 ? CASE_FAKE_CMP1_WORDS64 : 0;
            end else begin
                main_y_words64  = CASE_CMP0_WORDS64;
                main_uv_words64 = CASE_HAS_PLANE1 ? CASE_CMP1_WORDS64 : 0;
            end

            if (CASE_HAS_PLANE1) begin
                main_word_addr_valid = ((byte_addr >= CASE_TILE_BASE_Y_ADDR) &&
                                        (byte_addr < (CASE_TILE_BASE_Y_ADDR + main_y_words64 * 8))) ||
                                       ((byte_addr >= CASE_TILE_BASE_UV_ADDR) &&
                                        (byte_addr < (CASE_TILE_BASE_UV_ADDR + main_uv_words64 * 8)));
            end else begin
                main_word_addr_valid = (byte_addr >= CASE_TILE_BASE_Y_ADDR) &&
                                       (byte_addr < (CASE_TILE_BASE_Y_ADDR + main_y_words64 * 8));
            end
        end
    endfunction

    function automatic meta_word_addr_valid;
        input [AXI_AW-1:0] byte_addr;
        integer meta_y_words64;
        integer meta_uv_words64;
        begin
            if (tb_fake_mode_en) begin
                meta_y_words64  = CASE_FAKE_META0_WORDS64;
                meta_uv_words64 = CASE_HAS_PLANE1 ? CASE_FAKE_META1_WORDS64 : 0;
            end else begin
                meta_y_words64  = CASE_META0_WORDS64;
                meta_uv_words64 = CASE_HAS_PLANE1 ? CASE_META1_WORDS64 : 0;
            end

            if (CASE_HAS_PLANE1) begin
                meta_word_addr_valid = ((byte_addr >= CASE_META_BASE_Y_ADDR) &&
                                        (byte_addr < (CASE_META_BASE_Y_ADDR + meta_y_words64 * 8))) ||
                                       ((byte_addr >= CASE_META_BASE_UV_ADDR) &&
                                        (byte_addr < (CASE_META_BASE_UV_ADDR + meta_uv_words64 * 8)));
            end else begin
                meta_word_addr_valid = (byte_addr >= CASE_META_BASE_Y_ADDR) &&
                                       (byte_addr < (CASE_META_BASE_Y_ADDR + meta_y_words64 * 8));
            end
        end
    endfunction

    function automatic meta_v2_strb_valid;
        input [AXI_DW/8-1:0] strb;
        integer lane_idx;
        reg [AXI_DW/8-1:0] lane_mask;
        begin
            meta_v2_strb_valid = 1'b0;
            for (lane_idx = 0; lane_idx < (AXI_DW/64); lane_idx = lane_idx + 1) begin
                lane_mask = {(AXI_DW/8){1'b0}};
                lane_mask[lane_idx*8 +: 8] = 8'hFF;
                if (strb === lane_mask)
                    meta_v2_strb_valid = 1'b1;
            end
        end
    endfunction

    function automatic [63:0] main_ref_word64;
        input [AXI_AW-1:0] byte_addr;
        integer word_idx;
        begin
            word_idx = (byte_addr - CASE_MAIN_BASE_MIN) >> 3;
            if ((word_idx >= 0) && (word_idx < CASE_MAIN_REF_WORDS64))
                main_ref_word64 = exp_main_words[word_idx];
            else
                main_ref_word64 = 64'd0;
        end
    endfunction

    function automatic [63:0] meta_ref_word64;
        input [AXI_AW-1:0] byte_addr;
        integer word_idx;
        begin
            word_idx = (byte_addr - CASE_META_BASE_MIN) >> 3;
            if ((word_idx >= 0) && (word_idx < CASE_META_REF_WORDS64))
                meta_ref_word64 = exp_meta_words[word_idx];
            else
                meta_ref_word64 = 64'd0;
        end
    endfunction

    task automatic init_ref_word_arrays;
        integer idx;
        begin
            for (idx = 0; idx < CASE_TILE0_WORDS64; idx = idx + 1)
                tile_plane0_words[idx] = 64'd0;
            for (idx = 0; idx < CASE_TILE1_WORDS64; idx = idx + 1)
                tile_plane1_words[idx] = 64'd0;
            for (idx = 0; idx < CASE_MAIN_REF_WORDS64; idx = idx + 1)
                exp_main_words[idx] = 64'd0;
            for (idx = 0; idx < CASE_META_REF_WORDS64; idx = idx + 1)
                exp_meta_words[idx] = 64'd0;
        end
    endtask

    task automatic load_dump64_to_tile_plane;
        input [8*256-1:0]        file_name;
        input integer            plane_sel;
        input [AXI_AW-1:0]       file_base_addr;
        input integer            exp_word_count;
        integer                  fd;
        integer                  r;
        integer                  idx;
        reg [8*256-1:0]          line_buf_local;
        reg [63:0]               word_local;
        reg [AXI_AW-1:0]         header_addr_local;
        begin
            fd = $fopen(file_name, "r");
            if (fd == 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] cannot open tile-plane reference file: %0s", file_name);
            end else begin
                idx = 0;
                while (!$feof(fd)) begin
                    line_buf_local = '0;
                    r = $fgets(line_buf_local, fd);
                    if (r != 0) begin
                        if ($sscanf(line_buf_local, "@%h", header_addr_local) == 1) begin
                            if (header_addr_local !== file_base_addr) begin
                                fail_count = fail_count + 1;
                                $display("[TB][ERROR] tile-plane base mismatch file=%0s exp=0x%016x act=0x%016x",
                                         file_name, file_base_addr, header_addr_local);
                            end
                        end else if ($sscanf(line_buf_local, "%h", word_local) == 1) begin
                            if (plane_sel != 0) begin
                                if (idx < CASE_TILE1_WORDS64)
                                    tile_plane1_words[idx] = word_local;
                            end else begin
                                if (idx < CASE_TILE0_WORDS64)
                                    tile_plane0_words[idx] = word_local;
                            end
                            idx = idx + 1;
                        end
                    end
                end
                $fclose(fd);

                if (idx != exp_word_count) begin
                    fail_count = fail_count + 1;
                    $display("[TB][ERROR] tile-plane word count mismatch file=%0s exp=%0d act=%0d",
                             file_name, exp_word_count, idx);
                end
            end
        end
    endtask

    task automatic load_dump64_to_ref;
        input [8*256-1:0]        file_name;
        input integer            is_meta;
        input [AXI_AW-1:0]       file_base_addr;
        input integer            exp_word_count;
        integer                  fd;
        integer                  r;
        integer                  idx;
        integer                  base_word_idx;
        reg [8*256-1:0]          line_buf_local;
        reg [63:0]               word_local;
        reg [AXI_AW-1:0]         header_addr_local;
        begin
            fd = $fopen(file_name, "r");
            if (fd == 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] cannot open reference file: %0s", file_name);
            end else begin
                idx = 0;
                while (!$feof(fd)) begin
                    line_buf_local = '0;
                    r = $fgets(line_buf_local, fd);
                    if (r != 0) begin
                        if ($sscanf(line_buf_local, "@%h", header_addr_local) == 1) begin
                            if (header_addr_local !== file_base_addr) begin
                                fail_count = fail_count + 1;
                                $display("[TB][ERROR] reference base mismatch file=%0s exp=0x%016x act=0x%016x",
                                         file_name, file_base_addr, header_addr_local);
                            end
                        end else if ($sscanf(line_buf_local, "%h", word_local) == 1) begin
                            if (is_meta != 0)
                                base_word_idx = (file_base_addr - CASE_META_BASE_MIN) >> 3;
                            else
                                base_word_idx = (file_base_addr - CASE_MAIN_BASE_MIN) >> 3;

                            if (is_meta != 0) begin
                                if ((base_word_idx + idx) < CASE_META_REF_WORDS64)
                                    exp_meta_words[base_word_idx + idx] = word_local;
                            end else begin
                                if ((base_word_idx + idx) < CASE_MAIN_REF_WORDS64)
                                    exp_main_words[base_word_idx + idx] = word_local;
                            end
                            idx = idx + 1;
                        end
                    end
                end
                $fclose(fd);

                if (idx != exp_word_count) begin
                    fail_count = fail_count + 1;
                    $display("[TB][ERROR] reference word count mismatch file=%0s exp=%0d act=%0d",
                             file_name, exp_word_count, idx);
                end
            end
        end
    endtask

    task automatic compare_ref_beat;
        input integer            is_meta;
        input [AXI_AW-1:0]       beat_addr;
        input [AXI_DW-1:0]       actual_data;
        input [AXI_DW/8-1:0]     actual_strb;
        output reg               mismatch;
        output reg               range_error;
        output reg [AXI_DW-1:0]  expected_word;
        integer                  lane_idx;
        integer                  byte_idx;
        reg [AXI_AW-1:0]         lane_addr;
        reg [63:0]               exp_word;
        begin
            mismatch     = 1'b0;
            range_error  = 1'b0;
            expected_word = {AXI_DW{1'b0}};

            for (lane_idx = 0; lane_idx < (AXI_DW/64); lane_idx = lane_idx + 1) begin
                lane_addr = beat_addr + (lane_idx * 8);
                if (is_meta != 0)
                    exp_word = meta_ref_word64(lane_addr);
                else
                    exp_word = main_ref_word64(lane_addr);

                expected_word[lane_idx*64 +: 64] = exp_word;

                if (actual_strb[lane_idx*8 +: 8] != 8'd0) begin
                    if ((is_meta != 0) ? !meta_word_addr_valid(lane_addr) : !main_word_addr_valid(lane_addr)) begin
                        range_error = 1'b1;
                    end else begin
                        for (byte_idx = 0; byte_idx < 8; byte_idx = byte_idx + 1) begin
                            if (actual_strb[lane_idx*8 + byte_idx] &&
                                (actual_data[lane_idx*64 + byte_idx*8 +: 8] !== exp_word[byte_idx*8 +: 8])) begin
                                mismatch = 1'b1;
                            end
                        end
                    end
                end
            end
        end
    endtask

    task automatic compare_meta_dump_file_to_ref;
        input string             file_name;
        input [AXI_AW-1:0]       file_base_addr;
        input integer            exp_word_count;
        input integer            plane_sel;
        integer                  fd;
        integer                  r;
        integer                  idx;
        reg [8*256-1:0]          line_buf_local;
        reg [63:0]               word_local;
        reg [63:0]               exp_word_local;
        reg [AXI_AW-1:0]         header_addr_local;
        reg [AXI_AW-1:0]         curr_addr_local;
        begin
            fd = $fopen(file_name, "r");
            if (fd == 0) begin
                fail_count = fail_count + 1;
                meta_dump_word_count_error_count = meta_dump_word_count_error_count + 1;
                $display("[TB][ERROR] cannot open dumped meta file for compare: %0s", file_name);
            end else begin
                idx = 0;
                while (!$feof(fd)) begin
                    line_buf_local = '0;
                    r = $fgets(line_buf_local, fd);
                    if (r != 0) begin
                        if ($sscanf(line_buf_local, "@%h", header_addr_local) == 1) begin
                            if (header_addr_local !== file_base_addr) begin
                                fail_count = fail_count + 1;
                                meta_dump_word_count_error_count = meta_dump_word_count_error_count + 1;
                                $display("[TB][ERROR] dumped meta base mismatch file=%0s exp=0x%016x act=0x%016x",
                                         file_name, file_base_addr, header_addr_local);
                            end
                        end else if ($sscanf(line_buf_local, "%h", word_local) == 1) begin
                            curr_addr_local = file_base_addr + (idx * 8);
                            exp_word_local  = meta_ref_word64(curr_addr_local);
                            if (word_local !== exp_word_local) begin
                                meta_dump_mismatch_count = meta_dump_mismatch_count + 1;
                                if (plane_sel != 0)
                                    meta_dump_mismatch_plane1_count = meta_dump_mismatch_plane1_count + 1;
                                else
                                    meta_dump_mismatch_plane0_count = meta_dump_mismatch_plane0_count + 1;
                                if (!first_meta_dump_mismatch_seen) begin
                                    first_meta_dump_mismatch_seen = 1'b1;
                                    first_meta_dump_addr         = curr_addr_local;
                                    first_meta_dump_expected     = exp_word_local;
                                    first_meta_dump_actual       = word_local;
                                end
                            end
                            idx = idx + 1;
                        end
                    end
                end
                $fclose(fd);

                if (idx != exp_word_count) begin
                    fail_count = fail_count + 1;
                    meta_dump_word_count_error_count = meta_dump_word_count_error_count + 1;
                    $display("[TB][ERROR] dumped meta word count mismatch file=%0s exp=%0d act=%0d",
                             file_name, exp_word_count, idx);
                end
            end
        end
    endtask

    task automatic open_mem_dump_files;
        begin
            if (tb_fake_mode_en) begin
                case (CASE_ID)
                    CASE_RGBA1010102: begin
                        main_dump_file        = "tb_ubwc_enc_wrapper_top_tajmahal_rgba1010102_fake_main_mem.txt";
                        main_dump_file_plane1 = "";
                        meta_dump_file        = "tb_ubwc_enc_wrapper_top_tajmahal_rgba1010102_fake_meta_mem.txt";
                        meta_dump_file_plane1 = "";
                    end
                    CASE_G016: begin
                        main_dump_file        = "tb_ubwc_enc_wrapper_top_k_outdoor61_g016_fake_main_y_mem.txt";
                        main_dump_file_plane1 = "tb_ubwc_enc_wrapper_top_k_outdoor61_g016_fake_main_uv_mem.txt";
                        meta_dump_file        = "tb_ubwc_enc_wrapper_top_k_outdoor61_g016_fake_meta_y_mem.txt";
                        meta_dump_file_plane1 = "tb_ubwc_enc_wrapper_top_k_outdoor61_g016_fake_meta_uv_mem.txt";
                    end
                    CASE_NV12: begin
                        main_dump_file        = "tb_ubwc_enc_wrapper_top_tajmahal_nv12_fake_main_y_mem.txt";
                        main_dump_file_plane1 = "tb_ubwc_enc_wrapper_top_tajmahal_nv12_fake_main_uv_mem.txt";
                        meta_dump_file        = "tb_ubwc_enc_wrapper_top_tajmahal_nv12_fake_meta_y_mem.txt";
                        meta_dump_file_plane1 = "tb_ubwc_enc_wrapper_top_tajmahal_nv12_fake_meta_uv_mem.txt";
                    end
                    default: begin
                        main_dump_file        = "tb_ubwc_enc_wrapper_top_tajmahal_rgba8888_fake_main_mem.txt";
                        main_dump_file_plane1 = "";
                        meta_dump_file        = "tb_ubwc_enc_wrapper_top_tajmahal_rgba8888_fake_meta_mem.txt";
                        meta_dump_file_plane1 = "";
                    end
                endcase
            end else begin
                case (CASE_ID)
                    CASE_RGBA1010102: begin
                        main_dump_file        = "tb_ubwc_enc_wrapper_top_tajmahal_rgba1010102_nonfake_main_mem.txt";
                        main_dump_file_plane1 = "";
                        meta_dump_file        = "tb_ubwc_enc_wrapper_top_tajmahal_rgba1010102_nonfake_meta_mem.txt";
                        meta_dump_file_plane1 = "";
                    end
                    CASE_G016: begin
                        main_dump_file        = "tb_ubwc_enc_wrapper_top_k_outdoor61_g016_nonfake_main_y_mem.txt";
                        main_dump_file_plane1 = "tb_ubwc_enc_wrapper_top_k_outdoor61_g016_nonfake_main_uv_mem.txt";
                        meta_dump_file        = "tb_ubwc_enc_wrapper_top_k_outdoor61_g016_nonfake_meta_y_mem.txt";
                        meta_dump_file_plane1 = "tb_ubwc_enc_wrapper_top_k_outdoor61_g016_nonfake_meta_uv_mem.txt";
                    end
                    CASE_NV12: begin
                        main_dump_file        = "tb_ubwc_enc_wrapper_top_tajmahal_nv12_nonfake_main_y_mem.txt";
                        main_dump_file_plane1 = "tb_ubwc_enc_wrapper_top_tajmahal_nv12_nonfake_main_uv_mem.txt";
                        meta_dump_file        = "tb_ubwc_enc_wrapper_top_tajmahal_nv12_nonfake_meta_y_mem.txt";
                        meta_dump_file_plane1 = "tb_ubwc_enc_wrapper_top_tajmahal_nv12_nonfake_meta_uv_mem.txt";
                    end
                    default: begin
                        main_dump_file        = "tb_ubwc_enc_wrapper_top_tajmahal_rgba8888_nonfake_main_mem.txt";
                        main_dump_file_plane1 = "";
                        meta_dump_file        = "tb_ubwc_enc_wrapper_top_tajmahal_rgba8888_nonfake_meta_mem.txt";
                        meta_dump_file_plane1 = "";
                    end
                endcase
            end

            main_dump_has_prev_addr = 1'b0;
            meta_dump_has_prev_addr = 1'b0;
            main_dump_next_addr     = {AXI_AW{1'b0}};
            meta_dump_next_addr     = {AXI_AW{1'b0}};
            main_dump_fd_plane1     = 0;
            meta_dump_fd_plane1     = 0;

            main_dump_fd = $fopen(main_dump_file, "w");
            if (main_dump_fd == 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] cannot open main memory dump file: %0s", main_dump_file);
            end else begin
                $display("[TB] main memory dump file : %0s", main_dump_file);
            end

            meta_dump_fd = $fopen(meta_dump_file, "w");
            if (meta_dump_fd == 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] cannot open meta memory dump file: %0s", meta_dump_file);
            end else begin
                $display("[TB] meta memory dump file : %0s", meta_dump_file);
            end

            if (CASE_HAS_PLANE1) begin
                main_dump_fd_plane1 = $fopen(main_dump_file_plane1, "w");
                if (main_dump_fd_plane1 == 0) begin
                    fail_count = fail_count + 1;
                    $display("[TB][ERROR] cannot open main memory dump file (plane1): %0s", main_dump_file_plane1);
                end else begin
                    $display("[TB] main memory dump file (plane1) : %0s", main_dump_file_plane1);
                end

                meta_dump_fd_plane1 = $fopen(meta_dump_file_plane1, "w");
                if (meta_dump_fd_plane1 == 0) begin
                    fail_count = fail_count + 1;
                    $display("[TB][ERROR] cannot open meta memory dump file (plane1): %0s", meta_dump_file_plane1);
                end else begin
                    $display("[TB] meta memory dump file (plane1) : %0s", meta_dump_file_plane1);
                end
            end
        end
    endtask

    task automatic close_mem_dump_files;
        begin
            if (main_dump_fd != 0) begin
                $fclose(main_dump_fd);
                main_dump_fd = 0;
            end
            if (main_dump_fd_plane1 != 0) begin
                $fclose(main_dump_fd_plane1);
                main_dump_fd_plane1 = 0;
            end
            if (meta_dump_fd != 0) begin
                $fclose(meta_dump_fd);
                meta_dump_fd = 0;
            end
            if (meta_dump_fd_plane1 != 0) begin
                $fclose(meta_dump_fd_plane1);
                meta_dump_fd_plane1 = 0;
            end
        end
    endtask

    task automatic dump_mem_to_files;
        begin
            main_dump_has_prev_addr = 1'b0;
            meta_dump_has_prev_addr = 1'b0;
            main_dump_next_addr     = {AXI_AW{1'b0}};
            meta_dump_next_addr     = {AXI_AW{1'b0}};

            if (main_dump_fd != 0) begin
                u_axi_mem.dump_range64(main_dump_fd,
                                       CASE_TILE_BASE_Y_ADDR,
                                       tb_fake_mode_en ? CASE_FAKE_CMP0_WORDS64 : CASE_CMP0_WORDS64,
                                       1'b0,
                                       main_dump_has_prev_addr,
                                       main_dump_next_addr);
            end
            if (CASE_HAS_PLANE1 && (main_dump_fd_plane1 != 0)) begin
                main_dump_has_prev_addr = 1'b0;
                main_dump_next_addr     = {AXI_AW{1'b0}};
                u_axi_mem.dump_range64(main_dump_fd_plane1,
                                       CASE_TILE_BASE_UV_ADDR,
                                       tb_fake_mode_en ? CASE_FAKE_CMP1_WORDS64 : CASE_CMP1_WORDS64,
                                       1'b0,
                                       main_dump_has_prev_addr,
                                       main_dump_next_addr);
            end

            if (meta_dump_fd != 0) begin
                u_axi_mem.dump_range64(meta_dump_fd,
                                       CASE_META_BASE_Y_ADDR,
                                       CASE_META0_WORDS64,
                                       1'b0,
                                       meta_dump_has_prev_addr,
                                       meta_dump_next_addr);
            end
            if (CASE_HAS_PLANE1 && (meta_dump_fd_plane1 != 0)) begin
                meta_dump_has_prev_addr = 1'b0;
                meta_dump_next_addr     = {AXI_AW{1'b0}};
                u_axi_mem.dump_range64(meta_dump_fd_plane1,
                                       CASE_META_BASE_UV_ADDR,
                                       CASE_META1_WORDS64,
                                       1'b0,
                                       meta_dump_has_prev_addr,
                                       meta_dump_next_addr);
            end
        end
    endtask

    task automatic pulse_start_otf;
        begin
            start_otf = 1'b1;
            @(posedge clk);
            start_otf = 1'b0;
        end
    endtask

    task automatic wait_frame_idle;
        input integer completed_frames_exp;
        integer settle_cycles;
        integer expected_tile_count_local;
        integer expected_beat_count_local;
        integer expected_meta_aw_local;
        integer expected_meta_w_local;
        begin
            settle_cycles = 0;
            expected_tile_count_local = CASE_EXPECTED_TILES * completed_frames_exp;
            expected_beat_count_local = CASE_EXPECTED_BEATS * completed_frames_exp;
            expected_meta_aw_local    = (tb_fake_mode_en ? CASE_FAKE_EXPECTED_META_AW : CASE_EXPECTED_META_AW) *
                                        completed_frames_exp;
            expected_meta_w_local     = (tb_fake_mode_en ? CASE_FAKE_EXPECTED_META_W : CASE_EXPECTED_META_W) *
                                        completed_frames_exp;

            while ((settle_cycles < 64) && (timeout_count < case_timeout_cycles)) begin
                @(posedge clk);
                if (tb_fake_mode_en) begin
                    if ((otf_done_count >= completed_frames_exp) &&
                        (coord_count >= expected_tile_count_local) &&
                        (aw_count >= expected_tile_count_local) &&
                        (w_count >= expected_beat_count_local) &&
                        (meta_aw_count >= expected_meta_aw_local) &&
                        (meta_w_count >= expected_meta_w_local) &&
                        !tb_output_activity) begin
                        settle_cycles = settle_cycles + 1;
                    end else begin
                        settle_cycles = 0;
                    end
                end else begin
                    if ((otf_done_count >= completed_frames_exp) &&
                        !tb_output_activity) begin
                        settle_cycles = settle_cycles + 1;
                    end else begin
                        settle_cycles = 0;
                    end
                end
            end

            if (settle_cycles < 64) begin
                $display("[TB][ERROR] wait_frame_idle timeout: frame=%0d started=%0d done=%0d coord=%0d aw=%0d w=%0d meta_aw=%0d meta_w=%0d otf_done_cnt=%0d",
                         completed_frames_exp, frames_started, frames_completed,
                         coord_count, aw_count, w_count, meta_aw_count, meta_w_count, otf_done_count);
                $display("[TB][ERROR] meta split: y_aw=%0d uv_aw=%0d y_w=%0d uv_w=%0d exp_y=%0d exp_uv=%0d",
                         meta_aw_count_plane0, meta_aw_count_plane1,
                         meta_w_count_plane0, meta_w_count_plane1,
                         expected_meta_aw_plane0_total, expected_meta_aw_plane1_total);
                $display("[TB][ERROR] meta gen split: y=%0d uv=%0d total=%0d",
                         meta_gen_fire_count_plane0, meta_gen_fire_count_plane1, meta_gen_fire_count);
                $display("[TB][ERROR] meta gen y detail: active=%0d pad=%0d",
                         meta_gen_y_active_count, meta_gen_y_pad_count);
                $display("[TB][ERROR] meta last aw: y=0x%08x uv=0x%08x",
                         last_meta_aw_addr_y, last_meta_aw_addr_uv);
                $display("[TB][ERROR] activity: tile_coord_vld=%0b rvi_valid=%0b enc_awvalid=%0b enc_wvalid=%0b meta_awvalid=%0b meta_wvalid=%0b active_cmd=%0b rvi_active_cmd=%0b main_burst=%0b meta_burst=%0b",
                         dut.tile_coord_vld, dut.rvi_valid, dut.enc_axi_awvalid, dut.enc_axi_wvalid,
                         dut.meta_axi_awvalid, dut.meta_axi_wvalid, active_cmd_valid, rvi_active_cmd_valid,
                         main_burst_active, meta_burst_active);
                $display("[TB][ERROR] meta gen state: out_valid=%0b out_ready=%0b frame_pad_active=%0b frame_pad_left=%0d row_extra=%0b frame_done_pending=%0b",
                         dut.ubwc_enc_meta_addr_gen_inst.o_meta_valid,
                         dut.ubwc_enc_meta_addr_gen_inst.i_meta_ready,
                         dut.ubwc_enc_meta_addr_gen_inst.frame_pad_active_r,
                         dut.ubwc_enc_meta_addr_gen_inst.frame_pad_words_left_r,
                         dut.ubwc_enc_meta_addr_gen_inst.row_extra_pending_r,
                         dut.ubwc_enc_meta_addr_gen_inst.frame_done_pending_r);
                $display("[TB][ERROR] meta in_fifo: pop_valid=%0b push_ready=%0b drop_cnt=%0d",
                         dut.ubwc_enc_meta_addr_gen_inst.in_fifo_pop_valid,
                         dut.ubwc_enc_meta_addr_gen_inst.in_fifo_push_ready,
                         meta_in_fifo_drop_count);
                if (first_meta_in_fifo_drop_seen) begin
                    $display("[TB][ERROR] first meta in_fifo drop: fmt=%0d x=%0d y=%0d",
                             first_meta_in_fifo_drop_fmt,
                             first_meta_in_fifo_drop_x,
                             first_meta_in_fifo_drop_y);
                end
                $display("[TB][ERROR] meta gen last tile: fmt=%0d x=%0d y=%0d last_of_plane=%0b miss_rows=%0d pad_words=%0d",
                         dut.ubwc_enc_meta_addr_gen_inst.int_format,
                         dut.ubwc_enc_meta_addr_gen_inst.int_xcoord,
                         dut.ubwc_enc_meta_addr_gen_inst.int_ycoord,
                         dut.ubwc_enc_meta_addr_gen_inst.tile_last_of_plane_w,
                         dut.ubwc_enc_meta_addr_gen_inst.tile_missing_rows_w,
                         dut.ubwc_enc_meta_addr_gen_inst.tile_frame_pad_words_w);
                $fatal(1, "Encoder wrapper did not become idle before next frame start.");
            end

            repeat (16) @(posedge clk);
        end
    endtask

    task automatic apb_write;
        input [APB_AW-1:0] addr;
        input [APB_DW-1:0] data;
        begin
            @(posedge clk);
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b1;
            PADDR   <= addr;
            PWDATA  <= data;
            @(posedge clk);
            PENABLE <= 1'b1;
            @(posedge clk);
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
            PADDR   <= {APB_AW{1'b0}};
            PWDATA  <= {APB_DW{1'b0}};
        end
    endtask

    task automatic program_wrapper_regs;
        reg [31:0] reg2_data;
        reg [31:0] reg3_data;
        reg [31:0] reg4_data;
        reg [31:0] reg8_data;
        reg [31:0] reg9_data;
        reg [31:0] reg10_data;
        reg [31:0] reg11_data;
        reg [31:0] reg20_data;
        begin
            reg2_data = 32'd0;
            reg2_data[0]     = 1'b1;
            reg2_data[1]     = 1'b0;
            reg2_data[2]     = 1'b1;
            reg2_data[3]     = 1'b1;
            reg2_data[12:8]  = 5'd16;
            reg2_data[16]    = 1'b1;

            reg3_data = 32'd0;
            reg3_data[0]      = CASE_IS_G016 ? 1'b1 :
                                (CASE_HAS_PLANE1 ? 1'b0 : 1'b1);
            reg3_data[1]      = 1'b0;
            reg3_data[26:16]  = CASE_PITCH_UNITS[10:0];

            reg4_data = 32'd0;
            reg4_data[0]      = 1'b1;
            reg4_data[10:8]   = 3'd7;
            reg4_data[20:16]  = CASE_CI_FMT[4:0];
            reg4_data[24]     = 1'b0;

            reg8_data = 32'd0;
            reg8_data[2:0]    = CASE_OTF_FMT[2:0];

            reg9_data  = {CASE_STORED_H[15:0], IMG_W[15:0]};
            reg10_data = {CASE_TILE_H[15:0], CASE_TILE_W[15:0]};
            reg11_data = {CASE_B_TILE_COLS[15:0], CASE_A_TILE_COLS[15:0]};
            reg20_data = CASE_HAS_PLANE1 ? {(CASE_IS_G016 ? G016_ACTIVE_H[15:0] : NV12_ACTIVE_H[15:0]), IMG_W[15:0]}
                                         : {RGBA_ACTIVE_H[15:0], IMG_W[15:0]};

            apb_write(16'h000c, reg3_data);
            apb_write(16'h0008, reg2_data);
            apb_write(16'h0030, CASE_TILE_BASE_Y_ADDR[31:0]);
            apb_write(16'h0034, CASE_TILE_BASE_Y_ADDR[63:32]);
            apb_write(16'h0038, CASE_TILE_BASE_UV_ADDR[31:0]);
            apb_write(16'h003c, CASE_TILE_BASE_UV_ADDR[63:32]);
            apb_write(16'h0040, CASE_META_BASE_Y_ADDR[31:0]);
            apb_write(16'h0044, CASE_META_BASE_Y_ADDR[63:32]);
            apb_write(16'h0048, CASE_META_BASE_UV_ADDR[31:0]);
            apb_write(16'h004c, CASE_META_BASE_UV_ADDR[63:32]);
            apb_write(16'h0014, 32'd0);
            apb_write(16'h0018, 32'd0);
            apb_write(16'h001c, 32'd0);
            apb_write(16'h0010, reg4_data);
            apb_write(16'h0024, reg9_data);
            apb_write(16'h0028, reg10_data);
            apb_write(16'h002c, reg11_data);
            apb_write(16'h0050, reg20_data);
            apb_write(16'h0020, reg8_data);
        end
    endtask

    ubwc_enc_wrapper_top #(
        .SB_WIDTH    (SB_WIDTH),
        .APB_AW      (APB_AW),
        .APB_DW      (APB_DW),
        .AXI_AW      (AXI_AW),
        .AXI_DW      (AXI_DW),
        .AXI_LENW    (AXI_LENW),
        .AXI_IDW     (AXI_IDW),
        .COM_BUF_AW  (COM_BUF_AW),
        .COM_BUF_DW  (COM_BUF_DW)
    ) dut (
        .PCLK            (clk),
        .PRESETn         (rst_n),
        .PSEL            (PSEL),
        .PENABLE         (PENABLE),
        .PADDR           (PADDR),
        .PWRITE          (PWRITE),
        .PWDATA          (PWDATA),
        .PREADY          (PREADY),
        .PSLVERR         (PSLVERR),
        .PRDATA          (PRDATA),
        .i_clk           (clk),
        .i_rstn          (rst_n),
        .i_otf_vsync     (i_otf_vsync),
        .i_otf_hsync     (i_otf_hsync),
        .i_otf_de        (i_otf_de),
        .i_otf_data      (i_otf_data),
        .i_otf_fcnt      (i_otf_fcnt),
        .i_otf_lcnt      (i_otf_lcnt),
        .o_otf_ready     (o_otf_ready),
        .o_bank0_en      (o_bank0_en),
        .o_bank0_wen     (o_bank0_wen),
        .o_bank0_addr    (o_bank0_addr),
        .o_bank0_din     (o_bank0_din),
        .i_bank0_dout    (i_bank0_dout),
        .i_bank0_dout_vld(i_bank0_dout_vld),
        .o_bank1_en      (o_bank1_en),
        .o_bank1_wen     (o_bank1_wen),
        .o_bank1_addr    (o_bank1_addr),
        .o_bank1_din     (o_bank1_din),
        .i_bank1_dout    (i_bank1_dout),
        .i_bank1_dout_vld(i_bank1_dout_vld),
        .o_m_axi_awid    (o_m_axi_awid),
        .o_m_axi_awaddr  (o_m_axi_awaddr),
        .o_m_axi_awlen   (o_m_axi_awlen),
        .o_m_axi_awsize  (o_m_axi_awsize),
        .o_m_axi_awburst (o_m_axi_awburst),
        .o_m_axi_awlock  (o_m_axi_awlock),
        .o_m_axi_awcache (o_m_axi_awcache),
        .o_m_axi_awprot  (o_m_axi_awprot),
        .o_m_axi_awvalid (o_m_axi_awvalid),
        .i_m_axi_awready (i_m_axi_awready),
        .o_m_axi_wdata   (o_m_axi_wdata),
        .o_m_axi_wstrb   (o_m_axi_wstrb),
        .o_m_axi_wvalid  (o_m_axi_wvalid),
        .o_m_axi_wlast   (o_m_axi_wlast),
        .i_m_axi_wready  (i_m_axi_wready),
        .i_m_axi_bid     (i_m_axi_bid),
        .i_m_axi_bresp   (i_m_axi_bresp),
        .i_m_axi_bvalid  (i_m_axi_bvalid),
        .o_m_axi_bready  (o_m_axi_bready)
    );

    tb_enc_sync_sram_1rw #(
        .ADDR_W (COM_BUF_AW),
        .DATA_W (COM_BUF_DW)
    ) u_bank0 (
        .clk      (clk),
        .en       (o_bank0_en),
        .wen      (o_bank0_wen),
        .addr     (o_bank0_addr),
        .din      (o_bank0_din),
        .dout     (i_bank0_dout),
        .dout_vld (i_bank0_dout_vld)
    );

    tb_enc_sync_sram_1rw #(
        .ADDR_W (COM_BUF_AW),
        .DATA_W (COM_BUF_DW)
    ) u_bank1 (
        .clk      (clk),
        .en       (o_bank1_en),
        .wen      (o_bank1_wen),
        .addr     (o_bank1_addr),
        .din      (o_bank1_din),
        .dout     (i_bank1_dout),
        .dout_vld (i_bank1_dout_vld)
    );

    enc_otf_driver #(
        .INPUT_FILE ("input_otf_stream.txt")
    ) u_otf_driver (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start_otf),
        .done       (otf_done),
        .error_flag (otf_error),
        .img_width  (IMG_W[15:0]),
        .img_height (CASE_STORED_H[15:0]),
        .otf_vsync  (i_otf_vsync),
        .otf_hsync  (i_otf_hsync),
        .otf_de     (i_otf_de),
        .otf_data   (i_otf_data),
        .otf_fcnt   (i_otf_fcnt),
        .otf_lcnt   (i_otf_lcnt),
        .otf_ready  (o_otf_ready)
    );

    tb_enc_axi_write_sink #(
        .AXI_ID_WIDTH   (AXI_IDW + 1),
        .AXI_ADDR_WIDTH (AXI_AW),
        .AXI_DATA_WIDTH (AXI_DW),
        .MEM_BASE_ADDR  (CASE_META_BASE_MIN),
        .MEM_WORDS64    (CASE_OUTPUT_MEM_WORDS64)
    ) u_axi_mem (
        .aclk      (clk),
        .aresetn   (rst_n),
        .awid      (o_m_axi_awid),
        .awaddr    (o_m_axi_awaddr),
        .awlen     (o_m_axi_awlen),
        .awsize    (o_m_axi_awsize),
        .awburst   (o_m_axi_awburst),
        .awvalid   (o_m_axi_awvalid),
        .awready   (i_m_axi_awready),
        .wdata     (o_m_axi_wdata),
        .wstrb     (o_m_axi_wstrb),
        .wlast     (o_m_axi_wlast),
        .wvalid    (o_m_axi_wvalid),
        .wready    (i_m_axi_wready),
        .bid       (i_m_axi_bid),
        .bresp     (i_m_axi_bresp),
        .bvalid    (i_m_axi_bvalid),
        .bready    (o_m_axi_bready)
    );

    assign dbg_otf_to_tile_ci_valid  = dut.enc_ci_valid;
    assign dbg_otf_to_tile_ci_ready  = dut.enc_ci_ready;
    assign dbg_otf_to_tile_last      = dut.rvi_last;
    assign dbg_otf_to_tile_coord_vld = dut.tile_coord_vld;
    assign dbg_otf_to_tile_x         = dut.tile_xcoord_raw;
    assign dbg_otf_to_tile_y         = dut.tile_ycoord_raw;
    assign dbg_otf_to_tile_fcnt      = dut.tile_fcnt;
    assign dbg_otf_to_tile_format    = dut.enc_ci_format;
    assign meta_aw_fire_w            = dut.meta_axi_awvalid && dut.meta_axi_awready;
    assign meta_w_fire_w             = dut.meta_axi_wvalid && dut.meta_axi_wready;
    assign meta_use_curr_aw_w        = meta_aw_fire_w && !meta_burst_active;
    assign meta_write_beat_addr_w    = meta_use_curr_aw_w ? dut.meta_axi_awaddr : meta_burst_addr;
    assign meta_write_underflow_w    = meta_w_fire_w && !meta_burst_active && !meta_use_curr_aw_w;
    assign rvi_start_direct_w        = dut.ubwc_enc_otf_to_tile_inst.ci_fifo_wr_en &&
                                       dut.rvi_valid && dut.rvi_ready &&
                                       !rvi_active_cmd_valid &&
                                       (rvi_cmd_rd_ptr >= rvi_cmd_wr_ptr);
    assign cvo_start_direct_w        = tb_fake_mode_en ?
                                       (dut.ubwc_enc_otf_to_tile_inst.ci_fifo_wr_en &&
                                        dut.enc_cvo_valid && dut.enc_cvo_ready &&
                                        !cvo_active_cmd_valid &&
                                        (cvo_cmd_rd_ptr >= cvo_cmd_wr_ptr)) :
                                       (dut.enc_axi_awvalid && dut.enc_axi_awready &&
                                        dut.enc_cvo_valid && dut.enc_cvo_ready &&
                                        !cvo_active_cmd_valid &&
                                        (cvo_cmd_rd_ptr >= cvo_cmd_wr_ptr));
    assign tb_output_activity        = dut.tile_coord_vld || dut.rvi_valid ||
                                       dut.enc_axi_awvalid || dut.enc_axi_wvalid ||
                                       dut.meta_axi_awvalid || dut.meta_axi_wvalid ||
                                       active_cmd_valid || rvi_active_cmd_valid ||
                                       main_burst_active || meta_burst_active;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        integer frame_idx;
        $display("[TB] encoder wrapper bench start, CASE_ID=%0d", CASE_ID);
        PSEL     = 1'b0;
        PENABLE  = 1'b0;
        PADDR    = {APB_AW{1'b0}};
        PWRITE   = 1'b0;
        PWDATA   = {APB_DW{1'b0}};
        start_otf = 1'b0;
        rst_n = 1'b0;
        cmd_wr_ptr = 0;
        cmd_rd_ptr = 0;
        rvi_cmd_wr_ptr = 0;
        cvo_cmd_wr_ptr = 0;
        cvo_cmd_rd_ptr = 0;
        active_cmd_valid = 1'b0;
        active_cmd_fmt = 5'd0;
        active_cmd_x = 16'd0;
        active_cmd_y = 16'd0;
        active_cmd_beat_idx = 0;
        coord_count = 0;
        aw_count = 0;
        w_count = 0;
        meta_aw_count = 0;
        meta_aw_count_plane0 = 0;
        meta_aw_count_plane1 = 0;
        aw_mismatch_count = 0;
        data_mismatch_count = 0;
        strb_mismatch_count = 0;
        wlast_mismatch_count = 0;
        queue_underflow_count = 0;
        out_aw_count = 0;
        out_w_count = 0;
        main_mem_mismatch_count = 0;
        meta_mem_mismatch_count = 0;
        main_plane0_mem_mismatch_count = 0;
        main_plane1_mem_mismatch_count = 0;
        meta_plane0_mem_mismatch_count = 0;
        meta_plane1_mem_mismatch_count = 0;
        out_range_mismatch_count = 0;
        out_wlast_mismatch_count = 0;
        meta_w_count = 0;
        meta_w_count_plane0 = 0;
        meta_w_count_plane1 = 0;
        meta_dump_mismatch_count = 0;
        meta_dump_mismatch_plane0_count = 0;
        meta_dump_mismatch_plane1_count = 0;
        meta_dump_word_count_error_count = 0;
        meta_in_fifo_drop_count = 0;
        meta_gen_fire_count = 0;
        meta_gen_fire_count_plane0 = 0;
        meta_gen_fire_count_plane1 = 0;
        meta_gen_y_active_count = 0;
        meta_gen_y_pad_count = 0;
        first_out_range_seen = 1'b0;
        first_out_range_kind = 3'd0;
        first_out_range_addr = {AXI_AW{1'b0}};
        first_out_range_beat_idx = {(AXI_LENW+1){1'b0}};
        first_out_range_beats_total = {(AXI_LENW+1){1'b0}};
        first_meta_aw_seen = 1'b0;
        first_meta_aw_addr = {AXI_AW{1'b0}};
        last_meta_aw_addr_y = {AXI_AW{1'b0}};
        last_meta_aw_addr_uv = {AXI_AW{1'b0}};
        first_meta_aw_y_base = {AXI_AW{1'b0}};
        first_meta_aw_uv_base = {AXI_AW{1'b0}};
        first_meta_aw_y_meta_addr = {AXI_AW{1'b0}};
        first_meta_aw_uv_meta_addr = {AXI_AW{1'b0}};
        first_meta_aw_sel_uv = 1'b0;
        fail_count = 0;
        timeout_count = 0;
        idle_cycles_after_done = 0;
        case_timeout_cycles = CASE_TIMEOUT_CYCLES;
        tb_frame_repeat = 1;
        frames_started = 0;
        frames_completed = 0;
        expected_tiles_total = CASE_EXPECTED_TILES;
        expected_beats_total = CASE_EXPECTED_BEATS;
        expected_meta_aw_total = CASE_FAKE_EXPECTED_META_AW;
        expected_meta_w_total = CASE_FAKE_EXPECTED_META_W;
        expected_meta_aw_plane0_total = CASE_FAKE_EXPECTED_META0_AW;
        expected_meta_aw_plane1_total = CASE_FAKE_EXPECTED_META1_AW;
        expected_meta_w_plane0_total = CASE_FAKE_EXPECTED_META0_W;
        expected_meta_w_plane1_total = CASE_FAKE_EXPECTED_META1_W;
        otf_done_count = 0;
        void'($value$plusargs("tb_timeout_cycles=%d", case_timeout_cycles));
        if (!$value$plusargs("tb_frame_repeat=%d", tb_frame_repeat))
            tb_frame_repeat = 1;
        if (tb_frame_repeat < 1)
            tb_frame_repeat = 1;
        if (tb_frame_repeat > MAX_FRAME_REPEAT)
            $fatal(1, "tb_frame_repeat=%0d exceeds MAX_FRAME_REPEAT=%0d", tb_frame_repeat, MAX_FRAME_REPEAT);
        expected_tiles_total = CASE_EXPECTED_TILES * tb_frame_repeat;
        expected_beats_total = CASE_EXPECTED_BEATS * tb_frame_repeat;
        expected_meta_aw_total = CASE_FAKE_EXPECTED_META_AW * tb_frame_repeat;
        expected_meta_w_total = CASE_FAKE_EXPECTED_META_W * tb_frame_repeat;
        expected_meta_aw_plane0_total = CASE_FAKE_EXPECTED_META0_AW * tb_frame_repeat;
        expected_meta_aw_plane1_total = CASE_FAKE_EXPECTED_META1_AW * tb_frame_repeat;
        expected_meta_w_plane0_total = CASE_FAKE_EXPECTED_META0_W * tb_frame_repeat;
        expected_meta_w_plane1_total = CASE_FAKE_EXPECTED_META1_W * tb_frame_repeat;
        rvi_beat_count = 0;
        rvi_beat_idx = 0;
        rvi_cmd_rd_ptr = 0;
        cvo_beat_count = 0;
        rvi_data_mismatch_count = 0;
        cvo_data_mismatch_count = 0;
        rvi_active_cmd_valid = 1'b0;
        rvi_active_cmd_fmt = 5'd0;
        rvi_active_cmd_x = 16'd0;
        rvi_active_cmd_y = 16'd0;
        cvo_active_cmd_valid = 1'b0;
        cvo_active_cmd_fmt = 5'd0;
        cvo_active_cmd_x = 16'd0;
        cvo_active_cmd_y = 16'd0;
        cvo_active_cmd_addr = {AXI_AW{1'b0}};
        cvo_active_cmd_beats = 4'd0;
        cvo_beat_idx = 0;
        first_rvi_data_mismatch_seen = 1'b0;
        first_rvi_data_fmt = 5'd0;
        first_rvi_data_x = 16'd0;
        first_rvi_data_y = 16'd0;
        first_rvi_data_beat = 0;
        first_rvi_data_expected = {AXI_DW{1'b0}};
        first_rvi_data_actual = {AXI_DW{1'b0}};
        first_cvo_data_mismatch_seen = 1'b0;
        first_cvo_data_fmt = 5'd0;
        first_cvo_data_x = 16'd0;
        first_cvo_data_y = 16'd0;
        first_cvo_data_beat = 0;
        first_cvo_data_expected = {AXI_DW{1'b0}};
        first_cvo_data_actual = {AXI_DW{1'b0}};
        first_aw_mismatch_seen = 1'b0;
        first_aw_actual = {AXI_AW{1'b0}};
        first_aw_expected = {AXI_AW{1'b0}};
        first_aw_fmt = 5'd0;
        first_aw_x = 16'd0;
        first_aw_y = 16'd0;
        first_data_mismatch_seen = 1'b0;
        first_data_fmt = 5'd0;
        first_data_x = 16'd0;
        first_data_y = 16'd0;
        first_data_beat = 0;
        first_data_expected = {AXI_DW{1'b0}};
        first_data_actual = {AXI_DW{1'b0}};
        dbg_line_tile_en = 1'b0;
        tb_fake_mode_en = 1'b1;
        out_burst_active = 1'b0;
        out_burst_is_meta = 1'b0;
        out_burst_addr = {AXI_AW{1'b0}};
        out_burst_beats_total = {(AXI_LENW+1){1'b0}};
        out_burst_beat_idx = {(AXI_LENW+1){1'b0}};
        main_burst_active = 1'b0;
        main_burst_addr = {AXI_AW{1'b0}};
        main_burst_beats_total = {(AXI_LENW+1){1'b0}};
        main_burst_beat_idx = {(AXI_LENW+1){1'b0}};
        meta_burst_active = 1'b0;
        meta_burst_addr = {AXI_AW{1'b0}};
        meta_burst_beats_total = {(AXI_LENW+1){1'b0}};
        meta_burst_beat_idx = {(AXI_LENW+1){1'b0}};
        main_dump_fd = 0;
        main_dump_fd_plane1 = 0;
        meta_dump_fd = 0;
        meta_dump_fd_plane1 = 0;
        main_dump_file = "";
        main_dump_file_plane1 = "";
        meta_dump_file = "";
        meta_dump_file_plane1 = "";
        main_dump_has_prev_addr = 1'b0;
        meta_dump_has_prev_addr = 1'b0;
        main_dump_next_addr = {AXI_AW{1'b0}};
        meta_dump_next_addr = {AXI_AW{1'b0}};
        first_main_mem_mismatch_seen = 1'b0;
        first_meta_mem_mismatch_seen = 1'b0;
        first_meta_dump_mismatch_seen = 1'b0;
        first_main_mem_addr = {AXI_AW{1'b0}};
        first_meta_mem_addr = {AXI_AW{1'b0}};
        first_meta_dump_addr = {AXI_AW{1'b0}};
        first_main_mem_expected = {AXI_DW{1'b0}};
        first_main_mem_actual = {AXI_DW{1'b0}};
        first_meta_mem_expected = {AXI_DW{1'b0}};
        first_meta_mem_actual = {AXI_DW{1'b0}};
        first_meta_dump_expected = 64'd0;
        first_meta_dump_actual = 64'd0;
        first_meta_in_fifo_drop_seen = 1'b0;
        first_meta_in_fifo_drop_fmt = 5'd0;
        first_meta_in_fifo_drop_x = 28'd0;
        first_meta_in_fifo_drop_y = 13'd0;
        first_main_mem_strb = {(AXI_DW/8){1'b0}};
        first_meta_mem_strb = {(AXI_DW/8){1'b0}};
        ref_cmp_mismatch = 1'b0;
        ref_cmp_range_error = 1'b0;
        ref_cmp_expected_word = {AXI_DW{1'b0}};
        if ($test$plusargs("dbg_line_tile"))
            dbg_line_tile_en = 1'b1;
        if ($test$plusargs("tb_non_fake_mode"))
            tb_fake_mode_en = 1'b0;
        if (!tb_fake_mode_en) begin
            expected_meta_aw_total = CASE_EXPECTED_META_AW * tb_frame_repeat;
            expected_meta_w_total = CASE_EXPECTED_META_W * tb_frame_repeat;
            expected_meta_aw_plane0_total = CASE_EXPECTED_META0_AW * tb_frame_repeat;
            expected_meta_aw_plane1_total = CASE_EXPECTED_META1_AW * tb_frame_repeat;
            expected_meta_w_plane0_total = CASE_EXPECTED_META0_W * tb_frame_repeat;
            expected_meta_w_plane1_total = CASE_EXPECTED_META1_W * tb_frame_repeat;
        end
        open_mem_dump_files();

        init_ref_word_arrays();
        case (CASE_ID)
            CASE_RGBA8888: begin
                load_dump64_to_tile_plane("../../enc_from_mdss_zp_TajMahal_4096x600_rgba8888/visual_from_mdss_writeback_4_wb_2_rec_0_verify_ubwc_enc_in0.txt",
                                          0, CASE_TILE_BASE_Y_ADDR, CASE_TILE0_WORDS64);
            end
            CASE_RGBA1010102: begin
                load_dump64_to_tile_plane("../../enc_from_mdss_zp_TajMahal_4096x600_rgba1010102/visual_from_mdss_writeback_38_wb_2_rec_0_verify_ubwc_enc_in0.txt",
                                          0, CASE_TILE_BASE_Y_ADDR, CASE_TILE0_WORDS64);
            end
            CASE_G016: begin
                load_dump64_to_tile_plane("../../enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_in0.txt",
                                          0, CASE_TILE_BASE_Y_ADDR, CASE_TILE0_WORDS64);
                load_dump64_to_tile_plane("../../enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_in1.txt",
                                          1, CASE_TILE_BASE_UV_ADDR, CASE_TILE1_WORDS64);
            end
            default: begin
                load_dump64_to_tile_plane("../../enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in0.txt",
                                          0, CASE_TILE_BASE_Y_ADDR, CASE_TILE0_WORDS64);
                load_dump64_to_tile_plane("../../enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_in1.txt",
                                          1, CASE_TILE_BASE_UV_ADDR, CASE_TILE1_WORDS64);
            end
        endcase
        case (CASE_ID)
            CASE_RGBA8888: begin
                load_dump64_to_ref("../../enc_from_mdss_zp_TajMahal_4096x600_rgba8888/visual_from_mdss_writeback_4_wb_2_rec_0_verify_ubwc_enc_out2.txt",
                                   1, CASE_META_BASE_Y_ADDR, CASE_META0_WORDS64);
            end
            CASE_RGBA1010102: begin
                load_dump64_to_ref("../../enc_from_mdss_zp_TajMahal_4096x600_rgba1010102/visual_from_mdss_writeback_38_wb_2_rec_0_verify_ubwc_enc_out2.txt",
                                   1, CASE_META_BASE_Y_ADDR, CASE_META0_WORDS64);
            end
            CASE_G016: begin
                load_dump64_to_ref("../../enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out2.txt",
                                   1, CASE_META_BASE_Y_ADDR, CASE_META0_WORDS64);
                load_dump64_to_ref("../../enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out3.txt",
                                   1, CASE_META_BASE_UV_ADDR, CASE_META1_WORDS64);
            end
            default: begin
                load_dump64_to_ref("../../enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out2.txt",
                                   1, CASE_META_BASE_Y_ADDR, CASE_META0_WORDS64);
                load_dump64_to_ref("../../enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out3.txt",
                                   1, CASE_META_BASE_UV_ADDR, CASE_META1_WORDS64);
            end
        endcase

        if (!tb_fake_mode_en) begin
            case (CASE_ID)
                CASE_RGBA8888: begin
                    load_dump64_to_ref("../../enc_from_mdss_zp_TajMahal_4096x600_rgba8888/visual_from_mdss_writeback_4_wb_2_rec_0_verify_ubwc_enc_out0.txt",
                                       0, CASE_TILE_BASE_Y_ADDR, CASE_CMP0_WORDS64);
                end
                CASE_RGBA1010102: begin
                    load_dump64_to_ref("../../enc_from_mdss_zp_TajMahal_4096x600_rgba1010102/visual_from_mdss_writeback_38_wb_2_rec_0_verify_ubwc_enc_out0.txt",
                                       0, CASE_TILE_BASE_Y_ADDR, CASE_CMP0_WORDS64);
                end
                CASE_G016: begin
                    load_dump64_to_ref("../../enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out0.txt",
                                       0, CASE_TILE_BASE_Y_ADDR, CASE_CMP0_WORDS64);
                    load_dump64_to_ref("../../enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out1.txt",
                                       0, CASE_TILE_BASE_UV_ADDR, CASE_CMP1_WORDS64);
                end
                default: begin
                    load_dump64_to_ref("../../enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out0.txt",
                                       0, CASE_TILE_BASE_Y_ADDR, CASE_CMP0_WORDS64);
                    load_dump64_to_ref("../../enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out1.txt",
                                       0, CASE_TILE_BASE_UV_ADDR, CASE_CMP1_WORDS64);
                end
            endcase
        end

        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) @(posedge clk);
        program_wrapper_regs();
        repeat (4) @(posedge clk);
        frames_started = 1;
        pulse_start_otf();
        for (frame_idx = 1; frame_idx < tb_frame_repeat; frame_idx = frame_idx + 1) begin
            wait_frame_idle(frame_idx);
            frames_completed = frame_idx;
            $display("[TB] frame %0d / %0d complete, scheduling next frame.", frame_idx, tb_frame_repeat);
            repeat (8) @(posedge clk);
            frames_started = frame_idx + 1;
            pulse_start_otf();
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            cmd_wr_ptr            <= 0;
            cmd_rd_ptr            <= 0;
            rvi_cmd_wr_ptr        <= 0;
            cvo_cmd_wr_ptr        <= 0;
            cvo_cmd_rd_ptr        <= 0;
            active_cmd_valid      <= 1'b0;
            active_cmd_fmt        <= 5'd0;
            active_cmd_x          <= 16'd0;
            active_cmd_y          <= 16'd0;
            active_cmd_beat_idx   <= 0;
            coord_count           <= 0;
            aw_count              <= 0;
            w_count               <= 0;
            meta_aw_count         <= 0;
            meta_aw_count_plane0  <= 0;
            meta_aw_count_plane1  <= 0;
            aw_mismatch_count     <= 0;
            data_mismatch_count   <= 0;
            strb_mismatch_count   <= 0;
            wlast_mismatch_count  <= 0;
            queue_underflow_count <= 0;
            out_aw_count          <= 0;
            out_w_count           <= 0;
            main_mem_mismatch_count <= 0;
            meta_mem_mismatch_count <= 0;
            main_plane0_mem_mismatch_count <= 0;
            main_plane1_mem_mismatch_count <= 0;
            meta_plane0_mem_mismatch_count <= 0;
            meta_plane1_mem_mismatch_count <= 0;
            out_range_mismatch_count <= 0;
            out_wlast_mismatch_count <= 0;
            meta_w_count          <= 0;
            meta_w_count_plane0   <= 0;
            meta_w_count_plane1   <= 0;
            meta_dump_mismatch_count <= 0;
            meta_dump_mismatch_plane0_count <= 0;
            meta_dump_mismatch_plane1_count <= 0;
            meta_dump_word_count_error_count <= 0;
            meta_in_fifo_drop_count <= 0;
            meta_gen_fire_count <= 0;
            meta_gen_fire_count_plane0 <= 0;
            meta_gen_fire_count_plane1 <= 0;
            meta_gen_y_active_count <= 0;
            meta_gen_y_pad_count <= 0;
            first_out_range_seen  <= 1'b0;
            first_out_range_kind  <= 3'd0;
            first_out_range_addr  <= {AXI_AW{1'b0}};
            first_out_range_beat_idx <= {(AXI_LENW+1){1'b0}};
            first_out_range_beats_total <= {(AXI_LENW+1){1'b0}};
            first_meta_aw_seen    <= 1'b0;
            first_meta_aw_addr    <= {AXI_AW{1'b0}};
            last_meta_aw_addr_y   <= {AXI_AW{1'b0}};
            last_meta_aw_addr_uv  <= {AXI_AW{1'b0}};
            first_meta_aw_y_base  <= {AXI_AW{1'b0}};
            first_meta_aw_uv_base <= {AXI_AW{1'b0}};
            first_meta_aw_y_meta_addr <= {AXI_AW{1'b0}};
            first_meta_aw_uv_meta_addr <= {AXI_AW{1'b0}};
            first_meta_aw_sel_uv  <= 1'b0;
            timeout_count         <= 0;
            idle_cycles_after_done<= 0;
            frames_completed      <= 0;
            otf_done_count        <= 0;
            rvi_beat_count        <= 0;
            rvi_beat_idx          <= 0;
            rvi_cmd_rd_ptr        <= 0;
            cvo_beat_count        <= 0;
            rvi_data_mismatch_count <= 0;
            cvo_data_mismatch_count <= 0;
            rvi_active_cmd_valid  <= 1'b0;
            rvi_active_cmd_fmt    <= 5'd0;
            rvi_active_cmd_x      <= 16'd0;
            rvi_active_cmd_y      <= 16'd0;
            cvo_active_cmd_valid  <= 1'b0;
            cvo_active_cmd_fmt    <= 5'd0;
            cvo_active_cmd_x      <= 16'd0;
            cvo_active_cmd_y      <= 16'd0;
            cvo_active_cmd_addr   <= {AXI_AW{1'b0}};
            cvo_active_cmd_beats  <= 4'd0;
            cvo_beat_idx          <= 0;
            first_rvi_data_mismatch_seen <= 1'b0;
            first_rvi_data_fmt    <= 5'd0;
            first_rvi_data_x      <= 16'd0;
            first_rvi_data_y      <= 16'd0;
            first_rvi_data_beat   <= 0;
            first_rvi_data_expected <= {AXI_DW{1'b0}};
            first_rvi_data_actual   <= {AXI_DW{1'b0}};
            first_cvo_data_mismatch_seen <= 1'b0;
            first_cvo_data_fmt     <= 5'd0;
            first_cvo_data_x       <= 16'd0;
            first_cvo_data_y       <= 16'd0;
            first_cvo_data_beat    <= 0;
            first_cvo_data_expected<= {AXI_DW{1'b0}};
            first_cvo_data_actual  <= {AXI_DW{1'b0}};
            first_aw_mismatch_seen<= 1'b0;
            first_aw_actual       <= {AXI_AW{1'b0}};
            first_aw_expected     <= {AXI_AW{1'b0}};
            first_aw_fmt          <= 5'd0;
            first_aw_x            <= 16'd0;
            first_aw_y            <= 16'd0;
            first_data_mismatch_seen <= 1'b0;
            first_data_fmt           <= 5'd0;
            first_data_x             <= 16'd0;
            first_data_y             <= 16'd0;
            first_data_beat          <= 0;
            first_data_expected      <= {AXI_DW{1'b0}};
            first_data_actual        <= {AXI_DW{1'b0}};
            out_burst_active         <= 1'b0;
            out_burst_is_meta        <= 1'b0;
            out_burst_addr           <= {AXI_AW{1'b0}};
            out_burst_beats_total    <= {(AXI_LENW+1){1'b0}};
            out_burst_beat_idx       <= {(AXI_LENW+1){1'b0}};
            main_dump_has_prev_addr  <= 1'b0;
            meta_dump_has_prev_addr  <= 1'b0;
            main_dump_next_addr      <= {AXI_AW{1'b0}};
            meta_dump_next_addr      <= {AXI_AW{1'b0}};
            main_burst_active        <= 1'b0;
            main_burst_addr          <= {AXI_AW{1'b0}};
            main_burst_beats_total   <= {(AXI_LENW+1){1'b0}};
            main_burst_beat_idx      <= {(AXI_LENW+1){1'b0}};
            meta_burst_active        <= 1'b0;
            meta_burst_addr          <= {AXI_AW{1'b0}};
            meta_burst_beats_total   <= {(AXI_LENW+1){1'b0}};
            meta_burst_beat_idx      <= {(AXI_LENW+1){1'b0}};
            first_main_mem_mismatch_seen <= 1'b0;
            first_meta_mem_mismatch_seen <= 1'b0;
            first_meta_dump_mismatch_seen <= 1'b0;
            first_main_mem_addr      <= {AXI_AW{1'b0}};
            first_meta_mem_addr      <= {AXI_AW{1'b0}};
            first_meta_dump_addr     <= {AXI_AW{1'b0}};
            first_main_mem_expected  <= {AXI_DW{1'b0}};
            first_main_mem_actual    <= {AXI_DW{1'b0}};
            first_meta_mem_expected  <= {AXI_DW{1'b0}};
            first_meta_mem_actual    <= {AXI_DW{1'b0}};
            first_meta_dump_expected <= 64'd0;
            first_meta_dump_actual   <= 64'd0;
            first_meta_in_fifo_drop_seen <= 1'b0;
            first_meta_in_fifo_drop_fmt  <= 5'd0;
            first_meta_in_fifo_drop_x    <= 28'd0;
            first_meta_in_fifo_drop_y    <= 13'd0;
            first_main_mem_strb      <= {(AXI_DW/8){1'b0}};
            first_meta_mem_strb      <= {(AXI_DW/8){1'b0}};
            ref_cmp_mismatch         <= 1'b0;
            ref_cmp_range_error      <= 1'b0;
            ref_cmp_expected_word    <= {AXI_DW{1'b0}};
        end else begin
            timeout_count <= timeout_count + 1;
            if (otf_done)
                otf_done_count <= otf_done_count + 1;

            if (dut.enc_co_valid && !dut.ubwc_enc_meta_addr_gen_inst.in_fifo_push_ready) begin
                meta_in_fifo_drop_count <= meta_in_fifo_drop_count + 1;
                if (!first_meta_in_fifo_drop_seen) begin
                    first_meta_in_fifo_drop_seen <= 1'b1;
                    first_meta_in_fifo_drop_fmt  <= dut.b_tile_format;
                    first_meta_in_fifo_drop_x    <= dut.b_tile_xcoord;
                    first_meta_in_fifo_drop_y    <= dut.b_tile_ycoord;
                end
            end

            if (dut.meta_valid && dut.meta_ready) begin
                meta_gen_fire_count <= meta_gen_fire_count + 1;
                if (CASE_HAS_PLANE1 && (dut.meta_addr >= CASE_META_BASE_UV_ADDR))
                    meta_gen_fire_count_plane1 <= meta_gen_fire_count_plane1 + 1;
                else begin
                    meta_gen_fire_count_plane0 <= meta_gen_fire_count_plane0 + 1;
                    if (dut.meta_addr < (CASE_META_BASE_Y_ADDR + 64'h2800))
                        meta_gen_y_active_count <= meta_gen_y_active_count + 1;
                    else
                        meta_gen_y_pad_count <= meta_gen_y_pad_count + 1;
                end
            end

            if (dut.tile_coord_vld) begin
                coord_count <= coord_count + 1;
                if (tb_fake_mode_en) begin
                    if (cmd_wr_ptr < TILE_QUEUE_CAPACITY) begin
                        cmd_fmt_queue[cmd_wr_ptr] <= dut.enc_ci_format;
                        cmd_x_queue[cmd_wr_ptr]   <= dut.tile_xcoord_raw;
                        cmd_y_queue[cmd_wr_ptr]   <= dut.tile_ycoord_raw;
                        cmd_wr_ptr                <= cmd_wr_ptr + 1;
                    end
                end
            end

            if (dut.ubwc_enc_otf_to_tile_inst.ci_fifo_wr_en) begin
                if (!rvi_start_direct_w && (rvi_cmd_wr_ptr < TILE_QUEUE_CAPACITY)) begin
                    rvi_fmt_queue[rvi_cmd_wr_ptr] <= dut.ubwc_enc_otf_to_tile_inst.line_tile_format;
                    rvi_x_queue[rvi_cmd_wr_ptr]   <= dut.ubwc_enc_otf_to_tile_inst.line_tile_x;
                    rvi_y_queue[rvi_cmd_wr_ptr]   <= dut.ubwc_enc_otf_to_tile_inst.line_tile_y;
                    rvi_cmd_wr_ptr                <= rvi_cmd_wr_ptr + 1;
                end
                if (tb_fake_mode_en && !cvo_start_direct_w && (cvo_cmd_wr_ptr < TILE_QUEUE_CAPACITY)) begin
                    cvo_fmt_queue[cvo_cmd_wr_ptr]   <= dut.ubwc_enc_otf_to_tile_inst.line_tile_format;
                    cvo_x_queue[cvo_cmd_wr_ptr]     <= dut.ubwc_enc_otf_to_tile_inst.line_tile_x;
                    cvo_y_queue[cvo_cmd_wr_ptr]     <= dut.ubwc_enc_otf_to_tile_inst.line_tile_y;
                    cvo_addr_queue[cvo_cmd_wr_ptr]  <= expected_tile_addr(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                          dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                          dut.ubwc_enc_otf_to_tile_inst.line_tile_y);
                    cvo_beats_queue[cvo_cmd_wr_ptr] <= 4'd8;
                    cvo_cmd_wr_ptr                  <= cvo_cmd_wr_ptr + 1;
                end
            end

            if (!tb_fake_mode_en && dut.enc_axi_awvalid && dut.enc_axi_awready) begin
                if (!cvo_start_direct_w && (cvo_cmd_wr_ptr < TILE_QUEUE_CAPACITY)) begin
                    cvo_fmt_queue[cvo_cmd_wr_ptr]   <= 5'd0;
                    cvo_x_queue[cvo_cmd_wr_ptr]     <= 16'd0;
                    cvo_y_queue[cvo_cmd_wr_ptr]     <= 16'd0;
                    cvo_addr_queue[cvo_cmd_wr_ptr]  <= dut.enc_axi_awaddr;
                    cvo_beats_queue[cvo_cmd_wr_ptr] <= {1'b0, dut.enc_axi_awlen} + 4'd1;
                    cvo_cmd_wr_ptr                  <= cvo_cmd_wr_ptr + 1;
                end
            end

            if (dut.rvi_valid && dut.rvi_ready) begin
                rvi_beat_count <= rvi_beat_count + 1;
                if (!rvi_active_cmd_valid) begin
                    if (rvi_start_direct_w) begin
                        if (masked_axi_word_mismatch(dut.rvi_data,
                                                     dut.rvi_mask,
                                                     pack_expected_tile_axi_word(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                 dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                 dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                                                                                 0))) begin
                            rvi_data_mismatch_count <= rvi_data_mismatch_count + 1;
                            if (!first_rvi_data_mismatch_seen) begin
                                first_rvi_data_mismatch_seen <= 1'b1;
                                first_rvi_data_fmt           <= dut.ubwc_enc_otf_to_tile_inst.line_tile_format;
                                first_rvi_data_x             <= dut.ubwc_enc_otf_to_tile_inst.line_tile_x;
                                first_rvi_data_y             <= dut.ubwc_enc_otf_to_tile_inst.line_tile_y;
                                first_rvi_data_beat          <= 0;
                                first_rvi_data_expected      <= pack_expected_tile_axi_word(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                              dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                              dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                                                                                              0);
                                first_rvi_data_actual        <= dut.rvi_data;
                            end
                        end
                        rvi_active_cmd_valid <= 1'b1;
                        rvi_active_cmd_fmt   <= dut.ubwc_enc_otf_to_tile_inst.line_tile_format;
                        rvi_active_cmd_x     <= dut.ubwc_enc_otf_to_tile_inst.line_tile_x;
                        rvi_active_cmd_y     <= dut.ubwc_enc_otf_to_tile_inst.line_tile_y;
                        rvi_beat_idx         <= 1;
                    end else if (rvi_cmd_rd_ptr >= rvi_cmd_wr_ptr) begin
                        rvi_data_mismatch_count <= rvi_data_mismatch_count + 1;
                        if (!first_rvi_data_mismatch_seen) begin
                            first_rvi_data_mismatch_seen <= 1'b1;
                            first_rvi_data_fmt           <= 5'd0;
                            first_rvi_data_x             <= 16'd0;
                            first_rvi_data_y             <= 16'd0;
                            first_rvi_data_beat          <= 0;
                            first_rvi_data_expected      <= {AXI_DW{1'b0}};
                            first_rvi_data_actual        <= dut.rvi_data;
                        end
                    end else begin
                        if (masked_axi_word_mismatch(dut.rvi_data,
                                                     dut.rvi_mask,
                                                     pack_expected_tile_axi_word(rvi_fmt_queue[rvi_cmd_rd_ptr],
                                                                                 rvi_x_queue[rvi_cmd_rd_ptr],
                                                                                 rvi_y_queue[rvi_cmd_rd_ptr],
                                                                                 0))) begin
                            rvi_data_mismatch_count <= rvi_data_mismatch_count + 1;
                            if (!first_rvi_data_mismatch_seen) begin
                                first_rvi_data_mismatch_seen <= 1'b1;
                                first_rvi_data_fmt           <= rvi_fmt_queue[rvi_cmd_rd_ptr];
                                first_rvi_data_x             <= rvi_x_queue[rvi_cmd_rd_ptr];
                                first_rvi_data_y             <= rvi_y_queue[rvi_cmd_rd_ptr];
                                first_rvi_data_beat          <= 0;
                                first_rvi_data_expected      <= pack_expected_tile_axi_word(rvi_fmt_queue[rvi_cmd_rd_ptr],
                                                                                              rvi_x_queue[rvi_cmd_rd_ptr],
                                                                                              rvi_y_queue[rvi_cmd_rd_ptr],
                                                                                              0);
                                first_rvi_data_actual        <= dut.rvi_data;
                            end
                        end
                        rvi_active_cmd_valid <= 1'b1;
                        rvi_active_cmd_fmt   <= rvi_fmt_queue[rvi_cmd_rd_ptr];
                        rvi_active_cmd_x     <= rvi_x_queue[rvi_cmd_rd_ptr];
                        rvi_active_cmd_y     <= rvi_y_queue[rvi_cmd_rd_ptr];
                        rvi_cmd_rd_ptr       <= rvi_cmd_rd_ptr + 1;
                        rvi_beat_idx         <= 1;
                    end
                end else begin
                    if (masked_axi_word_mismatch(dut.rvi_data,
                                                 dut.rvi_mask,
                                                 pack_expected_tile_axi_word(rvi_active_cmd_fmt,
                                                                             rvi_active_cmd_x,
                                                                             rvi_active_cmd_y,
                                                                             rvi_beat_idx))) begin
                        rvi_data_mismatch_count <= rvi_data_mismatch_count + 1;
                        if (!first_rvi_data_mismatch_seen) begin
                            first_rvi_data_mismatch_seen <= 1'b1;
                            first_rvi_data_fmt           <= rvi_active_cmd_fmt;
                            first_rvi_data_x             <= rvi_active_cmd_x;
                            first_rvi_data_y             <= rvi_active_cmd_y;
                            first_rvi_data_beat          <= rvi_beat_idx;
                            first_rvi_data_expected      <= pack_expected_tile_axi_word(rvi_active_cmd_fmt,
                                                                                          rvi_active_cmd_x,
                                                                                          rvi_active_cmd_y,
                                                                                          rvi_beat_idx);
                            first_rvi_data_actual        <= dut.rvi_data;
                        end
                    end
                    if (rvi_beat_idx == 7) begin
                        rvi_active_cmd_valid <= 1'b0;
                        rvi_beat_idx         <= 0;
                    end else begin
                        rvi_beat_idx         <= rvi_beat_idx + 1;
                    end
                end
            end

            if (dut.enc_cvo_valid && dut.enc_cvo_ready) begin
                cvo_beat_count <= cvo_beat_count + 1;
                if (!cvo_active_cmd_valid) begin
                    if (cvo_start_direct_w) begin
                        if (tb_fake_mode_en) begin
                            if (masked_axi_word_mismatch(dut.enc_cvo_data,
                                                         dut.enc_cvo_mask,
                                                         pack_expected_tile_axi_word(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                     dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                     dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                                                                                     0))) begin
                                cvo_data_mismatch_count <= cvo_data_mismatch_count + 1;
                                if (!first_cvo_data_mismatch_seen) begin
                                    first_cvo_data_mismatch_seen <= 1'b1;
                                    first_cvo_data_fmt           <= dut.ubwc_enc_otf_to_tile_inst.line_tile_format;
                                    first_cvo_data_x             <= dut.ubwc_enc_otf_to_tile_inst.line_tile_x;
                                    first_cvo_data_y             <= dut.ubwc_enc_otf_to_tile_inst.line_tile_y;
                                    first_cvo_data_beat          <= 0;
                                    first_cvo_data_expected      <= pack_expected_tile_axi_word(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                                  dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                                  dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                                                                                                  0);
                                    first_cvo_data_actual        <= dut.enc_cvo_data;
                                end
                            end
                            cvo_active_cmd_fmt   <= dut.ubwc_enc_otf_to_tile_inst.line_tile_format;
                            cvo_active_cmd_x     <= dut.ubwc_enc_otf_to_tile_inst.line_tile_x;
                            cvo_active_cmd_y     <= dut.ubwc_enc_otf_to_tile_inst.line_tile_y;
                            cvo_active_cmd_addr  <= expected_tile_addr(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                        dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                        dut.ubwc_enc_otf_to_tile_inst.line_tile_y);
                            cvo_active_cmd_beats <= 4'd8;
                        end else begin
                            if (masked_axi_word_mismatch(dut.enc_cvo_data,
                                                         dut.enc_cvo_mask,
                                                         pack_main_ref_axi_word(dut.enc_axi_awaddr))) begin
                                cvo_data_mismatch_count <= cvo_data_mismatch_count + 1;
                                if (!first_cvo_data_mismatch_seen) begin
                                    first_cvo_data_mismatch_seen <= 1'b1;
                                    first_cvo_data_fmt           <= 5'd0;
                                    first_cvo_data_x             <= 16'd0;
                                    first_cvo_data_y             <= 16'd0;
                                    first_cvo_data_beat          <= 0;
                                    first_cvo_data_expected      <= pack_main_ref_axi_word(dut.enc_axi_awaddr);
                                    first_cvo_data_actual        <= dut.enc_cvo_data;
                                end
                            end
                            cvo_active_cmd_fmt   <= 5'd0;
                            cvo_active_cmd_x     <= 16'd0;
                            cvo_active_cmd_y     <= 16'd0;
                            cvo_active_cmd_addr  <= dut.enc_axi_awaddr;
                            cvo_active_cmd_beats <= {1'b0, dut.enc_axi_awlen} + 4'd1;
                        end
                        cvo_active_cmd_valid <= 1'b1;
                        cvo_beat_idx         <= 1;
                    end else if (cvo_cmd_rd_ptr >= cvo_cmd_wr_ptr) begin
                        cvo_data_mismatch_count <= cvo_data_mismatch_count + 1;
                        if (!first_cvo_data_mismatch_seen) begin
                            first_cvo_data_mismatch_seen <= 1'b1;
                            first_cvo_data_fmt           <= 5'd0;
                            first_cvo_data_x             <= 16'd0;
                            first_cvo_data_y             <= 16'd0;
                            first_cvo_data_beat          <= 0;
                            first_cvo_data_expected      <= {AXI_DW{1'b0}};
                            first_cvo_data_actual        <= dut.enc_cvo_data;
                        end
                    end else begin
                        if (tb_fake_mode_en) begin
                            if (masked_axi_word_mismatch(dut.enc_cvo_data,
                                                         dut.enc_cvo_mask,
                                                         pack_expected_tile_axi_word(cvo_fmt_queue[cvo_cmd_rd_ptr],
                                                                                     cvo_x_queue[cvo_cmd_rd_ptr],
                                                                                     cvo_y_queue[cvo_cmd_rd_ptr],
                                                                                     0))) begin
                                cvo_data_mismatch_count <= cvo_data_mismatch_count + 1;
                                if (!first_cvo_data_mismatch_seen) begin
                                    first_cvo_data_mismatch_seen <= 1'b1;
                                    first_cvo_data_fmt           <= cvo_fmt_queue[cvo_cmd_rd_ptr];
                                    first_cvo_data_x             <= cvo_x_queue[cvo_cmd_rd_ptr];
                                    first_cvo_data_y             <= cvo_y_queue[cvo_cmd_rd_ptr];
                                    first_cvo_data_beat          <= 0;
                                    first_cvo_data_expected      <= pack_expected_tile_axi_word(cvo_fmt_queue[cvo_cmd_rd_ptr],
                                                                                                  cvo_x_queue[cvo_cmd_rd_ptr],
                                                                                                  cvo_y_queue[cvo_cmd_rd_ptr],
                                                                                                  0);
                                    first_cvo_data_actual        <= dut.enc_cvo_data;
                                end
                            end
                        end else begin
                            if (masked_axi_word_mismatch(dut.enc_cvo_data,
                                                         dut.enc_cvo_mask,
                                                         pack_main_ref_axi_word(cvo_addr_queue[cvo_cmd_rd_ptr]))) begin
                                cvo_data_mismatch_count <= cvo_data_mismatch_count + 1;
                                if (!first_cvo_data_mismatch_seen) begin
                                    first_cvo_data_mismatch_seen <= 1'b1;
                                    first_cvo_data_fmt           <= cvo_fmt_queue[cvo_cmd_rd_ptr];
                                    first_cvo_data_x             <= cvo_x_queue[cvo_cmd_rd_ptr];
                                    first_cvo_data_y             <= cvo_y_queue[cvo_cmd_rd_ptr];
                                    first_cvo_data_beat          <= 0;
                                    first_cvo_data_expected      <= pack_main_ref_axi_word(cvo_addr_queue[cvo_cmd_rd_ptr]);
                                    first_cvo_data_actual        <= dut.enc_cvo_data;
                                end
                            end
                        end
                        cvo_active_cmd_valid <= 1'b1;
                        cvo_active_cmd_fmt   <= cvo_fmt_queue[cvo_cmd_rd_ptr];
                        cvo_active_cmd_x     <= cvo_x_queue[cvo_cmd_rd_ptr];
                        cvo_active_cmd_y     <= cvo_y_queue[cvo_cmd_rd_ptr];
                        cvo_active_cmd_addr  <= cvo_addr_queue[cvo_cmd_rd_ptr];
                        cvo_active_cmd_beats <= cvo_beats_queue[cvo_cmd_rd_ptr];
                        cvo_cmd_rd_ptr       <= cvo_cmd_rd_ptr + 1;
                        cvo_beat_idx         <= 1;
                    end
                end else begin
                    if (tb_fake_mode_en) begin
                        if (masked_axi_word_mismatch(dut.enc_cvo_data,
                                                     dut.enc_cvo_mask,
                                                     pack_expected_tile_axi_word(cvo_active_cmd_fmt,
                                                                                 cvo_active_cmd_x,
                                                                                 cvo_active_cmd_y,
                                                                                 cvo_beat_idx))) begin
                            cvo_data_mismatch_count <= cvo_data_mismatch_count + 1;
                            if (!first_cvo_data_mismatch_seen) begin
                                first_cvo_data_mismatch_seen <= 1'b1;
                                first_cvo_data_fmt           <= cvo_active_cmd_fmt;
                                first_cvo_data_x             <= cvo_active_cmd_x;
                                first_cvo_data_y             <= cvo_active_cmd_y;
                                first_cvo_data_beat          <= cvo_beat_idx;
                                first_cvo_data_expected      <= pack_expected_tile_axi_word(cvo_active_cmd_fmt,
                                                                                              cvo_active_cmd_x,
                                                                                              cvo_active_cmd_y,
                                                                                              cvo_beat_idx);
                                first_cvo_data_actual        <= dut.enc_cvo_data;
                            end
                        end
                    end else begin
                        if (masked_axi_word_mismatch(dut.enc_cvo_data,
                                                     dut.enc_cvo_mask,
                                                     pack_main_ref_axi_word(cvo_active_cmd_addr + (cvo_beat_idx * (AXI_DW/8))))) begin
                            cvo_data_mismatch_count <= cvo_data_mismatch_count + 1;
                            if (!first_cvo_data_mismatch_seen) begin
                                first_cvo_data_mismatch_seen <= 1'b1;
                                first_cvo_data_fmt           <= cvo_active_cmd_fmt;
                                first_cvo_data_x             <= cvo_active_cmd_x;
                                first_cvo_data_y             <= cvo_active_cmd_y;
                                first_cvo_data_beat          <= cvo_beat_idx;
                                first_cvo_data_expected      <= pack_main_ref_axi_word(cvo_active_cmd_addr + (cvo_beat_idx * (AXI_DW/8)));
                                first_cvo_data_actual        <= dut.enc_cvo_data;
                            end
                        end
                    end
                    if (cvo_beat_idx == (cvo_active_cmd_beats - 1)) begin
                        cvo_active_cmd_valid <= 1'b0;
                        cvo_beat_idx         <= 0;
                    end else begin
                        cvo_beat_idx         <= cvo_beat_idx + 1;
                    end
                end
            end

            if (tb_fake_mode_en) begin
                if (dut.enc_axi_awvalid && dut.enc_axi_awready) begin
                    aw_count <= aw_count + 1;
                    if (cmd_rd_ptr >= cmd_wr_ptr) begin
                        queue_underflow_count <= queue_underflow_count + 1;
                    end else begin
                        main_burst_active      <= 1'b1;
                        main_burst_addr        <= dut.enc_axi_awaddr;
                        main_burst_beats_total <= {{AXI_LENW{1'b0}}, 1'b1} + dut.enc_axi_awlen;
                        main_burst_beat_idx    <= {(AXI_LENW+1){1'b0}};
                        active_cmd_valid    <= 1'b1;
                        active_cmd_fmt      <= cmd_fmt_queue[cmd_rd_ptr];
                        active_cmd_x        <= cmd_x_queue[cmd_rd_ptr];
                        active_cmd_y        <= cmd_y_queue[cmd_rd_ptr];
                        active_cmd_beat_idx <= 0;
                        if (dut.enc_axi_awlen !== 8'd7)
                            aw_mismatch_count <= aw_mismatch_count + 1;
                        if (CASE_ADDR_CHECK_EN && (dut.enc_axi_awaddr !== expected_tile_addr(cmd_fmt_queue[cmd_rd_ptr], cmd_x_queue[cmd_rd_ptr], cmd_y_queue[cmd_rd_ptr]))) begin
                            aw_mismatch_count <= aw_mismatch_count + 1;
                            if (!first_aw_mismatch_seen) begin
                                first_aw_mismatch_seen <= 1'b1;
                                first_aw_actual       <= dut.enc_axi_awaddr;
                                first_aw_expected     <= expected_tile_addr(cmd_fmt_queue[cmd_rd_ptr], cmd_x_queue[cmd_rd_ptr], cmd_y_queue[cmd_rd_ptr]);
                                first_aw_fmt          <= cmd_fmt_queue[cmd_rd_ptr];
                                first_aw_x            <= cmd_x_queue[cmd_rd_ptr];
                                first_aw_y            <= cmd_y_queue[cmd_rd_ptr];
                            end
                        end
                        cmd_rd_ptr <= cmd_rd_ptr + 1;
                    end
                    if (!main_word_addr_valid(dut.enc_axi_awaddr)) begin
                        out_range_mismatch_count <= out_range_mismatch_count + 1;
                        if (!first_out_range_seen) begin
                            first_out_range_seen        <= 1'b1;
                            first_out_range_kind        <= 3'd1;
                            first_out_range_addr        <= dut.enc_axi_awaddr;
                            first_out_range_beat_idx    <= {(AXI_LENW+1){1'b0}};
                            first_out_range_beats_total <= {{AXI_LENW{1'b0}}, 1'b1} + dut.enc_axi_awlen;
                        end
                    end
                end

                if (dut.enc_axi_wvalid && dut.enc_axi_wready) begin
                    w_count <= w_count + 1;
                    if (!active_cmd_valid || !main_burst_active) begin
                        queue_underflow_count <= queue_underflow_count + 1;
                    end else begin
                        if (!main_word_addr_valid(main_burst_addr + (main_burst_beat_idx * (AXI_DW/8)))) begin
                            out_range_mismatch_count <= out_range_mismatch_count + 1;
                            if (!first_out_range_seen) begin
                                first_out_range_seen        <= 1'b1;
                                first_out_range_kind        <= 3'd2;
                                first_out_range_addr        <= main_burst_addr + (main_burst_beat_idx * (AXI_DW/8));
                                first_out_range_beat_idx    <= main_burst_beat_idx;
                                first_out_range_beats_total <= main_burst_beats_total;
                            end
                        end
                        if (dut.enc_axi_wstrb !== 32'hFFFF_FFFF)
                            strb_mismatch_count <= strb_mismatch_count + 1;
                        if (dut.enc_axi_wlast !== (main_burst_beat_idx == (main_burst_beats_total - 1'b1)))
                            wlast_mismatch_count <= wlast_mismatch_count + 1;
                        if (main_burst_beat_idx == (main_burst_beats_total - 1'b1)) begin
                            main_burst_active   <= 1'b0;
                            active_cmd_valid    <= 1'b0;
                            active_cmd_beat_idx <= 0;
                        end else begin
                            main_burst_beat_idx <= main_burst_beat_idx + {{AXI_LENW{1'b0}}, 1'b1};
                            active_cmd_beat_idx <= active_cmd_beat_idx + 1;
                        end
                    end
                end
                if (dut.meta_axi_awvalid && dut.meta_axi_awready) begin
                    meta_aw_count <= meta_aw_count + 1;
                    if (CASE_HAS_PLANE1 && (dut.meta_axi_awaddr >= CASE_META_BASE_UV_ADDR)) begin
                        meta_aw_count_plane1 <= meta_aw_count_plane1 + 1;
                        last_meta_aw_addr_uv <= dut.meta_axi_awaddr;
                    end else begin
                        meta_aw_count_plane0 <= meta_aw_count_plane0 + 1;
                        last_meta_aw_addr_y  <= dut.meta_axi_awaddr;
                    end
                    meta_burst_active      <= 1'b1;
                    meta_burst_addr        <= dut.meta_axi_awaddr;
                    meta_burst_beats_total <= {{AXI_LENW{1'b0}}, 1'b1} + dut.meta_axi_awlen;
                    meta_burst_beat_idx    <= {(AXI_LENW+1){1'b0}};
                    if (!meta_word_addr_valid(dut.meta_axi_awaddr)) begin
                        out_range_mismatch_count <= out_range_mismatch_count + 1;
                        if (!first_out_range_seen) begin
                            first_out_range_seen        <= 1'b1;
                            first_out_range_kind        <= 3'd3;
                            first_out_range_addr        <= dut.meta_axi_awaddr;
                            first_out_range_beat_idx    <= {(AXI_LENW+1){1'b0}};
                            first_out_range_beats_total <= {{AXI_LENW{1'b0}}, 1'b1} + dut.meta_axi_awlen;
                        end
                    end
                end

                if (dut.meta_axi_wvalid && dut.meta_axi_wready) begin
                    meta_w_count <= meta_w_count + 1;
                    if (CASE_HAS_PLANE1 && (meta_write_beat_addr_w >= CASE_META_BASE_UV_ADDR))
                        meta_w_count_plane1 <= meta_w_count_plane1 + 1;
                    else
                        meta_w_count_plane0 <= meta_w_count_plane0 + 1;
                    if (meta_write_underflow_w) begin
                        queue_underflow_count <= queue_underflow_count + 1;
                    end else begin
                        if (!meta_word_addr_valid(meta_write_beat_addr_w)) begin
                            out_range_mismatch_count <= out_range_mismatch_count + 1;
                            if (!first_out_range_seen) begin
                                first_out_range_seen        <= 1'b1;
                                first_out_range_kind        <= 3'd4;
                                first_out_range_addr        <= meta_write_beat_addr_w;
                                first_out_range_beat_idx    <= {(AXI_LENW+1){1'b0}};
                                first_out_range_beats_total <= {{AXI_LENW{1'b0}}, 1'b1};
                            end
                        end
                        if (!meta_v2_strb_valid(dut.meta_axi_wstrb))
                            strb_mismatch_count <= strb_mismatch_count + 1;
                        if (dut.meta_axi_wlast !== 1'b1)
                            out_wlast_mismatch_count <= out_wlast_mismatch_count + 1;
                    end
                    meta_burst_active   <= 1'b0;
                    meta_burst_beat_idx <= {(AXI_LENW+1){1'b0}};
                end
                if ((coord_count == expected_tiles_total) &&
                    (aw_count == expected_tiles_total) &&
                    (w_count == expected_beats_total) &&
                    (meta_aw_count == expected_meta_aw_total) &&
                    (meta_w_count == expected_meta_w_total) &&
                    !tb_output_activity)
                    idle_cycles_after_done <= idle_cycles_after_done + 1;
                else
                    idle_cycles_after_done <= 0;
            end else begin
                if (dut.enc_axi_awvalid && dut.enc_axi_awready) begin
                    aw_count               <= aw_count + 1;
                    out_aw_count           <= out_aw_count + 1;
                    main_burst_active      <= 1'b1;
                    main_burst_addr        <= dut.enc_axi_awaddr;
                    main_burst_beats_total <= {{AXI_LENW{1'b0}}, 1'b1} + dut.enc_axi_awlen;
                    main_burst_beat_idx    <= {(AXI_LENW+1){1'b0}};
                    if (!main_word_addr_valid(dut.enc_axi_awaddr)) begin
                        out_range_mismatch_count <= out_range_mismatch_count + 1;
                        if (!first_out_range_seen) begin
                            first_out_range_seen        <= 1'b1;
                            first_out_range_kind        <= 3'd1;
                            first_out_range_addr        <= dut.enc_axi_awaddr;
                            first_out_range_beat_idx    <= {(AXI_LENW+1){1'b0}};
                            first_out_range_beats_total <= {{AXI_LENW{1'b0}}, 1'b1} + dut.enc_axi_awlen;
                        end
                    end
                end

                if (dut.enc_axi_wvalid && dut.enc_axi_wready) begin
                    w_count     <= w_count + 1;
                    out_w_count <= out_w_count + 1;
                    if (!main_burst_active) begin
                        main_mem_mismatch_count <= main_mem_mismatch_count + 1;
                        if (!first_main_mem_mismatch_seen) begin
                            first_main_mem_mismatch_seen <= 1'b1;
                            first_main_mem_addr          <= {AXI_AW{1'b0}};
                            first_main_mem_expected      <= {AXI_DW{1'b0}};
                            first_main_mem_actual        <= dut.enc_axi_wdata;
                            first_main_mem_strb          <= dut.enc_axi_wstrb;
                        end
                    end else begin
                        compare_ref_beat(0,
                                         main_burst_addr + (main_burst_beat_idx * (AXI_DW/8)),
                                         dut.enc_axi_wdata,
                                         dut.enc_axi_wstrb,
                                         ref_cmp_mismatch,
                                         ref_cmp_range_error,
                                         ref_cmp_expected_word);
                        if (ref_cmp_range_error) begin
                            out_range_mismatch_count <= out_range_mismatch_count + 1;
                            if (!first_out_range_seen) begin
                                first_out_range_seen        <= 1'b1;
                                first_out_range_kind        <= 3'd2;
                                first_out_range_addr        <= main_burst_addr + (main_burst_beat_idx * (AXI_DW/8));
                                first_out_range_beat_idx    <= main_burst_beat_idx;
                                first_out_range_beats_total <= main_burst_beats_total;
                            end
                        end
                        if (ref_cmp_mismatch) begin
                            main_mem_mismatch_count <= main_mem_mismatch_count + 1;
                            if (CASE_HAS_PLANE1 && ((main_burst_addr + (main_burst_beat_idx * (AXI_DW/8))) >= CASE_TILE_BASE_UV_ADDR))
                                main_plane1_mem_mismatch_count <= main_plane1_mem_mismatch_count + 1;
                            else
                                main_plane0_mem_mismatch_count <= main_plane0_mem_mismatch_count + 1;
                            if (!first_main_mem_mismatch_seen) begin
                                first_main_mem_mismatch_seen <= 1'b1;
                                first_main_mem_addr          <= main_burst_addr + (main_burst_beat_idx * (AXI_DW/8));
                                first_main_mem_expected      <= ref_cmp_expected_word;
                                first_main_mem_actual        <= dut.enc_axi_wdata;
                                first_main_mem_strb          <= dut.enc_axi_wstrb;
                            end
                        end
                        if (dut.enc_axi_wlast !== (main_burst_beat_idx == (main_burst_beats_total - 1'b1)))
                            out_wlast_mismatch_count <= out_wlast_mismatch_count + 1;
                        if (main_burst_beat_idx == (main_burst_beats_total - 1'b1)) begin
                            main_burst_active   <= 1'b0;
                            main_burst_beat_idx <= {(AXI_LENW+1){1'b0}};
                        end else begin
                            main_burst_beat_idx <= main_burst_beat_idx + {{AXI_LENW{1'b0}}, 1'b1};
                        end
                    end
                end

                if (dut.meta_axi_awvalid && dut.meta_axi_awready) begin
                    meta_aw_count          <= meta_aw_count + 1;
                    if (CASE_HAS_PLANE1 && (dut.meta_axi_awaddr >= CASE_META_BASE_UV_ADDR))
                        meta_aw_count_plane1 <= meta_aw_count_plane1 + 1;
                    else
                        meta_aw_count_plane0 <= meta_aw_count_plane0 + 1;
                    meta_burst_active      <= 1'b1;
                    meta_burst_addr        <= dut.meta_axi_awaddr;
                    meta_burst_beats_total <= {{AXI_LENW{1'b0}}, 1'b1} + dut.meta_axi_awlen;
                    meta_burst_beat_idx    <= {(AXI_LENW+1){1'b0}};
                    if (!first_meta_aw_seen) begin
                        first_meta_aw_seen        <= 1'b1;
                        first_meta_aw_addr        <= dut.meta_axi_awaddr;
                        first_meta_aw_y_base      <= dut.meta_y_base_offset_addr;
                        first_meta_aw_uv_base     <= dut.meta_uv_base_offset_addr;
                        first_meta_aw_y_meta_addr <= dut.y_meta_addr;
                        first_meta_aw_uv_meta_addr<= dut.uv_meta_addr;
                        first_meta_aw_sel_uv      <= dut.meta_sel_uv;
                    end
                    if (!meta_word_addr_valid(dut.meta_axi_awaddr)) begin
                        out_range_mismatch_count <= out_range_mismatch_count + 1;
                        if (!first_out_range_seen) begin
                            first_out_range_seen        <= 1'b1;
                            first_out_range_kind        <= 3'd3;
                            first_out_range_addr        <= dut.meta_axi_awaddr;
                            first_out_range_beat_idx    <= {(AXI_LENW+1){1'b0}};
                            first_out_range_beats_total <= {{AXI_LENW{1'b0}}, 1'b1} + dut.meta_axi_awlen;
                        end
                    end
                end

                if (dut.meta_axi_wvalid && dut.meta_axi_wready) begin
                    meta_w_count <= meta_w_count + 1;
                    if (CASE_HAS_PLANE1 && (meta_write_beat_addr_w >= CASE_META_BASE_UV_ADDR))
                        meta_w_count_plane1 <= meta_w_count_plane1 + 1;
                    else
                        meta_w_count_plane0 <= meta_w_count_plane0 + 1;
                    if (meta_write_underflow_w) begin
                        meta_mem_mismatch_count <= meta_mem_mismatch_count + 1;
                        if (!first_meta_mem_mismatch_seen) begin
                            first_meta_mem_mismatch_seen <= 1'b1;
                            first_meta_mem_addr          <= {AXI_AW{1'b0}};
                            first_meta_mem_expected      <= {AXI_DW{1'b0}};
                            first_meta_mem_actual        <= dut.meta_axi_wdata;
                            first_meta_mem_strb          <= dut.meta_axi_wstrb;
                        end
                    end else begin
                        compare_ref_beat(1,
                                         meta_write_beat_addr_w,
                                         dut.meta_axi_wdata,
                                         dut.meta_axi_wstrb,
                                         ref_cmp_mismatch,
                                         ref_cmp_range_error,
                                         ref_cmp_expected_word);
                        if (ref_cmp_range_error) begin
                            out_range_mismatch_count <= out_range_mismatch_count + 1;
                            if (!first_out_range_seen) begin
                                first_out_range_seen        <= 1'b1;
                                first_out_range_kind        <= 3'd4;
                                first_out_range_addr        <= meta_write_beat_addr_w;
                                first_out_range_beat_idx    <= {(AXI_LENW+1){1'b0}};
                                first_out_range_beats_total <= {{AXI_LENW{1'b0}}, 1'b1};
                            end
                        end
                        if (ref_cmp_mismatch) begin
                            meta_mem_mismatch_count <= meta_mem_mismatch_count + 1;
                            if (CASE_HAS_PLANE1 && (meta_write_beat_addr_w >= CASE_META_BASE_UV_ADDR))
                                meta_plane1_mem_mismatch_count <= meta_plane1_mem_mismatch_count + 1;
                            else
                                meta_plane0_mem_mismatch_count <= meta_plane0_mem_mismatch_count + 1;
                            if (!first_meta_mem_mismatch_seen) begin
                                first_meta_mem_mismatch_seen <= 1'b1;
                                first_meta_mem_addr          <= meta_write_beat_addr_w;
                                first_meta_mem_expected      <= ref_cmp_expected_word;
                                first_meta_mem_actual        <= dut.meta_axi_wdata;
                                first_meta_mem_strb          <= dut.meta_axi_wstrb;
                            end
                        end
                        if (dut.meta_axi_wlast !== 1'b1)
                            out_wlast_mismatch_count <= out_wlast_mismatch_count + 1;
                    end
                    meta_burst_active   <= 1'b0;
                    meta_burst_beat_idx <= {(AXI_LENW+1){1'b0}};
                end

                if ((aw_count != 0) && (w_count != 0) &&
                    (meta_aw_count != 0) && (meta_w_count != 0) &&
                    !dut.enc_axi_awvalid && !dut.enc_axi_wvalid &&
                    !dut.meta_axi_awvalid && !dut.meta_axi_wvalid &&
                    !main_burst_active && !meta_burst_active)
                    idle_cycles_after_done <= idle_cycles_after_done + 1;
                else
                    idle_cycles_after_done <= 0;
            end

            if ((timeout_count != 0) && ((timeout_count % 250000) == 0)) begin
                if (tb_fake_mode_en) begin
                    $display("[TB] progress cycle=%0d mode=fake frame=%0d/%0d coord=%0d aw=%0d w=%0d otf_done=%0d otf_done_cnt=%0d",
                             timeout_count, frames_completed, tb_frame_repeat, coord_count, aw_count, w_count, otf_done, otf_done_count);
                end else begin
                    $display("[TB] progress cycle=%0d mode=real frame=%0d/%0d coord=%0d main_aw=%0d main_w=%0d meta_aw=%0d meta_w=%0d otf_done=%0d otf_done_cnt=%0d",
                             timeout_count, frames_completed, tb_frame_repeat, coord_count, aw_count, w_count, meta_aw_count, meta_w_count, otf_done, otf_done_count);
                end
            end
        end
    end

    initial begin
        wait(rst_n);
        wait(start_otf == 1'b1);
        wait(start_otf == 1'b0);
        wait_frame_idle(tb_frame_repeat);
        if (frames_completed < tb_frame_repeat)
            frames_completed = tb_frame_repeat;

        if (otf_error) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] OTF driver reported input-stream error.");
        end

        if (timeout_count >= case_timeout_cycles) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] Timeout waiting encoder wrapper flow to finish.");
            if (CASE_HAS_PLANE1 && (tb_frame_repeat > 1)) begin
                $display("[TB][DBG] multiframe NV12 timeout diagnostics:");
                $display("  frames_started      : %0d", frames_started);
                $display("  frames_completed    : %0d", frames_completed);
                $display("  otf_done_count      : %0d", otf_done_count);
                $display("  coord_count         : %0d / %0d", coord_count, expected_tiles_total);
                $display("  aw_count            : %0d / %0d", aw_count, expected_tiles_total);
                $display("  w_count             : %0d / %0d", w_count, expected_beats_total);

                $display("  dut top handshake   : rvi_v=%0b rvi_r=%0b ci_v=%0b ci_r=%0b",
                         dut.rvi_valid, dut.rvi_ready, dut.enc_ci_valid, dut.enc_ci_ready);
                $display("  wcmd_gen state      : st=%0d cmd_cnt=%0d data_cnt=%0d awv=%0b wv=%0b cvo_rdy=%0b",
                         dut.ubwc_tile_enc_axi_wcmd_gen_inst.state_r,
                         dut.ubwc_tile_enc_axi_wcmd_gen_inst.cmd_count_r,
                         dut.ubwc_tile_enc_axi_wcmd_gen_inst.data_count_r,
                         dut.enc_axi_awvalid, dut.enc_axi_wvalid, dut.enc_cvo_ready);

                $display("  otf_to_tile fifos   : data_empty=%0b data_af=%0b data_full=%0b ci_empty=%0b ci_full=%0b half_valid=%0b half_last=%0b first_word=%0b",
                         dut.ubwc_enc_otf_to_tile_inst.data_fifo_empty,
                         dut.ubwc_enc_otf_to_tile_inst.data_fifo_almost_full,
                         dut.ubwc_enc_otf_to_tile_inst.data_fifo_full,
                         dut.ubwc_enc_otf_to_tile_inst.ci_fifo_empty,
                         dut.ubwc_enc_otf_to_tile_inst.ci_fifo_full,
                         dut.ubwc_enc_otf_to_tile_inst.half_valid_r,
                         dut.ubwc_enc_otf_to_tile_inst.half_last_r,
                         dut.ubwc_enc_otf_to_tile_inst.tile_first_word_r);
                $display("  line_tile handshake : v=%0b r=%0b plane=%0b x=%0d y=%0d last=%0b",
                         dut.ubwc_enc_otf_to_tile_inst.line_tile_vld,
                         dut.ubwc_enc_otf_to_tile_inst.line_tile_rdy,
                         dut.ubwc_enc_otf_to_tile_inst.line_plane,
                         dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                         dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                         dut.ubwc_enc_otf_to_tile_inst.line_tile_last);

                $display("  packer in/out       : in_empty=%0b a_vld=%0b b_vld=%0b pipe_stall=%0b",
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.in_fifo_empty,
                         dut.ubwc_enc_otf_to_tile_inst.pack_fifo_a_vld,
                         dut.ubwc_enc_otf_to_tile_inst.pack_fifo_b_vld,
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.pipe_stall);

                $display("  line_to_tile state  : rd_state=%0d wr_bank=%0b rd_bank=%0b grp_y_cnt=%0d grp_y=%0d plane=%0b subrow=%0b",
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_state,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.wr_bank_sel,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_bank_sel_act,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_tile_grp_y_cnt,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_group_y,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_plane,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_y_subrow);
                $display("  line_to_tile banks  : b0(a_line=%0d b_line=%0d a_done=%0b b_done=%0b vsync=%0b) b1(a_line=%0d b_line=%0d a_done=%0b b_done=%0b vsync=%0b)",
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_a_line_idx,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_b_line_idx,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_a_done,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_b_done,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_vsync,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_a_line_idx,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_b_line_idx,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_a_done,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_b_done,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_vsync);
                $display("  line_to_tile ready  : bank0_rdy=%0b bank1_rdy=%0b resp_empty=%0b resp_af=%0b",
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_ready_for_read,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_ready_for_read,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.resp_fifo_empty,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.resp_fifo_almost_full);
            end
        end

        if (tb_fake_mode_en) begin
            if (coord_count != expected_tiles_total) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] tile_coord count mismatch: got=%0d exp=%0d", coord_count, expected_tiles_total);
            end
            if (aw_count != expected_tiles_total) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] tile AW count mismatch: got=%0d exp=%0d", aw_count, expected_tiles_total);
            end
            if (w_count != expected_beats_total) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] tile W beat count mismatch: got=%0d exp=%0d", w_count, expected_beats_total);
            end
            if (meta_aw_count != expected_meta_aw_total) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] meta AW count mismatch: got=%0d exp=%0d", meta_aw_count, expected_meta_aw_total);
            end
            if (meta_w_count != expected_meta_w_total) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] meta W beat count mismatch: got=%0d exp=%0d", meta_w_count, expected_meta_w_total);
            end
            if (CASE_HAS_PLANE1 && (meta_aw_count_plane0 != expected_meta_aw_plane0_total)) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] meta Y AW count mismatch: got=%0d exp=%0d", meta_aw_count_plane0, expected_meta_aw_plane0_total);
            end
            if (CASE_HAS_PLANE1 && (meta_aw_count_plane1 != expected_meta_aw_plane1_total)) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] meta UV AW count mismatch: got=%0d exp=%0d", meta_aw_count_plane1, expected_meta_aw_plane1_total);
            end
            if (CASE_HAS_PLANE1 && (meta_w_count_plane0 != expected_meta_w_plane0_total)) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] meta Y W count mismatch: got=%0d exp=%0d", meta_w_count_plane0, expected_meta_w_plane0_total);
            end
            if (CASE_HAS_PLANE1 && (meta_w_count_plane1 != expected_meta_w_plane1_total)) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] meta UV W count mismatch: got=%0d exp=%0d", meta_w_count_plane1, expected_meta_w_plane1_total);
            end
            if (aw_mismatch_count != 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] AW mismatches: %0d", aw_mismatch_count);
                if (first_aw_mismatch_seen) begin
                    $display("[TB][ERROR] first AW mismatch: fmt=%0d x=%0d y=%0d exp=0x%08x act=0x%08x",
                             first_aw_fmt, first_aw_x, first_aw_y, first_aw_expected, first_aw_actual);
                end
            end
            if (strb_mismatch_count != 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] strb mismatches: %0d", strb_mismatch_count);
            end
            if (wlast_mismatch_count != 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] tile wlast mismatches: %0d", wlast_mismatch_count);
            end
            if (out_wlast_mismatch_count != 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] meta burst wlast mismatches: %0d", out_wlast_mismatch_count);
            end
            if (queue_underflow_count != 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] queue underflow count: %0d", queue_underflow_count);
            end
            if (out_range_mismatch_count != 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] out-of-range write count: %0d", out_range_mismatch_count);
                if (first_out_range_seen) begin
                    $display("[TB][ERROR] first out-of-range kind=%0s addr=0x%016x beat=%0d/%0d",
                             (first_out_range_kind == 3'd1) ? "main_aw"  :
                             (first_out_range_kind == 3'd2) ? "main_w"   :
                             (first_out_range_kind == 3'd3) ? "meta_aw"  :
                             (first_out_range_kind == 3'd4) ? "meta_w"   : "unknown",
                             first_out_range_addr,
                             first_out_range_beat_idx,
                             first_out_range_beats_total);
                end
            end
        end else begin
            if (aw_count == 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] no compressed-data AW observed.");
            end
            if (w_count == 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] no compressed-data W observed.");
            end
            if (meta_aw_count == 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] no metadata AW observed.");
            end
            if (meta_w_count == 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] no metadata W observed.");
            end
            if (main_mem_mismatch_count != 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] compressed-data mismatches: %0d", main_mem_mismatch_count);
                if (first_main_mem_mismatch_seen) begin
                    $display("[TB][ERROR] first compressed-data mismatch addr=0x%016x strb=0x%08x",
                             first_main_mem_addr, first_main_mem_strb);
                    $display("[TB][ERROR]   expected=0x%064x", first_main_mem_expected);
                    $display("[TB][ERROR]   actual  =0x%064x", first_main_mem_actual);
                end
            end
            if (meta_mem_mismatch_count != 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] metadata mismatches: %0d", meta_mem_mismatch_count);
                if (first_meta_mem_mismatch_seen) begin
                    $display("[TB][ERROR] first metadata mismatch addr=0x%016x strb=0x%08x",
                             first_meta_mem_addr, first_meta_mem_strb);
                    $display("[TB][ERROR]   expected=0x%064x", first_meta_mem_expected);
                    $display("[TB][ERROR]   actual  =0x%064x", first_meta_mem_actual);
                end
            end
            if (out_range_mismatch_count != 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] out-of-range write count: %0d", out_range_mismatch_count);
                if (first_out_range_seen) begin
                    $display("[TB][ERROR] first out-of-range kind=%0s addr=0x%016x beat=%0d/%0d",
                             (first_out_range_kind == 3'd1) ? "main_aw"  :
                             (first_out_range_kind == 3'd2) ? "main_w"   :
                             (first_out_range_kind == 3'd3) ? "meta_aw"  :
                             (first_out_range_kind == 3'd4) ? "meta_w"   : "unknown",
                             first_out_range_addr,
                             first_out_range_beat_idx,
                             first_out_range_beats_total);
                end
                if (first_meta_aw_seen) begin
                    $display("[TB][ERROR] first meta AW addr=0x%016x sel_uv=%0d y_base=0x%016x uv_base=0x%016x y_meta_addr=0x%016x uv_meta_addr=0x%016x",
                             first_meta_aw_addr,
                             first_meta_aw_sel_uv,
                             first_meta_aw_y_base,
                             first_meta_aw_uv_base,
                             first_meta_aw_y_meta_addr,
                             first_meta_aw_uv_meta_addr);
                end
            end
            if (out_wlast_mismatch_count != 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] burst wlast mismatches: %0d", out_wlast_mismatch_count);
            end
        end

        dump_mem_to_files();
        close_mem_dump_files();

        compare_meta_dump_file_to_ref(meta_dump_file,
                                      CASE_META_BASE_Y_ADDR,
                                      CASE_META0_WORDS64,
                                      0);
        if (CASE_HAS_PLANE1) begin
            compare_meta_dump_file_to_ref(meta_dump_file_plane1,
                                          CASE_META_BASE_UV_ADDR,
                                          CASE_META1_WORDS64,
                                          1);
        end

        $display("[TB] Encoder wrapper case summary:");
        $display("  CASE_ID             : %0d", CASE_ID);
        $display("  mode                : %0s", tb_fake_mode_en ? "fake" : "non-fake");
        $display("  frame_repeat        : %0d", tb_frame_repeat);
        $display("  frames_started      : %0d", frames_started);
        $display("  frames_completed    : %0d", frames_completed);
        $display("  otf_done_count      : %0d", otf_done_count);
        $display("  coord_count         : %0d", coord_count);
        $display("  rvi_beat_count      : %0d", rvi_beat_count);
        $display("  rvi_data_mismatch   : %0d", rvi_data_mismatch_count);
        $display("  cvo_beat_count      : %0d", cvo_beat_count);
        $display("  cvo_data_mismatch   : %0d", cvo_data_mismatch_count);
        if (tb_fake_mode_en) begin
            $display("  tile_aw_count       : %0d", aw_count);
            $display("  tile_w_count        : %0d", w_count);
            $display("  meta_aw_count       : %0d", meta_aw_count);
            $display("  meta_w_count        : %0d", meta_w_count);
            $display("  aw_mismatch_count   : %0d", aw_mismatch_count);
            $display("  range_mismatch_cnt  : %0d", out_range_mismatch_count);
            $display("  strb_mismatch_count : %0d", strb_mismatch_count);
            $display("  tile_wlast_mismatch : %0d", wlast_mismatch_count);
            $display("  meta_wlast_mismatch : %0d", out_wlast_mismatch_count);
            $display("  queue_underflow_cnt : %0d", queue_underflow_count);
        end else begin
            $display("  main_aw_count       : %0d", aw_count);
            $display("  main_w_count        : %0d", w_count);
            $display("  meta_aw_count       : %0d", meta_aw_count);
            $display("  meta_w_count        : %0d", meta_w_count);
            $display("  main_mem_mismatch   : %0d", main_mem_mismatch_count);
            $display("  meta_mem_mismatch   : %0d", meta_mem_mismatch_count);
            $display("  range_mismatch_cnt  : %0d", out_range_mismatch_count);
            $display("  wlast_mismatch_cnt  : %0d", out_wlast_mismatch_count);
        end
        $display("  dut.err_bline       : %0d", dut.err_bline);
        $display("  dut.err_bframe      : %0d", dut.err_bframe);
        $display("  dut.err_fifo_ovf    : %0d", dut.err_fifo_ovf);
        $display("  otf_error           : %0d", otf_error);
        $display("  main_mem_dump_file  : %0s", main_dump_file);
        $display("  meta_mem_dump_file  : %0s", meta_dump_file);
        if (CASE_HAS_PLANE1) begin
            $display("  main_mem_dump_file1 : %0s", main_dump_file_plane1);
            $display("  meta_mem_dump_file1 : %0s", meta_dump_file_plane1);
            if (tb_fake_mode_en) begin
                $display("  meta_aw_count_y     : %0d", meta_aw_count_plane0);
                $display("  meta_aw_count_uv    : %0d", meta_aw_count_plane1);
                $display("  meta_w_count_y      : %0d", meta_w_count_plane0);
                $display("  meta_w_count_uv     : %0d", meta_w_count_plane1);
            end else begin
                $display("  meta_aw_count_y     : %0d", meta_aw_count_plane0);
                $display("  meta_aw_count_uv    : %0d", meta_aw_count_plane1);
                $display("  meta_w_count_y      : %0d", meta_w_count_plane0);
                $display("  meta_w_count_uv     : %0d", meta_w_count_plane1);
            end
        end
        $display("  meta_dump_cmp_mis   : %0d", meta_dump_mismatch_count);
        $display("  meta_dump_cmp_wcerr : %0d", meta_dump_word_count_error_count);
        if (CASE_HAS_PLANE1) begin
            $display("  meta_dump_cmp_y     : %0d", meta_dump_mismatch_plane0_count);
            $display("  meta_dump_cmp_uv    : %0d", meta_dump_mismatch_plane1_count);
        end
        if (!tb_fake_mode_en && CASE_HAS_PLANE1) begin
            if (CASE_IS_G016) begin
                $display("  ref main Y          : ../../enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out0.txt");
                $display("  ref main UV         : ../../enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out1.txt");
                $display("  ref meta Y          : ../../enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out2.txt");
                $display("  ref meta UV         : ../../enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out3.txt");
            end else begin
                $display("  ref main Y          : ../../enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out0.txt");
                $display("  ref main UV         : ../../enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out1.txt");
                $display("  ref meta Y          : ../../enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out2.txt");
                $display("  ref meta UV         : ../../enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out3.txt");
            end
            $display("  main Y mismatch cnt : %0d", main_plane0_mem_mismatch_count);
            $display("  main UV mismatch cnt: %0d", main_plane1_mem_mismatch_count);
            $display("  meta Y mismatch cnt : %0d", meta_plane0_mem_mismatch_count);
            $display("  meta UV mismatch cnt: %0d", meta_plane1_mem_mismatch_count);
        end

        if (meta_dump_mismatch_count != 0) begin
            if (!tb_fake_mode_en)
                fail_count = fail_count + 1;
            $display("%s dumped meta/golden mismatches: %0d",
                     tb_fake_mode_en ? "[TB][WARN]" : "[TB][ERROR]",
                     meta_dump_mismatch_count);
            if (first_meta_dump_mismatch_seen) begin
                $display("%s first dumped meta mismatch addr=0x%016x",
                         tb_fake_mode_en ? "[TB][WARN]" : "[TB][ERROR]",
                         first_meta_dump_addr);
                $display("%s   expected=0x%016x",
                         tb_fake_mode_en ? "[TB][WARN]" : "[TB][ERROR]",
                         first_meta_dump_expected);
                $display("%s   actual  =0x%016x",
                         tb_fake_mode_en ? "[TB][WARN]" : "[TB][ERROR]",
                         first_meta_dump_actual);
            end
        end
        if (meta_dump_word_count_error_count != 0) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] dumped meta word-count/base errors: %0d", meta_dump_word_count_error_count);
        end
        if (rvi_beat_count != expected_beats_total) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] rvi beat count mismatch: got=%0d exp=%0d",
                     rvi_beat_count, expected_beats_total);
        end
        if (rvi_data_mismatch_count != 0) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] rvi/tiled-uncompressed data mismatches: %0d",
                     rvi_data_mismatch_count);
            if (first_rvi_data_mismatch_seen) begin
                $display("[TB][ERROR] first rvi data mismatch: fmt=%0d x=%0d y=%0d beat=%0d",
                         first_rvi_data_fmt,
                         first_rvi_data_x,
                         first_rvi_data_y,
                         first_rvi_data_beat);
                $display("[TB][ERROR]   expected=0x%064x", first_rvi_data_expected);
                $display("[TB][ERROR]   actual  =0x%064x", first_rvi_data_actual);
            end
        end
        if (tb_fake_mode_en) begin
            if (cvo_beat_count != expected_beats_total) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] fake cvo beat count mismatch: got=%0d exp=%0d",
                         cvo_beat_count, expected_beats_total);
            end
        end else begin
            if (cvo_beat_count != w_count) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] non-fake cvo beat count mismatch: got=%0d exp(main_w)=%0d",
                         cvo_beat_count, w_count);
            end
        end
        if (cvo_data_mismatch_count != 0) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] cvo data mismatches: %0d",
                     cvo_data_mismatch_count);
            if (first_cvo_data_mismatch_seen) begin
                $display("[TB][ERROR] first cvo data mismatch: fmt=%0d x=%0d y=%0d beat=%0d",
                         first_cvo_data_fmt,
                         first_cvo_data_x,
                         first_cvo_data_y,
                         first_cvo_data_beat);
                $display("[TB][ERROR]   expected=0x%064x", first_cvo_data_expected);
                $display("[TB][ERROR]   actual  =0x%064x", first_cvo_data_actual);
            end
        end

        if (fail_count == 0) begin
            if (tb_fake_mode_en)
                $display("PASS: encoder wrapper fake-vivo layout/address/count check passed.");
            else
                $display("PASS: encoder wrapper non-fake compressed/metadata reference check passed.");
        end else begin
            if (tb_fake_mode_en)
                $display("FAIL: encoder wrapper fake-vivo layout/address/count check failed.");
            else
                $display("FAIL: encoder wrapper non-fake compressed/metadata reference check failed.");
        end
        $finish;
    end

    final begin
        if (main_dump_fd != 0)
            $fclose(main_dump_fd);
        if (main_dump_fd_plane1 != 0)
            $fclose(main_dump_fd_plane1);
        if (meta_dump_fd != 0)
            $fclose(meta_dump_fd);
        if (meta_dump_fd_plane1 != 0)
            $fclose(meta_dump_fd_plane1);
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        case (CASE_ID)
            CASE_RGBA1010102: $fsdbDumpfile("tb_ubwc_enc_wrapper_top_tajmahal_rgba1010102.fsdb");
            CASE_G016:        $fsdbDumpfile("tb_ubwc_enc_wrapper_top_k_outdoor61_g016.fsdb");
            CASE_NV12:        $fsdbDumpfile("tb_ubwc_enc_wrapper_top_tajmahal_nv12.fsdb");
            default:          $fsdbDumpfile("tb_ubwc_enc_wrapper_top_tajmahal_rgba8888.fsdb");
        endcase
        $fsdbDumpvars(0, tb_ubwc_enc_wrapper_top_tajmahal_core);
        $fsdbDumpvars(0, dut.ubwc_enc_otf_to_tile_inst);
        $fsdbDumpMDA(0, tb_ubwc_enc_wrapper_top_tajmahal_core);
`else
        case (CASE_ID)
            CASE_RGBA1010102: $dumpfile("tb_ubwc_enc_wrapper_top_tajmahal_rgba1010102.vcd");
            CASE_G016:        $dumpfile("tb_ubwc_enc_wrapper_top_k_outdoor61_g016.vcd");
            CASE_NV12:        $dumpfile("tb_ubwc_enc_wrapper_top_tajmahal_nv12.vcd");
            default:          $dumpfile("tb_ubwc_enc_wrapper_top_tajmahal_rgba8888.vcd");
        endcase
        $dumpvars(0, tb_ubwc_enc_wrapper_top_tajmahal_core);
        $dumpvars(0, dut.ubwc_enc_otf_to_tile_inst);
`endif
`endif
    end
endmodule

module tb_ubwc_enc_wrapper_top_tajmahal_cases #(
    parameter integer CASE_ID = 0
) ();
    tb_ubwc_enc_wrapper_top_tajmahal_core #(
        .CASE_ID(CASE_ID)
    ) u_core ();
endmodule

module tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888 ();
    tb_ubwc_enc_wrapper_top_tajmahal_core #(
        .CASE_ID(0)
    ) u_core ();
endmodule

module tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102 ();
    tb_ubwc_enc_wrapper_top_tajmahal_core #(
        .CASE_ID(1)
    ) u_core ();
endmodule

module tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 ();
    tb_ubwc_enc_wrapper_top_tajmahal_core #(
        .CASE_ID(2)
    ) u_core ();
endmodule

module tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 ();
    tb_ubwc_enc_wrapper_top_tajmahal_core #(
        .CASE_ID(3)
    ) u_core ();
endmodule

`default_nettype wire
