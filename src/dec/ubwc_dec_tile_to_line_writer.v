//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-04-01  23:15:40
// Design Name       :
// Module Name       :
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							:
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module tile_to_line_writer #(
    parameter   integer                             SRAM_ADDR_W                     = 12
)(
    input   wire                                        clk_sram                        ,
    input   wire                                        rst_n                           ,
    input   wire                                        i_frame_start                   ,
    input   wire    [15                     :0]         cfg_img_width                   ,
    input   wire                                        i_sram_a_free                   ,
    input   wire                                        i_sram_b_free                   ,
    input   wire                                        i_uv_slot0_free                 ,
    input   wire                                        i_uv_slot1_free                 ,

    input   wire    [4                      :0]         s_axis_format                   ,
    input   wire    [15                     :0]         s_axis_tile_x                   ,
    input   wire    [15                     :0]         s_axis_tile_y                   ,
    input   wire    [3                      :0]         s_axis_tile_fcnt                ,
    input   wire                                        s_axis_tile_valid               ,
    output  wire                                        s_axis_tile_ready               ,
    input   wire    [255                    :0]         s_axis_tdata                    ,
    input   wire                                        s_axis_tlast                    ,
    input   wire                                        s_axis_tvalid                   ,
    output  wire                                        s_axis_tready                   ,

    output  wire                                        sram_a_wen                      ,
    output  wire    [SRAM_ADDR_W         -1 :0]         sram_a_waddr                    ,
    output  wire    [127                    :0]         sram_a_wdata                    ,
    output  wire                                        sram_b_wen                      ,
    output  wire    [SRAM_ADDR_W         -1 :0]         sram_b_waddr                    ,
    output  wire    [127                    :0]         sram_b_wdata                    ,

    output  reg                                         o_writer_bank                   ,
    output  reg     [3                      :0]         o_writer_fcnt                   ,
    output  reg                                         o_writer_uv_slot                ,
    output  reg                                         o_writer_y_lower_done           ,
    output  reg                                         o_writer_uv_done                ,
    output  reg                                         o_buffer_vld
);

    localparam  integer                             TILE_WRITER_FIFO_DEPTH          = 16;
    localparam  integer                             SRAM_Y_REGION_WORDS            = 2048;
    localparam  integer                             SRAM_UV_SLOT_WORDS             = 1024;

    wire                                            hdr_fifo_empty                  ;
    wire                                            hdr_fifo_full                   ;
    wire                                            hdr_fifo_rd_en                  ;
    wire        [41                  -1 :0]         hdr_fifo_din                    ;
    wire        [41                  -1 :0]         hdr_fifo_dout                   ;
    wire                                            data_fifo_empty                 ;
    wire                                            data_fifo_full                  ;
    wire                                            data_fifo_rd_en                 ;
    wire                                            data_fifo_wr_en                 ;
    wire        [257                 -1 :0]         data_fifo_din                   ;
    wire        [257                 -1 :0]         data_fifo_dout                  ;
    wire                                            tile_ctx_available              ;
    wire                                            frame_start                     ;
    wire                                            tile_hdr_fire                   ;
    wire        [255                    :0]         cur_tdata                       ;
    wire                                            cur_tlast                       ;
    wire        [15                     :0]         cur_tile_x                      ;
    wire        [4                      :0]         cur_fmt                         ;
    wire        [3                      :0]         cur_fcnt                        ;
    wire                                            target_bank_free                ;
    wire                                            target_bank_storage_free        ;
    wire                                            uv_slot_prefer_free             ;
    wire                                            uv_slot_alternate_free          ;
    wire                                            uv_slot_available               ;
    wire                                            uv_slot_first_word              ;
    wire                                            uv_slot_write_sel               ;
    wire                                            uv_slot_addr_sel                ;
    wire                                            wide_profile                    ;
    wire                                            wide_yuv420_profile             ;
    wire                                            write_bank                      ;
    wire                                            sram_wen_req                    ;
    wire                                            sram_wen_internal               ;
    wire        [16                     :0]         p_base_full                     ;
    wire        [16                     :0]         y_lower_base_full               ;
    wire        [16                     :0]         uv_base_full                    ;
    wire        [16                     :0]         uv_split_base_full              ;
    wire        [16                     :0]         uv_slot_size_full               ;
    wire                                            group_row_sel                   ;
    wire                                            wide_yuv420_y_lower_stage       ;
    wire                                            wide_yuv420_uv_second_half      ;
    wire                                            wide_yuv420_bank_offset         ;
    wire        [16                     :0]         v_off_full                      ;
    wire        [2                      :0]         y_in_t                          ;
    wire        [2                      :0]         y_in_t_addr                     ;
    wire        [1                      :0]         x_w_off                         ;
    wire        [16                     :0]         y_off_rgba_full                 ;
    wire        [16                     :0]         y_off_yuv8_full                 ;
    wire        [16                     :0]         y_off_p010_full                 ;
    wire        [16                     :0]         y_off_full                      ;
    wire        [16                     :0]         tile_cols                       ;
    wire        [15                     :0]         max_tile_x                      ;
    wire                                            last_tile_x                     ;
    wire                                            tile_coord_active               ;
    wire        [16                     :0]         tile_x_word_base_full           ;
    wire        [16                     :0]         x_w_off_ext_full                ;
    wire        [16                     :0]         waddr_full                      ;
    wire        [SRAM_ADDR_W         -1 :0]         waddr                           ;
    wire        [127                    :0]         wdata                           ;
    wire                                            sram_write_active               ;
    wire                                            tile_last_write                 ;
    wire                                            rowgroup_done                   ;
    wire                                            slice_done                      ;
    wire                                            wide_yuv420_y_upper_ready       ;
    wire                                            wide_yuv420_y_ready             ;
    wire                                            writer_buffer_ready             ;

    reg                                             is_y_stride_1k                  ;
    reg                                             is_row_len_2                    ;
    reg                                             is_uv_plane                     ;
    reg                                             is_yuv420                       ;
    reg                                             is_rgba                         ;
    reg                                             is_p010                         ;
    reg                                             wr_bank                         ;
    reg                                             uv_slot_sel                     ;
    reg                                             uv_slot_active_sel              ;
    reg                                             uv_slot_done_sel                ;
    reg         [1                      :0]         y420_stage                      ;
    reg                                             gearbox_sel                     ;
    reg         [3                      :0]         cnt_write                       ;

    assign hdr_fifo_din               = {s_axis_tile_fcnt,
                                         s_axis_format,
                                         s_axis_tile_x,
                                         s_axis_tile_y};
    assign data_fifo_din              = {s_axis_tlast,
                                         s_axis_tdata};
    assign data_fifo_wr_en            = s_axis_tvalid && s_axis_tready;

    mg_sync_fifo #(
        .PROG_DEPTH                    ( 1                                     ),
        .DWIDTH                        ( 41                                    ),
        .DEPTH                         ( TILE_WRITER_FIFO_DEPTH                ),
        .SHOW_AHEAD                    ( 1                                     ),
        .RAM_STYLE                     ( "distributed"                         )
    ) u_hdr_fifo (
        .clk                           ( clk_sram                              ),
        .rst_n                         ( rst_n                                 ),
        .wr_en                         ( tile_hdr_fire                         ),
        .din                           ( hdr_fifo_din                          ),
        .prog_full                     (                                       ),
        .full                          ( hdr_fifo_full                         ),
        .rd_en                         ( hdr_fifo_rd_en                        ),
        .empty                         ( hdr_fifo_empty                        ),
        .dout                          ( hdr_fifo_dout                         ),
        .valid                         (                                       ),
        .data_count                    (                                       )
    );

    mg_sync_fifo #(
        .PROG_DEPTH                    ( 1                                     ),
        .DWIDTH                        ( 257                                   ),
        .DEPTH                         ( TILE_WRITER_FIFO_DEPTH                ),
        .SHOW_AHEAD                    ( 1                                     ),
        .RAM_STYLE                     ( "distributed"                         )
    ) u_data_fifo (
        .clk                           ( clk_sram                              ),
        .rst_n                         ( rst_n                                 ),
        .wr_en                         ( data_fifo_wr_en                      ),
        .din                           ( data_fifo_din                         ),
        .prog_full                     (                                       ),
        .full                          ( data_fifo_full                        ),
        .rd_en                         ( data_fifo_rd_en                       ),
        .empty                         ( data_fifo_empty                       ),
        .dout                          ( data_fifo_dout                        ),
        .valid                         (                                       ),
        .data_count                    (                                       )
    );

    assign frame_start                = (i_frame_start == 1'b1);
    assign s_axis_tile_ready          = ~hdr_fifo_full;
    assign tile_hdr_fire              = s_axis_tile_valid && s_axis_tile_ready;
    assign tile_ctx_available         = !hdr_fifo_empty || (s_axis_tile_valid && s_axis_tile_ready);
    assign s_axis_tready              = ~data_fifo_full && tile_ctx_available;
    assign cur_tdata                  = data_fifo_dout[255:0];
    assign cur_tlast                  = data_fifo_dout[256];
    assign cur_tile_x                 = hdr_fifo_dout[31:16];
    assign cur_fmt                    = hdr_fifo_dout[36:32];
    assign cur_fcnt                   = hdr_fifo_dout[40:37];
    assign wide_profile               = (cfg_img_width > 16'd2048);
    assign wide_yuv420_profile        = is_yuv420;
    assign wide_yuv420_y_lower_stage  = wide_yuv420_profile && !is_uv_plane &&
                                        (y420_stage == 2'd2);
    assign wide_yuv420_uv_second_half = wide_yuv420_profile && is_uv_plane &&
                                        (is_p010 ? y_in_t[1] : y_in_t[2]);
    assign wide_yuv420_bank_offset    = wide_yuv420_y_lower_stage ||
                                        wide_yuv420_uv_second_half;
    assign write_bank                 = wide_yuv420_profile ? (wr_bank ^ wide_yuv420_bank_offset) :
                                                              wr_bank;
    assign uv_slot_prefer_free        = uv_slot_sel ? i_uv_slot1_free :
                                                      i_uv_slot0_free;
    assign uv_slot_alternate_free     = uv_slot_sel ? i_uv_slot0_free :
                                                      i_uv_slot1_free;
    assign uv_slot_available          = uv_slot_prefer_free || uv_slot_alternate_free;
    assign uv_slot_first_word         = wide_yuv420_profile && is_uv_plane &&
                                        (cur_tile_x == 16'd0) && (cnt_write == 4'd0);
    assign uv_slot_write_sel          = uv_slot_prefer_free ? uv_slot_sel :
                                                             ~uv_slot_sel;
    assign uv_slot_addr_sel           = uv_slot_first_word ? uv_slot_write_sel :
                                                             uv_slot_active_sel;
    assign target_bank_storage_free   = !tile_coord_active ? 1'b1 :
                                        (wide_yuv420_profile && is_uv_plane) ?
                                        (!uv_slot_first_word || uv_slot_available) :
                                        (write_bank ? i_sram_b_free : i_sram_a_free);
    assign target_bank_free           = target_bank_storage_free;
    assign sram_wen_req               = (!hdr_fifo_empty) && (!data_fifo_empty) &&
                                        target_bank_free && !o_buffer_vld;
    assign sram_wen_internal          = sram_wen_req;
    assign data_fifo_rd_en            = sram_wen_internal && gearbox_sel;
    assign y_lower_base_full          = wide_yuv420_profile ? 17'(SRAM_Y_REGION_WORDS) :
                                        (wide_profile ? 17'd2048 :
                                                        17'd1024);
    assign uv_slot_size_full          = wide_yuv420_profile ? 17'(SRAM_UV_SLOT_WORDS) :
                                        (wide_profile ? 17'd1024 :
                                                        17'd512);
    assign uv_split_base_full         = (wide_yuv420_profile && uv_slot_addr_sel) ?
                                        (y_lower_base_full + uv_slot_size_full) :
                                        y_lower_base_full;
    assign uv_base_full               = wide_yuv420_profile ? 17'd0 :
                                        (wide_profile ? 17'd4096 :
                                                        17'd2048);
    assign p_base_full                = is_uv_plane ? (wide_yuv420_profile ? uv_split_base_full :
                                                                               uv_base_full) :
                                                       17'd0;
    assign group_row_sel              = (!wide_yuv420_profile && !is_uv_plane && is_yuv420) ?
                                        (y420_stage == 2'd1) :
                                        1'b0;
    assign v_off_full                 = group_row_sel ? y_lower_base_full : 17'd0;
    assign y_in_t                     = is_row_len_2 ? cnt_write[3:1] : {1'b0, cnt_write[3:2]};
    assign y_in_t_addr                = (wide_yuv420_profile && is_uv_plane) ?
                                        (is_p010 ? {2'd0, y_in_t[0]} :
                                                   {1'b0, y_in_t[1:0]}) :
                                        y_in_t;
    assign x_w_off                    = is_row_len_2 ? {1'b0, cnt_write[0]} : cnt_write[1:0];
    assign y_off_rgba_full            = wide_profile ? {4'd0, y_in_t_addr, 10'd0} :
                                                       {5'd0, y_in_t_addr, 9'd0};
    assign y_off_yuv8_full            = (wide_profile || wide_yuv420_profile) ?
                                        {6'd0, y_in_t_addr, 8'd0} :
                                        {7'd0, y_in_t_addr, 7'd0};
    assign y_off_p010_full            = (wide_profile || wide_yuv420_profile) ?
                                        {5'd0, y_in_t_addr, 9'd0} :
                                        {6'd0, y_in_t_addr, 8'd0};
    assign y_off_full                 = is_y_stride_1k ? y_off_rgba_full :
                                        (is_p010 ? y_off_p010_full : y_off_yuv8_full);
    assign tile_cols                  = is_rgba ?
                                        (({1'b0, cfg_img_width} + 17'd15) >> 4) :
                                        (({1'b0, cfg_img_width} + 17'd31) >> 5);
    assign max_tile_x                 = (tile_cols == 0) ? 16'd0 : (tile_cols[15:0] - 1'b1);
    assign last_tile_x                = (cur_tile_x == max_tile_x);
    assign tile_coord_active          = ({1'b0, cur_tile_x} < tile_cols);
    assign tile_x_word_base_full      = (is_rgba || is_p010) ?
                                        ({1'b0, cur_tile_x} << 2) :
                                        ({1'b0, cur_tile_x} << 1);
    assign x_w_off_ext_full           = {15'd0, x_w_off};
    assign waddr_full                 = p_base_full + v_off_full + y_off_full +
                                        tile_x_word_base_full + x_w_off_ext_full;
    assign waddr                      = waddr_full[SRAM_ADDR_W-1:0];
    assign wdata                      = gearbox_sel ? cur_tdata[255:128] : cur_tdata[127:0];
    assign sram_write_active          = sram_wen_internal && tile_coord_active;
    assign tile_last_write            = sram_wen_internal && cur_tlast && gearbox_sel;
    assign rowgroup_done              = tile_last_write && last_tile_x;
    assign slice_done                 = tile_last_write && last_tile_x && (is_rgba || is_uv_plane);
    assign wide_yuv420_y_upper_ready  = wide_yuv420_profile && !is_uv_plane && rowgroup_done &&
                                        (y420_stage == 2'd1);
    assign wide_yuv420_y_ready        = wide_yuv420_profile && !is_uv_plane && rowgroup_done &&
                                        (y420_stage == 2'd2);
    assign writer_buffer_ready        = wide_yuv420_profile ? wide_yuv420_y_upper_ready :
                                                              slice_done;
    assign hdr_fifo_rd_en             = tile_last_write;
    assign sram_a_wen                 = sram_write_active & (~write_bank);
    assign sram_b_wen                 = sram_write_active & (write_bank);
    assign sram_a_waddr               = waddr;
    assign sram_b_waddr               = waddr;
    assign sram_a_wdata               = wdata;
    assign sram_b_wdata               = wdata;

    always @(*) begin
        case (cur_fmt)
            5'b00000, 5'b00001: begin
                is_y_stride_1k = 1'b1; is_row_len_2 = 1'b0;
                is_uv_plane = 1'b0; is_yuv420 = 1'b0; is_rgba = 1'b1; is_p010 = 1'b0;
            end
            5'b01000: begin
                is_y_stride_1k = 1'b0; is_row_len_2 = 1'b1;
                is_uv_plane = 1'b0; is_yuv420 = 1'b1; is_rgba = 1'b0; is_p010 = 1'b0;
            end
            5'b01001: begin
                is_y_stride_1k = 1'b0; is_row_len_2 = 1'b1;
                is_uv_plane = 1'b1; is_yuv420 = 1'b1; is_rgba = 1'b0; is_p010 = 1'b0;
            end
            5'b01110: begin
                is_y_stride_1k = 1'b0; is_row_len_2 = 1'b0;
                is_uv_plane = 1'b0; is_yuv420 = 1'b1; is_rgba = 1'b0; is_p010 = 1'b1;
            end
            5'b01111: begin
                is_y_stride_1k = 1'b0; is_row_len_2 = 1'b0;
                is_uv_plane = 1'b1; is_yuv420 = 1'b1; is_rgba = 1'b0; is_p010 = 1'b1;
            end
            default:  begin
                is_y_stride_1k = 1'b1; is_row_len_2 = 1'b0;
                is_uv_plane = 1'b0; is_yuv420 = 1'b0; is_rgba = 1'b1; is_p010 = 1'b0;
            end
        endcase
    end

    // For YUV420, one slice is written as three full-width passes:
    // 1) UV, 2) Y upper, 3) Y lower.

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) gearbox_sel <= 1'b0;
        else if (frame_start) gearbox_sel <= 1'b0;
        else if (sram_wen_internal) gearbox_sel <= ~gearbox_sel;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            cnt_write <= 0;
        else if (frame_start)
            cnt_write <= 0;
        else if (sram_wen_internal)
            cnt_write <= tile_last_write ? 4'd0 : cnt_write + 1'b1;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            wr_bank <= 0;
        else if (frame_start)
            wr_bank <= 0;
        else if (sram_wen_internal && slice_done && !wide_yuv420_profile)
            wr_bank <= ~wr_bank;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_writer_bank <= 0;
        else if (frame_start)
            o_writer_bank <= 0;
        else if (sram_wen_internal && writer_buffer_ready)
            o_writer_bank <= wr_bank;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_writer_fcnt <= 4'd0;
        else if (frame_start)
            o_writer_fcnt <= 4'd0;
        else if (sram_wen_internal && writer_buffer_ready)
            o_writer_fcnt <= cur_fcnt;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_writer_uv_slot <= 1'b0;
        else if (frame_start)
            o_writer_uv_slot <= 1'b0;
        else if (sram_wen_internal && slice_done && wide_yuv420_profile)
            o_writer_uv_slot <= uv_slot_active_sel;
        else if (sram_wen_internal && writer_buffer_ready)
            o_writer_uv_slot <= uv_slot_done_sel;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_writer_y_lower_done <= 1'b0;
        else if (frame_start)
            o_writer_y_lower_done <= 1'b0;
        else
            o_writer_y_lower_done <= sram_wen_internal && wide_yuv420_y_ready;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_writer_uv_done <= 1'b0;
        else if (frame_start)
            o_writer_uv_done <= 1'b0;
        else
            o_writer_uv_done <= sram_wen_internal && slice_done && wide_yuv420_profile;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_buffer_vld <= 0;
        else if (frame_start)
            o_buffer_vld <= 0;
        else
            o_buffer_vld <= sram_wen_internal && writer_buffer_ready;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            y420_stage <= 2'd0;
        else if (frame_start)
            y420_stage <= 2'd0;
        else if (sram_wen_internal && rowgroup_done && !is_yuv420)
            y420_stage <= 2'd0;
        else if (sram_wen_internal && rowgroup_done && (y420_stage == 2'd0))
            y420_stage <= 2'd1;
        else if (sram_wen_internal && rowgroup_done && (y420_stage == 2'd1))
            y420_stage <= 2'd2;
        else if (sram_wen_internal && rowgroup_done)
            y420_stage <= 2'd0;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            uv_slot_sel <= 1'b0;
        else if (frame_start)
            uv_slot_sel <= 1'b0;
        else if (sram_wen_internal && slice_done && wide_yuv420_profile)
            uv_slot_sel <= ~uv_slot_active_sel;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            uv_slot_active_sel <= 1'b0;
        else if (frame_start)
            uv_slot_active_sel <= 1'b0;
        else if (sram_wen_internal && uv_slot_first_word)
            uv_slot_active_sel <= uv_slot_write_sel;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            uv_slot_done_sel <= 1'b0;
        else if (frame_start)
            uv_slot_done_sel <= 1'b0;
        else if (sram_wen_internal && slice_done && wide_yuv420_profile)
            uv_slot_done_sel <= uv_slot_active_sel;
    end

endmodule
