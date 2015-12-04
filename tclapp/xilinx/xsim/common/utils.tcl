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

proc xcs_get_relative_file_path { file_path_to_convert relative_to } {
  # Summary:
  # Argument Usage:
  # file_path_to_convert:
  # Return Value:

  # make sure we are dealing with a valid relative_to directory. If regular file or is not a directory, get directory
  if { [file isfile $relative_to] || ![file isdirectory $relative_to] } {
    set relative_to [file dirname $relative_to]
  }
  set cwd [file normalize [pwd]]
  if { [file pathtype $file_path_to_convert] eq "relative" } {
    # is relative_to path same as cwd?, just return this path, no further processing required
    if { [string equal $relative_to $cwd] } {
      return $file_path_to_convert
    }
    # the specified path is "relative" but something else, so make it absolute wrt current working dir
    set file_path_to_convert [file join $cwd $file_path_to_convert]
  }
  # is relative_to "relative"? convert to absolute as well wrt cwd
  if { [file pathtype $relative_to] eq "relative" } {
    set relative_to [file join $cwd $relative_to]
  }
  # normalize
  set file_path_to_convert [file normalize $file_path_to_convert]
  set relative_to          [file normalize $relative_to]
  set file_path $file_path_to_convert
  set file_comps        [file split $file_path]
  set relative_to_comps [file split $relative_to]
  set found_match false
  set index 0
  set fc_comps_len [llength $file_comps]
  set rt_comps_len [llength $relative_to_comps]
  # compare each dir element of file_to_convert and relative_to, set the flag and
  # get the final index till these sub-dirs matched
  while { [lindex $file_comps $index] == [lindex $relative_to_comps $index] } {
    if { !$found_match } { set found_match true }
    incr index
    if { ($index == $fc_comps_len) || ($index == $rt_comps_len) } {
      break;
    }
  }
  # any common dirs found? convert path to relative
  if { $found_match } {
    set parent_dir_path ""
    set rel_index $index
    # keep traversing the relative_to dirs and build "../" levels
    while { [lindex $relative_to_comps $rel_index] != "" } {
      set parent_dir_path "../$parent_dir_path"
      incr rel_index
    }
    #
    # at this point we have parent_dir_path setup with exact number of sub-dirs to go up
    #
    # now build up part of path which is relative to matched part
    set rel_path ""
    set rel_index $index
    while { [lindex $file_comps $rel_index] != "" } {
      set comps [lindex $file_comps $rel_index]
      if { $rel_path == "" } {
        # first dir
        set rel_path $comps
      } else {
        # append remaining dirs
        set rel_path "${rel_path}/$comps"
      }
      incr rel_index
    }
    # prepend parent dirs, this is the complete resolved path now
    set resolved_path "${parent_dir_path}${rel_path}"
    return $resolved_path
  }
  # no common dirs found, just return the normalized path
  return $file_path
}

proc xcs_get_sub_file_path { src_file_path dir_path_to_remove } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set src_path_comps [file split [file normalize $src_file_path]]
  set dir_path_comps [file split [file normalize $dir_path_to_remove]]

  set src_path_len [llength $src_path_comps]
  set dir_path_len [llength $dir_path_comps]

  set index 1
  while { [lindex $src_path_comps $index] == [lindex $dir_path_comps $index] } {
    incr index
    if { ($index == $src_path_len) || ($index == $dir_path_len) } {
      break;
    }
  }
  set sub_file_path [join [lrange $src_path_comps $index end] "/"]
  return $sub_file_path
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

proc xcs_is_fileset { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set spec_list [rdi::get_attr_specs -quiet -object $tcl_obj -regexp .*FILESET_TYPE.*]
  if { [llength $spec_list] > 0 } {
    if {[regexp -nocase {^fileset_type} $spec_list]} {
      return 1
    }
  }
  return 0
}

proc xcs_is_ip { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_valid_ip_extns
  # check if ip file extension
  if { [lsearch -exact $l_valid_ip_extns [file extension $tcl_obj]] >= 0 } {
    return 1
  } else {
    # check if IP object
    if {[regexp -nocase {^ip} [get_property [rdi::get_attr_specs CLASS -object $tcl_obj] $tcl_obj]] } {
      return 1
    }
  }
  return 0
}

proc xcs_is_static_ip_lib { library ip_static_libs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set library [string tolower $library]
  if { [lsearch $ip_static_libs $library] != -1 } {
    return true
  }
  return false
}
