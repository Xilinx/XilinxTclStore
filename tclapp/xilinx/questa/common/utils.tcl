####################################################################################
#
# utils.tcl
#
# Script created on 11/17/2015 by Nik Cimino (Xilinx, Inc.)
#
####################################################################################

# These procedures are not designed to be part of the global namespace, but should 
# be sourced inside of a simulation app's namespace. This is done to prevent 
# collisions of these functions if they all belonged to the same namespace, i.e.
# multiple utils.tcl files loaded with the same namespace.

variable _xcs_defined 1

proc xcs_find_comp { comps_arg index_arg to_match } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $comps_arg comps
  upvar $index_arg index
  set index 0
  set b_found false
  foreach comp $comps {
    incr index
    if { $to_match != $comp } continue;
    set b_found true
    break
  }
  return $b_found
}

proc xcs_contains_verilog { design_files {flow "NULL"} {s_netlist_file {}} } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_verilog_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {|}] 0]
    switch $type {
      {VERILOG} {
        set b_verilog_srcs 1
      }
    }
  }

  if { $flow != "NULL" } {
    if { (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && (!$b_verilog_srcs) } {
      set extn [file extension $s_netlist_file]
      if { {.v} == $extn } {
        set b_verilog_srcs 1
      }
    }
  }

  return $b_verilog_srcs
}

proc xcs_is_core_container { ip_file_name } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_is_container 1
  if { [get_property sim.use_central_dir_for_ips [current_project]] } {
    return $b_is_container
  }

  # is this ip core-container? if not return 0 (classic)
  set value [string trim [get_property core_container [get_files -all -quiet ${ip_file_name}]]]
  if { {} == $value } {
    set b_is_container 0
  }
  return $b_is_container
}
