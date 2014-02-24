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

puts "Starting server..."

if { [ info tclversion ] != "8.5" } {
  puts "The tk_tunnel package was designed to run with Tcl/Tk 8.5\n\
    \tDetected tcl version: '[info tclversion]'\n\
    \tYou can point to a Tcl/Tk 8.5 installation with:\n\
    \tlaunch_server '/usr/bin/tclsh8.5'\n\
    (press return to continue, and cancel the client)" 
  gets stdin
  exit
}

# Add the Xilinx Tcl libraries to the regular Tcl shell
lappend auto_path [file normalize [file join $::env(XILINX) .. PlanAhead tps tcl tcllib1.11.1]]

# Add this package to the regular Tcl shell
set file_dir [file dirname [info script]]
set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. ..]]
puts "== Tk Tunnel Directory: $file_dir"
puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"

lappend auto_path $::env(XILINX_TCLAPP_REPO)

package require ::tclapp::xilinx::tk_tunnel
namespace import ::tclapp::xilinx::tk_tunnel::*

start_server
# hide_server_start

vwait ::tclapp::xilinx::tk_tunnel::local_wait_on

puts "server finished."

exit
