set appName {mycompany::myapp}
  
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
# All the unit test scripts should be sourced now such as:
#   source -notrace [file join $test_dir my_command1_0001.tcl]

# Uninstall the app if it was not already installed when starting the script
if {[lsearch -exact $listInstalledApps $appName] == -1} {
  ::tclapp::unload_app $appName
}

return 0
