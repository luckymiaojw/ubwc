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
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_sd_fifo.v#11 $ 
**
** --------------------------------------------------------------------
**
** File     : DW_axi_x2x_sd_fifo.v
** Abstract : This block implements either 1 dual clock fifo or 1
**            single clock fifo.
**
** --------------------------------------------------------------------
*/

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_sd_fifo (
  // Inputs - Push Side 
  clk_push_i,
  resetn_push_i,

  push_req_n_i,
  data_i,
  
  // Outputs - Push Side
  push_full_o,


  // Inputs - Pop Side 

  pop_req_n_i,
  
  // Outputs - Pop Side
  pop_empty_o,
  data_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------

  // INTERFACE PARAMETERS - MUST BE SET BY INSTANTIATION
//  parameter DUAL_CLK = 0; // Controls wether single or dual clock
                          // fifos are implemented.

   
  parameter DATA_W = 0; // Controls the width of each fifo.

  parameter DEPTH = 0; // Controls the depth of each fifo.

  parameter LOG2_DEPTH = 0; // Log base 2 of DEPTH.


//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------
  
  // Inputs - Push Side 
  input clk_push_i; // Push side clk.
  input resetn_push_i; // Push side reset.

  input push_req_n_i; // Push request.

  input [DATA_W-1:0] data_i; // Data in for fifo.
  
  // Outputs - Push Side
  output push_full_o; // Full status signal from fifo.


  // Inputs - Pop Side 

  input pop_req_n_i; // Pop request signal for fifo.

  // Outputs - Pop Side
  output pop_empty_o; // Empty status signal from fifo.

  output [DATA_W-1:0] data_o; // Data out from fifo.


  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
    wire [DATA_W-1:0] sclk_data_o; // Single clock fifo output signals.
    wire sclk_push_full_o;
    wire sclk_pop_empty_o;

    wire ae_unconn, hf_unconn, af_unconn, error_unconn; 

  //--------------------------------------------------------------------
  // Instantiate single clock fifo.
  //--------------------------------------------------------------------
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : BCM components are configurable to use in various scenarios in this particular design we are not using certain ports. Hence although those signals are read we are not driving them. Therefore waiving this warning.
  ubwc_x2x_DW_axi_x2x_bcm65
  
  #(DATA_W,    // Word width.
    DEPTH,     // Word depth.  
    1,         // ae_level, don't care.
    1,         // af_level, don't care.
    0,         // err_mode, don't care.
    0,         // Reset mode, asynch. reset including memory.
    LOG2_DEPTH // Fifo address width.
  )
  U_sclk_fifo (
    .clk            (clk_push_i),   
    .rst_n          (resetn_push_i),
    .init_n         (1'b1), // Synchronous reset, not used.

    // Push side - Inputs
    .push_req_n     (push_req_n_i),
    .data_in        (data_i),   
    
    // Push side - Outputs
    .full           (sclk_push_full_o), 

    // Pop side - Inputs
    .pop_req_n      (pop_req_n_i),   
    
    // Pop side - Outputs
    .data_out       (sclk_data_o),
    .empty          (sclk_pop_empty_o),

    // Unconnected or tied off.
    .diag_n         (1'b1), // Never using diagnostic mode.
    .almost_empty   (ae_unconn),
    .half_full      (hf_unconn),
    .almost_full    (af_unconn),
    .error          (error_unconn)
  );
//spyglass enable_block W528




  //--------------------------------------------------------------------
  // Connect either dual or single clock fifo output signals.
  //--------------------------------------------------------------------
    assign push_full_o = sclk_push_full_o;
    assign pop_empty_o = sclk_pop_empty_o;
    assign data_o = sclk_data_o;
endmodule
