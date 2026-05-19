//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-04-01  23:16:49
// Design Name       :
// Module Name       : ubwc_dec_tile_to_line_sram_fetcher.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							:
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module sram_read_fetcher #(
    parameter   integer                             SRAM_ADDR_W                     = 12
)(
    input   wire                                        clk_sram                        ,
    input   wire                                        rst_n                           ,
    input   wire                                        i_frame_start                   ,
    input   wire    [15                     :0]         cfg_img_width                   ,
    input   wire    [4                      :0]         cfg_format                      ,
    input   wire                                        i_buffer_vld                    ,
    input   wire                                        i_writer_bank                   ,
    input   wire    [3                      :0]         i_buffer_fcnt                   ,
    input   wire                                        i_buffer_uv_slot                ,
    input   wire                                        i_buffer_y_lower_ready          ,
    input   wire                                        i_buffer_uv_ready               ,
    input   wire                                        i_y_lower_done                  ,
    input   wire                                        i_uv_done                       ,
    input   wire                                        i_sram_a_wbusy                  ,
    input   wire                                        i_sram_b_wbusy                  ,

    output  wire                                        o_sram_a_req                    ,
    output  wire                                        o_sram_a_ren                    ,
    output  wire    [SRAM_ADDR_W         -1 :0]         o_sram_a_raddr                  ,
    input   wire    [127                    :0]         i_sram_a_rdata                  ,
    input   wire                                        i_sram_a_rvalid                 ,
    output  wire                                        o_sram_b_req                    ,
    output  wire                                        o_sram_b_ren                    ,
    output  wire    [SRAM_ADDR_W         -1 :0]         o_sram_b_raddr                  ,
    input   wire    [127                    :0]         i_sram_b_rdata                  ,
    input   wire                                        i_sram_b_rvalid                 ,

    output  wire                                        o_fifo_wr_en                    ,
    output  wire    [255                    :0]         o_fifo_wdata                    ,
    output  reg     [3                      :0]         o_fifo_fcnt                     ,
    input   wire                                        i_fifo_full                     ,

    output  reg                                         o_fetcher_done                  ,
    output  reg                                         o_fetcher_bank                  ,
    output  reg     [3                      :0]         o_fetcher_fcnt                  ,
    output  reg                                         o_fetcher_bank0_done            ,
    output  reg                                         o_fetcher_bank1_done
);

    localparam  integer                             SRAM_Y_LOWER_BASE_WORDS_LE2048 = 1024;
    localparam  integer                             SRAM_Y_LOWER_BASE_WORDS_GT2048 = 2048;
    localparam  integer                             SRAM_UV_BASE_WORDS_LE2048      = 2048;
    localparam  integer                             SRAM_UV_BASE_WORDS_GT2048      = 4096;
    localparam  integer                             ENTRY_DEPTH                     = 8;
    localparam  integer                             ENTRY_PTR_W                     = 3;
    localparam  integer                             ENTRY_CNT_W                     = 4;
    localparam  integer                             DESC_DEPTH                      = 8;
    localparam  integer                             DESC_PTR_W                      = 3;
    localparam  integer                             DESC_CNT_W                      = 4;

    wire                                            is_rgba                         ;
    wire                                            wide_profile                    ;
    wire                                            wide_yuv420_profile             ;
    wire        [16                     :0]         w_limit_rgba_full               ;
    wire        [16                     :0]         w_limit_yuv_full                ;
    wire        [16                     :0]         w_limit_p010_full               ;
    wire        [12                     :0]         w_limit_rgba                    ;
    wire        [12                     :0]         w_limit_yuv                     ;
    wire        [12                     :0]         w_limit_p010                    ;
    wire        [12                     :0]         w_limit                         ;
    wire        [2                      :0]         y_line_in_group                 ;
    wire                                            y_second_half                   ;
    wire                                            next_y_second_half              ;
    wire        [16                     :0]         y_lower_base_full               ;
    wire        [16                     :0]         uv_slot_size_full               ;
    wire        [16                     :0]         uv_slot_base_full               ;
    wire        [16                     :0]         uv_base_full                    ;
    wire        [16                     :0]         y_group_off_full                ;
    wire        [16                     :0]         y_off_rgba_full                 ;
    wire        [16                     :0]         y_off_yuv8_full                 ;
    wire        [16                     :0]         y_off_p010_full                 ;
    wire        [16                     :0]         y_off_full                      ;
    wire        [16                     :0]         addr_y_full                     ;
    wire        [SRAM_ADDR_W         -1 :0]         addr_y                          ;
    wire        [SRAM_ADDR_W         -1 :0]         addr_y_p1                       ;
    wire        [2                      :0]         uv_l                            ;
    wire        [2                      :0]         uv_l_addr                       ;
    wire                                            uv_second_half                  ;
    wire                                            y_bank_sel                      ;
    wire                                            uv_bank_sel                     ;
    wire                                            next_y_bank_sel                 ;
    wire        [16                     :0]         uv_row_off_yuv8_full            ;
    wire        [16                     :0]         uv_row_off_p010_full            ;
    wire        [16                     :0]         uv_row_off_full                 ;
    wire        [16                     :0]         addr_uv_full                    ;
    wire        [SRAM_ADDR_W         -1 :0]         addr_uv                         ;
    wire                                            current_line_has_uv             ;
    wire                                            current_pair_has_second         ;
    wire        [1                      :0]         current_pair_step               ;
    wire                                            frame_start                     ;
    wire        [13                     :0]         issue_pair_next_word_sum        ;
    wire                                            pair_line_done                  ;
    wire                                            pair_bank_done                  ;
    wire        [4                      :0]         next_line_idx                   ;
    wire        [12                     :0]         next_word_idx                   ;
    wire        [2                      :0]         next_y_line_in_group            ;
    wire        [16                     :0]         next_y_off_rgba_full            ;
    wire        [16                     :0]         next_y_off_yuv8_full            ;
    wire        [16                     :0]         next_y_off_p010_full            ;
    wire        [16                     :0]         next_y_group_off_full           ;
    wire        [16                     :0]         next_y_off_full                 ;
    wire        [16                     :0]         next_addr_y_full                ;
    wire        [SRAM_ADDR_W         -1 :0]         next_addr_y                     ;
    wire                                            next_line_has_uv                ;
    wire                                            next_pair_has_second            ;
    wire        [1                      :0]         next_pair_step                  ;
    wire                                            push_fire                       ;
    wire                                            start_fetch_fire                ;
    wire                                            first_wait_y_lower              ;
    wire                                            first_issue_req                 ;
    wire                                            issue_first_fire                ;
    wire                                            second_cand_a_ready             ;
    wire                                            second_cand_b_ready             ;
    wire                                            a_desc_empty                    ;
    wire                                            b_desc_empty                    ;
    wire                                            a_desc_full                     ;
    wire                                            b_desc_full                     ;
    wire                                            a_desc_pop_fire                 ;
    wire                                            b_desc_pop_fire                 ;
    wire                                            a_desc_can_push                 ;
    wire                                            b_desc_can_push                 ;
    wire                                            a_read_desire                   ;
    wire                                            b_read_desire                   ;
    wire                                            a_issue_second                  ;
    wire                                            b_issue_second                  ;
    wire                                            a_issue_first                   ;
    wire                                            b_issue_first                   ;
    wire                                            a_desc_push_fire                ;
    wire                                            b_desc_push_fire                ;
    wire                                            entry_empty                     ;
    wire                                            entry_full                      ;
    wire                                            entry_can_alloc                 ;
    wire                                            head_entry_ready                ;
    wire                                            head_first_bank_done            ;
    wire                                            head_final_bank_done            ;
    wire                                            head_bank0_done                 ;
    wire                                            head_bank1_done                 ;
    wire                                            final_bank_done                 ;

    reg                                             fetch_active                    ;
    reg                                             issue_done                      ;
    reg         [2                      :0]         state                           ;
    reg         [4                      :0]         tot_lines                       ;
    reg                                             has_uv                          ;
    reg                                             is_yuv420                       ;
    reg                                             is_y_stride_1k                  ;
    reg                                             is_p010                         ;
    reg         [4                      :0]         line_idx                        ;
    reg         [12                     :0]         word_idx                        ;
    reg                                             target_bank                     ;
    reg         [3                      :0]         target_fcnt                     ;
    reg                                             target_uv_slot                  ;
    reg                                             target_y_lower_ready            ;
    reg                                             target_uv_ready                 ;
    reg         [ENTRY_PTR_W         -1 :0]         alloc_ptr                       ;
    reg         [ENTRY_PTR_W         -1 :0]         head_ptr                        ;
    reg         [ENTRY_CNT_W         -1 :0]         entry_count                     ;
    reg         [DESC_PTR_W          -1 :0]         a_desc_head                     ;
    reg         [DESC_PTR_W          -1 :0]         a_desc_tail                     ;
    reg         [DESC_CNT_W          -1 :0]         a_desc_count                    ;
    reg         [DESC_PTR_W          -1 :0]         b_desc_head                     ;
    reg         [DESC_PTR_W          -1 :0]         b_desc_tail                     ;
    reg         [DESC_CNT_W          -1 :0]         b_desc_count                    ;
    reg                                             a_read_req_r                    ;
    reg                                             b_read_req_r                    ;
    reg                                             second_cand_a_vld               ;
    reg                                             second_cand_b_vld               ;
    reg         [ENTRY_PTR_W         -1 :0]         second_cand_a_idx               ;
    reg         [ENTRY_PTR_W         -1 :0]         second_cand_b_idx               ;
    reg                                             entry_valid                     [0:ENTRY_DEPTH-1];
    reg                                             entry_first_valid               [0:ENTRY_DEPTH-1];
    reg                                             entry_second_valid              [0:ENTRY_DEPTH-1];
    reg                                             entry_has_second                [0:ENTRY_DEPTH-1];
    reg                                             entry_second_issued             [0:ENTRY_DEPTH-1];
    reg                                             entry_second_bank               [0:ENTRY_DEPTH-1];
    reg                                             entry_second_wait_uv            [0:ENTRY_DEPTH-1];
    reg         [SRAM_ADDR_W         -1 :0]         entry_second_addr               [0:ENTRY_DEPTH-1];
    reg         [127                    :0]         entry_first_data                [0:ENTRY_DEPTH-1];
    reg         [127                    :0]         entry_second_data               [0:ENTRY_DEPTH-1];
    reg                                             entry_first_bank_done           [0:ENTRY_DEPTH-1];
    reg                                             entry_final_bank_done           [0:ENTRY_DEPTH-1];
    reg                                             entry_final_done_bank           [0:ENTRY_DEPTH-1];
    reg         [ENTRY_PTR_W         -1 :0]         a_desc_entry                    [0:DESC_DEPTH-1];
    reg                                             a_desc_second                   [0:DESC_DEPTH-1];
    reg         [ENTRY_PTR_W         -1 :0]         b_desc_entry                    [0:DESC_DEPTH-1];
    reg                                             b_desc_second                   [0:DESC_DEPTH-1];
    integer                                         scan_a_idx                      ;
    integer                                         scan_b_idx                      ;
    integer                                         entry_loop_idx                  ;
    integer                                         desc_a_loop_idx                 ;
    integer                                         desc_b_loop_idx                 ;
    reg         [ENTRY_PTR_W         -1 :0]         scan_a_ptr                      ;
    reg         [ENTRY_PTR_W         -1 :0]         scan_b_ptr                      ;

    assign is_rgba                    = !has_uv;
    assign wide_profile               = (cfg_img_width > 16'd2048);
    assign wide_yuv420_profile        = has_uv && is_yuv420;
    assign w_limit_rgba_full          = ({1'b0, cfg_img_width} + 17'd3) >> 2;
    assign w_limit_yuv_full           = ({1'b0, cfg_img_width} + 17'd15) >> 4;
    assign w_limit_p010_full          = ({1'b0, cfg_img_width} + 17'd7) >> 3;
    assign w_limit_rgba               = (|w_limit_rgba_full[16:13]) ? 13'h1fff : w_limit_rgba_full[12:0];
    assign w_limit_yuv                = (|w_limit_yuv_full[16:13])  ? 13'h1fff : w_limit_yuv_full[12:0];
    assign w_limit_p010               = (|w_limit_p010_full[16:13]) ? 13'h1fff : w_limit_p010_full[12:0];
    assign w_limit                    = is_rgba ? w_limit_rgba : (is_p010 ? w_limit_p010 : w_limit_yuv);
    assign y_line_in_group            = is_p010 ? {1'b0, line_idx[1:0]} : line_idx[2:0];
    assign y_second_half              = wide_yuv420_profile &&
                                        (is_p010 ? line_idx[2] : line_idx[3]);
    assign next_y_second_half         = wide_yuv420_profile &&
                                        (is_p010 ? next_line_idx[2] : next_line_idx[3]);
    assign y_lower_base_full          = wide_profile ? 17'(SRAM_Y_LOWER_BASE_WORDS_GT2048) :
                                                       17'(SRAM_Y_LOWER_BASE_WORDS_LE2048);
    assign uv_slot_size_full          = wide_profile ? 17'd1024 :
                                                       17'd512;
    assign uv_slot_base_full          = target_uv_slot ? (y_lower_base_full + uv_slot_size_full) :
                                                         y_lower_base_full;
    assign uv_base_full               = wide_yuv420_profile ? uv_slot_base_full :
                                        (wide_profile ? 17'(SRAM_UV_BASE_WORDS_GT2048) :
                                                        17'(SRAM_UV_BASE_WORDS_LE2048));
    assign y_group_off_full           = wide_yuv420_profile ? 17'd0 :
                                        (is_p010 ? (line_idx[2] ? y_lower_base_full : 17'd0) :
                                                   (line_idx[3] ? y_lower_base_full : 17'd0));
    assign y_off_rgba_full            = wide_profile ? {4'd0, y_line_in_group, 10'd0} :
                                                       {5'd0, y_line_in_group, 9'd0};
    assign y_off_yuv8_full            = wide_profile ? {6'd0, y_line_in_group, 8'd0} :
                                                       {7'd0, y_line_in_group, 7'd0};
    assign y_off_p010_full            = wide_profile ? {5'd0, y_line_in_group, 9'd0} :
                                                       {6'd0, y_line_in_group, 8'd0};
    assign y_off_full                 = is_y_stride_1k ? y_off_rgba_full :
                                        (is_p010 ? y_off_p010_full : y_off_yuv8_full);
    assign addr_y_full                = y_group_off_full + y_off_full + {4'd0, word_idx};
    assign addr_y                     = addr_y_full[SRAM_ADDR_W-1:0];
    assign addr_y_p1                  = addr_y + SRAM_ADDR_W'(1);
    assign uv_l                       = is_yuv420 ? (is_p010 ? {1'b0, line_idx[2:1]} : line_idx[3:1]) : line_idx[2:0];
    assign uv_second_half             = wide_yuv420_profile &&
                                        (is_p010 ? uv_l[1] : uv_l[2]);
    assign uv_l_addr                  = (wide_yuv420_profile && uv_second_half) ?
                                        (is_p010 ? {2'd0, uv_l[0]} :
                                                   {1'b0, uv_l[1:0]}) :
                                        uv_l;
    assign y_bank_sel                 = y_second_half ? ~target_bank : target_bank;
    assign uv_bank_sel                = uv_second_half ? ~target_bank : target_bank;
    assign next_y_bank_sel            = next_y_second_half ? ~target_bank : target_bank;
    assign uv_row_off_yuv8_full       = wide_profile ? {6'd0, uv_l_addr, 8'd0} :
                                                       {7'd0, uv_l_addr, 7'd0};
    assign uv_row_off_p010_full       = wide_profile ? {5'd0, uv_l_addr, 9'd0} :
                                                       {6'd0, uv_l_addr, 8'd0};
    assign uv_row_off_full            = is_p010 ? uv_row_off_p010_full : uv_row_off_yuv8_full;
    assign addr_uv_full               = uv_base_full + uv_row_off_full + {4'd0, word_idx};
    assign addr_uv                    = addr_uv_full[SRAM_ADDR_W-1:0];
    assign current_line_has_uv        = has_uv && (!is_yuv420 || !line_idx[0]);
    assign current_pair_has_second    = current_line_has_uv | (is_rgba && (word_idx != (w_limit - 13'd1)));
    assign current_pair_step          = (is_rgba && current_pair_has_second) ? 2'd2 : 2'd1;
    assign frame_start                = (i_frame_start == 1'b1);
    assign issue_pair_next_word_sum   = {1'b0, word_idx} + {12'd0, current_pair_step};
    assign pair_line_done             = (issue_pair_next_word_sum >= {1'b0, w_limit});
    assign pair_bank_done             = pair_line_done && (line_idx == (tot_lines - 5'd1));
    assign next_line_idx              = pair_line_done ? (line_idx + 5'd1) : line_idx;
    assign next_word_idx              = pair_line_done ? 13'd0 : issue_pair_next_word_sum[12:0];
    assign next_y_line_in_group       = is_p010 ? {1'b0, next_line_idx[1:0]} : next_line_idx[2:0];
    assign next_y_group_off_full      = wide_yuv420_profile ? 17'd0 :
                                        (is_p010 ? (next_line_idx[2] ? y_lower_base_full : 17'd0) :
                                                   (next_line_idx[3] ? y_lower_base_full : 17'd0));
    assign next_y_off_rgba_full       = wide_profile ? {4'd0, next_y_line_in_group, 10'd0} :
                                                       {5'd0, next_y_line_in_group, 9'd0};
    assign next_y_off_yuv8_full       = wide_profile ? {6'd0, next_y_line_in_group, 8'd0} :
                                                       {7'd0, next_y_line_in_group, 7'd0};
    assign next_y_off_p010_full       = wide_profile ? {5'd0, next_y_line_in_group, 9'd0} :
                                                       {6'd0, next_y_line_in_group, 8'd0};
    assign next_y_off_full            = is_y_stride_1k ? next_y_off_rgba_full :
                                        (is_p010 ? next_y_off_p010_full : next_y_off_yuv8_full);
    assign next_addr_y_full           = next_y_group_off_full + next_y_off_full + {4'd0, next_word_idx};
    assign next_addr_y                = next_addr_y_full[SRAM_ADDR_W-1:0];
    assign next_line_has_uv           = has_uv && (!is_yuv420 || !next_line_idx[0]);
    assign next_pair_has_second       = next_line_has_uv | (is_rgba && (next_word_idx != (w_limit - 13'd1)));
    assign next_pair_step             = (is_rgba && next_pair_has_second) ? 2'd2 : 2'd1;
    assign entry_empty                = (entry_count == {ENTRY_CNT_W{1'b0}});
    assign entry_full                 = (entry_count == ENTRY_CNT_W'(ENTRY_DEPTH));
    assign entry_can_alloc            = !entry_full;
    assign start_fetch_fire           = !fetch_active && i_buffer_vld && (w_limit != 13'd0);
    assign first_wait_y_lower         = wide_yuv420_profile && y_second_half &&
                                        !target_y_lower_ready;
    assign first_issue_req            = fetch_active && !issue_done &&
                                        !first_wait_y_lower && entry_can_alloc;
    assign a_desc_empty               = (a_desc_count == {DESC_CNT_W{1'b0}});
    assign b_desc_empty               = (b_desc_count == {DESC_CNT_W{1'b0}});
    assign a_desc_full                = (a_desc_count == DESC_CNT_W'(DESC_DEPTH));
    assign b_desc_full                = (b_desc_count == DESC_CNT_W'(DESC_DEPTH));
    assign a_desc_pop_fire            = i_sram_a_rvalid && !a_desc_empty;
    assign b_desc_pop_fire            = i_sram_b_rvalid && !b_desc_empty;
    assign a_desc_can_push            = !a_desc_full || a_desc_pop_fire;
    assign b_desc_can_push            = !b_desc_full || b_desc_pop_fire;
    assign a_read_desire              = (second_cand_a_vld && a_desc_can_push) ||
                                        (first_issue_req && (y_bank_sel == 1'b0) &&
                                         a_desc_can_push);
    assign b_read_desire              = (second_cand_b_vld && b_desc_can_push) ||
                                        (first_issue_req && (y_bank_sel == 1'b1) &&
                                         b_desc_can_push);
    assign second_cand_a_ready        = second_cand_a_vld && !i_sram_a_wbusy && a_desc_can_push;
    assign second_cand_b_ready        = second_cand_b_vld && !i_sram_b_wbusy && b_desc_can_push;
    assign a_issue_second             = second_cand_a_ready;
    assign b_issue_second             = second_cand_b_ready;
    assign a_issue_first              = first_issue_req && (y_bank_sel == 1'b0) &&
                                        !i_sram_a_wbusy && a_desc_can_push &&
                                        !a_issue_second;
    assign b_issue_first              = first_issue_req && (y_bank_sel == 1'b1) &&
                                        !i_sram_b_wbusy && b_desc_can_push &&
                                        !b_issue_second;
    assign issue_first_fire           = a_issue_first || b_issue_first;
    assign a_desc_push_fire           = a_issue_second || a_issue_first;
    assign b_desc_push_fire           = b_issue_second || b_issue_first;
    assign o_sram_a_req               = a_read_req_r;
    assign o_sram_a_ren               = a_desc_push_fire;
    assign o_sram_b_req               = b_read_req_r;
    assign o_sram_b_ren               = b_desc_push_fire;
    assign o_sram_a_raddr             = a_issue_second ? entry_second_addr[second_cand_a_idx] :
                                                         addr_y;
    assign o_sram_b_raddr             = b_issue_second ? entry_second_addr[second_cand_b_idx] :
                                                         addr_y;
    assign o_fifo_wr_en               = push_fire;
    assign o_fifo_wdata               = {entry_second_data[head_ptr], entry_first_data[head_ptr]};
    assign head_entry_ready           = !entry_empty &&
                                        entry_valid[head_ptr] &&
                                        entry_first_valid[head_ptr] &&
                                        entry_second_valid[head_ptr];
    assign push_fire                  = head_entry_ready && !i_fifo_full;
    assign head_first_bank_done       = entry_first_bank_done[head_ptr];
    assign head_final_bank_done       = entry_final_bank_done[head_ptr];
    assign head_bank0_done            = (head_first_bank_done && (target_bank == 1'b0)) ||
                                        (head_final_bank_done && (entry_final_done_bank[head_ptr] == 1'b0));
    assign head_bank1_done            = (head_first_bank_done && (target_bank == 1'b1)) ||
                                        (head_final_bank_done && (entry_final_done_bank[head_ptr] == 1'b1));
    assign final_bank_done            = wide_yuv420_profile ? ~target_bank : target_bank;

    always @(*) begin
        second_cand_a_vld = 1'b0;
        second_cand_a_idx = {ENTRY_PTR_W{1'b0}};
        scan_a_ptr        = {ENTRY_PTR_W{1'b0}};
        for (scan_a_idx = 0; scan_a_idx < ENTRY_DEPTH; scan_a_idx = scan_a_idx + 1) begin
            scan_a_ptr = head_ptr + scan_a_idx[ENTRY_PTR_W-1:0];
            if (!second_cand_a_vld &&
                entry_valid[scan_a_ptr] &&
                entry_has_second[scan_a_ptr] &&
                !entry_second_issued[scan_a_ptr] &&
                !entry_second_valid[scan_a_ptr] &&
                (!entry_second_wait_uv[scan_a_ptr] || target_uv_ready) &&
                (entry_second_bank[scan_a_ptr] == 1'b0)) begin
                second_cand_a_vld = 1'b1;
                second_cand_a_idx = scan_a_ptr;
            end
        end
    end

    always @(*) begin
        second_cand_b_vld = 1'b0;
        second_cand_b_idx = {ENTRY_PTR_W{1'b0}};
        scan_b_ptr        = {ENTRY_PTR_W{1'b0}};
        for (scan_b_idx = 0; scan_b_idx < ENTRY_DEPTH; scan_b_idx = scan_b_idx + 1) begin
            scan_b_ptr = head_ptr + scan_b_idx[ENTRY_PTR_W-1:0];
            if (!second_cand_b_vld &&
                entry_valid[scan_b_ptr] &&
                entry_has_second[scan_b_ptr] &&
                !entry_second_issued[scan_b_ptr] &&
                !entry_second_valid[scan_b_ptr] &&
                (!entry_second_wait_uv[scan_b_ptr] || target_uv_ready) &&
                (entry_second_bank[scan_b_ptr] == 1'b1)) begin
                second_cand_b_vld = 1'b1;
                second_cand_b_idx = scan_b_ptr;
            end
        end
    end

    always @(*) begin
        case (cfg_format)
            5'b00000, 5'b00001: begin
                tot_lines=5'd4;  has_uv=1'b0; is_yuv420=1'b0; is_y_stride_1k=1'b1; is_p010=1'b0;
            end
            5'b00010,
            5'b01000, 5'b01001: begin
                tot_lines=5'd16; has_uv=1'b1; is_yuv420=1'b1; is_y_stride_1k=1'b0; is_p010=1'b0;
            end
            5'b00011,
            5'b01110, 5'b01111: begin
                tot_lines=5'd8;  has_uv=1'b1; is_yuv420=1'b1; is_y_stride_1k=1'b0; is_p010=1'b1;
            end
            default:  begin
                tot_lines=5'd4;  has_uv=1'b0; is_yuv420=1'b0; is_y_stride_1k=1'b1; is_p010=1'b0;
            end
        endcase
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            fetch_active <= 1'b0;
        else if (frame_start)
            fetch_active <= 1'b0;
        else if (start_fetch_fire)
            fetch_active <= 1'b1;
        else if (push_fire && entry_final_bank_done[head_ptr])
            fetch_active <= 1'b0;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            state <= 3'd0;
        else if (frame_start)
            state <= 3'd0;
        else if (fetch_active || start_fetch_fire)
            state <= 3'd1;
        else
            state <= 3'd0;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            issue_done <= 1'b0;
        else if (frame_start)
            issue_done <= 1'b0;
        else if (start_fetch_fire)
            issue_done <= 1'b0;
        else if (issue_first_fire && pair_bank_done)
            issue_done <= 1'b1;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            target_bank <= 1'b0;
        else if (frame_start)
            target_bank <= 1'b0;
        else if (start_fetch_fire)
            target_bank <= i_writer_bank;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            target_fcnt <= 4'd0;
        else if (frame_start)
            target_fcnt <= 4'd0;
        else if (start_fetch_fire)
            target_fcnt <= i_buffer_fcnt;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            target_uv_slot <= 1'b0;
        else if (frame_start)
            target_uv_slot <= 1'b0;
        else if (start_fetch_fire)
            target_uv_slot <= i_buffer_uv_slot;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            target_y_lower_ready <= 1'b0;
        else if (frame_start)
            target_y_lower_ready <= 1'b0;
        else if (start_fetch_fire)
            target_y_lower_ready <= i_buffer_y_lower_ready | i_y_lower_done;
        else if (i_y_lower_done)
            target_y_lower_ready <= 1'b1;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            target_uv_ready <= 1'b0;
        else if (frame_start)
            target_uv_ready <= 1'b0;
        else if (start_fetch_fire)
            target_uv_ready <= i_buffer_uv_ready | i_uv_done;
        else if (i_uv_done)
            target_uv_ready <= 1'b1;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            line_idx <= 5'd0;
        else if (frame_start)
            line_idx <= 5'd0;
        else if (start_fetch_fire)
            line_idx <= 5'd0;
        else if (issue_first_fire && !pair_bank_done)
            line_idx <= next_line_idx;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            word_idx <= 13'd0;
        else if (frame_start)
            word_idx <= 13'd0;
        else if (start_fetch_fire)
            word_idx <= 13'd0;
        else if (issue_first_fire)
            word_idx <= pair_bank_done ? 13'd0 : next_word_idx;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            alloc_ptr <= {ENTRY_PTR_W{1'b0}};
        else if (frame_start)
            alloc_ptr <= {ENTRY_PTR_W{1'b0}};
        else if (start_fetch_fire)
            alloc_ptr <= {ENTRY_PTR_W{1'b0}};
        else if (issue_first_fire)
            alloc_ptr <= alloc_ptr + ENTRY_PTR_W'(1);
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            head_ptr <= {ENTRY_PTR_W{1'b0}};
        else if (frame_start)
            head_ptr <= {ENTRY_PTR_W{1'b0}};
        else if (start_fetch_fire)
            head_ptr <= {ENTRY_PTR_W{1'b0}};
        else if (push_fire)
            head_ptr <= head_ptr + ENTRY_PTR_W'(1);
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            entry_count <= {ENTRY_CNT_W{1'b0}};
        else if (frame_start)
            entry_count <= {ENTRY_CNT_W{1'b0}};
        else if (start_fetch_fire)
            entry_count <= {ENTRY_CNT_W{1'b0}};
        else begin
            case ({issue_first_fire, push_fire})
                2'b10: entry_count <= entry_count + ENTRY_CNT_W'(1);
                2'b01: entry_count <= entry_count - ENTRY_CNT_W'(1);
                default: entry_count <= entry_count;
            endcase
        end
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            a_desc_head <= {DESC_PTR_W{1'b0}};
        else if (frame_start)
            a_desc_head <= {DESC_PTR_W{1'b0}};
        else if (start_fetch_fire)
            a_desc_head <= {DESC_PTR_W{1'b0}};
        else if (a_desc_pop_fire)
            a_desc_head <= a_desc_head + DESC_PTR_W'(1);
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            a_desc_tail <= {DESC_PTR_W{1'b0}};
        else if (frame_start)
            a_desc_tail <= {DESC_PTR_W{1'b0}};
        else if (start_fetch_fire)
            a_desc_tail <= {DESC_PTR_W{1'b0}};
        else if (a_desc_push_fire)
            a_desc_tail <= a_desc_tail + DESC_PTR_W'(1);
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            a_desc_count <= {DESC_CNT_W{1'b0}};
        else if (frame_start)
            a_desc_count <= {DESC_CNT_W{1'b0}};
        else if (start_fetch_fire)
            a_desc_count <= {DESC_CNT_W{1'b0}};
        else begin
            case ({a_desc_push_fire, a_desc_pop_fire})
                2'b10: a_desc_count <= a_desc_count + DESC_CNT_W'(1);
                2'b01: a_desc_count <= a_desc_count - DESC_CNT_W'(1);
                default: a_desc_count <= a_desc_count;
            endcase
        end
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            b_desc_head <= {DESC_PTR_W{1'b0}};
        else if (frame_start)
            b_desc_head <= {DESC_PTR_W{1'b0}};
        else if (start_fetch_fire)
            b_desc_head <= {DESC_PTR_W{1'b0}};
        else if (b_desc_pop_fire)
            b_desc_head <= b_desc_head + DESC_PTR_W'(1);
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            b_desc_tail <= {DESC_PTR_W{1'b0}};
        else if (frame_start)
            b_desc_tail <= {DESC_PTR_W{1'b0}};
        else if (start_fetch_fire)
            b_desc_tail <= {DESC_PTR_W{1'b0}};
        else if (b_desc_push_fire)
            b_desc_tail <= b_desc_tail + DESC_PTR_W'(1);
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            b_desc_count <= {DESC_CNT_W{1'b0}};
        else if (frame_start)
            b_desc_count <= {DESC_CNT_W{1'b0}};
        else if (start_fetch_fire)
            b_desc_count <= {DESC_CNT_W{1'b0}};
        else begin
            case ({b_desc_push_fire, b_desc_pop_fire})
                2'b10: b_desc_count <= b_desc_count + DESC_CNT_W'(1);
                2'b01: b_desc_count <= b_desc_count - DESC_CNT_W'(1);
                default: b_desc_count <= b_desc_count;
            endcase
        end
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            a_read_req_r <= 1'b0;
        else if (frame_start || start_fetch_fire)
            a_read_req_r <= 1'b0;
        else
            a_read_req_r <= a_read_desire;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            b_read_req_r <= 1'b0;
        else if (frame_start || start_fetch_fire)
            b_read_req_r <= 1'b0;
        else
            b_read_req_r <= b_read_desire;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            for (entry_loop_idx = 0; entry_loop_idx < ENTRY_DEPTH; entry_loop_idx = entry_loop_idx + 1) begin
                entry_valid[entry_loop_idx]           <= 1'b0;
                entry_first_valid[entry_loop_idx]     <= 1'b0;
                entry_second_valid[entry_loop_idx]    <= 1'b0;
                entry_has_second[entry_loop_idx]      <= 1'b0;
                entry_second_issued[entry_loop_idx]   <= 1'b0;
                entry_second_bank[entry_loop_idx]     <= 1'b0;
                entry_second_wait_uv[entry_loop_idx]  <= 1'b0;
                entry_second_addr[entry_loop_idx]     <= {SRAM_ADDR_W{1'b0}};
                entry_first_data[entry_loop_idx]      <= 128'd0;
                entry_second_data[entry_loop_idx]     <= 128'd0;
                entry_first_bank_done[entry_loop_idx] <= 1'b0;
                entry_final_bank_done[entry_loop_idx] <= 1'b0;
                entry_final_done_bank[entry_loop_idx] <= 1'b0;
            end
        else if (frame_start || start_fetch_fire)
            for (entry_loop_idx = 0; entry_loop_idx < ENTRY_DEPTH; entry_loop_idx = entry_loop_idx + 1) begin
                entry_valid[entry_loop_idx]           <= 1'b0;
                entry_first_valid[entry_loop_idx]     <= 1'b0;
                entry_second_valid[entry_loop_idx]    <= 1'b0;
                entry_has_second[entry_loop_idx]      <= 1'b0;
                entry_second_issued[entry_loop_idx]   <= 1'b0;
                entry_second_bank[entry_loop_idx]     <= 1'b0;
                entry_second_wait_uv[entry_loop_idx]  <= 1'b0;
                entry_second_addr[entry_loop_idx]     <= {SRAM_ADDR_W{1'b0}};
                entry_first_bank_done[entry_loop_idx] <= 1'b0;
                entry_final_bank_done[entry_loop_idx] <= 1'b0;
                entry_final_done_bank[entry_loop_idx] <= 1'b0;
            end
        else begin
            if (push_fire)
                entry_valid[head_ptr] <= 1'b0;

            if (issue_first_fire) begin
                entry_valid[alloc_ptr]           <= 1'b1;
                entry_first_valid[alloc_ptr]     <= 1'b0;
                entry_second_valid[alloc_ptr]    <= !current_pair_has_second;
                entry_has_second[alloc_ptr]      <= current_pair_has_second;
                entry_second_issued[alloc_ptr]   <= 1'b0;
                entry_second_bank[alloc_ptr]     <= has_uv ? uv_bank_sel : y_bank_sel;
                entry_second_wait_uv[alloc_ptr]  <= has_uv && current_line_has_uv;
                entry_second_addr[alloc_ptr]     <= has_uv ? addr_uv : addr_y_p1;
                entry_second_data[alloc_ptr]     <= 128'd0;
                entry_first_bank_done[alloc_ptr] <= pair_line_done && wide_yuv420_profile &&
                                                    (is_p010 ? (line_idx == 5'd3) :
                                                               (line_idx == 5'd7));
                entry_final_bank_done[alloc_ptr] <= pair_bank_done;
                entry_final_done_bank[alloc_ptr] <= final_bank_done;
            end

            if (a_issue_second)
                entry_second_issued[second_cand_a_idx] <= 1'b1;
            if (b_issue_second)
                entry_second_issued[second_cand_b_idx] <= 1'b1;

            if (a_desc_pop_fire) begin
                if (a_desc_second[a_desc_head]) begin
                    entry_second_valid[a_desc_entry[a_desc_head]] <= 1'b1;
                    entry_second_data[a_desc_entry[a_desc_head]]  <= i_sram_a_rdata;
                end else begin
                    entry_first_valid[a_desc_entry[a_desc_head]] <= 1'b1;
                    entry_first_data[a_desc_entry[a_desc_head]]  <= i_sram_a_rdata;
                end
            end

            if (b_desc_pop_fire) begin
                if (b_desc_second[b_desc_head]) begin
                    entry_second_valid[b_desc_entry[b_desc_head]] <= 1'b1;
                    entry_second_data[b_desc_entry[b_desc_head]]  <= i_sram_b_rdata;
                end else begin
                    entry_first_valid[b_desc_entry[b_desc_head]] <= 1'b1;
                    entry_first_data[b_desc_entry[b_desc_head]]  <= i_sram_b_rdata;
                end
            end
        end
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            for (desc_a_loop_idx = 0; desc_a_loop_idx < DESC_DEPTH; desc_a_loop_idx = desc_a_loop_idx + 1) begin
                a_desc_entry[desc_a_loop_idx]  <= {ENTRY_PTR_W{1'b0}};
                a_desc_second[desc_a_loop_idx] <= 1'b0;
            end
        else if (frame_start || start_fetch_fire)
            for (desc_a_loop_idx = 0; desc_a_loop_idx < DESC_DEPTH; desc_a_loop_idx = desc_a_loop_idx + 1) begin
                a_desc_entry[desc_a_loop_idx]  <= {ENTRY_PTR_W{1'b0}};
                a_desc_second[desc_a_loop_idx] <= 1'b0;
            end
        else if (a_desc_push_fire) begin
            a_desc_entry[a_desc_tail]  <= a_issue_second ? second_cand_a_idx :
                                                           alloc_ptr;
            a_desc_second[a_desc_tail] <= a_issue_second;
        end
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            for (desc_b_loop_idx = 0; desc_b_loop_idx < DESC_DEPTH; desc_b_loop_idx = desc_b_loop_idx + 1) begin
                b_desc_entry[desc_b_loop_idx]  <= {ENTRY_PTR_W{1'b0}};
                b_desc_second[desc_b_loop_idx] <= 1'b0;
            end
        else if (frame_start || start_fetch_fire)
            for (desc_b_loop_idx = 0; desc_b_loop_idx < DESC_DEPTH; desc_b_loop_idx = desc_b_loop_idx + 1) begin
                b_desc_entry[desc_b_loop_idx]  <= {ENTRY_PTR_W{1'b0}};
                b_desc_second[desc_b_loop_idx] <= 1'b0;
            end
        else if (b_desc_push_fire) begin
            b_desc_entry[b_desc_tail]  <= b_issue_second ? second_cand_b_idx :
                                                           alloc_ptr;
            b_desc_second[b_desc_tail] <= b_issue_second;
        end
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_fifo_fcnt <= 4'd0;
        else if (frame_start)
            o_fifo_fcnt <= 4'd0;
        else if (start_fetch_fire)
            o_fifo_fcnt <= i_buffer_fcnt;
        else if (fetch_active)
            o_fifo_fcnt <= target_fcnt;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_fetcher_done <= 1'b0;
        else if (frame_start)
            o_fetcher_done <= 1'b0;
        else
            o_fetcher_done <= push_fire && head_final_bank_done;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_fetcher_bank <= 1'b0;
        else if (frame_start)
            o_fetcher_bank <= 1'b0;
        else if (push_fire && head_final_bank_done)
            o_fetcher_bank <= target_bank;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_fetcher_fcnt <= 4'd0;
        else if (frame_start)
            o_fetcher_fcnt <= 4'd0;
        else if (push_fire && head_final_bank_done)
            o_fetcher_fcnt <= target_fcnt;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_fetcher_bank0_done <= 1'b0;
        else if (frame_start)
            o_fetcher_bank0_done <= 1'b0;
        else
            o_fetcher_bank0_done <= push_fire && head_bank0_done;
    end

    always @(posedge clk_sram or negedge rst_n) begin
        if (!rst_n)
            o_fetcher_bank1_done <= 1'b0;
        else if (frame_start)
            o_fetcher_bank1_done <= 1'b0;
        else
            o_fetcher_bank1_done <= push_fire && head_bank1_done;
    end
endmodule
