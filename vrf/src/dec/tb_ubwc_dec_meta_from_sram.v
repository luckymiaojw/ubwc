`timescale 1ns/1ps

module tb_ubwc_dec_meta;

    // Parameter definitions
    parameter SRAM_ADDR_W = 12;
    parameter SRAM_DW     = 64;
    localparam [SRAM_ADDR_W-1:0] PRELOAD_ADDR_LO = 12'h104;
    localparam [SRAM_ADDR_W-1:0] PRELOAD_ADDR_HI = 12'h105;
    localparam [4:0] BASE_FMT_YUV420_8 = 5'b00010;

    // DUT signals
    reg                     clk;
    reg                     rst_n;
    reg                     start;
    reg  [ 4:0]             base_format;
    reg  [15:0]             tile_x_numbers;
    reg  [15:0]             tile_y_numbers;
    wire [ 3:0]             sram_re_a;
    wire [ 3:0]             sram_re_b;
    wire [SRAM_ADDR_W-1:0]  sram_addr;
    wire [SRAM_DW-1:0]      sram_rdata;
    wire                    sram_rvalid;
    reg                     bfifo_we;
    reg  [40:0]             bfifo_wdata;
    wire                    bfifo_prog_full;
    wire [37:0]             fifo_wdata;
    wire                    fifo_vld;
    reg                     fifo_rdy;
    wire                    bank_release_valid_unused;
    wire                    bank_release_bank_b_unused;
    reg  [3:0]              sram_wr_we_a_tb;
    reg  [3:0]              sram_wr_we_b_tb;
    reg  [SRAM_ADDR_W-1:0]  sram_wr_addr_tb;
    reg  [255:0]            sram_wr_wdata_tb;
    wire                    sram_rsp_bank_b_unused;
    wire [1:0]              sram_rsp_lane_unused;
    wire [SRAM_ADDR_W-1:0]  sram_rsp_addr_unused;
    wire                    sram_rsp_hit_unused;
    wire [31:0]             sram_wr_cnt_unused;
    wire [31:0]             sram_rd_req_cnt_unused;
    wire [31:0]             sram_rd_rsp_cnt_unused;
    wire [31:0]             sram_rd_miss_cnt_unused;
    integer                 lane;

    // Instantiate DUT
    ubwc_dec_meta_data_from_sram #(
        .SRAM_ADDR_W(SRAM_ADDR_W),
        .SRAM_DW(SRAM_DW)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .base_format    (base_format),
        .tile_x_numbers (tile_x_numbers),
        .tile_y_numbers (tile_y_numbers),
        .sram_re_a      (sram_re_a),
        .sram_re_b      (sram_re_b),
        .sram_addr      (sram_addr),
        .sram_rdata     (sram_rdata),
        .sram_rvalid    (sram_rvalid),
        .bfifo_we       (bfifo_we),
        .bfifo_wdata    (bfifo_wdata),
        .bfifo_prog_full(bfifo_prog_full),
        .fifo_wdata     (fifo_wdata),
        .fifo_vld       (fifo_vld),
        .fifo_rdy       (fifo_rdy),
        .bank_release_valid (bank_release_valid_unused),
        .bank_release_bank_b(bank_release_bank_b_unused)
    );

    ubwc_dec_meta_pingpong_sram #(
        .WR_DATA_W (256),
        .RD_DATA_W (SRAM_DW),
        .ADDR_W    (SRAM_ADDR_W),
        .NUM_LANES (4),
        .DEPTH     (1 << SRAM_ADDR_W)
    ) u_sram_model (
        .clk           (clk),
        .rst_n         (rst_n),
        .wr_we_a       (sram_wr_we_a_tb),
        .wr_we_b       (sram_wr_we_b_tb),
        .wr_addr       (sram_wr_addr_tb),
        .wr_wdata      (sram_wr_wdata_tb),
        .rd_re_a       (sram_re_a),
        .rd_re_b       (sram_re_b),
        .rd_addr       (sram_addr),
        .rd_rdata      (sram_rdata),
        .rd_rvalid     (sram_rvalid),
        .rd_rsp_bank_b (sram_rsp_bank_b_unused),
        .rd_rsp_lane   (sram_rsp_lane_unused),
        .rd_rsp_addr   (sram_rsp_addr_unused),
        .rd_rsp_hit    (sram_rsp_hit_unused),
        .wr_cnt        (sram_wr_cnt_unused),
        .rd_req_cnt    (sram_rd_req_cnt_unused),
        .rd_rsp_cnt    (sram_rd_rsp_cnt_unused),
        .rd_miss_cnt   (sram_rd_miss_cnt_unused)
    );

    // Clock generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Main test flow
    initial begin
        // 1. Initialization
        rst_n          = 0;
        start          = 0;
        base_format    = BASE_FMT_YUV420_8;
        tile_x_numbers = 16'd8;
        tile_y_numbers = 16'd16;
        bfifo_we       = 0;
        bfifo_wdata    = 41'd0;
        fifo_rdy       = 1; // Downstream is always ready
        sram_wr_we_a_tb = 4'd0;
        sram_wr_we_b_tb = 4'd0;
        sram_wr_addr_tb = {SRAM_ADDR_W{1'b0}};
        sram_wr_wdata_tb = 256'd0;

        #20 rst_n = 1; // Release reset
        for (lane = 0; lane < 4; lane = lane + 1) begin
            sram_wr_we_a_tb = (4'b0001 << lane);
            sram_wr_addr_tb = PRELOAD_ADDR_LO;
            sram_wr_wdata_tb = {4{64'h07_06_05_04_03_02_01_00}};
            @(posedge clk);
            sram_wr_we_a_tb = (4'b0001 << lane);
            sram_wr_addr_tb = PRELOAD_ADDR_HI;
            sram_wr_wdata_tb = {4{64'h07_06_05_04_03_02_01_00}};
            @(posedge clk);
        end
        sram_wr_we_a_tb = 4'd0;
        #10 start = 1;
        #10 start = 0;
        #10;

        // 2. Emulate one bfifo descriptor pushed from the upstream stage
        // {pingpong, error, is_eol, is_last_pass, meta_format[4:0], xcoord[15:0], ycoord[15:0]}
        bfifo_we    = 1'b1;
        bfifo_wdata = {1'b0, 1'b0, 1'b1, 1'b1, 5'b01000, 16'd2, 16'd1};
        #10;
        bfifo_we    = 1'b0; // Deassert after one cycle

        // 3. Run the simulation for a while and inspect the waveform
        // Expected behavior:
        // row_phase 0~7: output the current 8-row group row by row
        // After row_phase 7 completes, return to 0 and wait for the next 8-row group
        #1000;
        
        $display("Simulation Finished.");
        $finish;
    end

    // Print a log whenever data is sent to the downstream interface
    always @(posedge clk) begin
        if (fifo_vld && fifo_rdy) begin
            $display("Time: %0t | row_phase: %0d | Addr: %0h | Meta Data Byte: %h",
                     $time, dut.row_phase, dut.sram_addr, fifo_wdata[34:27]);
        end
    end

    // Dump waveform
    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("top.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_meta);
`else
        $dumpfile("tb_ubwc_dec_meta.vcd");
        $dumpvars(0, tb_ubwc_dec_meta);
`endif
`endif
    end

endmodule
