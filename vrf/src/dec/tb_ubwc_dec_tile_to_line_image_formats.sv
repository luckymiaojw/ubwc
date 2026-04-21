`timescale 1ns/1ps

module tb_ubwc_dec_tile_to_line_image_formats;

    localparam [4:0] FMT_RGBA8888 = 5'b00000;
    localparam [4:0] FMT_YUV420_Y = 5'b01000;
    localparam [4:0] FMT_YUV420_UV = 5'b01001;
    localparam [4:0] FMT_YUV422_Y = 5'b01010;
    localparam [4:0] FMT_YUV422_UV = 5'b01011;

    reg           clk;
    reg           rst_n;
    reg  [15:0]   cfg_img_width;
    reg  [4:0]    cfg_format;

    reg  [255:0]  s_axis_tdata;
    reg           s_axis_tlast;
    reg  [4:0]    s_axis_format;
    reg  [15:0]   s_axis_tile_x;
    reg  [15:0]   s_axis_tile_y;
    reg           s_axis_tile_valid;
    wire          s_axis_tile_ready;
    reg           s_axis_tvalid;
    wire          s_axis_tready;

    wire          sram_a_wen, sram_b_wen;
    wire [12:0]   sram_a_waddr, sram_b_waddr;
    wire [127:0]  sram_a_wdata, sram_b_wdata;
    wire          sram_a_ren, sram_b_ren;
    wire [12:0]   sram_a_raddr, sram_b_raddr;
    wire [127:0]  sram_a_rdata, sram_b_rdata;

    wire          writer_vld;
    wire          writer_bank;
    wire          fetcher_done;
    wire          fetcher_bank;
    reg           sram_a_free;
    reg           sram_b_free;

    wire          fifo_wr_en;
    wire [255:0]  fifo_wdata;

    integer       out_count;
    integer       writer_vld_count;
    integer       fetch_done_count;
    reg [255:0]   observed_fifo [0:255];

    function automatic [31:0] rgba_pixel;
        input integer x;
        input integer y;
        reg [7:0] r;
        reg [7:0] g;
        reg [7:0] b;
        reg [7:0] a;
        begin
            r = ((x * 8)  + (y * 5)) & 8'hff;
            g = ((x * 3)  + (y * 28)) & 8'hff;
            b = (((x ^ (y << 2)) * 11)) & 8'hff;
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

    function automatic [7:0] nv12_y_sample;
        input integer x;
        input integer y;
        begin
            nv12_y_sample = ((x * 4) + (y * 13)) & 8'hff;
        end
    endfunction

    function automatic [127:0] nv12_y_word;
        input integer line_idx;
        input integer word_idx;
        integer pix;
        integer x_coord;
        reg [127:0] tmp;
        begin
            tmp = 128'd0;
            for (pix = 0; pix < 16; pix = pix + 1) begin
                x_coord = word_idx * 16 + pix;
                tmp[pix * 8 +: 8] = nv12_y_sample(x_coord, line_idx);
            end
            nv12_y_word = tmp;
        end
    endfunction

    function automatic [7:0] nv12_u_sample;
        input integer pair_x;
        input integer uv_line;
        begin
            nv12_u_sample = (8'h30 + pair_x * 6 + uv_line * 9) & 8'hff;
        end
    endfunction

    function automatic [7:0] nv12_v_sample;
        input integer pair_x;
        input integer uv_line;
        begin
            nv12_v_sample = (8'h80 + pair_x * 4 + uv_line * 11) & 8'hff;
        end
    endfunction

    function automatic [127:0] nv12_uv_word;
        input integer uv_line;
        input integer word_idx;
        integer pair_idx;
        integer pair_x;
        reg [127:0] tmp;
        begin
            tmp = 128'd0;
            for (pair_idx = 0; pair_idx < 8; pair_idx = pair_idx + 1) begin
                pair_x = word_idx * 8 + pair_idx;
                tmp[(pair_idx * 2 + 0) * 8 +: 8] = nv12_u_sample(pair_x, uv_line);
                tmp[(pair_idx * 2 + 1) * 8 +: 8] = nv12_v_sample(pair_x, uv_line);
            end
            nv12_uv_word = tmp;
        end
    endfunction

    function automatic [7:0] nv16_y_sample;
        input integer x;
        input integer y;
        begin
            nv16_y_sample = ((((x >> 1) * 15) ^ (y * 27)) + (x[0] ? 8'h20 : 8'h70)) & 8'hff;
        end
    endfunction

    function automatic [127:0] nv16_y_word;
        input integer line_idx;
        input integer word_idx;
        integer pix;
        integer x_coord;
        reg [127:0] tmp;
        begin
            tmp = 128'd0;
            for (pix = 0; pix < 16; pix = pix + 1) begin
                x_coord = word_idx * 16 + pix;
                tmp[pix * 8 +: 8] = nv16_y_sample(x_coord, line_idx);
            end
            nv16_y_word = tmp;
        end
    endfunction

    function automatic [7:0] nv16_u_sample;
        input integer pair_x;
        input integer line_idx;
        begin
            nv16_u_sample = (8'h20 + line_idx * 7 + pair_x * 5) & 8'hff;
        end
    endfunction

    function automatic [7:0] nv16_v_sample;
        input integer pair_x;
        input integer line_idx;
        begin
            nv16_v_sample = (8'hd0 - line_idx * 9 + pair_x * 3) & 8'hff;
        end
    endfunction

    function automatic [127:0] nv16_uv_word;
        input integer line_idx;
        input integer word_idx;
        integer pair_idx;
        integer pair_x;
        reg [127:0] tmp;
        begin
            tmp = 128'd0;
            for (pair_idx = 0; pair_idx < 8; pair_idx = pair_idx + 1) begin
                pair_x = word_idx * 8 + pair_idx;
                tmp[(pair_idx * 2 + 0) * 8 +: 8] = nv16_u_sample(pair_x, line_idx);
                tmp[(pair_idx * 2 + 1) * 8 +: 8] = nv16_v_sample(pair_x, line_idx);
            end
            nv16_uv_word = tmp;
        end
    endfunction

    task automatic drive_axis_tile_header;
        input [4:0] fmt;
        input [15:0] tile_x;
        input [15:0] tile_y;
        begin
            @(negedge clk);
            s_axis_format     = fmt;
            s_axis_tile_x     = tile_x;
            s_axis_tile_y     = tile_y;
            s_axis_tile_valid = 1'b1;
            while (!s_axis_tile_ready) @(negedge clk);
            @(negedge clk);
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
            @(negedge clk);
            s_axis_tvalid  = 1'b1;
            s_axis_tdata   = {hi_word, lo_word};
            s_axis_tlast   = is_last;
            while (!s_axis_tready) @(negedge clk);
        end
    endtask

    task automatic axis_idle;
        begin
            @(negedge clk);
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
        input integer base_line;
        integer beat;
        integer word_lo_idx;
        integer word_hi_idx;
        begin
            drive_axis_tile_header(FMT_RGBA8888, 16'd0, (base_line >> 2));
            for (beat = 0; beat < 8; beat = beat + 1) begin
                word_lo_idx = beat * 2;
                word_hi_idx = beat * 2 + 1;
                drive_axis_beat(
                    FMT_RGBA8888,
                    rgba_word(base_line + (word_lo_idx >> 2), word_lo_idx & 3),
                    rgba_word(base_line + (word_hi_idx >> 2), word_hi_idx & 3),
                    16'd0,
                    (base_line >> 2),
                    beat == 7
                );
            end
            axis_idle();
        end
    endtask

    task automatic send_nv12_y_tile;
        input integer base_line;
        input integer tile_y;
        integer beat;
        integer word_lo_idx;
        integer word_hi_idx;
        begin
            drive_axis_tile_header(FMT_YUV420_Y, 16'd0, tile_y[15:0]);
            for (beat = 0; beat < 8; beat = beat + 1) begin
                word_lo_idx = beat * 2;
                word_hi_idx = beat * 2 + 1;
                drive_axis_beat(
                    FMT_YUV420_Y,
                    nv12_y_word(base_line + (word_lo_idx >> 1), word_lo_idx & 1),
                    nv12_y_word(base_line + (word_hi_idx >> 1), word_hi_idx & 1),
                    16'd0,
                    tile_y[15:0],
                    beat == 7
                );
            end
            axis_idle();
        end
    endtask

    task automatic send_nv12_uv_tile;
        input integer base_uv_line;
        input integer tile_y;
        integer beat;
        integer word_lo_idx;
        integer word_hi_idx;
        begin
            drive_axis_tile_header(FMT_YUV420_UV, 16'd0, tile_y[15:0]);
            for (beat = 0; beat < 8; beat = beat + 1) begin
                word_lo_idx = beat * 2;
                word_hi_idx = beat * 2 + 1;
                drive_axis_beat(
                    FMT_YUV420_UV,
                    nv12_uv_word(base_uv_line + (word_lo_idx >> 1), word_lo_idx & 1),
                    nv12_uv_word(base_uv_line + (word_hi_idx >> 1), word_hi_idx & 1),
                    16'd0,
                    tile_y[15:0],
                    beat == 7
                );
            end
            axis_idle();
        end
    endtask

    task automatic send_nv16_y_tile;
        input integer base_line;
        integer beat;
        integer word_lo_idx;
        integer word_hi_idx;
        begin
            drive_axis_tile_header(FMT_YUV422_Y, 16'd0, (base_line >> 3));
            for (beat = 0; beat < 8; beat = beat + 1) begin
                word_lo_idx = beat * 2;
                word_hi_idx = beat * 2 + 1;
                drive_axis_beat(
                    FMT_YUV422_Y,
                    nv16_y_word(base_line + (word_lo_idx >> 1), word_lo_idx & 1),
                    nv16_y_word(base_line + (word_hi_idx >> 1), word_hi_idx & 1),
                    16'd0,
                    (base_line >> 3),
                    beat == 7
                );
            end
            axis_idle();
        end
    endtask

    task automatic send_nv16_uv_tile;
        input integer base_line;
        integer beat;
        integer word_lo_idx;
        integer word_hi_idx;
        begin
            drive_axis_tile_header(FMT_YUV422_UV, 16'd0, (base_line >> 3));
            for (beat = 0; beat < 8; beat = beat + 1) begin
                word_lo_idx = beat * 2;
                word_hi_idx = beat * 2 + 1;
                drive_axis_beat(
                    FMT_YUV422_UV,
                    nv16_uv_word(base_line + (word_lo_idx >> 1), word_lo_idx & 1),
                    nv16_uv_word(base_line + (word_hi_idx >> 1), word_hi_idx & 1),
                    16'd0,
                    (base_line >> 3),
                    beat == 7
                );
            end
            axis_idle();
        end
    endtask

    task automatic wait_for_fetch_done;
        input integer expected_done_count;
        integer timeout;
        begin
            timeout = 0;
            while ((fetch_done_count < expected_done_count) && (timeout < 2000)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 2000) begin
                $fatal(1, "Timeout waiting for fetch_done_count=%0d", expected_done_count);
            end
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic check_rgba_pattern;
        input integer start_idx;
        input integer base_line;
        integer idx;
        integer exp_line;
        integer exp_word;
        begin
            if ((out_count - start_idx) != 8) begin
                $fatal(1, "RGBA output count mismatch. got=%0d exp=8", out_count - start_idx);
            end
            for (idx = 0; idx < 8; idx = idx + 1) begin
                exp_line = base_line + ((idx * 2) >> 2);
                exp_word = (idx * 2) & 3;
                if (observed_fifo[start_idx + idx][127:0] !== rgba_word(exp_line, exp_word)) begin
                    $fatal(1, "RGBA low-half mismatch at idx=%0d", idx);
                end
                exp_line = base_line + (((idx * 2) + 1) >> 2);
                exp_word = ((idx * 2) + 1) & 3;
                if (observed_fifo[start_idx + idx][255:128] !== rgba_word(exp_line, exp_word)) begin
                    $fatal(1, "RGBA high-half mismatch at idx=%0d", idx);
                end
            end
        end
    endtask

    task automatic check_nv12_pattern;
        input integer start_idx;
        input integer base_line;
        input integer base_uv_line;
        integer line_idx;
        integer word_idx;
        integer obs_idx;
        begin
            if ((out_count - start_idx) != 32) begin
                $fatal(1, "NV12 output count mismatch. got=%0d exp=32", out_count - start_idx);
            end
            for (line_idx = 0; line_idx < 16; line_idx = line_idx + 1) begin
                for (word_idx = 0; word_idx < 2; word_idx = word_idx + 1) begin
                    obs_idx = start_idx + line_idx * 2 + word_idx;
                    if (observed_fifo[obs_idx][127:0] !== nv12_y_word(base_line + line_idx, word_idx)) begin
                        $fatal(1, "NV12 Y mismatch line=%0d word=%0d", line_idx, word_idx);
                    end
                    if (observed_fifo[obs_idx][255:128] !== nv12_uv_word(base_uv_line + (line_idx >> 1), word_idx)) begin
                        $fatal(1, "NV12 UV mismatch line=%0d word=%0d", line_idx, word_idx);
                    end
                end
            end
        end
    endtask

    task automatic check_nv16_pattern;
        input integer start_idx;
        input integer base_line;
        integer line_idx;
        integer word_idx;
        integer obs_idx;
        begin
            if ((out_count - start_idx) != 16) begin
                $fatal(1, "NV16 output count mismatch. got=%0d exp=16", out_count - start_idx);
            end
            for (line_idx = 0; line_idx < 8; line_idx = line_idx + 1) begin
                for (word_idx = 0; word_idx < 2; word_idx = word_idx + 1) begin
                    obs_idx = start_idx + line_idx * 2 + word_idx;
                    if (observed_fifo[obs_idx][127:0] !== nv16_y_word(base_line + line_idx, word_idx)) begin
                        $fatal(1, "NV16 Y mismatch line=%0d word=%0d", line_idx, word_idx);
                    end
                    if (observed_fifo[obs_idx][255:128] !== nv16_uv_word(base_line + line_idx, word_idx)) begin
                        $fatal(1, "NV16 UV mismatch line=%0d word=%0d", line_idx, word_idx);
                    end
                end
            end
        end
    endtask

    tile_to_line_writer dut_writer (
        .clk_sram       (clk),
        .rst_n          (rst_n),
        .cfg_img_width  (cfg_img_width),
        .i_sram_a_free  (sram_a_free),
        .i_sram_b_free  (sram_b_free),
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
        .sram_b_wen     (sram_b_wen),
        .sram_b_waddr   (sram_b_waddr),
        .sram_b_wdata   (sram_b_wdata),
        .o_writer_bank  (writer_bank),
        .o_buffer_vld   (writer_vld)
    );

    sram_pdp_8192x128 u_sram_bank_a (
        .clk        (clk),
        .wen        (sram_a_wen),
        .waddr      (sram_a_waddr),
        .wdata      (sram_a_wdata),
        .ren        (sram_a_ren),
        .raddr      (sram_a_raddr),
        .rdata      (sram_a_rdata)
    );

    sram_pdp_8192x128 u_sram_bank_b (
        .clk        (clk),
        .wen        (sram_b_wen),
        .waddr      (sram_b_waddr),
        .wdata      (sram_b_wdata),
        .ren        (sram_b_ren),
        .raddr      (sram_b_raddr),
        .rdata      (sram_b_rdata)
    );

    sram_read_fetcher dut_fetcher (
        .clk_sram       (clk),
        .rst_n          (rst_n),
        .cfg_img_width  (cfg_img_width),
        .cfg_format     (cfg_format),
        .i_buffer_vld   (writer_vld),
        .i_writer_bank  (writer_bank),
        .o_sram_a_ren   (sram_a_ren),
        .o_sram_a_raddr (sram_a_raddr),
        .i_sram_a_rdata (sram_a_rdata),
        .o_sram_b_ren   (sram_b_ren),
        .o_sram_b_raddr (sram_b_raddr),
        .i_sram_b_rdata (sram_b_rdata),
        .o_fifo_wr_en   (fifo_wr_en),
        .o_fifo_wdata   (fifo_wdata),
        .i_fifo_full    (1'b0),
        .o_fetcher_done (fetcher_done),
        .o_fetcher_bank (fetcher_bank)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sram_a_free <= 1'b1;
            sram_b_free <= 1'b1;
        end else begin
            if (writer_vld && (writer_bank == 1'b0)) sram_a_free <= 1'b0;
            else if (fetcher_done && (fetcher_bank == 1'b0)) sram_a_free <= 1'b1;

            if (writer_vld && (writer_bank == 1'b1)) sram_b_free <= 1'b0;
            else if (fetcher_done && (fetcher_bank == 1'b1)) sram_b_free <= 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_count <= 0;
            writer_vld_count <= 0;
            fetch_done_count <= 0;
        end else begin
            if (fifo_wr_en) begin
                observed_fifo[out_count] <= fifo_wdata;
                out_count <= out_count + 1;
            end
            if (writer_vld) writer_vld_count <= writer_vld_count + 1;
            if (fetcher_done) fetch_done_count <= fetch_done_count + 1;
        end
    end

    initial begin
        integer start_idx;
        integer start_writer_done;
        integer start_fetch_done;

        rst_n         = 1'b0;
        cfg_img_width = 16'd0;
        cfg_format    = 5'd0;
        s_axis_tdata  = 256'd0;
        s_axis_tlast  = 1'b0;
        s_axis_format = 5'd0;
        s_axis_tile_x = 16'd0;
        s_axis_tile_y = 16'd0;
        s_axis_tile_valid = 1'b0;
        s_axis_tvalid = 1'b0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        $display("");
        $display("=======================================================");
        $display("TB: ubwc_dec image-style format patterns");
        $display("Case1 RGBA8888 : 16x4  gradient + texture");
        $display("Case2 NV12     : 32x16 luma ramp + chroma bars");
        $display("Case3 NV16     : 32x8  luma checker + chroma stripes");
        $display("=======================================================");

        cfg_img_width = 16'd16;
        cfg_format    = FMT_RGBA8888;
        start_idx = out_count;
        start_writer_done = writer_vld_count;
        start_fetch_done = fetch_done_count;
        send_rgba_tile(0);
        wait_for_fetch_done(start_fetch_done + 1);
        if ((writer_vld_count - start_writer_done) != 1) begin
            $fatal(1, "RGBA writer_vld count mismatch");
        end
        check_rgba_pattern(start_idx, 0);

        cfg_img_width = 16'd32;
        cfg_format    = FMT_YUV420_Y;
        start_idx = out_count;
        start_writer_done = writer_vld_count;
        start_fetch_done = fetch_done_count;
        send_nv12_y_tile(0, 0);
        send_nv12_y_tile(8, 0);
        send_nv12_uv_tile(0, 0);
        wait_for_fetch_done(start_fetch_done + 1);
        if ((writer_vld_count - start_writer_done) != 1) begin
            $fatal(1, "NV12 writer_vld count mismatch");
        end
        check_nv12_pattern(start_idx, 0, 0);

        cfg_img_width = 16'd32;
        cfg_format    = FMT_YUV422_Y;
        start_idx = out_count;
        start_writer_done = writer_vld_count;
        start_fetch_done = fetch_done_count;
        send_nv16_y_tile(0);
        send_nv16_uv_tile(0);
        wait_for_fetch_done(start_fetch_done + 1);
        if ((writer_vld_count - start_writer_done) != 1) begin
            $fatal(1, "NV16 writer_vld count mismatch");
        end
        check_nv16_pattern(start_idx, 0);

        $display("PASS: image-style mainstream format patterns completed");
        repeat (10) @(posedge clk);
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_tile_to_line_image_formats.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_tile_to_line_image_formats);
        $fsdbDumpMDA(0, tb_ubwc_dec_tile_to_line_image_formats);
`else
        $dumpfile("tb_ubwc_dec_tile_to_line_image_formats.vcd");
        $dumpvars(0, tb_ubwc_dec_tile_to_line_image_formats);
`endif
`endif
    end

endmodule
