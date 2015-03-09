# Diff App


## Getting started:

    tclapp::install diff
    package require ::tclapp::xilinx::diff

## Why would I use this app?

### Compare all Cell 'Names' in two GUIs (same session)...

    # Select GUI 1 and run...
    Vivado% set design1 [ get_property NAME [ get_cells -hierarchical -filter { IS_PRIMITIVE == 1 } ] ]
    # Select GUI 2 and run...
    Vivado% set design2 [ get_property NAME [ get_cells -hierarchical -filter { IS_PRIMITIVE == 1 } ] ]
    Vivado% ::tclapp::xilinx::diff::compare_unordered_lists $design1 $design2

    # Output:
    $$ Comparing Unordered Lists...
    == They are equivalent

### Compare all Cell 'Names' with two in-memory Designs (same session)...

    # Same as above with a simple command...
    Vivado% ::tclapp::xilinx::diff::open_checkpoints design1.dcp design2.dcp
    Vivado% ::tclapp::xilinx::diff::compare_designs compare_unordered_lists { get_property NAME [ get_cells -hierarchical -filter { IS_PRIMITIVE == 1 } ] } 
    
    # Output:
    @@   get_property NAME [ get_cells -hierarchical -filter { IS_PRIMITIVE == 1 } ] 
    $$ Comparing Unordered Lists...
    == They are equivalent

### Compare all Cell 'Locations' in two GUIs (same session)...

    # Select GUI 1 and run...
    Vivado% set design1 [ get_property LOC [ get_cells -hierarchical -filter { IS_PRIMITIVE == 1 } ] ]
    # Select GUI 2 and run...
    Vivado% set design2 [ get_property LOC [ get_cells -hierarchical -filter { IS_PRIMITIVE == 1 } ] ]
    Vivado% ::tclapp::xilinx::diff::compare_unordered_lists $design1 $design2
    
    # Output:
    $$ Comparing Unordered Lists...
    !! Differences found:
     List 1 has 1 unique:
      SLICE_X0Y100
     List 2 has 1 unique:
      SLICE_X0Y101

### Compare all Cell 'Locations' with two in-memory Designs (same session)...

    # Same as above with a simple command...
    Vivado% ::tclapp::xilinx::diff::open_checkpoints design1.dcp design2.dcp
    Vivado% ::tclapp::xilinx::diff::compare_designs compare_unordered_lists { get_property LOC [ get_cells -hierarchical -filter { IS_PRIMITIVE == 1 } ] }
    
    # Output:
    @@  get_property LOC [ get_cells -hierarchical -filter { IS_PRIMITIVE == 1 } ] 
    $$ Comparing Unordered Lists...
    !! Differences found:
     List 1 has 1 unique:
      SLICE_X0Y100
     List 2 has 1 unique:
      SLICE_X0Y101
      
### Compare all Cell Properties with two in-memory Designs (same session)...

    # Compares every property of every cell... 
    Vivado% ::tclapp::xilinx::diff::open_checkpoints design1.dcp design2.dcp
    Vivado% ::tclapp::xilinx::diff::compare_designs compare_serialized_objects { serialize_objects [ get_cells -hierarchical -filter { IS_PRIMITIVE == 1 } ] }

    # Output:
    @@  serialize_objects [ get_cells -hierarchical -filter { IS_PRIMITIVE == 1 } ] 
    $$ Comparing Objects...
    ** Comparing 234 properties on 'cell' 'ff_stage[2].ff_channel[0].ff/q_reg'...
      Property 'BEL' differs : 'SLICEL.AFF' <=> 'SLICEL.D5FF'
      Property 'HDPCBEL' differs : '' <=> 'D5FF'
      Property 'HDPCLOC' differs : '' <=> 'SLICE_X0Y101'
      Property 'IS_BEL_FIXED' differs : '0' <=> '1'
      Property 'IS_FIXED' differs : '0' <=> '1'
      Property 'IS_LOC_FIXED' differs : '0' <=> '1'
      Property 'LOC' differs : 'SLICE_X0Y100' <=> 'SLICE_X0Y101'
      Property 'SITE' differs : 'SLICE_X0Y100' <=> 'SLICE_X0Y101'
      Property 'STATUS' differs : 'PLACED' <=> 'FIXED'
    !! Differing properties exist, differing properties are:
      BEL HDPCBEL HDPCLOC IS_BEL_FIXED IS_FIXED IS_LOC_FIXED LOC SITE STATUS

