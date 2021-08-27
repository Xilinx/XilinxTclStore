set appName {octavo::osdzu3}
  
set listInstalledApps [::tclapp::list_apps]

#set test_dir [file normalize [file dirname [info script]]]
#puts "== Test directory: $test_dir"

#set tclapp_repo [file normalize [file join $test_dir .. .. ..]]
#puts "== Application directory: $tclapp_repo"

if {[lsearch -exact $listInstalledApps $appName] != -1} {
  # Uninstall the app if it is already installed
  ::tclapp::unload_app $appName
}

# Install the app and require the package
catch "package forget ::tclapp::${appName}"
::tclapp::load_app $appName
package require ::tclapp::${appName}

# Set the File Directory to the current directory location of the script
set file_dir [file normalize [file dirname [info script]]]
set unit_test [file rootname [file tail [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Unit Test directory: $file_dir"
puts "== Unit Test name: $unit_test"

set tclapp_repo [file normalize [file join $file_dir .. .. ..]]
puts "== Application directory: $tclapp_repo"

# Set the Name to the name of the script
set name [file rootname [file tail [info script]]]

# Load the Design Checkpoint for the specific test
open_checkpoint "$file_dir/src/osdzu3_export_xdc/$name.dcp"

# Run the write_slr_pblock_xdc script and verify that no error was reported
if {[catch { ::tclapp::octavo::osdzu3::osdzu3_export_xdc } catchErrorString]} {
    close_design
    error [format " -E- Unit test $name failed: %s" $catchErrorString]   
}

close_design

set export_constraint_files [list impl_xdc.xdc osdzu3_timing.xdc osdzu3_io_delay.tcl osdzu3_package_pins.tcl]

# Clean up the generated files from the script run
foreach generatedFileName $export_constraint_files { 
  file delete -force $generatedFileName 
  puts "Deleting generated file $generatedFileName"
}

return 0
