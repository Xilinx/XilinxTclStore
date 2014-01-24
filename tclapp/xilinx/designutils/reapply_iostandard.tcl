####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export reapply_iostandard
}

proc ::tclapp::xilinx::designutils::reapply_iostandard {} {
  # Summary : this command queries the tool-chosen defaults from implementation
  # and "apply" them so it looks like the user did it from the beginning.
  # This complies with the bit export restriction that all ios be LOCd and 
  # explicitly set to an IO Standard

  # Argument Usage:

  # Return Value:
  # 0
  
  # Categories: xilinxtclstore, designutils

  foreach port [get_ports] {
   set_property IOSTANDARD [get_property IOSTANDARD $port] $port
   set_property LOC [get_property LOC $port] $port
  }
  return 0
}

