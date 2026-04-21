/* --------------------------------------------------------------------
**
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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/sim/testbench/sim_svte/apb_if.sv#1 $ 
**
** --------------------------------------------------------------------
**
** File     : ./apb_if.sv
** Created  : Wed Jul 20 00:36:35 MEST 2011
** Abstract :
**
** --------------------------------------------------------------------
*/


`ifndef GUARD_APB_IF_V

`define GUARD_APB_IF_V

`ifdef AXI_QOS

interface apb_if(input bit pclk);
   logic  [`APB_ADDR_WIDTH-1:0] paddr;
   logic                        psel;
   logic                        penable;
   logic                        pwrite;
   logic  [`APB_DATA_WIDTH-1:0] prdata;
   logic  [`APB_DATA_WIDTH-1:0] pwdata;

  initial begin
    paddr   = 0;
    psel    = 0;
    penable = 0;
    pwrite  = 0;
    pwdata  = 0;
  end

  /**
   * Clocking block for APB Master.
   */
  clocking master_cb @(posedge pclk);
    default input #1 output #1;
    output paddr, psel, penable, pwrite, pwdata;
    input  prdata;
  endclocking: master_cb

  /**
   * Clocking block for APB Slave.
   */
  clocking slave_cb @(posedge pclk);
    default input #1 output #1;
    input  paddr, psel, penable, pwrite, pwdata;
    output prdata;
  endclocking: slave_cb

  /**
   * Clocking block for APB Monitor.
   */
  clocking mon_cb @(posedge pclk);
    default input #1;
    input paddr, psel, penable, pwrite, prdata, pwdata;
  endclocking: mon_cb

  /** Modports for Master, Slave and Monitor */
  modport master(clocking master_cb);
  modport slave(clocking slave_cb);
  modport passive(clocking mon_cb);

endinterface: apb_if
`endif

`endif // GUARD_APB_IF_V
