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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/sim/test_svte_axi/test.sv#1 $ 
//------------------------------------------------------------------------

`ifndef TEST_V

`define TEST_V

/** 
  * This is main module from which all the traffic is initiated.
  *  -- If QOS is enabled, then qos registers are programmed firstly.
  *  -- Since slave needs to be reactive respond to the incoming requests, 
  *     slave response thread is forked off.
  *  -- All the individual tests are called sequentially one after the other.
  */ 
module test;

  /** 
    * This task will be called from the top-level file test_DW_axi.v, which triggers
    * the start of test 
    */
  task run_test;
    integer i;  
    begin

      /**
       * If QOS is enabled, then program QOS registers for all Masters
       */
      `ifdef AXI_QOS

        for (i=1;i<=`AXI_NUM_MASTERS;i++) begin
          `TOP.qos_programming(i);  
        end
      `endif    

      /** Call the task to fork off slave random responses */
      `TOP.slaves_rand_response;

      /**
        * Generate traffic from a randomly selected Master to
        * a randomly selected slave.
        */
      `TOP.single_master_single_slave_test;

      /**
        * Generate traffic from all the Masters to 
        * all visible slaves.
        */
      `TOP.multi_master_multi_slave_test;

      /** 
        * Generate traffic targetting the address 
        * to default slave.
        */
      `TOP.default_slave_unaligned_addr_test(1);

      /** 
        * Generate unaligned transfers from a ranomly selected Master
        * to a randomly selected Slave. 
        */
      `TOP.default_slave_unaligned_addr_test(2);
     
      /** Generate exclusive access transfers*/
      `TOP.exclusive_test;
     
      
      /** Low Power test - Enabled based on parameter */
      `ifdef AXI_HAS_LOWPWR_HS_IF

        `TOP.axi_low_power_test;
        `TOP.axi_low_power_test_star9000792946;
      `endif

      /** Allow the system to be idle before completing simulation */ 
      repeat (1000) @(posedge `TOP.system_clk);
    end
  endtask

//------------------------------------------------------------------------

endmodule

`endif // TEST_V
