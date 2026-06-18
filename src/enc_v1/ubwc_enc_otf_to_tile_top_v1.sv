//////////////////////////////////////////////////////////////////////////////////
// Module Name       : ubwc_enc_otf_to_tile_top   (V1 wrapper)
// File              : ubwc_enc_otf_to_tile_top_v1.sv
// Description       : V1 顶层：复用现行 packer + V1 otf_monitor + V1 writer + V1 fetcher
//   - packer (复用)：跨域 + 字节布局 + plane 分流 + 三类异常 (bline/bframe/fifo_ovf)
//   - otf_monitor (V1 薄壳)：fcnt 隔离 + 帧切换信号 + err_fcnt
//   - writer / fetcher：V1 新增
//   - bank SRAM mux + 1 拍寄存
//   - 新增对外端口 o_err_fcnt（独立于原 3 个 err 端口）
// Reference         : docs/claude code/enc/ubwc_enc_line_to_tile_v1_design_cn.md
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
`default_nettype none

module ubwc_enc_otf_to_tile_top
    import ubwc_enc_v1_pkg::*;
#(
    parameter                                       ADDR_W                          = 16,
    parameter                                       DATA_FIFO_DEPTH                 = 4,
    parameter                                       CI_FIFO_DEPTH                   = 16,
    parameter                                       DATA_FIFO_AF_LEVEL              = DATA_FIFO_DEPTH - 1,
    parameter                                       COORD_FIFO_DEPTH                = 32,
    parameter                                       SB_WIDTH                        = 1,
    parameter                                       TH_DW                           = 13,
    parameter                                       TW_DW                           = 8
)(
    input   wire                                        clk                             ,
    input   wire                                        i_otf_clk                       ,
    input   wire                                        i_vivo_clk                      ,
    input   wire                                        rst_n_sys                       ,
    input   wire                                        rst_n_otf                       ,
    input   wire                                        rst_n_vivo                      ,
    input   wire                                        i_start_pulse                   ,

    // static config
    input   wire    [3                   -1 :0]         i_cfg_format                    ,
    input   wire    [16                  -1 :0]         i_cfg_width                     ,
    input   wire    [16                  -1 :0]         i_cfg_height                    ,
    input   wire    [16                  -1 :0]         i_cfg_active_width              ,
    input   wire    [16                  -1 :0]         i_cfg_active_height             ,
    input   wire    [16                  -1 :0]         i_cfg_tile_w                    ,
    input   wire    [4                   -1 :0]         i_cfg_tile_h                    ,
    input   wire    [16                  -1 :0]         i_cfg_y_tile_cols               ,
    input   wire    [16                  -1 :0]         i_cfg_uv_tile_cols              ,

    // error flags（V1：每个 err 由独立源驱动；新增 o_err_fcnt）
    output  wire                                        o_err_bline                     ,
    output  wire                                        o_err_bframe                    ,
    output  wire                                        o_err_fifo_ovf                  ,
    output  wire                                        o_err_fcnt                      ,   // V1 新增
    input   wire                                        i_err_clear                     ,

    // OTF input
    input   wire                                        i_otf_vsync                     ,
    input   wire                                        i_otf_hsync                     ,
    input   wire                                        i_otf_de                        ,
    input   wire    [127                    :0]         i_otf_data                      ,
    input   wire    [3                      :0]         i_otf_fcnt                      ,
    input   wire    [11                     :0]         i_otf_lcnt                      ,
    output  wire                                        o_otf_ready                     ,

    // SRAM bank0
    output  wire                                        o_bank0_en                      ,
    output  wire                                        o_bank0_wen                     ,
    output  wire    [ADDR_W              -1 :0]         o_bank0_addr                    ,
    output  wire    [127                    :0]         o_bank0_din                     ,
    input   wire    [127                    :0]         i_bank0_dout                    ,
    input   wire                                        i_bank0_dout_vld                ,

    // SRAM bank1
    output  wire                                        o_bank1_en                      ,
    output  wire                                        o_bank1_wen                     ,
    output  wire    [ADDR_W              -1 :0]         o_bank1_addr                    ,
    output  wire    [127                    :0]         o_bank1_din                     ,
    input   wire    [127                    :0]         i_bank1_dout                    ,
    input   wire                                        i_bank1_dout_vld                ,

    // final tile output
    output  wire                                        o_tile_vld                      ,
    input   wire                                        i_tile_rdy                      ,
    output  wire    [255                    :0]         o_tile_data                     ,
    output  wire    [31                     :0]         o_tile_keep                     ,
    output  wire                                        o_tile_last                     ,
    output  wire                                        o_tile_stat_valid               ,
    output  wire                                        o_tile_stat_last                ,
    output  wire                                        o_tile_stat_slot                ,

    output  wire                                        o_ci_valid                      ,
    input   wire                                        i_ci_ready                      ,
    output  wire                                        o_ci_forced_pcm                 ,
    output  wire    [SB_WIDTH            -1 :0]         o_ci_sb                         ,
    output  wire    [15                     :0]         o_tile_x                        ,
    output  wire    [15                     :0]         o_tile_y                        ,
    output  wire    [3                      :0]         o_tile_fcnt                     ,
    output  wire    [4                      :0]         o_tile_format                   ,

    input   wire                                        i_co_valid                      ,
    input   wire                                        i_co_ready                      ,
    output  wire    [TW_DW               -1 :0]         o_co_tile_x                     ,
    output  wire    [TH_DW               -1 :0]         o_co_tile_y                     ,
    output  wire    [3                      :0]         o_co_tile_fcnt                  ,
    output  wire    [4                      :0]         o_co_tile_format                ,
    output  wire                                        o_coord_fifo_wr_en              ,
    output  wire                                        o_coord_fifo_rd_en              ,
    output  wire                                        o_addr_cfg_done_pulse           ,
    output  wire                                        o_addr_cfg_done_slot            ,

    output  wire                                        o_correct_irq_pulse             ,
    output  wire                                        o_correct_irq_slot              ,
    output  wire    [31                     :0]         o_otf_de_count0                 ,
    output  wire    [31                     :0]         o_otf_de_count1                 ,
    output  wire    [31                     :0]         o_otf_line_count0               ,
    output  wire    [31                     :0]         o_otf_line_count1
);

    //==========================================================================
    // Internal nets
    //==========================================================================

    // otf_monitor → writer (frame info bus, sys clk 域 — 2-FF 同步后)
    otf_frame_info_t                                frame_info_sys                  ;

    // packer otf_fcnt 输入：被 otf_monitor 隔离，tie 0
    wire        [3                      :0]         packer_otf_fcnt_tied            ;
    assign packer_otf_fcnt_tied          = 4'd0;

    // packer → writer (fifo_a, fifo_b) — sys clk 域
    wire                                            fifo_a_vld                      ;
    wire                                            fifo_a_rdy                      ;
    wire        [162                    :0]         fifo_a_data                     ;
    wire                                            fifo_b_vld                      ;
    wire                                            fifo_b_rdy                      ;
    wire        [162                    :0]         fifo_b_data                     ;
    packer_fifo_entry_t                             fifo_a_data_struct              ;
    packer_fifo_entry_t                             fifo_b_data_struct              ;
    assign fifo_a_data_struct            = fifo_a_data;
    assign fifo_b_data_struct            = fifo_b_data;

    // writer → bank mux (m_writer_*, core_clk 域)
    wire                                            wr_b0_en                        ;
    wire                                            wr_b0_wen                       ;
    wire        [ADDR_W              -1 :0]         wr_b0_addr                      ;
    wire        [127                    :0]         wr_b0_din                       ;
    wire                                            wr_b1_en                        ;
    wire                                            wr_b1_wen                       ;
    wire        [ADDR_W              -1 :0]         wr_b1_addr                      ;
    wire        [127                    :0]         wr_b1_din                       ;

    // fetcher → bank mux (m_fetcher_*, core_clk 域)
    wire                                            ft_b0_ren                       ;
    wire        [ADDR_W              -1 :0]         ft_b0_addr                      ;
    wire                                            ft_b1_ren                       ;
    wire        [ADDR_W              -1 :0]         ft_b1_addr                      ;

    // writer → fetcher (done_info)
    done_info_t                                     done_info_w                     ;
    wire                                            done_valid_w                    ;
    wire                                            done_ready_w                    ;

    // fetcher → writer (release 1 拍脉冲)
    wire                                            y_rel_valid                     ;
    wire                                            y_rel_bank                      ;
    wire                                            uv_rel_valid                    ;
    wire                                            uv_rel_slot                     ;

    // bank mux 组合 → 寄存 1 拍输出
    wire                                            b0_en_c                         ;
    wire                                            b0_wen_c                        ;
    wire        [ADDR_W              -1 :0]         b0_addr_c                       ;
    wire        [127                    :0]         b0_din_c                        ;
    wire                                            b1_en_c                         ;
    wire                                            b1_wen_c                        ;
    wire        [ADDR_W              -1 :0]         b1_addr_c                       ;
    wire        [127                    :0]         b1_din_c                        ;

    reg                                             b0_en_r                         ;
    reg                                             b0_wen_r                        ;
    reg         [ADDR_W              -1 :0]         b0_addr_r                       ;
    reg         [127                    :0]         b0_din_r                        ;
    reg                                             b1_en_r                         ;
    reg                                             b1_wen_r                        ;
    reg         [ADDR_W              -1 :0]         b1_addr_r                       ;
    reg         [127                    :0]         b1_din_r                        ;

    // writer / fetcher 内部 err (V1 暂保留接口)
    wire                                            err_wr                          ;
    wire                                            err_ft                          ;



    //==========================================================================
    // Bank mux (写优先 + 1 拍寄存)
    //==========================================================================
    assign b0_en_c                       = wr_b0_en | ft_b0_ren;
    assign b0_wen_c                      = wr_b0_wen;
    assign b0_addr_c                     = wr_b0_en ? wr_b0_addr : ft_b0_addr;
    assign b0_din_c                      = wr_b0_din;

    assign b1_en_c                       = wr_b1_en | ft_b1_ren;
    assign b1_wen_c                      = wr_b1_wen;
    assign b1_addr_c                     = wr_b1_en ? wr_b1_addr : ft_b1_addr;
    assign b1_din_c                      = wr_b1_din;

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            b0_en_r <= 1'b0;
        else
            b0_en_r <= b0_en_c;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            b0_wen_r <= 1'b0;
        else
            b0_wen_r <= b0_wen_c;
    end

    always @(posedge clk) begin
        if (b0_en_c)
            b0_addr_r <= b0_addr_c;
    end

    always @(posedge clk) begin
        if (b0_en_c && b0_wen_c)
            b0_din_r <= b0_din_c;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            b1_en_r <= 1'b0;
        else
            b1_en_r <= b1_en_c;
    end

    always @(posedge clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            b1_wen_r <= 1'b0;
        else
            b1_wen_r <= b1_wen_c;
    end

    always @(posedge clk) begin
        if (b1_en_c)
            b1_addr_r <= b1_addr_c;
    end

    always @(posedge clk) begin
        if (b1_en_c && b1_wen_c)
            b1_din_r <= b1_din_c;
    end

    assign o_bank0_en                    = b0_en_r;
    assign o_bank0_wen                   = b0_wen_r;
    assign o_bank0_addr                  = b0_addr_r;
    assign o_bank0_din                   = b0_din_r;
    assign o_bank1_en                    = b1_en_r;
    assign o_bank1_wen                   = b1_wen_r;
    assign o_bank1_addr                  = b1_addr_r;
    assign o_bank1_din                   = b1_din_r;

    //==========================================================================
    // V1 暂不实现端口 — tie 0
    //==========================================================================
    assign o_tile_stat_valid             = 1'b0;
    assign o_tile_stat_last              = 1'b0;
    assign o_tile_stat_slot              = 1'b0;

    assign o_co_tile_x                   = {TW_DW{1'b0}};
    assign o_co_tile_y                   = {TH_DW{1'b0}};
    assign o_co_tile_fcnt                = 4'd0;
    assign o_co_tile_format              = 5'd0;
    assign o_coord_fifo_wr_en            = 1'b0;
    assign o_coord_fifo_rd_en            = 1'b0;
    assign o_addr_cfg_done_pulse         = 1'b0;
    assign o_addr_cfg_done_slot          = 1'b0;

    assign o_correct_irq_pulse           = 1'b0;
    assign o_correct_irq_slot            = 1'b0;
    assign o_otf_de_count0               = 32'd0;
    assign o_otf_de_count1               = 32'd0;
    assign o_otf_line_count0             = 32'd0;
    assign o_otf_line_count1             = 32'd0;

    //==========================================================================
    // Submodule instances
    //==========================================================================

    // ----- otf_monitor (V1 薄壳：仅 fcnt 隔离) -----
    ubwc_enc_otf_monitor
    u_otf_monitor
    (
        .i_otf_clk                      ( i_otf_clk                     ),
        .rst_n_otf                      ( rst_n_otf                     ),
        .i_clk                          ( clk                           ),
        .rst_n_sys                      ( rst_n_sys                     ),

        .i_otf_vsync                    ( i_otf_vsync                   ),
        .i_otf_fcnt                     ( i_otf_fcnt                    ),

        .o_err_fcnt                     ( o_err_fcnt                    ),
        .i_err_clear                    ( i_err_clear                   ),

        .o_frame_info                   ( frame_info_sys                )
    );

    // ----- packer (复用现行 ubwc_enc_otf_data_packer.v，不修改) -----
    //   otf_fcnt 端 tie 0 — 被 otf_monitor 隔离
    ubwc_enc_otf_data_packer
    u_otf_data_packer
    (
        .i_otf_clk                      ( i_otf_clk                     ),
        .i_clk                          ( clk                           ),
        .rst_n_sys                      ( rst_n_sys                     ),
        .rst_n_otf                      ( rst_n_otf                     ),

        .cfg_format                     ( i_cfg_format                  ),
        .cfg_width                      ( i_cfg_width                   ),
        .cfg_height                     ( i_cfg_height                  ),
        .cfg_active_width               ( i_cfg_active_width            ),
        .cfg_active_height              ( i_cfg_active_height           ),

        .err_bline                      ( o_err_bline                   ),
        .err_bframe                     ( o_err_bframe                  ),
        .err_fifo_ovf                   ( o_err_fifo_ovf                ),
        .err_clear                      ( i_err_clear                   ),

        .otf_vsync                      ( i_otf_vsync                   ),
        .otf_hsync                      ( i_otf_hsync                   ),
        .otf_de                         ( i_otf_de                      ),
        .otf_data                       ( i_otf_data                    ),
        .otf_fcnt                       ( packer_otf_fcnt_tied          ),
        .otf_lcnt                       ( i_otf_lcnt                    ),
        .otf_ready                      ( o_otf_ready                   ),
        .otf_frame_done                 (                               ),

        .fifo_a_vld                     ( fifo_a_vld                    ),
        .fifo_a_rdy                     ( fifo_a_rdy                    ),
        .fifo_a_data                    ( fifo_a_data                   ),

        .fifo_b_vld                     ( fifo_b_vld                    ),
        .fifo_b_rdy                     ( fifo_b_rdy                    ),
        .fifo_b_data                    ( fifo_b_data                   )
    );

    // ----- writer (V1 新增) -----
    ubwc_enc_line_to_tile_writer
    #(
        .ADDR_W                         ( ADDR_W                        )
    )
    u_writer
    (
        .clk                            ( clk                           ),
        .rst_n                          ( rst_n_sys                     ),

        .cfg_format                     ( i_cfg_format                  ),
        .cfg_width                      ( i_cfg_width                   ),
        .cfg_height                     ( i_cfg_height                  ),
        .cfg_active_width               ( i_cfg_active_width            ),
        .cfg_active_height              ( i_cfg_active_height           ),
        .cfg_tile_h                     ( i_cfg_tile_h                  ),
        .cfg_y_tile_cols                ( i_cfg_y_tile_cols             ),
        .cfg_uv_tile_cols               ( i_cfg_uv_tile_cols            ),

        .i_frame_info                   ( frame_info_sys                ),

        .i_fifo_a_vld                   ( fifo_a_vld                    ),
        .o_fifo_a_rdy                   ( fifo_a_rdy                    ),
        .i_fifo_a_data                  ( fifo_a_data_struct            ),

        .i_fifo_b_vld                   ( fifo_b_vld                    ),
        .o_fifo_b_rdy                   ( fifo_b_rdy                    ),
        .i_fifo_b_data                  ( fifo_b_data_struct            ),

        .m_bank0_writer_en              ( wr_b0_en                      ),
        .m_bank0_writer_wen             ( wr_b0_wen                     ),
        .m_bank0_writer_addr            ( wr_b0_addr                    ),
        .m_bank0_writer_din             ( wr_b0_din                     ),

        .m_bank1_writer_en              ( wr_b1_en                      ),
        .m_bank1_writer_wen             ( wr_b1_wen                     ),
        .m_bank1_writer_addr            ( wr_b1_addr                    ),
        .m_bank1_writer_din             ( wr_b1_din                     ),

        .m_done_info                    ( done_info_w                   ),
        .m_done_valid                   ( done_valid_w                  ),
        .i_done_ready                   ( done_ready_w                  ),

        .i_y_release_valid              ( y_rel_valid                   ),
        .i_y_release_bank               ( y_rel_bank                    ),
        .i_uv_release_valid             ( uv_rel_valid                  ),
        .i_uv_release_slot              ( uv_rel_slot                   ),

        .o_err                          ( err_wr                        )
    );

    // ----- fetcher (V1 新增) -----
    ubwc_enc_tile_data_fetcher
    #(
        .ADDR_W                         ( ADDR_W                        ),
        .SB_WIDTH                       ( SB_WIDTH                      )
    )
    u_fetcher
    (
        .clk                            ( clk                           ),
        .rst_n                          ( rst_n_sys                     ),
        .i_vivo_clk                     ( i_vivo_clk                    ),
        .rst_n_vivo                     ( rst_n_vivo                    ),

        .cfg_format                     ( i_cfg_format                  ),
        .cfg_width                      ( i_cfg_width                   ),
        .cfg_active_width               ( i_cfg_active_width            ),
        .cfg_active_height              ( i_cfg_active_height           ),
        .cfg_y_tile_cols                ( i_cfg_y_tile_cols             ),
        .cfg_uv_tile_cols               ( i_cfg_uv_tile_cols            ),

        .i_done_info                    ( done_info_w                   ),
        .i_done_valid                   ( done_valid_w                  ),
        .o_done_ready                   ( done_ready_w                  ),

        .o_y_release_valid              ( y_rel_valid                   ),
        .o_y_release_bank               ( y_rel_bank                    ),
        .o_uv_release_valid             ( uv_rel_valid                  ),
        .o_uv_release_slot              ( uv_rel_slot                   ),

        .m_bank0_fetcher_ren            ( ft_b0_ren                     ),
        .m_bank0_fetcher_addr           ( ft_b0_addr                    ),
        .i_bank0_writer_wen             ( wr_b0_wen                     ),
        .i_bank0_dout                   ( i_bank0_dout                  ),
        .i_bank0_dout_vld               ( i_bank0_dout_vld              ),

        .m_bank1_fetcher_ren            ( ft_b1_ren                     ),
        .m_bank1_fetcher_addr           ( ft_b1_addr                    ),
        .i_bank1_writer_wen             ( wr_b1_wen                     ),
        .i_bank1_dout                   ( i_bank1_dout                  ),
        .i_bank1_dout_vld               ( i_bank1_dout_vld              ),

        .o_tile_vld                     ( o_tile_vld                    ),
        .i_tile_rdy                     ( i_tile_rdy                    ),
        .o_tile_data                    ( o_tile_data                   ),
        .o_tile_keep                    ( o_tile_keep                   ),
        .o_tile_last                    ( o_tile_last                   ),
        .o_tile_stat_valid              (                               ),
        .o_tile_stat_last               (                               ),
        .o_tile_stat_slot               (                               ),

        .o_ci_valid                     ( o_ci_valid                    ),
        .i_ci_ready                     ( i_ci_ready                    ),
        .o_ci_forced_pcm                ( o_ci_forced_pcm               ),
        .o_ci_sb                        ( o_ci_sb                       ),
        .o_tile_x                       ( o_tile_x                      ),
        .o_tile_y                       ( o_tile_y                      ),
        .o_tile_fcnt                    ( o_tile_fcnt                   ),
        .o_tile_format                  ( o_tile_format                 ),

        .i_co_valid                     ( i_co_valid                    ),

        .o_err                          ( err_ft                        )
    );

    // -------------------------------------------------------------------------
    // 未连接的现行 wrapper 输入 (i_start_pulse / i_co_ready / writer/fetcher 内部 err)
    //   V1 暂不使用
    // -------------------------------------------------------------------------
    wire                                            unused_inputs                   ;
    assign unused_inputs                 = i_start_pulse | i_co_ready | err_wr | err_ft;

endmodule

`default_nettype wire
