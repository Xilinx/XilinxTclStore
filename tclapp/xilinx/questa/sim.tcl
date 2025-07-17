######################################################################
#
# sim.tcl (simulation script for the 'Questa Advanced Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
######################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::questa {
  namespace export setup
}


namespace eval ::tclapp::xilinx::questa {
proc setup { args } {
  # Summary: initialize global vars and prepare for simulation
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # true (0) if success, false (1) otherwise

  # initialize global variables
  set args [string trim $args "\}\{"]

  # donot re-initialze, if -int_setup_sim_vars found in args (for -step flow only)
  if { [lsearch -exact $args {-int_setup_sim_vars}] == -1 } {
    usf_init_vars
  }

  # control precompile flow
  variable a_sim_vars
  xcs_control_pre_compile_flow a_sim_vars(b_use_static_lib)

  # read simulation command line args and set global variables
  usf_questa_setup_args $args

  # set NoC binding type
  if { $a_sim_vars(b_int_system_design) } {
    xcs_bind_legacy_noc
  }

  # perform initial simulation tasks
  if { [usf_questa_setup_simulation] } {
    return 1
  }
  return 0
}

proc compile { args } {
  # Summary: run the compile step for compiling the design files
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  send_msg_id USF-Questa-002 INFO "Questa::Compile design"
  usf_questa_write_compile_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  usf_launch_script "questa" $step
}

proc elaborate { args } {
  # Summary: run the elaborate step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  send_msg_id USF-Questa-003 INFO "Questa::Elaborate design"
  usf_questa_write_elaborate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  usf_launch_script "questa" $step
}

proc simulate { args } {
  # Summary: run the simulate step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none
 
  variable a_sim_vars

  send_msg_id USF-Questa-004 INFO "Questa::Simulate design"
  usf_questa_write_simulate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  usf_launch_script "questa" $step

  if { $a_sim_vars(b_scripts_only) } {
    set fh 0
    set file [file normalize [file join $a_sim_vars(s_launch_dir) "simulate.log"]]
    if {[catch {open $file w} fh]} {
      send_msg_id USF-Questa-016 ERROR "Failed to open file to write ($file)\n"
    } else {
      puts $fh "INFO: Scripts generated successfully. Please see the 'Tcl Console' window for details."
      close $fh
    }
  }
}
}

#
# Questa Advanced simulation flow
#
namespace eval ::tclapp::xilinx::questa {
proc usf_questa_setup_simulation { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  # set the simulation flow
  xcs_set_simulation_flow $a_sim_vars(s_simset) $a_sim_vars(s_mode) $a_sim_vars(s_type) a_sim_vars(s_flow_dir_key) a_sim_vars(s_simulation_flow)

  # set default object
  if { [xcs_set_sim_tcl_obj $a_sim_vars(s_comp_file) $a_sim_vars(s_simset) a_sim_vars(sp_tcl_obj) a_sim_vars(s_sim_top)] } {
    return 1
  }

  # *****************************************************************
  # is step exec mode?
  # *****************************************************************
  if { $a_sim_vars(b_int_setup_sim_vars) } {
    return 0
  }

  if { ({post_synth_sim} == $a_sim_vars(s_simulation_flow)) || ({post_impl_sim} == $a_sim_vars(s_simulation_flow)) } {
    set a_sim_vars(b_netlist_sim) 1
  }

  # enable systemC non-precompile flow if global pre-compiled static IP flow is disabled
  if { !$a_sim_vars(b_use_static_lib) } {
    set a_sim_vars(b_compile_simmodels) 1
  }

  if { $a_sim_vars(b_compile_simmodels) } {
    set a_sim_vars(s_simlib_dir) "$a_sim_vars(s_launch_dir)/simlibs"
    if { ![file exists $a_sim_vars(s_simlib_dir)] } {
      if { [catch {file mkdir $a_sim_vars(s_simlib_dir)} error_msg] } {
        send_msg_id USF-Questa-013 ERROR "Failed to create the directory ($a_sim_vars(s_simlib_dir)): $error_msg\n"
        return 1
      }
    }
  }

  usf_set_simulator_path   "questa"

  # initialize boost library reference
  set a_sim_vars(s_boost_dir) [xcs_get_boost_library_path]

  # initialize XPM libraries (if any)
  xcs_get_xpm_libraries

  # get hard-blocks
  #xcs_get_hard_blocks

  if { [get_param "project.enableCentralSimRepo"] } {
    # no op
  } else {
    # extract ip simulation files
    xcs_extract_ip_files a_sim_vars(b_extract_ip_sim_files)
  }

  # write functional/timing netlist for post-* simulation
  set a_sim_vars(s_netlist_file) [xcs_write_design_netlist $a_sim_vars(s_simset)          \
                                                           $a_sim_vars(s_simulation_flow) \
                                                           $a_sim_vars(s_type)            \
                                                           $a_sim_vars(s_sim_top)         \
                                                           $a_sim_vars(s_launch_dir)      \
                                 ]

  # prepare IP's for simulation
  # xcs_prepare_ip_for_simulation $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(s_launch_dir)

  # find/copy modelsim.ini file into run dir
  set a_sim_vars(s_clibs_dir) [usf_questa_verify_compiled_lib]

  # verify GCC version from CLIBs (make sure it matches, else throw critical warning)
  xcs_verify_clibs_gcc_version $a_sim_vars(s_clibs_dir) $a_sim_vars(s_gcc_version) "questa"

  variable l_compiled_libraries
  variable l_xpm_libraries
  set b_reference_xpm_library 0
  if { [llength $l_xpm_libraries] > 0 } {
     if { [get_param project.usePreCompiledXPMLibForSim] } {
      set b_reference_xpm_library 1
    }
  }
  if { ($a_sim_vars(b_use_static_lib)) && ([xcs_is_ip_project] || $b_reference_xpm_library) } {
    set l_local_ip_libs [xcs_get_libs_from_local_repo $a_sim_vars(b_use_static_lib) $a_sim_vars(s_local_ip_repo_leaf_dir) $a_sim_vars(b_int_sm_lib_ref_debug)]
    if { {} != $a_sim_vars(s_clibs_dir) } {
      set libraries [xcs_get_compiled_libraries $a_sim_vars(s_clibs_dir) $a_sim_vars(b_int_sm_lib_ref_debug)]
      # filter local ip definitions
      foreach lib $libraries {
        if { [lsearch -exact $l_local_ip_libs $lib] != -1 } {
          continue
        } else {
          lappend l_compiled_libraries $lib
        }
      }
    }
  }

  # extract simulation model library info
  xcs_fetch_lib_info "questa" $a_sim_vars(s_clibs_dir) $a_sim_vars(b_int_sm_lib_ref_debug)

  # generate mem files
  xcs_generate_mem_files_for_simulation $a_sim_vars(sp_tcl_obj) $a_sim_vars(s_launch_dir)

  # fetch the compile order for the specified object
  xcs_xport_data_files $a_sim_vars(sp_tcl_obj) $a_sim_vars(s_simset) $a_sim_vars(s_sim_top) $a_sim_vars(s_launch_dir) $a_sim_vars(dynamic_repo_dir)

  # cache all design files
  variable a_sim_cache_all_design_files_obj
  foreach file_obj [get_files -quiet -all] {
    set name [get_property -quiet "name" $file_obj]
    set a_sim_cache_all_design_files_obj($name) $file_obj
  }

  # cache all IPs
  variable a_sim_cache_all_ip_obj
  foreach ip_obj [lsort -unique [get_ips -all -quiet]] {
    set name [get_property -quiet name $ip_obj]
    set a_sim_cache_all_ip_obj($name) $ip_obj
  }

  # cache all system verilog package libraries
  xcs_find_sv_pkg_libs $a_sim_vars(s_launch_dir) $a_sim_vars(b_int_sm_lib_ref_debug)

  # systemC headers
  set a_sim_vars(b_contain_systemc_headers) [xcs_contains_systemc_headers]

  # find shared library paths from all IPs
  if { $a_sim_vars(b_int_systemc_mode) } {
    if { [xcs_contains_C_files] } {
      xcs_find_shared_lib_paths "questa" $a_sim_vars(s_gcc_version) $a_sim_vars(s_clibs_dir) $a_sim_vars(custom_sm_lib_dir) $a_sim_vars(b_int_sm_lib_ref_debug) a_sim_vars(sp_cpt_dir) a_sim_vars(sp_ext_dir)
    }
  }

  # find hbm IP, if any for netlist functional simulation
  if { $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) } {
    set a_sim_vars(sp_hbm_ip_obj) [xcs_find_ip "hbm"]
  }

  # find noc IP, if any for netlist functional simulation
  if { $a_sim_vars(b_enable_netlist_sim) && $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) } {
    set a_sim_vars(sp_xlnoc_bd_obj) [get_files -all -quiet "xlnoc.bd"]
  }

  # fetch design files
  variable l_local_design_libraries
  set global_files_str {}
  set a_sim_vars(l_design_files) [xcs_uniquify_cmd_str [usf_get_files_for_compilation global_files_str]]

  # print IPs that were not found from clibs
  xcs_print_local_IP_compilation_msg $a_sim_vars(b_int_sm_lib_ref_debug) $l_local_design_libraries $a_sim_vars(compiled_library_dir)

  # is system design?
  if { $a_sim_vars(b_contain_systemc_sources) || $a_sim_vars(b_contain_cpp_sources) || $a_sim_vars(b_contain_c_sources) } {
    set a_sim_vars(b_system_sim_design) 1
  }

  # create library directory
  usf_questa_create_lib_dir

  return 0
}

proc usf_questa_setup_args { args } {
  # Summary:
  # 

  # Argument Usage:
  # [-simset <arg>]: Name of the simulation fileset
  # [-mode <arg>]: Simulation mode. Values: behavioral, post-synthesis, post-implementation
  # [-type <arg>]: Netlist type. Values: functional, timing. This is only applicable when mode is set to post-synthesis or post-implementation
  # [-scripts_only]: Only generate scripts
  # [-gui]: Invoke simulator in GUI mode for scripts only
  # [-of_objects <arg>]: Generate do file for this object (applicable with -scripts_only option only)
  # [-absolute_path]: Make all file paths absolute wrt the reference directory
  # [-lib_map_path <arg>]: Precompiled simulation library directory path
  # [-install_path <arg>]: Custom Questa installation directory path
  # [-batch]: Execute batch flow simulation run (non-gui)
  # [-exec]: Execute script (applicable with -step switch only)
  # [-run_dir <arg>]: Simulation run directory
  # [-int_sm_lib_dir <arg>]: Simulation model library directory
  # [-int_os_type]: OS type (32 or 64) (internal use)
  # [-int_setup_sim_vars]: Initialize sim vars only (internal use)
  # [-int_debug_mode]: Debug mode (internal use)
  # [-int_ide_gui]: Vivado launch mode is gui (internal use)
  # [-int_halt_script]: Halt and generate error if simulator tools not found (internal use)
  # [-int_systemc_mode]: SystemC mode (internal use)
  # [-int_system_design]: Design configured for system simulation (internal use)
  # [-int_gcc_bin_path <arg>]: GCC path (internal use)
  # [-int_gcc_version <arg>]: GCC version (internal use)
  # [-int_sim_version <arg>]: Simulator version (internal use)
  # [-int_aie_work_dir <arg>]: AIE work dir (internal use)
  # [-int_compile_glbl]: Compile glbl (internal use)
  # [-int_sm_lib_ref_debug]: Print simulation model library referencing debug messages (internal use)
  # [-int_csim_compile_order]: Use compile order for co-simulation (internal use)
  # [-int_export_source_files]: Export IP sources to simulation run directory (internal use)
  # [-int_en_vitis_hw_emu_mode]: Enable code for Vitis HW-EMU (internal use)
  # [-int_perf_analysis]: Enable code for performance analysis (internal use)
  # [-int_fix_noc_assertion]: Enable code for fixing NoC assertion error (internal use)

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: xilinxtclstore, questa

  variable a_sim_vars
  set args [string trim $args "\}\{"]

  # process options
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-simset"                   { incr i;set a_sim_vars(s_simset)            [lindex $args $i] }
      "-mode"                     { incr i;set a_sim_vars(s_mode)              [lindex $args $i] }
      "-type"                     { incr i;set a_sim_vars(s_type)              [lindex $args $i] }
      "-of_objects"               { incr i;set a_sim_vars(s_comp_file)         [lindex $args $i] }
      "-lib_map_path"             { incr i;set a_sim_vars(s_lib_map_path)      [lindex $args $i] }
      "-install_path"             { incr i;set a_sim_vars(s_install_path)      [lindex $args $i] }
      "-run_dir"                  { incr i;set a_sim_vars(s_launch_dir)        [lindex $args $i] }
      "-int_os_type"              { incr i;set a_sim_vars(s_int_os_type)       [lindex $args $i] }
      "-int_debug_mode"           { incr i;set a_sim_vars(s_int_debug_mode)    [lindex $args $i] }
      "-int_gcc_bin_path"         { incr i;set a_sim_vars(s_gcc_bin_path)      [lindex $args $i] }
      "-int_gcc_version"          { incr i;set a_sim_vars(s_gcc_version)       [lindex $args $i] }
      "-int_sim_version"          { incr i;set a_sim_vars(s_sim_version)       [lindex $args $i] }
      "-int_aie_work_dir"         { incr i;set a_sim_vars(s_aie_work_dir)      [lindex $args $i] }
      "-int_sm_lib_dir"           { incr i;set a_sim_vars(custom_sm_lib_dir)   [lindex $args $i] }
      "-scripts_only"             { set a_sim_vars(b_scripts_only)             1                 }
      "-gui"                      { set a_sim_vars(b_gui)                      1                 }
      "-absolute_path"            { set a_sim_vars(b_absolute_path)            1                 }
      "-batch"                    { set a_sim_vars(b_batch)                    1                 }
      "-exec"                     { set a_sim_vars(b_exec_step) 1;set a_sim_vars(b_scripts_only) 0}
      "-int_ide_gui"              { set a_sim_vars(b_int_is_gui_mode)          1                 }
      "-int_halt_script"          { set a_sim_vars(b_int_halt_script)          1                 }
      "-int_systemc_mode"         { set a_sim_vars(b_int_systemc_mode)         1                 }
      "-int_system_design"        { set a_sim_vars(b_int_system_design)        1                 }
      "-int_compile_glbl"         { set a_sim_vars(b_int_compile_glbl)         1                 }
      "-int_sm_lib_ref_debug"     { set a_sim_vars(b_int_sm_lib_ref_debug)     1                 }
      "-int_csim_compile_order"   { set a_sim_vars(b_int_csim_compile_order)   1                 }
      "-int_export_source_files"  { set a_sim_vars(b_int_export_source_files)  1                 }
      "-int_en_vitis_hw_emu_mode" { set a_sim_vars(b_int_en_vitis_hw_emu_mode) 1                 }
      "-int_perf_analysis"        { set a_sim_vars(b_int_perf_analysis)        1                 }
      "-int_setup_sim_vars"       { set a_sim_vars(b_int_setup_sim_vars)       1                 }
      "-int_fix_noc_assertion"    { set a_sim_vars(b_int_fix_noc_assertion)    1                 }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id USF-Questa-006 WARNING "Unknown option '$option' specified (ignored)\n"
        }
      }
    }
  }
}

