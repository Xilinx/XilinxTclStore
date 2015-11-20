####################################################################################
#
# simulation.tcl
#
# Script created on 11/17/2015 by Nik Cimino (Xilinx, Inc.)
#
####################################################################################

# These procedures are not designed to be part of the global namespace, but should 
# be sourced inside of a simulation app's namespace. This is done to prevent 
# collisions of these functions if they all belonged to the same namespace, i.e.
# multiple simulation.tcl files loaded with the same namespace.

variable _xcs_defined 1

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

