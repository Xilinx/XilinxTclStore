###############################################################################
#
# helpers.tcl (simulation helper utilities for the 'Synopsys VCS Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
###############################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::vcs {
  namespace export usf_create_options
}

namespace eval ::tclapp::xilinx::vcs {
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
  set a_sim_vars(s_lib_map_path)     {}
  set a_sim_vars(b_batch)            0
  set a_sim_vars(s_int_os_type)      {}
  set a_sim_vars(s_int_debug_mode)   0

  set a_sim_vars(dynamic_repo_dir)   [get_property ip.user_files_dir [current_project]]
  set a_sim_vars(ipstatic_dir)       [get_property sim.ipstatic.source_dir [current_project]]
  set a_sim_vars(b_use_static_lib)   [get_property sim.ipstatic.use_precompiled_libs [current_project]]

  set a_sim_vars(s_tool_bin_path)    {}

  set a_sim_vars(sp_tcl_obj)         {}
  set a_sim_vars(b_extract_ip_sim_files) 0

  # fileset compile order
  variable l_compile_order_files     [list]
  variable l_design_files            [list]

  # ip static libraries
  variable l_ip_static_libs          [list]

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
                FILE_TYPE != \"VHDL 2008\"                    && \
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

  if { ![get_property IS_READONLY [current_project]] } {
    # simulation fileset objects
    foreach fs_obj [get_filesets -filter {FILESET_TYPE == SimulationSrcs}] {
      usf_set_fs_options $fs_obj $simulator $opts
    }
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
      send_msg_id USF-VCS-019 ERROR "Invalid simulation type '$a_sim_vars(s_type)' specified. Please see 'simulate -help' for more details.\n"
      return 1
    }
    set simulation_flow "behav_sim"
    set a_sim_vars(s_flow_dir_key) "behav"

    # set simulation and netlist mode on simset
    set_property sim_mode "behavioral" $fs_obj

  } elseif { {post-synthesis} == $a_sim_vars(s_mode) } {
    if { ({functional} != $a_sim_vars(s_type)) && ({timing} != $a_sim_vars(s_type)) } {
      send_msg_id USF-VCS-020 ERROR "Invalid simulation type '$a_sim_vars(s_type)' specified. Please see 'simulate -help' for more details.\n"
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
      send_msg_id USF-VCS-021 ERROR "Invalid simulation type '$a_sim_vars(s_type)' specified. Please see 'simulate -help' for more details.\n"
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
    send_msg_id USF-VCS-022 ERROR "Invalid simulation mode '$a_sim_vars(s_mode)' specified. Please see 'simulate -help' for more details.\n"
    return 1
  }
  set a_sim_vars(s_simulation_flow) $simulation_flow
  return 0
}

proc usf_extract_ip_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { ![get_property corecontainer.enable [current_project]] } {
    return
  }
  set a_sim_vars(b_extract_ip_sim_files) [get_property extract_ip_sim_files [current_project]]
  if { $a_sim_vars(b_extract_ip_sim_files) } {
    foreach ip [get_ips -all -quiet] {
      set xci_ip_name "${ip}.xci"
      set xcix_ip_name "${ip}.xcix"
      set xcix_file_path [get_property core_container [get_files ${xci_ip_name}]]
      if { {} != $xcix_file_path } {
        [catch {rdi::extract_ip_sim_files -of_objects [get_files ${xcix_ip_name}]} err]
      }
    }
  }
}

proc usf_set_sim_tcl_obj {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set comp_file $a_sim_vars(s_comp_file)
  if { {} != $comp_file } {
    # -of_objects <full-path-to-ip-composite-file>
    set a_sim_vars(sp_tcl_obj) [get_files -all -quiet [list "$comp_file"]]
    set a_sim_vars(s_sim_top) [file root [file tail $a_sim_vars(sp_tcl_obj)]]
  } else {
    set a_sim_vars(sp_tcl_obj) [get_filesets $::tclapp::xilinx::vcs::a_sim_vars(s_simset)]
    # set current simset
    if { {} == $a_sim_vars(sp_tcl_obj) } {
      set a_sim_vars(sp_tcl_obj) [current_fileset -simset]
    }
    set a_sim_vars(s_sim_top) [get_property TOP [get_filesets $a_sim_vars(sp_tcl_obj)]]
  }
  send_msg_id USF-VCS-023 INFO "Simulation object is '$a_sim_vars(sp_tcl_obj)'...\n"
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
    puts $fh "origin_dir=\"$a_sim_vars(s_launch_dir)\""
  } else {
    puts $fh "origin_dir=\".\""
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

  # check run status
  switch -regexp -- $a_sim_vars(s_simulation_flow) {
    {post_synth_sim} {
      if { {RTL} == $design_mode } {
        if { [get_param "project.checkRunResultsForUnifiedSim"] } {
          set synth_run [current_run -synthesis]
          set status [get_property "STATUS" $synth_run]
          if { ([regexp -nocase {^synth_design complete} $status] != 1) } {
            send_msg_id USF-VCS-028 ERROR \
               "Synthesis results not available! Please run 'Synthesis' from the GUI or execute 'launch_runs <synth>' command from the Tcl console and retry this operation.\n"
            return 1
          }
        }
      }

      if { {RTL} == $design_mode } {
        set synth_run [current_run -synthesis]
        set netlist $synth_run 
        # is design for the current synth run already opened in memory?
        set synth_design [get_designs -quiet $synth_run]
        if { {} != $synth_design } {
          # design already opened, set it current
          current_design $synth_design
        } else {
          if { [catch {open_run $synth_run -name $netlist} open_error] } {
            #send_msg_id USF-VCS-028 WARNING "open_run failed:$open_err"
          } else {
            current_design $netlist
          }
        }
      } elseif { {GateLvl} == $design_mode } {
        set netlist "rtl_1"
        # is design already opened in memory?
        set synth_design [get_designs -quiet $netlist]
        if { {} != $synth_design } {
          # design already opened, set it current
          current_design $synth_design
        } else {
          # open the design
          link_design -name $netlist
        }
      } else {
        send_msg_id USF-VCS-028 ERROR "Unsupported design mode found while opening the design for netlist generation!\n"
        return 1
      }

      set design_in_memory [current_design]
      send_msg_id USF-VCS-029 INFO "Writing simulation netlist file for design '$design_in_memory'..."
      # write netlist/sdf
      set wv_args "-nolib $netlist_cmd_args -file \"$net_file\""
      if { {functional} == $a_sim_vars(s_type) } {
        set wv_args "-mode funcsim $wv_args"
      } elseif { {timing} == $a_sim_vars(s_type) } {
        set wv_args "-mode timesim $wv_args"
      }
      if { {.v} == $extn } {
        send_msg_id USF-VCS-092 INFO "write_verilog $wv_args"
        eval "write_verilog $wv_args"
      } else {
        send_msg_id USF-VCS-092 INFO "write_vhdl $wv_args"
        eval "write_vhdl $wv_args"
      }
      if { {timing} == $a_sim_vars(s_type) } {
        send_msg_id USF-VCS-030 INFO "Writing SDF file..."
        set ws_args "-mode timesim $sdf_cmd_args -file \"$sdf_file\""
        send_msg_id USF-VCS-093 INFO "write_sdf $ws_args"
        eval "write_sdf $ws_args"
      }
      set a_sim_vars(s_netlist_file) $net_file
    }
    {post_impl_sim} {
      set impl_run [current_run -implementation]
      set netlist $impl_run
      if { [get_param "project.checkRunResultsForUnifiedSim"] } {
        set status [get_property "STATUS" $impl_run]
        if { ![get_property can_open_results $impl_run] } {
          send_msg_id USF-VCS-031 ERROR \
             "Implementation results not available! Please run 'Implementation' from the GUI or execute 'launch_runs <impl>' command from the Tcl console and retry this operation.\n"
          return 1
        }
      }

      # is design for the current impl run already opened in memory?
      set impl_design [get_designs -quiet $impl_run]
      if { {} != $impl_design } {
        # design already opened, set it current
        current_design $impl_design
      } else {
        if { [catch {open_run $impl_run -name $netlist} open_error] } {
          #send_msg_id USF-VCS-028 WARNING "open_run failed:$open_err"
        } else {
          current_design $impl_run
        }
      }

      set design_in_memory [current_design]
      send_msg_id USF-VCS-032 INFO "Writing simulation netlist file for design '$design_in_memory'..."

      # write netlist/sdf
      set wv_args "-nolib $netlist_cmd_args -file \"$net_file\""
      if { {functional} == $a_sim_vars(s_type) } {
        set wv_args "-mode funcsim $wv_args"
      } elseif { {timing} == $a_sim_vars(s_type) } {
        set wv_args "-mode timesim $wv_args"
      }
      if { {.v} == $extn } {
        send_msg_id USF-VCS-094 INFO "write_verilog $wv_args"
        eval "write_verilog $wv_args"
      } else {
        send_msg_id USF-VCS-094 INFO "write_vhdl $wv_args"
        eval "write_vhdl $wv_args"
      }
      if { {timing} == $a_sim_vars(s_type) } {
        send_msg_id USF-VCS-033 INFO "Writing SDF file..."
        set ws_args "-mode timesim $sdf_cmd_args -file \"$sdf_file\""
        send_msg_id USF-VCS-095 INFO "write_sdf $ws_args"
        eval "write_sdf $ws_args"
      }

      set a_sim_vars(s_netlist_file) $net_file
    }
  }
  if { [file exist $net_file] } { send_msg_id USF-VCS-034 INFO "Netlist generated:$net_file" }
  if { [file exist $sdf_file] } { send_msg_id USF-VCS-035 INFO "SDF generated:$sdf_file" }
}

