####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export report_all_primitives
}

proc ::tclapp::xilinx::designutils::report_all_primitives {} {
  # Summary : reports all primitives (LIB_CELL) in the design

  # Argument Usage:

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  set prim_list [get_property LIB_CELL [get_cells -hier -filter {IS_PRIMITIVE}]]
  foreach prim $prim_list {incr count($prim)}
  foreach prim [lsort -unique $prim_list] {puts "$prim: $count($prim)"}
  return 0
}
