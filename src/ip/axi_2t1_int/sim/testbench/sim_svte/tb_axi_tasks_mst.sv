//------------------------------------------------------------------------
//--
// ------------------------------------------------------------------------------
// 
// Copyright 2001 - 2020 Synopsys, INC.
// 
// This Synopsys IP and all associated documentation are proprietary to
// Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
// written license agreement with Synopsys, Inc. All other use, reproduction,
// modification, or distribution of the Synopsys IP or the associated
// documentation is strictly prohibited.
// 
// Component Name   : DW_axi
// Component Version: 4.04a
// Release Type     : GA
// ------------------------------------------------------------------------------

// 
// Release version :  4.04a
// File Version     :        $Revision: #3 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/sim/testbench/sim_svte/tb_axi_tasks_mst.sv#3 $ 
//------------------------------------------------------------------------

`ifndef TB_AXI_TASKS_MST_V

`define TB_AXI_TASKS_MST_V

/**
  * This task is used to generated random burst length.
  * 
  * When in AXI3 mode, burstlength is restricted to be <= 16.
  *
  * When in AXI4/ACE_LITE mode, no restriction exists.  However there is a 
  * weightage which kicks in which makes 80% of time burstlength <=16.
  * For remaining 20% of time it will be > 16.
  *
  * This task always output burst_length.
  */
