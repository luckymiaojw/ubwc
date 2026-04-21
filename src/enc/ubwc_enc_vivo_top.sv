module ubwc_enc_vivo_top #(
    parameter SB_WIDTH = 1
) (
    input  wire                  i_clk,
    input  wire                  i_reset,
    input  wire                  i_sreset,

    input  wire                  i_ubwc_en,

    input  wire                  i_ci_valid,
    output wire                  o_ci_ready,
    input  wire                  i_ci_input_type,
    input  wire [2:0]            i_ci_alen,
    input  wire [4:0]            i_ci_format,
    input  wire                  i_ci_forced_pcm,

    input  wire                  i_ci_lossy,
    input  wire [SB_WIDTH-1:0]   i_ci_sb,
    input  wire [2:0]            i_ci_ubwc_cfg_0,
    input  wire [2:0]            i_ci_ubwc_cfg_1,
    input  wire [3:0]            i_ci_ubwc_cfg_2,
    input  wire [3:0]            i_ci_ubwc_cfg_3,
    input  wire [3:0]            i_ci_ubwc_cfg_4,
    input  wire [3:0]            i_ci_ubwc_cfg_5,
    input  wire [1:0]            i_ci_ubwc_cfg_6,
    input  wire [1:0]            i_ci_ubwc_cfg_7,
    input  wire [1:0]            i_ci_ubwc_cfg_8,
    input  wire [2:0]            i_ci_ubwc_cfg_9,
    input  wire [5:0]            i_ci_ubwc_cfg_10,
    input  wire [5:0]            i_ci_ubwc_cfg_11,

    input  wire                  i_rvi_valid,
    output wire                  o_rvi_ready,
    input  wire [255:0]          i_rvi_data,
    input  wire [31:0]           i_rvi_mask,

    output reg                   o_co_valid,
    input  wire                  i_co_ready,
    output wire [2:0]            o_co_alen,
    output wire [SB_WIDTH-1:0]   o_co_sb,
    output wire                  o_co_pcm,

    output wire                  o_cvo_valid,
    input  wire                  i_cvo_ready,
    output wire [255:0]          o_cvo_data,
    output wire [31:0]           o_cvo_mask,
    output wire                  o_cvo_last,

    output wire                  o_idle,
    output wire                  o_error
);

    localparam integer CI_READY_PERIOD = 24;
    localparam integer CI_CNT_W        = (CI_READY_PERIOD <= 1) ? 1 : $clog2(CI_READY_PERIOD);

    reg  [CI_CNT_W-1:0] ci_ready_cnt_r;

    wire ci_period_hit;

    assign ci_period_hit = (ci_ready_cnt_r == CI_READY_PERIOD-1);

    always @(posedge i_clk or posedge i_reset) begin
        if(i_reset)
            o_co_valid  <= 1'b0 ;
        else
            o_co_valid  <= i_ubwc_en && i_ci_valid && o_ci_ready  ;
    end

    assign o_co_alen   = i_ci_alen;
    assign o_co_sb     = i_ci_sb;
    assign o_co_pcm    = i_ci_forced_pcm;

    assign o_cvo_valid = i_ubwc_en && i_rvi_valid;
    assign o_cvo_data  = i_rvi_data;
    assign o_cvo_mask  = i_rvi_mask;
    assign o_cvo_last  = 1'b0;

    assign o_ci_ready   = i_ubwc_en && ci_period_hit;
    assign o_rvi_ready  = i_ubwc_en && i_cvo_ready;

    assign o_idle      = ~i_ubwc_en;
    assign o_error     = 1'b0;

    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            ci_ready_cnt_r <= {CI_CNT_W{1'b0}};
        end else if (i_sreset) begin
            ci_ready_cnt_r <= {CI_CNT_W{1'b0}};
        end else if (!i_ubwc_en) begin
            ci_ready_cnt_r <= {CI_CNT_W{1'b0}};
        end else begin
            if (ci_period_hit)
                ci_ready_cnt_r <= {CI_CNT_W{1'b0}};
            else
                ci_ready_cnt_r <= ci_ready_cnt_r + {{(CI_CNT_W-1){1'b0}}, 1'b1};
        end
    end

endmodule
