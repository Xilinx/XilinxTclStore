package require Tcl 8.4

namespace eval ::tclapp::mycompany::myapp2 {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
	lappend ::auto_path $home
    }

}
package provide ::tclapp::mycompany::myapp2 1.0
