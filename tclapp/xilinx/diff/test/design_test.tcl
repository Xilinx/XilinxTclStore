set app_name {xilinx::diff}
  
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
  
# Start the unit tests
puts "script is invoked from $test_dir"


# setup
set_verbose 1
set_global_report stdout

# static part comparisons
set part1 [ lindex [ get_parts ] 0 ]
set part2 [ lindex [ get_parts ] end ]

print_start "Global STDOUT Override"
print_header "Comparing Parts"
compare_objects $part1 $part2

print_start "STDOUT Override" stdout
print_header "Comparing Parts" stdout
compare_objects $part1 $part2 stdout 

print_start "Text File Override" "override.dat"
print_header "Comparing Parts" "override.dat"
compare_objects $part1 $part2 "override.dat"

print_start "HTML File Override" "override.html"
print_header "Comparing Parts" "override.html"
compare_objects $part1 $part2 "override.html"
print_end "override.html"

set serialized_part1 [ serialize_objects $part1 ]
set serialized_part2 [ serialize_objects $part2 ]

set data_file1 "part1.dat"
set data_file2 "part2.dat"
serialize_to_file $serialized_part1 $data_file1
serialize_to_file $serialized_part2 $data_file2

# This loop retests some of the unit tests, but using different reporting methods
# Such as: stdout, html, log, and does so using the global report property
set reports [ list "stdout" "diff.html" "diff.log" ]
foreach report $reports {
  set_global_report $report
  print_start "My Difference Report"

  print_header "Version"
  print_stamp
  print_info "This design has the same logic, but one cell has been moved \n\
              this leads to location property, routing, and timing differences \n\
              (the design was rerouted)."

  print_header "Comparing Serialized Parts"
  compare_serialized_objects $serialized_part1 $serialized_part2

  print_header "Comparing files:\n  ${data_file1}\n  ${data_file2}"
  compare_files $data_file1 $data_file2

  set this_dir [ file dirname [ info script ] ] 
  set this_parent_dir [ file dirname $this_dir ]
  print_header "Comparing Directories"
  compare_dirs $this_dir $this_parent_dir

  set read_part1 [ serialize_from_file $data_file1 ]
  set read_part2 [ serialize_from_file $data_file2 ]
  print_header "Comparing Serialized Parts From Files"
  compare_serialized_objects $read_part1 $read_part2
  
  # design comparisons
  #set design1  [ open_checkpoint ${test_dir}/design1.dcp ]
  #set project1 [ current_project ] 
  #set design2  [ open_checkpoint ${test_dir}/design2.dcp ]
  #set project2 [ current_project ]
  #set_compare_objects $design1 $project1 $design2 $project2
  open_checkpoints "${test_dir}/design1.dcp" "${test_dir}/design2.dcp"

  # lists
  assert_same [ list ] [ compare_designs compare_unordered_lists { get_cells -hierarchical } ] "Expect no logical differences"
  assert_same 0        [ compare_designs compare_ordered_lists   { get_cells -hierarchical } ] "Expect no logical differences"
  assert_same 0        [ compare_designs compare_lines_lcs       { join [ get_cells -hierarchical ] \n } ] "Expect no logical differences"
  assert_same [ list ] [ compare_designs compare_unordered_lists { get_clocks } ] "Expect no logical differences"
  assert_same [ list ] [ compare_designs compare_unordered_lists { get_ports } ] "Expect no logical differences"
  assert_same [ list ] [ compare_designs compare_unordered_lists { get_nets -hierarchical } ] "Expect no logical differences"

  # unordered lists vs lines
  set different_locs [ compare_designs compare_unordered_lists { 
    get_property LOC [ lsort [ get_cells -hierarchical ] ] 
  } ]
  assert_true [ expr [ llength $different_locs ] > 0 ] "Expect LOC differences"
  set different_loc_count [ compare_designs compare_lines { 
    join [ get_property LOC [ lsort [ get_cells -hierarchical ] ] ] \n 
  } ]
  assert_true [ expr $different_loc_count > 0 ] "Expect LOC differences"

  # reports
  set report1 "timing1.log"
  set report2 "timing2.log"
  activate_design 1
  report_timing -file $report1 -max_paths 1000 
  activate_design 2
  report_timing -file $report2 -max_paths 1000 
  print_header "Comparing Timing Files"
  set different_timing_files [ compare_files $report1 $report2 ]
  assert_true [ expr $different_timing_files > 0 ] "Expect timing differences"

  set different_timing [ compare_designs compare_lines { 
    report_timing -return_string -max_paths 1000 
  } ] 
  assert_true [ expr $different_timing > 0 ] "Expect timing differences"

  set different_route_nets [ compare_designs compare_lines { 
    report_route_status -return_string -list_all_nets 
  } ] 
  assert_true [ expr $different_route_nets == 0 ] "Expect nets to be the same"
  
  set different_route_of_nets [ compare_designs compare_lines { 
    report_route_status -return_string -of_objects [get_nets] 
  } ]
  assert_true [ expr $different_route_of_nets > 0 ] "Expect of nets to be different"

  # objects
  set cell_serial_differences [ compare_designs compare_serialized_objects { 
    serialize_objects [ get_cells -hierarchical ]
  } ]
  assert_true [ expr [ llength $cell_serial_differences ] > 0 ] "Expect cell property (LOC, FIXED, ...) differences"

  set cell_differences [ compare_designs compare_objects { 
    get_cells -hierarchical
  } ]
  assert_true [ expr [ llength $cell_differences ] > 0 ] "Expect cell property (LOC, FIXED, ...) differences"

  set timing_differences [ compare_designs compare_objects { get_timing_paths -max_paths 1000 } ]
  assert_true [ expr [ llength $timing_differences ] > 0 ] "Expect timing property (SLACK, SKEW, ...) differences"

  set net_differences [ compare_designs compare_objects { get_nets -hierarchical } ] 
  assert_true [ expr [ llength $net_differences ] > 0 ] "Expect cell property (ROUTE) differences"

  # multi-line capable
  set multi_slack_differences [ compare_designs compare_unordered_lists {
  	set paths [ get_timing_paths -max_paths 1000 ]
  	return [ get_property SLACK [ lsort $paths ] ]
  } ]
  assert_true [ expr [ llength $multi_slack_differences ] > 0 ] "Expect timing property (SLACK, SKEW, ...) differences"


  set multi_loc_differences [ compare_designs compare_unordered_lists {
  	set cells [ get_cells -hierarchical ]
  	return [ get_property LOC [ lsort $cells ] ]
  } ]
  assert_true [ expr [ llength $multi_loc_differences ] > 0 ] "Expect cell property (LOC) differences"
  
  # won't compare on limited range output, could change with ordering
  compare_designs compare_lines {
  	set nets [ get_nets ]
  	set subset_nets [ lrange $nets 0 10 ]
  	return [ list [ report_route_status -return_string -of_objects [ get_nets $subset_nets ] ] ]
  } 
  
  set multi_path_differences [ compare_designs compare_objects {
  	set paths [ get_timing_paths -max_paths 1000 ]
  	return $paths
  } ]
  assert_true [ expr [ llength $multi_path_differences ] > 0 ] "Expect timing property (SLACK, SKEW, ...) differences"

  # filters
  set clean { 
    this-test is the same as_the text below
    this test is the same as the text below
  }
  set white { 
    this- test   is the same as_the text below
	this test is the sameas the textbelow
  }
  set special { 
    this-test is* the# same as_the text below
    this% test ^is !the @same (as )the +text= below
  }

  print_header "Comparing Clean"
  assert_same 0 [ compare_lines $clean $clean ] "Expect clean to be the same"

  print_header "Comparing White"
  assert_true [ expr [ compare_lines $clean $white ] > 0 ] "Expect clean and white to be different"
  
  print_header "Comparing White Filtered"
  assert_true [ expr [ compare_lines [ remove_whitespace $clean ] [ remove_whitespace $white ] ] == 0 ] "Expect clean and remove_whitespace to be the same"
  
  print_header "Comparing Special"
  assert_true [ expr [ compare_lines $clean $special ] > 0 ] "Expect clean and special to be different"
  
  print_header "Comparing Special Filtered"
  assert_true [ expr [ compare_lines $clean [ remove_special $special ] ] == 0 ] "Expect clean and remove_special to be the same"
  
  set paused true
  after 1000 { set paused false }; #ensures 1 second of timestamp difference, since report1 was generated
  vwait paused
  activate_design 1

  set report1_data [ serialize_from_file $report1 ]
  set report3_data [ report_timing -return_string -max_paths 1000 ]
  
  print_header "Comparing Same Reports with Differing Commands and Timestamps"
  set report_differenecs [ compare_lines $report1_data $report3_data ]
  assert_true [ expr $report_differenecs > 0 ] "Expect report differences due to command and timestamps"

  # manually filter '| Command.*' to deal with:
  #| Command      : report_timing -file timing1.log -max_paths 1000
  #| Command      : report_timing -return_string -max_paths 1000
  set report1_data [ regsub -all -line {(\|\ Command)(.*)} $report1_data {\1<removed>} ]
  set report3_data [ regsub -all -line {(\|\ Command)(.*)} $report3_data {\1<removed>} ]
  
  print_header "Comparing Same Reports with Differing Timestamps"
  set report_differenecs_wo_cmd [ compare_lines $report1_data $report3_data ]
  assert_true [ expr $report_differenecs_wo_cmd > 0 ] "Expect report differences due to timestamps"
  
  print_header "Comparing Same Reports with Differing Timestamps Filtered"
  set report_differenecs_wo_ts [ compare_lines [ remove_datestamps $report1_data ] [ remove_datestamps $report3_data ] ]
  assert_true [ expr $report_differenecs_wo_ts == 0 ] "Expect no report differences, timestamp and cmd were cleaned"

  # assertions
  print_header "Assertions"
  print_subheader ""
  assert_same $report1_data $report1_data
  assert_true  [ expr 1 && true ]
  assert_false [ expr 1 && false ]
  assert_pass { puts "test" }
  assert_fail { puts -bad "test" }
  assert_same_file $report1 $report1
  assert_file_exists [ info script ]
  assert_string_in_file {Command} $report1
  assert_string_not_in_file {This doesn't exist} $report1

  # done
  print_end

}

puts "Done."

