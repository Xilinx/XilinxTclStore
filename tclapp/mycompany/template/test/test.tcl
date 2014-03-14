# Set the File Directory to the current directory location of the script
set test_dir [file normalize [file dirname [info script]]]

# Set the Xilinx Tcl App Store Repository to the current repository location
puts "== Test directory: $test_dir"
# set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $test_dir .. .. ..]]
set tclapp_repo [file normalize [file join $test_dir .. .. ..]]

# Set the Xilinx Tcl App Store Repository path to the Tcl auto_path
# puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
puts "== Application directory: $tclapp_repo"
# set auto_path $::env(XILINX_TCLAPP_REPO)
# set auto_path $tclapp_repo
set auto_path [linsert $auto_path 0 $tclapp_repo]

# Safely require the package
catch {package forget ::tclapp::mycompany::template}
package require ::tclapp::mycompany::template

# Start the unit tests
puts "script is invoked from $test_dir"
source [file join $test_dir my_command1_0001.tcl]
source [file join $test_dir my_command1_0002.tcl]
source [file join $test_dir my_command2_0001.tcl]
source [file join $test_dir my_command3_0001.tcl]

return 0
