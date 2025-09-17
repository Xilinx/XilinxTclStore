set app_name {aldec::alint}

if {![info exists alint_path]} {
  error "alint tests require \$alint_path variable to run"
}

set file_dir [file normalize [file dirname [info script]]]
puts "== Unit Test directory: $file_dir"

set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]
puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
lappend auto_path $::env(XILINX_TCLAPP_REPO)

set list_installed_apps [::tclapp::list_apps]

# Uninstall the app if it is already installed
if {[lsearch -exact $list_installed_apps $app_name] != -1} {
  ::tclapp::unload_app $app_name
}

# Install the app and require the package
catch "package forget ::tclapp::${app_name}"
::tclapp::load_app $app_name
package require ::tclapp::${app_name}

set project_name "test_project"

# Prepare Vivado project
create_project -force -quiet $project_name ./$project_name
add_files -copy_to ./$project_name/sources -force -fileset sources_1 "$file_dir/src/uut.v"
add_files -copy_to ./$project_name/sources -force -fileset sim_1 "$file_dir/src/testbench.v"
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

::tclapp::${app_name}::convert_project $alint_path

if {[file exists ./$project_name/ALINT-PRO/$project_name.alintws]} {
  puts "TEST_PASSED"
} else {
  error "TEST_FAILED"
}

close_project
file delete -force ./$project_name

# Uninstall the app if it was not already installed when starting the script
if {[lsearch -exact $list_installed_apps $app_name] == -1} {
  ::tclapp::unload_app $app_name
}
