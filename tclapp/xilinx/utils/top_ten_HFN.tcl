package require Vivado 2013.1

namespace eval ::tclapp::xilinx::utils {
    namespace export topTenHFN
}

proc ::tclapp::xilinx::utils::topTenHFN {} {
    # Summary : proc to list top ten fanout values and associated nets

    # Argument Usage:
    # none

    # Return Value:
    # none
    
    # get only parent nets
    set nets [lsort -uniq [get_property PARENT [get_nets -hier *]]]

    # build an array: fanout values are keys, lists of nets with each
    # fanout value are the elements
    set fanouts [list]
    set netFan [dict create]
    puts "Processing [llength $nets] nets..."
    foreach net $nets {
        set loads [expr {[get_property FLAT_PIN_COUNT [get_nets $net]] - 1}]
        if {$loads > 0} {
            if {[dict exists $netFan $loads]} {
                dict append netFan $loads " $net"
            } else {
                dict set netFan $loads $net
            }
            if {[lsearch $fanouts $loads] < 0} {
                lappend fanouts "$loads"
            }
        }
    }

    # sort and print out the top ten fanout values
    set fanouts [lsort -integer -decreasing $fanouts]
    set maxRpt [llength $fanouts]
    if {$maxRpt > 10} {
        set maxRpt 10
    }
    puts "fanout  net"
    puts "------  ------"
    for {set i 0} {$i < $maxRpt} {incr i} {
        set loads [lindex $fanouts $i]
        set nets [dict get $netFan $loads]
        foreach net $nets {
            puts [format "%6d  %s" $loads $net]
        }
    }
}
