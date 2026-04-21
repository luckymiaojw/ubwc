/*
 ------------------------------------------------------------------------
--
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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/sim/testbench/sim_svte/tb_apb_rd_wr.sv#1 $ 
*/

// All required defines
`define MAIN_STREAM             0
`define QOS_DATA_REG_ADDR `AXI_IC_REG_BASE_ADDR+32'h0000_000C 
`define QOS_CMD_REG_ADDR `AXI_IC_REG_BASE_ADDR+32'h0000_0008
`define QOS_VERSION_ID_ADDR `AXI_IC_REG_BASE_ADDR+32'h000_0000 
`define QOS_HW_CFG_ADDR `AXI_IC_REG_BASE_ADDR+32'h000_0004 

`define QOS_CMD_BURSTINESS 3'b000
`define QOS_CMD_PEAK_RATE  3'b001
`define QOS_CMD_QOS_VALUE  3'b010
`define QOS_CMD_SLV_READY  3'b011

// +-----------------------------------------------+
//   Write call to do APB write transaction
// +-----------------------------------------------+
task automatic apb_write;
 input [31:0] apb_addr;
 input [31:0] apb_wr_data;
 integer status ;
 begin
   rd_wr_semaphore.get(1);
   apb_vip_master_inst.write(apb_addr,apb_wr_data);
   rd_wr_semaphore.put(1);
   if (test_debug) $display("%0t : Completed an APB Write - Addr = %0h Write_Data = %0h \n",$time,apb_addr,apb_wr_data);
 end
endtask

// +-----------------------------------------------+
//   READ call to do APB read transaction
// +-----------------------------------------------+
task automatic apb_read;
 input [31:0] apb_addr;
 output [31:0] apb_rd_data;
 reg [31:0] int_read_data;
 integer tag;
 begin
   rd_wr_semaphore.get(1);
   apb_vip_master_inst.read(apb_addr ,int_read_data );
   rd_wr_semaphore.put(1);
   if (test_debug) $display("%0t:Completed an APB READ - Addr = %0h Read_Data = %0h \n",$time,apb_addr,int_read_data);
   apb_rd_data = int_read_data;
 end
endtask

//+--------------------------------------------------------+
//  Task Name : command_reg_write  
//     - Issue a command write and wait for completion 
//     - Used to write a QOS command - Master Specific
//     - Can be used for both AW/AR channels per master
//+--------------------------------------------------------+
task automatic command_reg_write;
input integer masterID;
input [2:0] qos_cmd;
input  [31:0] data;
input rd_wr_chan ; //Bit 7 of CMD REG

reg [31:0] cmd_data;
reg [31:0] cmd_addr,data_addr;
reg [3:0] master_id;
integer status,tag ;
reg [31:0] read_data_frm_reg;
begin
  master_id = masterID-1;
  cmd_and_data_reg_write(1'b1,master_id,data,qos_cmd,rd_wr_chan);
  // Now READ BACK THE REGISTER to make sure data is written
  // correctly
  cmd_and_data_reg_write(1'b0,master_id,data,qos_cmd,rd_wr_chan);

 end//task begin
endtask

// +---------------------------------------------------+
//     Write into QOS CMD/DATA REG of specified master
// +---------------------------------------------------+
task automatic program_qos_registers;
input integer masterID;
input rd_wr_chan;
input [31:0] qos_cmd_burst,qos_cmd_peak_rate,qos_cmd_qos_value,qos_cmd_slv_rdy;
begin
  if (test_debug) $display("Inside TASK for Master:%0d : program_qos_registers \n",masterID);
  command_reg_write(masterID,3'b0,qos_cmd_burst,rd_wr_chan);
  command_reg_write(masterID,3'b001,qos_cmd_peak_rate,rd_wr_chan);
  command_reg_write(masterID,3'b010,qos_cmd_qos_value,rd_wr_chan);
  command_reg_write(masterID,3'b011,qos_cmd_slv_rdy,rd_wr_chan);
end
endtask

// +------------------------------------------------------+
//     Write Random QOS CMD/DATA REG of specified master
// +------------------------------------------------------+
task automatic program_qos_reg_random;
input integer masterID;
input rd_wr_chan;

reg [31:0] qos_cmd_burst,qos_cmd_peak_rate,qos_cmd_qos_value,qos_cmd_slv_rdy;
begin
 //Generate random data
 //gen_rand_data;
  qos_cmd_burst     = $random(seed);
  qos_cmd_peak_rate = $random(seed);
  qos_cmd_qos_value = $random(seed);
  qos_cmd_slv_rdy   = $random(seed);

  // Make the value '0' as non-zero 
  // To Enable more efficient checks use non-zero values
  // for all the fields of the registers
  
  // +-- SLV RDY Reg 
  if(qos_cmd_slv_rdy[0] == 0)
   qos_cmd_slv_rdy[0] = 1'b1;

  // +-- Busrt Reg
  if(qos_cmd_burst[0] == 0)
   qos_cmd_burst[0] = 1'b1;
  if(qos_cmd_burst[23:16] == 0)
   qos_cmd_burst[23:16] =$random(seed);

  // +-- Peak Rate Reg
  if(qos_cmd_peak_rate[7:0] == 0)
   qos_cmd_peak_rate[7:0] = $random(seed);
  if(qos_cmd_peak_rate[23:16] == 0)
   qos_cmd_peak_rate[23:16] = $random(seed);
 
  //++ --- QOS Value Reg
   if(qos_cmd_qos_value[3:0] ==0)
    qos_cmd_qos_value[3:0] = qos_cmd_qos_value[3:0]+2;   
 
$display("Rand Write:qos_cmd_burst:%0h qos_cmd_peak_rate:%0h\n",qos_cmd_burst,qos_cmd_peak_rate);
$display("Rand Write:qos_cmd_qos_value:%0h qos_cmd_slv_rdy:%0h\n",qos_cmd_qos_value,qos_cmd_slv_rdy);
  command_reg_write(masterID,3'b0,qos_cmd_burst,rd_wr_chan);
  command_reg_write(masterID,3'b001,qos_cmd_peak_rate,rd_wr_chan);
  command_reg_write(masterID,3'b010,qos_cmd_qos_value,rd_wr_chan);
  command_reg_write(masterID,3'b011,qos_cmd_slv_rdy,rd_wr_chan);
end
endtask

// +---------------------------------------------------+
// Task name : wait_for_cmd_reg_execute
//  - Task blocks until the command is executed.
//  - Timeout mechanism for command execution
//     Wait for CMD reg to be executed
// +---------------------------------------------------+
task automatic wait_for_cmd_reg_execute;
input [31:0] addr,cmd_data;
input is_it_soft_reset_test;
reg [31:0] read_data_frm_reg;
integer tag;

begin
// Wait for IC to reset the bit 31 of cmd_reg
 fork
 begin : task_cmd_wait
 forever begin
   repeat (5) @(posedge system_clk);
   apb_read(addr,read_data_frm_reg);
   $display("%0t : READ VALUE of CMD_REG = %0h \n",$time,read_data_frm_reg);
    begin
      if(read_data_frm_reg[31] ==0 )
       begin
         disable task_timeout_read_fork; disable task_cmd_wait;
         $display("The bit 31 is RESET by IC .. exiting .. \n"); 
       end
    end
  end
 end
 begin : task_timeout_read_fork
  repeat (1000) @(posedge system_clk);
  $display("ERROR : APB WRITE TIMEOUT - QOS DID not reset the bit 31 of the CMD reg \n");
  disable task_cmd_wait ;
  $finish; // Error condition if the cmd not written
 end
 join

end//begin-task
endtask

//+--------------------------------------------------------------------+
//  Task Name : cmd_and_data_reg_write
//     - Write the command & data registers
//     - Master specific / AR-AW  channel specific
//     - This API will update the CMD reg and wait for completion
//     Command bit not reset in specific time leads to timeout
//+---------------------------------------------------------------------+
task  automatic cmd_and_data_reg_write;
 input read_or_write;
 input [3:0] master_id;
 input [31:0] data_value;
 input [2:0] qos_cmd;
 input rd_wr_chan;

 reg [31:0] cmd_data,read_data_frm_reg;
 integer status,tag;
 begin
   
   // If write command - Data Reg first - recommended
   if(read_or_write == 1) begin
     apb_write(`QOS_DATA_REG_ADDR,data_value); 
   end
   // Form the command 
   create_command(1'b1,read_or_write,master_id,rd_wr_chan,qos_cmd,1'b1);
   
  // Read back to check if data written correctly
  if(read_or_write==0) begin
   // Now read the actual data written into the register
   apb_read(`QOS_DATA_REG_ADDR,read_data_frm_reg); 
   $display("%0t: Master :%0d Data READ : %0h QOS_CMD:%0h \
      ",$time,master_id, read_data_frm_reg,qos_cmd );

  end
 end //begin task
endtask



//+---------------------------------------------------+
// Task name : create_command
//   - This creates required fields for command register
//   - Inputs gain is master/command / channel specific
//   - Control for command execution wait 
//+---------------------------------------------------+

task create_command;
input cmd_en,rw_en;
input [3:0] master_port;
input rd_wr_chan;
input [2:0] qos_cmd ;
input enable_wait_for_exec;
reg [31:0] cmd_data ;
 begin

  // Form the command 
  cmd_data[31] = cmd_en;  
  cmd_data[30] = rw_en; 
  cmd_data[29] = 1'b0 ; 
  cmd_data[11:8] = master_port; 
  cmd_data[7] = rd_wr_chan; 
  cmd_data[2:0] = qos_cmd;  
  cmd_data[28:12] = 0; 
  cmd_data[6:3] = 0; 
  
  $display("Master ID-%0d Command_Data=%0h  \n",master_port,cmd_data); 
  // Write READ CMD into the reg
  apb_write(`QOS_CMD_REG_ADDR,cmd_data); 
  
  // Wait for the command to be executed
  if(enable_wait_for_exec)
   wait_for_cmd_reg_execute(`QOS_CMD_REG_ADDR,cmd_data,~cmd_en);
 end//begin-task
endtask

