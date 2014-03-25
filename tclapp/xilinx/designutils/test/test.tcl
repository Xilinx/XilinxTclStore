# Set the File Directory to the current directory location of the script
set test_dir [file normalize [file dirname [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Test directory: $test_dir"
set tclapp_repo [file normalize [file join $test_dir .. .. ..]]

# Set the Xilinx Tcl App Store Repository path to the Tcl auto_path
puts "== Application directory: $tclapp_repo"
set auto_path [linsert $auto_path 0 $tclapp_repo]

# Safely require the package
catch {package forget ::tclapp::xilinx::designutils}
package require ::tclapp::xilinx::designutils

# Start the unit tests
puts "script is invoked from $test_dir"
source -notrace [file join $test_dir check_cdc_paths_0001.tcl]
source -notrace [file join $test_dir convert_muxfx_to_luts_0001.tcl]
source -notrace [file join $test_dir write_slr_pblock_xdc_0001.tcl]

return 0
