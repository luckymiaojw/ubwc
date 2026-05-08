`timescale 1ns/1ps

module ubwc_tile_addr #(
    parameter ADDR_W = 64
)(
    input  wire                 i_cfg_lvl2_bank_swizzle_en,
    input  wire                 i_cfg_lvl3_bank_swizzle_en,
    input  wire [4:0]           i_cfg_highest_bank_bit,
    input  wire                 i_cfg_bank_spread_en,
    input  wire                 i_cfg_is_lossy_rgba_2_1_format,
    input  wire [11:0]          i_cfg_pitch,
    input  wire [ADDR_W-1:0]    i_cfg_base_addr_rgba_y0,
    input  wire [ADDR_W-1:0]    i_cfg_base_addr_uv0,
    input  wire [ADDR_W-1:0]    i_cfg_base_addr_rgba_y1,
    input  wire [ADDR_W-1:0]    i_cfg_base_addr_uv1,
    input  wire                 i_meta_valid,
    output wire                 o_meta_ready,
    input  wire [4:0]           i_meta_format,
    input  wire [3:0]           i_meta_flag,
    input  wire [2:0]           i_meta_alen,
    input  wire                 i_meta_has_payload,
    input  wire [11:0]          i_meta_x,
    input  wire [9:0]           i_meta_y,
    input  wire [3:0]           i_meta_fcnt,
    output wire                 o_cmd_valid,
    input  wire                 i_cmd_ready,
    output wire [ADDR_W-5:0]    o_cmd_addr,
    output wire [4:0]           o_cmd_format,
    output wire [3:0]           o_cmd_meta,
    output wire [2:0]           o_cmd_alen,
    output wire                 o_cmd_has_payload,
    output wire [3:0]           o_cmd_fcnt
);

    localparam [4:0] META_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] META_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] META_FMT_NV12_Y      = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV     = 5'b01001;
    localparam [4:0] META_FMT_P010_Y      = 5'b01110;
    localparam [4:0] META_FMT_P010_UV     = 5'b01111;

    function [4:0] macro_tile_slot;
        input [2:0] tile_x;
        input [2:0] tile_y;
        begin
            case (tile_x)
                3'd0: begin
                    case (tile_y)
                        3'd0: macro_tile_slot = 5'd0;
                        3'd1: macro_tile_slot = 5'd6;
                        3'd2: macro_tile_slot = 5'd3;
                        3'd3: macro_tile_slot = 5'd5;
                        3'd4: macro_tile_slot = 5'd4;
                        3'd5: macro_tile_slot = 5'd2;
                        3'd6: macro_tile_slot = 5'd7;
                        default: macro_tile_slot = 5'd1;
                    endcase
                end
                3'd1: begin
                    case (tile_y)
                        3'd0: macro_tile_slot = 5'd7;
                        3'd1: macro_tile_slot = 5'd1;
                        3'd2: macro_tile_slot = 5'd4;
                        3'd3: macro_tile_slot = 5'd2;
                        3'd4: macro_tile_slot = 5'd3;
                        3'd5: macro_tile_slot = 5'd5;
                        3'd6: macro_tile_slot = 5'd0;
                        default: macro_tile_slot = 5'd6;
                    endcase
                end
                3'd2: begin
                    case (tile_y)
                        3'd0: macro_tile_slot = 5'd10;
                        3'd1: macro_tile_slot = 5'd12;
                        3'd2: macro_tile_slot = 5'd9;
                        3'd3: macro_tile_slot = 5'd15;
                        3'd4: macro_tile_slot = 5'd14;
                        3'd5: macro_tile_slot = 5'd8;
                        3'd6: macro_tile_slot = 5'd13;
                        default: macro_tile_slot = 5'd11;
                    endcase
                end
                3'd3: begin
                    case (tile_y)
                        3'd0: macro_tile_slot = 5'd13;
                        3'd1: macro_tile_slot = 5'd11;
                        3'd2: macro_tile_slot = 5'd14;
                        3'd3: macro_tile_slot = 5'd8;
                        3'd4: macro_tile_slot = 5'd9;
                        3'd5: macro_tile_slot = 5'd15;
                        3'd6: macro_tile_slot = 5'd10;
                        default: macro_tile_slot = 5'd12;
                    endcase
                end
                3'd4: begin
                    case (tile_y)
                        3'd0: macro_tile_slot = 5'd4;
                        3'd1: macro_tile_slot = 5'd2;
                        3'd2: macro_tile_slot = 5'd7;
                        3'd3: macro_tile_slot = 5'd1;
                        3'd4: macro_tile_slot = 5'd0;
                        3'd5: macro_tile_slot = 5'd6;
                        3'd6: macro_tile_slot = 5'd3;
                        default: macro_tile_slot = 5'd5;
                    endcase
                end
                3'd5: begin
                    case (tile_y)
                        3'd0: macro_tile_slot = 5'd3;
                        3'd1: macro_tile_slot = 5'd5;
                        3'd2: macro_tile_slot = 5'd0;
                        3'd3: macro_tile_slot = 5'd6;
                        3'd4: macro_tile_slot = 5'd7;
                        3'd5: macro_tile_slot = 5'd1;
                        3'd6: macro_tile_slot = 5'd4;
                        default: macro_tile_slot = 5'd2;
                    endcase
                end
                3'd6: begin
                    case (tile_y)
                        3'd0: macro_tile_slot = 5'd14;
                        3'd1: macro_tile_slot = 5'd8;
                        3'd2: macro_tile_slot = 5'd13;
                        3'd3: macro_tile_slot = 5'd11;
                        3'd4: macro_tile_slot = 5'd10;
                        3'd5: macro_tile_slot = 5'd12;
                        3'd6: macro_tile_slot = 5'd9;
                        default: macro_tile_slot = 5'd15;
                    endcase
                end
                default: begin
                    case (tile_y)
                        3'd0: macro_tile_slot = 5'd9;
                        3'd1: macro_tile_slot = 5'd15;
                        3'd2: macro_tile_slot = 5'd10;
                        3'd3: macro_tile_slot = 5'd12;
                        3'd4: macro_tile_slot = 5'd13;
                        3'd5: macro_tile_slot = 5'd11;
                        3'd6: macro_tile_slot = 5'd14;
                        default: macro_tile_slot = 5'd8;
                    endcase
                end
            endcase
        end
    endfunction

    function [63:0] bit_mask;
        input [5:0] bit_idx;
        begin
            if (bit_idx >= 6'd63) begin
                bit_mask = {63'd0, 1'b1} << 63;
            end else begin
                bit_mask = 64'd1 << bit_idx;
            end
        end
    endfunction

    function get_bit64;
        input [5:0] bit_idx;
        input [63:0] word;
        begin
            get_bit64 = ((word & bit_mask(bit_idx)) != 64'd0);
        end
    endfunction

    function [63:0] program_bit64;
        input [5:0] bit_idx;
        input       bit_value;
        input [63:0] word;
        begin
            if (bit_value) begin
                program_bit64 = word | bit_mask(bit_idx);
            end else begin
                program_bit64 = word & ~bit_mask(bit_idx);
            end
        end
    endfunction

    function [63:0] mul64x32_shift_add;
        input [63:0] multiplicand;
        input [31:0] multiplier;
        integer idx;
        begin
            mul64x32_shift_add = 64'd0;
            for (idx = 0; idx < 32; idx = idx + 1) begin
                if (multiplier[idx])
                    mul64x32_shift_add = mul64x32_shift_add + (multiplicand << idx);
            end
        end
    endfunction

    wire [ADDR_W-1:0] cfg_base_addr_rgba_y;
    assign cfg_base_addr_rgba_y = i_meta_fcnt[0] ? i_cfg_base_addr_rgba_y1 :
                                                               i_cfg_base_addr_rgba_y0;
    wire [ADDR_W-1:0] cfg_base_addr_uv;
    assign cfg_base_addr_uv = i_meta_fcnt[0] ? i_cfg_base_addr_uv1 :
                                                               i_cfg_base_addr_uv0;

    wire meta_is_rgba;
    assign meta_is_rgba = (i_meta_format == META_FMT_RGBA8888) ||
                          (i_meta_format == META_FMT_RGBA1010102);
    wire meta_is_nv12;
    assign meta_is_nv12 = (i_meta_format == META_FMT_NV12_Y) ||
                          (i_meta_format == META_FMT_NV12_UV);
    wire meta_is_p010;
    assign meta_is_p010 = (i_meta_format == META_FMT_P010_Y) ||
                          (i_meta_format == META_FMT_P010_UV);
    wire meta_is_uv;
    assign meta_is_uv = (i_meta_format == META_FMT_NV12_UV) ||
                        (i_meta_format == META_FMT_P010_UV);

    wire [15:0] tile_width;
    assign tile_width = meta_is_rgba ? 16'd16 : 16'd32;
    wire [15:0] tile_height;
    assign tile_height = meta_is_nv12 ? 16'd8 : 16'd4;
    wire [2:0] bytes_per_pixel;
    assign bytes_per_pixel = meta_is_nv12 ? 3'd1 :
                             meta_is_p010 ? 3'd2 :
                                            3'd4;
    wire [63:0] surface_pitch_bytes;
    assign surface_pitch_bytes = {{(ADDR_W-16){1'b0}}, i_cfg_pitch, 4'b0000};
    wire [8:0] compressed_size_bytes;
    assign compressed_size_bytes = i_meta_has_payload ? (({6'd0, i_meta_alen} + 9'd1) << 5) :
                                                        9'd0;
    wire lossy_rgba_2_1_active;
    assign lossy_rgba_2_1_active = i_cfg_is_lossy_rgba_2_1_format &&
                                   (i_meta_format == META_FMT_RGBA8888);
    wire [63:0] payload_base_addr;
    assign payload_base_addr = meta_is_uv ? cfg_base_addr_uv :
                                            cfg_base_addr_rgba_y;
    wire [15:0] eff_tile_y;
    assign eff_tile_y = lossy_rgba_2_1_active ? {7'd0, i_meta_y[9:1]} :
                                                  {6'd0, i_meta_y};
    wire [15:0] macro_tile_x;
    assign macro_tile_x = {6'd0, i_meta_x[11:2]};
    wire [15:0] macro_tile_y;
    assign macro_tile_y = eff_tile_y >> 2;
    wire [2:0] temp_tile_x;
    assign temp_tile_x = i_meta_x[2:0];
    wire [2:0] temp_tile_y;
    assign temp_tile_y = eff_tile_y[2:0];
    wire [4:0] slot;
    assign slot = macro_tile_slot(temp_tile_x, temp_tile_y);
    wire [63:0] row_factor;
    assign row_factor = (tile_height == 16'd8) ? ({48'd0, macro_tile_y} << 5) :
                                                 ({48'd0, macro_tile_y} << 4);
    wire [63:0] macro_tile_base;
    assign macro_tile_base = mul64x32_shift_add(surface_pitch_bytes, row_factor[31:0]) +
                             ({48'd0, macro_tile_x} << 12);
    wire [63:0] addr_bytes_base;
    assign addr_bytes_base = macro_tile_base + ({59'd0, slot} << 8);
    wire use_special_swizzle_taps;
    assign use_special_swizzle_taps =
        ((bytes_per_pixel == 3'd1) && (tile_width == 16'd32) && (tile_height == 16'd8)) ||
        ((bytes_per_pixel == 3'd2) && (tile_width == 16'd16) && (tile_height == 16'd8));
    wire [63:0] tile_row_pixels;
    assign tile_row_pixels = (tile_height == 16'd8) ? ({48'd0, eff_tile_y} << 3) :
                                                     ({48'd0, eff_tile_y} << 2);
    wire [63:0] spread_mask;
    assign spread_mask = (i_cfg_highest_bank_bit == 5'd0) ? 64'd0 :
                         ((64'd1 << i_cfg_highest_bank_bit) - 1'b1);
    wire lvl2_cond;
    assign lvl2_cond = (i_cfg_highest_bank_bit != 5'd0) &&
                       (((surface_pitch_bytes << 4) & spread_mask) == 64'd0);
    wire [63:0] lvl3_mask;
    assign lvl3_mask = (64'd1 << (i_cfg_highest_bank_bit + 1'b1)) - 1'b1;
    wire lvl3_cond;
    assign lvl3_cond = (i_cfg_highest_bank_bit < 5'd31) &&
                       (((surface_pitch_bytes << 4) & lvl3_mask) == 64'd0);
    wire lvl2_bit_value;
    assign lvl2_bit_value = get_bit64(i_cfg_highest_bank_bit - 1'b1, addr_bytes_base) ^
                            (use_special_swizzle_taps ? get_bit64(6'd5, tile_row_pixels) :
                                                        get_bit64(6'd4, tile_row_pixels));
    wire [63:0] addr_after_lvl2;
    assign addr_after_lvl2 = (i_cfg_lvl2_bank_swizzle_en && lvl2_cond) ?
                             program_bit64(i_cfg_highest_bank_bit - 1'b1,
                                           lvl2_bit_value,
                                           addr_bytes_base) :
                             addr_bytes_base;
    wire lvl3_bit_value;
    assign lvl3_bit_value = get_bit64({1'b0, i_cfg_highest_bank_bit}, addr_after_lvl2) ^
                            (use_special_swizzle_taps ? get_bit64(6'd6, tile_row_pixels) :
                                                        get_bit64(6'd5, tile_row_pixels));
    wire [63:0] addr_after_lvl3;
    assign addr_after_lvl3 = (i_cfg_lvl3_bank_swizzle_en && lvl3_cond) ?
                             program_bit64({1'b0, i_cfg_highest_bank_bit},
                                           lvl3_bit_value,
                                           addr_after_lvl2) :
                             addr_after_lvl2;
    wire [63:0] addr_after_lossy;
    assign addr_after_lossy = lossy_rgba_2_1_active ?
                              (addr_after_lvl3 + ({63'd0, i_meta_y[0]} << 7)) :
                              addr_after_lvl3;
    wire bank_spread_en;
    assign bank_spread_en = i_cfg_bank_spread_en && !lossy_rgba_2_1_active;
    wire bank_spread_bump;
    assign bank_spread_bump = bank_spread_en && i_meta_has_payload &&
                              (compressed_size_bytes <= 9'd128) &&
                              (addr_after_lossy[8] ^ addr_after_lossy[9]);
    wire [63:0] addr_after_spread;
    assign addr_after_spread = bank_spread_bump ? (addr_after_lossy + 64'd128) :
                                                  addr_after_lossy;
    wire [63:0] addr_bytes;
    assign addr_bytes = addr_after_spread + payload_base_addr;

    assign o_meta_ready      = i_cmd_ready;
    assign o_cmd_valid       = i_meta_valid;
    assign o_cmd_addr        = addr_bytes[ADDR_W-1:4];
    assign o_cmd_format      = i_meta_format;
    assign o_cmd_meta        = i_meta_flag;
    assign o_cmd_alen        = i_meta_alen;
    assign o_cmd_has_payload = i_meta_has_payload;
    assign o_cmd_fcnt        = i_meta_fcnt;

endmodule
