# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"

# Set the Name to the name of the script
set name [file rootname [file tail [info script]]]

create_project $name -in_memory

# add_files -fileset sources_1 "$file_dir/src/bench16/bench16.v"
# add_files -fileset sources_1 "$file_dir/src/bench16/mux2.v"
# add_files -fileset sources_1 "$file_dir/src/bench16/mmcm0_clk_wiz.v"
# add_files -fileset constrs_1 "$file_dir/src/bench16/bench16.xdc"
# synth_design -top bench16 -part xc7k70tfbg484-3 -flatten rebuilt

add_files -fileset sources_1 "$file_dir/src/bench16/bench16_netlist.v"
add_files -fileset constrs_1 "$file_dir/src/bench16/bench16.xdc"
link_design -part xc7k70tfbg484-3 -top bench16

if {[catch { set result [::tclapp::xilinx::ultrafast::check_pll_connectivity -return_string] } errorstring]} {
  error [format " -E- Unit test $name failed: %s" $errorstring]
}

close_project

return 0
