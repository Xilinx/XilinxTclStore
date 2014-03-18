package require Tcl 8.4

namespace eval ::tclapp::topic::dyplo {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
	lappend ::auto_path $home
    }

}
package provide ::tclapp::topic::dyplo 0.1
