####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_cell_count
}
    
proc ::tclapp::xilinx::designutils::get_cell_count {} {
    # Summary : get cell count
    
    # Argument Usage:
    # none
    
    # Return Value:
    # returns count of cells
    
    set count 0
    foreach ins [get_cells -filter {lib_cell =~ "FD*"}] {
        set Qpin [get_pins "$ins/Q"]
        set Qnet [get_nets -of_object $Qpin]
        set pins [get_pins -leaf -filter "direction != OUT" -of_object $Qnet]
        set fan  [llength $pins]
        incr count
        puts "instance: $ins ; pins: $Qpin  ; nets: $Qnet ; fanout = $fan";
    }
    
    puts "=> $count instances"

    return count
}
####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
