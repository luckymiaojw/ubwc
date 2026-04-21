//////////////////////////////////////////////////////////////////////////////////
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Module Name       : sync_fifo.v
// Description       : Generic synchronous FIFO with parameterized width and depth
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module sync_fifo #(
    parameter DATA_WIDTH = 40,
    parameter DEPTH      = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   clr,

    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  din,
    output wire                   full,

    input  wire                   rd_en,
    output wire [DATA_WIDTH-1:0]  dout,
    output wire                   empty
);

    localparam ADDR_PTR = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_PTR:0] wr_ptr;
    reg [ADDR_PTR:0] rd_ptr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {(ADDR_PTR+1){1'b0}};
        end else if (clr) begin
            wr_ptr <= {(ADDR_PTR+1){1'b0}};
        end else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_PTR-1:0]] <= din;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= {(ADDR_PTR+1){1'b0}};
        end else if (clr) begin
            rd_ptr <= {(ADDR_PTR+1){1'b0}};
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    assign dout  = mem[rd_ptr[ADDR_PTR-1:0]];
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_PTR] != rd_ptr[ADDR_PTR]) &&
                   (wr_ptr[ADDR_PTR-1:0] == rd_ptr[ADDR_PTR-1:0]);

endmodule
