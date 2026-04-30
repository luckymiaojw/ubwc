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
// File Version     :        $Revision: #8 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_sp_r.v#8 $ 
//
/////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////
// R in SP
/////////////////////////////////////////////////////////////////////////

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_sp_r (
  //inputs
  aclk,
  aresetn,
  aid_i,
  asize_i,
  asize_mp_i,
  aburst_i,
  addr_i,
  pre_last_xact_i,
  last_rs_xact_i,
  rs_push_req_n_i,
  rvalid_i,
  rpayload_i,
  rpush_full_i,


  // Outputs 
  rs_push_full_o,
  rpush_req_n_o,
  rready_o,
  rpayload_o
);

  //parameters
  parameter MPPLD_W = `ubwc_x2x_X2X_RPYLD_W_MP;        //MP payload width
  parameter SPPLD_W = `ubwc_x2x_X2X_RPYLD_W_SP;        //SP payload width
  parameter MP_IDW  = `ubwc_x2x_X2X_MP_IDW;            //MP ID width

  parameter A_TRK_W    = `ubwc_x2x_X2X_ADDR_TRK_W;  //start addr bits
  parameter NUM_FIFOS  = `ubwc_x2x_X2X_MAX_URIDA;   //number of FIFOs implemented
  parameter MP_DW      = `ubwc_x2x_X2X_MP_DW;       //MP data width
  parameter SP_DW      = `ubwc_x2x_X2X_SP_DW;       //SP data width
  parameter TX_US      = `ubwc_x2x_X2X_HAS_TX_UPSIZE; //upsize
  parameter LOCKING    = `ubwc_x2x_X2X_HAS_LOCKING; //locking
  //internal parameters

  ///////////////////////////////////////////////////////////////////////
  //1. if MP_DW == SP_DW && MP_BLW == SP_BLW && no ET, no rs fifo used.
  //2. if MP_DW == SP_DW && MP_BLW == SP_BLW && ET, need id and mp_asize.
  //3. in R channel, no alen used.
  //4. if MP_DW <= SP_DW && no upsize, asize_sp = asize_mp.(save 3 bits).
  //5. if no locking sequence, no pre_xact signal used. ( save 1 bit).
  ///////////////////////////////////////////////////////////////////////
  parameter NO_ALTER   = `ubwc_x2x_X2X_TX_ALTER == `ubwc_x2x_X2X_TX_NO_ALTER;
  // spyglass disable_block W576
  // SMD: Logical operator used on a multibit value
  // SJ: X2X_HAS_ET is a parameter which can be set to 0 or 1. Since, parameter
  // is by default 32 bit, spyglass is considering it as a vector. Functionally
  // there will not be any issue as the result will be either 0 or 1.
  parameter RS_FK_BP   = NO_ALTER && `ubwc_x2x_X2X_HAS_ET;  //1 -> bypass RS but not bypass RS fifos.
                                                   //We need mp_asize and aid for endian transform.
  // spyglass enable_block W576
  parameter RS_BYPASS  = NO_ALTER && ((`ubwc_x2x_X2X_HAS_ET==0)); //1 -> bypass resizer
                           //and bypass RS fifos. Don't need info from AR channel.
  parameter NOUS_SP_L  = (MP_DW <= SP_DW) && ((TX_US==0)); //no US & SP larger
  parameter RS_FIFO_W  = RS_FK_BP ? (MP_IDW + 3) :
                         ( LOCKING ? ( NOUS_SP_L ? A_TRK_W + MP_IDW + 7 :
                         A_TRK_W + MP_IDW + 10 ) :
                         ( NOUS_SP_L ? A_TRK_W + MP_IDW + 6 :
                         A_TRK_W + MP_IDW + 9 ) );  //Resize FIFO width
  parameter DATA_W     = RS_FIFO_W;        //data width per FIFO
  parameter BUS_DATA_W = NUM_FIFOS*DATA_W; //real width of data signal

  input                  aclk;             //clk.
  input                  aresetn;          //reset.
  input [MP_IDW-1:0]     aid_i;           //ID from resize
  input [2:0]            asize_i;         //size from resize
  input [1:0]            aburst_i;        //burst type for xact
  input [A_TRK_W-1:0]    addr_i;          //start addr
  input                  pre_last_xact_i; //xact before last xact
  input                  last_rs_xact_i;  //last resize xact
  input [2:0]            asize_mp_i;      //MP asize for the xact
  input                  rs_push_req_n_i; //rs push enable, act low
  input                  rvalid_i;        //valid from AXI slave
  input [SPPLD_W-1:0]    rpayload_i;      //payload from AXI slave
  input                  rpush_full_i;    //read fifo push full flag

  // Outputs 
  output                 rs_push_full_o;  //push full flag to resizer
  output                 rpush_req_n_o;   //read FIFO push enable,act low
  output                 rready_o;        //ready signal to AXI slave
  output [MPPLD_W-1:0]   rpayload_o;      //payload to read FIFO


  wire [MPPLD_W-1:0]     rpayload_o;
  wire [NUM_FIFOS-1:0]   rs_bus_push_req_n;
  wire [NUM_FIFOS-1:0]   rs_bus_push_full;
  wire [NUM_FIFOS-1:0]   rs_bus_pop_empty;
  wire [BUS_DATA_W-1:0]  rs_bus_fifo_data;
  wire [NUM_FIFOS-1:0]   rs_bus_pop_req_n;
  wire [DATA_W-1:0]      rs_push_data;
  wire                   rs_push_full_o;
  wire                   rpush_req_n_o;
  wire                   rready_o;
  // These signals are used based on the RS_BYPASS parameter.
  wire [MPPLD_W-1:0]     rpayload_unbp;
  wire                   rs_push_full_unbp;
  wire                   pre_xact_fsh_unbp;
  wire                   rpush_req_n_unbp;
  wire                   rready_unbp;

  //mux bypass RS
  generate if (RS_BYPASS)
  begin
    assign rs_push_full_o = 1'b1;
    assign rpush_req_n_o  = !(rvalid_i & (~rpush_full_i));
    assign rready_o       = ~rpush_full_i;
    assign rpayload_o     = rpayload_i;
  end
  else
  begin
    assign rs_push_full_o = rs_push_full_unbp;
    assign rpush_req_n_o  = rpush_req_n_unbp;
    assign rready_o       = rready_unbp;
    assign rpayload_o     = rpayload_unbp;
  end
  endgenerate

  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : rs_push_full_unbp is read only when RS_BYPASS is set to 0.
  //Resize FIFO pusher
  ubwc_x2x_DW_axi_x2x_r_pusher
  
  #(`ubwc_x2x_X2X_MP_IDW,
    `ubwc_x2x_X2X_MAX_URIDA,
    RS_FIFO_W,
    NOUS_SP_L,
    RS_FK_BP,
    `ubwc_x2x_X2X_ADDR_TRK_W
  )
  U_read_rspusher (
    //inputs
    .aclk             ( aclk ),              //clock,
    .aresetn          ( aresetn ),           //reset, act low,
    .aid_i           ( aid_i ),            //ID from RS to RS FIFOs
    .asize_i         ( asize_i ),          //asize from RS to RS FIFOs
    .asize_mp_i      ( asize_mp_i ),       //MP asize from RS to RS FIFOs
    .aburst_i        ( aburst_i ),         //burst to RS fifos
    .addr_i          ( addr_i ),           //start addr
    .pre_last_xact_i ( pre_last_xact_i ),  //PreLastXact from RS to FIFOs
    .last_rs_xact_i  ( last_rs_xact_i ),   //LastRSXact from RS to FIFOs
    .push_req_n_i    ( rs_push_req_n_i ),  //RS push enable from RS
    .push_full_i     ( rs_bus_push_full ), //FIFOs full bus from FIFOs
    .pop_empty_i     ( rs_bus_pop_empty ), //FIFOs empty bus from FIFOs
    .fifo_data_i     ( rs_bus_fifo_data ), //FIFOs data bus from FIFOs

    // Outputs 
    .push_full_o     ( rs_push_full_unbp ),    //push full flag to RS
    .push_req_n_o    ( rs_bus_push_req_n ), //push enable bus to FIFOs
    .data_o          ( rs_push_data )       //push data to FIFOs
  );
  //spyglass enable_block W528

  //Resize FIFOs (single clock)
  ubwc_x2x_DW_axi_x2x_sp_r_rsfifos
  
  #(`ubwc_x2x_X2X_MAX_URIDA,
    RS_FIFO_W,
    `ubwc_x2x_X2X_MAX_RCA_ID,
    `ubwc_x2x_X2X_LOG2_MAX_RCA_ID,
    BUS_DATA_W
  )
  U_rsfifos (
    //inputs - push side
    .clk_i            ( aclk ),            //clock 
    .resetn_i         ( aresetn ),         //reset, act low
    .bus_push_req_n_i ( rs_bus_push_req_n ), //push enable bus to FIFOs
    .data_i           ( rs_push_data ),          //single FIFO data in 
    //outputs - push side
    .bus_push_full_o  ( rs_bus_push_full ),  //push full flag (bus)

    //inputs - pop side
    .bus_pop_req_n_i  ( rs_bus_pop_req_n ),  //pop enable bus to FIFOs
    // Outputs - pop side
    .bus_pop_empty_o  ( rs_bus_pop_empty ),  //pop empty flag (bus)
    .bus_data_o       ( rs_bus_fifo_data )   //multiple FIFOs data (bus)
  );

  //Resize fifo pop and read data packing