task automatic axi_weighted_burst_length;
output [`AXI_BLW-1:0] burst_length;
integer rand_int;
begin
  rand_int =  $random(seed) % 100;

`ifdef AXI_HAS_AXI3

  burst_length =  ({$random(seed)} % 16) + 1;
`endif

`ifdef AXI_HAS_AXI4

  if(rand_int < 80 )
    burst_length =  ({$random(seed)} % 16) + 1;
  else
    burst_length  = ({$random(seed)} % ({`AXI_BLW{1'b1}} + 1)) + 1;
`endif

  if (burst_length==0) burst_length = burst_length+1;

end
endtask

/**
 * Generates a random AXI Transaction
 * ----------------------------------
 * This task accepts below as its input:
 *  @param master_id     : Selects which Master will issue the transaction.
 *  @param slave_id      : Selects which Slave is targeted by the Master.
 *  @param region_id     : Selects which Region is targeted by the Master.
 *  @param write         : Read - 0, Write - 1, Randomly select - 2.
 *  @param lock          : Unlock - 0, Lock - 1, Randomly select - 2.
 *  @param secure        : Secure - 0, Nonsecure -1, Randomly select - 2.
 *  @param burst         : MultiBurst - 0, SingleBurst - 1, Random - 2, INCR16 - 3.
 *  @param slv_addr_dcdr : Used when doing unaglined or default slave testing.
 *                         Based on this address generation happens.
 *
 * This task returns transaction handle as its output:
 *  @param xfer_handle   : Transaction handle
 *
 * All other attributes of the transaction (Burst Length, Cache Type etc.) are 
 * generated randomly within the constraints of the AXI protocol.
 */
task automatic axi_master_rand_xact;
  input  [31:0]        master_id;
  input  [31:0]        slave_id;
  input  [31:0]        region_id;
  input  [31:0]	       write;
  input  [31:0]        lock;
  input  [31:0]        secure;
  input  [31:0]        burst;
  input  [31:0]        slv_addr_dcdr; 
  output integer       xfer_handle;

  //Internal variables to randomly generate different transaction attributes
  reg [`SVT_AXI_MAX_ADDR_WIDTH-1:0]     slv_addr;
  reg [31:0]                            slv_addr1;
  reg [31:0]                            slv_addr2;
  reg [`SVT_AXI_MAX_ADDR_WIDTH-1:0]     addr_offset;
  reg [`SVT_AXI_MAX_ADDR_WIDTH-1:0]     offset_rand_max;
  reg [31:0]		                xact_type;
  reg [31:0]       	                total_bytes;
  reg [31:0]      	                secure_sel;
  reg [1:0]                             lock_type;
  reg [2:0]                             prot_type;
  reg [3:0]                             cache_type;
  reg [`AXI_DW-1:0]                     data;
  reg [(`AXI_DW/8)-1:0]                 wstrb;
  reg [127:0]                           wstrb_mask;
  reg [1:0]                             burst_type;
  reg [2:0]                             burst_size;
  reg [`AXI_SIDW-1:0]                   aid;
  reg [`AXI_BLW-1:0]                    burst_length;
  reg [`AXI_AW-1:0]                     boundary;
  reg [`SVT_AXI_QOS_WIDTH-1:0]          axi_qos_val;

`ifdef AXI_HAS_AXI4

  reg [`SVT_AXI_MAX_ADDR_USER_WIDTH-1:0]  addr_user;
  reg [`SVT_AXI_MAX_DATA_USER_WIDTH-1:0]  data_user;
`endif

  /** Variables to generate and set random delays */
  integer addr_valid_delay;
  integer bready_delay;
  integer rready_delay;
  integer wvalid_delay;

  //Temporary variables
  reg                                   is_valid;
  integer                               temp_integer, random_master;
  integer                               dwsize, i, k, num_bytes;
  integer                               r, brk, decode_addr;

  reg [1:0]                             data_before_addr;
  reg                                   data_with_addr;

  //`ifdef AXI_HAS_ACELITE
  //  reg [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]  domain_type;
  //  reg [`SVT_AXI_ACE_BARRIER_WIDTH-1:0] barrier_type;
  //  reg [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0] coherent_xact_type;
  //`endif

begin
  if (test_debug) $display("@%0d [TB_DEBUG] {%m} : Randomize master transaction started\n",$time);

  //VIP doesn't support ACELITE
  //`ifdef AXI_HAS_ACELITE
  //   xact_type =  `SVT_AXI_TRANSACTION_TYPE_COHERENT;
  //`else
  if(write == `SIM_RW_RND)
    xact_type = {$random(seed)} % 2;
  else
    xact_type = write;
  //`endif
  
  /** 
    * Below logic is written for different lock values
    * SIM_LOCK_RND      : Pick anything value NORMAL, LOCK, EXCLUSIVE
    *                     If EXCLUSIVE, make sure it is READ, since EX-WR can't start firstly.
    * SIM_EXCLUSIVE     : If transaction is WRITE, then make sure it is READ.
    * 
    * If nothing is matched, then retain the input as it is.
    */ 
  if(lock == `SIM_LOCK_RND) begin
    lock_type = {$random(seed)} % 3;
    // Prevent an exclusive write from being randomly generated
    while(xact_type == `SIM_WRITE && lock_type == `SIM_EXCLUSIVE) begin
      lock_type = {$random(seed)} % 3;
    end
  end else if(lock == `SIM_EXCLUSIVE && xact_type == `SIM_WRITE ) begin
    lock_type = 0;
  end else begin
    lock_type = lock;
  end

   
  if(secure == `SIM_SECURE_RND)
    secure_sel = {$random(seed)} % 2;
  else
    secure_sel = secure;
   
  addr_offset = {`SVT_AXI_MAX_ADDR_WIDTH{1'b0}};
  slv_addr = {`SVT_AXI_MAX_ADDR_WIDTH{1'b0}};
 
  /** Randomise the starting address offset for targeted Slave Region */
  offset_rand_max = $random(seed);
  for(i = 1; i <= `AXI_AW/32; i = i + 1) begin
    temp_integer = $random(seed);
    offset_rand_max = {offset_rand_max, temp_integer};
  end
    
  addr_offset = offset_rand_max % (slv_region_size_array[slave_id][region_id] + 1);
  if(slv_addr_dcdr != 1) begin
    slv_addr[`AXI_AW-1:0] = slv_region_start_array[slave_id][region_id] + addr_offset[`AXI_AW-1:0];
  end
  boundary = addr_offset / (4096);

  case(`AXI_DW)
      8: burst_size  = {$random(seed)} % 1;
     16: burst_size  = {$random(seed)} % 2;
     32: burst_size  = {$random(seed)} % 3;
     64: burst_size  = {$random(seed)} % 4;
    128: burst_size  = {$random(seed)} % 5;
    256: burst_size  = {$random(seed)} % 6;
    512: burst_size  = {$random(seed)} % 7;
   1024: burst_size  = {$random(seed)} % 8;
   default: $display("\n@%0d [TB_ERROR] {%m} : Programmed AXI_DW value=%0h, is not valid \n",$time,`AXI_DW);
  endcase 
  
  num_bytes = 2**burst_size;
  /** Max number of bytes in exclusive access is 128 */
  if(lock_type == `SIM_EXCLUSIVE) begin
    while(num_bytes > 128) begin
      burst_size = burst_size - 1; 
      num_bytes = 2**burst_size;
    end
  end
  
  /** 
    * Randomly selects Burst Types from Fixed, Incremental or Wrapping
    * Unless specificaly asked for incr.
    */ 
  if (burst == `SIM_BURST_INCR_16)  
    burst_type = 1;
  else if (burst == `SIM_BURST_SINGLE)  
    burst_type = {$random(seed)} % 2;
  else 
    burst_type = {$random(seed)} % 3;
  
  /**
    * If the Burst Type is "Wrapping" ensures the length of the burst is
    * 2,4,8, 16 etc. as specified by the AXI protocol.
    */
  if(burst_type == 2) begin
    axi_weighted_burst_length(burst_length);
    while((burst_length != 2 && burst_length != 4 && burst_length != 8 && burst_length != 16) || ((burst_length)*num_bytes >= 4096) ) begin
      axi_weighted_burst_length(burst_length);
    end
  end 
  /** 
    * If the Burst Type is "Incremental" adjusts addr to ensure the length of the burst 
    * doesn't cause the transaction to cross Slave region boundaries
    */
  else if (burst_type == 1) begin 
    if(burst == `SIM_BURST_INCR_16) begin
      burst_length = 16;
    end
    else if (burst == `SIM_BURST_SINGLE) begin  
      burst_length = 1;
    end
    else begin
      axi_weighted_burst_length(burst_length);
    end
    if(((burst_length)*num_bytes) + addr_offset[`AXI_AW-1:0] >= (4096*(boundary+1)) - 1) begin
      if(slv_addr_dcdr != 1) begin
       slv_addr[`AXI_AW-1:0] = slv_region_start_array[slave_id][region_id] + 4096*boundary;
      end
    end
  end
  /**
    * If the Burst Type is "Fixed" ensures the length of the burst 
    * is within the burst length limit set by the AXI protocol
    */
  else begin
    if (burst == `SIM_BURST_SINGLE) begin  
      burst_length = 1;
    end
    else begin
      axi_weighted_burst_length(burst_length);
      while (burst_length > 16) begin
        axi_weighted_burst_length(burst_length);
      end  
    end
  end

  /**
    * If AxLOCK is exclusive, then take care of all the restrictions that
    * apply to exclusive access transactions as per protocol.
    */
  if(lock_type == `SIM_EXCLUSIVE) begin
    total_bytes = (burst_length) * num_bytes;
    while(//total_bytes != 1 &&  /** Due to STAR - 9000557216 for AXI SVT VIP */
          total_bytes != 2 &&
          total_bytes != 4 &&
          total_bytes != 8 && 
          total_bytes != 16 && 
          total_bytes != 32 && 
          total_bytes != 64 && 
          total_bytes != 128) begin
      
      axi_weighted_burst_length(burst_length);

      /** Exclusive accesses are not permitted to use a burstlength > 16. */
      while (burst_length > 16) begin
        axi_weighted_burst_length(burst_length);
      end               
 
      total_bytes = (burst_length) * num_bytes;
    end
  end 
  else begin
    while((burst_length)*num_bytes >= 4096) begin
      axi_weighted_burst_length(burst_length);
    end
  end
  
  if(burst_length == 1 && burst_type == 2 && lock_type == `SIM_EXCLUSIVE) begin
    burst_length = 2;
    burst_size = 0;
    num_bytes = 2**burst_size;
    total_bytes = (burst_length) * num_bytes;
  end

  /** 
    * Make sure to generate address targetting to default Slave when slv_addr_dcdr=1.
    * Basically we ensure that address doesn't fall into any of the existing Slave regions.
    */
  if(slv_addr_dcdr == 1) begin
    slv_addr = {`SVT_AXI_MAX_ADDR_WIDTH{1'b0}};
    decode_addr = 0;
    while (decode_addr != 1) begin
      brk = 0;
      slv_addr1 = $random(seed);
      slv_addr2 = $random(seed);
      slv_addr = {slv_addr1,slv_addr2};
      slv_addr = (slv_addr/num_bytes) * (num_bytes); /** Align the address */
      boundary = slv_addr % 4096;
      total_bytes = burst_length * (1 << burst_size);
      if ( (boundary + total_bytes) >= 4096) begin /** Make sure address doesn't cross 4K */
        slv_addr = slv_addr - boundary; 
        slv_addr = (slv_addr/num_bytes) * (num_bytes); /** Align the address */
      end  
      for (i=1; i<= `AXI_NUM_SLAVES; i=i+1) begin
        for (r=0; r<= slv_num_regions[i]; r++) begin
          if ( (slv_addr >= slv_region_start_array[i][r]) && (slv_addr <= slv_region_end_array[i][r]) ) begin
            decode_addr = 0;
            brk = 1;
            break;
          end  
          else
            decode_addr = 1;
        end
        if (brk)
          break;
      end
    end
  end

  /** Make sure to generate an un-aligned address, when slv_addr_dcdr=2. */
  if(slv_addr_dcdr == 2) begin
   if(test_debug) $display("\n@%0d [TB_DEBUG] {%m} : Generated Aligned Slave Address : %0h \n",$time,slv_addr);
   if(burst_size) begin
    slv_addr = slv_addr + burst_size;
   end 
   else begin
     if(test_debug) $display("\n@%0d [TB_DEBUG] {%m} : Generated burst_size=0, hence address is always aligned \n",$time);
   end        
   if(test_debug) $display("\n@%0d [TB_DEBUG] {%m} : Generated Un-Aligned Slave Address : %0h \n",$time,slv_addr);
  end

  /**
    * If burst type is randomly selected to be "Wrapping"
    * Ensure starting address is aligned to the size of the transfer
    */
  if(burst_type == 2) begin 
    slv_addr = (slv_addr/num_bytes) * (num_bytes);   
    if(test_debug) $display("\n@%0d [TB_DEBUG] {%m} : Since burst is WRAP, generating Aligned Slave Address : %0h \n",$time,slv_addr);
  end
  
  /**
    * If burst type is randomly selected to be an Exclusive access
    * Ensure starting address is aligned to the size of the transfer
    */
  if(lock_type == `SIM_EXCLUSIVE) slv_addr = (slv_addr/total_bytes) * (total_bytes);   

  /** Randomly selects Privileged access */
  prot_type[0]  = {$random(seed)} % 2;
  /** Selects Secure access based on external argument */
  prot_type[1]  = secure_sel;
  /** Randomly selects Instruction access */
  prot_type[2]  = {$random(seed)} % 2;
  
  /** Ensures the randomly selected Cache Type doesn't select a reserved value */
  cache_type = {$random(seed)} % 16;
  while(cache_type == 4 || cache_type == 5 || cache_type == 8 || cache_type == 9 || cache_type == 12 || cache_type == 13) begin
    cache_type = {$random(seed)} % 16;
  end

  /** For exclusive access, transaction can't be cacheable */
  if(lock_type == `SIM_EXCLUSIVE)
    //cache_type = {$random(seed)} % 2;  /** Due to VIP bug which checks for both NON_BUFF and NON_CACHE */
    cache_type = 0;
  
  /** Randomly select an AID value for this transaction */
  aid = {$random(seed)} % (1<<`AXI_MIDW);

  /** If Bi-direction support exists, make sure aid is generated as per legal configuration */
`ifdef AXI_BICMD_SUPPORT

  if(master_id <= `AXI_NUM_ICM && `AXI_LOG2_NM > 0) begin
    if(`AXI_NUM_ICM == 1) begin
      random_master = ({$random(seed)} % `AXI_NUM_SYS_MASTERS) + 1;
      while(axi_pnum_for_snum[random_master] != 1) begin
        random_master = {$random(seed)} % `AXI_NUM_SYS_MASTERS + 1;
      end
      aid[`AXI_SIDW-1:`AXI_SIDW-`AXI_LOG2_NM] = random_master - 1;
    end else begin
      random_master = {$random(seed)} % num_valid_icm_master[master_id];
      aid[`AXI_SIDW-1:`AXI_SIDW-`AXI_LOG2_NM] = valid_icm_master[master_id][random_master+1] - 1;
    end
  end
`endif

  case(burst_size)
      0: dwsize  = 8;
      1: dwsize  = 16;
      2: dwsize  = 32;
      3: dwsize  = 64;
      4: dwsize  = 128;
      5: dwsize  = 256;
      6: dwsize  = 512;
      7: dwsize  = 1024;
    default: $display("\n@%0d [TB_ERROR] {%m} : Programmed AXI_DW value=%0h, randomized burst_size=%0h, are not valid \n",$time,`AXI_DW,burst_size);
  endcase

  case(burst_size)
      0: wstrb_mask  = 128'h1;
      1: wstrb_mask  = 128'h3;
      2: wstrb_mask  = 128'hf;
      3: wstrb_mask  = 128'hff;
      4: wstrb_mask  = 128'hffff;
      5: wstrb_mask  = 128'hffff_ffff;
      6: wstrb_mask  = 128'hffff_ffff_ffff_ffff;
      7: wstrb_mask  = 128'hffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff;
   default: $display("\n@%0d [TB_ERROR] {%m} : Programmed AXI_DW value=%0h, randomized burst_size=%0h, are not valid \n",$time,`AXI_DW,burst_size);
  endcase

  /** Randomly generate QoS Value */
`ifdef AXI_QOS

  `ifdef AXI_HAS_AXI4

  axi_qos_val = $random(seed);
  `endif
`endif

  /** Randomly generate User signals */
`ifdef AXI_HAS_AXI4

  addr_user = {$random(seed),$random(seed),$random(seed),$random(seed),$random(seed),$random(seed),$random(seed),$random(seed)};
  data_user = {$random(seed),$random(seed),$random(seed),$random(seed),$random(seed),$random(seed),$random(seed),$random(seed)};
`endif

//`ifdef AXI_HAS_ACELITE
//     domain_type = $random(seed);
//     barrier_type = $random(seed);
//     coherent_xact_type = $random(seed) % 21;
//    //Remove the full ace transactions
//     case (coherent_xact_type)
//       `SVT_AXI_COHERENT_TRANSACTION_TYPE_READSHARED,`SVT_AXI_COHERENT_TRANSACTION_TYPE_READCLEAN,
//       `SVT_AXI_COHERENT_TRANSACTION_TYPE_READNOTSHAREDDIRTY,`SVT_AXI_COHERENT_TRANSACTION_TYPE_READUNIQUE,
//       `SVT_AXI_COHERENT_TRANSACTION_TYPE_CLEANUNIQUE,`SVT_AXI_COHERENT_TRANSACTION_TYPE_MAKEUNIQUE,
//       `SVT_AXI_COHERENT_TRANSACTION_TYPE_DVMCOMPLETE,`SVT_AXI_COHERENT_TRANSACTION_TYPE_DVMMESSAGE :
//         coherent_xact_type  = `SVT_AXI_COHERENT_TRANSACTION_TYPE_READNOSNOOP;
//       `SVT_AXI_COHERENT_TRANSACTION_TYPE_WRITECLEAN,`SVT_AXI_COHERENT_TRANSACTION_TYPE_WRITEBACK,
//       `SVT_AXI_COHERENT_TRANSACTION_TYPE_EVICT,`SVT_AXI_COHERENT_TRANSACTION_TYPE_WRITEBACK : coherent_xact_type  = `SVT_AXI_COHERENT_TRANSACTION_TYPE_WRITENOSNOOP;
//     endcase
//
//     // Clean invalid , Make invalid  and Write line unique burst_length must be 1,2,4,8 or 16
//     if((coherent_xact_type == 9 ) || (coherent_xact_type == 10 ) || (coherent_xact_type == 16 )) begin
//       burst_length = 1 << ($random(seed) % 4) ;
//     end
//
//     // Read barrier or write barrier  burst_length must be zero
//     if ((coherent_xact_type == 13 ) || (coherent_xact_type == 20 )) begin
//       burst_type = 1;
//       burst_length = 1;
//       barrier_type = barrier_type | 2'b1;
//     end 
//     else begin
//       barrier_type = barrier_type & 2'b0;
//     end
//`endif

   /** Create a new buffer for the transaction */
   `TOP.vip_new_data("master",master_id,"svt_axi_master_transaction",xfer_handle); 

   /** Program the transaction type */
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"xact_type", xact_type , 0,is_valid)
   /** Program the burst length */
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"burst_length",burst_length, 0,is_valid)
//`ifdef AXI_HAS_ACELITE
//    if (coherent_xact_type >= `SVT_AXI_COHERENT_TRANSACTION_TYPE_WRITENOSNOOP ) 
//`else 
   if (xact_type == `SIM_WRITE) 
//`endif
     `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle, "rresp_size", 0 , 0,is_valid)
   else
     `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle, "rresp_size", burst_length, 0,is_valid)

   /** Program other transaction attributes like addr, burst_type, etc... */
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"addr", slv_addr, 0,is_valid)
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"burst_type", burst_type, 0,is_valid)
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"prot_type", prot_type, 0,is_valid)
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"cache_type", cache_type, 0,is_valid)
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"burst_size", burst_size, 0,is_valid)
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"id", aid, 0,is_valid)
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"wvalid_delay_size", burst_length, 0,is_valid)
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"rready_delay_size", burst_length, 0,is_valid)
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"wstrb_size", burst_length, 0,is_valid)
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"data_size", burst_length, 0,is_valid)
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"data_user_size", burst_length, 0,is_valid)
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"atomic_type", lock_type, 0,is_valid)
    
   data_with_addr = 0;
