
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
// Filename    : DW_axi_x2x_bcm58.v
// Revision    : $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_bcm58.v#1 $
// Author      : Rick Kelly     11/03/06
// Description : DW_axi_x2x_bcm58.v Verilog module for DW_axi_x2x
//
// DesignWare IP ID: ea3d11d3
//
////////////////////////////////////////////////////////////////////////////////






module ubwc_x2x_DW_axi_x2x_bcm58 (
        clk_w,          // Write clock input
        rst_w_n,        // write domain active low asynch. reset
        en_w_n,         // acive low write enable
        addr_w,         // Write address input
        data_w,         // Write data input

        clk_r,          // Read clock input
        rst_r_n,        // read domain active low asynch. reset
        en_r_n,         // acive low read enable
        addr_r,         // Read address input
        data_r_a,       // Read data arrival status output
        data_r          // Read data output
);

parameter WIDTH = 8;    // RANGE 1 to 2048
parameter DEPTH = 4;    // RANGE 2 to 1024
parameter ADDR_WIDTH = 2; // RANGE 1 to 10
parameter MEM_MODE = 1; // RANGE 0 to 7
parameter RST_MODE = 0; // RANGE 0 to 1

 input                          clk_w;
// spyglass disable_block W240
// SMD: An input port is never read in the module
// SJ: The following port(s) are not used in certain configurations.
 input                          rst_w_n;
// spyglass enable_block W240
 input                          en_w_n;
 input [ADDR_WIDTH-1 : 0]       addr_w;
 input [WIDTH-1 : 0]            data_w;

// spyglass disable_block W240
// SMD: An input port is never read in the module
// SJ: The following port(s) are not used in certain configurations.
 input                          clk_r;
 input                          rst_r_n;
// spyglass enable_block W240
 input                          en_r_n;
 input [ADDR_WIDTH-1 : 0]       addr_r;
output                          data_r_a;
output [WIDTH-1 : 0]            data_r;



 reg [(DEPTH*WIDTH)-1 : 0]      mem_array;
 reg [(DEPTH*WIDTH)-1 : 0]      mem_array_nxt;

wire [ADDR_WIDTH-1 : 0] addr_w_array;
wire                    en_w_array;
wire [WIDTH-1 : 0]      data_w_array;
wire [ADDR_WIDTH-1 : 0] addr_r_array;
wire [WIDTH-1 : 0]      rd_data_array;

  

// spyglass disable_block STARC-2.3.4.3
// SMD: A flip-flop should have an asynchronous set or an asynchronous reset
// SJ: This module can be specifically configured/implemented with only a synchronous reset or no resets at all.
// spyglass disable_block W415a
// SMD: Signal may be multiply assigned (beside initialization) in the same scope
// SJ: The design checked and verified that not any one of a single bit of the bus is assigned more than once beside initialization or the multiple assignments are intentional.
// spyglass disable_block Ac_conv04
// SMD: Checks all the control-bus clock domain crossings which do not follow gray encoding
// SJ: The clock domain crossing bus is between the register file and the read-mux of a RAM, which do not need a gray encoding.

