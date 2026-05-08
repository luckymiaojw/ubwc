`timescale 1ns/1ps

module ubwc_dec_meta_data_from_sram
    #(
        parameter SRAM_ADDR_W       = 12    ,
        parameter SRAM_DW           = 64
    )(
        input   wire                            clk,
        input   wire                            rst_n,
        input   wire                            start,

        // --- External configuration ---
        input   wire    [ 4:0]                  base_format,      // Frame-level format only
        input   wire    [15:0]                  tile_x_numbers,   // Image tile columns
        input   wire    [15:0]                  tile_y_numbers,   // Image tile rows

        // --- SRAM control interface ---
        output  reg     [3:0]                   sram_re_a,
        output  reg     [3:0]                   sram_re_b,
        output  reg     [SRAM_ADDR_W-1:0]       sram_addr,
        input   wire    [SRAM_DW    -1:0]       sram_rdata,
        input   wire                            sram_rvalid,

        // --- FIFO interface (input side) ---
        input   wire                            bfifo_we,
        input   wire    [40:0]                  bfifo_wdata,
        output  wire                            bfifo_prog_full,

        // --- FIFO interface (output side) ---
        output  wire    [37:0]                  fifo_wdata,
        output  wire                            fifo_vld,
        input   wire                            fifo_rdy,

        // --- Bank lifecycle ---
        output  reg                             bank_release_valid,
        output  reg                             bank_release_bank_b
    );

    // ==========================================
    // 0. Format constants
    // ==========================================
    // base_format is a frame-level format selector.
    localparam [4:0] BASE_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] BASE_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] BASE_FMT_YUV420_8    = 5'b00010;
    localparam [4:0] BASE_FMT_YUV420_10   = 5'b00011;

    // meta_format is a tile-level format selector and keeps Y/UV split codes.
    localparam [4:0] META_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] META_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] META_FMT_NV12_Y      = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV     = 5'b01001;
    localparam [4:0] META_FMT_P010_Y      = 5'b01110;
    localparam [4:0] META_FMT_P010_UV     = 5'b01111;

    wire base_is_rgba;
    assign base_is_rgba = (base_format == BASE_FMT_RGBA8888) || (base_format == BASE_FMT_RGBA1010102);
    wire base_is_yuv420;
    assign base_is_yuv420 = (base_format == BASE_FMT_YUV420_8) || (base_format == BASE_FMT_YUV420_10);
    wire base_supported;
    assign base_supported = base_is_rgba || base_is_yuv420;

    // ==========================================
    // 1. Internal FIFO instances
    // ==========================================
    wire        in_bfifo_re;
    wire [40:0] in_bfifo_rdata;
    wire        in_bfifo_empty;
    wire        in_bfifo_full;

    ubwc_meta_simple_fifo #(
        .DWIDTH(41),
        .AWIDTH(9),
        .PROG_FULL_LEVEL(32)
    ) u_input_bfifo (
        .clk        (clk),
        .rst_n      (rst_n),
        .sclr       (start),
        .we         (bfifo_we),
        .din        (bfifo_wdata),
        .re         (in_bfifo_re),
        .dout       (in_bfifo_rdata),
        .empty      (in_bfifo_empty),
        .full       (in_bfifo_full),
        .prog_full  (bfifo_prog_full)
    );

    wire        legacy_int_fifo_we;
    wire [40:0] legacy_int_fifo_wdata;
    wire        legacy_int_fifo_re;
    wire [40:0] legacy_int_fifo_rdata;
    wire        legacy_int_fifo_empty;
    wire        legacy_int_fifo_full;
    wire        legacy_int_fifo_prog_full;

    ubwc_meta_simple_fifo #( .DWIDTH(41), .AWIDTH(9) ) u_internal_fifo (
        .clk        (clk),
        .rst_n      (rst_n),
        .sclr       (start),
        .we         (legacy_int_fifo_we),
        .din        (legacy_int_fifo_wdata),
        .re         (legacy_int_fifo_re),
        .dout       (legacy_int_fifo_rdata),
        .empty      (legacy_int_fifo_empty),
        .full       (legacy_int_fifo_full),
        .prog_full  (legacy_int_fifo_prog_full)
    );

    wire        yuv420_y0_fifo_we;
    wire [40:0] yuv420_y0_fifo_din;
    wire        yuv420_y0_fifo_re;
    wire [40:0] yuv420_y0_fifo_dout;
    wire        yuv420_y0_fifo_empty;
    wire        yuv420_y0_fifo_full;
    wire        yuv420_y0_fifo_prog_full;

    wire        yuv420_y1_fifo_we;
    wire [40:0] yuv420_y1_fifo_din;
    wire        yuv420_y1_fifo_re;
    wire [40:0] yuv420_y1_fifo_dout;
    wire        yuv420_y1_fifo_empty;
    wire        yuv420_y1_fifo_full;
    wire        yuv420_y1_fifo_prog_full;

    wire        yuv420_uv_fifo_we;
    wire [40:0] yuv420_uv_fifo_din;
    wire        yuv420_uv_fifo_re;
    wire [40:0] yuv420_uv_fifo_dout;
    wire        yuv420_uv_fifo_empty;
    wire        yuv420_uv_fifo_full;
    wire        yuv420_uv_fifo_prog_full;

    wire        yuv420_y0_int_fifo_we;
    wire [40:0] yuv420_y0_int_fifo_din;
    wire        yuv420_y0_int_fifo_re;
    wire [40:0] yuv420_y0_int_fifo_dout;
    wire        yuv420_y0_int_fifo_empty;
    wire        yuv420_y0_int_fifo_full;
    wire        yuv420_y0_int_fifo_prog_full;

    wire        yuv420_y1_int_fifo_we;
    wire [40:0] yuv420_y1_int_fifo_din;
    wire        yuv420_y1_int_fifo_re;
    wire [40:0] yuv420_y1_int_fifo_dout;
    wire        yuv420_y1_int_fifo_empty;
    wire        yuv420_y1_int_fifo_full;
    wire        yuv420_y1_int_fifo_prog_full;

    wire        yuv420_uv_int_fifo_we;
    wire [40:0] yuv420_uv_int_fifo_din;
    wire        yuv420_uv_int_fifo_re;
    wire [40:0] yuv420_uv_int_fifo_dout;
    wire        yuv420_uv_int_fifo_empty;
    wire        yuv420_uv_int_fifo_full;
    wire        yuv420_uv_int_fifo_prog_full;
    wire        fifo_status_seen;

    ubwc_meta_simple_fifo #( .DWIDTH(41), .AWIDTH(7) ) u_yuv420_y0_fifo (
        .clk        (clk),
        .rst_n      (rst_n),
        .sclr       (start),
        .we         (yuv420_y0_fifo_we),
        .din        (yuv420_y0_fifo_din),
        .re         (yuv420_y0_fifo_re),
        .dout       (yuv420_y0_fifo_dout),
        .empty      (yuv420_y0_fifo_empty),
        .full       (yuv420_y0_fifo_full),
        .prog_full  (yuv420_y0_fifo_prog_full)
    );

    ubwc_meta_simple_fifo #( .DWIDTH(41), .AWIDTH(7) ) u_yuv420_y1_fifo (
        .clk        (clk),
        .rst_n      (rst_n),
        .sclr       (start),
        .we         (yuv420_y1_fifo_we),
        .din        (yuv420_y1_fifo_din),
        .re         (yuv420_y1_fifo_re),
        .dout       (yuv420_y1_fifo_dout),
        .empty      (yuv420_y1_fifo_empty),
        .full       (yuv420_y1_fifo_full),
        .prog_full  (yuv420_y1_fifo_prog_full)
    );

    ubwc_meta_simple_fifo #( .DWIDTH(41), .AWIDTH(7) ) u_yuv420_uv_fifo (
        .clk        (clk),
        .rst_n      (rst_n),
        .sclr       (start),
        .we         (yuv420_uv_fifo_we),
        .din        (yuv420_uv_fifo_din),
        .re         (yuv420_uv_fifo_re),
        .dout       (yuv420_uv_fifo_dout),
        .empty      (yuv420_uv_fifo_empty),
        .full       (yuv420_uv_fifo_full),
        .prog_full  (yuv420_uv_fifo_prog_full)
    );

    ubwc_meta_simple_fifo #( .DWIDTH(41), .AWIDTH(7) ) u_yuv420_y0_int_fifo (
        .clk        (clk),
        .rst_n      (rst_n),
        .sclr       (start),
        .we         (yuv420_y0_int_fifo_we),
        .din        (yuv420_y0_int_fifo_din),
        .re         (yuv420_y0_int_fifo_re),
        .dout       (yuv420_y0_int_fifo_dout),
        .empty      (yuv420_y0_int_fifo_empty),
        .full       (yuv420_y0_int_fifo_full),
        .prog_full  (yuv420_y0_int_fifo_prog_full)
    );

    ubwc_meta_simple_fifo #( .DWIDTH(41), .AWIDTH(7) ) u_yuv420_y1_int_fifo (
        .clk        (clk),
        .rst_n      (rst_n),
        .sclr       (start),
        .we         (yuv420_y1_int_fifo_we),
        .din        (yuv420_y1_int_fifo_din),
        .re         (yuv420_y1_int_fifo_re),
        .dout       (yuv420_y1_int_fifo_dout),
        .empty      (yuv420_y1_int_fifo_empty),
        .full       (yuv420_y1_int_fifo_full),
        .prog_full  (yuv420_y1_int_fifo_prog_full)
    );

    ubwc_meta_simple_fifo #( .DWIDTH(41), .AWIDTH(7) ) u_yuv420_uv_int_fifo (
        .clk        (clk),
        .rst_n      (rst_n),
        .sclr       (start),
        .we         (yuv420_uv_int_fifo_we),
        .din        (yuv420_uv_int_fifo_din),
        .re         (yuv420_uv_int_fifo_re),
        .dout       (yuv420_uv_int_fifo_dout),
        .empty      (yuv420_uv_int_fifo_empty),
        .full       (yuv420_uv_int_fifo_full),
        .prog_full  (yuv420_uv_int_fifo_prog_full)
    );

    assign fifo_status_seen = in_bfifo_full |
                              legacy_int_fifo_full | legacy_int_fifo_prog_full |
                              yuv420_y0_fifo_prog_full |
                              yuv420_y1_fifo_prog_full |
                              yuv420_uv_fifo_prog_full |
                              yuv420_y0_int_fifo_full | yuv420_y0_int_fifo_prog_full |
                              yuv420_y1_int_fifo_full | yuv420_y1_int_fifo_prog_full |
                              yuv420_uv_int_fifo_full | yuv420_uv_int_fifo_prog_full;

    // ==========================================
    // 2. State machine and arbitration logic
    // ==========================================
    localparam ST_IDLE       = 2'd0;
    localparam ST_WAIT_SRAM  = 2'd1;
    localparam ST_SERIALIZE  = 2'd2;

    reg [1:0]   state;
    reg [1:0]   next_state;
    reg [2:0]   row_phase;
    reg [15:0]  yuv420_group_idx;
    reg [2:0]   yuv420_slice_phase;
    reg [1:0]   yuv420_slot_phase;

    function [20:0] yuv420_advance_ptr;
        input [15:0] group_idx;
        input [2:0]  slice_phase;
        input [1:0]  slot_phase;
        reg   [15:0] next_group_idx;
        reg   [2:0]  next_slice_phase;
        reg   [1:0]  next_slot_phase;
        begin
            next_group_idx  = group_idx;
            next_slice_phase = slice_phase;
            next_slot_phase  = slot_phase;

            if (slot_phase == 2'd2) begin
                next_slot_phase = 2'd0;
                if (slice_phase == 3'd7) begin
                    next_slice_phase = 3'd0;
                    next_group_idx   = group_idx + 16'd1;
                end else begin
                    next_slice_phase = slice_phase + 3'd1;
                end
            end else begin
                next_slot_phase = slot_phase + 2'd1;
            end

            yuv420_advance_ptr = {next_group_idx, next_slice_phase, next_slot_phase};
        end
    endfunction

    function [2:0] yuv420_calc_row_phase;
        input [2:0] slice_phase;
        input [1:0] slot_phase;
        reg   [3:0] y_row_in_group;
        begin
            if (slot_phase == 2'd2) begin
                yuv420_calc_row_phase = slice_phase;
            end else begin
                y_row_in_group = {slice_phase, 1'b0} + {3'd0, slot_phase[0]};
                yuv420_calc_row_phase = y_row_in_group[2:0];
            end
        end
    endfunction

    // row_phase:
    //   0~7 -> rows 0~7 within the current 8-row group
    // Scheduling order:
    //   First read every tile in the current 8-row group for rows 0~7
    //   Then move on to the next 8-row group
    wire        legacy_req_vld;
    assign legacy_req_vld = (row_phase == 3'd0) ? ~in_bfifo_empty : ~legacy_int_fifo_empty;
    wire [40:0] legacy_req_data;
    assign legacy_req_data = (row_phase == 3'd0) ? in_bfifo_rdata  : legacy_int_fifo_rdata;
    wire        req_ready;
    assign req_ready = (state == ST_IDLE);
    wire        legacy_in_bfifo_re;
    assign legacy_in_bfifo_re = req_ready && legacy_req_vld && (row_phase == 3'd0);
    wire        legacy_int_fifo_re_local;
    assign legacy_int_fifo_re_local = req_ready && legacy_req_vld && (row_phase != 3'd0);

    wire demux_is_yuv420_uv;
    assign demux_is_yuv420_uv = (in_bfifo_rdata[36:32] == META_FMT_NV12_UV) || (in_bfifo_rdata[36:32] == META_FMT_P010_UV);
    wire demux_is_yuv420_y1;
    assign demux_is_yuv420_y1 = !demux_is_yuv420_uv && in_bfifo_rdata[0];
    wire demux_target_full;
    assign demux_target_full = demux_is_yuv420_uv ? yuv420_uv_fifo_full :
                              demux_is_yuv420_y1 ? yuv420_y1_fifo_full :
                                                   yuv420_y0_fifo_full;
    wire yuv420_demux_re;
    assign yuv420_demux_re = base_is_yuv420 && !in_bfifo_empty && !demux_target_full;

    assign in_bfifo_re            = base_is_yuv420 ? yuv420_demux_re : legacy_in_bfifo_re;
    assign legacy_int_fifo_re     = legacy_int_fifo_re_local;
    assign legacy_int_fifo_we     = (legacy_in_bfifo_re || legacy_int_fifo_re_local) && (row_phase != 3'd7);
    assign legacy_int_fifo_wdata  = legacy_req_data;

    assign yuv420_y0_fifo_we  = yuv420_demux_re && !demux_is_yuv420_uv && !demux_is_yuv420_y1;
    assign yuv420_y0_fifo_din = in_bfifo_rdata;
    assign yuv420_y1_fifo_we  = yuv420_demux_re && !demux_is_yuv420_uv &&  demux_is_yuv420_y1;
    assign yuv420_y1_fifo_din = in_bfifo_rdata;
    assign yuv420_uv_fifo_we  = yuv420_demux_re && demux_is_yuv420_uv;
    assign yuv420_uv_fifo_din = in_bfifo_rdata;

    wire [15:0] yuv420_group_count;
    assign yuv420_group_count = (tile_y_numbers + 16'd15) >> 4;
    wire [16:0] yuv420_uv_total_rows;
    assign yuv420_uv_total_rows = ({1'b0, tile_y_numbers} + 17'd1) >> 1;
    wire [16:0] yuv420_luma_rows_consumed;
    assign yuv420_luma_rows_consumed = ({1'b0, yuv420_group_idx} << 4);
    wire [16:0] yuv420_luma_rows_remaining;
    assign yuv420_luma_rows_remaining = ({1'b0, tile_y_numbers} > yuv420_luma_rows_consumed) ?
            ({1'b0, tile_y_numbers} - yuv420_luma_rows_consumed) : 17'd0;
    wire [16:0] yuv420_uv_rows_consumed;
    assign yuv420_uv_rows_consumed = ({1'b0, yuv420_group_idx} << 3);
    wire [16:0] yuv420_uv_rows_remaining;
    assign yuv420_uv_rows_remaining = (yuv420_uv_total_rows > yuv420_uv_rows_consumed) ?
            (yuv420_uv_total_rows - yuv420_uv_rows_consumed) : 17'd0;
    wire [16:0] yuv420_y1_rows_remaining;
    assign yuv420_y1_rows_remaining = (yuv420_luma_rows_remaining > 17'd8) ? (yuv420_luma_rows_remaining - 17'd8) : 17'd0;
    wire        yuv420_groups_done;
    assign yuv420_groups_done = (yuv420_group_idx >= yuv420_group_count);
    wire        yuv420_slot_is_uv;
    assign yuv420_slot_is_uv = (yuv420_slot_phase == 2'd2);
    wire [3:0]  yuv420_y_row_in_group;
    assign yuv420_y_row_in_group = {yuv420_slice_phase, 1'b0} + {3'd0, yuv420_slot_phase[0]};
    wire        yuv420_use_y1_pass;
    assign yuv420_use_y1_pass = !yuv420_slot_is_uv && yuv420_y_row_in_group[3];
    wire [2:0]  yuv420_target_row_phase;
    assign yuv420_target_row_phase = yuv420_calc_row_phase(yuv420_slice_phase, yuv420_slot_phase);
    wire [4:0]  yuv420_y0_row_count;
    assign yuv420_y0_row_count = (yuv420_luma_rows_remaining >= 17'd8) ? 5'd8 : {1'b0, yuv420_luma_rows_remaining[3:0]};
    wire [4:0]  yuv420_y1_row_count;
    assign yuv420_y1_row_count = (yuv420_y1_rows_remaining >= 17'd8) ? 5'd8 : {1'b0, yuv420_y1_rows_remaining[3:0]};
    wire [4:0]  yuv420_uv_row_count;
    assign yuv420_uv_row_count = (yuv420_uv_rows_remaining >= 17'd8) ? 5'd8 : {1'b0, yuv420_uv_rows_remaining[3:0]};
    wire [4:0]  yuv420_selected_row_count;
    assign yuv420_selected_row_count = yuv420_slot_is_uv ? yuv420_uv_row_count :
        yuv420_use_y1_pass ? yuv420_y1_row_count :
                             yuv420_y0_row_count;
    wire        yuv420_slot_valid;
    assign yuv420_slot_valid = !yuv420_groups_done &&
        (yuv420_slot_is_uv ? ({14'd0, yuv420_slice_phase} < yuv420_uv_rows_remaining) :
                             ({13'd0, yuv420_y_row_in_group} < yuv420_luma_rows_remaining));
    wire        yuv420_use_input_fifo;
    assign yuv420_use_input_fifo = (yuv420_target_row_phase == 3'd0);
    wire [40:0] yuv420_req_data;
    assign yuv420_req_data = yuv420_slot_is_uv ?
            (yuv420_use_input_fifo ? yuv420_uv_fifo_dout : yuv420_uv_int_fifo_dout) :
        yuv420_use_y1_pass ?
            (yuv420_use_input_fifo ? yuv420_y1_fifo_dout : yuv420_y1_int_fifo_dout) :
            (yuv420_use_input_fifo ? yuv420_y0_fifo_dout : yuv420_y0_int_fifo_dout);
    wire        yuv420_req_empty;
    assign yuv420_req_empty = yuv420_slot_is_uv ?
            (yuv420_use_input_fifo ? yuv420_uv_fifo_empty : yuv420_uv_int_fifo_empty) :
        yuv420_use_y1_pass ?
            (yuv420_use_input_fifo ? yuv420_y1_fifo_empty : yuv420_y1_int_fifo_empty) :
            (yuv420_use_input_fifo ? yuv420_y0_fifo_empty : yuv420_y0_int_fifo_empty);
    wire        yuv420_req_vld;
    assign yuv420_req_vld = yuv420_slot_valid && !yuv420_req_empty;
    wire        yuv420_req_re;
    assign yuv420_req_re = req_ready && yuv420_req_vld;
    wire        yuv420_need_recirculate;
    assign yuv420_need_recirculate = yuv420_req_re && ({2'd0, yuv420_target_row_phase} + 5'd1 < yuv420_selected_row_count);
    wire [20:0] yuv420_advance_ptr_curr;
    assign yuv420_advance_ptr_curr = yuv420_advance_ptr(yuv420_group_idx, yuv420_slice_phase, yuv420_slot_phase);
    wire [15:0] yuv420_next_group_idx;
    assign yuv420_next_group_idx = yuv420_advance_ptr_curr[20:5];
    wire [2:0]  yuv420_next_slice_phase;
    assign yuv420_next_slice_phase = yuv420_advance_ptr_curr[4:2];
    wire [1:0]  yuv420_next_slot_phase;
    assign yuv420_next_slot_phase = yuv420_advance_ptr_curr[1:0];
    wire [2:0]  yuv420_next_row_phase;
    assign yuv420_next_row_phase = yuv420_calc_row_phase(yuv420_next_slice_phase, yuv420_next_slot_phase);

    assign yuv420_y0_fifo_re     = yuv420_req_re && !yuv420_slot_is_uv && !yuv420_use_y1_pass &&  yuv420_use_input_fifo;
    assign yuv420_y1_fifo_re     = yuv420_req_re && !yuv420_slot_is_uv &&  yuv420_use_y1_pass &&  yuv420_use_input_fifo;
    assign yuv420_uv_fifo_re     = yuv420_req_re &&  yuv420_slot_is_uv &&  yuv420_use_input_fifo;
    assign yuv420_y0_int_fifo_re = yuv420_req_re && !yuv420_slot_is_uv && !yuv420_use_y1_pass && !yuv420_use_input_fifo;
    assign yuv420_y1_int_fifo_re = yuv420_req_re && !yuv420_slot_is_uv &&  yuv420_use_y1_pass && !yuv420_use_input_fifo;
    assign yuv420_uv_int_fifo_re = yuv420_req_re &&  yuv420_slot_is_uv && !yuv420_use_input_fifo;

    assign yuv420_y0_int_fifo_we  = yuv420_need_recirculate && !yuv420_slot_is_uv && !yuv420_use_y1_pass;
    assign yuv420_y0_int_fifo_din = yuv420_req_data;
    assign yuv420_y1_int_fifo_we  = yuv420_need_recirculate && !yuv420_slot_is_uv &&  yuv420_use_y1_pass;
    assign yuv420_y1_int_fifo_din = yuv420_req_data;
    assign yuv420_uv_int_fifo_we  = yuv420_need_recirculate &&  yuv420_slot_is_uv;
    assign yuv420_uv_int_fifo_din = yuv420_req_data;

    wire        req_vld;
    assign req_vld = base_supported && (base_is_yuv420 ? yuv420_req_vld : legacy_req_vld);
    wire [40:0] req_data;
    assign req_data = base_is_yuv420 ? yuv420_req_data : legacy_req_data;
    wire        req_pingpong;
    assign req_pingpong = req_data[40];
    wire [4:0]  req_meta_format;
    assign req_meta_format = req_data[36:32];
    wire [8:0]  req_xcoord_9b;
    assign req_xcoord_9b = req_data[24:16];
    wire [6:0]  req_ycoord_7b;
    assign req_ycoord_7b = req_data[6:0];
    wire        req_ycoord_lsb;
    assign req_ycoord_lsb = req_data[0];

    // ==========================================
    // 3. Hardware-friendly address calculation (no multipliers)
    // ==========================================
    wire req_is_yuv420_uv;
    assign req_is_yuv420_uv = (req_meta_format == META_FMT_NV12_UV) || (req_meta_format == META_FMT_P010_UV);

    wire [1:0] sram_base_addr_offset;
    assign sram_base_addr_offset =
        base_is_rgba   ? {1'b0, req_ycoord_lsb} :
        base_is_yuv420 ? (req_is_yuv420_uv ? 2'b10 : {1'b0, req_ycoord_lsb}) :
                         2'b00;

    wire [SRAM_ADDR_W-1:0] sram_pass_base_addr;
    assign sram_pass_base_addr = {{(SRAM_ADDR_W-10){1'b0}}, sram_base_addr_offset, 8'h00};

    wire [2:0] req_row_phase;
    assign req_row_phase = base_is_yuv420 ? yuv420_target_row_phase : row_phase;
    wire [SRAM_ADDR_W-1:0] sram_tile_word_addr;
    assign sram_tile_word_addr = {{(SRAM_ADDR_W-9){1'b0}}, req_xcoord_9b[7:0], req_row_phase[2]};

    // ==========================================
    // 4. Main control logic
    // ==========================================
    reg         meta_error_reg;
    reg         meta_eol_reg;
    reg         meta_last_pass_reg;
    reg         meta_pingpong_reg;
    reg         meta_release_on_done_reg;
    reg [4:0]   meta_format_reg;
    reg [8:0]   meta_xcoord_reg;
    reg [6:0]   meta_ycoord_reg;
    reg [63:0]  sram_data_reg;
    reg [3:0]   byte_idx_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= ST_IDLE;
        else if (start) state <= ST_IDLE;
        else        state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE:      if (req_vld) next_state = ST_WAIT_SRAM;
            ST_WAIT_SRAM: if (sram_rvalid) next_state = ST_SERIALIZE;
            ST_SERIALIZE: if (byte_idx_reg == 4'd7 && fifo_rdy) next_state = ST_IDLE;
            default:      next_state = ST_IDLE;
        endcase
    end

    wire idle_yuv_skip_slot_fire;
    assign idle_yuv_skip_slot_fire = (state == ST_IDLE) && base_is_yuv420 &&
                                     !req_vld && !yuv420_groups_done &&
                                     !yuv420_slot_valid;
    wire req_accept_fire;
    assign req_accept_fire = (state == ST_IDLE) && req_vld;
    wire sram_capture_fire;
    assign sram_capture_fire = (state == ST_WAIT_SRAM) && sram_rvalid;
    wire serialize_fire;
    assign serialize_fire = (state == ST_SERIALIZE) && fifo_rdy;
    wire serialize_last_fire;
    assign serialize_last_fire = serialize_fire && (byte_idx_reg == 4'd7);
    wire serialize_more_fire;
    assign serialize_more_fire = serialize_fire && (byte_idx_reg != 4'd7);
    wire serialize_eol_fire;
    assign serialize_eol_fire = serialize_last_fire && meta_eol_reg;
    wire yuv420_advance_fire;
    assign yuv420_advance_fire = idle_yuv_skip_slot_fire ||
                                 (serialize_eol_fire && base_is_yuv420);
    wire legacy_row_wrap_fire;
    assign legacy_row_wrap_fire = serialize_eol_fire && !base_is_yuv420 &&
                                  (row_phase == 3'd7);
    wire legacy_row_inc_fire;
    assign legacy_row_inc_fire = serialize_eol_fire && !base_is_yuv420 &&
                                 (row_phase != 3'd7);
    wire release_fire;
    assign release_fire = serialize_last_fire && meta_eol_reg &&
                          meta_last_pass_reg && meta_release_on_done_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            row_phase <= 3'd0;
        else if (start)
            row_phase <= 3'd0;
        else if (req_accept_fire && base_is_yuv420)
            row_phase <= yuv420_target_row_phase;
        else if (yuv420_advance_fire)
            row_phase <= yuv420_next_row_phase;
        else if (legacy_row_wrap_fire)
            row_phase <= 3'd0;
        else if (legacy_row_inc_fire)
            row_phase <= row_phase + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            yuv420_group_idx <= 16'd0;
        else if (start)
            yuv420_group_idx <= 16'd0;
        else if (yuv420_advance_fire)
            yuv420_group_idx <= yuv420_next_group_idx;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            yuv420_slice_phase <= 3'd0;
        else if (start)
            yuv420_slice_phase <= 3'd0;
        else if (yuv420_advance_fire)
            yuv420_slice_phase <= yuv420_next_slice_phase;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            yuv420_slot_phase <= 2'd0;
        else if (start)
            yuv420_slot_phase <= 2'd0;
        else if (yuv420_advance_fire)
            yuv420_slot_phase <= yuv420_next_slot_phase;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            meta_error_reg <= 1'b0;
        else if (start)
            meta_error_reg <= 1'b0;
        else if (req_accept_fire)
            meta_error_reg <= req_data[39];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            meta_eol_reg <= 1'b0;
        else if (start)
            meta_eol_reg <= 1'b0;
        else if (req_accept_fire)
            meta_eol_reg <= req_data[38];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            meta_last_pass_reg <= 1'b0;
        else if (start)
            meta_last_pass_reg <= 1'b0;
        else if (req_accept_fire)
            meta_last_pass_reg <= req_data[37];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            meta_pingpong_reg <= 1'b0;
        else if (start)
            meta_pingpong_reg <= 1'b0;
        else if (req_accept_fire)
            meta_pingpong_reg <= req_pingpong;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            meta_release_on_done_reg <= 1'b0;
        else if (start)
            meta_release_on_done_reg <= 1'b0;
        else if (req_accept_fire)
            meta_release_on_done_reg <= base_is_yuv420 ? !yuv420_need_recirculate :
                                                        (row_phase == 3'd7);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            meta_format_reg <= META_FMT_RGBA8888;
        else if (start)
            meta_format_reg <= META_FMT_RGBA8888;
        else if (req_accept_fire)
            meta_format_reg <= req_meta_format;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            meta_xcoord_reg <= 9'd0;
        else if (start)
            meta_xcoord_reg <= 9'd0;
        else if (req_accept_fire)
            meta_xcoord_reg <= req_xcoord_9b;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            meta_ycoord_reg <= 7'd0;
        else if (start)
            meta_ycoord_reg <= 7'd0;
        else if (req_accept_fire)
            meta_ycoord_reg <= req_ycoord_7b;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sram_data_reg <= 64'd0;
        else if (start)
            sram_data_reg <= 64'd0;
        else if (sram_capture_fire)
            sram_data_reg <= sram_rdata;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            byte_idx_reg <= 4'd0;
        else if (start)
            byte_idx_reg <= 4'd0;
        else if (sram_capture_fire)
            byte_idx_reg <= 4'd0;
        else if (serialize_more_fire)
            byte_idx_reg <= byte_idx_reg + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sram_re_a <= 4'd0;
        else if (start)
            sram_re_a <= 4'd0;
        else if (req_accept_fire && !req_pingpong)
            sram_re_a <= (4'b0001 << req_row_phase[1:0]);
        else
            sram_re_a <= 4'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sram_re_b <= 4'd0;
        else if (start)
            sram_re_b <= 4'd0;
        else if (req_accept_fire && req_pingpong)
            sram_re_b <= (4'b0001 << req_row_phase[1:0]);
        else
            sram_re_b <= 4'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sram_addr <= {SRAM_ADDR_W{1'b0}};
        else if (start)
            sram_addr <= {SRAM_ADDR_W{1'b0}};
        else if (req_accept_fire)
            sram_addr <= sram_pass_base_addr + sram_tile_word_addr;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank_release_valid <= 1'b0;
        else if (start)
            bank_release_valid <= 1'b0;
        else
            bank_release_valid <= release_fire;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bank_release_bank_b <= 1'b0;
        else if (start)
            bank_release_bank_b <= 1'b0;
        else if (release_fire)
            bank_release_bank_b <= meta_pingpong_reg;
    end

    // ==========================================
    // 5. Output assembly (use shifts instead of multiplication)
    // ==========================================
    // byte_idx_reg * 8 is equivalent to shifting the index left by 3 for the bit offset
    reg [7:0] current_meta_byte;
    always @(*) begin
        case (byte_idx_reg[2:0])
            3'd0: current_meta_byte = sram_data_reg[ 7: 0];
            3'd1: current_meta_byte = sram_data_reg[15: 8];
            3'd2: current_meta_byte = sram_data_reg[23:16];
            3'd3: current_meta_byte = sram_data_reg[31:24];
            3'd4: current_meta_byte = sram_data_reg[39:32];
            3'd5: current_meta_byte = sram_data_reg[47:40];
            3'd6: current_meta_byte = sram_data_reg[55:48];
            3'd7: current_meta_byte = sram_data_reg[63:56];
            default: current_meta_byte = 8'd0;
        endcase
    end

    assign fifo_vld = (state == ST_SERIALIZE) | (fifo_status_seen & 1'b0);
    assign fifo_wdata = {
        meta_error_reg,                             // error
        meta_eol_reg,                               // is_eol
        meta_last_pass_reg,                         // is_last_pass
        current_meta_byte,                          // meta_data
        meta_format_reg,                            // format
        {meta_xcoord_reg, byte_idx_reg[2:0]},       // xcoord[8:0] + byte_index
        {meta_ycoord_reg, row_phase[2:0]}           // ycoord[6:0] + row_idx_in_8line_group
    };

endmodule