proc usf_questa_verify_compiled_lib {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set ini_file "modelsim.ini"
  set compiled_lib_dir {}

  send_msg_id USF-Questa-007 INFO "Finding pre-compiled libraries...\n"

  # 1. check MODELSIM
  if { {} == $compiled_lib_dir } {
    if { [info exists ::env(MODELSIM)] } {
      set file [file normalize $::env(MODELSIM)]
      if { {} != $file } {
        if { [file exists $file] && [file isfile $file] && [file readable $file] && [file writable $file] } {
          set compiled_lib_dir [file dirname $file]
        } else {
          send_msg_id USF-questa-025 ERROR \
            "The INI file specified with the MODELSIM environment variable is not accessible. Please check the file permissions.\n"
          return $compiled_lib_dir
        }
      }
    }
  }
  # 2. not found? find in project default dir (<project>/<project>.cache/compile_simlib
  set dir [get_property "compxlib.questa_compiled_library_dir" [current_project]]
  set file [file normalize [file join $dir $ini_file]]
  if { [file exists $file] } {
    set compiled_lib_dir $dir
  }
  # 2a. check -lib_map_path
  # is -lib_map_path specified and point to valid location?
  if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
    set a_sim_vars(s_lib_map_path) [file normalize $a_sim_vars(s_lib_map_path)]
    if { [file exists $a_sim_vars(s_lib_map_path)] } {
      set compiled_lib_dir $a_sim_vars(s_lib_map_path)
    } else {
      send_msg_id USF-Questa-010 WARNING "The path specified with the -lib_map_path does not exist:'$a_sim_vars(s_lib_map_path)'\n"
    }
  }
  # 3. not found? find modelsim.ini from current working directory
  if { {} == $compiled_lib_dir } {
    set dir [file normalize [pwd]]
    set file [file normalize [file join $dir $ini_file]]
    if { [file exists $file] } {
      set compiled_lib_dir $dir
    }
  }
  # 4. not found? check MGC_WD
  if { {} == $compiled_lib_dir } {
    if { [info exists ::env(MGC_WD)] } {
      set file_dir [file normalize $::env(MGC_WD)]
      if { {} != $file_dir } {
        set compiled_lib_dir $file_dir
      }
    }
  }
  # 5. not found? finally check in run dir
  if { {} == $compiled_lib_dir } {
    set file [file normalize [file join $a_sim_vars(s_launch_dir) $ini_file]]
    if { ! [file exists $file] } {
      if { $a_sim_vars(b_scripts_only) } {
        send_msg_id USF-Questa-024 WARNING "The pre-compiled simulation library could not be located. Please make sure to reference this library before executing the scripts.\n"
      } else {
        send_msg_id USF-Questa-008 "CRITICAL WARNING" "Failed to find the pre-compiled simulation library!\n"
      }
      send_msg_id USF-Questa-009 INFO " Recommendation:- Please follow these instructions to resolve this issue:-\n\
                                             - set the 'COMPXLIB.QUESTA_COMPILED_LIBRARY_DIR' project property to the directory where Xilinx simulation libraries are compiled for Questa, or\n\
                                             - set the 'MODELSIM' environment variable to point to the $ini_file file, or\n\
                                             - set the 'WD_MGC' environment variable to point to the directory containing the $ini_file file\n"
    }
  } else {
    # 6. copy to run dir
    set ini_file_path [file normalize [file join $compiled_lib_dir $ini_file]]
    if { [file exists $ini_file_path] } {
      if {[catch {file copy -force $ini_file_path $a_sim_vars(s_launch_dir)} error_msg] } {
        send_msg_id USF_Questa-010 ERROR "Failed to copy file ($ini_file): $error_msg\n"
      } else {
        send_msg_id USF_Questa-011 INFO "File '$ini_file_path' copied to run dir:'$a_sim_vars(s_launch_dir)'\n"
      }
    }
  }
  if { ({} != $compiled_lib_dir) && ([file exists $compiled_lib_dir]) } {
   set a_sim_vars(compiled_library_dir) $compiled_lib_dir
  }
  return $compiled_lib_dir
}

proc usf_questa_create_lib_dir {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set design_lib_dir "$a_sim_vars(s_launch_dir)/questa_lib"

  if { ![file exists $design_lib_dir] } {
    if { [catch {file mkdir $design_lib_dir} error_msg] } {
      send_msg_id USF-Questa-013 ERROR "Failed to create the directory ($design_lib_dir): $error_msg\n"
      return 1
    }
  }
}

proc usf_questa_write_compile_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  # step exec mode?
  if { $a_sim_vars(b_exec_step) } {
    return 0
  }

  set do_filename {}
  set do_filename $a_sim_vars(s_sim_top);append do_filename "_compile.do"
  set do_file [file normalize [file join $a_sim_vars(s_launch_dir) $do_filename]]
  send_msg_id USF-Questa-015 INFO "Creating automatic 'do' files...\n"
  usf_questa_create_do_file_for_compilation $do_file

  # write compile.sh/.bat
  usf_questa_write_driver_shell_script $do_filename "compile"
}

proc usf_questa_write_elaborate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  # step exec mode?
  if { $a_sim_vars(b_exec_step) } {
    return 0
  }

  set do_filename {}
  set do_filename $a_sim_vars(s_sim_top);append do_filename "_elaborate.do"
  set do_file [file normalize [file join $a_sim_vars(s_launch_dir) $do_filename]]
  usf_questa_create_do_file_for_elaboration $do_file

  # write elaborate.sh/.bat
  usf_questa_write_driver_shell_script $do_filename "elaborate"
}

proc usf_questa_write_simulate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  # step exec mode?
  if { $a_sim_vars(b_exec_step) } {
    return 0
  }

  set do_filename {}
  # is custom do file specified?
  set custom_do_file [get_property "questa.simulate.custom_do" $a_sim_vars(fs_obj)]
  if { {} != $custom_do_file } {
    send_msg_id USF-Questa-014 INFO "Using custom 'do' file '$custom_do_file'...\n"
    set do_filename $custom_do_file
  } else {
    set do_filename $a_sim_vars(s_sim_top);append do_filename "_simulate.do"
    set do_file [file normalize [file join $a_sim_vars(s_launch_dir) $do_filename]]

    usf_questa_create_do_file_for_simulation $do_file
  }

  # write elaborate.sh/.bat
  usf_questa_write_driver_shell_script $do_filename "simulate"
}

proc usf_questa_create_udo_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # if udo file exists, return
  if { [file exists $file] } {
    return 0
  }
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id USF-Questa-016 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  usf_questa_write_header $fh $file
  close $fh
}

proc usf_questa_create_wave_do_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { [file exists $file] } {
    return 0
  }
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id USF-Questa-017 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  usf_questa_write_header $fh $file
  puts $fh "if \{ \[catch \{\[add wave *\]\}\] \} \{\}"

  if { ([xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) || $a_sim_vars(b_int_compile_glbl) || $a_sim_vars(b_force_compile_glbl) } {
    if { $a_sim_vars(b_force_no_compile_glbl) } {
      # skip glbl signal waveform if force no compile set
    } else {
      puts $fh "add wave /glbl/GSR"
    }
  }
  close $fh
}

