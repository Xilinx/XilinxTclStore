####################################################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2014 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
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
namespace export set_verbose
namespace export set_designs 

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

####################################################################################################
# section: public definitions
####################################################################################################
proc open_checkpoints { checkpoint1 checkpoint2 } {
  variable checkpoints [ list $checkpoint1 $checkpoint2 ]
  set design1 [ open_checkpoint $checkpoint1 ]
  set project1 [ current_project ]
  set design2 [ open_checkpoint $checkpoint2 ]
  set project2 [ current_project ]
  set_designs $design1 $project1 $design2 $project2
}

proc set_designs { new_design1 new_project1 new_design2 new_project2 } {
  variable designs [ list $new_design1 $new_design2 ]
  variable projects [ list $new_project1 $new_project2 ]
}

proc activate_design { number } {
  variable designs
  variable projects
  current_project [ lindex $projects [ expr $number - 1 ] ]
  current_design [ lindex $designs [ expr $number - 1 ] ]
}

proc eval_cmd_ { design command } {
  # to support eval of return
  ::tclapp::xilinx::diff::activate_design $design
  return [ eval $command ]
}

proc compare_designs args {
  set difference_command [ lindex $args 0 ] 
  set design_command [ lindex $args 1 ]
  puts "cmd: $design_command"
  ::tclapp::xilinx::diff::print_header "$design_command"
  set data1 [ eval_cmd_ 1 $design_command ]
  set data2 [ eval_cmd_ 2 $design_command ]
  return [ $difference_command $data1 $data2 ]
}

# Sets are unordered
proc unique_in_first_set { set1 set2 } {
  return [ ::struct::set difference $set1 $set2 ]
}

proc unique_in_both_sets { set1 set2 } {
  return [ ::strung::set symdiff $set1 $set2 ]
}

proc serialize_object_ { object } {
  array set serializer {}
  foreach property [ list_property $object ] {
    set serializer(${property}) [ get_property -quiet $property $object ]
  }
  return [ array get serializer ]
}

proc serialize_objects { objects } {
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
  set file_handle [ open $file_name "a+" ]
  puts $file_handle $serialized_data
  close $file_handle
}

proc serialize_from_file { file_name } {
  set file_handle [ open $file_name "r" ]
  set serialized_data [ read $file_handle ]
  close $file_handle
  return $serialized_data
}

####################################################################################################
# section: helper definitions
####################################################################################################

# Files
proc compare_files { file1 file2 { channel {} } } {
  set handle1 [ open $file1 "r" ]
  set data1 [ read $handle1 ]
  close $handle1
  set handle2 [ open $file2 "r" ]
  set data2 [ read $handle2 ]
  close $handle2
  return [ ::tclapp::xilinx::diff::compare_lines $data1 $data2 $file1 $file2 $channel ]
}

