set file_dir [file normalize [file dirname [info script]]]

puts "== Unit Test directory: $file_dir"
set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]
puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
lappend auto_path $::env(XILINX_TCLAPP_REPO)

#package require ::tclapp::xilinx::projutils
#namespace import ::tclapp::xilinx::projutils::*

set name "test_0001"
create_project $name ./$name
add_files -fileset sources_1 "$file_dir/src/top.v"
write_project_tcl $name.tcl
close_project
