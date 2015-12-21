package require Tcl 8.5
#~ package require Vivado 1.2014.2
package require Vivado 1.2014.4

namespace eval ::tclapp::icl::protoip {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
      lappend ::auto_path $home
    }

}
package provide ::tclapp::icl::protoip 1.4
