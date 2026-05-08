`timescale 1ns/1ps

module ubwc_dec_meta_pingpong_sram #(
    parameter integer WR_DATA_W = 256,
    parameter integer RD_DATA_W = 64,
    parameter integer ADDR_W    = 12,
    parameter integer NUM_LANES = 4,
    parameter integer DEPTH     = (1 << ADDR_W),
    parameter [RD_DATA_W-1:0] MISS_DATA = 64'hDEAD_DEAD_DEAD_DEAD
)(
    input  wire                      clk,
    input  wire                      rst_n,

    input  wire [NUM_LANES-1:0]      wr_we_a,
    input  wire [NUM_LANES-1:0]      wr_we_b,
    input  wire [ADDR_W-1:0]         wr_addr,
    input  wire [WR_DATA_W-1:0]      wr_wdata,

    input  wire [NUM_LANES-1:0]      rd_re_a,
    input  wire [NUM_LANES-1:0]      rd_re_b,
    input  wire [ADDR_W-1:0]         rd_addr,
    output wire [RD_DATA_W-1:0]      rd_rdata,
    output reg                       rd_rvalid,

    output reg                       rd_rsp_bank_b,
    output reg  [$clog2(NUM_LANES)-1:0] rd_rsp_lane,
    output reg  [ADDR_W-1:0]         rd_rsp_addr,
    output reg                       rd_rsp_hit,

    output reg  [31:0]               wr_cnt,
    output reg  [31:0]               rd_req_cnt,
    output reg  [31:0]               rd_rsp_cnt,
    output reg  [31:0]               rd_miss_cnt
);

    localparam integer LANE_W = $clog2(NUM_LANES);

    wire [NUM_LANES-1:0] op_cs_a;
    wire [NUM_LANES-1:0] op_cs_b;
    wire [NUM_LANES-1:0] op_we_a;
    wire [NUM_LANES-1:0] op_we_b;
    wire [NUM_LANES-1:0] ram_rd_a;
    wire [NUM_LANES-1:0] ram_rd_b;
    wire [ADDR_W-1:0]    op_addr_a [0:NUM_LANES-1];
    wire [ADDR_W-1:0]    op_addr_b [0:NUM_LANES-1];
    wire [RD_DATA_W-1:0] op_din_a  [0:NUM_LANES-1];
    wire [RD_DATA_W-1:0] op_din_b  [0:NUM_LANES-1];
    wire [RD_DATA_W-1:0] bank_a_dout [0:NUM_LANES-1];
    wire [RD_DATA_W-1:0] bank_b_dout [0:NUM_LANES-1];

`ifndef SYNTHESIS
    reg bank_a_vld [0:NUM_LANES-1][0:DEPTH-1];
    reg bank_b_vld [0:NUM_LANES-1][0:DEPTH-1];
`endif

    reg                rd_pending_valid;
    reg                rd_pending_bank_b;
    reg [LANE_W-1:0]   rd_pending_lane;
    reg [ADDR_W-1:0]   rd_pending_addr;
    reg                rd_issue_valid;
    reg                rd_issue_bank_b;
    reg [LANE_W-1:0]   rd_issue_lane;
    reg [ADDR_W-1:0]   rd_issue_addr;
    reg                rd_issue_hit;

`ifndef SYNTHESIS
    integer bank_a_i;
    integer bank_a_j;
    integer bank_b_i;
    integer bank_b_j;
