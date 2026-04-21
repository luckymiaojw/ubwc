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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/sim/testbench/sim_svte/tb_axi_tasks_slv.sv#1 $ 
//------------------------------------------------------------------------

`ifndef TB_AXI_TASKS_SLV_V

`define TB_AXI_TASKS_SLV_V

//------------------------------------------------------------------------
// Randomizes the slave transaction
//
task automatic axi_slave_rand_xact;
  input integer slave_id;
  input resp_type;
  inout integer xfer_handle;

  begin
    /** To capture the retun is_valid value after the callback call. */
    reg is_valid;

    /** Variables to generate and set random delays */
    integer addr_ready_delay;
    integer bvalid_delay;
    integer rvalid_delay;
    integer wready_delay;

    /** To store the resposne object attributes. */
    integer burst_length, xact_type, atomic_type, resp;
    integer coherent_xact_type;
    `ifdef AXI_HAS_AXI4

      reg [`SVT_AXI_MAX_BRESP_USER_WIDTH-1:0] resp_user;
      reg [`SVT_AXI_MAX_DATA_USER_WIDTH-1:0]  data_user;
    `endif

    /** Temporary variable */
    integer i;

    /** Get the response attributes, based on which actual response is programmed */
    `GET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "xact_type",xact_type, 0,is_valid)
    `GET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "burst_length",burst_length, 0,is_valid)
    `GET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "atomic_type",atomic_type, 0,is_valid)
//`ifdef AXI_HAS_ACELITE
//    `GET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "coherent_xact_type",coherent_xact_type, 0,is_valid)
//`endif
    /** Set array sizes to burst_length */
    `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "wready_delay_size",burst_length, 0,is_valid)
    `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "rvalid_delay_size",burst_length, 0,is_valid)
    `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "data_user_size",burst_length, 0,is_valid)
    `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "random_interleave_array_size",burst_length, 0, is_valid)

    /** Program interleave array values */
    for(i=0; i<burst_length; i++) begin 
      if(burst_length == 1) begin
          `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "random_interleave_array",burst_length, i, is_valid)
      end    
      else begin
        `SET_DATA_PROP_W_CHECK("slave",slave_id, xfer_handle, "random_interleave_array",(burst_length-1), i, is_valid)
      end  
    end

//`ifdef AXI_HAS_ACELITE
//    if(coherent_xact_type >= `SVT_AXI_COHERENT_TRANSACTION_TYPE_WRITENOSNOOP)begin // write
//`else
    if(xact_type == `SVT_AXI_TRANSACTION_TYPE_WRITE) begin // Write
//`endif
      if(resp_type == `SIM_RESP_RAND) begin 
        resp = {$random(seed)} % 3;
        while (resp==1) 
          resp = {$random(seed)} % 3;
      end  
      else 
        resp = resp_type;

      /** If exclusive access, always give EXOKAY response */
      if (atomic_type == 1)
        resp = 1;

      `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "bresp",resp, 0,is_valid)
    end
    else begin  // Read
      for(i=0; i<burst_length; i++) begin 
        if(resp_type == `SIM_RESP_RAND) begin 
          resp = {$random(seed)} % 3;
          while (resp==1) 
            resp = {$random(seed)} % 3;
        end  
        else 
          resp = resp_type;

        /** If exclusive access, always give EXOKAY response */
        if (atomic_type == 1)
          resp = 1;

        `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "rresp",resp, i,is_valid)
      end
    end

    /** Program delays */
    addr_ready_delay = $random(seed) % 4;
    while (addr_ready_delay < 0) begin
      addr_ready_delay = $random(seed) % 4;
    end
    `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "addr_ready_delay",addr_ready_delay, 0, is_valid)

    bvalid_delay = $random(seed) % 4;
    while (bvalid_delay < 0) begin
      bvalid_delay = $random(seed) % 4;
    end
    if (long_bvalid_delay == 1) begin
      bvalid_delay = 16; // set to large value to throttle slave response generation (for test_max_id_limit test)
    end
    `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "bvalid_delay",bvalid_delay, 0, is_valid)

    for (i=0; i<burst_length; i++) begin 
      rvalid_delay = {$random(seed)} % 4;
      while (rvalid_delay < 0) begin
        rvalid_delay = $random(seed) % 4;
      end
      if (long_rvalid_delay == 1) begin
        rvalid_delay = 16; // set to large value to throttle slave response generation (for test_max_id_limit test)
      end
      `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle,"rvalid_delay", rvalid_delay, i,is_valid)

      wready_delay = {$random(seed)} % 4;
      while (wready_delay < 0) begin
        wready_delay = $random(seed) % 4;
      end
      `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle,"wready_delay", wready_delay, i,is_valid)
    end

`ifdef AXI_HAS_AXI4

//`ifdef AXI_HAS_ACELITE
//    if(coherent_xact_type >= `SVT_AXI_COHERENT_TRANSACTION_TYPE_WRITENOSNOOP)begin // write
//`else
    if(xact_type == `SVT_AXI_TRANSACTION_TYPE_WRITE) begin // Write
//`endif
      resp_user = $random(seed) ; 
      `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle, "resp_user",resp_user, 0, is_valid)
    end
    else begin // Read
      for(i=0;i<burst_length;i++) begin
        data_user = $random(seed);
        `SET_DATA_PROP_W_CHECK("slave",slave_id,xfer_handle,"data_user", data_user, i,is_valid)
      end
    end
`endif
  end
endtask

/** Waits for the callback and apply the random response */
task automatic axi_slave_send_rand_response;
  input integer slave_id;
  begin
    /**
     * To capture the retun is_valid value after the callback call.
     */
    reg is_valid;

    /**
     * Declare and initialize callback handle to null.
     */
    integer  callback_handle;

    integer i;
    callback_handle = `SVT_CMD_NULL_HANDLE;

    if (test_debug) $display("@%0d [TB_DEBUG] {%m} : Slave Random response started\n",$time);
    forever begin
      /** Wait for the callback */
      `TOP.vip_callback_wait_for("slave",slave_id,"monitor.NOTIFY_CB_PRE_RESPONSE_REQUEST_PORT_PUT",callback_handle,is_valid);
      if (test_debug) $display("@%0d [TB_DEBUG] {%m} : Got the slave [%0d] response request \n",$time,slave_id);

      /** Generate the random response */
      `TOP.axi_slave_rand_xact(slave_id,`SIM_RESP_RAND,callback_handle);

      /** Display the response */
      if (test_debug) `TOP.vip_display_data("slave",slave_id,callback_handle,"[TB_DEBUG] Slave Transaction:  ");

      /** Apply the data */
      `TOP.vip_apply_data("slave",slave_id,callback_handle);
      `TOP.vip_notify_wait_for("slave",slave_id,"driver.NOTIFY_TX_XACT_CONSUMED",is_valid);

      /** Proceed with the callback */
      `TOP.vip_callback_proceed("slave",slave_id,"monitor.NOTIFY_CB_PRE_RESPONSE_REQUEST_PORT_PUT",callback_handle,is_valid);
      if (test_debug) $display("@%0d [TB_DEBUG] {%m} : Send the slave [%0d] response request \n",$time,slave_id);
    end
  end
endtask

`endif // TB_AXI_TASKS_SLV_V
