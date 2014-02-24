###############################################################################
#
# helpers.tcl (simulation helper utilities for the 'Synopsys VCS_MX Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
###############################################################################
package require Vivado 2013.1

namespace eval ::tclapp::xilinx::vcs_mx {
  # do not export procs from this file
}

namespace eval ::tclapp::xilinx::vcs_mx {
proc usf_init_vars {} {
  # Summary: initializes global namespace vars
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set project                        [current_project]
  set a_sim_vars(s_project_name)     [get_property "NAME" $project]
  set a_sim_vars(s_project_dir)      [get_property "DIRECTORY" $project]
  set a_sim_vars(b_is_managed)       [get_property "MANAGED_IP" $project]
  set a_sim_vars(s_launch_dir)       {}
  set a_sim_vars(s_sim_top)          [get_property "TOP" [current_fileset -simset]]

  # launch_simulation tcl task args
  set a_sim_vars(s_simset)           [current_fileset -simset]
  set a_sim_vars(s_mode)             "behavioral"
  set a_sim_vars(s_type)             {}
  set a_sim_vars(b_scripts_only)     0
  set a_sim_vars(s_comp_file)        {}
  set a_sim_vars(b_absolute_path)    0
  set a_sim_vars(s_install_path)     {}
  set a_sim_vars(b_batch)            0
  set a_sim_vars(s_int_os_type)      {}
  set a_sim_vars(s_int_debug_mode)   0

  set a_sim_vars(s_tool_bin_path)    {}

  set a_sim_vars(sp_tcl_obj)         {}

  # fileset compile order
  variable l_compile_order_files     [list]

  # ip file extension types
  variable l_valid_ip_extns          [list]
  set l_valid_ip_extns               [list ".xci" ".bd" ".slx"]
 
  # data file extension types 
  variable s_data_files_filter
  set s_data_files_filter            "FILE_TYPE == \"Data Files\" || FILE_TYPE == \"Memory Initialization Files\" || FILE_TYPE == \"Coefficient Files\""

  # embedded file extension types 
  variable s_embedded_files_filter
  set s_embedded_files_filter        "FILE_TYPE == \"BMM\" || FILE_TYPE == \"ElF\""

  # non-hdl data files filter
  variable s_non_hdl_data_files_filter
  set s_non_hdl_data_files_filter \
               "FILE_TYPE != \"Verilog\"                      && \
                FILE_TYPE != \"Verilog Header\"               && \
                FILE_TYPE != \"Verilog Template\"             && \
                FILE_TYPE != \"VHDL\"                         && \
                FILE_TYPE != \"VHDL Template\"                && \
                FILE_TYPE != \"EDIF\"                         && \
                FILE_TYPE != \"NGC\"                          && \
                FILE_TYPE != \"IP\"                           && \
                FILE_TYPE != \"XCF\"                          && \
                FILE_TYPE != \"NCF\"                          && \
                FILE_TYPE != \"UCF\"                          && \
                FILE_TYPE != \"XDC\"                          && \
                FILE_TYPE != \"NGO\"                          && \
                FILE_TYPE != \"BMM\"                          && \
                FILE_TYPE != \"ELF\"                          && \
                FILE_TYPE != \"Data Files\"                   && \
                FILE_TYPE != \"Coefficient Files\"            && \
                FILE_TYPE != \"TM_XML_IPXACT\"                && \
                FILE_TYPE != \"Design Checkpoint\"            && \
                FILE_TYPE != \"Memory Initialization Files\"  && \
                FILE_TYPE != \"Waveform Configuration File\""

  # simulation mode types
  variable a_sim_mode_types
  set a_sim_mode_types(behavioral)          {behav}
  set a_sim_mode_types(post-synthesis)      {synth}
  set a_sim_mode_types(post-implementation) {impl}
  set a_sim_mode_types(funcsim)             {func}
  set a_sim_mode_types(timesim)             {timing}

  set a_sim_vars(s_flow_dir_key)            {behav}
  set a_sim_vars(s_simulation_flow)         {behav_sim}
  set a_sim_vars(s_netlist_mode)            {funcsim}

  # netlist file
  set a_sim_vars(s_netlist_file)            {}
}

proc usf_create_options { simulator opts } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # create options
  usf_create_fs_options_spec $simulator $opts

  # simulation fileset objects
  foreach fs_obj [get_filesets -filter {FILESET_TYPE == SimulationSrcs}] {
    usf_set_fs_options $fs_obj $simulator $opts
  }
}

proc usf_create_fs_options_spec { simulator opts } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # create properties on the fileset object
  foreach { row } $opts  {
    set name  [lindex $row 0]
    set type  [lindex $row 1]
    set value [lindex $row 2]
    set desc  [lindex $row 3]

    # setup property name
    set prop_name "${simulator}.${name}"

    # is registered already?
    if { [usf_is_option_registered_on_simulator $prop_name $simulator] } {
      continue;
    }

    # is enum type?
    if { {enum} == $type } {
      set e_value   [lindex $value 0]
      set e_default [lindex $value 1]
      set e_values  [lindex $value 2]
      # create enum property
      create_property -name "${prop_name}" -type $type -description $desc -enum_values $e_values -default_value $e_default -class fileset
    } else {
      set v_default $value
      create_property -name "${prop_name}" -type $type -description $desc -default_value $v_default -class fileset
    }
  }
  return 0
}

proc usf_set_fs_options { fs_obj simulator opts } {
  # Summary:
  # Argument Usage:
  # Return Value:

  foreach { row } $opts  {
    set name  [lindex $row 0]
    set type  [lindex $row 1]
    set value [lindex $row 2]
    set desc  [lindex $row 3]

    set prop_name "${simulator}.${name}"

    # is enum type?
    if { {enum} == $type } {
      set e_value   [lindex $value 0]
      set e_default [lindex $value 1]
      set e_values  [lindex $value 2]
      set_property -name "${prop_name}" -value $e_value -objects ${fs_obj}
    } else {
      set v_default $value
      set_property -name "${prop_name}" -value $value -objects ${fs_obj}
    }
  }
  return 0
}

proc usf_is_option_registered_on_simulator { prop_name simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set str_1 [string toupper $prop_name]
  # get registered options from simulator for the current simset
  foreach option_name [get_property "REGISTERED_OPTIONS" [get_simulators $simulator]] {
    set str_2 [string toupper $option_name]
    if { [string compare $str_1 $str_2] == 0 } {
      return true
    }
  }
  return false
}

proc usf_set_simulation_flow {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set fs_obj [get_filesets $a_sim_vars(s_simset)]
  set simulation_flow {unknown}
  set type_dir {timing}
  if { {behavioral} == $a_sim_vars(s_mode) } {
    if { ({functional} == $a_sim_vars(s_type)) || ({timing} == $a_sim_vars(s_type)) } {
      send_msg_id Vivado-VCS_MX-019 ERROR "Invalid simulation type '$a_sim_vars(s_type)' specified. Please see 'simulate -help' for more details.\n"
      return 1
    }
    set simulation_flow "behav_sim"
    set a_sim_vars(s_flow_dir_key) "behav"

    # set simulation and netlist mode on simset
    set_property sim_mode "behavioral" $fs_obj

  } elseif { {post-synthesis} == $a_sim_vars(s_mode) } {
    if { ({functional} != $a_sim_vars(s_type)) && ({timing} != $a_sim_vars(s_type)) } {
      send_msg_id Vivado-VCS_MX-020 ERROR "Invalid simulation type '$a_sim_vars(s_type)' specified. Please see 'simulate -help' for more details.\n"
      return 1
    }
    set simulation_flow "post_synth_sim"
    if { {functional} == $a_sim_vars(s_type) } {
      set type_dir "func"
    }
    set a_sim_vars(s_flow_dir_key) "synth/${type_dir}"

    # set simulation and netlist mode on simset
    set_property sim_mode "post-synthesis" $fs_obj
    if { {functional} == $a_sim_vars(s_type) } {
      set_property "NL.MODE" "funcsim" $fs_obj
    }
    if { {timing} == $a_sim_vars(s_type) } {
      set_property "NL.MODE" "timesim" $fs_obj
    }
  } elseif { ({post-implementation} == $a_sim_vars(s_mode)) || ({timing} == $a_sim_vars(s_mode)) } {
    if { ({functional} != $a_sim_vars(s_type)) && ({timing} != $a_sim_vars(s_type)) } {
      send_msg_id Vivado-VCS_MX-021 ERROR "Invalid simulation type '$a_sim_vars(s_type)' specified. Please see 'simulate -help' for more details.\n"
      return 1
    }
    set simulation_flow "post_impl_sim"
    if { {functional} == $a_sim_vars(s_type) } {
      set type_dir "func"
    }
    set a_sim_vars(s_flow_dir_key) "impl/${type_dir}"

    # set simulation and netlist mode on simset
    set_property sim_mode "post-implementation" $fs_obj
    if { {functional} == $a_sim_vars(s_type) } { set_property "NL.MODE" "funcsim" $fs_obj }
    if { {timing} == $a_sim_vars(s_type) } { set_property "NL.MODE" "timesim" $fs_obj }
  } else {
    send_msg_id Vivado-VCS_MX-022 ERROR "Invalid simulation mode '$a_sim_vars(s_mode)' specified. Please see 'simulate -help' for more details.\n"
    return 1
  }
  set a_sim_vars(s_simulation_flow) $simulation_flow
  return 0
}

