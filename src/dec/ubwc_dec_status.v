module ubwc_dec_status
    (
        input   wire                    i_clk,
        input   wire                    i_rstn,
        input   wire                    i_frame_start,

        input   wire                    i_meta_busy,
        input   wire                    i_tile_busy,
        input   wire                    i_vivo_busy,
        input   wire                    i_otf_busy,
        input   wire                    i_irq_enable,
        input   wire                    i_irq_clear,

        output  wire                    o_frame_active,
        output  wire                    o_any_stage_busy,
        output  wire    [4      -1:0]   o_stage_seen,
        output  wire    [5      -1:0]   o_stage_done,
        output  wire                    o_frame_done,
        output  wire                    o_irq_pending,
        output  wire                    o_irq
    );

    wire                                any_stage_busy;
    wire                                meta_done_next;
    wire                                tile_done_next;
    wire                                vivo_done_next;
    wire                                otf_done_next;
    wire                                frame_done_next;
    reg                                 frame_active_r;
    reg     [4          -1:0]           stage_seen_r;
    reg     [5          -1:0]           stage_done_r;
    reg                                 irq_pending_r;

    assign any_stage_busy              = i_meta_busy | i_tile_busy | i_vivo_busy | i_otf_busy;
    assign meta_done_next              = stage_done_r[0] | (stage_seen_r[0] & !i_meta_busy);
    assign tile_done_next              = stage_done_r[1] | (stage_seen_r[1] & !i_tile_busy);
    assign vivo_done_next              = stage_done_r[2] | (stage_seen_r[2] & !i_vivo_busy);
    assign otf_done_next               = stage_done_r[3] | (stage_seen_r[3] & !i_otf_busy);
    assign frame_done_next             = meta_done_next & tile_done_next &
                                         vivo_done_next & otf_done_next;

    assign o_frame_active              = frame_active_r;
    assign o_any_stage_busy            = any_stage_busy;
    assign o_stage_seen                = stage_seen_r;
    assign o_stage_done                = stage_done_r;
    assign o_frame_done                = stage_done_r[4];
    assign o_irq_pending               = irq_pending_r;
    assign o_irq                       = irq_pending_r & i_irq_enable;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            frame_active_r <= 1'b0;
            stage_seen_r   <= 4'd0;
            stage_done_r   <= 5'd0;
            irq_pending_r  <= 1'b0;
        end else if (i_frame_start) begin
            frame_active_r <= 1'b1;
            stage_seen_r   <= 4'd0;
            stage_done_r   <= 5'd0;
            irq_pending_r  <= 1'b0;
        end else if (i_irq_clear) begin
            irq_pending_r  <= 1'b0;
        end else if (frame_active_r) begin
            if (i_meta_busy) begin
                stage_seen_r[0] <= 1'b1;
            end
            if (i_tile_busy) begin
                stage_seen_r[1] <= 1'b1;
            end
            if (i_vivo_busy) begin
                stage_seen_r[2] <= 1'b1;
            end
            if (i_otf_busy) begin
                stage_seen_r[3] <= 1'b1;
            end

            stage_done_r[0] <= meta_done_next;
            stage_done_r[1] <= tile_done_next;
            stage_done_r[2] <= vivo_done_next;
            stage_done_r[3] <= otf_done_next;
            stage_done_r[4] <= frame_done_next;

            if (frame_done_next) begin
                frame_active_r <= 1'b0;
                irq_pending_r  <= 1'b1;
            end
        end
    end

endmodule
