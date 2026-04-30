#  ------------------------------------------------------------------------
#
#                    (C) COPYRIGHT 2001 - 2014 SYNOPSYS, INC.
#                            ALL RIGHTS RESERVED
#
#  This software and the associated documentation are confidential and
#  proprietary to Synopsys, Inc.  Your use or disclosure of this
#  software is subject to the terms and conditions of a written
#  license agreement between you, or your company, and Synopsys, Inc.
#
# The entire notice above must be reproduced on all authorized copies.
#
#  ------------------------------------------------------------------------
# Revision: $Id: //dwh/DW_ocb/DW_axi_x2x/amba_dev/pkg/pkg_script/DW_axi_x2x.elab.tcl#10 $
# --------------------------------------------------------------------
# Abstract : Post elaboration synthesis intent script for DW_axi_x2x.
#            Mainly setting constraints for conditional ports.
#
# --------------------------------------------------------------------

set clock_mode  [get_configuration_parameter X2X_CLK_MODE]
set sp_sync_d   [get_configuration_parameter X2X_SP_SYNC_DEPTH]
set mp_sync_d   [get_configuration_parameter X2X_MP_SYNC_DEPTH]
set channel_sel [get_configuration_parameter X2X_CH_SEL]
set tz_support [get_configuration_parameter X2X_TZ_SUPPORT]


# Master port clock.
set clock_m "aclk_m"


# If clock_mode is set to asynchronous there will be 2 clocks in the
# X2X, if so generate a seperate slave port clock and constrain 
# slave port ports w.r.t. that clock. Otherwise constrain w.r.t. 
# master port clock.

# 2 asynchronous clocks.
if {$clock_mode == 1 & (($sp_sync_d>0) | ($mp_sync_d>0))} {
  # Generate and constrain slave port clock.
  set clock_s "aclk_s"
  set_port_attribute  $clock_s ClockName $clock_s
  set_clock_attribute $clock_s FixHold   false
  set_clock_attribute $clock_s CycleTime 5.4ns

  set_port_attribute aresetn_s IdealPort True
  set_port_attribute aresetn_s MinInputDelay\[$clock_s\] "=percent_of_period 0"
  set_port_attribute aresetn_s MaxInputDelay\[$clock_s\] "=percent_of_period 0"
} 

# 2 synchronous clocks.
if {$clock_mode == 1 & ($sp_sync_d==0) & ($mp_sync_d==0)} {
  # Generate and constrain slave port clock.
  set clock_s "aclk_s"
  set_port_attribute  $clock_s ClockName $clock_s
  set_clock_attribute $clock_s FixHold   false
  set_clock_attribute $clock_s CycleTime 4ns

  set_port_attribute aresetn_s IdealPort True
  set_port_attribute aresetn_s MinInputDelay\[$clock_s\] "=percent_of_period 0"
  set_port_attribute aresetn_s MaxInputDelay\[$clock_s\] "=percent_of_period 0"
} 
  
# 1 clock.
if {$clock_mode == 0} {
  # Use master port clock. 
  set clock_s "aclk_m"
}