proc usf_questa_create_do_file_for_compilation { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  variable l_ip_static_libs
  variable l_local_design_libraries

  set DS "\\\\"
  if {$::tcl_platform(platform) == "unix"} {
    set DS "/"
  }
  set tool_path_str ""
  if { {} != $a_sim_vars(s_install_path) } {
    if {$::tcl_platform(platform) == "unix"} {
      set tool_path_str "[xcs_replace_with_var $a_sim_vars(s_tool_bin_path) "SIM_VER" "questa"]${DS}"
    } else {
      set tool_path_str "$a_sim_vars(s_tool_bin_path)${DS}"
    }
  }

  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-Questa-018 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_questa_write_header $fh $do_file

  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    # no op
  } else {
    usf_add_quit_on_error $fh "compile"
  }
 
  set design_lib_dir "$a_sim_vars(s_launch_dir)/questa_lib"
  set lib_dir_path [file normalize [string map {\\ /} $design_lib_dir]]
  if { $a_sim_vars(b_absolute_path) } {
    puts $fh "${tool_path_str}vlib $lib_dir_path/work"
    puts $fh "${tool_path_str}vlib $lib_dir_path/msim\n"
  } else {
    puts $fh "${tool_path_str}vlib questa_lib/work"
    puts $fh "${tool_path_str}vlib questa_lib/msim\n"
  }

  set design_libs [xcs_get_design_libs $a_sim_vars(l_design_files) 0 0 0]

  if { $a_sim_vars(b_compile_simmodels) } {
    # get the design simmodel compile order
    set a_sim_vars(l_simmodel_compile_order) [xcs_get_simmodel_compile_order]

    foreach lib $a_sim_vars(l_simmodel_compile_order) {
      puts $fh "${tool_path_str}vlib questa_lib/msim/$lib"
    }
  }

  # TODO:
  # If DesignFiles contains VHDL files, but simulation language is set to Verilog, we should issue CW
  # Vice verse, if DesignFiles contains Verilog files, but simulation language is set to VHDL

  set b_default_lib false
  set default_lib $a_sim_vars(default_top_library)
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    if { $default_lib == $lib } {
      set b_default_lib true
    }
    set lib_path "msim/$lib"
    if { $a_sim_vars(b_use_static_lib) && ([xcs_is_static_ip_lib $lib $l_ip_static_libs]) } {
      # continue if no local library found or continue if this library is precompiled (not local)
      if { ([llength $l_local_design_libraries] == 0) || (![xcs_is_local_ip_lib $lib $l_local_design_libraries]) } {
        continue
      }
    }
    if { $a_sim_vars(b_absolute_path) } {
      puts $fh "${tool_path_str}vlib $lib_dir_path/$lib_path"
    } else {
      puts $fh "${tool_path_str}vlib questa_lib/$lib_path"
    }
  }
  if { !$b_default_lib } {
    if { $a_sim_vars(b_absolute_path) } {
      puts $fh "${tool_path_str}vlib $lib_dir_path/msim/$default_lib"
    } else {
      puts $fh "${tool_path_str}vlib questa_lib/msim/$default_lib"
    }
  }
   
  puts $fh ""

  if { $a_sim_vars(b_compile_simmodels) } {
    foreach lib $a_sim_vars(l_simmodel_compile_order) {
      if { $a_sim_vars(b_absolute_path) } {
        puts $fh "${tool_path_str}vmap $lib $lib_dir_path/msim/$lib"
      } else {
        puts $fh "${tool_path_str}vmap $lib questa_lib/msim/$lib"
      }
    }
  }

  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    if { $a_sim_vars(b_use_static_lib) && ([xcs_is_static_ip_lib $lib $l_ip_static_libs]) } {
      # continue if no local library found or continue if this library is precompiled (not local)
      if { ([llength $l_local_design_libraries] == 0) || (![xcs_is_local_ip_lib $lib $l_local_design_libraries]) } {
        continue
      }
    }
    if { $a_sim_vars(b_absolute_path) } {
      puts $fh "${tool_path_str}vmap $lib $lib_dir_path/msim/$lib"
    } else {
      puts $fh "${tool_path_str}vmap $lib questa_lib/msim/$lib"
    }
  }
  if { !$b_default_lib } {
    if { $a_sim_vars(b_absolute_path) } {
      puts $fh "${tool_path_str}vmap $default_lib $lib_dir_path/msim/$default_lib"
    } else {
      puts $fh "${tool_path_str}vmap $default_lib questa_lib/msim/$default_lib"
    }
  }

  if { $a_sim_vars(b_use_static_lib) } {
    set cmd "${tool_path_str}vmap"
    usf_questa_map_pre_compiled_libs $fh $cmd
  }

  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    # no op
  } else {
    puts $fh ""
    if { $a_sim_vars(b_absolute_path) } {
      puts $fh "set origin_dir \"$a_sim_vars(s_launch_dir)\""
    } else {
      puts $fh "set origin_dir \".\""
    }
  }

  set vlog_arg_list [list]
  if { [get_property "incremental" $a_sim_vars(fs_obj)] } {
    lappend vlog_arg_list "-incr"
  }
  set more_vlog_options [string trim [get_property "questa.compile.vlog.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_vlog_options } {
    set vlog_arg_list [linsert $vlog_arg_list end "$more_vlog_options"]
  }
  set vlog_cmd_str [join $vlog_arg_list " "]
  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    # no op
  } else {
    puts $fh "set vlog_opts \{$vlog_cmd_str\}"
  }

  set vcom_arg_list [list]
  set more_vcom_options [string trim [get_property "questa.compile.vcom.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_vcom_options } {
    set vcom_arg_list [linsert $vcom_arg_list end "$more_vcom_options"]
  }
  set vcom_cmd_str [join $vcom_arg_list " "]
  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    # no op
  } else {
    puts $fh "set vcom_opts \{$vcom_cmd_str\}"
  }

  puts $fh ""

  if { $a_sim_vars(b_compile_simmodels) } {
    usf_compile_simmodel_sources $fh
  }
  
  set b_first true
  set prev_lib  {}
  set prev_file_type {}
  set b_redirect false
  set b_appended false

  foreach file $a_sim_vars(l_design_files) {
    set fargs       [split $file {|}]
    set type        [lindex $fargs 0]
    set file_type   [lindex $fargs 1]
    set lib         [lindex $fargs 2]
    set cmd_str     [lindex $fargs 3]
    set src_file    [lindex $fargs 4]
    set b_static_ip [lindex $fargs 5]

    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }

    if { $b_first } {
      set b_first false
      usf_questa_set_initial_cmd $fh $cmd_str $src_file $file_type $lib prev_file_type prev_lib
    } else {
      if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
        puts $fh "$src_file \\"
        set b_redirect true
      } else {
        puts $fh ""
        usf_questa_set_initial_cmd $fh $cmd_str $src_file $file_type $lib prev_file_type prev_lib
        set b_appended true
      }
    }
  }

  if { (!$b_redirect) || (!$b_appended) } {
    puts $fh ""
  }

  xcs_add_hard_block_wrapper $fh "questa" "-64 -incr -mfcu" $a_sim_vars(s_launch_dir)

  set glbl_file "glbl.v"
  if { $a_sim_vars(b_absolute_path) } {
    set glbl_file [file normalize [file join $a_sim_vars(s_launch_dir) $glbl_file]]
  }

  # compile glbl file
  if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
    set b_load_glbl [get_property "questa.compile.load_glbl" [get_filesets $a_sim_vars(s_simset)]]
    if { [xcs_compile_glbl_file "questa" $b_load_glbl $a_sim_vars(b_int_compile_glbl) $a_sim_vars(l_design_files) $a_sim_vars(s_simset) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $a_sim_vars(b_force_compile_glbl) } {
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
        set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
        set file_str "-work $top_lib \"${glbl_file}\""
        puts $fh "\n# compile glbl module\n${tool_path_str}vlog $file_str"
      }
    }
  } else {
    # for post* compile glbl if design contain verilog and netlist is vhdl
    if { (([xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] && ({VHDL} == $a_sim_vars(s_target_lang))) ||
          ($a_sim_vars(b_int_compile_glbl)) || ($a_sim_vars(b_force_compile_glbl))) } {
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        if { ({timing} == $a_sim_vars(s_type)) } {
          # This is not supported, netlist will be verilog always
        } else {
          xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
          set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
          set file_str "-work $top_lib \"${glbl_file}\""
          puts $fh "\n# compile glbl module\n${tool_path_str}vlog $file_str"
        }
      }
    }
  }

  set b_is_unix false
  if {$::tcl_platform(platform) == "unix"} {
    set b_is_unix true
  }

  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] && $b_is_unix } {
    # no op
  } else {
    # *** windows only ***
    # for scripts only mode, do not quit if param is set to false (default param is true)
    if { ![get_param "simulator.quitOnSimulationComplete"] && $a_sim_vars(b_scripts_only) } {
      # for debugging purposes, do not quit from vsim shell
    } else {
      puts $fh "\nquit -force"
    }
    # *** windows only ***
  }

  # Intentional: add a blank line at the very end in do file to avoid vsim error detecting '\' at EOF
  #              when executing the do file directly with vsim (vsim -c -do tb.do)
  #              ** Error: <EOF> reached in ./tb_compile.do with incomplete command at line
  #              e.g vcom test.vhd \
  #
  puts $fh ""

  close $fh
}

