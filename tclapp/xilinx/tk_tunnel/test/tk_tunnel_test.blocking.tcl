set file_dir [file normalize [file dirname [info script]]]
set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]
puts "== Unit Test directory: $file_dir"
puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"

lappend auto_path $::env(XILINX_TCLAPP_REPO)

package require struct
package require ::tclapp::xilinx::tk_tunnel
namespace import ::tclapp::xilinx::tk_tunnel::*

#   Make sure that tclsh is pointing to a Tcl/Tk 8.5 installation
launch_server
#   else use
# launch_server "/usr/bin/tclsh8.5"

start_client

read_checkpoint [file join [file dirname [info script]] "design1.dcp"]

if { [info commands tk_tunnel_test] == "tk_tunnel_test" } { tk_tunnel_test destroy }

::struct::stack tk_tunnel_test

tk_tunnel_test push {
	puts "net selection test blocking"
	select_objects [get_nets ff_stage[1].ff_channel[0].ff/O1]
	set answer [rexec_wait {ask "Is the net ff_stage\[1\].ff_channel\[0\].ff/O1 selected?"}]
	puts "Answer: $answer"
	# eval [tk_tunnel_test pop]
}

tk_tunnel_test push {
	puts "tile selection test"
	select_objects [get_tiles INT_R_X1Y65]
	set answer [rexec_wait {ask "Is the tile INT_R_X1Y65 selected?"}]
	puts "Answer: $answer"
	eval [tk_tunnel_test pop]
}

tk_tunnel_test push {
	puts "bel selection test"
	select_objects [get_bels SLICE_X10Y10/D6LUT]
	set answer [rexec_wait {ask "Is the bel SLICE_X10Y10/D6LUT selected?"}]
	puts "Answer: $answer"
	eval [tk_tunnel_test pop]
}

tk_tunnel_test push {
	puts "site selection test"
	select_objects [get_sites SLICE_X0Y0]
	set answer [rexec_wait {ask "Is the site SLICE_X0Y0 selected?"}]
	puts "Answer: $answer"
	eval [tk_tunnel_test pop]
}

eval [tk_tunnel_test pop]
