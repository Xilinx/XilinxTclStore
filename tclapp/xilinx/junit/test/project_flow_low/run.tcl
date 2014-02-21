#!vivado
lappend ::auto_path [ file normalize C:/Users/nikc/tcl/XilinxTclStore/tclapp/ ]

package require ::tclapp::xilinx::junit
package require struct

namespace import ::tclapp::xilinx::junit::*

::struct::graph graph

set time [ clock format [ clock seconds ] ]
set hostname [ info hostname ]

set testsuites [ new_testsuites graph ]
set testsuite [ new_testsuite graph $testsuites "LowLevelExample" $time $hostname ]

set scriptStartTime [ clock milliseconds ] 

set startTime [ clock milliseconds ] 
create_project -force tp tp
set endTime [ clock milliseconds ]
set wallTime [ expr ( $endTime - $startTime ) / 1000.0 ]
set testcase [ new_testcase graph $testsuite "ProjectCreation" "Setup" $wallTime ]

set testcase [ new_testcase graph $testsuite "SourceExistance" "Setup" ]
set expected 3
set files [ glob ../../src/* ] 
if { $expected != [ llength $files ] } {
  set msg "Expected '${expected}' source files, and found '[ llength $files ]':\n\t[ join $files \n\t ]"
  new_failure graph $testcase $msg "All source files were not found"
}

add_files $files

update_compile_order

set testcase [ new_testcase graph $testsuite "SourcesAdded" "Setup" ]
set expected 3
set files [ get_files -all ] 
if { $expected != [ llength $files ] } {
  set msg "Expected '${expected}' source files, and found '[ llength $files ]':\n\t[ join $files \n\t ]"
  new_failure graph $testcase $msg "All source files were not added"
}

set startTime [ clock milliseconds ] 
set failed [ catch { synth_design } returned ]
set endTime [ clock milliseconds ]
set wallTime [ expr ( $endTime - $startTime ) / 1000.0 ]
if { $failed } {
  set err "Returned: ${returned}\nErrorCode: $errorCode\nErrorInfo: {\n${errorInfo}\n}"
  set testcase [ new_testcase graph $testsuite "Execution" "Synthesis" ]
  new_failure graph $testcase $err "Synthesis Failed"
} else {
  set testcase [ new_testcase graph $testsuite "Execution" "Synthesis" $wallTime ]
}

set testcase [ new_testcase graph $testsuite "WARNING" "Messages" ]
set cmd {get_msg_config -count -severity {WARNING}}
set count [ eval $cmd ]
if { $count > 0 } {
  new_failure graph $testcase "Warnings were detected, found: $count" $cmd
}

set testcase [ new_testcase graph $testsuite "CRITICAL_WARNING" "Messages" ]
set cmd {get_msg_config -count -severity {CRITICAL WARNING}}
set count [ eval $cmd ]
if { $count > 0 } {
  new_failure graph $testcase "Critical warnings were detected, found: $count"  $cmd
}

set testcase [ new_testcase graph $testsuite "ERROR" "Messages" ]
set cmd {get_msg_config -count -severity {ERROR}}
set count [ eval $cmd ]
if { $count > 0 } {
  new_failure graph $testcase "Errors were detected, found: $count" $cmd
}

set scriptEndTime [ clock milliseconds ]
set scriptWallTime [ expr ( $scriptEndTime - $scriptStartTime ) / 1000.0 ]

set testcase [ new_testcase graph $testsuite "RunTime" "Script" $scriptWallTime ]

write [ graph_to_xml [ format_junit graph ] ] report.xml
