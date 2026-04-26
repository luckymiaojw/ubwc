`timescale 1ns/1ps

module ubwc_dec_meta_data_gen
    #(
        parameter   ADDR_WIDTH          = 32    ,
        parameter   ID_WIDTH            = 4     ,
        parameter   AXI_DATA_WIDTH      = 256   ,
        parameter   FORCE_FULL_PAYLOAD  = 0
    )(
        input   wire                                clk                         ,
        input   wire                                rst_n                       ,
        input   wire                                start                       ,

    // External configuration
        input   wire    [5              -1:0]       base_format                 ,
        input   wire    [ADDR_WIDTH     -1:0]       meta_base_addr_rgba_y       ,
        input   wire    [ADDR_WIDTH     -1:0]       meta_base_addr_uv           ,
        input   wire    [16             -1:0]       tile_x_numbers              ,
        input   wire    [16             -1:0]       tile_y_numbers              ,
        input   wire                                i_cfg_is_lossy_rgba_2_1_format ,

    // AXI AR channel
        output  wire                                m_axi_arvalid               ,
        input   wire                                m_axi_arready               ,
        output  wire    [ADDR_WIDTH     -1:0]       m_axi_araddr                ,
        output  wire    [8              -1:0]       m_axi_arlen                 ,
        output  wire    [3              -1:0]       m_axi_arsize                ,
        output  wire    [2              -1:0]       m_axi_arburst               ,
        output  wire    [ID_WIDTH       -1:0]       m_axi_arid                  ,

    // AXI R channel
        input   wire                                m_axi_rvalid                ,
        output  wire                                m_axi_rready                ,
        input   wire    [AXI_DATA_WIDTH -1:0]       m_axi_rdata                 ,
        input   wire    [ID_WIDTH       -1:0]       m_axi_rid                   ,
        input   wire    [2              -1:0]       m_axi_rresp                 ,
        input   wire                                m_axi_rlast                 ,

    // Decoded metadata output
        output  wire                                o_dec_valid                 ,
        input   wire                                i_dec_ready                 ,
        output  wire    [5              -1:0]       o_dec_format                ,
        output  wire    [4              -1:0]       o_dec_flag                  ,
        output  wire    [3              -1:0]       o_dec_alen                  ,
        output  wire                                o_dec_has_payload           ,
        output  wire    [12             -1:0]       o_dec_x                     ,
        output  wire    [10             -1:0]       o_dec_y                     ,

        output  wire                                o_busy                      ,

    // Status outputs
        output  wire    [32             -1:0]       error_cnt                   ,
        output  wire    [32             -1:0]       cmd_ok_cnt                  ,
        output  wire    [32             -1:0]       cmd_fail_cnt
    );

    wire                                        meta_grp_valid             ;
    wire                                        meta_grp_ready             ;
    wire    [ADDR_WIDTH     -1:0]               meta_grp_addr              ;
    wire    [5              -1:0]               meta_format                ;
    wire    [12             -1:0]               meta_xcoord                ;
    wire    [10             -1:0]               meta_ycoord                ;
    wire                                        meta_data_valid            ;
    wire                                        meta_data_ready            ;
    wire    [8              -1:0]               meta_data                  ;
    wire    [5              -1:0]               meta_data_format           ;
    wire    [12             -1:0]               meta_data_xcoord           ;
    wire    [10             -1:0]               meta_data_ycoord           ;
    wire                                        tile_number_high_seen      ;

    assign tile_number_high_seen = (|tile_x_numbers[15:12]) | (|tile_y_numbers[15:10]);

    ubwc_enc_meta_get_cmd_gen #(
        .ADDR_WIDTH             ( ADDR_WIDTH                            ),
        .TW_DW                  ( 12                                    ),
        .TH_DW                  ( 10                                    )
    ) u_meta_get_cmd_gen (
        .clk                    ( clk                                   ),
        .rst_n                  ( rst_n                                 ),
        .start                  ( start                                 ),
        .base_format            ( base_format                           ),
        .meta_base_addr_rgba_y  ( meta_base_addr_rgba_y                 ),
        .meta_base_addr_uv      ( meta_base_addr_uv                     ),
        .tile_x_numbers         ( tile_x_numbers[11:0]                 ),
        .tile_y_numbers         ( tile_y_numbers[9:0]                  ),
        .meta_grp_valid         ( meta_grp_valid                        ),
        .meta_grp_ready         ( meta_grp_ready                        ),
        .meta_grp_addr          ( meta_grp_addr                         ),
        .meta_format            ( meta_format                           ),
        .meta_xcoord            ( meta_xcoord                           ),
        .meta_ycoord            ( meta_ycoord                           )
    );

    ubwc_dec_meta_axi_rcmd_gen #(
        .ADDR_WIDTH             ( ADDR_WIDTH                            ),
        .ID_WIDTH               ( ID_WIDTH                              ),
        .DATA_WIDTH             ( AXI_DATA_WIDTH                        ),
        .TW_DW                  ( 12                                    ),
        .TH_DW                  ( 10                                    )
    ) u_axi_rcmd_gen (
        .clk                    ( clk                                   ),
        .rst_n                  ( rst_n                                 ),
        .start                  ( start                                 ),
        .m_axi_arvalid          ( m_axi_arvalid                         ),
        .m_axi_arready          ( m_axi_arready                         ),
        .m_axi_araddr           ( m_axi_araddr                          ),
        .m_axi_arlen            ( m_axi_arlen                           ),
        .m_axi_arsize           ( m_axi_arsize                          ),
        .m_axi_arburst          ( m_axi_arburst                         ),
        .m_axi_arid             ( m_axi_arid                            ),
        .m_axi_rvalid           ( m_axi_rvalid                          ),
        .m_axi_rready           ( m_axi_rready                          ),
        .m_axi_rdata            ( m_axi_rdata                           ),
        .m_axi_rid              ( m_axi_rid                             ),
        .m_axi_rresp            ( m_axi_rresp                           ),
        .m_axi_rlast            ( m_axi_rlast                           ),
        .meta_grp_valid         ( meta_grp_valid                        ),
        .meta_grp_ready         ( meta_grp_ready                        ),
        .meta_grp_addr          ( meta_grp_addr                         ),
        .meta_format            ( meta_format                           ),
        .meta_xcoord            ( meta_xcoord                           ),
        .meta_ycoord            ( meta_ycoord                           ),
        .meta_data_valid        ( meta_data_valid                       ),
        .meta_data_ready        ( meta_data_ready                       ),
        .meta_data              ( meta_data                             ),
        .meta_data_format       ( meta_data_format                      ),
        .meta_data_xcoord       ( meta_data_xcoord                      ),
        .meta_data_ycoord       ( meta_data_ycoord                      ),
        .error_cnt              ( error_cnt                             ),
        .cmd_ok_cnt             ( cmd_ok_cnt                            ),
        .cmd_fail_cnt           ( cmd_fail_cnt                          )
    );

    ubwc_dec_meta_data_decode #(
        .FORCE_FULL_PAYLOAD     ( FORCE_FULL_PAYLOAD                    )
    ) u_decode_metadata (
        .i_cfg_is_lossy_rgba_2_1_format  ( i_cfg_is_lossy_rgba_2_1_format        ),
        .i_meta_valid           ( meta_data_valid                       ),
        .o_meta_ready           ( meta_data_ready                       ),
        .i_meta_format          ( meta_data_format                      ),
        .i_meta_data            ( meta_data                             ),
        .i_meta_x               ( meta_data_xcoord                      ),
        .i_meta_y               ( meta_data_ycoord                      ),
        .o_dec_valid            ( o_dec_valid                           ),
        .i_dec_ready            ( i_dec_ready                           ),
        .o_dec_format           ( o_dec_format                          ),
        .o_dec_flag             ( o_dec_flag                            ),
        .o_dec_alen             ( o_dec_alen                            ),
        .o_dec_has_payload      ( o_dec_has_payload                     ),
        .o_dec_x                ( o_dec_x                               ),
        .o_dec_y                ( o_dec_y                               )
    );

    assign o_busy = meta_grp_valid | m_axi_arvalid | m_axi_rvalid | meta_data_valid |
                    o_dec_valid | (tile_number_high_seen & 1'b0);

endmodule
