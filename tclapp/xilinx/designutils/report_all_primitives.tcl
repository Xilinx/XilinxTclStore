package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export report_all_primitives
}

proc ::tclapp::xilinx::designutils::report_all_primitives {} {
  # Summary : Reports all primitives (LIB_CELL) in the design

  # Argument Usage:

  # Return Value:
  # 0 if succeeded or TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  set prim_list [get_property LIB_CELL [get_cells -hier -filter {IS_PRIMITIVE}]]
  foreach prim $prim_list {incr count($prim)}
  foreach prim [lsort -unique $prim_list] {puts "$prim: $count($prim)"}
  return 0
}
