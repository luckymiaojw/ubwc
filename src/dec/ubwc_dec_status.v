module ubwc_dec_status
    (
        input   wire                                        i_clk                           ,
        input   wire                                        i_rstn                          ,
        input   wire                                        i_frame_start                   ,

        input   wire                                        i_meta_busy                     ,
        input   wire                                        i_tile_busy                     ,
        input   wire                                        i_vivo_busy                     ,
        input   wire                                        i_otf_busy                      ,
        input   wire                                        i_correct_irq_event             ,
        input   wire                                        i_error_irq_event               ,
        input   wire                                        i_meta_tile_fire                ,
        input   wire                                        i_tile_addr_fire                ,
        input   wire                                        i_otf_tile_fire                 ,
        input   wire    [31                     :0]         i_otf_line_count                ,
        input   wire    [31                     :0]         i_otf_de_count                  ,
        input   wire                                        i_irq_enable                    ,
        input   wire                                        i_irq_clear                     ,

        output  wire                                        o_frame_active                  ,
        output  wire                                        o_any_stage_busy                ,
        output  wire    [4                   -1 :0]         o_stage_seen                    ,
        output  wire    [5                   -1 :0]         o_stage_done                    ,
        output  wire                                        o_frame_done                    ,
        output  wire                                        o_irq_correct_pending           ,
        output  wire                                        o_irq_error_pending             ,
        output  wire                                        o_irq_pending                   ,
        output  wire                                        o_irq                           ,
        output  wire    [31                     :0]         o_meta_tile_count               ,
        output  wire    [31                     :0]         o_tile_addr_count               ,
        output  wire    [31                     :0]         o_otf_tile_count                ,
        output  wire    [31                     :0]         o_otf_line_count                ,
        output  wire    [31                     :0]         o_otf_de_count
    );

    wire                                            any_stage_busy                  ;
    wire                                            irq_pending_next                ;
    wire                                            meta_done_event                 ;
    wire                                            tile_done_event                 ;
    wire                                            frame_counter_clear             ;
    wire                                            stage_seen0_event               ;
    wire                                            stage_seen1_event               ;
    wire                                            stage_seen2_event               ;
    wire                                            stage_seen3_event               ;

    reg                                             frame_active_r                  ;
    reg                                             meta_busy_d                     ;
    reg                                             tile_busy_d                     ;
    reg         [4                   -1 :0]         stage_seen_r                    ;
    reg         [5                   -1 :0]         stage_done_r                    ;
    reg                                             irq_correct_pending_r           ;
    reg                                             irq_error_pending_r             ;
    reg         [31                     :0]         meta_tile_count_r               ;
    reg         [31                     :0]         tile_addr_count_r               ;
    reg         [31                     :0]         otf_tile_count_r                ;
    reg         [31                     :0]         otf_line_count_r                ;
    reg         [31                     :0]         otf_de_count_r                  ;

    assign any_stage_busy              = i_meta_busy | i_tile_busy | i_vivo_busy | i_otf_busy;
    assign irq_pending_next            = irq_correct_pending_r | irq_error_pending_r |
                                         i_correct_irq_event | i_error_irq_event;
    assign meta_done_event             = meta_busy_d & !i_meta_busy;
    assign tile_done_event             = tile_busy_d & !i_tile_busy;
    assign frame_counter_clear         = i_irq_clear ||
                                         (i_frame_start && !irq_pending_next);
    assign stage_seen0_event           = i_meta_busy | i_meta_tile_fire;
    assign stage_seen1_event           = i_tile_busy | i_tile_addr_fire;
    assign stage_seen2_event           = i_vivo_busy;
    assign stage_seen3_event           = i_otf_busy | i_otf_tile_fire |
                                         i_correct_irq_event;
    assign o_frame_active              = frame_active_r;
    assign o_any_stage_busy            = any_stage_busy;
    assign o_stage_seen                = stage_seen_r;
    assign o_stage_done                = stage_done_r;
    assign o_frame_done                = stage_done_r[4];
    assign o_irq_correct_pending       = irq_correct_pending_r;
    assign o_irq_error_pending         = irq_error_pending_r;
    assign o_irq_pending               = irq_correct_pending_r | irq_error_pending_r;
    assign o_irq                       = (irq_correct_pending_r | irq_error_pending_r) & i_irq_enable;
    assign o_meta_tile_count           = meta_tile_count_r;
    assign o_tile_addr_count           = tile_addr_count_r;
    assign o_otf_tile_count            = otf_tile_count_r;
    assign o_otf_line_count            = otf_line_count_r;
    assign o_otf_de_count              = otf_de_count_r;

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            frame_active_r <= 1'b0;
        else if (i_irq_clear)
            frame_active_r <= 1'b0;
        else if (i_correct_irq_event)
            frame_active_r <= 1'b0;
        else if (i_frame_start)
            frame_active_r <= 1'b1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            meta_busy_d <= 1'b0;
        else
            meta_busy_d <= i_meta_busy;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            tile_busy_d <= 1'b0;
        else
            tile_busy_d <= i_tile_busy;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            stage_seen_r <= 4'd0;
        else if (frame_counter_clear)
            stage_seen_r <= {stage_seen3_event, stage_seen2_event,
                             stage_seen1_event, stage_seen0_event};
        else
            stage_seen_r <= stage_seen_r |
                            {stage_seen3_event, stage_seen2_event,
                             stage_seen1_event, stage_seen0_event};
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            stage_done_r <= 5'd0;
        else if (frame_counter_clear)
            stage_done_r <= {i_correct_irq_event, i_correct_irq_event,
                             1'b0, tile_done_event, meta_done_event};
        else
            stage_done_r <= stage_done_r |
                            {i_correct_irq_event, i_correct_irq_event,
                             1'b0, tile_done_event, meta_done_event};
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            irq_correct_pending_r <= 1'b0;
        else if (i_irq_clear)
            irq_correct_pending_r <= 1'b0;
        else if (i_correct_irq_event)
            irq_correct_pending_r <= 1'b1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            irq_error_pending_r <= 1'b0;
        else if (i_irq_clear)
            irq_error_pending_r <= 1'b0;
        else if (i_error_irq_event)
            irq_error_pending_r <= 1'b1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            meta_tile_count_r <= 32'd0;
        else if (frame_counter_clear)
            meta_tile_count_r <= 32'd0;
        else if (i_meta_tile_fire)
            meta_tile_count_r <= meta_tile_count_r + 1'b1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            tile_addr_count_r <= 32'd0;
        else if (frame_counter_clear)
            tile_addr_count_r <= 32'd0;
        else if (i_tile_addr_fire)
            tile_addr_count_r <= tile_addr_count_r + 1'b1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            otf_tile_count_r <= 32'd0;
        else if (frame_counter_clear)
            otf_tile_count_r <= 32'd0;
        else if (i_otf_tile_fire)
            otf_tile_count_r <= otf_tile_count_r + 1'b1;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            otf_line_count_r <= 32'd0;
        else if (i_irq_clear)
            otf_line_count_r <= 32'd0;
        else
            otf_line_count_r <= i_otf_line_count;
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn)
            otf_de_count_r <= 32'd0;
        else if (i_irq_clear)
            otf_de_count_r <= 32'd0;
        else
            otf_de_count_r <= i_otf_de_count;
    end

endmodule
