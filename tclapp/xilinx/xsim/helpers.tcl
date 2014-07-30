######################################################################
#
# helpers.tcl (simulation helper utilities for the 'Vivado Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
######################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::xsim {
  # do not export procs from this file
}

namespace eval ::tclapp::xilinx::xsim {
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

  # hdl file extension types
  variable l_valid_hdl_extns          [list]
  set l_valid_hdl_extns               [list ".vhd" ".vhdl" ".vhf" ".vho" ".v" ".vf" ".verilog" ".vr" ".vg" ".vb" ".tf" ".vlog" ".vp" ".vm" ".vh" ".h" ".svh" ".sv" ".veo"]
 
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
                FILE_TYPE != \"Waveform Configuration File\"  && \
                FILE_TYPE != \"BMM\"                          && \
                FILE_TYPE != \"ELF\""

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

    set prop_name [string tolower $prop_name]

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
      create_property -name "${prop_name}" -type $type -description $desc -enum_values $e_values -default_value $e_default -class fileset -no_register
    } elseif { {file} == $type } {
      set f_extns   [lindex $row 4]
      set f_desc    [lindex $row 5]
      # create file property
      set v_default $value
      create_property -name "${prop_name}" -type $type -description $desc -default_value $v_default -file_types $f_extns -display_text $f_desc -class fileset -no_register
    } else {
      set v_default $value
      create_property -name "${prop_name}" -type $type -description $desc -default_value $v_default -class fileset -no_register
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

    # is registered already?
    if { [usf_is_option_registered_on_simulator $prop_name $simulator] } {
      continue;
    }

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

  set str_1 [string tolower $prop_name]
  # get registered options from simulator for the current simset
  foreach option_name [get_property "REGISTERED_OPTIONS" [get_simulators $simulator]] {
    set str_2 [string tolower $option_name]
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
      send_msg_id USF-XSim-023 ERROR "Invalid simulation type '$a_sim_vars(s_type)' specified. Please see 'simulate -help' for more details.\n"
      return 1
    }
    set simulation_flow "behav_sim"
    set a_sim_vars(s_flow_dir_key) "behav"

    # set simulation and netlist mode on simset
    set_property sim_mode "behavioral" $fs_obj

  } elseif { {post-synthesis} == $a_sim_vars(s_mode) } {
    if { ({functional} != $a_sim_vars(s_type)) && ({timing} != $a_sim_vars(s_type)) } {
      send_msg_id USF-XSim-024 ERROR "Invalid simulation type '$a_sim_vars(s_type)' specified. Please see 'simulate -help' for more details.\n"
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
      send_msg_id USF-XSim-025 ERROR "Invalid simulation type '$a_sim_vars(s_type)' specified. Please see 'simulate -help' for more details.\n"
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
    send_msg_id USF-XSim-026 ERROR "Invalid simulation mode '$a_sim_vars(s_mode)' specified. Please see 'simulate -help' for more details.\n"
    return 1
  }
  set a_sim_vars(s_simulation_flow) $simulation_flow
  return 0
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
    set a_sim_vars(s_sim_top) [file root [file tail $a_sim_vars(sp_tcl_obj)]]
  } else {
    set a_sim_vars(sp_tcl_obj) [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]
    # set current simset
    if { {} == $a_sim_vars(sp_tcl_obj) } {
      set a_sim_vars(sp_tcl_obj) [current_fileset -simset]
    }
    set a_sim_vars(s_sim_top) [get_property TOP [get_filesets $a_sim_vars(sp_tcl_obj)]]
  }
  send_msg_id USF-XSim-027 INFO "Simulation object is '$a_sim_vars(sp_tcl_obj)'\n"
  return 0
}

