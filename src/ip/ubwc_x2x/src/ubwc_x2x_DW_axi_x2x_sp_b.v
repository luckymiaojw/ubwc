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
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_sp_b.v#11 $ 
**
** --------------------------------------------------------------------
**
** File     : DW_axi_x2x_sp_b.v
** Abstract : This block implements the burst response control block
**            in the X2X slave port.
**
**            It receives notification of issued transactions from
**            the slave port write address channel, stores them in
**            a fifo and can pack a possible number of burst responses
**            from the external slave into a single burst response
**            (downsized t/x) to be pushed into the channel fifo.
**
** --------------------------------------------------------------------
*/

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_sp_b (
  // System inputs
  aclk_i,
  aresetn_i,

  // SP WRITE ADDRESS CHANNEL I/F
  // Inputs 
  rs_push_req_n_i,
  aid_i,
  pre_last_xact_i,
  last_xact_i,
  
  // Outputs 
  rs_fifo_full_o,

  // CHANNEL FIFO I/F
  // Inputs 
  push_full_i,
  
  // Outputs 
  push_req_n_o,
  payload_o,
  

  // EXTERNAL SLAVE PORT I/F
  // Inputs 
  bus_valid_i,
  bus_payload_i,


  // Outputs 
  bus_ready_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------

  // INTERFACE PARAMETERS - MUST BE SET BY INSTANTIATION


  // INTERNAL PARAMETERS - MUST NOT BE SET BY INSTANTIATION
  parameter TX_ALTER = `ubwc_x2x_X2X_TX_ALTER; // Defines level to which
                                      // X2X alters transactions.
      
  parameter NUM_W_PORTS = `ubwc_x2x_X2X_NUM_W_PORTS; // Number of write ports.

//  parameter LOG2_NUM_W_PORTS = `ubwc_x2x_X2X_LOG2_NUM_W_PORTS; // Log b2.

  parameter SP_PYLD_W = `ubwc_x2x_X2X_BPYLD_W_SP; // SP payload width.

  parameter BUS_SP_PYLD_W = NUM_W_PORTS * SP_PYLD_W; // Width of bus of 
                                                     // SP payloads.

  parameter MP_PYLD_W = `ubwc_x2x_X2X_BPYLD_W_MP; // MP payload width.

  parameter MP_ID_W = `ubwc_x2x_X2X_MP_IDW; // Internal ID width will always be
                                   // this value. May be padded out to 
                                   // larger width before being 
                                   // forwarded from the SP.

//  parameter SP_ID_W = `ubwc_x2x_X2X_SP_IDW; // ID width driven out from X2X SP.

  // Width of resize info. fifo. Just need to store ID + 1 bit each for 
  // pre_last_xact_i and last_rs_xact_i.
  parameter RSI_FIFO_W = MP_ID_W + 2;

  // Fan out enabled or not.
  parameter WI_FAN_OUT = `ubwc_x2x_X2X_HAS_WI_FAN_OUT;
  
  // Write interleaving depth.
  parameter WID = (WI_FAN_OUT ? 1 : `ubwc_x2x_X2X_WID); 

  // Number of active unique write ID's, defines number of RSI fifos.
  parameter MAX_UWIDA = `ubwc_x2x_X2X_MAX_UWIDA;

  // Number of resize info. fifos.
  parameter NUM_RSI_FIFOS = WI_FAN_OUT ? WID : MAX_UWIDA;

  // Width of bus of all RSI fifo data signals.
  parameter BUS_RSI_FIFO_W = RSI_FIFO_W * MAX_UWIDA;

  // Number of active write t/x's per unique ID, defines depth of
  // each RSI fifo.
  parameter MAX_WCA_ID = `ubwc_x2x_X2X_MAX_WCA_ID;
  parameter MAX_WCA_ID_L2 = `ubwc_x2x_X2X_LOG2_MAX_WCA_ID; // Log base 2.


  // Burst response signal width.
  parameter BR_W = `ubwc_x2x_X2X_BRW;

  // Bussed resize info. fifo signal widths.
  parameter BUS_RSIF_ID_W = (NUM_RSI_FIFOS*MP_ID_W);

  // Bussed SP signal widths.
  parameter BUS_ID_W = (NUM_W_PORTS*MP_ID_W);
  parameter BUS_SP_BR_W = (NUM_W_PORTS*BR_W); // Per write port.
  parameter BUS_UWID_BR_W = (MAX_UWIDA*BR_W); // Per unique ID.

  // Depth of RSI fifo's. 
  // To avoid a deadlock scenario in configurations with X2X_WID > 1 we 
  // have to make the RSI fifo's deep enough to hold the maximum number 
  // of SP t/x's that the X2X can generate from a single MP t/x.
  // This avoids a deadlock condition if the slave can only return
  // burst responses in order.
  parameter RSI_FIFO_D = (WID > 1) ? `ubwc_x2x_X2X_WIP_FIFO_D : MAX_WCA_ID;
  
  // Log base 2 of depth of RSI fifo's. 
  parameter RSI_FIFO_D_L2 = (WID > 1) 
                            ? `ubwc_x2x_X2X_LOG2_WIP_FIFO_D 
                            : MAX_WCA_ID_L2;


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
  input rs_push_req_n_i; // Push request to resize info. fifo.

  // Resized transaction attributes.
  input [MP_ID_W-1:0] aid_i;

  input pre_last_xact_i; // Asserted when X2X issues 1 t/x prior to last 
                         // of t/x's created from downsizing an MP t/x.
 
  input last_xact_i; // Asserted when X2X issues last of t/x's created 
                     // from downsizing an MP t/x.
                         
  
  // Outputs 
  output rs_fifo_full_o; // Resize info. fifo full.


  //--------------------------------------------------------------------
  // CHANNEL FIFO I/F
  //--------------------------------------------------------------------
  // Inputs 
  input push_full_i; // Full status from channel fifo.
  
  // Outputs 
  output                 push_req_n_o; // Push request to channel fifo.
  output [MP_PYLD_W-1:0] payload_o; // Payload from channel fifo.
  

  //--------------------------------------------------------------------
  // EXTERNAL SLAVE PORT I/F
  //--------------------------------------------------------------------
  // Inputs 
  input [NUM_W_PORTS-1:0]   bus_valid_i; 
  input [BUS_SP_PYLD_W-1:0] bus_payload_i;
  
  // Outputs 
  output [NUM_W_PORTS-1:0] bus_ready_o; 



  //--------------------------------------------------------------------
  // WIRE/REGISTER VARIABLE DECLARATIONS
  //--------------------------------------------------------------------
  
  // RSI FIFO (RSIF) SIGNALS.    
  wire [RSI_FIFO_W-1:0] rsif_di; // Bus of data in signals to 
                                 // resize info. fifo.
  wire [BUS_RSI_FIFO_W-1:0] bus_rsif_do; // Bus of data out signals 
                                         // from resize info. fifo.

  wire [NUM_RSI_FIFOS-1:0] bus_rsif_push_n; // Busses of push and 
  reg  [NUM_RSI_FIFOS-1:0] bus_rsif_pop_n;  // pop signals for all
                                            // RSI fifos.
  wire [NUM_RSI_FIFOS-1:0] bus_rsif_empty; // empty signals for all
                                           // RSI fifos.

  wire [NUM_RSI_FIFOS-1:0] bus_rsif_sel; // RSI fifo that the next push
                                         // will target.

  // Bit for each RSIF, asserted when that RSIF is the lowest numbered
  // free (empty) RSIF.
  reg [NUM_RSI_FIFOS-1:0] bus_rsif_lsfree;
  
  wire [NUM_RSI_FIFOS-1:0] bus_rsif_full;  // Busses of full and 
  wire [NUM_RSI_FIFOS-1:0] bus_rsif_empty_nxt; // Pre registered empty
                                               // signals from all
                                               // RSI fifos.

  // Resizing information signals from the output of the RSI fifos.
  reg [BUS_RSIF_ID_W-1:0] bus_rsif_aid;
  reg [NUM_RSI_FIFOS-1:0] bus_rsif_last;


  // RSIF - Control generation signals.
  
  // Bit for each RSIF, asserted when aid_i matches with fifo @ head
  // of that rsi fifo when that fifo is not empty.
  reg [NUM_RSI_FIFOS-1:0] bus_aid_rsif_amatch; 

  // CHANNEL FIFO - push signal generation.
  
  // Bit for each RSIF, asserted when sp_id matches with fifo @ head
  // of that rsi fifo when that fifo is not empty.
  reg [NUM_RSI_FIFOS-1:0] bus_sp_id_rsif_amatch; 

  // Bit for each RSIF, asserted when response being packed for that
  // RSIF is ready to be pushed into the channel fifo.
  wire [NUM_W_PORTS-1:0] bus_chf_push_req;

  wire chf_arb_push; // Push signal to channel fifo coming from
                     // write fan out push request arbiter.

  // chf_arb_push expanded out with a bit per RSIF, 1 or no bits active
  // at a time.
  wire [NUM_W_PORTS-1:0] bus_chf_arb_push; 

  // AXI SP CHANNEL SIGNALS - Extracted from SP payload.
  reg [BUS_ID_W-1:0] bus_sp_id;
  reg [BUS_SP_BR_W-1:0] bus_sp_resp;

  
  // RESPONSE PACKING SIGNALS
  // Depedning on the configuration some bits of these signals maybe unused.
  reg [BUS_UWID_BR_W-1:0] bus_resp_pack_r;   // Register and next state 
  reg [BUS_UWID_BR_W-1:0] bus_resp_pack_nxt; // variables for burst 
                                             // response packing.

  wire [BR_W-1:0] resp_exokay; // Contains signal contents of EXOKAY
                               // response.

  // CHANNEL FIFO PAYLOAD GEN. SIGNALS
  // Depending on the configuration this signal maybe unused.
  reg [BUS_SP_PYLD_W-1:0] bus_pyld_rpck_chf_mux; // Payloads built using
                                                 // resp from packing 
                                                 // registers.



  wire [BR_W-1:0] mux_resp_pack_nxt; // Resp selected from
                                     // bus_resp_pack_nxt depending on 
                                     // which RSIF the SP ID matched 
                                     // with.
                 
  // RSI fifo - ID shadow registers.
  // Required as a solution for a situation that occurs when 
  // X2X_MAX_WCA_ID == 1.
  reg [BUS_RSIF_ID_W-1:0] bus_rsif_aid_shdw; // Registers for shadow
                                             // id values.

  reg [NUM_RSI_FIFOS-1:0] bus_aid_shdw_active_r; // Active bit for each
                                                 // shadow id value.

  reg [NUM_RSI_FIFOS-1:0] bus_aid_shdw_amatch; // Bit for each shadow
                                               // register asserted
                                               // when aid matches.
  

  //-------------------------------------------------------------------- 
  // Re Sizing Information (RSI) Fifo - Control Signals.
  //-------------------------------------------------------------------- 
  
  //-------------------------------------------------------------------- 
  // Generate push signals for RSI fifo's.
  //
  // We have an RSI fifo for each active unique ID we can have, so
  // here we make sure that each RSI fifo will only have a single ID 
  // active within it at any one time. As part of this we will implement
  // number of unique ID limit and number of t/x's per unique ID limit 
  // checking using RSI fifo status and data outputs.
  //
  //-------------------------------------------------------------------- 

  // Decode if aid_i from write address channel matches with any active
  // ID at the head of the RSI fifos and assert a bit specific to that
  // RSI fifo if we do find a match.
  integer rsi_num_rsif;
  integer id_bit_rsif;
  always @(aid_i or bus_rsif_aid or bus_rsif_empty)
  begin : bus_aid_rsif_amatch_PROC

    reg [MP_ID_W-1:0] rsif_aid;

    bus_aid_rsif_amatch = {NUM_RSI_FIFOS{1'b0}};

    for(rsi_num_rsif=0 ; rsi_num_rsif<=(NUM_RSI_FIFOS-1) ; rsi_num_rsif=rsi_num_rsif+1)
    begin
      // Extract rsif_aid from bus.
      for(id_bit_rsif=0 ; id_bit_rsif<=(MP_ID_W-1) ; id_bit_rsif=id_bit_rsif+1) begin
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
        rsif_aid[id_bit_rsif] = bus_rsif_aid[(rsi_num_rsif*MP_ID_W)+id_bit_rsif];
// spyglass enable_block SelfDeterminedExpr-ML
      end

      // Does aid_i match with id at head of this fifo and is this 
      // fifo not empty.
      if((rsif_aid == aid_i) && (~bus_rsif_empty[rsi_num_rsif])) begin
        bus_aid_rsif_amatch[rsi_num_rsif] = 1'b1;
      end
    end // for(rsi_num_rsif=0

  end // bus_aid_rsif_amatch_PROC


  // If aid_i did not match with the id from any active RSI fifos we 
  // need to see if there is free fifo for this ID. Here we find the 
  // lowest numbered free(empty) RSI fifo and assert a bit specific to
  // that fifo.
  integer rsi_num_rsif_lsf;
  always @(*) 
  begin : bus_rsif_lsfree_PROC
    reg found;

    bus_rsif_lsfree = {NUM_RSI_FIFOS{1'b0}};
    found = 1'b0;
//spyglass disable_block W415a 
//SMD: Signal may be multiply assigned (beside initialization) in the same scope.
//SJ : bus_rsif_lsfree and found are initialized to 0 inorder to avoid latches.
    for(rsi_num_rsif_lsf=0 ; rsi_num_rsif_lsf<=(NUM_RSI_FIFOS-1) ; rsi_num_rsif_lsf=rsi_num_rsif_lsf+1)
    begin
      // Assert bit for this fifo if it is empty and is not active for 
      // an outstanding transaction (shadow active reg.) and have we not
      // found a lower numbered empty fifo yet.
      if(   bus_rsif_empty[rsi_num_rsif_lsf] 
         & (~bus_aid_shdw_active_r[rsi_num_rsif_lsf])
         & (~found)
        )
      begin
        bus_rsif_lsfree[rsi_num_rsif_lsf] = 1'b1;
        found = 1'b1;
      end
    end
  end // bus_rsif_lsfree_PROC
//spyglass enable_block W415a 

  //-------------------------------------------------------------------- 
  // This code calculates bus_aid_shdw_amatch which will remember which
  // RSI fifo SP t/x's from the same MP t/x were stored in.
  //
  // We cannot use the fifos to do this because transactions 
  // belonging to the same MP t/x could be popped from the RSI fifos 
  // before the next t/x arrived, and we would not be able to put them 
  // in the same RSI fifo, which is essential to calculate the MP
  // response correctly.
  //-------------------------------------------------------------------- 
  integer rsi_num_aid;
  integer id_bit_aid;
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_rsif_aid_shdw_PROC

    if(~aresetn_i) begin
      bus_rsif_aid_shdw     <= {BUS_RSIF_ID_W{1'b0}};
      bus_aid_shdw_active_r <= {NUM_RSI_FIFOS{1'b0}};
    end else begin

      for(rsi_num_aid=0 ; rsi_num_aid<=(NUM_RSI_FIFOS-1) ; rsi_num_aid=rsi_num_aid+1)
      begin

      // When an RSI slot is selected and rs_push is asserted from
      // the address channel, then load the ID into the 
      // shadow id register and set the active bit also.
      // The priority between the 2 branches of the IF statement is
      // important as a new t/x could be pushed to an RSI fifo in the
      // same cycle that an old one is pushed out, in this case
      // the event we want to capture is the new t/x push.
      if(bus_rsif_sel[rsi_num_aid] & (~rs_push_req_n_i)) begin
  
          // Load id from address channel into this slot.
          for(id_bit_aid=0 ; id_bit_aid<=(MP_ID_W-1) ; id_bit_aid=id_bit_aid+1) begin
            bus_rsif_aid_shdw[(rsi_num_aid*MP_ID_W)+id_bit_aid] 
            <= aid_i[id_bit_aid];
          end
        
          bus_aid_shdw_active_r[rsi_num_aid] <= 1'b1;
        end else begin
          
          // Only deassert active bit when the rsif is popped and it
          // is the last SP t/x for the corresponding MP t/x.
          if(~bus_rsif_pop_n[rsi_num_aid] & bus_rsif_last[rsi_num_aid]) begin
            
            // Clear active bit for shadow id only the current pop
            // will empty the fifo (For this we need to use the pre
            // registered empty signal). If there are still entries
            // in the fifo then there are still active t/x's for this
            // ID.
            if(bus_rsif_empty_nxt[rsi_num_aid]) begin
              bus_aid_shdw_active_r[rsi_num_aid] <= 1'b0;
            end 
        
          end // if(~bus_rsif_pop_n[rsi_num_aid]...

        end 
  
      end // for(rsi_num_aid=0

    end // if(~aresetn_i)

  end // bus_rsif_aid_shdw_PROC

  
  // Decode if aid_i from write address channel matches with any active
  // ID in the shadow id registers. Assert a bit for the corresponding
  // RSI fifo if we do find a match.
  integer rsi_num_aid_shd;
  integer id_bit_aid_shd;
  always @(aid_i or bus_rsif_aid_shdw or bus_aid_shdw_active_r)
  begin : bus_aid_shdw_amatch_PROC

    reg [MP_ID_W-1:0] shdw_aid;

    bus_aid_shdw_amatch = {NUM_RSI_FIFOS{1'b0}};

    for(rsi_num_aid_shd=0 ; rsi_num_aid_shd<=(NUM_RSI_FIFOS-1) ; rsi_num_aid_shd=rsi_num_aid_shd+1)
    begin
      // Extract shdw_aid from bus.
      for(id_bit_aid_shd=0 ; id_bit_aid_shd<=(MP_ID_W-1) ; id_bit_aid_shd=id_bit_aid_shd+1) begin
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
        shdw_aid[id_bit_aid_shd] = bus_rsif_aid_shdw[(rsi_num_aid_shd*MP_ID_W)+id_bit_aid_shd];
// spyglass enable_block SelfDeterminedExpr-ML
      end

      // Does aid_i match with the shadow ID for this RSIF and is
      // the ID active.
      if((shdw_aid == aid_i) && bus_aid_shdw_active_r[rsi_num_aid_shd]) begin
        bus_aid_shdw_amatch[rsi_num_aid_shd] = 1'b1;
      end
    end // for(rsi_num_aid_shd=0

  end // bus_aid_shdw_amatch_PROC


  // Assert bit for the RSI fifo that the next push from the address
  // channel will target. 
  // If aid_i matches with a particular RSI fifo then select that
  // fifo, otherwise select the least significant numbered free
  // fifo.
  // Note we also need to use bus_aid_shdw_amatch to decode where the
  // t/x should go, because 2 SP t/x's for the same MP t/x could have 
  // come and gone from the RSI fifos at different times so there is
  // no record of the previous SP t/x to know it is related with the
  // latter SP t/x ... for this corner case we use bus_aid_shdw_amatch.

  assign bus_rsif_sel 
  = (bus_aid_rsif_amatch=={NUM_RSI_FIFOS{1'b0}})
    ? ( (bus_aid_shdw_amatch=={NUM_RSI_FIFOS{1'b0}})
        ? bus_rsif_lsfree  
        : bus_aid_shdw_amatch
      )
    : bus_aid_rsif_amatch;



  // Assert rs_fifo_full_o back to AW channel. And reduction of a 
  // bitwise and of inverted select per RSIF with full per RSIF, tells
  // us if the selected RSI fifo has room for a push for a t/x with 
  // aid_i. If no RSIF has been selected then assert the signal as there
  // is no free RSIF for this new ID.
  assign rs_fifo_full_o = (bus_rsif_sel == {NUM_RSI_FIFOS{1'b0}}) ? 1'b1 : |(bus_rsif_sel & bus_rsif_full);



  // Assert push for the selected RSI fifo if push asserted from 
  // address channel.
  assign bus_rsif_push_n 
    = ~(bus_rsif_sel & {NUM_RSI_FIFOS{~rs_push_req_n_i}}); 


  // Generate pop signals for RSI fifos.
  integer rsi_num_aid_pop;
  always @(*) 
  begin : bus_rsif_pop_n_PROC

    reg valid_i;

    bus_rsif_pop_n = {NUM_RSI_FIFOS{1'b1}};

    for(rsi_num_aid_pop=0 ; rsi_num_aid_pop<=(NUM_RSI_FIFOS-1) ; rsi_num_aid_pop=rsi_num_aid_pop+1)
    begin
//spyglass disable_block W415a 
//SMD: Signal may be multiply assigned (beside initialization) in the same scope. 
//SJ : valid_i is assigned twice inside a same forloop but depending on mutually exclusive condition. bus_rsif-pop_n is initialized before assigning inorder to avoid latches.
        valid_i = bus_valid_i[0];

      // Valid from SP must be asserted, and SP id must match
      // with an active RSIF.
      if(valid_i & bus_sp_id_rsif_amatch[rsi_num_aid_pop]) 
      begin


        // If this is the burst response for the last of a set of 
        // downsized t/x's we can only assert pop if push_full_i
        // from channel fifo is asserted, otherwise can assert
        // immediately as the burst response will be accepted into
        // a bresp packing register.
        if(bus_rsif_last[rsi_num_aid_pop]) begin
          bus_rsif_pop_n[rsi_num_aid_pop] = push_full_i;
        end else begin
          bus_rsif_pop_n[rsi_num_aid_pop] = 1'b0;
        end


      end // if(bus_valid_i

    end // for(rsi_num_aid_pop=0 ; rsi_num_aid_pop

  end // bus_rsif_pop_n
//spyglass enable_block W415a

  // Build data in bus for RSI fifos.
  assign rsif_di = {last_xact_i, pre_last_xact_i,aid_i};


  //-------------------------------------------------------------------- 
  // Re Sizing Information Fifos (RSIF's).
  //-------------------------------------------------------------------- 
  ubwc_x2x_DW_axi_x2x_sp_b_rsfifos
  
  #(NUM_RSI_FIFOS,      // Number of fifos.
    RSI_FIFO_W,         // Word width.
    RSI_FIFO_D,         // Depth of fifo.
    RSI_FIFO_D_L2,      // Log base 2 of depth.
    BUS_RSI_FIFO_W      // Width of bus of data signals. Just 1
                        // fifo in this instance.
   )
  U_SP_B_RSI_FIFO (
    // Inputs - Push Side 
    .clk_i                 (aclk_i),
    .resetn_i              (aresetn_i),

    .bus_push_req_n_i      (bus_rsif_push_n),
    .data_i                (rsif_di),
  
    // Outputs - Push Side
    .bus_push_full_o       (bus_rsif_full),


    // Inputs - Pop Side 
    .bus_pop_req_n_i       (bus_rsif_pop_n),
  
    // Outputs - Pop Side
    .bus_pop_empty_o       (bus_rsif_empty),
    .bus_pop_empty_nxt_o   (bus_rsif_empty_nxt),
    .bus_data_o            (bus_rsif_do)
  );


  //-------------------------------------------------------------------- 
  // Extract resizing information from RSI fifo.
  // Extract bus of individual RSI signal busses from bus containing
  // all RSI info. signals from all RSI fifos.
  // Data from each RSI fifo is organised in the order {last_xact_i,
  // pre_last_xact_i,aid_i}. last_xact_i and pre_last_xact_i are 1 bit
  // wide and aid_i is MP_ID_W bits wide.
  //-------------------------------------------------------------------- 
  integer rsi_num_extract;
  integer id_bit_extract;
  always @(bus_rsif_do)
  begin : rsif_rsi_extract_PROC

    for(rsi_num_extract=0 ; rsi_num_extract<=(NUM_RSI_FIFOS-1) ; rsi_num_extract=rsi_num_extract+1)
    begin
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
      for(id_bit_extract=0 ; id_bit_extract<=(MP_ID_W-1) ; id_bit_extract=id_bit_extract+1)
      begin
        bus_rsif_aid[(MP_ID_W*rsi_num_extract)+id_bit_extract] 
          = bus_rsif_do[(RSI_FIFO_W*rsi_num_extract)+id_bit_extract];
      end


      bus_rsif_last[rsi_num_extract] 
      = bus_rsif_do[(RSI_FIFO_W*rsi_num_extract)+MP_ID_W+1];
// spyglass enable_block SelfDeterminedExpr-ML
    end

  end // rsif_rsi_extract_PROC


  //-------------------------------------------------------------------- 
  // Extract busses of SP id and resp from bus_payload_i.
  //-------------------------------------------------------------------- 
  always @(bus_payload_i)
  begin : sp_id_resp_extract_PROC
    integer wp_num; // Write port number.
    integer resp_bit;
    integer id_bit;

// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
    for(wp_num=0 ; wp_num<=(NUM_W_PORTS-1) ; wp_num=wp_num+1) 
    begin
      for(resp_bit=0 ; resp_bit<=(BR_W-1) ; resp_bit=resp_bit+1)
      begin
        bus_sp_resp[(BR_W*wp_num)+resp_bit] 
          = bus_payload_i[(SP_PYLD_W*wp_num)+resp_bit];
      end

      for(id_bit=0 ; id_bit<=(MP_ID_W-1) ; id_bit=id_bit+1)
      begin
        bus_sp_id[(MP_ID_W*wp_num)+id_bit] 
          = bus_payload_i[(SP_PYLD_W*wp_num)+BR_W+id_bit];
      end
    end
// spyglass enable_block SelfDeterminedExpr-ML

  end // sp_id_resp_extract_PROC


  //-------------------------------------------------------------------- 
  // Find active ID match from sp_id in RSI fifos.
  //
  // Decode if bus_sp_id matches with any active ID at the head of the 
  // RSI fifos and assert a bit specific to that RSI fifo if we do find 
  // a match.
  //-------------------------------------------------------------------- 
  integer rsi_num_amatch;
  integer id_bit_amatch;
  always @(bus_sp_id or bus_rsif_aid or bus_rsif_empty or bus_valid_i )
  begin : bus_sp_id_rsif_amatch_PROC

    reg valid_i;
    reg [MP_ID_W-1:0] rsif_aid;
    reg [MP_ID_W-1:0] sp_id;

    bus_sp_id_rsif_amatch = {NUM_RSI_FIFOS{1'b0}};

    for(rsi_num_amatch=0 ; rsi_num_amatch<=(NUM_RSI_FIFOS-1) ; rsi_num_amatch=rsi_num_amatch+1)
    begin
      // Extract rsif_aid from bus.
      for(id_bit_amatch=0 ; id_bit_amatch<=(MP_ID_W-1) ; id_bit_amatch=id_bit_amatch+1)
      begin
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
        rsif_aid[id_bit_amatch] = bus_rsif_aid[(rsi_num_amatch*MP_ID_W)+id_bit_amatch];
// spyglass enable_block SelfDeterminedExpr-ML
      end

      // For write fan out enabled configurations the ID from each
      // write port will be compared with the ID from a specific
      // RSI fifo. Otherwise there will be only one write port ID and
      // it will be compared with all RSIF's.
        sp_id = bus_sp_id[MP_ID_W-1:0];

        valid_i = bus_valid_i[0];

      // Does aid_i match with id at head of this fifo and is this 
      // fifo not empty. Qualify with valid in for relevant port.
      if((rsif_aid == sp_id) && (~bus_rsif_empty[rsi_num_amatch]) && valid_i)
      begin
        bus_sp_id_rsif_amatch[rsi_num_amatch] = 1'b1;
      end
    end // for(rsi_num_amatch=0

  end // bus_sp_id_rsif_amatch_PROC


  //-------------------------------------------------------------------- 
  // Assert bit ( or bit per RSI fifo for fan out confis), 
  // when t/x being packed for that RSIF is ready to be pushed into
  // channel fifo. Decoded as valid and last bit asserted from RSIF 
  // and an active match with SP id and that RSIF.
  // Note for write fan out enabled configs there can be more than
  // one bit of this signal asserted at a time, but for non write
  // fan out configs only 1 bit will ever be assertd at a time.
  //-------------------------------------------------------------------- 
  generate if (WI_FAN_OUT)
    assign bus_chf_push_req = ((bus_valid_i & bus_rsif_last & bus_sp_id_rsif_amatch) & (!push_full_i));
  else
  begin
    assign bus_chf_push_req = (|({NUM_RSI_FIFOS{bus_valid_i}} & bus_rsif_last & bus_sp_id_rsif_amatch)) & (!push_full_i);
  end
  endgenerate


  //-------------------------------------------------------------------- 
  // Arbitrate between push requests for write fan out enabled 
  // configurations.
  //-------------------------------------------------------------------- 
   
  generate
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : bus_chf_arb_push is read only when X2X_WI_FAN_OUT is defined or bus_rsif_last[rsi_num_aid_pop] is set.
  if(NUM_W_PORTS>1) begin: ARB_BETWEEN_PUSH_REQ
        
// Dummy wires - used to suppress unconnected ports warnings by lint tool - BR - 2/25/2010
  wire l_unconn, p_unconn; 
  wire gi_unconn;

    ubwc_x2x_DW_axi_x2x_bcm51
    
    #(NUM_W_PORTS, // Number of clients.
      0,           // No parking logic required.
      0,           // Park index, don't care.
      0            // Output mode, non registered.
    )
    U_x2x_b_wfo_arb (
      // Inputs 
      .clk          (aclk_i),
      .rst_n        (aresetn_i),
      .enable       (1'b1), // Always enable.
      .mask         ({NUM_W_PORTS{1'b0}}), // Never mask.
  
      .request      (bus_chf_push_req),
      
      // Outputs
      .granted      (chf_arb_push),
      .grant        (bus_chf_arb_push),
      
      // Unconnected
      // Inputs
      .init_n       (1'b1),  // Synchronous reset not used.    
      .lock         (1'b0),  // Locking not used.   
  
      // Outputs
      .locked       (l_unconn),
      .grant_index  (gi_unconn),
      .parked       (p_unconn)
    );
  end else begin: NUM_W_PORTS_LT1
  // These signals are tied to zeros if NUM_W_PORTS <=1.
    assign chf_arb_push = 1'b0;
    assign bus_chf_arb_push = {NUM_W_PORTS{1'b0}};
  end
  //spyglass enable_block W528
  endgenerate


  //-------------------------------------------------------------------- 
  // Response Packing 
  //
  // When transactions have been split into multiple transactions by
  // the resizer in the address channel, this block will receive 
  // multiple burst responses and will have to pack them up to generate
  // a single burst response for the original pre-resized t/x.
  //
  // Divided into :
  // - Next state process.
  // - Register process.
  //-------------------------------------------------------------------- 
  
  integer rsi_num_resp;
  integer resp_bit_pack;
  // Next state packing register process.
  always @(bus_sp_resp           or 
           bus_resp_pack_r       or 
           bus_sp_id_rsif_amatch
          )
  begin : bus_resp_pack_nxt_PROC

    reg [BR_W-1:0] sp_resp;
    reg [BR_W-1:0] resp_pack_r;
    reg [BR_W-1:0] resp_pack_nxt;
       sp_resp = bus_sp_resp[BR_W-1:0];

// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
    for(rsi_num_resp=0 ; rsi_num_resp<=(NUM_RSI_FIFOS-1) ; rsi_num_resp=rsi_num_resp+1)
    begin 

      // Select sp_resp that will be used to update the packing register
      // for this RSI fifo. Write fan out enabled configs will have
      // a resp input for every RSIF , non write fan out configs will
      // have just 1 resp input.


      // Extract resp_pack_r from bus for this RSI fifo.
      for(resp_bit_pack=0 ; resp_bit_pack<=(BR_W-1) ; resp_bit_pack=resp_bit_pack+1)
      begin
        resp_pack_r[resp_bit_pack]
          = bus_resp_pack_r[(rsi_num_resp*BR_W)+resp_bit_pack];
      end
// spyglass enable_block SelfDeterminedExpr-ML

      // Default value.
      resp_pack_nxt = resp_pack_r;

      // Update if the id from SP is an active match with this RSIF.
      if(bus_sp_id_rsif_amatch[rsi_num_resp]) begin
        // Order of priority of resp values.
        // 1. DECERR
        // 2. SLVERR
        // 3. OKAY
        // 4. EXOKAY
        case(resp_pack_r) 
          // Lowest priority so can be overridden by anything.
          `ubwc_x2x_X2X_RESP_EXOKAY : begin
            resp_pack_nxt = sp_resp;
          end
        
          // OKAY response can only be overridden by a SLVERR or
          // DECERR.
          `ubwc_x2x_X2X_RESP_OKAY : begin
            if(   (sp_resp == `ubwc_x2x_X2X_RESP_SLVERR) 
               || (sp_resp == `ubwc_x2x_X2X_RESP_DECERR)
              )
            begin
              resp_pack_nxt = sp_resp;
            end
          end
        
          // SLVERR response can only be overridden by a DECERR.
          `ubwc_x2x_X2X_RESP_SLVERR : begin
            if(sp_resp == `ubwc_x2x_X2X_RESP_DECERR)
            begin
              resp_pack_nxt = `ubwc_x2x_X2X_RESP_DECERR;
            end
          end
        
          // Highest priority so hold value.
          `ubwc_x2x_X2X_RESP_DECERR : begin
            resp_pack_nxt = `ubwc_x2x_X2X_RESP_DECERR;
          end
          
        endcase

      end

      // Append updated response into bussed "nxt" signal.
      for(resp_bit_pack=0 ; resp_bit_pack<=(BR_W-1) ; resp_bit_pack=resp_bit_pack+1)
      begin
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
        bus_resp_pack_nxt[(rsi_num_resp*BR_W)+resp_bit_pack] 
         = resp_pack_nxt[resp_bit_pack];
// spyglass enable_block SelfDeterminedExpr-ML
      end

    end // for(rsi_num_resp=0

  end // bus_resp_pack_nxt_PROC


  // Create signal with EXOKAY response contents.
  assign resp_exokay = `ubwc_x2x_X2X_RESP_EXOKAY;

    integer rsi_num_resp_pop;
    integer resp_bit_pop;
  // Packing register process.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_resp_pack_r_PROC

    if(~aresetn_i) begin
      bus_resp_pack_r <= {BUS_UWID_BR_W{1'b0}};
    end else begin

      for(rsi_num_resp_pop=0 ; rsi_num_resp_pop<=(NUM_RSI_FIFOS-1) ; rsi_num_resp_pop=rsi_num_resp_pop+1)
      begin
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.

        // Reset the resp for this RSI fifos pack register to EXOKAY
        // if it has been accepted into the channel fifo. 
        // Decoded as a the RSI fifo being popped in the same cycle
        // that a push is being issued fro the channel fifo.
        // Note difference in push signals for fan out and non fan
        // out configs.
        if(((WI_FAN_OUT == 0) && 
            (~bus_rsif_pop_n[rsi_num_resp_pop] & bus_chf_push_req[0])
           ) ||
           ((WI_FAN_OUT == 1) && 
            (~bus_rsif_pop_n[rsi_num_resp_pop] & chf_arb_push)
           ) 
          ) begin
          for(resp_bit_pop=0 ; resp_bit_pop<=(BR_W-1) ; resp_bit_pop=resp_bit_pop+1)
          begin
            bus_resp_pack_r[(rsi_num_resp_pop*BR_W)+resp_bit_pop]
              <= resp_exokay[resp_bit_pop];
          end
        
        // Otherwise use the next state value.
        end else begin
          for(resp_bit_pop=0 ; resp_bit_pop<=(BR_W-1) ; resp_bit_pop=resp_bit_pop+1)
          begin
            bus_resp_pack_r[(rsi_num_resp_pop*BR_W)+resp_bit_pop]
              <= bus_resp_pack_nxt[(rsi_num_resp_pop*BR_W)+resp_bit_pop];
          end
        end

      end // for(rsi_num_resp_pop=0 
// spyglass enable_block SelfDeterminedExpr-ML
      
    end // if(~aresetn_i)
  end // bus_resp_pack_r_PROC


  // Packing register resp select mux.
  ubwc_x2x_DW_axi_x2x_busmux_ohsel
  
  #(MAX_UWIDA, // Number of buses to mux between.
    BR_W       // Width of each bus input to the mux.
  ) 
  U_resp_pack_busmux (
    .sel   (bus_sp_id_rsif_amatch),
    .din   (bus_resp_pack_nxt),
    .dout  (mux_resp_pack_nxt)
  );


  //-------------------------------------------------------------------- 
  // Generate payloads for channel fifo payload mux using resp from 
  // packing registers.
  //-------------------------------------------------------------------- 
  always @(*)
  begin : bus_pyld_rpck_chf_mux_PROC
    integer wp_num_pyld; // Write port number.
    integer resp_bit_pyld;
    integer id_bit_pyld;
    integer sb_bit_pyld;
//spyglass disable_block W415a 
//SMD: Signal may be multiply assigned (beside initialization) in the same scope.
//SJ : bus_pyld_rpck_chf_mux signal is assigned multiple times depending upon usage of the signal.
//spyglass disable_block W528
//SMD: A signal or variable is set but never read.
//SJ : bus_pyld_rpck_chf_mux is read only when X2X_WI_FAN_OUT is defined and TX_ALTER != `ubwc_x2x_X2X_TX_NO_ALTER.
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
    for(wp_num_pyld=0 ; wp_num_pyld<=(NUM_W_PORTS-1) ; wp_num_pyld=wp_num_pyld+1) begin

      // RESP - from packing registers.
      // For fan out we have multiple payloads, and each one is 
      // associated with a single packing register.
        // For non fanout we have a single payload and the packing
        // register selected depends on which RSIF the SP id matched
        // with, so comes from a mux.
        for(resp_bit_pyld=0 ; resp_bit_pyld<=(BR_W-1) ; resp_bit_pyld=resp_bit_pyld+1) 
        begin
          bus_pyld_rpck_chf_mux[(SP_PYLD_W*wp_num_pyld)+resp_bit_pyld]
            = mux_resp_pack_nxt[resp_bit_pyld];
        end

      // ID - from SP.
      for(id_bit_pyld=0 ; id_bit_pyld<=(MP_ID_W-1) ; id_bit_pyld=id_bit_pyld+1) 
      begin
        bus_pyld_rpck_chf_mux[(SP_PYLD_W*wp_num_pyld)+BR_W+id_bit_pyld]
          = bus_sp_id[(MP_ID_W*wp_num_pyld)+id_bit_pyld]; 
      end
      

    end // for(wp_num_pyld=0
// spyglass enable_block SelfDeterminedExpr-ML
//spyglass enable_block W528
//spyglass enable_block W415a
  end // bus_payload_chf_mux_PROC



  //-------------------------------------------------------------------- 
  // Final channel fifo connections.
  //-------------------------------------------------------------------- 

  // For write fan out enabled configs use push from the arbiter
  // , if not there is only 1 push request signal so we can bypass
  // ther arbiter.
  // spyglass disable_block W576
  // SMD: Logical operator used on a multibit value
  // SJ: X2X_HAS_ET is a parameter which can be set to 0 or 1. Since, parameter
  // is by default 32 bit, spyglass is considering it as a vector. Functionally
  // there will not be any issue as the result will be either 0 or 1.
  assign push_req_n_o = ((TX_ALTER != `ubwc_x2x_X2X_TX_NO_ALTER) || WI_FAN_OUT)
  // spyglass enable_block W576
                       
                       // Some kind of t/x altering is taking place
                       // or write fan out is enabled.
                        ? (WI_FAN_OUT ? ~chf_arb_push 
                        : ~bus_chf_push_req[0])
                       
                       // No altering or fan out so ready out is 
                       // controlled by valid from sp and channel fifo 
                       // full status.
                        : ~(bus_valid_i & (~push_full_i));

                     // If no write fan out is enabled but there is
                     // t/x altering use lower bits of
                     // bus_pyld_rpck_chf_mux, which is prior to
                     // payload mux.
  assign payload_o = (TX_ALTER != `ubwc_x2x_X2X_TX_NO_ALTER) ? bus_pyld_rpck_chf_mux[SP_PYLD_W-1:0]
                     // If neither t/x altering or write fan out
                     // connect directly from payload in.
                       : bus_payload_i[SP_PYLD_W-1:0];

  //-------------------------------------------------------------------- 
  // Drive ready out from X2X SP.
  // We assert ready for a burst response at the same time we pop the
  // RSI fifo. For write fan out enabled configs there is a bus of 
  // ready signals corresponding to each RSI fifo, otherwise a there is
  // only 1 ready output and a pop from any RSI fifo implies acceptance
  // of a burst response.
  //-------------------------------------------------------------------- 
/*  assign bus_ready_o = ((TX_ALTER != `ubwc_x2x_X2X_TX_NO_ALTER) || WI_FAN_OUT)

                      // Some kind of t/x altering is taking place
                      // or write fan out is enabled.
                             ? (WI_FAN_OUT ? ~bus_rsif_pop_n
                                    : |(~bus_rsif_pop_n))
               
                      // No altering or fan out so ready out is 
                      // controlled by channel fifo full status.
                       : ~push_full_i;
  */ 
  generate if (WI_FAN_OUT)
    assign bus_ready_o = ~bus_rsif_pop_n;
  else if ((TX_ALTER != `ubwc_x2x_X2X_TX_NO_ALTER) && (NUM_RSI_FIFOS > 1))
    assign bus_ready_o = |(~bus_rsif_pop_n);
  else if ((TX_ALTER != `ubwc_x2x_X2X_TX_NO_ALTER))
    assign bus_ready_o = (~bus_rsif_pop_n);
  else
    assign bus_ready_o = ~push_full_i;
  endgenerate

  //-------------------------------------------------------------------- 
  // Completion signaling to SP AW block. Used for locking t/x control.
  //-------------------------------------------------------------------- 
 

endmodule
