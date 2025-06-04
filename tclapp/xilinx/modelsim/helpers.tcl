###############################################################################
#
# helpers.tcl (simulation helper utilities for the 'ModelSim/Questa Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
###############################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::modelsim {
  namespace export usf_create_options
}

namespace eval ::tclapp::xilinx::modelsim {
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

  set a_sim_vars(b_int_csim_compile_order)   0
  set a_sim_vars(compiled_library_dir)       {}

  ###################
  # unitialize arrays
  ###################
  variable l_compile_order_files             [list]
  variable l_compile_order_files_uniq        [list]
  variable l_design_files                    [list]
  variable l_compiled_libraries              [list]
  variable l_local_design_libraries          [list]
  variable l_ip_static_libs                  [list]
  variable l_xpm_libraries                   [list]
  variable a_sim_sv_pkg_libs                 [list]

  variable a_sim_cache_result
  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_all_ip_obj
  variable a_sim_cache_all_bd_files
  variable a_sim_cache_parent_comp_files
  variable a_sim_cache_parent_comp_files
  variable a_ip_lib_ref_coln
  variable a_pre_compiled_source_info
  variable a_locked_ips
  variable a_custom_ips

  array unset a_sim_cache_result
  array unset a_sim_cache_all_design_files_obj
  array unset a_sim_cache_all_ip_obj
  array unset a_sim_cache_all_bd_files
  array unset a_sim_cache_parent_comp_files
  array unset a_sim_cache_parent_comp_files
  array unset a_ip_lib_ref_coln
  array unset a_pre_compiled_source_info
  array unset a_locked_ips
  array unset a_custom_ips

