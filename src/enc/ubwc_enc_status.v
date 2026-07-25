`timescale 1ns/1ps

module ubwc_enc_status
    (
        input   wire                                        i_clk                           ,
        input   wire                                        i_rstn                          ,
        input   wire                                        i_enc_ubwc_en                   ,

        input   wire                                        i_correct_irq_event             ,
        input   wire                                        i_correct_irq_slot              ,
        input   wire                                        i_error_irq_event               ,
        input   wire                                        i_addr_cfg_invalid              ,
        input   wire                                        i_vivo_idle                     ,
        input   wire                                        i_vivo_error                    ,
        input   wire                                        i_axi_idle                      ,

        input   wire                                        i_rvi_valid                     ,
        input   wire                                        i_rvi_ready                     ,
        input   wire                                        i_rvi_last                      ,
        input   wire                                        i_rvi_slot                      ,
        input   wire                                        i_tile_addr_vld                 ,
        input   wire                                        i_tile_addr_slot                ,
        input   wire                                        i_meta_addr_valid               ,
        input   wire                                        i_meta_addr_ready               ,
        input   wire                                        i_meta_slot                     ,

        input   wire                                        i_tile_axi_awvalid              ,
        input   wire                                        i_tile_axi_awready              ,
        input   wire                                        i_tile_axi_awslot               ,
        input   wire                                        i_tile_axi_wvalid               ,
        input   wire                                        i_tile_axi_wready               ,
        input   wire                                        i_tile_axi_wlast                ,
        input   wire                                        i_meta_axi_awvalid              ,
        input   wire                                        i_meta_axi_awready              ,
        input   wire                                        i_meta_axi_awslot               ,
        input   wire                                        i_meta_axi_wvalid               ,
        input   wire                                        i_meta_axi_wready               ,
        input   wire                                        i_meta_axi_wlast                ,

        input   wire    [32                  -1 :0]         i_otf_de_count0                 ,
        input   wire    [32                  -1 :0]         i_otf_de_count1                 ,
        input   wire    [32                  -1 :0]         i_otf_line_count0               ,
        input   wire    [32                  -1 :0]         i_otf_line_count1               ,

        input   wire                                        i_irq_enable                    ,
        input   wire                                        i_irq_clear                     ,

        output  wire    [8                   -1 :0]         o_stage_done                    ,
        output  wire                                        o_frame_done                    ,
        output  wire                                        o_irq_pending                   ,
        output  wire                                        o_irq_correct_pending           ,
        output  wire                                        o_irq_error_pending             ,
        output  wire                                        o_irq                           ,
        output  wire                                        o_enc_idle                      ,
        output  wire                                        o_enc_error                     ,

        output  wire    [32                  -1 :0]         o_meta_count0                   ,
        output  wire    [32                  -1 :0]         o_meta_count1                   ,
        output  wire    [32                  -1 :0]         o_tile_addr_count0              ,
        output  wire    [32                  -1 :0]         o_tile_addr_count1              ,
        output  wire    [32                  -1 :0]         o_otf_tile_count0               ,
        output  wire    [32                  -1 :0]         o_otf_tile_count1               ,
        output  wire    [32                  -1 :0]         o_otf_de_count0                 ,
        output  wire    [32                  -1 :0]         o_otf_de_count1                 ,
        output  wire    [32                  -1 :0]         o_otf_line_count0               ,
        output  wire    [32                  -1 :0]         o_otf_line_count1               ,
        output  wire    [32                  -1 :0]         o_tile_axi_w_count0             ,
        output  wire    [32                  -1 :0]         o_tile_axi_w_count1             ,
        output  wire    [32                  -1 :0]         o_meta_axi_w_count0             ,
        output  wire    [32                  -1 :0]         o_meta_axi_w_count1
    );

    wire                                            otf_tile_fire                   ;
    wire                                            tile_addr_fire                  ;
    wire                                            meta_fire                       ;
    wire                                            tile_axi_aw_fire                ;
    wire                                            tile_axi_w_fire                 ;
    wire                                            tile_axi_w_done_fire            ;
    wire                                            tile_axi_w_slot                 ;
    wire                                            meta_axi_aw_fire                ;
    wire                                            meta_axi_w_fire                 ;
    wire                                            meta_axi_w_done_fire            ;
    wire                                            meta_axi_w_slot                 ;
    wire        [32                  -1 :0]         meta_count0_next                ;
    wire        [32                  -1 :0]         meta_count1_next                ;
    wire        [32                  -1 :0]         tile_addr_count0_next           ;
    wire        [32                  -1 :0]         tile_addr_count1_next           ;
    wire        [32                  -1 :0]         otf_tile_count0_next            ;
    wire        [32                  -1 :0]         otf_tile_count1_next            ;
    wire                                            tile_axi_done_seen0_next        ;
    wire                                            tile_axi_done_seen1_next        ;
    wire                                            meta_axi_done_seen0_next        ;
    wire                                            meta_axi_done_seen1_next        ;
    wire                                            frame_output_done_seen0_set     ;
    wire                                            frame_output_done_seen1_set     ;
    wire                                            frame_done_event                ;
    wire                                            frame_done_slot                 ;
    wire                                            frame_output_done_seen0_next    ;
    wire                                            frame_output_done_seen1_next    ;
    wire        [8                   -1 :0]         stage_done_next                 ;

    reg         [32                  -1 :0]         meta_count0_r                   ;
    reg         [32                  -1 :0]         meta_count1_r                   ;
    reg         [32                  -1 :0]         tile_addr_count0_r              ;
    reg         [32                  -1 :0]         tile_addr_count1_r              ;
    reg         [32                  -1 :0]         otf_tile_count0_r               ;
    reg         [32                  -1 :0]         otf_tile_count1_r               ;
    reg         [32                  -1 :0]         tile_axi_w_count0_r             ;
    reg         [32                  -1 :0]         tile_axi_w_count1_r             ;
    reg         [32                  -1 :0]         meta_axi_w_count0_r             ;
    reg         [32                  -1 :0]         meta_axi_w_count1_r             ;
    reg                                             tile_axi_w_slot_r               ;
    reg                                             meta_axi_w_slot_r               ;
    reg                                             tile_axi_done_seen0_r           ;
    reg                                             tile_axi_done_seen1_r           ;
    reg                                             meta_axi_done_seen0_r           ;
    reg                                             meta_axi_done_seen1_r           ;
    reg                                             frame_output_done_seen0_r       ;
    reg                                             frame_output_done_seen1_r       ;
    reg         [8                   -1 :0]         stage_done_r                    ;
    reg                                             frame_done_r                    ;
    reg                                             irq_correct_pending_r           ;
    reg                                             irq_error_pending_r             ;
    reg                                             vivo_idle_meta_r                ;
    reg                                             vivo_idle_sync_r                ;
    reg                                             vivo_error_meta_r               ;
    reg                                             vivo_error_sync_r               ;

    assign otf_tile_fire             = i_rvi_valid & i_rvi_ready & i_rvi_last;
    assign tile_addr_fire            = i_tile_addr_vld;
    assign meta_fire                 = i_meta_addr_valid & i_meta_addr_ready;
    assign tile_axi_aw_fire          = i_tile_axi_awvalid & i_tile_axi_awready;
    assign tile_axi_w_fire           = i_tile_axi_wvalid & i_tile_axi_wready;
    assign tile_axi_w_done_fire      = tile_axi_w_fire & i_tile_axi_wlast;
    assign tile_axi_w_slot           = tile_axi_aw_fire ? i_tile_axi_awslot :
                                                          tile_axi_w_slot_r;
    assign meta_axi_aw_fire          = i_meta_axi_awvalid & i_meta_axi_awready;
    assign meta_axi_w_fire           = i_meta_axi_wvalid & i_meta_axi_wready;
    assign meta_axi_w_done_fire      = meta_axi_w_fire & i_meta_axi_wlast;
    assign meta_axi_w_slot           = meta_axi_aw_fire ? i_meta_axi_awslot :
                                                          meta_axi_w_slot_r;
    assign meta_count0_next          = meta_count0_r + {31'd0, (meta_fire      & ~i_meta_slot)};
    assign meta_count1_next          = meta_count1_r + {31'd0, (meta_fire      &  i_meta_slot)};
    assign tile_addr_count0_next     = tile_addr_count0_r + {31'd0, (tile_addr_fire & ~i_tile_addr_slot)};
    assign tile_addr_count1_next     = tile_addr_count1_r + {31'd0, (tile_addr_fire &  i_tile_addr_slot)};
    assign otf_tile_count0_next      = otf_tile_count0_r + {31'd0, (otf_tile_fire  & ~i_rvi_slot)};
    assign otf_tile_count1_next      = otf_tile_count1_r + {31'd0, (otf_tile_fire  &  i_rvi_slot)};
    assign tile_axi_done_seen0_next  = tile_axi_done_seen0_r |
                                       (tile_axi_w_done_fire & ~tile_axi_w_slot);
    assign tile_axi_done_seen1_next  = tile_axi_done_seen1_r |
                                       (tile_axi_w_done_fire &  tile_axi_w_slot);
    assign meta_axi_done_seen0_next  = meta_axi_done_seen0_r |
                                       (meta_axi_w_done_fire & ~meta_axi_w_slot);
    assign meta_axi_done_seen1_next  = meta_axi_done_seen1_r |
                                       (meta_axi_w_done_fire &  meta_axi_w_slot);
    assign frame_output_done_seen0_set  = frame_output_done_seen0_r |
                                          (i_correct_irq_event & ~i_correct_irq_slot);
    assign frame_output_done_seen1_set  = frame_output_done_seen1_r |
                                          (i_correct_irq_event &  i_correct_irq_slot);
    assign frame_done_slot              = frame_output_done_seen0_set ? 1'b0 : 1'b1;
    assign frame_done_event          = i_axi_idle &&
                                       (frame_output_done_seen0_set | frame_output_done_seen1_set);
    assign frame_output_done_seen0_next = frame_output_done_seen0_set &
                                          ~(frame_done_event & ~frame_done_slot);
    assign frame_output_done_seen1_next = frame_output_done_seen1_set &
                                          ~(frame_done_event &  frame_done_slot);
    assign stage_done_next[0]        = stage_done_r[0] |
                                       (i_correct_irq_event & ~i_correct_irq_slot);
    assign stage_done_next[1]        = stage_done_r[1] |
                                       (i_correct_irq_event &  i_correct_irq_slot);
    assign stage_done_next[2]        = stage_done_r[2] |
                                       (tile_addr_fire & ~i_tile_addr_slot);
    assign stage_done_next[3]        = stage_done_r[3] |
                                       (tile_addr_fire &  i_tile_addr_slot);
    assign stage_done_next[4]        = stage_done_r[4] |
                                       (meta_fire & ~i_meta_slot);
    assign stage_done_next[5]        = stage_done_r[5] |
                                       (meta_fire &  i_meta_slot);
    assign stage_done_next[6]        = stage_done_r[6] |
                                       (tile_axi_done_seen0_next & meta_axi_done_seen0_next);
    assign stage_done_next[7]        = stage_done_r[7] |
                                       (tile_axi_done_seen1_next & meta_axi_done_seen1_next);
    assign o_stage_done              = stage_done_r;
    assign o_frame_done              = frame_done_r;
    assign o_irq_correct_pending     = irq_correct_pending_r;
    assign o_irq_error_pending       = irq_error_pending_r;
    assign o_irq_pending             = irq_correct_pending_r | irq_error_pending_r;
    assign o_irq                     = (irq_correct_pending_r | irq_error_pending_r) & i_irq_enable;
    assign o_enc_idle                = vivo_idle_sync_r;
    assign o_enc_error               = vivo_error_sync_r;
    assign o_meta_count0             = meta_count0_r;
    assign o_meta_count1             = meta_count1_r;
    assign o_tile_addr_count0        = tile_addr_count0_r;
    assign o_tile_addr_count1        = tile_addr_count1_r;
    assign o_otf_tile_count0         = otf_tile_count0_r;
    assign o_otf_tile_count1         = otf_tile_count1_r;
    assign o_otf_de_count0           = i_otf_de_count0;
    assign o_otf_de_count1           = i_otf_de_count1;
    assign o_otf_line_count0         = i_otf_line_count0;
    assign o_otf_line_count1         = i_otf_line_count1;
    assign o_tile_axi_w_count0       = tile_axi_w_count0_r;
    assign o_tile_axi_w_count1       = tile_axi_w_count1_r;
    assign o_meta_axi_w_count0       = meta_axi_w_count0_r;
    assign o_meta_axi_w_count1       = meta_axi_w_count1_r;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            meta_count0_r <= 32'd0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            meta_count0_r <= 32'd0;
        else
            meta_count0_r <= meta_count0_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            vivo_idle_meta_r <= 1'b0;
        else
            vivo_idle_meta_r <= i_vivo_idle;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            vivo_idle_sync_r <= 1'b0;
        else
            vivo_idle_sync_r <= vivo_idle_meta_r;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            vivo_error_meta_r <= 1'b0;
        else
            vivo_error_meta_r <= i_vivo_error;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            vivo_error_sync_r <= 1'b0;
        else
            vivo_error_sync_r <= vivo_error_meta_r;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            meta_count1_r <= 32'd0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            meta_count1_r <= 32'd0;
        else
            meta_count1_r <= meta_count1_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            tile_addr_count0_r <= 32'd0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            tile_addr_count0_r <= 32'd0;
        else
            tile_addr_count0_r <= tile_addr_count0_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            tile_addr_count1_r <= 32'd0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            tile_addr_count1_r <= 32'd0;
        else
            tile_addr_count1_r <= tile_addr_count1_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            otf_tile_count0_r <= 32'd0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            otf_tile_count0_r <= 32'd0;
        else
            otf_tile_count0_r <= otf_tile_count0_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            otf_tile_count1_r <= 32'd0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            otf_tile_count1_r <= 32'd0;
        else
            otf_tile_count1_r <= otf_tile_count1_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            tile_axi_w_count0_r <= 32'd0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            tile_axi_w_count0_r <= 32'd0;
        else if (tile_axi_w_fire && !tile_axi_w_slot)
            tile_axi_w_count0_r <= tile_axi_w_count0_r + 32'd1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            tile_axi_w_count1_r <= 32'd0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            tile_axi_w_count1_r <= 32'd0;
        else if (tile_axi_w_fire && tile_axi_w_slot)
            tile_axi_w_count1_r <= tile_axi_w_count1_r + 32'd1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            meta_axi_w_count0_r <= 32'd0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            meta_axi_w_count0_r <= 32'd0;
        else if (meta_axi_w_fire && !meta_axi_w_slot)
            meta_axi_w_count0_r <= meta_axi_w_count0_r + 32'd1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            meta_axi_w_count1_r <= 32'd0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            meta_axi_w_count1_r <= 32'd0;
        else if (meta_axi_w_fire && meta_axi_w_slot)
            meta_axi_w_count1_r <= meta_axi_w_count1_r + 32'd1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            tile_axi_w_slot_r <= 1'b0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            tile_axi_w_slot_r <= 1'b0;
        else if (tile_axi_aw_fire)
            tile_axi_w_slot_r <= i_tile_axi_awslot;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            meta_axi_w_slot_r <= 1'b0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            meta_axi_w_slot_r <= 1'b0;
        else if (meta_axi_aw_fire)
            meta_axi_w_slot_r <= i_meta_axi_awslot;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            tile_axi_done_seen0_r <= 1'b0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            tile_axi_done_seen0_r <= 1'b0;
        else
            tile_axi_done_seen0_r <= tile_axi_done_seen0_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            tile_axi_done_seen1_r <= 1'b0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            tile_axi_done_seen1_r <= 1'b0;
        else
            tile_axi_done_seen1_r <= tile_axi_done_seen1_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            meta_axi_done_seen0_r <= 1'b0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            meta_axi_done_seen0_r <= 1'b0;
        else
            meta_axi_done_seen0_r <= meta_axi_done_seen0_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            meta_axi_done_seen1_r <= 1'b0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            meta_axi_done_seen1_r <= 1'b0;
        else
            meta_axi_done_seen1_r <= meta_axi_done_seen1_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            stage_done_r <= 8'd0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            stage_done_r <= 8'd0;
        else
            stage_done_r <= stage_done_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            frame_done_r <= 1'b0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            frame_done_r <= 1'b0;
        else if (frame_done_event)
            frame_done_r <= 1'b1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            irq_correct_pending_r <= 1'b0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            irq_correct_pending_r <= 1'b0;
        else if (frame_done_event)
            irq_correct_pending_r <= 1'b1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            irq_error_pending_r <= 1'b0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            irq_error_pending_r <= 1'b0;
        else if (i_error_irq_event | i_addr_cfg_invalid)
            irq_error_pending_r <= 1'b1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            frame_output_done_seen0_r <= 1'b0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            frame_output_done_seen0_r <= 1'b0;
        else
            frame_output_done_seen0_r <= frame_output_done_seen0_next;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            frame_output_done_seen1_r <= 1'b0;
        else if (!i_enc_ubwc_en || i_irq_clear)
            frame_output_done_seen1_r <= 1'b0;
        else
            frame_output_done_seen1_r <= frame_output_done_seen1_next;
    end

endmodule
