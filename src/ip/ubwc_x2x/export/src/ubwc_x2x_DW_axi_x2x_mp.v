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
// File Version     :        $Revision: #11 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_mp.v#11 $ 
**
** --------------------------------------------------------------------
**
** File     : DW_axi_x2x_mp.v
** Abstract : Master port block for DW_axi_x2x.
**
** --------------------------------------------------------------------
*/

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_mp (
  // System inputs
  // AR EXTERNAL
  // Inputs
  arvalid_i,
  arpayload_i,

  // Outputs
  arready_o,

  // AR INTERNAL
  // Inputs
  ar_push_full_i,

  // Outputs
  ar_push_req_n_o,
  arpayload_o,


  // R EXTERNAL
  // Inputs
  rready_i,

  // Outputs
  rvalid_o,
  rpayload_o,

  // R INTERNAL
  // Inputs
  r_pop_empty_i,
  rpayload_i,
  
  // Outputs
  r_pop_req_n_o,

  // AW EXTERNAL
  // Inputs
  awvalid_i,
  awpayload_i,

  // Outputs
  awready_o,

  // AW INTERNAL
  // Inputs
  aw_push_full_i,

  // Outputs
  aw_push_req_n_o,
  awpayload_o,


  // W EXTERNAL
  // Inputs
  wvalid_i,
  wpayload_i,

  // Outputs
  wready_o,


  // W INTERNAL
  
  // Inputs
  w_bus_push_full_i,
  
  // Outputs
  w_bus_push_req_n_o,
  wpayload_o,


  // B EXTERNAL
  // Inputs
  bready_i,

  // Outputs
  bvalid_o,
  bpayload_o,

  // B INTERNAL
  // Inputs
  b_pop_empty_i,
  bpayload_i,


  // Outputs
  b_pop_req_n_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------

  // INSTANTIAION PARAMETERS - Must be set by instantiation.
  parameter AWPYLD_W = 0; // Width of write address channel payload.
  parameter WPYLD_W  = 0; // Width of write channel payload.
  parameter BPYLD_W  = 0; // Width of burst response channel payload.
  parameter ARPYLD_W = 0; // Width of read address channel payload.
  parameter RPYLD_W  = 0; // Width of read channel payload.

  // NON-INSTANTIAION PARAMETERS - Must not be set by instantiation.
  parameter AW_CH_FIFO_W = `ubwc_x2x_X2X_AW_CH_FIFO_W; // Width of AW channel 
                                              // fifo.

  // Width of bus containing an MP ID for each write port.

//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------


  // AR EXTERNAL
  // Inputs
  input arvalid_i;
  input [ARPYLD_W-1:0] arpayload_i;

  // Outputs
  output arready_o;

  // AR INTERNAL
  // Inputs
  input ar_push_full_i; // Channel fifo status bit.
  
  // Outputs
  output ar_push_req_n_o; // Push request to channel fifo.
  output [ARPYLD_W-1:0] arpayload_o; // Payload to channel fifo.
  

  // R EXTERNAL
  // Inputs
  input rready_i;

  // Outputs
  output rvalid_o;
  output [RPYLD_W-1:0] rpayload_o;

  // R INTERNAL
  // Inputs
  input r_pop_empty_i; // Channel fifo status bit.
  input [RPYLD_W-1:0] rpayload_i; // Payload from channel fifo.
  
  // Outputs
  output  r_pop_req_n_o; // Pop request to channel fifo.


  // AW EXTERNAL
  // Inputs
  input awvalid_i; 
  input [AWPYLD_W-1:0] awpayload_i;

  // Outputs
  output awready_o;

  // AW INTERNAL
  // Inputs
  input aw_push_full_i; // Channel fifo status bit.
  
  // Outputs
  output aw_push_req_n_o; // Push request to channel fifo.
  output [AW_CH_FIFO_W-1:0] awpayload_o; // Payload to channel fifo.
  

  // W EXTERNAL
  // Inputs
  input wvalid_i;
  input [WPYLD_W-1:0] wpayload_i;

  // Outputs
  output wready_o;

  // W INTERNAL - Note that for write interleaving fan out there
  //              can be more than one write data port on the
  //              X2X SP. There are bussed signals internally
  //              also because we implement a seperate write 
  //              data channel buffer for every write interleaving
  //              depth in this case.
  
  // Inputs
  // Bus of fifo status bits for all channel fifos.
  input [`ubwc_x2x_X2X_NUM_W_PORTS-1:0] w_bus_push_full_i;
  
  // Outputs
  // Bus of push require signals for all channel fifos.
  output [`ubwc_x2x_X2X_NUM_W_PORTS-1:0] w_bus_push_req_n_o;
  output [WPYLD_W-1:0] wpayload_o; // Payload to all channel fifos.


  // B EXTERNAL
  // Inputs
  input bready_i;

  // Outputs
  output bvalid_o;
  output [BPYLD_W-1:0] bpayload_o;

  // B INTERNAL
  // Inputs
  input b_pop_empty_i; // Channel fifo status bit.
  input [BPYLD_W-1:0] bpayload_i; // Payload from channel fifo.
  
  // Outputs
  output  b_pop_req_n_o; // Pop request to channel fifo.


  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
  


  //--------------------------------------------------------------------
  // Read address channel.
  //--------------------------------------------------------------------
  ubwc_x2x_DW_axi_x2x_mp_a
   
  #(
     ARPYLD_W, // Channel payload width.
     ARPYLD_W //AR Channel FIFO width
  )
  U_AR_DW_axi_x2x_mp_a (
    // System Inputs

    // AXI Interface
    // Inputs
    .valid_i     (arvalid_i),
    .payload_i   (arpayload_i),

    // Outputs
    .ready_o     (arready_o),
  
    // FIFO Push Interface
    // Inputs
    .push_full_i (ar_push_full_i),

    // Outputs
    .push_req_n  (ar_push_req_n_o),
  
    // Pending t/x Interface
  
    // Write Fanout
    // Inputs

    .payload_o   (arpayload_o)
  );

  //--------------------------------------------------------------------
  // Read data channel.
  //--------------------------------------------------------------------
  ubwc_x2x_DW_axi_x2x_mp_rb
   
  #( RPYLD_W // Channel payload width.
  )
  U_DW_axi_x2x_mp_r ( 
    //inputs
    .ready_i     (rready_i),
    .pop_empty_i (r_pop_empty_i),
    .payload_i   (rpayload_i),
  
    //outputs
    .valid_o     (rvalid_o),
    .pop_req_n_o (r_pop_req_n_o),
    .payload_o   (rpayload_o)
  );



  //--------------------------------------------------------------------
  // Write address channel.
  //--------------------------------------------------------------------
  ubwc_x2x_DW_axi_x2x_mp_a
   
  #(
     AWPYLD_W,      // Channel payload width.
     AW_CH_FIFO_W   // AW channel fifo width.
  )
  U_AW_DW_axi_x2x_mp_a (
    // System Inputs

    // AXI Interface
    // Inputs
    .valid_i     (awvalid_i),
    .payload_i   (awpayload_i),

    // Outputs
    .ready_o     (awready_o),
  
    // FIFO Push Interface
    // Inputs
    .push_full_i (aw_push_full_i),

    // Outputs
    .push_req_n  (aw_push_req_n_o),
   
    // Pending t/x Interface
  
    
    // Write Fanout
    // Inputs


    // Outputs
    .payload_o   (awpayload_o)
  );


  //--------------------------------------------------------------------
  // Write data channel.
  //--------------------------------------------------------------------
  ubwc_x2x_DW_axi_x2x_mp_w
   
  U_DW_axi_x2x_mp_w (
    //inputs
    .valid_i      (wvalid_i),
    .payload_i    (wpayload_i),
    .push_full_i  (w_bus_push_full_i), 
    

    //outputs
    .push_req_n_o (w_bus_push_req_n_o),
    .payload_o    (wpayload_o),
    .ready_o      (wready_o)
  );


  //--------------------------------------------------------------------
  // Burst response channel.
  //--------------------------------------------------------------------
  ubwc_x2x_DW_axi_x2x_mp_rb
   
  #( BPYLD_W // Channel payload width.
  )
  U_DW_axi_x2x_mp_b (
    //inputs
    .ready_i     (bready_i),
    .pop_empty_i (b_pop_empty_i),
    .payload_i   (bpayload_i),
  
    //outputs
    .valid_o     (bvalid_o),
    .pop_req_n_o (b_pop_req_n_o),
    .payload_o   (bpayload_o)
  );

endmodule