//`ifdef DW_AXI_TB_ENABLE_QOS_INT
  // DW_axi does not support data before address scenario in AXI4 mode
  // But we need to ensure that data with address scenario is supported
  //`ifdef AXI_HAS_AXI4
  //   if(burst == `SIM_BURST_SINGLE)
  //     data_with_addr = 1;
  //   else
  //     data_with_addr = {$random(seed)} % 2;
  //   if ((data_with_addr == 1) && (xact_type == `SIM_WRITE)) begin
  //     `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"reference_event_for_first_wvalid_delay", `SVT_AXI_MASTER_TRANSACTION_WRITE_ADDR_VALID_REF, 0,is_valid)
  //   end

  //   if(data_with_addr)
  //     addr_valid_delay = 50 + {$random(seed)} % 51 ;
  //   else
  //     addr_valid_delay = {$random(seed)} % 4;
  //   while (addr_valid_delay < 0) begin
  //       addr_valid_delay = $random(seed) % 4;
  //     end
  //   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"addr_valid_delay", addr_valid_delay, 0,is_valid)
  //
  // `else // AXI3 mode

  /** 
    * 0 = data width address
    * 1 = data before address
    * 2 = data after address
    */
  data_before_addr = {$random(seed)} % 3;
  if (data_before_addr==0) data_with_addr=1;

  if ((data_before_addr == 1) && (xact_type == `SIM_WRITE)) begin
    `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"data_before_addr", data_before_addr, 0,is_valid)
    `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"reference_event_for_first_wvalid_delay", `SVT_AXI_MASTER_TRANSACTION_PREV_WRITE_DATA_HANDSHAKE_REF, 0,is_valid)
    `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"reference_event_for_addr_valid_delay", `SVT_AXI_MASTER_TRANSACTION_FIRST_WVALID_DATA_BEFORE_ADDR, 0,is_valid)
    if (test_debug) $display("@%0d [TB_DEBUG] {%m} : Setting the data_before_addr to 1\n",$time);
  end
  if ((data_before_addr == 0) && (xact_type == `SIM_WRITE)) begin
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"reference_event_for_first_wvalid_delay", `SVT_AXI_MASTER_TRANSACTION_WRITE_ADDR_VALID_REF, 0,is_valid)
  end
     
  if (data_before_addr == 1) begin  //-: DATA BEFORE ADDRESS, SO HAVE DELAY
    addr_valid_delay = {$random(seed)} % 8 + 1;
  end else if (data_before_addr == 0) begin  //-: DATA WIDTH ADDRESS, SO NO DELAY
    addr_valid_delay = 0;
  end
  else begin  //-: DATA AFTER ADDRESS, HAVE DELAY
    addr_valid_delay = {$random(seed)} % 4;
    while (addr_valid_delay < 0) begin
      addr_valid_delay = $random(seed) % 4;
    end
  end
  `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"addr_valid_delay", addr_valid_delay, 0,is_valid)
  //`endif
//`endif

   bready_delay = {$random(seed)} % 4;
   while (bready_delay < 0) begin
     bready_delay = $random(seed) % 4;
   end
   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"bready_delay", bready_delay, 0,is_valid)

   for (i=0; i<burst_length; i++) begin 
     rready_delay = {$random(seed)} % 4;
     while (rready_delay < 0) begin
       rready_delay = $random(seed) % 4;
     end
     `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"rready_delay", rready_delay, i,is_valid)

     /** Program random delays for WVALID signal */
     if (data_with_addr)
       wvalid_delay = 0;
     else
       wvalid_delay = {$random(seed)} % 4;

     while (wvalid_delay < 0) begin
       wvalid_delay = $random(seed) % 4;
     end

     `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"wvalid_delay", wvalid_delay, i,is_valid)
     
   end
   
   /** Program the QoS value */
