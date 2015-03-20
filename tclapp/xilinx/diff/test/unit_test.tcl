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


set log_dir [ file join $test_dir unit_logs ]
if { [ file exists $log_dir ] } {
  file delete -force $log_dir
}
file mkdir $log_dir

set log [ file join $log_dir unit_test.log ]
if { [ file exists $log ] } {
  file delete -force $log
}


#
# Generic
# 


set_global_report stdout
assert_same "stdout" [ get_global_report ]
set_global_report $log
assert_same $log [ get_global_report ]
set_global_report {}
assert_same {} [ get_global_report ]
set_verbose 0
assert_same 0 [ get_verbose ]
set_verbose 1
assert_same 1 [ get_verbose ]
# These next commands take objects as they are, thus using strings works here
set_compare_objects d1 p1 d2 p2
assert_same [ list [ list d1 d2 ] [ list p1 p2 ] ] [ get_compare_objects ]
set_compare_objects d3 p3 d4 p4
assert_same [ list [ list d3 d4 ] [ list p3 p4 ] ] [ get_compare_objects ]
set_checkpoints c1 c2
assert_same [ list c1 c2 ] [ get_checkpoints ]
set_checkpoints c3 c4
assert_same [ list c3 c4 ] [ get_checkpoints ]


#
# Assertions
#


# assert_same
assert_same 1         1           "Expect assert_same to return OK on 1:1" $log
assert_same 0         0           "Expect assert_same to return OK on 0:0" $log
assert_same 1         [ expr 1 && true ] "Expect assert_same to return OK on 1:true" $log
assert_same 0         [ expr 1 && false ] "Expect assert_same to return OK on 0:false" $log
assert_same string1   string1     "Expect assert_same to return OK on string1:string1" $log
assert_same "string1" "string1"   "Expect assert_same to return OK on \"string1\":\"string1\"" $log
assert_same "string1" {string1}   "Expect assert_same to return OK on \"string1\":{string1}" $log
assert_same ""        ""          "Expect assert_same to return OK on \"\":\"\"" $log
assert_same ""        {}          "Expect assert_same to return OK on \"\":{}" $log
set caught_error [ catch { assert_same 1 2 "Expect assert_same to return FAIL on 1:2" $log } _error ]
if { ! $caught_error } { error "ERROR: Expected 'assert_same 1 2' to throw, and it did not!!" }


# assert_pass
assert_pass { puts "assert_pass w/ puts" } "Expect assert_pass to return OK on puts" $log 
set caught_error [ catch { assert_pass { error "assert_pass w/ error" } "Expect assert_pass to return FAIL on error" $log } ]
if { ! $caught_error } { error "ERROR: Expected 'assert_pass { error ... }' to throw, and it did not!!" }

assert_pass { 
  uplevel { 
    assert_same 1 1 "Expect assert_same to return OK on 1:1" $log 
  } 
} "Expect assert_pass to return OK on assert_same OK" $log 

set caught_error [ catch {
  assert_pass { 
    uplevel { 
      assert_same 1 2 "Expect assert_same to return FAIL on 1:2" $log 
    } 
  } "Expect assert_pass to return FAIL on assert_same FAIL" $log 
} _error ]
if { ! $caught_error } { error "ERROR: Expected 'assert_pass {assert_same 1 2}' to throw, and it did not!!" }


# assert_fail
assert_fail { error "assert_fail w/ error" } "Expect assert_fail to return OK on error" $log 
set caught_error [ catch { assert_fail { puts "assert_fail w/ puts" } "Expect assert_fail to return FAIL on puts" $log } ]
if { ! $caught_error } { error "ERROR: Expected 'assert_fail { puts ... }' to throw, and it did not!!" }

assert_fail { 
  uplevel { 
    assert_same 1 2 "Expect assert_same to return FAIL on 1:2" $log 
  } 
} "Expect assert_fail to return OK on assert_same FAIL" $log 

set caught_error [ catch {
  assert_fail { 
    uplevel { 
      assert_same 1 1 "Expect assert_same to return OK on 1:1" $log 
    } 
  } "Expect assert_fail to return FAIL on assert_same OK" $log 
} _error ]
if { ! $caught_error } { error "ERROR: Expected 'assert_pass {assert_same 1 2}' to throw, and it did not!!" }


