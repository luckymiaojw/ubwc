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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/sim/testbench/sim_svte/tb_checker.sv#2 $ 
//------------------------------------------------------------------------

`ifndef TB_CHECKER_V

`define TB_CHECKER_V

// ------------------------------------------------------------------------------------------------------------------------------------

/** 
  * Checker for REGION signals
  * REGION signals are driven based on the memory map.
  * Expected values are computed as below:
  * - Based on the Slave address and memorymap, region value
  *   pre-calculated and stored as expected value.
  * - Actual value is sampled from the REGION signal seen on
  *   the interface
  */
task automatic check_region_decoding;
  input [31:0] slaveID;
  reg [3:0] awregion_actual,arregion_actual;
  reg [3:0] awregion_expected,arregion_expected;
  reg [`AXI_AW-1:0] awaddr_tmp,araddr_tmp;
begin
  if (test_debug) $display("@%0d [TB_DEBUG] {%m} : Calling check_region_decoding for Slave=%0d\n",$time,slaveID);
  fork
  begin //Write Address channel
    while (1) begin
      @(posedge `TOP.aclk);

      if (awvalid_s_bus[slaveID - 1]) begin
        if (test_debug) $display("@%0d [TB_DEBUG] {%m} : Detected valid write transaction for Slave=%0d\n",$time,slaveID);
        awregion_actual = awregion_s[slaveID];
        awaddr_tmp      = awaddr_s[slaveID];

        //Compute the expected region value
        if ( awaddr_tmp >= slv_region_start_array[slaveID][0] && awaddr_tmp <= slv_region_end_array[slaveID][0] ) awregion_expected = 0;
        else if ( awaddr_tmp >= slv_region_start_array[slaveID][1] && awaddr_tmp <= slv_region_end_array[slaveID][1] ) awregion_expected = 1;
        else if ( awaddr_tmp >= slv_region_start_array[slaveID][2] && awaddr_tmp <= slv_region_end_array[slaveID][2] ) awregion_expected = 2;
        else if ( awaddr_tmp >= slv_region_start_array[slaveID][3] && awaddr_tmp <= slv_region_end_array[slaveID][3] ) awregion_expected = 3;
        else if ( awaddr_tmp >= slv_region_start_array[slaveID][4] && awaddr_tmp <= slv_region_end_array[slaveID][4] ) awregion_expected = 4;
        else if ( awaddr_tmp >= slv_region_start_array[slaveID][5] && awaddr_tmp <= slv_region_end_array[slaveID][5] ) awregion_expected = 5;
        else if ( awaddr_tmp >= slv_region_start_array[slaveID][6] && awaddr_tmp <= slv_region_end_array[slaveID][6] ) awregion_expected = 6;
        else if ( awaddr_tmp >= slv_region_start_array[slaveID][7] && awaddr_tmp <= slv_region_end_array[slaveID][7] ) awregion_expected = 7;
    
        if (awregion_actual !== awregion_expected) begin
          $display("ERROR: %0d - SLV AWREGION CHECKER - Slave %0d: Received AWREGION value %0h, expected AWREGION value %0h;  Address value %0h", $time, slaveID, awregion_actual, awregion_expected, awaddr_tmp);
        end 
      end  
    end  
  end  
  begin //Read Address channel
    while (1) begin
      @(posedge `TOP.aclk);

      if (arvalid_s_bus[slaveID - 1]) begin
        if (test_debug) $display("@%0d [TB_DEBUG] {%m} : Detected valid read transaction for Slave=%0d\n",$time,slaveID);
        arregion_actual = arregion_s[slaveID];
        araddr_tmp      = araddr_s[slaveID];

        //Compute the expected region value
        if ( araddr_tmp >= slv_region_start_array[slaveID][0] && araddr_tmp <= slv_region_end_array[slaveID][0] ) arregion_expected = 0;
        else if ( araddr_tmp >= slv_region_start_array[slaveID][1] && araddr_tmp <= slv_region_end_array[slaveID][1] ) arregion_expected = 1;
        else if ( araddr_tmp >= slv_region_start_array[slaveID][2] && araddr_tmp <= slv_region_end_array[slaveID][2] ) arregion_expected = 2;
        else if ( araddr_tmp >= slv_region_start_array[slaveID][3] && araddr_tmp <= slv_region_end_array[slaveID][3] ) arregion_expected = 3;
        else if ( araddr_tmp >= slv_region_start_array[slaveID][4] && araddr_tmp <= slv_region_end_array[slaveID][4] ) arregion_expected = 4;
        else if ( araddr_tmp >= slv_region_start_array[slaveID][5] && araddr_tmp <= slv_region_end_array[slaveID][5] ) arregion_expected = 5;
        else if ( araddr_tmp >= slv_region_start_array[slaveID][6] && araddr_tmp <= slv_region_end_array[slaveID][6] ) arregion_expected = 6;
        else if ( araddr_tmp >= slv_region_start_array[slaveID][7] && araddr_tmp <= slv_region_end_array[slaveID][7] ) arregion_expected = 7;

        if (arregion_actual !== arregion_expected) begin
          $display("ERROR: %0d - SLV ARREGION CHECKER - Slave %0d: Received ARREGION value %0h, expected ARREGION value %0h;  Address value %0h", $time, slaveID, arregion_actual, arregion_expected, araddr_tmp);
        end 
      end  
    end  
  end    
  join_none
end
endtask : check_region_decoding

// ------------------------------------------------------------------------------------------------------------------------------------

/** 
  * Checker for ACE-LITE signals
  * ACELITE signals are just pass through in the interconnect
  * Expected values are computed as below:
  * AWBAR = ~AWBURST, AWDOMAIN = AWBURST, AWSNOOP = AWPROT
  * ARBAR = ~ARBURST, ARDOMAIN = ARBURST, ARSNOOP = ARCACHE
  */
task automatic check_acelite_signals;
  input [31:0] slaveID;
  reg [1:0] awdomain_actual, awdomain_expected;
  reg [1:0] ardomain_actual, ardomain_expected;
  reg [1:0] awbar_actual, awbar_expected;
  reg [1:0] arbar_actual, arbar_expected;
  reg [2:0] wsnoop_actual, wsnoop_expected;
  reg [3:0] rsnoop_actual, rsnoop_expected;
begin
  if (test_debug) $display("@%0d [TB_DEBUG] {%m} : Calling check_acelite_signals for Slave=%0d\n",$time,slaveID);
  fork
  begin //Write Address channel
    while (1) begin
      @(posedge `TOP.aclk);

      if (awvalid_s_bus[slaveID - 1]) begin
        awdomain_expected = awburst_s[slaveID];
        awdomain_actual   = awdomain_s[slaveID];
        awbar_expected    = ~awburst_s[slaveID];
        awbar_actual      = awbar_s[slaveID];  
        wsnoop_expected   = awprot_s[slaveID];
        wsnoop_actual     = awsnoop_s[slaveID];  
        if (awdomain_actual !== awdomain_expected) begin
          $display("ERROR: %0d - SLV AWDOMAIN CHECKER - Slave %0d: Received AWDOMAIN value %0h, expected AWDOMAIN value %0h", $time, slaveID, awdomain_actual, awdomain_expected);
        end 
        else begin
          if (test_debug) $display("DEBUG: %0d - SLV AWDOMAIN CHECKER - Slave %0d: Received AWDOMAIN value %0h, expected AWDOMAIN value %0h", $time, slaveID, awdomain_actual, awdomain_expected);
        end   
        if (awbar_actual !== awbar_expected) begin
          $display("ERROR: %0d - SLV AWBAR CHECKER - Slave %0d: Received AWBAR value %0h, expected AWBAR value %0h", $time, slaveID, awbar_actual, awbar_expected);
        end    
        else begin
          if (test_debug) $display("DEBUG: %0d - SLV AWBAR CHECKER - Slave %0d: Received AWBAR value %0h, expected AWBAR value %0h", $time, slaveID, awbar_actual, awbar_expected);
        end   
        if (wsnoop_actual !== wsnoop_expected) begin
          $display("ERROR: %0d - SLV AWSNOOP CHECKER - Slave %0d: Received AWSNOOP value %0h, expected AWSNOOP value %0h", $time, slaveID, wsnoop_actual, wsnoop_expected);
        end    
        else begin
          if (test_debug) $display("DEBUG: %0d - SLV AWSNOOP CHECKER - Slave %0d: Received AWSNOOP value %0h, expected AWSNOOP value %0h", $time, slaveID, wsnoop_actual, wsnoop_expected);
        end   
      end
    end  
  end
  begin
    while (1) begin
      @(posedge `TOP.aclk);

      if (arvalid_s_bus[slaveID - 1]) begin
        ardomain_expected = arburst_s[slaveID];
        ardomain_actual   = ardomain_s[slaveID];
        arbar_expected    = ~arburst_s[slaveID];
        arbar_actual      = arbar_s[slaveID];  
        rsnoop_expected   = arcache_s[slaveID];
        rsnoop_actual     = arsnoop_s[slaveID];

        if (ardomain_actual !== ardomain_expected) begin
          $display("ERROR: %0d - SLV ARDOMAIN CHECKER - Slave %0d: Received ARDOMAIN value %0h, expected ARDOMAIN value %0h", $time, slaveID, ardomain_actual, ardomain_expected);
        end    
        else begin
          if (test_debug) $display("DEBUG: %0d - SLV ARDOMAIN CHECKER - Slave %0d: Received ARDOMAIN value %0h, expected ARDOMAIN value %0h", $time, slaveID, ardomain_actual, ardomain_expected);
        end   
        if (arbar_actual !== arbar_expected) begin
          $display("ERROR: %0d - SLV ARBAR CHECKER - Slave %0d: Received ARBAR value %0h, expected ARBAR value %0h", $time, slaveID, arbar_actual, arbar_expected);
        end    
        else begin
          if (test_debug) $display("DEBUG: %0d - SLV ARBAR CHECKER - Slave %0d: Received ARBAR value %0h, expected ARBAR value %0h", $time, slaveID, arbar_actual, arbar_expected);
        end   
        if (rsnoop_actual !== rsnoop_expected) begin
          $display("ERROR: %0d - SLV ARSNOOP CHECKER - Slave %0d: Received ARSNOOP value %0h, expected ARSNOOP value %0h", $time, slaveID, rsnoop_actual, rsnoop_expected);
        end    
        else begin
          if (test_debug) $display("DEBUG: %0d - SLV ARSNOOP CHECKER - Slave %0d: Received ARSNOOP value %0h, expected ARSNOOP value %0h", $time, slaveID, rsnoop_actual, rsnoop_expected);
        end   
      end   
    end   
  end    
  join_none
end

endtask : check_acelite_signals

// ------------------------------------------------------------------------------------------------------------------------------------

/** 
  * Checker for sideband signals. The sideband signals are just pass through in the interconnect
  *   For AWSB - awaddr value is replicated twice and driven on awsideband_m*
  *   For ARSB - araddr value is replicated twice and driven on awsideband_m*
  *   For WSB -  wdata  value is replicated 8 times and driven on awsideband_m*
  */
task automatic check_aw_ar_w_sideband_signals;
  input [31:0] slaveID;
  begin
`ifdef AXI_INC_AWSB

    fork 
    begin : check_sideband_signals_awsb
      reg [`AXI_AW_SBW-1:0]   awsideband_expected_s;
      reg [`AXI_AW_SBW-1:0]   awsideband_received_s;
      while (1) begin
        @(posedge `TOP.aclk);
          if (awvalid_s_bus[slaveID - 1]) begin
            awsideband_expected_s = {2{awaddr_s[slaveID][`AXI_AW-1:0]}};
            awsideband_received_s = awsideband_s[slaveID];
            if (awsideband_expected_s !== awsideband_received_s) begin
              $display("ERROR: %0d - SLV AWSIDEBAND CHECKER - Slave %0d: FAIL : Received awsideband value %0h, expected awsideband value %0h", $time, slaveID, awsideband_received_s, awsideband_expected_s);
            end
            else begin
              if (test_debug) $display("DEBUG: %0d - SLV AWSIDEBAND CHECKER - Slave %0d: PASS : Received awsideband value %0h, expected awsideband value %0h", $time, slaveID, awsideband_received_s, awsideband_expected_s);
            end
          end
      end 
    end : check_sideband_signals_awsb
    join_none
