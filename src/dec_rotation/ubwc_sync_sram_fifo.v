//////////////////////////////////////////////////////////////////////////////////
// -------------------------------------------------------------------------------
// Copyright (c) 2014-2026 All rights reserved
// -------------------------------------------------------------------------------
// Company           : MagicIP
// Engineer          : jiawang.miao magic.jw@magicip.com.cn
// Create Date       : 2026-06-21
// Module Name       : ubwc_sync_sram_fifo.v
// Description       : Synchronous show-ahead FIFO backed by pseudo dual-port SRAM
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module ubwc_sync_sram_fifo #(
    parameter                                       PROG_DEPTH                     = 4,
    parameter                                       DWIDTH                         = 8,
    parameter                                       DEPTH                          = 32,
    parameter                                       AWIDTH                         = 5,
    parameter                                       CWIDTH                         = AWIDTH + 1
)(
    input   wire                                        clk                             ,
    input   wire                                        rst_n                           ,
    input   wire                                        clear                           ,

    input   wire                                        wr_en                           ,
    input   wire    [DWIDTH              -1 :0]         din                             ,
    output  reg                                         prog_full                       ,
    output  reg                                         full                            ,

    input   wire                                        rd_en                           ,
    output  reg                                         empty                           ,
    output  wire    [DWIDTH              -1 :0]         dout                            ,
    output  reg                                         valid                           ,

    output  reg     [CWIDTH              -1 :0]         data_count
);

    localparam  [AWIDTH              -1 :0]         ADDR_ZERO                       = {AWIDTH{1'b0}};
    localparam  [AWIDTH              -1 :0]         ADDR_LAST                       = AWIDTH'(DEPTH - 1);
    localparam  [CWIDTH              -1 :0]         COUNT_ZERO                      = {CWIDTH{1'b0}};
    localparam  [CWIDTH              -1 :0]         COUNT_ONE                       = {{(CWIDTH-1){1'b0}}, 1'b1};
    localparam  [CWIDTH              -1 :0]         COUNT_DEPTH                     = CWIDTH'(DEPTH);
    localparam  [CWIDTH              -1 :0]         PROG_FULL_LEVEL                 = CWIDTH'(DEPTH - PROG_DEPTH);

    wire                                            write_fire                      ;
    wire                                            pop_fire                        ;
    wire                                            ram_read_fire                   ;
    wire                                            fifo_has_mem_data               ;
    wire        [CWIDTH              -1 :0]         out_slot_count                  ;
    wire        [CWIDTH              -1 :0]         mem_entry_count                 ;
    wire        [AWIDTH              -1 :0]         waddr_next                      ;
    wire        [AWIDTH              -1 :0]         raddr_next                      ;

    reg         [AWIDTH              -1 :0]         waddr                           ;
    reg         [AWIDTH              -1 :0]         raddr                           ;
    reg                                             read_pending                    ;
    reg         [DWIDTH              -1 :0]         q_buf                           ;

    wire        [DWIDTH              -1 :0]         ram_rdata                       ;

    assign write_fire                  = wr_en && !full;
    assign pop_fire                    = rd_en && valid;
    assign out_slot_count              = {{(CWIDTH-1){1'b0}}, valid} +
                                         {{(CWIDTH-1){1'b0}}, read_pending};
    assign mem_entry_count             = data_count - out_slot_count;
    assign fifo_has_mem_data           = (mem_entry_count != COUNT_ZERO);
    assign ram_read_fire               = !read_pending && fifo_has_mem_data &&
                                         (!valid || pop_fire);
    assign waddr_next                  = (waddr == ADDR_LAST) ? ADDR_ZERO :
                                                                    (waddr + AWIDTH'(1));
    assign raddr_next                  = (raddr == ADDR_LAST) ? ADDR_ZERO :
                                                                    (raddr + AWIDTH'(1));
    assign dout                        = q_buf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            waddr <= ADDR_ZERO;
        else if (clear)
            waddr <= ADDR_ZERO;
        else if (write_fire)
            waddr <= waddr_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            raddr <= ADDR_ZERO;
        else if (clear)
            raddr <= ADDR_ZERO;
        else if (ram_read_fire)
            raddr <= raddr_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_count <= COUNT_ZERO;
        else if (clear)
            data_count <= COUNT_ZERO;
        else if (write_fire && !pop_fire)
            data_count <= data_count + COUNT_ONE;
        else if (!write_fire && pop_fire)
            data_count <= data_count - COUNT_ONE;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            full <= 1'b0;
        else if (clear)
            full <= 1'b0;
        else if (write_fire && !pop_fire)
            full <= (data_count == (COUNT_DEPTH - COUNT_ONE));
        else if (!write_fire && pop_fire)
            full <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            prog_full <= 1'b0;
        else if (clear)
            prog_full <= 1'b0;
        else
            prog_full <= (data_count >= PROG_FULL_LEVEL);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            empty <= 1'b1;
        else if (clear)
            empty <= 1'b1;
        else if (write_fire && !pop_fire)
            empty <= 1'b0;
        else if (!write_fire && pop_fire)
            empty <= (data_count == COUNT_ONE);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            read_pending <= 1'b0;
        else if (clear)
            read_pending <= 1'b0;
        else
            read_pending <= ram_read_fire;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid <= 1'b0;
        else if (clear)
            valid <= 1'b0;
        else if (read_pending)
            valid <= 1'b1;
        else if (pop_fire)
            valid <= 1'b0;
    end

    always @(posedge clk) begin
        if (read_pending)
            q_buf <= ram_rdata;
    end

    sram_pdp_8192x128 #(
        .DATA_WIDTH                     ( DWIDTH                                ),
        .ADDR_WIDTH                     ( AWIDTH                                ),
        .DEPTH                          ( DEPTH                                 )
    ) u_data_sram (
        .clk                            ( clk                                   ),
        .wen                            ( write_fire                            ),
        .waddr                          ( waddr                                 ),
        .wdata                          ( din                                   ),
        .ren                            ( ram_read_fire                         ),
        .raddr                          ( raddr                                 ),
        .rdata                          ( ram_rdata                             )
    );

endmodule
