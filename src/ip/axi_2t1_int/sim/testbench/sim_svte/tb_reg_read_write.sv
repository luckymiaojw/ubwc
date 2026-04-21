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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/sim/testbench/sim_svte/tb_reg_read_write.sv#1 $ 
*/
// +---------------------------------------------------------------------------------------+
//         Macro to check if Err bit - Validity
// +---------------------------------------------------------------------------------------+
`define CHECK_ERR_BIT(AW_HAS_QOS_REGULATOR, AR_HAS_QOS_REGULATOR, HAS_AWQOS_EXT, HAS_ARQOS_EXT) \
    if(data_rd[28] == 1'b0 && (AR_HAS_QOS_REGULATOR == 0 && data_rd[7]==0 && (data_rd[2:0]==3'b000 || data_rd[2:0]==3'b001 || data_rd[2:0]==3'b011 ) ) ) \
      $display("ERROR : Master%0d -No err_bit - AXI_AR_HAS_QOS_REGULATOR is disbaled \n",data_rd[11:8]+1); \
    else if(data_rd[28] == 1'b0 && (AW_HAS_QOS_REGULATOR ==0 && data_rd[7]==1 && (data_rd[2:0]==3'b000 || data_rd[2:0]==3'b001 || data_rd[2:0]==3'b011 )  ) ) \
      $display("ERROR : Master%0d - No err_bit - AXI_AW_HAS_QOS_REGULATOR is disbaled \n",data_rd[11:8]+1); \
    else if(data_rd[28] ==1'b0 && HAS_AWQOS_EXT ==1 && data_rd[7]==1 && data_rd[2:0]==3'b010) \
      $display("ERROR : Master%0d - No err bit - AXI_HAS_AWQOS_EXT_M Enabled - Cannot write QOS_VALUE \n",data_rd[11:8]+1); \
    else if(data_rd[28] ==1'b0 && HAS_ARQOS_EXT ==1 && data_rd[7]==0 && data_rd[2:0]==3'b010) \
      $display("ERROR : Master%0d - No err bit - AXI_HAS_ARQOS_EXT_M Enabled - Cannot write QOS_VALUE \n",data_rd[11:8]+1); \
    else if(data_rd[28] == 1'b1 && (AR_HAS_QOS_REGULATOR==0 && data_rd[7]==0 && (data_rd[2:0]==3'b000 || data_rd[2:0]==3'b001 || data_rd[2:0]==3'b011 ) ) ) \
      $display("PASS : Master%0d- VALID err_bit - AXI_AR_HAS_QOS_REGULATOR is disbaled \n",data_rd[11:8]+1); \
    else if(data_rd[28] == 1'b1 && (AW_HAS_QOS_REGULATOR==0 && data_rd[7]==1 && (data_rd[2:0]==3'b000 || data_rd[2:0]==3'b001 || data_rd[2:0]==3'b011 ) ) ) \
      $display("PASS : Master%0d - VALID err_bit - AXI_AW_HAS_QOS_REGULATOR is disbaled \n",data_rd[11:8]+1); \
    else if(data_rd[28] ==1'b1 && HAS_AWQOS_EXT == 1 && data_rd[7]==1 && data_rd[2:0]==3'b010) \
      $display("PASS : Master%0d - VALID err bit - AXI_HAS_AWQOS_EXT_M Enabled  \n",data_rd[11:8]+1); \
    else if(data_rd[28] ==1'b1 && HAS_ARQOS_EXT ==1 && data_rd[7]==0 && data_rd[2:0]==3'b010) \
      $display("PASS : Master%0d - VALID err bit - AXI_HAS_ARQOS_EXT_M Enabled  \n",data_rd[11:8]+1); \
    else if(data_rd[28] ==1'b0 &&  data_rd[2:0] > 3'b011) \
     $display("ERROR : Master%0d - No err bit generated for non-existen command\n",data_rd[11:8]+1); \
    else if(data_rd[28] ==1'b1 &&  data_rd[2:0] > 3'b011) \
     $display("PASS : Master%0d - VALID err bit generated for non-existen command\n",data_rd[11:8]+1); \
    else if(data_rd[28] == 1'b1 && data_rd[11:8] < `AXI_NUM_MASTERS && data_rd[11:8] !=0 ) \
     $display("%0t : Master%0d - ERROR : err_bit GENERATED - Check condition \n",$time,data_rd[11:8]+1);  

`define CHECK_EXT_QOS(HAS_AWQOS_EXT) \
 if ( HAS_AWQOS_EXT == 1 ) \
  ext_qos_en_wr_chan = 1; \
 else \
  ext_qos_en_wr_chan = 0;

`define CHECK_QOS_REGULATOR(HAS_REGULATOR) \
if(HAS_REGULATOR==1) \
  qos_regulation_rw_en = 1; \
else \
 qos_regulation_rw_en = 0;