proc usf_xport_data_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable s_data_files_filter
  variable s_non_hdl_data_files_filter
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [usf_is_ip $tcl_obj] } {
    send_msg_id USF-VCS-032 INFO "Inspecting IP design source files for '$a_sim_vars(s_sim_top)'...\n"

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
    send_msg_id USF-VCS-033 INFO "Inspecting design source files for '$a_sim_vars(s_sim_top)' in fileset '$tcl_obj'...\n"
    # export all fileset data files to run dir
    if { [get_param "project.copyDataFilesForSim"] } {
      usf_export_fs_data_files $s_data_files_filter
    }
    # export non-hdl data files to run dir
    usf_export_fs_non_hdl_data_files
  } else {
    send_msg_id USF-VCS-034 INFO "Unsupported object source: $tcl_obj\n"
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

proc usf_get_include_file_dirs { global_files_str { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set launch_dir $a_sim_vars(s_launch_dir)
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
    # set vh_file [extract_files -files [list "$vh_file"] -base_dir $launch_dir/ip_files]
    set vh_file [usf_xtract_file $vh_file]
    if { [get_param project.enableCentralSimRepo] } {
      set used_in_values [get_property "USED_IN" [lindex [get_files -all -quiet [list "$vh_file"]] 0]]
      if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
        set vh_file [usf_fetch_header_from_dynamic $vh_file]
      } else {
        set vh_file [usf_fetch_ip_static_file $vh_file]
      }
    }
    set dir [file normalize [file dirname $vh_file]]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[usf_resolve_file_path $dir]"
     } else {
       if { $ref_dir } {
        set dir "\$origin_dir/[usf_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
      }
    }
    lappend dir_names $dir
  }
  if {[llength $dir_names] > 0} {
    return [lsort -unique $dir_names]
  }
  return $dir_names
}

proc usf_get_compile_order_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:
  return [usf_uniquify_cmd_str $::tclapp::xilinx::vcs::l_compile_order_files]
}

proc usf_get_top_library { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set flow    $a_sim_vars(s_simulation_flow)
  set tcl_obj $a_sim_vars(sp_tcl_obj)

  # was -of_objects <ip> specified?, fetch current fileset
  if { [usf_is_ip $tcl_obj] } {
    set tcl_obj [get_filesets $a_sim_vars(s_simset)]
  }

  # 1. get the default top library set for the project
  set default_top_library [get_property "DEFAULT_LIB" [current_project]]

  # 2. get the library associated with the top file from the 'top_lib' property on the fileset
  set fs_top_library [get_property "TOP_LIB" [get_filesets $tcl_obj]]

  # 3. get the library associated with the last file in compile order
  set co_top_library {}
  if { ({behav_sim} == $flow) } {
    set filelist [usf_get_compile_order_files]
    if { [llength $filelist] > 0 } {
      set file_list [get_files -all [list "[lindex $filelist end]"]]
      if { [llength $file_list] > 0 } {
        set co_top_library [get_property "LIBRARY" [lindex $file_list 0]]
      }
    }
  } elseif { ({post_synth_sim} == $flow) || ({post_impl_sim} == $flow) } {
    set file_list [get_files -quiet -compile_order sources -used_in synthesis_post -of_objects [get_filesets $tcl_obj]]
    if { [llength $file_list] > 0 } {
      set co_top_library [get_property "LIBRARY" [lindex $file_list end]]
    }
  }

  # 4. if default top library is set and the compile order file library is different
  #    than this default, return the compile order file library
  if { {} != $default_top_library } {
    # compile order library is set and is different then the default
    if { ({} != $co_top_library) && ($default_top_library != $co_top_library) } {
      return $co_top_library
    } else {
      # worst case (default is set but compile order file library is empty or we failed to get the library for some reason)
      return $default_top_library
    }
  }

  # 5. default top library is empty at this point
  #    if fileset top library is set and the compile order file library is different
  #    than this default, return the compile order file library
  if { {} != $fs_top_library } {
    # compile order library is set and is different then the fileset
    if { ({} != $co_top_library) && ($fs_top_library != $co_top_library) } {
      return $co_top_library
    } else {
      # worst case (fileset library is set but compile order file library is empty or we failed to get the library for some reason)
      return $fs_top_library
    }
  }

  # 6. Both the default and fileset library are empty, return compile order library else xilinx default
  if { {} != $co_top_library } {
    return $co_top_library
  }

  return "xil_defaultlib"
}

