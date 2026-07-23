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
    reg [DATA_W-1:0] dout_pipe [0:2];
    reg [2:0]        dout_vld_pipe;
    integer          tb_bank_dly;
    integer idx;

    initial begin
        dout     = {DATA_W{1'b0}};
        dout_vld = 1'b0;
        dout_vld_pipe = 3'd0;
        tb_bank_dly = 1;
        void'($value$plusargs("tb_bank_dly=%d", tb_bank_dly));
        if (tb_bank_dly < 1)
            tb_bank_dly = 1;
        if (tb_bank_dly > 4)
            tb_bank_dly = 4;
        for (idx = 0; idx < 3; idx = idx + 1)
            dout_pipe[idx] = {DATA_W{1'b0}};
        for (idx = 0; idx < (1 << ADDR_W); idx = idx + 1)
            mem[idx] = {DATA_W{1'b0}};
    end

    always @(posedge clk) begin
        dout_vld <= 1'b0;
        dout_vld_pipe <= {dout_vld_pipe[1:0], 1'b0};
        dout_pipe[2] <= dout_pipe[1];
        dout_pipe[1] <= dout_pipe[0];
        if (en) begin
            if (wen) begin
                mem[addr] <= din;
            end else begin
                if (tb_bank_dly <= 1) begin
                    dout     <= mem[addr];
                    dout_vld <= 1'b1;
                end else begin
                    dout_pipe[0]      <= mem[addr];
                    dout_vld_pipe[0]  <= 1'b1;
                    dout              <= dout_pipe[tb_bank_dly - 2];
                    dout_vld          <= dout_vld_pipe[tb_bank_dly - 2];
                end
            end
        end else if (tb_bank_dly > 1) begin
            dout     <= dout_pipe[tb_bank_dly - 2];
            dout_vld <= dout_vld_pipe[tb_bank_dly - 2];
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
    integer tb_axi_random_en;
    integer tb_axi_seed;
    integer tb_axi_aw_stall_pct;
    integer tb_axi_w_stall_pct;
    reg dbg_meta_sink_en;
    reg dbg_meta_sink_fatal_en;
    reg [31:0] axi_rand_state;
    reg        axi_awready_gate;
    reg        axi_wready_gate;

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

    function automatic [31:0] lfsr_next;
        input [31:0] state_in;
        reg feedback;
        begin
            feedback = state_in[31] ^ state_in[21] ^ state_in[1] ^ state_in[0];
            lfsr_next = {state_in[30:0], feedback};
            if (lfsr_next == 32'd0)
                lfsr_next = 32'h6d2b_79f5;
        end
    endfunction

    function automatic ready_from_stall_pct;
        input [31:0] rand_word;
        input integer stall_pct;
        integer pct;
        begin
            if (stall_pct <= 0) begin
                ready_from_stall_pct = 1'b1;
            end else if (stall_pct >= 100) begin
                ready_from_stall_pct = 1'b0;
            end else begin
                pct = rand_word % 100;
                ready_from_stall_pct = (pct >= stall_pct);
            end
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
        awready = aresetn && !aw_fifo_full_w && axi_awready_gate;
        wready  = aresetn && axi_wready_gate &&
                  (burst_active || aw_fifo_valid_w || (awvalid && awready));

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
        tb_axi_random_en  = 0;
        tb_axi_seed       = 32'h6d2b_79f5;
        tb_axi_aw_stall_pct = 0;
        tb_axi_w_stall_pct  = 0;
        axi_rand_state      = 32'h6d2b_79f5;
        axi_awready_gate    = 1'b1;
        axi_wready_gate     = 1'b1;
        dbg_meta_sink_en        = 1'b0;
        dbg_meta_sink_fatal_en  = 1'b0;
        if ($test$plusargs("tb_axi_random"))
            tb_axi_random_en = 1;
        void'($value$plusargs("tb_axi_random=%d", tb_axi_random_en));
        void'($value$plusargs("tb_axi_seed=%d", tb_axi_seed));
        void'($value$plusargs("tb_axi_aw_stall_pct=%d", tb_axi_aw_stall_pct));
        void'($value$plusargs("tb_axi_w_stall_pct=%d", tb_axi_w_stall_pct));
        axi_rand_state = (tb_axi_seed == 0) ? 32'h6d2b_79f5 : tb_axi_seed[31:0];
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
            axi_rand_state    <= (tb_axi_seed == 0) ? 32'h6d2b_79f5 : tb_axi_seed[31:0];
            axi_awready_gate  <= 1'b1;
            axi_wready_gate   <= 1'b1;
        end else begin
            if (tb_axi_random_en != 0) begin
                axi_rand_state   <= lfsr_next(lfsr_next(axi_rand_state));
                axi_awready_gate <= ready_from_stall_pct(axi_rand_state, tb_axi_aw_stall_pct);
                axi_wready_gate  <= ready_from_stall_pct(lfsr_next(axi_rand_state), tb_axi_w_stall_pct);
            end else begin
                axi_awready_gate <= 1'b1;
                axi_wready_gate  <= 1'b1;
            end

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
                    $display("[TB_META_SINK] t=%0t w addr=%016x base=%016x beat=%0d/%0d strb=%08x wlast=%0b exp_last=%0b active=%0b aw_pop=%0b data=%064x",
                             $time,
                             curr_beat_addr_w,
                             curr_addr_w,
                             curr_beat_idx_w,
                             curr_beats_w,
                             wstrb,
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
    parameter integer CASE_ID = 0,
    parameter integer IMG_W = 4096,
    parameter integer RGBA_ACTIVE_H = 600,
    parameter integer RGBA_STORED_H = 608,
    parameter integer RGBA_TILE_PITCH = 16384,
    parameter integer RGBA_TILE_COLS = 256,
    parameter integer RGBA_TILE_ROWS = 152,
    parameter integer RGBA_META_WORDS64 = 5120,
    parameter integer CFG_NV12_ACTIVE_H = 600,
    parameter integer CFG_NV12_Y_STORED_H = 640,
    parameter integer CFG_NV12_UV_STORED_H = 320,
    parameter integer CFG_NV12_TILE_PITCH = 4096,
    parameter integer CFG_NV12_Y_TILE_COLS = 128,
    parameter integer CFG_NV12_UV_TILE_COLS = 128,
    parameter integer CFG_NV12_Y_TILE_ROWS = 80,
    parameter integer CFG_NV12_UV_TILE_ROWS = 40,
    parameter integer CFG_NV12_COMP_Y_WORDS64 = 311296,
    parameter integer CFG_NV12_COMP_UV_WORDS64 = 163840,
    parameter integer CFG_NV12_META_Y_WORDS64 = 1536,
    parameter integer CFG_NV12_META_UV_WORDS64 = 1024,
    parameter integer CFG_G016_ACTIVE_H = 600,
    parameter integer CFG_G016_Y_STORED_H = 608,
    parameter integer CFG_G016_UV_STORED_H = 304,
    parameter integer CFG_G016_TILE_PITCH = 8192,
    parameter integer CFG_G016_Y_TILE_COLS = 128,
    parameter integer CFG_G016_UV_TILE_COLS = 128,
    parameter integer CFG_G016_Y_TILE_ROWS = 152,
    parameter integer CFG_G016_UV_TILE_ROWS = 76,
    parameter integer CFG_G016_COMP_Y_WORDS64 = 622592,
    parameter integer CFG_G016_COMP_UV_WORDS64 = 311296,
    parameter integer CFG_G016_META_Y_WORDS64 = 2560,
    parameter integer CFG_G016_META_UV_WORDS64 = 1536,
    parameter [63:0] CFG_RGBA_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_A000,
    parameter [63:0] CFG_RGBA_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_NV12_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_3000,
    parameter [63:0] CFG_NV12_TILE_BASE_UV_ADDR = 64'h0000_0000_8028_5000,
    parameter [63:0] CFG_NV12_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_NV12_META_BASE_UV_ADDR = 64'h0000_0000_8028_3000,
    parameter [63:0] CFG_G016_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_5000,
    parameter [63:0] CFG_G016_TILE_BASE_UV_ADDR = 64'h0000_0000_804C_8000,
    parameter [63:0] CFG_G016_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_G016_META_BASE_UV_ADDR = 64'h0000_0000_804C_5000,
    parameter integer COM_BUF_AW = 11,
    parameter integer CASE_TILE_EXPECT_LINEAR = 0,
    parameter integer CASE_CI_LOSSY = 0,
    parameter integer CASE_UBWC_CFG_0 = 0,
    parameter integer CASE_UBWC_CFG_1 = 0,
    parameter integer CASE_UBWC_CFG_2 = 0,
    parameter integer CASE_UBWC_CFG_3 = 0,
    parameter integer CASE_UBWC_CFG_4 = 0,
    parameter integer CASE_UBWC_CFG_5 = 0,
    parameter integer CASE_UBWC_CFG_6 = 0,
    parameter integer CASE_UBWC_CFG_7 = 0,
    parameter integer CASE_UBWC_CFG_8 = 0,
    parameter integer CASE_UBWC_CFG_9 = 0,
    parameter integer CASE_UBWC_CFG_10 = 0,
    parameter integer CASE_UBWC_CFG_11 = 0
) ();
    localparam integer CASE_RGBA8888    = 0;
    localparam integer CASE_RGBA1010102 = 1;
    localparam integer CASE_NV12        = 2;
    localparam integer CASE_G016        = 3;

    function automatic integer align_up_int;
        input integer value;
        input integer alignment;
        begin
            align_up_int = ((value + alignment - 1) / alignment) * alignment;
        end
    endfunction

    task automatic report_first_mismatch_header;
        input string checker_name;
        input string wave_scope;
        begin
            $display("[TB][FIRST_MISMATCH] time=%0t checker=%0s scope=%0s",
                     $time, checker_name, wave_scope);
        end
    endtask

    localparam integer APB_AW          = 16;
    localparam integer APB_DW          = 32;
    localparam integer AXI_AW          = 64;
    localparam integer AXI_DW          = 256;
    localparam integer M_AXI_DW        = 128;
    localparam integer AXI_LENW        = 8;
    localparam integer AXI_IDW         = 4;
    localparam integer COM_BUF_DW      = 128;
    localparam integer SB_WIDTH        = 1;
    localparam [63:0]  META_BYTE_CMP_MASK = 64'h1f1f_1f1f_1f1f_1f1f;

    localparam [63:0]  CFG_RGBA_TILE_BASE_Y_ADDR_Z  = {32'd0, CFG_RGBA_TILE_BASE_Y_ADDR[31:0]};
    localparam [63:0]  CFG_RGBA_META_BASE_Y_ADDR_Z  = {32'd0, CFG_RGBA_META_BASE_Y_ADDR[31:0]};
    localparam [63:0]  CFG_NV12_TILE_BASE_Y_ADDR_Z  = {32'd0, CFG_NV12_TILE_BASE_Y_ADDR[31:0]};
    localparam [63:0]  CFG_NV12_TILE_BASE_UV_ADDR_Z = {32'd0, CFG_NV12_TILE_BASE_UV_ADDR[31:0]};
    localparam [63:0]  CFG_NV12_META_BASE_Y_ADDR_Z  = {32'd0, CFG_NV12_META_BASE_Y_ADDR[31:0]};
    localparam [63:0]  CFG_NV12_META_BASE_UV_ADDR_Z = {32'd0, CFG_NV12_META_BASE_UV_ADDR[31:0]};
    localparam [63:0]  CFG_G016_TILE_BASE_Y_ADDR_Z  = {32'd0, CFG_G016_TILE_BASE_Y_ADDR[31:0]};
    localparam [63:0]  CFG_G016_TILE_BASE_UV_ADDR_Z = {32'd0, CFG_G016_TILE_BASE_UV_ADDR[31:0]};
    localparam [63:0]  CFG_G016_META_BASE_Y_ADDR_Z  = {32'd0, CFG_G016_META_BASE_Y_ADDR[31:0]};
    localparam [63:0]  CFG_G016_META_BASE_UV_ADDR_Z = {32'd0, CFG_G016_META_BASE_UV_ADDR[31:0]};

    localparam real TB_APB_CLK_HALF_NS   = 5.0000;   // 100 MHz
    localparam real TB_AXI_CLK_HALF_NS   = 1.0000;   // 500 MHz
    localparam real TB_CORE_CLK_HALF_NS  = 2.5000;   // 200 MHz
    localparam real TB_OTF_CLK_HALF_NS   = 1.5625;   // 320 MHz

    localparam integer NV12_ACTIVE_H   = CFG_NV12_ACTIVE_H;
    localparam integer NV12_Y_STORED_H = CFG_NV12_Y_STORED_H;
    localparam integer NV12_UV_STORED_H= CFG_NV12_UV_STORED_H;
    localparam integer NV12_TILE_PITCH   = CFG_NV12_TILE_PITCH;
    localparam integer NV12_Y_TILE_COLS  = CFG_NV12_Y_TILE_COLS;
    localparam integer NV12_UV_TILE_COLS = CFG_NV12_UV_TILE_COLS;
    localparam integer NV12_Y_TILE_ROWS  = CFG_NV12_Y_TILE_ROWS;
    localparam integer NV12_UV_TILE_ROWS = CFG_NV12_UV_TILE_ROWS;
    localparam integer NV12_UV_ACTIVE_H  = (NV12_ACTIVE_H + 1) / 2;
    localparam integer NV12_Y_ACTIVE_TILE_ROWS  = (NV12_ACTIVE_H + 7) / 8;
    localparam integer NV12_UV_ACTIVE_TILE_ROWS = (NV12_UV_ACTIVE_H + 7) / 8;
    localparam integer NV12_COMP_Y_WORDS64  = CFG_NV12_COMP_Y_WORDS64;
    localparam integer NV12_COMP_UV_WORDS64 = CFG_NV12_COMP_UV_WORDS64;

    localparam integer G016_ACTIVE_H      = CFG_G016_ACTIVE_H;
    localparam integer G016_Y_STORED_H    = CFG_G016_Y_STORED_H;
    localparam integer G016_UV_STORED_H   = CFG_G016_UV_STORED_H;
    localparam integer G016_TILE_PITCH    = CFG_G016_TILE_PITCH;
    localparam integer G016_Y_TILE_COLS   = CFG_G016_Y_TILE_COLS;
    localparam integer G016_UV_TILE_COLS  = CFG_G016_UV_TILE_COLS;
    localparam integer G016_Y_TILE_ROWS   = CFG_G016_Y_TILE_ROWS;
    localparam integer G016_UV_TILE_ROWS  = CFG_G016_UV_TILE_ROWS;
    localparam integer G016_UV_ACTIVE_H   = (G016_ACTIVE_H + 1) / 2;
    localparam integer G016_Y_ACTIVE_TILE_ROWS  = (G016_ACTIVE_H + 3) / 4;
    localparam integer G016_UV_ACTIVE_TILE_ROWS = (G016_UV_ACTIVE_H + 3) / 4;

    localparam integer CASE_IS_NV12       = (CASE_ID == CASE_NV12);
    localparam integer CASE_IS_G016       = (CASE_ID == CASE_G016);
    localparam integer CASE_HAS_PLANE1    = CASE_IS_NV12 || CASE_IS_G016;
    localparam integer CASE_IS_RGBA10     = (CASE_ID == CASE_RGBA1010102);
    localparam integer CASE_IS_LOSSY_RGBA_2_1 = (CASE_ID == CASE_RGBA8888) && (CASE_CI_LOSSY != 0);
    localparam integer CASE_OTF_FMT       = CASE_IS_G016 ? 3'd3 :
                                            (CASE_IS_NV12 ? 3'd2 :
                                             (CASE_IS_RGBA10 ? 3'd1 : 3'd0));
    localparam integer CASE_CI_FMT        = CASE_IS_G016 ? 5'd14 :
                                            (CASE_IS_NV12 ? 5'd8 :
                                             (CASE_IS_RGBA10 ? 5'd1 : 5'd0));
    localparam integer CASE_STORED_H      = CASE_IS_G016 ? G016_Y_STORED_H :
                                            (CASE_IS_NV12 ? NV12_Y_STORED_H : RGBA_STORED_H);
    localparam integer CASE_ACTIVE_H      = CASE_IS_G016 ? G016_ACTIVE_H :
                                            (CASE_IS_NV12 ? NV12_ACTIVE_H : RGBA_ACTIVE_H);
    localparam integer CASE_TILE_W        = CASE_IS_G016 ? 32 :
                                            (CASE_IS_NV12 ? 32 : 16);
    localparam integer CASE_TILE_H        = CASE_IS_G016 ? 4 :
                                            (CASE_IS_NV12 ? 8 : 4);
    localparam integer CASE_BYTES_PER_PIXEL = CASE_IS_G016 ? 2 :
                                              (CASE_IS_NV12 ? 1 : 4);
    localparam integer CASE_A_TILE_COLS   = CASE_IS_G016 ? G016_UV_TILE_COLS :
                                            (CASE_IS_NV12 ? NV12_UV_TILE_COLS : RGBA_TILE_COLS);
    localparam integer CASE_B_TILE_COLS   = CASE_HAS_PLANE1 ? (CASE_IS_G016 ? G016_Y_TILE_COLS : NV12_Y_TILE_COLS) : 0;
    localparam integer CASE_PITCH_BYTES   = align_up_int(IMG_W * CASE_BYTES_PER_PIXEL,
                                                         CASE_TILE_W * 4 * CASE_BYTES_PER_PIXEL);
    localparam integer CASE_META_PITCH_BYTES = align_up_int((align_up_int(IMG_W, CASE_TILE_W * 4) + CASE_TILE_W - 1) / CASE_TILE_W, 64);
    localparam integer CASE_PITCH_UNITS = CASE_PITCH_BYTES / 16;
    localparam integer CASE_TILE0_WORDS64 = CASE_IS_G016 ? ((G016_TILE_PITCH * G016_Y_STORED_H) / 8) :
                                            (CASE_IS_NV12 ? ((NV12_TILE_PITCH * NV12_Y_STORED_H) / 8)
                                                          : ((RGBA_TILE_PITCH * RGBA_STORED_H) / 8));
    localparam integer CASE_TILE1_WORDS64 = CASE_IS_G016 ? ((G016_TILE_PITCH * G016_UV_STORED_H) / 8) :
                                            (CASE_IS_NV12 ? ((NV12_TILE_PITCH * NV12_UV_STORED_H) / 8) : 1);
    localparam integer CASE_LINEAR_TILE0_WORDS64 = align_up_int(IMG_W * CASE_BYTES_PER_PIXEL * CASE_ACTIVE_H, 8) / 8;
    localparam integer CASE_LINEAR_TILE1_WORDS64 = CASE_HAS_PLANE1 ?
                                             (align_up_int(IMG_W * CASE_BYTES_PER_PIXEL *
                                                           (CASE_IS_G016 ? G016_UV_ACTIVE_H : NV12_UV_ACTIVE_H), 8) / 8) : 1;
    localparam integer CASE_TILE0_FILE_WORDS64 = (CASE_TILE_EXPECT_LINEAR != 0) ?
                                             CASE_LINEAR_TILE0_WORDS64 : CASE_TILE0_WORDS64;
    localparam integer CASE_TILE1_FILE_WORDS64 = (CASE_TILE_EXPECT_LINEAR != 0) ?
                                             CASE_LINEAR_TILE1_WORDS64 : CASE_TILE1_WORDS64;
    localparam integer CASE_EXPECTED_TILES = CASE_IS_G016 ? ((G016_Y_TILE_COLS  * G016_Y_TILE_ROWS) +
                                                             (G016_UV_TILE_COLS * G016_UV_TILE_ROWS)) :
                                             (CASE_IS_NV12 ? ((NV12_Y_TILE_COLS  * NV12_Y_TILE_ROWS) +
                                                              (NV12_UV_TILE_COLS * NV12_UV_TILE_ROWS))
                                                           : (RGBA_TILE_COLS * RGBA_TILE_ROWS));
    localparam integer CASE_ACTIVE_TILE_ROWS = (RGBA_ACTIVE_H + 3) / 4;
    localparam integer CASE_ACTIVE_EXPECTED_TILES =
                                             CASE_IS_G016 ? ((G016_Y_TILE_COLS  * G016_Y_ACTIVE_TILE_ROWS) +
                                                            (G016_UV_TILE_COLS * G016_UV_ACTIVE_TILE_ROWS)) :
                                             (CASE_IS_NV12 ? ((NV12_Y_TILE_COLS  * NV12_Y_ACTIVE_TILE_ROWS) +
                                                              (NV12_UV_TILE_COLS * NV12_UV_ACTIVE_TILE_ROWS))
                                                           : (RGBA_TILE_COLS * CASE_ACTIVE_TILE_ROWS));
    localparam integer CASE_EXPECTED_BEATS = CASE_ACTIVE_EXPECTED_TILES * 8;
    localparam integer MAX_FRAME_REPEAT    = 100;
    localparam integer TILE_QUEUE_CAPACITY = CASE_EXPECTED_TILES * MAX_FRAME_REPEAT;
    localparam integer CASE_TIMEOUT_CYCLES = CASE_IS_NV12 ? 20000000 : 20000000;
    localparam integer CASE_ADDR_CHECK_EN  = 1;
    localparam [63:0]  CASE_TILE_BASE_Y_ADDR   = CASE_IS_G016 ? CFG_G016_TILE_BASE_Y_ADDR_Z :
                                                  (CASE_IS_NV12 ? CFG_NV12_TILE_BASE_Y_ADDR_Z : CFG_RGBA_TILE_BASE_Y_ADDR_Z);
    localparam [63:0]  CASE_TILE_BASE_UV_ADDR  = CASE_IS_G016 ? CFG_G016_TILE_BASE_UV_ADDR_Z :
                                                  (CASE_IS_NV12 ? CFG_NV12_TILE_BASE_UV_ADDR_Z : 64'h0000_0000_0000_0000);
    localparam [63:0]  CASE_META_BASE_Y_ADDR   = CASE_IS_G016 ? CFG_G016_META_BASE_Y_ADDR_Z :
                                                  (CASE_IS_NV12 ? CFG_NV12_META_BASE_Y_ADDR_Z : CFG_RGBA_META_BASE_Y_ADDR_Z);
    localparam [63:0]  CASE_META_BASE_UV_ADDR  = CASE_IS_G016 ? CFG_G016_META_BASE_UV_ADDR_Z :
                                                  (CASE_IS_NV12 ? CFG_NV12_META_BASE_UV_ADDR_Z : 64'h0000_0000_0000_0000);
    localparam integer CASE_CMP0_WORDS64       = CASE_IS_NV12 ? NV12_COMP_Y_WORDS64 : CASE_TILE0_WORDS64;
    localparam integer CASE_CMP1_WORDS64       = CASE_HAS_PLANE1 ? (CASE_IS_NV12 ? NV12_COMP_UV_WORDS64 : CASE_TILE1_WORDS64) : 1;
    localparam integer CASE_FAKE_CMP0_WORDS64  = CASE_IS_G016 ? (G016_Y_TILE_COLS  * G016_Y_TILE_ROWS  * 32) :
                                                  (CASE_IS_NV12 ? (NV12_Y_TILE_COLS  * NV12_Y_TILE_ROWS  * 32)
                                                                : (RGBA_TILE_COLS    * RGBA_TILE_ROWS    * 32));
    localparam integer CASE_FAKE_CMP1_WORDS64  = CASE_HAS_PLANE1 ? (CASE_IS_G016 ? (G016_UV_TILE_COLS * G016_UV_TILE_ROWS * 32)
                                                                                  : (NV12_UV_TILE_COLS * NV12_UV_TILE_ROWS * 32))
                                                                  : 0;
    localparam integer CASE_META0_WORDS64      = CASE_IS_G016 ? CFG_G016_META_Y_WORDS64 :
                                                  (CASE_IS_NV12 ? CFG_NV12_META_Y_WORDS64 : RGBA_META_WORDS64);
    localparam integer CASE_META1_WORDS64      = CASE_IS_G016 ? CFG_G016_META_UV_WORDS64 :
                                                  (CASE_IS_NV12 ? CFG_NV12_META_UV_WORDS64 : 1);
    localparam integer CASE_META_TOTAL_WORDS64 = CASE_META0_WORDS64 + (CASE_HAS_PLANE1 ? CASE_META1_WORDS64 : 0);
    localparam integer CASE_EXPECTED_META_W    = CASE_META_TOTAL_WORDS64;
    localparam integer CASE_EXPECTED_META_AW   = CASE_META_TOTAL_WORDS64;
    localparam integer CASE_EXPECTED_META0_W   = CASE_META0_WORDS64;
    localparam integer CASE_EXPECTED_META0_AW  = CASE_META0_WORDS64;
    localparam integer CASE_EXPECTED_META1_W   = CASE_HAS_PLANE1 ? CASE_META1_WORDS64 : 0;
    localparam integer CASE_EXPECTED_META1_AW  = CASE_HAS_PLANE1 ? CASE_META1_WORDS64 : 0;
    localparam integer CASE_FAKE_META0_WORDS64 = CASE_META0_WORDS64;
    localparam integer CASE_FAKE_META1_WORDS64 = CASE_HAS_PLANE1 ? CASE_META1_WORDS64 : 0;
    localparam integer CASE_FAKE_ACTIVE_META0_WORDS64 =
                                                 CASE_IS_G016 ? (((G016_Y_TILE_COLS  + 7) / 8) * G016_Y_ACTIVE_TILE_ROWS) :
                                                 (CASE_IS_NV12 ? (((NV12_Y_TILE_COLS + 7) / 8) * NV12_Y_ACTIVE_TILE_ROWS)
                                                               : (((RGBA_TILE_COLS   + 7) / 8) * CASE_ACTIVE_TILE_ROWS));
    localparam integer CASE_FAKE_ACTIVE_META1_WORDS64 =
                                                 CASE_HAS_PLANE1 ? (CASE_IS_G016 ? (((G016_UV_TILE_COLS + 7) / 8) * G016_UV_ACTIVE_TILE_ROWS)
                                                                                  : (((NV12_UV_TILE_COLS + 7) / 8) * NV12_UV_ACTIVE_TILE_ROWS))
                                                                 : 0;
    localparam integer CASE_FAKE_EXPECTED_META_W    = CASE_FAKE_ACTIVE_META0_WORDS64 +
                                                      (CASE_HAS_PLANE1 ? CASE_FAKE_ACTIVE_META1_WORDS64 : 0);
    localparam integer CASE_FAKE_EXPECTED_META_AW   = CASE_FAKE_EXPECTED_META_W;
    localparam integer CASE_FAKE_EXPECTED_META0_W   = CASE_FAKE_ACTIVE_META0_WORDS64;
    localparam integer CASE_FAKE_EXPECTED_META0_AW  = CASE_FAKE_ACTIVE_META0_WORDS64;
    localparam integer CASE_FAKE_EXPECTED_META1_W   = CASE_FAKE_ACTIVE_META1_WORDS64;
    localparam integer CASE_FAKE_EXPECTED_META1_AW  = CASE_FAKE_ACTIVE_META1_WORDS64;
    localparam [63:0]  CASE_MAIN_BASE_MIN      = CASE_TILE_BASE_Y_ADDR;
    localparam [63:0]  CASE_META_BASE_MIN      = (CASE_HAS_PLANE1 && (CASE_META_BASE_UV_ADDR < CASE_META_BASE_Y_ADDR)) ?
                                                 CASE_META_BASE_UV_ADDR : CASE_META_BASE_Y_ADDR;
    localparam [63:0]  CASE_META_REF_END_ADDR  = CASE_HAS_PLANE1 ?
                                                 (((CASE_META_BASE_Y_ADDR + (CASE_META0_WORDS64 * 8)) >
                                                   (CASE_META_BASE_UV_ADDR + (CASE_META1_WORDS64 * 8))) ?
                                                  (CASE_META_BASE_Y_ADDR + (CASE_META0_WORDS64 * 8)) :
                                                  (CASE_META_BASE_UV_ADDR + (CASE_META1_WORDS64 * 8))) :
                                                 (CASE_META_BASE_Y_ADDR + (CASE_META0_WORDS64 * 8));
    localparam integer CASE_MAIN_REF_WORDS64   = CASE_HAS_PLANE1 ?
                                                 (((CASE_TILE_BASE_UV_ADDR + (CASE_CMP1_WORDS64 * 8)) - CASE_MAIN_BASE_MIN) >> 3) :
                                                 CASE_CMP0_WORDS64;
    localparam integer CASE_META_REF_WORDS64   = (CASE_META_REF_END_ADDR - CASE_META_BASE_MIN) >> 3;
    localparam [63:0]  CASE_MAIN_END_ADDR      = CASE_HAS_PLANE1 ? (CASE_TILE_BASE_UV_ADDR + (CASE_CMP1_WORDS64 * 8))
                                                                 : (CASE_TILE_BASE_Y_ADDR  + (CASE_CMP0_WORDS64 * 8));
    localparam [63:0]  CASE_META_END_ADDR      = CASE_HAS_PLANE1 ? (CASE_META_BASE_UV_ADDR + (CASE_META1_WORDS64 * 8))
                                                                 : (CASE_META_BASE_Y_ADDR  + (CASE_META0_WORDS64 * 8));
    localparam [63:0]  CASE_OUTPUT_MEM_END_ADDR = (CASE_MAIN_END_ADDR > CASE_META_END_ADDR) ?
                                                  CASE_MAIN_END_ADDR : CASE_META_END_ADDR;
    localparam integer CASE_OUTPUT_MEM_WORDS64 = (CASE_OUTPUT_MEM_END_ADDR - CASE_META_BASE_MIN) >> 3;

    reg                         clk;
    reg                         pclk;
    reg                         vivo_clk;
    reg                         otf_clk;
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
    wire [M_AXI_DW-1:0]         o_m_axi_wdata;
    wire [(M_AXI_DW/8)-1:0]     o_m_axi_wstrb;
    wire                        o_m_axi_wvalid;
    wire                        o_m_axi_wlast;
    wire                        i_m_axi_wready;
    wire [AXI_IDW:0]            i_m_axi_bid;
    wire [1:0]                  i_m_axi_bresp;
    wire                        i_m_axi_bvalid;
    wire                        o_m_axi_bready;
    wire [7:0]                  o_stage_done;
    wire                        o_frame_done;
    wire                        o_irq;

    reg  [63:0]                 tile_plane0_words [0:CASE_TILE0_WORDS64-1];
    reg  [63:0]                 tile_plane1_words [0:CASE_TILE1_WORDS64-1];
    reg  [63:0]                 exp_main_words [0:CASE_MAIN_REF_WORDS64-1];
    reg  [63:0]                 exp_meta_words [0:CASE_META_REF_WORDS64-1];
    reg  [63:0]                 exp_meta_plane0_words [0:CASE_META0_WORDS64-1];
    reg  [63:0]                 exp_meta_plane1_words [0:CASE_META1_WORDS64-1];

    reg  [4:0]                  cmd_fmt_queue [0:TILE_QUEUE_CAPACITY-1];
    reg  [15:0]                 cmd_x_queue   [0:TILE_QUEUE_CAPACITY-1];
    reg  [15:0]                 cmd_y_queue   [0:TILE_QUEUE_CAPACITY-1];
    reg  [2:0]                  cmd_alen_queue[0:TILE_QUEUE_CAPACITY-1];
    reg  [AXI_AW-1:0]           cmd_addr_queue[0:TILE_QUEUE_CAPACITY-1];
    reg  [4:0]                  cvo_fmt_queue [0:TILE_QUEUE_CAPACITY-1];
    reg  [15:0]                 cvo_x_queue   [0:TILE_QUEUE_CAPACITY-1];
    reg  [15:0]                 cvo_y_queue   [0:TILE_QUEUE_CAPACITY-1];
    reg  [AXI_AW-1:0]           cvo_addr_queue[0:TILE_QUEUE_CAPACITY-1];
    reg  [3:0]                  cvo_beats_queue[0:TILE_QUEUE_CAPACITY-1];
    reg  [3:0]                  cvo_valid_beats_queue[0:TILE_QUEUE_CAPACITY-1];

    integer                     cmd_wr_ptr;
    integer                     cmd_rd_ptr;
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
    integer                     expected_rvi_beats_total;
    integer                     fake_expected_beats_total;
    integer                     expected_meta_aw_total;
    integer                     expected_meta_w_total;
    integer                     expected_meta_aw_plane0_total;
    integer                     expected_meta_aw_plane1_total;
    integer                     expected_meta_w_plane0_total;
    integer                     expected_meta_w_plane1_total;
    reg  [7:0]                  expected_stage_done;
    integer                     meta_ref_words_plane0;
    integer                     meta_ref_words_plane1;
    integer                     meta_ref_words_total;
    integer                     meta_ref_active_words_plane0;
    integer                     meta_ref_active_words_plane1;
    integer                     meta_ref_active_words_total;
    integer                     otf_done_count;
    integer                     rvi_beat_count;
    integer                     rvi_beat_idx;
    integer                     cvo_beat_count;
    integer                     vivo_ci_mismatch_count;
    integer                     rvi_data_mismatch_count;
    integer                     rvi_mask_mismatch_count;
    integer                     rvi_last_mismatch_count;
    integer                     rvi_coord_mismatch_count;
    integer                     cvo_data_mismatch_count;
    integer                     cvo_mask_mismatch_count;
    integer                     cvo_last_mismatch_count;
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
    reg  [3:0]                  cvo_active_valid_beats;
    integer                     cvo_beat_idx;
    reg                         first_rvi_data_mismatch_seen;
    reg  [4:0]                  first_rvi_data_fmt;
    reg  [15:0]                 first_rvi_data_x;
    reg  [15:0]                 first_rvi_data_y;
    integer                     first_rvi_data_beat;
    reg  [AXI_DW-1:0]           first_rvi_data_expected;
    reg  [AXI_DW-1:0]           first_rvi_data_actual;
    reg                         first_rvi_mask_mismatch_seen;
    reg  [4:0]                  first_rvi_mask_fmt;
    reg  [15:0]                 first_rvi_mask_x;
    reg  [15:0]                 first_rvi_mask_y;
    integer                     first_rvi_mask_beat;
    reg  [31:0]                 first_rvi_mask_expected;
    reg  [31:0]                 first_rvi_mask_actual;
    reg                         first_rvi_last_mismatch_seen;
    reg  [4:0]                  first_rvi_last_fmt;
    reg  [15:0]                 first_rvi_last_x;
    reg  [15:0]                 first_rvi_last_y;
    integer                     first_rvi_last_beat;
    reg                         first_rvi_last_expected;
    reg                         first_rvi_last_actual;
    reg                         first_rvi_coord_mismatch_seen;
    reg  [4:0]                  first_rvi_coord_exp_fmt;
    reg  [15:0]                 first_rvi_coord_exp_x;
    reg  [15:0]                 first_rvi_coord_exp_y;
    reg  [4:0]                  first_rvi_coord_act_fmt;
    reg  [15:0]                 first_rvi_coord_act_x;
    reg  [15:0]                 first_rvi_coord_act_y;
    integer                     first_rvi_coord_beat;
    reg                         first_cvo_data_mismatch_seen;
    reg  [4:0]                  first_cvo_data_fmt;
    reg  [15:0]                 first_cvo_data_x;
    reg  [15:0]                 first_cvo_data_y;
    integer                     first_cvo_data_beat;
    reg  [AXI_DW-1:0]           first_cvo_data_expected;
    reg  [AXI_DW-1:0]           first_cvo_data_actual;
    reg                         first_cvo_mask_mismatch_seen;
    reg  [4:0]                  first_cvo_mask_fmt;
    reg  [15:0]                 first_cvo_mask_x;
    reg  [15:0]                 first_cvo_mask_y;
    integer                     first_cvo_mask_beat;
    reg  [31:0]                 first_cvo_mask_expected;
    reg  [31:0]                 first_cvo_mask_actual;
    reg                         first_cvo_last_mismatch_seen;
    reg  [4:0]                  first_cvo_last_fmt;
    reg  [15:0]                 first_cvo_last_x;
    reg  [15:0]                 first_cvo_last_y;
    integer                     first_cvo_last_beat;
    reg                         first_cvo_last_expected;
    reg                         first_cvo_last_actual;
    reg                         first_vivo_ci_mismatch_seen;
    reg  [4:0]                  first_vivo_ci_mismatch_fmt;
    reg  [15:0]                 first_vivo_ci_mismatch_x;
    reg  [15:0]                 first_vivo_ci_mismatch_y;
    reg  [7:0]                  first_vivo_ci_expected_metadata;
    reg  [7:0]                  first_vivo_ci_actual_metadata;
    reg  [2:0]                  first_vivo_ci_expected_alen;
    reg  [2:0]                  first_vivo_ci_actual_alen;
    reg                         first_vivo_ci_expected_pcm;
    reg                         first_vivo_ci_actual_pcm;
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
    wire                        mon_meta_valid;
    wire                        mon_meta_ready;
    wire                        mon_meta_last;
    wire                        mon_meta_sel_y;
    wire                        mon_meta_sel_uv;
    wire                        mon_y_meta_valid;
    wire                        mon_y_meta_last;
    wire                        mon_y_meta_ready;
    wire [64-1:0]               mon_y_meta_data;
    wire [AXI_AW-1:0]           mon_y_meta_addr;
    wire                        mon_uv_meta_valid;
    wire                        mon_uv_meta_last;
    wire                        mon_uv_meta_ready;
    wire [64-1:0]               mon_uv_meta_data;
    wire [AXI_AW-1:0]           mon_uv_meta_addr;
    wire                        mon_meta_aw_fire;
    wire                        mon_meta_aw_sel_uv;
    wire [AXI_AW-1:0]           mon_meta_aw_y_addr;
    wire [AXI_AW-1:0]           mon_meta_aw_uv_addr;
    wire                        mon_b_co_valid;
    wire                        mon_err_bline;
    wire                        mon_err_bframe;
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
    integer                     meta_path_stall_count;
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
    reg                         lossy_aw_split_pending;
    reg  [AXI_AW-1:0]           lossy_aw_split_addr;
    reg  [AXI_LENW:0]           lossy_aw_split_beats;
    reg  [4:0]                  lossy_aw_split_fmt;
    reg  [15:0]                 lossy_aw_split_x;
    reg  [15:0]                 lossy_aw_split_y;
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
    reg                         first_meta_path_stall_seen;
    reg  [4:0]                  first_meta_path_stall_fmt;
    reg  [27:0]                 first_meta_path_stall_x;
    reg  [12:0]                 first_meta_path_stall_y;
    reg  [AXI_DW/8-1:0]         first_main_mem_strb;
    reg  [AXI_DW/8-1:0]         first_meta_mem_strb;
    reg                         ref_cmp_mismatch;
    reg                         ref_cmp_range_error;
    reg  [AXI_DW-1:0]           ref_cmp_expected_word;
    reg                         lossy_aw_expected_valid_w;
    reg                         lossy_aw_expected_split_w;
    reg  [AXI_AW-1:0]           lossy_aw_expected_addr_w;
    reg  [AXI_LENW-1:0]         lossy_aw_expected_len_w;
    reg  [AXI_LENW:0]           lossy_aw_expected_beats_w;
    reg  [AXI_AW-1:0]           lossy_aw_second_addr_w;
    reg  [AXI_LENW:0]           lossy_aw_second_beats_w;
    reg  [4:0]                  lossy_aw_expected_fmt_w;
    reg  [15:0]                 lossy_aw_expected_x_w;
    reg  [15:0]                 lossy_aw_expected_y_w;
    integer                     lossy_aw_total_beats_i;
    integer                     lossy_aw_bytes_to_4k_i;
    integer                     lossy_aw_first_beats_i;
    integer                     lossy_aw_second_beats_i;
    reg                         fake_cvo_drv_valid;
    integer                     fake_cvo_drv_rd_ptr;
    integer                     fake_cvo_drv_beat_idx;
    wire                        tb_output_activity;
    wire                        ci_cmd_fire_w;
    wire                        fake_vivo_ci_fire_w;
    wire                        fake_vivo_ci_active_w;
    wire [7:0]                  fake_vivo_co_meta_byte_w;
    wire [7:0]                  fake_vivo_co_metadata_w;
    reg                         fake_cvo_drv_cmd_valid_w;
    reg  [AXI_AW-1:0]           fake_cvo_drv_addr_w;
    reg  [AXI_DW-1:0]           fake_cvo_drv_data_w;
    reg  [31:0]                 fake_cvo_drv_mask_w;
    reg                         fake_cvo_drv_last_w;
    reg                         cvo_expect_valid_w;
    reg                         cvo_expect_direct_w;
    reg                         cvo_expect_queue_w;
    reg  [4:0]                  cvo_expect_fmt_w;
    reg  [15:0]                 cvo_expect_x_w;
    reg  [15:0]                 cvo_expect_y_w;
    reg  [AXI_AW-1:0]           cvo_expect_base_addr_w;
    reg  [AXI_AW-1:0]           cvo_expect_addr_w;
    reg  [AXI_DW-1:0]           cvo_expect_data_w;
    reg  [31:0]                 cvo_expect_mask_w;
    reg                         cvo_expect_last_w;
    reg  [3:0]                  cvo_expect_beat_w;
    reg  [3:0]                  cvo_expect_beats_w;
    reg  [3:0]                  cvo_expect_valid_beats_w;
    wire                        rvi_mon_fire_w;
    wire [AXI_DW-1:0]           rvi_mon_data_w;
    wire [31:0]                 rvi_mon_mask_w;
    wire [AXI_DW-1:0]           rvi_exp_data_w;
    wire [31:0]                 rvi_exp_mask_w;
    wire                        rvi_exp_last_w;
    wire                        meta_aw_fire_w;
    wire                        meta_w_fire_w;
    wire                        meta_use_curr_aw_w;
    wire [AXI_AW-1:0]           meta_write_beat_addr_w;
    wire                        meta_write_underflow_w;
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

    function automatic integer expected_tile_active_cols;
        input [4:0] fmt;
        begin
            if ((fmt == 5'd0) || (fmt == 5'd1))
                expected_tile_active_cols = RGBA_TILE_COLS;
            else if (fmt == 5'd8)
                expected_tile_active_cols = NV12_Y_TILE_COLS;
            else if (fmt == 5'd9)
                expected_tile_active_cols = NV12_UV_TILE_COLS;
            else if (fmt == 5'd14)
                expected_tile_active_cols = G016_Y_TILE_COLS;
            else
                expected_tile_active_cols = G016_UV_TILE_COLS;
        end
    endfunction

    function automatic integer expected_tile_active_rows;
        input [4:0] fmt;
        begin
            if ((fmt == 5'd0) || (fmt == 5'd1))
                expected_tile_active_rows = CASE_ACTIVE_TILE_ROWS;
            else if (fmt == 5'd8)
                expected_tile_active_rows = NV12_Y_ACTIVE_TILE_ROWS;
            else if (fmt == 5'd9)
                expected_tile_active_rows = NV12_UV_ACTIVE_TILE_ROWS;
            else if (fmt == 5'd14)
                expected_tile_active_rows = G016_Y_ACTIVE_TILE_ROWS;
            else
                expected_tile_active_rows = G016_UV_ACTIVE_TILE_ROWS;
        end
    endfunction

    function automatic expected_ci_forced_pcm;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        integer plane_active_height;
        integer tile_h;
        integer partial_width;
        integer partial_height;
        integer tile_cols;
        integer tile_rows;
        begin
            if ((fmt == 5'd0) || (fmt == 5'd1)) begin
                plane_active_height = RGBA_ACTIVE_H;
                tile_h              = 4;
            end else if (fmt == 5'd8) begin
                plane_active_height = NV12_ACTIVE_H;
                tile_h              = 8;
            end else if (fmt == 5'd9) begin
                plane_active_height = NV12_UV_ACTIVE_H;
                tile_h              = 8;
            end else if (fmt == 5'd14) begin
                plane_active_height = G016_ACTIVE_H;
                tile_h              = 4;
            end else begin
                plane_active_height = G016_UV_ACTIVE_H;
                tile_h              = 4;
            end

            tile_cols             = expected_tile_active_cols(fmt);
            tile_rows             = expected_tile_active_rows(fmt);
            partial_width         = (IMG_W % CASE_TILE_W) != 0;
            partial_height        = (plane_active_height % tile_h) != 0;
            expected_ci_forced_pcm = ((partial_width  != 0) && (tile_cols != 0) && (tile_x == (tile_cols - 1))) ||
                                     ((partial_height != 0) && (tile_rows != 0) && (tile_y == (tile_rows - 1)));
        end
    endfunction

    function automatic [AXI_AW-1:0] expected_meta_byte_addr;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        reg [AXI_AW-1:0] base_addr_local;
        reg [AXI_AW-1:0] offset_local;
        begin
            base_addr_local = ((fmt == 5'd9) || (fmt == 5'd15)) ?
                              CASE_META_BASE_UV_ADDR : CASE_META_BASE_Y_ADDR;
            offset_local = ((tile_y >> 4) * CASE_META_PITCH_BYTES * 16) +
                           ((tile_x >> 4) << 8) +
                           (((tile_y >> 3) & 1) << 7) +
                           (((tile_x >> 3) & 1) << 6) +
                           ((tile_y & 7) << 3) +
                           (tile_x & 7);
            expected_meta_byte_addr = base_addr_local + offset_local;
        end
    endfunction

    function automatic [7:0] expected_meta_byte;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        integer byte_sel;
        integer offset_local;
        integer word_idx;
        reg [63:0] word_local;
        reg [AXI_AW-1:0] byte_addr_local;
        begin
            offset_local = ((tile_y >> 4) * CASE_META_PITCH_BYTES * 16) +
                           ((tile_x >> 4) << 8) +
                           (((tile_y >> 3) & 1) << 7) +
                           (((tile_x >> 3) & 1) << 6) +
                           ((tile_y & 7) << 3) +
                           (tile_x & 7);
            byte_sel     = offset_local & 7;
            word_idx     = offset_local >> 3;
            word_local   = 64'd0;
            if (tb_fake_mode_en) begin
                if ((fmt == 5'd9) || (fmt == 5'd15)) begin
                    if ((word_idx >= 0) && (word_idx < CASE_META1_WORDS64))
                        word_local = exp_meta_plane1_words[word_idx];
                end else begin
                    if ((word_idx >= 0) && (word_idx < CASE_META0_WORDS64))
                        word_local = exp_meta_plane0_words[word_idx];
                end
            end else begin
                byte_addr_local = expected_meta_byte_addr(fmt, tile_x, tile_y);
                byte_sel        = byte_addr_local[2:0];
                word_local      = meta_ref_word64(byte_addr_local);
            end
            expected_meta_byte = word_local[byte_sel*8 +: 8];
        end
    endfunction

    function automatic integer fake_meta_compressed_size;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input [7:0] meta_byte;
        integer regular_size;
        integer coord_active;
        begin
            coord_active = (tile_x < expected_tile_active_cols(fmt)) &&
                           (tile_y < expected_tile_active_rows(fmt));
            regular_size = ({1'b0, meta_byte[3:1]} + 4'd1) << 5;

            if (!coord_active)
                fake_meta_compressed_size = 0;
            else if (meta_byte[7:6] != 2'b00)
                fake_meta_compressed_size = 32;
            else if (!meta_byte[4])
                fake_meta_compressed_size = 32;
            else if ((fmt == 5'd0) && meta_byte[5] && (regular_size == 256))
                fake_meta_compressed_size = 192;
            else
                fake_meta_compressed_size = regular_size;
        end
    endfunction

    function automatic [2:0] fake_meta_alen_from_byte;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input [7:0] meta_byte;
        integer coord_active;
        begin
            coord_active = (tile_x < expected_tile_active_cols(fmt)) &&
                           (tile_y < expected_tile_active_rows(fmt));
            fake_meta_alen_from_byte = coord_active ? meta_byte[3:1] :
                                                      3'd0;
        end
    endfunction

    function automatic [3:0] fake_meta_valid_beats_from_byte;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input [7:0] meta_byte;
        begin
            fake_meta_valid_beats_from_byte = {1'b0, fake_meta_alen_from_byte(fmt,
                                                                               tile_x,
                                                                               tile_y,
                                                                               meta_byte)} + 4'd1;
        end
    endfunction

    function automatic [3:0] fake_meta_total_beats_from_byte;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input [7:0] meta_byte;
        reg [3:0] valid_beats;
        begin
            valid_beats = fake_meta_valid_beats_from_byte(fmt, tile_x, tile_y, meta_byte);
            fake_meta_total_beats_from_byte = (valid_beats == 4'd0) ? 4'd1 : valid_beats;
        end
    endfunction

    function automatic [AXI_AW-1:0] expected_tile_addr_with_alen;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input [2:0] alen;
        reg [AXI_AW-1:0] addr_local;
        reg [AXI_AW-1:0] base_addr_local;
        reg [AXI_AW-1:0] addr_delta_local;
        reg [AXI_AW-1:0] addr_unit_local;
        integer base_word;
        begin
            if ((fmt == 5'd0) && (CASE_IS_LOSSY_RGBA_2_1 != 0)) begin
                base_word = rgba_tile_base_word(tile_x, tile_y >> 1);
                addr_local = CASE_TILE_BASE_Y_ADDR + (base_word << 3) +
                             ((tile_y & 1) ? 64'd128 : 64'd0);
            end else begin
                addr_local = expected_tile_addr(fmt, tile_x, tile_y);
                base_addr_local = ((fmt == 5'd9) || (fmt == 5'd15)) ?
                                  CASE_TILE_BASE_UV_ADDR : CASE_TILE_BASE_Y_ADDR;
                addr_delta_local = addr_local - base_addr_local;
                addr_unit_local  = addr_delta_local >> 4;
                if (alen <= 3'd3) begin
                    if (addr_unit_local[5] ^ addr_unit_local[4])
                        addr_local = addr_local + 64'd128;
                end
            end
            expected_tile_addr_with_alen = addr_local;
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
            if (CASE_TILE_EXPECT_LINEAR != 0) begin
                pack_expected_tile_axi_word = pack_expected_linear_tile_axi_word(fmt, tile_x, tile_y, beat_idx);
            end else if ((fmt == 5'd0) || (fmt == 5'd1)) begin
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
            if (CASE_TILE_EXPECT_LINEAR == 0)
                pack_expected_tile_axi_word = {w3, w2, w1, w0};
        end
    endfunction

    function automatic [7:0] expected_linear_byte;
        input integer plane_sel;
        input integer byte_idx;
        integer word_idx;
        integer byte_off;
        reg [63:0] word_local;
        begin
            word_idx = byte_idx / 8;
            byte_off = byte_idx % 8;
            word_local = 64'd0;
            if (plane_sel == 0) begin
                if ((word_idx >= 0) && (word_idx < CASE_TILE0_WORDS64))
                    word_local = tile_plane0_words[word_idx];
            end else begin
                if ((word_idx >= 0) && (word_idx < CASE_TILE1_WORDS64))
                    word_local = tile_plane1_words[word_idx];
            end
            expected_linear_byte = word_local[byte_off*8 +: 8];
        end
    endfunction

    function automatic [AXI_DW-1:0] pack_expected_linear_tile_axi_word;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer beat_idx;
        integer plane_sel;
        integer tile_width_px;
        integer tile_height_ln;
        integer bytes_per_pixel;
        integer plane_active_h;
        integer plane_row_bytes;
        integer tile_row_bytes;
        integer beats_per_tile_row;
        integer row_in_tile;
        integer beat_in_row;
        integer row_abs;
        integer col_byte_base;
        integer byte_idx;
        integer src_byte_idx;
        integer sample_byte_idx;
        reg [15:0] sample16;
        reg [7:0] byte_local;
        reg [AXI_DW-1:0] data_local;
        begin
            plane_sel = 0;
            tile_width_px = 16;
            tile_height_ln = 4;
            bytes_per_pixel = 4;
            plane_active_h = CASE_ACTIVE_H;
            plane_row_bytes = IMG_W * 4;

            if (fmt == 5'd8) begin
                tile_width_px = 32;
                tile_height_ln = 8;
                bytes_per_pixel = 1;
                plane_active_h = NV12_ACTIVE_H;
                plane_row_bytes = IMG_W;
            end else if (fmt == 5'd14) begin
                tile_width_px = 32;
                tile_height_ln = 4;
                bytes_per_pixel = 2;
                plane_active_h = G016_ACTIVE_H;
                plane_row_bytes = IMG_W * 2;
            end else if (fmt == 5'd15) begin
                plane_sel = 1;
                tile_width_px = 32;
                tile_height_ln = 4;
                bytes_per_pixel = 2;
                plane_active_h = G016_UV_ACTIVE_H;
                plane_row_bytes = IMG_W * 2;
            end else if ((fmt != 5'd0) && (fmt != 5'd1)) begin
                plane_sel = 1;
                tile_width_px = 16;
                tile_height_ln = 8;
                bytes_per_pixel = 2;
                plane_active_h = NV12_UV_ACTIVE_H;
                plane_row_bytes = IMG_W;
            end

            tile_row_bytes = tile_width_px * bytes_per_pixel;
            beats_per_tile_row = tile_row_bytes / 32;
            if (beats_per_tile_row <= 0)
                beats_per_tile_row = 1;
            row_in_tile = beat_idx / beats_per_tile_row;
            beat_in_row = beat_idx % beats_per_tile_row;
            row_abs = tile_y * tile_height_ln + row_in_tile;
            col_byte_base = tile_x * tile_row_bytes + beat_in_row * 32;

            data_local = {AXI_DW{1'b0}};
            for (byte_idx = 0; byte_idx < 32; byte_idx = byte_idx + 1) begin
                if ((row_abs < plane_active_h) && ((col_byte_base + byte_idx) < plane_row_bytes)) begin
                    src_byte_idx = row_abs * plane_row_bytes + col_byte_base + byte_idx;
                    if ((fmt == 5'd14) || (fmt == 5'd15)) begin
                        sample_byte_idx = (src_byte_idx / 2) * 2;
                        sample16 = {expected_linear_byte(plane_sel, sample_byte_idx + 1),
                                    expected_linear_byte(plane_sel, sample_byte_idx)};
                        sample16 = sample16 & 16'hffc0;
                        byte_local = (src_byte_idx[0] != 0) ? sample16[15:8] : sample16[7:0];
                    end else begin
                        byte_local = expected_linear_byte(plane_sel, src_byte_idx);
                    end
                    data_local[byte_idx*8 +: 8] = byte_local;
                end
            end

            pack_expected_linear_tile_axi_word = data_local;
        end
    endfunction

    function automatic [AXI_DW/8-1:0] expected_tile_axi_mask;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer beat_idx;
        integer tile_width_px;
        integer tile_height_ln;
        integer bytes_per_pixel;
        integer plane_active_h;
        integer plane_row_bytes;
        integer tile_row_bytes;
        integer beats_per_tile_row;
        integer row_in_tile;
        integer beat_in_row;
        integer row_abs;
        integer col_byte_base;
        integer byte_idx;
        reg [AXI_DW/8-1:0] mask_local;
        begin
            tile_width_px = 16;
            tile_height_ln = 4;
            bytes_per_pixel = 4;
            plane_active_h = CASE_ACTIVE_H;
            plane_row_bytes = IMG_W * 4;

            if (fmt == 5'd8) begin
                tile_width_px = 32;
                tile_height_ln = 8;
                bytes_per_pixel = 1;
                plane_active_h = NV12_ACTIVE_H;
                plane_row_bytes = IMG_W;
            end else if (fmt == 5'd14) begin
                tile_width_px = 32;
                tile_height_ln = 4;
                bytes_per_pixel = 2;
                plane_active_h = G016_ACTIVE_H;
                plane_row_bytes = IMG_W * 2;
            end else if (fmt == 5'd15) begin
                tile_width_px = 32;
                tile_height_ln = 4;
                bytes_per_pixel = 2;
                plane_active_h = G016_UV_ACTIVE_H;
                plane_row_bytes = IMG_W * 2;
            end else if ((fmt != 5'd0) && (fmt != 5'd1)) begin
                tile_width_px = 16;
                tile_height_ln = 8;
                bytes_per_pixel = 2;
                plane_active_h = NV12_UV_ACTIVE_H;
                plane_row_bytes = IMG_W;
            end

            tile_row_bytes = tile_width_px * bytes_per_pixel;
            beats_per_tile_row = tile_row_bytes / 32;
            if (beats_per_tile_row <= 0)
                beats_per_tile_row = 1;
            row_in_tile = beat_idx / beats_per_tile_row;
            beat_in_row = beat_idx % beats_per_tile_row;
            row_abs = tile_y * tile_height_ln + row_in_tile;
            col_byte_base = tile_x * tile_row_bytes + beat_in_row * 32;

            mask_local = {(AXI_DW/8){1'b0}};
            for (byte_idx = 0; byte_idx < (AXI_DW/8); byte_idx = byte_idx + 1) begin
                if ((row_abs < plane_active_h) && ((col_byte_base + byte_idx) < plane_row_bytes))
                    mask_local[byte_idx] = 1'b1;
            end
            expected_tile_axi_mask = mask_local;
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
                main_y_words64  = CASE_CMP0_WORDS64;
                main_uv_words64 = CASE_HAS_PLANE1 ? CASE_CMP1_WORDS64 : 0;
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
            end else if ((meta_ref_words_plane0 != 0) || (meta_ref_words_plane1 != 0)) begin
                meta_y_words64  = meta_ref_words_plane0;
                meta_uv_words64 = CASE_HAS_PLANE1 ? meta_ref_words_plane1 : 0;
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

    task automatic refresh_meta_ref_counts;
        integer idx;
        integer plane1_base_word_idx;
        begin
            meta_ref_words_plane0 = 0;
            meta_ref_active_words_plane0 = 0;
            for (idx = CASE_META0_WORDS64 - 1; idx >= 0; idx = idx - 1) begin
                if ((meta_ref_words_plane0 == 0) && (exp_meta_words[idx] !== 64'd0))
                    meta_ref_words_plane0 = idx + 1;
                if (exp_meta_words[idx] !== 64'd0)
                    meta_ref_active_words_plane0 = meta_ref_active_words_plane0 + 1;
            end

            meta_ref_words_plane1 = 0;
            meta_ref_active_words_plane1 = 0;
            if (CASE_HAS_PLANE1) begin
                plane1_base_word_idx = (CASE_META_BASE_UV_ADDR - CASE_META_BASE_MIN) >> 3;
                for (idx = CASE_META1_WORDS64 - 1; idx >= 0; idx = idx - 1) begin
                    if ((meta_ref_words_plane1 == 0) &&
                        (exp_meta_words[plane1_base_word_idx + idx] !== 64'd0))
                        meta_ref_words_plane1 = idx + 1;
                    if (exp_meta_words[plane1_base_word_idx + idx] !== 64'd0)
                        meta_ref_active_words_plane1 = meta_ref_active_words_plane1 + 1;
                end
            end

            meta_ref_words_total = meta_ref_words_plane0 +
                                   (CASE_HAS_PLANE1 ? meta_ref_words_plane1 : 0);
            meta_ref_active_words_total = meta_ref_active_words_plane0 +
                                          (CASE_HAS_PLANE1 ? meta_ref_active_words_plane1 : 0);
        end
    endtask

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
            for (idx = 0; idx < CASE_META0_WORDS64; idx = idx + 1)
                exp_meta_plane0_words[idx] = 64'd0;
            for (idx = 0; idx < CASE_META1_WORDS64; idx = idx + 1)
                exp_meta_plane1_words[idx] = 64'd0;
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

    task automatic load_dump64_to_meta_plane;
        input [8*256-1:0]        file_name;
        input integer            plane_sel;
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
                $display("[TB][ERROR] cannot open meta-plane reference file: %0s", file_name);
            end else begin
                idx = 0;
                while (!$feof(fd)) begin
                    line_buf_local = '0;
                    r = $fgets(line_buf_local, fd);
                    if (r != 0) begin
                        if ($sscanf(line_buf_local, "@%h", header_addr_local) == 1) begin
                        end else if ($sscanf(line_buf_local, "%h", word_local) == 1) begin
                            if (plane_sel != 0) begin
                                if (idx < CASE_META1_WORDS64)
                                    exp_meta_plane1_words[idx] = word_local;
                            end else begin
                                if (idx < CASE_META0_WORDS64)
                                    exp_meta_plane0_words[idx] = word_local;
                            end
                            idx = idx + 1;
                        end
                    end
                end
                $fclose(fd);

                if (idx != exp_word_count) begin
                    fail_count = fail_count + 1;
                    $display("[TB][ERROR] meta-plane word count mismatch file=%0s exp=%0d act=%0d",
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
                    end else if (exp_word != 64'd0) begin
                        for (byte_idx = 0; byte_idx < 8; byte_idx = byte_idx + 1) begin
                            if (actual_strb[lane_idx*8 + byte_idx] &&
                                ((is_meta != 0) ?
                                 (actual_data[lane_idx*64 + byte_idx*8 +: 5] !== exp_word[byte_idx*8 +: 5]) :
                                 (actual_data[lane_idx*64 + byte_idx*8 +: 8] !== exp_word[byte_idx*8 +: 8]))) begin
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
                report_first_mismatch_header("ENC_META_DUMP_OPEN",
                                             "post-sim meta dump compare");
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
                                report_first_mismatch_header("ENC_META_DUMP_BASE",
                                                             "post-sim meta dump compare");
                                $display("[TB][ERROR] dumped meta base mismatch file=%0s exp=0x%016x act=0x%016x",
                                         file_name, file_base_addr, header_addr_local);
                            end
                        end else if ($sscanf(line_buf_local, "%h", word_local) == 1) begin
                            curr_addr_local = file_base_addr + (idx * 8);
                            exp_word_local  = meta_ref_word64(curr_addr_local);
                            if ((exp_word_local !== 64'd0) &&
                                ((word_local & META_BYTE_CMP_MASK) !==
                                 (exp_word_local & META_BYTE_CMP_MASK))) begin
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
                                    report_first_mismatch_header("ENC_META_DUMP_DATA",
                                                                 "post-sim meta dump compare");
                                    $display("[TB][FIRST_MISMATCH]   file=%0s plane=%0d addr=0x%016x word_idx=%0d",
                                             file_name,
                                             plane_sel,
                                             curr_addr_local,
                                             idx);
                                    $display("[TB][FIRST_MISMATCH]   expected=0x%016x actual=0x%016x",
                                             exp_word_local,
                                             word_local);
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
                    report_first_mismatch_header("ENC_META_DUMP_WORD_COUNT",
                                                 "post-sim meta dump compare");
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
                                       tb_fake_mode_en ? CASE_FAKE_ACTIVE_META0_WORDS64 :
                                       ((meta_ref_words_plane0 != 0) ? meta_ref_words_plane0 : CASE_META0_WORDS64),
                                       1'b0,
                                       meta_dump_has_prev_addr,
                                       meta_dump_next_addr);
            end
            if (CASE_HAS_PLANE1 && (meta_dump_fd_plane1 != 0)) begin
                meta_dump_has_prev_addr = 1'b0;
                meta_dump_next_addr     = {AXI_AW{1'b0}};
                u_axi_mem.dump_range64(meta_dump_fd_plane1,
                                       CASE_META_BASE_UV_ADDR,
                                       tb_fake_mode_en ? CASE_FAKE_ACTIVE_META1_WORDS64 :
                                       ((meta_ref_words_plane1 != 0) ? meta_ref_words_plane1 : CASE_META1_WORDS64),
                                       1'b0,
                                       meta_dump_has_prev_addr,
                                       meta_dump_next_addr);
            end
        end
    endtask

    task automatic pulse_start_otf;
        begin
            wait (o_otf_ready == 1'b1);
            @(posedge otf_clk);
            start_otf = 1'b1;
            repeat (2) @(posedge otf_clk);
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
            expected_tile_count_local = CASE_ACTIVE_EXPECTED_TILES * completed_frames_exp;
            expected_beat_count_local = CASE_EXPECTED_BEATS * completed_frames_exp;
            if (tb_fake_mode_en) begin
                expected_meta_aw_local = CASE_FAKE_EXPECTED_META_AW * completed_frames_exp;
                expected_meta_w_local  = CASE_FAKE_EXPECTED_META_W * completed_frames_exp;
            end else begin
                expected_meta_aw_local = meta_ref_active_words_total * completed_frames_exp;
                expected_meta_w_local  = meta_ref_active_words_total * completed_frames_exp;
            end

            while ((settle_cycles < 64) && (timeout_count < case_timeout_cycles)) begin
                @(posedge clk);
                if (tb_fake_mode_en) begin
                    if ((otf_done_count >= completed_frames_exp) &&
                        (coord_count >= expected_tile_count_local) &&
                        (aw_count >= expected_tile_count_local) &&
                        (w_count >= fake_expected_beats_total) &&
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
                         ci_cmd_fire_w, rvi_mon_fire_w, dut.enc_axi_awvalid, dut.enc_axi_wvalid,
                         dut.meta_axi_awvalid, dut.meta_axi_wvalid, active_cmd_valid, rvi_active_cmd_valid,
                         main_burst_active, meta_burst_active);
                $display("[TB][ERROR] meta path state: data_vld=%0b data_rdy=%0b addr_vld=%0b addr_rdy=%0b data=0x%016x last_x=%0d",
                         dut.meta_data_valid,
                         dut.meta_data_ready,
                         dut.meta_addr_valid,
                         dut.meta_addr_ready,
                         dut.meta_data,
                         dut.meta_last_xcoord);
                $display("[TB][ERROR] meta path stall: enc_co_valid=%0b b_co_valid=%0b stall_cnt=%0d",
                         dut.enc_co_valid,
                         mon_b_co_valid,
                         meta_path_stall_count);
                $display("[TB][ERROR] addr cfg state: active=%0b invalid=%0b slot=%0b co_ready=%0b cfg0_valid=%0b cfg1_valid=%0b cfg0_cnt=%0d cfg1_cnt=%0d pop_sel=%0b push_sel=%0b",
                         dut.active_addr_cfg_valid,
                         dut.addr_cfg_invalid,
                         dut.b_tile_slot,
                         dut.enc_co_ready,
                         dut.ubwc_enc_apb_reg_blk.addr_cfg0_valid,
                         dut.ubwc_enc_apb_reg_blk.addr_cfg1_valid,
                         dut.ubwc_enc_apb_reg_blk.addr_cfg0_count,
                         dut.ubwc_enc_apb_reg_blk.addr_cfg1_count,
                         dut.ubwc_enc_apb_reg_blk.addr_cfg_pop_sel,
                         dut.ubwc_enc_apb_reg_blk.addr_cfg_push_sel);
                if (first_meta_path_stall_seen) begin
                    $display("[TB][ERROR] first meta path stall: fmt=%0d x=%0d y=%0d",
                             first_meta_path_stall_fmt,
                             first_meta_path_stall_x,
                             first_meta_path_stall_y);
                end
                $display("[TB][ERROR] meta path last tile: fmt=%0d x=%0d y=%0d meta_vld=%0b word_x=%0d addr=0x%016x",
                         dut.b_tile_format,
                         dut.b_tile_xcoord,
                         dut.b_tile_ycoord,
                         dut.meta_data_valid & dut.meta_addr_valid,
                         {dut.b_tile_xcoord[7:3], 3'b000},
                         dut.meta_addr);
                $display("[TB][ERROR] line_to_tile state: rd_state=%0d wr_bank=%0b rd_bank=%0b grp_y_cnt=%0d grp_y=%0d plane=%0b",
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_state,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.wr_bank_sel,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_bank_sel_act,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_tile_grp_y_cnt,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_group_y,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_plane);
                $display("[TB][ERROR] line_to_tile banks: b0(a_line=%0d b_line=%0d a_x=%0d b_x=%0d a_done=%0b b_done=%0b ready=%0b safe=%0b) b1(a_line=%0d b_line=%0d a_x=%0d b_x=%0d a_done=%0b b_done=%0b ready=%0b safe=%0b)",
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_a_line_idx,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_b_line_idx,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_a_tile_x,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_b_tile_x,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_a_done,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_b_done,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_ready_for_read,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_safe_for_read,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_a_line_idx,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_b_line_idx,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_a_tile_x,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_b_tile_x,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_a_done,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_b_done,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_ready_for_read,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_safe_for_read);
                $display("[TB][ERROR] packer state: in_empty=%0b a_vld=%0b a_rdy=%0b b_vld=%0b b_rdy=%0b a_cnt=%0d b_cnt=%0d write_seen=%0b",
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.in_fifo_empty,
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.fifo_a_vld,
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.fifo_a_rdy,
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.fifo_b_vld,
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.fifo_b_rdy,
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.a_pack32_cnt,
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.b_pack32_cnt,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.write_input_seen);
                $display("[TB][ERROR] packer sb: a32(fcnt=%0d lcnt=%0d) a64(fcnt=%0d lcnt=%0d) b32(fcnt=%0d lcnt=%0d) b64(fcnt=%0d lcnt=%0d)",
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.a_pack32_sb[17:14],
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.a_pack32_sb[13:2],
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.a_pack64_sb[17:14],
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.a_pack64_sb[13:2],
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.b_pack32_sb[17:14],
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.b_pack32_sb[13:2],
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.b_pack64_sb[17:14],
                         dut.ubwc_enc_otf_to_tile_inst.u_otf_data_packer.b_pack64_sb[13:2]);
                $display("[TB][ERROR] line_to_tile fire: a=%0b a_fcnt=%0d a_tlast=%0b b=%0b b_fcnt=%0d b_tlast=%0b bank_fcnt b0=%0d b1=%0d",
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.fire_a,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.a_fcnt,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.a_tlast,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.fire_b,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.b_fcnt,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.b_tlast,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_fcnt,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_fcnt);
                $display("[TB][ERROR] line_to_tile group: eff=%0b sel_vld=%0b sel_id=%0d a_lcnt=%0d a_gid=%0d a_ok=%0b b_lcnt=%0d b_gid=%0d b_ok=%0b b0(v=%0b id=%0d) b1(v=%0b id=%0d)",
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.wr_bank_sel_eff,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.sel_group_vld,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.sel_group_id,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.a_lcnt,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.a_group_id,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.fifo_a_group_ok,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.b_lcnt,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.b_group_id,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.fifo_b_group_ok,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_group_vld,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_group_id,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_group_vld,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_group_id);
                $display("[TB][ERROR] line_to_tile read: issue=%0b grant=%0b uv_allowed=%0b resp_af=%0b resp_empty=%0b resp_valid=%0b meta_af=%0b meta_empty=%0b meta_valid=%0b rd_addr=%0d rd_word=%0d tile_x=%0d last_col=%0b last_word=%0b data_vld=%0b dout_vld=%0b pending0=%0d pending1=%0d tile_rdy=%0b",
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.issue_read,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.read_grant,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_uv_read_allowed,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.resp_fifo_almost_full,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.resp_fifo_empty,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.resp_fifo_valid,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.read_meta_fifo_almost_full,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.read_meta_fifo_empty,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.read_meta_fifo_valid,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_read_addr,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_word_in_tile,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_tile_x,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_last_col,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.last_word_in_tile,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.read_data_vld,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.read_meta_bank_dout_vld,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank0_read_pending_count,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.bank1_read_pending_count,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.i_tile_rdy);
                $fatal(1, "Encoder wrapper did not become idle before next frame start.");
            end

            repeat (16) @(posedge clk);
        end
    endtask

    task automatic apb_write;
        input [APB_AW-1:0] addr;
        input [APB_DW-1:0] data;
        begin
            @(posedge pclk);
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b1;
            PADDR   <= addr;
            PWDATA  <= data;
            @(posedge pclk);
            PENABLE <= 1'b1;
            @(posedge pclk);
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
            PADDR   <= {APB_AW{1'b0}};
            PWDATA  <= {APB_DW{1'b0}};
        end
    endtask

    task automatic program_addr_cfg_once;
        begin
            apb_write(16'h0030, CASE_META_BASE_Y_ADDR[31:0]);
            apb_write(16'h0034, CASE_META_BASE_Y_ADDR[63:32]);
            apb_write(16'h0038, CASE_TILE_BASE_Y_ADDR[31:0]);
            apb_write(16'h003c, CASE_TILE_BASE_Y_ADDR[63:32]);
            apb_write(16'h0040, CASE_META_BASE_UV_ADDR[31:0]);
            apb_write(16'h0044, CASE_META_BASE_UV_ADDR[63:32]);
            apb_write(16'h0048, CASE_TILE_BASE_UV_ADDR[31:0]);
            apb_write(16'h004c, CASE_TILE_BASE_UV_ADDR[63:32]);
        end
    endtask

    task automatic program_wrapper_regs;
        reg [31:0] reg2_data;
        reg [31:0] reg3_data;
        reg [31:0] reg4_data;
        reg [31:0] reg5_data;
        reg [31:0] reg6_data;
        reg [31:0] reg7_data;
        reg [31:0] reg8_data;
        reg [31:0] reg9_data;
        reg [31:0] reg10_data;
        reg [31:0] reg11_data;
        reg [31:0] reg20_data;
        reg [31:0] reg21_data;
        integer addr_cfg_idx;
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
            reg3_data[1]      = (CASE_IS_LOSSY_RGBA_2_1 != 0);
            reg3_data[26:16]  = CASE_PITCH_UNITS[10:0];

            reg4_data = 32'd0;
            reg4_data[0]      = 1'b1;
            reg4_data[10:8]   = 3'd7;
            reg4_data[20:16]  = CASE_CI_FMT[4:0];
            reg4_data[24]     = 1'b0;

            reg5_data = 32'd0;
            reg5_data[16]     = (CASE_CI_LOSSY != 0);

            reg6_data = 32'd0;
            reg6_data[2:0]    = CASE_UBWC_CFG_0;
            reg6_data[5:3]    = CASE_UBWC_CFG_1;
            reg6_data[9:6]    = CASE_UBWC_CFG_2;
            reg6_data[13:10]  = CASE_UBWC_CFG_3;
            reg6_data[17:14]  = CASE_UBWC_CFG_4;
            reg6_data[21:18]  = CASE_UBWC_CFG_5;
            reg6_data[23:22]  = CASE_UBWC_CFG_6;
            reg6_data[25:24]  = CASE_UBWC_CFG_7;
            reg6_data[27:26]  = CASE_UBWC_CFG_8;
            reg6_data[30:28]  = CASE_UBWC_CFG_9;

            reg7_data = 32'd0;
            reg7_data[5:0]    = CASE_UBWC_CFG_10;
            reg7_data[13:8]   = CASE_UBWC_CFG_11;

            reg8_data = 32'd0;
            reg8_data[2:0]    = CASE_OTF_FMT[2:0];

            reg9_data  = {CASE_STORED_H[15:0], IMG_W[15:0]};
            reg10_data = {CASE_TILE_H[15:0], CASE_TILE_W[15:0]};
            reg11_data = {CASE_B_TILE_COLS[15:0], CASE_A_TILE_COLS[15:0]};
            reg20_data = CASE_HAS_PLANE1 ? {(CASE_IS_G016 ? G016_ACTIVE_H[15:0] : NV12_ACTIVE_H[15:0]), IMG_W[15:0]}
                                         : {RGBA_ACTIVE_H[15:0], IMG_W[15:0]};
            reg21_data = CASE_META_PITCH_BYTES[31:0];

            apb_write(16'h000c, reg3_data);
            apb_write(16'h0008, reg2_data);
            for (addr_cfg_idx = 0;
                 addr_cfg_idx < ((tb_frame_repeat < 8) ? tb_frame_repeat : 8);
                 addr_cfg_idx = addr_cfg_idx + 1) begin
                program_addr_cfg_once();
            end
            apb_write(16'h0014, reg5_data);
            apb_write(16'h0018, reg6_data);
            apb_write(16'h001c, reg7_data);
            apb_write(16'h0010, reg4_data);
            apb_write(16'h0024, reg9_data);
            apb_write(16'h0028, reg10_data);
            apb_write(16'h002c, reg11_data);
            apb_write(16'h0050, reg20_data);
            apb_write(16'h0054, reg21_data);
            apb_write(16'h0020, reg8_data);
        end
    endtask

    task automatic program_frame_start;
        begin
            apb_write(16'h0060, 32'h0000_0021);
        end
    endtask

    ubwc_enc_wrapper_top #(
        .SB_WIDTH    (SB_WIDTH),
        .APB_AW      (APB_AW),
        .APB_DW      (APB_DW),
        .AXI_AW      (AXI_AW),
        .AXI_DW      (M_AXI_DW),
        .AXI_LENW    (AXI_LENW),
        .AXI_IDW     (AXI_IDW),
        .COM_BUF_AW  (COM_BUF_AW),
        .COM_BUF_DW  (COM_BUF_DW),
        .ENC_VIVO_FAKE_MODEL_EN           (1),
        .ENC_VIVO_FAKE_TILE_EXPECT_LINEAR (CASE_TILE_EXPECT_LINEAR),
        .ENC_VIVO_FAKE_IMG_W              (IMG_W),
        .ENC_VIVO_FAKE_RGBA_ACTIVE_H      (RGBA_ACTIVE_H),
        .ENC_VIVO_FAKE_RGBA_TILE_PITCH    (RGBA_TILE_PITCH),
        .ENC_VIVO_FAKE_RGBA_TILE_COLS     (RGBA_TILE_COLS),
        .ENC_VIVO_FAKE_RGBA_TILE_ROWS     (RGBA_TILE_ROWS),
        .ENC_VIVO_FAKE_NV12_ACTIVE_H      (NV12_ACTIVE_H),
        .ENC_VIVO_FAKE_NV12_UV_ACTIVE_H   (NV12_UV_ACTIVE_H),
        .ENC_VIVO_FAKE_NV12_TILE_PITCH    (NV12_TILE_PITCH),
        .ENC_VIVO_FAKE_NV12_Y_TILE_COLS   (NV12_Y_TILE_COLS),
        .ENC_VIVO_FAKE_NV12_UV_TILE_COLS  (NV12_UV_TILE_COLS),
        .ENC_VIVO_FAKE_NV12_Y_TILE_ROWS   (NV12_Y_TILE_ROWS),
        .ENC_VIVO_FAKE_NV12_UV_TILE_ROWS  (NV12_UV_TILE_ROWS),
        .ENC_VIVO_FAKE_G016_ACTIVE_H      (G016_ACTIVE_H),
        .ENC_VIVO_FAKE_G016_UV_ACTIVE_H   (G016_UV_ACTIVE_H),
        .ENC_VIVO_FAKE_G016_TILE_PITCH    (G016_TILE_PITCH),
        .ENC_VIVO_FAKE_G016_Y_TILE_COLS   (G016_Y_TILE_COLS),
        .ENC_VIVO_FAKE_G016_UV_TILE_COLS  (G016_UV_TILE_COLS),
        .ENC_VIVO_FAKE_G016_Y_TILE_ROWS   (G016_Y_TILE_ROWS),
        .ENC_VIVO_FAKE_G016_UV_TILE_ROWS  (G016_UV_TILE_ROWS),
        .ENC_VIVO_FAKE_META_PITCH_BYTES   (CASE_META_PITCH_BYTES),
        .ENC_VIVO_FAKE_TILE_BASE_Y_ADDR   (CASE_TILE_BASE_Y_ADDR),
        .ENC_VIVO_FAKE_TILE_BASE_UV_ADDR  (CASE_TILE_BASE_UV_ADDR),
        .ENC_VIVO_FAKE_META_BASE_Y_ADDR   (CASE_META_BASE_Y_ADDR),
        .ENC_VIVO_FAKE_META_BASE_UV_ADDR  (CASE_META_BASE_UV_ADDR),
        .ENC_VIVO_FAKE_TILE0_WORDS64      (CASE_TILE0_FILE_WORDS64),
        .ENC_VIVO_FAKE_TILE1_WORDS64      (CASE_TILE1_FILE_WORDS64),
        .ENC_VIVO_FAKE_CMP0_WORDS64       (CASE_CMP0_WORDS64),
        .ENC_VIVO_FAKE_CMP1_WORDS64       (CASE_CMP1_WORDS64),
        .ENC_VIVO_FAKE_META0_WORDS64      (CASE_META0_WORDS64),
        .ENC_VIVO_FAKE_META1_WORDS64      (CASE_META1_WORDS64)
    ) dut (
        .PCLK            (pclk),
        .PRESETn         (rst_n),
        .PSEL            (PSEL),
        .PENABLE         (PENABLE),
        .PADDR           (PADDR),
        .PWRITE          (PWRITE),
        .PWDATA          (PWDATA),
        .PREADY          (PREADY),
        .PSLVERR         (PSLVERR),
        .PRDATA          (PRDATA),
        .i_axi_clk       (clk),
        .i_otf_clk       (otf_clk),
        .i_vivo_clk      (vivo_clk),
        .i_axi_rstn      (rst_n),
        .i_otf_rstn      (rst_n),
        .i_vivo_rstn     (rst_n),
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
        .o_m_axi_bready  (o_m_axi_bready),
        .o_stage_done    (o_stage_done),
        .o_frame_done    (o_frame_done),
        .o_irq           (o_irq)
    );

    tb_ubwc_enc_wrapper_top_monitor #(
        .AXI_AW (AXI_AW)
    ) u_monitor (
        .meta_data_valid          (dut.meta_data_valid),
        .meta_data_ready          (dut.meta_data_ready),
        .meta_data                (dut.meta_data),
        .meta_addr_valid          (dut.meta_addr_valid),
        .meta_addr_ready          (dut.meta_addr_ready),
        .meta_addr                (dut.meta_addr),
        .meta_uv_base_offset_addr (dut.meta_uv_base_offset_addr0),
        .meta_axi_awvalid         (dut.meta_axi_awvalid),
        .meta_axi_awready         (dut.meta_axi_awready),
        .meta_axi_awaddr          (dut.meta_axi_awaddr),
        .b_tile_info_vld          (dut.enc_co_valid),
        .enc_co_ready             (dut.enc_co_ready),
        .otf_tile_last            (dut.ubwc_enc_otf_to_tile_inst.o_tile_last),
        .otf_tile_fcnt            (dut.ubwc_enc_otf_to_tile_inst.o_tile_fcnt),
        .err_bline                (dut.ubwc_enc_otf_to_tile_inst.o_err_bline),
        .err_bframe               (dut.ubwc_enc_otf_to_tile_inst.o_err_bframe),
        .meta_valid               (mon_meta_valid),
        .meta_ready               (mon_meta_ready),
        .meta_last                (mon_meta_last),
        .meta_sel_y               (mon_meta_sel_y),
        .meta_sel_uv              (mon_meta_sel_uv),
        .y_meta_valid             (mon_y_meta_valid),
        .y_meta_last              (mon_y_meta_last),
        .y_meta_ready             (mon_y_meta_ready),
        .y_meta_data              (mon_y_meta_data),
        .y_meta_addr              (mon_y_meta_addr),
        .uv_meta_valid            (mon_uv_meta_valid),
        .uv_meta_last             (mon_uv_meta_last),
        .uv_meta_ready            (mon_uv_meta_ready),
        .uv_meta_data             (mon_uv_meta_data),
        .uv_meta_addr             (mon_uv_meta_addr),
        .meta_aw_fire             (mon_meta_aw_fire),
        .meta_aw_sel_uv           (mon_meta_aw_sel_uv),
        .meta_aw_y_addr           (mon_meta_aw_y_addr),
        .meta_aw_uv_addr          (mon_meta_aw_uv_addr),
        .b_co_valid               (mon_b_co_valid),
        .b_co_fire                (),
        .dbg_otf_tile_last        (dbg_otf_to_tile_last),
        .dbg_otf_tile_fcnt        (dbg_otf_to_tile_fcnt),
        .dbg_err_bline            (mon_err_bline),
        .dbg_err_bframe           (mon_err_bframe)
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
        .clk        (otf_clk),
        .rst_n      (rst_n),
        .start      (start_otf),
        .done       (otf_done),
        .error_flag (otf_error),
        .img_width  (IMG_W[15:0]),
        .img_height (CASE_ACTIVE_H[15:0]),
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
        .AXI_DATA_WIDTH (M_AXI_DW),
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
    assign dbg_otf_to_tile_coord_vld = ci_cmd_fire_w;
    assign dbg_otf_to_tile_x         = dut.ubwc_enc_otf_to_tile_inst.line_tile_x;
    assign dbg_otf_to_tile_y         = dut.ubwc_enc_otf_to_tile_inst.line_tile_y;
    assign dbg_otf_to_tile_format    = dut.ubwc_enc_otf_to_tile_inst.line_tile_format;
    assign meta_aw_fire_w            = dut.meta_axi_awvalid && dut.meta_axi_awready;
    assign meta_w_fire_w             = dut.meta_axi_wvalid && dut.meta_axi_wready;
    assign meta_use_curr_aw_w        = meta_aw_fire_w && !meta_burst_active;
    assign meta_write_beat_addr_w    = meta_use_curr_aw_w ? dut.meta_axi_awaddr : meta_burst_addr;
    assign meta_write_underflow_w    = meta_w_fire_w && !meta_burst_active && !meta_use_curr_aw_w;
    assign ci_cmd_fire_w             = dut.ubwc_enc_otf_to_tile_inst.ci_fifo_wr_en;
    assign fake_vivo_ci_fire_w       = dut.enc_ci_valid && dut.enc_ci_ready;
    assign fake_vivo_ci_active_w     = (dut.enc_ci_tile_xcoord <
                                        expected_tile_active_cols(dut.tile_format)) &&
                                       (dut.enc_ci_tile_ycoord <
                                        expected_tile_active_rows(dut.tile_format));
    assign fake_vivo_co_meta_byte_w  = expected_meta_byte(dut.tile_format,
                                                          dut.enc_ci_tile_xcoord,
                                                          dut.enc_ci_tile_ycoord);
    assign fake_vivo_co_metadata_w   = fake_vivo_ci_active_w ? fake_vivo_co_meta_byte_w : 8'd0;
    assign rvi_mon_fire_w            = dut.rvi_valid && dut.rvi_ready;
    assign rvi_mon_data_w            = dut.rvi_data;
    assign rvi_mon_mask_w            = dut.rvi_mask;
    assign rvi_exp_data_w            = rvi_active_cmd_valid ?
                                       pack_expected_tile_axi_word(rvi_active_cmd_fmt,
                                                                   rvi_active_cmd_x,
                                                                   rvi_active_cmd_y,
                                                                   rvi_beat_idx) :
                                       pack_expected_tile_axi_word(dut.rvi_tile_format,
                                                                   dut.rvi_tile_xcoord,
                                                                   dut.rvi_tile_ycoord,
                                                                   0);
    assign rvi_exp_mask_w            = rvi_active_cmd_valid ?
                                       expected_tile_axi_mask(rvi_active_cmd_fmt,
                                                              rvi_active_cmd_x,
                                                              rvi_active_cmd_y,
                                                              rvi_beat_idx) :
                                       expected_tile_axi_mask(dut.rvi_tile_format,
                                                              dut.rvi_tile_xcoord,
                                                              dut.rvi_tile_ycoord,
                                                              0);
    assign rvi_exp_last_w            = rvi_active_cmd_valid ? (rvi_beat_idx == 7) : 1'b0;
    assign cvo_start_direct_w        = tb_fake_mode_en ? 1'b0 :
                                       (dut.enc_axi_awvalid && dut.enc_axi_awready &&
                                        dut.enc_cvo_valid && dut.enc_cvo_ready &&
                                        !cvo_active_cmd_valid &&
                                        (cvo_cmd_rd_ptr >= cvo_cmd_wr_ptr));
    assign tb_output_activity        = ci_cmd_fire_w || rvi_mon_fire_w ||
                                       dut.enc_axi_awvalid || dut.enc_axi_wvalid ||
                                       dut.meta_axi_awvalid || dut.meta_axi_wvalid ||
                                       active_cmd_valid || rvi_active_cmd_valid ||
                                       main_burst_active || meta_burst_active;

    always @(*) begin
        fake_cvo_drv_valid = fake_cvo_drv_cmd_valid_w;
    end

    always @(*) begin
        fake_cvo_drv_cmd_valid_w = (fake_cvo_drv_rd_ptr < cvo_cmd_wr_ptr);
        fake_cvo_drv_addr_w      = {AXI_AW{1'b0}};
        fake_cvo_drv_data_w      = {AXI_DW{1'b0}};
        fake_cvo_drv_mask_w      = 32'd0;
        fake_cvo_drv_last_w      = 1'b0;

        if (fake_cvo_drv_cmd_valid_w && (fake_cvo_drv_rd_ptr < TILE_QUEUE_CAPACITY)) begin
            fake_cvo_drv_addr_w = cvo_addr_queue[fake_cvo_drv_rd_ptr] +
                                  (fake_cvo_drv_beat_idx * (AXI_DW/8));
            fake_cvo_drv_data_w = pack_main_ref_axi_word(fake_cvo_drv_addr_w);
            if (fake_cvo_drv_beat_idx < cvo_valid_beats_queue[fake_cvo_drv_rd_ptr])
                fake_cvo_drv_mask_w = 32'hFFFF_FFFF;
            fake_cvo_drv_last_w = (fake_cvo_drv_beat_idx ==
                                  (cvo_beats_queue[fake_cvo_drv_rd_ptr] - 1));
        end
    end

    always @(*) begin
        cvo_expect_valid_w       = 1'b0;
        cvo_expect_direct_w      = 1'b0;
        cvo_expect_queue_w       = 1'b0;
        cvo_expect_fmt_w         = 5'd0;
        cvo_expect_x_w           = 16'd0;
        cvo_expect_y_w           = 16'd0;
        cvo_expect_base_addr_w   = {AXI_AW{1'b0}};
        cvo_expect_addr_w        = {AXI_AW{1'b0}};
        cvo_expect_data_w        = {AXI_DW{1'b0}};
        cvo_expect_mask_w        = 32'd0;
        cvo_expect_last_w        = 1'b0;
        cvo_expect_beat_w        = 4'd0;
        cvo_expect_beats_w       = 4'd1;
        cvo_expect_valid_beats_w = 4'd1;

        if (cvo_active_cmd_valid) begin
            cvo_expect_valid_w       = 1'b1;
            cvo_expect_fmt_w         = cvo_active_cmd_fmt;
            cvo_expect_x_w           = cvo_active_cmd_x;
            cvo_expect_y_w           = cvo_active_cmd_y;
            cvo_expect_base_addr_w   = cvo_active_cmd_addr;
            cvo_expect_beat_w        = cvo_beat_idx[3:0];
            cvo_expect_beats_w       = cvo_active_cmd_beats;
            cvo_expect_valid_beats_w = cvo_active_valid_beats;
        end else if (cvo_start_direct_w) begin
            cvo_expect_valid_w       = 1'b1;
            cvo_expect_direct_w      = 1'b1;
            cvo_expect_base_addr_w   = dut.enc_axi_awaddr;
            cvo_expect_beats_w       = {1'b0, dut.enc_axi_awlen[2:0]} + 4'd1;
            cvo_expect_valid_beats_w = {1'b0, dut.enc_axi_awlen[2:0]} + 4'd1;
        end else if ((cvo_cmd_rd_ptr < cvo_cmd_wr_ptr) &&
                     (cvo_cmd_rd_ptr < TILE_QUEUE_CAPACITY)) begin
            cvo_expect_valid_w       = 1'b1;
            cvo_expect_queue_w       = 1'b1;
            cvo_expect_fmt_w         = cvo_fmt_queue[cvo_cmd_rd_ptr];
            cvo_expect_x_w           = cvo_x_queue[cvo_cmd_rd_ptr];
            cvo_expect_y_w           = cvo_y_queue[cvo_cmd_rd_ptr];
            cvo_expect_base_addr_w   = cvo_addr_queue[cvo_cmd_rd_ptr];
            cvo_expect_beats_w       = cvo_beats_queue[cvo_cmd_rd_ptr];
            cvo_expect_valid_beats_w = cvo_valid_beats_queue[cvo_cmd_rd_ptr];
        end

        cvo_expect_addr_w = cvo_expect_base_addr_w +
                            ({60'd0, cvo_expect_beat_w} << 5);
        cvo_expect_data_w = pack_main_ref_axi_word(cvo_expect_addr_w);
        if (cvo_expect_beat_w < cvo_expect_valid_beats_w)
            cvo_expect_mask_w = 32'hFFFF_FFFF;
        cvo_expect_last_w = (cvo_expect_beat_w == (cvo_expect_beats_w - 4'd1));
    end

    always @(*) begin
        lossy_aw_expected_valid_w = 1'b0;
        lossy_aw_expected_split_w = 1'b0;
        lossy_aw_expected_addr_w  = {AXI_AW{1'b0}};
        lossy_aw_expected_len_w   = {AXI_LENW{1'b0}};
        lossy_aw_expected_beats_w = {(AXI_LENW+1){1'b0}};
        lossy_aw_second_addr_w    = {AXI_AW{1'b0}};
        lossy_aw_second_beats_w   = {(AXI_LENW+1){1'b0}};
        lossy_aw_expected_fmt_w   = 5'd0;
        lossy_aw_expected_x_w     = 16'd0;
        lossy_aw_expected_y_w     = 16'd0;
        lossy_aw_total_beats_i    = 0;
        lossy_aw_bytes_to_4k_i    = 0;
        lossy_aw_first_beats_i    = 0;
        lossy_aw_second_beats_i   = 0;

        if (lossy_aw_split_pending) begin
            lossy_aw_expected_valid_w = 1'b1;
            lossy_aw_expected_addr_w  = lossy_aw_split_addr;
            lossy_aw_expected_beats_w = lossy_aw_split_beats;
            lossy_aw_expected_fmt_w   = lossy_aw_split_fmt;
            lossy_aw_expected_x_w     = lossy_aw_split_x;
            lossy_aw_expected_y_w     = lossy_aw_split_y;
        end else if ((cmd_rd_ptr < cmd_wr_ptr) &&
                     (cmd_rd_ptr < TILE_QUEUE_CAPACITY)) begin
            lossy_aw_expected_valid_w = 1'b1;
            lossy_aw_expected_addr_w  = cmd_addr_queue[cmd_rd_ptr];
            lossy_aw_expected_fmt_w   = cmd_fmt_queue[cmd_rd_ptr];
            lossy_aw_expected_x_w     = cmd_x_queue[cmd_rd_ptr];
            lossy_aw_expected_y_w     = cmd_y_queue[cmd_rd_ptr];
            lossy_aw_total_beats_i    = cmd_alen_queue[cmd_rd_ptr] + 1;
            lossy_aw_bytes_to_4k_i    = 4096 - cmd_addr_queue[cmd_rd_ptr][11:0];
            if ((cmd_addr_queue[cmd_rd_ptr][11:0] +
                 (lossy_aw_total_beats_i << 5)) > 4096)
                lossy_aw_first_beats_i = (lossy_aw_bytes_to_4k_i + 31) >> 5;
            else
                lossy_aw_first_beats_i = lossy_aw_total_beats_i;
            lossy_aw_second_beats_i   = lossy_aw_total_beats_i - lossy_aw_first_beats_i;
            lossy_aw_expected_beats_w = lossy_aw_first_beats_i;
            lossy_aw_second_beats_w   = lossy_aw_second_beats_i;
            lossy_aw_second_addr_w    = cmd_addr_queue[cmd_rd_ptr] +
                                        (lossy_aw_first_beats_i << 5);
            lossy_aw_expected_split_w = (lossy_aw_second_beats_i != 0);
        end

        if (lossy_aw_expected_valid_w)
            lossy_aw_expected_len_w = lossy_aw_expected_beats_w[AXI_LENW-1:0] -
                                      {{(AXI_LENW-1){1'b0}}, 1'b1};
    end

    always @(posedge vivo_clk or negedge rst_n) begin
        if (!rst_n) begin
            fake_cvo_drv_rd_ptr   <= 0;
            fake_cvo_drv_beat_idx <= 0;
        end else if (!tb_fake_mode_en) begin
            fake_cvo_drv_rd_ptr   <= 0;
            fake_cvo_drv_beat_idx <= 0;
        end else if (fake_cvo_drv_cmd_valid_w && dut.enc_cvo_valid && dut.enc_cvo_ready) begin
            if (fake_cvo_drv_last_w) begin
                fake_cvo_drv_rd_ptr   <= fake_cvo_drv_rd_ptr + 1;
                fake_cvo_drv_beat_idx <= 0;
            end else begin
                fake_cvo_drv_beat_idx <= fake_cvo_drv_beat_idx + 1;
            end
        end
    end

    always @(posedge vivo_clk or negedge rst_n) begin
        if (!rst_n) begin
            vivo_ci_mismatch_count          <= 0;
            first_vivo_ci_mismatch_seen     <= 1'b0;
            first_vivo_ci_mismatch_fmt      <= 5'd0;
            first_vivo_ci_mismatch_x        <= 16'd0;
            first_vivo_ci_mismatch_y        <= 16'd0;
            first_vivo_ci_expected_metadata <= 8'd0;
            first_vivo_ci_actual_metadata   <= 8'd0;
            first_vivo_ci_expected_alen     <= 3'd0;
            first_vivo_ci_actual_alen       <= 3'd0;
            first_vivo_ci_expected_pcm      <= 1'b0;
            first_vivo_ci_actual_pcm        <= 1'b0;
            rvi_beat_count                  <= 0;
            rvi_beat_idx                    <= 0;
            rvi_data_mismatch_count         <= 0;
            rvi_mask_mismatch_count         <= 0;
            rvi_last_mismatch_count         <= 0;
            rvi_coord_mismatch_count        <= 0;
            rvi_active_cmd_valid            <= 1'b0;
            rvi_active_cmd_fmt              <= 5'd0;
            rvi_active_cmd_x                <= 16'd0;
            rvi_active_cmd_y                <= 16'd0;
            first_rvi_data_mismatch_seen    <= 1'b0;
            first_rvi_data_fmt              <= 5'd0;
            first_rvi_data_x                <= 16'd0;
            first_rvi_data_y                <= 16'd0;
            first_rvi_data_beat             <= 0;
            first_rvi_data_expected         <= {AXI_DW{1'b0}};
            first_rvi_data_actual           <= {AXI_DW{1'b0}};
            first_rvi_mask_mismatch_seen    <= 1'b0;
            first_rvi_mask_fmt              <= 5'd0;
            first_rvi_mask_x                <= 16'd0;
            first_rvi_mask_y                <= 16'd0;
            first_rvi_mask_beat             <= 0;
            first_rvi_mask_expected         <= 32'd0;
            first_rvi_mask_actual           <= 32'd0;
            first_rvi_last_mismatch_seen    <= 1'b0;
            first_rvi_last_fmt              <= 5'd0;
            first_rvi_last_x                <= 16'd0;
            first_rvi_last_y                <= 16'd0;
            first_rvi_last_beat             <= 0;
            first_rvi_last_expected         <= 1'b0;
            first_rvi_last_actual           <= 1'b0;
            first_rvi_coord_mismatch_seen   <= 1'b0;
            first_rvi_coord_exp_fmt         <= 5'd0;
            first_rvi_coord_exp_x           <= 16'd0;
            first_rvi_coord_exp_y           <= 16'd0;
            first_rvi_coord_act_fmt         <= 5'd0;
            first_rvi_coord_act_x           <= 16'd0;
            first_rvi_coord_act_y           <= 16'd0;
            first_rvi_coord_beat            <= 0;
        end else begin
            if (fake_vivo_ci_fire_w) begin : vivo_ci_checker_block
                reg [7:0] vivo_ci_exp_metadata;
                reg [2:0] vivo_ci_exp_alen;
                reg       vivo_ci_exp_pcm;

                vivo_ci_exp_alen     = 3'd7;
                vivo_ci_exp_metadata = {4'h1, vivo_ci_exp_alen, 1'b0};
                vivo_ci_exp_pcm      = expected_ci_forced_pcm(dut.tile_format,
                                                              dut.enc_ci_tile_xcoord,
                                                              dut.enc_ci_tile_ycoord);
                if ((dut.enc_ci_metadata !== vivo_ci_exp_metadata) ||
                    (dut.enc_ci_alen !== vivo_ci_exp_alen) ||
                    (dut.enc_ci_forced_pcm !== vivo_ci_exp_pcm)) begin
                    vivo_ci_mismatch_count <= vivo_ci_mismatch_count + 1;
                    if (!first_vivo_ci_mismatch_seen) begin
                        first_vivo_ci_mismatch_seen     <= 1'b1;
                        first_vivo_ci_mismatch_fmt      <= dut.tile_format;
                        first_vivo_ci_mismatch_x        <= dut.enc_ci_tile_xcoord;
                        first_vivo_ci_mismatch_y        <= dut.enc_ci_tile_ycoord;
                        first_vivo_ci_expected_metadata <= vivo_ci_exp_metadata;
                        first_vivo_ci_actual_metadata   <= dut.enc_ci_metadata;
                        first_vivo_ci_expected_alen     <= vivo_ci_exp_alen;
                        first_vivo_ci_actual_alen       <= dut.enc_ci_alen;
                        first_vivo_ci_expected_pcm      <= vivo_ci_exp_pcm;
                        first_vivo_ci_actual_pcm        <= dut.enc_ci_forced_pcm;
                        report_first_mismatch_header("ENC_CI_INPUT",
                                                     "u_core.dut.ubwc_enc_vivo_top_inst.i_ci_*");
                        $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d",
                                 dut.tile_format,
                                 dut.enc_ci_tile_xcoord,
                                 dut.enc_ci_tile_ycoord);
                        $display("[TB][FIRST_MISMATCH]   metadata exp=0x%02x act=0x%02x alen exp=%0d act=%0d pcm exp=%0d act=%0d",
                                 vivo_ci_exp_metadata,
                                 dut.enc_ci_metadata,
                                 vivo_ci_exp_alen,
                                 dut.enc_ci_alen,
                                 vivo_ci_exp_pcm,
                                 dut.enc_ci_forced_pcm);
                    end
                end
            end

            if (rvi_mon_fire_w) begin
                rvi_beat_count <= rvi_beat_count + 1;

                if (masked_axi_word_mismatch(rvi_mon_data_w,
                                             rvi_mon_mask_w,
                                             rvi_exp_data_w)) begin
                    rvi_data_mismatch_count <= rvi_data_mismatch_count + 1;
                    if (!first_rvi_data_mismatch_seen) begin
                        first_rvi_data_mismatch_seen <= 1'b1;
                        first_rvi_data_fmt           <= rvi_active_cmd_valid ? rvi_active_cmd_fmt : dut.rvi_tile_format;
                        first_rvi_data_x             <= rvi_active_cmd_valid ? rvi_active_cmd_x : dut.rvi_tile_xcoord;
                        first_rvi_data_y             <= rvi_active_cmd_valid ? rvi_active_cmd_y : dut.rvi_tile_ycoord;
                        first_rvi_data_beat          <= rvi_active_cmd_valid ? rvi_beat_idx : 0;
                        first_rvi_data_expected      <= rvi_exp_data_w;
                        first_rvi_data_actual        <= rvi_mon_data_w;
                        report_first_mismatch_header("ENC_RVI_DATA",
                                                     "u_core.dut.ubwc_enc_vivo_top_inst.i_rvi_data");
                        $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d beat=%0d mask=0x%08x",
                                 rvi_active_cmd_valid ? rvi_active_cmd_fmt : dut.rvi_tile_format,
                                 rvi_active_cmd_valid ? rvi_active_cmd_x   : dut.rvi_tile_xcoord,
                                 rvi_active_cmd_valid ? rvi_active_cmd_y   : dut.rvi_tile_ycoord,
                                 rvi_active_cmd_valid ? rvi_beat_idx       : 0,
                                 rvi_mon_mask_w);
                        $display("[TB][FIRST_MISMATCH]   expected=0x%064x", rvi_exp_data_w);
                        $display("[TB][FIRST_MISMATCH]   actual  =0x%064x", rvi_mon_data_w);
                    end
                end

                if (rvi_mon_mask_w !== rvi_exp_mask_w) begin
                    rvi_mask_mismatch_count <= rvi_mask_mismatch_count + 1;
                    if (!first_rvi_mask_mismatch_seen) begin
                        first_rvi_mask_mismatch_seen <= 1'b1;
                        first_rvi_mask_fmt           <= rvi_active_cmd_valid ? rvi_active_cmd_fmt : dut.rvi_tile_format;
                        first_rvi_mask_x             <= rvi_active_cmd_valid ? rvi_active_cmd_x : dut.rvi_tile_xcoord;
                        first_rvi_mask_y             <= rvi_active_cmd_valid ? rvi_active_cmd_y : dut.rvi_tile_ycoord;
                        first_rvi_mask_beat          <= rvi_active_cmd_valid ? rvi_beat_idx : 0;
                        first_rvi_mask_expected      <= rvi_exp_mask_w;
                        first_rvi_mask_actual        <= rvi_mon_mask_w;
                        report_first_mismatch_header("ENC_RVI_MASK",
                                                     "u_core.dut.ubwc_enc_vivo_top_inst.i_rvi_mask");
                        $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d beat=%0d mask exp=0x%08x act=0x%08x",
                                 rvi_active_cmd_valid ? rvi_active_cmd_fmt : dut.rvi_tile_format,
                                 rvi_active_cmd_valid ? rvi_active_cmd_x   : dut.rvi_tile_xcoord,
                                 rvi_active_cmd_valid ? rvi_active_cmd_y   : dut.rvi_tile_ycoord,
                                 rvi_active_cmd_valid ? rvi_beat_idx       : 0,
                                 rvi_exp_mask_w,
                                 rvi_mon_mask_w);
                    end
                end

                if (dut.rvi_last !== rvi_exp_last_w) begin
                    rvi_last_mismatch_count <= rvi_last_mismatch_count + 1;
                    if (!first_rvi_last_mismatch_seen) begin
                        first_rvi_last_mismatch_seen <= 1'b1;
                        first_rvi_last_fmt           <= rvi_active_cmd_valid ? rvi_active_cmd_fmt : dut.rvi_tile_format;
                        first_rvi_last_x             <= rvi_active_cmd_valid ? rvi_active_cmd_x : dut.rvi_tile_xcoord;
                        first_rvi_last_y             <= rvi_active_cmd_valid ? rvi_active_cmd_y : dut.rvi_tile_ycoord;
                        first_rvi_last_beat          <= rvi_active_cmd_valid ? rvi_beat_idx : 0;
                        first_rvi_last_expected      <= rvi_exp_last_w;
                        first_rvi_last_actual        <= dut.rvi_last;
                        report_first_mismatch_header("ENC_RVI_LAST",
                                                     "u_core.dut.ubwc_enc_vivo_top_inst.i_rvi_last");
                        $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d beat=%0d last exp=%0d act=%0d",
                                 rvi_active_cmd_valid ? rvi_active_cmd_fmt : dut.rvi_tile_format,
                                 rvi_active_cmd_valid ? rvi_active_cmd_x   : dut.rvi_tile_xcoord,
                                 rvi_active_cmd_valid ? rvi_active_cmd_y   : dut.rvi_tile_ycoord,
                                 rvi_active_cmd_valid ? rvi_beat_idx       : 0,
                                 rvi_exp_last_w,
                                 dut.rvi_last);
                    end
                end

                if (rvi_active_cmd_valid &&
                    ((dut.rvi_tile_format !== rvi_active_cmd_fmt) ||
                     (dut.rvi_tile_xcoord !== rvi_active_cmd_x) ||
                     (dut.rvi_tile_ycoord !== rvi_active_cmd_y))) begin
                    rvi_coord_mismatch_count <= rvi_coord_mismatch_count + 1;
                    if (!first_rvi_coord_mismatch_seen) begin
                        first_rvi_coord_mismatch_seen <= 1'b1;
                        first_rvi_coord_exp_fmt       <= rvi_active_cmd_fmt;
                        first_rvi_coord_exp_x         <= rvi_active_cmd_x;
                        first_rvi_coord_exp_y         <= rvi_active_cmd_y;
                        first_rvi_coord_act_fmt       <= dut.rvi_tile_format;
                        first_rvi_coord_act_x         <= dut.rvi_tile_xcoord;
                        first_rvi_coord_act_y         <= dut.rvi_tile_ycoord;
                        first_rvi_coord_beat          <= rvi_beat_idx;
                        report_first_mismatch_header("ENC_RVI_COORD",
                                                     "u_core.dut.ubwc_enc_vivo_top_inst.i_rvi_format/xcoord/ycoord");
                        $display("[TB][FIRST_MISMATCH]   beat=%0d exp fmt=%0d x=%0d y=%0d act fmt=%0d x=%0d y=%0d",
                                 rvi_beat_idx,
                                 rvi_active_cmd_fmt,
                                 rvi_active_cmd_x,
                                 rvi_active_cmd_y,
                                 dut.rvi_tile_format,
                                 dut.rvi_tile_xcoord,
                                 dut.rvi_tile_ycoord);
                    end
                end

                if (rvi_exp_last_w) begin
                    rvi_active_cmd_valid <= 1'b0;
                    rvi_beat_idx         <= 0;
                end else if (!rvi_active_cmd_valid) begin
                    rvi_active_cmd_valid <= 1'b1;
                    rvi_active_cmd_fmt   <= dut.rvi_tile_format;
                    rvi_active_cmd_x     <= dut.rvi_tile_xcoord;
                    rvi_active_cmd_y     <= dut.rvi_tile_ycoord;
                    rvi_beat_idx         <= 1;
                end else begin
                    rvi_beat_idx         <= rvi_beat_idx + 1;
                end
            end
        end
    end

    task automatic apply_fake_vivo_forces;
        begin
            if (tb_fake_mode_en) begin
                $display("[TB] fake VIVO golden model enabled: internal metadata/compressed memories.");
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #(TB_AXI_CLK_HALF_NS) clk = ~clk;
    end

    initial begin
        pclk = 1'b0;
        forever #(TB_APB_CLK_HALF_NS) pclk = ~pclk;
    end

    initial begin
        vivo_clk = 1'b0;
        forever #(TB_CORE_CLK_HALF_NS) vivo_clk = ~vivo_clk;
    end

    initial begin
        otf_clk = 1'b0;
        forever #(TB_OTF_CLK_HALF_NS) otf_clk = ~otf_clk;
    end

    initial begin
        integer frame_idx;
        integer addr_cfg_programmed;
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
        cvo_cmd_wr_ptr = 0;
        cvo_cmd_rd_ptr = 0;
        fake_cvo_drv_rd_ptr = 0;
        fake_cvo_drv_beat_idx = 0;
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
        meta_path_stall_count = 0;
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
        expected_tiles_total = CASE_ACTIVE_EXPECTED_TILES;
        expected_beats_total = CASE_EXPECTED_BEATS;
        expected_rvi_beats_total = CASE_EXPECTED_BEATS;
        fake_expected_beats_total = 0;
        expected_meta_aw_total = CASE_FAKE_EXPECTED_META_AW;
        expected_meta_w_total = CASE_FAKE_EXPECTED_META_W;
        expected_meta_aw_plane0_total = CASE_FAKE_EXPECTED_META0_AW;
        expected_meta_aw_plane1_total = CASE_FAKE_EXPECTED_META1_AW;
        expected_meta_w_plane0_total = CASE_FAKE_EXPECTED_META0_W;
        expected_meta_w_plane1_total = CASE_FAKE_EXPECTED_META1_W;
        expected_stage_done = 8'h55;
        meta_ref_words_plane0 = 0;
        meta_ref_words_plane1 = 0;
        meta_ref_words_total = 0;
        meta_ref_active_words_plane0 = 0;
        meta_ref_active_words_plane1 = 0;
        meta_ref_active_words_total = 0;
        otf_done_count = 0;
        void'($value$plusargs("tb_timeout_cycles=%d", case_timeout_cycles));
        if (!$value$plusargs("tb_frame_repeat=%d", tb_frame_repeat))
            tb_frame_repeat = 1;
        if (tb_frame_repeat < 1)
            tb_frame_repeat = 1;
        if (tb_frame_repeat > MAX_FRAME_REPEAT)
            $fatal(1, "tb_frame_repeat=%0d exceeds MAX_FRAME_REPEAT=%0d", tb_frame_repeat, MAX_FRAME_REPEAT);
        expected_stage_done = (tb_frame_repeat > 1) ? 8'hff : 8'h55;
        expected_tiles_total = CASE_ACTIVE_EXPECTED_TILES * tb_frame_repeat;
        expected_beats_total = CASE_EXPECTED_BEATS * tb_frame_repeat;
        expected_rvi_beats_total = CASE_EXPECTED_BEATS * tb_frame_repeat;
        fake_expected_beats_total = 0;
        expected_meta_aw_total = CASE_FAKE_EXPECTED_META_AW * tb_frame_repeat;
        expected_meta_w_total = CASE_FAKE_EXPECTED_META_W * tb_frame_repeat;
        expected_meta_aw_plane0_total = CASE_FAKE_EXPECTED_META0_AW * tb_frame_repeat;
        expected_meta_aw_plane1_total = CASE_FAKE_EXPECTED_META1_AW * tb_frame_repeat;
        expected_meta_w_plane0_total = CASE_FAKE_EXPECTED_META0_W * tb_frame_repeat;
        expected_meta_w_plane1_total = CASE_FAKE_EXPECTED_META1_W * tb_frame_repeat;
        rvi_beat_count = 0;
        rvi_beat_idx = 0;
        cvo_beat_count = 0;
        vivo_ci_mismatch_count = 0;
        rvi_data_mismatch_count = 0;
        rvi_mask_mismatch_count = 0;
        rvi_last_mismatch_count = 0;
        rvi_coord_mismatch_count = 0;
        cvo_data_mismatch_count = 0;
        cvo_mask_mismatch_count = 0;
        cvo_last_mismatch_count = 0;
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
        cvo_active_valid_beats = 4'd0;
        cvo_beat_idx = 0;
        first_rvi_data_mismatch_seen = 1'b0;
        first_rvi_data_fmt = 5'd0;
        first_rvi_data_x = 16'd0;
        first_rvi_data_y = 16'd0;
        first_rvi_data_beat = 0;
        first_rvi_data_expected = {AXI_DW{1'b0}};
        first_rvi_data_actual = {AXI_DW{1'b0}};
        first_rvi_mask_mismatch_seen = 1'b0;
        first_rvi_mask_fmt = 5'd0;
        first_rvi_mask_x = 16'd0;
        first_rvi_mask_y = 16'd0;
        first_rvi_mask_beat = 0;
        first_rvi_mask_expected = 32'd0;
        first_rvi_mask_actual = 32'd0;
        first_rvi_last_mismatch_seen = 1'b0;
        first_rvi_last_fmt = 5'd0;
        first_rvi_last_x = 16'd0;
        first_rvi_last_y = 16'd0;
        first_rvi_last_beat = 0;
        first_rvi_last_expected = 1'b0;
        first_rvi_last_actual = 1'b0;
        first_rvi_coord_mismatch_seen = 1'b0;
        first_rvi_coord_exp_fmt = 5'd0;
        first_rvi_coord_exp_x = 16'd0;
        first_rvi_coord_exp_y = 16'd0;
        first_rvi_coord_act_fmt = 5'd0;
        first_rvi_coord_act_x = 16'd0;
        first_rvi_coord_act_y = 16'd0;
        first_rvi_coord_beat = 0;
        first_cvo_data_mismatch_seen = 1'b0;
        first_cvo_data_fmt = 5'd0;
        first_cvo_data_x = 16'd0;
        first_cvo_data_y = 16'd0;
        first_cvo_data_beat = 0;
        first_cvo_data_expected = {AXI_DW{1'b0}};
        first_cvo_data_actual = {AXI_DW{1'b0}};
        first_cvo_mask_mismatch_seen = 1'b0;
        first_cvo_mask_fmt = 5'd0;
        first_cvo_mask_x = 16'd0;
        first_cvo_mask_y = 16'd0;
        first_cvo_mask_beat = 0;
        first_cvo_mask_expected = 32'd0;
        first_cvo_mask_actual = 32'd0;
        first_cvo_last_mismatch_seen = 1'b0;
        first_cvo_last_fmt = 5'd0;
        first_cvo_last_x = 16'd0;
        first_cvo_last_y = 16'd0;
        first_cvo_last_beat = 0;
        first_cvo_last_expected = 1'b0;
        first_cvo_last_actual = 1'b0;
        first_vivo_ci_mismatch_seen = 1'b0;
        first_vivo_ci_mismatch_fmt = 5'd0;
        first_vivo_ci_mismatch_x = 16'd0;
        first_vivo_ci_mismatch_y = 16'd0;
        first_vivo_ci_expected_metadata = 8'd0;
        first_vivo_ci_actual_metadata = 8'd0;
        first_vivo_ci_expected_alen = 3'd0;
        first_vivo_ci_actual_alen = 3'd0;
        first_vivo_ci_expected_pcm = 1'b0;
        first_vivo_ci_actual_pcm = 1'b0;
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
        lossy_aw_split_pending = 1'b0;
        lossy_aw_split_addr = {AXI_AW{1'b0}};
        lossy_aw_split_beats = {(AXI_LENW+1){1'b0}};
        lossy_aw_split_fmt = 5'd0;
        lossy_aw_split_x = 16'd0;
        lossy_aw_split_y = 16'd0;
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
        first_meta_path_stall_seen = 1'b0;
        first_meta_path_stall_fmt = 5'd0;
        first_meta_path_stall_x = 28'd0;
        first_meta_path_stall_y = 13'd0;
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
        load_dump64_to_tile_plane("expected_tile_plane0.memh",
                                  0, CASE_TILE_BASE_Y_ADDR, CASE_TILE0_FILE_WORDS64);
        if (CASE_HAS_PLANE1) begin
            load_dump64_to_tile_plane("expected_tile_plane1.memh",
                                      1, CASE_TILE_BASE_UV_ADDR, CASE_TILE1_FILE_WORDS64);
        end

        load_dump64_to_ref("expected_meta_plane0.memh",
                           1, CASE_META_BASE_Y_ADDR, CASE_META0_WORDS64);
        load_dump64_to_meta_plane("expected_meta_plane0.memh",
                                  0, CASE_META0_WORDS64);
        if (CASE_HAS_PLANE1) begin
            load_dump64_to_ref("expected_meta_plane1.memh",
                               1, CASE_META_BASE_UV_ADDR, CASE_META1_WORDS64);
            load_dump64_to_meta_plane("expected_meta_plane1.memh",
                                      1, CASE_META1_WORDS64);
        end
        refresh_meta_ref_counts();
        if (!tb_fake_mode_en) begin
            expected_meta_aw_total = meta_ref_active_words_total * tb_frame_repeat;
            expected_meta_w_total = meta_ref_active_words_total * tb_frame_repeat;
            expected_meta_aw_plane0_total = meta_ref_active_words_plane0 * tb_frame_repeat;
            expected_meta_aw_plane1_total = meta_ref_active_words_plane1 * tb_frame_repeat;
            expected_meta_w_plane0_total = meta_ref_active_words_plane0 * tb_frame_repeat;
            expected_meta_w_plane1_total = meta_ref_active_words_plane1 * tb_frame_repeat;
        end

        load_dump64_to_ref("expected_cmp_plane0.memh",
                           0, CASE_TILE_BASE_Y_ADDR, CASE_CMP0_WORDS64);
        if (CASE_HAS_PLANE1) begin
            load_dump64_to_ref("expected_cmp_plane1.memh",
                               0, CASE_TILE_BASE_UV_ADDR, CASE_CMP1_WORDS64);
        end

        apply_fake_vivo_forces();

        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) @(posedge clk);
        program_wrapper_regs();
        addr_cfg_programmed = (tb_frame_repeat < 8) ? tb_frame_repeat : 8;
        repeat (64) @(posedge clk);
        frames_started = 1;
        program_frame_start();
        pulse_start_otf();
        for (frame_idx = 1; frame_idx < tb_frame_repeat; frame_idx = frame_idx + 1) begin
            wait_frame_idle(frame_idx);
            frames_completed = frame_idx;
            $display("[TB] frame %0d / %0d complete, scheduling next frame.", frame_idx, tb_frame_repeat);
            if (addr_cfg_programmed < tb_frame_repeat) begin
                program_addr_cfg_once();
                addr_cfg_programmed = addr_cfg_programmed + 1;
            end
            repeat (8) @(posedge clk);
            frames_started = frame_idx + 1;
            program_frame_start();
            pulse_start_otf();
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            cmd_wr_ptr            <= 0;
            cmd_rd_ptr            <= 0;
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
            meta_path_stall_count <= 0;
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
            cvo_beat_count        <= 0;
            cvo_data_mismatch_count <= 0;
            cvo_mask_mismatch_count <= 0;
            cvo_last_mismatch_count <= 0;
            cvo_active_cmd_valid  <= 1'b0;
            cvo_active_cmd_fmt    <= 5'd0;
            cvo_active_cmd_x      <= 16'd0;
            cvo_active_cmd_y      <= 16'd0;
            cvo_active_cmd_addr   <= {AXI_AW{1'b0}};
            cvo_active_cmd_beats  <= 4'd0;
            cvo_active_valid_beats<= 4'd0;
            cvo_beat_idx          <= 0;
            first_cvo_data_mismatch_seen <= 1'b0;
            first_cvo_data_fmt     <= 5'd0;
            first_cvo_data_x       <= 16'd0;
            first_cvo_data_y       <= 16'd0;
            first_cvo_data_beat    <= 0;
            first_cvo_data_expected<= {AXI_DW{1'b0}};
            first_cvo_data_actual  <= {AXI_DW{1'b0}};
            first_cvo_mask_mismatch_seen <= 1'b0;
            first_cvo_mask_fmt     <= 5'd0;
            first_cvo_mask_x       <= 16'd0;
            first_cvo_mask_y       <= 16'd0;
            first_cvo_mask_beat    <= 0;
            first_cvo_mask_expected<= 32'd0;
            first_cvo_mask_actual  <= 32'd0;
            first_cvo_last_mismatch_seen <= 1'b0;
            first_cvo_last_fmt     <= 5'd0;
            first_cvo_last_x       <= 16'd0;
            first_cvo_last_y       <= 16'd0;
            first_cvo_last_beat    <= 0;
            first_cvo_last_expected<= 1'b0;
            first_cvo_last_actual  <= 1'b0;
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
            lossy_aw_split_pending   <= 1'b0;
            lossy_aw_split_addr      <= {AXI_AW{1'b0}};
            lossy_aw_split_beats     <= {(AXI_LENW+1){1'b0}};
            lossy_aw_split_fmt       <= 5'd0;
            lossy_aw_split_x         <= 16'd0;
            lossy_aw_split_y         <= 16'd0;
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
            first_meta_path_stall_seen <= 1'b0;
            first_meta_path_stall_fmt  <= 5'd0;
            first_meta_path_stall_x    <= 28'd0;
            first_meta_path_stall_y    <= 13'd0;
            first_main_mem_strb      <= {(AXI_DW/8){1'b0}};
            first_meta_mem_strb      <= {(AXI_DW/8){1'b0}};
            ref_cmp_mismatch         <= 1'b0;
            ref_cmp_range_error      <= 1'b0;
            ref_cmp_expected_word    <= {AXI_DW{1'b0}};
        end else begin
            timeout_count <= timeout_count + 1;

            if (dut.enc_co_valid &&
                ((dut.meta_data_valid && !dut.meta_data_ready) ||
                 (dut.meta_addr_valid && !dut.meta_addr_ready))) begin
                meta_path_stall_count <= meta_path_stall_count + 1;
                if (!first_meta_path_stall_seen) begin
                    first_meta_path_stall_seen <= 1'b1;
                    first_meta_path_stall_fmt  <= dut.b_tile_format;
                    first_meta_path_stall_x    <= dut.b_tile_xcoord;
                    first_meta_path_stall_y    <= dut.b_tile_ycoord;
                end
            end

            if (mon_meta_valid && mon_meta_ready) begin
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

            if (ci_cmd_fire_w) begin
                coord_count <= coord_count + 1;
                if (tb_fake_mode_en) begin
                    if (cmd_wr_ptr < TILE_QUEUE_CAPACITY) begin
                        cmd_fmt_queue[cmd_wr_ptr] <= dut.ubwc_enc_otf_to_tile_inst.line_tile_format;
                        cmd_x_queue[cmd_wr_ptr]   <= dut.ubwc_enc_otf_to_tile_inst.line_tile_x;
                        cmd_y_queue[cmd_wr_ptr]   <= dut.ubwc_enc_otf_to_tile_inst.line_tile_y;
                        cmd_alen_queue[cmd_wr_ptr]<= fake_meta_alen_from_byte(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                              dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                              dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                                                                              expected_meta_byte(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                                 dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                                 dut.ubwc_enc_otf_to_tile_inst.line_tile_y));
                        cmd_addr_queue[cmd_wr_ptr]<= expected_tile_addr_with_alen(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                  dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                  dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                                                                                  fake_meta_alen_from_byte(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                                           dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                                           dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                                                                                                           expected_meta_byte(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                                                              dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                                                              dut.ubwc_enc_otf_to_tile_inst.line_tile_y)));
                        cmd_wr_ptr                <= cmd_wr_ptr + 1;
                    end
                end
            end

            if (ci_cmd_fire_w) begin
                if (tb_fake_mode_en && !cvo_start_direct_w && (cvo_cmd_wr_ptr < TILE_QUEUE_CAPACITY)) begin
                    cvo_fmt_queue[cvo_cmd_wr_ptr]   <= dut.ubwc_enc_otf_to_tile_inst.line_tile_format;
                    cvo_x_queue[cvo_cmd_wr_ptr]     <= dut.ubwc_enc_otf_to_tile_inst.line_tile_x;
                    cvo_y_queue[cvo_cmd_wr_ptr]     <= dut.ubwc_enc_otf_to_tile_inst.line_tile_y;
                    cvo_addr_queue[cvo_cmd_wr_ptr]  <= expected_tile_addr_with_alen(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                    dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                    dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                                                                                    fake_meta_alen_from_byte(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                                             dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                                             dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                                                                                                             expected_meta_byte(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                                                                dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                                                                dut.ubwc_enc_otf_to_tile_inst.line_tile_y)));
                    cvo_beats_queue[cvo_cmd_wr_ptr] <= fake_meta_total_beats_from_byte(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                       dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                       dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                                                                                       expected_meta_byte(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                                          dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                                          dut.ubwc_enc_otf_to_tile_inst.line_tile_y));
                    cvo_valid_beats_queue[cvo_cmd_wr_ptr] <= fake_meta_valid_beats_from_byte(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                             dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                             dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                                                                                             expected_meta_byte(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                                                dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                                                dut.ubwc_enc_otf_to_tile_inst.line_tile_y));
                    fake_expected_beats_total       <= fake_expected_beats_total +
                                                       fake_meta_total_beats_from_byte(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                       dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                       dut.ubwc_enc_otf_to_tile_inst.line_tile_y,
                                                                                       expected_meta_byte(dut.ubwc_enc_otf_to_tile_inst.line_tile_format,
                                                                                                          dut.ubwc_enc_otf_to_tile_inst.line_tile_x,
                                                                                                          dut.ubwc_enc_otf_to_tile_inst.line_tile_y));
                    cvo_cmd_wr_ptr                  <= cvo_cmd_wr_ptr + 1;
                end
            end

            if (!tb_fake_mode_en && dut.enc_axi_awvalid && dut.enc_axi_awready) begin
                if (!cvo_start_direct_w && (cvo_cmd_wr_ptr < TILE_QUEUE_CAPACITY)) begin
                    cvo_fmt_queue[cvo_cmd_wr_ptr]   <= 5'd0;
                    cvo_x_queue[cvo_cmd_wr_ptr]     <= 16'd0;
                    cvo_y_queue[cvo_cmd_wr_ptr]     <= 16'd0;
                    cvo_addr_queue[cvo_cmd_wr_ptr]  <= dut.enc_axi_awaddr;
                    cvo_beats_queue[cvo_cmd_wr_ptr] <= {1'b0, dut.enc_axi_awlen[2:0]} + 4'd1;
                    cvo_valid_beats_queue[cvo_cmd_wr_ptr] <= {1'b0, dut.enc_axi_awlen[2:0]} + 4'd1;
                    cvo_cmd_wr_ptr                  <= cvo_cmd_wr_ptr + 1;
                end
            end

            if (dut.enc_cvo_valid && dut.enc_cvo_ready) begin
                cvo_beat_count <= cvo_beat_count + 1;
                if (!cvo_expect_valid_w) begin
                    cvo_data_mismatch_count <= cvo_data_mismatch_count + 1;
                    if (!first_cvo_data_mismatch_seen) begin
                        first_cvo_data_mismatch_seen <= 1'b1;
                            first_cvo_data_fmt           <= 5'd0;
                            first_cvo_data_x             <= 16'd0;
                            first_cvo_data_y             <= 16'd0;
                            first_cvo_data_beat          <= 0;
                            first_cvo_data_expected      <= {AXI_DW{1'b0}};
                            first_cvo_data_actual        <= dut.enc_cvo_data;
                            report_first_mismatch_header("ENC_CVO_QUEUE_UNDERFLOW",
                                                         "u_core.dut.enc_cvo_*");
                            $display("[TB][FIRST_MISMATCH]   CVO data arrived with no queued command, mask=0x%08x",
                                     dut.enc_cvo_mask);
                        $display("[TB][FIRST_MISMATCH]   actual=0x%064x", dut.enc_cvo_data);
                    end
                end else begin
                    if (masked_axi_word_mismatch(dut.enc_cvo_data,
                                                 dut.enc_cvo_mask,
                                                 cvo_expect_data_w)) begin
                        cvo_data_mismatch_count <= cvo_data_mismatch_count + 1;
                        if (!first_cvo_data_mismatch_seen) begin
                            first_cvo_data_mismatch_seen <= 1'b1;
                            first_cvo_data_fmt           <= cvo_expect_fmt_w;
                            first_cvo_data_x             <= cvo_expect_x_w;
                            first_cvo_data_y             <= cvo_expect_y_w;
                            first_cvo_data_beat          <= cvo_expect_beat_w;
                            first_cvo_data_expected      <= cvo_expect_data_w;
                            first_cvo_data_actual        <= dut.enc_cvo_data;
                            report_first_mismatch_header("ENC_CVO_DATA",
                                                         "u_core.dut.ubwc_enc_vivo_top_inst.o_cvo_* / u_core.dut.enc_cvo_*");
                            $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d addr=0x%016x beat=%0d mask=0x%08x",
                                     cvo_expect_fmt_w,
                                     cvo_expect_x_w,
                                     cvo_expect_y_w,
                                     cvo_expect_addr_w,
                                     cvo_expect_beat_w,
                                     dut.enc_cvo_mask);
                            $display("[TB][FIRST_MISMATCH]   expected=0x%064x", cvo_expect_data_w);
                            $display("[TB][FIRST_MISMATCH]   actual  =0x%064x", dut.enc_cvo_data);
                        end
                    end
                    if (dut.enc_cvo_mask !== cvo_expect_mask_w) begin
                        cvo_mask_mismatch_count <= cvo_mask_mismatch_count + 1;
                        if (!first_cvo_mask_mismatch_seen) begin
                            first_cvo_mask_mismatch_seen <= 1'b1;
                            first_cvo_mask_fmt           <= cvo_expect_fmt_w;
                            first_cvo_mask_x             <= cvo_expect_x_w;
                            first_cvo_mask_y             <= cvo_expect_y_w;
                            first_cvo_mask_beat          <= cvo_expect_beat_w;
                            first_cvo_mask_expected      <= cvo_expect_mask_w;
                            first_cvo_mask_actual        <= dut.enc_cvo_mask;
                            report_first_mismatch_header("ENC_CVO_MASK",
                                                         "u_core.dut.ubwc_enc_vivo_top_inst.o_cvo_mask / u_core.dut.enc_cvo_mask");
                            $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d addr=0x%016x beat=%0d mask exp=0x%08x act=0x%08x",
                                     cvo_expect_fmt_w,
                                     cvo_expect_x_w,
                                     cvo_expect_y_w,
                                     cvo_expect_addr_w,
                                     cvo_expect_beat_w,
                                     cvo_expect_mask_w,
                                     dut.enc_cvo_mask);
                        end
                    end
                    if (dut.enc_cvo_last !== cvo_expect_last_w) begin
                        cvo_last_mismatch_count <= cvo_last_mismatch_count + 1;
                        if (!first_cvo_last_mismatch_seen) begin
                            first_cvo_last_mismatch_seen <= 1'b1;
                            first_cvo_last_fmt           <= cvo_expect_fmt_w;
                            first_cvo_last_x             <= cvo_expect_x_w;
                            first_cvo_last_y             <= cvo_expect_y_w;
                            first_cvo_last_beat          <= cvo_expect_beat_w;
                            first_cvo_last_expected      <= cvo_expect_last_w;
                            first_cvo_last_actual        <= dut.enc_cvo_last;
                            report_first_mismatch_header("ENC_CVO_LAST",
                                                         "u_core.dut.ubwc_enc_vivo_top_inst.o_cvo_last / u_core.dut.enc_cvo_last");
                            $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d addr=0x%016x beat=%0d last exp=%0d act=%0d",
                                     cvo_expect_fmt_w,
                                     cvo_expect_x_w,
                                     cvo_expect_y_w,
                                     cvo_expect_addr_w,
                                     cvo_expect_beat_w,
                                     cvo_expect_last_w,
                                     dut.enc_cvo_last);
                        end
                    end

                    if (!cvo_active_cmd_valid) begin
                        if (cvo_expect_queue_w)
                            cvo_cmd_rd_ptr <= cvo_cmd_rd_ptr + 1;
                        if (cvo_expect_last_w) begin
                            cvo_active_cmd_valid <= 1'b0;
                            cvo_beat_idx         <= 0;
                        end else begin
                            cvo_active_cmd_valid <= 1'b1;
                            cvo_active_cmd_fmt   <= cvo_expect_fmt_w;
                            cvo_active_cmd_x     <= cvo_expect_x_w;
                            cvo_active_cmd_y     <= cvo_expect_y_w;
                            cvo_active_cmd_addr  <= cvo_expect_base_addr_w;
                            cvo_active_cmd_beats <= cvo_expect_beats_w;
                            cvo_active_valid_beats <= cvo_expect_valid_beats_w;
                            cvo_beat_idx         <= 1;
                        end
                    end else if (cvo_expect_last_w) begin
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
                    if (CASE_IS_LOSSY_RGBA_2_1 != 0) begin
                        if (!lossy_aw_expected_valid_w) begin
                            queue_underflow_count <= queue_underflow_count + 1;
                        end else begin
                            main_burst_active      <= 1'b1;
                            main_burst_addr        <= dut.enc_axi_awaddr;
                            main_burst_beats_total <= {{AXI_LENW{1'b0}}, 1'b1} + dut.enc_axi_awlen;
                            main_burst_beat_idx    <= {(AXI_LENW+1){1'b0}};
                            active_cmd_valid       <= 1'b1;
                            active_cmd_fmt         <= lossy_aw_expected_fmt_w;
                            active_cmd_x           <= lossy_aw_expected_x_w;
                            active_cmd_y           <= lossy_aw_expected_y_w;
                            active_cmd_beat_idx    <= 0;
                            if (dut.enc_axi_awlen !== lossy_aw_expected_len_w) begin
                                aw_mismatch_count <= aw_mismatch_count + 1;
                                if (!first_aw_mismatch_seen) begin
                                    first_aw_mismatch_seen <= 1'b1;
                                    first_aw_actual        <= dut.enc_axi_awaddr;
                                    first_aw_expected      <= lossy_aw_expected_addr_w;
                                    first_aw_fmt           <= lossy_aw_expected_fmt_w;
                                    first_aw_x             <= lossy_aw_expected_x_w;
                                    first_aw_y             <= lossy_aw_expected_y_w;
                                    report_first_mismatch_header("ENC_TILE_AW_LEN",
                                                                 "u_core.dut.enc_axi_aw*");
                                    $display("[TB][FIRST_MISMATCH]   lossy fmt=%0d x=%0d y=%0d awlen exp=%0d act=%0d awaddr exp=0x%016x act=0x%016x",
                                             lossy_aw_expected_fmt_w,
                                             lossy_aw_expected_x_w,
                                             lossy_aw_expected_y_w,
                                             lossy_aw_expected_len_w,
                                             dut.enc_axi_awlen,
                                             lossy_aw_expected_addr_w,
                                             dut.enc_axi_awaddr);
                                end
                            end
                            if (CASE_ADDR_CHECK_EN &&
                                (dut.enc_axi_awaddr !== lossy_aw_expected_addr_w)) begin
                                aw_mismatch_count <= aw_mismatch_count + 1;
                                if (!first_aw_mismatch_seen) begin
                                    first_aw_mismatch_seen <= 1'b1;
                                    first_aw_actual        <= dut.enc_axi_awaddr;
                                    first_aw_expected      <= lossy_aw_expected_addr_w;
                                    first_aw_fmt           <= lossy_aw_expected_fmt_w;
                                    first_aw_x             <= lossy_aw_expected_x_w;
                                    first_aw_y             <= lossy_aw_expected_y_w;
                                    report_first_mismatch_header("ENC_TILE_AW_ADDR",
                                                                 "u_core.dut.enc_axi_aw*");
                                    $display("[TB][FIRST_MISMATCH]   lossy fmt=%0d x=%0d y=%0d awaddr exp=0x%016x act=0x%016x awlen exp=%0d act=%0d",
                                             lossy_aw_expected_fmt_w,
                                             lossy_aw_expected_x_w,
                                             lossy_aw_expected_y_w,
                                             lossy_aw_expected_addr_w,
                                             dut.enc_axi_awaddr,
                                             lossy_aw_expected_len_w,
                                             dut.enc_axi_awlen);
                                end
                            end
                            if (lossy_aw_split_pending) begin
                                lossy_aw_split_pending <= 1'b0;
                            end else begin
                                cmd_rd_ptr <= cmd_rd_ptr + 1;
                                if (lossy_aw_expected_split_w) begin
                                    lossy_aw_split_pending <= 1'b1;
                                    lossy_aw_split_addr    <= lossy_aw_second_addr_w;
                                    lossy_aw_split_beats   <= lossy_aw_second_beats_w;
                                    lossy_aw_split_fmt     <= lossy_aw_expected_fmt_w;
                                    lossy_aw_split_x       <= lossy_aw_expected_x_w;
                                    lossy_aw_split_y       <= lossy_aw_expected_y_w;
                                end
                            end
                        end
                    end else begin
                        if (cmd_rd_ptr >= cmd_wr_ptr) begin
                            queue_underflow_count <= queue_underflow_count + 1;
                        end else begin
                            main_burst_active      <= 1'b1;
                            main_burst_addr        <= dut.enc_axi_awaddr;
                            main_burst_beats_total <= {{AXI_LENW{1'b0}}, 1'b1} + dut.enc_axi_awlen;
                            main_burst_beat_idx    <= {(AXI_LENW+1){1'b0}};
                            active_cmd_valid       <= 1'b1;
                            active_cmd_fmt         <= cmd_fmt_queue[cmd_rd_ptr];
                            active_cmd_x           <= cmd_x_queue[cmd_rd_ptr];
                            active_cmd_y           <= cmd_y_queue[cmd_rd_ptr];
                            active_cmd_beat_idx    <= 0;
                            if (dut.enc_axi_awlen !== {{(AXI_LENW-3){1'b0}}, cmd_alen_queue[cmd_rd_ptr]})
                                aw_mismatch_count <= aw_mismatch_count + 1;
                            if (CASE_ADDR_CHECK_EN && (dut.enc_axi_awaddr !== cmd_addr_queue[cmd_rd_ptr])) begin
                                aw_mismatch_count <= aw_mismatch_count + 1;
                                if (!first_aw_mismatch_seen) begin
                                    first_aw_mismatch_seen <= 1'b1;
                                    first_aw_actual       <= dut.enc_axi_awaddr;
                                    first_aw_expected     <= cmd_addr_queue[cmd_rd_ptr];
                                    first_aw_fmt          <= cmd_fmt_queue[cmd_rd_ptr];
                                    first_aw_x            <= cmd_x_queue[cmd_rd_ptr];
                                    first_aw_y            <= cmd_y_queue[cmd_rd_ptr];
                                    report_first_mismatch_header("ENC_TILE_AW_ADDR",
                                                                 "u_core.dut.enc_axi_aw*");
                                    $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d awaddr exp=0x%016x act=0x%016x",
                                             cmd_fmt_queue[cmd_rd_ptr],
                                             cmd_x_queue[cmd_rd_ptr],
                                             cmd_y_queue[cmd_rd_ptr],
                                             cmd_addr_queue[cmd_rd_ptr],
                                             dut.enc_axi_awaddr);
                                end
                            end
                            cmd_rd_ptr <= cmd_rd_ptr + 1;
                        end
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
                    if ((!main_burst_active) || !active_cmd_valid) begin
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
                                report_first_mismatch_header("ENC_TILE_AXI_WDATA",
                                                             "u_core.dut.enc_axi_w*");
                                $display("[TB][FIRST_MISMATCH]   addr=0x%016x beat=%0d/%0d strb=0x%08x",
                                         main_burst_addr + (main_burst_beat_idx * (AXI_DW/8)),
                                         main_burst_beat_idx,
                                         main_burst_beats_total,
                                         dut.enc_axi_wstrb);
                                $display("[TB][FIRST_MISMATCH]   expected=0x%064x", ref_cmp_expected_word);
                                $display("[TB][FIRST_MISMATCH]   actual  =0x%064x", dut.enc_axi_wdata);
                            end
                        end
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
                                report_first_mismatch_header("ENC_META_AXI_WDATA",
                                                             "u_core.dut.meta_axi_w*");
                                $display("[TB][FIRST_MISMATCH]   addr=0x%016x strb=0x%08x sel_uv=%0d",
                                         meta_write_beat_addr_w,
                                         dut.meta_axi_wstrb,
                                         CASE_HAS_PLANE1 && (meta_write_beat_addr_w >= CASE_META_BASE_UV_ADDR));
                                $display("[TB][FIRST_MISMATCH]   expected=0x%064x", ref_cmp_expected_word);
                                $display("[TB][FIRST_MISMATCH]   actual  =0x%064x", dut.meta_axi_wdata);
                            end
                        end
                        if (dut.meta_axi_wlast !== 1'b1)
                            out_wlast_mismatch_count <= out_wlast_mismatch_count + 1;
                    end
                    meta_burst_active   <= 1'b0;
                    meta_burst_beat_idx <= {(AXI_LENW+1){1'b0}};
                end
                if ((coord_count == expected_tiles_total) &&
                    (aw_count == expected_tiles_total) &&
                    (w_count == fake_expected_beats_total) &&
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
                            report_first_mismatch_header("ENC_TILE_AXI_WDATA_UNDERFLOW",
                                                         "u_core.dut.enc_axi_w*");
                            $display("[TB][FIRST_MISMATCH]   W data arrived without active AW burst, strb=0x%08x",
                                     dut.enc_axi_wstrb);
                            $display("[TB][FIRST_MISMATCH]   actual=0x%064x", dut.enc_axi_wdata);
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
                                report_first_mismatch_header("ENC_TILE_AXI_WDATA",
                                                             "u_core.dut.enc_axi_w*");
                                $display("[TB][FIRST_MISMATCH]   addr=0x%016x beat=%0d/%0d strb=0x%08x",
                                         main_burst_addr + (main_burst_beat_idx * (AXI_DW/8)),
                                         main_burst_beat_idx,
                                         main_burst_beats_total,
                                         dut.enc_axi_wstrb);
                                $display("[TB][FIRST_MISMATCH]   expected=0x%064x", ref_cmp_expected_word);
                                $display("[TB][FIRST_MISMATCH]   actual  =0x%064x", dut.enc_axi_wdata);
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
                        first_meta_aw_y_base      <= dut.meta_y_base_offset_addr0;
                        first_meta_aw_uv_base     <= dut.meta_uv_base_offset_addr0;
                        first_meta_aw_sel_uv      <= mon_meta_aw_sel_uv;
                        first_meta_aw_y_meta_addr <= mon_meta_aw_y_addr;
                        first_meta_aw_uv_meta_addr<= mon_meta_aw_uv_addr;
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
                            report_first_mismatch_header("ENC_META_AXI_WDATA_UNDERFLOW",
                                                         "u_core.dut.meta_axi_w*");
                            $display("[TB][FIRST_MISMATCH]   meta W data arrived without active AW burst, strb=0x%08x",
                                     dut.meta_axi_wstrb);
                            $display("[TB][FIRST_MISMATCH]   actual=0x%064x", dut.meta_axi_wdata);
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
                                report_first_mismatch_header("ENC_META_AXI_WDATA",
                                                             "u_core.dut.meta_axi_w*");
                                $display("[TB][FIRST_MISMATCH]   addr=0x%016x strb=0x%08x sel_uv=%0d",
                                         meta_write_beat_addr_w,
                                         dut.meta_axi_wstrb,
                                         CASE_HAS_PLANE1 && (meta_write_beat_addr_w >= CASE_META_BASE_UV_ADDR));
                                $display("[TB][FIRST_MISMATCH]   expected=0x%064x", ref_cmp_expected_word);
                                $display("[TB][FIRST_MISMATCH]   actual  =0x%064x", dut.meta_axi_wdata);
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

    always @(posedge otf_clk or negedge rst_n) begin
        if (!rst_n)
            otf_done_count <= 0;
        else if (otf_done)
            otf_done_count <= otf_done_count + 1;
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
                $display("  w_count             : %0d / %0d", w_count,
                         tb_fake_mode_en ? fake_expected_beats_total : expected_beats_total);

                $display("  dut top handshake   : rvi_mon_fire=%0b ci_cmd_fire=%0b",
                         rvi_mon_fire_w, ci_cmd_fire_w);
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

                $display("  line_to_tile state  : rd_state=%0d wr_bank=%0b rd_bank=%0b grp_y_cnt=%0d grp_y=%0d plane=%0b",
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_state,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.wr_bank_sel,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_bank_sel_act,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_tile_grp_y_cnt,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_group_y,
                         dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_plane);
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

        if (o_stage_done !== expected_stage_done) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] encoder done stage mismatch: got=0x%02x exp=0x%02x",
                     o_stage_done,
                     expected_stage_done);
        end
        if (o_frame_done !== 1'b1) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] encoder frame_done did not assert.");
        end
        if (o_irq !== 1'b1) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] encoder irq did not assert.");
        end

        if (tb_fake_mode_en) begin
            if (coord_count != expected_tiles_total) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] tile_coord count mismatch: got=%0d exp=%0d", coord_count, expected_tiles_total);
            end
            if ((CASE_IS_LOSSY_RGBA_2_1 == 0) &&
                (aw_count != expected_tiles_total)) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] tile AW count mismatch: got=%0d exp=%0d", aw_count, expected_tiles_total);
            end
            if ((CASE_IS_LOSSY_RGBA_2_1 != 0) &&
                ((cmd_rd_ptr != cmd_wr_ptr) || lossy_aw_split_pending)) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] lossy tile AW command queue not drained: rd=%0d wr=%0d split_pending=%0d",
                         cmd_rd_ptr,
                         cmd_wr_ptr,
                         lossy_aw_split_pending);
            end
            if (w_count != fake_expected_beats_total) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] compressed W beat count mismatch: got=%0d exp=%0d", w_count, fake_expected_beats_total);
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
                $display("[TB][WARN] strb mismatches observed in fake mode: %0d", strb_mismatch_count);
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
            if (meta_mem_mismatch_count != 0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] metadata mismatches: %0d", meta_mem_mismatch_count);
                if (first_meta_mem_mismatch_seen) begin
                    $display("[TB][ERROR] first metadata mismatch addr=0x%016x strb=0x%08x",
                             first_meta_mem_addr,
                             first_meta_mem_strb);
                    $display("[TB][ERROR]   expected=0x%064x", first_meta_mem_expected);
                    $display("[TB][ERROR]   actual  =0x%064x", first_meta_mem_actual);
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
                                      tb_fake_mode_en ? CASE_FAKE_ACTIVE_META0_WORDS64 :
                                      ((meta_ref_words_plane0 != 0) ? meta_ref_words_plane0 : CASE_META0_WORDS64),
                                      0);
        if (CASE_HAS_PLANE1) begin
            compare_meta_dump_file_to_ref(meta_dump_file_plane1,
                                          CASE_META_BASE_UV_ADDR,
                                          tb_fake_mode_en ? CASE_FAKE_ACTIVE_META1_WORDS64 :
                                          ((meta_ref_words_plane1 != 0) ? meta_ref_words_plane1 : CASE_META1_WORDS64),
                                          1);
        end

        $display("[TB] Encoder wrapper case summary:");
        $display("  CASE_ID             : %0d", CASE_ID);
        $display("  mode                : %0s", tb_fake_mode_en ? "fake" : "non-fake");
        $display("  frame_repeat        : %0d", tb_frame_repeat);
        $display("  frames_started      : %0d", frames_started);
        $display("  frames_completed    : %0d", frames_completed);
        $display("  otf_done_count      : %0d", otf_done_count);
        $display("  dut.stage_done      : 0x%02x", o_stage_done);
        $display("  dut.frame_done      : %0d", o_frame_done);
        $display("  dut.irq             : %0d", o_irq);
        $display("  coord_count         : %0d", coord_count);
        $display("  rvi_beat_count      : %0d", rvi_beat_count);
        $display("  vivo_ci_mismatch    : %0d", vivo_ci_mismatch_count);
        $display("  rvi_data_mismatch   : %0d", rvi_data_mismatch_count);
        $display("  rvi_mask_mismatch   : %0d", rvi_mask_mismatch_count);
        $display("  rvi_last_mismatch   : %0d", rvi_last_mismatch_count);
        $display("  rvi_coord_mismatch  : %0d", rvi_coord_mismatch_count);
        $display("  cvo_beat_count      : %0d", cvo_beat_count);
        $display("  cvo_data_mismatch   : %0d", cvo_data_mismatch_count);
        $display("  cvo_mask_mismatch   : %0d", cvo_mask_mismatch_count);
        $display("  cvo_last_mismatch   : %0d", cvo_last_mismatch_count);
        if (tb_fake_mode_en) begin
            $display("  tile_aw_count       : %0d", aw_count);
            $display("  tile_w_count        : %0d", w_count);
            $display("  meta_aw_count       : %0d", meta_aw_count);
            $display("  meta_w_count        : %0d", meta_w_count);
            $display("  aw_mismatch_count   : %0d", aw_mismatch_count);
            $display("  main_mem_mismatch   : %0d", main_mem_mismatch_count);
            $display("  meta_mem_mismatch   : %0d", meta_mem_mismatch_count);
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
            $display("  dut.err_bline       : %0d", mon_err_bline);
            $display("  dut.err_bframe      : %0d", mon_err_bframe);
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
                $display("  ref main Y          : ../../../vector/enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out0.txt");
                $display("  ref main UV         : ../../../vector/enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out1.txt");
                $display("  ref meta Y          : ../../../vector/enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out2.txt");
                $display("  ref meta UV         : ../../../vector/enc_from_mdss_01000007_k_outdoor61_4096x600_g016/visual_from_mdss_writeback_50_wb_2_rec_0_verify_ubwc_enc_out3.txt");
            end else begin
                $display("  ref main Y          : ../../../vector/enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out0.txt");
                $display("  ref main UV         : ../../../vector/enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out1.txt");
                $display("  ref meta Y          : ../../../vector/enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out2.txt");
                $display("  ref meta UV         : ../../../vector/enc_from_mdss_zp_TajMahal_4096x600_nv12/visual_from_mdss_writeback_2_wb_2_rec_0_verify_ubwc_enc_out3.txt");
            end
            $display("  main Y mismatch cnt : %0d", main_plane0_mem_mismatch_count);
            $display("  main UV mismatch cnt: %0d", main_plane1_mem_mismatch_count);
            $display("  meta Y mismatch cnt : %0d", meta_plane0_mem_mismatch_count);
            $display("  meta UV mismatch cnt: %0d", meta_plane1_mem_mismatch_count);
        end

        if (meta_dump_mismatch_count != 0) begin
            fail_count = fail_count + 1;
            $display("%s dumped meta/golden mismatches: %0d",
                     "[TB][ERROR]",
                     meta_dump_mismatch_count);
            if (first_meta_dump_mismatch_seen) begin
                $display("%s first dumped meta mismatch addr=0x%016x",
                         "[TB][ERROR]",
                         first_meta_dump_addr);
                $display("%s   expected=0x%016x",
                         "[TB][ERROR]",
                         first_meta_dump_expected);
                $display("%s   actual  =0x%016x",
                         "[TB][ERROR]",
                         first_meta_dump_actual);
            end
        end
        if (meta_dump_word_count_error_count != 0) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] dumped meta word-count/base errors: %0d", meta_dump_word_count_error_count);
        end
        if (vivo_ci_mismatch_count != 0) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] vivo CI input metadata/alen/pcm mismatches: %0d",
                     vivo_ci_mismatch_count);
            if (first_vivo_ci_mismatch_seen) begin
                $display("[TB][ERROR] first vivo CI mismatch: fmt=%0d x=%0d y=%0d",
                         first_vivo_ci_mismatch_fmt,
                         first_vivo_ci_mismatch_x,
                         first_vivo_ci_mismatch_y);
                $display("[TB][ERROR]   metadata exp=0x%02x act=0x%02x",
                         first_vivo_ci_expected_metadata,
                         first_vivo_ci_actual_metadata);
                $display("[TB][ERROR]   alen     exp=%0d act=%0d",
                         first_vivo_ci_expected_alen,
                         first_vivo_ci_actual_alen);
                $display("[TB][ERROR]   pcm      exp=%0d act=%0d",
                         first_vivo_ci_expected_pcm,
                         first_vivo_ci_actual_pcm);
            end
        end
        if (rvi_beat_count != expected_rvi_beats_total) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] rvi beat count mismatch: got=%0d exp=%0d",
                     rvi_beat_count, expected_rvi_beats_total);
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
        if (rvi_mask_mismatch_count != 0) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] rvi/tiled-uncompressed mask mismatches: %0d",
                     rvi_mask_mismatch_count);
            if (first_rvi_mask_mismatch_seen) begin
                $display("[TB][ERROR] first rvi mask mismatch: fmt=%0d x=%0d y=%0d beat=%0d",
                         first_rvi_mask_fmt,
                         first_rvi_mask_x,
                         first_rvi_mask_y,
                         first_rvi_mask_beat);
                $display("[TB][ERROR]   expected=0x%08x actual=0x%08x",
                         first_rvi_mask_expected,
                         first_rvi_mask_actual);
            end
        end
        if (rvi_last_mismatch_count != 0) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] rvi/tiled-uncompressed last mismatches: %0d",
                     rvi_last_mismatch_count);
            if (first_rvi_last_mismatch_seen) begin
                $display("[TB][ERROR] first rvi last mismatch: fmt=%0d x=%0d y=%0d beat=%0d",
                         first_rvi_last_fmt,
                         first_rvi_last_x,
                         first_rvi_last_y,
                         first_rvi_last_beat);
                $display("[TB][ERROR]   expected=%0d actual=%0d",
                         first_rvi_last_expected,
                         first_rvi_last_actual);
            end
        end
        if (rvi_coord_mismatch_count != 0) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] rvi/tiled-uncompressed coord mismatches: %0d",
                     rvi_coord_mismatch_count);
            if (first_rvi_coord_mismatch_seen) begin
                $display("[TB][ERROR] first rvi coord mismatch: beat=%0d",
                         first_rvi_coord_beat);
                $display("[TB][ERROR]   expected fmt=%0d x=%0d y=%0d",
                         first_rvi_coord_exp_fmt,
                         first_rvi_coord_exp_x,
                         first_rvi_coord_exp_y);
                $display("[TB][ERROR]   actual   fmt=%0d x=%0d y=%0d",
                         first_rvi_coord_act_fmt,
                         first_rvi_coord_act_x,
                         first_rvi_coord_act_y);
            end
        end
        if (tb_fake_mode_en) begin
            if (cvo_beat_count != fake_expected_beats_total) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] fake cvo beat count mismatch: got=%0d exp=%0d",
                         cvo_beat_count, fake_expected_beats_total);
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
                $display("[TB][ERROR]   expected=0x%064x",
                         first_cvo_data_expected);
                $display("[TB][ERROR]   actual  =0x%064x",
                         first_cvo_data_actual);
            end
        end
        if (cvo_mask_mismatch_count != 0) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] cvo mask mismatches: %0d",
                     cvo_mask_mismatch_count);
            if (first_cvo_mask_mismatch_seen) begin
                $display("[TB][ERROR] first cvo mask mismatch: fmt=%0d x=%0d y=%0d beat=%0d",
                         first_cvo_mask_fmt,
                         first_cvo_mask_x,
                         first_cvo_mask_y,
                         first_cvo_mask_beat);
                $display("[TB][ERROR]   expected=0x%08x actual=0x%08x",
                         first_cvo_mask_expected,
                         first_cvo_mask_actual);
            end
        end
        if (cvo_last_mismatch_count != 0) begin
            fail_count = fail_count + 1;
            $display("[TB][ERROR] cvo last mismatches: %0d",
                     cvo_last_mismatch_count);
            if (first_cvo_last_mismatch_seen) begin
                $display("[TB][ERROR] first cvo last mismatch: fmt=%0d x=%0d y=%0d beat=%0d",
                         first_cvo_last_fmt,
                         first_cvo_last_x,
                         first_cvo_last_y,
                         first_cvo_last_beat);
                $display("[TB][ERROR]   expected=%0d actual=%0d",
                         first_cvo_last_expected,
                         first_cvo_last_actual);
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
    parameter integer CASE_ID = 0,
    parameter integer IMG_W = 4096,
    parameter integer RGBA_ACTIVE_H = 600,
    parameter integer RGBA_STORED_H = 608,
    parameter integer RGBA_TILE_PITCH = 16384,
    parameter integer RGBA_TILE_COLS = 256,
    parameter integer RGBA_TILE_ROWS = 152,
    parameter integer RGBA_META_WORDS64 = 5120,
    parameter integer CFG_NV12_ACTIVE_H = 600,
    parameter integer CFG_NV12_Y_STORED_H = 640,
    parameter integer CFG_NV12_UV_STORED_H = 320,
    parameter integer CFG_NV12_TILE_PITCH = 4096,
    parameter integer CFG_NV12_Y_TILE_COLS = 128,
    parameter integer CFG_NV12_UV_TILE_COLS = 128,
    parameter integer CFG_NV12_Y_TILE_ROWS = 80,
    parameter integer CFG_NV12_UV_TILE_ROWS = 40,
    parameter integer CFG_NV12_COMP_Y_WORDS64 = 311296,
    parameter integer CFG_NV12_COMP_UV_WORDS64 = 163840,
    parameter integer CFG_NV12_META_Y_WORDS64 = 1536,
    parameter integer CFG_NV12_META_UV_WORDS64 = 1024,
    parameter integer CFG_G016_ACTIVE_H = 600,
    parameter integer CFG_G016_Y_STORED_H = 608,
    parameter integer CFG_G016_UV_STORED_H = 304,
    parameter integer CFG_G016_TILE_PITCH = 8192,
    parameter integer CFG_G016_Y_TILE_COLS = 128,
    parameter integer CFG_G016_UV_TILE_COLS = 128,
    parameter integer CFG_G016_Y_TILE_ROWS = 152,
    parameter integer CFG_G016_UV_TILE_ROWS = 76,
    parameter integer CFG_G016_COMP_Y_WORDS64 = 622592,
    parameter integer CFG_G016_COMP_UV_WORDS64 = 311296,
    parameter integer CFG_G016_META_Y_WORDS64 = 2560,
    parameter integer CFG_G016_META_UV_WORDS64 = 1536,
    parameter [63:0] CFG_RGBA_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_A000,
    parameter [63:0] CFG_RGBA_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_NV12_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_3000,
    parameter [63:0] CFG_NV12_TILE_BASE_UV_ADDR = 64'h0000_0000_8028_5000,
    parameter [63:0] CFG_NV12_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_NV12_META_BASE_UV_ADDR = 64'h0000_0000_8028_3000,
    parameter [63:0] CFG_G016_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_5000,
    parameter [63:0] CFG_G016_TILE_BASE_UV_ADDR = 64'h0000_0000_804C_8000,
    parameter [63:0] CFG_G016_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_G016_META_BASE_UV_ADDR = 64'h0000_0000_804C_5000,
    parameter integer COM_BUF_AW = 11,
    parameter integer CASE_TILE_EXPECT_LINEAR = 0,
    parameter integer CASE_CI_LOSSY = 0,
    parameter integer CASE_UBWC_CFG_0 = 0,
    parameter integer CASE_UBWC_CFG_1 = 0,
    parameter integer CASE_UBWC_CFG_2 = 0,
    parameter integer CASE_UBWC_CFG_3 = 0,
    parameter integer CASE_UBWC_CFG_4 = 0,
    parameter integer CASE_UBWC_CFG_5 = 0,
    parameter integer CASE_UBWC_CFG_6 = 0,
    parameter integer CASE_UBWC_CFG_7 = 0,
    parameter integer CASE_UBWC_CFG_8 = 0,
    parameter integer CASE_UBWC_CFG_9 = 0,
    parameter integer CASE_UBWC_CFG_10 = 0,
    parameter integer CASE_UBWC_CFG_11 = 0
) ();
    tb_ubwc_enc_wrapper_top_tajmahal_core #(
        .CASE_ID(CASE_ID),
        .IMG_W(IMG_W),
        .RGBA_ACTIVE_H(RGBA_ACTIVE_H),
        .RGBA_STORED_H(RGBA_STORED_H),
        .RGBA_TILE_PITCH(RGBA_TILE_PITCH),
        .RGBA_TILE_COLS(RGBA_TILE_COLS),
        .RGBA_TILE_ROWS(RGBA_TILE_ROWS),
        .RGBA_META_WORDS64(RGBA_META_WORDS64),
        .CFG_NV12_ACTIVE_H(CFG_NV12_ACTIVE_H),
        .CFG_NV12_Y_STORED_H(CFG_NV12_Y_STORED_H),
        .CFG_NV12_UV_STORED_H(CFG_NV12_UV_STORED_H),
        .CFG_NV12_TILE_PITCH(CFG_NV12_TILE_PITCH),
        .CFG_NV12_Y_TILE_COLS(CFG_NV12_Y_TILE_COLS),
        .CFG_NV12_UV_TILE_COLS(CFG_NV12_UV_TILE_COLS),
        .CFG_NV12_Y_TILE_ROWS(CFG_NV12_Y_TILE_ROWS),
        .CFG_NV12_UV_TILE_ROWS(CFG_NV12_UV_TILE_ROWS),
        .CFG_NV12_COMP_Y_WORDS64(CFG_NV12_COMP_Y_WORDS64),
        .CFG_NV12_COMP_UV_WORDS64(CFG_NV12_COMP_UV_WORDS64),
        .CFG_NV12_META_Y_WORDS64(CFG_NV12_META_Y_WORDS64),
        .CFG_NV12_META_UV_WORDS64(CFG_NV12_META_UV_WORDS64),
        .CFG_G016_ACTIVE_H(CFG_G016_ACTIVE_H),
        .CFG_G016_Y_STORED_H(CFG_G016_Y_STORED_H),
        .CFG_G016_UV_STORED_H(CFG_G016_UV_STORED_H),
        .CFG_G016_TILE_PITCH(CFG_G016_TILE_PITCH),
        .CFG_G016_Y_TILE_COLS(CFG_G016_Y_TILE_COLS),
        .CFG_G016_UV_TILE_COLS(CFG_G016_UV_TILE_COLS),
        .CFG_G016_Y_TILE_ROWS(CFG_G016_Y_TILE_ROWS),
        .CFG_G016_UV_TILE_ROWS(CFG_G016_UV_TILE_ROWS),
        .CFG_G016_COMP_Y_WORDS64(CFG_G016_COMP_Y_WORDS64),
        .CFG_G016_COMP_UV_WORDS64(CFG_G016_COMP_UV_WORDS64),
        .CFG_G016_META_Y_WORDS64(CFG_G016_META_Y_WORDS64),
        .CFG_G016_META_UV_WORDS64(CFG_G016_META_UV_WORDS64),
        .CFG_RGBA_TILE_BASE_Y_ADDR(CFG_RGBA_TILE_BASE_Y_ADDR),
        .CFG_RGBA_META_BASE_Y_ADDR(CFG_RGBA_META_BASE_Y_ADDR),
        .CFG_NV12_TILE_BASE_Y_ADDR(CFG_NV12_TILE_BASE_Y_ADDR),
        .CFG_NV12_TILE_BASE_UV_ADDR(CFG_NV12_TILE_BASE_UV_ADDR),
        .CFG_NV12_META_BASE_Y_ADDR(CFG_NV12_META_BASE_Y_ADDR),
        .CFG_NV12_META_BASE_UV_ADDR(CFG_NV12_META_BASE_UV_ADDR),
        .CFG_G016_TILE_BASE_Y_ADDR(CFG_G016_TILE_BASE_Y_ADDR),
        .CFG_G016_TILE_BASE_UV_ADDR(CFG_G016_TILE_BASE_UV_ADDR),
        .CFG_G016_META_BASE_Y_ADDR(CFG_G016_META_BASE_Y_ADDR),
        .CFG_G016_META_BASE_UV_ADDR(CFG_G016_META_BASE_UV_ADDR),
        .COM_BUF_AW(COM_BUF_AW),
        .CASE_TILE_EXPECT_LINEAR(CASE_TILE_EXPECT_LINEAR),
        .CASE_CI_LOSSY(CASE_CI_LOSSY),
        .CASE_UBWC_CFG_0(CASE_UBWC_CFG_0),
        .CASE_UBWC_CFG_1(CASE_UBWC_CFG_1),
        .CASE_UBWC_CFG_2(CASE_UBWC_CFG_2),
        .CASE_UBWC_CFG_3(CASE_UBWC_CFG_3),
        .CASE_UBWC_CFG_4(CASE_UBWC_CFG_4),
        .CASE_UBWC_CFG_5(CASE_UBWC_CFG_5),
        .CASE_UBWC_CFG_6(CASE_UBWC_CFG_6),
        .CASE_UBWC_CFG_7(CASE_UBWC_CFG_7),
        .CASE_UBWC_CFG_8(CASE_UBWC_CFG_8),
        .CASE_UBWC_CFG_9(CASE_UBWC_CFG_9),
        .CASE_UBWC_CFG_10(CASE_UBWC_CFG_10),
        .CASE_UBWC_CFG_11(CASE_UBWC_CFG_11)
    ) u_core ();
endmodule

module tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888 #(
    parameter integer COM_BUF_AW = 11
) ();
    tb_ubwc_enc_wrapper_top_tajmahal_core #(
        .CASE_ID(0),
        .COM_BUF_AW(COM_BUF_AW)
    ) u_core ();
endmodule

module tb_ubwc_enc_wrapper_top_rgba8888_128x128 #(
    parameter integer COM_BUF_AW = 11
) ();
    tb_ubwc_enc_wrapper_top_tajmahal_core #(
        .CASE_ID(0),
        .IMG_W(128),
        .RGBA_ACTIVE_H(128),
        .RGBA_STORED_H(128),
        .RGBA_TILE_PITCH(512),
        .RGBA_TILE_COLS(8),
        .RGBA_TILE_ROWS(32),
        .RGBA_META_WORDS64(256),
        .COM_BUF_AW(COM_BUF_AW)
    ) u_core ();
endmodule

module tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102 #(
    parameter integer COM_BUF_AW = 11
) ();
    tb_ubwc_enc_wrapper_top_tajmahal_core #(
        .CASE_ID(1),
        .COM_BUF_AW(COM_BUF_AW)
    ) u_core ();
endmodule

module tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12 #(
    parameter integer COM_BUF_AW = 11
) ();
    tb_ubwc_enc_wrapper_top_tajmahal_core #(
        .CASE_ID(2),
        .COM_BUF_AW(COM_BUF_AW)
    ) u_core ();
endmodule

module tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016 #(
    parameter integer COM_BUF_AW = 11
) ();
    tb_ubwc_enc_wrapper_top_tajmahal_core #(
        .CASE_ID(3),
        .COM_BUF_AW(COM_BUF_AW)
    ) u_core ();
endmodule

`default_nettype wire
