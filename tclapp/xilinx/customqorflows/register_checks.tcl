####################################################################################
#
# register_checks.tcl (customqorflows reeegistering and sourcing all checks)
#
# Script created on 08/30/2026 by Madhur Chhabra, AMD
#
####################################################################################

namespace eval ::tclapp::xilinx::customqorflows {

    variable home [file join [pwd] [file dirname [info script]]]

    proc register_all_checks {args} {

        variable home

        # Source the common utilities for customqorflows
        source [file join $home common common.tcl]

        # Source the RQS checks for customqorflows
        source [file join $home customrqschecks rqs_checks.tcl]

        # Source the RQA checks for customqorflows
        source [file join $home customrqachecks rqa_checks.tcl]

    }
}