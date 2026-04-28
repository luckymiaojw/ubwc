module ubwc_enc_status
    (
        input   wire                    i_clk,
        input   wire                    i_rstn,
        input   wire                    i_enc_ubwc_en,

        input   wire    [16     -1:0]   i_cfg_height,
        input   wire    [4      -1:0]   i_cfg_tile_h,
        input   wire    [16     -1:0]   i_cfg_a_tile_cols,
        input   wire    [16     -1:0]   i_cfg_b_tile_cols,

        input   wire                    i_rvi_valid,
        input   wire                    i_rvi_ready,
        input   wire                    i_rvi_last,
        input   wire                    i_coord_fifo_wr_en,
        input   wire                    i_coord_fifo_rd_en,
        input   wire                    i_tile_addr_vld,
        input   wire                    i_meta_addr_valid,
        input   wire                    i_meta_addr_ready,

        input   wire                    i_tile_axi_awvalid,
        input   wire                    i_tile_axi_awready,
        input   wire                    i_tile_axi_wvalid,
        input   wire                    i_tile_axi_bvalid,
        input   wire                    i_tile_axi_bready,
        input   wire                    i_meta_axi_awvalid,
        input   wire                    i_meta_axi_awready,
        input   wire                    i_meta_axi_wvalid,
        input   wire                    i_meta_axi_bvalid,
        input   wire                    i_meta_axi_bready,

        input   wire                    i_core_m_axi_awvalid,
        input   wire                    i_core_m_axi_wvalid,
        input   wire                    i_core_m_axi_bvalid,
        input   wire                    i_m_axi_awvalid,
        input   wire                    i_m_axi_wvalid,
        input   wire                    i_m_axi_bvalid,
        input   wire                    i_irq_enable,
        input   wire                    i_irq_clear,

        output  wire    [8      -1:0]   o_stage_done,
        output  wire                    o_frame_done,
        output  wire                    o_irq_pending,
        output  wire                    o_irq
    );

    wire                                otf_tile_done_fire;
    wire                                ci_stage_done_fire;
    wire                                core_stage_done_fire;
    wire                                tile_addr_done_fire;
    wire                                meta_group_done_fire;
    wire                                tile_axi_aw_fire;
    wire                                tile_axi_b_fire;
    wire                                meta_axi_aw_fire;
    wire                                meta_axi_b_fire;
    wire                                done_status_restart;
    wire                                done_status_activity;
    wire                                format_has_uv_plane;
    wire    [32         -1:0]           y_tile_rows;
    wire    [32         -1:0]           uv_tile_rows;
    wire    [32         -1:0]           a_meta_groups_per_row;
    wire    [32         -1:0]           b_meta_groups_per_row;
    wire    [32         -1:0]           expected_tile_count;
    wire    [32         -1:0]           expected_meta_group_count;
    wire    [32         -1:0]           otf_tile_done_count_next;
    wire    [32         -1:0]           ci_done_count_next;
    wire    [32         -1:0]           core_done_count_next;
    wire    [32         -1:0]           tile_addr_done_count_next;
    wire    [32         -1:0]           meta_group_done_count_next;
    wire    [32         -1:0]           tile_axi_outstanding_next;
    wire    [32         -1:0]           meta_axi_outstanding_next;
    wire                                tile_axi_seen_next;
    wire                                meta_axi_seen_next;
    wire                                otf_tile_stage_done_next;
    wire                                ci_stage_done_next;
    wire                                core_stage_done_next;
    wire                                tile_addr_stage_done_next;
    wire                                meta_stage_done_next;
    wire                                tile_axi_stage_done_next;
    wire                                meta_axi_stage_done_next;
    wire                                frame_done_next;
    wire    [8          -1:0]           stage_done_next;
    reg     [32         -1:0]           otf_tile_done_count;
    reg     [32         -1:0]           ci_done_count;
    reg     [32         -1:0]           core_done_count;
    reg     [32         -1:0]           tile_addr_done_count;
    reg     [32         -1:0]           meta_group_done_count;
    reg     [32         -1:0]           tile_axi_outstanding;
    reg     [32         -1:0]           meta_axi_outstanding;
    reg                                 tile_axi_seen;
    reg                                 meta_axi_seen;
    reg     [8          -1:0]           stage_done_r;
    reg                                 frame_done_r;
    reg                                 irq_pending_r;

    function automatic [31:0] div_ceil_u32;
        input [31:0] value;
        input [31:0] divisor;
        begin
            div_ceil_u32 = (divisor == 32'd0) ? 32'd0 :
                           ((value + divisor - 32'd1) / divisor);
        end
    endfunction

    function automatic [31:0] outstanding_next_u32;
        input [31:0] outstanding_count;
        input        push_event;
        input        pop_event;
        reg   [31:0] outstanding_after_push;
        begin
            outstanding_after_push = outstanding_count + {31'd0, push_event};
            outstanding_next_u32   = (pop_event && (outstanding_after_push != 32'd0)) ?
                                     (outstanding_after_push - 32'd1) :
                                     outstanding_after_push;
        end
    endfunction

    assign otf_tile_done_fire        = i_rvi_valid & i_rvi_ready & i_rvi_last;
    assign ci_stage_done_fire        = i_coord_fifo_wr_en;
    assign core_stage_done_fire      = i_coord_fifo_rd_en;
    assign tile_addr_done_fire       = i_tile_addr_vld;
    assign meta_group_done_fire      = i_meta_addr_valid & i_meta_addr_ready;
    assign tile_axi_aw_fire          = i_tile_axi_awvalid & i_tile_axi_awready;
    assign tile_axi_b_fire           = i_tile_axi_bvalid & i_tile_axi_bready;
    assign meta_axi_aw_fire          = i_meta_axi_awvalid & i_meta_axi_awready;
    assign meta_axi_b_fire           = i_meta_axi_bvalid & i_meta_axi_bready;
    assign done_status_activity      = otf_tile_done_fire | ci_stage_done_fire |
                                       core_stage_done_fire | tile_addr_done_fire |
                                       meta_group_done_fire | tile_axi_aw_fire |
                                       meta_axi_aw_fire;
    assign done_status_restart       = frame_done_r & done_status_activity;
    assign format_has_uv_plane       = (i_cfg_b_tile_cols != 16'd0);
    assign y_tile_rows               = div_ceil_u32({16'd0, i_cfg_height}, {28'd0, i_cfg_tile_h});
    assign uv_tile_rows              = div_ceil_u32({16'd0, i_cfg_height}, {27'd0, i_cfg_tile_h, 1'b0});
    assign a_meta_groups_per_row     = div_ceil_u32({16'd0, i_cfg_a_tile_cols}, 32'd8);
    assign b_meta_groups_per_row     = div_ceil_u32({16'd0, i_cfg_b_tile_cols}, 32'd8);
    assign expected_tile_count       = format_has_uv_plane ?
                                       (({16'd0, i_cfg_b_tile_cols} * y_tile_rows) +
                                        ({16'd0, i_cfg_a_tile_cols} * uv_tile_rows)) :
                                       ({16'd0, i_cfg_a_tile_cols} * y_tile_rows);
    assign expected_meta_group_count = format_has_uv_plane ?
                                       ((b_meta_groups_per_row * y_tile_rows) +
                                        (a_meta_groups_per_row * uv_tile_rows)) :
                                       (a_meta_groups_per_row * y_tile_rows);
    assign otf_tile_done_count_next  = (done_status_restart ? 32'd0 : otf_tile_done_count) +
                                       {31'd0, otf_tile_done_fire};
    assign ci_done_count_next        = (done_status_restart ? 32'd0 : ci_done_count) +
                                       {31'd0, ci_stage_done_fire};
    assign core_done_count_next      = (done_status_restart ? 32'd0 : core_done_count) +
                                       {31'd0, core_stage_done_fire};
    assign tile_addr_done_count_next = (done_status_restart ? 32'd0 : tile_addr_done_count) +
                                       {31'd0, tile_addr_done_fire};
    assign meta_group_done_count_next = (done_status_restart ? 32'd0 : meta_group_done_count) +
                                        {31'd0, meta_group_done_fire};
    assign tile_axi_outstanding_next = outstanding_next_u32(done_status_restart ? 32'd0 : tile_axi_outstanding,
                                                            tile_axi_aw_fire, tile_axi_b_fire);
    assign meta_axi_outstanding_next = outstanding_next_u32(done_status_restart ? 32'd0 : meta_axi_outstanding,
                                                            meta_axi_aw_fire, meta_axi_b_fire);
    assign tile_axi_seen_next        = (done_status_restart ? 1'b0 : tile_axi_seen) | tile_axi_aw_fire;
    assign meta_axi_seen_next        = (done_status_restart ? 1'b0 : meta_axi_seen) | meta_axi_aw_fire;
    assign otf_tile_stage_done_next  = !done_status_restart &&
                                       (stage_done_r[0] |
                                        ((expected_tile_count != 32'd0) &&
                                         (otf_tile_done_count_next >= expected_tile_count)));
    assign ci_stage_done_next        = !done_status_restart &&
                                       (stage_done_r[1] |
                                        ((expected_tile_count != 32'd0) &&
                                         (ci_done_count_next >= expected_tile_count)));
    assign core_stage_done_next      = !done_status_restart &&
                                       (stage_done_r[2] |
                                        ((expected_tile_count != 32'd0) &&
                                         (core_done_count_next >= expected_tile_count)));
    assign tile_addr_stage_done_next = !done_status_restart &&
                                       (stage_done_r[3] |
                                        ((expected_tile_count != 32'd0) &&
                                         (tile_addr_done_count_next >= expected_tile_count)));
    assign meta_stage_done_next      = !done_status_restart &&
                                       (stage_done_r[4] |
                                        ((expected_meta_group_count != 32'd0) &&
                                         (meta_group_done_count_next >= expected_meta_group_count)));
    assign tile_axi_stage_done_next  = !done_status_restart &&
                                       (stage_done_r[5] |
                                        (tile_addr_stage_done_next && tile_axi_seen_next &&
                                         (tile_axi_outstanding_next == 32'd0) &&
                                         !i_tile_axi_awvalid && !i_tile_axi_wvalid && !i_tile_axi_bvalid));
    assign meta_axi_stage_done_next  = !done_status_restart &&
                                       (stage_done_r[6] |
                                        (meta_stage_done_next && meta_axi_seen_next &&
                                         (meta_axi_outstanding_next == 32'd0) &&
                                         !i_meta_axi_awvalid && !i_meta_axi_wvalid && !i_meta_axi_bvalid));
    assign frame_done_next           = !done_status_restart &&
                                       (stage_done_r[7] |
                                        (tile_axi_stage_done_next && meta_axi_stage_done_next &&
                                         !i_core_m_axi_awvalid && !i_core_m_axi_wvalid &&
                                         !i_core_m_axi_bvalid && !i_m_axi_awvalid &&
                                         !i_m_axi_wvalid && !i_m_axi_bvalid));
    assign stage_done_next           = {frame_done_next,
                                        meta_axi_stage_done_next,
                                        tile_axi_stage_done_next,
                                        meta_stage_done_next,
                                        tile_addr_stage_done_next,
                                        core_stage_done_next,
                                        ci_stage_done_next,
                                        otf_tile_stage_done_next};
    assign o_stage_done              = stage_done_r;
    assign o_frame_done              = frame_done_r;
    assign o_irq_pending             = irq_pending_r;
    assign o_irq                     = irq_pending_r & i_irq_enable;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            otf_tile_done_count   <= 32'd0;
            ci_done_count         <= 32'd0;
            core_done_count       <= 32'd0;
            tile_addr_done_count  <= 32'd0;
            meta_group_done_count <= 32'd0;
            tile_axi_outstanding  <= 32'd0;
            meta_axi_outstanding  <= 32'd0;
            tile_axi_seen         <= 1'b0;
            meta_axi_seen         <= 1'b0;
            stage_done_r          <= 8'd0;
            frame_done_r          <= 1'b0;
            irq_pending_r         <= 1'b0;
        end else if (!i_enc_ubwc_en) begin
            otf_tile_done_count   <= 32'd0;
            ci_done_count         <= 32'd0;
            core_done_count       <= 32'd0;
            tile_addr_done_count  <= 32'd0;
            meta_group_done_count <= 32'd0;
            tile_axi_outstanding  <= 32'd0;
            meta_axi_outstanding  <= 32'd0;
            tile_axi_seen         <= 1'b0;
            meta_axi_seen         <= 1'b0;
            stage_done_r          <= 8'd0;
            frame_done_r          <= 1'b0;
            irq_pending_r         <= 1'b0;
        end else begin
            otf_tile_done_count   <= otf_tile_done_count_next;
            ci_done_count         <= ci_done_count_next;
            core_done_count       <= core_done_count_next;
            tile_addr_done_count  <= tile_addr_done_count_next;
            meta_group_done_count <= meta_group_done_count_next;
            tile_axi_outstanding  <= tile_axi_outstanding_next;
            meta_axi_outstanding  <= meta_axi_outstanding_next;
            tile_axi_seen         <= tile_axi_seen_next;
            meta_axi_seen         <= meta_axi_seen_next;
            stage_done_r          <= stage_done_next;
            frame_done_r          <= frame_done_next;
            if (done_status_restart || i_irq_clear) begin
                irq_pending_r <= 1'b0;
            end else if (frame_done_next) begin
                irq_pending_r <= 1'b1;
            end
        end
    end

endmodule