proc usf_set_run_dir {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  # initialize simulation run dir path
  set sim_dir $a_sim_vars(s_project_name);append sim_dir ".sim"
  set mode [get_property "SIM_MODE" [get_filesets $a_sim_vars(s_simset)]]
  set run_dir [file normalize [file join $a_sim_vars(s_project_dir) $sim_dir $a_sim_vars(s_simset) $a_sim_vars(s_flow_dir_key)]]
  set a_sim_vars(s_launch_dir) $run_dir
}

proc usf_set_sim_tcl_obj {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set comp_file $a_sim_vars(s_comp_file)
  if { {} != $comp_file } {
    # -of_objects <full-path-to-ip-composite-file>
    set a_sim_vars(sp_tcl_obj) [get_files -all -quiet $comp_file]
  } else {
    set a_sim_vars(sp_tcl_obj) [current_fileset -simset]
  }
  #send_msg_id Vivado-VCS_MX-023 INFO "Simulation object is '$a_sim_vars(sp_tcl_obj)'...\n"
  return 0
}

proc usf_set_ref_dir { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  # setup source dir var
  puts $fh "# directory path for design sources and include directories (if any) wrt this path"
  if { $a_sim_vars(b_absolute_path) } {
    if {$::tcl_platform(platform) == "unix"} {
      puts $fh "reference_dir=\"$a_sim_vars(s_launch_dir)\""
    } else {
      puts $fh "set reference_dir=\"$a_sim_vars(s_launch_dir)\""
    }
  } else {
    if {$::tcl_platform(platform) == "unix"} {
      puts $fh "reference_dir=\".\""
    } else {
      puts $fh "set reference_dir=\".\""
    }
  }
  puts $fh ""
} 

proc usf_write_design_netlist {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  # is behavioral?, return
  if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
    return
  } 
  set extn [usf_get_netlist_extn 1]
  # generate netlist
  set net_filename [usf_get_netlist_filename];append net_filename "$extn"
  set sdf_filename [usf_get_netlist_filename];append sdf_filename ".sdf"
  set extn         {.v}
  set net_file [file normalize [file join $a_sim_vars(s_launch_dir) $net_filename]]
  set sdf_file [file normalize [file join $a_sim_vars(s_launch_dir) $sdf_filename]]
  set netlist_cmd_args [usf_get_netlist_writer_cmd_args]
  set sdf_cmd_args [usf_get_sdf_writer_cmd_args]

  # check run status
  switch -regexp -- $a_sim_vars(s_simulation_flow) {
    {post_synth_sim} {
      set status [get_property "STATUS" [current_run synth_1]]
      if { ({Not started} == $status) } {
        send_msg_id Vivado-VCS_MX-024 ERROR \
           "Synthesis results not available! Please run 'Synthesis' from the GUI or execute 'launch_runs <synth>' command from the Tcl console and retry this operation.\n"
        return 1
      }
      open_run synth_1 -name netlist_1

      send_msg_id Vivado-VCS_MX-025 INFO "Generarting simulation netlist '$net_file'"
      # write netlist/sdf
      # TODO: write_verilog is not taking cmd_args
      if { {functional} == $a_sim_vars(s_type) } {
        write_verilog -mode funcsim -force $net_file
      } elseif { {timing} == $a_sim_vars(s_type) } {
        write_verilog -mode timesim -force -sdf_file $sdf_file $net_file
      }
      if { {timing} == $a_sim_vars(s_type) } {
        send_msg_id Vivado-VCS_MX-026 INFO "Writing SDF file '$sdf_file'"
        write_sdf -mode timesim -force $sdf_file
      }
      set a_sim_vars(s_netlist_file) $net_file
    }
    {post_impl_sim} {
      # TODO: check if impl run exist
      set status [get_property "STATUS" [current_run impl_1]]
      if { ({Not started} == $status) } {
        send_msg_id Vivado-VCS_MX-027 ERROR \
           "Implementation results not available! Please run 'Implementation' from the GUI or execute 'launch_runs <impl>' command from the Tcl console and retry this operation.\n"
        return 1
      }
      open_run impl_1 -name netlist_1
      send_msg_id Vivado-VCS_MX-028 INFO "Generarting simulation netlist '$net_file'"

      # write netlist/sdf
      # TODO: write_verilog is not taking cmd_args
      if { {functional} == $a_sim_vars(s_type) } {
        write_verilog -mode funcsim -force $net_file
      } elseif { {timing} == $a_sim_vars(s_type) } {
        write_verilog -mode timesim -force -sdf_file $sdf_file $net_file
      }
      if { {timing} == $a_sim_vars(s_type) } {
        send_msg_id Vivado-VCS_MX-029 INFO "Writing SDF file '$sdf_file'"
        write_sdf -mode timesim -force $sdf_file
      }

      set a_sim_vars(s_netlist_file) $net_file
    }
  }
  if { [file exist $net_file] } { send_msg_id Vivado-VCS_MX-030 INFO "Netlist generated:'$net_file'" }
  if { [file exist $sdf_file] } { send_msg_id Vivado-VCS_MX-031 INFO "SDF generated:'$sdf_file'" }
}

proc usf_get_compile_order_for_obj { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable s_data_files_filter
  variable s_non_hdl_data_files_filter
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [usf_is_ip $tcl_obj] } {
    send_msg_id Vivado-VCS_MX-032 INFO "Inspecting IP design source files for '$a_sim_vars(s_sim_top)'...\n"
    usf_get_sim_files_for_ip $tcl_obj

    # export ip data files to run dir
    if { [get_param "project.copyDataFilesForSim"] } {
      set ip_filter "FILE_TYPE == \"IP\""
      set ip_name [file tail $tcl_obj]
      set data_files [list]
      set data_files [concat $data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_data_files_filter]]
      # non-hdl data files 
      foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_non_hdl_data_files_filter] {
        if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
          if { [get_property {IS_USER_DISABLED} $file] } {
            continue;
          }
        }
        lappend data_files $file
      }
      usf_export_data_files $data_files
    }
  } elseif { [usf_is_fileset $tcl_obj] } {
    send_msg_id Vivado-VCS_MX-033 INFO "Inspecting design source files for '$a_sim_vars(s_sim_top)' in fileset '$tcl_obj'...\n"
    if {[usf_get_sim_files_for_fs $tcl_obj]} {
      return 1
    }
    # export all fileset data files to run dir
    if { [get_param "project.copyDataFilesForSim"] } {
      usf_export_fs_data_files $s_data_files_filter "false"
    }
    # export non-hdl data files to run dir
    usf_export_fs_data_files $s_non_hdl_data_files_filter "true"
  } else {
    send_msg_id Vivado-VCS_MX-034 INFO "Unsupported object source: $tcl_obj\n"
    return 1
  }
}

proc usf_uniquify_cmd_str { cmd_strs } {
  # Summary: Removes exact duplicate files (same file path)
  # Argument Usage:
  # Return Value:

  set cmd_str_set   [list]
  set uniq_cmd_strs [list]
  foreach str $cmd_strs {
    if { [lsearch -exact $cmd_str_set $str] == -1 } {
      lappend cmd_str_set $str
      lappend uniq_cmd_strs $str
    }
  }
  return $uniq_cmd_strs
}

proc usf_get_compile_order_libs { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compile_order_files
  set libs [list]
  foreach file $l_compile_order_files {
    if { [lsearch -exact [list_property [lindex [get_files -all $file] 0]] {LIBRARY}] == -1} {
      continue;
    }
    foreach f [get_files -all $file] {
      set library [get_property "LIBRARY" $f]
      if { [lsearch -exact $libs $library] == -1 } {
        lappend libs $library
      }
    }
  }
  return $libs
}

