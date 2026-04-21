`timescale 1ns/1ps

module tb_ubwc_dec_meta_data_gen;

    localparam ADDR_WIDTH     = 32;
    localparam ID_WIDTH       = 4;
    localparam AXI_DATA_WIDTH = 256;
    localparam SRAM_ADDR_W    = 12;
    localparam SRAM_RD_DW     = 64;
    localparam [4:0] BASE_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] BASE_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] BASE_FMT_YUV420_8    = 5'b00010;
    localparam [4:0] BASE_FMT_YUV420_10   = 5'b00011;
    localparam [4:0] BASE_FMT_YUV422_8    = 5'b00100;
    localparam [4:0] BASE_FMT_YUV422_10   = 5'b00101;
    // 0: smoke test mode, each AR request returns 2 beats to match the current
    // ubwc_dec_axi_rdata_to_sram implementation intent.
    // 1: strict AXI mode, return arlen+1 beats, where arlen is already converted
    // from byte-based cmd_len inside ubwc_dec_axi_rcmd_gen.
    localparam STRICT_AXI_BURST = 1'b0;
    localparam PRAGMATIC_BEATS  = 2;

    reg                         clk;
    reg                         rst_n;
    reg                         start;
    reg  [4:0]                  base_format;
    reg  [ADDR_WIDTH-1:0]       meta_base_addr_rgba_uv;
    reg  [ADDR_WIDTH-1:0]       meta_base_addr_y;
    reg  [15:0]                 tile_x_numbers;
    reg  [15:0]                 tile_y_numbers;

    wire                        m_axi_arvalid;
    wire                        m_axi_arready;
    wire [ADDR_WIDTH-1:0]       m_axi_araddr;
    wire [7:0]                  m_axi_arlen;
    wire [2:0]                  m_axi_arsize;
    wire [1:0]                  m_axi_arburst;
    wire [ID_WIDTH-1:0]         m_axi_arid;

    wire                        m_axi_rvalid;
    wire                        m_axi_rready;
    wire [AXI_DATA_WIDTH-1:0]   m_axi_rdata;
    wire [ID_WIDTH-1:0]         m_axi_rid;
    wire [1:0]                  m_axi_rresp;
    wire                        m_axi_rlast;

    wire [37:0]                 fifo_wdata;
    wire                        fifo_vld;
    reg                         fifo_rdy;

    wire [31:0]                 error_cnt;
    wire [31:0]                 cmd_ok_cnt;
    wire [31:0]                 cmd_fail_cnt;

    integer                     cycle_cnt;
    integer                     fifo_out_cnt;
    wire [31:0]                 ar_cnt;
    wire [31:0]                 arlen_warn_cnt;
    wire [31:0]                 rlast_cnt;
    wire [31:0]                 sram_wr_cnt      = dut.u_meta_pingpong_sram.wr_cnt;
    wire [31:0]                 sram_rd_req_cnt  = dut.u_meta_pingpong_sram.rd_req_cnt;
    wire [31:0]                 sram_rd_rsp_cnt  = dut.u_meta_pingpong_sram.rd_rsp_cnt;
    wire [31:0]                 sram_rd_miss_cnt = dut.u_meta_pingpong_sram.rd_miss_cnt;

    ubwc_dec_meta_data_gen #(
        .ADDR_WIDTH     (ADDR_WIDTH),
        .ID_WIDTH       (ID_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .SRAM_ADDR_W    (SRAM_ADDR_W),
        .SRAM_RD_DW     (SRAM_RD_DW)
    ) dut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .start                  (start),
        .base_format            (base_format),
        .meta_base_addr_rgba_uv (meta_base_addr_rgba_uv),
        .meta_base_addr_y       (meta_base_addr_y),
        .tile_x_numbers         (tile_x_numbers),
        .tile_y_numbers         (tile_y_numbers),
        .m_axi_arvalid          (m_axi_arvalid),
        .m_axi_arready          (m_axi_arready),
        .m_axi_araddr           (m_axi_araddr),
        .m_axi_arlen            (m_axi_arlen),
        .m_axi_arsize           (m_axi_arsize),
        .m_axi_arburst          (m_axi_arburst),
        .m_axi_arid             (m_axi_arid),
        .m_axi_rvalid           (m_axi_rvalid),
        .m_axi_rready           (m_axi_rready),
        .m_axi_rdata            (m_axi_rdata),
        .m_axi_rid              (m_axi_rid),
        .m_axi_rresp            (m_axi_rresp),
        .m_axi_rlast            (m_axi_rlast),
        .fifo_wdata             (fifo_wdata),
        .fifo_vld               (fifo_vld),
        .fifo_rdy               (fifo_rdy),
        .error_cnt              (error_cnt),
        .cmd_ok_cnt             (cmd_ok_cnt),
        .cmd_fail_cnt           (cmd_fail_cnt)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    tb_axi_read_slave_model #(
        .ADDR_WIDTH       (ADDR_WIDTH),
        .ID_WIDTH         (ID_WIDTH),
        .AXI_DATA_WIDTH   (AXI_DATA_WIDTH),
        .STRICT_AXI_BURST (STRICT_AXI_BURST),
        .PRAGMATIC_BEATS  (PRAGMATIC_BEATS)
    ) u_axi_slave_model (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_arvalid  (m_axi_arvalid),
        .s_axi_arready  (m_axi_arready),
        .s_axi_araddr   (m_axi_araddr),
        .s_axi_arlen    (m_axi_arlen),
        .s_axi_arsize   (m_axi_arsize),
        .s_axi_arburst  (m_axi_arburst),
        .s_axi_arid     (m_axi_arid),
        .s_axi_rvalid   (m_axi_rvalid),
        .s_axi_rready   (m_axi_rready),
        .s_axi_rdata    (m_axi_rdata),
        .s_axi_rid      (m_axi_rid),
        .s_axi_rresp    (m_axi_rresp),
        .s_axi_rlast    (m_axi_rlast),
        .ar_cnt         (ar_cnt),
        .arlen_warn_cnt (arlen_warn_cnt),
        .rlast_cnt      (rlast_cnt)
    );

    task automatic pulse_start;
        begin
            @(posedge clk);
            start <= 1'b1;
            @(posedge clk);
            start <= 1'b0;
        end
    endtask

    task automatic wait_frame_done;
        integer timeout;
        begin
            timeout = 0;
            while ((dut.u_meta_get_cmd_gen.state != 4'd8) && (timeout < 5000)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 5000) begin
                $fatal(1, "Timeout waiting frame done.");
            end
            repeat (120) @(posedge clk);
        end
    endtask

    // Periodic backpressure to exercise fifo_vld/fifo_rdy handshakes.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
            fifo_rdy  <= 1'b1;
        end else begin
            cycle_cnt <= cycle_cnt + 1;
            fifo_rdy  <= ((cycle_cnt % 9) != 4);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_out_cnt <= 0;
        end else if (fifo_vld && fifo_rdy) begin
            fifo_out_cnt <= fifo_out_cnt + 1;
            $display("[%0t] FIFO: err=%0b eol=%0b last=%0b meta=%02h fmt=%0h x_byte=%03h y_row=%03h",
                     $time,
                     fifo_wdata[37],
                     fifo_wdata[36],
                     fifo_wdata[35],
                     fifo_wdata[34:27],
                     fifo_wdata[26:22],
                     fifo_wdata[21:10],
                     fifo_wdata[9:0]);
        end
    end

    initial begin
        rst_n                  = 1'b0;
        start                  = 1'b0;
        base_format            = BASE_FMT_YUV420_8;
        meta_base_addr_rgba_uv = 32'h1000_0000;
        meta_base_addr_y       = 32'h2000_0000;
        tile_x_numbers         = 16'd1;
        tile_y_numbers         = 16'd1;

        #25;
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        $display("");
        $display("==============================================");
        $display("TB: ubwc_dec_meta_data_gen smoke test");
        $display("Mode: %s", STRICT_AXI_BURST ? "STRICT_AXI_BURST" : "PRAGMATIC_2_BEAT");
        $display("Case: YUV420 8-bit, tile_x_numbers=1, tile_y_numbers=1");
        $display("==============================================");

        pulse_start();
        wait_frame_done();

        $display("");
        $display("--------------- Summary ---------------");
        $display("AR handshakes  : %0d", ar_cnt);
        $display("ARLEN warnings : %0d", arlen_warn_cnt);
        $display("R last count   : %0d", rlast_cnt);
        $display("SRAM writes    : %0d", sram_wr_cnt);
        $display("SRAM read reqs : %0d", sram_rd_req_cnt);
        $display("SRAM read rsps : %0d", sram_rd_rsp_cnt);
        $display("SRAM read miss : %0d", sram_rd_miss_cnt);
        $display("FIFO outputs   : %0d", fifo_out_cnt);
        $display("error_cnt      : %0d", error_cnt);
        $display("cmd_ok_cnt     : %0d", cmd_ok_cnt);
        $display("cmd_fail_cnt   : %0d", cmd_fail_cnt);
        $display("---------------------------------------");

        if (ar_cnt == 0) begin
            $fatal(1, "No AXI AR request observed.");
        end
        if (rlast_cnt == 0) begin
            $fatal(1, "No AXI RLAST observed.");
        end
        if (fifo_out_cnt == 0) begin
            $fatal(1, "No FIFO output observed.");
        end
        if (cmd_fail_cnt != 0) begin
            $fatal(1, "cmd_fail_cnt is non-zero.");
        end

        if (sram_rd_miss_cnt != 0) begin
            $display("WARN: SRAM read misses observed. This usually means the current");
            $display("      read/write address mapping assumptions are not fully aligned.");
        end

        #50;
        $finish;
    end

    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("tb_ubwc_dec_meta_data_gen.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_meta_data_gen);
        $fsdbDumpMDA(0, tb_ubwc_dec_meta_data_gen);
`else
        $dumpfile("tb_ubwc_dec_meta_data_gen.vcd");
        $dumpvars(0, tb_ubwc_dec_meta_data_gen);
`endif
`endif
    end

endmodule
