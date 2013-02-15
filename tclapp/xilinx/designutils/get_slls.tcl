####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_slls
}

proc ::tclapp::xilinx::designutils::get_slls { {slr *} } {
    # Summary : returns all the sll node objects in the device

    # Argument Usage:
    # [slr=*] : default is across all SLRs - allowable values for slr are * or an integer for the specifc SLR ID
    
    # Return Value:
    # returns all the sll node objects in the device
    
    set sllList [list]
    if {$slr == "*"} {
        set slvTiles [get_tiles T_TERM_INT_SLV*]
    } else {
        set slvTiles [get_tiles T_TERM_INT_SLV* -filter "SLR_REGION_ID == $slr"]
    }
    foreach tile $slvTiles {
        foreach node [get_nodes -filter "COST_CODE_NAME == VLONG12" -of $tile] {
            set wireList [get_wires -of $node]
            # SLLs have a large number of wires - normal vlongs have < 20
            if {[llength $wireList] > 100} {
                #	    puts "DEBUG:  SLL - $node"
                lappend sllList $node
            }
        }
    }
    return $sllList
}