proc usf_set_ref_dir { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  # setup source dir var
  puts $fh "# Directory path for design sources and include directories (if any) wrt this path"
  if { $a_sim_vars(b_absolute_path) } {
    if {$::tcl_platform(platform) == "unix"} {
      puts $fh "origin_dir=\"$a_sim_vars(s_launch_dir)\""
    } else {
      puts $fh "set origin_dir=\"$a_sim_vars(s_launch_dir)\""
    }
  } else {
    if {$::tcl_platform(platform) == "unix"} {
      puts $fh "origin_dir=\".\""
    } else {
      puts $fh "set origin_dir=\".\""
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
  set net_filename     [usf_get_netlist_filename];append net_filename "$extn"
  set sdf_filename     [usf_get_netlist_filename];append sdf_filename ".sdf"
  set net_file         [file normalize [file join $a_sim_vars(s_launch_dir) $net_filename]]
  set sdf_file         [file normalize [file join $a_sim_vars(s_launch_dir) $sdf_filename]]
  set netlist_cmd_args [usf_get_netlist_writer_cmd_args $extn]
  set sdf_cmd_args     [usf_get_sdf_writer_cmd_args]
  set design_mode      [get_property DESIGN_MODE [current_fileset]]

  # check run results status
  switch -regexp -- $a_sim_vars(s_simulation_flow) {
    {post_synth_sim} {
      if { {RTL} == $design_mode } {
        if { [get_param "project.checkRunResultsForUnifiedSim"] } {
          set synth_run [current_run -synthesis]
          set status [get_property "STATUS" $synth_run]
          if { ([regexp -nocase {^synth_design complete} $status] != 1) } {
            send_msg_id USF-XSim-028 ERROR \
               "Synthesis results not available! Please run 'Synthesis' from the GUI or execute 'launch_runs <synth>' command from the Tcl console and retry this operation.\n"
            return 1
          }
        }
      }

      if { {RTL} == $design_mode } {
        set synth_run [current_run -synthesis]
        if { [catch {open_run $synth_run -name netlist_1} open_err] } {
          #send_msg_id USF-XSim-028 WARNING "open_run failed:$open_err"
        }
      } elseif { {GateLvl} == $design_mode } {
        link_design -name netlist_1
      } else {
        send_msg_id USF-XSim-028 ERROR "Unsupported design mode found while opening the design for netlist generation!\n"
        return 1
      }

      send_msg_id USF-XSim-029 INFO "Writing simulation netlist file..."
      # write netlist/sdf
      set wv_args "-nolib $netlist_cmd_args -file $net_file"
      if { {functional} == $a_sim_vars(s_type) } {
        set wv_args "-mode funcsim $wv_args"
      } elseif { {timing} == $a_sim_vars(s_type) } {
        set wv_args "-mode timesim $wv_args"
      }
      if { {.v} == $extn } {
        send_msg_id USF-XSim-090 INFO "write_verilog $wv_args"
        eval "write_verilog $wv_args"
      } else {
        send_msg_id USF-XSim-090 INFO "write_vhdl $wv_args"
        eval "write_vhdl $wv_args"
      }
      if { {timing} == $a_sim_vars(s_type) } {
        send_msg_id USF-XSim-030 INFO "Writing SDF file..."
        set ws_args "-mode timesim $sdf_cmd_args -file $sdf_file"
        send_msg_id USF-XSim-091 INFO "write_sdf $ws_args"
        eval "write_sdf $ws_args"
      }
      set a_sim_vars(s_netlist_file) $net_file
    }
    {post_impl_sim} {
      set impl_run [current_run -implementation]
      if { [get_param "project.checkRunResultsForUnifiedSim"] } {
        if { ![get_property can_open_results $impl_run] } {
          send_msg_id USF-XSim-031 ERROR \
             "Implementation results not available! Please run 'Implementation' from the GUI or execute 'launch_runs <impl>' command from the Tcl console and retry this operation.\n"
          return 1
        }
      }

      if { [catch {open_run $impl_run -name netlist_1} open_error] } {
        #send_msg_id USF-XSim-028 WARNING "open_run failed:$open_err"
      }
      send_msg_id USF-XSim-032 INFO "Writing simulation netlist file..."

      # write netlist/sdf
      set wv_args "-nolib $netlist_cmd_args -file $net_file"
      if { {functional} == $a_sim_vars(s_type) } {
        set wv_args "-mode funcsim $wv_args"
      } elseif { {timing} == $a_sim_vars(s_type) } {
        set wv_args "-mode timesim $wv_args"
      }
      if { {.v} == $extn } {
        send_msg_id USF-XSim-092 INFO "write_verilog $wv_args"
        eval "write_verilog $wv_args"
      } else {
        send_msg_id USF-XSim-092 INFO "write_vhdl $wv_args"
        eval "write_vhdl $wv_args"
      }
      if { {timing} == $a_sim_vars(s_type) } {
        send_msg_id USF-XSim-033 INFO "Writing SDF file..."
        set ws_args "-mode timesim $sdf_cmd_args -file $sdf_file"
        send_msg_id USF-XSim-093 INFO "write_sdf $ws_args"
        eval "write_sdf $ws_args"
      }

      set a_sim_vars(s_netlist_file) $net_file
    }
  }
  if { [file exist $net_file] } { send_msg_id USF-XSim-034 INFO "Netlist generated:$net_file" }
  if { [file exist $sdf_file] } { send_msg_id USF-XSim-035 INFO "SDF generated:$sdf_file" }
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
    send_msg_id USF-XSim-036 INFO "Inspecting IP design source files for '$a_sim_vars(s_sim_top)'...\n"
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
    send_msg_id USF-XSim-037 INFO "Inspecting design source files for '$a_sim_vars(s_sim_top)' in fileset '$tcl_obj'...\n"
    if {[usf_get_sim_files_for_fs $tcl_obj]} {
      return 1
    }
    # export all fileset data files to run dir
    if { [get_param "project.copyDataFilesForSim"] } {
      usf_export_fs_data_files $s_data_files_filter
    }
    # export non-hdl data files to run dir
    usf_export_fs_non_hdl_data_files
  } else {
    send_msg_id USF-XSim-038 INFO "Unsupported object source: $tcl_obj\n"
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

proc usf_get_include_file_dirs { global_files_str { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set dir_names [list]
  set vh_files [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [usf_is_ip $tcl_obj] } {
    set vh_files [usf_get_incl_files_from_ip $tcl_obj]
  } else {
    set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"Verilog Header\""
    set vh_files [get_files -all -quiet -filter $filter]
  }

  # append global files (if any)
  if { {} != $global_files_str } {
    set global_files [split $global_files_str { }]
    foreach g_file $global_files {
      set g_file [string trim $g_file {\"}]
      lappend vh_files [get_files -quiet -all $g_file]
    }
  }

  foreach vh_file $vh_files {
    set dir [file normalize [file dirname $vh_file]]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[usf_resolve_file_path $dir]"
     } else {
       if { $ref_dir } {
        set dir "\$origin_dir/[usf_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
      } else {
        set dir "[usf_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
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
    set tcl_obj [get_filesets $a_sim_vars(s_simset)]
  }

  # get the default top library set for the project
  set default_top_library [get_property "DEFAULT_LIB" [current_project]]

  # get the library associated with the top file from the 'top_lib' property on the fileset
  set fs_top_library [get_property "TOP_LIB" [get_filesets $tcl_obj]]
  # post* simulation flow
  if { ({post_synth_sim} == $flow) || ({post_impl_sim} == $flow) } {
    # It isn't clear this is always appropriate, but it is at least consistent. Prior
    # to this there were cases where the post- netlist was being designated with the
    # default library, but the top_lib was being obtained from the _pSimSet, and these
    # didnt match. A better fix might be forcing the netlist into the _pSimSet top library.
    if { {} != $default_top_library } {
      return $default_top_library
    } elseif { {} != $fs_top_library } {
      return $fs_top_library
    } else {
      return "xil_defaultlib"
    }
  }

  # behavioral simulation

  # fetch top library from compile order
  set co_top_library {}
  if { [llength $l_compile_order_files] > 0 } {
    set co_top_library [get_property "LIBRARY" [lindex [get_files -all [lindex $l_compile_order_files end]] 0]]
  }
  # make sure default or fileset top library matches with the library from compile order, if not, then return the compile order library
  if { {} != $default_top_library } {
    if { ({} != $co_top_library) && ($default_top_library != $co_top_library) } {
      return $co_top_library
    } else {
      return $default_top_library
    }
  } elseif { {} != $fs_top_library } {
    if { ({} != $co_top_library) && ($fs_top_library != $co_top_library) } {
      return $co_top_library
    } else {
      return $fs_top_library
    }
  }

  return "xil_defaultlib"
}

proc usf_contains_verilog { design_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_compile_order_files
  variable a_sim_vars

  set flow $a_sim_vars(s_simulation_flow)

  set b_verilog_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {#}] 0]
    switch $type {
      {VERILOG} {
        set b_verilog_srcs 1
      }
    }
  }

  if { (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && (!$b_verilog_srcs) } {
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

proc usf_compile_glbl_file { simulator b_load_glbl design_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fs_obj      [get_filesets $a_sim_vars(s_simset)]
  set target_lang [get_property "TARGET_LANGUAGE" [current_project]]
  set flow        $a_sim_vars(s_simulation_flow)
  if { [usf_contains_verilog $design_files] } {
    return 1
  }
  # target lang is vhdl and glbl is added as top for post-implementation and post-synthesis and load glbl set (default)
  if { (({VHDL} == $target_lang) && (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && $b_load_glbl) } {
    return 1
  }
  return 0
}

proc usf_copy_glbl_file {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set run_dir $a_sim_vars(s_launch_dir)

  set target_glbl_file [file normalize [file join $run_dir "glbl.v"]]
  if { [file exists $target_glbl_file] } {
    return
  }

  set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
  set src_glbl_file [file normalize [file join $data_dir "verilog/src/glbl.v"]]

  if {[catch {file copy -force $src_glbl_file $run_dir} error_msg] } {
    send_msg_id USF-XSim-094 WARNING "Failed to copy glbl file '$src_glbl_file' to '$run_dir' : $error_msg\n"
  }
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
      send_msg_id USF-XSim-040 INFO "Inspecting fileset '$fs_name' for IP generation...\n"
      # get ip composite files
      foreach comp_file [get_files -quiet -of_objects [get_filesets $fs_obj] -filter $ip_filter] {
        usf_generate_comp_file_for_simulation $comp_file runs_to_launch
      }
    }
    # fileset contains embedded sources? generate mem files
    if { [usf_is_embedded_flow] } {
      send_msg_id USF-XSim-041 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
      generate_mem_files $a_sim_vars(s_launch_dir)
    }
  } elseif { [usf_is_ip $target_obj] } {
    set comp_file $target_obj
    usf_generate_comp_file_for_simulation $comp_file runs_to_launch
  } else {
    send_msg_id USF-XSim-042 ERROR "Unknown target '$target_obj'!\n"
  }
  # generate functional netlist  
  if { [llength $runs_to_launch] > 0 } {
    send_msg_id USF-XSim-043 INFO "Launching block-fileset run '$runs_to_launch'...\n"
    launch_runs $runs_to_launch

    foreach run $runs_to_launch {
      wait_on_run [get_property "NAME" [get_runs $run]]
    }
  }
  # update compile order
  if { {None} != [get_property "SOURCE_MGMT_MODE" [current_project]] } {
    foreach fs $fs_objs {
      if { [usf_fs_contains_hdl_source $fs] } {
        update_compile_order -fileset [get_filesets $fs]
      }
    }
  }
}

proc usf_generate_mem_files_for_simulation { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { [usf_is_fileset $a_sim_vars(sp_tcl_obj)] } {
    # fileset contains embedded sources? generate mem files
    if { [usf_is_embedded_flow] } {
      send_msg_id USF-XSim-096 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
      generate_mem_files $a_sim_vars(s_launch_dir)
    }
  }
}

proc usf_fs_contains_hdl_source { fs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_valid_ip_extns
  variable l_valid_hdl_extns

  set b_contains_hdl 0
  set tokens [split [find_top -fileset $fs -return_file_paths] { }]
  for {set i 0} {$i < [llength $tokens]} {incr i} {
    set top [string trim [lindex $tokens $i]];incr i
    set file [string trim [lindex $tokens $i]]
    if { ({} == $top) || ({} == $file) } { continue; }
    set extn [file extension $file]

    # skip ip's
    if { [lsearch -exact $l_valid_ip_extns $extn] >= 0 } { continue; }

    # check if any HDL sources present in fileset
    if { [lsearch -exact $l_valid_hdl_extns $extn] >= 0 } {
      set b_contains_hdl 1
      break
    }
  }
  return $b_contains_hdl
}

proc usf_get_files_for_compilation { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $global_files_str_arg global_files_str

  set sim_flow $a_sim_vars(s_simulation_flow)
 
  if { ({behav_sim} == $sim_flow) } {
    usf_get_files_for_compilation_behav_sim $global_files_str
  } elseif { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    usf_get_files_for_compilation_post_sim $global_files_str
  }
}

proc usf_get_files_for_compilation_behav_sim { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $global_files_str_arg global_files_str

  set files          [list]
  set target_obj     $a_sim_vars(sp_tcl_obj)
  set simset_obj     [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]
  set linked_src_set [get_property "SOURCE_SET" $simset_obj]
  set target_lang    [get_property "TARGET_LANGUAGE" [current_project]]
  set src_mgmt_mode  [get_property "SOURCE_MGMT_MODE" [current_project]]

  # get global include file paths
  set incl_file_paths [list]
  set incl_files      [list]
  usf_get_global_include_files incl_file_paths incl_files

  set global_incl_files $incl_files
  set global_files_str [usf_get_global_include_file_cmdstr incl_files]

  # prepare command line args for fileset files
  if { [usf_is_fileset $target_obj] } {
    set b_add_sim_files 1
    # add files from block filesets
    if { {} != $linked_src_set } {
      usf_add_block_fs_files $global_files_str files
    }
    # add files from simulation compile order
    if { {All} == $src_mgmt_mode } {
      foreach file $::tclapp::xilinx::xsim::l_compile_order_files {
        if { [usf_is_global_include_file $global_files_str $file] } { continue }
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) } { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) } { set g_files {} }
        set cmd_str [usf_get_file_cmd_str $file $file_type $g_files]
        if { {} != $cmd_str } {
          lappend files $cmd_str
        }
      }
      set b_add_sim_files 0
    } else {
      # add files from SOURCE_SET property value
      if { {} != $linked_src_set } {
        set srcset_obj [get_filesets $linked_src_set]
        if { {} != $srcset_obj } {
          set used_in_val "simulation"
          set ::tclapp::xilinx::xsim::l_compile_order_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $srcset_obj]]
          foreach file $::tclapp::xilinx::xsim::l_compile_order_files {
            set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
            if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) } { continue }
            set g_files $global_files_str
            if { ({VHDL} == $file_type) } { set g_files {} }
            set cmd_str [usf_get_file_cmd_str $file $file_type $g_files]
            if { {} != $cmd_str } {
              lappend files $cmd_str
            }
          }
        }
      }
    }

    if { $b_add_sim_files } {
      # add additional files from simulation fileset
      foreach file [get_files -quiet -all -of_objects [get_filesets $a_sim_vars(s_simset)]] {
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) } { continue }
        if { [get_property "IS_AUTO_DISABLED" [lindex [get_files -quiet -all $file] 0]]} { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) } { set g_files {} }
        set cmd_str [usf_get_file_cmd_str $file $file_type $g_files]
        if { {} != $cmd_str } {
          lappend files $cmd_str
        }
      }
    }
  } elseif { [usf_is_ip $target_obj] } {
    # prepare command line args for fileset ip files
    foreach file $::tclapp::xilinx::xsim::l_compile_order_files {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type $g_files]
      if { {} != $cmd_str } {
        lappend files $cmd_str
      }
    }
  }
  return $files
}