#*****************************************************************************************
# Constraints - Ayschronous Clock Domain Crossing 
#
# Following Methodology is followed for Clock Domain Crossing Signals
# 1. CDC Qualifier Signals 
#    Use set_max_delay constraint (of 1 destination clock period) for qualifier signals 
#    reaching first stage of double synchronizer in qualifier-based synchronizers
# 2. CDC Toggle Qualifier Signals
#    Use set_max_delay constraint (of 1 destination clock period) even for toggle signals 
#    reaching first stage of the BCM21/BCM41 inside a BCM22/BCM23 cell. This ensures 
#    that the pulse-synchronizer will work with minimal delay between two source pulses
# 3. CDC Qualified Data Signals
#    Use set_max_delay constraint (of (# of synchronizer stages - 0.5) * destination clock 
#    period) for qualified (data) signals in qualifier-based synchronizers. 
# 
# NOTE: 
# 1. This assumes the clocks are completely asynchronous and the false path is given 
#    set_max_delay constraint
# 2. The CDC Signals i.e. these false paths are not checked for hold. This is done 
#    through the set_false_path with hold check disabled.
#*****************************************************************************************
if {$clock_mode == 1} {
  if {($sp_sync_d>0) | ($mp_sync_d>0)} {
   # set sp_sync_perc  [expr int(($sp_sync_d - 0.5)*100)] 
   # set mp_sync_perc  [expr int(($mp_sync_d - 0.5)*100)] 

    set sp_sync_perc  [expr int(1 * 100)] 
    set mp_sync_perc  [expr int(1 * 100)] 
    set sp_sync_smdly "=percent_of_period $sp_sync_perc aclk_s"
    set mp_sync_smdly "=percent_of_period $mp_sync_perc aclk_m"

    read_sdc -script "set_clock_groups -asynchronous -group {aclk_m} -allow_paths" 
    read_sdc -script "set_clock_groups -asynchronous -group {aclk_s} -allow_paths" 

    set_false_path -from [find_item -type clock aclk_m] -to [find_item -type clock aclk_s] -hold
    set_max_delay -ignore_clock_latency $sp_sync_smdly -from [find_item -type clock aclk_m] -to [find_item -type clock aclk_s]
    set_min_delay -ignore_clock_latency 0 -from [find_item -type clock aclk_m] -to [find_item -type clock aclk_s]
    
    set_false_path -from [find_item -type clock aclk_s] -to [find_item -type clock aclk_m] -hold
    set_max_delay -ignore_clock_latency $mp_sync_smdly -from [find_item -type clock aclk_s] -to [find_item -type clock aclk_m]
    set_min_delay -ignore_clock_latency 0 -from [find_item -type clock aclk_s] -to [find_item -type clock aclk_m]

    #**************************************************************************************************************
    # Constraints added as part of QTIP check cdc_syn_02 : 26/02/2020
    # These constraints will ensure that only valid Gray codes will be sampled in the destination clock domain.
    # Commented as it was not taken as part of AXIGA2020.
    #**************************************************************************************************************
    #set_max_delay -ignore_clock_latency $mp_sync_smdly -from U_AW_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_PUSH_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_s]
    #set_max_delay -ignore_clock_latency $sp_sync_smdly -from U_AW_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_POP_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_m]
    #set_min_delay -ignore_clock_latency 0 -from U_AW_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_PUSH_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_s]
    #set_min_delay -ignore_clock_latency 0 -from U_AW_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_POP_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_m]

    #set_max_delay -ignore_clock_latency $mp_sync_smdly -from U_W_channel_fifo/*/U_FIFO_CTL/U_PUSH_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_s]
    #set_max_delay -ignore_clock_latency $sp_sync_smdly -from U_W_channel_fifo/*/U_FIFO_CTL/U_POP_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_m]
    #set_min_delay -ignore_clock_latency 0 -from U_W_channel_fifo/*/U_FIFO_CTL/U_PUSH_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_s]
    #set_min_delay -ignore_clock_latency 0 -from U_W_channel_fifo/*/U_FIFO_CTL/U_POP_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_m]

    #set_max_delay -ignore_clock_latency $sp_sync_smdly -from U_AR_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_PUSH_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_m]
    #set_max_delay -ignore_clock_latency $mp_sync_smdly -from U_AR_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_POP_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_s]
    #set_min_delay -ignore_clock_latency 0 -from U_AR_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_PUSH_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_m]
    #set_min_delay -ignore_clock_latency 0 -from U_AR_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_POP_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_s]

    #set_max_delay -ignore_clock_latency $sp_sync_smdly -from U_R_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_PUSH_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_m]
    #set_max_delay -ignore_clock_latency $mp_sync_smdly -from U_R_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_POP_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_s]
    #set_min_delay -ignore_clock_latency 0 -from U_R_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_PUSH_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_m]
    #set_min_delay -ignore_clock_latency 0 -from U_R_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_POP_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_s]

    #set_max_delay -ignore_clock_latency $sp_sync_smdly -from U_B_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_PUSH_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_m]
    #set_max_delay -ignore_clock_latency $mp_sync_smdly -from U_B_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_POP_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_s]
    #set_min_delay -ignore_clock_latency 0 -from U_B_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_PUSH_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_m]
    #set_min_delay -ignore_clock_latency 0 -from U_B_channel_fifo/U_dclk_fifo/U_FIFO_CTL/U_POP_FIFOFCTL/this_addr_g -to [find_item -type clock aclk_s]
  }
 # if {$tz_support == 1} {
 #   set clock_m_qual_smdly "=percent_of_period 100 aclk_m"

 #  set_max_delay $clock_m_qual_smdly -from {U_DW_axi_x2x_tz/U_DW_axi_x2x_bcm21_s2ml_tz_secure_s_i_ssyzr/data_s*} -to [find_item -type clock aclk_m] 
 # }   
}


