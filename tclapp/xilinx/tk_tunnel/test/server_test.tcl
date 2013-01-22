set file_dir [file normalize [file dirname [info script]]]
set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]
puts "== Unit Test directory: $file_dir"
puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"

lappend auto_path $::env(XILINX_TCLAPP_REPO)

package require ::tclapp::xilinx::tk_tunnel
namespace import ::tclapp::xilinx::tk_tunnel::*

#   Make sure that tclsh is pointing to a Tcl/Tk 8.5 installation
launch_server
#   else use
# launch_server "/usr/bin/tclsh8.5"

start_client

# Asynchronous : broadcasts from client using server back to client and sets global variable a to 1
puts "Having the server set clients \$::a = "
rexec {broadcast {set ::a 1}}
wait
puts "The clients \$::a = "
rexec {broadcast {puts $::a}}
wait
puts "Puts \$::a = "
puts $::a

# Synchronous : tells the server to execute 'return 2' and client to wait for the response
set answer [rexec_wait {return 2}]
puts "Answer: $answer"

# Synchronous : tells the server to ask and wait for the response
set answer2 [rexec_wait {ask "Are you having fun?"}]
puts "Answer2: $answer2"

# exit
