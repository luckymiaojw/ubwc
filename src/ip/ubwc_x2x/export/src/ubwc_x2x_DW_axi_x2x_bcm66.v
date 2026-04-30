
// ------------------------------------------------------------------------------
// 
// Copyright 2006 - 2020 Synopsys, INC.
// 
// This Synopsys IP and all associated documentation are proprietary to
// Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
// written license agreement with Synopsys, Inc. All other use, reproduction,
// modification, or distribution of the Synopsys IP or the associated
// documentation is strictly prohibited.
// 
// Component Name   : DW_axi_x2x
// Component Version: 1.08a
// Release Type     : GA
// ------------------------------------------------------------------------------

//
// Filename    : DW_axi_x2x_bcm66.v
// Revision    : $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_bcm66.v#11 $
// Author      : Doug Lee       9/3/04
// Description : DW_axi_x2x_bcm66.v Verilog module for DW_axi_x2x
//
// DesignWare IP ID: c28ccdc8
//
////////////////////////////////////////////////////////////////////////////////



module ubwc_x2x_DW_axi_x2x_bcm66(
                clk_push,
                rst_push_n,
                init_push_n,
                push_req_n,
                data_in,
                push_empty,
                push_ae,
                push_hf,
                push_af,
                push_full,
                push_error,
                push_word_count,

                clk_pop,
                rst_pop_n,
                init_pop_n,
                pop_req_n,
                pop_empty,
                pop_ae,
                pop_hf,
                pop_af,
                pop_full,
                pop_error,
                pop_word_count,
                data_out
                );

parameter WIDTH = 8;            // RANGE 1 to 2048
parameter DEPTH = 8;            // RANGE 2 to 1024
parameter ADDR_WIDTH = 3;       // RANGE 1 to 8
parameter COUNT_WIDTH = 4;      // RANGE 2 to 9
parameter PUSH_AE_LVL = 2;      // RANGE 1 to DEPTH-1
parameter PUSH_AF_LVL = 2;      // RANGE 1 to DEPTH-1
parameter POP_AE_LVL = 2;       // RANGE 1 to DEPTH-1
parameter POP_AF_LVL = 2;       // RANGE 1 to DEPTH-1
parameter ERR_MODE = 0;         // RANGE 0 to 1
parameter PUSH_SYNC = 2;        // RANGE 1 to 4
parameter POP_SYNC = 2;         // RANGE 1 to 4
parameter RST_MODE = 0;         // RANGE 0 to 1
parameter VERIF_EN = 1;         // RANGE 0 to 5
parameter MEM_MODE = 0;         // RANGE 0 to 7

localparam CTRLR_MEM_MODE = MEM_MODE >> 1;
   
localparam MEM_DEPTH  =  (DEPTH == (1<<ADDR_WIDTH))? DEPTH : DEPTH + (((DEPTH % 2) == 1)? 1 : 2);

   input                       clk_push;         // push domain clock input
   input                       rst_push_n;       // push domain async. reset
   input                       init_push_n;      // push domain sync. reset
   input                       push_req_n;       // push domain push request
   input [WIDTH-1:0]           data_in;          // FIFO input data bus (push domain)
   output                      push_empty;       // push domain empty status flag
   output                      push_ae;          // push domain almost empty status flag
   output                      push_hf;          // push domain half full status flag
   output                      push_af;          // push domain almost full status flag
   output                      push_full;        // push domain full status flag
   output                      push_error;       // push domain error status flag
   output [COUNT_WIDTH-1:0]    push_word_count;  // push domain FIFO word count

   input                       clk_pop;          // pop domain clock input
   input                       rst_pop_n;        // pop domain async. reset
   input                       init_pop_n;       // pop domain sync. reset
   input                       pop_req_n;        // pop domain pop request
   output                      pop_empty;        // pop domain empty status flag
   output                      pop_ae;           // pop domain almost empty status flag
   output                      pop_hf;           // pop domain half full status flag
   output                      pop_af;           // pop domain almost full status flag
   output                      pop_full;         // pop domain full status flag
   output                      pop_error;        // pop domain error status flag
   output [COUNT_WIDTH-1:0]    pop_word_count;   // pop domain FIFO word count
   output [WIDTH-1:0]          data_out;         // FIFO input data bus (pop domain)
wire [ADDR_WIDTH-1 : 0] wr_addr_int;
wire [ADDR_WIDTH-1 : 0] rd_addr_int;
wire [WIDTH-1 : 0]      pre_data_out;

wire we_n_int;
wire rd_n_int;
wire pop_empty_int;
wire a_mem_rst_w_n;
wire a_mem_rst_r_n;
   
generate
  if (RST_MODE == 0) begin : GEN_MEM_RST_RM0
    assign a_mem_rst_w_n = rst_push_n;
    assign a_mem_rst_r_n = rst_pop_n;
  end else begin : GEN_MEM_RST_RM_NE_0
    assign a_mem_rst_w_n = 1'b1;
    assign a_mem_rst_r_n = 1'b1;
  end
endgenerate

   
    // Instance of DW_axi_x2x_bcm07
   ubwc_x2x_DW_axi_x2x_bcm07
    #( 
                       DEPTH, 
                       ADDR_WIDTH,
                       COUNT_WIDTH,
                       PUSH_AE_LVL,
                       PUSH_AF_LVL, 
                       POP_AE_LVL,
                       POP_AF_LVL,
                       ERR_MODE, 
                       PUSH_SYNC, 
                       POP_SYNC,  
                       0,
                       0,
                       CTRLR_MEM_MODE,
                       VERIF_EN
                       )
      U_FIFO_CTL ( 
          .clk_push(clk_push), 
          .rst_push_n(rst_push_n), 
          .init_push_n(init_push_n), 
          .push_req_n(push_req_n), 
          .pop_req_n(pop_req_n), 
          .push_empty(push_empty), 
          .push_ae(push_ae),
          .push_hf(push_hf), 
          .push_af(push_af), 
          .push_full(push_full), 
          .push_error(push_error), 
          .push_word_count(push_word_count),
          .we_n(we_n_int),
          .wr_addr(wr_addr_int), 

          .clk_pop(clk_pop), 
          .rst_pop_n(rst_pop_n), 
          .init_pop_n(init_pop_n), 
          .pop_empty(pop_empty_int), 
          .pop_ae(pop_ae), 
          .pop_hf(pop_hf), 
          .pop_af(pop_af), 
          .pop_full(pop_full), 
          .pop_error(pop_error),
          .pop_word_count(pop_word_count),
          .rd_addr(rd_addr_int) );

     assign rd_n_int = pop_req_n | pop_empty;

     ubwc_x2x_DW_axi_x2x_bcm58
      #(
                        WIDTH, 
                        MEM_DEPTH, 
                        ADDR_WIDTH,
                        MEM_MODE,
                        0 )
           U_FIFO_MEM ( 
                .clk_w(clk_push), 
                .rst_w_n(a_mem_rst_w_n), 
                .en_w_n(we_n_int), 
                .data_w(data_in), 
                .addr_w(wr_addr_int), 

                .clk_r(clk_pop),
                .rst_r_n(a_mem_rst_r_n),
                .en_r_n(rd_n_int), 
                .addr_r(rd_addr_int), 
// spyglass disable_block W287b
// SMD: An output port of module or gate instance is not connected
// SJ: The following port(s) of this instance are intentionally unconnected.
                .data_r_a(),
// spyglass enable_block W287b
                .data_r(pre_data_out) );


    assign data_out = (pop_empty_int == 1'b0)? pre_data_out : {WIDTH{1'b0}};
    assign pop_empty = pop_empty_int;

endmodule
