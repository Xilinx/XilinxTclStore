####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::utils {
    namespace export get_netRoutedCrossingSLR
}

proc ::tclapp::xilinx::utils::get_netRoutedCrossingSLR { } {
    # Summary : get routed nets crossing SLR

    # Argument Usage:
    # none

    # Return Value:
    # returns all crossing nets
    
    set nets [get_nets]
    set netCrossing [list]
    foreach net $nets {
        set nodeList [get_nodes -of $net -filter "COST_CODE_NAME == VLONG12"]
        if {[llength $nodeList] > 0} {
            # found a net with VLONG (very long line) routing on it - now check to see if it is a SLL:
            foreach node $nodeList {
                if {[llength [get_wires -of $node]] > 100} {
                    #SLLs are VLONG12s with more than 100 wire shapes so capture this net in a list
                    lappend netCrossing $net
                }
            }
        }
        
        return $netCrossing
    }
}
####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
