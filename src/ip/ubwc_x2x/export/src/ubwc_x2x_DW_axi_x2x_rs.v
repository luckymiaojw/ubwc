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
// File Version     :        $Revision: #12 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_rs.v#12 $ 
//
/////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////
// Resizer
/////////////////////////////////////////////////////////////////////////

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_rs (
 //inputs
  aclk,
  aresetn,
  aid_i,
  addr_i,
  alen_i,
  asize_i,
  aburst_i,
  alock_i,
  acache_i,
  aprot_i,
  asideband_i,
  aready_i,
  rs_fifo_full_i,
  addrfifo_ept_i,
  
 //outputs
  aid_o,
  addr_o,
  addr_rs_o,
  alen_o,
  asize_o,
  asize_mp_o,
  aburst_o,
  alock_o,
  acache_o,
  aprot_o,
  asideband_o,
  avalid_o,
  pre_last_xact_o,
  last_rs_xact_o,
  rs_push_req_n_o,
  aready_o,
  wip_block_o,
  xact_upsize_o,
  pop_req_n_o 
);

  //parameters
  parameter [0:0] WRITE_CHANNEL     = 0;                  //write = 1, read = 0
  parameter A_SBW             = 8;                  //sideband width
//  parameter X2X_TX_UPSIZE     = `ubwc_x2x_X2X_HAS_TX_UPSIZE; //upsize = 1
  parameter A_TRK_W           = `ubwc_x2x_X2X_ADDR_TRK_W;  //addr bits to RS FIFO
  parameter MAX_MP_ALEN       = `ubwc_x2x_X2X_MAX_MP_ALEN+1;//{`ubwc_x2x_X2X_MP_BLW{1b1}}+1
  parameter MP_BLW            = `ubwc_x2x_X2X_MP_BLW;      //MP burst length width
  parameter MP_IDW            = `ubwc_x2x_X2X_MP_IDW;      //MP ID width
  parameter INT_AW            = `ubwc_x2x_X2X_INTERNAL_AW; //Internal address widt
  parameter INT_BW            = `ubwc_x2x_X2X_INTERNAL_BW; //Internal boundary
                                                  //width
  parameter SP_BLW            = `ubwc_x2x_X2X_SP_BLW;      //SP burst length width
  parameter MAX_SP_ALEN       = `ubwc_x2x_X2X_MAX_SP_ALEN+1;//{`ubwc_x2x_X2X_SP_BLW{1b1}}+1
  parameter LOG2_MP_SW        = (`ubwc_x2x_X2X_LOG2_MP_SW > 0) ?
                                `ubwc_x2x_X2X_LOG2_MP_SW : 1;   //log2^MP_SW
  parameter MAX_MP_ASIZE      = `ubwc_x2x_X2X_MAX_MP_ASIZE; //bytes -> asize
  parameter MAX_SP_ASIZE      = `ubwc_x2x_X2X_MAX_SP_ASIZE; //bytes -> asize
  parameter MAX_SP_TOTAL_BYTE = `ubwc_x2x_X2X_MAX_SP_TOTAL_BYTE; //max_sp_asize *
                                                        //max_alen
  parameter MAX_MP_TOTAL_BYTE = `ubwc_x2x_X2X_MAX_MP_TOTAL_BYTE; //max_mp_asize *
                                                        //max_alen
  parameter LOG2_BIG_SW       = (`ubwc_x2x_X2X_LOG2_MP_SW >= `ubwc_x2x_X2X_LOG2_SP_SW) ?
                                 `ubwc_x2x_X2X_LOG2_MP_SW : `ubwc_x2x_X2X_LOG2_SP_SW;
  parameter LOG2_BIG_BW       = LOG2_BIG_SW + SP_BLW;
  parameter LOG2_MP_BW        = LOG2_MP_SW + MP_BLW;
  parameter LOG2_MS_BW        = LOG2_MP_SW + SP_BLW;
  parameter MAX_ASIZE_S       = `ubwc_x2x_X2X_MAX_SP_ASIZE; //ByteSize-->BurstSize
  parameter OPRT_AW           = (`ubwc_x2x_X2X_LOG2_SP_BYTE > INT_BW) ?
                                (`ubwc_x2x_X2X_LOG2_SP_BYTE + 1) : (INT_BW + 1);
                                                   //OPERATING ADDRESS
  parameter RDC_NUM_W         = (LOG2_MP_SW > MAX_ASIZE_S) ?
                                LOG2_MP_SW - MAX_ASIZE_S : 1;
                                                   //reduce_num width
  parameter NO_ALTER      = `ubwc_x2x_X2X_TX_ALTER == `ubwc_x2x_X2X_TX_NO_ALTER;
  // spyglass disable_block W576
  // SMD: Logical operator used on a multibit value
  // SJ: X2X_HAS_ET is a parameter which can be set to 0 or 1. Since, parameter
  // is by default 32 bit, spyglass is considering it as a vector. Functionally
  // there will not be any issue as the result will be either 0 or 1.
  parameter RS_FK_BP      = NO_ALTER && `ubwc_x2x_X2X_HAS_ET;  //1->need to push
                                //mp_asize and aid to RS fifos for
                                //endian transform in data channels
  // spyglass enable_block W576
  //parameter ET_BYPASS     = NO_ALTER && (!(`ubwc_x2x_X2X_HAS_ET)); //1->bypass ET,
  parameter ET_BYPASS     = NO_ALTER && ((`ubwc_x2x_X2X_HAS_ET==0)); //1->bypass ET,
                                //no need to push data to RS fifos
  parameter RS_BYPASS     = RS_FK_BP | ET_BYPASS; //1->bypass RS,
                                //but not bypass RS fifos. we might
                                //push data to RS fifos for ET.
  parameter [0:0] SPALEN_LRG_MP     = MAX_SP_ALEN >= MAX_MP_ALEN;
                                             //1 -> MAX SP ALEN larger
  parameter [0:0] SPSIZE_LRG_MP     = MAX_SP_ASIZE >= MAX_MP_ASIZE;
                                             //1 -> MAX SP SIZE larger
  parameter [0:0] SPBYTE_LRG_MP     = MAX_SP_TOTAL_BYTE >= MAX_MP_TOTAL_BYTE;
                                             //1 -> MAX SP bytes larger
  parameter [0:0] PL                = `ubwc_x2x_X2X_HAS_PIPELINE; //pipeline

  //inputs
  input                aclk;            //clk
  input                aresetn;         //reset, active low
  input  [MP_IDW-1:0]  aid_i;           //master ID
  input  [INT_AW-1:0]  addr_i;          //master address
  input  [MP_BLW-1:0]  alen_i;          //MP burst length
  input  [2:0]         asize_i;         //master asize
  input  [1:0]         aburst_i;        //master burst
  input  [1:0]         alock_i;         //master lock
  input  [3:0]         acache_i;        //master cache
  input  [2:0]         aprot_i;         //master prot
  input  [A_SBW-1:0]   asideband_i;     //sideband
  input                aready_i;        //ready from AXI slave
  input                rs_fifo_full_i;  //resize fifo full
  input                addrfifo_ept_i;  //addr FIFO empty
  
  //outputs
  output [MP_IDW-1:0]  aid_o;           //ID to slave
  output [INT_AW-1:0]  addr_o;          //slave address
  output [A_TRK_W-1:0] addr_rs_o;       //addr to RS FIFOs
  output [SP_BLW-1:0]  alen_o;          //SP burst length
  output [2:0]         asize_o;         //slave asize
  output [2:0]         asize_mp_o;      //MP asize for read data packing
  output [1:0]         aburst_o;        //slave burst
  output [1:0]         alock_o;         //slave lock
  output [3:0]         acache_o;        //cache to slave
  output [2:0]         aprot_o;         //prot to slave
  output [A_SBW-1:0]   asideband_o;     //sideband
  output               avalid_o;        //valid to AXI slave
  output               pre_last_xact_o; //xact pre last xact to RS FIFO
  output               last_rs_xact_o;  //last resize xact to RS FIFO
  output               rs_push_req_n_o; //push enable to RS FIFO, act low
  output               aready_o;        //from aready_in for write interl
  output               wip_block_o;     //block same id xact
  output               xact_upsize_o;   //upsize enable, 1 -> upsize
  output               pop_req_n_o;     //pop enable, act low

  //temp calculation results
  reg  [2:0]           resize_ctrl;
  reg  [2:0]           mp_asize_mux;
  reg  [LOG2_BIG_BW:0] max_sp_total_byte_mux;
  wire [MP_BLW:0]      mp_alen;
  wire [LOG2_MP_BW:0]  mp_total_byte;
  wire [OPRT_AW-1:0]   bound_addr;
  wire [INT_BW-1:0]    tmp_bound_addr;
  wire                 wrap_from_bound;
  wire [LOG2_MS_BW:0]  max_sp_mpasize_total_byte;

  //outputs and their registers from inputs
  reg  [2:0]         asize_mp_o;
  reg  [MP_IDW-1:0]  aid_o;
  wire [INT_AW-1:0]  addr_o;   
  wire [SP_BLW-1:0]  alen_o;    
  wire [2:0]         asize_o;    
  wire [1:0]         aburst_o;
  wire [1:0]         alock_o;
  wire [OPRT_AW-1:0] addr_unbp;   
  wire [SP_BLW-1:0]  alen_unbp;    
  reg  [2:0]         asize_unbp;    
  reg  [1:0]         aburst_unbp;
  reg  [1:0]         alock_unbp;
  wire               pre_last_xact_unbp;
  reg                rs_push_req_n_unbp;
  reg                last_rs_xact_unbp;     //output to RS FIFO
  wire [A_TRK_W-1:0] addr_rs_unbp;
  wire [1:0]         alock_s;  //to catch locked sequence of last xact
  wire [1:0]         alock_ss; //to catch locked sequence of last xact
  wire [1:0]         alock_sss;//to catch locked sequence of last xact
  reg  [3:0]         acache_o;
  reg  [2:0]         aprot_o;
  wire               avalid_o;
  wire               pre_last_xact_o;
  wire               last_rs_xact_o;     //output to RS FIFO
  wire               last_rs_xact_ctl;   //used to control State machine
  reg                last_rs_xact_ctl_r;
  wire               rs_push_req_n_o;
  wire               pop_req_n_o;
  reg                pop_req_n_unbp;
  reg                avalid_unbp;
  reg                pop_req_n_unbp_r;
  wire [A_TRK_W-1:0] addr_rs_o;
  wire [A_SBW-1:0]   asideband_o;

  //temp results and registered
  wire              aready_in;
  wire              xact_stall;
  // jstokes, 7.8.10, crm 9000406128, added 1 bit to this signal to
  // fix bug downsizing wrap transactions which wrap at 4k boundary.
  wire [OPRT_AW:0]   total_addr_s;   
  // jstokes, 7.8.10, crm 9000406128, added 1 bit to this signal to
  // fix bug downsizing wrap transactions which wrap at 4k boundary.
  wire [LOG2_MP_BW:0] total_alen_s;    
  reg  [LOG2_MP_BW:0] total_alen_r;    
  reg  [OPRT_AW:0] total_addr_r;   
  reg                 wait_for_tx_r;
  reg               issued_aready_r;
  reg  [LOG2_MP_BW:0] pre_ran_num_bytes_r;
  reg  [LOG2_MP_BW:0] pre_ran_num_bytes_s;
  reg               issued_tx_r;
  reg  [RDC_NUM_W-1:0] reduce_num_r;
  wire [LOG2_MP_BW:0] total_remain_bytes;
  wire [LOG2_MP_BW:0] pre_ran_num_bytes;
  wire [LOG2_MP_BW:0] deduct_ran_num_bytes;
  wire [LOG2_BIG_BW:0] total_byte_mux;
  //Tx issued enable
  wire              issued_tx;
  //Upsize enable signal
  wire              xact_upsize; //1-->upsize; 0-->no
  wire              xact_upsize_o; //1-->upsize; 0-->no
  wire              ue_xact_upsize; //1-->upsize; 0-->no
  //aligned address
  reg  [OPRT_AW-1:0] aligned_addr;
  //unaligned uncount downsize xact number
  wire [RDC_NUM_W-1:0] mxin_reduce_num;
  wire [RDC_NUM_W-1:0] reduce_num;
  wire [LOG2_MP_SW-1:0] rn_mask; // Mask used in generation of
                                 // reduce_num.
  wire [LOG2_MP_SW-1:0] tmp_addr;
  wire [LOG2_MP_SW-1:0] tmp_num;
  reg  [LOG2_MP_SW:0] align_mask; //mask align addr
  //case control
  wire [1:0]        aburst_in;
  wire [3:0]        micro_ctrl;

  wire              aready_o;
  wire              aready_il;
  wire              wip_block_o;
  //RS_FK_BP control
  reg               avalid_fk;
  reg               push_for_fk_r;
  reg               avalid_fk_r;
  
  //bypass resizer
    assign addr_o = RS_BYPASS ? addr_i : {addr_i[INT_AW-1:OPRT_AW], addr_unbp};
  assign alen_o = RS_BYPASS ? alen_i : alen_unbp;
  assign asize_o = RS_BYPASS ? asize_i : asize_unbp;
  assign aburst_o = RS_BYPASS ? aburst_i : aburst_unbp;
  assign alock_o = RS_BYPASS ? alock_i : alock_unbp;
  assign avalid_o = ET_BYPASS ? !addrfifo_ept_i : ( RS_FK_BP ?
                    ( WRITE_CHANNEL ? avalid_fk :
                      (!addrfifo_ept_i & (!rs_fifo_full_i)) ) :
                    (xact_stall ? 1'b0 : avalid_unbp) );
  // When RS_BYPASS==0, this signal is tied to zero.
  assign pre_last_xact_o = RS_BYPASS ? 1'b0 : pre_last_xact_unbp;
  assign last_rs_xact_o = RS_BYPASS ? 1'b1 : last_rs_xact_unbp;
  assign rs_push_req_n_o = ET_BYPASS ? 1'b1 : ( RS_FK_BP ? !(issued_tx & avalid_o)
                           : (xact_stall ? 1'b1 : rs_push_req_n_unbp) );
  assign pop_req_n_o = ET_BYPASS ? !(!addrfifo_ept_i & aready_i) : ( RS_FK_BP ?
                       ( WRITE_CHANNEL ? !(!addrfifo_ept_i & avalid_fk & aready_i)
                       : !(!addrfifo_ept_i & (!rs_fifo_full_i) & aready_i) ) : 
                       pop_req_n_unbp );
  assign addr_rs_o = RS_BYPASS ? addr_i[A_TRK_W-1:0] : addr_rs_unbp;

  //reg push_for_fk_r for RS_FK_BP
  // Path from A* fifo data out to here, gated by empty.
  generate if ( WRITE_CHANNEL ) begin: PUSH_FOR_FK_R1_BLOCK
  always @( posedge aclk or negedge aresetn ) begin: PUSH_FOR_FK_R1_PROC
    if ( !aresetn )
      push_for_fk_r <= 1'b0;
    else begin
      if ( issued_tx & avalid_o & (!aready_il) )
        push_for_fk_r <= 1'b1;
      else if ( aready_il & avalid_o )
        push_for_fk_r <= 1'b0;
      end
    end //always
  end // generate if
  else begin: PUSH_FOR_FK_R2_BLOCK // generate
 
  wire push_for_fk_w;
  assign push_for_fk_w = 1'b0;   

  always@(*) begin: PUSH_FOR_FK_R2_PROC
      push_for_fk_r = push_for_fk_w;
  end
  end  
  endgenerate

  //reg avalid_fk_r for RS_FK_BP
  always @( posedge aclk or negedge aresetn ) begin: AVALID_FK_R_PROC
    if ( !aresetn )
      avalid_fk_r <= 1'b0;
    else
      avalid_fk_r <= avalid_fk;
  end

  //avalid_fk for RS_FK_BP
  always @( addrfifo_ept_i or rs_fifo_full_i or 
            push_for_fk_r or avalid_fk_r ) begin: AVALID_FK_PROC
    if ( !addrfifo_ept_i & (!rs_fifo_full_i) )
      avalid_fk = 1'b1;
    else if ( (rs_fifo_full_i & (!push_for_fk_r) && WRITE_CHANNEL) |
               addrfifo_ept_i )
      avalid_fk = 1'b0;
    else avalid_fk = avalid_fk_r;
  end

  assign aready_in = xact_stall ? 1'b1 :
                     ((WRITE_CHANNEL & RS_FK_BP & push_for_fk_r) ?
                      aready_i :
                     ((!rs_fifo_full_i & aready_i) |
                      (issued_aready_r & rs_fifo_full_i & aready_i)));
  assign aready_o  = 1'b0;
  assign aready_il = aready_i;
  assign wip_block_o= 1'b0;

  assign aburst_in = aburst_i;

 //For PL
  reg [MP_IDW-1:0] aid_pl_r;
  reg [3:0] acache_pl_r;
  reg [2:0] aprot_pl_r;
  

  //xact_upsize with PL
    assign xact_upsize = ue_xact_upsize;
  assign xact_upsize_o = xact_upsize;

  //sizeband with PL
  assign asideband_o = asideband_i;

  //xact issue enable.
  //during write xact, master must not wait for AWREADY asserted
  //before driving WVALID.
  //If read, the enable depends on aready_in.
  wire afifoept_rsfifoful_n;
    assign afifoept_rsfifoful_n = RS_BYPASS ? !addrfifo_ept_i & (!rs_fifo_full_i) : (!addrfifo_ept_i & (!rs_fifo_full_i));

  always @( posedge aclk or negedge aresetn ) begin: WAIT_FOR_TX_R_PROC
    if ( !aresetn ) begin
      wait_for_tx_r <= 1'b0;
    end
    else begin
      if ( wait_for_tx_r )
        wait_for_tx_r <= !aready_in;
      else
        wait_for_tx_r <= afifoept_rsfifoful_n & (!aready_in);
    end
  end

  wire read_issued;
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : Depending on WRITE/READ channel, read_issued signal is read.
    assign read_issued = RS_BYPASS ? aready_in : (aready_in);
  //spyglass enable_block W528
  assign issued_tx = WRITE_CHANNEL ? 
                     afifoept_rsfifoful_n & (!wait_for_tx_r) :
                     read_issued;
  
  // pop_req_n_unbp gen. If addr fifo not empty & resize fifo not full &
  // last resized xact completed & aready_i high, enable pop.
  wire pl_avalid; 
  assign pl_avalid = !addrfifo_ept_i & avalid_o;

  always @( aready_il or pl_avalid or last_rs_xact_ctl ) begin: POP_REQ_N_UNBP_2_PROC
    if ( aready_il & pl_avalid & last_rs_xact_ctl )
      pop_req_n_unbp = 1'b0;
    else
      pop_req_n_unbp = 1'b1;
  end

  always @( posedge aclk or negedge aresetn ) begin: POP_REQ_N_UNBP_3_PROC
    if ( !aresetn )
      pop_req_n_unbp_r <= 1'b1;
    else begin
      if ( !pop_req_n_unbp )
        pop_req_n_unbp_r <= 1'b0;
      else if ( !rs_fifo_full_i )
        pop_req_n_unbp_r <= 1'b1;
    end
  end

  // some calculation for further use
  assign mp_alen = {1'b0, alen_i} + 1; //MP length
    // spyglass disable_block W164b
    // SMD: Identifies assignments in which the LHS width is greater than the RHS width
    // SJ : This is not a functional issue, this is as per the requirement.
    //      Hence this can be waived.
  assign mp_total_byte = mp_alen << asize_i; //MP total bytes
    // spyglass enable_block W164b
  //Calculate the number of downsized SP xacts that will be ignored due
  //to an unaligned MP start address.
  //The reduce_num only used in INCR/FIXed type and first DS xact & DS
  //asize is SP data width.
    assign rn_mask = ~({LOG2_MP_SW{1'b1}} << asize_i);
    assign tmp_addr = addr_i[LOG2_MP_SW-1:0] & rn_mask;
    assign reduce_num = tmp_addr[LOG2_MP_SW-1:MAX_ASIZE_S];

    // spyglass disable_block W164b
    // SMD: Identifies assignments in which the LHS width is greater than the RHS width
    // SJ : This is not a functional issue, this is as per the requirement.
    //      Hence this can be waived.
    assign tmp_num = reduce_num << `ubwc_x2x_X2X_MAX_SP_ASIZE;
    // spyglass enable_block W164b
    // spyglass disable_block STARC-2.10.6.1
    // SMD: Possible loss of carry or borrow in addition or subtraction (Verilog)
    // SJ : This is not a functional issue, this is as per the requirement. Hence this can be waived.
    // spyglass disable_block W484
    // SMD: Possible loss of carry or borrow due to addition or subtraction.
    // SJ : This is as per requirement.
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ : This is not a functional issue, this is as per the requirement. Hence this can be waived.
    assign total_remain_bytes = mp_total_byte - (mp_alen * tmp_num);
    // spyglass enable_block W164a
    // spyglass enable_block W484
    // spyglass enable_block STARC-2.10.6.1

  //Boundary address for wrap xact
  //In wrap alen=2,4,8,16 only and asize_bytes=1,2,4,8,16,32,64 only.

  //function to tranform alen to bit width
  function automatic [2:0] num_bit;
    input [4:0]  alen;

    reg   [2:0] tmp_bit;

    begin
      tmp_bit = {3{1'b0}};

      case ( alen )
        2:  tmp_bit = 3'd1;
        4:  tmp_bit = 3'd2;
        8:  tmp_bit = 3'd3;
        //default=16
        default: tmp_bit = 3'd4;
      endcase

      num_bit = tmp_bit;
    end
  endfunction

  //least (num_bit(mp_alen)+asize_i) is 0 for bound_addr
  wire [INT_BW-1:0] bd_mask;
  wire [5:0] bind_bit;
  assign bind_bit = {3'b000, num_bit(mp_alen[4:0])} + {3'b000, asize_i};
  assign bd_mask = {INT_BW{1'b1}} << bind_bit;
  assign tmp_bound_addr = addr_i[INT_BW-1:0] & bd_mask;
  assign bound_addr  = {addr_i[OPRT_AW-1:INT_BW], tmp_bound_addr};

  parameter [LOG2_MS_BW:0] MAX_SP_ALEN_WIRE_1       = MAX_SP_ALEN;//{`ubwc_x2x_X2X_SP_BLW{1b1}}+1
  //if sp_asize=mp_asize & sp_alen=MAX_SP_ALEN, in SP xact bytes are
  assign max_sp_mpasize_total_byte = MAX_SP_ALEN_WIRE_1 << asize_i;
 
  parameter MAX_ASIZE_S_UE   = (`ubwc_x2x_X2X_MAX_SP_ASIZE > 0) ? 
                            `ubwc_x2x_X2X_MAX_SP_ASIZE : 1; //ByteSize-->BurstSize
  //instance Upsizing enable.
  ubwc_x2x_DW_axi_x2x_ue
  
  U_upsize_enable ( 
  //Inputs
  .addr_i          ( addr_i[MAX_ASIZE_S_UE-1:0] ),
  .alen_i          ( alen_i ),
  .asize_i         ( asize_i ),
  //Outputs
  .xact_upsize_o   ( ue_xact_upsize ) );

  //reg pre_resp_comp_i and clear
  // This logic only applies to configurations with 
  // X2X_HAS_LOCKING == 1.


  //for push_req_n and push_full
  generate if ( WRITE_CHANNEL ) begin: ISSUED_AREADY_R1_BLOCK
  always @( posedge aclk or negedge aresetn ) begin: ISSUED_AREADY_R1_PROC
    if ( !aresetn )
      issued_aready_r <= 1'b0;
    else begin
      if ( !rs_push_req_n_unbp & (!aready_il) )
        issued_aready_r <= 1'b1;
      else if ( aready_il & avalid_o )
        issued_aready_r <= 1'b0;
    end
  end // always
  end // if 
  else begin: ISSUED_AREADY_R1_BLOCK // generate
  
  wire issued_aready_w;
  assign issued_aready_w = 1'b0;   

  always @(*) begin: ISSUED_AREADY_R2_PROC
      issued_aready_r = issued_aready_w;
  end
  end  
  endgenerate

  //generate addr to RS fifos.
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : Signal addr_rs_unbp is read in un-bypassed transaction.
  assign addr_rs_unbp = addr_unbp[A_TRK_W-1:0];
  //spyglass enable_block W528
  wire [2:0] asize_temp;
    assign asize_temp = asize_i;

parameter [2:0] MAX_ASIZE_S_WIRE_1 = `ubwc_x2x_X2X_MAX_SP_ASIZE; //MAX_ASIZE_S;
parameter [LOG2_BIG_BW:0] MAX_SP_TOTAL_BYTE_WIRE_1 = `ubwc_x2x_X2X_MAX_SP_TOTAL_BYTE; //max_sp_asize *
  wire [LOG2_MS_BW:0] max_sp_mpasize_total_byte_temp;
    assign max_sp_mpasize_total_byte_temp = max_sp_mpasize_total_byte;
  //upsize mp_asize or downsize mp_asize
  //upsize or downsize max_sp_total_byte_mux
  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ : This is not a functional issue, this is as per the requirement.
  //      Hence this can be waived.
  // spyglass disable_block W164b
  // SMD: Identifies assignments in which the LHS width is greater than the RHS width
  // SJ : This is not a functional issue, this is as per the requirement.
  //      Hence this can be waived.
  always @(*) begin: SP_TOTAL_BYTE_PROC
    if ( xact_upsize ) begin
      max_sp_total_byte_mux = MAX_SP_TOTAL_BYTE_WIRE_1;
    end
    else begin //downsize
      max_sp_total_byte_mux = max_sp_mpasize_total_byte_temp;
    end
  end
  // spyglass enable_block W164b
  // spyglass enable_block W164a

  always @(*) begin: MP_ASIZE_MUX_PROC
    if ( xact_upsize ) begin
      mp_asize_mux = MAX_ASIZE_S_WIRE_1;
    end
    else begin //downsize
      mp_asize_mux = asize_temp;
    end
  end


  assign total_byte_mux = (resize_ctrl == `ubwc_x2x_MUL_XACT_NOTLAST) ?
                     MAX_SP_TOTAL_BYTE_WIRE_1 : max_sp_total_byte_mux;

  //get locked sequence for both AW & AR channels
  //2'b10-->locked.


  //alock_last_flag gen for lock sequence with last DS normal xact

  ///////////////////////////////////////////////////////////////////////
  //                       resizing
  //
  //If X2X issues 1st xact from a primary xact, we have the following.
  // 1.if mp_asize<=MAX_SP_ASIZE & mp_alen<=MAX_SP_ALEN, pass as-is (for
  //   WRAP, aligned_addr == bound_addr).
  //   if upsize, asize_o = log2(MAX_SP_ASIZE).
  //
  // 2.if mp_asize<=MAX_SP_ASIZE & mp_alen>MAX_SP_ALEN, multi xacts.
  //   if upsize, it might be single xact.
  //
  // 3.if mp_asize>MAX_SP_ASIZE & mp_total_byte<=MAX_SP_TOTAL_BYTE,
  //   single xact and no upsize (for WRAP, aligned_addr == bound_addr;
  //   for FIXED, total_remain_bytes <= MAX_SP_TOTAL_BYTE).
  //
  // 4.Otherwise (mp_asize>MAX_SP_ASIZE & mp_total_byte > 
  //   MAX_SP_TOTAL_BYTE), multi xacts and no upsize.
  //
  //If X2X issues 2nd and on xact from a primary xact, we have to do
  // 1.if mp_asize<=MAX_SP_ASIZE & mp_alen>MAX_SP_ALEN & not WRAP or
  //   aligned_addr != bound_addr & WRAP, multi xacts and possible
  //   upsize.
  //
  // 2.mp_total_byte <= MAX_SP_TOTAL_BYTE & not WRAP, no action.
  //
  // 3.Otherwise, multi xacts and no upsize.
  ///////////////////////////////////////////////////////////////////////
  wire spasize_larger;
  wire spalen_larger;
  wire spbyte_larger;

  parameter [2:0] MAX_SP_ASIZE_WIRE             = `ubwc_x2x_X2X_MAX_SP_ASIZE; //bytes -> asize
  parameter [MP_BLW:0] MAX_SP_ALEN_WIRE_2       = `ubwc_x2x_X2X_MAX_SP_ALEN+1;//{`ubwc_x2x_X2X_SP_BLW{1b1}}+1

  assign spasize_larger = ((asize_temp) <= MAX_SP_ASIZE_WIRE) |
                          SPSIZE_LRG_MP;
    assign spalen_larger = (mp_alen <= MAX_SP_ALEN_WIRE_2) | SPALEN_LRG_MP;
    assign spbyte_larger = (mp_total_byte <= `ubwc_x2x_X2X_MAX_SP_TOTAL_BYTE) | SPBYTE_LRG_MP;

  assign wrap_from_bound = (addr_i[OPRT_AW-1:0] == bound_addr) && 
                           (aburst_in == `ubwc_x2x_X2X_BT_WRAP);

  //resize control signal gen used to control different size cases
  wire [MP_BLW:0] pl_mp_alen;
  wire pl_addrfifo_ept;
  wire [OPRT_AW-1:0] pl_addr;
  wire [1:0] pl_aburst;
  wire [LOG2_MP_BW:0] pl_total_remain_bytes;
  wire pl_ept_or_full;
  wire [OPRT_AW-1:0] pl_bound_addr;
  assign pl_bound_addr = bound_addr;
     assign pl_mp_alen = mp_alen;
     assign pl_addrfifo_ept = addrfifo_ept_i;
     assign pl_addr = addr_i[OPRT_AW-1:0];
     assign pl_aburst = aburst_in;
     assign pl_ept_or_full = !addrfifo_ept_i;
     assign pl_total_remain_bytes = total_remain_bytes;

  always @( pl_mp_alen or pl_ept_or_full or
            pl_bound_addr or wrap_from_bound or pl_addr or
            spasize_larger or spalen_larger or spbyte_larger or
            pl_aburst or pl_total_remain_bytes or
            last_rs_xact_ctl_r ) begin: RESIZE_CTRL_PROC
    resize_ctrl = `ubwc_x2x_NO_ACTION;

     //if addr FIFO not empty & resize FIFO not full,do calculate & xact
     if ( pl_ept_or_full ) begin
       if ( last_rs_xact_ctl_r ) begin //in last xact
         if ( spasize_larger ) begin
           if ( spalen_larger
               && ( wrap_from_bound || (pl_aburst != `ubwc_x2x_X2X_BT_WRAP) )
              )
             //as_is_or_upsize control, in last xact
             resize_ctrl = `ubwc_x2x_AS_IS_OR_US_INLAST;
 
           else //  mp_alen > MAX_SP_ALEN
             //control of multi xacts or upsize, in last xact
             resize_ctrl = `ubwc_x2x_MUL_XACT_OR_US_INLAST;
 
         end
         else begin //mp_asize > MAX_SP_ASIZE
           if ( ( spbyte_larger && (
               wrap_from_bound |
               pl_aburst == `ubwc_x2x_X2X_BT_INCR) ) ||
               ( ((pl_total_remain_bytes <= `ubwc_x2x_X2X_MAX_SP_TOTAL_BYTE) |
                  SPBYTE_LRG_MP) &&
               pl_aburst == `ubwc_x2x_X2X_BT_FIXED) )
             //single xact, in last xact
             resize_ctrl = `ubwc_x2x_SINGLE_XACT_INLAST; 
 
           else //mp_total_byte > MAX_SP_TOTAL_BYTE
             //multi xacts, in last xact
             resize_ctrl = `ubwc_x2x_MUL_XACT_INLAST;
         end
       end // if last_rs_xact_ctl_r
       else begin //not in last xact
         if ( spasize_larger ) begin
           if ( (   (`ubwc_x2x_X2X_MP_BLW > `ubwc_x2x_X2X_SP_BLW)
              && pl_mp_alen > (`ubwc_x2x_X2X_MAX_SP_ALEN+1)
              && pl_aburst != `ubwc_x2x_X2X_BT_WRAP
             )
                || (pl_addr != pl_bound_addr && 
                pl_aburst == `ubwc_x2x_X2X_BT_WRAP)
              )
             //multi xacts or upsize, not in last xact
             resize_ctrl = `ubwc_x2x_MUL_XACT_OR_US_NOTLAST;
         end
         else begin //mp_asize > MAX_SP_ASIZE
           if ( spbyte_larger && (pl_aburst != `ubwc_x2x_X2X_BT_WRAP) )
             resize_ctrl = `ubwc_x2x_NO_ACTION;
           else
             //multi xacts, not in last xact
             resize_ctrl = `ubwc_x2x_MUL_XACT_NOTLAST;
         end
       end //else if ( mp_asize
     end //if ( !addrfifo_ept_i & !rs_fifo_full_i )
  end //always

  wire [LOG2_MP_BW:0] mp_total_byte_temp;
    assign mp_total_byte_temp = mp_total_byte;

  //instance xact control module
  //last_rs_xact_ctl used to indicate last xact or not
  ubwc_x2x_DW_axi_x2x_xact_ctrl
   
  #(  OPRT_AW  )
  U_xact_ctrl (
    .resize_ctrl_i           ( resize_ctrl ),
    .aready_i                ( aready_in ),
    .xact_upsize_i           ( xact_upsize ),
    .mp_total_byte_i         ( mp_total_byte_temp ),
    .addr_i                  ( pl_addr ),
    .bound_addr_i            ( pl_bound_addr ),
    .total_addr_r_i          ( total_addr_r ),
    .total_alen_r_i          ( total_alen_r ),
    .mp_asize_mux_i          ( mp_asize_mux ),
    .aburst_i                ( pl_aburst ),
    .last_rs_xact_ctl_r_i    ( last_rs_xact_ctl_r ),
    .total_remain_bytes_i    ( pl_total_remain_bytes ),
    .deduct_ran_num_bytes_i  ( deduct_ran_num_bytes ),

    .micro_ctrl_o            ( micro_ctrl ),
    .last_rs_xact_ctl_o      ( last_rs_xact_ctl )
  );

  //instance addr_alen
  //alen_o/addr_o gen. changes per xact
  wire [LOG2_MS_BW:0] pl_max_sp_mpasize_total_byte;
  assign pl_max_sp_mpasize_total_byte = max_sp_mpasize_total_byte_temp;
  wire [MP_BLW-1:0] alen_i_ip;
  wire [RDC_NUM_W-1:0] reduce_num_temp;
     assign alen_i_ip = alen_i;
     assign reduce_num_temp = reduce_num;

  wire [OPRT_AW-1:0] aligned_addr_temp;
    assign aligned_addr_temp = aligned_addr;
// When X2X_LOCKING is not defined, the pre_last_xact_o signal is tied to zero.
//spyglass disable_block W528
//SMD: A signal or variable is set but never read.
//SJ : Signal pre_last_xact_unbp is read only in un-bypassed transaction configuration.
  ubwc_x2x_DW_axi_x2x_addr_alen
   
  #( OPRT_AW, RDC_NUM_W ) U_addr_alen (
    .resize_ctrl_i               ( resize_ctrl ),
    .xact_upsize_i               ( xact_upsize ),
    .mp_total_byte_i       ( mp_total_byte_temp ),
    .aligned_addr_i        ( aligned_addr_temp ),
    .bound_addr_i                ( pl_bound_addr ),
    .total_alen_r_i              ( total_alen_r ),
    .total_addr_r_i              ( total_addr_r ),
    .max_sp_mpasize_total_byte_i ( pl_max_sp_mpasize_total_byte ),
    .asize_i                     ( asize_temp ),
    .micro_ctrl_i                ( micro_ctrl ),
    .reduce_num_i                ( reduce_num_temp ),
    .aready_i                    ( aready_in ),
    .aburst_i                    ( pl_aburst ),
    .alen_i                      ( alen_i_ip ),
    .addr_i                      ( pl_addr ),
    .max_sp_total_byte_mux_i     ( max_sp_total_byte_mux ),
    .total_remain_bytes_i        ( pl_total_remain_bytes ),
    .reduce_num_r_i              ( reduce_num_r ),
    .pre_ran_num_bytes_i         ( pre_ran_num_bytes ),

    //outputs
    .xact_stall_o                ( xact_stall ),
    .alen_o                      ( alen_unbp ),
    .addr_o                      ( addr_unbp ),
    .total_alen_o                ( total_alen_s ),
    .total_addr_o                ( total_addr_s ),
    .mxin_reduce_num_o           ( mxin_reduce_num ),
    .pre_last_xact_o             ( pre_last_xact_unbp )
  );
// spyglass enable_block W528

  always @( posedge aclk or negedge aresetn ) begin: REDUCE_NUM_R_PROC
    if ( !aresetn )
      reduce_num_r <= {RDC_NUM_W{1'b0}};
    else
      reduce_num_r <= mxin_reduce_num;
  end

  wire [1:0] alock_temp;
    assign alock_temp = alock_i;
  
  //alock_unbp gen. mind last normal xact within a locked sequenc with DS
  assign alock_s = `ubwc_x2x_NORMAL;
  assign alock_ss = `ubwc_x2x_NORMAL;
  assign alock_sss = alock_temp;
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : alock_unbp is read in un-bypassed transaction configuration.
  always @( resize_ctrl or micro_ctrl or
            alock_s or alock_ss or alock_sss ) begin: ALOCK_UNBP_PROC
    alock_unbp = alock_sss;

    case ( resize_ctrl )
      `ubwc_x2x_MUL_XACT_OR_US_INLAST: begin
        case ( micro_ctrl )
          `ubwc_x2x_MXUI_NO_CROSS, `ubwc_x2x_MXUI_CROSS, `ubwc_x2x_MXUI_DS, 
          `ubwc_x2x_MXUI_FI_MUL, `ubwc_x2x_MXUI_FI_DS:
            alock_unbp = alock_s;

          default: alock_unbp = alock_sss;
        endcase
      end

      `ubwc_x2x_MUL_XACT_OR_US_NOTLAST, `ubwc_x2x_MUL_XACT_NOTLAST: begin
        case ( micro_ctrl )
          `ubwc_x2x_MUX_OVERONE, `ubwc_x2x_MUX_CROSS, `ubwc_x2x_MUX_FI_MUL: alock_unbp = alock_s;

          `ubwc_x2x_MUX_WRAP_BOUND, `ubwc_x2x_MUX_WRAP, `ubwc_x2x_MUX_FI_LAST: alock_unbp=alock_ss;

          default: alock_unbp = alock_sss;
        endcase
      end

      `ubwc_x2x_MUL_XACT_INLAST: alock_unbp = alock_s;

      default: alock_unbp = alock_sss;
    endcase
  end
  // spyglass enable_block W528
  //aburst_unbp gen. for DS, WRAP -> INCR
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : aburst_unbp is read in un-bypassed transaction configuration.
  always @( resize_ctrl or pl_aburst ) begin: ABURST_UNBP_PROC
    aburst_unbp = pl_aburst;

    case ( resize_ctrl )
      `ubwc_x2x_SINGLE_XACT_INLAST, `ubwc_x2x_MUL_XACT_OR_US_INLAST, 
      `ubwc_x2x_MUL_XACT_OR_US_NOTLAST, `ubwc_x2x_MUL_XACT_INLAST, 
      `ubwc_x2x_MUL_XACT_NOTLAST, `ubwc_x2x_AS_IS_OR_US_INLAST: begin
        if ( pl_aburst == `ubwc_x2x_X2X_BT_WRAP ) aburst_unbp = `ubwc_x2x_X2X_BT_INCR;
      end

      default: aburst_unbp = pl_aburst;
    endcase
  end
// spyglass enable_block W528 
  //aid_o/asize_mp_o/acache_o/aprot_o gen. SP_IDW >= MP_IDW
  always @(*) begin: ACTRL_PROC
    aid_o = RS_BYPASS ? aid_i : (PL ? aid_pl_r : aid_i);
    asize_mp_o = RS_BYPASS ? asize_i : (asize_temp);
    acache_o = RS_BYPASS ? acache_i : (PL ? acache_pl_r : acache_i);
    aprot_o = RS_BYPASS ? aprot_i : (PL ? aprot_pl_r : aprot_i);
  end

  //asize_unbp gen. take asize_i from MP or MAX_ASIZE_S from MAX_SP_ASIZE
  //aligned_addr gen, dependent on asize_unbp.
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : aburst_unbp is read in un-bypassed transaction configuration.
  always @(*) begin: ASIZE_UNBP_PROC
    asize_unbp = asize_temp;

    case ( resize_ctrl )
      `ubwc_x2x_AS_IS_OR_US_INLAST, `ubwc_x2x_MUL_XACT_OR_US_INLAST, 
      `ubwc_x2x_MUL_XACT_OR_US_NOTLAST: begin
        if ( xact_upsize )
          asize_unbp = MAX_ASIZE_S_WIRE_1;
      end

      `ubwc_x2x_SINGLE_XACT_INLAST, `ubwc_x2x_MUL_XACT_INLAST, `ubwc_x2x_MUL_XACT_NOTLAST:
        asize_unbp = MAX_ASIZE_S_WIRE_1;

      default: asize_unbp = asize_temp;
    endcase

    if ( ue_xact_upsize ) begin
      align_mask = {(LOG2_MP_SW+1){1'b1}} << MAX_ASIZE_S;
      aligned_addr = {addr_i[OPRT_AW-1:LOG2_MP_SW+1],
                     (addr_i[LOG2_MP_SW:0] & align_mask)};
    end
    else begin
      align_mask = {(LOG2_MP_SW+1){1'b1}} << asize_i;
      aligned_addr = {addr_i[OPRT_AW-1:LOG2_MP_SW+1],
                     (addr_i[LOG2_MP_SW:0] & align_mask)}; 
    end
  end
 //spyglass enable_block W528
  //last_rs_xact_unbp gen. mind last xact only
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : last_rs_xact_unbp is read in un-bypassed transaction configuration.
  always @( micro_ctrl or resize_ctrl
          ) begin: LAST_RS_XACT_UNBP_PROC
    last_rs_xact_unbp = 1'b0;

    case ( resize_ctrl )
      `ubwc_x2x_AS_IS_OR_US_INLAST, `ubwc_x2x_SINGLE_XACT_INLAST:
        last_rs_xact_unbp = 1'b1;

      `ubwc_x2x_MUL_XACT_OR_US_INLAST: begin
        case ( micro_ctrl )
          `ubwc_x2x_MXUI_SINGLE, `ubwc_x2x_MXUI_FI_SINGLE:
            last_rs_xact_unbp = 1'b1;

          default: last_rs_xact_unbp = 1'b0;
        endcase
      end

      `ubwc_x2x_MUL_XACT_OR_US_NOTLAST, `ubwc_x2x_MUL_XACT_NOTLAST: begin
        case ( micro_ctrl )
          `ubwc_x2x_MUX_WRAP_BOUND, `ubwc_x2x_MUX_WRAP, `ubwc_x2x_MUX_FI_LAST: begin
              last_rs_xact_unbp = 1'b1;
          end
        
          default: last_rs_xact_unbp = 1'b0;
        endcase
      end

      default: last_rs_xact_unbp = 1'b0;
    endcase
  end
 //spyglass enable_block W528
  //avalid_unbp/rs_push_req_n_unbp gen. 
  //mind lock sequence for last normal xact
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : rs_push_req_n_unbp is read in un-bypassed transaction configuration.
  always @(*) begin: AVALID_SR_PUSH_REQ_PROC
    avalid_unbp = 1'b0;
    rs_push_req_n_unbp = 1'b1;

    if ( pl_addrfifo_ept | (rs_fifo_full_i & (!issued_aready_r) & 
          WRITE_CHANNEL) |
         (rs_fifo_full_i & (!WRITE_CHANNEL)) |
         (rs_fifo_full_i & issued_tx_r ) |
         (WRITE_CHANNEL & rs_fifo_full_i & (!pop_req_n_unbp_r)) )
      avalid_unbp = 1'b0;
    else begin
      case ( resize_ctrl )
        `ubwc_x2x_AS_IS_OR_US_INLAST, `ubwc_x2x_SINGLE_XACT_INLAST,
        `ubwc_x2x_MUL_XACT_OR_US_INLAST, `ubwc_x2x_MUL_XACT_INLAST: begin
          avalid_unbp = 1'b1;
  
          if ( issued_tx )
            rs_push_req_n_unbp = 1'b0;
        end
  
        default: begin
//        `ubwc_x2x_MUL_XACT_OR_US_NOTLAST, `ubwc_x2x_MUL_XACT_NOTLAST: begin
          case ( micro_ctrl )
            `ubwc_x2x_MUX_OVERONE, `ubwc_x2x_MUX_CROSS, `ubwc_x2x_MUX_FI_MUL: begin
              avalid_unbp = 1'b1;
  
              if ( issued_tx )
                rs_push_req_n_unbp = 1'b0;
            end
  
            `ubwc_x2x_MUX_WRAP_BOUND, `ubwc_x2x_MUX_WRAP, `ubwc_x2x_MUX_FI_LAST: begin
                avalid_unbp = 1'b1;
  
                if ( issued_tx )
                  rs_push_req_n_unbp = 1'b0;
            end
  
            default: begin
              avalid_unbp = 1'b0;
            end
          endcase
        end
  
//        default: begin
//          if ( avalid_unbp_r & aready_r ) avalid_unbp = 1'b0;
//          else avalid_unbp = avalid_unbp_r;
//        end
      endcase
    end
  end
//spyglass enable_block W528
  ///////////////////////////////////////////////////////////////////
  // register total_alen and total_addr, last_rs_xact_ctl and
  // default last_rs_xact_ctl is 1.
  ///////////////////////////////////////////////////////////////////
  always @( posedge aclk or negedge aresetn ) begin:ACTRL_TOTAL_PROC
    if ( !aresetn ) begin
      total_alen_r       <= {(LOG2_MP_BW+1){1'b0}};
    end
    else begin
      total_alen_r       <= total_alen_s;
    end
  end

  always @( posedge aclk or negedge aresetn ) begin: TOTAL_ADDR_R_PROC
    if ( !aresetn )
      total_addr_r <= {(OPRT_AW+1){1'b0}};
    else
      total_addr_r <= total_addr_s;
  end

  always @( posedge aclk or negedge aresetn ) begin: LAST_RS_XACT_CTL_R_PROC
    if ( !aresetn )
      last_rs_xact_ctl_r <= 1'b1;
    else
      last_rs_xact_ctl_r <= last_rs_xact_ctl;
  end


  //issued_tx_r used to disable avalid if aready/avalid/issued_tx
  //asserted at the same cycle as well as rs_fifo_full
  //spyglass disable_block FlopEConst  
  //SMD: Reports permanently disabled or enabled flip-flop enable pins
  //SJ : This is the intended design, this as per the requirement and  
  //     hence this can be waived.
  always @( posedge aclk or negedge aresetn ) begin: ISSUED_TX_R_PROC
    if ( !aresetn )
      issued_tx_r <= 1'b0;
    else begin
      if ( avalid_unbp & aready_il & issued_tx )
        issued_tx_r <= 1'b1;
      else if ( !rs_fifo_full_i )
        issued_tx_r <= 1'b0;
    end
  end
  //spyglass enable_block FlopEConst  

  ///////////////////////////////////////////////////////////////////
  // To get how many bytes already ran
  // add total_byte_mux if avalid_o & ready both high.
  ///////////////////////////////////////////////////////////////////
    // spyglass disable_block STARC-2.10.6.1
    // SMD: Possible loss of carry or borrow in addition or subtraction (Verilog)
    // SJ : This is not a functional issue, this is as per the requirement. Hence this can be waived.
    // spyglass disable_block W484
    // SMD: Possible loss of carry or borrow due to addition or subtraction.
    // SJ : This is as per the design requirement.
  generate if (LOG2_MP_BW+1 >= LOG2_BIG_BW+1)
  always @(*) begin: PRE_RAM_NUM_BYTES_S_PROC
    if ( last_rs_xact_ctl_r )
      pre_ran_num_bytes_s = {(LOG2_MP_BW+1){1'b0}};
    else if ( (avalid_unbp & aready_in) | xact_stall )
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ : This is not a functional issue, this is as per the requirement. Hence this can be waived.
      pre_ran_num_bytes_s = pre_ran_num_bytes_r + total_byte_mux;
    // spyglass enable_block W164a
    else
      pre_ran_num_bytes_s = pre_ran_num_bytes_r;
  end
  else
  always @(*) begin: PRE_RAM_NUM_BYTES_S_PROC
    if ( last_rs_xact_ctl_r )
      pre_ran_num_bytes_s = {(LOG2_MP_BW+1){1'b0}};
    else if ( (avalid_unbp & aready_in) | xact_stall )
    // spyglass enable_block W484
    // spyglass enable_block STARC-2.10.6.1
  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ : This is not a functional issue, this is as per the requirement.
  //      Hence this can be waived.
  //spyglass disable_block TA_09
  //SMD: Reports cause of uncontrollability or unobservability and estimates the number of nets whose controllability / observability is impacted. 
  //SJ : Tool will issue unobservability warning only for those bits which are "not read" or "floating". Since we are not reading those bits we don't need observability. Hence waiving this warning.
      pre_ran_num_bytes_s = {{((LOG2_BIG_BW - LOG2_MP_BW)){1'b0}}, pre_ran_num_bytes_r} + total_byte_mux;
  // spyglass enable_block TA_09
  // spyglass enable_block W164a
    else
      pre_ran_num_bytes_s = pre_ran_num_bytes_r;
  end
  endgenerate

  always @( posedge aclk or negedge aresetn ) begin: PRE_RAN_NUM_BYTES_R_PROC
    if ( !aresetn )
      pre_ran_num_bytes_r <= {(LOG2_MP_BW+1){1'b0}};
    else
      pre_ran_num_bytes_r <= pre_ran_num_bytes_s;
  end

    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ : This is not a functional issue, this is as per the requirement.
    // spyglass disable_block STARC-2.10.6.1
    // SMD: Possible loss of carry or borrow in addition or subtraction (Verilog)
    // SJ : This is not a functional issue, this is as per the requirement. Hence this can be waived.
    // spyglass disable_block W484
    // SMD: Possible loss of carry or borrow due to addition or subtraction.
    // SJ : This is as per the design requirement.
  generate if (LOG2_MP_BW+1 >= LOG2_BIG_BW+1)
  begin
    assign pre_ran_num_bytes = pre_ran_num_bytes_r + total_byte_mux;
    assign deduct_ran_num_bytes = pre_ran_num_bytes + total_byte_mux;
  end
  else
  begin
    // spyglass enable_block W484
    // spyglass enable_block STARC-2.10.6.1
    assign pre_ran_num_bytes = {{((LOG2_BIG_BW - LOG2_MP_BW)){1'b0}}, pre_ran_num_bytes_r} + total_byte_mux;
    assign deduct_ran_num_bytes = {{((LOG2_BIG_BW - LOG2_MP_BW)){1'b0}}, pre_ran_num_bytes} + total_byte_mux;
  // spyglass enable_block W164a
  end
  endgenerate

endmodule
