//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-03-15  19:50:26
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

module ubwc_sram_1rw #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 13 // Supports up to 256 macroblocks * 32 beats = 8192 words
)(
    input  wire                     i_clk   ,
    input  wire                     i_cs    , // Chip Select
    input  wire                     i_we    , // 1: Write, 0: Read
    input  wire [ADDR_WIDTH-1:0]    i_addr  , 
    input  wire [DATA_WIDTH-1:0]    i_wdata , 
    output logic [DATA_WIDTH-1:0]   o_rdata   
);

    // Replace with the vendor-provided 64-bit single-port SRAM macro for synthesis
    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always_ff @(posedge i_clk) begin
        if (i_cs) begin
            if (i_we) begin
                mem[i_addr] <= i_wdata;
            end else begin
                o_rdata <= mem[i_addr];
            end
        end
    end

endmodule