# assert_true
assert_pass { uplevel { assert_true 1 "Expect 'assert_true 1' to return OK" $log } } "Expect assert_true to pass" $log
assert_pass { uplevel { assert_true "1" "Expect 'assert_true \"1\"' to return OK" $log } } "Expect assert_true to pass" $log
assert_pass { uplevel { assert_true true "Expect 'assert_true true' to return OK" $log } } "Expect assert_true to pass" $log
assert_pass { uplevel { assert_true "true" "Expect 'assert_true \"true\"' to return OK" $log } } "Expect assert_true to pass" $log

assert_fail { uplevel { assert_true 0 "Expect 'assert_true 0' to return FAIL" $log } } "Expect assert_true to fail" $log
assert_fail { uplevel { assert_true false "Expect 'assert_true false' to return FAIL" $log } } "Expect assert_true to fail" $log


# assert_false
assert_pass { uplevel { assert_false 0 "Expect 'assert_false 0' to return OK" $log } } "Expect assert_false to pass" $log
assert_pass { uplevel { assert_false "0" "Expect 'assert_false \"0\"' to return OK" $log } } "Expect assert_false to pass" $log
assert_pass { uplevel { assert_false false "Expect 'assert_false false' to return OK" $log } } "Expect assert_false to pass" $log
assert_pass { uplevel { assert_false "false" "Expect 'assert_false \"false\"' to return OK" $log } } "Expect assert_false to pass" $log

assert_fail { uplevel { assert_false 1 "Expect 'assert_false 1' to return FAIL" $log } } "Expect assert_false to fail" $log
assert_fail { uplevel { assert_false true "Expect 'assert_false true' to return FAIL" $log } } "Expect assert_false to fail" $log


# assert_same_file
set content1 "content 1"
set content2 "content 2"
set file1 [ file join $log_dir test1.txt ]
set file2 [ file join $log_dir test2.txt ]

set fh1 [ open $file1 w+ ]
puts $fh1 $content1
close $fh1
set fh2 [ open $file2 w+ ]
puts $fh2 $content1
close $fh2
assert_pass { uplevel { assert_same_file $file1 $file2 "Expect assert_same_file to return OK" $log } } "Expect assert_same_file to pass" $log

set fh1 [ open $file1 w+ ]; # overwrites file
puts $fh1 $content1
close $fh1
set fh2 [ open $file2 w+ ]; # overwrites file
puts $fh2 $content2; # different content
close $fh2
assert_fail { uplevel { assert_same_file $file1 $file2 "Expect assert_same_file to return FAIL" $log } } "Expect assert_same_file to fail" $log

# assert_string_in_file
#   NOTE: uses files from previous step
assert_pass { uplevel { assert_string_in_file $content1 $file1 "Expect assert_string_in_file to return OK" $log } } "Expect assert_string_in_file to pass" $log
assert_pass { uplevel { assert_string_in_file $content2 $file2 "Expect assert_string_in_file to return OK" $log } } "Expect assert_string_in_file to pass" $log

assert_fail { uplevel { assert_string_in_file $content2 $file1 "Expect assert_string_in_file to return FAIL" $log } } "Expect assert_string_in_file to fail" $log
assert_fail { uplevel { assert_string_in_file $content1 $file2 "Expect assert_string_in_file to return FAIL" $log } } "Expect assert_string_in_file to fail" $log

# assert_string_not_in_file
#   NOTE: uses files from previous step
assert_pass { uplevel { assert_string_not_in_file $content2 $file1 "Expect assert_string_not_in_file to return OK" $log } } "Expect assert_string_not_in_file to pass" $log
assert_pass { uplevel { assert_string_not_in_file $content1 $file2 "Expect assert_string_not_in_file to return OK" $log } } "Expect assert_string_not_in_file to pass" $log

assert_fail { uplevel { assert_string_not_in_file $content1 $file1 "Expect assert_string_not_in_file to return FAIL" $log } } "Expect assert_string_not_in_file to fail" $log
assert_fail { uplevel { assert_string_not_in_file $content2 $file2 "Expect assert_string_not_in_file to return FAIL" $log } } "Expect assert_string_not_in_file to fail" $log

# assert_file_exists
#   NOTE: uses files from previous step
assert_pass { uplevel { assert_file_exists $file2 "Expect assert_file_exists to return OK" $log } } "Expect assert_file_exists to pass" $log
file delete -force $file1
file delete -force $file2
assert_fail { uplevel { assert_file_exists $file1 "Expect assert_file_exists to return FAIL" $log } } "Expect assert_file_exists to fail" $log


