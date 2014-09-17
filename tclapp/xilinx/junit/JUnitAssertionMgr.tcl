####################################################################################################
#
# JUnitAssertionMgr.tcl (api and assertion utilities for junit)
#
# Script created on 01/31/2014 by Nik Cimino (Xilinx, Inc.)
#
# 2014 - version 1.0 (rev. 1)
#  * initial version
#
####################################################################################################
# 
# Procedures:
#   run_step                     run_command                  run_silent
#
#   process_runs                 process_impl_design          process_synth_design         
#
#   get_report                   set_report                   write_results
#
#   validate_logic               validate_timing              validate_routing             
#   validate_messages            validate_drcs                validate_run_properties
#   
#   get_results                  reset_results
#
#   assert_same                  assert_exists
#
#   set_stdout                   set_stderr
#
#   new_testsuites               new_testsuite                new_testcase                 
#   new_error                    new_failure                  new_stdout
#   new_stderr                   
#   
#   validate_objects             validate_object
#
# Dependencies:   ::struct::graph
#                 ::struct::stack
#                 
####################################################################################################


####################################################################################################
# title: JUnit Reporting API
####################################################################################################

package require Vivado 1.2014.1
package require struct

namespace eval ::tclapp::xilinx::junit {


####################################################################################################
# section: variables
####################################################################################################

variable results     ::tclapp::xilinx::junit::resultsGraph
variable testsuite   {null}
variable report      "report.xml"


####################################################################################################
# section: high level api
####################################################################################################

namespace export run_step
namespace export run_command
namespace export run_silent
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


proc run_step _args {
  # Summary:
  # Used to wrap a run-step while logging success, errors, and run-times.
  # Runs the following validations after:
  #   validate_messages 
  #   validate_drcs 

  # Argument Usage: 
  #   args : Run-step command for the run step.

  # Return Value:
  # The return value from the run-step command.
  
  # Categories: xilinxtclstore, junit

  set commandName [ lindex $_args 0 ]
  
  set returned [ run_command $_args ]
  
  validate_messages "$commandName"
  validate_drcs "$commandName"
  
  return $returned
}


proc run_command _args {
  # Summary:
  # Used to wrap any command while logging success, errors, and runtime.
  
  # Argument Usage: 
  #   args : Command to run.
   
  # Return Value:
  # Return value from the command.
  
  # Categories: xilinxtclstore, junit
   
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


proc run_silent _args {
  # Summary:
  # Used to wrap any command while logging errors _only_. 
  # A JUnitXml entry is not created on success!
  
  # Argument Usage: 
  #   args : Command to run 
   
  # Return Value:
  # The return value from the command
  
  # Categories: xilinxtclstore, junit
   
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


proc process_runs { _runs { _group "ProcessRuns" } } {
  # Summary:
  # Used to post-process runs. This requires using the project managed runs infrastructure
  # Runs the following validations on each run:
  #   validate_run_properties
  #   validate_messages
  #   process_impl_design
  #   _or_
  #   process_synth_design
   
  # Argument Usage: 
  #   runs : List of run objects to process.
  #   group : Name of the grouping of tests (maps to JUnit's 'classname')
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
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


proc process_impl_design { _design { _group "ProcessImplDesign" } } {
  # Summary:
  # Used to process an implemented design.
  # Runs
  #   validate_timing
  #   validate_routing
  #   validate_drcs
  #   validate_messages
   
  # Argument Usage: 
  #   design : Implementation design objects to process.
  #   group : Name of the grouping of tests (maps to JUnit's 'classname').
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
  validate_object $_design "design"
  current_design $_design
  validate_timing $_group
  validate_routing $_group
  validate_drcs $_group
  validate_messages $_group
}


proc process_synth_design { _design { _group "ProcessSynthDesign" } } {
  # Summary:
  # Used to process an synthesized design.
  # Runs
  #   validate_logic
  #   validate_drcs
  #   validate_messages
   
  # Argument Usage: 
  #   design : Design object to process.
  #   group : Name of the grouping of tests (maps to JUnit's 'classname').
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
  validate_object $_design "design"
  current_design $_design
  validate_logic $_group
  validate_drcs $_group
  validate_messages $_group
}


####################################################################################################
# section: high level api - specific checks
####################################################################################################


proc validate_messages { { _group "ValidateMessages" } } {
  # Summary:
  # Checks if Warnings, Critical Warnings, or Errors exist.
  # If Errors are found, then the process is stopped (Tcl error).
   
  # Argument Usage: 
  #   group : Name of the grouping of tests (maps to JUnit's 'classname').
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
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


proc validate_drcs { { _group "ValidateDRCs" } } {
  # Summary:
  # Checks if any DRC Violations are found.
   
  # Argument Usage: 
  #   group : Name of the grouping of tests (maps to JUnit's 'classname').
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
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


proc validate_logic { { _group "ValidateLogic" } } {
  # Summary:
  # Checks for driver-less nets and latches.
   
  # Argument Usage: 
  #   group : Name of the grouping of tests (maps to JUnit's 'classname').
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
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


proc validate_routing { { _group "ValidateRouting" } } {
  # Summary:
  # Checks for unrouted nets.
   
  # Argument Usage: 
  #   group : Name of the grouping of tests (maps to JUnit's 'classname').
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
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


proc validate_timing { { _group "ValidateTiming" } } {
  # Summary:
  # Checks for paths with negative slack.
   
  # Argument Usage: 
  #   group : Name of the grouping of tests (maps to JUnit's 'classname').
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
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


proc validate_run_properties { _run { _group "ValidateRunProperties" } } {
  # Summary:
  # Logs run walltime. Validates the run is at 100% 
  # progress, else logs error and stops process.
   
  # Argument Usage: 
  #   run : Run object to use for validation.
  #   group : Name of the grouping of tests (maps to JUnit's 'classname').
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
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


proc set_report { _file } {
  # Summary:
  # Configures the JUnit API output location.
   
  # Argument Usage: 
  #   file : Report file name.
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
  variable report $_file
}


proc get_report {} {
  # Summary:
  # Returns the currently set JUnit API output location (see: set_report).
   
  # Argument Usage: 
   
  # Return Value:
  # The currently set report file name.
  
  # Categories: xilinxtclstore, junit
   
  variable report
  return $report
}


proc write_results {} {
  # Summary:
  # Write the in-memory results to disk (uses the set_report/get_report location).
   
  # Argument Usage: 
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
  variable report
  write [ graph_to_xml [ format_junit [ get_results ] ] ] $report  
}


####################################################################################################
# section: intermediate level api
####################################################################################################


proc get_results {} {
  # Summary:
  # Returns the in-memory results, this is a ::struct::graph name.
  # The name of a struct graph is a procedure and is used to configure 
  # and retrieve data from the graph object.
   
  # Argument Usage: 
   
  # Return Value:
  #   The name of the struct::graph holding on to the in-memory results.
  
  # Categories: xilinxtclstore, junit
   
  variable results 
  return $results
}


proc reset_results {} {
  # Summary:
  # Resets the in-memory results, if it exists.
   
  # Argument Usage: 
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
  variable results
  if { "[ info command $results ]" == "$results" } {
    $results destroy
  }
  init
}


proc set_stdout { _content } {
  # Summary:
  # Adds a stdout entry to the global testsuite and sets it's content.
   
  # Argument Usage: 
  #   content : This is the content that stdout will have.
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
  
  variable results
  variable testsuite
  new_stdout $results $testsuite $_content
}


proc set_stderr { _content } {
  # Summary:
  # Adds a stderr entry to the global testsuite and sets it's content.
   
  # Argument Usage: 
  #   content : This is the content that stderr will have.
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
  variable results
  variable testsuite
  new_stderr $results $testsuite $_content
}


proc assert_same { _expected _actual _msg { _name "Same" } { _group "Assertions" } } {
  # Summary:
  # Asserts that two values are the same, else a failure is logged.
   
  # Argument Usage: 
  #   expected : The expected return value.
  #   actual : The received (actual) return value.
  #   msg : Message to log on failure.
  #   name : Name of the test (maps to JUnit's 'name').
  #   group : Name of the grouping of tests (maps to JUnit's 'classname').
   
  # Return Value:
  # Returns true, else an error is thrown.
  
  # Categories: xilinxtclstore, junit
   
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


proc assert_exists { _files _msg { _name "FileExists" } { _group "Assertions" } } {
  # Summary:
  # Asserts that all files exist.
   
  # Argument Usage: 
  #   files : List of files to check for existence.
  #   msg : Message to log on failure.
  #   name : Name of the test (maps to JUnit's 'name').
  #   group : Name of the grouping of tests (maps to JUnit's 'classname').
   
  # Return Value:
  # Returns true, else an error is thrown.
  
  # Categories: xilinxtclstore, junit
   
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


proc new_results { _name } {
  # Summary:
  # Create a new in-memory results object.
   
  # Argument Usage: 
  #   name : Name of the results object.
   
  # Return Value:
  # Returns the name of the new object.
  
  # Categories: xilinxtclstore, junit
   
  ::struct::graph $_name
  return $_name
}


proc new_testsuites { _results } {
  # Summary:
  # Create a new node 'testsuites' in the provided results object.
   
  # Argument Usage: 
  #   results : The results object to add the testsuites node to.
   
  # Return Value:
  # Returns the new testsuites node. 
  
  # Categories: xilinxtclstore, junit
   
  return [ $_results node insert ]
}


proc new_testsuite { _results _parent _name _starttime _hostname } {
  # Summary:
  # Create a new node 'testsuite' in the provided results object.
  # Added under the provided parent node (testsuites).
   
  # Argument Usage: 
  #   results : The results object to add the testsuites node to.
  #   parent : The testsuites node to add the testsuite node under.
  #   name : The name of the testsuite node.
  #   starttime : The starttime of the testsuite node.
  #   hostname : The hostname of the testsuite node.
   
  # Return Value:
  # Returns the new testsuite node.
  
  # Categories: xilinxtclstore, junit
   
  set node [ $_results node insert ]
  $_results node set $node name $_name
  $_results node set $node starttime $_starttime
  $_results node set $node hostname $_hostname
  $_results arc insert $_parent $node
  return $node
}


proc new_testcase { _results _parent _name _group { _walltime 0 } } {
  # Summary:
  # Create a new node 'testcase' in the provided results object.
  # Added under the provided parent node (testsuite).
   
  # Argument Usage: 
  #   results : The results object to add the testsuites node to.
  #   parent : The testsuite node to add the testcase node under.
  #   name : The name of the testcase node.
  #   group : The group of the testcase node.
  #   walltime : The walltime of the testcase node.
   
  # Return Value:
  # Returns the new testcase node.
  
  # Categories: xilinxtclstore, junit
   
  set node [ $_results node insert ]
  $_results node set $node type "testcase"
  $_results node set $node name $_name
  $_results node set $node group $_group
  $_results node set $node walltime $_walltime
  $_results arc insert $_parent $node
  return $node
}


proc new_stdout { _results _parent _content } {
  # Summary:
  # Create a new node 'stdout' in the provided results object.
  # Added under the provided parent node (testsuite).
   
  # Argument Usage: 
  #   results : The results object to add the testsuites node to.
  #   parent : The testsuite node to add the testcase node under.
  #   content : The content of stdout.
   
  # Return Value:
  # Returns the new stdout node.
  
  # Categories: xilinxtclstore, junit
   
  set node [ $_results node insert ]
  $_results node set $node type "system-out"
  $_results node set $node content $_content
  $_results arc insert $_parent $node
  return $node
}


proc new_stderr { _results _parent _content } {
  # Summary:
  # Create a new node 'stderr' in the provided results object.
  # Added under the provided parent node (testsuite).
   
  # Argument Usage: 
  #   results : The results object to add the testsuites node to.
  #   parent : The testsuite node to add the stderr node under.
  #   content : The content of stderr.
   
  # Return Value:
  # Returns the new stderr node. 
  
  # Categories: xilinxtclstore, junit
   
  set node [ $_results node insert ]
  $_results node set $node type "system-err"
  $_results node set $node content $_content
  $_results arc insert $_parent $node
  return $node
}


proc new_failure { _results _parent _content _message } {
  # Summary:
  # Create a new node 'failure' in the provided results object.
  # Added under the provided parent node (testcase).
   
  # Argument Usage: 
  #   results : The results object to add the failure node to.
  #   parent : The testcase node to add the failure node under.
  #   content : The content of the failure.
  #   message : The message of the failure.
   
  # Return Value:
  # Returns the new failure node.
  
  # Categories: xilinxtclstore, junit
   
  set node [ $_results node insert ]
  $_results node set $node type "failure"
  $_results node set $node content $_content
  $_results node set $node message $_message
  $_results arc insert $_parent $node
  return $node
}


proc new_error { _results _parent _content _message } {
  # Summary:
  # Create a new node 'error' in the provided results object.
  # Added under the provided parent node (testcase).
   
  # Argument Usage: 
  #   results : The results object to add the error node to.
  #   parent : The testcase node to add the error node under.
  #   content : The content of the error.
  #   message : The message of the error.
   
  # Return Value:
  # Returns the new error node.
  
  # Categories: xilinxtclstore, junit
   
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


proc init {} {
  # Summary:
  # Initialize the new global results and global testsuite.
   
  # Argument Usage: 
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
  variable results
  #if { "[ info command $results ]" == "$results" } { return }
  set time [ clock format [ clock seconds ] -format "%Y-%m-%dT%H:%M:%S" ] 
  set hostname [ info hostname ]
  new_results $results 
  set testsuites [ new_testsuites $results ]
  variable testsuite [ new_testsuite $results $testsuites "Testsuite" $time $hostname ]
}


proc validate_objects { _objects _expected } {
  # Summary:
  # Validates the object types to make sure they are of the expected type.
   
  # Argument Usage: 
  #   objects : Objects to verify.
  #   expected : Object type to validate.
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
  catch { lsort -unique [ get_property class $_objects ] } clazz
  if { "$clazz" != "$_expected" } { error "Expected '${_expected}' object(s) received: '${clazz}'" }
}


proc validate_object { _object _expected } {
  # Summary:
  # Validates the object type to make sure it is of the expected type.
   
  # Argument Usage: 
  #   object : Object to verify.
  #   expected : Object type to validate.
   
  # Return Value:
  
  # Categories: xilinxtclstore, junit
   
  catch { get_property class $_object } clazz
  if { "$clazz" != "$_expected" } { error "Expected '${_expected}' object(s) received: '${clazz}'" }
}


# Used to initialize the global graph 
reset_results


}; # namespace ::tclapp::xilinx::junit
