package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_leaf_cells
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::get_leaf_cells
#------------------------------------------------------------------------
# Proc to export
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::get_leaf_cells { {pattern *} } {
  # Summary : Get all the leave cells below an instance
  
  # Argument Usage:
  # [pattern = *] : Hierarchical instance name pattern

  # Return Value:
  # list of leaf cells objects
  
  # Categories: xilinxtclstore, designutils

  uplevel [concat ::tclapp::xilinx::designutils::get_leaf_cells::get_leaf_cells $pattern]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::get_leaf_cells { 
  variable leafCells [list]
} ]

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::get_leaf_cells::get_leaf_cells
#------------------------------------------------------------------------
# 
#------------------------------------------------------------------------

proc ::tclapp::xilinx::designutils::get_leaf_cells::get_leaf_cells { {inst *} } {
  # Summary : get the leave cells of an instance
  
  # Argument Usage:
  # [inst = *] : Hierarchical instance name pattern

  # Return Value:
  # list of leaf cells objects
  
  # Categories: xilinxtclstore, designutils

  variable leafCells
  if {$inst != "*"} {
    set inst $inst/*
  }
  set leafCells [list]
  getLeafCells $inst
  # Convert all cell names to first class Tcl object
  set leafCells [get_cells -quiet $leafCells]
  # Return the list of cells
  return $leafCells
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::get_leaf_cells::getLeafCells
#------------------------------------------------------------------------
# 
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::get_leaf_cells::getLeafCells {pattern} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, designutils

  
  variable leafCells
  set leafCells [concat $leafCells [get_cells -quiet $pattern -filter {IS_PRIMITIVE && (REF_NAME!=VCC) && (REF_NAME!=GND)}] ]
  set hierCells [get_cells -quiet $pattern -filter {!IS_PRIMITIVE && (REF_NAME!=VCC) && (REF_NAME!=GND)}]
  foreach cell $hierCells {
    getLeafCells $cell/*
  }
  return 0
}
