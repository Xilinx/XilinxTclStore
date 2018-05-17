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
  namespace export usf_create_options
}

namespace eval ::tclapp::xilinx::xsim {
proc usf_init_vars {} {
  # Summary: initializes global namespace vars
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set project                         [current_project]
  set a_sim_vars(src_mgmt_mode)       [get_property "SOURCE_MGMT_MODE" $project]
  set a_sim_vars(default_top_library) [get_property "DEFAULT_LIB" $project]
  set a_sim_vars(s_project_name)      [get_property "NAME" $project]
  set a_sim_vars(s_project_dir)       [get_property "DIRECTORY" $project]
  set a_sim_vars(b_is_managed)        [get_property "MANAGED_IP" $project]
  set a_sim_vars(s_launch_dir)        {}
  set a_sim_vars(s_sim_top)           [get_property "TOP" [current_fileset -simset]]

  # launch_simulation tcl task args
  set a_sim_vars(s_simset)           [current_fileset -simset]
  set a_sim_vars(s_mode)             "behavioral"
  set a_sim_vars(s_type)             {}
  set a_sim_vars(b_scripts_only)     0
  set a_sim_vars(s_comp_file)        {}
  set a_sim_vars(b_absolute_path)    0
  set a_sim_vars(s_install_path)     {}
  set a_sim_vars(s_lib_map_path)     {}
  set a_sim_vars(s_clibs_dir)        {}
  set a_sim_vars(compiled_library_dir) {}
  set a_sim_vars(b_batch)            0
  set a_sim_vars(s_int_os_type)      {}
  set a_sim_vars(s_int_debug_mode)   0
  set a_sim_vars(b_int_systemc_mode) 0
  set a_sim_vars(b_int_rtl_kernel_mode) 0

  set a_sim_vars(dynamic_repo_dir)   [get_property ip.user_files_dir [current_project]]
  set a_sim_vars(ipstatic_dir)       [get_property sim.ipstatic.source_dir [current_project]]
  set a_sim_vars(b_use_static_lib)   [get_property sim.ipstatic.use_precompiled_libs [current_project]]

  set a_sim_vars(b_contain_systemc_sources) 0
  set a_sim_vars(b_contain_cpp_sources)     0
  set a_sim_vars(b_contain_c_sources)       0
  
  set a_sim_vars(b_group_files_by_library) [get_param "project.assembleFilesByLibraryForUnifiedSim"]
  set a_sim_vars(compiled_design_lib) "xsim.dir"

  # initialize ip repository dir
  set data_dir [rdi::get_data_dir -quiet -datafile "ip/xilinx"]
  set a_sim_vars(s_ip_repo_dir) [file normalize [file join $data_dir "ip/xilinx"]]

  set a_sim_vars(s_tool_bin_path)    {}

  set a_sim_vars(sp_tcl_obj)         {}

  # fileset compile order
  variable l_compile_order_files     [list]
  variable l_compile_order_files_uniq [list]
  variable l_design_files            [list]
  variable l_compiled_libraries      [list]
  variable l_local_design_libraries  [list]
  variable l_systemc_incl_dirs       [list]
  # ip static libraries
  variable l_ip_static_libs          [list]

  # list of xpm libraries
  variable l_xpm_libraries [list]

  # global files
  variable global_files_value        {}

  # ip file extension types
  variable l_valid_ip_extns          [list]
  set l_valid_ip_extns               [list ".xci" ".bd" ".slx"]

  # hdl file extension types
  variable l_valid_hdl_extns          [list]
  set l_valid_hdl_extns               [list ".vhd" ".vhdl" ".vhf" ".vho" ".v" ".vf" ".verilog" ".vr" ".vg" ".vb" ".tf" ".vlog" ".vp" ".vm" ".vh" ".h" ".svh" ".sv" ".veo" ".so"]
 
  # data file extension types 
  variable s_data_files_filter
  set s_data_files_filter            "FILE_TYPE == \"Data Files\" || FILE_TYPE == \"Memory File\" || FILE_TYPE == \"Memory Initialization Files\" || FILE_TYPE == \"Coefficient Files\""

  # embedded file extension types 
  variable s_embedded_files_filter
  set s_embedded_files_filter        "FILE_TYPE == \"BMM\" || FILE_TYPE == \"ELF\""

  # non-hdl data files filter
  variable s_non_hdl_data_files_filter
  set s_non_hdl_data_files_filter \
               "FILE_TYPE != \"Verilog\"                      && \
                FILE_TYPE != \"SystemVerilog\"                && \
                FILE_TYPE != \"Verilog Header\"               && \
                FILE_TYPE != \"Verilog/SystemVerilog Header\" && \
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

  # wrapper file for executing user tcl
  set a_sim_vars(s_compile_pre_tcl_wrapper)  "vivado_wc_pre"

  variable a_sim_cache_result
  array unset a_sim_cache_result

  variable a_sim_cache_all_design_files_obj
  array unset a_sim_cache_all_design_files_obj

  variable a_sim_cache_all_bd_files
  array unset a_sim_cache_all_bd_files

  variable a_sim_cache_parent_comp_files
  array unset a_sim_cache_parent_comp_files

  variable a_sim_cache_ip_repo_header_files
  array unset a_sim_cache_ip_repo_header_files

  variable a_sim_cache_lib_info
  array unset a_sim_cache_lib_info

  variable a_shared_library_path_coln
  array unset a_shared_library_path_coln

  variable a_sim_sv_pkg_libs [list]

}

proc usf_create_options { simulator opts } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # create options
  xcs_create_fs_options_spec $simulator $opts

