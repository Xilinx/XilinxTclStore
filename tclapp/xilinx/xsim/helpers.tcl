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
  variable a_sim_mode_types

  ########################
  # initialize common vars
  ########################
  xcs_set_common_vars a_sim_vars a_sim_mode_types
  xcs_set_common_sysc_vars a_sim_vars

  set a_sim_vars(compiled_library_dir)       {}

  set a_sim_vars(s_simlib_dir)               {}
  set a_sim_vars(s_snapshot)                 {}
  set a_sim_vars(s_dbg_sw)                   {}
  set a_sim_vars(sp_xlnoc_bd_obj)            {}

  set a_sim_vars(b_exec_step)                0
  set a_sim_vars(b_int_setup_sim_vars)       0
  set a_sim_vars(b_int_use_ini_file)         0
  set a_sim_vars(b_int_bind_sip_cores)       0

  set a_sim_vars(b_int_rtl_kernel_mode)      0
  set a_sim_vars(b_compile_simmodels)        0
  set a_sim_vars(b_contain_sv_srcs)          0

  set a_sim_vars(script_cmt_tag)             "REM"
  set a_sim_vars(compiled_design_lib)        "xsim.dir"
  set a_sim_vars(ubuntu_lib_dir)             "/usr/lib/x86_64-linux-gnu"

  set a_sim_vars(run_logs_compile)           [list "compile.log" "xvlog.log" "xvhdl.log" "xsc.log"]
  set a_sim_vars(run_logs_elaborate)         [list elaborate.log]
  set a_sim_vars(run_logs_simulate)          [list simulate.log]
  set a_sim_vars(run_logs)                   [concat $a_sim_vars(run_logs_compile) $a_sim_vars(run_logs_elaborate) $a_sim_vars(run_logs_simulate)]

  set a_sim_vars(b_gcc_version)              0

  ###################
  # initialize arrays
  ###################
  variable l_compile_order_files             [list]
  variable l_compile_order_files_uniq        [list]
  variable l_design_files                    [list]
  variable l_compiled_libraries              [list]
  variable l_local_design_libraries          [list]
  variable l_systemc_incl_dirs               [list]
  variable l_ip_static_libs                  [list]
  variable l_xpm_libraries                   [list]
  variable l_hard_blocks                     [list]
  variable a_sim_sv_pkg_libs                 [list]

  variable a_sim_cache_result
  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_all_ip_obj
  variable a_sim_cache_all_bd_files
  variable a_sim_cache_parent_comp_files
  variable a_sim_cache_lib_info
  variable a_sim_cache_lib_type_info
  variable a_sim_cache_ip_repo_header_files
  variable a_shared_library_path_coln
  variable a_shared_library_mapping_path_coln
  variable a_ip_lib_ref_coln
  variable a_pre_compiled_source_info
  variable a_locked_ips
  variable a_custom_ips

  array unset a_sim_cache_result
  array unset a_sim_cache_all_design_files_obj
  array unset a_sim_cache_all_ip_obj
  array unset a_sim_cache_all_bd_files
  array unset a_sim_cache_parent_comp_files
  array unset a_sim_cache_lib_info
  array unset a_sim_cache_lib_type_info
  array unset a_sim_cache_ip_repo_header_files
  array unset a_shared_library_path_coln
  array unset a_shared_library_mapping_path_coln
  array unset a_ip_lib_ref_coln
  array unset a_pre_compiled_source_info
  array unset a_locked_ips
  array unset a_custom_ips

  #######################
  # initialize param vars
  #######################
  xcs_set_common_param_vars
  set a_sim_vars(b_ref_sysc_lib_env)   [get_param "project.refSystemCLibPathWithXilinxEnv"]
  set a_sim_vars(b_enable_netlist_sim) [get_param "project.enableNetlistSimulationForVersal"]
}

proc usf_create_options { simulator opts } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # create options
  xcs_create_fs_options_spec $simulator $opts

  if { ![get_property "is_readonly" [current_project]] } {
    # simulation fileset objects
    foreach fs [get_filesets -filter {FILESET_TYPE == SimulationSrcs}] {
      xcs_set_fs_options $fs $simulator $opts
    }
  }
}