#
# Filters
#


# html_escape
assert_same "test&amp;test" [ html_escape "test&test" ] "Expect & to convert to &amp;" $log
assert_same "test&quot;test" [ html_escape "test\"test" ] "Expect \" to convert to &quot;" $log
assert_same "test&apos;test" [ html_escape "test'test" ] "Expect ' to convert to &apos;" $log
assert_same "test&lt;test" [ html_escape "test<test" ] "Expect < to convert to &lt;" $log
assert_same "test&gt;test" [ html_escape "test>test" ] "Expect > to convert to &gt;" $log

# remove_comments
#   NOTE: Used in lower sections
set proc_string "proc test_1 {} {
  # comments - for test1
  puts 'test string with specials: &\"'<>  !@#$%^&*()';  # more comments
}"
set proc_nocomment "proc test_1 {} {

  puts 'test string with specials: &\"'<>  !@#$%^&*()';
}"
assert_same $proc_nocomment [ remove_comments $proc_string ] "Expect comments to be removed" $log

# remove_whitespace
#   NOTE: using string from previous section
set proc_nowhite "proctest_1{}{#comments-fortest1puts'teststringwithspecials:&\"'<>!@#$%^&*()';#morecomments}"
assert_same $proc_nowhite [ remove_whitespace $proc_string ] "Expect whitespace to be removed" $log

# remove_special
#   NOTE: using string from previous section
set proc_nospecial "proc test_1  
   comments - for test1
  puts test string with specials      more comments
"
assert_same $proc_nospecial [ remove_special $proc_string ] "Expect special characters to be removed" $log

# remove_datestamps
set dates "W/ TZ: Mon Jun 16 10:02:33 MDT 2014 end
W/O TZ: Mon Jun 1 1:02:33 2014 end
ISO: 2014-01-04T07:00:23+0400 end"
set dates_cleaned "W/ TZ: <removed_timestamp> end
W/O TZ: <removed_timestamp> end
ISO: <removed_timestamp> end"
assert_same $dates_cleaned [ remove_datestamps $dates ] "Expect datestamps to be removed" $log


#
# Reporting
#


# Used in lower sections
set reports {}
set log_report [ file join $log_dir report.log ]
lappend reports $log_report

set html_report [ file join $log_dir report.html ]
lappend reports $html_report

foreach report $reports {
  print_start "Difference Report" $report
  print_stamp $report
  set msg(HTML) "<b>custom message (base proc)</b>"
  set msg(STD) "custom message (base proc)"
  print_msg [ array get msg ] $report
  print_header "custom header" $report
  print_subheader "custom subheader" $report
  print_info "custom info\n" $report
  print_alert "custom alert\n" $report
  print_success "custom success\n" $report
  print_results "custom results\n" $report
  print_header "custom header 2" $report
  print_subheader "custom subheader 2" $report
  print_info "custom info 2\n" $report
  print_alert "custom alert 2\n" $report
  print_success "custom success 2\n" $report
  print_results "custom results 2\n" $report
  print_end $report
  assert_file_exists $report "Expect '${report}' to exist" $log
  assert_string_in_file "custom message" $report "Expect 'customer message' in file" $log
  assert_string_in_file "custom header" $report "Expect 'customer header' in file" $log
  assert_string_in_file "custom subheader" $report "Expect 'customer subheader' in file" $log
  assert_string_in_file "custom info" $report "Expect 'customer info' in file" $log
  assert_string_in_file "custom alert" $report "Expect 'customer alert' in file" $log
  assert_string_in_file "custom success" $report "Expect 'customer success' in file" $log
  assert_string_in_file "custom results" $report "Expect 'customer results' in file" $log
  #file delete -force $report
}


#
# Data
#


# serialize_objects
set part1 [ lindex [ get_parts ] 0 ]
set serialized_part1 [ serialize_objects $part1 ]
foreach property [ list_property $part1 ] {
  print_info "  Checking for serialized property '${property}'\n" $log
  if { ! [ regexp -- $property $serialized_part1 ] } { error "Serialized object property missing: '${property}'" }
  set prop_val [ get_property -quiet $property $part1 ]
  print_info "  Checking for serialized property value '${prop_val}'\n" $log
  if { ! [ regexp -- $prop_val $serialized_part1 ] } { error "Serialized object property value missing: '${prop_val}'" }
}

