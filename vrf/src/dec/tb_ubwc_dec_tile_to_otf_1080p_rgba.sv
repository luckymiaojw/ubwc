`timescale 1ns/1ps

module tb_ubwc_dec_tile_to_otf_1080p_rgba;

    localparam integer IMG_W = 1920;
    localparam integer IMG_H = 1080;
    localparam integer RGBA_SLICE_LINES = 4;
    localparam integer RGBA_TILE_W = 16;
    localparam integer RGBA_TILE_X_COUNT = IMG_W / RGBA_TILE_W;
    localparam integer RGBA_SLICE_COUNT = IMG_H / RGBA_SLICE_LINES;
    localparam integer FRAME_PIXEL_COUNT = IMG_W * IMG_H;

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

    integer       sent_tile_count;
    integer       checked_pixel_count;
    integer       active_x;
    integer       active_y;
    reg           sending_done;
    reg           frame_done;

    function automatic [31:0] rgba_pixel;
        input integer x;
        input integer y;
        reg [7:0] r;
        reg [7:0] g;
        reg [7:0] b;
        reg [7:0] a;
        begin
            r = ((x * 3) + (y * 5)) & 8'hff;
            g = ((x * 7) + (y * 11)) & 8'hff;
            b = ((x * 13) ^ (y * 17)) & 8'hff;
            a = 8'hff;
            rgba_pixel = {a, b, g, r};
        end
    endfunction

    function automatic [127:0] rgba_word;
        input integer line_idx;
        input integer word_idx;
        integer pix;
        integer x_coord;
        reg [127:0] tmp;
        begin
            tmp = 128'd0;
            for (pix = 0; pix < 4; pix = pix + 1) begin
                x_coord = word_idx * 4 + pix;
                tmp[pix * 32 +: 32] = rgba_pixel(x_coord, line_idx);
            end
            rgba_word = tmp;
        end
    endfunction

    task automatic drive_axis_tile_header;
        input [4:0] fmt;
        input [15:0] tile_x;
        input [15:0] tile_y;
        begin
            @(negedge clk_sram);
            s_axis_tvalid    = 1'b0;
            s_axis_tdata     = 256'd0;
            s_axis_tlast     = 1'b0;
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
        input [4:0] fmt;
        input [127:0] lo_word;
        input [127:0] hi_word;
        input [15:0] tile_x;
        input [15:0] tile_y;
        input is_last;
        begin
            @(negedge clk_sram);
            s_axis_tvalid  = 1'b1;
            s_axis_tdata   = {hi_word, lo_word};
            s_axis_tlast   = is_last;
            while (!s_axis_tready) @(negedge clk_sram);
        end
    endtask

    task automatic axis_idle;
        begin
            @(negedge clk_sram);
            s_axis_tvalid = 1'b0;
            s_axis_tdata  = 256'd0;
            s_axis_tlast  = 1'b0;
            s_axis_format = 5'd0;
            s_axis_tile_x = 16'd0;
            s_axis_tile_y = 16'd0;
            s_axis_tile_valid = 1'b0;
        end
    endtask

    task automatic send_rgba_tile;
        input integer tile_x;
        input integer base_line;
        integer beat;
        integer local_lo;
        integer local_hi;
        integer line_lo;
        integer line_hi;
        integer word_lo;
        integer word_hi;
        begin
            drive_axis_tile_header(FMT_RGBA8888, tile_x[15:0], (base_line >> 2));
            for (beat = 0; beat < 8; beat = beat + 1) begin
                local_lo = beat * 2;
                local_hi = beat * 2 + 1;
                line_lo  = local_lo >> 2;
                line_hi  = local_hi >> 2;
                word_lo  = tile_x * 4 + (local_lo & 3);
                word_hi  = tile_x * 4 + (local_hi & 3);

                drive_axis_beat(
                    FMT_RGBA8888,
                    rgba_word(base_line + line_lo, word_lo),
                    rgba_word(base_line + line_hi, word_hi),
                    tile_x[15:0],
                    (base_line >> 2),
                    (beat == 7)
                );
            end

            sent_tile_count = sent_tile_count + 1;
            axis_idle();
        end
    endtask

    task automatic send_full_hd_frame;
        integer slice_idx;
        integer tile_x;
        integer base_line;
        begin
            for (slice_idx = 0; slice_idx < RGBA_SLICE_COUNT; slice_idx = slice_idx + 1) begin
                base_line = slice_idx * RGBA_SLICE_LINES;
                for (tile_x = 0; tile_x < RGBA_TILE_X_COUNT; tile_x = tile_x + 1) begin
                    send_rgba_tile(tile_x, base_line);
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
        .clk_sram       (clk_sram),
        .clk_otf        (clk_otf),
        .rst_sram_n          (rst_n),
        .rst_otf_n          (rst_n),
        .cfg_img_width  (cfg_img_width),
        .cfg_format     (cfg_format),
        .cfg_otf_h_total(cfg_otf_h_total),
        .cfg_otf_h_sync (cfg_otf_h_sync),
        .cfg_otf_h_bp   (cfg_otf_h_bp),
        .cfg_otf_h_act  (cfg_otf_h_act),
        .cfg_otf_v_total(cfg_otf_v_total),
        .cfg_otf_v_sync (cfg_otf_v_sync),
        .cfg_otf_v_bp   (cfg_otf_v_bp),
        .cfg_otf_v_act  (cfg_otf_v_act),
        .s_axis_format  (s_axis_format),
        .s_axis_tile_x  (s_axis_tile_x),
        .s_axis_tile_y  (s_axis_tile_y),
        .s_axis_tile_valid(s_axis_tile_valid),
        .s_axis_tile_ready(s_axis_tile_ready),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .sram_a_wen     (sram_a_wen),
        .sram_a_waddr   (sram_a_waddr),
        .sram_a_wdata   (sram_a_wdata),
        .sram_a_ren     (sram_a_ren),
        .sram_a_raddr   (sram_a_raddr),
        .sram_a_rdata   (sram_a_rdata),
        .sram_a_rvalid   (sram_a_dout_vld),
        .sram_b_wen     (sram_b_wen),
        .sram_b_waddr   (sram_b_waddr),
        .sram_b_wdata   (sram_b_wdata),
        .sram_b_ren     (sram_b_ren),
        .sram_b_raddr   (sram_b_raddr),
        .sram_b_rdata   (sram_b_rdata),
        .sram_b_rvalid   (sram_b_dout_vld),
        .o_otf_vsync    (o_otf_vsync),
        .o_otf_hsync    (o_otf_hsync),
        .o_otf_de       (o_otf_de),
        .o_otf_data     (o_otf_data),
        .o_otf_fcnt     (o_otf_fcnt),
        .o_otf_lcnt     (o_otf_lcnt),
        .i_otf_ready    (i_otf_ready)
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
            active_x <= 0;
            active_y <= 0;
            frame_done <= 1'b0;
        end else if (i_otf_ready && o_otf_de && !frame_done) begin
            if (o_otf_data[31:0] !== rgba_pixel(active_x + 0, active_y)) begin
                $fatal(1,
                       "OTF pixel mismatch at x=%0d y=%0d got=%h exp=%h",
                       active_x + 0, active_y, o_otf_data[31:0], rgba_pixel(active_x + 0, active_y));
            end
            if (o_otf_data[63:32] !== rgba_pixel(active_x + 1, active_y)) begin
                $fatal(1,
                       "OTF pixel mismatch at x=%0d y=%0d got=%h exp=%h",
                       active_x + 1, active_y, o_otf_data[63:32], rgba_pixel(active_x + 1, active_y));
            end
            if (o_otf_data[95:64] !== rgba_pixel(active_x + 2, active_y)) begin
                $fatal(1,
                       "OTF pixel mismatch at x=%0d y=%0d got=%h exp=%h",
                       active_x + 2, active_y, o_otf_data[95:64], rgba_pixel(active_x + 2, active_y));
            end
            if (o_otf_data[127:96] !== rgba_pixel(active_x + 3, active_y)) begin
                $fatal(1,
                       "OTF pixel mismatch at x=%0d y=%0d got=%h exp=%h",
                       active_x + 3, active_y, o_otf_data[127:96], rgba_pixel(active_x + 3, active_y));
            end

            if ((active_x == 0) && ((active_y % 120) == 0)) begin
                $display("OTF progress: line %0d / %0d", active_y, IMG_H);
            end

            checked_pixel_count <= checked_pixel_count + 4;

            if (active_x == IMG_W - 4) begin
                active_x <= 0;
                if (active_y == IMG_H - 1) begin
                    active_y <= 0;
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

        rst_n          = 1'b0;
        cfg_img_width  = IMG_W[15:0];
        cfg_format     = FMT_RGBA8888;
        cfg_otf_h_total = 16'd2200;
        cfg_otf_h_sync  = 16'd44;
        cfg_otf_h_bp    = 16'd148;
        cfg_otf_h_act   = IMG_W[15:0];
        cfg_otf_v_total = 16'd1125;
        cfg_otf_v_sync  = 16'd5;
        cfg_otf_v_bp    = 16'd36;
        cfg_otf_v_act   = IMG_H[15:0];
        s_axis_tdata   = 256'd0;
        s_axis_tlast   = 1'b0;
        s_axis_format  = 5'd0;
        s_axis_tile_x  = 16'd0;
        s_axis_tile_y  = 16'd0;
        s_axis_tile_valid = 1'b0;
        s_axis_tvalid  = 1'b0;
        i_otf_ready    = 1'b1;
        sent_tile_count = 0;
        sending_done    = 1'b0;

        repeat (8) @(posedge clk_sram);
        rst_n = 1'b1;
        repeat (4) @(posedge clk_sram);

        $display("");
        $display("========================================================");
        $display("TB: ubwc_dec_tile_to_otf full 1920x1080 RGBA8888 frame");
        $display("Frame size   : %0dx%0d", IMG_W, IMG_H);
        $display("Tile slices  : %0d groups of %0d lines", RGBA_SLICE_COUNT, RGBA_SLICE_LINES);
        $display("Tiles / slice: %0d", RGBA_TILE_X_COUNT);
        $display("========================================================");

        fork
            send_full_hd_frame();
        join_none

        timeout = 0;
        while (!frame_done && (timeout < 5000000)) begin
            @(posedge clk_otf);
            timeout = timeout + 1;
        end

        if (timeout >= 5000000) begin
            $fatal(1, "Timeout waiting for full 1080p OTF frame.");
        end

        if (!sending_done) begin
            $fatal(1, "Input AXIS frame was not fully sent.");
        end

        if (sent_tile_count != (RGBA_TILE_X_COUNT * RGBA_SLICE_COUNT)) begin
            $fatal(1, "Sent tile count mismatch. got=%0d exp=%0d",
                   sent_tile_count, RGBA_TILE_X_COUNT * RGBA_SLICE_COUNT);
        end

        if (checked_pixel_count != FRAME_PIXEL_COUNT) begin
            $fatal(1, "Checked pixel count mismatch. got=%0d exp=%0d",
                   checked_pixel_count, FRAME_PIXEL_COUNT);
        end

        if (dut.writer_vld !== 1'b0) begin
            $display("WARN: writer_vld is still asserted near end of test.");
        end

        $display("PASS: ubwc_dec_tile_to_otf full 1920x1080 RGBA8888 frame completed");
        $display("Checked pixels : %0d", checked_pixel_count);
        $display("Sent tiles     : %0d", sent_tile_count);

        repeat (20) @(posedge clk_otf);
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_tile_to_otf_1080p_rgba.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_tile_to_otf_1080p_rgba);
        $fsdbDumpMDA(0, tb_ubwc_dec_tile_to_otf_1080p_rgba);
`else
        $dumpfile("tb_ubwc_dec_tile_to_otf_1080p_rgba.vcd");
        $dumpvars(0, tb_ubwc_dec_tile_to_otf_1080p_rgba);
`endif
`endif
    end

endmodule
