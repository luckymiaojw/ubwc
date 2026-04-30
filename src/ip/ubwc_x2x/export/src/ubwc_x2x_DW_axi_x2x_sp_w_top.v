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
// File Version     :        $Revision: #9 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_sp_w_top.v#9 $ 
**
** --------------------------------------------------------------------
**
** File     : DW_axi_x2x_sp_w_top.v
** Abstract : This is a top level module to stitch together multiple
**            DW_axi_x2x_sp_w blocks. For write interleaving fan 
**            out one of these blocks will be instantiated for every
**            write interleaving depth.
**
** --------------------------------------------------------------------
*/

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_sp_w_top (
  // System inputs
  aclk_i,
  aresetn_i,

  // SP WRITE ADDRESS CHANNEL I/F
  // Inputs 
  bus_rs_push_req_n_i,
  asize_mp_i,
  alen_i,
  aburst_i,
  asize_sp_i,
  addr_i,
  us_xact_issue_off_i,
  
  // Outputs 
  bus_rs_fifo_full_o,

  // CHANNEL FIFOS I/F
  // Inputs 
  bus_pop_empty_i,
  bus_payload_i,
  
  // Outputs 
  bus_pop_req_n_o,
  

  // EXTERNAL SLAVE PORTS I/F
  // Inputs 
  bus_ready_i,
  
  // Outputs 
  bus_valid_o,
  bus_payload_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------

  // INTERFACE PARAMETERS - MUST BE SET BY INSTANTIATION


  // INTERNAL PARAMETERS - MUST NOT BE SET BY INSTANTIATION
  parameter NUM_W_PORTS = `ubwc_x2x_X2X_NUM_W_PORTS; // Number of write ports.

  parameter MP_WPYLD_W = `ubwc_x2x_X2X_WPYLD_W_MP; // Width of W payload at MP.
  parameter SP_WPYLD_W = `ubwc_x2x_X2X_WPYLD_W_SP; // Width of W payload at SP.

  // Width of bus of W payloads, for MP width payload.
  parameter BUS_MP_WPYLD_W = MP_WPYLD_W * NUM_W_PORTS; 

  // Width of bus of W payloads, for SP width payload.
  parameter BUS_SP_WPYLD_W = SP_WPYLD_W * NUM_W_PORTS; 

//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------
 

//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------
  // System inputs
  input aclk_i;
  input aresetn_i;
  

  //--------------------------------------------------------------------
  // SP WRITE ADDRESS CHANNEL I/F
  //--------------------------------------------------------------------
  
  // Inputs 
  // Bus of push request signals to down size information fifos.
  input [NUM_W_PORTS-1:0] bus_rs_push_req_n_i; 

  // Downsized transaction attributes.
  input [`ubwc_x2x_X2X_BSW-1:0]        asize_mp_i; 
  input [`ubwc_x2x_X2X_SP_BLW-1:0]     alen_i;
  input [`ubwc_x2x_X2X_BTW-1:0]        aburst_i; 
  input [`ubwc_x2x_X2X_BSW-1:0]        asize_sp_i; 
  input [`ubwc_x2x_X2X_ADDR_TRK_W-1:0] addr_i; 
  
  input us_xact_issue_off_i; // Used in controlling issuing of upsized
                             // t/x data in configs with X2X_WID>1.
     
  // Outputs 
  // Bus of downsize fifo full status signals.
  output [NUM_W_PORTS-1:0] bus_rs_fifo_full_o; 


  //--------------------------------------------------------------------
  // CHANNEL FIFO I/F
  //--------------------------------------------------------------------
  // Inputs 
  // Empty status from all channel fifos.
  input [NUM_W_PORTS-1:0] bus_pop_empty_i; 
  // Bus of payloads from channel fifos.
  input [BUS_MP_WPYLD_W-1:0] bus_payload_i; 
  
  // Outputs 
  // Bus of pop requests to channel fifos.
  output [NUM_W_PORTS-1:0] bus_pop_req_n_o; 
  

  //--------------------------------------------------------------------
  // EXTERNAL SLAVE PORT I/F
  //--------------------------------------------------------------------
  // Inputs 
  // Bus of ready signals from SP write ports.
  input [NUM_W_PORTS-1:0] bus_ready_i; 
  
  // Outputs 
  // Bus of valid signals to SP write ports.
  output [NUM_W_PORTS-1:0] bus_valid_o; 
  // Bus of payloads to to SP write ports.
  output [BUS_SP_WPYLD_W-1:0] bus_payload_o; 


  //--------------------------------------------------------------------
  // WIRE/REGISTER VARIABLE DECLARATIONS
  //--------------------------------------------------------------------
  // bus_payload_i split up into individual payloads.
  wire [MP_WPYLD_W-1:0] payload_i_sp1;
  wire [SP_WPYLD_W-1:0] payload_o_sp1;
  
  // Split up incoming bus of channel payloads into individual
  // payloads signals per slave port.
  assign {
    payload_i_sp1 }
  = bus_payload_i;


  //--------------------------------------------------------------------
  // Instantiate Write Data Control block for SP 1.
  //--------------------------------------------------------------------
// In some configurations the us_issue_req_o signal is tied to zero.
  ubwc_x2x_DW_axi_x2x_sp_w
   
  U_DW_axi_x2x_sp_w1 (
    // System inputs
    .aclk_i               (aclk_i),
    .aresetn_i            (aresetn_i),

    // SP WRITE ADDRESS CHANNEL I/F
    // Inputs 
    .rs_push_req_n_i      (bus_rs_push_req_n_i[0]),
    .asize_mp_i           (asize_mp_i),
    .alen_i               (alen_i),
    .aburst_i             (aburst_i),
    .asize_sp_i           (asize_sp_i),
    .addr_i               (addr_i),
    .us_xact_issue_off_i  (us_xact_issue_off_i),
    
    // Outputs 
    .rs_fifo_full_o       (bus_rs_fifo_full_o[0]),
  
    // CHANNEL FIFO I/F
    // Inputs 
    .pop_empty_i          (bus_pop_empty_i[0]),
    .payload_i            (payload_i_sp1),
    
    // Outputs 
    .pop_req_n_o          (bus_pop_req_n_o[0]),
    
  
    // EXTERNAL SLAVE PORT I/F
    // Inputs 
    .ready_i              (bus_ready_i[0]),
    
    // Outputs 
    .valid_o              (bus_valid_o[0]),
    .payload_o            (payload_o_sp1)
  );




  











  // Collect individual slave port payloads signals into single bus.
  assign bus_payload_o = {
    payload_o_sp1 };

endmodule
