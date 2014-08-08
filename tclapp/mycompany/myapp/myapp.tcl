package require Tcl 8.4

namespace eval ::tclapp::mycompany::myapp {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
	lappend ::auto_path $home
    }

}
package provide ::tclapp::mycompany::myapp 1.0
# this is a comment
# this is another comment
# this is a 3rd comment line
# this is a 4th comment line
