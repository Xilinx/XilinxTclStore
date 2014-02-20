####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2014 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
# Company:        Xilinx, Inc.
# Created by:     Nik Cimino
# 
# Created Date:   01/31/14
# Script name:    junit.tcl
# Procedures:     ?
# Tool Versions:  Vivado 2013.4
# Description:    Xilinx (Tcl) Reporting API
# Dependencies:   ?
#                 
# Notes:          
#     ?
# 
# Getting Started:
#     % package require ::tclapp::xilinx::junit
#     % ?
#
####################################################################################################

# title: Xilinx (Tcl) Reporting API

namespace eval ::tclapp::xilinx::junit {

  # Allow Tcl to find tclIndex
  variable home [file join [pwd] [file dirname [info script]]]
  if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
  }

}

package provide ::tclapp::xilinx::junit 1.0
