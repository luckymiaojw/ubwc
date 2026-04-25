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
        parameter   SB_WIDTH        = 1     ,
        parameter   IN_FIFO_DEPTH   = 32    ,
        parameter   META_AW         = 64    ,
        parameter   TH_DW           = 12    ,
        parameter   TW_DW           = 8
    )(
        input   wire                        i_clk                       ,
        input   wire                        i_rstn                      ,

        input   wire                        i_srstn                     ,

        input   wire    [32         -1:0]   i_meta_data_plane_pitch     ,
        input   wire    [TW_DW      -1:0]   i_total_x_units             ,

        input   wire    [64         -1:0]   i_meta_y_base_offset_addr   ,
        input   wire    [64         -1:0]   i_meta_uv_base_offset_addr  ,

        input   wire                        i_co_valid                  ,
        input   wire    [3          -1:0]   i_co_alen                   ,
        input   wire    [SB_WIDTH   -1:0]   i_co_sb                     ,
        input   wire                        i_co_pcm                    ,
        input   wire    [5          -1:0]   i_format                    ,
        input   wire    [TH_DW      -1:0]   i_ycoord                    ,
        input   wire    [TW_DW      -1:0]   i_xcoord                    ,

        output  logic                       o_meta_data_valid           ,
        output  logic   [64         -1:0]   o_meta_data                 ,
        input   logic                       i_meta_data_ready           ,

        output  logic                       o_meta_addr_valid           ,
        output  logic   [META_AW    -1:0]   o_meta_addr                 ,
        input   logic                       i_meta_addr_ready           ,

        output  logic                       o_meta_err_0                ,   // co_buffer_overflow
        output  logic                       o_meta_err_1                ,   // incorrect tile order
        output  logic                       o_frame_done
    );

    //i_co_singals ...........
    localparam      IN_DATA_W   = 3+SB_WIDTH+1+5+TH_DW+TW_DW    ;

    wire                         co_buf_full        ;
    wire    [3          -1:0]    int_co_alen        ;
    wire    [SB_WIDTH   -1:0]    int_co_sb          ;
    wire                         int_co_pcm         ;
    wire    [5          -1:0]    int_format         ;
    wire    [TH_DW      -1:0]    int_ycoord         ;
    wire    [TW_DW      -1:0]    int_xcoord         ;

    wire    [IN_DATA_W  -1:0]   in_fifo_push_data   ;
    wire                        in_fifo_push_ready  ;
    wire                        in_fifo_pop_valid   ;
    reg                         in_fifo_pop_ready   ;
    wire    [IN_DATA_W  -1:0]   in_fifo_pop_data    ;


    assign  in_fifo_push_data   = {i_co_alen, i_co_sb, i_co_pcm, i_format, i_ycoord, i_xcoord};
    assign  in_fifo_push_ready  = ~co_buf_full  ;
    assign  int_xcoord          = in_fifo_pop_data[0                        +:TW_DW     ];
    assign  int_ycoord          = in_fifo_pop_data[TW_DW                    +:TH_DW     ];
    assign  int_format          = in_fifo_pop_data[TH_DW+TW_DW              +:5         ];
    assign  int_co_pcm          = in_fifo_pop_data[TH_DW+TW_DW+5            +:1         ];
    assign  int_co_sb           = in_fifo_pop_data[TH_DW+TW_DW+5+1          +:SB_WIDTH  ];
    assign  int_co_alen         = in_fifo_pop_data[TH_DW+TW_DW+5+1+SB_WIDTH +:3         ];

    mg_sync_fifo
    #(
        .PROG_DEPTH             ( 4                     ),
        .DWIDTH                 ( IN_DATA_W             ),
        .DEPTH                  ( IN_FIFO_DEPTH         ),
        .SHOW_AHEAD             ( 1                     )
    )
    ubwc_enc_co_sfifo_inst
    (
        .clk                    ( i_clk                 ),
        .rst_n                  ( i_rstn                ),
        .wr_en                  ( i_co_valid            ),
        .din                    ( in_fifo_push_data     ),
        .prog_full              (                       ),
        .full                   ( co_buf_full           ),
        .rd_en                  ( in_fifo_pop_ready     ),
        .empty                  (                       ),
        .dout                   ( in_fifo_pop_data      ),
        .valid                  ( in_fifo_pop_valid     ),
        .data_count             (                       )
    );

    //.................................

    //logic for meta data
    wire    [7:0]   tile_meta_fill_byte_w   ;
    reg     [2:0]   pop_cnt                 ;
    reg             tile_meta_vld           ;
    reg     [63:0]  tile_meta_word_w        ;
    wire            tile_meta_vld_w         ;
    wire    [63:0]  pack_reg_r              ;
    wire    [TW_DW-1:0] tile_last_xcoord_w  ;
    wire    [TW_DW-1:0] tile_word_xcoord_w  ;
    wire    [META_AW-1:0] tile_meta_addr_w  ;
    wire            meta_data_buf_pfull     ;
    wire            meta_addr_buf_pfull     ;

    function automatic [7:0] build_meta_byte;
        input [2:0] alen;
        begin
            build_meta_byte = {4'h1, alen, 1'b0};
        end
    endfunction

    assign tile_meta_fill_byte_w = build_meta_byte(int_co_alen);
    assign tile_meta_vld_w       = tile_meta_vld;
    assign pack_reg_r            = tile_meta_word_w;
    assign tile_last_xcoord_w    = i_total_x_units;
    assign tile_word_xcoord_w    = {int_xcoord[TW_DW-1:3], 3'b000};

    //pop_cnt
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
            tile_meta_word_w    <= 64'd0    ;
        else if(in_fifo_pop_valid && in_fifo_pop_ready) begin
            case(int_xcoord[2:0])
                3'd0    :   tile_meta_word_w    <= {56'd0,tile_meta_fill_byte_w                         }    ;
                3'd1    :   tile_meta_word_w    <= {48'd0,tile_meta_fill_byte_w,tile_meta_word_w[0 +: 8]}    ;
                3'd2    :   tile_meta_word_w    <= {40'd0,tile_meta_fill_byte_w,tile_meta_word_w[0 +:16]}    ;
                3'd3    :   tile_meta_word_w    <= {32'd0,tile_meta_fill_byte_w,tile_meta_word_w[0 +:24]}    ;
                3'd4    :   tile_meta_word_w    <= {24'd0,tile_meta_fill_byte_w,tile_meta_word_w[0 +:32]}    ;
                3'd5    :   tile_meta_word_w    <= {16'd0,tile_meta_fill_byte_w,tile_meta_word_w[0 +:40]}    ;
                3'd6    :   tile_meta_word_w    <= { 8'd0,tile_meta_fill_byte_w,tile_meta_word_w[0 +:48]}    ;
                3'd7    :   tile_meta_word_w    <= {      tile_meta_fill_byte_w,tile_meta_word_w[0 +:56]}    ;
            endcase
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            in_fifo_pop_ready   <= 1'b0 ;
        else if((meta_data_buf_pfull == 1'b0) && (meta_addr_buf_pfull == 1'b0))
            in_fifo_pop_ready   <= 1'b1 ;
        else if(((pop_cnt == 3'd7) || (int_xcoord == i_total_x_units)) && ((meta_data_buf_pfull == 1'b1) || (meta_addr_buf_pfull == 1'b1)))
            in_fifo_pop_ready   <= 1'b0 ;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            tile_meta_vld   <= 1'b0 ;
        else if(in_fifo_pop_valid && in_fifo_pop_ready) begin
            if((pop_cnt == 3'd7) || (int_xcoord == i_total_x_units))
                tile_meta_vld   <= 1'b1 ;
            else
                tile_meta_vld   <= 1'b0 ;
        end else
            tile_meta_vld   <= 1'b0 ;
    end

    mg_sync_fifo
    #(
        .PROG_DEPTH             ( 1                     ),
        .DWIDTH                 ( 8*8                   ),  //8 meta data width
        .DEPTH                  ( 32                    ),
        .SHOW_AHEAD             ( 1                     )
    )
    ubwc_enc_meta_data_buf_inst
    (
        .clk                    ( i_clk                 ),
        .rst_n                  ( i_rstn                ),
        .wr_en                  ( tile_meta_vld         ),
        .din                    ( tile_meta_word_w      ),
        .prog_full              ( meta_data_buf_pfull   ),
        .full                   (                       ),
        .rd_en                  ( i_meta_data_ready     ),
        .empty                  (                       ),
        .dout                   ( o_meta_data           ),
        .valid                  ( o_meta_data_valid     ),
        .data_count             (                       )
    );

    //logic for meta addr
    localparam [4:0] FMT_NV12_UV    = 5'd9;
    localparam [4:0] FMT_P010_UV    = 5'd15;

    reg     [META_AW  -1:0]     tile_meta_addr          ;
    wire    [META_AW  -1:0]     tile_meta_y_base_addr_w ;
    wire                        tile_meta_addr_base_w   ;
    wire    [META_AW  -1:0]     tile_meta_base_addr     ;

    assign  tile_meta_addr_base_w   = ((int_format == FMT_NV12_UV) || (int_format == FMT_P010_UV)) ? 1'b1 : 1'b0;
    assign  tile_meta_base_addr     = tile_meta_addr_base_w ? i_meta_uv_base_offset_addr : i_meta_y_base_offset_addr;
    assign  tile_meta_y_base_addr_w = int_ycoord[TH_DW-1:4] * {i_meta_data_plane_pitch,4'd0};
    assign  tile_meta_addr_w        = tile_meta_addr;

    always @(posedge i_clk or negedge i_rstn) begin
        if(~i_rstn)
            tile_meta_addr  <= {META_AW{1'd0}}    ;
        else if(in_fifo_pop_valid && in_fifo_pop_ready && (int_xcoord[2:0] == 3'd0))
                tile_meta_addr  <= tile_meta_base_addr
                                 + tile_meta_y_base_addr_w
                                 + {int_xcoord[TW_DW-1:4]
                                   ,int_ycoord[3+:1]
                                   ,int_xcoord[3+:1]
                                   ,int_ycoord[0+:3]
                                   ,int_xcoord[0+:3]} ;
    end

    mg_sync_fifo
    #(
        .PROG_DEPTH                 ( 1                         ),
        .DWIDTH                     ( META_AW                   ),
        .DEPTH                      ( 32                        ),
        .SHOW_AHEAD                 ( 1                         )
    )
    ubwc_enc_meta_addr_buf_inst
    (
        .clk                        ( i_clk                     ),
        .rst_n                      ( i_rstn                    ),
        .wr_en                      ( tile_meta_vld             ),
        .din                        ( tile_meta_addr            ),
        .prog_full                  ( meta_addr_buf_pfull       ),
        .full                       (                           ),
        .rd_en                      ( i_meta_addr_ready         ),
        .empty                      (                           ),
        .dout                       ( o_meta_addr               ),
        .valid                      ( o_meta_addr_valid         ),
        .data_count                 (                           )
    );

endmodule
