/////////////////////////////////////////////////////////////////////////
//
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
// Release version :  1.08a
// File Version     :        $Revision: #6 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_mp_rb.v#6 $ 
//
/////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////
// R and B channel RTL in MP
/////////////////////////////////////////////////////////////////////////

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_mp_rb (
 //inputs
  ready_i,
  pop_empty_i,
  payload_i,
  
 //outputs
  valid_o,
  pop_req_n_o,
  payload_o
);

  //parameters
  parameter PLD_W = `ubwc_x2x_X2X_RPYLD_W_MP;  //payload width

  //inputs
  input              ready_i;      //ready signal
  input              pop_empty_i;  //pop_empty flag, active high
  input [PLD_W-1:0]  payload_i;    //input payload
  
  //outputs
  output             valid_o;      //valid signal
  output             pop_req_n_o;  //pop enable, active low
  output [PLD_W-1:0] payload_o;    //output payload


  wire               valid_o;
  wire               pop_req_n_o;
  wire [PLD_W-1:0]   payload_o;


  ///////////////////////////////////////////////////////
  // If FIFO empty, no more data valid.
  // so valid must be deasserted.
  ///////////////////////////////////////////////////////
  assign valid_o = !pop_empty_i;

  ///////////////////////////////////////////////////////
  // If FIFO empty or AXI master not ready, no more pop
  ///////////////////////////////////////////////////////
  assign pop_req_n_o = !( valid_o && ready_i);

  ///////////////////////////////////////////////////////
  // payload just passes as-is
  ///////////////////////////////////////////////////////
  assign payload_o = payload_i;

endmodule



