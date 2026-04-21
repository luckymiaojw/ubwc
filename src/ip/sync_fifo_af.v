//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-03-20  15:19:17
// Design Name       : 
// Module Name       : sync_fifo_af.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//		Revision 1.00 - File Created by		: MiaoJiawang
//		Description							: 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
`default_nettype none

module sync_fifo_af #(
    parameter DATA_WIDTH = 163,
    parameter DEPTH      = 16,
    parameter AF_LEVEL   = 12
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] din,
    output wire                  full,
    output wire                  almost_full,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] dout,
    output wire                  empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH:0]   count;
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    assign full        = (count == DEPTH);
    assign empty       = (count == 0);
    assign almost_full = (count >= AF_LEVEL);
    assign dout        = mem[rd_ptr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {ADDR_WIDTH{1'b0}};
            rd_ptr <= {ADDR_WIDTH{1'b0}};
            count  <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: begin
                    mem[wr_ptr] <= din;
                    if (wr_ptr == DEPTH-1) wr_ptr <= {ADDR_WIDTH{1'b0}};
                    else                   wr_ptr <= wr_ptr + 1'b1;
                    count <= count + 1'b1;
                end
                2'b01: begin
                    if (rd_ptr == DEPTH-1) rd_ptr <= {ADDR_WIDTH{1'b0}};
                    else                   rd_ptr <= rd_ptr + 1'b1;
                    count <= count - 1'b1;
                end
                2'b11: begin
                    mem[wr_ptr] <= din;
                    if (wr_ptr == DEPTH-1) wr_ptr <= {ADDR_WIDTH{1'b0}};
                    else                   wr_ptr <= wr_ptr + 1'b1;
                    if (rd_ptr == DEPTH-1) rd_ptr <= {ADDR_WIDTH{1'b0}};
                    else                   rd_ptr <= rd_ptr + 1'b1;
                end
                default: begin
                end
            endcase
        end
    end

endmodule

`default_nettype wire
