package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export report_hier_util
}

proc ::tclapp::xilinx::designutils::report_hier_util {{pattern {*}}} {
  # Summary : Report the cell utilization below hierarchical instances

  # Argument Usage:
  # [pattern= * ] : Pattern of hierarchical cells

  # Return Value:
  # 0
  # TCL_ERROR if an error happened

  # Categories: xilinxtclstore, designutils

  if {$pattern == {*}} {
    set listHierCells [get_cells -quiet -filter "!IS_PRIMITIVE" ]
  } else {
    # Look for cells at the current level and below
    set listHierCells [get_cells -quiet -hier $pattern -filter "!IS_PRIMITIVE" ]
  }
  if {$listHierCells == {}} {
    error " error - no hierarchical cell matches $pattern"
  }
  
  # Initialize the table object
  set table [::tclapp::xilinx::designutils::prettyTable create]
  $table header { {Hierarchical Cell} {# Leaf Cells} {# LUT} {% LUT} {# RAMB} {% RAMB} {# DSP} {% DSP} {# FF} {% FF} }

  set cellList [get_cells -quiet -hierarchical -filter {IS_PRIMITIVE}]
  set numCells [llength $cellList]
  # Get all the available sites in the device to place the primitives
  set numBelDSP [llength [get_bels *DSP*]]
  set numBelLUT [llength [get_bels *LUT*]]
  set numBelFF [llength [get_bels *FF*]]
  set numBelBRAM [llength [get_bels *RAMB*]]
  foreach hierCell $listHierCells {
    set childList [get_cells -quiet -hierarchical -filter "NAME =~ $hierCell/* && IS_PRIMITIVE"]
    set numChild [llength $childList]
    set numLUT [llength [filter $childList {REF_NAME =~ LUT*}]]
    set percentLUT [format {%.1f} [expr 100.0 * double($numLUT) / double($numBelLUT)]]
    set numBRAM [llength [filter $childList {REF_NAME =~ RAMB*}]]
    set percentBRAM [format {%.1f} [expr 100.0 * double($numBRAM) / double($numBelBRAM)]]
    set numDSP [llength [filter $childList {REF_NAME =~ DSP*}]]
    set percentDSP [format {%.1f} [expr 100.0 * double($numDSP) / double($numBelDSP)]]
    set numFF [llength [filter $childList {REF_NAME =~ FD*}]]
    set percentFF [format {%.1f} [expr 100.0 * double($numFF) / double($numBelFF)]]
    $table addrow [list $hierCell $numChild $numLUT $percentLUT $numBRAM $percentBRAM $numDSP $percentDSP $numFF $percentFF ]
  }

  # Print table and summary
  $table configure -title [format "Utilization Summary\n-------------------\n  Total cells: %s\n  FF Bels: %s\n  LUT Bels: %s\n  DSP Bels: %s\n  BRAM Bels: %s" \
                                  $numCells \
                                  $numBelFF \
                                  $numBelLUT \
                                  $numBelDSP \
                                  $numBelBRAM ]
  puts [$table print]\n

  # Destroy the table objects to free memory
  catch {$table destroy}

  return 0
}
