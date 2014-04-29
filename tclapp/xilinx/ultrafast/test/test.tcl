set appName {xilinx::ultrafast}
  
set listInstalledApps [::tclapp::list_apps]

set test_dir [file normalize [file dirname [info script]]]
puts "== Test directory: $test_dir"

set tclapp_repo [file normalize [file join $test_dir .. .. ..]]
puts "== Application directory: $tclapp_repo"

if {[lsearch -exact $listInstalledApps $appName] != -1} {
  # Uninstall the app if it is already installed
  ::tclapp::unload_app $appName
}

# Install the app and require the package
catch "package forget ::tclapp::${appName}"
::tclapp::load_app $appName
package require ::tclapp::${appName}
  
# Start the unit tests
puts "script is invoked from $test_dir"
source -notrace [file join $test_dir check_pll_connectivity_0001.tcl]
source -notrace [file join $test_dir create_cdc_reports_0001.tcl]
source -notrace [file join $test_dir report_clock_topology_0001.tcl]
source -notrace [file join $test_dir report_io_reg_0001.tcl]
source -notrace [file join $test_dir report_reset_signals_0001.tcl]

# Uninstall the app if it was not already installed when starting the script
if {[lsearch -exact $listInstalledApps $appName] == -1} {
  ::tclapp::unload_app $appName
}

return 0