  #######################
  # initialize param vars
  #######################
  xcs_set_common_param_vars
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

proc usf_append_define_generics { def_gen_list tool opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts

  foreach element $def_gen_list {
    set key_val_pair [split $element "="]
    set name [lindex $key_val_pair 0]
    set val  [lindex $key_val_pair 1]
    set str "+define+$name=" 
    # escape '
    if { [regexp {'} $val] } {
      regsub -all {'} $val {\\'} val
    }

    if { [string length $val] > 0 } {
      if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
        set str "$str$val"
      } else {
        set str "$str\"$val\""
      }
    }

    switch -regexp -- $tool {
      "vlog" { lappend opts "$str"  }
    }
  }
}

proc usf_create_do_file { simulator do_filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set do_file [file join $a_sim_vars(s_launch_dir) $do_filename]
  set fh_do 0
  if {[catch {open $do_file w} fh_do]} {
    send_msg_id USF-ModelSim-042 ERROR "Failed to open file to write ($do_file)\n"
  } else {
    set time [get_property "runtime" $a_sim_vars(fs_obj)]
    puts $fh_do "run $time"
  }
  close $fh_do
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
  send_msg_id USF-ModelSim-047 INFO "Finding simulator installation...\n"
  switch -regexp -- $simulator {
    {modelsim} {
      set tool_name "vsim";append tool_name ${tool_extn}
      if { {} == $install_path } {
        set install_path [get_param "simulator.modelsimInstallPath"]
      }
    }
  }
 
  if { {} == $install_path } {
    set bin_path [xcs_get_bin_path $tool_name $path_sep]
    if { {} == $bin_path } {
      set b_halt_flow true
      if { $a_sim_vars(b_scripts_only) } {
        if { $a_sim_vars(b_int_halt_script) } {
          # halt
        } else {
          set b_halt_flow false
        }
      }

      if { $b_halt_flow } {
        [catch {send_msg_id USF-ModelSim-048 ERROR \
          "Failed to locate '$tool_name' executable in the shell environment 'PATH' variable. Please source the settings script included with the installation and retry this operation again.\n"}]
        # IMPORTANT - *** DONOT MODIFY THIS ***
        error "_SIM_STEP_RUN_EXEC_ERROR_"
        # IMPORTANT - *** DONOT MODIFY THIS ***
        return 1
      } else {
        send_msg_id USF-ModelSim-114 WARNING \
          "Simulator executable path could not be located. Please make sure to set this path before launching the scripts.\n"
      }
    } else {
      send_msg_id USF-ModelSim-049 INFO "Using simulator executables from '$bin_path'\n"
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
      send_msg_id USF-ModelSim-050 INFO "Using simulator executables from '$tool_path'\n"
    } else {
      send_msg_id USF-ModelSim-051 ERROR "Path to custom '$tool_name' executable program does not exist:$tool_path'\n"
    }
  }

  set a_sim_vars(s_tool_bin_path) [string map {/ \\\\} $bin_path]
  if {$::tcl_platform(platform) == "unix"} {
    set a_sim_vars(s_tool_bin_path) $bin_path
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
  set target_lang    [get_property "target_language" [current_project]]

  # get global include file paths
  set incl_file_paths [list]
  set incl_files      [list]
  send_msg_id USF-ModelSim-107 INFO "Finding global include files..."
  usf_get_global_include_files incl_file_paths incl_files

  set global_incl_files $incl_files
  set global_files_str [usf_get_global_include_file_cmdstr incl_files]

  # verilog incl dir's and verilog headers directory path if any
  send_msg_id USF-ModelSim-108 INFO "Finding include directories and verilog header directory paths..."
  set l_incl_dirs_opts [list]
  set uniq_dirs [list]
  foreach dir [concat [usf_get_include_dirs] [usf_get_verilog_header_paths] [xcs_get_vip_include_dirs]] {
    if { [lsearch -exact $uniq_dirs $dir] == -1 } {
      lappend uniq_dirs $dir
      lappend l_incl_dirs_opts "\"+incdir+$dir\""
    }
  }

  # if xilinx_vip not referenced, compile it locally
  if { ([lsearch -exact $l_compiled_libraries "xilinx_vip"] == -1) } {
    variable a_sim_sv_pkg_libs
    if { [llength $a_sim_sv_pkg_libs] > 0 } {
      set incl_dir_opts "\\\"+incdir+[xcs_get_vip_include_dirs]\\\""
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
      foreach file [rdi::get_xpm_files -library_name $library] {
        set file_type "SystemVerilog"
        set g_files $global_files_str
        set cmd_str [usf_get_file_cmd_str $file $file_type true $g_files l_incl_dirs_opts]
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
      set cmd_str [usf_get_file_cmd_str $file $file_type true $g_files l_incl_dirs_opts l_dummy_incl_dirs_opts $xpm_library]
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
        usf_add_block_fs_files $global_files_str l_incl_dirs_opts files l_compile_order_files
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
        set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files l_incl_dirs_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }
    # add files from simulation compile order
    if { {All} == $a_sim_vars(src_mgmt_mode) } {
      send_msg_id USF-ModelSim-109 INFO "Fetching design files from '$target_obj'..."
      foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $target_obj]] {
        if { [xcs_is_global_include_file $global_files_str $file] } { continue }
        set file_type [get_property "file_type" $file]
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) && ({VHDL 2019} != $file_type) } { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
        set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files l_incl_dirs_opts]
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
          send_msg_id USF-ModelSim-110 INFO "Fetching design files from '$srcset_obj'...(this may take a while)..."
          foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $srcset_obj]] {
            set file_type [get_property "file_type" $file]
            if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) && ({VHDL 2019} != $file_type) } { continue }
            set g_files $global_files_str
            if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
            set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files l_incl_dirs_opts]
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
      send_msg_id USF-ModelSim-111 INFO "Fetching design files from '$a_sim_vars(s_simset)'..."
      foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $a_sim_vars(s_simset)]] {
        if { [xcs_is_xlnoc_for_synth $file] } { continue }
        set file_type [get_property "file_type" $file]
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) && ({VHDL 2019} != $file_type) } { continue }
        if { [get_property "is_auto_disabled" $file] } { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
        set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files l_incl_dirs_opts]
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
          set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files l_incl_dirs_opts]
          if { {} != $cmd_str } {
            lappend files $cmd_str
            lappend l_compile_order_files $file
          }
        }
      }
    }

  } elseif { [xcs_is_ip $target_obj [xcs_get_valid_ip_extns]] } {
    # prepare command line args for fileset ip files
    send_msg_id USF-ModelSim-112 INFO "Fetching design files from IP '$target_obj'..."
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
      set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files l_incl_dirs_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  }
  
  if { ($a_sim_vars(b_use_static_lib)) && ($a_sim_vars(b_dynamic_xpm_noc_compile)) } {
    variable l_local_design_libraries
    if { [lsearch -exact $l_local_design_libraries "xpm"] == -1 } {
      lappend l_local_design_libraries "xpm"
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

  # verilog incl dir's and verilog headers directory path if any
  set l_incl_dirs_opts [list]
  set uniq_dirs [list]
  foreach dir [concat [usf_get_include_dirs] [usf_get_verilog_header_paths] [xcs_get_vip_include_dirs]] {
    if { [lsearch -exact $uniq_dirs $dir] == -1 } {
      lappend uniq_dirs $dir
      lappend l_incl_dirs_opts "\"+incdir+$dir\""
    }
  }

  # add hbm source to compile order for netlist functional simulation
  if { $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) && ({} != $a_sim_vars(sp_hbm_ip_obj)) } {
    set hbm_file_obj [get_files -quiet -all "hbm_model.sv"]
    if { {} != $hbm_file_obj } {
      set file_type [get_property "file_type" $hbm_file_obj]
      set cmd_str [usf_get_file_cmd_str $hbm_file_obj $file_type false {} l_incl_dirs_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $hbm_file_obj
      }
    }
  }

  if { {} != $netlist_file } {
    set file_type "Verilog"
    set extn [file extension $netlist_file]
    if { {.sv} == $extn } {
      set file_type "SystemVerilog"
    } elseif { {.vhd} == $extn } {
      set file_type "VHDL"
    }
    set cmd_str [usf_get_file_cmd_str $netlist_file $file_type false {} l_incl_dirs_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend l_compile_order_files $netlist_file
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
  #  set cmd_str [usf_get_file_cmd_str $file $file_type false {} l_incl_dirs_opts]
  #  if { {} != $cmd_str } {
  #    lappend files $cmd_str
  #    lappend l_compile_order_files $file
  #  }
  #}
  ##set verilog_filter "USED_IN_TESTBENCH == 1 && FILE_TYPE == \"Verilog\" && FILE_TYPE == \"Verilog Header\" && FILE_TYPE == \"Verilog/SystemVerilog Header\""
  #set verilog_filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"Verilog\" || FILE_TYPE == \"SystemVerilog\")"
  #foreach file [usf_get_testbench_files_from_ip $verilog_filter] {
  #  if { [lsearch -exact [list_property -quiet $file] {FILE_TYPE}] == -1 } {
  #    continue;
  #  }
  #  #set file_type [get_property "file_type" [lindex [get_files -quiet -all [list "$file"]] 0]]
  #  set file_type [get_property "file_type" $file]
  #  set cmd_str [usf_get_file_cmd_str $file $file_type false {} l_incl_dirs_opts]
  #  if { {} != $cmd_str } {
  #    lappend files $cmd_str
  #    lappend l_compile_order_files $file
  #  }
  #}

  # prepare command line args for fileset files
  if { [xcs_is_fileset $target_obj] } {

    # 851957 - if simulation and design source file tops are same (no testbench), skip adding simset files. Just pass the netlist above.
    set src_fs_top [get_property "top" [current_fileset]]
    set sim_fs_top [get_property "top" [get_filesets $a_sim_vars(s_simset)]]
    if { $src_fs_top == $sim_fs_top } {
      return $files
    }

    # add additional files from simulation fileset
    foreach file [get_files -compile_order sources -used_in synthesis_post -of_objects [get_filesets $a_sim_vars(s_simset)]] {
      set file_type [get_property "file_type" $file]
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) && ({VHDL 2019} != $file_type) } { continue }
      #if { [get_property "is_auto_disabled" $file] } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files l_incl_dirs_opts]
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
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) && ({VHDL 2019} != $file_type) } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type false $g_files l_incl_dirs_opts]
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

  variable a_sim_cache_all_design_files_obj

  set vhdl_filter "FILE_TYPE == \"VHDL\" || FILE_TYPE == \"VHDL 2008\" || FILE_TYPE == \"VHDL 2019\""
  foreach file [xcs_get_files_from_block_filesets $vhdl_filter] {
    if { [info exists a_sim_cache_all_design_files_obj($file)] } {
      set file_obj $a_sim_cache_all_design_files_obj($file)
    } else {
      set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
    }
    set file_type [get_property "file_type" $file_obj]
    set cmd_str [usf_get_file_cmd_str $file $file_type false {} l_incl_dirs_opts]
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
    set cmd_str [usf_get_file_cmd_str $file $file_type false $global_files_str l_incl_dirs_opts]
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

  set extn [xcs_get_script_extn "modelsim"]
  set scr_file ${step}$extn

  set shell_script_file [file normalize [file join $a_sim_vars(s_launch_dir) $scr_file]]
  xcs_make_file_executable $shell_script_file

  if { $a_sim_vars(b_scripts_only) } {
    send_msg_id USF-ModelSim-068 INFO "Script generated:[file normalize [file join $a_sim_vars(s_launch_dir) $scr_file]]"
    return 0
  }

  set b_wait 0
  if { $a_sim_vars(b_batch) || (!$a_sim_vars(b_int_is_gui_mode)) } {
    set b_wait 1 
  }
  set faulty_run 0
  set cwd [pwd]
  cd $a_sim_vars(s_launch_dir)
  set display_step [string toupper $step]
  if { "$display_step" == "COMPILE" } {
    set display_step "${display_step} and ANALYZE"
  }
  send_msg_id USF-ModelSim-069 INFO "Executing '${display_step}' step in '$a_sim_vars(s_launch_dir)'"
  set results_log {}
  switch $step {
    {compile} -
    {elaborate} {
      set start_time [clock seconds]
      set error_log {}
      set faulty_run [xcs_exec_script $scr_file error_log]
      set end_time [clock seconds]
      send_msg_id USF-ModelSim-069 INFO "'$step' step finished in '[expr $end_time - $start_time]' seconds"
      # check errors
      if { [usf_check_errors $step results_log] } {
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
        send_msg_id USF-ModelSim-072 ERROR "Failed to launch $scr_file:$error_log\n"
        set faulty_run 1
      }
    }
  }
  cd $cwd
  if { $faulty_run } {
    if { {} == $results_log} {
      set msg "'$step' step failed with error(s) while executing '$shell_script_file' script. Please check that the file has the correct 'read/write/execute' permissions and the Tcl console output for any other possible errors or warnings.\n"
      [catch {send_msg_id USF-ModelSim-070 ERROR "$msg"}]
    } else {
      [catch {send_msg_id USF-ModelSim-070 ERROR "'$step' step failed with error(s). Please check the Tcl console output or '$results_log' file for more information.\n"}]
    }
    # IMPORTANT - *** DONOT MODIFY THIS ***
    error "_SIM_STEP_RUN_EXEC_ERROR_"
    # IMPORTANT - *** DONOT MODIFY THIS ***
    return 1
  }
  return 0
}
}

