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

# Define example proc to profile:
namespace eval ::test {
  proc sleep {seconds} {
    set vwait 1
    after $seconds set vwait 0
    vwait vwait
  }
  proc first {} {
    sleep 1
    second
    sleep 1
  }
  proc second {} {
    sleep 3
  }
  proc main {} {
    sleep 1
    first
    second
    sleep 1
  }
}

file delete -force .profile.csv
file delete -force profile.out

###
#tclapp::xilinx::profiler::add_commands [ info procs ::test::* ]

tclapp::xilinx::profiler::add_commands [ info procs ::test::first ]
tclapp::xilinx::profiler::add_commands [ info procs ::test::second ]
tclapp::xilinx::profiler::add_commands [ info procs ::test::main ]
#tclapp::xilinx::profiler::add_commands [ info procs ::test::sleep ]

tclapp::xilinx::profiler::add_commands [ info commands after ]
tclapp::xilinx::profiler::add_commands [ info commands vwait ]
###

tclapp::xilinx::profiler::start
test::main
tclapp::xilinx::profiler::stop

test::main

tclapp::xilinx::profiler::start
test::main
tclapp::xilinx::profiler::stop

if { ! [ file exists .profile.csv ] } { error "Failed to find the .profile.csv" } 

tclapp::xilinx::profiler::write_report

if { [ file exists .profile.csv ] } { error "Found the .profile.csv, this file should've been cleaned up" } 
if { ! [ file exists profile.out ] } { error "Failed to find the profile.out" } 

file delete -force profile.out

puts "Done."

