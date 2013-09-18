####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_host_platform
}
    
proc ::tclapp::xilinx::designutils::get_host_platform {} {
  # Summary : return the host platform (windows|unix)
  
  # Argument Usage:
  
  # Return Value:
  # either "windows" or "linux" depending on which platform Vivado is running on
  
  # Categories: xilinctclstore, designutils

  if {[info exists tcl_platform(platform)]} {
    # this is a general tcl platform variable
    return $tcl_platform(platform)
  } else {
    # else try to determine from the PATH environment variable
    set path $::env(PATH)
    if {[regexp {^[A-Za-z]:} $path]} {
      return {windows}
    } else {
      return {unix}
    }
  }
}
