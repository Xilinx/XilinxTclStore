set file_dir [file normalize [file dirname [info script]]]

puts "== Unit Test directory: $file_dir"
set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]

puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
lappend auto_path $::env(XILINX_TCLAPP_REPO)

set name "riviera_0001"

create_project -force $name ./$name
add_files -copy_to ./$name/sources -force -fileset sources_1 "$file_dir/src/uut.v"
add_files -copy_to ./$name/sources -force -fileset sim_1 "$file_dir/src/testbench.v"
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property TARGET_SIMULATOR Riviera [current_project]
launch_simulation -batch
close_project
if { [file exists "./$name/$name.sim/sim_1/behav/dataset.asdb"] } {
	puts "TEST_PASSED"
} else {
	error "TEST_FAILED"
}