`endif

`ifdef AXI_INC_ARSB

    fork 
    begin : check_sideband_signals_arsb
      reg [`AXI_AR_SBW-1:0]   arsideband_expected_s;
      reg [`AXI_AR_SBW-1:0]   arsideband_received_s;
      while (1) begin
        @(posedge `TOP.aclk);
          if (arvalid_s_bus[slaveID - 1]) begin
            arsideband_expected_s = {2{araddr_s[slaveID][`AXI_AW-1:0]}};
            arsideband_received_s = arsideband_s[slaveID];
            if (arsideband_expected_s !== arsideband_received_s) begin
              $display("ERROR: %0d - SLV ARSIDEBAND CHECKER - Slave %0d: FAIL : Received arsideband value %0h, expected arsideband value %0h", $time, slaveID, arsideband_received_s, arsideband_expected_s);
            end
            else begin
              if (test_debug) $display("DEBUG: %0d - SLV ARSIDEBAND CHECKER - Slave %0d: PASS : Received arsideband value %0h, expected arsideband value %0h", $time, slaveID, arsideband_received_s, arsideband_expected_s);
            end
          end
      end // while (1) begin
    end : check_sideband_signals_arsb
    join_none
`endif

`ifdef AXI_INC_WSB

    fork 
    begin : check_sideband_signals_wsb
      reg [`AXI_W_SBW-1:0]   wsideband_expected_s;
      reg [`AXI_W_SBW-1:0]   wsideband_received_s;
      while (1) begin
        @(posedge `TOP.aclk);
          if (wvalid_s[slaveID]) begin
            wsideband_expected_s = {8{wdata_s[slaveID][`AXI_DW-1:0]}};
            wsideband_received_s = wsideband_s[slaveID];
            if (wsideband_expected_s !== wsideband_received_s) begin
              $display("ERROR: %0d - SLV WSIDEBAND CHECKER - Slave %0d: FAIL : Received wsideband value %0h, expected wsideband value %0h", $time, slaveID, wsideband_received_s, wsideband_expected_s);
            end
            else begin
              if (test_debug) $display("DEBUG: %0d - SLV WSIDEBAND CHECKER - Slave %0d: PASS : Received wsideband value %0h, expected wsideband value %0h", $time, slaveID, wsideband_received_s, wsideband_expected_s);
            end
          end
      end // while (1) begin
    end : check_sideband_signals_wsb
    join_none
