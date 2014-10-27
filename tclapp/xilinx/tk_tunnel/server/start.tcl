####################################################################################
#
# server/start.tcl (start Tk server)
#
# Script created on 11/20/2012 by Nik Cimino (Xilinx, Inc.)
#
# 2012 - version 1.0 (rev. 1)
#  * initial version
#
####################################################################################

# 
# Getting Started:
#   This script is the default called by the launch_server command.
#
#   The purpose of this file is to be sourced by a Tcl/Tk 8.5 shell to start the Tk server, e.g.
#       ::tclapp::xilinx::tk_tunnel::start_server
#       ::tclapp::xilinx::tk_tunnel::hide_server_start
#       vwait ::tclapp::xilinx::tk_tunnel::local_wait_on
#   
#   This is just a default server launch script, and users may create their own.
#
#   The launch_server command can be passed a different launch server_file:
#       launch_server "/usr/bin/tclsh8.5" "~/start_server.tcl"
#
#   Alternatively, the user could also write their own launch_server command:
#		exec cmd.exe /c start cmd /k "/usr/bin/tclsh8.5" "~/start_server.tcl" &   # windows
#		exec xterm -iconic -e "/usr/bin/tclsh8.5" "~/start_server.tcl" &          # linux
#		

# This file is executed by the server to start the Tk listner

proc start_tcl_server {} {

  # Validate Tcl Version
  if { [ info tclversion ] != "8.5" } {
    error "The tk_tunnel package was designed to run with Tcl/Tk 8.5\n\
      \tDetected tcl version: '[info tclversion]'\n\
      \tYou can point to a Tcl/Tk 8.5 installation with:\n\
      \tlaunch_server '/usr/bin/tclsh8.5'\n" 
  }

  # Add this package to the regular Tcl shell
  set file_dir [ file dirname [ info script ] ]
  set app_dir [ file normalize [ file join $file_dir .. ] ]
  if { ! [ info exists ::env(XILINX_TCLAPP_REPO) ] } {
    set ::env(XILINX_TCLAPP_REPO) [ file normalize [ file join $app_dir .. .. .. ] ]
  }

  # Add the Xilinx Tcl libraries to the regular Tcl shell
  lappend auto_path [ file normalize [ file join $::env(XILINX_VIVADO) tps tcl tcllib1.11.1 ] ]
  # Add the paths to auto_path
  lappend auto_path [ file normalize $::env(XILINX_TCLAPP_REPO) ]

  puts "== This Launch Script:\n  [ info script ]"
  puts "== Repository directory:\n  $::env(XILINX_TCLAPP_REPO)"
  #puts "== Tk Tunnel Directory:\n  $app_dir"
  #puts "== Vivado:\n  $::env(XILINX_VIVADO)"
  #puts "== Working Dir:\n  [ pwd ]"
  #puts "== Auto path:\n\ \ [ join $auto_path \n\ \ ]\n"

  # Not sure why, but the package require needs to be done at the top-level
  # This used to work fine at this level, something changed in regular Tcl
  uplevel #0 { 
    lappend auto_path $::env(XILINX_TCLAPP_REPO)
    package require ::tclapp::xilinx::tk_tunnel
  }

  ::tclapp::xilinx::tk_tunnel::start_server
  # ::tclapp::xilinx::tk_tunnel::hide_server_start

  vwait ::tclapp::xilinx::tk_tunnel::local_wait_on

}

puts "Starting server..."
catch { start_tcl_server } _output
puts $_output

set bAutoClose 1

if { $bAutoClose } {
  # Wait for 10 seconds before close
  puts "Server terminated, shell will close in 10 seconds."
  set wait_on {}
  after 10000 { set wait_on "next" }
  vwait wait_on
} else {
  # Else wait forever
  puts "Server terminated, press 'Enter' to exit."
  gets stdin
}

exit

