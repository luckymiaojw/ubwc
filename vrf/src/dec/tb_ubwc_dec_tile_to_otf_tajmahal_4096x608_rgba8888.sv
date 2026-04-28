`timescale 1ns/1ps

module tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888;

    localparam integer IMG_W              = 4096;
    localparam integer IMG_H_ACTIVE       = 600;
    localparam integer IMG_H_STORED       = 608;
    localparam integer RGBA_TILE_W        = 16;
    localparam integer RGBA_TILE_H        = 4;
    localparam integer RGBA_TILE_X_COUNT  = IMG_W / RGBA_TILE_W;
    localparam integer RGBA_SLICE_COUNT   = IMG_H_STORED / RGBA_TILE_H;
    localparam integer FRAME_PIXEL_COUNT  = IMG_W * IMG_H_STORED;
    localparam integer WORDS64_PER_LINE   = IMG_W / 2;
    localparam integer WORDS64_PER_TILE   = 32;
    localparam integer WORDS64_TOTAL      = WORDS64_PER_LINE * IMG_H_STORED;
    localparam integer BEATS_PER_TILE     = WORDS64_PER_TILE / 4;
    localparam integer SURFACE_PITCH_BYTES = 16384;
    localparam integer HIGHEST_BANK_BIT    = 16;

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

    reg  [63:0]   tiled_words [0:WORDS64_TOTAL-1];
    reg  [63:0]   linear_words [0:WORDS64_TOTAL-1];

    integer       sent_tile_count;
    integer       checked_pixel_count;
    integer       active_x;
    integer       active_y;
    reg           sending_done;
    reg           frame_done;

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

            addr_bytes = (SURFACE_PITCH_BYTES * (macro_tile_y * 4) * RGBA_TILE_H) +
                         (macro_tile_x * 4096) +
                         (macro_tile_slot(temp_tile_x, temp_tile_y) * 256);

            if (((16 * SURFACE_PITCH_BYTES) % (1 << HIGHEST_BANK_BIT)) == 0) begin
                tile_row_pixels = tile_y * RGBA_TILE_H;
                bit_val = ((addr_bytes >> (HIGHEST_BANK_BIT - 1)) & 1) ^ ((tile_row_pixels >> 4) & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (1 << (HIGHEST_BANK_BIT - 1));
                end else begin
                    addr_bytes = addr_bytes & ~(1 << (HIGHEST_BANK_BIT - 1));
                end
            end

            if (((16 * SURFACE_PITCH_BYTES) % (1 << (HIGHEST_BANK_BIT + 1))) == 0) begin
                tile_row_pixels = tile_y * RGBA_TILE_H;
                bit_val = ((addr_bytes >> HIGHEST_BANK_BIT) & 1) ^ ((tile_row_pixels >> 5) & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (1 << HIGHEST_BANK_BIT);
                end else begin
                    addr_bytes = addr_bytes & ~(1 << HIGHEST_BANK_BIT);
                end
            end

            rgba_tile_base_word = addr_bytes >> 3;
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

    task automatic send_rgba_tile_from_vector;
        input integer tile_x;
        input integer tile_y;
        integer tile_base_word;
        integer beat;
        integer word_idx;
        reg [255:0] beat_data;
        begin
            tile_base_word = rgba_tile_base_word(tile_x, tile_y);
            drive_axis_tile_header(FMT_RGBA8888, tile_x[15:0], tile_y[15:0]);

            for (beat = 0; beat < BEATS_PER_TILE; beat = beat + 1) begin
                word_idx = tile_base_word + beat * 4;
                beat_data = {tiled_words[word_idx + 3],
                             tiled_words[word_idx + 2],
                             tiled_words[word_idx + 1],
                             tiled_words[word_idx + 0]};
                drive_axis_beat(beat_data, (beat == (BEATS_PER_TILE - 1)));
            end

            sent_tile_count = sent_tile_count + 1;
            axis_idle();
        end
    endtask

    task automatic send_full_vector_frame;
        integer slice_idx;
        integer tile_x;
        begin
            for (slice_idx = 0; slice_idx < RGBA_SLICE_COUNT; slice_idx = slice_idx + 1) begin
                for (tile_x = 0; tile_x < RGBA_TILE_X_COUNT; tile_x = tile_x + 1) begin
                    send_rgba_tile_from_vector(tile_x, slice_idx);
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
        .rst_sram_n           (rst_n),
        .rst_otf_n           (rst_n),
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
        .sram_a_rvalid    (sram_a_dout_vld),
        .sram_b_wen      (sram_b_wen),
        .sram_b_waddr    (sram_b_waddr),
        .sram_b_wdata    (sram_b_wdata),
        .sram_b_ren      (sram_b_ren),
        .sram_b_raddr    (sram_b_raddr),
        .sram_b_rdata    (sram_b_rdata),
        .sram_b_rvalid    (sram_b_dout_vld),
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
            active_x            <= 0;
            active_y            <= 0;
            frame_done          <= 1'b0;
        end else if (i_otf_ready && o_otf_de && !frame_done) begin
            if (o_otf_data !== expected_otf_word(active_x, active_y)) begin
                $fatal(1,
                       "OTF beat mismatch at x=%0d y=%0d got=%032h exp=%032h",
                       active_x, active_y, o_otf_data, expected_otf_word(active_x, active_y));
            end

            if ((active_x == 0) && ((active_y % 64) == 0)) begin
                $display("Vector OTF progress: line %0d / %0d", active_y, IMG_H_STORED);
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

        $readmemh("tajmahal_tiled.memh",  tiled_words);
        $readmemh("tajmahal_linear.memh", linear_words);

        if (^tiled_words[0] === 1'bx) begin
            $fatal(1, "Failed to load tajmahal_tiled.memh");
        end
        if (^linear_words[0] === 1'bx) begin
            $fatal(1, "Failed to load tajmahal_linear.memh");
        end

        rst_n            = 1'b0;
        cfg_img_width    = IMG_W[15:0];
        cfg_format       = FMT_RGBA8888;
        cfg_otf_h_total  = 16'd4400;
        cfg_otf_h_sync   = 16'd44;
        cfg_otf_h_bp     = 16'd148;
        cfg_otf_h_act    = IMG_W[15:0];
        cfg_otf_v_total  = 16'd650;
        cfg_otf_v_sync   = 16'd5;
        cfg_otf_v_bp     = 16'd36;
        cfg_otf_v_act    = IMG_H_STORED[15:0];
        s_axis_tdata     = 256'd0;
        s_axis_tlast     = 1'b0;
        s_axis_format    = 5'd0;
        s_axis_tile_x    = 16'd0;
        s_axis_tile_y    = 16'd0;
        s_axis_tile_valid = 1'b0;
        s_axis_tvalid    = 1'b0;
        i_otf_ready      = 1'b1;
        sent_tile_count  = 0;
        sending_done     = 1'b0;

        repeat (8) @(posedge clk_sram);
        rst_n = 1'b1;
        repeat (4) @(posedge clk_sram);

        $display("");
        $display("==============================================================");
        $display("TB: ubwc_dec_tile_to_otf TajMahal vector RGBA8888");
        $display("Vector source      : tajmahal_tiled.memh / tajmahal_linear.memh");
        $display("Actual image size  : %0dx%0d", IMG_W, IMG_H_ACTIVE);
        $display("Stored image size  : %0dx%0d", IMG_W, IMG_H_STORED);
        $display("Tile slices        : %0d", RGBA_SLICE_COUNT);
        $display("Tiles / slice      : %0d", RGBA_TILE_X_COUNT);
        $display("==============================================================");

        fork
            send_full_vector_frame();
        join_none

        timeout = 0;
        while (!frame_done && (timeout < 3000000)) begin
            @(posedge clk_otf);
            timeout = timeout + 1;
        end

        if (timeout >= 3000000) begin
            $fatal(1, "Timeout waiting for TajMahal OTF frame.");
        end

        if (!sending_done) begin
            $fatal(1, "Vector AXIS frame was not fully sent.");
        end

        if (sent_tile_count != (RGBA_TILE_X_COUNT * RGBA_SLICE_COUNT)) begin
            $fatal(1, "Sent tile count mismatch. got=%0d exp=%0d",
                   sent_tile_count, RGBA_TILE_X_COUNT * RGBA_SLICE_COUNT);
        end

        if (checked_pixel_count != FRAME_PIXEL_COUNT) begin
            $fatal(1, "Checked pixel count mismatch. got=%0d exp=%0d",
                   checked_pixel_count, FRAME_PIXEL_COUNT);
        end

        $display("PASS: ubwc_dec_tile_to_otf TajMahal vector completed");
        $display("Checked pixels : %0d", checked_pixel_count);
        $display("Sent tiles     : %0d", sent_tile_count);

        repeat (20) @(posedge clk_otf);
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888);
        $fsdbDumpMDA(0, tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888);
`else
        $dumpfile("tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888.vcd");
        $dumpvars(0, tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888);
`endif
`endif
    end

endmodule
