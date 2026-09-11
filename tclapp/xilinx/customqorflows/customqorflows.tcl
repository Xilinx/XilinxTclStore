####################################################################################
#
# customqorflows.tcl (customqorflows package loader)
#
# Script created on 03/30/2026 by Madhur Chhabra, AMD
#
####################################################################################

namespace eval ::tclapp::xilinx::customqorflows {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
    }

}
package provide ::tclapp::xilinx::customqorflows 1.10
