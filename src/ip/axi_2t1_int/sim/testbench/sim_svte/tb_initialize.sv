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
// File Version     :        $Revision: #1 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/sim/testbench/sim_svte/tb_initialize.sv#1 $ 
//------------------------------------------------------------------------

`ifndef TB_INITIALIZE_V

`define TB_INITIALIZE_V

/**
 * To hold the return 'is_valid' of set/get and other VIP calls.
 * Also used to check whether the return value is correct or not.
 */
reg is_valid;

/**
 * Variable used in VIP method calls - to temporarily store the handle.
 */
integer handle;
integer sys_cfg_handle;

/**
 * Defines used while initializing the VIP instances
 */
`define AXI_VIP_ACTIVE   1
`define AXI_VIP_PASSIVE  0

/** 
 * Set Up the Master's Configuration
 *   -- Get an integer handle that references a temporary copy of the Master's (default)
 *      internal configuration data object. Using this handle, the desired configuration
 *      settings will be applied to the properties of the temporary copy. 
 *
 */ 
`define AXI_SVT_CONFIGURE_VIP(transactor,xactor_id, mstr_slv_type, is_active_passive,handle,is_valid) \
  `GET_DATA_PROP_W_CHECK(transactor,xactor_id, `SVT_CMD_NULL_HANDLE, "cfg", handle, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "axi_port_kind", mstr_slv_type, 0, is_valid) \
  `ifdef AXI_HAS_AXI4\
\
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "axi_interface_type", `SVT_AXI_INTERFACE_AXI4, 0, is_valid) \
  `endif \
  `ifdef AXI_HAS_AXI3\
\
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "axi_interface_type", `SVT_AXI_INTERFACE_AXI3, 0, is_valid) \
  `endif \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "axi_interface_category", `SVT_AXI_READ_WRITE, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "addr_width",`AXI_AW, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "data_width",`AXI_DW, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "is_active",is_active_passive, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "exclusive_access_enable", 1, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "max_num_exclusive_access",4, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "axi_port_kind", mstr_slv_type, 0, is_valid) \
  `ifdef AXI_HAS_AXI4\
\
  `ifdef AXI_INC_AWSB\
\
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "awuser_enable", 1, 0, is_valid) \
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "addr_user_width", `AXI_AW_SBW, 0, is_valid) \
  `endif \
  `ifdef AXI_INC_WSB\
\
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "wuser_enable", 1, 0, is_valid) \
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "data_user_width", `AXI_W_SBW, 0, is_valid) \
  `endif \
  `ifdef AXI_INC_BSB\
\
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "buser_enable", 1, 0, is_valid) \
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "resp_user_width", `AXI_B_SBW, 0, is_valid) \
  `endif \
  `ifdef AXI_INC_ARSB\
\
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "aruser_enable", 1, 0, is_valid) \
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "addr_user_width", `AXI_AR_SBW, 0, is_valid) \
  `endif \
  `ifdef AXI_INC_RSB\
\
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "ruser_enable", 1, 0, is_valid) \
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "data_user_width", `AXI_R_SBW, 0, is_valid) \
  `endif \
  `endif \
  `ifdef AXI_QOS\
\
    `ifdef AXI_HAS_AXI4\
\
      `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "awqos_enable",1, 0, is_valid) \
      `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "arqos_enable",1, 0, is_valid) \
    `endif \
  `endif \
  if (mstr_slv_type == `SVT_AXI_SLAVE) begin \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "id_width",`AXI_SIDW, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "default_awready",{$random(seed)}%2, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "default_arready",{$random(seed)}%2, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "default_wready",{$random(seed)}%2, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "num_outstanding_xact",slv_max_transaction[xactor_id], 0, is_valid) \
  `ifdef AXI_HAS_AXI3\
\
    if (slv_wid_array[xactor_id] > 8) \
      `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "write_data_interleave_depth",8, 0, is_valid) \
    else \
      `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "write_data_interleave_depth",slv_wid_array[xactor_id], 0, is_valid) \
  `endif \
  `ifdef AXI_HAS_AXI4\
