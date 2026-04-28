`timescale 1ns / 1ps

module ubwc_dec_tile_to_otf_line_ring (
    input  wire           clk_sram,
    input  wire           rst_n,
    input  wire           i_frame_start,
    input  wire [15:0]    cfg_img_width,
    input  wire [4:0]     cfg_format,
    input  wire [15:0]    cfg_otf_v_act,

    input  wire [4:0]     s_axis_format,
    input  wire [15:0]    s_axis_tile_x,
    input  wire [15:0]    s_axis_tile_y,
    input  wire           s_axis_tile_valid,
    output wire           s_axis_tile_ready,
    input  wire [255:0]   s_axis_tdata,
    input  wire           s_axis_tlast,
    input  wire           s_axis_tvalid,
    output wire           s_axis_tready,

    output wire           sram_a_wen,
    output wire [12:0]    sram_a_waddr,
    output wire [127:0]   sram_a_wdata,
    output wire           sram_a_ren,
    output wire [12:0]    sram_a_raddr,
    input  wire [127:0]   sram_a_rdata,
    input  wire           sram_a_rvalid,
    output wire           sram_b_wen,
    output wire [12:0]    sram_b_waddr,
    output wire [127:0]   sram_b_wdata,
    output wire           sram_b_ren,
    output wire [12:0]    sram_b_raddr,
    input  wire [127:0]   sram_b_rdata,
    input  wire           sram_b_rvalid,

    output reg            o_fifo_wr_en,
    output reg  [255:0]   o_fifo_wdata,
    input  wire           i_fifo_full,

    output wire           o_writer_vld,
    output wire           o_fetcher_req,
    output reg            o_fetcher_done,
    output wire           o_sram_a_free,
    output wire           o_sram_b_free,
    output wire           o_busy
);

    localparam integer                  LINE_RING_DEPTH            = 32;
    localparam integer                  LINE_SLOT_W                = 5;
    localparam integer                  TILE_FIFO_DEPTH            = 16;
    localparam integer                  TILE_DATA_BEATS            = 8;
    localparam integer                  DATA_CREDIT_W              = 6;

    localparam [1:0]                    RD_IDLE                    = 2'd0;
    localparam [1:0]                    RD_WAIT_Y                  = 2'd1;
    localparam [1:0]                    RD_WAIT_SECOND             = 2'd2;
    localparam [1:0]                    RD_PUSH                    = 2'd3;

    wire                                frame_start                = (i_frame_start == 1'b1);
    wire                                hdr_fifo_empty;
    wire                                hdr_fifo_full;
    wire                                hdr_fifo_rd_en;
    wire    [37             -1:0]       hdr_fifo_dout;
    wire                                hdr_fifo_prog_full;
    wire                                hdr_fifo_valid;
    wire    [5              -1:0]       hdr_fifo_data_count;
    wire                                data_fifo_empty;
    wire                                data_fifo_full;
    wire                                data_fifo_rd_en;
    wire    [257            -1:0]       data_fifo_dout;
    wire                                data_fifo_prog_full;
    wire                                data_fifo_valid;
    wire    [5              -1:0]       data_fifo_data_count;
    wire                                tile_hdr_fire;
    wire                                tile_ctx_available;
    wire                                data_credit_has_room;
    reg     [DATA_CREDIT_W -1:0]        data_credit_used;

    assign data_credit_has_room = (data_credit_used <= DATA_CREDIT_W'(TILE_FIFO_DEPTH - TILE_DATA_BEATS));
    assign s_axis_tile_ready    = !hdr_fifo_full && data_credit_has_room;
    assign tile_hdr_fire        = s_axis_tile_valid && s_axis_tile_ready;
    assign tile_ctx_available   = !hdr_fifo_empty || tile_hdr_fire;
    assign s_axis_tready        = !data_fifo_full && tile_ctx_available;

    mg_sync_fifo #(
        .PROG_DEPTH                    ( 1                                     ),
        .DWIDTH                        ( 37                                    ),
        .DEPTH                         ( TILE_FIFO_DEPTH                       ),
        .SHOW_AHEAD                    ( 1                                     ),
        .RAM_STYLE                     ( "distributed"                         )
    ) u_hdr_fifo (
        .clk                           ( clk_sram                              ),
        .rst_n                         ( rst_n && !frame_start                 ),
        .wr_en                         ( tile_hdr_fire                         ),
        .din                           ( {s_axis_format, s_axis_tile_x, s_axis_tile_y} ),
        .prog_full                     ( hdr_fifo_prog_full                    ),
        .full                          ( hdr_fifo_full                         ),
        .rd_en                         ( hdr_fifo_rd_en                        ),
        .empty                         ( hdr_fifo_empty                        ),
        .dout                          ( hdr_fifo_dout                         ),
        .valid                         ( hdr_fifo_valid                        ),
        .data_count                    ( hdr_fifo_data_count                   )
    );

    mg_sync_fifo #(
        .PROG_DEPTH                    ( 1                                     ),
        .DWIDTH                        ( 257                                   ),
        .DEPTH                         ( TILE_FIFO_DEPTH                       ),
        .SHOW_AHEAD                    ( 1                                     ),
        .RAM_STYLE                     ( "distributed"                         )
    ) u_data_fifo (
        .clk                           ( clk_sram                              ),
        .rst_n                         ( rst_n && !frame_start                 ),
        .wr_en                         ( s_axis_tvalid && s_axis_tready        ),
        .din                           ( {s_axis_tlast, s_axis_tdata}          ),
        .prog_full                     ( data_fifo_prog_full                   ),
        .full                          ( data_fifo_full                        ),
        .rd_en                         ( data_fifo_rd_en                       ),
        .empty                         ( data_fifo_empty                       ),
        .dout                          ( data_fifo_dout                        ),
        .valid                         ( data_fifo_valid                       ),
        .data_count                    ( data_fifo_data_count                  )
    );

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) begin
            data_credit_used <= {DATA_CREDIT_W{1'b0}};
        end else if (frame_start) begin
            data_credit_used <= {DATA_CREDIT_W{1'b0}};
        end else begin
            case ({tile_hdr_fire, data_fifo_rd_en})
                2'b10: data_credit_used <= data_credit_used + DATA_CREDIT_W'(TILE_DATA_BEATS);
                2'b01: data_credit_used <= data_credit_used - {{(DATA_CREDIT_W-1){1'b0}}, 1'b1};
                2'b11: data_credit_used <= data_credit_used + DATA_CREDIT_W'(TILE_DATA_BEATS - 1);
                default: data_credit_used <= data_credit_used;
            endcase
        end
    end

    wire    [255:0]                     cur_tdata                   = data_fifo_dout[255:0];
    wire                                cur_tlast                   = data_fifo_dout[256];
    wire    [15:0]                      cur_tile_y                  = hdr_fifo_dout[15:0];
    wire    [15:0]                      cur_tile_x                  = hdr_fifo_dout[31:16];
    wire    [4:0]                       cur_fmt                     = hdr_fifo_dout[36:32];

    reg                                 cur_is_y_stride_1k;
    reg                                 cur_is_row_len_2;
    reg                                 cur_is_uv_plane;
    reg                                 cur_is_yuv420;
    reg                                 cur_is_rgba;
    reg                                 cur_is_p010;

    always @(*) begin
        case (cur_fmt)
            5'b00000, 5'b00001: begin
                cur_is_y_stride_1k = 1'b1; cur_is_row_len_2 = 1'b0;
                cur_is_uv_plane = 1'b0; cur_is_yuv420 = 1'b0; cur_is_rgba = 1'b1; cur_is_p010 = 1'b0;
            end
            5'b01000: begin
                cur_is_y_stride_1k = 1'b0; cur_is_row_len_2 = 1'b1;
                cur_is_uv_plane = 1'b0; cur_is_yuv420 = 1'b1; cur_is_rgba = 1'b0; cur_is_p010 = 1'b0;
            end
            5'b01001: begin
                cur_is_y_stride_1k = 1'b0; cur_is_row_len_2 = 1'b1;
                cur_is_uv_plane = 1'b1; cur_is_yuv420 = 1'b1; cur_is_rgba = 1'b0; cur_is_p010 = 1'b0;
            end
            5'b01110: begin
                cur_is_y_stride_1k = 1'b0; cur_is_row_len_2 = 1'b0;
                cur_is_uv_plane = 1'b0; cur_is_yuv420 = 1'b1; cur_is_rgba = 1'b0; cur_is_p010 = 1'b1;
            end
            5'b01111: begin
                cur_is_y_stride_1k = 1'b0; cur_is_row_len_2 = 1'b0;
                cur_is_uv_plane = 1'b1; cur_is_yuv420 = 1'b1; cur_is_rgba = 1'b0; cur_is_p010 = 1'b1;
            end
            5'b01010: begin
                cur_is_y_stride_1k = 1'b0; cur_is_row_len_2 = 1'b1;
                cur_is_uv_plane = 1'b0; cur_is_yuv420 = 1'b0; cur_is_rgba = 1'b0; cur_is_p010 = 1'b0;
            end
            5'b01011: begin
                cur_is_y_stride_1k = 1'b0; cur_is_row_len_2 = 1'b1;
                cur_is_uv_plane = 1'b1; cur_is_yuv420 = 1'b0; cur_is_rgba = 1'b0; cur_is_p010 = 1'b0;
            end
            default: begin
                cur_is_y_stride_1k = 1'b1; cur_is_row_len_2 = 1'b0;
                cur_is_uv_plane = 1'b0; cur_is_yuv420 = 1'b0; cur_is_rgba = 1'b1; cur_is_p010 = 1'b0;
            end
        endcase
    end

    reg     [3:0]                       cnt_write;
    reg                                 gearbox_sel;
    reg     [1:0]                       y420_stage;
    reg     [15:0]                      writer_group_idx;
    reg     [LINE_RING_DEPTH-1:0]       y_line_ready;
    reg     [LINE_RING_DEPTH-1:0]       uv_line_ready;

    wire    [2:0]                       writer_line_in_tile         = cur_is_row_len_2 ? cnt_write[3:1] : {1'b0, cnt_write[3:2]};
    wire    [1:0]                       writer_word_in_line         = cur_is_row_len_2 ? {1'b0, cnt_write[0]} : cnt_write[1:0];
    wire                                writer_word_last_in_line    = cur_is_row_len_2 ? cnt_write[0] : (&cnt_write[1:0]);
    wire    [16:0]                      writer_tile_cols_full       = cur_is_rgba ? (({1'b0, cfg_img_width} + 17'd15) >> 4) :
                                                                                   (({1'b0, cfg_img_width} + 17'd31) >> 5);
    wire    [15:0]                      writer_max_tile_x           = (writer_tile_cols_full == 17'd0) ? 16'd0 :
                                                                                   (writer_tile_cols_full[15:0] - 16'd1);
    wire                                writer_last_tile_x          = (cur_tile_x == writer_max_tile_x);
    wire    [12:0]                      writer_tile_x_word_base     = (cur_is_rgba || cur_is_p010) ?
                                                                      {cur_tile_x[10:0], 2'b00} :
                                                                      {cur_tile_x[11:0], 1'b0};
    wire    [15:0]                      writer_rgba_line_base       = {writer_group_idx[13:0], 2'b00};
    wire    [15:0]                      writer_yuv8_line_base       = {writer_group_idx[12:0], 3'b000};
    wire    [15:0]                      writer_y420_nv12_base       = {writer_group_idx[11:0], 4'b0000};
    wire    [15:0]                      writer_y420_p010_base       = {writer_group_idx[12:0], 3'b000};
    wire    [15:0]                      writer_uv_nv12_base         = {writer_group_idx[12:0], 3'b000};
    wire    [15:0]                      writer_uv_p010_base         = {writer_group_idx[13:0], 2'b00};
    wire    [15:0]                      writer_y420_stage_off       = cur_is_p010 ?
                                                                      ((y420_stage == 2'd0) ? 16'd0 : 16'd4) :
                                                                      ((y420_stage == 2'd0) ? 16'd0 : 16'd8);
    wire    [15:0]                      writer_global_line          = cur_is_rgba ? (writer_rgba_line_base + {13'd0, writer_line_in_tile}) :
                                                                      (cur_is_yuv420 && cur_is_uv_plane && cur_is_p010) ? (writer_uv_p010_base + {13'd0, writer_line_in_tile}) :
                                                                      (cur_is_yuv420 && cur_is_uv_plane) ? (writer_uv_nv12_base + {13'd0, writer_line_in_tile}) :
                                                                      (cur_is_yuv420 && cur_is_p010) ? (writer_y420_p010_base + writer_y420_stage_off + {13'd0, writer_line_in_tile}) :
                                                                      cur_is_yuv420 ? (writer_y420_nv12_base + writer_y420_stage_off + {13'd0, writer_line_in_tile}) :
                                                                      (writer_yuv8_line_base + {13'd0, writer_line_in_tile});
    wire    [LINE_SLOT_W-1:0]           writer_line_slot            = cur_is_rgba ? {2'b00, writer_global_line[2:0]} :
                                                                      cur_is_p010 ? {1'b0, writer_global_line[3:0]} :
                                                                                    writer_global_line[4:0];
    wire    [12:0]                      writer_line_base_addr       = cur_is_rgba ? {writer_line_slot[2:0], 10'd0} :
                                                                      cur_is_p010 ? {writer_line_slot[3:0], 9'd0} :
                                                                                    {writer_line_slot[4:0], 8'd0};
    wire    [12:0]                      writer_word_addr            = writer_line_base_addr +
                                                                      writer_tile_x_word_base +
                                                                      {11'd0, writer_word_in_line};
    wire                                writer_to_uv_bank           = cur_is_uv_plane;
    wire                                writer_slot_busy            = writer_to_uv_bank ?
                                                                      uv_line_ready[writer_line_slot] :
                                                                      y_line_ready[writer_line_slot];
    wire                                writer_req                  = !hdr_fifo_empty && !data_fifo_empty && !writer_slot_busy;

    reg     [1:0]                       rd_state;
    reg     [15:0]                      rd_line_idx;
    reg     [12:0]                      rd_word_idx;
    reg     [127:0]                     rd_first_data;
    reg     [127:0]                     rd_second_data;
    reg                                 rd_line_has_uv_reg;
    reg                                 rd_is_rgba_reg;
    reg                                 rd_is_yuv420_reg;
    reg                                 rd_is_p010_reg;
    reg     [12:0]                      rd_line_words_reg;
    reg     [LINE_SLOT_W-1:0]           rd_y_slot_reg;
    reg     [LINE_SLOT_W-1:0]           rd_uv_slot_reg;
    reg                                 rd_y_data_valid;
    reg                                 rd_uv_data_valid;

    wire                                cfg_is_rgba                 = (cfg_format == 5'b00000) || (cfg_format == 5'b00001);
    wire                                cfg_is_p010                 = (cfg_format == 5'b00011) || (cfg_format == 5'b01110) || (cfg_format == 5'b01111);
    wire                                cfg_is_yuv420               = (cfg_format == 5'b00010) || (cfg_format == 5'b00011) ||
                                                                      (cfg_format == 5'b01000) || (cfg_format == 5'b01001) ||
                                                                      (cfg_format == 5'b01110) || (cfg_format == 5'b01111);
    wire                                cfg_has_uv                  = !cfg_is_rgba;
    wire    [16:0]                      rd_words_rgba_full          = ({1'b0, cfg_img_width} + 17'd3) >> 2;
    wire    [16:0]                      rd_words_yuv8_full          = ({1'b0, cfg_img_width} + 17'd15) >> 4;
    wire    [16:0]                      rd_words_p010_full          = ({1'b0, cfg_img_width} + 17'd7) >> 3;
    wire    [12:0]                      rd_line_words_rgba          = (|rd_words_rgba_full[16:13]) ? 13'h1fff : rd_words_rgba_full[12:0];
    wire    [12:0]                      rd_line_words_yuv8          = (|rd_words_yuv8_full[16:13]) ? 13'h1fff : rd_words_yuv8_full[12:0];
    wire    [12:0]                      rd_line_words_p010          = (|rd_words_p010_full[16:13]) ? 13'h1fff : rd_words_p010_full[12:0];
    wire    [12:0]                      rd_line_words               = cfg_is_rgba ? rd_line_words_rgba :
                                                                      (cfg_is_p010 ? rd_line_words_p010 : rd_line_words_yuv8);
    wire    [LINE_SLOT_W-1:0]           rd_y_slot                   = cfg_is_rgba ? {2'b00, rd_line_idx[2:0]} :
                                                                      cfg_is_p010 ? {1'b0, rd_line_idx[3:0]} :
                                                                                    rd_line_idx[4:0];
    wire    [LINE_SLOT_W-1:0]           rd_uv_slot                  = cfg_is_p010 ? {1'b0, rd_line_idx[4:1]} :
                                                                      cfg_is_yuv420 ? rd_line_idx[5:1] :
                                                                                      rd_line_idx[4:0];
    wire                                rd_line_has_uv              = cfg_has_uv && (!cfg_is_yuv420 || rd_line_idx[0]);
    wire                                rd_line_ready               = y_line_ready[rd_y_slot] &&
                                                                      (!rd_line_has_uv || uv_line_ready[rd_uv_slot]);
    wire                                rd_frame_active             = (rd_line_idx < cfg_otf_v_act);
    wire                                rd_can_start                = (rd_state == RD_IDLE) && rd_frame_active &&
                                                                      rd_line_ready && !i_fifo_full &&
                                                                      (rd_line_words != 13'd0);
    wire    [12:0]                      rd_y_base_addr              = cfg_is_rgba ? {rd_y_slot[2:0], 10'd0} :
                                                                      cfg_is_p010 ? {rd_y_slot[3:0], 9'd0} :
                                                                                    {rd_y_slot[4:0], 8'd0};
    wire    [12:0]                      rd_uv_base_addr             = cfg_is_p010 ? {rd_uv_slot[3:0], 9'd0} :
                                                                                    {rd_uv_slot[4:0], 8'd0};
    wire    [12:0]                      rd_y_addr                   = rd_y_base_addr + rd_word_idx;
    wire    [12:0]                      rd_uv_addr                  = rd_uv_base_addr + rd_word_idx;
    wire    [12:0]                      rd_y_addr_p1                = rd_y_addr + 13'd1;
    wire                                rd_push_fire                = (rd_state == RD_PUSH) && !i_fifo_full;
    wire    [13:0]                      rd_next_word_sum            = {1'b0, rd_word_idx} +
                                                                      (rd_is_rgba_reg ? 14'd2 : 14'd1);
    wire                                rd_line_done                = (rd_next_word_sum >= {1'b0, rd_line_words_reg});

    wire                                rd_issue_y                  = rd_can_start;
    wire                                rd_issue_uv                 = rd_can_start && rd_line_has_uv;
    wire                                rd_y_data_ready             = rd_y_data_valid | sram_a_rvalid;
    wire                                rd_uv_data_ready            = !rd_line_has_uv_reg |
                                                                      rd_uv_data_valid |
                                                                      sram_b_rvalid;
    wire                                rd_wait_y_done              = rd_y_data_ready &&
                                                                      (rd_is_rgba_reg || rd_uv_data_ready);
    wire                                rd_issue_rgba_second        = (rd_state == RD_WAIT_Y) && rd_is_rgba_reg && rd_wait_y_done;
    wire                                rd_wait_second_done         = sram_a_rvalid;
    wire                                writer_conflict_a           = writer_req && !writer_to_uv_bank && (rd_issue_y || rd_issue_rgba_second);
    wire                                writer_conflict_b           = writer_req &&  writer_to_uv_bank && rd_issue_uv;
    wire                                writer_fire                 = writer_req && !writer_conflict_a && !writer_conflict_b;

    assign data_fifo_rd_en = writer_fire && gearbox_sel;
    assign hdr_fifo_rd_en  = writer_fire && cur_tlast && gearbox_sel;

    assign sram_a_wen      = writer_fire && !writer_to_uv_bank;
    assign sram_a_waddr    = writer_word_addr;
    assign sram_a_wdata    = gearbox_sel ? cur_tdata[255:128] : cur_tdata[127:0];
    assign sram_a_ren      = rd_issue_y || rd_issue_rgba_second;
    assign sram_a_raddr    = rd_issue_rgba_second ? rd_y_addr_p1 : rd_y_addr;

    assign sram_b_wen      = writer_fire && writer_to_uv_bank;
    assign sram_b_waddr    = writer_word_addr;
    assign sram_b_wdata    = gearbox_sel ? cur_tdata[255:128] : cur_tdata[127:0];
    assign sram_b_ren      = rd_issue_uv;
    assign sram_b_raddr    = rd_uv_addr;

    wire                                writer_line_done            = writer_fire && writer_last_tile_x && writer_word_last_in_line;
    wire                                writer_tile_done            = writer_fire && cur_tlast && gearbox_sel;
    wire                                writer_rowgroup_done        = writer_tile_done && writer_last_tile_x;

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) begin
            cnt_write        <= 4'd0;
            gearbox_sel      <= 1'b0;
            y420_stage       <= 2'd0;
            writer_group_idx <= 16'd0;
            y_line_ready     <= {LINE_RING_DEPTH{1'b0}};
            uv_line_ready    <= {LINE_RING_DEPTH{1'b0}};
        end else if (frame_start) begin
            cnt_write        <= 4'd0;
            gearbox_sel      <= 1'b0;
            y420_stage       <= 2'd0;
            writer_group_idx <= 16'd0;
            y_line_ready     <= {LINE_RING_DEPTH{1'b0}};
            uv_line_ready    <= {LINE_RING_DEPTH{1'b0}};
        end else begin
            if (writer_line_done) begin
                if (writer_to_uv_bank) begin
                    uv_line_ready[writer_line_slot] <= 1'b1;
                end else begin
                    y_line_ready[writer_line_slot] <= 1'b1;
                end
            end

            if (rd_push_fire && rd_line_done) begin
                y_line_ready[rd_y_slot_reg] <= 1'b0;
                if (rd_line_has_uv_reg) begin
                    uv_line_ready[rd_uv_slot_reg] <= 1'b0;
                end
            end

            if (writer_fire) begin
                gearbox_sel <= ~gearbox_sel;
                cnt_write   <= writer_tile_done ? 4'd0 : (cnt_write + 4'd1);
                if (writer_rowgroup_done) begin
                    if (cur_is_yuv420) begin
                        if (cur_is_uv_plane) begin
                            y420_stage       <= 2'd0;
                            writer_group_idx <= writer_group_idx + 16'd1;
                        end else if (y420_stage == 2'd0) begin
                            y420_stage <= 2'd1;
                        end else begin
                            y420_stage <= 2'd2;
                        end
                    end else begin
                        y420_stage       <= 2'd0;
                        writer_group_idx <= writer_group_idx + 16'd1;
                    end
                end
            end
        end
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n) begin
            rd_state           <= RD_IDLE;
            rd_line_idx        <= 16'd0;
            rd_word_idx        <= 13'd0;
            rd_first_data      <= 128'd0;
            rd_second_data     <= 128'd0;
            rd_line_has_uv_reg <= 1'b0;
            rd_is_rgba_reg     <= 1'b0;
            rd_is_yuv420_reg   <= 1'b0;
            rd_is_p010_reg     <= 1'b0;
            rd_line_words_reg  <= 13'd0;
            rd_y_slot_reg      <= {LINE_SLOT_W{1'b0}};
            rd_uv_slot_reg     <= {LINE_SLOT_W{1'b0}};
            rd_y_data_valid    <= 1'b0;
            rd_uv_data_valid   <= 1'b0;
            o_fifo_wr_en       <= 1'b0;
            o_fifo_wdata       <= 256'd0;
            o_fetcher_done     <= 1'b0;
        end else if (frame_start) begin
            rd_state           <= RD_IDLE;
            rd_line_idx        <= 16'd0;
            rd_word_idx        <= 13'd0;
            rd_first_data      <= 128'd0;
            rd_second_data     <= 128'd0;
            rd_line_has_uv_reg <= 1'b0;
            rd_is_rgba_reg     <= 1'b0;
            rd_is_yuv420_reg   <= 1'b0;
            rd_is_p010_reg     <= 1'b0;
            rd_line_words_reg  <= 13'd0;
            rd_y_slot_reg      <= {LINE_SLOT_W{1'b0}};
            rd_uv_slot_reg     <= {LINE_SLOT_W{1'b0}};
            rd_y_data_valid    <= 1'b0;
            rd_uv_data_valid   <= 1'b0;
            o_fifo_wr_en       <= 1'b0;
            o_fifo_wdata       <= 256'd0;
            o_fetcher_done     <= 1'b0;
        end else begin
            o_fifo_wr_en   <= 1'b0;
            o_fetcher_done <= 1'b0;
            case (rd_state)
                RD_IDLE: begin
                    if (rd_can_start) begin
                        rd_line_has_uv_reg <= rd_line_has_uv;
                        rd_is_rgba_reg     <= cfg_is_rgba;
                        rd_is_yuv420_reg   <= cfg_is_yuv420;
                        rd_is_p010_reg     <= cfg_is_p010;
                        rd_line_words_reg  <= rd_line_words;
                        rd_y_slot_reg      <= rd_y_slot;
                        rd_uv_slot_reg     <= rd_uv_slot;
                        rd_y_data_valid    <= 1'b0;
                        rd_uv_data_valid   <= 1'b0;
                        rd_state           <= RD_WAIT_Y;
                    end
                end
                RD_WAIT_Y: begin
                    if (sram_a_rvalid) begin
                        rd_first_data   <= sram_a_rdata;
                        rd_y_data_valid <= 1'b1;
                    end
                    if (rd_line_has_uv_reg && sram_b_rvalid) begin
                        rd_second_data   <= sram_b_rdata;
                        rd_uv_data_valid <= 1'b1;
                    end
                    if (rd_wait_y_done) begin
                        if (rd_is_rgba_reg) begin
                            rd_y_data_valid <= 1'b0;
                            rd_state <= RD_WAIT_SECOND;
                        end else begin
                            if (!rd_line_has_uv_reg) begin
                                rd_second_data <= 128'd0;
                            end
                            rd_y_data_valid  <= 1'b0;
                            rd_uv_data_valid <= 1'b0;
                            rd_state         <= RD_PUSH;
                        end
                    end
                end
                RD_WAIT_SECOND: begin
                    if (rd_wait_second_done) begin
                        rd_second_data <= sram_a_rdata;
                        rd_state       <= RD_PUSH;
                    end
                end
                RD_PUSH: begin
                    if (!i_fifo_full) begin
                        o_fifo_wr_en <= 1'b1;
                        o_fifo_wdata <= {rd_second_data, rd_first_data};
                        if (rd_line_done) begin
                            rd_word_idx <= 13'd0;
                            rd_line_idx <= rd_line_idx + 16'd1;
                            o_fetcher_done <= 1'b1;
                        end else begin
                            rd_word_idx <= rd_next_word_sum[12:0];
                        end
                        rd_state <= RD_IDLE;
                    end
                end
                default: begin
                    rd_state <= RD_IDLE;
                end
            endcase
        end
    end

    assign o_writer_vld   = writer_line_done;
    assign o_fetcher_req  = rd_frame_active && (rd_state != RD_IDLE || rd_line_ready);
    assign o_sram_a_free  = !(|y_line_ready);
    assign o_sram_b_free  = !(|uv_line_ready);
    assign o_busy         = s_axis_tile_valid | s_axis_tvalid |
                            !hdr_fifo_empty | !data_fifo_empty |
                            (|y_line_ready) | (|uv_line_ready) |
                            (rd_state != RD_IDLE);

endmodule
