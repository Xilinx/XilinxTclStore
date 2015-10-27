set appName {xilinx::incrcompile}
  
set listInstalledApps [::tclapp::list_apps]

set test_dir [file normalize [file dirname [info script]]]
set script_dir [file normalize [file join $test_dir ..]]
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
source -notrace [file join $script_dir get_reused.tcl]
source -notrace [file join $script_dir get_non_reused.tcl]
source -notrace [file join $script_dir highlight_reused.tcl]
source -notrace [file join $script_dir highlight_non_reused.tcl]
source -notrace [file join $script_dir analyze_critical_path.tcl]
source -notrace [file join $script_dir enable_auto_incremental_compile.tcl]
source -notrace [file join $script_dir disable_auto_incremental_compile.tcl]

# Uninstall the app if it was not already installed when starting the script
if {[lsearch -exact $listInstalledApps $appName] == -1} {
  ::tclapp::unload_app $appName
}

return 0
