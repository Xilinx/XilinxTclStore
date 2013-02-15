####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export generate_cost_table
}

proc ::tclapp::xilinx::designutils::generate_cost_table { {runToCopy ""} {costTableRange 1:10} } {
    # Summary : create a cost table
    
    # Argument Usage:
    # [runToCopy=""] :
    # [costTableRange = 1:10] : range
    
    # Return Value:
    # none
    
    if {$runToCopy == ""} {
        set currRun [lindex [get_runs impl_*] 0]
    } else {
        set currRun [get_runs $runToCopy]
    }
    set start [lindex [split $costTableRange {:}] 0]
    set end [lindex [split $costTableRange {:}] 1]
    set synthRun [get_property PARENT $currRun]
    set strategy [get_property STRATEGY $currRun]
    for {set x $start} {$x <= $end} {incr x} {
        set r ${currRun}_costTable$x 
        create_run $r -parent_run $synthRun -strategy $strategy -flow {ISE 13}
        config_run $r -program map -option -t -value $x
        config_run $r -program map -option -timing -value true      
    }
}