proc usf_get_include_file_dirs { { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set dir_names [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [usf_is_ip $tcl_obj] } {
    set vh_files [usf_get_incl_files_from_ip $tcl_obj]
  } else {
    set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"Verilog Header\""
    set vh_files [get_files -all -quiet -filter $filter]
  }
  foreach vh_file $vh_files {
    set dir [file normalize [file dirname $vh_file]]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[usf_resolve_file_path $dir]"
     } else {
       if { $ref_dir } {
        set dir "\$reference_dir/[usf_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
      }
    }
    lappend dir_names $dir
  }
  if {[llength $dir_names] > 0} {
    return [lsort -unique $dir_names]
  }
  return $dir_names
}

proc usf_get_top_library { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compile_order_files
  set flow    $a_sim_vars(s_simulation_flow)
  set tcl_obj $a_sim_vars(sp_tcl_obj)

  # was -of_objects <ip> specified?, fetch current fileset
  if { [usf_is_ip $tcl_obj] } {
    set tcl_obj [current_fileset -simset]
  }
  set top_library [get_property "DEFAULT_LIB" [current_project]]
  if { ({post_synth_sim} == $flow) || ({post_impl_sim} == $flow) } {
    # It isn't clear this is always appropriate, but it is at least consistent. Prior
    # to this there were cases where the post- netlist was being designated with the
    # default library, but the top_lib was being obtained from the _pSimSet, and these
    # didnt match. A better fix might be forcing the netlist into the _pSimSet top library.
    return $top_library
  }
  # get the library associated with the top file from the 'top_lib' property on the fileset
  set top_library [get_property "TOP_LIB" [get_filesets $tcl_obj]]
  if { {} == $top_library } {
    # fallback to fetching it from fileset source iterator (last non-disabled file)
    if { [llength $l_compile_order_files] > 0 } {
      set top_library [get_property "LIBRARY" [lindex [get_files -all [lindex $l_compile_order_files end]] 0]]
    }
    # If for some reason the associated library is empty, do not set (keep default),
    # so, set only if we have one set in the source and is not default.
    if { {} != $top_library } {
      return $top_library
    }
  }
  return $top_library
}

proc usf_contains_verilog {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_compile_order_files
  variable a_sim_vars
  set flow $a_sim_vars(s_simulation_flow)
  set b_verilog_srcs 0
  if { {behav_sim} == $flow } {
    foreach file $l_compile_order_files {
      set file_type [get_property "FILE_TYPE" [get_files -quiet -all $file]]
      if { {Verilog} == $file_type || {SystemVerilog} == $file_type } {
        set b_verilog_srcs 1
      }
    }
  } elseif { ({post_synth_sim} == $flow) || ({post_impl_sim} == $flow) } {
    set extn [file extension $a_sim_vars(s_netlist_file)]
    if { {.v} == $extn } {
      set b_verilog_srcs 1
    }
  }
  return $b_verilog_srcs
}

proc usf_is_fileset { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if {[regexp -nocase {^fileset_type} [rdi::get_attr_specs -quiet -object $tcl_obj -regexp .*FILESET_TYPE.*]]} {
    return 1
  }
  return 0
}

proc usf_append_define_generics { def_gen_list tool opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  foreach element $def_gen_list {
    set key_val_pair [split $element "="]
    set name [lindex $key_val_pair 0]
    set val  [lindex $key_val_pair 1]
    if { [string length $val] > 0 } {
      switch -regexp -- $tool {
        "vlog" { lappend opts_arg "-define"  ; lappend opts_arg "\"$name=$val\""  }
      }
    }
  }
}

proc usf_compile_glbl_file { simulator b_load_glbl } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fs_obj      [current_fileset -simset]
  set target_lang [get_property "TARGET_LANGUAGE" [current_project]]
  set flow        $a_sim_vars(s_simulation_flow)
  if { [usf_contains_verilog] } {
    return 1
  }
  # target lang is vhdl and glbl is added as top for post-implementation and post-synthesis and load glbl set (default)
  if { (({VHDL} == $target_lang) && (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && $b_load_glbl) } {
    return 1
  }
  switch $simulator {
    {ies} -
    {vcs_mx} {
      if { ({post_synth_sim} == $flow) || ({post_impl_sim} == $flow) } {
        return 1
      }
    }
  }
  return 0
}

proc usf_add_unisims { b_compile_unifast } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fs_obj       [get_filesets $::tclapp::xilinx::vcs_mx::a_sim_vars(s_simset)]
  set flow         $a_sim_vars(s_simulation_flow)
  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]
  if { {behav_sim} == $flow } {
    if { [usf_contains_verilog] } {
      if { ! $b_compile_unifast } {
        return 1
      }
    }
  } elseif { ({post_synth_sim} == $flow) || ({post_impl_sim} == $flow) } {
    if { [usf_contains_verilog] || ({Verilog} == $target_lang) } {
      if { {timesim} != $netlist_mode } {
        return 1
      }
    }
  }
  return 0
}

proc usf_add_simprims {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set flow         $a_sim_vars(s_simulation_flow)
  set fs_obj       [get_filesets $::tclapp::xilinx::vcs_mx::a_sim_vars(s_simset)]
  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]
  if { ({post_synth_sim} == $flow) || ({post_impl_sim} == $flow) } {
    if { [usf_contains_verilog] || ({Verilog} == $target_lang) } {
      if { {timesim} == $netlist_mode } {
        return 1
      }
    }
  }
  return 0
}

proc usf_add_unifast { b_compile_unifast } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set flow        $a_sim_vars(s_simulation_flow)
  set target_lang [get_property "TARGET_LANGUAGE" [current_project]]
  if { {behav_sim} == $flow } {
    if { [usf_contains_verilog] } {
      if { $b_compile_unifast } {
        return 1
      }
    }
  }
  return 0
}

proc usf_add_unimacro {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set flow        $a_sim_vars(s_simulation_flow)
  if { {behav_sim} == $flow } {
    if { [usf_contains_verilog] } {
      return 1
    }
  }
  return 0
}

proc usf_add_secureip {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  return 1
}

proc usf_get_glbl_file {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
  set glbl_file [file normalize [file join $data_dir "verilog/src/glbl.v"]]
  return $glbl_file
}

proc usf_create_do_file { simulator do_filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fs_obj [current_fileset -simset]
  set top $::tclapp::xilinx::vcs_mx::a_sim_vars(s_sim_top)
  set do_file [file join $a_sim_vars(s_launch_dir) $do_filename]
  set fh_do 0
  if {[catch {open $do_file w} fh_do]} {
    send_msg_id Vivado-VCS_MX-035 ERROR "failed to open file to write ($do_file)\n"
  } else {
    # generate saif file for power estimation
    set saif {}
    set uut [get_property "UNIT_UNDER_TEST" $fs_obj]
    switch -regexp -- $simulator {
      "ies" {
        set saif [get_property "IES.SIMULATE.SAIF" $fs_obj]
        if { {} != $saif } {
          if { {} == $uut } {
            set uut "/$top/uut/*"
          }
          puts $fh_do "dumpsaif -scope $uut -overwrite -output $saif"
        }
      }
      "vcs_mx" {
        set saif [get_property "VCS_MX.SIMULATE.SAIF" $fs_obj]
        if { {} != $saif } {
          if { {} == $uut } {
            set uut "$top.uut"
          }
          puts $fh_do "power $uut"
          puts $fh_do "power -enable"
        }
      }
    }
    set time [get_property "VCS_MX.SIMULATE.RUNTIME" $fs_obj]
    puts $fh_do "run $time"
    if { {} != $saif } {
      switch -regexp -- $simulator {
        "ies"    { puts $fh_do "dumpsaif -end" }
        "vcs_mx" {
          set timescale {1}
          if { {} == $uut } {
            set uut "$top.uut"
          }
          set module    $uut 
          puts $fh_do "power -disable"
          puts $fh_do "power -report $saif $timescale $module"
        }
      }
    }
    switch -regexp -- $simulator {
      "ies"    { puts $fh_do "exit" }
      "vcs_mx" { puts $fh_do "quit" }
    }
  }
  close $fh_do
}