proc usf_get_files_for_compilation_post_sim { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $global_files_str_arg global_files_str

  set files         [list]
  set netlist_file  $a_sim_vars(s_netlist_file)
  set target_obj    $a_sim_vars(sp_tcl_obj)
  set target_lang   [get_property "TARGET_LANGUAGE" [current_project]]
  set src_mgmt_mode [get_property "SOURCE_MGMT_MODE" [current_project]]

  # get global include file paths
  set incl_file_paths [list]
  set incl_files      [list]
  usf_get_global_include_files incl_file_paths incl_files

  set global_incl_files $incl_files
  set global_files_str [usf_get_global_include_file_cmdstr incl_files]

  if { {} != $netlist_file } {
    set file_type "Verilog"
    if { {.vhd} == [file extension $netlist_file] } {
      set file_type "VHDL"
    }
    set cmd_str [usf_get_file_cmd_str $netlist_file $file_type {}]
    if { {} != $cmd_str } {
      lappend files $cmd_str
    }
  }
 
  # add testbench files if any
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
    }
  }
  #set verilog_filter "USED_IN_TESTBENCH == 1 && FILE_TYPE == \"Verilog\" && FILE_TYPE == \"Verilog Header\""
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
    }
  }

  # prepare command line args for fileset files
  if { [usf_is_fileset $target_obj] } {
    # add additional files from simulation fileset
    foreach file [get_files -quiet -all -of_objects [get_filesets $a_sim_vars(s_simset)]] {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) } { continue }
      if { [get_property "IS_AUTO_DISABLED" [lindex [get_files -quiet -all $file] 0]]} { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type $g_files]
      if { {} != $cmd_str } {
        lappend files $cmd_str
      }
    }
  } elseif { [usf_is_ip $target_obj] } {
    # prepare command line args for fileset ip files
    foreach file $::tclapp::xilinx::xsim::l_compile_order_files {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type $g_files]
      if { {} != $cmd_str } {
        lappend files $cmd_str
      }
    }
  }
  return $files
}

