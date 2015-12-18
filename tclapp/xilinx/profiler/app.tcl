####################################################################################################
#
# app.tcl
#
# Script created on 12/07/2015 by Nik Cimino (Xilinx, Inc.)
#
####################################################################################################

package require Vivado 1.2014.1
package require struct::graph
package require struct::stack

####################################################################################################
# title: Profiler
####################################################################################################

namespace eval ::tclapp::xilinx::profiler {


####################################################################################################
# section: variables
####################################################################################################
variable commands_to_profile [list]
variable out_file [ file join [ pwd ] "profile.out" ]
variable csv_file [ file join [ pwd ] ".profile.csv" ]
variable csv_fd 0
variable running 0
variable arc_stack arc_stack
variable node_stack node_stack
variable profile_graph profile_graph
variable profile_units microseconds
variable written_nodes [list]
variable initialized 0

####################################################################################################
# section: export public commands
####################################################################################################
namespace export add_commands
namespace export set_out_file
namespace export get_out_file
namespace export start
namespace export stop
namespace export write_report

}; # end ::tclapp::xilinx::profiler


####################################################################################################
# section: generic setters and getters
####################################################################################################
proc ::tclapp::xilinx::profiler::set_out_file { file } {
  # Summary:
  # Sets output file that will be consumed by kcachegrind (.out)

  # Argument Usage: 
  #   file : The output file.
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler
  
  set fh [ open $file "a+" ]
  if { $fh > 0 } { close $fh }

  variable out_file $file 
}


proc ::tclapp::xilinx::profiler::get_out_file {} {
  # Summary:
  # Get output file that will be consumed by kcachegrind (.out)

  # Argument Usage: 
   
  # Return Value:
  #   out_file : The output file
    
  # Categories: xilinxtclstore, profiler
  
  variable out_file
  return $out_file
}


proc ::tclapp::xilinx::profiler::set_csv_file { file } {
  # Summary:
  # Sets output file name that will be used to capture profile (.csv).
  # This file is normally hidden and the user should not need to use this file

  # Argument Usage: 
  #   file : File name of profile csv file.
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  variable initialized 
  #variable running 

  #if { $running } { 
  #  send_msg_id Profiler-Tcl-007 ERROR "Unable to change the csv file while the profiler is running (i.e. 'start' was called). \
  #  After calling 'stop' then the csv file can be changed."
  #}
  if { $initialized } { 
    #variable csv_fd
    #close $csv_fd
    #set csv_fd [ open $file "w+" ]

    # Note: we can support changing the CSV after start, but it require all code above to be uncommented
    send_msg_id Profiler-Tcl-008 ERROR "Changing the csv file after 'start' has been called one time is not allowed."
  } else {
    # Make sure we can open it...
    set fh [ open $file "a+" ]
    if { $fh > 0 } { close $fh }
  }

  variable csv_file $file 
}


proc ::tclapp::xilinx::profiler::get_csv_file {} {
  # Summary:
  # Get output file name that will be used to capture profile (.csv).
  # This file is normally hidden and the user should not need to use this file

  # Argument Usage: 
   
  # Return Value:
  #   csv_file : The output file (.csv)
    
  # Categories: xilinxtclstore, profiler
  
  variable csv_file
  return $csv_file
}


####################################################################################################
# section: Profiling
####################################################################################################
proc ::tclapp::xilinx::profiler::start {} {
  # Summary:
  # Start profiling

  # Argument Usage: 
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  variable commands_to_profile
  variable running 

  init

  if { $running } {
    send_msg_id Profiler-Tcl-003 ERROR "Cannot start, the profiler is already running."
    return
  }
  set running 1
  foreach command $commands_to_profile {
    send_msg_id Profiler-Tcl-009 INFO "Tracking started for command: '${command}'"
    trace add execution $command enter ::tclapp::xilinx::profiler::capture
    #trace add execution $command enterstep ::tclapp::xilinx::profiler::capture
    trace add execution $command leave ::tclapp::xilinx::profiler::capture
    #trace add execution $command leavestep ::tclapp::xilinx::profiler::capture
  }
}


