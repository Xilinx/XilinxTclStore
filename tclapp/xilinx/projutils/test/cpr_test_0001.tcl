set file_dir [file normalize [file dirname [info script]]]

puts "== Unit Test directory: $file_dir"
#set ::env(XILINX_TCLAPP_REPO) [file normalize [file join $file_dir .. .. ..]]

#puts "== Application directory: $::env(XILINX_TCLAPP_REPO)"
#lappend auto_path $::env(XILINX_TCLAPP_REPO)

set name            "cpr_test_0001"
set result_dir      [ file normalize [ file join $file_dir "cpr_results" ] ]
set data_origin_dir [ file normalize [ file join $file_dir "data" ] ]

if { [ file exists $result_dir ] } {
  file delete -force $result_dir 
}
file mkdir $result_dir


# Test starts here

package require struct
proc compare_runs { run1 run2 {ignore {}} } {
  puts "Comparing runs '${run1}' and '${run2}'"
  set always_ignore   { DIRECTORY NAME }
  set ignore          [ concat $always_ignore $ignore ]
  set properties1     [ list_property $run1 ]
  set properties2     [ list_property $run2 ]
  set deltas1         [ ::struct::set difference $properties1 $properties2 ]
  set deltas2         [ ::struct::set difference $properties2 $properties1 ]
  if { ( [ llength $deltas1 ] != 0 ) || ( [ llength $deltas2 ] != 0 ) } {
    error "\nERROR: There are differences between the property names on '${run1}' and '${run2}'\n\
    Run 1 is missing : '[ join $deltas2 ',\ ' ]'\n\
    Run 2 is missing : '[ join $deltas1 ',\ ' ]'\n"
  }
  foreach property $properties1 {
    if { [ lsearch -nocase $ignore $property ] != -1 } {
      puts "  Skipping the property '${property}'"
      continue
    }
    set run1_value [ get_property $property $run1 ]
    set run2_value [ get_property $property $run2 ]
    if { $run1_value != $run2_value } {
      error "\nERROR: Difference detected for property '${property}':\n\
      '${run1}' has '${run1_value}'\n\
      '${run2}' has '${run2_value}'\n"
    }
    puts "  Validated the property '${property}'"
  }
}


create_project -dir [ file join $result_dir tp ] tp


puts " = Validating project"
if { "[ get_runs synth_1 ]" != "synth_1" } { error "\nERROR: Default project configuration did not have the synth_1 run as expected" }
if { "[ get_runs impl_1 ]" != "impl_1" } { error "\nERROR: Default project configuration did not have the impl_1 run as expected" }


puts " = Read-only projects"
set_property IS_READONLY 1 [ current_project ]
if { ! [ catch { copy_run -verbose synth_1 -name synth_1_readonly } ] } { error "\nERROR: Didn't receive expected error with: read-only project copy_run should fail" }
set_property IS_READONLY 0 [ current_project ]


puts " = Validating business rules"
if { ! [ catch { copy_run -verbose } ] } { error "\nERROR: Didn't receive expected error with: no run specified" }
if { ! [ catch { copy_run -verbose synth_1 } ] } { error "\nERROR: Didn't receive expected error with: no name specified" }
if { ! [ catch { copy_run -verbose null_run -name null_run } ] } { error "\nERROR: Didn't receive expected error with: non-existent run source" }
if { ! [ catch { copy_run -verbose impl_1 -name impl_1_copy -parent_run null_run } ] } { error "\nERROR: Didn't receive expected error with: non-existent parent run" }
if { ! [ catch { copy_run -verbose synth_1 -name synth_1 } ] } { error "\nERROR: Didn't receive expected error with: already existing run destination" }


puts " = Validating synthesis"
set run_synth_1_copy_1 [ copy_run -verbose synth_1 -name synth_1_copy_1 ]
compare_runs [ get_runs synth_1 ] $run_synth_1_copy_1


puts " = Validating implementation"
set run_impl_1_copy_1 [ copy_run -verbose impl_1 -name impl_1_copy_1 ]
compare_runs [ get_runs impl_1 ] $run_impl_1_copy_1

puts " = Validating implementation -parent_run"
set run_impl_1_copy_2 [ copy_run -verbose impl_1 -name impl_1_copy_2 -parent_run $run_synth_1_copy_1 ]
set post_parent_run [ get_property PARENT $run_impl_1_copy_2 ]
if { $post_parent_run != $run_synth_1_copy_1 } {
  error "\nERROR: The '-parent_run' switch was specified with '${run_synth_1_copy_1}' the value was set to '${post_parent_run}'"
}
set ignore_properties {PARENT}
compare_runs [ get_runs impl_1 ] $run_impl_1_copy_2 $ignore_properties


puts " = Validating synthesis properties"

puts "Start with a new golden run called 'synth_2'"
set synth_2 [ create_run synth_2 -flow [ get_property FLOW [ current_run -synthesis ] ] ]

set_property INCLUDE_IN_ARCHIVE 0 $synth_2

set step_properties [ lsearch -regexp -all -inline [ list_property $synth_2 ] "STEPS\\." ] 
foreach step_property $step_properties {
  if { [ regexp "\\.VERBOSE" $step_property ] } {
    set_property $step_property 1 $synth_2
  }
  if { [ regexp "\\.IS_ENABLED" $step_property ] } {
    set_property $step_property 1 $synth_2
  }
  if { [ regexp "\\.TCL\\." $step_property ] } {
    set_property $step_property "test_[clock microseconds]" $synth_2
  }
}

set synth_2_copy_1 [ copy_run -verbose synth_2 -name synth_2_copy_1 ]
compare_runs [ get_runs synth_2 ] $synth_2_copy_1


puts " = Validating implementation properties"

puts "Start with a new golden run called 'impl_2'"
set impl_2 [ create_run impl_2 -flow [ get_property FLOW [ current_run -implementation ] ] -parent_run [ current_run -synthesis ] ]

set_property INCLUDE_IN_ARCHIVE 0 $impl_2

set step_properties [ lsearch -regexp -all -inline [ list_property $impl_2 ] "STEPS\\." ] 
foreach step_property $step_properties {
  if { [ regexp "\\.VERBOSE" $step_property ] } {
    set_property $step_property 1 $impl_2
  }
  if { [ regexp "\\.IS_ENABLED" $step_property ] } {
    set_property $step_property 1 $impl_2
  }
  if { [ regexp "\\.TCL\\." $step_property ] } {
    set_property $step_property "test_[clock microseconds]" $impl_2
  }
}

set impl_2_copy_1 [ copy_run -verbose impl_2 -name impl_2_copy_1 ]
compare_runs [ get_runs impl_2 ] $impl_2_copy_1


# cleanup if we didn't error
file delete -force $result_dir

puts "\nSUCCESS\n\ndone."

puts ""
puts "   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
puts "   !!!   NOTICE: This test has completed SUCCESSFULLY, errors above were    !!!"
puts "   !!!   expected and were negative tests. Unexpected conditions stop flow. !!!"
puts "   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
puts ""