  if { ![get_property IS_READONLY [current_project]] } {
    # simulation fileset objects
    foreach fs_obj [get_filesets -filter {FILESET_TYPE == SimulationSrcs}] {
      xcs_set_fs_options $fs_obj $simulator $opts
    }
  }
}

proc usf_get_include_file_dirs { global_files_str { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_valid_ip_extns
  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_all_bd_files
  set launch_dir $a_sim_vars(s_launch_dir)
  set d_dir_names [dict create]
  set vh_files [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xcs_is_ip $tcl_obj $l_valid_ip_extns] } {
    set vh_files [usf_get_incl_files_from_ip $tcl_obj]
  } else {
    set filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\")"
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
    set vh_file_obj {}
    if { [info exists a_sim_cache_all_design_files_obj($vh_file)] } {
      set vh_file_obj $a_sim_cache_all_design_files_obj($vh_file)
    } else {
      set vh_file_obj [lindex [get_files -all -quiet [list "$vh_file"]] 0]
    }
    # set vh_file [extract_files -files [list "$vh_file"] -base_dir $launch_dir/ip_files]
    if { [get_param project.enableCentralSimRepo] } {
      set b_is_bd 0
      if { [info exists a_sim_cache_all_bd_files($vh_file)] } {
        set b_is_bd 1
      } else {
        set b_is_bd [xcs_is_bd_file $vh_file]
        if { $b_is_bd } {
          set a_sim_cache_all_bd_files($vh_file) $b_is_bd
        }
      }
      set used_in_values [get_property "USED_IN" $vh_file_obj]
      if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
        set vh_file [xcs_fetch_header_from_dynamic $vh_file $b_is_bd $a_sim_vars(dynamic_repo_dir)]
      } else {
        if { $b_is_bd } {
          set vh_file [xcs_fetch_ipi_static_header_file $vh_file_obj $vh_file $a_sim_vars(ipstatic_dir) $a_sim_vars(s_ip_repo_dir)]
        } else {
          set vh_file_path [xcs_fetch_ip_static_header_file $vh_file $vh_file_obj $a_sim_vars(ipstatic_dir) $a_sim_vars(s_ip_repo_dir)]
          if { $a_sim_vars(b_use_static_lib) } {
            if { [file exists $vh_file_path] } {
              set vh_file $vh_file_path
            }
          } else {
            set vh_file $vh_file_path 
          }
        }
      }
    }
    set dir [file normalize [file dirname $vh_file]]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[xcs_resolve_file_path $dir $a_sim_vars(s_launch_dir)]"
     } else {
       if { $ref_dir } {
        set dir "[xcs_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
      } else {
        set dir "[xcs_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
      }
    }
    dict append d_dir_names $dir
  }
  return [dict keys $d_dir_names]
}

proc usf_get_other_verilog_options { global_files_str opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  variable a_sim_vars
  set dir $a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $a_sim_vars(s_simset)]

  # include_dirs
  set unique_incl_dirs [list]
  set incl_dir_str [xcs_resolve_incl_dir_property_value [get_property "INCLUDE_DIRS" [get_filesets $fs_obj]]]
  foreach incl_dir [split $incl_dir_str "|"] {
    if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
      lappend unique_incl_dirs $incl_dir
      if { $a_sim_vars(b_absolute_path) } {
        set incl_dir "[xcs_resolve_file_path $incl_dir $dir]"
      } else {
        set incl_dir "[xcs_get_relative_file_path $incl_dir $dir]"
      }
      lappend opts "-i \"$incl_dir\""
    }
  }

  # include dirs from design source set
  set linked_src_set [get_property "SOURCE_SET" [get_filesets $fs_obj]]
  if { {} != $linked_src_set } {
    set src_fs_obj [get_filesets $linked_src_set]
    set incl_dir_str [xcs_resolve_incl_dir_property_value [get_property "INCLUDE_DIRS" [get_filesets $src_fs_obj]]]
    foreach incl_dir [split $incl_dir_str "|"] {
      if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
        lappend unique_incl_dirs $incl_dir
        if { $a_sim_vars(b_absolute_path) } {
          set incl_dir "[xcs_resolve_file_path $incl_dir $dir]"
        } else {
          set incl_dir "[xcs_get_relative_file_path $incl_dir $dir]"
        }
        lappend opts "-i \"$incl_dir\""
      }
    }
  }

  # --include
  set prefix_ref_dir "false"
  foreach incl_dir [concat [usf_get_include_file_dirs $global_files_str $prefix_ref_dir] [xcs_get_vip_include_dirs]] {
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
      set str "$name="
      if { [string length $val] > 0 } {
        set str "$str$val"
      }
      lappend opts "-d \"$str\""
    }
  }
}