`endif

    function automatic [LANE_W-1:0] onehot_to_idx;
        input [NUM_LANES-1:0] onehot;
        integer idx;
        begin
            onehot_to_idx = {LANE_W{1'b0}};
            for (idx = 0; idx < NUM_LANES; idx = idx + 1) begin
                if (onehot[idx]) begin
                    onehot_to_idx = idx[LANE_W-1:0];
                end
            end
        end
    endfunction

    function automatic [31:0] count_ones;
        input [NUM_LANES-1:0] bits;
        integer idx;
        begin
            count_ones = 32'd0;
            for (idx = 0; idx < NUM_LANES; idx = idx + 1) begin
                if (bits[idx])
                    count_ones = count_ones + 32'd1;
            end
        end
    endfunction

    wire                  rd_req_any;
    assign rd_req_any = |rd_re_a || |rd_re_b;
    wire                  rd_req_bank_b;
    assign rd_req_bank_b = |rd_re_b;
    wire [LANE_W-1:0]     rd_req_lane;
    assign rd_req_lane = onehot_to_idx(rd_req_bank_b ? rd_re_b : rd_re_a);
    wire                  cand_valid;
    assign cand_valid = rd_pending_valid || rd_req_any;
    wire                  cand_bank_b;
    assign cand_bank_b = rd_pending_valid ? rd_pending_bank_b : rd_req_bank_b;
    wire [LANE_W-1:0]     cand_lane;
    assign cand_lane = rd_pending_valid ? rd_pending_lane   : rd_req_lane;
    wire [ADDR_W-1:0]     cand_addr;
    assign cand_addr = rd_pending_valid ? rd_pending_addr   : rd_addr;
    wire                  cand_conflict;
    assign cand_conflict = cand_bank_b ? wr_we_b[cand_lane] : wr_we_a[cand_lane];
    wire                  issue_now;
    assign issue_now = cand_valid && !cand_conflict;
    wire                  store_new_req;
    assign store_new_req = !rd_pending_valid && rd_req_any && !issue_now;
    wire [31:0]           wr_inc;
    assign wr_inc = count_ones(wr_we_a) + count_ones(wr_we_b);

    assign rd_rdata = rd_rsp_hit ? (rd_rsp_bank_b ? bank_b_dout[rd_rsp_lane] : bank_a_dout[rd_rsp_lane]) :
                                  MISS_DATA;

    generate
        genvar g_lane;
        for (g_lane = 0; g_lane < NUM_LANES; g_lane = g_lane + 1) begin : gen_lane
            assign ram_rd_a[g_lane]  = issue_now && !cand_bank_b && (cand_lane == g_lane[LANE_W-1:0]);
            assign ram_rd_b[g_lane]  = issue_now &&  cand_bank_b && (cand_lane == g_lane[LANE_W-1:0]);
            assign op_cs_a[g_lane]   = wr_we_a[g_lane] || ram_rd_a[g_lane];
            assign op_cs_b[g_lane]   = wr_we_b[g_lane] || ram_rd_b[g_lane];
            assign op_we_a[g_lane]   = wr_we_a[g_lane];
            assign op_we_b[g_lane]   = wr_we_b[g_lane];
            assign op_addr_a[g_lane] = wr_we_a[g_lane] ? wr_addr : cand_addr;
            assign op_addr_b[g_lane] = wr_we_b[g_lane] ? wr_addr : cand_addr;
            assign op_din_a[g_lane]  = wr_wdata[g_lane*RD_DATA_W +: RD_DATA_W];
            assign op_din_b[g_lane]  = wr_wdata[g_lane*RD_DATA_W +: RD_DATA_W];

            ubwc_std_single_port_sram #(
                .DATA_W (RD_DATA_W),
                .ADDR_W (ADDR_W),
                .DEPTH  (DEPTH)
            ) u_bank_a_sram (
                .clk  (clk),
                .cs   (op_cs_a[g_lane]),
                .we   (op_we_a[g_lane]),
                .addr (op_addr_a[g_lane]),
                .din  (op_din_a[g_lane]),
                .dout (bank_a_dout[g_lane])
            );

            ubwc_std_single_port_sram #(
                .DATA_W (RD_DATA_W),
                .ADDR_W (ADDR_W),
                .DEPTH  (DEPTH)
            ) u_bank_b_sram (
                .clk  (clk),
                .cs   (op_cs_b[g_lane]),
                .we   (op_we_b[g_lane]),
                .addr (op_addr_b[g_lane]),
                .din  (op_din_b[g_lane]),
                .dout (bank_b_dout[g_lane])
            );
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_rvalid <= 1'b0;
        else
            rd_rvalid <= rd_issue_valid;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_rsp_bank_b <= 1'b0;
        else
            rd_rsp_bank_b <= rd_issue_bank_b;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_rsp_lane <= {LANE_W{1'b0}};
        else
            rd_rsp_lane <= rd_issue_lane;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_rsp_addr <= {ADDR_W{1'b0}};
        else
            rd_rsp_addr <= rd_issue_addr;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_rsp_hit <= 1'b0;
        else
            rd_rsp_hit <= rd_issue_hit;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_cnt <= 32'd0;
        else if (wr_inc != 32'd0)
            wr_cnt <= wr_cnt + wr_inc;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_req_cnt <= 32'd0;
        else if (rd_req_any)
            rd_req_cnt <= rd_req_cnt + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_rsp_cnt <= 32'd0;
        else if (rd_issue_valid)
            rd_rsp_cnt <= rd_rsp_cnt + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_miss_cnt <= 32'd0;
        else if (rd_issue_valid && !rd_issue_hit)
            rd_miss_cnt <= rd_miss_cnt + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_pending_valid <= 1'b0;
        else if (store_new_req)
            rd_pending_valid <= 1'b1;
        else if (issue_now)
            rd_pending_valid <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_pending_bank_b <= 1'b0;
        else if (store_new_req)
            rd_pending_bank_b <= rd_req_bank_b;
        else if (issue_now)
            rd_pending_bank_b <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_pending_lane <= {LANE_W{1'b0}};
        else if (store_new_req)
            rd_pending_lane <= rd_req_lane;
        else if (issue_now)
            rd_pending_lane <= {LANE_W{1'b0}};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_pending_addr <= {ADDR_W{1'b0}};
        else if (store_new_req)
            rd_pending_addr <= rd_addr;
        else if (issue_now)
            rd_pending_addr <= {ADDR_W{1'b0}};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_issue_valid <= 1'b0;
        else
            rd_issue_valid <= issue_now;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_issue_bank_b <= 1'b0;
        else
            rd_issue_bank_b <= cand_bank_b;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_issue_lane <= {LANE_W{1'b0}};
        else
            rd_issue_lane <= cand_lane;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_issue_addr <= {ADDR_W{1'b0}};
        else
            rd_issue_addr <= cand_addr;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_issue_hit <= 1'b0;
        else begin
`ifndef SYNTHESIS
            if (issue_now) begin
                rd_issue_hit <= cand_bank_b ? bank_b_vld[cand_lane][cand_addr] :
                                             bank_a_vld[cand_lane][cand_addr];
            end else begin
                rd_issue_hit <= 1'b0;
            end
