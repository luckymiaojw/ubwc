`timescale 1ns/1ps

module tb_axi_read_slave_model #(
    parameter ADDR_WIDTH       = 32,
    parameter ID_WIDTH         = 4,
    parameter AXI_DATA_WIDTH   = 256,
    parameter STRICT_AXI_BURST = 1'b0,
    parameter PRAGMATIC_BEATS  = 2
)(
    input  wire                      clk,
    input  wire                      rst_n,

    input  wire                      s_axi_arvalid,
    output wire                      s_axi_arready,
    input  wire [ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [7:0]                s_axi_arlen,
    input  wire [2:0]                s_axi_arsize,
    input  wire [1:0]                s_axi_arburst,
    input  wire [ID_WIDTH-1:0]       s_axi_arid,

    output reg                       s_axi_rvalid,
    input  wire                      s_axi_rready,
    output reg  [AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [ID_WIDTH-1:0]       s_axi_rid,
    output reg  [1:0]                s_axi_rresp,
    output reg                       s_axi_rlast,

    output reg  [31:0]               ar_cnt,
    output reg  [31:0]               arlen_warn_cnt,
    output reg  [31:0]               rlast_cnt
);

    localparam integer BYTES_PER_BEAT  = AXI_DATA_WIDTH / 8;
    localparam integer ARSIZE_EXPECTED = $clog2(BYTES_PER_BEAT);

    reg                    rsp_active;
    reg [ADDR_WIDTH-1:0]   rsp_addr;
    reg [ID_WIDTH-1:0]     rsp_id;
    integer                wait_cycles;
    integer                beats_left;
    integer                beat_idx;

    assign s_axi_arready = !rsp_active;

    function automatic [AXI_DATA_WIDTH-1:0] gen_axi_word;
        input [ADDR_WIDTH-1:0] addr;
        input integer          beat_idx_in;
        reg   [63:0]           lane_word;
        integer                lane_idx;
        begin
            gen_axi_word = {AXI_DATA_WIDTH{1'b0}};
            for (lane_idx = 0; lane_idx < (AXI_DATA_WIDTH / 64); lane_idx = lane_idx + 1) begin
                lane_word = {
                    16'hCAFE,
                    addr[15:0],
                    beat_idx_in[7:0],
                    lane_idx[7:0],
                    8'h10,
                    lane_idx[7:0]
                };
                gen_axi_word[lane_idx*64 +: 64] = lane_word;
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_rvalid    <= 1'b0;
            s_axi_rdata     <= {AXI_DATA_WIDTH{1'b0}};
            s_axi_rid       <= {ID_WIDTH{1'b0}};
            s_axi_rresp     <= 2'b00;
            s_axi_rlast     <= 1'b0;
            rsp_active      <= 1'b0;
            rsp_addr        <= {ADDR_WIDTH{1'b0}};
            rsp_id          <= {ID_WIDTH{1'b0}};
            wait_cycles     <= 0;
            beats_left      <= 0;
            beat_idx        <= 0;
            ar_cnt          <= 32'd0;
            arlen_warn_cnt  <= 32'd0;
            rlast_cnt       <= 32'd0;
        end else begin
            s_axi_rvalid  <= 1'b0;
            s_axi_rlast   <= 1'b0;

            if (s_axi_arvalid && s_axi_arready) begin
                rsp_active   <= 1'b1;
                rsp_addr     <= s_axi_araddr;
                rsp_id       <= s_axi_arid;
                wait_cycles  <= 1;
                beats_left   <= STRICT_AXI_BURST ? (s_axi_arlen + 1) : PRAGMATIC_BEATS;
                beat_idx     <= 0;
                ar_cnt       <= ar_cnt + 1'b1;

                if (s_axi_arlen != 8'd1) begin
                    arlen_warn_cnt <= arlen_warn_cnt + 1'b1;
                    $display("[%0t] WARN: ARLEN=%0d, current smoke model returns %0d beats.",
                             $time, s_axi_arlen, PRAGMATIC_BEATS);
                end
                if (s_axi_arsize != ARSIZE_EXPECTED[2:0]) begin
                    $display("[%0t] WARN: ARSIZE=%0d, expected %0d for %0d-bit AXI data width.",
                             $time, s_axi_arsize, ARSIZE_EXPECTED, AXI_DATA_WIDTH);
                end
                if (s_axi_arburst != 2'b01) begin
                    $display("[%0t] WARN: ARBURST=%0d, expected INCR burst.", $time, s_axi_arburst);
                end
            end else if (rsp_active && (wait_cycles != 0)) begin
                wait_cycles <= wait_cycles - 1;
            end else if (rsp_active) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rdata  <= gen_axi_word(rsp_addr, beat_idx);
                s_axi_rid    <= rsp_id;
                s_axi_rresp  <= 2'b00;
                s_axi_rlast  <= (beats_left == 1);

                if (s_axi_rready) begin
                    if (beats_left == 1) begin
                        rsp_active <= 1'b0;
                        beats_left <= 0;
                        beat_idx   <= 0;
                        rlast_cnt  <= rlast_cnt + 1'b1;
                    end else begin
                        beats_left <= beats_left - 1;
                        beat_idx   <= beat_idx + 1;
                    end
                end
            end
        end
    end

endmodule
