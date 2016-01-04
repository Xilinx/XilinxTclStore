
# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]
set unit_test [file rootname [file tail [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"
puts "== Unit Test name: $unit_test"
puts "== Working in [pwd]"

# Set the Name to the name of the script
set name [file rootname [file tail [info script]]]

# Create the project and BD for the specific test
set myproj [file join $file_dir wipit]
file mkdir $myproj
create_project $name $myproj -part xc7k325tffg900-2 -force
set_property BOARD_PART xilinx.com:kc705:part0:1.2 [current_project]
set design_name design_1
create_bd_design $design_name

source "$file_dir/src/write_ip_integrator_testbench/test_$name.tcl"

puts "== current bd => [current_bd_design]"
open_bd_design [current_bd_design]

# Run the write_slr_pblock_xdc script and verify that no error was reported
if {[catch { 	::tclapp::xilinx::designutils::write_ip_integrator_testbench -output "$myproj/tb_$name" -addToProject } catchErrorString]} {
    close_bd_design [current_bd_design]
    close_project
    error [format " -E- Unit test $name failed: %s" $catchErrorString]   
}

#simulate
close_sim -quiet
if {[catch { 	launch_simulation } catchErrorString]} {
    close_sim
    close_bd_design [current_bd_design]
    close_project
    error [format " -E- Unit test $name failed simulation: %s" $catchErrorString]   
}

close_sim
close_bd_design [current_bd_design]
close_project

# Clean up the generated files from the script run
file delete -force -- $myproj
file delete -force -- add_wave_design_1.tcl

return 0
