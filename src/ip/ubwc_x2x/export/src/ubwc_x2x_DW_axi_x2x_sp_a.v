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
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_sp_a.v#9 $ 
//
/////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////
// AR & AW in SP
/////////////////////////////////////////////////////////////////////////

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_sp_a (
 //inputs
  aclk,
  aresetn,
  payload_i,
  aready_i,
  data_fifo_full_i,
  resp_fifo_full_i,
  addr_fifo_ept_i,
  
 //outputs
  payload_o,
  avalid_o,
  rs_push_req_n_o,
  aid_o,
  addr_rs_o,
  alen_o,
  asize_o,
  asize_mp_o,
  aburst_o,
  pre_last_xact_o,
  last_rs_xact_o,
  us_xact_issue_off_o,
  pop_req_n_o
);

  //parameters from upper level module
  parameter WRITE_CH  = 0;                      //1->write channel,
                                                //0->read channel
// spyglass disable_block W576
// SMD: Logical operator used on a multibit value
// SJ: X2X_HAS_WI_FAN_OUT and WRITE_CH can be set to 0 or 1. Since, parameter
// is by default 32 bit, spyglass is considering it as a vector. Functionally
// there will not be any issue as the result will be either 0 or 1.
  parameter INC_WRITE_FANOUT = `ubwc_x2x_X2X_HAS_WI_FAN_OUT && WRITE_CH; 
// spyglass enable_block W576
                                                //write + fanout
  parameter NUM_FIFOS = `ubwc_x2x_X2X_NUM_W_PORTS;       //number of RS FIFOs
  parameter NUM_PORTS = `ubwc_x2x_X2X_NUM_W_PORTS;       //number of FANOUT ports
  parameter A_TRK_W   = `ubwc_x2x_X2X_ADDR_TRK_W;        //addr bits to RS FIFO

  //auto switch parameters based on WRITE_CH
  parameter MPPLD_W = WRITE_CH ? `ubwc_x2x_X2X_AWPYLD_W_MP :
                      `ubwc_x2x_X2X_ARPYLD_W_MP;         //MP payload width
  parameter SPPLD_W = WRITE_CH ? `ubwc_x2x_X2X_AWPYLD_W_SP :
                      `ubwc_x2x_X2X_ARPYLD_W_SP;         //SP payload width

  //not from upper level module
  parameter MP_BLW     = `ubwc_x2x_X2X_MP_BLW;             //Burst length width
  parameter INT_AW     = `ubwc_x2x_X2X_INTERNAL_AW;        //Internal addr width
  parameter MP_IDW     = `ubwc_x2x_X2X_MP_IDW;             //ID width
  parameter SP_BLW     = `ubwc_x2x_X2X_SP_BLW;             //Burst length width
