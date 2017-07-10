set file_dir [file normalize [file dirname [info script]]]

puts "== Unit Test directory: $file_dir"
set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]

puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
lappend auto_path $::env(XILINX_TCLAPP_REPO)

set name "bpsvvs_0001"

create_project -force $name ./$name
add_files -copy_to ./$name/sources -force -fileset sources_1 "$file_dir/src/bp_install_check.v"
update_compile_order -fileset sources_1
launch_runs synth_1 impl_1
wait_on_run [current_run]

::tclapp::bluepearl::bpsvvs::generate_bps_project
if { ![file exists "./$name/bp_install_check.bluepearl_generated.tcl"] } {
    error "TEST_FAILED"
}
::tclapp::bluepearl::bpsvvs::update_vivado_into_bps
if { ![file exists "./$name/bp_install_check.execfile.tcl/"] } {
    error "TEST_FAILED"
}
if { ![file exists "./$name/$name.runs/impl_1/bps_timing_report.txt"] } {
    error "TEST_FAILED"
}
if { ![file exists "./$name/$name.runs/impl_1/bps_power_report.txt"] } {
    error "TEST_FAILED"
}
if { ![file exists "./$name/$name.runs/impl_1/bps_utilization_report.txt"] } {
    error "TEST_FAILED"
}
close_project

puts "TEST_PASSED"
