package require Vivado 2013.1

namespace eval ::tclapp::xilinx::utils {
    namespace export sort_pins_by_direction
}

proc ::tclapp::xilinx::utils::sort_pins_by_direction { { site RAMB36_X0Y0 } } {
    # Summary : get all pins on a site and sort them by direction

    # Argument Usage:
    # [site=RAMB36_X0Y0] : site to use
    
    # Return Value:
    # none
    
    set ram_pins [device::get_pins -of_object [get_sites $site]]
    unset -nocomplain ram_inputs
    unset -nocomplain ram_outputs
    unset -nocomplain ram_bidirs
    foreach ram_pin $ram_pins {
        if {[string equal "1" [get_property IS_INPUT $ram_pin]]} {lappend ram_inputs $ram_pin}
        if {[string equal "1" [get_property IS_OUTPUT $ram_pin]]} {lappend ram_outputs $ram_pin}
        if {[string equal "1" [get_property IS_BIDIR $ram_pin]]} {lappend ram_bidirs $ram_pin}
    }
}
