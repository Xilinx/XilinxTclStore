package require Vivado 2012.2

namespace eval ::tclapp::xilinx::utils {
    namespace export findRpms
}

proc ::tclapp::xilinx::utils::findRpms {} {
    # Summary : find rpms

    # Argument Usage:
    # none

    # Return Value:
    # none
    
    global rpms
    global rpmCells
    set rpmCount 0
    foreach cell [get_cells -hier *] {
        set rpm [get_property RPM $cell]
        if {$rpm != {}} {
            if {[lsearch $rpms $rpm] < 0} {
                lappend rpms $rpm
                puts "Found new RPM $rpm"
                incr rpmCount
            }
            if {![get_property IS_PRIMITIVE $cell]} {
                set cell [getLeafCells $cell]
            }
            dict lappend rpmCells $rpm $cell
            #puts " added cells $cell"
        }
    }
    puts "Found $rpmCount RPMs"
}
