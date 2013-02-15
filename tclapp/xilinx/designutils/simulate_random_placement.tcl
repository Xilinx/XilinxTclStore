####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export getRndWeight strToSeed netWeightRnd
}

    
proc ::tclapp::xilinx::designutils::getRndWeight { seed {max 3} } {
    # Summary :  to simulate random placement seed:

    # Argument Usage:
    # seed : seed for rng
    # [max=3] : max

    # Return Value:
    # random weight
    
    # takes an integer seed and returns a random integer
    # between 1 and 3
    # increase max to increase random weight range
    set rnd [expr {srand($seed)}]
    set rnd [expr {$max * $rnd}]
    set rnd [expr int(ceil($rnd))]
    
    return $rnd
}


proc ::tclapp::xilinx::designutils::strToSeed {net} {
    # Summary : a quick and dumb way to generate a seed from the net name

    # Argument Usage:
    # net : net to get name from

    # Return Value:
    # seed for rng
    
    set seed [list]
    for {set i 0} {$i < [string length $net]} {incr i} {
        scan [string index $net $i] %c seedIncr
        set seed ${seed}$seedIncr
    }
    return $seed
}


proc ::tclapp::xilinx::designutils::netWeightRnd { {nets {}} } {
    # Summary : top proc

    # Argument Usage:
    # [nets={}] : nets

    # Return Value:
    # none
    
    if {[llength $nets] == 0} {
        set nets [get_nets -hier *]
    }
    foreach net $nets {
        set seed [strToSeed $net]
        set weight [getRndWeight $seed]
        set_property weight $weight [get_nets $net]
    }
}

