`timescale 1ns/1ps

module tb_ubwc_dec_meta_data_gen_bank_reuse;

    localparam integer ADDR_WIDTH     = 32;
    localparam integer ID_WIDTH       = 4;
    localparam integer AXI_DATA_WIDTH = 256;
    localparam integer SRAM_ADDR_W    = 12;
    localparam integer SRAM_RD_DW     = 64;
    localparam [4:0]   BASE_FMT_RGBA8888 = 5'b00000;
    localparam integer META_DONE_STATE = 8;

    reg                       clk;
    reg                       rst_n;
    reg                       start;
    reg  [4:0]                base_format;
    reg  [ADDR_WIDTH-1:0]     meta_base_addr_rgba_y;
    reg  [ADDR_WIDTH-1:0]     meta_base_addr_uv;
    reg  [15:0]               tile_x_numbers;
    reg  [15:0]               tile_y_numbers;

    wire                      m_axi_arvalid;
    wire                      m_axi_arready;
    wire [ADDR_WIDTH-1:0]     m_axi_araddr;
    wire [7:0]                m_axi_arlen;
    wire [2:0]                m_axi_arsize;
    wire [1:0]                m_axi_arburst;
    wire [ID_WIDTH-1:0]       m_axi_arid;

    wire                      m_axi_rvalid;
    wire                      m_axi_rready;
    wire [AXI_DATA_WIDTH-1:0] m_axi_rdata;
    wire [ID_WIDTH-1:0]       m_axi_rid;
    wire [1:0]                m_axi_rresp;
    wire                      m_axi_rlast;

    wire [37:0]               fifo_wdata;
    wire                      fifo_vld;
    reg                       fifo_rdy;

    wire [31:0]               error_cnt;
    wire [31:0]               cmd_ok_cnt;
    wire [31:0]               cmd_fail_cnt;

    integer                   cycle_cnt;
    integer                   timeout_cnt;
    integer                   fill_a_cnt;
    integer                   fill_b_cnt;
    integer                   release_a_cnt;
    integer                   release_b_cnt;
    integer                   double_fill_err_cnt;
    reg                       bank_a_pending;
    reg                       bank_b_pending;

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
        .meta_base_addr_rgba_y (meta_base_addr_rgba_y),
        .meta_base_addr_uv       (meta_base_addr_uv),
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
        .o_busy                 (),
        .error_cnt              (error_cnt),
        .cmd_ok_cnt             (cmd_ok_cnt),
        .cmd_fail_cnt           (cmd_fail_cnt)
    );

    tb_axi_read_slave_model #(
        .ADDR_WIDTH       (ADDR_WIDTH),
        .ID_WIDTH         (ID_WIDTH),
        .AXI_DATA_WIDTH   (AXI_DATA_WIDTH),
        .STRICT_AXI_BURST (1'b0),
        .PRAGMATIC_BEATS  (2)
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
        .ar_cnt         (),
        .arlen_warn_cnt (),
        .rlast_cnt      ()
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
            fifo_rdy  <= 1'b0;
        end else begin
            cycle_cnt <= cycle_cnt + 1;
            // Keep the read side much slower than the write side so bank reuse
            // pressure shows up quickly.
            fifo_rdy <= ((cycle_cnt % 17) == 0);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fill_a_cnt           <= 0;
            fill_b_cnt           <= 0;
            release_a_cnt        <= 0;
            release_b_cnt        <= 0;
            double_fill_err_cnt  <= 0;
            bank_a_pending       <= 1'b0;
            bank_b_pending       <= 1'b0;
        end else if (start) begin
            fill_a_cnt           <= 0;
            fill_b_cnt           <= 0;
            release_a_cnt        <= 0;
            release_b_cnt        <= 0;
            double_fill_err_cnt  <= 0;
            bank_a_pending       <= 1'b0;
            bank_b_pending       <= 1'b0;
        end else begin
            if (dut.meta_bank_fill_valid && !dut.meta_bank_fill_bank_b) begin
                if (bank_a_pending) begin
                    double_fill_err_cnt <= double_fill_err_cnt + 1;
                end
                bank_a_pending <= 1'b1;
                fill_a_cnt <= fill_a_cnt + 1;
            end
            if (dut.meta_bank_fill_valid && dut.meta_bank_fill_bank_b) begin
                if (bank_b_pending) begin
                    double_fill_err_cnt <= double_fill_err_cnt + 1;
                end
                bank_b_pending <= 1'b1;
                fill_b_cnt <= fill_b_cnt + 1;
            end
            if (dut.meta_bank_release_valid && !dut.meta_bank_release_bank_b) begin
                bank_a_pending <= 1'b0;
                release_a_cnt <= release_a_cnt + 1;
            end
            if (dut.meta_bank_release_valid && dut.meta_bank_release_bank_b) begin
                bank_b_pending <= 1'b0;
                release_b_cnt <= release_b_cnt + 1;
            end
        end
    end

    initial begin
        rst_n                  = 1'b0;
        start                  = 1'b0;
        base_format            = BASE_FMT_RGBA8888;
        meta_base_addr_rgba_y = 32'h8000_0000;
        meta_base_addr_uv       = 32'h8000_0000;
        tile_x_numbers         = 16'd8;
        tile_y_numbers         = 16'd48;
        fifo_rdy               = 1'b0;
        timeout_cnt            = 0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        while (((fill_a_cnt < 2) || (fill_b_cnt < 1) ||
                (release_a_cnt < 2) || (release_b_cnt < 1) ||
                bank_a_pending || bank_b_pending) &&
               (timeout_cnt < 200000)) begin
            @(posedge clk);
            timeout_cnt = timeout_cnt + 1;
        end

        $display("");
        $display("==============================================");
        $display("TB: ubwc_dec_meta_data_gen bank reuse guard");
        $display("fill_a/release_a : %0d / %0d", fill_a_cnt, release_a_cnt);
        $display("fill_b/release_b : %0d / %0d", fill_b_cnt, release_b_cnt);
        $display("double_fill_errs : %0d", double_fill_err_cnt);
        $display("cmd_ok/fail      : %0d / %0d", cmd_ok_cnt, cmd_fail_cnt);
        $display("==============================================");

        if (timeout_cnt >= 200000) begin
            $fatal(1, "Timeout waiting for bank reuse test to complete.");
        end
        if (double_fill_err_cnt != 0) begin
            $fatal(1, "Observed bank refill before prior contents were released.");
        end
        if (fill_a_cnt != 2) begin
            $fatal(1, "Expected bank A to be used twice. got=%0d", fill_a_cnt);
        end
        if (fill_b_cnt != 1) begin
            $fatal(1, "Expected bank B to be used once. got=%0d", fill_b_cnt);
        end
        if (release_a_cnt != 2) begin
            $fatal(1, "Expected bank A to be released twice. got=%0d", release_a_cnt);
        end
        if (release_b_cnt != 1) begin
            $fatal(1, "Expected bank B to be released once. got=%0d", release_b_cnt);
        end
        if (cmd_fail_cnt != 0) begin
            $fatal(1, "cmd_fail_cnt should stay zero.");
        end

        $display("PASS: meta bank reuse is protected until read side release.");
        $finish;
    end

endmodule
