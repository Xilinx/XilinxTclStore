# tclapp/mentor/questa_cdc/questa_cdc.tcl
package require Tcl 8.5

namespace eval ::tclapp::mentor::questa_cdc {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
    }

}
package provide ::tclapp::mentor::questa_cdc 1.1
