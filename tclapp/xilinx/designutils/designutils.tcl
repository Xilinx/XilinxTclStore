
source [file join  [file dirname [info script]] common.tcl]

namespace eval ::tclapp::xilinx::designutils {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
        lappend ::auto_path $home
    }

}

package provide ::tclapp::xilinx::designutils 1.27
