############################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2014 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
############################################################################
#
# tk_tunnel.tcl (allow Tcl to find tclindex and provide package version 1.0)
# 
# Getting Started:
#     % package require ::tclapp::xilinx::tk_tunnel
#     % namespace import ::tclapp::xilinx::tk_tunnel::*
#     % launch_server "/usr/bin/tclsh8.5"
#     % start_client
#     % rexec { tk::toplevel .w; wm title .w "New Window"; }
#

package require Tcl 8.5
catch {package require Tk} 
namespace eval ::tclapp::xilinx::tk_tunnel {
  # Allow Tcl to find tclIndex
  variable home [file join [pwd] [file dirname [info script]]]
  if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
  }
}
package provide ::tclapp::xilinx::tk_tunnel 1.1
