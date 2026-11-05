# Regression test for ::tclapp::linty::vivado_to_linty::run
# Source this file from a Vivado Tcl session.

set app_dir [file normalize [file join [file dirname [info script]] ..]]
set cmd ::tclapp::linty::vivado_to_linty::run
if {[info commands $cmd] eq ""} {
    source [file join $app_dir vivado_to_linty.tcl]
    package require ::tclapp::linty::vivado_to_linty
}

set work [file normalize [file join /tmp vivado_to_linty_tclapp_test]]
file delete -force $work
file mkdir $work
set sv [file join $work top.sv]
set fh [open $sv w]
puts $fh {module top(input wire clk, output wire q); assign q = clk; endmodule}
close $fh

create_project tclapp_test [file join $work proj] -part xc7a35tcpg236-1 -force
add_files -norecurse [list $sv]
set_property TOP top [current_fileset]
$cmd
close_project

set ys [file join $work .linty yosys]
set read_ys [file join $ys read.ys]
set hierarchy [file join $ys hierarchy.ys]
if {![file exists $read_ys] || ![file exists $hierarchy]} {
    error "FAIL: vivado_to_linty did not write the Yosys scripts"
}
set read_text [read [open $read_ys r]]
set hier_text [read [open $hierarchy r]]
if {![string match *top.sv* $read_text]} {
    error "FAIL: read.ys does not read top.sv"
}
if {![string match "*hierarchy -top top*" $hier_text]} {
    error "FAIL: hierarchy.ys does not elaborate top"
}
file delete -force $work
puts "PASS: vivado_to_linty tclapp test"