proc ::tclapp::xilinx::profiler::stop {} {
  # Summary:
  # Stop profiling

  # Argument Usage: 
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  variable csv_fd
  variable commands_to_profile
  variable running 

  if { ! $running } {
    send_msg_id Profiler-Tcl-002 ERROR "Cannot stop, the profiler was never started."
    return
  }
  set running 0
  foreach command $commands_to_profile {
    send_msg_id Profiler-Tcl-009 INFO "Tracking stopped for command: '${command}'"
    trace remove execution $command enter ::tclapp::xilinx::profiler::capture
    #trace remove execution $command enterstep ::tclapp::xilinx::profiler::capture
    trace remove execution $command leave ::tclapp::xilinx::profiler::capture
    #trace remove execution $command leavestep ::tclapp::xilinx::profiler::capture
  }
}


proc ::tclapp::xilinx::profiler::write_report {} {
  # Summary:
  # Write the profiling report

  # Argument Usage: 
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  variable csv_file
  variable csv_fd
  variable commands_to_profile
  variable running 

  if { $running } {
    send_msg_id Profiler-Tcl-004 ERROR "Cannot write_report, the profiler is still running."
    return
  }
  close $csv_fd
  convert_csv_to_out
  file delete -force $csv_file
}


proc ::tclapp::xilinx::profiler::add_commands commands {
  # Summary:
  # Add commands to profile

  # Argument Usage: 
  #   cmds : List of commands to profiler
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  variable commands_to_profile
  variable running

  if { $running } {
    # We can support this, but then the traces need to be added here
    send_msg_id Profiler-Tcl-001 ERROR "Cannot add_commands while the profiler is running."
    return
  }
  set commands_to_profile [ concat $commands_to_profile $commands ]
  set commands_to_profile [ lsort -unique $commands_to_profile ]
}


####################################################################################################
# section: Private - Profiling
####################################################################################################
proc ::tclapp::xilinx::profiler::init {} {
  # Summary:
  # Initialize profiler app

  # Argument Usage: 
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  variable csv_fd
  variable csv_file
  variable initialized 

  if { $initialized } { return }

  set csv_fd [ open $csv_file "w+" ]

  set initialized 1
}

proc ::tclapp::xilinx::profiler::print_stack { } {
  # Summary:
  # Prints a stack trace

  # Argument Usage: 
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  set this_location_in_stack 2
  set start_frame 2
  # stack size will change with 'for' and 'foreach' loops, but because the levels 1 
  # through $this_location_in_stack will be the same, these references are okay within the loops
  set stack_size [ info frame ]
  set stack_payload_size [ expr "${stack_size} - ${this_location_in_stack}" ]
  set stack {}
  set first_source_frame {}
  set last_source_frame {}
  for { set frame_counter $start_frame } { $frame_counter <= $stack_payload_size } { incr frame_counter } { 
    set frame [ info frame $frame_counter ]
    set frame_pairs {}
    foreach key [ lsort -decreasing [ dict keys $frame ] ] {
      set value [ dict get $frame $key ]
      if { ( "${key}" == "type" ) && ( "${value}" == "source" ) } {
        if { ( "${first_source_frame}" == "" ) } {
          set first_source_frame $frame
        } else {
          set last_source_frame $frame
        }
      }
      set max_string_size 30
      if { [ string length $value ] > $max_string_size } {
        set value "{[ string range $value 0 $max_string_size ]...}"
      }
      lappend frame_pairs "$key = $value"
    }
    lappend stack [ join $frame_pairs \ |\  ]
  }
  catch { puts " Top Most Invocation at Line: [ dict get $first_source_frame line ]  In File: [ dict get $first_source_frame file ]" }
  puts "  [ join $stack \n\ \  ]"
  catch { puts " Print Location Command at Line: [ dict get $last_source_frame line ]  In File: [ dict get $last_source_frame file ]" }
}

