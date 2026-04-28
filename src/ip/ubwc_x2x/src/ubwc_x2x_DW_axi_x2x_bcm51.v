
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
// Filename    : DW_axi_x2x_bcm51.v
// Revision    : $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_bcm51.v#10 $
// Author      : Bruce Dean      April 20, 2004
// Description : DW_axi_x2x_bcm51.v Verilog module for DW_axi_x2x
//
// DesignWare IP ID: 5613bb93
//
////////////////////////////////////////////////////////////////////////////////

module ubwc_x2x_DW_axi_x2x_bcm51 (
           clk,
           rst_n,
           init_n,
           enable,
           request,
           lock,
           mask,
           parked,
           granted,
           locked,
           grant,
           grant_index
    );
    
  parameter N                = 4; // RANGE 2 to 32
  parameter PARK_MODE        = 1; // RANGE 0 or 1
  parameter PARK_INDEX       = 0; // RANGE 0 to (N - 1)
  parameter OUTPUT_MODE      = 1; // RANGE 0 or 1
  parameter INDEX_WIDTH = 2;  // RANGE 1 to 5


  input                         clk;     // clock input
  input                         rst_n;   // active low asynchronous reset
  input                         init_n;  // active low synchronous reset
  input                         enable;  // active high enable
  input  [N-1: 0]               request; // client request bus
  input  [N-1: 0]               lock;    // client lock bus
  input  [N-1: 0]               mask;    // client mask bus

  output                        parked;  // arbiter parked status flag
  output                        granted; // arbiter granted status flag
  output                        locked;  // arbeter locked status bus
  output [N-1: 0]               grant;   // one-hot granted client bus
  output [INDEX_WIDTH-1: 0]     grant_index; //ndex of current granted client 

// spyglass disable_block ParamWidthMismatch-ML
// SMD: Parameter width does not match with the value assigned
// SJ: The legal value of RHS parameter cannot exceed the range that the LHS parameter can represent.  Even though there is a width mismatch, no information is lost in the assignment.
localparam [INDEX_WIDTH-1:0]    IDLE_INDEX = (PARK_MODE == 1) ? PARK_INDEX : -1;
localparam [N-1:0]              IDLE_GRANT = (PARK_MODE == 1) ? 1 << PARK_INDEX : 0;
// spyglass enable_block ParamWidthMismatch-ML
localparam [INDEX_WIDTH-1:0]    NMINUSONE = N - 1;

reg  [INDEX_WIDTH-1 : 0] grant_index_int, grant_index_next;
reg  [N-1 : 0]           grant_next, grant_int;


reg            granted_next, granted_int;
reg            locked_next;

wire [N-1 : 0] mreq;
   
  assign             mreq = request & (~mask);

// spyglass disable_block W415a
// SMD: Signal may be multiply assigned (beside initialization) in the same scope
// SJ: The design checked and verified that not any one of a single bit of the bus is assigned more than once beside initialization or the multiple assignments are intentional.
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
always @ (mreq or lock or grant_index_int or grant_int 
          or granted_int ) begin : MASKED_REQ_COMBO_PROC
   reg [31:0]   index;
   if( ((|(lock & grant_int)) & (granted_int)) != 1'b0) begin
     locked_next      = 1'b1;
     grant_index_next = grant_index_int;
     grant_next       = grant_int;
     granted_next     = granted_int;
   end else begin
      grant_index_next = IDLE_INDEX;
      grant_next       = IDLE_GRANT;
      granted_next     = 1'b0;
      locked_next      = 1'b0;
// spyglass disable_block W480
// SMD: Loop index is not of type integer
// SJ: for loop construction using sized vector reviewed and determined to be safe
      for(index = 32'b0; index < N; index = index + 32'b1) begin
        if (mreq[N - 1 - index] == 1'b1) begin : mk_next_vals
          grant_next = {N{1'b0}};
          grant_next[N - 1 - index] = 1'b1;
          grant_index_next = NMINUSONE - index[INDEX_WIDTH-1:0];
          granted_next     = 1'b1;
        end
      end
// spyglass enable_block W480
   end
 end
// spyglass enable_block W415a
// spyglass enable_block SelfDeterminedExpr-ML

  always @(posedge clk or negedge rst_n) begin : register_PROC
    if (rst_n == 1'b0) begin
      grant_index_int     <= IDLE_INDEX;
      granted_int         <= 1'b0;
      grant_int           <= IDLE_GRANT;
    end else if (init_n == 1'b0) begin
      grant_index_int     <= IDLE_INDEX;
      granted_int         <= 1'b0;
      grant_int           <= IDLE_GRANT;
    end else if(enable) begin
      grant_index_int     <= grant_index_next;
      granted_int         <= granted_next;
      grant_int           <= grant_next;
    end
  end

  generate
    if (OUTPUT_MODE == 0) begin : GEN_OM_EQ_0
      assign grant       = (init_n==1'b0)? IDLE_GRANT : grant_next;
      assign grant_index = (init_n==1'b0)? IDLE_INDEX : grant_index_next;
      assign granted     = granted_next & init_n;
      assign locked      = locked_next & init_n;
    end else begin : GET_OM_NE_0
      reg    locked_int;

      always @(posedge clk or negedge rst_n) begin : register_PROC
        if (rst_n == 1'b0) begin
          locked_int          <= 1'b0;
        end else if (init_n == 1'b0) begin
          locked_int          <= 1'b0;
        end else if(enable) begin
          locked_int          <= locked_next;
        end
      end

      assign grant       = grant_int;
      assign grant_index = grant_index_int;
      assign granted     = granted_int;
      assign locked      = locked_int;
    end
  endgenerate

  generate
    if (PARK_MODE == 0) begin : GEN_PM_EQ_0
      assign parked = 1'b0;
    end else if (OUTPUT_MODE == 0) begin : GEN_PM_NE_0_OM_EQ_0
      assign parked     = ~granted_next | ~init_n;
    end else begin : GEN_PM_NE_0_OM_NE_0
      assign parked     = ~granted_int;
    end
  endgenerate

endmodule