proc usf_compile_simmodel_sources { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set platform "lin"
  if {$::tcl_platform(platform) == "windows"} {
    set platform "win"
  }

  set b_dbg 0
  if { $a_sim_vars(s_int_debug_mode) == "1" } {
    set b_dbg 1
  }

  set simulator "questa"
  set data_dir [rdi::get_data_dir -quiet -datafile "systemc/simlibs"]
  set cpt_dir  [xcs_get_simmodel_dir "questa" $a_sim_vars(s_gcc_version) "cpt"]

  # is pure-rtl sources for system simulation (selected_sim_model = rtl), don't need to compile the systemC/CPP/C sim-models
  if { [llength $a_sim_vars(l_simmodel_compile_order)] == 0 } {
    if { [file exists $a_sim_vars(s_simlib_dir)] } {
      # delete <run-dir>/simlibs dir (not required)
      [catch {file delete -force $a_sim_vars(s_simlib_dir)} error_msg]
    }
    return
  }

  # find simmodel info from dat file and update do file
  foreach lib_name $a_sim_vars(l_simmodel_compile_order) {
    set lib_path [xcs_find_lib_path_for_simmodel $lib_name]
    #
    set fh_dat 0
    set dat_file "$lib_path/.cxl.sim_info.dat"
    if {[catch {open $dat_file r} fh_dat]} {
      send_msg_id USF-Questa-016 WARNING "Failed to open file to read ($dat_file)\n"
      continue
    }
    set data [split [read $fh_dat] "\n"]
    close $fh_dat

    # is current platform supported?
    set simulator_platform {}
    set simmodel_name      {}
    set library_name       {}
    set b_process          0

    foreach line $data {
      set line [string trim $line]
      if { {} == $line } { continue }
      set line_info [split $line {:}]
      set tag   [lindex $line_info 0]
      set value [lindex $line_info 1]
      if { "<SIMMODEL_NAME>"              == $tag } { set simmodel_name $value }
      if { "<LIBRARY_NAME>"               == $tag } { set library_name $value  }
      if { "<SIMULATOR_PLATFORM>" == $tag } {
        if { ("all" == $value) || (("linux" == $value) && ("lin" == $platform)) || (("windows" == $vlue) && ("win" == $platform)) } {
          # supported
          set b_process 1
        } else {
          continue
        }
      }
    }

    # not supported, work on next simmodel
    if { !$b_process } { continue }

    #send_msg_id USF-Questa-107 STATUS "Generating compilation commands for '$lib_name'\n"

    # create local lib dir
    set simlib_dir "$a_sim_vars(s_simlib_dir)/$lib_name"
    if { ![file exists $simlib_dir] } {
      if { [catch {file mkdir $simlib_dir} error_msg] } {
        send_msg_id USF-Questa-013 ERROR "Failed to create the directory ($simlib_dir): $error_msg\n"
        return 1
      }
    }

    # copy simmodel sources locally
    if { $a_sim_vars(b_int_export_source_files) } {
      if { {} == $simmodel_name } { send_msg_id USF-Questa-107 WARNING "Empty tag '$simmodel_name'!\n" }
      if { {} == $library_name  } { send_msg_id USF-Questa-107 WARNING "Empty tag '$library_name'!\n"  }

      set src_sim_model_dir "$data_dir/systemc/simlibs/$simmodel_name/$library_name/src"
      set dst_dir "$a_sim_vars(s_launch_dir)/simlibs/$library_name"
      if { [file exists $src_sim_model_dir] } {
        [catch {file delete -force $dst_dir/src} error_msg]
        if { [catch {file copy -force $src_sim_model_dir $dst_dir} error_msg] } {
          [catch {send_msg_id USF-Questa-108 ERROR "Failed to copy file '$src_sim_model_dir' to '$dst_dir': $error_msg\n"} err]
        } else {
          #puts "copied '$src_sim_model_dir' to run dir:'$a_sim_vars(s_launch_dir)/simlibs'\n"
        }
      } else {
        [catch {send_msg_id USF-Questa-108 ERROR "File '$src_sim_model_dir' does not exist\n"} err]
      }
    }

    # copy include dir
    set simlib_incl_dir "$lib_path/include"
    set target_dir      "$a_sim_vars(s_simlib_dir)/$lib_name"
    set target_incl_dir "$target_dir/include"
    if { ![file exists $target_incl_dir] } {
      if { [catch {file copy -force $simlib_incl_dir $target_dir} error_msg] } {
        [catch {send_msg_id USF-Questa-010 ERROR "Failed to copy file '$simlib_incl_dir' to '$target_dir': $error_msg\n"} err]
      }
    }

    # simmodel file_info.dat data
    set library_type            {}
    set output_format           {}
    set gplus_compile_flags     [list]
    set gplus_compile_opt_flags [list]
    set gplus_compile_dbg_flags [list]
    set gcc_compile_flags       [list]
    set gcc_compile_opt_flags   [list]
    set gcc_compile_dbg_flags   [list]
    set ldflags                 [list]
    set gplus_ldflags_option    {}
    set gcc_ldflags_option      {}
    set ldflags_lin64           [list]
    set ldflags_win64           [list]
    set ldlibs                  [list]
    set ldlibs_lin64            [list]
    set ldlibs_win64            [list]
    set gplus_ldlibs_option     {}
    set gcc_ldlibs_option       {}
    set sysc_dep_libs           {}
    set cpp_dep_libs            {}
    set c_dep_libs              {}
    set sccom_compile_flags     {}
    set more_xsc_options        [list]
    set simulator_platform      {}
    set systemc_compile_option  {}
    set cpp_compile_option      {}
    set c_compile_option        {}
    set shared_lib              {}
    set systemc_incl_dirs       [list]
    set cpp_incl_dirs           [list]
    set osci_incl_dirs          [list]
    set c_incl_dirs             [list]

    set sysc_files [list]
    set cpp_files  [list]
    set c_files    [list]

    # process simmodel data from .dat file
    foreach line $data {
      set line [string trim $line]
      if { {} == $line } { continue }
      set line_info [split $line {:}]
      set tag       [lindex $line_info 0]
      set value     [lindex $line_info 1]

      # collect sources
      if { ("<SYSTEMC_SOURCES>" == $tag) || ("<CPP_SOURCES>" == $tag) || ("<C_SOURCES>" == $tag) } {
        set file_path "$data_dir/$value"

        # local file path where sources will be copied for export option
        if { $a_sim_vars(b_int_export_source_files) } {
          set dirs [split $value "/"]
          set value [join [lrange $dirs 3 end] "/"]
          set file_path "simlibs/$value"
        }

        if { ("<SYSTEMC_SOURCES>" == $tag) } { lappend sysc_files $file_path }
        if { ("<CPP_SOURCES>"     == $tag) } { lappend cpp_files  $file_path }
        if { ("<C_SOURCES>"       == $tag) } { lappend c_files    $file_path }
      }

      # get simmodel info
      if { "<LIBRARY_TYPE>"               == $tag } { set library_type            $value             }
      if { "<OUTPUT_FORMAT>"              == $tag } { set output_format           $value             }
      if { "<SYSTEMC_INCLUDE_DIRS>"       == $tag } { set systemc_incl_dirs       [split $value {,}] }
      if { "<CPP_INCLUDE_DIRS>"           == $tag } { set cpp_incl_dirs           [split $value {,}] }
      if { "<C_INCLUDE_DIRS>"             == $tag } { set c_incl_dirs             [split $value {,}] }
      if { "<OSCI_INCLUDE_DIRS>"          == $tag } { set osci_incl_dirs          [split $value {,}] }
      if { "<G++_COMPILE_FLAGS>"          == $tag } { set gplus_compile_flags     [split $value {,}] }
      if { "<G++_COMPILE_OPTIMIZE_FLAGS>" == $tag } { set gplus_compile_opt_flags [split $value {,}] }
      if { "<G++_COMPILE_DEBUG_FLAGS>"    == $tag } { set gplus_compile_dbg_flags [split $value {,}] }
      if { "<GCC_COMPILE_FLAGS>"          == $tag } { set gcc_compile_flags       [split $value {,}] }
      if { "<GCC_COMPILE_OPTIMIZE_FLAGS>" == $tag } { set gcc_compile_opt_flags   [split $value {,}] }
      if { "<GCC_COMPILE_DEBUG_FLAGS>"    == $tag } { set gcc_compile_dbg_flags   [split $value {,}] }
      if { "<LDFLAGS>"                    == $tag } { set ldflags                 [split $value {,}] }
      if { "<LDFLAGS_LNX64>"              == $tag } { set ldflags_lin64           [split $value {,}] }
      if { "<LDFLAGS_WIN64>"              == $tag } { set ldflags_win64           [split $value {,}] }
      if { "<G++_LDFLAGS_OPTION>"         == $tag } { set gplus_ldflags_option    $value             }
      if { "<GCC_LDFLAGS_OPTION>"         == $tag } { set gcc_ldflags_option      $value             }
      if { "<LDLIBS>"                     == $tag } { set ldlibs                  [split $value {,}] }
      if { "<LDLIBS_LNX64>"               == $tag } { set ldlibs_lin64            [split $value {,}] }
      if { "<LDLIBS_WIN64>"               == $tag } { set ldlibs_win64            [split $value {,}] }
      if { "<G++_LDLIBS_OPTION>"          == $tag } { set gplus_ldlibs_option     $value             }
      if { "<GCC_LDLIBS_OPTION>"          == $tag } { set gcc_ldlibs_option       $value             }
      if { "<SYSTEMC_DEPENDENT_LIBS>"     == $tag } { set sysc_dep_libs           $value             }
      if { "<CPP_DEPENDENT_LIBS>"         == $tag } { set cpp_dep_libs            $value             }
      if { "<C_DEPENDENT_LIBS>"           == $tag } { set c_dep_libs              $value             }
      if { "<SCCOM_COMPILE_FLAGS>"        == $tag } { set sccom_compile_flags     $value             }
      if { "<MORE_XSC_OPTIONS>"           == $tag } { set more_xsc_options        [split $value {,}] }
      if { "<SIMULATOR_PLATFORM>"         == $tag } { set simulator_platform      $value             }
      if { "<SYSTEMC_COMPILE_OPTION>"     == $tag } { set systemc_compile_option  $value             }
      if { "<CPP_COMPILE_OPTION>"         == $tag } { set cpp_compile_option      $value             }
      if { "<C_COMPILE_OPTION>"           == $tag } { set c_compile_option        $value             }
      if { "<SHARED_LIBRARY>"             == $tag } { set shared_lib              $value             }
    }

    set obj_dir "$a_sim_vars(s_launch_dir)/questa_lib/$lib_name"
    if { ![file exists $obj_dir] } {
      if { [catch {file mkdir $obj_dir} error_msg] } {
        send_msg_id USF-Questa-013 ERROR "Failed to create the directory ($obj_dir): $error_msg\n"
        return 1
      }
    }

    #
    # write systemC/CPP/C command line
    #
    if { [llength $sysc_files] > 0 } {
      # write cmf file
      set compiler "sccom"
      set cmf_filename "${lib_name}.cmf"
      set cmf "$a_sim_vars(s_launch_dir)/$cmf_filename"
      set fh_cmf 0
      if {[catch {open $cmf w} fh_cmf]} {
        send_msg_id USF-Questa-016 WARNING "Failed to open file to write ($cmf)\n"
      } else {
        foreach sysc_file $sysc_files {
          puts $fh_cmf $sysc_file
        }
        close $fh_cmf
      }
    
      #
      # COMPILE (sccom)
      #
      set args [list]
      lappend args "-64"
      set gcc_path "$a_sim_vars(s_gcc_bin_path)/g++"
      if {$::tcl_platform(platform) == "unix"} {
        set gcc_path "[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_gcc_bin_path) "SIM_VER" "questa"] "GCC_VER" "questa"]/g++"
      }
      lappend args "-cpppath $gcc_path"
      
      # <SYSTEMC_COMPILE_OPTION>
      if { {} != $systemc_compile_option } { lappend args $systemc_compile_option }

      # <SCCOM_COMPILE_FLAGS>
      lappend args "$sccom_compile_flags"
  
      # <SYSTEMC_INCLUDE_DIRS> 
      if { [llength $systemc_incl_dirs] > 0 } {
        foreach incl_dir $systemc_incl_dirs {
          if { [regexp {^\$xv_cpt_lib_path} $incl_dir] } {
            set str_to_replace "xv_cpt_lib_path"
            set str_replace_with "$cpt_dir"
            regsub -all $str_to_replace $incl_dir $str_replace_with incl_dir 
            set incl_dir [string trimleft $incl_dir {\$}]
            set incl_dir "$data_dir/$incl_dir"
          }
          if { [regexp {^\$xv_ext_lib_path} $incl_dir] } {
            set str_to_replace "xv_ext_lib_path"
            set str_replace_with "$a_sim_vars(sp_ext_dir)"
            regsub -all $str_to_replace $incl_dir $str_replace_with incl_dir 
            set incl_dir [string trimleft $incl_dir {\$}]
          }
          if {$::tcl_platform(platform) == "unix"} {
            lappend args "-I [xcs_replace_with_var [xcs_replace_with_var $incl_dir "SIM_VER" "questa"] "GCC_VER" "questa"]"
          } else {
            lappend args "-I $incl_dir"
          }
        }
      }
   
      # <CPP_COMPILE_OPTION> 
      lappend args $cpp_compile_option

      # <G++_COMPILE_FLAGS>
      foreach opt $gplus_compile_flags { lappend args $opt }

      # <G++_COMPILE_OPTIMIZE_FLAGS>
      foreach opt $gplus_compile_opt_flags { lappend args $opt }
    
      # config simmodel options
      set cfg_opt "${simulator}.compile.${compiler}.${library_name}"
      set cfg_val ""
      [catch {set cfg_val [get_param $cfg_opt]} err]
      if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
        lappend args "$cfg_val"
      }
    
      # global simmodel option (if any)
      set cfg_opt "${simulator}.compile.${compiler}.global"
      set cfg_val ""
      [catch {set cfg_val [get_param $cfg_opt]} err]
      if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
        lappend args "$cfg_val"
      }

      # work dir    
      lappend args "-work $lib_name"
      lappend args "-f ${lib_name}.cmf"
    
      set cmd_str [join $args " "]
      puts $fh "# compile '$lib_name' model sources"
      puts $fh "$a_sim_vars(s_tool_bin_path)/$compiler $cmd_str\n"
   
      # 
      # LINK (sccom)
      #
      set args [list]
      lappend args "-64"
      set gcc_path "$a_sim_vars(s_gcc_bin_path)/g++"
      if {$::tcl_platform(platform) == "unix"} {
        set gcc_path "[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_gcc_bin_path) "SIM_VER" "questa"] "GCC_VER" "questa"]/g++"
      }
      lappend args "-cpppath $gcc_path"

      # <SYSTEMC_COMPILE_OPTION>
      if { {} != $systemc_compile_option } {
        lappend args $systemc_compile_option
      }
      lappend args "-linkshared"
      lappend args "-lib $lib_name"
    
      # <LDFLAGS>
      if { [llength $ldflags] > 0 } { foreach opt $ldflags { lappend args $opt } }

      if {$::tcl_platform(platform) == "windows"} {
        if { [llength $ldflags_win64] > 0 } { foreach opt $ldflags_win64 { lappend args $opt } }
      } else {
        if { [llength $ldflags_lin64] > 0 } { foreach opt $ldflags_lin64 { lappend args $opt } }
      }
    
      # acd ldflags 
      if { {} != $gplus_ldflags_option } { lappend args $gplus_ldflags_option }
   
      # <LDLIBS>
      if { [llength $ldlibs] > 0 } {
        foreach opt $ldlibs {
          if { [regexp {\$xv_cpt_lib_path} $opt] } {
            set cpt_dir_path "$data_dir/$cpt_dir"
            set str_to_replace {\$xv_cpt_lib_path}
            set str_replace_with "$cpt_dir_path"
            regsub -all $str_to_replace $opt $str_replace_with opt 
          }
          lappend args $opt
        }
      }
    
      if {$::tcl_platform(platform) == "windows"} {
        if { [llength $ldlibs_win64] > 0 } { foreach opt $ldlibs_win64 { lappend args $opt } }
      } else {
        if { [llength $ldlibs_lin64] > 0 } { foreach opt $ldlibs_lin64 { lappend args $opt } }
      }
    
      # acd ldlibs
      if { {} != $gplus_ldlibs_option } { lappend args "$gplus_ldlibs_option" }
    
      lappend args "-work $lib_name"
      set cmd_str [join $args " "]
      puts $fh "$a_sim_vars(s_tool_bin_path)/$compiler $cmd_str\n"

    } elseif { [llength $cpp_files] > 0 } {
      puts $fh "# compile '$lib_name' model sources"
      set compiler "g++"
      #
      # COMPILE (g++)
      #
      foreach src_file $cpp_files {
        set file_name [file root [file tail $src_file]]
        set obj_file "${file_name}.o"

        # construct g++ compile command line
        set args [list]
        lappend args "-c"
  
        # <CPP_INCLUDE_DIRS>
        if { [llength $cpp_incl_dirs] > 0 } { foreach incl_dir $cpp_incl_dirs { lappend args "-I $incl_dir" } }

        # <CPP_COMPILE_OPTION>
        lappend args $cpp_compile_option

        # <G++_COMPILE_FLAGS>
        if { [llength $gplus_compile_flags] > 0 } { foreach opt $gplus_compile_flags { lappend args $opt } }

        # <G++_COMPILE_OPTIMIZE_FLAGS>
        if { $b_dbg } {
          if { [llength $gplus_compile_dbg_flags] > 0 } { foreach opt $gplus_compile_dbg_flags { lappend args $opt } }
        } else {
          if { [llength $gplus_compile_opt_flags] > 0 } { foreach opt $gplus_compile_opt_flags { lappend args $opt } }
        }

        # config simmodel options
        set cfg_opt "${simulator}.compile.${compiler}.${library_name}"
        set cfg_val ""
        [catch {set cfg_val [get_param $cfg_opt]} err]
        if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
          lappend args "$cfg_val"
        }
      
        # global simmodel option (if any)
        set cfg_opt "${simulator}.compile.${compiler}.global"
        set cfg_val ""
        [catch {set cfg_val [get_param $cfg_opt]} err]
        if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
          lappend args "$cfg_val"
        }

        lappend args $src_file
        lappend args "-o"
        lappend args "questa_lib/$lib_name/${obj_file}"

        set cmd_str [join $args " "]
        puts $fh "$a_sim_vars(s_gcc_bin_path)/$compiler $cmd_str\n"
      }
    
      # 
      # LINK (g++)
      #
      set args [list]
      foreach src_file $cpp_files {
        set file_name [file root [file tail $src_file]]
        set obj_file "questa_lib/$lib_name/${file_name}.o"
        lappend args $obj_file
      }
      lappend args "-shared"
      lappend args "-o"
      lappend args "questa_lib/$lib_name/lib${lib_name}.so"
      
      set cmd_str [join $args " "]
      puts $fh "$a_sim_vars(s_gcc_bin_path)/$compiler $cmd_str\n"

    } elseif { [llength $c_files] > 0 } {
      puts $fh "# compile '$lib_name' model sources"
      set compiler "gcc"
      #
      # COMPILE (gcc)
      #
      foreach src_file $c_files {
        set file_name [file root [file tail $src_file]]
        set obj_file "${file_name}.o"

        # construct gcc compile command line
        set args [list]
        lappend args "-c"
  
        # <C_INCLUDE_DIRS>
        if { [llength $c_incl_dirs] > 0 } { foreach incl_dir $c_incl_dirs { lappend args "-I $incl_dir" } }

        # <C_COMPILE_OPTION>
        lappend args $c_compile_option

        # <GCC_COMPILE_FLAGS>
        if { [llength $gcc_compile_flags] > 0 } { foreach opt $gcc_compile_flags { lappend args $opt } }

        # <GCC_COMPILE_OPTIMIZE_FLAGS>
        if { $b_dbg } {
          if { [llength $gcc_compile_dbg_flags] > 0 } { foreach opt $gcc_compile_dbg_flags { lappend args $opt } }
        } else {
          if { [llength $gcc_compile_opt_flags] > 0 } { foreach opt $gcc_compile_opt_flags { lappend args $opt } }
        }

        # config simmodel options
        set cfg_opt "${simulator}.compile.${compiler}.${library_name}"
        set cfg_val ""
        [catch {set cfg_val [get_param $cfg_opt]} err]
        if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
          lappend args "$cfg_val"
        }
      
        # global simmodel option (if any)
        set cfg_opt "${simulator}.compile.${compiler}.global"
        set cfg_val ""
        [catch {set cfg_val [get_param $cfg_opt]} err]
        if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
          lappend args "$cfg_val"
        }

        lappend args $src_file
        lappend args "-o"
        lappend args "questa_lib/$lib_name/${obj_file}"

        set cmd_str [join $args " "]
        puts $fh "$a_sim_vars(s_gcc_bin_path)/$compiler $cmd_str\n"
      }
    
      # 
      # LINK (gcc)
      #
      set args [list]
      foreach src_file $c_files {
        set file_name [file root [file tail $src_file]]
        set obj_file "questa_lib/$lib_name/${file_name}.o"
        lappend args $obj_file
      }
      lappend args "-shared"
      lappend args "-o"
      lappend args "questa_lib/$lib_name/lib${lib_name}.so"
      
      set cmd_str [join $args " "]
      puts $fh "$a_sim_vars(s_gcc_bin_path)/$compiler $cmd_str\n"

    }
  }
}

