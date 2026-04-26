`timescale 1ns/1ps

module ubwc_dec_meta_data_decode #(
    parameter FORCE_FULL_PAYLOAD = 0
) (
    input  wire        i_cfg_is_lossy_rgba_2_1_format,
    input  wire        i_meta_valid,
    output wire        o_meta_ready,
    input  wire [4:0]  i_meta_format,
    input  wire [7:0]  i_meta_data,
    input  wire [11:0] i_meta_x,
    input  wire [9:0]  i_meta_y,
    output wire        o_dec_valid,
    input  wire        i_dec_ready,
    output wire [4:0]  o_dec_format,
    output wire [3:0]  o_dec_flag,
    output wire [2:0]  o_dec_alen,
    output wire        o_dec_has_payload,
    output wire [11:0] o_dec_x,
    output wire [9:0]  o_dec_y
);

    localparam [4:0] META_FMT_RGBA8888    = 5'b00000;

    reg [8:0] compressed_size;
    reg [3:0] meta_flag;
    reg [1:0] alpha_mode;
    wire [3:0] dec_alen_ext = compressed_size[8:5] - 4'd1;
    wire is_rgba8888_lossy_2_1 = i_cfg_is_lossy_rgba_2_1_format && (i_meta_format == META_FMT_RGBA8888);

    always @(*) begin
        compressed_size = 9'd0;
        meta_flag = 4'd0;
        alpha_mode = {i_meta_data[5], i_meta_data[0]};

        if (FORCE_FULL_PAYLOAD != 0) begin
            compressed_size = 9'd256;
            meta_flag = 4'h7;
        end else if ((i_meta_data[7:6]) != 2'b00) begin
            compressed_size = 9'd32;
            meta_flag = 4'd0;
        end else if (!i_meta_data[4]) begin
            compressed_size = 9'd0;
            meta_flag = 4'h8 | {1'b0, i_meta_data[3:2], 1'b0};
        end else begin
            compressed_size = ({5'd0, i_meta_data[3:1]} + 9'd1) << 5;
            meta_flag = {1'b0, i_meta_data[3:1]};

            if (compressed_size == 9'd256) begin
                if (is_rgba8888_lossy_2_1) begin
                    compressed_size = 9'd128;
                end else if (i_meta_format == META_FMT_RGBA8888) begin
                    if ((alpha_mode == 2'd2) || (alpha_mode == 2'd3)) begin
                        compressed_size = 9'd192;
                    end
                end
            end
        end
    end

    assign o_meta_ready      = i_dec_ready;
    assign o_dec_valid       = i_meta_valid;
    assign o_dec_format      = i_meta_format;
    assign o_dec_flag        = meta_flag;
    assign o_dec_alen        = (compressed_size == 0) ? 3'd0 : dec_alen_ext[2:0];
    assign o_dec_has_payload = (compressed_size != 0) | (dec_alen_ext[3] & 1'b0);
    assign o_dec_x           = i_meta_x;
    assign o_dec_y           = i_meta_y;

endmodule
