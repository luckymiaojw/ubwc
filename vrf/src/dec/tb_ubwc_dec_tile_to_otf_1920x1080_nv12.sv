`timescale 1ns/1ps

module tb_ubwc_dec_tile_to_otf_1920x1080_nv12;

    localparam integer IMG_W = 1920;
    localparam integer IMG_H = 1080;
    localparam integer TILE_W = 32;
    localparam integer Y_ROWGROUP_LINES = 8;
    localparam integer SLICE_LINES = 16;
    localparam integer UV_ROWGROUP_LINES = 8;
    localparam integer TILE_X_COUNT = (IMG_W + TILE_W - 1) / TILE_W;
    localparam integer SLICE_COUNT = (IMG_H + SLICE_LINES - 1) / SLICE_LINES;
    localparam integer FRAME_PIXEL_COUNT = IMG_W * IMG_H;

    localparam integer OTF_H_SYNC  = 44;
    localparam integer OTF_H_BP    = 148;
    localparam integer OTF_H_FP    = 88;
    localparam integer OTF_H_TOTAL = OTF_H_SYNC + OTF_H_BP + IMG_W + OTF_H_FP;

    localparam [4:0] FMT_YUV420_Y  = 5'b01000;
    localparam [4:0] FMT_YUV420_UV = 5'b01001;

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

    integer       sent_tile_count;
    integer       checked_pixel_count;
    integer       active_x;
    integer       active_y;
    reg           sending_done;
    reg           frame_done;

    function automatic [7:0] nv12_y_sample;
        input integer x;
        input integer y;
        begin
            nv12_y_sample = ((x * 2) + (y * 9)) & 8'hff;
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

    task automatic drive_axis_tile_header;
        input [4:0] fmt;
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

    task automatic send_nv12_y_rowgroup;
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
            for (tile_x = 0; tile_x < TILE_X_COUNT; tile_x = tile_x + 1) begin
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
                        nv12_y_word(base_line + line_lo, word_lo),
                        nv12_y_word(base_line + line_hi, word_hi),
                        tile_x[15:0],
                        tile_y[15:0],
                        (beat == 7)
                    );
                end
                sent_tile_count = sent_tile_count + 1;
            end
            axis_idle();
        end
    endtask

    task automatic send_nv12_uv_rowgroup;
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
            for (tile_x = 0; tile_x < TILE_X_COUNT; tile_x = tile_x + 1) begin
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
                        nv12_uv_word(base_uv_line + line_lo, word_lo),
                        nv12_uv_word(base_uv_line + line_hi, word_hi),
                        tile_x[15:0],
                        tile_y[15:0],
                        (beat == 7)
                    );
                end
                sent_tile_count = sent_tile_count + 1;
            end
            axis_idle();
        end
    endtask

    task automatic send_full_nv12_frame;
        integer slice_idx;
        integer base_line;
        integer base_uv_line;
        begin
            for (slice_idx = 0; slice_idx < SLICE_COUNT; slice_idx = slice_idx + 1) begin
                // One YUV420 slice is sent as full-width Y upper, Y lower, then UV.
                base_line = slice_idx * SLICE_LINES;
                base_uv_line = slice_idx * UV_ROWGROUP_LINES;
                send_nv12_y_rowgroup(base_line + 0, slice_idx);
                send_nv12_y_rowgroup(base_line + Y_ROWGROUP_LINES, slice_idx);
                send_nv12_uv_rowgroup(base_uv_line, slice_idx);
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
        .rst_n          (rst_n),
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
        .sram_b_wen     (sram_b_wen),
        .sram_b_waddr   (sram_b_waddr),
        .sram_b_wdata   (sram_b_wdata),
        .sram_b_ren     (sram_b_ren),
        .sram_b_raddr   (sram_b_raddr),
        .sram_b_rdata   (sram_b_rdata),
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

    always @(posedge clk_otf or negedge rst_n) begin
        integer uv_line;
        integer pair_x0;
        integer pair_x1;
        reg [127:0] exp_data;
        if (!rst_n) begin
            checked_pixel_count <= 0;
            active_x <= 0;
            active_y <= 0;
            frame_done <= 1'b0;
        end else if (i_otf_ready && o_otf_de && !frame_done) begin
            uv_line = active_y >> 1;
            pair_x0 = active_x >> 1;
            pair_x1 = pair_x0 + 1;

            exp_data = 128'd0;
            exp_data[15:8]    = nv12_y_sample(active_x + 0, active_y);
            exp_data[47:40]   = nv12_y_sample(active_x + 1, active_y);
            exp_data[79:72]   = nv12_y_sample(active_x + 2, active_y);
            exp_data[111:104] = nv12_y_sample(active_x + 3, active_y);
            if ((active_y & 1) == 1) begin
                exp_data[7:0]   = nv12_v_sample(pair_x0, uv_line);
                exp_data[23:16] = nv12_u_sample(pair_x0, uv_line);
                exp_data[71:64] = nv12_v_sample(pair_x1, uv_line);
                exp_data[87:80] = nv12_u_sample(pair_x1, uv_line);
            end

            if (o_otf_data !== exp_data) begin
                $fatal(1,
                       "OTF NV12 mismatch at x=%0d y=%0d got=%h exp=%h",
                       active_x, active_y, o_otf_data, exp_data);
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

        rst_n           = 1'b0;
        cfg_img_width   = IMG_W[15:0];
        cfg_format      = FMT_YUV420_Y;
        cfg_otf_h_total = OTF_H_TOTAL[15:0];
        cfg_otf_h_sync  = OTF_H_SYNC[15:0];
        cfg_otf_h_bp    = OTF_H_BP[15:0];
        cfg_otf_h_act   = IMG_W[15:0];
        cfg_otf_v_total = 16'd1125;
        cfg_otf_v_sync  = 16'd5;
        cfg_otf_v_bp    = 16'd36;
        cfg_otf_v_act   = IMG_H[15:0];
        s_axis_tdata    = 256'd0;
        s_axis_tlast    = 1'b0;
        s_axis_format   = 5'd0;
        s_axis_tile_x   = 16'd0;
        s_axis_tile_y   = 16'd0;
        s_axis_tile_valid = 1'b0;
        s_axis_tvalid   = 1'b0;
        i_otf_ready     = 1'b1;
        sent_tile_count = 0;
        sending_done    = 1'b0;

        repeat (8) @(posedge clk_sram);
        rst_n = 1'b1;
        repeat (4) @(posedge clk_sram);

        $display("");
        $display("========================================================");
        $display("TB: ubwc_dec_tile_to_otf 1920x1080 NV12 frame");
        $display("Frame size   : %0dx%0d", IMG_W, IMG_H);
        $display("Tiles / rowgroup: %0d", TILE_X_COUNT);
        $display("Slice count     : %0d", SLICE_COUNT);
        $display("========================================================");

        fork
            send_full_nv12_frame();
        join_none

        timeout = 0;
        while (!frame_done && (timeout < 6000000)) begin
            @(posedge clk_otf);
            timeout = timeout + 1;
        end

        if (timeout >= 6000000) begin
            $fatal(1, "Timeout waiting for full 1920x1080 NV12 frame.");
        end

        if (!sending_done) begin
            $fatal(1, "Input AXIS frame was not fully sent.");
        end

        if (sent_tile_count != (TILE_X_COUNT * SLICE_COUNT * 3)) begin
            $fatal(1, "Sent tile count mismatch. got=%0d exp=%0d",
                   sent_tile_count, TILE_X_COUNT * SLICE_COUNT * 3);
        end

        if (checked_pixel_count != FRAME_PIXEL_COUNT) begin
            $fatal(1, "Checked pixel count mismatch. got=%0d exp=%0d",
                   checked_pixel_count, FRAME_PIXEL_COUNT);
        end

        $display("PASS: ubwc_dec_tile_to_otf full 1920x1080 NV12 frame completed");
        $display("Checked pixels : %0d", checked_pixel_count);
        $display("Sent tiles     : %0d", sent_tile_count);

        repeat (20) @(posedge clk_otf);
        $finish;
    end


    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_tile_to_otf_1920x1080_nv12.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_tile_to_otf_1920x1080_nv12);
        $fsdbDumpMDA(0, tb_ubwc_dec_tile_to_otf_1920x1080_nv12);
`else
        $dumpfile("tb_ubwc_dec_tile_to_otf_1920x1080_nv12.vcd");
        $dumpvars(0, tb_ubwc_dec_tile_to_otf_1920x1080_nv12);
`endif
`endif
    end

endmodule