proc usf_questa_create_do_file_for_elaboration { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set DS "\\\\"
  if {$::tcl_platform(platform) == "unix"} {
    set DS "/"
  }
  set tool_path_str ""
  if { {} != $a_sim_vars(s_install_path) } {
    set tool_path_str "$a_sim_vars(s_tool_bin_path)${DS}"
    if {$::tcl_platform(platform) == "unix"} {
      set tool_path_str "[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_tool_bin_path) "SIM_VER" "questa"] "GCC_VER" "questa"]${DS}"
    }
  }

  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-Questa-019 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_questa_write_header $fh $do_file
  if {$::tcl_platform(platform) == "unix"} {
    xcs_write_version_id $fh "questa"
  }
  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    # no op
  } else {
    usf_add_quit_on_error $fh "elaborate"
  }

  set cmd_str [usf_questa_get_elaboration_cmdline]
  puts $fh "\n${tool_path_str}$cmd_str"

  set b_is_unix false
  if {$::tcl_platform(platform) == "unix"} {
    set b_is_unix true
  }

  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] && $b_is_unix } {
    # no op
  } else {
    # *** windows only ***
    # for scripts only mode, do not quit if param is set to false (default param is true)
    if { ![get_param "simulator.quitOnSimulationComplete"] && $a_sim_vars(b_scripts_only) } {
      # for debugging purposes, do not quit from vsim shell
    } else {
      puts $fh "\nquit -force"
    }
    # *** windows only ***
  }

  close $fh
}

proc usf_questa_get_elaboration_cmdline {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set netlist_mode [get_property "nl.mode" $a_sim_vars(fs_obj)]

  set tool "vopt"
  set arg_list [list]

  if { [get_param project.writeNativeScriptForUnifiedSimulation] } {
    if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
      lappend arg_list {-32}
    } else {
      if {$::tcl_platform(platform) == "windows"} {
        # -64 not supported
      } else {
        lappend arg_list {-64}
      }
    }
  }

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_contain_systemc_sources) } {
    set gcc_path "$a_sim_vars(s_gcc_bin_path)/g++"
    if {$::tcl_platform(platform) == "unix"} {
      set gcc_path "[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_gcc_bin_path) "SIM_VER" "questa"] "GCC_VER" "questa"]/g++"
    }
    lappend arg_list "-cpppath $gcc_path"
  }

  set acc [get_property "questa.elaborate.acc" $a_sim_vars(fs_obj)]
  if { [get_param "simulator.enableqisflow"] } {
    set opt_mode [get_property -quiet "questa.elaborate.opt_mode" $a_sim_vars(fs_obj)]
    if { {None} == $acc } {
      # no val
    } elseif { "acc=npr" == $acc } {
      if { {access} == $opt_mode } {
        lappend arg_list "-access=r+/."
      } elseif { {debug} == $opt_mode } {
        lappend arg_list "-debug"
      }
    } elseif { "acc" == $acc } {
      if { {access} == $opt_mode } {
        lappend arg_list "-uvmaccess"
      }
    }
  } else {
    if { {None} == $acc } {
      # no val
    } else {
      # not enabled for Questa yet (# ** Error (suppressible): (vsim-12130) WLF logging is not supported with QIS.)
      set a_sim_vars(b_int_perf_analysis) 0
      if { $a_sim_vars(b_int_perf_analysis) } {
        if { ("acc=npr" == $acc) } {
          lappend arg_list "-access=r+/."
        }
      } else {
        lappend arg_list "+$acc"
      }
    }
  }

  set vhdl_generics [list]
  set vhdl_generics [get_property "generic" [get_filesets $a_sim_vars(fs_obj)]]
  if { [llength $vhdl_generics] > 0 } {
    xcs_append_generics "questa" $vhdl_generics arg_list  
  }

  if { $a_sim_vars(b_int_fix_noc_assertion) } {
    lappend arg_list "-inlineFactor=0 -noprotectopt"
  }
 
  #
  # 1123017 (suppress "Warning: (vopt-10016) Option '-L <lib>' was detected by vlog for design-unit '<du>',
  #          but was not detected by vopt. The vlog option will be ignored." for sv source based package
  #          libraries that are referenced in vlog -L <sv-pkg-lib>)
  #
  lappend arg_list "-suppress 10016"

  set more_vopt_options [string trim [get_property "questa.elaborate.vopt.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_vopt_options } {
    set arg_list [linsert $arg_list end "$more_vopt_options"]
  }

  set t_opts [join $arg_list " "]

  set design_files $a_sim_vars(l_design_files)
  set design_libs [xcs_get_design_libs $design_files 1 1 1]

  # add simulation libraries
  set arg_list [list]

  # add sv pkg libraries
  #variable a_sim_sv_pkg_libs
  #foreach lib $a_sim_sv_pkg_libs {
  #  if { [lsearch $design_libs $lib] == -1 } {
  #    lappend arg_list "-L"
  #    lappend arg_list "$lib"
  #  }
  #}

  # add user design libraries
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend arg_list "-L"
    lappend arg_list "$lib"
    #lappend arg_list "[string tolower $lib]"
  }
  
  if { $a_sim_vars(b_enable_netlist_sim) && $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) && ({} != $a_sim_vars(sp_xlnoc_bd_obj)) } {
    foreach noc_lib [xcs_get_noc_libs_for_netlist_sim $a_sim_vars(s_simulation_flow) $a_sim_vars(s_type)] {
      if { [regexp {^noc_nmu_v} $noc_lib] } { continue; } 
      lappend arg_list "-L $noc_lib"
    }
  }

  # add xilinx vip library
  if { [get_param "project.usePreCompiledXilinxVIPLibForSim"] } {
    if { [xcs_design_contain_sv_ip] } {
      lappend arg_list "-L"
      lappend arg_list "xilinx_vip"
    }
  }

  # post* simulation
  if { ({post_synth_sim} == $a_sim_vars(s_simulation_flow)) || ({post_impl_sim} == $a_sim_vars(s_simulation_flow)) } {
    if { [xcs_contains_verilog $design_files $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || ({Verilog} == $a_sim_vars(s_target_lang)) } {
      if { {timesim} == $netlist_mode } {
        set arg_list [linsert $arg_list end "-L" "simprims_ver"]
      } else {
        set arg_list [linsert $arg_list end "-L" "unisims_ver"]
      }
    }
  }

  # behavioral simulation
  set b_compile_unifast 0
  set simulator_language [string tolower [get_property "simulator_language" [current_project]]]
  if { ([get_param "simulation.addUnifastLibraryForVhdl"]) && ({vhdl} == $simulator_language) } {
    set b_compile_unifast [get_property "unifast" $a_sim_vars(fs_obj)]
  }

  if { ([xcs_contains_vhdl $design_files $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $a_sim_vars(s_simulation_flow)) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-L" "unifast"]
    }
  }

  set b_compile_unifast [get_property "unifast" $a_sim_vars(fs_obj)]
  if { ([xcs_contains_verilog $design_files $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $a_sim_vars(s_simulation_flow)) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-L" "unifast_ver"]
    }
    set arg_list [linsert $arg_list end "-L" "unisims_ver"]
    set arg_list [linsert $arg_list end "-L" "unimacro_ver"]
  }

  if { $a_sim_vars(b_int_compile_glbl) || $a_sim_vars(b_force_compile_glbl) } {
    if { ([lsearch -exact $arg_list "unisims_ver"] == -1) } {
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip unisims_ver
      } else {
        set arg_list [linsert $arg_list end "-L" "unisims_ver"]
      }
    }
  }

  # add secureip
  set arg_list [linsert $arg_list end "-L" "secureip"]

  # reference XPM modules from precompiled libs if param is set
  set b_reference_xpm_library 0
  [catch {set b_reference_xpm_library [get_param project.usePreCompiledXPMLibForSim]} err]

  # for precompile flow, if xpm library not found from precompiled libs, compile it locally
  # for non-precompile flow, compile xpm locally and do not reference precompiled xpm library
  if { $b_reference_xpm_library } {
    if { $a_sim_vars(b_use_static_lib) } {
      variable l_compiled_libraries
      if { ([lsearch -exact $l_compiled_libraries "xpm"] == -1) } {
        set b_reference_xpm_library 0
      }
    } else {
      set b_reference_xpm_library 0
    }
  }

  if { $b_reference_xpm_library } {
    # pass xpm library reference for behavioral simulation only
    if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
      set arg_list [linsert $arg_list end "-L" "xpm"]
    }
  }

  # add ap lib
  variable l_hard_blocks
  if { [llength $l_hard_blocks] > 0 } {
    lappend arg_list "-L aph"
  }

  lappend arg_list "-work"
  lappend arg_list $a_sim_vars(default_top_library)
  
  set d_libs [join $arg_list " "]
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]

  set arg_list [list $tool $t_opts]
  lappend arg_list "$d_libs"

  variable l_hard_blocks
  foreach hb $l_hard_blocks {
    set hb_wrapper "xil_defaultlib.${hb}_sim_wrapper"
    lappend arg_list "$hb_wrapper"
  }

  lappend arg_list "${top_lib}.$a_sim_vars(s_sim_top)"

  # logical noc
  set lnoc_top [get_property -quiet "logical_noc_top" $a_sim_vars(fs_obj)]
  if { {} != $lnoc_top } {
    set lib [get_property -quiet "logical_noc_top_lib" $a_sim_vars(fs_obj)]
    lappend arg_list "${lib}.${lnoc_top}"
  }

  set top_level_inst_names {}
  usf_add_glbl_top_instance arg_list $top_level_inst_names

  lappend arg_list "-o"
  lappend arg_list "$a_sim_vars(s_sim_top)_opt"

  set cmd_str [join $arg_list " "]
  return $cmd_str
}