#
# Low level helper procs
# 
namespace eval ::tclapp::xilinx::modelsim {

proc usf_get_include_dirs { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set d_dir_names [dict create]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  set incl_dirs [list]
  set incl_dir_str {}
  if { [xcs_is_ip $tcl_obj [xcs_get_valid_ip_extns]] } {
    set incl_dir_str [usf_get_incl_dirs_from_ip $tcl_obj]
    set incl_dirs [split $incl_dir_str "|"]
  } else {
    set incl_dir_str [xcs_resolve_incl_dir_property_value [get_property "include_dirs" [get_filesets $tcl_obj]]]
    set incl_prop_dirs [split $incl_dir_str "|"]

    # include dirs from design source set
    set linked_src_set [get_property "source_set" [get_filesets $tcl_obj]]
    if { {} != $linked_src_set } {
      set src_fs_obj [get_filesets $linked_src_set]
      set dirs [xcs_resolve_incl_dir_property_value [get_property "include_dirs" [get_filesets $src_fs_obj]]]
      foreach dir [split $dirs "|"] {
        if { [lsearch -exact $incl_prop_dirs $dir] == -1 } {
          lappend incl_prop_dirs $dir
        } 
      }  
    }

    foreach dir $incl_prop_dirs {
      if { $a_sim_vars(b_absolute_path) } {
        set dir "[xcs_resolve_file_path $dir $a_sim_vars(s_launch_dir)]"
      } else {
        if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
          set dir "[xcs_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
        } else {
          set dir "\$origin_dir/[xcs_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
        }
      }
      lappend incl_dirs $dir
    }
  }
  
