module ubwc_enc_vivo_top
    #(
        parameter                                     SB_DW                          = 1,
        parameter integer                             FAKE_MODEL_EN                  = 0,
        parameter integer                             FAKE_TILE_EXPECT_LINEAR        = 0,
        parameter integer                             FAKE_IMG_W                     = 4096,
        parameter integer                             FAKE_RGBA_ACTIVE_H             = 600,
        parameter integer                             FAKE_RGBA_TILE_PITCH           = 16384,
        parameter integer                             FAKE_RGBA_TILE_COLS            = 256,
        parameter integer                             FAKE_RGBA_TILE_ROWS            = 152,
        parameter integer                             FAKE_NV12_ACTIVE_H             = 600,
        parameter integer                             FAKE_NV12_UV_ACTIVE_H          = 300,
        parameter integer                             FAKE_NV12_TILE_PITCH           = 4096,
        parameter integer                             FAKE_NV12_Y_TILE_COLS          = 128,
        parameter integer                             FAKE_NV12_UV_TILE_COLS         = 128,
        parameter integer                             FAKE_NV12_Y_TILE_ROWS          = 80,
        parameter integer                             FAKE_NV12_UV_TILE_ROWS         = 40,
        parameter integer                             FAKE_G016_ACTIVE_H             = 600,
        parameter integer                             FAKE_G016_UV_ACTIVE_H          = 300,
        parameter integer                             FAKE_G016_TILE_PITCH           = 8192,
        parameter integer                             FAKE_G016_Y_TILE_COLS          = 128,
        parameter integer                             FAKE_G016_UV_TILE_COLS         = 128,
        parameter integer                             FAKE_G016_Y_TILE_ROWS          = 152,
        parameter integer                             FAKE_G016_UV_TILE_ROWS         = 76,
        parameter integer                             FAKE_META_PITCH_BYTES          = 512,
        parameter [63                     :0]         FAKE_TILE_BASE_Y_ADDR          = 64'h0000_0000_8000_0000,
        parameter [63                     :0]         FAKE_TILE_BASE_UV_ADDR         = 64'h0000_0000_8020_0000,
        parameter [63                     :0]         FAKE_META_BASE_Y_ADDR          = 64'h0000_0000_8000_0000,
        parameter [63                     :0]         FAKE_META_BASE_UV_ADDR         = 64'h0000_0000_8020_0000,
        parameter integer                             FAKE_TILE0_WORDS64             = 1,
        parameter integer                             FAKE_TILE1_WORDS64             = 1,
        parameter integer                             FAKE_CMP0_WORDS64              = 1,
        parameter integer                             FAKE_CMP1_WORDS64              = 1,
        parameter integer                             FAKE_META0_WORDS64             = 1,
        parameter integer                             FAKE_META1_WORDS64             = 1
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
        input   wire    [7                      :0]         i_ci_metadata                   ,
        input   wire                                        i_ci_forced_pcm                 ,
        input   wire    [15                     :0]         i_ci_xcoord                     ,
        input   wire    [15                     :0]         i_ci_ycoord                     ,
        input   wire    [3                      :0]         i_ci_fcnt                       ,
        input   wire                                        i_ci_lossy                      ,
        input   wire    [SB_DW                -1:0]         i_ci_sb                         ,
        input   wire    [2                      :0]         i_ci_ubwc_cfg_0                 ,
        input   wire    [2                      :0]         i_ci_ubwc_cfg_1                 ,
        input   wire    [3                      :0]         i_ci_ubwc_cfg_2                 ,
        input   wire    [3                      :0]         i_ci_ubwc_cfg_3                 ,
        input   wire    [3                      :0]         i_ci_ubwc_cfg_4                 ,
        input   wire    [3                      :0]         i_ci_ubwc_cfg_5                 ,
        input   wire    [1                      :0]         i_ci_ubwc_cfg_6                 ,
        input   wire    [1                      :0]         i_ci_ubwc_cfg_7                 ,
        input   wire    [1                      :0]         i_ci_ubwc_cfg_8                 ,
        input   wire    [2                      :0]         i_ci_ubwc_cfg_9                 ,
        input   wire    [5                      :0]         i_ci_ubwc_cfg_10                ,
        input   wire    [5                      :0]         i_ci_ubwc_cfg_11                ,
        input   wire    [3                      :0]         i_ci_ubwc_ver                   ,

        input   wire                                        i_rvi_valid                     ,
        output  wire                                        o_rvi_ready                     ,
        input   wire    [255                    :0]         i_rvi_data                      ,
        input   wire    [31                     :0]         i_rvi_mask                      ,
        input   wire                                        i_rvi_last                      ,
        input   wire    [4                      :0]         i_rvi_format                    ,
        input   wire    [15                     :0]         i_rvi_xcoord                    ,
        input   wire    [15                     :0]         i_rvi_ycoord                    ,
        input   wire    [3                      :0]         i_rvi_fcnt                      ,

        output  reg                                         o_co_valid                      ,
        input   wire                                        i_co_ready                      ,
        output  reg     [2                      :0]         o_co_alen                       ,
        output  reg                                         o_co_pcm                        ,
        output  reg     [SB_DW                -1:0]         o_co_sb                         ,

        output  wire                                        o_cvo_valid                     ,
        input   wire                                        i_cvo_ready                     ,
        output  wire    [255                    :0]         o_cvo_data                      ,
        output  wire    [31                     :0]         o_cvo_mask                      ,
        output  wire                                        o_cvo_last                      ,

        output  wire                                        o_idle                          ,
        output  wire                                        o_error
);

    localparam  integer                             CI_READY_PERIOD                 = 24;
    localparam  integer                             CI_CNT_W                        = (CI_READY_PERIOD <= 1) ? 1 : $clog2(CI_READY_PERIOD);
    localparam  [CI_CNT_W            -1 :0]         CI_READY_PERIOD_LAST            = CI_CNT_W'(CI_READY_PERIOD - 1);
    localparam  integer                             FAKE_TILE0_WORDS64_SAFE         = (FAKE_TILE0_WORDS64 > 0) ? FAKE_TILE0_WORDS64 : 1;
    localparam  integer                             FAKE_TILE1_WORDS64_SAFE         = (FAKE_TILE1_WORDS64 > 0) ? FAKE_TILE1_WORDS64 : 1;
    localparam  integer                             FAKE_CMP0_WORDS64_SAFE          = (FAKE_CMP0_WORDS64  > 0) ? FAKE_CMP0_WORDS64  : 1;
    localparam  integer                             FAKE_CMP1_WORDS64_SAFE          = (FAKE_CMP1_WORDS64  > 0) ? FAKE_CMP1_WORDS64  : 1;
    localparam  integer                             FAKE_META0_WORDS64_SAFE         = (FAKE_META0_WORDS64 > 0) ? FAKE_META0_WORDS64 : 1;
    localparam  integer                             FAKE_META1_WORDS64_SAFE         = (FAKE_META1_WORDS64 > 0) ? FAKE_META1_WORDS64 : 1;

    wire                                            fake_model_active               ;
    wire                                            fake_cmd_can_accept             ;
    wire                                            fake_ci_cmd_can_accept          ;
    wire                                            fake_cvo_fire                   ;
    wire                                            fake_cvo_last_w                 ;
    wire                                            fake_rvi_fire                   ;
    wire                                            fake_rvi_tile_start             ;
    wire                                            fake_rvi_start_fire             ;
    wire                                            ci_period_hit                   ;
    wire                                            ci_fire                         ;
    wire                                            ci_coord_active                 ;
    wire        [7                      :0]         ci_metadata_eff                 ;
    wire        [7                      :0]         ci_metadata_from_mem            ;
    wire        [2                      :0]         ci_alen_from_metadata           ;
    wire        [3                      :0]         ci_valid_beats_from_metadata    ;
    wire        [3                      :0]         ci_total_beats_from_metadata    ;
    wire        [63                     :0]         ci_cmp_addr_from_metadata       ;
    wire        [255                    :0]         fake_cvo_data_w                 ;
    wire        [31                     :0]         fake_cvo_mask_w                 ;

    reg                                             fake_model_active_r             ;
    reg                                             fake_ci_cmd_valid_r             ;
    reg                                             fake_cvo_cmd_valid_r            ;
    reg         [CI_CNT_W            -1 :0]         ci_ready_cnt_r                  ;
    reg         [63                     :0]         fake_ci_cmd_addr_r              ;
    reg         [3                      :0]         fake_ci_valid_beats_r           ;
    reg         [3                      :0]         fake_ci_total_beats_r           ;
    reg         [63                     :0]         fake_cvo_cmd_addr_r             ;
    reg         [3                      :0]         fake_cvo_valid_beats_r          ;
    reg         [3                      :0]         fake_cvo_total_beats_r          ;
    reg         [3                      :0]         fake_cvo_beat_idx_r             ;
    reg         [3                      :0]         fake_rvi_beat_idx_r             ;

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
        reg [63:0] base_addr_local;
        reg [63:0] addr_unit_local;
        integer base_word;
        begin
            if ((fmt == 5'd0) && is_lossy_rgba_2_1) begin
                base_word  = fake_rgba_tile_base_word(tile_x, tile_y >> 1);
                addr_local = FAKE_TILE_BASE_Y_ADDR + (base_word << 3) +
                             ((tile_y & 1) ? 64'd128 : 64'd0);
            end else begin
                addr_local      = fake_tile_addr(fmt, tile_x, tile_y);
                base_addr_local = ((fmt == 5'd9) || (fmt == 5'd15)) ? FAKE_TILE_BASE_UV_ADDR : FAKE_TILE_BASE_Y_ADDR;
                addr_unit_local = (addr_local - base_addr_local) >> 4;
                if (alen <= 3'd3) begin
                    if (addr_unit_local[5] ^ addr_unit_local[4])
                        addr_local = addr_local + 64'd128;
                end
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

    function automatic [7:0] fake_linear_byte;
        input integer plane_sel;
        input integer byte_idx;
        integer word_idx;
        integer byte_off;
        reg [63:0] word_local;
        begin
            word_idx   = byte_idx / 8;
            byte_off   = byte_idx % 8;
            word_local = 64'd0;
            if (plane_sel == 0) begin
                if ((word_idx >= 0) && (word_idx < FAKE_TILE0_WORDS64_SAFE))
                    word_local = fake_tile0_words[word_idx];
            end else begin
                if ((word_idx >= 0) && (word_idx < FAKE_TILE1_WORDS64_SAFE))
                    word_local = fake_tile1_words[word_idx];
            end
            fake_linear_byte = word_local[byte_off*8 +: 8];
        end
    endfunction

    function automatic [255:0] fake_pack_linear_tile_axi_word;
        input [4:0] fmt;
        input integer tile_x;
        input integer tile_y;
        input integer beat_idx;
        integer plane_sel;
        integer tile_width_px;
        integer tile_height_ln;
        integer bytes_per_pixel;
        integer plane_active_h;
        integer plane_row_bytes;
        integer tile_row_bytes;
        integer beats_per_tile_row;
        integer row_in_tile;
        integer beat_in_row;
        integer row_abs;
        integer col_byte_base;
        integer byte_idx;
        integer src_byte_idx;
        integer sample_byte_idx;
        reg [15:0] sample16;
        reg [7:0] byte_local;
        reg [255:0] data_local;
        begin
            plane_sel       = 0;
            tile_width_px   = 16;
            tile_height_ln  = 4;
            bytes_per_pixel = 4;
            plane_active_h  = FAKE_RGBA_ACTIVE_H;
            plane_row_bytes = FAKE_IMG_W * 4;

            if (fmt == 5'd8) begin
                tile_width_px   = 32;
                tile_height_ln  = 8;
                bytes_per_pixel = 1;
                plane_active_h  = FAKE_NV12_ACTIVE_H;
                plane_row_bytes = FAKE_IMG_W;
            end else if (fmt == 5'd14) begin
                tile_width_px   = 32;
                tile_height_ln  = 4;
                bytes_per_pixel = 2;
                plane_active_h  = FAKE_G016_ACTIVE_H;
                plane_row_bytes = FAKE_IMG_W * 2;
            end else if (fmt == 5'd15) begin
                plane_sel       = 1;
                tile_width_px   = 32;
                tile_height_ln  = 4;
                bytes_per_pixel = 2;
                plane_active_h  = FAKE_G016_UV_ACTIVE_H;
                plane_row_bytes = FAKE_IMG_W * 2;
            end else if ((fmt != 5'd0) && (fmt != 5'd1)) begin
                plane_sel       = 1;
                tile_width_px   = 16;
                tile_height_ln  = 8;
                bytes_per_pixel = 2;
                plane_active_h  = FAKE_NV12_UV_ACTIVE_H;
                plane_row_bytes = FAKE_IMG_W;
            end

            tile_row_bytes    = tile_width_px * bytes_per_pixel;
            beats_per_tile_row = tile_row_bytes / 32;
            if (beats_per_tile_row <= 0)
                beats_per_tile_row = 1;
            row_in_tile  = beat_idx / beats_per_tile_row;
            beat_in_row  = beat_idx % beats_per_tile_row;
            row_abs      = tile_y * tile_height_ln + row_in_tile;
            col_byte_base = tile_x * tile_row_bytes + beat_in_row * 32;

            data_local = 256'd0;
            for (byte_idx = 0; byte_idx < 32; byte_idx = byte_idx + 1) begin
                if ((row_abs < plane_active_h) && ((col_byte_base + byte_idx) < plane_row_bytes)) begin
                    src_byte_idx = row_abs * plane_row_bytes + col_byte_base + byte_idx;
                    if ((fmt == 5'd14) || (fmt == 5'd15)) begin
                        sample_byte_idx = (src_byte_idx / 2) * 2;
                        sample16        = {fake_linear_byte(plane_sel, sample_byte_idx + 1),
                                           fake_linear_byte(plane_sel, sample_byte_idx)};
                        sample16        = sample16 & 16'hffc0;
                        byte_local      = (src_byte_idx[0] != 0) ? sample16[15:8] : sample16[7:0];
                    end else begin
                        byte_local      = fake_linear_byte(plane_sel, src_byte_idx);
                    end
                    data_local[byte_idx*8 +: 8] = byte_local;
                end
            end

            fake_pack_linear_tile_axi_word = data_local;
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
            w0 = 64'd0;
            w1 = 64'd0;
            w2 = 64'd0;
            w3 = 64'd0;
            if (FAKE_TILE_EXPECT_LINEAR != 0) begin
                fake_pack_tile_axi_word = fake_pack_linear_tile_axi_word(fmt,
                                                                         tile_x,
                                                                         tile_y,
                                                                         beat_idx);
            end else if ((fmt == 5'd0) || (fmt == 5'd1)) begin
                word64_base = fake_rgba_tile_base_word(tile_x, tile_y);
                word_idx    = word64_base + beat_idx * 4;
                if ((word_idx + 0) < FAKE_TILE0_WORDS64_SAFE) w0 = fake_tile0_words[word_idx + 0];
                if ((word_idx + 1) < FAKE_TILE0_WORDS64_SAFE) w1 = fake_tile0_words[word_idx + 1];
                if ((word_idx + 2) < FAKE_TILE0_WORDS64_SAFE) w2 = fake_tile0_words[word_idx + 2];
                if ((word_idx + 3) < FAKE_TILE0_WORDS64_SAFE) w3 = fake_tile0_words[word_idx + 3];
            end else if (fmt == 5'd8) begin
                word64_base = fake_plane_tile_base_word(tile_x, tile_y, 32, 8, FAKE_NV12_TILE_PITCH, 1);
                word_idx    = word64_base + beat_idx * 4;
                if ((word_idx + 0) < FAKE_TILE0_WORDS64_SAFE) w0 = fake_tile0_words[word_idx + 0];
                if ((word_idx + 1) < FAKE_TILE0_WORDS64_SAFE) w1 = fake_tile0_words[word_idx + 1];
                if ((word_idx + 2) < FAKE_TILE0_WORDS64_SAFE) w2 = fake_tile0_words[word_idx + 2];
                if ((word_idx + 3) < FAKE_TILE0_WORDS64_SAFE) w3 = fake_tile0_words[word_idx + 3];
            end else if (fmt == 5'd14) begin
                word64_base = fake_plane_tile_base_word(tile_x, tile_y, 32, 4, FAKE_G016_TILE_PITCH, 2);
                word_idx    = word64_base + beat_idx * 4;
                if ((word_idx + 0) < FAKE_TILE0_WORDS64_SAFE) w0 = fake_tile0_words[word_idx + 0];
                if ((word_idx + 1) < FAKE_TILE0_WORDS64_SAFE) w1 = fake_tile0_words[word_idx + 1];
                if ((word_idx + 2) < FAKE_TILE0_WORDS64_SAFE) w2 = fake_tile0_words[word_idx + 2];
                if ((word_idx + 3) < FAKE_TILE0_WORDS64_SAFE) w3 = fake_tile0_words[word_idx + 3];
            end else if (fmt == 5'd15) begin
                word64_base = fake_plane_tile_base_word(tile_x, tile_y, 32, 4, FAKE_G016_TILE_PITCH, 2);
                word_idx    = word64_base + beat_idx * 4;
                if ((word_idx + 0) < FAKE_TILE1_WORDS64_SAFE) w0 = fake_tile1_words[word_idx + 0];
                if ((word_idx + 1) < FAKE_TILE1_WORDS64_SAFE) w1 = fake_tile1_words[word_idx + 1];
                if ((word_idx + 2) < FAKE_TILE1_WORDS64_SAFE) w2 = fake_tile1_words[word_idx + 2];
                if ((word_idx + 3) < FAKE_TILE1_WORDS64_SAFE) w3 = fake_tile1_words[word_idx + 3];
            end else begin
                word64_base = fake_plane_tile_base_word(tile_x, tile_y, 16, 8, FAKE_NV12_TILE_PITCH, 2);
                word_idx    = word64_base + beat_idx * 4;
                if ((word_idx + 0) < FAKE_TILE1_WORDS64_SAFE) w0 = fake_tile1_words[word_idx + 0];
                if ((word_idx + 1) < FAKE_TILE1_WORDS64_SAFE) w1 = fake_tile1_words[word_idx + 1];
                if ((word_idx + 2) < FAKE_TILE1_WORDS64_SAFE) w2 = fake_tile1_words[word_idx + 2];
                if ((word_idx + 3) < FAKE_TILE1_WORDS64_SAFE) w3 = fake_tile1_words[word_idx + 3];
            end
            if (FAKE_TILE_EXPECT_LINEAR == 0)
                fake_pack_tile_axi_word = {w3, w2, w1, w0};
        end
    endfunction

    initial begin
        fake_model_active_r = (FAKE_MODEL_EN != 0);
        if ($test$plusargs("tb_non_fake_mode"))
            fake_model_active_r = 1'b0;

        for (fake_init_idx = 0; fake_init_idx < FAKE_TILE0_WORDS64_SAFE; fake_init_idx = fake_init_idx + 1) fake_tile0_words[fake_init_idx] = 64'd0;
        for (fake_init_idx = 0; fake_init_idx < FAKE_TILE1_WORDS64_SAFE; fake_init_idx = fake_init_idx + 1) fake_tile1_words[fake_init_idx] = 64'd0;
        for (fake_init_idx = 0; fake_init_idx < FAKE_CMP0_WORDS64_SAFE;  fake_init_idx = fake_init_idx + 1) fake_cmp0_words[fake_init_idx]  = 64'd0;
        for (fake_init_idx = 0; fake_init_idx < FAKE_CMP1_WORDS64_SAFE;  fake_init_idx = fake_init_idx + 1) fake_cmp1_words[fake_init_idx]  = 64'd0;
        for (fake_init_idx = 0; fake_init_idx < FAKE_META0_WORDS64_SAFE; fake_init_idx = fake_init_idx + 1) fake_meta0_words[fake_init_idx] = 64'd0;
        for (fake_init_idx = 0; fake_init_idx < FAKE_META1_WORDS64_SAFE; fake_init_idx = fake_init_idx + 1) fake_meta1_words[fake_init_idx] = 64'd0;

        if (fake_model_active_r) begin
            fake_file_fd = $fopen("expected_tile_plane0.memh", "r");
            if (fake_file_fd != 0) begin
                $fclose(fake_file_fd);
                $readmemh("expected_tile_plane0.memh", fake_tile0_words);
            end
            fake_file_fd = $fopen("expected_tile_plane1.memh", "r");
            if (fake_file_fd != 0) begin
                $fclose(fake_file_fd);
                $readmemh("expected_tile_plane1.memh", fake_tile1_words);
            end
            fake_file_fd = $fopen("expected_cmp_plane0.memh", "r");
            if (fake_file_fd != 0) begin
                $fclose(fake_file_fd);
                $readmemh("expected_cmp_plane0.memh", fake_cmp0_words);
            end
            fake_file_fd = $fopen("expected_cmp_plane1.memh", "r");
            if (fake_file_fd != 0) begin
                $fclose(fake_file_fd);
                $readmemh("expected_cmp_plane1.memh", fake_cmp1_words);
            end
            fake_file_fd = $fopen("expected_meta_plane0.memh", "r");
            if (fake_file_fd != 0) begin
                $fclose(fake_file_fd);
                $readmemh("expected_meta_plane0.memh", fake_meta0_words);
            end
            fake_file_fd = $fopen("expected_meta_plane1.memh", "r");
            if (fake_file_fd != 0) begin
                $fclose(fake_file_fd);
                $readmemh("expected_meta_plane1.memh", fake_meta1_words);
            end
        end
    end

    assign fake_model_active            = fake_model_active_r;
    assign fake_ci_cmd_can_accept       = !fake_model_active ||
                                          !fake_ci_cmd_valid_r;
    assign fake_cmd_can_accept          = !fake_model_active ||
                                          (fake_ci_cmd_valid_r &&
                                           (!fake_cvo_cmd_valid_r ||
                                            (fake_cvo_fire && fake_cvo_last_w)));
    assign ci_period_hit                = (ci_ready_cnt_r == CI_READY_PERIOD_LAST);
    assign ci_fire                      = i_ubwc_en && i_ci_valid && o_ci_ready;
    assign ci_metadata_from_mem         = fake_meta_byte(i_ci_format, i_ci_xcoord, i_ci_ycoord);
    assign ci_metadata_eff              = fake_model_active ? ci_metadata_from_mem : i_ci_metadata;
    assign ci_coord_active              = !fake_model_active ||
                                          ((i_ci_xcoord < fake_tile_active_cols(i_ci_format)) &&
                                           (i_ci_ycoord < fake_tile_active_rows(i_ci_format)));
    assign ci_alen_from_metadata        = ci_coord_active ? ci_metadata_eff[3:1] :
                                                            3'd0;
    assign ci_valid_beats_from_metadata = {1'b0, ci_alen_from_metadata} + 4'd1;
    assign ci_total_beats_from_metadata = (ci_valid_beats_from_metadata == 4'd0) ? 4'd1 :
                                                                                    ci_valid_beats_from_metadata;
    assign ci_cmp_addr_from_metadata    = fake_tile_addr_with_alen(i_ci_format,
                                                                   i_ci_xcoord,
                                                                   i_ci_ycoord,
                                                                   ci_alen_from_metadata,
                                                                   i_ci_lossy && (i_ci_format == 5'd0));
    assign fake_cvo_last_w              = (fake_cvo_beat_idx_r == (fake_cvo_total_beats_r - 4'd1));
    assign fake_cvo_fire                = o_cvo_valid && i_cvo_ready;
    assign fake_cvo_data_w              = fake_pack_cmp_axi_word(fake_cvo_cmd_addr_r +
                                                                 ({60'd0, fake_cvo_beat_idx_r} << 5));
    assign fake_cvo_mask_w              = (fake_cvo_beat_idx_r < fake_cvo_valid_beats_r) ? 32'hFFFF_FFFF :
                                                                                           32'd0;
    assign fake_rvi_fire                = i_rvi_valid && o_rvi_ready;
    assign fake_rvi_tile_start          = (fake_rvi_beat_idx_r == 4'd0);
    assign fake_rvi_start_fire          = fake_model_active && fake_rvi_fire && fake_rvi_tile_start;
    assign o_cvo_valid                  = fake_model_active ? (i_ubwc_en && fake_cvo_cmd_valid_r) :
                                                              (i_ubwc_en && i_rvi_valid);
    assign o_cvo_data                   = fake_model_active ? fake_cvo_data_w : i_rvi_data;
    assign o_cvo_mask                   = fake_model_active ? fake_cvo_mask_w : i_rvi_mask;
    assign o_cvo_last                   = fake_model_active ? fake_cvo_last_w : i_rvi_last;
    assign o_ci_ready                   = i_ubwc_en && ci_period_hit && i_co_ready &&
                                          fake_ci_cmd_can_accept;
    assign o_rvi_ready                  = fake_model_active ? (i_ubwc_en &&
                                                               (!fake_rvi_tile_start || fake_cmd_can_accept)) :
                                                              (i_ubwc_en && i_cvo_ready);
    assign o_idle                       = ~i_ubwc_en && !fake_cvo_cmd_valid_r;
    assign o_error                      = 1'b0;

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            o_co_valid <= 1'b0;
        else
            o_co_valid <= ci_fire;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            o_co_alen <= 3'd0;
        else if (i_sreset)
            o_co_alen <= 3'd0;
        else if (ci_fire)
            o_co_alen <= fake_model_active ? ci_alen_from_metadata :
                                             i_ci_alen;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            o_co_pcm <= 1'b0;
        else if (i_sreset)
            o_co_pcm <= 1'b0;
        else if (ci_fire)
            o_co_pcm <= fake_model_active ? ci_metadata_eff[5] :
                                            i_ci_forced_pcm;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            o_co_sb <= {SB_DW{1'b0}};
        else if (i_sreset)
            o_co_sb <= {SB_DW{1'b0}};
        else if (ci_fire)
            o_co_sb <= i_ci_sb;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_ci_cmd_valid_r <= 1'b0;
        else if (i_sreset || !i_ubwc_en || !fake_model_active)
            fake_ci_cmd_valid_r <= 1'b0;
        else if (fake_rvi_start_fire)
            fake_ci_cmd_valid_r <= 1'b0;
        else if (ci_fire)
            fake_ci_cmd_valid_r <= 1'b1;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_ci_cmd_addr_r <= 64'd0;
        else if (i_sreset || !i_ubwc_en)
            fake_ci_cmd_addr_r <= 64'd0;
        else if (ci_fire)
            fake_ci_cmd_addr_r <= ci_cmp_addr_from_metadata;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_ci_valid_beats_r <= 4'd0;
        else if (i_sreset || !i_ubwc_en)
            fake_ci_valid_beats_r <= 4'd0;
        else if (ci_fire)
            fake_ci_valid_beats_r <= ci_valid_beats_from_metadata;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_ci_total_beats_r <= 4'd1;
        else if (i_sreset || !i_ubwc_en)
            fake_ci_total_beats_r <= 4'd1;
        else if (ci_fire)
            fake_ci_total_beats_r <= ci_total_beats_from_metadata;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_cvo_cmd_valid_r <= 1'b0;
        else if (i_sreset || !i_ubwc_en || !fake_model_active)
            fake_cvo_cmd_valid_r <= 1'b0;
        else if (fake_rvi_start_fire)
            fake_cvo_cmd_valid_r <= 1'b1;
        else if (fake_cvo_fire && fake_cvo_last_w)
            fake_cvo_cmd_valid_r <= 1'b0;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_cvo_cmd_addr_r <= 64'd0;
        else if (i_sreset || !i_ubwc_en)
            fake_cvo_cmd_addr_r <= 64'd0;
        else if (fake_rvi_start_fire)
            fake_cvo_cmd_addr_r <= fake_ci_cmd_addr_r;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_cvo_valid_beats_r <= 4'd0;
        else if (i_sreset || !i_ubwc_en)
            fake_cvo_valid_beats_r <= 4'd0;
        else if (fake_rvi_start_fire)
            fake_cvo_valid_beats_r <= fake_ci_valid_beats_r;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_cvo_total_beats_r <= 4'd1;
        else if (i_sreset || !i_ubwc_en)
            fake_cvo_total_beats_r <= 4'd1;
        else if (fake_rvi_start_fire)
            fake_cvo_total_beats_r <= fake_ci_total_beats_r;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_cvo_beat_idx_r <= 4'd0;
        else if (i_sreset || !i_ubwc_en || !fake_model_active)
            fake_cvo_beat_idx_r <= 4'd0;
        else if (fake_rvi_start_fire)
            fake_cvo_beat_idx_r <= 4'd0;
        else if (fake_cvo_fire && !fake_cvo_last_w)
            fake_cvo_beat_idx_r <= fake_cvo_beat_idx_r + 4'd1;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            fake_rvi_beat_idx_r <= 4'd0;
        else if (i_sreset || !i_ubwc_en)
            fake_rvi_beat_idx_r <= 4'd0;
        else if (fake_rvi_fire && i_rvi_last)
            fake_rvi_beat_idx_r <= 4'd0;
        else if (fake_rvi_fire)
            fake_rvi_beat_idx_r <= fake_rvi_beat_idx_r + 4'd1;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            ci_ready_cnt_r <= {CI_CNT_W{1'b0}};
        else if (i_sreset)
            ci_ready_cnt_r <= {CI_CNT_W{1'b0}};
        else if (!i_ubwc_en)
            ci_ready_cnt_r <= {CI_CNT_W{1'b0}};
        else if (ci_period_hit)
            ci_ready_cnt_r <= {CI_CNT_W{1'b0}};
        else
            ci_ready_cnt_r <= ci_ready_cnt_r + {{(CI_CNT_W-1){1'b0}}, 1'b1};
    end

endmodule
