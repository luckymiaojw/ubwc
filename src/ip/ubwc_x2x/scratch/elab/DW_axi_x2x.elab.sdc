#-----------------------------------------------------------------------
# 
# Release version  : 
# File Version     :        $Revision: #5 $ 
# Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/pkg/pkg_script/DW_axi_x2x.elab.sdc#5 $
#  Abstract     :               Specify multi cycle paths for DW_axi_x2x
#                               quasi sync mode.
#
#-----------------------------------------------------------------------
#  set sdc_version 1.1

  set clock_mode  [get_configuration_parameter X2X_CLK_MODE]
  set sp_sync_d   [get_configuration_parameter X2X_SP_SYNC_DEPTH]
  set mp_sync_d   [get_configuration_parameter X2X_MP_SYNC_DEPTH]

# jstokes, 5.8.2010, crm 8000409386 has been filed with DC team to understand why these constraints are not working
# with our synthesis flow. In the mean time the constraints are documented in the DB.
# Create multi cycle paths from fifo memory registers to fifo data out sampling registers
# in quasi sync configs. We can do this because although there is no synchronisation on
# the pointers, there is a register on the empty status output bit in the FIFO.
  #if {$clock_mode == 1 & ($sp_sync_d==0) & ($mp_sync_d==0)} {
    #set_multicycle -setup 2 -from [get_clocks aclk_m] -through {U_AW_channel_fifo/U_dclk_fifo_U_FIFO_MEM_mem_reg* } -to [get_clocks aclk_s] -end
    #set_multicycle -setup 2 -from [get_clocks aclk_m] -through {U_AR_channel_fifo/U_dclk_fifo_U_FIFO_MEM_mem_reg* } -to [get_clocks aclk_s] -end
    #set_multicycle -setup 2 -from [get_clocks aclk_m] -through {U_W_channel_fifo/U_dclk_fifo0_U_FIFO_MEM_mem_reg* } -to [get_clocks aclk_s] -end
#
    #set_multicycle -setup 2 -from [get_clocks aclk_s] -through {U_R_channel_fifo/U_dclk_fifo_U_FIFO_MEM_mem_reg* } -to [get_clocks aclk_m] -end
    #set_multicycle -setup 2 -from [get_clocks aclk_s] -through {U_B_channel_fifo_U_dclk_fifo_U_FIFO_MEM_mem_reg* } -to [get_clocks aclk_m] -end
#
    #set_multicycle -setup 2 -from {U_AR_channel_fifo/U_dclk_fifo_U_FIFO_MEM_mem_reg_0__3_/*} -to {U_DW_axi_x2x_sp/U_DW_axi_x2x_sp_ar/U_resizer_acache_pl_r_reg_0_/*}
    #set_multicycle -hold 1 -from {U_AR_channel_fifo/U_dclk_fifo_U_FIFO_MEM_mem_reg_0__3_/*} -to {U_DW_axi_x2x_sp/U_DW_axi_x2x_sp_ar/U_resizer_acache_pl_r_reg_0_/*}

  #}
