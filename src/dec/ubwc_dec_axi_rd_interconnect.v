`timescale 1ns/1ps

module ubwc_dec_axi_rd_interconnect #(
    parameter AXI_AW   = 64,
    parameter AXI_DW   = 256,
    parameter AXI_IDW  = 6,
    parameter AXI_LENW = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  i_frame_start,

    input  wire                  s0_arvalid,
    output wire                  s0_arready,
    input  wire [AXI_AW-1:0]     s0_araddr,
    input  wire [7:0]            s0_arlen,
    input  wire [2:0]            s0_arsize,
    input  wire [1:0]            s0_arburst,
    input  wire [AXI_IDW-1:0]    s0_arid,
    output wire                  s0_rvalid,
    input  wire                  s0_rready,
    output wire [AXI_DW-1:0]     s0_rdata,
    output wire [1:0]            s0_rresp,
    output wire                  s0_rlast,

    input  wire                  s1_arvalid,
    output wire                  s1_arready,
    input  wire [AXI_AW-1:0]     s1_araddr,
    input  wire [7:0]            s1_arlen,
    input  wire [2:0]            s1_arsize,
    input  wire [1:0]            s1_arburst,
    input  wire [AXI_IDW-1:0]    s1_arid,
    output wire                  s1_rvalid,
    input  wire                  s1_rready,
    output wire [AXI_DW-1:0]     s1_rdata,
    output wire [1:0]            s1_rresp,
    output wire                  s1_rlast,

    output wire [AXI_IDW:0]      m_arid,
    output wire [AXI_AW-1:0]     m_araddr,
    output wire [AXI_LENW-1:0]   m_arlen,
    output wire [3:0]            m_arsize,
    output wire [1:0]            m_arburst,
    output wire                  m_arvalid,
    input  wire                  m_arready,
    input  wire [AXI_DW-1:0]     m_rdata,
    input  wire                  m_rvalid,
    input  wire [1:0]            m_rresp,
    input  wire                  m_rlast,
    output wire                  m_rready,

    output wire                  o_busy
);

    reg                  inflight;
    reg                  owner_s0;
    reg                  prefer_s1;
    reg                  rbuf_valid;
    reg [AXI_DW-1:0]     rbuf_data;
    reg [1:0]            rbuf_resp;
    reg                  rbuf_last;

    wire grant_s0 = !inflight && s0_arvalid && (!s1_arvalid || !prefer_s1);
    wire grant_s1 = !inflight && s1_arvalid && (!s0_arvalid ||  prefer_s1);

    wire [AXI_AW-1:0]   sel_araddr  = grant_s0 ? s0_araddr  : s1_araddr;
    wire [7:0]          sel_arlen   = grant_s0 ? s0_arlen   : s1_arlen;
    wire [2:0]          sel_arsize  = grant_s0 ? s0_arsize  : s1_arsize;
    wire [1:0]          sel_arburst = grant_s0 ? s0_arburst : s1_arburst;
    wire [AXI_IDW-1:0]  sel_arid    = grant_s0 ? s0_arid    : s1_arid;

    assign m_arvalid = !inflight && (s0_arvalid || s1_arvalid);
    assign m_araddr  = sel_araddr;
    assign m_arlen   = {{(AXI_LENW-8){1'b0}}, sel_arlen};
    assign m_arsize  = {1'b0, sel_arsize};
    assign m_arburst = sel_arburst;
    assign m_arid    = {1'b0, sel_arid};

    assign s0_arready = grant_s0 && m_arready;
    assign s1_arready = grant_s1 && m_arready;

    wire                 sel_rready     = owner_s0 ? s0_rready : s1_rready;
    wire                 routed_rvalid  = inflight && (rbuf_valid || m_rvalid);
    wire [AXI_DW-1:0]    routed_rdata   = rbuf_valid ? rbuf_data : m_rdata;
    wire [1:0]           routed_rresp   = rbuf_valid ? rbuf_resp : m_rresp;
    wire                 routed_rlast   = rbuf_valid ? rbuf_last : m_rlast;
    wire                 direct_last_ok = inflight && !rbuf_valid && m_rvalid && sel_rready && m_rlast;
    wire                 buf_last_ok    = inflight &&  rbuf_valid && sel_rready && rbuf_last;

    assign s0_rvalid = owner_s0 && routed_rvalid;
    assign s1_rvalid = !owner_s0 && routed_rvalid;
    assign s0_rdata  = routed_rdata;
    assign s1_rdata  = routed_rdata;
    assign s0_rresp  = routed_rresp;
    assign s1_rresp  = routed_rresp;
    assign s0_rlast  = owner_s0  && routed_rvalid && routed_rlast;
    assign s1_rlast  = !owner_s0 && routed_rvalid && routed_rlast;

    // Keep at most one return beat locally. Once a beat is buffered, stop the
    // upstream R channel until that buffered beat has been drained to the
    // selected sink. This avoids a subtle drain/fill race where one beat can be
    // accepted into the interconnect without ever reaching either sink.
    assign m_rready = inflight && !rbuf_valid;
    assign o_busy   = inflight | rbuf_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inflight <= 1'b0;
            owner_s0 <= 1'b0;
            prefer_s1 <= 1'b0;
            rbuf_valid <= 1'b0;
            rbuf_data  <= {AXI_DW{1'b0}};
            rbuf_resp  <= 2'b00;
            rbuf_last  <= 1'b0;
        end else if (i_frame_start) begin
            inflight <= 1'b0;
            owner_s0 <= 1'b0;
            prefer_s1 <= 1'b0;
            rbuf_valid <= 1'b0;
            rbuf_data  <= {AXI_DW{1'b0}};
            rbuf_resp  <= 2'b00;
            rbuf_last  <= 1'b0;
        end else begin
            if (!inflight) begin
                rbuf_valid <= 1'b0;
                if (m_arvalid && m_arready) begin
                    inflight <= 1'b1;
                    owner_s0 <= grant_s0;
                    prefer_s1 <= grant_s0;
                end
            end else begin
                if (rbuf_valid) begin
                    if (sel_rready) begin
                        rbuf_valid <= 1'b0;
                    end
                end else if (m_rvalid && !sel_rready) begin
                    rbuf_valid <= 1'b1;
                    rbuf_data  <= m_rdata;
                    rbuf_resp  <= m_rresp;
                    rbuf_last  <= m_rlast;
                end

                if (buf_last_ok || direct_last_ok) begin
                    inflight <= 1'b0;
                end
            end
        end
    end

endmodule
