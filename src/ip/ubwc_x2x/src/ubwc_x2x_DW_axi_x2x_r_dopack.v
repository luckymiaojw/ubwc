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
// File Version     :        $Revision: #10 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_r_dopack.v#10 $ 
//
/////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////
// read data packing. 
// 1. compare the read ID with the RS FIFO's IDs. If match, packing.
//    If not, stall.
// 2. During packing, a register required to count down the number of
//    MP_ARSIZE/SP_ARSIZE. If it is zero, do push to read FIFO.
// 3. If it is the last resize xact, issue RLAST to 1.
// 4. After packing, do pop to the RS FIFO.
// 5. If upsize (fifo_asize_mp_i < fifo_asize_i), register last/resp/data
//   from slave. Meanwhile get number of fifo_asize_i/fifo_asize_mp_i &
//   organize first beat and push it to read FIFO. If the data reg empty,
//   assert rready. 
/////////////////////////////////////////////////////////////////////////

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_r_dopack (
  // Inputs 
  aclk,
  aresetn,
  rpayload_i,
  push_full_i,
  pop_empty_i,
  rvalid_i,
  fifo_data_i,
  
  // Outputs 
  pre_xact_fsh_o,
  rs_pop_req_n_o,
  r_push_req_n_o,
  rready_o,
  fifo_asize_mp_o,
  rpayload_o
);

  //parameters
  parameter DATA_W  = 16;                 //RS fifo width
  parameter NOUS_SP_L = 0;                //No upsize & SP DW larger
  parameter RS_FK_BP  = 0;                //fake bypass RS
  parameter MP_DW   = `ubwc_x2x_X2X_MP_DW;         //MP data width
  parameter SP_DW   = `ubwc_x2x_X2X_SP_DW;         //SP data width
  parameter MP_IDW  = `ubwc_x2x_X2X_MP_IDW;        //MP ID width
  parameter A_TRK_W = `ubwc_x2x_X2X_ADDR_TRK_W;    //start addr bits
  parameter SPPLD_W = `ubwc_x2x_X2X_RPYLD_W_SP;    //SP payload width
  parameter MPPLD_W = `ubwc_x2x_X2X_RPYLD_W_MP;    //MP payload width
  //internal
  parameter MP_1L2  = `ubwc_x2x_X2X_LOG2_MAX_MP_BYTES; //MP bytes 1log2
  parameter SP_1L2  = `ubwc_x2x_X2X_LOG2_MAX_SP_BYTES; //SP bytes 1log2
  parameter MP_DW_B = `ubwc_x2x_X2X_MAX_MP_BYTES;  //MP data width bytes
  parameter LOG2_MP = `ubwc_x2x_X2X_0LOG2_MAX_MP_BYTES; //MP LOG2 bytes
  parameter LOG2_SP = `ubwc_x2x_X2X_0LOG2_MAX_SP_BYTES; //SP LOG2 bytes
  parameter SP_DW_B = `ubwc_x2x_X2X_MAX_SP_BYTES;  //SP data width bytes
  parameter BG_BLW  = (`ubwc_x2x_X2X_MP_BLW > `ubwc_x2x_X2X_SP_BLW) ?
                      `ubwc_x2x_X2X_MP_BLW : `ubwc_x2x_X2X_SP_BLW; //bigger BLW
  parameter BIG_BLW = (SP_1L2+1) > BG_BLW ? (SP_1L2+1) : BG_BLW;
  parameter MP_T_SP = MP_DW_B / SP_DW_B;
  parameter SP_T_MP = SP_DW_B / MP_DW_B;
