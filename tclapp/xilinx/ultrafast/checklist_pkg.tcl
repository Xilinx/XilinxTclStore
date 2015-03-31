
source [file join  [file dirname [info script]] checklist.tcl]

namespace eval ::tclapp::xilinx::ultrafast {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
        lappend ::auto_path $home
    }

}

package provide ::tclapp::xilinx::ultrafast 1.7