set parts [ lrange [ get_parts ] 1 3 ]
set serialized_parts [ serialize_objects $parts ]
foreach name [ get_property NAME $parts ] {
  print_info "  Checking for serialzied part with name: $name\n" $log
  if { ! [ regexp -- $name $serialized_parts ] } { error "Serialized objects name missing: '${name}'" }
}


#
# Algorithms
#


# compare_serialize_objects
#   NOTE: uses objects from previous section
#set part1 [ lindex [ get_parts ] 0 ]
#set serialized_part1 [ serialize_objects $part1 ]
set part2 [ lindex [ get_parts ] 1 ]
set serialized_part2 [ serialize_objects $part2 ]

# compare part1 w/ part1
set cso_same_log [ file join $log_dir cso_same.log ]
set differing_properties [ compare_serialized_objects $serialized_part1 $serialized_part1 $cso_same_log ]
assert_same 0 [ llength $differing_properties ] "Expect part1 and part1 serialized properties to be the same" $log
assert_file_exists $cso_same_log "Expect compare_serialized_objects log to exist" $log
assert_string_in_file "are equivalent" $cso_same_log "Expect all properties to be equivalent" $log
#file delete -force $cso_same_log

# compare part1 w/ part2
set cso_diff_log [ file join $log_dir cso_diff.log ]
set differing_properties [ compare_serialized_objects $serialized_part1 $serialized_part2 $cso_diff_log ]
assert_true [ expr [ llength $differing_properties ] > 0 ] "Expect part1 and part2 serialized properties to be different" $log
assert_file_exists $cso_diff_log "Expect compare_serialized_objects log to exist" $log
assert_string_in_file "Differing properties exist" $cso_diff_log "Expect property differences" $log
#file delete -force $cso_diff_log

# compare_objects
#   NOTE: using parts from previous section

# compare part1 w/ part1
set co_same_log [ file join $log_dir co_same.log ]
set differing_properties [ compare_objects $part1 $part1 $co_same_log ]
assert_same 0 [ llength $differing_properties ] "Expect part1 and part1 serialized properties to be the same" $log
assert_file_exists $co_same_log "Expect compare_serialized_objects log to exist" $log
assert_string_in_file "are equivalent" $co_same_log "Expect all properties to be equivalent" $log
#file delete -force $co_same_log

# compare part1 w/ part2
set co_diff_log [ file join $log_dir co_diff.log ]
set differing_properties [ compare_objects $part1 $part2 $co_diff_log ]
assert_true [ expr [ llength $differing_properties ] > 0 ] "Expect part1 and part2 serialized properties to be different" $log
assert_file_exists $co_diff_log "Expect compare_serialized_objects log to exist" $log
assert_string_in_file "Differing properties exist" $co_diff_log "Expect property differences" $log
#file delete -force $co_diff_log

# compare_unordered_lists, returns the different items
assert_same [ list 1 ]  [ compare_unordered_lists "2 4 3" "4 3 2 1" $log ] "Expect 1 to be the only difference" $log
assert_same [ list 4 ]  [ compare_unordered_lists [ list 1 2 4 3 ] [ list 3 2 1 ] $log ] "Expect 1 to be the only difference" $log
assert_same [ list ]    [ compare_unordered_lists "1 2 4 3" "4 3 2 1" $log ] "Expect no difference in lists" $log
assert_same [ list ]    [ compare_unordered_lists "1 2 4 3" "1 2 3 4" $log ] "Expect no difference in lists" $log
set list1 [ list {item4} {item3} {item2} ]
set list2 [ list {item1} {item2} {item3} {item4} ]
assert_same "item1"     [ compare_unordered_lists $list1 $list2 $log ] "Expect item1 to be the only difference" $log

# compare_ordered_lists, returns the number of differences
assert_true [ expr [ compare_ordered_lists "1 2 4 3" "1 2 3 4" $log ] > 0 ] "Expect to be different" $log
assert_true [ expr [ compare_ordered_lists [ list 1 3 2 4 ] [ list 1 2 3 4 ] $log ] > 0 ] "Expect to be differt" $log
assert_true [ expr [ compare_ordered_lists "1 2 4 3" "4 3 2 1" $log ] > 0 ] "Expect to be different" $log
assert_true [ expr [ compare_ordered_lists "1 2 3 4" "1 2 3 4" $log ] == 0 ] "Expect to be same" $log
set list1 [ list {item1} {item2} {item4} ]
set list2 [ list {item1} {item2} {item3} {item4} ]
assert_true [ expr [ compare_ordered_lists $list1 $list2 $log ] > 0 ] "Expect 1 to be different" $log

