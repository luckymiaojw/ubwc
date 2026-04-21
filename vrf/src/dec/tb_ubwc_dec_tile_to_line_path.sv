`timescale 1ns/1ps

module tb_ubwc_dec_tile_to_line_path;

    localparam [4:0] FMT_RGBA8888 = 5'b00000;
    localparam [4:0] FMT_RGBA_ALT = 5'b00001;
    localparam [4:0] FMT_YUV420_Y = 5'b01000;
    localparam [4:0] FMT_YUV420_UV = 5'b01001;
    localparam [4:0] FMT_P010_UV = 5'b01110;
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

    function automatic [127:0] make_word;
        input [31:0] seed;
        begin
            make_word = {4{seed}};
        end
    endfunction

    task automatic send_tile_header;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        begin
            @(negedge clk);
            s_axis_format     = fmt;
            s_axis_tile_x     = tile_x[15:0];
            s_axis_tile_y     = tile_y[15:0];
            s_axis_tile_valid = 1'b1;
            while (!s_axis_tile_ready) @(negedge clk);
            @(negedge clk);
            s_axis_tile_valid = 1'b0;
        end
    endtask

    task automatic send_tile;
        input [4:0] fmt;
        input integer base_word_id;
        input integer tile_x;
        input integer tile_y;
        integer beat;
        begin
            send_tile_header(fmt, tile_x, tile_y);
            for (beat = 0; beat < 8; beat = beat + 1) begin
                @(negedge clk);
                s_axis_tvalid  = 1'b1;
                s_axis_tdata   = {make_word(base_word_id + beat * 2 + 1),
                                  make_word(base_word_id + beat * 2)};
                s_axis_tlast   = (beat == 7);
                while (!s_axis_tready) @(negedge clk);
            end

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

    task automatic check_rgba_case;
        input integer start_idx;
        input integer base_word_id;
        integer i;
        begin
            if ((out_count - start_idx) != 8) begin
                $fatal(1, "RGBA case output count mismatch. got=%0d exp=8", out_count - start_idx);
            end
            for (i = 0; i < 8; i = i + 1) begin
                if (observed_fifo[start_idx + i][127:0] !== make_word(base_word_id + i * 2)) begin
                    $fatal(1, "RGBA Y mismatch at idx=%0d got=%h exp=%h",
                           i, observed_fifo[start_idx + i][127:0], make_word(base_word_id + i * 2));
                end
                if (observed_fifo[start_idx + i][255:128] !== make_word(base_word_id + i * 2 + 1)) begin
                    $fatal(1, "RGBA upper-half mismatch at idx=%0d got=%h exp=%h",
                           i, observed_fifo[start_idx + i][255:128], make_word(base_word_id + i * 2 + 1));
                end
            end
        end
    endtask

    task automatic check_yuv420_case;
        input integer start_idx;
        input integer base_y0;
        input integer base_y1;
        input integer base_uv;
        integer line_idx;
        integer word_idx;
        integer obs_idx;
        integer exp_y_id;
        integer exp_uv_id;
        begin
            if ((out_count - start_idx) != 32) begin
                $fatal(1, "YUV420 case output count mismatch. got=%0d exp=32", out_count - start_idx);
            end
            for (line_idx = 0; line_idx < 16; line_idx = line_idx + 1) begin
                for (word_idx = 0; word_idx < 2; word_idx = word_idx + 1) begin
                    obs_idx = start_idx + line_idx * 2 + word_idx;
                    exp_y_id = (line_idx < 8) ? (base_y0 + line_idx * 2 + word_idx)
                                              : (base_y1 + (line_idx - 8) * 2 + word_idx);
                    exp_uv_id = base_uv + (line_idx >> 1) * 2 + word_idx;
                    if (observed_fifo[obs_idx][127:0] !== make_word(exp_y_id)) begin
                        $fatal(1, "YUV420 Y mismatch line=%0d word=%0d got=%h exp=%h",
                               line_idx, word_idx, observed_fifo[obs_idx][127:0], make_word(exp_y_id));
                    end
                    if (observed_fifo[obs_idx][255:128] !== make_word(exp_uv_id)) begin
                        $fatal(1, "YUV420 UV mismatch line=%0d word=%0d got=%h exp=%h",
                               line_idx, word_idx, observed_fifo[obs_idx][255:128], make_word(exp_uv_id));
                    end
                end
            end
        end
    endtask

    task automatic check_yuv422_case;
        input integer start_idx;
        input integer base_y;
        input integer base_uv;
        integer line_idx;
        integer word_idx;
        integer obs_idx;
        integer exp_y_id;
        integer exp_uv_id;
        begin
            if ((out_count - start_idx) != 16) begin
                $fatal(1, "YUV422 case output count mismatch. got=%0d exp=16", out_count - start_idx);
            end
            for (line_idx = 0; line_idx < 8; line_idx = line_idx + 1) begin
                for (word_idx = 0; word_idx < 2; word_idx = word_idx + 1) begin
                    obs_idx = start_idx + line_idx * 2 + word_idx;
                    exp_y_id = base_y + line_idx * 2 + word_idx;
                    exp_uv_id = base_uv + line_idx * 2 + word_idx;
                    if (observed_fifo[obs_idx][127:0] !== make_word(exp_y_id)) begin
                        $fatal(1, "YUV422 Y mismatch line=%0d word=%0d got=%h exp=%h",
                               line_idx, word_idx, observed_fifo[obs_idx][127:0], make_word(exp_y_id));
                    end
                    if (observed_fifo[obs_idx][255:128] !== make_word(exp_uv_id)) begin
                        $fatal(1, "YUV422 UV mismatch line=%0d word=%0d got=%h exp=%h",
                               line_idx, word_idx, observed_fifo[obs_idx][255:128], make_word(exp_uv_id));
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
        $display("==============================================");
        $display("TB: ubwc_dec tile-to-line writer/fetcher path");
        $display("==============================================");

        cfg_img_width = 16'd16;
        cfg_format    = FMT_RGBA_ALT;
        start_idx = out_count;
        start_writer_done = writer_vld_count;
        start_fetch_done = fetch_done_count;
        send_tile(FMT_RGBA_ALT, 32'h10, 0, 0);
        wait_for_fetch_done(start_fetch_done + 1);
        if ((writer_vld_count - start_writer_done) != 1) begin
            $fatal(1, "RGBA case writer_vld count mismatch");
        end
        check_rgba_case(start_idx, 32'h10);

        cfg_img_width = 16'd32;
        cfg_format    = FMT_YUV420_Y;
        start_idx = out_count;
        start_writer_done = writer_vld_count;
        start_fetch_done = fetch_done_count;
        send_tile(FMT_YUV420_Y, 32'h100, 0, 0);
        send_tile(FMT_YUV420_Y, 32'h200, 0, 0);
        send_tile(FMT_P010_UV, 32'h300, 0, 0);
        wait_for_fetch_done(start_fetch_done + 1);
        if ((writer_vld_count - start_writer_done) != 1) begin
            $fatal(1, "YUV420 case writer_vld count mismatch");
        end
        check_yuv420_case(start_idx, 32'h100, 32'h200, 32'h300);

        cfg_img_width = 16'd32;
        cfg_format    = FMT_YUV422_Y;
        start_idx = out_count;
        start_writer_done = writer_vld_count;
        start_fetch_done = fetch_done_count;
        send_tile(FMT_YUV422_Y, 32'h500, 0, 0);
        send_tile(FMT_YUV422_UV, 32'h600, 0, 0);
        wait_for_fetch_done(start_fetch_done + 1);
        if ((writer_vld_count - start_writer_done) != 1) begin
            $fatal(1, "YUV422 case writer_vld count mismatch");
        end
        check_yuv422_case(start_idx, 32'h500, 32'h600);

        $display("PASS: all tile-to-line path cases completed");
        repeat (10) @(posedge clk);
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_tile_to_line_path.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_tile_to_line_path);
        $fsdbDumpMDA(0, tb_ubwc_dec_tile_to_line_path);
`else
        $dumpfile("tb_ubwc_dec_tile_to_line_path.vcd");
        $dumpvars(0, tb_ubwc_dec_tile_to_line_path);
`endif
`endif
    end

endmodule