`endif

  end
endtask : check_aw_ar_w_sideband_signals

// ------------------------------------------------------------------------------------------------------------------------------------

/** 
  * Checker for sideband signals. The sideband signals are just pass through in the interconnect
  *   For BSB - bid value is replicated on bsideband bus
  *   For RSB - rdata value is replicated on the bus
  */
task automatic check_b_r_sideband_signals;
  input [31:0] masterID;
  begin
`ifdef AXI_INC_BSB

    fork 
    begin : check_sideband_signals_bsb
      reg [`AXI_B_SBW-1:0]   bsideband_expected_m;
      reg [`AXI_B_SBW-1:0]   bsideband_received_m;
      while (1) begin
        @(posedge `TOP.aclk);
          if (bvalid_m[masterID]) begin
            bsideband_expected_m = {64{bid_m[masterID][`AXI_MIDW-1:0]}};
            bsideband_received_m = bsideband_m[masterID];
            // additionally check for response value to distingiush the response comming from default slave,
            //  default slave will not drive sideband, hence the value will not match if the response is from default slave
            if ((bsideband_expected_m !== bsideband_received_m) && (bresp_m[masterID] !== 3)) begin
              $display("ERROR: %0d - MSTR BSIDEBAND CHECKER - Master %0d: FAIL : Received bsideband value %0h, expected bsideband value %0h", $time, masterID, bsideband_received_m, bsideband_expected_m);
            end
            else begin
              if (test_debug) $display("DEBUG: %0d - MSTR BSIDEBAND CHECKER - Master %0d: PASS : Received bsideband value %0h, expected bsideband value %0h, bresp = 'b%0b", $time, masterID, bsideband_received_m, bsideband_expected_m, bresp_m[masterID]);
            end
          end
      end // while (1) begin
    end : check_sideband_signals_bsb
    join_none
