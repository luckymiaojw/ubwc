`timescale 1ns/1ps

module ubwc_std_single_port_sram #(
    parameter integer DATA_W = 64,
    parameter integer ADDR_W = 12,
    parameter integer DEPTH  = (1 << ADDR_W)
)(
    input  wire                clk,
    input  wire                cs,
    input  wire                we,
    input  wire [ADDR_W-1:0]   addr,
    input  wire [DATA_W-1:0]   din,
    output reg  [DATA_W-1:0]   dout
);

    reg [DATA_W-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (cs) begin
            if (we) begin
                mem[addr] <= din;
            end else begin
                dout <= mem[addr];
            end
        end
    end

endmodule