`else
            rd_issue_hit <= issue_now;
`endif
        end
    end

`ifndef SYNTHESIS
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (bank_a_i = 0; bank_a_i < NUM_LANES; bank_a_i = bank_a_i + 1) begin
                for (bank_a_j = 0; bank_a_j < DEPTH; bank_a_j = bank_a_j + 1)
                    bank_a_vld[bank_a_i][bank_a_j] <= 1'b0;
            end
        end else begin
            for (bank_a_i = 0; bank_a_i < NUM_LANES; bank_a_i = bank_a_i + 1) begin
                if (wr_we_a[bank_a_i])
                    bank_a_vld[bank_a_i][wr_addr] <= 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (bank_b_i = 0; bank_b_i < NUM_LANES; bank_b_i = bank_b_i + 1) begin
                for (bank_b_j = 0; bank_b_j < DEPTH; bank_b_j = bank_b_j + 1)
                    bank_b_vld[bank_b_i][bank_b_j] <= 1'b0;
            end
        end else begin
            for (bank_b_i = 0; bank_b_i < NUM_LANES; bank_b_i = bank_b_i + 1) begin
                if (wr_we_b[bank_b_i])
                    bank_b_vld[bank_b_i][wr_addr] <= 1'b1;
            end
        end
    end
`endif

endmodule
