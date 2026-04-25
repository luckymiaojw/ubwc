//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : MiaoJiawang magic.jw@magicip.com.cn
// Create Date       : 2026-04-24  03:49:19
// Module Name       : mg_sync_fifo.v
// Editor            : Gvim, tab size (4)
// Revision          : 1.00
//      Revision 1.00 - File Created by        : MiaoJiawang
//      Description                            :
//
//////////////////////////////////////////////////////////////////////////////////
//`timescale 1ns/1ps

module mg_sync_fifo
    #(
        parameter   PROG_DEPTH  = 4,
        parameter   DWIDTH      = 8,
        parameter   DEPTH       = 256,
        parameter   SHOW_AHEAD  = 0,
        parameter   RAM_STYLE   = "block",
        parameter   AWIDTH      = log2(DEPTH)
    )(
    // system signal
        input   wire                    clk,
        input   wire                    rst_n,

    // write
        input   wire                    wr_en,
        input   wire    [DWIDTH-1:0]    din,
        output  reg                     prog_full,
        output  reg                     full,

    // read
        input   wire                    rd_en,
        output  reg                     empty,
        output  wire    [DWIDTH-1:0]    dout,
        output  reg                     valid,

    // used words
        output  reg     [AWIDTH-1:0]    data_count
    );

    (* ramstyle = RAM_STYLE *)
    reg     [DWIDTH-1:0]    mem[0:DEPTH-1];
    reg     [DWIDTH-1:0]    q_buf = {DWIDTH{1'b0}};
    reg     [AWIDTH-1:0]    waddr;
    reg     [AWIDTH-1:0]    raddr;
    wire    [AWIDTH-1:0]    wnext;
    wire    [AWIDTH-1:0]    rnext;

    function integer log2;
        input  [31:0] value;
        reg    [31:0] tmp;
        begin
            tmp = value;
            for (log2 = 0; tmp > 0; log2 = log2 + 1)
                tmp = tmp >> 1;
        end
    endfunction

    assign wnext = !(~full & wr_en) ? waddr :
                   (waddr == DEPTH - 1) ? 1'b0 :
                   waddr + 1'b1;
    assign rnext = !(~empty & rd_en) ? raddr :
                   (raddr == DEPTH - 1) ? 1'b0 :
                   raddr + 1'b1;

    always @(posedge clk) begin
        if (~rst_n)
            waddr <= 1'b0;
        else
            waddr <= wnext;
    end

    always @(posedge clk) begin
        if (~rst_n)
            raddr <= 1'b0;
        else
            raddr <= rnext;
    end

    always @(posedge clk) begin
        if (~rst_n)
            data_count <= 1'b0;
        else if ((~full & wr_en) & ~(~empty & rd_en))
            data_count <= data_count + 1'b1;
        else if (~(~full & wr_en) & (~empty & rd_en))
            data_count <= data_count - 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            full <= 1'b0;
        else if ((~full & wr_en) & ~(~empty & rd_en))
            full <= (data_count == DEPTH - 1);
        else if (~(~full & wr_en) & (~empty & rd_en))
            full <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            prog_full <= 1'b0;
        else
            prog_full <= (data_count >= DEPTH - PROG_DEPTH - 1) ? 1'b1 : 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            empty <= 1'b1;
        else if ((~full & wr_en) & ~(~empty & rd_en))
            empty <= 1'b0;
        else if (~(~full & wr_en) & (~empty & rd_en))
            empty <= (data_count == 1'b1);
    end

    integer a;
    always @(posedge clk) begin
`ifdef SIMULATION
        if (~rst_n) begin
            for (a = 0; a < DEPTH; a = a + 1)
                mem[a] <= {DWIDTH{1'b0}};
        end else
`endif
        if (~full & wr_en)
            mem[waddr] <= din;
    end

    generate
        if (SHOW_AHEAD) begin : gen_show_ahead_q
            reg [DWIDTH-1:0] q_tmp = {DWIDTH{1'b0}};
            reg              show_ahead;

            assign dout = show_ahead ? q_tmp : q_buf;

            always @(posedge clk) begin
                q_buf <= mem[rnext];
            end

            always @(*) begin
                valid <= ~empty;
            end

            always @(posedge clk) begin
                if (~full & wr_en)
                    q_tmp <= din;
            end

            always @(posedge clk) begin
                if (~rst_n)
                    show_ahead <= 1'b0;
                else if (~full & wr_en)
                    show_ahead <= (waddr == rnext);
                else
                    show_ahead <= 1'b0;
            end
        end else begin : gen_normal_q
            assign dout = q_buf;

            always @(posedge clk) begin
                if (~empty & rd_en) begin
                    q_buf <= mem[raddr];
                    valid <= 1'b1;
                end else begin
                    valid <= 1'b0;
                end
            end
        end
    endgenerate

endmodule
