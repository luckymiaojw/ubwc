`timescale 1ns/1ps

module tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888;

    localparam integer IMG_W             = 4096;
    localparam integer IMG_H_ACTIVE      = 600;
    localparam integer IMG_H_STORED      = 608;
    localparam integer RGBA_TILE_W       = 16;
    localparam integer RGBA_TILE_H       = 4;
    localparam integer RGBA_TILE_X_COUNT = IMG_W / RGBA_TILE_W;
    localparam integer RGBA_TILE_Y_COUNT = IMG_H_STORED / RGBA_TILE_H;
    localparam integer FRAME_PIXEL_COUNT = IMG_W * IMG_H_STORED;
    localparam integer WORDS64_PER_LINE  = IMG_W / 2;
    localparam integer WORDS64_TOTAL     = WORDS64_PER_LINE * IMG_H_STORED;
    localparam integer WORDS64_PER_TILE  = 32;
    localparam integer BEATS_PER_TILE    = WORDS64_PER_TILE / 4;

    localparam [4:0] FMT_RGBA8888 = 5'b00000;

    reg           clk_sram;
    reg           clk_otf;
    reg           rst_n;

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
    wire          sram_b_wen;
    wire [12:0]   sram_b_waddr;
    wire [127:0]  sram_b_wdata;
    wire          sram_b_ren;
    wire [12:0]   sram_b_raddr;
    wire [127:0]  sram_b_rdata;

    wire          o_otf_vsync;
    wire          o_otf_hsync;
    wire          o_otf_de;
    wire [127:0]  o_otf_data;
    wire [3:0]    o_otf_fcnt;
    wire [11:0]   o_otf_lcnt;
    reg           i_otf_ready;

    reg  [63:0]   linear_words [0:WORDS64_TOTAL-1];

    integer       sent_tile_count;
    integer       checked_pixel_count;
    integer       active_x;
    integer       active_y;
    integer       otf_fd;
    reg           sending_done;
    reg           frame_done;

    function automatic [63:0] linear_tile_word64;
        input integer tile_x;
        input integer tile_y;
        input integer local_word_idx;
        integer line_in_tile;
        integer word_in_line;
        integer global_y;
        integer global_word_x;
        integer linear_word_idx;
        begin
            line_in_tile   = local_word_idx >> 3;
            word_in_line   = local_word_idx & 7;
            global_y       = tile_y * RGBA_TILE_H + line_in_tile;
            global_word_x  = tile_x * (RGBA_TILE_W / 2) + word_in_line;
            linear_word_idx = global_y * WORDS64_PER_LINE + global_word_x;
            if ((global_y < IMG_H_STORED) && (global_word_x < WORDS64_PER_LINE)) begin
                linear_tile_word64 = linear_words[linear_word_idx];
            end else begin
                linear_tile_word64 = 64'd0;
            end
        end
    endfunction

    function automatic [127:0] expected_otf_word;
        input integer x;
        input integer y;
        integer word64_idx;
        begin
            word64_idx = y * WORDS64_PER_LINE + (x >> 1);
            expected_otf_word = {linear_words[word64_idx + 1], linear_words[word64_idx + 0]};
        end
    endfunction

    task automatic drive_axis_tile_header;
        input [4:0]  fmt;
        input [15:0] tile_x;
        input [15:0] tile_y;
        begin
            @(negedge clk_sram);
            s_axis_format     = fmt;
            s_axis_tile_x     = tile_x;
            s_axis_tile_y     = tile_y;
            s_axis_tile_valid = 1'b1;
            while (!s_axis_tile_ready) @(negedge clk_sram);
            @(negedge clk_sram);
            s_axis_tile_valid = 1'b0;
        end
    endtask

    task automatic drive_axis_beat;
        input [255:0] beat_data;
        input         is_last;
        begin
            @(negedge clk_sram);
            s_axis_tvalid = 1'b1;
            s_axis_tdata  = beat_data;
            s_axis_tlast  = is_last;
            while (!s_axis_tready) @(negedge clk_sram);
        end
    endtask

    task automatic axis_idle;
        begin
            @(negedge clk_sram);
            s_axis_tvalid      = 1'b0;
            s_axis_tdata       = 256'd0;
            s_axis_tlast       = 1'b0;
            s_axis_format      = 5'd0;
            s_axis_tile_x      = 16'd0;
            s_axis_tile_y      = 16'd0;
            s_axis_tile_valid  = 1'b0;
        end
    endtask

    task automatic send_rgba_tile_from_linear;
        input integer tile_x;
        input integer tile_y;
        integer beat;
        integer local_word_idx;
        reg [255:0] beat_data;
        begin
            drive_axis_tile_header(FMT_RGBA8888, tile_x[15:0], tile_y[15:0]);

            for (beat = 0; beat < BEATS_PER_TILE; beat = beat + 1) begin
                local_word_idx = beat * 4;
                beat_data = {linear_tile_word64(tile_x, tile_y, local_word_idx + 3),
                             linear_tile_word64(tile_x, tile_y, local_word_idx + 2),
                             linear_tile_word64(tile_x, tile_y, local_word_idx + 1),
                             linear_tile_word64(tile_x, tile_y, local_word_idx + 0)};
                drive_axis_beat(beat_data, (beat == (BEATS_PER_TILE - 1)));
            end

            sent_tile_count = sent_tile_count + 1;
            axis_idle();
        end
    endtask

    task automatic send_full_linear_frame_as_tiles;
        integer slice_idx;
        integer tile_x;
        begin
            for (slice_idx = 0; slice_idx < RGBA_TILE_Y_COUNT; slice_idx = slice_idx + 1) begin
                for (tile_x = 0; tile_x < RGBA_TILE_X_COUNT; tile_x = tile_x + 1) begin
                    send_rgba_tile_from_linear(tile_x, slice_idx);
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
        .clk_sram        (clk_sram),
        .clk_otf         (clk_otf),
        .rst_n           (rst_n),
        .cfg_img_width   (cfg_img_width),
        .cfg_format      (cfg_format),
        .cfg_otf_h_total (cfg_otf_h_total),
        .cfg_otf_h_sync  (cfg_otf_h_sync),
        .cfg_otf_h_bp    (cfg_otf_h_bp),
        .cfg_otf_h_act   (cfg_otf_h_act),
        .cfg_otf_v_total (cfg_otf_v_total),
        .cfg_otf_v_sync  (cfg_otf_v_sync),
        .cfg_otf_v_bp    (cfg_otf_v_bp),
        .cfg_otf_v_act   (cfg_otf_v_act),
        .s_axis_format   (s_axis_format),
        .s_axis_tile_x   (s_axis_tile_x),
        .s_axis_tile_y   (s_axis_tile_y),
        .s_axis_tile_valid(s_axis_tile_valid),
        .s_axis_tile_ready(s_axis_tile_ready),
        .s_axis_tdata    (s_axis_tdata),
        .s_axis_tlast    (s_axis_tlast),
        .s_axis_tvalid   (s_axis_tvalid),
        .s_axis_tready   (s_axis_tready),
        .sram_a_wen      (sram_a_wen),
        .sram_a_waddr    (sram_a_waddr),
        .sram_a_wdata    (sram_a_wdata),
        .sram_a_ren      (sram_a_ren),
        .sram_a_raddr    (sram_a_raddr),
        .sram_a_rdata    (sram_a_rdata),
        .sram_b_wen      (sram_b_wen),
        .sram_b_waddr    (sram_b_waddr),
        .sram_b_wdata    (sram_b_wdata),
        .sram_b_ren      (sram_b_ren),
        .sram_b_raddr    (sram_b_raddr),
        .sram_b_rdata    (sram_b_rdata),
        .o_otf_vsync     (o_otf_vsync),
        .o_otf_hsync     (o_otf_hsync),
        .o_otf_de        (o_otf_de),
        .o_otf_data      (o_otf_data),
        .o_otf_fcnt      (o_otf_fcnt),
        .o_otf_lcnt      (o_otf_lcnt),
        .i_otf_ready     (i_otf_ready)
    );

    initial begin
        clk_sram = 1'b0;
        forever #2 clk_sram = ~clk_sram;
    end

    initial begin
        clk_otf = 1'b0;
        forever #3 clk_otf = ~clk_otf;
    end

    always @(posedge clk_otf or negedge rst_n) begin
        if (!rst_n) begin
            checked_pixel_count <= 0;
            active_x            <= 0;
            active_y            <= 0;
            frame_done          <= 1'b0;
        end else if (i_otf_ready && o_otf_de && !frame_done) begin
            if (otf_fd != 0) begin
                $fwrite(otf_fd, "%0d %032h\n", active_y, o_otf_data);
            end

            if (o_otf_data !== expected_otf_word(active_x, active_y)) begin
                $fatal(1,
                       "OTF beat mismatch at x=%0d y=%0d got=%032h exp=%032h",
                       active_x, active_y, o_otf_data, expected_otf_word(active_x, active_y));
            end

            if ((active_x == 0) && ((active_y % 64) == 0)) begin
                $display("Linear-in OTF progress: line %0d / %0d", active_y, IMG_H_STORED);
            end

            checked_pixel_count <= checked_pixel_count + 4;

            if (active_x == IMG_W - 4) begin
                active_x <= 0;
                if (active_y == IMG_H_STORED - 1) begin
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
        integer timeout;

        $readmemh("tajmahal_linear.memh", linear_words);

        if (^linear_words[0] === 1'bx) begin
            $fatal(1, "Failed to load tajmahal_linear.memh");
        end

        rst_n             = 1'b0;
        cfg_img_width     = IMG_W[15:0];
        cfg_format        = FMT_RGBA8888;
        cfg_otf_h_total   = 16'd4400;
        cfg_otf_h_sync    = 16'd44;
        cfg_otf_h_bp      = 16'd148;
        cfg_otf_h_act     = IMG_W[15:0];
        cfg_otf_v_total   = 16'd650;
        cfg_otf_v_sync    = 16'd5;
        cfg_otf_v_bp      = 16'd36;
        cfg_otf_v_act     = IMG_H_STORED[15:0];
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

        repeat (8) @(posedge clk_sram);
        rst_n = 1'b1;
        repeat (4) @(posedge clk_sram);

        $display("");
        $display("==============================================================");
        $display("TB: ubwc_dec_tile_to_otf TajMahal linear-in RGBA8888");
        $display("Vector source      : tajmahal_linear.memh");
        $display("Actual image size  : %0dx%0d", IMG_W, IMG_H_ACTIVE);
        $display("Stored image size  : %0dx%0d", IMG_W, IMG_H_STORED);
        $display("Tile grid          : %0d x %0d", RGBA_TILE_X_COUNT, RGBA_TILE_Y_COUNT);
        $display("==============================================================");

        otf_fd = $fopen("tajmahal_linear_in_otf_stream.txt", "w");
        if (otf_fd == 0) begin
            $fatal(1, "Failed to open tajmahal_linear_in_otf_stream.txt");
        end

        fork
            send_full_linear_frame_as_tiles();
        join_none

        timeout = 0;
        while (!frame_done && (timeout < 3000000)) begin
            @(posedge clk_otf);
            timeout = timeout + 1;
        end

        if (timeout >= 3000000) begin
            $fatal(1, "Timeout waiting for TajMahal linear-in OTF frame.");
        end

        if (!sending_done) begin
            $fatal(1, "Linear-in AXIS frame was not fully sent.");
        end

        if (sent_tile_count != (RGBA_TILE_X_COUNT * RGBA_TILE_Y_COUNT)) begin
            $fatal(1, "Sent tile count mismatch. got=%0d exp=%0d",
                   sent_tile_count, RGBA_TILE_X_COUNT * RGBA_TILE_Y_COUNT);
        end

        if (checked_pixel_count != FRAME_PIXEL_COUNT) begin
            $fatal(1, "Checked pixel count mismatch. got=%0d exp=%0d",
                   checked_pixel_count, FRAME_PIXEL_COUNT);
        end

        $display("PASS: ubwc_dec_tile_to_otf TajMahal linear-in vector completed");
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
        $fsdbDumpfile("tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888);
        $fsdbDumpMDA(0, tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888);
`else
        $dumpfile("tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888.vcd");
        $dumpvars(0, tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888);
`endif
`endif
    end

endmodule
