`timescale 1ns/1ps

module ubwc_dec_vivo_top
    #(
        parameter                                       SB_WIDTH                        = 1,
        parameter integer                               FAKE_MODEL_EN                   = 0,
        parameter integer                               FAKE_TILE_EXPECT_LINEAR         = 0,
        parameter integer                               FAKE_IMG_W                      = 4096,
        parameter integer                               FAKE_RGBA_ACTIVE_H              = 600,
        parameter integer                               FAKE_RGBA_TILE_PITCH            = 16384,
        parameter integer                               FAKE_RGBA_TILE_COLS             = 256,
        parameter integer                               FAKE_RGBA_TILE_ROWS             = 152,
        parameter integer                               FAKE_NV12_ACTIVE_H              = 600,
        parameter integer                               FAKE_NV12_UV_ACTIVE_H           = 300,
        parameter integer                               FAKE_NV12_TILE_PITCH            = 4096,
        parameter integer                               FAKE_NV12_Y_TILE_COLS           = 128,
        parameter integer                               FAKE_NV12_UV_TILE_COLS          = 128,
        parameter integer                               FAKE_NV12_Y_TILE_ROWS           = 80,
        parameter integer                               FAKE_NV12_UV_TILE_ROWS          = 40,
        parameter integer                               FAKE_G016_ACTIVE_H              = 600,
        parameter integer                               FAKE_G016_UV_ACTIVE_H           = 300,
        parameter integer                               FAKE_G016_TILE_PITCH            = 8192,
        parameter integer                               FAKE_G016_Y_TILE_COLS           = 128,
        parameter integer                               FAKE_G016_UV_TILE_COLS          = 128,
        parameter integer                               FAKE_G016_Y_TILE_ROWS           = 152,
        parameter integer                               FAKE_G016_UV_TILE_ROWS          = 76,
        parameter integer                               FAKE_META_PITCH_BYTES           = 512,
        parameter [63                     :0]           FAKE_TILE_BASE_Y_ADDR           = 64'h0000_0000_8000_0000,
        parameter [63                     :0]           FAKE_TILE_BASE_UV_ADDR          = 64'h0000_0000_8020_0000,
        parameter [63                     :0]           FAKE_META_BASE_Y_ADDR           = 64'h0000_0000_8000_0000,
        parameter [63                     :0]           FAKE_META_BASE_UV_ADDR          = 64'h0000_0000_8020_0000,
        parameter integer                               FAKE_TILE0_WORDS64              = 1,
        parameter integer                               FAKE_TILE1_WORDS64              = 1,
        parameter integer                               FAKE_CMP0_WORDS64               = 1,
        parameter integer                               FAKE_CMP1_WORDS64               = 1,
        parameter integer                               FAKE_META0_WORDS64              = 1,
        parameter integer                               FAKE_META1_WORDS64              = 1
    )(
        input   wire                                        i_clk                           ,
        input   wire                                        i_reset                         ,
        input   wire                                        i_sreset                        ,

        input   wire                                        i_ubwc_en                       ,

        input   wire                                        i_ci_valid                      ,
        output  wire                                        o_ci_ready                      ,
        input   wire                                        i_ci_input_type                 ,
        input   wire    [2                      :0]         i_ci_alen                       ,
        input   wire    [4                      :0]         i_ci_format                     ,
        input   wire    [3                      :0]         i_ci_metadata                   ,
        input   wire                                        i_ci_lossy                      ,
        input   wire    [1                      :0]         i_ci_alpha_mode                 ,
        input   wire    [SB_WIDTH-1             :0]         i_ci_sb                         ,
        input   wire    [12                  -1 :0]         i_ci_xcoord                     ,
        input   wire    [10                  -1 :0]         i_ci_ycoord                     ,
        input   wire    [4                   -1 :0]         i_ci_fcnt                       ,

        input   wire                                        i_cvi_valid                     ,
        input   wire    [255                    :0]         i_cvi_data                      ,
        input   wire                                        i_cvi_last                      ,
        input   wire    [5                   -1 :0]         i_cvi_format                    ,
        input   wire    [12                  -1 :0]         i_cvi_xcoord                    ,
        input   wire    [10                  -1 :0]         i_cvi_ycoord                    ,
        input   wire    [4                   -1 :0]         i_cvi_fcnt                      ,
        output  wire                                        o_cvi_ready                     ,

        output  wire                                        o_co_valid                      ,
        output  wire    [2                      :0]         o_co_alen                       ,
        input   wire                                        i_co_ready                      ,
        output  wire                                        o_co_sb                         ,

        output  wire                                        o_rvo_valid                     ,
        output  wire    [255                    :0]         o_rvo_data                      ,
        output  wire                                        o_rvo_last                      ,
        input   wire                                        i_rvo_ready                     ,

        output  wire                                        o_idle                          ,
        output  wire    [6                      :0]         o_error
);

    localparam  [3                      :0]         TILE_OUT_BEATS                  = 4'd8;
    localparam  integer                             FAKE_TILE0_WORDS64_SAFE         = (FAKE_TILE0_WORDS64 > 0) ? FAKE_TILE0_WORDS64 : 1;
    localparam  integer                             FAKE_TILE1_WORDS64_SAFE         = (FAKE_TILE1_WORDS64 > 0) ? FAKE_TILE1_WORDS64 : 1;
    localparam  integer                             FAKE_CMP0_WORDS64_SAFE          = (FAKE_CMP0_WORDS64  > 0) ? FAKE_CMP0_WORDS64  : 1;
    localparam  integer                             FAKE_CMP1_WORDS64_SAFE          = (FAKE_CMP1_WORDS64  > 0) ? FAKE_CMP1_WORDS64  : 1;
    localparam  integer                             FAKE_META0_WORDS64_SAFE         = (FAKE_META0_WORDS64 > 0) ? FAKE_META0_WORDS64 : 1;
    localparam  integer                             FAKE_META1_WORDS64_SAFE         = (FAKE_META1_WORDS64 > 0) ? FAKE_META1_WORDS64 : 1;

    wire                                            fake_model_active               ;
    wire                                            ci_fire                         ;
    wire                                            co_fire                         ;
    wire                                            cvi_fire                        ;
    wire                                            out_fire                        ;
    wire                                            need_input_beat                 ;
    wire                                            pad_active                      ;
    wire                                            fake_out_active                 ;
    wire                                            fake_cvi_active                 ;
    wire                                            fake_out_done                   ;
    wire                                            fake_cvi_done                   ;
    wire                                            fake_tile_done                  ;
    wire                                            ci_coord_active                 ;
    wire                                            ci_has_payload                  ;
    wire        [7                      :0]         ci_metadata_from_mem            ;
    wire        [7                      :0]         ci_metadata_eff                 ;
    wire        [2                      :0]         ci_alen_from_metadata           ;
    wire        [63                     :0]         ci_cmp_addr_from_metadata       ;
    wire        [255                    :0]         fake_rvo_data                   ;

    reg                                             r_reset_sync                    ;
    reg                                             r_co_valid                      ;
    reg                                             r_tile_active                   ;
    reg         [3                      :0]         r_out_beats_left                ;
    reg         [3                      :0]         r_in_beats_left                 ;
    reg         [2                      :0]         r_ci_alen                       ;
    reg         [4                      :0]         r_ci_format                     ;
    reg         [3                      :0]         r_ci_metadata                   ;
    reg         [SB_WIDTH-1             :0]         r_ci_sb                         ;
    reg         [12                  -1 :0]         r_ci_xcoord                     ;
    reg         [10                  -1 :0]         r_ci_ycoord                     ;
    reg         [4                   -1 :0]         r_ci_fcnt                       ;
    reg         [5                   -1 :0]         r_cvi_format                    ;
    reg         [12                  -1 :0]         r_cvi_xcoord                    ;
    reg         [10                  -1 :0]         r_cvi_ycoord                    ;
    reg         [4                   -1 :0]         r_cvi_fcnt                      ;
    reg         [3                      :0]         fake_cvi_beat_idx               ;
    reg         [3                      :0]         fake_rvo_beat_idx               ;
    reg         [63                     :0]         fake_cvi_cmd_addr               ;

    reg         [63                     :0]         fake_tile0_words [0:FAKE_TILE0_WORDS64_SAFE-1];
    reg         [63                     :0]         fake_tile1_words [0:FAKE_TILE1_WORDS64_SAFE-1];
    reg         [63                     :0]         fake_cmp0_words  [0:FAKE_CMP0_WORDS64_SAFE -1];
    reg         [63                     :0]         fake_cmp1_words  [0:FAKE_CMP1_WORDS64_SAFE -1];
    reg         [63                     :0]         fake_meta0_words [0:FAKE_META0_WORDS64_SAFE-1];
    reg         [63                     :0]         fake_meta1_words [0:FAKE_META1_WORDS64_SAFE-1];

    integer                                         fake_init_idx;
    integer                                         fake_file_fd;

    function automatic integer fake_macro_tile_slot;
        input integer tile_x_mod8;
        input integer tile_y_mod8;
        begin
            case (tile_x_mod8)
                0: case (tile_y_mod8) 0: fake_macro_tile_slot = 0;  1: fake_macro_tile_slot = 6;  2: fake_macro_tile_slot = 3;  3: fake_macro_tile_slot = 5;  4: fake_macro_tile_slot = 4;  5: fake_macro_tile_slot = 2;  6: fake_macro_tile_slot = 7;  default: fake_macro_tile_slot = 1;  endcase
                1: case (tile_y_mod8) 0: fake_macro_tile_slot = 7;  1: fake_macro_tile_slot = 1;  2: fake_macro_tile_slot = 4;  3: fake_macro_tile_slot = 2;  4: fake_macro_tile_slot = 3;  5: fake_macro_tile_slot = 5;  6: fake_macro_tile_slot = 0;  default: fake_macro_tile_slot = 6;  endcase
                2: case (tile_y_mod8) 0: fake_macro_tile_slot = 10; 1: fake_macro_tile_slot = 12; 2: fake_macro_tile_slot = 9;  3: fake_macro_tile_slot = 15; 4: fake_macro_tile_slot = 14; 5: fake_macro_tile_slot = 8;  6: fake_macro_tile_slot = 13; default: fake_macro_tile_slot = 11; endcase
                3: case (tile_y_mod8) 0: fake_macro_tile_slot = 13; 1: fake_macro_tile_slot = 11; 2: fake_macro_tile_slot = 14; 3: fake_macro_tile_slot = 8;  4: fake_macro_tile_slot = 9;  5: fake_macro_tile_slot = 15; 6: fake_macro_tile_slot = 10; default: fake_macro_tile_slot = 12; endcase
                4: case (tile_y_mod8) 0: fake_macro_tile_slot = 4;  1: fake_macro_tile_slot = 2;  2: fake_macro_tile_slot = 7;  3: fake_macro_tile_slot = 1;  4: fake_macro_tile_slot = 0;  5: fake_macro_tile_slot = 6;  6: fake_macro_tile_slot = 3;  default: fake_macro_tile_slot = 5;  endcase
                5: case (tile_y_mod8) 0: fake_macro_tile_slot = 3;  1: fake_macro_tile_slot = 5;  2: fake_macro_tile_slot = 0;  3: fake_macro_tile_slot = 6;  4: fake_macro_tile_slot = 7;  5: fake_macro_tile_slot = 1;  6: fake_macro_tile_slot = 4;  default: fake_macro_tile_slot = 2;  endcase
                6: case (tile_y_mod8) 0: fake_macro_tile_slot = 14; 1: fake_macro_tile_slot = 8;  2: fake_macro_tile_slot = 13; 3: fake_macro_tile_slot = 11; 4: fake_macro_tile_slot = 10; 5: fake_macro_tile_slot = 12; 6: fake_macro_tile_slot = 9;  default: fake_macro_tile_slot = 15; endcase
                default: case (tile_y_mod8) 0: fake_macro_tile_slot = 9;  1: fake_macro_tile_slot = 15; 2: fake_macro_tile_slot = 10; 3: fake_macro_tile_slot = 12; 4: fake_macro_tile_slot = 13; 5: fake_macro_tile_slot = 11; 6: fake_macro_tile_slot = 14; default: fake_macro_tile_slot = 8;  endcase
            endcase
        end
    endfunction

    function automatic integer fake_rgba_tile_base_word;
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
            addr_bytes   = (FAKE_RGBA_TILE_PITCH * (macro_tile_y * 4) * 4) +
                           (macro_tile_x * 4096) +
                           (fake_macro_tile_slot(temp_tile_x, temp_tile_y) * 256);
            if (((16 * FAKE_RGBA_TILE_PITCH) % (1 << 16)) == 0) begin
                tile_row_pixels = tile_y * 4;
                bit_val         = ((addr_bytes >> 15) & 1) ^ ((tile_row_pixels >> 4) & 1);
                if (bit_val != 0)
                    addr_bytes = addr_bytes | (1 << 15);
                else
                    addr_bytes = addr_bytes & ~(1 << 15);
            end
            if (((16 * FAKE_RGBA_TILE_PITCH) % (1 << 17)) == 0) begin
                tile_row_pixels = tile_y * 4;
                bit_val         = ((addr_bytes >> 16) & 1) ^ ((tile_row_pixels >> 5) & 1);
                if (bit_val != 0)
                    addr_bytes = addr_bytes | (1 << 16);
                else
                    addr_bytes = addr_bytes & ~(1 << 16);
            end
            fake_rgba_tile_base_word = addr_bytes >> 3;
        end
    endfunction

    function automatic integer fake_plane_tile_base_word;
        input integer tile_x;
        input integer tile_y;
        input integer tile_width;
        input integer tile_height;
        input integer surface_pitch_bytes;
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
            addr_bytes   = (surface_pitch_bytes * (macro_tile_y * 4) * tile_height) +
                           (macro_tile_x * 4096) +
                           (fake_macro_tile_slot(temp_tile_x, temp_tile_y) * 256);
            if (((16 * surface_pitch_bytes) % (1 << 16)) == 0) begin
                if (((bpp == 1) && (tile_width == 32) && (tile_height == 8)) ||
                    ((bpp == 2) && (tile_width == 16) && (tile_height == 8)))
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                else
                    tile_row_pixels = (tile_y * tile_height) >> 4;
                bit_val = ((addr_bytes >> 15) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0)
                    addr_bytes = addr_bytes | (1 << 15);
                else
                    addr_bytes = addr_bytes & ~(1 << 15);
            end
            if (((16 * surface_pitch_bytes) % (1 << 17)) == 0) begin
                if (((bpp == 1) && (tile_width == 32) && (tile_height == 8)) ||
                    ((bpp == 2) && (tile_width == 16) && (tile_height == 8)))
                    tile_row_pixels = (tile_y * tile_height) >> 6;
                else
                    tile_row_pixels = (tile_y * tile_height) >> 5;
                bit_val = ((addr_bytes >> 16) & 1) ^ (tile_row_pixels & 1);
                if (bit_val != 0)
                    addr_bytes = addr_bytes | (1 << 16);
                else
                    addr_bytes = addr_bytes & ~(1 << 16);
            end
            fake_plane_tile_base_word = addr_bytes >> 3;
        end
    endfunction

    function automatic integer fake_tile_active_cols;
        input [4:0] fmt;
        begin
            if ((fmt == 5'd0) || (fmt == 5'd1))
                fake_tile_active_cols = FAKE_RGBA_TILE_COLS;
            else if (fmt == 5'd8)
                fake_tile_active_cols = FAKE_NV12_Y_TILE_COLS;
            else if (fmt == 5'd9)
                fake_tile_active_cols = FAKE_NV12_UV_TILE_COLS;
            else if (fmt == 5'd14)
                fake_tile_active_cols = FAKE_G016_Y_TILE_COLS;
            else
                fake_tile_active_cols = FAKE_G016_UV_TILE_COLS;
        end
    endfunction

    function automatic integer fake_tile_active_rows;
        input [4:0] fmt;
        begin
            if ((fmt == 5'd0) || (fmt == 5'd1))
                fake_tile_active_rows = (FAKE_RGBA_ACTIVE_H + 3) / 4;
            else if (fmt == 5'd8)
                fake_tile_active_rows = (FAKE_NV12_ACTIVE_H + 7) / 8;
            else if (fmt == 5'd9)
                fake_tile_active_rows = (FAKE_NV12_UV_ACTIVE_H + 7) / 8;
            else if (fmt == 5'd14)
                fake_tile_active_rows = (FAKE_G016_ACTIVE_H + 3) / 4;
            else
                fake_tile_active_rows = (FAKE_G016_UV_ACTIVE_H + 3) / 4;
        end
    endfunction

    function automatic [7:0] fake_meta_byte;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        integer offset_local;
        integer word_idx;
        integer byte_sel;
        reg [63:0] word_local;
        begin
            offset_local = ((tile_y >> 4) * FAKE_META_PITCH_BYTES * 16) +
                           ((tile_x >> 4) << 8) +
                           (((tile_y >> 3) & 1) << 7) +
                           (((tile_x >> 3) & 1) << 6) +
                           ((tile_y & 7) << 3) +
                           (tile_x & 7);
            word_idx   = offset_local >> 3;
            byte_sel   = offset_local & 7;
            word_local = 64'd0;
            if ((fmt == 5'd9) || (fmt == 5'd15)) begin
                if ((word_idx >= 0) && (word_idx < FAKE_META1_WORDS64_SAFE))
                    word_local = fake_meta1_words[word_idx];
            end else begin
                if ((word_idx >= 0) && (word_idx < FAKE_META0_WORDS64_SAFE))
                    word_local = fake_meta0_words[word_idx];
            end
            fake_meta_byte = word_local[byte_sel*8 +: 8];
        end
    endfunction

    function automatic [63:0] fake_tile_addr;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        integer base_word;
        begin
            if ((fmt == 5'd0) || (fmt == 5'd1)) begin
                base_word      = fake_rgba_tile_base_word(tile_x, tile_y);
                fake_tile_addr = FAKE_TILE_BASE_Y_ADDR + (base_word << 3);
            end else if (fmt == 5'd8) begin
                base_word      = fake_plane_tile_base_word(tile_x, tile_y, 32, 8, FAKE_NV12_TILE_PITCH, 1);
                fake_tile_addr = FAKE_TILE_BASE_Y_ADDR + (base_word << 3);
            end else if (fmt == 5'd14) begin
                base_word      = fake_plane_tile_base_word(tile_x, tile_y, 32, 4, FAKE_G016_TILE_PITCH, 2);
                fake_tile_addr = FAKE_TILE_BASE_Y_ADDR + (base_word << 3);
            end else if (fmt == 5'd15) begin
                base_word      = fake_plane_tile_base_word(tile_x, tile_y, 32, 4, FAKE_G016_TILE_PITCH, 2);
                fake_tile_addr = FAKE_TILE_BASE_UV_ADDR + (base_word << 3);
            end else begin
                base_word      = fake_plane_tile_base_word(tile_x, tile_y, 16, 8, FAKE_NV12_TILE_PITCH, 2);
                fake_tile_addr = FAKE_TILE_BASE_UV_ADDR + (base_word << 3);
            end
        end
    endfunction

    function automatic [63:0] fake_tile_addr_with_alen;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input [2:0] alen;
        input is_lossy_rgba_2_1;
        reg [63:0] addr_local;
        integer base_word;
        integer payload_bytes;
        begin
            if ((fmt == 5'd0) && is_lossy_rgba_2_1) begin
                base_word  = fake_rgba_tile_base_word(tile_x, tile_y >> 1);
                addr_local = FAKE_TILE_BASE_Y_ADDR + (base_word << 3) +
                             ((tile_y & 1) ? 64'd128 : 64'd0);
            end else begin
                addr_local    = fake_tile_addr(fmt, tile_x, tile_y);
                payload_bytes = (alen + 1) << 5;
                if ((payload_bytes <= 128) && (addr_local[8] ^ addr_local[9]))
                    addr_local = addr_local + 64'd128;
            end
            fake_tile_addr_with_alen = addr_local;
        end
    endfunction

    function automatic [255:0] fake_pack_cmp_axi_word;
        input [63:0] beat_addr;
        integer word_idx;
        reg [63:0] w0;
        reg [63:0] w1;
        reg [63:0] w2;
        reg [63:0] w3;
        begin
            w0 = 64'd0;
            w1 = 64'd0;
            w2 = 64'd0;
            w3 = 64'd0;
            if ((FAKE_TILE_BASE_UV_ADDR != 64'd0) &&
                (beat_addr >= FAKE_TILE_BASE_UV_ADDR)) begin
                word_idx = (beat_addr - FAKE_TILE_BASE_UV_ADDR) >> 3;
                if ((word_idx + 0) < FAKE_CMP1_WORDS64_SAFE) w0 = fake_cmp1_words[word_idx + 0];
                if ((word_idx + 1) < FAKE_CMP1_WORDS64_SAFE) w1 = fake_cmp1_words[word_idx + 1];
                if ((word_idx + 2) < FAKE_CMP1_WORDS64_SAFE) w2 = fake_cmp1_words[word_idx + 2];
                if ((word_idx + 3) < FAKE_CMP1_WORDS64_SAFE) w3 = fake_cmp1_words[word_idx + 3];
            end else begin
                word_idx = (beat_addr - FAKE_TILE_BASE_Y_ADDR) >> 3;
                if ((word_idx + 0) < FAKE_CMP0_WORDS64_SAFE) w0 = fake_cmp0_words[word_idx + 0];
                if ((word_idx + 1) < FAKE_CMP0_WORDS64_SAFE) w1 = fake_cmp0_words[word_idx + 1];
                if ((word_idx + 2) < FAKE_CMP0_WORDS64_SAFE) w2 = fake_cmp0_words[word_idx + 2];
                if ((word_idx + 3) < FAKE_CMP0_WORDS64_SAFE) w3 = fake_cmp0_words[word_idx + 3];
            end
            fake_pack_cmp_axi_word = {w3, w2, w1, w0};
        end
    endfunction

    function automatic [255:0] fake_pack_tile_axi_word;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer beat_idx;
        integer word64_base;
        integer word_idx;
        reg [63:0] w0;
        reg [63:0] w1;
        reg [63:0] w2;
        reg [63:0] w3;
        begin
            if ((fmt == 5'd0) || (fmt == 5'd1)) begin
                word64_base = fake_rgba_tile_base_word(tile_x, tile_y);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < FAKE_TILE0_WORDS64_SAFE) ? fake_tile0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < FAKE_TILE0_WORDS64_SAFE) ? fake_tile0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < FAKE_TILE0_WORDS64_SAFE) ? fake_tile0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < FAKE_TILE0_WORDS64_SAFE) ? fake_tile0_words[word_idx + 3] : 64'd0;
            end else if (fmt == 5'd8) begin
                word64_base = fake_plane_tile_base_word(tile_x, tile_y, 32, 8, FAKE_NV12_TILE_PITCH, 1);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < FAKE_TILE0_WORDS64_SAFE) ? fake_tile0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < FAKE_TILE0_WORDS64_SAFE) ? fake_tile0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < FAKE_TILE0_WORDS64_SAFE) ? fake_tile0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < FAKE_TILE0_WORDS64_SAFE) ? fake_tile0_words[word_idx + 3] : 64'd0;
            end else if (fmt == 5'd14) begin
                word64_base = fake_plane_tile_base_word(tile_x, tile_y, 32, 4, FAKE_G016_TILE_PITCH, 2);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < FAKE_TILE0_WORDS64_SAFE) ? fake_tile0_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < FAKE_TILE0_WORDS64_SAFE) ? fake_tile0_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < FAKE_TILE0_WORDS64_SAFE) ? fake_tile0_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < FAKE_TILE0_WORDS64_SAFE) ? fake_tile0_words[word_idx + 3] : 64'd0;
            end else if (fmt == 5'd15) begin
                word64_base = fake_plane_tile_base_word(tile_x, tile_y, 32, 4, FAKE_G016_TILE_PITCH, 2);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < FAKE_TILE1_WORDS64_SAFE) ? fake_tile1_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < FAKE_TILE1_WORDS64_SAFE) ? fake_tile1_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < FAKE_TILE1_WORDS64_SAFE) ? fake_tile1_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < FAKE_TILE1_WORDS64_SAFE) ? fake_tile1_words[word_idx + 3] : 64'd0;
            end else begin
                word64_base = fake_plane_tile_base_word(tile_x, tile_y, 16, 8, FAKE_NV12_TILE_PITCH, 2);
                word_idx    = word64_base + beat_idx * 4;
                w0 = (word_idx + 0 < FAKE_TILE1_WORDS64_SAFE) ? fake_tile1_words[word_idx + 0] : 64'd0;
                w1 = (word_idx + 1 < FAKE_TILE1_WORDS64_SAFE) ? fake_tile1_words[word_idx + 1] : 64'd0;
                w2 = (word_idx + 2 < FAKE_TILE1_WORDS64_SAFE) ? fake_tile1_words[word_idx + 2] : 64'd0;
                w3 = (word_idx + 3 < FAKE_TILE1_WORDS64_SAFE) ? fake_tile1_words[word_idx + 3] : 64'd0;
            end
            fake_pack_tile_axi_word = {w3, w2, w1, w0};
        end
    endfunction

    initial begin
        for (fake_init_idx = 0; fake_init_idx < FAKE_TILE0_WORDS64_SAFE; fake_init_idx = fake_init_idx + 1) fake_tile0_words[fake_init_idx] = 64'd0;
        for (fake_init_idx = 0; fake_init_idx < FAKE_TILE1_WORDS64_SAFE; fake_init_idx = fake_init_idx + 1) fake_tile1_words[fake_init_idx] = 64'd0;
        for (fake_init_idx = 0; fake_init_idx < FAKE_CMP0_WORDS64_SAFE;  fake_init_idx = fake_init_idx + 1) fake_cmp0_words[fake_init_idx]  = 64'd0;
        for (fake_init_idx = 0; fake_init_idx < FAKE_CMP1_WORDS64_SAFE;  fake_init_idx = fake_init_idx + 1) fake_cmp1_words[fake_init_idx]  = 64'd0;
        for (fake_init_idx = 0; fake_init_idx < FAKE_META0_WORDS64_SAFE; fake_init_idx = fake_init_idx + 1) fake_meta0_words[fake_init_idx] = 64'd0;
        for (fake_init_idx = 0; fake_init_idx < FAKE_META1_WORDS64_SAFE; fake_init_idx = fake_init_idx + 1) fake_meta1_words[fake_init_idx] = 64'd0;

        if (FAKE_MODEL_EN != 0) begin
            fake_file_fd = $fopen("inject_tile_plane0.txt", "r");
            if (fake_file_fd != 0) begin
                $fclose(fake_file_fd);
                $readmemh("inject_tile_plane0.txt", fake_tile0_words);
            end else begin
                fake_file_fd = $fopen("expected_tile_plane0.memh", "r");
                if (fake_file_fd != 0) begin
                    $fclose(fake_file_fd);
                    $readmemh("expected_tile_plane0.memh", fake_tile0_words);
                end
            end

            fake_file_fd = $fopen("inject_tile_plane1.txt", "r");
            if (fake_file_fd != 0) begin
                $fclose(fake_file_fd);
                $readmemh("inject_tile_plane1.txt", fake_tile1_words);
            end else begin
                fake_file_fd = $fopen("expected_tile_plane1.memh", "r");
                if (fake_file_fd != 0) begin
                    $fclose(fake_file_fd);
                    $readmemh("expected_tile_plane1.memh", fake_tile1_words);
                end
            end

            fake_file_fd = $fopen("input_tile_plane0.txt", "r");
            if (fake_file_fd != 0) begin
                $fclose(fake_file_fd);
                $readmemh("input_tile_plane0.txt", fake_cmp0_words);
            end else begin
                fake_file_fd = $fopen("expected_cmp_plane0.memh", "r");
                if (fake_file_fd != 0) begin
                    $fclose(fake_file_fd);
                    $readmemh("expected_cmp_plane0.memh", fake_cmp0_words);
                end
            end

            fake_file_fd = $fopen("input_tile_plane1.txt", "r");
            if (fake_file_fd != 0) begin
                $fclose(fake_file_fd);
                $readmemh("input_tile_plane1.txt", fake_cmp1_words);
            end else begin
                fake_file_fd = $fopen("expected_cmp_plane1.memh", "r");
                if (fake_file_fd != 0) begin
                    $fclose(fake_file_fd);
                    $readmemh("expected_cmp_plane1.memh", fake_cmp1_words);
                end
            end

            fake_file_fd = $fopen("input_meta_plane0.txt", "r");
            if (fake_file_fd != 0) begin
                $fclose(fake_file_fd);
                $readmemh("input_meta_plane0.txt", fake_meta0_words);
            end else begin
                fake_file_fd = $fopen("expected_meta_plane0.memh", "r");
                if (fake_file_fd != 0) begin
                    $fclose(fake_file_fd);
                    $readmemh("expected_meta_plane0.memh", fake_meta0_words);
                end
            end

            fake_file_fd = $fopen("input_meta_plane1.txt", "r");
            if (fake_file_fd != 0) begin
                $fclose(fake_file_fd);
                $readmemh("input_meta_plane1.txt", fake_meta1_words);
            end else begin
                fake_file_fd = $fopen("expected_meta_plane1.memh", "r");
                if (fake_file_fd != 0) begin
                    $fclose(fake_file_fd);
                    $readmemh("expected_meta_plane1.memh", fake_meta1_words);
                end
            end
        end
    end

    assign fake_model_active            = (FAKE_MODEL_EN != 0);
    assign ci_fire                      = i_ci_valid && o_ci_ready;
    assign co_fire                      = o_co_valid && i_co_ready;
    assign cvi_fire                     = i_cvi_valid && o_cvi_ready;
    assign out_fire                     = o_rvo_valid && i_rvo_ready;
    assign o_co_valid                   = r_co_valid;
    assign o_co_alen                    = 3'd7;
    assign o_co_sb                      = r_ci_sb[0];
    assign need_input_beat              = r_tile_active && (r_in_beats_left != 4'd0);
    assign pad_active                   = r_tile_active && (r_in_beats_left == 4'd0) && (r_out_beats_left != 4'd0);
    assign fake_out_active              = r_tile_active && (r_out_beats_left != 4'd0);
    assign fake_cvi_active              = r_tile_active && (r_in_beats_left != 4'd0);
    assign fake_out_done                = fake_model_active && out_fire && (r_out_beats_left <= 4'd1);
    assign fake_cvi_done                = fake_model_active && cvi_fire && (r_in_beats_left <= 4'd1);
    assign fake_tile_done               = ((r_out_beats_left == 4'd0) || fake_out_done) &&
                                          ((r_in_beats_left == 4'd0) || fake_cvi_done);
    assign o_ci_ready                   = i_ubwc_en && !r_reset_sync && !r_tile_active &&
                                          !r_co_valid && i_co_ready;
    assign o_cvi_ready                  = fake_model_active ?
                                          (i_ubwc_en && !r_reset_sync && fake_cvi_active) :
                                          (i_ubwc_en && !r_reset_sync && r_tile_active &&
                                           need_input_beat && i_rvo_ready);
    assign o_rvo_valid                  = fake_model_active ?
                                          (i_ubwc_en && !r_reset_sync && fake_out_active) :
                                          (i_ubwc_en && !r_reset_sync && r_tile_active &&
                                           (need_input_beat ? i_cvi_valid : pad_active));
    assign fake_rvo_data                = fake_pack_tile_axi_word(r_ci_format,
                                                                  r_ci_xcoord,
                                                                  r_ci_ycoord,
                                                                  fake_rvo_beat_idx);
    assign o_rvo_data                   = fake_model_active ?
                                          fake_rvo_data :
                                          (need_input_beat ? i_cvi_data : 256'd0);
    assign o_rvo_last                   = fake_model_active ?
                                          (fake_out_active && (r_out_beats_left == 4'd1)) :
                                          (r_tile_active && (r_out_beats_left == 4'd1));
    assign o_idle                       = !r_reset_sync &&
                                          !r_tile_active &&
                                          !i_ci_valid &&
                                          !i_cvi_valid &&
                                          (!r_co_valid || i_co_ready) &&
                                          (!o_rvo_valid || i_rvo_ready);
    assign o_error                      = 7'd0;

    assign ci_metadata_from_mem         = fake_meta_byte(i_ci_format, i_ci_xcoord, i_ci_ycoord);
    assign ci_metadata_eff              = fake_model_active ? ci_metadata_from_mem : {4'd0, i_ci_metadata};
    assign ci_coord_active              = !fake_model_active ||
                                          ((i_ci_xcoord < fake_tile_active_cols(i_ci_format)) &&
                                           (i_ci_ycoord < fake_tile_active_rows(i_ci_format)));
    assign ci_has_payload               = !i_ci_metadata[3];
    assign ci_alen_from_metadata        = ci_coord_active ? ci_metadata_eff[3:1] :
                                                            3'd0;
    assign ci_cmp_addr_from_metadata    = fake_tile_addr_with_alen(i_ci_format,
                                                                   i_ci_xcoord,
                                                                   i_ci_ycoord,
                                                                   ci_alen_from_metadata,
                                                                   i_ci_lossy && (i_ci_format == 5'd0));
    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_reset_sync <= 1'b1;
        else
            r_reset_sync <= i_sreset;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_co_valid <= 1'b0;
        else if (r_reset_sync || !i_ubwc_en)
            r_co_valid <= 1'b0;
        else if (co_fire)
            r_co_valid <= 1'b0;
        else if (ci_fire)
            r_co_valid <= 1'b1;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_tile_active <= 1'b0;
        else if (r_reset_sync || !i_ubwc_en)
            r_tile_active <= 1'b0;
        else if (ci_fire)
            r_tile_active <= 1'b1;
        else if (fake_model_active && r_tile_active && fake_tile_done)
            r_tile_active <= 1'b0;
        else if (!fake_model_active && out_fire && r_tile_active && (r_out_beats_left <= 4'd1))
            r_tile_active <= 1'b0;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_out_beats_left <= 4'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_out_beats_left <= 4'd0;
        else if (ci_fire)
            r_out_beats_left <= TILE_OUT_BEATS;
        else if (out_fire && r_tile_active && (r_out_beats_left <= 4'd1))
            r_out_beats_left <= 4'd0;
        else if (out_fire && r_tile_active)
            r_out_beats_left <= r_out_beats_left - 4'd1;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_in_beats_left <= 4'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_in_beats_left <= 4'd0;
        else if (ci_fire)
            r_in_beats_left <= ci_has_payload ? ({1'b0, i_ci_alen} + 4'd1) :
                                                 4'd0;
        else if (cvi_fire && r_tile_active && (r_in_beats_left <= 4'd1))
            r_in_beats_left <= 4'd0;
        else if (cvi_fire && r_tile_active && (r_in_beats_left != 4'd0))
            r_in_beats_left <= r_in_beats_left - 4'd1;
        else if (!fake_model_active && out_fire && r_tile_active && (r_out_beats_left <= 4'd1))
            r_in_beats_left <= 4'd0;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_ci_alen <= 3'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_ci_alen <= 3'd0;
        else if (ci_fire)
            r_ci_alen <= i_ci_alen;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_ci_format <= 5'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_ci_format <= 5'd0;
        else if (ci_fire)
            r_ci_format <= i_ci_format;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_ci_metadata <= 4'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_ci_metadata <= 4'd0;
        else if (ci_fire)
            r_ci_metadata <= i_ci_metadata;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_ci_sb <= {SB_WIDTH{1'b0}};
        else if (r_reset_sync || !i_ubwc_en)
            r_ci_sb <= {SB_WIDTH{1'b0}};
        else if (ci_fire)
            r_ci_sb <= i_ci_sb;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_ci_xcoord <= 12'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_ci_xcoord <= 12'd0;
        else if (ci_fire)
            r_ci_xcoord <= i_ci_xcoord;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_ci_ycoord <= 10'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_ci_ycoord <= 10'd0;
        else if (ci_fire)
            r_ci_ycoord <= i_ci_ycoord;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_ci_fcnt <= 4'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_ci_fcnt <= 4'd0;
        else if (ci_fire)
            r_ci_fcnt <= i_ci_fcnt;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_cvi_format <= 5'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_cvi_format <= 5'd0;
        else if (cvi_fire)
            r_cvi_format <= i_cvi_format;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_cvi_xcoord <= 12'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_cvi_xcoord <= 12'd0;
        else if (cvi_fire)
            r_cvi_xcoord <= i_cvi_xcoord;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_cvi_ycoord <= 10'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_cvi_ycoord <= 10'd0;
        else if (cvi_fire)
            r_cvi_ycoord <= i_cvi_ycoord;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_cvi_fcnt <= 4'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_cvi_fcnt <= 4'd0;
        else if (cvi_fire)
            r_cvi_fcnt <= i_cvi_fcnt;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_cvi_beat_idx <= 4'd0;
        else if (r_reset_sync || !i_ubwc_en || !fake_model_active)
            fake_cvi_beat_idx <= 4'd0;
        else if (ci_fire)
            fake_cvi_beat_idx <= 4'd0;
        else if (cvi_fire && (r_in_beats_left > 4'd1))
            fake_cvi_beat_idx <= fake_cvi_beat_idx + 4'd1;
        else if (cvi_fire)
            fake_cvi_beat_idx <= 4'd0;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_rvo_beat_idx <= 4'd0;
        else if (r_reset_sync || !i_ubwc_en || !fake_model_active)
            fake_rvo_beat_idx <= 4'd0;
        else if (ci_fire)
            fake_rvo_beat_idx <= 4'd0;
        else if (out_fire && (r_out_beats_left > 4'd1))
            fake_rvo_beat_idx <= fake_rvo_beat_idx + 4'd1;
        else if (out_fire)
            fake_rvo_beat_idx <= 4'd0;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_cvi_cmd_addr <= 64'd0;
        else if (r_reset_sync || !i_ubwc_en || !fake_model_active)
            fake_cvi_cmd_addr <= 64'd0;
        else if (ci_fire)
            fake_cvi_cmd_addr <= ci_cmp_addr_from_metadata;
    end

endmodule
