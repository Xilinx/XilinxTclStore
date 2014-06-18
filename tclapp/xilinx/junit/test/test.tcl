set appName {xilinx::junit}
  
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

# namespace eval is used here to contain per script variables
# a variable from one source would be available in another sourced script
# using different namespaces ensures correct variable references

namespace eval test0 {
  source [ file join $test_dir project_step_high_ns run.tcl ]
}

namespace eval test1 {
  source [ file join $test_dir project_step_high run.tcl ]
}

namespace eval test2 {
  source [ file join $test_dir project_flow_low run.tcl ]
}

namespace eval test3 {
  source [ file join $test_dir project_flow_inter run.tcl ]
}

namespace eval test4 {
  source [ file join $test_dir project_flow_high run.tcl ]
}

namespace eval test5 {
  source [ file join $test_dir project_hook_high run.tcl ]
}

# Uninstall the app if it was not already installed when starting the script
if {[lsearch -exact $listInstalledApps $appName] == -1} {
  ::tclapp::unload_app $appName
  catch "package forget ::tclapp::${appName}"
}

puts "completed with all tests."

# exit 0