proc usf_get_files_for_compilation { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compile_order_files
  variable l_compile_order_files_uniq

  upvar $global_files_str_arg global_files_str

  set sim_flow $a_sim_vars(s_simulation_flow)

  set design_files [list] 
  if { ({behav_sim} == $sim_flow) } {
    set design_files [usf_get_files_for_compilation_behav_sim $global_files_str]
  } elseif { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    set design_files [usf_get_files_for_compilation_post_sim $global_files_str]

    # prepend design files from behavioral for RTL kernel simulation
    if { [info exists a_sim_vars(b_int_rtl_kernel_mode)] } {
      if { $a_sim_vars(b_int_rtl_kernel_mode) } {
        set behav_design_files [usf_get_files_for_compilation_behav_sim $global_files_str]
        set design_files [concat $behav_design_files $design_files]
      }
    }
  }
  set l_compile_order_files_uniq [xcs_uniquify_cmd_str $l_compile_order_files]
  return $design_files
}

proc usf_get_files_for_compilation_behav_sim { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compile_order_files
  variable l_valid_ip_extns
  variable l_compiled_libraries
  upvar $global_files_str_arg global_files_str

  set files          [list]
  set l_compile_order_files [list]
  set target_obj     $a_sim_vars(sp_tcl_obj)
  set simset_obj     [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]
  set linked_src_set [get_property "SOURCE_SET" $simset_obj]
  set target_lang    [get_property "TARGET_LANGUAGE" [current_project]]

  # get global include file paths
  set incl_file_paths [list]
  set incl_files      [list]
  send_msg_id USF-XSim-097 INFO "Finding global include files..."
  usf_get_global_include_files incl_file_paths incl_files

  set global_incl_files $incl_files
  set global_files_str [usf_get_global_include_file_cmdstr incl_files]

  set other_ver_opts [list]
  usf_get_other_verilog_options $global_files_str other_ver_opts

  # if xilinx_vip not referenced, compile it locally
  if { ([lsearch -exact $l_compiled_libraries "xilinx_vip"] == -1) } {
    variable a_sim_sv_pkg_libs
    if { [llength $a_sim_sv_pkg_libs] > 0 } {
      set incl_dir_opts "--include \\\"[xcs_get_vip_include_dirs]\\\""
      foreach file [xcs_get_xilinx_vip_files] {
        set file_type "SystemVerilog"
        set g_files $global_files_str
        set cmd_str [usf_get_file_cmd_str $file $file_type true $g_files incl_dir_opts "" "xilinx_vip"]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }
  }

  set b_compile_xpm_library 1
  # reference XPM modules from precompiled libs if param is set
  set b_reference_xpm_library 0
  [catch {set b_reference_xpm_library [get_param project.usePreCompiledXPMLibForSim]} err]

  # for precompile flow, if xpm library not found from precompiled libs, compile it locally
  # for non-precompile flow, compile xpm locally and do not reference precompiled xpm library
  if { $b_reference_xpm_library } {
    if { $a_sim_vars(b_use_static_lib) } {
      if { ([lsearch -exact $l_compiled_libraries "xpm"] == -1) } {
        set b_reference_xpm_library 0
      }
    } else {
      set b_reference_xpm_library 0
    }
  }

  if { $b_reference_xpm_library } {
    set b_compile_xpm_library 0
  }

  if { $b_compile_xpm_library } {
    variable l_xpm_libraries
    set b_using_xpm_libraries false
    foreach library $l_xpm_libraries {
      foreach file [rdi::get_xpm_files -library_name $library] {
        set file_type "SystemVerilog"
        set g_files $global_files_str
        set cmd_str [usf_get_file_cmd_str $file $file_type true $g_files other_ver_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
          set b_using_xpm_libraries true
        }
      }
    }
    if { $b_using_xpm_libraries } {
      set xpm_library [xcs_get_common_xpm_library]
      set common_xpm_vhdl_files [xcs_get_common_xpm_vhdl_files]
      foreach file $common_xpm_vhdl_files {
        set file_type "VHDL"
        set g_files {}
        set b_is_xpm true
        set cmd_str [usf_get_file_cmd_str $file $file_type $b_is_xpm $g_files other_ver_opts $xpm_library]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }
  }

  # prepare command line args for fileset files
  if { [xcs_is_fileset $target_obj] } {
    set used_in_val "simulation"
    switch [get_property "FILESET_TYPE" [get_filesets $target_obj]] {
      "DesignSrcs"     { set used_in_val "synthesis" }
      "SimulationSrcs" { set used_in_val "simulation"}
      "BlockSrcs"      { set used_in_val "synthesis" }
    }

    set b_add_sim_files 1
    # add files from block filesets
    if { {} != $linked_src_set } {
      if { [get_param project.addBlockFilesetFilesForUnifiedSim] } {
        usf_add_block_fs_files $global_files_str other_ver_opts files l_compile_order_files
      }
    }
    # add files from simulation compile order
    if { {All} == $a_sim_vars(src_mgmt_mode) } {
      send_msg_id USF-XSim-098 INFO "Fetching design files from '$target_obj'..."
      foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $target_obj]] {
        if { [xcs_is_global_include_file $global_files_str $file] } { continue }
        set file_type [get_property "FILE_TYPE" $file]
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
        set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files other_ver_opts]
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
          send_msg_id USF-XSim-100 INFO "Fetching design files from '$srcset_obj'...(this may take a while)..."
          foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $srcset_obj]] {
            set file_type [get_property "FILE_TYPE" $file]
            if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
            set g_files $global_files_str
            if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
            set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files other_ver_opts]
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
      send_msg_id USF-XSim-101 INFO "Fetching design files from '$a_sim_vars(s_simset)'..."
      foreach file [get_files -quiet -all -of_objects [get_filesets $a_sim_vars(s_simset)]] {
        set file_type [get_property "FILE_TYPE" $file]
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
        if { [get_property "IS_AUTO_DISABLED" $file]} { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
        set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files other_ver_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }
  } elseif { [xcs_is_ip $target_obj $l_valid_ip_extns] } {
    # prepare command line args for fileset ip files
    send_msg_id USF-XSim-102 INFO "Fetching design files from IP '$target_obj'..."
    set ip_filename [file tail $target_obj]
    foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet $ip_filename]] {
      set file_type [get_property "FILE_TYPE" $file]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files other_ver_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  }

  if { $a_sim_vars(b_int_systemc_mode) } {
    # design contain systemc sources?
    set simulator "xsim"
    set prefix_ref_dir false
    set sc_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC\")"
    set cpp_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"CPP\")"
    set c_filter   "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C\")"

    # fetch systemc files
    set sc_files [xcs_get_sc_files $sc_filter]
    if { [llength $sc_files] > 0 } {
      set g_files {}
      set l_incl_dir_opts {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      foreach file $sc_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }
        # set flag
        if { !$a_sim_vars(b_contain_systemc_sources) } {
          set a_sim_vars(b_contain_systemc_sources) true
        }

        # is dynamic? process
        set used_in_values [get_property "USED_IN" [lindex [get_files -quiet -all [list "$file"]] 0]]
        if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
          set file_type "SystemC"
          set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files l_incl_dir_opts]
          if { {} != $cmd_str } {
            lappend files $cmd_str
            lappend compile_order_files $file
          }
        }
      }
    }

    # fetch cpp files
    set cpp_files [get_files -quiet -all -filter $cpp_filter]
    if { [llength $cpp_files] > 0 } {
      set g_files {}
      set l_incl_dir_opts {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      foreach file $cpp_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }
        set used_in_values [get_property "USED_IN" [lindex [get_files -quiet -all [list "$file"]] 0]]
        # is HLS source?
        if { [lsearch -exact $used_in_values "c_source"] != -1 } {
          continue
        }
        # set flag
        if { !$a_sim_vars(b_contain_cpp_sources) } {
          set a_sim_vars(b_contain_cpp_sources) true
        }
        # is dynamic? process
        if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
          set file_type "CPP"
          set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files l_incl_dir_opts]
          if { {} != $cmd_str } {
            lappend files $cmd_str
            lappend compile_order_files $file
          }
        }
      }
    }

    # fetch c files
    set c_files [get_files -quiet -all -filter $c_filter]
    if { [llength $c_files] > 0 } {
      set g_files {}
      set l_incl_dir_opts {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      foreach file $c_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }
        set used_in_values [get_property "USED_IN" [lindex [get_files -quiet -all [list "$file"]] 0]]
        # is HLS source?
        if { [lsearch -exact $used_in_values "c_source"] != -1 } {
          continue
        }
        # set flag
        if { !$a_sim_vars(b_contain_c_sources) } {
          set a_sim_vars(b_contain_c_sources) true
        }
        # is dynamic? process
        if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
          set file_type "C"
          set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files l_incl_dir_opts]
          if { {} != $cmd_str } {
            lappend files $cmd_str
            lappend compile_order_files $file
          }
        }
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
  variable l_valid_ip_extns
  upvar $global_files_str_arg global_files_str

  set files         [list]
  set l_compile_order_files [list]
  set netlist_file  $a_sim_vars(s_netlist_file)
  set target_obj    $a_sim_vars(sp_tcl_obj)
  set target_lang   [get_property "TARGET_LANGUAGE" [current_project]]

  # get global include file paths
  set incl_file_paths [list]
  set incl_files      [list]
  usf_get_global_include_files incl_file_paths incl_files

  set global_incl_files $incl_files
  set global_files_str [usf_get_global_include_file_cmdstr incl_files]

  set other_ver_opts [list]
  usf_get_other_verilog_options $global_files_str other_ver_opts

  if { {} != $netlist_file } {
    set file_type "Verilog"
    set extn [file extension $netlist_file]
    if { {.sv} == $extn } {
      set file_type "SystemVerilog"
    } elseif { {.vhd} == $extn } {
      set file_type "VHDL"
    }
    set cmd_str [usf_get_file_cmd_str $netlist_file $file_type false {} other_ver_opts]
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
  #  set cmd_str [usf_get_file_cmd_str $file $file_type false {} other_ver_opts]
  #  if { {} != $cmd_str } {
  #    lappend files $cmd_str
  #    lappend l_compile_order_files $file
  #  }
  #}
  #set verilog_filter "USED_IN_TESTBENCH == 1 && FILE_TYPE == \"Verilog\" && FILE_TYPE == \"Verilog Header\" && FILE_TYPE == \"Verilog/SystemVerilog Header\""
  #set verilog_filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"Verilog\" || FILE_TYPE == \"SystemVerilog\")"
  #foreach file [usf_get_testbench_files_from_ip $verilog_filter] {
  #  if { [lsearch -exact [list_property $file] {FILE_TYPE}] == -1 } {
  #    continue;
  #  }
  #  #set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
  #  set file_type [get_property "FILE_TYPE" $file]
  #  set cmd_str [usf_get_file_cmd_str $file $file_type false {} other_ver_opts]
  #  if { {} != $cmd_str } {
  #    lappend files $cmd_str
  #    lappend l_compile_order_files $file
  #  }
  #}

  # prepare command line args for fileset files
  if { [xcs_is_fileset $target_obj] } {

    # 851957 - if simulation and design source file tops are same (no testbench), skip adding simset files. Just pass the netlist above.
    set src_fs_top [get_property top [current_fileset]]
    set sim_fs_top [get_property top [get_filesets $a_sim_vars(s_simset)]]
    if { $src_fs_top == $sim_fs_top } {
      return $files   
    }

    # add additional files from simulation fileset
    foreach file [get_files -compile_order sources -used_in synthesis_post -of_objects [get_filesets $a_sim_vars(s_simset)]] {
      set file_type [get_property "FILE_TYPE" $file]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
      #if { [get_property "IS_AUTO_DISABLED" $file]} { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files other_ver_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  } elseif { [xcs_is_ip $target_obj $l_valid_ip_extns] } {
    # prepare command line args for fileset ip files
    set ip_filename [file tail $target_obj]
    foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]] {
      set file_type [get_property "FILE_TYPE" $file]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL} != $file_type) } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files other_ver_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  }
  return $files
}

