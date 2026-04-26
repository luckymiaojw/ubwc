//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Module Name       : ubwc_dec_wrapper_top.v
// Description       : Integration top for the available UBWC decode blocks.
//                     Tile address configuration is stored in local APB registers.
//                     Tile CI/CVI traffic is routed into ubwc_dec_vivo_top, and
//                     the vivo raw output is routed into ubwc_dec_tile_to_otf.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_dec_wrapper_top #(
    parameter integer APB_AW     = 16,
    parameter integer APB_DW     = 32,
    parameter integer AXI_AW     = 64,
    parameter integer AXI_DW     = 64,
    parameter integer AXI_IDW    = 6,
    parameter integer AXI_LENW   = 8,
    parameter integer SB_WIDTH   = 1,
    parameter integer COM_BUF_AW = 13,
    parameter integer COM_BUF_DW = 128,
    parameter integer FORCE_FULL_PAYLOAD = 0
)(
    // ---------------------------------------------------------------------
    // APB slave interface
    // ---------------------------------------------------------------------
    input  wire                           PCLK,
    input  wire                           PRESETn,
    input  wire                           PSEL,
    input  wire                           PENABLE,
    input  wire [APB_AW-1:0]              PADDR,
    input  wire                           PWRITE,
    input  wire [APB_DW-1:0]              PWDATA,
    output wire                           PREADY,
    output wire                           PSLVERR,
    output wire [APB_DW-1:0]              PRDATA,

    // ---------------------------------------------------------------------
    // Direct configuration: OTF backend
    // ---------------------------------------------------------------------
    input  wire                           i_otf_clk,
    input  wire                           i_otf_rstn,
    output wire                           o_otf_vsync,
    output wire                           o_otf_hsync,
    output wire                           o_otf_de,
    output wire [127:0]                   o_otf_data,
    output wire [3:0]                     o_otf_fcnt,
    output wire [11:0]                    o_otf_lcnt,
    input  wire                           i_otf_ready,

    // ---------------------------------------------------------------------
    // External OTF ping-pong SRAM banks
    // ---------------------------------------------------------------------
    output wire                           o_bank0_en,
    output wire                           o_bank0_wen,
    output wire [COM_BUF_AW-1:0]          o_bank0_addr,
    output wire [COM_BUF_DW-1:0]          o_bank0_din,
    input  wire [COM_BUF_DW-1:0]          i_bank0_dout,
    input  wire                           i_bank0_dout_vld,
    output wire                           o_bank1_en,
    output wire                           o_bank1_wen,
    output wire [COM_BUF_AW-1:0]          o_bank1_addr,
    output wire [COM_BUF_DW-1:0]          o_bank1_din,
    input  wire [COM_BUF_DW-1:0]          i_bank1_dout,
    input  wire                           i_bank1_dout_vld,

    // ---------------------------------------------------------------------
    // Shared AXI read master interface on i_axi_clk
    // ---------------------------------------------------------------------
    input  wire                           i_axi_clk,
    input  wire                           i_axi_rstn,
    output wire [AXI_IDW:0]               o_m_axi_arid,
    output wire [AXI_AW-1:0]              o_m_axi_araddr,
    output wire [AXI_LENW-1:0]            o_m_axi_arlen,
    output wire [3:0]                     o_m_axi_arsize,
    output wire [1:0]                     o_m_axi_arburst,
    output wire [0:0]                     o_m_axi_arlock,
    output wire [3:0]                     o_m_axi_arcache,
    output wire [2:0]                     o_m_axi_arprot,
    output wire                           o_m_axi_arvalid,
    input  wire                           i_m_axi_arready,
    input  wire [AXI_DW-1:0]              i_m_axi_rdata,
    input  wire                           i_m_axi_rvalid,
    input  wire [1:0]                     i_m_axi_rresp,
    input  wire                           i_m_axi_rlast,
    output wire                           o_m_axi_rready
);

    localparam integer                  CORE_AXI_DW                 = 256;
    localparam [AXI_IDW     -1:0]       AXI_ZERO_ID                 = {AXI_IDW{1'b0}};

    wire                                ctrl_rst_n                  ;
    wire                                otf_rst_n                   ;

    wire                                r_tile_cfg_lvl2_bank_swizzle_en;
    wire                                r_tile_cfg_lvl3_bank_swizzle_en;
    wire    [5              -1:0]       r_tile_cfg_highest_bank_bit ;
    wire                                r_tile_cfg_bank_spread_en   ;
    wire                                r_tile_cfg_is_lossy_rgba_2_1_format;
    wire    [12             -1:0]       r_tile_cfg_pitch            ;
    wire                                r_tile_cfg_ci_input_type    ;
    wire    [SB_WIDTH       -1:0]       r_tile_cfg_ci_sb            ;
    wire                                r_tile_cfg_ci_lossy         ;
    wire    [2              -1:0]       r_tile_cfg_ci_alpha_mode    ;
    wire    [AXI_AW         -1:0]       r_tile_base_addr_rgba_uv    ;
    wire    [AXI_AW         -1:0]       r_tile_base_addr_y          ;
    wire                                r_vivo_ubwc_en              ;
    wire                                r_vivo_sreset               ;
    wire                                frame_start_pulse_axi       ;
    wire                                meta_start_pulse_axi        ;
    wire    [5              -1:0]       r_meta_base_format          ;
    wire    [AXI_AW         -1:0]       r_meta_base_addr_rgba_y     ;
    wire    [AXI_AW         -1:0]       r_meta_base_addr_uv         ;
    wire    [16             -1:0]       r_meta_tile_x_numbers       ;
    wire    [16             -1:0]       r_meta_tile_y_numbers       ;
    wire    [16             -1:0]       r_otf_cfg_img_width         ;
    wire    [5              -1:0]       r_otf_cfg_format            ;
    wire    [16             -1:0]       r_otf_cfg_h_total           ;
    wire    [16             -1:0]       r_otf_cfg_h_sync            ;
    wire    [16             -1:0]       r_otf_cfg_h_bp              ;
    wire    [16             -1:0]       r_otf_cfg_h_act             ;
    wire    [16             -1:0]       r_otf_cfg_v_total           ;
    wire    [16             -1:0]       r_otf_cfg_v_sync            ;
    wire    [16             -1:0]       r_otf_cfg_v_bp              ;
    wire    [16             -1:0]       r_otf_cfg_v_act             ;
    wire                                meta_stage_busy_int         ;
    wire                                tile_stage_busy_int         ;
    wire                                meta_stage_busy_core_int    ;
    wire                                tile_stage_busy_core_int    ;
    wire                                vivo_stage_busy_int         ;
    wire                                otf_stage_busy_int          ;
    wire                                rd_interconnect_busy_int    ;
    wire                                rd_interconnect_core_busy_int;
    wire    [7              -1:0]       vivo_idle_bits_int          ;
    wire    [7              -1:0]       vivo_error_bits_int         ;
    wire    [32             -1:0]       meta_error_cnt_int          ;
    wire    [32             -1:0]       meta_cmd_ok_cnt_int         ;
    wire    [32             -1:0]       meta_cmd_fail_cnt_int       ;
    wire                                meta_status_seen            ;

    ubwc_dec_rstn_gen u_dec_rstn_gen (
        .i_presetn   (PRESETn),
        .i_axi_rstn  (i_axi_rstn),
        .i_otf_rstn  (i_otf_rstn),
        .o_ctrl_rst_n(ctrl_rst_n),
        .o_otf_rst_n (otf_rst_n)
    );

    ubwc_dec_apb_reg_blk #(
        .AW       (APB_AW),
        .DW       (APB_DW),
        .AXI_AW   (AXI_AW),
        .SB_WIDTH (SB_WIDTH)
    ) u_apb_dec_reg_blk (
        .PCLK                                 (PCLK),
        .PRESETn                              (PRESETn),
        .PSEL                                 (PSEL),
        .PENABLE                              (PENABLE),
        .PADDR                                (PADDR),
        .PWRITE                               (PWRITE),
        .PWDATA                               (PWDATA),
        .i_axi_clk                            (i_axi_clk),
        .i_axi_rst_n                          (ctrl_rst_n),
        .i_meta_busy_axi                      (meta_stage_busy_int),
        .i_tile_busy_axi                      (tile_stage_busy_int),
        .i_vivo_busy_axi                      (vivo_stage_busy_int),
        .i_otf_busy_axi                       (otf_stage_busy_int),
        .i_vivo_idle_bits_axi                 (vivo_idle_bits_int),
        .i_vivo_error_bits_axi                (vivo_error_bits_int),
        .PREADY                               (PREADY),
        .PSLVERR                              (PSLVERR),
        .PRDATA                               (PRDATA),
        .o_tile_cfg_lvl2_bank_swizzle_en      (r_tile_cfg_lvl2_bank_swizzle_en),
        .o_tile_cfg_lvl3_bank_swizzle_en      (r_tile_cfg_lvl3_bank_swizzle_en),
        .o_tile_cfg_highest_bank_bit          (r_tile_cfg_highest_bank_bit),
        .o_tile_cfg_bank_spread_en            (r_tile_cfg_bank_spread_en),
        .o_tile_cfg_is_lossy_rgba_2_1_format  (r_tile_cfg_is_lossy_rgba_2_1_format),
        .o_tile_cfg_pitch                     (r_tile_cfg_pitch),
        .o_tile_cfg_ci_input_type             (r_tile_cfg_ci_input_type),
        .o_tile_cfg_ci_sb                     (r_tile_cfg_ci_sb),
        .o_tile_cfg_ci_lossy                  (r_tile_cfg_ci_lossy),
        .o_tile_cfg_ci_alpha_mode             (r_tile_cfg_ci_alpha_mode),
        .o_tile_base_addr_rgba_uv             (r_tile_base_addr_rgba_uv),
        .o_tile_base_addr_y                   (r_tile_base_addr_y),
        .o_vivo_ubwc_en                       (r_vivo_ubwc_en),
        .o_vivo_sreset                        (r_vivo_sreset),
        .o_frame_start_pulse_axi              (frame_start_pulse_axi),
        .o_meta_start_pulse_axi               (meta_start_pulse_axi),
        .o_meta_base_format                   (r_meta_base_format),
        .o_meta_base_addr_rgba_y              (r_meta_base_addr_rgba_y),
        .o_meta_base_addr_uv                  (r_meta_base_addr_uv),
        .o_meta_tile_x_numbers                (r_meta_tile_x_numbers),
        .o_meta_tile_y_numbers                (r_meta_tile_y_numbers),
        .o_otf_cfg_img_width                  (r_otf_cfg_img_width),
        .o_otf_cfg_format                     (r_otf_cfg_format),
        .o_otf_cfg_h_total                    (r_otf_cfg_h_total),
        .o_otf_cfg_h_sync                     (r_otf_cfg_h_sync),
        .o_otf_cfg_h_bp                       (r_otf_cfg_h_bp),
        .o_otf_cfg_h_act                      (r_otf_cfg_h_act),
        .o_otf_cfg_v_total                    (r_otf_cfg_v_total),
        .o_otf_cfg_v_sync                     (r_otf_cfg_v_sync),
        .o_otf_cfg_v_bp                       (r_otf_cfg_v_bp),
        .o_otf_cfg_v_act                      (r_otf_cfg_v_act)
    );

    // ---------------------------------------------------------------------
    // Metadata path -> tile command path
    // ---------------------------------------------------------------------
    wire                                meta_dec_valid             ;
    wire                                meta_dec_ready             ;
    wire    [5              -1:0]       meta_dec_format            ;
    wire    [4              -1:0]       meta_dec_flag              ;
    wire    [3              -1:0]       meta_dec_alen              ;
    wire                                meta_dec_has_payload       ;
    wire    [12             -1:0]       meta_dec_x                 ;
    wire    [10             -1:0]       meta_dec_y                 ;

    wire    [AXI_IDW          :0]       core_m_axi_arid            ;
    wire    [AXI_AW         -1:0]       core_m_axi_araddr          ;
    wire    [AXI_LENW       -1:0]       core_m_axi_arlen           ;
    wire    [4              -1:0]       core_m_axi_arsize          ;
    wire    [2              -1:0]       core_m_axi_arburst         ;
    wire                                core_m_axi_arvalid         ;
    wire                                core_m_axi_arready         ;
    wire    [CORE_AXI_DW    -1:0]       core_m_axi_rdata           ;
    wire                                core_m_axi_rvalid          ;
    wire    [2              -1:0]       core_m_axi_rresp           ;
    wire                                core_m_axi_rlast           ;
    wire                                core_m_axi_rready          ;

    wire                                meta_m_axi_arvalid         ;
    wire                                meta_m_axi_arready         ;
    wire    [AXI_AW         -1:0]       meta_m_axi_araddr          ;
    wire    [8              -1:0]       meta_m_axi_arlen           ;
    wire    [3              -1:0]       meta_m_axi_arsize          ;
    wire    [2              -1:0]       meta_m_axi_arburst         ;
    wire    [AXI_IDW        -1:0]       meta_m_axi_arid            ;
    wire                                meta_m_axi_rvalid          ;
    wire                                meta_m_axi_rready          ;
    wire    [CORE_AXI_DW    -1:0]       meta_m_axi_rdata           ;
    wire    [2              -1:0]       meta_m_axi_rresp           ;
    wire                                meta_m_axi_rlast           ;

    ubwc_dec_meta_data_gen #(
        .ADDR_WIDTH             ( AXI_AW                                ),
        .ID_WIDTH               ( AXI_IDW                               ),
        .AXI_DATA_WIDTH         ( CORE_AXI_DW                           ),
        .FORCE_FULL_PAYLOAD     ( FORCE_FULL_PAYLOAD                    )
    ) u_meta_data_gen (
        .clk                    ( i_axi_clk                             ),
        .rst_n                  ( ctrl_rst_n                            ),
        .start                  ( meta_start_pulse_axi                  ),
        .base_format            ( r_meta_base_format                    ),
        .meta_base_addr_rgba_y  ( r_meta_base_addr_rgba_y               ),
        .meta_base_addr_uv      ( r_meta_base_addr_uv                   ),
        .tile_x_numbers         ( r_meta_tile_x_numbers                 ),
        .tile_y_numbers         ( r_meta_tile_y_numbers                 ),
        .i_cfg_is_lossy_rgba_2_1_format  ( r_tile_cfg_is_lossy_rgba_2_1_format ),
        .m_axi_arvalid          ( meta_m_axi_arvalid                    ),
        .m_axi_arready          ( meta_m_axi_arready                    ),
        .m_axi_araddr           ( meta_m_axi_araddr                     ),
        .m_axi_arlen            ( meta_m_axi_arlen                      ),
        .m_axi_arsize           ( meta_m_axi_arsize                     ),
        .m_axi_arburst          ( meta_m_axi_arburst                    ),
        .m_axi_arid             ( meta_m_axi_arid                       ),
        .m_axi_rvalid           ( meta_m_axi_rvalid                     ),
        .m_axi_rready           ( meta_m_axi_rready                     ),
        .m_axi_rdata            ( meta_m_axi_rdata                      ),
        .m_axi_rid              ( AXI_ZERO_ID                           ),
        .m_axi_rresp            ( meta_m_axi_rresp                      ),
        .m_axi_rlast            ( meta_m_axi_rlast                      ),
        .o_dec_valid            ( meta_dec_valid                        ),
        .i_dec_ready            ( meta_dec_ready                        ),
        .o_dec_format           ( meta_dec_format                       ),
        .o_dec_flag             ( meta_dec_flag                         ),
        .o_dec_alen             ( meta_dec_alen                         ),
        .o_dec_has_payload      ( meta_dec_has_payload                  ),
        .o_dec_x                ( meta_dec_x                            ),
        .o_dec_y                ( meta_dec_y                            ),
        .o_busy                 ( meta_stage_busy_core_int              ),
        .error_cnt              ( meta_error_cnt_int                    ),
        .cmd_ok_cnt             ( meta_cmd_ok_cnt_int                   ),
        .cmd_fail_cnt           ( meta_cmd_fail_cnt_int                 )
    );

    wire                                tile_m_axi_arvalid         ;
    wire                                tile_m_axi_arready         ;
    wire    [AXI_AW         -1:0]       tile_m_axi_araddr          ;
    wire    [8              -1:0]       tile_m_axi_arlen           ;
    wire    [3              -1:0]       tile_m_axi_arsize          ;
    wire    [2              -1:0]       tile_m_axi_arburst         ;
    wire    [AXI_IDW        -1:0]       tile_m_axi_arid            ;
    wire                                tile_m_axi_rvalid          ;
    wire                                tile_m_axi_rready          ;
    wire    [CORE_AXI_DW    -1:0]       tile_m_axi_rdata           ;
    wire    [2              -1:0]       tile_m_axi_rresp           ;
    wire                                tile_m_axi_rlast           ;

    wire                                tile_ci_valid_int          ;
    wire                                tile_ci_ready_int          ;
    wire                                tile_ci_input_type_int     ;
    wire    [3              -1:0]       tile_ci_alen_int           ;
    wire    [5              -1:0]       tile_ci_format_int         ;
    wire    [4              -1:0]       tile_ci_metadata_int       ;
    wire                                tile_ci_lossy_int          ;
    wire    [2              -1:0]       tile_ci_alpha_mode_int     ;
    wire    [SB_WIDTH       -1:0]       tile_ci_sb_int             ;
    wire                                tile_coord_vld_int         ;
    wire    [5              -1:0]       tile_format_int            ;
    wire    [12             -1:0]       tile_x_coord_int           ;
    wire    [10             -1:0]       tile_y_coord_int           ;
    wire                                tile_cvi_valid_int         ;
    wire    [256            -1:0]       tile_cvi_data_int          ;
    wire                                tile_cvi_last_int          ;
    wire                                tile_cvi_ready_int         ;

    ubwc_dec_tile_arcmd_gen #(
        .AXI_AW                         ( AXI_AW                                ),
        .AXI_DW                         ( CORE_AXI_DW                           ),
        .AXI_IDW                        ( AXI_IDW                               ),
        .SB_WIDTH                       ( SB_WIDTH                              )
    ) u_tile_arcmd_gen (
        .clk                             ( i_axi_clk                             ),
        .rst_n                           ( ctrl_rst_n                            ),
        .i_frame_start                   ( frame_start_pulse_axi                 ),
        .i_cfg_lvl2_bank_swizzle_en      ( r_tile_cfg_lvl2_bank_swizzle_en        ),
        .i_cfg_lvl3_bank_swizzle_en      ( r_tile_cfg_lvl3_bank_swizzle_en        ),
        .i_cfg_highest_bank_bit          ( r_tile_cfg_highest_bank_bit            ),
        .i_cfg_bank_spread_en            ( r_tile_cfg_bank_spread_en              ),
        .i_cfg_is_lossy_rgba_2_1_format  ( r_tile_cfg_is_lossy_rgba_2_1_format    ),
        .i_cfg_pitch                     ( r_tile_cfg_pitch                       ),
        .i_cfg_ci_input_type             ( r_tile_cfg_ci_input_type               ),
        .i_cfg_ci_sb                     ( r_tile_cfg_ci_sb                       ),
        .i_cfg_ci_lossy                  ( r_tile_cfg_ci_lossy                    ),
        .i_cfg_ci_alpha_mode             ( r_tile_cfg_ci_alpha_mode               ),
        .i_cfg_base_addr_rgba_uv         ( r_tile_base_addr_rgba_uv               ),
        .i_cfg_base_addr_y               ( r_tile_base_addr_y                     ),
        .dec_meta_valid                  ( meta_dec_valid                        ),
        .dec_meta_ready                  ( meta_dec_ready                        ),
        .dec_meta_format                 ( meta_dec_format                       ),
        .dec_meta_flag                   ( meta_dec_flag                         ),
        .dec_meta_alen                   ( meta_dec_alen                         ),
        .dec_meta_has_payload            ( meta_dec_has_payload                  ),
        .dec_meta_x                      ( meta_dec_x                            ),
        .dec_meta_y                      ( meta_dec_y                            ),
        .m_axi_arvalid                   ( tile_m_axi_arvalid                    ),
        .m_axi_arready                   ( tile_m_axi_arready                    ),
        .m_axi_araddr                    ( tile_m_axi_araddr                     ),
        .m_axi_arlen                     ( tile_m_axi_arlen                      ),
        .m_axi_arsize                    ( tile_m_axi_arsize                     ),
        .m_axi_arburst                   ( tile_m_axi_arburst                    ),
        .m_axi_arid                      ( tile_m_axi_arid                       ),
        .m_axi_rvalid                    ( tile_m_axi_rvalid                     ),
        .m_axi_rid                       ( AXI_ZERO_ID                           ),
        .m_axi_rdata                     ( tile_m_axi_rdata                      ),
        .m_axi_rresp                     ( tile_m_axi_rresp                      ),
        .m_axi_rlast                     ( tile_m_axi_rlast                      ),
        .m_axi_rready                    ( tile_m_axi_rready                     ),
        .o_ci_valid                      ( tile_ci_valid_int                     ),
        .i_ci_ready                      ( tile_ci_ready_int                     ),
        .o_ci_input_type                 ( tile_ci_input_type_int                ),
        .o_ci_alen                       ( tile_ci_alen_int                      ),
        .o_ci_format                     ( tile_ci_format_int                    ),
        .o_ci_metadata                   ( tile_ci_metadata_int                  ),
        .o_ci_lossy                      ( tile_ci_lossy_int                     ),
        .o_ci_alpha_mode                 ( tile_ci_alpha_mode_int                ),
        .o_ci_sb                         ( tile_ci_sb_int                        ),
        .o_tile_coord_vld                ( tile_coord_vld_int                    ),
        .o_tile_format                   ( tile_format_int                       ),
        .o_tile_x_coord                  ( tile_x_coord_int                      ),
        .o_tile_y_coord                  ( tile_y_coord_int                      ),
        .o_cvi_valid                     ( tile_cvi_valid_int                    ),
        .o_cvi_data                      ( tile_cvi_data_int                     ),
        .o_cvi_last                      ( tile_cvi_last_int                     ),
        .i_cvi_ready                     ( tile_cvi_ready_int                    ),
        .o_busy                          ( tile_stage_busy_core_int              )
    );

    // ---------------------------------------------------------------------
    // Shared AXI read interconnect
    // ---------------------------------------------------------------------
    ubwc_dec_axi_rd_interconnect #(
        .AXI_AW   (AXI_AW),
        .AXI_DW   (CORE_AXI_DW),
        .AXI_IDW  (AXI_IDW),
        .AXI_LENW (AXI_LENW)
    ) u_axi_rd_interconnect (
        .clk       (i_axi_clk),
        .rst_n     (ctrl_rst_n),
        .i_frame_start(frame_start_pulse_axi),
        .s0_arvalid(meta_m_axi_arvalid),
        .s0_arready(meta_m_axi_arready),
        .s0_araddr (meta_m_axi_araddr),
        .s0_arlen  (meta_m_axi_arlen),
        .s0_arsize (meta_m_axi_arsize),
        .s0_arburst(meta_m_axi_arburst),
        .s0_arid   (meta_m_axi_arid),
        .s0_rvalid (meta_m_axi_rvalid),
        .s0_rready (meta_m_axi_rready),
        .s0_rdata  (meta_m_axi_rdata),
        .s0_rresp  (meta_m_axi_rresp),
        .s0_rlast  (meta_m_axi_rlast),
        .s1_arvalid(tile_m_axi_arvalid),
        .s1_arready(tile_m_axi_arready),
        .s1_araddr (tile_m_axi_araddr),
        .s1_arlen  (tile_m_axi_arlen),
        .s1_arsize (tile_m_axi_arsize),
        .s1_arburst(tile_m_axi_arburst),
        .s1_arid   (tile_m_axi_arid),
        .s1_rvalid (tile_m_axi_rvalid),
        .s1_rready (tile_m_axi_rready),
        .s1_rdata  (tile_m_axi_rdata),
        .s1_rresp  (tile_m_axi_rresp),
        .s1_rlast  (tile_m_axi_rlast),
        .m_arid    (core_m_axi_arid),
        .m_araddr  (core_m_axi_araddr),
        .m_arlen   (core_m_axi_arlen),
        .m_arsize  (core_m_axi_arsize),
        .m_arburst (core_m_axi_arburst),
        .m_arvalid (core_m_axi_arvalid),
        .m_arready (core_m_axi_arready),
        .m_rdata   (core_m_axi_rdata),
        .m_rvalid  (core_m_axi_rvalid),
        .m_rresp   (core_m_axi_rresp),
        .m_rlast   (core_m_axi_rlast),
        .m_rready  (core_m_axi_rready),
        .o_busy    (rd_interconnect_core_busy_int)
    );

    ubwc_axi_rd_256to64 #(
        .ADDR_WIDTH  (AXI_AW),
        .ID_WIDTH    (AXI_IDW + 1),
        .AXI_LENW    (AXI_LENW),
        .CORE_AXI_DW (CORE_AXI_DW),
        .M_AXI_DW    (AXI_DW)
    ) u_axi_rd_256to64 (
        .clk         (i_axi_clk),
        .rst_n       (ctrl_rst_n),
        .s_axi_arid  (core_m_axi_arid),
        .s_axi_araddr(core_m_axi_araddr),
        .s_axi_arlen (core_m_axi_arlen),
        .s_axi_arsize(core_m_axi_arsize),
        .s_axi_arburst(core_m_axi_arburst),
        .s_axi_arvalid(core_m_axi_arvalid),
        .s_axi_arready(core_m_axi_arready),
        .s_axi_rdata (core_m_axi_rdata),
        .s_axi_rresp (core_m_axi_rresp),
        .s_axi_rlast (core_m_axi_rlast),
        .s_axi_rvalid(core_m_axi_rvalid),
        .s_axi_rready(core_m_axi_rready),
        .m_axi_arid  (o_m_axi_arid),
        .m_axi_araddr(o_m_axi_araddr),
        .m_axi_arlen (o_m_axi_arlen),
        .m_axi_arsize(o_m_axi_arsize),
        .m_axi_arburst(o_m_axi_arburst),
        .m_axi_arvalid(o_m_axi_arvalid),
        .m_axi_arready(i_m_axi_arready),
        .m_axi_rdata (i_m_axi_rdata),
        .m_axi_rresp (i_m_axi_rresp),
        .m_axi_rlast (i_m_axi_rlast),
        .m_axi_rvalid(i_m_axi_rvalid),
        .m_axi_rready(o_m_axi_rready)
    );

    assign o_m_axi_arlock  = 1'b0;
    assign o_m_axi_arcache = 4'b0000;
    assign o_m_axi_arprot  = 3'b000;
    wire bank_dout_vld_seen = i_bank0_dout_vld | i_bank1_dout_vld;

    assign rd_interconnect_busy_int = rd_interconnect_core_busy_int |
                                      core_m_axi_arvalid |
                                      core_m_axi_rvalid |
                                      o_m_axi_arvalid |
                                      i_m_axi_rvalid |
                                      (bank_dout_vld_seen & 1'b0);
    assign meta_status_seen = (|meta_error_cnt_int) | (|meta_cmd_ok_cnt_int) | (|meta_cmd_fail_cnt_int);
    assign meta_stage_busy_int = meta_stage_busy_core_int | rd_interconnect_busy_int |
                                 (meta_status_seen & 1'b0);
    assign tile_stage_busy_int = tile_stage_busy_core_int | rd_interconnect_busy_int;

    // ---------------------------------------------------------------------
    // ubwc_dec_vivo_top integration
    // ---------------------------------------------------------------------
    wire                     vivo_ci_ready_raw;
    wire                     vivo_ci_valid_int;
    wire                     vivo_rvo_valid;
    wire [255:0]             vivo_rvo_data;
    wire                     vivo_rvo_last;
    wire                     vivo_rvo_ready;
    wire                     vivo_co_valid;
    wire [2:0]               vivo_co_alen;
    wire [SB_WIDTH-1:0]      vivo_co_sb;
    wire                     vivo_co_seen;
    wire                     otf_axis_tile_ready_int;
    wire                     otf_axis_tready_int;
    wire [4:0]               otf_axis_format;
    wire [15:0]              otf_axis_tile_x;
    wire [15:0]              otf_axis_tile_y;
    wire                     otf_axis_tile_valid;
    wire [255:0]             otf_axis_tdata;
    wire                     otf_axis_tlast;
    wire                     otf_axis_tvalid;
    wire                     otf_sram_a_wen_int;
    wire [12:0]              otf_sram_a_waddr_int;
    wire [127:0]             otf_sram_a_wdata_int;
    wire                     otf_sram_a_ren_int;
    wire [12:0]              otf_sram_a_raddr_int;
    wire [127:0]             otf_sram_a_rdata_int;
    wire                     otf_sram_b_wen_int;
    wire [12:0]              otf_sram_b_waddr_int;
    wire [127:0]             otf_sram_b_wdata_int;
    wire                     otf_sram_b_ren_int;
    wire [12:0]              otf_sram_b_raddr_int;
    wire [127:0]             otf_sram_b_rdata_int;

    // Tile header and CI command now share the same ready chain. This keeps
    // format/x/y aligned with the CI acceptance point and removes the need
    // for extra wrapper-side header FIFOs.
    assign vivo_ci_valid_int = tile_ci_valid_int && otf_axis_tile_ready_int;
    assign tile_ci_ready_int   = vivo_ci_ready_raw && otf_axis_tile_ready_int;
    assign otf_axis_format     = tile_format_int;
    assign otf_axis_tile_x     = {4'd0, tile_x_coord_int};
    assign otf_axis_tile_y     = {6'd0, tile_y_coord_int};
    assign otf_axis_tile_valid = tile_coord_vld_int;
    assign otf_axis_tdata      = vivo_rvo_data;
    assign otf_axis_tlast      = vivo_rvo_last;
    assign otf_axis_tvalid     = vivo_rvo_valid;

    assign vivo_rvo_ready      = otf_axis_tready_int;
    assign vivo_co_seen        = vivo_co_valid | (|vivo_co_alen) | (|vivo_co_sb);
    assign vivo_stage_busy_int = !(&vivo_idle_bits_int) | (vivo_co_seen & 1'b0);
    assign o_bank0_en          = otf_sram_a_wen_int | otf_sram_a_ren_int;
    assign o_bank0_wen         = otf_sram_a_wen_int;
    assign o_bank0_addr        = otf_sram_a_wen_int ? otf_sram_a_waddr_int : otf_sram_a_raddr_int;
    assign o_bank0_din         = otf_sram_a_wdata_int;
    assign o_bank1_en          = otf_sram_b_wen_int | otf_sram_b_ren_int;
    assign o_bank1_wen         = otf_sram_b_wen_int;
    assign o_bank1_addr        = otf_sram_b_wen_int ? otf_sram_b_waddr_int : otf_sram_b_raddr_int;
    assign o_bank1_din         = otf_sram_b_wdata_int;
    assign otf_sram_a_rdata_int = i_bank0_dout[127:0];
    assign otf_sram_b_rdata_int = i_bank1_dout[127:0];

    ubwc_dec_vivo_top #(
        .SB_WIDTH (SB_WIDTH)
    ) u_dec_vivo_top (
        .i_clk            (i_axi_clk),
        .i_reset          (~ctrl_rst_n),
        .i_sreset         (r_vivo_sreset | frame_start_pulse_axi),
        .i_ubwc_en        (r_vivo_ubwc_en),
        .i_ci_valid       (vivo_ci_valid_int),
        .o_ci_ready       (vivo_ci_ready_raw),
        .i_ci_input_type  (tile_ci_input_type_int),
        .i_ci_alen        (tile_ci_alen_int),
        .i_ci_format      (tile_ci_format_int),
        .i_ci_metadata    (tile_ci_metadata_int),
        .i_ci_lossy       (tile_ci_lossy_int),
        .i_ci_alpha_mode  (tile_ci_alpha_mode_int),
        .i_ci_sb          (tile_ci_sb_int),
        .i_cvi_valid      (tile_cvi_valid_int),
        .i_cvi_data       (tile_cvi_data_int),
        .i_cvi_last       (tile_cvi_last_int),
        .o_cvi_ready      (tile_cvi_ready_int),
        .o_co_valid       (vivo_co_valid),
        .o_co_alen        (vivo_co_alen),
        .o_co_sb          (vivo_co_sb),
        .i_co_ready       (1'b1),
        .o_rvo_valid      (vivo_rvo_valid),
        .o_rvo_data       (vivo_rvo_data),
        .o_rvo_last       (vivo_rvo_last),
        .i_rvo_ready      (vivo_rvo_ready),
        .o_idle           (vivo_idle_bits_int),
        .o_error          (vivo_error_bits_int)
    );

    ubwc_dec_tile_to_otf u_tile_to_otf (
        .clk_sram          (i_axi_clk),
        .clk_otf           (i_otf_clk),
        .rst_n             (otf_rst_n),
        .i_frame_start     (frame_start_pulse_axi),
        .cfg_img_width     (r_otf_cfg_img_width),
        .cfg_format        (r_otf_cfg_format),
        .cfg_otf_h_total   (r_otf_cfg_h_total),
        .cfg_otf_h_sync    (r_otf_cfg_h_sync),
        .cfg_otf_h_bp      (r_otf_cfg_h_bp),
        .cfg_otf_h_act     (r_otf_cfg_h_act),
        .cfg_otf_v_total   (r_otf_cfg_v_total),
        .cfg_otf_v_sync    (r_otf_cfg_v_sync),
        .cfg_otf_v_bp      (r_otf_cfg_v_bp),
        .cfg_otf_v_act     (r_otf_cfg_v_act),
        .s_axis_format     (otf_axis_format),
        .s_axis_tile_x     (otf_axis_tile_x),
        .s_axis_tile_y     (otf_axis_tile_y),
        .s_axis_tile_valid (otf_axis_tile_valid),
        .s_axis_tile_ready (otf_axis_tile_ready_int),
        .s_axis_tdata      (otf_axis_tdata),
        .s_axis_tlast      (otf_axis_tlast),
        .s_axis_tvalid     (otf_axis_tvalid),
        .s_axis_tready     (otf_axis_tready_int),
        .sram_a_wen        (otf_sram_a_wen_int),
        .sram_a_waddr      (otf_sram_a_waddr_int),
        .sram_a_wdata      (otf_sram_a_wdata_int),
        .sram_a_ren        (otf_sram_a_ren_int),
        .sram_a_raddr      (otf_sram_a_raddr_int),
        .sram_a_rdata      (otf_sram_a_rdata_int),
        .sram_b_wen        (otf_sram_b_wen_int),
        .sram_b_waddr      (otf_sram_b_waddr_int),
        .sram_b_wdata      (otf_sram_b_wdata_int),
        .sram_b_ren        (otf_sram_b_ren_int),
        .sram_b_raddr      (otf_sram_b_raddr_int),
        .sram_b_rdata      (otf_sram_b_rdata_int),
        .o_otf_vsync       (o_otf_vsync),
        .o_otf_hsync       (o_otf_hsync),
        .o_otf_de          (o_otf_de),
        .o_otf_data        (o_otf_data),
        .o_otf_fcnt        (o_otf_fcnt),
        .o_otf_lcnt        (o_otf_lcnt),
        .i_otf_ready       (i_otf_ready),
        .o_busy            (otf_stage_busy_int)
    );

endmodule
