set appName {xilinx::tk_tunnel}
  
set listInstalledApps [::tclapp::list_apps]

set test_dir [file normalize [file dirname [info script]]]
puts "== Test directory: $test_dir"

set tclapp_repo [file normalize [file join $test_dir .. .. ..]]
puts "== Application directory: $tclapp_repo"

if {[lsearch -exact $listInstalledApps $appName] != -1} {
  # Uninstall the app if it is already installed
  ::tclapp::unload_app $appName
}

# Install the app and require the package
catch "package forget ::tclapp::${appName}"
::tclapp::load_app $appName
package require ::tclapp::${appName}
  
# Start the unit tests
puts "script is invoked from $test_dir"


if { [ info exists ::env(RDI_DEVKIT) ] } {
  set launch_shell [ file join $::env(RDI_DEVKIT) "lnx64" "tcl-8.5.14" "bin" "tclsh8.5" ]
} else {
  set launch_shell "tclsh85"

}
#   Make sure that tclsh is pointing to a Tcl/Tk 8.5 installation
::tclapp::xilinx::tk_tunnel::launch_server $launch_shell
#   else use
# launch_server "/usr/bin/tclsh8.5"
 
::tclapp::xilinx::tk_tunnel::start_client

# Raw Tk example
::tclapp::xilinx::tk_tunnel::rexec {
  tk::toplevel .window_rexec; \
  wm title .window_rexec "New from rexec"; \
  wm geometry .window_rexec 300x200-5+40; \
  wm resizable .window_rexec 0 0; \
}

::tclapp::xilinx::tk_tunnel::rexec "source [file normalize [file join [file dirname [info script]] {tk.tcl}]]"

set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::open_file}]
puts "Answer: $answer"

set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::save_file}]
puts "Answer: $answer"

set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::choose_dir}]
puts "Answer: $answer"

set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::choose_color}]
puts "Answer: $answer"

set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::ask "Are you sure you want to do this?"}]
puts "Answer: $answer"

set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::ok "Are you sure you want to do this?"}]
puts "Answer: $answer"

set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::ask_or_cancel "Are you sure you want to do this?"}]
puts "Answer: $answer"

while {$answer != "retry"} {
  set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::failed "Operation failed!"}]
  puts "Answer: $answer"
}

set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::msg "Have a nice day!"}]
puts "Answer: $answer"
