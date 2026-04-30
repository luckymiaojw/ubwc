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
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_ue.v#8 $ 
//
/////////////////////////////////////////////////////////////////////////

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

/////////////////////////////////////////////////////////////////////////
// Upsizing enable signal generation
/////////////////////////////////////////////////////////////////////////

module ubwc_x2x_DW_axi_x2x_ue (
 //inputs
  addr_i,
  alen_i,
  asize_i,
  
 //outputs
  xact_upsize_o 
);

  //parameters
  parameter MAX_ASIZE_S = (`ubwc_x2x_X2X_MAX_SP_ASIZE > 0) ? `ubwc_x2x_X2X_MAX_SP_ASIZE : 1; //ByteSize-->BurstSize

  //inputs
  input  [MAX_ASIZE_S-1:0]      addr_i;        //master address
  input  [`ubwc_x2x_X2X_MP_BLW-1:0]      alen_i;        //MP burst length
  input  [2:0]                  asize_i;       //master asize
  
  //outputs
  output                        xact_upsize_o; //pop enable, act low

  //Upsize enable signal
  wire              unalign_bit;
  wire              xact_upsize_o; //1-->upsize; 0-->no
  wire              beat_integer;

  ///////////////////////////////////////////////////////////////////////
  //Upsizing enable.
  //If `ubwc_x2x_X2X_TX_UPSIZE & ( `ubwc_x2x_X2X_MP_DW < `ubwc_x2x_X2X_SP_DW ) &
  //MP_TOTAL_BYTES is integer of `ubwc_x2x_X2X_SP_DW/8 &
  //MP data width aligned to SP data width
  ///////////////////////////////////////////////////////////////////////
  //spyglass disable_block TA_09
  //SMD: Reports cause of uncontrollability or unobservability and estimates the number of nets whose controllability / observability is impacted. 
  //SJ : Tool will issue unobservability warning only for those bits which are "not read" or "floating". Since we are not reading those bits we don't need observability. Hence waiving this warning.
  assign beat_integer = ((( alen_i + 1 ) << asize_i ) % 
                         `ubwc_x2x_X2X_MAX_SP_BYTES) == 0; //integer
  //spyglass enable_block TA_09
  //check aligned bits from start addr_i
  generate if (MAX_ASIZE_S==1)
    assign unalign_bit = (MAX_ASIZE_S > asize_i) ? {addr_i[MAX_ASIZE_S-1:0] >> asize_i} : 1'b1; //1-->unaligned, 0-->aligned
  else
    assign unalign_bit = (MAX_ASIZE_S > asize_i) ? |{addr_i[MAX_ASIZE_S-1:0] >> asize_i} : 1'b1; //1-->unaligned, 0-->aligned
  endgenerate

  //if ANY_ASIZE true and upsize conditions meet, do upsize.
  //if ANY_ASIZE false and if upsize conditions meet and asize_i
  //equals LOG2_MP_SW, do upsize.
  // spyglass disable_block STARC05-2.10.2.3
  // SMD: Do not perform logical negation on vectors.
  // SJ: X2X_UPSIZE_ANY_ASIZE is a parameter which can be set to 0 or 1. Since, parameter
  // is by default 32 bit, spyglass is considering it as a vector. Functionally
  // there will not be any issue as negation of it will be either 0 or 1
  // spyglass disable_block W576
  // SMD: Do not perform logical negation on vectors.
  // SJ: X2X_UPSIZE_ANY_ASIZE is a parameter which can be set to 0 or 1. Since, parameter
  // is by default 32 bit, spyglass is considering it as a vector. Functionally
  // there will not be any issue as negation of it will be either 0 or 1
  assign xact_upsize_o = ( `ubwc_x2x_X2X_UPSIZE_ANY_ASIZE | 
                           (!`ubwc_x2x_X2X_UPSIZE_ANY_ASIZE & (`ubwc_x2x_X2X_LOG2_MP_SW == asize_i)) ) &
                           `ubwc_x2x_X2X_HAS_TX_UPSIZE& ( `ubwc_x2x_X2X_MP_DW < `ubwc_x2x_X2X_SP_DW ) &
                           beat_integer & (!unalign_bit);
  // spyglass enable_block W576
  // spyglass enable_block STARC05-2.10.2.3

endmodule



