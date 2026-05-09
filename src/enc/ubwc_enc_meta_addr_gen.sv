//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-04-24  03:42:51
// Module Name       : ubwc_enc_meta_addr_gen.sv
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//      Revision 1.00 - File Created by      : MiaoJiawang
//      Description                           :
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_enc_meta_addr_gen
    #(
        parameter                                       SB_WIDTH                        = 1,
        parameter                                       IN_FIFO_DEPTH                   = 32,
        parameter                                       META_AW                         = 64,
        parameter                                       TH_DW                           = 12,
        parameter                                       TW_DW                           = 8
    )(
        input   wire                                        i_clk                           ,
        input   wire                                        i_rstn                          ,

        input   wire                                        i_srstn                         ,

        input   wire    [32                  -1 :0]         i_meta_data_plane_pitch         ,
        input   wire    [TW_DW               -1 :0]         i_meta_last_xcoord              ,

        input   wire    [64                  -1 :0]         i_meta_y_base_offset_addr0      ,
        input   wire    [64                  -1 :0]         i_meta_uv_base_offset_addr0     ,
        input   wire    [64                  -1 :0]         i_meta_y_base_offset_addr1      ,
        input   wire    [64                  -1 :0]         i_meta_uv_base_offset_addr1     ,

        input   wire                                        i_co_valid                      ,
        input   wire    [3                   -1 :0]         i_co_alen                       ,
        input   wire    [SB_WIDTH            -1 :0]         i_co_sb                         ,
        input   wire                                        i_co_pcm                        ,
        input   wire    [5                   -1 :0]         i_format                        ,
        input   wire    [4                   -1 :0]         i_fcnt                          ,
        input   wire    [TH_DW               -1 :0]         i_ycoord                        ,
        input   wire    [TW_DW               -1 :0]         i_xcoord                        ,

        output  logic                                       o_meta_data_valid               ,
        output  logic   [66                  -1 :0]         o_meta_data                     ,
        input   logic                                       i_meta_data_ready               ,

        output  logic                                       o_meta_addr_valid               ,
        output  logic   [META_AW             -1 :0]         o_meta_addr                     ,
        output  logic   [4                   -1 :0]         o_meta_fcnt                     ,
        input   logic                                       i_meta_addr_ready               ,

        output  logic                                       o_meta_err_0                    , // co_buffer_overflow
        output  logic                                       o_meta_err_1                    , // incorrect tile order
        output  logic                                       o_frame_done
    );

    localparam                                      IN_DATA_W                       = 3+SB_WIDTH+1+5+4+TH_DW+TW_DW;
    localparam  [4                      :0]         FMT_NV12_UV                     = 5'd9;
    localparam  [4                      :0]         FMT_P010_UV                     = 5'd15;
    localparam  integer                             META_Y_GROUP_W                  = TH_DW - 4;
    localparam  integer                             META_TILE_OFFSET_W              = TW_DW + 4;
    localparam  integer                             META_ADDR_FIFO_W                = META_AW + 4;

    wire                                            co_buf_full                     ;
    wire        [3                   -1 :0]         int_co_alen                     ;
    wire        [SB_WIDTH            -1 :0]         int_co_sb                       ;
    wire                                            int_co_pcm                      ;
    wire        [5                   -1 :0]         int_format                      ;
    wire        [4                   -1 :0]         int_fcnt                        ;
    wire        [TH_DW               -1 :0]         int_ycoord                      ;
    wire        [TW_DW               -1 :0]         int_xcoord                      ;
    wire        [IN_DATA_W           -1 :0]         in_fifo_push_data               ;
    wire                                            in_fifo_push_ready              ;
    wire                                            fifo_sclr                       ;
    wire                                            in_fifo_pop_valid               ;
    wire        [IN_DATA_W           -1 :0]         in_fifo_pop_data                ;
    wire        [7                      :0]         tile_meta_fill_byte_w           ;
    wire        [65                     :0]         tile_meta_word_w                ;
    wire                                            tile_meta_vld_w                 ;
    wire        [TW_DW               -1 :0]         tile_last_xcoord_w              ;
    wire        [TW_DW               -1 :0]         tile_word_xcoord_w              ;
    wire        [META_AW             -1 :0]         tile_meta_addr_w                ;
    wire                                            meta_data_buf_pfull             ;
    wire                                            meta_addr_buf_pfull             ;
    wire                                            co_buffer_overflow              ;
    wire                                            tile_meta_addr_base_w           ;
    wire        [64                  -1 :0]         tile_meta_y_base_sel            ;
    wire        [64                  -1 :0]         tile_meta_uv_base_sel           ;
    wire        [META_AW             -1 :0]         tile_meta_base_addr             ;
    wire        [META_AW             -1 :0]         tile_meta_pitch_stride_w        ;
    wire        [META_AW             -1 :0]         tile_meta_y_base_addr_next      ;
    wire        [META_Y_GROUP_W      -1 :0]         tile_meta_y_group_w             ;
    wire        [META_Y_GROUP_W      -1 :0]         tile_meta_y_group_inc_w         ;
    wire                                            tile_meta_addr_fire             ;
    wire                                            tile_meta_same_stream_w         ;
    wire                                            tile_meta_group_restart_w       ;
    wire                                            tile_meta_group_same_w          ;
    wire                                            tile_meta_group_next_w          ;
    wire                                            tile_meta_order_err_w           ;
    wire        [META_TILE_OFFSET_W  -1 :0]         tile_meta_offset_w              ;
    wire        [META_ADDR_FIFO_W    -1 :0]         meta_addr_fifo_din              ;
    wire        [META_ADDR_FIFO_W    -1 :0]         meta_addr_fifo_dout             ;

    reg                                             in_fifo_pop_ready               ;
    reg         [2                      :0]         pop_cnt                         ;
    reg                                             tile_meta_vld                   ;
    reg         [3                      :0]         tile_meta_fcnt                  ;
    reg         [63                     :0]         tile_meta_word_data_w           ;
    reg         [META_AW             -1 :0]         tile_meta_addr                  ;
    reg         [META_AW             -1 :0]         tile_meta_y_base_addr_r         ;
    reg         [META_Y_GROUP_W      -1 :0]         tile_meta_y_group_r             ;
    reg                                             tile_meta_y_base_valid_r        ;
    reg                                             tile_meta_y_base_plane_r        ;
    reg                                             tile_meta_y_base_slot_r         ;
    reg                                             tile_meta_order_err_r           ;

    //i_co_singals ...........
    assign fifo_sclr                  = !i_srstn;

    mg_sync_fifo
    #(
        .PROG_DEPTH                 ( 4                             ),
        .DWIDTH                     ( IN_DATA_W                     ),
        .DEPTH                      ( IN_FIFO_DEPTH                 ),
        .SHOW_AHEAD                 ( 1                             )
    )
    ubwc_enc_co_sfifo_inst
    (
        .clk                        ( i_clk                         ),
        .rst_n                      ( i_rstn                        ),
        .sclr                       ( fifo_sclr                     ),
        .wr_en                      ( i_co_valid                    ),
        .din                        ( in_fifo_push_data             ),
        .prog_full                  (                               ),
        .full                       ( co_buf_full                   ),
        .rd_en                      ( in_fifo_pop_ready             ),
        .empty                      (                               ),
        .dout                       ( in_fifo_pop_data              ),
        .valid                      ( in_fifo_pop_valid             ),
        .data_count                 (                               )
    );

    //.................................

    //logic for meta data

    //pop_cnt

    assign in_fifo_push_data          = {i_co_alen, i_co_sb, i_co_pcm, i_format, i_fcnt, i_ycoord, i_xcoord};
    assign in_fifo_push_ready         = ~co_buf_full  ;
    assign int_xcoord                 = in_fifo_pop_data[0                        +:TW_DW     ];
    assign int_ycoord                 = in_fifo_pop_data[TW_DW                    +:TH_DW     ];
    assign int_fcnt                   = in_fifo_pop_data[TH_DW+TW_DW              +:4         ];
    assign int_format                 = in_fifo_pop_data[TH_DW+TW_DW+4            +:5         ];
    assign int_co_pcm                 = in_fifo_pop_data[TH_DW+TW_DW+4+5          +:1         ];
    assign int_co_sb                  = in_fifo_pop_data[TH_DW+TW_DW+4+5+1        +:SB_WIDTH  ];
    assign int_co_alen                = in_fifo_pop_data[TH_DW+TW_DW+4+5+1+SB_WIDTH +:3       ];
    assign tile_meta_fill_byte_w      = {4'h1, int_co_alen, 1'b0};
    assign tile_meta_vld_w            = tile_meta_vld;
    assign tile_last_xcoord_w         = i_meta_last_xcoord;
    assign tile_word_xcoord_w         = {int_xcoord[TW_DW-1:3], 3'b000};
    assign co_buffer_overflow         = i_co_valid & co_buf_full;
    assign tile_meta_addr_base_w      = ((int_format == FMT_NV12_UV) || (int_format == FMT_P010_UV)) ? 1'b1 : 1'b0;
    assign tile_meta_y_base_sel       = int_fcnt[0] ? i_meta_y_base_offset_addr1  : i_meta_y_base_offset_addr0;
    assign tile_meta_uv_base_sel      = int_fcnt[0] ? i_meta_uv_base_offset_addr1 : i_meta_uv_base_offset_addr0;
    assign tile_meta_base_addr        = tile_meta_addr_base_w ? tile_meta_uv_base_sel : tile_meta_y_base_sel;
    assign tile_meta_pitch_stride_w   = {{(META_AW-36){1'b0}}, i_meta_data_plane_pitch, 4'd0};
    assign tile_meta_addr_w           = tile_meta_addr;
    assign tile_meta_word_w           = {tile_meta_addr[4:3], tile_meta_word_data_w};
    assign tile_meta_offset_w         = {int_xcoord[TW_DW-1:4]
                                         ,int_ycoord[3+:1]
                                         ,int_xcoord[3+:1]
                                         ,int_ycoord[0+:3]
                                         ,int_xcoord[0+:3]};
    assign tile_meta_addr_fire        = in_fifo_pop_valid && in_fifo_pop_ready && (int_xcoord[2:0] == 3'd0);
    assign tile_meta_y_group_w        = int_ycoord[TH_DW-1:4];
    assign tile_meta_y_group_inc_w    = tile_meta_y_group_r + {{(META_Y_GROUP_W-1){1'b0}}, 1'b1};
    assign tile_meta_same_stream_w    = tile_meta_y_base_valid_r &&
                                        (tile_meta_y_base_slot_r == int_fcnt[0]) &&
                                        (tile_meta_y_base_plane_r == tile_meta_addr_base_w);
    assign tile_meta_group_restart_w  = !tile_meta_same_stream_w ||
                                        (tile_meta_y_group_w == {META_Y_GROUP_W{1'b0}});
    assign tile_meta_group_same_w     = tile_meta_same_stream_w &&
                                        (tile_meta_y_group_w == tile_meta_y_group_r);
    assign tile_meta_group_next_w     = tile_meta_same_stream_w &&
                                        (tile_meta_y_group_w == tile_meta_y_group_inc_w);
    assign tile_meta_y_base_addr_next = tile_meta_group_restart_w ? {META_AW{1'b0}} :
                                        tile_meta_group_same_w    ? tile_meta_y_base_addr_r :
                                        (tile_meta_y_base_addr_r + tile_meta_pitch_stride_w);
    assign tile_meta_order_err_w      = tile_meta_addr_fire &&
                                        !tile_meta_group_restart_w &&
                                        !tile_meta_group_same_w &&
                                        !tile_meta_group_next_w;
    assign meta_addr_fifo_din         = {tile_meta_fcnt, tile_meta_addr};
    assign o_meta_addr                = meta_addr_fifo_dout[0 +: META_AW];
    assign o_meta_fcnt                = meta_addr_fifo_dout[META_ADDR_FIFO_W-1 -: 4];
    assign o_meta_err_0               = co_buffer_overflow;
    assign o_meta_err_1               = tile_meta_order_err_r;
    assign o_frame_done               = 1'b0;

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            pop_cnt <= 3'd0    ;
        else if(in_fifo_pop_valid && in_fifo_pop_ready) begin
            if(int_xcoord[2:0] == 3'd0)
                pop_cnt <= 3'd1 ;
            else
                pop_cnt <= pop_cnt + 1'b1   ;
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            tile_meta_word_data_w    <= 64'd0    ;
        else if(in_fifo_pop_valid && in_fifo_pop_ready) begin
            case(int_xcoord[2:0])
                3'd0    :   tile_meta_word_data_w    <= {56'd0,tile_meta_fill_byte_w                              }    ;
                3'd1    :   tile_meta_word_data_w    <= {48'd0,tile_meta_fill_byte_w,tile_meta_word_data_w[0 +: 8]}    ;
                3'd2    :   tile_meta_word_data_w    <= {40'd0,tile_meta_fill_byte_w,tile_meta_word_data_w[0 +:16]}    ;
                3'd3    :   tile_meta_word_data_w    <= {32'd0,tile_meta_fill_byte_w,tile_meta_word_data_w[0 +:24]}    ;
                3'd4    :   tile_meta_word_data_w    <= {24'd0,tile_meta_fill_byte_w,tile_meta_word_data_w[0 +:32]}    ;
                3'd5    :   tile_meta_word_data_w    <= {16'd0,tile_meta_fill_byte_w,tile_meta_word_data_w[0 +:40]}    ;
                3'd6    :   tile_meta_word_data_w    <= { 8'd0,tile_meta_fill_byte_w,tile_meta_word_data_w[0 +:48]}    ;
                3'd7    :   tile_meta_word_data_w    <= {      tile_meta_fill_byte_w,tile_meta_word_data_w[0 +:56]}    ;
            endcase
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            in_fifo_pop_ready   <= 1'b0 ;
        else if((meta_data_buf_pfull == 1'b0) && (meta_addr_buf_pfull == 1'b0))
            in_fifo_pop_ready   <= 1'b1 ;
        else if(((pop_cnt == 3'd7) || (int_xcoord == i_meta_last_xcoord)) && ((meta_data_buf_pfull == 1'b1) || (meta_addr_buf_pfull == 1'b1)))
            in_fifo_pop_ready   <= 1'b0 ;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            tile_meta_vld   <= 1'b0 ;
        else if(in_fifo_pop_valid && in_fifo_pop_ready) begin
            if((pop_cnt == 3'd7) || (int_xcoord == i_meta_last_xcoord))
                tile_meta_vld   <= 1'b1 ;
            else
                tile_meta_vld   <= 1'b0 ;
        end else
            tile_meta_vld   <= 1'b0 ;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            tile_meta_fcnt  <= 4'd0 ;
        else if(in_fifo_pop_valid && in_fifo_pop_ready && ((pop_cnt == 3'd7) || (int_xcoord == i_meta_last_xcoord)))
            tile_meta_fcnt  <= int_fcnt ;
    end

    mg_sync_fifo
    #(
        .PROG_DEPTH                 ( 1                             ),
        .DWIDTH                     ( 66                            ),  // 64-bit meta data + 2-bit 256-bit lane index
        .DEPTH                      ( 32                            ),
        .SHOW_AHEAD                 ( 1                             )
    )
    ubwc_enc_meta_data_buf_inst
    (
        .clk                        ( i_clk                         ),
        .rst_n                      ( i_rstn                        ),
        .sclr                       ( fifo_sclr                     ),
        .wr_en                      ( tile_meta_vld                 ),
        .din                        ( tile_meta_word_w              ),
        .prog_full                  ( meta_data_buf_pfull           ),
        .full                       (                               ),
        .rd_en                      ( i_meta_data_ready             ),
        .empty                      (                               ),
        .dout                       ( o_meta_data                   ),
        .valid                      ( o_meta_data_valid             ),
        .data_count                 (                               )
    );

    //logic for meta addr

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            tile_meta_addr  <= {META_AW{1'd0}}    ;
        else if(tile_meta_addr_fire)
                tile_meta_addr  <= tile_meta_base_addr
                                 + tile_meta_y_base_addr_next
                                 + {{(META_AW-META_TILE_OFFSET_W){1'b0}}, tile_meta_offset_w};
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            tile_meta_y_base_addr_r <= {META_AW{1'b0}};
        else if(!i_srstn)
            tile_meta_y_base_addr_r <= {META_AW{1'b0}};
        else if(tile_meta_addr_fire)
            tile_meta_y_base_addr_r <= tile_meta_y_base_addr_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            tile_meta_y_group_r <= {META_Y_GROUP_W{1'b0}};
        else if(!i_srstn)
            tile_meta_y_group_r <= {META_Y_GROUP_W{1'b0}};
        else if(tile_meta_addr_fire)
            tile_meta_y_group_r <= tile_meta_y_group_w;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            tile_meta_y_base_valid_r <= 1'b0;
        else if(!i_srstn)
            tile_meta_y_base_valid_r <= 1'b0;
        else if(tile_meta_addr_fire)
            tile_meta_y_base_valid_r <= 1'b1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            tile_meta_y_base_plane_r <= 1'b0;
        else if(!i_srstn)
            tile_meta_y_base_plane_r <= 1'b0;
        else if(tile_meta_addr_fire)
            tile_meta_y_base_plane_r <= tile_meta_addr_base_w;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            tile_meta_y_base_slot_r <= 1'b0;
        else if(!i_srstn)
            tile_meta_y_base_slot_r <= 1'b0;
        else if(tile_meta_addr_fire)
            tile_meta_y_base_slot_r <= int_fcnt[0];
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            tile_meta_order_err_r <= 1'b0;
        else if(!i_srstn)
            tile_meta_order_err_r <= 1'b0;
        else
            tile_meta_order_err_r <= tile_meta_order_err_w;
    end

    mg_sync_fifo
    #(
        .PROG_DEPTH                 ( 1                             ),
        .DWIDTH                     ( META_ADDR_FIFO_W              ),
        .DEPTH                      ( 32                            ),
        .SHOW_AHEAD                 ( 1                             )
    )
    ubwc_enc_meta_addr_buf_inst
    (
        .clk                        ( i_clk                         ),
        .rst_n                      ( i_rstn                        ),
        .sclr                       ( fifo_sclr                     ),
        .wr_en                      ( tile_meta_vld                 ),
        .din                        ( meta_addr_fifo_din            ),
        .prog_full                  ( meta_addr_buf_pfull           ),
        .full                       (                               ),
        .rd_en                      ( i_meta_addr_ready             ),
        .empty                      (                               ),
        .dout                       ( meta_addr_fifo_dout           ),
        .valid                      ( o_meta_addr_valid             ),
        .data_count                 (                               )
    );

endmodule
