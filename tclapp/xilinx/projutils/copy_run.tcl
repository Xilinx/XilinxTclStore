####################################################################################
#
# copy_run.tcl (copy a Vivado run via Tcl)
#
# Script created on 01/05/2016 by Nik Cimino Xilinx, Inc.
#
# 2016.1 - v1.0 (rev 1)
#  * initial version
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::projutils {
  namespace export copy_run
}

namespace eval ::tclapp::xilinx::projutils {

proc copy_run args {
  # Summary:
  # Copy a run from an already existing run, source-run, to a new copy of that run, destination-run.

  # Argument Usage:
  # [-parent_run <arg>]: Specify the synthesis run for the new implementation run, accepts name or run object (Default: same as source run)
  # [-verbose]: Print detailed information as the copy progresses
  # -name <arg>: Specify the name of the new run
  # run: The run to be copied, accepts name or run object

  # Return Value:
  # The new run object

  # Categories: xilinxtclstore, projutils

  # member variables
  variable m_cpr_options
  init_cpr_vars_
 
  # process options
  set runs_specified [list]
  for { set index 0 } { $index < [ llength $args ] } { incr index } {
    set option [ string trim [ lindex $args $index ] ]
    # NOTE: get_runs here handles invalid run string / object nicely
    switch -regexp -- $option {
      "-parent_run"   { incr index; set parent_run [ lindex $args $index ] }
      "-name"         { incr index; set m_cpr_options(name) [ lindex $args $index ] }
      "-verbose"      { set m_cpr_options(verbose) 1 }
      default {
        # is incorrect switch specified?
        if { [ regexp {^-} $option ] } {
          send_msg_id Vivado-projutils-401 ERROR "Unknown option '$option', type 'copy_run -help' for usage info.\n"
          return 1
        }
        # positional
        foreach run $option {
          lappend runs_specified $run
        }
      }
    }
  }

  # business logic
  if { [ llength $runs_specified ] != 1 } {
    send_msg_id Vivado-projutils-402 ERROR "Expected one run, received [ llength $m_cpr_options(run_to_copy) ]: '[ join $m_cpr_options(run_to_copy) ',\ ' ]', type 'copy_run -help' for usage info.\n"
    return 1
  }
  if { [ string length $m_cpr_options(name) ] == 0} {
    send_msg_id Vivado-projutils-403 ERROR "The run name (-name) is required yet it was not specified, type 'copy_run -help' for usage info.\n"
    return 1
  }
  if { [ llength [ get_runs -quiet $m_cpr_options(name) ] ] != 0} {
    send_msg_id Vivado-projutils-413 ERROR "A run already exists with the name '$m_cpr_options(name)', type 'copy_run -help' for usage info.\n"
    return 1
  }
  # NOTE: current_project handles no project open nicely
  if { [ get_property IS_READONLY [ current_project ] ] } {
    send_msg_id Vivado-projutils-404 ERROR "The current project is marked as 'IS_READONLY', thus the run cannot be copied.\n"
    return 1
  }

  # post-processing
  foreach specified_run $runs_specified { 
    set run_object [ get_runs -quiet $specified_run ]
    if { [ llength $run_object ] != 1 } {
      send_msg_id Vivado-projutils-412 ERROR "The run object '${specified_run}' does not exist, type 'copy_run -help' for usage info.\n"
      return 1
    }
    set m_cpr_options(run_to_copy) $run_object
  }
  if { [ info exists parent_run ] } {
    set parent_object [ get_runs -quiet $parent_run ]
    if { [ llength $parent_object ] != 1 } {
      send_msg_id Vivado-projutils-411 ERROR "The parent run object '${parent_run}' does not exist, type 'copy_run -help' for usage info.\n"
      return 1
    }
    set m_cpr_options(parent_run) $parent_object
  }

  # copy run
  if { $m_cpr_options(verbose) } { 
    send_msg_id Vivado-projutils-414 INFO "Starting to copy run..."
  }
  set return_run [ copy_run_ ]
  if { $m_cpr_options(verbose) } { 
    send_msg_id Vivado-projutils-415 INFO "Copy run completed successfully."
  }
  return $return_run
}



##########
# Common #
##########


proc init_cpr_vars_ {} {
  # Summary:
  # Initialize all member variables

  # Argument Usage:
  # None

  # Return Value:
  # None
  
  # member variables
  variable m_cpr_options
  
  array unset m_cpr_options
  set m_cpr_options(name)           ""
  set m_cpr_options(parent_run)     {}
  set m_cpr_options(run_to_copy)    {}
  set m_cpr_options(verbose)        0
}


proc copy_run_ {} {
  # Summary:
  # Performs the actual operations of copying a run

  # Argument Usage:
  # None

  # Return Value:
  # The new run object

  variable m_cpr_options

  set create_run_cmd create_run

  lappend create_run_cmd $m_cpr_options(name)
  
  lappend create_run_cmd "-constrset"
  lappend create_run_cmd [ get_property CONSTRSET $m_cpr_options(run_to_copy) ]
  
  lappend create_run_cmd "-flow"
  lappend create_run_cmd [ get_property FLOW $m_cpr_options(run_to_copy) ]
  
  lappend create_run_cmd "-part"
  lappend create_run_cmd [ get_property PART $m_cpr_options(run_to_copy) ]
  
  lappend create_run_cmd "-strategy"
  lappend create_run_cmd [ get_property STRATEGY $m_cpr_options(run_to_copy) ]
  
  if { $m_cpr_options(verbose) } {
    lappend create_run_cmd "-verbose"
  } else {
    lappend create_run_cmd "-quiet"
  } 
  
  if { [ get_property IS_IMPLEMENTATION $m_cpr_options(run_to_copy) ] } {
    if { $m_cpr_options(parent_run) == {} } {
      set impl_parent [ get_property PARENT $m_cpr_options(run_to_copy) ]
      if { [ string length $impl_parent ] != 0 } {
        lappend create_run_cmd "-parent_run"
        lappend create_run_cmd $impl_parent
      }
    } else {
      lappend create_run_cmd "-parent_run"
      lappend create_run_cmd $m_cpr_options(parent_run) 
    }
  }
  
  # create the new run
  if { $m_cpr_options(verbose) } { 
    send_msg_id Vivado-projutils-407 INFO "Creating run: ${create_run_cmd}\n"
  }
  set new_run [ eval $create_run_cmd ]

  # properties
  set property_value_pairs  [ list ]
  set tcl_attr_names        [ rdi::get_attr_specs -object $new_run -filter { (! IS_READONLY) && (IS_TCL) } ]
  set step_property_names   [ lsearch -regexp -all -inline [ list_property $new_run ] "STEPS\\." ] 
  set all_property_names    [ concat $tcl_attr_names $step_property_names ]

  # these should all be read-only == false (that's all we set)
  set ignore_properties     { ADD_STEP CONSTRSET DESCRIPTION FLOW NAME NEEDS_REFRESH PARENT PART SRCSET STRATEGY }

  if { $m_cpr_options(verbose) } { 
    send_msg_id Vivado-projutils-409 INFO "Copying properties: ${all_property_names}\n"
  }

  foreach property_name $all_property_names {
    
    if { [ lsearch -nocase $ignore_properties $property_name ] != -1 } {
      if { $m_cpr_options(verbose) } {
        send_msg_id Vivado-projutils-410 INFO "'${property_name}' is ignored.\n" 
      }
      continue; # property is in ignore list, skipping
    }

    set default_value [ list_property_value -default $property_name $new_run ]
    set old_value     [ get_property $property_name $m_cpr_options(run_to_copy) ]

    if { [ string equal $default_value $old_value ] } {
      if { $m_cpr_options(verbose) } { 
        send_msg_id Vivado-projutils-405 INFO "'${property_name}' is default and will not be updated ('${default_value}').\n" 
      }
      continue; # property is default, skipping
    }
  
    if { $m_cpr_options(verbose) } { 
      send_msg_id Vivado-projutils-406 INFO "'${property_name}' will be updated to '${old_value}'.\n" 
    }
    lappend property_value_pairs $property_name
    lappend property_value_pairs $old_value

  }; # foreach
  
  if { [ llength $property_value_pairs ] != 0 } {
    if { $m_cpr_options(verbose) } { 
      send_msg_id Vivado-projutils-408 INFO "The dictionary being used to set the new run's properties is: '${property_value_pairs}'\n"
    }
    set_property -dict $property_value_pairs $new_run
  }

  return $new_run
}


}; # end namespace ::tclapp::xilinx::projutils