# Set master port i/o delays.

# Read channels will only exist if X2X_CH_SEL == 0, => both read and
# write channels will exist.

# Read address channel.
if {$channel_sel == 0} {
set mARInputPorts [find_item -type port -filter {PortDirection==in} ar*_m*]
set_port_attribute $mARInputPorts MinInputDelay\[$clock_m\] "=percent_of_period 30"
set_port_attribute $mARInputPorts MaxInputDelay\[$clock_m\] "=percent_of_period 30"

set mAROutputPorts [find_item -type port -filter {PortDirection==out} ar*_m*]
set_port_attribute $mAROutputPorts MinOutputDelay\[$clock_m\] "=percent_of_period 30"
set_port_attribute $mAROutputPorts MaxOutputDelay\[$clock_m\] "=percent_of_period 30"

# Read data channel.
set mRInputPorts [find_item -type port -filter {PortDirection==in} r*_m*]
set_port_attribute $mRInputPorts MinInputDelay\[$clock_m\] "=percent_of_period 30"
set_port_attribute $mRInputPorts MaxInputDelay\[$clock_m\] "=percent_of_period 30"

set mROutputPorts [find_item -type port -filter {PortDirection==out} r*_m*]
set_port_attribute $mROutputPorts MinOutputDelay\[$clock_m\] "=percent_of_period 30"
set_port_attribute $mROutputPorts MaxOutputDelay\[$clock_m\] "=percent_of_period 30"
}


# Set slave port i/o delays.

# Read channels will only exist if X2X_CH_SEL == 0, => both read and
# write channels will exist.
if {$channel_sel == 0} {
# Read address channel.
set sARInputPorts [find_item -type port -filter {PortDirection==in} ar*_s*]
set_port_attribute $sARInputPorts MinInputDelay\[$clock_s\] "=percent_of_period 20"
set_port_attribute $sARInputPorts MaxInputDelay\[$clock_s\] "=percent_of_period 20"

set sAROutputPorts [find_item -type port -filter {PortDirection==out} ar*_s*]
set_port_attribute $sAROutputPorts MinOutputDelay\[$clock_s\] "=percent_of_period 20"
set_port_attribute $sAROutputPorts MaxOutputDelay\[$clock_s\] "=percent_of_period 20"

# Read data channel.
set sRInputPorts [find_item -type port -filter {PortDirection==in} r*_s*]
set_port_attribute $sRInputPorts MinInputDelay\[$clock_s\] "=percent_of_period 20"
set_port_attribute $sRInputPorts MaxInputDelay\[$clock_s\] "=percent_of_period 20"

set sROutputPorts [find_item -type port -filter {PortDirection==out} r*_s*]
set_port_attribute $sROutputPorts MinOutputDelay\[$clock_s\] "=percent_of_period 20"
set_port_attribute $sROutputPorts MaxOutputDelay\[$clock_s\] "=percent_of_period 20"
}


# Write address channel.
set sAWInputPorts [find_item -type port -filter {PortDirection==in} aw*_s*]
set_port_attribute $sAWInputPorts MinInputDelay\[$clock_s\] "=percent_of_period 20"
set_port_attribute $sAWInputPorts MaxInputDelay\[$clock_s\] "=percent_of_period 20"

set sAWOutputPorts [find_item -type port -filter {PortDirection==out} aw*_s*]
set_port_attribute $sAWOutputPorts MinOutputDelay\[$clock_s\] "=percent_of_period 10"
set_port_attribute $sAWOutputPorts MaxOutputDelay\[$clock_s\] "=percent_of_period 10"


