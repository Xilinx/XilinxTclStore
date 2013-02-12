####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export getLeafCells
}

proc ::tclapp::xilinx::designutils::getLeafCells { {inst *} } {
    # Summary : get the leave cells of an instance
    
    # Argument Usage:
    # [inst=*] : instance

    # Return Value:
    # list of leaf cells
    
    if {$inst != "*"} {
        set inst $inst/*
    }
    set leafCells [list]
    foreach cell [get_cells $inst] {
        set isPrim [get_property IS_PRIMITIVE $cell]
        if {!$isPrim} {
            getLeafCells $cell
        } else {
            set type [get_property LIB_CELL $cell]
            if {$type != "VCC" && $type != "GND"} {
                lappend leafCells $cell
            }
        }
    }
    #foreach cell $leafCells {
    #  puts "leaf cell: $cell"
    #}
    return $leafCells
}
####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
