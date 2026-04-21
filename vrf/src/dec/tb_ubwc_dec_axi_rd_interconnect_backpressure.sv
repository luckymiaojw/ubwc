`timescale 1ns/1ps

module tb_ubwc_dec_axi_rd_interconnect_backpressure;

    localparam integer AXI_AW   = 64;
    localparam integer AXI_DW   = 256;
    localparam integer AXI_IDW  = 6;
    localparam integer AXI_LENW = 8;

    reg                    clk;
    reg                    rst_n;

    reg                    s0_arvalid;
    wire                   s0_arready;
    reg  [AXI_AW-1:0]      s0_araddr;
    reg  [7:0]             s0_arlen;
    reg  [2:0]             s0_arsize;
    reg  [1:0]             s0_arburst;
    reg  [AXI_IDW-1:0]     s0_arid;
    wire                   s0_rvalid;
    reg                    s0_rready;
    wire [AXI_DW-1:0]      s0_rdata;
    wire [1:0]             s0_rresp;
    wire                   s0_rlast;

    reg                    s1_arvalid;
    wire                   s1_arready;
    reg  [AXI_AW-1:0]      s1_araddr;
    reg  [7:0]             s1_arlen;
    reg  [2:0]             s1_arsize;
    reg  [1:0]             s1_arburst;
    reg  [AXI_IDW-1:0]     s1_arid;
    wire                   s1_rvalid;
    reg                    s1_rready;
    wire [AXI_DW-1:0]      s1_rdata;
    wire [1:0]             s1_rresp;
    wire                   s1_rlast;

    wire [AXI_IDW:0]       m_arid;
    wire [AXI_AW-1:0]      m_araddr;
    wire [AXI_LENW-1:0]    m_arlen;
    wire [3:0]             m_arsize;
    wire [1:0]             m_arburst;
    wire                   m_arvalid;
    reg                    m_arready;
    reg  [AXI_DW-1:0]      m_rdata;
    reg                    m_rvalid;
    reg  [1:0]             m_rresp;
    reg                    m_rlast;
    wire                   m_rready;

    integer                s1_last_count;

    ubwc_dec_axi_rd_interconnect #(
        .AXI_AW   (AXI_AW),
        .AXI_DW   (AXI_DW),
        .AXI_IDW  (AXI_IDW),
        .AXI_LENW (AXI_LENW)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .i_frame_start(1'b0),
        .s0_arvalid(s0_arvalid),
        .s0_arready(s0_arready),
        .s0_araddr (s0_araddr),
        .s0_arlen  (s0_arlen),
        .s0_arsize (s0_arsize),
        .s0_arburst(s0_arburst),
        .s0_arid   (s0_arid),
        .s0_rvalid (s0_rvalid),
        .s0_rready (s0_rready),
        .s0_rdata  (s0_rdata),
        .s0_rresp  (s0_rresp),
        .s0_rlast  (s0_rlast),
        .s1_arvalid(s1_arvalid),
        .s1_arready(s1_arready),
        .s1_araddr (s1_araddr),
        .s1_arlen  (s1_arlen),
        .s1_arsize (s1_arsize),
        .s1_arburst(s1_arburst),
        .s1_arid   (s1_arid),
        .s1_rvalid (s1_rvalid),
        .s1_rready (s1_rready),
        .s1_rdata  (s1_rdata),
        .s1_rresp  (s1_rresp),
        .s1_rlast  (s1_rlast),
        .m_arid    (m_arid),
        .m_araddr  (m_araddr),
        .m_arlen   (m_arlen),
        .m_arsize  (m_arsize),
        .m_arburst (m_arburst),
        .m_arvalid (m_arvalid),
        .m_arready (m_arready),
        .m_rdata   (m_rdata),
        .m_rvalid  (m_rvalid),
        .m_rresp   (m_rresp),
        .m_rlast   (m_rlast),
        .m_rready  (m_rready)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_last_count <= 0;
        end else if (s1_rvalid && s1_rready && s1_rlast) begin
            s1_last_count <= s1_last_count + 1;
        end
    end

    initial begin
        rst_n     = 1'b0;
        s0_arvalid = 1'b0;
        s0_araddr  = '0;
        s0_arlen   = '0;
        s0_arsize  = 3'd5;
        s0_arburst = 2'b01;
        s0_arid    = '0;
        s0_rready  = 1'b0;

        s1_arvalid = 1'b0;
        s1_araddr  = 64'h1000;
        s1_arlen   = 8'd1;
        s1_arsize  = 3'd5;
        s1_arburst = 2'b01;
        s1_arid    = '0;
        s1_rready  = 1'b1;

        m_arready  = 1'b1;
        m_rdata    = '0;
        m_rvalid   = 1'b0;
        m_rresp    = 2'b00;
        m_rlast    = 1'b0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("TB: ubwc_dec_axi_rd_interconnect backpressure");

        // Issue one request from s1.
        s1_arvalid <= 1'b1;
        @(posedge clk);
        if (!s1_arready) begin
            $fatal(1, "s1_arready was not asserted for the request.");
        end
        s1_arvalid <= 1'b0;

        // Beat 0 goes through directly.
        m_rvalid <= 1'b1;
        m_rdata  <= 256'h1111;
        m_rlast  <= 1'b0;
        @(posedge clk);
        if (!m_rready || !s1_rvalid || s1_rlast) begin
            $fatal(1, "Beat0 handshake mismatch. m_rready=%0b s1_rvalid=%0b s1_rlast=%0b",
                   m_rready, s1_rvalid, s1_rlast);
        end

        // Hold the sink not-ready for one cycle while the final beat arrives.
        // The interconnect should still absorb this beat into its local buffer.
        s1_rready <= 1'b0;
        m_rdata   <= 256'h2222;
        m_rlast   <= 1'b1;
        @(posedge clk);
        if (!m_rready) begin
            $fatal(1, "Final beat was not accepted into the elastic buffer.");
        end
        m_rvalid <= 1'b0;
        m_rlast  <= 1'b0;

        // The buffered final beat should be replayed when the sink is ready.
        repeat (2) @(posedge clk);
        s1_rready <= 1'b1;
        @(posedge clk);
        if (!s1_rvalid || !s1_rlast) begin
            $fatal(1, "Buffered final beat was not replayed to s1.");
        end
        @(posedge clk);

        // A second request should no longer be blocked by a stuck inflight state.
        s1_arvalid <= 1'b1;
        @(posedge clk);
        if (!s1_arready) begin
            $fatal(1, "Second request was blocked after the buffered last beat.");
        end
        s1_arvalid <= 1'b0;

        if (s1_last_count != 1) begin
            $fatal(1, "Unexpected s1 last-beat count: %0d", s1_last_count);
        end

        $display("PASS: ubwc_dec_axi_rd_interconnect backpressure");
        #20;
        $finish;
    end

endmodule