# Write data channel.
set sWInputPorts [find_item -type port -filter {PortDirection==in} w*_s*]
set_port_attribute $sWInputPorts MinInputDelay\[$clock_s\] "=percent_of_period 20"
set_port_attribute $sWInputPorts MaxInputDelay\[$clock_s\] "=percent_of_period 20"

set sWOutputPorts [find_item -type port -filter {PortDirection==out} w*_s*]
set_port_attribute $sWOutputPorts MinOutputDelay\[$clock_s\] "=percent_of_period 20"
set_port_attribute $sWOutputPorts MaxOutputDelay\[$clock_s\] "=percent_of_period 20"


# Burst response channel.
set sBInputPorts [find_item -type port -filter {PortDirection==in} b*_s*]
set_port_attribute $sBInputPorts MinInputDelay\[$clock_s\] "=percent_of_period 20"
set_port_attribute $sBInputPorts MaxInputDelay\[$clock_s\] "=percent_of_period 20"

set sBOutputPorts [find_item -type port -filter {PortDirection==out} b*_s*]
set_port_attribute $sBOutputPorts MinOutputDelay\[$clock_s\] "=percent_of_period 20"
set_port_attribute $sBOutputPorts MaxOutputDelay\[$clock_s\] "=percent_of_period 20"


# Constrain sideband ports.

set arsideband [get_configuration_parameter X2X_HAS_ARSB]

if {$arsideband == 1} {
  set arsb [find_item -type port -filter {PortDirection==in} arsideband_m*]
  set_port_attribute $arsb MaxInputDelay\[$clock_m\] "=percent_of_period 30"
  set_port_attribute $arsb MinInputDelay\[$clock_m\] "=percent_of_period 30"
}


if {$arsideband == 1} {
  set arsb [find_item -type port -filter {PortDirection==out} arsideband_s*]
  set_port_attribute $arsb MaxOutputDelay\[$clock_s\] "=percent_of_period 30"
  set_port_attribute $arsb MinOutputDelay\[$clock_s\] "=percent_of_period 30"
}


set awsideband [get_configuration_parameter X2X_HAS_AWSB]

if {$awsideband == 1} {
  set awsb [find_item -type port -filter {PortDirection==in} awsideband_m*]
  set_port_attribute $awsb MaxInputDelay\[$clock_m\] "=percent_of_period 30"
  set_port_attribute $awsb MinInputDelay\[$clock_m\] "=percent_of_period 30"
}


if {$awsideband == 1} {
  set awsb [find_item -type port -filter {PortDirection==out} awsideband_s*]
  set_port_attribute $awsb MaxOutputDelay\[$clock_s\] "=percent_of_period 10"
  set_port_attribute $awsb MinOutputDelay\[$clock_s\] "=percent_of_period 10"
}



set rsideband [get_configuration_parameter X2X_HAS_RSB]

if {$rsideband == 1} {
  set rsb [find_item -type port -filter {PortDirection==out} rsideband_m*]
  set_port_attribute $rsb MaxOutputDelay\[$clock_m\] "=percent_of_period 30"
  set_port_attribute $rsb MinOutputDelay\[$clock_m\] "=percent_of_period 30"
}


if {$rsideband == 1} {
  set rsb [find_item -type port -filter {PortDirection==in} rsideband_s*]
  set_port_attribute $rsb MaxInputDelay\[$clock_s\] "=percent_of_period 30"
  set_port_attribute $rsb MinInputDelay\[$clock_s\] "=percent_of_period 30"
}

set wsideband [get_configuration_parameter X2X_HAS_WSB]

if {$wsideband == 1} {
  set wsb [find_item -type port -filter {PortDirection==in} wsideband_m*]
  set_port_attribute $wsb MaxInputDelay\[$clock_m\] "=percent_of_period 30"
  set_port_attribute $wsb MinInputDelay\[$clock_m\] "=percent_of_period 30"
}

if {$wsideband == 1} {
  set wsb [find_item -type port -filter {PortDirection==out} wsideband_s*]
  set_port_attribute $wsb MaxOutputDelay\[$clock_s\] "=percent_of_period 30"
  set_port_attribute $wsb MinOutputDelay\[$clock_s\] "=percent_of_period 30"
}