proc usf_add_block_fs_files { global_files_str files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $files_arg files

  set vhdl_filter "FILE_TYPE == \"VHDL\""
  foreach file [usf_get_files_from_block_filesets $vhdl_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
    set cmd_str [usf_get_file_cmd_str $file $file_type {}]
    if { {} != $cmd_str } {
      lappend files $cmd_str
    }
  }
  set verilog_filter "FILE_TYPE == \"Verilog\""
  foreach file [usf_get_files_from_block_filesets $verilog_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all $file] 0]]
    set cmd_str [usf_get_file_cmd_str $file $file_type $global_files_str]
    if { {} != $cmd_str } {
      lappend files $cmd_str
    }
  }
}

proc usf_is_global_include_file { global_files_str file_to_find } {
  # Summary:
  # Argument Usage:
  # Return Value:

  foreach g_file [split $global_files_str { }] {
    set g_file [string trim $g_file {\"}]
    if { [string compare $g_file $file_to_find] == 0 } {
      return true
    }
  }
  return false
}

proc usf_launch_script { simulator step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set extn [usf_get_script_extn]
  set scr_file ${step}$extn
  set run_dir $a_sim_vars(s_launch_dir)

  set shell_script_file [file normalize [file join $run_dir $scr_file]]
  usf_make_file_executable $shell_script_file

  if { $a_sim_vars(b_scripts_only) } {
    send_msg_id USF-XSim-060 INFO "Script generated:[file normalize [file join $run_dir $scr_file]]"
    return 0
  }
 
  if { {simulate} == $step } {
    return 0
  }

  set b_wait 0
  if { $a_sim_vars(b_batch) } {
    set b_wait 1 
  }
  set faulty_run 0
  set cwd [pwd]
  cd $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)
  send_msg_id USF-XSim-061 INFO "Executing '[string toupper $step]' step"
  switch $step {
    {compile} -
    {elaborate} {
      if {[catch {rdi::run_program $scr_file} error_log] || [usf_check_errors $step]} {
        send_msg_id USF-XSim-062 ERROR "'$step' step failed with errors. Please check the Tcl console or log files for more information.\n"
        set faulty_run 1
      }
    }
    {simulate} {
      set retval 0
      set error_log {}
      if { $b_wait } {
        set retval [catch {rdi::run_program $scr_file} error_log]
      } else {
        set retval [catch {rdi::run_program -no_wait $scr_file} error_log]
      }
      if { $retval } {
        send_msg_id USF-XSim-063 ERROR "Failed to launch $scr_file:$error_log\n"
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

proc usf_check_errors { step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # TODO
  return 0

  switch $step {
    {compile} {
      # errors in xvlog?
      set token "xvlog"
      if { [usf_found_errors_in_file $token] } { return 1 }
      # errors in xvhdl?
      set token "xvhdl"
      if { [usf_found_errors_in_file $token] } { return 1 }
    }
    {elaborate} {
      # errors in xelab?
      set token "xelab"
      if { [usf_found_errors_in_file $token] } { return 1 }
    }
  }
  return 0
}

proc usf_found_errors_in_file { token } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set fh 0
  set file ${token}.log
  if {[file exists $file]} {
    if {[catch {open $file r} fh]} {
      send_msg_id USF-XSIM-095 ERROR "Failed to open file to read ($file)\n"
      return 1
    }
  } else {
    return 0
  }
  set data [read $fh]
  close $fh

  set log_data [split $data "\n"]
  foreach line $log_data {
    set line_str [string trim $line]
    switch $token {
      {xvlog} { if { [regexp {^foo} $line_str] } { return 1 } }
      {xvhdl} { if { [regexp {^foo} $line_str] } { return 1 } }
      {xelab} { if { [regexp {^foo} $line_str] } { return 1 } }
    }
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
  set uut [string map {\\ /} $uut]
  # prepend slash
  if { ![string match "/*" $uut] } {
    set uut "/$uut"
  }
  # append *
  if { [string match "*/" $uut] } {
    set uut "${uut}*"
  }
  # append /*
  if { {/*} != [string range $uut end-1 end] } {
    set uut "${uut}/*"
  }
  return $uut
}

proc usf_print_args {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  puts "*******************************"
  puts "-simset         = $::tclapp::xilinx::xsim::a_sim_vars(s_simset)"
  puts "-mode           = $::tclapp::xilinx::xsim::a_sim_vars(s_mode)"
  puts "-type           = $::tclapp::xilinx::xsim::a_sim_vars(s_type)"
  puts "-scripts_only   = $::tclapp::xilinx::xsim::a_sim_vars(b_scripts_only)"
  puts "-of_objects     = $::tclapp::xilinx::xsim::a_sim_vars(s_comp_file)"
  puts "-absolute_path  = $::tclapp::xilinx::xsim::a_sim_vars(b_absolute_path)"
  puts "-install_path   = $::tclapp::xilinx::xsim::a_sim_vars(s_install_path)"
  puts "-batch          = $::tclapp::xilinx::xsim::a_sim_vars(b_batch)"
  puts "-run_dir        = $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)"
  puts "-int_os_type    = $::tclapp::xilinx::xsim::a_sim_vars(s_int_os_type)"
  puts "-int_debug_mode = $::tclapp::xilinx::xsim::a_sim_vars(s_int_debug_mode)"
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
}

#
# Low level helper procs
# 
namespace eval ::tclapp::xilinx::xsim {
proc usf_get_netlist_extn { warning } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars

  set extn {.v}
  set target_lang [get_property "TARGET_LANGUAGE" [current_project]]
  if { {VHDL} == $target_lang } {
    set extn {.vhd}
  }

  if { (({VHDL} == $target_lang) && ({timing} == $a_sim_vars(s_type))) } {
    set extn {.v}
    if { $warning } {
      send_msg_id USF-XSim-064 INFO "The target language is set to VHDL, it is not supported for simulation type '$a_sim_vars(s_type)', using Verilog instead.\n"
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
        send_msg_id USF-XSim-065 WARNING "Failed to copy file '$file' to '$export_dir' : $error_msg\n"
      } else {
        send_msg_id USF-XSim-066 INFO "Exported '$file'\n"
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

proc usf_export_fs_data_files { filter } {
  # Summary: Copy fileset IP data files to output directory
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fs_obj [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]
  set data_files [list]
  # ip data files
  set ips [get_files -all -quiet -filter "FILE_TYPE == \"IP\""]
  foreach ip $ips {
    set ip_name [file tail $ip]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter] {
      lappend data_files $file
    }
  }
  set filesets [list]

  # block fileset data files
  lappend filesets [get_filesets -filter "FILESET_TYPE == \"BlockSrcs\""]

  # current source set fileset data files
  lappend filesets [current_fileset -srcset]

  # current simulation fileset data files
  lappend filesets [get_filesets $a_sim_vars(s_simset)]

  # collect all fileset data files
  foreach fs_obj $filesets {
    foreach file [get_files -all -quiet -of_objects [get_filesets $fs_obj] -filter $filter] {
      lappend data_files $file
    }
  }
  usf_export_data_files $data_files
}

proc usf_export_fs_non_hdl_data_files {} {
  # Summary: Copy fileset IP data files to output directory
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable s_non_hdl_data_files_filter

  set fs_obj [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]
  set data_files [list]
  foreach file [get_files -all -quiet -of_objects [get_filesets $fs_obj] -filter $s_non_hdl_data_files_filter] {
    # skip user disabled (if the file supports is_user_disabled property
    if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
      if { [get_property {IS_USER_DISABLED} $file] } {
        continue;
      }
    }
    lappend data_files $file
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
    send_msg_id USF-XSim-067 INFO "Inspecting fileset '$fs_name' for '$filter_type' files...\n"
    #set files [usf_remove_duplicate_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fs_obj] -filter $filter_type]]
    set files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fs_obj] -filter $filter_type]
    if { [llength $files] == 0 } {
      send_msg_id USF-XSim-068 INFO "No files found in '$fs_name'\n"
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
  set incl_dir_str {}  
  if { [usf_is_ip $tcl_obj] } {
    set incl_dir_str [usf_get_incl_dirs_from_ip $tcl_obj]
    set incl_dirs [split $incl_dir_str " "]
  } else {
    set incl_dir_str [usf_resolve_incl_dir_property_value [get_property "INCLUDE_DIRS" [get_filesets $tcl_obj]]]
    set incl_dirs [split $incl_dir_str "#"]
  }

  foreach vh_dir $incl_dirs {
    set dir [file normalize $vh_dir]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[usf_resolve_file_path $dir]"
    } else {
      set dir "\$origin_dir/[usf_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
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
    if { [get_property "IS_GLOBAL_INCLUDE" [lindex [get_files -quiet $file] 0]] } {
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
  # Summary: find source files marked as global include
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
    set vh_files [get_files -quiet -of_objects [get_filesets $fs_obj] -filter $filter]
    foreach file $vh_files {
      if { ![get_property "IS_GLOBAL_INCLUDE" [lindex [get_files -quiet $file] 0]] } {
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
           set incl_file_path "\$origin_dir/[usf_get_relative_file_path $incl_file_path $dir]"
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
      set file "\$origin_dir/[usf_get_relative_file_path $file $a_sim_vars(s_launch_dir)]"
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
      set dir "\$origin_dir/[usf_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
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

proc usf_resolve_file_path { file_dir_path_to_convert } {
  # Summary: Make file path relative to origin_dir if relative component found
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
    set compiler "vhdl"
  } elseif { ({Verilog} == $file_type) || ({SystemVerilog} == $file_type) || ({Verilog Header} == $file_type) } {
    if { ({SystemVerilog} == $file_type) } {
      set compiler "sv"
    } else {
      set compiler "verilog"
    }
  }
  return $compiler
}

proc usf_append_compiler_options { tool file_type opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  variable a_sim_vars
  set fs_obj [get_filesets $a_sim_vars(s_simset)] 
  switch $tool {
    "vhdl" {
      #lappend opts "\$${tool}_opts"
    }
    "verilog" {
      #lappend opts "\$${tool}_opts"
    }
  }
}

proc usf_append_other_options { tool file_type global_files_str opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  variable a_sim_vars
  set dir $a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $a_sim_vars(s_simset)]

  switch $tool {
    "verilog" -
    "sv" {
      # include_dirs
      set unique_incl_dirs [list]
      set incl_dir_str [usf_resolve_incl_dir_property_value [get_property "INCLUDE_DIRS" [get_filesets $fs_obj]]]
      foreach incl_dir [split $incl_dir_str "#"] {
        if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
          lappend unique_incl_dirs $incl_dir
          if { $a_sim_vars(b_absolute_path) } {
            set incl_dir "[usf_resolve_file_path $incl_dir]"
          } else {
            set incl_dir "[usf_get_relative_file_path $incl_dir $dir]"
          }
          lappend opts "-i \"$incl_dir\""
        }
      }
      # --include
      set prefix_ref_dir "false"
      foreach incl_dir [usf_get_include_file_dirs $global_files_str $prefix_ref_dir] {
        set incl_dir [string map {\\ /} $incl_dir]
        lappend opts "--include \"$incl_dir\""
      }
      # -d (verilog macros)
      set v_defines [get_property "VERILOG_DEFINE" $fs_obj]
      if { [llength $v_defines] > 0 } {
        foreach element $v_defines {
          set key_val_pair [split $element "="]
          set name [lindex $key_val_pair 0]
          set val  [lindex $key_val_pair 1]
          if { [string length $val] > 0 } {
            set str "\"$name=$val\""
            lappend opts "-d $str"
          }
        }
      }
    }
  }
}

proc usf_make_file_executable { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if {$::tcl_platform(platform) == "unix"} {
    if {[catch {exec chmod a+x $file} error_msg] } {
      send_msg_id USF-XSim-069 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
    }
  } else {
    if {[catch {exec attrib /D -R $file} error_msg] } {
      send_msg_id USF-XSim-070 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
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
      send_msg_id USF-XSim-071 INFO "Generating simulation products for IP '$ip_name'...\n"
      set delivered_targets [get_property delivered_targets [get_ips -quiet ${ip_name}]]
      if { [regexp -nocase {simulation} $delivered_targets] } {
        generate_target {simulation} [get_files $comp_file] -force
      }
    } else {
      send_msg_id USF-XSim-074 INFO "IP '$ip_name' is upto date for simulation\n"
    }
  } elseif { [get_property "GENERATE_SYNTH_CHECKPOINT" $comp_file] } {
    # make sure ip is up-to-date
    if { ![get_property "IS_IP_GENERATED" $comp_file] } { 
      generate_target {all} [get_files $comp_file] -force
      send_msg_id USF-XSim-077 INFO "Generating functional netlist for IP '$ip_name'...\n"
      usf_generate_ip_netlist $comp_file runs_to_launch
    } else {
      send_msg_id USF-XSim-078 INFO "IP '$ip_name' is upto date for all products\n"
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
    send_msg_id USF-XSim-079 WARNING "$error_msg\n"
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
    send_msg_id USF-XSim-081 INFO "Generate synth checkpoint is 'false':$comp_file\n"
    # if synth checkpoint read-only, return
    if { [get_property "IS_IP_SYNTH_CHECKPOINT_READONLY" $comp_file_obj] } {
      send_msg_id USF-XSim-082 WARNING "Synth checkpoint property is 'readonly' ... skipping:$comp_file\n"
      return
    }
    # set property to create a DCP/structural simulation file
    send_msg_id USF-XSim-083 INFO "Setting synth checkpoint for generating simulation netlist:$comp_file\n"
    set_property "GENERATE_SYNTH_CHECKPOINT" true $comp_file_obj
  } else {
    send_msg_id USF-XSim-084 INFO "Generate synth checkpoint is set:$comp_file\n"
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
    send_msg_id USF-XSim-085 INFO "Block-fileset created:$block_fs_obj"
    # set fileset top
    set comp_file_top [get_property "IP_TOP" $comp_file_obj]
    set_property "TOP" $comp_file_top [get_filesets $ip_basename]
    # move sub-design to block-fileset
    send_msg_id USF-XSim-086 INFO "Moving ip composite source(s) to '$ip_basename' fileset"
    move_files -fileset [get_fileset $ip_basename] [get_files -of_objects [get_filesets $comp_file_fs] $src_file] 
  }
  if { {BlockSrcs} != [get_property "FILESET_TYPE" $block_fs_obj] } {
    send_msg_id USF-XSim-087 ERROR "Given source file is not associated with a design source fileset.\n"
    return 1
  }
  # construct block-fileset run for the netlist
  set run_name $ip_basename;append run_name "_synth_1"
  if { ![get_property "IS_INITIALIZED" [get_runs $run_name]] } {
    reset_run $run_name
  }
  lappend runs_to_launch $run_name
  send_msg_id USF-XSim-088 INFO "Run scheduled for '$ip_basename':$run_name\n"
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

proc usf_get_file_cmd_str { file file_type global_files_str} {
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
    set arg_list [linsert $arg_list end "$associated_library" "$global_files_str" "\"$file\""]
  }
  usf_append_other_options $compiler $file_type $global_files_str arg_list
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

proc usf_get_netlist_writer_cmd_args { extn } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fs_obj                 [get_filesets $a_sim_vars(s_simset)]
  set nl_cell                [get_property "NL.CELL" $fs_obj]
  set nl_incl_unisim_models  [get_property "NL.INCL_UNISIM_MODELS" $fs_obj]
  set nl_rename_top          [get_property "NL.RENAME_TOP" $fs_obj]
  set nl_sdf_anno            [get_property "NL.SDF_ANNO" $fs_obj]
  set nl_write_all_overrides [get_property "NL.WRITE_ALL_OVERRIDES" $fs_obj]
  set args                   [list]

  if { {} != $nl_cell }          { lappend args "-cell";lappend args $nl_cell }
  if { $nl_write_all_overrides } { lappend args "-write_all_overrides" }

  if { {} != $nl_rename_top } {
    if { {.v} == $extn } {
      lappend args "-rename_top";lappend args $nl_rename_top
    } elseif { {.vhd} == $extn } {
      lappend args "-rename_top";lappend args $nl_rename_top
    }
  }

  if { ({timing} == $a_sim_vars(s_type)) } {
    if { $nl_sdf_anno } {
      lappend args "-sdf_anno true"
    } else {
      lappend args "-sdf_anno false"
    }
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
  set fs_obj            [get_filesets $a_sim_vars(s_simset)]
  set nl_cell           [get_property "NL.CELL" $fs_obj]
  set nl_rename_top     [get_property "NL.RENAME_TOP" $fs_obj]
  set nl_process_corner [get_property "NL.PROCESS_CORNER" $fs_obj]
  set args              [list]

  if { {} != $nl_cell } {lappend args "-cell";lappend args $nl_cell}
  lappend args "-process_corner";lappend args $nl_process_corner
  if { {} != $nl_rename_top } {lappend "-rename_top_module";lappend args $nl_rename_top}
  lappend args "-force"
  set cmd_args [join $args " "]
  return $cmd_args
}

proc usf_get_rdi_bin_path {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set rdi_path $::env(RDI_BINROOT)
  set rdi_path [string map {/ \\\\} $rdi_path]
  return $rdi_path
}

proc usf_resolve_incl_dir_property_value { incl_dirs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set resolved_path {}
  set incl_dirs [string map {\\ /} $incl_dirs]
  set path_elem {} 
  set comps [split $incl_dirs { }]
  foreach elem $comps {
    # path element starts slash (/)? or drive (c:/)?
    if { [string match "/*" $elem] || [regexp {^[a-zA-Z]:} $elem] } {
      if { {} != $path_elem } {
        # previous path is complete now, add hash and append to resolved path string
        set path_elem "$path_elem#"
        append resolved_path $path_elem
      }
      # setup new path
      set path_elem "$elem"
    } else {
      # sub-dir with space, append to current path
      set path_elem "$path_elem $elem"
    }
  }
  append resolved_path $path_elem

  return $resolved_path
}

proc usf_find_files { src_files_arg filter } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $src_files_arg src_files

  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [usf_is_ip $tcl_obj] } {
    set ip_name [file tail $tcl_obj]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter] {
      if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
        if { [get_property {IS_USER_DISABLED} $file] } {
          continue;
        }
      }
      set file [file normalize $file]
      if { $a_sim_vars(b_absolute_path) } {
        set file "[usf_resolve_file_path $file]"
      } else {
        set file "[usf_get_relative_file_path $file $a_sim_vars(s_launch_dir)]"
      }
      lappend src_files $file
    }
  } elseif { [usf_is_fileset $tcl_obj] } {
    set filesets       [list]
    set simset_obj     [get_filesets $a_sim_vars(s_simset)]

    lappend filesets $simset_obj
    set linked_src_set [get_property "SOURCE_SET" $simset_obj]
    if { {} != $linked_src_set } {
      lappend filesets $linked_src_set
    }

    # add block filesets
    set blk_filter "FILESET_TYPE == \"BlockSrcs\""
    foreach blk_fs_obj [get_filesets -filter $blk_filter] {
      lappend filesets $blk_fs_obj
    }

    foreach fs_obj $filesets {
      foreach file [get_files -quiet -of_objects [get_filesets $fs_obj] -filter $filter] {
        if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
          if { [get_property {IS_USER_DISABLED} $file] } {
            continue;
          }
        }
        set file [file normalize $file]
        if { $a_sim_vars(b_absolute_path) } {
          set file "[usf_resolve_file_path $file]"
        } else {
          set file "[usf_get_relative_file_path $file $a_sim_vars(s_launch_dir)]"
        }
        lappend src_files $file
      }
    }
  }
}
}

#
# not used currently
#
namespace eval ::tclapp::xilinx::xsim {
proc usf_get_top { top_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $top_arg top
  set fs_obj [get_filesets $a_sim_vars(s_simset)]
  set fs_name [get_property "NAME" $fs_obj]
  set top [get_property "TOP" $fs_obj]
  if { {} == $top } {
    send_msg_id USF-XSim-089 ERROR "Top module not set for fileset '$fs_name'. Please ensure that a valid \
       value is provided for 'top'. The value for 'top' can be set/changed using the 'Top Module Name' field under\
       'Project Settings', or using the 'set_property top' Tcl command (e.g. set_property top <name> \[current_fileset\])."
    return 1
  }
  return 0
}
}
