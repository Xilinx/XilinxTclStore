# tclapp/siemens/questa_cdc/questa_cdc.tcl
package require Tcl 8.5

namespace eval ::tclapp::mentor::questa_cdc {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
    }
    ## Keep an environment variable with the path of the script
    set env(QUESTA_CDC_TCL_SCRIPT_PATH) [file normalize [file dirname [info script]]]
}
package provide ::tclapp::mentor::questa_cdc 1.7
