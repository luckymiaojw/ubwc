package ubwc_enc_cfg_pkg;

    localparam int unsigned UBWC_ENC_FMT_RGBA8888       = 0;
    localparam int unsigned UBWC_ENC_FMT_RGBA1010102    = 1;
    localparam int unsigned UBWC_ENC_FMT_YUV420_8_NV12  = 2;
    localparam int unsigned UBWC_ENC_FMT_YUV420_10_P010 = 3;
    localparam int unsigned UBWC_ENC_FMT_RGBA8888_L_2_1 = 4;

    localparam logic [15:0] UBWC_ENC_REG_TILE_CFG0        = 16'h0008;
    localparam logic [15:0] UBWC_ENC_REG_TILE_CFG1        = 16'h000c;
    localparam logic [15:0] UBWC_ENC_REG_ENC_CI_CFG0      = 16'h0010;
    localparam logic [15:0] UBWC_ENC_REG_ENC_CI_CFG1      = 16'h0014;
    localparam logic [15:0] UBWC_ENC_REG_ENC_CI_CFG2      = 16'h0018;
    localparam logic [15:0] UBWC_ENC_REG_ENC_CI_CFG3      = 16'h001c;
    localparam logic [15:0] UBWC_ENC_REG_OTF_CFG0         = 16'h0020;
    localparam logic [15:0] UBWC_ENC_REG_OTF_CFG1         = 16'h0024;
    localparam logic [15:0] UBWC_ENC_REG_OTF_CFG2         = 16'h0028;
    localparam logic [15:0] UBWC_ENC_REG_OTF_CFG3         = 16'h002c;
    localparam logic [15:0] UBWC_ENC_REG_META_BASE_Y_LO   = 16'h0030;
    localparam logic [15:0] UBWC_ENC_REG_META_BASE_Y_HI   = 16'h0034;
    localparam logic [15:0] UBWC_ENC_REG_TILE_BASE_Y_LO   = 16'h0038;
    localparam logic [15:0] UBWC_ENC_REG_TILE_BASE_Y_HI   = 16'h003c;
    localparam logic [15:0] UBWC_ENC_REG_META_BASE_UV_LO  = 16'h0040;
    localparam logic [15:0] UBWC_ENC_REG_META_BASE_UV_HI  = 16'h0044;
    localparam logic [15:0] UBWC_ENC_REG_TILE_BASE_UV_LO  = 16'h0048;
    localparam logic [15:0] UBWC_ENC_REG_TILE_BASE_UV_HI  = 16'h004c;
    localparam logic [15:0] UBWC_ENC_REG_META_ACTIVE_SIZE = 16'h0050;
    localparam logic [15:0] UBWC_ENC_REG_META_PITCH       = 16'h0054;
    localparam logic [15:0] UBWC_ENC_REG_STATUS0          = 16'h0058;
    localparam logic [15:0] UBWC_ENC_REG_IRQ_CTRL         = 16'h0060;
    localparam int unsigned UBWC_ENC_STATUS0_CFG_VALID_BIT = 14;
    localparam int unsigned UBWC_ENC_IRQ_CTRL_CFG_COMMIT_BIT = 5;

    typedef struct packed {
        logic [15:0] addr;
        logic [31:0] data;
    } ubwc_enc_reg_write_t;

    typedef struct packed {
        logic [63:0] tile_base_y;
        logic [63:0] tile_base_uv;
        logic [63:0] meta_base_y;
        logic [63:0] meta_base_uv;
    } ubwc_enc_base_cfg_t;

    function automatic int unsigned ubwc_enc_align_up(input int unsigned value,
                                                      input int unsigned unit);
        ubwc_enc_align_up = ((value + unit - 1) / unit) * unit;
    endfunction

    function automatic int unsigned ubwc_enc_ceil_div(input int unsigned value,
                                                      input int unsigned unit);
        ubwc_enc_ceil_div = (value + unit - 1) / unit;
    endfunction

    function automatic bit ubwc_enc_is_rgba_format(input int unsigned format);
        ubwc_enc_is_rgba_format = (format == UBWC_ENC_FMT_RGBA8888) ||
                                  (format == UBWC_ENC_FMT_RGBA1010102) ||
                                  (format == UBWC_ENC_FMT_RGBA8888_L_2_1);
    endfunction

    function automatic int unsigned ubwc_enc_tile_w(input int unsigned format);
        ubwc_enc_tile_w = ubwc_enc_is_rgba_format(format) ? 16 : 32;
    endfunction

    function automatic int unsigned ubwc_enc_tile_h(input int unsigned format);
        if ((format == UBWC_ENC_FMT_RGBA8888) ||
            (format == UBWC_ENC_FMT_RGBA1010102) ||
            (format == UBWC_ENC_FMT_RGBA8888_L_2_1) ||
            (format == UBWC_ENC_FMT_YUV420_10_P010)) begin
            ubwc_enc_tile_h = 4;
        end else begin
            ubwc_enc_tile_h = 8;
        end
    endfunction

    function automatic int unsigned ubwc_enc_bytes_per_pixel(input int unsigned format);
        if ((format == UBWC_ENC_FMT_RGBA8888) ||
            (format == UBWC_ENC_FMT_RGBA1010102) ||
            (format == UBWC_ENC_FMT_RGBA8888_L_2_1)) begin
            ubwc_enc_bytes_per_pixel = 4;
        end else if (format == UBWC_ENC_FMT_YUV420_10_P010) begin
            ubwc_enc_bytes_per_pixel = 2;
        end else begin
            ubwc_enc_bytes_per_pixel = 1;
        end
    endfunction

    function automatic int unsigned ubwc_enc_aligned_width_px(input int unsigned format,
                                                             input int unsigned width_px);
        ubwc_enc_aligned_width_px =
            ubwc_enc_align_up(width_px, ubwc_enc_tile_w(format) * 4);
    endfunction

    function automatic int unsigned ubwc_enc_tile_cols(input int unsigned format,
                                                      input int unsigned width_px);
        ubwc_enc_tile_cols =
            ubwc_enc_ceil_div(ubwc_enc_aligned_width_px(format, width_px),
                              ubwc_enc_tile_w(format));
    endfunction

    function automatic int unsigned ubwc_enc_uv_height_px(input int unsigned height_px);
        ubwc_enc_uv_height_px = ubwc_enc_ceil_div(height_px, 2);
    endfunction

    function automatic int unsigned ubwc_enc_stored_uv_height_px(input int unsigned format,
                                                                input int unsigned height_px);
        if (ubwc_enc_is_rgba_format(format)) begin
            ubwc_enc_stored_uv_height_px = 0;
        end else begin
            ubwc_enc_stored_uv_height_px =
                ubwc_enc_align_up(ubwc_enc_uv_height_px(height_px), ubwc_enc_tile_h(format) * 4);
        end
    endfunction

    function automatic int unsigned ubwc_enc_stored_height_px(input int unsigned format,
                                                             input int unsigned height_px);
        if (ubwc_enc_is_rgba_format(format)) begin
            ubwc_enc_stored_height_px = ubwc_enc_align_up(height_px, ubwc_enc_tile_h(format) * 4);
        end else begin
            ubwc_enc_stored_height_px = ubwc_enc_stored_uv_height_px(format, height_px) * 2;
        end
    endfunction

    function automatic int unsigned ubwc_enc_tile_rows(input int unsigned format,
                                                      input int unsigned height_px);
        ubwc_enc_tile_rows = ubwc_enc_stored_height_px(format, height_px) / ubwc_enc_tile_h(format);
    endfunction

    function automatic int unsigned ubwc_enc_uv_tile_rows(input int unsigned format,
                                                         input int unsigned height_px);
        if (ubwc_enc_is_rgba_format(format)) begin
            ubwc_enc_uv_tile_rows = 0;
        end else begin
            ubwc_enc_uv_tile_rows =
                ubwc_enc_stored_uv_height_px(format, height_px) / ubwc_enc_tile_h(format);
        end
    endfunction

    function automatic int unsigned ubwc_enc_y_tile_cols(input int unsigned format,
                                                        input int unsigned width_px);
        ubwc_enc_y_tile_cols = ubwc_enc_tile_cols(format, width_px);
    endfunction

    function automatic int unsigned ubwc_enc_uv_tile_cols(input int unsigned format,
                                                        input int unsigned width_px);
        ubwc_enc_uv_tile_cols = ubwc_enc_is_rgba_format(format) ? 0 :
                               ubwc_enc_tile_cols(format, width_px);
    endfunction

    function automatic int unsigned ubwc_enc_meta_last_xcoord(input int unsigned format,
                                                             input int unsigned width_px);
        int unsigned y_cols;
        int unsigned uv_cols;
        int unsigned total_cols;
        y_cols = ubwc_enc_y_tile_cols(format, width_px);
        uv_cols = ubwc_enc_uv_tile_cols(format, width_px);
        total_cols = (y_cols >= uv_cols) ? y_cols : uv_cols;
        ubwc_enc_meta_last_xcoord = (total_cols == 0) ? 0 : (total_cols - 1);
    endfunction

    function automatic int unsigned ubwc_enc_surface_pitch_bytes(input int unsigned format,
                                                                input int unsigned width_px);
        ubwc_enc_surface_pitch_bytes =
            ubwc_enc_align_up(width_px * ubwc_enc_bytes_per_pixel(format),
                              ubwc_enc_tile_w(format) * 4 *
                              ubwc_enc_bytes_per_pixel(format));
    endfunction

    function automatic int unsigned ubwc_enc_tile_pitch(input int unsigned format,
                                                       input int unsigned width_px);
        ubwc_enc_tile_pitch = ubwc_enc_surface_pitch_bytes(format, width_px) / 16;
    endfunction

    function automatic int unsigned ubwc_enc_meta_data_plane_pitch(input int unsigned format,
                                                                  input int unsigned width_px);
        ubwc_enc_meta_data_plane_pitch =
            ubwc_enc_align_up(ubwc_enc_tile_cols(format, width_px), 64);
    endfunction

    function automatic int unsigned ubwc_enc_meta_plane_size(input int unsigned format,
                                                            input int unsigned width_px,
                                                            input int unsigned height_px);
        int unsigned meta_pitch;
        int unsigned meta_lines;
        meta_pitch = ubwc_enc_meta_data_plane_pitch(format, width_px);
        meta_lines = ubwc_enc_align_up(ubwc_enc_tile_rows(format, height_px), 16);
        ubwc_enc_meta_plane_size = ubwc_enc_align_up(meta_pitch * meta_lines, 4096);
    endfunction

    function automatic int unsigned ubwc_enc_tile_plane_size(input int unsigned format,
                                                            input int unsigned width_px,
                                                            input int unsigned height_px);
        ubwc_enc_tile_plane_size =
            ubwc_enc_align_up(ubwc_enc_surface_pitch_bytes(format, width_px) *
                              ubwc_enc_stored_height_px(format, height_px), 4096);
    endfunction

    function automatic int unsigned ubwc_enc_meta_uv_plane_size(input int unsigned format,
                                                               input int unsigned width_px,
                                                               input int unsigned height_px);
        int unsigned meta_pitch;
        int unsigned meta_lines;
        meta_pitch = ubwc_enc_meta_data_plane_pitch(format, width_px);
        meta_lines = ubwc_enc_align_up(ubwc_enc_uv_tile_rows(format, height_px), 16);
        ubwc_enc_meta_uv_plane_size = ubwc_enc_align_up(meta_pitch * meta_lines, 4096);
    endfunction

    function automatic int unsigned ubwc_enc_tile_uv_plane_size(input int unsigned format,
                                                               input int unsigned width_px,
                                                               input int unsigned height_px);
        ubwc_enc_tile_uv_plane_size =
            ubwc_enc_align_up(ubwc_enc_surface_pitch_bytes(format, width_px) *
                              ubwc_enc_stored_uv_height_px(format, height_px), 4096);
    endfunction

    function automatic ubwc_enc_base_cfg_t ubwc_enc_layout_bases(input int unsigned format,
                                                                 input int unsigned width_px,
                                                                 input int unsigned height_px,
                                                                 input logic [63:0] meta_y_base_addr);
        int unsigned meta_y_size;
        int unsigned tile_y_size;
        int unsigned meta_uv_size;
        ubwc_enc_base_cfg_t b;

        meta_y_size = ubwc_enc_meta_plane_size(format, width_px, height_px);
        tile_y_size = ubwc_enc_tile_plane_size(format, width_px, height_px);
        meta_uv_size = ubwc_enc_is_rgba_format(format) ? 0 :
                       ubwc_enc_meta_uv_plane_size(format, width_px, height_px);

        b.meta_base_y = meta_y_base_addr;
        b.tile_base_y = meta_y_base_addr + {32'd0, meta_y_size};
        if (ubwc_enc_is_rgba_format(format)) begin
            b.meta_base_uv = 64'd0;
            b.tile_base_uv = 64'd0;
        end else begin
            b.meta_base_uv = b.tile_base_y + {32'd0, tile_y_size};
            b.tile_base_uv = b.meta_base_uv + {32'd0, meta_uv_size};
        end
        ubwc_enc_layout_bases = b;
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_tile_cfg0(input bit enc_ubwc_en,
                                                          input bit lvl1_bank_swizzle_en,
                                                          input bit lvl2_bank_swizzle_en,
                                                          input bit lvl3_bank_swizzle_en,
                                                          input int unsigned highest_bank_bit,
                                                          input bit bank_spread_en);
        ubwc_enc_reg_tile_cfg0 = {32{1'b0}};
        ubwc_enc_reg_tile_cfg0[0] = enc_ubwc_en;
        ubwc_enc_reg_tile_cfg0[1] = lvl1_bank_swizzle_en;
        ubwc_enc_reg_tile_cfg0[2] = lvl2_bank_swizzle_en;
        ubwc_enc_reg_tile_cfg0[3] = lvl3_bank_swizzle_en;
        ubwc_enc_reg_tile_cfg0[12:8] = highest_bank_bit[4:0];
        ubwc_enc_reg_tile_cfg0[16] = bank_spread_en;
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_tile_cfg1(input int unsigned format,
                                                          input int unsigned width_px);
        int unsigned tile_pitch;
        tile_pitch = ubwc_enc_tile_pitch(format, width_px);
        ubwc_enc_reg_tile_cfg1 = {32{1'b0}};
        ubwc_enc_reg_tile_cfg1[0] = ubwc_enc_is_rgba_format(format);
        ubwc_enc_reg_tile_cfg1[1] = (format == UBWC_ENC_FMT_RGBA8888_L_2_1);
        ubwc_enc_reg_tile_cfg1[26:16] = tile_pitch[10:0];
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_enc_ci_cfg0(input bit input_type,
                                                            input logic [2:0] alen);
        ubwc_enc_reg_enc_ci_cfg0 = {32{1'b0}};
        ubwc_enc_reg_enc_ci_cfg0[0] = input_type;
        ubwc_enc_reg_enc_ci_cfg0[10:8] = alen;
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_enc_ci_cfg1(input int unsigned sb,
                                                            input bit lossy);
        ubwc_enc_reg_enc_ci_cfg1 = {32{1'b0}};
        ubwc_enc_reg_enc_ci_cfg1[15:0] = sb[15:0];
        ubwc_enc_reg_enc_ci_cfg1[16] = lossy;
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_enc_ci_cfg2();
        ubwc_enc_reg_enc_ci_cfg2 = 32'd0;
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_enc_ci_cfg3_fields(input logic [5:0] ubwc_cfg_10,
                                                                    input logic [5:0] ubwc_cfg_11,
                                                                    input logic [3:0] ubwc_ver);
        ubwc_enc_reg_enc_ci_cfg3_fields = 32'd0;
        ubwc_enc_reg_enc_ci_cfg3_fields[5:0] = ubwc_cfg_10;
        ubwc_enc_reg_enc_ci_cfg3_fields[13:8] = ubwc_cfg_11;
        ubwc_enc_reg_enc_ci_cfg3_fields[19:16] = ubwc_ver;
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_enc_ci_cfg3();
        ubwc_enc_reg_enc_ci_cfg3 = ubwc_enc_reg_enc_ci_cfg3_fields(6'd0, 6'd0, 4'd7);
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_otf_cfg0(input int unsigned format);
        ubwc_enc_reg_otf_cfg0 = {29'd0, format[2:0]};
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_otf_cfg1(input int unsigned width_px,
                                                         input int unsigned height_px);
        ubwc_enc_reg_otf_cfg1 = {height_px[15:0], width_px[15:0]};
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_otf_cfg2(input int unsigned format);
        int unsigned tile_w;
        int unsigned tile_h;
        tile_w = ubwc_enc_tile_w(format);
        tile_h = ubwc_enc_tile_h(format);
        ubwc_enc_reg_otf_cfg2 = {12'd0,
                                 tile_h[3:0],
                                 tile_w[15:0]};
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_otf_cfg3(input int unsigned format,
                                                         input int unsigned width_px);
        int unsigned y_tile_cols;
        int unsigned uv_tile_cols;
        y_tile_cols = ubwc_enc_y_tile_cols(format, width_px);
        uv_tile_cols = ubwc_enc_uv_tile_cols(format, width_px);
        ubwc_enc_reg_otf_cfg3 = {uv_tile_cols[15:0], y_tile_cols[15:0]};
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_meta_active_size(input int unsigned width_px,
                                                                 input int unsigned height_px);
        ubwc_enc_reg_meta_active_size = {height_px[15:0], width_px[15:0]};
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_meta_pitch(input int unsigned format,
                                                           input int unsigned width_px);
        ubwc_enc_reg_meta_pitch = ubwc_enc_meta_data_plane_pitch(format, width_px);
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_base_lo(input logic [63:0] base_addr);
        ubwc_enc_reg_base_lo = base_addr[31:0];
    endfunction

    function automatic logic [31:0] ubwc_enc_reg_base_hi(input logic [63:0] base_addr);
        ubwc_enc_reg_base_hi = base_addr[63:32];
    endfunction

endpackage
