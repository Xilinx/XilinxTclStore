set app_name {xilinx::profiler}
  
set list_installed_apps [::tclapp::list_apps]

set test_dir [file normalize [file dirname [info script]]]
puts "== Test directory: $test_dir"

set tclapp_repo [file normalize [file join $test_dir .. .. ..]]
puts "== Application directory: $tclapp_repo"

if {[lsearch -exact $list_installed_apps $app_name] != -1} {
  # Uninstall the app if it is already installed
  ::tclapp::unload_app $app_name
}

# Install the app and require the package
catch "package forget ::tclapp::${app_name}"
::tclapp::load_app $app_name
package require ::tclapp::${app_name}
namespace import -force ::tclapp::${app_name}::*
  
# Start the tests
puts "script is invoked from $test_dir"


####################
### TESTING CODE ###
####################

###############################################################################
# set_out_file & get_out_file

# Negative: this should fail
set bad_output_file [file join [pwd] "this" "does" "not" "exist"]
if { ! [catch {tclapp::xilinx::profiler::set_out_file $bad_output_file} _error ] } {
  error ">>> ERROR: Due to the variable 'bad_output_file' ($bad_output_file) the 'set_out_file' proc \
  should've thrown an error; However, the 'set_out_file' proc did not throw an error as expected."
}

if { [tclapp::xilinx::profiler::get_out_file] == $bad_output_file } { 
  error ">>> ERROR: Due to the variable 'out_file' variable change should've been an error;\
  However, the variable 'out_file' was actually modified, and this is _NOT_ expected."
}

set output_dir [file join [pwd] "output"]
file delete -force $output_dir
file mkdir $output_dir

set output_file_name "test_profile.out"
set output_full_path [file join $output_dir $output_file_name]
tclapp::xilinx::profiler::set_out_file $output_full_path

if { [tclapp::xilinx::profiler::get_out_file] != $output_full_path } {
  error ">>> ERROR: Due to the variable 'out_file' variable change should've been valid;\
  However, the variable 'out_file' was not updated as expected, and this is _NOT_ expected."
}

###############################################################################
# set_csv_file & get_csv_file

# Negative: this should fail
set bad_csv_file [file join [pwd] "this" "does" "not" "exist"]
if { ! [catch {tclapp::xilinx::profiler::set_csv_file $bad_csv_file} _error ] } {
  error ">>> ERROR: Due to the variable 'bad_csv_file' ($bad_csv_file) the 'set_csv_file' proc \
  should've thrown an error; However, the 'set_csv_file' proc did not throw an error and thus \
  this test is failing."
}

if { [tclapp::xilinx::profiler::get_csv_file] == $bad_csv_file } { 
  error ">>> ERROR: Due to the variable 'csv_file' variable change should've been an error;\
  However, the variable 'csv_file' was actually modified, and this is _NOT_ expected."
}

set csv_dir [file join [pwd] "csv"]
file delete -force $csv_dir
file mkdir $csv_dir

set csv_file_name "test_profile.csv"
set csv_full_path [file join $csv_dir $csv_file_name]
tclapp::xilinx::profiler::set_csv_file $csv_full_path

if { [tclapp::xilinx::profiler::get_csv_file] != $csv_full_path } {
  error ">>> ERROR: Due to the variable 'csv_file' variable change should've been valid;\
  However, the variable 'csv_file' was not updated to '${csv_full_path}', and this is _NOT_ expected."
}

###############################################################################
# init, start, & stop

if { $tclapp::xilinx::profiler::initialized } {
  error ">>> ERROR: The initialized variable is set to '$tclapp::xilinx::profiler::initialized' ; \
  However, it is expected to be '0' at this stage, i.e. we have not called init (or start)."
}

tclapp::xilinx::profiler::start

if { ! $tclapp::xilinx::profiler::initialized } {
  error ">>> ERROR: The initialized variable is set to '$tclapp::xilinx::profiler::initialized' ; \
  However, it is expected to be '1' at this stage, i.e. we have called start."
}

if { ! [file exists $tclapp::xilinx::profiler::csv_file] } {
  error ">>> ERROR: Expected the csv file to exist after a call to 'init'; \
  However, the csv file does not exist: '$tclapp::xilinx::profiler::csv_file'"
}

# Negative: this should fail
if { ! [catch {tclapp::xilinx::profiler::start} _error ] } {
  error ">>> ERROR: Due to the variable 'running' ($tclapp::xilinx::profiler::running) the 'start' proc \
  should've thrown an error - cannot 'start' if already started; However, the 'start' proc did not throw an error and thus \
  this test is failing."
}

tclapp::xilinx::profiler::stop

# Negative: this should fail
if { ! [catch {tclapp::xilinx::profiler::stop} _error ] } {
  error ">>> ERROR: Due to the variable 'running' ($tclapp::xilinx::profiler::running) the 'stop' proc \
  should've thrown an error - cannot 'stop' if already stopped; However, the 'stop' proc did not throw an error and thus \
  this test is failing."
}

###############################################################################
# add_commands

namespace eval ::unittest {
  proc proc2 {} {
    puts "proc2"
  }
  proc proc1 {} {
    puts "proc1"
    proc2
  }
}
tclapp::xilinx::profiler::add_commands [info procs ::unittest::*]
tclapp::xilinx::profiler::add_commands [info commands puts]
# NOTE: profiling puts can be dangerous if you start adding puts to profiler procs!

set expected_commands [lsort [list ::unittest::proc1 ::unittest::proc2 puts]]
#set expected_commands [lsort [list ::unittest::proc1 ::unittest::proc2]]
if { $tclapp::xilinx::profiler::commands_to_profile != $expected_commands } {
  error ">>> ERROR: After using add_commands the expected commands for profiling are '${expected_commands}'; \
  However, the commands to profile that were added are different: '${tclapp::xilinx::profiler::commands_to_profile}'"
}

###############################################################################
# write_report

tclapp::xilinx::profiler::start
unittest::proc1
unittest::proc2
tclapp::xilinx::profiler::stop

if { ! [ file exists $csv_full_path ] } { error "Failed to find the .profile.csv" } 

tclapp::xilinx::profiler::write_report

if { [ file exists $csv_full_path ] } { error "Found the .profile.csv, this file should've been cleaned up" } 
if { ! [ file exists $output_full_path ] } { error "Failed to find the profile.out" } 

file delete -force $output_dir

puts "Done."