proc usf_get_include_file_dirs { global_files_str { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_all_bd_files

  set d_dir_names [dict create]
  set vh_files [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)

  if { [xcs_is_ip $tcl_obj [xcs_get_valid_ip_extns]] } {
    set vh_files [xcs_get_incl_files_from_ip $tcl_obj]
  } else {
    set filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\")"
    set vh_files [get_files -all -quiet -filter $filter]
  }

  # append global files (if any)
  if { {} != $global_files_str } {
    set global_files [split $global_files_str { }]
    foreach g_file $global_files {
      set g_file [string trim $g_file {\"}]
      if { [info exists a_sim_cache_all_design_files_obj($g_file)] } {
        lappend vh_files $a_sim_cache_all_design_files_obj($g_file)
      } else {
        lappend vh_files [get_files -quiet -all $g_file]
      }
    }
  }

  foreach vh_file $vh_files {
    set vh_file_obj {}
    if { [info exists a_sim_cache_all_design_files_obj($vh_file)] } {
      set vh_file_obj $a_sim_cache_all_design_files_obj($vh_file)
    } else {
      set vh_file_obj [lindex [get_files -all -quiet [list "$vh_file"]] 0]
    }
    # set vh_file [extract_files -files [list "$vh_file"] -base_dir $a_sim_vars(s_launch_dir)/ip_files]
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
      set used_in_values [get_property "used_in" $vh_file_obj]
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

  # include_dirs
  set unique_incl_dirs [list]
  set incl_dir_str [xcs_resolve_incl_dir_property_value [get_property "include_dirs" $a_sim_vars(fs_obj)]]
  foreach incl_dir [split $incl_dir_str "|"] {
    if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
      lappend unique_incl_dirs $incl_dir
      if { $a_sim_vars(b_absolute_path) } {
        set incl_dir "[xcs_resolve_file_path $incl_dir $a_sim_vars(s_launch_dir)]"
      } else {
        set incl_dir "[xcs_get_relative_file_path $incl_dir $a_sim_vars(s_launch_dir)]"
      }
      lappend opts "-i \"$incl_dir\""
    }
  }

  # include dirs from design source set
  set linked_src_set [get_property "source_set" $a_sim_vars(fs_obj)]
  if { {} != $linked_src_set } {
    set src_fs_obj [get_filesets $linked_src_set]
    set incl_dir_str [xcs_resolve_incl_dir_property_value [get_property "include_dirs" [get_filesets $src_fs_obj]]]
    foreach incl_dir [split $incl_dir_str "|"] {
      if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
        lappend unique_incl_dirs $incl_dir
        if { $a_sim_vars(b_absolute_path) } {
          set incl_dir "[xcs_resolve_file_path $incl_dir $a_sim_vars(s_launch_dir)]"
        } else {
          set incl_dir "[xcs_get_relative_file_path $incl_dir $a_sim_vars(s_launch_dir)]"
        }
        lappend opts "-i \"$incl_dir\""
      }
    }
  }

  set intf_incl_dir "[xcs_add_axi_interface_header  $a_sim_vars(b_absolute_path) $a_sim_vars(s_launch_dir)]"
  if { {} != $intf_incl_dir } {
    lappend opts "--include \"$intf_incl_dir\""
  }

  # --include
  set prefix_ref_dir "false"
  foreach incl_dir [concat [usf_get_include_file_dirs $global_files_str $prefix_ref_dir] [xcs_get_vip_include_dirs]] {
    set incl_dir [string map {\\ /} $incl_dir]
    lappend opts "--include \"$incl_dir\""
  }

  # -d (verilog macros)
  set v_defines [get_property "verilog_define" $a_sim_vars(fs_obj)]
  if { [llength $v_defines] > 0 } {
    foreach element $v_defines {
      set key_val_pair [split $element "="]
      set name [lindex $key_val_pair 0]
      set val  [lindex $key_val_pair 1]
      set str "$name"
      if { [string length $val] > 0 } {
        set str "$str=$val"
      }
      lappend opts "-d \"$str\""
    }
  }
}

proc usf_get_files_for_compilation { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $global_files_str_arg global_files_str

  variable a_sim_vars

  variable l_compile_order_files
  variable l_compile_order_files_uniq

  set design_files [list] 
  if { ({behav_sim} == $a_sim_vars(s_simulation_flow)) } {
    set design_files [usf_get_files_for_compilation_behav_sim $global_files_str]
  } elseif { ({post_synth_sim} == $a_sim_vars(s_simulation_flow)) || ({post_impl_sim} == $a_sim_vars(s_simulation_flow)) } {
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

  upvar $global_files_str_arg global_files_str

  variable a_sim_vars

  variable l_compile_order_files
  variable l_compiled_libraries
  variable a_sim_cache_all_design_files_obj

  set files          [list]
  set l_compile_order_files [list]
  set target_obj     $a_sim_vars(sp_tcl_obj)
  set simset_obj     [get_filesets $a_sim_vars(s_simset)]
  set linked_src_set [get_property "source_set" $simset_obj]

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
        set b_reference_xpm_library 0 ; # for pre-compile, xpm lib not found from clibs so don't reference and compile it locally
      }
    } else {
      set b_reference_xpm_library 0 ; # non pre-compile flow, don't reference and compile it locally
    }
  }

  if { $b_reference_xpm_library } {
    set b_compile_xpm_library 0
  }

  if { $b_compile_xpm_library } {
    variable l_xpm_libraries
    set b_using_xpm_libraries false
    foreach library $l_xpm_libraries {
      if { "XPM_NOC" == $library } { continue; }
      if { "AP_LIB" == $library } { continue; }
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
      if { [string equal -nocase $a_sim_vars(simulator_language) "verilog"] == 1 } {
        # do not compile vhdl component file if simulator language is verilog
      } else {
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
  }

  # force xpm noc files compilation
  if { ([lsearch -exact [rdi::get_xpm_libraries] "XPM_NOC"] != -1) } {
    set a_sim_vars(b_dynamic_xpm_noc_compile) 1
    set xpm_library "xpm_noc"
    foreach file [rdi::get_xpm_files -library_name "XPM_NOC"] {
      set file_type "SystemVerilog"
      set g_files $global_files_str
      set cmd_str [usf_get_file_cmd_str $file $file_type true $g_files other_ver_opts $xpm_library]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  }

  # prepare command line args for fileset files
  if { [xcs_is_fileset $target_obj] } {
    set used_in_val "simulation"
    switch [get_property "fileset_type" [get_filesets $target_obj]] {
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
    # add logical NoC files
    set lnoc_files [list]
    [catch {set lnoc_files [rdi::get_logical_noc_files]} err]
    foreach file $lnoc_files {
      set file_type [get_property "file_type" $file]
      if { ({Verilog} == $file_type) || ({SystemVerilog} == $file_type) } {
        set used_in_values [get_property -quiet "USED_IN" $file]
        if { [lsearch -exact $used_in_values "ipstatic"] != -1 } {
          if { $a_sim_vars(b_use_static_lib) } {
            continue;
          }
        }
        set g_files $global_files_str
        set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files other_ver_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }
    # add files from simulation compile order
    if { {All} == $a_sim_vars(src_mgmt_mode) } {
      send_msg_id USF-XSim-098 INFO "Fetching design files from '$target_obj'..."
      foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $target_obj]] {
        if { [xcs_is_global_include_file $global_files_str $file] } { continue }
        set file_type [get_property "file_type" $file]
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) && ({VHDL 2019} != $file_type) } { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
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
            set file_type [get_property "file_type" $file]
            if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) && ({VHDL 2019} != $file_type) } { continue }
            set g_files $global_files_str
            if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
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
      foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $a_sim_vars(s_simset)]] {
        if { [xcs_is_xlnoc_for_synth $file] } { continue }
        set file_type [get_property "file_type" $file]
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) && ({VHDL 2019} != $file_type) } { continue }
        if { [get_property "is_auto_disabled" $file]} { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
        set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files other_ver_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }

    # add logical noc top module file
    set lnoc_top [get_property -quiet logical_noc_top $a_sim_vars(fs_obj)]
    if { {} != $lnoc_top } {
      set lnoc_file "${lnoc_top}.v"
      set file [get_files -all $lnoc_file -of_objects $a_sim_vars(fs_obj)]
      if { {} != $file } {
        set file_type [get_property "file_type" $file]
        if { ({Verilog} == $file_type) || ({SystemVerilog} == $file_type) } {
          set g_files $global_files_str
          set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files other_ver_opts]
          if { {} != $cmd_str } {
            lappend files $cmd_str
            lappend l_compile_order_files $file
          }
        }
      }
    }

  } elseif { [xcs_is_ip $target_obj [xcs_get_valid_ip_extns]] } {
    # prepare command line args for fileset ip files
    send_msg_id USF-XSim-102 INFO "Fetching design files from IP '$target_obj'..."
    set ip_filename [file tail $target_obj]
    set ip_file_obj {}
    if { [info exists a_sim_cache_all_design_files_obj($ip_filename)] } {
      set ip_file_obj $a_sim_cache_all_design_files_obj($ip_filename)
    } else {
      set ip_file_obj [get_files -quiet ${ip_filename}]
    }
    foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet $ip_file_obj]] {
      set file_type [get_property "file_type" $file]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) && ({VHDL 2019} != $file_type) } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files other_ver_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  }

  if { ($a_sim_vars(b_use_static_lib)) && ($a_sim_vars(b_dynamic_xpm_noc_compile)) } {
    variable l_local_design_libraries
    lappend l_local_design_libraries "xpm_noc"
  }

  if { $a_sim_vars(b_int_systemc_mode) } {
    # design contain systemc sources?
    set simulator "xsim"
    set prefix_ref_dir false
    set sc_filter  "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC\")"
    set cpp_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"CPP\")"
    set c_filter   "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C\")"
    set asm_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"ASM\")"

    # fetch systemc files
    set sc_files [xcs_get_c_files $sc_filter $a_sim_vars(b_int_csim_compile_order)]
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
        set file_obj {}
        if { [info exists a_sim_cache_all_design_files_obj($file)] } {
          set file_obj $a_sim_cache_all_design_files_obj($file)
        } else {
          set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
        }
        set used_in_values [get_property "USED_IN" $file_obj]
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
    set cpp_files [xcs_get_c_files $cpp_filter $a_sim_vars(b_int_csim_compile_order)]
    if { [llength $cpp_files] > 0 } {
      set g_files {}
      set l_incl_dir_opts {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      foreach file $cpp_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }
        set used_in_values [get_property "used_in" [lindex [get_files -quiet -all [list "$file"]] 0]]
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
    set c_files [xcs_get_c_files $c_filter $a_sim_vars(b_int_csim_compile_order)]
    if { [llength $c_files] > 0 } {
      set g_files {}
      set l_incl_dir_opts {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      foreach file $c_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }
        set used_in_values [get_property "used_in" [lindex [get_files -quiet -all [list "$file"]] 0]]
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

    # fetch asm files
    set asm_files [xcs_get_c_files $asm_filter $a_sim_vars(b_int_csim_compile_order)]
    if { [llength $asm_files] > 0 } {
      set g_files {}
      set l_incl_dir_opts {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      foreach file $asm_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }
        set used_in_values [get_property "used_in" [lindex [get_files -quiet -all [list "$file"]] 0]]
        # is HLS source?
        if { [lsearch -exact $used_in_values "c_source"] != -1 } {
          continue
        }
        # set flag
        if { !$a_sim_vars(b_contain_asm_sources) } {
          set a_sim_vars(b_contain_asm_sources) true
        }
        # is dynamic? process
        if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
          set file_type "ASM"
          set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files l_incl_dir_opts]
          if { {} != $cmd_str } {
            lappend files $cmd_str
            lappend compile_order_files $file
          }
        }
      }
    }
  }

  # print pre-compiled source info
  if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
    xcs_print_pre_compiled_info $a_sim_vars(s_clibs_dir)
  }

  return $files
}

