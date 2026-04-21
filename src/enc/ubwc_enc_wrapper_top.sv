//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-02-26  22:11:51
// Module Name       : ubwc_enc_wrapper_top.sv
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
//  
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module ubwc_enc_wrapper_top
    #(
        parameter   SB_WIDTH        = 1     ,
        parameter   APB_AW          = 16    ,
        parameter   APB_DW          = 32    ,
        parameter   APB_BLK_NREG    = 64    ,
        parameter   AXI_AW          = 64    ,
        parameter   AXI_DW          = 256   ,
        parameter   AXI_LENW        = 8     ,
        parameter   AXI_IDW         = 6     ,
        parameter   COM_BUF_AW      = 16    ,
        parameter   COM_BUF_DW      = 128
    )(
        input   wire                                PCLK                ,
        input   wire                                PRESETn             ,
        input   wire                                PSEL                ,
        input   wire                                PENABLE             ,
        input   wire    [APB_AW         -1:0]       PADDR               ,
        input   wire                                PWRITE              ,
        input   wire    [APB_DW         -1:0]       PWDATA              ,
        output  wire                                PREADY              ,
        output  wire                                PSLVERR             ,
        output  wire    [APB_DW         -1:0]       PRDATA              ,

    // clock/reset
        input   wire                                i_clk	            ,
        input   wire                                i_rstn              ,

    // OTF input
        input   wire                                i_otf_vsync         ,
        input   wire                                i_otf_hsync         ,
        input   wire                                i_otf_de            ,
        input   wire    [128            -1:0]       i_otf_data          ,
        input   wire    [  4            -1:0]       i_otf_fcnt          ,
        input   wire    [ 12            -1:0]       i_otf_lcnt          , 
        output  wire                                o_otf_ready         ,

    // SRAM bank0
        output  wire                                o_bank0_en          ,
        output  wire                                o_bank0_wen         ,
        output  wire    [COM_BUF_AW     -1:0]       o_bank0_addr        ,
        output  wire    [COM_BUF_DW     -1:0]       o_bank0_din         ,
        input   wire    [COM_BUF_DW     -1:0]       i_bank0_dout        ,
        input   wire                                i_bank0_dout_vld    ,
   
    // SRAM bank1
        output  wire                                o_bank1_en          ,
        output  wire                                o_bank1_wen         ,
        output  wire    [COM_BUF_AW     -1:0]       o_bank1_addr        ,
        output  wire    [COM_BUF_DW     -1:0]       o_bank1_din         ,
        input   wire    [COM_BUF_DW     -1:0]       i_bank1_dout        ,
        input   wire                                i_bank1_dout_vld    ,

    //AXI master interface        
        output  wire    [AXI_IDW          :0]       o_m_axi_awid        ,
        output  wire    [AXI_AW         -1:0]       o_m_axi_awaddr      ,
        output  wire    [AXI_LENW       -1:0]       o_m_axi_awlen       ,
        output  wire    [3              -1:0]       o_m_axi_awsize      ,
        output  wire    [2              -1:0]       o_m_axi_awburst     ,
        output  wire    [2              -1:0]       o_m_axi_awlock      ,
        output  wire    [4              -1:0]       o_m_axi_awcache     ,
        output  wire    [3              -1:0]       o_m_axi_awprot      ,
        output  wire                                o_m_axi_awvalid     ,
        input   wire                                i_m_axi_awready     ,

        output  wire    [AXI_DW         -1:0]       o_m_axi_wdata       ,
        output  wire    [AXI_DW/8       -1:0]       o_m_axi_wstrb       ,
        output  wire                                o_m_axi_wvalid      ,
        output  wire                                o_m_axi_wlast       ,
        input   wire                                i_m_axi_wready      ,

        input   wire    [AXI_IDW          :0]       i_m_axi_bid         ,
        input   wire    [2              -1:0]       i_m_axi_bresp       ,
        input   wire                                i_m_axi_bvalid      ,
        output  wire                                o_m_axi_bready
    );

    wire                                otf_cfg_vld                 ;
    wire                                otf_cfg_rdy                 ;
    wire    [3          -1:0]           otf_cfg_format              ;
    wire    [16         -1:0]           otf_cfg_width               ;
    wire    [16         -1:0]           otf_cfg_height              ;
    wire    [16         -1:0]           meta_active_width_px        ;
    wire    [16         -1:0]           meta_active_height_px       ;
    wire    [16         -1:0]           otf_cfg_tile_w              ;
    wire    [4          -1:0]           otf_cfg_tile_h              ;
    wire    [16         -1:0]           otf_cfg_a_tile_cols         ;          
    wire    [16         -1:0]           otf_cfg_b_tile_cols         ;          

    wire                                enc_ubwc_en			        ;
    wire                                enc_ci_valid		        ;
    wire                                enc_ci_cfg_vld_ahb         ;
    wire                                enc_ci_ready		        ;
    wire                                enc_ci_input_type	        ;
    wire    [3          -1:0]           enc_ci_alen			        ;
    wire    [5          -1:0]           enc_ci_format		        ;
    wire                                enc_ci_forced_pcm_cfg       ;
    wire                                enc_ci_forced_pcm_dyn       ;
    wire                                enc_ci_forced_pcm	        ;
    wire    [SB_WIDTH   -1:0]           enc_ci_sb			        ;
    wire                                enc_ci_lossy		        ;
    wire    [3          -1:0]           enc_ci_ubwc_cfg_0	        ;
    wire    [3          -1:0]           enc_ci_ubwc_cfg_1	        ;
    wire    [4          -1:0]           enc_ci_ubwc_cfg_2	        ;
    wire    [4          -1:0]           enc_ci_ubwc_cfg_3	        ;
    wire    [4          -1:0]           enc_ci_ubwc_cfg_4	        ;
    wire    [4          -1:0]           enc_ci_ubwc_cfg_5	        ;
    wire    [2          -1:0]           enc_ci_ubwc_cfg_6	        ;
    wire    [2          -1:0]           enc_ci_ubwc_cfg_7	        ;
    wire    [2          -1:0]           enc_ci_ubwc_cfg_8	        ;
    wire    [3          -1:0]           enc_ci_ubwc_cfg_9	        ;
    wire    [6          -1:0]           enc_ci_ubwc_cfg_10	        ;
    wire    [6          -1:0]           enc_ci_ubwc_cfg_11	        ;

    wire                                tile_addr_gen_cfg_vld       ;
    wire                                tile_addr_gen_cfg_rdy       ;
    wire                                lvl1_bank_swizzle_en        ;
    wire                                lvl2_bank_swizzle_en        ;
    wire                                lvl3_bank_swizzle_en        ;
    wire    [5          -1:0]           highest_bank_bit            ;
    wire                                bank_spread_en              ;
    wire                                four_line_format            ;
    wire                                is_lossy_rgba_2_1_format    ;
    wire    [12         -1:0]           pitch                       ;
    wire    [64         -1:0]           y_base_offset_addr          ;
    wire    [64         -1:0]           uv_base_offset_addr         ;
    wire    [64         -1:0]           meta_y_base_offset_addr     ;
    wire    [64         -1:0]           meta_uv_base_offset_addr    ;

    wire                                otf_to_tile_busy		    ;
    wire                                otf_to_tile_overflow        ;

    wire                                meta_cfg_vld                ;
    wire                                meta_cfg_rdy                ;
    wire    [5          -1:0]           meta_cfg_format             ;
    wire    [3          -1:0]           meta_cfg_alen               ;
    wire    [SB_WIDTH   -1:0]           meta_cfg_sb                 ;
    wire                                meta_cfg_pcm                ;

    wire                                rvi_valid				    ;
    wire                                rvi_last                    ;
    wire                                rvi_ready				    ;
	wire	[256        -1:0]           rvi_data				    ;
	wire	[ 32        -1:0]           rvi_mask				    ;
    wire    [4          -1:0]           tile_fcnt                   ;
    localparam integer                  COORD_FIFO_DEPTH            = 32;
    localparam integer                  COORD_FIFO_W                = 5 + 4 + 13 + 28;
    wire                                b_tile_info_vld            ;
    wire    [5          -1:0]           b_tile_format              ;
    wire    [4          -1:0]           b_tile_fcnt                ;
    wire    [13         -1:0]           b_tile_ycoord              ;
    wire    [28         -1:0]           b_tile_xcoord              ;
    wire                                b_co_valid                 ;
    wire                                b_co_fire                  ;

    wire                                tile_coord_vld              ;
    wire                                tile_coord_rdy              ;
    wire    [5          -1:0]           tile_format                 ;
    wire    [16         -1:0]           tile_ycoord_raw             ;
    wire    [16         -1:0]           tile_xcoord_raw             ;
    wire    [13         -1:0]           tile_ycoord                 ;
    wire    [28         -1:0]           tile_xcoord                 ;

    wire    [28         -1:0]           tile_addr                   ;
    wire    [3          -1:0]           tile_alen                   ;
    wire                                tile_addr_vld               ;

    wire                                enc_co_valid                ;
    wire                                enc_co_ready                ;
    wire    [3          -1:0]           enc_co_alen                 ;
    wire    [SB_WIDTH   -1:0]           enc_co_sb                   ;
    wire                                enc_co_pcm                  ;
    
    wire                                enc_cvo_valid               ;
    wire                                enc_cvo_ready               ;
    wire    [256        -1:0]           enc_cvo_data                ;
    wire    [32         -1:0]           enc_cvo_mask                ;
    wire                                enc_cvo_last                ;
    wire                                meta_force_flush            ;
    
    wire                                enc_idle                    ;
    wire                                enc_error                   ;

    wire                                y_meta_valid                ;
    wire                                y_meta_last                 ;
    wire                                y_meta_ready                ;
    wire    [ 64        -1:0]           y_meta_data                 ;
    wire    [AXI_AW     -1:0]           y_meta_addr                 ;
    wire                                uv_meta_valid               ;
    wire                                uv_meta_last                ;
    wire                                uv_meta_ready               ;
    wire    [ 64        -1:0]           uv_meta_data                ;
    wire    [AXI_AW     -1:0]           uv_meta_addr                ;
    wire                                meta_valid                  ;
    wire                                meta_last                   ;
    wire                                meta_ready                  ;
    wire    [ 64        -1:0]           meta_data                   ;
    wire    [AXI_AW     -1:0]           meta_addr                   ;
    reg                                 meta_pkt_active             ;
    reg                                 meta_pkt_sel_uv             ;
    wire                                meta_sel_uv                 ;
    wire                                meta_sel_y                  ;

    wire                                tile_addr_co_ready          ;
    wire    [16         -1:0]           pic_tile_cols               ;
    wire    [16         -1:0]           pic_tile_rows               ;
    wire    [ 8         -1:0]           total_x_units               ;
    wire    [28         -1:0]           tile_x_numbers              ;
    wire    [13         -1:0]           tile_y_numbers              ;
    wire    [28         -1:0]           meta_active_tile_x_numbers  ;
    wire    [13         -1:0]           meta_active_tile_y_numbers  ;
    wire                                dual_plane_mode             ;
    wire    [28         -1:0]           y_surface_tile_x_numbers    ;
    wire    [28         -1:0]           uv_surface_tile_x_numbers   ;
    wire    [8          -1:0]           y_surface_total_x_units     ;
    wire    [8          -1:0]           uv_surface_total_x_units    ;
    wire                                meta_active_width_override  ;
    wire    [28         -1:0]           y_surface_active_tile_x_numbers;
    wire    [28         -1:0]           uv_surface_active_tile_x_numbers;
    wire    [55         -1:0]           uv_active_tile_cols_scaled  ;

    wire                                err_bline                   ;
    wire                                err_bframe                  ;
    wire                                err_fifo_ovf                ;
    wire                                rst                         ;
    wire                                srst                        ;

    wire    [AXI_IDW    -1: 0]          enc_axi_awid                ;
    wire    [AXI_AW     -1: 0]          enc_axi_awaddr              ;
    wire    [AXI_LENW   -1: 0]          enc_axi_awlen               ;
    wire    [3          -1: 0]          enc_axi_awsize              ;
    wire    [2          -1: 0]          enc_axi_awburst             ;
    wire    [2          -1: 0]          enc_axi_awlock              ;
    wire    [4          -1: 0]          enc_axi_awcache             ;
    wire    [3          -1: 0]          enc_axi_awprot              ;
    wire                                enc_axi_awvalid             ;
    wire                                enc_axi_awready             ;
    wire    [AXI_IDW    -1: 0]          enc_axi_wid                 ;
    wire    [AXI_DW     -1: 0]          enc_axi_wdata               ;
    wire    [AXI_DW/8   -1: 0]          enc_axi_wstrb               ;
    wire                                enc_axi_wlast               ;
    wire                                enc_axi_wvalid              ;
    wire                                enc_axi_wready              ;
    wire    [AXI_IDW    -1: 0]          enc_axi_bid                 ;
    wire    [2          -1: 0]          enc_axi_bresp               ;
    wire                                enc_axi_bvalid              ;
    wire                                enc_axi_bready              ;

    wire    [AXI_IDW    -1: 0]          meta_axi_awid               ;
    wire    [AXI_AW     -1: 0]          meta_axi_awaddr             ;
    wire    [AXI_LENW   -1: 0]          meta_axi_awlen              ;
    wire    [3          -1: 0]          meta_axi_awsize             ;
    wire    [2          -1: 0]          meta_axi_awburst            ;
    wire    [2          -1: 0]          meta_axi_awlock             ;
    wire    [4          -1: 0]          meta_axi_awcache            ;
    wire    [3          -1: 0]          meta_axi_awprot             ;
    wire                                meta_axi_awvalid            ;
    wire                                meta_axi_awready            ;
    wire    [AXI_IDW    -1: 0]          meta_axi_wid                ;
    wire    [AXI_DW     -1: 0]          meta_axi_wdata              ;
    wire    [AXI_DW/8   -1: 0]          meta_axi_wstrb              ;
    wire                                meta_axi_wlast              ;
    wire                                meta_axi_wvalid             ;
    wire                                meta_axi_wready             ;
    wire    [AXI_IDW    -1: 0]          meta_axi_bid                ;
    wire    [2          -1: 0]          meta_axi_bresp              ;
    wire                                meta_axi_bvalid             ;
    wire                                meta_axi_bready             ;

    wire    [AXI_IDW      :0]           dbg_awid_s0                 ;
    wire    [AXI_AW     -1:0]           dbg_awaddr_s0               ;
    wire    [AXI_LENW   -1:0]           dbg_awlen_s0                ;
    wire    [3          -1:0]           dbg_awsize_s0               ;
    wire    [2          -1:0]           dbg_awburst_s0              ;
    wire    [2          -1:0]           dbg_awlock_s0               ;
    wire    [4          -1:0]           dbg_awcache_s0              ;
    wire    [3          -1:0]           dbg_awprot_s0               ;
    wire                                dbg_awvalid_s0              ;
    wire                                dbg_awready_s0              ;
    wire    [AXI_IDW      :0]           dbg_wid_s0                  ;
    wire    [AXI_DW     -1:0]           dbg_wdata_s0                ;
    wire    [AXI_DW/8   -1:0]           dbg_wstrb_s0                ;
    wire                                dbg_wlast_s0                ;
    wire                                dbg_wvalid_s0               ;
    wire                                dbg_wready_s0               ;
    wire    [AXI_IDW      :0]           dbg_bid_s0                  ;
    wire    [2          -1:0]           dbg_bresp_s0                ;
    wire                                dbg_bvalid_s0               ;
    wire                                dbg_bready_s0               ;
    wire    [AXI_IDW      :0]           dbg_arid_s0                 ;
    wire    [AXI_AW     -1:0]           dbg_araddr_s0               ;
    wire    [AXI_LENW   -1:0]           dbg_arlen_s0                ;
    wire    [3          -1:0]           dbg_arsize_s0               ;
    wire    [2          -1:0]           dbg_arburst_s0              ;
    wire    [2          -1:0]           dbg_arlock_s0               ;
    wire    [4          -1:0]           dbg_arcache_s0              ;
    wire    [3          -1:0]           dbg_arprot_s0               ;
    wire                                dbg_arvalid_s0              ;
    wire                                dbg_arready_s0              ;
    wire    [AXI_IDW      :0]           dbg_rid_s0                  ;
    wire    [AXI_DW     -1:0]           dbg_rdata_s0                ;
    wire    [2          -1:0]           dbg_rresp_s0                ;
    wire                                dbg_rvalid_s0               ;
    wire                                dbg_rlast_s0                ;
    wire                                dbg_rready_s0               ;
    assign otf_cfg_rdy       = 1'b1;
    assign tile_coord_vld    = enc_ci_valid & enc_ci_ready;
    assign tile_coord_rdy    = enc_ci_ready;
    assign tile_xcoord       = {{12{1'b0}}, tile_xcoord_raw};
    assign tile_ycoord       = tile_ycoord_raw[12:0];
    assign enc_ci_format     = tile_format;
    assign b_co_valid        = b_tile_info_vld;
    assign b_co_fire         = b_tile_info_vld & enc_co_ready;
    assign otf_to_tile_busy  = rvi_valid;
    assign otf_to_tile_overflow = err_fifo_ovf;
    assign meta_force_flush  = 1'b0;
    assign dual_plane_mode   = (otf_cfg_b_tile_cols != 16'd0);
    assign y_surface_tile_x_numbers  = dual_plane_mode ? {{12{1'b0}}, otf_cfg_b_tile_cols} : tile_x_numbers;
    assign uv_surface_tile_x_numbers = dual_plane_mode ? {{12{1'b0}}, otf_cfg_a_tile_cols} : tile_x_numbers;
    assign y_surface_total_x_units   = (y_surface_tile_x_numbers[15:0]  + 16'd15) >> 4;
    assign uv_surface_total_x_units  = (uv_surface_tile_x_numbers[15:0] + 16'd15) >> 4;
    assign meta_active_width_override = dual_plane_mode && (meta_active_tile_x_numbers != tile_x_numbers);
    assign y_surface_active_tile_x_numbers =
        meta_active_width_override ? meta_active_tile_x_numbers : y_surface_tile_x_numbers;
    assign uv_active_tile_cols_scaled =
        ({28'd0, meta_active_tile_x_numbers} * {28'd0, uv_surface_tile_x_numbers}) +
        {28'd0, y_surface_tile_x_numbers} - 56'd1;
    assign uv_surface_active_tile_x_numbers =
        meta_active_width_override ? (uv_active_tile_cols_scaled / y_surface_tile_x_numbers)
                                   : uv_surface_tile_x_numbers;

    ubwc_enc_rst_mdl ubwc_enc_rst_mdl_inst 
    (
        .i_clk                      ( i_clk                         ),
        .i_rstn                     ( i_rstn                        ),

        .o_rst                      ( rst                           ),
        .o_srst                     ( srst                          )
    );

    ubwc_enc_apb_reg_blk
    #(
        .AW                         ( APB_AW                        ),
        .DW                         ( APB_DW                        ),
        .NREG                       ( APB_BLK_NREG                  ),
        .SB_WIDTH                   ( SB_WIDTH                      )
    )
    ubwc_enc_apb_reg_blk
    (
        .PCLK				        ( PCLK				            ),
        .PRESETn				    ( PRESETn				        ),
        .PSEL				        ( PSEL				            ),
        .PENABLE				    ( PENABLE				        ),
        .PADDR				        ( PADDR				            ),
        .PWRITE				        ( PWRITE				        ),
        .PWDATA				        ( PWDATA				        ),
        .PREADY				        ( PREADY				        ),
        .PSLVERR				    ( PSLVERR				        ),
        .PRDATA				        ( PRDATA				        ),

        .o_otf_cfg_vld				( otf_cfg_vld				    ),
        .i_otf_cfg_rdy				( otf_cfg_rdy				    ),
        .o_otf_cfg_format			( otf_cfg_format			    ),
        .o_otf_cfg_width            ( otf_cfg_width                 ),
        .o_otf_cfg_height           ( otf_cfg_height                ),
        .o_meta_active_width_px     ( meta_active_width_px          ),
        .o_meta_active_height_px    ( meta_active_height_px         ),
        .o_otf_cfg_tile_w           ( otf_cfg_tile_w                ),
        .o_otf_cfg_tile_h           ( otf_cfg_tile_h                ),
        .o_otf_cfg_a_tile_cols      ( otf_cfg_a_tile_cols           ),          
        .o_otf_cfg_b_tile_cols      ( otf_cfg_b_tile_cols           ),          
        .o_pic_tile_cols            ( pic_tile_cols                 ),
        .o_pic_tile_rows            ( pic_tile_rows                 ),
        .o_total_x_units            ( total_x_units                 ),
        .o_tile_x_numbers           ( tile_x_numbers                ),
        .o_tile_y_numbers           ( tile_y_numbers                ),
        .o_meta_active_tile_x_numbers ( meta_active_tile_x_numbers  ),
        .o_meta_active_tile_y_numbers ( meta_active_tile_y_numbers  ),

        .o_enc_ubwc_en				( enc_ubwc_en				    ),
        .o_enc_ci_vld				( enc_ci_cfg_vld_ahb            ),
        .i_enc_ci_rdy				( 1'b1                          ),
        .o_enc_ci_alen              ( enc_ci_alen                   ),
        .o_enc_ci_input_type		( enc_ci_input_type		        ),
        .o_enc_ci_forced_pcm		( enc_ci_forced_pcm_cfg        ),
        .o_enc_ci_sb				( enc_ci_sb				        ),
        .o_enc_ci_lossy				( enc_ci_lossy			        ),
        .o_enc_ci_ubwc_cfg_0		( enc_ci_ubwc_cfg_0		        ),
        .o_enc_ci_ubwc_cfg_1		( enc_ci_ubwc_cfg_1		        ),
        .o_enc_ci_ubwc_cfg_2		( enc_ci_ubwc_cfg_2		        ),
        .o_enc_ci_ubwc_cfg_3		( enc_ci_ubwc_cfg_3		        ),
        .o_enc_ci_ubwc_cfg_4		( enc_ci_ubwc_cfg_4		        ),
        .o_enc_ci_ubwc_cfg_5		( enc_ci_ubwc_cfg_5		        ),
        .o_enc_ci_ubwc_cfg_6		( enc_ci_ubwc_cfg_6		        ),
        .o_enc_ci_ubwc_cfg_7		( enc_ci_ubwc_cfg_7		        ),
        .o_enc_ci_ubwc_cfg_8		( enc_ci_ubwc_cfg_8		        ),
        .o_enc_ci_ubwc_cfg_9		( enc_ci_ubwc_cfg_9		        ),
        .o_enc_ci_ubwc_cfg_10		( enc_ci_ubwc_cfg_10		    ),
        .o_enc_ci_ubwc_cfg_11		( enc_ci_ubwc_cfg_11		    ),

        .i_enc_idle                 ( enc_idle                      ),
        .i_enc_error                ( enc_error                     ),

        .o_tile_addr_gen_cfg_vld    ( tile_addr_gen_cfg_vld         ),
        .i_tile_addr_gen_cfg_rdy    ( tile_addr_gen_cfg_rdy         ),
        .o_lvl1_bank_swizzle_en		( lvl1_bank_swizzle_en	        ),
        .o_lvl2_bank_swizzle_en		( lvl2_bank_swizzle_en	        ),
        .o_lvl3_bank_swizzle_en		( lvl3_bank_swizzle_en	        ),
        .o_highest_bank_bit			( highest_bank_bit		        ),
        .o_bank_spread_en           ( bank_spread_en                ),
        .o_4line_format             ( four_line_format              ),
        .o_is_lossy_rgba_2_1_format ( is_lossy_rgba_2_1_format      ),
        .o_pitch                    ( pitch                         ),
        .o_y_base_offset_addr       ( y_base_offset_addr            ),
        .o_uv_base_offset_addr      ( uv_base_offset_addr           ),
        .o_meta_y_base_offset_addr  ( meta_y_base_offset_addr       ),
        .o_meta_uv_base_offset_addr ( meta_uv_base_offset_addr      ),

        .i_otf_to_tile_busy			( otf_to_tile_busy				),
        .i_otf_to_tile_overflow     ( otf_to_tile_overflow          )
    );

    ubwc_enc_otf_to_tile
    #(
        .ADDR_W                     ( COM_BUF_AW                    )
    )
    ubwc_enc_otf_to_tile_inst
    (
        .clk						( i_clk						    ),
        .rst_n						( i_rstn						),

        .i_cfg_format				( otf_cfg_format				),
        .i_cfg_width                ( otf_cfg_width                 ),
        .i_cfg_height               ( otf_cfg_height                ),
        .i_cfg_active_width         ( meta_active_width_px          ),
        .i_cfg_active_height        ( meta_active_height_px         ),
        .i_cfg_tile_w               ( otf_cfg_tile_w                ),
        .i_cfg_tile_h               ( otf_cfg_tile_h                ),
        .i_cfg_a_tile_cols          ( otf_cfg_a_tile_cols           ),          
        .i_cfg_b_tile_cols          ( otf_cfg_b_tile_cols           ),          

        .o_err_bline			    ( err_bline					    ),
        .o_err_bframe				( err_bframe				    ),
        .o_err_fifo_ovf				( err_fifo_ovf				    ),

        .i_otf_vsync				( i_otf_vsync					),
        .i_otf_hsync				( i_otf_hsync					),
        .i_otf_de					( i_otf_de					    ),
        .i_otf_data					( i_otf_data					),
        .i_otf_fcnt					( i_otf_fcnt					),
        .i_otf_lcnt					( i_otf_lcnt					),
        .o_otf_ready				( o_otf_ready					),

        .o_bank0_en                 ( o_bank0_en                    ),
        .o_bank0_wen                ( o_bank0_wen                   ),
        .o_bank0_addr               ( o_bank0_addr                  ),
        .o_bank0_din                ( o_bank0_din                   ),
        .i_bank0_dout               ( i_bank0_dout                  ),
        .i_bank0_dout_vld           ( i_bank0_dout_vld              ),

        .o_bank1_en                 ( o_bank1_en                    ),
        .o_bank1_wen                ( o_bank1_wen                   ),
        .o_bank1_addr               ( o_bank1_addr                  ),
        .o_bank1_din                ( o_bank1_din                   ),
        .i_bank1_dout               ( i_bank1_dout                  ),
        .i_bank1_dout_vld           ( i_bank1_dout_vld              ),

        .o_tile_vld					( rvi_valid                     ),
        .i_tile_rdy					( rvi_ready                     ),
        .o_tile_data				( rvi_data                      ),
        .o_tile_keep				( rvi_mask                      ),
        .o_tile_last				( rvi_last                      ),

        .o_ci_valid		            ( enc_ci_valid		            ),
        .i_ci_ready		            ( enc_ci_ready		            ),
        .o_ci_forced_pcm            ( enc_ci_forced_pcm_dyn         ),
        .o_tile_x					( tile_xcoord_raw               ),
        .o_tile_y					( tile_ycoord_raw               ),
        .o_tile_fcnt                ( tile_fcnt                     ),
        .o_tile_format	            ( tile_format	                )
    );

    assign enc_ci_forced_pcm = enc_ci_forced_pcm_cfg | enc_ci_forced_pcm_dyn;

    ubwc_sync_fifo_fwft #(
        .DATA_WIDTH (COORD_FIFO_W),
        .DEPTH      (COORD_FIFO_DEPTH)
    ) u_coord_fifo (
        .clk          (i_clk),
        .rstn         (i_rstn),
        .i_push_valid (tile_coord_vld),
        .o_push_ready (),
        .i_push_data  ({tile_format,tile_fcnt, tile_ycoord, tile_xcoord}),
        .o_pop_valid  (b_tile_info_vld),
        .i_pop_ready  (enc_co_valid && enc_co_ready),
        .o_pop_data   ({b_tile_format,b_tile_fcnt, b_tile_ycoord, b_tile_xcoord})
    );

    ubwc_enc_vivo_top
    #(
        .SB_WIDTH                   ( SB_WIDTH                      )
    )
    ubwc_enc_vivo_top_inst
    (
        .i_clk                      ( i_clk                         ),

        .i_reset                    ( rst                           ),
        .i_sreset                   ( srst                          ),

        .i_ubwc_en                  ( enc_ubwc_en                   ),
        .i_ci_alen		            ( enc_ci_alen		            ),
        .i_ci_input_type            ( enc_ci_input_type             ),
        .i_ci_forced_pcm            ( enc_ci_forced_pcm             ),
        .i_ci_lossy		            ( enc_ci_lossy		            ),
        .i_ci_sb		            ( enc_ci_sb		                ),
        .i_ci_ubwc_cfg_0            ( enc_ci_ubwc_cfg_0             ),
        .i_ci_ubwc_cfg_1            ( enc_ci_ubwc_cfg_1             ),
        .i_ci_ubwc_cfg_2            ( enc_ci_ubwc_cfg_2             ),
        .i_ci_ubwc_cfg_3            ( enc_ci_ubwc_cfg_3             ),
        .i_ci_ubwc_cfg_4            ( enc_ci_ubwc_cfg_4             ),
        .i_ci_ubwc_cfg_5            ( enc_ci_ubwc_cfg_5             ),
        .i_ci_ubwc_cfg_6            ( enc_ci_ubwc_cfg_6             ),
        .i_ci_ubwc_cfg_7            ( enc_ci_ubwc_cfg_7             ),
        .i_ci_ubwc_cfg_8            ( enc_ci_ubwc_cfg_8             ),
        .i_ci_ubwc_cfg_9            ( enc_ci_ubwc_cfg_9             ),
        .i_ci_ubwc_cfg_10           ( enc_ci_ubwc_cfg_10            ),
        .i_ci_ubwc_cfg_11           ( enc_ci_ubwc_cfg_11            ),

        .i_ci_valid		            ( enc_ci_valid		            ),
        .o_ci_ready		            ( enc_ci_ready		            ),
        .i_ci_format	            ( enc_ci_format	                ),

        .i_rvi_valid	            ( rvi_valid	                    ),
        .o_rvi_ready	            ( rvi_ready	                    ),
        .i_rvi_data		            ( rvi_data		                ),
        .i_rvi_mask		            ( rvi_mask		                ),

        .o_co_valid		            ( enc_co_valid		            ),
        .i_co_ready		            ( enc_co_ready		            ),
        .o_co_alen		            ( enc_co_alen		            ),
        .o_co_sb		            ( enc_co_sb		                ),
        .o_co_pcm		            ( enc_co_pcm		            ),

        .o_cvo_valid	            ( enc_cvo_valid	                ),
        .i_cvo_ready	            ( enc_cvo_ready	                ),
        .o_cvo_data		            ( enc_cvo_data		            ),
        .o_cvo_mask		            ( enc_cvo_mask		            ),
        .o_cvo_last		            ( enc_cvo_last		            ),

        .o_idle			            ( enc_idle			            ),
        .o_error                    ( enc_error                     )
    );


    ubwc_enc_tile_addr ubwc_tile_addr_inst
    (
        .i_clk                      ( i_clk                         ),
        .i_rstn                     ( i_rstn                        ),

        .i_tile_addr_gen_cfg_vld    ( tile_addr_gen_cfg_vld         ),
        .o_tile_addr_gen_cfg_rdy    ( tile_addr_gen_cfg_rdy         ),
        .i_lvl1_bank_swizzle_en		( lvl1_bank_swizzle_en	        ),
        .i_lvl2_bank_swizzle_en		( lvl2_bank_swizzle_en	        ),
        .i_lvl3_bank_swizzle_en		( lvl3_bank_swizzle_en	        ),
        .i_highest_bank_bit			( highest_bank_bit		        ),
        .i_bank_spread_en           ( bank_spread_en                ),
        .i_4line_format             ( four_line_format              ),
        .i_is_lossy_rgba_2_1_format ( is_lossy_rgba_2_1_format      ),
        .i_pitch                    ( pitch                         ),
        .i_y_base_offset_addr       ( y_base_offset_addr            ),
        .i_uv_base_offset_addr      ( uv_base_offset_addr           ),

        .i_co_valid                 ( enc_co_valid                  ),
        .o_co_ready                 ( enc_co_ready                  ),
        .i_co_alen                  ( enc_co_alen		            ),
        .i_co_sb                    ( enc_co_sb		                ),
        .i_co_pcm                   ( enc_co_pcm		            ),
        .i_format                   ( b_tile_format                 ),
        .i_ycoord                   ( b_tile_ycoord                 ),
        .i_xcoord                   ( b_tile_xcoord                 ),

        .o_tile_alen                ( tile_alen                     ),
        .o_tile_addr_vld            ( tile_addr_vld                 ),
        .o_tile_addr                ( tile_addr                     )
    );

    ubwc_enc_meta_addr_gen
    #(
        .SB_WIDTH                   ( SB_WIDTH                      ),
        .META_AW                    ( AXI_AW                        )
    )
    ubwc_enc_meta_addr_gen_inst
    (
        .i_clk                      ( i_clk                         ),
        .i_rstn                     ( i_rstn                        ),

        .i_meta_data_plane_pitch    ( {20'd0, pitch}                ),
        .i_total_x_units            ( total_x_units                 ),
        .i_pic_width_tiles          ( tile_x_numbers                ),
        .i_pic_height_tiles         ( tile_y_numbers                ),
        .i_active_pic_width_tiles   ( meta_active_tile_x_numbers    ),
        .i_active_pic_height_tiles  ( meta_active_tile_y_numbers    ),

        .i_meta_y_base_offset_addr  ( meta_y_base_offset_addr       ),
        .i_meta_uv_base_offset_addr ( meta_uv_base_offset_addr      ),
        .i_force_flush              ( meta_force_flush              ),

        .i_co_valid                 ( enc_co_valid                  ),
        .i_co_alen                  ( enc_co_alen                   ),
        .i_co_sb                    ( enc_co_sb                     ),
        .i_co_pcm                   ( enc_co_pcm                    ),
        .i_format                   ( b_tile_format                 ),
        .i_ycoord                   ( b_tile_ycoord                 ),
        .i_xcoord                   ( b_tile_xcoord                 ),

        .o_meta_valid               ( meta_valid                    ),
        .o_meta_last                ( meta_last                     ),
        .i_meta_ready               ( meta_ready                    ),
        .o_meta_data                ( meta_data                     ),
        .o_meta_addr                ( meta_addr                     ),

        .o_frame_done               (                               )
    );

    ubwc_tile_enc_axi_wcmd_gen
    #(
        .AXI_AW                     ( AXI_AW                        ),
        .AXI_DW                     ( AXI_DW                        ),
        .AXI_LENW                   ( AXI_LENW                      ),
        .AXI_IDW                    ( AXI_IDW                       )
    )
    ubwc_tile_enc_axi_wcmd_gen_inst
    (
        .i_aclk                     ( i_clk                         ),
        .i_aresetn                  ( i_rstn                        ),

        .i_tile_addr                ( tile_addr                     ),
        .i_tile_alen                ( tile_alen                     ),
        .i_tile_addr_vld            ( tile_addr_vld                 ),

        .i_cvo_valid	            ( enc_cvo_valid	                ),
        .o_cvo_ready	            ( enc_cvo_ready	                ),
        .i_cvo_data		            ( enc_cvo_data		            ),
        .i_cvo_mask		            ( enc_cvo_mask		            ),
        .i_cvo_last		            ( enc_cvo_last		            ),

        .o_m_axi_awid               ( enc_axi_awid                  ),
        .o_m_axi_awaddr             ( enc_axi_awaddr                ),
        .o_m_axi_awlen              ( enc_axi_awlen                 ),
        .o_m_axi_awsize             ( enc_axi_awsize                ),
        .o_m_axi_awburst            ( enc_axi_awburst               ),
        .o_m_axi_awlock             ( enc_axi_awlock                ),
        .o_m_axi_awcache            ( enc_axi_awcache               ),
        .o_m_axi_awprot             ( enc_axi_awprot                ),
        .o_m_axi_awvalid            ( enc_axi_awvalid               ),
        .i_m_axi_awready            ( enc_axi_awready               ),

        .o_m_axi_wdata              ( enc_axi_wdata                 ),
        .o_m_axi_wstrb              ( enc_axi_wstrb                 ),
        .o_m_axi_wvalid             ( enc_axi_wvalid                ),
        .o_m_axi_wlast              ( enc_axi_wlast                 ),
        .i_m_axi_wready             ( enc_axi_wready                ),

        .i_m_axi_bid                ( enc_axi_bid                   ),
        .i_m_axi_bresp              ( enc_axi_bresp                 ),
        .i_m_axi_bvalid             ( enc_axi_bvalid                ),
        .o_m_axi_bready             ( enc_axi_bready                )
    );

    ubwc_enc_meta_axi_wcmd_gen_v2
    #(
        .AXI_AW                     ( AXI_AW                        ),
        .AXI_DW                     ( AXI_DW                        ),
        .AXI_LENW                   ( AXI_LENW                      ),
        .AXI_IDW                    ( AXI_IDW                       )
    )
    ubwc_enc_meta_axi_wcmd_gen_inst
    (
        .i_aclk                     ( i_clk                         ),
        .i_aresetn                  ( i_rstn                        ),

        .i_meta_valid               ( meta_valid                    ),
        .i_meta_last                ( meta_last                     ),
        .o_meta_ready               ( meta_ready                    ),
        .i_meta_addr                ( meta_addr                     ),
        .i_meta_data                ( meta_data                     ),

        .o_m_axi_awid               ( meta_axi_awid                 ),
        .o_m_axi_awaddr             ( meta_axi_awaddr               ),
        .o_m_axi_awlen              ( meta_axi_awlen                ),
        .o_m_axi_awsize             ( meta_axi_awsize               ),
        .o_m_axi_awburst            ( meta_axi_awburst              ),
        .o_m_axi_awlock             ( meta_axi_awlock               ),
        .o_m_axi_awcache            ( meta_axi_awcache              ),
        .o_m_axi_awprot             ( meta_axi_awprot               ),
        .o_m_axi_awvalid            ( meta_axi_awvalid              ),
        .i_m_axi_awready            ( meta_axi_awready              ),

        .o_m_axi_wdata              ( meta_axi_wdata                ),
        .o_m_axi_wstrb              ( meta_axi_wstrb                ),
        .o_m_axi_wvalid             ( meta_axi_wvalid               ),
        .o_m_axi_wlast              ( meta_axi_wlast                ),
        .i_m_axi_wready             ( meta_axi_wready               ),

        .i_m_axi_bid                ( meta_axi_bid                  ),
        .i_m_axi_bresp              ( meta_axi_bresp                ),
        .i_m_axi_bvalid             ( meta_axi_bvalid               ),
        .o_m_axi_bready             ( meta_axi_bready               )
    );

    axi_2t1_int_DW_axi
    #(
        .AXI_AW                     ( AXI_AW                        ),
        .AXI_DW                     ( AXI_DW                        ),
        .AXI_LENW                   ( AXI_LENW                      ),
        .AXI_IDW                    ( AXI_IDW                       )
    )
    axi_2t1_int_DW_axi_inst
    (
        .aclk                       ( i_clk                         ),
        .aresetn                    ( i_rstn                        ),

        .awvalid_m1				    ( enc_axi_awvalid			    ),
        .awaddr_m1				    ( enc_axi_awaddr			    ),
        .awid_m1				    ( enc_axi_awid				    ),
        .awlen_m1				    ( enc_axi_awlen				    ),
        .awsize_m1				    ( enc_axi_awsize			    ),
        .awburst_m1				    ( enc_axi_awburst			    ),
        .awlock_m1				    ( enc_axi_awlock			    ),
        .awcache_m1				    ( enc_axi_awcache			    ),
        .awprot_m1				    ( enc_axi_awprot			    ),
        .awready_m1				    ( enc_axi_awready			    ),
        .wvalid_m1				    ( enc_axi_wvalid			    ),
        .wdata_m1				    ( enc_axi_wdata				    ),
        .wstrb_m1				    ( enc_axi_wstrb				    ),
        .wlast_m1				    ( enc_axi_wlast				    ),
        .wready_m1				    ( enc_axi_wready			    ),
        .bvalid_m1				    ( enc_axi_bvalid			    ),
        .bid_m1				        ( enc_axi_bid				    ),
        .bresp_m1				    ( enc_axi_bresp				    ),
        .bready_m1				    ( enc_axi_bready			    ),

        .arvalid_m1				    ( 1'b0                          ),
        .arid_m1				    ( {AXI_IDW {1'b0}}              ),
        .araddr_m1				    ( {AXI_AW  {1'b0}}              ),
        .arlen_m1				    ( {AXI_LENW{1'b0}}              ),
        .arsize_m1				    ( {3       {1'b0}}              ),
        .arburst_m1				    ( {2       {1'b0}}              ),
        .arlock_m1				    ( {2       {1'b0}}              ),
        .arcache_m1				    ( {4       {1'b0}}              ),
        .arprot_m1				    ( {3       {1'b0}}              ),
        .arready_m1				    ( 			                    ),
        .rvalid_m1				    (                               ),
        .rid_m1				        (                               ),
        .rdata_m1				    (                               ),
        .rresp_m1				    (                               ),
        .rlast_m1				    (                               ),
        .rready_m1				    ( 1'b1			                ),

        .awvalid_m2				    ( meta_axi_awvalid			    ),
        .awaddr_m2				    ( meta_axi_awaddr			    ),
        .awid_m2				    ( meta_axi_awid				    ),
        .awlen_m2				    ( meta_axi_awlen			    ),
        .awsize_m2				    ( meta_axi_awsize			    ),
        .awburst_m2				    ( meta_axi_awburst			    ),
        .awlock_m2				    ( meta_axi_awlock			    ),
        .awcache_m2				    ( meta_axi_awcache			    ),
        .awprot_m2				    ( meta_axi_awprot			    ),
        .awready_m2				    ( meta_axi_awready			    ),
        .wvalid_m2				    ( meta_axi_wvalid			    ),
        .wdata_m2				    ( meta_axi_wdata			    ),
        .wstrb_m2				    ( meta_axi_wstrb			    ),
        .wlast_m2				    ( meta_axi_wlast			    ),
        .wready_m2				    ( meta_axi_wready			    ),
        .bvalid_m2				    ( meta_axi_bvalid			    ),
        .bid_m2				        ( meta_axi_bid				    ),
        .bresp_m2				    ( meta_axi_bresp			    ),
        .bready_m2				    ( meta_axi_bready			    ),
        .arvalid_m2				    ( 1'b0                          ),
        .arid_m2				    ( {AXI_IDW {1'b0}}              ),
        .araddr_m2				    ( {AXI_AW  {1'b0}}              ),
        .arlen_m2				    ( {AXI_LENW{1'b0}}              ),
        .arsize_m2				    ( {3       {1'b0}}              ),
        .arburst_m2				    ( {2       {1'b0}}              ),
        .arlock_m2				    ( {2       {1'b0}}              ),
        .arcache_m2				    ( {4       {1'b0}}              ),
        .arprot_m2				    ( {3       {1'b0}}              ),
        .arready_m2				    ( 			                    ),
        .rvalid_m2				    (                               ),
        .rid_m2				        (                               ),
        .rdata_m2				    (                               ),
        .rresp_m2				    (                               ),
        .rlast_m2				    (                               ),
        .rready_m2				    ( 1'b1			                ),

        .awvalid_s1					( o_m_axi_awvalid				),
        .awaddr_s1					( o_m_axi_awaddr				),
        .awid_s1					( o_m_axi_awid					),
        .awlen_s1					( o_m_axi_awlen					),
        .awsize_s1					( o_m_axi_awsize				),
        .awburst_s1					( o_m_axi_awburst				),
        .awlock_s1					( o_m_axi_awlock				),
        .awcache_s1					( o_m_axi_awcache				),
        .awprot_s1					( o_m_axi_awprot				),
        .awready_s1					( i_m_axi_awready				),
        .wvalid_s1					( o_m_axi_wvalid				),
        .wdata_s1					( o_m_axi_wdata					),
        .wstrb_s1					( o_m_axi_wstrb					),
        .wlast_s1					( o_m_axi_wlast					),
        .wready_s1					( i_m_axi_wready				),

        .bvalid_s1					( i_m_axi_bvalid				),
        .bid_s1						( i_m_axi_bid					),
        .bresp_s1					( i_m_axi_bresp					),
        .bready_s1					( o_m_axi_bready				),

        .arvalid_s1					(                               ),
        .arid_s1					(                               ),
        .araddr_s1					(                               ),
        .arlen_s1					(                               ),
        .arsize_s1					(                               ),
        .arburst_s1					(                               ),
        .arlock_s1					(                               ),
        .arcache_s1					(                               ),
        .arprot_s1					(                               ),
        .arready_s1					( 1'b0                          ),

        .rvalid_s1					( 1'b0                          ),
        .rid_s1						( {(AXI_IDW+1){1'b0}}           ),
        .rdata_s1					( {AXI_DW{1'b0}}                ),
        .rresp_s1					( 2'd0                          ),
        .rlast_s1					( 1'b0      					),
        .rready_s1					(                               ),

        .dbg_awid_s0                ( dbg_awid_s0                   ),
        .dbg_awaddr_s0              ( dbg_awaddr_s0                 ),
        .dbg_awlen_s0               ( dbg_awlen_s0                  ),
        .dbg_awsize_s0              ( dbg_awsize_s0                 ),
        .dbg_awburst_s0             ( dbg_awburst_s0                ),
        .dbg_awlock_s0              ( dbg_awlock_s0                 ),
        .dbg_awcache_s0             ( dbg_awcache_s0                ),
        .dbg_awprot_s0              ( dbg_awprot_s0                 ),
        .dbg_awvalid_s0             ( dbg_awvalid_s0                ),
        .dbg_awready_s0             ( dbg_awready_s0                ),
        .dbg_wid_s0                 ( dbg_wid_s0                    ),
        .dbg_wdata_s0               ( dbg_wdata_s0                  ),
        .dbg_wstrb_s0               ( dbg_wstrb_s0                  ),
        .dbg_wlast_s0               ( dbg_wlast_s0                  ),
        .dbg_wvalid_s0              ( dbg_wvalid_s0                 ),
        .dbg_wready_s0              ( dbg_wready_s0                 ),
        .dbg_bid_s0                 ( dbg_bid_s0                    ),
        .dbg_bresp_s0               ( dbg_bresp_s0                  ),
        .dbg_bvalid_s0              ( dbg_bvalid_s0                 ),
        .dbg_bready_s0              ( dbg_bready_s0                 ),
        .dbg_arid_s0                ( dbg_arid_s0                   ),
        .dbg_araddr_s0              ( dbg_araddr_s0                 ),
        .dbg_arlen_s0               ( dbg_arlen_s0                  ),
        .dbg_arsize_s0              ( dbg_arsize_s0                 ),
        .dbg_arburst_s0             ( dbg_arburst_s0                ),
        .dbg_arlock_s0              ( dbg_arlock_s0                 ),
        .dbg_arcache_s0             ( dbg_arcache_s0                ),
        .dbg_arprot_s0              ( dbg_arprot_s0                 ),
        .dbg_arvalid_s0             ( dbg_arvalid_s0                ),
        .dbg_arready_s0             ( dbg_arready_s0                ),
        .dbg_rid_s0                 ( dbg_rid_s0                    ),
        .dbg_rdata_s0               ( dbg_rdata_s0                  ),
        .dbg_rresp_s0               ( dbg_rresp_s0                  ),
        .dbg_rvalid_s0              ( dbg_rvalid_s0                 ),
        .dbg_rlast_s0               ( dbg_rlast_s0                  ),
        .dbg_rready_s0              ( dbg_rready_s0                 )
    );


endmodule