set bsideband [get_configuration_parameter X2X_HAS_BSB]

if {$bsideband == 1} {
  set bsb [find_item -type port -filter {PortDirection==out} bsideband_m*]
  set_port_attribute $bsb MaxOutputDelay\[$clock_m\] "=percent_of_period 30"
  set_port_attribute $bsb MinOutputDelay\[$clock_m\] "=percent_of_period 30"
}


if {$bsideband == 1} {
  set bsb [find_item -type port -filter {PortDirection==in} bsideband_s*]
  set_port_attribute $bsb MaxInputDelay\[$clock_s\] "=percent_of_period 30"
  set_port_attribute $bsb MinInputDelay\[$clock_s\] "=percent_of_period 30"
}


set tz_support [get_configuration_parameter X2X_HAS_TZ_SUPPORT]

if {$tz_support == 1} {
  set tz_o [find_item -type port -filter {PortDirection==out} tz_secure_m*]
  set_port_attribute $tz_o MaxOutputDelay\[$clock_m\] "=percent_of_period 30"
  set_port_attribute $tz_o MinOutputDelay\[$clock_m\] "=percent_of_period 30"
}

if {$tz_support == 1} {
  set tz_i [find_item -type port -filter {PortDirection==in} tz_secure_s*]
  set_port_attribute $tz_i MaxInputDelay\[$clock_s\] "=percent_of_period 30"
  set_port_attribute $tz_i MinInputDelay\[$clock_s\] "=percent_of_period 30"
}

set lowpwr_hs_if [get_configuration_parameter X2X_LOWPWR_HS_IF]
if {$lowpwr_hs_if == 1} {
  set_port_attribute csysreq MaxInputDelay\[$clock_m\] "=percent_of_period 20"
  set_port_attribute csysreq MinInputDelay\[$clock_m\] "=percent_of_period 20"
  set_port_attribute cactive MaxOutputDelay\[$clock_m\] "=percent_of_period 20"
  set_port_attribute cactive MinOutputDelay\[$clock_m\] "=percent_of_period 20"
  set_port_attribute csysack MaxOutputDelay\[$clock_m\] "=percent_of_period 20"
  set_port_attribute csysack MinOutputDelay\[$clock_m\] "=percent_of_period 20"
}


# Create multi cycle paths from fifo memory registers to fifo data out sampling registers
# in quasi sync configs. We can do this because although there is no synchronisation on
# the pointers, there is a register on the empty status output bit in the FIFO.
#JS_DEBUG
#if {$clock_mode == 1 & ($sp_sync_d==0) & ($mp_sync_d==0)} {
  #set_multicycle -setup 2 -through {U_AW_channel_fifo/U_dclk_fifo_U_FIFO_MEM_mem_reg* } -to aclk_s
  #set_multicycle -setup 2 -through {U_AW_channel_fifo/U_dclk_fifo_U_FIFO_MEM_mem_reg* } -to aclk_s
  #set_multicycle -setup 2 -through {U_AR_channel_fifo/U_dclk_fifo_U_FIFO_MEM_mem_reg* } -to aclk_s
  #set_multicycle -setup 2 -through {U_AR_channel_fifo/U_dclk_fifo_U_FIFO_MEM_mem_reg* } -to aclk_s
  #set_multicycle -setup 2 -through {U_W_channel_fifo/U_dclk_fifo0_U_FIFO_MEM_mem_reg* } -to aclk_s
  #set_multicycle -setup 2 -through {U_W_channel_fifo/U_dclk_fifo0_U_FIFO_MEM_mem_reg* } -to aclk_s

  #set_multicycle -setup 2 -through {U_R_channel_fifo/U_dclk_fifo_U_FIFO_MEM_mem_reg* } -to aclk_m
  #set_multicycle -setup 2 -through {U_R_channel_fifo/U_dclk_fifo_U_FIFO_MEM_mem_reg* } -to aclk_m
  #set_multicycle -setup 2 -through {U_B_channel_fifo_U_dclk_fifo_U_FIFO_MEM_mem_reg* } -to aclk_m
  #set_multicycle -setup 2 -through {U_B_channel_fifo_U_dclk_fifo_U_FIFO_MEM_mem_reg* } -to aclk_m
#}