generate
  if (RST_MODE == 0) begin : GEN_RM0W
    always @ (posedge clk_w or negedge rst_w_n) begin : clk_regs_PROC
      if (rst_w_n == 1'b0)
        mem_array <= {WIDTH*DEPTH{1'b0}};
      else if (en_w_array == 1'b1)
        mem_array <= mem_array_nxt;
    end
  end else begin : GEN_RM1W
    always @ (posedge clk_w) begin : clk_regs_PROC
      if (en_w_array==1'b1)
        mem_array <= mem_array_nxt;
    end
  end
endgenerate

always @ (mem_array or addr_w_array or data_w_array) begin : mk_next_mem_PROC
  integer i, j, k;
  mem_array_nxt = mem_array;

  k = 0;
  for (i=0 ; i < DEPTH ; i=i+1) begin
    if ($unsigned(i) == addr_w_array) begin
      for (j=0 ; j < WIDTH ; j=j+1)
        mem_array_nxt[k+j] = data_w_array[j];
    end

    k = k + WIDTH;
  end
end

// spyglass enable_block STARC-2.3.4.3
// spyglass enable_block W415a
// spyglass enable_block Ac_conv04


generate
  if ((MEM_MODE & 4) == 4) begin : GEN_MMBT2_1
    reg [ADDR_WIDTH-1 : 0] addr_w_retimed;
    reg [WIDTH-1 : 0] data_w_retimed;
    reg en_w_retimed;

    always @ (posedge clk_w or negedge rst_w_n) begin : mmbt2_1_PROC
      if (rst_w_n == 1'b0) begin
        addr_w_retimed <= {ADDR_WIDTH{1'b0}};
        data_w_retimed <= {WIDTH{1'b0}};
        en_w_retimed <= 1'b0;
      end else begin
        if (en_w_n == 1'b0) begin
          addr_w_retimed <= addr_w;
          data_w_retimed <= data_w;
        end
        en_w_retimed <= ~en_w_n;
      end
    end

    assign addr_w_array = addr_w_retimed;
    assign en_w_array = en_w_retimed;
    assign data_w_array = data_w_retimed;
  end else begin : GEN_MMBT2_0
    assign addr_w_array = addr_w;
    assign en_w_array = ~en_w_n;
    assign data_w_array = data_w;
  end
endgenerate



// Selects one of N equal sized subsections of an input vector to the specified output.

  // Selects one of DEPTH equal sized subsections of an input vector to the specified output 
  function automatic [WIDTH-1:0] func_read_mux ;
    input [WIDTH*DEPTH-1:0]     f_a;    // input bus
    input [ADDR_WIDTH-1:0]      f_sel;  // select
    reg   [WIDTH-1:0]   f_z;
    integer                     f_i, f_j, f_k;
    begin
      f_z = {WIDTH {1'b0}};
      f_j = 0;
      for (f_i=0 ; f_i<DEPTH ; f_i=f_i+1) begin
        if ($unsigned(f_i) == f_sel) begin
          for (f_k=0 ; f_k<WIDTH ; f_k=f_k+1) begin
// spyglass disable_block W415a
// SMD: Signal may be multiply assigned (beside initialization) in the same scope
// SJ: The design checked and verified that not any one of a single bit of the bus is assigned more than once beside initialization or the multiple assignments are intentional.
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
            f_z[f_k] = f_a[f_j + f_k];
// spyglass enable_block W415a
// spyglass enable_block SelfDeterminedExpr-ML
          end // for (f_k
        end // if
        f_j = f_j + WIDTH;
      end // for (f_i
      func_read_mux  = f_z;
    end
  endfunction

  assign rd_data_array = func_read_mux ( mem_array, addr_r_array );



generate
  if ( (MEM_MODE&3) == 0 ) begin : GEN_MM_0 // no retiming regs
    assign addr_r_array = addr_r;
    assign data_r = rd_data_array;
    assign data_r_a = ~en_r_n;
  end

  if ( (MEM_MODE&3) == 1) begin : GEN_MM_1 // data out retiming reg
    reg en_r_n_retimed;
    reg [WIDTH-1:0] rd_data_retimed;
    wire en_r_array;

    always @ (posedge clk_r or negedge rst_r_n) begin : rd_n_q_PROC
      if (rst_r_n == 1'b0)
        en_r_n_retimed <= 1'b0;
      else
        en_r_n_retimed <= ~en_r_n;
    end

    always @ (posedge clk_r or negedge rst_r_n) begin : rd_data_q_PROC
      if (rst_r_n == 1'b0) begin
        rd_data_retimed <= {WIDTH{1'b0}};
      end else begin
        if (en_r_array == 1'b1)
          rd_data_retimed <= rd_data_array;
      end
    end

    assign addr_r_array = addr_r;
    assign en_r_array = ~en_r_n;
    assign data_r = rd_data_retimed;
    assign data_r_a = en_r_n_retimed;
  end

  if ( (MEM_MODE&3) == 2) begin : GEN_MM_2 // addr in retiming reg
    reg [ADDR_WIDTH-1:0] addr_r_retimed;
    reg en_r_n_retimed;

    always @ (posedge clk_r or negedge rst_r_n) begin : rd_addr_q_PROC
      if (rst_r_n == 1'b0)
        addr_r_retimed <= {ADDR_WIDTH{1'b0}};
      else if (en_r_n == 1'b0)
        addr_r_retimed <= addr_r;
    end

    always @ (posedge clk_r or negedge rst_r_n) begin : rd_n_q_PROC
      if (rst_r_n == 1'b0)
        en_r_n_retimed <= 1'b0;
      else
        en_r_n_retimed <= ~en_r_n;
    end

    assign addr_r_array = addr_r_retimed;
    assign data_r = rd_data_array;
    assign data_r_a = en_r_n_retimed;
  end

  if ( (MEM_MODE&3) == 3) begin : GEN_MM_3 // both retiming regs
    reg [ADDR_WIDTH-1:0] addr_r_retimed;
    reg en_r_n_retimed;
    reg en_r_n_retimed2;
    reg [WIDTH-1:0] rd_data_retimed;
    wire en_r_array;

    always @ (posedge clk_r or negedge rst_r_n) begin : rd_addr_q_PROC
      if (rst_r_n == 1'b0)
        addr_r_retimed <= {ADDR_WIDTH{1'b0}};
      else if (en_r_n == 1'b0)
        addr_r_retimed <= addr_r;
    end

    always @ (posedge clk_r or negedge rst_r_n) begin : rd_n_q_PROC
      if (rst_r_n == 1'b0) begin
        en_r_n_retimed <= 1'b0;
        en_r_n_retimed2  <= 1'b0;
      end else begin
        en_r_n_retimed <= ~en_r_n;
        en_r_n_retimed2 <= en_r_n_retimed;
      end
    end

    always @ (posedge clk_r or negedge rst_r_n) begin : rd_data_q_PROC
      if (rst_r_n == 1'b0) begin
        rd_data_retimed <= {WIDTH{1'b0}};
      end else begin
        if (en_r_array == 1'b1)
          rd_data_retimed <= rd_data_array;
      end
    end

    assign addr_r_array = addr_r_retimed;
    assign en_r_array = en_r_n_retimed;
    assign data_r = rd_data_retimed;
    assign data_r_a = en_r_n_retimed2;
  end

endgenerate


endmodule
