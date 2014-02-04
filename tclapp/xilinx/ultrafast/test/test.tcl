####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require ::tclapp::xilinx::ultrafast
set path [file dirname [info script]]
puts "script is invoked from $path"
source [file join $path check_pll_connectivity_0001.tcl]
source [file join $path create_cdc_reports_0001.tcl]
source [file join $path report_clock_topology_0001.tcl]
source [file join $path report_io_reg_0001.tcl]
source [file join $path report_reset_signals_0001.tcl]