proc usf_add_block_fs_files { global_files_str other_ver_opts_arg files_arg compile_order_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $other_ver_opts_arg other_ver_opts
  upvar $files_arg files
  upvar $compile_order_files_arg compile_order_files

  set vhdl_filter "FILE_TYPE == \"VHDL\" || FILE_TYPE == \"VHDL 2008\""
  foreach file [xcs_get_files_from_block_filesets $vhdl_filter] {
    set file_type [get_property "FILE_TYPE" $file]
    set cmd_str [usf_get_file_cmd_str $file $file_type false {} other_ver_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend compile_order_files $file
    }
  }
  set verilog_filter "FILE_TYPE == \"Verilog\" || FILE_TYPE == \"SystemVerilog\""
  foreach file [xcs_get_files_from_block_filesets $verilog_filter] {
    set file_type [get_property "FILE_TYPE" $file]
    set cmd_str [usf_get_file_cmd_str $file $file_type false $global_files_str other_ver_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend compile_order_files $file
    }
  }
}

proc usf_launch_script { simulator step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set extn [xcs_get_script_extn "xsim"]
  set scr_file ${step}$extn
  set run_dir $a_sim_vars(s_launch_dir)

  set shell_script_file [file normalize [file join $run_dir $scr_file]]
  xcs_make_file_executable $shell_script_file

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
  set display_step [string toupper $step]
  if { "$display_step" == "COMPILE" } {
    set display_step "${display_step} and ANALYZE"
  }
  send_msg_id USF-XSim-061 INFO "Executing '${display_step}' step in '$run_dir'"
  set results_log {}
  switch $step {
    {compile} -
    {elaborate} {
      set start_time [clock seconds]
      if {[catch {rdi::run_program $scr_file} error_log]} {
        set faulty_run 1
      }
      set end_time [clock seconds]
      send_msg_id USF-XSim-069 INFO "'$step' step finished in '[expr $end_time - $start_time]' seconds"
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
        [catch {send_msg_id USF-XSim-063 ERROR "Failed to launch $scr_file:$error_log\n"}]
        set faulty_run 1
      }
    }
  }
  cd $cwd
  if { $faulty_run } {
    if { {} == $results_log} {
      set msg "'$step' step failed with error(s) while executing '$shell_script_file' script. Please check that the file has the correct 'read/write/execute' permissions and the Tcl console output for any other possible errors or warnings.\n"
      [catch {send_msg_id USF-XSim-062 ERROR "$msg"}]
    } else {
      [catch {send_msg_id USF-XSim-062 ERROR "'$step' step failed with error(s). Please check the Tcl console output or '$results_log' file for more information.\n"}]
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
      # errors in xvlog?
      set token "xvlog"
      if { [usf_found_errors_in_file $token] } {
        set results_log [file normalize [file join $run_dir "${token}.log"]]
        return 1
      }
      # errors in xvhdl?
      set token "xvhdl"
      if { [usf_found_errors_in_file $token] } {
        set results_log [file normalize [file join $run_dir "${token}.log"]]
        return 1
      }
    }
    {elaborate} {
      # errors in xelab?
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
      send_msg_id USF-XSIM-095 ERROR "Failed to open file to read ($file)\n"
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
      {xvlog}     -
      {xvhdl}     -
      {elaborate} { if { [regexp {^ERROR} $line_str] } { set retval 1;break } }
    }
  }

  if { $retval } {
    set results_log [file normalize [file join $run_dir "${token}.log"]]
    [catch {send_msg_id USF-XSim-099 INFO "Step results log file:'$results_log'\n"}]
    return 1
  }
  return 0
}
}

