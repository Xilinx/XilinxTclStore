####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_data_through_pins
}


proc ::tclapp::xilinx::designutils::get_data_through_pins {timing_path} {
  # Summary : Return the data pins of a single timing path

  # Argument Usage:
  # timing_path : Single timing path from get_timing_paths

  # Return Value:
  # List of pins

  # Categories: xilinxtclstore, designutils
  
  set count_flag 0
  set rpt_tim [report_timing -no_nets -no_header -return_string -of $timing_path]


  foreach line [split $rpt_tim \n] {
    #puts $line
    #puts $count_flag
    if { [regexp {\-\-\-\-\-\-} $line ] } {
      incr count_flag
    }
    if { $count_flag == 2 } {
      if { [regexp {^(.*)\s+(r|f)\s+(.*)} $line all firstpart rise_fall pin] } {
        set pin [get_pins $pin]
        lappend intermediate_pins $pin
        #puts "Found Pin: $pin"
      }
    }
  }

  return $intermediate_pins
}