proc usf_prepare_ip_for_simulation { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  #if { [regexp {^post_} $a_sim_vars(s_simulation_flow)] } {
  #  return
  #}
  variable a_sim_vars
  # list of block filesets and corresponding runs to launch
  set fs_objs        [list]
  set runs_to_launch [list]
  # target object (fileset or ip)
  set target_obj $a_sim_vars(sp_tcl_obj)
  if { [usf_is_fileset $target_obj] } {
    set fs $target_obj
    # add specified fileset (expected simulation fileset)
    lappend fs_objs $fs
    # add linked source fileset
    if { {SimulationSrcs} == [get_property "FILESET_TYPE" [get_filesets $fs]] } {
      set src_set [get_property "SOURCE_SET" [get_filesets $fs]]
      if { {} != $src_set } {
        lappend fs_objs $src_set
      }
    }
    # add block filesets
    set filter "FILESET_TYPE == \"BlockSrcs\""
    foreach blk_fs_obj [get_filesets -filter $filter] {
      lappend fs_objs $blk_fs_obj
    }
    set ip_filter "FILE_TYPE == \"IP\""
    foreach fs_obj $fs_objs {
      set fs_name [get_property "NAME" [get_filesets $fs_obj]]
      send_msg_id Vivado-VCS_MX-036 INFO "Inspecting fileset '$fs_name' for IP generation...\n"
      # get ip composite files
      foreach comp_file [get_files -quiet -of_objects [get_filesets $fs_obj] -filter $ip_filter] {
        usf_generate_comp_file_for_simulation $comp_file runs_to_launch
      }
    }
    # fileset contains embedded sources? generate mem files
    if { [usf_is_embedded_flow] } {
      send_msg_id Vivado-VCS_MX-037 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
      generate_mem_files $a_sim_vars(s_launch_dir)
    }
  } elseif { [usf_is_ip $target_obj] } {
    set comp_file $target_obj
    usf_generate_comp_file_for_simulation $comp_file runs_to_launch
  } else {
    send_msg_id Vivado-VCS_MX-038 ERROR "Unknown target '$target_obj'!\n"
  }
  # generate functional netlist  
  if { [llength $runs_to_launch] > 0 } {
    send_msg_id Vivado-VCS_MX-039 INFO "Launching block-fileset run '$runs_to_launch'...\n"
    launch_runs $runs_to_launch

    foreach run $runs_to_launch {
      wait_on_run [get_property "NAME" [get_runs $run]]
    }
  }
  # update compile order
  foreach fs $fs_objs {
    update_compile_order -fileset [get_filesets $fs]
  }
}

proc usf_set_simulator_path { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set bin_path  {}
  set tool_name {} 
  set path_sep  {;}
  set tool_extn {.exe}
  if {$::tcl_platform(platform) == "unix"} { set path_sep {:} }
  if {$::tcl_platform(platform) == "unix"} { set tool_extn {} }
  set install_path $a_sim_vars(s_install_path)
  send_msg_id Vivado-VCS_MX-040 INFO "Finding simulator installation...\n"
  switch -regexp -- $simulator {
    {vcs_mx} {
      set tool_name "vcs";append tool_name ${tool_extn}
      if { {} == $install_path } {
        set install_path [get_param "simulator.vcsmxInstallPath"]
      }
    }
 }
 
 if { {} == $install_path } {
   set bin_path [usf_get_bin_path $tool_name $path_sep]
   if { {} == $bin_path } {
     send_msg_id Vivado-VCS_MX-041 ERROR \
       "Failed to locate '$tool_name' executable in the shell environment 'PATH' variable. Please source the settings script included with the installation and retry this operation again.\n"
     # IMPORTANT - *** DONOT MODIFY THIS ***
     error "_SIM_STEP_RUN_EXEC_ERROR_"
     # IMPORTANT - *** DONOT MODIFY THIS ***
     return 1
   }
   send_msg_id Vivado-VCS_MX-042 INFO "Using simulator executables from '$bin_path'\n"
 } else {
   set install_path [file normalize [string map {\\ /} $install_path]]
   set install_path [string trimright $install_path {/}]
   set bin_path $install_path
   set tool_path [file join $install_path $tool_name]
   # Couldn't find it at install path, so try inserting /bin.
   # This is a bit roundabout with new variables so we don't change the
   # originals. If this doesn't work, we want the error messages to report
   # based on the originals.
   set tool_bin_path {}
   if { ![file exists $tool_path] } {
     set tool_bin_path [file join $install_path "bin" $tool_name]
     if { [file exists $tool_bin_path] } {
       set tool_path $tool_bin_path
       set bin_path [file join $install_path "bin"]
     }
   }
   if { [file exists $tool_path] && ![file isdirectory $tool_path] } {
     send_msg_id Vivado-VCS_MX-043 INFO "Using simulator executables from '$tool_path'\n"
   } else {
     send_msg_id Vivado-VCS_MX-044 ERROR "Path to custom '$tool_name' executable program does not exist:$tool_path'\n"
   }
 }
 set a_sim_vars(s_tool_bin_path) $bin_path
}

proc usf_get_files_for_compilation {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set files [list]
  set sim_flow      $a_sim_vars(s_simulation_flow)
  set netlist_file  $a_sim_vars(s_netlist_file)
  set target_obj    $a_sim_vars(sp_tcl_obj)
  set target_lang   [get_property "TARGET_LANGUAGE" [current_project]]
  set src_mgmt_mode [get_property "SOURCE_MGMT_MODE" [current_project]]
  # get global include file paths
  set incl_file_paths [list]
  set incl_files      [list]
  usf_get_global_include_files incl_file_paths incl_files
  set global_files [usf_get_global_include_file_cmdstr incl_files]

  # post-* simulation
  if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    #send_msg_id Vivado-VCS_MX-045 INFO "Adding netlist files:-\n"
    if { {} != $netlist_file } {
      set file_type "Verilog"
      set cmd_str [usf_get_file_cmd_str $netlist_file $file_type {}]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        #send_msg_id Vivado-VCS_MX-046 INFO " +$cmd_str\n"
      }
    }
 
    # add testbench files if any
    #send_msg_id Vivado-VCS_MX-047 INFO "Adding VHDL test bench files (post-synth/impl simulation):-\n"
    set vhdl_filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"VHDL\""
    foreach file [usf_get_testbench_files_from_ip $vhdl_filter] {
      if { [lsearch -exact [list_property $file] {FILE_TYPE}] == -1 } {
        continue;
      }
      #set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
      set file_type [get_property "FILE_TYPE" $file]
      set cmd_str [usf_get_file_cmd_str $file $file_type {}]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        #send_msg_id Vivado-VCS_MX-048 INFO " +$cmd_str\n"
      }
    }
    #set verilog_filter "USED_IN_TESTBENCH == 1 && FILE_TYPE == \"Verilog\" && FILE_TYPE == \"Verilog Header\""
    #send_msg_id Vivado-VCS_MX-049 INFO "Adding Verilog test bench files (post-synth/impl simulation):-\n"
    set verilog_filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"Verilog\""
    foreach file [usf_get_testbench_files_from_ip $verilog_filter] {
      if { [lsearch -exact [list_property $file] {FILE_TYPE}] == -1 } {
        continue;
      }
      #set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
      set file_type [get_property "FILE_TYPE" $file]
      set cmd_str [usf_get_file_cmd_str $file $file_type {}]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        #send_msg_id Vivado-VCS_MX-050 INFO " +$cmd_str\n"
      }
    }
  }
  # end post-* simulation

  # prepare command line args for fileset files
  if { [usf_is_fileset $target_obj] } {
    # behavioral simulation
    set b_add_sim_files 1
    if { ({behav_sim} == $sim_flow) } {

      # 1. add vhdl files from block-filesets
      #send_msg_id Vivado-VCS_MX-051 INFO "Adding block-fileset VHDL files (behav simulation):-\n"
      set vhdl_filter "FILE_TYPE == \"VHDL\""
      foreach file [usf_get_files_from_block_filesets $vhdl_filter] {
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
        set cmd_str [usf_get_file_cmd_str $file $file_type {}]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          #send_msg_id Vivado-VCS_MX-052 INFO " +$cmd_str\n"
        }
      }
      # 2. add verilog files from block-filesets
      #send_msg_id Vivado-VCS_MX-053 INFO "Adding block-fileset Verilog files (behav simulation):-\n"
      set verilog_filter "FILE_TYPE == \"Verilog\""
      foreach file [usf_get_files_from_block_filesets $verilog_filter] {
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
        set cmd_str [usf_get_file_cmd_str $file $file_type $global_files]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          #send_msg_id Vivado-VCS_MX-054 INFO " +$cmd_str\n"
        }
      }
 
      # 3. add files from simulation compile order
      if { {All} == $src_mgmt_mode } {
        #send_msg_id Vivado-VCS_MX-055 INFO "Adding compile order files (behav simulation):-\n"
        foreach file $::tclapp::xilinx::vcs_mx::l_compile_order_files {
          set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
          if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) } { continue }
          set g_files $global_files
          if { ({VHDL} == $file_type) } { set g_files {} }
          set cmd_str [usf_get_file_cmd_str $file $file_type $g_files]
          if { {} != $cmd_str } {
            lappend files $cmd_str
            #send_msg_id Vivado-VCS_MX-056 INFO " +$cmd_str\n"
          }
        }
        set b_add_sim_files 0
      } else {
        # 4. add files from SOURCE_SET property value
        # TODO
      }
    }
    if { $b_add_sim_files } {
      # 5. add additional files from simulation fileset
      #send_msg_id Vivado-VCS_MX-057 INFO "Adding additional simulation fileset files (behav simulation):-\n"
      foreach file [get_files -all -of_objects [current_fileset -simset]] {
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) } { continue }
        set g_files $global_files
        if { ({VHDL} == $file_type) } { set g_files {} }
        set cmd_str [usf_get_file_cmd_str $file $file_type $g_files]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          #send_msg_id Vivado-VCS_MX-058 INFO " +$cmd_str\n"
        }
      }
    }
  } elseif { [usf_is_ip $target_obj] } {
    # prepare command line args for fileset ip files
    #send_msg_id Vivado-VCS_MX-059 INFO "Adding IP compile order files:-\n"
    foreach file $::tclapp::xilinx::vcs_mx::l_compile_order_files {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) } { continue }
      set g_files $global_files
      if { ({VHDL} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type $g_files]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        #send_msg_id Vivado-VCS_MX-060 INFO " +$cmd_str\n"
      }
    }
  }
  # print all files fetched from filesets for simulation
  #foreach file $files {
  #  puts "CMD_STR=$file"
  #}
  return $files
}