\
    `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "write_data_interleave_depth",1, 0, is_valid) \
    if (axi_has_region[xactor_id-1]) begin \
      `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "awregion_enable",1, 0, is_valid) \
      `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "arregion_enable",1, 0, is_valid) \
    end \
  `endif \
  if(ri_limit_m[`AXI_NUM_MASTERS-1:0] == {`AXI_NUM_MASTERS{1'b0}}) begin \
   if(slv_max_rd_transaction[xactor_id] > 8) \
     `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "read_data_interleave_size",8, 0, is_valid) \
   else  \
     `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "read_data_interleave_size",slv_max_rd_transaction[xactor_id], 0, is_valid) \
  end else begin \
     `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "read_data_interleave_size",1, 0, is_valid) \
      end \
  end \
  else if (mstr_slv_type == `SVT_AXI_MASTER) begin \
    if(xactor_id <= `AXI_NUM_ICM) \
      `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "id_width",`AXI_SIDW, 0, is_valid) \
    else \
      `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "id_width",`AXI_MIDW, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "default_rready",{$random(seed)}%2, 0,is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "default_bready",{$random(seed)}%2, 0,is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "num_outstanding_xact",mst_max_transaction[xactor_id], 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "write_data_interleave_depth",1, 0,is_valid) \
  end \
  `GET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, "sys_cfg", sys_cfg_handle ,0,is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, sys_cfg_handle, "bus_inactivity_timeout", 10000000, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, sys_cfg_handle, "awready_watchdog_timeout", 5000, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, sys_cfg_handle, "arready_watchdog_timeout", 8000, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, sys_cfg_handle, "bready_watchdog_timeout", 5000, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, sys_cfg_handle, "rready_watchdog_timeout", 8000, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, sys_cfg_handle, "wready_watchdog_timeout", 5000, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, sys_cfg_handle, "rdata_watchdog_timeout", 30000, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, sys_cfg_handle, "bresp_watchdog_timeout", 5000, 0, is_valid) \
  `SET_DATA_PROP_W_CHECK(transactor,xactor_id, `SVT_CMD_NULL_HANDLE, "filter(Timed out waiting for wdata after Write address handshake assertion)", `SVT_CMD_NORMAL_SEVERITY, 0, is_valid)
/**
  * Demoting known UVM_ERROR due to VIP restriction -- STAR 9000777797.
  */                                               

/**
  * Method to Configure Masters VIP instances.
  */
task configure_master_vip;
  integer i;
  integer xfer_handle;
  reg is_valid;
  begin
    $display ("\n@%0d [TB_INFO] {%m} : Master configuration started\n",$time);
    for (i = 1 ; i <= `AXI_NUM_MASTERS; i++) begin
      `AXI_SVT_CONFIGURE_VIP("master",i, `SVT_AXI_MASTER, `AXI_VIP_ACTIVE,xfer_handle,is_valid)
      `TOP.vip_apply_data("master",i,xfer_handle);
      `GET_DATA_PROP_W_CHECK("master",i, `SVT_CMD_NULL_HANDLE, "cfg", xfer_handle, 0, is_valid) 
      if (test_debug) `TOP.vip_display_data("master",i,xfer_handle,"[TB_DEBUG] Master Configuration");
    end
    $display ("\n@%0d [TB_INFO] {%m} : Master configuration ended\n",$time);
  end
endtask

/**
  * Method to Configure Slave VIP instances.
  */
task configure_slave_vip;
  integer i;
  reg is_valid;
  integer xfer_handle;
  begin
    $display ("\n@%0d [TB_INFO] {%m} : Slave configuration Started\n",$time);
    for (i = 1 ; i <= `AXI_NUM_SLAVES; i++) begin
      `AXI_SVT_CONFIGURE_VIP("slave",i, `SVT_AXI_SLAVE, `AXI_VIP_ACTIVE,xfer_handle,is_valid)
      `TOP.vip_apply_data("slave",i,xfer_handle);
      `GET_DATA_PROP_W_CHECK("slave",i, `SVT_CMD_NULL_HANDLE, "cfg", xfer_handle, 0, is_valid) 
      if (test_debug) `TOP.vip_display_data("slave",i,xfer_handle,"[TB_DEBUG] Slave Configuration");
    end
    $display ("\n@%0d [TB_INFO] {%m} : Slaves configuration Ended\n",$time);
  end
endtask

/**
 * Method to start the Master transactors
 */
task start_all_masters;
  integer i;
  begin
    $display ("\n@%0d [TB_INFO] {%m} : Starting all masters\n",$time);
    for (i = 1; i <= `AXI_NUM_MASTERS; i++) begin
      `TOP.vip_start("master",i);
    end
  end
endtask

/**
 * Method to start the Slave transactors
 */
task start_all_slaves;
  integer i;
  begin
     $display ("\n@%0d [TB_INFO] {%m} : Starting all slaves\n",$time);
    for (i = 1; i <= `AXI_NUM_SLAVES; i++) begin
      `TOP.vip_start("slave",i);
    end
  end
endtask

/**
 * Method to stop the Master transactors
 */
task stop_all_masters;
  integer i;
  begin
    $display ("\n@%0d [TB_INFO] {%m} : Stoping all masters\n",$time);
    for (i = 1; i <= `AXI_NUM_MASTERS; i++) begin
      `TOP.vip_stop("master",i);
    end
  end
endtask

/**
 * Method to stop the Slave transactors
 */
task stop_all_slaves;
  integer i;
  begin
    $display ("\n@%0d [TB_INFO] {%m} : Stoping all slaves\n",$time);
    for (i = 1; i <= `AXI_NUM_SLAVES; i++) begin
      `TOP.vip_stop("slave",i);
    end
  end
endtask

`endif // TB_INITIALIZE_V
