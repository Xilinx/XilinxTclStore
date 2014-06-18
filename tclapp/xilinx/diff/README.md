# Diff App


## Require the package:

    package require ::tclapp::xilinx::diff

## Use a command:

### Comparisons - Compare data, files, lists, objects, and even previously saved (serialized) objects

    unique_in_first_set             unique_in_both_sets
    compare_objects                 compare_lines
    compare_serialized_objects      compare_ordered_lists
    compare_dirs                    compare_unordered_lists
    compare_files

### Assertions - Compare and Validate Data

    assert_same                     assert_same_file
    assert_true                     assert_file_exists
    assert_false                    assert_string_in_file
    assert_pass                     assert_string_not_in_file
    assert_fail

### Designs - Simple helpers to compare objects between designs or projects

    open_checkpoints                activate_design 
    compare_designs

### Serialize Objects - For storage and later comparison

    serialize_to_file               serialize_objects
    serialize_from_file

### Filter Results - To ensure valid comparisons

    remove_special                  remove_whitespace
    remove_datestamps               html_escape

## Example Script 

    package require ::tclapp::xilinx::diff
    
    # setup
    ::tclapp::xilinx::diff::set_verbose 1
    ::tclapp::xilinx::diff::set_global_report stdout

    # static part comparisons
    set part1 [ lindex [ get_parts ] 0 ]
    set part2 [ lindex [ get_parts ] 1 ]

    ::tclapp::xilinx::diff::print_start "Global STDOUT Override"
    ::tclapp::xilinx::diff::print_header "Comparing Parts"
    ::tclapp::xilinx::diff::compare_objects $part1 $part2

    ::tclapp::xilinx::diff::print_start "STDOUT Override" stdout
    ::tclapp::xilinx::diff::print_header "Comparing Parts" stdout
    ::tclapp::xilinx::diff::compare_objects $part1 $part2 stdout 

    ::tclapp::xilinx::diff::print_start "Text File Override" "override.dat"
    ::tclapp::xilinx::diff::print_header "Comparing Parts" "override.dat"
    ::tclapp::xilinx::diff::compare_objects $part1 $part2 "override.dat"

    ::tclapp::xilinx::diff::print_start "HTML File Override" "override.html"
    ::tclapp::xilinx::diff::print_header "Comparing Parts" "override.html"
    ::tclapp::xilinx::diff::compare_objects $part1 $part2 "override.html"
    ::tclapp::xilinx::diff::print_end "override.html"

    set serialized_part1 [ ::tclapp::xilinx::diff::serialize_objects $part1 ]
    set serialized_part2 [ ::tclapp::xilinx::diff::serialize_objects $part2 ]

    set data_file1 "part1.dat"
    set data_file2 "part2.dat"
    ::tclapp::xilinx::diff::serialize_to_file $serialized_part1 $data_file1
    ::tclapp::xilinx::diff::serialize_to_file $serialized_part2 $data_file2

    set reports [ list "stdout" "diff.html" "diff.log" ]
    foreach report $reports {
      ::tclapp::xilinx::diff::set_global_report $report
      ::tclapp::xilinx::diff::print_start "My Difference Report"

      ::tclapp::xilinx::diff::print_header "Version"
      ::tclapp::xilinx::diff::print_stamp

      ::tclapp::xilinx::diff::print_header "Comparing Serialized Parts"
      ::tclapp::xilinx::diff::compare_serialized_objects $serialized_part1 $serialized_part2

      ::tclapp::xilinx::diff::print_header "Comparing files:\n  ${data_file1}\n  ${data_file2}"
      ::tclapp::xilinx::diff::compare_files $data_file1 $data_file2

      set this_dir [ file dirname [ info script ] ] 
      set this_parent_dir [ file dirname $this_dir ]
      ::tclapp::xilinx::diff::print_header "Comparing Directories"
      ::tclapp::xilinx::diff::compare_dirs $this_dir $this_parent_dir

      set read_part1 [ ::tclapp::xilinx::diff::serialize_from_file $data_file1 ]
      set read_part2 [ ::tclapp::xilinx::diff::serialize_from_file $data_file2 ]
      ::tclapp::xilinx::diff::print_header "Comparing Serialized Parts From Files"
      ::tclapp::xilinx::diff::compare_serialized_objects $read_part1 $read_part2
      
      # design comparisons
      #set design1  [ open_checkpoint ${test_dir}/design1.dcp ]
      #set project1 [ current_project ] 
      #set design2  [ open_checkpoint ${test_dir}/design2.dcp ]
      #set project2 [ current_project ]
      #::tclapp::xilinx::diff::set_compare_objects $design1 $project1 $design2 $project2
      ::tclapp::xilinx::diff::open_checkpoints "${test_dir}/design1.dcp" "${test_dir}/design2.dcp"

      # lists
      ::tclapp::xilinx::diff::compare_designs compare_unordered_lists { get_cells -hierarchical }
      ::tclapp::xilinx::diff::compare_designs compare_ordered_lists   { get_cells -hierarchical }
      ::tclapp::xilinx::diff::compare_designs compare_lines_lcs       { join [ get_cells -hierarchical ] \n }
      ::tclapp::xilinx::diff::compare_designs compare_unordered_lists { get_clocks }
      ::tclapp::xilinx::diff::compare_designs compare_unordered_lists { get_ports }
      ::tclapp::xilinx::diff::compare_designs compare_unordered_lists { get_nets -hierarchical }

      # unordered lists vs lines
      ::tclapp::xilinx::diff::compare_designs compare_unordered_lists { get_property LOC [lsort [ get_cells -hierarchical ] ] }
      ::tclapp::xilinx::diff::compare_designs compare_lines { join [ get_property LOC [ lsort [ get_cells -hierarchical ] ] ] \n }

      # reports
      set report1 "timing1.log"
      set report2 "timing2.log"
      ::tclapp::xilinx::diff::activate_design 1
      report_timing -file $report1 -max_paths 1000 
      ::tclapp::xilinx::diff::activate_design 2
      report_timing -file $report2 -max_paths 1000 
      ::tclapp::xilinx::diff::print_header "Comparing Timing Files"
      ::tclapp::xilinx::diff::compare_files $report1 $report2
      ::tclapp::xilinx::diff::compare_designs compare_lines { report_timing -return_string -max_paths 1000 }
      ::tclapp::xilinx::diff::compare_designs compare_lines { report_route_status -return_string -list_all_nets }
      ::tclapp::xilinx::diff::compare_designs compare_lines { report_route_status -return_string -of_objects [get_nets] }

      # objects
      ::tclapp::xilinx::diff::compare_designs compare_serialized_objects { serialize_objects [ lrange [ get_cells -hierarchical ] 0 9 ] }
      ::tclapp::xilinx::diff::compare_designs compare_objects { lrange [ get_cells -hierarchical ] 9 19 }
      ::tclapp::xilinx::diff::compare_designs compare_objects { get_timing_paths -max_paths 1000 }

      # multi-line capable
      ::tclapp::xilinx::diff::compare_designs compare_unordered_lists {
        set paths [ get_timing_paths -max_paths 1000 ]
        return [ get_property SLACK [ lsort $paths ] ]
      }
      
      ::tclapp::xilinx::diff::compare_designs compare_unordered_lists {
        set cells [ get_cells -hierarchical ]
        return [ get_property LOC [ lsort $cells ] ]
      } 
      
      ::tclapp::xilinx::diff::compare_designs compare_lines {
        set nets [ get_nets ]
        set subset_nets [ lrange $nets 0 10 ]
        return [ list [ report_route_status -return_string -of_objects [ get_nets $subset_nets ] ] ]
      } 
      
      ::tclapp::xilinx::diff::compare_designs compare_objects {
        set paths [ get_timing_paths -max_paths 1000 ]
        return $paths
      }

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
        this-test is*the#same as_the text below
        this%test^is!the@same(as)the+text=below
      }

      ::tclapp::xilinx::diff::print_header "Comparing Clean"
      ::tclapp::xilinx::diff::compare_lines $clean $clean 

      ::tclapp::xilinx::diff::print_header "Comparing White"
      ::tclapp::xilinx::diff::compare_lines $clean $white 
      
      ::tclapp::xilinx::diff::print_header "Comparing White Filtered"
      ::tclapp::xilinx::diff::compare_lines [ remove_whitespace $clean ] [ remove_whitespace $white ]
      
      ::tclapp::xilinx::diff::print_header "Comparing Special"
      ::tclapp::xilinx::diff::compare_lines $clean $special
      
      ::tclapp::xilinx::diff::print_header "Comparing Special Filtered"
      ::tclapp::xilinx::diff::compare_lines $clean [ remove_special $special ]
      
      set paused true
      after 1000 { set paused false }; #ensures 1 second of timestamp difference
      vwait paused
      ::tclapp::xilinx::diff::activate_design 1

      set report1_data [ ::tclapp::xilinx::diff::serialize_from_file $report1 ]
      set report3_data [ report_timing -return_string -max_paths 1000 ]
      
      ::tclapp::xilinx::diff::print_header "Comparing Same Reports with Differing Commands and Timestamps"
      ::tclapp::xilinx::diff::compare_lines $report1_data $report3_data

      # manually filter '| Command.*' to deal with:
      #| Command      : report_timing -file timing1.log -max_paths 1000
      #| Command      : report_timing -return_string -max_paths 1000
      set report1_data [ regsub -all -line {(\|\ Command)(.*)} $report1_data {\1<removed>} ]
      set report3_data [ regsub -all -line {(\|\ Command)(.*)} $report3_data {\1<removed>} ]
      
      ::tclapp::xilinx::diff::print_header "Comparing Same Reports with Differing Timestamps"
      ::tclapp::xilinx::diff::compare_lines $report1_data $report3_data
      
      ::tclapp::xilinx::diff::print_header "Comparing Same Reports with Differing Timestamps Filtered"
      set report1_ds [ ::tclapp::xilinx::diff::remove_datestamps $report1_data ] 
      set report2_ds [ ::tclapp::xilinx::diff::remove_datestamps $report3_data ]
      ::tclapp::xilinx::diff::compare_lines $report1_ds $report2_ds

      # assertions
      ::tclapp::xilinx::diff::print_header "Assertions"
      ::tclapp::xilinx::diff::print_subheader ""
      ::tclapp::xilinx::diff::assert_same $report1_data $report1_data
      ::tclapp::xilinx::diff::assert_true  [ expr 1 && true ]
      ::tclapp::xilinx::diff::assert_false [ expr 1 && false ]
      ::tclapp::xilinx::diff::assert_pass { puts "test" }
      ::tclapp::xilinx::diff::assert_fail { puts -bad "test" }
      ::tclapp::xilinx::diff::assert_same_file $report1 $report1
      ::tclapp::xilinx::diff::assert_file_exists [ info script ]
      ::tclapp::xilinx::diff::assert_string_in_file {Command} $report1
      ::tclapp::xilinx::diff::assert_string_not_in_file {This doesn't exist} $report1

      # done
      ::tclapp::xilinx::diff::print_end

    }