proc usf_write_script_header_info { fh file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  set timestamp   [clock format [clock seconds]]
  set mode_type   $::tclapp::xilinx::vcs_mx::a_sim_vars(s_mode)
  set name        [file tail $file]

  puts $fh "######################################################################"
  puts $fh "#"
  puts $fh "# File name : $name"
  puts $fh "# Created on: $timestamp"
  puts $fh "#"
  puts $fh "# Auto generated by $product for '$mode_type' simulation"
  puts $fh "#"
  puts $fh "######################################################################"
}

proc usf_launch_script { simulator step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set run_dir $a_sim_vars(s_launch_dir)
  if { $a_sim_vars(b_scripts_only) } {
    send_msg_id Vivado-VCS_MX-061 INFO "Scripts generated."
    return 0
  }

  set b_wait 0
  if { $a_sim_vars(b_batch) } {
    set b_wait 1 
  }
  set extn [usf_get_script_extn]
  set scr_file ${step}$extn
  set faulty_run 0
  set cwd [pwd]
  cd $::tclapp::xilinx::vcs_mx::a_sim_vars(s_launch_dir)
  send_msg_id Vivado-VCS_MX-062 INFO "Executing '[string toupper $step]' step"
  switch $step {
    {compile} -
    {elaborate} {
      usf_make_file_executable $scr_file
      if {[catch {rdi::run_program $scr_file} error_log]} {
        send_msg_id Vivado-VCS_MX-063 ERROR "'$step' step failed with errors. Please check the Tcl console or log files for more information.\n"
        set faulty_run 1
      }
    }
    {simulate} {
      usf_make_file_executable $scr_file
      set retval 0
      set error_log {}
      if { $b_wait } {
        set retval [catch {rdi::run_program $scr_file} error_log]
      } else {
        set retval [catch {rdi::run_program -no_wait $scr_file} error_log]
      }
      if { $retval } {
        send_msg_id Vivado-VCS_MX-064 ERROR "failed to launch $scr_file:$error_log\n"
        set faulty_run 1
      }
    }
  }
  cd $cwd
  if { $faulty_run } {
    # IMPORTANT - *** DONOT MODIFY THIS ***
    error "_SIM_STEP_RUN_EXEC_ERROR_"
    # IMPORTANT - *** DONOT MODIFY THIS ***
    return 1
  }
  return 0
}

proc usf_write_shell_step_fn { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  puts $fh "ExecStep()"
  puts $fh "\{"
  puts $fh "\"\$@\""
  puts $fh "RETVAL=\$?"
  puts $fh "if \[ \$RETVAL -ne 0 \]"
  puts $fh "then"
  puts $fh "exit \$RETVAL"
  puts $fh "fi"
  puts $fh "\}"
}

proc usf_resolve_uut_name { uut_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $uut_arg uut
  set uut [string map {\\ /} $uut]]
  # prepend slash
  if { ![string match "/*" $uut] } {
    set uut "/$uut"
  }
  # append *
  if { [string match "*/" $uut] } {
    set uut "${uut}*"
  }
  # append /*
  if { ![string match "*/\*" $uut] } {
    set uut "${uut}/*"
  }
  return $uut
}

proc usf_print_args {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  puts "*******************************"
  puts "-simset         = $::tclapp::xilinx::vcs_mx::a_sim_vars(s_simset)"
  puts "-mode           = $::tclapp::xilinx::vcs_mx::a_sim_vars(s_mode)"
  puts "-type           = $::tclapp::xilinx::vcs_mx::a_sim_vars(s_type)"
  puts "-scripts_only   = $::tclapp::xilinx::vcs_mx::a_sim_vars(b_scripts_only)"
  puts "-of_objects     = $::tclapp::xilinx::vcs_mx::a_sim_vars(s_comp_file)"
  puts "-absolute_path  = $::tclapp::xilinx::vcs_mx::a_sim_vars(b_absolute_path)"
  puts "-install_path   = $::tclapp::xilinx::vcs_mx::a_sim_vars(s_install_path)"
  puts "-batch          = $::tclapp::xilinx::vcs_mx::a_sim_vars(b_batch)"
  puts "-int_os_type    = $::tclapp::xilinx::vcs_mx::a_sim_vars(s_int_os_type)"
  puts "-int_debug_mode = $::tclapp::xilinx::vcs_mx::a_sim_vars(s_int_debug_mode)"
  puts "*******************************"
}

proc usf_get_script_extn {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set scr_extn ".bat"
  if {$::tcl_platform(platform) == "unix"} {
    set scr_extn ".sh"
  }
  return $scr_extn
}

proc usf_get_platform {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  set platform {} 
  set os $::tcl_platform(platform)
  if { {windows}   == $os } { set platform "win32" }
  if { {windows64} == $os } { set platform "win64" }
  if { {unix} == $os } {
    if { {x86_64} == $::tcl_platform(machine) } {
      set platform "lin64"
    } else {
      set platform "lin32"
    }
  }
  return $platform
}

proc usf_is_axi_bfm_ip {} {
  # Summary: Finds VLNV property value for the IP and checks to see if the IP is AXI_BFM
  # Argument Usage:
  # Return Value:
  # true (1) if specified IP is axi_bfm, false (0) otherwise

  foreach ip [get_ips] {
    set ip_def [lindex [split [get_property "IPDEF" [get_ips $ip]] {:}] 2]
    set value [get_property "VLNV" [get_ipdefs -regexp .*${ip_def}.*]]
    if { [regexp -nocase {axi_bfm} $value] } {
      return 1
    }
  }
  return 0
}

proc usf_get_simulator_lib_for_bfm {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set simulator_lib {}
  set xil           $::env(XILINX)
  set path_sep      {;}
  set lib_extn      {.dll}
  set platform      [::tclapp::xilinx::vcs_mx::usf_get_platform]

  if {$::tcl_platform(platform) == "unix"} { set path_sep {:} }
  if {$::tcl_platform(platform) == "unix"} { set lib_extn {.so} }

  set lib_name "libxil_vcs";append lib_name $lib_extn
  if { {} != $xil } {
    set lib_path {}
    foreach path [split $xil $path_sep] {
      set file [file normalize [file join $path "lib" $platform $lib_name]]
      if { [file exists $file] } {
        set simulator_lib $file
        break
      }
    }
  } else {
    send_msg_id Vivado-VCS_MX-065 ERROR "Environment variable 'XILINX' is not set!"
  }
  return $simulator_lib
}
}

#
# Low level helper procs
# 
namespace eval ::tclapp::xilinx::vcs_mx {
proc usf_get_netlist_extn { warning } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars

  set extn {.v}
  set target_lang [get_property "TARGET_LANGUAGE" [current_project]]
  if { {VHDL} == $target_lang } {
    set extn {.vhdl}
  }

  if { ({VHDL} == $target_lang) && ({timing} == $a_sim_vars(s_type) || {functional} == $a_sim_vars(s_type)) } {
    set extn {.v}
    if { $warning } {
      send_msg_id Vivado-VCS_MX-066 INFO "The target language is set to VHDL, it is not supported for simulation type '$a_sim_vars(s_type)', using Verilog instead.\n"
    }
  }
  return $extn
}

proc usf_get_netlist_filename { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set filename $a_sim_vars(s_sim_top)
  switch -regexp -- $a_sim_vars(s_simulation_flow) {
    {behav_sim} { set filename [append filename "_behav"] }
    {post_synth_sim} -
    {post_impl_sim} {
      switch -regexp -- $a_sim_vars(s_type) {
        {functional} { set filename [append filename "_func"] }
        {timing} {set filename [append filename "_time"] }
      }
    }
  }
  switch -regexp -- $a_sim_vars(s_simulation_flow) {
    {post_synth_sim} { set filename [append filename "_synth"] }
    {post_impl_sim}  { set filename [append filename "_impl"] }
  }
  return $filename
}

