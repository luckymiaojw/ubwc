`timescale 1ns/1ps

module ubwc_dec_vivo_top #(
    parameter                                       SB_WIDTH                        = 1
) (
    input   wire                                        i_clk                           ,
    input   wire                                        i_reset                         ,
    input   wire                                        i_sreset                        ,

    input   wire                                        i_ubwc_en                       ,

    input   wire                                        i_ci_valid                      ,
    output  wire                                        o_ci_ready                      ,
    input   wire                                        i_ci_input_type                 ,
    input   wire    [2                      :0]         i_ci_alen                       ,
    input   wire    [4                      :0]         i_ci_format                     ,
    input   wire    [3                      :0]         i_ci_metadata                   ,
    input   wire                                        i_ci_lossy                      ,
    input   wire    [1                      :0]         i_ci_alpha_mode                 ,
    input   wire    [SB_WIDTH            -1 :0]         i_ci_sb                         ,

    input   wire                                        i_cvi_valid                     ,
    input   wire    [255                    :0]         i_cvi_data                      ,
    input   wire                                        i_cvi_last                      ,
    output  wire                                        o_cvi_ready                     ,

    output  wire                                        o_co_valid                      ,
    output  wire    [2                      :0]         o_co_alen                       ,
    output  wire    [SB_WIDTH            -1 :0]         o_co_sb                         ,
    input   wire                                        i_co_ready                      ,

    output  wire                                        o_rvo_valid                     ,
    output  wire    [255                    :0]         o_rvo_data                      ,
    output  wire                                        o_rvo_last                      ,
    input   wire                                        i_rvo_ready                     ,

    output  wire    [6                      :0]         o_idle                          ,
    output  wire    [6                      :0]         o_error
);

    localparam  [4                      :0]         CI_READY_PERIOD_M1              = 5'd23;
    localparam  [3                      :0]         TILE_OUT_BEATS                  = 4'd8; // 256B / 32B-per-beat

    wire                                            ci_period_hit                   ;
    wire                                            ci_fire                         ;
    wire                                            out_fire                        ;
    wire                                            need_input_beat                 ;
    wire                                            pad_active                      ;

    reg                                             r_reset_sync                    ;
    reg         [4                      :0]         r_ci_period_cnt                 ;
    reg                                             r_tile_active                   ;
    reg         [3                      :0]         r_out_beats_left                ;
    reg         [3                      :0]         r_in_beats_left                 ;
    reg         [2                      :0]         r_ci_alen                       ;
    reg         [SB_WIDTH            -1 :0]         r_ci_sb                         ;

    assign ci_period_hit = (r_ci_period_cnt == CI_READY_PERIOD_M1);
    assign o_ci_ready  = i_ubwc_en && !r_reset_sync && !r_tile_active && ci_period_hit;
    assign o_cvi_ready = i_ubwc_en && !r_reset_sync &&
                         (r_tile_active ? ((r_in_beats_left != 4'd0) ? i_rvo_ready : 1'b1) : 1'b1);
    assign ci_fire  = i_ci_valid  && o_ci_ready;
    assign out_fire = o_rvo_valid && i_rvo_ready;
    assign o_co_valid = r_tile_active;
    assign o_co_alen  = r_ci_alen;
    assign o_co_sb    = r_ci_sb;
    assign need_input_beat = r_tile_active && (r_in_beats_left != 4'd0);
    assign pad_active = r_tile_active && (r_in_beats_left == 4'd0) && (r_out_beats_left != 4'd0);
    assign o_rvo_valid = i_ubwc_en && !r_reset_sync && r_tile_active &&
                         (need_input_beat ? i_cvi_valid : pad_active);
    assign o_rvo_data  = need_input_beat ? i_cvi_data : 256'd0;
    assign o_rvo_last  = r_tile_active && (r_out_beats_left == 4'd1);
    assign o_idle[0] = !r_tile_active && !i_ci_valid && !i_cvi_valid;
    assign o_idle[1] = !r_tile_active;
    assign o_idle[2] = !i_ci_valid || o_ci_ready;
    assign o_idle[3] = !i_cvi_valid || o_cvi_ready;
    assign o_idle[4] = !o_co_valid || i_co_ready;
    assign o_idle[5] = !o_rvo_valid || i_rvo_ready;
    assign o_idle[6] = !r_reset_sync;
    assign o_error = 7'd0;

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            r_reset_sync <= 1'b1;
        end else begin
            r_reset_sync <= i_sreset;
        end
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            r_ci_period_cnt <= 5'd0;
        end else if (r_reset_sync || !i_ubwc_en) begin
            r_ci_period_cnt <= 5'd0;
        end else if (ci_period_hit) begin
            r_ci_period_cnt <= 5'd0;
        end else begin
            r_ci_period_cnt <= r_ci_period_cnt + 5'd1;
        end
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_tile_active <= 1'b0;
        else if (r_reset_sync || !i_ubwc_en)
            r_tile_active <= 1'b0;
        else if (ci_fire)
            r_tile_active <= 1'b1;
        else if (out_fire && r_tile_active && (r_out_beats_left <= 4'd1))
            r_tile_active <= 1'b0;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_out_beats_left <= 4'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_out_beats_left <= 4'd0;
        else if (ci_fire)
            r_out_beats_left <= TILE_OUT_BEATS;
        else if (out_fire && r_tile_active && (r_out_beats_left <= 4'd1))
            r_out_beats_left <= 4'd0;
        else if (out_fire && r_tile_active)
            r_out_beats_left <= r_out_beats_left - 4'd1;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_in_beats_left <= 4'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_in_beats_left <= 4'd0;
        else if (ci_fire)
            r_in_beats_left <= i_ci_metadata[3] ? 4'd0 :
                               ({1'b0, i_ci_alen} + 4'd1);
        else if (out_fire && r_tile_active && (r_out_beats_left <= 4'd1))
            r_in_beats_left <= 4'd0;
        else if (out_fire && r_tile_active && (r_in_beats_left != 4'd0))
            r_in_beats_left <= r_in_beats_left - 4'd1;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_ci_alen <= 3'd0;
        else if (r_reset_sync || !i_ubwc_en)
            r_ci_alen <= 3'd0;
        else if (ci_fire)
            r_ci_alen <= i_ci_alen;
    end

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset)
            r_ci_sb <= {SB_WIDTH{1'b0}};
        else if (r_reset_sync || !i_ubwc_en)
            r_ci_sb <= {SB_WIDTH{1'b0}};
        else if (ci_fire)
            r_ci_sb <= i_ci_sb;
    end

    // Fake vivo mode: accept one tile command every 24 clocks. The payload
    // data path is a "tile packer":
    // - forwards incoming CVI beats when present
    // - otherwise pads with zeros up to a fixed 8-beat tile payload

endmodule
