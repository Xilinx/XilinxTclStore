####################################################################################################
# Company:        Xilinx, Inc.
# Created by:     Raj Klair
# 
# Created Date:   25/01/2013
# Script name:    bldproj.tcl
# Procedures:     write_project_tcl
# Tool Versions:  Vivado 2013.1
# Description:    This script is used to write a Tcl script for re-building the project.
# 
# Getting Started:
#     % tclapp::load_app xilinx::bldproj -namespace bldproj
#     % write_project_tcl 
#
####################################################################################################


# title: Vivado Project Re-Build Tcl Script

#package require Tcl 8.5

namespace eval ::tclapp::xilinx::bldproj {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
	lappend ::auto_path $home
    }

}

package provide ::tclapp::xilinx::bldproj 1.0
