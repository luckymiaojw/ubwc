`timescale 1ns/1ps

module tb_ubwc_dec_tile_to_otf_tajmahal_core #(
    parameter integer CASE_ID = 0
);

    localparam integer CASE_RGBA8888_TILED    = 0;
    localparam integer CASE_RGBA1010102_TILED = 1;
    localparam integer CASE_RGBA8888_LINEAR   = 2;
    localparam integer CASE_NV12_TILED        = 3;

    localparam integer IMG_W               = 4096;

    localparam integer RGBA_ACTIVE_H       = 600;
    localparam integer RGBA_STORED_H       = 608;
    localparam integer RGBA_TILE_W         = 16;
    localparam integer RGBA_TILE_H         = 4;
    localparam integer RGBA_TILE_X_COUNT   = IMG_W / RGBA_TILE_W;
    localparam integer RGBA_TILE_Y_COUNT   = RGBA_STORED_H / RGBA_TILE_H;
    localparam integer RGBA_WORDS64_PER_LINE = IMG_W / 2;
    localparam integer RGBA_WORDS64_TOTAL  = RGBA_WORDS64_PER_LINE * RGBA_STORED_H;
    localparam integer RGBA_WORDS64_PER_TILE = 32;
    localparam integer RGBA_BEATS_PER_TILE = RGBA_WORDS64_PER_TILE / 4;
    localparam integer RGBA_SURFACE_PITCH_BYTES = 16384;
    localparam integer RGBA_HIGHEST_BANK_BIT = 16;

    localparam integer NV12_ACTIVE_H       = 600;
    localparam integer NV12_Y_STORED_H     = 640;
    localparam integer NV12_UV_STORED_H    = 320;
    localparam integer NV12_TILE_W         = 32;
    localparam integer NV12_TILE_H         = 8;
    localparam integer NV12_SLICE_LINES    = 16;
    localparam integer NV12_TILE_X_COUNT   = IMG_W / NV12_TILE_W;
    localparam integer NV12_SLICE_COUNT    = NV12_Y_STORED_H / NV12_SLICE_LINES;
    localparam integer NV12_Y_WORDS64_PER_LINE  = IMG_W / 8;
    localparam integer NV12_UV_WORDS64_PER_LINE = IMG_W / 8;
    localparam integer NV12_Y_WORDS64_TOTAL  = NV12_Y_WORDS64_PER_LINE * NV12_Y_STORED_H;
    localparam integer NV12_UV_WORDS64_TOTAL = NV12_UV_WORDS64_PER_LINE * NV12_UV_STORED_H;
    localparam integer NV12_WORDS64_PER_TILE = 32;
    localparam integer NV12_BEATS_PER_TILE = NV12_WORDS64_PER_TILE / 4;
    localparam integer NV12_SURFACE_PITCH_BYTES = 4096;
    localparam integer NV12_HIGHEST_BANK_BIT = 16;

    localparam integer CASE_IS_NV12        = (CASE_ID == CASE_NV12_TILED);
    localparam integer CASE_IS_LINEAR_IN   = (CASE_ID == CASE_RGBA8888_LINEAR);
    localparam integer CASE_IS_RGBA1010102 = (CASE_ID == CASE_RGBA1010102_TILED);

    localparam integer CASE_ACTIVE_H       = CASE_IS_NV12 ? NV12_ACTIVE_H : RGBA_ACTIVE_H;
    localparam integer CASE_STORED_H       = CASE_IS_NV12 ? NV12_Y_STORED_H : RGBA_STORED_H;
    localparam integer CASE_FRAME_PIXELS   = IMG_W * CASE_STORED_H;
    localparam integer CASE_EXPECTED_BEATS = (IMG_W / 4) * CASE_STORED_H;
    localparam integer CASE_EXPECTED_TILES = CASE_IS_NV12
                                           ? (NV12_TILE_X_COUNT * NV12_SLICE_COUNT * 3)
                                           : (RGBA_TILE_X_COUNT * RGBA_TILE_Y_COUNT);
    localparam integer CASE_TIMEOUT        = CASE_IS_NV12 ? 4000000 : 3000000;

    localparam [4:0] FMT_RGBA8888    = 5'b00000;
    localparam [4:0] FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] FMT_YUV420_Y    = 5'b01000;
    localparam [4:0] FMT_YUV420_UV   = 5'b01001;

    localparam [4:0] CASE_CFG_FORMAT = CASE_IS_NV12
                                     ? FMT_YUV420_Y
                                     : (CASE_IS_RGBA1010102 ? FMT_RGBA1010102 : FMT_RGBA8888);

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

    reg  [63:0]   rgba_tiled_words      [0:RGBA_WORDS64_TOTAL-1];
    reg  [63:0]   rgba_linear_words     [0:RGBA_WORDS64_TOTAL-1];
    reg  [63:0]   nv12_y_tiled_words    [0:NV12_Y_WORDS64_TOTAL-1];
    reg  [63:0]   nv12_uv_tiled_words   [0:NV12_UV_WORDS64_TOTAL-1];
    reg  [127:0]  expected_beats        [0:CASE_EXPECTED_BEATS-1];

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

            addr_bytes = (RGBA_SURFACE_PITCH_BYTES * (macro_tile_y * 4) * RGBA_TILE_H) +
                         (macro_tile_x * 4096) +
                         (macro_tile_slot(temp_tile_x, temp_tile_y) * 256);

            if (((16 * RGBA_SURFACE_PITCH_BYTES) % (1 << RGBA_HIGHEST_BANK_BIT)) == 0) begin
                tile_row_pixels = tile_y * RGBA_TILE_H;
                bit_val = ((addr_bytes >> (RGBA_HIGHEST_BANK_BIT - 1)) & 1) ^ ((tile_row_pixels >> 4) & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (1 << (RGBA_HIGHEST_BANK_BIT - 1));
                end else begin
                    addr_bytes = addr_bytes & ~(1 << (RGBA_HIGHEST_BANK_BIT - 1));
                end
            end

            if (((16 * RGBA_SURFACE_PITCH_BYTES) % (1 << (RGBA_HIGHEST_BANK_BIT + 1))) == 0) begin
                tile_row_pixels = tile_y * RGBA_TILE_H;
                bit_val = ((addr_bytes >> RGBA_HIGHEST_BANK_BIT) & 1) ^ ((tile_row_pixels >> 5) & 1);
                if (bit_val != 0) begin
                    addr_bytes = addr_bytes | (1 << RGBA_HIGHEST_BANK_BIT);
                end else begin
                    addr_bytes = addr_bytes & ~(1 << RGBA_HIGHEST_BANK_BIT);
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
                if (((bpp == 1) && (tile_width * 4 == 128) && (tile_height * 4 == 32)) ||
                    ((bpp == 2) && (tile_width * 4 == 64)  && (tile_height * 4 == 32))) begin
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
                if (((bpp == 1) && (tile_width * 4 == 128) && (tile_height * 4 == 32)) ||
                    ((bpp == 2) && (tile_width * 4 == 64)  && (tile_height * 4 == 32))) begin
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
            line_in_tile    = local_word_idx >> 3;
            word_in_line    = local_word_idx & 7;
            global_y        = tile_y * RGBA_TILE_H + line_in_tile;
            global_word_x   = tile_x * (RGBA_TILE_W / 2) + word_in_line;
            linear_word_idx = global_y * RGBA_WORDS64_PER_LINE + global_word_x;
            if ((global_y < RGBA_STORED_H) && (global_word_x < RGBA_WORDS64_PER_LINE)) begin
                linear_tile_word64 = rgba_linear_words[linear_word_idx];
            end else begin
                linear_tile_word64 = 64'd0;
            end
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

    task automatic send_rgba_tiled_tile;
        input integer tile_x;
        input integer tile_y;
        integer tile_base_word;
        integer beat;
        integer word_idx;
        reg [255:0] beat_data;
        reg [4:0]   tile_format;
        begin
            tile_format = CASE_IS_RGBA1010102 ? FMT_RGBA1010102 : FMT_RGBA8888;
            tile_base_word = rgba_tile_base_word(tile_x, tile_y);
            drive_axis_tile_header(tile_format, tile_x[15:0], tile_y[15:0]);

            for (beat = 0; beat < RGBA_BEATS_PER_TILE; beat = beat + 1) begin
                word_idx = tile_base_word + beat * 4;
                beat_data = {rgba_tiled_words[word_idx + 3],
                             rgba_tiled_words[word_idx + 2],
                             rgba_tiled_words[word_idx + 1],
                             rgba_tiled_words[word_idx + 0]};
                drive_axis_beat(beat_data, (beat == (RGBA_BEATS_PER_TILE - 1)));
            end

            sent_tile_count = sent_tile_count + 1;
            axis_idle();
        end
    endtask

    task automatic send_rgba_linear_tile;
        input integer tile_x;
        input integer tile_y;
        integer beat;
        integer local_word_idx;
        reg [255:0] beat_data;
        begin
            drive_axis_tile_header(FMT_RGBA8888, tile_x[15:0], tile_y[15:0]);

            for (beat = 0; beat < RGBA_BEATS_PER_TILE; beat = beat + 1) begin
                local_word_idx = beat * 4;
                beat_data = {linear_tile_word64(tile_x, tile_y, local_word_idx + 3),
                             linear_tile_word64(tile_x, tile_y, local_word_idx + 2),
                             linear_tile_word64(tile_x, tile_y, local_word_idx + 1),
                             linear_tile_word64(tile_x, tile_y, local_word_idx + 0)};
                drive_axis_beat(beat_data, (beat == (RGBA_BEATS_PER_TILE - 1)));
            end

            sent_tile_count = sent_tile_count + 1;
            axis_idle();
        end
    endtask

    task automatic send_nv12_y_tile;
        input integer tile_x;
        input integer y_tile_y;
        input integer slice_idx;
        integer tile_base_word;
        integer beat;
        integer word_idx;
        reg [255:0] beat_data;
        begin
            tile_base_word = plane_tile_base_word(tile_x, y_tile_y, NV12_TILE_W, NV12_TILE_H,
                                                  NV12_SURFACE_PITCH_BYTES, NV12_HIGHEST_BANK_BIT, 1);
            drive_axis_tile_header(FMT_YUV420_Y, tile_x[15:0], slice_idx[15:0]);

            for (beat = 0; beat < NV12_BEATS_PER_TILE; beat = beat + 1) begin
                word_idx = tile_base_word + beat * 4;
                beat_data = {nv12_y_tiled_words[word_idx + 3],
                             nv12_y_tiled_words[word_idx + 2],
                             nv12_y_tiled_words[word_idx + 1],
                             nv12_y_tiled_words[word_idx + 0]};
                drive_axis_beat(beat_data, (beat == (NV12_BEATS_PER_TILE - 1)));
            end

            sent_tile_count = sent_tile_count + 1;
            axis_idle();
        end
    endtask

    task automatic send_nv12_uv_tile;
        input integer tile_x;
        input integer uv_tile_y;
        input integer slice_idx;
        integer tile_base_word;
        integer beat;
        integer word_idx;
        reg [255:0] beat_data;
        begin
            tile_base_word = plane_tile_base_word(tile_x, uv_tile_y, NV12_TILE_W, NV12_TILE_H,
                                                  NV12_SURFACE_PITCH_BYTES, NV12_HIGHEST_BANK_BIT, 1);
            drive_axis_tile_header(FMT_YUV420_UV, tile_x[15:0], slice_idx[15:0]);

            for (beat = 0; beat < NV12_BEATS_PER_TILE; beat = beat + 1) begin
                word_idx = tile_base_word + beat * 4;
                beat_data = {nv12_uv_tiled_words[word_idx + 3],
                             nv12_uv_tiled_words[word_idx + 2],
                             nv12_uv_tiled_words[word_idx + 1],
                             nv12_uv_tiled_words[word_idx + 0]};
                drive_axis_beat(beat_data, (beat == (NV12_BEATS_PER_TILE - 1)));
            end

            sent_tile_count = sent_tile_count + 1;
            axis_idle();
        end
    endtask

    task automatic send_full_case_frame;
        integer slice_idx;
        integer tile_x;
        integer tile_y;
        integer y_upper_tile_y;
        integer y_lower_tile_y;
        integer uv_tile_y;
        begin
            if (CASE_IS_NV12) begin
                for (slice_idx = 0; slice_idx < NV12_SLICE_COUNT; slice_idx = slice_idx + 1) begin
                    y_upper_tile_y = slice_idx * 2;
                    y_lower_tile_y = slice_idx * 2 + 1;
                    uv_tile_y      = slice_idx;

                    for (tile_x = 0; tile_x < NV12_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_nv12_y_tile(tile_x, y_upper_tile_y, slice_idx);
                    end
                    for (tile_x = 0; tile_x < NV12_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_nv12_y_tile(tile_x, y_lower_tile_y, slice_idx);
                    end
                    for (tile_x = 0; tile_x < NV12_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_nv12_uv_tile(tile_x, uv_tile_y, slice_idx);
                    end
                end
            end else if (CASE_IS_LINEAR_IN) begin
                for (tile_y = 0; tile_y < RGBA_TILE_Y_COUNT; tile_y = tile_y + 1) begin
                    for (tile_x = 0; tile_x < RGBA_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_rgba_linear_tile(tile_x, tile_y);
                    end
                end
            end else begin
                for (tile_y = 0; tile_y < RGBA_TILE_Y_COUNT; tile_y = tile_y + 1) begin
                    for (tile_x = 0; tile_x < RGBA_TILE_X_COUNT; tile_x = tile_x + 1) begin
                        send_rgba_tiled_tile(tile_x, tile_y);
                    end
                end
            end
            sending_done = 1'b1;
        end
    endtask

    task automatic display_banner;
        begin
            $display("");
            $display("================================================================");
            case (CASE_ID)
                CASE_RGBA8888_TILED: begin
                    $display("TB: ubwc_dec_tile_to_otf TajMahal vector RGBA8888");
                    $display("Input vector       : input_rgba_tiled.memh");
                    $display("Expected stream    : expected_otf_stream.txt");
                    $display("Actual stream      : actual_otf_stream.txt");
                    $display("Actual image size  : %0dx%0d", IMG_W, RGBA_ACTIVE_H);
                    $display("Stored image size  : %0dx%0d", IMG_W, RGBA_STORED_H);
                    $display("Tile grid          : %0d x %0d", RGBA_TILE_X_COUNT, RGBA_TILE_Y_COUNT);
                end
                CASE_RGBA1010102_TILED: begin
                    $display("TB: ubwc_dec_tile_to_otf TajMahal vector RGBA1010102");
                    $display("Input vector       : input_rgba_tiled.memh");
                    $display("Expected stream    : expected_otf_stream.txt");
                    $display("Actual stream      : actual_otf_stream.txt");
                    $display("Actual image size  : %0dx%0d", IMG_W, RGBA_ACTIVE_H);
                    $display("Stored image size  : %0dx%0d", IMG_W, RGBA_STORED_H);
                    $display("Tile grid          : %0d x %0d", RGBA_TILE_X_COUNT, RGBA_TILE_Y_COUNT);
                end
                CASE_RGBA8888_LINEAR: begin
                    $display("TB: ubwc_dec_tile_to_otf TajMahal linear-in RGBA8888");
                    $display("Input vector       : input_rgba_linear.memh");
                    $display("Expected stream    : expected_otf_stream.txt");
                    $display("Actual stream      : actual_otf_stream.txt");
                    $display("Actual image size  : %0dx%0d", IMG_W, RGBA_ACTIVE_H);
                    $display("Stored image size  : %0dx%0d", IMG_W, RGBA_STORED_H);
                    $display("Tile grid          : %0d x %0d", RGBA_TILE_X_COUNT, RGBA_TILE_Y_COUNT);
                end
                default: begin
                    $display("TB: ubwc_dec_tile_to_otf TajMahal NV12 tiled vector");
                    $display("Input Y vector     : input_nv12_y_tiled.memh");
                    $display("Input UV vector    : input_nv12_uv_tiled.memh");
                    $display("Expected stream    : expected_otf_stream.txt");
                    $display("Actual stream      : actual_otf_stream.txt");
                    $display("Actual image size  : %0dx%0d", IMG_W, NV12_ACTIVE_H);
                    $display("Stored Y size      : %0dx%0d", IMG_W, NV12_Y_STORED_H);
                    $display("Stored UV size     : %0dx%0d", IMG_W, NV12_UV_STORED_H);
                    $display("Slice count        : %0d", NV12_SLICE_COUNT);
                    $display("Tiles / rowgroup   : %0d", NV12_TILE_X_COUNT);
                end
            endcase
            $display("================================================================");
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
        .clk_sram         (clk_sram),
        .clk_otf          (clk_otf),
        .rst_n            (rst_n),
        .cfg_img_width    (cfg_img_width),
        .cfg_format       (cfg_format),
        .cfg_otf_h_total  (cfg_otf_h_total),
        .cfg_otf_h_sync   (cfg_otf_h_sync),
        .cfg_otf_h_bp     (cfg_otf_h_bp),
        .cfg_otf_h_act    (cfg_otf_h_act),
        .cfg_otf_v_total  (cfg_otf_v_total),
        .cfg_otf_v_sync   (cfg_otf_v_sync),
        .cfg_otf_v_bp     (cfg_otf_v_bp),
        .cfg_otf_v_act    (cfg_otf_v_act),
        .s_axis_format    (s_axis_format),
        .s_axis_tile_x    (s_axis_tile_x),
        .s_axis_tile_y    (s_axis_tile_y),
        .s_axis_tile_valid(s_axis_tile_valid),
        .s_axis_tile_ready(s_axis_tile_ready),
        .s_axis_tdata     (s_axis_tdata),
        .s_axis_tlast     (s_axis_tlast),
        .s_axis_tvalid    (s_axis_tvalid),
        .s_axis_tready    (s_axis_tready),
        .sram_a_wen       (sram_a_wen),
        .sram_a_waddr     (sram_a_waddr),
        .sram_a_wdata     (sram_a_wdata),
        .sram_a_ren       (sram_a_ren),
        .sram_a_raddr     (sram_a_raddr),
        .sram_a_rdata     (sram_a_rdata),
        .sram_b_wen       (sram_b_wen),
        .sram_b_waddr     (sram_b_waddr),
        .sram_b_wdata     (sram_b_wdata),
        .sram_b_ren       (sram_b_ren),
        .sram_b_raddr     (sram_b_raddr),
        .sram_b_rdata     (sram_b_rdata),
        .o_otf_vsync      (o_otf_vsync),
        .o_otf_hsync      (o_otf_hsync),
        .o_otf_de         (o_otf_de),
        .o_otf_data       (o_otf_data),
        .o_otf_fcnt       (o_otf_fcnt),
        .o_otf_lcnt       (o_otf_lcnt),
        .i_otf_ready      (i_otf_ready)
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
            checked_beat_count  <= 0;
            active_x            <= 0;
            active_y            <= 0;
            frame_done          <= 1'b0;
        end else if (i_otf_ready && o_otf_de && frame_done) begin
            $fatal(1, "Unexpected extra OTF beat after frame completion. data=%032h", o_otf_data);
        end else if (i_otf_ready && o_otf_de && !frame_done) begin
            if (checked_beat_count >= CASE_EXPECTED_BEATS) begin
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

            if ((active_x == 0) && ((active_y % 64) == 0)) begin
                $display("OTF progress(case=%0d): line %0d / %0d", CASE_ID, active_y, CASE_STORED_H);
            end

            checked_beat_count  <= checked_beat_count + 1;
            checked_pixel_count <= checked_pixel_count + 4;

            if (active_x == IMG_W - 4) begin
                active_x <= 0;
                if (active_y == CASE_STORED_H - 1) begin
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
        $readmemh("expected_otf_stream.txt", expected_beats);
        if (^expected_beats[0] === 1'bx) begin
            $fatal(1, "Failed to load expected_otf_stream.txt");
        end

        case (CASE_ID)
            CASE_RGBA8888_TILED,
            CASE_RGBA1010102_TILED: begin
                $readmemh("input_rgba_tiled.memh", rgba_tiled_words);
                if (^rgba_tiled_words[0] === 1'bx) begin
                    $fatal(1, "Failed to load input_rgba_tiled.memh");
                end
            end
            CASE_RGBA8888_LINEAR: begin
                $readmemh("input_rgba_linear.memh", rgba_linear_words);
                if (^rgba_linear_words[0] === 1'bx) begin
                    $fatal(1, "Failed to load input_rgba_linear.memh");
                end
            end
            CASE_NV12_TILED: begin
                $readmemh("input_nv12_y_tiled.memh",  nv12_y_tiled_words);
                $readmemh("input_nv12_uv_tiled.memh", nv12_uv_tiled_words);
                if (^nv12_y_tiled_words[0] === 1'bx) begin
                    $fatal(1, "Failed to load input_nv12_y_tiled.memh");
                end
                if (^nv12_uv_tiled_words[0] === 1'bx) begin
                    $fatal(1, "Failed to load input_nv12_uv_tiled.memh");
                end
            end
            default: begin
                $fatal(1, "Unsupported CASE_ID=%0d", CASE_ID);
            end
        endcase

        rst_n             = 1'b0;
        cfg_img_width     = IMG_W[15:0];
        cfg_format        = CASE_CFG_FORMAT;
        cfg_otf_h_total   = 16'd4400;
        cfg_otf_h_sync    = 16'd44;
        cfg_otf_h_bp      = 16'd148;
        cfg_otf_h_act     = IMG_W[15:0];
        cfg_otf_v_total   = CASE_IS_NV12 ? 16'd690 : 16'd650;
        cfg_otf_v_sync    = 16'd5;
        cfg_otf_v_bp      = 16'd36;
        cfg_otf_v_act     = CASE_STORED_H;
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

        display_banner();

        otf_fd = $fopen("actual_otf_stream.txt", "w");
        if (otf_fd == 0) begin
            $fatal(1, "Failed to open actual_otf_stream.txt");
        end

        fork
            send_full_case_frame();
        join_none

        while (!frame_done && (timeout < CASE_TIMEOUT)) begin
            @(posedge clk_otf);
            timeout = timeout + 1;
        end

        if (timeout >= CASE_TIMEOUT) begin
            $fatal(1, "Timeout waiting for TajMahal OTF frame. CASE_ID=%0d", CASE_ID);
        end

        if (!sending_done) begin
            $fatal(1, "Input frame was not fully sent. CASE_ID=%0d", CASE_ID);
        end

        if (sent_tile_count != CASE_EXPECTED_TILES) begin
            $fatal(1, "Sent tile count mismatch. got=%0d exp=%0d",
                   sent_tile_count, CASE_EXPECTED_TILES);
        end

        if (checked_beat_count != CASE_EXPECTED_BEATS) begin
            $fatal(1, "Checked beat count mismatch. got=%0d exp=%0d",
                   checked_beat_count, CASE_EXPECTED_BEATS);
        end

        if (checked_pixel_count != CASE_FRAME_PIXELS) begin
            $fatal(1, "Checked pixel count mismatch. got=%0d exp=%0d",
                   checked_pixel_count, CASE_FRAME_PIXELS);
        end

        $display("PASS: ubwc_dec_tile_to_otf TajMahal case=%0d completed", CASE_ID);
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
        case (CASE_ID)
            CASE_RGBA8888_TILED:    $fsdbDumpfile("tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888.fsdb");
            CASE_RGBA1010102_TILED: $fsdbDumpfile("tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102.fsdb");
            CASE_RGBA8888_LINEAR:   $fsdbDumpfile("tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888.fsdb");
            default:                $fsdbDumpfile("tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12.fsdb");
        endcase
        $fsdbDumpvars(0);
        $fsdbDumpMDA(0);
`else
        case (CASE_ID)
            CASE_RGBA8888_TILED:    $dumpfile("tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888.vcd");
            CASE_RGBA1010102_TILED: $dumpfile("tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102.vcd");
            CASE_RGBA8888_LINEAR:   $dumpfile("tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888.vcd");
            default:                $dumpfile("tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12.vcd");
        endcase
        $dumpvars(0);
`endif
`endif
    end

endmodule

module tb_ubwc_dec_tile_to_otf_tajmahal_cases #(
    parameter integer CASE_ID = 0
);
    tb_ubwc_dec_tile_to_otf_tajmahal_core #(
        .CASE_ID(CASE_ID)
    ) u_core ();
endmodule

module tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba8888;
    tb_ubwc_dec_tile_to_otf_tajmahal_core #(
        .CASE_ID(0)
    ) u_core ();
endmodule

module tb_ubwc_dec_tile_to_otf_tajmahal_4096x608_rgba1010102;
    tb_ubwc_dec_tile_to_otf_tajmahal_core #(
        .CASE_ID(1)
    ) u_core ();
endmodule

module tb_ubwc_dec_tile_to_otf_tajmahal_linear_in_rgba8888;
    tb_ubwc_dec_tile_to_otf_tajmahal_core #(
        .CASE_ID(2)
    ) u_core ();
endmodule

module tb_ubwc_dec_tile_to_otf_tajmahal_4096x640_nv12;
    tb_ubwc_dec_tile_to_otf_tajmahal_core #(
        .CASE_ID(3)
    ) u_core ();
endmodule