# Data
proc compare_lines { d1_in_results d2_in_results { d1_name "data_set_1" } { d2_name "data_set_2" } { channel {} } } {
  set d1_results [ split $d1_in_results \n ]
  set d2_results [ split $d2_in_results \n ]
  set d1_length  [ llength $d1_results ]
  set d2_length  [ llength $d2_results ]
  set d1_pointer 0
  set d2_pointer 0
  set diffs 0
  ::tclapp::xilinx::diff::print_subheader "Comparing Ordered Data..." $channel
  if { $d1_results == $d2_results } {
    ::tclapp::xilinx::diff::print_success "The Ordered Lines are Equivalent" $channel
  }
  while { ( $d1_pointer < $d1_length ) && ( $d2_pointer < $d2_length ) } {
    set d1_string [ lindex $d1_results $d1_pointer ]
    set d2_string [ lindex $d2_results $d2_pointer ]
    if { $d1_string == $d2_string } {
      incr d1_pointer
      incr d2_pointer
    } else {
      if { $diffs == 0 } { ::tclapp::xilinx::diff::print_alert "Differenes found:\n<  ${d1_name}\n>  ${d2_name}\n---" $channel }
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
  return $diffs
}

# SLOW!!, but provides the best difference results
proc compare_lines_lcs { d1_results d2_results { channel {} } } {
  ::tclapp::xilinx::diff::print_subheader "Comparing Ordered Data..." $channel
  ::tclapp::xilinx::diff::print_info "Analyzing Longest Common Subsequence..." $channel
  set lcs [::struct::list longestCommonSubsequence $d1_results $d2_results]
  ::tclapp::xilinx::diff::print_info "Inverting Longest Common Subsequence..." $channel
  set ilcs [::struct::list lcsInvert $lcs [llength $d1_results] [llength $d2_results]]
  if { [llength $ilcs] != 0 } { 
    ::tclapp::xilinx::diff::print_alert "Differenes were found in the reports:\n<\t$::tclapp::xilinx::diff::design::($($this,d1),name)\n>\t$::tclapp::xilinx::diff::design::($($this,d2),name)\n---" $channel
  }
  foreach sequence $ilcs {
    set d1_lines [regsub -all {\[|\]} [eval "\[expr [join [lsort -unique -integer [lindex $sequence 1]] { + 1],[expr }] + 1\]"] {}]
    set d2_lines [regsub -all {\[|\]} [eval "\[expr [join [lsort -unique -integer [lindex $sequence 2]] { + 1],[expr }] + 1\]"] {}]
    ::tclapp::xilinx::diff::print_results "${d1_lines}[string index [lindex $sequence 0] 0]${d2_lines}\n> " $channel
    ::tclapp::xilinx::diff::print_results [join [eval "lrange \$d1_results [join [lindex $sequence 1] { }]"] "\n> "] $channel
    ::tclapp::xilinx::diff::print_results "---\n< " $channel
    ::tclapp::xilinx::diff::print_results [join [eval "lrange \$d2_results [join [lindex $sequence 2] { }]"] "\n< "] $channel
  }
  return [llength $ilcs]
}

# Lists - ordered
proc compare_ordered_lists { list1 list2 { channel {} } } {
  set list1_lines [ join $list1 \n ]
  set list2_lines [ join $list2 \n ]
  return [ ::tclapp::xilinx::diff::compare_lines $list1_lines $list2_lines "list_1" "list_2" $channel ]
}

# Lists - unordered
proc compare_unordered_lists { list1 list2 { channel {} } } {
  ::tclapp::xilinx::diff::print_subheader "Comparing Unordered Data..."
  set list1_only [ unique_in_first_set $list1 $list2 ]
  set list2_only [ unique_in_first_set $list2 $list1 ]
  if { ( [ llength $list1_only ] == 0 ) && ( [ llength $list2_only ] == 0 ) } {
    ::tclapp::xilinx::diff::print_success "The lists are equivalent" $channel
  } else {
    ::tclapp::xilinx::diff::print_alert "Differences found:\n List 1 has [ llength $list1_only ] unique:\n  [ join $list1_only \n\ \  ]\n List 2 has [ llength $list2_only ] unique:\n  [ join $list2_only \n\ \  ]"
  }
  return [ concat $list1_only $list2_only ]
}

# Objects
proc compare_objects { objects1 objects2 { channel {} } } {
  set objects1_serialized [ ::tclapp::xilinx::diff::serialize_objects $objects1 ]
  set objects2_serialized [ ::tclapp::xilinx::diff::serialize_objects $objects2 ]
  compare_serialized_objects $objects1_serialized $objects2_serialized $channel
}

proc compare_serialized_objects { serialized_objects1 serialized_objects2 { channel {} } } {
  ::tclapp::xilinx::diff::print_subheader "Comparing Objects..." $channel
  set differing_properties {}
  foreach serialized_object1 $serialized_objects1 serialized_object2 $serialized_objects2 {
    set differing_properties [ concat $differing_properties [ ::tclapp::xilinx::diff::compare_object_props_ $serialized_object1 $serialized_object2 $channel ] ]
  }
  set differing_properties [ lsort -unique $differing_properties ]
  if { [ llength $differing_properties ] > 0 } {
    ::tclapp::xilinx::diff::print_info "Differing properties exist, differing properties are:\n  [ join $differing_properties \  ]" $channel
  } else {
    ::tclapp::xilinx::diff::print_success "All properties for all objects are equivalent" $channel
  }
  return $differing_properties
}

proc compare_object_props_ { serialized_object1 serialized_object2 { channel {} } } {
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

  if { $serialized_object1 == $serialized_object2 } {
    if { $verbose } {
      ::tclapp::xilinx::diff::print_info "Comparing ${object_count} properties on '${object_class}' '${object_name}'...\n" $channel
      ::tclapp::xilinx::diff::print_success "All properties are equivalent\n" $channel
    }
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
        ::tclapp::xilinx::diff::print_info "Comparing ${object_count} properties on '${object_class}' '${object_name}'...\n" $channel
      }
      ::tclapp::xilinx::diff::print_alert "Property '${property}' differs - '$object1_properties($property)' <=> '$object2_properties($property)'\n" $channel
      lappend differing_properties $property
    }
  }
  return $differing_properties
}

