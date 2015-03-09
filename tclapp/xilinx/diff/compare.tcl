####################################################################################################
#
# algorithms.tcl (differencing algorithms)
#
# Script created on 06/15/2014 by Nik Cimino (Xilinx, Inc.)
#
# 2014 - version 2.0 (rev. 1)
#  * encapsulated differencing algorithms and abstracted diff concepts 
# 2012 - version 1.0 (rev. 1)
#  * initial version
#
####################################################################################################

package require Vivado 1.2014.1
package require struct

####################################################################################################
# title: Diff
####################################################################################################

namespace eval ::tclapp::xilinx::diff {


####################################################################################################
# section: variables
####################################################################################################
variable global_report {}
variable verbose 0
variable designs {}
variable projects {}
variable checkpoints {}

####################################################################################################
# section: export public commands
####################################################################################################
namespace export set_global_report
namespace export get_global_report
namespace export set_verbose
namespace export get_verbose
namespace export set_compare_objects 
namespace export get_compare_objects 
namespace export set_checkpoints 
namespace export get_checkpoints 

namespace export open_checkpoints 

namespace export activate_design 
namespace export compare_designs

namespace export unique_in_first_set
namespace export unique_in_both_sets

namespace export serialize_objects
namespace export serialize_to_file
namespace export serialize_from_file

namespace export compare_objects
namespace export compare_serialized_objects
namespace export compare_dirs
namespace export compare_files
namespace export compare_lines
namespace export compare_ordered_lists
namespace export compare_unordered_lists

namespace export print_stamp 
namespace export print_css 
namespace export print_js 
namespace export print_msg
namespace export print_start
namespace export print_info
namespace export print_subheader 
namespace export print_header
namespace export print_alert
namespace export print_success
namespace export print_results
namespace export print_end

namespace export html_escape
namespace export remove_whitespace
namespace export remove_special
namespace export remove_datestamps
namespace export remove_comments

namespace export assert_same
namespace export assert_true
namespace export assert_false
namespace export assert_pass
namespace export assert_fail
namespace export assert_same_file
namespace export assert_file_exists
namespace export assert_string_in_file
namespace export assert_string_not_in_file

####################################################################################################
# section: generic setters and getters
####################################################################################################
proc set_global_report { file } {
  # Summary:
  # Sets global report file name and can be set to stdout or stderr. If not specified, then each 
  # print_* command requires a file name be provided to the channel argument. If the file name 
  # has the extension 'htm' or 'html', then an HTML report will be generated.
  
  # Argument Usage: 
  #   file : File name or stdout/stderr channel to use for print_* commands.
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  variable global_report $file 
}

proc get_global_report {} {
  # Summary:
  # Gets global report value. The output of this command is what resource will be used to output data
  # if unique resources are not provided to the print_* commands.  Use set_global_report to change.
  
  # Argument Usage: 
   
  # Return Value:
  # Global report value
    
  # Categories: xilinxtclstore, diff

  variable global_report
  return $global_report
}

proc set_verbose { value } {
  # Summary:
  # Sets verbosity mode. True or 1 will print verbose, false or 0 will not.
  
  # Argument Usage: 
  #   value : Value to set verbosity mode to
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  variable verbose $value 
}

proc get_verbose {} {
  # Summary:
  # Gets verbosity mode.
  
  # Argument Usage: 
   
  # Return Value:
  # Verbosity mode value
    
  # Categories: xilinxtclstore, diff

  variable verbose
  return $verbose
}

proc set_compare_objects { new_design1 new_project1 new_design2 new_project2 } {
  # Summary:
  # Sets design and project objects to be used for design comparisons.
  
  # Argument Usage: 
  #   new_design1  : Design to be used when referencing activate_design 1
  #   new_project1 : Project to be used when referencing activate_design 1 (has design 1)
  #   new_design2  : Design to be used when referencing activate_design 2
  #   new_project2 : Project to be used when referencing activate_design 2 (has design 2)
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  variable designs [ list $new_design1 $new_design2 ]
  variable projects [ list $new_project1 $new_project2 ]
}

proc get_compare_objects {} {
  # Summary:
  # Gets design and project objects to be used for design comparisons.
  
  # Argument Usage: 
   
  # Return Value:
  # List with 2 items: [ List of Designs ] [ List of Projects ] to be used for design comparisons
    
  # Categories: xilinxtclstore, diff

  variable designs
  variable projects
  return [ list $designs $projects ]
}

proc set_checkpoints { checkpoint1 checkpoint2 } {
  # Summary:
  # Sets checkpoints to be used for design comparisons.
  
  # Argument Usage: 
  #   checkpoint1 : File name of DCP for checkpoint 1
  #   checkpoint2 : File name of DCP for checkpoint 2
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  variable checkpoints [ list $checkpoint1 $checkpoint2 ]
}

proc get_checkpoints {} {
  # Summary:
  # Gets checkpoints to be used for design comparisons.
  
  # Argument Usage: 
   
  # Return Value:
  # List of checkpoints to be used for design comparisons
    
  # Categories: xilinxtclstore, diff

  variable checkpoints 
  return $checkpoints
}


####################################################################################################
# section: designs
####################################################################################################
proc open_checkpoints { checkpoint1 checkpoint2 } {
  # Summary:
  # Opens checkpoints while capturing the corresponding design and project objects.
  # Channel is not specified here, and cannot be used with the design comparison flow.
  # Use the set_global_report for controlling the outputs channel with design comparisons.
  
  # Argument Usage: 
  #   checkpoint1 : File name of DCP for checkpoint 1
  #   checkpoint2 : File name of DCP for checkpoint 2
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  set_checkpoints $checkpoint1 $checkpoint2
  set design1 [ open_checkpoint $checkpoint1 ]
  set project1 [ current_project ]
  set design2 [ open_checkpoint $checkpoint2 ]
  set project2 [ current_project ]
  set_compare_objects $design1 $project1 $design2 $project2
}

proc activate_design { number } {
  # Summary:
  # Activates (makes active) the project and design of the number specified, 
  # options are 1 or 2.  The project and design are set via set_compare_objects
  # (or open_checkpoints).
  
  # Argument Usage: 
  #   number : Design to make active, choices are 1 or 2.
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  variable designs
  variable projects
  current_project [ lindex $projects [ expr $number - 1 ] ]
  current_design [ lindex $designs [ expr $number - 1 ] ]
}

proc eval_cmd_ { design command } {
  # Summary:
  # (PRIVATE) Make a design/project combination active and then evaluates a command.
  #
  # There is a hidden subtlety to this proc that gives it multiline evaluation capability.
  # When '[eval $cmd]' happens and a 'return' command is encountered it is the same as calling 
  # return in the current scope. Because we are returning at this point, everything works as 
  # expected.  If the $cmd does not have a 'return' then the outer return is used to return the 
  # commands return value.
  #
  # e.g.  return [ expr [ eval return 0 ] + 1 ]; # returns 0, only the inner return is executed
  
  # Argument Usage: 
  #   design : Design number to make active (same as activate_design's number argument)
  #   command : Command to execute after the design is made active
   
  # Return Value:
  # The return value from the command.  If multiline with a 'return' command, then that return 
  # value is returned.
    
  # Categories: xilinxtclstore, diff

  ::tclapp::xilinx::diff::activate_design $design
  return [ eval $command ]
}

proc compare_designs args {
  # Summary:
  # References the design/project combinations set with set_compare_objects. Then a 'design_command'
  # is executed with each design being made active and the outputs of those commands are captured.
  # Those outputs are then compared using the specified 'difference_command'. The design/project 
  # values must have been set with set_compare_objects (or open_checkpoints) before executing this command.
  # 
  # e.g. 
  # open_checkpoints design1.dcp design2.dcp; # calls set_compare_objects for us and opens the DCPs 
  # compare_designs compare_lines { report_timing -return_string -max_paths 1000 }
  
  # Argument Usage: 
  #   difference_command : A compare_* commandfrom the diff package used to compare data
  #   design_command : A Tcl command used to extract some data from both of the designs
   
  # Return Value:
  # The output from the 'difference_command' is returned (see compare_* commands for details)
    
  # Categories: xilinxtclstore, diff

  set difference_command [ compare_designs_difference_command_ [ lindex $args 0 ] ]
  set design_command [ lindex $args 1 ]
  ::tclapp::xilinx::diff::print_header "$design_command"
  set data1 [ compare_designs_data_ [ eval_cmd_ 1 $design_command ] $difference_command ]
  #set data1 [ eval_cmd_ 1 $design_command ] 
  set data2 [ compare_designs_data_ [ eval_cmd_ 2 $design_command ] $difference_command ]
  #set data2 [ eval_cmd_ 2 $design_command ] 
  return [ $difference_command $data1 $data2 ]
}

proc compare_designs_data_ { data difference_command } {
  # Summary:
  # If the user is trying to compare first class objects between the designs, then the objects will
  # go invalid when the design, that the objects belong to, is no longer active (i.e. at comparison).
  # This procedure converts the object into serialized objects to handle this use case.
  
  # Argument Usage: 
  #   difference_command : A compare_* command from the diff package used to compare data
   
  # Return Value:
  # The correct 'difference_command' for compare_designs 
    
  # Categories: xilinxtclstore, diff

  # If any part (of a collection) of the passed in data is not an object, 
  # then we can't work with objects so return the data...
  if { [ catch { get_property CLASS $data } _error ] } {
    return ${data}; # but first convert all objects to a string
  }
  if { $difference_command == "compare_serialized_objects" } {
    return [ serialize_objects $data ]
  } else {
    return [ get_property NAME $data ]
  }
}

proc compare_designs_difference_command_ { difference_command } {
  # Summary:
  # If the user is trying to compare first class objects between the designs, then the objects will
  # go invalid when the design, that the objects belong to, is no longer active (i.e. at comparison).
  # This procedure converts the object comparison algorithms into serialized comparison algorithms
  # to handle this use case.
  
  # Argument Usage: 
  #   difference_command : A compare_* command from the diff package used to compare data
   
  # Return Value:
  # The correct 'difference_command' for compare_designs 
    
  # Categories: xilinxtclstore, diff

  if { $difference_command == "compare_objects" } {
    return "compare_serialized_objects";
  }

  return $difference_command

}

####################################################################################################
# section: data manager
####################################################################################################
proc serialize_object_ { object } {
  # Summary:
  # (PRIVATE) Serializes a single first-class Tcl object.
  
  # Argument Usage: 
  #   object : First-class Tcl object to be serialized
   
  # Return Value:
  # Serialized version of the first-class Tcl object
    
  # Categories: xilinxtclstore, diff

  array set serializer {}
  foreach property [ list_property $object ] {
    set serializer(${property}) [ get_property -quiet $property $object ]
  }
  return [ array get serializer ]
}

proc serialize_objects { objects } {
  # Summary:
  # Serializes all provided first-class Tcl objects.
  
  # Argument Usage: 
  #   objects : First-class Tcl objects to be serialized
   
  # Return Value:
  # Serialized versions (one object per line) of the first-class Tcl objects
    
  # Categories: xilinxtclstore, diff

  set serialized_objects {}
  if { [ llength $objects ] == 1 } {
    lappend serialized_objects [ serialize_object_ $objects ]
  } else {
    foreach object $objects {
      lappend serialized_objects [ serialize_object_ $object ]
    }
  }
  return [ lsort $serialized_objects ]
}

proc serialize_to_file { serialized_data file_name } {
  # Summary:
  # Writes data to file. Can be used as a generic file writer, but this command always appends.
  
  # Argument Usage: 
  #   serialized_data : Data to be stored in file
  #   file_name : File name to store data
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  set file_handle [ open $file_name "a+" ]
  puts $file_handle $serialized_data
  close $file_handle
}

proc serialize_from_file { file_name } {
  # Summary:
  # Read data from file. Can be used as a generic file reader.
  
  # Argument Usage: 
  #   file_name : File name to read data from
   
  # Return Value:
  # Data from file
    
  # Categories: xilinxtclstore, diff

  set file_handle [ open $file_name "r" ]
  set serialized_data [ read $file_handle ]
  close $file_handle
  return $serialized_data
}

####################################################################################################
# section: algorithms
####################################################################################################
proc unique_in_first_set { set1 set2 } {
  # Summary:
  # Find the unique items in set1. Also known as the 'Set Difference' or U\A [ $set1 \ $set2 ].
  
  # Argument Usage: 
  #   set1 : Find the unique items from this set that are not in set2
  #   set2 : Find the unique items from set1 that do not exist in this set
   
  # Return Value:
  # Unique objects that exist in set1 and not in set2
    
  # Categories: xilinxtclstore, diff

  return [ ::struct::set difference $set1 $set2 ]
}

proc unique_in_both_sets { set1 set2 } {
  # Summary:
  # Find the unique items in set1 and in set2. Also known as the 'Symmetric Difference' or 
  # (A\B) U (B\A) [ ( $set1 \ $set2 ) U ( $set2 \ $set1 ) ].
  
  # Argument Usage: 
  #   set1 : Find the unique items from this set that are not in set2
  #   set2 : Find the unique items from this set that are not in set1
   
  # Return Value:
  # Unique objects that exist in set1 and not in set2 and vice versa
  return [ ::struct::set symdiff $set1 $set2 ]
}

proc compare_dirs { dir1 dir2 { channel {} } } {
  # Summary:
  # Compares directory contents.
  
  # Argument Usage: 
  #   dir1 : dir name of dir 1 to compare
  #   dir2 : dir name of dir 2 to compare
  #   [ channel ] : dir name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # The number of differences detected, 0 : no differences, >0 : differences detected
    
  # Categories: xilinxtclstore, diff

  set list1 [ glob -directory [ file normalize $dir1 ] -tails * ]
  set list2 [ glob -directory [ file normalize $dir2 ] -tails * ]
  ::tclapp::xilinx::diff::print_subheader "Comparing Dirs..." $channel
  return [ ::tclapp::xilinx::diff::compare_unordered_ $list1 $list2 $channel ]
}

proc compare_files { file1 file2 { channel {} } } {
  # Summary:
  # Compares file contents. Similar to the linux diff command. This algorithm is designed to be fast and
  # does not find the best matches between files. For best matching use linux diff or the compare_lines_lcs
  # command, but be aware: the compare_lines_lcs has a long runtime.
  
  # Argument Usage: 
  #   file1 : File name of file 1 to compare
  #   file2 : File name of file 2 to compare
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # The number of differences detected, 0 : no differences, >0 : differences detected
    
  # Categories: xilinxtclstore, diff

  set data1 [ ::tclapp::xilinx::diff::serialize_from_file $file1 ]
  set data2 [ ::tclapp::xilinx::diff::serialize_from_file $file2 ]
  ::tclapp::xilinx::diff::print_subheader "Comparing Files..." $channel
  return [ ::tclapp::xilinx::diff::compare_ordered_ $data1 $data2 $file1 $file2 $channel ]
}

proc compare_lines { d1_in_results d2_in_results { d1_name "data_set_1" } { d2_name "data_set_2" } { channel {} } } {
  # Summary:
  # Compares data by lines, and looks for the closest next line match when it encounters a difference.
  
  # Argument Usage: 
  #   d1_in_results : data set 1 to compare, not a list format (expects \n to delimit lines)
  #   d2_in_results : data set 2 to compare, not a list format (expects \n to delimit lines)
  #   d1_name       : name to use when referencing data set 1
  #   d2_name       : name to use when referencing data set 2
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # The number of differences detected, 0 : no differences, >0 : differences detected
    
  # Categories: xilinxtclstore, diff

  ::tclapp::xilinx::diff::print_subheader "Comparing Lines..." $channel
  return [ ::tclapp::xilinx::diff::compare_ordered_ $d1_in_results $d2_in_results $d1_name $d2_name $channel ]
}

# Ordered Lists
proc compare_ordered_ { d1_in_results d2_in_results { d1_name "data_set_1" } { d2_name "data_set_2" } { channel {} } } {
  # Summary:
  # (PRIVATE) Compares data by lines, and looks for the closest next line match when it encounters a difference.
  
  # Argument Usage: 
  #   d1_in_results : data set 1 to compare, not a list format (expects \n to delimit lines)
  #   d2_in_results : data set 2 to compare, not a list format (expects \n to delimit lines)
  #   d1_name       : name to use when referencing data set 1
  #   d2_name       : name to use when referencing data set 2
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # The number of differences detected, 0 : no differences, >0 : differences detected
    
  # Categories: xilinxtclstore, diff

  set d1_results [ split $d1_in_results \n ]
  set d2_results [ split $d2_in_results \n ]
  set d1_length  [ llength $d1_results ]
  set d2_length  [ llength $d2_results ]
  set d1_pointer 0
  set d2_pointer 0
  set diffs 0
  if { $d1_results == $d2_results } {
    ::tclapp::xilinx::diff::print_success "They are equivalent" $channel
  }
  while { ( $d1_pointer <= $d1_length ) && ( $d2_pointer <= $d2_length ) } {
    set d1_string [ lindex $d1_results $d1_pointer ]
    set d2_string [ lindex $d2_results $d2_pointer ]
    if { $d1_string == $d2_string } {
      incr d1_pointer
      incr d2_pointer
    } else {
      if { $diffs == 0 } { ::tclapp::xilinx::diff::print_alert "Differences found:\n<  ${d1_name}\n>  ${d2_name}\n---" $channel }
      incr diffs
      set d1_hit_in_d2 [ lsearch -start $d2_pointer $d2_results $d1_string ]
      set d2_hit_in_d1 [ lsearch -start $d1_pointer $d1_results $d2_string ]
      # set missing search 'hit' to same as current pointer, gives a delta of 0
      if { $d1_hit_in_d2 == -1 } { set d1_hit_in_d2 $d2_pointer }
      if { $d2_hit_in_d1 == -1 } { set d2_hit_in_d1 $d1_pointer }
      set d2_distance_to_hit [ expr $d1_hit_in_d2 - $d2_pointer ]
      set d1_distance_to_hit [ expr $d2_hit_in_d1 - $d1_pointer ]
      set d1_new_pointer $d1_pointer
      set d2_new_pointer $d2_pointer
      if { ( $d2_distance_to_hit > 0 ) || ( $d1_distance_to_hit > 0 ) } {
        if { $d2_distance_to_hit > $d1_distance_to_hit } {
          set d1_new_pointer $d2_hit_in_d1
        } else {
          set d2_new_pointer $d1_hit_in_d2
        }
      }
      set d1_pointer_to_next [ lsort -unique -integer [ list ${d1_pointer} ${d1_new_pointer} ] ]
      set d2_pointer_to_next [ lsort -unique -integer [ list ${d2_pointer} ${d2_new_pointer} ] ]
      set d1_joined_with_add [ join $d1_pointer_to_next { + 1],[expr } ]
      set d2_joined_with_add [ join $d2_pointer_to_next { + 1],[expr } ]
      set d1_lines [ regsub -all {\[|\]} [ eval "\[ expr $d1_joined_with_add + 1\]" ] {} ]
      set d2_lines [ regsub -all {\[|\]} [ eval "\[ expr $d2_joined_with_add + 1\]" ] {} ]
      ::tclapp::xilinx::diff::print_results "\n${d1_lines}c${d2_lines}\n< " $channel
      ::tclapp::xilinx::diff::print_results [ join [ lrange $d1_results $d1_pointer $d1_new_pointer ] "\n< " ] $channel
      ::tclapp::xilinx::diff::print_results "\n---\n> " $channel
      ::tclapp::xilinx::diff::print_results [ join [ lrange $d2_results $d2_pointer $d2_new_pointer ] "\n> " ] $channel
      set d1_pointer $d1_new_pointer
      set d2_pointer $d2_new_pointer
      incr d1_pointer
      incr d2_pointer
    }
  }
  ::tclapp::xilinx::diff::print_results "\n" $channel; # STDOUT seperator for return value
  return $diffs
}

proc compare_lines_lcs { d1_in_results d2_in_results { d1_name "data_set_1" } { d2_name "data_set_2" } { channel {} } } {
  # Summary:
  # Compares data using the Longest Common Subsequence (LCS) algorithm.  This provides the best matching of data.
  # However, there can a significant time hit when using this algorithm.
  
  # Argument Usage: 
  #   d1_in_results : data set 1 to compare, not a list format (expects \n to delimit lines)
  #   d2_in_results : data set 2 to compare, not a list format (expects \n to delimit lines)
  #   d1_name       : name to use when referencing data set 1
  #   d2_name       : name to use when referencing data set 2
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # The number of differences detected, 0 : no differences, >0 : differences detected
    
  # Categories: xilinxtclstore, diff

  set d1_results [ split $d1_in_results \n ]
  set d2_results [ split $d2_in_results \n ]
  ::tclapp::xilinx::diff::print_subheader "Comparing Lines using Longest Common Subsequence (LCS)..." $channel
  ::tclapp::xilinx::diff::print_info "Analyzing Longest Common Subsequence...\n" $channel
  set lcs [::struct::list longestCommonSubsequence $d1_results $d2_results]
  ::tclapp::xilinx::diff::print_info "Inverting Longest Common Subsequence...\n" $channel
  set ilcs [::struct::list lcsInvert $lcs [llength $d1_results] [llength $d2_results]]
  if { [llength $ilcs] != 0 } { 
    ::tclapp::xilinx::diff::print_alert "Differences were found in the reports:\n<  ${d1_name}\n>  ${d2_name}\n---\n" $channel
  }
  foreach sequence $ilcs {
    set d1_lines [regsub -all {\[|\]} [eval "\[expr [join [lsort -unique -integer [lindex $sequence 1]] { + 1],[expr }] + 1\]"] {}]
    set d2_lines [regsub -all {\[|\]} [eval "\[expr [join [lsort -unique -integer [lindex $sequence 2]] { + 1],[expr }] + 1\]"] {}]
    ::tclapp::xilinx::diff::print_results "${d1_lines}[string index [lindex $sequence 0] 0]${d2_lines}\n> " $channel
    ::tclapp::xilinx::diff::print_results [join [eval "lrange \$d1_results [join [lindex $sequence 1] { }]"] "\n> "] $channel
    ::tclapp::xilinx::diff::print_results "\n---\n< " $channel
    ::tclapp::xilinx::diff::print_results [join [eval "lrange \$d2_results [join [lindex $sequence 2] { }]"] "\n< "] $channel
  }
  ::tclapp::xilinx::diff::print_results "\n" $channel; # STDOUT seperator for return value
  return [llength $ilcs]
}

proc compare_ordered_lists { list1 list2 { channel {} } } {
  # Summary:
  # Compare ordered lists and finds in-order differences.  Uniqueness is not considered in this algorithm.
  
  # Argument Usage: 
  #   list1 : data set 1 to compare, a list format
  #   list2 : data set 2 to compare, a list format
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # The number of differences detected, 0 : no differences, >0 : differences detected
    
  # Categories: xilinxtclstore, diff

  set list1_lines [ join $list1 \n ]
  set list2_lines [ join $list2 \n ]
  ::tclapp::xilinx::diff::print_subheader "Comparing Ordered Lists..." $channel
  return [ ::tclapp::xilinx::diff::compare_ordered_ $list1_lines $list2_lines "list_1" "list_2" $channel ]
}

proc compare_unordered_lists { list1 list2 { channel {} } } {
  # Summary:
  # Compare unordered lists and finds unique objects that exist in each list/set.
  
  # Argument Usage: 
  #   list1 : data set 1 to compare, a list format
  #   list2 : data set 2 to compare, a list format
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # A list of all of the unique values
    
  # Categories: xilinxtclstore, diff

  ::tclapp::xilinx::diff::print_subheader "Comparing Unordered Lists..." $channel
  return [ compare_unordered_ $list1 $list2 $channel ]
}

proc compare_unordered_ { list1 list2 { channel {} } } {
  # Summary:
  # (PRIVATE) Compare unordered lists and finds unique objects that exist in each list/set.
  
  # Argument Usage: 
  #   list1 : data set 1 to compare, a list format
  #   list2 : data set 2 to compare, a list format
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # A list of all of the unique values
    
  # Categories: xilinxtclstore, diff

  set list1_only [ unique_in_first_set $list1 $list2 ]
  set list2_only [ unique_in_first_set $list2 $list1 ]
  if { ( [ llength $list1_only ] == 0 ) && ( [ llength $list2_only ] == 0 ) } {
    ::tclapp::xilinx::diff::print_success "They are equivalent" $channel
  } else {
    ::tclapp::xilinx::diff::print_alert "Differences found:\n List 1 has [ llength $list1_only ] unique:\n  [ join $list1_only \n\ \  ]\n List 2 has [ llength $list2_only ] unique:\n  [ join $list2_only \n\ \  ]" $channel
  }
  ::tclapp::xilinx::diff::print_results "\n" $channel; # STDOUT seperator for return value
  return [ concat $list1_only $list2_only ]
}

proc compare_objects { objects1 objects2 { channel {} } } {
  # Summary:
  # Compare first-class Tcl object properties.
  
  # Argument Usage: 
  #   objects1 : object group 1 to compare, must be first-class Tcl objects
  #   objects2 : object group 2 to compare, must be first-class Tcl objects
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # A list of all properties that differ between the two objects
    
  # Categories: xilinxtclstore, diff

  set objects1_serialized [ ::tclapp::xilinx::diff::serialize_objects $objects1 ]
  set objects2_serialized [ ::tclapp::xilinx::diff::serialize_objects $objects2 ]
  return [ compare_serialized_objects $objects1_serialized $objects2_serialized $channel ]
}

proc compare_serialized_objects { serialized_objects1 serialized_objects2 { channel {} } } {
  # Summary:
  # Compare serialized object properties. To serialize objects use the command serialize_objects. 
  # To read in objects that have been serialized to disk use serialize_from_file.
  
  # Argument Usage: 
  #   serialized_objects1 : object group 1 to compare, must be serialized objects
  #   serialized_objects2 : object group 2 to compare, must be serialized objects
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # A list of all properties that differ between the two objects
    
  # Categories: xilinxtclstore, diff

  ::tclapp::xilinx::diff::print_subheader "Comparing Objects..." $channel
  set differing_properties {}
  foreach serialized_object1 $serialized_objects1 serialized_object2 $serialized_objects2 {
    set differing_properties [ concat $differing_properties [ ::tclapp::xilinx::diff::compare_object_props_ $serialized_object1 $serialized_object2 $channel ] ]
  }
  set differing_properties [ lsort -unique $differing_properties ]
  if { [ llength $differing_properties ] > 0 } {
    ::tclapp::xilinx::diff::print_alert "Differing properties exist, differing properties are:\n  [ join $differing_properties \  ]" $channel
  } else {
    ::tclapp::xilinx::diff::print_success "All properties for all objects are equivalent" $channel
  }
  ::tclapp::xilinx::diff::print_results "\n" $channel; # STDOUT seperator for return value
  return $differing_properties
}

proc compare_object_props_ { serialized_object1 serialized_object2 { channel {} } } {
  # Summary:
  # (PRIVATE) Compares a single object's properties.
  
  # Argument Usage: 
  #   serialized_object1 : object 1 to compare, must be a serialized object
  #   serialized_object2 : object 2 to compare, must be a serialized object
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # A list of all properties that differ between the two objects
    
  # Categories: xilinxtclstore, diff

  variable verbose 
  array set object1_properties $serialized_object1 
  set object1_property_keys [ array names object1_properties ]
  array set object2_properties $serialized_object2 
  set object2_property_keys [ array names object2_properties ]
  set combined_property_keys [ lsort -unique [ concat $object1_property_keys $object2_property_keys ] ]

  # object type
  set missing_class "&lt;CLASS_MISSING&gt;"
  set object1_class [ expr { [ info exists object1_properties(CLASS) ] ? "$object1_properties(CLASS)" : "$missing_class" } ]
  set object2_class [ expr { [ info exists object2_properties(CLASS) ] ? "$object2_properties(CLASS)" : "$missing_class" } ]
  set object_class [ expr { ( "${object1_class}" == "${object2_class}" ) ? "${object1_class}" : "${object1_class} <-> ${object2_class}" } ]

  # object name
  set missing_name "&lt;NAME_MISSING&gt;"
  set object1_name [ expr { [ info exists object1_properties(NAME) ] ? "$object1_properties(NAME)" : "$missing_name" } ]
  set object2_name [ expr { [ info exists object2_properties(NAME) ] ? "$object2_properties(NAME)" : "$missing_name" } ]
  set object_name [ expr { ( "${object1_name}" == "${object2_name}" ) ? "$object1_name" : "${object1_name} <-> ${object2_name}" } ]
  
  # object property count
  set object1_count [ llength $serialized_object1 ]
  set object2_count [ llength $serialized_object2 ]
  set object_count [ expr { ( $object1_count == $object2_count ) ? "$object1_count" : "${object1_count} <-> ${object2_count}" } ]

  set comparing_info "Comparing ${object_count} properties on '${object_class}' '${object_name}'...\n"

  if { $serialized_object1 == $serialized_object2 } {
    if { $verbose } {
      ::tclapp::xilinx::diff::print_info $comparing_info $channel
      #::tclapp::xilinx::diff::print_success "All properties are equivalent\n" $channel
    }
    ::tclapp::xilinx::diff::print_results "\n" $channel; # STDOUT seperator for return value
    return {}
  }; # else difference detected

  set differing_properties {}
  foreach property $combined_property_keys {
    if { ! [ info exists object1_properties($property) ] } {
      set object1_properties($property) "<Property does not exist for Object 1>"
    }
    if { ! [ info exists object2_properties($property) ] } {
      set object2_properties($property) "<Property does not exist for Object 2>"
    }
    if { "$object1_properties($property)" != "$object2_properties($property)" } {
      if { "${differing_properties}" == "" } {
        ::tclapp::xilinx::diff::print_info $comparing_info $channel
      }
      ::tclapp::xilinx::diff::print_results "  Property '${property}' differs : '$object1_properties($property)' <=> '$object2_properties($property)'\n" $channel
      lappend differing_properties $property
    }
  }
  ::tclapp::xilinx::diff::print_results "\n" $channel; # STDOUT seperator for return value
  return $differing_properties
}

####################################################################################################
# section: reporting 
####################################################################################################
proc print_stamp { { channel {} } } {
  # Summary:
  # Print current time stamp, current build, current changelist, and process ID.
  
  # Argument Usage: 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  catch { version } _version
  set _build  [lindex [lindex [split $_version \n] 0] 1]
  set _cl     [lindex [lindex [split $_version \n] 1] 1]
  lappend html "Created at [clock format [clock seconds]]"
  lappend html "Current Build: $_build    Changelist: $_cl    Process ID: [pid]"
  set msg(HTML) [ join $html "<br/>\n" ]
  set msg(STD)  [ join $html \n ]
  print_msg [ array get msg ] $channel
}

proc print_css {} {
  # Summary:
  # Return Cascaded Stylesheet (CSS) information for HTML report
  
  # Argument Usage: 
   
  # Return Value:
  # CSS information for HTML report
    
  # Categories: xilinxtclstore, diff

  lappend html "<link href='http://maxcdn.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css' rel='stylesheet' />"
  lappend html "<style type='text/css'>"
  lappend html "  .panel-heading {cursor: pointer;}"
  lappend html "</style>"
  return [ join $html \n ]
}


proc print_js {} {
  # Summary:
  # Return JavaScript (JS) information for HTML report
  
  # Argument Usage: 
   
  # Return Value:
  # JS information for HTML report
    
  # Categories: xilinxtclstore, diff

  lappend html "<script type='text/javascript' src='https://ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js'></script>"
  lappend html "<script type='text/javascript' src='http://maxcdn.bootstrapcdn.com/bootstrap/3.1.1/js/bootstrap.min.js'></script>"
  lappend html "<script type='text/javascript'>"
  lappend html "  \$(document).ready(function(){"
  lappend html "    \$('.panel-heading').click(function() {"
  lappend html "      \$(this).next().toggle();"
  lappend html "      return false;"
  lappend html "    }).next().show();"
  lappend html "    \$('.toc').each(function(i) {"
  lappend html "      var current = \$(this);"
  lappend html "      current.attr('id', 'title' + i);"
  lappend html "      \$('#toc').first().append(\"<li><a id='link\" + i + \"' href='#title\" +"
  lappend html "      i + \"' title='\" + current.text() + \"'>\" + "
  lappend html "      current.html() + \"</a></li>\");"
  lappend html "    });"
  lappend html "  });"
  lappend html "</script>"
  return [ join $html \n ]
}

proc print_msg { output { channel {} } { newline 1 } } {
  # Summary:
  # Print generic message. Most print_* commands use this as the base proc for reporting.
  
  # Argument Usage: 
  #   output : The message to be printed
  #   [ channel ] : The channel can be a file name, stdout, or stderr. If this ends with '.htm' 
  #                 or '.html', then an HTML report will be generated.
  #   [ newline ] : Determines if a new line character is inserted at the end of the 'output'
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  variable global_report
  if { "$channel" == "" } {
    set channel $global_report
  }
  if { "$channel" == "" } {
    set channel stdout
  }
  #array set msg [ array get $output ]
  array set msg $output 
  if { [ regexp -- {.*\.(htm|html)$} $channel ] } {
    set content "$msg(HTML)"
  } else { 
    set content "$msg(STD)"
  }
  if { ( "${channel}" != "stdout" ) && ( "${channel}" != "stderr" ) } {
    set handle [ open $channel "a+" ]
  } else {
    set handle $channel
  }
  if { $newline } {
    puts $handle $content 
  } else {
    puts -nonewline $handle $content 
  }
  if { ( "${channel}" != "stdout" ) && ( "${channel}" != "stderr" ) } {
    close $handle
  }
}

proc print_start { { title "Difference Report" } { channel {} } } {
  # Summary:
  # Print report title, if using HTML, then this generates the head content of the HTML report.
  
  # Argument Usage: 
  #   title : Reports title 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  lappend html "<html lang='en'>"
  lappend html "<head>"
  lappend html "<title>[ html_escape ${title} ]</title>"
  lappend html "<link rel='shortcut icon' href='http://www.xilinx.com/favicon.ico'/>"
  lappend html [ ::tclapp::xilinx::diff::print_css ] 
  lappend html [ ::tclapp::xilinx::diff::print_js ]
  lappend html "</head>"
  lappend html "<body>"
  lappend html "<div id='container' class='container bs-docs-container'>"
  lappend html "<div class='row'>"
  lappend html "<div id='content' role='main' class='col-md-9'>"
  lappend html "<h1>[ html_escape ${title} ]</h1>"
  lappend html "<div class='hide'>"; # print_header starts and ends panel
  lappend html "<div>"; # print_subheader starts and ends panel-body
  lappend html "<pre>"; # print_subheader starts and ends well
  set msg(HTML) [ join $html \n ]
  set msg(STD)  "${title}"
  print_msg [ array get msg ] $channel
}

proc print_end { { channel {} } } {
  # Summary:
  # Print end of the report. If using an HTML report, then this prints the ending HTML tags.
  
  # Argument Usage: 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  lappend html "</pre>"; #well
  lappend html "</div>"; #panel-body
  lappend html "</div>"; #panel
  lappend html "</div>"; #col-md-9
  lappend html "<div class='col-md-3'>"; #col-md-3
  lappend html "<div id='toc' class='bs-docs-sidebar hidden-print affix' role='complementary'>"; #toc
  lappend html "<ul class='nav bs-docs-sidenav'></ul>"
  lappend html "</div>"; #toc
  lappend html "</div>"; #col-md-3
  lappend html "</div>"; #row
  lappend html "</div>"; #container
  lappend html "</body>"
  lappend html "</html>"
  set msg(HTML) [ join $html \n ]
  set msg(STD)  ""
  print_msg [ array get msg ] $channel
}

proc print_subheader { subheader { channel {} } } {
  # Summary:
  # Print a sub-heading. For HTML reports this begins the pre-formatted area under each heading.
  
  # Argument Usage: 
  #   subheader : A sub-heading for the report
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  set new_msg {}
  foreach line [ split $subheader \n ] { if { $line != {} } { lappend new_msg [ string trim [ html_escape $line ] ] } }
  lappend html [ join $new_msg "<br/>\n" ]
  lappend html "<pre>"; #well
  set msg(HTML) [ join $html \n ]
  set msg(STD)  "\$\$ ${subheader}"
  print_msg [ array get msg ] $channel
}

proc print_header { header { channel {} } } {
  # Summary:
  # Print a heading. For HTML reports this begins the different sections of the report.
  
  # Argument Usage: 
  #   header : A heading for the report
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  set new_msg {}
  foreach line [ split $header \n ] { if { $line != {} } { lappend new_msg [ string trim [ html_escape $line ] ] } }
  lappend html "</pre>"; #well
  lappend html "</div>"; #panel-body
  lappend html "</div>"; #panel
  lappend html "<div class='panel panel-primary'>"; #panel
  lappend html "<div class='panel-heading'>"; #panel-heading
  lappend html "<span class='toc'>"
  lappend html [ join $new_msg "<br/>\n" ]
  lappend html "</h2>"
  lappend html "</div>"; #panel-heading
  lappend html "<div class='panel-body'>"; #panel-body
  set msg(HTML) [ join $html \n ]
  set msg(STD)  "\n\n@@ ${header}"
  print_msg [ array get msg ] $channel
}

proc print_info { info { channel {} } } {
  # Summary:
  # Print a info message. For HTML reports this shows in dark blue.
  
  # Argument Usage: 
  #   info : An info for the report
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  lappend html "<span title='[ html_escape ${info} ]' class='text-info'>"
  lappend html [ html_escape $info ]
  lappend html "</span>"
  set msg(HTML) [ join $html {} ]
  set msg(STD)  "** ${info}"
  print_msg [ array get msg ] $channel 0
}

proc print_alert { alert { channel {} } } {
  # Summary:
  # Print an alert message. For HTML reports this shows in dark red.
  
  # Argument Usage: 
  #   alert : An alert for the report
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  lappend html "<span class='text-danger'>"
  lappend html [ html_escape $alert ]
  lappend html "</span>"
  set msg(HTML) [ join $html {} ]
  set msg(STD)  "!! ${alert}"
  print_msg [ array get msg ] $channel 0
}

proc print_success { success { channel {} } } {
  # Summary:
  # Print a success message. For HTML reports this shows in dark green.
  
  # Argument Usage: 
  #   success : A success for the report
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  lappend html "<span class='text-success'>"
  lappend html [ html_escape $success ]
  lappend html "</span>"
  set msg(HTML) [ join $html {} ]
  set msg(STD)  "== ${success}"
  print_msg [ array get msg ] $channel 0
}

proc print_results { results { channel {} } } {
  # Summary:
  # Print a result message. For HTML reports this shows in dark gray.
  
  # Argument Usage: 
  #   result : A result for the report
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  lappend html "<span class='text-muted'>"
  lappend html [ html_escape $results ]
  lappend html "</span>"
  set msg(HTML) [ join $html {} ]
  set msg(STD)  "${results}"
  print_msg [ array get msg ] $channel 0 ; # don't print a new line
}

proc throw_error { error { channel {} } } {
  # Summary:
  # Print error (using print_alert), print report end, and then throw the same error.
  
  # Argument Usage: 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
    
  # Categories: xilinxtclstore, diff

  ::tclapp::xilinx::diff::print_alert $error $channel
  ::tclapp::xilinx::diff::print_end $channel
  error $error
}

####################################################################################################
# section: filters
####################################################################################################
proc html_escape { input } {
  # Summary:
  # Escapes all XML characters.
  #   & = &amp;
  #   " = &quot;
  #   ' = &apos;
  #   < = &lt;
  #   > = &gt;
  
  # Argument Usage: 
  #   string : String to escape
   
  # Return Value:
  # The escaped version of the input string.
    
  # Categories: xilinxtclstore, diff
 
  set output $input
  set output [ string map {& &amp;} $output ]
  set output [ string map {\" &quot;} $output ]
  set output [ string map {' &apos;} $output ]
  set output [ string map {< &lt;} $output ]
  set output [ string map {> &gt;} $output ]
  return $output
}

proc remove_comments { input } {
  # Summary:
  # Removes all comments
  
  # Argument Usage: 
  #   string : String to clean
   
  # Return Value:
  # The non-comment version of the input string.
    
  # Categories: xilinxtclstore, diff
 
  set output $input
  set output [ regsub -all -line {;\s*#.*} $output {;} ]
  set output [ regsub -all -line {^\s*#.*} $output {} ]
  return $output
}

proc remove_whitespace { input } {
  # Summary:
  # Removes all whitespace
  
  # Argument Usage: 
  #   string : String to clean
   
  # Return Value:
  # The non-whitespace version of the input string.
    
  # Categories: xilinxtclstore, diff
 
  set output $input
  set output [ regsub -all {\s+} $output {} ]
  return $output
}

proc remove_special { input } {
  # Summary:
  # Removes all special characters, except '-', '_', and whitespace
  
  # Argument Usage: 
  #   string : String to clean
   
  # Return Value:
  # The non-special character version of the input string.
    
  # Categories: xilinxtclstore, diff
 
  set output $input
  set output [ regsub -all {[^\sa-zA-Z0-9_-]+} $output {} ]
  return $output
}

proc remove_datestamps { input { replace_with {<removed_timestamp>} } } {
  # Summary:
  # Removes all date stamps
  
  # Argument Usage: 
  #   string : String to clean
   
  # Return Value:
  # The string with date stamps removed.
    
  # Categories: xilinxtclstore, diff
 
  set output $input
  # Matches:  Mon Jun 16 10:02:33 MDT 2014 or Mon Jun 1 1:02:33 2014
  set output [ regsub -all {[a-zA-Z]{3}\s+[a-zA-Z]{3}\s+[0-9]{1,2}\s+[0-9]{1,2}:[0-9]{2}:[0-9]{2}\s+([A-Z]{3}\s+){0,1}[0-9]{4}} $output $replace_with ]
  # Matches:  Mon Jun 1 1:02:33 2014
  #set output [ regsub -all {[a-zA-Z]{3} [a-zA-Z]{3} [0-9]{1,2} [0-9]{1,2}:[0-9]{2}:[0-9]{2} [0-9]{4}} $output $replace_with ]
  # Matches ISO 8601:  2014-01-04T07:00:23+0400
  set output [ regsub -all {([0-9]{4}\-[0-9]{2}-[0-9]{2}([tT][0-9:\.]*)?)([zZ]|([+\-])([0-9]{2}):?([0-9]{2}))} $output $replace_with ]
  return $output
}

####################################################################################################
# section: assertions
####################################################################################################

proc assert_same { expected received { msg "Same As Assertion" } { channel {} } } {
  # Summary:
  # Compares two values to ensure that they are the same.
  
  # Argument Usage: 
  #   expected : The expected value
  #   received : The value received
  #   [ msg ] : Message printed 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # True or throws error
    
  # Categories: xilinxtclstore, diff

  if { "${expected}" == "" } { set expected {} }
  if { "${received}" == "" } { set received {} }
  if { ${expected} == ${received} } {
    ::tclapp::xilinx::diff::print_success "OK: ${msg}\n" $channel
    return 1
  }
  ::tclapp::xilinx::diff::throw_error "FAIL: ${msg}:\n  Expected: '${expected}'\n  Received: '${received}'\n" $channel
}

proc assert_true { boolean { msg "True Assertion" } { channel {} } } {
  # Summary:
  # Compares boolean to true.
  
  # Argument Usage: 
  #   boolean : The value received
  #   [ msg ] : Message printed 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # True or throws error
    
  # Categories: xilinxtclstore, diff

  if { [ catch { set safe_boolean [ expr 1 && $boolean ] } _error ] } {
    ::tclapp::xilinx::diff::throw_error "FAIL: ${msg}: Unable to resolve '${boolean}' to 'true' or 'false':\n  ${_error}\n" $channel
  }
  assert_same 1 $safe_boolean $msg $channel
}

proc assert_false { boolean { msg "False Assertion" } { channel {} } } {
  # Summary:
  # Compares boolean to false.
  
  # Argument Usage: 
  #   boolean : The value received
  #   [ msg ] : Message printed 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # True or throws error
    
  # Categories: xilinxtclstore, diff

  if { [ catch { set safe_boolean [ expr 1 && ! ( $boolean ) ] } _error ] } {
    ::tclapp::xilinx::diff::throw_error "FAIL: ${msg}: Unable to resolve '${boolean}' to 'true' or 'false':\n  ${_error}\n" $channel
  }
  assert_same 1 $safe_boolean $msg $channel
}

proc assert_pass { cmd { msg "Pass Assertion" } { channel {} } } {
  # Summary:
  # Ensures that the command passes. This is normally not needed as a failing command will throw on it's own.
  
  # Argument Usage: 
  #   cmd : The command to execute
  #   [ msg ] : Message printed 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # True or throws error
    
  # Categories: xilinxtclstore, diff

  if { [ catch { eval $cmd } _error ] } {
    ::tclapp::xilinx::diff::throw_error "FAIL: ${msg}: Command Failed: {${cmd}}\n  Returned Error: '${_error}'\n" $channel
  }
  ::tclapp::xilinx::diff::print_success "OK: ${msg}: Command Passed: {${cmd}}\n" $channel
  return 1
}

proc assert_fail { cmd { msg "Fail Assertion" } { channel {} } } {
  # Summary:
  # Ensures that the command fails.
  
  # Argument Usage: 
  #   cmd : The command to execute
  #   [ msg ] : Message printed 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # True or throws error
    
  # Categories: xilinxtclstore, diff

  if { ! [ catch { eval $cmd } _error ] } {
    ::tclapp::xilinx::diff::throw_error "FAIL: ${msg}: Command Passed: {${cmd}}\n" $channel
  }
  ::tclapp::xilinx::diff::print_success "OK: ${msg}: Command Failed: {${cmd}}\n  Returned Error: '${_error}'\n" $channel
  return 1
}

proc assert_same_file { file1 file2 { msg "Same File Assertion" } { channel {} } } {
  # Summary:
  # Compares files to ensure that they are the same.
  
  # Argument Usage: 
  #   file1 : File name of file 1 to compare
  #   file2 : File name of file 2 to compare
  #   [ msg ] : Message printed 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # True or throws error
    
  # Categories: xilinxtclstore, diff

  set data1 [ ::tclapp::xilinx::diff::serialize_from_file $file1 ]
  set data2 [ ::tclapp::xilinx::diff::serialize_from_file $file2 ]
  if { $data1 != $data2 } {
    ::tclapp::xilinx::diff::throw_error "FAIL: ${msg}: Files Differ:\n  ${file1}\n  ${file2}\n" $channel
  }
  ::tclapp::xilinx::diff::print_success "OK: ${msg}: Files are the same\n" $channel
  return 1
}

proc assert_file_exists { file { msg "File Exists Assertion" } { channel {} } } {
  # Summary:
  # Ensures file exists. 
  
  # Argument Usage: 
  #   file : File name to check for existence
  #   [ msg ] : Message printed 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # True or throws error
    
  # Categories: xilinxtclstore, diff

  if { ! [ file exists $file ] } {
    ::tclapp::xilinx::diff::throw_error "FAIL: ${msg}: File Does Not Exist: ${file}\n" $channel
  }
  ::tclapp::xilinx::diff::print_success "OK: ${msg}: File Exists: ${file}\n" $channel
  return 1

}

proc assert_string_in_file { find_string file { msg "String In File Assertion" } { channel {} } } {
  # Summary:
  # Ensures string is in file.
  
  # Argument Usage: 
  #   find_string : String to find in file
  #   file : File name to search for string in
  #   [ msg ] : Message printed 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # True or throws error
    
  # Categories: xilinxtclstore, diff

  set data [ ::tclapp::xilinx::diff::serialize_from_file $file ]
  if { ! [ regexp -- $find_string $data ] } {
    ::tclapp::xilinx::diff::throw_error "FAIL: ${msg}: String Not Found\n  String: '${find_string}'\n  File: '${file}'\n" $channel
  }
  ::tclapp::xilinx::diff::print_success "OK: ${msg}: String Found: '${find_string}'\n" $channel
  return 1
foreach property [ list_property $part1 ] {
  if { ! [ regexp -- $property $serialized_part1 ] } { error "Serialized object property key missing: '${property}' " }
  set prop_val = [ get_property -quiet $property $part1 ]
  if { ! [ regexp -- $prop_val $serialized_part1 ] } { error "Serialized object property value missing: '${prop_val}' " }
}
}

proc assert_string_not_in_file { find_string file { msg "String Not In File Assertion" } { channel {} } } {
  # Summary:
  # Ensures string is not in file.
  
  # Argument Usage: 
  #   find_string : String to find in file
  #   file : File name to search for string in
  #   [ msg ] : Message printed 
  #   [ channel ] : File name, stdout, or stderr for reporting (Default: see get_global_report usage)
   
  # Return Value:
  # True or throws error
    
  # Categories: xilinxtclstore, diff

  set data [ ::tclapp::xilinx::diff::serialize_from_file $file ]
  if { [ regexp -- $find_string $data ] } {
    ::tclapp::xilinx::diff::throw_error "FAIL: ${msg}: String Found\n  String: '${find_string}'\n  File: '${file}'\n" $channel
  }
  ::tclapp::xilinx::diff::print_success "OK: ${msg}: String Not Found: '${find_string}'\n" $channel
  return 1
}

}; # end ::tclapp::xilinx::diff

