# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]
set unit_test [file rootname [file tail [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"
puts "== Unit Test name: $unit_test"

# Set the Name to the name of the script
set name [file rootname [file tail [info script]]]

open_checkpoint $file_dir/test.dcp

# Run the add_probe and verify that no error was reported
if {[catch { ::tclapp::xilinx::debugutils::add_probe -net inst_1/tmp_q[0] -loc H10 -port myprobe1 -iostandard LVCMOS18} catchErrorString]} {
    close_design
    error [format " -E- Unit test $name failed: %s" $catchErrorString]   
}

if {[catch { ::tclapp::xilinx::debugutils::add_probe -net inst_1/tmp_q[1] -loc H10 -port myprobe1} catchErrorString]} {
    close_design
    error [format " -E- Unit test $name failed: %s" $catchErrorString]   
}

# if {[catch { ::tclapp::xilinx::debugutils::add_probe -net inst_1/tmp_q[0] -loc E12 -port rst_n} catchErrorString]} {
#     close_design
#     error [format " -E- Unit test $name failed: %s" $catchErrorString]   
# }
# 
# if {[catch { ::tclapp::xilinx::debugutils::add_probe -net inst_1/tmp_q[1] -loc H10 -port myprobe} catchErrorString]} {
#     close_design
#     error [format " -E- Unit test $name failed: %s" $catchErrorString]   
# }
# 
# if {[catch { ::tclapp::xilinx::debugutils::add_probe -net inst_1/tmp_q[1] -loc H9 -port myprobe1} catchErrorString]} {
#     close_design
#     error [format " -E- Unit test $name failed: %s" $catchErrorString]   
# }

close_design

return 0
