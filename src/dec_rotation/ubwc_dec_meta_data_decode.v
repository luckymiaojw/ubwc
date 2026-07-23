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
    input   wire    [11                      :0]        i_cfg_tile_x_numbers            ,
    input   wire    [9                       :0]        i_cfg_tile_y_numbers            ,
    input   wire    [3                       :0]        i_meta_fcnt                     ,
    output  wire                                        o_dec_valid                     ,
    input   wire                                        i_dec_ready                     ,
    output  wire    [4                       :0]        o_dec_format                    ,
    output  wire    [3                       :0]        o_dec_flag                      ,
    output  wire    [2                       :0]        o_dec_alen                      ,
    output  wire    [1                       :0]        o_dec_alpha_mode                ,
    output  wire    [11                      :0]        o_dec_x                         ,
    output  wire    [9                       :0]        o_dec_y                         ,
    output  wire    [3                       :0]        o_dec_fcnt
);

    localparam  [4                       :0]        META_FMT_NV12_UV                = 5'b01001;
    localparam  [4                       :0]        META_FMT_RGBA8888               = 5'b00000;
    localparam  [4                       :0]        META_FMT_P010_UV                = 5'b01111;

    wire                                            force_full_payload_en           ;
    wire                                            meta_is_uv_plane                ;
    wire                                            meta_is_rgba8888                ;
    wire                                            meta_coord_active               ;
    wire                                            meta_is_sc                      ;
    wire                                            meta_is_fc                      ;
    wire                                            meta_rgba_pcm                   ;
    wire        [2                       :0]        meta_regular_alen               ;
    wire        [2                       :0]        meta_rgba8888_alen              ;
    wire        [3                       :0]        meta_flag                       ;
    wire        [2                       :0]        meta_alen                       ;
    wire        [1                       :0]        meta_alpha_mode                 ;
    wire        [10                      :0]        meta_tile_y_limit               ;

    assign meta_is_uv_plane              = (i_meta_format == META_FMT_NV12_UV) ||
                                           (i_meta_format == META_FMT_P010_UV);
    assign meta_is_rgba8888              = (i_meta_format == META_FMT_RGBA8888);
    assign meta_tile_y_limit             = meta_is_uv_plane ?
                                           (({1'b0, i_cfg_tile_y_numbers} + 11'd1) >> 1) :
                                           {1'b0, i_cfg_tile_y_numbers};
    assign meta_coord_active             = (i_meta_x < i_cfg_tile_x_numbers) &&
                                           ({1'b0, i_meta_y} < meta_tile_y_limit);
    assign force_full_payload_en         = (FORCE_FULL_PAYLOAD != 0) && meta_coord_active;
    assign meta_is_sc                    = (i_meta_data[7:6] != 2'b00);
    assign meta_is_fc                    = !meta_is_sc && !i_meta_data[4];
    assign meta_rgba_pcm                 = (i_meta_data[3:1] == 3'b111);
    assign meta_regular_alen             = i_meta_data[3:1];
    assign meta_rgba8888_alen            = i_cfg_is_lossy_rgba_2_1_format ?
                                           (meta_rgba_pcm ? 3'd3 : meta_regular_alen) :
                                           (meta_rgba_pcm ? (i_meta_data[5] ? 3'd5 : 3'd7) :
                                                            meta_regular_alen);
    assign meta_flag                     = !meta_coord_active  ? 4'h8 :
                                           force_full_payload_en ? 4'h7 :
                                           meta_is_sc            ? 4'd0 :
                                                                   {~i_meta_data[4], i_meta_data[3:1]};
    assign meta_alen                     = !meta_coord_active    ? 3'd0 :
                                           force_full_payload_en ? 3'd7 :
                                           meta_is_sc            ? 3'd0 :
                                           meta_is_fc            ? 3'd0 :
                                           meta_is_rgba8888      ? meta_rgba8888_alen :
                                                                   meta_regular_alen;
    assign meta_alpha_mode               = meta_coord_active ? {i_meta_data[5], i_meta_data[0]} :
                                                               2'd0;
    assign o_meta_ready                  = meta_coord_active ? i_dec_ready : 1'b1;
    assign o_dec_valid                   = i_meta_valid && meta_coord_active;
    assign o_dec_format                  = i_meta_format;
    assign o_dec_flag                    = meta_flag;
    assign o_dec_alen                    = meta_alen;
    assign o_dec_alpha_mode              = meta_alpha_mode;
    assign o_dec_x                       = i_meta_x;
    assign o_dec_y                       = i_meta_y;
    assign o_dec_fcnt                    = i_meta_fcnt;

endmodule