//+---------------------------------------------------+
//     Check if err bit raised correctly
//+---------------------------------------------------+
task  automatic check_err_bit ;
input [31:0] data_rd;
begin
case(data_rd[11:8])
4'b0000: 
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M1, `AXI_AR_HAS_QOS_REGULATOR_M1, `AXI_HAS_AWQOS_EXT_M1, `AXI_HAS_ARQOS_EXT_M1)
    end
4'b0001:
    begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M2, `AXI_AR_HAS_QOS_REGULATOR_M2, `AXI_HAS_AWQOS_EXT_M2, `AXI_HAS_ARQOS_EXT_M2)
    end
4'b0010:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M3, `AXI_AR_HAS_QOS_REGULATOR_M3, `AXI_HAS_AWQOS_EXT_M3, `AXI_HAS_ARQOS_EXT_M3)
   end
4'b0011:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M4, `AXI_AR_HAS_QOS_REGULATOR_M4, `AXI_HAS_AWQOS_EXT_M4, `AXI_HAS_ARQOS_EXT_M4)
   end
4'b0100:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M5, `AXI_AR_HAS_QOS_REGULATOR_M5, `AXI_HAS_AWQOS_EXT_M5, `AXI_HAS_ARQOS_EXT_M5)
   end
4'b0101:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M6, `AXI_AR_HAS_QOS_REGULATOR_M6, `AXI_HAS_AWQOS_EXT_M6, `AXI_HAS_ARQOS_EXT_M6)
   end
4'b0110:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M7, `AXI_AR_HAS_QOS_REGULATOR_M7, `AXI_HAS_AWQOS_EXT_M7, `AXI_HAS_ARQOS_EXT_M7)
   end
4'b0111:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M8, `AXI_AR_HAS_QOS_REGULATOR_M8, `AXI_HAS_AWQOS_EXT_M8, `AXI_HAS_ARQOS_EXT_M8)
   end
4'b1000:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M9, `AXI_AR_HAS_QOS_REGULATOR_M9, `AXI_HAS_AWQOS_EXT_M9, `AXI_HAS_ARQOS_EXT_M9)
   end
4'b1001:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M10, `AXI_AR_HAS_QOS_REGULATOR_M10, `AXI_HAS_AWQOS_EXT_M10, `AXI_HAS_ARQOS_EXT_M10)
   end
4'b1010:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M11, `AXI_AR_HAS_QOS_REGULATOR_M11, `AXI_HAS_AWQOS_EXT_M11, `AXI_HAS_ARQOS_EXT_M11)
   end
4'b1011:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M12, `AXI_AR_HAS_QOS_REGULATOR_M12, `AXI_HAS_AWQOS_EXT_M12, `AXI_HAS_ARQOS_EXT_M12)
   end
4'b1100:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M13, `AXI_AR_HAS_QOS_REGULATOR_M13, `AXI_HAS_AWQOS_EXT_M13, `AXI_HAS_ARQOS_EXT_M13)
   end
4'b1101:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M14, `AXI_AR_HAS_QOS_REGULATOR_M14, `AXI_HAS_AWQOS_EXT_M14, `AXI_HAS_ARQOS_EXT_M14)
   end
4'b1110:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M15, `AXI_AR_HAS_QOS_REGULATOR_M15, `AXI_HAS_AWQOS_EXT_M15, `AXI_HAS_ARQOS_EXT_M15)
   end
