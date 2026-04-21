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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/sim/testbench/sim_svte/tb_common_macros.sv#1 $ 
//------------------------------------------------------------------------

/**
 * This file is intended to be included at places
 *   where common macros are used in the code.
 */

`ifndef TB_COMMON_MACROS_V

`define TB_COMMON_MACROS_V

/**
 * Top module name
 */
`define TOP test_DW_axi

/**
 * Defines used by various VIP methods and macros.
 */
`define INFO_SEV     0
`define WARNING_SEV  1
`define ERROR_SEV    2
`define FATAL_SEV    3

/**
 * Defines used by testbench methods and macros.
 */
`define SIM_SLVERR                            4
`define SIM_SLVERR_RND                        1
`define SIM_NOSLVERR                          0

`define SIM_BURST_SINGLE                      1
`define SIM_BURST_RND                         2
`define SIM_BURST_INCR_16                     3

`define SIM_WRITE                             1
`define SIM_READ                              0
`define SIM_RW_RND                            2

`define SIM_SECURE                            0
`define SIM_UNSECURE                          1
`define SIM_SECURE_RND                        2

`define SIM_EXCLUSIVE                         1
`define SIM_LOCK                              2
`define SIM_UNLOCK                            0
`define SIM_LOCK_RND                          4

`define SIM_RESP_RAND                         4

//------------------------------------------------------------------------

// -- VIP Utility macros.

`define CHECK_IS_VALID(is_valid,expisvalid,failaction,msgstr) \
  if (is_valid != expisvalid) begin \
    if (failaction == `FATAL_SEV) begin \
      $display("%m: FATAL - %s - Aborting Simulation...",msgstr); $finish; \
    end \
    else if (failaction == `ERROR_SEV) begin \
      $display ("%m: ERROR - %s",msgstr); \
    end \
    else if (failaction == `WARNING_SEV) begin \
      $display ("%m: WARNING - %s",msgstr); \
    end \
    else if (failaction == `INFO_SEV) begin \
      $display ("%m: INFO - %s",msgstr); \
    end \
  end


`endif // TB_COMMON_MACROS_V
