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

# Raw Tk example
rexec {
  tk::toplevel .window_rexec; \
  wm title .window_rexec "New from rexec"; \
  wm geometry .window_rexec 300x200-5+40; \
  wm resizable .window_rexec 0 0; \
}

rexec "source [file normalize [file join [file dirname [info script]] {tk.tcl}]]"

set answer [rexec_wait {open_file}]
puts "Answer: $answer"

set answer [rexec_wait {save_file}]
puts "Answer: $answer"

set answer [rexec_wait {choose_dir}]
puts "Answer: $answer"

set answer [rexec_wait {choose_color}]
puts "Answer: $answer"

set answer [rexec_wait {ask "Are you sure you want to do this?"}]
puts "Answer: $answer"

set answer [rexec_wait {ok "Are you sure you want to do this?"}]
puts "Answer: $answer"

set answer [rexec_wait {ask_or_cancel "Are you sure you want to do this?"}]
puts "Answer: $answer"

while {$answer != "retry"} {
  set answer [rexec_wait {failed "Operation failed!"}]
  puts "Answer: $answer"
}

set answer [rexec_wait {msg "Have a nice day!"}]
puts "Answer: $answer"