//  parameter LOG2_DR = LOG2_MP - LOG2_SP;
  parameter A_SP_DR = (A_TRK_W > LOG2_SP) ? (A_TRK_W - LOG2_SP) : 0;
  parameter A_MP_DR = (A_TRK_W > LOG2_MP) ? (A_TRK_W - LOG2_MP) : 0;

  // Inputs
  input               aclk;                //clk.
  input               aresetn;             //reset.
  input [SPPLD_W-1:0] rpayload_i;         //rpayload from slave
  input               push_full_i;        //push full flag from R FIFO
  input               pop_empty_i;        //pop empty flag from RS FIFO
  input               rvalid_i;           //rvaild
  input [DATA_W-1:0]  fifo_data_i;        //data from RS fifo
 
  // Outputs 
  output               pre_xact_fsh_o;     //pre last xact to AR
  output               rs_pop_req_n_o;     //pop enable to RS fifo
  output               r_push_req_n_o;     //push enable to R fifo
  output               rready_o;           //RREADY
  output [2:0]         fifo_asize_mp_o;    //asize for endian use
  output [MPPLD_W-1:0] rpayload_o;         //payload to R fifo

  reg                 pre_xact_fsh_o;
  reg                 rs_pop_req_n_o;
  reg                 r_push_req_n_o;
  reg                 rready_o;
  reg                 last_to_fifo_o;
  reg  [BIG_BLW-1:0]  div_num_r;
  reg  [A_TRK_W-1:0]  num_dw_size;
  reg  [A_TRK_W-1:0]  num_sp_beat_r;
  reg  [A_TRK_W-1:0]  num_sp_beat;
  reg  [A_TRK_W-1:0]  num_dw_size_r;
  reg  [A_TRK_W-1:0]  num_mp_beat;
  reg  [A_TRK_W-1:0]  num_mp_beat_r;
  reg  [1:0]          resp_to_fifo_r;
  reg  [1:0]          resp_to_fifo_o;
  reg  [MP_DW-1:0]    data_to_fifo_o;
  reg  [MP_DW-1:0]    data_to_fifo_r;
  reg  [BIG_BLW-1:0]  div_num;
  reg                 fixed_start_r;
  wire [MPPLD_W-1:0]  rpayload_o;
  wire                last_from_sp_i;     
  wire [1:0]          resp_from_sp_i;    
  wire [SP_DW-1:0]    data_from_sp_i;
  wire [MP_IDW-1:0]   rid_from_sp_i;
  wire  [2:0]         fifo_asize_mp_i;    //MP asize
  wire  [2:0]         fifo_asize_mp_o;    //MP asize
// This signal is used when !(RS_FK_BP || NOUS_SP_L)
  wire  [2:0]         fifo_asize_i;       //resize asize (SP)
// This signal is used when (RS_FK_BP) is set.

  reg  [1:0]          resp_to_fifo;
  wire  [2:0]         fifo_asize_s;       //resize asize (SP)
  wire  [A_TRK_W-1:0] fifo_addr_i;        //start addr