  set intf_incl_dir "[xcs_add_axi_interface_header  $a_sim_vars(b_absolute_path) $a_sim_vars(s_launch_dir)]"
  if { {} != $intf_incl_dir } {
    lappend incl_dirs $intf_incl_dir
  }

  foreach vh_dir $incl_dirs {
    set vh_dir [string trim $vh_dir {\{\}}]
    dict append d_dir_names $vh_dir
  }
  return [dict keys $d_dir_names]
}

proc usf_get_verilog_header_paths {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

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

  set unique_paths   [list]
  set linked_src_set [get_property "source_set" $a_sim_vars(fs_obj)]
  if { {} != $linked_src_set } {
    set srcset_obj [get_filesets $linked_src_set]
    if { {} != $srcset_obj } {
      usf_add_unique_incl_paths $srcset_obj unique_paths incl_header_paths
    }
  }
  usf_add_unique_incl_paths $a_sim_vars(fs_obj) unique_paths incl_header_paths
  # add paths from block filesets
  set filter "FILESET_TYPE == \"BlockSrcs\""
  foreach blk_fs_obj [get_filesets -filter $filter] {
    set fs_name [get_property "name" [get_filesets $blk_fs_obj]]
    usf_add_unique_incl_paths $blk_fs_obj unique_paths incl_header_paths
  }
}

