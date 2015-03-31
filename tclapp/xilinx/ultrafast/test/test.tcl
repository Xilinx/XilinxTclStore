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
# ::tclapp::load_app $appName -namespace $appName
::tclapp::load_app $appName
package require ::tclapp::${appName}

#########################################
## Standard regression tests
#########################################

# Start the regression tests
puts "script is invoked from $test_dir"
source -notrace [file join $test_dir check_pll_connectivity_0001.tcl]
source -notrace [file join $test_dir report_io_reg_0001.tcl]
source -notrace [file join $test_dir report_reset_signals_0001.tcl]

#########################################
## Unit tests
#########################################

package require tcltest
tcltest::configure -testdir $test_dir
tcltest::configure -file *.test -singleproc 1 -debug 0 -verbose {skip body error start}
# tcltest::configure -file check_pll_connectivity_*.test -singleproc 1 -debug 0 -verbose {skip body error start}
# tcltest::configure -file report_io_reg_*.test -singleproc 1 -debug 0 -verbose {skip body error start}
# tcltest::configure -file report_reset_signals_*.test -singleproc 1 -debug 0 -verbose {skip body error start}

# Hook to determine if any of the tests failed. Then we can exit with
# proper exit code: 0=all passed, 1=one or more failed
set ::tcltestNumFailed 0
proc ::tcltest::cleanupTestsHook {} {
  variable numTests
  set ::tcltestNumFailed $numTests(Failed)
}

set ::QUIET 1
tcltest::runAllTests

puts "  ==> Completed [info script]"

# Uninstall the app if it was not already installed when starting the script
if {[lsearch -exact $listInstalledApps $appName] == -1} {
  ::tclapp::unload_app $appName
}

if {$tcltestNumFailed != 0} {
  error [format " -E- Regression tests: %s unit test(s) failed" $::tcltestNumFailed ]
#   puts [format " -E- Regression tests: %s unit test(s) failed" $::tcltestNumFailed ]
  return 1
}
return 0