// if RS_FK_BP is set this signal is unused.
  wire                fifo_lastrsxact_i;  //last xact from RS
  wire  [1:0]         fifo_aburst_i;      //burst
  wire  [MP_IDW-1:0]  fifo_id_i;          //ID from RS

  //extract RS FIFO data
  
  generate if (RS_FK_BP)
    assign {fifo_asize_mp_i, fifo_id_i} = fifo_data_i[3+MP_IDW-1:0];
  else if ( NOUS_SP_L )
    assign {fifo_aburst_i, fifo_addr_i, fifo_lastrsxact_i,
            fifo_asize_mp_i, fifo_id_i}
          = fifo_data_i[2+A_TRK_W+1+3+MP_IDW-1:0];
  else
    assign  {fifo_aburst_i, fifo_addr_i, fifo_lastrsxact_i,
             fifo_asize_mp_i, fifo_asize_s, fifo_id_i}
           = fifo_data_i[2+A_TRK_W+1+3+3+MP_IDW-1:0];
  endgenerate


  //get sp asize
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : When RS_FK_BP = 1 then fifo_asize_i is grounded and not read.
  generate if (RS_FK_BP)
  begin
    assign fifo_asize_i = 3'b000;
  end
  else if (NOUS_SP_L)
    assign fifo_asize_i = fifo_asize_mp_i;
  else
    assign fifo_asize_i = fifo_asize_s;
  endgenerate
  //spyglass enable_block W528
  //fifo_asize_mp_o for endian
  assign fifo_asize_mp_o = fifo_asize_mp_i; //for endian use


  parameter [MP_1L2:0] SIZE_BYTES_CONST_1  = 1;
  parameter [MP_1L2:0] SIZE_BYTES_CONST_2  = 2;
  parameter [MP_1L2:0] SIZE_BYTES_CONST_4  = 4;
  parameter [MP_1L2:0] SIZE_BYTES_CONST_8  = 8;
  parameter [MP_1L2:0] SIZE_BYTES_CONST_16 = 16;
  parameter [MP_1L2:0] SIZE_BYTES_CONST_32 = 32;
  //function to tranform asize to bytes
  function automatic [MP_1L2:0] size_bytes;
    input [2:0]  asize;

    begin
      case ( asize )
        3'b001:  size_bytes = SIZE_BYTES_CONST_2;
        3'b010:  size_bytes = SIZE_BYTES_CONST_4;
        3'b011:  size_bytes = SIZE_BYTES_CONST_8;
        3'b100:  size_bytes = SIZE_BYTES_CONST_16;
        3'b101:  size_bytes = SIZE_BYTES_CONST_32;
        //default=3'b000
        default: size_bytes = SIZE_BYTES_CONST_1;
      endcase
    end
  endfunction

  //func to get 1st beat of mp per asize_mp for push
  function automatic [A_TRK_W-1:0] ds_push_num1;
    input [A_TRK_W-1:0] addr;     //start addr
    input [2:0]         asize;   //mp asize

    reg [A_TRK_W-1:0] tmp_addr;
    reg [A_TRK_W-1:0] zero_mask;
    begin
      zero_mask = {A_TRK_W{1'b1}} >> (`ubwc_x2x_X2X_ADDR_TRK_W - asize);
      tmp_addr = addr & zero_mask;
      ds_push_num1 = tmp_addr >> `ubwc_x2x_X2X_0LOG2_MAX_SP_BYTES;
    end
  endfunction

  //calculate MP beat number per asize_mp for push
  //when asize_mp == asize_sp
  function automatic [A_TRK_W-1:0] mp_num1;
    input [A_TRK_W-1:0] addr;     //start addr
    input [2:0]         asize;    //asize

    reg [A_TRK_W-1:0] tmp_addr;
    reg [A_TRK_W-1:0] zero_mask;

    begin
      zero_mask = {A_TRK_W{1'b1}} >> A_MP_DR;
      tmp_addr = addr & zero_mask;
      mp_num1 = tmp_addr >> asize;
    end
  endfunction

  //calculate SP beat number when asize_mp == asize_sp
  function automatic [A_TRK_W-1:0] sp_num1;
    input [A_TRK_W-1:0] addr;     //start addr
    input [2:0]         asize;    //asize

    reg [A_TRK_W-1:0] tmp_addr;
    reg [A_TRK_W-1:0] zero_mask;

    begin
      zero_mask = {A_TRK_W{1'b1}} >> A_SP_DR;
      tmp_addr = addr & zero_mask;
      sp_num1 = tmp_addr >> asize;
    end
  endfunction

  //func to get sp beat number
  function automatic [A_TRK_W-1:0] f_num_sp_beat;
    input [A_TRK_W-1:0] addr;     //start addr
    input [2:0]         asize;    //asize

    reg [A_TRK_W-1:0] zero_mask;
    begin
      zero_mask = {A_TRK_W{1'b1}} << asize;
      f_num_sp_beat = ( addr & zero_mask ) >> `ubwc_x2x_X2X_0LOG2_MAX_SP_BYTES;
    end
  endfunction

  //function to get ds_data_to_fifo for MP data lane
  function automatic [MP_DW-1:0] ds_mp_chip_data_out;
    input [A_TRK_W-1:0] num_beats;
    input [SP_DW-1:0]   data_in;
    input [MP_DW-1:0]   data_r;

    reg   [MP_DW-1:0]   data_tmp;
    integer             i, j, k;
    begin
      data_tmp = data_r;

      for ( i=0; i<MP_T_SP; i=i+1 ) begin //MP lane
        if ( num_beats == i ) begin
          for ( j=0; j<SP_DW; j=j+1 ) //j-->MP data
            data_tmp[i*SP_DW + j] = data_in[j]; 
        end
      end

      ds_mp_chip_data_out = data_tmp;
    end
  endfunction

  //function to get data_to_fifo for MP lanes
  function automatic [MP_DW-1:0] mp_chip_data_out;
    input [A_TRK_W-1:0] num_beats;
    input [2:0]         asize;
    input [SP_DW-1:0]   data_in;

    reg   [MP_DW-1:0]   data_tmp;
    integer             i, j, k;
    begin
      data_tmp = {MP_DW{1'b0}};

//spyglass disable_block W362
//SMD: Reports an arithmetic comparison operator with unequal length
//SJ : This is the intended design, the comparison result will be as per
//     the requirement. To have compact code for all configuration, the 
//     RTL is written as below. Hence this can be waived.
//spyglass disable_block SelfDeterminedExpr-ML
//SMD: Self determined expression present in the design.
//SJ : This arithmetic operation does not result in any issue.
      for ( i=0; i<MP_T_SP; i=i+1 ) begin //MP lane
        if ( (num_beats<<asize) >= (i<<LOG2_SP) &&
             (num_beats<<asize) < ((i+1)<<LOG2_SP) ) begin
          for ( j=0; j<SP_DW; j=j+1 ) //j-->MP data
            data_tmp[i*SP_DW + j] = data_in[j];
        end
      end
//spyglass enable_block SelfDeterminedExpr-ML
//spyglass enable_block W362

      mp_chip_data_out = data_tmp;
    end
  endfunction

  //This code is only used for configs with MP_DW < SP_DW so
  //turn off coverage for downsizing configs.
  //VCS coverage off

  //function to get data_to_fifo for SP lanes
  function automatic [MP_DW-1:0] sp_chip_data_out;
    input [A_TRK_W-1:0] num_beats;
    input [2:0]         asize;
    input [SP_DW-1:0]   data_in;

    reg   [MP_DW-1:0]   data_tmp;
    integer             i, j, k;

    begin
      data_tmp = {MP_DW{1'b0}};
//spyglass disable_block W362
//SMD: Reports an arithmetic comparison operator with unequal length
//SJ : This is the intended design, the comparison result will be as per
//     the requirement. To have compact code for all configuration, the 
//     RTL is written as below. Hence this can be waived.
      for ( i=0; i<SP_T_MP; i=i+1 ) begin //lanes
        if ( (num_beats<<asize) >= (i<<`ubwc_x2x_X2X_0LOG2_MAX_MP_BYTES) &&
//spyglass disable_block SelfDeterminedExpr-ML
//SMD: Self determined expression present in the design.
//SJ : This arithmetic operation does not result in any issue.
             (num_beats<<asize) < ((i+1)<<`ubwc_x2x_X2X_0LOG2_MAX_MP_BYTES) ) begin
//spyglass enable_block SelfDeterminedExpr-ML
          for ( j=0; j<MP_DW; j=j+1 ) //j-->bytes
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
            data_tmp[j] = data_in[i*MP_DW + j]; 
//spyglass enable_block SelfDeterminedExpr-ML
        end
      end
//spyglass enable_block W362

      sp_chip_data_out = data_tmp;
    end
  endfunction

  //function to get data_to_fifo for fixed SP lanes
  function automatic [MP_DW-1:0] fix_sp_chip_data_out;
    input [A_TRK_W-1:0] num_beats;
    input [2:0]         asize;
    input [SP_DW-1:0]   data_in;

    reg   [SP_DW-1:0]   data_tmp;
    reg   [A_TRK_W+8:0] mov_bits;

    begin
      data_tmp = {SP_DW{1'b0}};
      mov_bits = ({9'h000, num_beats}<<asize)<<3;

      data_tmp = data_in >> mov_bits;
      fix_sp_chip_data_out = {{(MP_DW-SP_DW){1'b0}}, data_tmp};
    end
  endfunction
  //VCS coverage on


  //response gen for downsize packing
  // spyglass disable_block W528
  // SMD: A signal or variable is set but never read.
  // SJ : fixed_start is read only when RS_FK_BP != 1
  always @( resp_from_sp_i or resp_to_fifo_r ) begin: RESP_FROM_SP_I_PROC
    if ( resp_to_fifo_r == `ubwc_x2x_X2X_RESP_DECERR || 
         resp_from_sp_i== `ubwc_x2x_X2X_RESP_DECERR )
      resp_to_fifo = `ubwc_x2x_X2X_RESP_DECERR;
    else if (resp_to_fifo_r == `ubwc_x2x_X2X_RESP_SLVERR || 
             resp_from_sp_i == `ubwc_x2x_X2X_RESP_SLVERR)
      resp_to_fifo = `ubwc_x2x_X2X_RESP_SLVERR;
    else if (resp_to_fifo_r == `ubwc_x2x_X2X_RESP_OKAY || 
             resp_from_sp_i == `ubwc_x2x_X2X_RESP_OKAY)
      resp_to_fifo = `ubwc_x2x_X2X_RESP_OKAY;
    else //resp_to_fifo0_r == 2'b01 || resp_from_sp_i == 2'b01
      resp_to_fifo = `ubwc_x2x_X2X_RESP_EXOKAY; //resp
    end
  // spyglass enable_block W528
  //extract data and controls from rpayload_i
  //rpayload_i = {rid, rdata, rresp, rlast}
  assign {           rid_from_sp_i, data_from_sp_i, resp_from_sp_i, last_from_sp_i}
         = rpayload_i;

  //register div_num, resp_to_fifo, data
  always @( posedge aclk or negedge aresetn ) begin: RESP_TO_FIFO_R_PROC
    if ( !aresetn ) begin
      resp_to_fifo_r <= 2'h1;
      data_to_fifo_r <= {MP_DW{1'b0}};
    end
    else begin
      if ( !r_push_req_n_o ) begin
        resp_to_fifo_r <= 2'b01;
        data_to_fifo_r <= {MP_DW{1'b0}};
      end
      else begin
        resp_to_fifo_r <= resp_to_fifo_o;
        data_to_fifo_r <= data_to_fifo_o;
      end
    end
  end

  parameter [BIG_BLW-1:0]  DIV_NUM_DFLT = 1;
  always @( posedge aclk or negedge aresetn ) begin: CTRL_PROC
    if ( !aresetn ) begin
      div_num_r      <= DIV_NUM_DFLT;
      num_dw_size_r  <= {A_TRK_W{1'b0}};
      num_sp_beat_r  <= {A_TRK_W{1'b0}};
      num_mp_beat_r  <= {A_TRK_W{1'b0}};
    end
    else begin
      div_num_r      <= div_num;
      num_dw_size_r  <= num_dw_size;
      num_sp_beat_r  <= num_sp_beat;
      num_mp_beat_r  <= num_mp_beat;
    end
  end

  //spyglass disable_block UndrivenInTerm-ML
  //SMD: Detects undriven but loaded input terminal of an instance
  //SJ : The fifo_aburst_i and fifo_lastrsxact_i are generated and used when the configuration is other RS_FK_BP = 1.
  //     This will not affect the design, as this fifo_aburst_i and fifo_lastrsxact_i signals are driven in the required 
  //     configuration. Hence this can be waived.
  //spyglass disable_block UndrivenNet-ML
  //SMD: Detects undriven but loaded input terminal of an instance
  //SJ : Refer previous SJ
  //spyglass disable_block W123
  //SMD: Detects undriven but loaded input terminal of an instance
  //SJ : The fifo_aburst_i and fifo_lastrsxact_i are generated and used when the configuration is other RS_FK_BP = 1.
  //     This will not affect the design, as this fifo_aburst_i and fifo_lastrsxact_i signals are driven in the required 
  //     configuration. Hence this can be waived.
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : fixed_start is read only when RS_FK_BP != 1.
  //spyglass disable_block TA_09
  //SMD: Reports cause of uncontrollability or unobservability and estimates the number of nets whose controllability / observability is impacted.
  //SJ : The fifo_aburst_i and fifo_lastrsxact_i are generated and used when the configuration is other RS_FK_BP = 1.
  //     This will not affect the design, as this fifo_aburst_i and fifo_lastrsxact_i signals are driven in the required 
  //     configuration. For other configurations its undriven.
  always @( posedge aclk or negedge aresetn ) begin: FIFO_ABURST_PROC
    if ( !aresetn ) fixed_start_r <= 1'b0;
    else begin
      if ( rid_from_sp_i == fifo_id_i & rvalid_i & (!pop_empty_i) &
           fifo_aburst_i == `ubwc_x2x_X2X_BT_FIXED & last_from_sp_i &
           fifo_lastrsxact_i & (!push_full_i))
        fixed_start_r <= 1'b0;
      else if ( rid_from_sp_i == fifo_id_i & rvalid_i & (!pop_empty_i) &
           fifo_aburst_i == `ubwc_x2x_X2X_BT_FIXED & last_from_sp_i &
           (!push_full_i) )
        fixed_start_r <= 1'b1;
    end
  end
  //spyglass enable_block TA_09
  //spyglass enable_block W528
  //spyglass enable_block W123
  //spyglass enable_block UndrivenNet-ML
  //spyglass enable_block UndrivenInTerm-ML

  //do packing
  generate if ( RS_FK_BP ) begin //no_alter but ET
  always @(*) begin: CTRL_SIG_PROC

    pre_xact_fsh_o = 1'b0;
    rs_pop_req_n_o = 1'b1;
    r_push_req_n_o = 1'b1;
    rready_o       = 1'b0;
    last_to_fifo_o = 1'b0;
    div_num        = div_num_r;
    resp_to_fifo_o = resp_to_fifo_r;
    data_to_fifo_o = data_to_fifo_r;
    num_dw_size    = num_dw_size_r;
    num_sp_beat    = num_sp_beat_r;
    num_mp_beat    = num_mp_beat_r;

//    if ( RS_FK_BP ) begin //no_alter but ET
    if ( {rid_from_sp_i, 1'b0, rvalid_i} ==
         {fifo_id_i, pop_empty_i, 1'b1} ) begin
    if ( !push_full_i ) begin
      rready_o      = 1'b1;
      r_push_req_n_o = 1'b0;
      resp_to_fifo_o = resp_from_sp_i; //resp
      data_to_fifo_o = {{(MP_DW-SP_DW){1'b0}}, data_from_sp_i}; //data
      last_to_fifo_o = last_from_sp_i; //last

      if ( last_from_sp_i ) //last signal of R xact
        rs_pop_req_n_o = 1'b0; //enable the next xact
      end
    end
  end // end always
  end // end generate if
    // Don't collect coverage of this branch if there
    // is no downsizing in the configuration.
  else // generate else
  always @(*) begin: CTRL_SIG1_PROC
    pre_xact_fsh_o = 1'b0;
    rs_pop_req_n_o = 1'b1;
    r_push_req_n_o = 1'b1;
    rready_o       = 1'b0;
    last_to_fifo_o = 1'b0;
    div_num        = div_num_r;
    resp_to_fifo_o = resp_to_fifo_r;
    data_to_fifo_o = data_to_fifo_r;
    num_dw_size    = num_dw_size_r;
    num_sp_beat    = num_sp_beat_r;
    num_mp_beat    = num_mp_beat_r;

    if ( fifo_asize_mp_i >= fifo_asize_i ) begin //downsize
      //look for match ID and not empty
      if ( {rid_from_sp_i, 1'b0, rvalid_i} ==
           {fifo_id_i, pop_empty_i, 1'b1} ) begin
        if ( fifo_asize_mp_i == fifo_asize_i ) begin //no packing
          data_to_fifo_o = {MP_DW{1'b0}};

          if ( !push_full_i ) begin //read FIFO not full
            rready_o      = 1'b1;
            r_push_req_n_o = 1'b0;
            resp_to_fifo_o = resp_from_sp_i; //resp

            //count beat number per xact
            if ( last_from_sp_i )
              div_num = DIV_NUM_DFLT;
            else
              div_num = div_num_r + 1;

            //calculate MP beat number per asize_mp for push
            if ( div_num_r == 1 || fifo_aburst_i == `ubwc_x2x_X2X_BT_FIXED )
              num_mp_beat = mp_num1(fifo_addr_i,fifo_asize_mp_i);
            else if ((num_mp_beat_r + 1) == 
                     (`ubwc_x2x_X2X_MAX_MP_BYTES >> fifo_asize_mp_i)) 
              num_mp_beat = {A_TRK_W{1'b0}};
            else
              num_mp_beat = num_mp_beat_r + 1;
               
            //calculate SP beat number
            if ( div_num_r == 1 || fifo_aburst_i == `ubwc_x2x_X2X_BT_FIXED )
              num_sp_beat = sp_num1(fifo_addr_i,fifo_asize_i);
            else if ((num_sp_beat_r + 1) == 
                    (`ubwc_x2x_X2X_MAX_SP_BYTES >> fifo_asize_i))
              num_sp_beat = {A_TRK_W{1'b0}};
            else
              num_sp_beat = num_sp_beat_r + 1;

            //data
            //need to get lanes to handle data copying
            //SP_DW >= MP_DW, then SP has lanes.
            //MP_DW > SP_DW, then MP has lanes.
              data_to_fifo_o = mp_chip_data_out(num_mp_beat, fifo_asize_mp_i, data_from_sp_i);

            if ( last_from_sp_i ) begin  //last signal of RS xact
              rs_pop_req_n_o = 1'b0; //enable the next xact
  
  
              if ( fifo_lastrsxact_i ) //real last xact to master
                last_to_fifo_o = 1'b1;
            end //if ( last_from_sp_i
          end //if ( !push_full_i 
        end //if ( fifo_asize_mp_i
        else begin //fifo_asize_mp_i > fifo_asize_i (downsize packing)
          if ( !push_full_i ) begin  //read FIFO not full
            //count beat number per xact
            if ( last_from_sp_i )
              div_num = DIV_NUM_DFLT;
            else
              div_num = div_num_r + 1;
            //calculate MP beat number per asize_mp for push
            if ( div_num_r == 1 && fifo_aburst_i != `ubwc_x2x_X2X_BT_FIXED )
              num_dw_size = ds_push_num1(fifo_addr_i,fifo_asize_mp_i);
            //spyglass disable_block SelfDeterminedExpr-ML
            //SMD: Self determined expression present in the design.
            //SJ : This arithmetic operation does not result in any issue.
            else if ( (fifo_aburst_i == `ubwc_x2x_X2X_BT_FIXED) &&
                     ( (div_num_r == 1 && (!fixed_start_r)) ||
                     ( (num_mp_beat_r + 1) >= (num_sp_beat +
                 (size_bytes(fifo_asize_mp_i) >> `ubwc_x2x_X2X_0LOG2_MAX_SP_BYTES)) ) ) )
            //spyglass enable_block SelfDeterminedExpr-ML
              num_dw_size = ds_push_num1(fifo_addr_i,fifo_asize_mp_i);
            else if ((num_dw_size_r + 1) ==
                 (size_bytes(fifo_asize_mp_i) >> `ubwc_x2x_X2X_0LOG2_MAX_SP_BYTES))
              num_dw_size = {A_TRK_W{1'b0}};
            else
              num_dw_size = num_dw_size_r + 1;

            //calculate base MP beat number
            if ( div_num_r == 1 )
              num_sp_beat = f_num_sp_beat(fifo_addr_i,fifo_asize_mp_i); 
            else
              num_sp_beat = num_sp_beat_r;

            //calculate MP beat number to locate the moving bits
            if ( div_num_r == 1 && fifo_aburst_i != `ubwc_x2x_X2X_BT_FIXED ) begin
             // spyglass disable_block W164b
             // SMD: Identifies assignments in which the LHS width is greater than the RHS width
             // SJ : This is not a functional issue, this is as per the requirement.
             //      Hence this can be waived.
               num_mp_beat = fifo_addr_i[LOG2_MP-1:LOG2_SP];
             // spyglass enable_block W164b
            end
            //spyglass disable_block SelfDeterminedExpr-ML
            //SMD: Self determined expression present in the design.
            //SJ : This arithmetic operation does not result in any issue.
            else if ( (fifo_aburst_i == `ubwc_x2x_X2X_BT_FIXED) &&
                     ( (div_num_r == 1 && (!fixed_start_r)) ||
                     ( (num_mp_beat_r + 1) >= (num_sp_beat +
                 (size_bytes(fifo_asize_mp_i) >> `ubwc_x2x_X2X_0LOG2_MAX_SP_BYTES)) ) ) ) begin
            //spyglass enable_block SelfDeterminedExpr-ML
             // spyglass disable_block W164b
             // SMD: Identifies assignments in which the LHS width is greater than the RHS width
             // SJ : This is not a functional issue, this is as per the requirement.
             //      Hence this can be waived.
              num_mp_beat = fifo_addr_i[LOG2_MP-1:LOG2_SP];
             // spyglass enable_block W164b
            end
            else if ((num_mp_beat_r + 1) ==
                    (MP_DW_B >> LOG2_SP))
              num_mp_beat = {A_TRK_W{1'b0}};
            else
              num_mp_beat = num_mp_beat_r + 1;
  
            //fifo_asize_mp_i > fifo_asize_i, MP_DW > SP_DW
            //MP has lanes
            data_to_fifo_o = ds_mp_chip_data_out( num_mp_beat,
                             data_from_sp_i, data_to_fifo_r);

            rready_o = 1'b1; //rready per cycle
  
            //resp
            resp_to_fifo_o = resp_to_fifo;
           
            //packing data fills, do push
            if ((num_dw_size + 1) == 
                (size_bytes(fifo_asize_mp_i) >> `ubwc_x2x_X2X_0LOG2_MAX_SP_BYTES)) begin
              r_push_req_n_o = 1'b0;
            end
  
            if ( last_from_sp_i ) begin //last signal of RS xact
              rs_pop_req_n_o = 1'b0;    //enable the next xact
  
  
              if ( fifo_lastrsxact_i )  //real last xact to master
                last_to_fifo_o = 1'b1;
            end //if ( last_from_sp_i
          end //if ( !push_full_i
        end //else begin //downsize packing
      end //if ( {rid_from_sp_i
    end //if ( fifo_asize_mp_i >= fifo_asize_i
    else begin //fifo_asize_mp_i < fifo_asize_i (upsize)
      // Upsizing logic, turn off coverage for downsizing configs.
      //VCS coverage off

      //look for match ID and not empty
      if ( {rid_from_sp_i, 1'b0} == {fifo_id_i, pop_empty_i} ) begin
        if (!push_full_i && div_num_r == 2 && rvalid_i) //1st beat to MP
          rready_o = 1'b1;

        //get resp/data
        if ( (rvalid_i && div_num_r == 1) || (div_num_r > 1) ) begin
          data_to_fifo_o = {MP_DW{1'b0}};


          if ( !push_full_i ) begin  //read FIFO not full
            //create number of sp_dw_bytes/mp_asize
            if ( div_num_r == 1 )
              div_num = `ubwc_x2x_X2X_MAX_SP_BYTES >> fifo_asize_mp_i;
            else
              div_num = div_num_r - 1;

            //calculate SP active bytes
            if ( rvalid_i && div_num_r == 1 )
              num_sp_beat = {A_TRK_W{1'b0}};
            else
              num_sp_beat = num_sp_beat_r + 1;

            //data
            //in upsize, because of aligned, SP data low part moves to
            //MP low part of data.Given SP data/lanes/bytes,
            //do bits moving
            if ( fifo_aburst_i == `ubwc_x2x_X2X_BT_FIXED ) begin
              data_to_fifo_o = fix_sp_chip_data_out(num_sp_beat,
                               fifo_asize_mp_i, data_from_sp_i);
            end
            else
              data_to_fifo_o = sp_chip_data_out(num_sp_beat, 
                               fifo_asize_mp_i, data_from_sp_i);

            //resp
            resp_to_fifo_o = resp_from_sp_i;
            r_push_req_n_o = 1'b0; //do push per cycle

            //reg data empty
            if ( div_num_r == 2 ) begin
              if ( last_from_sp_i ) begin    //last signal of RS xact
                rs_pop_req_n_o = 1'b0;       //enable the next xact


                if ( fifo_lastrsxact_i )    //real last xact to master
                  last_to_fifo_o = 1'b1;
              end //if ( last_from_sp_i
            end //if ( div_num_r 
          end //if ( !push_full_i )
        end //if ( (rvalid_i && div_num_r
      end //if ( {rid_from_sp, 1'b0}
    end //else begin //fifo_asize_mp_i < fifo_asize_i (upsize)

    // Upsizing logic, turn off coverage for downsizing configs.
    //VCS coverage on

  end //always
  endgenerate

  //cocantenate rpayload_o to R fifo
  assign  rpayload_o =
          {           rid_from_sp_i, data_to_fifo_o, 
           resp_to_fifo_o, last_to_fifo_o};

endmodule


