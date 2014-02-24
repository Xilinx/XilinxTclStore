# Xilinx JUnit App

This app can be used to generate JUnit reports.

## Architecture

The JUnit App is built with 3 layers of APIs.

The high level API enables a user to run generic tests or a group of predefined tests on demand.

The intermediate level API enables a user to call assertions and customize the tests.

Both the high level and intermediate level APIs are automatically generating a JUnit report in memory.

The low level API enables the user to work directly with the "data graph" in memory.

There is a section in the writer class where this in-memory "data graph" is converted to a "junit graph".

The "junit graph" is then just dumped to an XML file.  The conversion from "data graph" to "junit graph" 
exists to enable users to convert the data to other formats.

## Getting Started

Require the package:

    package require ::tclapp::xilinx::junit

Import the namespace, not needed, but will be used here for brevity:
    
    namespace import ::tclapp::xilinx::junit::*

### High Level API Example - Project

    set_report ./report.xml

    file delete [ glob ./* ]

    create_project -force tp tp -part xc7vx485tffg1157-1
    add_files [ glob $root/src/* ]

    update_compile_order

    launch_runs synth_1
    wait_on_run synth_1

    launch_runs impl_1
    wait_on_run impl_1

    process_runs [ get_runs ] 

    write_results

### High Level API Example - w/o Project
    
    # set optional report name (default: report.xml)
    set_report ./report.xml

    add_files [ glob $root/src/* ]

    update_compile_order

    # synth_design
    run_step {synth_design -top ff_replicator -part xc7vx485tffg1157-1}
    write_checkpoint synthesis.dcp
    # validation
    validate_timing "Post synth_design"
    validate_logic "Post synth_design"

    # opt_design
    run_step {opt_design}
    write_checkpoint opt_design.dcp
    # validation
    validate_timing "Post opt_design"
    validate_logic "Post opt_design"

    # place_design
    run_step {place_design}
    write_checkpoint place_design.dcp
    # validation
    validate_timing "Post place_design"
    validate_logic "Post place_design"

    # phys_opt_design
    run_step {phys_opt_design}
    write_checkpoint phys_opt_design.dcp
    # validation
    validate_timing "Post phys_opt_design"
    validate_logic "Post phys_opt_design"

    # route_design
    run_step {route_design}
    write_checkpoint route_design.dcp
    # validation
    validate_timing "Post route_design"
    validate_routing "Post route_design"


    # done after each step
    validate_messages "Final"
    validate_drcs "Final"

    write_results 


### Intermediate Level API Example - Project

    set_report ./report.xml

    run_command { create_project -force tp tp -part xc7k70tfbg676-2 }

    assert_exists [ glob $root/src/* ] "All source files were not found"
    add_files [ glob $root/src/* ]
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
    
### Low Level API Example - Project

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
    set files [ glob $root/src/* ] 
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

## Commands

### High Level API Commands

    run_step
    run_command
    process_runs
    process_impl_design
    process_synth_design
    get_report
    set_report
    write_results

### High Level API Commands ( Specific Checks )

    validate_logic
    validate_timing
    validate_routing
    validate_messages
    validate_drcs
    validate_run_properties

### Intermediate Level API Commands

    get_results
    reset_results
    assert_same
    assert_exists
    set_stdout
    set_stderr

### Low Level API Commands

    new_testsuites
    new_testsuite
    new_testcase
    new_error
    new_failure
    new_stdout
    new_stderr

## More?

If that's not enough info, then jump into the code:
https://github.com/Xilinx/XilinxTclStore/blob/master/tclapp/xilinx/junit/
