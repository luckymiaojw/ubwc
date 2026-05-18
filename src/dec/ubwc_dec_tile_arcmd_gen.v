`timescale 1ns/1ps

module ubwc_dec_tile_arcmd_gen
    #(
        parameter                                       AXI_AW                          = 64,
        parameter                                       AXI_DW                          = 256,
        parameter                                       AXI_IDW                         = 4,
        parameter                                       SB_WIDTH                        = 1
    )(
        input   wire                                        clk                             ,
        input   wire                                        rst_n                           ,
        input   wire                                        i_frame_start                   ,

        input   wire                                        i_cfg_lvl2_bank_swizzle_en      ,
        input   wire                                        i_cfg_lvl3_bank_swizzle_en      ,
        input   wire    [5                   -1 :0]         i_cfg_highest_bank_bit          ,
        input   wire                                        i_cfg_bank_spread_en            ,
        input   wire                                        i_cfg_is_lossy_rgba_2_1_format  ,
        input   wire    [12                  -1 :0]         i_cfg_pitch                     ,

        input   wire                                        i_cfg_ci_input_type             ,
        input   wire                                        i_cfg_ci_lossy                  ,
        input   wire    [2                   -1 :0]         i_cfg_ci_alpha_mode             ,
        input   wire    [AXI_AW              -1 :0]         i_cfg_base_addr_rgba_y0         ,
        input   wire    [AXI_AW              -1 :0]         i_cfg_base_addr_uv0             ,
        input   wire    [AXI_AW              -1 :0]         i_cfg_base_addr_rgba_y1         ,
        input   wire    [AXI_AW              -1 :0]         i_cfg_base_addr_uv1             ,

    // Decoded metadata stream from ubwc_dec_meta_data_gen
        input   wire                                        dec_meta_valid                  ,
        output  wire                                        dec_meta_ready                  ,
        input   wire    [5                   -1 :0]         dec_meta_format                 ,
        input   wire    [4                   -1 :0]         dec_meta_flag                   ,
        input   wire    [3                   -1 :0]         dec_meta_alen                   ,
        input   wire                                        dec_meta_has_payload            ,
        input   wire    [12                  -1 :0]         dec_meta_x                      ,
        input   wire    [10                  -1 :0]         dec_meta_y                      ,
        input   wire    [4                   -1 :0]         dec_meta_fcnt                   ,

        output  wire                                        m_axi_arvalid                   ,
        input   wire                                        m_axi_arready                   ,
        output  wire    [AXI_AW              -1 :0]         m_axi_araddr                    ,
        output  wire    [8                   -1 :0]         m_axi_arlen                     ,
        output  wire    [3                   -1 :0]         m_axi_arsize                    ,
        output  wire    [2                   -1 :0]         m_axi_arburst                   ,
        output  wire    [AXI_IDW             -1 :0]         m_axi_arid                      ,

        input   wire                                        m_axi_rvalid                    ,
        input   wire    [AXI_IDW             -1 :0]         m_axi_rid                       ,
        input   wire    [AXI_DW              -1 :0]         m_axi_rdata                     ,
        input   wire    [2                   -1 :0]         m_axi_rresp                     ,
        input   wire                                        m_axi_rlast                     ,
        output  wire                                        m_axi_rready                    ,

        output  wire                                        o_ci_valid                      ,
        input   wire                                        i_ci_ready                      ,
        output  wire                                        o_ci_input_type                 ,
        output  wire    [3                   -1 :0]         o_ci_alen                       ,
        output  wire    [5                   -1 :0]         o_ci_format                     ,
        output  wire    [4                   -1 :0]         o_ci_metadata                   ,
        output  wire                                        o_ci_lossy                      ,
        output  wire    [2                   -1 :0]         o_ci_alpha_mode                 ,
        output  wire    [SB_WIDTH            -1 :0]         o_ci_sb                         ,

        output  wire                                        o_tile_coord_vld                ,
        output  wire    [5                   -1 :0]         o_tile_format                   ,
        output  wire    [12                  -1 :0]         o_tile_x_coord                  ,
        output  wire    [10                  -1 :0]         o_tile_y_coord                  ,
        output  wire    [4                   -1 :0]         o_tile_fcnt                     ,

        output  wire                                        o_cvi_valid                     ,
        output  wire    [256                 -1 :0]         o_cvi_data                      ,
        output  wire                                        o_cvi_last                      ,
        input   wire                                        i_cvi_ready                     ,

        output  wire                                        o_busy                          ,
        output  reg     [32                  -1 :0]         cmd_fail_cnt
    );

    localparam  integer                             AR_ADDR_W                       = AXI_AW - 4;
    localparam  integer                             CI_Y_LSB                        = 0;
    localparam  integer                             CI_Y_MSB                        = 9;
    localparam  integer                             CI_X_LSB                        = 10;
    localparam  integer                             CI_X_MSB                        = 21;
    localparam  integer                             CI_ALEN_LSB                     = 22;
    localparam  integer                             CI_ALEN_MSB                     = 24;
    localparam  integer                             CI_META_LSB                     = 25;
    localparam  integer                             CI_META_MSB                     = 28;
    localparam  integer                             CI_FORMAT_LSB                   = 29;
    localparam  integer                             CI_FORMAT_MSB                   = 33;
    localparam  integer                             CI_PAYLOAD_BIT                  = 34;
    localparam  integer                             CI_ADDR_LSB                     = 35;
    localparam  integer                             CI_ADDR_MSB                     = CI_ADDR_LSB + AXI_AW - 1;
    localparam  integer                             CI_ID_LSB                       = CI_ADDR_MSB + 1;
    localparam  integer                             CI_ID_MSB                       = CI_ID_LSB + AXI_IDW - 1;
    localparam  integer                             CI_FCNT_LSB                     = CI_ID_MSB + 1;
    localparam  integer                             CI_FCNT_MSB                     = CI_FCNT_LSB + 4 - 1;
    localparam  integer                             CI_FIFO_W                       = CI_FCNT_MSB + 1;
    localparam  integer                             RDATA_FIFO_W                    = AXI_DW + 1;
    localparam  [3                   -1 :0]         AXI_ARSIZE                      = 3'($clog2(AXI_DW >> 3));

    wire                                            tile_cmd_valid                  ;
    wire                                            tile_cmd_ready                  ;
    wire        [AR_ADDR_W           -1 :0]         tile_cmd_addr                   ;
    wire        [5                   -1 :0]         tile_cmd_format                 ;
    wire        [4                   -1 :0]         tile_cmd_meta                   ;
    wire        [3                   -1 :0]         tile_cmd_alen                   ;
    wire                                            tile_cmd_has_payload            ;
    wire        [4                   -1 :0]         tile_cmd_fcnt                   ;
    wire        [AXI_AW              -1 :0]         tile_cmd_addr_full              ;
    wire        [AXI_IDW             -1 :0]         tile_cmd_axi_id                 ;
    wire        [CI_FIFO_W           -1 :0]         ci_fifo_din                     ;
    wire        [CI_FIFO_W           -1 :0]         ci_fifo_dout                    ;
    wire                                            ci_fifo_full                    ;
    wire                                            ci_fifo_empty                   ;
    wire                                            ci_fifo_valid                   ;
    wire                                            ci_fifo_wr_en                   ;
    wire                                            ci_fifo_rd_en                   ;
    wire                                            ci_fifo_has_payload             ;
    wire        [AXI_AW              -1 :0]         ci_fifo_addr                    ;
    wire        [AXI_IDW             -1 :0]         ci_fifo_axi_id                  ;
    wire        [3                   -1 :0]         ci_fifo_alen                    ;
    wire        [4                   -1 :0]         ci_fifo_payload_beats           ;
    wire        [CI_FIFO_W           -1 :0]         ci_pending_fifo_dout            ;
    wire                                            ci_pending_fifo_full            ;
    wire                                            ci_pending_fifo_empty           ;
    wire                                            ci_pending_fifo_valid           ;
    wire                                            ci_pending_fifo_wr_en           ;
    wire                                            ci_pending_fifo_rd_en           ;
    wire                                            ci_pending_has_payload          ;
    wire        [AXI_IDW             -1 :0]         ci_pending_axi_id               ;
    wire        [3                   -1 :0]         ci_pending_alen                 ;
    wire        [4                   -1 :0]         ci_pending_payload_beats        ;
    wire        [RDATA_FIFO_W        -1 :0]         rdata_fifo_din                  ;
    wire        [RDATA_FIFO_W        -1 :0]         rdata_fifo_dout                 ;
    wire                                            rdata_fifo_full                 ;
    wire                                            rdata_fifo_empty                ;
    wire                                            rdata_fifo_valid                ;
    wire                                            rdata_fifo_wr_en                ;
    wire                                            rdata_fifo_rd_en                ;
    wire                                            rdata_fifo_last                 ;
    wire                                            ar_split_active                 ;
    wire        [AXI_AW              -1 :0]         ar_req_addr                     ;
    wire        [AXI_IDW             -1 :0]         ar_req_axi_id                   ;
    wire        [4                   -1 :0]         ar_req_beats_left               ;
    wire        [8                   -1 :0]         ar_boundary_beats               ;
    wire        [4                   -1 :0]         ar_issue_beats                  ;
    wire        [4                   -1 :0]         ar_next_beats_left              ;
    wire        [AXI_AW              -1 :0]         ar_next_addr                    ;
    wire                                            ar_valid_from_fifo              ;
    wire                                            ar_fire                         ;
    wire                                            ar_first_fire                   ;
    wire                                            ci_fifo_no_payload_fire         ;
    wire                                            payload_active                  ;
    wire                                            ci_out_fire                     ;
    wire        [4                   -1 :0]         ci_out_fcnt                     ;
    wire                                            ci_payload_stream_start          ;
    wire        [4                   -1 :0]         ci_payload_stream_beats          ;
    wire                                            ci_out_can_load                 ;
    wire                                            ci_pending_done_can_load        ;
    wire                                            ci_pending_load_no_payload      ;
    wire                                            r_collect_active                ;
    wire        [4                   -1 :0]         r_collect_beats_left            ;
    wire                                            r_collect_last                  ;
    wire                                            r_collect_ready                 ;
    wire                                            r_fire                          ;
    wire                                            r_resp_ok                       ;
    wire                                            r_collect_done                  ;
    wire                                            cvi_stream_last                 ;

    reg         [AXI_AW              -1 :0]         ar_req_addr_reg                 ;
    reg         [AXI_IDW             -1 :0]         ar_req_axi_id_reg               ;
    reg         [4                   -1 :0]         ar_req_beats_left_reg           ;
    reg         [4                   -1 :0]         payload_beats_left_reg          ;
    reg         [CI_FIFO_W           -1 :0]         ci_out_data_reg                 ;
    reg                                             ci_out_valid_reg                ;
    reg                                             cvi_stream_active_reg           ;
    reg         [4                   -1 :0]         cvi_stream_beats_left_reg       ;
    reg                                             ci_pending_payload_done_reg     ;
    reg                                             r_burst_fail_reg                ;

    ubwc_tile_addr #(
        .ADDR_W                         ( AXI_AW                                )
    ) u_ubwc_tile_addr (
        .i_cfg_lvl2_bank_swizzle_en      ( i_cfg_lvl2_bank_swizzle_en            ),
        .i_cfg_lvl3_bank_swizzle_en      ( i_cfg_lvl3_bank_swizzle_en            ),
        .i_cfg_highest_bank_bit          ( i_cfg_highest_bank_bit                ),
        .i_cfg_bank_spread_en            ( i_cfg_bank_spread_en                  ),
        .i_cfg_is_lossy_rgba_2_1_format  ( i_cfg_is_lossy_rgba_2_1_format        ),
        .i_cfg_pitch                     ( i_cfg_pitch                           ),
        .i_cfg_base_addr_rgba_y0         ( i_cfg_base_addr_rgba_y0               ),
        .i_cfg_base_addr_uv0             ( i_cfg_base_addr_uv0                   ),
        .i_cfg_base_addr_rgba_y1         ( i_cfg_base_addr_rgba_y1               ),
        .i_cfg_base_addr_uv1             ( i_cfg_base_addr_uv1                   ),
        .i_meta_valid                    ( dec_meta_valid                        ),
        .o_meta_ready                    ( dec_meta_ready                        ),
        .i_meta_format                   ( dec_meta_format                       ),
        .i_meta_flag                     ( dec_meta_flag                         ),
        .i_meta_alen                     ( dec_meta_alen                         ),
        .i_meta_has_payload              ( dec_meta_has_payload                  ),
        .i_meta_x                        ( dec_meta_x                            ),
        .i_meta_y                        ( dec_meta_y                            ),
        .i_meta_fcnt                     ( dec_meta_fcnt                         ),
        .o_cmd_valid                     ( tile_cmd_valid                        ),
        .i_cmd_ready                     ( tile_cmd_ready                        ),
        .o_cmd_addr                      ( tile_cmd_addr                         ),
        .o_cmd_format                    ( tile_cmd_format                       ),
        .o_cmd_meta                      ( tile_cmd_meta                         ),
        .o_cmd_alen                      ( tile_cmd_alen                         ),
        .o_cmd_has_payload               ( tile_cmd_has_payload                  ),
        .o_cmd_fcnt                      ( tile_cmd_fcnt                         )
    );

    mg_sync_fifo #(
        .PROG_DEPTH                    ( 1                                     ),
        .DWIDTH                        ( CI_FIFO_W                             ),
        .DEPTH                         ( 64                                    ),
        .SHOW_AHEAD                    ( 1                                     )
    ) u_ci_fifo (
        .clk                           ( clk                                   ),
        .rst_n                         ( rst_n                                 ),
        .wr_en                         ( ci_fifo_wr_en                         ),
        .din                           ( ci_fifo_din                           ),
        .prog_full                     (                                       ),
        .full                          ( ci_fifo_full                          ),
        .rd_en                         ( ci_fifo_rd_en                         ),
        .empty                         ( ci_fifo_empty                         ),
        .dout                          ( ci_fifo_dout                          ),
        .valid                         ( ci_fifo_valid                         ),
        .data_count                    (                                       )
    );

    mg_sync_fifo #(
        .PROG_DEPTH                    ( 1                                     ),
        .DWIDTH                        ( CI_FIFO_W                             ),
        .DEPTH                         ( 64                                    ),
        .SHOW_AHEAD                    ( 1                                     )
    ) u_ci_pending_fifo (
        .clk                           ( clk                                   ),
        .rst_n                         ( rst_n                                 ),
        .wr_en                         ( ci_pending_fifo_wr_en                 ),
        .din                           ( ci_fifo_dout                          ),
        .prog_full                     (                                       ),
        .full                          ( ci_pending_fifo_full                  ),
        .rd_en                         ( ci_pending_fifo_rd_en                 ),
        .empty                         ( ci_pending_fifo_empty                 ),
        .dout                          ( ci_pending_fifo_dout                  ),
        .valid                         ( ci_pending_fifo_valid                 ),
        .data_count                    (                                       )
    );

    mg_sync_fifo #(
        .PROG_DEPTH                    ( 1                                     ),
        .DWIDTH                        ( RDATA_FIFO_W                         ),
        .DEPTH                         ( 32                                    ),
        .SHOW_AHEAD                    ( 1                                     )
    ) u_rdata_fifo (
        .clk                           ( clk                                   ),
        .rst_n                         ( rst_n                                 ),
        .wr_en                         ( rdata_fifo_wr_en                      ),
        .din                           ( rdata_fifo_din                        ),
        .prog_full                     (                                       ),
        .full                          ( rdata_fifo_full                       ),
        .rd_en                         ( rdata_fifo_rd_en                      ),
        .empty                         ( rdata_fifo_empty                      ),
        .dout                          ( rdata_fifo_dout                       ),
        .valid                         ( rdata_fifo_valid                      ),
        .data_count                    (                                       )
    );

    assign tile_cmd_addr_full         = {tile_cmd_addr, 4'b0000};
    assign tile_cmd_axi_id            = tile_cmd_fcnt;
    assign ci_fifo_din                = {tile_cmd_fcnt, tile_cmd_axi_id, tile_cmd_addr_full, tile_cmd_has_payload, tile_cmd_format, tile_cmd_meta, tile_cmd_alen, dec_meta_x, dec_meta_y};
    assign ci_fifo_wr_en              = tile_cmd_valid && tile_cmd_ready;
    assign ci_fifo_has_payload        = ci_fifo_dout[CI_PAYLOAD_BIT];
    assign ci_fifo_addr               = ci_fifo_dout[CI_ADDR_MSB:CI_ADDR_LSB];
    assign ci_fifo_axi_id             = ci_fifo_dout[CI_ID_MSB:CI_ID_LSB];
    assign ci_fifo_alen               = ci_fifo_dout[CI_ALEN_MSB:CI_ALEN_LSB];
    assign ci_fifo_payload_beats      = {1'b0, ci_fifo_alen} + 4'd1;
    assign ci_pending_has_payload     = ci_pending_fifo_dout[CI_PAYLOAD_BIT];
    assign ci_pending_axi_id          = ci_pending_fifo_dout[CI_ID_MSB:CI_ID_LSB];
    assign ci_pending_alen            = ci_pending_fifo_dout[CI_ALEN_MSB:CI_ALEN_LSB];
    assign ci_pending_payload_beats   = {1'b0, ci_pending_alen} + 4'd1;
    assign rdata_fifo_last            = rdata_fifo_dout[AXI_DW];
    assign ar_split_active            = (ar_req_beats_left_reg != 4'd0);
    assign ar_req_addr                = ar_split_active ? ar_req_addr_reg : ci_fifo_addr;
    assign ar_req_axi_id              = ar_split_active ? ar_req_axi_id_reg : ci_fifo_axi_id;
    assign ar_req_beats_left          = ar_split_active ? ar_req_beats_left_reg : ci_fifo_payload_beats;
    assign ar_boundary_beats          = 8'd128 - {1'b0, ar_req_addr[11:5]};
    assign ar_issue_beats             = (ar_boundary_beats[7:4] != 4'd0) ? ar_req_beats_left :
                                        ((ar_req_beats_left <= ar_boundary_beats[3:0]) ? ar_req_beats_left : ar_boundary_beats[3:0]);
    assign ar_next_beats_left         = ar_req_beats_left - ar_issue_beats;
    assign ar_next_addr               = ar_req_addr + {{(AXI_AW-9){1'b0}}, ar_issue_beats, 5'b0};
    assign ar_valid_from_fifo         = ci_fifo_valid && ci_fifo_has_payload && !ci_pending_fifo_full && !ar_split_active;
    assign ar_fire                    = m_axi_arvalid && m_axi_arready;
    assign ar_first_fire              = ar_fire && !ar_split_active;
    assign ci_fifo_no_payload_fire    = ci_fifo_valid && !ci_fifo_has_payload && !ci_pending_fifo_full;
    assign payload_active             = (payload_beats_left_reg != 4'd0);
    assign ci_out_fire                = o_ci_valid && i_ci_ready;
    assign ci_out_fcnt                = ci_out_data_reg[CI_FCNT_MSB:CI_FCNT_LSB];
    assign ci_payload_stream_start    = ci_pending_fifo_rd_en && ci_pending_has_payload;
    assign ci_payload_stream_beats    = ci_pending_payload_beats;
    assign ci_out_can_load            = !ci_out_valid_reg;
    assign ci_pending_done_can_load   = ci_pending_payload_done_reg && ci_out_can_load;
    assign ci_pending_load_no_payload = ci_pending_fifo_valid && !ci_pending_has_payload && ci_out_can_load;
    assign r_collect_active           = ci_pending_fifo_valid && ci_pending_has_payload &&
                                        !ci_pending_payload_done_reg &&
                                        !cvi_stream_active_reg &&
                                        ci_out_can_load;
    assign r_collect_beats_left       = payload_active ? payload_beats_left_reg : ci_pending_payload_beats;
    assign r_collect_last             = (r_collect_beats_left <= 4'd1);
    assign r_collect_ready            = !rdata_fifo_full;
    assign r_fire                     = m_axi_rvalid && m_axi_rready && r_collect_active;
    assign r_resp_ok                  = ((m_axi_rresp == 2'b00) || (m_axi_rresp == 2'b01)) &&
                                        (m_axi_rid == ci_pending_axi_id);
    assign r_collect_done             = r_fire && r_collect_last;
    assign cvi_stream_last            = (cvi_stream_beats_left_reg <= 4'd1);
    assign tile_cmd_ready             = !ci_fifo_full;
    assign ci_fifo_rd_en              = ar_first_fire | ci_fifo_no_payload_fire;
    assign ci_pending_fifo_wr_en      = ci_fifo_rd_en;
    assign ci_pending_fifo_rd_en      = (r_collect_done && ci_out_can_load) |
                                        ci_pending_done_can_load |
                                        ci_pending_load_no_payload;
    assign rdata_fifo_din             = {r_collect_last, m_axi_rdata};
    assign rdata_fifo_wr_en           = r_fire;
    assign rdata_fifo_rd_en           = o_cvi_valid && i_cvi_ready;
    assign o_ci_valid                 = ci_out_valid_reg;
    assign o_ci_input_type            = i_cfg_ci_input_type;
    assign o_ci_format                = ci_out_data_reg[CI_FORMAT_MSB:CI_FORMAT_LSB];
    assign o_ci_metadata              = ci_out_data_reg[CI_META_MSB:CI_META_LSB];
    assign o_ci_alen                  = ci_out_data_reg[CI_ALEN_MSB:CI_ALEN_LSB];
    assign o_ci_lossy                 = i_cfg_ci_lossy;
    assign o_ci_alpha_mode            = i_cfg_ci_alpha_mode;
    assign o_ci_sb                    = {{(SB_WIDTH-1){1'b0}}, ci_out_fcnt[0]};
    assign o_tile_coord_vld           = ci_out_fire;
    assign o_tile_format              = ci_out_data_reg[CI_FORMAT_MSB:CI_FORMAT_LSB];
    assign o_tile_x_coord             = ci_out_data_reg[CI_X_MSB:CI_X_LSB];
    assign o_tile_y_coord             = ci_out_data_reg[CI_Y_MSB:CI_Y_LSB];
    assign o_tile_fcnt                = ci_out_fcnt;
    assign m_axi_arvalid              = ar_split_active | ar_valid_from_fifo;
    assign m_axi_araddr               = ar_req_addr;
    assign m_axi_arlen                = {4'd0, ar_issue_beats} - 8'd1;
    assign m_axi_arsize               = AXI_ARSIZE;
    assign m_axi_arburst              = 2'b01;
    assign m_axi_arid                 = ar_req_axi_id;
    assign m_axi_rready               = r_collect_active && r_collect_ready;
    assign o_cvi_valid                = cvi_stream_active_reg && rdata_fifo_valid;
    assign o_cvi_data                 = rdata_fifo_dout[0+:AXI_DW];
    assign o_cvi_last                 = o_cvi_valid && rdata_fifo_last;
    assign o_busy                     = dec_meta_valid | tile_cmd_valid | !ci_fifo_empty |
                                        !ci_pending_fifo_empty | !rdata_fifo_empty |
                                        ci_out_valid_reg | cvi_stream_active_reg |
                                        ar_split_active | payload_active |
                                        m_axi_arvalid | m_axi_rvalid | o_ci_valid | o_cvi_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ar_req_addr_reg <= {AXI_AW{1'b0}};
        else if (ar_fire)
            ar_req_addr_reg <= ar_next_addr;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ar_req_axi_id_reg <= {AXI_IDW{1'b0}};
        else if (ar_fire)
            ar_req_axi_id_reg <= ar_req_axi_id;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ar_req_beats_left_reg <= 4'd0;
        else if (ar_fire)
            ar_req_beats_left_reg <= ar_next_beats_left;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            payload_beats_left_reg <= 4'd0;
        else if (r_collect_done)
            payload_beats_left_reg <= 4'd0;
        else if (r_fire)
            payload_beats_left_reg <= r_collect_beats_left - 4'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ci_out_data_reg <= {CI_FIFO_W{1'b0}};
        else if (ci_pending_fifo_rd_en)
            ci_out_data_reg <= ci_pending_fifo_dout;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ci_out_valid_reg <= 1'b0;
        else if (ci_pending_fifo_rd_en)
            ci_out_valid_reg <= 1'b1;
        else if (ci_out_fire)
            ci_out_valid_reg <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cvi_stream_active_reg <= 1'b0;
        else if (ci_payload_stream_start)
            cvi_stream_active_reg <= 1'b1;
        else if (rdata_fifo_rd_en && cvi_stream_last)
            cvi_stream_active_reg <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cvi_stream_beats_left_reg <= 4'd0;
        else if (ci_payload_stream_start)
            cvi_stream_beats_left_reg <= ci_payload_stream_beats;
        else if (rdata_fifo_rd_en && cvi_stream_last)
            cvi_stream_beats_left_reg <= 4'd0;
        else if (rdata_fifo_rd_en)
            cvi_stream_beats_left_reg <= cvi_stream_beats_left_reg - 4'd1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ci_pending_payload_done_reg <= 1'b0;
        else if (r_collect_done && !ci_out_can_load)
            ci_pending_payload_done_reg <= 1'b1;
        else if (ci_pending_done_can_load)
            ci_pending_payload_done_reg <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            r_burst_fail_reg <= 1'b0;
        else if (i_frame_start)
            r_burst_fail_reg <= 1'b0;
        else if (r_fire && m_axi_rlast)
            r_burst_fail_reg <= 1'b0;
        else if (r_fire && !r_resp_ok)
            r_burst_fail_reg <= 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cmd_fail_cnt <= 32'd0;
        else if (i_frame_start)
            cmd_fail_cnt <= 32'd0;
        else if (r_fire && m_axi_rlast && (r_burst_fail_reg || !r_resp_ok))
            cmd_fail_cnt <= cmd_fail_cnt + 1'b1;
    end

endmodule
