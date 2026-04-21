`timescale 1ns / 1ps

// Pseudo dual-port SRAM (1 write port, 1 read port)
module sram_pdp_8192x128 #(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 13,
    parameter DEPTH      = 8192
)(
    input  wire                   clk,
    
    // Write Port
    input  wire                   wen,
    input  wire [ADDR_WIDTH-1:0]  waddr,
    input  wire [DATA_WIDTH-1:0]  wdata,
    
    // Read Port
    input  wire                   ren,
    input  wire [ADDR_WIDTH-1:0]  raddr,
    output reg  [DATA_WIDTH-1:0]  rdata
);

    // Internal memory array
    // Synthesis hint: prefer block RAM
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write path (synchronous write)
    always @(posedge clk) begin
        if (wen) begin
            mem[waddr] <= wdata;
        end
    end

    // Read path (synchronous read, 1-cycle latency)
    always @(posedge clk) begin
        if (ren) begin
            rdata <= mem[raddr];
        end
    end

endmodule