//  parameter SP_IDW     = `ubwc_x2x_X2X_SP_IDW;             //ID width
//  parameter BUS_ID_W   = NUM_PORTS * MP_IDW;      //MP ID width of BUS
  parameter NUM_PORT_W = `ubwc_x2x_X2X_LOG2_NUM_W_PORTS;   //port number width
  parameter MPPLD_W_I  = NUM_PORTS == 1 ? MPPLD_W :
                         MPPLD_W + NUM_PORT_W;    //+ port number
  parameter BUS_SPPLDW = NUM_PORTS * SPPLD_W;     //SP payload BUS width
// spyglass disable_block W576
// SMD: Logical operator used on a multibit value
// SJ: WRITE_CH is a parameter which can be set to 0 or 1. Since, parameter
// is by default 32 bit, spyglass is considering it as a vector. Functionally
// there will not be any issue as the result will be either 0 or 1.
  parameter A_SBW      = (WRITE_CH && `ubwc_x2x_X2X_HAS_AWSB) ? `ubwc_x2x_X2X_AW_SBW :
                         ((!WRITE_CH && `ubwc_x2x_X2X_HAS_ARSB) ? `ubwc_x2x_X2X_AR_SBW :
                         1);                      //SB width of AW or AR
// spyglass enable_block W576

  //inputs
  input                 aclk;             //clock
  input                 aresetn;          //reset, act low
  input [MPPLD_W_I-1:0] payload_i;        //payload from Addr FIFO
  input [NUM_PORTS-1:0] aready_i;         //ready from port
  input [NUM_FIFOS-1:0] data_fifo_full_i; //resize FIFO full
  
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read.
  //SJ : This signal is used depending on the WRITE_CH parameter (--there are multiple instances of this module).
  input [NUM_FIFOS-1:0] resp_fifo_full_i; //resize FIFO full
  //spyglass enable_block W240
  input                 addr_fifo_ept_i;  //addr FIFO empty
  
  //outputs
  output [BUS_SPPLDW-1:0] payload_o;       //payload to port
  output [NUM_PORTS-1:0]  avalid_o;        //avalid to port
  output [NUM_FIFOS-1:0]  rs_push_req_n_o; //push enable to RS FIFO
  output [MP_IDW-1:0]     aid_o;           //ID to rs fifos
  output [A_TRK_W-1:0]    addr_rs_o;       //addr to RS
  output [SP_BLW-1:0]     alen_o;          //len to rs fifos
  output [2:0]            asize_o;         //size to rs fifos
  output [`ubwc_x2x_X2X_BTW-1:0]   aburst_o;        //burst type to rs fifos
  output [2:0]            asize_mp_o;      //MP asize to resp fifos
  output                  pre_last_xact_o; //xact pre last xact
  output                  last_rs_xact_o;  //last xact
  output                  us_xact_issue_off_o; //US xact issued
  output                  pop_req_n_o;     //pop enable to addr FIFO

  wire [SPPLD_W-1:0]    payload_w;
  wire                  avalid_w;
  wire                  rs_push_req_n_w;
  wire [MP_IDW-1:0]     aid_w;
  wire [A_TRK_W-1:0]    addr_rs_w;
  wire [SP_BLW-1:0]     alen_w;
  wire [2:0]            asize_w;
  wire [`ubwc_x2x_X2X_BTW-1:0]   aburst_w;
  wire [2:0]            asize_mp_w;
  wire                  pre_last_xact_w;
  wire                  last_rs_xact_w;
  wire [A_SBW-1:0]      asideband_rs;
  // This signal is used depending on a hierarchical parameter as this module is instantiated multiple times.
  wire [NUM_FIFOS-1:0]  rs_push_req_n_wfc;
  wire [NUM_PORTS-1:0]  avalid_wfc;
  wire                  aready_wfc;
  wire                  rs_fifo_full_wfc;
  wire [BUS_SPPLDW-1:0] payload_wfc;
  wire [NUM_PORT_W-1:0] port_num_i;
  wire                  aready_rs;
  wire                  wip_block;
  wire                  xact_upsize;
  wire                  rs_fifo_full;
  wire [NUM_FIFOS-1:0]  rs_fifo_full_in;
  wire                  aready_mux;
  wire [NUM_FIFOS-1:0]  rs_push_req_n_o;
  wire [2:0]            aprot_i;
  wire [3:0]            acache_i;
  wire [1:0]            alock_i;
  wire [1:0]            aburst_i;
  wire  [2:0]            asize_i;
  wire [MP_BLW-1:0]     alen_i;
  wire [INT_AW-1:0]     addr_i;
  wire [MP_IDW-1:0]     aid_i;
  wire [A_SBW-1:0]      asideband_i;
  wire                  pre_last_xact_o;
  wire                  last_rs_xact_o;
  wire [2:0]            aprot_rs;
  wire [3:0]            acache_rs;
  wire [1:0]            alock_rs;
  wire [1:0]            aburst_rs;
  wire [2:0]            asize_rs;
  wire [2:0]            asize_o;
  wire [SP_BLW-1:0]     alen_rs;
  wire [SP_BLW-1:0]     alen_o;
  wire [INT_AW-1:0]     addr_rs;
  wire [A_TRK_W-1:0]    addr_rs_o;
  wire [A_TRK_W-1:0]    addr_rs_rs;
  wire [MP_IDW-1:0]     aid_rs;
  wire                  rs_push_req_n_rs;
  wire [MP_IDW-1:0]     aid_o;
  wire                  avalid_rs;
  wire                  pre_last_xact_rs;
  wire                  last_rs_xact_rs;
  wire [2:0]            asize_mp_rs;
  wire [SPPLD_W-1:0]    payload_rs;
  wire [BUS_SPPLDW-1:0] payload_o;
  wire [NUM_PORTS-1:0]  avalid_o;

  //extract payload_i to addr and control signals
  //payload_i={port_num, aid, addr, alen, asize, aburst, 
  //           alock, acache, aprot}
    // spyglass disable_block W164b
    // SMD: Identifies assignments in which the LHS width is greater than the RHS width
    // SJ : This is not a functional issue, this is as per the requirement.
    //      Hence this can be waived.
    // spyglass disable_block W528
    // SMD: A signal or variable is set but never read.
    // SJ : port_num_i is read only when X2X_WI_FAN_OUTNN is defined.
    // spyglass disable_block W576
    // SMD: Logical operator used on a multibit value
    // SJ: WRITE_CH is a parameter which can be set to 0 or 1. Since, parameter
    // is by default 32 bit, spyglass is considering it as a vector. Functionally
    // there will not be any issue as the result will be either 0 or 1.
  generate if ( (WRITE_CH && `ubwc_x2x_X2X_HAS_AWSB) | (!WRITE_CH && `ubwc_x2x_X2X_HAS_ARSB) )
    // spyglass enable_block W576
    assign {port_num_i, asideband_i, aid_i, addr_i, alen_i, asize_i,
            aburst_i, alock_i, acache_i, aprot_i} = payload_i;
  else 
  begin
    assign {port_num_i, aid_i, addr_i, alen_i, asize_i,
            aburst_i, alock_i, acache_i, aprot_i} = payload_i;
    assign asideband_i = {A_SBW{1'b0}}; //undriven
  end
  endgenerate
    // spyglass enable_block W528
    // spyglass enable_block W164b

  //generate rs_fifo_full_in, no response channel for R
  assign rs_fifo_full_in = WRITE_CH ? 
                           data_fifo_full_i | resp_fifo_full_i :
                           data_fifo_full_i; 

  //generate rs_fifo_full for RS
  assign rs_fifo_full = INC_WRITE_FANOUT ? rs_fifo_full_wfc :
                                           rs_fifo_full_in[0];

  //assign W xact info
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : All these signals are used or read depending on the WRITE_CH parameter.
  assign {payload_w, avalid_w, rs_push_req_n_w}  = 
         {payload_rs, avalid_rs, rs_push_req_n_rs};

  assign {aid_w, addr_rs_w, alen_w, asize_w, asize_mp_w,
          aburst_w, pre_last_xact_w, last_rs_xact_w} = 
         {aid_rs, addr_rs_rs, alen_rs, asize_rs, asize_mp_rs,
          aburst_rs, pre_last_xact_rs, last_rs_xact_rs};

  assign us_xact_issue_off_o = 1'b0;
    // spyglass enable_block W528

  //instance write interleave process
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : awpush_full_wip is used or read depending on the WRITE_CH parameter. 
//spyglass enable_block W528

  assign aready_mux      = INC_WRITE_FANOUT ? aready_wfc : aready_i[0];

  generate if ( INC_WRITE_FANOUT ) begin //fanout
      assign avalid_o        = avalid_wfc;
      assign rs_push_req_n_o = rs_push_req_n_wfc;
      assign payload_o       = payload_wfc;
    end
    else if (WRITE_CH)
    begin //directly from resizer
      assign avalid_o        = avalid_w;
      assign rs_push_req_n_o = rs_push_req_n_w;
      assign payload_o       = payload_w;
    end
    else
    begin //directly from resizer
      assign avalid_o        = avalid_rs;
      assign rs_push_req_n_o = rs_push_req_n_rs;
      assign payload_o       = payload_rs;
    end
  endgenerate

  //instance resizer
  // In some configurations some signals are tied to zero.
  // - Signals: aready_o and wip_block_o are tied to zeros if X2X_WIP_BYPASS is defined.
  // - Signals: pre_last_xact_o and last_rs_xact_o are tied to zero/one if RS_BYPASS is set.
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : aready_rs and wip_block are used or read depending on the WRITE_CH parameter. 
  ubwc_x2x_DW_axi_x2x_rs
   
  #( WRITE_CH, A_SBW ) U_resizer (
    //inputs
    .aclk             ( aclk ),
    .aresetn          ( aresetn ),
    .aid_i            ( aid_i ),
    .addr_i           ( addr_i ),
    .alen_i           ( alen_i ),
    .asize_i          ( asize_i ),
    .aburst_i         ( aburst_i ),
    .alock_i          ( alock_i ),
    .acache_i         ( acache_i ),
    .aprot_i          ( aprot_i ),
    .asideband_i      ( asideband_i ),
    .aready_i         ( aready_mux ),
    .rs_fifo_full_i   ( rs_fifo_full ),
    .addrfifo_ept_i   ( addr_fifo_ept_i ),
    //outputs
    .aid_o            ( aid_rs ),
    .addr_o           ( addr_rs ),
    .addr_rs_o        ( addr_rs_rs ),
    .alen_o           ( alen_rs ),
    .asize_o          ( asize_rs ),
    .asize_mp_o       ( asize_mp_rs ),
    .aburst_o         ( aburst_rs ),
    .alock_o          ( alock_rs ),
    .acache_o         ( acache_rs ),
    .aprot_o          ( aprot_rs ),
    .asideband_o      ( asideband_rs ),
    .avalid_o         ( avalid_rs ),
    .pre_last_xact_o  ( pre_last_xact_rs ),
    .last_rs_xact_o   ( last_rs_xact_rs ),
    .rs_push_req_n_o  ( rs_push_req_n_rs ),
    .aready_o         ( aready_rs ),
    .wip_block_o      ( wip_block ),
    .xact_upsize_o    ( xact_upsize ),
    .pop_req_n_o      ( pop_req_n_o )
  );
  // spyglass enable_block W528

  //concatenate to payload
  //payload={aid, addr, alen, asize, aburst, alock, acache, aprot}
  // spyglass disable_block W576
  // SMD: Logical operator used on a multibit value
  // SJ: WRITE_CH is a parameter which can be set to 0 or 1. Since, parameter
  // is by default 32 bit, spyglass is considering it as a vector. Functionally
  // there will not be any issue as the result will be either 0 or 1.
  generate if ( (WRITE_CH && `ubwc_x2x_X2X_HAS_AWSB) | (!WRITE_CH && `ubwc_x2x_X2X_HAS_ARSB) )
  // spyglass enable_block W576
      assign payload_rs = {asideband_rs, aid_rs, addr_rs, alen_rs, asize_rs,
                           aburst_rs, alock_rs, acache_rs, aprot_rs};
  else
      assign payload_rs = {aid_rs, addr_rs, alen_rs, asize_rs, aburst_rs,
                           alock_rs, acache_rs, aprot_rs};
  endgenerate

  //to RS fifos
  assign aid_o = WRITE_CH ? aid_w : aid_rs;
  assign alen_o = WRITE_CH ? alen_w : alen_rs;
  assign asize_o = WRITE_CH ? asize_w : asize_rs;
  assign aburst_o = WRITE_CH ? aburst_w : aburst_rs;
  assign addr_rs_o = WRITE_CH ? addr_rs_w : addr_rs_rs;
  assign asize_mp_o = WRITE_CH ? asize_mp_w : asize_mp_rs;
  assign pre_last_xact_o = WRITE_CH ? pre_last_xact_w : pre_last_xact_rs;
  assign last_rs_xact_o = WRITE_CH ? last_rs_xact_w : last_rs_xact_rs;

endmodule