4'b1111:
   begin
     `CHECK_ERR_BIT(`AXI_AW_HAS_QOS_REGULATOR_M16, `AXI_AR_HAS_QOS_REGULATOR_M16, `AXI_HAS_AWQOS_EXT_M16, `AXI_HAS_ARQOS_EXT_M16)
   end
endcase

end//task begin
endtask

// +---------------------------------------------------+
//         Check for WRITE/READ data in Reg
// +---------------------------------------------------+
task automatic chk_rd_wr;
input [3:0] master_id;
input [31:0] ref_data, actual_data,qos_cmd ;
input rd_wr_chan;
reg ext_mst_on;
reg qos_regulator;

begin
  $display(" READ/WRITE Check for Master-%0d \n",master_id);
  get_qos_regulator_param(master_id,rd_wr_chan,qos_regulator);
  get_ext_qos_status(master_id,rd_wr_chan,ext_mst_on);
  $display("Value of qos_regulator:%0d ext_mst_on:%0d \n",qos_regulator,ext_mst_on);

  case(qos_cmd) 
    3'b000: 
    begin
      if(actual_data[23:16] == ref_data[23:16] && actual_data[0] == ref_data[0])
       $display("Reg Burstiness PASS- WR_Data:%0h RD_Data:%0h \n",ref_data,actual_data); 
      else if(actual_data == 0 && qos_regulator==0)
       $display("Reg Burstiness PASS -RD_ONLY WR_Data:%0h RD_Data:%0h \n",ref_data,actual_data); 
      else
       $display("ERROR : Master ID:%0d Reg Burstiness FAILED- WR_Data:%0h RD_Data:%0h \n",master_id,ref_data,actual_data); 

     if(actual_data[31:24] != 0 && actual_data[15:1] !=0) 
       $display("ERROR : Master ID:%0d Burstiness Reserved WR FAILED- WR_Data:%0h RD_Data:%0h \n",master_id,ref_data,actual_data); 
    end
    3'b001: 
    begin
      if(actual_data[15:4] == ref_data[15:4] && actual_data[31:20] == ref_data[31:20])
       $display("Reg PEAKRATE PASS- WR_Data:%0h RD_Data:%0h \n",ref_data,actual_data); 
      else if(actual_data==0 && qos_regulator==0)
       $display("Reg PEAKRATE PASS RD_ONLY - WR_Data:%0h RD_Data:%0h \n",ref_data,actual_data); 
      else
       $display("ERROR :  Master ID:%0d Reg PEAKRATE FAILED- WR_Data:%0h RD_Data:%0h \n",master_id,ref_data,actual_data); 
     
      if(actual_data[19:16] != 0 && actual_data[3:0] !=0) 
       $display("ERROR : Master ID:%0d PEAKRATE Reserved WR FAILED- WR_Data:%0h RD_Data:%0h \n",master_id,ref_data,actual_data); 
    end
    3'b010: 
    begin
      if(actual_data[3:0] == ref_data[3:0] && ext_mst_on==0)
        $display("Reg QOS_VALUE PASS- WR_Data:%0h RD_Data:%0h \n",ref_data,actual_data); 
      else if(actual_data[3:0] == 0 && ext_mst_on==1)
        $display("PASS : Reg QOS_VALUEis RD only - WR_Data:%0h RD_Data:%0h \n",ref_data,actual_data); 
      else
        $display("ERROR :  Master ID:%0d Reg QOS_VALUE FAILED- WR_Data:%0h RD_Data:%0h \n",master_id,ref_data,actual_data); 
      
      if(actual_data[31:4] != 0 ) 
       $display("ERROR : Master ID:%0d QOS Value Reserved WR FAILED- WR_Data:%0h RD_Data:%0h \n",master_id,ref_data,actual_data); 
    end
    3'b011 : 
    begin
      if(actual_data[0] == ref_data[0])
       $display("Reg SLV_RDY PASS- WR_Data:%0h RD_Data:%0h \n",ref_data,actual_data);
      else if(actual_data == 0 && qos_regulator ==0)
       $display("Reg SLV_RDY PASS RD_ONLY - WR_Data:%0h RD_Data:%0h \n",ref_data,actual_data);
      else 
       $display("ERROR :  Master ID:%0d Reg SLV_RDY FAILED- WR_Data:%0h RD_Data:%0h \n",master_id,ref_data,actual_data); 
      
      if(actual_data[31:1] != 0 ) 
       $display("ERROR : Master ID:%0d SLV_RDY Value Reserved WR FAILED- WR_Data:%0h RD_Data:%0h \n",master_id,ref_data,actual_data); 

    end
  endcase
end//task begin
endtask

//+------------------------------------------------------------------
//       Task  for performing register Rd/WR - Direct reg access
//+------------------------------------------------------------------
task automatic test_qos_reg_back2back;
input [3:0] masterID;
input rd_wr_chan;

integer status,tag ;
reg [3:0] master_id;
reg [31:0] qos_cmd_burst,qos_cmd_peak_rate,qos_cmd_qos_value,qos_cmd_slv_rdy;
begin // task begin
 master_id = masterID-1; 
 //Generate random data
 //gen_rand_data;
  qos_cmd_burst     = $random(seed);
  qos_cmd_peak_rate = $random(seed);
  qos_cmd_qos_value = $random(seed);
  qos_cmd_slv_rdy   = $random(seed);
$display("Rand Write:qos_cmd_burst:%0h qos_cmd_peak_rate:%0h\n",qos_cmd_burst,qos_cmd_peak_rate);
$display("Rand Write:qos_cmd_qos_value:%0h qos_cmd_slv_rdy:%0h\n",qos_cmd_qos_value,qos_cmd_slv_rdy);

  $display("+-----------------------------------------------------+ \n");
  $display("          Begin back to back reg testing                \n"); 
  $display("+-----------------------------------------------------+ \n");
  
  $display("+-----------------------------------------------------+ \n");
  $display("          Begin back to back WRITES                     \n");
  $display("+-----------------------------------------------------+ \n");
  // Do 4 writes back to back
  cmd_and_data_reg_write(1'b1,master_id,qos_cmd_burst,3'b0,rd_wr_chan);
  cmd_and_data_reg_write(1'b1,master_id,qos_cmd_peak_rate,3'b001,rd_wr_chan);
  cmd_and_data_reg_write(1'b1,master_id,qos_cmd_qos_value,3'b010,rd_wr_chan);
  cmd_and_data_reg_write(1'b1,master_id,qos_cmd_slv_rdy,3'b011,rd_wr_chan);
  
  $display("+-----------------------------------------------------+ \n");
  $display("          Begin back to back READS                     \n");
  $display("+-----------------------------------------------------+ \n");
  // DO 4 back to back for the registers
  cmd_and_data_reg_write(1'b0,master_id,qos_cmd_burst,3'b0,rd_wr_chan);
  cmd_and_data_reg_write(1'b0,master_id,qos_cmd_peak_rate,3'b001,rd_wr_chan);
  cmd_and_data_reg_write(1'b0,master_id,qos_cmd_qos_value,3'b010,rd_wr_chan);
  cmd_and_data_reg_write(1'b0,master_id,qos_cmd_slv_rdy,3'b011,rd_wr_chan);
  
  $display("+------------ Back--Back QOS-REG TEST COMPLETE - PASS ------------+ \n");

end //task begin
endtask

//+------------------------------------------------------------------
//                  Task  for DIRECT REG READ/WRITES
//+------------------------------------------------------------------
 task automatic test_qos_reg_direct;
 input [3:0] masterID;
 integer status,tag;
 reg  [31:0] read_data_frm_reg;
 begin // task begin

  $display("+-----------------------------------------------------+ \n");
  $display("          Begin Direct Reg Read/Writes ....             \n");
  $display("+-----------------------------------------------------+ \n");

  // Write Data into the Data reg
  apb_write(`QOS_DATA_REG_ADDR,32'hFFFF_FFFF); 

  //READ from DATA Reg - Check for values
  apb_read(`QOS_DATA_REG_ADDR,read_data_frm_reg);
  chk_data_cmd_reg(1,32'hFFFF_FFFF, read_data_frm_reg,masterID-1);

  // Write CMD into the reg
  apb_write(`QOS_CMD_REG_ADDR,32'hFFFF_FFFF); 

  // READ CMD Reg - Check for value written
  apb_read(`QOS_CMD_REG_ADDR,read_data_frm_reg);
  chk_data_cmd_reg(0,32'hFFFF_FFFF, read_data_frm_reg,masterID-1);
   
  wait_for_cmd_reg_execute(`QOS_CMD_REG_ADDR,32'hFFFF_FFFF,1'b1);

 end //task begin
 endtask

// +---------------------------------------------------+
//         Check for WRITE/READ data in Reg
// +---------------------------------------------------+
 task automatic chk_data_cmd_reg;
  input data_reg;
  input [31:0] ref_data , actual_data;
  input [3:0] master_id;
 begin
  // Check for Data REG
  if(data_reg==1 && ref_data == actual_data)
   $display("Master ID :%0d:PASS : Data REG write succeded : Ref_data:%0h Actual read data:%0h \n",master_id,ref_data,actual_data);
  else if(data_reg==1 && ref_data!=actual_data)
   $display("Master ID :%0d:ERROR : Data REG write Failed : Ref_data:%0h Actual read data:%0h \n",master_id,ref_data,actual_data);

  // Check the CMD Reg
  if(data_reg ==0) begin
     if(actual_data[31:29] == ref_data[31:29] && actual_data[27:12]==0 && actual_data[11:8] == ref_data[11:8] && actual_data[7] == ref_data[7] && actual_data[6:3]==0 && actual_data[2:0] ==ref_data[2:0]  && actual_data[29] == ref_data[29])
      $display("Master ID :%0d: PASS : CMD REG write succeeded : Ref_data:%0h Actual read data:%0h \n",master_id,ref_data,actual_data);
     else if( (actual_data[31:29] != ref_data[31:29] || actual_data[27:12]!=0 || actual_data[11:8] != ref_data[11:8] || actual_data[7] != ref_data[7] || actual_data[6:3]!=0 || actual_data[2:0] !=ref_data[2:0] || actual_data[29] != ref_data[29]) && ref_data[29]!=0)
      $display("%0t : Master ID :%0d:ERROR : CMD REG write Failed : Ref_data:%0h Actual read data:%0h \n",$time,master_id,ref_data,actual_data);
  end

 end
 endtask

// +---------------------------------------------------+
//              Register SOFT RESET TEST
// +---------------------------------------------------+
 task automatic soft_reset_test;
 input [3:0] masterID;
 integer status,tag;
 reg  [31:0] read_data_frm_reg;
 reg [31:0] init_cmd_value,init_data_reg_value;
 begin
  
   $display("\n-------------- SOFT RESET TEST ----------------\n"); 
   // Stote the initial value of the CMD reg before soft reset
   apb_read(`QOS_CMD_REG_ADDR,init_cmd_value);
   $display("Initial value of CMD Reg before SOFt Reset : %0h \n",init_cmd_value);
   
   //READ from DATA Reg - Check for values
   apb_read(`QOS_DATA_REG_ADDR,init_data_reg_value);
   $display("Initial value of DATA Reg before SOFT Reset : %0h \n",init_data_reg_value);

   // Write CMD into the reg
   apb_write(`QOS_DATA_REG_ADDR,32'hFFFF_FFFF); 
   apb_write(`QOS_CMD_REG_ADDR,32'hFFFF_FFFF); 
   wait_for_cmd_reg_execute(`QOS_CMD_REG_ADDR,32'hFFFF_FFFF,1'b1);

   // READ CMD Reg - Check for value written
   apb_read(`QOS_CMD_REG_ADDR,read_data_frm_reg);

   if(read_data_frm_reg==0)
    $display("Master :%0d Soft RESET - PASS For CMD_REG : Data_read:%0h \n",masterID,read_data_frm_reg);
    else
    $display("ERROR : Master :%0d Soft RESET - FAIL For CMD_REG : Data_read:%0h \n",masterID,read_data_frm_reg);
    
   //READ from DATA Reg - Check for values
   apb_read(`QOS_DATA_REG_ADDR,read_data_frm_reg);

   // make sure Data register not written into
   if(read_data_frm_reg==0)
    $display("Master %0d - Soft Reset PASS on Data Reg : data_write:32'hDFFF_AAAA data_read:%0h \n",masterID,read_data_frm_reg);
    else
    $display("ERROR: Master %0d - Soft Reset failed on Data Reg : data_write:32'hDFFF_AAAA data_read:%0h \n",masterID,read_data_frm_reg);
 end
 endtask

//+-------------------------------------------------------------------------
//            HARD APB RESET TEST - Direct & Indirect default value check
//+-------------------------------------------------------------------------
 task reset_test;
  input rd_wr_chan ;
  input axi_reset;
  integer i;

  reg [31:0] cmd_reg_value;
  reg [31:0] read_burstiness[0:`AXI_NUM_MASTERS],read_peak_rate[0:`AXI_NUM_MASTERS];
  reg [31:0] read_qos_value[0:`AXI_NUM_MASTERS],read_slave_rdy[0:`AXI_NUM_MASTERS];

  integer status,tag;
  reg [31:0] read_data_frm_reg;
  reg ext_mst_on,qos_regulator ;

 begin
  $display("----------- Begin reset_test with RW_CH=%0b ------------\n",rd_wr_chan);
  //Make sure internal registers have some value before reset
  for(i=1;i<=`AXI_NUM_MASTERS;i=i+1) begin
    program_qos_reg_random(i,rd_wr_chan);
    command_reg_write(i,3'b011,32'h1,rd_wr_chan); // make sure '1' is written for slv_rdy
  end//for
 
  //Do APB reset   
   do_reset(axi_reset); 

  // READ CMD Reg - Check for value written
   apb_read(`QOS_CMD_REG_ADDR,read_data_frm_reg);
   check_default_value(1,axi_reset,`QOS_CMD_REG_ADDR,read_data_frm_reg,3'b111);

  //READ from DATA Reg - Check for values
   apb_read(`QOS_DATA_REG_ADDR,read_data_frm_reg);
   check_default_value(1,axi_reset,`QOS_DATA_REG_ADDR,read_data_frm_reg,3'b111);
 
  for(i=1;i<=`AXI_NUM_MASTERS;i=i+1) begin
   do_read(i,3'b000,rd_wr_chan,read_burstiness[i]); 
   do_read(i,3'b001,rd_wr_chan,read_peak_rate[i]); 
   do_read(i,3'b010,rd_wr_chan,read_qos_value[i]); 
   do_read(i,3'b011,rd_wr_chan,read_slave_rdy[i]); 
   get_ext_qos_status(i-1,rd_wr_chan,ext_mst_on);
   get_qos_regulator_param(i-1,rd_wr_chan,qos_regulator);
   // Do default reset check only if qos regulator is present
   if(qos_regulator ==1) begin
     check_default_value(1,axi_reset,`QOS_DATA_REG_ADDR,read_burstiness[i],0);
     check_default_value(1,axi_reset,`QOS_DATA_REG_ADDR,read_peak_rate[i],1);
     check_default_value(1,axi_reset,`QOS_DATA_REG_ADDR,read_slave_rdy[i],3);
   end

   if(ext_mst_on==0) //Check only if ext param in off
     check_default_value(1,axi_reset,`QOS_DATA_REG_ADDR,read_qos_value[i],2);

  end 

 end//begin task
 endtask


//+-------------------------------------------------------------------------
//            Get the status of param _ext for reg rd/wr checks
//+-------------------------------------------------------------------------

 task get_ext_qos_status;
 input [3:0] master_id; 
 input rd_wr_chan;

 output ext_qos_en_wr_chan;
 begin
case(master_id)
4'b0000: 
   begin
     if(rd_wr_chan == 1)
      `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M1)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M1)
    end
4'b0001:
    begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M2)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M2)
    end
4'b0010:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M3)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M3)
   end
4'b0011:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M4)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M4)
   end
4'b0100:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M5)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M5)
   end
4'b0101:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M6)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M6)
   end
4'b0110:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M7)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M7)
   end
4'b0111:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M8)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M8)
   end
4'b1000:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M9)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M9)
   end
4'b1001:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M10)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M10)
   end
4'b1010:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M11)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M11)
   end
4'b1011:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M12)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M12)
   end
4'b1100:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M13)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M13)
   end
4'b1101:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M14)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M14)
   end
4'b1110:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M15)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M15)
   end
4'b1111:
   begin
     if(rd_wr_chan == 1)
     `CHECK_EXT_QOS(`AXI_HAS_AWQOS_EXT_M16)
     else 
      `CHECK_EXT_QOS(`AXI_HAS_ARQOS_EXT_M16)
   end

 endcase
 end//begin-task
 endtask

