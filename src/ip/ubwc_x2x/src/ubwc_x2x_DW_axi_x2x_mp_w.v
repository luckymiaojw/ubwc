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
// File Version     :        $Revision: #9 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_mp_w.v#9 $ 
//
/////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////
// W control in MP including fanout
/////////////////////////////////////////////////////////////////////////

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_mp_w (
 //inputs
  valid_i,
  payload_i,

  push_full_i, 


 //outputs
  push_req_n_o,
  payload_o,
  ready_o
);

  //parameters
  parameter NUM_PORTS = `ubwc_x2x_X2X_NUM_W_PORTS;     //number of fanout ports
  parameter PLD_W     = `ubwc_x2x_X2X_WPYLD_W_MP;      //payload width
  //internal parameters
//  parameter MAX_ID_W  = 8 * MP_IDW;           //Max BUS ID width

  //inputs
  input                  valid_i;      //valid signal
  input [PLD_W-1:0]      payload_i;    //payload in

  input [NUM_PORTS-1:0]  push_full_i;  //push full flag
  
  //outputs
  output [NUM_PORTS-1:0] push_req_n_o; //push enable to port 1
  output [PLD_W-1:0]     payload_o;    //payload to port
  output                 ready_o;      //ready signal to AXI master


  wire                 ready_o;
  wire [PLD_W-1:0]     payload_o;
  wire [NUM_PORTS-1:0] push_req_n_o;


  ////////////////////////////////////////////////////////////
  // decode wid to put payload to corresponding FIFO.
  // If ID matches one port ID, forward payload to that FIFO
  ////////////////////////////////////////////////////////////

  assign payload_o = payload_i;

  // Hold ready out low during low power mode.
  assign ready_o         = !push_full_i[0];
  assign push_req_n_o[0] = !(valid_i && ready_o);



endmodule