proc usf_export_data_files { data_files } {
  # Summary: 
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set export_dir $a_sim_vars(s_launch_dir)
  if { [llength $data_files] > 0 } {
    set data_files [usf_remove_duplicate_files $data_files]
    # export now
    foreach file $data_files {
      if {[catch {file copy -force $file $export_dir} error_msg] } {
        send_msg_id Vivado-VCS_MX-067 WARNING "failed to copy file '$file' to '$export_dir' : $error_msg\n"
      } else {
        send_msg_id Vivado-VCS_MX-068 INFO "exported '$file'\n"
      }
    }
  }
}

proc usf_get_sim_files_for_fs { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compile_order_files
  set obj_name $tcl_obj
  set used_in_val "simulation"
  switch [get_property "FILESET_TYPE" [get_filesets $tcl_obj]] {
    "DesignSrcs"     { set used_in_val "synthesis" }
    "SimulationSrcs" { set used_in_val "simulation"}
    "BlockSrcs"      { set used_in_val "synthesis" }
  }
  switch -regexp -- $a_sim_vars(s_simulation_flow) {
    {behav_sim} {
      set l_compile_order_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $tcl_obj]]
      # remove duplicates?
      #set l_compile_order_files [usf_remove_duplicate_files $l_compile_order_files]
    }
    {post_synth_sim} -
    {post_impl_sim} {
      # simulation fileset files
      set simset_file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_filesets $tcl_obj]]
      lappend l_compile_order_files $simset_file

      # add test bench files from IP
      # TODO
    }
  }
  #puts "compile order:"
  #puts "**************"
  #foreach f $l_compile_order_files { puts $f }
  #puts "**************"
  return 0
}

proc usf_export_fs_data_files { filter b_check_for_user_disabled } {
  # Summary: Copy fileset IP data files to output directory
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fs_obj       [get_filesets $::tclapp::xilinx::vcs_mx::a_sim_vars(s_simset)]
  set data_files [list]
  # ip data files
  set ips [get_files -all -quiet -filter "FILE_TYPE == \"IP\""]
  foreach ip $ips {
    set ip_name [file tail $ip]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter] {
      if { $b_check_for_user_disabled } {
        if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
          if { [get_property {IS_USER_DISABLED} $file] } {
            continue;
          }
        }
      }
      lappend data_files $file
    }
  }
  set filesets [list]
  # block fileset data files
  lappend filesets [get_filesets -filter "FILESET_TYPE == \"BlockSrcs\""]
  # current source set fileset data files
  lappend filesets [current_fileset -srcset]
  # current simulation fileset data files
  lappend filesets [current_fileset -simset]
  # collect all fileset data files
  foreach fs_obj $filesets {
    foreach file [get_files -all -quiet -of_objects [get_filesets $fs_obj] -filter $filter] {
      lappend data_files $file
    }
  }
  usf_export_data_files $data_files
}

proc usf_get_sim_files_for_ip { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable s_data_files_filter
  variable l_compile_order_files
  set ip_filename [file tail $tcl_obj]
  set l_compile_order_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]]
  #foreach file $l_compile_order_files { puts "file=$file" }
  # remove duplicates?
  #set l_compile_order_files [usf_remove_duplicate_files $l_compile_order_files]
}

proc usf_get_files_from_block_filesets { filter_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set file_list [list]
  set filter "FILESET_TYPE == \"BlockSrcs\""
  set used_in_val "simulation"
  foreach fs_obj [get_filesets -filter $filter] {
    set fs_name [get_property "NAME" $fs_obj]
    send_msg_id Vivado-VCS_MX-069 INFO "Inspecting fileset '$fs_name' for '$filter_type' files...\n"
    #set files [usf_remove_duplicate_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fs_obj] -filter $filter_type]]
    set files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fs_obj] -filter $filter_type]
    if { [llength $files] == 0 } {
      send_msg_id Vivado-VCS_MX-070 INFO "No files found in '$fs_name'\n"
      continue
    } else {
      foreach file $files {
        lappend file_list $file
      }
    }
  }
  return $file_list
}

proc usf_remove_duplicate_files { compile_order_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set file_list [list]
  set compile_order [list]
  foreach file $compile_order_files {
    set normalized_file_path [file normalize [string map {\\ /} $file]]
    if { [lsearch -exact $file_list $normalized_file_path] == -1 } {
      lappend file_list $normalized_file_path
      lappend compile_order $file
    }
  }
  return $compile_order
}

proc usf_get_include_dirs { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set dir_names [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [usf_is_ip $tcl_obj] } {
    set incl_dir_str [usf_get_incl_dirs_from_ip $tcl_obj]
  } else {
    set incl_dir_str [get_property "INCLUDE_DIRS" [get_filesets $tcl_obj]]
  }
  set incl_dirs [split $incl_dir_str " "]
  foreach vh_dir $incl_dirs {
    set dir [file normalize $vh_dir]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[usf_resolve_file_path $dir]"
    } else {
      set dir "\$reference_dir/[usf_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
    }
    lappend dir_names $dir
  }
  return [lsort -unique $dir_names]
}

proc usf_get_verilog_header_paths {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set simset_obj     [get_filesets $a_sim_vars(s_simset)]
  set include_paths  [list]
  # 1. get paths for verilog header files (.vh, .h)
  usf_get_header_include_paths include_paths 
  # 2. add include dirs if any
  foreach dir [usf_get_include_dirs] {
    lappend include_paths $dir
  }
  # 3. uniquify paths (its quite possible that files marked with global include can be a "VERILOG_HEADER' as well collected in step 1)
  set final_unique_paths  [list]
  set incl_header_paths   [list]
  foreach path $include_paths {
    if { [lsearch -exact $final_unique_paths $path] == -1 } {
      lappend incl_header_paths $path
      lappend final_unique_paths $path
    }
  }
  return $incl_header_paths
}

proc usf_get_header_include_paths { incl_header_paths_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $incl_header_paths_arg incl_header_paths
  variable a_sim_vars
  set simset_obj     [get_filesets $a_sim_vars(s_simset)]
  set unique_paths   [list]
  set linked_src_set [get_property "SOURCE_SET" $simset_obj]
  if { {} != $linked_src_set } {
    set srcset_obj [get_filesets $linked_src_set]
    if { {} != $srcset_obj } {
      usf_add_unique_incl_paths $srcset_obj unique_paths incl_header_paths
    }
  }
  usf_add_unique_incl_paths $simset_obj unique_paths incl_header_paths
  # add paths from block filesets
  set filter "FILESET_TYPE == \"BlockSrcs\""
  foreach blk_fs_obj [get_filesets -filter $filter] {
    set fs_name [get_property "NAME" [get_filesets $blk_fs_obj]]
    usf_add_unique_incl_paths $blk_fs_obj unique_paths incl_header_paths
  }
}

proc usf_add_unique_incl_paths { fs_obj unique_paths_arg incl_header_paths_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $unique_paths_arg      unique_paths
  upvar $incl_header_paths_arg incl_header_paths

  # setup the filter to include only header types enabled for simulation
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"Verilog Header\""
  set vh_files [get_files -quiet -filter $filter]
  foreach file $vh_files {
    if { [get_property "IS_GLOBAL_INCLUDE" [get_files -quiet $file]] } {
      continue
    }
    set file_path [file normalize [string map {\\ /} [file dirname $file]]]
    if { [lsearch -exact $unique_paths $file_path] == -1 } {
      lappend incl_header_paths $file_path
      lappend unique_paths      $file_path
    }
  }
}

