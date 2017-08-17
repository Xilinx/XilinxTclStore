####################################################################################
#
# create_bd_partition_def.tcl
#
# Purpose: Create a partition definition from a level of hierarchy.
#
# 2017.3 - v1.0 (rev 1)
#   * initial version
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::projutils {

proc create_bd_partition_def {args} {
  # Summary:
  # Create a partition definition from a level of hierarchy cell
  
  # Argument Usage:
  # [-verbose]: Print detailed information as processing
  # -name <arg>: Specify the name of partition definition
  # -module <arg>: Specify the reconfigurable module name
  # cell_path: The path of a level hierarchy cell

  # Return Value:
  # None

  # Categories: xilinxtclstore, projutils

  # member variables
  variable a_cpd_vars
  cpd_init_vars
 
  # process options
  set runs_specified [list]
  for { set index 0 } { $index < [llength $args] } { incr index } {
    set option [string trim [lindex $args $index]]
    # NOTE: get_runs here handles invalid run string / object nicely
    switch -regexp -- $option {
      "-module"       { incr index; set a_cpd_vars(rm_name) [lindex $args $index] }
      "-name"         { incr index; set a_cpd_vars(name) [lindex $args $index] }
      "-verbose"      { set a_cpd_vars(b_verbose) 1 }
      default {
        # is incorrect switch specified?
        if { [ regexp {^-} $option ] } {
          send_msg_id cr_bd_partition_def-Tcl-001 ERROR "Unknown option '$option', type 'create_bd_partition_def -help' for usage info.\n"
          return
        }
        set a_cpd_vars(cell_path) $option
      }
    }
  }
  
  if { [ string length $a_cpd_vars(cell_path) ] == 0} {
    send_msg_id cr_bd_partition_def-Tcl-002 ERROR "The cell_path is required yet it was not specified, type 'create_bd_partition_def -help' for usage info.\n"
    return
  }

  if { [ string length $a_cpd_vars(name) ] == 0} {
    send_msg_id cr_bd_partition_def-Tcl-003 ERROR "The name (-name) is required yet it was not specified, type 'create_bd_partition_def -help' for usage info.\n"
    return
  }

  if { [ string length $a_cpd_vars(rm_name) ] == 0} {
    send_msg_id cr_bd_partition_def-Tcl-004 ERROR "The name (-module) is required yet it was not specified, type 'create_bd_partition_def -help' for usage info.\n"
    return
  }

  cpd_create_bd_partition

  return
}
}

# common utilities
namespace eval ::tclapp::xilinx::projutils {

proc cpd_init_vars {} {
  # Summary: Initialize all member variables
  # Argument Usage: None
  # Return Value: None
  
  # member variables
  variable a_cpd_vars
  array unset a_cpd_vars

  set a_cpd_vars(name)       {}
  set a_cpd_vars(rm_name)    {}
  set a_cpd_vars(cell_path)  {}
  set a_cpd_vars(b_verbose)   0
}

proc cpd_create_bd_partition {} {
  # Summary: Initialize all member variables
  # Argument Usage: None
  # Return Value: None
    
  variable a_cpd_vars
  set pd_name $a_cpd_vars(name)

  set pr_flow [string is true [get_property PR_FLOW [current_project]]]
  if { $pr_flow == 0 } {
    set_property PR_FLOW true [current_project]
  }

  set cur_cell_obj  [get_bd_cell $a_cpd_vars(cell_path)]
  set cur_cell_name [get_property name $cur_cell_obj]
  set curdesign     [current_bd_design]

  create_bd_design -cell $cur_cell_obj $a_cpd_vars(rm_name)
  set new_mod [create_partition_def -name $pd_name -module $a_cpd_vars(rm_name)]

  create_reconfig_module -name $a_cpd_vars(rm_name) -partition_def $new_mod -define_from $a_cpd_vars(rm_name)
  current_bd_design $curdesign

  set new_pdcell_obj [create_bd_cell -type module -reference $new_mod ${cur_cell_name}_temp]

  replace_bd_cell $cur_cell_obj $new_pdcell_obj
  delete_bd_objs  $cur_cell_obj 

  set_property name ${cur_cell_name} $new_pdcell_obj
}
}
