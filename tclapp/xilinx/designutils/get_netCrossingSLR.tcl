####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export get_netCrossingSLR
}

proc ::tclapp::xilinx::designutils::get_netCrossingSLR { } {
    # Summary : get the nest crossing an SLR

    # Argument Usage:
    # none

    # Return Value:
    # list of crossing nets
    
    # returns all 
    set nets [get_nets]
    set netCrossing [list]
    foreach net $nets {
        # make sure we start with a clean list of SLRs for each net in the design
        array set sllList {}
        # query all the sites of all the placed calls attached to this net
        set siteList [get_sites -of [get_cells -of $net -filter {IS_PRIMITIVE && LOC != ""}]]
        foreach site $siteList {
            # query the SLR for all the placed sites - and store in an associative array
            set sll [get_property SLR_REGION_ID $site]
            set sllList($sll) 1
        }
        if {[llength [array names $sllList]] > 1} {
            # the cells on this net are placed in more than 1 SLR so save it
            lappend netCrossing $net
        }
        array unset sllList
    }
    return $netCrossing
}
####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
