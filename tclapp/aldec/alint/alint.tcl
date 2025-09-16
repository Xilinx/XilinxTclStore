package require Tcl 8.5

namespace eval ::tclapp::aldec::alint {
    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
        lappend ::auto_path $home
    }
}

package provide ::tclapp::aldec::alint 1.0
