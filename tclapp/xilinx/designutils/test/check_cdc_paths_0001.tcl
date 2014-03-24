# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]
set unit_test [file rootname [file tail [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"
puts "== Unit Test name: $unit_test"

# Set the Name to the name of the script
set name [file rootname [file tail [info script]]]

# Create in-memory project
create_project $name -in_memory

add_files -fileset sources_1 "$file_dir/src/bench16/bench16_netlist.v"
add_files -fileset constrs_1 "$file_dir/src/bench16/bench16.xdc"
link_design -part xc7k70tfbg484-3 -top bench16

# Run the write_slr_pblock_xdc script and verify that no error was reported
if {[catch { ::tclapp::xilinx::designutils::check_cdc_paths } catchErrorString]} {
    close_project
    error [format " -E- Unit test $name failed: %s" $catchErrorString]   
}

close_project

return 0