proc usf_add_unique_incl_paths { fs_obj unique_paths_arg incl_header_paths_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $unique_paths_arg      unique_paths
  upvar $incl_header_paths_arg incl_header_paths

  variable a_sim_vars

  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_all_bd_files

  # setup the filter to include only header types enabled for simulation
  set filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\")"
  set vh_files [get_files -all -quiet -filter $filter]
  foreach vh_file $vh_files {
    set vh_file_obj {}
    if { [info exists a_sim_cache_all_design_files_obj($vh_file)] } {
      set vh_file_obj $a_sim_cache_all_design_files_obj($vh_file)
    } else {
      set vh_file_obj [lindex [get_files -all -quiet [list "$vh_file"]] 0]
    }
    if { [get_property "is_global_include" $vh_file_obj] } {
      continue
    }
    # set vh_file [extract_files -files [list "$vh_file"] -base_dir $a_sim_vars(s_launch_dir)/ip_files]
    set vh_file [usf_xtract_file $vh_file]
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
    set file_path [file normalize [string map {\\ /} [file dirname $vh_file]]]
    if { [lsearch -exact $unique_paths $file_path] == -1 } {
      if { $a_sim_vars(b_absolute_path) } {
        set incl_file_path "[xcs_resolve_file_path $file_path $a_sim_vars(s_launch_dir)]"
      } else {
        if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
          set incl_file_path "[xcs_get_relative_file_path $file_path $a_sim_vars(s_launch_dir)]"
        } else {
          set incl_file_path "\$origin_dir/[xcs_get_relative_file_path $file_path $a_sim_vars(s_launch_dir)]"
        }
      }
      lappend incl_header_paths $incl_file_path
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

  variable a_sim_cache_all_design_files_obj
  set filesets       [list]

  set linked_src_set [get_property "source_set" $a_sim_vars(fs_obj)]
  set incl_files_set [list]

  if { {} != $linked_src_set } {
    lappend filesets $linked_src_set
  }
  lappend filesets $a_sim_vars(fs_obj)
  # find verilog files marked as global include and not user disabled
  set filter "(FILE_TYPE == \"Verilog\"                      || \
               FILE_TYPE == \"Verilog Header\"               || \
               FILE_TYPE == \"Verilog/SystemVerilog Header\" || \
               FILE_TYPE == \"Verilog Template\")            && \
              (IS_GLOBAL_INCLUDE == 1 && IS_USER_DISABLED == 0)"
  foreach fs_obj $filesets {
    foreach file [get_files -quiet -all -of_objects [get_filesets $fs_obj] -filter $filter] {
      set file_obj {}
      if { [info exists a_sim_cache_all_design_files_obj($file)] } {
        set file_obj $a_sim_cache_all_design_files_obj($file)
      } else {
        set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
      }
      set file [usf_xtract_file $file]
      set file [file normalize [string map {\\ /} $file]]
      if { [lsearch -exact $incl_files_set $file] == -1 } {
        lappend incl_files_set $file
        lappend incl_files     $file
        set incl_file_path [file normalize [string map {\\ /} [file dirname $file]]]
        if { $a_sim_vars(b_absolute_path) } {
          set incl_file_path "[xcs_resolve_file_path $incl_file_path $a_sim_vars(s_launch_dir)]"
        } else {
          if { $ref_dir } {
            if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
              set incl_file_path "[xcs_get_relative_file_path $incl_file_path $a_sim_vars(s_launch_dir)]"
            } else {
              set incl_file_path "\$origin_dir/[xcs_get_relative_file_path $incl_file_path $a_sim_vars(s_launch_dir)]"
            }
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

  set ip_name [file tail $tcl_obj]
  set incl_dirs [list]
  set filter "FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\""
  set vh_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    # set file [extract_files -files [list "$file"] -base_dir $a_sim_vars(s_launch_dir)/ip_files]
    set file [usf_xtract_file $file]
    set dir [file dirname $file]
    if { [get_param project.enableCentralSimRepo] } {
      set b_static_ip_file 0
      set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
      set associated_library {}
      if { {} != $file_obj } {
        if { [lsearch -exact [list_property -quiet $file_obj] {LIBRARY}] != -1 } {
          set associated_library [get_property "library" $file_obj]
        }
      }
      set file [usf_get_ip_file_from_repo $tcl_obj $file $associated_library $a_sim_vars(s_launch_dir) b_static_ip_file]
      set dir [file dirname $file]
      # remove leading "./"
      if { [regexp {^\.\/} $dir] } {
        set dir [join [lrange [split $dir "/"] 1 end] "/"]
      }
    } else {
      if { $a_sim_vars(b_absolute_path) } {
        set dir "[xcs_resolve_file_path $dir $a_sim_vars(s_launch_dir)]"
      } else {
        if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
          set dir "[xcs_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
        } else {
          set dir "\$origin_dir/[xcs_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
        }
      }
    }
    lappend incl_dirs $dir
  }
  set incl_dirs [join $incl_dirs "|"]
  return $incl_dirs
}

proc usf_append_compiler_options { tool file_type opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts

  variable a_sim_vars
  variable a_sim_sv_pkg_libs

  set s_64bit {-64}
  if {$::tcl_platform(platform) == "windows"} {
    # -64 not supported
    set s_64bit {}
  }
  if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
    set s_64bit {-32}
  }

  switch $tool {
    "vcom" {
      set vhdl_syntax [get_property "modelsim.compile.vhdl_syntax" $a_sim_vars(fs_obj)]
      set vhd_syntax "-$vhdl_syntax"
      if { [string equal -nocase $file_type "vhdl 2008"] } {
        set vhd_syntax "-2008"
      }
      if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
        set arg_list [list $s_64bit]
        lappend arg_list $vhd_syntax
        set more_options [string trim [get_property "modelsim.compile.vcom.more_options" $a_sim_vars(fs_obj)]]
        if { {} != $more_options } {
          set arg_list [linsert $arg_list end "$more_options"]
        }
        set cmd_str [join $arg_list " "]
        lappend opts $cmd_str
      } else {
        lappend opts $vhd_syntax
        lappend opts "\$${tool}_opts"
      }
    }
    "vlog" {
      if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
        set arg_list [list $s_64bit]
        if { [get_property "incremental" $a_sim_vars(fs_obj)] } {
          lappend arg_list "-incr"
        }

        # cr:1086604
        lappend arg_list "-mfcu"

        set more_options [string trim [get_property "modelsim.compile.vlog.more_options" $a_sim_vars(fs_obj)]]
        if { {} != $more_options } {
          set arg_list [linsert $arg_list end "$more_options"]
        }
        set cmd_str [join $arg_list " "]
        lappend opts $cmd_str
      } else {
        lappend opts "\$${tool}_opts"
      }
      if { [string equal -nocase $file_type "systemverilog"] } {
        lappend opts "-sv"
        # append sv pkg libs
        foreach sv_pkg_lib $a_sim_sv_pkg_libs {
          # filter hbm IP library binding for netlist functional simulation (e.g hbm_v1_0_1)
          if { [regexp {^hbm_v} $sv_pkg_lib] } {
            if { $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) && ({} != $a_sim_vars(sp_hbm_ip_obj)) } {
              continue
            }
          }
          lappend opts "-L $sv_pkg_lib"
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

  switch $tool {
    "vlog" {
      # verilog defines
      set verilog_defines [list]
      set verilog_defines [get_property "verilog_define" [get_filesets $a_sim_vars(fs_obj)]]
      if { [llength $verilog_defines] > 0 } {
        usf_append_define_generics $verilog_defines $tool opts
      }
 
      # for hbm netlist functional simulation
      if { $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) && ({} != $a_sim_vars(sp_hbm_ip_obj)) } {
        lappend opts "+define+NETLIST_SIM"
      }
    }
  }
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

proc usf_get_file_cmd_str { file file_type b_xpm global_files_str l_incl_dirs_opts_arg {xpm_library {}} {xv_lib {}}} {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts

  variable a_sim_vars

  variable a_sim_cache_all_design_files_obj

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
    if { [get_param "project.enableCentralSimRepo"] } {
      # no op
    } else {
      if { $a_sim_vars(b_extract_ip_sim_files) } {
        set xcix_ip_path [get_property "core_container" $file_obj]
        if { {} != $xcix_ip_path } {
          set ip_name [file root [file tail $xcix_ip_path]]
          set ip_ext_dir [get_property "ip_extract_dir" [get_ips -all -quiet $ip_name]]
          set ip_file "[xcs_get_relative_file_path $file $ip_ext_dir]"
          # remove leading "../"
          set ip_file [join [lrange [split $ip_file "/"] 1 end] "/"]
          set file [file join $ip_ext_dir $ip_file]
        } else {
          # set file [extract_files -files [list "$file"] -base_dir $a_sim_vars(s_launch_dir)/ip_files]
        }
      }
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

  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    # no op
  } else {
    # any spaces in file path, escape it?
    regsub -all { } $file {\\\\ } file
  }

  set compiler [xcs_get_compiler_name "modelsim" $file_type]
  set arg_list [list]
  if { [string length $compiler] > 0 } {
    lappend arg_list $compiler
    usf_append_compiler_options $compiler $file_type arg_list
    set arg_list [linsert $arg_list end "-work $associated_library" "$global_files_str"]
  }
  usf_append_other_options $compiler $file_type $global_files_str arg_list

  # append include dirs for verilog sources
  if { {vlog} == $compiler } {
    set arg_list [concat $arg_list $l_incl_dirs_opts]
  }

  set file_str [join $arg_list " "]
  set type [xcs_get_file_type_category $file_type]
  set cmd_str "$type|$file_type|$associated_library|$file_str|\"$file\"|$b_static_ip_file"
  return $cmd_str
}

proc usf_check_errors { step results_log_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $results_log_arg results_log
  
  variable a_sim_vars

  set retval 0
  set log [file normalize [file join $a_sim_vars(s_launch_dir) ${step}.log]]
  if { [file exists $log] } {
    set fh 0
    if {[catch {open $log r} fh]} {
      send_msg_id USF-ModelSim-099 WARNING "Failed to open file to read ($log)\n"
    } else {
      set log_data [read $fh]
      close $fh
      set log_data [split $log_data "\n"]
      foreach line $log_data {
        if {[regexp -nocase {ONERROR} $line]} {
          set results_log $log
          set retval 1
          break
        }
        if {[regexp -nocase {\*\* Error:} $line]} {
          set results_log $log
          set retval 1
          break
        }
      }
    }
  }
  if { $retval } {
    [catch {send_msg_id USF-ModelSim-099 INFO "Step results log file:'$log'\n"}]
    return 1
  }
  return 0
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
    set xcix_ip_path [get_property "core_container" $file_obj]
    if { {} != $xcix_ip_path } {
      set ip_name [file root [file tail $xcix_ip_path]]
      set ip_ext_dir [get_property "ip_extract_dir" [get_ips -all -quiet $ip_name]]
      set ip_file "[xcs_get_relative_file_path $file $ip_ext_dir]"
      # remove leading "../"
      set ip_file [join [lrange [split $ip_file "/"] 1 end] "/"]
      set file [file join $ip_ext_dir $ip_file]
    }
  }
  return $file
}
proc usf_get_ip_file_from_repo { ip_file src_file library launch_dir b_static_ip_file_arg  } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $b_static_ip_file_arg b_static_ip_file

  variable a_sim_vars

  variable l_ip_static_libs
  set b_donot_process 0

  if { (![get_param project.enableCentralSimRepo]) || ({} == $ip_file) } {
    set b_donot_process 1
  }

  if { $b_donot_process } {
    if { $a_sim_vars(b_absolute_path) } {
      set src_file "[xcs_resolve_file_path $src_file $launch_dir]"
    } else {
      if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
        set src_file "[xcs_get_relative_file_path $src_file $launch_dir]"
      } else {
        set src_file "\$origin_dir/[xcs_get_relative_file_path $src_file $launch_dir]"
      }
    }

    return $src_file
  }

  if { ({} != $a_sim_vars(dynamic_repo_dir)) && ([file exist $a_sim_vars(dynamic_repo_dir)]) } {
    set b_is_static 0
    set b_is_dynamic 0
    set src_file [usf_get_source_from_repo $ip_file $src_file $launch_dir b_is_static b_is_dynamic]
    set b_static_ip_file $b_is_static
    if { (!$b_is_static) && (!$b_is_dynamic) } {
      #send_msg_id USF-ModelSim-056 "CRITICAL WARNING" "IP file is neither static or dynamic:'$src_file'\n"
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
      #send_msg_id USF-ModelSim-024 WARNING "Expected IP user file does not exist:'$repo_src_file'!, using from default location:'$full_src_file_path'"
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
}
