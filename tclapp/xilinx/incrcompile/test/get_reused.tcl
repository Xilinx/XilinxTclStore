# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]
set unit_test [file rootname [file tail [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"
puts "== Unit Test name: $unit_test"

# Set the Name to the name of the script
set name [file rootname [file tail [info script]]]

# Load the Design Checkpoint for the specific test
open_checkpoint "$file_dir/src/routed.dcp"

if {[llength [::tclapp::xilinx::incrcompile::get_reused -cells ]] == 0 } {
    close_design
    error [format " -E- Unit test $name failed: %s" "Zero reused cells found" ]   
}

if {[llength [::tclapp::xilinx::incrcompile::get_non_reused -cells ]] == 0 } {
    close_design
    error [format " -E- Unit test $name failed: %s" "Zero non reused cells found" ]   
}

close_design

return 0
