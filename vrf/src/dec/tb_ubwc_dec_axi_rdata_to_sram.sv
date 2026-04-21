`timescale 1ns / 1ps

module tb_ubwc_dec_axi_rdata_to_sram();

    parameter AXI_DATA_WIDTH = 256;
    localparam [4:0] BASE_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] BASE_FMT_YUV420_8    = 5'b00010;
    localparam [4:0] BASE_FMT_YUV422_8    = 5'b00100;
    localparam [4:0] META_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] META_FMT_NV12_Y      = 5'b01000;
    localparam [4:0] META_FMT_NV12_UV     = 5'b01001;
    localparam [4:0] META_FMT_NV16_Y      = 5'b01010;
    reg clk, rst_n;
    reg start;

    // --- External configuration ---
    reg [4:0]  base_format;
    reg [15:0] tile_x_numbers;

    // --- Meta interface ---
    reg        meta_valid;
    wire       meta_ready;
    reg [4:0]  meta_format;
    reg [15:0] meta_xcoord, meta_ycoord;

    // --- AXI R channel ---
    reg                       axi_rvalid;
    wire                      axi_rready;
    reg  [AXI_DATA_WIDTH-1:0] axi_rdata;
    reg                       axi_rlast;

    // --- SRAM & FIFO monitors ---
    wire [3:0]  sram_we_a, sram_we_b;
    wire [11:0] sram_addr;
    wire        bfifo_we;
    wire [40:0] bfifo_wdata;
    wire        bank_fill_valid_unused;
    wire        bank_fill_bank_b_unused;

    // --- Instantiate DUT ---
    ubwc_dec_meta_axi_rdata_to_sram dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .base_format(base_format),
        .tile_x_numbers(tile_x_numbers),
        .meta_valid(meta_valid),
        .meta_ready(meta_ready),
        .meta_format(meta_format),
        .meta_xcoord(meta_xcoord),
        .meta_ycoord(meta_ycoord),
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready),
        .axi_rdata(axi_rdata),
        .axi_rlast(axi_rlast),
        .bank_a_free(1'b1),
        .bank_b_free(1'b1),
        .sram_we_a(sram_we_a),
        .sram_we_b(sram_we_b),
        .sram_addr(sram_addr),
        .sram_wdata(),
        .bfifo_we(bfifo_we),
        .bfifo_wdata(bfifo_wdata),
        .bank_fill_valid(bank_fill_valid_unused),
        .bank_fill_bank_b(bank_fill_bank_b_unused)
    );

    // Clock generation (100MHz)
    initial begin clk = 0; forever #5 clk = ~clk; end

    // --- Generic send task ---
    task send_meta(input [4:0] fmt, input [15:0] x, input [15:0] y);
        begin
            meta_valid = 1; meta_format = fmt; meta_xcoord = x; meta_ycoord = y;
            // Beat 1
            @(posedge clk); 
            axi_rvalid = 1; axi_rlast = 0; axi_rdata = {$random, $random};
            // Beat 2
            @(posedge clk); 
            axi_rlast = 1; axi_rdata = {$random, $random};
            // Wait for completion
            @(posedge clk);
            while(!meta_ready) @(posedge clk);
            meta_valid = 0; axi_rvalid = 0; axi_rlast = 0;
            @(posedge clk);
        end
    endtask

    initial begin
        // Initialize signals
        rst_n = 0; base_format = BASE_FMT_RGBA8888; tile_x_numbers = 16'd32;
        start = 0;
        meta_valid = 0; axi_rvalid = 0; axi_rlast = 0; axi_rdata = 0;
        #25 rst_n = 1;
        #10 start = 1;
        #10 start = 0;
        #20;

        // ============================================================
        // CASE 1: Normal YUV420 flow (check 3-pass behavior and Last flag)
        // ============================================================
        $display("\n[CASE 1] Normal YUV420 Flow...");
        base_format = BASE_FMT_YUV420_8;
        send_meta(META_FMT_NV12_Y, 0, 0); send_meta(META_FMT_NV12_Y, 1, 0);
        send_meta(META_FMT_NV12_Y, 0, 1); send_meta(META_FMT_NV12_Y, 1, 1);
        send_meta(META_FMT_NV12_UV, 0, 0); send_meta(META_FMT_NV12_UV, 1, 0);
        #50;

        // ============================================================
        // CASE 2: Abnormal - switch Base Format mid-row (check Error flag)
        // ============================================================
        $display("\n[CASE 2] Abnormal - Base Format changed during row...");
        base_format = BASE_FMT_YUV420_8;
        send_meta(META_FMT_NV12_Y, 0, 0);
        
        #10;
        base_format = BASE_FMT_RGBA8888;
        $display("   !!! Base Format forced to RGBA now !!!");
        
        send_meta(META_FMT_NV12_Y, 1, 0);
        #50;

        // ============================================================
        // CASE 3: Abnormal - coordinate overflow (check Xcoord vs. tile_x mismatch)
        // ============================================================
        $display("\n[CASE 3] Abnormal - Xcoord exceeds tile_x_numbers...");
        rst_n = 0; #10 rst_n = 1; start = 1; #10 start = 0; // Reset and clear the previous error state
        base_format = BASE_FMT_YUV422_8;
        tile_x_numbers = 16'd16;

        send_meta(META_FMT_NV16_Y, 1, 0);
        #50;

        // ============================================================
        // CASE 4: Normal RGBA quick switch
        // ============================================================
        $display("\n[CASE 4] Normal RGBA Single Pass...");
        base_format = BASE_FMT_RGBA8888;
        tile_x_numbers = 16'd32;
        send_meta(META_FMT_RGBA8888, 0, 0); send_meta(META_FMT_RGBA8888, 1, 0);
        
        #100;
        $display("\n--- ALL TEST CASES FINISHED ---");
        $finish;
    end

    // --- Automatic monitor logic ---
    always @(posedge clk) begin
        if (bfifo_we) begin
            $display("TIME:%t | FIFO_W: [PP:%b Err:%b EOL:%b Last:%b Fmt:%02h X:%0d Y:%0d] | SRAM_ADDR:0x%h", 
                      $time, bfifo_wdata[40], bfifo_wdata[39], bfifo_wdata[38], bfifo_wdata[37], bfifo_wdata[36:32], 
                      bfifo_wdata[31:16], bfifo_wdata[15:0], sram_addr);
        end
    end

    // Waveform dump
    initial begin
`ifdef WAVES
`ifdef FSDB
        $fsdbDumpfile("top.fsdb");
        $fsdbDumpvars(0, tb_ubwc_dec_axi_rdata_to_sram);
`else
        $dumpfile("tb_ubwc_dec_axi_rdata_to_sram.vcd");
        $dumpvars(0, tb_ubwc_dec_axi_rdata_to_sram);
`endif
`endif
    end

endmodule
