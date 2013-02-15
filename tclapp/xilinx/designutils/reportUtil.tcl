####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export reportUtilByHier
}

proc ::tclapp::xilinx::designutils::reportUtilByHier {{pattern *}} {
    # Summary : get all leaf-level placeable instances in the design

    # Argument Usage:
    # [pattern=*] : filter

    # Return Value:
    # none
    
    set cellList [get_cells * -hierarchical -filter "IS_PRIMITIVE == 1"]
    set numCells [llength $cellList]
    # now get all the available sites in the device to place the primitives
    set numBelDSP [llength [device::get_bels *DSP*]]
    set numBelLUT [llength [device::get_bels *LUT*]]
    set numBelFF [llength [device::get_bels *FF*]]
    set numBelBRAM [llength [device::get_bels *BRAM*]]
    puts "Total placeable instances:  $numCells"
    puts "Total FF Bels:  $numBelFF"
    puts "Total LUT Bels:  $numBelLUT"
    puts "Total DSP Bels:  $numBelDSP"
    puts "Total BRAM Bels:  $numBelBRAM"
    # get all hierarchical instances below the specified pattern
    puts "hier,numChild,numLUT,percentLUT,numBRAM,percentBRAM,numDSP,percentDSP,numFF,percentFF"
    foreach hier [get_cells $pattern -filter "IS_PRIMITIVE == 0" ] {
        set childList [get_cells -hierarchical -filter "NAME =~ $hier/* && IS_PRIMITIVE == 1"]
        set numChild [llength $childList]
        set numLUT [llength [filter $childList {lib_cell =~ LUT*}]]
        set percentLUT [expr $numLUT / $numBelLUT]
        set numBRAM [llength [filter $childList {lib_cell =~ BRAM*}]]
        set percentBRAM [expr $numBRAM / $numBelBRAM]
        set numDSP [llength [filter $childList {lib_cell =~ DSP*}]]
        set percentDSP [expr $numDSP / $numBelDSP]
        set numFF [llength [filter $childList {lib_cell =~ FD*}]]
        set percentFF [expr $numFF / $numBelFF]
        puts "$hier,$numChild,$numLUT,$percentLUT,$numBRAM,$percentBRAM,$numDSP,$percentDSP,$numFF,$percentFF"
    }
}

