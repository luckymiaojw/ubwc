//////////////////////////////////////////////////////////////////////////////////
// Module Name       : ubwc_enc_otf_monitor   (V1 — fcnt 隔离层)
// Description       : V1 薄壳：仅做 OTF fcnt 连续性检测 + 帧切换信号生成
//   - OTF fcnt 不外传（被本模块完全吸收）
//   - 输出 err_fcnt (sticky) → 顶层独立 err 端口 o_err_fcnt
//   - 输出 frame_info bus (frame_change_pulse + fcnt_seen) → writer 用作 fcnt +1
//   - 横向 / 帧高度 / FIFO 溢出 等异常已被 ubwc_enc_otf_data_packer 覆盖，本模块不重复
// Reference         : docs/claude code/enc/ubwc_enc_line_to_tile_v1_design_cn.md §2
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
`default_nettype none

module ubwc_enc_otf_monitor
    import ubwc_enc_v1_pkg::*;
(
    input   wire                                        i_otf_clk                       ,
    input   wire                                        rst_n_otf                       ,
    input   wire                                        i_clk                           ,
    input   wire                                        rst_n_sys                       ,

    input   wire                                        i_otf_vsync                     ,
    input   wire    [3                      :0]         i_otf_fcnt                      ,

    output  wire                                        o_err_fcnt                      ,
    input   wire                                        i_err_clear                     ,

    output  otf_frame_info_t                            o_frame_info
);

    //--------------------------------------------------------------------------
    // otf_clk 域：vsync 边沿 + fcnt latch + 连续性检测 + toggle 跨域
    //--------------------------------------------------------------------------
    wire                                            vsync_rising_otf                ;
    wire        [3                      :0]         expected_fcnt_otf               ;
    wire                                            fcnt_mismatch_otf               ;

    reg                                             vsync_prev_otf                  ;
    reg         [3                      :0]         fcnt_seen_otf                   ;
    reg                                             fcnt_seen_vld_otf               ;
    reg                                             vsync_toggle_otf                ;
    reg                                             err_fcnt_toggle_otf             ;

    assign vsync_rising_otf              = i_otf_vsync && !vsync_prev_otf;
    assign expected_fcnt_otf             = fcnt_seen_otf + 4'd1;
    assign fcnt_mismatch_otf             = vsync_rising_otf && fcnt_seen_vld_otf &&
                                           (i_otf_fcnt != expected_fcnt_otf);

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            vsync_prev_otf <= 1'b0;
        else
            vsync_prev_otf <= i_otf_vsync;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            fcnt_seen_otf <= 4'd0;
        else if (vsync_rising_otf)
            fcnt_seen_otf <= i_otf_fcnt;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            fcnt_seen_vld_otf <= 1'b0;
        else if (vsync_rising_otf)
            fcnt_seen_vld_otf <= 1'b1;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            vsync_toggle_otf <= 1'b0;
        else if (vsync_rising_otf)
            vsync_toggle_otf <= ~vsync_toggle_otf;
    end

    always @(posedge i_otf_clk or negedge rst_n_otf) begin
        if (!rst_n_otf)
            err_fcnt_toggle_otf <= 1'b0;
        else if (fcnt_mismatch_otf)
            err_fcnt_toggle_otf <= ~err_fcnt_toggle_otf;
    end

    //--------------------------------------------------------------------------
    // sys clk 域：3-FF 同步 + edge detect + sticky err + frame_info latch
    //--------------------------------------------------------------------------
    wire                                            frame_change_pulse_sys          ;
    wire                                            err_fcnt_event_sys              ;

    (* async_reg = "true" *) reg                    vsync_toggle_ff1_sys            ;
    (* async_reg = "true" *) reg                    vsync_toggle_ff2_sys            ;
                             reg                    vsync_toggle_ff3_sys            ;
    (* async_reg = "true" *) reg                    err_fcnt_toggle_ff1_sys         ;
    (* async_reg = "true" *) reg                    err_fcnt_toggle_ff2_sys         ;
                             reg                    err_fcnt_toggle_ff3_sys         ;
    (* async_reg = "true" *) reg [3              :0] fcnt_seen_ff1_sys              ;
    (* async_reg = "true" *) reg [3              :0] fcnt_seen_ff2_sys              ;

    reg                                             err_fcnt_sticky_sys             ;
    reg                                             frame_change_pulse_r            ;
    reg         [3                      :0]         fcnt_seen_r                     ;

    assign frame_change_pulse_sys        = vsync_toggle_ff2_sys ^ vsync_toggle_ff3_sys;
    assign err_fcnt_event_sys            = err_fcnt_toggle_ff2_sys ^ err_fcnt_toggle_ff3_sys;

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            vsync_toggle_ff1_sys <= 1'b0;
        else
            vsync_toggle_ff1_sys <= vsync_toggle_otf;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            vsync_toggle_ff2_sys <= 1'b0;
        else
            vsync_toggle_ff2_sys <= vsync_toggle_ff1_sys;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            vsync_toggle_ff3_sys <= 1'b0;
        else
            vsync_toggle_ff3_sys <= vsync_toggle_ff2_sys;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_fcnt_toggle_ff1_sys <= 1'b0;
        else
            err_fcnt_toggle_ff1_sys <= err_fcnt_toggle_otf;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_fcnt_toggle_ff2_sys <= 1'b0;
        else
            err_fcnt_toggle_ff2_sys <= err_fcnt_toggle_ff1_sys;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_fcnt_toggle_ff3_sys <= 1'b0;
        else
            err_fcnt_toggle_ff3_sys <= err_fcnt_toggle_ff2_sys;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            fcnt_seen_ff1_sys <= 4'd0;
        else
            fcnt_seen_ff1_sys <= fcnt_seen_otf;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            fcnt_seen_ff2_sys <= 4'd0;
        else
            fcnt_seen_ff2_sys <= fcnt_seen_ff1_sys;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            err_fcnt_sticky_sys <= 1'b0;
        else if (i_err_clear)
            err_fcnt_sticky_sys <= 1'b0;
        else if (err_fcnt_event_sys)
            err_fcnt_sticky_sys <= 1'b1;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            frame_change_pulse_r <= 1'b0;
        else
            frame_change_pulse_r <= frame_change_pulse_sys;
    end

    always @(posedge i_clk or negedge rst_n_sys) begin
        if (!rst_n_sys)
            fcnt_seen_r <= 4'd0;
        else if (frame_change_pulse_sys)
            fcnt_seen_r <= fcnt_seen_ff2_sys;
    end

    assign o_err_fcnt                    = err_fcnt_sticky_sys;
    assign o_frame_info.frame_change_pulse = frame_change_pulse_r;
    assign o_frame_info.fcnt_seen        = fcnt_seen_r;

endmodule

`default_nettype wire
