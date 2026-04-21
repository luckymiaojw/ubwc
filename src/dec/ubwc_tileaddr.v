`timescale 1ns/1ps

module ubwc_tile_addr #(
    parameter ADDR_W = 64
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 i_cfg_lvl1_bank_swizzle_en,
    input  wire                 i_cfg_lvl2_bank_swizzle_en,
    input  wire                 i_cfg_lvl3_bank_swizzle_en,
    input  wire [4:0]           i_cfg_highest_bank_bit,
    input  wire                 i_cfg_bank_spread_en,
    input  wire                 i_cfg_4line_format,
    input  wire                 i_cfg_is_lossy_rgba_2_1_format,
    input  wire [11:0]          i_cfg_pitch,
    input  wire [ADDR_W-1:0]    i_cfg_base_addr_rgba_uv,
    input  wire [ADDR_W-1:0]    i_cfg_base_addr_y,
    input  wire                 i_meta_valid,
    output wire                 o_meta_ready,
    input  wire [4:0]           i_meta_format,
    input  wire [3:0]           i_meta_flag,
    input  wire [2:0]           i_meta_alen,
    input  wire                 i_meta_has_payload,
    input  wire [11:0]          i_meta_x,
    input  wire [9:0]           i_meta_y,
    output wire                 o_cmd_valid,
    input  wire                 i_cmd_ready,
    output wire [ADDR_W-5:0]    o_cmd_addr,
    output wire [4:0]           o_cmd_format,
    output wire [3:0]           o_cmd_meta,
    output wire [2:0]           o_cmd_alen,
    output wire                 o_cmd_has_payload
);

    localparam [4:0] META_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] META_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] META_FMT_NV12_Y      = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV     = 5'b01001;
    localparam [4:0] META_FMT_NV16_Y      = 5'b01010;
    localparam [4:0] META_FMT_NV16_UV     = 5'b01011;
    localparam [4:0] META_FMT_NV16_10_Y   = 5'b01100;
    localparam [4:0] META_FMT_NV16_10_UV  = 5'b01101;
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

    reg [15:0] tile_width;
    reg [15:0] tile_height;
    reg [2:0]  bytes_per_pixel;
    reg [63:0] addr_bytes;
    reg [63:0] surface_pitch_bytes;
    reg [63:0] macro_tile_base;
    reg [63:0] row_factor;
    reg [63:0] tile_row_pixels;
    reg [63:0] spread_mask;
    reg [63:0] payload_base_addr;
    reg [15:0] eff_tile_y;
    reg [15:0] macro_tile_x;
    reg [15:0] macro_tile_y;
    reg [2:0]  temp_tile_x;
    reg [2:0]  temp_tile_y;
    reg [4:0]  slot;
    reg [8:0]  compressed_size_bytes;
    reg        use_special_swizzle_taps;
    reg        lossy_rgba_2_1_active;
    reg        lvl2_cond;
    reg        lvl3_cond;
    reg        bank_spread_en;
    reg        bit_value;

    always @(*) begin
        tile_width = 16'd16;
        tile_height = 16'd4;
        bytes_per_pixel = 3'd4;

        case (i_meta_format)
            META_FMT_RGBA8888,
            META_FMT_RGBA1010102: begin
                tile_width = 16'd16;
                tile_height = 16'd4;
                bytes_per_pixel = 3'd4;
            end
            META_FMT_NV12_Y,
            META_FMT_NV12_UV,
            META_FMT_NV16_Y,
            META_FMT_NV16_UV: begin
                tile_width = 16'd32;
                tile_height = 16'd8;
                bytes_per_pixel = 3'd1;
            end
            META_FMT_NV16_10_Y,
            META_FMT_NV16_10_UV,
            META_FMT_P010_Y,
            META_FMT_P010_UV: begin
                tile_width = 16'd32;
                tile_height = 16'd4;
                bytes_per_pixel = 3'd2;
            end
            default: begin
                tile_width = 16'd16;
                tile_height = 16'd4;
                bytes_per_pixel = 3'd4;
            end
        endcase

        // Assumption: i_cfg_pitch is provided in 16-byte units to fit the 12-bit port.
        surface_pitch_bytes = {{(ADDR_W-16){1'b0}}, i_cfg_pitch, 4'b0000};
        compressed_size_bytes = i_meta_has_payload ? ({6'd0, i_meta_alen} + 9'd1) << 5 : 9'd0;
        lossy_rgba_2_1_active = i_cfg_is_lossy_rgba_2_1_format && (i_meta_format == META_FMT_RGBA8888);
        payload_base_addr = i_cfg_base_addr_rgba_uv;

        case (i_meta_format)
            META_FMT_NV12_Y,
            META_FMT_NV16_Y,
            META_FMT_NV16_10_Y,
            META_FMT_P010_Y: begin
                payload_base_addr = i_cfg_base_addr_y;
            end
            default: begin
                payload_base_addr = i_cfg_base_addr_rgba_uv;
            end
        endcase

        eff_tile_y = lossy_rgba_2_1_active ? {7'd0, i_meta_y[9:1]} : {6'd0, i_meta_y};
        macro_tile_x = {6'd0, i_meta_x[11:2]};
        macro_tile_y = eff_tile_y >> 2;
        temp_tile_x = i_meta_x[2:0];
        temp_tile_y = eff_tile_y[2:0];

        slot = macro_tile_slot(temp_tile_x, temp_tile_y);
        row_factor = (tile_height == 16'd8) ? ({48'd0, macro_tile_y} << 5) : ({48'd0, macro_tile_y} << 4);
        macro_tile_base = (surface_pitch_bytes * row_factor) + ({48'd0, macro_tile_x} << 12);
        addr_bytes = macro_tile_base + ({59'd0, slot} << 8);

        // Match ubwc_demo.cpp: compute the swizzled plane-local tile address first,
        // then add the plane base afterwards so base bits do not affect swizzling.
        use_special_swizzle_taps =
            ((bytes_per_pixel == 3'd1) && (tile_width == 16'd32) && (tile_height == 16'd8)) ||
            ((bytes_per_pixel == 3'd2) && (tile_width == 16'd16) && (tile_height == 16'd8));

        tile_row_pixels = (tile_height == 16'd8) ? ({48'd0, eff_tile_y} << 3) : ({48'd0, eff_tile_y} << 2);
        spread_mask = (i_cfg_highest_bank_bit == 0) ? 64'd0 : ((64'd1 << i_cfg_highest_bank_bit) - 1'b1);
        lvl2_cond = (i_cfg_highest_bank_bit != 0) &&
                    (((surface_pitch_bytes << 4) & spread_mask) == 64'd0);
        lvl3_cond = (i_cfg_highest_bank_bit < 5'd31) &&
                    (((surface_pitch_bytes << 4) & ((64'd1 << (i_cfg_highest_bank_bit + 1'b1)) - 1'b1)) == 64'd0);

        if (i_cfg_lvl2_bank_swizzle_en && lvl2_cond) begin
            bit_value = get_bit64(i_cfg_highest_bank_bit - 1'b1, addr_bytes) ^
                        (use_special_swizzle_taps ? get_bit64(6'd5, tile_row_pixels)
                                                  : get_bit64(6'd4, tile_row_pixels));
            addr_bytes = program_bit64(i_cfg_highest_bank_bit - 1'b1, bit_value, addr_bytes);
        end

        if (i_cfg_lvl3_bank_swizzle_en && lvl3_cond) begin
            bit_value = get_bit64(i_cfg_highest_bank_bit, addr_bytes) ^
                        (use_special_swizzle_taps ? get_bit64(6'd6, tile_row_pixels)
                                                  : get_bit64(6'd5, tile_row_pixels));
            addr_bytes = program_bit64(i_cfg_highest_bank_bit, bit_value, addr_bytes);
        end

        if (lossy_rgba_2_1_active) begin
            addr_bytes = addr_bytes + ({63'd0, i_meta_y[0]} << 7);
        end

        bank_spread_en = i_cfg_bank_spread_en && !lossy_rgba_2_1_active;
        if (bank_spread_en && i_meta_has_payload && (compressed_size_bytes <= 9'd128) &&
            (addr_bytes[8] ^ addr_bytes[9])) begin
            addr_bytes = addr_bytes + 64'd128;
        end

        addr_bytes = addr_bytes + payload_base_addr;
    end

    assign o_meta_ready      = i_cmd_ready;
    assign o_cmd_valid       = i_meta_valid;
    assign o_cmd_addr        = addr_bytes[ADDR_W-1:4];
    assign o_cmd_format      = i_meta_format;
    assign o_cmd_meta        = i_meta_flag;
    assign o_cmd_alen        = i_meta_alen;
    assign o_cmd_has_payload = i_meta_has_payload;

    wire unused_cfg = clk | rst_n | i_cfg_lvl1_bank_swizzle_en | i_cfg_4line_format;

endmodule
