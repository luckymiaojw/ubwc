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
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_mp_wfc.v#7 $ 
//
/////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////
// ID maintain and reg active block (write fanout control) in AW of MP
/////////////////////////////////////////////////////////////////////////


`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_mp_wfc (
 //inputs
  aclk,
  aresetn,
  avalid_i,
  apayload_i,
  apush_full_i,
  bid_i,
  bvalid_i,
  bready_i,

 //outputs
  awid_o,
  awact_o,
  f_port_num_o,
  f_stall_o
);

  //parameters
  parameter AW_PLD_W  = `ubwc_x2x_X2X_AWPYLD_W_MP;       //AW payload width of MP
  parameter NUM_PORTS = `ubwc_x2x_X2X_NUM_W_PORTS;       //number of fanout ports
  parameter MP_IDW    = `ubwc_x2x_X2X_MP_IDW;            //ID width of MP
  parameter IDACTW    = `ubwc_x2x_X2X_MAX_WCA_ID_P1L2;   //width of per act ID
  parameter ID_LS     = `ubwc_x2x_X2X_AWPYLD_ID_LHS_MP;  //ID left side bit of MP
  parameter ID_RS     = `ubwc_x2x_X2X_AWPYLD_ID_RHS_MP;  //ID right side bit of MP
  parameter WCA_ID    = `ubwc_x2x_X2X_MAX_WCA_ID;        //number per active ID
  parameter BUS_ID_W  = NUM_PORTS * MP_IDW;     //MP ID width of BUS
  parameter BUS_IDACTW = NUM_PORTS * IDACTW;    //BUS width of  act ID
  //internal parameters
  parameter NUM_PORT_W = `ubwc_x2x_X2X_LOG2_NUM_W_PORTS; //port number width

  //inputs
  input                   aclk;         //clock
  input                   aresetn;      //reset, act low
  input                   avalid_i;     //valid signal from AXI master
  input [AW_PLD_W-1:0]    apayload_i;   //payload from AXI master
  input                   apush_full_i; //push full signal from AW FIFO
  input [MP_IDW-1:0]      bid_i;        //ID from B of MP
  input                   bvalid_i;     //valid from B of MP
  input                   bready_i;     //ready from B of MP
  
  //outputs
  output [BUS_ID_W-1:0]   awid_o;       //ID bus to W of MP 
  output [NUM_PORTS-1:0]  awact_o;      //port active flag
  output [NUM_PORT_W-1:0] f_port_num_o; //port # of current xact go thru
  output                  f_stall_o;    //stall signal to stop AW xact


  wire [NUM_PORT_W-1:0] f_port_num_o;      //port number for this xact
  wire                  f_stall_o;         //fanout stall
  reg [NUM_PORT_W-1:0]  f_match_port_num;  //port number for this xact
  reg [NUM_PORT_W-1:0]  f_free_port_num;   //port number for this xact
  reg                   f_match_stall;     //fanout stall
  reg                   f_free_stall;      //fanout stall
  wire [MP_IDW-1:0]     aid;               //aid to be held for use
  reg  [BUS_ID_W-1:0]   awid_r;            //registered BUS MP_IDW
  reg  [BUS_ID_W-1:0]   awid;              //BUS free ID value
  reg  [MP_IDW-1:0]     awid_b;            //catch temperary ID from 
                                           //registered ID for B channel.
                                           //If match B id and 
                                           //bvalid/bready, -1 xact num. 
  reg  [MP_IDW-1:0]     awid_a;            //catch temperary ID from
                                           //registered ID for A channel.
                                           //If match A id, +1 xact num.
  // Set to 0 as a wire if no fan out 
  // configured.

  reg  [BUS_IDACTW-1:0] awact_m1;          //-1 of act ID num if one reg
                                           //id matches B id.
  wire [BUS_IDACTW-1:0] awact_bus;         //act num per ID with bus.
  reg  [BUS_IDACTW-1:0] awact_p1;          //+1 of act ID num if one reg
                                           //id matches A id.
  reg  [BUS_IDACTW-1:0] awact_free;        //act ID num is 1 if one reg
                                           //is free and no the other
                                           //reg IDs match the aid.
  reg  [BUS_IDACTW-1:0] awact_r;           //reg bus act ID value
  reg  [IDACTW-1:0]     awact_tb;          //temperary awact value from
                                           //awact_r for bid_i.
  reg  [IDACTW-1:0]     awact_tm1;         //temperary value of awact_tb
                                           // - 1.
  reg  [IDACTW-1:0]     awact_tp1;         //temperary value 
  reg  [IDACTW-1:0]     awact_use3;        //held value of num of act ID
  reg  [IDACTW-1:0]     awact_cm1;         //catch per ID value from
                                           //awact_m1 to find matching
                                           //aid value.
  reg  [IDACTW-1:0]     awact_fm1;         //catch per ID value from
                                           //awact_m1 to find free reg
                                           //to locate aid value if no
                                           //matching reg ids.
  reg                   aid_match;         //AID match flag
  reg                   aid_free;          //AID free flag

  // Set to 0 as a wire if no fan out 
  // configured.
  reg  [NUM_PORTS-1:0]  awact_o;           //act or inact ID to W of MP
  reg  [BUS_ID_W-1:0]   awid_o;            //maintained ID to W of MP

  integer               i, j;

  // Remove all logic if write fan out is not configured to exist.

  //////////////////////////////////////////////////////////////////
  //get ID value from apayload_i from AXI master
  //////////////////////////////////////////////////////////////////
  assign aid = apayload_i[ID_LS:ID_RS];

  //////////////////////////////////////////////////////////////////////
  // if bid_i matches maintained ID value and bready_i and bvalid_i are
  //    are asserted, the ID xact completed, the corresponding ID number
  //    should be -1
  //////////////////////////////////////////////////////////////////////
  always @( bid_i or bready_i or bvalid_i or awid_r or awact_r ) begin
    awact_m1 = awact_r;

    for ( i=0; i<NUM_PORTS; i=i+1 ) begin
      for ( j=0; j<MP_IDW; j=j+1 )
        awid_b[j] = awid_r[i*MP_IDW+j];
      
      if ( (awid_b == bid_i) & bready_i & bvalid_i ) begin
        for ( j=0; j<IDACTW; j=j+1 )
          awact_tb[j] = awact_r[i*IDACTW+j];

        awact_tm1 = awact_tb - 1;

        for ( j=0; j<IDACTW; j=j+1 )
          awact_m1[i*IDACTW+j] = awact_tm1[j];
      end
    end
  end

  //////////////////////////////////////////////////////////////////////
  //If aid matches one maintained ID or there is a free ID port
  //   register, then this port is payload_o port to AXI slave and pass
  //   the port info (ID and active) to W of MP as well as push the
  //   port number to AW FIFO for use by SP AW.
  //////////////////////////////////////////////////////////////////////
  always @( apush_full_i or avalid_i or awid_r or aid or awact_m1 ) begin
    f_match_stall    = 1'b1;
    f_match_port_num = 0;
    aid_match        = 1'b0;
    awact_p1         = awact_m1;

    for ( i=0; i<NUM_PORTS; i=i+1 ) begin
      for ( j=0; j<MP_IDW; j=j+1 )
        awid_a[j] = awid_r[i*MP_IDW+j];

      for ( j=0; j<IDACTW; j=j+1 )
        awact_cm1[j] = awact_m1[i*IDACTW+j];

      if ( (awid_a == aid) &&
           (awact_cm1 != {IDACTW{1'b0}}) & avalid_i ) begin
        aid_match = 1'b1;

        //unfull, issue xact & awact_m1+1
        if ( !apush_full_i & (awact_cm1 < WCA_ID) ) begin
          awact_tp1   = awact_cm1 + 1;

          for ( j=0; j<IDACTW; j=j+1 )
            awact_p1[i*IDACTW+j] = awact_tp1[j];

          f_match_stall    = 1'b0;
          f_match_port_num = i;
        end
      end
    end
  end

  //get free ID location indicator
  always @( apush_full_i or avalid_i or awact_m1 or 
                      aid_match or aid or awid_r ) begin
    f_free_stall    = 1'b1;
    f_free_port_num = 0;
    aid_free        = 1'b0;
    awact_free      = awact_m1;
    awid            = awid_r;

    if ( !aid_match & !apush_full_i & !aid_free ) begin
      for ( i=0; i<NUM_PORTS; i=i+1 ) begin
        for ( j=0; j<IDACTW; j=j+1 )
          awact_fm1[j] = awact_m1[i*IDACTW+j];
  
        if ( (awact_fm1 == {IDACTW{1'b0}}) & avalid_i ) begin
          aid_free = 1'b1;

          for ( j=0; j<MP_IDW; j=j+1 )
            awid[i*MP_IDW+j] = aid[j];
  
          if ( !apush_full_i ) begin
            awact_free[i*IDACTW] = 1'b1;
            f_free_port_num      = i;
            f_free_stall         = 1'b0;
          end
        end
      end
    end
  end

  assign f_port_num_o = aid_match ? f_match_port_num : 
                        ( aid_free ? f_free_port_num : 0 );
  assign f_stall_o    = aid_match ? f_match_stall :
                        ( aid_free ? f_free_stall : 1'b1 );
  assign awact_bus    = aid_match ? awact_p1 :
                        ( aid_free ? awact_free : awact_m1 );

  //////////////////////////////////////////////////////////
  // reg ID value and awact_bus 
  //////////////////////////////////////////////////////////
  always @(posedge aclk or negedge aresetn ) begin
    if ( !aresetn ) begin
      awid_r   <= {BUS_ID_W{1'b0}};
      awact_r  <= {BUS_IDACTW{1'b0}};
    end
    else begin
      awid_r   <= awid;
      awact_r  <= awact_bus;
    end
  end

  //////////////////////////////////////////////////////////////
  // output to W of MP
  //////////////////////////////////////////////////////////////
  always @(awid or awact_bus ) begin
    for ( i=0; i<NUM_PORTS; i=i+1 ) begin
      for ( j=0; j<IDACTW; j=j+1 ) begin
        awact_o[i] = |awact_bus[i*IDACTW + j];
      end
    end

    awid_o  = awid;
  end

endmodule


