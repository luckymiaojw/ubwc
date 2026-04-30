/* --------------------------------------------------------------------
**
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
// File Version     :        $Revision: #10 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_mp_a.v#10 $ 
**
** --------------------------------------------------------------------
**
** File     : DW_axi_x2x_mp_a.v
** Abstract : Converts X2X master port address channel signals to
**            a fifo push interface signaling.
**
** --------------------------------------------------------------------
*/

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_mp_a (
  // System Inputs

  // AXI Interface
  // Inputs
  valid_i,
  payload_i,

  // Outputs
  ready_o,
  
  // FIFO Push Interface
  // Inputs
  push_full_i,

  // Outputs
  push_req_n,

  // Write Fanout
  // Inputs

  //lowpower stall input


  // Outputs
  payload_o

);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter PYLD_W = `ubwc_x2x_X2X_AWPYLD_W_MP; //payload width of AW or AR of MP
  parameter CH_FIFO_W = `ubwc_x2x_X2X_AW_CH_FIFO_W; //payload width in FIFO
  parameter NUM_PORTS = `ubwc_x2x_X2X_NUM_W_PORTS; //number of fanout ports

  //internal parameters
//  parameter MAX_ID_W  = 8 * MP_IDW;         //Max BUS ID width
//  parameter MAX_IDA_W = 8 * IDACTW;         //Max BUS ACT ID width

//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------
  // System Inputs

  // AXI Interface
  // Inputs
  input valid_i; // Valid from channel source.
  input [PYLD_W-1:0] payload_i; // Payload from channel source.

  // Outputs
  output ready_o; // Ready to channel source.
  wire   ready_o;
  
  // FIFO Push Interface
  // Inputs
  input push_full_i; // Full status from channel fifo.

  // Outputs
  output push_req_n; // Push request to channel fifo.
  wire   push_req_n; 

  output [CH_FIFO_W-1:0] payload_o; // Channel payload to channel fifo.
  wire   [CH_FIFO_W-1:0] payload_o;

  // Write fanout
  // Inputs

  //lowpower stall

  // Outputs




  
  // Active low push request.
  // Asserted when source has valid data and the destination
  // fifo is not full.
  // If write fanout and stall, no push.
  assign push_req_n =                      ~(valid_i && (!push_full_i));


  // Straight through connection.
  // If write fanout, need port number.
  // Otherwise, port number = 0.
  assign payload_o =                     (NUM_PORTS == 1) ? payload_i :
                     payload_i;


  // Ready to channel source.
  // Asserted whenever the destination fifo is NOT full.
  // If write fanout & stall, no ready asserted.
  assign ready_o =                  !push_full_i;



endmodule
