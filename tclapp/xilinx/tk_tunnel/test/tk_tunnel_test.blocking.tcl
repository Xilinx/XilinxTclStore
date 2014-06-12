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


package require struct

if { [ info exists ::env(RDI_DEVKIT) ] } {
  set launch_shell [ file join $::env(RDI_DEVKIT) "lnx64" "tcl-8.5.14" "bin" "tclsh8.5" ]
} else {
  set launch_shell "tclsh85"
}

set server_file [ file normalize [ file join $test_dir ".." "server" "start.tcl" ] ]

::tclapp::xilinx::tk_tunnel::launch_server $launch_shell $server_file

::tclapp::xilinx::tk_tunnel::start_client

open_checkpoint [file join [file dirname [info script]] "design1.dcp"]

if { [info commands tk_tunnel_test] == "tk_tunnel_test" } { tk_tunnel_test destroy }

# stack is used here to hold a sequential list of commands to execute
#  last command should not pop
#  stack is: last in first out
::struct::stack tk_tunnel_test

tk_tunnel_test push {
	puts "net selection test blocking"
	select_objects [get_nets ff_stage[1].ff_channel[0].ff/O1]
	set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::ask "Is the net ff_stage\[1\].ff_channel\[0\].ff/O1 selected?"}]
	puts "Answer: $answer"
	# eval [tk_tunnel_test pop]
}

tk_tunnel_test push {
	puts "tile selection test"
	select_objects [get_tiles INT_R_X1Y65]
	set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::ask "Is the tile INT_R_X1Y65 selected?"}]
	puts "Answer: $answer"
	eval [tk_tunnel_test pop]
}

tk_tunnel_test push {
	puts "bel selection test"
	select_objects [get_bels SLICE_X10Y10/D6LUT]
	set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::ask "Is the bel SLICE_X10Y10/D6LUT selected?"}]
	puts "Answer: $answer"
	eval [tk_tunnel_test pop]
}

tk_tunnel_test push {
	puts "site selection test"
	select_objects [get_sites SLICE_X0Y0]
	set answer [::tclapp::xilinx::tk_tunnel::rexec_wait {::tclapp::xilinx::tk_tunnel::ask "Is the site SLICE_X0Y0 selected?"}]
	puts "Answer: $answer"
	eval [tk_tunnel_test pop]
}

eval [tk_tunnel_test pop]
