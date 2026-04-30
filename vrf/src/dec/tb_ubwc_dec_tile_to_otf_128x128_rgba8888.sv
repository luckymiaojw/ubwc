`timescale 1ns/1ps

module tb_ubwc_dec_tile_to_otf_128x128_rgba8888;

    localparam integer IMG_W = 128;
    localparam integer IMG_H = 128;
    localparam integer RGBA_TILE_W = 16;
    localparam integer RGBA_TILE_H = 4;
    localparam integer TILE_X_COUNT = IMG_W / RGBA_TILE_W;
    localparam integer TILE_Y_COUNT = IMG_H / RGBA_TILE_H;
    localparam integer WORDS64_PER_TILE = 32;
    localparam integer BEATS_PER_TILE = 8;
    localparam integer WORDS64_TOTAL = TILE_X_COUNT * TILE_Y_COUNT * WORDS64_PER_TILE;
    localparam integer EXPECTED_BEATS = (IMG_W / 4) * IMG_H;
    localparam integer FRAME_PIXEL_COUNT = IMG_W * IMG_H;

    localparam [4:0] FMT_RGBA8888 = 5'b00000;

    reg           clk_sram;
    reg           clk_otf;
    reg           rst_n;
    reg           frame_start;

    reg  [15:0]   cfg_img_width;
    reg  [4:0]    cfg_format;
    reg  [15:0]   cfg_otf_h_total;
    reg  [15:0]   cfg_otf_h_sync;
    reg  [15:0]   cfg_otf_h_bp;
    reg  [15:0]   cfg_otf_h_act;
    reg  [15:0]   cfg_otf_v_total;
    reg  [15:0]   cfg_otf_v_sync;
    reg  [15:0]   cfg_otf_v_bp;
    reg  [15:0]   cfg_otf_v_act;

    reg  [255:0]  s_axis_tdata;
    reg           s_axis_tlast;
    reg  [4:0]    s_axis_format;
    reg  [15:0]   s_axis_tile_x;
    reg  [15:0]   s_axis_tile_y;
    reg           s_axis_tile_valid;
    wire          s_axis_tile_ready;
    reg           s_axis_tvalid;
    wire          s_axis_tready;

    wire          sram_a_wen;
    wire [12:0]   sram_a_waddr;
    wire [127:0]  sram_a_wdata;
    wire          sram_a_ren;
    wire [12:0]   sram_a_raddr;
    wire [127:0]  sram_a_rdata;
    reg           sram_a_dout_vld;
    wire          sram_b_wen;
    wire [12:0]   sram_b_waddr;
    wire [127:0]  sram_b_wdata;
    wire          sram_b_ren;
    wire [12:0]   sram_b_raddr;
    wire [127:0]  sram_b_rdata;
    reg           sram_b_dout_vld;

    wire          o_otf_vsync;
    wire          o_otf_hsync;
    wire          o_otf_de;
    wire [127:0]  o_otf_data;
    wire [3:0]    o_otf_fcnt;
    wire [11:0]   o_otf_lcnt;
    reg           i_otf_ready;
    wire          o_busy;

    reg  [63:0]   tiled_words [0:WORDS64_TOTAL-1];
    reg  [127:0]  expected_beats [0:EXPECTED_BEATS-1];

    integer       sent_tile_count;
    integer       checked_pixel_count;
    integer       checked_beat_count;
    integer       active_x;
    integer       active_y;
    integer       otf_fd;
    integer       timeout;
    reg           sending_done;
    reg           frame_done;
    reg  [127:0]  exp_data;

    task automatic drive_axis_tile_header;
        input [15:0] tile_x;
        input [15:0] tile_y;
        begin
            @(negedge clk_sram);
            s_axis_tvalid     = 1'b0;
            s_axis_tdata      = 256'd0;
            s_axis_tlast      = 1'b0;
            s_axis_format     = FMT_RGBA8888;
            s_axis_tile_x     = tile_x;
            s_axis_tile_y     = tile_y;
            s_axis_tile_valid = 1'b1;
            while (!s_axis_tile_ready) @(negedge clk_sram);
            @(negedge clk_sram);
            s_axis_tile_valid = 1'b0;
        end
    endtask

    task automatic drive_axis_beat;
        input [127:0] lo_word;
        input [127:0] hi_word;
        input         is_last;
        begin
            @(negedge clk_sram);
            s_axis_tvalid = 1'b1;
            s_axis_tdata  = {hi_word, lo_word};
            s_axis_tlast  = is_last;
            while (!s_axis_tready) @(negedge clk_sram);
        end
    endtask

    task automatic axis_idle;
        begin
            @(negedge clk_sram);
            s_axis_tvalid     = 1'b0;
            s_axis_tdata      = 256'd0;
            s_axis_tlast      = 1'b0;
            s_axis_format     = 5'd0;
            s_axis_tile_x     = 16'd0;
            s_axis_tile_y     = 16'd0;
            s_axis_tile_valid = 1'b0;
        end
    endtask

    task automatic send_rgba_tile;
        input integer tile_x;
        input integer tile_y;
        integer beat;
        integer base_word;
        begin
            base_word = ((tile_y * TILE_X_COUNT) + tile_x) * WORDS64_PER_TILE;
            drive_axis_tile_header(tile_x[15:0], tile_y[15:0]);
            for (beat = 0; beat < BEATS_PER_TILE; beat = beat + 1) begin
                drive_axis_beat(
                    {tiled_words[base_word + beat * 4 + 1], tiled_words[base_word + beat * 4 + 0]},
                    {tiled_words[base_word + beat * 4 + 3], tiled_words[base_word + beat * 4 + 2]},
                    (beat == BEATS_PER_TILE - 1)
                );
            end
            sent_tile_count = sent_tile_count + 1;
            axis_idle();
        end
    endtask

    task automatic send_frame;
        integer tile_x;
        integer tile_y;
        begin
            for (tile_y = 0; tile_y < TILE_Y_COUNT; tile_y = tile_y + 1) begin
                for (tile_x = 0; tile_x < TILE_X_COUNT; tile_x = tile_x + 1) begin
                    send_rgba_tile(tile_x, tile_y);
                end
            end
            sending_done = 1'b1;
        end
    endtask

    sram_pdp_8192x128 u_sram_bank_a (
        .clk        (clk_sram),
        .wen        (sram_a_wen),
        .waddr      (sram_a_waddr),
        .wdata      (sram_a_wdata),
        .ren        (sram_a_ren),
        .raddr      (sram_a_raddr),
        .rdata      (sram_a_rdata)
    );

    sram_pdp_8192x128 u_sram_bank_b (
        .clk        (clk_sram),
        .wen        (sram_b_wen),
        .waddr      (sram_b_waddr),
        .wdata      (sram_b_wdata),
        .ren        (sram_b_ren),
        .raddr      (sram_b_raddr),
        .rdata      (sram_b_rdata)
    );

    ubwc_dec_tile_to_otf dut (
        .clk_sram          (clk_sram),
        .clk_otf           (clk_otf),
        .rst_sram_n        (rst_n),
        .rst_otf_n         (rst_n),
        .i_frame_start     (frame_start),
        .cfg_img_width     (cfg_img_width),
        .cfg_format        (cfg_format),
        .cfg_otf_h_total   (cfg_otf_h_total),
        .cfg_otf_h_sync    (cfg_otf_h_sync),
        .cfg_otf_h_bp      (cfg_otf_h_bp),
        .cfg_otf_h_act     (cfg_otf_h_act),
        .cfg_otf_v_total   (cfg_otf_v_total),
        .cfg_otf_v_sync    (cfg_otf_v_sync),
        .cfg_otf_v_bp      (cfg_otf_v_bp),
        .cfg_otf_v_act     (cfg_otf_v_act),
        .s_axis_format     (s_axis_format),
        .s_axis_tile_x     (s_axis_tile_x),
        .s_axis_tile_y     (s_axis_tile_y),
        .s_axis_tile_valid (s_axis_tile_valid),
        .s_axis_tile_ready (s_axis_tile_ready),
        .s_axis_tdata      (s_axis_tdata),
        .s_axis_tlast      (s_axis_tlast),
        .s_axis_tvalid     (s_axis_tvalid),
        .s_axis_tready     (s_axis_tready),
        .sram_a_wen        (sram_a_wen),
        .sram_a_waddr      (sram_a_waddr),
        .sram_a_wdata      (sram_a_wdata),
        .sram_a_ren        (sram_a_ren),
        .sram_a_raddr      (sram_a_raddr),
        .sram_a_rdata      (sram_a_rdata),
        .sram_a_rvalid     (sram_a_dout_vld),
        .sram_b_wen        (sram_b_wen),
        .sram_b_waddr      (sram_b_waddr),
        .sram_b_wdata      (sram_b_wdata),
        .sram_b_ren        (sram_b_ren),
        .sram_b_raddr      (sram_b_raddr),
        .sram_b_rdata      (sram_b_rdata),
        .sram_b_rvalid     (sram_b_dout_vld),
        .o_otf_vsync       (o_otf_vsync),
        .o_otf_hsync       (o_otf_hsync),
        .o_otf_de          (o_otf_de),
        .o_otf_data        (o_otf_data),
        .o_otf_fcnt        (o_otf_fcnt),
        .o_otf_lcnt        (o_otf_lcnt),
        .i_otf_ready       (i_otf_ready),
        .o_busy            (o_busy)
    );

    initial begin
        clk_sram = 1'b0;
        forever #2 clk_sram = ~clk_sram;
    end

    initial begin
        clk_otf = 1'b0;
        forever #3 clk_otf = ~clk_otf;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) begin
            sram_a_dout_vld <= 1'b0;
            sram_b_dout_vld <= 1'b0;
        end else begin
            sram_a_dout_vld <= sram_a_ren;
            sram_b_dout_vld <= sram_b_ren;
        end
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n) begin
            checked_pixel_count <= 0;
            checked_beat_count  <= 0;
            active_x            <= 0;
            active_y            <= 0;
            frame_done          <= 1'b0;
        end else if (i_otf_ready && o_otf_de && frame_done) begin
            $fatal(1, "Unexpected extra OTF beat after frame completion. data=%032h", o_otf_data);
        end else if (i_otf_ready && o_otf_de && !frame_done) begin
            if (checked_beat_count >= EXPECTED_BEATS) begin
                $fatal(1, "Observed extra OTF beat beyond expected stream. beat=%0d data=%032h",
                       checked_beat_count, o_otf_data);
            end

            exp_data = expected_beats[checked_beat_count];
            if (otf_fd != 0) begin
                $fwrite(otf_fd, "%032h\n", o_otf_data);
            end

            if (o_otf_data !== exp_data) begin
                $fatal(1,
                       "OTF stream mismatch at beat=%0d x=%0d y=%0d got=%032h exp=%032h",
                       checked_beat_count, active_x, active_y, o_otf_data, exp_data);
            end

            checked_beat_count  <= checked_beat_count + 1;
            checked_pixel_count <= checked_pixel_count + 4;

            if (active_x == IMG_W - 4) begin
                active_x <= 0;
                if (active_y == IMG_H - 1) begin
                    active_y   <= 0;
                    frame_done <= 1'b1;
                end else begin
                    active_y <= active_y + 1;
                end
            end else begin
                active_x <= active_x + 4;
            end
        end
    end

    initial begin
        $readmemh("input_rgba_tiled.memh", tiled_words);
        $readmemh("expected_otf_stream.txt", expected_beats);
        if (^tiled_words[0] === 1'bx) begin
            $fatal(1, "Failed to load input_rgba_tiled.memh");
        end
        if (^expected_beats[0] === 1'bx) begin
            $fatal(1, "Failed to load expected_otf_stream.txt");
        end

        rst_n             = 1'b0;
        frame_start       = 1'b0;
        cfg_img_width     = IMG_W[15:0];
        cfg_format        = FMT_RGBA8888;
        cfg_otf_h_total   = 16'd160;
        cfg_otf_h_sync    = 16'd4;
        cfg_otf_h_bp      = 16'd8;
        cfg_otf_h_act     = IMG_W[15:0];
        cfg_otf_v_total   = 16'd140;
        cfg_otf_v_sync    = 16'd2;
        cfg_otf_v_bp      = 16'd4;
        cfg_otf_v_act     = IMG_H[15:0];
        s_axis_tdata      = 256'd0;
        s_axis_tlast      = 1'b0;
        s_axis_format     = 5'd0;
        s_axis_tile_x     = 16'd0;
        s_axis_tile_y     = 16'd0;
        s_axis_tile_valid = 1'b0;
        s_axis_tvalid     = 1'b0;
        i_otf_ready       = 1'b1;
        otf_fd            = 0;
        sent_tile_count   = 0;
        sending_done      = 1'b0;
        timeout           = 0;

        repeat (8) @(posedge clk_sram);
        rst_n = 1'b1;
        repeat (4) @(posedge clk_sram);
        @(negedge clk_sram);
        frame_start = 1'b1;
        @(negedge clk_sram);
        frame_start = 1'b0;
        repeat (4) @(posedge clk_sram);

        $display("");
        $display("========================================================");
        $display("TB: ubwc_dec_tile_to_otf 128x128 RGBA8888 vector");
        $display("Frame size   : %0dx%0d", IMG_W, IMG_H);
        $display("Tile grid    : %0d x %0d", TILE_X_COUNT, TILE_Y_COUNT);
        $display("Expected beat: %0d", EXPECTED_BEATS);
        $display("========================================================");

        otf_fd = $fopen("actual_otf_stream.txt", "w");
        if (otf_fd == 0) begin
            $fatal(1, "Failed to open actual_otf_stream.txt");
        end

        fork
            send_frame();
        join_none

        while (!frame_done && (timeout < 200000)) begin
            @(posedge clk_otf);
            timeout = timeout + 1;
        end

        if (timeout >= 200000) begin
            $fatal(1, "Timeout waiting for 128x128 OTF frame.");
        end

        if (!sending_done) begin
            $fatal(1, "Input AXIS frame was not fully sent.");
        end

        if (sent_tile_count != (TILE_X_COUNT * TILE_Y_COUNT)) begin
            $fatal(1, "Sent tile count mismatch. got=%0d exp=%0d",
                   sent_tile_count, TILE_X_COUNT * TILE_Y_COUNT);
        end

        if (checked_beat_count != EXPECTED_BEATS) begin
            $fatal(1, "Checked beat count mismatch. got=%0d exp=%0d",
                   checked_beat_count, EXPECTED_BEATS);
        end

        if (checked_pixel_count != FRAME_PIXEL_COUNT) begin
            $fatal(1, "Checked pixel count mismatch. got=%0d exp=%0d",
                   checked_pixel_count, FRAME_PIXEL_COUNT);
        end

        $display("PASS: ubwc_dec_tile_to_otf 128x128 RGBA8888 vector completed");
        $display("Checked beats  : %0d", checked_beat_count);
        $display("Checked pixels : %0d", checked_pixel_count);
        $display("Sent tiles     : %0d", sent_tile_count);

        if (otf_fd != 0) begin
            $fclose(otf_fd);
            otf_fd = 0;
        end

        repeat (20) @(posedge clk_otf);
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_tile_to_otf_128x128_rgba8888.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_tile_to_otf_128x128_rgba8888);
        $fsdbDumpMDA(0, tb_ubwc_dec_tile_to_otf_128x128_rgba8888);
`else
        $dumpfile("tb_ubwc_dec_tile_to_otf_128x128_rgba8888.vcd");
        $dumpvars(0, tb_ubwc_dec_tile_to_otf_128x128_rgba8888);
`endif
`endif
    end

endmodule
