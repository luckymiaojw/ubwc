//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-03-28  17:29:56
// Design Name       : 
// Module Name       : tb_ubwc_enc_meta_get_cmd_gen.sv
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module tb_ubwc_enc_meta_get_cmd_gen();

    parameter ADDR_WIDTH = 32;
    localparam [4:0] BASE_FMT_RGBA8888    = 5'b00000;
    localparam [4:0] BASE_FMT_RGBA1010102 = 5'b00001;
    localparam [4:0] BASE_FMT_YUV420_8    = 5'b00010;
    localparam [4:0] BASE_FMT_YUV420_10   = 5'b00011;
    localparam [4:0] BASE_FMT_YUV422_8    = 5'b00100;
    localparam [4:0] BASE_FMT_YUV422_10   = 5'b00101;

    reg                   clk;
    reg                   rst_n;
    reg                   start;
    reg  [4:0]            base_format;
    
    reg  [ADDR_WIDTH-1:0] meta_base_addr_rgba_uv;
    reg  [ADDR_WIDTH-1:0] meta_base_addr_y;
    
    reg  [15:0]           tile_x_numbers;
    reg  [15:0]           tile_y_numbers;

    wire                  cmd_valid;
    reg                   cmd_ready;
    wire [ADDR_WIDTH-1:0] cmd_addr;
    wire [7:0]            cmd_len;

    wire                  meta_valid;
    reg                   meta_ready;
    wire [4:0]            meta_format;
    wire [15:0]           meta_xcoord;
    wire [15:0]           meta_ycoord;

    ubwc_enc_meta_get_cmd_gen#(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .base_format(base_format),
        .meta_base_addr_rgba_uv(meta_base_addr_rgba_uv),
        .meta_base_addr_y(meta_base_addr_y),
        .tile_x_numbers(tile_x_numbers),
        .tile_y_numbers(tile_y_numbers),
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
      
        .cmd_addr(cmd_addr),
        .cmd_len(cmd_len),
        .meta_valid(meta_valid),
        .meta_ready(meta_ready),
        .meta_format(meta_format),
        .meta_xcoord(meta_xcoord),
        .meta_ycoord(meta_ycoord)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // ============================================================
    // Main stimulus flow
    // ============================================================
    initial begin
        rst_n = 0;
        start = 0;
        cmd_ready = 1;  
        // meta_ready is driven by the random backpressure logic below

        meta_base_addr_rgba_uv = 32'h1000_0000;
        meta_base_addr_y       = 32'h2000_0000;

        // Global tile resolution: 129 columns x 65 rows
        tile_x_numbers = 16'd129; 
        tile_y_numbers = 16'd65;

        #25 rst_n = 1;
        #10;

        // -----------------------------------------------------------
        // Test Case 1: RGBA8888 
        // -----------------------------------------------------------
        $display("\n==============================================");
        $display("--- TEST 1: RGBA8888 SCANNING (129 x 65) ---");
        $display("==============================================");
        base_format = BASE_FMT_RGBA8888;
        start = 1;
        #10 start = 0;
        wait (dut.state == 8); // Wait for S_DONE
        
        $display(">>> [FRAME DONE] Waiting 1us... <<<");
        #1000; // Frame interval: 1us (1000ns)

        // -----------------------------------------------------------
        // Test Case 2: RGBA1010102
        // -----------------------------------------------------------
        $display("\n==============================================");
        $display("--- TEST 2: RGBA1010102 SCANNING (129 x 65) ---");
        $display("==============================================");
        base_format = BASE_FMT_RGBA1010102;
        start = 1;
        #10 start = 0;
        wait (dut.state == 8); 
        
        $display(">>> [FRAME DONE] Waiting 1us... <<<");
        #1000; // Frame interval: 1us (1000ns)

        // -----------------------------------------------------------
        // Test Case 3: YUV422
        // -----------------------------------------------------------
        $display("\n==============================================");
        $display("--- TEST 3: YUV422 SCANNING (129 x 65) ---");
        $display("==============================================");
        base_format = BASE_FMT_YUV422_8;
        start = 1;
        #10 start = 0;
        wait (dut.state == 8); 
        
        $display(">>> [FRAME DONE] Waiting 1us... <<<");
        #1000; // Frame interval: 1us (1000ns)

        // -----------------------------------------------------------
        // Test Case 4: YUV420
        // -----------------------------------------------------------
        $display("\n==============================================");
        $display("--- TEST 4: YUV420 SCANNING (129 x 65) ---");
        $display("==============================================");
        base_format = BASE_FMT_YUV420_8;
        start = 1;
        #10 start = 0;
        wait (dut.state == 8); 
        
        $display(">>> [FRAME DONE] Waiting 1us... <<<");
        #1000;

        $display("\n==============================================");
        $display("--- TEST 5: P010 SCANNING (129 x 65) ---");
        $display("==============================================");
        base_format = BASE_FMT_YUV420_10;
        start = 1;
        #10 start = 0;
        wait (dut.state == 8); 
        
        $display(">>> [FRAME DONE] Waiting 1us... <<<");
        #1000;

        $display("\n==============================================");
        $display("--- TEST 6: YUV422 10BIT SCANNING (129 x 65) ---");
        $display("==============================================");
        base_format = BASE_FMT_YUV422_10;
        start = 1;
        #10 start = 0;
        wait (dut.state == 8); 
        
        $display(">>> [FRAME DONE] Waiting 1us... <<<");
        #1000; // Frame interval: 1us (1000ns)

        $display("\n--- ALL SIMULATIONS COMPLETE ---");
        $finish;
    end

    // ============================================================
    // Log monitor
    // ============================================================
    always @(posedge clk) begin
        if (meta_valid && meta_ready) begin
            $display(">> [%0t ns] [META] Format: %b | Coord: (X=%0d, Y=%0d)", 
                     $time, meta_format, meta_xcoord, meta_ycoord);
        end
        if (cmd_valid && cmd_ready) begin
            $display("   [CMD]  Addr: 0x%0h", cmd_addr);
        end
    end

    // ============================================================
    // Random meta_ready backpressure control
    // Force ready low for 1~10 cycles after every 16 successful handshakes
    // ============================================================
    integer meta_handshake_cnt = 0;
    integer wait_cycles = 0;

    initial begin
        meta_ready = 1; // Initially ready to accept data
        forever begin
            @(posedge clk);
            
            // Count a transfer only when valid and ready are both high
            if (meta_valid && meta_ready) begin
                meta_handshake_cnt = meta_handshake_cnt + 1;
                
                // Once 16 transfers have been accepted
                if (meta_handshake_cnt == 16) begin
                    meta_ready <= 0; // Force ready low to emulate downstream FIFO full
                    
                    // Generate a random stall length from 1 to 10 cycles
                    wait_cycles = $urandom_range(1, 10);
                    $display("------------------------------------------------------------------");
                    $display(">>> [TB INJECT] 16 META entries accepted, forcing meta_ready low for %0d cycles <<<", wait_cycles);
                    $display("------------------------------------------------------------------");
                    
                    // Block for the randomized number of cycles
                    repeat(wait_cycles) @(posedge clk);
                    
                    // Restore ready and clear the counter for the next round
                    meta_ready <= 1; 
                    meta_handshake_cnt = 0; 
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Waveform Dumping
    // ------------------------------------------------------------
    initial begin
`ifdef WAVES
`ifdef FSDB
        $display("Dumping Waveform for DEBUG is active !!!");
        $fsdbAutoSwitchDumpfile(10000,"top.fsdb",20);
        $fsdbDumpfile("top.fsdb");
        $fsdbDumpMDA(0, tb_ubwc_enc_meta_get_cmd_gen);
        $fsdbDumpSVA(0, tb_ubwc_enc_meta_get_cmd_gen);
        $fsdbDumpvars(0, tb_ubwc_enc_meta_get_cmd_gen);
`endif
`endif
    end

endmodule