// In some configurations the pre_xact_fsh_o is tied to zero.
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : pre_xact_fsh_unbp is read only when X2X_LOCKING is defined. 
  ubwc_x2x_DW_axi_x2x_r_packer
  
  #(`ubwc_x2x_X2X_MAX_URIDA,
    NOUS_SP_L,
    RS_FK_BP,
    RS_FIFO_W
  )
  U_read_packer (
    .aclk            ( aclk ),              //clock
    .aresetn         ( aresetn ),           //reset, act low
    .rvalid_i       ( rvalid_i ),         //read valid from AXI slave
    .rpayload_i     ( rpayload_i ),       //read payload from AXI slave
    .rs_data_i      ( rs_bus_fifo_data ), //RS data bus from RS FIFOs
    .rs_pop_ept_i   ( rs_bus_pop_empty ), //RS FIFOs empty flag bus
    .push_full_i    ( rpush_full_i ),     //push full flag from read FIFO

  // Outputs 
    .pre_xact_fsh_o ( pre_xact_fsh_unbp ),   //PreLastXact complete to RS
    .rs_pop_req_n_o ( rs_bus_pop_req_n ), //RS pop enable bus to RS FIFOs
    .r_push_req_n_o ( rpush_req_n_unbp ),    //push enable to read FIFO
    .rready_o       ( rready_unbp ),         //read ready to AXI slave
    .rpayload_o     ( rpayload_unbp )        //read payload to read FIFO
  );
//spyglass enable_block W528
endmodule