proc usf_get_files_for_compilation_post_sim { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $global_files_str_arg global_files_str

  variable a_sim_vars

  variable l_compile_order_files

  set files         [list]
  set l_compile_order_files [list]
  set netlist_file  $a_sim_vars(s_netlist_file)
  set target_obj    $a_sim_vars(sp_tcl_obj)

  # get global include file paths
  set incl_file_paths [list]
  set incl_files      [list]
  usf_get_global_include_files incl_file_paths incl_files

  set global_incl_files $incl_files
  set global_files_str [usf_get_global_include_file_cmdstr incl_files]

  set other_ver_opts [list]
  usf_get_other_verilog_options $global_files_str other_ver_opts

  # add netlist sources for post-synth functional simulation
  if { $a_sim_vars(b_enable_netlist_sim) && $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) } {
    usf_add_netlist_sources files l_compile_order_files other_ver_opts
  }

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

  # add files marked for netlist_simulation
  if { $a_sim_vars(b_enable_netlist_sim) && $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) } {
    foreach file_obj [get_files -compile_order sources -used_in simulation -of_objects [get_filesets $a_sim_vars(s_simset)]] {
      if { [get_property -quiet "netlist_simulation" $file_obj] } {
        set file_type [get_property "file_type" $file_obj]
        set cmd_str [usf_get_file_cmd_str $file_obj $file_type false {} other_ver_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file_obj
        }
      }
    }
  }
 
  # add testbench files if any
  #set vhdl_filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"VHDL\" || FILE_TYPE == \"VHDL 2008\")"
  #foreach file [usf_get_testbench_files_from_ip $vhdl_filter] {
  #  if { [lsearch -exact [list_property -quiet $file] {FILE_TYPE}] == -1 } {
  #    continue;
  #  }
  #  #set file_type [get_property "file_type" [lindex [get_files -quiet -all [list "$file"]] 0]]
  #  set file_type [get_property "file_type" $file]
  #  set cmd_str [usf_get_file_cmd_str $file $file_type false {} other_ver_opts]
  #  if { {} != $cmd_str } {
  #    lappend files $cmd_str
  #    lappend l_compile_order_files $file
  #  }
  #}
  #set verilog_filter "USED_IN_TESTBENCH == 1 && FILE_TYPE == \"Verilog\" && FILE_TYPE == \"Verilog Header\" && FILE_TYPE == \"Verilog/SystemVerilog Header\""
  #set verilog_filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"Verilog\" || FILE_TYPE == \"SystemVerilog\")"
  #foreach file [usf_get_testbench_files_from_ip $verilog_filter] {
  #  if { [lsearch -exact [list_property -quiet $file] {FILE_TYPE}] == -1 } {
  #    continue;
  #  }
  #  #set file_type [get_property "file_type" [lindex [get_files -quiet -all [list "$file"]] 0]]
  #  set file_type [get_property "file_type" $file]
  #  set cmd_str [usf_get_file_cmd_str $file $file_type false {} other_ver_opts]
  #  if { {} != $cmd_str } {
  #    lappend files $cmd_str
  #    lappend l_compile_order_files $file
  #  }
  #}

  # prepare command line args for fileset files
  if { [xcs_is_fileset $target_obj] } {

    # 851957 - if simulation and design source file tops are same (no testbench), skip adding simset files. Just pass the netlist above.
    set src_fs_top [get_property "top" [current_fileset]]
    set sim_fs_top [get_property "top" $a_sim_vars(fs_obj)]
    if { $src_fs_top == $sim_fs_top } {
      return $files   
    }

    # add additional files from simulation fileset
    foreach file [get_files -compile_order sources -used_in synthesis_post -of_objects [get_filesets $a_sim_vars(s_simset)]] {
      set file_type [get_property "file_type" $file]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) && ({VHDL 2019} != $file_type) } { continue }
      #if { [get_property "is_auto_disabled" $file]} { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files other_ver_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  } elseif { [xcs_is_ip $target_obj [xcs_get_valid_ip_extns]] } {
    # prepare command line args for fileset ip files
    set ip_filename [file tail $target_obj]
    foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]] {
      set file_type [get_property "file_type" $file]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL} != $file_type) } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
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

  variable a_sim_cache_all_design_files_obj

  set vhdl_filter "FILE_TYPE == \"VHDL\" || FILE_TYPE == \"VHDL 2008\" || FILE_TYPE == \"VHDL 2019\""
  foreach file [xcs_get_files_from_block_filesets $vhdl_filter] {
    if { [info exists a_sim_cache_all_design_files_obj($file)] } {
      set file_obj $a_sim_cache_all_design_files_obj($file)
    } else {
      set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
    }
    set file_type [get_property "file_type" $file_obj]
    set cmd_str [usf_get_file_cmd_str $file $file_type false {} other_ver_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend compile_order_files $file
    }
  }
  set verilog_filter "FILE_TYPE == \"Verilog\" || FILE_TYPE == \"SystemVerilog\""
  foreach file [xcs_get_files_from_block_filesets $verilog_filter] {
    if { [info exists a_sim_cache_all_design_files_obj($file)] } {
      set file_obj $a_sim_cache_all_design_files_obj($file)
    } else {
      set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
    }
    set file_type [get_property "file_type" $file_obj]
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

  set shell_script_file [file normalize [file join $a_sim_vars(s_launch_dir) $scr_file]]
  xcs_make_file_executable $shell_script_file

  if { $a_sim_vars(b_scripts_only) } {
    send_msg_id USF-XSim-060 INFO "Script generated:[file normalize [file join $a_sim_vars(s_launch_dir) $scr_file]]"
    return 0
  }

  # simulate step is launched with direct tcl command 
  if { {simulate} == $step } {
    return 0
  }

  set b_wait 0
  if { $a_sim_vars(b_batch) } {
    set b_wait 1 
  }
  set faulty_run 0
  set cwd [pwd]
  cd $a_sim_vars(s_launch_dir)
  set display_step [string toupper $step]
  if { "$display_step" == "COMPILE" } {
    set display_step "${display_step} and ANALYZE"
  }
  send_msg_id USF-XSim-061 INFO "Executing '${display_step}' step in '$a_sim_vars(s_launch_dir)'"
  set results_log {}
  switch $step {
    {compile} -
    {elaborate} {
      set start_time [clock seconds]
      set error_log {}
      set faulty_run [xcs_exec_script $scr_file error_log]
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

  switch $step {
    {compile} {
      # errors in xvlog?
      set token "xvlog"
      if { [usf_found_errors_in_file $token] } {
        set results_log [file normalize [file join $a_sim_vars(s_launch_dir) "${token}.log"]]
        return 1
      }
      # errors in xvhdl?
      set token "xvhdl"
      if { [usf_found_errors_in_file $token] } {
        set results_log [file normalize [file join $a_sim_vars(s_launch_dir) "${token}.log"]]
        return 1
      }
      # errors in xsc?
      set token "xsc"
      if { [usf_found_errors_in_file $token] } {
        set token "compile"
        set results_log [file normalize [file join $a_sim_vars(s_launch_dir) "${token}.log"]]
        return 1
      }
    }
    {elaborate} {
      # errors in xelab?
      set token "elaborate"
      if { [usf_found_errors_in_file $token] } {
        set results_log [file normalize [file join $a_sim_vars(s_launch_dir) "${token}.log"]]
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
      {xsc}       -
      {elaborate} { if { [regexp {^ERROR} $line_str] } { set retval 1;break } }
    }
  }

  if { $retval } {
    if { "xsc" == $token } {
      set token "compile"
    }
    set results_log [file normalize [file join $a_sim_vars(s_launch_dir) "${token}.log"]]
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
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $incl_file_paths_arg incl_file_paths
  upvar $incl_files_arg      incl_files

  variable a_sim_vars

  variable a_sim_cache_all_design_files_obj

  set filesets       [list]
  set dir            $a_sim_vars(s_launch_dir)
  set simset_obj     [get_filesets $a_sim_vars(s_simset)]
  set linked_src_set [get_property "source_set" $simset_obj]
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
  foreach fs $filesets {
    foreach vh_file [get_files -quiet -all -of_objects [get_filesets $fs] -filter $filter] {
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


proc usf_get_incl_dirs_from_ip { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set incl_dirs [list]
  set ft "FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\""
  set ip_name [file tail $tcl_obj]

  foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $ft] {
    # set file [extract_files -files [list "$file"] -base_dir $a_sim_vars(s_launch_dir)/ip_files]
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
  foreach file $incl_files {
    # set file [extract_files -files [list "$file"] -base_dir $a_sim_vars(s_launch_dir)/ip_files]
    lappend file_str "\"$file\""
  }
  return [join $file_str " "]
}

proc usf_get_file_cmd_str { file file_type b_xpm global_files_str other_ver_opts_arg {xpm_library {}} {xv_lib {}}} {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $other_ver_opts_arg other_ver_opts

  variable a_sim_vars

  variable a_sim_cache_all_design_files_obj

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
    if { [lsearch -exact [list_property -quiet $file_obj] {LIBRARY}] != -1 } {
      set associated_library [get_property "library" $file_obj]
    }
  } else { ; # File object is not defined. Check if this is an XPM file...
    if { $b_xpm } {
      if { [string length $xpm_library] != 0 } {
        set associated_library $xpm_library
      } else {
        set associated_library "xpm"
      }
    }
  }

  if { {} != $xv_lib } {
    set associated_library $xv_lib
  }

  set b_static_ip_file 0
  set ip_file {}
  if { !$b_xpm } {
    set ip_file [xcs_cache_result {xcs_get_top_ip_filename $file}]
    set file [usf_get_ip_file_from_repo $ip_file $file $associated_library $a_sim_vars(s_launch_dir) b_static_ip_file]
  }

  set compiler [xcs_get_compiler_name "xsim" $file_type]
  set arg_list [list]
  if { [string length $compiler] > 0 } {
    lappend arg_list $compiler
    set arg_list [linsert $arg_list end "$associated_library" "$global_files_str"]
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

  upvar $b_is_static_arg b_is_static
  upvar $b_is_dynamic_arg b_is_dynamic

  variable a_sim_vars

  variable l_compiled_libraries
  variable l_local_design_libraries
  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_all_bd_files
  variable a_sim_cache_all_ip_obj 

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
  set used_in_values [xcs_find_used_in_values $full_src_file_obj]
  set library [get_property "library" $full_src_file_obj]
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
      # library found from valid pre-compiled libraries list, so use this pre-compiled version
      if { [lsearch -exact $l_compiled_libraries $library] != -1 } {
        # do not process file and mark this as static
        set b_process_file 0
        set b_is_static 1
       
        #################################################################
        # Pre-compiled version of this IP static source file will be used
        #################################################################
        variable a_pre_compiled_source_info
        set static_ip_filename [file tail $dst_cip_file]
        set static_library     $library
        if { ![info exists a_pre_compiled_source_info($static_ip_filename)] } {
          # store this info for printing/debugging purposes
          set a_pre_compiled_source_info($static_ip_filename) $static_library
        }
       
      } else {
        # library to be compiled locally, add this to the local library linkage collection for mapping purposes
        if { [lsearch -exact $l_local_design_libraries $library] == -1 } {
          lappend l_local_design_libraries $library
          xcs_print_ip_compile_msg $library
        }
      }
    }

    if { $b_process_file } {
      if { $b_is_bd_ip } {
        set dst_cip_file [xcs_fetch_ipi_static_file $full_src_file_obj $ip_static_file $a_sim_vars(ipstatic_dir)]
      } else {
        # get the parent composite file for this static file
        set parent_comp_file [get_property "parent_composite_file" -quiet $full_src_file_obj]

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
            if { [info exists a_sim_cache_all_ip_obj($parent_ip_name)] } {
              set ip_obj $a_sim_cache_all_ip_obj($parent_ip_name)
            } else {
              set ip_obj [get_ips -all $parent_ip_name]
            }
            set ip_output_dir [get_property "ip_output_dir" $ip_obj]
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

proc usf_write_run_script { simulator log_files } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  if {$::tcl_platform(platform) != "unix"} {
    return
  }

  variable a_sim_vars

  # Vivado release info
  set curr_time    [clock format [clock seconds]]
  set version_info [split [version] "\n"]
  set release      [lindex $version_info 0]
  set swbuild      [lindex $version_info 1]
  set copyright    [lindex $version_info 4]
  set copyright_1  [lindex $version_info 5]
  set product      [lindex [split $release " "] 0]
  set version_id   [join [lrange $release 1 end] " "]
  set simulator    [xcs_get_simulator_pretty_name $simulator]
  set desc         "Script to compile, link/elaborate and simulate the design"

  # open file to write
  set extn     ".sh"
  set cmt      "#"
  set filename "run${extn}"
  set file     "$a_sim_vars(s_launch_dir)/$filename"

  set fh 0
  if { [catch {open $file w} fh] } {
    send_msg_id SIM-utils-058 WARNING "Failed to open file for write! '$file'\n"
    return
  }

  # write script contents
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh "[xcs_get_shell_env]"
  } else {
    puts $fh "@echo off"
  }
  puts $fh "$cmt ****************************************************************************"
  puts $fh "$cmt $product (TM) $version_id"
  puts $fh "$cmt"
  puts $fh "$cmt Filename    : $filename"
  puts $fh "$cmt Simulator   : $simulator"
  puts $fh "$cmt Description : $desc"
  puts $fh "$cmt"
  puts $fh "$cmt Generated by $product on $curr_time"
  puts $fh "$cmt $swbuild"
  puts $fh "$cmt"
  puts $fh "$cmt $copyright"
  puts $fh "$cmt $copyright_1"
  puts $fh "$cmt"
  puts $fh "$cmt usage: $filename"
  puts $fh "$cmt"
  puts $fh "$cmt ****************************************************************************"

  # start script code
  puts $fh "\n# Script usage"
  puts $fh "usage()"
  puts $fh "\{"
  puts $fh "  echo -e \"$desc\\n\""
  puts $fh "  echo -e \"Usage: run.sh \[-help\] \[-reset_run\]\\n\""
  puts $fh "  echo -e \"\[-help\]      -- Print help\""
  puts $fh "  echo -e \"\[-reset_run\] -- Delete generated data from the previous run before executing the steps\\n\""
  puts $fh "  exit 1"
  puts $fh "\}"
  puts $fh ""
  puts $fh "# Delete generated files (if any)"
  puts $fh "reset_run()"
  puts $fh "\{"
  set files [join $log_files " "]
  puts $fh "  files_to_remove=($files)"
  puts $fh "  for (( i=0; i<\$\{#files_to_remove\[*\]\}; i++ )); do"
  puts $fh "    file=\"\$\{files_to_remove\[i\]\}\""
  puts $fh "    if \[\[ -e \$file \]\]; then"
  puts $fh "      rm -rf \$file"
  puts $fh "    fi"
  puts $fh "  done"
  puts $fh "  rm -rf ./$a_sim_vars(compiled_design_lib)"
  puts $fh "  mkdir $a_sim_vars(compiled_design_lib)"
  puts $fh "\}"
  puts $fh ""
  puts $fh "# Compile design"
  puts $fh "compile()"
  puts $fh "\{"
  puts $fh "  ./compile${extn}"
  puts $fh "\}"
  puts $fh ""
  puts $fh "# Link/Elaborate design"
  puts $fh "elaborate()"
  puts $fh "\{"
  puts $fh "  ./elaborate${extn}"
  puts $fh "\}"
  puts $fh ""
  puts $fh "# Simulate design"
  puts $fh "simulate()"
  puts $fh "\{"
  puts $fh "  ./simulate${extn}"
  puts $fh "\}"
  puts $fh ""
  puts $fh "# Execute steps"
  puts $fh "run()"
  puts $fh "\{"
  puts $fh "  case \$1 in"
  puts $fh "    \"-reset_run\" )"
  puts $fh "      reset_run"
  puts $fh "      echo -e \"INFO: Simulation generated data deleted.\\n\""
  puts $fh "    ;;"
  puts $fh "    * )"
  puts $fh "    ;;"
  puts $fh "  esac\n"
  puts $fh "  # Exit on step error"
  puts $fh "  set -Eeuo pipefail"
  puts $fh "  compile"
  puts $fh "  elaborate"
  puts $fh "  simulate"
  puts $fh "\}"
  puts $fh ""
  puts $fh "# Check command line args"
  puts $fh "if \[\[ \$# > 1 \]\]; then"
  puts $fh "  echo -e \"error: invalid number of arguments specified (for more information type \"run.sh -h\[elp\]\")\""
  puts $fh "  exit 1"
  puts $fh "fi"
  puts $fh "if \[\[ (\$# == 1 ) && (\$1 != \"-reset_run\" && \$1 != \"-help\" && \$1 != \"-h\") \]\]; then"
  puts $fh "  echo -e \"error: unknown argument '\$1' (for more information type \"run.sh -h\[elp\]\")\""
  puts $fh "  exit 1"
  puts $fh "fi"
  puts $fh "if \[\[ (\$1 == \"-help\" || \$1 == \"-h\") \]\]; then"
  puts $fh "  usage"
  puts $fh "fi\n"
  puts $fh "# Launch script"
  puts $fh "run \$1"

  close $fh
  xcs_make_file_executable $file
}

proc usf_add_netlist_sources { files_arg l_compile_order_files_arg other_ver_opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $other_ver_opts_arg other_ver_opts 
  upvar $files_arg files
  upvar $l_compile_order_files_arg l_compile_order_files

  variable a_sim_vars
  set sim_flow $a_sim_vars(s_simulation_flow)
  
  # contains xlnoc.bd?
  if { {} == $a_sim_vars(sp_xlnoc_bd_obj) } {
    return
  }

  variable a_sim_noc_files_info
  variable a_sim_noc_files_incl_dirs_info

  array unset a_sim_noc_files_info
  array unset a_sim_noc_files_incl_dirs_info

  set l_all_netlist_files [list]

  # add behavioral sources marked for netlist simulation
  if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
    puts "-----------------------------------------------------------------"
    puts "Finding behavioral simulation files marked for netlist simulation"
    puts "-----------------------------------------------------------------"
  }

  # find sources marked for netlist simulation and construct include dirs
  foreach ip_obj [get_ips -quiet -all] {
    if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
      set ipdef [get_property -quiet "ipdef" $ip_obj]
      set vlnv_name [xcs_get_library_vlnv_name $ip_obj $ipdef]
      puts "$ip_obj ($vlnv_name)"
    }
    set l_netlist_files [rdi::get_netlist_sim_files $ip_obj]
    set l_all_netlist_files [concat $l_netlist_files $l_all_netlist_files]
    foreach nf $l_netlist_files {
      set nf_obj [lindex [get_files -all -quiet $nf] 0]
      set file_name [file tail $nf]
      set file_type [get_property -quiet "file_type" $nf_obj]
      if { ($file_type == "Verilog Header") || ($file_type == "Verilog/SystemVerilog Header") } {
        set incl_dir [file dirname $nf_obj]
        if { ![info exists a_sim_noc_files_incl_dirs_info($incl_dir)] } {
          set a_sim_noc_files_incl_dirs_info($incl_dir) "$file_name"
        }
      }
    }
  }
  if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
    puts "-----------------------------------------------------------------"
  }

  # construct include dir arg and append to other verilog options 
  if { [array size a_sim_noc_files_incl_dirs_info] > 0 } {
    foreach {key value} [array get a_sim_noc_files_incl_dirs_info] {
      set incl_dir    $key
      set vh_filename $value
      if { $a_sim_vars(b_absolute_path) } {
        set incl_dir "[xcs_resolve_file_path $incl_dir $a_sim_vars(s_launch_dir)]"
      } else {
        set incl_dir "[xcs_get_relative_file_path $incl_dir $a_sim_vars(s_launch_dir)]"
      }
      set incl_dir [string map {\\ /} $incl_dir]
      lappend other_ver_opts "--include \"$incl_dir\""
    }
  }

  # add netlist sources to prj
  foreach nf $l_all_netlist_files {
    set nf_obj [lindex [get_files -all -quiet $nf] 0]
    set file_name [file tail $nf]
    set file_type [get_property -quiet "file_type" $nf_obj]
    if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) && ({VHDL 2019} != $file_type) } { continue }
    set file_name [file tail $nf]
    if { ![info exists a_sim_noc_files_info($file_name)] } {
      set a_sim_noc_files_info($file_name) "$ip_obj"
      set cmd_str [usf_get_file_cmd_str $nf_obj $file_type false {} other_ver_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $nf_obj
      }
    }
  }

  # add xlnoc.v
  set xlnoc_filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"Verilog\")"
  set xlnoc_file_obj [lindex [get_files -all -quiet "xlnoc.v" -filter $xlnoc_filter] 0] 
  if { {} != $xlnoc_file_obj } {
    set file_type "Verilog"
    set cmd_str [usf_get_file_cmd_str $xlnoc_file_obj $file_type false {} other_ver_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend l_compile_order_files $xlnoc_file_obj
    }
  }

  # add xlnoc sources
  set xlnoc_filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"SystemVerilog\")"
  foreach xlnoc_file_obj [get_files -all -quiet "*xlnoc_*" -filter $xlnoc_filter] {
    set file_type "SystemVerilog"
    set cmd_str [usf_get_file_cmd_str $xlnoc_file_obj $file_type false {} other_ver_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend l_compile_order_files $xlnoc_file_obj
    }
  }
}
}
