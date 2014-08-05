package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::incrementalcompile {
    namespace export get_reused_cells
}

proc ::tclapp::xilinx::designutils::get_reused_cells {} {
  # Summary : get reused cells

  # Argument Usage:

  # Return Value:
  # list of reused cells

  # Categories: xilinxtclstore, incrementalcompile

  set sel_cells [get_cells -filter { REUSE_STATUS=="Reused" } -hierarchical ]
  return $sel_cells
}