proc usf_questa_get_simulation_cmdline {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set netlist_mode [get_property "nl.mode" $a_sim_vars(fs_obj)]

  set tool "vsim"
  set arg_list [list "$tool"]

  set path_delay 0
  set int_delay 0
  set tpd_prop "TRANSPORT_PATH_DELAY"
  set tid_prop "TRANSPORT_INT_DELAY"
  if { [lsearch -exact [list_property -quiet $a_sim_vars(fs_obj)] $tpd_prop] != -1 } {
    set path_delay [get_property $tpd_prop $a_sim_vars(fs_obj)]
  }
  if { [lsearch -exact [list_property -quiet $a_sim_vars(fs_obj)] $tid_prop] != -1 } {
    set int_delay [get_property $tid_prop $a_sim_vars(fs_obj)]
  }

  if { ({post_synth_sim} == $a_sim_vars(s_simulation_flow) || {post_impl_sim} == $a_sim_vars(s_simulation_flow)) && ({timesim} == $netlist_mode) } {
    lappend arg_list "+transport_int_delays"
    lappend arg_list "+pulse_e/$path_delay"
    lappend arg_list "+pulse_int_e/$int_delay"
    lappend arg_list "+pulse_r/$path_delay"
    lappend arg_list "+pulse_int_r/$int_delay"
  }

  set b_async_update [get_property -quiet "questa.simulate.sc_async_update" $a_sim_vars(fs_obj)]
  if { $b_async_update } {
    set arg_list [linsert $arg_list end "-scasyncupdate"]
  }

  set more_sim_options [string trim [get_property "questa.simulate.vsim.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_sim_options } {
    set arg_list [linsert $arg_list end "$more_sim_options"]
  }

  set b_bind_dpi_c false
  [catch {set b_bind_dpi_c [get_param project.bindGTDPICModel]} err]
  set ip_obj [xcs_find_ip "gt_quad_base"]
  if { {} != $ip_obj } {
    set gt_lib "gtye5_quad"
    # 1054737
    # set clibs_dir "[xcs_get_relative_file_path $a_sim_vars(s_clibs_dir) $a_sim_vars(s_launch_dir)]"
    set clibs_dir [string map {\\ /} $a_sim_vars(s_clibs_dir)]
    # default install location
    set shared_lib_dir "${clibs_dir}/secureip"
    if { $b_bind_dpi_c } {
      lappend arg_list "-sv_root \"$shared_lib_dir\" -sv_lib $gt_lib"
    }
  }

  if { [get_param "project.allowSharedLibraryType"] } {
    foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_filesets $a_sim_vars(fs_obj)]] {
      if { {Shared Library} == [get_property "file_type" $file] } {
        set file_dir [file dirname $file]
        set file_dir "[xcs_get_relative_file_path $file_dir $a_sim_vars(s_launch_dir)]"

        if { [get_param "project.copyShLibsToCurrRunDir"] } {
          if { [file exists $file] } {
            if { [catch {file copy -force $file $a_sim_vars(s_launch_dir)} error_msg] } {
              send_msg_id USF_Questa-010 ERROR "Failed to copy file ($file): $error_msg\n"
            } else {
              send_msg_id USF_Questa-011 INFO "File '$file' copied to run dir:'$a_sim_vars(s_launch_dir)'\n"
            }
          }
          set file_dir "."
        }

        set file_name [file tail $file]
        if { [string match "lib*so" $file_name] } {
          # remove ".so" from libraryname 
          set file_name [string range $file_name 0 end-3]
        }
        lappend arg_list "-sv_root \"$file_dir\" -sv_lib $file_name"
      }
    }
  }

  lappend arg_list "-lib"
  lappend arg_list $a_sim_vars(default_top_library)
  lappend arg_list "$a_sim_vars(s_sim_top)_opt"

  set cmd_str [join $arg_list " "]
  return $cmd_str
}

proc usf_add_glbl_top_instance { opts_arg top_level_inst_names } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts

  variable a_sim_vars

  set b_verilog_sim_netlist 0
  if { ({post_synth_sim} == $a_sim_vars(s_simulation_flow)) || ({post_impl_sim} == $a_sim_vars(s_simulation_flow)) } {
    if { {Verilog} == $a_sim_vars(s_target_lang) } {
      set b_verilog_sim_netlist 1
    }
  }

  set b_add_glbl 0
  set b_top_level_glbl_inst_set 0

  # is glbl specified explicitly?
  if { ([lsearch ${top_level_inst_names} {glbl}] != -1) } {
    set b_top_level_glbl_inst_set 1
  }

  set b_load_glbl [get_property "questa.compile.load_glbl" $a_sim_vars(fs_obj)]
  if { [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $b_verilog_sim_netlist } {
    if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
      if { (!$b_top_level_glbl_inst_set) && $b_load_glbl } {
        set b_add_glbl 1
      }
    } else {
      # for post* sim flow add glbl top if design contains verilog sources or verilog netlist add glbl top if not set earlier
      if { !$b_top_level_glbl_inst_set } {
        set b_add_glbl 1
      }
    }
  }

  if { !$b_add_glbl } {
    if { $a_sim_vars(b_int_compile_glbl) } {
      set b_add_glbl 1
    }
  }

  if { !$b_add_glbl } {
    if { $b_load_glbl } {
      # TODO: revisit this for pure vhdl, causing failures
      #set b_add_glbl 1
    }
  }

  # force compile glbl
  if { !$b_add_glbl } {
    if { $a_sim_vars(b_force_compile_glbl) } {
      set b_add_glbl 1
    }
  }

  # force no compile glbl
  if { $b_add_glbl && $a_sim_vars(b_force_no_compile_glbl) } {
    set b_add_glbl 0
  }
  
  if { $b_add_glbl } {
    set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
    lappend opts "${top_lib}.glbl"
  }
}

proc usf_questa_create_do_file_for_simulation { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-Questa-021 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_questa_write_header $fh $do_file
  set wave_do_filename $a_sim_vars(s_sim_top);append wave_do_filename "_wave.do"
  set wave_do_file [file normalize [file join $a_sim_vars(s_launch_dir) $wave_do_filename]]
  set custom_wave_do_file [get_property "questa.simulate.custom_wave_do" $a_sim_vars(fs_obj)]
  if { {} != $custom_wave_do_file } {
    set wave_do_filename $custom_wave_do_file
    # custom wave do specified, delete existing auto generated wave do file from run dir
    if { [file exists $wave_do_file] } {
      [catch {file delete -force $wave_do_file} error_msg]
    }
  } else {
    usf_questa_create_wave_do_file $wave_do_file
  }
  #if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
  #  # TODO: this is not required but mentioned in hw_emu_common_util.tcl (need to confirm)
  #  #puts $fh "set xv_lib_path \"\$::env(XILINX_VIVADO)/lib/lnx64.o/Default:\$::env(XILINX_VIVADO)/lib/lnx64.o\""
  #}
  set cmd_str [usf_questa_get_simulation_cmdline]
  usf_add_quit_on_error $fh "simulate"
  
  if { [get_param "project.allowSharedLibraryType"] } {
    puts $fh "set xv_lib_path \"$::env(RDI_LIBDIR)\""
  }

  puts $fh "$cmd_str"
  if { [get_property "questa.simulate.ieee_warnings" $a_sim_vars(fs_obj)] } {
    puts $fh "\nset NumericStdNoWarnings 1"
    puts $fh "set StdArithNoWarnings 1"
  }

  if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
    puts $fh "\nif \{ \[file exists vitis_params.tcl\] \} \{"
    puts $fh "  source vitis_params.tcl"
    puts $fh "\}"
    puts $fh "\nif \{ \[info exists ::env(USER_PRE_SIM_SCRIPT)\] \} \{"
    puts $fh "  if \{ \[catch \{source \$::env(USER_PRE_SIM_SCRIPT)\} msg\] \} \{"
    puts $fh "    puts \$msg"
    puts $fh "  \}"
    puts $fh "\}"
  }
  
  puts $fh "\ndo \{$wave_do_filename\}"
  puts $fh "\nview wave"
  puts $fh "view structure"
  puts $fh "view signals\n"

  set b_log_all_signals [get_property "questa.simulate.log_all_signals" $a_sim_vars(fs_obj)]
  if { $b_log_all_signals } {
    puts $fh "log -r /*\n"
  }
 
  # generate saif file for power estimation
  set saif [get_property "questa.simulate.saif" $a_sim_vars(fs_obj)] 
  if { {} != $saif } {
    set uut {}
    [catch {set uut [get_property -quiet "questa.simulate.uut" $a_sim_vars(fs_obj)]} msg]
    set saif_scope [get_property "questa.simulate.saif_scope" $a_sim_vars(fs_obj)]
    if { {} != $saif_scope } {
      set uut $saif_scope
    }
    if { {} == $uut } {
      set uut "/$a_sim_vars(s_sim_top)/uut/*"
    }
    set simulator "questa"
    if { ({functional} == $a_sim_vars(s_type)) || \
         ({timing} == $a_sim_vars(s_type)) } {
      puts $fh "power add -r -in -inout -out -nocellnet -internal [xcs_resolve_uut_name $simulator uut]\n"
    } else {
      puts $fh "power add -in -inout -out -nocellnet -internal [xcs_resolve_uut_name $simulator uut]\n"
    }
  }
  # create custom UDO file
  set udo_file [get_property "questa.simulate.custom_udo" $a_sim_vars(fs_obj)]
  if { {} == $udo_file } {
    set udo_filename $a_sim_vars(s_sim_top);append udo_filename ".udo"
    set udo_file [file normalize [file join $a_sim_vars(s_launch_dir) $udo_filename]]
    usf_questa_create_udo_file $udo_file
    puts $fh "do \{$a_sim_vars(s_sim_top).udo\}"
  } else {
    puts $fh "do \{$udo_file\}"
  }

  # write tcl post hook for windows
  set tcl_post_hook [get_property "questa.simulate.tcl.post" $a_sim_vars(fs_obj)]
  if { {} != $tcl_post_hook } {
    puts $fh "\n# execute post tcl file"
    puts $fh "set rc \[catch \{"
    puts $fh "  puts \"source $tcl_post_hook\""
    puts $fh "  source \"$tcl_post_hook\""
    puts $fh "\} result\]"
    puts $fh "if \{\$rc\} \{"
    puts $fh "  puts \"\$result\""
    puts $fh "  puts \"ERROR: \\\[USF-simtcl-1\\\] Script failed:$tcl_post_hook\""
    #puts $fh "  return -code error"
    puts $fh "\}"
  }

  set rt [string trim [get_property "questa.simulate.runtime" $a_sim_vars(fs_obj)]]
  if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
    puts $fh "\nputs \"We are running simulator for infinite time. Added some default signals in the waveform. You can pause simulation and add signals and then resume the simulation again.\""
    puts $fh "puts \"\""
    puts $fh "puts \"Stopping at breakpoint in simulator also stops the host code execution\""
    puts $fh "puts \"\""
    puts $fh "if \{ \[info exists ::env(VITIS_LAUNCH_WAVEFORM_GUI) \] \} \{"
    puts $fh "  run 1ns"
    puts $fh "\} else \{"
    if { {} == $rt } {
      # no runtime specified
      puts $fh "  run"
    } else {
      set rt_value [string tolower $rt]
      if { ({all} == $rt_value) || (![regexp {^[0-9]} $rt_value]) } {
        puts $fh "  run -all"
      } else {
        puts $fh "  run $rt"
      }
    }
    puts $fh "\}"
  } else {
    if { {} == $rt } {
      # no runtime specified
      puts $fh "\nrun"
    } else {
      set rt_value [string tolower $rt]
      if { ({all} == $rt_value) || (![regexp {^[0-9]} $rt_value]) } {
        puts $fh "\nrun -all"
      } else {
        puts $fh "\nrun $rt"
      }
    }
  }

  if { {} != $saif } {
    set extn [string tolower [file extension $saif]]
    if { {.saif} != $extn } {
      append saif ".saif"
    }
    puts $fh "\npower report -all -bsaif $saif"
  }

  # add TCL sources
  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\" && IS_USER_DISABLED == 0"
  set sim_obj $a_sim_vars(s_simset)
  xcs_find_files tcl_src_files $a_sim_vars(sp_tcl_obj) $filter $a_sim_vars(s_launch_dir) $a_sim_vars(b_absolute_path) $sim_obj
  if {[llength $tcl_src_files] > 0} {
    puts $fh ""
    foreach file $tcl_src_files {
      puts $fh "source \{$file\}"
    }
    puts $fh ""
  }

  if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
    puts $fh "\nif \{ \[info exists ::env(VITIS_LAUNCH_WAVEFORM_BATCH) \] \} \{"
    puts $fh "  if \{ \[info exists ::env(USER_POST_SIM_SCRIPT) \] \} \{"
    puts $fh "    if \{ \[catch \{source \$::env(USER_POST_SIM_SCRIPT)\} msg\] \} \{"
    puts $fh "      puts \$msg"
    puts $fh "    \}"
    puts $fh "  \}"
    puts $fh "  quit -force"
    puts $fh "\}"
  } else {
    if { $a_sim_vars(b_batch) } {
      puts $fh "\nquit -force"
    } elseif { $a_sim_vars(b_scripts_only) } {
      # for scripts_only mode, set script for simulator gui mode (do not quit)
      if { $a_sim_vars(b_gui) } {
        # run simulation
      } else {
        if { [get_param "simulator.quitOnSimulationComplete"] } {
          puts $fh "\nquit -force"
        }
      }
    } else {
      # launch_simulation - if called from vivado in batch or Tcl mode, quit
      if { !$a_sim_vars(b_int_is_gui_mode) } {
        puts $fh "\nquit -force"
      }
    }
  }
  close $fh
}

proc usf_questa_write_header { fh filename } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars

  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 4]
  set copyright_1 [lindex $version_txt 5]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  set timestamp   [clock format [clock seconds]]
  set mode_type   $a_sim_vars(s_mode)
  set name        [file tail $filename]

  puts $fh "######################################################################"
  puts $fh "#"
  puts $fh "# File name : $name"
  puts $fh "# Created on: $timestamp"
  puts $fh "#"
  puts $fh "# Auto generated by $product for '$mode_type' simulation"
  puts $fh "#"
  puts $fh "######################################################################"
}

