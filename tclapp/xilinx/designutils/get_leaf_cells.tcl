####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_leaf_cells
}

#------------------------------------------------------------------------
# ::tclapp::xilinx::designutils::report_clock_interaction
#------------------------------------------------------------------------
# Proc to export
#------------------------------------------------------------------------
proc ::tclapp::xilinx::designutils::get_leaf_cells { args } {
  # Summary : get all the leave cells below an instance
  
  # Argument Usage:
  # [inst=*] : instance

  # Return Value:
  # list of leaf cells
  
  uplevel [concat ::tclapp::xilinx::designutils::get_leaf_cells::get_leaf_cells $args]
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
  # [inst=*] : instance

  # Return Value:
  # list of leaf cells
  
  variable leafCells
  if {$inst != "*"} {
    set inst $inst/*
  }
  set leafCells [list]
  getLeafCells $inst
  # Convert all cell names to first class Tcl object
  set leafCells [get_cells $leafCells]
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
  
  variable leafCells
  set leafCells [concat $leafCells [get_cells $pattern -filter {IS_PRIMITIVE && (REF_NAME!=VCC) && (REF_NAME!=GND)}] ]
  set hierCells [get_cells $pattern -filter {!IS_PRIMITIVE && (REF_NAME!=VCC) && (REF_NAME!=GND)}]
  foreach cell $hierCells {
    getLeafCells $cell/*
  }
  return 0
}