####################################################################################################
# section: report definitions
####################################################################################################
proc set_global_report { file } {
  variable global_report $file 
}

proc set_verbose { value } {
  variable verbose $value 
}

proc print_stamp { { channel {} } } {
  catch { version } _version
  set _build  [lindex [lindex [split $_version \n] 0] 1]
  set _cl     [lindex [lindex [split $_version \n] 1] 1]
  ::tclapp::xilinx::diff::print_info "Created at [clock format [clock seconds]]" $channel
  ::tclapp::xilinx::diff::print_info "Current Build: $_build\t\tChangelist: $_cl\t\tProcess ID: [pid]" $channel
}

proc print_css {} {
  lappend html "<link href='http://maxcdn.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css' rel='stylesheet' />"
  lappend html "<style type='text/css'>"
  lappend html "  .panel-heading {cursor: pointer;}"
  lappend html "</style>"
  return [ join $html \n ]
}


proc print_js {} {
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
  variable global_report
  if { "$channel" == "" } {
    set channel $global_report
  }
  #array set msg [ array get $output ]
  array set msg $output 
  if { [ regexp {.*\.(htm|html)$} $channel ] } {
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
  set new_msg {}
  foreach line [ split $subheader \n ] { if { $line != {} } { lappend new_msg [ string trim [ html_escape $line ] ] } }
  lappend html [ join $new_msg "<br/>" ]
  lappend html "<pre>"; #well
  set msg(HTML) [ join $html \n ]
  set msg(STD)  "\$\$ ${new_msg}"
  print_msg [ array get msg ] $channel
}

proc print_header { header { channel {} } } {
  set new_msg {}
  foreach line [ split $header \n ] { if { $line != {} } { lappend new_msg [ string trim [ html_escape $line ] ] } }
  lappend html "</pre>"; #well
  lappend html "</div>"; #panel-body
  lappend html "</div>"; #panel
  lappend html "<div class='panel panel-primary'>"; #panel
  lappend html "<div class='panel-heading'>"; #panel-heading
  lappend html "<span class='toc'>"
  lappend html [ join $new_msg "<br/>" ]
  lappend html "</h2>"
  lappend html "</div>"; #panel-heading
  lappend html "<div class='panel-body'>"; #panel-body
  set msg(HTML) [ join $html \n ]
  set msg(STD)  "\n\n@@ ${header}"
  print_msg [ array get msg ] $channel
}

proc print_info { info { channel {} } } {
  lappend html "<span title='[ html_escape ${info} ]' class='text-info'>"
  lappend html [ html_escape $info ]
  lappend html "</span>"
  set msg(HTML) [ join $html {} ]
  set msg(STD)  "** ${info}"
  print_msg [ array get msg ] $channel 0
}

proc print_alert { alert { channel {} } } {
  lappend html "<span class='text-danger'>"
  lappend html [ html_escape $alert ]
  lappend html "</span>"
  set msg(HTML) [ join $html {} ]
  set msg(STD)  "!! ${alert}"
  print_msg [ array get msg ] $channel 0
}

proc print_success { success { channel {} } } {
  lappend html "<span class='text-success'>"
  lappend html [ html_escape $success ]
  lappend html "</span>"
  set msg(HTML) [ join $html {} ]
  set msg(STD)  "== ${success}"
  print_msg [ array get msg ] $channel 0
}

proc print_results { results { channel {} } } {
  lappend html "<span class='text-muted'>"
  lappend html [ html_escape $results ]
  lappend html "</span>"
  set msg(HTML) [ join $html {} ]
  set msg(STD)  "${results}"
  print_msg [ array get msg ] $channel 0 ; # don't print a new line
}

proc html_escape { _string } {
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
    
  # Categories: xilinxtclstore, junit
 
  set output $_string
  set output [ string map {& &amp;} $output ]
  set output [ string map {\" &quot;} $output ]
  set output [ string map {' &apos;} $output ]
  set output [ string map {< &lt;} $output ]
  set output [ string map {> &gt;} $output ]
  return $output
}

}; # end ::tclapp::xilinx::diff

