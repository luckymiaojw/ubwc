//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-03-15  15:10:45
// Design Name       : 
// Module Name       : 
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module axi_sram_model #(
    parameter int AXI_ID_WIDTH   = 6,
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 256,
    parameter string DUMP_FILE   = "axi_mem_dump.txt" // 导出的文件名
)(
    input  logic                      aclk,
    input  logic                      aresetn,

    // Write Address Channel (AW)
    input  logic [AXI_ID_WIDTH-1:0]   awid,
    input  logic [AXI_ADDR_WIDTH-1:0] awaddr,
    input  logic [7:0]                awlen,
    input  logic [2:0]                awsize,
    input  logic [1:0]                awburst,
    input  logic                      awvalid,
    output logic                      awready,

    // Write Data Channel (W)
    input  logic [AXI_DATA_WIDTH-1:0] wdata,
    input  logic [(AXI_DATA_WIDTH/8)-1:0] wstrb,
    input  logic                      wlast,
    input  logic                      wvalid,
    output logic                      wready,

    // Write Response Channel (B)
    output logic [AXI_ID_WIDTH-1:0]   bid,
    output logic [1:0]                bresp,
    output logic                      bvalid,
    input  logic                      bready,

    // Read Address Channel (AR)
    input  logic [AXI_ID_WIDTH-1:0]   arid,
    input  logic [AXI_ADDR_WIDTH-1:0] araddr,
    input  logic [7:0]                arlen,
    input  logic [2:0]                arsize,
    input  logic [1:0]                arburst,
    input  logic                      arvalid,
    output logic                      arready,

    // Read Data Channel (R)
    output logic [AXI_ID_WIDTH-1:0]   rid,
    output logic [AXI_DATA_WIDTH-1:0] rdata,
    output logic [1:0]                rresp,
    output logic                      rlast,
    output logic                      rvalid,
    input  logic                      rready
);

    // -------------------------------------------------------------------------
    // Memory Array (Associative array for sparse memory simulation)
    // -------------------------------------------------------------------------
    logic [7:0] mem [longint];

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] BURST_INCR  = 2'b01;
    localparam int NUM_BYTES           = AXI_DATA_WIDTH / 8;

    // -------------------------------------------------------------------------
    // Write FSM & Logic
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} w_state_t;
    w_state_t w_state;

    logic [AXI_ADDR_WIDTH-1:0] w_addr_reg;
    logic [AXI_ID_WIDTH-1:0]   w_id_reg;
    int                        w_bytes_per_transfer;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_state <= W_IDLE;
            awready <= 1'b0;
            wready  <= 1'b0;
            bvalid  <= 1'b0;
            bid     <= '0;
            bresp   <= RESP_OKAY;
        end else begin
            case (w_state)
                W_IDLE: begin
                    awready <= 1'b1;
                    if (awvalid && awready) begin
                        awready <= 1'b0;
                        w_addr_reg <= awaddr;
                        w_id_reg   <= awid;
                        w_bytes_per_transfer <= 1 << awsize;
                        wready  <= 1'b1;
                        w_state <= W_DATA;
                    end
                end

                W_DATA: begin
                    if (wvalid && wready) begin
                        // 根据 wstrb 按字节写入关联数组
                        for (int i = 0; i < NUM_BYTES; i++) begin
                            if (wstrb[i]) begin
                                mem[w_addr_reg + i] = wdata[i*8 +: 8];
                            end
                        end

                        w_addr_reg <= w_addr_reg + w_bytes_per_transfer;

                        if (wlast) begin
                            wready  <= 1'b0;
                            bvalid  <= 1'b1;
                            bid     <= w_id_reg;
                            w_state <= W_RESP;
                        end
                    end
                end

                W_RESP: begin
                    if (bvalid && bready) begin
                        bvalid  <= 1'b0;
                        w_state <= W_IDLE;
                    end
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Read FSM & Logic
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {R_IDLE, R_DATA} r_state_t;
    r_state_t r_state;

    logic [AXI_ADDR_WIDTH-1:0] r_addr_reg;
    logic [7:0]                r_len_reg;
    int                        r_bytes_per_transfer;
    logic [7:0]                r_count;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_state <= R_IDLE;
            arready <= 1'b0;
            rvalid  <= 1'b0;
            rid     <= '0;
            rdata   <= '0;
            rresp   <= RESP_OKAY;
            rlast   <= 1'b0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    arready <= 1'b1;
                    if (arvalid && arready) begin
                        arready <= 1'b0;
                        r_addr_reg <= araddr;
                        rid        <= arid;
                        r_len_reg  <= arlen;
                        r_bytes_per_transfer <= 1 << arsize;
                        r_count    <= '0;
                        r_state    <= R_DATA;
                    end
                end

                R_DATA: begin
                    logic [AXI_DATA_WIDTH-1:0] tmp_data;
                    tmp_data = '0;
                    for (int i = 0; i < NUM_BYTES; i++) begin
                        if (mem.exists(r_addr_reg + i)) begin
                            tmp_data[i*8 +: 8] = mem[r_addr_reg + i];
                        end else begin
                            tmp_data[i*8 +: 8] = 8'h00; 
                        end
                    end

                    rdata  <= tmp_data;
                    rvalid <= 1'b1;
                    rlast  <= (r_count == r_len_reg);

                    if (rvalid && rready) begin
                        r_addr_reg <= r_addr_reg + r_bytes_per_transfer;
                        r_count    <= r_count + 1;
                        
                        if (rlast) begin
                            rvalid  <= 1'b0;
                            rlast   <= 1'b0;
                            r_state <= R_IDLE;
                        end
                    end
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 仿真结束时自动导出数据到 TXT
    // -------------------------------------------------------------------------
    task automatic dump_to_txt(string filename);
        int fd;
        longint addr;
        longint aligned_addr;
        logic [AXI_DATA_WIDTH-1:0] line_data;
        
        // 步骤 1：找出所有被写过的、按 AXI_DATA_WIDTH 对齐的首地址
        bit populated_lines [longint];
        
        if (mem.first(addr)) begin
            do begin
                aligned_addr = addr & ~(NUM_BYTES - 1);
                populated_lines[aligned_addr] = 1;
            end while (mem.next(addr));
        end
        
        // 步骤 2：遍历这些有效对齐地址，将离散的 byte 拼成完整 word 写入文件
        fd = $fopen(filename, "w");
        if (fd) begin
            if (populated_lines.first(aligned_addr)) begin
                do begin
                    line_data = '0; // 默认填 0
                    for (int i = 0; i < NUM_BYTES; i++) begin
                        if (mem.exists(aligned_addr + i)) begin
                            line_data[i*8 +: 8] = mem[aligned_addr + i];
                        end
                    end
                    // 输出格式：@地址(16进制) 数据(16进制)
                    $fdisplay(fd, "@%08X %x", aligned_addr, line_data);
                end while (populated_lines.next(aligned_addr));
            end
            $fclose(fd);
            $display("==================================================");
            $display("[AXI SRAM] 内存数据已成功导出至: %s", filename);
            $display("==================================================");
        end else begin
            $error("[AXI SRAM] 无法打开文件 %s 进行写入！", filename);
        end
    endtask

    // 当 Testbench 调用 $finish 时，自动触发此 block
    final begin
        dump_to_txt(DUMP_FILE);
    end

endmodule
