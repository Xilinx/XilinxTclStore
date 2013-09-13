####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export report_parts
}

proc ::tclapp::xilinx::designutils::report_parts { {pattern *} } {
  # Summary : report all the parts in the current project

  # Argument Usage:
  # pattern : pattern for part names

  # Return Value:
  # 0
  
  # Initialize the table object
  set table [::tclapp::xilinx::designutils::prettyTable create {Summary of all parts}]
  $table header { PART LUT  SLICE DSP RAM MMCM PCI GB IO PACK }
  
  foreach part [lsort -dictionary [get_parts -quiet $pattern]] {
    set numRAM [get_property -quiet BLOCK_RAMS $part]
    set numIO [get_property -quiet AVAILABLE_IOBS $part]
    set numDSP [get_property -quiet DSP $part]
    set numLUT [get_property -quiet LUT_ELEMENTS $part]
    set numMMCM [get_property -quiet MMCM $part]
    set numSLICE [get_property -quiet SLICES $part]
    set numPCI [get_property -quiet PCI_BUSES $part]
    set PACKAGE [get_property -quiet PACKAGE $part]
    set numGB [get_property -quiet GB_TRANSCEIVERS $part]
    set numFF [get_property -quiet FLIPFLOPS $part]
    $table addrow [list $part $numLUT $numSLICE $numDSP $numRAM $numMMCM $numPCI $numGB $numIO $PACKAGE ]
  }
  
  puts [$table print]\n

  # Destroy the table objects to free memory
  catch {$table destroy}

  return 0
}