proc usf_get_global_include_files { incl_file_paths_arg incl_files_arg { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $incl_file_paths_arg incl_file_paths
  upvar $incl_files_arg      incl_files
  variable a_sim_vars
  set filesets       [list]
  set dir            $a_sim_vars(s_launch_dir)
  set simset_obj     [get_filesets $a_sim_vars(s_simset)]
  set linked_src_set [get_property "SOURCE_SET" $simset_obj]
  set incl_files_set [list]

  if { {} != $linked_src_set } {
    lappend filesets $linked_src_set
  }
  lappend filesets $simset_obj
  set filter "FILE_TYPE == \"Verilog\" || FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog Template\""
  foreach fs_obj $filesets {
    set vh_files [get_files -quiet -of_objects $fs_obj -filter $filter]
    foreach file $vh_files {
      if { ![get_property "IS_GLOBAL_INCLUDE" [get_files -quiet $file]] } {
        continue
      }
      set file [file normalize [string map {\\ /} $file]]
      if { [lsearch -exact $incl_files_set $file] == -1 } {
        lappend incl_files_set $file
        lappend incl_files     $file
        set incl_file_path [file normalize [string map {\\ /} [file dirname $file]]]
        if { $a_sim_vars(b_absolute_path) } {
          set incl_file_path "[usf_resolve_file_path $incl_file_path]"
        } else {
          if { $ref_dir } {
           set incl_file_path "\$reference_dir/[usf_get_relative_file_path $incl_file_path $dir]"
          }
        }
        lappend incl_file_paths $incl_file_path
      }
    }
  }
}

proc usf_get_incl_files_from_ip { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set incl_files [list]
  set ip_name [file tail $tcl_obj]
  set filter "FILE_TYPE == \"Verilog Header\""
  set vh_files [get_files -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    if { $a_sim_vars(b_absolute_path) } {
      set file "[usf_resolve_file_path $file]"
    } else {
      set file "\$reference_dir/[usf_get_relative_file_path $file $a_sim_vars(s_launch_dir)]"
    }
    lappend incl_files $file
  }
  return $incl_files
}

proc usf_get_incl_dirs_from_ip { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set ip_name [file tail $tcl_obj]
  set incl_dirs [list]
  set filter "FILE_TYPE == \"Verilog Header\""
  set vh_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    set dir [file dirname $file]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[usf_resolve_file_path $dir]"
    } else {
      set dir "\$reference_dir/[usf_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
    }
    lappend incl_dirs $dir
  }
  return $incl_dirs
}

proc usf_get_relative_file_path { file_path_to_convert relative_to } {
  # Summary: Get the relative path wrt to path specified
  # Argument Usage:
  # file_path_to_convert: input file to make relative to specfied path
  # Return Value:
  # Relative path wrt the path specified

  variable a_sim_vars
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
  # compare each dir element of file_to_convert and relative_to, set the flag and
  # get the final index till these sub-dirs matched
  while { [lindex $file_comps $index] == [lindex $relative_to_comps $index] } {
    if { !$found_match } { set found_match true }
    incr index
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

proc usf_resolve_file_path { file_dir_path_to_convert } {
  # Summary: Make file path relative to reference_dir if relative component found
  # Argument Usage:
  # file_dir_path_to_convert: input file to make relative to specfied path
  # Return Value:
  # Relative path wrt the path specified

  variable a_sim_vars
  set ref_dir [file normalize [string map {\\ /} $a_sim_vars(s_launch_dir)]]
  set ref_comps [lrange [split $ref_dir "/"] 1 end]
  set file_comps [lrange [split [file normalize [string map {\\ /} $file_dir_path_to_convert]] "/"] 1 end]
  set index 1
  while { [lindex $ref_comps $index] == [lindex $file_comps $index] } {
    incr index
  }
  # is file path within reference dir? return relative path
  if { $index == [llength $ref_comps] } {
    return [usf_get_relative_file_path $file_dir_path_to_convert $ref_dir]
  }
  # return absolute
  return $file_dir_path_to_convert
}

proc usf_is_ip { tcl_obj } {
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

proc usf_is_embedded_flow {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable s_embedded_files_filter
  set embedded_files [get_files -all -quiet -filter $s_embedded_files_filter]
  if { [llength $embedded_files] > 0 } {
    return 1
  }
  return 0
}

proc usf_get_compiler_name { file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set compiler ""
  if { {VHDL} == $file_type } {
    set compiler "vhdlan"
  } elseif { ({Verilog} == $file_type) || ({SystemVerilog} == $file_type) || ({Verilog Header} == $file_type) } {
    set compiler "vlogan"
  }
  return $compiler
}

proc usf_append_compiler_options { tool file_type opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  variable a_sim_vars
  set fs_obj [current_fileset -simset]
  switch $tool {
    "vhdlan" {
      lappend opts "\$${tool}_opts"
    }
    "vlogan" {
      lappend opts "\$${tool}_opts"
      if { [string equal -nocase $file_type "verilog"] } {
        lappend opts "+v2k"
      } elseif { [string equal -nocase $file_type "systemverilog"] } {
        lappend opts "-sverilog"
        lappend opts "-Xcheck_p1800_2009=char"
      }
    }
  }
  # append verilog defines, include dirs and include file dirs
  switch $tool {
    "vlogan" {
      # verilog defines
      if { [usf_is_fileset $a_sim_vars(sp_tcl_obj)] } {
        set verilog_defines [list]
        set verilog_defines [get_property "VERILOG_DEFINE" [get_filesets $a_sim_vars(sp_tcl_obj)]]
        if { [llength $verilog_defines] > 0 } {
          usf_append_define_generics $verilog_defines $tool opts
        }
      }
      # include dirs
      foreach dir [concat [usf_get_include_dirs] [usf_get_include_file_dirs]] {
        #lappend opts "+incdir+\"$dir\""
        lappend opts "+incdir+$dir"
      }
    }
  }
}

proc usf_append_other_options { tool file_type opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  variable a_sim_vars
  set dir $a_sim_vars(s_launch_dir)
  set fs_obj [current_fileset -simset]
}

proc usf_make_file_executable { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if {$::tcl_platform(platform) == "unix"} {
    if {[catch {exec chmod a+x $file} error_msg] } {
      send_msg_id Vivado-VCS_MX-071 WARNING "failed to change file permissions to executable ($file): $error_msg\n"
    }
  } else {
    if {[catch {exec attrib /D -R $file} error_msg] } {
      send_msg_id Vivado-VCS_MX-072 WARNING "failed to change file permissions to executable ($file): $error_msg\n"
    }
  }
}

proc usf_generate_comp_file_for_simulation { comp_file runs_to_launch_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $runs_to_launch_arg runs_to_launch
  set ts [get_property "SIMULATOR_LANGUAGE" [current_project]]
  set ip_filename [file tail $comp_file]
  set ip_name     [file root $ip_filename]
  # - does the ip support behavioral language?,
  #   -- if yes, then generate simulation products (if not generated by ip earlier)
  #   -- if not, then does ip synth checkpoint set?,
  #       --- if yes, then generate all products (if not generated by ip earlier)
  #       --- if not, then error with recommendation
  # and also generate the IP netlist
  if { [get_property "IS_IP_BEHAV_LANG_SUPPORTED" $comp_file] } {
    # does ip generated simulation products? if not, generate them
    if { ![get_property "IS_IP_GENERATED_SIM" $comp_file] } {
      send_msg_id Vivado-XSim-071 INFO "Generating simulation products for IP '$ip_name'...\n"
      generate_target {simulation} [get_files $comp_file] -force
    } else {
      send_msg_id Vivado-XSim-074 INFO "IP '$ip_name' is upto date for simulation\n"
    }
  } elseif { [get_property "GENERATE_SYNTH_CHECKPOINT" $comp_file] } {
    # make sure ip is up-to-date
    if { ![get_property "IS_IP_GENERATED" $comp_file] } {
      generate_target {all} [get_files $comp_file] -force
      send_msg_id Vivado-XSim-077 INFO "Generating functional netlist for IP '$ip_name'...\n"
      usf_generate_ip_netlist $comp_file runs_to_launch
    } else {
      send_msg_id Vivado-XSim-078 INFO "IP '$ip_name' is upto date for all products\n"
    }
  } else {
    # at this point, ip doesnot support behavioral language and synth check point is false, so advise
    # users to select synthesized checkpoint option or set the "generate_synth_checkpoint' ip property.
    set simulator_lang [get_property "SIMULATOR_LANGUAGE" [current_project]]
    set error_msg "IP contains simulation files that do not support the current Simulation Language: '$simulator_lang'.\n"
    if { [get_property "IS_IP_SYNTH_TARGET_SUPPORTED" $comp_file] } {
      append error_msg "Resolution:-\n"
      append error_msg "1)\n"
      append error_msg "or\n2) Select the option Generate Synthesized Checkpoint (.dcp) in the Generate Output Products dialog\
                        to automatically create a matching simulation netlist, or set the 'GENERATE_SYNTH_CHECKPOINT' property on the core."
    } else {
      # no synthesis, so no recommendation to do a synth checkpoint.
    }
    send_msg_id Vivado-XSim-079 WARNING "$error_msg\n"
    #return 1
  }
}

proc usf_generate_ip_netlist { comp_file runs_to_launch_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $runs_to_launch_arg runs_to_launch
  set comp_file_obj [get_files $comp_file]
  set comp_file_fs  [get_property "FILESET_NAME" $comp_file_obj]
  if { ![get_property "GENERATE_SYNTH_CHECKPOINT" $comp_file_obj] } {
    send_msg_id Vivado-VCS_MX-083 INFO "Generate synth checkpoint is 'false':$comp_file\n"
    # if synth checkpoint read-only, return
    if { [get_property "IS_IP_SYNTH_CHECKPOINT_READONLY" $comp_file_obj] } {
      send_msg_id Vivado-VCS_MX-084 WARNING "Synth checkpoint property is 'readonly' ... skipping:$comp_file\n"
      return
    }
    # set property to create a DCP/structural simulation file
    send_msg_id Vivado-VCS_MX-085 INFO "Setting synth checkpoint for generating simulation netlist:$comp_file\n"
    set_property "GENERATE_SYNTH_CHECKPOINT" true $comp_file_obj
  } else {
    send_msg_id Vivado-VCS_MX-086 INFO "Generate synth checkpoint is set:$comp_file\n"
  }
  # block fileset name is based on the basename of the IP
  set src_file [file normalize $comp_file]
  set ip_basename [file root [file tail $src_file]]
  # block-fileset may not be created at this point, so quiet if not found
  set block_fs_obj [get_filesets -quiet $ip_basename]
  # "block fileset" exists? if not create it
  if { {} == $block_fs_obj } {
    create_fileset -blockset "$ip_basename"
    set block_fs_obj [get_filesets $ip_basename]
    send_msg_id Vivado-VCS_MX-087 INFO "Block-fileset created:$block_fs_obj"
    # set fileset top
    set comp_file_top [get_property "IP_TOP" $comp_file_obj]
    set_property "TOP" $comp_file_top [get_filesets $ip_basename]
    # move sub-design to block-fileset
    send_msg_id Vivado-VCS_MX-088 INFO "Moving ip composite source(s) to '$ip_basename' fileset"
    move_files -fileset [get_fileset $ip_basename] [get_files -of_objects [get_filesets $comp_file_fs] $src_file] 
  }
  if { {BlockSrcs} != [get_property "FILESET_TYPE" $block_fs_obj] } {
    send_msg_id Vivado-VCS_MX-089 ERROR "Given source file is not associated with a design source fileset.\n"
    return 1
  }
  # construct block-fileset run for the netlist
  set run_name $ip_basename;append run_name "_synth_1"
  if { ![get_property "IS_INITIALIZED" [get_runs $run_name]] } {
    reset_run $run_name
  }
  lappend runs_to_launch $run_name
  send_msg_id Vivado-VCS_MX-090 INFO "Run scheduled for '$ip_basename':$run_name\n"
}

proc usf_get_testbench_files_from_ip { file_type_filter } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set tb_filelist [list]
  set ip_filter "FILE_TYPE == \"IP\""
  foreach ip [get_files -all -quiet -filter $ip_filter] {
    set ip_name [file tail $ip]
    set tb_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $file_type_filter]
    if { [llength $tb_files] > 0 } {
      foreach tb $tb_files {
        set tb_file_obj [lindex [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] $tb] 0]
        if { {simulation testbench} == [get_property "USED_IN" $tb_file_obj] } {
          lappend tb_filelist $tb
        }
      }
    }
  }
  return $tb_filelist
}

