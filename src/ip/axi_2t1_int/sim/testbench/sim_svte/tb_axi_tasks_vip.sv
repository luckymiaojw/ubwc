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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/sim/testbench/sim_svte/tb_axi_tasks_vip.sv#1 $ 
//------------------------------------------------------------------------

`ifndef TB_AXI_TASKS_VIP_V

`define TB_AXI_TASKS_VIP_V

/**
 * Utility task to check if a bit is as expected. Use this to check is_valid 
 * after calling a command that returns an is_valid value.
 *
 * @param is_valid       : Input bit to be checked for expected value.
 * @param exp_is_valid   : Expected value of input bit.
 *                         A value of -1 indicates that is_valid is a don't care.
 * @param msgstr         : String that will be displayed inside the message.
 *                         This can be used to identify what caused the is_valid to be not expected.
 * @param failaction     : Flag indicating if is_valid not matching with exp_is_valid is a fatal condition. 
 *                         Use defines `FATAL_SEV , `ERROR_SEV and `WARNING_SEV.
 */
task check_for_expected;
  input         reg is_valid;
  input         int exp_is_valid;
  input         reg [80*8:0] msgstr;
  input         reg [1:0] failaction;
  begin
    if ((exp_is_valid != -1) && (is_valid != exp_is_valid)) begin
      $display($time,"%m: %s - is_valid is %0b, expected %0d (%0s)",
               (failaction == `FATAL_SEV) ? "FATAL" : (failaction == `ERROR_SEV) ? "ERROR" : "WARNING",
                is_valid, exp_is_valid, msgstr);
      if (failaction == `FATAL_SEV) begin
        $display($time,"%m: FATAL - Aborting Simulation ...");
        $finish;
      end
    end
  end
endtask : check_for_expected

/**
 * Utility task to check if a bit is 1. Use this to check is_valid after 
 * calling a command that returns an is_valid value.
 *
 * @param is_valid   : Input bit to be checked if it is 1.
 * @param msgstr     : String that will be displayed inside the message.
 * @param failaction : Flag indicating if is_valid = 0 is a fatal condition. 
 *   Use defines `FATAL_SEV , `ERROR_SEV and `WARNING_SEV.
 */
task check_for_1;
  input         reg is_valid;
  input         reg [80*8:0] msgstr;
  input         reg [1:0] failaction;
  begin
    check_for_expected(is_valid, 1, msgstr, failaction);
  end
endtask : check_for_1

// ----------------------------------------------------------------------------------------------------
/**
 * Used to start the VIP transactor
 *
 * @param transactor   : The string corresponding to VIP instance of the `TOP.
 * @param xactor_id     : The transactor number, ex: 1 corresponds to master[1] or slave[1] or master_passive[1] or slave_passive[1].
 */
task automatic vip_start;
  input       reg [80*8:0] transactor;
  input       integer xactor_id;
  begin
    if (transactor == "master") begin
      case (xactor_id)
`ifdef AXI_HAS_M1

        1:`TOP.axi_master[1].start();
`endif
`ifdef AXI_HAS_M2

        2:`TOP.axi_master[2].start();
`endif
`ifdef AXI_HAS_M3

        3:`TOP.axi_master[3].start();
`endif
`ifdef AXI_HAS_M4

        4:`TOP.axi_master[4].start();
`endif
`ifdef AXI_HAS_M5

        5:`TOP.axi_master[5].start();
`endif
`ifdef AXI_HAS_M6

        6:`TOP.axi_master[6].start();
`endif
`ifdef AXI_HAS_M7

        7:`TOP.axi_master[7].start();
`endif
`ifdef AXI_HAS_M8

        8:`TOP.axi_master[8].start();
`endif
`ifdef AXI_HAS_M9

        9:`TOP.axi_master[9].start();
`endif
`ifdef AXI_HAS_M10

       10:`TOP.axi_master[10].start();
`endif
`ifdef AXI_HAS_M11

       11:`TOP.axi_master[11].start();
`endif
`ifdef AXI_HAS_M12

       12:`TOP.axi_master[12].start();
`endif
`ifdef AXI_HAS_M13

       13:`TOP.axi_master[13].start();
`endif
`ifdef AXI_HAS_M14

       14:`TOP.axi_master[14].start();
`endif
`ifdef AXI_HAS_M15

       15:`TOP.axi_master[15].start();
`endif
`ifdef AXI_HAS_M16

       16:`TOP.axi_master[16].start();
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end 
    else if (transactor == "slave") begin
      case (xactor_id)
`ifdef AXI_HAS_S1

        1:`TOP.axi_slave[1].start();
`endif
`ifdef AXI_HAS_S2

        2:`TOP.axi_slave[2].start();
`endif
`ifdef AXI_HAS_S3

        3:`TOP.axi_slave[3].start();
`endif
`ifdef AXI_HAS_S4

        4:`TOP.axi_slave[4].start();
`endif
`ifdef AXI_HAS_S5

        5:`TOP.axi_slave[5].start();
`endif
`ifdef AXI_HAS_S6

        6:`TOP.axi_slave[6].start();
`endif
`ifdef AXI_HAS_S7

        7:`TOP.axi_slave[7].start();
`endif
`ifdef AXI_HAS_S8

        8:`TOP.axi_slave[8].start();
`endif
`ifdef AXI_HAS_S9

        9:`TOP.axi_slave[9].start();
`endif
`ifdef AXI_HAS_S10

       10:`TOP.axi_slave[10].start();
`endif
`ifdef AXI_HAS_S11

       11:`TOP.axi_slave[11].start();
`endif
`ifdef AXI_HAS_S12

       12:`TOP.axi_slave[12].start();
`endif
`ifdef AXI_HAS_S13

       13:`TOP.axi_slave[13].start();
`endif
`ifdef AXI_HAS_S14

       14:`TOP.axi_slave[14].start();
`endif
`ifdef AXI_HAS_S15

       15:`TOP.axi_slave[15].start();
`endif
`ifdef AXI_HAS_S16

       16:`TOP.axi_slave[16].start();
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end
//    else if (transactor == "master_passive") begin
//      case (xactor_id)
//`ifdef AXI_HAS_M1
//        1:`TOP.axi_master_passive[1].start();
//`endif
//`ifdef AXI_HAS_M2
//        2:`TOP.axi_master_passive[2].start();
//`endif
//`ifdef AXI_HAS_M3
//        3:`TOP.axi_master_passive[3].start();
//`endif
//`ifdef AXI_HAS_M4
//        4:`TOP.axi_master_passive[4].start();
//`endif
//`ifdef AXI_HAS_M5
//        5:`TOP.axi_master_passive[5].start();
//`endif
//`ifdef AXI_HAS_M6
//        6:`TOP.axi_master_passive[6].start();
//`endif
//`ifdef AXI_HAS_M7
//        7:`TOP.axi_master_passive[7].start();
//`endif
//`ifdef AXI_HAS_M8
//        8:`TOP.axi_master_passive[8].start();
//`endif
//`ifdef AXI_HAS_M9
//        9:`TOP.axi_master_passive[9].start();
//`endif
//`ifdef AXI_HAS_M10
//       10:`TOP.axi_master_passive[10].start();
//`endif
//`ifdef AXI_HAS_M11
//       11:`TOP.axi_master_passive[11].start();
//`endif
//`ifdef AXI_HAS_M12
//       12:`TOP.axi_master_passive[12].start();
//`endif
//`ifdef AXI_HAS_M13
//       13:`TOP.axi_master_passive[13].start();
//`endif
//`ifdef AXI_HAS_M14
//       14:`TOP.axi_master_passive[14].start();
//`endif
//`ifdef AXI_HAS_M15
//       15:`TOP.axi_master_passive[15].start();
//`endif
//`ifdef AXI_HAS_M16
//       16:`TOP.axi_master_passive[16].start();
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//    end 
//    else if (transactor == "slave_passive") begin
//
//      case (xactor_id)
//`ifdef AXI_HAS_S1
//        1:`TOP.axi_slave_passive[1].start();
//`endif
//`ifdef AXI_HAS_S2
//        2:`TOP.axi_slave_passive[2].start();
//`endif
//`ifdef AXI_HAS_S3
//        3:`TOP.axi_slave_passive[3].start();
//`endif
//`ifdef AXI_HAS_S4
//        4:`TOP.axi_slave_passive[4].start();
//`endif
//`ifdef AXI_HAS_S5
//        5:`TOP.axi_slave_passive[5].start();
//`endif
//`ifdef AXI_HAS_S6
//        6:`TOP.axi_slave_passive[6].start();
//`endif
//`ifdef AXI_HAS_S7
//        7:`TOP.axi_slave_passive[7].start();
//`endif
//`ifdef AXI_HAS_S8
//        8:`TOP.axi_slave_passive[8].start();
//`endif
//`ifdef AXI_HAS_S9
//        9:`TOP.axi_slave_passive[9].start();
//`endif
//`ifdef AXI_HAS_S10
//       10:`TOP.axi_slave_passive[10].start();
//`endif
//`ifdef AXI_HAS_S11
//       11:`TOP.axi_slave_passive[11].start();
//`endif
//`ifdef AXI_HAS_S12
//       12:`TOP.axi_slave_passive[12].start();
//`endif
//`ifdef AXI_HAS_S13
//       13:`TOP.axi_slave_passive[13].start();
//`endif
//`ifdef AXI_HAS_S14
//       14:`TOP.axi_slave_passive[14].start();
//`endif
//`ifdef AXI_HAS_S15
//       15:`TOP.axi_slave_passive[15].start();
//`endif
//`ifdef AXI_HAS_S16
//       16:`TOP.axi_slave_passive[16].start();
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//    end 
    else begin
      $display($time,"%m: ERROR - The input argument transactor(%0s) is not recognized.  Currently supported argument values are master and slave.",transactor);
    end
  end
endtask : vip_start

/**
 * Used to stop the module internal run phase.
 *
 * @param transactor     : The string corresponding to VIP instance of the `TOP, master or slave or master_passive or slave_passive.
 * @param xactor_id     : The transactor number, ex: 1 corresponds to master[1] or slave[1] or master_passive[1] or slave_passive[1].
 */
task automatic vip_stop;
  input       reg [80*8:0] transactor;
  input       integer xactor_id;
  begin
    if (transactor == "master") begin
      case (xactor_id)
`ifdef AXI_HAS_M1

        1:`TOP.axi_master[1].stop();
`endif
`ifdef AXI_HAS_M2

        2:`TOP.axi_master[2].stop();
`endif
`ifdef AXI_HAS_M3

        3:`TOP.axi_master[3].stop();
`endif
`ifdef AXI_HAS_M4

        4:`TOP.axi_master[4].stop();
`endif
`ifdef AXI_HAS_M5

        5:`TOP.axi_master[5].stop();
`endif
`ifdef AXI_HAS_M6

        6:`TOP.axi_master[6].stop();
`endif
`ifdef AXI_HAS_M7

        7:`TOP.axi_master[7].stop();
`endif
`ifdef AXI_HAS_M8

        8:`TOP.axi_master[8].stop();
`endif
`ifdef AXI_HAS_M9

        9:`TOP.axi_master[9].stop();
`endif
`ifdef AXI_HAS_M10

       10:`TOP.axi_master[10].stop();
`endif
`ifdef AXI_HAS_M11

       11:`TOP.axi_master[11].stop();
`endif
`ifdef AXI_HAS_M12

       12:`TOP.axi_master[12].stop();
`endif
`ifdef AXI_HAS_M13

       13:`TOP.axi_master[13].stop();
`endif
`ifdef AXI_HAS_M14

       14:`TOP.axi_master[14].stop();
`endif
`ifdef AXI_HAS_M15

       15:`TOP.axi_master[15].stop();
`endif
`ifdef AXI_HAS_M16

       16:`TOP.axi_master[16].stop();
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
     endcase
    end 
    else if (transactor == "slave") begin
      case (xactor_id)
`ifdef AXI_HAS_S1

        1:`TOP.axi_slave[1].stop();
`endif
`ifdef AXI_HAS_S2

        2:`TOP.axi_slave[2].stop();
`endif
`ifdef AXI_HAS_S3

        3:`TOP.axi_slave[3].stop();
`endif
`ifdef AXI_HAS_S4

        4:`TOP.axi_slave[4].stop();
`endif
`ifdef AXI_HAS_S5

        5:`TOP.axi_slave[5].stop();
`endif
`ifdef AXI_HAS_S6

        6:`TOP.axi_slave[6].stop();
`endif
`ifdef AXI_HAS_S7

        7:`TOP.axi_slave[7].stop();
`endif
`ifdef AXI_HAS_S8

        8:`TOP.axi_slave[8].stop();
`endif
`ifdef AXI_HAS_S9

        9:`TOP.axi_slave[9].stop();
`endif
`ifdef AXI_HAS_S10

       10:`TOP.axi_slave[10].stop();
`endif
`ifdef AXI_HAS_S11

       11:`TOP.axi_slave[11].stop();
`endif
`ifdef AXI_HAS_S12

       12:`TOP.axi_slave[12].stop();
`endif
`ifdef AXI_HAS_S13

       13:`TOP.axi_slave[13].stop();
`endif
`ifdef AXI_HAS_S14

       14:`TOP.axi_slave[14].stop();
`endif
`ifdef AXI_HAS_S15

       15:`TOP.axi_slave[15].stop();
`endif
`ifdef AXI_HAS_S16

       16:`TOP.axi_slave[16].stop();
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
     endcase

    end
//    else if (transactor == "master_passive") begin
//      case (xactor_id)
//`ifdef AXI_HAS_M1
//        1:`TOP.axi_master_passive[1].stop();
//`endif
//`ifdef AXI_HAS_M2
//        2:`TOP.axi_master_passive[2].stop();
//`endif
//`ifdef AXI_HAS_M3
//        3:`TOP.axi_master_passive[3].stop();
//`endif
//`ifdef AXI_HAS_M4
//        4:`TOP.axi_master_passive[4].stop();
//`endif
//`ifdef AXI_HAS_M5
//        5:`TOP.axi_master_passive[5].stop();
//`endif
//`ifdef AXI_HAS_M6
//        6:`TOP.axi_master_passive[6].stop();
//`endif
//`ifdef AXI_HAS_M7
//        7:`TOP.axi_master_passive[7].stop();
//`endif
//`ifdef AXI_HAS_M8
//        8:`TOP.axi_master_passive[8].stop();
//`endif
//`ifdef AXI_HAS_M9
//        9:`TOP.axi_master_passive[9].stop();
//`endif
//`ifdef AXI_HAS_M10
//       10:`TOP.axi_master_passive[10].stop();
//`endif
//`ifdef AXI_HAS_M11
//       11:`TOP.axi_master_passive[11].stop();
//`endif
//`ifdef AXI_HAS_M12
//       12:`TOP.axi_master_passive[12].stop();
//`endif
//`ifdef AXI_HAS_M13
//       13:`TOP.axi_master_passive[13].stop();
//`endif
//`ifdef AXI_HAS_M14
//       14:`TOP.axi_master_passive[14].stop();
//`endif
//`ifdef AXI_HAS_M15
//       15:`TOP.axi_master_passive[15].stop();
//`endif
//`ifdef AXI_HAS_M16
//       16:`TOP.axi_master_passive[16].stop();
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//     endcase
//
//    end 
//    else if (transactor == "slave_passive") begin
//      case (xactor_id)
//`ifdef AXI_HAS_S1
//        1:`TOP.axi_slave_passive[1].stop();
//`endif
//`ifdef AXI_HAS_S2
//        2:`TOP.axi_slave_passive[2].stop();
//`endif
//`ifdef AXI_HAS_S3
//        3:`TOP.axi_slave_passive[3].stop();
//`endif
//`ifdef AXI_HAS_S4
//        4:`TOP.axi_slave_passive[4].stop();
//`endif
//`ifdef AXI_HAS_S5
//        5:`TOP.axi_slave_passive[5].stop();
//`endif
//`ifdef AXI_HAS_S6
//        6:`TOP.axi_slave_passive[6].stop();
//`endif
//`ifdef AXI_HAS_S7
//        7:`TOP.axi_slave_passive[7].stop();
//`endif
//`ifdef AXI_HAS_S8
//        8:`TOP.axi_slave_passive[8].stop();
//`endif
//`ifdef AXI_HAS_S9
//        9:`TOP.axi_slave_passive[9].stop();
//`endif
//`ifdef AXI_HAS_S10
//       10:`TOP.axi_slave_passive[10].stop();
//`endif
//`ifdef AXI_HAS_S11
//       11:`TOP.axi_slave_passive[11].stop();
//`endif
//`ifdef AXI_HAS_S12
//       12:`TOP.axi_slave_passive[12].stop();
//`endif
//`ifdef AXI_HAS_S13
//       13:`TOP.axi_slave_passive[13].stop();
//`endif
//`ifdef AXI_HAS_S14
//       14:`TOP.axi_slave_passive[14].stop();
//`endif
//`ifdef AXI_HAS_S15
//       15:`TOP.axi_slave_passive[15].stop();
//`endif
//`ifdef AXI_HAS_S16
//       16:`TOP.axi_slave_passive[16].stop();
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//     endcase
//
//    end 
    else begin
      $display($time,"%m: ERROR - The input argument transactor(%0s) is not recognized.  Currently supported argument values are master and slave.",transactor);
    end
  end
endtask : vip_stop

/**
 * Utility method to call new_data for a specific VIP instance
 *
 * @param transactor   : The string corresponding to VIP instance of the `TOP, master or slave or master_passive or slave_passive.
 * @param xactor_id   : The transactor number, ex: 1 corresponds to master[1] or slave[1] or master_passive[1] or slave_passive[1].
 * @param data_type    : Handle to object type to be created in VIP instance.
 * @param handle       : Handle to point object of VIP instance.
 *
 */
task automatic vip_new_data;
  input       reg [80*8:0] transactor;
  input       integer xactor_id;
`ifdef SVT_MULTI_SIM_STRING_ARG_IN_EXPORTED_METHODS

  input       reg [80*8:0] datatype;
`else
  input       string       datatype;
`endif
  output      integer handle;
  reg         is_valid;
  reg [80*8:0] msgstr;
  begin
    if (transactor == "master") begin
      case(xactor_id)
`ifdef AXI_HAS_M1

        1:`TOP.axi_master[1].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M2

        2:`TOP.axi_master[2].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M3

        3:`TOP.axi_master[3].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M4

        4:`TOP.axi_master[4].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M5

        5:`TOP.axi_master[5].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M6

        6:`TOP.axi_master[6].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M7

        7:`TOP.axi_master[7].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M8

        8:`TOP.axi_master[8].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M9

        9:`TOP.axi_master[9].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M10

       10:`TOP.axi_master[10].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M11

       11:`TOP.axi_master[11].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M12

       12:`TOP.axi_master[12].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M13

       13:`TOP.axi_master[13].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M14

       14:`TOP.axi_master[14].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M15

       15:`TOP.axi_master[15].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_M16

       16:`TOP.axi_master[16].new_data(is_valid, handle, datatype);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end 
    else if (transactor == "slave") begin
      case(xactor_id)
`ifdef AXI_HAS_S1

        1:`TOP.axi_slave[1].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S2

        2:`TOP.axi_slave[2].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S3

        3:`TOP.axi_slave[3].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S4

        4:`TOP.axi_slave[4].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S5

        5:`TOP.axi_slave[5].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S6

        6:`TOP.axi_slave[6].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S7

        7:`TOP.axi_slave[7].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S8

        8:`TOP.axi_slave[8].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S9

        9:`TOP.axi_slave[9].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S10

       10:`TOP.axi_slave[10].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S11

       11:`TOP.axi_slave[11].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S12

       12:`TOP.axi_slave[12].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S13

       13:`TOP.axi_slave[13].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S14

       14:`TOP.axi_slave[14].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S15

       15:`TOP.axi_slave[15].new_data(is_valid, handle, datatype);
`endif
`ifdef AXI_HAS_S16

       16:`TOP.axi_slave[16].new_data(is_valid, handle, datatype);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end
//    else if (transactor == "master_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_M1
//        1:`TOP.axi_master_passive[1].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M2
//        2:`TOP.axi_master_passive[2].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M3
//        3:`TOP.axi_master_passive[3].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M4
//        4:`TOP.axi_master_passive[4].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M5
//        5:`TOP.axi_master_passive[5].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M6
//        6:`TOP.axi_master_passive[6].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M7
//        7:`TOP.axi_master_passive[7].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M8
//        8:`TOP.axi_master_passive[8].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M9
//        9:`TOP.axi_master_passive[9].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M10
//       10:`TOP.axi_master_passive[10].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M11
//       11:`TOP.axi_master_passive[11].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M12
//       12:`TOP.axi_master_passive[12].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M13
//       13:`TOP.axi_master_passive[13].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M14
//       14:`TOP.axi_master_passive[14].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M15
//       15:`TOP.axi_master_passive[15].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_M16
//       16:`TOP.axi_master_passive[16].new_data(is_valid, handle, datatype);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//    end 
//    else if (transactor == "slave_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_S1
//        1:`TOP.axi_slave_passive[1].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S2
//        2:`TOP.axi_slave_passive[2].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S3
//        3:`TOP.axi_slave_passive[3].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S4
//        4:`TOP.axi_slave_passive[4].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S5
//        5:`TOP.axi_slave_passive[5].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S6
//        6:`TOP.axi_slave_passive[6].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S7
//        7:`TOP.axi_slave_passive[7].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S8
//        8:`TOP.axi_slave_passive[8].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S9
//        9:`TOP.axi_slave_passive[9].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S10
//       10:`TOP.axi_slave_passive[10].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S11
//       11:`TOP.axi_slave_passive[11].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S12
//       12:`TOP.axi_slave_passive[12].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S13
//       13:`TOP.axi_slave_passive[13].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S14
//       14:`TOP.axi_slave_passive[14].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S15
//       15:`TOP.axi_slave_passive[15].new_data(is_valid, handle, datatype);
//`endif
//`ifdef AXI_HAS_S16
//       16:`TOP.axi_slave_passive[16].new_data(is_valid, handle, datatype);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//    end 
    else begin
      $display($time,"%m: ERROR - The input argument transactor(%0s) is not recognized.  Currently supported argument values are master and slave.",transactor);
      return;
    end
    $swrite(msgstr, "%0s.new_data(is_valid, handle, datatype",transactor);
    check_for_1(is_valid, msgstr, `ERROR_SEV);
  end
endtask : vip_new_data

/**
 * Utility method to call apply_data for a specific VIP instance
 * @param transactor   : The string corresponding to VIP instance of the `TOP, master or slave or master_passive or slave_passive.
 * @param xactor_id   : The transactor number, ex: 1 corresponds to master[1] or slave[1] or master_passive[1] or slave_passive[1].
 * @param handle       : Handle to point object of VIP instance.
 */
task automatic vip_apply_data;
  input       reg [80*8:0] transactor;
  input       integer xactor_id;
  input       integer handle;
  reg         is_valid;
  reg [80*8:0] msgstr;
  begin
    if (transactor == "master") begin
      case(xactor_id)
`ifdef AXI_HAS_M1

        1:`TOP.axi_master[1].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M2

        2:`TOP.axi_master[2].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M3

        3:`TOP.axi_master[3].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M4

        4:`TOP.axi_master[4].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M5

        5:`TOP.axi_master[5].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M6

        6:`TOP.axi_master[6].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M7

        7:`TOP.axi_master[7].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M8

        8:`TOP.axi_master[8].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M9

        9:`TOP.axi_master[9].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M10

       10:`TOP.axi_master[10].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M11

       11:`TOP.axi_master[11].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M12

       12:`TOP.axi_master[12].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M13

       13:`TOP.axi_master[13].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M14

       14:`TOP.axi_master[14].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M15

       15:`TOP.axi_master[15].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_M16

       16:`TOP.axi_master[16].apply_data(is_valid, handle, 1);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end 
    else if (transactor == "slave") begin
      case(xactor_id)
`ifdef AXI_HAS_S1

        1:`TOP.axi_slave[1].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S2

        2:`TOP.axi_slave[2].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S3

        3:`TOP.axi_slave[3].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S4

        4:`TOP.axi_slave[4].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S5

        5:`TOP.axi_slave[5].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S6

        6:`TOP.axi_slave[6].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S7

        7:`TOP.axi_slave[7].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S8

        8:`TOP.axi_slave[8].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S9

        9:`TOP.axi_slave[9].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S10

       10:`TOP.axi_slave[10].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S11

       11:`TOP.axi_slave[11].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S12

       12:`TOP.axi_slave[12].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S13

       13:`TOP.axi_slave[13].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S14

       14:`TOP.axi_slave[14].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S15

       15:`TOP.axi_slave[15].apply_data(is_valid, handle, 1);
`endif
`ifdef AXI_HAS_S16

       16:`TOP.axi_slave[16].apply_data(is_valid, handle, 1);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end
//    else if (transactor == "master_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_M1
//        1:`TOP.axi_master_passive[1].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M2
//        2:`TOP.axi_master_passive[2].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M3
//        3:`TOP.axi_master_passive[3].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M4
//        4:`TOP.axi_master_passive[4].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M5
//        5:`TOP.axi_master_passive[5].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M6
//        6:`TOP.axi_master_passive[6].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M7
//        7:`TOP.axi_master_passive[7].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M8
//        8:`TOP.axi_master_passive[8].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M9
//        9:`TOP.axi_master_passive[9].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M10
//       10:`TOP.axi_master_passive[10].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M11
//       11:`TOP.axi_master_passive[11].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M12
//       12:`TOP.axi_master_passive[12].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M13
//       13:`TOP.axi_master_passive[13].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M14
//       14:`TOP.axi_master_passive[14].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M15
//       15:`TOP.axi_master_passive[15].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_M16
//       16:`TOP.axi_master_passive[16].apply_data(is_valid, handle, 1);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//    end 
//    else if (transactor == "slave_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_S1
//        1:`TOP.axi_slave_passive[1].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S2
//        2:`TOP.axi_slave_passive[2].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S3
//        3:`TOP.axi_slave_passive[3].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S4
//        4:`TOP.axi_slave_passive[4].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S5
//        5:`TOP.axi_slave_passive[5].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S6
//        6:`TOP.axi_slave_passive[6].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S7
//        7:`TOP.axi_slave_passive[7].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S8
//        8:`TOP.axi_slave_passive[8].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S9
//        9:`TOP.axi_slave_passive[9].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S10
//       10:`TOP.axi_slave_passive[10].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S11
//       11:`TOP.axi_slave_passive[11].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S12
//       12:`TOP.axi_slave_passive[12].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S13
//       13:`TOP.axi_slave_passive[13].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S14
//       14:`TOP.axi_slave_passive[14].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S15
//       15:`TOP.axi_slave_passive[15].apply_data(is_valid, handle, 1);
//`endif
//`ifdef AXI_HAS_S16
//       16:`TOP.axi_slave_passive[16].apply_data(is_valid, handle, 1);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//    end 
    else begin
      $display($time,"%m: ERROR - The input argument transactor(%0s) is not recognized.  Currently supported argument values are master and slave.",transactor);
      return;
    end
    $swrite(msgstr, "%0s.apply_data(is_valid, handle, 1",transactor);
    check_for_1(is_valid, msgstr, `ERROR_SEV);
  end
endtask : vip_apply_data

/**
 * Utility method to call delete_data for a specific VIP instance 
 *
 * @param transactor   : The string corresponding to VIP instance of the `TOP, master or slave or master_passive or slave_passive.
 * @param xactor_id   : The transactor number, ex: 1 corresponds to master[1] or slave[1] or master_passive[1] or slave_passive[1].
 * @param handle       : Handle to point object of VIP instance.
 *
 */
task automatic vip_delete_data;
  input       reg [80*8:0] transactor;
  input       integer xactor_id;
  input       integer handle;
  reg         is_valid;
  reg [80*8:0] msgstr;
  begin
    if (transactor == "master") begin
      case(xactor_id)
`ifdef AXI_HAS_M1

        1:`TOP.axi_master[1].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M2

        2:`TOP.axi_master[2].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M3

        3:`TOP.axi_master[3].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M4

        4:`TOP.axi_master[4].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M5

        5:`TOP.axi_master[5].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M6

        6:`TOP.axi_master[6].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M7

        7:`TOP.axi_master[7].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M8

        8:`TOP.axi_master[8].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M9

        9:`TOP.axi_master[9].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M10

       10:`TOP.axi_master[10].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M11

       11:`TOP.axi_master[11].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M12

       12:`TOP.axi_master[12].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M13

       13:`TOP.axi_master[13].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M14

       14:`TOP.axi_master[14].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M15

       15:`TOP.axi_master[15].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_M16

       16:`TOP.axi_master[16].delete_data(is_valid, handle);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end 
    else if (transactor == "slave") begin
      case(xactor_id)
`ifdef AXI_HAS_S1

        1:`TOP.axi_slave[1].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S2

        2:`TOP.axi_slave[2].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S3

        3:`TOP.axi_slave[3].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S4

        4:`TOP.axi_slave[4].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S5

        5:`TOP.axi_slave[5].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S6

        6:`TOP.axi_slave[6].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S7

        7:`TOP.axi_slave[7].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S8

        8:`TOP.axi_slave[8].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S9

        9:`TOP.axi_slave[9].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S10

       10:`TOP.axi_slave[10].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S11

       11:`TOP.axi_slave[11].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S12

       12:`TOP.axi_slave[12].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S13

       13:`TOP.axi_slave[13].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S14

       14:`TOP.axi_slave[14].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S15

       15:`TOP.axi_slave[15].delete_data(is_valid, handle);
`endif
`ifdef AXI_HAS_S16

       16:`TOP.axi_slave[16].delete_data(is_valid, handle);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end
//    else if (transactor == "master_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_M1
//        1:`TOP.axi_master_passive[1].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M2
//        2:`TOP.axi_master_passive[2].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M3
//        3:`TOP.axi_master_passive[3].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M4
//        4:`TOP.axi_master_passive[4].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M5
//        5:`TOP.axi_master_passive[5].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M6
//        6:`TOP.axi_master_passive[6].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M7
//        7:`TOP.axi_master_passive[7].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M8
//        8:`TOP.axi_master_passive[8].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M9
//        9:`TOP.axi_master_passive[9].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M10
//       10:`TOP.axi_master_passive[10].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M11
//       11:`TOP.axi_master_passive[11].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M12
//       12:`TOP.axi_master_passive[12].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M12
//       13:`TOP.axi_master_passive[13].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M13
//       14:`TOP.axi_master_passive[14].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M14
//       15:`TOP.axi_master_passive[15].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_M15
//       16:`TOP.axi_master_passive[16].delete_data(is_valid, handle);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//    end 
//    else if (transactor == "slave_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_S1
//        1:`TOP.axi_slave_passive[1].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S2
//        2:`TOP.axi_slave_passive[2].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S3
//        3:`TOP.axi_slave_passive[3].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S4
//        4:`TOP.axi_slave_passive[4].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S5
//        5:`TOP.axi_slave_passive[5].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S6
//        6:`TOP.axi_slave_passive[6].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S7
//        7:`TOP.axi_slave_passive[7].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S8
//        8:`TOP.axi_slave_passive[8].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S9
//        9:`TOP.axi_slave_passive[9].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S10
//       10:`TOP.axi_slave_passive[10].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S11
//       11:`TOP.axi_slave_passive[11].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S12
//       12:`TOP.axi_slave_passive[12].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S13
//       13:`TOP.axi_slave_passive[13].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S14
//       14:`TOP.axi_slave_passive[14].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S15
//       15:`TOP.axi_slave_passive[15].delete_data(is_valid, handle);
//`endif
//`ifdef AXI_HAS_S16
//       16:`TOP.axi_slave_passive[16].delete_data(is_valid, handle);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//    end 
    else begin
      $display($time,"%m: ERROR - The input argument transactor(%0s) is not recognized.  Currently supported argument values are master and slave.",transactor);
      return;
    end
    $swrite(msgstr, "%0s.delete_data(is_valid, handle, datatype",transactor);
    check_for_1(is_valid, msgstr, `ERROR_SEV);
  end
endtask : vip_delete_data

/**
 * Used to create the deep copy of active data object.
 *
 * @param transactor     : The string corresponding to VIP instance of the `TOP, master or slave or master_passive or slave_passive.
 * @param xactor_id     : The transactor number, ex: 1 corresponds to master[1] or slave[1] or master_passive[1] or slave_passive[1].
 * @param src_handle   : Handle to point object of VIP instance from which copy is made.
 * @param handle       : Handle to point object of VIP instance to which copy is made.
 */
task automatic vip_copy_data;
  input       reg [80*8:0] transactor;
  input       integer xactor_id;
  input       integer src_handle;
  output      integer handle;
  reg         is_valid;
  begin
    is_valid = 0;
    if (transactor == "master") begin
      case(xactor_id)
`ifdef AXI_HAS_M1

        1:`TOP.axi_master[1].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M2

        2:`TOP.axi_master[2].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M3

        3:`TOP.axi_master[3].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M4

        4:`TOP.axi_master[4].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M5

        5:`TOP.axi_master[5].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M6

        6:`TOP.axi_master[6].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M7

        7:`TOP.axi_master[7].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M8

        8:`TOP.axi_master[8].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M9

        9:`TOP.axi_master[9].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M10

       10:`TOP.axi_master[10].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M11

       11:`TOP.axi_master[11].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M12

       12:`TOP.axi_master[12].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M13

       13:`TOP.axi_master[13].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M14

       14:`TOP.axi_master[14].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M15

       15:`TOP.axi_master[15].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_M16

       16:`TOP.axi_master[16].copy_data(is_valid, handle, src_handle);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end 
    else if (transactor == "slave") begin
      case(xactor_id)
`ifdef AXI_HAS_S1

        1:`TOP.axi_slave[1].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S2

        2:`TOP.axi_slave[2].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S3

        3:`TOP.axi_slave[3].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S4

        4:`TOP.axi_slave[4].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S5

        5:`TOP.axi_slave[5].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S6

        6:`TOP.axi_slave[6].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S7

        7:`TOP.axi_slave[7].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S8

        8:`TOP.axi_slave[8].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S9

        9:`TOP.axi_slave[9].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S10

       10:`TOP.axi_slave[10].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S11

       11:`TOP.axi_slave[11].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S12

       12:`TOP.axi_slave[12].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S13

       13:`TOP.axi_slave[13].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S14

       14:`TOP.axi_slave[14].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S15

       15:`TOP.axi_slave[15].copy_data(is_valid, handle, src_handle);
`endif
`ifdef AXI_HAS_S16

       16:`TOP.axi_slave[16].copy_data(is_valid, handle, src_handle);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase

    end
//    else if (transactor == "master_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_M1
//        1:`TOP.axi_master_passive[1].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M2
//        2:`TOP.axi_master_passive[2].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M3
//        3:`TOP.axi_master_passive[3].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M4
//        4:`TOP.axi_master_passive[4].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M5
//        5:`TOP.axi_master_passive[5].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M6
//        6:`TOP.axi_master_passive[6].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M7
//        7:`TOP.axi_master_passive[7].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M8
//        8:`TOP.axi_master_passive[8].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M9
//        9:`TOP.axi_master_passive[9].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M10
//       10:`TOP.axi_master_passive[10].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M11
//       11:`TOP.axi_master_passive[11].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M12
//       12:`TOP.axi_master_passive[12].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M13
//       13:`TOP.axi_master_passive[13].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M14
//       14:`TOP.axi_master_passive[14].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M15
//       15:`TOP.axi_master_passive[15].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_M16
//       16:`TOP.axi_master_passive[16].copy_data(is_valid, handle, src_handle);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//
//    end 
//    else if (transactor == "slave_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_S1
//        1:`TOP.axi_slave_passive[1].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S2
//        2:`TOP.axi_slave_passive[2].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S3
//        3:`TOP.axi_slave_passive[3].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S4
//        4:`TOP.axi_slave_passive[4].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S5
//        5:`TOP.axi_slave_passive[5].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S6
//        6:`TOP.axi_slave_passive[6].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S7
//        7:`TOP.axi_slave_passive[7].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S8
//        8:`TOP.axi_slave_passive[8].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S9
//        9:`TOP.axi_slave_passive[9].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S10
//       10:`TOP.axi_slave_passive[10].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S11
//       11:`TOP.axi_slave_passive[11].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S12
//       12:`TOP.axi_slave_passive[12].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S13
//       13:`TOP.axi_slave_passive[13].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S14
//       14:`TOP.axi_slave_passive[14].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S15
//       15:`TOP.axi_slave_passive[15].copy_data(is_valid, handle, src_handle);
//`endif
//`ifdef AXI_HAS_S16
//       16:`TOP.axi_slave_passive[16].copy_data(is_valid, handle, src_handle);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//
//    end 
    else begin
      $display($time,"%m: ERROR - The input argument transactor(%0s) is not recognized.  Currently supported argument values are master and slave.",transactor);
    end
    check_for_1(is_valid, "copy for given data can not be created", `ERROR_SEV);
  end
endtask : vip_copy_data

/**
 * Utility method to call display_data for a specific VIP instance 
 *
 * @param transactor   : The string corresponding to VIP instance of the `TOP, master or slave or master_passive or slave_passive.
 * @param xactor_id   : The transactor number, ex: 1 corresponds to master[1] or slave[1] or master_passive[1] or slave_passive[1].
 * @param handle       : Handle to point object of VIP instance.
 * @param str          : This corresponds to comment to be displayed in log.
 * @param is_valid     : This flags the status of function executed 1 as success 0 as failure.
 */
task automatic vip_display_data;
  input       reg [80*8:0] transactor;
  input       integer xactor_id;
  input       integer handle;
`ifdef SVT_MULTI_SIM_STRING_ARG_IN_EXPORTED_METHODS

  input       reg [80*8:0] str;
`else
  input       string str;
`endif
  reg         is_valid;
  reg [80*8:0] msgstr;
  begin
    if (transactor == "master") begin
      case (xactor_id)
`ifdef AXI_HAS_M1

        1:`TOP.axi_master[1].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M2

        2:`TOP.axi_master[2].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M3

        3:`TOP.axi_master[3].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M4

        4:`TOP.axi_master[4].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M5

        5:`TOP.axi_master[5].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M6

        6:`TOP.axi_master[6].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M7

        7:`TOP.axi_master[7].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M8

        8:`TOP.axi_master[8].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M9

        9:`TOP.axi_master[9].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M10

       10:`TOP.axi_master[10].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M11

       11:`TOP.axi_master[11].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M12

       12:`TOP.axi_master[12].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M13

       13:`TOP.axi_master[13].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M14

       14:`TOP.axi_master[14].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M15

       15:`TOP.axi_master[15].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_M16

       16:`TOP.axi_master[16].display_data(is_valid, handle, str);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end 
    else if (transactor == "slave") begin
      case (xactor_id)
`ifdef AXI_HAS_S1

        1:`TOP.axi_slave[1].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S2

        2:`TOP.axi_slave[2].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S3

        3:`TOP.axi_slave[3].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S4

        4:`TOP.axi_slave[4].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S5

        5:`TOP.axi_slave[5].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S6

        6:`TOP.axi_slave[6].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S7

        7:`TOP.axi_slave[7].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S8

        8:`TOP.axi_slave[8].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S9

        9:`TOP.axi_slave[9].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S10

       10:`TOP.axi_slave[10].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S11

       11:`TOP.axi_slave[11].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S12

       12:`TOP.axi_slave[12].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S13

       13:`TOP.axi_slave[13].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S14

       14:`TOP.axi_slave[14].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S15

       15:`TOP.axi_slave[15].display_data(is_valid, handle, str);
`endif
`ifdef AXI_HAS_S16

       16:`TOP.axi_slave[16].display_data(is_valid, handle, str);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end
//    else if (transactor == "master_passive") begin
//      case (xactor_id)
//`ifdef AXI_HAS_M1
//        1:`TOP.axi_master_passive[1].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M2
//        2:`TOP.axi_master_passive[2].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M3
//        3:`TOP.axi_master_passive[3].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M4
//        4:`TOP.axi_master_passive[4].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M5
//        5:`TOP.axi_master_passive[5].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M6
//        6:`TOP.axi_master_passive[6].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M7
//        7:`TOP.axi_master_passive[7].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M8
//        8:`TOP.axi_master_passive[8].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M9
//        9:`TOP.axi_master_passive[9].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M10
//       10:`TOP.axi_master_passive[10].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M11
//       11:`TOP.axi_master_passive[11].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M12
//       12:`TOP.axi_master_passive[12].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M13
//       13:`TOP.axi_master_passive[13].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M14
//       14:`TOP.axi_master_passive[14].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M15
//       15:`TOP.axi_master_passive[15].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_M16
//       16:`TOP.axi_master_passive[16].display_data(is_valid, handle, str);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//    end 
//    else if (transactor == "slave_passive") begin
//      case (xactor_id)
//`ifdef AXI_HAS_S1
//        1:`TOP.axi_slave_passive[1].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S2
//        2:`TOP.axi_slave_passive[2].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S3
//        3:`TOP.axi_slave_passive[3].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S4
//        4:`TOP.axi_slave_passive[4].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S5
//        5:`TOP.axi_slave_passive[5].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S6
//        6:`TOP.axi_slave_passive[6].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S7
//        7:`TOP.axi_slave_passive[7].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S8
//        8:`TOP.axi_slave_passive[8].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S9
//        9:`TOP.axi_slave_passive[9].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S10
//       10:`TOP.axi_slave_passive[10].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S11
//       11:`TOP.axi_slave_passive[11].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S12
//       12:`TOP.axi_slave_passive[12].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S13
//       13:`TOP.axi_slave_passive[13].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S14
//       14:`TOP.axi_slave_passive[14].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S15
//       15:`TOP.axi_slave_passive[15].display_data(is_valid, handle, str);
//`endif
//`ifdef AXI_HAS_S16
//       16:`TOP.axi_slave_passive[16].display_data(is_valid, handle, str);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//    end 
    else begin
      $display($time,"%m: ERROR - The input argument transactor(%0s) is not recognized.  Currently supported argument values are master and slave.",transactor);
      return;
    end
    $swrite(msgstr, "%0s.display_data(is_valid, handle, str",transactor);
    check_for_1(is_valid, msgstr, `ERROR_SEV);
  end
endtask : vip_display_data


/**
 * Utility method to call set_data_prop for a specific VIP instance.
 * @param transactor     : The string corresponding to VIP instance of the `TOP, master or slave or master_passive or slave_passive.
 * @param xactor_id     : The transactor number, ex: 1 corresponds to master[1] or slave[1] or master_passive[1] or slave_passive[1].
 * @param handle         : Specifies master or slave instance handle of the testbench 
 * @param prop_name      : Property name of data object like ID,addr,xact_type etc. 
 * @param prop_val       : Property value that needs to be set. 
 * @param array_ix       : Specifies array index for array properties like data,wstrb etc. 
 * @param is_valid       : Returned is_valid value. 
 */
task automatic vip_set_data_prop;
  input        reg [80*8:0] transactor;
  input        integer xactor_id;
  input        integer handle;
`ifdef SVT_MULTI_SIM_STRING_ARG_IN_EXPORTED_METHODS

  input        reg [80*8:0] prop_name;
`else
  input        string prop_name;
`endif
  input        reg [80*8:0] prop_val;
  input        integer array_ix;
  output       reg is_valid;
  reg [80*8:0] msgstr;
  begin
    if (transactor == "master") begin
      case (xactor_id) 
`ifdef AXI_HAS_M1

        1:`TOP.axi_master[1].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M2

        2:`TOP.axi_master[2].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M3

        3:`TOP.axi_master[3].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M4

        4:`TOP.axi_master[4].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M5

        5:`TOP.axi_master[5].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M6

        6:`TOP.axi_master[6].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M7

        7:`TOP.axi_master[7].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M8

        8:`TOP.axi_master[8].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M9

        9:`TOP.axi_master[9].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M10

       10:`TOP.axi_master[10].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M11

       11:`TOP.axi_master[11].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M12

       12:`TOP.axi_master[12].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M13

       13:`TOP.axi_master[13].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M14

       14:`TOP.axi_master[14].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M15

       15:`TOP.axi_master[15].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M16

       16:`TOP.axi_master[16].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
     endcase
    end 
    else if (transactor == "slave") begin
     case (xactor_id) 
`ifdef AXI_HAS_S1

        1:`TOP.axi_slave[1].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S2

        2:`TOP.axi_slave[2].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S3

        3:`TOP.axi_slave[3].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S4

        4:`TOP.axi_slave[4].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S5

        5:`TOP.axi_slave[5].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S6

        6:`TOP.axi_slave[6].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S7

        7:`TOP.axi_slave[7].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S8

        8:`TOP.axi_slave[8].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S9

        9:`TOP.axi_slave[9].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S10

       10:`TOP.axi_slave[10].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S11

       11:`TOP.axi_slave[11].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S12

       12:`TOP.axi_slave[12].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S13

       13:`TOP.axi_slave[13].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S14

       14:`TOP.axi_slave[14].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S15

       15:`TOP.axi_slave[15].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S16

       16:`TOP.axi_slave[16].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
     endcase
    end 
//    else if (transactor == "master_passive") begin
//      case (xactor_id) 
//`ifdef AXI_HAS_M1
//        1:`TOP.axi_master_passive[1].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M2
//        2:`TOP.axi_master_passive[2].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M3
//        3:`TOP.axi_master_passive[3].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M4
//        4:`TOP.axi_master_passive[4].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M5
//        5:`TOP.axi_master_passive[5].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M6
//        6:`TOP.axi_master_passive[6].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M7
//        7:`TOP.axi_master_passive[7].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M8
//        8:`TOP.axi_master_passive[8].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M9
//        9:`TOP.axi_master_passive[9].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M10
//       10:`TOP.axi_master_passive[10].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M11
//       11:`TOP.axi_master_passive[11].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M12
//       12:`TOP.axi_master_passive[12].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M13
//       13:`TOP.axi_master_passive[13].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M14
//       14:`TOP.axi_master_passive[14].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M15
//       15:`TOP.axi_master_passive[15].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M16
//       16:`TOP.axi_master_passive[16].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//     endcase
//    end 
//    else if (transactor == "slave_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_S1
//        1:`TOP.axi_slave_passive[1].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S2
//        2:`TOP.axi_slave_passive[2].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S3
//        3:`TOP.axi_slave_passive[3].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S4
//        4:`TOP.axi_slave_passive[4].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S5
//        5:`TOP.axi_slave_passive[5].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S6
//        6:`TOP.axi_slave_passive[6].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S7
//        7:`TOP.axi_slave_passive[7].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S8
//        8:`TOP.axi_slave_passive[8].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S9
//        9:`TOP.axi_slave_passive[9].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S10
//       10:`TOP.axi_slave_passive[10].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S11
//       11:`TOP.axi_slave_passive[11].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S12
//       12:`TOP.axi_slave_passive[12].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S13
//       13:`TOP.axi_slave_passive[13].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S14
//       14:`TOP.axi_slave_passive[14].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S15
//       15:`TOP.axi_slave_passive[15].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S16
//       16:`TOP.axi_slave_passive[16].set_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//     endcase
//    end 
    else begin
      $display($time,"%m: ERROR - The input argument transactor(%0s) is not recognized.  Currently supported argument values are master and slave.",transactor);
      return;
    end
    $swrite(msgstr, "%0s[%0d].set_data_prop(is_valid, handle,%0s, %0d, %0d);",transactor,xactor_id,prop_name,prop_val,array_ix);
    check_for_1(is_valid, msgstr, `ERROR_SEV);
  end
endtask : vip_set_data_prop

/**
 * Utility method to call get_data_prop for a specific VIP instance
 * @param transactor     : The string corresponding to VIP instance of the `TOP, master or slave or master_passive or slave_passive.
 * @param xactor_id     : The transactor number, ex: 1 corresponds to master[1] or slave[1] or master_passive[1] or slave_passive[1].
 * @param handle         : Specifies master or slave instance handle of the testbench 
 * @param prop_name      : Property name of data object like ID,addr,xact_type etc. 
 * @param array_ix       : Specifies array index for array properties like data,wstrb etc. 
 * @param prop_val       : Returned property value. 
 * @param is_valid       : Returned is_valid value. 
 */
task automatic vip_get_data_prop;
  input        reg [80*8:0] transactor;
  input        integer xactor_id;
  input        integer handle;
`ifdef SVT_MULTI_SIM_STRING_ARG_IN_EXPORTED_METHODS

  input        reg [80*8:0] prop_name;
`else
  input        string       prop_name;
`endif
  output       bit [1023:0 ] prop_val;
  input        int array_ix;
  output       reg is_valid;
  reg [80*8:0] msgstr;
  begin
      if (transactor == "master") begin
      case (xactor_id) 
`ifdef AXI_HAS_M1

        1:`TOP.axi_master[1].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M2

        2:`TOP.axi_master[2].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M3

        3:`TOP.axi_master[3].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M4

        4:`TOP.axi_master[4].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M5

        5:`TOP.axi_master[5].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M6

        6:`TOP.axi_master[6].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M7

        7:`TOP.axi_master[7].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M8

        8:`TOP.axi_master[8].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M9

        9:`TOP.axi_master[9].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M10

       10:`TOP.axi_master[10].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M11

       11:`TOP.axi_master[11].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M12

       12:`TOP.axi_master[12].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M13

       13:`TOP.axi_master[13].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M14

       14:`TOP.axi_master[14].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M15

       15:`TOP.axi_master[15].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_M16

       16:`TOP.axi_master[16].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
     endcase
    end 
    else if (transactor == "slave") begin
     case (xactor_id) 
`ifdef AXI_HAS_S1

        1:`TOP.axi_slave[1].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S2

        2:`TOP.axi_slave[2].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S3

        3:`TOP.axi_slave[3].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S4

        4:`TOP.axi_slave[4].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S5

        5:`TOP.axi_slave[5].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S6

        6:`TOP.axi_slave[6].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S7

        7:`TOP.axi_slave[7].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S8

        8:`TOP.axi_slave[8].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S9

        9:`TOP.axi_slave[9].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S10

       10:`TOP.axi_slave[10].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S11

       11:`TOP.axi_slave[11].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S12

       12:`TOP.axi_slave[12].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S13

       13:`TOP.axi_slave[13].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S14

       14:`TOP.axi_slave[14].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S15

       15:`TOP.axi_slave[15].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
`ifdef AXI_HAS_S16

       16:`TOP.axi_slave[16].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
     endcase
    end 
//    else if (transactor == "master_passive") begin
//      case (xactor_id) 
//`ifdef AXI_HAS_M1
//        1:`TOP.axi_master_passive[1].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M2
//        2:`TOP.axi_master_passive[2].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M3
//        3:`TOP.axi_master_passive[3].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M4
//        4:`TOP.axi_master_passive[4].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M5
//        5:`TOP.axi_master_passive[5].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M6
//        6:`TOP.axi_master_passive[6].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M7
//        7:`TOP.axi_master_passive[7].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M8
//        8:`TOP.axi_master_passive[8].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M9
//        9:`TOP.axi_master_passive[9].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M10
//       10:`TOP.axi_master_passive[10].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M11
//       11:`TOP.axi_master_passive[11].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M12
//       12:`TOP.axi_master_passive[12].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M13
//       13:`TOP.axi_master_passive[13].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M14
//       14:`TOP.axi_master_passive[14].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M15
//       15:`TOP.axi_master_passive[15].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_M16
//       16:`TOP.axi_master_passive[16].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//     endcase
//    end 
//    else if (transactor == "slave_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_S1
//        1:`TOP.axi_slave_passive[1].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S2
//        2:`TOP.axi_slave_passive[2].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S3
//        3:`TOP.axi_slave_passive[3].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S4
//        4:`TOP.axi_slave_passive[4].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S5
//        5:`TOP.axi_slave_passive[5].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S6
//        6:`TOP.axi_slave_passive[6].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S7
//        7:`TOP.axi_slave_passive[7].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S8
//        8:`TOP.axi_slave_passive[8].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S9
//        9:`TOP.axi_slave_passive[9].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S10
//       10:`TOP.axi_slave_passive[10].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S11
//       11:`TOP.axi_slave_passive[11].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S12
//       12:`TOP.axi_slave_passive[12].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S13
//       13:`TOP.axi_slave_passive[13].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S14
//       14:`TOP.axi_slave_passive[14].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S15
//       15:`TOP.axi_slave_passive[15].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//`ifdef AXI_HAS_S16
//       16:`TOP.axi_slave_passive[16].get_data_prop(is_valid, handle, prop_name, prop_val, array_ix);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//     endcase
//    end 
    else begin
      $display($time,"%m: ERROR - The input argument transactor(%0s) is not recognized.  Currently supported argument values are master and slave.",transactor);
      return;
    end
    $swrite(msgstr, "%0s.get_data_prop(is_valid, handle,%0s, %0d, %0d);",transactor,prop_name,prop_val,array_ix);
    check_for_1(is_valid, msgstr, `ERROR_SEV);
  end
endtask : vip_get_data_prop

/**
 * Command Support:
 * When called from the command, does not return until the specified 
 * event occurs within the model.
 *
 * @param transactor      : The string corresponding to VIP instance of the `TOP, master or slave or master_passive or slave_passive.
 * @param xactor_id      : The transactor number, ex: 1 corresponds to master[1] or slave[1] or master_passive[1] or slave_passive[1].
 * @param event_name      : The name of an <i>uvm_event</i> event
 *                          configured in the driver, and intended to be command accessible. The
 *                          name should be of the form "NOTIFY_...".
 * @param is_valid        : Functions as a <i>return</i> value ('0' if the
 *                          <b>event_name</b> argument does not specify a event that is
 *                          available for the command to use).
 */
task automatic vip_notify_wait_for;
  input       reg [80*8:0] transactor;
  input       integer xactor_id;
`ifdef SVT_MULTI_SIM_STRING_ARG_IN_EXPORTED_METHODS

  input       reg [80*8:0] event_name;
`else
  input       string event_name;
`endif
  output      bit is_valid;
  begin
    reg [80*8:0] msgstr;
    if (transactor == "master") begin
      case(xactor_id)
`ifdef AXI_HAS_M1

        1:`TOP.axi_master[1].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M2

        2:`TOP.axi_master[2].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M3

        3:`TOP.axi_master[3].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M4

        4:`TOP.axi_master[4].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M5

        5:`TOP.axi_master[5].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M6

        6:`TOP.axi_master[6].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M7

        7:`TOP.axi_master[7].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M8

        8:`TOP.axi_master[8].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M9

        9:`TOP.axi_master[9].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M10

       10:`TOP.axi_master[10].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M11

       11:`TOP.axi_master[11].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M12

       12:`TOP.axi_master[12].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M13

       13:`TOP.axi_master[13].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M14

       14:`TOP.axi_master[14].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M15

       15:`TOP.axi_master[15].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_M16

       16:`TOP.axi_master[16].notify_wait_for(is_valid, event_name);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end 
    else if (transactor == "slave") begin
      case(xactor_id)
`ifdef AXI_HAS_S1

        1:`TOP.axi_slave[1].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S2

        2:`TOP.axi_slave[2].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S3

        3:`TOP.axi_slave[3].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S4

        4:`TOP.axi_slave[4].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S5

        5:`TOP.axi_slave[5].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S6

        6:`TOP.axi_slave[6].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S7

        7:`TOP.axi_slave[7].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S8

        8:`TOP.axi_slave[8].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S9

        9:`TOP.axi_slave[9].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S10

       10:`TOP.axi_slave[10].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S11

       11:`TOP.axi_slave[11].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S12

       12:`TOP.axi_slave[12].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S13

       13:`TOP.axi_slave[13].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S14

       14:`TOP.axi_slave[14].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S15

       15:`TOP.axi_slave[15].notify_wait_for(is_valid, event_name);
`endif
`ifdef AXI_HAS_S16

       16:`TOP.axi_slave[16].notify_wait_for(is_valid, event_name);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end
//    else if (transactor == "master_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_M1
//        1:`TOP.axi_master_passive[1].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M2
//        2:`TOP.axi_master_passive[2].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M3
//        3:`TOP.axi_master_passive[3].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M4
//        4:`TOP.axi_master_passive[4].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M5
//        5:`TOP.axi_master_passive[5].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M6
//        6:`TOP.axi_master_passive[6].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M7
//        7:`TOP.axi_master_passive[7].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M8
//        8:`TOP.axi_master_passive[8].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M9
//        9:`TOP.axi_master_passive[9].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M10
//       10:`TOP.axi_master_passive[10].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M11
//       11:`TOP.axi_master_passive[11].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M12
//       12:`TOP.axi_master_passive[12].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M13
//       13:`TOP.axi_master_passive[13].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M14
//       14:`TOP.axi_master_passive[14].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M15
//       15:`TOP.axi_master_passive[15].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_M16
//       16:`TOP.axi_master_passive[16].notify_wait_for(is_valid, event_name);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//    end 
//    else if (transactor == "slave_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_S1
//        1:`TOP.axi_slave_passive[1].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S2
//        2:`TOP.axi_slave_passive[2].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S3
//        3:`TOP.axi_slave_passive[3].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S4
//        4:`TOP.axi_slave_passive[4].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S5
//        5:`TOP.axi_slave_passive[5].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S6
//        6:`TOP.axi_slave_passive[6].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S7
//        7:`TOP.axi_slave_passive[7].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S8
//        8:`TOP.axi_slave_passive[8].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S9
//        9:`TOP.axi_slave_passive[9].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S10
//       10:`TOP.axi_slave_passive[10].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S11
//       11:`TOP.axi_slave_passive[11].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S12
//       12:`TOP.axi_slave_passive[12].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S13
//       13:`TOP.axi_slave_passive[13].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S14
//       14:`TOP.axi_slave_passive[14].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S15
//       15:`TOP.axi_slave_passive[15].notify_wait_for(is_valid, event_name);
//`endif
//`ifdef AXI_HAS_S16
//       16:`TOP.axi_slave_passive[16].notify_wait_for(is_valid, event_name);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//    end 
    else begin
      $display($time,"%m: ERROR - The input argument transactor(%0s) is not recognized.  Currently supported argument values are master and slave.",transactor);
    end
    $swrite(msgstr, "%0s[%0d].vip_notify_wait_for(is_valid, %0s);",transactor,xactor_id,event_name);
    check_for_1(is_valid, msgstr, `ERROR_SEV);
  end
endtask : vip_notify_wait_for


/**
 * Utility method to call callback_wait_for for a specific VIP instance
 *
 * @param transactor     : The string corresponding to VIP instance of the `TOP, master or slave or master_passive or slave_passive.
 * @param xactor_id     : The transactor number, ex: 1 corresponds to master[1] or slave[1] or master_passive[1] or slave_passive[1].
 * @param cb_notify_name : The name of an <i>uvm_event</i> event
 *                         configured in the driver, and intended to be command accessible. The
 *                         name should be of the form "NOTIFY_CB_...".
 * @param handle         : Handle to point object of VIP instance.
 * @param is_valid       : This flags the status of function executed 1 as success 0 as failure.
 *
 */
task automatic vip_callback_wait_for;
  input       reg [80*8:0] transactor;
  input       integer xactor_id;
`ifdef SVT_MULTI_SIM_STRING_ARG_IN_EXPORTED_METHODS

  input       bit[80*8-1:0] cb_notify_name;
`else
  input       string cb_notify_name;
`endif
  inout       integer handle;
  output      bit is_valid;
  begin
    reg [80*8:0] msgstr;
    if (transactor == "master") 
      case (xactor_id)
`ifdef AXI_HAS_M1

        1:`TOP.axi_master[1].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M2

        2:`TOP.axi_master[2].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M3

        3:`TOP.axi_master[3].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M4

        4:`TOP.axi_master[4].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M5

        5:`TOP.axi_master[5].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M6

        6:`TOP.axi_master[6].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M7

        7:`TOP.axi_master[7].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M8

        8:`TOP.axi_master[8].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M9

        9:`TOP.axi_master[9].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M10

       10:`TOP.axi_master[10].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M11

       11:`TOP.axi_master[11].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M12

       12:`TOP.axi_master[12].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M13

       13:`TOP.axi_master[13].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M14

       14:`TOP.axi_master[14].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M15

       15:`TOP.axi_master[15].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M16

       16:`TOP.axi_master[16].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    else if (transactor == "slave")
      case(xactor_id)
`ifdef AXI_HAS_S1

        1:`TOP.axi_slave[1].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S2

        2:`TOP.axi_slave[2].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S3

        3:`TOP.axi_slave[3].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S4

        4:`TOP.axi_slave[4].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S5

        5:`TOP.axi_slave[5].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S6

        6:`TOP.axi_slave[6].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S7

        7:`TOP.axi_slave[7].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S8

        8:`TOP.axi_slave[8].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S9

        9:`TOP.axi_slave[9].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S10

       10:`TOP.axi_slave[10].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S11

       11:`TOP.axi_slave[11].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S12

       12:`TOP.axi_slave[12].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S13

       13:`TOP.axi_slave[13].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S14

       14:`TOP.axi_slave[14].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S15

       15:`TOP.axi_slave[15].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S16

       16:`TOP.axi_slave[16].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase

//    else if (transactor == "master_passive") 
//      case(xactor_id)
//`ifdef AXI_HAS_M1
//        1:`TOP.axi_master_passive[1].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M2
//        2:`TOP.axi_master_passive[2].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M3
//        3:`TOP.axi_master_passive[3].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M4
//        4:`TOP.axi_master_passive[4].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M5
//        5:`TOP.axi_master_passive[5].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M6
//        6:`TOP.axi_master_passive[6].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M7
//        7:`TOP.axi_master_passive[7].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M8
//        8:`TOP.axi_master_passive[8].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M9
//        9:`TOP.axi_master_passive[9].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M10
//       10:`TOP.axi_master_passive[10].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M11
//       11:`TOP.axi_master_passive[11].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M12
//       12:`TOP.axi_master_passive[12].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M13
//       13:`TOP.axi_master_passive[13].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M14
//       14:`TOP.axi_master_passive[14].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M15
//       15:`TOP.axi_master_passive[15].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M16
//       16:`TOP.axi_master_passive[16].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//
//    else if (transactor == "slave_passive") 
//      case(xactor_id)
//`ifdef AXI_HAS_S1
//        1:`TOP.axi_slave_passive[1].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S2
//        2:`TOP.axi_slave_passive[2].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S3
//        3:`TOP.axi_slave_passive[3].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S4
//        4:`TOP.axi_slave_passive[4].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S5
//        5:`TOP.axi_slave_passive[5].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S6
//        6:`TOP.axi_slave_passive[6].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S7
//        7:`TOP.axi_slave_passive[7].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S8
//        8:`TOP.axi_slave_passive[8].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S9
//        9:`TOP.axi_slave_passive[9].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S10
//       10:`TOP.axi_slave_passive[10].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S11
//       11:`TOP.axi_slave_passive[11].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S12
//       12:`TOP.axi_slave_passive[12].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S13
//       13:`TOP.axi_slave_passive[13].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S14
//       14:`TOP.axi_slave_passive[14].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S15
//       15:`TOP.axi_slave_passive[15].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S16
//       16:`TOP.axi_slave_passive[16].cmd_callback_wait_for(is_valid, handle, cb_notify_name);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase

    else begin
      $display($time,"%m: ERROR - The input argument transactor(%0s) is not recognized.  Currently supported argument values are master and slave.",transactor);
    end
    $swrite(msgstr, "%0s[%0d].cmd_callback_wait_for(is_valid, handle, %0s);",transactor,xactor_id,cb_notify_name);
    check_for_1(is_valid, msgstr, `ERROR_SEV);
  end
endtask : vip_callback_wait_for

/**
 * Utility method to call callback_proceed for a specific VIP instance
 *
 * @param transactor     : The string corresponding to VIP instance of the `TOP, master or slave or master_passive or slave_passive.
 * @param xactor_id     : The transactor number, ex: 1 corresponds to master[1] or slave[1] or master_passive[1] or slave_passive[1].
 * @param cb_notify_name : The name of an <i>uvm_event</i> event
 *                         configured in the driver, and intended to be command accessible. The
 *                         name should be of the form "NOTIFY_CB_...".
 * @param handle         : Handle to point object of VIP instance.
 * @param is_valid       : This flags the status of function executed 1 as success 0 as failure.
 *
 */
task automatic vip_callback_proceed;
  input       reg [80*8:0] transactor;
  input       integer  xactor_id;
`ifdef SVT_MULTI_SIM_STRING_ARG_IN_EXPORTED_METHODS

  input       bit[80*8-1:0] cb_notify_name;
`else
  input       string cb_notify_name;
`endif
  inout       integer handle;
  output      bit is_valid;
  begin
    reg [80*8:0] msgstr;
    if (transactor == "master") begin
      case(xactor_id)
`ifdef AXI_HAS_M1

        1:`TOP.axi_master[1].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M2

        2:`TOP.axi_master[2].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M3

        3:`TOP.axi_master[3].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M4

        4:`TOP.axi_master[4].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M5

        5:`TOP.axi_master[5].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M6

        6:`TOP.axi_master[6].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M7

        7:`TOP.axi_master[7].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M8

        8:`TOP.axi_master[8].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M9

        9:`TOP.axi_master[9].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M10

       10:`TOP.axi_master[10].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M11

       11:`TOP.axi_master[11].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M12

       12:`TOP.axi_master[12].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M13

       13:`TOP.axi_master[13].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M14

       14:`TOP.axi_master[14].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M15

       15:`TOP.axi_master[15].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_M16

       16:`TOP.axi_master[16].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase
    end 
    else if (transactor == "slave") begin
      case(xactor_id)
`ifdef AXI_HAS_S1

        1:`TOP.axi_slave[1].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S2

        2:`TOP.axi_slave[2].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S3

        3:`TOP.axi_slave[3].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S4

        4:`TOP.axi_slave[4].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S5

        5:`TOP.axi_slave[5].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S6

        6:`TOP.axi_slave[6].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S7

        7:`TOP.axi_slave[7].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S8

        8:`TOP.axi_slave[8].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S9

        9:`TOP.axi_slave[9].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S10

       10:`TOP.axi_slave[10].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S11

       11:`TOP.axi_slave[11].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S12

       12:`TOP.axi_slave[12].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S13

       13:`TOP.axi_slave[13].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S14

       14:`TOP.axi_slave[14].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S15

       15:`TOP.axi_slave[15].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
`ifdef AXI_HAS_S16

       16:`TOP.axi_slave[16].cmd_callback_proceed(is_valid, handle, cb_notify_name);
`endif
       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
      endcase

    end
//    else if (transactor == "master_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_M1
//        1:`TOP.axi_master_passive[1].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M2
//        2:`TOP.axi_master_passive[2].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M3
//        3:`TOP.axi_master_passive[3].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M4
//        4:`TOP.axi_master_passive[4].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M5
//        5:`TOP.axi_master_passive[5].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M6
//        6:`TOP.axi_master_passive[6].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M7
//        7:`TOP.axi_master_passive[7].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M8
//        8:`TOP.axi_master_passive[8].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M9
//        9:`TOP.axi_master_passive[9].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M10
//       10:`TOP.axi_master_passive[10].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M11
//       11:`TOP.axi_master_passive[11].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M12
//       12:`TOP.axi_master_passive[12].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M13
//       13:`TOP.axi_master_passive[13].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M14
//       14:`TOP.axi_master_passive[14].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M15
//       15:`TOP.axi_master_passive[15].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_M16
//       16:`TOP.axi_master_passive[16].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//
//    end 
//    else if (transactor == "slave_passive") begin
//      case(xactor_id)
//`ifdef AXI_HAS_S1
//        1:`TOP.axi_slave_passive[1].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S2
//        2:`TOP.axi_slave_passive[2].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S3
//        3:`TOP.axi_slave_passive[3].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S4
//        4:`TOP.axi_slave_passive[4].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S5
//        5:`TOP.axi_slave_passive[5].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S6
//        6:`TOP.axi_slave_passive[6].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S7
//        7:`TOP.axi_slave_passive[7].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S8
//        8:`TOP.axi_slave_passive[8].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S9
//        9:`TOP.axi_slave_passive[9].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S10
//       10:`TOP.axi_slave_passive[10].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S11
//       11:`TOP.axi_slave_passive[11].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S12
//       12:`TOP.axi_slave_passive[12].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S13
//       13:`TOP.axi_slave_passive[13].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S14
//       14:`TOP.axi_slave_passive[14].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S15
//       15:`TOP.axi_slave_passive[15].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//`ifdef AXI_HAS_S16
//       16:`TOP.axi_slave_passive[16].cmd_callback_proceed(is_valid, handle, cb_notify_name);
//`endif
//       default :$display($time,"%m: ERROR - The input argument xactor_id(%0d) is not recognized.",xactor_id);
//      endcase
//
//    end 
    else begin
      $display($time,"%m: ERROR - The input argument transactor(%0s) is not recognized.  Currently supported argument values are master and slave.",transactor);
    end
    $swrite(msgstr, "%0s[%0d].cmd_callback_proceed(is_valid, handle, %0s);",transactor,xactor_id,cb_notify_name);
    check_for_1(is_valid, msgstr, `ERROR_SEV);
  end
endtask : vip_callback_proceed

//------------------------------------------------------------------------
`define GET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, propname, propval, propidx, is_valid) \
  `TOP.vip_get_data_prop(transactor,xactor_id,handle, propname, propval, propidx, is_valid); 

//------------------------------------------------------------------------
`define SET_DATA_PROP_W_CHECK(transactor,xactor_id, handle, propname, propval, propidx, is_valid) \
  `TOP.vip_set_data_prop(transactor,xactor_id,handle, propname, propval, propidx, is_valid); 

`endif // TB_AXI_TASKS_VIP_V
