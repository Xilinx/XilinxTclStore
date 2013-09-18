####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export report_cells_loc
}
    
proc ::tclapp::xilinx::designutils::report_cells_loc { {comp_type "ALL"} } {
  # Summary : report the location of cells matching a REF_NAME pattern
  
  # Argument Usage:
  # [comp_type="ALL"] : REF_NAME pattern. "ALL" matches any cell
  
  # Return Value:
  # 0
  
  # Categories: xilinctclstore, designutils

  # Description:
  # By default this will print all the placed
  # components if the comp is not specified
  # It will also print unplaced components if any
  
  # Initialize the table object
  set table [::tclapp::xilinx::designutils::prettyTable create {Fanout Summary}]
  $table header [list {Lib Cell} {Cell} {LOC}]

  set placed 0
  set unplaced 0
  # Get cells from current level and below
#   set cells [get_cells -hier -filter {IS_PRIMITIVE}]
  # Get cells from current level only
  set cells [get_cells -filter {IS_PRIMITIVE}]
  foreach cell $cells {
    set ref_name [get_property -quiet REF_NAME $cell]
    if {($ref_name == {GND}) || ($ref_name == {VCC})} {
      continue
    }
    if {![string match $comp_type $ref_name] &&
        ![string match "ALL" $comp_type]} {
      # Skip cells that are not of interesr
      continue
    }
    set loc [get_property -quiet LOC $cell]
    if {$loc == {}} {
      incr unplaced
      set loc {-}
    } else {
      incr placed
    }
    $table addrow [list $ref_name $cell $loc]
  }
  # Sort the table by LOC: the unplaced cells show first
#   $table sort +loc 
  $table sort +2
  puts [$table print]
  puts "\n # placed cells: $placed"
  puts " # unplaced cells: $unplaced"

  # Destroy the table object to free memory
  catch {$table destroy}

  return 0
}
