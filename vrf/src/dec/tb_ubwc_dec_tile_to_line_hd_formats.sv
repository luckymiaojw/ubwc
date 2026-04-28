`timescale 1ns/1ps

module tb_ubwc_dec_tile_to_line_hd_formats;

    localparam integer HD_W = 1920;

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
    reg [255:0]   observed_fifo [0:8191];

    function automatic [31:0] rgba_pixel;
        input integer x;
        input integer y;
        reg [7:0] r;
        reg [7:0] g;
        reg [7:0] b;
        reg [7:0] a;
        begin
            r = ((x * 3)  + (y * 5)) & 8'hff;
            g = ((x * 7)  + (y * 11)) & 8'hff;
            b = ((x * 13) ^ (y * 17)) & 8'hff;
            a = 8'hff;
            rgba_pixel = {a, b, g, r};
        end
    endfunction

    function automatic [127:0] rgba_word_hd;
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
            rgba_word_hd = tmp;
        end
    endfunction

    function automatic [7:0] nv12_y_sample;
        input integer x;
        input integer y;
        begin
            nv12_y_sample = ((x * 2) + (y * 9)) & 8'hff;
        end
    endfunction

    function automatic [127:0] nv12_y_word_hd;
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
            nv12_y_word_hd = tmp;
        end
    endfunction

    function automatic [7:0] nv12_u_sample;
        input integer pair_x;
        input integer uv_line;
        begin
            nv12_u_sample = (8'h20 + pair_x * 3 + uv_line * 7) & 8'hff;
        end
    endfunction

    function automatic [7:0] nv12_v_sample;
        input integer pair_x;
        input integer uv_line;
        begin
            nv12_v_sample = (8'h90 + pair_x * 5 + uv_line * 11) & 8'hff;
        end
    endfunction

    function automatic [127:0] nv12_uv_word_hd;
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
            nv12_uv_word_hd = tmp;
        end
    endfunction

    function automatic [7:0] nv16_y_sample;
        input integer x;
        input integer y;
        begin
            nv16_y_sample = (((x >> 1) * 21) + (y * 19) + (x[0] ? 8'h10 : 8'h70)) & 8'hff;
        end
    endfunction

    function automatic [127:0] nv16_y_word_hd;
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
            nv16_y_word_hd = tmp;
        end
    endfunction

    function automatic [7:0] nv16_u_sample;
        input integer pair_x;
        input integer line_idx;
        begin
            nv16_u_sample = (8'h30 + pair_x * 4 + line_idx * 5) & 8'hff;
        end
    endfunction

    function automatic [7:0] nv16_v_sample;
        input integer pair_x;
        input integer line_idx;
        begin
            nv16_v_sample = (8'hc0 + pair_x * 2 + line_idx * 9) & 8'hff;
        end
    endfunction

    function automatic [127:0] nv16_uv_word_hd;
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
            nv16_uv_word_hd = tmp;
        end
    endfunction

    task automatic drive_axis_tile_header;
        input [4:0] fmt;
        input [15:0] tile_x;
        input [15:0] tile_y;
        integer timeout;
        begin
            @(negedge clk);
            s_axis_tvalid    = 1'b0;
            s_axis_tdata     = 256'd0;
            s_axis_tlast     = 1'b0;
            s_axis_format     = fmt;
            s_axis_tile_x     = tile_x;
            s_axis_tile_y     = tile_y;
            s_axis_tile_valid = 1'b1;
            timeout = 0;
            while (!s_axis_tile_ready && (timeout < 10000)) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 10000) begin
                $fatal(1, "Timeout waiting tile_ready fmt=%0d x=%0d y=%0d credit=%0d hdr_full=%0b data_full=%0b data_count=%0d",
                       fmt, tile_x, tile_y, dut_writer.data_credit_used, dut_writer.hdr_fifo_full,
                       dut_writer.data_fifo_full, dut_writer.data_fifo_data_count);
            end
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
        integer timeout;
        begin
            @(negedge clk);
            s_axis_tvalid  = 1'b1;
            s_axis_tdata   = {hi_word, lo_word};
            s_axis_tlast   = is_last;
            timeout = 0;
            while (!s_axis_tready && (timeout < 10000)) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 10000) begin
                $fatal(1, "Timeout waiting tready fmt=%0d x=%0d y=%0d last=%0d credit=%0d hdr_empty=%0b data_full=%0b data_count=%0d",
                       fmt, tile_x, tile_y, is_last, dut_writer.data_credit_used, dut_writer.hdr_fifo_empty,
                       dut_writer.data_fifo_full, dut_writer.data_fifo_data_count);
            end
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

    task automatic send_rgba_hd_slice;
        input integer base_line;
        integer tile_x;
        integer beat;
        integer local_lo;
        integer local_hi;
        integer line_lo;
        integer line_hi;
        integer word_lo;
        integer word_hi;
        begin
            for (tile_x = 0; tile_x < 120; tile_x = tile_x + 1) begin
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
                        rgba_word_hd(base_line + line_lo, word_lo),
                        rgba_word_hd(base_line + line_hi, word_hi),
                        tile_x[15:0],
                        (base_line >> 2),
                        (beat == 7)
                    );
                end
            end
            axis_idle();
        end
    endtask

    task automatic send_nv12_y_rowgroup_hd;
        input integer base_line;
        input integer tile_y;
        integer tile_x;
        integer beat;
        integer local_lo;
        integer local_hi;
        integer line_lo;
        integer line_hi;
        integer word_lo;
        integer word_hi;
        begin
            for (tile_x = 0; tile_x < 60; tile_x = tile_x + 1) begin
                drive_axis_tile_header(FMT_YUV420_Y, tile_x[15:0], tile_y[15:0]);
                for (beat = 0; beat < 8; beat = beat + 1) begin
                    local_lo = beat * 2;
                    local_hi = beat * 2 + 1;
                    line_lo  = local_lo >> 1;
                    line_hi  = local_hi >> 1;
                    word_lo  = tile_x * 2 + (local_lo & 1);
                    word_hi  = tile_x * 2 + (local_hi & 1);
                    drive_axis_beat(
                        FMT_YUV420_Y,
                        nv12_y_word_hd(base_line + line_lo, word_lo),
                        nv12_y_word_hd(base_line + line_hi, word_hi),
                        tile_x[15:0],
                        tile_y[15:0],
                        (beat == 7)
                    );
                end
            end
            axis_idle();
        end
    endtask

    task automatic send_nv12_uv_rowgroup_hd;
        input integer base_uv_line;
        input integer tile_y;
        integer tile_x;
        integer beat;
        integer local_lo;
        integer local_hi;
        integer line_lo;
        integer line_hi;
        integer word_lo;
        integer word_hi;
        begin
            for (tile_x = 0; tile_x < 60; tile_x = tile_x + 1) begin
                drive_axis_tile_header(FMT_YUV420_UV, tile_x[15:0], tile_y[15:0]);
                for (beat = 0; beat < 8; beat = beat + 1) begin
                    local_lo = beat * 2;
                    local_hi = beat * 2 + 1;
                    line_lo  = local_lo >> 1;
                    line_hi  = local_hi >> 1;
                    word_lo  = tile_x * 2 + (local_lo & 1);
                    word_hi  = tile_x * 2 + (local_hi & 1);
                    drive_axis_beat(
                        FMT_YUV420_UV,
                        nv12_uv_word_hd(base_uv_line + line_lo, word_lo),
                        nv12_uv_word_hd(base_uv_line + line_hi, word_hi),
                        tile_x[15:0],
                        tile_y[15:0],
                        (beat == 7)
                    );
                end
            end
            axis_idle();
        end
    endtask

    task automatic send_nv16_y_rowgroup_hd;
        input integer base_line;
        integer tile_x;
        integer beat;
        integer local_lo;
        integer local_hi;
        integer line_lo;
        integer line_hi;
        integer word_lo;
        integer word_hi;
        begin
            for (tile_x = 0; tile_x < 60; tile_x = tile_x + 1) begin
                drive_axis_tile_header(FMT_YUV422_Y, tile_x[15:0], (base_line >> 3));
                for (beat = 0; beat < 8; beat = beat + 1) begin
                    local_lo = beat * 2;
                    local_hi = beat * 2 + 1;
                    line_lo  = local_lo >> 1;
                    line_hi  = local_hi >> 1;
                    word_lo  = tile_x * 2 + (local_lo & 1);
                    word_hi  = tile_x * 2 + (local_hi & 1);
                    drive_axis_beat(
                        FMT_YUV422_Y,
                        nv16_y_word_hd(base_line + line_lo, word_lo),
                        nv16_y_word_hd(base_line + line_hi, word_hi),
                        tile_x[15:0],
                        (base_line >> 3),
                        (beat == 7)
                    );
                end
            end
            axis_idle();
        end
    endtask

    task automatic send_nv16_uv_rowgroup_hd;
        input integer base_line;
        integer tile_x;
        integer beat;
        integer local_lo;
        integer local_hi;
        integer line_lo;
        integer line_hi;
        integer word_lo;
        integer word_hi;
        begin
            for (tile_x = 0; tile_x < 60; tile_x = tile_x + 1) begin
                drive_axis_tile_header(FMT_YUV422_UV, tile_x[15:0], (base_line >> 3));
                for (beat = 0; beat < 8; beat = beat + 1) begin
                    local_lo = beat * 2;
                    local_hi = beat * 2 + 1;
                    line_lo  = local_lo >> 1;
                    line_hi  = local_hi >> 1;
                    word_lo  = tile_x * 2 + (local_lo & 1);
                    word_hi  = tile_x * 2 + (local_hi & 1);
                    drive_axis_beat(
                        FMT_YUV422_UV,
                        nv16_uv_word_hd(base_line + line_lo, word_lo),
                        nv16_uv_word_hd(base_line + line_hi, word_hi),
                        tile_x[15:0],
                        (base_line >> 3),
                        (beat == 7)
                    );
                end
            end
            axis_idle();
        end
    endtask

    task automatic wait_for_fetch_done;
        input integer expected_done_count;
        integer timeout;
        begin
            timeout = 0;
            while ((fetch_done_count < expected_done_count) && (timeout < 50000)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 50000) begin
                $fatal(1, "Timeout waiting for fetch_done_count=%0d", expected_done_count);
            end
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic check_rgba_hd_slice;
        input integer start_idx;
        input integer base_line;
        integer line_idx;
        integer word_idx;
        integer pair_idx;
        integer obs_idx;
        begin
            if ((out_count - start_idx) != 960) begin
                $fatal(1, "RGBA HD output count mismatch. got=%0d exp=960", out_count - start_idx);
            end
            for (line_idx = 0; line_idx < 4; line_idx = line_idx + 1) begin
                for (pair_idx = 0; pair_idx < 240; pair_idx = pair_idx + 1) begin
                    word_idx = pair_idx * 2;
                    obs_idx = start_idx + line_idx * 240 + pair_idx;
                    if (observed_fifo[obs_idx][127:0] !== rgba_word_hd(base_line + line_idx, word_idx)) begin
                        $fatal(1, "RGBA HD low-half mismatch line=%0d word=%0d", line_idx, word_idx);
                    end
                    if (observed_fifo[obs_idx][255:128] !== rgba_word_hd(base_line + line_idx, word_idx + 1)) begin
                        $fatal(1, "RGBA HD high-half mismatch line=%0d word=%0d", line_idx, word_idx + 1);
                    end
                end
            end
        end
    endtask

    task automatic check_nv12_hd_slice;
        input integer start_idx;
        input integer base_line;
        input integer base_uv_line;
        integer line_idx;
        integer word_idx;
        integer obs_idx;
        begin
            if ((out_count - start_idx) != 1920) begin
                $fatal(1, "NV12 HD output count mismatch. got=%0d exp=1920", out_count - start_idx);
            end
            for (line_idx = 0; line_idx < 16; line_idx = line_idx + 1) begin
                for (word_idx = 0; word_idx < 120; word_idx = word_idx + 1) begin
                    obs_idx = start_idx + line_idx * 120 + word_idx;
                    if (observed_fifo[obs_idx][127:0] !== nv12_y_word_hd(base_line + line_idx, word_idx)) begin
                        $fatal(1, "NV12 HD Y mismatch line=%0d word=%0d", line_idx, word_idx);
                    end
                    if (observed_fifo[obs_idx][255:128] !== nv12_uv_word_hd(base_uv_line + (line_idx >> 1), word_idx)) begin
                        $fatal(1, "NV12 HD UV mismatch line=%0d word=%0d", line_idx, word_idx);
                    end
                end
            end
        end
    endtask

    task automatic check_nv16_hd_slice;
        input integer start_idx;
        input integer base_line;
        integer line_idx;
        integer word_idx;
        integer obs_idx;
        begin
            if ((out_count - start_idx) != 960) begin
                $fatal(1, "NV16 HD output count mismatch. got=%0d exp=960", out_count - start_idx);
            end
            for (line_idx = 0; line_idx < 8; line_idx = line_idx + 1) begin
                for (word_idx = 0; word_idx < 120; word_idx = word_idx + 1) begin
                    obs_idx = start_idx + line_idx * 120 + word_idx;
                    if (observed_fifo[obs_idx][127:0] !== nv16_y_word_hd(base_line + line_idx, word_idx)) begin
                        $fatal(1, "NV16 HD Y mismatch line=%0d word=%0d", line_idx, word_idx);
                    end
                    if (observed_fifo[obs_idx][255:128] !== nv16_uv_word_hd(base_line + line_idx, word_idx)) begin
                        $fatal(1, "NV16 HD UV mismatch line=%0d word=%0d", line_idx, word_idx);
                    end
                end
            end
        end
    endtask

    tile_to_line_writer dut_writer (
        .clk_sram       (clk),
        .rst_n          (rst_n),
        .i_frame_start  (1'b0),
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
        $display("==========================================================");
        $display("TB: HD-width image slices derived from 1920x1080 use case");
        $display("RGBA8888 slice : 1920x4   (270 slices for full 1080p)");
        $display("NV12 slice     : 1920x16  (68 padded slices for 1080p->1088)");
        $display("NV16 slice     : 1920x8   (135 slices for full 1080p)");
        $display("==========================================================");

        cfg_img_width = HD_W[15:0];
        cfg_format    = FMT_RGBA8888;
        start_idx = out_count;
        start_writer_done = writer_vld_count;
        start_fetch_done = fetch_done_count;
        send_rgba_hd_slice(0);
        wait_for_fetch_done(start_fetch_done + 1);
        if ((writer_vld_count - start_writer_done) != 1) begin
            $fatal(1, "RGBA HD writer_vld count mismatch");
        end
        check_rgba_hd_slice(start_idx, 0);

        cfg_img_width = HD_W[15:0];
        cfg_format    = FMT_YUV420_Y;
        start_idx = out_count;
        start_writer_done = writer_vld_count;
        start_fetch_done = fetch_done_count;
        send_nv12_y_rowgroup_hd(0, 0);
        send_nv12_y_rowgroup_hd(8, 0);
        send_nv12_uv_rowgroup_hd(0, 0);
        wait_for_fetch_done(start_fetch_done + 1);
        if ((writer_vld_count - start_writer_done) != 1) begin
            $fatal(1, "NV12 HD writer_vld count mismatch");
        end
        check_nv12_hd_slice(start_idx, 0, 0);

        cfg_img_width = HD_W[15:0];
        cfg_format    = FMT_YUV422_Y;
        start_idx = out_count;
        start_writer_done = writer_vld_count;
        start_fetch_done = fetch_done_count;
        send_nv16_y_rowgroup_hd(0);
        send_nv16_uv_rowgroup_hd(0);
        wait_for_fetch_done(start_fetch_done + 1);
        if ((writer_vld_count - start_writer_done) != 1) begin
            $fatal(1, "NV16 HD writer_vld count mismatch");
        end
        check_nv16_hd_slice(start_idx, 0);

        $display("PASS: HD-width mainstream format slices completed");
        repeat (10) @(posedge clk);
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_tile_to_line_hd_formats.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_tile_to_line_hd_formats);
        $fsdbDumpMDA(0, tb_ubwc_dec_tile_to_line_hd_formats);
`else
        $dumpfile("tb_ubwc_dec_tile_to_line_hd_formats.vcd");
        $dumpvars(0, tb_ubwc_dec_tile_to_line_hd_formats);
`endif
`endif
    end

endmodule