proc usf_contains_vhdl { design_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set flow $a_sim_vars(s_simulation_flow)

  set b_vhdl_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {#}] 0]
    switch $type {
      {VHDL} -
      {VHDL 2008} {
        set b_vhdl_srcs 1
      }
    }
  }

  if { (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && (!$b_vhdl_srcs) } {
    set extn [file extension $a_sim_vars(s_netlist_file)]
    if { {.vhd} == $extn } {
      set b_vhdl_srcs 1
    }
  }

  return $b_vhdl_srcs
}

proc usf_contains_verilog { design_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

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

proc usf_append_define_generics { def_gen_list tool opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  foreach element $def_gen_list {
    set key_val_pair [split $element "="]
    set name [lindex $key_val_pair 0]
    set val  [lindex $key_val_pair 1]
    set str "$name="
    if { [string length $val] > 0 } {
      set str "$str\"$val\""
    } 
    switch -regexp -- $tool {
      "vlogan" { lappend opts "+define+$str" }
    }
  }
}

proc usf_append_generics { generic_list opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  foreach element $generic_list {
    set key_val_pair [split $element "="]
    set name [lindex $key_val_pair 0]
    set val  [lindex $key_val_pair 1]
    set str "$name="
    if { [string length $val] > 0 } {
      set str "$str\"$val\""
    } 
    lappend opts "-gv $str"
  }
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
    if { $b_load_glbl } {
      return 1
    }
    return 0
  }
  # target lang is vhdl and glbl is added as top for post-implementation and post-synthesis and load glbl set (default)
  if { ((({VHDL} == $target_lang) || ({VHDL 2008} == $target_lang)) && (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && $b_load_glbl) } {
    return 1
  }
  switch $simulator {
    {vcs} {
      if { ({post_synth_sim} == $flow) || ({post_impl_sim} == $flow) } {
        return 1
      }
    }
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
    send_msg_id USF-VCS-096 WARNING "Failed to copy glbl file '$src_glbl_file' to '$run_dir' : $error_msg\n"
  }
}

proc usf_create_do_file { simulator do_filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fs_obj [current_fileset -simset]
  set top $::tclapp::xilinx::vcs::a_sim_vars(s_sim_top)
  set b_scripts_only $::tclapp::xilinx::vcs::a_sim_vars(b_scripts_only)
  set do_file [file join $a_sim_vars(s_launch_dir) $do_filename]
  set fh_do 0
  if {[catch {open $do_file w} fh_do]} {
    send_msg_id USF-VCS-035 ERROR "Failed to open file to write ($do_file)\n"
  } else {
    # generate saif file for power estimation
    set saif {}
    set uut [get_property "VCS.SIMULATE.UUT" $fs_obj]
    set saif [get_property "VCS.SIMULATE.SAIF" $fs_obj]
    if { {} != $saif } {
      if { {} == $uut } {
        set uut "$top.uut"
      }
      puts $fh_do "power $uut"
      puts $fh_do "power -enable"
    }
    puts $fh_do "add_wave /$top/*"
    puts $fh_do "dump -add * -depth 0"

    set rt [string trim [get_property "VCS.SIMULATE.RUNTIME" $fs_obj]]
    if { {} == $rt } {
      # no runtime specified
      puts $fh_do "\nrun"
    } else {
      set rt_value [string tolower $rt]
      if { ({all} == $rt_value) || (![regexp {^[0-9]} $rt_value]) } {
        puts $fh_do "\nrun"
      } else {
        puts $fh_do "\nrun $rt"
      }
    }

    if { {} != $saif } {
      set timescale {1}
      if { {} == $uut } {
        set uut "$top.uut"
      }
      set module $uut
      puts $fh_do "power -disable"
      puts $fh_do "power -report $saif $timescale $module"
    }

    # add TCL sources
    set tcl_src_files [list]
    set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\""
    ::tclapp::xilinx::vcs::usf_find_files tcl_src_files $filter
    if {[llength $tcl_src_files] > 0} {
      puts $fh_do ""
      foreach file $tcl_src_files {
        puts $fh_do "source \{$file\}"
      }
      puts $fh_do ""
    }

    if { $a_sim_vars(b_batch) || $a_sim_vars(b_scripts_only) } {
      puts $fh_do "quit"
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
      send_msg_id USF-VCS-036 INFO "Inspecting fileset '$fs_name' for IP generation...\n"
      # get ip composite files
      foreach comp_file [get_files -quiet -of_objects [get_filesets $fs_obj] -filter $ip_filter] {
        usf_generate_comp_file_for_simulation $comp_file runs_to_launch
      }
    }
    # fileset contains embedded sources? generate mem files
    if { [usf_is_embedded_flow] } {
      send_msg_id USF-VCS-037 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
      generate_mem_files $a_sim_vars(s_launch_dir)
    }
  } elseif { [usf_is_ip $target_obj] } {
    set comp_file $target_obj
    usf_generate_comp_file_for_simulation $comp_file runs_to_launch
  } else {
    send_msg_id USF-VCS-038 ERROR "Unknown target '$target_obj'!\n"
  }
  # generate functional netlist  
  if { [llength $runs_to_launch] > 0 } {
    send_msg_id USF-VCS-039 INFO "Launching block-fileset run '$runs_to_launch'...\n"
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
      send_msg_id USF-VCS-098 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
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

proc usf_is_tool_installed {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set path_sep  {:}
  set tool_extn {}

  set tool_name "vcs";append tool_name ${tool_extn}

  # user specified install path? if not, use the param value if set
  set install_path $a_sim_vars(s_install_path)
  if { {} == $install_path } {
    set install_path [get_param "simulator.vcsmxInstallPath"]
  }

  # install path found and exist
  if { ({} != $install_path) && ([file exists $install_path]) } {
    return 1
  }

  # bin path found from PATH and exist
  if { {} != [usf_get_bin_path $tool_name $path_sep] } {
    return 1
  }

  return 0
}

proc usf_set_simulator_path { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set bin_path  {}
  set tool_name {} 
  set path_sep  {:}
  set tool_extn {}
  set install_path $a_sim_vars(s_install_path)
  send_msg_id USF-VCS-040 INFO "Finding simulator installation...\n"
  switch -regexp -- $simulator {
    {vcs} {
      set tool_name "vcs";append tool_name ${tool_extn}
      if { {} == $install_path } {
        set install_path [get_param "simulator.vcsmxInstallPath"]
      }
    }
  }
 
  if { {} == $install_path } {
    set bin_path [usf_get_bin_path $tool_name $path_sep]
    if { {} == $bin_path } {
      if { $a_sim_vars(b_scripts_only) } {
        send_msg_id USF-VCS-107 WARNING \
          "Simulator executable path could not be located. Please make sure to set this path before launching the scripts.\n"
      } else {
        [catch {send_msg_id USF-VCS-041 ERROR \
          "Failed to locate '$tool_name' executable in the shell environment 'PATH' variable. Please source the settings script included with the installation and retry this operation again.\n"}]
        # IMPORTANT - *** DONOT MODIFY THIS ***
        error "_SIM_STEP_RUN_EXEC_ERROR_"
        # IMPORTANT - *** DONOT MODIFY THIS ***
        return 1
      }
    } else {
      send_msg_id USF-VCS-042 INFO "Using simulator executables from '$bin_path'\n"
    }
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
      send_msg_id USF-VCS-043 INFO "Using simulator executables from '$tool_path'\n"
    } else {
      send_msg_id USF-VCS-044 ERROR "Path to custom '$tool_name' executable program does not exist:$tool_path'\n"
    }
  }
 
  set a_sim_vars(s_tool_bin_path) $bin_path
}

proc usf_get_files_for_compilation { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $global_files_str_arg global_files_str

  set sim_flow $a_sim_vars(s_simulation_flow)

  set design_files [list]
  if { ({behav_sim} == $sim_flow) } {
    set design_files [usf_get_files_for_compilation_behav_sim $global_files_str]
  } elseif { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    set design_files [usf_get_files_for_compilation_post_sim $global_files_str]
  }
  return $design_files
}

proc usf_get_files_for_compilation_behav_sim { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compile_order_files
  upvar $global_files_str_arg global_files_str

  set files          [list]
  set l_compile_order_files [list]
  set target_obj     $a_sim_vars(sp_tcl_obj)
  set simset_obj     [get_filesets $::tclapp::xilinx::vcs::a_sim_vars(s_simset)]
  set linked_src_set [get_property "SOURCE_SET" $simset_obj]
  set target_lang    [get_property "TARGET_LANGUAGE" [current_project]]
  set src_mgmt_mode  [get_property "SOURCE_MGMT_MODE" [current_project]]

  # get global include file paths
  set incl_file_paths [list]
  set incl_files      [list]
  send_msg_id USF-VCS-100 INFO "Finding global include files..."
  usf_get_global_include_files incl_file_paths incl_files

  set global_incl_files $incl_files
  set global_files_str [usf_get_global_include_file_cmdstr incl_files]

  # verilog incl dir's and verilog headers directory path if any
  send_msg_id USF-VCS-101 INFO "Finding include directories and verilog header directory paths..."
  set l_incl_dirs_opts [list]
  foreach dir [concat [usf_get_include_dirs] [usf_get_include_file_dirs {}]] {
    lappend l_incl_dirs_opts "+incdir+$dir"
  }

  # prepare command line args for fileset files
  if { [usf_is_fileset $target_obj] } {
    set used_in_val "simulation"
    switch [get_property "FILESET_TYPE" [get_filesets $target_obj]] {
      "DesignSrcs"     { set used_in_val "synthesis" }
      "SimulationSrcs" { set used_in_val "simulation"}
      "BlockSrcs"      { set used_in_val "synthesis" }
    }
    set xpm_libraries [get_property -quiet xpm_libraries [current_project]]
    foreach library $xpm_libraries {
      foreach file [rdi::get_xpm_files -library_name $library] {
        set file_type "SystemVerilog"
        set g_files $global_files_str
        set cmd_str [usf_get_file_cmd_str $file $file_type $g_files l_incl_dirs_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }
    set b_add_sim_files 1
    # add files from block filesets
    if { {} != $linked_src_set } {
      if { [get_param project.addBlockFilesetFilesForUnifiedSim] } {
        usf_add_block_fs_files $global_files_str l_incl_dirs_opts files l_compile_order_files
      }
    }
    # add files from simulation compile order
    if { {All} == $src_mgmt_mode } {
      send_msg_id USF-VCS-102 INFO "Fetching design files from '$target_obj'..."
      foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $target_obj]] {
        if { [usf_is_global_include_file $global_files_str $file] } { continue }
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
        set cmd_str [usf_get_file_cmd_str $file $file_type $g_files l_incl_dirs_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
      set b_add_sim_files 0
    } else {
      # add files from SOURCE_SET property value
      if { {} != $linked_src_set } {
        set srcset_obj [get_filesets $linked_src_set]
        if { {} != $srcset_obj } {
          send_msg_id USF-VCS-103 INFO "Fetching design files from '$srcset_obj'...(this may take a while)..."
          foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $srcset_obj]] {
            set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
            if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
            set g_files $global_files_str
            if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
            set cmd_str [usf_get_file_cmd_str $file $file_type $g_files l_incl_dirs_opts]
            if { {} != $cmd_str } {
              lappend files $cmd_str
              lappend l_compile_order_files $file
            }
          }
        }
      }
    }

    if { $b_add_sim_files } {
      # add additional files from simulation fileset
      send_msg_id USF-VCS-104 INFO "Fetching design files from '$a_sim_vars(s_simset)'..."
      foreach file [get_files -quiet -all -of_objects [get_filesets $a_sim_vars(s_simset)]] {
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
        if { [get_property "IS_AUTO_DISABLED" [lindex [get_files -quiet -all [list "$file"]] 0]]} { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
        set cmd_str [usf_get_file_cmd_str $file $file_type $g_files l_incl_dirs_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }
  } elseif { [usf_is_ip $target_obj] } {
    # prepare command line args for fileset ip files
    send_msg_id USF-VCS-105 INFO "Fetching design files from IP '$target_obj'..."
    set ip_filename [file tail $target_obj]
    foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]] {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type $g_files l_incl_dirs_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
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
  variable l_compile_order_files
  upvar $global_files_str_arg global_files_str

  set files         [list]
  set l_compile_order_files [list]
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

  # verilog incl dir's and verilog headers directory path if any
  send_msg_id USF-VCS-106 INFO "Finding include directories and verilog header directory paths..."
  set l_incl_dirs_opts [list]
  foreach dir [concat [usf_get_include_dirs] [usf_get_include_file_dirs {}]] {
    lappend l_incl_dirs_opts "+incdir+$dir"
  }

  if { {} != $netlist_file } {
    set file_type "Verilog"
    if { {.vhd} == [file extension $netlist_file] } {
      set file_type "VHDL"
    }
    set cmd_str [usf_get_file_cmd_str $netlist_file $file_type {} l_incl_dirs_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend l_compile_order_files $netlist_file
    }
  }

  # add testbench files if any
  #set vhdl_filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"VHDL\" || FILE_TYPE == \"VHDL 2008\")"
  #foreach file [usf_get_testbench_files_from_ip $vhdl_filter] {
  #  if { [lsearch -exact [list_property $file] {FILE_TYPE}] == -1 } {
  #    continue;
  #  }
  #  #set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
  #  set file_type [get_property "FILE_TYPE" $file]
  #  set cmd_str [usf_get_file_cmd_str $file $file_type {} l_incl_dirs_opts]
  #  if { {} != $cmd_str } {
  #    lappend files $cmd_str
  #    lappend l_compile_order_files $file
  #  }
  #}
  ##set verilog_filter "USED_IN_TESTBENCH == 1 && FILE_TYPE == \"Verilog\" && FILE_TYPE == \"Verilog Header\""
  #set verilog_filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"Verilog\" || FILE_TYPE == \"SystemVerilog\")"
  #foreach file [usf_get_testbench_files_from_ip $verilog_filter] {
  #  if { [lsearch -exact [list_property $file] {FILE_TYPE}] == -1 } {
  #    continue;
  #  }
  #  #set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
  #  set file_type [get_property "FILE_TYPE" $file]
  #  set cmd_str [usf_get_file_cmd_str $file $file_type {} l_incl_dirs_opts]
  #  if { {} != $cmd_str } {
  #    lappend files $cmd_str
  #    lappend l_compile_order_files $file
  #  }
  #}

  # prepare command line args for fileset files
  if { [usf_is_fileset $target_obj] } {
    # add additional files from simulation fileset
    set simset_files [get_files -compile_order sources -used_in synthesis_post -of_objects [get_filesets $a_sim_vars(s_simset)]]
    foreach file $simset_files {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
      #if { [get_property "IS_AUTO_DISABLED" [lindex [get_files -quiet -all [list "$file"]] 0]]} { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type $g_files l_incl_dirs_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  } elseif { [usf_is_ip $target_obj] } {
    # prepare command line args for fileset ip files
    set ip_filename [file tail $target_obj]
    foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]] {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type $g_files l_incl_dirs_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  }
  return $files
}

proc usf_add_block_fs_files { global_files_str l_incl_dirs_opts_arg files_arg compile_order_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts
  upvar $files_arg files
  upvar $compile_order_files_arg compile_order_files

  set vhdl_filter "FILE_TYPE == \"VHDL\" || FILE_TYPE == \"VHDL 2008\""
  foreach file [usf_get_files_from_block_filesets $vhdl_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
    set cmd_str [usf_get_file_cmd_str $file $file_type {} l_incl_dirs_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend compile_order_files $file
    }
  }
  set verilog_filter "FILE_TYPE == \"Verilog\" || FILE_TYPE == \"SystemVerilog\""
  foreach file [usf_get_files_from_block_filesets $verilog_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
    set cmd_str [usf_get_file_cmd_str $file $file_type $global_files_str l_incl_dirs_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend compile_order_files $file
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
  set mode_type   $::tclapp::xilinx::vcs::a_sim_vars(s_mode)
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
  set extn [usf_get_script_extn]
  set scr_file ${step}$extn
  set run_dir $a_sim_vars(s_launch_dir)

  set shell_script_file [file normalize [file join $run_dir $scr_file]]
  usf_make_file_executable $shell_script_file

  if { $a_sim_vars(b_scripts_only) } {
    send_msg_id USF-VCS-061 INFO "Script generated:[file normalize [file join $run_dir $scr_file]]"
    return 0
  }

  set b_wait 0
  if { $a_sim_vars(b_batch) } {
    set b_wait 1 
  }
  set faulty_run 0
  set cwd [pwd]
  cd $::tclapp::xilinx::vcs::a_sim_vars(s_launch_dir)
  send_msg_id USF-VCS-062 INFO "Executing '[string toupper $step]' step in '$run_dir'"
  set results_log {}
  switch $step {
    {compile} -
    {elaborate} {
      if {[catch {rdi::run_program $scr_file} error_log]} {
        set faulty_run 1
      }
      
      # check errors
      if { [usf_check_errors $step results_log]} {
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
        send_msg_id USF-VCS-064 ERROR "Failed to launch $scr_file:$error_log\n"
        set faulty_run 1
      }
    }
  }
  cd $cwd
  if { $faulty_run } {
    if { {} == $results_log} {
      set msg "'$step' step failed with error(s) while executing '$shell_script_file' script. Please check that the file has the correct 'read/write/execute' permissions and the Tcl console output for any other possible errors or warnings.\n"
      [catch {send_msg_id USF-VCS-063 ERROR "$msg"}]
    } else {
      [catch {send_msg_id USF-VCS-063 ERROR "'$step' step failed with error(s). Please check the Tcl console output or '$results_log' file for more information.\n"}]
    }
    # IMPORTANT - *** DONOT MODIFY THIS ***
    error "_SIM_STEP_RUN_EXEC_ERROR_"
    # IMPORTANT - *** DONOT MODIFY THIS ***
    return 1
  }
  return 0
}

proc usf_check_errors { step results_log_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $results_log_arg results_log

  variable a_sim_vars
  set run_dir $a_sim_vars(s_launch_dir)

  switch $step {
    {compile} {
      # errors in vlogan?
      set token "vlogan"
      if { [usf_found_errors_in_file $token] } {
        set results_log [file normalize [file join $run_dir "${token}.log"]]
        return 1
      }
      # errors in vhdlan?
      set token "vhdlan"
      if { [usf_found_errors_in_file $token] } {
        set results_log [file normalize [file join $run_dir "${token}.log"]]
        return 1
      }
    }
    {elaborate} {
      # errors in vsim?
      set token "elaborate"
      if { [usf_found_errors_in_file $token] } {
        set results_log [file normalize [file join $run_dir "${token}.log"]]
        return 1
      }
    }
  }
  return 0
}

proc usf_found_errors_in_file { token } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set run_dir $a_sim_vars(s_launch_dir)

  set fh 0
  set file ${token}.log
  if {[file exists $file]} {
    if {[catch {open $file r} fh]} {
      send_msg_id USF-VCS-097 ERROR "Failed to open file to read ($file)\n"
      return 1
    }
  } else {
    return 0
  }
  set data [read $fh]
  close $fh
  set retval 0
  set log_data [split $data "\n"]
  foreach line $log_data {
    set line_str [string trim $line]
    switch $token {
      {vlogan}    { if { [regexp {^Error-} $line_str] } { set retval 1;break } }
      {vhdlan}    { if { [regexp {^Error-} $line_str] } { set retval 1;break } }
      {elaborate} { if { [regexp {^Error-} $line_str] } { set retval 1;break } }
    }
  }

  if { $retval } {
    set results_log [file normalize [file join $run_dir "${token}.log"]]
    [catch {send_msg_id USF-VCS-099 INFO "Step results log file:'$results_log'\n"}]
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
  puts "-simset         = $::tclapp::xilinx::vcs::a_sim_vars(s_simset)"
  puts "-mode           = $::tclapp::xilinx::vcs::a_sim_vars(s_mode)"
  puts "-type           = $::tclapp::xilinx::vcs::a_sim_vars(s_type)"
  puts "-scripts_only   = $::tclapp::xilinx::vcs::a_sim_vars(b_scripts_only)"
  puts "-of_objects     = $::tclapp::xilinx::vcs::a_sim_vars(s_comp_file)"
  puts "-absolute_path  = $::tclapp::xilinx::vcs::a_sim_vars(b_absolute_path)"
  puts "-install_path   = $::tclapp::xilinx::vcs::a_sim_vars(s_install_path)"
  puts "-batch          = $::tclapp::xilinx::vcs::a_sim_vars(b_batch)"
  puts "-int_os_type    = $::tclapp::xilinx::vcs::a_sim_vars(s_int_os_type)"
  puts "-int_debug_mode = $::tclapp::xilinx::vcs::a_sim_vars(s_int_debug_mode)"
  puts "*******************************"
}

proc usf_get_script_extn {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set scr_extn ".sh"
  return $scr_extn
}

proc usf_get_platform {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fs_obj [get_filesets $::tclapp::xilinx::vcs::a_sim_vars(s_simset)]
  set platform {}
  set b_32_bit [get_property 32bit $fs_obj]
  set platform "lnx64"
  if { $b_32_bit } {
    set platform "lnx32"
  }
  return $platform
}
  
proc usf_is_axi_bfm_ip {} {
  # Summary: Finds VLNV property value for the IP and checks to see if the IP is AXI_BFM
  # Argument Usage:
  # Return Value:
  # true (1) if specified IP is axi_bfm, false (0) otherwise

  foreach ip [get_ips -all -quiet] {
    set ip_def [lindex [split [get_property "IPDEF" [get_ips -all -quiet $ip]] {:}] 2]
    set ip_def_obj [get_ipdefs -quiet -regexp .*${ip_def}.*]
    #puts ip_def_obj=$ip_def_obj
    if { {} != $ip_def_obj } {
      set value [get_property "VLNV" $ip_def_obj]
      #puts is_axi_bfm_ip=$value
      if { ([regexp -nocase {axi_bfm} $value]) || ([regexp -nocase {processing_system7} $value]) } {
        return 1
      }
    }
  }
  return 0
}

proc usf_get_simulator_lib_for_bfm {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set simulator_lib {}
  set xil           $::env(XILINX_VIVADO)
  set path_sep      {:}
  set lib_extn      {.so}
  set platform      [::tclapp::xilinx::vcs::usf_get_platform]

  set lib_name "libxil_vcs";append lib_name $lib_extn
  if { {} != $xil } {
    append platform ".o"
    set lib_path {}
    send_msg_id USF-VCS-116 INFO "Finding simulator library from 'XILINX_VIVADO'..."
    foreach path [split $xil $path_sep] {
      set file [file normalize [file join $path "lib" $platform $lib_name]]
      if { [file exists $file] } {
        send_msg_id USF-VCS-117 INFO "Using library:'$file'"
        set simulator_lib $file
        break
      } else {
        send_msg_id USF-VCS-118 WARNING "Library not found:'$file'"
      }
    }
  } else {
    send_msg_id USF-VCS-065 ERROR "Environment variable 'XILINX_VIVADO' is not set!"
  }
  return $simulator_lib
}
}

#
# Low level helper procs
# 
namespace eval ::tclapp::xilinx::vcs {
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
      send_msg_id USF-VCS-066 INFO "The target language is set to VHDL, it is not supported for simulation type '$a_sim_vars(s_type)', using Verilog instead.\n"
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
  variable l_target_simulator
  set export_dir $a_sim_vars(s_launch_dir)
  if { [llength $data_files] > 0 } {
    set data_files [usf_remove_duplicate_files $data_files]
    foreach file $data_files {
      set extn [file extension $file]
      switch -- $extn {
        {.c} -
        {.zip} -
        {.hwh} -
        {.hwdef} -
        {.xml} {
          if { {} != [usf_get_ip_name $file] } {
            continue
          }
        }
      }
      set filename [file tail $file]
      set repo_file {}
      if { [get_param project.enableCentralSimRepo] } {
        set repo_file [file normalize [file join $a_sim_vars(dynamic_repo_dir) "mem_init_files" $filename]]
      }
      if { ({} != $repo_file) && ([file exists $repo_file]) } {
        set file $repo_file
      } else {
        set file [extract_files -no_paths -files [list "$file"] -base_dir $export_dir]
      }

      if {[catch {file copy -force $file $export_dir} error_msg] } {
        send_msg_id USF-VCS-067 WARNING "Failed to copy file '$file' to '$export_dir' : $error_msg\n"
      } else {
        send_msg_id USF-VCS-068 INFO "Exported '$file'\n"
      }
    }
  }
}

proc usf_export_fs_data_files { filter } {
  # Summary: Copy fileset IP data files to output directory
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fs_obj [get_filesets $::tclapp::xilinx::vcs::a_sim_vars(s_simset)]
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

  set fs_obj [get_filesets $::tclapp::xilinx::vcs::a_sim_vars(s_simset)]
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

proc usf_get_files_from_block_filesets { filter_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set file_list [list]
  set filter "FILESET_TYPE == \"BlockSrcs\""
  set used_in_val "simulation"
  foreach fs_obj [get_filesets -filter $filter] {
    set fs_name [get_property "NAME" $fs_obj]
    send_msg_id USF-VCS-069 INFO "Inspecting fileset '$fs_name' for '$filter_type' files...\n"
    #set files [usf_remove_duplicate_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fs_obj] -filter $filter_type]]
    set files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fs_obj] -filter $filter_type]
    if { [llength $files] == 0 } {
      send_msg_id USF-VCS-070 INFO "No files found in '$fs_name'\n"
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
    foreach vh_file $vh_files {
      # skip if not marked as global include
      if { ![get_property "IS_GLOBAL_INCLUDE" [lindex [get_files -quiet [list "$vh_file"]] 0]] } {
        continue
      }

      # skip if marked user disabled
      if { [get_property "IS_USER_DISABLED" [lindex [get_files -quiet [list "$vh_file"]] 0]] } {
        continue
      }

      set vh_file [file normalize [string map {\\ /} $vh_file]]
      if { [lsearch -exact $incl_files_set $vh_file] == -1 } {
        lappend incl_files_set $vh_file
        lappend incl_files     $vh_file
        set incl_file_path [file normalize [string map {\\ /} [file dirname $vh_file]]]
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
  foreach vh_file $vh_files {
    if { $a_sim_vars(b_absolute_path) } {
      set vh_file "[usf_resolve_file_path $vh_file]"
    } else {
      set vh_file "\$origin_dir/[usf_get_relative_file_path $vh_file $a_sim_vars(s_launch_dir)]"
    }
    lappend incl_files $vh_file
  }
  return $incl_files
}

proc usf_get_incl_dirs_from_ip { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set launch_dir $a_sim_vars(s_launch_dir)
  set ip_name [file tail $tcl_obj]
  set incl_dirs [list]
  set filter "FILE_TYPE == \"Verilog Header\""
  set vh_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach vh_file $vh_files {
    # set vh_file [extract_files -files [list "$vh_file"] -base_dir $launch_dir/ip_files]
    set vh_file [usf_xtract_file $vh_file]
    set dir [file dirname $vh_file]
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
  if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } {
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
  set fs_obj [get_filesets $a_sim_vars(s_simset)]
  switch $tool {
    "vhdlan" {
      lappend opts "\$${tool}_opts"
      if { [string equal -nocase $file_type "vhdl 2008"] } {
        lappend opts "-vhdl08"
      }
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
}

proc usf_make_file_executable { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if {$::tcl_platform(platform) == "unix"} {
    if {[catch {exec chmod a+x $file} error_msg] } {
      send_msg_id USF-VCS-071 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
    }
  } else {
    if {[catch {exec attrib /D -R $file} error_msg] } {
      send_msg_id USF-VCS-072 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
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
      send_msg_id USF-VCS-071 INFO "Generating simulation products for IP '$ip_name'...\n"
      set delivered_targets [get_property delivered_targets [get_ips -all -quiet ${ip_name}]]
      if { [regexp -nocase {simulation} $delivered_targets] } {
        generate_target {simulation} [get_files [list "$comp_file"]] -force
      }
    } else {
      send_msg_id USF-VCS-074 INFO "IP '$ip_name' is upto date for simulation\n"
    }
  } elseif { [get_property "GENERATE_SYNTH_CHECKPOINT" $comp_file] } {
    # make sure ip is up-to-date
    if { ![get_property "IS_IP_GENERATED" $comp_file] } {
      generate_target {all} [get_files [list "$comp_file"]] -force
      send_msg_id USF-VCS-077 INFO "Generating functional netlist for IP '$ip_name'...\n"
      usf_generate_ip_netlist $comp_file runs_to_launch
    } else {
      send_msg_id USF-VCS-078 INFO "IP '$ip_name' is upto date for all products\n"
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
    send_msg_id USF-VCS-079 WARNING "$error_msg\n"
    #return 1
  }
}

proc usf_generate_ip_netlist { comp_file runs_to_launch_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $runs_to_launch_arg runs_to_launch
  set comp_file_obj [get_files [list "$comp_file"]]
  set comp_file_fs  [get_property "FILESET_NAME" $comp_file_obj]
  if { ![get_property "GENERATE_SYNTH_CHECKPOINT" $comp_file_obj] } {
    send_msg_id USF-VCS-083 INFO "Generate synth checkpoint is 'false':$comp_file\n"
    # if synth checkpoint read-only, return
    if { [get_property "IS_IP_SYNTH_CHECKPOINT_READONLY" $comp_file_obj] } {
      send_msg_id USF-VCS-084 WARNING "Synth checkpoint property is 'readonly' ... skipping:$comp_file\n"
      return
    }
    # set property to create a DCP/structural simulation file
    send_msg_id USF-VCS-085 INFO "Setting synth checkpoint for generating simulation netlist:$comp_file\n"
    set_property "GENERATE_SYNTH_CHECKPOINT" true $comp_file_obj
  } else {
    send_msg_id USF-VCS-086 INFO "Generate synth checkpoint is set:$comp_file\n"
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
    send_msg_id USF-VCS-087 INFO "Block-fileset created:$block_fs_obj"
    # set fileset top
    set comp_file_top [get_property "IP_TOP" $comp_file_obj]
    set_property "TOP" $comp_file_top [get_filesets $ip_basename]
    # move sub-design to block-fileset
    send_msg_id USF-VCS-088 INFO "Moving ip composite source(s) to '$ip_basename' fileset"
    move_files -fileset [get_filesets $ip_basename] [get_files -of_objects [get_filesets $comp_file_fs] $src_file] 
  }
  if { {BlockSrcs} != [get_property "FILESET_TYPE" $block_fs_obj] } {
    send_msg_id USF-VCS-089 ERROR "Given source file is not associated with a design source fileset.\n"
    return 1
  }
  # construct block-fileset run for the netlist
  set run_name $ip_basename;append run_name "_synth_1"
  if { ![get_property "IS_INITIALIZED" [get_runs $run_name]] } {
    reset_run $run_name
  }
  lappend runs_to_launch $run_name
  send_msg_id USF-VCS-090 INFO "Run scheduled for '$ip_basename':$run_name\n"
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
          if { [lsearch -exact [list_property $tb_file_obj] {IS_USER_DISABLED}] != -1 } {
            if { [get_property {IS_USER_DISABLED} $tb_file_obj] } {
              continue;
            }
          }
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
  set launch_dir $a_sim_vars(s_launch_dir)

  foreach file $incl_files {
    # set file [extract_files -files [list "$file"] -base_dir $launch_dir/ip_files]
    lappend file_str "\"$file\""
  }
  return [join $file_str " "]
}

proc usf_get_file_cmd_str { file file_type global_files_str l_incl_dirs_opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts
  set dir             $a_sim_vars(s_launch_dir)
  set b_absolute_path $a_sim_vars(b_absolute_path)
  set cmd_str {}
  set associated_library [get_property "DEFAULT_LIB" [current_project]]
  set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
  if { {} != $file_obj } {
    if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
      set associated_library [get_property "LIBRARY" $file_obj]
    }
    if { [get_param "project.enableCentralSimRepo"] } {
      # no op
    } else {
      if { $a_sim_vars(b_extract_ip_sim_files) } {
        set xcix_ip_path [get_property core_container $file_obj]
        if { {} != $xcix_ip_path } {
          set ip_name [file root [file tail $xcix_ip_path]]
          set ip_ext_dir [get_property ip_extract_dir [get_ips -all -quiet $ip_name]]
          set ip_file "./[usf_get_relative_file_path $file $ip_ext_dir]"
          # remove leading "./../"
          set ip_file [join [lrange [split $ip_file "/"] 2 end] "/"]
          set file [file join $ip_ext_dir $ip_file]
        } else {
          # set file [extract_files -files [list "$file"] -base_dir $dir/ip_files]
        }
      }
    }
  }

  set ip_file  [usf_get_ip_name $file]
  set b_static_ip_file 0
  set file [usf_get_ip_file_from_repo $ip_file $file $associated_library $dir b_static_ip_file]

  set compiler [usf_get_compiler_name $file_type]
  set arg_list [list]
  if { [string length $compiler] > 0 } {
    lappend arg_list $compiler
    usf_append_compiler_options $compiler $file_type arg_list
    if { [string equal -nocase $associated_library "work"] } {
      set arg_list [linsert $arg_list end "$global_files_str"]
    } else {
      set arg_list [linsert $arg_list end "-work $associated_library" "$global_files_str"]
    }
  }

  # append include dirs for verilog sources
  if { {vlogan} == $compiler } {
    set arg_list [concat $arg_list $l_incl_dirs_opts]
  }

  usf_append_other_options $compiler $global_files_str $file_type arg_list

  set file_str [join $arg_list " "]
  set type [usf_get_file_type_category $file_type]

  set cmd_str "$type#$file_type#$associated_library#$file_str#\"$file\"#$b_static_ip_file"
  return $cmd_str
}

proc usf_get_ip_name { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set ip {}
  set file_obj [lindex [get_files -all -quiet $src_file] 0]
  if { {} == $file_obj } {
    set file_obj [lindex [get_files -all -quiet [file tail $src_file]] 0]
  }

  if { {} == $file_obj } {
    return $ip
  }

  set props [list_property $file_obj]
  if { [lsearch $props "PARENT_COMPOSITE_FILE"] != -1 } {
    set ip [get_property "PARENT_COMPOSITE_FILE" $file_obj]
  }
  return $ip
}

proc usf_get_file_type_category { file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set type {UNKNOWN}
  switch $file_type {
    {VHDL} -
    {VHDL 2008} {
      set type {VHDL}
    }
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

proc usf_xtract_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { [get_param "project.enableCentralSimRepo"] } {
    return $file
  }

  variable a_sim_vars
  if { $a_sim_vars(b_extract_ip_sim_files) } {
    set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
    set xcix_ip_path [get_property core_container $file_obj]
    if { {} != $xcix_ip_path } {
      set ip_name [file root [file tail $xcix_ip_path]]
      set ip_ext_dir [get_property ip_extract_dir [get_ips all -quiet $ip_name]]
      set ip_file "./[usf_get_relative_file_path $file $ip_ext_dir]"
      # remove leading "./../"
      set ip_file [join [lrange [split $ip_file "/"] 2 end] "/"]
      set file [file join $ip_ext_dir $ip_file]
    }
  }
  return $file
}

proc usf_get_ip_file_from_repo { ip_file src_file library launch_dir b_static_ip_file_arg  } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_ip_static_libs
  upvar $b_static_ip_file_arg b_static_ip_file
  set b_donot_process 0

  if { (![get_param project.enableCentralSimRepo]) || ({} == $ip_file) } {
    set b_donot_process 1
  }

  if { $b_donot_process } {
    if { $a_sim_vars(b_absolute_path) } {
      set src_file "[usf_resolve_file_path $src_file]"
    } else {
      set src_file "\$origin_dir/[usf_get_relative_file_path $src_file $launch_dir]"
    }
    return $src_file
  }

  if { ({} != $a_sim_vars(dynamic_repo_dir)) && ([file exist $a_sim_vars(dynamic_repo_dir)]) } {
    set b_is_static 0
    set b_is_dynamic 0
    set src_file [usf_get_source_from_repo $ip_file $src_file $launch_dir b_is_static b_is_dynamic]
    if { (!$b_is_static) && (!$b_is_dynamic) } {
      send_msg_id USF-VCS-056 "CRITICAL WARNING" "IP file is neither static or dynamic:'$src_file'\n"
    }
    # phase-2
    if { $b_is_static } {
      lappend l_ip_static_libs [string tolower $library]
    }
  }

  return $src_file
}

proc usf_get_source_from_repo { ip_file orig_src_file launch_dir b_is_static_arg b_is_dynamic_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $b_is_static_arg b_is_static
  upvar $b_is_dynamic_arg b_is_dynamic

  #puts org_file=$orig_src_file
  set src_file $orig_src_file

  set b_wrap_in_quotes 0
  if { [regexp {\"} $src_file] } {
    set b_wrap_in_quotes 1
    regsub -all {\"} $src_file {} src_file
  }

  set b_add_ref 0 
  if {[regexp -nocase {^\$origin_dir} $src_file]} {
    set b_add_ref 1
    set src_file [string range $src_file 9 end]
    set src_file "./$src_file"
  }
  #puts src_file=$src_file
  set filename [file tail $src_file]
  #puts ip_file=$ip_file
  set ip_name [file root [file tail $ip_file]] 

  set full_src_file_path [usf_find_file_from_compile_order $ip_name $src_file]
  #puts ful_file=$full_src_file_path
  #puts ip_name=$ip_name

  set b_is_bd_ip 0
  #set ip_obj [get_ips -all -quiet $ip_name]
  #if { {} != $ip_obj } {
  #  set ip_file [get_property IP_FILE $ip_obj]
  #  set ipi_file [usf_get_ip_name $ip_file]
  #  if { ({} != $ipi_file) && ({.bd} == [file extension $ipi_file]) } {
  #    set b_is_bd_ip 1
  #  }
  #} else {
  #  # ip_name=design_1 (this is not ip, so check if src contain "design_1"
  #  set sub_dirs [list]
  #  set comps [lrange [split $full_src_file_path "/"] 1 end]
  #  set to_match "$ip_name"
  #  foreach comp $comps {
  #    if { $to_match == $comp } {
  #      set ip_file $full_src_file_path
  #      set ipi_file [usf_get_ip_name $ip_file]
  #      if { ({} != $ipi_file) && ({.bd} == [file extension $ipi_file]) } {
  #        set b_is_bd_ip 1
  #        break
  #      }
  #    }
  #  }
  #}

  set b_is_bd_ip 0
  # TODO: handle dynamic bd files

  set dst_cip_file {}
  if { $b_is_bd_ip } {
    set dst_cip_file [usf_fetch_ipi_dynamic_file $ipi_file $full_src_file_path]
  } else {
    #set dst_cip_file [file normalize [file join $a_sim_vars(dynamic_repo_dir) $ip_name "sim" $filename]] 
    set dst_cip_file [usf_get_dynamic_sim_file $ip_file $ip_name $full_src_file_path]
  }
  set b_is_dynamic 1

  # is static ip file? set flag and return
  set ip_static_file [get_files -quiet -all -of_objects [get_ips -all -quiet $ip_name] [list "$full_src_file_path"] -filter {USED_IN=~"*ipstatic*"}]
  if { {} != $ip_static_file } {
    #puts ip_static_file=$ip_static_file
    set b_is_static 1
    set b_is_dynamic 0
    set dst_cip_file $ip_static_file

    set b_is_bd_ip [usf_is_bd_file $full_src_file_path]
    if { $b_is_bd_ip } {
      set dst_cip_file [usf_fetch_ipi_static_file $ip_static_file]
    } else {
      set dst_cip_file [extract_files -no_ip_dir -quiet -files [list "$ip_static_file"] -base_dir $a_sim_vars(ipstatic_dir)]
    }
  }

  if { [file exist $dst_cip_file] } {
    if { $a_sim_vars(b_absolute_path) } {
      set dst_cip_file "[usf_resolve_file_path $dst_cip_file]"
    } else {
      #if { $b_add_ref } {
      #  set dst_cip_file "\$origin_dir/[usf_get_relative_file_path $dst_cip_file $launch_dir]"
      #} else {
      #  set dst_cip_file "./[usf_get_relative_file_path $dst_cip_file $launch_dir]"
      #}
      set dst_cip_file "\$origin_dir/[usf_get_relative_file_path $dst_cip_file $launch_dir]"
    }
    if { $b_wrap_in_quotes } {
      set dst_cip_file "\"$dst_cip_file\""
    }
    set orig_src_file $dst_cip_file
  }
  return $orig_src_file
}

proc usf_is_bd_file { compile_order_src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set b_is_bd_file 0

  # TODO: recursively find the parent composite file to see if the top most file is a bd

  set comps [lrange [split $compile_order_src_file "/"] 1 end]
  if { ([lsearch $comps "bd"] != -1)         ||
       ([lsearch $comps "ipshared"] != -1)   ||
       ([lsearch $comps "xilinx.com"] != -1) } {
    set b_is_bd_file 1
  }

  return $b_is_bd_file
}

proc usf_fetch_ip_static_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set src_ip_file $file
  #puts src_ip_file=$src_ip_file
  set comps [lrange [split $src_ip_file "/"] 1 end]
  set to_match "ip"
  if { [lsearch -exact $comps $to_match] == -1 } {
    return $src_ip_file
  }

  set index 0
  foreach comp $comps {
    if { $to_match != $comp } {
      incr index
      continue;
    }
    break
  }
  set file_path_str [join [lrange $comps 0 $index] "/"]
  set ip_lib_dir "/$file_path_str"
  #puts ip_lib_dir=$ip_lib_dir

  incr index
  incr index
  set ip_hdl_sub_dir [join [lrange $comps $index end] "/"]
  #puts ip_hdl_sub_dir=$ip_hdl_sub_dir

  set dst_cip_file [file join $a_sim_vars(ipstatic_dir) $ip_hdl_sub_dir]
  #puts dst_cip_file=$dst_cip_file
  return $dst_cip_file
}

proc usf_fetch_ipi_static_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set src_ip_file $file
  set comps [lrange [split $src_ip_file "/"] 1 end]
  set to_match "xilinx.com"
  set index 0
  foreach comp $comps {
    incr index
    if { $to_match != $comp } continue;
    break
  }
  set file_path_str [join [lrange $comps 0 $index] "/"]
  set ip_lib_dir "/$file_path_str"

  #puts ip_lib_dir=$ip_lib_dir
  set ip_lib_dir_name [file tail $ip_lib_dir]
  set target_ip_lib_dir [file join $a_sim_vars(ipstatic_dir) $ip_lib_dir_name]
  #puts target_ip_lib_dir=$target_ip_lib_dir

  # get the sub-dir path after "xilinx.com/xbip_utils_v3_0/4f162624"
  set ip_hdl_dir [join [lrange $comps 0 $index] "/"]
  set ip_hdl_dir "/$ip_hdl_dir"
  # /demo/ipshared/xilinx.com/xbip_utils_v3_0/4f162624/hdl
  #puts ip_hdl_dir=$ip_hdl_dir
  incr index

  set ip_hdl_sub_dir [join [lrange $comps $index end] "/"]
  # /4f162624/hdl/xbip_utils_v3_0_vh_rfs.vhd
  #puts ip_hdl_sub_dir=$ip_hdl_sub_dir

  set dst_cip_file [file join $target_ip_lib_dir $ip_hdl_sub_dir]
  #puts dst_cip_file=$dst_cip_file
  return $dst_cip_file
}

proc usf_get_dynamic_sim_file { ip_file ip_name src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  #puts ip_name=$ip_name
  #puts inn_src_file=$src_file

  # if not core-container (classic), return original source file from project
  if { ![usf_is_core_container $ip_file $ip_name] } {
    return $src_file
  }

  set comps [lrange [split $src_file "/"] 1 end]

  set b_found false
  if { $a_sim_vars(b_is_managed) } {
    # for managed ip get the path from core container ip name (below)
  } else {
    #set to_match "ip/$ip_name"
    set to_match "ip"
    set index 0
    set b_found false
    foreach comp $comps {
      incr index
      if { $to_match != $comp } continue;
      set b_found true
      break
    }
  
    # try ip name
    if { !$b_found } {
      set to_match "$ip_name"
      set index 0
      set b_found false
      foreach comp $comps {
        incr index
        if { $to_match != $comp } continue;
        set b_found true
        break
      }
    }
  }

  if { !$b_found } {
    # get the core container ip name of this source and find from repo area
    set file_obj [lindex [get_files -all -quiet [list "$src_file"]] 0]
    set xcix_file [string trim [get_property core_container $file_obj]]
    if { {} != $xcix_file } {
      set ip_name [file root [file tail $xcix_file]]
      set to_match "$ip_name"
      set index 0
      set b_found false
      foreach comp $comps {
        incr index
        if { $to_match != $comp } continue;
        set b_found true
        break
      }
    }
  }

  if { !$b_found } {
    return $src_file
  }

  set file_path_str [join [lrange $comps $index end] "/"]
  #puts file_path_str=$file_path_str
  set src_file [file join $a_sim_vars(dynamic_repo_dir) "ip" $file_path_str]
  if { $to_match == $ip_name } {
    set src_file [file join $a_sim_vars(dynamic_repo_dir) "ip" $ip_name $file_path_str]
  }
  #puts out_src_file=$src_file
  return $src_file
}

proc usf_fetch_ipi_dynamic_file { ipi_file src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set ip_name [file root [file tail $ipi_file]]
  # design_1
  #puts ip_name=$ip_name
  #puts inn_src_file=$src_file

  set comps [lrange [split $src_file "/"] 1 end]
  set to_match "$ip_name"
  set index 0
  foreach comp $comps {
    incr index
    if { $to_match != $comp } continue;
    break
  }
  set file_path_str [join [lrange $comps $index end] "/"]
  if { {} == $file_path_str } {
    return $src_file
  }
  #puts file_path_str=$file_path_str

  set file_path_str "$ip_name/$file_path_str"
  set src_file [file join $a_sim_vars(dynamic_repo_dir) "bd" $file_path_str]
  if { $a_sim_vars(b_is_managed) } {
    set src_file [file join $a_sim_vars(dynamic_repo_dir) "bd" $ip_name $file_path_str]
  }
  #puts out_src_file=$src_file
  return $src_file
}

proc usf_fetch_header_from_dynamic { vh_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  #puts vh_file=$vh_file
  set ip_file [usf_get_ip_name $vh_file]
  if { {} == $ip_file } {
    return $vh_file
  }
  set ip_name [file root [file tail $ip_file]]
  #puts ip_name=$ip_name

  set comps [lrange [split $vh_file "/"] 1 end]

  # for bd's
  if { [lsearch $comps "bd"] != -1 } {
    set to_match "bd"
    set index 0
    set b_found false
    foreach comp $comps {
      incr index
      if { $to_match != $comp } continue;
      set b_found true
      break
    }
    if { !$b_found } {
      return $vh_file
    }
    set file_path_str [join [lrange $comps $index end] "/"]
    #puts file_path_str=$file_path_str
    set vh_file [file join $a_sim_vars(dynamic_repo_dir) "bd" $file_path_str]
  } else {
    set to_match "ip"
    set index 0
    set b_found false
    foreach comp $comps {
      incr index
      if { $to_match != $comp } continue;
      set b_found true
      break
    }
  
    # try ip name
    if { !$b_found } {
      set to_match "$ip_name"
      set index 0
      set b_found false
      foreach comp $comps {
        incr index
        if { $to_match != $comp } continue;
        set b_found true
        break
      }
    }
  
    if { !$b_found } {
      return $vh_file
    }
  
    set file_path_str [join [lrange $comps $index end] "/"]
    #puts file_path_str=$file_path_str
    set vh_file [file join $a_sim_vars(dynamic_repo_dir) "ip" $file_path_str]
    if { $to_match == $ip_name } {
      set vh_file [file join $a_sim_vars(dynamic_repo_dir) "ip" $ip_name $file_path_str]
    }
  }
  #puts out_src_file=$vh_file
  return $vh_file
}

proc usf_is_core_container { ip_file ip_name } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_is_container 1
  if { [get_property sim.use_central_dir_for_ips [current_project]] } {
    return $b_is_container
  }

  set file_extn [file extension $ip_file]
  #puts $ip_name=$file_extn

  # is this ip core-container? if not return 0 (classic)
  set value [string trim [get_property core_container [get_files -all -quiet ${ip_name}${file_extn}]]]
  if { {} == $value } {
    set b_is_container 0
  }
  return $b_is_container
}

proc usf_find_file_from_compile_order { ip_name src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  #puts src_file=$src_file
  set file [string map {\\ /} $src_file]

  set sub_dirs [list]
  set comps [lrange [split $file "/"] 1 end]
  foreach comp $comps {
    if { {.} == $comp } continue;
    if { {..} == $comp } continue;
    lappend sub_dirs $comp
  }
  set file_path_str [join $sub_dirs "/"]

  set str_to_replace "/{$ip_name}/"
  set str_replace_with "/${ip_name}/"
  regsub -all $str_to_replace $file_path_str $str_replace_with file_path_str
  #puts file_path_str=$file_path_str

  foreach file [usf_get_compile_order_files] {
    set file [string map {\\ /} $file]
    #puts +co_file=$file
    if { [string match  *$file_path_str $file] } {
      set src_file $file
      break
    }
  }
  #puts out_file=$src_file
  return $src_file
}

proc usf_is_static_ip_lib { library } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_ip_static_libs
  set library [string tolower $library]
  if { [lsearch $l_ip_static_libs $library] != -1 } {
    return true
  }
  return false
}
}

#
# not used currently
#
namespace eval ::tclapp::xilinx::vcs {
proc usf_get_top { top_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $top_arg top
  set fs_obj [get_filesets $a_sim_vars(s_simset)]
  set fs_name [get_property "NAME" $fs_obj]
  set top [get_property "TOP" $fs_obj]
  if { {} == $top } {
    send_msg_id USF-VCS-091 ERROR "Top module not set for fileset '$fs_name'. Please ensure that a valid \
       value is provided for 'top'. The value for 'top' can be set/changed using the 'Top Module Name' field under\
       'Project Settings', or using the 'set_property top' Tcl command (e.g. set_property top <name> \[current_fileset\])."
    return 1
  }
  return 0
}
}