proc usf_get_bin_path { tool_name path_sep } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set path_value $::env(PATH)
  set bin_path {}
  foreach path [split $path_value $path_sep] {
    set exe_file [file normalize [file join $path $tool_name]]
    if { [file exists $exe_file] } {
      set bin_path $path
      break
    }
  }
  return $bin_path
}

proc usf_get_global_include_file_cmdstr { incl_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $incl_files_arg incl_files
  variable a_sim_vars
  set file_str [list]
  foreach file $incl_files {
    lappend file_str "\"$file\""
  }
  return [join $file_str " "]
}

proc usf_get_file_cmd_str { file file_type global_files} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set dir             $a_sim_vars(s_launch_dir)
  set b_absolute_path $a_sim_vars(b_absolute_path)
  set cmd_str {}
  set associated_library [get_property "DEFAULT_LIB" [current_project]]
  set file_obj [lindex [get_files -quiet -all $file] 0]
  if { {} != $file_obj } {
    if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
      set associated_library [get_property "LIBRARY" $file_obj]
    }
  }
  if { $a_sim_vars(b_absolute_path) } {
    set file "[usf_resolve_file_path $file]"
  } else {
    set file "[usf_get_relative_file_path $file $dir]"
  }
  set compiler [usf_get_compiler_name $file_type]
  if { [string length $compiler] > 0 } {
    set arg_list [list $compiler]
    usf_append_compiler_options $compiler $file_type arg_list
    if { [string equal -nocase $associated_library "work"] } {
      set arg_list [linsert $arg_list end "$global_files" "\"$file\""]
    } else {
      set arg_list [linsert $arg_list end "-work $associated_library" "$global_files" "\"$file\""]
    }
  }
  usf_append_other_options $compiler $file_type arg_list
  set file_str [join $arg_list " "]
  set type [usf_get_file_type_category $file_type]
  set cmd_str "$type#$associated_library#$file_str"
  return $cmd_str
}

proc usf_get_file_type_category { file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set type {VHDL}
  switch $file_type {
    {Verilog} -
    {SystemVerilog} -
    {Verilog Header} {
      set type {VERILOG}
    }
  }
  return $type
}

proc usf_get_netlist_writer_cmd_args { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fs_obj                 [get_filesets $a_sim_vars(s_simset)]
  set nl_cell                [get_property "NL.CELL" $fs_obj]
  set nl_mode                [get_property "NL.MODE" $fs_obj]
  set nl_nolib               [get_property "NL.NOLIB" $fs_obj]
  set nl_write_all_overrides [get_property "NL.WRITE_ALL_OVERRIDES" $fs_obj]
  set nl_rename_top          [get_property "NL.RENAME_TOP" $fs_obj]
  set nl_sdf_anno            [get_property "NL.SDF_ANNO" $fs_obj]
  set nl_process_corner      [get_property "NL.PROCESS_CORNER" $fs_obj]
  set nl_incl_unisim_models  [get_property "NL.INCL_UNISIM_MODELS" $fs_obj]
  set ng_sdf_path            [get_property "NG.SDF_PATH" $fs_obj]
  set args [list]
  if { {} != $nl_cell } {
    lappend args "-cell";lappend args $nl_cell
  }
  lappend args "-mode";lappend args $nl_mode
  if { $nl_nolib } {
    lappend "-nolib"
  }
  if { $nl_write_all_overrides } {
    lappend args "-write_all_overrides"
  }
  if { {} != $nl_rename_top } {
    if { {.v} == $extn } {
      lappend "-rename_top_module";lappend args $nl_rename_top
    } elseif { {.vhd} == $extn } {
      lappend "-rename_top_entity";lappend args $nl_rename_top
    }
  }
  if { $nl_sdf_anno && ({timing} == $a_sim_vars(s_type)) } {
    lappend args "-sdf_anno"
  }
  if { {} != $ng_sdf_path } {
    lappend args "-sdf_path";lappend args $ng_sdf_path 
  }
  if { $nl_incl_unisim_models } { lappend args "-include_unisim" }
  lappend args "-force"
  set cmd_args [join $args " "]
  return $cmd_args
}

proc usf_get_sdf_writer_cmd_args { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fs_obj                 [get_filesets $a_sim_vars(s_simset)]
  set nl_cell                [get_property "NL.CELL" $fs_obj]
  set nl_mode                [get_property "NL.MODE" $fs_obj]
  set nl_rename_top          [get_property "NL.RENAME_TOP" $fs_obj]
  set nl_process_corner      [get_property "NL.PROCESS_CORNER" $fs_obj]
  set args [list]
  if { {} != $nl_cell } {
    lappend args "-cell";lappend args $nl_cell
  }
  lappend args "-mode";lappend args $nl_mode
  lappend args "-process_corner";lappend args $nl_process_corner
  if { {} != $nl_rename_top } {
    lappend "-rename_top_module";lappend args $nl_rename_top
  }
  lappend args "-force"
  set cmd_args [join $args " "]
  return $cmd_args
}

}

#
# not used currently
#
namespace eval ::tclapp::xilinx::vcs_mx {
proc usf_get_top { top_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $top_arg top
  set fs_obj [current_fileset -srcset]
  set fs_name [get_property "NAME" $fs_obj]
  set top [get_property "TOP" $fs_obj]
  if { {} == $top } {
    send_msg_id Vivado-VCS_MX-091 ERROR "Top module not set for fileset '$fs_name'. Please ensure that a valid \
       value is provided for 'top'. The value for 'top' can be set/changed using the 'Top Module Name' field under\
       'Project Settings', or using the 'set_property top' Tcl command (e.g. set_property top <name> \[current_fileset\])."
    return 1
  }
  return 0
}
}

package provide ::tclapp::xilinx::vcs_mx::helpers 1.0
