package require Vivado 2012.2

namespace eval ::tclapp::xilinx::utils {
    namespace export get_7vlx_parts
}

proc ::tclapp::xilinx::utils::get_7vlx_parts {} {
    # Summary : Get a list of all the 7vlx parts with package tff484 and speedgrade -2

    # Argument Usage:
    # none

    # Return Value:
    # list of parts
    
    set parts [get_parts xc7vlx*tff484-2]
    puts $parts
    # prints: xc7vlx75tff484-2 xc7vlx130tff484
    
    return $parts
}
