set file_dir [file normalize [file dirname [info script]]]

puts "== Unit Test directory: $file_dir"
#set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]

#puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
#lappend auto_path $::env(XILINX_TCLAPP_REPO)

set name "xsim_0001"

create_project $name ./$name -force
add_files -fileset sources_1 "$file_dir/src/top.v"
add_files -fileset sim_1 "$file_dir/src/tb.v"
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
#launch_simulation -batch
close_project
