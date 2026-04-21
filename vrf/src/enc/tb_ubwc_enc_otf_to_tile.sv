`timescale 1ns/1ps
`default_nettype none

module tb_sync_sram_1rw #(
    parameter ADDR_W = 13,
    parameter DATA_W = 128
) (
    input  wire                  clk,
    input  wire                  en,
    input  wire                  wen,
    input  wire [ADDR_W-1:0]     addr,
    input  wire [DATA_W-1:0]     din,
    output logic [DATA_W-1:0]    dout,
    output logic                 dout_vld
);
    logic [DATA_W-1:0] mem [0:(1<<ADDR_W)-1];
    integer idx;

    task automatic clear_mem;
        begin
            for (idx = 0; idx < (1 << ADDR_W); idx = idx + 1)
                mem[idx] = {DATA_W{1'b0}};
            dout     = {DATA_W{1'b0}};
            dout_vld = 1'b0;
        end
    endtask

    initial begin
        clear_mem();
    end

    always_ff @(posedge clk) begin
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

module tb_ubwc_enc_otf_to_tile #(
    parameter integer ADDR_W              = 13,
    parameter integer FRAME_W             = 4096,
    parameter integer FRAME_H             = 608
) ();
    localparam integer PROC_CLK_PERIOD_NS = 2;
    localparam integer OTF_CLK_PERIOD_NS  = 10;
    localparam integer BEATS_PER_LINE     = FRAME_W / 4;
    localparam integer TILE_COLS          = FRAME_W / 16;

    localparam [2:0] FMT_RGBA8888         = 3'd0;
    localparam [2:0] FMT_YUV420_8         = 3'd2;

    localparam integer RGBA_TILE_H        = 4;
    localparam integer RGBA_TILE_ROWS     = FRAME_H / RGBA_TILE_H;
    localparam integer RGBA_EXPECT_TILES  = TILE_COLS * RGBA_TILE_ROWS;
    localparam integer RGBA_EXPECT_BEATS  = RGBA_EXPECT_TILES * 16;

    localparam integer YUV_TILE_GROUP_H   = 16;
    localparam integer YUV_TILE_ROWS      = FRAME_H / YUV_TILE_GROUP_H;
    localparam integer YUV_EXPECT_TILES   = TILE_COLS * YUV_TILE_ROWS * 2;
    localparam integer YUV_EXPECT_BEATS   = YUV_EXPECT_TILES * 16;
    localparam integer YUV_EXPECT_FMT8    = YUV_EXPECT_BEATS / 2;
    localparam integer YUV_EXPECT_FMT9    = YUV_EXPECT_BEATS / 2;

    logic               clk;
    logic               otf_clk;
    logic               rst_n;

    logic [2:0]         cfg_format;
    logic [15:0]        cfg_width;
    logic [15:0]        cfg_height;
    logic [15:0]        cfg_active_width;
    logic [15:0]        cfg_active_height;
    logic [15:0]        cfg_tile_w;
    logic [3:0]         cfg_tile_h;
    logic [15:0]        cfg_a_tile_cols;
    logic [15:0]        cfg_b_tile_cols;

    logic               otf_vsync;
    logic               otf_hsync;
    logic               otf_de;
    logic [127:0]       otf_data;
    logic [3:0]         otf_fcnt;
    logic [11:0]        otf_lcnt;
    wire                otf_ready;

    wire                bank0_en;
    wire                bank0_wen;
    wire [ADDR_W-1:0]   bank0_addr;
    wire [127:0]        bank0_din;
    wire [127:0]        bank0_dout;
    wire                bank0_dout_vld;

    wire                bank1_en;
    wire                bank1_wen;
    wire [ADDR_W-1:0]   bank1_addr;
    wire [127:0]        bank1_din;
    wire [127:0]        bank1_dout;
    wire                bank1_dout_vld;

    wire                err_bline;
    wire                err_bframe;
    wire                err_fifo_ovf;

    wire                tile_vld;
    logic               tile_rdy;
    wire [255:0]        tile_data;
    wire [31:0]         tile_keep;
    wire                tile_last;
    wire                ci_valid;
    logic               ci_ready;
    wire                ci_forced_pcm;
    wire [15:0]         tile_x;
    wire [15:0]         tile_y;
    wire [3:0]          tile_fcnt;
    wire [4:0]          tile_format;

    integer tile_beat_count;
    integer tile_count;
    integer ci_valid_count;
    integer fmt0_beat_count;
    integer fmt8_beat_count;
    integer fmt9_beat_count;
    integer other_fmt_beat_count;
    integer keep_error_count;
    integer ci_mismatch_count;
    integer upper_data_nonzero_count;
    integer max_tile_x_seen;
    integer max_tile_y_seen;
    integer fail_count;

    ubwc_enc_otf_to_tile #(
        .ADDR_W(ADDR_W)
    ) dut (
        .clk            (clk),
        .i_otf_clk      (otf_clk),
        .rst_n          (rst_n),
        .i_cfg_format   (cfg_format),
        .i_cfg_width    (cfg_width),
        .i_cfg_height   (cfg_height),
        .i_cfg_active_width(cfg_active_width),
        .i_cfg_active_height(cfg_active_height),
        .i_cfg_tile_w   (cfg_tile_w),
        .i_cfg_tile_h   (cfg_tile_h),
        .i_cfg_a_tile_cols(cfg_a_tile_cols),
        .i_cfg_b_tile_cols(cfg_b_tile_cols),
        .o_err_bline    (err_bline),
        .o_err_bframe   (err_bframe),
        .o_err_fifo_ovf (err_fifo_ovf),
        .i_otf_vsync    (otf_vsync),
        .i_otf_hsync    (otf_hsync),
        .i_otf_de       (otf_de),
        .i_otf_data     (otf_data),
        .i_otf_fcnt     (otf_fcnt),
        .i_otf_lcnt     (otf_lcnt),
        .o_otf_ready    (otf_ready),
        .o_bank0_en     (bank0_en),
        .o_bank0_wen    (bank0_wen),
        .o_bank0_addr   (bank0_addr),
        .o_bank0_din    (bank0_din),
        .i_bank0_dout   (bank0_dout),
        .i_bank0_dout_vld(bank0_dout_vld),
        .o_bank1_en     (bank1_en),
        .o_bank1_wen    (bank1_wen),
        .o_bank1_addr   (bank1_addr),
        .o_bank1_din    (bank1_din),
        .i_bank1_dout   (bank1_dout),
        .i_bank1_dout_vld(bank1_dout_vld),
        .o_tile_vld     (tile_vld),
        .i_tile_rdy     (tile_rdy),
        .o_tile_data    (tile_data),
        .o_tile_keep    (tile_keep),
        .o_tile_last    (tile_last),
        .o_ci_valid     (ci_valid),
        .i_ci_ready     (ci_ready),
        .o_ci_forced_pcm(ci_forced_pcm),
        .o_tile_x       (tile_x),
        .o_tile_y       (tile_y),
        .o_tile_fcnt    (tile_fcnt),
        .o_tile_format  (tile_format)
    );

    tb_sync_sram_1rw #(
        .ADDR_W(ADDR_W),
        .DATA_W(128)
    ) u_bank0 (
        .clk        (clk),
        .en         (bank0_en),
        .wen        (bank0_wen),
        .addr       (bank0_addr),
        .din        (bank0_din),
        .dout       (bank0_dout),
        .dout_vld   (bank0_dout_vld)
    );

    tb_sync_sram_1rw #(
        .ADDR_W(ADDR_W),
        .DATA_W(128)
    ) u_bank1 (
        .clk        (clk),
        .en         (bank1_en),
        .wen        (bank1_wen),
        .addr       (bank1_addr),
        .din        (bank1_din),
        .dout       (bank1_dout),
        .dout_vld   (bank1_dout_vld)
    );

    initial clk = 1'b0;
    always #(PROC_CLK_PERIOD_NS/2) clk = ~clk;

    initial otf_clk = 1'b0;
    always #(OTF_CLK_PERIOD_NS/2) otf_clk = ~otf_clk;

    initial begin
        if ($test$plusargs("dump_vcd")) begin
            $dumpfile("tb_ubwc_enc_otf_to_tile.vcd");
            $dumpvars(0, tb_ubwc_enc_otf_to_tile);
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            tile_beat_count         <= 0;
            tile_count              <= 0;
            ci_valid_count          <= 0;
            fmt0_beat_count         <= 0;
            fmt8_beat_count         <= 0;
            fmt9_beat_count         <= 0;
            other_fmt_beat_count    <= 0;
            keep_error_count        <= 0;
            ci_mismatch_count       <= 0;
            upper_data_nonzero_count<= 0;
            max_tile_x_seen         <= 0;
            max_tile_y_seen         <= 0;
        end else if (tile_vld && tile_rdy) begin
            tile_beat_count <= tile_beat_count + 1;
            if (ci_valid)
                ci_valid_count <= ci_valid_count + 1;
            else
                ci_mismatch_count <= ci_mismatch_count + 1;

            if (tile_last)
                tile_count <= tile_count + 1;

            if (tile_keep != 32'h0000_FFFF)
                keep_error_count <= keep_error_count + 1;

            if (tile_data[255:128] != 128'd0)
                upper_data_nonzero_count <= upper_data_nonzero_count + 1;

            if (tile_x > max_tile_x_seen[15:0])
                max_tile_x_seen <= tile_x;

            if (tile_y > max_tile_y_seen[15:0])
                max_tile_y_seen <= tile_y;

            case (tile_format)
                5'd0: fmt0_beat_count      <= fmt0_beat_count + 1;
                5'd8: fmt8_beat_count      <= fmt8_beat_count + 1;
                5'd9: fmt9_beat_count      <= fmt9_beat_count + 1;
                default: other_fmt_beat_count <= other_fmt_beat_count + 1;
            endcase
        end
    end

    function automatic [127:0] make_rgba_beat;
        input integer line_idx;
        input integer beat_idx;
        reg [31:0] pix0;
        reg [31:0] pix1;
        reg [31:0] pix2;
        reg [31:0] pix3;
        begin
            pix0 = {8'h10, line_idx[7:0], beat_idx[7:0], 8'h00};
            pix1 = {8'h20, line_idx[7:0], beat_idx[7:0], 8'h01};
            pix2 = {8'h30, line_idx[7:0], beat_idx[7:0], 8'h02};
            pix3 = {8'h40, line_idx[7:0], beat_idx[7:0], 8'h03};
            make_rgba_beat = {pix3, pix2, pix1, pix0};
        end
    endfunction

    function automatic [127:0] make_yuv420_beat;
        input integer line_idx;
        input integer beat_idx;
        reg [127:0] data_word;
        begin
            data_word = 128'd0;
            data_word[7:0]     = beat_idx[7:0];
            data_word[15:8]    = line_idx[7:0];
            data_word[23:16]   = beat_idx[7:0] + 8'd1;
            data_word[47:40]   = beat_idx[7:0] + 8'd2;
            data_word[71:64]   = line_idx[7:0] + 8'd3;
            data_word[79:72]   = line_idx[7:0] + 8'd4;
            data_word[87:80]   = beat_idx[7:0] + 8'd5;
            data_word[111:104] = line_idx[7:0] + 8'd6;
            make_yuv420_beat   = data_word;
        end
    endfunction

    task automatic clear_inputs;
        begin
            cfg_format      = 3'd0;
            cfg_width       = 16'd0;
            cfg_height      = 16'd0;
            cfg_active_width  = 16'd0;
            cfg_active_height = 16'd0;
            cfg_tile_w      = 16'd0;
            cfg_tile_h      = 4'd0;
            cfg_a_tile_cols = 16'd0;
            cfg_b_tile_cols = 16'd0;
            otf_vsync       = 1'b0;
            otf_hsync       = 1'b0;
            otf_de          = 1'b0;
            otf_data        = 128'd0;
            otf_fcnt        = 4'd0;
            otf_lcnt        = 12'd0;
            tile_rdy        = 1'b1;
            ci_ready        = 1'b1;
        end
    endtask

    task automatic do_reset;
        begin
            rst_n = 1'b0;
            clear_inputs();
            u_bank0.clear_mem();
            u_bank1.clear_mem();
            repeat (8) @(posedge clk);
            rst_n = 1'b1;
            repeat (8) @(posedge clk);
            repeat (4) @(posedge otf_clk);
        end
    endtask

    task automatic expect_equal;
        input [255:0] check_name;
        input integer got_value;
        input integer exp_value;
        begin
            if (got_value !== exp_value) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] %0s got=%0d exp=%0d", check_name, got_value, exp_value);
            end else begin
                $display("[TB][PASS ] %0s = %0d", check_name, got_value);
            end
        end
    endtask

    task automatic expect_zero_flag;
        input [255:0] check_name;
        input logic   flag_value;
        begin
            if (flag_value !== 1'b0) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] %0s asserted unexpectedly", check_name);
            end else begin
                $display("[TB][PASS ] %0s remained low", check_name);
            end
        end
    endtask

    task automatic drive_otf_beat;
        input logic       beat_vsync;
        input logic       beat_hsync;
        input [127:0]     beat_data;
        input [3:0]       beat_fcnt;
        input [11:0]      beat_lcnt;
        begin
            while (otf_ready !== 1'b1)
                @(posedge otf_clk);

            otf_vsync = beat_vsync;
            otf_hsync = beat_hsync;
            otf_de    = 1'b1;
            otf_data  = beat_data;
            otf_fcnt  = beat_fcnt;
            otf_lcnt  = beat_lcnt;
            @(posedge otf_clk);

            otf_vsync = 1'b0;
            otf_hsync = 1'b0;
            otf_de    = 1'b0;
            otf_data  = 128'd0;
            otf_fcnt  = 4'd0;
            otf_lcnt  = 12'd0;
        end
    endtask

    task automatic send_rgba_frame;
        integer line_idx;
        integer beat_idx;
        begin
            for (line_idx = 0; line_idx < FRAME_H; line_idx = line_idx + 1) begin
                for (beat_idx = 0; beat_idx < BEATS_PER_LINE; beat_idx = beat_idx + 1) begin
                    drive_otf_beat((line_idx == 0) && (beat_idx == 0),
                                   (beat_idx == 0),
                                   make_rgba_beat(line_idx, beat_idx),
                                   4'h1,
                                   line_idx[11:0]);
                end
            end
        end
    endtask

    task automatic send_yuv420_frame;
        integer line_idx;
        integer beat_idx;
        begin
            for (line_idx = 0; line_idx < FRAME_H; line_idx = line_idx + 1) begin
                for (beat_idx = 0; beat_idx < BEATS_PER_LINE; beat_idx = beat_idx + 1) begin
                    drive_otf_beat((line_idx == 0) && (beat_idx == 0),
                                   (beat_idx == 0),
                                   make_yuv420_beat(line_idx, beat_idx),
                                   4'h2,
                                   line_idx[11:0]);
                end
            end
        end
    endtask

    task automatic wait_for_tiles;
        input [255:0] case_name;
        input integer exp_tile_cnt;
        integer timeout_cycles;
        begin
            $display("[TB] %0s wait_for_tiles start: tile_count=%0d exp=%0d time=%0t",
                     case_name, tile_count, exp_tile_cnt, $time);
            timeout_cycles = 0;
            while ((tile_count < exp_tile_cnt) && (timeout_cycles < 3000000)) begin
                @(posedge clk);
                timeout_cycles = timeout_cycles + 1;
            end

            if (tile_count != exp_tile_cnt) begin
                fail_count = fail_count + 1;
                $display("[TB][ERROR] %0s timeout waiting tiles, got=%0d exp=%0d", case_name, tile_count, exp_tile_cnt);
            end else begin
                $display("[TB] %0s completed with tile_count=%0d", case_name, tile_count);
            end

            repeat (20) @(posedge clk);
        end
    endtask

    task automatic run_rgba_case;
        begin
            $display("[TB] ==== Run RGBA8888 %0dx%0d case ====", FRAME_W, FRAME_H);
            cfg_format      = FMT_RGBA8888;
            cfg_width       = FRAME_W[15:0];
            cfg_height      = FRAME_H[15:0];
            cfg_active_width  = FRAME_W[15:0];
            cfg_active_height = FRAME_H[15:0];
            cfg_tile_w      = 16'd16;
            cfg_tile_h      = 4'd4;
            cfg_a_tile_cols = TILE_COLS[15:0];
            cfg_b_tile_cols = 16'd0;

            repeat (8) @(posedge clk);
            send_rgba_frame();
            $display("[TB] RGBA8888 input done at time=%0t tile_count=%0d", $time, tile_count);
            wait_for_tiles("RGBA8888", RGBA_EXPECT_TILES);

            expect_equal("RGBA beat count",      tile_beat_count,      RGBA_EXPECT_BEATS);
            expect_equal("RGBA tile count",      tile_count,           RGBA_EXPECT_TILES);
            expect_equal("RGBA ci_valid count",  ci_valid_count,       RGBA_EXPECT_BEATS);
            expect_equal("RGBA fmt0 beats",      fmt0_beat_count,      RGBA_EXPECT_BEATS);
            expect_equal("RGBA fmt8 beats",      fmt8_beat_count,      0);
            expect_equal("RGBA fmt9 beats",      fmt9_beat_count,      0);
            expect_equal("RGBA other fmt beats", other_fmt_beat_count, 0);
            expect_equal("RGBA keep errors",     keep_error_count,      0);
            expect_equal("RGBA ci mismatches",   ci_mismatch_count,     0);
            expect_equal("RGBA upper data nz",   upper_data_nonzero_count, 0);
            expect_equal("RGBA max tile x",      max_tile_x_seen,       TILE_COLS - 1);
            expect_equal("RGBA max tile y",      max_tile_y_seen,       RGBA_TILE_ROWS - 1);
            expect_equal("RGBA beats per tile",  tile_beat_count,       tile_count * 16);
            expect_zero_flag("RGBA err_bline",   err_bline);
            expect_zero_flag("RGBA err_bframe",  err_bframe);
            expect_zero_flag("RGBA err_fifo_ovf",err_fifo_ovf);
        end
    endtask

    task automatic run_yuv420_case;
        begin
            $display("[TB] ==== Run YUV420_8 %0dx%0d case ====", FRAME_W, FRAME_H);
            cfg_format      = FMT_YUV420_8;
            cfg_width       = FRAME_W[15:0];
            cfg_height      = FRAME_H[15:0];
            cfg_active_width  = FRAME_W[15:0];
            cfg_active_height = FRAME_H[15:0];
            cfg_tile_w      = 16'd16;
            cfg_tile_h      = 4'd8;
            cfg_a_tile_cols = TILE_COLS[15:0];
            cfg_b_tile_cols = TILE_COLS[15:0];

            repeat (8) @(posedge clk);
            send_yuv420_frame();
            $display("[TB] YUV420_8 input done at time=%0t tile_count=%0d", $time, tile_count);
            wait_for_tiles("YUV420_8", YUV_EXPECT_TILES);

            expect_equal("YUV beat count",      tile_beat_count,      YUV_EXPECT_BEATS);
            expect_equal("YUV tile count",      tile_count,           YUV_EXPECT_TILES);
            expect_equal("YUV ci_valid count",  ci_valid_count,       YUV_EXPECT_BEATS);
            expect_equal("YUV fmt0 beats",      fmt0_beat_count,      0);
            expect_equal("YUV fmt8 beats",      fmt8_beat_count,      YUV_EXPECT_FMT8);
            expect_equal("YUV fmt9 beats",      fmt9_beat_count,      YUV_EXPECT_FMT9);
            expect_equal("YUV other fmt beats", other_fmt_beat_count, 0);
            expect_equal("YUV keep errors",     keep_error_count,      0);
            expect_equal("YUV ci mismatches",   ci_mismatch_count,     0);
            expect_equal("YUV upper data nz",   upper_data_nonzero_count, 0);
            expect_equal("YUV max tile x",      max_tile_x_seen,       TILE_COLS - 1);
            expect_equal("YUV max tile y",      max_tile_y_seen,       YUV_TILE_ROWS - 1);
            expect_equal("YUV beats per tile",  tile_beat_count,       tile_count * 16);
            expect_zero_flag("YUV err_bline",   err_bline);
            expect_zero_flag("YUV err_bframe",  err_bframe);
            expect_zero_flag("YUV err_fifo_ovf",err_fifo_ovf);
        end
    endtask

    initial begin
        fail_count = 0;
        do_reset();
        run_rgba_case();

        do_reset();
        run_yuv420_case();

        if (fail_count == 0)
            $display("[TB] All otf_to_tile test cases passed.");
        else
            $display("[TB] otf_to_tile testbench failed, fail_count=%0d", fail_count);

        #100;
        $finish;
    end
endmodule

`default_nettype wire
