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

    # Source the common utilities for customqorflows
    source [file join $home common common.tcl]

    # Source the RQS checks for customqorflows
    source [file join $home customrqschecks rqs_checks.tcl]

    # Source the RQA checks for customqorflows
    source [file join $home customrqachecks rqa_checks.tcl]

}
package provide ::tclapp::xilinx::customqorflows 1.01
