//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-03-15  21:28:25
// Design Name       : 
// Module Name       : 
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_sync_fifo_fwft #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16
)(
    input  logic                    clk,
    input  logic                    rstn,

    // Push Interface (Write)
    input  logic                    i_push_valid,
    output logic                    o_push_ready,
    input  logic [DATA_WIDTH-1:0]   i_push_data,

    // Pop Interface (Read)
    output logic                    o_pop_valid,
    input  logic                    i_pop_ready,
    output logic [DATA_WIDTH-1:0]   o_pop_data
);

    localparam ADDR_W = $clog2(DEPTH);
    
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_W:0]       wr_ptr, rd_ptr;
    
    wire empty = (wr_ptr == rd_ptr);
    wire full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) && (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);

    // 内部普通 FIFO 写逻辑
    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            wr_ptr <= '0;
        end else if (i_push_valid && o_push_ready) begin
            mem[wr_ptr[ADDR_W-1:0]] <= i_push_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // 内部普通 FIFO 读逻辑
    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            rd_ptr <= '0;
        end else if (!empty && o_pop_valid && i_pop_ready) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    // FWFT 读出数据逻辑 (直接看下一个要读的数据)
    assign o_push_ready = ~full;
    assign o_pop_valid  = ~empty;
    assign o_pop_data   = mem[rd_ptr[ADDR_W-1:0]];

endmodule
