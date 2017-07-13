set appName {bluepearl::bpsvvs}
  
set listInstalledApps [::tclapp::list_apps]

set file_dir [file normalize [file dirname [info script]]]

puts "== Unit Test directory: $file_dir"
set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]

puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
lappend auto_path $::env(XILINX_TCLAPP_REPO)

if {[lsearch -exact $listInstalledApps $appName] != -1} {
  # Uninstall the app if it is already installed
  ::tclapp::unload_app $appName
}

# Install the app and require the package
catch "package forget ::tclapp::${appName}"
::tclapp::load_app $appName
package require ::tclapp::${appName}
  
#disable running of BPS
set ::tclapp::${appName}::runBPS 0
  
set name "bpsvvs_0002"

create_project -force $name ./$name
add_files -copy_to ./$name/sources -force -fileset sources_1 "$file_dir/src/bp_install_check.v"
update_compile_order -fileset sources_1
launch_runs synth_1 impl_1
wait_on_run [current_run]

::tclapp::bluepearl::bpsvvs::generate_bps_project
if { ![file exists "./$name/bp_install_check.bluepearl_generated.tcl"] } {
    error "TEST_FAILED"
}

set moduleName bp_install_check
set utilRep   ./$name/$name.runs/impl_1/${moduleName}_utilization_placed.rpt
set timingRep ./$name/$name.runs/impl_1/${moduleName}_power_routed.rpt
set powerRep  ./$name/$name.runs/impl_1/${moduleName}_timing_summary_routed.rpt

puts "Util Report: $utilRep"
puts "Timing Report: $timingRep"
puts "Power Report: $powerRep"
#delete existing to force the update to regenerate them
if {[file exists $utilRep]} {
    puts "Deleting existing $utilRep"
    set aOK [file delete $utilRep]
}
if {[file exists $timingRep]} {
    puts "Deleting existing $timingRep"
    set aOK [file delete $timingRep]
}
if {[file exists $powerRep]} {
    puts "Deleting existing $powerRep"
    set aOK [file delete $powerRep]
}

::tclapp::bluepearl::bpsvvs::update_vivado_into_bps

if {![file exists $utilRep]} {
    error "TEST_FAILED"
}

if {![file exists $timingRep]} {
    error "TEST_FAILED"
}

if {![file exists $powerRep]} {
    error "TEST_FAILED"
}

close_project

# Cleaning
file delete -force ./${name}

puts "TEST_PASSED"

# Uninstall the app if it was not already installed when starting the script
if {[lsearch -exact $listInstalledApps $appName] == -1} {
  ::tclapp::unload_app $appName
}

return 0
