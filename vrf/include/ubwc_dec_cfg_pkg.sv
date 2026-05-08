package ubwc_dec_cfg_pkg;

    localparam int unsigned UBWC_DEC_FMT_RGBA8888       = 0;
    localparam int unsigned UBWC_DEC_FMT_RGBA1010102    = 1;
    localparam int unsigned UBWC_DEC_FMT_YUV420_8_NV12  = 2;
    localparam int unsigned UBWC_DEC_FMT_YUV420_10_P010 = 3;
    localparam int unsigned UBWC_DEC_FMT_RGBA8888_L_2_1 = 4;

    localparam logic [15:0] UBWC_DEC_REG_TILE_CFG0  = 16'h0008;
    localparam logic [15:0] UBWC_DEC_REG_TILE_CFG1  = 16'h000c;
    localparam logic [15:0] UBWC_DEC_REG_TILE_CFG2  = 16'h0010;
    localparam logic [15:0] UBWC_DEC_REG_VIVO_CFG   = 16'h0014;
    localparam logic [15:0] UBWC_DEC_REG_OTF_CFG0   = 16'h0018;
    localparam logic [15:0] UBWC_DEC_REG_OTF_CFG1   = 16'h001c;
    localparam logic [15:0] UBWC_DEC_REG_OTF_CFG2   = 16'h0020;
    localparam logic [15:0] UBWC_DEC_REG_OTF_CFG3   = 16'h0024;
    localparam logic [15:0] UBWC_DEC_REG_OTF_CFG4   = 16'h0028;
    localparam logic [15:0] UBWC_DEC_REG_META_CFG0  = 16'h002c;
    localparam logic [15:0] UBWC_DEC_REG_META_BASE_Y_LO  = 16'h0030;
    localparam logic [15:0] UBWC_DEC_REG_META_BASE_Y_HI  = 16'h0034;
    localparam logic [15:0] UBWC_DEC_REG_TILE_BASE_Y_LO  = 16'h0038;
    localparam logic [15:0] UBWC_DEC_REG_TILE_BASE_Y_HI  = 16'h003c;
    localparam logic [15:0] UBWC_DEC_REG_META_BASE_UV_LO = 16'h0040;
    localparam logic [15:0] UBWC_DEC_REG_META_BASE_UV_HI = 16'h0044;
    localparam logic [15:0] UBWC_DEC_REG_TILE_BASE_UV_LO = 16'h0048;
    localparam logic [15:0] UBWC_DEC_REG_TILE_BASE_UV_HI = 16'h004c;

    typedef struct packed {
        logic [63:0] tile_base_rgba_y;
        logic [63:0] tile_base_uv;
        logic [63:0] meta_base_rgba_y;
        logic [63:0] meta_base_uv;
    } ubwc_dec_base_cfg_t;

    function automatic int unsigned ubwc_dec_align_up(input int unsigned value,
                                                      input int unsigned unit);
        ubwc_dec_align_up = ((value + unit - 1) / unit) * unit;
    endfunction

    function automatic int unsigned ubwc_dec_ceil_div(input int unsigned value,
                                                      input int unsigned unit);
        ubwc_dec_ceil_div = (value + unit - 1) / unit;
    endfunction

    function automatic int unsigned ubwc_dec_base_format(input int unsigned format);
        ubwc_dec_base_format =
            (format == UBWC_DEC_FMT_RGBA8888_L_2_1) ? UBWC_DEC_FMT_RGBA8888 : (format & 32'h1f);
    endfunction

    function automatic bit ubwc_dec_is_rgba_format(input int unsigned format);
        ubwc_dec_is_rgba_format = (format == UBWC_DEC_FMT_RGBA8888) ||
                                  (format == UBWC_DEC_FMT_RGBA1010102) ||
                                  (format == UBWC_DEC_FMT_RGBA8888_L_2_1);
    endfunction

    function automatic int unsigned ubwc_dec_tile_w(input int unsigned format);
        ubwc_dec_tile_w = ubwc_dec_is_rgba_format(format) ? 16 : 32;
    endfunction

    function automatic int unsigned ubwc_dec_tile_h(input int unsigned format);
        if ((format == UBWC_DEC_FMT_RGBA8888) ||
            (format == UBWC_DEC_FMT_RGBA1010102) ||
            (format == UBWC_DEC_FMT_RGBA8888_L_2_1) ||
            (format == UBWC_DEC_FMT_YUV420_10_P010)) begin
            ubwc_dec_tile_h = 4;
        end else begin
            ubwc_dec_tile_h = 8;
        end
    endfunction

    function automatic int unsigned ubwc_dec_bytes_per_pixel(input int unsigned format);
        if (ubwc_dec_is_rgba_format(format)) begin
            ubwc_dec_bytes_per_pixel = 4;
        end else if (format == UBWC_DEC_FMT_YUV420_10_P010) begin
            ubwc_dec_bytes_per_pixel = 2;
        end else begin
            ubwc_dec_bytes_per_pixel = 1;
        end
    endfunction

    function automatic int unsigned ubwc_dec_aligned_width_px(input int unsigned format,
                                                             input int unsigned width_px);
        ubwc_dec_aligned_width_px = ubwc_dec_align_up(width_px, ubwc_dec_tile_w(format) * 4);
    endfunction

    function automatic int unsigned ubwc_dec_stored_height_px(input int unsigned format,
                                                             input int unsigned height_px);
        ubwc_dec_stored_height_px = ubwc_dec_align_up(height_px, ubwc_dec_tile_h(format) * 4);
    endfunction

    function automatic int unsigned ubwc_dec_tile_x_numbers(input int unsigned format,
                                                           input int unsigned width_px);
        ubwc_dec_tile_x_numbers =
            ubwc_dec_ceil_div(ubwc_dec_aligned_width_px(format, width_px),
                              ubwc_dec_tile_w(format));
    endfunction

    function automatic int unsigned ubwc_dec_tile_y_numbers(input int unsigned format,
                                                           input int unsigned height_px);
        ubwc_dec_tile_y_numbers =
            ubwc_dec_ceil_div(ubwc_dec_stored_height_px(format, height_px),
                              ubwc_dec_tile_h(format));
    endfunction

    function automatic int unsigned ubwc_dec_uv_height_px(input int unsigned height_px);
        ubwc_dec_uv_height_px = ubwc_dec_ceil_div(height_px, 2);
    endfunction

    function automatic int unsigned ubwc_dec_surface_pitch_bytes(input int unsigned format,
                                                                input int unsigned width_px);
        ubwc_dec_surface_pitch_bytes =
            ubwc_dec_align_up(width_px * ubwc_dec_bytes_per_pixel(format),
                              ubwc_dec_tile_w(format) * 4 * ubwc_dec_bytes_per_pixel(format));
    endfunction

    function automatic int unsigned ubwc_dec_tile_pitch(input int unsigned format,
                                                       input int unsigned width_px);
        ubwc_dec_tile_pitch = ubwc_dec_surface_pitch_bytes(format, width_px) / 16;
    endfunction

    function automatic int unsigned ubwc_dec_meta_data_plane_pitch(input int unsigned format,
                                                                  input int unsigned width_px);
        ubwc_dec_meta_data_plane_pitch =
            ubwc_dec_align_up(ubwc_dec_tile_x_numbers(format, width_px), 64);
    endfunction

    function automatic int unsigned ubwc_dec_meta_plane_size(input int unsigned format,
                                                            input int unsigned width_px,
                                                            input int unsigned height_px);
        int unsigned meta_pitch;
        int unsigned meta_lines;
        meta_pitch = ubwc_dec_meta_data_plane_pitch(format, width_px);
        meta_lines = ubwc_dec_align_up(ubwc_dec_tile_y_numbers(format, height_px), 16);
        ubwc_dec_meta_plane_size = ubwc_dec_align_up(meta_pitch * meta_lines, 4096);
    endfunction

    function automatic int unsigned ubwc_dec_tile_plane_size(input int unsigned format,
                                                            input int unsigned width_px,
                                                            input int unsigned height_px);
        ubwc_dec_tile_plane_size =
            ubwc_dec_align_up(ubwc_dec_surface_pitch_bytes(format, width_px) *
                              ubwc_dec_stored_height_px(format, height_px), 4096);
    endfunction

    function automatic ubwc_dec_base_cfg_t ubwc_dec_layout_bases(input int unsigned format,
                                                                 input int unsigned width_px,
                                                                 input int unsigned height_px,
                                                                 input logic [63:0] meta_y_base_addr);
        int unsigned meta_y_size;
        int unsigned tile_y_size;
        int unsigned meta_uv_size;
        int unsigned uv_height;
        ubwc_dec_base_cfg_t b;

        uv_height = ubwc_dec_uv_height_px(height_px);
        meta_y_size = ubwc_dec_meta_plane_size(format, width_px, height_px);
        tile_y_size = ubwc_dec_tile_plane_size(format, width_px, height_px);
        meta_uv_size = ubwc_dec_is_rgba_format(format) ? 0 :
                       ubwc_dec_meta_plane_size(format, width_px, uv_height);

        b.meta_base_rgba_y = meta_y_base_addr;
        if (ubwc_dec_is_rgba_format(format)) begin
            b.tile_base_rgba_y = meta_y_base_addr + {32'd0, meta_y_size};
            b.meta_base_uv = 64'd0;
            b.tile_base_uv = 64'd0;
        end else begin
            b.tile_base_rgba_y = meta_y_base_addr + {32'd0, meta_y_size};
            b.meta_base_uv = b.tile_base_rgba_y + {32'd0, tile_y_size};
            b.tile_base_uv = b.meta_base_uv + {32'd0, meta_uv_size};
        end
        ubwc_dec_layout_bases = b;
    endfunction

    function automatic logic [31:0] ubwc_dec_reg_tile_cfg0(input bit lvl1_bank_swizzle_en,
                                                          input bit lvl2_bank_swizzle_en,
                                                          input bit lvl3_bank_swizzle_en,
                                                          input int unsigned highest_bank_bit,
                                                          input bit bank_spread_en,
                                                          input bit four_line_format,
                                                          input bit lossy_rgba_2_1);
        ubwc_dec_reg_tile_cfg0 = 32'd0;
        ubwc_dec_reg_tile_cfg0[0] = lvl1_bank_swizzle_en;
        ubwc_dec_reg_tile_cfg0[1] = lvl2_bank_swizzle_en;
        ubwc_dec_reg_tile_cfg0[2] = lvl3_bank_swizzle_en;
        ubwc_dec_reg_tile_cfg0[8:4] = highest_bank_bit[4:0];
        ubwc_dec_reg_tile_cfg0[9] = bank_spread_en;
        ubwc_dec_reg_tile_cfg0[10] = four_line_format;
        ubwc_dec_reg_tile_cfg0[11] = lossy_rgba_2_1;
    endfunction

    function automatic logic [31:0] ubwc_dec_reg_tile_cfg1(input int unsigned format,
                                                          input int unsigned width_px);
        int unsigned pitch;
        pitch = ubwc_dec_tile_pitch(format, width_px);
        ubwc_dec_reg_tile_cfg1 = {20'd0, pitch[11:0]};
    endfunction

    function automatic logic [31:0] ubwc_dec_reg_tile_cfg2(input bit ci_input_type,
                                                          input bit ci_lossy,
                                                          input logic [1:0] ci_alpha_mode);
        ubwc_dec_reg_tile_cfg2 = 32'd0;
        ubwc_dec_reg_tile_cfg2[0] = ci_input_type;
        ubwc_dec_reg_tile_cfg2[8] = ci_lossy;
        ubwc_dec_reg_tile_cfg2[10:9] = ci_alpha_mode;
    endfunction

    function automatic logic [31:0] ubwc_dec_reg_vivo_cfg(input bit ubwc_en,
                                                         input bit sreset);
        ubwc_dec_reg_vivo_cfg = {30'd0, sreset, ubwc_en};
    endfunction

    function automatic logic [31:0] ubwc_dec_reg_meta_cfg0(input int unsigned format,
                                                           input int unsigned width_px,
                                                           input int unsigned height_px);
        int unsigned tile_x;
        int unsigned tile_y;
        tile_x = ubwc_dec_tile_x_numbers(format, width_px);
        tile_y = ubwc_dec_tile_y_numbers(format, height_px);
        ubwc_dec_reg_meta_cfg0 = {tile_y[15:0], tile_x[15:0]};
    endfunction

    function automatic logic [31:0] ubwc_dec_reg_otf_cfg0(input int unsigned format,
                                                         input int unsigned width_px);
        int unsigned base_format;
        base_format = ubwc_dec_base_format(format);
        ubwc_dec_reg_otf_cfg0 = {11'd0, base_format[4:0], width_px[15:0]};
    endfunction

    function automatic logic [31:0] ubwc_dec_reg_otf_cfg1(input int unsigned h_total,
                                                         input int unsigned h_sync);
        ubwc_dec_reg_otf_cfg1 = {h_sync[15:0], h_total[15:0]};
    endfunction

    function automatic logic [31:0] ubwc_dec_reg_otf_cfg2(input int unsigned h_bp,
                                                         input int unsigned h_act);
        ubwc_dec_reg_otf_cfg2 = {h_act[15:0], h_bp[15:0]};
    endfunction

    function automatic logic [31:0] ubwc_dec_reg_otf_cfg3(input int unsigned v_total,
                                                         input int unsigned v_sync);
        ubwc_dec_reg_otf_cfg3 = {v_sync[15:0], v_total[15:0]};
    endfunction

    function automatic logic [31:0] ubwc_dec_reg_otf_cfg4(input int unsigned v_bp,
                                                         input int unsigned v_act);
        ubwc_dec_reg_otf_cfg4 = {v_act[15:0], v_bp[15:0]};
    endfunction

    function automatic logic [31:0] ubwc_dec_reg_base_lo(input logic [63:0] base_addr);
        ubwc_dec_reg_base_lo = base_addr[31:0];
    endfunction

    function automatic logic [31:0] ubwc_dec_reg_base_hi(input logic [63:0] base_addr);
        ubwc_dec_reg_base_hi = base_addr[63:32];
    endfunction

endpackage
