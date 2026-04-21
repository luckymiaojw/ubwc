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
// File Version     :        $Revision: #2 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/sim/testbench/sim_svte/test_DW_axi.sv#2 $ 
//------------------------------------------------------------------------

`timescale 1 ns / 1 ns

`include "axi_2t1_int_DW_axi_constants.vh"
`include "axi_2t1_int_DW_axi_cc_constants.vh"

//this is done to check if macro prefixing is enabled
`ifndef AXI_NUM_SLAVES

`define MACRO_PREFIX_EN 
`endif

`ifdef MACRO_PREFIX_EN

`include "test_DW_axi_cc_constants.vh"
`endif

`ifdef SNPS_INTERNAL_ON

`include "DW_axi_sva01.v"
`include "DW_axi_bvm02.v"
`endif
//------------------------------------------------------------------------

/**
 * Includes required for AMBA SVT VIP
 */
`include "svt_axi_defines.svi"
`include "svt_axi_master_agent_hdl.sv"
`include "svt_axi_slave_agent_hdl.sv"

/**
 * Include APB master BFM */
`ifdef AXI_QOS

 `include "tb_apb_master.sv"
`endif

/**
 * File containing commonly used macros.
 */
`include "tb_common_macros.sv"

/**
 * File containing test decoder for external decoder config
 */
`include "tb_dcdr.sv"  
//`include "tb_systolcl.sv"
//`include "tb_busmux.sv"

/**
 * File containing 'run_test' method to initiate traffic.
 */
`include "test.sv"

/**
 * Slave 0 is default slave.
 */
`define AXI_HAS_S0

/**
 * Test case timeout value.
 */
`ifdef AXI_HAS_M10

  // More traffic if number of master's are more
  //  Hence more the timeout value
  `define TEST_TIMEOUT #1500_0000
`else
  `define TEST_TIMEOUT #1500_0000
`endif

/**
 * To hold the seed value.
 *  - will be assinged with `AXI_SEED.
 *  - used in $ramdom(seed) calls.
 */
integer seed=0;

/** Variable(s) to throttle and control Slave VIP response generation.
 *    These variable(s) are used by 'test_max_id_limit' to throttle Slave(s) Response generation. 
 */
reg long_bvalid_delay = 0;
reg long_rvalid_delay = 0;

integer i;

/** Top-level Module */
module test_DW_axi;

  parameter simulation_cycle = 100;
  /** Low-Power test parameters */
  parameter  FullPower   = 1'b0;
  parameter  LowPower    = 1'b1;
  localparam AR_HAS_BUFF = (`AXI_AR_TMO != 0) & (`AXI_AR_PL_ARB);
  localparam AW_HAS_BUFF = (`AXI_AW_TMO != 0) & (`AXI_AW_PL_ARB);
  localparam W_HAS_BUFF  = (`AXI_W_TMO != 0)  & (`AXI_W_PL_ARB );

  reg       system_clk,pclk;
  wire      aclk = system_clk;

  reg       aresetn;

  /** Event to signal initial reset signaling. */
  event     reset_done;

  /** Event to synchronize the seed randomization */
  event     seed_set;

  /** Sempahore for APB rd/wr tasks */
  semaphore rd_wr_semaphore ;

  /** Low-Power test signals */
  reg      csysreq;
  wire     cactive;
  wire     csysack;
  reg      low_power_mode;
  integer axi_idle;
  integer sim_in_progress;

  /** Variable to enable testbench debug messages */
  integer test_debug;

  /**
   * Master VIP to DW_axi signals (Long Vector format)
   */
   wire [(`AXI_NUM_MASTERS*`AXI_LOG2_NSP1)-1:0]                 xdcdr_slv_num_rd_m_bus;
   wire [(`AXI_NUM_MASTERS*`AXI_LOG2_NSP1)-1:0]                 xdcdr_slv_num_wr_m_bus;

  //-----------------------------------------------------------------------
  // AXI3 Interface Write Address Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_MASTERS)-1:0]                                   awvalid_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_ADDR_WIDTH-1):0]           awaddr_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_BURST_LENGTH_WIDTH-1):0]   awlen_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_SIZE_WIDTH-1):0]               awsize_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_BURST_WIDTH-1):0]              awburst_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_LOCK_WIDTH-1):0]               awlock_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_CACHE_WIDTH-1):0]              awcache_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_PROT_WIDTH-1):0]               awprot_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_ID_WIDTH-1):0]             awid_m_bus;
  wire [(`AXI_NUM_MASTERS)-1:0]                                   awready_m_bus;

  // AXI ACE Extension of Write Address Channel Signals
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_ACE_DOMAIN_WIDTH-1):0]         awdomain_m_bus;    
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_ACE_WSNOOP_WIDTH-1):0]         awsnoop_m_bus; 
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_ACE_BARRIER_WIDTH-1):0]        awbar_m_bus;

  //-----------------------------------------------------------------------
  // AXI Interface Read Address Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_MASTERS)-1:0]                                   arvalid_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_ADDR_WIDTH-1):0]           araddr_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_BURST_LENGTH_WIDTH-1):0]   arlen_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_SIZE_WIDTH-1):0]               arsize_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_BURST_WIDTH-1):0]              arburst_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_LOCK_WIDTH-1):0]               arlock_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_CACHE_WIDTH-1):0]              arcache_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_PROT_WIDTH-1):0]               arprot_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_ID_WIDTH-1):0]             arid_m_bus;
  wire [(`AXI_NUM_MASTERS)-1:0]                                   arready_m_bus;

  // AXI ACE Extension of Read Address Channel 
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_ACE_DOMAIN_WIDTH-1):0]         ardomain_m_bus;    
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_ACE_RSNOOP_WIDTH-1):0]         arsnoop_m_bus; 
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_ACE_BARRIER_WIDTH-1):0]        arbar_m_bus;

  //-----------------------------------------------------------------------
  // AXI Interface Read Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_MASTERS)-1:0]                                   rvalid_m_bus;
  wire [(`AXI_NUM_MASTERS)-1:0]                                   rlast_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_DATA_WIDTH-1):0]           rdata_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_RESP_WIDTH-1):0]               rresp_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_ID_WIDTH-1):0]             rid_m_bus;
  wire [(`AXI_NUM_MASTERS)-1:0]                                   rready_m_bus;

  // AXI ACE Extension of Read Data Channel
  wire [(`AXI_NUM_MASTERS)-1:0]                                   rack_m_bus;

  //-----------------------------------------------------------------------
  // AXI Interface Write Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_MASTERS)-1:0]                                   wvalid_m_bus;
  wire [(`AXI_NUM_MASTERS)-1:0]                                   wlast_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_DATA_WIDTH-1):0]           wdata_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_DATA_WIDTH/8-1):0]         wstrb_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_ID_WIDTH-1):0]             wid_m_bus;
  wire [(`AXI_NUM_MASTERS)-1:0]                                   wready_m_bus;
  
  //-----------------------------------------------------------------------
  // AXI Interface Write Response Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_MASTERS)-1:0]                                   bvalid_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_RESP_WIDTH-1):0]               bresp_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_ID_WIDTH-1):0]             bid_m_bus;
  wire [(`AXI_NUM_MASTERS)-1:0]                                   bready_m_bus;

  // AXI ACE Extension of Write Response Channel
  wire [(`AXI_NUM_MASTERS)-1:0]                                   wack_m_bus;

  //-----------------------------------------------------------------------
  // AXI4 Interface Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_REGION_WIDTH-1):0]             awregion_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_QOS_WIDTH-1):0]                awqos_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_ADDR_USER_WIDTH-1):0]      awuser_m_bus;
  
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_REGION_WIDTH-1):0]             arregion_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_QOS_WIDTH-1):0]                arqos_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_ADDR_USER_WIDTH-1):0]      aruser_m_bus;

  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_DATA_USER_WIDTH-1):0]      wuser_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_DATA_USER_WIDTH-1):0]      ruser_m_bus;
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_MAX_BRESP_USER_WIDTH-1):0]     buser_m_bus;

  //-----------------------------------------------------------------------
  // AXI ACE Interface SNOOP Address Channel Signals 
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_MASTERS)-1:0]                                   acvalid_m_bus; 
  wire [(`AXI_NUM_MASTERS)-1:0]                                   acready_m_bus; 
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_ACE_SNOOP_ADDR_WIDTH-1):0]     acaddr_m_bus;          
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_ACE_SNOOP_TYPE_WIDTH-1):0]     acsnoop_m_bus; 
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_ACE_SNOOP_BURST_WIDTH-1):0]    aclen_m_bus;       
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_ACE_SNOOP_PROT_WIDTH-1):0]     acprot_m_bus;      

  //-----------------------------------------------------------------------
  // AXI ACE Interface SNOOP Response Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_MASTERS)-1:0]                                   crvalid_m_bus; 
  wire [(`AXI_NUM_MASTERS)-1:0]                                   crready_m_bus; 
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_ACE_SNOOP_RESP_WIDTH-1):0]     crresp_m_bus;      

  //-----------------------------------------------------------------------
  // AXI ACE Interface Data Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_MASTERS)-1:0]                                   cdvalid_m_bus; 
  wire [(`AXI_NUM_MASTERS)-1:0]                                   cdready_m_bus; 
  wire [(`AXI_NUM_MASTERS*`SVT_AXI_ACE_SNOOP_DATA_WIDTH-1):0]     cddata_m_bus;      
  wire [(`AXI_NUM_MASTERS)-1:0]                                   cdlast_m_bus;

  //------------------------------------------------------------------------

  /**
   * Slave VIP to DW_axi signals. (Long Vector format)
   */
  //-----------------------------------------------------------------------
  // AXI3 Interface Write Address Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_SLAVES)-1:0]                                   awvalid_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_ADDR_WIDTH-1):0]           awaddr_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_BURST_LENGTH_WIDTH-1):0]   awlen_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_SIZE_WIDTH-1):0]               awsize_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_BURST_WIDTH-1):0]              awburst_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_LOCK_WIDTH-1):0]               awlock_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_CACHE_WIDTH-1):0]              awcache_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_PROT_WIDTH-1):0]               awprot_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_ID_WIDTH-1):0]             awid_s_bus;
  wire [(`AXI_NUM_SLAVES)-1:0]                                   awready_s_bus;

  // AXI ACE Extension of Write Address Channel Signals
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_ACE_DOMAIN_WIDTH-1):0]         awdomain_s_bus;    
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_ACE_WSNOOP_WIDTH-1):0]         awsnoop_s_bus; 
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_ACE_BARRIER_WIDTH-1):0]        awbar_s_bus;

  //-----------------------------------------------------------------------
  // AXI Interface Read Address Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_SLAVES)-1:0]                                   arvalid_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_ADDR_WIDTH-1):0]           araddr_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_BURST_LENGTH_WIDTH-1):0]   arlen_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_SIZE_WIDTH-1):0]               arsize_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_BURST_WIDTH-1):0]              arburst_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_LOCK_WIDTH-1):0]               arlock_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_CACHE_WIDTH-1):0]              arcache_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_PROT_WIDTH-1):0]               arprot_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_ID_WIDTH-1):0]             arid_s_bus;
  wire [(`AXI_NUM_SLAVES)-1:0]                                   arready_s_bus;

  // AXI ACE Extension of Read Address Channel 
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_ACE_DOMAIN_WIDTH-1):0]         ardomain_s_bus;    
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_ACE_RSNOOP_WIDTH-1):0]         arsnoop_s_bus; 
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_ACE_BARRIER_WIDTH-1):0]        arbar_s_bus;

  //-----------------------------------------------------------------------
  // AXI Interface Read Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_SLAVES)-1:0]                                   rvalid_s_bus;
  wire [(`AXI_NUM_SLAVES)-1:0]                                   rlast_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_DATA_WIDTH-1):0]           rdata_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_RESP_WIDTH-1):0]               rresp_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_ID_WIDTH-1):0]             rid_s_bus;
  wire [(`AXI_NUM_SLAVES)-1:0]                                   rready_s_bus;

  // AXI ACE Extension of Read Data Channel
  wire [(`AXI_NUM_SLAVES)-1:0]                                   rack_s_bus;

  //-----------------------------------------------------------------------
  // AXI Interface Write Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_SLAVES)-1:0]                                   wvalid_s_bus;
  wire [(`AXI_NUM_SLAVES)-1:0]                                   wlast_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_DATA_WIDTH-1):0]           wdata_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_DATA_WIDTH/8-1):0]         wstrb_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_ID_WIDTH-1):0]             wid_s_bus;
  wire [(`AXI_NUM_SLAVES)-1:0]                                   wready_s_bus;
  
  //-----------------------------------------------------------------------
  // AXI Interface Write Response Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_SLAVES)-1:0]                                   bvalid_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_RESP_WIDTH-1):0]               bresp_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_ID_WIDTH-1):0]             bid_s_bus;
  wire [(`AXI_NUM_SLAVES)-1:0]                                   bready_s_bus;

  // AXI ACE Extension of Write Response Channel
  wire [(`AXI_NUM_SLAVES)-1:0]                                   wack_s_bus;

  //-----------------------------------------------------------------------
  // AXI4 Interface Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_REGION_WIDTH-1):0]             awregion_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_QOS_WIDTH-1):0]                awqos_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_ADDR_USER_WIDTH-1):0]      awuser_s_bus;
  
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_REGION_WIDTH-1):0]             arregion_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_QOS_WIDTH-1):0]                arqos_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_ADDR_USER_WIDTH-1):0]      aruser_s_bus;

  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_DATA_USER_WIDTH-1):0]      wuser_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_DATA_USER_WIDTH-1):0]      ruser_s_bus;
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_MAX_BRESP_USER_WIDTH-1):0]     buser_s_bus;

  //-----------------------------------------------------------------------
  // Testbench signals for checker
  //-----------------------------------------------------------------------
  wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s[`AXI_NUM_SLAVES:0];
  wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s[`AXI_NUM_SLAVES:0];

  //-----------------------------------------------------------------------
  // AXI ACE Interface SNOOP Address Channel Signals 
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_SLAVES)-1:0]                                   acvalid_s_bus; 
  wire [(`AXI_NUM_SLAVES)-1:0]                                   acready_s_bus; 
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_ACE_SNOOP_ADDR_WIDTH-1):0]     acaddr_s_bus;          
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_ACE_SNOOP_TYPE_WIDTH-1):0]     acsnoop_s_bus; 
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_ACE_SNOOP_BURST_WIDTH-1):0]    aclen_s_bus;       
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_ACE_SNOOP_PROT_WIDTH-1):0]     acprot_s_bus;      

  //-----------------------------------------------------------------------
  // AXI ACE Interface SNOOP Response Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_SLAVES)-1:0]                                   crvalid_s_bus; 
  wire [(`AXI_NUM_SLAVES)-1:0]                                   crready_s_bus; 
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_ACE_SNOOP_RESP_WIDTH-1):0]     crresp_s_bus;      

  //-----------------------------------------------------------------------
  // AXI ACE Interface Data Channel Signals
  //-----------------------------------------------------------------------
  wire [(`AXI_NUM_SLAVES)-1:0]                                   cdvalid_s_bus; 
  wire [(`AXI_NUM_SLAVES)-1:0]                                   cdready_s_bus; 
  wire [(`AXI_NUM_SLAVES*`SVT_AXI_ACE_SNOOP_DATA_WIDTH-1):0]     cddata_s_bus;      
  wire [(`AXI_NUM_SLAVES)-1:0]                                   cdlast_s_bus;

  //-----------------------------------------------------------------------
  // Testbench signals for checker
  //-----------------------------------------------------------------------
  wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]                           awdomain_s[`AXI_NUM_SLAVES:0];
  wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]                           awsnoop_s[`AXI_NUM_SLAVES:0];
  wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]                          awbar_s[`AXI_NUM_SLAVES:0];
  wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]                           ardomain_s[`AXI_NUM_SLAVES:0];
  wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]                           arsnoop_s[`AXI_NUM_SLAVES:0];
  wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]                          arbar_s[`AXI_NUM_SLAVES:0];

  //------------------------------------------------------------------------

`ifdef AXI_QOS

  // APB related signals
  event apb_start_done;
  reg                         presetn ;
  wire [15:0]                 psel ;
  wire                        penable ;
  wire                        pwrite ;
  wire [`APB_ADDR_WIDTH-1:0]  paddr ;
  wire [`APB_DATA_WIDTH-1:0]  prdata ;
  wire [`APB_DATA_WIDTH-1:0]  pwdata ;
  
  reg apb_reg_prog_flag; // flag to avoid multiple write at same time
  
  /**
    * -- Macro to assign QOS signal of each master port from shared variable.
    * -- (shared variable i.e. arqos_m_bus is connected to DW AXI Master VIP
    * -- refer to VIP instance below)
    */
  `define AXI_QOS_ASSIGN_MASTER_SIGNALS(MP, AWQOS_EXT, ARQOS_EXT, AWQOS_SIG, ARQOS_SIG) \
    `ifdef AWQOS_EXT\
\
      wire [`SVT_AXI_QOS_WIDTH-1:0]  AWQOS_SIG; \
      `ifdef AXI_HAS_AXI3\
\
        assign AWQOS_SIG = 4'h0; \
      `endif \
      `ifdef AXI_HAS_AXI4\
\
        assign AWQOS_SIG = awqos_m_bus[((MP * `SVT_AXI_QOS_WIDTH) - 1) : ((MP - 1) * `SVT_AXI_QOS_WIDTH) ]; \
      `endif \
    `endif \
    `ifdef ARQOS_EXT\
\
      wire [`SVT_AXI_QOS_WIDTH-1:0]  ARQOS_SIG; \
      `ifdef AXI_HAS_AXI3\
\
        assign ARQOS_SIG = 4'h0; \
      `endif \
      `ifdef AXI_HAS_AXI4\
\
        assign ARQOS_SIG = arqos_m_bus[((MP * `SVT_AXI_QOS_WIDTH) - 1) : ((MP - 1) * `SVT_AXI_QOS_WIDTH) ]; \
      `endif \
    `endif
  
  /** Macro to assign QOS signals of slave port to DW AXI Slave VIP */
  `define AXI_QOS_ASSIGN_SLAVE_SIGNALS(SP, HAS_SLAVE, AWQOS_SIG, ARQOS_SIG) \
    `ifdef HAS_SLAVE\
\
      wire [`SVT_AXI_QOS_WIDTH-1:0]  AWQOS_SIG; \
      wire [`SVT_AXI_QOS_WIDTH-1:0]  ARQOS_SIG; \
      assign awqos_s_bus[((SP * `SVT_AXI_QOS_WIDTH) - 1) : ((SP - 1) * `SVT_AXI_QOS_WIDTH) ] = AWQOS_SIG ; \
      assign arqos_s_bus[((SP * `SVT_AXI_QOS_WIDTH) - 1) : ((SP - 1) * `SVT_AXI_QOS_WIDTH) ] = ARQOS_SIG ; \
    `endif
  
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(1,  AXI_AWQOS_EXT_M1,  AXI_ARQOS_EXT_M1, awqos_m1, arqos_m1)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(2,  AXI_AWQOS_EXT_M2,  AXI_ARQOS_EXT_M2, awqos_m2, arqos_m2)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(3,  AXI_AWQOS_EXT_M3,  AXI_ARQOS_EXT_M3, awqos_m3, arqos_m3)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(4,  AXI_AWQOS_EXT_M4,  AXI_ARQOS_EXT_M4, awqos_m4, arqos_m4)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(5,  AXI_AWQOS_EXT_M5,  AXI_ARQOS_EXT_M5, awqos_m5, arqos_m5)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(6,  AXI_AWQOS_EXT_M6,  AXI_ARQOS_EXT_M6, awqos_m6, arqos_m6)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(7,  AXI_AWQOS_EXT_M7,  AXI_ARQOS_EXT_M7, awqos_m7, arqos_m7)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(8,  AXI_AWQOS_EXT_M8,  AXI_ARQOS_EXT_M8, awqos_m8, arqos_m8)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(9,  AXI_AWQOS_EXT_M9,  AXI_ARQOS_EXT_M9, awqos_m9, arqos_m9)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(10, AXI_AWQOS_EXT_M10, AXI_ARQOS_EXT_M10, awqos_m10, arqos_m10)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(11, AXI_AWQOS_EXT_M11, AXI_ARQOS_EXT_M11, awqos_m11, arqos_m11)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(12, AXI_AWQOS_EXT_M12, AXI_ARQOS_EXT_M12, awqos_m12, arqos_m12)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(13, AXI_AWQOS_EXT_M13, AXI_ARQOS_EXT_M13, awqos_m13, arqos_m13)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(14, AXI_AWQOS_EXT_M14, AXI_ARQOS_EXT_M14, awqos_m14, arqos_m14)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(15, AXI_AWQOS_EXT_M15, AXI_ARQOS_EXT_M15, awqos_m15, arqos_m15)
    `AXI_QOS_ASSIGN_MASTER_SIGNALS(16, AXI_AWQOS_EXT_M16, AXI_ARQOS_EXT_M16, awqos_m16, arqos_m16)
   
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(1,  AXI_HAS_S1, awqos_s1, arqos_s1)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(2,  AXI_HAS_S2, awqos_s2, arqos_s2)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(3,  AXI_HAS_S3, awqos_s3, arqos_s3)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(4,  AXI_HAS_S4, awqos_s4, arqos_s4)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(5,  AXI_HAS_S5, awqos_s5, arqos_s5)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(6,  AXI_HAS_S6, awqos_s6, arqos_s6)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(7,  AXI_HAS_S7, awqos_s7, arqos_s7)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(8,  AXI_HAS_S8, awqos_s8, arqos_s8)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(9,  AXI_HAS_S9, awqos_s9, arqos_s9)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(10, AXI_HAS_S10, awqos_s10, arqos_s10)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(11, AXI_HAS_S11, awqos_s11, arqos_s11)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(12, AXI_HAS_S12, awqos_s12, arqos_s12)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(13, AXI_HAS_S13, awqos_s13, arqos_s13)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(14, AXI_HAS_S14, awqos_s14, arqos_s14)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(15, AXI_HAS_S15, awqos_s15, arqos_s15)
    `AXI_QOS_ASSIGN_SLAVE_SIGNALS(16, AXI_HAS_S16, awqos_s16, arqos_s16)
`endif // `ifdef AXI_QOS

  //------------------------------------------------------------------------

  /**
    * Wire Declarations for Master Vip to DW_axi (Array format)
    */
   wire [`AXI_NUM_MASTERS:1]                    arvalid_m;
   wire [`SVT_AXI_MAX_ADDR_WIDTH-1:0]           araddr_m[`AXI_NUM_MASTERS:1];
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH-1:0]   arlen_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_SIZE_WIDTH-1:0]               arsize_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_BURST_WIDTH-1:0]              arburst_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_LOCK_WIDTH-1:0]               arlock_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_CACHE_WIDTH-1:0]              arcache_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_PROT_WIDTH-1:0]               arprot_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_MAX_ID_WIDTH-1:0]             arid_m[`AXI_NUM_MASTERS:1];
   wire [`AXI_NUM_MASTERS:1]                    arready_m;
   wire [`AXI_NUM_MASTERS:1]                    awvalid_m;
   wire [`SVT_AXI_MAX_ADDR_WIDTH-1:0]           awaddr_m[`AXI_NUM_MASTERS:1];
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH-1:0]   awlen_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_SIZE_WIDTH-1:0]               awsize_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_BURST_WIDTH-1:0]              awburst_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_LOCK_WIDTH-1:0]               awlock_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_CACHE_WIDTH-1:0]              awcache_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_PROT_WIDTH-1:0]               awprot_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_MAX_ID_WIDTH-1:0]             awid_m[`AXI_NUM_MASTERS:1];
   wire [`AXI_NUM_MASTERS:1]                    awready_m;
   wire [`AXI_NUM_MASTERS:1]                    rvalid_m;
   wire [`AXI_NUM_MASTERS:1]                    rlast_m;
   wire [`AXI_NUM_MASTERS:1]                    rlast_m_tb;
   wire [`SVT_AXI_MAX_DATA_WIDTH-1:0]           rdata_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_RESP_WIDTH-1:0]               rresp_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_MAX_ID_WIDTH-1:0]             rid_m[`AXI_NUM_MASTERS:1];
   wire [`AXI_NUM_MASTERS:1]                    rready_m;
   wire [`AXI_NUM_MASTERS:1]                    wvalid_m;
   wire [`AXI_NUM_MASTERS:1]                    wlast_m;
   wire [`SVT_AXI_MAX_DATA_WIDTH-1:0]           wdata_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_MAX_DATA_WIDTH-1:0]           wstrb_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_MAX_ID_WIDTH-1:0]             wid_m[`AXI_NUM_MASTERS:1];
   wire [`AXI_NUM_MASTERS:1]                    wready_m;
   wire [`AXI_NUM_MASTERS:1]                    bvalid_m;
   wire [`SVT_AXI_RESP_WIDTH-1:0]               bresp_m[`AXI_NUM_MASTERS:1];
   wire [`SVT_AXI_MAX_ID_WIDTH-1:0]             bid_m[`AXI_NUM_MASTERS:1];
   wire [`AXI_NUM_MASTERS:1]                    bready_m;

   wire [`AXI_AW_SBW-1:0]                       awsideband_m[`AXI_NUM_MASTERS:1];
   wire [`AXI_W_SBW-1:0]                        wsideband_m[`AXI_NUM_MASTERS:1];
   wire [`AXI_AR_SBW-1:0]                       arsideband_m[`AXI_NUM_MASTERS:1];
   wire [`AXI_B_SBW-1:0]                        bsideband_m[`AXI_NUM_MASTERS:1];
   wire [`AXI_R_SBW-1:0]                        rsideband_m[`AXI_NUM_MASTERS:1];

  /**
    * Wire Declarations for Slave Vip to DW_axi (Array format)
    */
   wire [`AXI_NUM_SLAVES:0]                     arvalid_s;
   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]             araddr_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]             araddr_s0;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]     arlen_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]     arlen_s0;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]               arsize_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_SIZE_WIDTH-1:0]               arsize_s0;
   wire [`SVT_AXI_BURST_WIDTH-1:0]              arburst_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_BURST_WIDTH-1:0]              arburst_s0;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]               arlock_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_LOCK_WIDTH-1:0]               arlock_s0;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]              arcache_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_CACHE_WIDTH-1:0]              arcache_s0;
   wire [`SVT_AXI_PROT_WIDTH-1:0]               arprot_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_PROT_WIDTH-1:0]               arprot_s0;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]               arid_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_MAX_ID_WIDTH:0]               arid_s0;
   wire [`AXI_NUM_SLAVES:0]                     arready_s;
   wire [`AXI_NUM_SLAVES:0]                     awvalid_s;
   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]             awaddr_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]             awaddr_s0;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]     awlen_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]     awlen_s0;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]               awsize_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_SIZE_WIDTH-1:0]               awsize_s0;
   wire [`SVT_AXI_BURST_WIDTH-1:0]              awburst_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_BURST_WIDTH-1:0]              awburst_s0;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]               awlock_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_LOCK_WIDTH-1:0]               awlock_s0;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]              awcache_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_CACHE_WIDTH-1:0]              awcache_s0;
   wire [`SVT_AXI_PROT_WIDTH-1:0]               awprot_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_PROT_WIDTH-1:0]               awprot_s0;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]               awid_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_MAX_ID_WIDTH:0]               awid_s0;
   wire [`AXI_NUM_SLAVES:0]                     awready_s;
   wire [`AXI_NUM_SLAVES:0]                     rvalid_s;
   wire [`AXI_NUM_SLAVES:0]                     rlast_s;
   wire [`SVT_AXI_MAX_DATA_WIDTH:0]             rdata_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_MAX_DATA_WIDTH:0]             rdata_s0;
   wire [`SVT_AXI_RESP_WIDTH-1:0]               rresp_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_RESP_WIDTH-1:0]               rresp_s0;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]               rid_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_MAX_ID_WIDTH:0]               rid_s0;
   wire [`AXI_NUM_SLAVES:0]                     rready_s;
   wire [`AXI_NUM_SLAVES:0]                     wvalid_s;
   wire [`AXI_NUM_SLAVES:0]                     wlast_s;
   wire [`SVT_AXI_MAX_DATA_WIDTH:0]             wdata_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_MAX_DATA_WIDTH:0]             wdata_s0;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]           wstrb_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]           wstrb_s0;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]               wid_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_MAX_ID_WIDTH:0]               wid_s0;
   wire [`AXI_NUM_SLAVES:0]                     wready_s;
   wire [`AXI_NUM_SLAVES:0]                     bvalid_s;
   wire [`SVT_AXI_RESP_WIDTH-1:0]               bresp_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_RESP_WIDTH-1:0]               bresp_s0;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]               bid_s[`AXI_NUM_SLAVES:0];
   wire [`SVT_AXI_MAX_ID_WIDTH:0]               bid_s0;
   wire [`AXI_NUM_SLAVES:0]                     bready_s;

   wire [`AXI_NUM_SLAVES:0]                     awvalid_alias0_s;
   wire [`AXI_NUM_SLAVES:0]                     awvalid_alias1_s;
   wire [`AXI_NUM_SLAVES:0]                     awvalid_alias2_s;
   wire [`AXI_NUM_SLAVES:0]                     arvalid_alias0_s;
   wire [`AXI_NUM_SLAVES:0]                     arvalid_alias1_s;
   wire [`AXI_NUM_SLAVES:0]                     arvalid_alias2_s;
   wire [`AXI_NUM_SLAVES:0]                     wvalid_alias0_s;
   wire [`AXI_NUM_SLAVES:0]                     wvalid_alias1_s;
   wire [`AXI_NUM_SLAVES:0]                     wvalid_alias2_s;
   wire [`AXI_NUM_SLAVES:0]                     rvalid_alias0_s;
   wire [`AXI_NUM_SLAVES:0]                     rvalid_alias1_s;
   wire [`AXI_NUM_SLAVES:0]                     rvalid_alias2_s;
   wire [`AXI_NUM_SLAVES:0]                     bvalid_alias0_s;
   wire [`AXI_NUM_SLAVES:0]                     bvalid_alias1_s;
   wire [`AXI_NUM_SLAVES:0]                     bvalid_alias2_s;

   reg  [`AXI_NUM_SLAVES:0]                     tz_secure_s;
   wire [`AXI_AW_SBW-1:0]                       awsideband_s[`AXI_NUM_SLAVES:0];
   wire [`AXI_W_SBW-1:0]                        wsideband_s[`AXI_NUM_SLAVES:0];
   wire [`AXI_AR_SBW-1:0]                       arsideband_s[`AXI_NUM_SLAVES:0];
   wire [`AXI_B_SBW-1:0]                        bsideband_s[`AXI_NUM_SLAVES:0];
   wire [`AXI_R_SBW-1:0]                        rsideband_s[`AXI_NUM_SLAVES:0];

  wire [(`AXI_NUM_MASTERS)-1:0]                int_awvalid_m_bus;
   wire [(`AXI_NUM_MASTERS)-1:0]                int_awready_m_bus;
   wire [(`AXI_NUM_MASTERS)-1:0]                int_arvalid_m_bus;
   wire [(`AXI_NUM_MASTERS)-1:0]                int_arready_m_bus;
   wire [(`AXI_NUM_MASTERS)-1:0]                int_wready_m_bus;
   wire [(`AXI_NUM_MASTERS)-1:0]                int_bvalid_m_bus;
   wire [(`AXI_NUM_MASTERS)-1:0]                int_bready_m_bus;
   wire [(`AXI_NUM_MASTERS)-1:0]                int_rvalid_m_bus;
   wire [(`AXI_NUM_MASTERS)-1:0]                int_rready_m_bus;
   wire [(`AXI_NUM_MASTERS)-1:0]                int_rlast_m_bus;
   wire                                         int_csysreq;
   wire                                         int_csysack;
   wire                                         int_cactive;

   assign #1 int_awvalid_m_bus = awvalid_m_bus;
   assign #1 int_awready_m_bus = awready_m_bus;
   assign #1 int_arvalid_m_bus = arvalid_m_bus;
   assign #1 int_arready_m_bus = arready_m_bus;
   assign #1 int_wready_m_bus  = wready_m_bus;
   assign #1 int_bvalid_m_bus  = bvalid_m_bus;
   assign #1 int_bready_m_bus  = bready_m_bus;
   assign #1 int_rvalid_m_bus  = rvalid_m_bus;
   assign #1 int_rready_m_bus  = rready_m_bus;
   assign #1 int_rlast_m_bus   = rlast_m_bus;
   assign #1 int_csysreq       = csysreq;
   assign #1 int_csysack       = csysack;
   assign #1 int_cactive       = cactive;

   //To take care of sampling issues
   assign #1 rlast_m_tb        = rlast_m;

`ifdef AXI_HAS_M1

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]                araddr_m1;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]                  arid_m1;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m1;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]                  arsize_m1;
   wire [`SVT_AXI_BURST_WIDTH-1:0]                 arburst_m1;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]                  arlock_m1;
   wire [`SVT_AXI_PROT_WIDTH-1:0]                  arprot_m1;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]                 arcache_m1;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]                awaddr_m1;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]                  awid_m1;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m1;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]                  awsize_m1;
   wire [`SVT_AXI_BURST_WIDTH-1:0]                 awburst_m1;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]                  awlock_m1;
   wire [`SVT_AXI_PROT_WIDTH-1:0]                  awprot_m1;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]                 awcache_m1;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]                wdata_m1;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]                  wid_m1;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]              wstrb_m1;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]                rdata_m1;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]                  rid_m1;
   wire [`SVT_AXI_RESP_WIDTH:0]                    rresp_m1;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]                  bid_m1;
   wire [`SVT_AXI_RESP_WIDTH:0]                    bresp_m1;
   assign bresp_m1[3:2] = 2'b00;

`ifdef AXI_HAS_ACELITE

   wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m1;
   wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m1;
   wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m1;
   wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m1;
   wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m1;
   wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m1;

   assign awdomain_m1   = awburst_m1;
   assign awsnoop_m1    = awprot_m1;
   assign awbar_m1      = ~awburst_m1;

   assign ardomain_m1   = arburst_m1;
   assign arsnoop_m1    = arcache_m1;
   assign arbar_m1      = ~arburst_m1;
`endif  // `ifdef AXI_HAS_ACELITE

   wire [`AXI_LOG2_NSP1-1:0]                       xdcdr_slv_num_wr_m1;
   wire [`AXI_LOG2_NSP1-1:0]                       xdcdr_slv_num_rd_m1;

   assign xdcdr_slv_num_wr_m[1] = xdcdr_slv_num_wr_m1;
   assign xdcdr_slv_num_rd_m[1] = xdcdr_slv_num_rd_m1;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m1;
   assign arsideband_m[1] = arsideband_m1;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m1;
   assign awsideband_m[1] = awsideband_m1;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m1;
   assign rsideband_m[1] = rsideband_m1;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m1;
   assign wsideband_m[1] = wsideband_m1;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m1;
   assign bsideband_m[1] = bsideband_m1;
 `endif
`else
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m1;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m1;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m1;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m1;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m1;
 `endif  
`endif

   reg       remap_n;
   wire [31:0] num_vis_mst[`AXI_NUM_SLAVES:0];
  `ifdef AXI_BICMD_SUPPORT

   wire [31:0] axi_pnum_for_snum[64:0];
  `endif
   wire [31:0] num_valid_icm_master[4:0];
   wire [31:0] valid_icm_master[4:0][8:0];
   // Visibility settings for the active address mode.
   wire visible_slaves[`AXI_NUM_MASTERS:0][`AXI_NUM_SLAVES:0];
   // Visibility settings for the inactive address mode.
   wire visible_slaves_other_mode[`AXI_NUM_MASTERS:0][`AXI_NUM_SLAVES:0];
   wire [`AXI_NUM_MASTERS-1:0] ri_limit_m;
   // Variable to decode regions
   wire [`AXI_NUM_SLAVES-1:0] axi_has_region;

   wire [31:0]  slv_wid_array [`AXI_NUM_SLAVES:0];
   wire [31:0]  slv_num_regions [`AXI_NUM_SLAVES:0];
   wire [31:0]  region_num;
   wire [`AXI_AW-1:0] slv_region_start_array [`AXI_NUM_SLAVES:0][7:0];
   wire [`AXI_AW-1:0] slv_region_end_array [`AXI_NUM_SLAVES:0][7:0];
   wire [`AXI_AW-1:0] slv_region_size_array [`AXI_NUM_SLAVES:0][7:0];
   wire [31:0]  slv_max_transaction[`AXI_NUM_SLAVES:0];
   wire [31:0]  slv_max_wr_transaction[`AXI_NUM_SLAVES:0];
   wire [31:0]  slv_max_rd_transaction[`AXI_NUM_SLAVES:0];
   wire [31:0]  mst_max_transaction[`AXI_NUM_MASTERS:0];
   wire [31:0]  mst_max_wr_uid_transaction[`AXI_NUM_MASTERS:0];
   wire [31:0]  mst_max_wr_cmd_transaction[`AXI_NUM_MASTERS:0];
   wire [31:0]  mst_max_rd_uid_transaction[`AXI_NUM_MASTERS:0];
   wire [31:0]  mst_max_rd_cmd_transaction[`AXI_NUM_MASTERS:0];

 `ifdef AXI_EXT_PRIORITY


   `ifdef AXI_SHARED_LAYER_SLAVE_PRIORITY_EN

      reg [`AXI_LOG2_NSP1-1:0] slv_priority_shared;
   `endif
   `ifdef AXI_SHARED_LAYER_MASTER_PRIORITY_EN

      reg [`AXI_LOG2_LCL_NM-1:0] mst_priority_shared;
   `endif

   reg [`AXI_LOG2_NSP1-1:0] set_slave_priority[`AXI_NUM_SLAVES:0];
   reg [`AXI_LOG2_LCL_NM-1:0] set_master_priority[`AXI_NUM_MASTERS:0];
 `endif

   wire [`AXI_LOG2_NSP1-1:0] axi_slave_priority[`AXI_NUM_SLAVES:0];
   wire [`AXI_LOG2_NM-1:0] axi_master_priority[`AXI_NUM_MASTERS:0];
   reg [`AXI_LOG2_NSP1-1:0] axi_slave_priority_reg[`AXI_NUM_SLAVES:0];
   reg [`AXI_LOG2_NM-1:0] axi_master_priority_reg[`AXI_NUM_MASTERS:0];

   assign araddr_m[1]  = araddr_m1;
   assign arid_m[1]    = arid_m1;
   assign arlen_m[1]   = arlen_m1;
   assign arsize_m[1]  = arsize_m1;
   assign arburst_m[1] = arburst_m1;
   assign arlock_m[1]  = arlock_m1;
   assign arprot_m[1]  = arprot_m1;
   assign arcache_m[1] = arcache_m1;

   assign awaddr_m[1]  = awaddr_m1;
   assign awid_m[1]    = awid_m1;
   assign awlen_m[1]   = awlen_m1;
   assign awsize_m[1]  = awsize_m1;
   assign awburst_m[1] = awburst_m1;
   assign awlock_m[1]  = awlock_m1;
   assign awprot_m[1]  = awprot_m1;
   assign awcache_m[1] = awcache_m1;

   assign wdata_m[1] = wdata_m1;
   assign wid_m[1]   = wid_m1;
   assign wstrb_m[1] = wstrb_m1;

   assign rdata_m[1] = rdata_m1;
   assign rid_m[1]   = rid_m1;
   assign rresp_m[1] = rresp_m1;

   assign bresp_m[1] = bresp_m1;
   assign bid_m[1]   = bid_m1;

   assign arvalid_m[1] = arvalid_m_bus[0];
   assign araddr_m1    = araddr_m_bus[ ((0 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(0*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m1 = xdcdr_slv_num_rd_m_bus[ ((0 + 1) * `AXI_LOG2_NSP1) -1:(0*`AXI_LOG2_NSP1)];
   assign arlen_m1     = arlen_m_bus[  ((0 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(0*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m1    = arsize_m_bus[ ((0 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(0*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m1   = arburst_m_bus[((0 + 1) * `SVT_AXI_BURST_WIDTH)-1:(0*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m1    = arlock_m_bus[ ((0 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(0*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m1   = arcache_m_bus[((0 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(0*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m1    = arprot_m_bus[ ((0 + 1) * `SVT_AXI_PROT_WIDTH) -1:(0*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m1      = arid_m_bus[ ((0 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(0*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[0] = arready_m[1];

   assign awvalid_m[1] = awvalid_m_bus[0];
   assign awaddr_m1    = awaddr_m_bus[ ((0 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(0*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m1 = xdcdr_slv_num_wr_m_bus[ ((0 + 1) * `AXI_LOG2_NSP1) -1:(0*`AXI_LOG2_NSP1)];
   assign awlen_m1     = awlen_m_bus[  ((0 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(0*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m1    = awsize_m_bus[ ((0 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(0*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m1   = awburst_m_bus[((0 + 1) * `SVT_AXI_BURST_WIDTH)-1:(0*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m1    = awlock_m_bus[ ((0 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(0*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m1   = awcache_m_bus[((0 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(0*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m1    = awprot_m_bus[ ((0 + 1) * `SVT_AXI_PROT_WIDTH) -1:(0*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m1      = awid_m_bus[ ((0 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(0*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[0] = awready_m[1];

   assign rvalid_m_bus[0] = rvalid_m[1];
   assign rlast_m_bus[0] = rlast_m[1];
   assign rdata_m_bus[((0 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(0*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m1;
   assign rresp_m_bus[((0 + 1) * `SVT_AXI_RESP_WIDTH)-1:(0*`SVT_AXI_RESP_WIDTH)] = rresp_m1;
   assign rid_m_bus[((0 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(0*`SVT_AXI_MAX_ID_WIDTH)] = rid_m1;
   assign rready_m[1] = rready_m_bus[0];

   assign wvalid_m[1] = wvalid_m_bus[0];
   assign wlast_m[1]  = wlast_m_bus[0];
   assign wdata_m1    = wdata_m_bus[((0 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(0*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m1    = wstrb_m_bus[((0 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(0*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m1      = wid_m_bus[((0 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(0*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[0] = wready_m[1];

   assign bvalid_m_bus[0] = bvalid_m[1];
   assign bresp_m_bus[((0 + 1) * `SVT_AXI_RESP_WIDTH)-1:(0*`SVT_AXI_RESP_WIDTH)] = bresp_m1;
   assign bid_m_bus[((0 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(0*`SVT_AXI_MAX_ID_WIDTH)] = bid_m1;
   assign bready_m[1] = bready_m_bus[0];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m1 = {2{awaddr_m_bus[(0*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(0*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m1 = {8{wdata_m_bus[(0*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(0*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m1 = {2{araddr_m_bus[(0*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(0*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else
 `ifdef AXI_INC_AWSB

   assign awuser_m1 = awuser_m_bus[ ((0 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(0 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m1 = wuser_m_bus[ ((0 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(0 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m1 = aruser_m_bus[ ((0 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(0 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((0 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(0 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m1;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((0 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(0 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m1;
 `endif   
 `endif //AXI_HAS_AXI3 
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M2

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]                araddr_m2;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]                  arid_m2;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m2;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]                  arsize_m2;
   wire [`SVT_AXI_BURST_WIDTH-1:0]                 arburst_m2;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]                  arlock_m2;
   wire [`SVT_AXI_PROT_WIDTH-1:0]                  arprot_m2;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]                 arcache_m2;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]                awaddr_m2;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]                  awid_m2;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m2;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]                  awsize_m2;
   wire [`SVT_AXI_BURST_WIDTH-1:0]                 awburst_m2;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]                  awlock_m2;
   wire [`SVT_AXI_PROT_WIDTH-1:0]                  awprot_m2;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]                 awcache_m2;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]                wdata_m2;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]                  wid_m2;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]              wstrb_m2;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]                rdata_m2;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]                  rid_m2;
   wire [`SVT_AXI_RESP_WIDTH:0]                    rresp_m2;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]                  bid_m2;
   wire [`SVT_AXI_RESP_WIDTH:0]                    bresp_m2;
   assign bresp_m2[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m2;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m2;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m2;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m2;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m2;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m2;

     assign awdomain_m2   = awburst_m2;
     assign awsnoop_m2    = awprot_m2;
     assign awbar_m2      = ~awburst_m2;

     assign ardomain_m2   = arburst_m2;
     assign arsnoop_m2    = arcache_m2;
     assign arbar_m2      = ~arburst_m2;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                       xdcdr_slv_num_wr_m2;
   wire [`AXI_LOG2_NSP1-1:0]                       xdcdr_slv_num_rd_m2;

   assign xdcdr_slv_num_wr_m[2] = xdcdr_slv_num_wr_m2;
   assign xdcdr_slv_num_rd_m[2] = xdcdr_slv_num_rd_m2;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m2;
   assign arsideband_m[2] = arsideband_m2;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m2;
   assign awsideband_m[2] = awsideband_m2;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m2;
   assign rsideband_m[2] = rsideband_m2;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m2;
   assign wsideband_m[2] = wsideband_m2;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m2;
   assign bsideband_m[2] = bsideband_m2;
 `endif
`else
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m2;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m2;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m2;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m2;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m2;
 `endif  
`endif

   assign araddr_m[2]  = araddr_m2;
   assign arid_m[2]    = arid_m2;
   assign arlen_m[2]   = arlen_m2;
   assign arsize_m[2]  = arsize_m2;
   assign arburst_m[2] = arburst_m2;
   assign arlock_m[2]  = arlock_m2;
   assign arprot_m[2]  = arprot_m2;
   assign arcache_m[2] = arcache_m2;

   assign awaddr_m[2]  = awaddr_m2;
   assign awid_m[2]    = awid_m2;
   assign awlen_m[2]   = awlen_m2;
   assign awsize_m[2]  = awsize_m2;
   assign awburst_m[2] = awburst_m2;
   assign awlock_m[2]  = awlock_m2;
   assign awprot_m[2]  = awprot_m2;
   assign awcache_m[2] = awcache_m2;

   assign wdata_m[2] = wdata_m2;
   assign wid_m[2]   = wid_m2;
   assign wstrb_m[2] = wstrb_m2;

   assign rdata_m[2] = rdata_m2;
   assign rid_m[2]   = rid_m2;
   assign rresp_m[2] = rresp_m2;

   assign bresp_m[2] = bresp_m2;
   assign bid_m[2]   = bid_m2;

   assign arvalid_m[2] = arvalid_m_bus[1];
   assign araddr_m2    = araddr_m_bus[ ((1 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(1*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m2 = xdcdr_slv_num_rd_m_bus[ ((1 + 1) * `AXI_LOG2_NSP1) -1:(1*`AXI_LOG2_NSP1)];
   assign arlen_m2     = arlen_m_bus[  ((1 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(1*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m2    = arsize_m_bus[ ((1 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(1*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m2   = arburst_m_bus[((1 + 1) * `SVT_AXI_BURST_WIDTH)-1:(1*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m2    = arlock_m_bus[ ((1 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(1*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m2   = arcache_m_bus[((1 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(1*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m2    = arprot_m_bus[ ((1 + 1) * `SVT_AXI_PROT_WIDTH) -1:(1*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m2      = arid_m_bus[ ((1 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(1*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[1] = arready_m[2];

   assign awvalid_m[2] = awvalid_m_bus[1];
   assign awaddr_m2    = awaddr_m_bus[ ((1 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(1*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m2 = xdcdr_slv_num_wr_m_bus[ ((1 + 1) * `AXI_LOG2_NSP1) -1:(1*`AXI_LOG2_NSP1)];
   assign awlen_m2     = awlen_m_bus[  ((1 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(1*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m2    = awsize_m_bus[ ((1 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(1*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m2   = awburst_m_bus[((1 + 1) * `SVT_AXI_BURST_WIDTH)-1:(1*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m2    = awlock_m_bus[ ((1 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(1*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m2   = awcache_m_bus[((1 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(1*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m2    = awprot_m_bus[ ((1 + 1) * `SVT_AXI_PROT_WIDTH) -1:(1*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m2      = awid_m_bus[ ((1 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(1*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[1] = awready_m[2];

   assign rvalid_m_bus[1] = rvalid_m[2];
   assign rlast_m_bus[1] = rlast_m[2];
   assign rdata_m_bus[((1 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(1*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m2;
   assign rresp_m_bus[((1 + 1) * `SVT_AXI_RESP_WIDTH)-1:(1*`SVT_AXI_RESP_WIDTH)] = rresp_m2;
   assign rid_m_bus[((1 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(1*`SVT_AXI_MAX_ID_WIDTH)] = rid_m2;
   assign rready_m[2] = rready_m_bus[1];

   assign wvalid_m[2] = wvalid_m_bus[1];
   assign wlast_m[2]  = wlast_m_bus[1];
   assign wdata_m2    = wdata_m_bus[((1 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(1*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m2    = wstrb_m_bus[((1 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(1*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m2      = wid_m_bus[((1 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(1*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[1] = wready_m[2];

   assign bvalid_m_bus[1] = bvalid_m[2];
   assign bresp_m_bus[((1 + 1) * `SVT_AXI_RESP_WIDTH)-1:(1*`SVT_AXI_RESP_WIDTH)] = bresp_m2;
   assign bid_m_bus[((1 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(1*`SVT_AXI_MAX_ID_WIDTH)] = bid_m2;
   assign bready_m[2] = bready_m_bus[1];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m2 = {2{awaddr_m_bus[(1*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(1*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m2 = {8{wdata_m_bus[(1*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(1*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m2 = {2{araddr_m_bus[(1*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(1*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m2 = awuser_m_bus[ ((1 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(1 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m2 = wuser_m_bus[ ((1 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(1 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m2 = aruser_m_bus[ ((1 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(1 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((1 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(1 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m2;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((1 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(1 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m2;
 `endif  
`endif  //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M3

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m3;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m3;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m3;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m3;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m3;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m3;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m3;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m3;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m3;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m3;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m3;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m3;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m3;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m3;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m3;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m3;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m3;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m3;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m3;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m3;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m3;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m3;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m3;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m3;
   assign bresp_m3[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m3;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m3;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m3;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m3;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m3;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m3;

     assign awdomain_m3   = awburst_m3;
     assign awsnoop_m3    = awprot_m3;
     assign awbar_m3      = ~awburst_m3;

     assign ardomain_m3   = arburst_m3;
     assign arsnoop_m3    = arcache_m3;
     assign arbar_m3      = ~arburst_m3;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m3;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m3;

   assign xdcdr_slv_num_wr_m[3] = xdcdr_slv_num_wr_m3;
   assign xdcdr_slv_num_rd_m[3] = xdcdr_slv_num_rd_m3;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m3;
   assign arsideband_m[3] = arsideband_m3;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m3;
   assign awsideband_m[3] = awsideband_m3;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m3;
   assign rsideband_m[3] = rsideband_m3;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m3;
   assign wsideband_m[3] = wsideband_m3;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m3;
   assign bsideband_m[3] = bsideband_m3;
 `endif
`else
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m3;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m3;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m3;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m3;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m3;
 `endif  
`endif

   assign araddr_m[3]  = araddr_m3;
   assign arid_m[3]    = arid_m3;
   assign arlen_m[3]   = arlen_m3;
   assign arsize_m[3]  = arsize_m3;
   assign arburst_m[3] = arburst_m3;
   assign arlock_m[3]  = arlock_m3;
   assign arprot_m[3]  = arprot_m3;
   assign arcache_m[3] = arcache_m3;

   assign awaddr_m[3]  = awaddr_m3;
   assign awid_m[3]    = awid_m3;
   assign awlen_m[3]   = awlen_m3;
   assign awsize_m[3]  = awsize_m3;
   assign awburst_m[3] = awburst_m3;
   assign awlock_m[3]  = awlock_m3;
   assign awprot_m[3]  = awprot_m3;
   assign awcache_m[3] = awcache_m3;

   assign wdata_m[3] = wdata_m3;
   assign wid_m[3]   = wid_m3;
   assign wstrb_m[3] = wstrb_m3;

   assign rdata_m[3] = rdata_m3;
   assign rid_m[3]   = rid_m3;
   assign rresp_m[3] = rresp_m3;

   assign bresp_m[3] = bresp_m3;
   assign bid_m[3]   = bid_m3;

   assign arvalid_m[3] = arvalid_m_bus[2];
   assign araddr_m3    = araddr_m_bus[ ((2 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(2*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m3 = xdcdr_slv_num_rd_m_bus[ ((2 + 1) * `AXI_LOG2_NSP1) -1:(2*`AXI_LOG2_NSP1)];
   assign arlen_m3     = arlen_m_bus[  ((2 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(2*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m3    = arsize_m_bus[ ((2 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(2*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m3   = arburst_m_bus[((2 + 1) * `SVT_AXI_BURST_WIDTH)-1:(2*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m3    = arlock_m_bus[ ((2 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(2*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m3   = arcache_m_bus[((2 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(2*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m3    = arprot_m_bus[ ((2 + 1) * `SVT_AXI_PROT_WIDTH) -1:(2*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m3      = arid_m_bus[ ((2 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(2*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[2] = arready_m[3];

   assign awvalid_m[3] = awvalid_m_bus[2];
   assign awaddr_m3    = awaddr_m_bus[ ((2 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(2*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m3 = xdcdr_slv_num_wr_m_bus[ ((2 + 1) * `AXI_LOG2_NSP1) -1:(2*`AXI_LOG2_NSP1)];
   assign awlen_m3     = awlen_m_bus[  ((2 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(2*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m3    = awsize_m_bus[ ((2 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(2*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m3   = awburst_m_bus[((2 + 1) * `SVT_AXI_BURST_WIDTH)-1:(2*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m3    = awlock_m_bus[ ((2 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(2*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m3   = awcache_m_bus[((2 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(2*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m3    = awprot_m_bus[ ((2 + 1) * `SVT_AXI_PROT_WIDTH) -1:(2*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m3      = awid_m_bus[ ((2 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(2*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[2] = awready_m[3];

   assign rvalid_m_bus[2] = rvalid_m[3];
   assign rlast_m_bus[2] = rlast_m[3];
   assign rdata_m_bus[((2 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(2*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m3;
   assign rresp_m_bus[((2 + 1) * `SVT_AXI_RESP_WIDTH)-1:(2*`SVT_AXI_RESP_WIDTH)] = rresp_m3;
   assign rid_m_bus[((2 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(2*`SVT_AXI_MAX_ID_WIDTH)] = rid_m3;
   assign rready_m[3] = rready_m_bus[2];

   assign wvalid_m[3] = wvalid_m_bus[2];
   assign wlast_m[3]  = wlast_m_bus[2];
   assign wdata_m3    = wdata_m_bus[((2 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(2*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m3    = wstrb_m_bus[((2 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(2*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m3      = wid_m_bus[((2 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(2*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[2] = wready_m[3];

   assign bvalid_m_bus[2] = bvalid_m[3];
   assign bresp_m_bus[((2 + 1) * `SVT_AXI_RESP_WIDTH)-1:(2*`SVT_AXI_RESP_WIDTH)] = bresp_m3;
   assign bid_m_bus[((2 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(2*`SVT_AXI_MAX_ID_WIDTH)] = bid_m3;
   assign bready_m[3] = bready_m_bus[2];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m3 = {2{awaddr_m_bus[(2*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(2*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m3 = {8{wdata_m_bus[(2*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(2*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m3 = {2{araddr_m_bus[(2*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(2*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m3 = awuser_m_bus[ ((2 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(2 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m3 = wuser_m_bus[ ((2 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(2 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m3 = aruser_m_bus[ ((2 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(2 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((2 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(2 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m3;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((2 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(2 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m3;
 `endif  
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M4

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m4;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m4;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m4;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m4;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m4;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m4;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m4;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m4;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m4;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m4;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m4;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m4;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m4;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m4;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m4;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m4;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m4;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m4;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m4;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m4;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m4;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m4;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m4;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m4;
   assign bresp_m4[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m4;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m4;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m4;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m4;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m4;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m4;

     assign awdomain_m4   = awburst_m4;
     assign awsnoop_m4    = awprot_m4;
     assign awbar_m4      = ~awburst_m4;

     assign ardomain_m4   = arburst_m4;
     assign arsnoop_m4    = arcache_m4;
     assign arbar_m4      = ~arburst_m4;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m4;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m4;

   assign xdcdr_slv_num_wr_m[4] = xdcdr_slv_num_wr_m4;
   assign xdcdr_slv_num_rd_m[4] = xdcdr_slv_num_rd_m4;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m4;
   assign arsideband_m[4] = arsideband_m4;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m4;
   assign awsideband_m[4] = awsideband_m4;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m4;
   assign rsideband_m[4] = rsideband_m4;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m4;
   assign wsideband_m[4] = wsideband_m4;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m4;
   assign bsideband_m[4] = bsideband_m4;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m4;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m4;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m4;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m4;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m4;
 `endif  
`endif

   assign araddr_m[4]  = araddr_m4;
   assign arid_m[4]    = arid_m4;
   assign arlen_m[4]   = arlen_m4;
   assign arsize_m[4]  = arsize_m4;
   assign arburst_m[4] = arburst_m4;
   assign arlock_m[4]  = arlock_m4;
   assign arprot_m[4]  = arprot_m4;
   assign arcache_m[4] = arcache_m4;

   assign awaddr_m[4]  = awaddr_m4;
   assign awid_m[4]    = awid_m4;
   assign awlen_m[4]   = awlen_m4;
   assign awsize_m[4]  = awsize_m4;
   assign awburst_m[4] = awburst_m4;
   assign awlock_m[4]  = awlock_m4;
   assign awprot_m[4]  = awprot_m4;
   assign awcache_m[4] = awcache_m4;

   assign wdata_m[4] = wdata_m4;
   assign wid_m[4]   = wid_m4;
   assign wstrb_m[4] = wstrb_m4;

   assign rdata_m[4] = rdata_m4;
   assign rid_m[4]   = rid_m4;
   assign rresp_m[4] = rresp_m4;

   assign bresp_m[4] = bresp_m4;
   assign bid_m[4]   = bid_m4;

   assign arvalid_m[4] = arvalid_m_bus[3];
   assign araddr_m4    = araddr_m_bus[ ((3 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(3*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m4 = xdcdr_slv_num_rd_m_bus[ ((3 + 1) * `AXI_LOG2_NSP1) -1:(3*`AXI_LOG2_NSP1)];
   assign arlen_m4     = arlen_m_bus[  ((3 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(3*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m4    = arsize_m_bus[ ((3 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(3*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m4   = arburst_m_bus[((3 + 1) * `SVT_AXI_BURST_WIDTH)-1:(3*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m4    = arlock_m_bus[ ((3 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(3*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m4   = arcache_m_bus[((3 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(3*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m4    = arprot_m_bus[ ((3 + 1) * `SVT_AXI_PROT_WIDTH) -1:(3*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m4      = arid_m_bus[ ((3 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(3*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[3] = arready_m[4];

   assign awvalid_m[4] = awvalid_m_bus[3];
   assign awaddr_m4    = awaddr_m_bus[ ((3 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(3*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m4 = xdcdr_slv_num_wr_m_bus[ ((3 + 1) * `AXI_LOG2_NSP1) -1:(3*`AXI_LOG2_NSP1)];
   assign awlen_m4     = awlen_m_bus[  ((3 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(3*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m4    = awsize_m_bus[ ((3 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(3*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m4   = awburst_m_bus[((3 + 1) * `SVT_AXI_BURST_WIDTH)-1:(3*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m4    = awlock_m_bus[ ((3 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(3*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m4   = awcache_m_bus[((3 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(3*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m4    = awprot_m_bus[ ((3 + 1) * `SVT_AXI_PROT_WIDTH) -1:(3*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m4      = awid_m_bus[ ((3 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(3*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[3] = awready_m[4];

   assign rvalid_m_bus[3] = rvalid_m[4];
   assign rlast_m_bus[3] = rlast_m[4];
   assign rdata_m_bus[((3 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(3*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m4;
   assign rresp_m_bus[((3 + 1) * `SVT_AXI_RESP_WIDTH)-1:(3*`SVT_AXI_RESP_WIDTH)] = rresp_m4;
   assign rid_m_bus[((3 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(3*`SVT_AXI_MAX_ID_WIDTH)] = rid_m4;
   assign rready_m[4] = rready_m_bus[3];

   assign wvalid_m[4] = wvalid_m_bus[3];
   assign wlast_m[4]  = wlast_m_bus[3];
   assign wdata_m4    = wdata_m_bus[((3 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(3*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m4    = wstrb_m_bus[((3 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(3*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m4      = wid_m_bus[((3 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(3*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[3] = wready_m[4];

   assign bvalid_m_bus[3] = bvalid_m[4];
   assign bresp_m_bus[((3 + 1) * `SVT_AXI_RESP_WIDTH)-1:(3*`SVT_AXI_RESP_WIDTH)] = bresp_m4;
   assign bid_m_bus[((3 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(3*`SVT_AXI_MAX_ID_WIDTH)] = bid_m4;
   assign bready_m[4] = bready_m_bus[3];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m4 = {2{awaddr_m_bus[(3*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(3*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m4 = {8{wdata_m_bus[(3*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(3*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m4 = {2{araddr_m_bus[(3*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(3*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m4 = awuser_m_bus[ ((3 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(3 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m4 = wuser_m_bus[ ((3 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(3 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m4 = aruser_m_bus[ ((3 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(3 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((3 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(3 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m4;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((3 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(3 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m4;
 `endif  
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M5

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m5;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m5;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m5;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m5;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m5;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m5;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m5;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m5;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m5;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m5;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m5;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m5;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m5;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m5;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m5;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m5;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m5;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m5;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m5;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m5;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m5;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m5;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m5;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m5;
   assign bresp_m5[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m5;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m5;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m5;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m5;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m5;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m5;

     assign awdomain_m5   = awburst_m5;
     assign awsnoop_m5    = awprot_m5;
     assign awbar_m5      = ~awburst_m5;

     assign ardomain_m5   = arburst_m5;
     assign arsnoop_m5    = arcache_m5;
     assign arbar_m5      = ~arburst_m5;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m5;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m5;

   assign xdcdr_slv_num_wr_m[5] = xdcdr_slv_num_wr_m5;
   assign xdcdr_slv_num_rd_m[5] = xdcdr_slv_num_rd_m5;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m5;
   assign arsideband_m[5] = arsideband_m5;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m5;
   assign awsideband_m[5] = awsideband_m5;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m5;
   assign rsideband_m[5] = rsideband_m5;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m5;
   assign wsideband_m[5] = wsideband_m5;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m5;
   assign bsideband_m[5] = bsideband_m5;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m5;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m5;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m5;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m5;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m5;
 `endif  
`endif

   assign araddr_m[5]  = araddr_m5;
   assign arid_m[5]    = arid_m5;
   assign arlen_m[5]   = arlen_m5;
   assign arsize_m[5]  = arsize_m5;
   assign arburst_m[5] = arburst_m5;
   assign arlock_m[5]  = arlock_m5;
   assign arprot_m[5]  = arprot_m5;
   assign arcache_m[5] = arcache_m5;

   assign awaddr_m[5]  = awaddr_m5;
   assign awid_m[5]    = awid_m5;
   assign awlen_m[5]   = awlen_m5;
   assign awsize_m[5]  = awsize_m5;
   assign awburst_m[5] = awburst_m5;
   assign awlock_m[5]  = awlock_m5;
   assign awprot_m[5]  = awprot_m5;
   assign awcache_m[5] = awcache_m5;

   assign wdata_m[5] = wdata_m5;
   assign wid_m[5]   = wid_m5;
   assign wstrb_m[5] = wstrb_m5;

   assign rdata_m[5] = rdata_m5;
   assign rid_m[5]   = rid_m5;
   assign rresp_m[5] = rresp_m5;

   assign bresp_m[5] = bresp_m5;
   assign bid_m[5]   = bid_m5;

   assign arvalid_m[5] = arvalid_m_bus[4];
   assign araddr_m5    = araddr_m_bus[ ((4 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(4*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m5 = xdcdr_slv_num_rd_m_bus[ ((4 + 1) * `AXI_LOG2_NSP1) -1:(4*`AXI_LOG2_NSP1)];
   assign arlen_m5     = arlen_m_bus[  ((4 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(4*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m5    = arsize_m_bus[ ((4 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(4*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m5   = arburst_m_bus[((4 + 1) * `SVT_AXI_BURST_WIDTH)-1:(4*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m5    = arlock_m_bus[ ((4 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(4*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m5   = arcache_m_bus[((4 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(4*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m5    = arprot_m_bus[ ((4 + 1) * `SVT_AXI_PROT_WIDTH) -1:(4*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m5      = arid_m_bus[ ((4 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(4*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[4] = arready_m[5];

   assign awvalid_m[5] = awvalid_m_bus[4];
   assign awaddr_m5    = awaddr_m_bus[ ((4 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(4*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m5 = xdcdr_slv_num_wr_m_bus[ ((4 + 1) * `AXI_LOG2_NSP1) -1:(4*`AXI_LOG2_NSP1)];
   assign awlen_m5     = awlen_m_bus[  ((4 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(4*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m5    = awsize_m_bus[ ((4 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(4*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m5   = awburst_m_bus[((4 + 1) * `SVT_AXI_BURST_WIDTH)-1:(4*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m5    = awlock_m_bus[ ((4 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(4*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m5   = awcache_m_bus[((4 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(4*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m5    = awprot_m_bus[ ((4 + 1) * `SVT_AXI_PROT_WIDTH) -1:(4*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m5      = awid_m_bus[ ((4 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(4*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[4] = awready_m[5];

   assign rvalid_m_bus[4] = rvalid_m[5];
   assign rlast_m_bus[4] = rlast_m[5];
   assign rdata_m_bus[((4 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(4*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m5;
   assign rresp_m_bus[((4 + 1) * `SVT_AXI_RESP_WIDTH)-1:(4*`SVT_AXI_RESP_WIDTH)] = rresp_m5;
   assign rid_m_bus[((4 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(4*`SVT_AXI_MAX_ID_WIDTH)] = rid_m5;
   assign rready_m[5] = rready_m_bus[4];

   assign wvalid_m[5] = wvalid_m_bus[4];
   assign wlast_m[5]  = wlast_m_bus[4];
   assign wdata_m5    = wdata_m_bus[((4 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(4*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m5    = wstrb_m_bus[((4 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(4*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m5      = wid_m_bus[((4 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(4*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[4] = wready_m[5];

   assign bvalid_m_bus[4] = bvalid_m[5];
   assign bresp_m_bus[((4 + 1) * `SVT_AXI_RESP_WIDTH)-1:(4*`SVT_AXI_RESP_WIDTH)] = bresp_m5;
   assign bid_m_bus[((4 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(4*`SVT_AXI_MAX_ID_WIDTH)] = bid_m5;
   assign bready_m[5] = bready_m_bus[4];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m5 = {2{awaddr_m_bus[(4*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(4*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m5 = {8{wdata_m_bus[(4*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(4*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m5 = {2{araddr_m_bus[(4*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(4*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m5 = awuser_m_bus[ ((4 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(4 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m5 = wuser_m_bus[ ((4 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(4 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m5 = aruser_m_bus[ ((4 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(4 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((4 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(4 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m5;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((4 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(4 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m5;
 `endif  
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M6

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m6;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m6;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m6;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m6;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m6;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m6;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m6;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m6;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m6;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m6;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m6;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m6;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m6;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m6;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m6;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m6;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m6;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m6;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m6;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m6;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m6;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m6;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m6;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m6;
   assign bresp_m6[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m6;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m6;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m6;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m6;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m6;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m6;

     assign awdomain_m6   = awburst_m6;
     assign awsnoop_m6    = awprot_m6;
     assign awbar_m6      = ~awburst_m6;

     assign ardomain_m6   = arburst_m6;
     assign arsnoop_m6    = arcache_m6;
     assign arbar_m6      = ~arburst_m6;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m6;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m6;

   assign xdcdr_slv_num_wr_m[6] = xdcdr_slv_num_wr_m6;
   assign xdcdr_slv_num_rd_m[6] = xdcdr_slv_num_rd_m6;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m6;
   assign arsideband_m[6] = arsideband_m6;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m6;
   assign awsideband_m[6] = awsideband_m6;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m6;
   assign rsideband_m[6] = rsideband_m6;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m6;
   assign wsideband_m[6] = wsideband_m6;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m6;
   assign bsideband_m[6] = bsideband_m6;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m6;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m6;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m6;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m6;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m6;
 `endif  
`endif

   assign araddr_m[6]  = araddr_m6;
   assign arid_m[6]    = arid_m6;
   assign arlen_m[6]   = arlen_m6;
   assign arsize_m[6]  = arsize_m6;
   assign arburst_m[6] = arburst_m6;
   assign arlock_m[6]  = arlock_m6;
   assign arprot_m[6]  = arprot_m6;
   assign arcache_m[6] = arcache_m6;

   assign awaddr_m[6]  = awaddr_m6;
   assign awid_m[6]    = awid_m6;
   assign awlen_m[6]   = awlen_m6;
   assign awsize_m[6]  = awsize_m6;
   assign awburst_m[6] = awburst_m6;
   assign awlock_m[6]  = awlock_m6;
   assign awprot_m[6]  = awprot_m6;
   assign awcache_m[6] = awcache_m6;

   assign wdata_m[6] = wdata_m6;
   assign wid_m[6]   = wid_m6;
   assign wstrb_m[6] = wstrb_m6;

   assign rdata_m[6] = rdata_m6;
   assign rid_m[6]   = rid_m6;
   assign rresp_m[6] = rresp_m6;

   assign bresp_m[6] = bresp_m6;
   assign bid_m[6]   = bid_m6;

   assign arvalid_m[6] = arvalid_m_bus[5];
   assign araddr_m6    = araddr_m_bus[ ((5 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(5*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m6 = xdcdr_slv_num_rd_m_bus[ ((5 + 1) * `AXI_LOG2_NSP1) -1:(5*`AXI_LOG2_NSP1)];
   assign arlen_m6     = arlen_m_bus[  ((5 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(5*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m6    = arsize_m_bus[ ((5 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(5*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m6   = arburst_m_bus[((5 + 1) * `SVT_AXI_BURST_WIDTH)-1:(5*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m6    = arlock_m_bus[ ((5 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(5*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m6   = arcache_m_bus[((5 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(5*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m6    = arprot_m_bus[ ((5 + 1) * `SVT_AXI_PROT_WIDTH) -1:(5*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m6      = arid_m_bus[ ((5 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(5*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[5] = arready_m[6];

   assign awvalid_m[6] = awvalid_m_bus[5];
   assign awaddr_m6    = awaddr_m_bus[ ((5 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(5*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m6 = xdcdr_slv_num_wr_m_bus[ ((5 + 1) * `AXI_LOG2_NSP1) -1:(5*`AXI_LOG2_NSP1)];
   assign awlen_m6     = awlen_m_bus[  ((5 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(5*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m6    = awsize_m_bus[ ((5 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(5*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m6   = awburst_m_bus[((5 + 1) * `SVT_AXI_BURST_WIDTH)-1:(5*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m6    = awlock_m_bus[ ((5 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(5*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m6   = awcache_m_bus[((5 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(5*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m6    = awprot_m_bus[ ((5 + 1) * `SVT_AXI_PROT_WIDTH) -1:(5*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m6      = awid_m_bus[ ((5 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(5*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[5] = awready_m[6];

   assign rvalid_m_bus[5] = rvalid_m[6];
   assign rlast_m_bus[5] = rlast_m[6];
   assign rdata_m_bus[((5 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(5*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m6;
   assign rresp_m_bus[((5 + 1) * `SVT_AXI_RESP_WIDTH)-1:(5*`SVT_AXI_RESP_WIDTH)] = rresp_m6;
   assign rid_m_bus[((5 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(5*`SVT_AXI_MAX_ID_WIDTH)] = rid_m6;
   assign rready_m[6] = rready_m_bus[5];

   assign wvalid_m[6] = wvalid_m_bus[5];
   assign wlast_m[6]  = wlast_m_bus[5];
   assign wdata_m6    = wdata_m_bus[((5 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(5*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m6    = wstrb_m_bus[((5 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(5*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m6      = wid_m_bus[((5 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(5*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[5] = wready_m[6];

   assign bvalid_m_bus[5] = bvalid_m[6];
   assign bresp_m_bus[((5 + 1) * `SVT_AXI_RESP_WIDTH)-1:(5*`SVT_AXI_RESP_WIDTH)] = bresp_m6;
   assign bid_m_bus[((5 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(5*`SVT_AXI_MAX_ID_WIDTH)] = bid_m6;
   assign bready_m[6] = bready_m_bus[5];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m6 = {2{awaddr_m_bus[(5*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(5*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m6 = {8{wdata_m_bus[(5*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(5*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m6 = {2{araddr_m_bus[(5*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(5*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m6 = awuser_m_bus[ ((5 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(5 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m6 = wuser_m_bus[ ((5 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(5 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m6 = aruser_m_bus[ ((5 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(5 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((5 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(5 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m6;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((5 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(5 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m6;
 `endif  
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M7

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m7;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m7;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m7;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m7;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m7;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m7;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m7;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m7;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m7;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m7;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m7;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m7;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m7;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m7;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m7;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m7;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m7;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m7;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m7;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m7;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m7;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m7;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m7;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m7;
   assign bresp_m7[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m7;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m7;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m7;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m7;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m7;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m7;

     assign awdomain_m7   = awburst_m7;
     assign awsnoop_m7    = awprot_m7;
     assign awbar_m7      = ~awburst_m7;

     assign ardomain_m7   = arburst_m7;
     assign arsnoop_m7    = arcache_m7;
     assign arbar_m7      = ~arburst_m7;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m7;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m7;

   assign xdcdr_slv_num_wr_m[7] = xdcdr_slv_num_wr_m7;
   assign xdcdr_slv_num_rd_m[7] = xdcdr_slv_num_rd_m7;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m7;
   assign arsideband_m[7] = arsideband_m7;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m7;
   assign awsideband_m[7] = awsideband_m7;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m7;
   assign rsideband_m[7] = rsideband_m7;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m7;
   assign wsideband_m[7] = wsideband_m7;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m7;
   assign bsideband_m[7] = bsideband_m7;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m7;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m7;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m7;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m7;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m7;
 `endif  
`endif 

   assign araddr_m[7]  = araddr_m7;
   assign arid_m[7]    = arid_m7;
   assign arlen_m[7]   = arlen_m7;
   assign arsize_m[7]  = arsize_m7;
   assign arburst_m[7] = arburst_m7;
   assign arlock_m[7]  = arlock_m7;
   assign arprot_m[7]  = arprot_m7;
   assign arcache_m[7] = arcache_m7;

   assign awaddr_m[7]  = awaddr_m7;
   assign awid_m[7]    = awid_m7;
   assign awlen_m[7]   = awlen_m7;
   assign awsize_m[7]  = awsize_m7;
   assign awburst_m[7] = awburst_m7;
   assign awlock_m[7]  = awlock_m7;
   assign awprot_m[7]  = awprot_m7;
   assign awcache_m[7] = awcache_m7;

   assign wdata_m[7] = wdata_m7;
   assign wid_m[7]   = wid_m7;
   assign wstrb_m[7] = wstrb_m7;

   assign rdata_m[7] = rdata_m7;
   assign rid_m[7]   = rid_m7;
   assign rresp_m[7] = rresp_m7;

   assign bresp_m[7] = bresp_m7;
   assign bid_m[7]   = bid_m7;

   assign arvalid_m[7] = arvalid_m_bus[6];
   assign araddr_m7    = araddr_m_bus[ ((6 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(6*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m7 = xdcdr_slv_num_rd_m_bus[ ((6 + 1) * `AXI_LOG2_NSP1) -1:(6*`AXI_LOG2_NSP1)];
   assign arlen_m7     = arlen_m_bus[  ((6 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(6*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m7    = arsize_m_bus[ ((6 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(6*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m7   = arburst_m_bus[((6 + 1) * `SVT_AXI_BURST_WIDTH)-1:(6*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m7    = arlock_m_bus[ ((6 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(6*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m7   = arcache_m_bus[((6 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(6*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m7    = arprot_m_bus[ ((6 + 1) * `SVT_AXI_PROT_WIDTH) -1:(6*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m7      = arid_m_bus[ ((6 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(6*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[6] = arready_m[7];

   assign awvalid_m[7] = awvalid_m_bus[6];
   assign awaddr_m7    = awaddr_m_bus[ ((6 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(6*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m7 = xdcdr_slv_num_wr_m_bus[ ((6 + 1) * `AXI_LOG2_NSP1) -1:(6*`AXI_LOG2_NSP1)];
   assign awlen_m7     = awlen_m_bus[  ((6 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(6*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m7    = awsize_m_bus[ ((6 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(6*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m7   = awburst_m_bus[((6 + 1) * `SVT_AXI_BURST_WIDTH)-1:(6*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m7    = awlock_m_bus[ ((6 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(6*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m7   = awcache_m_bus[((6 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(6*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m7    = awprot_m_bus[ ((6 + 1) * `SVT_AXI_PROT_WIDTH) -1:(6*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m7      = awid_m_bus[ ((6 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(6*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[6] = awready_m[7];

   assign rvalid_m_bus[6] = rvalid_m[7];
   assign rlast_m_bus[6] = rlast_m[7];
   assign rdata_m_bus[((6 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(6*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m7;
   assign rresp_m_bus[((6 + 1) * `SVT_AXI_RESP_WIDTH)-1:(6*`SVT_AXI_RESP_WIDTH)] = rresp_m7;
   assign rid_m_bus[((6 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(6*`SVT_AXI_MAX_ID_WIDTH)] = rid_m7;
   assign rready_m[7] = rready_m_bus[6];

   assign wvalid_m[7] = wvalid_m_bus[6];
   assign wlast_m[7]  = wlast_m_bus[6];
   assign wdata_m7    = wdata_m_bus[((6 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(6*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m7    = wstrb_m_bus[((6 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(6*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m7      = wid_m_bus[((6 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(6*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[6] = wready_m[7];

   assign bvalid_m_bus[6] = bvalid_m[7];
   assign bresp_m_bus[((6 + 1) * `SVT_AXI_RESP_WIDTH)-1:(6*`SVT_AXI_RESP_WIDTH)] = bresp_m7;
   assign bid_m_bus[((6 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(6*`SVT_AXI_MAX_ID_WIDTH)] = bid_m7;
   assign bready_m[7] = bready_m_bus[6];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m7 = {2{awaddr_m_bus[(6*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(6*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m7 = {8{wdata_m_bus[(6*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(6*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m7 = {2{araddr_m_bus[(6*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(6*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m7 = awuser_m_bus[ ((6 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(6 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m7 = wuser_m_bus[ ((6 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(6 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m7 = aruser_m_bus[ ((6 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(6 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((6 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(6 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m7;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((6 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(6 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m7;
 `endif  
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M8

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m8;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m8;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m8;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m8;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m8;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m8;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m8;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m8;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m8;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m8;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m8;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m8;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m8;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m8;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m8;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m8;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m8;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m8;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m8;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m8;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m8;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m8;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m8;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m8;
   assign bresp_m8[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m8;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m8;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m8;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m8;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m8;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m8;

     assign awdomain_m8   = awburst_m8;
     assign awsnoop_m8    = awprot_m8;
     assign awbar_m8      = ~awburst_m8;

     assign ardomain_m8   = arburst_m8;
     assign arsnoop_m8    = arcache_m8;
     assign arbar_m8      = ~arburst_m8;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m8;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m8;

   assign xdcdr_slv_num_wr_m[8] = xdcdr_slv_num_wr_m8;
   assign xdcdr_slv_num_rd_m[8] = xdcdr_slv_num_rd_m8;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m8;
   assign arsideband_m[8] = arsideband_m8;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m8;
   assign awsideband_m[8] = awsideband_m8;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m8;
   assign rsideband_m[8] = rsideband_m8;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m8;
   assign wsideband_m[8] = wsideband_m8;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m8;
   assign bsideband_m[8] = bsideband_m8;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m8;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m8;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m8;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m8;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m8;
 `endif  
`endif 

   assign araddr_m[8]  = araddr_m8;
   assign arid_m[8]    = arid_m8;
   assign arlen_m[8]   = arlen_m8;
   assign arsize_m[8]  = arsize_m8;
   assign arburst_m[8] = arburst_m8;
   assign arlock_m[8]  = arlock_m8;
   assign arprot_m[8]  = arprot_m8;
   assign arcache_m[8] = arcache_m8;

   assign awaddr_m[8]  = awaddr_m8;
   assign awid_m[8]    = awid_m8;
   assign awlen_m[8]   = awlen_m8;
   assign awsize_m[8]  = awsize_m8;
   assign awburst_m[8] = awburst_m8;
   assign awlock_m[8]  = awlock_m8;
   assign awprot_m[8]  = awprot_m8;
   assign awcache_m[8] = awcache_m8;

   assign wdata_m[8] = wdata_m8;
   assign wid_m[8]   = wid_m8;
   assign wstrb_m[8] = wstrb_m8;

   assign rdata_m[8] = rdata_m8;
   assign rid_m[8]   = rid_m8;
   assign rresp_m[8] = rresp_m8;

   assign bresp_m[8] = bresp_m8;
   assign bid_m[8]   = bid_m8;

   assign arvalid_m[8] = arvalid_m_bus[7];
   assign araddr_m8    = araddr_m_bus[ ((7 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(7*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m8 = xdcdr_slv_num_rd_m_bus[ ((7 + 1) * `AXI_LOG2_NSP1) -1:(7*`AXI_LOG2_NSP1)];
   assign arlen_m8     = arlen_m_bus[  ((7 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(7*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m8    = arsize_m_bus[ ((7 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(7*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m8   = arburst_m_bus[((7 + 1) * `SVT_AXI_BURST_WIDTH)-1:(7*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m8    = arlock_m_bus[ ((7 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(7*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m8   = arcache_m_bus[((7 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(7*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m8    = arprot_m_bus[ ((7 + 1) * `SVT_AXI_PROT_WIDTH) -1:(7*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m8      = arid_m_bus[ ((7 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(7*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[7] = arready_m[8];

   assign awvalid_m[8] = awvalid_m_bus[7];
   assign awaddr_m8    = awaddr_m_bus[ ((7 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(7*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m8 = xdcdr_slv_num_wr_m_bus[ ((7 + 1) * `AXI_LOG2_NSP1) -1:(7*`AXI_LOG2_NSP1)];
   assign awlen_m8     = awlen_m_bus[  ((7 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(7*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m8    = awsize_m_bus[ ((7 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(7*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m8   = awburst_m_bus[((7 + 1) * `SVT_AXI_BURST_WIDTH)-1:(7*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m8    = awlock_m_bus[ ((7 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(7*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m8   = awcache_m_bus[((7 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(7*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m8    = awprot_m_bus[ ((7 + 1) * `SVT_AXI_PROT_WIDTH) -1:(7*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m8      = awid_m_bus[ ((7 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(7*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[7] = awready_m[8];

   assign rvalid_m_bus[7] = rvalid_m[8];
   assign rlast_m_bus[7] = rlast_m[8];
   assign rdata_m_bus[((7 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(7*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m8;
   assign rresp_m_bus[((7 + 1) * `SVT_AXI_RESP_WIDTH)-1:(7*`SVT_AXI_RESP_WIDTH)] = rresp_m8;
   assign rid_m_bus[((7 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(7*`SVT_AXI_MAX_ID_WIDTH)] = rid_m8;
   assign rready_m[8] = rready_m_bus[7];

   assign wvalid_m[8] = wvalid_m_bus[7];
   assign wlast_m[8]  = wlast_m_bus[7];
   assign wdata_m8    = wdata_m_bus[((7 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(7*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m8    = wstrb_m_bus[((7 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(7*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m8      = wid_m_bus[((7 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(7*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[7] = wready_m[8];

   assign bvalid_m_bus[7] = bvalid_m[8];
   assign bresp_m_bus[((7 + 1) * `SVT_AXI_RESP_WIDTH)-1:(7*`SVT_AXI_RESP_WIDTH)] = bresp_m8;
   assign bid_m_bus[((7 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(7*`SVT_AXI_MAX_ID_WIDTH)] = bid_m8;
   assign bready_m[8] = bready_m_bus[7];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m8 = {2{awaddr_m_bus[(7*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(7*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m8 = {8{wdata_m_bus[(7*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(7*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m8 = {2{araddr_m_bus[(7*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(7*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m8 = awuser_m_bus[ ((7 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(7 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m8 = wuser_m_bus[ ((7 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(7 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m8 = aruser_m_bus[ ((7 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(7 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((7 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(7 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m8;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((7 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(7 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m8;
 `endif  
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M9

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m9;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m9;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m9;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m9;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m9;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m9;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m9;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m9;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m9;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m9;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m9;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m9;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m9;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m9;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m9;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m9;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m9;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m9;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m9;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m9;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m9;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m9;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m9;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m9;
   assign bresp_m9[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m9;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m9;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m9;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m9;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m9;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m9;

     assign awdomain_m9   = awburst_m9;
     assign awsnoop_m9    = awprot_m9;
     assign awbar_m9      = ~awburst_m9;

     assign ardomain_m9   = arburst_m9;
     assign arsnoop_m9    = arcache_m9;
     assign arbar_m9      = ~arburst_m9;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m9;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m9;

   assign xdcdr_slv_num_wr_m[9] = xdcdr_slv_num_wr_m9;
   assign xdcdr_slv_num_rd_m[9] = xdcdr_slv_num_rd_m9;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m9;
   assign arsideband_m[9] = arsideband_m9;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m9;
   assign awsideband_m[9] = awsideband_m9;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m9;
   assign rsideband_m[9] = rsideband_m9;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m9;
   assign wsideband_m[9] = wsideband_m9;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m9;
   assign bsideband_m[9] = bsideband_m9;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m9;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m9;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m9;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m9;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m9;
 `endif  
`endif 

   assign araddr_m[9]  = araddr_m9;
   assign arid_m[9]    = arid_m9;
   assign arlen_m[9]   = arlen_m9;
   assign arsize_m[9]  = arsize_m9;
   assign arburst_m[9] = arburst_m9;
   assign arlock_m[9]  = arlock_m9;
   assign arprot_m[9]  = arprot_m9;
   assign arcache_m[9] = arcache_m9;

   assign awaddr_m[9]  = awaddr_m9;
   assign awid_m[9]    = awid_m9;
   assign awlen_m[9]   = awlen_m9;
   assign awsize_m[9]  = awsize_m9;
   assign awburst_m[9] = awburst_m9;
   assign awlock_m[9]  = awlock_m9;
   assign awprot_m[9]  = awprot_m9;
   assign awcache_m[9] = awcache_m9;

   assign wdata_m[9] = wdata_m9;
   assign wid_m[9]   = wid_m9;
   assign wstrb_m[9] = wstrb_m9;

   assign rdata_m[9] = rdata_m9;
   assign rid_m[9]   = rid_m9;
   assign rresp_m[9] = rresp_m9;

   assign bresp_m[9] = bresp_m9;
   assign bid_m[9]   = bid_m9;

   assign arvalid_m[9] = arvalid_m_bus[8];
   assign araddr_m9    = araddr_m_bus[ ((8 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(8*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m9 = xdcdr_slv_num_rd_m_bus[ ((8 + 1) * `AXI_LOG2_NSP1) -1:(8*`AXI_LOG2_NSP1)];
   assign arlen_m9     = arlen_m_bus[  ((8 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(8*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m9    = arsize_m_bus[ ((8 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(8*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m9   = arburst_m_bus[((8 + 1) * `SVT_AXI_BURST_WIDTH)-1:(8*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m9    = arlock_m_bus[ ((8 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(8*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m9   = arcache_m_bus[((8 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(8*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m9    = arprot_m_bus[ ((8 + 1) * `SVT_AXI_PROT_WIDTH) -1:(8*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m9      = arid_m_bus[ ((8 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(8*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[8] = arready_m[9];

   assign awvalid_m[9] = awvalid_m_bus[8];
   assign awaddr_m9    = awaddr_m_bus[ ((8 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(8*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m9 = xdcdr_slv_num_wr_m_bus[ ((8 + 1) * `AXI_LOG2_NSP1) -1:(8*`AXI_LOG2_NSP1)];
   assign awlen_m9     = awlen_m_bus[  ((8 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(8*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m9    = awsize_m_bus[ ((8 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(8*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m9   = awburst_m_bus[((8 + 1) * `SVT_AXI_BURST_WIDTH)-1:(8*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m9    = awlock_m_bus[ ((8 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(8*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m9   = awcache_m_bus[((8 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(8*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m9    = awprot_m_bus[ ((8 + 1) * `SVT_AXI_PROT_WIDTH) -1:(8*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m9      = awid_m_bus[ ((8 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(8*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[8] = awready_m[9];

   assign rvalid_m_bus[8] = rvalid_m[9];
   assign rlast_m_bus[8] = rlast_m[9];
   assign rdata_m_bus[((8 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(8*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m9;
   assign rresp_m_bus[((8 + 1) * `SVT_AXI_RESP_WIDTH)-1:(8*`SVT_AXI_RESP_WIDTH)] = rresp_m9;
   assign rid_m_bus[((8 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(8*`SVT_AXI_MAX_ID_WIDTH)] = rid_m9;
   assign rready_m[9] = rready_m_bus[8];

   assign wvalid_m[9] = wvalid_m_bus[8];
   assign wlast_m[9]  = wlast_m_bus[8];
   assign wdata_m9    = wdata_m_bus[((8 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(8*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m9    = wstrb_m_bus[((8 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(8*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m9      = wid_m_bus[((8 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(8*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[8] = wready_m[9];

   assign bvalid_m_bus[8] = bvalid_m[9];
   assign bresp_m_bus[((8 + 1) * `SVT_AXI_RESP_WIDTH)-1:(8*`SVT_AXI_RESP_WIDTH)] = bresp_m9;
   assign bid_m_bus[((8 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(8*`SVT_AXI_MAX_ID_WIDTH)] = bid_m9;
   assign bready_m[9] = bready_m_bus[8];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m9 = {2{awaddr_m_bus[(8*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(8*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m9 = {8{wdata_m_bus[(8*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(8*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m9 = {2{araddr_m_bus[(8*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(8*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m9 = awuser_m_bus[ ((8 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(8 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m9 = wuser_m_bus[ ((8 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(8 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m9 = aruser_m_bus[ ((8 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(8 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((8 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(8 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m9;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((8 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(8 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m9;
 `endif  
`endif  //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M10

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m10;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m10;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m10;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m10;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m10;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m10;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m10;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m10;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m10;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m10;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m10;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m10;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m10;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m10;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m10;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m10;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m10;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m10;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m10;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m10;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m10;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m10;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m10;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m10;
   assign bresp_m10[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m10;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m10;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m10;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m10;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m10;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m10;

     assign awdomain_m10   = awburst_m10;
     assign awsnoop_m10    = awprot_m10;
     assign awbar_m10      = ~awburst_m10;

     assign ardomain_m10   = arburst_m10;
     assign arsnoop_m10    = arcache_m10;
     assign arbar_m10      = ~arburst_m10;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m10;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m10;

   assign xdcdr_slv_num_wr_m[10] = xdcdr_slv_num_wr_m10;
   assign xdcdr_slv_num_rd_m[10] = xdcdr_slv_num_rd_m10;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m10;
   assign arsideband_m[10] = arsideband_m10;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m10;
   assign awsideband_m[10] = awsideband_m10;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m10;
   assign rsideband_m[10] = rsideband_m10;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m10;
   assign wsideband_m[10] = wsideband_m10;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m10;
   assign bsideband_m[10] = bsideband_m10;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m10;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m10;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m10;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m10;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m10;
 `endif  
`endif

   assign araddr_m[10]  = araddr_m10;
   assign arid_m[10]    = arid_m10;
   assign arlen_m[10]   = arlen_m10;
   assign arsize_m[10]  = arsize_m10;
   assign arburst_m[10] = arburst_m10;
   assign arlock_m[10]  = arlock_m10;
   assign arprot_m[10]  = arprot_m10;
   assign arcache_m[10] = arcache_m10;

   assign awaddr_m[10]  = awaddr_m10;
   assign awid_m[10]    = awid_m10;
   assign awlen_m[10]   = awlen_m10;
   assign awsize_m[10]  = awsize_m10;
   assign awburst_m[10] = awburst_m10;
   assign awlock_m[10]  = awlock_m10;
   assign awprot_m[10]  = awprot_m10;
   assign awcache_m[10] = awcache_m10;

   assign wdata_m[10] = wdata_m10;
   assign wid_m[10]   = wid_m10;
   assign wstrb_m[10] = wstrb_m10;

   assign rdata_m[10] = rdata_m10;
   assign rid_m[10]   = rid_m10;
   assign rresp_m[10] = rresp_m10;

   assign bresp_m[10] = bresp_m10;
   assign bid_m[10]   = bid_m10;

   assign arvalid_m[10] = arvalid_m_bus[9];
   assign araddr_m10    = araddr_m_bus[ ((9 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(9*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m10 = xdcdr_slv_num_rd_m_bus[ ((9 + 1) * `AXI_LOG2_NSP1) -1:(9*`AXI_LOG2_NSP1)];
   assign arlen_m10     = arlen_m_bus[  ((9 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(9*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m10    = arsize_m_bus[ ((9 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(9*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m10   = arburst_m_bus[((9 + 1) * `SVT_AXI_BURST_WIDTH)-1:(9*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m10    = arlock_m_bus[ ((9 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(9*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m10   = arcache_m_bus[((9 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(9*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m10    = arprot_m_bus[ ((9 + 1) * `SVT_AXI_PROT_WIDTH) -1:(9*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m10      = arid_m_bus[ ((9 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(9*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[9] = arready_m[10];

   assign awvalid_m[10] = awvalid_m_bus[9];
   assign awaddr_m10    = awaddr_m_bus[ ((9 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(9*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m10 = xdcdr_slv_num_wr_m_bus[ ((9 + 1) * `AXI_LOG2_NSP1) -1:(9*`AXI_LOG2_NSP1)];
   assign awlen_m10     = awlen_m_bus[  ((9 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(9*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m10    = awsize_m_bus[ ((9 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(9*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m10   = awburst_m_bus[((9 + 1) * `SVT_AXI_BURST_WIDTH)-1:(9*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m10    = awlock_m_bus[ ((9 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(9*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m10   = awcache_m_bus[((9 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(9*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m10    = awprot_m_bus[ ((9 + 1) * `SVT_AXI_PROT_WIDTH) -1:(9*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m10      = awid_m_bus[ ((9 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(9*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[9] = awready_m[10];

   assign rvalid_m_bus[9] = rvalid_m[10];
   assign rlast_m_bus[9] = rlast_m[10];
   assign rdata_m_bus[((9 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(9*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m10;
   assign rresp_m_bus[((9 + 1) * `SVT_AXI_RESP_WIDTH)-1:(9*`SVT_AXI_RESP_WIDTH)] = rresp_m10;
   assign rid_m_bus[((9 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(9*`SVT_AXI_MAX_ID_WIDTH)] = rid_m10;
   assign rready_m[10] = rready_m_bus[9];

   assign wvalid_m[10] = wvalid_m_bus[9];
   assign wlast_m[10]  = wlast_m_bus[9];
   assign wdata_m10    = wdata_m_bus[((9 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(9*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m10    = wstrb_m_bus[((9 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(9*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m10      = wid_m_bus[((9 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(9*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[9] = wready_m[10];

   assign bvalid_m_bus[9] = bvalid_m[10];
   assign bresp_m_bus[((9 + 1) * `SVT_AXI_RESP_WIDTH)-1:(9*`SVT_AXI_RESP_WIDTH)] = bresp_m10;
   assign bid_m_bus[((9 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(9*`SVT_AXI_MAX_ID_WIDTH)] = bid_m10;
   assign bready_m[10] = bready_m_bus[9];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m10 = {2{awaddr_m_bus[(9*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(9*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m10 = {8{wdata_m_bus[(9*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(9*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m10 = {2{araddr_m_bus[(9*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(9*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m10 = awuser_m_bus[ ((9 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(9 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m10 = wuser_m_bus[ ((9 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(9 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m10 = aruser_m_bus[ ((9 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(9 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((9 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(9 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m10;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((9 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(9 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m10;
 `endif  
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M11

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m11;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m11;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m11;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m11;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m11;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m11;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m11;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m11;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m11;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m11;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m11;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m11;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m11;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m11;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m11;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m11;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m11;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m11;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m11;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m11;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m11;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m11;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m11;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m11;
   assign bresp_m11[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m11;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m11;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m11;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m11;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m11;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m11;

     assign awdomain_m11   = awburst_m11;
     assign awsnoop_m11    = awprot_m11;
     assign awbar_m11      = ~awburst_m11;

     assign ardomain_m11   = arburst_m11;
     assign arsnoop_m11    = arcache_m11;
     assign arbar_m11      = ~arburst_m11;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m11;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m11;

   assign xdcdr_slv_num_wr_m[11] = xdcdr_slv_num_wr_m11;
   assign xdcdr_slv_num_rd_m[11] = xdcdr_slv_num_rd_m11;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m11;
   assign arsideband_m[11] = arsideband_m11;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m11;
   assign awsideband_m[11] = awsideband_m11;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m11;
   assign rsideband_m[11] = rsideband_m11;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m11;
   assign wsideband_m[11] = wsideband_m11;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m11;
   assign bsideband_m[11] = bsideband_m11;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m11;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m11;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m11;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m11;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m11;
 `endif  
`endif

   assign araddr_m[11]  = araddr_m11;
   assign arid_m[11]    = arid_m11;
   assign arlen_m[11]   = arlen_m11;
   assign arsize_m[11]  = arsize_m11;
   assign arburst_m[11] = arburst_m11;
   assign arlock_m[11]  = arlock_m11;
   assign arprot_m[11]  = arprot_m11;
   assign arcache_m[11] = arcache_m11;

   assign awaddr_m[11]  = awaddr_m11;
   assign awid_m[11]    = awid_m11;
   assign awlen_m[11]   = awlen_m11;
   assign awsize_m[11]  = awsize_m11;
   assign awburst_m[11] = awburst_m11;
   assign awlock_m[11]  = awlock_m11;
   assign awprot_m[11]  = awprot_m11;
   assign awcache_m[11] = awcache_m11;

   assign wdata_m[11] = wdata_m11;
   assign wid_m[11]   = wid_m11;
   assign wstrb_m[11] = wstrb_m11;

   assign rdata_m[11] = rdata_m11;
   assign rid_m[11]   = rid_m11;
   assign rresp_m[11] = rresp_m11;

   assign bresp_m[11] = bresp_m11;
   assign bid_m[11]   = bid_m11;

   assign arvalid_m[11] = arvalid_m_bus[10];
   assign araddr_m11    = araddr_m_bus[ ((10 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(10*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m11 = xdcdr_slv_num_rd_m_bus[ ((10 + 1) * `AXI_LOG2_NSP1) -1:(10*`AXI_LOG2_NSP1)];
   assign arlen_m11     = arlen_m_bus[  ((10 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(10*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m11    = arsize_m_bus[ ((10 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(10*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m11   = arburst_m_bus[((10 + 1) * `SVT_AXI_BURST_WIDTH)-1:(10*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m11    = arlock_m_bus[ ((10 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(10*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m11   = arcache_m_bus[((10 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(10*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m11    = arprot_m_bus[ ((10 + 1) * `SVT_AXI_PROT_WIDTH) -1:(10*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m11      = arid_m_bus[ ((10 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(10*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[10] = arready_m[11];

   assign awvalid_m[11] = awvalid_m_bus[10];
   assign awaddr_m11    = awaddr_m_bus[ ((10 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(10*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m11 = xdcdr_slv_num_wr_m_bus[ ((10 + 1) * `AXI_LOG2_NSP1) -1:(10*`AXI_LOG2_NSP1)];
   assign awlen_m11     = awlen_m_bus[  ((10 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(10*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m11    = awsize_m_bus[ ((10 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(10*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m11   = awburst_m_bus[((10 + 1) * `SVT_AXI_BURST_WIDTH)-1:(10*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m11    = awlock_m_bus[ ((10 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(10*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m11   = awcache_m_bus[((10 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(10*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m11    = awprot_m_bus[ ((10 + 1) * `SVT_AXI_PROT_WIDTH) -1:(10*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m11      = awid_m_bus[ ((10 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(10*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[10] = awready_m[11];

   assign rvalid_m_bus[10] = rvalid_m[11];
   assign rlast_m_bus[10] = rlast_m[11];
   assign rdata_m_bus[((10 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(10*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m11;
   assign rresp_m_bus[((10 + 1) * `SVT_AXI_RESP_WIDTH)-1:(10*`SVT_AXI_RESP_WIDTH)] = rresp_m11;
   assign rid_m_bus[((10 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(10*`SVT_AXI_MAX_ID_WIDTH)] = rid_m11;
   assign rready_m[11] = rready_m_bus[10];

   assign wvalid_m[11] = wvalid_m_bus[10];
   assign wlast_m[11]  = wlast_m_bus[10];
   assign wdata_m11    = wdata_m_bus[((10 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(10*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m11    = wstrb_m_bus[((10 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(10*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m11      = wid_m_bus[((10 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(10*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[10] = wready_m[11];

   assign bvalid_m_bus[10] = bvalid_m[11];
   assign bresp_m_bus[((10 + 1) * `SVT_AXI_RESP_WIDTH)-1:(10*`SVT_AXI_RESP_WIDTH)] = bresp_m11;
   assign bid_m_bus[((10 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(10*`SVT_AXI_MAX_ID_WIDTH)] = bid_m11;
   assign bready_m[11] = bready_m_bus[10];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m11 = {2{awaddr_m_bus[(10*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(10*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m11 = {8{wdata_m_bus[(10*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(10*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m11 = {2{araddr_m_bus[(10*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(10*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m11 = awuser_m_bus[ ((10 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(10 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m11 = wuser_m_bus[ ((10 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(10 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m11 = aruser_m_bus[ ((10 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(10 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((10 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(10 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m11;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((10 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(10 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m11;
 `endif  
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M12

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m12;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m12;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m12;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m12;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m12;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m12;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m12;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m12;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m12;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m12;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m12;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m12;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m12;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m12;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m12;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m12;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m12;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m12;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m12;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m12;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m12;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m12;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m12;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m12;
   assign bresp_m12[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m12;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m12;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m12;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m12;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m12;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m12;

     assign awdomain_m12   = awburst_m12;
     assign awsnoop_m12    = awprot_m12;
     assign awbar_m12      = ~awburst_m12;

     assign ardomain_m12   = arburst_m12;
     assign arsnoop_m12    = arcache_m12;
     assign arbar_m12      = ~arburst_m12;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m12;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m12;

   assign xdcdr_slv_num_wr_m[12] = xdcdr_slv_num_wr_m12;
   assign xdcdr_slv_num_rd_m[12] = xdcdr_slv_num_rd_m12;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m12;
   assign arsideband_m[12] = arsideband_m12;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m12;
   assign awsideband_m[12] = awsideband_m12;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m12;
   assign rsideband_m[12] = rsideband_m12;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m12;
   assign wsideband_m[12] = wsideband_m12;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m12;
   assign bsideband_m[12] = bsideband_m12;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m12;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m12;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m12;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m12;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m12;
 `endif  
`endif

   assign araddr_m[12]  = araddr_m12;
   assign arid_m[12]    = arid_m12;
   assign arlen_m[12]   = arlen_m12;
   assign arsize_m[12]  = arsize_m12;
   assign arburst_m[12] = arburst_m12;
   assign arlock_m[12]  = arlock_m12;
   assign arprot_m[12]  = arprot_m12;
   assign arcache_m[12] = arcache_m12;

   assign awaddr_m[12]  = awaddr_m12;
   assign awid_m[12]    = awid_m12;
   assign awlen_m[12]   = awlen_m12;
   assign awsize_m[12]  = awsize_m12;
   assign awburst_m[12] = awburst_m12;
   assign awlock_m[12]  = awlock_m12;
   assign awprot_m[12]  = awprot_m12;
   assign awcache_m[12] = awcache_m12;

   assign wdata_m[12] = wdata_m12;
   assign wid_m[12]   = wid_m12;
   assign wstrb_m[12] = wstrb_m12;

   assign rdata_m[12] = rdata_m12;
   assign rid_m[12]   = rid_m12;
   assign rresp_m[12] = rresp_m12;

   assign bresp_m[12] = bresp_m12;
   assign bid_m[12]   = bid_m12;

   assign arvalid_m[12] = arvalid_m_bus[11];
   assign araddr_m12    = araddr_m_bus[ ((11 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(11*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m12 = xdcdr_slv_num_rd_m_bus[ ((11 + 1) * `AXI_LOG2_NSP1) -1:(11*`AXI_LOG2_NSP1)];
   assign arlen_m12     = arlen_m_bus[  ((11 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(11*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m12    = arsize_m_bus[ ((11 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(11*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m12   = arburst_m_bus[((11 + 1) * `SVT_AXI_BURST_WIDTH)-1:(11*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m12    = arlock_m_bus[ ((11 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(11*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m12   = arcache_m_bus[((11 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(11*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m12    = arprot_m_bus[ ((11 + 1) * `SVT_AXI_PROT_WIDTH) -1:(11*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m12      = arid_m_bus[ ((11 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(11*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[11] = arready_m[12];

   assign awvalid_m[12] = awvalid_m_bus[11];
   assign awaddr_m12    = awaddr_m_bus[ ((11 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(11*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m12 = xdcdr_slv_num_wr_m_bus[ ((11 + 1) * `AXI_LOG2_NSP1) -1:(11*`AXI_LOG2_NSP1)];
   assign awlen_m12     = awlen_m_bus[  ((11 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(11*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m12    = awsize_m_bus[ ((11 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(11*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m12   = awburst_m_bus[((11 + 1) * `SVT_AXI_BURST_WIDTH)-1:(11*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m12    = awlock_m_bus[ ((11 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(11*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m12   = awcache_m_bus[((11 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(11*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m12    = awprot_m_bus[ ((11 + 1) * `SVT_AXI_PROT_WIDTH) -1:(11*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m12      = awid_m_bus[ ((11 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(11*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[11] = awready_m[12];

   assign rvalid_m_bus[11] = rvalid_m[12];
   assign rlast_m_bus[11] = rlast_m[12];
   assign rdata_m_bus[((11 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(11*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m12;
   assign rresp_m_bus[((11 + 1) * `SVT_AXI_RESP_WIDTH)-1:(11*`SVT_AXI_RESP_WIDTH)] = rresp_m12;
   assign rid_m_bus[((11 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(11*`SVT_AXI_MAX_ID_WIDTH)] = rid_m12;
   assign rready_m[12] = rready_m_bus[11];

   assign wvalid_m[12] = wvalid_m_bus[11];
   assign wlast_m[12]  = wlast_m_bus[11];
   assign wdata_m12    = wdata_m_bus[((11 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(11*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m12    = wstrb_m_bus[((11 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(11*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m12      = wid_m_bus[((11 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(11*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[11] = wready_m[12];

   assign bvalid_m_bus[11] = bvalid_m[12];
   assign bresp_m_bus[((11 + 1) * `SVT_AXI_RESP_WIDTH)-1:(11*`SVT_AXI_RESP_WIDTH)] = bresp_m12;
   assign bid_m_bus[((11 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(11*`SVT_AXI_MAX_ID_WIDTH)] = bid_m12;
   assign bready_m[12] = bready_m_bus[11];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m12 = {2{awaddr_m_bus[(11*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(11*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m12 = {8{wdata_m_bus[(11*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(11*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m12 = {2{araddr_m_bus[(11*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(11*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m12 = awuser_m_bus[ ((11 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(11 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m12 = wuser_m_bus[ ((11 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(11 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m12 = aruser_m_bus[ ((11 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(11 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((11 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(11 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m12;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((11 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(11 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m12;
 `endif  
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M13

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m13;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m13;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m13;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m13;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m13;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m13;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m13;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m13;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m13;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m13;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m13;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m13;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m13;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m13;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m13;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m13;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m13;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m13;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m13;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m13;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m13;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m13;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m13;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m13;
   assign bresp_m13[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m13;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m13;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m13;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m13;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m13;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m13;

     assign awdomain_m13   = awburst_m13;
     assign awsnoop_m13    = awprot_m13;
     assign awbar_m13      = ~awburst_m13;

     assign ardomain_m13   = arburst_m13;
     assign arsnoop_m13    = arcache_m13;
     assign arbar_m13      = ~arburst_m13;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m13;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m13;

   assign xdcdr_slv_num_wr_m[13] = xdcdr_slv_num_wr_m13;
   assign xdcdr_slv_num_rd_m[13] = xdcdr_slv_num_rd_m13;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m13;
   assign arsideband_m[13] = arsideband_m13;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m13;
   assign awsideband_m[13] = awsideband_m13;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m13;
   assign rsideband_m[13] = rsideband_m13;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m13;
   assign wsideband_m[13] = wsideband_m13;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m13;
   assign bsideband_m[13] = bsideband_m13;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m13;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m13;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m13;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m13;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m13;
 `endif  
`endif 

   assign araddr_m[13]  = araddr_m13;
   assign arid_m[13]    = arid_m13;
   assign arlen_m[13]   = arlen_m13;
   assign arsize_m[13]  = arsize_m13;
   assign arburst_m[13] = arburst_m13;
   assign arlock_m[13]  = arlock_m13;
   assign arprot_m[13]  = arprot_m13;
   assign arcache_m[13] = arcache_m13;

   assign awaddr_m[13]  = awaddr_m13;
   assign awid_m[13]    = awid_m13;
   assign awlen_m[13]   = awlen_m13;
   assign awsize_m[13]  = awsize_m13;
   assign awburst_m[13] = awburst_m13;
   assign awlock_m[13]  = awlock_m13;
   assign awprot_m[13]  = awprot_m13;
   assign awcache_m[13] = awcache_m13;

   assign wdata_m[13] = wdata_m13;
   assign wid_m[13]   = wid_m13;
   assign wstrb_m[13] = wstrb_m13;

   assign rdata_m[13] = rdata_m13;
   assign rid_m[13]   = rid_m13;
   assign rresp_m[13] = rresp_m13;

   assign bresp_m[13] = bresp_m13;
   assign bid_m[13]   = bid_m13;

   assign arvalid_m[13] = arvalid_m_bus[12];
   assign araddr_m13    = araddr_m_bus[ ((12 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(12*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m13 = xdcdr_slv_num_rd_m_bus[ ((12 + 1) * `AXI_LOG2_NSP1) -1:(12*`AXI_LOG2_NSP1)];
   assign arlen_m13     = arlen_m_bus[  ((12 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(12*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m13    = arsize_m_bus[ ((12 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(12*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m13   = arburst_m_bus[((12 + 1) * `SVT_AXI_BURST_WIDTH)-1:(12*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m13    = arlock_m_bus[ ((12 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(12*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m13   = arcache_m_bus[((12 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(12*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m13    = arprot_m_bus[ ((12 + 1) * `SVT_AXI_PROT_WIDTH) -1:(12*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m13      = arid_m_bus[ ((12 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(12*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[12] = arready_m[13];

   assign awvalid_m[13] = awvalid_m_bus[12];
   assign awaddr_m13    = awaddr_m_bus[ ((12 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(12*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m13 = xdcdr_slv_num_wr_m_bus[ ((12 + 1) * `AXI_LOG2_NSP1) -1:(12*`AXI_LOG2_NSP1)];
   assign awlen_m13     = awlen_m_bus[  ((12 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(12*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m13    = awsize_m_bus[ ((12 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(12*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m13   = awburst_m_bus[((12 + 1) * `SVT_AXI_BURST_WIDTH)-1:(12*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m13    = awlock_m_bus[ ((12 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(12*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m13   = awcache_m_bus[((12 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(12*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m13    = awprot_m_bus[ ((12 + 1) * `SVT_AXI_PROT_WIDTH) -1:(12*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m13      = awid_m_bus[ ((12 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(12*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[12] = awready_m[13];

   assign rvalid_m_bus[12] = rvalid_m[13];
   assign rlast_m_bus[12] = rlast_m[13];
   assign rdata_m_bus[((12 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(12*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m13;
   assign rresp_m_bus[((12 + 1) * `SVT_AXI_RESP_WIDTH)-1:(12*`SVT_AXI_RESP_WIDTH)] = rresp_m13;
   assign rid_m_bus[((12 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(12*`SVT_AXI_MAX_ID_WIDTH)] = rid_m13;
   assign rready_m[13] = rready_m_bus[12];

   assign wvalid_m[13] = wvalid_m_bus[12];
   assign wlast_m[13]  = wlast_m_bus[12];
   assign wdata_m13    = wdata_m_bus[((12 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(12*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m13    = wstrb_m_bus[((12 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(12*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m13      = wid_m_bus[((12 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(12*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[12] = wready_m[13];

   assign bvalid_m_bus[12] = bvalid_m[13];
   assign bresp_m_bus[((12 + 1) * `SVT_AXI_RESP_WIDTH)-1:(12*`SVT_AXI_RESP_WIDTH)] = bresp_m13;
   assign bid_m_bus[((12 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(12*`SVT_AXI_MAX_ID_WIDTH)] = bid_m13;
   assign bready_m[13] = bready_m_bus[12];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m13 = {2{awaddr_m_bus[(12*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(12*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m13 = {8{wdata_m_bus[(12*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(12*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m13 = {2{araddr_m_bus[(12*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(12*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m13 = awuser_m_bus[ ((12 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(12 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m13 = wuser_m_bus[ ((12 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(12 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m13 = aruser_m_bus[ ((12 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(12 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((12 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(12 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m13;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((12 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(12 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m13;
 `endif  
`endif  //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M14

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m14;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m14;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m14;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m14;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m14;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m14;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m14;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m14;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m14;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m14;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m14;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m14;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m14;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m14;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m14;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m14;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m14;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m14;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m14;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m14;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m14;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m14;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m14;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m14;
   assign bresp_m14[3:2] = 2'b00;

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m14;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m14;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m14;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m14;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m14;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m14;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m14;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m14;

     assign awdomain_m14   = awburst_m14;
     assign awsnoop_m14    = awprot_m14;
     assign awbar_m14      = ~awburst_m14;

     assign ardomain_m14   = arburst_m14;
     assign arsnoop_m14    = arcache_m14;
     assign arbar_m14      = ~arburst_m14;
   `endif    

   assign xdcdr_slv_num_wr_m[14] = xdcdr_slv_num_wr_m14;
   assign xdcdr_slv_num_rd_m[14] = xdcdr_slv_num_rd_m14;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m14;
   assign arsideband_m[14] = arsideband_m14;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m14;
   assign awsideband_m[14] = awsideband_m14;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m14;
   assign rsideband_m[14] = rsideband_m14;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m14;
   assign wsideband_m[14] = wsideband_m14;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m14;
   assign bsideband_m[14] = bsideband_m14;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m14;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m14;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m14;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m14;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m14;
 `endif  
`endif

   assign araddr_m[14]  = araddr_m14;
   assign arid_m[14]    = arid_m14;
   assign arlen_m[14]   = arlen_m14;
   assign arsize_m[14]  = arsize_m14;
   assign arburst_m[14] = arburst_m14;
   assign arlock_m[14]  = arlock_m14;
   assign arprot_m[14]  = arprot_m14;
   assign arcache_m[14] = arcache_m14;

   assign awaddr_m[14]  = awaddr_m14;
   assign awid_m[14]    = awid_m14;
   assign awlen_m[14]   = awlen_m14;
   assign awsize_m[14]  = awsize_m14;
   assign awburst_m[14] = awburst_m14;
   assign awlock_m[14]  = awlock_m14;
   assign awprot_m[14]  = awprot_m14;
   assign awcache_m[14] = awcache_m14;

   assign wdata_m[14] = wdata_m14;
   assign wid_m[14]   = wid_m14;
   assign wstrb_m[14] = wstrb_m14;

   assign rdata_m[14] = rdata_m14;
   assign rid_m[14]   = rid_m14;
   assign rresp_m[14] = rresp_m14;

   assign bresp_m[14] = bresp_m14;
   assign bid_m[14]   = bid_m14;

   assign arvalid_m[14] = arvalid_m_bus[13];
   assign araddr_m14    = araddr_m_bus[ ((13 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(13*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m14 = xdcdr_slv_num_rd_m_bus[ ((13 + 1) * `AXI_LOG2_NSP1) -1:(13*`AXI_LOG2_NSP1)];
   assign arlen_m14     = arlen_m_bus[  ((13 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(13*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m14    = arsize_m_bus[ ((13 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(13*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m14   = arburst_m_bus[((13 + 1) * `SVT_AXI_BURST_WIDTH)-1:(13*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m14    = arlock_m_bus[ ((13 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(13*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m14   = arcache_m_bus[((13 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(13*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m14    = arprot_m_bus[ ((13 + 1) * `SVT_AXI_PROT_WIDTH) -1:(13*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m14      = arid_m_bus[ ((13 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(13*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[13] = arready_m[14];

   assign awvalid_m[14] = awvalid_m_bus[13];
   assign awaddr_m14    = awaddr_m_bus[ ((13 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(13*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m14 = xdcdr_slv_num_wr_m_bus[ ((13 + 1) * `AXI_LOG2_NSP1) -1:(13*`AXI_LOG2_NSP1)];
   assign awlen_m14     = awlen_m_bus[  ((13 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(13*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m14    = awsize_m_bus[ ((13 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(13*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m14   = awburst_m_bus[((13 + 1) * `SVT_AXI_BURST_WIDTH)-1:(13*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m14    = awlock_m_bus[ ((13 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(13*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m14   = awcache_m_bus[((13 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(13*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m14    = awprot_m_bus[ ((13 + 1) * `SVT_AXI_PROT_WIDTH) -1:(13*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m14      = awid_m_bus[ ((13 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(13*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[13] = awready_m[14];

   assign rvalid_m_bus[13] = rvalid_m[14];
   assign rlast_m_bus[13] = rlast_m[14];
   assign rdata_m_bus[((13 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(13*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m14;
   assign rresp_m_bus[((13 + 1) * `SVT_AXI_RESP_WIDTH)-1:(13*`SVT_AXI_RESP_WIDTH)] = rresp_m14;
   assign rid_m_bus[((13 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(13*`SVT_AXI_MAX_ID_WIDTH)] = rid_m14;
   assign rready_m[14] = rready_m_bus[13];

   assign wvalid_m[14] = wvalid_m_bus[13];
   assign wlast_m[14]  = wlast_m_bus[13];
   assign wdata_m14    = wdata_m_bus[((13 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(13*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m14    = wstrb_m_bus[((13 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(13*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m14      = wid_m_bus[((13 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(13*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[13] = wready_m[14];

   assign bvalid_m_bus[13] = bvalid_m[14];
   assign bresp_m_bus[((13 + 1) * `SVT_AXI_RESP_WIDTH)-1:(13*`SVT_AXI_RESP_WIDTH)] = bresp_m14;
   assign bid_m_bus[((13 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(13*`SVT_AXI_MAX_ID_WIDTH)] = bid_m14;
   assign bready_m[14] = bready_m_bus[13];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m14 = {2{awaddr_m_bus[(13*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(13*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m14 = {8{wdata_m_bus[(13*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(13*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m14 = {2{araddr_m_bus[(13*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(13*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m14 = awuser_m_bus[ ((13 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(13 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m14 = wuser_m_bus[ ((13 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(13 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m14 = aruser_m_bus[ ((13 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(13 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((13 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(13 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m14;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((13 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(13 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m14;
 `endif  
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M15

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m15;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m15;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m15;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m15;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m15;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m15;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m15;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m15;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m15;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m15;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m15;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m15;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m15;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m15;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m15;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m15;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m15;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m15;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m15;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m15;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m15;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m15;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m15;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m15;
   assign bresp_m15[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m15;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m15;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m15;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m15;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m15;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m15;

     assign awdomain_m15   = awburst_m15;
     assign awsnoop_m15    = awprot_m15;
     assign awbar_m15      = ~awburst_m15;

     assign ardomain_m15   = arburst_m15;
     assign arsnoop_m15    = arcache_m15;
     assign arbar_m15      = ~arburst_m15;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m15;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m15;

   assign xdcdr_slv_num_wr_m[15] = xdcdr_slv_num_wr_m15;
   assign xdcdr_slv_num_rd_m[15] = xdcdr_slv_num_rd_m15;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m15;
   assign arsideband_m[15] = arsideband_m15;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m15;
   assign awsideband_m[15] = awsideband_m15;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m15;
   assign rsideband_m[15] = rsideband_m15;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m15;
   assign wsideband_m[15] = wsideband_m15;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m15;
   assign bsideband_m[15] = bsideband_m15;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m15;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m15;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m15;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m15;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m15;
 `endif 
`endif 

   assign araddr_m[15]  = araddr_m15;
   assign arid_m[15]    = arid_m15;
   assign arlen_m[15]   = arlen_m15;
   assign arsize_m[15]  = arsize_m15;
   assign arburst_m[15] = arburst_m15;
   assign arlock_m[15]  = arlock_m15;
   assign arprot_m[15]  = arprot_m15;
   assign arcache_m[15] = arcache_m15;

   assign awaddr_m[15]  = awaddr_m15;
   assign awid_m[15]    = awid_m15;
   assign awlen_m[15]   = awlen_m15;
   assign awsize_m[15]  = awsize_m15;
   assign awburst_m[15] = awburst_m15;
   assign awlock_m[15]  = awlock_m15;
   assign awprot_m[15]  = awprot_m15;
   assign awcache_m[15] = awcache_m15;

   assign wdata_m[15] = wdata_m15;
   assign wid_m[15]   = wid_m15;
   assign wstrb_m[15] = wstrb_m15;

   assign rdata_m[15] = rdata_m15;
   assign rid_m[15]   = rid_m15;
   assign rresp_m[15] = rresp_m15;

   assign bresp_m[15] = bresp_m15;
   assign bid_m[15]   = bid_m15;

   assign arvalid_m[15] = arvalid_m_bus[14];
   assign araddr_m15    = araddr_m_bus[ ((14 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(14*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m15 = xdcdr_slv_num_rd_m_bus[ ((14 + 1) * `AXI_LOG2_NSP1) -1:(14*`AXI_LOG2_NSP1)];
   assign arlen_m15     = arlen_m_bus[  ((14 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(14*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m15    = arsize_m_bus[ ((14 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(14*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m15   = arburst_m_bus[((14 + 1) * `SVT_AXI_BURST_WIDTH)-1:(14*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m15    = arlock_m_bus[ ((14 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(14*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m15   = arcache_m_bus[((14 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(14*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m15    = arprot_m_bus[ ((14 + 1) * `SVT_AXI_PROT_WIDTH) -1:(14*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m15      = arid_m_bus[ ((14 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(14*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[14] = arready_m[15];

   assign awvalid_m[15] = awvalid_m_bus[14];
   assign awaddr_m15    = awaddr_m_bus[ ((14 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(14*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m15 = xdcdr_slv_num_wr_m_bus[ ((14 + 1) * `AXI_LOG2_NSP1) -1:(14*`AXI_LOG2_NSP1)];
   assign awlen_m15     = awlen_m_bus[  ((14 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(14*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m15    = awsize_m_bus[ ((14 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(14*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m15   = awburst_m_bus[((14 + 1) * `SVT_AXI_BURST_WIDTH)-1:(14*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m15    = awlock_m_bus[ ((14 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(14*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m15   = awcache_m_bus[((14 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(14*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m15    = awprot_m_bus[ ((14 + 1) * `SVT_AXI_PROT_WIDTH) -1:(14*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m15      = awid_m_bus[ ((14 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(14*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[14] = awready_m[15];

   assign rvalid_m_bus[14] = rvalid_m[15];
   assign rlast_m_bus[14] = rlast_m[15];
   assign rdata_m_bus[((14 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(14*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m15;
   assign rresp_m_bus[((14 + 1) * `SVT_AXI_RESP_WIDTH)-1:(14*`SVT_AXI_RESP_WIDTH)] = rresp_m15;
   assign rid_m_bus[((14 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(14*`SVT_AXI_MAX_ID_WIDTH)] = rid_m15;
   assign rready_m[15] = rready_m_bus[14];

   assign wvalid_m[15] = wvalid_m_bus[14];
   assign wlast_m[15]  = wlast_m_bus[14];
   assign wdata_m15    = wdata_m_bus[((14 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(14*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m15    = wstrb_m_bus[((14 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(14*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m15      = wid_m_bus[((14 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(14*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[14] = wready_m[15];

   assign bvalid_m_bus[14] = bvalid_m[15];
   assign bresp_m_bus[((14 + 1) * `SVT_AXI_RESP_WIDTH)-1:(14*`SVT_AXI_RESP_WIDTH)] = bresp_m15;
   assign bid_m_bus[((14 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(14*`SVT_AXI_MAX_ID_WIDTH)] = bid_m15;
   assign bready_m[15] = bready_m_bus[14];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m15 = {2{awaddr_m_bus[(14*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(14*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m15 = {8{wdata_m_bus[(14*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(14*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m15 = {2{araddr_m_bus[(14*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(14*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m15 = awuser_m_bus[ ((14 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(14 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m15 = wuser_m_bus[ ((14 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(14 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m15 = aruser_m_bus[ ((14 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(14 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((14 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(14 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m15;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((14 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(14 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m15;
 `endif  
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_M16

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_m16;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_m16;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_m16;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_m16;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_m16;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_m16;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_m16;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_m16;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_m16;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_m16;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_m16;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_m16;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_m16;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_m16;
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_m16;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_m16;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_m16;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_m16;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_m16;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_m16;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_m16;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_m16;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_m16;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_m16;
   assign bresp_m16[3:2] = 2'b00;

   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_m16;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_m16;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_m16;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_m16;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_m16;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_m16;

     assign awdomain_m16   = awburst_m16;
     assign awsnoop_m16    = awprot_m16;
     assign awbar_m16      = ~awburst_m16;

     assign ardomain_m16   = arburst_m16;
     assign arsnoop_m16    = arcache_m16;
     assign arbar_m16      = ~arburst_m16;
   `endif    

   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_wr_m16;
   wire [`AXI_LOG2_NSP1-1:0]                    xdcdr_slv_num_rd_m16;

   assign xdcdr_slv_num_wr_m[16] = xdcdr_slv_num_wr_m16;
   assign xdcdr_slv_num_rd_m[16] = xdcdr_slv_num_rd_m16;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_m16;
   assign arsideband_m[16] = arsideband_m16;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_m16;
   assign awsideband_m[16] = awsideband_m16;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_m16;
   assign rsideband_m[16] = rsideband_m16;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_m16;
   assign wsideband_m[16] = wsideband_m16;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_m16;
   assign bsideband_m[16] = bsideband_m16;
 `endif
`else 
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awuser_m16;
 `endif  
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wuser_m16;
 `endif  
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] buser_m16;
 `endif  
 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] aruser_m16;
 `endif  
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] ruser_m16;
 `endif  
`endif 

   assign araddr_m[16]  = araddr_m16;
   assign arid_m[16]    = arid_m16;
   assign arlen_m[16]   = arlen_m16;
   assign arsize_m[16]  = arsize_m16;
   assign arburst_m[16] = arburst_m16;
   assign arlock_m[16]  = arlock_m16;
   assign arprot_m[16]  = arprot_m16;
   assign arcache_m[16] = arcache_m16;

   assign awaddr_m[16]  = awaddr_m16;
   assign awid_m[16]    = awid_m16;
   assign awlen_m[16]   = awlen_m16;
   assign awsize_m[16]  = awsize_m16;
   assign awburst_m[16] = awburst_m16;
   assign awlock_m[16]  = awlock_m16;
   assign awprot_m[16]  = awprot_m16;
   assign awcache_m[16] = awcache_m16;

   assign wdata_m[16] = wdata_m16;
   assign wid_m[16]   = wid_m16;
   assign wstrb_m[16] = wstrb_m16;

   assign rdata_m[16] = rdata_m16;
   assign rid_m[16]   = rid_m16;
   assign rresp_m[16] = rresp_m16;

   assign bresp_m[16] = bresp_m16;
   assign bid_m[16]   = bid_m16;

   assign arvalid_m[16] = arvalid_m_bus[15];
   assign araddr_m16    = araddr_m_bus[ ((15 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(15*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_rd_m16 = xdcdr_slv_num_rd_m_bus[ ((15 + 1) * `AXI_LOG2_NSP1) -1:(15*`AXI_LOG2_NSP1)];
   assign arlen_m16     = arlen_m_bus[  ((15 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(15*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign arsize_m16    = arsize_m_bus[ ((15 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(15*`SVT_AXI_SIZE_WIDTH  )];
   assign arburst_m16   = arburst_m_bus[((15 + 1) * `SVT_AXI_BURST_WIDTH)-1:(15*`SVT_AXI_BURST_WIDTH )];
   assign arlock_m16    = arlock_m_bus[ ((15 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(15*`SVT_AXI_LOCK_WIDTH  )];
   assign arcache_m16   = arcache_m_bus[((15 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(15*`SVT_AXI_CACHE_WIDTH )];
   assign arprot_m16    = arprot_m_bus[ ((15 + 1) * `SVT_AXI_PROT_WIDTH) -1:(15*`SVT_AXI_PROT_WIDTH  )];
   assign arid_m16      = arid_m_bus[ ((15 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(15*`SVT_AXI_MAX_ID_WIDTH)];
   assign arready_m_bus[15] = arready_m[16];

   assign awvalid_m[16] = awvalid_m_bus[15];
   assign awaddr_m16    = awaddr_m_bus[ ((15 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(15*`SVT_AXI_MAX_ADDR_WIDTH  )];
   assign xdcdr_slv_num_wr_m16 = xdcdr_slv_num_wr_m_bus[ ((15 + 1) * `AXI_LOG2_NSP1) -1:(15*`AXI_LOG2_NSP1)];
   assign awlen_m16     = awlen_m_bus[  ((15 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(15*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )];
   assign awsize_m16    = awsize_m_bus[ ((15 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(15*`SVT_AXI_SIZE_WIDTH  )];
   assign awburst_m16   = awburst_m_bus[((15 + 1) * `SVT_AXI_BURST_WIDTH)-1:(15*`SVT_AXI_BURST_WIDTH )];
   assign awlock_m16    = awlock_m_bus[ ((15 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(15*`SVT_AXI_LOCK_WIDTH  )];
   assign awcache_m16   = awcache_m_bus[((15 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(15*`SVT_AXI_CACHE_WIDTH )];
   assign awprot_m16    = awprot_m_bus[ ((15 + 1) * `SVT_AXI_PROT_WIDTH) -1:(15*`SVT_AXI_PROT_WIDTH  )];
   assign awid_m16      = awid_m_bus[ ((15 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(15*`SVT_AXI_MAX_ID_WIDTH)];
   assign awready_m_bus[15] = awready_m[16];

   assign rvalid_m_bus[15] = rvalid_m[16];
   assign rlast_m_bus[15] = rlast_m[16];
   assign rdata_m_bus[((15 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(15*`SVT_AXI_MAX_DATA_WIDTH)] = rdata_m16;
   assign rresp_m_bus[((15 + 1) * `SVT_AXI_RESP_WIDTH)-1:(15*`SVT_AXI_RESP_WIDTH)] = rresp_m16;
   assign rid_m_bus[((15 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(15*`SVT_AXI_MAX_ID_WIDTH)] = rid_m16;
   assign rready_m[16] = rready_m_bus[15];

   assign wvalid_m[16] = wvalid_m_bus[15];
   assign wlast_m[16]  = wlast_m_bus[15];
   assign wdata_m16    = wdata_m_bus[((15 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(15*`SVT_AXI_MAX_DATA_WIDTH)];
   assign wstrb_m16    = wstrb_m_bus[((15 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(15*`SVT_AXI_MAX_DATA_WIDTH/8)];
   assign wid_m16      = wid_m_bus[((15 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(15*`SVT_AXI_MAX_ID_WIDTH)];
   assign wready_m_bus[15] = wready_m[16];

   assign bvalid_m_bus[15] = bvalid_m[16];
   assign bresp_m_bus[((15 + 1) * `SVT_AXI_RESP_WIDTH)-1:(15*`SVT_AXI_RESP_WIDTH)] = bresp_m16;
   assign bid_m_bus[((15 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(15*`SVT_AXI_MAX_ID_WIDTH)] = bid_m16;
   assign bready_m[16] = bready_m_bus[15];
`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_AWSB

   assign awsideband_m16 = {2{awaddr_m_bus[(15*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(15*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
 `ifdef AXI_INC_WSB

   assign wsideband_m16 = {8{wdata_m_bus[(15*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(15*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_ARSB

   assign arsideband_m16 = {2{araddr_m_bus[(15*`SVT_AXI_MAX_ADDR_WIDTH) + `AXI_AW-1:(15*`SVT_AXI_MAX_ADDR_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_m16 = awuser_m_bus[ ((15 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(15 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_m16 = wuser_m_bus[ ((15 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(15 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_m16 = aruser_m_bus[ ((15 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(15 * `SVT_AXI_MAX_ADDR_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_m_bus[ ((15 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(15 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = ruser_m16;
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_m_bus[ ((15 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(15 * `SVT_AXI_MAX_BRESP_USER_WIDTH )] = buser_m16;
 `endif  
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S1


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s1;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s1;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s1;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s1;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s1;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s1;
   `ifdef AXI_HAS_AXI4

     assign arlock_s1[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s1;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s1;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s1;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s1;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s1;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s1;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s1;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s1;
   `ifdef AXI_HAS_AXI4

     assign awlock_s1[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s1;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s1;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s1;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s1;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s1;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s1;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s1;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s1;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s1;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s1;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s1;
   assign arsideband_s[1] = arsideband_s1;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s1;
   assign awsideband_s[1] = awsideband_s1;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s1;
   assign rsideband_s[1] = rsideband_s1;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s1;
   assign wsideband_s[1] = wsideband_s1;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s1;
   assign bsideband_s[1] = bsideband_s1;
 `endif
`endif
  `ifdef AXI_REGIONS_S1

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s1; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s1; 
    assign #1 awregion_s[1] = awregion_s1;
    assign #1 arregion_s[1] = arregion_s1;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s1;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s1;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s1;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s1;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s1;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s1;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s1;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s1;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s1;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s1;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s1;

     assign awdomain_s[1]       =       awdomain_s1;
     assign awsnoop_s[1]        =       awsnoop_s1;
     assign awbar_s[1]          =       awbar_s1;
     assign ardomain_s[1]       =       ardomain_s1;
     assign arsnoop_s[1]        =       arsnoop_s1;
     assign arbar_s[1]          =       arbar_s1;
   `endif    

   assign #1 araddr_s[1]  = araddr_s1;
   assign arid_s[1]    = arid_s1;
   assign arlen_s[1]   = arlen_s1;
   assign arsize_s[1]  = arsize_s1;
   assign arburst_s[1] = arburst_s1;
   assign arlock_s[1]  = arlock_s1;
   assign arprot_s[1]  = arprot_s1;
   assign arcache_s[1] = arcache_s1;

   assign #1 awaddr_s[1]  = awaddr_s1;
   assign awid_s[1]    = awid_s1;
   assign awlen_s[1]   = awlen_s1;
   assign awsize_s[1]  = awsize_s1;
   assign awburst_s[1] = awburst_s1;
   assign awlock_s[1]  = awlock_s1;
   assign awprot_s[1]  = awprot_s1;
   assign awcache_s[1] = awcache_s1;

   assign wdata_s[1] = wdata_s1;
   assign wid_s[1]   = wid_s1;
   assign wstrb_s[1] = wstrb_s1;

   assign rdata_s[1] = rdata_s1;
   assign rid_s[1]   = rid_s1;
   assign rresp_s[1] = rresp_s1;

   assign bid_s[1]   = bid_s1;
   assign bresp_s[1] = bresp_s1;

   assign #1 arvalid_s_bus[0] = arvalid_s[1];
   assign araddr_s_bus[ ((0 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(0*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s1;
   assign arlen_s_bus[  ((0 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(0*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s1;
   assign arsize_s_bus[ ((0 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(0*`SVT_AXI_SIZE_WIDTH  )] = arsize_s1;
   assign arburst_s_bus[((0 + 1) * `SVT_AXI_BURST_WIDTH)-1:(0*`SVT_AXI_BURST_WIDTH )] = arburst_s1;
   assign arlock_s_bus[ ((0 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(0*`SVT_AXI_LOCK_WIDTH  )] = arlock_s1;
   assign arcache_s_bus[((0 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(0*`SVT_AXI_CACHE_WIDTH )] = arcache_s1;
   assign arprot_s_bus[ ((0 + 1) * `SVT_AXI_PROT_WIDTH) -1:(0*`SVT_AXI_PROT_WIDTH  )] = arprot_s1;
   assign arid_s_bus[ ((0 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(0*`SVT_AXI_MAX_ID_WIDTH)] = arid_s1;
   assign arready_s[1] = arready_s_bus[0];
  `ifdef AXI_REGIONS_S1

    assign arregion_s_bus[ ((0 + 1) * `SVT_AXI_REGION_WIDTH) -1:(0*`SVT_AXI_REGION_WIDTH ) ] = arregion_s1;
    assign awregion_s_bus[ ((0 + 1) * `SVT_AXI_REGION_WIDTH) -1:(0*`SVT_AXI_REGION_WIDTH ) ] = awregion_s1;
  `endif  
    
   assign #1 awvalid_s_bus[0] = awvalid_s[1];
   assign awaddr_s_bus[ ((0 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(0*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s1;
   assign awlen_s_bus[  ((0 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(0*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s1;
   assign awsize_s_bus[ ((0 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(0*`SVT_AXI_SIZE_WIDTH  )] = awsize_s1;
   assign awburst_s_bus[((0 + 1) * `SVT_AXI_BURST_WIDTH)-1:(0*`SVT_AXI_BURST_WIDTH )] = awburst_s1;
   assign awlock_s_bus[ ((0 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(0*`SVT_AXI_LOCK_WIDTH  )] = awlock_s1;
   assign awcache_s_bus[((0 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(0*`SVT_AXI_CACHE_WIDTH )] = awcache_s1;
   assign awprot_s_bus[ ((0 + 1) * `SVT_AXI_PROT_WIDTH) -1:(0*`SVT_AXI_PROT_WIDTH  )] = awprot_s1;
   assign awid_s_bus[ ((0 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(0*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s1;
   assign awready_s[1] =  awready_s_bus[0];

   assign rvalid_s[1]= rvalid_s_bus[0];
   assign rlast_s[1] = rlast_s_bus[0];
   assign rdata_s1 = rdata_s_bus[((0 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(0*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s1 = rresp_s_bus[((0 + 1) * `SVT_AXI_RESP_WIDTH)-1:(0*`SVT_AXI_RESP_WIDTH)];
   assign rid_s1   = rid_s_bus[((0 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(0*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[0] = rready_s[1];

   assign wvalid_s_bus[0] = wvalid_s[1];
   assign wlast_s_bus[0]  = wlast_s[1];
   assign wdata_s_bus[((0 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(0*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s1;
   assign wstrb_s_bus[((0 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(0*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s1;
   assign wid_s_bus[((0 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(0*`SVT_AXI_MAX_ID_WIDTH)] = wid_s1;
   assign wready_s[1] =  wready_s_bus[0];

   assign bvalid_s[1]=  bvalid_s_bus[0];
   assign bresp_s1 = bresp_s_bus[((0 + 1) * `SVT_AXI_RESP_WIDTH)-1:(0*`SVT_AXI_RESP_WIDTH)];
   assign bid_s1   = bid_s_bus[((0 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(0*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[0] = bready_s[1];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s1 = {8{rdata_s_bus[(0*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(0*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s1 = {64{bid_s_bus[(0*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(0*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((0 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(0 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s1;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((0 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(0 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s1;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((0 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(0 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s1;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s1 = ruser_s_bus[ ((0 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(0 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s1 = buser_s_bus[ ((0 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(0 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif  //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S2


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s2;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s2;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s2;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s2;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s2;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s2;
   `ifdef AXI_HAS_AXI4

     assign arlock_s2[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s2;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s2;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s2;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s2;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s2;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s2;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s2;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s2;
   `ifdef AXI_HAS_AXI4

     assign awlock_s2[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s2;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s2;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s2;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s2;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s2;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s2;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s2;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s2;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s2;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s2;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s2;
   assign arsideband_s[2] = arsideband_s2;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s2;
   assign awsideband_s[2] = awsideband_s2;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s2;
   assign rsideband_s[2] = rsideband_s2;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s2;
   assign wsideband_s[2] = wsideband_s2;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s2;
   assign bsideband_s[2] = bsideband_s2;
 `endif
`endif 
  `ifdef AXI_REGIONS_S2

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s2; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s2; 
    assign #1 awregion_s[2] = awregion_s2;
    assign #1 arregion_s[2] = arregion_s2;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s2;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s2;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s2;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s2;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s2;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s2;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s2;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s2;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s2;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s2;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s2;

     assign awdomain_s[2]       =       awdomain_s2;
     assign awsnoop_s[2]        =       awsnoop_s2;
     assign awbar_s[2]          =       awbar_s2;
     assign ardomain_s[2]       =       ardomain_s2;
     assign arsnoop_s[2]        =       arsnoop_s2;
     assign arbar_s[2]          =       arbar_s2;
   `endif    

   assign #1 araddr_s[2]  = araddr_s2;
   assign arid_s[2]    = arid_s2;
   assign arlen_s[2]   = arlen_s2;
   assign arsize_s[2]  = arsize_s2;
   assign arburst_s[2] = arburst_s2;
   assign arlock_s[2]  = arlock_s2;
   assign arprot_s[2]  = arprot_s2;
   assign arcache_s[2] = arcache_s2;

   assign #1 awaddr_s[2]  = awaddr_s2;
   assign awid_s[2]    = awid_s2;
   assign awlen_s[2]   = awlen_s2;
   assign awsize_s[2]  = awsize_s2;
   assign awburst_s[2] = awburst_s2;
   assign awlock_s[2]  = awlock_s2;
   assign awprot_s[2]  = awprot_s2;
   assign awcache_s[2] = awcache_s2;

   assign wdata_s[2] = wdata_s2;
   assign wid_s[2]   = wid_s2;
   assign wstrb_s[2] = wstrb_s2;

   assign rdata_s[2] = rdata_s2;
   assign rid_s[2]   = rid_s2;
   assign rresp_s[2] = rresp_s2;

   assign bid_s[2]   = bid_s2;
   assign bresp_s[2] = bresp_s2;

   assign #1 arvalid_s_bus[1] = arvalid_s[2];
   assign araddr_s_bus[ ((1 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(1*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s2;
   assign arlen_s_bus[  ((1 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(1*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s2;
   assign arsize_s_bus[ ((1 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(1*`SVT_AXI_SIZE_WIDTH  )] = arsize_s2;
   assign arburst_s_bus[((1 + 1) * `SVT_AXI_BURST_WIDTH)-1:(1*`SVT_AXI_BURST_WIDTH )] = arburst_s2;
   assign arlock_s_bus[ ((1 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(1*`SVT_AXI_LOCK_WIDTH  )] = arlock_s2;
   assign arcache_s_bus[((1 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(1*`SVT_AXI_CACHE_WIDTH )] = arcache_s2;
   assign arprot_s_bus[ ((1 + 1) * `SVT_AXI_PROT_WIDTH) -1:(1*`SVT_AXI_PROT_WIDTH  )] = arprot_s2;
   assign arid_s_bus[ ((1 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(1*`SVT_AXI_MAX_ID_WIDTH)] = arid_s2;
   assign arready_s[2] = arready_s_bus[1];
  `ifdef AXI_REGIONS_S2

    assign arregion_s_bus[ ((1 + 1) * `SVT_AXI_REGION_WIDTH) -1:(1*`SVT_AXI_REGION_WIDTH ) ] = arregion_s2;
    assign awregion_s_bus[ ((1 + 1) * `SVT_AXI_REGION_WIDTH) -1:(1*`SVT_AXI_REGION_WIDTH ) ] = awregion_s2;
  `endif  

   assign #1 awvalid_s_bus[1] = awvalid_s[2];
   assign awaddr_s_bus[ ((1 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(1*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s2;
   assign awlen_s_bus[  ((1 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(1*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s2;
   assign awsize_s_bus[ ((1 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(1*`SVT_AXI_SIZE_WIDTH  )] = awsize_s2;
   assign awburst_s_bus[((1 + 1) * `SVT_AXI_BURST_WIDTH)-1:(1*`SVT_AXI_BURST_WIDTH )] = awburst_s2;
   assign awlock_s_bus[ ((1 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(1*`SVT_AXI_LOCK_WIDTH  )] = awlock_s2;
   assign awcache_s_bus[((1 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(1*`SVT_AXI_CACHE_WIDTH )] = awcache_s2;
   assign awprot_s_bus[ ((1 + 1) * `SVT_AXI_PROT_WIDTH) -1:(1*`SVT_AXI_PROT_WIDTH  )] = awprot_s2;
   assign awid_s_bus[ ((1 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(1*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s2;
   assign awready_s[2] =  awready_s_bus[1];

   assign rvalid_s[2]= rvalid_s_bus[1];
   assign rlast_s[2] = rlast_s_bus[1];
   assign rdata_s2 = rdata_s_bus[((1 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(1*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s2 = rresp_s_bus[((1 + 1) * `SVT_AXI_RESP_WIDTH)-1:(1*`SVT_AXI_RESP_WIDTH)];
   assign rid_s2   = rid_s_bus[((1 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(1*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[1] = rready_s[2];

   assign wvalid_s_bus[1] = wvalid_s[2];
   assign wlast_s_bus[1]  = wlast_s[2];
   assign wdata_s_bus[((1 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(1*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s2;
   assign wstrb_s_bus[((1 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(1*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s2;
   assign wid_s_bus[((1 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(1*`SVT_AXI_MAX_ID_WIDTH)] = wid_s2;
   assign wready_s[2] =  wready_s_bus[1];

   assign bvalid_s[2]=  bvalid_s_bus[1];
   assign bresp_s2 = bresp_s_bus[((1 + 1) * `SVT_AXI_RESP_WIDTH)-1:(1*`SVT_AXI_RESP_WIDTH)];
   assign bid_s2   = bid_s_bus[((1 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(1*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[1] = bready_s[2];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s2 = {8{rdata_s_bus[(1*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(1*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s2 = {64{bid_s_bus[(1*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(1*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((1 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(1 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s2;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((1 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(1 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s2;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((1 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(1 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s2;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s2 = ruser_s_bus[ ((1 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(1 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s2 = buser_s_bus[ ((1 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(1 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S3


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s3;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s3;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s3;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s3;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s3;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s3;
   `ifdef AXI_HAS_AXI4

     assign arlock_s3[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s3;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s3;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s3;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s3;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s3;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s3;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s3;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s3;
   `ifdef AXI_HAS_AXI4

     assign awlock_s3[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s3;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s3;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s3;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s3;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s3;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s3;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s3;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s3;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s3;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s3;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s3;
   assign arsideband_s[3] = arsideband_s3;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s3;
   assign awsideband_s[3] = awsideband_s3;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s3;
   assign rsideband_s[3] = rsideband_s3;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s3;
   assign wsideband_s[3] = wsideband_s3;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s3;
   assign bsideband_s[3] = bsideband_s3;
 `endif
`endif 
  `ifdef AXI_REGIONS_S3

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s3; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s3; 
    assign #1 awregion_s[3] = awregion_s3;
    assign #1 arregion_s[3] = arregion_s3;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s3;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s3;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s3;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s3;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s3;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s3;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s3;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s3;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s3;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s3;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s3;

     assign awdomain_s[3]       =       awdomain_s3;
     assign awsnoop_s[3]        =       awsnoop_s3;
     assign awbar_s[3]          =       awbar_s3;
     assign ardomain_s[3]       =       ardomain_s3;
     assign arsnoop_s[3]        =       arsnoop_s3;
     assign arbar_s[3]          =       arbar_s3;
   `endif    

   assign #1 araddr_s[3]  = araddr_s3;
   assign arid_s[3]    = arid_s3;
   assign arlen_s[3]   = arlen_s3;
   assign arsize_s[3]  = arsize_s3;
   assign arburst_s[3] = arburst_s3;
   assign arlock_s[3]  = arlock_s3;
   assign arprot_s[3]  = arprot_s3;
   assign arcache_s[3] = arcache_s3;

   assign #1 awaddr_s[3]  = awaddr_s3;
   assign awid_s[3]    = awid_s3;
   assign awlen_s[3]   = awlen_s3;
   assign awsize_s[3]  = awsize_s3;
   assign awburst_s[3] = awburst_s3;
   assign awlock_s[3]  = awlock_s3;
   assign awprot_s[3]  = awprot_s3;
   assign awcache_s[3] = awcache_s3;

   assign wdata_s[3] = wdata_s3;
   assign wid_s[3]   = wid_s3;
   assign wstrb_s[3] = wstrb_s3;

   assign rdata_s[3] = rdata_s3;
   assign rid_s[3]   = rid_s3;
   assign rresp_s[3] = rresp_s3;

   assign bid_s[3]   = bid_s3;
   assign bresp_s[3] = bresp_s3;

   assign #1 arvalid_s_bus[2] = arvalid_s[3];
   assign araddr_s_bus[ ((2 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(2*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s3;
   assign arlen_s_bus[  ((2 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(2*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s3;
   assign arsize_s_bus[ ((2 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(2*`SVT_AXI_SIZE_WIDTH  )] = arsize_s3;
   assign arburst_s_bus[((2 + 1) * `SVT_AXI_BURST_WIDTH)-1:(2*`SVT_AXI_BURST_WIDTH )] = arburst_s3;
   assign arlock_s_bus[ ((2 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(2*`SVT_AXI_LOCK_WIDTH  )] = arlock_s3;
   assign arcache_s_bus[((2 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(2*`SVT_AXI_CACHE_WIDTH )] = arcache_s3;
   assign arprot_s_bus[ ((2 + 1) * `SVT_AXI_PROT_WIDTH) -1:(2*`SVT_AXI_PROT_WIDTH  )] = arprot_s3;
   assign arid_s_bus[ ((2 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(2*`SVT_AXI_MAX_ID_WIDTH)] = arid_s3;
   assign arready_s[3] = arready_s_bus[2];
  `ifdef AXI_REGIONS_S3

    assign arregion_s_bus[ ((2 + 1) * `SVT_AXI_REGION_WIDTH) -1:(2*`SVT_AXI_REGION_WIDTH ) ] = arregion_s3;
    assign awregion_s_bus[ ((2 + 1) * `SVT_AXI_REGION_WIDTH) -1:(2*`SVT_AXI_REGION_WIDTH ) ] = awregion_s3;
  `endif  

   assign #1 awvalid_s_bus[2] = awvalid_s[3];
   assign awaddr_s_bus[ ((2 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(2*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s3;
   assign awlen_s_bus[  ((2 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(2*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s3;
   assign awsize_s_bus[ ((2 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(2*`SVT_AXI_SIZE_WIDTH  )] = awsize_s3;
   assign awburst_s_bus[((2 + 1) * `SVT_AXI_BURST_WIDTH)-1:(2*`SVT_AXI_BURST_WIDTH )] = awburst_s3;
   assign awlock_s_bus[ ((2 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(2*`SVT_AXI_LOCK_WIDTH  )] = awlock_s3;
   assign awcache_s_bus[((2 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(2*`SVT_AXI_CACHE_WIDTH )] = awcache_s3;
   assign awprot_s_bus[ ((2 + 1) * `SVT_AXI_PROT_WIDTH) -1:(2*`SVT_AXI_PROT_WIDTH  )] = awprot_s3;
   assign awid_s_bus[ ((2 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(2*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s3;
   assign awready_s[3] =  awready_s_bus[2];

   assign rvalid_s[3]= rvalid_s_bus[2];
   assign rlast_s[3] = rlast_s_bus[2];
   assign rdata_s3 = rdata_s_bus[((2 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(2*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s3 = rresp_s_bus[((2 + 1) * `SVT_AXI_RESP_WIDTH)-1:(2*`SVT_AXI_RESP_WIDTH)];
   assign rid_s3   = rid_s_bus[((2 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(2*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[2] = rready_s[3];

   assign wvalid_s_bus[2] = wvalid_s[3];
   assign wlast_s_bus[2]  = wlast_s[3];
   assign wdata_s_bus[((2 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(2*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s3;
   assign wstrb_s_bus[((2 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(2*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s3;
   assign wid_s_bus[((2 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(2*`SVT_AXI_MAX_ID_WIDTH)] = wid_s3;
   assign wready_s[3] =  wready_s_bus[2];

   assign bvalid_s[3]=  bvalid_s_bus[2];
   assign bresp_s3 = bresp_s_bus[((2 + 1) * `SVT_AXI_RESP_WIDTH)-1:(2*`SVT_AXI_RESP_WIDTH)];
   assign bid_s3   = bid_s_bus[((2 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(2*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[2] = bready_s[3];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s3 = {8{rdata_s_bus[(2*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(2*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s3 = {64{bid_s_bus[(2*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(2*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((2 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(2 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s3;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((2 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(2 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s3;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((2 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(2 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s3;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s3 = ruser_s_bus[ ((2 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(2 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s3 = buser_s_bus[ ((2 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(2 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S4


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s4;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s4;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s4;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s4;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s4;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s4;
   `ifdef AXI_HAS_AXI4

     assign arlock_s4[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s4;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s4;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s4;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s4;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s4;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s4;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s4;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s4;
   `ifdef AXI_HAS_AXI4

     assign awlock_s4[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s4;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s4;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s4;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s4;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s4;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s4;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s4;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s4;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s4;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s4;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s4;
   assign arsideband_s[4] = arsideband_s4;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s4;
   assign awsideband_s[4] = awsideband_s4;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s4;
   assign rsideband_s[4] = rsideband_s4;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s4;
   assign wsideband_s[4] = wsideband_s4;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s4;
   assign bsideband_s[4] = bsideband_s4;
 `endif
`endif 
  `ifdef AXI_REGIONS_S4

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s4; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s4; 
    assign #1 awregion_s[4] = awregion_s4;
    assign #1 arregion_s[4] = arregion_s4;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s4;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s4;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s4;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s4;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s4;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s4;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s4;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s4;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s4;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s4;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s4;

     assign awdomain_s[4]       =       awdomain_s4;
     assign awsnoop_s[4]        =       awsnoop_s4;
     assign awbar_s[4]          =       awbar_s4;
     assign ardomain_s[4]       =       ardomain_s4;
     assign arsnoop_s[4]        =       arsnoop_s4;
     assign arbar_s[4]          =       arbar_s4;
   `endif    

   assign #1 araddr_s[4]  = araddr_s4;
   assign arid_s[4]    = arid_s4;
   assign arlen_s[4]   = arlen_s4;
   assign arsize_s[4]  = arsize_s4;
   assign arburst_s[4] = arburst_s4;
   assign arlock_s[4]  = arlock_s4;
   assign arprot_s[4]  = arprot_s4;
   assign arcache_s[4] = arcache_s4;

   assign #1 awaddr_s[4]  = awaddr_s4;
   assign awid_s[4]    = awid_s4;
   assign awlen_s[4]   = awlen_s4;
   assign awsize_s[4]  = awsize_s4;
   assign awburst_s[4] = awburst_s4;
   assign awlock_s[4]  = awlock_s4;
   assign awprot_s[4]  = awprot_s4;
   assign awcache_s[4] = awcache_s4;

   assign wdata_s[4] = wdata_s4;
   assign wid_s[4]   = wid_s4;
   assign wstrb_s[4] = wstrb_s4;

   assign rdata_s[4] = rdata_s4;
   assign rid_s[4]   = rid_s4;
   assign rresp_s[4] = rresp_s4;

   assign bid_s[4]   = bid_s4;
   assign bresp_s[4] = bresp_s4;

   assign #1 arvalid_s_bus[3] = arvalid_s[4];
   assign araddr_s_bus[ ((3 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(3*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s4;
   assign arlen_s_bus[  ((3 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(3*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s4;
   assign arsize_s_bus[ ((3 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(3*`SVT_AXI_SIZE_WIDTH  )] = arsize_s4;
   assign arburst_s_bus[((3 + 1) * `SVT_AXI_BURST_WIDTH)-1:(3*`SVT_AXI_BURST_WIDTH )] = arburst_s4;
   assign arlock_s_bus[ ((3 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(3*`SVT_AXI_LOCK_WIDTH  )] = arlock_s4;
   assign arcache_s_bus[((3 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(3*`SVT_AXI_CACHE_WIDTH )] = arcache_s4;
   assign arprot_s_bus[ ((3 + 1) * `SVT_AXI_PROT_WIDTH) -1:(3*`SVT_AXI_PROT_WIDTH  )] = arprot_s4;
   assign arid_s_bus[ ((3 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(3*`SVT_AXI_MAX_ID_WIDTH)] = arid_s4;
   assign arready_s[4] = arready_s_bus[3];
  `ifdef AXI_REGIONS_S4

    assign arregion_s_bus[ ((3 + 1) * `SVT_AXI_REGION_WIDTH) -1:(3*`SVT_AXI_REGION_WIDTH ) ] = arregion_s4;
    assign awregion_s_bus[ ((3 + 1) * `SVT_AXI_REGION_WIDTH) -1:(3*`SVT_AXI_REGION_WIDTH ) ] = awregion_s4;
  `endif  

   assign #1 awvalid_s_bus[3] = awvalid_s[4];
   assign awaddr_s_bus[ ((3 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(3*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s4;
   assign awlen_s_bus[  ((3 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(3*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s4;
   assign awsize_s_bus[ ((3 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(3*`SVT_AXI_SIZE_WIDTH  )] = awsize_s4;
   assign awburst_s_bus[((3 + 1) * `SVT_AXI_BURST_WIDTH)-1:(3*`SVT_AXI_BURST_WIDTH )] = awburst_s4;
   assign awlock_s_bus[ ((3 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(3*`SVT_AXI_LOCK_WIDTH  )] = awlock_s4;
   assign awcache_s_bus[((3 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(3*`SVT_AXI_CACHE_WIDTH )] = awcache_s4;
   assign awprot_s_bus[ ((3 + 1) * `SVT_AXI_PROT_WIDTH) -1:(3*`SVT_AXI_PROT_WIDTH  )] = awprot_s4;
   assign awid_s_bus[ ((3 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(3*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s4;
   assign awready_s[4] =  awready_s_bus[3];

   assign rvalid_s[4]= rvalid_s_bus[3];
   assign rlast_s[4] = rlast_s_bus[3];
   assign rdata_s4 = rdata_s_bus[((3 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(3*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s4 = rresp_s_bus[((3 + 1) * `SVT_AXI_RESP_WIDTH)-1:(3*`SVT_AXI_RESP_WIDTH)];
   assign rid_s4   = rid_s_bus[((3 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(3*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[3] = rready_s[4];

   assign wvalid_s_bus[3] = wvalid_s[4];
   assign wlast_s_bus[3]  = wlast_s[4];
   assign wdata_s_bus[((3 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(3*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s4;
   assign wstrb_s_bus[((3 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(3*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s4;
   assign wid_s_bus[((3 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(3*`SVT_AXI_MAX_ID_WIDTH)] = wid_s4;
   assign wready_s[4] =  wready_s_bus[3];

   assign bvalid_s[4]=  bvalid_s_bus[3];
   assign bresp_s4 = bresp_s_bus[((3 + 1) * `SVT_AXI_RESP_WIDTH)-1:(3*`SVT_AXI_RESP_WIDTH)];
   assign bid_s4   = bid_s_bus[((3 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(3*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[3] = bready_s[4];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s4 = {8{rdata_s_bus[(3*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(3*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s4 = {64{bid_s_bus[(3*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(3*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((3 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(3 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s4;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((3 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(3 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s4;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((3 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(3 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s4;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s4 = ruser_s_bus[ ((3 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(3 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s4 = buser_s_bus[ ((3 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(3 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S5


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s5;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s5;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s5;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s5;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s5;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s5;
   `ifdef AXI_HAS_AXI4

     assign arlock_s5[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s5;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s5;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s5;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s5;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s5;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s5;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s5;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s5;
   `ifdef AXI_HAS_AXI4

     assign awlock_s5[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s5;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s5;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s5;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s5;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s5;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s5;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s5;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s5;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s5;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s5;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s5;
   assign arsideband_s[5] = arsideband_s5;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s5;
   assign awsideband_s[5] = awsideband_s5;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s5;
   assign rsideband_s[5] = rsideband_s5;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s5;
   assign wsideband_s[5] = wsideband_s5;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s5;
   assign bsideband_s[5] = bsideband_s5;
 `endif
`endif  
  `ifdef AXI_REGIONS_S5

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s5; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s5; 
    assign #1 awregion_s[5] = awregion_s5;
    assign #1 arregion_s[5] = arregion_s5;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s5;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s5;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s5;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s5;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s5;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s5;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s5;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s5;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s5;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s5;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s5;

     assign awdomain_s[5]       =       awdomain_s5;
     assign awsnoop_s[5]        =       awsnoop_s5;
     assign awbar_s[5]          =       awbar_s5;
     assign ardomain_s[5]       =       ardomain_s5;
     assign arsnoop_s[5]        =       arsnoop_s5;
     assign arbar_s[5]          =       arbar_s5;
   `endif    

   assign #1 araddr_s[5]  = araddr_s5;
   assign arid_s[5]    = arid_s5;
   assign arlen_s[5]   = arlen_s5;
   assign arsize_s[5]  = arsize_s5;
   assign arburst_s[5] = arburst_s5;
   assign arlock_s[5]  = arlock_s5;
   assign arprot_s[5]  = arprot_s5;
   assign arcache_s[5] = arcache_s5;

   assign #1 awaddr_s[5]  = awaddr_s5;
   assign awid_s[5]    = awid_s5;
   assign awlen_s[5]   = awlen_s5;
   assign awsize_s[5]  = awsize_s5;
   assign awburst_s[5] = awburst_s5;
   assign awlock_s[5]  = awlock_s5;
   assign awprot_s[5]  = awprot_s5;
   assign awcache_s[5] = awcache_s5;

   assign wdata_s[5] = wdata_s5;
   assign wid_s[5]   = wid_s5;
   assign wstrb_s[5] = wstrb_s5;

   assign rdata_s[5] = rdata_s5;
   assign rid_s[5]   = rid_s5;
   assign rresp_s[5] = rresp_s5;

   assign bid_s[5]   = bid_s5;
   assign bresp_s[5] = bresp_s5;

   assign #1 arvalid_s_bus[4] = arvalid_s[5];
   assign araddr_s_bus[ ((4 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(4*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s5;
   assign arlen_s_bus[  ((4 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(4*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s5;
   assign arsize_s_bus[ ((4 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(4*`SVT_AXI_SIZE_WIDTH  )] = arsize_s5;
   assign arburst_s_bus[((4 + 1) * `SVT_AXI_BURST_WIDTH)-1:(4*`SVT_AXI_BURST_WIDTH )] = arburst_s5;
   assign arlock_s_bus[ ((4 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(4*`SVT_AXI_LOCK_WIDTH  )] = arlock_s5;
   assign arcache_s_bus[((4 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(4*`SVT_AXI_CACHE_WIDTH )] = arcache_s5;
   assign arprot_s_bus[ ((4 + 1) * `SVT_AXI_PROT_WIDTH) -1:(4*`SVT_AXI_PROT_WIDTH  )] = arprot_s5;
   assign arid_s_bus[ ((4 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(4*`SVT_AXI_MAX_ID_WIDTH)] = arid_s5;
   assign arready_s[5] = arready_s_bus[4];
  `ifdef AXI_REGIONS_S5

    assign arregion_s_bus[ ((4 + 1) * `SVT_AXI_REGION_WIDTH) -1:(4*`SVT_AXI_REGION_WIDTH ) ] = arregion_s5;
    assign awregion_s_bus[ ((4 + 1) * `SVT_AXI_REGION_WIDTH) -1:(4*`SVT_AXI_REGION_WIDTH ) ] = awregion_s5;
  `endif  

   assign #1 awvalid_s_bus[4] = awvalid_s[5];
   assign awaddr_s_bus[ ((4 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(4*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s5;
   assign awlen_s_bus[  ((4 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(4*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s5;
   assign awsize_s_bus[ ((4 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(4*`SVT_AXI_SIZE_WIDTH  )] = awsize_s5;
   assign awburst_s_bus[((4 + 1) * `SVT_AXI_BURST_WIDTH)-1:(4*`SVT_AXI_BURST_WIDTH )] = awburst_s5;
   assign awlock_s_bus[ ((4 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(4*`SVT_AXI_LOCK_WIDTH  )] = awlock_s5;
   assign awcache_s_bus[((4 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(4*`SVT_AXI_CACHE_WIDTH )] = awcache_s5;
   assign awprot_s_bus[ ((4 + 1) * `SVT_AXI_PROT_WIDTH) -1:(4*`SVT_AXI_PROT_WIDTH  )] = awprot_s5;
   assign awid_s_bus[ ((4 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(4*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s5;
   assign awready_s[5] =  awready_s_bus[4];

   assign rvalid_s[5]= rvalid_s_bus[4];
   assign rlast_s[5] = rlast_s_bus[4];
   assign rdata_s5 = rdata_s_bus[((4 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(4*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s5 = rresp_s_bus[((4 + 1) * `SVT_AXI_RESP_WIDTH)-1:(4*`SVT_AXI_RESP_WIDTH)];
   assign rid_s5   = rid_s_bus[((4 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(4*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[4] = rready_s[5];

   assign wvalid_s_bus[4] = wvalid_s[5];
   assign wlast_s_bus[4]  = wlast_s[5];
   assign wdata_s_bus[((4 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(4*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s5;
   assign wstrb_s_bus[((4 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(4*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s5;
   assign wid_s_bus[((4 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(4*`SVT_AXI_MAX_ID_WIDTH)] = wid_s5;
   assign wready_s[5] =  wready_s_bus[4];

   assign bvalid_s[5]=  bvalid_s_bus[4];
   assign bresp_s5 = bresp_s_bus[((4 + 1) * `SVT_AXI_RESP_WIDTH)-1:(4*`SVT_AXI_RESP_WIDTH)];
   assign bid_s5   = bid_s_bus[((4 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(4*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[4] = bready_s[5];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s5 = {8{rdata_s_bus[(4*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(4*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s5 = {64{bid_s_bus[(4*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(4*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((4 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(4 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s5;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((4 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(4 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s5;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((4 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(4 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s5;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s5 = ruser_s_bus[ ((4 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(4 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s5 = buser_s_bus[ ((4 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(4 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S6


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s6;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s6;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s6;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s6;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s6;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s6;
   `ifdef AXI_HAS_AXI4

     assign arlock_s6[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s6;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s6;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s6;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s6;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s6;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s6;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s6;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s6;
   `ifdef AXI_HAS_AXI4

     assign awlock_s6[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s6;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s6;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s6;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s6;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s6;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s6;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s6;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s6;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s6;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s6;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s6;
   assign arsideband_s[6] = arsideband_s6;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s6;
   assign awsideband_s[6] = awsideband_s6;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s6;
   assign rsideband_s[6] = rsideband_s6;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s6;
   assign wsideband_s[6] = wsideband_s6;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s6;
   assign bsideband_s[6] = bsideband_s6;
 `endif
`endif 
  `ifdef AXI_REGIONS_S6

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s6; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s6; 
    assign #1 awregion_s[6] = awregion_s6;
    assign #1 arregion_s[6] = arregion_s6;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s6;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s6;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s6;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s6;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s6;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s6;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s6;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s6;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s6;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s6;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s6;

     assign awdomain_s[6]       =       awdomain_s6;
     assign awsnoop_s[6]        =       awsnoop_s6;
     assign awbar_s[6]          =       awbar_s6;
     assign ardomain_s[6]       =       ardomain_s6;
     assign arsnoop_s[6]        =       arsnoop_s6;
     assign arbar_s[6]          =       arbar_s6;
   `endif    

   assign #1 araddr_s[6]  = araddr_s6;
   assign arid_s[6]    = arid_s6;
   assign arlen_s[6]   = arlen_s6;
   assign arsize_s[6]  = arsize_s6;
   assign arburst_s[6] = arburst_s6;
   assign arlock_s[6]  = arlock_s6;
   assign arprot_s[6]  = arprot_s6;
   assign arcache_s[6] = arcache_s6;

   assign #1 awaddr_s[6]  = awaddr_s6;
   assign awid_s[6]    = awid_s6;
   assign awlen_s[6]   = awlen_s6;
   assign awsize_s[6]  = awsize_s6;
   assign awburst_s[6] = awburst_s6;
   assign awlock_s[6]  = awlock_s6;
   assign awprot_s[6]  = awprot_s6;
   assign awcache_s[6] = awcache_s6;

   assign wdata_s[6] = wdata_s6;
   assign wid_s[6]   = wid_s6;
   assign wstrb_s[6] = wstrb_s6;

   assign rdata_s[6] = rdata_s6;
   assign rid_s[6]   = rid_s6;
   assign rresp_s[6] = rresp_s6;

   assign bid_s[6]   = bid_s6;
   assign bresp_s[6] = bresp_s6;

   assign #1 arvalid_s_bus[5] = arvalid_s[6];
   assign araddr_s_bus[ ((5 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(5*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s6;
   assign arlen_s_bus[  ((5 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(5*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s6;
   assign arsize_s_bus[ ((5 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(5*`SVT_AXI_SIZE_WIDTH  )] = arsize_s6;
   assign arburst_s_bus[((5 + 1) * `SVT_AXI_BURST_WIDTH)-1:(5*`SVT_AXI_BURST_WIDTH )] = arburst_s6;
   assign arlock_s_bus[ ((5 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(5*`SVT_AXI_LOCK_WIDTH  )] = arlock_s6;
   assign arcache_s_bus[((5 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(5*`SVT_AXI_CACHE_WIDTH )] = arcache_s6;
   assign arprot_s_bus[ ((5 + 1) * `SVT_AXI_PROT_WIDTH) -1:(5*`SVT_AXI_PROT_WIDTH  )] = arprot_s6;
   assign arid_s_bus[ ((5 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(5*`SVT_AXI_MAX_ID_WIDTH)] = arid_s6;
   assign arready_s[6] = arready_s_bus[5];
  `ifdef AXI_REGIONS_S6

    assign arregion_s_bus[ ((5 + 1) * `SVT_AXI_REGION_WIDTH) -1:(5*`SVT_AXI_REGION_WIDTH ) ] = arregion_s6;
    assign awregion_s_bus[ ((5 + 1) * `SVT_AXI_REGION_WIDTH) -1:(5*`SVT_AXI_REGION_WIDTH ) ] = awregion_s6;
  `endif  

   assign #1 awvalid_s_bus[5] = awvalid_s[6];
   assign awaddr_s_bus[ ((5 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(5*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s6;
   assign awlen_s_bus[  ((5 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(5*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s6;
   assign awsize_s_bus[ ((5 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(5*`SVT_AXI_SIZE_WIDTH  )] = awsize_s6;
   assign awburst_s_bus[((5 + 1) * `SVT_AXI_BURST_WIDTH)-1:(5*`SVT_AXI_BURST_WIDTH )] = awburst_s6;
   assign awlock_s_bus[ ((5 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(5*`SVT_AXI_LOCK_WIDTH  )] = awlock_s6;
   assign awcache_s_bus[((5 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(5*`SVT_AXI_CACHE_WIDTH )] = awcache_s6;
   assign awprot_s_bus[ ((5 + 1) * `SVT_AXI_PROT_WIDTH) -1:(5*`SVT_AXI_PROT_WIDTH  )] = awprot_s6;
   assign awid_s_bus[ ((5 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(5*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s6;
   assign awready_s[6] =  awready_s_bus[5];

   assign rvalid_s[6]= rvalid_s_bus[5];
   assign rlast_s[6] = rlast_s_bus[5];
   assign rdata_s6 = rdata_s_bus[((5 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(5*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s6 = rresp_s_bus[((5 + 1) * `SVT_AXI_RESP_WIDTH)-1:(5*`SVT_AXI_RESP_WIDTH)];
   assign rid_s6   = rid_s_bus[((5 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(5*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[5] = rready_s[6];

   assign wvalid_s_bus[5] = wvalid_s[6];
   assign wlast_s_bus[5]  = wlast_s[6];
   assign wdata_s_bus[((5 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(5*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s6;
   assign wstrb_s_bus[((5 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(5*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s6;
   assign wid_s_bus[((5 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(5*`SVT_AXI_MAX_ID_WIDTH)] = wid_s6;
   assign wready_s[6] =  wready_s_bus[5];

   assign bvalid_s[6]=  bvalid_s_bus[5];
   assign bresp_s6 = bresp_s_bus[((5 + 1) * `SVT_AXI_RESP_WIDTH)-1:(5*`SVT_AXI_RESP_WIDTH)];
   assign bid_s6   = bid_s_bus[((5 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(5*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[5] = bready_s[6];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s6 = {8{rdata_s_bus[(5*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(5*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s6 = {64{bid_s_bus[(5*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(5*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((5 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(5 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s6;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((5 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(5 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s6;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((5 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(5 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s6;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s6 = ruser_s_bus[ ((5 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(5 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s6 = buser_s_bus[ ((5 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(5 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S7


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s7;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s7;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s7;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s7;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s7;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s7;
   `ifdef AXI_HAS_AXI4

     assign arlock_s7[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s7;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s7;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s7;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s7;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s7;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s7;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s7;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s7;
   `ifdef AXI_HAS_AXI4

     assign awlock_s7[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s7;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s7;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s7;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s7;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s7;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s7;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s7;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s7;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s7;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s7;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s7;
   assign arsideband_s[7] = arsideband_s7;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s7;
   assign awsideband_s[7] = awsideband_s7;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s7;
   assign rsideband_s[7] = rsideband_s7;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s7;
   assign wsideband_s[7] = wsideband_s7;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s7;
   assign bsideband_s[7] = bsideband_s7;
 `endif
`endif
  `ifdef AXI_REGIONS_S7

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s7; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s7; 
    assign #1 awregion_s[7] = awregion_s7;
    assign #1 arregion_s[7] = arregion_s7;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s7;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s7;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s7;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s7;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s7;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s7;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s7;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s7;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s7;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s7;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s7;

     assign awdomain_s[7]       =       awdomain_s7;
     assign awsnoop_s[7]        =       awsnoop_s7;
     assign awbar_s[7]          =       awbar_s7;
     assign ardomain_s[7]       =       ardomain_s7;
     assign arsnoop_s[7]        =       arsnoop_s7;
     assign arbar_s[7]          =       arbar_s7;
   `endif    

   assign #1 araddr_s[7]  = araddr_s7;
   assign arid_s[7]    = arid_s7;
   assign arlen_s[7]   = arlen_s7;
   assign arsize_s[7]  = arsize_s7;
   assign arburst_s[7] = arburst_s7;
   assign arlock_s[7]  = arlock_s7;
   assign arprot_s[7]  = arprot_s7;
   assign arcache_s[7] = arcache_s7;

   assign #1 awaddr_s[7]  = awaddr_s7;
   assign awid_s[7]    = awid_s7;
   assign awlen_s[7]   = awlen_s7;
   assign awsize_s[7]  = awsize_s7;
   assign awburst_s[7] = awburst_s7;
   assign awlock_s[7]  = awlock_s7;
   assign awprot_s[7]  = awprot_s7;
   assign awcache_s[7] = awcache_s7;

   assign wdata_s[7] = wdata_s7;
   assign wid_s[7]   = wid_s7;
   assign wstrb_s[7] = wstrb_s7;

   assign rdata_s[7] = rdata_s7;
   assign rid_s[7]   = rid_s7;
   assign rresp_s[7] = rresp_s7;

   assign bid_s[7]   = bid_s7;
   assign bresp_s[7] = bresp_s7;

   assign #1 arvalid_s_bus[6] = arvalid_s[7];
   assign araddr_s_bus[ ((6 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(6*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s7;
   assign arlen_s_bus[  ((6 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(6*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s7;
   assign arsize_s_bus[ ((6 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(6*`SVT_AXI_SIZE_WIDTH  )] = arsize_s7;
   assign arburst_s_bus[((6 + 1) * `SVT_AXI_BURST_WIDTH)-1:(6*`SVT_AXI_BURST_WIDTH )] = arburst_s7;
   assign arlock_s_bus[ ((6 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(6*`SVT_AXI_LOCK_WIDTH  )] = arlock_s7;
   assign arcache_s_bus[((6 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(6*`SVT_AXI_CACHE_WIDTH )] = arcache_s7;
   assign arprot_s_bus[ ((6 + 1) * `SVT_AXI_PROT_WIDTH) -1:(6*`SVT_AXI_PROT_WIDTH  )] = arprot_s7;
   assign arid_s_bus[ ((6 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(6*`SVT_AXI_MAX_ID_WIDTH)] = arid_s7;
   assign arready_s[7] = arready_s_bus[6];
  `ifdef AXI_REGIONS_S7

    assign arregion_s_bus[ ((6 + 1) * `SVT_AXI_REGION_WIDTH) -1:(6*`SVT_AXI_REGION_WIDTH ) ] = arregion_s7;
    assign awregion_s_bus[ ((6 + 1) * `SVT_AXI_REGION_WIDTH) -1:(6*`SVT_AXI_REGION_WIDTH ) ] = awregion_s7;
  `endif  

   assign #1 awvalid_s_bus[6] = awvalid_s[7];
   assign awaddr_s_bus[ ((6 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(6*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s7;
   assign awlen_s_bus[  ((6 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(6*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s7;
   assign awsize_s_bus[ ((6 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(6*`SVT_AXI_SIZE_WIDTH  )] = awsize_s7;
   assign awburst_s_bus[((6 + 1) * `SVT_AXI_BURST_WIDTH)-1:(6*`SVT_AXI_BURST_WIDTH )] = awburst_s7;
   assign awlock_s_bus[ ((6 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(6*`SVT_AXI_LOCK_WIDTH  )] = awlock_s7;
   assign awcache_s_bus[((6 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(6*`SVT_AXI_CACHE_WIDTH )] = awcache_s7;
   assign awprot_s_bus[ ((6 + 1) * `SVT_AXI_PROT_WIDTH) -1:(6*`SVT_AXI_PROT_WIDTH  )] = awprot_s7;
   assign awid_s_bus[ ((6 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(6*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s7;
   assign awready_s[7] =  awready_s_bus[6];

   assign rvalid_s[7]= rvalid_s_bus[6];
   assign rlast_s[7] = rlast_s_bus[6];
   assign rdata_s7 = rdata_s_bus[((6 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(6*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s7 = rresp_s_bus[((6 + 1) * `SVT_AXI_RESP_WIDTH)-1:(6*`SVT_AXI_RESP_WIDTH)];
   assign rid_s7   = rid_s_bus[((6 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(6*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[6] = rready_s[7];

   assign wvalid_s_bus[6] = wvalid_s[7];
   assign wlast_s_bus[6]  = wlast_s[7];
   assign wdata_s_bus[((6 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(6*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s7;
   assign wstrb_s_bus[((6 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(6*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s7;
   assign wid_s_bus[((6 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(6*`SVT_AXI_MAX_ID_WIDTH)] = wid_s7;
   assign wready_s[7] =  wready_s_bus[6];

   assign bvalid_s[7]=  bvalid_s_bus[6];
   assign bresp_s7 = bresp_s_bus[((6 + 1) * `SVT_AXI_RESP_WIDTH)-1:(6*`SVT_AXI_RESP_WIDTH)];
   assign bid_s7   = bid_s_bus[((6 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(6*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[6] = bready_s[7];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s7 = {8{rdata_s_bus[(6*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(6*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s7 = {64{bid_s_bus[(6*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(6*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((6 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(6 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s7;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((6 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(6 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s7;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((6 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(6 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s7;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s7 = ruser_s_bus[ ((6 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(6 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s7 = buser_s_bus[ ((6 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(6 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S8


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s8;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s8;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s8;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s8;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s8;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s8;
   `ifdef AXI_HAS_AXI4

     assign arlock_s8[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s8;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s8;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s8;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s8;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s8;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s8;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s8;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s8;
   `ifdef AXI_HAS_AXI4

     assign awlock_s8[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s8;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s8;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s8;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s8;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s8;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s8;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s8;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s8;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s8;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s8;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s8;
   assign arsideband_s[8] = arsideband_s8;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s8;
   assign awsideband_s[8] = awsideband_s8;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s8;
   assign rsideband_s[8] = rsideband_s8;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s8;
   assign wsideband_s[8] = wsideband_s8;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s8;
   assign bsideband_s[8] = bsideband_s8;
 `endif
`endif
  `ifdef AXI_REGIONS_S8

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s8; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s8; 
    assign #1 awregion_s[8] = awregion_s8;
    assign #1 arregion_s[8] = arregion_s8;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s8;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s8;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s8;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s8;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s8;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s8;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s8;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s8;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s8;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s8;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s8;

     assign awdomain_s[8]       =       awdomain_s8;
     assign awsnoop_s[8]        =       awsnoop_s8;
     assign awbar_s[8]          =       awbar_s8;
     assign ardomain_s[8]       =       ardomain_s8;
     assign arsnoop_s[8]        =       arsnoop_s8;
     assign arbar_s[8]          =       arbar_s8;
   `endif    

   assign #1 araddr_s[8]  = araddr_s8;
   assign arid_s[8]    = arid_s8;
   assign arlen_s[8]   = arlen_s8;
   assign arsize_s[8]  = arsize_s8;
   assign arburst_s[8] = arburst_s8;
   assign arlock_s[8]  = arlock_s8;
   assign arprot_s[8]  = arprot_s8;
   assign arcache_s[8] = arcache_s8;

   assign #1 awaddr_s[8]  = awaddr_s8;
   assign awid_s[8]    = awid_s8;
   assign awlen_s[8]   = awlen_s8;
   assign awsize_s[8]  = awsize_s8;
   assign awburst_s[8] = awburst_s8;
   assign awlock_s[8]  = awlock_s8;
   assign awprot_s[8]  = awprot_s8;
   assign awcache_s[8] = awcache_s8;

   assign wdata_s[8] = wdata_s8;
   assign wid_s[8]   = wid_s8;
   assign wstrb_s[8] = wstrb_s8;

   assign rdata_s[8] = rdata_s8;
   assign rid_s[8]   = rid_s8;
   assign rresp_s[8] = rresp_s8;

   assign bid_s[8]   = bid_s8;
   assign bresp_s[8] = bresp_s8;

   assign #1 arvalid_s_bus[7] = arvalid_s[8];
   assign araddr_s_bus[ ((7 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(7*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s8;
   assign arlen_s_bus[  ((7 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(7*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s8;
   assign arsize_s_bus[ ((7 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(7*`SVT_AXI_SIZE_WIDTH  )] = arsize_s8;
   assign arburst_s_bus[((7 + 1) * `SVT_AXI_BURST_WIDTH)-1:(7*`SVT_AXI_BURST_WIDTH )] = arburst_s8;
   assign arlock_s_bus[ ((7 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(7*`SVT_AXI_LOCK_WIDTH  )] = arlock_s8;
   assign arcache_s_bus[((7 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(7*`SVT_AXI_CACHE_WIDTH )] = arcache_s8;
   assign arprot_s_bus[ ((7 + 1) * `SVT_AXI_PROT_WIDTH) -1:(7*`SVT_AXI_PROT_WIDTH  )] = arprot_s8;
   assign arid_s_bus[ ((7 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(7*`SVT_AXI_MAX_ID_WIDTH)] = arid_s8;
   assign arready_s[8] = arready_s_bus[7];
  `ifdef AXI_REGIONS_S8

    assign arregion_s_bus[ ((7 + 1) * `SVT_AXI_REGION_WIDTH) -1:(7*`SVT_AXI_REGION_WIDTH ) ] = arregion_s8;
    assign awregion_s_bus[ ((7 + 1) * `SVT_AXI_REGION_WIDTH) -1:(7*`SVT_AXI_REGION_WIDTH ) ] = awregion_s8;
  `endif  

   assign #1 awvalid_s_bus[7] = awvalid_s[8];
   assign awaddr_s_bus[ ((7 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(7*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s8;
   assign awlen_s_bus[  ((7 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(7*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s8;
   assign awsize_s_bus[ ((7 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(7*`SVT_AXI_SIZE_WIDTH  )] = awsize_s8;
   assign awburst_s_bus[((7 + 1) * `SVT_AXI_BURST_WIDTH)-1:(7*`SVT_AXI_BURST_WIDTH )] = awburst_s8;
   assign awlock_s_bus[ ((7 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(7*`SVT_AXI_LOCK_WIDTH  )] = awlock_s8;
   assign awcache_s_bus[((7 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(7*`SVT_AXI_CACHE_WIDTH )] = awcache_s8;
   assign awprot_s_bus[ ((7 + 1) * `SVT_AXI_PROT_WIDTH) -1:(7*`SVT_AXI_PROT_WIDTH  )] = awprot_s8;
   assign awid_s_bus[ ((7 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(7*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s8;
   assign awready_s[8] =  awready_s_bus[7];

   assign rvalid_s[8]= rvalid_s_bus[7];
   assign rlast_s[8] = rlast_s_bus[7];
   assign rdata_s8 = rdata_s_bus[((7 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(7*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s8 = rresp_s_bus[((7 + 1) * `SVT_AXI_RESP_WIDTH)-1:(7*`SVT_AXI_RESP_WIDTH)];
   assign rid_s8   = rid_s_bus[((7 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(7*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[7] = rready_s[8];

   assign wvalid_s_bus[7] = wvalid_s[8];
   assign wlast_s_bus[7]  = wlast_s[8];
   assign wdata_s_bus[((7 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(7*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s8;
   assign wstrb_s_bus[((7 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(7*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s8;
   assign wid_s_bus[((7 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(7*`SVT_AXI_MAX_ID_WIDTH)] = wid_s8;
   assign wready_s[8] =  wready_s_bus[7];

   assign bvalid_s[8]=  bvalid_s_bus[7];
   assign bresp_s8 = bresp_s_bus[((7 + 1) * `SVT_AXI_RESP_WIDTH)-1:(7*`SVT_AXI_RESP_WIDTH)];
   assign bid_s8   = bid_s_bus[((7 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(7*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[7] = bready_s[8];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s8 = {8{rdata_s_bus[(7*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(7*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s8 = {64{bid_s_bus[(7*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(7*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((7 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(7 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s8;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((7 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(7 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s8;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((7 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(7 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s8;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s8 = ruser_s_bus[ ((7 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(7 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s8 = buser_s_bus[ ((7 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(7 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S9


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s9;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s9;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s9;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s9;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s9;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s9;
   `ifdef AXI_HAS_AXI4

     assign arlock_s9[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s9;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s9;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s9;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s9;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s9;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s9;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s9;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s9;
   `ifdef AXI_HAS_AXI4

     assign awlock_s9[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s9;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s9;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s9;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s9;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s9;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s9;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s9;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s9;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s9;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s9;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s9;
   assign arsideband_s[9] = arsideband_s9;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s9;
   assign awsideband_s[9] = awsideband_s9;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s9;
   assign rsideband_s[9] = rsideband_s9;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s9;
   assign wsideband_s[9] = wsideband_s9;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s9;
   assign bsideband_s[9] = bsideband_s9;
 `endif
`endif 
  `ifdef AXI_REGIONS_S9

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s9; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s9; 
    assign #1 awregion_s[9] = awregion_s9;
    assign #1 arregion_s[9] = arregion_s9;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s9;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s9;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s9;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s9;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s9;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s9;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s9;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s9;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s9;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s9;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s9;

     assign awdomain_s[9]       =       awdomain_s9;
     assign awsnoop_s[9]        =       awsnoop_s9;
     assign awbar_s[9]          =       awbar_s9;
     assign ardomain_s[9]       =       ardomain_s9;
     assign arsnoop_s[9]        =       arsnoop_s9;
     assign arbar_s[9]          =       arbar_s9;
   `endif    

   assign #1 araddr_s[9]  = araddr_s9;
   assign arid_s[9]    = arid_s9;
   assign arlen_s[9]   = arlen_s9;
   assign arsize_s[9]  = arsize_s9;
   assign arburst_s[9] = arburst_s9;
   assign arlock_s[9]  = arlock_s9;
   assign arprot_s[9]  = arprot_s9;
   assign arcache_s[9] = arcache_s9;

   assign #1 awaddr_s[9]  = awaddr_s9;
   assign awid_s[9]    = awid_s9;
   assign awlen_s[9]   = awlen_s9;
   assign awsize_s[9]  = awsize_s9;
   assign awburst_s[9] = awburst_s9;
   assign awlock_s[9]  = awlock_s9;
   assign awprot_s[9]  = awprot_s9;
   assign awcache_s[9] = awcache_s9;

   assign wdata_s[9] = wdata_s9;
   assign wid_s[9]   = wid_s9;
   assign wstrb_s[9] = wstrb_s9;

   assign rdata_s[9] = rdata_s9;
   assign rid_s[9]   = rid_s9;
   assign rresp_s[9] = rresp_s9;

   assign bid_s[9]   = bid_s9;
   assign bresp_s[9] = bresp_s9;

   assign #1 arvalid_s_bus[8] = arvalid_s[9];
   assign araddr_s_bus[ ((8 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(8*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s9;
   assign arlen_s_bus[  ((8 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(8*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s9;
   assign arsize_s_bus[ ((8 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(8*`SVT_AXI_SIZE_WIDTH  )] = arsize_s9;
   assign arburst_s_bus[((8 + 1) * `SVT_AXI_BURST_WIDTH)-1:(8*`SVT_AXI_BURST_WIDTH )] = arburst_s9;
   assign arlock_s_bus[ ((8 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(8*`SVT_AXI_LOCK_WIDTH  )] = arlock_s9;
   assign arcache_s_bus[((8 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(8*`SVT_AXI_CACHE_WIDTH )] = arcache_s9;
   assign arprot_s_bus[ ((8 + 1) * `SVT_AXI_PROT_WIDTH) -1:(8*`SVT_AXI_PROT_WIDTH  )] = arprot_s9;
   assign arid_s_bus[ ((8 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(8*`SVT_AXI_MAX_ID_WIDTH)] = arid_s9;
   assign arready_s[9] = arready_s_bus[8];
  `ifdef AXI_REGIONS_S9

    assign arregion_s_bus[ ((8 + 1) * `SVT_AXI_REGION_WIDTH) -1:(8*`SVT_AXI_REGION_WIDTH ) ] = arregion_s9;
    assign awregion_s_bus[ ((8 + 1) * `SVT_AXI_REGION_WIDTH) -1:(8*`SVT_AXI_REGION_WIDTH ) ] = awregion_s9;
  `endif  

   assign #1 awvalid_s_bus[8] = awvalid_s[9];
   assign awaddr_s_bus[ ((8 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(8*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s9;
   assign awlen_s_bus[  ((8 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(8*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s9;
   assign awsize_s_bus[ ((8 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(8*`SVT_AXI_SIZE_WIDTH  )] = awsize_s9;
   assign awburst_s_bus[((8 + 1) * `SVT_AXI_BURST_WIDTH)-1:(8*`SVT_AXI_BURST_WIDTH )] = awburst_s9;
   assign awlock_s_bus[ ((8 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(8*`SVT_AXI_LOCK_WIDTH  )] = awlock_s9;
   assign awcache_s_bus[((8 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(8*`SVT_AXI_CACHE_WIDTH )] = awcache_s9;
   assign awprot_s_bus[ ((8 + 1) * `SVT_AXI_PROT_WIDTH) -1:(8*`SVT_AXI_PROT_WIDTH  )] = awprot_s9;
   assign awid_s_bus[ ((8 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(8*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s9;
   assign awready_s[9] =  awready_s_bus[8];

   assign rvalid_s[9]= rvalid_s_bus[8];
   assign rlast_s[9] = rlast_s_bus[8];
   assign rdata_s9 = rdata_s_bus[((8 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(8*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s9 = rresp_s_bus[((8 + 1) * `SVT_AXI_RESP_WIDTH)-1:(8*`SVT_AXI_RESP_WIDTH)];
   assign rid_s9   = rid_s_bus[((8 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(8*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[8] = rready_s[9];

   assign wvalid_s_bus[8] = wvalid_s[9];
   assign wlast_s_bus[8]  = wlast_s[9];
   assign wdata_s_bus[((8 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(8*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s9;
   assign wstrb_s_bus[((8 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(8*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s9;
   assign wid_s_bus[((8 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(8*`SVT_AXI_MAX_ID_WIDTH)] = wid_s9;
   assign wready_s[9] =  wready_s_bus[8];

   assign bvalid_s[9]=  bvalid_s_bus[8];
   assign bresp_s9 = bresp_s_bus[((8 + 1) * `SVT_AXI_RESP_WIDTH)-1:(8*`SVT_AXI_RESP_WIDTH)];
   assign bid_s9   = bid_s_bus[((8 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(8*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[8] = bready_s[9];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s9 = {8{rdata_s_bus[(8*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(8*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s9 = {64{bid_s_bus[(8*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(8*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((8 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(8 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s9;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((8 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(8 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s9;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((8 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(8 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s9;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s9 = ruser_s_bus[ ((8 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(8 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s9 = buser_s_bus[ ((8 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(8 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif  //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S10


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s10;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s10;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s10;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s10;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s10;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s10;
   `ifdef AXI_HAS_AXI4

     assign arlock_s10[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s10;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s10;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s10;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s10;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s10;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s10;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s10;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s10;
   `ifdef AXI_HAS_AXI4

     assign awlock_s10[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s10;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s10;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s10;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s10;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s10;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s10;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s10;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s10;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s10;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s10;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s10;
   assign arsideband_s[10] = arsideband_s10;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s10;
   assign awsideband_s[10] = awsideband_s10;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s10;
   assign rsideband_s[10] = rsideband_s10;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s10;
   assign wsideband_s[10] = wsideband_s10;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s10;
   assign bsideband_s[10] = bsideband_s10;
 `endif
`endif
  `ifdef AXI_REGIONS_S10

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s10; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s10; 
    assign #1 awregion_s[10] = awregion_s10;
    assign #1 arregion_s[10] = arregion_s10;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s10;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s10;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s10;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s10;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s10;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s10;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s10;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s10;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s10;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s10;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s10;

     assign awdomain_s[10]       =       awdomain_s10;
     assign awsnoop_s[10]        =       awsnoop_s10;
     assign awbar_s[10]          =       awbar_s10;
     assign ardomain_s[10]       =       ardomain_s10;
     assign arsnoop_s[10]        =       arsnoop_s10;
     assign arbar_s[10]          =       arbar_s10;
   `endif    

   assign #1 araddr_s[10]  = araddr_s10;
   assign arid_s[10]    = arid_s10;
   assign arlen_s[10]   = arlen_s10;
   assign arsize_s[10]  = arsize_s10;
   assign arburst_s[10] = arburst_s10;
   assign arlock_s[10]  = arlock_s10;
   assign arprot_s[10]  = arprot_s10;
   assign arcache_s[10] = arcache_s10;

   assign #1 awaddr_s[10]  = awaddr_s10;
   assign awid_s[10]    = awid_s10;
   assign awlen_s[10]   = awlen_s10;
   assign awsize_s[10]  = awsize_s10;
   assign awburst_s[10] = awburst_s10;
   assign awlock_s[10]  = awlock_s10;
   assign awprot_s[10]  = awprot_s10;
   assign awcache_s[10] = awcache_s10;

   assign wdata_s[10] = wdata_s10;
   assign wid_s[10]   = wid_s10;
   assign wstrb_s[10] = wstrb_s10;

   assign rdata_s[10] = rdata_s10;
   assign rid_s[10]   = rid_s10;
   assign rresp_s[10] = rresp_s10;

   assign bid_s[10]   = bid_s10;
   assign bresp_s[10] = bresp_s10;

   assign #1 arvalid_s_bus[9] = arvalid_s[10];
   assign araddr_s_bus[ ((9 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(9*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s10;
   assign arlen_s_bus[  ((9 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(9*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s10;
   assign arsize_s_bus[ ((9 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(9*`SVT_AXI_SIZE_WIDTH  )] = arsize_s10;
   assign arburst_s_bus[((9 + 1) * `SVT_AXI_BURST_WIDTH)-1:(9*`SVT_AXI_BURST_WIDTH )] = arburst_s10;
   assign arlock_s_bus[ ((9 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(9*`SVT_AXI_LOCK_WIDTH  )] = arlock_s10;
   assign arcache_s_bus[((9 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(9*`SVT_AXI_CACHE_WIDTH )] = arcache_s10;
   assign arprot_s_bus[ ((9 + 1) * `SVT_AXI_PROT_WIDTH) -1:(9*`SVT_AXI_PROT_WIDTH  )] = arprot_s10;
   assign arid_s_bus[ ((9 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(9*`SVT_AXI_MAX_ID_WIDTH)] = arid_s10;
   assign arready_s[10] = arready_s_bus[9];
  `ifdef AXI_REGIONS_S10

    assign arregion_s_bus[ ((9 + 1) * `SVT_AXI_REGION_WIDTH) -1:(9*`SVT_AXI_REGION_WIDTH ) ] = arregion_s10;
    assign awregion_s_bus[ ((9 + 1) * `SVT_AXI_REGION_WIDTH) -1:(9*`SVT_AXI_REGION_WIDTH ) ] = awregion_s10;
  `endif  

   assign #1 awvalid_s_bus[9] = awvalid_s[10];
   assign awaddr_s_bus[ ((9 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(9*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s10;
   assign awlen_s_bus[  ((9 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(9*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s10;
   assign awsize_s_bus[ ((9 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(9*`SVT_AXI_SIZE_WIDTH  )] = awsize_s10;
   assign awburst_s_bus[((9 + 1) * `SVT_AXI_BURST_WIDTH)-1:(9*`SVT_AXI_BURST_WIDTH )] = awburst_s10;
   assign awlock_s_bus[ ((9 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(9*`SVT_AXI_LOCK_WIDTH  )] = awlock_s10;
   assign awcache_s_bus[((9 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(9*`SVT_AXI_CACHE_WIDTH )] = awcache_s10;
   assign awprot_s_bus[ ((9 + 1) * `SVT_AXI_PROT_WIDTH) -1:(9*`SVT_AXI_PROT_WIDTH  )] = awprot_s10;
   assign awid_s_bus[ ((9 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(9*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s10;
   assign awready_s[10] =  awready_s_bus[9];

   assign rvalid_s[10]= rvalid_s_bus[9];
   assign rlast_s[10] = rlast_s_bus[9];
   assign rdata_s10 = rdata_s_bus[((9 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(9*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s10 = rresp_s_bus[((9 + 1) * `SVT_AXI_RESP_WIDTH)-1:(9*`SVT_AXI_RESP_WIDTH)];
   assign rid_s10   = rid_s_bus[((9 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(9*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[9] = rready_s[10];

   assign wvalid_s_bus[9] = wvalid_s[10];
   assign wlast_s_bus[9]  = wlast_s[10];
   assign wdata_s_bus[((9 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(9*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s10;
   assign wstrb_s_bus[((9 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(9*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s10;
   assign wid_s_bus[((9 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(9*`SVT_AXI_MAX_ID_WIDTH)] = wid_s10;
   assign wready_s[10] =  wready_s_bus[9];

   assign bvalid_s[10]=  bvalid_s_bus[9];
   assign bresp_s10 = bresp_s_bus[((9 + 1) * `SVT_AXI_RESP_WIDTH)-1:(9*`SVT_AXI_RESP_WIDTH)];
   assign bid_s10   = bid_s_bus[((9 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(9*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[9] = bready_s[10];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s10 = {8{rdata_s_bus[(9*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(9*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s10 = {64{bid_s_bus[(9*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(9*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((9 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(9 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s10;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((9 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(9 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s10;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((9 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(9 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s10;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s10 = ruser_s_bus[ ((9 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(9 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s10 = buser_s_bus[ ((9 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(9 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif  //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S11


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s11;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s11;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s11;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s11;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s11;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s11;
   `ifdef AXI_HAS_AXI4

     assign arlock_s11[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s11;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s11;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s11;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s11;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s11;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s11;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s11;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s11;
   `ifdef AXI_HAS_AXI4

     assign awlock_s11[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s11;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s11;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s11;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s11;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s11;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s11;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s11;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s11;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s11;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s11;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s11;
   assign arsideband_s[11] = arsideband_s11;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s11;
   assign awsideband_s[11] = awsideband_s11;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s11;
   assign rsideband_s[11] = rsideband_s11;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s11;
   assign wsideband_s[11] = wsideband_s11;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s11;
   assign bsideband_s[11] = bsideband_s11;
 `endif
`endif
  `ifdef AXI_REGIONS_S11

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s11; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s11; 
    assign #1 awregion_s[11] = awregion_s11;
    assign #1 arregion_s[11] = arregion_s11;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s11;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s11;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s11;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s11;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s11;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s11;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s11;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s11;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s11;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s11;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s11;

     assign awdomain_s[11]       =       awdomain_s11;
     assign awsnoop_s[11]        =       awsnoop_s11;
     assign awbar_s[11]          =       awbar_s11;
     assign ardomain_s[11]       =       ardomain_s11;
     assign arsnoop_s[11]        =       arsnoop_s11;
     assign arbar_s[11]          =       arbar_s11;
   `endif    

   assign #1 araddr_s[11]  = araddr_s11;
   assign arid_s[11]    = arid_s11;
   assign arlen_s[11]   = arlen_s11;
   assign arsize_s[11]  = arsize_s11;
   assign arburst_s[11] = arburst_s11;
   assign arlock_s[11]  = arlock_s11;
   assign arprot_s[11]  = arprot_s11;
   assign arcache_s[11] = arcache_s11;

   assign #1 awaddr_s[11]  = awaddr_s11;
   assign awid_s[11]    = awid_s11;
   assign awlen_s[11]   = awlen_s11;
   assign awsize_s[11]  = awsize_s11;
   assign awburst_s[11] = awburst_s11;
   assign awlock_s[11]  = awlock_s11;
   assign awprot_s[11]  = awprot_s11;
   assign awcache_s[11] = awcache_s11;

   assign wdata_s[11] = wdata_s11;
   assign wid_s[11]   = wid_s11;
   assign wstrb_s[11] = wstrb_s11;

   assign rdata_s[11] = rdata_s11;
   assign rid_s[11]   = rid_s11;
   assign rresp_s[11] = rresp_s11;

   assign bid_s[11]   = bid_s11;
   assign bresp_s[11] = bresp_s11;

   assign #1 arvalid_s_bus[10] = arvalid_s[11];
   assign araddr_s_bus[ ((10 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(10*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s11;
   assign arlen_s_bus[  ((10 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(10*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s11;
   assign arsize_s_bus[ ((10 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(10*`SVT_AXI_SIZE_WIDTH  )] = arsize_s11;
   assign arburst_s_bus[((10 + 1) * `SVT_AXI_BURST_WIDTH)-1:(10*`SVT_AXI_BURST_WIDTH )] = arburst_s11;
   assign arlock_s_bus[ ((10 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(10*`SVT_AXI_LOCK_WIDTH  )] = arlock_s11;
   assign arcache_s_bus[((10 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(10*`SVT_AXI_CACHE_WIDTH )] = arcache_s11;
   assign arprot_s_bus[ ((10 + 1) * `SVT_AXI_PROT_WIDTH) -1:(10*`SVT_AXI_PROT_WIDTH  )] = arprot_s11;
   assign arid_s_bus[ ((10 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(10*`SVT_AXI_MAX_ID_WIDTH)] = arid_s11;
   assign arready_s[11] = arready_s_bus[10];
  `ifdef AXI_REGIONS_S11

    assign arregion_s_bus[ ((10 + 1) * `SVT_AXI_REGION_WIDTH) -1:(10*`SVT_AXI_REGION_WIDTH ) ] = arregion_s11;
    assign awregion_s_bus[ ((10 + 1) * `SVT_AXI_REGION_WIDTH) -1:(10*`SVT_AXI_REGION_WIDTH ) ] = awregion_s11;
  `endif  

   assign #1 awvalid_s_bus[10] = awvalid_s[11];
   assign awaddr_s_bus[ ((10 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(10*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s11;
   assign awlen_s_bus[  ((10 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(10*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s11;
   assign awsize_s_bus[ ((10 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(10*`SVT_AXI_SIZE_WIDTH  )] = awsize_s11;
   assign awburst_s_bus[((10 + 1) * `SVT_AXI_BURST_WIDTH)-1:(10*`SVT_AXI_BURST_WIDTH )] = awburst_s11;
   assign awlock_s_bus[ ((10 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(10*`SVT_AXI_LOCK_WIDTH  )] = awlock_s11;
   assign awcache_s_bus[((10 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(10*`SVT_AXI_CACHE_WIDTH )] = awcache_s11;
   assign awprot_s_bus[ ((10 + 1) * `SVT_AXI_PROT_WIDTH) -1:(10*`SVT_AXI_PROT_WIDTH  )] = awprot_s11;
   assign awid_s_bus[ ((10 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(10*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s11;
   assign awready_s[11] =  awready_s_bus[10];

   assign rvalid_s[11]= rvalid_s_bus[10];
   assign rlast_s[11] = rlast_s_bus[10];
   assign rdata_s11 = rdata_s_bus[((10 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(10*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s11 = rresp_s_bus[((10 + 1) * `SVT_AXI_RESP_WIDTH)-1:(10*`SVT_AXI_RESP_WIDTH)];
   assign rid_s11   = rid_s_bus[((10 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(10*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[10] = rready_s[11];

   assign wvalid_s_bus[10] = wvalid_s[11];
   assign wlast_s_bus[10]  = wlast_s[11];
   assign wdata_s_bus[((10 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(10*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s11;
   assign wstrb_s_bus[((10 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(10*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s11;
   assign wid_s_bus[((10 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(10*`SVT_AXI_MAX_ID_WIDTH)] = wid_s11;
   assign wready_s[11] =  wready_s_bus[10];

   assign bvalid_s[11]=  bvalid_s_bus[10];
   assign bresp_s11 = bresp_s_bus[((10 + 1) * `SVT_AXI_RESP_WIDTH)-1:(10*`SVT_AXI_RESP_WIDTH)];
   assign bid_s11   = bid_s_bus[((10 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(10*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[10] = bready_s[11];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s11 = {8{rdata_s_bus[(10*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(10*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s11 = {64{bid_s_bus[(10*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(10*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((10 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(10 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s11;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((10 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(10 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s11;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((10 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(10 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s11;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s11 = ruser_s_bus[ ((10 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(10 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s11 = buser_s_bus[ ((10 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(10 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif  //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S12


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s12;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s12;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s12;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s12;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s12;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s12;
   `ifdef AXI_HAS_AXI4

     assign arlock_s12[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s12;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s12;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s12;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s12;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s12;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s12;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s12;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s12;
   `ifdef AXI_HAS_AXI4

     assign awlock_s12[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s12;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s12;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s12;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s12;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s12;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s12;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s12;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s12;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s12;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s12;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s12;
   assign arsideband_s[12] = arsideband_s12;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s12;
   assign awsideband_s[12] = awsideband_s12;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s12;
   assign rsideband_s[12] = rsideband_s12;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s12;
   assign wsideband_s[12] = wsideband_s12;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s12;
   assign bsideband_s[12] = bsideband_s12;
 `endif
`endif
  `ifdef AXI_REGIONS_S12

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s12; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s12; 
    assign #1 awregion_s[12] = awregion_s12;
    assign #1 arregion_s[12] = arregion_s12;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s12;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s12;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s12;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s12;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s12;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s12;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s12;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s12;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s12;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s12;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s12;

     assign awdomain_s[12]       =       awdomain_s12;
     assign awsnoop_s[12]        =       awsnoop_s12;
     assign awbar_s[12]          =       awbar_s12;
     assign ardomain_s[12]       =       ardomain_s12;
     assign arsnoop_s[12]        =       arsnoop_s12;
     assign arbar_s[12]          =       arbar_s12;
   `endif    

   assign #1 araddr_s[12]  = araddr_s12;
   assign arid_s[12]    = arid_s12;
   assign arlen_s[12]   = arlen_s12;
   assign arsize_s[12]  = arsize_s12;
   assign arburst_s[12] = arburst_s12;
   assign arlock_s[12]  = arlock_s12;
   assign arprot_s[12]  = arprot_s12;
   assign arcache_s[12] = arcache_s12;

   assign #1 awaddr_s[12]  = awaddr_s12;
   assign awid_s[12]    = awid_s12;
   assign awlen_s[12]   = awlen_s12;
   assign awsize_s[12]  = awsize_s12;
   assign awburst_s[12] = awburst_s12;
   assign awlock_s[12]  = awlock_s12;
   assign awprot_s[12]  = awprot_s12;
   assign awcache_s[12] = awcache_s12;

   assign wdata_s[12] = wdata_s12;
   assign wid_s[12]   = wid_s12;
   assign wstrb_s[12] = wstrb_s12;

   assign rdata_s[12] = rdata_s12;
   assign rid_s[12]   = rid_s12;
   assign rresp_s[12] = rresp_s12;

   assign bid_s[12]   = bid_s12;
   assign bresp_s[12] = bresp_s12;

   assign #1 arvalid_s_bus[11] = arvalid_s[12];
   assign araddr_s_bus[ ((11 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(11*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s12;
   assign arlen_s_bus[  ((11 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(11*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s12;
   assign arsize_s_bus[ ((11 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(11*`SVT_AXI_SIZE_WIDTH  )] = arsize_s12;
   assign arburst_s_bus[((11 + 1) * `SVT_AXI_BURST_WIDTH)-1:(11*`SVT_AXI_BURST_WIDTH )] = arburst_s12;
   assign arlock_s_bus[ ((11 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(11*`SVT_AXI_LOCK_WIDTH  )] = arlock_s12;
   assign arcache_s_bus[((11 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(11*`SVT_AXI_CACHE_WIDTH )] = arcache_s12;
   assign arprot_s_bus[ ((11 + 1) * `SVT_AXI_PROT_WIDTH) -1:(11*`SVT_AXI_PROT_WIDTH  )] = arprot_s12;
   assign arid_s_bus[ ((11 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(11*`SVT_AXI_MAX_ID_WIDTH)] = arid_s12;
   assign arready_s[12] = arready_s_bus[11];
  `ifdef AXI_REGIONS_S12

    assign arregion_s_bus[ ((11 + 1) * `SVT_AXI_REGION_WIDTH) -1:(11*`SVT_AXI_REGION_WIDTH ) ] = arregion_s12;
    assign awregion_s_bus[ ((11 + 1) * `SVT_AXI_REGION_WIDTH) -1:(11*`SVT_AXI_REGION_WIDTH ) ] = awregion_s12;
  `endif  

   assign #1 awvalid_s_bus[11] = awvalid_s[12];
   assign awaddr_s_bus[ ((11 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(11*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s12;
   assign awlen_s_bus[  ((11 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(11*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s12;
   assign awsize_s_bus[ ((11 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(11*`SVT_AXI_SIZE_WIDTH  )] = awsize_s12;
   assign awburst_s_bus[((11 + 1) * `SVT_AXI_BURST_WIDTH)-1:(11*`SVT_AXI_BURST_WIDTH )] = awburst_s12;
   assign awlock_s_bus[ ((11 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(11*`SVT_AXI_LOCK_WIDTH  )] = awlock_s12;
   assign awcache_s_bus[((11 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(11*`SVT_AXI_CACHE_WIDTH )] = awcache_s12;
   assign awprot_s_bus[ ((11 + 1) * `SVT_AXI_PROT_WIDTH) -1:(11*`SVT_AXI_PROT_WIDTH  )] = awprot_s12;
   assign awid_s_bus[ ((11 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(11*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s12;
   assign awready_s[12] =  awready_s_bus[11];

   assign rvalid_s[12]= rvalid_s_bus[11];
   assign rlast_s[12] = rlast_s_bus[11];
   assign rdata_s12 = rdata_s_bus[((11 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(11*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s12 = rresp_s_bus[((11 + 1) * `SVT_AXI_RESP_WIDTH)-1:(11*`SVT_AXI_RESP_WIDTH)];
   assign rid_s12   = rid_s_bus[((11 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(11*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[11] = rready_s[12];

   assign wvalid_s_bus[11] = wvalid_s[12];
   assign wlast_s_bus[11]  = wlast_s[12];
   assign wdata_s_bus[((11 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(11*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s12;
   assign wstrb_s_bus[((11 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(11*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s12;
   assign wid_s_bus[((11 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(11*`SVT_AXI_MAX_ID_WIDTH)] = wid_s12;
   assign wready_s[12] =  wready_s_bus[11];

   assign bvalid_s[12]=  bvalid_s_bus[11];
   assign bresp_s12 = bresp_s_bus[((11 + 1) * `SVT_AXI_RESP_WIDTH)-1:(11*`SVT_AXI_RESP_WIDTH)];
   assign bid_s12   = bid_s_bus[((11 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(11*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[11] = bready_s[12];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s12 = {8{rdata_s_bus[(11*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(11*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s12 = {64{bid_s_bus[(11*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(11*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((11 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(11 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s12;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((11 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(11 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s12;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((11 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(11 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s12;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s12 = ruser_s_bus[ ((11 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(11 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s12 = buser_s_bus[ ((11 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(11 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S13


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s13;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s13;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s13;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s13;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s13;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s13;
   `ifdef AXI_HAS_AXI4

     assign arlock_s13[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s13;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s13;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s13;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s13;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s13;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s13;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s13;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s13;
   `ifdef AXI_HAS_AXI4

     assign awlock_s13[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s13;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s13;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s13;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s13;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s13;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s13;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s13;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s13;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s13;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s13;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s13;
   assign arsideband_s[13] = arsideband_s13;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s13;
   assign awsideband_s[13] = awsideband_s13;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s13;
   assign rsideband_s[13] = rsideband_s13;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s13;
   assign wsideband_s[13] = wsideband_s13;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s13;
   assign bsideband_s[13] = bsideband_s13;
 `endif
`endif
  `ifdef AXI_REGIONS_S13

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s13; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s13; 
    assign #1 awregion_s[13] = awregion_s13;
    assign #1 arregion_s[13] = arregion_s13;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s13;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s13;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s13;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s13;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s13;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s13;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s13;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s13;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s13;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s13;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s13;

     assign awdomain_s[13]       =       awdomain_s13;
     assign awsnoop_s[13]        =       awsnoop_s13;
     assign awbar_s[13]          =       awbar_s13;
     assign ardomain_s[13]       =       ardomain_s13;
     assign arsnoop_s[13]        =       arsnoop_s13;
     assign arbar_s[13]          =       arbar_s13;
   `endif    

   assign #1 araddr_s[13]  = araddr_s13;
   assign arid_s[13]    = arid_s13;
   assign arlen_s[13]   = arlen_s13;
   assign arsize_s[13]  = arsize_s13;
   assign arburst_s[13] = arburst_s13;
   assign arlock_s[13]  = arlock_s13;
   assign arprot_s[13]  = arprot_s13;
   assign arcache_s[13] = arcache_s13;

   assign #1 awaddr_s[13]  = awaddr_s13;
   assign awid_s[13]    = awid_s13;
   assign awlen_s[13]   = awlen_s13;
   assign awsize_s[13]  = awsize_s13;
   assign awburst_s[13] = awburst_s13;
   assign awlock_s[13]  = awlock_s13;
   assign awprot_s[13]  = awprot_s13;
   assign awcache_s[13] = awcache_s13;

   assign wdata_s[13] = wdata_s13;
   assign wid_s[13]   = wid_s13;
   assign wstrb_s[13] = wstrb_s13;

   assign rdata_s[13] = rdata_s13;
   assign rid_s[13]   = rid_s13;
   assign rresp_s[13] = rresp_s13;

   assign bid_s[13]   = bid_s13;
   assign bresp_s[13] = bresp_s13;

   assign #1 arvalid_s_bus[12] = arvalid_s[13];
   assign araddr_s_bus[ ((12 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(12*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s13;
   assign arlen_s_bus[  ((12 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(12*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s13;
   assign arsize_s_bus[ ((12 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(12*`SVT_AXI_SIZE_WIDTH  )] = arsize_s13;
   assign arburst_s_bus[((12 + 1) * `SVT_AXI_BURST_WIDTH)-1:(12*`SVT_AXI_BURST_WIDTH )] = arburst_s13;
   assign arlock_s_bus[ ((12 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(12*`SVT_AXI_LOCK_WIDTH  )] = arlock_s13;
   assign arcache_s_bus[((12 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(12*`SVT_AXI_CACHE_WIDTH )] = arcache_s13;
   assign arprot_s_bus[ ((12 + 1) * `SVT_AXI_PROT_WIDTH) -1:(12*`SVT_AXI_PROT_WIDTH  )] = arprot_s13;
   assign arid_s_bus[ ((12 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(12*`SVT_AXI_MAX_ID_WIDTH)] = arid_s13;
   assign arready_s[13] = arready_s_bus[12];
  `ifdef AXI_REGIONS_S13

    assign arregion_s_bus[ ((12 + 1) * `SVT_AXI_REGION_WIDTH) -1:(12*`SVT_AXI_REGION_WIDTH ) ] = arregion_s13;
    assign awregion_s_bus[ ((12 + 1) * `SVT_AXI_REGION_WIDTH) -1:(12*`SVT_AXI_REGION_WIDTH ) ] = awregion_s13;
  `endif  

   assign #1 awvalid_s_bus[12] = awvalid_s[13];
   assign awaddr_s_bus[ ((12 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(12*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s13;
   assign awlen_s_bus[  ((12 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(12*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s13;
   assign awsize_s_bus[ ((12 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(12*`SVT_AXI_SIZE_WIDTH  )] = awsize_s13;
   assign awburst_s_bus[((12 + 1) * `SVT_AXI_BURST_WIDTH)-1:(12*`SVT_AXI_BURST_WIDTH )] = awburst_s13;
   assign awlock_s_bus[ ((12 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(12*`SVT_AXI_LOCK_WIDTH  )] = awlock_s13;
   assign awcache_s_bus[((12 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(12*`SVT_AXI_CACHE_WIDTH )] = awcache_s13;
   assign awprot_s_bus[ ((12 + 1) * `SVT_AXI_PROT_WIDTH) -1:(12*`SVT_AXI_PROT_WIDTH  )] = awprot_s13;
   assign awid_s_bus[ ((12 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(12*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s13;
   assign awready_s[13] =  awready_s_bus[12];

   assign rvalid_s[13]= rvalid_s_bus[12];
   assign rlast_s[13] = rlast_s_bus[12];
   assign rdata_s13 = rdata_s_bus[((12 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(12*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s13 = rresp_s_bus[((12 + 1) * `SVT_AXI_RESP_WIDTH)-1:(12*`SVT_AXI_RESP_WIDTH)];
   assign rid_s13   = rid_s_bus[((12 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(12*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[12] = rready_s[13];

   assign wvalid_s_bus[12] = wvalid_s[13];
   assign wlast_s_bus[12]  = wlast_s[13];
   assign wdata_s_bus[((12 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(12*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s13;
   assign wstrb_s_bus[((12 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(12*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s13;
   assign wid_s_bus[((12 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(12*`SVT_AXI_MAX_ID_WIDTH)] = wid_s13;
   assign wready_s[13] =  wready_s_bus[12];

   assign bvalid_s[13]=  bvalid_s_bus[12];
   assign bresp_s13 = bresp_s_bus[((12 + 1) * `SVT_AXI_RESP_WIDTH)-1:(12*`SVT_AXI_RESP_WIDTH)];
   assign bid_s13   = bid_s_bus[((12 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(12*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[12] = bready_s[13];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s13 = {8{rdata_s_bus[(12*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(12*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s13 = {64{bid_s_bus[(12*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(12*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((12 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(12 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s13;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((12 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(12 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s13;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((12 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(12 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s13;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s13 = ruser_s_bus[ ((12 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(12 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s13 = buser_s_bus[ ((12 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(12 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif  //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S14


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s14;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s14;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s14;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s14;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s14;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s14;
   `ifdef AXI_HAS_AXI4

     assign arlock_s14[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s14;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s14;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s14;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s14;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s14;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s14;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s14;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s14;
   `ifdef AXI_HAS_AXI4

     assign awlock_s14[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s14;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s14;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s14;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s14;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s14;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s14;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s14;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s14;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s14;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s14;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s14;
   assign arsideband_s[14] = arsideband_s14;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s14;
   assign awsideband_s[14] = awsideband_s14;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s14;
   assign rsideband_s[14] = rsideband_s14;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s14;
   assign wsideband_s[14] = wsideband_s14;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s14;
   assign bsideband_s[14] = bsideband_s14;
 `endif
`endif
  `ifdef AXI_REGIONS_S14

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s14; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s14; 
    assign #1 awregion_s[14] = awregion_s14;
    assign #1 arregion_s[14] = arregion_s14;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s14;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s14;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s14;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s14;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s14;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s14;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s14;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s14;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s14;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s14;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s14;

     assign awdomain_s[14]       =       awdomain_s14;
     assign awsnoop_s[14]        =       awsnoop_s14;
     assign awbar_s[14]          =       awbar_s14;
     assign ardomain_s[14]       =       ardomain_s14;
     assign arsnoop_s[14]        =       arsnoop_s14;
     assign arbar_s[14]          =       arbar_s14;
   `endif    

   assign #1 araddr_s[14]  = araddr_s14;
   assign arid_s[14]    = arid_s14;
   assign arlen_s[14]   = arlen_s14;
   assign arsize_s[14]  = arsize_s14;
   assign arburst_s[14] = arburst_s14;
   assign arlock_s[14]  = arlock_s14;
   assign arprot_s[14]  = arprot_s14;
   assign arcache_s[14] = arcache_s14;

   assign #1 awaddr_s[14]  = awaddr_s14;
   assign awid_s[14]    = awid_s14;
   assign awlen_s[14]   = awlen_s14;
   assign awsize_s[14]  = awsize_s14;
   assign awburst_s[14] = awburst_s14;
   assign awlock_s[14]  = awlock_s14;
   assign awprot_s[14]  = awprot_s14;
   assign awcache_s[14] = awcache_s14;

   assign wdata_s[14] = wdata_s14;
   assign wid_s[14]   = wid_s14;
   assign wstrb_s[14] = wstrb_s14;

   assign rdata_s[14] = rdata_s14;
   assign rid_s[14]   = rid_s14;
   assign rresp_s[14] = rresp_s14;

   assign bid_s[14]   = bid_s14;
   assign bresp_s[14] = bresp_s14;

   assign #1 arvalid_s_bus[13] = arvalid_s[14];
   assign araddr_s_bus[ ((13 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(13*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s14;
   assign arlen_s_bus[  ((13 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(13*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s14;
   assign arsize_s_bus[ ((13 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(13*`SVT_AXI_SIZE_WIDTH  )] = arsize_s14;
   assign arburst_s_bus[((13 + 1) * `SVT_AXI_BURST_WIDTH)-1:(13*`SVT_AXI_BURST_WIDTH )] = arburst_s14;
   assign arlock_s_bus[ ((13 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(13*`SVT_AXI_LOCK_WIDTH  )] = arlock_s14;
   assign arcache_s_bus[((13 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(13*`SVT_AXI_CACHE_WIDTH )] = arcache_s14;
   assign arprot_s_bus[ ((13 + 1) * `SVT_AXI_PROT_WIDTH) -1:(13*`SVT_AXI_PROT_WIDTH  )] = arprot_s14;
   assign arid_s_bus[ ((13 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(13*`SVT_AXI_MAX_ID_WIDTH)] = arid_s14;
   assign arready_s[14] = arready_s_bus[13];
  `ifdef AXI_REGIONS_S14

    assign arregion_s_bus[ ((13 + 1) * `SVT_AXI_REGION_WIDTH) -1:(13*`SVT_AXI_REGION_WIDTH ) ] = arregion_s14;
    assign awregion_s_bus[ ((13 + 1) * `SVT_AXI_REGION_WIDTH) -1:(13*`SVT_AXI_REGION_WIDTH ) ] = awregion_s14;
  `endif  

   assign #1 awvalid_s_bus[13] = awvalid_s[14];
   assign awaddr_s_bus[ ((13 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(13*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s14;
   assign awlen_s_bus[  ((13 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(13*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s14;
   assign awsize_s_bus[ ((13 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(13*`SVT_AXI_SIZE_WIDTH  )] = awsize_s14;
   assign awburst_s_bus[((13 + 1) * `SVT_AXI_BURST_WIDTH)-1:(13*`SVT_AXI_BURST_WIDTH )] = awburst_s14;
   assign awlock_s_bus[ ((13 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(13*`SVT_AXI_LOCK_WIDTH  )] = awlock_s14;
   assign awcache_s_bus[((13 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(13*`SVT_AXI_CACHE_WIDTH )] = awcache_s14;
   assign awprot_s_bus[ ((13 + 1) * `SVT_AXI_PROT_WIDTH) -1:(13*`SVT_AXI_PROT_WIDTH  )] = awprot_s14;
   assign awid_s_bus[ ((13 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(13*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s14;
   assign awready_s[14] =  awready_s_bus[13];

   assign rvalid_s[14]= rvalid_s_bus[13];
   assign rlast_s[14] = rlast_s_bus[13];
   assign rdata_s14 = rdata_s_bus[((13 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(13*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s14 = rresp_s_bus[((13 + 1) * `SVT_AXI_RESP_WIDTH)-1:(13*`SVT_AXI_RESP_WIDTH)];
   assign rid_s14   = rid_s_bus[((13 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(13*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[13] = rready_s[14];

   assign wvalid_s_bus[13] = wvalid_s[14];
   assign wlast_s_bus[13]  = wlast_s[14];
   assign wdata_s_bus[((13 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(13*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s14;
   assign wstrb_s_bus[((13 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(13*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s14;
   assign wid_s_bus[((13 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(13*`SVT_AXI_MAX_ID_WIDTH)] = wid_s14;
   assign wready_s[14] =  wready_s_bus[13];

   assign bvalid_s[14]=  bvalid_s_bus[13];
   assign bresp_s14 = bresp_s_bus[((13 + 1) * `SVT_AXI_RESP_WIDTH)-1:(13*`SVT_AXI_RESP_WIDTH)];
   assign bid_s14   = bid_s_bus[((13 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(13*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[13] = bready_s[14];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s14 = {8{rdata_s_bus[(13*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(13*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s14 = {64{bid_s_bus[(13*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(13*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((13 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(13 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s14;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((13 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(13 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s14;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((13 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(13 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s14;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s14 = ruser_s_bus[ ((13 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(13 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s14 = buser_s_bus[ ((13 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(13 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif  //AXI_HAS_AXI3
`endif    

//------------------------------------------------------------------------

`ifdef AXI_HAS_S15


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s15;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s15;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s15;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s15;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s15;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s15;
   `ifdef AXI_HAS_AXI4

     assign arlock_s15[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s15;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s15;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s15;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s15;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s15;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s15;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s15;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s15;
   `ifdef AXI_HAS_AXI4

     assign awlock_s15[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s15;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s15;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s15;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s15;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s15;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s15;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s15;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s15;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s15;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s15;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s15;
   assign arsideband_s[15] = arsideband_s15;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s15;
   assign awsideband_s[15] = awsideband_s15;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s15;
   assign rsideband_s[15] = rsideband_s15;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s15;
   assign wsideband_s[15] = wsideband_s15;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s15;
   assign bsideband_s[15] = bsideband_s15;
 `endif
`endif 
  `ifdef AXI_REGIONS_S15

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s15; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s15; 
    assign #1 awregion_s[15] = awregion_s15;
    assign #1 arregion_s[15] = arregion_s15;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s15;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s15;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s15;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s15;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s15;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s15;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s15;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s15;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s15;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s15;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s15;

     assign awdomain_s[15]       =       awdomain_s15;
     assign awsnoop_s[15]        =       awsnoop_s15;
     assign awbar_s[15]          =       awbar_s15;
     assign ardomain_s[15]       =       ardomain_s15;
     assign arsnoop_s[15]        =       arsnoop_s15;
     assign arbar_s[15]          =       arbar_s15;
   `endif    

   assign #1 araddr_s[15]  = araddr_s15;
   assign arid_s[15]    = arid_s15;
   assign arlen_s[15]   = arlen_s15;
   assign arsize_s[15]  = arsize_s15;
   assign arburst_s[15] = arburst_s15;
   assign arlock_s[15]  = arlock_s15;
   assign arprot_s[15]  = arprot_s15;
   assign arcache_s[15] = arcache_s15;

   assign #1 awaddr_s[15]  = awaddr_s15;
   assign awid_s[15]    = awid_s15;
   assign awlen_s[15]   = awlen_s15;
   assign awsize_s[15]  = awsize_s15;
   assign awburst_s[15] = awburst_s15;
   assign awlock_s[15]  = awlock_s15;
   assign awprot_s[15]  = awprot_s15;
   assign awcache_s[15] = awcache_s15;

   assign wdata_s[15] = wdata_s15;
   assign wid_s[15]   = wid_s15;
   assign wstrb_s[15] = wstrb_s15;

   assign rdata_s[15] = rdata_s15;
   assign rid_s[15]   = rid_s15;
   assign rresp_s[15] = rresp_s15;

   assign bid_s[15]   = bid_s15;
   assign bresp_s[15] = bresp_s15;

   assign #1 arvalid_s_bus[14] = arvalid_s[15];
   assign araddr_s_bus[ ((14 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(14*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s15;
   assign arlen_s_bus[  ((14 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(14*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s15;
   assign arsize_s_bus[ ((14 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(14*`SVT_AXI_SIZE_WIDTH  )] = arsize_s15;
   assign arburst_s_bus[((14 + 1) * `SVT_AXI_BURST_WIDTH)-1:(14*`SVT_AXI_BURST_WIDTH )] = arburst_s15;
   assign arlock_s_bus[ ((14 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(14*`SVT_AXI_LOCK_WIDTH  )] = arlock_s15;
   assign arcache_s_bus[((14 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(14*`SVT_AXI_CACHE_WIDTH )] = arcache_s15;
   assign arprot_s_bus[ ((14 + 1) * `SVT_AXI_PROT_WIDTH) -1:(14*`SVT_AXI_PROT_WIDTH  )] = arprot_s15;
   assign arid_s_bus[ ((14 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(14*`SVT_AXI_MAX_ID_WIDTH)] = arid_s15;
   assign arready_s[15] = arready_s_bus[14];
  `ifdef AXI_REGIONS_S15

    assign arregion_s_bus[ ((14 + 1) * `SVT_AXI_REGION_WIDTH) -1:(14*`SVT_AXI_REGION_WIDTH ) ] = arregion_s15;
    assign awregion_s_bus[ ((14 + 1) * `SVT_AXI_REGION_WIDTH) -1:(14*`SVT_AXI_REGION_WIDTH ) ] = awregion_s15;
  `endif  

   assign #1 awvalid_s_bus[14] = awvalid_s[15];
   assign awaddr_s_bus[ ((14 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(14*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s15;
   assign awlen_s_bus[  ((14 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(14*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s15;
   assign awsize_s_bus[ ((14 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(14*`SVT_AXI_SIZE_WIDTH  )] = awsize_s15;
   assign awburst_s_bus[((14 + 1) * `SVT_AXI_BURST_WIDTH)-1:(14*`SVT_AXI_BURST_WIDTH )] = awburst_s15;
   assign awlock_s_bus[ ((14 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(14*`SVT_AXI_LOCK_WIDTH  )] = awlock_s15;
   assign awcache_s_bus[((14 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(14*`SVT_AXI_CACHE_WIDTH )] = awcache_s15;
   assign awprot_s_bus[ ((14 + 1) * `SVT_AXI_PROT_WIDTH) -1:(14*`SVT_AXI_PROT_WIDTH  )] = awprot_s15;
   assign awid_s_bus[ ((14 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(14*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s15;
   assign awready_s[15] =  awready_s_bus[14];

   assign rvalid_s[15]= rvalid_s_bus[14];
   assign rlast_s[15] = rlast_s_bus[14];
   assign rdata_s15 = rdata_s_bus[((14 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(14*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s15 = rresp_s_bus[((14 + 1) * `SVT_AXI_RESP_WIDTH)-1:(14*`SVT_AXI_RESP_WIDTH)];
   assign rid_s15   = rid_s_bus[((14 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(14*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[14] = rready_s[15];

   assign wvalid_s_bus[14] = wvalid_s[15];
   assign wlast_s_bus[14]  = wlast_s[15];
   assign wdata_s_bus[((14 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(14*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s15;
   assign wstrb_s_bus[((14 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(14*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s15;
   assign wid_s_bus[((14 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(14*`SVT_AXI_MAX_ID_WIDTH)] = wid_s15;
   assign wready_s[15] =  wready_s_bus[14];

   assign bvalid_s[15]=  bvalid_s_bus[14];
   assign bresp_s15 = bresp_s_bus[((14 + 1) * `SVT_AXI_RESP_WIDTH)-1:(14*`SVT_AXI_RESP_WIDTH)];
   assign bid_s15   = bid_s_bus[((14 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(14*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[14] = bready_s[15];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s15 = {8{rdata_s_bus[(14*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(14*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s15 = {64{bid_s_bus[(14*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(14*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((14 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(14 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s15;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((14 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(14 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s15;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((14 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(14 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s15;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s15 = ruser_s_bus[ ((14 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(14 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s15 = buser_s_bus[ ((14 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(14 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif    
`endif  //AXI_HAS_AXI3
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S16


   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       araddr_s16;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         arid_s16;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        arlen_s16;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     arsize_s16;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    arburst_s16;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     arlock_s16;
   `ifdef AXI_HAS_AXI4

     assign arlock_s16[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     arprot_s16;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    arcache_s16;

   wire [`SVT_AXI_MAX_ADDR_WIDTH:0]       awaddr_s16;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]         awid_s16;
   wire [`SVT_AXI_MAX_BURST_LENGTH_WIDTH:0]        awlen_s16;
   wire [`SVT_AXI_SIZE_WIDTH-1:0]     awsize_s16;
   wire [`SVT_AXI_BURST_WIDTH-1:0]    awburst_s16;
   wire [`SVT_AXI_LOCK_WIDTH-1:0]     awlock_s16;
   `ifdef AXI_HAS_AXI4

     assign awlock_s16[1] = 1'b0;
   `endif    
   wire [`SVT_AXI_PROT_WIDTH-1:0]     awprot_s16;
   wire [`SVT_AXI_CACHE_WIDTH-1:0]    awcache_s16;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        wdata_s16;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          wid_s16;
   wire [`SVT_AXI_MAX_DATA_WIDTH/8:0]        wstrb_s16;

   wire [`SVT_AXI_MAX_DATA_WIDTH:0]        rdata_s16;
   wire [`SVT_AXI_MAX_ID_WIDTH:0]          rid_s16;
   wire [`SVT_AXI_RESP_WIDTH:0]        rresp_s16;

   wire [`SVT_AXI_MAX_ID_WIDTH:0]          bid_s16;
   wire [`SVT_AXI_RESP_WIDTH:0]        bresp_s16;

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_ARSB

   wire [`AXI_AR_SBW-1:0] arsideband_s16;
   assign arsideband_s[16] = arsideband_s16;
 `endif
 `ifdef AXI_INC_AWSB

   wire [`AXI_AW_SBW-1:0] awsideband_s16;
   assign awsideband_s[16] = awsideband_s16;
 `endif
 `ifdef AXI_INC_RSB

   wire [`AXI_R_SBW-1:0] rsideband_s16;
   assign rsideband_s[16] = rsideband_s16;
 `endif
 `ifdef AXI_INC_WSB

   wire [`AXI_W_SBW-1:0] wsideband_s16;
   assign wsideband_s[16] = wsideband_s16;
 `endif
 `ifdef AXI_INC_BSB

   wire [`AXI_B_SBW-1:0] bsideband_s16;
   assign bsideband_s[16] = bsideband_s16;
 `endif
`endif 
  `ifdef AXI_REGIONS_S16

    wire [`SVT_AXI_REGION_WIDTH-1:0] arregion_s16; 
    wire [`SVT_AXI_REGION_WIDTH-1:0] awregion_s16; 
    assign #1 awregion_s[16] = awregion_s16;
    assign #1 arregion_s[16] = arregion_s16;
  `endif 
`ifdef AXI_HAS_AXI4

  `ifdef AXI_INC_AWSB

    wire [`AXI_AW_SBW-1:0] awuser_s16;
  `endif
  `ifdef AXI_INC_WSB

    wire [`AXI_W_SBW-1:0] wuser_s16;
  `endif
  `ifdef AXI_INC_BSB

    wire [`AXI_B_SBW-1:0] buser_s16;
  `endif
  `ifdef AXI_INC_ARSB

    wire [`AXI_AR_SBW-1:0] aruser_s16;
  `endif
  `ifdef AXI_INC_RSB

    wire [`AXI_R_SBW-1:0] ruser_s16;
  `endif
`endif
   `ifdef AXI_HAS_ACELITE

     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          awdomain_s16;
     wire [`SVT_AXI_ACE_WSNOOP_WIDTH-1:0]          awsnoop_s16;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         awbar_s16;
     wire [`SVT_AXI_ACE_DOMAIN_WIDTH-1:0]          ardomain_s16;
     wire [`SVT_AXI_ACE_RSNOOP_WIDTH-1:0]          arsnoop_s16;
     wire [`SVT_AXI_ACE_BARRIER_WIDTH-1:0]         arbar_s16;

     assign awdomain_s[16]       =       awdomain_s16;
     assign awsnoop_s[16]        =       awsnoop_s16;
     assign awbar_s[16]          =       awbar_s16;
     assign ardomain_s[16]       =       ardomain_s16;
     assign arsnoop_s[16]        =       arsnoop_s16;
     assign arbar_s[16]          =       arbar_s16;
   `endif    

   assign #1 araddr_s[16]  = araddr_s16;
   assign arid_s[16]    = arid_s16;
   assign arlen_s[16]   = arlen_s16;
   assign arsize_s[16]  = arsize_s16;
   assign arburst_s[16] = arburst_s16;
   assign arlock_s[16]  = arlock_s16;
   assign arprot_s[16]  = arprot_s16;
   assign arcache_s[16] = arcache_s16;

   assign #1 awaddr_s[16]  = awaddr_s16;
   assign awid_s[16]    = awid_s16;
   assign awlen_s[16]   = awlen_s16;
   assign awsize_s[16]  = awsize_s16;
   assign awburst_s[16] = awburst_s16;
   assign awlock_s[16]  = awlock_s16;
   assign awprot_s[16]  = awprot_s16;
   assign awcache_s[16] = awcache_s16;

   assign wdata_s[16] = wdata_s16;
   assign wid_s[16]   = wid_s16;
   assign wstrb_s[16] = wstrb_s16;

   assign rdata_s[16] = rdata_s16;
   assign rid_s[16]   = rid_s16;
   assign rresp_s[16] = rresp_s16;

   assign bid_s[16]   = bid_s16;
   assign bresp_s[16] = bresp_s16;

   assign #1 arvalid_s_bus[15] = arvalid_s[16];
   assign araddr_s_bus[ ((15 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(15*`SVT_AXI_MAX_ADDR_WIDTH  )] = araddr_s16;
   assign arlen_s_bus[  ((15 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(15*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = arlen_s16;
   assign arsize_s_bus[ ((15 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(15*`SVT_AXI_SIZE_WIDTH  )] = arsize_s16;
   assign arburst_s_bus[((15 + 1) * `SVT_AXI_BURST_WIDTH)-1:(15*`SVT_AXI_BURST_WIDTH )] = arburst_s16;
   assign arlock_s_bus[ ((15 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(15*`SVT_AXI_LOCK_WIDTH  )] = arlock_s16;
   assign arcache_s_bus[((15 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(15*`SVT_AXI_CACHE_WIDTH )] = arcache_s16;
   assign arprot_s_bus[ ((15 + 1) * `SVT_AXI_PROT_WIDTH) -1:(15*`SVT_AXI_PROT_WIDTH  )] = arprot_s16;
   assign arid_s_bus[ ((15 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(15*`SVT_AXI_MAX_ID_WIDTH)] = arid_s16;
   assign arready_s[16] = arready_s_bus[15];
  `ifdef AXI_REGIONS_S16

    assign arregion_s_bus[ ((15 + 1) * `SVT_AXI_REGION_WIDTH) -1:(15*`SVT_AXI_REGION_WIDTH ) ] = arregion_s16;
    assign awregion_s_bus[ ((15 + 1) * `SVT_AXI_REGION_WIDTH) -1:(15*`SVT_AXI_REGION_WIDTH ) ] = awregion_s16;
  `endif  

   assign #1 awvalid_s_bus[15] = awvalid_s[16];
   assign awaddr_s_bus[ ((15 + 1) * `SVT_AXI_MAX_ADDR_WIDTH) -1:(15*`SVT_AXI_MAX_ADDR_WIDTH  )] = awaddr_s16;
   assign awlen_s_bus[  ((15 + 1) * `SVT_AXI_MAX_BURST_LENGTH_WIDTH)  -1:(15*`SVT_AXI_MAX_BURST_LENGTH_WIDTH   )] = awlen_s16;
   assign awsize_s_bus[ ((15 + 1) * `SVT_AXI_SIZE_WIDTH) -1:(15*`SVT_AXI_SIZE_WIDTH  )] = awsize_s16;
   assign awburst_s_bus[((15 + 1) * `SVT_AXI_BURST_WIDTH)-1:(15*`SVT_AXI_BURST_WIDTH )] = awburst_s16;
   assign awlock_s_bus[ ((15 + 1) * `SVT_AXI_LOCK_WIDTH) -1:(15*`SVT_AXI_LOCK_WIDTH  )] = awlock_s16;
   assign awcache_s_bus[((15 + 1) * `SVT_AXI_CACHE_WIDTH)-1:(15*`SVT_AXI_CACHE_WIDTH )] = awcache_s16;
   assign awprot_s_bus[ ((15 + 1) * `SVT_AXI_PROT_WIDTH) -1:(15*`SVT_AXI_PROT_WIDTH  )] = awprot_s16;
   assign awid_s_bus[ ((15 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(15*`SVT_AXI_MAX_ID_WIDTH)] =  awid_s16;
   assign awready_s[16] =  awready_s_bus[15];

   assign rvalid_s[16]= rvalid_s_bus[15];
   assign rlast_s[16] = rlast_s_bus[15];
   assign rdata_s16 = rdata_s_bus[((15 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(15*`SVT_AXI_MAX_DATA_WIDTH)];
   assign rresp_s16 = rresp_s_bus[((15 + 1) * `SVT_AXI_RESP_WIDTH)-1:(15*`SVT_AXI_RESP_WIDTH)];
   assign rid_s16   = rid_s_bus[((15 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(15*`SVT_AXI_MAX_ID_WIDTH)];
   assign rready_s_bus[15] = rready_s[16];

   assign wvalid_s_bus[15] = wvalid_s[16];
   assign wlast_s_bus[15]  = wlast_s[16];
   assign wdata_s_bus[((15 + 1) * `SVT_AXI_MAX_DATA_WIDTH)-1:(15*`SVT_AXI_MAX_DATA_WIDTH)] = wdata_s16;
   assign wstrb_s_bus[((15 + 1) * `SVT_AXI_MAX_DATA_WIDTH/8)-1:(15*`SVT_AXI_MAX_DATA_WIDTH/8)] = wstrb_s16;
   assign wid_s_bus[((15 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(15*`SVT_AXI_MAX_ID_WIDTH)] = wid_s16;
   assign wready_s[16] =  wready_s_bus[15];

   assign bvalid_s[16]=  bvalid_s_bus[15];
   assign bresp_s16 = bresp_s_bus[((15 + 1) * `SVT_AXI_RESP_WIDTH)-1:(15*`SVT_AXI_RESP_WIDTH)];
   assign bid_s16   = bid_s_bus[((15 + 1) * `SVT_AXI_MAX_ID_WIDTH)-1:(15*`SVT_AXI_MAX_ID_WIDTH)];
   assign bready_s_bus[15] = bready_s[16];

`ifdef AXI_HAS_AXI3

 `ifdef AXI_INC_RSB

   assign rsideband_s16 = {8{rdata_s_bus[(15*`SVT_AXI_MAX_DATA_WIDTH) + `AXI_DW-1:(15*`SVT_AXI_MAX_DATA_WIDTH)]}};
 `endif
 `ifdef AXI_INC_BSB

   assign bsideband_s16 = {64{bid_s_bus[(15*`SVT_AXI_MAX_ID_WIDTH) + `AXI_MIDW-1:(15*`SVT_AXI_MAX_ID_WIDTH)]}};
 `endif
`else 
 `ifdef AXI_INC_AWSB

   assign awuser_s_bus[ ((15 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(15 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = awuser_s16;
 `endif    
 `ifdef AXI_INC_WSB

   assign wuser_s_bus[ ((15 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(15 * `SVT_AXI_MAX_DATA_USER_WIDTH )] = wuser_s16;
 `endif    
 `ifdef AXI_INC_ARSB

   assign aruser_s_bus[ ((15 + 1) * `SVT_AXI_MAX_ADDR_USER_WIDTH) -1:(15 * `SVT_AXI_MAX_ADDR_USER_WIDTH )] = aruser_s16;
 `endif    
 `ifdef AXI_INC_RSB

   assign ruser_s16 = ruser_s_bus[ ((15 + 1) * `SVT_AXI_MAX_DATA_USER_WIDTH) -1:(15 * `SVT_AXI_MAX_DATA_USER_WIDTH )];
 `endif    
 `ifdef AXI_INC_BSB

   assign buser_s16 = buser_s_bus[ ((15 + 1) * `SVT_AXI_MAX_BRESP_USER_WIDTH) -1:(15 * `SVT_AXI_MAX_BRESP_USER_WIDTH )];
 `endif  
`endif 
`endif

//------------------------------------------------------------------------

`ifdef AXI_HAS_S0

  assign  araddr_s0[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s0[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s0[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s0[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s0[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s0[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s0[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s0[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s0[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s0[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s0[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s0[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S1

  assign  araddr_s1[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s1[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s1[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s1[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s1[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s1[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s1[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s1[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s1[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s1[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s1[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s1[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S2

  assign  araddr_s2[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s2[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s2[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s2[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s2[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s2[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s2[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s2[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s2[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s2[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s2[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s2[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S3

  assign  araddr_s3[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s3[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s3[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s3[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s3[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s3[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s3[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s3[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s3[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s3[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s3[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s3[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S4

  assign  araddr_s4[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s4[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s4[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s4[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s4[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s4[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s4[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s4[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s4[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s4[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s4[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s4[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S5

  assign  araddr_s5[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s5[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s5[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s5[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s5[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s5[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s5[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s5[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s5[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s5[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s5[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s5[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S6

  assign  araddr_s6[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s6[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s6[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s6[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s6[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s6[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s6[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s6[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s6[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s6[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s6[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s6[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S7

  assign  araddr_s7[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s7[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s7[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s7[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s7[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s7[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s7[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s7[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s7[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s7[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s7[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s7[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S8

  assign  araddr_s8[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s8[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s8[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s8[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s8[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s8[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s8[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s8[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s8[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s8[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s8[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s8[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S9

  assign  araddr_s9[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s9[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s9[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s9[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s9[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s9[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s9[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s9[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s9[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s9[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s9[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s9[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S10

  assign  araddr_s10[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s10[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s10[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s10[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s10[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s10[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s10[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s10[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s10[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s10[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s10[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s10[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S11

  assign  araddr_s11[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s11[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s11[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s11[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s11[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s11[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s11[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s11[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s11[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s11[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s11[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s11[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S12

  assign  araddr_s12[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s12[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s12[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s12[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s12[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s12[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s12[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s12[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s12[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s12[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s12[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s12[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S13

  assign  araddr_s13[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s13[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s13[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s13[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s13[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s13[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s13[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s13[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s13[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s13[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s13[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s13[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S14

  assign  araddr_s14[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s14[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s14[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s14[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s14[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s14[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s14[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s14[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s14[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s14[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s14[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s14[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S15

  assign  araddr_s15[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s15[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s15[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s15[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s15[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s15[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s15[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s15[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s15[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s15[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s15[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s15[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif
`ifdef AXI_HAS_S16

  assign  araddr_s16[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  awaddr_s16[`SVT_AXI_MAX_ADDR_WIDTH:`AXI_AW] = 0;
  assign  arid_s16[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  awid_s16[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  arlen_s16[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  awlen_s16[`SVT_AXI_MAX_BURST_LENGTH_WIDTH:`AXI_BLW] = 0;
  assign  wstrb_s16[`SVT_AXI_MAX_DATA_WIDTH/8:`AXI_SW] = 0;
  assign  rid_s16[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  bid_s16[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  wid_s16[`SVT_AXI_MAX_ID_WIDTH:`AXI_SIDW] = 0;
  assign  rdata_s16[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
  assign  wdata_s16[`SVT_AXI_MAX_DATA_WIDTH:`AXI_DW] = 0;
`endif


// ----------------------------------------------------------------------------------
/**
 * Include axi assignments
 */
`include "tb_axi_assignment.sv"

/**
 * Include axi_svt vip common wrapper tasks
 */
`include "tb_axi_tasks_vip.sv"

/**
 * Master VIP Utility methods, to initiate traffic etc.,
 */
`include "tb_axi_tasks_mst.sv"

/**
 * Slave VIP Utility methods, to generate response etc.,
 */
`include "tb_axi_tasks_slv.sv"

/**
* Include common test tasks
*/
`include "tb_test_tasks.sv"

/** 
* Include checkers
*/
`include "tb_checker.sv"

/**
 * DW_axi Instantiation.
 */
  axi_2t1_int_DW_axi U_DW_axi(
                                .aclk (aclklp)
                                ,.aresetn (aresetn)
   `ifdef AXI_REMAP

                                ,.remap_n (remap_n)
   `endif

   `ifdef AXI_EXT_PRIORITY

   `ifdef AXI_SHARED_LAYER_MASTER_PRIORITY_EN

                               ,.mst_priority_shared (mst_priority_shared)
   `endif
   `ifdef AXI_SHARED_LAYER_SLAVE_PRIORITY_EN

                               ,.slv_priority_shared (slv_priority_shared)
   `endif
   `endif

`ifdef AXI_HAS_M1

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m1 (xdcdr_slv_num_rd_m1)
                                ,.xdcdr_slv_num_wr_m1 (xdcdr_slv_num_wr_m1)
   `endif
                                ,.awid_m1    (awid_m1)
                                ,.awaddr_m1  (awaddr_m1)
                                ,.awlen_m1   (awlen_m1)
                                ,.awsize_m1  (awsize_m1)
                                ,.awburst_m1 (awburst_m1)
                                ,.awlock_m1  (awlock_m1)
                                ,.awcache_m1 (awcache_m1)
                                ,.awprot_m1  (awprot_m1)
                                ,.awvalid_m1 (awvalid_m[1])
                                ,.awready_m1 (awready_m[1])
  `ifdef AXI_AWQOS_EXT_M1

                                ,.awqos_m1 (awqos_m1)
  `endif
  `ifdef AXI_ARQOS_EXT_M1

                                ,.arqos_m1 (arqos_m1)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m1    (wid_m1)
   `endif                             
                                ,.wdata_m1  (wdata_m1)
                                ,.wstrb_m1  (wstrb_m1)
                                ,.wlast_m1  (wlast_m[1])
                                ,.wvalid_m1 (wvalid_m[1])
                                ,.wready_m1 (wready_m[1])
                                ,.bid_m1    (bid_m1)
                                ,.bresp_m1  (bresp_m1)
                                ,.bvalid_m1 (bvalid_m[1])
                                ,.bready_m1 (bready_m[1])
                                ,.arid_m1    (arid_m1)
                                ,.araddr_m1  (araddr_m1)
                                ,.arlen_m1   (arlen_m1)
                                ,.arsize_m1  (arsize_m1)
                                ,.arburst_m1 (arburst_m1)
                                ,.arlock_m1  (arlock_m1)
                                ,.arcache_m1 (arcache_m1)
                                ,.arprot_m1  (arprot_m1)
                                ,.arvalid_m1 (arvalid_m[1])
                                ,.arready_m1 (arready_m[1])
                                ,.rid_m1    (rid_m1)
                                ,.rdata_m1  (rdata_m1)
                                ,.rresp_m1  (rresp_m1)
                                ,.rlast_m1  (rlast_m[1])
                                ,.rvalid_m1 (rvalid_m[1])
                                ,.rready_m1 (rready_m[1])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m1 (awsideband_m1)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m1 (wsideband_m1)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m1 (bsideband_m1)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m1 (arsideband_m1)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m1 (rsideband_m1)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m1 (awuser_m1)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m1 (wuser_m1)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m1 (buser_m1)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m1 (aruser_m1)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m1 (ruser_m1)
   `endif  
`endif  
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m1 (awdomain_m1)
                                ,.awsnoop_m1 (awsnoop_m1)
                                ,.awbar_m1    (awbar_m1)
                                ,.ardomain_m1 (ardomain_m1)
                                ,.arsnoop_m1 (arsnoop_m1)
                                ,.arbar_m1    (arbar_m1)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m1(axi_master_priority[1])
                                //,.mst_priority_m1(1)
   `endif
`endif
`ifdef AXI_HAS_M2

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m2 (xdcdr_slv_num_rd_m2)
                                ,.xdcdr_slv_num_wr_m2 (xdcdr_slv_num_wr_m2)
   `endif
                                ,.awid_m2    (awid_m2)
                                ,.awaddr_m2  (awaddr_m2)
                                ,.awlen_m2   (awlen_m2)
                                ,.awsize_m2  (awsize_m2)
                                ,.awburst_m2 (awburst_m2)
                                ,.awlock_m2  (awlock_m2)
                                ,.awcache_m2 (awcache_m2)
                                ,.awprot_m2  (awprot_m2)
                                ,.awvalid_m2 (awvalid_m[2])
                                ,.awready_m2 (awready_m[2])
  `ifdef AXI_AWQOS_EXT_M2

                                ,.awqos_m2 (awqos_m2)
  `endif
  `ifdef AXI_ARQOS_EXT_M2

                                ,.arqos_m2 (arqos_m2)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m2    (wid_m2)
   `endif
                                ,.wdata_m2  (wdata_m2)
                                ,.wstrb_m2  (wstrb_m2)
                                ,.wlast_m2  (wlast_m[2])
                                ,.wvalid_m2 (wvalid_m[2])
                                ,.wready_m2 (wready_m[2])
                                ,.bid_m2    (bid_m2)
                                ,.bresp_m2  (bresp_m2)
                                ,.bvalid_m2 (bvalid_m[2])
                                ,.bready_m2 (bready_m[2])
                                ,.arid_m2    (arid_m2)
                                ,.araddr_m2  (araddr_m2)
                                ,.arlen_m2   (arlen_m2)
                                ,.arsize_m2  (arsize_m2)
                                ,.arburst_m2 (arburst_m2)
                                ,.arlock_m2  (arlock_m2)
                                ,.arcache_m2 (arcache_m2)
                                ,.arprot_m2  (arprot_m2)
                                ,.arvalid_m2 (arvalid_m[2])
                                ,.arready_m2 (arready_m[2])
                                ,.rid_m2    (rid_m2)
                                ,.rdata_m2  (rdata_m2)
                                ,.rresp_m2  (rresp_m2)
                                ,.rlast_m2  (rlast_m[2])
                                ,.rvalid_m2 (rvalid_m[2])
                                ,.rready_m2 (rready_m[2])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m2 (awsideband_m2)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m2 (wsideband_m2)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m2 (bsideband_m2)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m2 (arsideband_m2)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m2 (rsideband_m2)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m2 (awuser_m2)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m2 (wuser_m2)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m2 (buser_m2)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m2 (aruser_m2)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m2 (ruser_m2)
   `endif  
`endif  
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m2 (awdomain_m2)
                                ,.awsnoop_m2 (awsnoop_m2)
                                ,.awbar_m2    (awbar_m2)
                                ,.ardomain_m2 (ardomain_m2)
                                ,.arsnoop_m2 (arsnoop_m2)
                                ,.arbar_m2    (arbar_m2)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m2(axi_master_priority[2])
                               // ,.mst_priority_m2(2)
   `endif
`endif
`ifdef AXI_HAS_M3

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m3 (xdcdr_slv_num_rd_m3)
                                ,.xdcdr_slv_num_wr_m3 (xdcdr_slv_num_wr_m3)
   `endif
                                ,.awid_m3    (awid_m3)
                                ,.awaddr_m3  (awaddr_m3)
                                ,.awlen_m3   (awlen_m3)
                                ,.awsize_m3  (awsize_m3)
                                ,.awburst_m3 (awburst_m3)
                                ,.awlock_m3  (awlock_m3)
                                ,.awcache_m3 (awcache_m3)
                                ,.awprot_m3  (awprot_m3)
                                ,.awvalid_m3 (awvalid_m[3])
                                ,.awready_m3 (awready_m[3])
  `ifdef AXI_AWQOS_EXT_M3

                                ,.awqos_m3 (awqos_m3)
  `endif
  `ifdef AXI_ARQOS_EXT_M3

                                ,.arqos_m3 (arqos_m3)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m3    (wid_m3)
   `endif
                                ,.wdata_m3  (wdata_m3)
                                ,.wstrb_m3  (wstrb_m3)
                                ,.wlast_m3  (wlast_m[3])
                                ,.wvalid_m3 (wvalid_m[3])
                                ,.wready_m3 (wready_m[3])
                                ,.bid_m3    (bid_m3)
                                ,.bresp_m3  (bresp_m3)
                                ,.bvalid_m3 (bvalid_m[3])
                                ,.bready_m3 (bready_m[3])
                                ,.arid_m3    (arid_m3)
                                ,.araddr_m3  (araddr_m3)
                                ,.arlen_m3   (arlen_m3)
                                ,.arsize_m3  (arsize_m3)
                                ,.arburst_m3 (arburst_m3)
                                ,.arlock_m3  (arlock_m3)
                                ,.arcache_m3 (arcache_m3)
                                ,.arprot_m3  (arprot_m3)
                                ,.arvalid_m3 (arvalid_m[3])
                                ,.arready_m3 (arready_m[3])
                                ,.rid_m3    (rid_m3)
                                ,.rdata_m3  (rdata_m3)
                                ,.rresp_m3  (rresp_m3)
                                ,.rlast_m3  (rlast_m[3])
                                ,.rvalid_m3 (rvalid_m[3])
                                ,.rready_m3 (rready_m[3])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m3 (awsideband_m3)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m3 (wsideband_m3)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m3 (bsideband_m3)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m3 (arsideband_m3)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m3 (rsideband_m3)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m3 (awuser_m3)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m3 (wuser_m3)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m3 (buser_m3)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m3 (aruser_m3)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m3 (ruser_m3)
   `endif  
`endif  
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m3 (awdomain_m3)
                                ,.awsnoop_m3 (awsnoop_m3)
                                ,.awbar_m3    (awbar_m3)
                                ,.ardomain_m3 (ardomain_m3)
                                ,.arsnoop_m3 (arsnoop_m3)
                                ,.arbar_m3    (arbar_m3)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m3(axi_master_priority[3])
                                //,.mst_priority_m3(3)
   `endif
`endif
`ifdef AXI_HAS_M4

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m4 (xdcdr_slv_num_rd_m4)
                                ,.xdcdr_slv_num_wr_m4 (xdcdr_slv_num_wr_m4)
   `endif
                                ,.awid_m4    (awid_m4)
                                ,.awaddr_m4  (awaddr_m4)
                                ,.awlen_m4   (awlen_m4)
                                ,.awsize_m4  (awsize_m4)
                                ,.awburst_m4 (awburst_m4)
                                ,.awlock_m4  (awlock_m4)
                                ,.awcache_m4 (awcache_m4)
                                ,.awprot_m4  (awprot_m4)
                                ,.awvalid_m4 (awvalid_m[4])
                                ,.awready_m4 (awready_m[4])
  `ifdef AXI_AWQOS_EXT_M4

                                ,.awqos_m4 (awqos_m4)
  `endif
  `ifdef AXI_ARQOS_EXT_M4

                                ,.arqos_m4 (arqos_m4)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m4    (wid_m4)
   `endif
                                ,.wdata_m4  (wdata_m4)
                                ,.wstrb_m4  (wstrb_m4)
                                ,.wlast_m4  (wlast_m[4])
                                ,.wvalid_m4 (wvalid_m[4])
                                ,.wready_m4 (wready_m[4])
                                ,.bid_m4    (bid_m4)
                                ,.bresp_m4  (bresp_m4)
                                ,.bvalid_m4 (bvalid_m[4])
                                ,.bready_m4 (bready_m[4])
                                ,.arid_m4    (arid_m4)
                                ,.araddr_m4  (araddr_m4)
                                ,.arlen_m4   (arlen_m4)
                                ,.arsize_m4  (arsize_m4)
                                ,.arburst_m4 (arburst_m4)
                                ,.arlock_m4  (arlock_m4)
                                ,.arcache_m4 (arcache_m4)
                                ,.arprot_m4  (arprot_m4)
                                ,.arvalid_m4 (arvalid_m[4])
                                ,.arready_m4 (arready_m[4])
                                ,.rid_m4    (rid_m4)
                                ,.rdata_m4  (rdata_m4)
                                ,.rresp_m4  (rresp_m4)
                                ,.rlast_m4  (rlast_m[4])
                                ,.rvalid_m4 (rvalid_m[4])
                                ,.rready_m4 (rready_m[4])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m4 (awsideband_m4)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m4 (wsideband_m4)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m4 (bsideband_m4)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m4 (arsideband_m4)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m4 (rsideband_m4)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m4 (awuser_m4)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m4 (wuser_m4)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m4 (buser_m4)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m4 (aruser_m4)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m4 (ruser_m4)
   `endif  
`endif  
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m4 (awdomain_m4)
                                ,.awsnoop_m4 (awsnoop_m4)
                                ,.awbar_m4    (awbar_m4)
                                ,.ardomain_m4 (ardomain_m4)
                                ,.arsnoop_m4 (arsnoop_m4)
                                ,.arbar_m4    (arbar_m4)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m4(axi_master_priority[4])
                                //,.mst_priority_m4(4)
   `endif
`endif
`ifdef AXI_HAS_M5

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m5 (xdcdr_slv_num_rd_m5)
                                ,.xdcdr_slv_num_wr_m5 (xdcdr_slv_num_wr_m5)
   `endif
                                ,.awid_m5    (awid_m5)
                                ,.awaddr_m5  (awaddr_m5)
                                ,.awlen_m5   (awlen_m5)
                                ,.awsize_m5  (awsize_m5)
                                ,.awburst_m5 (awburst_m5)
                                ,.awlock_m5  (awlock_m5)
                                ,.awcache_m5 (awcache_m5)
                                ,.awprot_m5  (awprot_m5)
                                ,.awvalid_m5 (awvalid_m[5])
                                ,.awready_m5 (awready_m[5])
  `ifdef AXI_AWQOS_EXT_M5

                                ,.awqos_m5 (awqos_m5)
  `endif
  `ifdef AXI_ARQOS_EXT_M5

                                ,.arqos_m5 (arqos_m5)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m5    (wid_m5)
   `endif
                                ,.wdata_m5  (wdata_m5)
                                ,.wstrb_m5  (wstrb_m5)
                                ,.wlast_m5  (wlast_m[5])
                                ,.wvalid_m5 (wvalid_m[5])
                                ,.wready_m5 (wready_m[5])
                                ,.bid_m5    (bid_m5)
                                ,.bresp_m5  (bresp_m5)
                                ,.bvalid_m5 (bvalid_m[5])
                                ,.bready_m5 (bready_m[5])
                                ,.arid_m5    (arid_m5)
                                ,.araddr_m5  (araddr_m5)
                                ,.arlen_m5   (arlen_m5)
                                ,.arsize_m5  (arsize_m5)
                                ,.arburst_m5 (arburst_m5)
                                ,.arlock_m5  (arlock_m5)
                                ,.arcache_m5 (arcache_m5)
                                ,.arprot_m5  (arprot_m5)
                                ,.arvalid_m5 (arvalid_m[5])
                                ,.arready_m5 (arready_m[5])
                                ,.rid_m5    (rid_m5)
                                ,.rdata_m5  (rdata_m5)
                                ,.rresp_m5  (rresp_m5)
                                ,.rlast_m5  (rlast_m[5])
                                ,.rvalid_m5 (rvalid_m[5])
                                ,.rready_m5 (rready_m[5])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m5 (awsideband_m5)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m5 (wsideband_m5)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m5 (bsideband_m5)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m5 (arsideband_m5)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m5 (rsideband_m5)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m5 (awuser_m5)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m5 (wuser_m5)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m5 (buser_m5)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m5 (aruser_m5)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m5 (ruser_m5)
   `endif  
`endif  
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m5 (awdomain_m5)
                                ,.awsnoop_m5 (awsnoop_m5)
                                ,.awbar_m5    (awbar_m5)
                                ,.ardomain_m5 (ardomain_m5)
                                ,.arsnoop_m5 (arsnoop_m5)
                                ,.arbar_m5    (arbar_m5)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m5(axi_master_priority[5])
                               // ,.mst_priority_m5(5)
   `endif
`endif
`ifdef AXI_HAS_M6

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m6 (xdcdr_slv_num_rd_m6)
                                ,.xdcdr_slv_num_wr_m6 (xdcdr_slv_num_wr_m6)
   `endif
                                ,.awid_m6    (awid_m6)
                                ,.awaddr_m6  (awaddr_m6)
                                ,.awlen_m6   (awlen_m6)
                                ,.awsize_m6  (awsize_m6)
                                ,.awburst_m6 (awburst_m6)
                                ,.awlock_m6  (awlock_m6)
                                ,.awcache_m6 (awcache_m6)
                                ,.awprot_m6  (awprot_m6)
                                ,.awvalid_m6 (awvalid_m[6])
                                ,.awready_m6 (awready_m[6])
  `ifdef AXI_AWQOS_EXT_M6

                                ,.awqos_m6 (awqos_m6)
  `endif
  `ifdef AXI_ARQOS_EXT_M6

                                ,.arqos_m6 (arqos_m6)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m6    (wid_m6)
   `endif
                                ,.wdata_m6  (wdata_m6)
                                ,.wstrb_m6  (wstrb_m6)
                                ,.wlast_m6  (wlast_m[6])
                                ,.wvalid_m6 (wvalid_m[6])
                                ,.wready_m6 (wready_m[6])
                                ,.bid_m6    (bid_m6)
                                ,.bresp_m6  (bresp_m6)
                                ,.bvalid_m6 (bvalid_m[6])
                                ,.bready_m6 (bready_m[6])
                                ,.arid_m6    (arid_m6)
                                ,.araddr_m6  (araddr_m6)
                                ,.arlen_m6   (arlen_m6)
                                ,.arsize_m6  (arsize_m6)
                                ,.arburst_m6 (arburst_m6)
                                ,.arlock_m6  (arlock_m6)
                                ,.arcache_m6 (arcache_m6)
                                ,.arprot_m6  (arprot_m6)
                                ,.arvalid_m6 (arvalid_m[6])
                                ,.arready_m6 (arready_m[6])
                                ,.rid_m6    (rid_m6)
                                ,.rdata_m6  (rdata_m6)
                                ,.rresp_m6  (rresp_m6)
                                ,.rlast_m6  (rlast_m[6])
                                ,.rvalid_m6 (rvalid_m[6])
                                ,.rready_m6 (rready_m[6])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m6 (awsideband_m6)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m6 (wsideband_m6)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m6 (bsideband_m6)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m6 (arsideband_m6)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m6 (rsideband_m6)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m6 (awuser_m6)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m6 (wuser_m6)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m6 (buser_m6)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m6 (aruser_m6)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m6 (ruser_m6)
   `endif  
`endif  
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m6 (awdomain_m6)
                                ,.awsnoop_m6 (awsnoop_m6)
                                ,.awbar_m6    (awbar_m6)
                                ,.ardomain_m6 (ardomain_m6)
                                ,.arsnoop_m6 (arsnoop_m6)
                                ,.arbar_m6    (arbar_m6)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m6(axi_master_priority[6])
                                //,.mst_priority_m6(6)
   `endif
`endif
`ifdef AXI_HAS_M7

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m7 (xdcdr_slv_num_rd_m7)
                                ,.xdcdr_slv_num_wr_m7 (xdcdr_slv_num_wr_m7)
   `endif
                                ,.awid_m7    (awid_m7)
                                ,.awaddr_m7  (awaddr_m7)
                                ,.awlen_m7   (awlen_m7)
                                ,.awsize_m7  (awsize_m7)
                                ,.awburst_m7 (awburst_m7)
                                ,.awlock_m7  (awlock_m7)
                                ,.awcache_m7 (awcache_m7)
                                ,.awprot_m7  (awprot_m7)
                                ,.awvalid_m7 (awvalid_m[7])
                                ,.awready_m7 (awready_m[7])
  `ifdef AXI_AWQOS_EXT_M7

                                ,.awqos_m7 (awqos_m7)
  `endif
  `ifdef AXI_ARQOS_EXT_M7

                                ,.arqos_m7 (arqos_m7)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m7    (wid_m7)
   `endif
                                ,.wdata_m7  (wdata_m7)
                                ,.wstrb_m7  (wstrb_m7)
                                ,.wlast_m7  (wlast_m[7])
                                ,.wvalid_m7 (wvalid_m[7])
                                ,.wready_m7 (wready_m[7])
                                ,.bid_m7    (bid_m7)
                                ,.bresp_m7  (bresp_m7)
                                ,.bvalid_m7 (bvalid_m[7])
                                ,.bready_m7 (bready_m[7])
                                ,.arid_m7    (arid_m7)
                                ,.araddr_m7  (araddr_m7)
                                ,.arlen_m7   (arlen_m7)
                                ,.arsize_m7  (arsize_m7)
                                ,.arburst_m7 (arburst_m7)
                                ,.arlock_m7  (arlock_m7)
                                ,.arcache_m7 (arcache_m7)
                                ,.arprot_m7  (arprot_m7)
                                ,.arvalid_m7 (arvalid_m[7])
                                ,.arready_m7 (arready_m[7])
                                ,.rid_m7    (rid_m7)
                                ,.rdata_m7  (rdata_m7)
                                ,.rresp_m7  (rresp_m7)
                                ,.rlast_m7  (rlast_m[7])
                                ,.rvalid_m7 (rvalid_m[7])
                                ,.rready_m7 (rready_m[7])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m7 (awsideband_m7)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m7 (wsideband_m7)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m7 (bsideband_m7)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m7 (arsideband_m7)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m7 (rsideband_m7)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m7 (awuser_m7)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m7 (wuser_m7)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m7 (buser_m7)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m7 (aruser_m7)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m7 (ruser_m7)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m7 (awdomain_m7)
                                ,.awsnoop_m7 (awsnoop_m7)
                                ,.awbar_m7    (awbar_m7)
                                ,.ardomain_m7 (ardomain_m7)
                                ,.arsnoop_m7 (arsnoop_m7)
                                ,.arbar_m7    (arbar_m7)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m7(axi_master_priority[7])
                                //,.mst_priority_m7(7)
   `endif
`endif
`ifdef AXI_HAS_M8

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m8 (xdcdr_slv_num_rd_m8)
                                ,.xdcdr_slv_num_wr_m8 (xdcdr_slv_num_wr_m8)
   `endif
                                ,.awid_m8    (awid_m8)
                                ,.awaddr_m8  (awaddr_m8)
                                ,.awlen_m8   (awlen_m8)
                                ,.awsize_m8  (awsize_m8)
                                ,.awburst_m8 (awburst_m8)
                                ,.awlock_m8  (awlock_m8)
                                ,.awcache_m8 (awcache_m8)
                                ,.awprot_m8  (awprot_m8)
                                ,.awvalid_m8 (awvalid_m[8])
                                ,.awready_m8 (awready_m[8])
  `ifdef AXI_AWQOS_EXT_M8

                                ,.awqos_m8 (awqos_m8)
  `endif
  `ifdef AXI_ARQOS_EXT_M8

                                ,.arqos_m8 (arqos_m8)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m8    (wid_m8)
   `endif
                                ,.wdata_m8  (wdata_m8)
                                ,.wstrb_m8  (wstrb_m8)
                                ,.wlast_m8  (wlast_m[8])
                                ,.wvalid_m8 (wvalid_m[8])
                                ,.wready_m8 (wready_m[8])
                                ,.bid_m8    (bid_m8)
                                ,.bresp_m8  (bresp_m8)
                                ,.bvalid_m8 (bvalid_m[8])
                                ,.bready_m8 (bready_m[8])
                                ,.arid_m8    (arid_m8)
                                ,.araddr_m8  (araddr_m8)
                                ,.arlen_m8   (arlen_m8)
                                ,.arsize_m8  (arsize_m8)
                                ,.arburst_m8 (arburst_m8)
                                ,.arlock_m8  (arlock_m8)
                                ,.arcache_m8 (arcache_m8)
                                ,.arprot_m8  (arprot_m8)
                                ,.arvalid_m8 (arvalid_m[8])
                                ,.arready_m8 (arready_m[8])
                                ,.rid_m8    (rid_m8)
                                ,.rdata_m8  (rdata_m8)
                                ,.rresp_m8  (rresp_m8)
                                ,.rlast_m8  (rlast_m[8])
                                ,.rvalid_m8 (rvalid_m[8])
                                ,.rready_m8 (rready_m[8])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m8 (awsideband_m8)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m8 (wsideband_m8)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m8 (bsideband_m8)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m8 (arsideband_m8)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m8 (rsideband_m8)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m8 (awuser_m8)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m8 (wuser_m8)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m8 (buser_m8)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m8 (aruser_m8)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m8 (ruser_m8)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m8 (awdomain_m8)
                                ,.awsnoop_m8 (awsnoop_m8)
                                ,.awbar_m8    (awbar_m8)
                                ,.ardomain_m8 (ardomain_m8)
                                ,.arsnoop_m8 (arsnoop_m8)
                                ,.arbar_m8    (arbar_m8)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m8(axi_master_priority[8])
                               //,.mst_priority_m8(8)
   `endif
`endif
`ifdef AXI_HAS_M9

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m9 (xdcdr_slv_num_rd_m9)
                                ,.xdcdr_slv_num_wr_m9 (xdcdr_slv_num_wr_m9)
   `endif
                                ,.awid_m9    (awid_m9)
                                ,.awaddr_m9  (awaddr_m9)
                                ,.awlen_m9   (awlen_m9)
                                ,.awsize_m9  (awsize_m9)
                                ,.awburst_m9 (awburst_m9)
                                ,.awlock_m9  (awlock_m9)
                                ,.awcache_m9 (awcache_m9)
                                ,.awprot_m9  (awprot_m9)
                                ,.awvalid_m9 (awvalid_m[9])
                                ,.awready_m9 (awready_m[9])
  `ifdef AXI_AWQOS_EXT_M9

                                ,.awqos_m9 (awqos_m9)
  `endif
  `ifdef AXI_ARQOS_EXT_M9

                                ,.arqos_m9 (arqos_m9)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m9    (wid_m9)
   `endif
                                ,.wdata_m9  (wdata_m9)
                                ,.wstrb_m9  (wstrb_m9)
                                ,.wlast_m9  (wlast_m[9])
                                ,.wvalid_m9 (wvalid_m[9])
                                ,.wready_m9 (wready_m[9])
                                ,.bid_m9    (bid_m9)
                                ,.bresp_m9  (bresp_m9)
                                ,.bvalid_m9 (bvalid_m[9])
                                ,.bready_m9 (bready_m[9])
                                ,.arid_m9    (arid_m9)
                                ,.araddr_m9  (araddr_m9)
                                ,.arlen_m9   (arlen_m9)
                                ,.arsize_m9  (arsize_m9)
                                ,.arburst_m9 (arburst_m9)
                                ,.arlock_m9  (arlock_m9)
                                ,.arcache_m9 (arcache_m9)
                                ,.arprot_m9  (arprot_m9)
                                ,.arvalid_m9 (arvalid_m[9])
                                ,.arready_m9 (arready_m[9])
                                ,.rid_m9    (rid_m9)
                                ,.rdata_m9  (rdata_m9)
                                ,.rresp_m9  (rresp_m9)
                                ,.rlast_m9  (rlast_m[9])
                                ,.rvalid_m9 (rvalid_m[9])
                                ,.rready_m9 (rready_m[9])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m9 (awsideband_m9)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m9 (wsideband_m9)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m9 (bsideband_m9)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m9 (arsideband_m9)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m9 (rsideband_m9)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m9 (awuser_m9)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m9 (wuser_m9)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m9 (buser_m9)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m9 (aruser_m9)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m9 (ruser_m9)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m9 (awdomain_m9)
                                ,.awsnoop_m9 (awsnoop_m9)
                                ,.awbar_m9    (awbar_m9)
                                ,.ardomain_m9 (ardomain_m9)
                                ,.arsnoop_m9 (arsnoop_m9)
                                ,.arbar_m9    (arbar_m9)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m9(axi_master_priority[9])
                                //,.mst_priority_m9(9)
   `endif
`endif
`ifdef AXI_HAS_M10

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m10 (xdcdr_slv_num_rd_m10)
                                ,.xdcdr_slv_num_wr_m10 (xdcdr_slv_num_wr_m10)
   `endif
                                ,.awid_m10    (awid_m10)
                                ,.awaddr_m10  (awaddr_m10)
                                ,.awlen_m10   (awlen_m10)
                                ,.awsize_m10  (awsize_m10)
                                ,.awburst_m10 (awburst_m10)
                                ,.awlock_m10  (awlock_m10)
                                ,.awcache_m10 (awcache_m10)
                                ,.awprot_m10  (awprot_m10)
                                ,.awvalid_m10 (awvalid_m[10])
                                ,.awready_m10 (awready_m[10])
  `ifdef AXI_AWQOS_EXT_M10

                                ,.awqos_m10 (awqos_m10)
  `endif
  `ifdef AXI_ARQOS_EXT_M10

                                ,.arqos_m10 (arqos_m10)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m10    (wid_m10)
   `endif
                                ,.wdata_m10  (wdata_m10)
                                ,.wstrb_m10  (wstrb_m10)
                                ,.wlast_m10  (wlast_m[10])
                                ,.wvalid_m10 (wvalid_m[10])
                                ,.wready_m10 (wready_m[10])
                                ,.bid_m10    (bid_m10)
                                ,.bresp_m10  (bresp_m10)
                                ,.bvalid_m10 (bvalid_m[10])
                                ,.bready_m10 (bready_m[10])
                                ,.arid_m10    (arid_m10)
                                ,.araddr_m10  (araddr_m10)
                                ,.arlen_m10   (arlen_m10)
                                ,.arsize_m10  (arsize_m10)
                                ,.arburst_m10 (arburst_m10)
                                ,.arlock_m10  (arlock_m10)
                                ,.arcache_m10 (arcache_m10)
                                ,.arprot_m10  (arprot_m10)
                                ,.arvalid_m10 (arvalid_m[10])
                                ,.arready_m10 (arready_m[10])
                                ,.rid_m10    (rid_m10)
                                ,.rdata_m10  (rdata_m10)
                                ,.rresp_m10  (rresp_m10)
                                ,.rlast_m10  (rlast_m[10])
                                ,.rvalid_m10 (rvalid_m[10])
                                ,.rready_m10 (rready_m[10])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m10 (awsideband_m10)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m10 (wsideband_m10)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m10 (bsideband_m10)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m10 (arsideband_m10)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m10 (rsideband_m10)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m10 (awuser_m10)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m10 (wuser_m10)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m10 (buser_m10)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m10 (aruser_m10)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m10 (ruser_m10)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m10 (awdomain_m10)
                                ,.awsnoop_m10 (awsnoop_m10)
                                ,.awbar_m10    (awbar_m10)
                                ,.ardomain_m10 (ardomain_m10)
                                ,.arsnoop_m10 (arsnoop_m10)
                                ,.arbar_m10    (arbar_m10)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m10(axi_master_priority[10])
                                //,.mst_priority_m10(10)
   `endif
`endif
`ifdef AXI_HAS_M11

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m11 (xdcdr_slv_num_rd_m11)
                                ,.xdcdr_slv_num_wr_m11 (xdcdr_slv_num_wr_m11)
   `endif
                                ,.awid_m11    (awid_m11)
                                ,.awaddr_m11  (awaddr_m11)
                                ,.awlen_m11   (awlen_m11)
                                ,.awsize_m11  (awsize_m11)
                                ,.awburst_m11 (awburst_m11)
                                ,.awlock_m11  (awlock_m11)
                                ,.awcache_m11 (awcache_m11)
                                ,.awprot_m11  (awprot_m11)
                                ,.awvalid_m11 (awvalid_m[11])
                                ,.awready_m11 (awready_m[11])
  `ifdef AXI_AWQOS_EXT_M11

                                ,.awqos_m11 (awqos_m11)
  `endif
  `ifdef AXI_ARQOS_EXT_M11

                                ,.arqos_m11 (arqos_m11)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m11    (wid_m11)
   `endif
                                ,.wdata_m11  (wdata_m11)
                                ,.wstrb_m11  (wstrb_m11)
                                ,.wlast_m11  (wlast_m[11])
                                ,.wvalid_m11 (wvalid_m[11])
                                ,.wready_m11 (wready_m[11])
                                ,.bid_m11    (bid_m11)
                                ,.bresp_m11  (bresp_m11)
                                ,.bvalid_m11 (bvalid_m[11])
                                ,.bready_m11 (bready_m[11])
                                ,.arid_m11    (arid_m11)
                                ,.araddr_m11  (araddr_m11)
                                ,.arlen_m11   (arlen_m11)
                                ,.arsize_m11  (arsize_m11)
                                ,.arburst_m11 (arburst_m11)
                                ,.arlock_m11  (arlock_m11)
                                ,.arcache_m11 (arcache_m11)
                                ,.arprot_m11  (arprot_m11)
                                ,.arvalid_m11 (arvalid_m[11])
                                ,.arready_m11 (arready_m[11])
                                ,.rid_m11    (rid_m11)
                                ,.rdata_m11  (rdata_m11)
                                ,.rresp_m11  (rresp_m11)
                                ,.rlast_m11  (rlast_m[11])
                                ,.rvalid_m11 (rvalid_m[11])
                                ,.rready_m11 (rready_m[11])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m11 (awsideband_m11)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m11 (wsideband_m11)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m11 (bsideband_m11)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m11 (arsideband_m11)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m11 (rsideband_m11)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m11 (awuser_m11)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m11 (wuser_m11)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m11 (buser_m11)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m11 (aruser_m11)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m11 (ruser_m11)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m11 (awdomain_m11)
                                ,.awsnoop_m11 (awsnoop_m11)
                                ,.awbar_m11    (awbar_m11)
                                ,.ardomain_m11 (ardomain_m11)
                                ,.arsnoop_m11 (arsnoop_m11)
                                ,.arbar_m11    (arbar_m11)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m11(axi_master_priority[11])
                                //,.mst_priority_m11(11)
   `endif
`endif
`ifdef AXI_HAS_M12

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m12 (xdcdr_slv_num_rd_m12)
                                ,.xdcdr_slv_num_wr_m12 (xdcdr_slv_num_wr_m12)
   `endif
                                ,.awid_m12    (awid_m12)
                                ,.awaddr_m12  (awaddr_m12)
                                ,.awlen_m12   (awlen_m12)
                                ,.awsize_m12  (awsize_m12)
                                ,.awburst_m12 (awburst_m12)
                                ,.awlock_m12  (awlock_m12)
                                ,.awcache_m12 (awcache_m12)
                                ,.awprot_m12  (awprot_m12)
                                ,.awvalid_m12 (awvalid_m[12])
                                ,.awready_m12 (awready_m[12])
  `ifdef AXI_AWQOS_EXT_M12

                                ,.awqos_m12 (awqos_m12)
  `endif
  `ifdef AXI_ARQOS_EXT_M12

                                ,.arqos_m12 (arqos_m12)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m12    (wid_m12)
   `endif
                                ,.wdata_m12  (wdata_m12)
                                ,.wstrb_m12  (wstrb_m12)
                                ,.wlast_m12  (wlast_m[12])
                                ,.wvalid_m12 (wvalid_m[12])
                                ,.wready_m12 (wready_m[12])
                                ,.bid_m12    (bid_m12)
                                ,.bresp_m12  (bresp_m12)
                                ,.bvalid_m12 (bvalid_m[12])
                                ,.bready_m12 (bready_m[12])
                                ,.arid_m12    (arid_m12)
                                ,.araddr_m12  (araddr_m12)
                                ,.arlen_m12   (arlen_m12)
                                ,.arsize_m12  (arsize_m12)
                                ,.arburst_m12 (arburst_m12)
                                ,.arlock_m12  (arlock_m12)
                                ,.arcache_m12 (arcache_m12)
                                ,.arprot_m12  (arprot_m12)
                                ,.arvalid_m12 (arvalid_m[12])
                                ,.arready_m12 (arready_m[12])
                                ,.rid_m12    (rid_m12)
                                ,.rdata_m12  (rdata_m12)
                                ,.rresp_m12  (rresp_m12)
                                ,.rlast_m12  (rlast_m[12])
                                ,.rvalid_m12 (rvalid_m[12])
                                ,.rready_m12 (rready_m[12])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m12 (awsideband_m12)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m12 (wsideband_m12)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m12 (bsideband_m12)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m12 (arsideband_m12)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m12 (rsideband_m12)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m12 (awuser_m12)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m12 (wuser_m12)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m12 (buser_m12)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m12 (aruser_m12)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m12 (ruser_m12)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m12 (awdomain_m12)
                                ,.awsnoop_m12 (awsnoop_m12)
                                ,.awbar_m12    (awbar_m12)
                                ,.ardomain_m12 (ardomain_m12)
                                ,.arsnoop_m12 (arsnoop_m12)
                                ,.arbar_m12    (arbar_m12)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m12(axi_master_priority[12])
                                //,.mst_priority_m12(12)
   `endif
`endif
`ifdef AXI_HAS_M13

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m13 (xdcdr_slv_num_rd_m13)
                                ,.xdcdr_slv_num_wr_m13 (xdcdr_slv_num_wr_m13)
   `endif
                                ,.awid_m13    (awid_m13)
                                ,.awaddr_m13  (awaddr_m13)
                                ,.awlen_m13   (awlen_m13)
                                ,.awsize_m13  (awsize_m13)
                                ,.awburst_m13 (awburst_m13)
                                ,.awlock_m13  (awlock_m13)
                                ,.awcache_m13 (awcache_m13)
                                ,.awprot_m13  (awprot_m13)
                                ,.awvalid_m13 (awvalid_m[13])
                                ,.awready_m13 (awready_m[13])
  `ifdef AXI_AWQOS_EXT_M13

                                ,.awqos_m13 (awqos_m13)
  `endif
  `ifdef AXI_ARQOS_EXT_M13

                                ,.arqos_m13 (arqos_m13)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m13    (wid_m13)
   `endif
                                ,.wdata_m13  (wdata_m13)
                                ,.wstrb_m13  (wstrb_m13)
                                ,.wlast_m13  (wlast_m[13])
                                ,.wvalid_m13 (wvalid_m[13])
                                ,.wready_m13 (wready_m[13])
                                ,.bid_m13    (bid_m13)
                                ,.bresp_m13  (bresp_m13)
                                ,.bvalid_m13 (bvalid_m[13])
                                ,.bready_m13 (bready_m[13])
                                ,.arid_m13    (arid_m13)
                                ,.araddr_m13  (araddr_m13)
                                ,.arlen_m13   (arlen_m13)
                                ,.arsize_m13  (arsize_m13)
                                ,.arburst_m13 (arburst_m13)
                                ,.arlock_m13  (arlock_m13)
                                ,.arcache_m13 (arcache_m13)
                                ,.arprot_m13  (arprot_m13)
                                ,.arvalid_m13 (arvalid_m[13])
                                ,.arready_m13 (arready_m[13])
                                ,.rid_m13    (rid_m13)
                                ,.rdata_m13  (rdata_m13)
                                ,.rresp_m13  (rresp_m13)
                                ,.rlast_m13  (rlast_m[13])
                                ,.rvalid_m13 (rvalid_m[13])
                                ,.rready_m13 (rready_m[13])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m13 (awsideband_m13)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m13 (wsideband_m13)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m13 (bsideband_m13)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m13 (arsideband_m13)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m13 (rsideband_m13)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m13 (awuser_m13)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m13 (wuser_m13)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m13 (buser_m13)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m13 (aruser_m13)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m13 (ruser_m13)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m13 (awdomain_m13)
                                ,.awsnoop_m13 (awsnoop_m13)
                                ,.awbar_m13    (awbar_m13)
                                ,.ardomain_m13 (ardomain_m13)
                                ,.arsnoop_m13 (arsnoop_m13)
                                ,.arbar_m13    (arbar_m13)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m13(axi_master_priority[13])
                                //,.mst_priority_m13(13)
   `endif
`endif
`ifdef AXI_HAS_M14

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m14 (xdcdr_slv_num_rd_m14)
                                ,.xdcdr_slv_num_wr_m14 (xdcdr_slv_num_wr_m14)
   `endif
                                ,.awid_m14    (awid_m14)
                                ,.awaddr_m14  (awaddr_m14)
                                ,.awlen_m14   (awlen_m14)
                                ,.awsize_m14  (awsize_m14)
                                ,.awburst_m14 (awburst_m14)
                                ,.awlock_m14  (awlock_m14)
                                ,.awcache_m14 (awcache_m14)
                                ,.awprot_m14  (awprot_m14)
                                ,.awvalid_m14 (awvalid_m[14])
                                ,.awready_m14 (awready_m[14])
  `ifdef AXI_AWQOS_EXT_M14

                                ,.awqos_m14 (awqos_m14)
  `endif
  `ifdef AXI_ARQOS_EXT_M14

                                ,.arqos_m14 (arqos_m14)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m14    (wid_m14)
   `endif
                                ,.wdata_m14  (wdata_m14)
                                ,.wstrb_m14  (wstrb_m14)
                                ,.wlast_m14  (wlast_m[14])
                                ,.wvalid_m14 (wvalid_m[14])
                                ,.wready_m14 (wready_m[14])
                                ,.bid_m14    (bid_m14)
                                ,.bresp_m14  (bresp_m14)
                                ,.bvalid_m14 (bvalid_m[14])
                                ,.bready_m14 (bready_m[14])
                                ,.arid_m14    (arid_m14)
                                ,.araddr_m14  (araddr_m14)
                                ,.arlen_m14   (arlen_m14)
                                ,.arsize_m14  (arsize_m14)
                                ,.arburst_m14 (arburst_m14)
                                ,.arlock_m14  (arlock_m14)
                                ,.arcache_m14 (arcache_m14)
                                ,.arprot_m14  (arprot_m14)
                                ,.arvalid_m14 (arvalid_m[14])
                                ,.arready_m14 (arready_m[14])
                                ,.rid_m14    (rid_m14)
                                ,.rdata_m14  (rdata_m14)
                                ,.rresp_m14  (rresp_m14)
                                ,.rlast_m14  (rlast_m[14])
                                ,.rvalid_m14 (rvalid_m[14])
                                ,.rready_m14 (rready_m[14])
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m14(axi_master_priority[14])
                                //,.mst_priority_m14(14)
   `endif
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m14 (awsideband_m14)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m14 (wsideband_m14)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m14 (bsideband_m14)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m14 (arsideband_m14)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m14 (rsideband_m14)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m14 (awuser_m14)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m14 (wuser_m14)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m14 (buser_m14)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m14 (aruser_m14)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m14 (ruser_m14)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m14 (awdomain_m14)
                                ,.awsnoop_m14 (awsnoop_m14)
                                ,.awbar_m14    (awbar_m14)
                                ,.ardomain_m14 (ardomain_m14)
                                ,.arsnoop_m14 (arsnoop_m14)
                                ,.arbar_m14    (arbar_m14)
   `endif 
`endif
`ifdef AXI_HAS_M15

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m15 (xdcdr_slv_num_rd_m15)
                                ,.xdcdr_slv_num_wr_m15 (xdcdr_slv_num_wr_m15)
   `endif
                                ,.awid_m15    (awid_m15)
                                ,.awaddr_m15  (awaddr_m15)
                                ,.awlen_m15   (awlen_m15)
                                ,.awsize_m15  (awsize_m15)
                                ,.awburst_m15 (awburst_m15)
                                ,.awlock_m15  (awlock_m15)
                                ,.awcache_m15 (awcache_m15)
                                ,.awprot_m15  (awprot_m15)
                                ,.awvalid_m15 (awvalid_m[15])
                                ,.awready_m15 (awready_m[15])
  `ifdef AXI_AWQOS_EXT_M15

                                ,.awqos_m15 (awqos_m15)
  `endif
  `ifdef AXI_ARQOS_EXT_M15

                                ,.arqos_m15 (arqos_m15)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m15    (wid_m15)
   `endif
                                ,.wdata_m15  (wdata_m15)
                                ,.wstrb_m15  (wstrb_m15)
                                ,.wlast_m15  (wlast_m[15])
                                ,.wvalid_m15 (wvalid_m[15])
                                ,.wready_m15 (wready_m[15])
                                ,.bid_m15    (bid_m15)
                                ,.bresp_m15  (bresp_m15)
                                ,.bvalid_m15 (bvalid_m[15])
                                ,.bready_m15 (bready_m[15])
                                ,.arid_m15    (arid_m15)
                                ,.araddr_m15  (araddr_m15)
                                ,.arlen_m15   (arlen_m15)
                                ,.arsize_m15  (arsize_m15)
                                ,.arburst_m15 (arburst_m15)
                                ,.arlock_m15  (arlock_m15)
                                ,.arcache_m15 (arcache_m15)
                                ,.arprot_m15  (arprot_m15)
                                ,.arvalid_m15 (arvalid_m[15])
                                ,.arready_m15 (arready_m[15])
                                ,.rid_m15    (rid_m15)
                                ,.rdata_m15  (rdata_m15)
                                ,.rresp_m15  (rresp_m15)
                                ,.rlast_m15  (rlast_m[15])
                                ,.rvalid_m15 (rvalid_m[15])
                                ,.rready_m15 (rready_m[15])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m15 (awsideband_m15)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m15 (wsideband_m15)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m15 (bsideband_m15)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m15 (arsideband_m15)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m15 (rsideband_m15)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m15 (awuser_m15)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m15 (wuser_m15)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m15 (buser_m15)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m15 (aruser_m15)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m15 (ruser_m15)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m15 (awdomain_m15)
                                ,.awsnoop_m15 (awsnoop_m15)
                                ,.awbar_m15    (awbar_m15)
                                ,.ardomain_m15 (ardomain_m15)
                                ,.arsnoop_m15 (arsnoop_m15)
                                ,.arbar_m15    (arbar_m15)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m15(axi_master_priority[15])
                                //,.mst_priority_m15(15)
   `endif
`endif
`ifdef AXI_HAS_M16

   `ifdef AXI_XDCDR

                                ,.xdcdr_slv_num_rd_m16 (xdcdr_slv_num_rd_m16)
                                ,.xdcdr_slv_num_wr_m16 (xdcdr_slv_num_wr_m16)
   `endif
                                ,.awid_m16    (awid_m16)
                                ,.awaddr_m16  (awaddr_m16)
                                ,.awlen_m16   (awlen_m16)
                                ,.awsize_m16  (awsize_m16)
                                ,.awburst_m16 (awburst_m16)
                                ,.awlock_m16  (awlock_m16)
                                ,.awcache_m16 (awcache_m16)
                                ,.awprot_m16  (awprot_m16)
                                ,.awvalid_m16 (awvalid_m[16])
                                ,.awready_m16 (awready_m[16])
  `ifdef AXI_AWQOS_EXT_M16

                                ,.awqos_m16 (awqos_m16)
  `endif
  `ifdef AXI_ARQOS_EXT_M16

                                ,.arqos_m16 (arqos_m16)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_m16    (wid_m16)
   `endif
                                ,.wdata_m16  (wdata_m16)
                                ,.wstrb_m16  (wstrb_m16)
                                ,.wlast_m16  (wlast_m[16])
                                ,.wvalid_m16 (wvalid_m[16])
                                ,.wready_m16 (wready_m[16])
                                ,.bid_m16    (bid_m16)
                                ,.bresp_m16  (bresp_m16)
                                ,.bvalid_m16 (bvalid_m[16])
                                ,.bready_m16 (bready_m[16])
                                ,.arid_m16    (arid_m16)
                                ,.araddr_m16  (araddr_m16)
                                ,.arlen_m16   (arlen_m16)
                                ,.arsize_m16  (arsize_m16)
                                ,.arburst_m16 (arburst_m16)
                                ,.arlock_m16  (arlock_m16)
                                ,.arcache_m16 (arcache_m16)
                                ,.arprot_m16  (arprot_m16)
                                ,.arvalid_m16 (arvalid_m[16])
                                ,.arready_m16 (arready_m[16])
                                ,.rid_m16    (rid_m16)
                                ,.rdata_m16  (rdata_m16)
                                ,.rresp_m16  (rresp_m16)
                                ,.rlast_m16  (rlast_m[16])
                                ,.rvalid_m16 (rvalid_m[16])
                                ,.rready_m16 (rready_m[16])
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_m16 (awsideband_m16)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_m16 (wsideband_m16)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_m16 (bsideband_m16)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_m16 (arsideband_m16)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_m16 (rsideband_m16)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_m16 (awuser_m16)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_m16 (wuser_m16)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_m16 (buser_m16)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_m16 (aruser_m16)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_m16 (ruser_m16)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_m16 (awdomain_m16)
                                ,.awsnoop_m16 (awsnoop_m16)
                                ,.awbar_m16    (awbar_m16)
                                ,.ardomain_m16 (ardomain_m16)
                                ,.arsnoop_m16 (arsnoop_m16)
                                ,.arbar_m16    (arbar_m16)
   `endif 
   `ifdef AXI_EXT_PRIORITY

                                ,.mst_priority_m16(axi_master_priority[16])
                                //,.mst_priority_m16(16)
   `endif
`endif

`ifdef AXI_HAS_S1

            ,.awid_s1    (awid_s1)
                                ,.awaddr_s1  (awaddr_s1)
                                ,.awlen_s1   (awlen_s1)
                                ,.awsize_s1  (awsize_s1)
                                ,.awburst_s1 (awburst_s1)
                                ,.awlock_s1  (awlock_s1)
                                ,.awcache_s1 (awcache_s1)
                                ,.awprot_s1  (awprot_s1)
                                ,.awvalid_s1 (awvalid_s[1])
                                ,.awready_s1 (awready_s[1])
  `ifdef AXI_QOS

                                ,.awqos_s1 (awqos_s1)
                                ,.arqos_s1 (arqos_s1)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s1    (wid_s1)
   `endif
                                ,.wdata_s1  (wdata_s1)
                                ,.wstrb_s1  (wstrb_s1)
                                ,.wlast_s1  (wlast_s[1])
                                ,.wvalid_s1 (wvalid_s[1])
                                ,.wready_s1 (wready_s[1])
                                ,.bid_s1    (bid_s1)
                                ,.bresp_s1  (bresp_s1)
                                ,.bvalid_s1 (bvalid_s[1])
                                ,.bready_s1 (bready_s[1])
                                ,.arid_s1    (arid_s1)
                                ,.araddr_s1  (araddr_s1)
                                ,.arlen_s1   (arlen_s1)
                                ,.arsize_s1  (arsize_s1)
                                ,.arburst_s1 (arburst_s1)
                                ,.arlock_s1  (arlock_s1)
                                ,.arcache_s1 (arcache_s1)
                                ,.arprot_s1  (arprot_s1)
                                ,.arvalid_s1 (arvalid_s[1])
                                ,.arready_s1 (arready_s[1])
                                ,.rid_s1    (rid_s1)
                                ,.rdata_s1  (rdata_s1)
                                ,.rresp_s1  (rresp_s1)
                                ,.rvalid_s1 (rvalid_s[1])
                                ,.rlast_s1  (rlast_s[1])
                                ,.rready_s1 (rready_s[1])
   `ifdef AXI_REGIONS_S1

                                ,.awregion_s1 (awregion_s1)
                                ,.arregion_s1 (arregion_s1)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s1 (awsideband_s1)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s1 (wsideband_s1)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s1 (bsideband_s1)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s1 (arsideband_s1)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s1 (rsideband_s1)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s1 (awuser_s1)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s1 (wuser_s1)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s1 (buser_s1)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s1 (aruser_s1)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s1 (ruser_s1)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s1 (awdomain_s1)
                                ,.awsnoop_s1  (awsnoop_s1)
                                ,.awbar_s1 (awbar_s1)
                                ,.ardomain_s1 (ardomain_s1)
                                ,.arsnoop_s1 (arsnoop_s1)
                                ,.arbar_s1 (arbar_s1)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s1(axi_slave_priority[1])
                                //,.slv_priority_s1(1)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s1 (tz_secure_s[1])
   `endif
`endif


`ifdef AXI_HAS_S2

            ,.awid_s2    (awid_s2)
                                ,.awaddr_s2  (awaddr_s2)
                                ,.awlen_s2   (awlen_s2)
                                ,.awsize_s2  (awsize_s2)
                                ,.awburst_s2 (awburst_s2)
                                ,.awlock_s2  (awlock_s2)
                                ,.awcache_s2 (awcache_s2)
                                ,.awprot_s2  (awprot_s2)
                                ,.awvalid_s2 (awvalid_s[2])
                                ,.awready_s2 (awready_s[2])
  `ifdef AXI_QOS

                                ,.awqos_s2 (awqos_s2)
                                ,.arqos_s2 (arqos_s2)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s2    (wid_s2)
   `endif
                                ,.wdata_s2  (wdata_s2)
                                ,.wstrb_s2  (wstrb_s2)
                                ,.wlast_s2  (wlast_s[2])
                                ,.wvalid_s2 (wvalid_s[2])
                                ,.wready_s2 (wready_s[2])
                                ,.bid_s2    (bid_s2)
                                ,.bresp_s2  (bresp_s2)
                                ,.bvalid_s2 (bvalid_s[2])
                                ,.bready_s2 (bready_s[2])
                                ,.arid_s2    (arid_s2)
                                ,.araddr_s2  (araddr_s2)
                                ,.arlen_s2   (arlen_s2)
                                ,.arsize_s2  (arsize_s2)
                                ,.arburst_s2 (arburst_s2)
                                ,.arlock_s2  (arlock_s2)
                                ,.arcache_s2 (arcache_s2)
                                ,.arprot_s2  (arprot_s2)
                                ,.arvalid_s2 (arvalid_s[2])
                                ,.arready_s2 (arready_s[2])
                                ,.rid_s2    (rid_s2)
                                ,.rdata_s2  (rdata_s2)
                                ,.rresp_s2  (rresp_s2)
                                ,.rvalid_s2 (rvalid_s[2])
                                ,.rlast_s2  (rlast_s[2])
                                ,.rready_s2 (rready_s[2])
   `ifdef AXI_REGIONS_S2

                                ,.awregion_s2 (awregion_s2)
                                ,.arregion_s2 (arregion_s2)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s2 (awsideband_s2)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s2 (wsideband_s2)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s2 (bsideband_s2)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s2 (arsideband_s2)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s2 (rsideband_s2)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s2 (awuser_s2)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s2 (wuser_s2)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s2 (buser_s2)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s2 (aruser_s2)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s2 (ruser_s2)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s2 (awdomain_s2)
                                ,.awsnoop_s2  (awsnoop_s2)
                                ,.awbar_s2 (awbar_s2)
                                ,.ardomain_s2 (ardomain_s2)
                                ,.arsnoop_s2 (arsnoop_s2)
                                ,.arbar_s2 (arbar_s2)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s2(axi_slave_priority[2])
                                //,.slv_priority_s2(2)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s2 (tz_secure_s[2])
   `endif
`endif


`ifdef AXI_HAS_S3

            ,.awid_s3    (awid_s3)
                                ,.awaddr_s3  (awaddr_s3)
                                ,.awlen_s3   (awlen_s3)
                                ,.awsize_s3  (awsize_s3)
                                ,.awburst_s3 (awburst_s3)
                                ,.awlock_s3  (awlock_s3)
                                ,.awcache_s3 (awcache_s3)
                                ,.awprot_s3  (awprot_s3)
                                ,.awvalid_s3 (awvalid_s[3])
                                ,.awready_s3 (awready_s[3])
  `ifdef AXI_QOS

                                ,.awqos_s3 (awqos_s3)
                                ,.arqos_s3 (arqos_s3)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s3    (wid_s3)
   `endif
                                ,.wdata_s3  (wdata_s3)
                                ,.wstrb_s3  (wstrb_s3)
                                ,.wlast_s3  (wlast_s[3])
                                ,.wvalid_s3 (wvalid_s[3])
                                ,.wready_s3 (wready_s[3])
                                ,.bid_s3    (bid_s3)
                                ,.bresp_s3  (bresp_s3)
                                ,.bvalid_s3 (bvalid_s[3])
                                ,.bready_s3 (bready_s[3])
                                ,.arid_s3    (arid_s3)
                                ,.araddr_s3  (araddr_s3)
                                ,.arlen_s3   (arlen_s3)
                                ,.arsize_s3  (arsize_s3)
                                ,.arburst_s3 (arburst_s3)
                                ,.arlock_s3  (arlock_s3)
                                ,.arcache_s3 (arcache_s3)
                                ,.arprot_s3  (arprot_s3)
                                ,.arvalid_s3 (arvalid_s[3])
                                ,.arready_s3 (arready_s[3])
                                ,.rid_s3    (rid_s3)
                                ,.rdata_s3  (rdata_s3)
                                ,.rresp_s3  (rresp_s3)
                                ,.rvalid_s3 (rvalid_s[3])
                                ,.rlast_s3  (rlast_s[3])
                                ,.rready_s3 (rready_s[3])
   `ifdef AXI_REGIONS_S3

                                ,.awregion_s3 (awregion_s3)
                                ,.arregion_s3 (arregion_s3)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s3 (awsideband_s3)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s3 (wsideband_s3)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s3 (bsideband_s3)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s3 (arsideband_s3)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s3 (rsideband_s3)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s3 (awuser_s3)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s3 (wuser_s3)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s3 (buser_s3)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s3 (aruser_s3)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s3 (ruser_s3)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s3 (awdomain_s3)
                                ,.awsnoop_s3  (awsnoop_s3)
                                ,.awbar_s3 (awbar_s3)
                                ,.ardomain_s3 (ardomain_s3)
                                ,.arsnoop_s3 (arsnoop_s3)
                                ,.arbar_s3 (arbar_s3)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s3(axi_slave_priority[3])
                                //,.slv_priority_s3(3)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s3 (tz_secure_s[3])
   `endif
`endif


`ifdef AXI_HAS_S4

            ,.awid_s4    (awid_s4)
                                ,.awaddr_s4  (awaddr_s4)
                                ,.awlen_s4   (awlen_s4)
                                ,.awsize_s4  (awsize_s4)
                                ,.awburst_s4 (awburst_s4)
                                ,.awlock_s4  (awlock_s4)
                                ,.awcache_s4 (awcache_s4)
                                ,.awprot_s4  (awprot_s4)
                                ,.awvalid_s4 (awvalid_s[4])
                                ,.awready_s4 (awready_s[4])
  `ifdef AXI_QOS

                                ,.awqos_s4 (awqos_s4)
                                ,.arqos_s4 (arqos_s4)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s4    (wid_s4)
   `endif
                                ,.wdata_s4  (wdata_s4)
                                ,.wstrb_s4  (wstrb_s4)
                                ,.wlast_s4  (wlast_s[4])
                                ,.wvalid_s4 (wvalid_s[4])
                                ,.wready_s4 (wready_s[4])
                                ,.bid_s4    (bid_s4)
                                ,.bresp_s4  (bresp_s4)
                                ,.bvalid_s4 (bvalid_s[4])
                                ,.bready_s4 (bready_s[4])
                                ,.arid_s4    (arid_s4)
                                ,.araddr_s4  (araddr_s4)
                                ,.arlen_s4   (arlen_s4)
                                ,.arsize_s4  (arsize_s4)
                                ,.arburst_s4 (arburst_s4)
                                ,.arlock_s4  (arlock_s4)
                                ,.arcache_s4 (arcache_s4)
                                ,.arprot_s4  (arprot_s4)
                                ,.arvalid_s4 (arvalid_s[4])
                                ,.arready_s4 (arready_s[4])
                                ,.rid_s4    (rid_s4)
                                ,.rdata_s4  (rdata_s4)
                                ,.rresp_s4  (rresp_s4)
                                ,.rvalid_s4 (rvalid_s[4])
                                ,.rlast_s4  (rlast_s[4])
                                ,.rready_s4 (rready_s[4])
   `ifdef AXI_REGIONS_S4

                                ,.awregion_s4 (awregion_s4)
                                ,.arregion_s4 (arregion_s4)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s4 (awsideband_s4)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s4 (wsideband_s4)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s4 (bsideband_s4)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s4 (arsideband_s4)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s4 (rsideband_s4)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s4 (awuser_s4)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s4 (wuser_s4)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s4 (buser_s4)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s4 (aruser_s4)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s4 (ruser_s4)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s4 (awdomain_s4)
                                ,.awsnoop_s4  (awsnoop_s4)
                                ,.awbar_s4 (awbar_s4)
                                ,.ardomain_s4 (ardomain_s4)
                                ,.arsnoop_s4 (arsnoop_s4)
                                ,.arbar_s4 (arbar_s4)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                //,.slv_priority_s4(4)
                                ,.slv_priority_s4(4)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s4 (tz_secure_s[4])
   `endif
`endif


`ifdef AXI_HAS_S5

            ,.awid_s5    (awid_s5)
                                ,.awaddr_s5  (awaddr_s5)
                                ,.awlen_s5   (awlen_s5)
                                ,.awsize_s5  (awsize_s5)
                                ,.awburst_s5 (awburst_s5)
                                ,.awlock_s5  (awlock_s5)
                                ,.awcache_s5 (awcache_s5)
                                ,.awprot_s5  (awprot_s5)
                                ,.awvalid_s5 (awvalid_s[5])
                                ,.awready_s5 (awready_s[5])
  `ifdef AXI_QOS

                                ,.awqos_s5 (awqos_s5)
                                ,.arqos_s5 (arqos_s5)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s5    (wid_s5)
   `endif
                                ,.wdata_s5  (wdata_s5)
                                ,.wstrb_s5  (wstrb_s5)
                                ,.wlast_s5  (wlast_s[5])
                                ,.wvalid_s5 (wvalid_s[5])
                                ,.wready_s5 (wready_s[5])
                                ,.bid_s5    (bid_s5)
                                ,.bresp_s5  (bresp_s5)
                                ,.bvalid_s5 (bvalid_s[5])
                                ,.bready_s5 (bready_s[5])
                                ,.arid_s5    (arid_s5)
                                ,.araddr_s5  (araddr_s5)
                                ,.arlen_s5   (arlen_s5)
                                ,.arsize_s5  (arsize_s5)
                                ,.arburst_s5 (arburst_s5)
                                ,.arlock_s5  (arlock_s5)
                                ,.arcache_s5 (arcache_s5)
                                ,.arprot_s5  (arprot_s5)
                                ,.arvalid_s5 (arvalid_s[5])
                                ,.arready_s5 (arready_s[5])
                                ,.rid_s5    (rid_s5)
                                ,.rdata_s5  (rdata_s5)
                                ,.rresp_s5  (rresp_s5)
                                ,.rvalid_s5 (rvalid_s[5])
                                ,.rlast_s5  (rlast_s[5])
                                ,.rready_s5 (rready_s[5])
   `ifdef AXI_REGIONS_S5

                                ,.awregion_s5 (awregion_s5)
                                ,.arregion_s5 (arregion_s5)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s5 (awsideband_s5)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s5 (wsideband_s5)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s5 (bsideband_s5)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s5 (arsideband_s5)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s5 (rsideband_s5)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s5 (awuser_s5)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s5 (wuser_s5)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s5 (buser_s5)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s5 (aruser_s5)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s5 (ruser_s5)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s5 (awdomain_s5)
                                ,.awsnoop_s5  (awsnoop_s5)
                                ,.awbar_s5 (awbar_s5)
                                ,.ardomain_s5 (ardomain_s5)
                                ,.arsnoop_s5 (arsnoop_s5)
                                ,.arbar_s5 (arbar_s5)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s5(axi_slave_priority[5])
                                // ,.slv_priority_s5(5)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s5 (tz_secure_s[5])
   `endif
`endif


`ifdef AXI_HAS_S6

            ,.awid_s6    (awid_s6)
                                ,.awaddr_s6  (awaddr_s6)
                                ,.awlen_s6   (awlen_s6)
                                ,.awsize_s6  (awsize_s6)
                                ,.awburst_s6 (awburst_s6)
                                ,.awlock_s6  (awlock_s6)
                                ,.awcache_s6 (awcache_s6)
                                ,.awprot_s6  (awprot_s6)
                                ,.awvalid_s6 (awvalid_s[6])
                                ,.awready_s6 (awready_s[6])
  `ifdef AXI_QOS

                                ,.awqos_s6 (awqos_s6)
                                ,.arqos_s6 (arqos_s6)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s6    (wid_s6)
   `endif
                                ,.wdata_s6  (wdata_s6)
                                ,.wstrb_s6  (wstrb_s6)
                                ,.wlast_s6  (wlast_s[6])
                                ,.wvalid_s6 (wvalid_s[6])
                                ,.wready_s6 (wready_s[6])
                                ,.bid_s6    (bid_s6)
                                ,.bresp_s6  (bresp_s6)
                                ,.bvalid_s6 (bvalid_s[6])
                                ,.bready_s6 (bready_s[6])
                                ,.arid_s6    (arid_s6)
                                ,.araddr_s6  (araddr_s6)
                                ,.arlen_s6   (arlen_s6)
                                ,.arsize_s6  (arsize_s6)
                                ,.arburst_s6 (arburst_s6)
                                ,.arlock_s6  (arlock_s6)
                                ,.arcache_s6 (arcache_s6)
                                ,.arprot_s6  (arprot_s6)
                                ,.arvalid_s6 (arvalid_s[6])
                                ,.arready_s6 (arready_s[6])
                                ,.rid_s6    (rid_s6)
                                ,.rdata_s6  (rdata_s6)
                                ,.rresp_s6  (rresp_s6)
                                ,.rvalid_s6 (rvalid_s[6])
                                ,.rlast_s6  (rlast_s[6])
                                ,.rready_s6 (rready_s[6])
   `ifdef AXI_REGIONS_S6

                                ,.awregion_s6 (awregion_s6)
                                ,.arregion_s6 (arregion_s6)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s6 (awsideband_s6)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s6 (wsideband_s6)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s6 (bsideband_s6)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s6 (arsideband_s6)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s6 (rsideband_s6)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s6 (awuser_s6)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s6 (wuser_s6)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s6 (buser_s6)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s6 (aruser_s6)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s6 (ruser_s6)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s6 (awdomain_s6)
                                ,.awsnoop_s6  (awsnoop_s6)
                                ,.awbar_s6 (awbar_s6)
                                ,.ardomain_s6 (ardomain_s6)
                                ,.arsnoop_s6 (arsnoop_s6)
                                ,.arbar_s6 (arbar_s6)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s6(axi_slave_priority[6])
                                //,.slv_priority_s6(6)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s6 (tz_secure_s[6])
   `endif
`endif


`ifdef AXI_HAS_S7

            ,.awid_s7    (awid_s7)
                                ,.awaddr_s7  (awaddr_s7)
                                ,.awlen_s7   (awlen_s7)
                                ,.awsize_s7  (awsize_s7)
                                ,.awburst_s7 (awburst_s7)
                                ,.awlock_s7  (awlock_s7)
                                ,.awcache_s7 (awcache_s7)
                                ,.awprot_s7  (awprot_s7)
                                ,.awvalid_s7 (awvalid_s[7])
                                ,.awready_s7 (awready_s[7])
  `ifdef AXI_QOS

                                ,.awqos_s7 (awqos_s7)
                                ,.arqos_s7 (arqos_s7)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s7    (wid_s7)
   `endif
                                ,.wdata_s7  (wdata_s7)
                                ,.wstrb_s7  (wstrb_s7)
                                ,.wlast_s7  (wlast_s[7])
                                ,.wvalid_s7 (wvalid_s[7])
                                ,.wready_s7 (wready_s[7])
                                ,.bid_s7    (bid_s7)
                                ,.bresp_s7  (bresp_s7)
                                ,.bvalid_s7 (bvalid_s[7])
                                ,.bready_s7 (bready_s[7])
                                ,.arid_s7    (arid_s7)
                                ,.araddr_s7  (araddr_s7)
                                ,.arlen_s7   (arlen_s7)
                                ,.arsize_s7  (arsize_s7)
                                ,.arburst_s7 (arburst_s7)
                                ,.arlock_s7  (arlock_s7)
                                ,.arcache_s7 (arcache_s7)
                                ,.arprot_s7  (arprot_s7)
                                ,.arvalid_s7 (arvalid_s[7])
                                ,.arready_s7 (arready_s[7])
                                ,.rid_s7    (rid_s7)
                                ,.rdata_s7  (rdata_s7)
                                ,.rresp_s7  (rresp_s7)
                                ,.rvalid_s7 (rvalid_s[7])
                                ,.rlast_s7  (rlast_s[7])
                                ,.rready_s7 (rready_s[7])
   `ifdef AXI_REGIONS_S7

                                ,.awregion_s7 (awregion_s7)
                                ,.arregion_s7 (arregion_s7)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s7 (awsideband_s7)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s7 (wsideband_s7)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s7 (bsideband_s7)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s7 (arsideband_s7)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s7 (rsideband_s7)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s7 (awuser_s7)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s7 (wuser_s7)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s7 (buser_s7)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s7 (aruser_s7)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s7 (ruser_s7)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s7 (awdomain_s7)
                                ,.awsnoop_s7  (awsnoop_s7)
                                ,.awbar_s7 (awbar_s7)
                                ,.ardomain_s7 (ardomain_s7)
                                ,.arsnoop_s7 (arsnoop_s7)
                                ,.arbar_s7 (arbar_s7)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s7(axi_slave_priority[7])
                                //,.slv_priority_s7(7)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s7 (tz_secure_s[7])
   `endif
`endif


`ifdef AXI_HAS_S8

            ,.awid_s8    (awid_s8)
                                ,.awaddr_s8  (awaddr_s8)
                                ,.awlen_s8   (awlen_s8)
                                ,.awsize_s8  (awsize_s8)
                                ,.awburst_s8 (awburst_s8)
                                ,.awlock_s8  (awlock_s8)
                                ,.awcache_s8 (awcache_s8)
                                ,.awprot_s8  (awprot_s8)
                                ,.awvalid_s8 (awvalid_s[8])
                                ,.awready_s8 (awready_s[8])
  `ifdef AXI_QOS

                                ,.awqos_s8 (awqos_s8)
                                ,.arqos_s8 (arqos_s8)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s8    (wid_s8)
   `endif
                                ,.wdata_s8  (wdata_s8)
                                ,.wstrb_s8  (wstrb_s8)
                                ,.wlast_s8  (wlast_s[8])
                                ,.wvalid_s8 (wvalid_s[8])
                                ,.wready_s8 (wready_s[8])
                                ,.bid_s8    (bid_s8)
                                ,.bresp_s8  (bresp_s8)
                                ,.bvalid_s8 (bvalid_s[8])
                                ,.bready_s8 (bready_s[8])
                                ,.arid_s8    (arid_s8)
                                ,.araddr_s8  (araddr_s8)
                                ,.arlen_s8   (arlen_s8)
                                ,.arsize_s8  (arsize_s8)
                                ,.arburst_s8 (arburst_s8)
                                ,.arlock_s8  (arlock_s8)
                                ,.arcache_s8 (arcache_s8)
                                ,.arprot_s8  (arprot_s8)
                                ,.arvalid_s8 (arvalid_s[8])
                                ,.arready_s8 (arready_s[8])
                                ,.rid_s8    (rid_s8)
                                ,.rdata_s8  (rdata_s8)
                                ,.rresp_s8  (rresp_s8)
                                ,.rvalid_s8 (rvalid_s[8])
                                ,.rlast_s8  (rlast_s[8])
                                ,.rready_s8 (rready_s[8])
   `ifdef AXI_REGIONS_S8

                                ,.awregion_s8 (awregion_s8)
                                ,.arregion_s8 (arregion_s8)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s8 (awsideband_s8)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s8 (wsideband_s8)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s8 (bsideband_s8)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s8 (arsideband_s8)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s8 (rsideband_s8)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s8 (awuser_s8)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s8 (wuser_s8)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s8 (buser_s8)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s8 (aruser_s8)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s8 (ruser_s8)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s8 (awdomain_s8)
                                ,.awsnoop_s8  (awsnoop_s8)
                                ,.awbar_s8 (awbar_s8)
                                ,.ardomain_s8 (ardomain_s8)
                                ,.arsnoop_s8 (arsnoop_s8)
                                ,.arbar_s8 (arbar_s8)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s8(axi_slave_priority[8])
                                //,.slv_priority_s8(8)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s8 (tz_secure_s[8])
   `endif
`endif


`ifdef AXI_HAS_S9

            ,.awid_s9    (awid_s9)
                                ,.awaddr_s9  (awaddr_s9)
                                ,.awlen_s9   (awlen_s9)
                                ,.awsize_s9  (awsize_s9)
                                ,.awburst_s9 (awburst_s9)
                                ,.awlock_s9  (awlock_s9)
                                ,.awcache_s9 (awcache_s9)
                                ,.awprot_s9  (awprot_s9)
                                ,.awvalid_s9 (awvalid_s[9])
                                ,.awready_s9 (awready_s[9])
  `ifdef AXI_QOS

                                ,.awqos_s9 (awqos_s9)
                                ,.arqos_s9 (arqos_s9)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s9    (wid_s9)
   `endif
                                ,.wdata_s9  (wdata_s9)
                                ,.wstrb_s9  (wstrb_s9)
                                ,.wlast_s9  (wlast_s[9])
                                ,.wvalid_s9 (wvalid_s[9])
                                ,.wready_s9 (wready_s[9])
                                ,.bid_s9    (bid_s9)
                                ,.bresp_s9  (bresp_s9)
                                ,.bvalid_s9 (bvalid_s[9])
                                ,.bready_s9 (bready_s[9])
                                ,.arid_s9    (arid_s9)
                                ,.araddr_s9  (araddr_s9)
                                ,.arlen_s9   (arlen_s9)
                                ,.arsize_s9  (arsize_s9)
                                ,.arburst_s9 (arburst_s9)
                                ,.arlock_s9  (arlock_s9)
                                ,.arcache_s9 (arcache_s9)
                                ,.arprot_s9  (arprot_s9)
                                ,.arvalid_s9 (arvalid_s[9])
                                ,.arready_s9 (arready_s[9])
                                ,.rid_s9    (rid_s9)
                                ,.rdata_s9  (rdata_s9)
                                ,.rresp_s9  (rresp_s9)
                                ,.rvalid_s9 (rvalid_s[9])
                                ,.rlast_s9  (rlast_s[9])
                                ,.rready_s9 (rready_s[9])
   `ifdef AXI_REGIONS_S9

                                ,.awregion_s9 (awregion_s9)
                                ,.arregion_s9 (arregion_s9)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s9 (awsideband_s9)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s9 (wsideband_s9)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s9 (bsideband_s9)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s9 (arsideband_s9)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s9 (rsideband_s9)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s9 (awuser_s9)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s9 (wuser_s9)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s9 (buser_s9)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s9 (aruser_s9)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s9 (ruser_s9)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s9 (awdomain_s9)
                                ,.awsnoop_s9  (awsnoop_s9)
                                ,.awbar_s9 (awbar_s9)
                                ,.ardomain_s9 (ardomain_s9)
                                ,.arsnoop_s9 (arsnoop_s9)
                                ,.arbar_s9 (arbar_s9)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s9(axi_slave_priority[9])
                                // ,.slv_priority_s9(9)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s9 (tz_secure_s[9])
   `endif
`endif


`ifdef AXI_HAS_S10

            ,.awid_s10    (awid_s10)
                                ,.awaddr_s10  (awaddr_s10)
                                ,.awlen_s10   (awlen_s10)
                                ,.awsize_s10  (awsize_s10)
                                ,.awburst_s10 (awburst_s10)
                                ,.awlock_s10  (awlock_s10)
                                ,.awcache_s10 (awcache_s10)
                                ,.awprot_s10  (awprot_s10)
                                ,.awvalid_s10 (awvalid_s[10])
                                ,.awready_s10 (awready_s[10])
  `ifdef AXI_QOS

                                ,.awqos_s10 (awqos_s10)
                                ,.arqos_s10 (arqos_s10)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s10    (wid_s10)
   `endif
                                ,.wdata_s10  (wdata_s10)
                                ,.wstrb_s10  (wstrb_s10)
                                ,.wlast_s10  (wlast_s[10])
                                ,.wvalid_s10 (wvalid_s[10])
                                ,.wready_s10 (wready_s[10])
                                ,.bid_s10    (bid_s10)
                                ,.bresp_s10  (bresp_s10)
                                ,.bvalid_s10 (bvalid_s[10])
                                ,.bready_s10 (bready_s[10])
                                ,.arid_s10    (arid_s10)
                                ,.araddr_s10  (araddr_s10)
                                ,.arlen_s10   (arlen_s10)
                                ,.arsize_s10  (arsize_s10)
                                ,.arburst_s10 (arburst_s10)
                                ,.arlock_s10  (arlock_s10)
                                ,.arcache_s10 (arcache_s10)
                                ,.arprot_s10  (arprot_s10)
                                ,.arvalid_s10 (arvalid_s[10])
                                ,.arready_s10 (arready_s[10])
                                ,.rid_s10    (rid_s10)
                                ,.rdata_s10  (rdata_s10)
                                ,.rresp_s10  (rresp_s10)
                                ,.rvalid_s10 (rvalid_s[10])
                                ,.rlast_s10  (rlast_s[10])
                                ,.rready_s10 (rready_s[10])
   `ifdef AXI_REGIONS_S10

                                ,.awregion_s10 (awregion_s10)
                                ,.arregion_s10 (arregion_s10)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s10 (awsideband_s10)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s10 (wsideband_s10)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s10 (bsideband_s10)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s10 (arsideband_s10)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s10 (rsideband_s10)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s10 (awuser_s10)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s10 (wuser_s10)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s10 (buser_s10)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s10 (aruser_s10)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s10 (ruser_s10)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s10 (awdomain_s10)
                                ,.awsnoop_s10  (awsnoop_s10)
                                ,.awbar_s10 (awbar_s10)
                                ,.ardomain_s10 (ardomain_s10)
                                ,.arsnoop_s10 (arsnoop_s10)
                                ,.arbar_s10 (arbar_s10)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s10(axi_slave_priority[10])
                                // ,.slv_priority_s10(10)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s10 (tz_secure_s[10])
   `endif
`endif


`ifdef AXI_HAS_S11

            ,.awid_s11    (awid_s11)
                                ,.awaddr_s11  (awaddr_s11)
                                ,.awlen_s11   (awlen_s11)
                                ,.awsize_s11  (awsize_s11)
                                ,.awburst_s11 (awburst_s11)
                                ,.awlock_s11  (awlock_s11)
                                ,.awcache_s11 (awcache_s11)
                                ,.awprot_s11  (awprot_s11)
                                ,.awvalid_s11 (awvalid_s[11])
                                ,.awready_s11 (awready_s[11])
  `ifdef AXI_QOS

                                ,.awqos_s11 (awqos_s11)
                                ,.arqos_s11 (arqos_s11)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s11    (wid_s11)
   `endif
                                ,.wdata_s11  (wdata_s11)
                                ,.wstrb_s11  (wstrb_s11)
                                ,.wlast_s11  (wlast_s[11])
                                ,.wvalid_s11 (wvalid_s[11])
                                ,.wready_s11 (wready_s[11])
                                ,.bid_s11    (bid_s11)
                                ,.bresp_s11  (bresp_s11)
                                ,.bvalid_s11 (bvalid_s[11])
                                ,.bready_s11 (bready_s[11])
                                ,.arid_s11    (arid_s11)
                                ,.araddr_s11  (araddr_s11)
                                ,.arlen_s11   (arlen_s11)
                                ,.arsize_s11  (arsize_s11)
                                ,.arburst_s11 (arburst_s11)
                                ,.arlock_s11  (arlock_s11)
                                ,.arcache_s11 (arcache_s11)
                                ,.arprot_s11  (arprot_s11)
                                ,.arvalid_s11 (arvalid_s[11])
                                ,.arready_s11 (arready_s[11])
                                ,.rid_s11    (rid_s11)
                                ,.rdata_s11  (rdata_s11)
                                ,.rresp_s11  (rresp_s11)
                                ,.rvalid_s11 (rvalid_s[11])
                                ,.rlast_s11  (rlast_s[11])
                                ,.rready_s11 (rready_s[11])
   `ifdef AXI_REGIONS_S11

                                ,.awregion_s11 (awregion_s11)
                                ,.arregion_s11 (arregion_s11)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s11 (awsideband_s11)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s11 (wsideband_s11)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s11 (bsideband_s11)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s11 (arsideband_s11)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s11 (rsideband_s11)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s11 (awuser_s11)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s11 (wuser_s11)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s11 (buser_s11)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s11 (aruser_s11)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s11 (ruser_s11)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s11 (awdomain_s11)
                                ,.awsnoop_s11  (awsnoop_s11)
                                ,.awbar_s11 (awbar_s11)
                                ,.ardomain_s11 (ardomain_s11)
                                ,.arsnoop_s11 (arsnoop_s11)
                                ,.arbar_s11 (arbar_s11)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s11(axi_slave_priority[11])
                                // ,.slv_priority_s11(11)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s11 (tz_secure_s[11])
   `endif
`endif


`ifdef AXI_HAS_S12

            ,.awid_s12    (awid_s12)
                                ,.awaddr_s12  (awaddr_s12)
                                ,.awlen_s12   (awlen_s12)
                                ,.awsize_s12  (awsize_s12)
                                ,.awburst_s12 (awburst_s12)
                                ,.awlock_s12  (awlock_s12)
                                ,.awcache_s12 (awcache_s12)
                                ,.awprot_s12  (awprot_s12)
                                ,.awvalid_s12 (awvalid_s[12])
                                ,.awready_s12 (awready_s[12])
  `ifdef AXI_QOS

                                ,.awqos_s12 (awqos_s12)
                                ,.arqos_s12 (arqos_s12)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s12    (wid_s12)
   `endif
                                ,.wdata_s12  (wdata_s12)
                                ,.wstrb_s12  (wstrb_s12)
                                ,.wlast_s12  (wlast_s[12])
                                ,.wvalid_s12 (wvalid_s[12])
                                ,.wready_s12 (wready_s[12])
                                ,.bid_s12    (bid_s12)
                                ,.bresp_s12  (bresp_s12)
                                ,.bvalid_s12 (bvalid_s[12])
                                ,.bready_s12 (bready_s[12])
                                ,.arid_s12    (arid_s12)
                                ,.araddr_s12  (araddr_s12)
                                ,.arlen_s12   (arlen_s12)
                                ,.arsize_s12  (arsize_s12)
                                ,.arburst_s12 (arburst_s12)
                                ,.arlock_s12  (arlock_s12)
                                ,.arcache_s12 (arcache_s12)
                                ,.arprot_s12  (arprot_s12)
                                ,.arvalid_s12 (arvalid_s[12])
                                ,.arready_s12 (arready_s[12])
                                ,.rid_s12    (rid_s12)
                                ,.rdata_s12  (rdata_s12)
                                ,.rresp_s12  (rresp_s12)
                                ,.rvalid_s12 (rvalid_s[12])
                                ,.rlast_s12  (rlast_s[12])
                                ,.rready_s12 (rready_s[12])
   `ifdef AXI_REGIONS_S12

                                ,.awregion_s12 (awregion_s12)
                                ,.arregion_s12 (arregion_s12)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s12 (awsideband_s12)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s12 (wsideband_s12)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s12 (bsideband_s12)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s12 (arsideband_s12)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s12 (rsideband_s12)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s12 (awuser_s12)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s12 (wuser_s12)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s12 (buser_s12)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s12 (aruser_s12)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s12 (ruser_s12)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s12 (awdomain_s12)
                                ,.awsnoop_s12  (awsnoop_s12)
                                ,.awbar_s12 (awbar_s12)
                                ,.ardomain_s12 (ardomain_s12)
                                ,.arsnoop_s12 (arsnoop_s12)
                                ,.arbar_s12 (arbar_s12)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s12(axi_slave_priority[12])
                                // ,.slv_priority_s12(12)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s12 (tz_secure_s[12])
   `endif
`endif


`ifdef AXI_HAS_S13

            ,.awid_s13    (awid_s13)
                                ,.awaddr_s13  (awaddr_s13)
                                ,.awlen_s13   (awlen_s13)
                                ,.awsize_s13  (awsize_s13)
                                ,.awburst_s13 (awburst_s13)
                                ,.awlock_s13  (awlock_s13)
                                ,.awcache_s13 (awcache_s13)
                                ,.awprot_s13  (awprot_s13)
                                ,.awvalid_s13 (awvalid_s[13])
                                ,.awready_s13 (awready_s[13])
  `ifdef AXI_QOS

                                ,.awqos_s13 (awqos_s13)
                                ,.arqos_s13 (arqos_s13)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s13    (wid_s13)
   `endif
                                ,.wdata_s13  (wdata_s13)
                                ,.wstrb_s13  (wstrb_s13)
                                ,.wlast_s13  (wlast_s[13])
                                ,.wvalid_s13 (wvalid_s[13])
                                ,.wready_s13 (wready_s[13])
                                ,.bid_s13    (bid_s13)
                                ,.bresp_s13  (bresp_s13)
                                ,.bvalid_s13 (bvalid_s[13])
                                ,.bready_s13 (bready_s[13])
                                ,.arid_s13    (arid_s13)
                                ,.araddr_s13  (araddr_s13)
                                ,.arlen_s13   (arlen_s13)
                                ,.arsize_s13  (arsize_s13)
                                ,.arburst_s13 (arburst_s13)
                                ,.arlock_s13  (arlock_s13)
                                ,.arcache_s13 (arcache_s13)
                                ,.arprot_s13  (arprot_s13)
                                ,.arvalid_s13 (arvalid_s[13])
                                ,.arready_s13 (arready_s[13])
                                ,.rid_s13    (rid_s13)
                                ,.rdata_s13  (rdata_s13)
                                ,.rresp_s13  (rresp_s13)
                                ,.rvalid_s13 (rvalid_s[13])
                                ,.rlast_s13  (rlast_s[13])
                                ,.rready_s13 (rready_s[13])
   `ifdef AXI_REGIONS_S13

                                ,.awregion_s13 (awregion_s13)
                                ,.arregion_s13 (arregion_s13)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s13 (awsideband_s13)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s13 (wsideband_s13)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s13 (bsideband_s13)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s13 (arsideband_s13)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s13 (rsideband_s13)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s13 (awuser_s13)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s13 (wuser_s13)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s13 (buser_s13)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s13 (aruser_s13)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s13 (ruser_s13)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s13 (awdomain_s13)
                                ,.awsnoop_s13  (awsnoop_s13)
                                ,.awbar_s13 (awbar_s13)
                                ,.ardomain_s13 (ardomain_s13)
                                ,.arsnoop_s13 (arsnoop_s13)
                                ,.arbar_s13 (arbar_s13)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s13(axi_slave_priority[13])
                                // ,.slv_priority_s13(13)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s13 (tz_secure_s[13])
   `endif
`endif


`ifdef AXI_HAS_S14

            ,.awid_s14    (awid_s14)
                                ,.awaddr_s14  (awaddr_s14)
                                ,.awlen_s14   (awlen_s14)
                                ,.awsize_s14  (awsize_s14)
                                ,.awburst_s14 (awburst_s14)
                                ,.awlock_s14  (awlock_s14)
                                ,.awcache_s14 (awcache_s14)
                                ,.awprot_s14  (awprot_s14)
                                ,.awvalid_s14 (awvalid_s[14])
                                ,.awready_s14 (awready_s[14])
  `ifdef AXI_QOS

                                ,.awqos_s14 (awqos_s14)
                                ,.arqos_s14 (arqos_s14)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s14    (wid_s14)
   `endif
                                ,.wdata_s14  (wdata_s14)
                                ,.wstrb_s14  (wstrb_s14)
                                ,.wlast_s14  (wlast_s[14])
                                ,.wvalid_s14 (wvalid_s[14])
                                ,.wready_s14 (wready_s[14])
                                ,.bid_s14    (bid_s14)
                                ,.bresp_s14  (bresp_s14)
                                ,.bvalid_s14 (bvalid_s[14])
                                ,.bready_s14 (bready_s[14])
                                ,.arid_s14    (arid_s14)
                                ,.araddr_s14  (araddr_s14)
                                ,.arlen_s14   (arlen_s14)
                                ,.arsize_s14  (arsize_s14)
                                ,.arburst_s14 (arburst_s14)
                                ,.arlock_s14  (arlock_s14)
                                ,.arcache_s14 (arcache_s14)
                                ,.arprot_s14  (arprot_s14)
                                ,.arvalid_s14 (arvalid_s[14])
                                ,.arready_s14 (arready_s[14])
                                ,.rid_s14    (rid_s14)
                                ,.rdata_s14  (rdata_s14)
                                ,.rresp_s14  (rresp_s14)
                                ,.rvalid_s14 (rvalid_s[14])
                                ,.rlast_s14  (rlast_s[14])
                                ,.rready_s14 (rready_s[14])
   `ifdef AXI_REGIONS_S14

                                ,.awregion_s14 (awregion_s14)
                                ,.arregion_s14 (arregion_s14)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s14 (awsideband_s14)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s14 (wsideband_s14)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s14 (bsideband_s14)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s14 (arsideband_s14)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s14 (rsideband_s14)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s14 (awuser_s14)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s14 (wuser_s14)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s14 (buser_s14)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s14 (aruser_s14)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s14 (ruser_s14)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s14 (awdomain_s14)
                                ,.awsnoop_s14  (awsnoop_s14)
                                ,.awbar_s14 (awbar_s14)
                                ,.ardomain_s14 (ardomain_s14)
                                ,.arsnoop_s14 (arsnoop_s14)
                                ,.arbar_s14 (arbar_s14)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s14(axi_slave_priority[14])
                                // ,.slv_priority_s14(14)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s14 (tz_secure_s[14])
   `endif
`endif


`ifdef AXI_HAS_S15

            ,.awid_s15    (awid_s15)
                                ,.awaddr_s15  (awaddr_s15)
                                ,.awlen_s15   (awlen_s15)
                                ,.awsize_s15  (awsize_s15)
                                ,.awburst_s15 (awburst_s15)
                                ,.awlock_s15  (awlock_s15)
                                ,.awcache_s15 (awcache_s15)
                                ,.awprot_s15  (awprot_s15)
                                ,.awvalid_s15 (awvalid_s[15])
                                ,.awready_s15 (awready_s[15])
  `ifdef AXI_QOS

                                ,.awqos_s15 (awqos_s15)
                                ,.arqos_s15 (arqos_s15)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s15    (wid_s15)
   `endif
                                ,.wdata_s15  (wdata_s15)
                                ,.wstrb_s15  (wstrb_s15)
                                ,.wlast_s15  (wlast_s[15])
                                ,.wvalid_s15 (wvalid_s[15])
                                ,.wready_s15 (wready_s[15])
                                ,.bid_s15    (bid_s15)
                                ,.bresp_s15  (bresp_s15)
                                ,.bvalid_s15 (bvalid_s[15])
                                ,.bready_s15 (bready_s[15])
                                ,.arid_s15    (arid_s15)
                                ,.araddr_s15  (araddr_s15)
                                ,.arlen_s15   (arlen_s15)
                                ,.arsize_s15  (arsize_s15)
                                ,.arburst_s15 (arburst_s15)
                                ,.arlock_s15  (arlock_s15)
                                ,.arcache_s15 (arcache_s15)
                                ,.arprot_s15  (arprot_s15)
                                ,.arvalid_s15 (arvalid_s[15])
                                ,.arready_s15 (arready_s[15])
                                ,.rid_s15    (rid_s15)
                                ,.rdata_s15  (rdata_s15)
                                ,.rresp_s15  (rresp_s15)
                                ,.rvalid_s15 (rvalid_s[15])
                                ,.rlast_s15  (rlast_s[15])
                                ,.rready_s15 (rready_s[15])
   `ifdef AXI_REGIONS_S15

                                ,.awregion_s15 (awregion_s15)
                                ,.arregion_s15 (arregion_s15)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s15 (awsideband_s15)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s15 (wsideband_s15)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s15 (bsideband_s15)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s15 (arsideband_s15)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s15 (rsideband_s15)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s15 (awuser_s15)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s15 (wuser_s15)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s15 (buser_s15)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s15 (aruser_s15)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s15 (ruser_s15)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s15 (awdomain_s15)
                                ,.awsnoop_s15  (awsnoop_s15)
                                ,.awbar_s15 (awbar_s15)
                                ,.ardomain_s15 (ardomain_s15)
                                ,.arsnoop_s15 (arsnoop_s15)
                                ,.arbar_s15 (arbar_s15)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s15(axi_slave_priority[15])
                                // ,.slv_priority_s15(15)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s15 (tz_secure_s[15])
   `endif
`endif


`ifdef AXI_HAS_S16

            ,.awid_s16    (awid_s16)
                                ,.awaddr_s16  (awaddr_s16)
                                ,.awlen_s16   (awlen_s16)
                                ,.awsize_s16  (awsize_s16)
                                ,.awburst_s16 (awburst_s16)
                                ,.awlock_s16  (awlock_s16)
                                ,.awcache_s16 (awcache_s16)
                                ,.awprot_s16  (awprot_s16)
                                ,.awvalid_s16 (awvalid_s[16])
                                ,.awready_s16 (awready_s[16])
  `ifdef AXI_QOS

                                ,.awqos_s16 (awqos_s16)
                                ,.arqos_s16 (arqos_s16)
  `endif
   `ifdef AXI_HAS_AXI3

                                ,.wid_s16    (wid_s16)
   `endif
                                ,.wdata_s16  (wdata_s16)
                                ,.wstrb_s16  (wstrb_s16)
                                ,.wlast_s16  (wlast_s[16])
                                ,.wvalid_s16 (wvalid_s[16])
                                ,.wready_s16 (wready_s[16])
                                ,.bid_s16    (bid_s16)
                                ,.bresp_s16  (bresp_s16)
                                ,.bvalid_s16 (bvalid_s[16])
                                ,.bready_s16 (bready_s[16])
                                ,.arid_s16    (arid_s16)
                                ,.araddr_s16  (araddr_s16)
                                ,.arlen_s16   (arlen_s16)
                                ,.arsize_s16  (arsize_s16)
                                ,.arburst_s16 (arburst_s16)
                                ,.arlock_s16  (arlock_s16)
                                ,.arcache_s16 (arcache_s16)
                                ,.arprot_s16  (arprot_s16)
                                ,.arvalid_s16 (arvalid_s[16])
                                ,.arready_s16 (arready_s[16])
                                ,.rid_s16    (rid_s16)
                                ,.rdata_s16  (rdata_s16)
                                ,.rresp_s16  (rresp_s16)
                                ,.rvalid_s16 (rvalid_s[16])
                                ,.rlast_s16  (rlast_s[16])
                                ,.rready_s16 (rready_s[16])
   `ifdef AXI_REGIONS_S16

                                ,.awregion_s16 (awregion_s16)
                                ,.arregion_s16 (arregion_s16)
   `endif    
`ifdef AXI_HAS_AXI3

   `ifdef AXI_INC_AWSB

                                ,.awsideband_s16 (awsideband_s16)
   `endif
   `ifdef AXI_INC_WSB

                                ,.wsideband_s16 (wsideband_s16)
   `endif
   `ifdef AXI_INC_BSB

                                ,.bsideband_s16 (bsideband_s16)
   `endif
   `ifdef AXI_INC_ARSB

                                ,.arsideband_s16 (arsideband_s16)
   `endif
   `ifdef AXI_INC_RSB

                                ,.rsideband_s16 (rsideband_s16)
   `endif
`else   
   `ifdef AXI_INC_AWSB

                                ,.awuser_s16 (awuser_s16)
   `endif  
   `ifdef AXI_INC_WSB

                                ,.wuser_s16 (wuser_s16)
   `endif  
   `ifdef AXI_INC_BSB

                                ,.buser_s16 (buser_s16)
   `endif  
   `ifdef AXI_INC_ARSB

                                ,.aruser_s16 (aruser_s16)
   `endif  
   `ifdef AXI_INC_RSB

                                ,.ruser_s16 (ruser_s16)
   `endif  
`endif   
   `ifdef AXI_HAS_ACELITE

                                ,.awdomain_s16 (awdomain_s16)
                                ,.awsnoop_s16  (awsnoop_s16)
                                ,.awbar_s16 (awbar_s16)
                                ,.ardomain_s16 (ardomain_s16)
                                ,.arsnoop_s16 (arsnoop_s16)
                                ,.arbar_s16 (arbar_s16)
   `endif    
   `ifdef AXI_EXT_PRIORITY

                                ,.slv_priority_s16(axi_slave_priority[16])
                                //,.slv_priority_s16(16)
   `endif
   `ifdef AXI_TZ_SUPPORT

                                ,.tz_secure_s16 (tz_secure_s[16])
   `endif
`endif

`ifdef AXI_HAS_LOWPWR_HS_IF

                                ,.csysreq        (csysreq)
                                ,.csysack        (csysack)
                                ,.cactive        (cactive)
`endif


`ifdef AXI_HAS_DLOCK_NOTIFY

                                ,.dlock_mst      (dlock_mst)
                                ,.dlock_slv      (dlock_slv)
                                ,.dlock_id       (dlock_id)
                                ,.dlock_wr       (dlock_wr)
                                ,.dlock_irq      (dlock_irq)
`endif

                                ,.dbg_awid_s0    (awid_s0)
                                ,.dbg_awaddr_s0  (awaddr_s0)
                                ,.dbg_awlen_s0   (awlen_s0)
                                ,.dbg_awsize_s0  (awsize_s0)
                                ,.dbg_awburst_s0 (awburst_s0)
                                ,.dbg_awlock_s0  (awlock_s0)
                                ,.dbg_awcache_s0 (awcache_s0)
                                ,.dbg_awprot_s0  (awprot_s0)
                                ,.dbg_awvalid_s0 (awvalid_s[0])
                                ,.dbg_awready_s0 (awready_s[0])
                                ,.dbg_wid_s0    (wid_s0)
                                ,.dbg_wdata_s0  (wdata_s0)
                                ,.dbg_wstrb_s0  (wstrb_s0)
                                ,.dbg_wlast_s0  (wlast_s[0])
                                ,.dbg_wvalid_s0 (wvalid_s[0])
                                ,.dbg_wready_s0 (wready_s[0])
                                ,.dbg_bid_s0    (bid_s0)
                                ,.dbg_bresp_s0  (bresp_s0)
                                ,.dbg_bvalid_s0 (bvalid_s[0])
                                ,.dbg_bready_s0 (bready_s[0])
                                ,.dbg_arid_s0    (arid_s0)
                                ,.dbg_araddr_s0  (araddr_s0)
                                ,.dbg_arlen_s0   (arlen_s0)
                                ,.dbg_arsize_s0  (arsize_s0)
                                ,.dbg_arburst_s0 (arburst_s0)
                                ,.dbg_arlock_s0  (arlock_s0)
                                ,.dbg_arcache_s0 (arcache_s0)
                                ,.dbg_arprot_s0  (arprot_s0)
                                ,.dbg_arvalid_s0 (arvalid_s[0])
                                ,.dbg_arready_s0 (arready_s[0])
                                ,.dbg_rid_s0    (rid_s0)
                                ,.dbg_rdata_s0  (rdata_s0)
                                ,.dbg_rresp_s0  (rresp_s0)
                                ,.dbg_rvalid_s0 (rvalid_s[0])
                                ,.dbg_rlast_s0  (rlast_s[0])
                                ,.dbg_rready_s0 (rready_s[0])
`ifdef AXI_QOS

                                ,.pclk(pclk)
                                ,.presetn(presetn)
                                ,.psel(apbif.psel)
                                ,.penable(apbif.penable)
                                ,.pwrite(apbif.pwrite)
                                ,.paddr(apbif.paddr)
                                ,.pwdata(apbif.pwdata)
                                ,.prdata(apbif.prdata)
`endif
               );

`ifdef AXI_HAS_LOWPWR_HS_IF

    tb_check_lp #(
       `AXI_NUM_MASTERS,
       `AXI_LOWPWR_NOPX_CNT,
       1,
       AR_HAS_BUFF,
       AW_HAS_BUFF,
       W_HAS_BUFF
    )
    U_check_lp (
     .clk            (aclk),
     .clklp          (aclklp),
     .resetn         (aresetn),
     .cvrgen         (~sim_in_progress),

     .awvalid_m_bus  (int_awvalid_m_bus),
     .awready_m_bus  (int_awready_m_bus),
     .arvalid_m_bus  (int_arvalid_m_bus),
     .arready_m_bus  (int_arready_m_bus),
     .wready_m_bus   (int_wready_m_bus),
     .bvalid_m_bus   (int_bvalid_m_bus),
     .bready_m_bus   (int_bready_m_bus),
     .rvalid_m_bus   (int_rvalid_m_bus),
     .rready_m_bus   (int_rready_m_bus),
     .rlast_m_bus    (int_rlast_m_bus),

     .csysreq        (int_csysreq),
     .csysack        (int_csysack),
     .cactive        (int_cactive)
    );
 `endif

`ifdef AXI_XDCDR

`ifdef AXI_HAS_M1

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M1, `AXI_LOG2_NSP1V_M1, 1
               ,`AXI_NV_S1_BY_M1
               ,`AXI_NV_S2_BY_M1
               ,`AXI_NV_S3_BY_M1
               ,`AXI_NV_S4_BY_M1
               ,`AXI_NV_S5_BY_M1
               ,`AXI_NV_S6_BY_M1
               ,`AXI_NV_S7_BY_M1
               ,`AXI_NV_S8_BY_M1
               ,`AXI_NV_S9_BY_M1
               ,`AXI_NV_S10_BY_M1
               ,`AXI_NV_S11_BY_M1
               ,`AXI_NV_S12_BY_M1
               ,`AXI_NV_S13_BY_M1
               ,`AXI_NV_S14_BY_M1
               ,`AXI_NV_S15_BY_M1
               ,`AXI_NV_S16_BY_M1
               , 1
               ,`AXI_BV_S1_BY_M1
               ,`AXI_BV_S2_BY_M1
               ,`AXI_BV_S3_BY_M1
               ,`AXI_BV_S4_BY_M1
               ,`AXI_BV_S5_BY_M1
               ,`AXI_BV_S6_BY_M1
               ,`AXI_BV_S7_BY_M1
               ,`AXI_BV_S8_BY_M1
               ,`AXI_BV_S9_BY_M1
               ,`AXI_BV_S10_BY_M1
               ,`AXI_BV_S11_BY_M1
               ,`AXI_BV_S12_BY_M1
               ,`AXI_BV_S13_BY_M1
               ,`AXI_BV_S14_BY_M1
               ,`AXI_BV_S15_BY_M1
               ,`AXI_BV_S16_BY_M1
             )
             U_ardcdr_m1(
                  .addr_i  (araddr_m1),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m1)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M1, `AXI_LOG2_NSP1V_M1, 1
               ,`AXI_NV_S1_BY_M1
               ,`AXI_NV_S2_BY_M1
               ,`AXI_NV_S3_BY_M1
               ,`AXI_NV_S4_BY_M1
               ,`AXI_NV_S5_BY_M1
               ,`AXI_NV_S6_BY_M1
               ,`AXI_NV_S7_BY_M1
               ,`AXI_NV_S8_BY_M1
               ,`AXI_NV_S9_BY_M1
               ,`AXI_NV_S10_BY_M1
               ,`AXI_NV_S11_BY_M1
               ,`AXI_NV_S12_BY_M1
               ,`AXI_NV_S13_BY_M1
               ,`AXI_NV_S14_BY_M1
               ,`AXI_NV_S15_BY_M1
               ,`AXI_NV_S16_BY_M1
               , 1
               ,`AXI_BV_S1_BY_M1
               ,`AXI_BV_S2_BY_M1
               ,`AXI_BV_S3_BY_M1
               ,`AXI_BV_S4_BY_M1
               ,`AXI_BV_S5_BY_M1
               ,`AXI_BV_S6_BY_M1
               ,`AXI_BV_S7_BY_M1
               ,`AXI_BV_S8_BY_M1
               ,`AXI_BV_S9_BY_M1
               ,`AXI_BV_S10_BY_M1
               ,`AXI_BV_S11_BY_M1
               ,`AXI_BV_S12_BY_M1
               ,`AXI_BV_S13_BY_M1
               ,`AXI_BV_S14_BY_M1
               ,`AXI_BV_S15_BY_M1
               ,`AXI_BV_S16_BY_M1
             )
       U_awdcdr_m1(
                  .addr_i  (awaddr_m1),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m1)
                 );
`endif
`ifdef AXI_HAS_M2

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M2, `AXI_LOG2_NSP1V_M2, 1
               ,`AXI_NV_S1_BY_M2
               ,`AXI_NV_S2_BY_M2
               ,`AXI_NV_S3_BY_M2
               ,`AXI_NV_S4_BY_M2
               ,`AXI_NV_S5_BY_M2
               ,`AXI_NV_S6_BY_M2
               ,`AXI_NV_S7_BY_M2
               ,`AXI_NV_S8_BY_M2
               ,`AXI_NV_S9_BY_M2
               ,`AXI_NV_S10_BY_M2
               ,`AXI_NV_S11_BY_M2
               ,`AXI_NV_S12_BY_M2
               ,`AXI_NV_S13_BY_M2
               ,`AXI_NV_S14_BY_M2
               ,`AXI_NV_S15_BY_M2
               ,`AXI_NV_S16_BY_M2
               , 1
               ,`AXI_BV_S1_BY_M2
               ,`AXI_BV_S2_BY_M2
               ,`AXI_BV_S3_BY_M2
               ,`AXI_BV_S4_BY_M2
               ,`AXI_BV_S5_BY_M2
               ,`AXI_BV_S6_BY_M2
               ,`AXI_BV_S7_BY_M2
               ,`AXI_BV_S8_BY_M2
               ,`AXI_BV_S9_BY_M2
               ,`AXI_BV_S10_BY_M2
               ,`AXI_BV_S11_BY_M2
               ,`AXI_BV_S12_BY_M2
               ,`AXI_BV_S13_BY_M2
               ,`AXI_BV_S14_BY_M2
               ,`AXI_BV_S15_BY_M2
               ,`AXI_BV_S16_BY_M2
             )
             U_ardcdr_m2(
                  .addr_i  (araddr_m2),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m2)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M2, `AXI_LOG2_NSP1V_M2, 1
               ,`AXI_NV_S1_BY_M2
               ,`AXI_NV_S2_BY_M2
               ,`AXI_NV_S3_BY_M2
               ,`AXI_NV_S4_BY_M2
               ,`AXI_NV_S5_BY_M2
               ,`AXI_NV_S6_BY_M2
               ,`AXI_NV_S7_BY_M2
               ,`AXI_NV_S8_BY_M2
               ,`AXI_NV_S9_BY_M2
               ,`AXI_NV_S10_BY_M2
               ,`AXI_NV_S11_BY_M2
               ,`AXI_NV_S12_BY_M2
               ,`AXI_NV_S13_BY_M2
               ,`AXI_NV_S14_BY_M2
               ,`AXI_NV_S15_BY_M2
               ,`AXI_NV_S16_BY_M2
               , 1
               ,`AXI_BV_S1_BY_M2
               ,`AXI_BV_S2_BY_M2
               ,`AXI_BV_S3_BY_M2
               ,`AXI_BV_S4_BY_M2
               ,`AXI_BV_S5_BY_M2
               ,`AXI_BV_S6_BY_M2
               ,`AXI_BV_S7_BY_M2
               ,`AXI_BV_S8_BY_M2
               ,`AXI_BV_S9_BY_M2
               ,`AXI_BV_S10_BY_M2
               ,`AXI_BV_S11_BY_M2
               ,`AXI_BV_S12_BY_M2
               ,`AXI_BV_S13_BY_M2
               ,`AXI_BV_S14_BY_M2
               ,`AXI_BV_S15_BY_M2
               ,`AXI_BV_S16_BY_M2
             )
       U_awdcdr_m2(
                  .addr_i  (awaddr_m2),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m2)
                 );
`endif
`ifdef AXI_HAS_M3

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M3, `AXI_LOG2_NSP1V_M3, 1
               ,`AXI_NV_S1_BY_M3
               ,`AXI_NV_S2_BY_M3
               ,`AXI_NV_S3_BY_M3
               ,`AXI_NV_S4_BY_M3
               ,`AXI_NV_S5_BY_M3
               ,`AXI_NV_S6_BY_M3
               ,`AXI_NV_S7_BY_M3
               ,`AXI_NV_S8_BY_M3
               ,`AXI_NV_S9_BY_M3
               ,`AXI_NV_S10_BY_M3
               ,`AXI_NV_S11_BY_M3
               ,`AXI_NV_S12_BY_M3
               ,`AXI_NV_S13_BY_M3
               ,`AXI_NV_S14_BY_M3
               ,`AXI_NV_S15_BY_M3
               ,`AXI_NV_S16_BY_M3
               , 1
               ,`AXI_BV_S1_BY_M3
               ,`AXI_BV_S2_BY_M3
               ,`AXI_BV_S3_BY_M3
               ,`AXI_BV_S4_BY_M3
               ,`AXI_BV_S5_BY_M3
               ,`AXI_BV_S6_BY_M3
               ,`AXI_BV_S7_BY_M3
               ,`AXI_BV_S8_BY_M3
               ,`AXI_BV_S9_BY_M3
               ,`AXI_BV_S10_BY_M3
               ,`AXI_BV_S11_BY_M3
               ,`AXI_BV_S12_BY_M3
               ,`AXI_BV_S13_BY_M3
               ,`AXI_BV_S14_BY_M3
               ,`AXI_BV_S15_BY_M3
               ,`AXI_BV_S16_BY_M3
             )
             U_ardcdr_m3(
                  .addr_i  (araddr_m3),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m3)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M3, `AXI_LOG2_NSP1V_M3, 1
               ,`AXI_NV_S1_BY_M3
               ,`AXI_NV_S2_BY_M3
               ,`AXI_NV_S3_BY_M3
               ,`AXI_NV_S4_BY_M3
               ,`AXI_NV_S5_BY_M3
               ,`AXI_NV_S6_BY_M3
               ,`AXI_NV_S7_BY_M3
               ,`AXI_NV_S8_BY_M3
               ,`AXI_NV_S9_BY_M3
               ,`AXI_NV_S10_BY_M3
               ,`AXI_NV_S11_BY_M3
               ,`AXI_NV_S12_BY_M3
               ,`AXI_NV_S13_BY_M3
               ,`AXI_NV_S14_BY_M3
               ,`AXI_NV_S15_BY_M3
               ,`AXI_NV_S16_BY_M3
               , 1
               ,`AXI_BV_S1_BY_M3
               ,`AXI_BV_S2_BY_M3
               ,`AXI_BV_S3_BY_M3
               ,`AXI_BV_S4_BY_M3
               ,`AXI_BV_S5_BY_M3
               ,`AXI_BV_S6_BY_M3
               ,`AXI_BV_S7_BY_M3
               ,`AXI_BV_S8_BY_M3
               ,`AXI_BV_S9_BY_M3
               ,`AXI_BV_S10_BY_M3
               ,`AXI_BV_S11_BY_M3
               ,`AXI_BV_S12_BY_M3
               ,`AXI_BV_S13_BY_M3
               ,`AXI_BV_S14_BY_M3
               ,`AXI_BV_S15_BY_M3
               ,`AXI_BV_S16_BY_M3
             )
       U_awdcdr_m3(
                  .addr_i  (awaddr_m3),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m3)
                 );
`endif
`ifdef AXI_HAS_M4

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M4, `AXI_LOG2_NSP1V_M4, 1
               ,`AXI_NV_S1_BY_M4
               ,`AXI_NV_S2_BY_M4
               ,`AXI_NV_S3_BY_M4
               ,`AXI_NV_S4_BY_M4
               ,`AXI_NV_S5_BY_M4
               ,`AXI_NV_S6_BY_M4
               ,`AXI_NV_S7_BY_M4
               ,`AXI_NV_S8_BY_M4
               ,`AXI_NV_S9_BY_M4
               ,`AXI_NV_S10_BY_M4
               ,`AXI_NV_S11_BY_M4
               ,`AXI_NV_S12_BY_M4
               ,`AXI_NV_S13_BY_M4
               ,`AXI_NV_S14_BY_M4
               ,`AXI_NV_S15_BY_M4
               ,`AXI_NV_S16_BY_M4
               , 1
               ,`AXI_BV_S1_BY_M4
               ,`AXI_BV_S2_BY_M4
               ,`AXI_BV_S3_BY_M4
               ,`AXI_BV_S4_BY_M4
               ,`AXI_BV_S5_BY_M4
               ,`AXI_BV_S6_BY_M4
               ,`AXI_BV_S7_BY_M4
               ,`AXI_BV_S8_BY_M4
               ,`AXI_BV_S9_BY_M4
               ,`AXI_BV_S10_BY_M4
               ,`AXI_BV_S11_BY_M4
               ,`AXI_BV_S12_BY_M4
               ,`AXI_BV_S13_BY_M4
               ,`AXI_BV_S14_BY_M4
               ,`AXI_BV_S15_BY_M4
               ,`AXI_BV_S16_BY_M4
             )
             U_ardcdr_m4(
                  .addr_i  (araddr_m4),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m4)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M4, `AXI_LOG2_NSP1V_M4, 1
               ,`AXI_NV_S1_BY_M4
               ,`AXI_NV_S2_BY_M4
               ,`AXI_NV_S3_BY_M4
               ,`AXI_NV_S4_BY_M4
               ,`AXI_NV_S5_BY_M4
               ,`AXI_NV_S6_BY_M4
               ,`AXI_NV_S7_BY_M4
               ,`AXI_NV_S8_BY_M4
               ,`AXI_NV_S9_BY_M4
               ,`AXI_NV_S10_BY_M4
               ,`AXI_NV_S11_BY_M4
               ,`AXI_NV_S12_BY_M4
               ,`AXI_NV_S13_BY_M4
               ,`AXI_NV_S14_BY_M4
               ,`AXI_NV_S15_BY_M4
               ,`AXI_NV_S16_BY_M4
               , 1
               ,`AXI_BV_S1_BY_M4
               ,`AXI_BV_S2_BY_M4
               ,`AXI_BV_S3_BY_M4
               ,`AXI_BV_S4_BY_M4
               ,`AXI_BV_S5_BY_M4
               ,`AXI_BV_S6_BY_M4
               ,`AXI_BV_S7_BY_M4
               ,`AXI_BV_S8_BY_M4
               ,`AXI_BV_S9_BY_M4
               ,`AXI_BV_S10_BY_M4
               ,`AXI_BV_S11_BY_M4
               ,`AXI_BV_S12_BY_M4
               ,`AXI_BV_S13_BY_M4
               ,`AXI_BV_S14_BY_M4
               ,`AXI_BV_S15_BY_M4
               ,`AXI_BV_S16_BY_M4
             )
       U_awdcdr_m4(
                  .addr_i  (awaddr_m4),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m4)
                 );
`endif
`ifdef AXI_HAS_M5

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M5, `AXI_LOG2_NSP1V_M5, 1
               ,`AXI_NV_S1_BY_M5
               ,`AXI_NV_S2_BY_M5
               ,`AXI_NV_S3_BY_M5
               ,`AXI_NV_S4_BY_M5
               ,`AXI_NV_S5_BY_M5
               ,`AXI_NV_S6_BY_M5
               ,`AXI_NV_S7_BY_M5
               ,`AXI_NV_S8_BY_M5
               ,`AXI_NV_S9_BY_M5
               ,`AXI_NV_S10_BY_M5
               ,`AXI_NV_S11_BY_M5
               ,`AXI_NV_S12_BY_M5
               ,`AXI_NV_S13_BY_M5
               ,`AXI_NV_S14_BY_M5
               ,`AXI_NV_S15_BY_M5
               ,`AXI_NV_S16_BY_M5
               , 1
               ,`AXI_BV_S1_BY_M5
               ,`AXI_BV_S2_BY_M5
               ,`AXI_BV_S3_BY_M5
               ,`AXI_BV_S4_BY_M5
               ,`AXI_BV_S5_BY_M5
               ,`AXI_BV_S6_BY_M5
               ,`AXI_BV_S7_BY_M5
               ,`AXI_BV_S8_BY_M5
               ,`AXI_BV_S9_BY_M5
               ,`AXI_BV_S10_BY_M5
               ,`AXI_BV_S11_BY_M5
               ,`AXI_BV_S12_BY_M5
               ,`AXI_BV_S13_BY_M5
               ,`AXI_BV_S14_BY_M5
               ,`AXI_BV_S15_BY_M5
               ,`AXI_BV_S16_BY_M5
             )
             U_ardcdr_m5(
                  .addr_i  (araddr_m5),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m5)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M5, `AXI_LOG2_NSP1V_M5, 1
               ,`AXI_NV_S1_BY_M5
               ,`AXI_NV_S2_BY_M5
               ,`AXI_NV_S3_BY_M5
               ,`AXI_NV_S4_BY_M5
               ,`AXI_NV_S5_BY_M5
               ,`AXI_NV_S6_BY_M5
               ,`AXI_NV_S7_BY_M5
               ,`AXI_NV_S8_BY_M5
               ,`AXI_NV_S9_BY_M5
               ,`AXI_NV_S10_BY_M5
               ,`AXI_NV_S11_BY_M5
               ,`AXI_NV_S12_BY_M5
               ,`AXI_NV_S13_BY_M5
               ,`AXI_NV_S14_BY_M5
               ,`AXI_NV_S15_BY_M5
               ,`AXI_NV_S16_BY_M5
               , 1
               ,`AXI_BV_S1_BY_M5
               ,`AXI_BV_S2_BY_M5
               ,`AXI_BV_S3_BY_M5
               ,`AXI_BV_S4_BY_M5
               ,`AXI_BV_S5_BY_M5
               ,`AXI_BV_S6_BY_M5
               ,`AXI_BV_S7_BY_M5
               ,`AXI_BV_S8_BY_M5
               ,`AXI_BV_S9_BY_M5
               ,`AXI_BV_S10_BY_M5
               ,`AXI_BV_S11_BY_M5
               ,`AXI_BV_S12_BY_M5
               ,`AXI_BV_S13_BY_M5
               ,`AXI_BV_S14_BY_M5
               ,`AXI_BV_S15_BY_M5
               ,`AXI_BV_S16_BY_M5
             )
       U_awdcdr_m5(
                  .addr_i  (awaddr_m5),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m5)
                 );
`endif
`ifdef AXI_HAS_M6

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M6, `AXI_LOG2_NSP1V_M6, 1
               ,`AXI_NV_S1_BY_M6
               ,`AXI_NV_S2_BY_M6
               ,`AXI_NV_S3_BY_M6
               ,`AXI_NV_S4_BY_M6
               ,`AXI_NV_S5_BY_M6
               ,`AXI_NV_S6_BY_M6
               ,`AXI_NV_S7_BY_M6
               ,`AXI_NV_S8_BY_M6
               ,`AXI_NV_S9_BY_M6
               ,`AXI_NV_S10_BY_M6
               ,`AXI_NV_S11_BY_M6
               ,`AXI_NV_S12_BY_M6
               ,`AXI_NV_S13_BY_M6
               ,`AXI_NV_S14_BY_M6
               ,`AXI_NV_S15_BY_M6
               ,`AXI_NV_S16_BY_M6
               , 1
               ,`AXI_BV_S1_BY_M6
               ,`AXI_BV_S2_BY_M6
               ,`AXI_BV_S3_BY_M6
               ,`AXI_BV_S4_BY_M6
               ,`AXI_BV_S5_BY_M6
               ,`AXI_BV_S6_BY_M6
               ,`AXI_BV_S7_BY_M6
               ,`AXI_BV_S8_BY_M6
               ,`AXI_BV_S9_BY_M6
               ,`AXI_BV_S10_BY_M6
               ,`AXI_BV_S11_BY_M6
               ,`AXI_BV_S12_BY_M6
               ,`AXI_BV_S13_BY_M6
               ,`AXI_BV_S14_BY_M6
               ,`AXI_BV_S15_BY_M6
               ,`AXI_BV_S16_BY_M6
             )
             U_ardcdr_m6(
                  .addr_i  (araddr_m6),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m6)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M6, `AXI_LOG2_NSP1V_M6, 1
               ,`AXI_NV_S1_BY_M6
               ,`AXI_NV_S2_BY_M6
               ,`AXI_NV_S3_BY_M6
               ,`AXI_NV_S4_BY_M6
               ,`AXI_NV_S5_BY_M6
               ,`AXI_NV_S6_BY_M6
               ,`AXI_NV_S7_BY_M6
               ,`AXI_NV_S8_BY_M6
               ,`AXI_NV_S9_BY_M6
               ,`AXI_NV_S10_BY_M6
               ,`AXI_NV_S11_BY_M6
               ,`AXI_NV_S12_BY_M6
               ,`AXI_NV_S13_BY_M6
               ,`AXI_NV_S14_BY_M6
               ,`AXI_NV_S15_BY_M6
               ,`AXI_NV_S16_BY_M6
               , 1
               ,`AXI_BV_S1_BY_M6
               ,`AXI_BV_S2_BY_M6
               ,`AXI_BV_S3_BY_M6
               ,`AXI_BV_S4_BY_M6
               ,`AXI_BV_S5_BY_M6
               ,`AXI_BV_S6_BY_M6
               ,`AXI_BV_S7_BY_M6
               ,`AXI_BV_S8_BY_M6
               ,`AXI_BV_S9_BY_M6
               ,`AXI_BV_S10_BY_M6
               ,`AXI_BV_S11_BY_M6
               ,`AXI_BV_S12_BY_M6
               ,`AXI_BV_S13_BY_M6
               ,`AXI_BV_S14_BY_M6
               ,`AXI_BV_S15_BY_M6
               ,`AXI_BV_S16_BY_M6
             )
       U_awdcdr_m6(
                  .addr_i  (awaddr_m6),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m6)
                 );
`endif
`ifdef AXI_HAS_M7

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M7, `AXI_LOG2_NSP1V_M7, 1
               ,`AXI_NV_S1_BY_M7
               ,`AXI_NV_S2_BY_M7
               ,`AXI_NV_S3_BY_M7
               ,`AXI_NV_S4_BY_M7
               ,`AXI_NV_S5_BY_M7
               ,`AXI_NV_S6_BY_M7
               ,`AXI_NV_S7_BY_M7
               ,`AXI_NV_S8_BY_M7
               ,`AXI_NV_S9_BY_M7
               ,`AXI_NV_S10_BY_M7
               ,`AXI_NV_S11_BY_M7
               ,`AXI_NV_S12_BY_M7
               ,`AXI_NV_S13_BY_M7
               ,`AXI_NV_S14_BY_M7
               ,`AXI_NV_S15_BY_M7
               ,`AXI_NV_S16_BY_M7
               , 1
               ,`AXI_BV_S1_BY_M7
               ,`AXI_BV_S2_BY_M7
               ,`AXI_BV_S3_BY_M7
               ,`AXI_BV_S4_BY_M7
               ,`AXI_BV_S5_BY_M7
               ,`AXI_BV_S6_BY_M7
               ,`AXI_BV_S7_BY_M7
               ,`AXI_BV_S8_BY_M7
               ,`AXI_BV_S9_BY_M7
               ,`AXI_BV_S10_BY_M7
               ,`AXI_BV_S11_BY_M7
               ,`AXI_BV_S12_BY_M7
               ,`AXI_BV_S13_BY_M7
               ,`AXI_BV_S14_BY_M7
               ,`AXI_BV_S15_BY_M7
               ,`AXI_BV_S16_BY_M7
             )
             U_ardcdr_m7(
                  .addr_i  (araddr_m7),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m7)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M7, `AXI_LOG2_NSP1V_M7, 1
               ,`AXI_NV_S1_BY_M7
               ,`AXI_NV_S2_BY_M7
               ,`AXI_NV_S3_BY_M7
               ,`AXI_NV_S4_BY_M7
               ,`AXI_NV_S5_BY_M7
               ,`AXI_NV_S6_BY_M7
               ,`AXI_NV_S7_BY_M7
               ,`AXI_NV_S8_BY_M7
               ,`AXI_NV_S9_BY_M7
               ,`AXI_NV_S10_BY_M7
               ,`AXI_NV_S11_BY_M7
               ,`AXI_NV_S12_BY_M7
               ,`AXI_NV_S13_BY_M7
               ,`AXI_NV_S14_BY_M7
               ,`AXI_NV_S15_BY_M7
               ,`AXI_NV_S16_BY_M7
               , 1
               ,`AXI_BV_S1_BY_M7
               ,`AXI_BV_S2_BY_M7
               ,`AXI_BV_S3_BY_M7
               ,`AXI_BV_S4_BY_M7
               ,`AXI_BV_S5_BY_M7
               ,`AXI_BV_S6_BY_M7
               ,`AXI_BV_S7_BY_M7
               ,`AXI_BV_S8_BY_M7
               ,`AXI_BV_S9_BY_M7
               ,`AXI_BV_S10_BY_M7
               ,`AXI_BV_S11_BY_M7
               ,`AXI_BV_S12_BY_M7
               ,`AXI_BV_S13_BY_M7
               ,`AXI_BV_S14_BY_M7
               ,`AXI_BV_S15_BY_M7
               ,`AXI_BV_S16_BY_M7
             )
       U_awdcdr_m7(
                  .addr_i  (awaddr_m7),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m7)
                 );
`endif
`ifdef AXI_HAS_M8

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M8, `AXI_LOG2_NSP1V_M8, 1
               ,`AXI_NV_S1_BY_M8
               ,`AXI_NV_S2_BY_M8
               ,`AXI_NV_S3_BY_M8
               ,`AXI_NV_S4_BY_M8
               ,`AXI_NV_S5_BY_M8
               ,`AXI_NV_S6_BY_M8
               ,`AXI_NV_S7_BY_M8
               ,`AXI_NV_S8_BY_M8
               ,`AXI_NV_S9_BY_M8
               ,`AXI_NV_S10_BY_M8
               ,`AXI_NV_S11_BY_M8
               ,`AXI_NV_S12_BY_M8
               ,`AXI_NV_S13_BY_M8
               ,`AXI_NV_S14_BY_M8
               ,`AXI_NV_S15_BY_M8
               ,`AXI_NV_S16_BY_M8
               , 1
               ,`AXI_BV_S1_BY_M8
               ,`AXI_BV_S2_BY_M8
               ,`AXI_BV_S3_BY_M8
               ,`AXI_BV_S4_BY_M8
               ,`AXI_BV_S5_BY_M8
               ,`AXI_BV_S6_BY_M8
               ,`AXI_BV_S7_BY_M8
               ,`AXI_BV_S8_BY_M8
               ,`AXI_BV_S9_BY_M8
               ,`AXI_BV_S10_BY_M8
               ,`AXI_BV_S11_BY_M8
               ,`AXI_BV_S12_BY_M8
               ,`AXI_BV_S13_BY_M8
               ,`AXI_BV_S14_BY_M8
               ,`AXI_BV_S15_BY_M8
               ,`AXI_BV_S16_BY_M8
             )
             U_ardcdr_m8(
                  .addr_i  (araddr_m8),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m8)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M8, `AXI_LOG2_NSP1V_M8, 1
               ,`AXI_NV_S1_BY_M8
               ,`AXI_NV_S2_BY_M8
               ,`AXI_NV_S3_BY_M8
               ,`AXI_NV_S4_BY_M8
               ,`AXI_NV_S5_BY_M8
               ,`AXI_NV_S6_BY_M8
               ,`AXI_NV_S7_BY_M8
               ,`AXI_NV_S8_BY_M8
               ,`AXI_NV_S9_BY_M8
               ,`AXI_NV_S10_BY_M8
               ,`AXI_NV_S11_BY_M8
               ,`AXI_NV_S12_BY_M8
               ,`AXI_NV_S13_BY_M8
               ,`AXI_NV_S14_BY_M8
               ,`AXI_NV_S15_BY_M8
               ,`AXI_NV_S16_BY_M8
               , 1
               ,`AXI_BV_S1_BY_M8
               ,`AXI_BV_S2_BY_M8
               ,`AXI_BV_S3_BY_M8
               ,`AXI_BV_S4_BY_M8
               ,`AXI_BV_S5_BY_M8
               ,`AXI_BV_S6_BY_M8
               ,`AXI_BV_S7_BY_M8
               ,`AXI_BV_S8_BY_M8
               ,`AXI_BV_S9_BY_M8
               ,`AXI_BV_S10_BY_M8
               ,`AXI_BV_S11_BY_M8
               ,`AXI_BV_S12_BY_M8
               ,`AXI_BV_S13_BY_M8
               ,`AXI_BV_S14_BY_M8
               ,`AXI_BV_S15_BY_M8
               ,`AXI_BV_S16_BY_M8
             )
       U_awdcdr_m8(
                  .addr_i  (awaddr_m8),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m8)
                 );
`endif
`ifdef AXI_HAS_M9

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M9, `AXI_LOG2_NSP1V_M9, 1
               ,`AXI_NV_S1_BY_M9
               ,`AXI_NV_S2_BY_M9
               ,`AXI_NV_S3_BY_M9
               ,`AXI_NV_S4_BY_M9
               ,`AXI_NV_S5_BY_M9
               ,`AXI_NV_S6_BY_M9
               ,`AXI_NV_S7_BY_M9
               ,`AXI_NV_S8_BY_M9
               ,`AXI_NV_S9_BY_M9
               ,`AXI_NV_S10_BY_M9
               ,`AXI_NV_S11_BY_M9
               ,`AXI_NV_S12_BY_M9
               ,`AXI_NV_S13_BY_M9
               ,`AXI_NV_S14_BY_M9
               ,`AXI_NV_S15_BY_M9
               ,`AXI_NV_S16_BY_M9
               , 1
               ,`AXI_BV_S1_BY_M9
               ,`AXI_BV_S2_BY_M9
               ,`AXI_BV_S3_BY_M9
               ,`AXI_BV_S4_BY_M9
               ,`AXI_BV_S5_BY_M9
               ,`AXI_BV_S6_BY_M9
               ,`AXI_BV_S7_BY_M9
               ,`AXI_BV_S8_BY_M9
               ,`AXI_BV_S9_BY_M9
               ,`AXI_BV_S10_BY_M9
               ,`AXI_BV_S11_BY_M9
               ,`AXI_BV_S12_BY_M9
               ,`AXI_BV_S13_BY_M9
               ,`AXI_BV_S14_BY_M9
               ,`AXI_BV_S15_BY_M9
               ,`AXI_BV_S16_BY_M9
             )
             U_ardcdr_m9(
                  .addr_i  (araddr_m9),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m9)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M9, `AXI_LOG2_NSP1V_M9, 1
               ,`AXI_NV_S1_BY_M9
               ,`AXI_NV_S2_BY_M9
               ,`AXI_NV_S3_BY_M9
               ,`AXI_NV_S4_BY_M9
               ,`AXI_NV_S5_BY_M9
               ,`AXI_NV_S6_BY_M9
               ,`AXI_NV_S7_BY_M9
               ,`AXI_NV_S8_BY_M9
               ,`AXI_NV_S9_BY_M9
               ,`AXI_NV_S10_BY_M9
               ,`AXI_NV_S11_BY_M9
               ,`AXI_NV_S12_BY_M9
               ,`AXI_NV_S13_BY_M9
               ,`AXI_NV_S14_BY_M9
               ,`AXI_NV_S15_BY_M9
               ,`AXI_NV_S16_BY_M9
               , 1
               ,`AXI_BV_S1_BY_M9
               ,`AXI_BV_S2_BY_M9
               ,`AXI_BV_S3_BY_M9
               ,`AXI_BV_S4_BY_M9
               ,`AXI_BV_S5_BY_M9
               ,`AXI_BV_S6_BY_M9
               ,`AXI_BV_S7_BY_M9
               ,`AXI_BV_S8_BY_M9
               ,`AXI_BV_S9_BY_M9
               ,`AXI_BV_S10_BY_M9
               ,`AXI_BV_S11_BY_M9
               ,`AXI_BV_S12_BY_M9
               ,`AXI_BV_S13_BY_M9
               ,`AXI_BV_S14_BY_M9
               ,`AXI_BV_S15_BY_M9
               ,`AXI_BV_S16_BY_M9
             )
       U_awdcdr_m9(
                  .addr_i  (awaddr_m9),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m9)
                 );
`endif
`ifdef AXI_HAS_M10

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M10, `AXI_LOG2_NSP1V_M10, 1
               ,`AXI_NV_S1_BY_M10
               ,`AXI_NV_S2_BY_M10
               ,`AXI_NV_S3_BY_M10
               ,`AXI_NV_S4_BY_M10
               ,`AXI_NV_S5_BY_M10
               ,`AXI_NV_S6_BY_M10
               ,`AXI_NV_S7_BY_M10
               ,`AXI_NV_S8_BY_M10
               ,`AXI_NV_S9_BY_M10
               ,`AXI_NV_S10_BY_M10
               ,`AXI_NV_S11_BY_M10
               ,`AXI_NV_S12_BY_M10
               ,`AXI_NV_S13_BY_M10
               ,`AXI_NV_S14_BY_M10
               ,`AXI_NV_S15_BY_M10
               ,`AXI_NV_S16_BY_M10
               , 1
               ,`AXI_BV_S1_BY_M10
               ,`AXI_BV_S2_BY_M10
               ,`AXI_BV_S3_BY_M10
               ,`AXI_BV_S4_BY_M10
               ,`AXI_BV_S5_BY_M10
               ,`AXI_BV_S6_BY_M10
               ,`AXI_BV_S7_BY_M10
               ,`AXI_BV_S8_BY_M10
               ,`AXI_BV_S9_BY_M10
               ,`AXI_BV_S10_BY_M10
               ,`AXI_BV_S11_BY_M10
               ,`AXI_BV_S12_BY_M10
               ,`AXI_BV_S13_BY_M10
               ,`AXI_BV_S14_BY_M10
               ,`AXI_BV_S15_BY_M10
               ,`AXI_BV_S16_BY_M10
             )
             U_ardcdr_m10(
                  .addr_i  (araddr_m10),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m10)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M10, `AXI_LOG2_NSP1V_M10, 1
               ,`AXI_NV_S1_BY_M10
               ,`AXI_NV_S2_BY_M10
               ,`AXI_NV_S3_BY_M10
               ,`AXI_NV_S4_BY_M10
               ,`AXI_NV_S5_BY_M10
               ,`AXI_NV_S6_BY_M10
               ,`AXI_NV_S7_BY_M10
               ,`AXI_NV_S8_BY_M10
               ,`AXI_NV_S9_BY_M10
               ,`AXI_NV_S10_BY_M10
               ,`AXI_NV_S11_BY_M10
               ,`AXI_NV_S12_BY_M10
               ,`AXI_NV_S13_BY_M10
               ,`AXI_NV_S14_BY_M10
               ,`AXI_NV_S15_BY_M10
               ,`AXI_NV_S16_BY_M10
               , 1
               ,`AXI_BV_S1_BY_M10
               ,`AXI_BV_S2_BY_M10
               ,`AXI_BV_S3_BY_M10
               ,`AXI_BV_S4_BY_M10
               ,`AXI_BV_S5_BY_M10
               ,`AXI_BV_S6_BY_M10
               ,`AXI_BV_S7_BY_M10
               ,`AXI_BV_S8_BY_M10
               ,`AXI_BV_S9_BY_M10
               ,`AXI_BV_S10_BY_M10
               ,`AXI_BV_S11_BY_M10
               ,`AXI_BV_S12_BY_M10
               ,`AXI_BV_S13_BY_M10
               ,`AXI_BV_S14_BY_M10
               ,`AXI_BV_S15_BY_M10
               ,`AXI_BV_S16_BY_M10
             )
       U_awdcdr_m10(
                  .addr_i  (awaddr_m10),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m10)
                 );
`endif
`ifdef AXI_HAS_M11

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M11, `AXI_LOG2_NSP1V_M11, 1
               ,`AXI_NV_S1_BY_M11
               ,`AXI_NV_S2_BY_M11
               ,`AXI_NV_S3_BY_M11
               ,`AXI_NV_S4_BY_M11
               ,`AXI_NV_S5_BY_M11
               ,`AXI_NV_S6_BY_M11
               ,`AXI_NV_S7_BY_M11
               ,`AXI_NV_S8_BY_M11
               ,`AXI_NV_S9_BY_M11
               ,`AXI_NV_S10_BY_M11
               ,`AXI_NV_S11_BY_M11
               ,`AXI_NV_S12_BY_M11
               ,`AXI_NV_S13_BY_M11
               ,`AXI_NV_S14_BY_M11
               ,`AXI_NV_S15_BY_M11
               ,`AXI_NV_S16_BY_M11
               , 1
               ,`AXI_BV_S1_BY_M11
               ,`AXI_BV_S2_BY_M11
               ,`AXI_BV_S3_BY_M11
               ,`AXI_BV_S4_BY_M11
               ,`AXI_BV_S5_BY_M11
               ,`AXI_BV_S6_BY_M11
               ,`AXI_BV_S7_BY_M11
               ,`AXI_BV_S8_BY_M11
               ,`AXI_BV_S9_BY_M11
               ,`AXI_BV_S10_BY_M11
               ,`AXI_BV_S11_BY_M11
               ,`AXI_BV_S12_BY_M11
               ,`AXI_BV_S13_BY_M11
               ,`AXI_BV_S14_BY_M11
               ,`AXI_BV_S15_BY_M11
               ,`AXI_BV_S16_BY_M11
             )
             U_ardcdr_m11(
                  .addr_i  (araddr_m11),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m11)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M11, `AXI_LOG2_NSP1V_M11, 1
               ,`AXI_NV_S1_BY_M11
               ,`AXI_NV_S2_BY_M11
               ,`AXI_NV_S3_BY_M11
               ,`AXI_NV_S4_BY_M11
               ,`AXI_NV_S5_BY_M11
               ,`AXI_NV_S6_BY_M11
               ,`AXI_NV_S7_BY_M11
               ,`AXI_NV_S8_BY_M11
               ,`AXI_NV_S9_BY_M11
               ,`AXI_NV_S10_BY_M11
               ,`AXI_NV_S11_BY_M11
               ,`AXI_NV_S12_BY_M11
               ,`AXI_NV_S13_BY_M11
               ,`AXI_NV_S14_BY_M11
               ,`AXI_NV_S15_BY_M11
               ,`AXI_NV_S16_BY_M11
               , 1
               ,`AXI_BV_S1_BY_M11
               ,`AXI_BV_S2_BY_M11
               ,`AXI_BV_S3_BY_M11
               ,`AXI_BV_S4_BY_M11
               ,`AXI_BV_S5_BY_M11
               ,`AXI_BV_S6_BY_M11
               ,`AXI_BV_S7_BY_M11
               ,`AXI_BV_S8_BY_M11
               ,`AXI_BV_S9_BY_M11
               ,`AXI_BV_S10_BY_M11
               ,`AXI_BV_S11_BY_M11
               ,`AXI_BV_S12_BY_M11
               ,`AXI_BV_S13_BY_M11
               ,`AXI_BV_S14_BY_M11
               ,`AXI_BV_S15_BY_M11
               ,`AXI_BV_S16_BY_M11
             )
       U_awdcdr_m11(
                  .addr_i  (awaddr_m11),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m11)
                 );
`endif
`ifdef AXI_HAS_M12

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M12, `AXI_LOG2_NSP1V_M12, 1
               ,`AXI_NV_S1_BY_M12
               ,`AXI_NV_S2_BY_M12
               ,`AXI_NV_S3_BY_M12
               ,`AXI_NV_S4_BY_M12
               ,`AXI_NV_S5_BY_M12
               ,`AXI_NV_S6_BY_M12
               ,`AXI_NV_S7_BY_M12
               ,`AXI_NV_S8_BY_M12
               ,`AXI_NV_S9_BY_M12
               ,`AXI_NV_S10_BY_M12
               ,`AXI_NV_S11_BY_M12
               ,`AXI_NV_S12_BY_M12
               ,`AXI_NV_S13_BY_M12
               ,`AXI_NV_S14_BY_M12
               ,`AXI_NV_S15_BY_M12
               ,`AXI_NV_S16_BY_M12
               , 1
               ,`AXI_BV_S1_BY_M12
               ,`AXI_BV_S2_BY_M12
               ,`AXI_BV_S3_BY_M12
               ,`AXI_BV_S4_BY_M12
               ,`AXI_BV_S5_BY_M12
               ,`AXI_BV_S6_BY_M12
               ,`AXI_BV_S7_BY_M12
               ,`AXI_BV_S8_BY_M12
               ,`AXI_BV_S9_BY_M12
               ,`AXI_BV_S10_BY_M12
               ,`AXI_BV_S11_BY_M12
               ,`AXI_BV_S12_BY_M12
               ,`AXI_BV_S13_BY_M12
               ,`AXI_BV_S14_BY_M12
               ,`AXI_BV_S15_BY_M12
               ,`AXI_BV_S16_BY_M12
             )
             U_ardcdr_m12(
                  .addr_i  (araddr_m12),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m12)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M12, `AXI_LOG2_NSP1V_M12, 1
               ,`AXI_NV_S1_BY_M12
               ,`AXI_NV_S2_BY_M12
               ,`AXI_NV_S3_BY_M12
               ,`AXI_NV_S4_BY_M12
               ,`AXI_NV_S5_BY_M12
               ,`AXI_NV_S6_BY_M12
               ,`AXI_NV_S7_BY_M12
               ,`AXI_NV_S8_BY_M12
               ,`AXI_NV_S9_BY_M12
               ,`AXI_NV_S10_BY_M12
               ,`AXI_NV_S11_BY_M12
               ,`AXI_NV_S12_BY_M12
               ,`AXI_NV_S13_BY_M12
               ,`AXI_NV_S14_BY_M12
               ,`AXI_NV_S15_BY_M12
               ,`AXI_NV_S16_BY_M12
               , 1
               ,`AXI_BV_S1_BY_M12
               ,`AXI_BV_S2_BY_M12
               ,`AXI_BV_S3_BY_M12
               ,`AXI_BV_S4_BY_M12
               ,`AXI_BV_S5_BY_M12
               ,`AXI_BV_S6_BY_M12
               ,`AXI_BV_S7_BY_M12
               ,`AXI_BV_S8_BY_M12
               ,`AXI_BV_S9_BY_M12
               ,`AXI_BV_S10_BY_M12
               ,`AXI_BV_S11_BY_M12
               ,`AXI_BV_S12_BY_M12
               ,`AXI_BV_S13_BY_M12
               ,`AXI_BV_S14_BY_M12
               ,`AXI_BV_S15_BY_M12
               ,`AXI_BV_S16_BY_M12
             )
       U_awdcdr_m12(
                  .addr_i  (awaddr_m12),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m12)
                 );
`endif
`ifdef AXI_HAS_M13

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M13, `AXI_LOG2_NSP1V_M13, 1
               ,`AXI_NV_S1_BY_M13
               ,`AXI_NV_S2_BY_M13
               ,`AXI_NV_S3_BY_M13
               ,`AXI_NV_S4_BY_M13
               ,`AXI_NV_S5_BY_M13
               ,`AXI_NV_S6_BY_M13
               ,`AXI_NV_S7_BY_M13
               ,`AXI_NV_S8_BY_M13
               ,`AXI_NV_S9_BY_M13
               ,`AXI_NV_S10_BY_M13
               ,`AXI_NV_S11_BY_M13
               ,`AXI_NV_S12_BY_M13
               ,`AXI_NV_S13_BY_M13
               ,`AXI_NV_S14_BY_M13
               ,`AXI_NV_S15_BY_M13
               ,`AXI_NV_S16_BY_M13
               , 1
               ,`AXI_BV_S1_BY_M13
               ,`AXI_BV_S2_BY_M13
               ,`AXI_BV_S3_BY_M13
               ,`AXI_BV_S4_BY_M13
               ,`AXI_BV_S5_BY_M13
               ,`AXI_BV_S6_BY_M13
               ,`AXI_BV_S7_BY_M13
               ,`AXI_BV_S8_BY_M13
               ,`AXI_BV_S9_BY_M13
               ,`AXI_BV_S10_BY_M13
               ,`AXI_BV_S11_BY_M13
               ,`AXI_BV_S12_BY_M13
               ,`AXI_BV_S13_BY_M13
               ,`AXI_BV_S14_BY_M13
               ,`AXI_BV_S15_BY_M13
               ,`AXI_BV_S16_BY_M13
             )
             U_ardcdr_m13(
                  .addr_i  (araddr_m13),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m13)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M13, `AXI_LOG2_NSP1V_M13, 1
               ,`AXI_NV_S1_BY_M13
               ,`AXI_NV_S2_BY_M13
               ,`AXI_NV_S3_BY_M13
               ,`AXI_NV_S4_BY_M13
               ,`AXI_NV_S5_BY_M13
               ,`AXI_NV_S6_BY_M13
               ,`AXI_NV_S7_BY_M13
               ,`AXI_NV_S8_BY_M13
               ,`AXI_NV_S9_BY_M13
               ,`AXI_NV_S10_BY_M13
               ,`AXI_NV_S11_BY_M13
               ,`AXI_NV_S12_BY_M13
               ,`AXI_NV_S13_BY_M13
               ,`AXI_NV_S14_BY_M13
               ,`AXI_NV_S15_BY_M13
               ,`AXI_NV_S16_BY_M13
               , 1
               ,`AXI_BV_S1_BY_M13
               ,`AXI_BV_S2_BY_M13
               ,`AXI_BV_S3_BY_M13
               ,`AXI_BV_S4_BY_M13
               ,`AXI_BV_S5_BY_M13
               ,`AXI_BV_S6_BY_M13
               ,`AXI_BV_S7_BY_M13
               ,`AXI_BV_S8_BY_M13
               ,`AXI_BV_S9_BY_M13
               ,`AXI_BV_S10_BY_M13
               ,`AXI_BV_S11_BY_M13
               ,`AXI_BV_S12_BY_M13
               ,`AXI_BV_S13_BY_M13
               ,`AXI_BV_S14_BY_M13
               ,`AXI_BV_S15_BY_M13
               ,`AXI_BV_S16_BY_M13
             )
       U_awdcdr_m13(
                  .addr_i  (awaddr_m13),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m13)
                 );
`endif
`ifdef AXI_HAS_M14

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M14, `AXI_LOG2_NSP1V_M14, 1
               ,`AXI_NV_S1_BY_M14
               ,`AXI_NV_S2_BY_M14
               ,`AXI_NV_S3_BY_M14
               ,`AXI_NV_S4_BY_M14
               ,`AXI_NV_S5_BY_M14
               ,`AXI_NV_S6_BY_M14
               ,`AXI_NV_S7_BY_M14
               ,`AXI_NV_S8_BY_M14
               ,`AXI_NV_S9_BY_M14
               ,`AXI_NV_S10_BY_M14
               ,`AXI_NV_S11_BY_M14
               ,`AXI_NV_S12_BY_M14
               ,`AXI_NV_S13_BY_M14
               ,`AXI_NV_S14_BY_M14
               ,`AXI_NV_S15_BY_M14
               ,`AXI_NV_S16_BY_M14
               , 1
               ,`AXI_BV_S1_BY_M14
               ,`AXI_BV_S2_BY_M14
               ,`AXI_BV_S3_BY_M14
               ,`AXI_BV_S4_BY_M14
               ,`AXI_BV_S5_BY_M14
               ,`AXI_BV_S6_BY_M14
               ,`AXI_BV_S7_BY_M14
               ,`AXI_BV_S8_BY_M14
               ,`AXI_BV_S9_BY_M14
               ,`AXI_BV_S10_BY_M14
               ,`AXI_BV_S11_BY_M14
               ,`AXI_BV_S12_BY_M14
               ,`AXI_BV_S13_BY_M14
               ,`AXI_BV_S14_BY_M14
               ,`AXI_BV_S15_BY_M14
               ,`AXI_BV_S16_BY_M14
             )
             U_ardcdr_m14(
                  .addr_i  (araddr_m14),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m14)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M14, `AXI_LOG2_NSP1V_M14, 1
               ,`AXI_NV_S1_BY_M14
               ,`AXI_NV_S2_BY_M14
               ,`AXI_NV_S3_BY_M14
               ,`AXI_NV_S4_BY_M14
               ,`AXI_NV_S5_BY_M14
               ,`AXI_NV_S6_BY_M14
               ,`AXI_NV_S7_BY_M14
               ,`AXI_NV_S8_BY_M14
               ,`AXI_NV_S9_BY_M14
               ,`AXI_NV_S10_BY_M14
               ,`AXI_NV_S11_BY_M14
               ,`AXI_NV_S12_BY_M14
               ,`AXI_NV_S13_BY_M14
               ,`AXI_NV_S14_BY_M14
               ,`AXI_NV_S15_BY_M14
               ,`AXI_NV_S16_BY_M14
               , 1
               ,`AXI_BV_S1_BY_M14
               ,`AXI_BV_S2_BY_M14
               ,`AXI_BV_S3_BY_M14
               ,`AXI_BV_S4_BY_M14
               ,`AXI_BV_S5_BY_M14
               ,`AXI_BV_S6_BY_M14
               ,`AXI_BV_S7_BY_M14
               ,`AXI_BV_S8_BY_M14
               ,`AXI_BV_S9_BY_M14
               ,`AXI_BV_S10_BY_M14
               ,`AXI_BV_S11_BY_M14
               ,`AXI_BV_S12_BY_M14
               ,`AXI_BV_S13_BY_M14
               ,`AXI_BV_S14_BY_M14
               ,`AXI_BV_S15_BY_M14
               ,`AXI_BV_S16_BY_M14
             )
       U_awdcdr_m14(
                  .addr_i  (awaddr_m14),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m14)
                 );
`endif
`ifdef AXI_HAS_M15

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M15, `AXI_LOG2_NSP1V_M15, 1
               ,`AXI_NV_S1_BY_M15
               ,`AXI_NV_S2_BY_M15
               ,`AXI_NV_S3_BY_M15
               ,`AXI_NV_S4_BY_M15
               ,`AXI_NV_S5_BY_M15
               ,`AXI_NV_S6_BY_M15
               ,`AXI_NV_S7_BY_M15
               ,`AXI_NV_S8_BY_M15
               ,`AXI_NV_S9_BY_M15
               ,`AXI_NV_S10_BY_M15
               ,`AXI_NV_S11_BY_M15
               ,`AXI_NV_S12_BY_M15
               ,`AXI_NV_S13_BY_M15
               ,`AXI_NV_S14_BY_M15
               ,`AXI_NV_S15_BY_M15
               ,`AXI_NV_S16_BY_M15
               , 1
               ,`AXI_BV_S1_BY_M15
               ,`AXI_BV_S2_BY_M15
               ,`AXI_BV_S3_BY_M15
               ,`AXI_BV_S4_BY_M15
               ,`AXI_BV_S5_BY_M15
               ,`AXI_BV_S6_BY_M15
               ,`AXI_BV_S7_BY_M15
               ,`AXI_BV_S8_BY_M15
               ,`AXI_BV_S9_BY_M15
               ,`AXI_BV_S10_BY_M15
               ,`AXI_BV_S11_BY_M15
               ,`AXI_BV_S12_BY_M15
               ,`AXI_BV_S13_BY_M15
               ,`AXI_BV_S14_BY_M15
               ,`AXI_BV_S15_BY_M15
               ,`AXI_BV_S16_BY_M15
             )
             U_ardcdr_m15(
                  .addr_i  (araddr_m15),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m15)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M15, `AXI_LOG2_NSP1V_M15, 1
               ,`AXI_NV_S1_BY_M15
               ,`AXI_NV_S2_BY_M15
               ,`AXI_NV_S3_BY_M15
               ,`AXI_NV_S4_BY_M15
               ,`AXI_NV_S5_BY_M15
               ,`AXI_NV_S6_BY_M15
               ,`AXI_NV_S7_BY_M15
               ,`AXI_NV_S8_BY_M15
               ,`AXI_NV_S9_BY_M15
               ,`AXI_NV_S10_BY_M15
               ,`AXI_NV_S11_BY_M15
               ,`AXI_NV_S12_BY_M15
               ,`AXI_NV_S13_BY_M15
               ,`AXI_NV_S14_BY_M15
               ,`AXI_NV_S15_BY_M15
               ,`AXI_NV_S16_BY_M15
               , 1
               ,`AXI_BV_S1_BY_M15
               ,`AXI_BV_S2_BY_M15
               ,`AXI_BV_S3_BY_M15
               ,`AXI_BV_S4_BY_M15
               ,`AXI_BV_S5_BY_M15
               ,`AXI_BV_S6_BY_M15
               ,`AXI_BV_S7_BY_M15
               ,`AXI_BV_S8_BY_M15
               ,`AXI_BV_S9_BY_M15
               ,`AXI_BV_S10_BY_M15
               ,`AXI_BV_S11_BY_M15
               ,`AXI_BV_S12_BY_M15
               ,`AXI_BV_S13_BY_M15
               ,`AXI_BV_S14_BY_M15
               ,`AXI_BV_S15_BY_M15
               ,`AXI_BV_S16_BY_M15
             )
       U_awdcdr_m15(
                  .addr_i  (awaddr_m15),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m15)
                 );
`endif
`ifdef AXI_HAS_M16

// External Read Address Decoders Instantiation

  tb_dcdr
   #(`AXI_NSP1V_M16, `AXI_LOG2_NSP1V_M16, 1
               ,`AXI_NV_S1_BY_M16
               ,`AXI_NV_S2_BY_M16
               ,`AXI_NV_S3_BY_M16
               ,`AXI_NV_S4_BY_M16
               ,`AXI_NV_S5_BY_M16
               ,`AXI_NV_S6_BY_M16
               ,`AXI_NV_S7_BY_M16
               ,`AXI_NV_S8_BY_M16
               ,`AXI_NV_S9_BY_M16
               ,`AXI_NV_S10_BY_M16
               ,`AXI_NV_S11_BY_M16
               ,`AXI_NV_S12_BY_M16
               ,`AXI_NV_S13_BY_M16
               ,`AXI_NV_S14_BY_M16
               ,`AXI_NV_S15_BY_M16
               ,`AXI_NV_S16_BY_M16
               , 1
               ,`AXI_BV_S1_BY_M16
               ,`AXI_BV_S2_BY_M16
               ,`AXI_BV_S3_BY_M16
               ,`AXI_BV_S4_BY_M16
               ,`AXI_BV_S5_BY_M16
               ,`AXI_BV_S6_BY_M16
               ,`AXI_BV_S7_BY_M16
               ,`AXI_BV_S8_BY_M16
               ,`AXI_BV_S9_BY_M16
               ,`AXI_BV_S10_BY_M16
               ,`AXI_BV_S11_BY_M16
               ,`AXI_BV_S12_BY_M16
               ,`AXI_BV_S13_BY_M16
               ,`AXI_BV_S14_BY_M16
               ,`AXI_BV_S15_BY_M16
               ,`AXI_BV_S16_BY_M16
             )
             U_ardcdr_m16(
                  .addr_i  (araddr_m16),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_rd_m16)
                 );

// External Write Address Decoders Instantiation

tb_dcdr
  #(`AXI_NSP1V_M16, `AXI_LOG2_NSP1V_M16, 1
               ,`AXI_NV_S1_BY_M16
               ,`AXI_NV_S2_BY_M16
               ,`AXI_NV_S3_BY_M16
               ,`AXI_NV_S4_BY_M16
               ,`AXI_NV_S5_BY_M16
               ,`AXI_NV_S6_BY_M16
               ,`AXI_NV_S7_BY_M16
               ,`AXI_NV_S8_BY_M16
               ,`AXI_NV_S9_BY_M16
               ,`AXI_NV_S10_BY_M16
               ,`AXI_NV_S11_BY_M16
               ,`AXI_NV_S12_BY_M16
               ,`AXI_NV_S13_BY_M16
               ,`AXI_NV_S14_BY_M16
               ,`AXI_NV_S15_BY_M16
               ,`AXI_NV_S16_BY_M16
               , 1
               ,`AXI_BV_S1_BY_M16
               ,`AXI_BV_S2_BY_M16
               ,`AXI_BV_S3_BY_M16
               ,`AXI_BV_S4_BY_M16
               ,`AXI_BV_S5_BY_M16
               ,`AXI_BV_S6_BY_M16
               ,`AXI_BV_S7_BY_M16
               ,`AXI_BV_S8_BY_M16
               ,`AXI_BV_S9_BY_M16
               ,`AXI_BV_S10_BY_M16
               ,`AXI_BV_S11_BY_M16
               ,`AXI_BV_S12_BY_M16
               ,`AXI_BV_S13_BY_M16
               ,`AXI_BV_S14_BY_M16
               ,`AXI_BV_S15_BY_M16
               ,`AXI_BV_S16_BY_M16
             )
       U_awdcdr_m16(
                  .addr_i  (awaddr_m16),
                `ifdef AXI_REMAP

                  .remap_n_i(remap_n),
                `endif

                  .local_slv_o(),
                  .sys_slv_o(xdcdr_slv_num_wr_m16)
                 );
`endif
`endif

 `ifdef AXI_QOS

  /** Instantiate APB Interface */
   apb_if apbif(
    .pclk(pclk)
   );   
  /** Instantiate APB Master, which is used to connect DW_axi APB signals */
  apb_master_vip apb_vip_master_inst(apbif); 
`endif

//------------------------------------------------------------------------

/**
 * Active Master instances of VIP. 
 * Instanstiates `AXI_NUM_MASTERS Master Models.
 */
  svt_axi_master_agent_hdl axi_master[`AXI_NUM_MASTERS:1] (
    .CLK                 (aclk),
    .aresetn             (aresetn),

    .awvalid             (awvalid_m_bus),
    .awaddr              (awaddr_m_bus),
    .awlen               (awlen_m_bus),
    .awsize              (awsize_m_bus),
    .awburst             (awburst_m_bus),
    .awlock              (awlock_m_bus),
    .awcache             (awcache_m_bus),
    .awprot              (awprot_m_bus),
    .awid                (awid_m_bus),
    .awready             (awready_m_bus),
    .awdomain            (awdomain_m_bus),
    .awsnoop             (awsnoop_m_bus),
    .awbar               (awbar_m_bus),

    .arvalid             (arvalid_m_bus),
    .araddr              (araddr_m_bus),
    .arlen               (arlen_m_bus),
    .arsize              (arsize_m_bus),
    .arburst             (arburst_m_bus),
    .arlock              (arlock_m_bus),
    .arcache             (arcache_m_bus),
    .arprot              (arprot_m_bus),
    .arid                (arid_m_bus),
    .arready             (arready_m_bus),
    .ardomain            (ardomain_m_bus),
    .arsnoop             (arsnoop_m_bus),
    .arbar               (arbar_m_bus),

    .rvalid              (rvalid_m_bus),
    .rlast               (rlast_m_bus),
    .rdata               (rdata_m_bus),
    .rresp               (rresp_m_bus),
    .rid                 (rid_m_bus),
    .rready              (rready_m_bus),
    .rack                (rack_m_bus),

    .wvalid              (wvalid_m_bus),
    .wlast               (wlast_m_bus),
    .wdata               (wdata_m_bus),
    .wstrb               (wstrb_m_bus),
    .wid                 (wid_m_bus),
    .wready              (wready_m_bus),

    .bvalid              (bvalid_m_bus),
    .bresp               (bresp_m_bus),
    .bid                 (bid_m_bus),
    .bready              (bready_m_bus),
    .wack                (wack_m_bus),

    .awregion            (awregion_m_bus),
    .awqos               (awqos_m_bus),
    .awuser              (awuser_m_bus),

    .arregion            (arregion_m_bus),
    .arqos               (arqos_m_bus),
    .aruser              (aruser_m_bus),

    .wuser               (wuser_m_bus),
    .ruser               (ruser_m_bus),
    .buser               (buser_m_bus),

    .acvalid             (acvalid_m_bus),
    .acready             (acready_m_bus),
    .acaddr              (acaddr_m_bus),
    .acsnoop             (acsnoop_m_bus),
   // .aclen             (aclen_m_bus),
    .acprot              (acprot_m_bus),
           
    .crvalid             (crvalid_m_bus),
    .crready             (crready_m_bus),
    .crresp              (crresp_m_bus),
            
    .cdvalid             (cdvalid_m_bus),
    .cdready             (cdready_m_bus),
    .cddata              (cddata_m_bus),
    .cdlast              (cdlast_m_bus)

    //.awvalid_passive     (awvalid[31]), 
    //.awaddr_passive      (awaddr[31]),  
    //.awlen_passive       (awlen[31]),   
    //.awsize_passive      (awsize[31]),
    //.awburst_passive     (awburst[31]),
    //.awlock_passive      (awlock[31]),
    //.awcache_passive     (awcache[31]),
    //.awprot_passive      (awprot[31]),
    //.awid_passive        (awid[31]),
    //.awdomain_passive    (awdomain[31]),
    //.awsnoop_passive     (awsnoop[31]),
    //.awbar_passive       (awbar[31]),
    //.arvalid_passive     (arvalid[31]),
    //.araddr_passive      (araddr[31]),
    //.arlen_passive       (arlen[31]),
    //.arsize_passive      (arsize[31]),
    //.arburst_passive     (arburst[31]),
    //.arlock_passive      (arlock[31]),
    //.arcache_passive     (arcache[31]),
    //.arprot_passive      (arprot[31]),
    //.arid_passive        (arid[31]),
    //.ardomain_passive    (ardomain[31]),
    //.arsnoop_passive     (arsnoop[31]),
    //.arbar_passive       (arbar[31]),
    //.rready_passive      (rready[31]),
    //.rack_passive        (rack[31]),
    //.wvalid_passive      (wvalid[31]),
    //.wlast_passive       (wlast[31]),
    //.wdata_passive       (wdata[31]),
    //.wstrb_passive       (wstrb[31]),

    //.wid_passive         (wid[31]),
    //.bready_passive      (bready[31]),
    //.wack_passive        (wack[31]),
    //.awregion_passive    (awregion[31]),
    //.awqos_passive       (awqos[31]),
    //.awuser_passive      (awuser[31]),
    //.arregion_passive    (arregion[31]),
    //.arqos_passive       (arqos[31]),
    //.aruser_passive      (aruser[31]),
    //.wuser_passive       (wuser[31]),
    //.acready_passive     (acready[31]),
    //.crvalid_passive     (crvalid[31]),
    //.crresp_passive      (crresp[31]),
    //.cdvalid_passive     (cdvalid[31]),
    //.cddata_passive      (cddata[31]),
    //.cdlast_passive      (cdlast[31])

  );

//------------------------------------------------------------------------

/**
 * Active slave instances.
 * Instanstiates `AXI_NUM_SLAVES Slave Models.
 */
 svt_axi_slave_agent_hdl axi_slave[`AXI_NUM_SLAVES:1] (
    .CLK                 (aclk),
    .aresetn             (aresetn),

    .awvalid             (awvalid_s_bus),
    .awaddr              (awaddr_s_bus),
    .awlen               (awlen_s_bus),
    .awsize              (awsize_s_bus),
    .awburst             (awburst_s_bus),
    .awlock              (awlock_s_bus),
    .awcache             (awcache_s_bus),
    .awprot              (awprot_s_bus),
    .awid                (awid_s_bus),
    .awready             (awready_s_bus),
    .awdomain            (awdomain_s_bus),
    .awsnoop             (awsnoop_s_bus),
    .awbar               (awbar_s_bus),

    .arvalid             (arvalid_s_bus),
    .araddr              (araddr_s_bus),
    .arlen               (arlen_s_bus),
    .arsize              (arsize_s_bus),
    .arburst             (arburst_s_bus),
    .arlock              (arlock_s_bus),
    .arcache             (arcache_s_bus),
    .arprot              (arprot_s_bus),
    .arid                (arid_s_bus),
    .arready             (arready_s_bus),
    .ardomain            (ardomain_s_bus),
    .arsnoop             (arsnoop_s_bus),
    .arbar               (arbar_s_bus),

    .rvalid              (rvalid_s_bus),
    .rlast               (rlast_s_bus),
    .rdata               (rdata_s_bus),
    .rresp               (rresp_s_bus),
    .rid                 (rid_s_bus),
    .rready              (rready_s_bus),
    .rack                (rack_s_bus),

    .wvalid              (wvalid_s_bus),
    .wlast               (wlast_s_bus),
    .wdata               (wdata_s_bus),
    .wstrb               (wstrb_s_bus),
    .wid                 (wid_s_bus),
    .wready              (wready_s_bus),

    .bvalid              (bvalid_s_bus),
    .bresp               (bresp_s_bus),
    .bid                 (bid_s_bus),
    .bready              (bready_s_bus),
    .wack                (wack_s_bus),

    .awregion            (awregion_s_bus),
    .awqos               (awqos_s_bus),
    .awuser              (awuser_s_bus),

    .arregion            (arregion_s_bus),
    .arqos               (arqos_s_bus),
    .aruser              (aruser_s_bus),

    .wuser               (wuser_s_bus),
    .ruser               (ruser_s_bus),
    .buser               (buser_s_bus),

    .acvalid             (acvalid_s_bus),
    .acready             (acready_s_bus),
    .acaddr              (acaddr_s_bus),
    .acsnoop             (acsnoop_s_bus),
   // .aclen             (aclen_s_bus),
    .acprot              (acprot_s_bus),
           
    .crvalid             (crvalid_s_bus),
    .crready             (crready_s_bus),
    .crresp              (crresp_s_bus),
            
    .cdvalid             (cdvalid_s_bus),
    .cdready             (cdready_s_bus),
    .cddata              (cddata_s_bus),
    .cdlast              (cdlast_s_bus)

    //.awready_passive     (awready[31]),
    //.arready_passive     (arready[31]),
    //.rvalid_passive      (rvalid[31]),
    //.rlast_passive       (rlast[31]),
    //.rdata_passive       (rdata[31]),
    //.rresp_passive       (rresp[31]),
    //.rid_passive         (rid[31]),
    //.wready_passive      (wready[31]),
    //.bvalid_passive      (bvalid[31]),
    //.bresp_passive       (bresp[31]),
    //.bid_passive         (bid[31]),
    //.ruser_passive       (ruser[31]),
    //.buser_passive       (buser[31]),
    //.acvalid_passive     (acvalid[31]),
    //.acaddr_passive      (acaddr[31]),
    //.acsnoop_passive     (acsnoop[31]),
    //.acprot_passive      (acprot[31]),
    //.crready_passive     (crready[31]),
    //.cdready_passive     (cdready[31])

  ); 

/**
 * Drive external priority to random value.
  Enabled when AXI_EXT_PRIORITY is selected 
 **/
 initial begin
  @(seed_set);
 `ifdef AXI_EXT_PRIORITY

  `ifdef AXI_HAS_M1

       axi_master_priority_reg[1] = $random(seed);
       force  axi_master_priority[1]  = axi_master_priority_reg[1] ; 
  `endif
  
  `ifdef AXI_HAS_M2

        axi_master_priority_reg[2] = $random(seed);
       force  axi_master_priority[2]  = axi_master_priority_reg[2] ; 
  `endif
  `ifdef AXI_HAS_M3

        axi_master_priority_reg[3] = $random(seed);
       force  axi_master_priority[3]  = axi_master_priority_reg[3] ; 
  `endif
  `ifdef AXI_HAS_M4

        axi_master_priority_reg[4] = $random(seed);
       force  axi_master_priority[4]  = axi_master_priority_reg[4] ; 
  `endif
  `ifdef AXI_HAS_M5

        axi_master_priority_reg[5] = $random(seed);
       force  axi_master_priority[5]  = axi_master_priority_reg[5] ; 
  `endif
  `ifdef AXI_HAS_M6

        axi_master_priority_reg[6] = $random(seed);
       force  axi_master_priority[6]  = axi_master_priority_reg[6] ; 
  `endif
  `ifdef AXI_HAS_M7

        axi_master_priority_reg[7] = $random(seed);
       force  axi_master_priority[7]  = axi_master_priority_reg[7] ; 
  `endif
  `ifdef AXI_HAS_M8

        axi_master_priority_reg[8] = $random(seed);
       force  axi_master_priority[8]  = axi_master_priority_reg[8] ; 
  `endif
  `ifdef AXI_HAS_M9

        axi_master_priority_reg[9] = $random(seed);
       force  axi_master_priority[9]  = axi_master_priority_reg[9] ; 
  `endif
  `ifdef AXI_HAS_M10

        axi_master_priority_reg[10] = $random(seed);
       force  axi_master_priority[10] = axi_master_priority_reg[10];
  `endif
  `ifdef AXI_HAS_M11

        axi_master_priority_reg[11] = $random(seed);
       force  axi_master_priority[11] = axi_master_priority_reg[11];
  `endif
  `ifdef AXI_HAS_M12

        axi_master_priority_reg[12] = $random(seed);
       force  axi_master_priority[12] = axi_master_priority_reg[12];
  `endif
  `ifdef AXI_HAS_M13

        axi_master_priority_reg[13] = $random(seed);
       force  axi_master_priority[13] = axi_master_priority_reg[13];
  `endif
  `ifdef AXI_HAS_M14

        axi_master_priority_reg[14] = $random(seed);
       force  axi_master_priority[14] = axi_master_priority_reg[14];
  `endif
  `ifdef AXI_HAS_M15

        axi_master_priority_reg[15] = $random(seed);
       force  axi_master_priority[15] = axi_master_priority_reg[15];
  `endif
  `ifdef AXI_HAS_M16

        axi_master_priority_reg[16] = $random(seed);
       force  axi_master_priority[16] = axi_master_priority_reg[16];
  `endif
  
`ifdef AXI_HAS_S1

        axi_slave_priority_reg[1] = $random(seed);
       force  axi_slave_priority[1]  = axi_slave_priority_reg[1] ;
  `endif
`ifdef AXI_HAS_S2

        axi_slave_priority_reg[2] = $random(seed);
       force  axi_slave_priority[2]  = axi_slave_priority_reg[2] ;
  `endif
`ifdef AXI_HAS_S3

        axi_slave_priority_reg[3] = $random(seed);
       force  axi_slave_priority[3]  = axi_slave_priority_reg[3] ;
  `endif
`ifdef AXI_HAS_S4

        axi_slave_priority_reg[4] = $random(seed);
       force  axi_slave_priority[4]  = axi_slave_priority_reg[4] ;
  `endif
`ifdef AXI_HAS_S5

        axi_slave_priority_reg[5] = $random(seed);
       force  axi_slave_priority[5]  = axi_slave_priority_reg[5] ;
  `endif
`ifdef AXI_HAS_S6

        axi_slave_priority_reg[6] = $random(seed);
       force  axi_slave_priority[6]  = axi_slave_priority_reg[6] ;
  `endif
`ifdef AXI_HAS_S7

        axi_slave_priority_reg[7] = $random(seed);
       force  axi_slave_priority[7]  = axi_slave_priority_reg[7] ;
  `endif
`ifdef AXI_HAS_S8

        axi_slave_priority_reg[8] = $random(seed);
       force  axi_slave_priority[8]  = axi_slave_priority_reg[8] ;
  `endif
`ifdef AXI_HAS_S9

        axi_slave_priority_reg[9] = $random(seed);
       force  axi_slave_priority[9]  = axi_slave_priority_reg[9] ;
  `endif
`ifdef AXI_HAS_S10

        axi_slave_priority_reg[10] = $random(seed);
       force  axi_slave_priority[10] = axi_slave_priority_reg[10];
  `endif
`ifdef AXI_HAS_S11

        axi_slave_priority_reg[11] = $random(seed);
       force  axi_slave_priority[11] = axi_slave_priority_reg[11];
  `endif
`ifdef AXI_HAS_S12

        axi_slave_priority_reg[12] = $random(seed);
       force  axi_slave_priority[12] = axi_slave_priority_reg[12];
  `endif
`ifdef AXI_HAS_S13

        axi_slave_priority_reg[13] = $random(seed);
       force  axi_slave_priority[13] = axi_slave_priority_reg[13];
  `endif
`ifdef AXI_HAS_S14

        axi_slave_priority_reg[14] = $random(seed);
       force  axi_slave_priority[14] = axi_slave_priority_reg[14];
  `endif
`ifdef AXI_HAS_S15

        axi_slave_priority_reg[15] = $random(seed);
       force  axi_slave_priority[15] = axi_slave_priority_reg[15];
  `endif
`ifdef AXI_HAS_S16

        axi_slave_priority_reg[16] = $random(seed);
       force  axi_slave_priority[16] = axi_slave_priority_reg[16];
  `endif
  
 `endif//AXI_EXT_PRIORITY
 end

/** Initial csysreq generation - In full power mode */
 initial begin
   csysreq  = 1;
 end

//------------------------------------------------------------------------
/**
  * SDF simulations
  */
`ifdef SDF_FILE

  initial begin
    $display($time,"test_DW_axi : About to sdf-annotate the design %s",`SDF_FILE);
    $sdf_annotate(`SDF_FILE, U_DW_axi, , , `SDF_LEVEL);
  end
`endif

//------------------------------------------------------------------------
/**
  * Waveform Dump.
  */
`ifdef DUMP_DEPTH

  initial begin
   `ifdef VCS

    $vcdpluson(`DUMP_DEPTH, test_DW_axi);
   `else
     `ifdef DUMP_FILE

     `else
       `define DUMP_FILE "test.vpd"
     `endif
    $dumpfile(`DUMP_FILE);
    $dumpvars(`DUMP_DEPTH, test_DW_axi);
   `endif
  end
`endif

//------------------------------------------------------------------------
/** APB clock generation */
initial begin
  pclk = 0;
  #3; // Out of edge with aclk
  forever begin
    #(2*simulation_cycle)
    pclk = !pclk;
  end
end

/** AXI Reset */
initial begin
  aresetn = 1'b1;
  repeat (10) @(posedge system_clk);
  aresetn = 1'b0;
  repeat (10) @(posedge system_clk);
  #200;
  repeat (10) @(posedge system_clk);
  repeat (10) @(posedge system_clk);
  #1 aresetn = 1'b1;
  -> reset_done;
end

`ifdef AXI_QOS

/** Initial APB reset */
initial begin
  presetn = 1'b1;
  repeat (10) @(posedge system_clk);
  repeat (10) @(posedge system_clk);
  #200;
  presetn = 1'b0;
  repeat (10) @(posedge system_clk);
  #1 presetn = 1'b1;
  apb_reg_prog_flag = 1'b0;
  repeat (10) @(posedge system_clk);
end
`endif

initial begin
 //Initialize RW/WR semaphore with 1 key
 rd_wr_semaphore = new(1);
end

//------------------------------------------------------------------------
/** Clock generation. */
initial begin
  system_clk = 0;
  forever begin
    #(simulation_cycle/2)
    system_clk = !system_clk;
  end
end

//------------------------------------------------------------------------
/** Low Power clock generation control **/
reg pstate;
reg next_pstate;
always @(*) begin
   next_pstate = pstate;
   case (pstate)
      FullPower: begin
         low_power_mode = 0;
         if (!csysreq && !cactive && !csysack) begin
            next_pstate = LowPower;
         end
      end

      LowPower: begin
         low_power_mode = 1;
         if (csysreq | cactive) begin
            next_pstate = FullPower;
         end
      end
   endcase
end
always@(posedge aclk or negedge aresetn) begin
   if(~aresetn) begin
       pstate <= FullPower;
   end
   else begin
       pstate <= next_pstate;
   end
end
reg lp_clk_val;
always @(low_power_mode) begin
   lp_clk_val = {$random(seed)} % 2;
end
assign aclklp = (low_power_mode) ? lp_clk_val : system_clk;
//------------------------------------------------------------------------

initial begin

  @(reset_done);

/** Call the region checkers */
`ifdef AXI_REGIONS_S1

    check_region_decoding(1);
`endif  
`ifdef AXI_REGIONS_S2

    check_region_decoding(2);
`endif  
`ifdef AXI_REGIONS_S3

    check_region_decoding(3);
`endif  
`ifdef AXI_REGIONS_S4

    check_region_decoding(4);
`endif  
`ifdef AXI_REGIONS_S5

    check_region_decoding(5);
`endif  
`ifdef AXI_REGIONS_S6

    check_region_decoding(6);
`endif  
`ifdef AXI_REGIONS_S7

    check_region_decoding(7);
`endif  
`ifdef AXI_REGIONS_S8

    check_region_decoding(8);
`endif  
`ifdef AXI_REGIONS_S9

    check_region_decoding(9);
`endif  
`ifdef AXI_REGIONS_S10

    check_region_decoding(10);
`endif  
`ifdef AXI_REGIONS_S11

    check_region_decoding(11);
`endif  
`ifdef AXI_REGIONS_S12

    check_region_decoding(12);
`endif  
`ifdef AXI_REGIONS_S13

    check_region_decoding(13);
`endif  
`ifdef AXI_REGIONS_S14

    check_region_decoding(14);
`endif  
`ifdef AXI_REGIONS_S15

    check_region_decoding(15);
`endif  
`ifdef AXI_REGIONS_S16

    check_region_decoding(16);
`endif  

/** Call the ACE-Lite checker */
`ifdef AXI_HAS_ACELITE

  `ifdef AXI_HAS_S1

    check_acelite_signals(1);
  `endif
  `ifdef AXI_HAS_S2

    check_acelite_signals(2);
  `endif
  `ifdef AXI_HAS_S3

    check_acelite_signals(3);
  `endif
  `ifdef AXI_HAS_S4

    check_acelite_signals(4);
  `endif
  `ifdef AXI_HAS_S5

    check_acelite_signals(5);
  `endif
  `ifdef AXI_HAS_S6

    check_acelite_signals(6);
  `endif
  `ifdef AXI_HAS_S7

    check_acelite_signals(7);
  `endif
  `ifdef AXI_HAS_S8

    check_acelite_signals(8);
  `endif
  `ifdef AXI_HAS_S9

    check_acelite_signals(9);
  `endif
  `ifdef AXI_HAS_S10

    check_acelite_signals(10);
  `endif
  `ifdef AXI_HAS_S11

    check_acelite_signals(11);
  `endif
  `ifdef AXI_HAS_S12

    check_acelite_signals(12);
  `endif
  `ifdef AXI_HAS_S13

    check_acelite_signals(13);
  `endif
  `ifdef AXI_HAS_S14

    check_acelite_signals(14);
  `endif
  `ifdef AXI_HAS_S15

    check_acelite_signals(15);
  `endif
  `ifdef AXI_HAS_S16

    check_acelite_signals(16);
  `endif
`endif

/** Call the sideband checker */
`ifdef AXI_HAS_AXI3

  `ifdef AXI_HAS_S1

    check_aw_ar_w_sideband_signals(1);
  `endif
  `ifdef AXI_HAS_S2

    check_aw_ar_w_sideband_signals(2);
  `endif
  `ifdef AXI_HAS_S3

    check_aw_ar_w_sideband_signals(3);
  `endif
  `ifdef AXI_HAS_S4

    check_aw_ar_w_sideband_signals(4);
  `endif
  `ifdef AXI_HAS_S5

    check_aw_ar_w_sideband_signals(5);
  `endif
  `ifdef AXI_HAS_S6

    check_aw_ar_w_sideband_signals(6);
  `endif
  `ifdef AXI_HAS_S7

    check_aw_ar_w_sideband_signals(7);
  `endif
  `ifdef AXI_HAS_S8

    check_aw_ar_w_sideband_signals(8);
  `endif
  `ifdef AXI_HAS_S9

    check_aw_ar_w_sideband_signals(9);
  `endif
  `ifdef AXI_HAS_S10

    check_aw_ar_w_sideband_signals(10);
  `endif
  `ifdef AXI_HAS_S11

    check_aw_ar_w_sideband_signals(11);
  `endif
  `ifdef AXI_HAS_S12

    check_aw_ar_w_sideband_signals(12);
  `endif
  `ifdef AXI_HAS_S13

    check_aw_ar_w_sideband_signals(13);
  `endif
  `ifdef AXI_HAS_S14

    check_aw_ar_w_sideband_signals(14);
  `endif
  `ifdef AXI_HAS_S15

    check_aw_ar_w_sideband_signals(15);
  `endif
  `ifdef AXI_HAS_S16

    check_aw_ar_w_sideband_signals(16);
  `endif

  `ifdef AXI_HAS_M1

    check_b_r_sideband_signals(1);
  `endif
  `ifdef AXI_HAS_M2

    check_b_r_sideband_signals(2);
  `endif
  `ifdef AXI_HAS_M3

    check_b_r_sideband_signals(3);
  `endif
  `ifdef AXI_HAS_M4

    check_b_r_sideband_signals(4);
  `endif
  `ifdef AXI_HAS_M5

    check_b_r_sideband_signals(5);
  `endif
  `ifdef AXI_HAS_M6

    check_b_r_sideband_signals(6);
  `endif
  `ifdef AXI_HAS_M7

    check_b_r_sideband_signals(7);
  `endif
  `ifdef AXI_HAS_M8

    check_b_r_sideband_signals(8);
  `endif
  `ifdef AXI_HAS_M9

    check_b_r_sideband_signals(9);
  `endif
  `ifdef AXI_HAS_M10

    check_b_r_sideband_signals(10);
  `endif
  `ifdef AXI_HAS_M11

    check_b_r_sideband_signals(11);
  `endif
  `ifdef AXI_HAS_M12

    check_b_r_sideband_signals(12);
  `endif
  `ifdef AXI_HAS_M13

    check_b_r_sideband_signals(13);
  `endif
  `ifdef AXI_HAS_M14

    check_b_r_sideband_signals(14);
  `endif
  `ifdef AXI_HAS_M15

    check_b_r_sideband_signals(15);
  `endif
  `ifdef AXI_HAS_M16

    check_b_r_sideband_signals(16);
  `endif
`endif
end

/**
 * File containing utility methods to initialize VIP instances.
 */
 `include "tb_initialize.sv"

`ifdef AXI_QOS

  `include "../testbench/sim_svte/tb_apb_rd_wr.sv"
`endif//AXI_QOS

/** 
 * To call 'test_inst.run_test' which will initiate the traffic.
 */
 test test_inst();

/** 
 * Main Test Program. 
 *   -> Launches the test execution processes involved in the test.
 */
 initial begin: main_program
   remap_n = 1;
   test_debug = 0;
   @(reset_done)
   seed = `AXI_SEED;
   $display("\n@%0d [TB_INFO] {%m} : Seed value passed through AXI_SEED is 32'h%0h\n",$time,seed);
   -> seed_set;

   sim_in_progress = 1;
   `ifdef AXI_REMAP

     remap_n = {$random(seed)} % 2;
   `endif

   /** Shared layer priorities. */
   `ifdef AXI_EXT_PRIORITY

     `ifdef AXI_SHARED_LAYER_SLAVE_PRIORITY_EN

       slv_priority_shared = {$random(seed)};
     `endif
     `ifdef AXI_SHARED_LAYER_MASTER_PRIORITY_EN

       mst_priority_shared = {$random(seed)};
     `endif
   `endif

   /**
    * Configure the Master and Slave VIP instances. 
    */
   configure_master_vip;
   configure_slave_vip;

   /**
    * Start the VIP instances
    */
   start_all_masters;
   start_all_slaves;

   `ifdef AXI_TZ_SUPPORT

     tz_secure_s = {$random(seed)} % {(`AXI_NUM_SLAVES + 1){1'b1}};
     tz_secure_s[0] = 0;
   `endif

   /**
    * Start the test
    */
   test_inst.run_test;

   sim_in_progress = 0;
   @(posedge system_clk);

   $display("-------------------------");
   $display("  Simulation Completed   ");
   $display("-------------------------");
   $display("User test stimulus has completed");

   /**
    * Stop the VIP instances
    */
   stop_all_masters;
   stop_all_slaves;

   repeat (10) @(posedge system_clk);

   $finish;
 end : main_program

 /**
  * Testcase timeout block.
  */
 initial begin : test_timeout
   `TEST_TIMEOUT;
   $display("\n",$time," ERROR : Testcase timed out.\n");
   $finish;
 end

//------------------------------------------------------------------------

endmodule

