//////////////////////////////////////////////////////////////////////////////////
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Module Name       : ubwc_meta_simple_fifo.v
// Description       : Simple synchronous FIFO with a prog_full threshold
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_meta_simple_fifo #(
    parameter DWIDTH = 23,
    parameter AWIDTH = 9,
    parameter PROG_FULL_LEVEL = ((1 << AWIDTH) - 16)
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              we,
    input  wire [DWIDTH-1:0] din,
    input  wire              re,
    output wire [DWIDTH-1:0] dout,
    output wire              empty,
    output wire              full,
    output wire              prog_full
);

    reg [DWIDTH-1:0] mem [0:(1<<AWIDTH)-1];
    reg [AWIDTH:0] waddr;
    reg [AWIDTH:0] raddr;
    wire [AWIDTH:0] count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            waddr <= {(AWIDTH+1){1'b0}};
        end else if (we && !full) begin
            waddr <= waddr + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raddr <= {(AWIDTH+1){1'b0}};
        end else if (re && !empty) begin
            raddr <= raddr + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (we && !full) begin
            mem[waddr[AWIDTH-1:0]] <= din;
        end
    end

    assign dout      = mem[raddr[AWIDTH-1:0]];
    assign empty     = (waddr == raddr);
    assign full      = (waddr[AWIDTH-1:0] == raddr[AWIDTH-1:0]) && (waddr[AWIDTH] != raddr[AWIDTH]);
    assign count     = waddr - raddr;
    assign prog_full = (count >= PROG_FULL_LEVEL[AWIDTH:0]);

endmodule
