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
// File Version     :        $Revision: #7 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_sp_wfc.v#7 $ 
//
/////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////
// ID maintain and stall xact for fanout (write fanout control)
/////////////////////////////////////////////////////////////////////////

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"


module ubwc_x2x_DW_axi_x2x_sp_wfc (
 //inputs
  addr_fifo_ept_i,
  avalid_i,
  payload_i,
  rs_push_req_n_i,
  aready_i,
  rs_fifo_full_i,
  port_num_i,

 //outputs
  avalid_o,
  payload_o,
  rs_push_req_n_o,
  aready_o,
  rs_fifo_full_o
);

  //parameters
  parameter SPPLD_W    = `ubwc_x2x_X2X_AWPYLD_W_SP;      //SP payload width
  parameter NUM_PORTS  = `ubwc_x2x_X2X_NUM_W_PORTS;      //number of fanout ports
  parameter NUM_PORT_W = `ubwc_x2x_X2X_LOG2_NUM_W_PORTS; //port number width
  parameter BUS_SPPLDW = NUM_PORTS * SPPLD_W;   //BUS payload width

  //inputs
  input                  addr_fifo_ept_i;  //Address FIFO empty signal
  input                  avalid_i;         //valid from resize
  input [SPPLD_W-1:0]    payload_i;        //payload from RS
  input                  rs_push_req_n_i;  //push enable from RS
  input [NUM_PORTS-1:0]  aready_i;         //ready from ports
  input [NUM_PORTS-1:0]  rs_fifo_full_i;   //bus RS FIFO full signal
  input [NUM_PORT_W-1:0] port_num_i;       //port number located
  
  //outputs
  output [NUM_PORTS-1:0]  avalid_o;         //valid to port1 to AXI slave
  output [BUS_SPPLDW-1:0] payload_o;        //BUS payload
  output [NUM_PORTS-1:0]  rs_push_req_n_o;  //push enable to RS FIFO1
  output                  aready_o;         //ready signal to resizer
  output                  rs_fifo_full_o;   //RS FIFO full to resizer
                                            //when ADDR fifo not empty
                                            //and corresponding RS fifo
                                            //not full from W of SP.

  // These signals are set to 0 as wires if there is no
  // write interleaving fan out in the configuration.
  reg                   rs_fifo_full_o;     //FIFO full signal to RS
  reg                   aready_o;           //AREADY signal to RS
  reg  [NUM_PORTS-1:0]  avalid_o;           //AVALID signal to ports
  reg  [BUS_SPPLDW-1:0] payload_o;          //BUS payload
  reg  [NUM_PORTS-1:0]  rs_push_req_n_o;    //RS fifo push EN to W of SP

  // Remove write interleaving fan out logic if fan out is not 
  // configured to exist.
  integer               i, j;
  
  ////////////////////////////////////////////////////////////////////
  //If addr FIFO not empty and port is available,
  //assign fifo_full and aready signal for RS use 
  //according to port_num.
  //
  //If addr FIFO not empty and port is available,
  //locate avalid (from RS) to fanout ports.
  //locate rs_push_req_n (from RS) to RS FIFOs in W of SP.
  ////////////////////////////////////////////////////////////////////
  always @( rs_fifo_full_i or aready_i or port_num_i or avalid_i or
            payload_i or rs_push_req_n_i or addr_fifo_ept_i ) begin
    rs_fifo_full_o  = 1'b1;
    aready_o        = 1'b0;
    avalid_o        = {NUM_PORTS{1'b0}};
    rs_push_req_n_o = {NUM_PORTS{1'b1}};
    payload_o       = {BUS_SPPLDW{1'b0}};

    if ( !addr_fifo_ept_i ) begin
      for ( i=0; i<NUM_PORTS; i=i+1 ) begin
        if ( port_num_i == i ) begin
          rs_fifo_full_o     = rs_fifo_full_i[i];
          aready_o           = aready_i[i];
         
          avalid_o[i]        = avalid_i;
          rs_push_req_n_o[i] = rs_push_req_n_i;

          for ( j=0; j<SPPLD_W; j=j+1 )
            payload_o[i*SPPLD_W + j] = payload_i[j];
        end
      end
    end
  end

endmodule