proc usf_questa_write_driver_shell_script { do_filename step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set scr_filename $step;append scr_filename [xcs_get_script_extn "questa"]
  set scr_file [file normalize [file join $a_sim_vars(s_launch_dir) $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-Questa-022 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  set batch_sw {-c}
  if { ({simulate} == $step) } {
    # launch_simulation
    if { (!$a_sim_vars(b_batch)) && (!$a_sim_vars(b_scripts_only)) } {
      # launch_simulation - if called from vivado in batch or Tcl mode, run in command mode
      if { !$a_sim_vars(b_int_is_gui_mode) } {
        set batch_sw {-c}
      } else {
        set batch_sw {}
      }
    }

    # for scripts_only mode, set script for simulator gui mode (don't pass -c)
    if { {} != $batch_sw } {
      if { $a_sim_vars(b_gui) } {
        set batch_sw {}
      }
    }
  }

  set s_64bit {}
  if {$::tcl_platform(platform) == "unix"} {
    if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
      # donot pass os type
    } else {
      set s_64bit {-64}
      if {$::tcl_platform(platform) == "windows"} {
        # -64 not supported
        set s_64bit {}
      }
    }
  }

  # write tcl pre hook
  set tcl_pre_hook [get_property "questa.compile.tcl.pre" $a_sim_vars(fs_obj)]

  set log_filename "${step}.log"
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "[xcs_get_shell_env]"
    xcs_write_script_header $fh_scr $step "questa"
    xcs_write_version_id $fh_scr "questa"
    puts $fh_scr "\n# catch pipeline exit status"
    xcs_write_pipe_exit $fh_scr
    if { {} != $a_sim_vars(s_tool_bin_path) } {
      puts $fh_scr "\n# set simulator install path"
      puts $fh_scr "bin_path=\"[xcs_replace_with_var $a_sim_vars(s_tool_bin_path) "SIM_VER" "questa"]\""
    }

    set aie_ip_obj {}
    set ld_path_str {}
    if { $a_sim_vars(b_int_systemc_mode) } {
      if { $a_sim_vars(b_contain_systemc_sources) } {
        if { {simulate} == $step } {
          if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
            xcs_write_launch_mode_for_vitis $fh_scr "questa"
          }
        }
        if { ({elaborate} == $step) || ({simulate} == $step) } {
          set shared_ip_libs [list]

          # get data dir from $XILINX_VIVADO/data/simmodels/questa (will return $XILINX_VIVADO/data)
          set data_dir [rdi::get_data_dir -quiet -datafile "simmodels/questa"]

          set aie_ip_obj [xcs_find_ip "ai_engine"]
          if { {} != $aie_ip_obj } {
            # get protected sub-dir (simmodels/questa/2019.4/lnx64/5.3.0/systemc/protected)
            set cpt_dir [xcs_get_simmodel_dir "questa" $a_sim_vars(s_gcc_version) "cpt"]
            set model_ver [rdi::get_aie_config_type]
            set lib_dir $model_ver
            if { {aie} == $model_ver } {
              set lib_dir "${model_ver}_cluster_v1_0_0"
            }
            # disable AIE binding
            #lappend shared_ip_libs "$data_dir/$cpt_dir/$lib_dir"
          }

          variable a_shared_library_path_coln
          foreach {key value} [array get a_shared_library_path_coln] {
            set sc_lib   $key
            set lib_path $value
            set resolved_path [xcs_resolve_sim_model_dir "questa" $value $a_sim_vars(s_clibs_dir) $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved $a_sim_vars(b_compile_simmodels) "obj"]
            set lib_dir "$resolved_path"
            if { $a_sim_vars(b_compile_simmodels) } {
              set lib_name [file tail $lib_path]
              set lib_type [file tail [file dirname $lib_path]]
              if { ("protobuf" == $lib_name) || ("protected" == $lib_type) } {
                # skip
              } else {
                set lib_dir "questa_lib/$lib_name"
              }
            }
            lappend shared_ip_libs $lib_dir
          }

          # bind IP static librarries
          set sh_ip_libs [xcs_get_shared_ip_libraries $a_sim_vars(s_clibs_dir)]
          set uniq_shared_libs    [list]
          set shared_libs_to_link [list]
          foreach ip_obj [get_ips -all -quiet] {
            set ipdef [get_property -quiet "ipdef" $ip_obj]
            set vlnv_name [xcs_get_library_vlnv_name $ip_obj $ipdef]
            set ssm_type [get_property -quiet "selected_sim_model" $ip_obj]
            if { [lsearch $sh_ip_libs $vlnv_name] != -1 } {
              if { [lsearch -exact $uniq_shared_libs $vlnv_name] == -1 } {
                if { ("tlm" == $ssm_type) } {
                  # bind systemC library
                  lappend shared_libs_to_link $vlnv_name
                  lappend uniq_shared_libs $vlnv_name
                } else {
                  # rtl, tlm_dpi (no binding)
                }
              }
            }
          }
          foreach vlnv_name $shared_libs_to_link {
            set lib_dir "$a_sim_vars(s_clibs_dir)/$vlnv_name"
            lappend shared_ip_libs $lib_dir 
          }

          # bind user specified systemC/C/C++ libraries
          set l_link_sysc_libs [get_property "questa.elaborate.link.sysc" $a_sim_vars(fs_obj)]
          set l_link_c_libs    [get_property "questa.elaborate.link.c"    $a_sim_vars(fs_obj)]
          if { ([llength $l_link_sysc_libs] > 0) || ([llength $l_link_c_libs] > 0) } {
            variable a_link_libs
            array unset a_link_libs
            foreach lib $l_link_sysc_libs {
              set lib_dir [file dirname $lib]
              if { ![info exists a_link_libs($lib_dir)] } {
                set a_link_libs($lib_dir) ""
                lappend shared_ip_libs "$lib_dir"
              }
            }
            foreach lib $l_link_c_libs {
              set lib_dir [file dirname $lib]
              if { ![info exists a_link_libs($lib_dir)] } {
                set a_link_libs($lib_dir) ""
                lappend shared_ip_libs "$lib_dir"
              }
            }
          }
 
          if { [llength $shared_ip_libs] > 0 } {
            set shared_ip_libs_env_path [join $shared_ip_libs ":"]
            set ld_path_str "export LD_LIBRARY_PATH=$shared_ip_libs_env_path"
            if { {} != $aie_ip_obj } {
              append ld_path_str ":\$XILINX_VITIS/aietools/lib/lnx64.o"
            }
          }
        }
      }
    }

    # TODO: once vsim picks the "so"s path at runtime , we can remove the following code
    if { {simulate} == $step } {
      if { [get_param "project.allowSharedLibraryType"] } {
        puts $fh_scr "xv_path=\"$::env(XILINX_VIVADO)\""
        puts $fh_scr "xv_lib_path=\"$::env(RDI_LIBDIR)\""

        set args_list [list]
        foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_filesets $a_sim_vars(fs_obj)]] {
          set file_type [get_property "file_type" $file]
          set file_dir [file dirname $file] 
          set file_name [file tail $file] 

          if { {Shared Library} == $file_type } {
            set file_dir "[xcs_get_relative_file_path $file_dir $a_sim_vars(s_launch_dir)]"
            if { ![info exists a_shared_lib_dirs($file_dir)] } {
              set a_shared_lib_dirs($file_dir) $file_dir
              lappend args_list "$file_dir"
            }
          }
        }

        if { [llength $args_list] != 0 } {
          set cmd_args [join $args_list ":"]
          if { [get_param "project.copyShLibsToCurrRunDir"] } {
            puts $fh_scr "\nexport LD_LIBRARY_PATH=\$PWD:\$xv_lib_path:\$LD_LIBRARY_PATH\n"
          } else {
            puts $fh_scr "\nexport LD_LIBRARY_PATH=$cmd_args:\$xv_lib_path:\$LD_LIBRARY_PATH\n"
          }
        }
      }
    }

    if { {} != $tcl_pre_hook } {
      puts $fh_scr "xv_path=\"$::env(XILINX_VIVADO)\""
    }


    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      puts $fh_scr "\n# set simulation library paths"
      if { ("elaborate" == $step) || ("simulate" == $step) } {
        puts $fh_scr "export xv_cxl_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_clibs_dir) "SIM_VER" "questa"] "GCC_VER" "questa"]\""
        puts $fh_scr "export xv_cxl_ip_path=\"\$xv_cxl_lib_path\""
      }
      puts $fh_scr "export xv_cpt_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_cpt_dir) "SIM_VER" "questa"] "GCC_VER" "questa"]\""
      puts $fh_scr "export xv_ext_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_ext_dir) "SIM_VER" "questa"] "GCC_VER" "questa"]\""
      # for aie
      if { {} != $aie_ip_obj } {
        puts $fh_scr "\n# set header/runtime library path for AIE compiler"
        puts $fh_scr "export CHESSDIR=\"\$XILINX_VITIS/aietools/tps/lnx64/target/chessdir\""
        set aie_work_dir $a_sim_vars(s_aie_work_dir)
        if { {} != $aie_work_dir } {
          puts $fh_scr "export AIE_WORK_DIR=\"$aie_work_dir\""
        }
      }
      if { ("elaborate" == $step) || ("simulate" == $step) } {
        puts $fh_scr "\n# set shared library paths"
        puts $fh_scr "$ld_path_str:\$LD_LIBRARY_PATH\n"
      }
    }

    # add tcl pre hook
    if { ({compile} == $step) && ({} != $tcl_pre_hook) } {
      if { ![file exists $tcl_pre_hook] } {
        [catch {send_msg_id USF-Questa-103 ERROR "File does not exist:'$tcl_pre_hook'\n"} err]
      }
      set tcl_wrapper_file $a_sim_vars(s_compile_pre_tcl_wrapper)
      xcs_delete_backup_log $tcl_wrapper_file $a_sim_vars(s_launch_dir)
      xcs_write_tcl_wrapper $tcl_pre_hook ${tcl_wrapper_file}.tcl $a_sim_vars(s_launch_dir)
      set vivado_cmd_str "-mode batch -notrace -nojournal -log ${tcl_wrapper_file}.log -source ${tcl_wrapper_file}.tcl"
      set cmd "vivado $vivado_cmd_str"
      puts $fh_scr "echo \"$cmd\""
      set full_cmd "\$xv_path/bin/vivado $vivado_cmd_str"
      puts $fh_scr "$full_cmd"
      xcs_write_exit_code $fh_scr
    }

    set b_append_log false
    if { ({elaborate} == $step) && [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
      # write sccom cmd line
      set args [usf_questa_get_sccom_cmd_args]
      if { [llength $args] > 0 } {
        set sccom_cmd_str [join $args " "]
        puts $fh_scr "\$bin_path/sccom $sccom_cmd_str 2>&1 | tee $log_filename"
        set b_append_log true
        xcs_write_exit_code $fh_scr
      }
    }
 
    if { ({compile} == $step) && [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
      puts $fh_scr "\nsource $do_filename 2>&1 | tee $log_filename"
      xcs_write_exit_code $fh_scr
    } elseif { ({elaborate} == $step) && [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
      set append_sw " "
      if { $b_append_log } { set append_sw " -a " }
      puts $fh_scr "source $do_filename 2>&1 | tee${append_sw}${log_filename}"
      xcs_write_exit_code $fh_scr
    } else {
      # simulate step
      set gcc_cmd {}
      if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
        set gcc_path "[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_gcc_bin_path) "SIM_VER" "questa"] "GCC_VER" "questa"]/g++"
        set gcc_cmd "-cpppath $gcc_path"
      }
      if { {} != $a_sim_vars(s_tool_bin_path) } {
        set s_cmd "\$bin_path/vsim $s_64bit"
        if { {} != $gcc_cmd } {
          append s_cmd " $gcc_cmd "
        }
        if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
          append s_cmd " \$mode -do \"do \{$do_filename\}\" -l $log_filename"
        } else {
          append s_cmd " $batch_sw -do \"do \{$do_filename\}\" -l $log_filename"
        }
        puts $fh_scr $s_cmd
        xcs_write_exit_code $fh_scr
      } else {
        set s_cmd "vsim $s_64bit"
        if { {} != $gcc_cmd } {
          append s_cmd " $gcc_cmd "
        }
        if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
          append s_cmd " \$mode -do \"do \{$do_filename\}\" -l $log_filename"
        } else {
          append s_cmd " $batch_sw -do \"do \{$do_filename\}\" -l $log_filename"
        }
        puts $fh_scr $s_cmd
        xcs_write_exit_code $fh_scr
      }
    }
  } else {
    # windows
    puts $fh_scr "@echo off"
    xcs_write_script_header $fh_scr $step "questa"
    if { {} != $a_sim_vars(s_tool_bin_path) } {
      puts $fh_scr "set bin_path=$a_sim_vars(s_tool_bin_path)"
      if { ({compile} == $step) && ({} != $tcl_pre_hook) } {
        set xv $::env(XILINX_VIVADO)
        set xv [string map {\\\\ /} $xv]
        set xv_path $xv
 
        # check if its a cygwin drive mapping (/cygdrive/c/<path>), if yes, then replace with (c:/<path>)
        set xv_comps [split $xv "/"]
        if { "cygdrive" == [lindex $xv_comps 1] } {
          set drive [lindex $xv_comps 2]
          append drive ":/"
          set xv_path [join [lrange $xv_comps 3 end] "/"]
          set xv_path [file join $drive $xv_path]
        }

        # fix slashes
        set xv_path [string map {/ \\} $xv_path]
        puts $fh_scr "set xv_path=$xv_path"

        if { ![file exists $tcl_pre_hook] } {
          [catch {send_msg_id USF-ModelSim-103 ERROR "File does not exist:'$tcl_pre_hook'\n"} err]
        }
        set tcl_wrapper_file $a_sim_vars(s_compile_pre_tcl_wrapper)
        xcs_delete_backup_log $tcl_wrapper_file $a_sim_vars(s_launch_dir)
        xcs_write_tcl_wrapper $tcl_pre_hook ${tcl_wrapper_file}.tcl $a_sim_vars(s_launch_dir)
        set vivado_cmd_str "-mode batch -notrace -nojournal -log ${tcl_wrapper_file}.log -source ${tcl_wrapper_file}.tcl"
        set cmd "vivado $vivado_cmd_str"
        puts $fh_scr "echo \"$cmd\""
        set full_cmd "%xv_path%/bin/vivado $vivado_cmd_str"
        puts $fh_scr "call $full_cmd"
      }
      if { ({elaborate} == $step) && [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
        # write sccom cmd line
        set args [usf_questa_get_sccom_cmd_args]
        if { [llength $args] > 0 } {
          set sccom_cmd_str [join $args " "]
          puts $fh_scr "call %bin_path%/sccom $sccom_cmd_str"
          puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
          puts $fh_scr "if \"%errorlevel%\"==\"0\" goto SUCCESS"
        }
      }
      puts $fh_scr "call %bin_path%/vsim $s_64bit $batch_sw -do \"do \{$do_filename\}\" -l $log_filename"
    } else {
      if { ({elaborate} == $step) && [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
        # write sccom cmd line
        set args [usf_questa_get_sccom_cmd_args]
        if { [llength $args] > 0 } {
          set sccom_cmd_str [join $args " "]
          puts $fh_scr "call sccom $sccom_cmd_str"
          puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
          puts $fh_scr "if \"%errorlevel%\"==\"0\" goto SUCCESS"
        }
      }
      puts $fh_scr "call vsim $s_64bit $batch_sw -do \"do \{$do_filename\}\" -l $log_filename"
    }
    puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
    puts $fh_scr "if \"%errorlevel%\"==\"0\" goto SUCCESS"
    puts $fh_scr ":END"
    puts $fh_scr "exit 1"
    puts $fh_scr ":SUCCESS"
    puts $fh_scr "exit 0"
  }

  close $fh_scr
}

proc usf_questa_get_sccom_cmd_args {} {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  variable a_sim_cache_all_ip_obj

  set args [list]
  
  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_contain_systemc_sources) } {
    # systemc
    if {$::tcl_platform(platform) == "unix"} {
      if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
        lappend args {-32}
      } else {
        if {$::tcl_platform(platform) == "windows"} {
          # -64 not supported
        } else {
          lappend args {-64}
        }
      }
    }
    set gcc_path "$a_sim_vars(s_gcc_bin_path)/g++"
    if {$::tcl_platform(platform) == "unix"} {
      set gcc_path "[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_gcc_bin_path) "SIM_VER" "questa"] "GCC_VER" "questa"]/g++"
    }
    lappend args "-cpppath $gcc_path"
    lappend args "-link"

    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      set ip_obj [xcs_find_ip "ai_engine"]
      if { {} != $ip_obj } {
        lappend args "-Wl,-u -Wl,_ZN5sc_dt12sc_concatref6m_poolE"
        lappend args "-Wl,-whole-archive -lsystemc_gcc74 -Wl,-no-whole-archive"
      }
    }

    set more_opts [get_property "questa.elaborate.sccom.more_options" $a_sim_vars(fs_obj)]
    if { {} != $more_opts } {
      lappend args "$more_opts"
    }

    variable a_shared_library_path_coln
    foreach {key value} [array get a_shared_library_path_coln] {
      set sc_lib   $key
      set lib_path $value
      set lib_name [file root $sc_lib]
      set lib_name [string trimleft $lib_name {lib}]
      set lib_dir "$lib_path"
      # is C/CPP library?
      if { ([xcs_is_c_library $lib_name]) || ([xcs_is_cpp_library $lib_name]) } {
        lappend args "-L$lib_dir"
        lappend args "-l$lib_name"
      } else {
        lappend args "-lib $lib_name"
      }
    }

    # bind user specified systemC/C/C++ libraries
    set l_link_sysc_libs [get_property "questa.elaborate.link.sysc" $a_sim_vars(fs_obj)]
    foreach lib $l_link_sysc_libs {
      set lib_name [file root [file tail $lib]]
      set lib_name [string trimleft $lib_name {lib}]
      lappend args "-lib $lib_name"
    }
    set l_link_c_libs    [get_property "questa.elaborate.link.c"    $a_sim_vars(fs_obj)]
    foreach lib $l_link_c_libs {
      set lib_dir  [file dirname $lib]
      set lib_name [file root [file tail $lib]]
      set lib_name [string trimleft $lib_name {lib}]
      lappend args "-L$lib_dir"
      lappend args "-l$lib_name"
    }

    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      set ip_obj [xcs_find_ip "ai_engine"]
      if { {} != $ip_obj } {
        set cpt_dir  [xcs_get_simmodel_dir "questa" $a_sim_vars(s_gcc_version) "cpt"]
        set data_dir [rdi::get_data_dir -quiet -datafile "simmodels/questa"]
        set model_ver [rdi::get_aie_config_type]
        set lib_name "${model_ver}_cluster_v1_0_0"
        # disable AIE binding
        if { {aie} == $model_ver } {
          # lappend args "-L$data_dir/$cpt_dir/$lib_name"
        } else {
          # lappend args "-L$data_dir/$cpt_dir/$model_ver"
        }
        # lappend args "-l$lib_name"
      }
    }

    lappend args "-lib $a_sim_vars(default_top_library)"

    # bind IP static librarries
    set shared_ip_libs [xcs_get_shared_ip_libraries $a_sim_vars(s_clibs_dir)]
    if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
      puts "------------------------------------------------------------------------------------------------------------------------------------"
      puts "Referenced pre-compiled shared libraries"
      puts "------------------------------------------------------------------------------------------------------------------------------------"
    }
    set uniq_shared_libs    [list]
    set shared_libs_to_link [list]
    xcs_cache_ip_objs
    foreach ip [array names a_sim_cache_all_ip_obj] {
      set ip_obj $a_sim_cache_all_ip_obj($ip)
      set ipdef [get_property -quiet "ipdef" $ip_obj]
      set vlnv_name [xcs_get_library_vlnv_name $ip_obj $ipdef]
      set ssm_type [get_property -quiet "selected_sim_model" $ip_obj]
      if { [lsearch $shared_ip_libs $vlnv_name] != -1 } {
        if { [lsearch -exact $uniq_shared_libs $vlnv_name] == -1 } {
          if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
            puts " IP - $ip_obj ($vlnv_name) - SELECTED_SIM_MODEL=$ssm_type"
          }
          if { ("tlm" == $ssm_type) } {
            # bind systemC library
            lappend shared_libs_to_link $vlnv_name
            lappend uniq_shared_libs $vlnv_name
            if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
              puts "      (BIND)-> $a_sim_vars(s_clibs_dir)/$vlnv_name"
            }
          } else {
            # rtl, tlm_dpi (no binding)
            if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
              puts "      (SKIP)-> $a_sim_vars(s_clibs_dir)/$vlnv_name"
            }
          }
        }
      } else {
        # check if incompatible version found from compiled area
        if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
          set ip_name [get_property -quiet "name" $ip_obj]
          # ipdef -> xilinx.com:ip:versal_cips:3.0 -> versal_cips_v
          set ip_prefix [lindex [split $ipdef {:}] 2]
          set ip_prefix "${ip_prefix}_v"

          # match first part from clibs area to see if it matches
          set matches [lsearch -regexp -all $shared_ip_libs $ip_prefix]
          if { [llength $matches] > 0 } {
            puts " WARNING: Expected pre-compiled shared library for '$vlnv_name' referenced in IP '$ip_name' not found!"
            puts "          (Library '$vlnv_name' will not be linked during elaboration)"
            puts "          Available version(s) present in CLIBS '$a_sim_vars(s_clibs_dir)':"
            foreach index $matches {
              puts "           + [lindex $shared_ip_libs $index]"
            }
          }
        }
      }
    }
    foreach vlnv_name $shared_libs_to_link {
      lappend args "-lib $vlnv_name"
    }
    if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
      puts "------------------------------------------------------------------------------------------------------------------------------------"
    }

    lappend args "-work $a_sim_vars(default_top_library)"
  }
  return $args
}

