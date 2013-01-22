package require Vivado 2012.2

namespace eval ::tclapp::xilinx::utils {
    namespace export getRndWeight strToSeed netWeightRnd
}

    
proc ::tclapp::xilinx::utils::getRndWeight { seed {max 3} } {
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


proc ::tclapp::xilinx::utils::strToSeed {net} {
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


proc ::tclapp::xilinx::utils::netWeightRnd { {nets {}} } {
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
