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
package require struct

namespace import ::tclapp::xilinx::junit::*

set graph ::graph

::struct::graph $graph

set time [ clock format [ clock seconds ] ]
set hostname [ info hostname ]

set testsuites [ new_testsuites $graph ]
set testsuite [ new_testsuite $graph $testsuites "LowLevelExample" $time $hostname ]

set scriptStartTime [ clock milliseconds ] 

set projectDir [ file join $runDir tp ]
set startTime [ clock milliseconds ] 
create_project tp $projectDir -part xc7vx485tffg1157-1
set endTime [ clock milliseconds ]
set wallTime [ expr ( $endTime - $startTime ) / 1000.0 ]
set testcase [ new_testcase $graph $testsuite "ProjectCreation" "Setup" $wallTime ]

set testcase [ new_testcase $graph $testsuite "SourceExistance" "Setup" ]
set expected 3
set files [ glob [ file join $::test_dir src * ] ]
if { $expected != [ llength $files ] } {
  set msg "Expected '${expected}' source files, and found '[ llength $files ]':\n\t[ join $files \n\t ]"
  new_failure $graph $testcase $msg "All source files were not found"
}

add_files $files

update_compile_order

set testcase [ new_testcase $graph $testsuite "SourcesAdded" "Setup" ]
set expected 3
set files [ get_files -all ] 
if { $expected != [ llength $files ] } {
  set msg "Expected '${expected}' source files, and found '[ llength $files ]':\n\t[ join $files \n\t ]"
  new_failure $graph $testcase $msg "All source files were not added"
}

set startTime [ clock milliseconds ] 
set failed [ catch { synth_design } returned ]
set endTime [ clock milliseconds ]
set wallTime [ expr ( $endTime - $startTime ) / 1000.0 ]
if { $failed } {
  set err "Returned: ${returned}\nErrorCode: $errorCode\nErrorInfo: {\n${errorInfo}\n}"
  set testcase [ new_testcase $graph $testsuite "Execution" "Synthesis" ]
  new_failure $graph $testcase $err "Synthesis Failed"
} else {
  set testcase [ new_testcase $graph $testsuite "Execution" "Synthesis" $wallTime ]
}

set testcase [ new_testcase $graph $testsuite "WARNING" "Messages" ]
set cmd {get_msg_config -count -severity {WARNING}}
set count [ eval $cmd ]
if { $count > 0 } {
  new_failure $graph $testcase "Warnings were detected, found: $count" $cmd
}

set testcase [ new_testcase $graph $testsuite "CRITICAL_WARNING" "Messages" ]
set cmd {get_msg_config -count -severity {CRITICAL WARNING}}
set count [ eval $cmd ]
if { $count > 0 } {
  new_failure $graph $testcase "Critical warnings were detected, found: $count"  $cmd
}

set testcase [ new_testcase $graph $testsuite "ERROR" "Messages" ]
set cmd {get_msg_config -count -severity {ERROR}}
set count [ eval $cmd ]
if { $count > 0 } {
  new_failure $graph $testcase "Errors were detected, found: $count" $cmd
}

set scriptEndTime [ clock milliseconds ]
set scriptWallTime [ expr ( $scriptEndTime - $scriptStartTime ) / 1000.0 ]

set testcase [ new_testcase $graph $testsuite "RunTime" "Script" $scriptWallTime ]

set outputReport [ file join $runDir report.xml ]
write [ graph_to_xml [ format_junit $graph ] ] $outputReport

close_project

# smoke test to just make sure XML is generated
if { ! [ file exists $outputReport ] } {
  error "Couldn't find junit report: '$outputReport'"
}

# clean on success
file delete -force $runDir 
puts "done."

