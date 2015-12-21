# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]
set unit_test [file rootname [file tail [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"
puts "== Unit Test name: $unit_test"

# Set the Name to the name of the script
set name [file rootname [file tail [info script]]]

# Create a new Manage IP project
create_project -ip -part xcvu125-flvc2104-2-e ${name}_ex/proj_ip_${name}

# Check which version of Vivado is being run
if {[package vcompare [package require Vivado] "1.2015.3"]>=0} {
    # Create DDR4 IP instance
    create_ip -name ddr4 -vendor xilinx.com -library ip -module_name mig_0
	# Convert IP to Classic
	#convert_ips [get_files mig_0.xci] ## Remove since Core Container is now off by default
} else {
    # Create MIG IP instance
    create_ip -name mig -vendor xilinx.com -library ip -module_name mig_0
}

# Run the Create Combined MIG design script
if {[catch { ::tclapp::xilinx::designutils::create_combined_mig_io_design -project_name "proj_$name" -out_dir "./${name}_ex" [get_ips mig_0] } catchErrorString]} {
   # Close the two projects
    close_project
    close_project
	file delete -force "./ip_user_files"
	file delete -force "./${name}_ex"
    error [format " -E- Unit test $name failed: %s" $catchErrorString]
}

# Launch the synthesis run to verify the top module was created correctly
#launch_runs synth_1
#wait_on_run synth_1

# Check that the syntehsis completed
#if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
#	error error [format " -E- Unit test $name failed: %s" "synth_1 failed"]
#}

# Close the two projects
close_project
close_project

# Delete the project on disk
file delete -force "./${name}_ex"
file delete -force "./ip_user_files"

return 0
