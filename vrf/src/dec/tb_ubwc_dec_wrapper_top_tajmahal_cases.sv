`timescale 1ns/1ps

module tb_dec_pdp_sram_delay #(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 13,
    parameter DEPTH      = 8192
) (
    input  wire                   clk,
    input  wire                   wen,
    input  wire [ADDR_WIDTH-1:0]  waddr,
    input  wire [DATA_WIDTH-1:0]  wdata,
    input  wire                   ren,
    input  wire [ADDR_WIDTH-1:0]  raddr,
    output reg  [DATA_WIDTH-1:0]  rdata,
    output reg                    rvalid
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] rdata_pipe [0:2];
    reg [2:0]            rvalid_pipe;
    integer              tb_bank_dly;
    integer              idx;

    initial begin
        rdata       = {DATA_WIDTH{1'b0}};
        rvalid      = 1'b0;
        rvalid_pipe = 3'd0;
        tb_bank_dly = 1;
        void'($value$plusargs("tb_bank_dly=%d", tb_bank_dly));
        if (tb_bank_dly < 1)
            tb_bank_dly = 1;
        if (tb_bank_dly > 4)
            tb_bank_dly = 4;
        for (idx = 0; idx < 3; idx = idx + 1)
            rdata_pipe[idx] = {DATA_WIDTH{1'b0}};
    end

    always @(posedge clk) begin
        if (wen)
            mem[waddr] <= wdata;
    end

    always @(posedge clk) begin
        rvalid <= 1'b0;
        rvalid_pipe <= {rvalid_pipe[1:0], 1'b0};
        rdata_pipe[2] <= rdata_pipe[1];
        rdata_pipe[1] <= rdata_pipe[0];
        if (ren) begin
            if (tb_bank_dly <= 1) begin
                rdata  <= mem[raddr];
                rvalid <= 1'b1;
            end else begin
                rdata_pipe[0]  <= mem[raddr];
                rvalid_pipe[0] <= 1'b1;
                rdata          <= rdata_pipe[tb_bank_dly - 2];
                rvalid         <= rvalid_pipe[tb_bank_dly - 2];
            end
        end else if (tb_bank_dly > 1) begin
            rdata  <= rdata_pipe[tb_bank_dly - 2];
            rvalid <= rvalid_pipe[tb_bank_dly - 2];
        end
    end
endmodule

module tb_dec_to_enc_sync_sram_1rw #(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 12,
    parameter DEPTH      = 4096
) (
    input  wire                   clk,
    input  wire                   en,
    input  wire                   wen,
    input  wire [ADDR_WIDTH-1:0]  addr,
    input  wire [DATA_WIDTH-1:0]  din,
    output reg  [DATA_WIDTH-1:0]  dout,
    output reg                    dout_vld
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] rdata_pipe [0:2];
    reg [2:0]            rvalid_pipe;
    integer              tb_bank_dly;
    integer              idx;

    initial begin
        dout        = {DATA_WIDTH{1'b0}};
        dout_vld    = 1'b0;
        rvalid_pipe = 3'd0;
        tb_bank_dly = 1;
        void'($value$plusargs("tb_bank_dly=%d", tb_bank_dly));
        if (tb_bank_dly < 1)
            tb_bank_dly = 1;
        if (tb_bank_dly > 4)
            tb_bank_dly = 4;
        for (idx = 0; idx < 3; idx = idx + 1)
            rdata_pipe[idx] = {DATA_WIDTH{1'b0}};
    end

    always @(posedge clk) begin
        dout_vld    <= 1'b0;
        rvalid_pipe <= {rvalid_pipe[1:0], 1'b0};
        rdata_pipe[2] <= rdata_pipe[1];
        rdata_pipe[1] <= rdata_pipe[0];
        if (en) begin
            if (wen) begin
                mem[addr] <= din;
            end else begin
                if (tb_bank_dly <= 1) begin
                    dout     <= mem[addr];
                    dout_vld <= 1'b1;
                end else begin
                    rdata_pipe[0]  <= mem[addr];
                    rvalid_pipe[0] <= 1'b1;
                    dout           <= rdata_pipe[tb_bank_dly - 2];
                    dout_vld       <= rvalid_pipe[tb_bank_dly - 2];
                end
            end
        end else if (tb_bank_dly > 1) begin
            dout     <= rdata_pipe[tb_bank_dly - 2];
            dout_vld <= rvalid_pipe[tb_bank_dly - 2];
        end
    end
endmodule

module tb_ubwc_dec_wrapper_top_tajmahal_core #(
    parameter integer CASE_ID = 0,
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0,
    parameter integer LOOP_TO_ENC = 0,
    parameter integer COM_BUF_AW = 12,
    parameter integer CASE_TILE_EXPECT_LINEAR = 0,
    parameter integer IMG_W = 4096,
    parameter integer RGBA_ACTIVE_H = 600,
    parameter integer RGBA_STORED_H = 608,
    parameter integer RGBA_TILE_X_COUNT = 256,
    parameter integer RGBA_TILE_Y_COUNT = 152,
    parameter integer RGBA_META_PITCH = 256,
    parameter integer RGBA_META_LINES = 160,
    parameter integer RGBA_META_WORDS64 = 0,
    parameter integer RGBA_TILE_PITCH = 16384,
    parameter integer CFG_NV12_ACTIVE_H = 600,
    parameter integer CFG_NV12_Y_STORED_H = 640,
    parameter integer CFG_NV12_UV_STORED_H = 320,
    parameter integer CFG_NV12_TILE_X_COUNT = 128,
    parameter integer CFG_NV12_Y_TILE_Y_COUNT = 80,
    parameter integer CFG_NV12_UV_TILE_Y_COUNT = 40,
    parameter integer CFG_NV12_META_PITCH = 128,
    parameter integer CFG_NV12_META_Y_LINES = 96,
    parameter integer CFG_NV12_META_UV_LINES = 64,
    parameter integer CFG_NV12_TILE_PITCH = 4096,
    parameter integer CFG_NV12_COMP_Y_WORDS64 = 311296,
    parameter integer CFG_NV12_COMP_UV_WORDS64 = 163840,
    parameter integer CFG_NV12_UNCOMP_Y_WORDS64 = 327680,
    parameter integer CFG_NV12_UNCOMP_UV_WORDS64 = 163840,
    parameter integer CFG_G016_ACTIVE_H = 600,
    parameter integer CFG_G016_Y_STORED_H = 608,
    parameter integer CFG_G016_UV_STORED_H = 304,
    parameter integer CFG_G016_TILE_X_COUNT = 128,
    parameter integer CFG_G016_Y_TILE_Y_COUNT = 152,
    parameter integer CFG_G016_UV_TILE_Y_COUNT = 76,
    parameter integer CFG_G016_META_PITCH = 128,
    parameter integer CFG_G016_META_Y_LINES = 160,
    parameter integer CFG_G016_META_UV_LINES = 96,
    parameter integer CFG_G016_TILE_PITCH = 8192,
    parameter integer CFG_G016_COMP_Y_WORDS64 = 622592,
    parameter integer CFG_G016_COMP_UV_WORDS64 = 311296,
    parameter integer CFG_G016_UNCOMP_Y_WORDS64 = 622592,
    parameter integer CFG_G016_UNCOMP_UV_WORDS64 = 311296,
    parameter [63:0] CFG_RGBA_TILE_BASE_Y_ADDR = 64'h0000_0000_0028_5000,
    parameter [63:0] CFG_RGBA_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_NV12_TILE_BASE_Y_ADDR = 64'h0000_0000_0000_3000,
    parameter [63:0] CFG_NV12_TILE_BASE_UV_ADDR = 64'h0000_0000_0028_5000,
    parameter [63:0] CFG_NV12_DUMP_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_3000,
    parameter [63:0] CFG_NV12_DUMP_TILE_BASE_UV_ADDR = 64'h0000_0000_8028_5000,
    parameter [63:0] CFG_NV12_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_NV12_META_BASE_UV_ADDR = 64'h0000_0000_8028_3000,
    parameter [63:0] CFG_G016_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_5000,
    parameter [63:0] CFG_G016_TILE_BASE_UV_ADDR = 64'h0000_0000_804c_8000,
    parameter [63:0] CFG_G016_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_G016_META_BASE_UV_ADDR = 64'h0000_0000_804c_5000,
    parameter integer CASE_OTF_H_TOTAL = 4400,
    parameter integer CASE_OTF_H_SYNC = 44,
    parameter integer CASE_OTF_H_BP = 148,
    parameter integer CFG_OTF_V_TOTAL = 682,
    parameter integer CFG_OTF_V_SYNC = 5,
    parameter integer CFG_OTF_V_BP = 36,
    parameter integer CASE_DEC_ROTATION = 0,
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
);

    function automatic integer ceil_div;
        input integer value;
        input integer divisor;
        begin
            if (value <= 0) begin
                ceil_div = 0;
            end else begin
                ceil_div = (value + divisor - 1) / divisor;
            end
        end
    endfunction

    function automatic [31:0] lfsr_next;
        input [31:0] state_in;
        reg feedback;
        begin
            feedback = state_in[31] ^ state_in[21] ^ state_in[1] ^ state_in[0];
            lfsr_next = {state_in[30:0], feedback};
            if (lfsr_next == 32'd0)
                lfsr_next = 32'h3c6e_f372;
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

    localparam integer CASE_RGBA8888    = 0;
    localparam integer CASE_RGBA1010102 = 1;
    localparam integer CASE_NV12        = 2;
    localparam integer CASE_G016        = 3;

    localparam integer APB_AW   = 16;
    localparam integer APB_DW   = 32;
    localparam integer AXI_AW   = 64;
    localparam integer AXI_DW   = 256;
    localparam integer M_AXI_DW = 128;
    localparam integer AXI_IDW  = 4;
    localparam integer AXI_LENW = 5;
    localparam integer SB_WIDTH = 3;
    localparam integer OTF_SRAM_DEPTH = (1 << COM_BUF_AW);

    localparam [AXI_AW-1:0] CFG_RGBA_TILE_BASE_Y_ADDR_Z     = {{(AXI_AW-32){1'b0}}, CFG_RGBA_TILE_BASE_Y_ADDR[31:0]};
    localparam [AXI_AW-1:0] CFG_RGBA_META_BASE_Y_ADDR_Z     = {{(AXI_AW-32){1'b0}}, CFG_RGBA_META_BASE_Y_ADDR[31:0]};
    localparam [AXI_AW-1:0] CFG_NV12_TILE_BASE_Y_ADDR_Z     = {{(AXI_AW-32){1'b0}}, CFG_NV12_TILE_BASE_Y_ADDR[31:0]};
    localparam [AXI_AW-1:0] CFG_NV12_TILE_BASE_UV_ADDR_Z    = {{(AXI_AW-32){1'b0}}, CFG_NV12_TILE_BASE_UV_ADDR[31:0]};
    localparam [AXI_AW-1:0] CFG_NV12_DUMP_TILE_BASE_Y_ADDR_Z  = {{(AXI_AW-32){1'b0}}, CFG_NV12_DUMP_TILE_BASE_Y_ADDR[31:0]};
    localparam [AXI_AW-1:0] CFG_NV12_DUMP_TILE_BASE_UV_ADDR_Z = {{(AXI_AW-32){1'b0}}, CFG_NV12_DUMP_TILE_BASE_UV_ADDR[31:0]};
    localparam [AXI_AW-1:0] CFG_NV12_META_BASE_Y_ADDR_Z     = {{(AXI_AW-32){1'b0}}, CFG_NV12_META_BASE_Y_ADDR[31:0]};
    localparam [AXI_AW-1:0] CFG_NV12_META_BASE_UV_ADDR_Z    = {{(AXI_AW-32){1'b0}}, CFG_NV12_META_BASE_UV_ADDR[31:0]};
    localparam [AXI_AW-1:0] CFG_G016_TILE_BASE_Y_ADDR_Z     = {{(AXI_AW-32){1'b0}}, CFG_G016_TILE_BASE_Y_ADDR[31:0]};
    localparam [AXI_AW-1:0] CFG_G016_TILE_BASE_UV_ADDR_Z    = {{(AXI_AW-32){1'b0}}, CFG_G016_TILE_BASE_UV_ADDR[31:0]};
    localparam [AXI_AW-1:0] CFG_G016_META_BASE_Y_ADDR_Z     = {{(AXI_AW-32){1'b0}}, CFG_G016_META_BASE_Y_ADDR[31:0]};
    localparam [AXI_AW-1:0] CFG_G016_META_BASE_UV_ADDR_Z    = {{(AXI_AW-32){1'b0}}, CFG_G016_META_BASE_UV_ADDR[31:0]};

    localparam [4:0] BASE_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] BASE_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] BASE_FMT_YUV420_8    = 5'b00010;
    localparam [4:0] BASE_FMT_YUV420_10   = 5'b00011;

    localparam [4:0] META_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] META_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] META_FMT_NV12_Y      = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV     = 5'b01001;
    localparam [4:0] META_FMT_P010_Y      = 5'b01110;
    localparam [4:0] META_FMT_P010_UV     = 5'b01111;
    localparam integer CASE_LOSSY_RGBA_2_1 = 0;
    localparam [1:0] DEC_META_PHASE_UV    = 2'd0;
    localparam [1:0] DEC_META_PHASE_YH    = 2'd1;
    localparam [1:0] DEC_META_PHASE_YL    = 2'd2;

    localparam integer RGBA_HIGHEST_BANK   = 16;
    localparam integer RGBA_ACTIVE_TILE_Y_COUNT = ceil_div(RGBA_ACTIVE_H, 4);
    localparam integer RGBA_META_WORDS64_CALC = (RGBA_META_PITCH * RGBA_META_LINES) / 8;
    localparam integer RGBA_META_WORDS64_USED = (RGBA_META_WORDS64 != 0) ?
                                                RGBA_META_WORDS64 :
                                                RGBA_META_WORDS64_CALC;
    localparam integer RGBA_TILE_WORDS64   = (RGBA_TILE_PITCH * RGBA_STORED_H) / 8;

    localparam integer NV12_ACTIVE_H       = CFG_NV12_ACTIVE_H;
    localparam integer NV12_Y_STORED_H     = CFG_NV12_Y_STORED_H;
    localparam integer NV12_UV_STORED_H    = CFG_NV12_UV_STORED_H;
    localparam integer NV12_TILE_X_COUNT   = CFG_NV12_TILE_X_COUNT;
    localparam integer NV12_Y_TILE_Y_COUNT = CFG_NV12_Y_TILE_Y_COUNT;
    localparam integer NV12_UV_TILE_Y_COUNT= CFG_NV12_UV_TILE_Y_COUNT;
    localparam integer NV12_Y_ACTIVE_TILE_Y_COUNT = ceil_div(NV12_ACTIVE_H, 8);
    localparam integer NV12_UV_ACTIVE_TILE_Y_COUNT= ceil_div(NV12_Y_ACTIVE_TILE_Y_COUNT, 2);
    localparam integer NV12_META_PITCH     = CFG_NV12_META_PITCH;
    localparam integer NV12_META_Y_LINES   = CFG_NV12_META_Y_LINES;
    localparam integer NV12_META_UV_LINES  = CFG_NV12_META_UV_LINES;
    localparam integer NV12_TILE_PITCH     = CFG_NV12_TILE_PITCH;
    localparam integer NV12_HIGHEST_BANK   = 16;
    localparam integer NV12_Y_META_WORDS64 = (NV12_META_PITCH * NV12_META_Y_LINES) / 8;
    localparam integer NV12_UV_META_WORDS64= (NV12_META_PITCH * NV12_META_UV_LINES) / 8;
    localparam integer NV12_Y_TILE_WORDS64 = CFG_NV12_UNCOMP_Y_WORDS64;
    localparam integer NV12_UV_TILE_WORDS64= CFG_NV12_UNCOMP_UV_WORDS64;
    localparam integer NV12_Y_CMP_WORDS64  = CFG_NV12_COMP_Y_WORDS64;
    localparam integer NV12_UV_CMP_WORDS64 = CFG_NV12_COMP_UV_WORDS64;

    localparam integer G016_ACTIVE_H        = CFG_G016_ACTIVE_H;
    localparam integer G016_Y_STORED_H      = CFG_G016_Y_STORED_H;
    localparam integer G016_UV_STORED_H     = CFG_G016_UV_STORED_H;
    localparam integer G016_TILE_X_COUNT    = CFG_G016_TILE_X_COUNT;
    localparam integer G016_Y_TILE_Y_COUNT  = CFG_G016_Y_TILE_Y_COUNT;
    localparam integer G016_UV_TILE_Y_COUNT = CFG_G016_UV_TILE_Y_COUNT;
    localparam integer G016_Y_ACTIVE_TILE_Y_COUNT  = ceil_div(G016_ACTIVE_H, 4);
    localparam integer G016_UV_ACTIVE_TILE_Y_COUNT = ceil_div(G016_Y_ACTIVE_TILE_Y_COUNT, 2);
    localparam integer G016_META_PITCH      = CFG_G016_META_PITCH;
    localparam integer G016_META_Y_LINES    = CFG_G016_META_Y_LINES;
    localparam integer G016_META_UV_LINES   = CFG_G016_META_UV_LINES;
    localparam integer G016_TILE_PITCH      = CFG_G016_TILE_PITCH;
    localparam integer G016_HIGHEST_BANK    = 16;
    localparam integer G016_Y_META_WORDS64  = (G016_META_PITCH * G016_META_Y_LINES) / 8;
    localparam integer G016_UV_META_WORDS64 = (G016_META_PITCH * G016_META_UV_LINES) / 8;
    localparam integer G016_Y_TILE_WORDS64  = CFG_G016_UNCOMP_Y_WORDS64;
    localparam integer G016_UV_TILE_WORDS64 = CFG_G016_UNCOMP_UV_WORDS64;
    localparam integer G016_Y_CMP_WORDS64   = CFG_G016_COMP_Y_WORDS64;
    localparam integer G016_UV_CMP_WORDS64  = CFG_G016_COMP_UV_WORDS64;

    localparam integer CASE_IS_NV12         = (CASE_ID == CASE_NV12);
    localparam integer CASE_IS_G016         = (CASE_ID == CASE_G016);
    localparam integer CASE_IS_RGBA1010102  = (CASE_ID == CASE_RGBA1010102);
    localparam integer CASE_IS_LOSSY_RGBA_2_1 = (CASE_ID == CASE_RGBA8888) && (CASE_CI_LOSSY != 0);
    localparam integer CASE_HAS_PLANE1      = CASE_IS_NV12 || CASE_IS_G016;

    localparam [4:0] CASE_BASE_FORMAT = CASE_IS_G016
                                      ? BASE_FMT_YUV420_10
                                      : (CASE_IS_NV12
                                         ? BASE_FMT_YUV420_8
                                         : (CASE_IS_RGBA1010102 ? BASE_FMT_RGBA1010102 : BASE_FMT_RGBA8888));
    localparam integer CASE_TILE_X_NUMBERS = CASE_IS_G016 ? G016_TILE_X_COUNT :
                                             (CASE_IS_NV12 ? NV12_TILE_X_COUNT : RGBA_TILE_X_COUNT);
    localparam integer CASE_TILE_Y_NUMBERS = CASE_IS_G016 ? G016_Y_ACTIVE_TILE_Y_COUNT :
                                             (CASE_IS_NV12 ? NV12_Y_ACTIVE_TILE_Y_COUNT : RGBA_ACTIVE_TILE_Y_COUNT);
    localparam integer CASE_META_X_SAMPLES = CASE_TILE_X_NUMBERS;
    localparam integer CASE_META_ACTIVE_X_NUMBERS = CASE_HAS_PLANE1 ?
                                                    (ceil_div(IMG_W, 128) * 4) :
                                                    (ceil_div(IMG_W, 64) * 4);
    localparam integer CASE_EXPECTED_CI_CMDS = CASE_IS_G016
                                             ? (CASE_META_X_SAMPLES * (G016_Y_ACTIVE_TILE_Y_COUNT + G016_UV_ACTIVE_TILE_Y_COUNT))
                                             : (CASE_IS_NV12
                                                ? (CASE_META_X_SAMPLES * (NV12_Y_ACTIVE_TILE_Y_COUNT + NV12_UV_ACTIVE_TILE_Y_COUNT))
                                                : (CASE_META_X_SAMPLES * RGBA_ACTIVE_TILE_Y_COUNT));
    localparam integer MAX_FRAME_REPEAT = 100;
    localparam integer CASE_MAX_EXPECTED_CI_CMDS = CASE_EXPECTED_CI_CMDS * MAX_FRAME_REPEAT;
    localparam integer CASE_EXPECTED_DEC_META_SAMPLES = CASE_EXPECTED_CI_CMDS;
    localparam integer CASE_FULL_TILE_BEATS   = 8;
    localparam integer CASE_TILE_PITCH_BYTES = CASE_IS_G016 ? G016_TILE_PITCH :
                                               (CASE_IS_NV12 ? NV12_TILE_PITCH : RGBA_TILE_PITCH);
    localparam integer CASE_TILE_PITCH_UNITS = CASE_TILE_PITCH_BYTES / 16;
    localparam integer CASE_INPUT_V_ACT      = CASE_IS_G016 ? G016_ACTIVE_H :
                                               (CASE_IS_NV12 ? NV12_ACTIVE_H : RGBA_ACTIVE_H);
    localparam integer CASE_DEC_ROTATE_EN    = (CASE_DEC_ROTATION == 90) ||
                                               (CASE_DEC_ROTATION == 270);
    localparam integer CASE_ROTATE_MODE      = (CASE_DEC_ROTATION == 90)  ? 1 :
                                               (CASE_DEC_ROTATION == 270) ? 2 : 0;
    localparam integer CASE_OTF_H_ACT        = CASE_DEC_ROTATE_EN ? CASE_INPUT_V_ACT : IMG_W;
    localparam integer CASE_OTF_V_ACT        = CASE_DEC_ROTATE_EN ? IMG_W : CASE_INPUT_V_ACT;
    localparam integer CASE_OTF_V_TOTAL      = CFG_OTF_V_TOTAL;
    localparam integer CASE_OTF_BEATS_PER_LINE= ceil_div(CASE_OTF_H_ACT, 4);
    localparam integer CASE_EXPECTED_OTF_BEATS= CASE_OTF_BEATS_PER_LINE * CASE_OTF_V_ACT;
    localparam integer CASE_TIMEOUT_CYCLES   = CASE_HAS_PLANE1 ? 12000000 : 16000000;
    // With OTF at 100MHz and full porch timing, active pixels can start
    // hundreds of microseconds after frame start, so the AXI-side watchdog
    // must allow a much longer no-progress window than the legacy single-clock TB.
    localparam integer CASE_IDLE_GAP_CYCLES  = 4000000;
    localparam integer CASE_META0_WORDS64    = CASE_IS_G016 ? G016_Y_META_WORDS64 :
                                               (CASE_IS_NV12 ? NV12_Y_META_WORDS64 : RGBA_META_WORDS64_USED);
    localparam integer CASE_META1_WORDS64    = CASE_IS_G016 ? G016_UV_META_WORDS64 :
                                               (CASE_IS_NV12 ? NV12_UV_META_WORDS64 : 1);
    localparam integer CASE_META_PITCH_BYTES  = ceil_div(CASE_TILE_X_NUMBERS, 64) * 64;
    localparam integer CASE_TILE0_WORDS64    = CASE_IS_G016 ? G016_Y_TILE_WORDS64 :
                                               (CASE_IS_NV12 ? NV12_Y_TILE_WORDS64 : RGBA_TILE_WORDS64);
    localparam integer CASE_TILE1_WORDS64    = CASE_IS_G016 ? G016_UV_TILE_WORDS64 :
                                               (CASE_IS_NV12 ? NV12_UV_TILE_WORDS64 : 1);
    localparam integer CASE_CMP0_WORDS64     = CASE_IS_G016 ? G016_Y_CMP_WORDS64 :
                                               (CASE_IS_NV12 ? NV12_Y_CMP_WORDS64 : CASE_TILE0_WORDS64);
    localparam integer CASE_CMP1_WORDS64     = CASE_IS_G016 ? G016_UV_CMP_WORDS64 :
                                               (CASE_IS_NV12 ? NV12_UV_CMP_WORDS64 : 1);
    localparam [SB_WIDTH-1:0] CASE_CI_SB     = {SB_WIDTH{1'b1}};

    localparam [AXI_AW-1:0] CASE_TILE_BASE_ADDR_Y = CASE_IS_G016 ? CFG_G016_TILE_BASE_Y_ADDR_Z :
                                                     (CASE_IS_NV12 ? CFG_NV12_TILE_BASE_Y_ADDR_Z : CFG_RGBA_TILE_BASE_Y_ADDR_Z);
    localparam [AXI_AW-1:0] CASE_TILE_BASE_ADDR_UV = CASE_IS_G016 ? CFG_G016_TILE_BASE_UV_ADDR_Z :
                                                      CFG_NV12_TILE_BASE_UV_ADDR_Z;
    localparam [AXI_AW-1:0] CASE_DUMP_TILE_BASE_ADDR_Y = CASE_IS_G016 ? CFG_G016_TILE_BASE_Y_ADDR_Z :
                                                          (CASE_IS_NV12 ? CFG_NV12_DUMP_TILE_BASE_Y_ADDR_Z : CASE_TILE_BASE_ADDR_Y);
    localparam [AXI_AW-1:0] CASE_DUMP_TILE_BASE_ADDR_UV = CASE_IS_G016 ? CFG_G016_TILE_BASE_UV_ADDR_Z :
                                                           CFG_NV12_DUMP_TILE_BASE_UV_ADDR_Z;
    localparam [AXI_AW-1:0] CASE_META_BASE_ADDR_Y = CASE_IS_G016 ? CFG_G016_META_BASE_Y_ADDR_Z :
                                                    (CASE_IS_NV12 ? CFG_NV12_META_BASE_Y_ADDR_Z : CFG_RGBA_META_BASE_Y_ADDR_Z);
    localparam [AXI_AW-1:0] CASE_META_BASE_ADDR_UV = CASE_IS_G016 ? CFG_G016_META_BASE_UV_ADDR_Z :
                                                      CFG_NV12_META_BASE_UV_ADDR_Z;
    localparam integer CASE_HIGHEST_BANK = CASE_IS_G016 ? G016_HIGHEST_BANK :
                                           (CASE_IS_NV12 ? NV12_HIGHEST_BANK : RGBA_HIGHEST_BANK);

    localparam real TB_APB_CLK_HALF_NS   = 5.0000;   // 100 MHz
    localparam real TB_AXI_CLK_HALF_NS   = 1.0000;   // 500 MHz
    localparam real TB_CORE_CLK_HALF_NS  = 2.5000;   // 200 MHz
    localparam real TB_OTF_CLK_HALF_NS   = 1.5625;   // 320 MHz

    reg                       PCLK;
    reg                       PRESETn;
    reg                       PSEL;
    reg                       PENABLE;
    reg  [APB_AW-1:0]         PADDR;
    reg                       PWRITE;
    reg  [APB_DW-1:0]         PWDATA;
    wire                      PREADY;
    wire                      PSLVERR;
    wire [APB_DW-1:0]         PRDATA;

    reg                       i_axi_clk;
    reg                       i_axi_rstn;
    reg                       i_vivo_clk;
    reg                       i_otf_clk;
    reg                       i_otf_rstn;
    reg                       i_vivo_rstn;

    wire                      o_otf_vsync;
    wire                      o_otf_hsync;
    wire                      o_otf_de;
    wire [127:0]              o_otf_data;
    wire [3:0]                o_otf_fcnt;
    wire [11:0]               o_otf_lcnt;
    wire                      tb_otf_vsync;
    wire                      tb_otf_hsync;
    wire                      tb_otf_de;
    wire [127:0]              tb_otf_data;
    wire [3:0]                tb_otf_fcnt;
    wire [11:0]               tb_otf_lcnt;
    reg                       i_otf_ready;
    wire                      dec_i_otf_ready_eff;
    reg  [1:0]                otf_ready_div;

    reg                       enc_PSEL;
    reg                       enc_PENABLE;
    reg  [APB_AW-1:0]         enc_PADDR;
    reg                       enc_PWRITE;
    reg  [APB_DW-1:0]         enc_PWDATA;
    wire                      enc_PREADY;
    wire                      enc_PSLVERR;
    wire [APB_DW-1:0]         enc_PRDATA;
    wire                      enc_o_otf_ready;
    wire                      enc_bank0_en;
    wire                      enc_bank0_wen;
    wire [COM_BUF_AW-1:0]     enc_bank0_addr;
    wire [127:0]              enc_bank0_din;
    wire [127:0]              enc_bank0_dout;
    wire                      enc_bank0_dout_vld;
    wire                      enc_bank1_en;
    wire                      enc_bank1_wen;
    wire [COM_BUF_AW-1:0]     enc_bank1_addr;
    wire [127:0]              enc_bank1_din;
    wire [127:0]              enc_bank1_dout;
    wire                      enc_bank1_dout_vld;
    wire [AXI_IDW:0]          enc_o_m_axi_awid;
    wire [AXI_AW-1:0]         enc_o_m_axi_awaddr;
    wire [AXI_LENW-1:0]       enc_o_m_axi_awlen;
    wire [2:0]                enc_o_m_axi_awsize;
    wire [1:0]                enc_o_m_axi_awburst;
    wire [1:0]                enc_o_m_axi_awlock;
    wire [3:0]                enc_o_m_axi_awcache;
    wire [2:0]                enc_o_m_axi_awprot;
    wire                      enc_o_m_axi_awvalid;
    reg                       enc_i_m_axi_awready;
    wire [M_AXI_DW-1:0]       enc_o_m_axi_wdata;
    wire [(M_AXI_DW/8)-1:0]   enc_o_m_axi_wstrb;
    wire                      enc_o_m_axi_wvalid;
    wire                      enc_o_m_axi_wlast;
    reg                       enc_i_m_axi_wready;
    reg  [AXI_IDW:0]          enc_i_m_axi_bid;
    reg  [1:0]                enc_i_m_axi_bresp;
    reg                       enc_i_m_axi_bvalid;
    wire                      enc_o_m_axi_bready;
    wire [7:0]                enc_o_stage_done;
    wire                      enc_o_frame_done;
    wire                      enc_o_irq;
    wire                      loop_enc_coord_fifo_rd_en;
    wire                      loop_enc_coord_fifo_valid;
    wire                      loop_enc_coord_fifo_empty;
    wire [4:0]                loop_enc_coord_format;
    wire [15:0]               loop_enc_coord_x;
    wire [15:0]               loop_enc_coord_y;
    wire [15:0]               loop_enc_coord_cols;
    wire [15:0]               loop_enc_coord_rows;
    wire                      loop_enc_coord_last_col;
    wire                      loop_enc_coord_last_row;
    wire                      loop_enc_coord_is_yuv420;
    wire                      loop_enc_coord_is_uv_plane;
    wire                      loop_enc_coord_yuv_last_uv;
    wire                      loop_enc_coord_frame_last;
    wire                      loop_enc_addr_cfg_done_pulse;
    wire                      loop_enc_correct_irq_pulse;
    wire [1:0]                loop_enc_l2t_rd_state;
    wire                      loop_enc_l2t_rd_plane;
    wire                      loop_enc_l2t_rd_uv_mode;
    wire [15:0]               loop_enc_l2t_rd_tile_x;
    wire [15:0]               loop_enc_l2t_rd_group_y;
    wire [15:0]               loop_enc_l2t_rd_word;
    wire                      loop_enc_l2t_issue_read;
    wire                      loop_enc_l2t_read_grant;
    wire                      loop_enc_l2t_uv_read_allowed;
    wire                      loop_enc_l2t_resp_afull;
    wire                      loop_enc_l2t_meta_afull;
    wire                      loop_enc_l2t_resp_empty;
    wire                      loop_enc_l2t_resp_valid;
    wire                      loop_enc_l2t_meta_empty;
    wire                      loop_enc_l2t_meta_valid;
    wire                      loop_enc_l2t_tile_vld;
    wire                      loop_enc_l2t_tile_rdy;
    wire                      loop_enc_l2t_data_fifo_full;
    wire                      loop_enc_l2t_data_fifo_afull;
    wire                      loop_enc_l2t_ci_fifo_full;
    wire                      loop_enc_l2t_coord_fifo_full;
    wire                      loop_enc_l2t_half_valid;
    wire                      loop_enc_l2t_half_last;
    wire                      loop_enc_l2t_flush_half_only;
    wire                      loop_enc_l2t_pack_second_fire;
    wire                      loop_enc_wrap_ci_valid;
    wire                      loop_enc_wrap_ci_ready;
    wire                      loop_enc_wrap_co_valid;
    wire                      loop_enc_wrap_co_ready;
    wire                      loop_enc_wrap_vivo_co_valid;
    wire                      loop_enc_wrap_vivo_co_ready;
    wire                      loop_enc_wrap_co_fifo_full;
    wire                      loop_enc_wrap_co_fifo_empty;
    wire                      loop_enc_wrap_cvo_valid;
    wire                      loop_enc_wrap_cvo_ready;
    wire                      loop_enc_wrap_vivo_cvo_valid;
    wire                      loop_enc_wrap_vivo_cvo_ready;
    wire                      loop_enc_wrap_cvo_fifo_full;
    wire                      loop_enc_wrap_cvo_fifo_empty;
    wire                      loop_enc_wrap_tile_addr_vld;
    wire                      loop_enc_wrap_fake_cmd_valid;
    wire [3:0]                loop_enc_wrap_fake_cvo_beat_idx;
    wire [3:0]                loop_enc_wrap_fake_cvo_total_beats;
    wire [3:0]                loop_enc_wrap_fake_cvo_valid_beats;
    wire                      loop_enc_wrap_fake_cvo_fire;
    wire                      loop_enc_wrap_fake_cvo_last;

    wire                      o_otf_sram_a_wen;
    wire [COM_BUF_AW-1:0]     o_otf_sram_a_waddr;
    wire [127:0]              o_otf_sram_a_wdata;
    wire                      o_otf_sram_a_ren;
    wire [COM_BUF_AW-1:0]     o_otf_sram_a_raddr;
    wire [127:0]              i_otf_sram_a_rdata;
    wire                      o_otf_sram_b_wen;
    wire [COM_BUF_AW-1:0]     o_otf_sram_b_waddr;
    wire [127:0]              o_otf_sram_b_wdata;
    wire                      o_otf_sram_b_ren;
    wire [COM_BUF_AW-1:0]     o_otf_sram_b_raddr;
    wire [127:0]              i_otf_sram_b_rdata;
    wire                      o_bank0_en;
    wire                      o_bank0_wen;
    wire [COM_BUF_AW-1:0]     o_bank0_addr;
    wire [127:0]              o_bank0_din;
    wire [127:0]              i_bank0_dout;
    wire                      i_bank0_dout_vld;
    wire                      o_bank1_en;
    wire                      o_bank1_wen;
    wire [COM_BUF_AW-1:0]     o_bank1_addr;
    wire [127:0]              o_bank1_din;
    wire [127:0]              i_bank1_dout;
    wire                      i_bank1_dout_vld;

    wire                      fake_otf_sram_a_wen;
    wire [COM_BUF_AW-1:0]     fake_otf_sram_a_waddr;
    wire [127:0]              fake_otf_sram_a_wdata;
    wire                      fake_otf_sram_a_ren;
    wire [COM_BUF_AW-1:0]     fake_otf_sram_a_raddr;
    wire [127:0]              fake_otf_sram_a_rdata;
    wire                      fake_otf_sram_b_wen;
    wire [COM_BUF_AW-1:0]     fake_otf_sram_b_waddr;
    wire [127:0]              fake_otf_sram_b_wdata;
    wire                      fake_otf_sram_b_ren;
    wire [COM_BUF_AW-1:0]     fake_otf_sram_b_raddr;
    wire [127:0]              fake_otf_sram_b_rdata;
    wire                      fake_o_otf_vsync;
    wire                      fake_o_otf_hsync;
    wire                      fake_o_otf_de;
    wire [127:0]              fake_o_otf_data;
    wire [3:0]                fake_o_otf_fcnt;
    wire [11:0]               fake_o_otf_lcnt;
    wire                      fake_otf_sram_a_rvalid;
    wire                      fake_otf_sram_b_rvalid;
    wire                      fake_correct_irq_pulse;
    wire [31:0]               fake_otf_line_count;
    wire [31:0]               fake_otf_de_count;
    wire                      inject_axis_tile_ready;
    wire                      inject_axis_tready;

    wire [AXI_IDW:0]          o_m_axi_arid;
    wire [AXI_AW-1:0]         o_m_axi_araddr;
    wire [AXI_LENW-1:0]       o_m_axi_arlen;
    wire [3:0]                o_m_axi_arsize;
    wire [1:0]                o_m_axi_arburst;
    wire [0:0]                o_m_axi_arlock;
    wire [3:0]                o_m_axi_arcache;
    wire [2:0]                o_m_axi_arprot;
    wire                      o_m_axi_arvalid;
    reg                       i_m_axi_arready;
    reg  [AXI_IDW:0]          i_m_axi_rid;
    reg  [M_AXI_DW-1:0]       i_m_axi_rdata;
    reg                       i_m_axi_rvalid;
    reg  [1:0]                i_m_axi_rresp;
    reg                       i_m_axi_rlast;
    wire                      o_m_axi_rready;
    wire [4:0]                o_stage_done;
    wire                      o_frame_done;
    wire                      o_irq;

    reg  [63:0]               meta_plane0_words [0:CASE_META0_WORDS64-1];
    reg  [63:0]               meta_plane1_words [0:CASE_META1_WORDS64-1];
    reg  [63:0]               tile_plane0_words [0:CASE_CMP0_WORDS64-1];
    reg  [63:0]               tile_plane1_words [0:CASE_CMP1_WORDS64-1];
    reg  [63:0]               ref_tile_plane0_words [0:CASE_TILE0_WORDS64-1];
    reg  [63:0]               ref_tile_plane1_words [0:CASE_TILE1_WORDS64-1];
    reg  [63:0]               actual_rvo_plane0_words [0:CASE_TILE0_WORDS64-1];
    reg  [63:0]               actual_rvo_plane1_words [0:CASE_TILE1_WORDS64-1];
    reg  [127:0]              expected_otf_beats [0:CASE_EXPECTED_OTF_BEATS-1];

    reg  [4:0]                tile_fmt_queue [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg  [11:0]               tile_x_queue   [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg  [9:0]                tile_y_queue   [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg  [2:0]                tile_alen_queue[0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg  [AXI_AW-1:0]         tile_addr_queue[0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg  [4:0]                ci_fmt_queue   [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg  [11:0]               ci_x_queue     [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg  [9:0]                ci_y_queue     [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg                       ci_input_type_queue [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg  [2:0]                ci_alen_queue      [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg  [3:0]                ci_metadata_queue  [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg                       ci_lossy_queue     [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg  [1:0]                ci_alpha_mode_queue[0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg  [SB_WIDTH-1:0]       ci_sb_queue        [0:CASE_MAX_EXPECTED_CI_CMDS-1];

    reg                       axi_rsp_active;
    reg                       axi_rsp_is_meta;
    reg                       axi_rsp_meta_plane1;
    reg  [AXI_AW-1:0]         axi_rsp_addr;
    reg  [AXI_IDW:0]          axi_rsp_id;
    reg  [7:0]                axi_rsp_beats_left;
    reg  [7:0]                axi_rsp_beat_idx;
    reg  [4:0]                axi_rsp_tile_fmt;
    reg  [11:0]               axi_rsp_tile_x;
    reg  [9:0]                axi_rsp_tile_y;
    integer                   axi_rsp_wait_cycles;
    integer                   tile_queue_wr_ptr;
    integer                   tile_queue_rd_ptr;
    integer                   ci_queue_wr_ptr;
    integer                   cmp_tile_rd_ptr;
    integer                   cmp_tile_beat_idx;
    integer                   meta_ar_cnt;
    integer                   meta_ar_plane0_cnt;
    integer                   meta_ar_plane1_cnt;
    integer                   tile_ar_cnt;
    integer                   axi_rbeat_cnt;
    integer                   meta_rbeat_cnt;
    integer                   tile_rbeat_cnt;
    integer                   tile_rbeat_no_rvo_cnt;
    integer                   ci_accept_cnt;
    integer                   payload_cmd_cnt;
    integer                   expected_rvo_beats_total;
    integer                   expected_ci_cmds_total;
    integer                   expected_dec_meta_samples_total;
    integer                   expected_otf_beats_total;
    integer                   expected_rvo_last_total;
    integer                   rvo_beat_cnt;
    integer                   rvo_last_cnt;
    integer                   co_active_cycle_cnt;
    integer                   ar_addr_mismatch_cnt;
    integer                   ar_len_mismatch_cnt;
    integer                   rvo_data_mismatch_cnt;
    integer                   rvo_last_mismatch_cnt;
    integer                   co_mismatch_cnt;
    integer                   tile_queue_underflow_cnt;
    integer                   writer_vld_cnt;
    integer                   writer_hdr_fire_cnt;
    integer                   writer_data_fire_cnt;
    integer                   writer_data_rd_cnt;
    integer                   fetcher_done_cnt;
    integer                   fifo_wr_cnt;
    integer                   fifo_rd_cnt;
    integer                   otf_fifo_empty_need_cnt;
    integer                   first_otf_fifo_empty_need_beat;
    integer                   otf_underflow_cnt;
    integer                   fake_writer_vld_cnt;
    integer                   fake_fetcher_done_cnt;
    integer                   fake_fifo_wr_cnt;
    integer                   fake_fifo_rd_cnt;
    integer                   fake_hdr_hs_cnt;
    integer                   fake_data_hs_cnt;
    integer                   fake_sram_wen_cnt;
    integer                   fake_tile_last_write_cnt;
    integer                   fake_slice_done_cnt;
    integer                   fake_hdr_last_x_hs_cnt;
    integer                   fake_hdr_x_max_seen;
    integer                   enc_aw_cnt;
    integer                   enc_w_cnt;
    integer                   enc_b_cnt;
    integer                   enc_b_wr_ptr;
    integer                   enc_b_rd_ptr;
    integer                   loop_enc_coord_rd_cnt;
    integer                   loop_enc_coord_uv_rd_cnt;
    integer                   loop_enc_coord_frame_last_cnt;
    reg [AXI_IDW:0]           enc_b_id_queue [0:(CASE_MAX_EXPECTED_CI_CMDS*2)-1];
    reg [4:0]                 loop_enc_last_coord_format;
    reg [15:0]                loop_enc_last_coord_x;
    reg [15:0]                loop_enc_last_coord_y;
    reg [15:0]                loop_enc_last_coord_cols;
    reg [15:0]                loop_enc_last_coord_rows;
    reg                       loop_enc_last_coord_uv;
    reg                       loop_enc_last_coord_last_col;
    reg                       loop_enc_last_coord_last_row;
    reg                       loop_enc_last_coord_frame_last;
    reg [4:0]                 loop_enc_last_uv_format;
    reg [15:0]                loop_enc_last_uv_x;
    reg [15:0]                loop_enc_last_uv_y;
    reg [15:0]                loop_enc_last_uv_cols;
    reg [15:0]                loop_enc_last_uv_rows;
    reg                       loop_enc_last_uv_last_col;
    reg                       loop_enc_last_uv_last_row;
    reg                       loop_enc_last_uv_frame_last;
    integer                   m_rhandshake_cnt;
    integer                   m_r_nosink_cnt;
    integer                   m_r_nosink_meta_cnt;
    integer                   m_r_nosink_tile_cnt;
    integer                   rbuf_meta_drain_cnt;
    integer                   rbuf_tile_drain_cnt;
    integer                   axi_rdata_cccc_cnt;
    integer                   axi_rdata_cccc_meta_cnt;
    integer                   axi_rdata_cccc_tile_cnt;
    integer                   first_axi_rdata_cccc_cycle;
    integer                   first_axi_rdata_cccc_lane;
    integer                   stream_fd;
    integer                   expected_stream_fd;
    integer                   stream_plane0_fd;
    integer                   expected_stream_plane0_fd;
    integer                   stream_plane1_fd;
    integer                   expected_stream_plane1_fd;
    integer                   dec_meta_actual_fd;
    integer                   dec_meta_expected_fd;
    integer                   vivo_ci_fd [0:5];
    integer                   vivo_cvi_fd [0:5];
    integer                   vivo_rvo_fd [0:5];
    integer                   vivo_ci_dump_cnt [0:5];
    integer                   vivo_cvi_dump_cnt [0:5];
    integer                   vivo_rvo_dump_cnt [0:5];
    integer                   otf_fd;
    integer                   compressed_tile_in_fd;
    integer                   summary_fd;
    integer                   fc_sc_event_fd;
    integer                   fc_sc_event_cnt;
    integer                   cycle_cnt;
    integer                   last_progress_cycle;
    integer                   last_otf_progress_cycle;
    integer                   timeout_cycles;
    integer                   tb_timeout_limit_cycles;
    integer                   tb_idle_gap_limit_cycles;
    integer                   tb_frame_repeat;
    integer                   tb_program_frame_idx;
    integer                   tb_enc_status_wait_cycles;
    integer                   tb_otf_ready_random_en;
    integer                   tb_otf_ready_seed;
    integer                   tb_otf_ready_stall_pct;
    integer                   tb_axi_random_en;
    integer                   tb_axi_seed;
    integer                   tb_axi_ar_stall_pct;
    integer                   tb_axi_rvalid_stall_pct;
    integer                   tb_axi_read_delay_cycles;
    integer                   tb_debug_word64_index;
    integer                   dbg_axi_word64_base;
    integer                   tb_check_no_otf_underflow;
    integer                   rotate_dbg_progress_sum;
    integer                   rotate_dbg_prev_progress_sum;
    integer                   rotate_dbg_stall_cycles;
    integer                   tb_rotate_stop_cycle;
    reg [4:0]                 first_rvo_mismatch_fmt;
    reg [11:0]                first_rvo_mismatch_x;
    reg [9:0]                 first_rvo_mismatch_y;
    integer                   first_rvo_mismatch_beat;
    reg [AXI_DW-1:0]          first_rvo_expected_data;
    reg [AXI_DW-1:0]          first_rvo_actual_data;
    reg [2:0]                 first_rvo_expected_alen;
    reg                       first_rvo_actual_last;
    reg [4:0]                 first_ar_mismatch_fmt;
    reg [11:0]                first_ar_mismatch_x;
    reg [9:0]                 first_ar_mismatch_y;
    reg [AXI_AW-1:0]          first_ar_expected_addr;
    reg [AXI_AW-1:0]          first_ar_actual_addr;
    reg [AXI_AW-1:0]          first_axi_rdata_cccc_addr;
    reg                       first_axi_rdata_cccc_is_meta;
    reg [M_AXI_DW-1:0]        first_axi_rdata_cccc_data;
    reg [7:0]                 first_dec_meta_expected_raw;
    reg [7:0]                 first_dec_meta_actual_raw;
    reg [4:0]                 first_dec_meta_expected_format;
    reg [4:0]                 first_dec_meta_actual_format;
    reg [3:0]                 first_dec_meta_expected_flag;
    reg [3:0]                 first_dec_meta_actual_flag;
    reg [2:0]                 first_dec_meta_expected_alen;
    reg [2:0]                 first_dec_meta_actual_alen;
    reg [11:0]                first_dec_meta_expected_x;
    reg [11:0]                first_dec_meta_actual_x;
    reg [9:0]                 first_dec_meta_expected_y;
    reg [9:0]                 first_dec_meta_actual_y;
    reg [4:0]                 first_vivo_ci_mismatch_fmt;
    reg [11:0]                first_vivo_ci_mismatch_x;
    reg [9:0]                 first_vivo_ci_mismatch_y;
    reg [7:0]                 first_vivo_ci_expected_raw;
    reg [3:0]                 first_vivo_ci_expected_metadata;
    reg [3:0]                 first_vivo_ci_actual_metadata;
    reg [2:0]                 first_vivo_ci_expected_alen;
    reg [2:0]                 first_vivo_ci_actual_alen;
    reg [4:0]                 first_vivo_cvi_mismatch_fmt;
    reg [11:0]                first_vivo_cvi_mismatch_x;
    reg [9:0]                 first_vivo_cvi_mismatch_y;
    integer                   first_vivo_cvi_mismatch_beat;
    reg [AXI_DW-1:0]          first_vivo_cvi_expected_data;
    reg [AXI_DW-1:0]          first_vivo_cvi_actual_data;
    reg                       first_vivo_cvi_expected_last;
    reg                       first_vivo_cvi_actual_last;
    integer                   first_m_r_nosink_cycle;
    reg                       first_m_r_nosink_owner_s0;
    reg                       first_m_r_nosink_rlast;
    reg                       first_m_r_nosink_rbuf_valid;
    reg [7:0]                 first_m_r_nosink_payload_left;
    reg [7:0]                 first_m_r_nosink_ar_left;
    integer                   otf_beat_cnt;
    integer                   otf_mismatch_cnt;
    integer                   first_otf_mismatch_beat;
    integer                   first_otf_mismatch_x;
    integer                   first_otf_mismatch_y;
    reg [127:0]               first_otf_expected_data;
    reg [127:0]               first_otf_actual_data;
    integer                   inject_tile_cnt;
    reg                       otf_frame_done;
    integer                   otf_frame_done_count;
    integer                   otf_active_x;
    integer                   otf_active_y;
    integer                   compressed_tile_hs_cnt;
    integer                   compressed_tile_last_cnt;
    integer                   vivo_ci_mismatch_cnt;
    integer                   vivo_cvi_data_mismatch_cnt;
    integer                   vivo_cvi_last_mismatch_cnt;
    integer                   dec_meta_out_cnt;
    integer                   dec_meta_mismatch_cnt;
    integer                   first_dec_meta_mismatch_idx;
    integer                   fake_ci_fifo_wr_cnt;
    integer                   fake_ci_fifo_rd_cnt;
    integer                   cvi_tile_rd_ptr;
    integer                   cvi_tile_beat_idx;
    reg [4:0]                 vivo_if_fmt_queue   [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg [11:0]                vivo_if_x_queue     [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg [9:0]                 vivo_if_y_queue     [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    reg [2:0]                 vivo_if_alen_queue  [0:CASE_MAX_EXPECTED_CI_CMDS-1];
    integer                   vivo_if_ci_wr_ptr;
    integer                   vivo_if_cvi_rd_ptr;
    integer                   vivo_if_rvo_rd_ptr;
    integer                   vivo_if_cvi_beat_idx;
    integer                   vivo_if_rvo_beat_idx;
    integer                   vivo_if_ci_accept_cnt;
    integer                   vivo_if_cvi_beat_cnt;
    integer                   vivo_if_cvi_last_cnt;
    integer                   vivo_if_rvo_beat_cnt;
    integer                   vivo_if_rvo_last_cnt;
    integer                   vivo_if_ci_mismatch_cnt;
    integer                   vivo_if_cvi_underflow_cnt;
    integer                   vivo_if_cvi_data_mismatch_cnt;
    integer                   vivo_if_cvi_last_mismatch_cnt;
    integer                   vivo_if_rvo_underflow_cnt;
    integer                   vivo_if_rvo_data_mismatch_cnt;
    integer                   vivo_if_rvo_last_mismatch_cnt;
    reg                       axi_r_cccc_seen_curr_beat;
    reg [31:0]                otf_ready_rand_state;
    reg [31:0]                axi_rand_state;

    reg [4:0]                 inject_axis_format;
    reg [15:0]                inject_axis_tile_x;
    reg [15:0]                inject_axis_tile_y;
    reg                       inject_axis_tile_valid;
    reg [255:0]               inject_axis_tdata;
    reg                       inject_axis_tlast;
    reg                       inject_axis_tvalid;

    reg [8*96-1:0]            case_name;
    reg [8*128-1:0]           stream_file;
    reg [8*128-1:0]           expected_stream_file;
    reg [8*128-1:0]           stream_plane0_file;
    reg [8*128-1:0]           expected_stream_plane0_file;
    reg [8*128-1:0]           stream_plane1_file;
    reg [8*128-1:0]           expected_stream_plane1_file;
    reg [8*128-1:0]           dec_meta_actual_file;
    reg [8*128-1:0]           dec_meta_expected_file;
    reg [8*128-1:0]           fc_sc_event_file;
    reg [8*128-1:0]           summary_file;

    reg                       exp_dec_meta_is_uv;
    reg [1:0]                 exp_dec_meta_phase;
    reg [11:0]                exp_dec_meta_x;
    reg [9:0]                 exp_dec_meta_y;
    reg [9:0]                 exp_dec_meta_uv_y;
    reg                       exp_dec_meta_done;

    assign tb_otf_vsync = o_otf_vsync;
    assign tb_otf_hsync = o_otf_hsync;
    assign tb_otf_de    = o_otf_de;
    assign tb_otf_data  = o_otf_data;
    assign tb_otf_fcnt  = o_otf_fcnt;
    assign tb_otf_lcnt  = o_otf_lcnt;
    assign dec_i_otf_ready_eff = (LOOP_TO_ENC != 0) ? enc_o_otf_ready : i_otf_ready;
    assign o_otf_sram_a_wen   = o_bank0_en && o_bank0_wen;
    assign o_otf_sram_a_waddr = o_bank0_addr;
    assign o_otf_sram_a_wdata = o_bank0_din;
    assign o_otf_sram_a_ren   = o_bank0_en && !o_bank0_wen;
    assign o_otf_sram_a_raddr = o_bank0_addr;
    assign i_bank0_dout       = i_otf_sram_a_rdata;
    assign o_otf_sram_b_wen   = o_bank1_en && o_bank1_wen;
    assign o_otf_sram_b_waddr = o_bank1_addr;
    assign o_otf_sram_b_wdata = o_bank1_din;
    assign o_otf_sram_b_ren   = o_bank1_en && !o_bank1_wen;
    assign o_otf_sram_b_raddr = o_bank1_addr;
    assign i_bank1_dout       = i_otf_sram_b_rdata;

    function automatic has_cccc_lane;
        input [M_AXI_DW-1:0] data_word;
        integer lane_idx;
        begin
            has_cccc_lane = 1'b0;
            for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                if (data_word[lane_idx*64 +: 64] == 64'hcccccccccccccccc)
                    has_cccc_lane = 1'b1;
            end
        end
    endfunction

    function automatic integer first_cccc_lane_idx;
        input [M_AXI_DW-1:0] data_word;
        integer lane_idx;
        begin
            first_cccc_lane_idx = -1;
            for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                if ((first_cccc_lane_idx < 0) &&
                    (data_word[lane_idx*64 +: 64] == 64'hcccccccccccccccc))
                    first_cccc_lane_idx = lane_idx;
            end
        end
    endfunction

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

    function automatic is_plane1_fmt;
        input [4:0] fmt;
        begin
            is_plane1_fmt = (fmt == META_FMT_NV12_UV) ||
                            (fmt == META_FMT_P010_UV);
        end
    endfunction

    function automatic is_active_rvo_tile;
        input [4:0]  fmt;
        input [11:0] tile_x;
        input [9:0]  tile_y;
        begin
            if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102)) begin
                is_active_rvo_tile = (tile_x < RGBA_TILE_X_COUNT) &&
                                     (tile_y < RGBA_ACTIVE_TILE_Y_COUNT);
            end else if (fmt == META_FMT_NV12_Y) begin
                is_active_rvo_tile = (tile_x < NV12_TILE_X_COUNT) &&
                                     (tile_y < NV12_Y_ACTIVE_TILE_Y_COUNT);
            end else if (fmt == META_FMT_NV12_UV) begin
                is_active_rvo_tile = (tile_x < NV12_TILE_X_COUNT) &&
                                     (tile_y < NV12_UV_ACTIVE_TILE_Y_COUNT);
            end else if (fmt == META_FMT_P010_Y) begin
                is_active_rvo_tile = (tile_x < G016_TILE_X_COUNT) &&
                                     (tile_y < G016_Y_ACTIVE_TILE_Y_COUNT);
            end else if (fmt == META_FMT_P010_UV) begin
                is_active_rvo_tile = (tile_x < G016_TILE_X_COUNT) &&
                                     (tile_y < G016_UV_ACTIVE_TILE_Y_COUNT);
            end else begin
                is_active_rvo_tile = 1'b0;
            end
        end
    endfunction

    function automatic [4:0] expected_dec_meta_format;
        input integer is_uv_plane;
        begin
            if (CASE_IS_NV12) begin
                expected_dec_meta_format = (is_uv_plane != 0) ? META_FMT_NV12_UV : META_FMT_NV12_Y;
            end else if (CASE_IS_G016) begin
                expected_dec_meta_format = (is_uv_plane != 0) ? META_FMT_P010_UV : META_FMT_P010_Y;
            end else if (CASE_IS_RGBA1010102) begin
                expected_dec_meta_format = META_FMT_RGBA1010102;
            end else begin
                expected_dec_meta_format = META_FMT_RGBA8888;
            end
        end
    endfunction

    function automatic expected_dec_meta_coord_active;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        begin
            if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102)) begin
                expected_dec_meta_coord_active = (tile_x < CASE_META_ACTIVE_X_NUMBERS) &&
                                                 (tile_y < RGBA_ACTIVE_TILE_Y_COUNT);
            end else if (fmt == META_FMT_NV12_Y) begin
                expected_dec_meta_coord_active = (tile_x < CASE_META_ACTIVE_X_NUMBERS) &&
                                                 (tile_y < NV12_Y_ACTIVE_TILE_Y_COUNT);
            end else if (fmt == META_FMT_NV12_UV) begin
                expected_dec_meta_coord_active = (tile_x < CASE_META_ACTIVE_X_NUMBERS) &&
                                                 (tile_y < NV12_UV_ACTIVE_TILE_Y_COUNT);
            end else if (fmt == META_FMT_P010_Y) begin
                expected_dec_meta_coord_active = (tile_x < CASE_META_ACTIVE_X_NUMBERS) &&
                                                 (tile_y < G016_Y_ACTIVE_TILE_Y_COUNT);
            end else if (fmt == META_FMT_P010_UV) begin
                expected_dec_meta_coord_active = (tile_x < CASE_META_ACTIVE_X_NUMBERS) &&
                                                 (tile_y < G016_UV_ACTIVE_TILE_Y_COUNT);
            end else begin
                expected_dec_meta_coord_active = 1'b0;
            end
        end
    endfunction

    function automatic [AXI_AW-1:0] expected_dec_meta_byte_addr;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        reg [AXI_AW-1:0] meta_offset_addr;
        begin
            meta_offset_addr = ((tile_y >> 4) * CASE_META_PITCH_BYTES * 16) +
                               ((tile_x >> 4) << 8) +
                               (((tile_y >> 3) & 1) << 7) +
                               (((tile_x >> 3) & 1) << 6) +
                               ((tile_y & 7) << 3) +
                               (tile_x & 7);
            expected_dec_meta_byte_addr = (is_plane1_fmt(fmt) ? CASE_META_BASE_ADDR_UV : CASE_META_BASE_ADDR_Y) +
                                          meta_offset_addr;
        end
    endfunction

    function automatic [7:0] expected_dec_meta_raw;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        reg [AXI_AW-1:0] byte_addr;
        integer word_idx;
        integer byte_idx;
        reg [63:0] meta_word;
        begin
            byte_addr = expected_dec_meta_byte_addr(fmt, tile_x, tile_y);
            byte_idx  = byte_addr[2:0];
            if (is_plane1_fmt(fmt)) begin
                word_idx  = (byte_addr - CASE_META_BASE_ADDR_UV) >> 3;
                meta_word = (word_idx < CASE_META1_WORDS64) ? meta_plane1_words[word_idx] : 64'd0;
            end else begin
                word_idx  = (byte_addr - CASE_META_BASE_ADDR_Y) >> 3;
                meta_word = (word_idx < CASE_META0_WORDS64) ? meta_plane0_words[word_idx] : 64'd0;
            end
            expected_dec_meta_raw = meta_word[byte_idx*8 +: 8];
        end
    endfunction

    function automatic [3:0] expected_dec_meta_flag;
        input [7:0] meta_raw;
        begin
            if (FORCE_FULL_PAYLOAD_CASE != 0) begin
                expected_dec_meta_flag = 4'h7;
            end else if (meta_raw[7:6] != 2'b00) begin
                expected_dec_meta_flag = 4'd0;
            end else begin
                expected_dec_meta_flag = {~meta_raw[4], meta_raw[3:1]};
            end
        end
    endfunction

    function automatic [2:0] expected_dec_meta_alen;
        input [4:0] fmt;
        input [7:0] meta_raw;
        begin
            if (FORCE_FULL_PAYLOAD_CASE != 0) begin
                expected_dec_meta_alen = 3'd7;
            end else if (meta_raw[7:6] != 2'b00) begin
                expected_dec_meta_alen = 3'd0;
            end else if (!meta_raw[4]) begin
                expected_dec_meta_alen = 3'd0;
            end else if (fmt == META_FMT_RGBA8888) begin
                if (meta_raw[3:1] == 3'b111) begin
                    if (CASE_LOSSY_RGBA_2_1 != 0)
                        expected_dec_meta_alen = 3'd3;
                    else if (meta_raw[5])
                        expected_dec_meta_alen = 3'd5;
                    else
                        expected_dec_meta_alen = 3'd7;
                end else begin
                    expected_dec_meta_alen = meta_raw[3:1];
                end
            end else begin
                expected_dec_meta_alen = meta_raw[3:1];
            end
        end
    endfunction

    function automatic [3:0] expected_dec_meta_flag_by_coord;
        input [4:0] fmt;
        input [7:0] meta_raw;
        input integer tile_x;
        input integer tile_y;
        begin
            expected_dec_meta_flag_by_coord = expected_dec_meta_coord_active(fmt, tile_x, tile_y) ?
                                              expected_dec_meta_flag(meta_raw) :
                                              4'h8;
        end
    endfunction

    function automatic [2:0] expected_dec_meta_alen_by_coord;
        input [4:0] fmt;
        input [7:0] meta_raw;
        input integer tile_x;
        input integer tile_y;
        begin
            expected_dec_meta_alen_by_coord = expected_dec_meta_coord_active(fmt, tile_x, tile_y) ?
                                              expected_dec_meta_alen(fmt, meta_raw) :
                                              3'd0;
        end
    endfunction

    task automatic write_dec_meta_line;
        input integer fd;
        input integer index;
        input [7:0] raw;
        input [4:0] fmt;
        input [3:0] flag;
        input [2:0] alen;
        input [11:0] xcoord;
        input [9:0] ycoord;
        begin
            if (fd != 0) begin
                $fwrite(fd, "%06d raw=%02h fmt=%02h flag=%01h alen=%0d x=%04h y=%04h\n",
                        index, raw, fmt, flag, alen, xcoord, ycoord);
            end
        end
    endtask

    task automatic write_fc_sc_event;
        input [8*16-1:0] stage;
        input integer index;
        input [7:0] raw;
        input [4:0] fmt;
        input [3:0] flag;
        input [2:0] alen;
        input [1:0] alpha_mode;
        input [11:0] xcoord;
        input [9:0] ycoord;
        reg [8*2-1:0] kind;
        begin
            if ((raw[7:6] != 2'b00) || !raw[4]) begin
                kind = (raw[7:6] != 2'b00) ? "SC" : "FC";
                if (fc_sc_event_fd != 0) begin
                    $fwrite(fc_sc_event_fd,
                            "%0d time_ps=%0.0f time_ns=%0.3f stage=%0s idx=%0d kind=%0s raw=%02h fmt=%02h flag=%01h alen=%0d alpha_mode=%0d x=%0d y=%0d\n",
                            fc_sc_event_cnt,
                            ($realtime * 1000.0),
                            $realtime,
                            stage,
                            index,
                            kind,
                            raw,
                            fmt,
                            flag,
                            alen,
                            alpha_mode,
                            xcoord,
                            ycoord);
                end
                fc_sc_event_cnt = fc_sc_event_cnt + 1;
            end
        end
    endtask

    task automatic dump_expected_dec_meta_stream;
        input integer fd;
        integer sample_idx;
        integer is_uv_plane;
        integer xcoord;
        integer ycoord;
        integer uv_ycoord;
        integer active_ycoord;
        integer scan_phase;
        reg [4:0] fmt;
        reg [7:0] raw;
        begin
            if (fd != 0) begin
                $fwrite(fd, "# idx raw fmt flag alen x y\n");
            end

            sample_idx  = 0;
            is_uv_plane = CASE_HAS_PLANE1 ? 1 : 0;
            scan_phase  = CASE_HAS_PLANE1 ? DEC_META_PHASE_UV : DEC_META_PHASE_YH;
            xcoord      = 0;
            ycoord      = 0;
            uv_ycoord   = 0;

            if (CASE_DEC_ROTATE_EN && CASE_IS_NV12) begin
                xcoord = (CASE_DEC_ROTATION == 270) ? (CASE_META_X_SAMPLES - 1) : 0;
                while ((CASE_DEC_ROTATION == 270) ? (xcoord >= 0) :
                                                     (xcoord < CASE_META_X_SAMPLES)) begin
                    for (uv_ycoord = 0; uv_ycoord < NV12_UV_ACTIVE_TILE_Y_COUNT; uv_ycoord = uv_ycoord + 1) begin
                        fmt = expected_dec_meta_format(1);
                        raw = expected_dec_meta_raw(fmt, xcoord, uv_ycoord);
                        write_dec_meta_line(fd, sample_idx, raw, fmt,
                                            expected_dec_meta_flag_by_coord(fmt, raw, xcoord, uv_ycoord),
                                            expected_dec_meta_alen_by_coord(fmt, raw, xcoord, uv_ycoord),
                                            xcoord, uv_ycoord);
                        sample_idx = sample_idx + 1;
                    end
                    for (ycoord = 0; ycoord < NV12_Y_ACTIVE_TILE_Y_COUNT; ycoord = ycoord + 1) begin
                        fmt = expected_dec_meta_format(0);
                        raw = expected_dec_meta_raw(fmt, xcoord, ycoord);
                        write_dec_meta_line(fd, sample_idx, raw, fmt,
                                            expected_dec_meta_flag_by_coord(fmt, raw, xcoord, ycoord),
                                            expected_dec_meta_alen_by_coord(fmt, raw, xcoord, ycoord),
                                            xcoord, ycoord);
                        sample_idx = sample_idx + 1;
                    end
                    xcoord = (CASE_DEC_ROTATION == 270) ? (xcoord - 1) :
                                                          (xcoord + 1);
                end
            end else while (sample_idx < CASE_EXPECTED_DEC_META_SAMPLES) begin
                fmt = expected_dec_meta_format(is_uv_plane);
                active_ycoord = is_uv_plane ? uv_ycoord :
                                ((scan_phase == DEC_META_PHASE_YL) ? (ycoord + 1) :
                                                                      ycoord);
                raw = expected_dec_meta_raw(fmt, xcoord, active_ycoord);
                write_dec_meta_line(fd, sample_idx, raw, fmt,
                                    expected_dec_meta_flag_by_coord(fmt, raw, xcoord, active_ycoord),
                                    expected_dec_meta_alen_by_coord(fmt, raw, xcoord, active_ycoord),
                                    xcoord, active_ycoord);

                sample_idx = sample_idx + 1;
                if (xcoord == (CASE_META_X_SAMPLES - 1)) begin
                    xcoord = 0;
                    if (!CASE_HAS_PLANE1) begin
                        ycoord = ycoord + 1;
                    end else if (scan_phase == DEC_META_PHASE_UV) begin
                        uv_ycoord   = uv_ycoord + 1;
                        is_uv_plane = 0;
                        scan_phase  = DEC_META_PHASE_YH;
                    end else if (scan_phase == DEC_META_PHASE_YH) begin
                        if ((ycoord + 1) < CASE_TILE_Y_NUMBERS) begin
                            scan_phase = DEC_META_PHASE_YL;
                        end else begin
                            ycoord      = ycoord + 2;
                            is_uv_plane = 1;
                            scan_phase  = DEC_META_PHASE_UV;
                        end
                    end else begin
                        ycoord      = ycoord + 2;
                        is_uv_plane = 1;
                        scan_phase  = DEC_META_PHASE_UV;
                    end
                end else begin
                    xcoord = xcoord + 1;
                end
            end
        end
    endtask

    function automatic integer rvo_plane_word_base;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        begin
            if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102)) begin
                rvo_plane_word_base = rgba_tile_base_word(tile_x, tile_y);
            end else if (fmt == META_FMT_NV12_Y) begin
                rvo_plane_word_base = plane_tile_base_word(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1);
            end else if (fmt == META_FMT_P010_Y) begin
                rvo_plane_word_base = plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2);
            end else begin
                rvo_plane_word_base = CASE_IS_G016
                                    ? plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2)
                                    : plane_tile_base_word(tile_x, tile_y, 16, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 2);
            end
        end
    endfunction

    task automatic write_rvo_beat_words;
        input integer fd;
        input [AXI_DW-1:0] beat_data;
        begin
            if (fd != 0) begin
                $fwrite(fd, "%016h\n", beat_data[63:0]);
                $fwrite(fd, "%016h\n", beat_data[127:64]);
                $fwrite(fd, "%016h\n", beat_data[191:128]);
                $fwrite(fd, "%016h\n", beat_data[255:192]);
            end
        end
    endtask

    function automatic integer vivo_fmt_dump_idx;
        input [4:0] fmt;
        begin
            case (fmt)
                META_FMT_RGBA1010102: vivo_fmt_dump_idx = 1;
                META_FMT_NV12_Y:      vivo_fmt_dump_idx = 2;
                META_FMT_NV12_UV:     vivo_fmt_dump_idx = 3;
                META_FMT_P010_Y:      vivo_fmt_dump_idx = 4;
                META_FMT_P010_UV:     vivo_fmt_dump_idx = 5;
                default:              vivo_fmt_dump_idx = 0;
            endcase
        end
    endfunction

    task automatic write_vivo_dump_headers;
        input integer idx;
        begin
            if (vivo_ci_fd[idx] != 0) begin
                $fwrite(vivo_ci_fd[idx], "# idx fmt x y input_type alen metadata lossy alpha_mode sb\n");
            end
            if (vivo_cvi_fd[idx] != 0) begin
                $fwrite(vivo_cvi_fd[idx], "# idx fmt x y beat last data\n");
            end
            if (vivo_rvo_fd[idx] != 0) begin
                $fwrite(vivo_rvo_fd[idx], "# idx fmt x y beat last data\n");
            end
        end
    endtask

    task automatic open_vivo_dump_files;
        integer idx;
        begin
            for (idx = 0; idx < 6; idx = idx + 1) begin
                vivo_ci_dump_cnt[idx]  = 0;
                vivo_cvi_dump_cnt[idx] = 0;
                vivo_rvo_dump_cnt[idx] = 0;
            end

            vivo_ci_fd[0]  = $fopen("vivo_ci_rgba8888.txt", "w");
            vivo_cvi_fd[0] = $fopen("vivo_cvi_rgba8888.txt", "w");
            vivo_rvo_fd[0] = $fopen("vivo_rvo_rgba8888.txt", "w");
            vivo_ci_fd[1]  = $fopen("vivo_ci_rgba1010102.txt", "w");
            vivo_cvi_fd[1] = $fopen("vivo_cvi_rgba1010102.txt", "w");
            vivo_rvo_fd[1] = $fopen("vivo_rvo_rgba1010102.txt", "w");
            vivo_ci_fd[2]  = $fopen("vivo_ci_nv12_y.txt", "w");
            vivo_cvi_fd[2] = $fopen("vivo_cvi_nv12_y.txt", "w");
            vivo_rvo_fd[2] = $fopen("vivo_rvo_nv12_y.txt", "w");
            vivo_ci_fd[3]  = $fopen("vivo_ci_nv12_uv.txt", "w");
            vivo_cvi_fd[3] = $fopen("vivo_cvi_nv12_uv.txt", "w");
            vivo_rvo_fd[3] = $fopen("vivo_rvo_nv12_uv.txt", "w");
            vivo_ci_fd[4]  = $fopen("vivo_ci_p010_y.txt", "w");
            vivo_cvi_fd[4] = $fopen("vivo_cvi_p010_y.txt", "w");
            vivo_rvo_fd[4] = $fopen("vivo_rvo_p010_y.txt", "w");
            vivo_ci_fd[5]  = $fopen("vivo_ci_p010_uv.txt", "w");
            vivo_cvi_fd[5] = $fopen("vivo_cvi_p010_uv.txt", "w");
            vivo_rvo_fd[5] = $fopen("vivo_rvo_p010_uv.txt", "w");

            for (idx = 0; idx < 6; idx = idx + 1) begin
                if ((vivo_ci_fd[idx] == 0) || (vivo_cvi_fd[idx] == 0) || (vivo_rvo_fd[idx] == 0)) begin
                    $fatal(1, "Failed to open vivo dump file set idx=%0d", idx);
                end
                write_vivo_dump_headers(idx);
            end
        end
    endtask

    task automatic close_vivo_dump_files;
        integer idx;
        begin
            for (idx = 0; idx < 6; idx = idx + 1) begin
                if (vivo_ci_fd[idx] != 0) begin
                    $fclose(vivo_ci_fd[idx]);
                    vivo_ci_fd[idx] = 0;
                end
                if (vivo_cvi_fd[idx] != 0) begin
                    $fclose(vivo_cvi_fd[idx]);
                    vivo_cvi_fd[idx] = 0;
                end
                if (vivo_rvo_fd[idx] != 0) begin
                    $fclose(vivo_rvo_fd[idx]);
                    vivo_rvo_fd[idx] = 0;
                end
            end
        end
    endtask

    task automatic write_vivo_ci_dump;
        input [4:0] fmt;
        input [11:0] tile_x;
        input [9:0] tile_y;
        input input_type;
        input [2:0] alen;
        input [3:0] metadata;
        input lossy;
        input [1:0] alpha_mode;
        input [SB_WIDTH-1:0] sb;
        integer idx;
        begin
            idx = vivo_fmt_dump_idx(fmt);
            if (vivo_ci_fd[idx] != 0) begin
                $fwrite(vivo_ci_fd[idx],
                        "%0d fmt=%0d x=%0d y=%0d input_type=%0b alen=%0d metadata=%0h lossy=%0b alpha_mode=%0d sb=%0h\n",
                        vivo_ci_dump_cnt[idx], fmt, tile_x, tile_y, input_type, alen, metadata, lossy,
                        alpha_mode, sb);
            end
            vivo_ci_dump_cnt[idx] = vivo_ci_dump_cnt[idx] + 1;
        end
    endtask

    task automatic write_vivo_cvi_dump;
        input [4:0] fmt;
        input [11:0] tile_x;
        input [9:0] tile_y;
        input integer beat_idx;
        input last;
        input [255:0] data;
        integer idx;
        begin
            idx = vivo_fmt_dump_idx(fmt);
            if (vivo_cvi_fd[idx] != 0) begin
                $fwrite(vivo_cvi_fd[idx], "%0d fmt=%0d x=%0d y=%0d beat=%0d last=%0b data=%064h\n",
                        vivo_cvi_dump_cnt[idx], fmt, tile_x, tile_y, beat_idx, last, data);
            end
            vivo_cvi_dump_cnt[idx] = vivo_cvi_dump_cnt[idx] + 1;
        end
    endtask

    task automatic write_vivo_rvo_dump;
        input [4:0] fmt;
        input [11:0] tile_x;
        input [9:0] tile_y;
        input integer beat_idx;
        input last;
        input [255:0] data;
        integer idx;
        begin
            idx = vivo_fmt_dump_idx(fmt);
            if (vivo_rvo_fd[idx] != 0) begin
                $fwrite(vivo_rvo_fd[idx], "%0d fmt=%0d x=%0d y=%0d beat=%0d last=%0b data=%064h\n",
                        vivo_rvo_dump_cnt[idx], fmt, tile_x, tile_y, beat_idx, last, data);
            end
            vivo_rvo_dump_cnt[idx] = vivo_rvo_dump_cnt[idx] + 1;
        end
    endtask

    task automatic capture_rvo_beat_to_plane_mem;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer beat_idx;
        input [AXI_DW-1:0] beat_data;
        integer word_idx;
        begin
            word_idx = rvo_plane_word_base(fmt, tile_x, tile_y) + beat_idx * 4;
            if (is_plane1_fmt(fmt)) begin
                if (word_idx + 0 < CASE_TILE1_WORDS64) actual_rvo_plane1_words[word_idx + 0] = beat_data[63:0];
                if (word_idx + 1 < CASE_TILE1_WORDS64) actual_rvo_plane1_words[word_idx + 1] = beat_data[127:64];
                if (word_idx + 2 < CASE_TILE1_WORDS64) actual_rvo_plane1_words[word_idx + 2] = beat_data[191:128];
                if (word_idx + 3 < CASE_TILE1_WORDS64) actual_rvo_plane1_words[word_idx + 3] = beat_data[255:192];
            end else begin
                if (word_idx + 0 < CASE_TILE0_WORDS64) actual_rvo_plane0_words[word_idx + 0] = beat_data[63:0];
                if (word_idx + 1 < CASE_TILE0_WORDS64) actual_rvo_plane0_words[word_idx + 1] = beat_data[127:64];
                if (word_idx + 2 < CASE_TILE0_WORDS64) actual_rvo_plane0_words[word_idx + 2] = beat_data[191:128];
                if (word_idx + 3 < CASE_TILE0_WORDS64) actual_rvo_plane0_words[word_idx + 3] = beat_data[255:192];
            end
        end
    endtask

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

            if (((16 * RGBA_TILE_PITCH) % (1 << RGBA_HIGHEST_BANK)) == 0) begin
                tile_row_pixels = tile_y * 4;
                bit_val = ((addr_bytes >> (RGBA_HIGHEST_BANK - 1)) & 1) ^ ((tile_row_pixels >> 4) & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (1 << (RGBA_HIGHEST_BANK - 1));
                end else begin
                    addr_bytes = addr_bytes & ~(1 << (RGBA_HIGHEST_BANK - 1));
                end
            end

            if (((16 * RGBA_TILE_PITCH) % (1 << (RGBA_HIGHEST_BANK + 1))) == 0) begin
                tile_row_pixels = tile_y * 4;
                bit_val = ((addr_bytes >> RGBA_HIGHEST_BANK) & 1) ^ ((tile_row_pixels >> 5) & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (1 << RGBA_HIGHEST_BANK);
                end else begin
                    addr_bytes = addr_bytes & ~(1 << RGBA_HIGHEST_BANK);
                end
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
        input integer highest_bank_bit;
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

            if (((16 * surface_pitch_bytes) % (1 << highest_bank_bit)) == 0) begin
                if (((bpp == 1) && (tile_width == 32) && (tile_height == 8)) ||
                    ((bpp == 2) && (tile_width == 16) && (tile_height == 8))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 4;
                end
                bit_val = ((addr_bytes >> (highest_bank_bit - 1)) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (1 << (highest_bank_bit - 1));
                end else begin
                    addr_bytes = addr_bytes & ~(1 << (highest_bank_bit - 1));
                end
            end

            if (((16 * surface_pitch_bytes) % (1 << (highest_bank_bit + 1))) == 0) begin
                if (((bpp == 1) && (tile_width == 32) && (tile_height == 8)) ||
                    ((bpp == 2) && (tile_width == 16) && (tile_height == 8))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 6;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end
                bit_val = ((addr_bytes >> highest_bank_bit) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (1 << highest_bank_bit);
                end else begin
                    addr_bytes = addr_bytes & ~(1 << highest_bank_bit);
                end
            end

            plane_tile_base_word = addr_bytes >> 3;
        end
    endfunction

    function automatic [AXI_AW-1:0] rgba_tile_addr_bytes;
        input integer tile_x;
        input integer tile_y;
        input [AXI_AW-1:0] base_addr;
        reg [AXI_AW-1:0] addr_bytes;
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

            if (((16 * RGBA_TILE_PITCH) % (1 << RGBA_HIGHEST_BANK)) == 0) begin
                tile_row_pixels = tile_y * 4;
                bit_val = ((addr_bytes >> (RGBA_HIGHEST_BANK - 1)) & 1) ^ ((tile_row_pixels >> 4) & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | ({{(AXI_AW-1){1'b0}}, 1'b1} << (RGBA_HIGHEST_BANK - 1));
                end else begin
                    addr_bytes = addr_bytes & ~( {{(AXI_AW-1){1'b0}}, 1'b1} << (RGBA_HIGHEST_BANK - 1));
                end
            end

            if (((16 * RGBA_TILE_PITCH) % (1 << (RGBA_HIGHEST_BANK + 1))) == 0) begin
                tile_row_pixels = tile_y * 4;
                bit_val = ((addr_bytes >> RGBA_HIGHEST_BANK) & 1) ^ ((tile_row_pixels >> 5) & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | ({{(AXI_AW-1){1'b0}}, 1'b1} << RGBA_HIGHEST_BANK);
                end else begin
                    addr_bytes = addr_bytes & ~( {{(AXI_AW-1){1'b0}}, 1'b1} << RGBA_HIGHEST_BANK);
                end
            end

            rgba_tile_addr_bytes = addr_bytes + base_addr;
        end
    endfunction

    function automatic [AXI_AW-1:0] plane_tile_addr_bytes;
        input integer tile_x;
        input integer tile_y;
        input integer tile_width;
        input integer tile_height;
        input integer surface_pitch_bytes;
        input integer highest_bank_bit;
        input integer bpp;
        input [AXI_AW-1:0] base_addr;
        reg [AXI_AW-1:0] addr_bytes;
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

            if (((16 * surface_pitch_bytes) % (1 << highest_bank_bit)) == 0) begin
                if (((bpp == 1) && (tile_width == 32) && (tile_height == 8)) ||
                    ((bpp == 2) && (tile_width == 16) && (tile_height == 8))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 4;
                end
                bit_val = ((addr_bytes >> (highest_bank_bit - 1)) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | ({{(AXI_AW-1){1'b0}}, 1'b1} << (highest_bank_bit - 1));
                end else begin
                    addr_bytes = addr_bytes & ~( {{(AXI_AW-1){1'b0}}, 1'b1} << (highest_bank_bit - 1));
                end
            end

            if (((16 * surface_pitch_bytes) % (1 << (highest_bank_bit + 1))) == 0) begin
                if (((bpp == 1) && (tile_width == 32) && (tile_height == 8)) ||
                    ((bpp == 2) && (tile_width == 16) && (tile_height == 8))) begin
                    tile_row_pixels = (tile_y * tile_height) >> 6;
                end else begin
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                end
                bit_val = ((addr_bytes >> highest_bank_bit) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | ({{(AXI_AW-1){1'b0}}, 1'b1} << highest_bank_bit);
                end else begin
                    addr_bytes = addr_bytes & ~( {{(AXI_AW-1){1'b0}}, 1'b1} << highest_bank_bit);
                end
            end

            plane_tile_addr_bytes = addr_bytes + base_addr;
        end
    endfunction

    function automatic [AXI_AW-1:0] expected_tile_addr;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer alen;
        reg [AXI_AW-1:0] addr_bytes;
        integer payload_bytes;
        begin
            if ((fmt == META_FMT_RGBA8888) && (CASE_IS_LOSSY_RGBA_2_1 != 0)) begin
                addr_bytes = rgba_tile_addr_bytes(tile_x, tile_y >> 1, CASE_TILE_BASE_ADDR_Y);
                if ((tile_y & 1) != 0) begin
                    addr_bytes = addr_bytes + 128;
                end
            end else if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102)) begin
                addr_bytes = rgba_tile_addr_bytes(tile_x, tile_y, CASE_TILE_BASE_ADDR_Y);
            end else if (fmt == META_FMT_NV12_Y) begin
                addr_bytes = plane_tile_addr_bytes(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1,
                                                   CASE_TILE_BASE_ADDR_Y);
            end else if (fmt == META_FMT_NV12_UV) begin
                addr_bytes = plane_tile_addr_bytes(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1,
                                                   CASE_TILE_BASE_ADDR_UV);
            end else if (fmt == META_FMT_P010_Y) begin
                addr_bytes = plane_tile_addr_bytes(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2,
                                                   CASE_TILE_BASE_ADDR_Y);
            end else begin
                addr_bytes = plane_tile_addr_bytes(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2,
                                                   CASE_TILE_BASE_ADDR_UV);
            end

            if (!((fmt == META_FMT_RGBA8888) && (CASE_IS_LOSSY_RGBA_2_1 != 0))) begin
                payload_bytes = (alen + 1) << 5;
                if ((payload_bytes <= 128) && (addr_bytes[8] ^ addr_bytes[9])) begin
                    addr_bytes = addr_bytes + 128;
                end
            end

            expected_tile_addr = addr_bytes;
        end
    endfunction

    function automatic [M_AXI_DW-1:0] pack_meta_axi_word;
        input integer is_plane1;
        input [AXI_AW-1:0] addr;
        input integer beat_idx;
        integer word64_base;
        integer lane_idx;
        begin
            pack_meta_axi_word = {M_AXI_DW{1'b0}};
            if (is_plane1 != 0) begin
                word64_base = ((addr - CASE_META_BASE_ADDR_UV) >> 3) + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word64_base + lane_idx) < CASE_META1_WORDS64)
                        pack_meta_axi_word[lane_idx*64 +: 64] = meta_plane1_words[word64_base + lane_idx];
                end
            end else begin
                word64_base = ((addr - CASE_META_BASE_ADDR_Y) >> 3) + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word64_base + lane_idx) < CASE_META0_WORDS64)
                        pack_meta_axi_word[lane_idx*64 +: 64] = meta_plane0_words[word64_base + lane_idx];
                end
            end
        end
    endfunction

    function automatic [M_AXI_DW-1:0] pack_tile_axi_word;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer beat_idx;
        integer word64_base;
        integer word_idx;
        integer lane_idx;
        begin
            pack_tile_axi_word = {M_AXI_DW{1'b0}};
            if ((fmt == META_FMT_RGBA8888) && (CASE_IS_LOSSY_RGBA_2_1 != 0)) begin
                word64_base = rgba_tile_base_word(tile_x, tile_y >> 1) +
                              (((tile_y & 1) != 0) ? 16 : 0);
                word_idx    = word64_base + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word_idx + lane_idx) < CASE_CMP0_WORDS64)
                        pack_tile_axi_word[lane_idx*64 +: 64] = tile_plane0_words[word_idx + lane_idx];
                end
            end else if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102)) begin
                word64_base = rgba_tile_base_word(tile_x, tile_y);
                word_idx    = word64_base + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word_idx + lane_idx) < CASE_CMP0_WORDS64)
                        pack_tile_axi_word[lane_idx*64 +: 64] = tile_plane0_words[word_idx + lane_idx];
                end
            end else if (fmt == META_FMT_NV12_Y) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1);
                word_idx    = word64_base + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word_idx + lane_idx) < CASE_CMP0_WORDS64)
                        pack_tile_axi_word[lane_idx*64 +: 64] = tile_plane0_words[word_idx + lane_idx];
                end
            end else if (fmt == META_FMT_P010_Y) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2);
                word_idx    = word64_base + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word_idx + lane_idx) < CASE_CMP0_WORDS64)
                        pack_tile_axi_word[lane_idx*64 +: 64] = tile_plane0_words[word_idx + lane_idx];
                end
            end else begin
                word64_base = CASE_IS_G016
                            ? plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2)
                            : plane_tile_base_word(tile_x, tile_y, 16, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 2);
                word_idx    = word64_base + beat_idx * (M_AXI_DW / 64);
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word_idx + lane_idx) < CASE_CMP1_WORDS64)
                        pack_tile_axi_word[lane_idx*64 +: 64] = tile_plane1_words[word_idx + lane_idx];
                end
            end
        end
    endfunction

    function automatic [AXI_DW-1:0] pack_tile_vivo_word;
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
            if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102)) begin
                word64_base = rgba_tile_base_word(tile_x, tile_y);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_CMP0_WORDS64) ? tile_plane0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_CMP0_WORDS64) ? tile_plane0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_CMP0_WORDS64) ? tile_plane0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_CMP0_WORDS64) ? tile_plane0_words[word_idx + 3] : 64'd0;
            end else if (fmt == META_FMT_NV12_Y) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_CMP0_WORDS64) ? tile_plane0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_CMP0_WORDS64) ? tile_plane0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_CMP0_WORDS64) ? tile_plane0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_CMP0_WORDS64) ? tile_plane0_words[word_idx + 3] : 64'd0;
            end else if (fmt == META_FMT_P010_Y) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_CMP0_WORDS64) ? tile_plane0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_CMP0_WORDS64) ? tile_plane0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_CMP0_WORDS64) ? tile_plane0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_CMP0_WORDS64) ? tile_plane0_words[word_idx + 3] : 64'd0;
            end else begin
                word64_base = CASE_IS_G016
                            ? plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2)
                            : plane_tile_base_word(tile_x, tile_y, 16, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 2);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_CMP1_WORDS64) ? tile_plane1_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_CMP1_WORDS64) ? tile_plane1_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_CMP1_WORDS64) ? tile_plane1_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_CMP1_WORDS64) ? tile_plane1_words[word_idx + 3] : 64'd0;
            end
            pack_tile_vivo_word = {w3, w2, w1, w0};
        end
    endfunction

    function automatic [AXI_DW-1:0] pack_raw_tile_vivo_word;
        input [4:0] fmt;
        input [AXI_AW-1:0] addr;
        input integer beat_idx;
        integer word64_base;
        reg [AXI_AW-1:0] tile_addr_offset;
        reg [63:0] w0;
        reg [63:0] w1;
        reg [63:0] w2;
        reg [63:0] w3;
        begin
            if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102) ||
                (fmt == META_FMT_NV12_Y) || (fmt == META_FMT_P010_Y)) begin
                tile_addr_offset = addr - CASE_TILE_BASE_ADDR_Y;
            end else begin
                tile_addr_offset = addr - CASE_TILE_BASE_ADDR_UV;
            end
            word64_base = (tile_addr_offset >> 3) + beat_idx * 4;
            if ((fmt == META_FMT_NV12_UV) || (fmt == META_FMT_P010_UV)) begin
                w0 = (word64_base + 0 < CASE_CMP1_WORDS64) ? tile_plane1_words[word64_base + 0] : 64'd0;
                w1 = (word64_base + 1 < CASE_CMP1_WORDS64) ? tile_plane1_words[word64_base + 1] : 64'd0;
                w2 = (word64_base + 2 < CASE_CMP1_WORDS64) ? tile_plane1_words[word64_base + 2] : 64'd0;
                w3 = (word64_base + 3 < CASE_CMP1_WORDS64) ? tile_plane1_words[word64_base + 3] : 64'd0;
            end else begin
                w0 = (word64_base + 0 < CASE_CMP0_WORDS64) ? tile_plane0_words[word64_base + 0] : 64'd0;
                w1 = (word64_base + 1 < CASE_CMP0_WORDS64) ? tile_plane0_words[word64_base + 1] : 64'd0;
                w2 = (word64_base + 2 < CASE_CMP0_WORDS64) ? tile_plane0_words[word64_base + 2] : 64'd0;
                w3 = (word64_base + 3 < CASE_CMP0_WORDS64) ? tile_plane0_words[word64_base + 3] : 64'd0;
            end
            pack_raw_tile_vivo_word = {w3, w2, w1, w0};
        end
    endfunction

    function automatic [AXI_DW-1:0] pack_ref_tile_axi_word;
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
            if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102)) begin
                word64_base = rgba_tile_base_word(tile_x, tile_y);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 3] : 64'd0;
            end else if (fmt == META_FMT_NV12_Y) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 1);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 3] : 64'd0;
            end else if (fmt == META_FMT_P010_Y) begin
                word64_base = plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE0_WORDS64) ? ref_tile_plane0_words[word_idx + 3] : 64'd0;
            end else begin
                word64_base = CASE_IS_G016
                            ? plane_tile_base_word(tile_x, tile_y, 32, 4, G016_TILE_PITCH, G016_HIGHEST_BANK, 2)
                            : plane_tile_base_word(tile_x, tile_y, 16, 8, NV12_TILE_PITCH, NV12_HIGHEST_BANK, 2);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < CASE_TILE1_WORDS64) ? ref_tile_plane1_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < CASE_TILE1_WORDS64) ? ref_tile_plane1_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < CASE_TILE1_WORDS64) ? ref_tile_plane1_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < CASE_TILE1_WORDS64) ? ref_tile_plane1_words[word_idx + 3] : 64'd0;
            end
            pack_ref_tile_axi_word = {w3, w2, w1, w0};
        end
    endfunction

    function automatic [M_AXI_DW-1:0] pack_raw_tile_axi_word;
        input [4:0] fmt;
        input [AXI_AW-1:0] addr;
        input integer beat_idx;
        integer word64_base;
        reg [AXI_AW-1:0] tile_addr_offset;
        integer lane_idx;
        begin
            pack_raw_tile_axi_word = {M_AXI_DW{1'b0}};
            if ((fmt == META_FMT_RGBA8888) || (fmt == META_FMT_RGBA1010102) ||
                (fmt == META_FMT_NV12_Y) || (fmt == META_FMT_P010_Y)) begin
                tile_addr_offset = addr - CASE_TILE_BASE_ADDR_Y;
            end else begin
                tile_addr_offset = addr - CASE_TILE_BASE_ADDR_UV;
            end
            word64_base = (tile_addr_offset >> 3) + beat_idx * (M_AXI_DW / 64);
            if ((fmt == META_FMT_NV12_UV) || (fmt == META_FMT_P010_UV)) begin
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word64_base + lane_idx) < CASE_CMP1_WORDS64)
                        pack_raw_tile_axi_word[lane_idx*64 +: 64] = tile_plane1_words[word64_base + lane_idx];
                end
            end else begin
                for (lane_idx = 0; lane_idx < (M_AXI_DW / 64); lane_idx = lane_idx + 1) begin
                    if ((word64_base + lane_idx) < CASE_CMP0_WORDS64)
                        pack_raw_tile_axi_word[lane_idx*64 +: 64] = tile_plane0_words[word64_base + lane_idx];
                end
            end
        end
    endfunction

    task automatic inject_axis_idle;
        begin
            @(negedge i_axi_clk);
            inject_axis_format     = 5'd0;
            inject_axis_tile_x     = 16'd0;
            inject_axis_tile_y     = 16'd0;
            inject_axis_tile_valid = 1'b0;
            inject_axis_tdata      = 256'd0;
            inject_axis_tlast      = 1'b0;
            inject_axis_tvalid     = 1'b0;
        end
    endtask

    task automatic drive_injected_header;
        input [4:0] fmt;
        input [11:0] tile_x;
        input [9:0] tile_y;
        begin
            @(negedge i_axi_clk);
            inject_axis_format     = fmt;
            inject_axis_tile_x     = {4'd0, tile_x};
            inject_axis_tile_y     = {6'd0, tile_y};
            inject_axis_tile_valid = 1'b1;
            while (inject_axis_tile_ready !== 1'b1) @(negedge i_axi_clk);
            @(negedge i_axi_clk);
            inject_axis_tile_valid = 1'b0;
        end
    endtask

    task automatic drive_injected_beat;
        input [255:0] beat_data;
        input         is_last;
        begin
            @(negedge i_axi_clk);
            inject_axis_tvalid = 1'b1;
            inject_axis_tdata  = beat_data;
            inject_axis_tlast  = is_last;
            while (inject_axis_tready !== 1'b1) @(negedge i_axi_clk);
        end
    endtask

    task automatic send_injected_tile;
        input [4:0] fmt;
        input [11:0] tile_x;
        input [9:0] tile_y;
        integer beat_idx;
        reg [255:0] beat_data;
        begin
            drive_injected_header(fmt, tile_x, tile_y);
            for (beat_idx = 0; beat_idx < CASE_FULL_TILE_BEATS; beat_idx = beat_idx + 1) begin
                beat_data = pack_ref_tile_axi_word(fmt, tile_x, tile_y, beat_idx);
                if (TB_REAL_VIVO_MODE == 0) begin
                    if (stream_fd != 0) begin
                        $fwrite(stream_fd, "%0d %0d %0d %0d %064h\n",
                                fmt, tile_x, tile_y, beat_idx, beat_data);
                    end
                    if (expected_stream_fd != 0) begin
                        $fwrite(expected_stream_fd, "%0d %0d %0d %0d %064h\n",
                                fmt, tile_x, tile_y, beat_idx, beat_data);
                    end
                end
                drive_injected_beat(beat_data, (beat_idx == (CASE_FULL_TILE_BEATS - 1)));
            end
            inject_tile_cnt = inject_tile_cnt + 1;
            inject_axis_idle();
        end
    endtask

    task automatic send_fake_otf_frame;
        integer tile_x;
        integer tile_y;
        integer slice_idx;
        integer y_upper_tile_y;
        integer y_lower_tile_y;
        integer uv_tile_y;
        reg [4:0] rgba_fmt;
        begin
            rgba_fmt = CASE_IS_RGBA1010102 ? META_FMT_RGBA1010102 : META_FMT_RGBA8888;
            if (CASE_IS_NV12) begin
                for (slice_idx = 0; slice_idx < NV12_UV_ACTIVE_TILE_Y_COUNT; slice_idx = slice_idx + 1) begin
                    y_upper_tile_y = slice_idx * 2;
                    y_lower_tile_y = slice_idx * 2 + 1;
                    uv_tile_y      = slice_idx;

                    for (tile_x = 0; tile_x < NV12_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_injected_tile(META_FMT_NV12_Y, tile_x[11:0], y_upper_tile_y[9:0]);
                    end
                    if (y_lower_tile_y < NV12_Y_ACTIVE_TILE_Y_COUNT) begin
                        for (tile_x = 0; tile_x < NV12_TILE_X_COUNT; tile_x = tile_x + 1) begin
                            send_injected_tile(META_FMT_NV12_Y, tile_x[11:0], y_lower_tile_y[9:0]);
                        end
                    end
                    for (tile_x = 0; tile_x < NV12_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_injected_tile(META_FMT_NV12_UV, tile_x[11:0], uv_tile_y[9:0]);
                    end
                end
            end else if (CASE_IS_G016) begin
                for (slice_idx = 0; slice_idx < G016_UV_ACTIVE_TILE_Y_COUNT; slice_idx = slice_idx + 1) begin
                    y_upper_tile_y = slice_idx * 2;
                    y_lower_tile_y = slice_idx * 2 + 1;
                    uv_tile_y      = slice_idx;

                    for (tile_x = 0; tile_x < G016_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_injected_tile(META_FMT_P010_Y, tile_x[11:0], y_upper_tile_y[9:0]);
                    end
                    if (y_lower_tile_y < G016_Y_ACTIVE_TILE_Y_COUNT) begin
                        for (tile_x = 0; tile_x < G016_TILE_X_COUNT; tile_x = tile_x + 1) begin
                            send_injected_tile(META_FMT_P010_Y, tile_x[11:0], y_lower_tile_y[9:0]);
                        end
                    end
                    for (tile_x = 0; tile_x < G016_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_injected_tile(META_FMT_P010_UV, tile_x[11:0], uv_tile_y[9:0]);
                    end
                end
            end else begin
                for (tile_y = 0; tile_y < RGBA_ACTIVE_TILE_Y_COUNT; tile_y = tile_y + 1) begin
                    for (tile_x = 0; tile_x < RGBA_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_injected_tile(rgba_fmt, tile_x[11:0], tile_y[9:0]);
                    end
                end
            end
        end
    endtask

    task automatic apb_write;
        input [APB_AW-1:0] addr;
        input [APB_DW-1:0] data;
        begin
            @(posedge PCLK);
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b1;
            PADDR   <= addr;
            PWDATA  <= data;
            @(posedge PCLK);
            PENABLE <= 1'b1;
            do begin
                @(posedge PCLK);
            end while (!PREADY);
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
            PADDR   <= {APB_AW{1'b0}};
            PWDATA  <= {APB_DW{1'b0}};
        end
    endtask

    task automatic program_frame_base_and_start;
        begin
            apb_write(16'h0030, CASE_META_BASE_ADDR_Y[31:0]);
            apb_write(16'h0034, CASE_META_BASE_ADDR_Y[63:32]);
            apb_write(16'h0038, CASE_TILE_BASE_ADDR_Y[31:0]);
            apb_write(16'h003c, CASE_TILE_BASE_ADDR_Y[63:32]);
            apb_write(16'h0040, CASE_META_BASE_ADDR_UV[31:0]);
            apb_write(16'h0044, CASE_META_BASE_ADDR_UV[63:32]);
            apb_write(16'h0048, CASE_TILE_BASE_ADDR_UV[31:0]);
            apb_write(16'h004c, CASE_TILE_BASE_ADDR_UV[63:32]);
            apb_write(16'h0060, 32'h0000_0021);
        end
    endtask

    task automatic program_wrapper_regs;
        reg cfg_4line_format;
        reg cfg_lossy_rgba_2_1;
        reg [31:0] tile_cfg2_data;
        begin
            cfg_4line_format = CASE_IS_NV12 ? 1'b0 : 1'b1;
            cfg_lossy_rgba_2_1 = (CASE_IS_LOSSY_RGBA_2_1 != 0);
            tile_cfg2_data = 32'h0000_000f;
            tile_cfg2_data[8] = (CASE_CI_LOSSY != 0);

            apb_write(16'h0008, {20'd0, cfg_lossy_rgba_2_1, cfg_4line_format,
                                  1'b1, 5'd16, 1'b0, 1'b1, 1'b1, 1'b0});
            apb_write(16'h000c, CASE_TILE_PITCH_UNITS);
            apb_write(16'h0010, tile_cfg2_data);
            apb_write(16'h0014, 32'h0000_0001);

            apb_write(16'h0018, {9'd0, CASE_ROTATE_MODE[1:0], CASE_BASE_FORMAT, IMG_W[15:0]});
            apb_write(16'h001c, {CASE_OTF_H_SYNC[15:0], CASE_OTF_H_TOTAL[15:0]});
            apb_write(16'h0020, {CASE_OTF_H_ACT[15:0], CASE_OTF_H_BP[15:0]});
            apb_write(16'h0024, {CFG_OTF_V_SYNC[15:0], CASE_OTF_V_TOTAL[15:0]});
            apb_write(16'h0028, {CASE_OTF_V_ACT[15:0], CFG_OTF_V_BP[15:0]});
            apb_write(16'h002c, {CASE_TILE_Y_NUMBERS[15:0], CASE_TILE_X_NUMBERS[15:0]});

            program_frame_base_and_start();
        end
    endtask

    task automatic enc_apb_write;
        input [APB_AW-1:0] addr;
        input [APB_DW-1:0] data;
        begin
            @(posedge PCLK);
            enc_PSEL    <= 1'b1;
            enc_PENABLE <= 1'b0;
            enc_PWRITE  <= 1'b1;
            enc_PADDR   <= addr;
            enc_PWDATA  <= data;
            @(posedge PCLK);
            enc_PENABLE <= 1'b1;
            do begin
                @(posedge PCLK);
            end while (!enc_PREADY);
            enc_PSEL    <= 1'b0;
            enc_PENABLE <= 1'b0;
            enc_PWRITE  <= 1'b0;
            enc_PADDR   <= {APB_AW{1'b0}};
            enc_PWDATA  <= {APB_DW{1'b0}};
        end
    endtask

    task automatic program_enc_frame_start;
        begin
            enc_apb_write(16'h0060, 32'h0000_0021);
        end
    endtask

    task automatic program_enc_addr_cfg_once;
        begin
            enc_apb_write(16'h0030, CASE_META_BASE_ADDR_Y[31:0]);
            enc_apb_write(16'h0034, CASE_META_BASE_ADDR_Y[63:32]);
            enc_apb_write(16'h0038, CASE_TILE_BASE_ADDR_Y[31:0]);
            enc_apb_write(16'h003c, CASE_TILE_BASE_ADDR_Y[63:32]);
            enc_apb_write(16'h0040, CASE_META_BASE_ADDR_UV[31:0]);
            enc_apb_write(16'h0044, CASE_META_BASE_ADDR_UV[63:32]);
            enc_apb_write(16'h0048, CASE_TILE_BASE_ADDR_UV[31:0]);
            enc_apb_write(16'h004c, CASE_TILE_BASE_ADDR_UV[63:32]);
        end
    endtask

    task automatic program_enc_wrapper_regs;
        reg [31:0] reg_tile_cfg0;
        reg [31:0] reg_tile_cfg1;
        reg [31:0] reg_ci_cfg0;
        reg [31:0] reg_ci_cfg1;
        reg [31:0] reg_ci_cfg2;
        reg [31:0] reg_ci_cfg3;
        reg [31:0] reg_otf_cfg0;
        reg [31:0] reg_otf_cfg1;
        reg [31:0] reg_otf_cfg2;
        reg [31:0] reg_otf_cfg3;
        reg [31:0] reg_meta_active_size;
        reg [31:0] reg_meta_pitch;
        integer addr_cfg_idx;
        begin
            reg_tile_cfg0             = 32'd0;
            reg_tile_cfg0[0]          = 1'b1;
            reg_tile_cfg0[2]          = 1'b1;
            reg_tile_cfg0[3]          = 1'b1;
            reg_tile_cfg0[12:8]       = CASE_HIGHEST_BANK[4:0];
            reg_tile_cfg0[16]         = 1'b1;

            reg_tile_cfg1             = 32'd0;
            reg_tile_cfg1[0]          = CASE_IS_G016 ? 1'b1 :
                                        (CASE_HAS_PLANE1 ? 1'b0 : 1'b1);
            reg_tile_cfg1[1]          = (CASE_IS_LOSSY_RGBA_2_1 != 0);
            reg_tile_cfg1[26:16]      = CASE_TILE_PITCH_UNITS[10:0];

            reg_ci_cfg0               = 32'd0;
            reg_ci_cfg0[0]            = 1'b1;
            reg_ci_cfg0[10:8]         = 3'd7;
            reg_ci_cfg0[20:16]        = expected_dec_meta_format(1'b0);

            reg_ci_cfg1               = 32'd0;
            reg_ci_cfg1[16]           = (CASE_CI_LOSSY != 0);

            reg_ci_cfg2               = 32'd0;
            reg_ci_cfg2[2:0]          = CASE_UBWC_CFG_0;
            reg_ci_cfg2[5:3]          = CASE_UBWC_CFG_1;
            reg_ci_cfg2[9:6]          = CASE_UBWC_CFG_2;
            reg_ci_cfg2[13:10]        = CASE_UBWC_CFG_3;
            reg_ci_cfg2[17:14]        = CASE_UBWC_CFG_4;
            reg_ci_cfg2[21:18]        = CASE_UBWC_CFG_5;
            reg_ci_cfg2[23:22]        = CASE_UBWC_CFG_6;
            reg_ci_cfg2[25:24]        = CASE_UBWC_CFG_7;
            reg_ci_cfg2[27:26]        = CASE_UBWC_CFG_8;
            reg_ci_cfg2[30:28]        = CASE_UBWC_CFG_9;

            reg_ci_cfg3               = 32'd0;
            reg_ci_cfg3[5:0]          = CASE_UBWC_CFG_10;
            reg_ci_cfg3[13:8]         = CASE_UBWC_CFG_11;

            reg_otf_cfg0              = 32'd0;
            reg_otf_cfg0[2:0]         = CASE_BASE_FORMAT[2:0];

            reg_otf_cfg1              = {CASE_OTF_V_ACT[15:0], IMG_W[15:0]};
            reg_otf_cfg2              = {CASE_IS_G016 ? 16'd4 :
                                         (CASE_IS_NV12 ? 16'd8 : 16'd4),
                                         CASE_HAS_PLANE1 ? 16'd32 : 16'd16};
            reg_otf_cfg3              = {CASE_HAS_PLANE1 ? CASE_TILE_X_NUMBERS[15:0] : 16'd0,
                                         CASE_TILE_X_NUMBERS[15:0]};
            reg_meta_active_size      = {CASE_OTF_V_ACT[15:0], IMG_W[15:0]};
            reg_meta_pitch            = CASE_META_PITCH_BYTES[31:0];

            enc_apb_write(16'h000c, reg_tile_cfg1);
            enc_apb_write(16'h0008, reg_tile_cfg0);
            for (addr_cfg_idx = 0;
                 addr_cfg_idx < ((tb_frame_repeat < 8) ? tb_frame_repeat : 8);
                 addr_cfg_idx = addr_cfg_idx + 1) begin
                program_enc_addr_cfg_once();
            end
            enc_apb_write(16'h0014, reg_ci_cfg1);
            enc_apb_write(16'h0018, reg_ci_cfg2);
            enc_apb_write(16'h001c, reg_ci_cfg3);
            enc_apb_write(16'h0010, reg_ci_cfg0);
            enc_apb_write(16'h0024, reg_otf_cfg1);
            enc_apb_write(16'h0028, reg_otf_cfg2);
            enc_apb_write(16'h002c, reg_otf_cfg3);
            enc_apb_write(16'h0050, reg_meta_active_size);
            enc_apb_write(16'h0054, reg_meta_pitch);
            enc_apb_write(16'h0020, reg_otf_cfg0);
        end
    endtask

    tb_dec_pdp_sram_delay #(
        .ADDR_WIDTH (COM_BUF_AW),
        .DEPTH      (OTF_SRAM_DEPTH)
    ) u_otf_sram_bank_a (
        .clk   (i_axi_clk),
        .wen   (o_otf_sram_a_wen),
        .waddr (o_otf_sram_a_waddr),
        .wdata (o_otf_sram_a_wdata),
        .ren   (o_otf_sram_a_ren),
        .raddr (o_otf_sram_a_raddr),
        .rdata (i_otf_sram_a_rdata),
        .rvalid(i_bank0_dout_vld)
    );

    tb_dec_pdp_sram_delay #(
        .ADDR_WIDTH (COM_BUF_AW),
        .DEPTH      (OTF_SRAM_DEPTH)
    ) u_otf_sram_bank_b (
        .clk   (i_axi_clk),
        .wen   (o_otf_sram_b_wen),
        .waddr (o_otf_sram_b_waddr),
        .wdata (o_otf_sram_b_wdata),
        .ren   (o_otf_sram_b_ren),
        .raddr (o_otf_sram_b_raddr),
        .rdata (i_otf_sram_b_rdata),
        .rvalid(i_bank1_dout_vld)
    );

    tb_dec_pdp_sram_delay #(
        .ADDR_WIDTH (COM_BUF_AW),
        .DEPTH      (OTF_SRAM_DEPTH)
    ) u_fake_otf_sram_bank_a (
        .clk   (i_axi_clk),
        .wen   (fake_otf_sram_a_wen),
        .waddr (fake_otf_sram_a_waddr),
        .wdata (fake_otf_sram_a_wdata),
        .ren   (fake_otf_sram_a_ren),
        .raddr (fake_otf_sram_a_raddr),
        .rdata (fake_otf_sram_a_rdata),
        .rvalid(fake_otf_sram_a_rvalid)
    );

    tb_dec_pdp_sram_delay #(
        .ADDR_WIDTH (COM_BUF_AW),
        .DEPTH      (OTF_SRAM_DEPTH)
    ) u_fake_otf_sram_bank_b (
        .clk   (i_axi_clk),
        .wen   (fake_otf_sram_b_wen),
        .waddr (fake_otf_sram_b_waddr),
        .wdata (fake_otf_sram_b_wdata),
        .ren   (fake_otf_sram_b_ren),
        .raddr (fake_otf_sram_b_raddr),
        .rdata (fake_otf_sram_b_rdata),
        .rvalid(fake_otf_sram_b_rvalid)
    );

    ubwc_dec_wrapper_top #(
        .APB_AW   (APB_AW),
        .APB_DW   (APB_DW),
        .AXI_AW   (AXI_AW),
        .AXI_DW   (M_AXI_DW),
        .AXI_IDW  (AXI_IDW),
        .AXI_LENW (AXI_LENW),
        .SB_WIDTH (SB_WIDTH),
        .COM_BUF_AW (COM_BUF_AW),
        .FORCE_FULL_PAYLOAD (FORCE_FULL_PAYLOAD_CASE),
        .DEC_VIVO_FAKE_MODEL_EN           ((TB_REAL_VIVO_MODE == 0) ? 1 : 0),
        .DEC_VIVO_FAKE_TILE_EXPECT_LINEAR (CASE_TILE_EXPECT_LINEAR),
        .DEC_VIVO_FAKE_IMG_W              (IMG_W),
        .DEC_VIVO_FAKE_RGBA_ACTIVE_H      (RGBA_ACTIVE_H),
        .DEC_VIVO_FAKE_RGBA_TILE_PITCH    (RGBA_TILE_PITCH),
        .DEC_VIVO_FAKE_RGBA_TILE_COLS     (RGBA_TILE_X_COUNT),
        .DEC_VIVO_FAKE_RGBA_TILE_ROWS     (RGBA_TILE_Y_COUNT),
        .DEC_VIVO_FAKE_NV12_ACTIVE_H      (NV12_ACTIVE_H),
        .DEC_VIVO_FAKE_NV12_UV_ACTIVE_H   (NV12_ACTIVE_H / 2),
        .DEC_VIVO_FAKE_NV12_TILE_PITCH    (NV12_TILE_PITCH),
        .DEC_VIVO_FAKE_NV12_Y_TILE_COLS   (NV12_TILE_X_COUNT),
        .DEC_VIVO_FAKE_NV12_UV_TILE_COLS  (NV12_TILE_X_COUNT),
        .DEC_VIVO_FAKE_NV12_Y_TILE_ROWS   (NV12_Y_TILE_Y_COUNT),
        .DEC_VIVO_FAKE_NV12_UV_TILE_ROWS  (NV12_UV_TILE_Y_COUNT),
        .DEC_VIVO_FAKE_G016_ACTIVE_H      (G016_ACTIVE_H),
        .DEC_VIVO_FAKE_G016_UV_ACTIVE_H   (G016_ACTIVE_H / 2),
        .DEC_VIVO_FAKE_G016_TILE_PITCH    (G016_TILE_PITCH),
        .DEC_VIVO_FAKE_G016_Y_TILE_COLS   (G016_TILE_X_COUNT),
        .DEC_VIVO_FAKE_G016_UV_TILE_COLS  (G016_TILE_X_COUNT),
        .DEC_VIVO_FAKE_G016_Y_TILE_ROWS   (G016_Y_TILE_Y_COUNT),
        .DEC_VIVO_FAKE_G016_UV_TILE_ROWS  (G016_UV_TILE_Y_COUNT),
        .DEC_VIVO_FAKE_META_PITCH_BYTES   (CASE_META_PITCH_BYTES),
        .DEC_VIVO_FAKE_TILE_BASE_Y_ADDR   (CASE_TILE_BASE_ADDR_Y),
        .DEC_VIVO_FAKE_TILE_BASE_UV_ADDR  (CASE_TILE_BASE_ADDR_UV),
        .DEC_VIVO_FAKE_META_BASE_Y_ADDR   (CASE_META_BASE_ADDR_Y),
        .DEC_VIVO_FAKE_META_BASE_UV_ADDR  (CASE_META_BASE_ADDR_UV),
        .DEC_VIVO_FAKE_TILE0_WORDS64      (CASE_TILE0_WORDS64),
        .DEC_VIVO_FAKE_TILE1_WORDS64      (CASE_TILE1_WORDS64),
        .DEC_VIVO_FAKE_CMP0_WORDS64       (CASE_CMP0_WORDS64),
        .DEC_VIVO_FAKE_CMP1_WORDS64       (CASE_CMP1_WORDS64),
        .DEC_VIVO_FAKE_META0_WORDS64      (CASE_META0_WORDS64),
        .DEC_VIVO_FAKE_META1_WORDS64      (CASE_META1_WORDS64)
    ) dut (
        .PCLK              (PCLK),
        .PRESETn           (PRESETn),
        .PSEL              (PSEL),
        .PENABLE           (PENABLE),
        .PADDR             (PADDR),
        .PWRITE            (PWRITE),
        .PWDATA            (PWDATA),
        .PREADY            (PREADY),
        .PSLVERR           (PSLVERR),
        .PRDATA            (PRDATA),
        .i_otf_clk         (i_otf_clk),
        .i_vivo_clk        (i_vivo_clk),
        .i_otf_rstn        (i_otf_rstn),
        .i_vivo_rstn       (i_vivo_rstn),
        .o_otf_vsync       (o_otf_vsync),
        .o_otf_hsync       (o_otf_hsync),
        .o_otf_de          (o_otf_de),
        .o_otf_data        (o_otf_data),
        .o_otf_fcnt        (o_otf_fcnt),
        .o_otf_lcnt        (o_otf_lcnt),
        .i_otf_ready       (dec_i_otf_ready_eff),
        .o_bank0_en        (o_bank0_en),
        .o_bank0_wen       (o_bank0_wen),
        .o_bank0_addr      (o_bank0_addr),
        .o_bank0_din       (o_bank0_din),
        .i_bank0_dout      (i_bank0_dout),
        .i_bank0_dout_vld  (i_bank0_dout_vld),
        .o_bank1_en        (o_bank1_en),
        .o_bank1_wen       (o_bank1_wen),
        .o_bank1_addr      (o_bank1_addr),
        .o_bank1_din       (o_bank1_din),
        .i_bank1_dout      (i_bank1_dout),
        .i_bank1_dout_vld  (i_bank1_dout_vld),
        .i_axi_clk         (i_axi_clk),
        .i_axi_rstn        (i_axi_rstn),
        .o_m_axi_arid      (o_m_axi_arid),
        .o_m_axi_araddr    (o_m_axi_araddr),
        .o_m_axi_arlen     (o_m_axi_arlen),
        .o_m_axi_arsize    (o_m_axi_arsize),
        .o_m_axi_arburst   (o_m_axi_arburst),
        .o_m_axi_arlock    (o_m_axi_arlock),
        .o_m_axi_arcache   (o_m_axi_arcache),
        .o_m_axi_arprot    (o_m_axi_arprot),
        .o_m_axi_arvalid   (o_m_axi_arvalid),
        .i_m_axi_arready   (i_m_axi_arready),
        .i_m_axi_rid       (i_m_axi_rid),
        .i_m_axi_rdata     (i_m_axi_rdata),
        .i_m_axi_rvalid    (i_m_axi_rvalid),
        .i_m_axi_rresp     (i_m_axi_rresp),
        .i_m_axi_rlast     (i_m_axi_rlast),
        .o_m_axi_rready    (o_m_axi_rready),
        .o_stage_done      (o_stage_done),
        .o_frame_done      (o_frame_done),
        .o_irq             (o_irq)
    );

    generate
        if (LOOP_TO_ENC != 0) begin : g_dec_to_enc_loop
            tb_dec_to_enc_sync_sram_1rw #(
                .ADDR_WIDTH (COM_BUF_AW),
                .DEPTH      (OTF_SRAM_DEPTH)
            ) u_enc_sram_bank0 (
                .clk      (i_axi_clk),
                .en       (enc_bank0_en),
                .wen      (enc_bank0_wen),
                .addr     (enc_bank0_addr),
                .din      (enc_bank0_din),
                .dout     (enc_bank0_dout),
                .dout_vld (enc_bank0_dout_vld)
            );

            tb_dec_to_enc_sync_sram_1rw #(
                .ADDR_WIDTH (COM_BUF_AW),
                .DEPTH      (OTF_SRAM_DEPTH)
            ) u_enc_sram_bank1 (
                .clk      (i_axi_clk),
                .en       (enc_bank1_en),
                .wen      (enc_bank1_wen),
                .addr     (enc_bank1_addr),
                .din      (enc_bank1_din),
                .dout     (enc_bank1_dout),
                .dout_vld (enc_bank1_dout_vld)
            );

            ubwc_enc_wrapper_top #(
                .SB_WIDTH                         (36),
                .APB_AW                           (APB_AW),
                .APB_DW                           (APB_DW),
                .AXI_AW                           (AXI_AW),
                .AXI_DW                           (M_AXI_DW),
                .AXI_LENW                         (AXI_LENW),
                .AXI_IDW                          (AXI_IDW),
                .COM_BUF_AW                       (COM_BUF_AW),
                .COM_BUF_DW                       (128),
                .ENC_VIVO_FAKE_MODEL_EN           (1),
                .ENC_VIVO_FAKE_TILE_EXPECT_LINEAR (CASE_TILE_EXPECT_LINEAR),
                .ENC_VIVO_FAKE_IMG_W              (IMG_W),
                .ENC_VIVO_FAKE_RGBA_ACTIVE_H      (RGBA_ACTIVE_H),
                .ENC_VIVO_FAKE_RGBA_TILE_PITCH    (RGBA_TILE_PITCH),
                .ENC_VIVO_FAKE_RGBA_TILE_COLS     (RGBA_TILE_X_COUNT),
                .ENC_VIVO_FAKE_RGBA_TILE_ROWS     (RGBA_TILE_Y_COUNT),
                .ENC_VIVO_FAKE_NV12_ACTIVE_H      (NV12_ACTIVE_H),
                .ENC_VIVO_FAKE_NV12_UV_ACTIVE_H   (NV12_ACTIVE_H / 2),
                .ENC_VIVO_FAKE_NV12_TILE_PITCH    (NV12_TILE_PITCH),
                .ENC_VIVO_FAKE_NV12_Y_TILE_COLS   (NV12_TILE_X_COUNT),
                .ENC_VIVO_FAKE_NV12_UV_TILE_COLS  (NV12_TILE_X_COUNT),
                .ENC_VIVO_FAKE_NV12_Y_TILE_ROWS   (NV12_Y_TILE_Y_COUNT),
                .ENC_VIVO_FAKE_NV12_UV_TILE_ROWS  (NV12_UV_TILE_Y_COUNT),
                .ENC_VIVO_FAKE_G016_ACTIVE_H      (G016_ACTIVE_H),
                .ENC_VIVO_FAKE_G016_UV_ACTIVE_H   (G016_ACTIVE_H / 2),
                .ENC_VIVO_FAKE_G016_TILE_PITCH    (G016_TILE_PITCH),
                .ENC_VIVO_FAKE_G016_Y_TILE_COLS   (G016_TILE_X_COUNT),
                .ENC_VIVO_FAKE_G016_UV_TILE_COLS  (G016_TILE_X_COUNT),
                .ENC_VIVO_FAKE_G016_Y_TILE_ROWS   (G016_Y_TILE_Y_COUNT),
                .ENC_VIVO_FAKE_G016_UV_TILE_ROWS  (G016_UV_TILE_Y_COUNT),
                .ENC_VIVO_FAKE_META_PITCH_BYTES   (CASE_META_PITCH_BYTES),
                .ENC_VIVO_FAKE_TILE_BASE_Y_ADDR   (CASE_TILE_BASE_ADDR_Y),
                .ENC_VIVO_FAKE_TILE_BASE_UV_ADDR  (CASE_TILE_BASE_ADDR_UV),
                .ENC_VIVO_FAKE_META_BASE_Y_ADDR   (CASE_META_BASE_ADDR_Y),
                .ENC_VIVO_FAKE_META_BASE_UV_ADDR  (CASE_META_BASE_ADDR_UV),
                .ENC_VIVO_FAKE_TILE0_WORDS64      (CASE_TILE0_WORDS64),
                .ENC_VIVO_FAKE_TILE1_WORDS64      (CASE_TILE1_WORDS64),
                .ENC_VIVO_FAKE_CMP0_WORDS64       (CASE_TILE0_WORDS64),
                .ENC_VIVO_FAKE_CMP1_WORDS64       (CASE_TILE1_WORDS64),
                .ENC_VIVO_FAKE_META0_WORDS64      (CASE_META0_WORDS64),
                .ENC_VIVO_FAKE_META1_WORDS64      (CASE_META1_WORDS64)
            ) enc_dut (
                .PCLK              (PCLK),
                .PRESETn           (PRESETn),
                .PSEL              (enc_PSEL),
                .PENABLE           (enc_PENABLE),
                .PADDR             (enc_PADDR),
                .PWRITE            (enc_PWRITE),
                .PWDATA            (enc_PWDATA),
                .PREADY            (enc_PREADY),
                .PSLVERR           (enc_PSLVERR),
                .PRDATA            (enc_PRDATA),
                .i_axi_clk         (i_axi_clk),
                .i_otf_clk         (i_otf_clk),
                .i_vivo_clk        (i_vivo_clk),
                .i_axi_rstn        (i_axi_rstn),
                .i_otf_rstn        (i_otf_rstn),
                .i_vivo_rstn       (i_vivo_rstn),
                .i_otf_vsync       (o_otf_vsync),
                .i_otf_hsync       (o_otf_hsync),
                .i_otf_de          (o_otf_de),
                .i_otf_data        (o_otf_data),
                .i_otf_fcnt        (o_otf_fcnt),
                .i_otf_lcnt        (o_otf_lcnt),
                .o_otf_ready       (enc_o_otf_ready),
                .o_bank0_en        (enc_bank0_en),
                .o_bank0_wen       (enc_bank0_wen),
                .o_bank0_addr      (enc_bank0_addr),
                .o_bank0_din       (enc_bank0_din),
                .i_bank0_dout      (enc_bank0_dout),
                .i_bank0_dout_vld  (enc_bank0_dout_vld),
                .o_bank1_en        (enc_bank1_en),
                .o_bank1_wen       (enc_bank1_wen),
                .o_bank1_addr      (enc_bank1_addr),
                .o_bank1_din       (enc_bank1_din),
                .i_bank1_dout      (enc_bank1_dout),
                .i_bank1_dout_vld  (enc_bank1_dout_vld),
                .o_m_axi_awid      (enc_o_m_axi_awid),
                .o_m_axi_awaddr    (enc_o_m_axi_awaddr),
                .o_m_axi_awlen     (enc_o_m_axi_awlen),
                .o_m_axi_awsize    (enc_o_m_axi_awsize),
                .o_m_axi_awburst   (enc_o_m_axi_awburst),
                .o_m_axi_awlock    (enc_o_m_axi_awlock),
                .o_m_axi_awcache   (enc_o_m_axi_awcache),
                .o_m_axi_awprot    (enc_o_m_axi_awprot),
                .o_m_axi_awvalid   (enc_o_m_axi_awvalid),
                .i_m_axi_awready   (enc_i_m_axi_awready),
                .o_m_axi_wdata     (enc_o_m_axi_wdata),
                .o_m_axi_wstrb     (enc_o_m_axi_wstrb),
                .o_m_axi_wvalid    (enc_o_m_axi_wvalid),
                .o_m_axi_wlast     (enc_o_m_axi_wlast),
                .i_m_axi_wready    (enc_i_m_axi_wready),
                .i_m_axi_bid       (enc_i_m_axi_bid),
                .i_m_axi_bresp     (enc_i_m_axi_bresp),
                .i_m_axi_bvalid    (enc_i_m_axi_bvalid),
                .o_m_axi_bready    (enc_o_m_axi_bready),
                .o_stage_done      (enc_o_stage_done),
                .o_frame_done      (enc_o_frame_done),
                .o_irq             (enc_o_irq)
            );
            assign loop_enc_coord_fifo_rd_en     = enc_dut.ubwc_enc_otf_to_tile_inst.coord_fifo_rd_en;
            assign loop_enc_coord_fifo_valid     = enc_dut.ubwc_enc_otf_to_tile_inst.coord_fifo_valid;
            assign loop_enc_coord_fifo_empty     = enc_dut.ubwc_enc_otf_to_tile_inst.coord_fifo_empty;
            assign loop_enc_coord_format         = enc_dut.ubwc_enc_otf_to_tile_inst.o_co_tile_format;
            assign loop_enc_coord_x              = enc_dut.ubwc_enc_otf_to_tile_inst.coord_tile_x_u16;
            assign loop_enc_coord_y              = enc_dut.ubwc_enc_otf_to_tile_inst.coord_tile_y_u16;
            assign loop_enc_coord_cols           = enc_dut.ubwc_enc_otf_to_tile_inst.coord_tile_cols;
            assign loop_enc_coord_rows           = enc_dut.ubwc_enc_otf_to_tile_inst.coord_tile_rows;
            assign loop_enc_coord_last_col       = enc_dut.ubwc_enc_otf_to_tile_inst.coord_last_col;
            assign loop_enc_coord_last_row       = enc_dut.ubwc_enc_otf_to_tile_inst.coord_last_row;
            assign loop_enc_coord_is_yuv420      = enc_dut.ubwc_enc_otf_to_tile_inst.coord_is_yuv420;
            assign loop_enc_coord_is_uv_plane    = enc_dut.ubwc_enc_otf_to_tile_inst.coord_is_uv_plane;
            assign loop_enc_coord_yuv_last_uv    = enc_dut.ubwc_enc_otf_to_tile_inst.coord_yuv_last_uv;
            assign loop_enc_coord_frame_last     = enc_dut.ubwc_enc_otf_to_tile_inst.coord_frame_last;
            assign loop_enc_addr_cfg_done_pulse  = enc_dut.ubwc_enc_otf_to_tile_inst.o_correct_irq_pulse;
            assign loop_enc_correct_irq_pulse    = enc_dut.ubwc_enc_otf_to_tile_inst.o_correct_irq_pulse;
            assign loop_enc_l2t_rd_state         = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_state;
            assign loop_enc_l2t_rd_plane         = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_plane;
            assign loop_enc_l2t_rd_uv_mode       = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_uv_mode;
            assign loop_enc_l2t_rd_tile_x        = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_tile_x;
            assign loop_enc_l2t_rd_group_y       = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_group_y;
            assign loop_enc_l2t_rd_word          = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_word_in_tile;
            assign loop_enc_l2t_issue_read       = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.issue_read;
            assign loop_enc_l2t_read_grant       = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.read_grant;
            assign loop_enc_l2t_uv_read_allowed  = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.rd_uv_read_allowed;
            assign loop_enc_l2t_resp_afull       = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.resp_fifo_almost_full;
            assign loop_enc_l2t_meta_afull       = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.read_meta_fifo_almost_full;
            assign loop_enc_l2t_resp_empty       = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.resp_fifo_empty;
            assign loop_enc_l2t_resp_valid       = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.resp_fifo_valid;
            assign loop_enc_l2t_meta_empty       = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.read_meta_fifo_empty;
            assign loop_enc_l2t_meta_valid       = enc_dut.ubwc_enc_otf_to_tile_inst.u_line_to_tile.read_meta_fifo_valid;
            assign loop_enc_l2t_tile_vld         = enc_dut.ubwc_enc_otf_to_tile_inst.line_tile_vld;
            assign loop_enc_l2t_tile_rdy         = enc_dut.ubwc_enc_otf_to_tile_inst.line_tile_rdy;
            assign loop_enc_l2t_data_fifo_full   = enc_dut.ubwc_enc_otf_to_tile_inst.data_fifo_full;
            assign loop_enc_l2t_data_fifo_afull  = enc_dut.ubwc_enc_otf_to_tile_inst.data_fifo_almost_full;
            assign loop_enc_l2t_ci_fifo_full     = enc_dut.ubwc_enc_otf_to_tile_inst.ci_fifo_full;
            assign loop_enc_l2t_coord_fifo_full  = enc_dut.ubwc_enc_otf_to_tile_inst.coord_fifo_full;
            assign loop_enc_l2t_half_valid       = enc_dut.ubwc_enc_otf_to_tile_inst.half_valid_r;
            assign loop_enc_l2t_half_last        = enc_dut.ubwc_enc_otf_to_tile_inst.half_last_r;
            assign loop_enc_l2t_flush_half_only  = enc_dut.ubwc_enc_otf_to_tile_inst.flush_half_only;
            assign loop_enc_l2t_pack_second_fire = enc_dut.ubwc_enc_otf_to_tile_inst.pack_second_fire;
            assign loop_enc_wrap_ci_valid             = enc_dut.enc_ci_valid;
            assign loop_enc_wrap_ci_ready             = enc_dut.enc_ci_ready;
            assign loop_enc_wrap_co_valid             = enc_dut.enc_co_valid;
            assign loop_enc_wrap_co_ready             = enc_dut.enc_co_ready;
            assign loop_enc_wrap_vivo_co_valid        = enc_dut.enc_vivo_co_valid;
            assign loop_enc_wrap_vivo_co_ready        = enc_dut.enc_vivo_co_ready;
            assign loop_enc_wrap_co_fifo_full         = enc_dut.enc_co_fifo_full;
            assign loop_enc_wrap_co_fifo_empty        = enc_dut.enc_co_fifo_empty;
            assign loop_enc_wrap_cvo_valid            = enc_dut.enc_cvo_valid;
            assign loop_enc_wrap_cvo_ready            = enc_dut.enc_cvo_ready;
            assign loop_enc_wrap_vivo_cvo_valid       = enc_dut.enc_vivo_cvo_valid;
            assign loop_enc_wrap_vivo_cvo_ready       = enc_dut.enc_vivo_cvo_ready;
            assign loop_enc_wrap_cvo_fifo_full        = enc_dut.enc_cvo_fifo_full;
            assign loop_enc_wrap_cvo_fifo_empty       = enc_dut.enc_cvo_fifo_empty;
            assign loop_enc_wrap_tile_addr_vld        = enc_dut.tile_addr_vld;
            assign loop_enc_wrap_fake_cmd_valid       = enc_dut.enc_vivo_cvo_valid;
            assign loop_enc_wrap_fake_cvo_beat_idx    = 4'd0;
            assign loop_enc_wrap_fake_cvo_total_beats = 4'd0;
            assign loop_enc_wrap_fake_cvo_valid_beats = 4'd0;
            assign loop_enc_wrap_fake_cvo_fire        = enc_dut.enc_vivo_cvo_valid &
                                                        enc_dut.enc_vivo_cvo_ready;
            assign loop_enc_wrap_fake_cvo_last        = enc_dut.enc_vivo_cvo_last;
        end else begin : g_no_dec_to_enc_loop
            assign loop_enc_coord_fifo_rd_en     = 1'b0;
            assign loop_enc_coord_fifo_valid     = 1'b0;
            assign loop_enc_coord_fifo_empty     = 1'b1;
            assign loop_enc_coord_format         = 5'd0;
            assign loop_enc_coord_x              = 16'd0;
            assign loop_enc_coord_y              = 16'd0;
            assign loop_enc_coord_cols           = 16'd0;
            assign loop_enc_coord_rows           = 16'd0;
            assign loop_enc_coord_last_col       = 1'b0;
            assign loop_enc_coord_last_row       = 1'b0;
            assign loop_enc_coord_is_yuv420      = 1'b0;
            assign loop_enc_coord_is_uv_plane    = 1'b0;
            assign loop_enc_coord_yuv_last_uv    = 1'b0;
            assign loop_enc_coord_frame_last     = 1'b0;
            assign loop_enc_addr_cfg_done_pulse  = 1'b0;
            assign loop_enc_correct_irq_pulse    = 1'b0;
            assign loop_enc_l2t_rd_state         = 2'd0;
            assign loop_enc_l2t_rd_plane         = 1'b0;
            assign loop_enc_l2t_rd_uv_mode       = 1'b0;
            assign loop_enc_l2t_rd_tile_x        = 16'd0;
            assign loop_enc_l2t_rd_group_y       = 16'd0;
            assign loop_enc_l2t_rd_word          = 16'd0;
            assign loop_enc_l2t_issue_read       = 1'b0;
            assign loop_enc_l2t_read_grant       = 1'b0;
            assign loop_enc_l2t_uv_read_allowed  = 1'b0;
            assign loop_enc_l2t_resp_afull       = 1'b0;
            assign loop_enc_l2t_meta_afull       = 1'b0;
            assign loop_enc_l2t_resp_empty       = 1'b1;
            assign loop_enc_l2t_resp_valid       = 1'b0;
            assign loop_enc_l2t_meta_empty       = 1'b1;
            assign loop_enc_l2t_meta_valid       = 1'b0;
            assign loop_enc_l2t_tile_vld         = 1'b0;
            assign loop_enc_l2t_tile_rdy         = 1'b0;
            assign loop_enc_l2t_data_fifo_full   = 1'b0;
            assign loop_enc_l2t_data_fifo_afull  = 1'b0;
            assign loop_enc_l2t_ci_fifo_full     = 1'b0;
            assign loop_enc_l2t_coord_fifo_full  = 1'b0;
            assign loop_enc_l2t_half_valid       = 1'b0;
            assign loop_enc_l2t_half_last        = 1'b0;
            assign loop_enc_l2t_flush_half_only  = 1'b0;
            assign loop_enc_l2t_pack_second_fire = 1'b0;
            assign loop_enc_wrap_ci_valid             = 1'b0;
            assign loop_enc_wrap_ci_ready             = 1'b0;
            assign loop_enc_wrap_co_valid             = 1'b0;
            assign loop_enc_wrap_co_ready             = 1'b0;
            assign loop_enc_wrap_vivo_co_valid        = 1'b0;
            assign loop_enc_wrap_vivo_co_ready        = 1'b0;
            assign loop_enc_wrap_co_fifo_full         = 1'b0;
            assign loop_enc_wrap_co_fifo_empty        = 1'b1;
            assign loop_enc_wrap_cvo_valid            = 1'b0;
            assign loop_enc_wrap_cvo_ready            = 1'b0;
            assign loop_enc_wrap_vivo_cvo_valid       = 1'b0;
            assign loop_enc_wrap_vivo_cvo_ready       = 1'b0;
            assign loop_enc_wrap_cvo_fifo_full        = 1'b0;
            assign loop_enc_wrap_cvo_fifo_empty       = 1'b1;
            assign loop_enc_wrap_tile_addr_vld        = 1'b0;
            assign loop_enc_wrap_fake_cmd_valid       = 1'b0;
            assign loop_enc_wrap_fake_cvo_beat_idx    = 4'd0;
            assign loop_enc_wrap_fake_cvo_total_beats = 4'd0;
            assign loop_enc_wrap_fake_cvo_valid_beats = 4'd0;
            assign loop_enc_wrap_fake_cvo_fire        = 1'b0;
            assign loop_enc_wrap_fake_cvo_last        = 1'b0;
        end
    endgenerate

    ubwc_dec_tile_to_otf #(
        .SRAM_ADDR_W (COM_BUF_AW)
    ) u_fake_tile_to_otf (
        .clk_sram         (i_axi_clk),
        .clk_otf          (i_otf_clk),
        .rst_sram_n       (i_axi_rstn),
        .rst_otf_n        (i_otf_rstn),
        .i_frame_start    (1'b0),
        .i_frame_fcnt     (4'd0),
        .cfg_img_width    (CASE_OTF_H_ACT[15:0]),
        .cfg_format       (CASE_BASE_FORMAT),
`ifdef UBWC_DEC_ROTATION
        .i_rotate_mode    (2'd0),
`endif
        .cfg_otf_h_total  (CASE_OTF_H_TOTAL[15:0]),
        .cfg_otf_h_sync   (CASE_OTF_H_SYNC[15:0]),
        .cfg_otf_h_bp     (CASE_OTF_H_BP[15:0]),
        .cfg_otf_h_act    (CASE_OTF_H_ACT[15:0]),
        .cfg_otf_v_total  (CASE_OTF_V_TOTAL[15:0]),
        .cfg_otf_v_sync   (CFG_OTF_V_SYNC[15:0]),
        .cfg_otf_v_bp     (CFG_OTF_V_BP[15:0]),
        .cfg_otf_v_act    (CASE_OTF_V_ACT[15:0]),
        .s_axis_format    (inject_axis_format),
        .s_axis_tile_x    (inject_axis_tile_x),
        .s_axis_tile_y    (inject_axis_tile_y),
        .s_axis_tile_fcnt(4'd0),
        .s_axis_tile_valid(inject_axis_tile_valid),
        .s_axis_tile_ready(inject_axis_tile_ready),
        .s_axis_tdata     (inject_axis_tdata),
        .s_axis_tlast     (inject_axis_tlast),
        .s_axis_tvalid    (inject_axis_tvalid),
        .s_axis_tready    (inject_axis_tready),
        .sram_a_wen       (fake_otf_sram_a_wen),
        .sram_a_waddr     (fake_otf_sram_a_waddr),
        .sram_a_wdata     (fake_otf_sram_a_wdata),
        .sram_a_ren       (fake_otf_sram_a_ren),
        .sram_a_raddr     (fake_otf_sram_a_raddr),
        .sram_a_rdata     (fake_otf_sram_a_rdata),
        .sram_a_rvalid    (1'b1),
        .sram_b_wen       (fake_otf_sram_b_wen),
        .sram_b_waddr     (fake_otf_sram_b_waddr),
        .sram_b_wdata     (fake_otf_sram_b_wdata),
        .sram_b_ren       (fake_otf_sram_b_ren),
        .sram_b_raddr     (fake_otf_sram_b_raddr),
        .sram_b_rdata     (fake_otf_sram_b_rdata),
        .sram_b_rvalid    (1'b1),
        .o_otf_vsync      (fake_o_otf_vsync),
        .o_otf_hsync      (fake_o_otf_hsync),
        .o_otf_de         (fake_o_otf_de),
        .o_otf_data       (fake_o_otf_data),
        .o_otf_fcnt       (fake_o_otf_fcnt),
        .o_otf_lcnt       (fake_o_otf_lcnt),
        .i_otf_ready      (dec_i_otf_ready_eff),
        .o_busy                 (),
        .o_correct_irq_pulse    (fake_correct_irq_pulse),
        .o_underflow            (),
        .o_otf_line_count       (fake_otf_line_count),
        .o_otf_de_count         (fake_otf_de_count)
    );

    initial begin
        PCLK = 1'b0;
        forever #(TB_APB_CLK_HALF_NS) PCLK = ~PCLK;
    end

    initial begin
        i_axi_clk = 1'b0;
        forever #(TB_AXI_CLK_HALF_NS) i_axi_clk = ~i_axi_clk;
    end

    initial begin
        i_vivo_clk = 1'b0;
        forever #(TB_CORE_CLK_HALF_NS) i_vivo_clk = ~i_vivo_clk;
    end

    initial begin
        i_otf_clk = 1'b0;
        forever #(TB_OTF_CLK_HALF_NS) i_otf_clk = ~i_otf_clk;
    end

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        if (!i_otf_rstn) begin
            otf_ready_div <= 2'd0;
            i_otf_ready   <= 1'b0;
            otf_ready_rand_state <= (tb_otf_ready_seed == 0) ? 32'h3c6e_f372 : tb_otf_ready_seed[31:0];
        end else if (tb_otf_ready_random_en != 0) begin
            otf_ready_div <= 2'd0;
            otf_ready_rand_state <= lfsr_next(otf_ready_rand_state);
            i_otf_ready <= ready_from_stall_pct(otf_ready_rand_state, tb_otf_ready_stall_pct);
        end else if (CASE_IS_G016) begin
            // G016/P010 needs light sink-side backpressure in this TB so the
            // tile-to-OTF path can drain cleanly at the current clock ratio.
            otf_ready_div <= otf_ready_div + 1'b1;
            i_otf_ready   <= (otf_ready_div != 2'd3);
        end else begin
            otf_ready_div <= 2'd0;
            i_otf_ready   <= 1'b1;
        end
    end

    always @(posedge i_axi_clk) begin
        cycle_cnt <= cycle_cnt + 1;
    end

`ifdef UBWC_DEC_ROTATION
    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            rotate_dbg_prev_progress_sum <= 0;
            rotate_dbg_stall_cycles      <= 0;
        end else if ((CASE_DEC_ROTATE_EN != 0) && $test$plusargs("tb_rotate_debug_stop")) begin
            rotate_dbg_progress_sum = dec_meta_out_cnt +
                                      vivo_if_ci_accept_cnt +
                                      vivo_if_cvi_beat_cnt +
                                      vivo_if_rvo_beat_cnt +
                                      otf_beat_cnt +
                                      dut.u_tile_to_otf.u_rotate_ref.tile_done_count +
                                      dut.u_tile_to_otf.u_rotate_ref.tile_beat_idx +
                                      dut.u_tile_to_otf.u_rotate_ref.emit_line +
                                      dut.u_tile_to_otf.u_rotate_ref.emit_word_idx +
                                      dut.u_tile_to_otf.u_rotate_ref.otf_de_count_sram;
            if (rotate_dbg_progress_sum != rotate_dbg_prev_progress_sum) begin
                rotate_dbg_prev_progress_sum <= rotate_dbg_progress_sum;
                rotate_dbg_stall_cycles      <= 0;
            end else if (rotate_dbg_progress_sum != 0) begin
                rotate_dbg_stall_cycles <= rotate_dbg_stall_cycles + 1;
            end

            if ((rotate_dbg_progress_sum != 0) && (rotate_dbg_stall_cycles == 2000)) begin
                $display("[ROTDBG] stalled at time=%0t cycle=%0d progress=%0d", $time, cycle_cnt, rotate_dbg_progress_sum);
                $display("[ROTDBG] counts meta=%0d ci=%0d cvi=%0d rvo=%0d otf=%0d",
                         dec_meta_out_cnt,
                         vivo_if_ci_accept_cnt,
                         vivo_if_cvi_beat_cnt,
                         vivo_if_rvo_beat_cnt,
                         otf_beat_cnt);
                $display("[ROTDBG] meta v/r=%0b/%0b tile_ci v/r=%0b/%0b tile_cvi v/r=%0b/%0b",
                         dut.meta_dec_valid,
                         dut.meta_dec_ready,
                         dut.tile_ci_valid_int,
                         dut.tile_ci_ready_int,
                         dut.tile_cvi_valid_int,
                         dut.tile_cvi_ready_int);
                $display("[ROTDBG] vivo fifo ci_empty/full=%0b/%0b coord_v/full=%0b/%0b co_v=%0b rvo_empty/full=%0b/%0b",
                         dut.vivo_ci_fifo_empty,
                         dut.vivo_ci_fifo_full,
                         dut.vivo_coord_fifo_valid,
                         dut.vivo_coord_fifo_full,
                         dut.vivo_co_axi_valid,
                         dut.vivo_rvo_fifo_empty,
                         dut.vivo_rvo_fifo_full);
                $display("[ROTDBG] vivo int ci v/r=%0b/%0b cvi v/r=%0b/%0b gate=%0b tile_active=%0b in_left=%0d out_left=%0d co_valid=%0b",
                         dut.vivo_ci_valid_int,
                         dut.vivo_ci_ready_raw,
                         dut.vivo_cvi_valid_int,
                         dut.vivo_cvi_ready_int,
                         dut.vivo_cvi_gate_active,
                         dut.u_dec_vivo_top.r_tile_active,
                         dut.u_dec_vivo_top.r_in_beats_left,
                         dut.u_dec_vivo_top.r_out_beats_left,
                         dut.u_dec_vivo_top.r_co_valid);
                $display("[ROTDBG] arcmd ci_empty/full=%0b/%0b desc_used/rsp/complete=%0d/%0d/%0d reserved/resident=%0d/%0d rdata_empty/full=%0b/%0b cvi_active=%0b beats_left=%0d arvalid/ready=%0b/%0b rvalid/ready=%0b/%0b",
                         dut.u_tile_arcmd_gen.ci_fifo_empty,
                         dut.u_tile_arcmd_gen.ci_fifo_full,
                         dut.u_tile_arcmd_gen.desc_used_count,
                         dut.u_tile_arcmd_gen.rsp_desc_count,
                         dut.u_tile_arcmd_gen.complete_tile_count,
                         dut.u_tile_arcmd_gen.reserved_beat_count,
                         dut.u_tile_arcmd_gen.rdata_fifo_data_count,
                         dut.u_tile_arcmd_gen.rdata_fifo_empty,
                         dut.u_tile_arcmd_gen.rdata_fifo_full,
                         dut.u_tile_arcmd_gen.cvi_stream_active_reg,
                         dut.u_tile_arcmd_gen.cvi_stream_beats_left_reg,
                         dut.tile_m_axi_arvalid,
                         dut.tile_m_axi_arready,
                         dut.tile_m_axi_rvalid,
                         dut.tile_m_axi_rready);
                $display("[ROTDBG] wrapper rotate=%0b otf_tile v/r/fire=%0b/%0b/%0b rvo empty/full/wr/rd/last=%0b/%0b/%0b/%0b/%0b",
                         dut.vivo_rotate_active,
                         dut.otf_axis_tile_valid,
                         dut.otf_axis_tile_ready_int,
                         dut.otf_axis_tile_fire,
                         dut.vivo_rvo_fifo_empty,
                         dut.vivo_rvo_fifo_full,
                         dut.vivo_rvo_fifo_wr_en,
                         dut.vivo_rvo_fifo_rd_en,
                         dut.vivo_rvo_last);
                $display("[ROTDBG] rotate active=%0b hdr v/r=%0b/%0b data v/r=%0b/%0b tile_active=%0b beat=%0d done=%0d expect=%0d emit=%0b fifo_empty/full=%0b/%0b",
                         dut.u_tile_to_otf.rotate_active,
                         dut.u_tile_to_otf.s_axis_tile_valid,
                         dut.u_tile_to_otf.s_axis_tile_ready,
                         dut.u_tile_to_otf.s_axis_tvalid,
                         dut.u_tile_to_otf.s_axis_tready,
                         dut.u_tile_to_otf.u_rotate_ref.tile_active,
                         dut.u_tile_to_otf.u_rotate_ref.tile_beat_idx,
                         dut.u_tile_to_otf.u_rotate_ref.tile_done_count,
                         dut.u_tile_to_otf.u_rotate_ref.expect_tile_count,
                         dut.u_tile_to_otf.u_rotate_ref.emit_active,
                         dut.u_tile_to_otf.u_rotate_ref.fifo_empty,
                         dut.u_tile_to_otf.u_rotate_ref.fifo_full);
                $finish;
            end
        end
    end

    always @(posedge i_axi_clk) begin
        if ((CASE_DEC_ROTATE_EN != 0) &&
            $test$plusargs("tb_rotate_trace") &&
            (cycle_cnt != 0) &&
            ((cycle_cnt % 10000) == 0)) begin
            $display("[ROTTRACE] time=%0t cycle=%0d meta=%0d ci=%0d cvi=%0d rvo=%0d otf=%0d done=%0d beat=%0d emit=%0b line=%0d word=%0d fifo_cnt=%0d rvo_empty=%0b",
                     $time,
                     cycle_cnt,
                     dec_meta_out_cnt,
                     vivo_if_ci_accept_cnt,
                     vivo_if_cvi_beat_cnt,
                     vivo_if_rvo_beat_cnt,
                     otf_beat_cnt,
                     dut.u_tile_to_otf.u_rotate_ref.tile_done_count,
                     dut.u_tile_to_otf.u_rotate_ref.tile_beat_idx,
                     dut.u_tile_to_otf.u_rotate_ref.emit_active,
                     dut.u_tile_to_otf.u_rotate_ref.emit_line,
                     dut.u_tile_to_otf.u_rotate_ref.emit_word_idx,
                     dut.u_tile_to_otf.u_rotate_ref.fifo_rd_count,
                     dut.vivo_rvo_fifo_empty);
        end
    end

    initial begin : rotate_debug_stop_at_cycle
        tb_rotate_stop_cycle = 0;
        void'($value$plusargs("tb_rotate_stop_cycle=%d", tb_rotate_stop_cycle));
        if (tb_rotate_stop_cycle > 0) begin
            wait (PRESETn && i_axi_rstn && i_otf_rstn && i_vivo_rstn);
            wait (cycle_cnt >= tb_rotate_stop_cycle);
            $display("[ROTSTOP] cycle=%0d time=%0t", cycle_cnt, $time);
            $display("[ROTSTOP] ref busy=%0b tile_active=%0b emit=%0b line=%0d word=%0d done=%0d expect=%0d fifo empty/full/cnt=%0b/%0b/%0d start_ready=%0b fs_empty=%0b fs_rd=%0b otf_ready=%0b",
                     dut.u_tile_to_otf.u_rotate_ref.o_busy,
                     dut.u_tile_to_otf.u_rotate_ref.tile_active,
                     dut.u_tile_to_otf.u_rotate_ref.emit_active,
                     dut.u_tile_to_otf.u_rotate_ref.emit_line,
                     dut.u_tile_to_otf.u_rotate_ref.emit_word_idx,
                     dut.u_tile_to_otf.u_rotate_ref.tile_done_count,
                     dut.u_tile_to_otf.u_rotate_ref.expect_tile_count,
                     dut.u_tile_to_otf.u_rotate_ref.fifo_empty,
                     dut.u_tile_to_otf.u_rotate_ref.fifo_full,
                     dut.u_tile_to_otf.u_rotate_ref.fifo_rd_count,
                     dut.u_tile_to_otf.u_rotate_ref.fifo_start_ready,
                     dut.u_tile_to_otf.u_rotate_ref.frame_start_fifo_empty,
                     dut.u_tile_to_otf.u_rotate_ref.frame_start_fifo_rd_en,
                     dut.u_tile_to_otf.u_rotate_ref.otf_frame_start_ready);
            $display("[ROTSTOP] stream hdr v/r=%0b/%0b data v/r=%0b/%0b otf beats=%0d frame_done=%0d",
                     dut.u_tile_to_otf.u_rotate_ref.s_axis_tile_valid,
                     dut.u_tile_to_otf.u_rotate_ref.s_axis_tile_ready,
                     dut.u_tile_to_otf.u_rotate_ref.s_axis_tvalid,
                     dut.u_tile_to_otf.u_rotate_ref.s_axis_tready,
                     otf_beat_cnt,
                     otf_frame_done_count);
            $display("[ROTSTOP] wrapper coord_v=%0b otf_tile v/r/fire=%0b/%0b/%0b rvo empty/full wr/rd=%0b/%0b %0b/%0b",
                     dut.vivo_coord_fifo_valid,
                     dut.otf_axis_tile_valid,
                     dut.otf_axis_tile_ready_int,
                     dut.otf_axis_tile_fire,
                     dut.vivo_rvo_fifo_empty,
                     dut.vivo_rvo_fifo_full,
                     dut.vivo_rvo_fifo_wr_en,
                     dut.vivo_rvo_fifo_rd_en);
            $finish;
        end
    end
`endif

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            tile_queue_wr_ptr       <= 0;
            ci_queue_wr_ptr         <= 0;
            payload_cmd_cnt         <= 0;
            expected_rvo_beats_total<= 0;
            ci_accept_cnt           <= 0;
            tile_rbeat_no_rvo_cnt   <= 0;
            rvo_beat_cnt            <= 0;
            rvo_last_cnt            <= 0;
            co_active_cycle_cnt     <= 0;
            rvo_data_mismatch_cnt   <= 0;
            rvo_last_mismatch_cnt   <= 0;
            co_mismatch_cnt         <= 0;
            first_rvo_mismatch_fmt  <= 5'd0;
            first_rvo_mismatch_x    <= 12'd0;
            first_rvo_mismatch_y    <= 10'd0;
            first_rvo_mismatch_beat <= 0;
            first_rvo_expected_data <= {AXI_DW{1'b0}};
            first_rvo_actual_data   <= {AXI_DW{1'b0}};
            first_rvo_expected_alen <= 3'd0;
            first_rvo_actual_last   <= 1'b0;
            first_ar_mismatch_fmt   <= 5'd0;
            first_ar_mismatch_x     <= 12'd0;
            first_ar_mismatch_y     <= 10'd0;
            first_ar_expected_addr  <= {AXI_AW{1'b0}};
            first_ar_actual_addr    <= {AXI_AW{1'b0}};
            writer_vld_cnt          <= 0;
            writer_hdr_fire_cnt     <= 0;
            writer_data_fire_cnt    <= 0;
            writer_data_rd_cnt      <= 0;
            fetcher_done_cnt        <= 0;
            fifo_wr_cnt             <= 0;
            fifo_rd_cnt             <= 0;
            otf_fifo_empty_need_cnt <= 0;
            first_otf_fifo_empty_need_beat <= -1;
            otf_underflow_cnt       <= 0;
            fake_writer_vld_cnt     <= 0;
            fake_fetcher_done_cnt   <= 0;
            fake_fifo_wr_cnt        <= 0;
            fake_fifo_rd_cnt        <= 0;
            fake_hdr_hs_cnt         <= 0;
            fake_data_hs_cnt        <= 0;
            fake_sram_wen_cnt       <= 0;
            fake_tile_last_write_cnt<= 0;
            fake_slice_done_cnt     <= 0;
            fake_hdr_last_x_hs_cnt  <= 0;
            fake_hdr_x_max_seen     <= 0;
            m_rhandshake_cnt        <= 0;
            m_r_nosink_cnt          <= 0;
            m_r_nosink_meta_cnt     <= 0;
            m_r_nosink_tile_cnt     <= 0;
            rbuf_meta_drain_cnt     <= 0;
            rbuf_tile_drain_cnt     <= 0;
            compressed_tile_hs_cnt  <= 0;
            compressed_tile_last_cnt<= 0;
            vivo_ci_mismatch_cnt    <= 0;
            vivo_cvi_data_mismatch_cnt <= 0;
            vivo_cvi_last_mismatch_cnt <= 0;
            dec_meta_out_cnt        <= 0;
            dec_meta_mismatch_cnt   <= 0;
            first_dec_meta_mismatch_idx <= -1;
            first_dec_meta_expected_raw <= 8'd0;
            first_dec_meta_actual_raw   <= 8'd0;
            first_dec_meta_expected_format <= 5'd0;
            first_dec_meta_actual_format   <= 5'd0;
            first_dec_meta_expected_flag <= 4'd0;
            first_dec_meta_actual_flag   <= 4'd0;
            first_dec_meta_expected_alen <= 3'd0;
            first_dec_meta_actual_alen   <= 3'd0;
            first_dec_meta_expected_x <= 12'd0;
            first_dec_meta_actual_x   <= 12'd0;
            first_dec_meta_expected_y <= 10'd0;
            first_dec_meta_actual_y   <= 10'd0;
            first_vivo_ci_mismatch_fmt <= 5'd0;
            first_vivo_ci_mismatch_x <= 12'd0;
            first_vivo_ci_mismatch_y <= 10'd0;
            first_vivo_ci_expected_raw <= 8'd0;
            first_vivo_ci_expected_metadata <= 4'd0;
            first_vivo_ci_actual_metadata <= 4'd0;
            first_vivo_ci_expected_alen <= 3'd0;
            first_vivo_ci_actual_alen <= 3'd0;
            first_vivo_cvi_mismatch_fmt <= 5'd0;
            first_vivo_cvi_mismatch_x <= 12'd0;
            first_vivo_cvi_mismatch_y <= 10'd0;
            first_vivo_cvi_mismatch_beat <= 0;
            first_vivo_cvi_expected_data <= {AXI_DW{1'b0}};
            first_vivo_cvi_actual_data <= {AXI_DW{1'b0}};
            first_vivo_cvi_expected_last <= 1'b0;
            first_vivo_cvi_actual_last <= 1'b0;
            exp_dec_meta_is_uv     <= CASE_HAS_PLANE1 ? 1'b1 : 1'b0;
            exp_dec_meta_phase     <= CASE_HAS_PLANE1 ? DEC_META_PHASE_UV : DEC_META_PHASE_YH;
            exp_dec_meta_x         <= (CASE_DEC_ROTATION == 270) ?
                                      (CASE_META_X_SAMPLES - 1) : 12'd0;
            exp_dec_meta_y         <= 10'd0;
            exp_dec_meta_uv_y      <= 10'd0;
            exp_dec_meta_done      <= 1'b0;
            fake_ci_fifo_wr_cnt     <= 0;
            fake_ci_fifo_rd_cnt     <= 0;
            cvi_tile_rd_ptr         <= 0;
            cvi_tile_beat_idx       <= 0;
            axi_r_cccc_seen_curr_beat <= 1'b0;
            axi_rdata_cccc_cnt      <= 0;
            axi_rdata_cccc_meta_cnt <= 0;
            axi_rdata_cccc_tile_cnt <= 0;
            first_axi_rdata_cccc_cycle <= -1;
            first_axi_rdata_cccc_lane  <= -1;
            first_axi_rdata_cccc_addr  <= {AXI_AW{1'b0}};
            first_axi_rdata_cccc_is_meta <= 1'b0;
            first_axi_rdata_cccc_data <= {M_AXI_DW{1'b0}};
            first_m_r_nosink_cycle  <= -1;
            first_m_r_nosink_owner_s0 <= 1'b0;
            first_m_r_nosink_rlast  <= 1'b0;
            first_m_r_nosink_rbuf_valid <= 1'b0;
            first_m_r_nosink_payload_left <= 8'd0;
            first_m_r_nosink_ar_left <= 8'd0;
        end else begin
            if (dut.u_tile_arcmd_gen.tile_cmd_valid &&
                dut.u_tile_arcmd_gen.tile_cmd_ready &&
                !dut.u_tile_arcmd_gen.tile_cmd_meta[3]) begin
                tile_fmt_queue[tile_queue_wr_ptr]  <= dut.u_tile_arcmd_gen.tile_cmd_format;
                tile_x_queue[tile_queue_wr_ptr]    <= dut.u_tile_arcmd_gen.dec_meta_x;
                tile_y_queue[tile_queue_wr_ptr]    <= dut.u_tile_arcmd_gen.dec_meta_y;
                tile_alen_queue[tile_queue_wr_ptr] <= dut.u_tile_arcmd_gen.tile_cmd_alen;
                tile_addr_queue[tile_queue_wr_ptr] <= expected_tile_addr(dut.u_tile_arcmd_gen.tile_cmd_format,
                                                                         dut.u_tile_arcmd_gen.dec_meta_x,
                                                                         dut.u_tile_arcmd_gen.dec_meta_y,
                                                                         dut.u_tile_arcmd_gen.tile_cmd_alen);
                tile_queue_wr_ptr        <= tile_queue_wr_ptr + 1;
                payload_cmd_cnt          <= payload_cmd_cnt + 1;
                last_progress_cycle      <= cycle_cnt;
            end

            if (dut.meta_dec_valid && dut.meta_dec_ready) begin : dec_meta_compare_block
                reg [4:0]  exp_fmt;
                reg [7:0]  exp_raw;
                reg [3:0]  exp_flag;
                reg [2:0]  exp_alen;
                reg [11:0] exp_x;
                reg [9:0]  exp_y;
                exp_fmt         = expected_dec_meta_format(exp_dec_meta_is_uv);
                exp_x           = exp_dec_meta_x;
                exp_y           = exp_dec_meta_is_uv ? exp_dec_meta_uv_y :
                                  ((exp_dec_meta_phase == DEC_META_PHASE_YL) ?
                                   (exp_dec_meta_y + 1'b1) : exp_dec_meta_y);
                exp_raw         = expected_dec_meta_raw(exp_fmt, exp_x, exp_y);
                exp_flag        = expected_dec_meta_flag_by_coord(exp_fmt, exp_raw, exp_x, exp_y);
                exp_alen        = expected_dec_meta_alen_by_coord(exp_fmt, exp_raw, exp_x, exp_y);
                dec_meta_out_cnt <= dec_meta_out_cnt + 1;
                write_dec_meta_line(dec_meta_actual_fd, dec_meta_out_cnt,
                                    dut.u_meta_data_gen.meta_data,
                                    dut.meta_dec_format,
                                    dut.meta_dec_flag,
                                    dut.meta_dec_alen,
                                    dut.meta_dec_x,
                                    dut.meta_dec_y);
                write_fc_sc_event("META_OUT", dec_meta_out_cnt,
                                  dut.u_meta_data_gen.meta_data,
                                  dut.meta_dec_format,
                                  dut.meta_dec_flag,
                                  dut.meta_dec_alen,
                                  {dut.u_meta_data_gen.meta_data[5],
                                   dut.u_meta_data_gen.meta_data[0]},
                                  dut.meta_dec_x,
                                  dut.meta_dec_y);

                if ((dec_meta_out_cnt >= expected_dec_meta_samples_total) ||
                    (dut.meta_dec_format !== exp_fmt) ||
                    (dut.meta_dec_flag !== exp_flag) ||
                    (dut.meta_dec_alen !== exp_alen) ||
                    (dut.meta_dec_x !== exp_x) ||
                    (dut.meta_dec_y !== exp_y)) begin
                    dec_meta_mismatch_cnt <= dec_meta_mismatch_cnt + 1;
                    if (first_dec_meta_mismatch_idx < 0) begin
                        first_dec_meta_mismatch_idx <= dec_meta_out_cnt;
                        first_dec_meta_expected_raw <= exp_raw;
                        first_dec_meta_actual_raw   <= dut.u_meta_data_gen.meta_data;
                        first_dec_meta_expected_format <= exp_fmt;
                        first_dec_meta_actual_format   <= dut.meta_dec_format;
                        first_dec_meta_expected_flag <= exp_flag;
                        first_dec_meta_actual_flag   <= dut.meta_dec_flag;
                        first_dec_meta_expected_alen <= exp_alen;
                        first_dec_meta_actual_alen   <= dut.meta_dec_alen;
                        first_dec_meta_expected_x <= exp_x;
                        first_dec_meta_actual_x   <= dut.meta_dec_x;
                        first_dec_meta_expected_y <= exp_y;
                        first_dec_meta_actual_y   <= dut.meta_dec_y;
                    end
                end

                if (((dec_meta_out_cnt + 1) % CASE_EXPECTED_DEC_META_SAMPLES) == 0) begin
                    exp_dec_meta_is_uv <= CASE_HAS_PLANE1 ? 1'b1 : 1'b0;
                    exp_dec_meta_phase <= CASE_HAS_PLANE1 ? DEC_META_PHASE_UV : DEC_META_PHASE_YH;
                    exp_dec_meta_x     <= (CASE_DEC_ROTATION == 270) ?
                                          (CASE_META_X_SAMPLES - 1) : 12'd0;
                    exp_dec_meta_y     <= 10'd0;
                    exp_dec_meta_uv_y  <= 10'd0;
                    exp_dec_meta_done  <= ((dec_meta_out_cnt + 1) >= expected_dec_meta_samples_total);
                end else if (CASE_DEC_ROTATE_EN && CASE_IS_NV12) begin
                    if (exp_dec_meta_is_uv) begin
                        if (exp_dec_meta_uv_y == (NV12_UV_ACTIVE_TILE_Y_COUNT - 1)) begin
                            exp_dec_meta_uv_y  <= 10'd0;
                            exp_dec_meta_y     <= 10'd0;
                            exp_dec_meta_is_uv <= 1'b0;
                            exp_dec_meta_phase <= DEC_META_PHASE_YH;
                        end else begin
                            exp_dec_meta_uv_y <= exp_dec_meta_uv_y + 1'b1;
                        end
                    end else begin
                        if (exp_dec_meta_y == (NV12_Y_ACTIVE_TILE_Y_COUNT - 1)) begin
                            exp_dec_meta_y     <= 10'd0;
                            exp_dec_meta_uv_y  <= 10'd0;
                            exp_dec_meta_is_uv <= 1'b1;
                            exp_dec_meta_phase <= DEC_META_PHASE_UV;
                            if (CASE_DEC_ROTATION == 270)
                                exp_dec_meta_x <= (exp_dec_meta_x == 12'd0) ?
                                                  (CASE_META_X_SAMPLES - 1) :
                                                  (exp_dec_meta_x - 1'b1);
                            else
                                exp_dec_meta_x <= (exp_dec_meta_x == (CASE_META_X_SAMPLES - 1)) ?
                                                  12'd0 : (exp_dec_meta_x + 1'b1);
                        end else begin
                            exp_dec_meta_y <= exp_dec_meta_y + 1'b1;
                        end
                    end
                end else begin
                    if (exp_dec_meta_x == (CASE_META_X_SAMPLES - 1)) begin
                        exp_dec_meta_x <= 12'd0;
                        if (!CASE_HAS_PLANE1) begin
                            exp_dec_meta_y <= exp_dec_meta_y + 1'b1;
                        end else if (exp_dec_meta_phase == DEC_META_PHASE_UV) begin
                            exp_dec_meta_uv_y  <= exp_dec_meta_uv_y + 1'b1;
                            exp_dec_meta_is_uv <= 1'b0;
                            exp_dec_meta_phase <= DEC_META_PHASE_YH;
                        end else if (exp_dec_meta_phase == DEC_META_PHASE_YH) begin
                            if ((exp_dec_meta_y + 1'b1) < CASE_TILE_Y_NUMBERS) begin
                                exp_dec_meta_phase <= DEC_META_PHASE_YL;
                            end else begin
                                exp_dec_meta_y     <= exp_dec_meta_y + 2'd2;
                                exp_dec_meta_is_uv <= 1'b1;
                                exp_dec_meta_phase <= DEC_META_PHASE_UV;
                            end
                        end else begin
                            exp_dec_meta_y     <= exp_dec_meta_y + 2'd2;
                            exp_dec_meta_is_uv <= 1'b1;
                            exp_dec_meta_phase <= DEC_META_PHASE_UV;
                        end
                    end else begin
                        exp_dec_meta_x <= exp_dec_meta_x + 1'b1;
                    end
                end
            end

            if (dut.tile_ci_valid_int && dut.tile_ci_ready_int) begin : vivo_ci_checker_block
                reg [7:0] vivo_ci_exp_raw;
                reg [3:0] vivo_ci_exp_metadata;
                reg [2:0] vivo_ci_exp_alen;
                vivo_ci_exp_raw      = expected_dec_meta_raw(dut.tile_ci_format_int,
                                                             dut.tile_x_coord_int,
                                                             dut.tile_y_coord_int);
                vivo_ci_exp_metadata = expected_dec_meta_flag_by_coord(dut.tile_ci_format_int,
                                                                       vivo_ci_exp_raw,
                                                                       dut.tile_x_coord_int,
                                                                       dut.tile_y_coord_int);
                vivo_ci_exp_alen     = expected_dec_meta_alen_by_coord(dut.tile_ci_format_int,
                                                                       vivo_ci_exp_raw,
                                                                       dut.tile_x_coord_int,
                                                                       dut.tile_y_coord_int);
                ci_accept_cnt        <= ci_accept_cnt + 1;
                ci_fmt_queue[ci_queue_wr_ptr] <= dut.tile_ci_format_int;
                ci_x_queue[ci_queue_wr_ptr]   <= dut.tile_x_coord_int;
                ci_y_queue[ci_queue_wr_ptr]   <= dut.tile_y_coord_int;
                ci_input_type_queue[ci_queue_wr_ptr] <= dut.tile_ci_input_type_int;
                ci_alen_queue[ci_queue_wr_ptr]       <= dut.tile_ci_alen_int;
                ci_metadata_queue[ci_queue_wr_ptr]   <= dut.tile_ci_metadata_int;
                ci_lossy_queue[ci_queue_wr_ptr]      <= dut.tile_ci_lossy_int;
                ci_alpha_mode_queue[ci_queue_wr_ptr] <= dut.tile_ci_alpha_mode_int;
                ci_sb_queue[ci_queue_wr_ptr]         <= {{(SB_WIDTH-1){1'b0}},
                                                         dut.tile_fcnt_int[0]};
                ci_queue_wr_ptr               <= ci_queue_wr_ptr + 1;
                expected_rvo_beats_total      <= expected_rvo_beats_total + CASE_FULL_TILE_BEATS;
                if (TB_REAL_VIVO_MODE == 0) begin
                    fake_ci_fifo_wr_cnt <= fake_ci_fifo_wr_cnt + 1;
                end
                write_vivo_ci_dump(dut.tile_ci_format_int,
                                   dut.tile_x_coord_int,
                                   dut.tile_y_coord_int,
                                   dut.tile_ci_input_type_int,
                                   dut.tile_ci_alen_int,
                                   dut.tile_ci_metadata_int,
                                   dut.tile_ci_lossy_int,
                                   dut.tile_ci_alpha_mode_int,
                                   {{(SB_WIDTH-1){1'b0}}, dut.tile_fcnt_int[0]});
                write_fc_sc_event("VIVO_CI", ci_accept_cnt,
                                  vivo_ci_exp_raw,
                                  dut.tile_ci_format_int,
                                  dut.tile_ci_metadata_int,
                                  dut.tile_ci_alen_int,
                                  dut.tile_ci_alpha_mode_int,
                                  dut.tile_x_coord_int,
                                  dut.tile_y_coord_int);
                if ((dut.tile_ci_metadata_int !== vivo_ci_exp_metadata) ||
                    (dut.tile_ci_alen_int !== vivo_ci_exp_alen)) begin
                    vivo_ci_mismatch_cnt <= vivo_ci_mismatch_cnt + 1;
                    if (vivo_ci_mismatch_cnt == 0) begin
                        first_vivo_ci_mismatch_fmt      <= dut.tile_ci_format_int;
                        first_vivo_ci_mismatch_x        <= dut.tile_x_coord_int;
                        first_vivo_ci_mismatch_y        <= dut.tile_y_coord_int;
                        first_vivo_ci_expected_raw      <= vivo_ci_exp_raw;
                        first_vivo_ci_expected_metadata <= vivo_ci_exp_metadata;
                        first_vivo_ci_actual_metadata   <= dut.tile_ci_metadata_int;
                        first_vivo_ci_expected_alen     <= vivo_ci_exp_alen;
                        first_vivo_ci_actual_alen       <= dut.tile_ci_alen_int;
                    end
                end
                last_progress_cycle  <= cycle_cnt;
            end

            if (dut.tile_cvi_valid_int && dut.tile_cvi_ready_int) begin : vivo_cvi_checker_block
                compressed_tile_hs_cnt <= compressed_tile_hs_cnt + 1;
                if (compressed_tile_in_fd != 0) begin
                    $fwrite(compressed_tile_in_fd, "%064h\n", dut.tile_cvi_data_int);
                    if (dut.tile_cvi_last_int) begin
                        $fwrite(compressed_tile_in_fd, "\n");
                    end
                end
                if (dut.tile_cvi_last_int) begin
                    compressed_tile_last_cnt <= compressed_tile_last_cnt + 1;
                end
                last_progress_cycle <= cycle_cnt;
            end

            if (dut.vivo_co_valid) begin
                co_active_cycle_cnt <= co_active_cycle_cnt + 1;
            end

            if (dut.u_tile_to_otf.writer_vld) begin
                writer_vld_cnt <= writer_vld_cnt + 1;
            end
            if (dut.u_tile_to_otf.u_writer.tile_hdr_fire) begin
                writer_hdr_fire_cnt <= writer_hdr_fire_cnt + 1;
            end
            if (dut.u_tile_to_otf.u_writer.data_fifo_wr_en) begin
                writer_data_fire_cnt <= writer_data_fire_cnt + 1;
            end
            if (dut.u_tile_to_otf.u_writer.data_fifo_rd_en) begin
                writer_data_rd_cnt <= writer_data_rd_cnt + 1;
            end
            if (dut.u_tile_to_otf.fetcher_done) begin
                fetcher_done_cnt <= fetcher_done_cnt + 1;
            end
            if (dut.u_tile_to_otf.fifo_wr_en) begin
                fifo_wr_cnt <= fifo_wr_cnt + 1;
            end
            if ((dut.u_tile_to_otf.fifo_rd_en0 | dut.u_tile_to_otf.fifo_rd_en1)) begin
                fifo_rd_cnt <= fifo_rd_cnt + 1;
            end
            if (dut.u_tile_to_otf.u_otf_driver.need_data &&
                (dut.u_tile_to_otf.fifo_empty0 & dut.u_tile_to_otf.fifo_empty1)) begin
                otf_fifo_empty_need_cnt <= otf_fifo_empty_need_cnt + 1;
                if (first_otf_fifo_empty_need_beat < 0) begin
                    first_otf_fifo_empty_need_beat <= otf_beat_cnt;
                end
            end
            if (dut.otf_underflow_int) begin
                otf_underflow_cnt <= otf_underflow_cnt + 1;
            end
            if (u_fake_tile_to_otf.writer_vld) begin
                fake_writer_vld_cnt <= fake_writer_vld_cnt + 1;
            end
            if (u_fake_tile_to_otf.fetcher_done) begin
                fake_fetcher_done_cnt <= fake_fetcher_done_cnt + 1;
            end
            if (u_fake_tile_to_otf.fifo_wr_en) begin
                fake_fifo_wr_cnt <= fake_fifo_wr_cnt + 1;
            end
            if ((u_fake_tile_to_otf.fifo_rd_en0 | u_fake_tile_to_otf.fifo_rd_en1)) begin
                fake_fifo_rd_cnt <= fake_fifo_rd_cnt + 1;
            end
            if (inject_axis_tile_valid && inject_axis_tile_ready) begin
                fake_hdr_hs_cnt <= fake_hdr_hs_cnt + 1;
                if (inject_axis_tile_x == 16'd255) begin
                    fake_hdr_last_x_hs_cnt <= fake_hdr_last_x_hs_cnt + 1;
                end
                if (inject_axis_tile_x > fake_hdr_x_max_seen) begin
                    fake_hdr_x_max_seen <= inject_axis_tile_x;
                end
            end
            if (inject_axis_tvalid && inject_axis_tready) begin
                fake_data_hs_cnt <= fake_data_hs_cnt + 1;
            end
            if (fake_otf_sram_a_wen || fake_otf_sram_b_wen) begin
                fake_sram_wen_cnt <= fake_sram_wen_cnt + 1;
            end
            if (u_fake_tile_to_otf.u_writer.tile_last_write) begin
                fake_tile_last_write_cnt <= fake_tile_last_write_cnt + 1;
            end
            if (u_fake_tile_to_otf.u_writer.slice_done) begin
                fake_slice_done_cnt <= fake_slice_done_cnt + 1;
            end
            if (dut.meta_m_axi_rvalid && dut.meta_m_axi_rready) begin
                meta_rbeat_cnt <= meta_rbeat_cnt + 1;
            end
            if (dut.tile_m_axi_rvalid && dut.tile_m_axi_rready) begin
                tile_rbeat_cnt <= tile_rbeat_cnt + 1;
            end
            if (!dut.i_m_axi_rvalid) begin
                axi_r_cccc_seen_curr_beat <= 1'b0;
            end else begin
                if (has_cccc_lane(dut.i_m_axi_rdata) && !axi_r_cccc_seen_curr_beat) begin
                    axi_rdata_cccc_cnt <= axi_rdata_cccc_cnt + 1;
                    if ((!dut.core_m_axi_rid_r[AXI_IDW])) begin
                        axi_rdata_cccc_meta_cnt <= axi_rdata_cccc_meta_cnt + 1;
                    end else begin
                        axi_rdata_cccc_tile_cnt <= axi_rdata_cccc_tile_cnt + 1;
                    end
                    axi_r_cccc_seen_curr_beat <= 1'b1;
                    if (first_axi_rdata_cccc_cycle < 0) begin
                        first_axi_rdata_cccc_cycle   <= cycle_cnt;
                        first_axi_rdata_cccc_lane    <= first_cccc_lane_idx(dut.i_m_axi_rdata);
                        first_axi_rdata_cccc_addr    <= axi_rsp_addr + (axi_rsp_beat_idx * (M_AXI_DW / 8));
                        first_axi_rdata_cccc_is_meta <= (!dut.core_m_axi_rid_r[AXI_IDW]);
                        first_axi_rdata_cccc_data    <= dut.i_m_axi_rdata;
                        $display("WARN: suspicious AXI RDATA contains 64'hcccccccccccccccc while axi_rvalid=1 at cycle=%0d owner=%0s addr=%016h lane=%0d data=%064h",
                                 cycle_cnt,
                                 (!dut.core_m_axi_rid_r[AXI_IDW]) ? "meta" : "tile",
                                 axi_rsp_addr + (axi_rsp_beat_idx * (M_AXI_DW / 8)),
                                 first_cccc_lane_idx(dut.i_m_axi_rdata),
                                 dut.i_m_axi_rdata);
                    end
                end
                if (dut.o_m_axi_rready) begin
                    axi_r_cccc_seen_curr_beat <= 1'b0;
                end
            end

            if (dut.i_m_axi_rvalid && dut.o_m_axi_rready) begin
                m_rhandshake_cnt <= m_rhandshake_cnt + 1;
                if (!(dut.meta_m_axi_rvalid && dut.meta_m_axi_rready) &&
                    !(dut.tile_m_axi_rvalid && dut.tile_m_axi_rready)) begin
                    m_r_nosink_cnt <= m_r_nosink_cnt + 1;
                    if ((!dut.core_m_axi_rid_r[AXI_IDW])) begin
                        m_r_nosink_meta_cnt <= m_r_nosink_meta_cnt + 1;
                    end else begin
                        m_r_nosink_tile_cnt <= m_r_nosink_tile_cnt + 1;
                    end
                    if (first_m_r_nosink_cycle < 0) begin
                        first_m_r_nosink_cycle      <= cycle_cnt;
                        first_m_r_nosink_owner_s0   <= (!dut.core_m_axi_rid_r[AXI_IDW]);
                        first_m_r_nosink_rlast      <= dut.i_m_axi_rlast;
                        first_m_r_nosink_rbuf_valid <= 1'b0;
                        first_m_r_nosink_payload_left <= dut.u_tile_arcmd_gen.payload_beats_left_reg;
                        first_m_r_nosink_ar_left    <= dut.u_tile_arcmd_gen.ar_req_beats_left_reg;
                    end
                end
            end
            if (1'b0 &&
                dut.meta_m_axi_rvalid && dut.meta_m_axi_rready) begin
                rbuf_meta_drain_cnt <= rbuf_meta_drain_cnt + 1;
            end
            if (1'b0 &&
                dut.tile_m_axi_rvalid && dut.tile_m_axi_rready) begin
                rbuf_tile_drain_cnt <= rbuf_tile_drain_cnt + 1;
            end

            if (dut.tile_m_axi_rvalid && dut.tile_m_axi_rready &&
                !(dut.otf_axis_tvalid && dut.otf_axis_tready_int)) begin
                tile_rbeat_no_rvo_cnt <= tile_rbeat_no_rvo_cnt + 1;
            end

            if (dut.otf_axis_tvalid && dut.otf_axis_tready_int) begin
                rvo_beat_cnt       <= rvo_beat_cnt + 1;
                last_progress_cycle<= cycle_cnt;
                if (cmp_tile_rd_ptr >= ci_queue_wr_ptr) begin
                    rvo_data_mismatch_cnt <= rvo_data_mismatch_cnt + 1;
                    if (rvo_data_mismatch_cnt == 0) begin
                        first_rvo_mismatch_fmt  <= 5'd0;
                        first_rvo_mismatch_x    <= 12'd0;
                        first_rvo_mismatch_y    <= 10'd0;
                        first_rvo_mismatch_beat <= cmp_tile_beat_idx;
                        first_rvo_expected_data <= {AXI_DW{1'b0}};
                        first_rvo_actual_data   <= dut.otf_axis_tdata;
                        first_rvo_expected_alen <= 3'd7;
                        first_rvo_actual_last   <= dut.otf_axis_tlast;
                    end
                end else begin
                    if (is_active_rvo_tile(ci_fmt_queue[cmp_tile_rd_ptr],
                                           ci_x_queue[cmp_tile_rd_ptr],
                                           ci_y_queue[cmp_tile_rd_ptr]) &&
                        (dut.otf_axis_tdata !== pack_ref_tile_axi_word(ci_fmt_queue[cmp_tile_rd_ptr],
                                                                       ci_x_queue[cmp_tile_rd_ptr],
                                                                       ci_y_queue[cmp_tile_rd_ptr],
                                                                       cmp_tile_beat_idx))) begin
                        rvo_data_mismatch_cnt <= rvo_data_mismatch_cnt + 1;
                        if (rvo_data_mismatch_cnt == 0) begin
                            first_rvo_mismatch_fmt  <= ci_fmt_queue[cmp_tile_rd_ptr];
                            first_rvo_mismatch_x    <= ci_x_queue[cmp_tile_rd_ptr];
                            first_rvo_mismatch_y    <= ci_y_queue[cmp_tile_rd_ptr];
                            first_rvo_mismatch_beat <= cmp_tile_beat_idx;
                            first_rvo_expected_data <= pack_ref_tile_axi_word(ci_fmt_queue[cmp_tile_rd_ptr],
                                                                               ci_x_queue[cmp_tile_rd_ptr],
                                                                               ci_y_queue[cmp_tile_rd_ptr],
                                                                               cmp_tile_beat_idx);
                            first_rvo_actual_data   <= dut.otf_axis_tdata;
                            first_rvo_expected_alen <= 3'd7;
                            first_rvo_actual_last   <= dut.otf_axis_tlast;
                        end
                    end
                    if (is_active_rvo_tile(ci_fmt_queue[cmp_tile_rd_ptr],
                                           ci_x_queue[cmp_tile_rd_ptr],
                                           ci_y_queue[cmp_tile_rd_ptr]) &&
                        (dut.otf_axis_tlast !== (cmp_tile_beat_idx == (CASE_FULL_TILE_BEATS - 1)))) begin
                        rvo_last_mismatch_cnt <= rvo_last_mismatch_cnt + 1;
                        if ((rvo_data_mismatch_cnt == 0) && (rvo_last_mismatch_cnt == 0)) begin
                            first_rvo_mismatch_fmt  <= ci_fmt_queue[cmp_tile_rd_ptr];
                            first_rvo_mismatch_x    <= ci_x_queue[cmp_tile_rd_ptr];
                            first_rvo_mismatch_y    <= ci_y_queue[cmp_tile_rd_ptr];
                            first_rvo_mismatch_beat <= cmp_tile_beat_idx;
                            first_rvo_expected_data <= pack_ref_tile_axi_word(ci_fmt_queue[cmp_tile_rd_ptr],
                                                                               ci_x_queue[cmp_tile_rd_ptr],
                                                                               ci_y_queue[cmp_tile_rd_ptr],
                                                                               cmp_tile_beat_idx);
                            first_rvo_actual_data   <= dut.otf_axis_tdata;
                            first_rvo_expected_alen <= 3'd7;
                            first_rvo_actual_last   <= dut.otf_axis_tlast;
                        end
                    end
                    if (dut.otf_axis_tlast) begin
                        rvo_last_cnt <= rvo_last_cnt + 1;
                        if (TB_REAL_VIVO_MODE == 0) begin
                            fake_ci_fifo_rd_cnt <= fake_ci_fifo_rd_cnt + 1;
                        end
                    end

                    if (stream_fd != 0) begin
                        $fwrite(stream_fd, "%0d %0d %0d %0d %064h\n",
                                ci_fmt_queue[cmp_tile_rd_ptr], ci_x_queue[cmp_tile_rd_ptr], ci_y_queue[cmp_tile_rd_ptr],
                                cmp_tile_beat_idx, dut.otf_axis_tdata);
                    end
                    write_vivo_rvo_dump(ci_fmt_queue[cmp_tile_rd_ptr],
                                        ci_x_queue[cmp_tile_rd_ptr],
                                        ci_y_queue[cmp_tile_rd_ptr],
                                        cmp_tile_beat_idx,
                                        dut.otf_axis_tlast,
                                        dut.otf_axis_tdata);
                    capture_rvo_beat_to_plane_mem(ci_fmt_queue[cmp_tile_rd_ptr],
                                                  ci_x_queue[cmp_tile_rd_ptr],
                                                  ci_y_queue[cmp_tile_rd_ptr],
                                                  cmp_tile_beat_idx,
                                                  dut.otf_axis_tdata);
                    if (expected_stream_fd != 0) begin
                        $fwrite(expected_stream_fd, "%0d %0d %0d %0d %064h\n",
                                ci_fmt_queue[cmp_tile_rd_ptr], ci_x_queue[cmp_tile_rd_ptr], ci_y_queue[cmp_tile_rd_ptr],
                                cmp_tile_beat_idx,
                                pack_ref_tile_axi_word(ci_fmt_queue[cmp_tile_rd_ptr],
                                                       ci_x_queue[cmp_tile_rd_ptr],
                                                       ci_y_queue[cmp_tile_rd_ptr],
                                                       cmp_tile_beat_idx));
                    end

                    if (cmp_tile_beat_idx == (CASE_FULL_TILE_BEATS - 1)) begin
                        cmp_tile_rd_ptr   <= cmp_tile_rd_ptr + 1;
                        cmp_tile_beat_idx <= 0;
                    end else begin
                        cmp_tile_beat_idx <= cmp_tile_beat_idx + 1;
                    end
                end
            end

        end
    end

    always @(posedge i_vivo_clk or negedge i_vivo_rstn) begin
        if (!i_vivo_rstn) begin
            vivo_if_ci_wr_ptr              <= 0;
            vivo_if_cvi_rd_ptr             <= 0;
            vivo_if_rvo_rd_ptr             <= 0;
            vivo_if_cvi_beat_idx           <= 0;
            vivo_if_rvo_beat_idx           <= 0;
            vivo_if_ci_accept_cnt          <= 0;
            vivo_if_cvi_beat_cnt           <= 0;
            vivo_if_cvi_last_cnt           <= 0;
            vivo_if_rvo_beat_cnt           <= 0;
            vivo_if_rvo_last_cnt           <= 0;
            vivo_if_ci_mismatch_cnt        <= 0;
            vivo_if_cvi_underflow_cnt      <= 0;
            vivo_if_cvi_data_mismatch_cnt  <= 0;
            vivo_if_cvi_last_mismatch_cnt  <= 0;
            vivo_if_rvo_underflow_cnt      <= 0;
            vivo_if_rvo_data_mismatch_cnt  <= 0;
            vivo_if_rvo_last_mismatch_cnt  <= 0;
        end else begin
            if (dut.vivo_ci_valid_int && dut.vivo_ci_ready_raw) begin : vivo_if_ci_checker_block
                reg [7:0] vivo_if_ci_exp_raw;
                reg [3:0] vivo_if_ci_exp_metadata;
                reg [2:0] vivo_if_ci_exp_alen;

                vivo_if_ci_exp_raw      = expected_dec_meta_raw(dut.vivo_ci_format_int,
                                                                 dut.vivo_ci_x_coord_int,
                                                                 dut.vivo_ci_y_coord_int);
                vivo_if_ci_exp_metadata = expected_dec_meta_flag_by_coord(dut.vivo_ci_format_int,
                                                                          vivo_if_ci_exp_raw,
                                                                          dut.vivo_ci_x_coord_int,
                                                                          dut.vivo_ci_y_coord_int);
                vivo_if_ci_exp_alen     = expected_dec_meta_alen_by_coord(dut.vivo_ci_format_int,
                                                                          vivo_if_ci_exp_raw,
                                                                          dut.vivo_ci_x_coord_int,
                                                                          dut.vivo_ci_y_coord_int);

                vivo_if_fmt_queue[vivo_if_ci_wr_ptr]  <= dut.vivo_ci_format_int;
                vivo_if_x_queue[vivo_if_ci_wr_ptr]    <= dut.vivo_ci_x_coord_int;
                vivo_if_y_queue[vivo_if_ci_wr_ptr]    <= dut.vivo_ci_y_coord_int;
                vivo_if_alen_queue[vivo_if_ci_wr_ptr] <= dut.vivo_ci_alen_int;
                vivo_if_ci_wr_ptr                     <= vivo_if_ci_wr_ptr + 1;
                vivo_if_ci_accept_cnt                 <= vivo_if_ci_accept_cnt + 1;

                if ((dut.vivo_ci_metadata_int !== vivo_if_ci_exp_metadata) ||
                    (dut.vivo_ci_alen_int !== vivo_if_ci_exp_alen)) begin
                    vivo_if_ci_mismatch_cnt <= vivo_if_ci_mismatch_cnt + 1;
                    if (vivo_if_ci_mismatch_cnt == 0) begin
                        $display("[TB][FIRST_MISMATCH] time=%0t checker=DEC_VIVO_IF_CI scope=u_core.dut.u_dec_vivo_top.i_ci_*",
                                 $time);
                        $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d raw=0x%02x",
                                 dut.vivo_ci_format_int,
                                 dut.vivo_ci_x_coord_int,
                                 dut.vivo_ci_y_coord_int,
                                 vivo_if_ci_exp_raw);
                        $display("[TB][FIRST_MISMATCH]   metadata exp=0x%01x act=0x%01x alen exp=%0d act=%0d",
                                 vivo_if_ci_exp_metadata,
                                 dut.vivo_ci_metadata_int,
                                 vivo_if_ci_exp_alen,
                                 dut.vivo_ci_alen_int);
                    end
                end
            end

            if (dut.vivo_cvi_valid_int && dut.vivo_cvi_ready_int) begin : vivo_if_cvi_checker_block
                reg [AXI_AW-1:0] vivo_if_cvi_exp_addr;
                reg [AXI_DW-1:0] vivo_if_cvi_exp_data;
                reg              vivo_if_cvi_exp_last;
                reg [4:0]        vivo_if_cvi_exp_fmt;
                reg [11:0]       vivo_if_cvi_exp_x;
                reg [9:0]        vivo_if_cvi_exp_y;
                reg [2:0]        vivo_if_cvi_exp_alen;
                integer          vivo_if_cvi_exp_last_beat;

                vivo_if_cvi_beat_cnt <= vivo_if_cvi_beat_cnt + 1;
                if (vivo_if_cvi_rd_ptr >= tile_queue_wr_ptr) begin
                    vivo_if_cvi_underflow_cnt     <= vivo_if_cvi_underflow_cnt + 1;
                    vivo_if_cvi_data_mismatch_cnt <= vivo_if_cvi_data_mismatch_cnt + 1;
                    if (vivo_if_cvi_underflow_cnt == 0) begin
                        $display("[TB][FIRST_MISMATCH] time=%0t checker=DEC_VIVO_IF_CVI_UNDERFLOW scope=u_core.dut.u_dec_vivo_top.i_cvi_*",
                                 $time);
                        $display("[TB][FIRST_MISMATCH]   cvi data arrived with no accepted CI command, data=0x%064x last=%0b",
                                 dut.vivo_cvi_data_int,
                                 dut.vivo_cvi_last_int);
                    end
                end else begin
                    vivo_if_cvi_exp_fmt  = tile_fmt_queue[vivo_if_cvi_rd_ptr];
                    vivo_if_cvi_exp_x    = tile_x_queue[vivo_if_cvi_rd_ptr];
                    vivo_if_cvi_exp_y    = tile_y_queue[vivo_if_cvi_rd_ptr];
                    vivo_if_cvi_exp_alen = tile_alen_queue[vivo_if_cvi_rd_ptr];
                    vivo_if_cvi_exp_addr = expected_tile_addr(vivo_if_cvi_exp_fmt,
                                                              vivo_if_cvi_exp_x,
                                                              vivo_if_cvi_exp_y,
                                                              vivo_if_cvi_exp_alen);
                    vivo_if_cvi_exp_data = (CASE_TILE_EXPECT_LINEAR != 0) ?
                                           pack_tile_vivo_word(vivo_if_cvi_exp_fmt,
                                                               vivo_if_cvi_exp_x,
                                                               vivo_if_cvi_exp_y,
                                                               vivo_if_cvi_beat_idx) :
                                           pack_raw_tile_vivo_word(vivo_if_cvi_exp_fmt,
                                                                   vivo_if_cvi_exp_addr,
                                                                   vivo_if_cvi_beat_idx);
                    vivo_if_cvi_exp_last_beat = vivo_if_cvi_exp_alen;
                    vivo_if_cvi_exp_last      = (vivo_if_cvi_beat_idx == vivo_if_cvi_exp_last_beat);

                    write_vivo_cvi_dump(vivo_if_cvi_exp_fmt,
                                        vivo_if_cvi_exp_x,
                                        vivo_if_cvi_exp_y,
                                        vivo_if_cvi_beat_idx,
                                        dut.vivo_cvi_last_int,
                                        dut.vivo_cvi_data_int);

                    if (dut.vivo_cvi_data_int !== vivo_if_cvi_exp_data) begin
                        vivo_if_cvi_data_mismatch_cnt <= vivo_if_cvi_data_mismatch_cnt + 1;
                        if (vivo_if_cvi_data_mismatch_cnt == 0) begin
                            $display("[TB][FIRST_MISMATCH] time=%0t checker=DEC_VIVO_IF_CVI_DATA scope=u_core.dut.u_dec_vivo_top.i_cvi_*",
                                     $time);
                            $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d addr=0x%016x beat=%0d",
                                     vivo_if_cvi_exp_fmt,
                                     vivo_if_cvi_exp_x,
                                     vivo_if_cvi_exp_y,
                                     vivo_if_cvi_exp_addr,
                                     vivo_if_cvi_beat_idx);
                            $display("[TB][FIRST_MISMATCH]   expected=0x%064x",
                                     vivo_if_cvi_exp_data);
                            $display("[TB][FIRST_MISMATCH]   actual  =0x%064x",
                                     dut.vivo_cvi_data_int);
                        end
                    end

                    if (dut.vivo_cvi_last_int !== vivo_if_cvi_exp_last) begin
                        vivo_if_cvi_last_mismatch_cnt <= vivo_if_cvi_last_mismatch_cnt + 1;
                        if (vivo_if_cvi_last_mismatch_cnt == 0) begin
                            $display("[TB][FIRST_MISMATCH] time=%0t checker=DEC_VIVO_IF_CVI_LAST scope=u_core.dut.u_dec_vivo_top.i_cvi_last",
                                     $time);
                            $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d beat=%0d last exp=%0b act=%0b",
                                     vivo_if_cvi_exp_fmt,
                                     vivo_if_cvi_exp_x,
                                     vivo_if_cvi_exp_y,
                                     vivo_if_cvi_beat_idx,
                                     vivo_if_cvi_exp_last,
                                     dut.vivo_cvi_last_int);
                        end
                    end

                    if (dut.vivo_cvi_last_int) begin
                        vivo_if_cvi_last_cnt <= vivo_if_cvi_last_cnt + 1;
                        vivo_if_cvi_rd_ptr   <= vivo_if_cvi_rd_ptr + 1;
                        vivo_if_cvi_beat_idx <= 0;
                    end else begin
                        vivo_if_cvi_beat_idx <= vivo_if_cvi_beat_idx + 1;
                    end
                end
            end

            if (dut.vivo_rvo_valid && dut.vivo_rvo_ready) begin : vivo_if_rvo_checker_block
                reg [AXI_DW-1:0] vivo_if_rvo_exp_data;
                reg              vivo_if_rvo_exp_last;

                vivo_if_rvo_beat_cnt <= vivo_if_rvo_beat_cnt + 1;
                if (vivo_if_rvo_rd_ptr >= vivo_if_ci_wr_ptr) begin
                    vivo_if_rvo_underflow_cnt     <= vivo_if_rvo_underflow_cnt + 1;
                    vivo_if_rvo_data_mismatch_cnt <= vivo_if_rvo_data_mismatch_cnt + 1;
                    if (vivo_if_rvo_underflow_cnt == 0) begin
                        $display("[TB][FIRST_MISMATCH] time=%0t checker=DEC_VIVO_IF_RVO_UNDERFLOW scope=u_core.dut.u_dec_vivo_top.o_rvo_*",
                                 $time);
                        $display("[TB][FIRST_MISMATCH]   rvo data arrived with no accepted CI command, data=0x%064x last=%0b",
                                 dut.vivo_rvo_data,
                                 dut.vivo_rvo_last);
                    end
                end else begin
                    vivo_if_rvo_exp_data = pack_ref_tile_axi_word(vivo_if_fmt_queue[vivo_if_rvo_rd_ptr],
                                                                  vivo_if_x_queue[vivo_if_rvo_rd_ptr],
                                                                  vivo_if_y_queue[vivo_if_rvo_rd_ptr],
                                                                  vivo_if_rvo_beat_idx);
                    vivo_if_rvo_exp_last = (vivo_if_rvo_beat_idx == (CASE_FULL_TILE_BEATS - 1));

                    if (is_active_rvo_tile(vivo_if_fmt_queue[vivo_if_rvo_rd_ptr],
                                           vivo_if_x_queue[vivo_if_rvo_rd_ptr],
                                           vivo_if_y_queue[vivo_if_rvo_rd_ptr]) &&
                        (dut.vivo_rvo_data !== vivo_if_rvo_exp_data)) begin
                        vivo_if_rvo_data_mismatch_cnt <= vivo_if_rvo_data_mismatch_cnt + 1;
                        if (vivo_if_rvo_data_mismatch_cnt == 0) begin
                            $display("[TB][FIRST_MISMATCH] time=%0t checker=DEC_VIVO_IF_RVO_DATA scope=u_core.dut.u_dec_vivo_top.o_rvo_*",
                                     $time);
                            $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d beat=%0d",
                                     vivo_if_fmt_queue[vivo_if_rvo_rd_ptr],
                                     vivo_if_x_queue[vivo_if_rvo_rd_ptr],
                                     vivo_if_y_queue[vivo_if_rvo_rd_ptr],
                                     vivo_if_rvo_beat_idx);
                            $display("[TB][FIRST_MISMATCH]   expected=0x%064x",
                                     vivo_if_rvo_exp_data);
                            $display("[TB][FIRST_MISMATCH]   actual  =0x%064x",
                                     dut.vivo_rvo_data);
                        end
                    end

                    if (is_active_rvo_tile(vivo_if_fmt_queue[vivo_if_rvo_rd_ptr],
                                           vivo_if_x_queue[vivo_if_rvo_rd_ptr],
                                           vivo_if_y_queue[vivo_if_rvo_rd_ptr]) &&
                        (dut.vivo_rvo_last !== vivo_if_rvo_exp_last)) begin
                        vivo_if_rvo_last_mismatch_cnt <= vivo_if_rvo_last_mismatch_cnt + 1;
                        if (vivo_if_rvo_last_mismatch_cnt == 0) begin
                            $display("[TB][FIRST_MISMATCH] time=%0t checker=DEC_VIVO_IF_RVO_LAST scope=u_core.dut.u_dec_vivo_top.o_rvo_last",
                                     $time);
                            $display("[TB][FIRST_MISMATCH]   fmt=%0d x=%0d y=%0d beat=%0d last exp=%0b act=%0b",
                                     vivo_if_fmt_queue[vivo_if_rvo_rd_ptr],
                                     vivo_if_x_queue[vivo_if_rvo_rd_ptr],
                                     vivo_if_y_queue[vivo_if_rvo_rd_ptr],
                                     vivo_if_rvo_beat_idx,
                                     vivo_if_rvo_exp_last,
                                     dut.vivo_rvo_last);
                        end
                    end

                    if (dut.vivo_rvo_last) begin
                        vivo_if_rvo_last_cnt <= vivo_if_rvo_last_cnt + 1;
                        vivo_if_rvo_rd_ptr   <= vivo_if_rvo_rd_ptr + 1;
                        vivo_if_rvo_beat_idx <= 0;
                    end else begin
                        vivo_if_rvo_beat_idx <= vivo_if_rvo_beat_idx + 1;
                    end
                end
            end
        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            i_m_axi_arready        <= 1'b1;
            i_m_axi_rid            <= {(AXI_IDW+1){1'b0}};
            i_m_axi_rvalid         <= 1'b0;
            i_m_axi_rdata          <= {M_AXI_DW{1'b0}};
            i_m_axi_rresp          <= 2'b00;
            i_m_axi_rlast          <= 1'b0;
            axi_rsp_active         <= 1'b0;
            axi_rsp_is_meta        <= 1'b0;
            axi_rsp_meta_plane1    <= 1'b0;
            axi_rsp_addr           <= {AXI_AW{1'b0}};
            axi_rsp_id             <= {(AXI_IDW+1){1'b0}};
            axi_rsp_beats_left     <= 8'd0;
            axi_rsp_beat_idx       <= 8'd0;
            axi_rsp_tile_fmt       <= 5'd0;
            axi_rsp_tile_x         <= 12'd0;
            axi_rsp_tile_y         <= 10'd0;
            axi_rsp_wait_cycles    <= 0;
            tile_queue_rd_ptr      <= 0;
            meta_ar_cnt            <= 0;
            meta_ar_plane0_cnt     <= 0;
            meta_ar_plane1_cnt     <= 0;
            tile_ar_cnt            <= 0;
            axi_rbeat_cnt          <= 0;
            meta_rbeat_cnt         <= 0;
            tile_rbeat_cnt         <= 0;
            ar_addr_mismatch_cnt   <= 0;
            ar_len_mismatch_cnt    <= 0;
            tile_queue_underflow_cnt <= 0;
            last_progress_cycle    <= 0;
            axi_rand_state         <= (tb_axi_seed == 0) ? 32'h5eed_0d1a : tb_axi_seed[31:0];
        end else begin
            if (tb_axi_random_en != 0)
                axi_rand_state <= lfsr_next(lfsr_next(axi_rand_state));
            else
                axi_rand_state <= (tb_axi_seed == 0) ? 32'h5eed_0d1a : tb_axi_seed[31:0];

            if (!axi_rsp_active) begin
                i_m_axi_rvalid <= 1'b0;
                i_m_axi_rlast  <= 1'b0;
                axi_rsp_wait_cycles <= 0;
                i_m_axi_arready <= ready_from_stall_pct(axi_rand_state, tb_axi_ar_stall_pct);
                if (o_m_axi_arvalid && i_m_axi_arready) begin
                    i_m_axi_arready <= 1'b0;
                    if (((o_m_axi_araddr >= CASE_META_BASE_ADDR_Y) &&
                         (o_m_axi_araddr < (CASE_META_BASE_ADDR_Y + (CASE_META0_WORDS64 * 8)))) ||
                        (CASE_HAS_PLANE1 &&
                         (o_m_axi_araddr >= CASE_META_BASE_ADDR_UV) &&
                         (o_m_axi_araddr < (CASE_META_BASE_ADDR_UV + (CASE_META1_WORDS64 * 8))))) begin
                        axi_rsp_active      <= 1'b1;
                        axi_rsp_is_meta     <= 1'b1;
                        axi_rsp_meta_plane1 <= CASE_HAS_PLANE1 &&
                                               (o_m_axi_araddr >= CASE_META_BASE_ADDR_UV) &&
                                               (o_m_axi_araddr < (CASE_META_BASE_ADDR_UV + (CASE_META1_WORDS64 * 8)));
                        axi_rsp_addr        <= o_m_axi_araddr;
                        axi_rsp_id          <= o_m_axi_arid;
                        axi_rsp_beats_left  <= o_m_axi_arlen + 1'b1;
                        axi_rsp_beat_idx    <= 8'd0;
                        axi_rsp_wait_cycles <= tb_axi_read_delay_cycles;
                        meta_ar_cnt         <= meta_ar_cnt + 1;
                        if (CASE_HAS_PLANE1 &&
                            (o_m_axi_araddr >= CASE_META_BASE_ADDR_UV) &&
                            (o_m_axi_araddr < (CASE_META_BASE_ADDR_UV + (CASE_META1_WORDS64 * 8)))) begin
                            meta_ar_plane1_cnt <= meta_ar_plane1_cnt + 1;
                        end else begin
                            meta_ar_plane0_cnt <= meta_ar_plane0_cnt + 1;
                        end
                        last_progress_cycle <= cycle_cnt;
                    end else begin
                        if (tile_queue_rd_ptr >= tile_queue_wr_ptr) begin
                            tile_queue_underflow_cnt <= tile_queue_underflow_cnt + 1;
                        end else begin
                            axi_rsp_active     <= 1'b1;
                            axi_rsp_is_meta    <= 1'b0;
                            axi_rsp_addr       <= o_m_axi_araddr;
                            axi_rsp_id         <= o_m_axi_arid;
                            axi_rsp_beats_left <= ((tile_alen_queue[tile_queue_rd_ptr] + 1) * (AXI_DW / M_AXI_DW));
                            axi_rsp_beat_idx   <= 8'd0;
                            axi_rsp_wait_cycles<= tb_axi_read_delay_cycles;
                            axi_rsp_tile_fmt   <= tile_fmt_queue[tile_queue_rd_ptr];
                            axi_rsp_tile_x     <= tile_x_queue[tile_queue_rd_ptr];
                            axi_rsp_tile_y     <= tile_y_queue[tile_queue_rd_ptr];
                            if (is_active_rvo_tile(tile_fmt_queue[tile_queue_rd_ptr],
                                                   tile_x_queue[tile_queue_rd_ptr],
                                                   tile_y_queue[tile_queue_rd_ptr]) &&
                                (o_m_axi_araddr !== tile_addr_queue[tile_queue_rd_ptr])) begin
                                ar_addr_mismatch_cnt <= ar_addr_mismatch_cnt + 1;
                                if (ar_addr_mismatch_cnt == 0) begin
                                    first_ar_mismatch_fmt  <= tile_fmt_queue[tile_queue_rd_ptr];
                                    first_ar_mismatch_x    <= tile_x_queue[tile_queue_rd_ptr];
                                    first_ar_mismatch_y    <= tile_y_queue[tile_queue_rd_ptr];
                                    first_ar_expected_addr <= tile_addr_queue[tile_queue_rd_ptr];
                                    first_ar_actual_addr   <= o_m_axi_araddr;
                                end
                            end
                            if (is_active_rvo_tile(tile_fmt_queue[tile_queue_rd_ptr],
                                                   tile_x_queue[tile_queue_rd_ptr],
                                                   tile_y_queue[tile_queue_rd_ptr]) &&
                                (o_m_axi_arlen !== (((tile_alen_queue[tile_queue_rd_ptr] + 1) * (AXI_DW / M_AXI_DW)) - 1))) begin
                                ar_len_mismatch_cnt <= ar_len_mismatch_cnt + 1;
                            end
                            tile_queue_rd_ptr  <= tile_queue_rd_ptr + 1;
                            tile_ar_cnt        <= tile_ar_cnt + 1;
                            last_progress_cycle<= cycle_cnt;
                        end
                    end
                end
            end else if (!i_m_axi_rvalid) begin
                i_m_axi_arready <= 1'b0;
                if (axi_rsp_wait_cycles > 0) begin
                    axi_rsp_wait_cycles <= axi_rsp_wait_cycles - 1;
                    i_m_axi_rvalid <= 1'b0;
                    i_m_axi_rlast  <= 1'b0;
                end else if (!ready_from_stall_pct(lfsr_next(axi_rand_state), tb_axi_rvalid_stall_pct)) begin
                    i_m_axi_rvalid <= 1'b0;
                    i_m_axi_rlast  <= 1'b0;
                end else begin
                    i_m_axi_rvalid <= 1'b1;
                    i_m_axi_rid    <= axi_rsp_id;
                    i_m_axi_rresp  <= 2'b00;
                    i_m_axi_rlast  <= (axi_rsp_beats_left == 8'd1);
                    if (axi_rsp_is_meta) begin
                        i_m_axi_rdata <= pack_meta_axi_word(axi_rsp_meta_plane1, axi_rsp_addr, axi_rsp_beat_idx);
                    end else if (CASE_TILE_EXPECT_LINEAR != 0) begin
                        i_m_axi_rdata <= pack_tile_axi_word(axi_rsp_tile_fmt, axi_rsp_tile_x, axi_rsp_tile_y,
                                                            axi_rsp_beat_idx);
                    end else begin
                        i_m_axi_rdata <= pack_raw_tile_axi_word(axi_rsp_tile_fmt, axi_rsp_addr, axi_rsp_beat_idx);
                        dbg_axi_word64_base = (((axi_rsp_addr -
                                                (((axi_rsp_tile_fmt == META_FMT_NV12_UV) ||
                                                  (axi_rsp_tile_fmt == META_FMT_P010_UV)) ?
                                                 CASE_TILE_BASE_ADDR_UV : CASE_TILE_BASE_ADDR_Y)) >> 3) +
                                               (axi_rsp_beat_idx * (M_AXI_DW / 64)));
                        if ((tb_debug_word64_index >= dbg_axi_word64_base) &&
                            (tb_debug_word64_index < (dbg_axi_word64_base + (M_AXI_DW / 64)))) begin
                            $display("[TB][DBG_AXI_TILE] time=%0t addr=0x%016h base_idx=%0d target_idx=%0d beat=%0d lane=%0d data=0x%064h",
                                     $time,
                                     axi_rsp_addr,
                                     dbg_axi_word64_base,
                                     tb_debug_word64_index,
                                     axi_rsp_beat_idx,
                                     tb_debug_word64_index - dbg_axi_word64_base,
                                     pack_raw_tile_axi_word(axi_rsp_tile_fmt, axi_rsp_addr, axi_rsp_beat_idx));
                        end
                    end
                end
            end else if (o_m_axi_rready) begin
                axi_rbeat_cnt       <= axi_rbeat_cnt + 1;
                last_progress_cycle <= cycle_cnt;
                if (axi_rsp_beats_left == 8'd1) begin
                    i_m_axi_arready   <= 1'b1;
                    i_m_axi_rvalid     <= 1'b0;
                    i_m_axi_rlast      <= 1'b0;
                    axi_rsp_active     <= 1'b0;
                    axi_rsp_beats_left <= 8'd0;
                    axi_rsp_beat_idx   <= 8'd0;
                    axi_rsp_wait_cycles<= 0;
                end else begin
                    axi_rsp_beats_left <= axi_rsp_beats_left - 1'b1;
                    axi_rsp_beat_idx   <= axi_rsp_beat_idx + 1'b1;
                    i_m_axi_rvalid     <= 1'b1;
                    i_m_axi_rid        <= axi_rsp_id;
                    i_m_axi_rresp      <= 2'b00;
                    i_m_axi_rlast      <= (axi_rsp_beats_left == 8'd2);
                    if (axi_rsp_is_meta) begin
                        i_m_axi_rdata <= pack_meta_axi_word(axi_rsp_meta_plane1, axi_rsp_addr, axi_rsp_beat_idx + 1'b1);
                    end else if (CASE_TILE_EXPECT_LINEAR != 0) begin
                        i_m_axi_rdata <= pack_tile_axi_word(axi_rsp_tile_fmt, axi_rsp_tile_x, axi_rsp_tile_y,
                                                            axi_rsp_beat_idx + 1'b1);
                    end else begin
                        i_m_axi_rdata <= pack_raw_tile_axi_word(axi_rsp_tile_fmt, axi_rsp_addr, axi_rsp_beat_idx + 1'b1);
                        dbg_axi_word64_base = (((axi_rsp_addr -
                                                (((axi_rsp_tile_fmt == META_FMT_NV12_UV) ||
                                                  (axi_rsp_tile_fmt == META_FMT_P010_UV)) ?
                                                 CASE_TILE_BASE_ADDR_UV : CASE_TILE_BASE_ADDR_Y)) >> 3) +
                                               ((axi_rsp_beat_idx + 1'b1) * (M_AXI_DW / 64)));
                        if ((tb_debug_word64_index >= dbg_axi_word64_base) &&
                            (tb_debug_word64_index < (dbg_axi_word64_base + (M_AXI_DW / 64)))) begin
                            $display("[TB][DBG_AXI_TILE] time=%0t addr=0x%016h base_idx=%0d target_idx=%0d beat=%0d lane=%0d data=0x%064h",
                                     $time,
                                     axi_rsp_addr,
                                     dbg_axi_word64_base,
                                     tb_debug_word64_index,
                                     axi_rsp_beat_idx + 1'b1,
                                     tb_debug_word64_index - dbg_axi_word64_base,
                                     pack_raw_tile_axi_word(axi_rsp_tile_fmt, axi_rsp_addr, axi_rsp_beat_idx + 1'b1));
                        end
                    end
                end
            end
        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            enc_i_m_axi_awready <= 1'b1;
            enc_i_m_axi_wready  <= 1'b1;
            enc_i_m_axi_bid     <= {(AXI_IDW+1){1'b0}};
            enc_i_m_axi_bresp   <= 2'b00;
            enc_i_m_axi_bvalid  <= 1'b0;
            enc_aw_cnt          <= 0;
            enc_w_cnt           <= 0;
            enc_b_cnt           <= 0;
            enc_b_wr_ptr        <= 0;
            enc_b_rd_ptr        <= 0;
        end else if (LOOP_TO_ENC != 0) begin
            enc_i_m_axi_awready <= 1'b1;
            enc_i_m_axi_wready  <= 1'b1;

            if (enc_i_m_axi_bvalid && enc_o_m_axi_bready) begin
                enc_i_m_axi_bvalid <= 1'b0;
                enc_b_cnt          <= enc_b_cnt + 1;
            end

            if (enc_o_m_axi_awvalid && enc_i_m_axi_awready) begin
                enc_b_id_queue[enc_b_wr_ptr] <= enc_o_m_axi_awid;
                enc_b_wr_ptr                 <= enc_b_wr_ptr + 1;
                enc_aw_cnt                   <= enc_aw_cnt + 1;
                last_progress_cycle          <= cycle_cnt;
            end

            if (enc_o_m_axi_wvalid && enc_i_m_axi_wready) begin
                enc_w_cnt          <= enc_w_cnt + 1;
                last_progress_cycle<= cycle_cnt;
                if (enc_o_m_axi_wlast) begin
                    enc_i_m_axi_bvalid <= 1'b1;
                    enc_i_m_axi_bid    <= enc_b_id_queue[enc_b_rd_ptr];
                    enc_i_m_axi_bresp  <= 2'b00;
                    enc_b_rd_ptr       <= enc_b_rd_ptr + 1;
                end
            end
        end else begin
            enc_i_m_axi_awready <= 1'b1;
            enc_i_m_axi_wready  <= 1'b1;
            enc_i_m_axi_bvalid  <= 1'b0;
        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn) begin
            loop_enc_coord_rd_cnt         <= 0;
            loop_enc_coord_uv_rd_cnt      <= 0;
            loop_enc_coord_frame_last_cnt <= 0;
            loop_enc_last_coord_format    <= 5'd0;
            loop_enc_last_coord_x         <= 16'd0;
            loop_enc_last_coord_y         <= 16'd0;
            loop_enc_last_coord_cols      <= 16'd0;
            loop_enc_last_coord_rows      <= 16'd0;
            loop_enc_last_coord_uv        <= 1'b0;
            loop_enc_last_coord_last_col  <= 1'b0;
            loop_enc_last_coord_last_row  <= 1'b0;
            loop_enc_last_coord_frame_last<= 1'b0;
            loop_enc_last_uv_format       <= 5'd0;
            loop_enc_last_uv_x            <= 16'd0;
            loop_enc_last_uv_y            <= 16'd0;
            loop_enc_last_uv_cols         <= 16'd0;
            loop_enc_last_uv_rows         <= 16'd0;
            loop_enc_last_uv_last_col     <= 1'b0;
            loop_enc_last_uv_last_row     <= 1'b0;
            loop_enc_last_uv_frame_last   <= 1'b0;
        end else if (loop_enc_coord_fifo_rd_en) begin
            loop_enc_coord_rd_cnt          <= loop_enc_coord_rd_cnt + 1;
            loop_enc_last_coord_format     <= loop_enc_coord_format;
            loop_enc_last_coord_x          <= loop_enc_coord_x;
            loop_enc_last_coord_y          <= loop_enc_coord_y;
            loop_enc_last_coord_cols       <= loop_enc_coord_cols;
            loop_enc_last_coord_rows       <= loop_enc_coord_rows;
            loop_enc_last_coord_uv         <= loop_enc_coord_is_uv_plane;
            loop_enc_last_coord_last_col   <= loop_enc_coord_last_col;
            loop_enc_last_coord_last_row   <= loop_enc_coord_last_row;
            loop_enc_last_coord_frame_last <= loop_enc_coord_frame_last;
            if (loop_enc_coord_is_uv_plane) begin
                loop_enc_coord_uv_rd_cnt    <= loop_enc_coord_uv_rd_cnt + 1;
                loop_enc_last_uv_format     <= loop_enc_coord_format;
                loop_enc_last_uv_x          <= loop_enc_coord_x;
                loop_enc_last_uv_y          <= loop_enc_coord_y;
                loop_enc_last_uv_cols       <= loop_enc_coord_cols;
                loop_enc_last_uv_rows       <= loop_enc_coord_rows;
                loop_enc_last_uv_last_col   <= loop_enc_coord_last_col;
                loop_enc_last_uv_last_row   <= loop_enc_coord_last_row;
                loop_enc_last_uv_frame_last <= loop_enc_coord_frame_last;
            end
            if (loop_enc_coord_frame_last)
                loop_enc_coord_frame_last_cnt <= loop_enc_coord_frame_last_cnt + 1;
        end
    end

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        reg [127:0] exp_data_word;
        reg [127:0] otf_cmp_mask;
        reg [15:0]  otf_valid_pixels;
        if (!i_otf_rstn) begin
            otf_beat_cnt            <= 0;
            otf_mismatch_cnt        <= 0;
            first_otf_mismatch_beat <= -1;
            first_otf_mismatch_x    <= -1;
            first_otf_mismatch_y    <= -1;
            first_otf_expected_data <= 128'd0;
            first_otf_actual_data   <= 128'd0;
            otf_frame_done          <= 1'b0;
            otf_frame_done_count    <= 0;
            otf_active_x            <= 0;
            otf_active_y            <= 0;
            last_otf_progress_cycle <= 0;
        end else if (dec_i_otf_ready_eff && tb_otf_de && !otf_frame_done) begin
            if (otf_beat_cnt >= expected_otf_beats_total) begin
                $fatal(1, "Observed extra OTF beat beyond expected stream. beat=%0d data=%032h",
                       otf_beat_cnt, tb_otf_data);
            end
            exp_data_word = expected_otf_beats[otf_beat_cnt % CASE_EXPECTED_OTF_BEATS];
            if ((otf_active_x + 4) > CASE_OTF_H_ACT)
                otf_valid_pixels = CASE_OTF_H_ACT - otf_active_x;
            else
                otf_valid_pixels = 16'd4;

            case (otf_valid_pixels)
                16'd0   : otf_cmp_mask = 128'h00000000000000000000000000000000;
                16'd1   : otf_cmp_mask = 128'h000000000000000000000000ffffffff;
                16'd2   : otf_cmp_mask = 128'h0000000000000000ffffffffffffffff;
                16'd3   : otf_cmp_mask = 128'h00000000ffffffffffffffffffffffff;
                default : otf_cmp_mask = 128'hffffffffffffffffffffffffffffffff;
            endcase

            if (otf_fd != 0) begin
                $fwrite(otf_fd, "%032h\n", tb_otf_data);
            end
            if ((tb_otf_data & otf_cmp_mask) !== (exp_data_word & otf_cmp_mask)) begin
                otf_mismatch_cnt <= otf_mismatch_cnt + 1;
                if (first_otf_mismatch_beat < 0) begin
                    first_otf_mismatch_beat <= otf_beat_cnt;
                    first_otf_mismatch_x    <= otf_active_x;
                    first_otf_mismatch_y    <= otf_active_y;
                    first_otf_expected_data <= exp_data_word;
                    first_otf_actual_data   <= tb_otf_data;
                end
            end

            otf_beat_cnt            <= otf_beat_cnt + 1;
            last_progress_cycle     <= cycle_cnt;
            last_otf_progress_cycle <= cycle_cnt;

            if ((otf_active_x + 4) >= CASE_OTF_H_ACT) begin
                otf_active_x <= 0;
                if (otf_active_y == (CASE_OTF_V_ACT - 1)) begin
                    otf_active_y         <= 0;
                    otf_frame_done_count <= otf_frame_done_count + 1;
                    otf_frame_done       <= ((otf_frame_done_count + 1) >= tb_frame_repeat);
                end else begin
                    otf_active_y <= otf_active_y + 1;
                end
            end else begin
                otf_active_x <= otf_active_x + 4;
            end
        end
    end

    initial begin
        integer init_idx;
        integer enc_addr_cfg_programmed;
        case (CASE_ID)
            CASE_RGBA1010102: begin
                case_name            = "TajMahal RGBA1010102";
                stream_plane0_file   = "";
                expected_stream_plane0_file = "";
                stream_plane1_file   = "";
                expected_stream_plane1_file = "";
                if (TB_REAL_VIVO_MODE != 0) begin
                    stream_file          = "wrapper_tajmahal_vivo_rgba1010102.txt";
                    expected_stream_file = "wrapper_tajmahal_vivo_expected_rgba1010102.txt";
                end else begin
                    stream_file          = "wrapper_tajmahal_fake_vivo_rgba1010102.txt";
                    expected_stream_file = "wrapper_tajmahal_fake_vivo_expected_rgba1010102.txt";
                end
            end
            CASE_NV12: begin
                case_name            = "TajMahal NV12";
                if (TB_REAL_VIVO_MODE != 0) begin
                    stream_file          = "wrapper_tajmahal_vivo_nv12.txt";
                    expected_stream_file = "wrapper_tajmahal_vivo_expected_nv12.txt";
                    stream_plane0_file   = "wrapper_tajmahal_vivo_nv12_y.txt";
                    expected_stream_plane0_file = "wrapper_tajmahal_vivo_expected_nv12_y.txt";
                    stream_plane1_file   = "wrapper_tajmahal_vivo_nv12_uv.txt";
                    expected_stream_plane1_file = "wrapper_tajmahal_vivo_expected_nv12_uv.txt";
                end else begin
                    stream_file          = "wrapper_tajmahal_fake_vivo_nv12.txt";
                    expected_stream_file = "wrapper_tajmahal_fake_vivo_expected_nv12.txt";
                    stream_plane0_file   = "wrapper_tajmahal_fake_vivo_nv12_y.txt";
                    expected_stream_plane0_file = "wrapper_tajmahal_fake_vivo_expected_nv12_y.txt";
                    stream_plane1_file   = "wrapper_tajmahal_fake_vivo_nv12_uv.txt";
                    expected_stream_plane1_file = "wrapper_tajmahal_fake_vivo_expected_nv12_uv.txt";
                end
            end
            CASE_G016: begin
                case_name            = "K Outdoor61 G016";
                if (TB_REAL_VIVO_MODE != 0) begin
                    stream_file          = "wrapper_k_outdoor61_vivo_g016.txt";
                    expected_stream_file = "wrapper_k_outdoor61_vivo_expected_g016.txt";
                    stream_plane0_file   = "wrapper_k_outdoor61_vivo_g016_y.txt";
                    expected_stream_plane0_file = "wrapper_k_outdoor61_vivo_expected_g016_y.txt";
                    stream_plane1_file   = "wrapper_k_outdoor61_vivo_g016_uv.txt";
                    expected_stream_plane1_file = "wrapper_k_outdoor61_vivo_expected_g016_uv.txt";
                end else begin
                    stream_file          = "wrapper_k_outdoor61_fake_vivo_g016.txt";
                    expected_stream_file = "wrapper_k_outdoor61_fake_vivo_expected_g016.txt";
                    stream_plane0_file   = "wrapper_k_outdoor61_fake_vivo_g016_y.txt";
                    expected_stream_plane0_file = "wrapper_k_outdoor61_fake_vivo_expected_g016_y.txt";
                    stream_plane1_file   = "wrapper_k_outdoor61_fake_vivo_g016_uv.txt";
                    expected_stream_plane1_file = "wrapper_k_outdoor61_fake_vivo_expected_g016_uv.txt";
                end
            end
            default: begin
                case_name            = "TajMahal RGBA8888";
                stream_plane0_file   = "";
                expected_stream_plane0_file = "";
                stream_plane1_file   = "";
                expected_stream_plane1_file = "";
                if (TB_REAL_VIVO_MODE != 0) begin
                    stream_file          = "wrapper_tajmahal_vivo_rgba8888.txt";
                    expected_stream_file = "wrapper_tajmahal_vivo_expected_rgba8888.txt";
                end else begin
                    stream_file          = "wrapper_tajmahal_fake_vivo_rgba8888.txt";
                    expected_stream_file = "wrapper_tajmahal_fake_vivo_expected_rgba8888.txt";
                end
            end
        endcase
        dec_meta_actual_file   = "wrapper_dec_meta_actual.txt";
        dec_meta_expected_file = "wrapper_dec_meta_expected.txt";
        fc_sc_event_file       = "dec_fc_sc_events.txt";
        summary_file = "wrapper_compare_summary.txt";

        for (init_idx = 0; init_idx < CASE_CMP0_WORDS64; init_idx = init_idx + 1) begin
            tile_plane0_words[init_idx]      = 64'd0;
        end
        for (init_idx = 0; init_idx < CASE_CMP1_WORDS64; init_idx = init_idx + 1) begin
            tile_plane1_words[init_idx]      = 64'd0;
        end
        for (init_idx = 0; init_idx < CASE_TILE0_WORDS64; init_idx = init_idx + 1) begin
            ref_tile_plane0_words[init_idx]  = 64'd0;
            actual_rvo_plane0_words[init_idx]= 64'hcccccccccccccccc;
        end
        for (init_idx = 0; init_idx < CASE_TILE1_WORDS64; init_idx = init_idx + 1) begin
            ref_tile_plane1_words[init_idx]  = 64'd0;
            actual_rvo_plane1_words[init_idx]= 64'hcccccccccccccccc;
        end

        $readmemh("expected_otf_stream.txt", expected_otf_beats);
        $readmemh("input_meta_plane0.txt", meta_plane0_words);
        $readmemh("input_tile_plane0.txt", tile_plane0_words);
        $readmemh("inject_tile_plane0.txt", ref_tile_plane0_words);
        if (CASE_HAS_PLANE1) begin
            $readmemh("input_meta_plane1.txt", meta_plane1_words);
            $readmemh("input_tile_plane1.txt", tile_plane1_words);
            $readmemh("inject_tile_plane1.txt", ref_tile_plane1_words);
        end

        if (^expected_otf_beats[0] === 1'bx) begin
            $fatal(1, "Failed to load expected_otf_stream.txt");
        end
        if (^meta_plane0_words[0] === 1'bx) begin
            $fatal(1, "Failed to load input_meta_plane0.txt");
        end
        if (^tile_plane0_words[0] === 1'bx) begin
            $fatal(1, "Failed to load input_tile_plane0.txt");
        end
        if (^ref_tile_plane0_words[0] === 1'bx) begin
            $fatal(1, "Failed to load inject_tile_plane0.txt");
        end
        if (CASE_HAS_PLANE1) begin
            if (^meta_plane1_words[0] === 1'bx) begin
                $fatal(1, "Failed to load input_meta_plane1.txt");
            end
            if (^tile_plane1_words[0] === 1'bx) begin
                $fatal(1, "Failed to load input_tile_plane1.txt");
            end
            if (^ref_tile_plane1_words[0] === 1'bx) begin
                $fatal(1, "Failed to load inject_tile_plane1.txt");
            end
        end

        PRESETn         = 1'b0;
        i_axi_rstn      = 1'b0;
        i_otf_rstn      = 1'b0;
        i_vivo_rstn     = 1'b0;
        PSEL            = 1'b0;
        PENABLE         = 1'b0;
        PADDR           = {APB_AW{1'b0}};
        PWRITE          = 1'b0;
        PWDATA          = {APB_DW{1'b0}};
        enc_PSEL        = 1'b0;
        enc_PENABLE     = 1'b0;
        enc_PADDR       = {APB_AW{1'b0}};
        enc_PWRITE      = 1'b0;
        enc_PWDATA      = {APB_DW{1'b0}};
        enc_i_m_axi_awready = 1'b1;
        enc_i_m_axi_wready  = 1'b1;
        enc_i_m_axi_bid     = {(AXI_IDW+1){1'b0}};
        enc_i_m_axi_bresp   = 2'b00;
        enc_i_m_axi_bvalid  = 1'b0;
        i_otf_ready     = 1'b0;
        otf_ready_div   = 2'd0;
        i_m_axi_arready = 1'b1;
        i_m_axi_rdata   = {M_AXI_DW{1'b0}};
        i_m_axi_rvalid  = 1'b0;
        i_m_axi_rresp   = 2'b00;
        i_m_axi_rlast   = 1'b0;
        tb_otf_ready_random_en  = 0;
        tb_otf_ready_seed       = 32'h3c6e_f372;
        tb_otf_ready_stall_pct  = 0;
        tb_axi_random_en        = 0;
        tb_axi_seed             = 32'h5eed_0d1a;
        tb_axi_ar_stall_pct     = 0;
        tb_axi_rvalid_stall_pct = 0;
        tb_axi_read_delay_cycles= 0;
        tb_debug_word64_index   = -1;
        tb_check_no_otf_underflow = 0;
        otf_ready_rand_state    = 32'h3c6e_f372;
        axi_rand_state          = 32'h5eed_0d1a;
        enc_aw_cnt              = 0;
        enc_w_cnt               = 0;
        enc_b_cnt               = 0;
        enc_b_wr_ptr            = 0;
        enc_b_rd_ptr            = 0;
        loop_enc_coord_rd_cnt         = 0;
        loop_enc_coord_uv_rd_cnt      = 0;
        loop_enc_coord_frame_last_cnt = 0;
        loop_enc_last_coord_format    = 5'd0;
        loop_enc_last_coord_x         = 16'd0;
        loop_enc_last_coord_y         = 16'd0;
        loop_enc_last_coord_cols      = 16'd0;
        loop_enc_last_coord_rows      = 16'd0;
        loop_enc_last_coord_uv        = 1'b0;
        loop_enc_last_coord_last_col  = 1'b0;
        loop_enc_last_coord_last_row  = 1'b0;
        loop_enc_last_coord_frame_last= 1'b0;
        loop_enc_last_uv_format       = 5'd0;
        loop_enc_last_uv_x            = 16'd0;
        loop_enc_last_uv_y            = 16'd0;
        loop_enc_last_uv_cols         = 16'd0;
        loop_enc_last_uv_rows         = 16'd0;
        loop_enc_last_uv_last_col     = 1'b0;
        loop_enc_last_uv_last_row     = 1'b0;
        loop_enc_last_uv_frame_last   = 1'b0;
        axi_rsp_active  = 1'b0;
        axi_rsp_id      = {(AXI_IDW+1){1'b0}};
        axi_rsp_wait_cycles = 0;
        cycle_cnt       = 0;
        last_progress_cycle = 0;
        stream_fd       = 0;
        expected_stream_fd = 0;
        stream_plane0_fd = 0;
        expected_stream_plane0_fd = 0;
        stream_plane1_fd = 0;
        expected_stream_plane1_fd = 0;
        dec_meta_actual_fd = 0;
        dec_meta_expected_fd = 0;
        for (init_idx = 0; init_idx < 6; init_idx = init_idx + 1) begin
            vivo_ci_fd[init_idx]       = 0;
            vivo_cvi_fd[init_idx]      = 0;
            vivo_rvo_fd[init_idx]      = 0;
            vivo_ci_dump_cnt[init_idx] = 0;
            vivo_cvi_dump_cnt[init_idx]= 0;
            vivo_rvo_dump_cnt[init_idx]= 0;
        end
        otf_fd          = 0;
        compressed_tile_in_fd = 0;
        summary_fd      = 0;
        tb_timeout_limit_cycles = CASE_TIMEOUT_CYCLES;
        tb_idle_gap_limit_cycles = CASE_IDLE_GAP_CYCLES;
        tb_frame_repeat = 1;
        cvi_tile_rd_ptr     = 0;
        cvi_tile_beat_idx   = 0;
        cmp_tile_rd_ptr     = 0;
        cmp_tile_beat_idx   = 0;
        inject_tile_cnt     = 0;
        inject_axis_format     = 5'd0;
        inject_axis_tile_x     = 16'd0;
        inject_axis_tile_y     = 16'd0;
        inject_axis_tile_valid = 1'b0;
        inject_axis_tdata      = 256'd0;
        inject_axis_tlast      = 1'b0;
        inject_axis_tvalid     = 1'b0;
        void'($value$plusargs("tb_timeout_cycles=%d", tb_timeout_limit_cycles));
        void'($value$plusargs("tb_idle_gap_cycles=%d", tb_idle_gap_limit_cycles));
        void'($value$plusargs("tb_frame_repeat=%d", tb_frame_repeat));
        if ($test$plusargs("tb_otf_ready_random"))
            tb_otf_ready_random_en = 1;
        if ($test$plusargs("tb_axi_random"))
            tb_axi_random_en = 1;
        void'($value$plusargs("tb_otf_ready_random=%d", tb_otf_ready_random_en));
        void'($value$plusargs("tb_otf_ready_seed=%d", tb_otf_ready_seed));
        void'($value$plusargs("tb_otf_ready_stall_pct=%d", tb_otf_ready_stall_pct));
        void'($value$plusargs("tb_axi_random=%d", tb_axi_random_en));
        void'($value$plusargs("tb_axi_seed=%d", tb_axi_seed));
        void'($value$plusargs("tb_axi_ar_stall_pct=%d", tb_axi_ar_stall_pct));
        void'($value$plusargs("tb_axi_rvalid_stall_pct=%d", tb_axi_rvalid_stall_pct));
        void'($value$plusargs("tb_axi_read_delay_cycles=%d", tb_axi_read_delay_cycles));
        void'($value$plusargs("tb_debug_word64_index=%d", tb_debug_word64_index));
        if ($test$plusargs("tb_check_no_otf_underflow"))
            tb_check_no_otf_underflow = 1;
        otf_ready_rand_state = (tb_otf_ready_seed == 0) ? 32'h3c6e_f372 : tb_otf_ready_seed[31:0];
        axi_rand_state       = (tb_axi_seed == 0) ? 32'h5eed_0d1a : tb_axi_seed[31:0];
        if (tb_frame_repeat < 1) begin
            tb_frame_repeat = 1;
        end else if (tb_frame_repeat > MAX_FRAME_REPEAT) begin
            $display("WARN: tb_frame_repeat=%0d exceeds FIFO TB max %0d; clamp to %0d",
                     tb_frame_repeat, MAX_FRAME_REPEAT, MAX_FRAME_REPEAT);
            tb_frame_repeat = MAX_FRAME_REPEAT;
        end
        expected_ci_cmds_total = CASE_EXPECTED_CI_CMDS * tb_frame_repeat;
        expected_dec_meta_samples_total = CASE_EXPECTED_DEC_META_SAMPLES * tb_frame_repeat;
        expected_otf_beats_total = CASE_EXPECTED_OTF_BEATS * tb_frame_repeat;
        expected_rvo_last_total = CASE_EXPECTED_CI_CMDS * tb_frame_repeat;

        repeat (8) @(posedge i_axi_clk);
        PRESETn    = 1'b1;
        i_axi_rstn = 1'b1;
        i_otf_rstn = 1'b1;
        i_vivo_rstn = 1'b1;
        repeat (4) @(posedge i_axi_clk);

        stream_fd = $fopen(stream_file, "w");
        if (stream_fd == 0) begin
            $fatal(1, "Failed to open %0s", stream_file);
        end
        expected_stream_fd = $fopen(expected_stream_file, "w");
        if (expected_stream_fd == 0) begin
            $fatal(1, "Failed to open %0s", expected_stream_file);
        end
        if (CASE_HAS_PLANE1) begin
            stream_plane0_fd = $fopen(stream_plane0_file, "w");
            if (stream_plane0_fd == 0) begin
                $fatal(1, "Failed to open %0s", stream_plane0_file);
            end
            expected_stream_plane0_fd = $fopen(expected_stream_plane0_file, "w");
            if (expected_stream_plane0_fd == 0) begin
                $fatal(1, "Failed to open %0s", expected_stream_plane0_file);
            end
            stream_plane1_fd = $fopen(stream_plane1_file, "w");
            if (stream_plane1_fd == 0) begin
                $fatal(1, "Failed to open %0s", stream_plane1_file);
            end
            expected_stream_plane1_fd = $fopen(expected_stream_plane1_file, "w");
            if (expected_stream_plane1_fd == 0) begin
                $fatal(1, "Failed to open %0s", expected_stream_plane1_file);
            end
        end
        otf_fd = $fopen("actual_otf_stream.txt", "w");
        if (otf_fd == 0) begin
            $fatal(1, "Failed to open actual_otf_stream.txt");
        end
        compressed_tile_in_fd = $fopen("compressed_tile_in.txt", "w");
        if (compressed_tile_in_fd == 0) begin
            $fatal(1, "Failed to open compressed_tile_in.txt");
        end
        dec_meta_actual_fd = $fopen(dec_meta_actual_file, "w");
        if (dec_meta_actual_fd == 0) begin
            $fatal(1, "Failed to open %0s", dec_meta_actual_file);
        end
        dec_meta_expected_fd = $fopen(dec_meta_expected_file, "w");
        if (dec_meta_expected_fd == 0) begin
            $fatal(1, "Failed to open %0s", dec_meta_expected_file);
        end
        fc_sc_event_fd = $fopen(fc_sc_event_file, "w");
        if (fc_sc_event_fd == 0) begin
            $fatal(1, "Failed to open %0s", fc_sc_event_file);
        end
        fc_sc_event_cnt = 0;
        $fwrite(dec_meta_actual_fd, "# idx raw fmt flag alen payload x y\n");
        $fwrite(fc_sc_event_fd, "# event_idx time_ps time_ns stage idx kind raw fmt flag alen alpha_mode x y\n");
        dump_expected_dec_meta_stream(dec_meta_expected_fd);
        open_vivo_dump_files();
        summary_fd = $fopen(summary_file, "w");
        if (summary_fd == 0) begin
            $fatal(1, "Failed to open %0s", summary_file);
        end

        $display("");
        $display("==============================================================");
        $display("TB: ubwc_dec_wrapper_top unified check %0s", case_name);
        $display("Vivo mode   : %s", (TB_REAL_VIVO_MODE != 0) ? "real/rvo-compare" : "fake/uncompressed-axi+rvo-compare");
        $display("Metadata plane0 : input_meta_plane0.txt");
        if (CASE_HAS_PLANE1) $display("Metadata plane1 : input_meta_plane1.txt");
        $display("Tile plane0 : input_tile_plane0.txt");
        if (CASE_HAS_PLANE1) $display("Tile plane1 : input_tile_plane1.txt");
        $display("Ref tile0   : inject_tile_plane0.txt");
        if (CASE_HAS_PLANE1) $display("Ref tile1   : inject_tile_plane1.txt");
        if (TB_REAL_VIVO_MODE != 0) begin
            $display("Actual RVO  : %0s", stream_file);
            $display("Expect RVO  : %0s", expected_stream_file);
        end else begin
            $display("Actual RVO  : %0s", stream_file);
            $display("Expect RVO  : %0s", expected_stream_file);
        end
        if (CASE_HAS_PLANE1) begin
            $display("Actual RVO Y: %0s", stream_plane0_file);
            $display("Expect RVO Y: %0s", expected_stream_plane0_file);
            $display("Actual RVO U: %0s", stream_plane1_file);
            $display("Expect RVO U: %0s", expected_stream_plane1_file);
        end
        $display("Comp Tile In: compressed_tile_in.txt");
        $display("Vivo CI dump: vivo_ci_<format>.txt");
        $display("Vivo CVI dump: vivo_cvi_<format>.txt");
        $display("Vivo RVO dump: vivo_rvo_<format>.txt");
        $display("Dec Meta Act: %0s", dec_meta_actual_file);
        $display("Dec Meta Exp: %0s", dec_meta_expected_file);
        $display("FC/SC Events: %0s", fc_sc_event_file);
        $display("Actual OTF  : actual_otf_stream.txt");
        $display("Expected OTF: expected_otf_stream.txt");
        $display("Summary     : %0s", summary_file);
        $display("Tile counts : x=%0d y=%0d", CASE_TILE_X_NUMBERS, CASE_TILE_Y_NUMBERS);
        $display("Frame repeat: %0d", tb_frame_repeat);
        $display("==============================================================");

        if (LOOP_TO_ENC != 0) begin
            program_enc_wrapper_regs();
            enc_addr_cfg_programmed = (tb_frame_repeat < 8) ? tb_frame_repeat : 8;
            program_enc_frame_start();
        end
        program_wrapper_regs();

        for (tb_program_frame_idx = 1;
             tb_program_frame_idx < tb_frame_repeat;
             tb_program_frame_idx = tb_program_frame_idx + 1) begin
            wait ((otf_frame_done_count >= tb_program_frame_idx) &&
                  (o_stage_done == 5'h1b) &&
                  (o_frame_done == 1'b1) &&
                  (o_irq == 1'b1) &&
                  (dut.u_tile_to_otf.tile_to_otf_idle_sram == 1'b1));
            if (LOOP_TO_ENC != 0) begin
                tb_enc_status_wait_cycles = 0;
                while (((enc_o_frame_done !== 1'b1) || (enc_o_irq !== 1'b1)) &&
                       (tb_enc_status_wait_cycles < tb_idle_gap_limit_cycles)) begin
                    @(posedge i_axi_clk);
                    tb_enc_status_wait_cycles = tb_enc_status_wait_cycles + 1;
                end
            end
            repeat (8) @(posedge i_axi_clk);
            apb_write(16'h0060, 32'h0000_0003);
            repeat (8) @(posedge i_axi_clk);
            if (LOOP_TO_ENC != 0) begin
                enc_apb_write(16'h0060, 32'h0000_0003);
                repeat (8) @(posedge i_axi_clk);
                if (enc_addr_cfg_programmed < tb_frame_repeat) begin
                    program_enc_addr_cfg_once();
                    enc_addr_cfg_programmed = enc_addr_cfg_programmed + 1;
                end
                program_enc_frame_start();
                repeat (32) @(posedge i_axi_clk);
            end
            program_frame_base_and_start();
        end
    end

    initial begin : fake_otf_injector
        inject_axis_idle();
    end

    initial begin : finish_block
        integer dump_idx;
        integer fail_check_cnt;
        integer status_wait_cycles;
        integer inactive_tail_cnt;
        integer loop_wait_cycles;
        timeout_cycles = 0;
        fail_check_cnt = 0;
        status_wait_cycles = 0;
        inactive_tail_cnt = 0;
        loop_wait_cycles = 0;
        wait (PRESETn && i_axi_rstn && i_otf_rstn && i_vivo_rstn);
        repeat (100) @(posedge i_axi_clk);
        while ((ci_accept_cnt < expected_ci_cmds_total ||
                axi_rsp_active ||
                (tile_queue_rd_ptr < tile_queue_wr_ptr) ||
                (cmp_tile_rd_ptr < expected_ci_cmds_total) ||
                ((TB_REAL_VIVO_MODE == 0) && (fake_ci_fifo_rd_cnt < ci_queue_wr_ptr)) ||
                !otf_frame_done) &&
               ((cycle_cnt - last_progress_cycle) <= tb_idle_gap_limit_cycles) &&
               (timeout_cycles < tb_timeout_limit_cycles)) begin
            @(posedge i_axi_clk);
            timeout_cycles = timeout_cycles + 1;
        end

        while (otf_frame_done &&
               ((o_stage_done !== 5'h1b) || (o_frame_done !== 1'b1) || (o_irq !== 1'b1)) &&
               (status_wait_cycles < 1024)) begin
            @(posedge i_axi_clk);
            status_wait_cycles = status_wait_cycles + 1;
        end

        if (LOOP_TO_ENC != 0) begin
            while (((enc_o_frame_done !== 1'b1) || (enc_o_irq !== 1'b1) ||
                    (enc_b_cnt != enc_aw_cnt) || enc_i_m_axi_bvalid) &&
                   (loop_wait_cycles < tb_idle_gap_limit_cycles)) begin
                @(posedge i_axi_clk);
                loop_wait_cycles = loop_wait_cycles + 1;
            end
        end

        $display("Wrapper vivo run summary:");
        $display("  meta AR count        : %0d", meta_ar_cnt);
        $display("  meta plane0 AR count : %0d", meta_ar_plane0_cnt);
        $display("  meta plane1 AR count : %0d", meta_ar_plane1_cnt);
        $display("  tile AR count        : %0d", tile_ar_cnt);
        $display("  payload tile cmds    : %0d", payload_cmd_cnt);
        $display("  CI accepted count    : %0d", ci_accept_cnt);
        $display("  AXI R beat count     : %0d", axi_rbeat_cnt);
        $display("  AXI R handshakes     : %0d", m_rhandshake_cnt);
        $display("  meta R beat count    : %0d", meta_rbeat_cnt);
        $display("  tile R beat count    : %0d", tile_rbeat_cnt);
        $display("  Tile R no-RVO beats  : %0d", tile_rbeat_no_rvo_cnt);
        $display("  R no-sink count      : %0d", m_r_nosink_cnt);
        $display("  R no-sink meta/tile  : %0d / %0d", m_r_nosink_meta_cnt, m_r_nosink_tile_cnt);
        $display("  rbuf drain meta/tile : %0d / %0d", rbuf_meta_drain_cnt, rbuf_tile_drain_cnt);
        $display("  AXI RDATA cccc hits  : %0d (meta=%0d tile=%0d)",
                 axi_rdata_cccc_cnt, axi_rdata_cccc_meta_cnt, axi_rdata_cccc_tile_cnt);
        $display("  RVO beat count       : %0d", rvo_beat_cnt);
        $display("  RVO last count       : %0d", rvo_last_cnt);
        $display("  CO active cycles     : %0d", co_active_cycle_cnt);
        $display("  writer_vld count     : %0d", writer_vld_cnt);
        $display("  writer hdr/data/rd   : %0d / %0d / %0d",
                 writer_hdr_fire_cnt, writer_data_fire_cnt, writer_data_rd_cnt);
        $display("  fetcher_done count   : %0d", fetcher_done_cnt);
        $display("  fifo_wr count        : %0d", fifo_wr_cnt);
        $display("  fifo_rd count        : %0d", fifo_rd_cnt);
        $display("  otf need+empty cnt   : %0d first=%0d", otf_fifo_empty_need_cnt, first_otf_fifo_empty_need_beat);
        $display("  otf underflow cnt    : %0d", otf_underflow_cnt);
        if (TB_REAL_VIVO_MODE == 0) begin
            $display("  fake CI fifo wr/rd   : %0d / %0d", fake_ci_fifo_wr_cnt, fake_ci_fifo_rd_cnt);
            $display("  fake CI/RVO tiles    : ci_wr=%0d rvo_last=%0d", ci_queue_wr_ptr, fake_ci_fifo_rd_cnt);
            $display("  comp tile hs/last    : %0d / %0d", compressed_tile_hs_cnt, compressed_tile_last_cnt);
        end
        $display("  dec meta outputs     : %0d", dec_meta_out_cnt);
        $display("  dec meta mismatches  : %0d", dec_meta_mismatch_cnt);
        $display("  vivo IF CI count     : %0d", vivo_if_ci_accept_cnt);
        $display("  vivo IF CVI beat/last: %0d / %0d", vivo_if_cvi_beat_cnt, vivo_if_cvi_last_cnt);
        $display("  vivo IF RVO beat/last: %0d / %0d", vivo_if_rvo_beat_cnt, vivo_if_rvo_last_cnt);
        $display("  vivo IF CI mismatch  : %0d", vivo_if_ci_mismatch_cnt);
        $display("  vivo IF CVI mis/u    : data=%0d last=%0d underflow=%0d",
                 vivo_if_cvi_data_mismatch_cnt,
                 vivo_if_cvi_last_mismatch_cnt,
                 vivo_if_cvi_underflow_cnt);
        $display("  vivo IF RVO mis/u    : data=%0d last=%0d underflow=%0d",
                 vivo_if_rvo_data_mismatch_cnt,
                 vivo_if_rvo_last_mismatch_cnt,
                 vivo_if_rvo_underflow_cnt);
        $display("  dbg bank state       : a_free=%0b b_free=%0b pending_a=%0b pending_b=%0b fetch_req=%0b",
                 dut.u_tile_to_otf.sram_a_free, dut.u_tile_to_otf.sram_b_free,
                 dut.u_tile_to_otf.pending_a, dut.u_tile_to_otf.pending_b,
                 dut.u_tile_to_otf.fetcher_req);
        $display("  dbg writer state     : cnt_write=%0d gearbox_sel=%0b hdr_empty=%0b hdr_full=%0b data_empty=%0b data_full=%0b",
                 dut.u_tile_to_otf.u_writer.cnt_write,
                 dut.u_tile_to_otf.u_writer.gearbox_sel,
                 dut.u_tile_to_otf.u_writer.hdr_fifo_empty,
                 dut.u_tile_to_otf.u_writer.hdr_fifo_full,
                 dut.u_tile_to_otf.u_writer.data_fifo_empty,
                 dut.u_tile_to_otf.u_writer.data_fifo_full);
        $display("  dbg fetcher state    : state=%0d line=%0d word=%0d fifo_full=%0b",
                 dut.u_tile_to_otf.u_fetcher.state,
                 dut.u_tile_to_otf.u_fetcher.line_idx,
                 dut.u_tile_to_otf.u_fetcher.word_idx,
                 dut.u_tile_to_otf.u_fetcher.i_fifo_full);
        $display("  dbg vivo interface   : ci_v/r=%0b/%0b cvi_v/r=%0b/%0b co_v/r=%0b/%0b rvo_v/r=%0b/%0b",
                 dut.vivo_ci_valid_int, dut.vivo_ci_ready_raw,
                 dut.vivo_cvi_valid_int, dut.vivo_cvi_ready_int,
                 dut.vivo_co_valid, dut.vivo_co_ready,
                 dut.vivo_rvo_valid, dut.vivo_rvo_ready);
        $display("  OTF beat count       : %0d", otf_beat_cnt);
        $display("  OTF frame done count : %0d", otf_frame_done_count);
        $display("  OTF mismatches       : %0d", otf_mismatch_cnt);
        $display("  dbg arcmd state      : payload_left=%0d ar_left=%0d ci_fifo_empty=%0b ci_fifo_full=%0b",
                 dut.u_tile_arcmd_gen.payload_beats_left_reg,
                 dut.u_tile_arcmd_gen.ar_req_beats_left_reg,
                 dut.u_tile_arcmd_gen.ci_fifo_empty,
                 dut.u_tile_arcmd_gen.ci_fifo_full);
        $display("  dbg tile cfg         : lvl1=%0b lvl2=%0b lvl3=%0b highest=%0d spread=%0b pitch=0x%0h 4line=%0b",
                 dut.u_apb_dec_reg_blk.r_tile_cfg_lvl1_bank_swizzle_en,
                 dut.r_tile_cfg_lvl2_bank_swizzle_en,
                 dut.r_tile_cfg_lvl3_bank_swizzle_en,
                 dut.r_tile_cfg_highest_bank_bit,
                 dut.r_tile_cfg_bank_spread_en,
                 dut.r_tile_cfg_pitch,
                 dut.u_apb_dec_reg_blk.r_tile_cfg_4line_format);
        $display("  dbg tile axi state   : rvalid=%0b rready=%0b rlast=%0b",
                 dut.tile_m_axi_rvalid,
                 dut.tile_m_axi_rready,
                 dut.tile_m_axi_rlast);
        $display("  dbg axi ic state     : inflight=%0b owner_s0=%0b rbuf_valid=%0b m_rvalid=%0b m_rready=%0b m_rlast=%0b",
                 dut.rd_interconnect_core_busy_int,
                 (!dut.core_m_axi_rid_r[AXI_IDW]),
                 1'b0,
                 dut.i_m_axi_rvalid,
                 dut.o_m_axi_rready,
                 dut.i_m_axi_rlast);
        $display("  dbg t2o fcnt         : accept_valid=%0b accept=%0d s_fcnt=%0d tile_accept=%0b",
                 dut.u_tile_to_otf.accept_fcnt_valid_sram,
                 dut.u_tile_to_otf.accept_fcnt_sram,
                 dut.u_tile_to_otf.s_axis_tile_fcnt,
                 dut.u_tile_to_otf.tile_fcnt_accept);
        $display("  dbg t2o start        : fs_empty=%0b fs_rd=%0b otf_ready=%0b fs_pending=%0b fifo_ready=%0b",
                 dut.u_tile_to_otf.frame_start_fifo_empty,
                 dut.u_tile_to_otf.frame_start_fifo_rd_en,
                 dut.u_tile_to_otf.otf_frame_start_ready,
                 dut.u_tile_to_otf.u_otf_driver.frame_start_pending,
                 dut.u_tile_to_otf.fifo_start_ready);
        $display("  dbg t2o writer       : axis_vld=%0b axis_rdy=%0b writer_vld=%0b pending_a=%0b pending_b=%0b",
                 dut.u_tile_to_otf.writer_axis_tile_valid,
                 dut.u_tile_to_otf.writer_axis_tile_ready,
                 dut.u_tile_to_otf.writer_vld,
                 dut.u_tile_to_otf.pending_a,
                 dut.u_tile_to_otf.pending_b);
`ifdef UBWC_DEC_ROTATION
        if (CASE_DEC_ROTATE_EN) begin
            $display("  dbg rotate ref       : active=%0b tile_active=%0b fmt=%0d x=%0d y=%0d beat=%0d done=%0d expect=%0d",
                     dut.u_tile_to_otf.rotate_active,
                     dut.u_tile_to_otf.u_rotate_ref.tile_active,
                     dut.u_tile_to_otf.u_rotate_ref.tile_format_r,
                     dut.u_tile_to_otf.u_rotate_ref.tile_x_r,
                     dut.u_tile_to_otf.u_rotate_ref.tile_y_r,
                     dut.u_tile_to_otf.u_rotate_ref.tile_beat_idx,
                     dut.u_tile_to_otf.u_rotate_ref.tile_done_count,
                     dut.u_tile_to_otf.u_rotate_ref.expect_tile_count);
            $display("  dbg rotate stream    : hdr_v/r=%0b/%0b data_v/r=%0b/%0b emit=%0b fifo_empty=%0b fifo_full=%0b fifo_count=%0d",
                     dut.u_tile_to_otf.s_axis_tile_valid,
                     dut.u_tile_to_otf.s_axis_tile_ready,
                     dut.u_tile_to_otf.s_axis_tvalid,
                     dut.u_tile_to_otf.s_axis_tready,
                     dut.u_tile_to_otf.u_rotate_ref.emit_active,
                     dut.u_tile_to_otf.u_rotate_ref.fifo_empty,
                     dut.u_tile_to_otf.u_rotate_ref.fifo_full,
                     dut.u_tile_to_otf.u_rotate_ref.fifo_rd_count);
        end
`endif
        $display("  dbg wrap fifo        : coord_v=%0b co_v=%0b rvo_empty=%0b rvo_tvalid=%0b rvo_tready=%0b",
                 dut.vivo_coord_fifo_valid,
                 dut.vivo_co_axi_valid,
                 dut.vivo_rvo_fifo_empty,
                 dut.otf_axis_tvalid,
                 dut.otf_axis_tready_int);
        $display("  AR addr mismatches   : %0d", ar_addr_mismatch_cnt);
        $display("  AR len mismatches    : %0d", ar_len_mismatch_cnt);
        $display("  RVO data mismatches  : %0d", rvo_data_mismatch_cnt);
        $display("  RVO last mismatches  : %0d", rvo_last_mismatch_cnt);
        $display("  CO mismatches        : %0d", co_mismatch_cnt);
        $display("  Queue underflows     : %0d", tile_queue_underflow_cnt);
        $display("  dec.stage_done       : 0x%02x", o_stage_done);
        $display("  dec.frame_done       : %0d", o_frame_done);
        $display("  dec.irq              : %0d", o_irq);
        $display("  dec.status wait cyc  : %0d", status_wait_cycles);
        if (LOOP_TO_ENC != 0) begin
            $display("  loop.enc AW/W/B      : %0d / %0d / %0d", enc_aw_cnt, enc_w_cnt, enc_b_cnt);
            $display("  loop.enc stage_done  : 0x%02x", enc_o_stage_done);
            $display("  loop.enc frame_done  : %0d", enc_o_frame_done);
            $display("  loop.enc irq         : %0d", enc_o_irq);
            $display("  loop.enc wait cyc    : %0d", loop_wait_cycles);
            $display("  loop.enc coord last  : rd=%0b v=%0b empty=%0b fmt=%0d x=%0d y=%0d cols=%0d rows=%0d last_col=%0b last_row=%0b yuv=%0b uv=%0b yuv_last_uv=%0b frame_last=%0b addr_done=%0b correct=%0b",
                     loop_enc_coord_fifo_rd_en,
                     loop_enc_coord_fifo_valid,
                     loop_enc_coord_fifo_empty,
                     loop_enc_coord_format,
                     loop_enc_coord_x,
                     loop_enc_coord_y,
                     loop_enc_coord_cols,
                     loop_enc_coord_rows,
                     loop_enc_coord_last_col,
                     loop_enc_coord_last_row,
                     loop_enc_coord_is_yuv420,
                     loop_enc_coord_is_uv_plane,
                     loop_enc_coord_yuv_last_uv,
                     loop_enc_coord_frame_last,
                     loop_enc_addr_cfg_done_pulse,
                     loop_enc_correct_irq_pulse);
            $display("  loop.enc coord cnt   : rd=%0d uv=%0d frame_last=%0d",
                     loop_enc_coord_rd_cnt,
                     loop_enc_coord_uv_rd_cnt,
                     loop_enc_coord_frame_last_cnt);
            $display("  loop.enc last coord  : fmt=%0d x=%0d y=%0d cols=%0d rows=%0d uv=%0b last_col=%0b last_row=%0b frame_last=%0b",
                     loop_enc_last_coord_format,
                     loop_enc_last_coord_x,
                     loop_enc_last_coord_y,
                     loop_enc_last_coord_cols,
                     loop_enc_last_coord_rows,
                     loop_enc_last_coord_uv,
                     loop_enc_last_coord_last_col,
                     loop_enc_last_coord_last_row,
                     loop_enc_last_coord_frame_last);
            $display("  loop.enc last uv     : fmt=%0d x=%0d y=%0d cols=%0d rows=%0d last_col=%0b last_row=%0b frame_last=%0b",
                     loop_enc_last_uv_format,
                     loop_enc_last_uv_x,
                     loop_enc_last_uv_y,
                     loop_enc_last_uv_cols,
                     loop_enc_last_uv_rows,
                     loop_enc_last_uv_last_col,
                     loop_enc_last_uv_last_row,
                     loop_enc_last_uv_frame_last);
            $display("  loop.enc l2t rd      : state=%0d plane=%0b uv_mode=%0b x=%0d y=%0d word=%0d issue=%0b grant=%0b uv_ok=%0b",
                     loop_enc_l2t_rd_state,
                     loop_enc_l2t_rd_plane,
                     loop_enc_l2t_rd_uv_mode,
                     loop_enc_l2t_rd_tile_x,
                     loop_enc_l2t_rd_group_y,
                     loop_enc_l2t_rd_word,
                     loop_enc_l2t_issue_read,
                     loop_enc_l2t_read_grant,
                     loop_enc_l2t_uv_read_allowed);
            $display("  loop.enc l2t fifo    : resp_af=%0b meta_af=%0b resp_e/v=%0b/%0b meta_e/v=%0b/%0b tile_v/r=%0b/%0b data_full/af=%0b/%0b ci_full=%0b coord_full=%0b half_v/last=%0b/%0b flush=%0b pack2=%0b",
                     loop_enc_l2t_resp_afull,
                     loop_enc_l2t_meta_afull,
                     loop_enc_l2t_resp_empty,
                     loop_enc_l2t_resp_valid,
                     loop_enc_l2t_meta_empty,
                     loop_enc_l2t_meta_valid,
                     loop_enc_l2t_tile_vld,
                     loop_enc_l2t_tile_rdy,
                     loop_enc_l2t_data_fifo_full,
                     loop_enc_l2t_data_fifo_afull,
                     loop_enc_l2t_ci_fifo_full,
                     loop_enc_l2t_coord_fifo_full,
                     loop_enc_l2t_half_valid,
                     loop_enc_l2t_half_last,
                     loop_enc_l2t_flush_half_only,
                     loop_enc_l2t_pack_second_fire);
            $display("  loop.enc vivo path   : ci_v/r=%0b/%0b vivo_co_v/r=%0b/%0b co_v/r=%0b/%0b co_fifo_f/e=%0b/%0b vivo_cvo_v/r=%0b/%0b cvo_v/r=%0b/%0b cvo_fifo_f/e=%0b/%0b tile_addr_v=%0b fake_cmd=%0b beat=%0d/%0d valid=%0d fire=%0b last=%0b",
                     loop_enc_wrap_ci_valid,
                     loop_enc_wrap_ci_ready,
                     loop_enc_wrap_vivo_co_valid,
                     loop_enc_wrap_vivo_co_ready,
                     loop_enc_wrap_co_valid,
                     loop_enc_wrap_co_ready,
                     loop_enc_wrap_co_fifo_full,
                     loop_enc_wrap_co_fifo_empty,
                     loop_enc_wrap_vivo_cvo_valid,
                     loop_enc_wrap_vivo_cvo_ready,
                     loop_enc_wrap_cvo_valid,
                     loop_enc_wrap_cvo_ready,
                     loop_enc_wrap_cvo_fifo_full,
                     loop_enc_wrap_cvo_fifo_empty,
                     loop_enc_wrap_tile_addr_vld,
                     loop_enc_wrap_fake_cmd_valid,
                     loop_enc_wrap_fake_cvo_beat_idx,
                     loop_enc_wrap_fake_cvo_total_beats,
                     loop_enc_wrap_fake_cvo_valid_beats,
                     loop_enc_wrap_fake_cvo_fire,
                     loop_enc_wrap_fake_cvo_last);
        end
        if ((rvo_data_mismatch_cnt != 0) || (rvo_last_mismatch_cnt != 0)) begin
            $display("  First RVO mismatch   : fmt=%0d x=%0d y=%0d beat=%0d alen=%0d last=%0d",
                     first_rvo_mismatch_fmt, first_rvo_mismatch_x, first_rvo_mismatch_y,
                     first_rvo_mismatch_beat, first_rvo_expected_alen, first_rvo_actual_last);
            $display("  First RVO exp data   : %064h", first_rvo_expected_data);
            $display("  First RVO act data   : %064h", first_rvo_actual_data);
        end
        if (ar_addr_mismatch_cnt != 0) begin
            $display("  First AR mismatch    : fmt=%0d x=%0d y=%0d", first_ar_mismatch_fmt,
                     first_ar_mismatch_x, first_ar_mismatch_y);
            $display("  First AR exp/act     : %016h / %016h",
                     first_ar_expected_addr, first_ar_actual_addr);
        end
        if (dec_meta_mismatch_cnt != 0) begin
            $display("  First dec meta mis   : idx=%0d raw %02h/%02h fmt %0d/%0d flag %0h/%0h alen %0d/%0d x %0d/%0d y %0d/%0d",
                     first_dec_meta_mismatch_idx,
                     first_dec_meta_expected_raw, first_dec_meta_actual_raw,
                     first_dec_meta_expected_format, first_dec_meta_actual_format,
                     first_dec_meta_expected_flag, first_dec_meta_actual_flag,
                     first_dec_meta_expected_alen, first_dec_meta_actual_alen,
                     first_dec_meta_expected_x, first_dec_meta_actual_x,
                     first_dec_meta_expected_y, first_dec_meta_actual_y);
        end
        if (vivo_ci_mismatch_cnt != 0) begin
            $display("  First vivo CI mis    : fmt=%0d x=%0d y=%0d raw=%02h metadata %0h/%0h alen %0d/%0d",
                     first_vivo_ci_mismatch_fmt,
                     first_vivo_ci_mismatch_x,
                     first_vivo_ci_mismatch_y,
                     first_vivo_ci_expected_raw,
                     first_vivo_ci_expected_metadata,
                     first_vivo_ci_actual_metadata,
                     first_vivo_ci_expected_alen,
                     first_vivo_ci_actual_alen);
        end
        if ((vivo_cvi_data_mismatch_cnt != 0) || (vivo_cvi_last_mismatch_cnt != 0)) begin
            $display("  First vivo CVI mis   : fmt=%0d x=%0d y=%0d beat=%0d last %0b/%0b",
                     first_vivo_cvi_mismatch_fmt,
                     first_vivo_cvi_mismatch_x,
                     first_vivo_cvi_mismatch_y,
                     first_vivo_cvi_mismatch_beat,
                     first_vivo_cvi_expected_last,
                     first_vivo_cvi_actual_last);
            $display("  First vivo CVI exp   : %064h", first_vivo_cvi_expected_data);
            $display("  First vivo CVI act   : %064h", first_vivo_cvi_actual_data);
        end
        if (first_axi_rdata_cccc_cycle >= 0) begin
            $display("  First AXI cccc hit   : cycle=%0d owner=%0s addr=%016h lane=%0d",
                     first_axi_rdata_cccc_cycle,
                     first_axi_rdata_cccc_is_meta ? "meta" : "tile",
                     first_axi_rdata_cccc_addr,
                     first_axi_rdata_cccc_lane);
            $display("  First AXI cccc data  : %064h", first_axi_rdata_cccc_data);
        end
        if (first_m_r_nosink_cycle >= 0) begin
            $display("  First R no-sink cyc  : %0d owner_s0=%0b rlast=%0b rbuf_valid=%0b payload_left=%0d ar_left=%0d",
                     first_m_r_nosink_cycle, first_m_r_nosink_owner_s0,
                     first_m_r_nosink_rlast, first_m_r_nosink_rbuf_valid,
                     first_m_r_nosink_payload_left, first_m_r_nosink_ar_left);
        end

        inactive_tail_cnt = 0;
        for (dump_idx = tile_queue_rd_ptr; dump_idx < tile_queue_wr_ptr; dump_idx = dump_idx + 1) begin
            if (!is_active_rvo_tile(tile_fmt_queue[dump_idx],
                                    tile_x_queue[dump_idx],
                                    tile_y_queue[dump_idx])) begin
                inactive_tail_cnt = inactive_tail_cnt + 1;
            end
        end

        if (meta_ar_cnt == 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: No metadata AXI reads were observed.");
        end
        if (tile_ar_cnt == 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: No tile AXI reads were observed.");
        end
        if (ci_accept_cnt != expected_ci_cmds_total) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Unexpected CI count. got=%0d exp=%0d", ci_accept_cnt, expected_ci_cmds_total);
        end
        if (dec_meta_out_cnt != expected_dec_meta_samples_total) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Unexpected decoded metadata count. got=%0d exp=%0d",
                     dec_meta_out_cnt, expected_dec_meta_samples_total);
        end
        if (dec_meta_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Decoded metadata output mismatches were observed.");
        end
        if (vivo_ci_mismatch_cnt != 0) begin
            $display("WARN: Legacy pre-interface CI checker mismatches were observed; VIVO interface checker is authoritative.");
        end
        if (vivo_cvi_data_mismatch_cnt != 0) begin
            $display("WARN: Legacy pre-interface CVI data checker mismatches were observed; VIVO interface checker is authoritative.");
        end
        if (vivo_cvi_last_mismatch_cnt != 0) begin
            $display("WARN: Legacy pre-interface CVI last checker mismatches were observed; VIVO interface checker is authoritative.");
        end
        if (vivo_if_ci_accept_cnt != expected_ci_cmds_total) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Vivo interface CI count mismatch. got=%0d exp=%0d",
                     vivo_if_ci_accept_cnt, expected_ci_cmds_total);
        end
        if (vivo_if_ci_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Vivo interface CI metadata/alen mismatches were observed.");
        end
        if (vivo_if_cvi_underflow_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Vivo interface CVI arrived before matching CI.");
        end
        if (vivo_if_cvi_data_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Vivo interface CVI compressed-data mismatches were observed.");
        end
        if (vivo_if_cvi_last_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Vivo interface CVI last mismatches were observed.");
        end
        if (vivo_if_rvo_underflow_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Vivo interface RVO arrived before matching CI.");
        end
        if (vivo_if_rvo_data_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Vivo interface RVO data mismatches were observed.");
        end
        if (vivo_if_rvo_last_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Vivo interface RVO last mismatches were observed.");
        end
        if (tile_ar_cnt != (payload_cmd_cnt - inactive_tail_cnt)) begin
            $display("WARN: Tile AR count differs from active payload tile command count. ar=%0d payload=%0d inactive_tail=%0d",
                     tile_ar_cnt, payload_cmd_cnt, inactive_tail_cnt);
        end
        if ((tile_queue_rd_ptr + inactive_tail_cnt) != tile_queue_wr_ptr) begin
            $display("WARN: Tile queue not fully drained by the simplified AR checker. rd=%0d wr=%0d inactive_tail=%0d",
                     tile_queue_rd_ptr, tile_queue_wr_ptr, inactive_tail_cnt);
        end
        if (ar_addr_mismatch_cnt != 0) begin
            $display("WARN: Tile AXI address checker mismatches were observed; RVO/OTF data comparison remains authoritative.");
        end
        if (ar_len_mismatch_cnt != 0) begin
            $display("WARN: Tile AXI len checker mismatches were observed; RVO/OTF data comparison remains authoritative.");
        end
        if (!otf_frame_done) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Wrapper OTF frame did not finish before timeout.");
        end
        if (otf_beat_cnt != expected_otf_beats_total) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Unexpected OTF beat count. got=%0d exp=%0d", otf_beat_cnt, expected_otf_beats_total);
        end
        if (otf_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Wrapper OTF mismatches were observed. first mismatch beat=%0d x=%0d y=%0d",
                     first_otf_mismatch_beat, first_otf_mismatch_x, first_otf_mismatch_y);
            $display("      first OTF expected=%032h", first_otf_expected_data);
            $display("      first OTF actual  =%032h", first_otf_actual_data);
        end
        if ((tb_check_no_otf_underflow != 0) && (otf_underflow_cnt != 0)) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: OTF underflow was observed while no-underflow check is enabled.");
        end
        if (rvo_beat_cnt != expected_rvo_beats_total) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Unexpected RVO beat count. got=%0d exp=%0d", rvo_beat_cnt, expected_rvo_beats_total);
        end
        if (rvo_last_cnt != expected_rvo_last_total) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Unexpected RVO last count. got=%0d exp=%0d", rvo_last_cnt, expected_rvo_last_total);
        end
        if (rvo_data_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Vivo raw output data mismatches were observed.");
        end
        if (rvo_last_mismatch_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Vivo raw output last mismatches were observed.");
        end
        if ((TB_REAL_VIVO_MODE == 0) && (fake_ci_fifo_rd_cnt != ci_queue_wr_ptr)) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Fake vivo RVO tile count mismatch. rvo=%0d ci=%0d", fake_ci_fifo_rd_cnt, ci_queue_wr_ptr);
        end
        if (tile_queue_underflow_cnt != 0) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: Tile command queue underflows were observed.");
        end
        if (o_stage_done !== 5'h1b) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: DEC stage done mismatch. got=0x%02x exp=0x1b", o_stage_done);
        end
        if (o_frame_done !== 1'b1) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: DEC frame_done did not assert.");
        end
        if (o_irq !== 1'b1) begin
            fail_check_cnt = fail_check_cnt + 1;
            $display("FAIL: DEC irq did not assert.");
        end
        if (LOOP_TO_ENC != 0) begin
            if (enc_aw_cnt == 0) begin
                fail_check_cnt = fail_check_cnt + 1;
                $display("FAIL: LOOP ENC did not issue AXI AW.");
            end
            if (enc_w_cnt == 0) begin
                fail_check_cnt = fail_check_cnt + 1;
                $display("FAIL: LOOP ENC did not issue AXI W.");
            end
            if (enc_o_frame_done !== 1'b1) begin
                fail_check_cnt = fail_check_cnt + 1;
                $display("FAIL: LOOP ENC frame_done did not assert.");
            end
            if (enc_o_irq !== 1'b1) begin
                fail_check_cnt = fail_check_cnt + 1;
                $display("FAIL: LOOP ENC irq did not assert.");
            end
        end

        if (CASE_HAS_PLANE1) begin
            if (stream_plane0_fd != 0) begin
                $fwrite(stream_plane0_fd, "@%016h\n", CASE_DUMP_TILE_BASE_ADDR_Y);
                for (dump_idx = 0; dump_idx < CASE_TILE0_WORDS64; dump_idx = dump_idx + 1) begin
                    $fwrite(stream_plane0_fd, "%016h\n", actual_rvo_plane0_words[dump_idx]);
                end
            end
            if (expected_stream_plane0_fd != 0) begin
                $fwrite(expected_stream_plane0_fd, "@%016h\n", CASE_DUMP_TILE_BASE_ADDR_Y);
                for (dump_idx = 0; dump_idx < CASE_TILE0_WORDS64; dump_idx = dump_idx + 1) begin
                    $fwrite(expected_stream_plane0_fd, "%016h\n", ref_tile_plane0_words[dump_idx]);
                end
            end
            if (stream_plane1_fd != 0) begin
                $fwrite(stream_plane1_fd, "@%016h\n", CASE_DUMP_TILE_BASE_ADDR_UV);
                for (dump_idx = 0; dump_idx < CASE_TILE1_WORDS64; dump_idx = dump_idx + 1) begin
                    $fwrite(stream_plane1_fd, "%016h\n", actual_rvo_plane1_words[dump_idx]);
                end
            end
            if (expected_stream_plane1_fd != 0) begin
                $fwrite(expected_stream_plane1_fd, "@%016h\n", CASE_DUMP_TILE_BASE_ADDR_UV);
                for (dump_idx = 0; dump_idx < CASE_TILE1_WORDS64; dump_idx = dump_idx + 1) begin
                    $fwrite(expected_stream_plane1_fd, "%016h\n", ref_tile_plane1_words[dump_idx]);
                end
            end
        end

        if (summary_fd != 0) begin
            $fwrite(summary_fd, "case=%0s\n", case_name);
            $fwrite(summary_fd, "mode=%0s\n", (TB_REAL_VIVO_MODE != 0) ? "real" : "fake");
            $fwrite(summary_fd, "fail_check_cnt=%0d\n", fail_check_cnt);
            $fwrite(summary_fd, "result=%0s\n", (fail_check_cnt == 0) ? "PASS" : "FAIL");
            $fwrite(summary_fd, "actual_rvo=%0s\n", stream_file);
            $fwrite(summary_fd, "expected_rvo=%0s\n", expected_stream_file);
            if (CASE_HAS_PLANE1) begin
                $fwrite(summary_fd, "actual_rvo_plane0=%0s\n", stream_plane0_file);
                $fwrite(summary_fd, "expected_rvo_plane0=%0s\n", expected_stream_plane0_file);
                $fwrite(summary_fd, "actual_rvo_plane1=%0s\n", stream_plane1_file);
                $fwrite(summary_fd, "expected_rvo_plane1=%0s\n", expected_stream_plane1_file);
            end
            $fwrite(summary_fd, "compressed_tile_in=compressed_tile_in.txt\n");
            $fwrite(summary_fd, "vivo_ci_rgba8888=vivo_ci_rgba8888.txt\n");
            $fwrite(summary_fd, "vivo_cvi_rgba8888=vivo_cvi_rgba8888.txt\n");
            $fwrite(summary_fd, "vivo_rvo_rgba8888=vivo_rvo_rgba8888.txt\n");
            $fwrite(summary_fd, "vivo_ci_rgba1010102=vivo_ci_rgba1010102.txt\n");
            $fwrite(summary_fd, "vivo_cvi_rgba1010102=vivo_cvi_rgba1010102.txt\n");
            $fwrite(summary_fd, "vivo_rvo_rgba1010102=vivo_rvo_rgba1010102.txt\n");
            $fwrite(summary_fd, "vivo_ci_nv12_y=vivo_ci_nv12_y.txt\n");
            $fwrite(summary_fd, "vivo_cvi_nv12_y=vivo_cvi_nv12_y.txt\n");
            $fwrite(summary_fd, "vivo_rvo_nv12_y=vivo_rvo_nv12_y.txt\n");
            $fwrite(summary_fd, "vivo_ci_nv12_uv=vivo_ci_nv12_uv.txt\n");
            $fwrite(summary_fd, "vivo_cvi_nv12_uv=vivo_cvi_nv12_uv.txt\n");
            $fwrite(summary_fd, "vivo_rvo_nv12_uv=vivo_rvo_nv12_uv.txt\n");
            $fwrite(summary_fd, "vivo_ci_p010_y=vivo_ci_p010_y.txt\n");
            $fwrite(summary_fd, "vivo_cvi_p010_y=vivo_cvi_p010_y.txt\n");
            $fwrite(summary_fd, "vivo_rvo_p010_y=vivo_rvo_p010_y.txt\n");
            $fwrite(summary_fd, "vivo_ci_p010_uv=vivo_ci_p010_uv.txt\n");
            $fwrite(summary_fd, "vivo_cvi_p010_uv=vivo_cvi_p010_uv.txt\n");
            $fwrite(summary_fd, "vivo_rvo_p010_uv=vivo_rvo_p010_uv.txt\n");
            $fwrite(summary_fd, "actual_dec_meta=%0s\n", dec_meta_actual_file);
            $fwrite(summary_fd, "expected_dec_meta=%0s\n", dec_meta_expected_file);
            $fwrite(summary_fd, "fc_sc_events=%0s\n", fc_sc_event_file);
            $fwrite(summary_fd, "actual_otf=actual_otf_stream.txt\n");
            $fwrite(summary_fd, "expected_otf=expected_otf_stream.txt\n");
            $fwrite(summary_fd, "frame_repeat=%0d\n", tb_frame_repeat);
            $fwrite(summary_fd, "meta_ar_cnt=%0d\n", meta_ar_cnt);
            $fwrite(summary_fd, "tile_ar_cnt=%0d\n", tile_ar_cnt);
            $fwrite(summary_fd, "ci_accept_cnt=%0d\n", ci_accept_cnt);
            $fwrite(summary_fd, "dec_meta_out_cnt=%0d\n", dec_meta_out_cnt);
            $fwrite(summary_fd, "dec_meta_mismatch_cnt=%0d\n", dec_meta_mismatch_cnt);
            $fwrite(summary_fd, "vivo_ci_mismatch_cnt=%0d\n", vivo_ci_mismatch_cnt);
            $fwrite(summary_fd, "vivo_cvi_data_mismatch_cnt=%0d\n", vivo_cvi_data_mismatch_cnt);
            $fwrite(summary_fd, "vivo_cvi_last_mismatch_cnt=%0d\n", vivo_cvi_last_mismatch_cnt);
            $fwrite(summary_fd, "vivo_if_ci_accept_cnt=%0d\n", vivo_if_ci_accept_cnt);
            $fwrite(summary_fd, "vivo_if_cvi_beat_cnt=%0d\n", vivo_if_cvi_beat_cnt);
            $fwrite(summary_fd, "vivo_if_cvi_last_cnt=%0d\n", vivo_if_cvi_last_cnt);
            $fwrite(summary_fd, "vivo_if_rvo_beat_cnt=%0d\n", vivo_if_rvo_beat_cnt);
            $fwrite(summary_fd, "vivo_if_rvo_last_cnt=%0d\n", vivo_if_rvo_last_cnt);
            $fwrite(summary_fd, "vivo_if_ci_mismatch_cnt=%0d\n", vivo_if_ci_mismatch_cnt);
            $fwrite(summary_fd, "vivo_if_cvi_underflow_cnt=%0d\n", vivo_if_cvi_underflow_cnt);
            $fwrite(summary_fd, "vivo_if_cvi_data_mismatch_cnt=%0d\n", vivo_if_cvi_data_mismatch_cnt);
            $fwrite(summary_fd, "vivo_if_cvi_last_mismatch_cnt=%0d\n", vivo_if_cvi_last_mismatch_cnt);
            $fwrite(summary_fd, "vivo_if_rvo_underflow_cnt=%0d\n", vivo_if_rvo_underflow_cnt);
            $fwrite(summary_fd, "vivo_if_rvo_data_mismatch_cnt=%0d\n", vivo_if_rvo_data_mismatch_cnt);
            $fwrite(summary_fd, "vivo_if_rvo_last_mismatch_cnt=%0d\n", vivo_if_rvo_last_mismatch_cnt);
            $fwrite(summary_fd, "fake_ci_fifo_wr_cnt=%0d\n", fake_ci_fifo_wr_cnt);
            $fwrite(summary_fd, "fake_ci_fifo_rd_cnt=%0d\n", fake_ci_fifo_rd_cnt);
            $fwrite(summary_fd, "compressed_tile_hs_cnt=%0d\n", compressed_tile_hs_cnt);
            $fwrite(summary_fd, "compressed_tile_last_cnt=%0d\n", compressed_tile_last_cnt);
            $fwrite(summary_fd, "vivo_dump_ci_counts=%0d,%0d,%0d,%0d,%0d,%0d\n",
                    vivo_ci_dump_cnt[0], vivo_ci_dump_cnt[1], vivo_ci_dump_cnt[2],
                    vivo_ci_dump_cnt[3], vivo_ci_dump_cnt[4], vivo_ci_dump_cnt[5]);
            $fwrite(summary_fd, "vivo_dump_cvi_counts=%0d,%0d,%0d,%0d,%0d,%0d\n",
                    vivo_cvi_dump_cnt[0], vivo_cvi_dump_cnt[1], vivo_cvi_dump_cnt[2],
                    vivo_cvi_dump_cnt[3], vivo_cvi_dump_cnt[4], vivo_cvi_dump_cnt[5]);
            $fwrite(summary_fd, "vivo_dump_rvo_counts=%0d,%0d,%0d,%0d,%0d,%0d\n",
                    vivo_rvo_dump_cnt[0], vivo_rvo_dump_cnt[1], vivo_rvo_dump_cnt[2],
                    vivo_rvo_dump_cnt[3], vivo_rvo_dump_cnt[4], vivo_rvo_dump_cnt[5]);
            $fwrite(summary_fd, "axi_rdata_cccc_cnt=%0d\n", axi_rdata_cccc_cnt);
            $fwrite(summary_fd, "axi_rdata_cccc_meta_cnt=%0d\n", axi_rdata_cccc_meta_cnt);
            $fwrite(summary_fd, "axi_rdata_cccc_tile_cnt=%0d\n", axi_rdata_cccc_tile_cnt);
            $fwrite(summary_fd, "rvo_beat_cnt=%0d\n", rvo_beat_cnt);
            $fwrite(summary_fd, "rvo_last_cnt=%0d\n", rvo_last_cnt);
            $fwrite(summary_fd, "rvo_data_mismatch_cnt=%0d\n", rvo_data_mismatch_cnt);
            $fwrite(summary_fd, "rvo_last_mismatch_cnt=%0d\n", rvo_last_mismatch_cnt);
            $fwrite(summary_fd, "otf_beat_cnt=%0d\n", otf_beat_cnt);
            $fwrite(summary_fd, "otf_frame_done_count=%0d\n", otf_frame_done_count);
            $fwrite(summary_fd, "otf_mismatch_cnt=%0d\n", otf_mismatch_cnt);
            if (first_axi_rdata_cccc_cycle >= 0) begin
                $fwrite(summary_fd, "first_axi_rdata_cccc=cycle:%0d owner:%0s addr:%016h lane:%0d\n",
                        first_axi_rdata_cccc_cycle,
                        first_axi_rdata_cccc_is_meta ? "meta" : "tile",
                        first_axi_rdata_cccc_addr,
                        first_axi_rdata_cccc_lane);
                $fwrite(summary_fd, "first_axi_rdata_cccc_data=%064h\n", first_axi_rdata_cccc_data);
            end
            if ((rvo_data_mismatch_cnt != 0) || (rvo_last_mismatch_cnt != 0)) begin
                $fwrite(summary_fd, "first_rvo_mismatch=fmt:%0d x:%0d y:%0d beat:%0d alen:%0d last:%0d\n",
                        first_rvo_mismatch_fmt, first_rvo_mismatch_x, first_rvo_mismatch_y,
                        first_rvo_mismatch_beat, first_rvo_expected_alen, first_rvo_actual_last);
                $fwrite(summary_fd, "first_rvo_expected=%064h\n", first_rvo_expected_data);
                $fwrite(summary_fd, "first_rvo_actual=%064h\n", first_rvo_actual_data);
            end
            if (dec_meta_mismatch_cnt != 0) begin
                $fwrite(summary_fd, "first_dec_meta_mismatch=idx:%0d exp_raw:%02h act_raw:%02h exp_fmt:%0d act_fmt:%0d exp_flag:%0h act_flag:%0h exp_alen:%0d act_alen:%0d exp_x:%0d act_x:%0d exp_y:%0d act_y:%0d\n",
                        first_dec_meta_mismatch_idx,
                        first_dec_meta_expected_raw, first_dec_meta_actual_raw,
                        first_dec_meta_expected_format, first_dec_meta_actual_format,
                        first_dec_meta_expected_flag, first_dec_meta_actual_flag,
                        first_dec_meta_expected_alen, first_dec_meta_actual_alen,
                        first_dec_meta_expected_x, first_dec_meta_actual_x,
                        first_dec_meta_expected_y, first_dec_meta_actual_y);
            end
            if (otf_mismatch_cnt != 0) begin
                $fwrite(summary_fd, "first_otf_mismatch=beat:%0d x:%0d y:%0d\n",
                        first_otf_mismatch_beat, first_otf_mismatch_x, first_otf_mismatch_y);
                $fwrite(summary_fd, "first_otf_expected=%032h\n", first_otf_expected_data);
                $fwrite(summary_fd, "first_otf_actual=%032h\n", first_otf_actual_data);
            end
        end

        if (stream_fd != 0) begin
            $fclose(stream_fd);
        end
        if (expected_stream_fd != 0) begin
            $fclose(expected_stream_fd);
        end
        if (stream_plane0_fd != 0) begin
            $fclose(stream_plane0_fd);
        end
        if (expected_stream_plane0_fd != 0) begin
            $fclose(expected_stream_plane0_fd);
        end
        if (stream_plane1_fd != 0) begin
            $fclose(stream_plane1_fd);
        end
        if (expected_stream_plane1_fd != 0) begin
            $fclose(expected_stream_plane1_fd);
        end
        if (otf_fd != 0) begin
            $fclose(otf_fd);
        end
        if (compressed_tile_in_fd != 0) begin
            $fclose(compressed_tile_in_fd);
        end
        if (dec_meta_actual_fd != 0) begin
            $fclose(dec_meta_actual_fd);
        end
        if (dec_meta_expected_fd != 0) begin
            $fclose(dec_meta_expected_fd);
        end
        if (fc_sc_event_fd != 0) begin
            $fclose(fc_sc_event_fd);
        end
        close_vivo_dump_files();
        if (summary_fd != 0) begin
            $fclose(summary_fd);
        end

        if (fail_check_cnt == 0) begin
            $display("PASS: wrapper_top %0s path checks passed and OTF matches linear golden.",
                     (TB_REAL_VIVO_MODE != 0) ? "real" : "fake");
        end else begin
            $display("FAIL: wrapper_top %0s completed with %0d check failures. dumps and summary were still written.",
                     (TB_REAL_VIVO_MODE != 0) ? "real" : "fake", fail_check_cnt);
        end
        $finish;
    end

    initial begin
`ifdef WAVES
        if (!$test$plusargs("tb_no_wave")) begin
`ifdef FSDB
            case (CASE_ID)
                CASE_RGBA1010102: $fsdbDumpfile("tb_ubwc_dec_wrapper_top_tajmahal_rgba1010102.fsdb");
                CASE_NV12:        $fsdbDumpfile("tb_ubwc_dec_wrapper_top_tajmahal_nv12.fsdb");
                CASE_G016:        $fsdbDumpfile("tb_ubwc_dec_wrapper_top_k_outdoor61_g016.fsdb");
                default:          $fsdbDumpfile("tb_ubwc_dec_wrapper_top_tajmahal_rgba8888.fsdb");
            endcase
            $fsdbDumpvars(0, tb_ubwc_dec_wrapper_top_tajmahal_core);
            $fsdbDumpMDA(0, tb_ubwc_dec_wrapper_top_tajmahal_core);
`else
            case (CASE_ID)
                CASE_RGBA1010102: $dumpfile("tb_ubwc_dec_wrapper_top_tajmahal_rgba1010102.vcd");
                CASE_NV12:        $dumpfile("tb_ubwc_dec_wrapper_top_tajmahal_nv12.vcd");
                CASE_G016:        $dumpfile("tb_ubwc_dec_wrapper_top_k_outdoor61_g016.vcd");
                default:          $dumpfile("tb_ubwc_dec_wrapper_top_tajmahal_rgba8888.vcd");
            endcase
            $dumpvars(0, tb_ubwc_dec_wrapper_top_tajmahal_core);
`endif
        end
`endif
    end

endmodule

module tb_ubwc_dec_wrapper_top_tajmahal_cases #(
    parameter integer CASE_ID = 0,
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0,
    parameter integer LOOP_TO_ENC = 0,
    parameter integer COM_BUF_AW = 12,
    parameter integer CASE_TILE_EXPECT_LINEAR = 0,
    parameter integer IMG_W = 4096,
    parameter integer RGBA_ACTIVE_H = 600,
    parameter integer RGBA_STORED_H = 608,
    parameter integer RGBA_TILE_X_COUNT = 256,
    parameter integer RGBA_TILE_Y_COUNT = 152,
    parameter integer RGBA_META_PITCH = 256,
    parameter integer RGBA_META_LINES = 160,
    parameter integer RGBA_META_WORDS64 = 0,
    parameter integer RGBA_TILE_PITCH = 16384,
    parameter integer CFG_NV12_ACTIVE_H = 600,
    parameter integer CFG_NV12_Y_STORED_H = 640,
    parameter integer CFG_NV12_UV_STORED_H = 320,
    parameter integer CFG_NV12_TILE_X_COUNT = 128,
    parameter integer CFG_NV12_Y_TILE_Y_COUNT = 80,
    parameter integer CFG_NV12_UV_TILE_Y_COUNT = 40,
    parameter integer CFG_NV12_META_PITCH = 128,
    parameter integer CFG_NV12_META_Y_LINES = 96,
    parameter integer CFG_NV12_META_UV_LINES = 64,
    parameter integer CFG_NV12_TILE_PITCH = 4096,
    parameter integer CFG_NV12_COMP_Y_WORDS64 = 311296,
    parameter integer CFG_NV12_COMP_UV_WORDS64 = 163840,
    parameter integer CFG_NV12_UNCOMP_Y_WORDS64 = 327680,
    parameter integer CFG_NV12_UNCOMP_UV_WORDS64 = 163840,
    parameter integer CFG_G016_ACTIVE_H = 600,
    parameter integer CFG_G016_Y_STORED_H = 608,
    parameter integer CFG_G016_UV_STORED_H = 304,
    parameter integer CFG_G016_TILE_X_COUNT = 128,
    parameter integer CFG_G016_Y_TILE_Y_COUNT = 152,
    parameter integer CFG_G016_UV_TILE_Y_COUNT = 76,
    parameter integer CFG_G016_META_PITCH = 128,
    parameter integer CFG_G016_META_Y_LINES = 160,
    parameter integer CFG_G016_META_UV_LINES = 96,
    parameter integer CFG_G016_TILE_PITCH = 8192,
    parameter integer CFG_G016_COMP_Y_WORDS64 = 622592,
    parameter integer CFG_G016_COMP_UV_WORDS64 = 311296,
    parameter integer CFG_G016_UNCOMP_Y_WORDS64 = 622592,
    parameter integer CFG_G016_UNCOMP_UV_WORDS64 = 311296,
    parameter [63:0] CFG_RGBA_TILE_BASE_Y_ADDR = 64'h0000_0000_0028_5000,
    parameter [63:0] CFG_RGBA_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_NV12_TILE_BASE_Y_ADDR = 64'h0000_0000_0000_3000,
    parameter [63:0] CFG_NV12_TILE_BASE_UV_ADDR = 64'h0000_0000_0028_5000,
    parameter [63:0] CFG_NV12_DUMP_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_3000,
    parameter [63:0] CFG_NV12_DUMP_TILE_BASE_UV_ADDR = 64'h0000_0000_8028_5000,
    parameter [63:0] CFG_NV12_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_NV12_META_BASE_UV_ADDR = 64'h0000_0000_8028_3000,
    parameter [63:0] CFG_G016_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_5000,
    parameter [63:0] CFG_G016_TILE_BASE_UV_ADDR = 64'h0000_0000_804c_8000,
    parameter [63:0] CFG_G016_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_G016_META_BASE_UV_ADDR = 64'h0000_0000_804c_5000,
    parameter integer CASE_OTF_H_TOTAL = 4400,
    parameter integer CASE_OTF_H_SYNC = 44,
    parameter integer CASE_OTF_H_BP = 148,
    parameter integer CFG_OTF_V_TOTAL = 682,
    parameter integer CFG_OTF_V_SYNC = 5,
    parameter integer CFG_OTF_V_BP = 36,
    parameter integer CASE_DEC_ROTATION = 0,
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
);
    tb_ubwc_dec_wrapper_top_tajmahal_core #(
        .CASE_ID (CASE_ID),
        .TB_REAL_VIVO_MODE (TB_REAL_VIVO_MODE),
        .FORCE_FULL_PAYLOAD_CASE (FORCE_FULL_PAYLOAD_CASE),
        .LOOP_TO_ENC (LOOP_TO_ENC),
        .COM_BUF_AW (COM_BUF_AW),
        .CASE_TILE_EXPECT_LINEAR (CASE_TILE_EXPECT_LINEAR),
        .IMG_W (IMG_W),
        .RGBA_ACTIVE_H (RGBA_ACTIVE_H),
        .RGBA_STORED_H (RGBA_STORED_H),
        .RGBA_TILE_X_COUNT (RGBA_TILE_X_COUNT),
        .RGBA_TILE_Y_COUNT (RGBA_TILE_Y_COUNT),
        .RGBA_META_PITCH (RGBA_META_PITCH),
        .RGBA_META_LINES (RGBA_META_LINES),
        .RGBA_META_WORDS64 (RGBA_META_WORDS64),
        .RGBA_TILE_PITCH (RGBA_TILE_PITCH),
        .CFG_NV12_ACTIVE_H (CFG_NV12_ACTIVE_H),
        .CFG_NV12_Y_STORED_H (CFG_NV12_Y_STORED_H),
        .CFG_NV12_UV_STORED_H (CFG_NV12_UV_STORED_H),
        .CFG_NV12_TILE_X_COUNT (CFG_NV12_TILE_X_COUNT),
        .CFG_NV12_Y_TILE_Y_COUNT (CFG_NV12_Y_TILE_Y_COUNT),
        .CFG_NV12_UV_TILE_Y_COUNT (CFG_NV12_UV_TILE_Y_COUNT),
        .CFG_NV12_META_PITCH (CFG_NV12_META_PITCH),
        .CFG_NV12_META_Y_LINES (CFG_NV12_META_Y_LINES),
        .CFG_NV12_META_UV_LINES (CFG_NV12_META_UV_LINES),
        .CFG_NV12_TILE_PITCH (CFG_NV12_TILE_PITCH),
        .CFG_NV12_COMP_Y_WORDS64 (CFG_NV12_COMP_Y_WORDS64),
        .CFG_NV12_COMP_UV_WORDS64 (CFG_NV12_COMP_UV_WORDS64),
        .CFG_NV12_UNCOMP_Y_WORDS64 (CFG_NV12_UNCOMP_Y_WORDS64),
        .CFG_NV12_UNCOMP_UV_WORDS64 (CFG_NV12_UNCOMP_UV_WORDS64),
        .CFG_G016_ACTIVE_H (CFG_G016_ACTIVE_H),
        .CFG_G016_Y_STORED_H (CFG_G016_Y_STORED_H),
        .CFG_G016_UV_STORED_H (CFG_G016_UV_STORED_H),
        .CFG_G016_TILE_X_COUNT (CFG_G016_TILE_X_COUNT),
        .CFG_G016_Y_TILE_Y_COUNT (CFG_G016_Y_TILE_Y_COUNT),
        .CFG_G016_UV_TILE_Y_COUNT (CFG_G016_UV_TILE_Y_COUNT),
        .CFG_G016_META_PITCH (CFG_G016_META_PITCH),
        .CFG_G016_META_Y_LINES (CFG_G016_META_Y_LINES),
        .CFG_G016_META_UV_LINES (CFG_G016_META_UV_LINES),
        .CFG_G016_TILE_PITCH (CFG_G016_TILE_PITCH),
        .CFG_G016_COMP_Y_WORDS64 (CFG_G016_COMP_Y_WORDS64),
        .CFG_G016_COMP_UV_WORDS64 (CFG_G016_COMP_UV_WORDS64),
        .CFG_G016_UNCOMP_Y_WORDS64 (CFG_G016_UNCOMP_Y_WORDS64),
        .CFG_G016_UNCOMP_UV_WORDS64 (CFG_G016_UNCOMP_UV_WORDS64),
        .CFG_RGBA_TILE_BASE_Y_ADDR (CFG_RGBA_TILE_BASE_Y_ADDR),
        .CFG_RGBA_META_BASE_Y_ADDR (CFG_RGBA_META_BASE_Y_ADDR),
        .CFG_NV12_TILE_BASE_Y_ADDR (CFG_NV12_TILE_BASE_Y_ADDR),
        .CFG_NV12_TILE_BASE_UV_ADDR (CFG_NV12_TILE_BASE_UV_ADDR),
        .CFG_NV12_DUMP_TILE_BASE_Y_ADDR (CFG_NV12_DUMP_TILE_BASE_Y_ADDR),
        .CFG_NV12_DUMP_TILE_BASE_UV_ADDR (CFG_NV12_DUMP_TILE_BASE_UV_ADDR),
        .CFG_NV12_META_BASE_Y_ADDR (CFG_NV12_META_BASE_Y_ADDR),
        .CFG_NV12_META_BASE_UV_ADDR (CFG_NV12_META_BASE_UV_ADDR),
        .CFG_G016_TILE_BASE_Y_ADDR (CFG_G016_TILE_BASE_Y_ADDR),
        .CFG_G016_TILE_BASE_UV_ADDR (CFG_G016_TILE_BASE_UV_ADDR),
        .CFG_G016_META_BASE_Y_ADDR (CFG_G016_META_BASE_Y_ADDR),
        .CFG_G016_META_BASE_UV_ADDR (CFG_G016_META_BASE_UV_ADDR),
        .CASE_OTF_H_TOTAL (CASE_OTF_H_TOTAL),
        .CASE_OTF_H_SYNC (CASE_OTF_H_SYNC),
        .CASE_OTF_H_BP (CASE_OTF_H_BP),
        .CFG_OTF_V_TOTAL (CFG_OTF_V_TOTAL),
        .CFG_OTF_V_SYNC (CFG_OTF_V_SYNC),
        .CFG_OTF_V_BP (CFG_OTF_V_BP),
        .CASE_DEC_ROTATION (CASE_DEC_ROTATION),
        .CASE_CI_LOSSY (CASE_CI_LOSSY),
        .CASE_UBWC_CFG_0 (CASE_UBWC_CFG_0),
        .CASE_UBWC_CFG_1 (CASE_UBWC_CFG_1),
        .CASE_UBWC_CFG_2 (CASE_UBWC_CFG_2),
        .CASE_UBWC_CFG_3 (CASE_UBWC_CFG_3),
        .CASE_UBWC_CFG_4 (CASE_UBWC_CFG_4),
        .CASE_UBWC_CFG_5 (CASE_UBWC_CFG_5),
        .CASE_UBWC_CFG_6 (CASE_UBWC_CFG_6),
        .CASE_UBWC_CFG_7 (CASE_UBWC_CFG_7),
        .CASE_UBWC_CFG_8 (CASE_UBWC_CFG_8),
        .CASE_UBWC_CFG_9 (CASE_UBWC_CFG_9),
        .CASE_UBWC_CFG_10 (CASE_UBWC_CFG_10),
        .CASE_UBWC_CFG_11 (CASE_UBWC_CFG_11)
    ) u_core ();
endmodule

module tb_ubwc_dec_to_enc_loop_tajmahal_cases #(
    parameter integer CASE_ID = 0,
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0,
    parameter integer COM_BUF_AW = 12,
    parameter integer CASE_TILE_EXPECT_LINEAR = 0,
    parameter integer IMG_W = 4096,
    parameter integer RGBA_ACTIVE_H = 600,
    parameter integer RGBA_STORED_H = 608,
    parameter integer RGBA_TILE_X_COUNT = 256,
    parameter integer RGBA_TILE_Y_COUNT = 152,
    parameter integer RGBA_META_PITCH = 256,
    parameter integer RGBA_META_LINES = 160,
    parameter integer RGBA_META_WORDS64 = 0,
    parameter integer RGBA_TILE_PITCH = 16384,
    parameter integer CFG_NV12_ACTIVE_H = 600,
    parameter integer CFG_NV12_Y_STORED_H = 640,
    parameter integer CFG_NV12_UV_STORED_H = 320,
    parameter integer CFG_NV12_TILE_X_COUNT = 128,
    parameter integer CFG_NV12_Y_TILE_Y_COUNT = 80,
    parameter integer CFG_NV12_UV_TILE_Y_COUNT = 40,
    parameter integer CFG_NV12_META_PITCH = 128,
    parameter integer CFG_NV12_META_Y_LINES = 96,
    parameter integer CFG_NV12_META_UV_LINES = 64,
    parameter integer CFG_NV12_TILE_PITCH = 4096,
    parameter integer CFG_NV12_COMP_Y_WORDS64 = 311296,
    parameter integer CFG_NV12_COMP_UV_WORDS64 = 163840,
    parameter integer CFG_NV12_UNCOMP_Y_WORDS64 = 327680,
    parameter integer CFG_NV12_UNCOMP_UV_WORDS64 = 163840,
    parameter integer CFG_G016_ACTIVE_H = 600,
    parameter integer CFG_G016_Y_STORED_H = 608,
    parameter integer CFG_G016_UV_STORED_H = 304,
    parameter integer CFG_G016_TILE_X_COUNT = 128,
    parameter integer CFG_G016_Y_TILE_Y_COUNT = 152,
    parameter integer CFG_G016_UV_TILE_Y_COUNT = 76,
    parameter integer CFG_G016_META_PITCH = 128,
    parameter integer CFG_G016_META_Y_LINES = 160,
    parameter integer CFG_G016_META_UV_LINES = 96,
    parameter integer CFG_G016_TILE_PITCH = 8192,
    parameter integer CFG_G016_COMP_Y_WORDS64 = 622592,
    parameter integer CFG_G016_COMP_UV_WORDS64 = 311296,
    parameter integer CFG_G016_UNCOMP_Y_WORDS64 = 622592,
    parameter integer CFG_G016_UNCOMP_UV_WORDS64 = 311296,
    parameter [63:0] CFG_RGBA_TILE_BASE_Y_ADDR = 64'h0000_0000_0028_5000,
    parameter [63:0] CFG_RGBA_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_NV12_TILE_BASE_Y_ADDR = 64'h0000_0000_0000_3000,
    parameter [63:0] CFG_NV12_TILE_BASE_UV_ADDR = 64'h0000_0000_0028_5000,
    parameter [63:0] CFG_NV12_DUMP_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_3000,
    parameter [63:0] CFG_NV12_DUMP_TILE_BASE_UV_ADDR = 64'h0000_0000_8028_5000,
    parameter [63:0] CFG_NV12_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_NV12_META_BASE_UV_ADDR = 64'h0000_0000_8028_3000,
    parameter [63:0] CFG_G016_TILE_BASE_Y_ADDR = 64'h0000_0000_8000_5000,
    parameter [63:0] CFG_G016_TILE_BASE_UV_ADDR = 64'h0000_0000_804c_8000,
    parameter [63:0] CFG_G016_META_BASE_Y_ADDR = 64'h0000_0000_8000_0000,
    parameter [63:0] CFG_G016_META_BASE_UV_ADDR = 64'h0000_0000_804c_5000,
    parameter integer CASE_OTF_H_TOTAL = 4400,
    parameter integer CASE_OTF_H_SYNC = 44,
    parameter integer CASE_OTF_H_BP = 148,
    parameter integer CFG_OTF_V_TOTAL = 682,
    parameter integer CFG_OTF_V_SYNC = 5,
    parameter integer CFG_OTF_V_BP = 36,
    parameter integer CASE_DEC_ROTATION = 0,
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
);
    tb_ubwc_dec_wrapper_top_tajmahal_cases #(
        .CASE_ID (CASE_ID),
        .TB_REAL_VIVO_MODE (TB_REAL_VIVO_MODE),
        .FORCE_FULL_PAYLOAD_CASE (FORCE_FULL_PAYLOAD_CASE),
        .LOOP_TO_ENC (1),
        .COM_BUF_AW (COM_BUF_AW),
        .CASE_TILE_EXPECT_LINEAR (CASE_TILE_EXPECT_LINEAR),
        .IMG_W (IMG_W),
        .RGBA_ACTIVE_H (RGBA_ACTIVE_H),
        .RGBA_STORED_H (RGBA_STORED_H),
        .RGBA_TILE_X_COUNT (RGBA_TILE_X_COUNT),
        .RGBA_TILE_Y_COUNT (RGBA_TILE_Y_COUNT),
        .RGBA_META_PITCH (RGBA_META_PITCH),
        .RGBA_META_LINES (RGBA_META_LINES),
        .RGBA_META_WORDS64 (RGBA_META_WORDS64),
        .RGBA_TILE_PITCH (RGBA_TILE_PITCH),
        .CFG_NV12_ACTIVE_H (CFG_NV12_ACTIVE_H),
        .CFG_NV12_Y_STORED_H (CFG_NV12_Y_STORED_H),
        .CFG_NV12_UV_STORED_H (CFG_NV12_UV_STORED_H),
        .CFG_NV12_TILE_X_COUNT (CFG_NV12_TILE_X_COUNT),
        .CFG_NV12_Y_TILE_Y_COUNT (CFG_NV12_Y_TILE_Y_COUNT),
        .CFG_NV12_UV_TILE_Y_COUNT (CFG_NV12_UV_TILE_Y_COUNT),
        .CFG_NV12_META_PITCH (CFG_NV12_META_PITCH),
        .CFG_NV12_META_Y_LINES (CFG_NV12_META_Y_LINES),
        .CFG_NV12_META_UV_LINES (CFG_NV12_META_UV_LINES),
        .CFG_NV12_TILE_PITCH (CFG_NV12_TILE_PITCH),
        .CFG_NV12_COMP_Y_WORDS64 (CFG_NV12_COMP_Y_WORDS64),
        .CFG_NV12_COMP_UV_WORDS64 (CFG_NV12_COMP_UV_WORDS64),
        .CFG_NV12_UNCOMP_Y_WORDS64 (CFG_NV12_UNCOMP_Y_WORDS64),
        .CFG_NV12_UNCOMP_UV_WORDS64 (CFG_NV12_UNCOMP_UV_WORDS64),
        .CFG_G016_ACTIVE_H (CFG_G016_ACTIVE_H),
        .CFG_G016_Y_STORED_H (CFG_G016_Y_STORED_H),
        .CFG_G016_UV_STORED_H (CFG_G016_UV_STORED_H),
        .CFG_G016_TILE_X_COUNT (CFG_G016_TILE_X_COUNT),
        .CFG_G016_Y_TILE_Y_COUNT (CFG_G016_Y_TILE_Y_COUNT),
        .CFG_G016_UV_TILE_Y_COUNT (CFG_G016_UV_TILE_Y_COUNT),
        .CFG_G016_META_PITCH (CFG_G016_META_PITCH),
        .CFG_G016_META_Y_LINES (CFG_G016_META_Y_LINES),
        .CFG_G016_META_UV_LINES (CFG_G016_META_UV_LINES),
        .CFG_G016_TILE_PITCH (CFG_G016_TILE_PITCH),
        .CFG_G016_COMP_Y_WORDS64 (CFG_G016_COMP_Y_WORDS64),
        .CFG_G016_COMP_UV_WORDS64 (CFG_G016_COMP_UV_WORDS64),
        .CFG_G016_UNCOMP_Y_WORDS64 (CFG_G016_UNCOMP_Y_WORDS64),
        .CFG_G016_UNCOMP_UV_WORDS64 (CFG_G016_UNCOMP_UV_WORDS64),
        .CFG_RGBA_TILE_BASE_Y_ADDR (CFG_RGBA_TILE_BASE_Y_ADDR),
        .CFG_RGBA_META_BASE_Y_ADDR (CFG_RGBA_META_BASE_Y_ADDR),
        .CFG_NV12_TILE_BASE_Y_ADDR (CFG_NV12_TILE_BASE_Y_ADDR),
        .CFG_NV12_TILE_BASE_UV_ADDR (CFG_NV12_TILE_BASE_UV_ADDR),
        .CFG_NV12_DUMP_TILE_BASE_Y_ADDR (CFG_NV12_DUMP_TILE_BASE_Y_ADDR),
        .CFG_NV12_DUMP_TILE_BASE_UV_ADDR (CFG_NV12_DUMP_TILE_BASE_UV_ADDR),
        .CFG_NV12_META_BASE_Y_ADDR (CFG_NV12_META_BASE_Y_ADDR),
        .CFG_NV12_META_BASE_UV_ADDR (CFG_NV12_META_BASE_UV_ADDR),
        .CFG_G016_TILE_BASE_Y_ADDR (CFG_G016_TILE_BASE_Y_ADDR),
        .CFG_G016_TILE_BASE_UV_ADDR (CFG_G016_TILE_BASE_UV_ADDR),
        .CFG_G016_META_BASE_Y_ADDR (CFG_G016_META_BASE_Y_ADDR),
        .CFG_G016_META_BASE_UV_ADDR (CFG_G016_META_BASE_UV_ADDR),
        .CASE_OTF_H_TOTAL (CASE_OTF_H_TOTAL),
        .CASE_OTF_H_SYNC (CASE_OTF_H_SYNC),
        .CASE_OTF_H_BP (CASE_OTF_H_BP),
        .CFG_OTF_V_TOTAL (CFG_OTF_V_TOTAL),
        .CFG_OTF_V_SYNC (CFG_OTF_V_SYNC),
        .CFG_OTF_V_BP (CFG_OTF_V_BP),
        .CASE_DEC_ROTATION (CASE_DEC_ROTATION),
        .CASE_CI_LOSSY (CASE_CI_LOSSY),
        .CASE_UBWC_CFG_0 (CASE_UBWC_CFG_0),
        .CASE_UBWC_CFG_1 (CASE_UBWC_CFG_1),
        .CASE_UBWC_CFG_2 (CASE_UBWC_CFG_2),
        .CASE_UBWC_CFG_3 (CASE_UBWC_CFG_3),
        .CASE_UBWC_CFG_4 (CASE_UBWC_CFG_4),
        .CASE_UBWC_CFG_5 (CASE_UBWC_CFG_5),
        .CASE_UBWC_CFG_6 (CASE_UBWC_CFG_6),
        .CASE_UBWC_CFG_7 (CASE_UBWC_CFG_7),
        .CASE_UBWC_CFG_8 (CASE_UBWC_CFG_8),
        .CASE_UBWC_CFG_9 (CASE_UBWC_CFG_9),
        .CASE_UBWC_CFG_10 (CASE_UBWC_CFG_10),
        .CASE_UBWC_CFG_11 (CASE_UBWC_CFG_11)
    ) u_loop ();
endmodule

module tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba8888 #(
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0,
    parameter integer COM_BUF_AW = 12
);
    tb_ubwc_dec_wrapper_top_tajmahal_core #(
        .CASE_ID (0),
        .TB_REAL_VIVO_MODE (TB_REAL_VIVO_MODE),
        .FORCE_FULL_PAYLOAD_CASE (FORCE_FULL_PAYLOAD_CASE),
        .COM_BUF_AW (COM_BUF_AW)
    ) u_core ();
endmodule

module tb_ubwc_dec_wrapper_top_rgba8888_128x128 #(
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 1,
    parameter integer COM_BUF_AW = 12
);
    tb_ubwc_dec_wrapper_top_tajmahal_core #(
        .CASE_ID (0),
        .TB_REAL_VIVO_MODE (TB_REAL_VIVO_MODE),
        .FORCE_FULL_PAYLOAD_CASE (FORCE_FULL_PAYLOAD_CASE),
        .COM_BUF_AW (COM_BUF_AW),
        .IMG_W(128),
        .RGBA_ACTIVE_H(128),
        .RGBA_STORED_H(128),
        .RGBA_TILE_X_COUNT(8),
        .RGBA_TILE_Y_COUNT(32),
        .RGBA_META_PITCH(64),
        .RGBA_META_LINES(32),
        .RGBA_TILE_PITCH(512),
        .CASE_OTF_H_TOTAL(160),
        .CASE_OTF_H_SYNC(4),
        .CASE_OTF_H_BP(8)
    ) u_core ();
endmodule

module tb_ubwc_dec_wrapper_top_tajmahal_4096x600_rgba1010102 #(
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0,
    parameter integer COM_BUF_AW = 12
);
    tb_ubwc_dec_wrapper_top_tajmahal_core #(
        .CASE_ID (1),
        .TB_REAL_VIVO_MODE (TB_REAL_VIVO_MODE),
        .FORCE_FULL_PAYLOAD_CASE (FORCE_FULL_PAYLOAD_CASE),
        .COM_BUF_AW (COM_BUF_AW)
    ) u_core ();
endmodule

module tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12 #(
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0,
    parameter integer COM_BUF_AW = 12
);
    tb_ubwc_dec_wrapper_top_tajmahal_core #(
        .CASE_ID (2),
        .TB_REAL_VIVO_MODE (TB_REAL_VIVO_MODE),
        .FORCE_FULL_PAYLOAD_CASE (FORCE_FULL_PAYLOAD_CASE),
        .COM_BUF_AW (COM_BUF_AW)
    ) u_core ();
endmodule

module tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016 #(
    parameter integer TB_REAL_VIVO_MODE = 0,
    parameter integer FORCE_FULL_PAYLOAD_CASE = 0,
    parameter integer COM_BUF_AW = 12
);
    tb_ubwc_dec_wrapper_top_tajmahal_core #(
        .CASE_ID (3),
        .TB_REAL_VIVO_MODE (TB_REAL_VIVO_MODE),
        .FORCE_FULL_PAYLOAD_CASE (FORCE_FULL_PAYLOAD_CASE),
        .COM_BUF_AW (COM_BUF_AW)
    ) u_core ();
endmodule
