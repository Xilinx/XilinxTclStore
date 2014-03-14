package require Tcl 8.5

namespace eval ::tclapp::mycompany::template {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
      lappend ::auto_path $home
    }

}
package provide ::tclapp::mycompany::template 1.0