proc ::tclapp::xilinx::profiler::capture args {
  # Summary:
  # Takes a snapshot of current time in profiling units, currently: us (microseconds)
  # Generally called by trace for the 'enter' and 'leave' of a proc

  # Argument Usage: 
  #   file : File name of profile csv file.
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  variable csv_fd
  variable profile_units

  # This code will take procs within namespaces (e.g. 'proc2') and return the
  # fully qualified name (e.g. '::test::proc2'). This ensures 1:1 proc name w/ call.
  set name [ lindex [ lindex $args 0 ] 0 ]
  set uplevel_cmd "namespace which $name"
  set resolved [ uplevel 1 $uplevel_cmd ]

  #set capture "[ clock $profile_units ],[ lindex [ lindex $args 0 ] 0 ],[ lindex $args end ]"
  set capture "[ clock $profile_units ],${resolved},[ lindex $args end ]"
  puts $csv_fd $capture
}


####################################################################################################
# section: Private - Converting CSV to Out
####################################################################################################
proc ::tclapp::xilinx::profiler::convert_csv_to_out {} {
  # Summary:
  # Converts CSV to OUT file for kcachgrind

  # Argument Usage: 
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  reset_profile_graph
  parse_csv_to_graph
  convert_graph_to_out
  
}


proc ::tclapp::xilinx::profiler::sum_totals {arcs} {
  # Summary:
  # Sums all provided calls, each arc represents a single call

  # Argument Usage: 
  #   arcs : Should be from [<graph> arc attr total -arcs <arcs>] Which has the form {arc1 arc1_total arc2 arc2_total ...}
   
  # Return Value:
  #   total : The sum total of all the arc totals
    
  # Categories: xilinxtclstore, profiler
  set total 0
  for { set index 0 } { $index < [ llength $arcs ] } { incr index } {
    #set arc [ lindex $arcs $index ]
    incr index
    set call_total [ lindex $arcs $index ]
    incr total $call_total
  }
  return $total
}


proc ::tclapp::xilinx::profiler::write_node_to_out {node out_fd} {
  # Summary:
  # Recursively writes out the node and it's children in kcachegrind compatible format

  # Argument Usage: 
  #   node : The node to write the output for
  #   out_fd : The channel/file descriptor to write the output to
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  variable profile_graph
  variable written_nodes

  # If we already wrote this node, then skip it
  if { [lsearch $written_nodes $node] != -1 } { return }
  lappend written_nodes $node

  # Each arc represents a call: in are calling us, out we are calling
  set all_calls_from  [ $profile_graph arcs -in $node ]
  set all_calls_to    [ $profile_graph arcs -out $node ]

  # While retrieving attr the return will look like {arc1 arc1_total arc2 arc2_total ...}
  set calls_from_with_totals  [ $profile_graph arc attr total -arcs $all_calls_from ]
  set calls_to_with_totals    [ $profile_graph arc attr total -arcs $all_calls_to ]

  set total_called_from [ sum_totals $calls_from_with_totals ]
  set total_called_to   [ sum_totals $calls_to_with_totals ]

  set leftover [ expr $total_called_from - $total_called_to ]

  set name [ $profile_graph node get $node name ]
  puts $out_fd "\nfn=${name}"
  puts $out_fd "1 ${leftover}"
  set called_nodes [ $profile_graph nodes -out $node ]
  foreach called_node $called_nodes {
    set name [ $profile_graph node get $called_node name ]
    puts $out_fd "cfn=${name}"
    set calls_to_node [ $profile_graph arcs -inner $called_node $node ]
    puts $out_fd "calls=[ llength $calls_to_node] 1"
    set calls_to_node_with_totals [ $profile_graph arc attr total -arcs $calls_to_node ]
    set calls_to_node_time_total [ sum_totals $calls_to_node_with_totals ]
    puts $out_fd "1 $calls_to_node_time_total"
  }

  foreach called_node $called_nodes {
    write_node_to_out $called_node $out_fd
  }
}

proc ::tclapp::xilinx::profiler::convert_graph_to_out {} {
  # Summary:
  # Convert the in-memory graph to the kcachegrind output format

  # Argument Usage: 
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  variable out_file
  variable profile_graph
  variable profile_units
  variable written_nodes [list]
  
  send_msg_id Profiler-Tcl-010 INFO "Creating the output file..."
  set root [ $profile_graph nodes -filter ::tclapp::xilinx::profiler::is_root_node ]
  #set main [ $profile_graph nodes -out $root ]
  set out_fd [ open $out_file "w+" ]
  puts $out_fd "\nevents: ${profile_units}"
  write_node_to_out $root $out_fd
  close $out_fd
  send_msg_id Profiler-Tcl-011 INFO "Output file generated: '${out_file}'"


  # Reclaim memory
  set written_nodes [list]
}