proc usf_questa_map_pre_compiled_libs { fh cmd } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { !$a_sim_vars(b_use_static_lib) } {
    return
  }

  set lib_path [get_property "sim.ipstatic.compiled_library_dir" [current_project]]
  set ini_file [file join $lib_path "modelsim.ini"]
  if { ![file exists $ini_file] } {
    return
  }

  set fh_ini 0
  if { [catch {open $ini_file r} fh_ini] } {
    send_msg_id USF-Questa-099 WARNING "Failed to open file for read ($ini_file)\n"
    return
  }
  set ini_data [read $fh_ini]
  close $fh_ini

  set ini_data [split $ini_data "\n"]
  set b_lib_start false
  foreach line $ini_data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    if { [regexp "^secureip" $line] } {
      set b_lib_start true
    }
    if { $b_lib_start } {
      if { [regexp "^secureip" $line] ||
           [regexp "^unisim" $line] ||
           [regexp "^simprim" $line] ||
           [regexp "^unifast" $line] ||
           [regexp "^unimacro" $line] } {
        continue
      }
      if { ([regexp {^;} $line]) || ([regexp {^\[} $line]) } {
        set b_lib_start false
        continue
      }
      if { [regexp "=" $line] } {
        set tokens [split $line "="]
        set name [string trim [lindex $tokens 0]]
        set dir  [string trim [lindex $tokens 1]]
        if { {} == $dir } { continue }
        puts $fh "$cmd $name $dir"
      }
    }
  }
}

proc usf_questa_set_initial_cmd { fh_scr cmd_str src_file file_type lib prev_file_type_arg prev_lib_arg } {
  # Summary: Print compiler command line and store previous file type and library information
  # Argument Usage:
  # Return Value:
  # None

  upvar $prev_file_type_arg prev_file_type
  upvar $prev_lib_arg  prev_lib

  variable a_sim_vars

  set DS "\\\\"
  if {$::tcl_platform(platform) == "unix"} {
    set DS "/"
  }
  set tool_path_str ""
  if { {} != $a_sim_vars(s_install_path) } {
    set tool_path_str "$a_sim_vars(s_tool_bin_path)${DS}"
    if {$::tcl_platform(platform) == "unix"} {
      set tool_path_str "[xcs_replace_with_var $a_sim_vars(s_tool_bin_path) "SIM_VER" "questa"]${DS}"
    }
  }

  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    puts $fh_scr "${tool_path_str}$cmd_str \\"
  } else {
    puts $fh_scr "eval $cmd_str \\"
  }
  puts $fh_scr "$src_file \\"

  set prev_file_type $file_type
  set prev_lib  $lib
}

proc usf_add_quit_on_error { fh step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { $a_sim_vars(b_scripts_only) } {
    # for both native and classic modes
    if { {simulate} == $step } {
      if { [get_param "simulator.modelsimNoQuitOnError"] } {
        # no op
      } else {
        puts $fh "onbreak {quit -f}"
        puts $fh "onerror {quit -f}\n"
      }
    }
  } else {
    # GUI and batch
    # native mode (default)
    if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
      if { {simulate} == $step } {
        if { [get_param "simulator.modelsimNoQuitOnError"] } {
          # no op
        } else {
          puts $fh "onbreak {quit -f}"
          puts $fh "onerror {quit -f}\n"
        }
      }
    # classic mode
    } else {
      if { ({compile} == $step) || ({elaborate} == $step) || ({simulate} == $step) } {
        if { [get_param "simulator.modelsimNoQuitOnError"] } {
          # no op
        } else {
          puts $fh "onbreak {quit -f}"
          puts $fh "onerror {quit -f}\n"
        }
      }
    }
  }
}
}
