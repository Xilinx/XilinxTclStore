#!vivado

# prep
set testDir   [ file normalize [ file dirname [ info script ] ] ]
set runDir    [ file join $testDir run ]
puts "= Current Test Dir:\n  $testDir"
puts "= Current Run Dir:\n  $runDir"

# clean
if { [ file exists $runDir ] } { file delete -force $runDir }
file mkdir $runDir

package require ::tclapp::xilinx::junit
namespace import ::tclapp::xilinx::junit::*

set outputReport [ file join $runDir report.xml ]
set_report $outputReport

# similar to run_step, except run_command doesn't run any validation steps
set projectDir [ file join $runDir tp ]
run_command { create_project tp $projectDir -part xc7vx485tffg1157-1 }

set srcFiles [ file normalize [ file join $runDir .. .. src * ] ]
puts "Searching for source files with:\n  ${srcFiles}"
# assert_* will stop the flow on failure!
assert_exists [ glob $srcFiles ] "All source files were not found"
add_files [ glob $srcFiles ]
assert_same 3 [ llength [ get_files -all ] ] "All source files were not added to the project"

update_compile_order

launch_runs synth_1
wait_on_run synth_1

set status [ get_property STATUS [ get_runs synth_1 ] ]
assert_same "100%" [ get_property PROGRESS [ get_runs synth_1 ] ] "Synthesis progress not as expected, status:\n${status}"

set threshold 100
set elapsed [ split [ get_property STATS.ELAPSED [ get_runs synth_1 ] ] : ]
set seconds [ expr [ lindex $elapsed 2 ] + ( [ lindex $elapsed 1 ] * 60 ) + ( [ lindex $elapsed 0 ] * 60 * 60 ) ]
# catching asserts will enable the flow to continue, but you should still print the errors
if { [ catch { assert_same 1 [ expr $seconds < $threshold ] "Synthesis runtime was over ${threshold} seconds, it took: ${seconds}" } _err ] } { 
  puts $_err 
}

set projDir [ get_property DIRECTORY [ current_project ] ]
set projName [ get_property NAME [ current_project ] ]

set synthReport [ file join $projDir ${projName}.runs synth_1 ff_replicator.vds ]
assert_exists $synthReport "Synthesis report was not found"

#launch_runs impl_1
#wait_on_run impl_1
#
#open_run impl_1
#
#set status [ get_property STATUS [ get_runs impl_1 ] ]
#assert_same "100%" [ get_property PROGRESS [ get_runs impl_1 ] ] "Implementation progress not as expected, status:\n${status}"
#
#set threshold 200
#set elapsed [ split [ get_property STATS.ELAPSED [ get_runs impl_1 ] ] : ]
#set seconds [ expr [ lindex $elapsed 2 ] + ( [ lindex $elapsed 1 ] * 60 ) + ( [ lindex $elapsed 0 ] * 60 * 60 ) ]
#if { [ catch { assert_same 1 [ expr $seconds < $threshold ] "Implementation runtime was over ${threshold} seconds, it took: ${seconds}" } _err ] } { 
#  puts $_err 
#}
#
#set implReport [ file join $projDir ${projName}.runs impl_1 ff_replicator.rdi ]
#assert_exists $implReport "Implementation report was not found"
#
#set failedRoutes [ get_nets -filter { ROUTE_STATUS != INTRASITE && ROUTE_STATUS != ROUTED } ]
#if { [ catch { assert_same 0 [ llength $failedRoutes ] "Failed routes detected: [ join $failedRoutes \n ]" } _err ] } { 
#  puts $_err 
#}

if { [ catch { assert_same 0 [ get_msg_config -count -severity {CRITICAL WARNING} ] "Critical warnings were detected" } _err ] } { 
  puts $_err 
}
if { [ catch { assert_same 0 [ get_msg_config -count -severity {WARNING} ] "Warnings were detected" } _err ] } { 
  puts $_err 
}
if { [ catch { assert_same 0 [ get_msg_config -count -severity {ERROR} ] "Errors were detected" } _err ] } { 
  puts $_err 
}

write_results

close_project

# smoke test to just make sure XML is generated
if { ! [ file exists $outputReport ] } {
  error "Couldn't find junit report: '$outputReport'"
}

# clean on success
file delete -force $runDir 
puts "done."

