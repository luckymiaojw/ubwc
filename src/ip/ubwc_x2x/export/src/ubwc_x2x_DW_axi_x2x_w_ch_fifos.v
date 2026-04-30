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
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_w_ch_fifos.v#10 $ 
**
** --------------------------------------------------------------------
**
** File     : DW_axi_x2x_w_ch_fifos.v
** Abstract : This block implements fifos for the write data channel.
**
**            Single or dual clock fifo's may be selected.
**
**            The majority of clock boundary crossing within the 
**            DW_axi_x2x is handled in this block.
**
** --------------------------------------------------------------------
*/

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_w_ch_fifos (
  // Inputs - Push Side 
  clk_push_i,
  resetn_push_i,

  bus_push_req_n_i,
  data_i,
  
  // Outputs - Push Side
  bus_push_full_o,


  // Inputs - Pop Side 

  bus_pop_req_n_i,
  
  // Outputs - Pop Side
  bus_pop_empty_o,
  bus_data_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------

  // INTERFACE PARAMETERS - MUST BE SET BY INSTANTIATION
//  parameter DUAL_CLK = 0; // Controls wether single or dual clock
                          // fifos are implemented.



  parameter NUM_FIFOS = 1; // Controls how many fifos will be 
                           // implemented. Maximum of 16.

  parameter DATA_W = 0; // Controls the width of each fifo.

  parameter DEPTH = 0; // Controls the depth of each fifo.

  parameter LOG2_DEPTH = 0; // Log base 2 of DEPTH.

  parameter BUS_DATA_W = 0; // Width of bus of data signals.


  // INTERNAL PARAMETERS - MUST NOT BE SET BY INSTANTIATION
//  parameter MAX_NUM_FIFOS = 8; // Maximum number of fifos in this 
                               // block.

//  parameter MAX_DATA_W = MAX_NUM_FIFOS * DATA_W; // Max width of bus
                                                 // data signal.

//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------
 

//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------
  
  // Inputs - Push Side 
  input clk_push_i; // Push side clk.
  input resetn_push_i; // Push side reset.

  input [NUM_FIFOS-1:0] bus_push_req_n_i; // Bus of push request signals
                                          // for each fifo.

  input [DATA_W-1:0] data_i; // Payload vector for each fifo.
  
  // Outputs - Push Side
  output [NUM_FIFOS-1:0] bus_push_full_o; // Bus of full status signals
                                          // from each fifo.


  // Inputs - Pop Side 

  input [NUM_FIFOS-1:0] bus_pop_req_n_i; // Bus of pop request signals
                                         // for each fifo.

  // Outputs - Pop Side
  output [NUM_FIFOS-1:0] bus_pop_empty_o; // Bus of empty status signals
                                          // from each fifo.

  output [BUS_DATA_W-1:0] bus_data_o; // Bus of data vectors from
                                      // each fifo.


  //--------------------------------------------------------------------
  // REGISTER VARIABLES.
  //--------------------------------------------------------------------

  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
  
// Dummy wires - used to suppress unconnected ports warnings by lint tool - BR - 2/24/2010
  wire [NUM_FIFOS-1:0] fifo_ae_unconn, fifo_hf_unconn, fifo_af_unconn, fifo_error_unconn;
  
    
  //--------------------------------------------------------------------
  // Assign bussed input signals to max width signals.
  //--------------------------------------------------------------------


  //--------------------------------------------------------------------
  // Note ifdefs are used to remove unecessary fifos, for this module
  // there will only be more than 1 single or dual clock fifo if 
  // X2X_HAS_WI_FAN_OUT == 1, in this case there are multiple slave
  // ports on the the X2X (write channels only) , so we use the
  // macros X2X_SP[x] to tell us wheter or not to include a particular
  // fifo.
  //--------------------------------------------------------------------
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : BCM components are configurable to use in various scenarios in this particular design we are not using certain ports. Hence although those signals are read we are not driving them. Therefore waiving this warning.

  //--------------------------------------------------------------------
  // Instantiate single clock fifo's 
  //--------------------------------------------------------------------
  
genvar gvsf;
generate
  for (gvsf=0; gvsf < NUM_FIFOS; gvsf=gvsf+1) begin: Unrollbcm65
    ubwc_x2x_DW_axi_x2x_bcm65
    
    #(DATA_W,    // Word width.
      DEPTH,     // Word depth.  
      1,         // ae_level, don't care.
      1,         // af_level, don't care.
      0,         // err_mode, don't care.
      0,         // Reset mode, asynch. reset including memory.
      LOG2_DEPTH // Fifo address width.
    )
    U_sclk_fifo0 (
      .clk            (clk_push_i),   
      .rst_n          (resetn_push_i),
      .init_n         (1'b1), // Synchronous reset, not used.
  
      // Push side - Inputs
      .push_req_n     (bus_push_req_n_i[gvsf]),
      .data_in        (data_i),   
      
      // Push side - Outputs
      .full           (bus_push_full_o[gvsf]), 
  
      // Pop side - Inputs
      .pop_req_n      (bus_pop_req_n_i[gvsf]),   
      
      // Pop side - Outputs
      .data_out       (bus_data_o[gvsf*DATA_W+:DATA_W]),
      .empty          (bus_pop_empty_o[gvsf]),
  
      // Unconnected or tied off.
      .diag_n         (1'b1), // Never using diagnostic mode.
      .almost_empty   (fifo_ae_unconn),
      .half_full      (fifo_hf_unconn),
      .almost_full    (fifo_af_unconn),
      .error          (fifo_error_unconn)
    );
  end
endgenerate



//spyglass enable_block W528
endmodule
