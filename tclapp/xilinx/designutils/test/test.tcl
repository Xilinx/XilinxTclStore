# Set the File Directory to the current directory location of the script
set test_dir [file normalize [file dirname [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Test directory: $test_dir"
set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $test_dir .. .. ..]]

# Set the Xilinx Tcl App Store Repository path to the Tcl auto_path
puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
set auto_path $::env(XILINX_TCLAPP_REPO)

# Safely require the package
catch {package forget ::tclapp::xilinx::designutils}
package require ::tclapp::xilinx::designutils

# Start the unit tests
puts "script is invoked from $test_dir"
source [file join $test_dir write_slr_pblock_xdc_0001.tcl]
