####################################################################################################
# COPYRIGHT NOTICE
# Copyright 2001-2013 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# 
# Created Date:   01/25/2013
# Script name:    projutils.tcl
# Procedures:     write_project_tcl
# Tool Versions:  Vivado 2013.1
# Description:    This script is used to write a Tcl script for re-building the project.
# 
# Getting Started:
#     % tclapp::load_app xilinx::projutils -namespace projutils
#     % write_project_tcl 
#
####################################################################################################


# title: Vivado Project Re-Build Tcl Script

#package require Tcl 8.5

namespace eval ::tclapp::xilinx::projutils {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
	lappend ::auto_path $home
    }

}

package provide ::tclapp::xilinx::projutils 1.0
