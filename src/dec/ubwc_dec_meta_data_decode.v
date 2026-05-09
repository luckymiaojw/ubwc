`timescale 1ns/1ps

module ubwc_dec_meta_data_decode #(
    parameter                                       FORCE_FULL_PAYLOAD              = 0
) (
    input   wire                                        i_cfg_is_lossy_rgba_2_1_format  ,
    input   wire                                        i_meta_valid                    ,
    output  wire                                        o_meta_ready                    ,
    input   wire    [4                       :0]        i_meta_format                   ,
    input   wire    [7                       :0]        i_meta_data                     ,
    input   wire    [11                      :0]        i_meta_x                        ,
    input   wire    [9                       :0]        i_meta_y                        ,
    input   wire    [3                       :0]        i_meta_fcnt                     ,
    output  wire                                        o_dec_valid                     ,
    input   wire                                        i_dec_ready                     ,
    output  wire    [4                       :0]        o_dec_format                    ,
    output  wire    [3                       :0]        o_dec_flag                      ,
    output  wire    [2                       :0]        o_dec_alen                      ,
    output  wire                                        o_dec_has_payload               ,
    output  wire    [11                      :0]        o_dec_x                         ,
    output  wire    [9                       :0]        o_dec_y                         ,
    output  wire    [3                       :0]        o_dec_fcnt
);

    localparam  [4                       :0]        META_FMT_RGBA8888               = 5'b00000;

    wire                                            force_full_payload_en           ;
    wire                                            is_rgba8888                     ;
    wire                                            is_rgba8888_lossy_2_1           ;
    wire                                            meta_escape_payload             ;
    wire                                            meta_zero_payload               ;
    wire                                            meta_regular_payload            ;
    wire                                            alpha_mode_is_2_or_3            ;
    wire                                            regular_size_is_full            ;
    wire                                            regular_size_lossy_shrink       ;
    wire                                            regular_size_alpha_shrink       ;
    wire        [3                       :0]        regular_size_units              ;
    wire        [8                       :0]        regular_compressed_size         ;
    wire        [8                       :0]        compressed_size_pre             ;
    wire        [8                       :0]        compressed_size                 ;
    wire        [3                       :0]        meta_flag                       ;
    wire        [3                       :0]        dec_alen_ext                    ;

    assign force_full_payload_en         = (FORCE_FULL_PAYLOAD != 0);
    assign is_rgba8888                   = (i_meta_format == META_FMT_RGBA8888);
    assign is_rgba8888_lossy_2_1         = i_cfg_is_lossy_rgba_2_1_format && is_rgba8888;
    assign meta_escape_payload           = (i_meta_data[7:6] != 2'b00);
    assign meta_zero_payload             = !i_meta_data[4];
    assign meta_regular_payload          = !force_full_payload_en && !meta_escape_payload && !meta_zero_payload;
    assign alpha_mode_is_2_or_3          = i_meta_data[5];
    assign regular_size_units            = {1'b0, i_meta_data[3:1]} + 4'd1;
    assign regular_compressed_size       = {regular_size_units, 5'd0};
    assign regular_size_is_full          = meta_regular_payload && (regular_compressed_size == 9'd256);
    assign regular_size_lossy_shrink     = regular_size_is_full && is_rgba8888_lossy_2_1;
    assign regular_size_alpha_shrink     = regular_size_is_full && is_rgba8888 && alpha_mode_is_2_or_3;
    assign compressed_size_pre           = force_full_payload_en ? 9'd256 :
                                           meta_escape_payload   ? 9'd32  :
                                           meta_zero_payload     ? 9'd0   :
                                                                   regular_compressed_size;
    assign compressed_size               = regular_size_lossy_shrink ? 9'd128 :
                                           regular_size_alpha_shrink ? 9'd192 :
                                                                       compressed_size_pre;
    assign meta_flag                     = force_full_payload_en ? 4'h7 :
                                           meta_escape_payload   ? 4'd0 :
                                           meta_zero_payload     ? (4'h8 | {1'b0, i_meta_data[3:2], 1'b0}) :
                                                                   {1'b0, i_meta_data[3:1]};
    assign dec_alen_ext                  = compressed_size[8:5] - 4'd1;
    assign o_meta_ready                  = i_dec_ready;
    assign o_dec_valid                   = i_meta_valid;
    assign o_dec_format                  = i_meta_format;
    assign o_dec_flag                    = meta_flag;
    assign o_dec_alen                    = (compressed_size == 9'd0) ? 3'd0 : dec_alen_ext[2:0];
    assign o_dec_has_payload             = (compressed_size != 9'd0);
    assign o_dec_x                       = i_meta_x;
    assign o_dec_y                       = i_meta_y;
    assign o_dec_fcnt                    = i_meta_fcnt;

endmodule
