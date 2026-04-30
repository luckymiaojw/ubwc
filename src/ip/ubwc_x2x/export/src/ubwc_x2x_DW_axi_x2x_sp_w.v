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
// Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/src/DW_axi_x2x_sp_w.v#11 $ 
**
** --------------------------------------------------------------------
**
** File     : DW_axi_x2x_sp_w.v
** Abstract : This block implements the write data control block
**            in the X2X slave port.
**
**            It receives notification of issued transactions from
**            the slave port write address channel, stores them in
**            a fifo and converts write data beats from the master
**            ports to match the transactions issued by the slave port
**            address channels.
**
** --------------------------------------------------------------------
*/

`include "ubwc_x2x_DW_axi_x2x_all_includes.vh"

module ubwc_x2x_DW_axi_x2x_sp_w (
  // System inputs
  aclk_i,
  aresetn_i,

  // SP WRITE ADDRESS CHANNEL I/F
  // Inputs 
  rs_push_req_n_i,
  alen_i,
  aburst_i,
  asize_sp_i,
  asize_mp_i,
  addr_i,
  us_xact_issue_off_i,
  
  // Outputs 
  rs_fifo_full_o,

  // CHANNEL FIFO I/F
  // Inputs 
  pop_empty_i,
  payload_i,
  
  // Outputs 
  pop_req_n_o,
  

  // EXTERNAL SLAVE PORT I/F
  // Inputs 
  ready_i,
  
  // Outputs 
  valid_o,
  payload_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------

  // INTERNAL PARAMETERS - MUST NOT BE SET BY INSTANTIATION
  parameter MP_ID_W             = `ubwc_x2x_X2X_MP_IDW;          // Internal ID width will always be this value. May be padded
                                                        // out to larger width before being forwarded from the SP.
  parameter SP_PYLD_W           = `ubwc_x2x_X2X_WPYLD_W_SP;      // SP payload width.
  parameter MP_PYLD_W           = `ubwc_x2x_X2X_WPYLD_W_MP;      // MP payload width.
  parameter SP_BL_W             = `ubwc_x2x_X2X_SP_BLW;          // SP burst length signal width.
  parameter BS_W                = `ubwc_x2x_X2X_BSW;             // Burst size signal width.
  parameter BT_W                = `ubwc_x2x_X2X_BTW;             // Burst type signal width.
  parameter RSI_FIFO_W          = `ubwc_x2x_X2X_SP_W_RSFIFO_W;   // Width of resize info. fifo.
  parameter RSINFO_FIFO_D       = `ubwc_x2x_X2X_SP_W_RSFIFO_D;   // Depth of resizing info. fifo.
  parameter RSINFO_FIFO_D_L2    = `ubwc_x2x_X2X_SP_W_RSFIFO_D_L2;// Log base 2 of RSINFO_FIFO_D.
  parameter ADDR_TRK_W          = `ubwc_x2x_X2X_ADDR_TRK_W;      // Bits of address that X2X requires for resizing.
  parameter BEATS_PER_POP_W     = `ubwc_x2x_X2X_SP_W_BEATS_PER_POP_W; // Beats per pop width.     
  parameter WID                 = (`ubwc_x2x_X2X_HAS_WI_FAN_OUT ? 1 : `ubwc_x2x_X2X_WID); // Write interleaving depth.
  parameter BUS_MP_ID_W         = (WID*MP_ID_W);        // Bussed resize info. slot signal widths.
  parameter BUS_SP_BL_W         = (WID*SP_BL_W);        // Bussed resize info. slot signal widths.
  parameter BUS_BS_W            = (WID*BS_W);           // Bussed resize info. slot signal widths.
  parameter BUS_BT_W            = (WID*BT_W);           // Bussed resize info. slot signal widths.
  parameter BUS_ADDR_TRK_W      = (WID*ADDR_TRK_W);     // Bussed resize info. slot signal widths.
  parameter BUS_BEATS_PER_POP_W = (WID*BEATS_PER_POP_W);// Bussed resize info. slot signal widths.
  parameter MP_DW               = `ubwc_x2x_X2X_MP_DW;           // MP signal width parameters.
  parameter MP_SW               = `ubwc_x2x_X2X_MP_SW;           // MP signal width parameters.
  parameter SP_DW               = `ubwc_x2x_X2X_SP_DW;           // SP signal width parameters.
  parameter SP_SW               = `ubwc_x2x_X2X_SP_SW;           // SP signal width parameters.
  parameter DATA_SEL_W          = `ubwc_x2x_X2X_DATA_SEL_W;      // Data select width.
  parameter SP_LOG2_SW          = `ubwc_x2x_X2X_LOG2_SP_SW;      // Log base 2 of SP strobe width.
 parameter LOG2_MAX_SW          = `ubwc_x2x_X2X_LOG2_MAX_SW;     // Log b2 of max strobe width.
  // Slave port data width divided by all possible values of mp_asize.

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
  // The signal is_xact_issue_off_i is not used when WID==1
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read.
  //SJ : The signal us_xact_issue_off_i is not used when WID==1
  input         us_xact_issue_off_i; // Used in controlling issuing of upsized t/x data in configs with X2X_WID>1.
  //spyglass enable_block W240
  input [SP_BL_W-1:0]    alen_i;
  input [BT_W-1:0]       aburst_i;
  input [BS_W-1:0]       asize_sp_i; // Size of t/x issued from SP.
  input [BS_W-1:0]       asize_mp_i; // Size of t/x issued to MP.
  input [ADDR_TRK_W-1:0] addr_i;     // Require certain bits of t/x addr to track beat location if MP_DW != SP_DW.
   
  // Outputs 
  output rs_fifo_full_o;      // Resize info. fifo full.


  //--------------------------------------------------------------------
  // CHANNEL FIFO I/F
  //--------------------------------------------------------------------
  // Inputs 
  // pop_empty_i is used according to multiple configurations, and may be non driving in specific configurations. 
  input                 pop_empty_i; // Empty status from channel fifo.
  input [MP_PYLD_W-1:0] payload_i;   // Payload from channel fifo.
  
  // Outputs 
  output                pop_req_n_o; // Pop request to channel fifo.
  reg                   pop_req_n_o; 
  
  //--------------------------------------------------------------------
  // EXTERNAL SLAVE PORT I/F
  //--------------------------------------------------------------------
  // Inputs 
  input ready_i; // Ready from SP.
  
  // Outputs 
  // valid_o is used according to multiple configurations, and may be non driving in some specific configurations.
  output valid_o; // Valid to SP.
  reg    valid_o; 
  output [SP_PYLD_W-1:0] payload_o; // Payload to SP.

  //--------------------------------------------------------------------
  // WIRE/REGISTER VARIABLE DECLARATIONS
  //--------------------------------------------------------------------
  
  // RESIZE INFO. CONDITIONING SIGNALS.
  reg [ADDR_TRK_W-1:0] addr_aligned; // addr_i aligned w.r.t. asize_sp_i.
 
  // RSI FIFO SIGNALS.
  reg [RSI_FIFO_W-1:0] rsi_fifo_di; // Data in to resize info. fifo.
  // In some configurations this signal is unused. It is retained as it is an ouput from a BCM module.
  wire [RSI_FIFO_W-1:0] rsi_fifo_do; // Data out from resize info. fifo.

  wire rsi_fifo_push_n;
  wire rsi_fifo_pop_n;
  
  // Full and empty fifo status.
  wire rsi_fifo_full;  
  wire rsi_fifo_empty;

  // Resizing information signals from the output of the resize
  // information fifo.
  reg  [MP_ID_W-1:0]         rsif_aid;
  reg  [SP_BL_W-1:0]         rsif_alen;
  reg  [BT_W-1:0]            rsif_aburst;
  reg  [BS_W-1:0]            rsif_asize_sp;
  reg  [BS_W-1:0]            rsif_asize_mp;
  reg  [LOG2_MAX_SW:0]       rsif_asize_mp_bytes;
  reg  [ADDR_TRK_W-1:0]      rsif_addr;
  wire [BEATS_PER_POP_W-1:0] rsif_bpp;    // Beats per pop.
  reg  [BEATS_PER_POP_W-1:0] rsif_fb_bpp; // First mp beat, 
                                          // beats per pop.
  
  parameter  [BEATS_PER_POP_W-1:0] CONST_RSIF_FB_BPP_1 = 1; // First mp beat, 

  // RESIZE INFO. SLOT CONTROL SIGNALS
  reg [WID-1:0] rsis_newtx; // Bit for each slot asserted when there is information for a new t/x to load.
  wire [WID-1:0] rsis_update_mp; // Bit for each slot asserted when there is updated information 
                                 // while the t/x is in progress, following acceptance of an MP beat.
  wire [WID-1:0] rsis_update_sp; // Bit for each slot asserted when there is updated information 
                                 // while the t/x is in progress, following acceptance of an SP beat.

  // RESIZE INFO. SLOT SIGNALS
  // Slot for 1 to write interleaving depth (WID).
  reg [BUS_MP_ID_W-1:0]         bus_rsis_aid_r;
  reg [BUS_SP_BL_W-1:0]         bus_rsis_alen_r;
  reg [BUS_BT_W-1:0]            bus_rsis_aburst_r;
  reg [BUS_BS_W-1:0]            bus_rsis_asize_sp_r;
  reg [WID-1:0] bus_rsis_active_r; // Bit for each slot asserted if slot
                                   // is active.
  reg [BUS_BS_W-1:0]            bus_rsis_asize_mp_r;
  reg [BUS_ADDR_TRK_W-1:0]      bus_rsis_addr_r;
  
  wire [BEATS_PER_POP_W-1:0] rsis_bpp;    // Beats per pop and first 
  reg  [BEATS_PER_POP_W-1:0] rsis_fb_bpp; // beat beats per pop. Derived from rsis mux_* signals.

  // AXI MP CHANNEL SIGNALS - Extracted from channel fifo payload.
  wire [MP_ID_W-1:0] mp_id;
  wire [MP_DW-1:0]   mp_wdata;
  wire [MP_SW-1:0]   mp_wstrb;
  // This signal is used only when (`ubwc_x2x_X2X_TX_ALTER==`ubwc_x2x_X2X_TX_NO_ALTER)
  wire               mp_wlast;

  // ENDIAN TRANSFORMED AXI MP CHANNEL SIGNALS
  wire [MP_DW-1:0] et_mp_wdata;
  wire [MP_SW-1:0] et_mp_wstrb;
  
  // AXI SP CHANNEL SIGNALS  
  wire [SP_DW-1:0]   sp_wdata;
  wire [SP_SW-1:0]   sp_wstrb;
  wire               sp_wlast;

  // ID MATCHING SIGNALS
  wire match_active_id; // Asserted when ID from channel fifo matches with an active set
                        // of resizing information from either the RSI fifo or RSI slots.

  reg [WID-1:0] rsis_match; // Bit for each RSI slot asserted when ID from
                            // channel fifo matches with ID in the RSI slot.

  wire rsif_match; // Asserted when channel ID does not match with any active RSI
                   // slot ID's but matches with ID at the head of the RSI fifo.

  // CURRENT T/X ATTRIBUTE SIGNALS
  // Selected from either the RSI slots or the RSI fifo.
  wire [SP_BL_W-1:0]         mux_alen;
  wire [BT_W-1:0]            mux_aburst;
  wire [BS_W-1:0]            mux_asize_sp;
  wire [BS_W-1:0]            mux_asize_mp;
  reg  [LOG2_MAX_SW:0]       mux_asize_sp_bytes;
  reg  [LOG2_MAX_SW:0]       mux_asize_mp_bytes;
  wire [ADDR_TRK_W-1:0]      mux_addr;
  wire [BEATS_PER_POP_W-1:0] mux_bpp;
  // BEAT GENERATION SIGNALS
  
  // Address used to track position of active beats in data bus.
  // Register and next register value variables.
  reg [ADDR_TRK_W-1:0] update_addr_nxt; 
  reg [ADDR_TRK_W-1:0] update_addr_r; 

// Depedning on the MP/SP data bus widths, some LSBs of this signal maybe unused. This is not an issue.
  wire [ADDR_TRK_W-1:0] current_addr;

  wire [SP_BL_W-1:0] update_alen; // Tracks remaing beats in t/x.

  // Tracks number of beats issued for every pop from channel fifo.
  // Register value and nxt - nxt value to register.
  // Used to generate pop to channel fifo.
  reg [BUS_BEATS_PER_POP_W-1:0] update_bpp_r; 
  reg  [BUS_BEATS_PER_POP_W-1:0] update_bpp_nxt; 

  wire beat_acc_mp; // Asserted when an mp beat is accepted.
  wire beat_acc_sp; // Asserted when an sp beat is accepted.

  
  // DATA AND STROBE MUX SIGNALS
  wire [DATA_SEL_W-1:0] sp_data_sel; // Select lines for selecting
                                     // sp write data from mp write
                                     // data.


  // UPSIZING VARIABLES

  wire upsized_tx; // Asserted when current beat is from an upsized
                   // transactions.

  wire pack_reg_nxt_full; // Asserted when next beat from channel fifo
                          // to currently active packing register 
                          // will fill it.
// Dummy wires - used to suppress unconnected ports warnings by lint tool - BR - 2/24/2010
   wire ae_unconn, hf_unconn, af_unconn, error_unconn; 
   
  //--------------------------------------------------------------------
  // Signals used in synchronising issuing of upsized write t/x's
  // with upsized write data for configs with WID > 1.
  //--------------------------------------------------------------------


  // Bit for each write interleaving depth to tell us when the upsized
  // t/x currently being processed has started.
  reg [WID-1:0] bus_us_tx_started_r; 

  //--------------------------------------------------------------------
  // The Resize Information Fifo (RSIF) stores information about slave
  // port transactions from the resizer block in the write address
  // channel. We need this information here in order to rebuild the 
  // write beats into the new transaction that the X2X has issued.
  //
  // The following steps are done to generate input data for RSI fifo
  //
  // 1. Condition data from SP AW.
  // 2. Collect into single vector depending on required data.
  //--------------------------------------------------------------------


  // 1. Condition data from SP AW.
  //    - Align address with respect to the asize of the smaller
  //      data width side. This is only functionaly necessary for 
  //      upsizing configurations but we do in all cases for clarity
  //      and ease of debugging.
//spyglass disable_block W415a 
//SMD: Signal may be multiply assigned (beside initialization) in the same scope.
//SJ : Here addr_aligned is initialized to 0 before assignment statement to avoid latches.
  always @(*)
  begin : addr_aligned_PROC
    reg [`ubwc_x2x_X2X_BSW-1:0] size;
    reg [ADDR_TRK_W-1:0] size_addr_mask;
    reg [ADDR_TRK_W-1:0] all_1s_aw;

    addr_aligned = {ADDR_TRK_W{1'b0}};

    // Align with respect to the asize of the smaller side.
    size = asize_sp_i;

    // Align address by zeroing lsb's depending on size value.
    // Do this by ANDing the address with a mask generated from the 
    // size we want to align with. Mask will have 0's in bit positions 
    // that address within the size.
    all_1s_aw = {ADDR_TRK_W{1'b1}};
    size_addr_mask = (all_1s_aw << size);
    addr_aligned = addr_i & size_addr_mask;
  end // addr_aligned_PROC
//spyglass enable_block W415a


  // 2. Collect into single vector depending on required data.
  //    - The data we put into the fifo changes depending on the
  //      configuration so here we will select what goes into the
  //      resize info. fifo.
  always @(*)
  begin : rsi_fifo_di_PROC
    integer start_bit;
    integer sz_bit;
    integer len_bit;
    integer addr_bit;
    integer burst_bit;
    // Using start bit variable to track where next signals should
    // be concatenated to rsi_fifo_di.
    // spyglass disable_block W528
    // SMD: A signal or variable is set but never read.
    // SJ : This signal is used to track where next signals should be concatenated to rsi_fifo_di. So if rsi_fifo_di is never updated in any one of the configuration, then start_bit is unused.
    start_bit = 0;
   // spyglass enable_block W528
  // Some of the bits in the rsi_fifo_di register will always be set to zero. This is due to assigning the respective bits of this register based on the configuration.
    rsi_fifo_di = {RSI_FIFO_W{1'b0}};
//spyglass disable_block W415a 
//SMD: Signal may be multiply assigned (beside initialization) in the same scope.
//SJ : Nets of rsi_fifo_di is always initialized to zero in order to avoid latches when some of the bits are not assigned during implementation.



    // asize_mp
    // Endian mapping, downsizing, or SP larger with upsizing.
      // an input to the module
      for(sz_bit=0 ; sz_bit<=(BS_W-1) ; sz_bit=sz_bit+1)
      begin
        rsi_fifo_di[start_bit+sz_bit] = asize_mp_i[sz_bit];
      end
      start_bit = start_bit + BS_W;

    // asize_sp
    // Any difference in MP and SP data widths.
      for(sz_bit=0 ; sz_bit<=(BS_W-1) ; sz_bit=sz_bit+1)
      begin
        rsi_fifo_di[start_bit+sz_bit] = asize_sp_i[sz_bit];
      end
      start_bit = start_bit + BS_W;

    // alen
    // Any difference in data widths or len widths.
      for(len_bit=0 ; len_bit<=(SP_BL_W-1) ; len_bit=len_bit+1)
      begin
        rsi_fifo_di[start_bit+len_bit] = alen_i[len_bit];
      end
      start_bit = start_bit + SP_BL_W;

    // addr
    // Any difference in data widths.
      for(addr_bit=0 ; addr_bit<=(ADDR_TRK_W-1) ; addr_bit=addr_bit+1)
      begin
        rsi_fifo_di[start_bit+addr_bit] = addr_aligned[addr_bit];
      end
      start_bit = start_bit + ADDR_TRK_W;

    // aburst
    // Any difference in data widths.
      for(burst_bit=0 ; 
          burst_bit<=(BT_W-1) ; 
          burst_bit=burst_bit+1
         )
      begin
        rsi_fifo_di[start_bit+burst_bit] = aburst_i[burst_bit];
      end
      start_bit = start_bit + BT_W;
//spyglass enable_block W415a
  end // rsi_fifo_di_PROC


  //-------------------------------------------------------------------- 
  // Re Sizing Information (RSI) Fifo - Control Signals.
  //-------------------------------------------------------------------- 

  // Generate push to RSI fifo. Gate with full status to avoid overflow.
  assign rsi_fifo_push_n = rs_push_req_n_i | rsi_fifo_full;
  
  // Generate pop to RSI fifo. We pop whenever the incoming channel
  // ID matches with no active RSI slot but matches with the ID at 
  // the head of the RSIS fifo.
  assign rsi_fifo_pop_n = ~rsif_match;


  //-------------------------------------------------------------------- 
  // Re Sizing Information (RSI) Fifo.
  //-------------------------------------------------------------------- 
  // The depth of this fifo is the number of unique write ID's * the 
  // number of active transactions per unique ID. Because of the write
  // ordering rules (must start in address order) we can get away with
  // using 1 fifo here. In the SP B channel there will be a separate 
  // fifo for each unique ID, so this block will stall the SP AW channel
  // if either the unique ID or t/x per unique ID limits are reached.
  //--------------------------------------------------------------------
//spyglass disable_block W528
//SMD: A signal or variable is set but never read.
//SJ : BCM components are configurable to use in various scenarios in this particular design we are not using certain ports. Hence although those signals are read we are not driving them. Therefore waiving this warning.
  ubwc_x2x_DW_axi_x2x_bcm65
  
  #(RSI_FIFO_W,      // Word width.
    RSINFO_FIFO_D,   // Word depth.  
    1,               // ae_level, don't care.
    1,               // af_level, don't care.
    0,               // err_mode, don't care.
    0,               // Reset mode, asynch. reset including memory.
    RSINFO_FIFO_D_L2 // Fifo address width.
  )
  U_SP_W_RSI_FIFO (
    .clk            (aclk_i),   
    .rst_n          (aresetn_i),
    .init_n         (1'b1), // Synchronous reset, not used.

    // Push side - Inputs
    .push_req_n     (rsi_fifo_push_n),
    .data_in        (rsi_fifo_di),   
    
    // Push side - Outputs
    .full           (rsi_fifo_full), 

    // Pop side - Inputs
    .pop_req_n      (rsi_fifo_pop_n),   
    
    // Pop side - Outputs
    .data_out       (rsi_fifo_do),
    .empty          (rsi_fifo_empty),

    // Unconnected or tied off.
    .diag_n         (1'b1), // Never using diagnostic mode.
    .almost_empty   (ae_unconn),
    .half_full      (hf_unconn),
    .almost_full    (af_unconn),
    .error          (error_unconn)
  );
//spyglass enable_block W528

  // spyglass disable_block SelfDeterminedExpr-ML
  // SMD: Self determined expression found
  // SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
  //--------------------------------------------------------------------
  // Extract individual signals from resize fifo data out.
  //--------------------------------------------------------------------
  always @(*)
  begin : rsi_fifo_do_PROC
    integer start_bit;
    integer sz_bit;
    integer len_bit;
    integer addr_bit;
    integer burst_bit;

    // Using start bit variable to track where next signals should
    // be from in rsi_fifo_do.
    // spyglass disable_block W528
    // SMD: A signal or variable is set but never read.
    // SJ : This signal is used to track where next signals should be concatenated to rsi_fifo_do. So if rsi_fifo_do is never updated in any one of the configuration, then start_bit is unused.
    start_bit = 0;
    // spyglass enable_block W528
    rsif_aburst = {BT_W{1'b0}};

    {rsif_aid, rsif_asize_mp, rsif_alen, rsif_asize_sp, rsif_addr}
      = {(MP_ID_W+BS_W+SP_BL_W+BS_W+ADDR_TRK_W){1'b0}}; //{RSI_FIFO_W{1'b0}};

    // aid
//spyglass disable_block W415a 
//SMD: Signal may be multiply assigned (beside initialization) in the same scope.
//SJ : rsif_aid, rsid_asize_mp, rsif_asize_sp, rsif_alen, rsif_addr, rsif_aburst are initialized to 0 inorder to optimize the synthesis process if unused.
    rsif_aid = {MP_ID_W{1'b0}};



    // asize_mp
    // Endian mapping or SP larger with upsizing.
      for(sz_bit=0 ; sz_bit<=(BS_W-1) ; sz_bit=sz_bit+1)
      begin
        rsif_asize_mp[sz_bit] = rsi_fifo_do[start_bit+sz_bit];
      end
      start_bit = start_bit + BS_W;

    // asize_sp
    // Any difference in MP and SP data widths.
      for(sz_bit=0 ; sz_bit<=(BS_W-1) ; sz_bit=sz_bit+1)
      begin
        rsif_asize_sp[sz_bit] = rsi_fifo_do[start_bit+sz_bit];
      end
      start_bit = start_bit + BS_W;

    // alen
    // Any difference in data widths or len widths.
      for(len_bit=0 ; len_bit<=(SP_BL_W-1) ; len_bit=len_bit+1)
      begin
        rsif_alen[len_bit] = rsi_fifo_do[start_bit+len_bit];
      end
      start_bit = start_bit + SP_BL_W;

    // addr
    // Any difference in data widths.
      for(addr_bit=0 ; addr_bit<=(ADDR_TRK_W-1) ; addr_bit=addr_bit+1)
      begin
        rsif_addr[addr_bit] = rsi_fifo_do[start_bit+addr_bit];
      end
      start_bit = start_bit + ADDR_TRK_W;

    // aburst
    // Any difference in data widths.
      for(burst_bit=0 ; 
          burst_bit<=(BT_W-1) ; 
          burst_bit=burst_bit+1
         )
      begin
        rsif_aburst[burst_bit] = rsi_fifo_do[start_bit+burst_bit];
      end
      start_bit = start_bit + BT_W;
//spyglass enable_block W415a
  end // rsi_fifo_do_PROC
  // spyglass enable_block SelfDeterminedExpr-ML
  
parameter [LOG2_MAX_SW:0]       CONST_LOG2_MAX_SW_1  = 1;
parameter [LOG2_MAX_SW:0]       CONST_LOG2_MAX_SW_2  = 2;
parameter [LOG2_MAX_SW:0]       CONST_LOG2_MAX_SW_4  = 4;
parameter [LOG2_MAX_SW:0]       CONST_LOG2_MAX_SW_8  = 8;
parameter [LOG2_MAX_SW:0]       CONST_LOG2_MAX_SW_16 = 16;
parameter [LOG2_MAX_SW:0]       CONST_LOG2_MAX_SW_32 = 32;
parameter [LOG2_MAX_SW:0]       CONST_LOG2_MAX_SW_64 = 64;
  // Calculate the number of bytes in rsif_asize_mp.
  always @(rsif_asize_mp)
  begin : rsif_asize_mp_bytes_PROC
    case (rsif_asize_mp)
      3'b000  : rsif_asize_mp_bytes = CONST_LOG2_MAX_SW_1; //  1;
      3'b001  : rsif_asize_mp_bytes = CONST_LOG2_MAX_SW_2; //  2;
      3'b010  : rsif_asize_mp_bytes = CONST_LOG2_MAX_SW_4; //  4;
      3'b011  : rsif_asize_mp_bytes = CONST_LOG2_MAX_SW_8; //  8;
      3'b100  : rsif_asize_mp_bytes = CONST_LOG2_MAX_SW_16; //  16;
      3'b101  : rsif_asize_mp_bytes = CONST_LOG2_MAX_SW_32; //  32;
      3'b110  : rsif_asize_mp_bytes = CONST_LOG2_MAX_SW_64; //  64;
      default : rsif_asize_mp_bytes = CONST_LOG2_MAX_SW_64; //  64;
    endcase
  end // rsif_asize_mp_bytes_PROC

  //    - Generate beats_per_pop,
  //      For all except the first beat from the mp, the number of sp
  //      write data beats we generate for every beat from the mp 
  //      (pop from from channel fifo) is mp size bytes/max sp size 
  //      bytes. To cut down on logic size we use shifting to perform 
  //      the division, taking that /X => >> log base 2(X) and that 
  //      there will always be a power of 2 relationship between the
  //      t/x sizes on MP and SP, and that MAX_SP_ASIZE is log base 2
  //      of SP_DW, we can right shift the number of bytes represented
  //      by rsif_asize_mp by MAX_SP_ASIZE to get our answer.
  //      Applies for downsizing only.
  //spyglass disable_block W486
  //SMD: Reports shift overflow operations
  //SJ : This is the intended implementation. This is not an issue functionally.
  //     Hence this can be waived.
  //spyglass disable_block W164a
  //SMD: LHS width is less than the RHS width
  //SJ : This is the intended implementation. This is not an issue functionally.
  //     Hence this can be waived.
  assign rsif_bpp = (rsif_asize_mp > `ubwc_x2x_X2X_MAX_SP_ASIZE)
                    ? (rsif_asize_mp_bytes >> `ubwc_x2x_X2X_MAX_SP_ASIZE)
                    : CONST_RSIF_FB_BPP_1;
  //spyglass enable_block W164a
  //spyglass enable_block W486

  //--------------------------------------------------------------------
  // Calculate beats per pop for the first beat of the t/x from the MP. 
  // Address alignment may mean there are less SP beats from the first 
  // MP beat than the (mp_size/sp_size) value that applies to other 
  // beats. The bits of the address from asize_mp down to log base 2 SP
  // byte width (strobe width) tell us how many SP width beats will be 
  // missed due to unalignment.
  //--------------------------------------------------------------------
  // Only include this code if MP DW is larger than SP DW to avoid 
  // compilation errors.
  integer addr_bit_rsif;
  always @(*)
  begin : rsif_fb_bpp_PROC
    reg [ADDR_TRK_W-1:0] addr;

    // The bits of the start address more significant than those that
    // apply to the SP data width up to the bit that apply to the MP 
    // asize tell us where in the MP data bus we should take the first 
    // SP data beat from. 
    // NOTE : The addr_aligned_PROC will already have masked out the 
    // bits that apply to the SP DW, so here we just mask out the bits
    // more significant than rsif_asize_mp.
    // For example, if MP_DW=128, SP_DW=32, rsif_asize_mp=3 (128 bits)
    // then we get 
    //              BIT NUMBERS
    // rsif_addr =  3  2  1  0
    //                   |<-->|   : Bits that apply to SP_DW
    //              |<------->|   : Bits that apply to rsif_asize_mp
    //              |<-->|        : Where to take first 32 bit sp beat 
    //                              from in the mp data bus.
    addr = {ADDR_TRK_W{1'b0}};
    for(addr_bit_rsif=0 ; 
        addr_bit_rsif<=(ADDR_TRK_W-1) ; 
        addr_bit_rsif=addr_bit_rsif+1
       ) 
    begin
    //spyglass disable_block W415a 
    //SMD: Signal may be multiply assigned (beside initialization) in the same scope.
    //SJ : addr signal is initialized to 0 inoder to avoid lathces for unused bits.
      if(addr_bit_rsif < rsif_asize_mp) addr[addr_bit_rsif] = rsif_addr[addr_bit_rsif];
    //spyglass enable_block W415a
    end
    
    // Subtracting this (above) from the beats per pop value gives us 
    // how many SP data beats we can extract from the MP data bus on the
    // first MP beat.
    if(rsif_asize_mp >  `ubwc_x2x_X2X_MAX_SP_ASIZE) begin
   // spyglass disable_block STARC-2.10.6.1
   // SMD: Possible loss of carry or borrow in addition or subtraction (Verilog)
   // SJ : This is not a functional issue, this is as per the requirement. Hence this can be waived.
   // spyglass disable_block W484
   // SMD: Possible loss of carry or borrow due to addition or subtraction.
   // SJ : This is not an issue because addr bitwidth will be <= rsif_bpp bit width. The implementation is as intended.
   // spyglass disable_block W164a
   // SMD: LHS width is less than the RHS width
   // SJ : This is not an issue because addr bitwidth will be <= rsif_bpp bit width. The implementation is as intended.
      rsif_fb_bpp = rsif_bpp - addr[ADDR_TRK_W-1:SP_LOG2_SW];
   // spyglass enable_block W164a
   // spyglass enable_block W484
   // spyglass enable_block STARC-2.10.6.1
    end else begin
      rsif_fb_bpp = CONST_RSIF_FB_BPP_1; // 1'b1;
    end

  end // rsif_fb_bpp_PROC


  //--------------------------------------------------------------------
  // Resize Information Slot Control Signals
  //
  // 1. rsis_newtx
  //    This signal is used to load details for a new slave port 
  //    transaction into one of the RSI slots. Has 1 bit for every RSI
  //    slot.
  //
  // 2. rsis_update
  //    This signals is used to instruct an RSI slot to update its 
  //    transaction information while the transaction is in progress.
  //    Has 1 bit for every RSI slot.
  //--------------------------------------------------------------------
  
  // 1. rsis_newtx
  //    When the channel ID matched with no active RSI slot ID and 
  //    matched with the ID at the head of the RSI fifo, we find
  //    the lowest numbered inactive RSI slot to load the resizing
  //    information for the t/x into from the RSI fifo.
  
  reg found;
  integer  slot_num_f;
  always @(bus_rsis_active_r or 
           rsif_match        or
           sp_wlast          or
           ready_i
          )
  begin : rsis_newtx_PROC

    rsis_newtx = {WID{1'b0}};
    found      = 1'b0;
//spyglass disable_block W415a 
//SMD: Signal may be multiply assigned (beside initialization) in the same scope.
//SJ : Here for signals rsis_newtx and found  which are initialized to 0 are asserted based on some conditional statement.
    for(slot_num_f=0 ; slot_num_f<=(WID-1) ; slot_num_f=slot_num_f+1) begin
    
      // Assert bit for this rsis slot if the slot is inactive
      // , if no previous id slots were inactive and if the 
      // incoming channel ID matched with the ID at the head of the
      // RSI fifo.
      if(~bus_rsis_active_r[slot_num_f] & (!found) & rsif_match
         // Do not load into RSI slot if the write data part of
         // the t/x has completed already.
         & (~(sp_wlast & ready_i))
        )
      begin
        rsis_newtx[slot_num_f] = 1'b1;
        // Use found variable to only match to least significant
        // numbered id slot.
        found = 1'b1;
      end

    end // for(slot_num_f=0

  end // rsis_newtx_PROC
//spyglass enable_block W415a

  // 2. rsis_update_sp/mp
  //    Signals to update RSI slots on acceptance of a beat from
  //    the MP or acceptance of a beat from the SP.
  assign rsis_update_mp = rsis_match & {WID{beat_acc_mp}};
  assign rsis_update_sp = rsis_match & {WID{beat_acc_sp}};


  //--------------------------------------------------------------------
  // Resize Information Slots (1 for each write interleaving depth).
  //
  // Each slot contains (depending on configuration) :
  // 1. active
  // 2. aid
  // 3. alen
  // 4. aburst
  // 5. asize_sp
  // 6. asize_mp
  // 7. addr (up to 6 lsb's)
  // 8. beats per pop
  //--------------------------------------------------------------------

  // 1. active
  //    Bit for each RSI slot, asserted when t/x in slot is active.

  integer slot_num_lb;
//  integer len_bit_lb;
//  reg [SP_BL_W-1:0] alen;
  always @(posedge aclk_i or negedge aresetn_i)
    begin : bus_rsis_active_PROC

      if(!aresetn_i) begin
        bus_rsis_active_r <= {WID{1'b0}};
      end else begin

        for(slot_num_lb=0 ; slot_num_lb<=(WID-1) ; slot_num_lb=slot_num_lb+1) begin

            // Extract alen for this slot.
//          for(len_bit_lb=0 ; len_bit_lb<=(SP_BL_W-1) ; len_bit_lb=len_bit_lb+1) 
//               begin
//                 alen[len_bit_lb] <= bus_rsis_alen_r[(slot_num_lb*SP_BL_W)+len_bit_lb];
//               end

          // If this is the active slot and a beat is accepted on the SP
          // and the beat is the last beat of the t/x ,then the t/x in the
          // slot is finished and the slot is inactive.
          if(rsis_update_sp[slot_num_lb] & sp_wlast) 
            begin
              bus_rsis_active_r[slot_num_lb] <= 1'b0;
        
              // New t/x for this slot, assert active bit. 
            end else if (rsis_newtx[slot_num_lb]) begin
              bus_rsis_active_r[slot_num_lb] <= 1'b1;
            end
        end // for(slot_num_lb=0
      end // if(!aresetn_i)
    end // bus_rsis_active_PROC

  // 2. aid
  //    ID for each re size info. slot.
  integer slot_num_rs;
  integer id_bit_rs;
  always @(posedge aclk_i or negedge aresetn_i)
    begin : bus_rsis_aid_r_PROC

      if(!aresetn_i) begin
        bus_rsis_aid_r <= {BUS_MP_ID_W{1'b0}};
      end else begin
        for(slot_num_rs=0 ; slot_num_rs<=(WID-1) ; slot_num_rs=slot_num_rs+1) begin

          // New t/x for this slot, load from RSI fifo.
          if(rsis_newtx[slot_num_rs]) begin
            for(id_bit_rs=0 ; id_bit_rs<=(MP_ID_W-1) ; id_bit_rs=id_bit_rs+1) begin
                   bus_rsis_aid_r[(slot_num_rs*MP_ID_W)+id_bit_rs]
                     <= rsif_aid[id_bit_rs];
            end
          end

        end // for(slot_num=0 

      end // if(!aresetn_i)

    end // bus_rsis_aid_r_PROC


  // 3. alen
  //    Length of resized t/x generated by resizer in the 
  //    SP AW block.
  integer slot_num_br;
  integer len_bit_br;
  always @(posedge aclk_i or negedge aresetn_i)
    begin : bus_rsis_alen_r_PROC

      if(!aresetn_i) begin
        bus_rsis_alen_r <= {BUS_SP_BL_W{1'b0}};
      end else begin
        for(slot_num_br=0 ; slot_num_br<=(WID-1) ; slot_num_br=slot_num_br+1) begin

          // New t/x for this slot, load from RSI fifo.
          if(rsis_newtx[slot_num_br]) begin
            for(len_bit_br=0 ; 
                len_bit_br<=(SP_BL_W-1) ; 
                len_bit_br=len_bit_br+1
                ) 
              begin
                // If beat is accepted in same cycle as being loaded
                // into an RSIS slot then use the update value which has
                // changed to take into account the accepted beat.
                bus_rsis_alen_r[(slot_num_br*SP_BL_W)+len_bit_br] 
                  <= beat_acc_sp
                     ? update_alen[len_bit_br]
                  : rsif_alen[len_bit_br];
              end
            end
//spyglass disable_block W415a 
//SMD: Signal may be multiply assigned (beside initialization) in the same scope.
//SJ : bus_rsis_alen_r is assigned in mulitple for loops but with mutually dependent conditions but as per the priority. 
          // Update remaining length for this t/x. Transfer generation 
          // logic decrements the length value as it issues beats for the 
          // transaction. A bit of rsis_update_sp is asserted whenever a 
          // beat for the t/x in the corresponding slot is accepted at the
          // SP , so we save the updated length into the currently active
          // slot.
          if(rsis_update_sp[slot_num_br]) begin
            for(len_bit_br=0 ; 
                len_bit_br<=(SP_BL_W-1) ; 
                len_bit_br=len_bit_br+1
                ) 
              begin
                bus_rsis_alen_r[(slot_num_br*SP_BL_W)+len_bit_br] 
                  <= update_alen[len_bit_br];
              end
            end

        end // for(slot_num_br=0 

      end // if(!aresetn_i)

    end // bus_rsis_alen_r_PROC
//spyglass enable_block W415a

  // 4. aburst
  //    Burst type of t/x generated by resizer in SP AW block.
  integer slot_num_ra;
  integer burst_bit_ra;
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_rsis_aburst_r_PROC

    if(!aresetn_i) begin
      bus_rsis_aburst_r <= {BUS_BT_W{1'b0}};
    end else begin
      for(slot_num_ra=0 ; slot_num_ra<=(WID-1) ; slot_num_ra=slot_num_ra+1) begin

        // New t/x for this slot, load from RSI fifo.
        if(rsis_newtx[slot_num_ra]) begin
          for(burst_bit_ra=0 ; burst_bit_ra<=(BT_W-1) ; burst_bit_ra=burst_bit_ra+1) begin
            bus_rsis_aburst_r[(slot_num_ra*BT_W)+burst_bit_ra] 
              <= rsif_aburst[burst_bit_ra];
          end
        end

      end // for(slot_num_ra=0 

    end // if(!aresetn_i)
  end // bus_rsis_aburst_r_PROC


  // 5. asize_sp
  //    Size of t/x generated by resizer in SP AW block.
  integer slot_num_as;
  integer size_bit_as;
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_rsis_asize_sp_r_PROC

    if(!aresetn_i) begin
      bus_rsis_asize_sp_r <= {BUS_BS_W{1'b0}};
    end else begin
      for(slot_num_as=0 ; slot_num_as<=(WID-1) ; slot_num_as=slot_num_as+1) begin

        // New t/x for this slot, load from RSI fifo.
        if(rsis_newtx[slot_num_as]) begin
          for(size_bit_as=0 ; size_bit_as<=(BS_W-1) ; size_bit_as=size_bit_as+1) begin
            bus_rsis_asize_sp_r[(slot_num_as*BS_W)+size_bit_as] 
              <= rsif_asize_sp[size_bit_as];
          end
        end

      end // for(slot_num_as=0 

    end // if(!aresetn_i)
  end // bus_rsis_asize_sp_r_PROC


  // 6. asize_mp
  //    Size of t/x received at X2X MP.
  integer slot_num_sm;
  integer size_bit_sm;
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_rsis_asize_mp_r_PROC

    if(!aresetn_i) begin
      bus_rsis_asize_mp_r <= {BUS_BS_W{1'b0}};
    end else begin
      for(slot_num_sm=0 ; slot_num_sm<=(WID-1) ; slot_num_sm=slot_num_sm+1) begin

        // New t/x for this slot, load from RSI fifo.
        if(rsis_newtx[slot_num_sm]) begin
          for(size_bit_sm=0 ; 
              size_bit_sm<=(BS_W-1) ; 
              size_bit_sm=size_bit_sm+1
             )
          begin
            bus_rsis_asize_mp_r[(slot_num_sm*BS_W)+size_bit_sm] 
              <= rsif_asize_mp[size_bit_sm];
          end
        end

      end // for(slot_num_sm=0 

    end // if(!aresetn_i)
  end // bus_rsis_asize_mp_r_PROC


  // 7. addr
  //    Lsb's of start address generated by resizer in SP AW block.
  integer slot_num_ad;
  integer addr_bit_ad;
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_rsis_addr_r_PROC

    if(!aresetn_i) begin
      bus_rsis_addr_r <= {BUS_ADDR_TRK_W{1'b0}};
    end else begin
      for(slot_num_ad=0 ; slot_num_ad<=(WID-1) ; slot_num_ad=slot_num_ad+1) begin

        // New t/x for this slot, load from RSI fifo.
        if(rsis_newtx[slot_num_ad]) begin
          for(addr_bit_ad=0 ; 
              addr_bit_ad<=(ADDR_TRK_W-1) ;
              addr_bit_ad=addr_bit_ad+1
             ) 
          begin
            // If beat is accepted in same cycle as being loaded
            // into an RSIS slot then use the update value which has
            // changed to take into account the accepted beat.
            bus_rsis_addr_r[(slot_num_ad*ADDR_TRK_W)+addr_bit_ad] 
              <= beat_acc_mp
                 ? update_addr_nxt[addr_bit_ad]
                 : rsif_addr[addr_bit_ad];
          end
        end
//spyglass disable_block W415a 
//SMD: Signal may be multiply assigned (beside initialization) in the same scope.
//SJ : bus_rsis_addr_r is assigned in mulitple for loops but with mutually dependent conditions but as per the priority.        
        // Transfer generation logic updates the address as it 
        // proccesses beats for the transaction. Here we save the
        // updated address bits in the resize info. slot that 
        // corresponds with the t/x currently in operation.
        // Updated every time a beat from the MP is accepted.
        if(rsis_update_mp[slot_num_ad]) begin
          for(addr_bit_ad=0 ; 
              addr_bit_ad<=(ADDR_TRK_W-1) ; 
              addr_bit_ad=addr_bit_ad+1
             ) 
          begin
            bus_rsis_addr_r[(slot_num_ad*ADDR_TRK_W)+addr_bit_ad] 
              <= update_addr_nxt[addr_bit_ad];
          end
        end

      end // for(slot_num_ad=0 
    end // if(!aresetn_i)
  end // bus_rsis_addr_r_PROC
//spyglass enable_block W415a
  //--------------------------------------------------------------------
  // Split payload from channel fifo up into constituent parts.
  //--------------------------------------------------------------------
  //spyglass disable_block W528
  //SMD: A signal or variable is set but never read.
  //SJ : mp_wlast will be read only when `ubwc_x2x_X2X_TX_ALTER==`ubwc_x2x_X2X_TX_NO_ALTER.
  assign {
    mp_id, 
    mp_wdata, 
    mp_wstrb, 
    mp_wlast}
  = payload_i;
  //spyglass enable_block W528

  //--------------------------------------------------------------------
  // Do endian mapping.
  // This block will optimise away endian mapping logic if no endian
  // transformation/mapping is required.
  //--------------------------------------------------------------------
  ubwc_x2x_DW_axi_x2x_et
   
  #(`ubwc_x2x_X2X_MP_DW,  // Data width.
    `ubwc_x2x_X2X_MP_SW,  // Strobe width.
    1            // 1 for write data channel, 0 for read data.
                 // Controls presence of strobe mapping logic.
  )
  U_sp_w_endian_transform (
    //inputs
    .data_in_i    (mp_wdata),
    .strobe_in_i  (mp_wstrb),
    .asize_i      (mux_asize_mp),
  
    //outputs
    .data_out_o   (et_mp_wdata),
    .strobe_out_o (et_mp_wstrb)
  );


  //--------------------------------------------------------------------
  // Find set of resizing information for the ID from the channel 
  // fifo.
  //--------------------------------------------------------------------
  always @(bus_rsis_aid_r    or
           bus_rsis_active_r or
           pop_empty_i       or
           mp_id 
          )
  begin : rsis_match_PROC

    integer rsis_num;
    integer id_bit;

  // local_match is used only in case WID <= 1.
    reg [WID-1:0] local_match;

    reg [MP_ID_W-1:0] rsis_id;

    local_match = {WID{1'b0}};

    for(rsis_num=0 ; rsis_num<=(WID-1) ; rsis_num=rsis_num+1) begin

      // Extract ID from this slot into temporary variable.
      for(id_bit=0 ; id_bit<=(MP_ID_W-1) ; id_bit=id_bit+1) begin
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
        rsis_id[id_bit] = bus_rsis_aid_r[(MP_ID_W*rsis_num)+id_bit];
// spyglass enable_block SelfDeterminedExpr-ML
      end
     
      // If master port ID matches with slot ID and the slot is
      // active assert bit for this slot.
      // spyglass disable_block W528
      // SMD: A signal or variable is set but never read.
      // SJ : local_match is used only in case WID <= 1.
      if((rsis_id == mp_id) & bus_rsis_active_r[rsis_num]) begin
        local_match[rsis_num] = 1'b1;
      end
      // spyglass enable_block W528
    end

    // This is the intended implementation. This is not an issue as the qualifier ensures the correct bitwidth.
    // For final value, if channel fifo is empty then do not assert
    // any match bits.
    // spyglass disable_block W164b
    // SMD: LHS width is greater than RHS width.
    // SJ : This is the intended implementation. This is not an issue as the qualifier ensures the correct bitwidth.
    rsis_match = (WID > 1 ) ? ({WID{~pop_empty_i}} & local_match)

                            // If WID == 1 then we don't care about the
                            // ID matching as the t/x's always have
                            // to be completed in address order.
                            // So just match if the only RSIS slot is
                            // active.
                            : (~pop_empty_i & bus_rsis_active_r[0]);
    // spyglass enable_block W164b

  end // rsis_match_PROC


  // If incoming channel ID has not matched with any RSI slot ID's,
  // and neither the channel fifo or RIS fifo are empty then we
  // can say the incoming ID matches with the fifo at the head
  // of the RSIF fifo. Don't need to worry about ID matching,
  // as the data must be in order with the t/x.
  generate if (WID>1)
    assign rsif_match = (~(|rsis_match) & (~(pop_empty_i | rsi_fifo_empty)));
  else 
    assign rsif_match = (~(rsis_match) & (~(pop_empty_i | rsi_fifo_empty)));
  endgenerate
                      


  // Assert if incoming channel ID has matched with any active 
  // resizing information slots (RSIS) or matched with the ID
  // at the head of the RSI fifo.
  generate if (WID>1)
    assign match_active_id = (|rsis_match) | rsif_match;
  else
    assign match_active_id = (rsis_match) | rsif_match;
  endgenerate


  //--------------------------------------------------------------------
  // RESIZE INFO. MUXES
  //
  // Note resizing information can come from resizing info. slots
  // (RSIS) or the resizing info. fifo (RSIF). RSIF signals are 
  // appended into the mux inputs at the MSB positions.
  //--------------------------------------------------------------------
  
  // alen mux.
  ubwc_x2x_DW_axi_x2x_busmux_ohsel
  
  #((WID+1), // Number of buses to mux between.
    SP_BL_W  // Width of each bus input to the mux.
  ) 
  U_rsis_alen_busmux (
    .sel   ({rsif_match, rsis_match}),
    .din   ({rsif_alen, bus_rsis_alen_r}),
    .dout  (mux_alen)
  );
  

  // aburst mux.
  ubwc_x2x_DW_axi_x2x_busmux_ohsel
  
  #((WID+1), // Number of buses to mux between.
    BT_W  // Width of each bus input to the mux.
  ) 
  U_rsis_aburst_busmux (
    .sel   ({rsif_match, rsis_match}),
    .din   ({rsif_aburst, bus_rsis_aburst_r}),
    .dout  (mux_aburst)
  );
  

  // asize_sp mux.
  ubwc_x2x_DW_axi_x2x_busmux_ohsel
  
  #((WID+1), // Number of buses to mux between.
    BS_W     // Width of each bus input to the mux.
  ) 
  U_rsis_asize_sp_busmux (
    .sel   ({rsif_match, rsis_match}),
    .din   ({rsif_asize_sp, bus_rsis_asize_sp_r}),
    .dout  (mux_asize_sp)
  );
  

  // asize_mp mux.
  ubwc_x2x_DW_axi_x2x_busmux_ohsel
  
  #((WID+1), // Number of buses to mux between.
    BS_W     // Width of each bus input to the mux.
   ) 
  U_rsis_asize_mp_busmux (
    .sel   ({rsif_match, rsis_match}),
    .din   ({rsif_asize_mp, bus_rsis_asize_mp_r}),
    .dout  (mux_asize_mp)
  );


  // addr mux.
  ubwc_x2x_DW_axi_x2x_busmux_ohsel
  
  #((WID+1),    // Number of buses to mux between.
    ADDR_TRK_W  // Width of each bus input to the mux.
   ) 
  U_rsis_addr_busmux (
    .sel   ({rsif_match, rsis_match}),
    .din   ({rsif_addr, bus_rsis_addr_r}),
    .dout  (mux_addr)
  );


  //--------------------------------------------------------------------
  // Signals derived from mux_* signals.
  //--------------------------------------------------------------------


  // Calculate the number of bytes in mux_asize_mp.    
  always @(mux_asize_sp)
  begin : mux_asize_sp_bytes_PROC
    case (mux_asize_sp)
      3'b000  : mux_asize_sp_bytes = CONST_LOG2_MAX_SW_1; // 1;
      3'b001  : mux_asize_sp_bytes = CONST_LOG2_MAX_SW_2; // 2;
      3'b010  : mux_asize_sp_bytes = CONST_LOG2_MAX_SW_4; // 4;
      3'b011  : mux_asize_sp_bytes = CONST_LOG2_MAX_SW_8; // 8;
      3'b100  : mux_asize_sp_bytes = CONST_LOG2_MAX_SW_16; // 16;
      3'b101  : mux_asize_sp_bytes = CONST_LOG2_MAX_SW_32; // 32;
      // If MP_DW > SP_DW then we can not get SP_DW = 512 and
      // mux_asize_sp_bytes = 64 bytes.
      //VCS coverage off
      3'b110  : mux_asize_sp_bytes = CONST_LOG2_MAX_SW_64; // 64;
      default : mux_asize_sp_bytes = CONST_LOG2_MAX_SW_64; // 64;
      //VCS coverage on
    endcase
  end // mux_asize_sp_bytes_PROC


  // Calculate the number of bytes in mux_asize_mp.    
  always @(mux_asize_mp)
  begin : mux_asize_mp_bytes_PROC
    case (mux_asize_mp)
      3'b000  : mux_asize_mp_bytes = CONST_LOG2_MAX_SW_1; // 1;
      3'b001  : mux_asize_mp_bytes = CONST_LOG2_MAX_SW_2; // 2;
      3'b010  : mux_asize_mp_bytes = CONST_LOG2_MAX_SW_4; // 4;
      3'b011  : mux_asize_mp_bytes = CONST_LOG2_MAX_SW_8; // 8;
      3'b100  : mux_asize_mp_bytes = CONST_LOG2_MAX_SW_16; // 16;
      3'b101  : mux_asize_mp_bytes = CONST_LOG2_MAX_SW_32; // 32;
      3'b110  : mux_asize_mp_bytes = CONST_LOG2_MAX_SW_64; // 64;
      default : mux_asize_mp_bytes = CONST_LOG2_MAX_SW_64; // 64;
    endcase
  end // mux_asize_mp_bytes_PROC

  // Beats per pop value derived from RSIS mux_* values.
  // Used for FIXED bursts where we have to return to the first beat,
  // beats per pop value after every MP beat.
  // Only used for configs with MP_DW > SP_DW.

  //spyglass disable_block W486
  //SMD: Reports shift overflow operations
  //SJ : This is the intended implementation. This is not an issue functionally.
  //     Hence this can be waived.
  //spyglass disable_block W164a
  //SMD: LHS width is less than the RHS width
  //SJ : This is the intended implementation. This is not an issue functionally.
  //    Hence this can be waived.
  assign rsis_bpp = (mux_asize_mp >  `ubwc_x2x_X2X_MAX_SP_ASIZE)
                    ? (mux_asize_mp_bytes >>  `ubwc_x2x_X2X_MAX_SP_ASIZE)
                    : CONST_RSIF_FB_BPP_1;
  //spyglass enable_block W164a
  //spyglass enable_block W486


  // Only include this code if MP DW is larger than SP DW to avoid 
  // compilation errors.
 
  // First beat, beats per pop value derived from RSIS mux_* values.
  // See generation of rsis_fb_bpp to see more info.
  integer addr_bit_rsis;
  always @(*)
  begin : rsis_fb_bpp_PROC
    reg [ADDR_TRK_W-1:0] addr;

    addr = {ADDR_TRK_W{1'b0}};
    for(addr_bit_rsis=0 ; 
        addr_bit_rsis<=(ADDR_TRK_W-1) ; 
        addr_bit_rsis=addr_bit_rsis+1
       ) 
    begin
    //spyglass disable_block W415a 
    //SMD: Signal may be multiply assigned (beside initialization) in the same scope.
    //SJ : addr signal is initialized to 0 inoder to avoid lathces for unused bits.
      if(addr_bit_rsis < mux_asize_mp) addr[addr_bit_rsis] = mux_addr[addr_bit_rsis];
    //spyglass enable_block W415a
    end
    
    if(mux_asize_mp >  `ubwc_x2x_X2X_MAX_SP_ASIZE) begin
    // spyglass disable_block STARC-2.10.6.1
    // SMD: Possible loss of carry or borrow in addition or subtraction (Verilog)
    // SJ : This is not a functional issue, this is as per the requirement. Hence this can be waived.
    // spyglass disable_block W484
    // SMD: Possible loss of carry or borrow due to addition or subtraction.
    // SJ : This is not an issue because addr bitwidth will be <= rsis_bpp bit width. The implementation is as intended.
    // spyglass disable_block W164a
    // SMD: LHS width is less than the RHS width
    // SJ : This is not an issue because addr bitwidth will be <= rsis_bpp bit width. The implementation is as intended.
      rsis_fb_bpp = rsis_bpp - addr[ADDR_TRK_W-1:SP_LOG2_SW];
    //spyglass enable_block W164a
    // spyglass enable_block W484
    // spyglass enable_block STARC-2.10.6.1
    end else begin
      rsis_fb_bpp = CONST_RSIF_FB_BPP_1;
    end
  end // rsis_fb_bpp_PROC
  
  // Gen current beats per pop (BPP).
  assign mux_bpp = rsif_match 

                   // For the first beat of an SP t/x (first beat will
                   // match with RSI fifo) always select first beat
                   // beats per pop value derived from RSIF values.
                   ? rsif_fb_bpp 
                
                   : (mux_aburst == `ubwc_x2x_X2X_BT_FIXED)
                     // If this is not the first beat of an SP 
                     // transaction then we select the first beat bpp
                     // value for FIXED t/x types as the same byte 
                     // lanes will be active for each beat.
                     ?  rsis_fb_bpp
                
                     // For a non FIXED t/x type take the bpp value 
                     // derived from the RSIS mux_* values.
                     :  rsis_bpp;

  //--------------------------------------------------------------------
  // BEAT GENERATION LOGIC
  //--------------------------------------------------------------------
  
  // Assert whenever a beat from channel fifo has been accepted.
  assign beat_acc_mp = ~pop_req_n_o;

  // Assert whenever a beat is accepted from SP.    
  assign beat_acc_sp = valid_o & ready_i;


  //--------------------------------------------------------------------
  // TRACK ADDRESS - During MP beat.
  //--------------------------------------------------------------------
  // Increment address by size_sp_bytes to keep track of active byte
  // lanes for each beat. Stored in the currently active RSI slot
  // whenever rsis_update is asserted.
  // Upper bits of mux_addr will tell us where to take next chunk
  // of sp_wdata from, in the mp_wdata bus.
  // While using multiple SP beats to send a single MP beat the address
  // will come from update_addr_r, and when that beat is finished we
  // will reload from the active RSIS address. The RSIS address is 
  // updated after every completed MP beat.
  always @(*)
  begin : update_addr_nxt_PROC
    reg [ADDR_TRK_W-1:0] addr;
    reg                  beat_acc;
    reg [LOG2_MAX_SW:0]  asize_bytes;

    update_addr_nxt = {ADDR_TRK_W{1'b0}};

    // Select mux_addr from RSIF or RSIS when we are waiting for
    // another MP beat to operate on.
    // NOTE : update_bpp_r is only relevant if X2X_MP_DW > X2X_SP_DW.
    if( ((update_bpp_r == {BUS_BEATS_PER_POP_W{1'b0}}) || (MP_DW <= SP_DW)) 
        & match_active_id
      )
    begin
      addr = mux_addr;
    end else begin
      addr = update_addr_r;
    end

    // beat_acc controls when we update update_addr_r. 
    // For configs where MP_DW > SP_DW, we can issue multiple SP beats
    // for every MP beat, so we update on every accepted SP beat.
    // For configs where MP_DW < SP_DW and upsizing is enabled, we could
    // accept multiple MP beats before we issue a single SP beat, so
    // we update on every accepted MP beat.
    // In other cases beat_acc_mp and beat_acc_sp are identical so we 
    // default to beat_acc_sp.
    beat_acc = beat_acc_sp;

    // Select which asize bytes value to add to update_addr_r, 
    // depending on whether we are updating from MP beats or SP beats.
    // See selecting of beat_acc.
    asize_bytes = mux_asize_sp_bytes;

    case({beat_acc, mux_aburst})
    
      {1'b1, `ubwc_x2x_X2X_BT_FIXED} : begin

        if(mux_asize_mp >  `ubwc_x2x_X2X_MAX_SP_ASIZE) begin
          // If we get a FIXED burst from the MP with a SIZE greater
          // than the max SP SIZE. We have to use multiple SP beats to
          // send the single SP beat but we have to be careful not to
          // keep incrementing the address. When we have sent the
          // MP SIZE we have to wrap back to the start of the FIXED 
          // address for the next MP beat.
          if(update_bpp_nxt != {BUS_BEATS_PER_POP_W{1'b0}}) begin
            // Haven't sent the full MP SIZE yet so keep incrementing.
  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ : This is not a functional issue, this is as per the requirement.
  //      Hence this can be waived.
  // spyglass disable_block TA_09
  // SMD: Reports cause of uncontrollability or unobservability and estimates the number of nets whose controllability / observability is impacted. 
  // SJ : Tool will issue unobservability warning only for those bits which are "not read" or "floating". Since we are not reading those bits we don't need observability. Hence waiving this warning.
            update_addr_nxt = {{(LOG2_MAX_SW+1 - ADDR_TRK_W){1'b0}} , addr} + asize_bytes;
  // spyglass enable_block TA_09
  // spyglass enable_block W164a
          end else begin
            // We have sent the full MP size so wrap back to the
            // start address.
            update_addr_nxt = mux_addr;
          end
        end else begin
          // Turn off coverage here for non upsizing configs.
          //VCS coverage off
          // MP ASIZE is <= MAX_SP_ASIZE.
          if(upsized_tx) begin
            // For an upsized fixed t/x we increment the address until
            // the pack register is full, then we reset to the start
            // address for the next beat.
  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ : This is not a functional issue, this is as per the requirement.
  //      Hence this can be waived.
  // spyglass disable_block TA_09
  // SMD: Reports cause of uncontrollability or unobservability and estimates the number of nets whose controllability / observability is impacted. 
  // SJ : Tool will issue unobservability warning only for those bits which are "not read" or "floating". Since we are not reading those bits we don't need observability. Hence waiving this warning.
            update_addr_nxt = pack_reg_nxt_full ? {ADDR_TRK_W{1'b0}} : {{(LOG2_MAX_SW+1 - ADDR_TRK_W){1'b0}} , addr} + asize_bytes;
  // spyglass enable_block TA_09
  // spyglass enable_block W164a
              // Because an upsized fixed t/x has to meet the upsizing
              // rules, we know we can set the start address as
              // all 0's. This logic has to take responsibility for 
              // setting bus_rsis_addr back to the start address for the 
              // burst as the value in bus_rsis_addr will have been
              // incremented by 1 beat as we accepted the beat from
              // the master port. Unalignment w.r.t. asize_mp is 
              // transparent to the write data channel anyway so we
              // can use all 0's.
          end else begin
          //VCS coverage on
            // Non upsized fixed t/x, address stays static throughout
            // the t/x.
            update_addr_nxt = addr;
          end
        end 

      end // `ubwc_x2x_X2X_BT_FIXED

      {1'b1, `ubwc_x2x_X2X_BT_INCR} : begin
  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ : This is not a functional issue, this is as per the requirement.
  //      Hence this can be waived.
  // spyglass disable_block TA_09
  // SMD: Reports cause of uncontrollability or unobservability and estimates the number of nets whose controllability / observability is impacted. 
  // SJ : Tool will issue unobservability warning only for those bits which are "not read" or "floating". Since we are not reading those bits we don't need observability. Hence waiving this warning.
            update_addr_nxt = {{(LOG2_MAX_SW+1 - ADDR_TRK_W){1'b0}} , addr} + asize_bytes;
  // spyglass enable_block TA_09
  // spyglass enable_block W164a
      end // `ubwc_x2x_X2X_BT_INCR

      default : begin
        // No beat accepted, do not update address.
        update_addr_nxt = addr;
      end

    endcase

  end // update_addr_nxt_PROC

  
  // Register process, loaded from update_addr_nxt.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : update_addr_r_PROC
    if(!aresetn_i) begin
      update_addr_r <= {ADDR_TRK_W{1'b0}};
    end else begin
      update_addr_r <= update_addr_nxt;
    end
  end // update_addr_r_PROC


  // Address of the current beat. Select from mux_addr (from the RSI
  // slots or RSI fifo) or the update_addr_r register.
  // Update_addr_r contains the address of the current beat as we work
  // through a beat from the MP (could be multiple SP beats) and we
  // select mux_addr for the first cycle of a new beat from the MP.
  assign current_addr = (update_bpp_r == {BUS_BEATS_PER_POP_W{1'b0}}) ? mux_addr : update_addr_r;


  // Update length, subtract 1. Loaded into the currently active RSI
  // slot whenever rsis_update is asserted. 
  // Since alen=0 implies a single beat this value will wrap around
  // after the last beat, but this should not be a problem as we
  // have a seperate active bit for each RSI slot to tell us when
  // there are beats left for a t/x in the slot.
  assign update_alen = (mux_alen - 1);


  //--------------------------------------------------------------------
  // Track beats per pop.
  //--------------------------------------------------------------------
  // Because of downsizing we could have to issue multiple beats
  // for a single pop from the write data channel fifo.
  // when it is 0 we will pop the write data channel fifo if it
  // is not empty.
  // Also, when this value is 0 we will load update_bpp_r from
  // mux_bpp (from the RSI slots).
  //--------------------------------------------------------------------
  always @(*) 
  begin : update_bpp_nxt_PROC
    update_bpp_nxt = {BUS_BEATS_PER_POP_W{1'b0}};

    //spyglass disable_block W164b
    //SMD: Identifies assignments in which the LHS width is greater than the RHS width
    //SJ : This is not a functional issue, this is as per the requirement.
    //      Hence this can be waived.

    // Remove logic if SP DW is larger.

    // This is a next state process for update_bpp_r.
    // When update_bpp_r is 0 and an ID from the channel fifo has 
    // matched with an active ID, select mux_bpp 
    // Want to qualify non zero bpp values with the id match.
    // A beat could be accepted in the same cycle so we could need
    // to decrement immediately.
    if( (update_bpp_r == {BUS_BEATS_PER_POP_W{1'b0}}) 
        && match_active_id
      ) begin
    update_bpp_nxt = beat_acc_sp
                     ? (mux_bpp - 1)
                     : mux_bpp;
    end else begin
      // For each beat accepted decrement this value.
      update_bpp_nxt = beat_acc_sp 
                       ? (update_bpp_r - 1)
                       : update_bpp_r;
    end
    //spyglass enable_block W164b

  end // update_bpp_nxt_PROC


  // Register process, loaded from update_bpp_nxt.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : update_bpp_r_PROC
    if(!aresetn_i) begin
      update_bpp_r <= {BUS_BEATS_PER_POP_W{1'b0}};
    end else begin
      update_bpp_r <= update_bpp_nxt;
    end
  end // update_bpp_r_PROC


  //--------------------------------------------------------------------
  // Generate pop to write data channel fifo.
  //--------------------------------------------------------------------
  always @(*)
  begin : pop_req_n_o_PROC
    pop_req_n_o = 1'b1;

    // Only pop if the fifo is not empty.
    if(~pop_empty_i) begin

      // For downsized configs, beats per pop next must be 0 when
      // the SP beat is accepted before we can pop the channel fifo.
      // Because we can have multiple SP beats from a single MP beat.
        pop_req_n_o 
          = ~(  beat_acc_sp 
              & (update_bpp_nxt == {BUS_BEATS_PER_POP_W{1'b0}})
             );


    end // if(~pop_empty_i

  end // pop_req_n_o_PROC


  // not required.
  assign upsized_tx = 1'b0;
  assign pack_reg_nxt_full = 1'b0;



  //--------------------------------------------------------------------
  // DATA AND STROBE MUXES.
  //--------------------------------------------------------------------
  
  
  // Assign data select signal.
  // For each beat of a t/x we add the size of the beat to the start
  // address and from the sizes of the MP and SP data busses we
  // can figure out how many of the upper bits of this tracking address
  // we need to select where in the mp data bus sp data should come
  // from or vice versa. 
  assign sp_data_sel = current_addr[(ADDR_TRK_W-1):SP_LOG2_SW];


  // Data Mux.
  ubwc_x2x_DW_axi_x2x_busmux
  
  #(`ubwc_x2x_X2X_RS_RATIO, // Number of buses to mux between.
    SP_DW,         // Width of each bus input to the mux.
    DATA_SEL_W     // Width of select line.
  ) 
  U_mp_dw_larger_data_mux (
    .sel   (sp_data_sel),
    .din   (et_mp_wdata),
    .dout  (sp_wdata)
  );
  
  // Strobe Mux.
  ubwc_x2x_DW_axi_x2x_busmux
  
  #(`ubwc_x2x_X2X_RS_RATIO, // Number of buses to mux between.
    SP_SW,         // Width of each bus input to the mux.
    DATA_SEL_W     // Width of select line.
  ) 
  U_mp_dw_larger_strobe_mux (
    .sel   (sp_data_sel),
    .din   (et_mp_wstrb),
    .dout  (sp_wstrb)
  );

  





  //--------------------------------------------------------------------
  // OUTPUT STAGE
  //
  // Drive remaining channel output signals.
  //--------------------------------------------------------------------

  // Decode valid out.
  generate if(   (`ubwc_x2x_X2X_TX_ALTER == `ubwc_x2x_X2X_TX_NO_ALTER) && (`ubwc_x2x_X2X_HAS_ET == 0))
  always @(*)
  begin : valid_o1_PROC

    reg us_valid;
    // spyglass disable_block W528
    // SMD: A signal or variable is set but never read.
    // SJ : us_valid is read only when `ubwc_x2x_X2X_TX_ALTER != `ubwc_x2x_X2X_TX_NO_ALTER or `ubwc_x2x_X2X_HAS_ET == 1.
    valid_o = 1'b0;
    us_valid = 1'b0;
    // spyglass enable_block W528
    // If no t/x altering or endianness mapping is taking place we can
    // drive valid_o directly from the channel fifos pop empty signal.
    //spyglass disable_block W415a
    //SMD: Signal may be multiply assigned (beside initialization) in the same scope.
    //SJ : valid_o is initialized to 0 before assignment to avoid latches. 
      valid_o = ~pop_empty_i;
    
  end 

  else // generate

  always @(*)
  begin : valid_o_PROC

    reg us_valid;

    valid_o = 1'b0;
    us_valid = 1'b0;

    // If the beat is from an upsized t/x, the data beats have to be
    // packed before we issue a beat from the X2X SP. So only assert valid
    // if the next mp beat will fill the pack reg and we have an ID match.
    if(upsized_tx) begin

      //VCS coverage off

      // Assert when we have valid data for an upsized t/x.
      us_valid = pack_reg_nxt_full & match_active_id;

      // Here we control valid for an upsized transaction to take account of the necessary
      // synchronisation with the write address channel for configs with X2X_WID > 1.

      // blocking assignments mean us_valid is assigned before it is read
      // If this is the first beat of data for the upsized write, then do no assert until the write address
      // channel has signalled it can forward the upsized write t/x by deasserting us_xact_issue_off_i.
      // Otherwise assert valid as normal.
      //spyglass disable_block UndrivenInTerm-ML
      //SMD: Detects undriven but loaded input terminal of an instance
      //SJ : The bus_us_tx_started_r is generated only when Upsizing of the transfer is 
      //     is necessary. The RTL code in which is generated is guarded by ifdef (unconfigured code),
      //     but here it is guarded with Verilog generate if statement. Hence this can be waived.
      //spyglass disable_block W123
      //SMD: Identifies the signals and variables that are read but not set
      //SJ : The bus_us_tx_started_r is generated only when Upsizing of the transfer is 
      //     is necessary. The RTL code in which is generated is guarded by ifdef (unconfigured code),
      //     but here it is guarded with Verilog generate if statement. Hence this can be waived.
      //spyglass disable_block UndrivenNet-ML
      //SMD: Detected undriven but loaded net in the design 
      //SJ : The bus_us_tx_started_r is generated only when Upsizing of the transfer is 
      //     is necessary. The RTL code in which is generated is guarded by ifdef (unconfigured code),
      //     but here it is guarded with Verilog generate if statement. Hence this can be waived.
      valid_o = (WID>1) ? ( ~|(rsis_match & bus_us_tx_started_r) ? (~us_xact_issue_off_i & us_valid) : us_valid) : us_valid ;
      //spyglass enable_block UndrivenNet-ML
      //spyglass enable_block W123
      //spyglass enable_block UndrivenInTerm-ML
      
      //VCS coverage on

    // This branch applies to all other configs where the beat is not
    // from an upsized t/x so can be issued immediately if there is an ID match.
    end else begin
      valid_o = match_active_id;
    end
  end // valid_o_PROC
  //spyglass enable_block W415a 
  endgenerate


  // Drive sp_wlast.
  // If the X2X will not change the length of t/x's that pass through 
  // it then we can forward wlast directly from the channel fifo. 
  // Otherwise we will decode last from our internal length value 
  // being == 0.
  // Justifying with valid_o so it is not asserted by default.
  //
  // Turn coverage off for whole line. TX_ALTER==NO_ALTER will
  // never be hit for interesting configs and the other line
  // is safe from a coverage point of view.
  
  //VCS coverage off
  generate if (`ubwc_x2x_X2X_TX_ALTER==`ubwc_x2x_X2X_TX_NO_ALTER)
    assign sp_wlast = (valid_o ? mp_wlast : 1'b0);
  else
    assign sp_wlast = (valid_o ? (mux_alen == {SP_BL_W{1'b0}}) : 1'b0);
  endgenerate
   //VCS coverage on
  

  // Build up payload out bus.
  // Drive outputs to 'b0 if valid is not being asserted to reduce 
  // unecessary switching on output ports.
  assign payload_o = 
    valid_o ? { 
               mp_id,
               sp_wdata,
               sp_wstrb,
               sp_wlast
              }
            : {SP_PYLD_W{1'b0}};


  // Connect RSI fifo full output.
  assign rs_fifo_full_o = rsi_fifo_full;


endmodule
