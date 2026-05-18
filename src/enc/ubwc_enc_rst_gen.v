//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-05-17
// Module Name       : ubwc_enc_rst_gen.v
// Description       : ENC internal reset sequencer.
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module ubwc_enc_rst_gen
    (
        input   wire                                        i_axi_clk                       ,
        input   wire                                        i_otf_clk                       ,
        input   wire                                        i_vivo_clk                      ,
        input   wire                                        i_axi_rstn                      ,
        input   wire                                        i_otf_rstn                      ,
        input   wire                                        i_vivo_rstn                     ,
        input   wire                                        i_enc_ubwc_en                   ,
        input   wire                                        i_start_pulse                   ,
        input   wire                                        i_axi_idle                      ,
        input   wire                                        i_error_clear                   ,

        output  wire                                        o_axi_rstn                      ,
        output  wire                                        o_otf_rstn                      ,
        output  wire                                        o_vivo_rstn                     ,
        output  wire                                        o_axi_drain_req                 ,
        output  wire                                        o_axi_drain_timeout             ,
        output  wire                                        o_start_pulse
    );

    localparam  [2                      :0]         RESET_HOLD_CYCLES              = 3'd3;
    localparam  [1                      :0]         AXI_RST_RUN                    = 2'd0;
    localparam  [1                      :0]         AXI_RST_DRAIN                  = 2'd1;
    localparam  [1                      :0]         AXI_RST_HOLD                   = 2'd2;
    localparam  [15                     :0]         DRAIN_TIMEOUT_CYCLES           = 16'hffff;
    localparam  [2                      :0]         START_RELEASE_CYCLES           = 3'd7;

    wire                                            start_toggle_sync_otf_pulse     ;
    wire                                            start_toggle_sync_vivo_pulse    ;
    wire                                            enc_ubwc_en_otf                 ;
    wire                                            enc_ubwc_en_vivo                ;
    wire                                            soft_reset_req                  ;
    wire                                            axi_drain_timeout_hit           ;
    wire                                            axi_drain_done                  ;
    wire                                            axi_enter_hold                  ;
    wire                                            axi_reset_done                  ;
    wire                                            all_reset_done                  ;
    wire                                            start_release_done              ;
    wire                                            start_fire_ready                ;

    reg         [2                      :0]         axi_rst_cnt                     ;
    reg         [2                      :0]         otf_rst_cnt                     ;
    reg         [2                      :0]         vivo_rst_cnt                    ;
    reg         [1                      :0]         axi_rst_state                   ;
    reg         [15                     :0]         axi_drain_cnt                   ;
    reg                                             axi_rstn_r                      ;
    reg                                             otf_rstn_r                      ;
    reg                                             vivo_rstn_r                     ;
    reg                                             axi_drain_timeout_r             ;
    reg                                             start_pending_r                 ;
    reg         [2                      :0]         start_release_cnt               ;
    reg                                             start_pulse_r                   ;
    reg                                             start_toggle_axi_r              ;
    reg                                             start_toggle_otf_meta_r         ;
    reg                                             start_toggle_otf_sync_r         ;
    reg                                             start_toggle_otf_sync_d_r       ;
    reg                                             start_toggle_vivo_meta_r        ;
    reg                                             start_toggle_vivo_sync_r        ;
    reg                                             start_toggle_vivo_sync_d_r      ;
    reg                                             enc_ubwc_en_otf_meta_r          ;
    reg                                             enc_ubwc_en_otf_sync_r          ;
    reg                                             enc_ubwc_en_vivo_meta_r         ;
    reg                                             enc_ubwc_en_vivo_sync_r         ;
    reg                                             otf_rstn_axi_meta_r             ;
    reg                                             otf_rstn_axi_sync_r             ;
    reg                                             vivo_rstn_axi_meta_r            ;
    reg                                             vivo_rstn_axi_sync_r            ;

    assign start_toggle_sync_otf_pulse  = start_toggle_otf_sync_r ^ start_toggle_otf_sync_d_r;
    assign start_toggle_sync_vivo_pulse = start_toggle_vivo_sync_r ^ start_toggle_vivo_sync_d_r;
    assign enc_ubwc_en_otf              = enc_ubwc_en_otf_sync_r;
    assign enc_ubwc_en_vivo             = enc_ubwc_en_vivo_sync_r;
    assign soft_reset_req               = !i_enc_ubwc_en || i_start_pulse;
    assign axi_drain_timeout_hit        = (axi_drain_cnt == DRAIN_TIMEOUT_CYCLES);
    assign axi_drain_done               = i_axi_idle || axi_drain_timeout_hit;
    assign axi_enter_hold               = (axi_rst_state == AXI_RST_DRAIN) && axi_drain_done;
    assign axi_reset_done               = (axi_rst_state == AXI_RST_RUN) && axi_rstn_r;
    assign all_reset_done               = axi_reset_done &&
                                          otf_rstn_axi_sync_r &&
                                          vivo_rstn_axi_sync_r;
    assign start_release_done           = (start_release_cnt == 3'd0);
    assign start_fire_ready             = start_pending_r && all_reset_done && start_release_done;
    assign o_axi_rstn                   = axi_rstn_r;
    assign o_otf_rstn                   = otf_rstn_r;
    assign o_vivo_rstn                  = vivo_rstn_r;
    assign o_axi_drain_req              = (axi_rst_state == AXI_RST_DRAIN);
    assign o_axi_drain_timeout          = axi_drain_timeout_r;
    assign o_start_pulse                = start_pulse_r;

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            axi_rst_state <= AXI_RST_HOLD;
        else begin
            case (axi_rst_state)
                AXI_RST_RUN: begin
                    if (soft_reset_req)
                        axi_rst_state <= AXI_RST_DRAIN;
                end
                AXI_RST_DRAIN: begin
                    if (axi_drain_done)
                        axi_rst_state <= AXI_RST_HOLD;
                end
                AXI_RST_HOLD: begin
                    if (i_enc_ubwc_en && (axi_rst_cnt == 3'd0))
                        axi_rst_state <= AXI_RST_RUN;
                end
                default: begin
                    axi_rst_state <= AXI_RST_HOLD;
                end
            endcase
        end
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            axi_rst_cnt <= RESET_HOLD_CYCLES;
        else if (axi_enter_hold)
            axi_rst_cnt <= RESET_HOLD_CYCLES;
        else if ((axi_rst_state == AXI_RST_HOLD) && !i_enc_ubwc_en)
            axi_rst_cnt <= RESET_HOLD_CYCLES;
        else if ((axi_rst_state == AXI_RST_HOLD) && (axi_rst_cnt != 3'd0))
            axi_rst_cnt <= axi_rst_cnt - 3'd1;
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            axi_drain_cnt <= 16'd0;
        else if (axi_rst_state != AXI_RST_DRAIN)
            axi_drain_cnt <= 16'd0;
        else if (!axi_drain_done)
            axi_drain_cnt <= axi_drain_cnt + 16'd1;
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            axi_rstn_r <= 1'b0;
        else
            axi_rstn_r <= (axi_rst_state == AXI_RST_RUN) ||
                          (axi_rst_state == AXI_RST_DRAIN);
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            axi_drain_timeout_r <= 1'b0;
        else if (i_error_clear)
            axi_drain_timeout_r <= 1'b0;
        else if ((axi_rst_state == AXI_RST_DRAIN) && axi_drain_timeout_hit)
            axi_drain_timeout_r <= 1'b1;
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            start_pending_r <= 1'b0;
        else if (!i_enc_ubwc_en)
            start_pending_r <= 1'b0;
        else if (i_start_pulse)
            start_pending_r <= 1'b1;
        else if (start_fire_ready)
            start_pending_r <= 1'b0;
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            start_release_cnt <= START_RELEASE_CYCLES;
        else if (!i_enc_ubwc_en)
            start_release_cnt <= START_RELEASE_CYCLES;
        else if (!start_pending_r)
            start_release_cnt <= START_RELEASE_CYCLES;
        else if (!all_reset_done)
            start_release_cnt <= START_RELEASE_CYCLES;
        else if (start_release_cnt != 3'd0)
            start_release_cnt <= start_release_cnt - 3'd1;
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            start_toggle_axi_r <= 1'b0;
        else if (axi_enter_hold && start_pending_r)
            start_toggle_axi_r <= ~start_toggle_axi_r;
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            start_pulse_r <= 1'b0;
        else
            start_pulse_r <= start_fire_ready;
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            otf_rstn_axi_meta_r <= 1'b0;
        else
            otf_rstn_axi_meta_r <= otf_rstn_r;
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            otf_rstn_axi_sync_r <= 1'b0;
        else
            otf_rstn_axi_sync_r <= otf_rstn_axi_meta_r;
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            vivo_rstn_axi_meta_r <= 1'b0;
        else
            vivo_rstn_axi_meta_r <= vivo_rstn_r;
    end

    always @(posedge i_axi_clk or negedge i_axi_rstn) begin
        if (!i_axi_rstn)
            vivo_rstn_axi_sync_r <= 1'b0;
        else
            vivo_rstn_axi_sync_r <= vivo_rstn_axi_meta_r;
    end

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        if (!i_otf_rstn)
            start_toggle_otf_meta_r <= 1'b0;
        else
            start_toggle_otf_meta_r <= start_toggle_axi_r;
    end

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        if (!i_otf_rstn)
            start_toggle_otf_sync_r <= 1'b0;
        else
            start_toggle_otf_sync_r <= start_toggle_otf_meta_r;
    end

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        if (!i_otf_rstn)
            start_toggle_otf_sync_d_r <= 1'b0;
        else
            start_toggle_otf_sync_d_r <= start_toggle_otf_sync_r;
    end

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        if (!i_otf_rstn)
            enc_ubwc_en_otf_meta_r <= 1'b0;
        else
            enc_ubwc_en_otf_meta_r <= axi_rstn_r;
    end

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        if (!i_otf_rstn)
            enc_ubwc_en_otf_sync_r <= 1'b0;
        else
            enc_ubwc_en_otf_sync_r <= enc_ubwc_en_otf_meta_r;
    end

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        if (!i_otf_rstn)
            otf_rst_cnt <= RESET_HOLD_CYCLES;
        else if (!enc_ubwc_en_otf)
            otf_rst_cnt <= RESET_HOLD_CYCLES;
        else if (start_toggle_sync_otf_pulse)
            otf_rst_cnt <= RESET_HOLD_CYCLES;
        else if (otf_rst_cnt != 3'd0)
            otf_rst_cnt <= otf_rst_cnt - 3'd1;
    end

    always @(posedge i_otf_clk or negedge i_otf_rstn) begin
        if (!i_otf_rstn)
            otf_rstn_r <= 1'b0;
        else
            otf_rstn_r <= enc_ubwc_en_otf && (otf_rst_cnt == 3'd0);
    end

    always @(posedge i_vivo_clk or negedge i_vivo_rstn) begin
        if (!i_vivo_rstn)
            start_toggle_vivo_meta_r <= 1'b0;
        else
            start_toggle_vivo_meta_r <= start_toggle_axi_r;
    end

    always @(posedge i_vivo_clk or negedge i_vivo_rstn) begin
        if (!i_vivo_rstn)
            start_toggle_vivo_sync_r <= 1'b0;
        else
            start_toggle_vivo_sync_r <= start_toggle_vivo_meta_r;
    end

    always @(posedge i_vivo_clk or negedge i_vivo_rstn) begin
        if (!i_vivo_rstn)
            start_toggle_vivo_sync_d_r <= 1'b0;
        else
            start_toggle_vivo_sync_d_r <= start_toggle_vivo_sync_r;
    end

    always @(posedge i_vivo_clk or negedge i_vivo_rstn) begin
        if (!i_vivo_rstn)
            enc_ubwc_en_vivo_meta_r <= 1'b0;
        else
            enc_ubwc_en_vivo_meta_r <= axi_rstn_r;
    end

    always @(posedge i_vivo_clk or negedge i_vivo_rstn) begin
        if (!i_vivo_rstn)
            enc_ubwc_en_vivo_sync_r <= 1'b0;
        else
            enc_ubwc_en_vivo_sync_r <= enc_ubwc_en_vivo_meta_r;
    end

    always @(posedge i_vivo_clk or negedge i_vivo_rstn) begin
        if (!i_vivo_rstn)
            vivo_rst_cnt <= RESET_HOLD_CYCLES;
        else if (!enc_ubwc_en_vivo)
            vivo_rst_cnt <= RESET_HOLD_CYCLES;
        else if (start_toggle_sync_vivo_pulse)
            vivo_rst_cnt <= RESET_HOLD_CYCLES;
        else if (vivo_rst_cnt != 3'd0)
            vivo_rst_cnt <= vivo_rst_cnt - 3'd1;
    end

    always @(posedge i_vivo_clk or negedge i_vivo_rstn) begin
        if (!i_vivo_rstn)
            vivo_rstn_r <= 1'b0;
        else
            vivo_rstn_r <= enc_ubwc_en_vivo && (vivo_rst_cnt == 3'd0);
    end

endmodule