`endif

`ifdef AXI_INC_RSB

    fork 
    begin : check_sideband_signals_rsb
      reg [`AXI_R_SBW-1:0]   rsideband_expected_m;
      reg [`AXI_R_SBW-1:0]   rsideband_received_m;
      while (1) begin
        @(posedge `TOP.aclk);
          if (rvalid_m[masterID]) begin
            rsideband_expected_m = {8{rdata_m[masterID][`AXI_DW-1:0]}};
            rsideband_received_m = rsideband_m[masterID];
            // additionally check for response value to distingiush the response comming from default slave,
            //  default slave will not drive sideband, hence the value will not match if the response is from default slave
            if ((rsideband_expected_m !== rsideband_received_m) && (bresp_m[masterID] !== 3)) begin
              $display("ERROR: %0d - MSTR RSIDEBAND CHECKER - Master %0d: FAIL : Received rsideband value %0h, expected rsideband value %0h", $time, masterID, rsideband_received_m, rsideband_expected_m);
            end
            else begin
              if (test_debug) $display("DEBUG: %0d - MSTR RSIDEBAND CHECKER - Master %0d: PASS : Received rsideband value %0h, expected rsideband value %0h, bresp = 'b%0b", $time, masterID, rsideband_received_m, rsideband_expected_m, bresp_m[masterID]);
            end
          end
      end // while (1) begin
    end : check_sideband_signals_rsb
    join_none
`endif
  end
endtask : check_b_r_sideband_signals

// ------------------------------------------------------------------------------------------------------------------------------------

`endif //TB_CHECKER_V