#
# Low level helper procs
# 
namespace eval ::tclapp::xilinx::xsim {

proc usf_get_global_include_files { incl_file_paths_arg incl_files_arg { ref_dir "true" } } {
  # Summary: find source files marked as global include
  # Argument Usage:
  # Return Value:

  upvar $incl_file_paths_arg incl_file_paths
  upvar $incl_files_arg      incl_files
  variable a_sim_vars
  variable a_sim_cache_all_design_files_obj
  set filesets       [list]
  set dir            $a_sim_vars(s_launch_dir)
  set simset_obj     [get_filesets $a_sim_vars(s_simset)]
  set linked_src_set [get_property "SOURCE_SET" $simset_obj]
  set incl_files_set [list]

  if { {} != $linked_src_set } {
    lappend filesets $linked_src_set
  }
  lappend filesets $simset_obj
  # find verilog files marked as global include and not user disabled
  set filter "(FILE_TYPE == \"Verilog\"                      || \
               FILE_TYPE == \"Verilog Header\"               || \
               FILE_TYPE == \"Verilog/SystemVerilog Header\" || \
               FILE_TYPE == \"Verilog Template\")            && \
              (IS_GLOBAL_INCLUDE == 1 && IS_USER_DISABLED == 0)"
  foreach fs_obj $filesets {
    foreach vh_file [get_files -quiet -all -of_objects [get_filesets $fs_obj] -filter $filter] {
      set file_obj {}
      if { [info exists a_sim_cache_all_design_files_obj($vh_file)] } {
        set file_obj $a_sim_cache_all_design_files_obj($vh_file)
      } else {
        set file_obj [lindex [get_files -quiet -all [list "$vh_file"]] 0]
      }
      set vh_file [file normalize [string map {\\ /} $vh_file]]
      if { [lsearch -exact $incl_files_set $vh_file] == -1 } {
        lappend incl_files_set $vh_file
        lappend incl_files     $vh_file
        set incl_file_path [file normalize [string map {\\ /} [file dirname $vh_file]]]
        if { $a_sim_vars(b_absolute_path) } {
          set incl_file_path "[xcs_resolve_file_path $incl_file_path $dir]"
        } else {
          if { $ref_dir } {
           set incl_file_path "[xcs_get_relative_file_path $incl_file_path $dir]"
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
  set filter "FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\""
  set vh_files [get_files -quiet -all -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    lappend incl_files $file
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
  set filter "FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\""
  set vh_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    # set file [extract_files -files [list "$file"] -base_dir $launch_dir/ip_files]
    set dir [file dirname $file]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[xcs_resolve_file_path $dir $a_sim_vars(s_launch_dir)]"
    } else {
      set dir "[xcs_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
    }
    lappend incl_dirs $dir
  }
  return $incl_dirs
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

proc usf_get_file_cmd_str { file file_type b_xpm global_files_str other_ver_opts_arg {xpm_library {}} {xv_lib {}}} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $other_ver_opts_arg other_ver_opts
  variable a_sim_cache_all_design_files_obj
  set dir             $a_sim_vars(s_launch_dir)
  set b_absolute_path $a_sim_vars(b_absolute_path)
  set cmd_str {}
  set associated_library $a_sim_vars(default_top_library)
  set file_obj {}
  if { [info exists a_sim_cache_all_design_files_obj($file)] } {
    set file_obj $a_sim_cache_all_design_files_obj($file)
  } else {
    set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
  }
  if { {} != $file_obj } {
    if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
      set associated_library [get_property "LIBRARY" $file_obj]
    }
  } else { ; # File object is not defined. Check if this is an XPM file...
    if { ($b_xpm) && ([string length $xpm_library] != 0)} {
      set associated_library $xpm_library
    }
  }

  if { {} != $xv_lib } {
    set associated_library $xv_lib
  }

  set b_static_ip_file 0
  set ip_file {}
  if { !$b_xpm } {
    set ip_file [xcs_cache_result {xcs_get_top_ip_filename $file}]
    set file [usf_get_ip_file_from_repo $ip_file $file $associated_library $dir b_static_ip_file]
  }

  set compiler [xcs_get_compiler_name "xsim" $file_type]
  set arg_list [list]
  if { [string length $compiler] > 0 } {
    lappend arg_list $compiler
    if { $a_sim_vars(b_group_files_by_library) } {
      set arg_list [linsert $arg_list end "$associated_library" "$global_files_str"]
    } else {
      set arg_list [linsert $arg_list end "$associated_library" "$global_files_str" "\"$file\""]
    }
  }
 
  # append other options (-i, --include, -d) for verilog sources 
  if { ({verilog} == $compiler) || ({sv} == $compiler) } {
    set arg_list [concat $arg_list $other_ver_opts]
  }

  set file_str [join $arg_list " "]
  set type [xcs_get_file_type_category $file_type]
  set cmd_str "$type|$file_type|$associated_library|$file_str|$file|$b_static_ip_file"
  return $cmd_str
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
      set src_file "[xcs_resolve_file_path $src_file $launch_dir]"
    } else {
      set src_file "[xcs_get_relative_file_path $src_file $launch_dir]"
    }
    return $src_file
  }

  if { ({} != $a_sim_vars(dynamic_repo_dir)) && ([file exist $a_sim_vars(dynamic_repo_dir)]) } {
    set b_is_static 0
    set b_is_dynamic 0
    set src_file [usf_get_source_from_repo $ip_file $src_file $launch_dir b_is_static b_is_dynamic]
    set b_static_ip_file $b_is_static
    if { (!$b_is_static) && (!$b_is_dynamic) } {
      #send_msg_id USF-XSim-056 "CRITICAL WARNING" "IP file is neither static or dynamic:'$src_file'\n"
    }
    # phase-2
    if { $b_is_static } {
      set b_static_ip_file 1
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
  variable l_compiled_libraries
  variable l_local_design_libraries
  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_all_bd_files
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
  if {[regexp -nocase {^\$ref_dir} $src_file]} {
    set b_add_ref 1
    set src_file [string range $src_file 9 end]
    set src_file "$src_file"
  }
  #puts src_file=$src_file
  set filename [file tail $src_file]
  #puts ip_file=$ip_file
  set ip_name [file root [file tail $ip_file]] 

  set full_src_file_path [xcs_find_file_from_compile_order $ip_name $src_file]
  #puts ful_file=$full_src_file_path
  set full_src_file_obj {}
  if { [info exists a_sim_cache_all_design_files_obj($full_src_file_path)] } {
    set full_src_file_obj $a_sim_cache_all_design_files_obj($full_src_file_path)
  } else {
    set full_src_file_obj [lindex [get_files -quiet -all [list "$full_src_file_path"]] 0]
  }
  if { {} == $full_src_file_obj } {
    return $orig_src_file
  }
  #puts ip_name=$ip_name

  set dst_cip_file $full_src_file_path
  set used_in_values [get_property "USED_IN" $full_src_file_obj]
  set library [get_property "LIBRARY" $full_src_file_obj]
  set b_file_is_static 0
  # is dynamic?
  if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
    set file_extn [file extension $ip_file]
    set b_found_in_repo 0
    set repo_src_file {}
    if { [xcs_cache_result {xcs_is_core_container ${ip_name}${file_extn}}] } {
      set dst_cip_file [xcs_get_dynamic_sim_file_core_container $full_src_file_path $a_sim_vars(dynamic_repo_dir) b_found_in_repo repo_src_file]
    } else {
      set dst_cip_file [xcs_get_dynamic_sim_file_core_classic $full_src_file_path $a_sim_vars(dynamic_repo_dir) b_found_in_repo repo_src_file]
    }
    if { !$b_found_in_repo } {
      #send_msg_id USF-XSim-024 WARNING "Expected IP user file does not exist:'$repo_src_file'!, using from default location:'$full_src_file_path'"
    }
  } else {
    set b_file_is_static 1
  }

  set b_is_dynamic 1
  set b_is_bd_ip 0
  if { [info exists a_sim_cache_all_bd_files($full_src_file_path)] } {
    set b_is_bd_ip 1
  } else {
    set b_is_bd_ip [xcs_is_bd_file $full_src_file_path]
    if { $b_is_bd_ip } {
      set a_sim_cache_all_bd_files($full_src_file_path) $b_is_bd_ip
    }
  }

  # is static ip file? set flag and return
  #puts ip_name=$ip_name
  set ip_static_file {}
  if { $b_file_is_static } {
    set ip_static_file $full_src_file_path
  }
  if { {} != $ip_static_file } {
    #puts ip_static_file=$ip_static_file
    set b_is_static 0
    set b_is_dynamic 0
    set dst_cip_file $ip_static_file
    
    set b_process_file 1
    if { $a_sim_vars(b_use_static_lib) } {
      # use pre-compiled lib
      if { [lsearch -exact $l_compiled_libraries $library] != -1 } {
        set b_process_file 0
        set b_is_static 1
      } else {
        # add this library to have the new library linkage in mapping file
        if { [lsearch -exact $l_local_design_libraries $library] == -1 } {
          lappend l_local_design_libraries $library
        }
      }
    }

    if { $b_process_file } {
      if { $b_is_bd_ip } {
        set dst_cip_file [xcs_fetch_ipi_static_file $full_src_file_obj $ip_static_file $a_sim_vars(ipstatic_dir)]
      } else {
        # get the parent composite file for this static file
        set parent_comp_file [get_property parent_composite_file -quiet $full_src_file_obj]

        # calculate destination path
        set dst_cip_file [xcs_find_ipstatic_file_path $full_src_file_obj $ip_static_file $parent_comp_file $a_sim_vars(ipstatic_dir)]

        # skip if file exists
        if { ({} == $dst_cip_file) || (![file exists $dst_cip_file]) } {
          # if parent composite file is empty, extract to default ipstatic dir (the extracted path is expected to be
          # correct in this case starting from the library name (e.g fifo_generator_v13_0_0/hdl/fifo_generator_v13_0_rfs.vhd))
          if { {} == $parent_comp_file } {
            set dst_cip_file [extract_files -no_ip_dir -quiet -files [list "$full_src_file_obj"] -base_dir $a_sim_vars(ipstatic_dir)]
            #puts extracted_file_no_pc=$dst_cip_file
          } else {
            # parent composite is not empty, so get the ip output dir of the parent composite and subtract it from source file
            set parent_ip_name [file root [file tail $parent_comp_file]]
            set ip_output_dir [get_property ip_output_dir [get_ips -all $parent_ip_name]]
            #puts src_ip_file=$ip_static_file
  
            # get the source ip file dir
            set src_ip_file_dir [file dirname $ip_static_file]
  
            # strip the ip_output_dir path from source ip file and prepend static dir
            set lib_dir [xcs_get_sub_file_path $src_ip_file_dir $ip_output_dir]
            set target_extract_dir [file normalize [file join $a_sim_vars(ipstatic_dir) $lib_dir]]
            #puts target_extract_dir=$target_extract_dir
  
            set dst_cip_file [extract_files -no_path -quiet -files [list "$full_src_file_obj"] -base_dir $target_extract_dir]
            #puts extracted_file_with_pc=$dst_cip_file
          }
        }
      }
    }
  }

  if { [file exist $dst_cip_file] } {
    if { $a_sim_vars(b_absolute_path) } {
      set dst_cip_file "[xcs_resolve_file_path $dst_cip_file $launch_dir]"
    } else {
      if { $b_add_ref } {
        set dst_cip_file "\$ref_dir/[xcs_get_relative_file_path $dst_cip_file $launch_dir]"
      } else {
        set dst_cip_file "[xcs_get_relative_file_path $dst_cip_file $launch_dir]"
      }
    }
    if { $b_wrap_in_quotes } {
      set dst_cip_file "\"$dst_cip_file\""
    }
    set orig_src_file $dst_cip_file
  }
  return $orig_src_file
}
}