proc ::tclapp::xilinx::profiler::parse_csv_to_graph {} {
  # Summary:
  # Convert the CSV file from profiling into the in-memory graph

  # Argument Usage: 
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  variable csv_file
  variable arc_stack
  variable node_stack
  variable profile_graph

  send_msg_id Profiler-Tcl-012 INFO "Converting profile data to graph..."

  # TODO: can we use csv_fd? will read reset the buffer to 0 before reading?
  set local_csv_fd [ open $csv_file "r" ]
  set csv_data [ split [ read $local_csv_fd [ file size $csv_file ] ] \n ]
  close $local_csv_fd
  
  set root_node_name "TclInterp"
  set root_node [ $profile_graph node insert $root_node_name ]
  $profile_graph node set $root_node name $root_node_name
  $node_stack push $root_node
  
  # Parse the CSV into a graph
  
  foreach line $csv_data {
    set separated [ split $line , ]
    set time    [ lindex $separated 0 ]
    set command [ lindex $separated 1 ]
    set type    [ lindex $separated 2 ]
  
    set node [ $profile_graph nodes -key name -value $command ]
    if { ( $node == "" ) && [ $profile_graph node exists $command ] } {
      send_msg_id Profiler-Tcl-005 ERROR "Profiler identified an unexpected condition (i.e. a bug should be filed) - \
      Did not get a node from '$profile_graph nodes...' however, the node exists..."
    }
    if { [ llength $node ] > 1 } {
      send_msg_id Profiler-Tcl-006 ERROR "Profiler identified an unexpected condition (i.e. a bug should be filed) - \
      Found more than one node matching name '${command}'"
    }
  
    if { $type == "enter" } {
      if { $node == "" } {
        set node [ $profile_graph node insert $command ]; # use command here to ensure unique
        $profile_graph node set $node name $command
      }
  
      set parent_node [ $node_stack peek ]
      set arc [ $profile_graph arc insert $parent_node $node ]
      # store the time of the call on the arc
      $profile_graph arc set $arc enter $time
     
      $arc_stack push $arc
      $node_stack push $node
    }
  
    if { $type == "leave" } {
      set previous_arc [ $arc_stack pop ]
      set enter [ $profile_graph arc get $previous_arc enter ]
      set delta [ expr $time - $enter ]
      $profile_graph arc set $previous_arc total $delta 
      $profile_graph arc unset $previous_arc enter
  
      #$profile_graph arc set $previous_arc leave $time
  
      set parent_node [ $node_stack pop ]
    }
  
  }

  send_msg_id Profiler-Tcl-013 INFO "Done converting profile data to graph."
}


proc ::tclapp::xilinx::profiler::reset_profile_graph {} {
  # Summary:
  # Clears the profile graph, the node stack, and the arc stack

  # Argument Usage: 
   
  # Return Value:
    
  # Categories: xilinxtclstore, profiler

  variable arc_stack
  variable node_stack
  variable profile_graph

  if { "[ info commands $arc_stack ]" == "$arc_stack" } { $arc_stack destroy }
  ::struct::stack $arc_stack
  if { "[ info commands $node_stack ]" == "$node_stack" } { $node_stack destroy }
  ::struct::stack $node_stack
  if { "[ info commands $profile_graph ]" == "$profile_graph" } { $profile_graph destroy }
  ::struct::graph $profile_graph
}


proc ::tclapp::xilinx::profiler::is_root_node { graph node } {
  # Summary:
  # Gets the top-most root node of the profile graph

  # Argument Usage: 
   
  # Return Value:
  #   node : The top-most root node of the profile graph.
    
  # Categories: xilinxtclstore, profiler

  return [ expr [ $graph node degree -in $node ] == 0 ]
}

