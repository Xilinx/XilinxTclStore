#!vivado
lappend ::auto_path [ file normalize C:/Users/nikc/tcl/XilinxTclStore/tclapp/ ]

package require ::tclapp::xilinx::junit
namespace import ::tclapp::xilinx::junit::*

set_report ./report.xml

run_command { create_project -force tp tp -part xc7k70tfbg676-2 }

assert_exists [ glob ../../src/* ] "All source files were not found"
add_files [ glob ../../src/* ]
assert_same 3 [ llength [ get_files -all ] ] "All source file were not added to the project"

update_compile_order

launch_runs synth_1
wait_on_run synth_1

set status [ get_property STATUS [ get_runs synth_1 ] ]
assert_same "100%" [ get_property PROGRESS [ get_runs synth_1 ] ] "Synthesis progress not as expected, status:\n${status}"

set threshold 100
set elapsed [ split [ get_property STATS.ELAPSED [ get_runs synth_1 ] ] : ]
set seconds [ expr [ lindex $elapsed 2 ] + ( [ lindex $elapsed 1 ] * 60 ) + ( [ lindex $elapsed 0 ] * 60 * 60 ) ]
if { [ catch { assert_same 1 [ expr $seconds < $threshold ] "Synthesis runtime was over ${threshold} seconds, it took: ${seconds}" } _err ] } { 
  puts $_err 
}

set projDir [ get_property DIRECTORY [ current_project ] ]
set projName [ get_property NAME [ current_project ] ]

set synthReport [ file join $projDir ${projName}.runs synth_1 ff_replicator.rds ]
assert_exists $synthReport "Synthesis report was not found"

launch_runs impl_1
wait_on_run impl_1

open_run impl_1

set status [ get_property STATUS [ get_runs impl_1 ] ]
assert_same "100%" [ get_property PROGRESS [ get_runs impl_1 ] ] "Implementation progress not as expected, status:\n${status}"

set threshold 200
set elapsed [ split [ get_property STATS.ELAPSED [ get_runs impl_1 ] ] : ]
set seconds [ expr [ lindex $elapsed 2 ] + ( [ lindex $elapsed 1 ] * 60 ) + ( [ lindex $elapsed 0 ] * 60 * 60 ) ]
if { [ catch { assert_same 1 [ expr $seconds < $threshold ] "Implementation runtime was over ${threshold} seconds, it took: ${seconds}" } _err ] } { 
  puts $_err 
}

set implReport [ file join $projDir ${projName}.runs impl_1 ff_replicator.rdi ]
assert_exists $implReport "Implementation report was not found"

if { [ catch { assert_same 0 [ get_msg_config -count -severity {CRITICAL WARNING} ] "Critical warnings were detected" } _err ] } { 
  puts $_err 
}
if { [ catch { assert_same 0 [ get_msg_config -count -severity {WARNING} ] "Warnings were detected" } _err ] } { 
  puts $_err 
}
if { [ catch { assert_same 0 [ get_msg_config -count -severity {ERROR} ] "Errors were detected" } _err ] } { 
  puts $_err 
}

set failedRoutes [ get_nets -filter { ROUTE_STATUS != INTRASITE && ROUTE_STATUS != ROUTED } ]
if { [ catch { assert_same 0 [ llength $failedRoutes ] "Failed routes detected: [ join $failedRoutes \n ]" } _err ] } { 
  puts $_err 
}

write_results