### Compare all Net Properties with two in-memory Designs (different sessions)...
    
    # In Session 1 Serialize Design 1 Objects...
    Vivado% tclapp::xilinx::diff::serialize_to_file [ tclapp::xilinx::diff::serialize_objects [ get_nets -hierarchical ] ] ./design_1_nets.dat
    # In Session 2 Serialize Design 1 Objects...
    Vivado% set design1 [ tclapp::xilinx::diff::serialize_from_file ./design_1_nets.dat ]
    Vivado% set design2 [ tclapp::xilinx::diff::serialize_objects [ get_nets -hierarchical ] ]
    Vivado% ::tclapp::xilinx::diff::compare_serialized_objects $design1 $design2
    
    # Output:
    $$ Comparing Objects...
    ** Comparing 178 properties on 'net' 'ff_stage[1].ff_channel[0].ff/O1'...
      Property 'ROUTE' differs : ' { CLBLL_L_AQ CLBLL_LOGIC_OUTS0 WW4BEG0 ER1BEG1 BYP_ALT5 BYP_BOUNCE5 FAN_ALT5 FAN_BOUNCE5 BYP_ALT1 BYP_L1 CLBLL_LL_AX }  ' <=> ' { CLBLL_L_AQ CLBLL_LOGIC_OUTS0 NW6BEG0 SR1BEG_S0 SE2BEG0 EL1BEG_N3 BYP_ALT6 BYP_L6 CLBLL_LL_DX }  '
    ** Comparing 178 properties on 'net' 'ff_stage[2].ff_channel[0].ff/dout[0]'...
      Property 'ROUTE' differs : ' { CLBLL_LL_AQ CLBLL_LOGIC_OUTS4 WR1BEG1 WL1BEG_N3 SR1BEG_S0 IMUX_L34 IOI_OLOGIC0_D1 LIOI_OLOGIC0_OQ LIOI_O0 }  ' <=> ' { CLBLL_LL_DMUX CLBLL_LOGIC_OUTS23 WW2BEG1 SS2BEG1 IMUX_L34 IOI_OLOGIC0_D1 LIOI_OLOGIC0_OQ LIOI_O0 }  '
    !! Differing properties exist, differing properties are:
      ROUTE

### Compare all Timing Paths with two in-memory Designs (same sessions)...

    # Compares every property of the worst 1000 timing paths... 
    Vivado% ::tclapp::xilinx::diff::open_checkpoints design1.dcp design2.dcp
    Vivado% ::tclapp::xilinx::diff::compare_designs compare_serialized_objects { tclapp::xilinx::diff::serialize_objects [get_timing_paths -max_paths 1000] }

    # Output:
    @@  get_timing_paths -max_paths 1000 
    $$ Comparing Objects...
    ** Comparing 50 properties on 'timing_path' '{din[0] --> ff_stage[0].ff_channel[0].ff/q_reg/D}'...
      Property 'ENDPOINT_PIN' differs : 'q_reg/D' <=> 'ff_stage[0].ff_channel[0].ff/q_reg/D'
    ** Comparing 50 properties on 'timing_path' '{ff_stage[2].ff_channel[0].ff/q_reg/C --> dout[0]}'...
      Property 'DATAPATH_DELAY' differs : '4.930' <=> '4.939'
      Property 'SLACK' differs : '-11.138' <=> '-11.147'
      Property 'STARTPOINT_PIN' differs : 'q_reg/C' <=> 'ff_stage[2].ff_channel[0].ff/q_reg/C'
    !! Differing properties exist, differing properties are:
      DATAPATH_DELAY ENDPOINT_PIN SLACK ENDPOINT_PIN

## All Available Commands

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