//+-------------------------------------------------------------------------
//            Get the status of param Regulator for reg rd/wr checks
//+-------------------------------------------------------------------------

 task get_qos_regulator_param;
 input [3:0] master_id; 
 input rd_wr_chan;

 output qos_regulation_rw_en;
 begin
case(master_id)
4'b0000: 
   begin
     if(rd_wr_chan == 1)
      `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M1)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M1)
    end
4'b0001:
    begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M2)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M2)
    end
4'b0010:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M3)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M3)
   end
4'b0011:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M4)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M4)
   end
4'b0100:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M5)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M5)
   end
4'b0101:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M6)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M6)
   end
4'b0110:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M7)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M7)
   end
4'b0111:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M8)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M8)
   end
4'b1000:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M9)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M9)
   end
4'b1001:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M10)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M10)
   end
4'b1010:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M11)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M11)
   end
4'b1011:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M12)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M12)
   end
4'b1100:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M13)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M13)
   end
4'b1101:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M14)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M14)
   end
4'b1110:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M15)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M15)
   end
4'b1111:
   begin
     if(rd_wr_chan == 1)
     `CHECK_QOS_REGULATOR(`AXI_AW_HAS_QOS_REGULATOR_M16)
     else 
      `CHECK_QOS_REGULATOR(`AXI_AR_HAS_QOS_REGULATOR_M16)
   end

 endcase
 end//begin-task
 endtask

//+---------------------------------------------------+
//     Check the default Values after reset
//+---------------------------------------------------+
 task check_default_value;
 input hard_apb_reset;
 input hard_axi_reset; 
 input [31:0] addr,read_default_value;
 input [2:0] cmd;
 reg [255:0] str;
 begin

  if(addr == `QOS_CMD_REG_ADDR && cmd==7) str = "CMD_REG" ;
  else if(addr ==`QOS_DATA_REG_ADDR &&cmd==7) str = "DATA_REG";

  if(cmd==0) str ="BURST_REG";
  else if(cmd==1) str = "PEAK_REG";
  else if(cmd==2) str = "QOS_REG";
  else if(cmd==3) str = "SLVRDY_REG";

  if(read_default_value == 0 && cmd==7)
   $display("The %0s default value check Pass after Hard/Soft Reset - Default Value :%0h  \n",str,read_default_value);
  else if(read_default_value!=0 && cmd !=7 && hard_apb_reset==0 && hard_axi_reset==0)
   $display("PASS - %0s default Soft reset check PASS - Default Value READ :%0h  \n",str,read_default_value);
  else if(read_default_value!=0 && cmd !=7 && hard_apb_reset==1 && hard_axi_reset==0)
   $display("PASS - %0s default Hard reset check PASS -  Value READ :%0h  \n",str,read_default_value);
  else if(read_default_value == 0 && cmd !=7 && hard_axi_reset==1)//Internal reg not to be reset for APB reset
   $display("PASS - %0s Hard reset AXI RESET Internal Reg- PASS -  Value READ :%0h  \n",str,read_default_value);
  else if(read_default_value != 0 && cmd !=7 && hard_axi_reset==1)//Internal reg not to be reset for APB reset
   $display("ERROR - %0s Hard reset AXI RESET TEST Fail  -  Value READ :%0h  \n",str,read_default_value);
  else if(read_default_value == 0 && cmd !=7 && hard_apb_reset==1 && hard_axi_reset==0)//Internal reg not to be reset for APB reset
   $display("ERROR - %0s default value check FAIL  Hard Reset CANNOT reset internal registers - Default Value :%0h  \n",str,read_default_value);
  else if(read_default_value != 0 && cmd !=7 && hard_apb_reset==0 && hard_axi_reset==0)
   $display("ERROR - %0s default value check FAIL after Soft Reset - Default Value :%0h  \n",str,read_default_value);
 end//begin task
 endtask

//+---------------------------------------------------+
//     Indirect Reg READ CMD
//+---------------------------------------------------+
task  automatic do_read;
 input [3:0] master_id;
 input [2:0] qos_cmd;
 input rd_wr_chan;

 output [31:0] data_value;
 reg [31:0] cmd_data,read_data_frm_reg;
 integer status,tag;
 begin
   // Form the command 
   create_command (1'b1,1'b0,master_id-1,rd_wr_chan,qos_cmd,1'b1);

  // Read back the Data Reg
   apb_read(`QOS_DATA_REG_ADDR,read_data_frm_reg);
   $display("%0t: Master :%0d Data READ : %0h QOS_CMD:%0h \n ",$time,master_id, read_data_frm_reg,qos_cmd );
   data_value = read_data_frm_reg ;

 end //begin task
endtask

//+---------------------------------------------------+
//      Hard reset - APB/AXI reset
//+---------------------------------------------------+
task do_reset;
 input axi_reset;
begin
 #30;
 test_DW_axi.presetn = 1'b0;
 if(axi_reset==1)
 test_DW_axi.aresetn = 1'b0;
 #200;
 test_DW_axi.presetn = 1'b1;
 if(axi_reset==1)
 test_DW_axi.aresetn = 1'b1;
end
endtask

//+---------------------------------------------------+
//      Reg test with CMD disable
//+---------------------------------------------------+
task do_cmd_test;
input [3:0] MasterID;
input back2back_test;
input rd_wr_chan;

reg [31:0] qos_cmd_burst,qos_cmd_peak_rate,qos_cmd_qos_value,qos_cmd_slv_rdy;
begin

  $display("-------------------------------------------------------\n");
  $display("            BEGIN Reg TEST without CMD Enable          \n");
  $display("-------------------------------------------------------\n");
 //Generate random data
  qos_cmd_burst     = $random(seed);
  qos_cmd_peak_rate = $random(seed);
  qos_cmd_qos_value = $random(seed);
  qos_cmd_slv_rdy   = $random(seed);
   //Back 2 back enable test  
   if(back2back_test) begin
     test_back2back_cmd_en(MasterID,3'b000,qos_cmd_burst,rd_wr_chan);
     test_back2back_cmd_en(MasterID,3'b000,qos_cmd_burst,rd_wr_chan);
     test_back2back_cmd_en(MasterID,3'b001,qos_cmd_peak_rate,rd_wr_chan);
     test_back2back_cmd_en(MasterID,3'b010,qos_cmd_qos_value,rd_wr_chan);
   end
   else begin
     test_with_cmd_disable(MasterID,3'b011,qos_cmd_slv_rdy,rd_wr_chan);
     test_with_cmd_disable(MasterID,3'b001,qos_cmd_peak_rate,rd_wr_chan);
     test_with_cmd_disable(MasterID,3'b010,qos_cmd_qos_value,rd_wr_chan);
     test_with_cmd_disable(MasterID,3'b011,qos_cmd_slv_rdy,rd_wr_chan);
   end
end
endtask

//+---------------------------------------------------+
//      Reg test with CMD disable
//+---------------------------------------------------+
task test_with_cmd_disable;
input [3:0] MasterID;
input [2:0] qos_cmd;
input [31:0] data_in;
input rd_wr_chan;

reg [255:0] str;
reg [31:0] read_data_frm_reg;
reg [31:0] int_reg_data;
begin
get_string_name(qos_cmd,str);
$display("MasterID-%0d - Starting test_with_cmd_disable for %0s \n",MasterID,str);
//1. Step - To write indirectly to Reg - WR Channel
cmd_and_data_reg_write(1'b1,MasterID-1,data_in,qos_cmd,rd_wr_chan);

//2. Step - Read Back the Peak Reg
cmd_and_data_reg_write(1'b0,MasterID-1,data_in,qos_cmd,rd_wr_chan);

//3. Step - Write Data Reg with different value
apb_write(`QOS_DATA_REG_ADDR,~data_in);

//4. Step - Create Write CMD without enable
create_command(1'b0,1'b1,MasterID,rd_wr_chan,qos_cmd,1'b1);

//5. Step - Create READ CMD 
create_command(1'b1,1'b0,MasterID,rd_wr_chan,qos_cmd,1'b1);

//6. Step - Make sure Data not written as CMD disabled
apb_read(`QOS_DATA_REG_ADDR,read_data_frm_reg);

if(read_data_frm_reg == ~data_in)
 $display("ERROR : Master %0d - CMD Reg updated %0s without Enable Data_read:%0h \n",MasterID,str,read_data_frm_reg);
 else
  $display("PASS - Master %0d - %0s not updated when CMD En is disabled. Read Data:%0h  \n",MasterID,str,read_data_frm_reg);

end //begin-task
endtask

//+---------------------------------------------------+
//      Back to Back CMD Enable Test
//+---------------------------------------------------+
task test_back2back_cmd_en;
input [3:0] MasterID;
input [2:0] qos_cmd;
input [31:0] data_in;
input rd_wr_chan ;

reg [255:0] str;
reg [31:0] read_data_frm_reg;
reg [31:0] int_reg_data;
begin
  get_string_name(qos_cmd,str);
  $display("MasterID-%0d - Starting test_back2back_cmd_en for %0s \n",MasterID,str);
  //1. Step - To write indirectly to Reg - WR Channel without waiting
  apb_write(`QOS_DATA_REG_ADDR,data_in); 
  create_command(1'b1,1'b1,MasterID,rd_wr_chan,qos_cmd,1'b0);
  
  //2. Step - Write Data Reg with different value
  apb_write(`QOS_DATA_REG_ADDR,~data_in);
  create_command(1'b1,1'b1,MasterID,rd_wr_chan,qos_cmd,1'b1);
  
  //3. Step - Create READ CMD to read back data value
  create_command(1'b1,1'b0,MasterID,rd_wr_chan,qos_cmd,1'b1);
  
  //4. Step - Make sure Data not written as CMD disabled
  apb_read(`QOS_DATA_REG_ADDR,read_data_frm_reg);
  
  if(read_data_frm_reg == ~data_in)
   $display("ERROR : Master %0d - CMD Reg updated %0s in back2back CMD_EN- Data_read:%0h \n",MasterID,str,read_data_frm_reg);
   else
    $display("PASS - Master %0d - %0s not updated in back2back CMD_EN - Read Data:%0h  \n",MasterID,str,read_data_frm_reg);
  
end //begin-task
endtask
// +-----------------------------------------------------------------------
//             CMD Reg Error bit generation test
// +-----------------------------------------------------------------------
task cmd_reg_err_bit_gen;
input rd_wr_chan ;
integer num_masters;
integer i;
reg [2:0] qos_cmd;
reg err_bit;

begin
  $display("\n ----------------------------------------------------\n");
  $display("     ERR_BIT GEN TEST FOR NON-EXISTENT MASTER        \n");
  $display("   ----------------------------------------------------\n");
  for(i=`AXI_NUM_MASTERS+1;i<=16;i=i+1) begin
    apb_write(`QOS_DATA_REG_ADDR,32'hFFFF_FFFF); 
    create_command(1'b1,1'b1,i-1,rd_wr_chan,3'b0,1'b0);
    wait_for_err_bit(`QOS_CMD_REG_ADDR,err_bit);
    if(err_bit !=1) 
     $display("ERROR bit test FAIL - For non-existent master:%0d \n",i);
    else
     $display("PASS : Err bit set for Master %0d \n",i);
  end//for

  $display("\n ----------------------------------------------------\n");
  $display("     ERR_BIT GEN TEST FOR NON-EXISTENT QOS COMMANDS  \n");
  $display("   ----------------------------------------------------\n");
  qos_cmd = 3'b100; //Start with non-existent command
  for(i=1;i<=`AXI_NUM_MASTERS;i=i+1) begin
    apb_write(`QOS_DATA_REG_ADDR,32'hFFFF_FFFF); 
    create_command(1'b1,1'b1,i-1,rd_wr_chan,qos_cmd,1'b0);
    wait_for_err_bit(`QOS_CMD_REG_ADDR,err_bit);
    if(err_bit !=1) 
     $display("ERROR Master %0d bit test FAIL - For non-existent Command:%0h \n",i+1,qos_cmd);
    else
     $display("PASS : Err bit set for Non-exsistent command %0d \n",i);
     if(qos_cmd == 3'b111)
      qos_cmd=3'b100;
     else
       qos_cmd = qos_cmd+1;
  end//for
end//begin-task
endtask

// +---------------------------------------------------+
//     Wait for CMD reg to get err bit set
// +---------------------------------------------------+
task automatic wait_for_err_bit;
input [31:0] addr;
output err_bit;
reg [31:0] read_data_frm_reg;
integer tag;

begin
// Wait for IC to reset the bit 31 of cmd_reg
 fork
 begin : task_cmd_wait_1
 forever begin
   repeat (5) @(posedge system_clk);
   apb_read(addr,read_data_frm_reg);
   $display("%0t : READ VALUE of CMD_REG = %0h \n",$time,read_data_frm_reg);
   if(read_data_frm_reg[31] ==0 ) begin
     disable task_timeout_read_fork_1; disable task_cmd_wait_1;
     $display("The bit 31 is RESET by IC .. exiting .. \n"); 
    end
  end
 end
 begin : task_timeout_read_fork_1
  repeat (1000) @(posedge system_clk);
  $display("ERROR : APB WRITE TIMEOUT - QOS DID not reset for ERR bit TEST \n");
  disable task_cmd_wait_1 ;
  $finish; // Error condition if the cmd not written
 end
 join

 err_bit = read_data_frm_reg[28];

end//begin task
endtask

// +---------------------------------------------------+
//      Test Version ID & HW Cfg Reg - Read Only
// +---------------------------------------------------+
task automatic test_version_hwcfg_reg;
reg [31:0] read_data;
begin
// Test version ID Reg
 apb_write(`QOS_VERSION_ID_ADDR,32'hDDCC_ABCD);
 apb_read (`QOS_VERSION_ID_ADDR,read_data);
 if(read_data == 32'hDDCC_ABCD) 
  $display("ERROR: VERSION_ID_REG - RO failed Read_data:%0h \n",read_data);
 else
  $display("PASS : VERSION_ID_REG - Read Only Read_data:%0h \n",read_data);

// Test version ID Reg
 apb_write(`QOS_HW_CFG_ADDR,32'hFFFF_AAAA);
 apb_read (`QOS_HW_CFG_ADDR,read_data);
 if(read_data == 32'hDDCC_ABCD) 
  $display("ERROR: QOS_HW_CFG_REG - RO failed Read_data:%0h \n",read_data);
 else
  $display("PASS : QOS_HW_CFG_REG - Read Only Read_data:%0h \n",read_data);

end//begin-task
endtask

task get_string_name;
input [7:0] reg_in;
output [255:0] str_out;
begin

case(reg_in) 
8'h0 : str_out ="BURSTINESS_REG";
8'h1 : str_out ="PEAKRATE_REG";
8'h2 : str_out ="QOS_REG";
8'h3 : str_out ="SLVRDY_REG";
endcase
end
endtask