`ifdef AXI_QOS

  `ifdef AXI_HAS_AXI4

   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"qos", axi_qos_val, 0,is_valid)
  `endif  
`endif    

//`ifdef AXI_HAS_ACELITE
//    if (coherent_xact_type >= `SVT_AXI_COHERENT_TRANSACTION_TYPE_WRITENOSNOOP) begin
//`else 
   if (xact_type == `SIM_WRITE) begin
//`endif
     /** Randomly generate the write data */
     for (i=0; i<burst_length; i++) begin 
       data = ($random(seed)) & (dwsize-1); 
       `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle, "data", data, i, is_valid) 
     end 
     /** Program random strobe values */
     for (i=0; i<burst_length; i++) begin 
       wstrb = ($random(seed)) & (wstrb_mask); 
       `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"wstrb", wstrb, i, is_valid) 
     end 
     /** Program random data user values */
`ifdef AXI_HAS_AXI4

     for(i=0;i<burst_length;i++) begin
       data_user = $random(seed);
       `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"data_user", data_user, i,is_valid)
     end
`endif
   end
   /** Program random address user values */
`ifdef AXI_HAS_AXI4

   `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"addr_user", addr_user, 0,is_valid)
`endif

//`ifdef AXI_HAS_ACELITE
//    `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"coherent_xact_type",coherent_xact_type, 0,is_valid)
//    `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"domain_type",domain_type, 0,is_valid)
//    `SET_DATA_PROP_W_CHECK("master",master_id,xfer_handle,"barrier_type",barrier_type, 0,is_valid)
//`endif

   if (test_debug) `TOP.vip_display_data("master",master_id,xfer_handle,"[TB_DEBUG] Master Transaction:  ");
end
endtask

/**
  * This task is used to wait for the VIP transaction to be consumed.
  * It takes Master ID and transaction handle as inputs
  */
task automatic axi_master_apply_wait_for_consumed;
  input integer master_id;
  input integer xfer_handle;
  reg is_valid;
begin
  `TOP.vip_apply_data("master",master_id,xfer_handle);
  `TOP.vip_notify_wait_for("master",master_id,"driver.NOTIFY_TX_XACT_CONSUMED",is_valid); 
  if (test_debug) $display("@%0d [TB_DEBUG] {%m} : Got the Notification driver.NOTIFY_TX_XACT_CONSUMED from Master for transfer\n",$time);
end
endtask

`endif // TB_AXI_TASKS_MST_V