# compare_lines
assert_true [ expr [ compare_lines $proc_string $proc_string "str1" "str2" $log ] == 0 ] "Expect same procs to be same" $log
assert_true [ expr [ compare_lines $proc_string [ remove_comments $proc_string ] "str1" "nocomment" $log ] > 0 ] "Expect procs to be different" $log
assert_true [ expr [ compare_lines $proc_string [ remove_special $proc_string ] "str1" "nospecial" $log ] > 0 ] "Expect procs to be different" $log
assert_true [ expr [ compare_lines [ join $list1 "\n" ] [ join $list1 "\n" ] "list1" "list2" $log ] == 0 ] "Expect same lists to be same" $log
assert_true [ expr [ compare_lines [ join $list1 "\n" ] [ join $list2 "\n" ] "list1" "list2" $log ] > 0 ] "Expect lists to be different" $log

# compare_files
#   NOTE: uses objects from previous section
assert_true [ expr [ compare_files $log_report $log_report $log ] == 0 ] "Expect same logs to be same" $log
assert_true [ expr [ compare_files $log_report $html_report $log ] > 0 ] "Expect html to differ from log" $log
assert_true [ expr [ compare_files $html_report $html_report $log ] == 0 ] "Expect same html to be same" $log

# compare_dirs
#   NOTE: uses objects from previous section
assert_same [ list ] [ compare_dirs $log_dir $log_dir $log ] "Expect same log dir to be same" $log
assert_true [ expr [ llength [ compare_dirs $log_dir $test_dir $log ] ] > 0 ] "Expect log dir to differ from test dir" $log

# unique_in_first_set
assert_same [ list ]    [ lsort [ unique_in_first_set "2 4 3" "4 3 2 1" ] ] "Expect no differences" $log
assert_same [ list 4 ]  [ lsort [ unique_in_first_set [ list 1 2 4 3 ] [ list 3 2 1 ] ] ] "Expect 4 to be the only difference" $log
assert_same [ list 2 ]  [ lsort [ unique_in_first_set "1 2 4 3" "4 3 5 1" ] ] "Expect 2 to be the only difference" $log
assert_same [ list ]    [ lsort [ unique_in_first_set "1 2 4 3" "1 2 3 4" ] ] "Expect no difference in lists" $log
set list1 [ list {item1} {item2} {item3} {item4} ]
set list2 [ list {item4} {item3} {item2} ]
assert_same [ list ]    [ lsort [ unique_in_first_set $list1 $list1 ] ] "Expect list1 to be the same" $log
assert_same "item1"     [ lsort [ unique_in_first_set $list1 $list2 ] ] "Expect item1 to be the only difference" $log

# unique_in_both_sets
assert_same [ list 1 ]    [ lsort [ unique_in_both_sets "2 4 3" "4 3 2 1" ] ] "Expect 1 to be the only difference" $log
assert_same [ list 4 5 ]  [ lsort [ unique_in_both_sets [ list 1 2 4 3 ] [ list 3 2 1 5 ] ] ] "Expect 4 and 5 to be the only difference" $log
assert_same [ list 2 5 ]  [ lsort [ unique_in_both_sets "1 2 4 3" "4 3 5 1" ] ] "Expect 2 and 5 to be the only difference" $log
assert_same [ list ]      [ lsort [ unique_in_both_sets "1 2 4 3" "1 2 3 4" ] ] "Expect no difference in lists" $log
set list1 [ list {item1} {item2} {item3} {item4} ]
set list2 [ list {item4} {item3} {item2} {item5} ]
assert_same [ list ]             [ lsort [ unique_in_both_sets $list1 $list1 ] ] "Expect list1 to be the same" $log
assert_same [ list item1 item5 ] [ lsort [ unique_in_both_sets $list1 $list2 ] ] "Expect item1 and item5 to be the only difference" $log


#
# Design
#


# These are tested in the design_test.tcl


puts "Done."

