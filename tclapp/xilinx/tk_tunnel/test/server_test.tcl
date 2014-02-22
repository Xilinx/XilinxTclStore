set file_dir [ file normalize [ file dirname [ info script ] ] ]
set ::env(XILINX_TCLAPP_REPO) [ file normalize [ file join $file_dir .. .. .. .. ] ]
puts "== Unit Test directory: $file_dir"
puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"

lappend auto_path [ file join $::env(XILINX_TCLAPP_REPO) "tclapp" ]

package require ::tclapp::xilinx::tk_tunnel 1.1
namespace import ::tclapp::xilinx::tk_tunnel::*

set launch_shell "tclsh85"

# Make sure that tclsh is pointing to a Tcl/Tk 8.5 installation
#set procid [ launch_server ]
# else use
#set procid [ launch_server $launch_shell ]

# Manual override of launch_server for this test, using tclsh85 packaged with Git
if { [ auto_execok $launch_shell ] == "" } {
  error "Unable to find tclsh using '${launch_shell}' open this file and edit the exec line or change the script to use launch_server:\n[ info script ]"
}
set server_file [ file join $::env(XILINX_TCLAPP_REPO) "tclapp" "xilinx" "tk_tunnel" "server" "start.tcl" ]
set procid [ exec [ auto_execok cmd.exe ] /k $launch_shell ${server_file} & ]

start_client

# Asynchronous : broadcasts from client using server back to client and sets global variable a to 1
puts "Having the server set clients \$::a = "
rexec {broadcast {set ::a 1}}
wait; # 500 ms
puts "The clients \$::a = "
rexec {broadcast {puts $::a}}
wait; # 500 ms
puts "Puts \$::a = "
puts $::a

if { $::a != 1 } {
  error "sent from client to server a broadcast command that should have set \$::a to 1, instead found: '$::a'"
}

# Synchronous : tells the server to execute 'return 2' and client to wait for the response
set answer [rexec_wait {return 2}]
puts "Answer: $answer"
set expected 2


if { $answer != $expected } {
  error "rexec_wait did not return the expected value '${expected}', instead found '${answer}'"
}

# Synchronous : tells the server to ask and wait for the response
#set answer2 [rexec_wait {ask "Are you having fun?"}]
#puts "Answer2: $answer2"
# Disabled: cannot have interactive for auto testing

if { $::tcl_platform(platform) == "unix" } {
  exec [ auto_execok kill ] -9 $procid
} else {
  exec [ auto_execok taskkill ] /F /PID $procid
}

puts "Done. Success."

exit

