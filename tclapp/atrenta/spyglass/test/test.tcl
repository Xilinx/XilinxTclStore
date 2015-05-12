set appName {atrenta::spyglass}
  
set listInstalledApps [::tclapp::list_apps]

set test_dir [file normalize [file dirname [info script]]]
puts "== Test directory: $test_dir"

set design_top vfifo_controller

set tclapp_repo [file normalize [file join $test_dir .. .. ..]]
puts "== Application directory: $tclapp_repo"

if {[lsearch -exact $listInstalledApps $appName] != -1} {
  # Uninstall the app if it is already installed
  ::tclapp::unload_app $appName
}

# Install the app and require the package

#_satrajit: Uncomment once added to Xilinx
catch "package forget ::tclapp::${appName}"
::tclapp::load_app $appName
package require ::tclapp::${appName}
  
# Start the unit tests
puts "script is invoked from $test_dir"
# All the unit test scripts should be sourced now such as:
if {[catch {source -notrace [file join $test_dir vivado_flow_x4gen2.tcl]} errorstring]} {
  catch { close_project }
}

::tclapp::atrenta::spyglass::write_spyglass_script $design_top $test_dir/spy_run.prj

# Cleaning
close_project
file delete $test_dir/spy_run.prj
file delete -force $test_dir/vivado_proj_1

# Uninstall the app if it was not already installed when starting the script
if {[lsearch -exact $listInstalledApps $appName] == -1} {
  ::tclapp::unload_app $appName
}

return 0
