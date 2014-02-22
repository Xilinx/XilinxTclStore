####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2014 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
####################################################################################################
# Company:        Xilinx, Inc.
# Created by:     Nik Cimino
# 
# Created Date:   01/31/14
# Script name:    JUnitAssertionMgr.tcl
# Procedures:
#   run_step                     run_command
#   process_runs                 process_impl_design
#   process_synth_design         get_report
#   set_report                   write_results
#   validate_logic               validate_timing
#   validate_routing             validate_messages
#   validate_drcs                validate_run_properties
#   get_results                  reset_results
#   assert_same                  assert_exists
#   set_stdout                   set_stderr
#   new_testsuites               new_testsuite
#   new_testcase                 new_error
#   new_failure                  new_stdout
#   new_stderr                   init
#   validate_objects             validate_object
# Tool Versions:  Vivado 2013.4
# Description:    JUnit Reporting API
# Dependencies:   ::struct::graph
#                 ::struct::stack
#                 
####################################################################################################


####################################################################################################
# title: JUnit Reporting API
####################################################################################################

package require struct

namespace eval ::tclapp::xilinx::junit {


####################################################################################################
# section: variables
####################################################################################################

set results     ::tclapp::xilinx::junit::resultsGraph
set testsuite   {null}
set report      "report.xml"


####################################################################################################
# section: high level api
####################################################################################################

namespace export run_step
namespace export run_command
namespace export process_runs
namespace export process_impl_design
namespace export process_synth_design
namespace export get_report
namespace export set_report
namespace export write_results


####################################################################################################
# section: high level api - specific checks
####################################################################################################

namespace export validate_logic
namespace export validate_timing
namespace export validate_routing
namespace export validate_messages
namespace export validate_drcs
namespace export validate_run_properties


####################################################################################################
# section: intermediate level api
####################################################################################################

namespace export get_results
namespace export reset_results
namespace export assert_same
namespace export assert_exists
namespace export set_stdout
namespace export set_stderr


####################################################################################################
# section: low level api 
####################################################################################################

namespace export new_testsuites
namespace export new_testsuite
namespace export new_testcase
namespace export new_error
namespace export new_failure
namespace export new_stdout
namespace export new_stderr


####################################################################################################
# section: high level api
####################################################################################################


# proc: run_step
# Summary:
# Used to wrap a run step while logging success, errors, and runtimes
# Runs 
#   validate_messages 
#   validate_drcs 
#    
# Argument Usage: 
#:     run_step _args
# 
# Parameters:
#     _args          - Run step command for the run step
# 
# Return Value:
#     returned       - This is the return value from the run step command
# 
# Example:
#     
#:     # run synth_design
#:     run_step {synth_design -top top -part xc7vx485tffg1157-1}
#:     
#:     # run opt_design
#:     run_step {opt_design}
#
proc run_step _args {
  set commandName [ lindex $_args 0 ]
  
  set returned [ run_command $_args ]
  
  validate_messages "$commandName"
  validate_drcs "$commandName"
  
  return $returned
}


# proc: run_command
# Summary:
# Used to wrap any command while logging success, errors, and runtime
# 
# Argument Usage: 
#:     run_command _args
# 
# Parameters:
#     _args          - Command to run 
# 
# Return Value:
#     returned       - Return value from the command
# 
# Example:
#     
#:     # execute create_project and catch errors and log runtime
#:     run_command {create_project test test}
#
proc run_command _args {
  variable results
  variable testsuite

  set startTime [ clock milliseconds ] 
  set failure [ catch { uplevel $_args } returned ]
  set endTime [ clock milliseconds ]
  set wallTime [ expr ( $endTime - $startTime ) / 1000.0 ]
  
  set commandName [ lindex $_args 0 ]
  
  set testcase [ new_testcase $results $testsuite "$commandName" "CommandExecution" $wallTime ]
  if { $failure } {
    new_error $results $testcase "Command error, output:\n${returned}" $_args
    write_results
    error $returned
  }
  
  return $returned
}


# proc: run_silent
# Summary:
# Used to wrap any command while logging errors _only_
# A JUnitXml entry is not created on success!!
# 
# Argument Usage: 
#:     run_silent _args
# 
# Parameters:
#     _args          - Command to run 
# 
# Return Value:
#     returned       - This is the return value from the command
# 
# Example:
#     
#:     # execute create_project and catch as well as log errors on failure
#:     run_silent {create_project test test}
#
proc run_silent _args {
  variable results
  variable testsuite

  set startTime [ clock milliseconds ] 
  set failure [ catch { uplevel $_args } returned ]
  set endTime [ clock milliseconds ]
  set wallTime [ expr ( $endTime - $startTime ) / 1000.0 ]
  
  if { $failure } {
    set commandName [ lindex $_args 0 ]
    set testcase [ new_testcase $results $testsuite "$commandName" "CommandExecution" $wallTime ]
    new_error $results $testcase "Command error, output:\n${returned}" $_args
    write_results
    error $returned
  }
  
  return $returned
}


# proc: process_runs
# Summary:
# Used to post-process runs
# This requires using the project managed runs infrastructure
# Runs on each run
#   validate_run_properties
#   validate_messages
#   process_impl_design
#   _or_
#   process_synth_design
# 
# Argument Usage: 
#:     process_runs _runs ?_group?
# 
# Parameters:
#     _runs          - List of run objects to process
#     _group         - Name of the grouping of tests (maps to JUnit's 'classname')
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # process a list of runs after they have been completed
#:     process_runs [ get_runs synth_1 impl_1 ] "PostRunProcessing"
#
proc process_runs { _runs { _group "ProcessRuns" } } {
  validate_objects $_runs "run"
  foreach run $_runs {    
    validate_run_properties $run $_group
    validate_messages $_group
    set design [ open_run $run ]
    if { [ get_property IS_IMPLEMENTATION $run ] } {
      catch { process_impl_design $design $_group }    
    } else {
      catch { process_synth_design $design $_group }    
    }; # catch and enable other runs to be processed
    close_design
  }
}


# proc: process_impl_design
# Summary:
# Used to process an implemented design
# Runs
#   validate_timing
#   validate_routing
#   validate_drcs
#   validate_messages
# 
# Argument Usage: 
#:     process_impl_design _design ?_group?
# 
# Parameters:
#     _design        - Design objects to process
#     _group         - Name of the grouping of tests (maps to JUnit's 'classname')
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # process the current design
#:     process_impl_design [ current_design ] "PostRoutedDesignProcessing"
#
proc process_impl_design { _design { _group "ProcessImplDesign" } } {
  validate_object $_design "design"
  current_design $_design
  validate_timing $_group
  validate_routing $_group
  validate_drcs $_group
  validate_messages $_group
}


# proc: process_synth_design
# Summary:
# Used to process an synthesized design
# Runs
#   validate_logic
#   validate_drcs
#   validate_messages
# 
# Argument Usage: 
#:     process_synth_design _design ?_group?
# 
# Parameters:
#     _design        - Design object to process
#     _group         - Name of the grouping of tests (maps to JUnit's 'classname')
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # process the current design
#:     process_synth_design [ current_design ] "PostSynthDesignProcessing"
#
proc process_synth_design { _design { _group "ProcessSynthDesign" } } {
  validate_object $_design "design"
  current_design $_design
  validate_logic $_group
  validate_drcs $_group
  validate_messages $_group
}


####################################################################################################
# section: high level api - specific checks
####################################################################################################


# proc: validate_messages
# Summary:
# Checks if Warnings, Critical Warnings, or Errors exist
# If Errors are found, then the process is stopped
# 
# Argument Usage: 
#:     validate_messages ?_group?
# 
# Parameters:
#     _group         - Name of the grouping of tests (maps to JUnit's 'classname')
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # checks if messages exist
#:     validate_messages "ValidateMessages"
#
proc validate_messages { { _group "ValidateMessages" } } {
  variable results
  variable testsuite

  # Messages: WARNINGS
  set testcase [ new_testcase $results $testsuite "WARNING" $_group ]
  set cmd {get_msg_config -quiet -count -severity {WARNING}}
  set count [ run_silent $cmd ]
  if { $count > 0 } {
    set msg "Warnings were detected, found: $count"
    new_failure $results $testcase $msg $cmd
  }
  
  # Messages: CRITICAL_WARNING
  set testcase [ new_testcase $results $testsuite "CRITICAL_WARNING" $_group ]
  set cmd {get_msg_config -quiet -count -severity {CRITICAL WARNING}}
  set count [ run_silent $cmd ]
  if { $count > 0 } {
    set msg "Critical warnings were detected, found: $count"
    new_failure $results $testcase $msg $cmd
  }
  
  # Messages: ERRORS
  set testcase [ new_testcase $results $testsuite "ERROR" $_group ]
  set cmd {get_msg_config -quiet -count -severity {ERROR}}
  set count [ run_silent $cmd ]
  if { $count > 0 } {
    set msg "Errors were detected, found: $count"
    new_error $results $testcase $msg $cmd
    write_results
    error $msg; # stop flow
  }
    
}


# proc: validate_drcs
# Summary:
# Checks if any DRCs are found
# 
# Argument Usage: 
#:     validate_drcs ?_group?
# 
# Parameters:
#     _group         - Name of the grouping of tests (maps to JUnit's 'classname')
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # checks if DRC violations exist
#:     validate_drcs "ValidateDRCs"
#
proc validate_drcs { { _group "ValidateDRCs" } } {
  variable results
  variable testsuite

  # DRCs: RunAllDRCs
  set testcase [ new_testcase $results $testsuite "RunAllDRCs" $_group ]
  reset_drc
  set failureMsg [ report_drc -return_string ]
  set cmd "get_drc_violations -quiet"
  if { [ llength [ run_silent $cmd ] ] > 0 } {
    new_failure $results $testcase $failureMsg $cmd 
  }
}


# proc: validate_logic
# Summary:
# Checks for driverless nets and latches
# 
# Argument Usage: 
#:     validate_logic ?_group?
# 
# Parameters:
#     _group         - Name of the grouping of tests (maps to JUnit's 'classname')
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # checks if DRC violations exist
#:     validate_logic "ValidateLogic"
#
proc validate_logic { { _group "ValidateLogic" } } {
  variable results
  variable testsuite

  # Synthesis: DriverlessNetsDRC
  set testcase [ new_testcase $results $testsuite "DriverlessNetsDRC" $_group ]
  set rule "NDRV-1"
  reset_drc
  set cmd "report_drc -checks $rule -return_string"
  set failureMsg [ run_silent $cmd ]
  set violations [ llength [ get_drc_violations -quiet ${rule}* ] ] 
  if { $violations > 0 } {
    new_failure $results $testcase $failureMsg $cmd 
  }
  
  # Synthesis: DriverlessNetsGetNets
  set testcase [ new_testcase $results $testsuite "DriverlessNetsGetNets" $_group ]
  set cmd "get_nets -quiet -hierarchical -filter {DRIVER_COUNT == 0}"
  set driverlessNets [ run_silent $cmd ] 
    if { [ llength $driverlessNets ] > 0 } {
    new_failure $results $testcase "Driverless nets were found using get_nets:\n\t[ join $driverlessNets \n\t ]" $cmd 
  }
  
  # Synthesis: LatchCheck
  set testcase [ new_testcase $results $testsuite "Latches" $_group ]
  set cmd {get_cells -quiet -hierarchical -filter { PRIMITIVE_SUBGROUP == "latch" }}
  set latches [ run_silent $cmd ]
  if { [ llength $latches ] > 0 } {
    new_failure $results $testcase "Found latches:\n\t[ join $latches \n\t ]" $cmd 
  }
  
}


# proc: validate_routing
# Summary:
# Checks for unrouted nets
# 
# Argument Usage: 
#:     validate_routing ?_group?
# 
# Parameters:
#     _group         - Name of the grouping of tests (maps to JUnit's 'classname')
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # checks if DRC violations exist
#:     validate_routing "ValidateRouting"
#
proc validate_routing { { _group "ValidateRouting" } } {
  variable results
  variable testsuite
  
  # Implementation: RoutedNets
  set testcase [ new_testcase $results $testsuite "RoutedNets" $_group ]
  set cmd {get_nets -quiet -hierarchical -filter { ROUTE_STATUS != INTRASITE && ROUTE_STATUS != ROUTED }}
  set failedRoutes [ run_silent $cmd ]
  if { [ llength $failedRoutes ] > 0 } {
    new_failure $results $testcase "Failed routes detected: [ join $failedRoutes \n ]" $cmd
  }
  
}


# proc: validate_timing
# Summary:
# Checks for unrouted nets
# 
# Argument Usage: 
#:     validate_timing ?_group?
# 
# Parameters:
#     _group         - Name of the grouping of tests (maps to JUnit's 'classname')
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # checks if timing violations exist
#:     validate_timing "ValidateTiming"
#
proc validate_timing { { _group "ValidateTiming" } } {
  variable results
  variable testsuite
  
  # Timing: NegativeSlack
  set testcase [ new_testcase $results $testsuite "NegativeSlack" $_group ]
  #set cmd {filter [ get_timing_paths -max_paths 10 -filter { SLACK != "" } ] { SLACK < 0 }}
  set cmd {get_timing_paths -quiet -max_paths 10 -slack_lesser_than 0}
  set failedTiming [ run_silent $cmd ]
  if { [ llength $failedTiming ] > 0 } {
    lappend failureMsg "Failed timing checks (paths):\n\t[ join $failedTiming \n\t ]\n\nTiming Summary:"
    lappend failureMsg [ report_timing_summary -return_string -max_paths 10 -slack_lesser_than 0 ]
    new_failure $results $testcase [ join $failureMsg "\n" ] $cmd 
  }
  
}


# proc: validate_run_properties
# Summary:
# Logs run walltime 
# Validates the run is at 100% progress, else logs error and stops process
# 
# Argument Usage: 
#:     validate_run_properties _run ?_group?
# 
# Parameters:
#     _run           - Run object to use for validation
#     _group         - Name of the grouping of tests (maps to JUnit's 'classname')
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # checks if timing violations exist
#:     validate_run_properties [ get_runs impl_1 ] "ValidateTiming"
#
proc validate_run_properties { _run { _group "ValidateRunProperties" } } {
  variable results
  variable testsuite

  # RunProperties: Runtime
  set elapsed [ split [ get_property STATS.ELAPSED $_run ] : ]
  # scan __ %d cleanly changes 09 to 9 etc in Tcl while keeping base 10
  set seconds [ scan [ lindex $elapsed 2 ] %d ]
  set minutes [ expr [ scan [ lindex $elapsed 1 ] %d ] * 60 ] 
  set hours   [ expr [ scan [ lindex $elapsed 0 ] %d ] * 60 * 60 ] 
  set runtime [ expr $seconds + $minutes + $hours ]
  set testcase [ new_testcase $results $testsuite "Runtime" $_group $runtime ]

  # RunProperties: Progress
  set testcase [ new_testcase $results $testsuite "Progress" $_group ]
  set cmd {get_property PROGRESS $_run}
  if { [ run_silent $cmd ] != "100%" } {
    set status [ get_property STATUS $_run ]
    set msg "Synthesis progress not as expected, status:\n${status}"
    new_failure $results $testcase $msg $cmd
    write_results
    error $msg; # stop flow
  }
  
}


# proc: set_report
# Summary:
# Configures the JUnit API output location
# 
# Argument Usage: 
#:     set_report _file
# 
# Parameters:
#     _file          - Report file name
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # checks if timing violations exist
#:     set_report "results.xml"
#
proc set_report { _file } {
  variable report $_file
}


# proc: get_report
# Summary:
# Returns the currently set JUnit API output location 
# 
# Argument Usage: 
#:     get_report
# 
# Parameters:
#     void           - Unused
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # checks if timing violations exist
#:     get_report
#
proc get_report {} {
  variable report
  return $report
}


# proc: write_results
# Summary:
# Write the in-memory results to dist (uses the set_report/get_report location)
# 
# Argument Usage: 
#:     write_results
# 
# Parameters:
#     void           - Unused
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # commits the in memory test results to disk
#:     write_report
#
proc write_results {} {
  variable report
  write [ graph_to_xml [ format_junit [ get_results ] ] ] $report  
}


####################################################################################################
# section: intermediate level api
####################################################################################################


# proc: get_results
# Summary:
# Returns the in-memory results, this is a ::struct::graph name
# The name of a struct graph is a procedure and is used to configure
# and retrieve data from the graph object
# 
# Argument Usage: 
#:     get_results
# 
# Parameters:
#     void           - Unused
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # commits the in memory test results to disk, using get_results to retrieve the data
#:     write [ graph_to_xml [ format_junit [ get_results ] ] ] "report.xml" 
#
proc get_results {} {
  variable results 
  return $results
}


# proc: reset_results
# Summary:
# Resets the in-memory results, if it exists
# 
# Argument Usage: 
#:     reset_results
# 
# Parameters:
#     void           - Unused
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # resets the in-memory results
#:     reset_results
#
proc reset_results {} {
  variable results
  if { "[ info command $results ]" == "$results" } {
    $results destroy
  }
  init
}


# proc: set_stdout
# Summary:
# Adds a stdout entry to the global testsuite and sets it's content
# 
# Argument Usage: 
#:     set_stdout _content
# 
# Parameters:
#     _content       - This is the content that stdout will have
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # sets stdout node for the global testsuite
#:     set_stdout "All process finished, and return: 0"
#
proc set_stdout { _content } {
  variable results
  variable testsuite
  new_stdout $results $testsuite $_content
}


# proc: set_stderr
# Summary:
# Adds a stderr entry to the global testsuite and sets it's content
# 
# Argument Usage: 
#:     set_stderr _content
# 
# Parameters:
#     _content       - This is the content that stderr will have
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # sets stderr node for the global testsuite
#:     set_stderr "All process finished, '2' errors detected"
#
proc set_stderr { _content } {
  variable results
  variable testsuite
  new_stderr $results $testsuite $_content
}


# Deprecated: proc profile: instead use run_command, run_step, or run_silent
#proc profile _cmd {
#  set starttime [ clock milliseconds ] 
#  uplevel "eval { $_cmd }"
#  set endtime [ clock milliseconds ]
#  return [ expr ( $endtime - $starttime ) / 1000.0 ]
#}


# proc: assert_same
# Summary:
# Asserts that two values are the same, else a failure is logged
# 
# Argument Usage: 
#:     assert_same _expected _actual _msg ?_name? ?_group?
# 
# Parameters:
#     _expected      - The expected return value
#     _actual        - The received (actual) return value
#     _msg           - Message to log on failure
#     _name          - Name of the test (maps to JUnit's 'name')
#     _group         - Name of the grouping of tests (maps to JUnit's 'classname')
# 
# Return Value:
#     true           - Returns true else an error is thrown
# 
# Example:
#     
#:     set name "ProgressTest"
#:     set group "SynthesisTests"
#:     set expected "100%"
#:     set progress [ get_property PROGRESS [ get_runs synth_1 ] ]
#:     set msg "synth_1 is not at 100%"
#:      
#:     # checks that synth_1 progress is at 100% else the error is logged and the flow is stopped
#:     assert_same $expected $progress $msg $name $group
#:     
#:     # checks that synth_1 progress is at 100% else an error is logged and the flow continues
#:     if { [ catch { assert_same $expected $progress $msg $name $group } error ] } {
#:       puts "ERROR: $error"
#:       pits "Process will now continue..."
#:     }
#
proc assert_same { _expected _actual _msg { _name "Same" } { _group "Assertions" } } {
  variable testsuite
  variable results
  set testcase [ new_testcase $results $testsuite $_name $_group ]
  set success 1
  if { "$_expected" == "$_actual" } {
    puts "\[PASS\] Assertion passed, expected '$_expected' and received '$_actual'"
    return $success
  }  
  set assertionMsg "\[FAIL\] Assertion failed, expected '$_expected' and received '$_actual'\n$_msg"    
  new_error $results $testcase $assertionMsg "Compare assertion failure"
  write_results
  error $assertionMsg
}


# proc: assert_exists
# Summary:
# Asserts that all file exist
# 
# Argument Usage: 
#:     assert_exists _files _msg ?_name? ?_group?
# 
# Parameters:
#     _files         - List of files to check for existance
#     _msg           - Message to log on failure
#     _name          - Name of the test (maps to JUnit's 'name')
#     _group         - Name of the grouping of tests (maps to JUnit's 'classname')
# 
# Return Value:
#     true           - Returns true else an error is thrown
# 
# Example:
#     
#:     set name "SourceExists"
#:     set group "ProjectSetup"
#:     set files {"top.v" "sub.v"}
#:     set msg "All source files were not found"
#:      
#:     # checks that all source files exist, else log an error and stop the flow
#:     assert_exists $files $msg $name $group
#:     
#:     # checks that all source files exist, else log an error and then let the flow continue
#:     if { [ catch { assert_exists $files $msg $name $group } error ] } {
#:       puts "ERROR: $error"
#:       pits "Process will now continue..."
#:     }
#
proc assert_exists { _files _msg { _name "FileExists" } { _group "Assertions" } } {
  variable testsuite
  variable results
  set testcase [ new_testcase $results $testsuite $_name $_group ]
  set missingFiles {}
  foreach testfile $_files {
    if { ! [ file exists $testfile ] } {
      lappend missingFiles $testfile
    }
  }
  if { [ llength $missingFiles ] == 0 } {
    puts "\[PASS\] Assertion passed, found files:\n[ join $_files \n]"
    return 1
  }
  set assertionMsg "\[FAIL\] Assertion failed, missing files:\n[ join $missingFiles \n]"
  new_error $results $testcase $assertionMsg "File existance assertion failure"
  write_results
  error $assertionMsg
}


####################################################################################################
# section: low level api
####################################################################################################


# proc: new_results
# Summary:
# Create a new in-memory results object
# 
# Argument Usage: 
#:     new_results _name
# 
# Parameters:
#     _name          - Name of the results object
# 
# Return Value:
#     _name          - Returns the name of the new object 
# 
# Example:
#     
#:     # creates a new in-memory results object
#:     set myResults [ new_results "uniqueResultsName" ]
#
proc new_results { _name } {
  ::struct::graph $_name
  return $_name
}



# proc: new_testsuites
# Summary:
# Create a new node 'testsuites' in the provided results object
# 
# Argument Usage: 
#:     new_testsuites _results
# 
# Parameters:
#     _results       - The results object to add the testsuites node to
# 
# Return Value:
#     node           - Returns the new testsuites node 
# 
# Example:
#     
#:     # creates a new in-memory results object
#:     set myResults [ new_results "uniqueResultsName" ]
#:
#:     # creates a new testsuites node on the results object
#:     set myTestsuitesNode [ new_testsuites $myResults ]
#
proc new_testsuites { _results } {
  return [ $_results node insert ]
}


# proc: new_testsuite
# Summary:
# Create a new node 'testsuite' in the provided results object
# Added under the provided parent node (testsuites)
# 
# Argument Usage: 
#:     new_testsuite _results _parent _name _starttime _hostname
# 
# Parameters:
#     _results       - The results object to add the testsuites node to
#     _parent        - The testsuites node to add the testsuite node under
#     _name          - The name of the testsuite node
#     _starttime     - The starttime of the testsuite node
#     _hostname      - The hostname of the testsuite node
# 
# Return Value:
#     node           - Returns the new testsuite node 
# 
# Example:
#     
#:     # creates a new in-memory results object
#:     set myResults [ new_results "uniqueResultsName" ]
#:
#:     # creates a new testsuites node on the results object
#:     set RootNode [ new_testsuites $myResults ]
#:
#:     # creates a new testsuite node under the testsuites node
#:     set time [ clock format [ clock seconds ] -format "%Y-%m-%dT%H:%M:%S" ] 
#:     set hostname [ info hostname ]
#:     set TSNode [ new_testsuite $myResults $RootNode "SynthesisTests" $time $hostname ]
#
proc new_testsuite { _results _parent _name _starttime _hostname } {
  set node [ $_results node insert ]
  $_results node set $node name $_name
  $_results node set $node starttime $_starttime
  $_results node set $node hostname $_hostname
  $_results arc insert $_parent $node
  return $node
}


# proc: new_testcase
# Summary:
# Create a new node 'testcase' in the provided results object
# Added under the provided parent node (testsuite)
# 
# Argument Usage: 
#:     new_testcase _results _parent _name _group ?_walltime?
# 
# Parameters:
#     _results       - The results object to add the testsuites node to
#     _parent        - The testsuite node to add the testcase node under
#     _name          - The name of the testcase node
#     _group         - The group of the testcase node
#     _walltime      - The walltime of the testcase node
# 
# Return Value:
#     node           - Returns the new testcase node 
# 
# Example:
#     
#:     # creates a new in-memory results object
#:     set results [ new_results "uniqueResultsName" ]
#:
#:     # creates a new testsuites node on the results object
#:     set testsuites [ new_testsuites $results ]
#:
#:     # creates a new testsuite node under the testsuites node
#:     set time [ clock format [ clock seconds ] -format "%Y-%m-%dT%H:%M:%S" ] 
#:     set hostname [ info hostname ]
#:     set testsuite [ new_testsuite $myResults $testsuites "SynthesisTests" $time $hostname ]
#:
#:     # creates a new testcase node under the testsuite node
#:     set startTime [ clock milliseconds ] 
#:     create_project -force project project
#:     set endTime [ clock milliseconds ]
#:     set wallTime [ expr ( $endTime - $startTime ) / 1000.0 ]
#:     set testcase [ new_testcase graph $testsuite "ProjectCreation" "Setup" $wallTime ]
#
proc new_testcase { _results _parent _name _group { _walltime 0 } } {
  set node [ $_results node insert ]
  $_results node set $node type "testcase"
  $_results node set $node name $_name
  $_results node set $node group $_group
  $_results node set $node walltime $_walltime
  $_results arc insert $_parent $node
  return $node
}


# proc: new_stdout
# Summary:
# Create a new node 'stdout' in the provided results object
# Added under the provided parent node (testsuite)
# 
# Argument Usage: 
#:     new_stdout _results _parent _content
# 
# Parameters:
#     _results       - The results object to add the testsuites node to
#     _parent        - The testsuite node to add the testcase node under
#     _content       - The content of stdout
# 
# Return Value:
#     node           - Returns the new stdout node 
# 
# Example:
#     
#:     # creates a new stdout node under the testsuite node
#:     new_stdout $results $testsuite "STDOUT content"
proc new_stdout { _results _parent _content } {
  set node [ $_results node insert ]
  $_results node set $node type "system-out"
  $_results node set $node content $_content
  $_results arc insert $_parent $node
  return $node
}


# proc: new_stderr
# Summary:
# Create a new node 'stderr' in the provided results object
# Added under the provided parent node (testsuite)
# 
# Argument Usage: 
#:     new_stderr _results _parent _content
# 
# Parameters:
#     _results       - The results object to add the testsuites node to
#     _parent        - The testsuite node to add the stderr node under
#     _content       - The content of stderr
# 
# Return Value:
#     node           - Returns the new stderr node 
# 
# Example:
#     
#:     # creates a new in-memory results object
#:     set results [ new_results "uniqueResultsName" ]
#:
#:     # creates a new testsuites node on the results object
#:     set testsuites [ new_testsuites $results ]
#:
#:     # creates a new stderr node under the testsuites node
#:     new_stderr $results $testsuites "STDERR content"
proc new_stderr { _results _parent _content } {
  set node [ $_results node insert ]
  $_results node set $node type "system-err"
  $_results node set $node content $_content
  $_results arc insert $_parent $node
  return $node
}


# proc: new_failure
# Summary:
# Create a new node 'failure' in the provided results object
# Added under the provided parent node (testcase)
# 
# Argument Usage: 
#:     new_failure _results _parent _content _message
# 
# Parameters:
#     _results       - The results object to add the failure node to
#     _parent        - The testcase node to add the failure node under
#     _content       - The content of the failure
#     _message       - The message of the failure
# 
# Return Value:
#     node           - Returns the new failure node 
# 
# Example:
#     
#:     # creates a new in-memory results object
#:     set results [ new_results "uniqueResultsName" ]
#:
#:     # creates a new testsuites node on the results object
#:     set testsuites [ new_testsuites $results ]
#:
#:     # creates a new testsuite node under the testsuites node
#:     set time [ clock format [ clock seconds ] -format "%Y-%m-%dT%H:%M:%S" ] 
#:     set hostname [ info hostname ]
#:     set testsuite [ new_testsuite $results $testsuites "SynthesisTests" $time $hostname ]
#:
#:     # creates a new testcase node under the testsuite node
#:     set testcase [ new_testcase graph $testsuite "Warning" "Messages" ]
#:     set cmd {get_msg_config -count -severity {WARNING}}
#:     set count [ eval $cmd ]
#:     if { $count > 0 } {
#:       new_failure $results $testcase "Warnings were detected, found: $count" $cmd
#:     }
proc new_failure { _results _parent _content _message } {
  set node [ $_results node insert ]
  $_results node set $node type "failure"
  $_results node set $node content $_content
  $_results node set $node message $_message
  $_results arc insert $_parent $node
  return $node
}


# proc: new_error
# Summary:
# Create a new node 'error' in the provided results object
# Added under the provided parent node (testcase)
# 
# Argument Usage: 
#:     new_error _results _parent _content _message
# 
# Parameters:
#     _results       - The results object to add the error node to
#     _parent        - The testcase node to add the error node under
#     _content       - The content of the error
#     _message       - The message of the error
# 
# Return Value:
#     node           - Returns the new error node 
# 
# Example:
#     
#:     # creates a new in-memory results object
#:     set results [ new_results "uniqueResultsName" ]
#:
#:     # creates a new testsuites node on the results object
#:     set testsuites [ new_testsuites $results ]
#:
#:     # creates a new testsuite node under the testsuites node
#:     set time [ clock format [ clock seconds ] -format "%Y-%m-%dT%H:%M:%S" ] 
#:     set hostname [ info hostname ]
#:     set testsuite [ new_testsuite $results $testsuites "SynthesisTests" $time $hostname ]
#:
#:     # creates a new testcase node under the testsuite node
#:     set testcase [ new_testcase graph $testsuite "ERROR" "Messages" ]
#:     set cmd {get_msg_config -count -severity {ERROR}}
#:     set count [ eval $cmd ]
#:     if { $count > 0 } {
#:       new_error $results $testcase "Errors were detected, found: $count" $cmd
#:       write [ graph_to_xml [ format_junit $results ] ] report.xml
#:       error $cmd
#:     }
proc new_error { _results _parent _content _message } {
  set node [ $_results node insert ]
  $_results node set $node type "error"
  $_results node set $node content $_content
  $_results node set $node message $_message
  $_results arc insert $_parent $node
  return $node
}

####################################################################################################
# section: private
####################################################################################################


# proc: init
# Summary:
# Initialize the new global results and global testsuite
# 
# Argument Usage: 
#:     init
# 
# Parameters:
#     void           - Unused
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # set up and initialize the global variables
#:     init
#
proc init {} {
  variable results
  #if { "[ info command $results ]" == "$results" } { return }
  set time [ clock format [ clock seconds ] -format "%Y-%m-%dT%H:%M:%S" ] 
  set hostname [ info hostname ]
  new_results $results 
  set testsuites [ new_testsuites $results ]
  variable testsuite [ new_testsuite $results $testsuites "Testsuite" $time $hostname ]
}


# proc: validate_objects
# Summary:
# Validates the object types to make sure they are of the expected type
# 
# Argument Usage: 
#:     validate_objects _objects _expected
# 
# Parameters:
#     _objects       - Objects to verify
#     _expected      - Object type to validate
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # set up and initialize the global variables
#:     validate_objects [ get_runs ] "run"
proc validate_objects { _objects _expected } {
  catch { lsort -unique [ get_property class $_objects ] } clazz
  if { "$clazz" != "$_expected" } { error "Expected '${_expected}' object(s) received: '${clazz}'" }
}


# proc: validate_object
# Summary:
# Validates the object type to make sure it is of the expected type
# 
# Argument Usage: 
#:     validate_object _object _expected
# 
# Parameters:
#     _object        - Object to verify
#     _expected      - Object type to validate
# 
# Return Value:
#     void           - Unused
# 
# Example:
#     
#:     # set up and initialize the global variables
#:     validate_object [ get_runs synth_1 ] "run"
proc validate_object { _object _expected } {
  catch { get_property class $_object } clazz
  if { "$clazz" != "$_expected" } { error "Expected '${_expected}' object(s) received: '${clazz}'" }
}


# Used to initialize the global graph 
reset_results


}; # namespace ::tclapp::xilinx::junit
