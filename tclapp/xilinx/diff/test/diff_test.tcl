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
namespace import ::tclapp::${app_name}::*
  
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

set reports [ list "stdout" "diff.html" "diff.log" ]
foreach report $reports {
  set_global_report $report
  print_start "My Difference Report"

  print_header "Comparing Serialized Parts"
  compare_serialized_objects $serialized_part1 $serialized_part2

  print_header "Comparing files:\n  ${data_file1}\n  ${data_file2}"
  compare_files $data_file1 $data_file2

  set read_part1 [ serialize_from_file $data_file1 ]
  set read_part2 [ serialize_from_file $data_file2 ]
  print_header "Comparing Serialized Parts From Files"
  compare_serialized_objects $read_part1 $read_part2
  
  # design comparisons
  #set design1  [ open_checkpoint ${test_dir}/design1.dcp ]
  #set project1 [ current_project ] 
  #set design2  [ open_checkpoint ${test_dir}/design2.dcp ]
  #set project2 [ current_project ]
  #set_designs $design1 $project1 $design2 $project2
  open_checkpoints "${test_dir}/design1.dcp" "${test_dir}/design2.dcp"

  # lists
  compare_designs compare_unordered_lists { get_cells -hierarchical }
  compare_designs compare_ordered_lists { get_cells -hierarchical }
  compare_designs compare_unordered_lists { get_nets -hierarchical }
  compare_designs compare_unordered_lists { get_clocks }
  compare_designs compare_unordered_lists { get_ports }

  # unordered lists vs lines
  compare_designs compare_unordered_lists { get_property LOC [lsort [ get_cells -hierarchical ] ] }
  compare_designs compare_lines { join [ get_property LOC [ lsort [ get_cells -hierarchical ] ] ] \n }

  # reports
  set report1 "timing1.log"
  set report2 "timing2.log"
  activate_design 1
  report_timing -file $report1 -max_paths 1000 
  activate_design 2
  report_timing -file $report2 -max_paths 1000 
  print_header "Comparing Timing Files"
  compare_files $report1 $report2
  compare_designs compare_lines { report_timing -return_string -max_paths 1000 }
  compare_designs compare_lines { report_route_status -return_string -list_all_nets }
  compare_designs compare_lines { report_route_status -return_string -of_objects [get_nets] }

  # objects
  compare_designs compare_serialized_objects { serialize_objects [ lrange [ get_cells -hierarchical ] 0 9 ] }
  compare_designs compare_objects { lrange [ get_cells -hierarchical ] 9 19 }
  compare_designs compare_objects { get_timing_paths -max_paths 1000 }

  # multi-line capable
  compare_designs compare_unordered_lists {
  	set paths [ get_timing_paths -max_paths 1000 ]
  	return [ get_property SLACK [ lsort $paths ] ]
  }
  
  compare_designs compare_unordered_lists {
  	set cells [ get_cells -hierarchical ]
  	return [ get_property LOC [ lsort $cells ] ]
  } 
  
  compare_designs compare_lines {
  	set nets [ get_nets ]
  	set subset_nets [ lrange $nets 0 10 ]
  	return [ list [ report_route_status -return_string -of_objects [ get_nets $subset_nets ] ] ]
  } 
  
  compare_designs compare_objects {
  	set paths [ get_timing_paths -max_paths 1000 ]
  	return $paths
  }

  # done
  print_end

}

