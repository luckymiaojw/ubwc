`timescale 1ns/1ps

module tb_ubwc_dec_meta_data_gen;

    localparam ADDR_WIDTH     = 32;
    localparam ID_WIDTH       = 4;
    localparam AXI_DATA_WIDTH = 256;
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
    reg  [ADDR_WIDTH-1:0]       meta_base_addr_rgba_y;
    reg  [ADDR_WIDTH-1:0]       meta_base_addr_uv;
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

    wire                        dec_valid;
    reg                         dec_ready;
    wire [4:0]                  dec_format;
    wire [3:0]                  dec_flag;
    wire [2:0]                  dec_alen;
    wire                        dec_has_payload;
    wire [11:0]                 dec_x;
    wire [9:0]                  dec_y;

    wire [31:0]                 error_cnt;
    wire [31:0]                 cmd_ok_cnt;
    wire [31:0]                 cmd_fail_cnt;

    integer                     cycle_cnt;
    integer                     dec_out_cnt;
    wire [31:0]                 ar_cnt;
    wire [31:0]                 arlen_warn_cnt;
    wire [31:0]                 rlast_cnt;

    ubwc_dec_meta_data_gen #(
        .ADDR_WIDTH     (ADDR_WIDTH),
        .ID_WIDTH       (ID_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH)
    ) dut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .start                  (start),
        .base_format            (base_format),
        .meta_base_addr_rgba_y (meta_base_addr_rgba_y),
        .meta_base_addr_uv       (meta_base_addr_uv),
        .tile_x_numbers         (tile_x_numbers),
        .tile_y_numbers         (tile_y_numbers),
        .i_cfg_is_lossy_rgba_2_1_format (1'b0),
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
        .o_dec_valid            (dec_valid),
        .i_dec_ready            (dec_ready),
        .o_dec_format           (dec_format),
        .o_dec_flag             (dec_flag),
        .o_dec_alen             (dec_alen),
        .o_dec_has_payload      (dec_has_payload),
        .o_dec_x                (dec_x),
        .o_dec_y                (dec_y),
        .o_busy                 (),
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
            while ((dut.u_meta_get_cmd_gen.frame_done != 1'b1) && (timeout < 5000)) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 5000) begin
                $fatal(1, "Timeout waiting frame done.");
            end
            repeat (120) @(posedge clk);
        end
    endtask

    // Periodic backpressure to exercise decoded metadata handshakes.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
            dec_ready <= 1'b1;
        end else begin
            cycle_cnt <= cycle_cnt + 1;
            dec_ready <= ((cycle_cnt % 9) != 4);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dec_out_cnt <= 0;
        end else if (dec_valid && dec_ready) begin
            dec_out_cnt <= dec_out_cnt + 1;
            $display("[%0t] DEC: fmt=%0h flag=%0h alen=%0d payload=%0b x=%03h y=%03h",
                     $time,
                     dec_format,
                     dec_flag,
                     dec_alen,
                     dec_has_payload,
                     dec_x,
                     dec_y);
        end
    end

    initial begin
        rst_n                  = 1'b0;
        start                  = 1'b0;
        base_format            = BASE_FMT_YUV420_8;
        meta_base_addr_rgba_y = 32'h1000_0000;
        meta_base_addr_uv       = 32'h2000_0000;
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
        $display("DEC outputs    : %0d", dec_out_cnt);
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
        if (dec_out_cnt == 0) begin
            $fatal(1, "No decoded metadata output observed.");
        end
        if (cmd_fail_cnt != 0) begin
            $fatal(1, "cmd_fail_cnt is non-zero.");
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
