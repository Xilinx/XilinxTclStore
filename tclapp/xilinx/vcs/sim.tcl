######################################################################
#
# sim.tcl (simulation script for the 'Synopsys VCS Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
######################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::vcs {
  namespace export setup
}

namespace eval ::tclapp::xilinx::vcs {
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
  usf_vcs_setup_args $args

  # set NoC binding type
  if { $a_sim_vars(b_int_system_design) } {
    xcs_bind_legacy_noc
  }

  # perform initial simulation tasks
  if { [usf_vcs_setup_simulation] } {
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

  send_msg_id USF-VCS-002 INFO "VCS::Compile design"
  usf_vcs_write_compile_script
  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  usf_launch_script "vcs" $step
}

proc elaborate { args } {
  # Summary: run the elaboration step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  send_msg_id USF-VCS-003 INFO "VCS::Elaborate design"
  usf_vcs_write_elaborate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  usf_launch_script "vcs" $step
}

proc simulate { args } {
  # Summary: run the simulation step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  variable a_sim_vars

  send_msg_id USF-VCS-004 INFO "VCS::Simulate design"
  usf_vcs_write_simulate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  usf_launch_script "vcs" $step

  if { $a_sim_vars(b_scripts_only) } {
    set fh 0
    set file [file normalize [file join $a_sim_vars(s_launch_dir) "simulate.log"]]
    if {[catch {open $file w} fh]} {
      send_msg_id USF-VCS-016 ERROR "Failed to open file to write ($file)\n"
    } else {
      puts $fh "INFO: Scripts generated successfully. Please see the 'Tcl Console' window for details."
      close $fh
    }
  }
}
}

#
# VCS simulation flow
#
namespace eval ::tclapp::xilinx::vcs {
proc usf_vcs_setup_simulation { args } {
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

  # uvm
  [catch {set a_sim_vars(b_uvm) [get_param simulator.enableUVMSimulation]} err]

  # nopc - enable systemC non-precompile flow if global pre-compiled static IP flow is disabled
  if { !$a_sim_vars(b_use_static_lib) } {
    set a_sim_vars(b_compile_simmodels) 1
  }

  if { $a_sim_vars(b_compile_simmodels) } {
    set a_sim_vars(s_simlib_dir) "$a_sim_vars(s_launch_dir)/simlibs"
    if { ![file exists $a_sim_vars(s_simlib_dir)] } {
      if { [catch {file mkdir $a_sim_vars(s_simlib_dir)} error_msg] } {
        send_msg_id USF-VCS-013 ERROR "Failed to create the directory ($a_sim_vars(s_simlib_dir)): $error_msg\n"
        return 1
      }
    }
  }

  usf_set_simulator_path "vcs"

  if { $a_sim_vars(b_int_system_design) } {
    usf_set_systemc_library_path "vcs"
  }

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

  # find/copy synopsys_sim.setup file into run dir
  set a_sim_vars(s_clibs_dir) [usf_vcs_verify_compiled_lib]

  # verify GCC version from CLIBs (make sure it matches, else throw critical warning)
  xcs_verify_clibs_gcc_version $a_sim_vars(s_clibs_dir) $a_sim_vars(s_gcc_version) "vcs"

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

  if { $a_sim_vars(b_int_systemc_mode) } {
    # extract simulation model library info
    xcs_fetch_lib_info "vcs" $a_sim_vars(s_clibs_dir) $a_sim_vars(b_int_sm_lib_ref_debug)
  }

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

  # find hbm IP, if any for netlist functional simulation
  if { $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) } {
    set a_sim_vars(sp_hbm_ip_obj) [xcs_find_ip "hbm"]
  }

  # fetch design files
  variable l_local_design_libraries
  set global_files_str {}
  set a_sim_vars(l_design_files) [xcs_uniquify_cmd_str [usf_get_files_for_compilation global_files_str]]

  # print IPs that were not found from clibs
  xcs_print_local_IP_compilation_msg $a_sim_vars(b_int_sm_lib_ref_debug) $l_local_design_libraries $a_sim_vars(compiled_library_dir)

  # is system design?
  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_contain_systemc_sources) || $a_sim_vars(b_contain_cpp_sources) || $a_sim_vars(b_contain_c_sources) } {
      set a_sim_vars(b_system_sim_design) 1
    }
  }
  
  if { $a_sim_vars(b_int_systemc_mode) } {
    # systemC headers
    set a_sim_vars(b_contain_systemc_headers) [xcs_contains_systemc_headers]

    # find shared library paths from all IPs
    if { $a_sim_vars(b_system_sim_design) } {
      if { [xcs_contains_C_files] } {
        xcs_find_shared_lib_paths "vcs" $a_sim_vars(s_gcc_version) $a_sim_vars(s_clibs_dir) $a_sim_vars(custom_sm_lib_dir) $a_sim_vars(b_int_sm_lib_ref_debug) a_sim_vars(sp_cpt_dir) a_sim_vars(sp_ext_dir)
      }

      # cache all systemC stub files
      variable a_sim_cache_sysc_stub_files
      foreach file_obj [get_files -quiet -all "*_stub.sv"] {
        set name [get_property -quiet "name" $file_obj]
        set file_name [file root [file tail $name]]
        set module_name [string trimright $file_name "_stub"]
        set a_sim_cache_sysc_stub_files($module_name) $file_obj
      }
    }
  }

  # nopc
  if { $a_sim_vars(b_compile_simmodels) } {
    # get the design simmodel compile order
    set a_sim_vars(l_simmodel_compile_order) [xcs_get_simmodel_compile_order]
  }

  # create setup file
  usf_vcs_write_setup_files

  return 0
}

proc usf_vcs_setup_args { args } {
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
  # [-install_path <arg>]: Custom VCS installation directory path
  # [-batch]: Execute batch flow simulation run (non-gui)
  # [-run_dir <arg>]: Simulation run directory
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
  # [-int_enable_dmv_sim]: Enable DMV unisim simulation (internal use)

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: xilinxtclstore, vcs

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
      "-int_enable_dmv_sim"       { set a_sim_vars(b_int_enable_dmv_sim)       1                 }
      "-int_setup_sim_vars"       { set a_sim_vars(b_int_setup_sim_vars)       1                 }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id USF-VCS-005 WARNING "Unknown option '$option' specified (ignored)\n"
        }
      }
    }
  }
}

proc usf_vcs_verify_compiled_lib {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set syn_filename "synopsys_sim.setup"
  set compiled_lib_dir {}
  send_msg_id USF-VCS-006 INFO "Finding pre-compiled libraries...\n"
  # check property value
  set dir [get_property "compxlib.vcs_compiled_library_dir" [current_project]]
  set syn_file [file normalize [file join $dir $syn_filename]]
  if { [file exists $syn_file] } {
    set compiled_lib_dir $dir
  }
  # 1. check -lib_map_path
  # is -lib_map_path specified and point to valid location?
  if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
    set a_sim_vars(s_lib_map_path) [file normalize $a_sim_vars(s_lib_map_path)]
    if { [file exists $a_sim_vars(s_lib_map_path)] } {
      set compiled_lib_dir $a_sim_vars(s_lib_map_path)
    } else {
      send_msg_id USF-VCS-010 WARNING "The path specified with the -lib_map_path does not exist:'$a_sim_vars(s_lib_map_path)'\n"
    }
  }
  # 1a. find setup file from current working directory
  if { {} == $compiled_lib_dir } {
    set dir [file normalize [pwd]]
    set syn_file [file normalize [file join $dir $syn_filename]]
    if { [file exists $syn_file] } {
      set compiled_lib_dir $dir
    }
  }
  # return if found, else warning
  if { {} != $compiled_lib_dir } {
   send_msg_id USF-VCS-007 INFO "Using synopsys_sim.setup from '$compiled_lib_dir/synopsys_sim.setup'\n"
   set a_sim_vars(compiled_library_dir) $compiled_lib_dir
   return $compiled_lib_dir
  }
  if { $a_sim_vars(b_scripts_only) } {
    send_msg_id USF-VCS-018 WARNING "The pre-compiled simulation library could not be located. Please make sure to reference this library before executing the scripts.\n"
  } else {
    send_msg_id USF-VCS-008 "CRITICAL WARNING" "Failed to find the pre-compiled simulation library!\n"
  }
  send_msg_id USF-VCS-009 INFO \
     "Please set the 'COMPXLIB.VCS_COMPILED_LIBRARY_DIR' project property to the directory where Xilinx simulation libraries are compiled for VCS.\n"

  return $compiled_lib_dir
}

proc usf_vcs_write_setup_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  variable l_ip_static_libs
  variable l_local_design_libraries

  set filename "synopsys_sim.setup"
  set file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id USF-VCS-010 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  set lib_map_path $a_sim_vars(compiled_library_dir)
  if { {} == $lib_map_path } {
    set lib_map_path "?"
  }
  set libs [list]

  set b_search_ref_lib_mod false
  [catch {set b_search_ref_lib_mod [get_param "simulator.searchMatchingModuleFromSetupFile"]} err]
  if { $b_search_ref_lib_mod } {
    puts $fh "LIBRARY_SCAN=TRUE"
  }

  # unifast
  set b_compile_unifast 0
  set simulator_language [string tolower [get_property "simulator_language" [current_project]]]
  if { ([get_param "simulation.addUnifastLibraryForVhdl"]) && ({vhdl} == $simulator_language) } {
    set b_compile_unifast [get_property "unifast" $a_sim_vars(fs_obj)]
  }

  if { ([xcs_contains_vhdl $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $a_sim_vars(s_simulation_flow)) } {
    if { $b_compile_unifast } {
      puts $fh "unifast : $lib_map_path/unifast"
    }
  }

  set b_compile_unifast [get_property "unifast" $a_sim_vars(fs_obj)]
  if { ([xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $a_sim_vars(s_simulation_flow)) } {
    if { $b_compile_unifast } {
      puts $fh "unifast_ver : $lib_map_path/unifast_ver"
    }
  }

  set design_libs [xcs_get_design_libs $a_sim_vars(l_design_files) 0 0 0]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    if { ({work} == $lib) } { continue; }
    lappend libs [string tolower $lib]
  }
  set default_lib [string tolower $a_sim_vars(default_top_library)]
  if { [lsearch -exact $libs $default_lib] == -1 } {
    lappend libs $default_lib
  }

  set dir_name "vcs_lib"
  foreach lib_name $libs {
    if { $a_sim_vars(b_use_static_lib) && ([xcs_is_static_ip_lib $lib_name $l_ip_static_libs]) } {
      # continue if no local library found or continue if precompiled library (not local) and library is not default
      if { $lib_name != $default_lib } {        
        if { ([llength $l_local_design_libraries] == 0) || (![xcs_is_local_ip_lib $lib_name $l_local_design_libraries]) } {
          continue
        }
      }
    }
    set lib_dir [file join $dir_name $lib_name]
    set lib_dir_path [file normalize [string map {\\ /} [file join $a_sim_vars(s_launch_dir) $lib_dir]]]
    if { ! [file exists $lib_dir_path] } {
      if {[catch {file mkdir $lib_dir_path} error_msg] } {
        send_msg_id USF-VCS-011 ERROR "Failed to create the directory ($lib_dir_path): $error_msg\n"
        return 1
      }
    }
    if { $a_sim_vars(b_absolute_path) } {
      set lib_dir $lib_dir_path
    }
    puts $fh "$lib_name : $lib_dir"
  }

  if { $a_sim_vars(b_use_static_lib) } {
    usf_vcs_map_pre_compiled_libs $fh
  }

  if { $a_sim_vars(b_int_enable_dmv_sim) } {
    set design_dmv [get_property -quiet dmv $a_sim_vars(fs_obj)]
    set b_dmv 0
    foreach dmv [rdi::get_unisim_dmvs] {
      # unisims
      set map_dir "vcs_lib/$dmv"
      set fp "$a_sim_vars(s_launch_dir)/$map_dir"
      if { [file exists $fp] } {
        [catch {file delete -force $fp} error_msg]
      }
      # secureip
      set map_dir "vcs_lib/${dmv}_sip"
      set fp "$a_sim_vars(s_launch_dir)/$map_dir"
      if { [file exists $fp] } {
        [catch {file delete -force $fp} error_msg]
      }
    }
    foreach dmv [rdi::get_unisim_dmvs] {
      if { $dmv != $design_dmv } {
        if { !$b_dmv } {
          # unisims_ver
          set map_dir "vcs_lib/unisims_ver"
          set fp "$a_sim_vars(s_launch_dir)/$map_dir"
          puts $fh "unisims_ver : $map_dir"
          if { [file exists $fp] } {
            [catch {file delete -force $fp} error_msg]
          }
          [catch {file mkdir $fp} error_msg]

          #secureip
          set map_dir "vcs_lib/secureip"
          set fp "$a_sim_vars(s_launch_dir)/$map_dir"
          puts $fh "secureip : $map_dir"
          if { [file exists $fp] } {
            [catch {file delete -force $fp} error_msg]
          }
          [catch {file mkdir $fp} error_msg]
          set b_dmv 1
        }
        # unisims
        set map_dir "vcs_lib/$dmv"
        set fp "$a_sim_vars(s_launch_dir)/$map_dir"
        puts $fh "$dmv : $map_dir"
        if { [file exists $fp] } {
          [catch {file delete -force $fp} error_msg]
        }
        [catch {file mkdir $fp} error_msg]
 
        #secureip
        set map_dir "vcs_lib/${dmv}_sip"
        set fp "$a_sim_vars(s_launch_dir)/$map_dir"
        puts $fh "${dmv}_sip : $map_dir"
        if { [file exists $fp] } {
          [catch {file delete -force $fp} error_msg]
        }
        [catch {file mkdir $fp} error_msg]
      }
    }
  }

  puts $fh "OTHERS=$lib_map_path/$filename"
  close $fh

  # create setup file
  usf_vcs_create_setup_script
}

proc usf_vcs_set_initial_cmd { fh_scr cmd_str src_file file_type lib prev_file_type_arg prev_lib_arg log_arg } {
  # Summary: Print compiler command line and store previous file type and library information
  # Argument Usage:
  # Return Value:
  # None

  upvar $prev_file_type_arg prev_file_type
  upvar $prev_lib_arg  prev_lib
  upvar $log_arg log

  variable a_sim_vars

  if { {} != $a_sim_vars(s_tool_bin_path) } {
    if { $a_sim_vars(b_system_sim_design) } {
      if { [regexp -nocase {vhdl} $file_type] } {
        puts $fh_scr "\$bin_path/$cmd_str \\"
      } else {
        puts $fh_scr "\$bin_path/$cmd_str -sysc \\"
      }
    } else {
      puts $fh_scr "\$bin_path/$cmd_str \\"
    }
  } else {
    if { $a_sim_vars(b_system_sim_design) } {
      if { [regexp -nocase {vhdl} $file_type] } {
        puts $fh_scr "$cmd_str \\"
      } else {
        puts $fh_scr "$cmd_str -sysc \\"
      }
    } else {
      puts $fh_scr "$cmd_str \\"
    }
  }
  puts $fh_scr "$src_file \\"

  set prev_file_type $file_type
  set prev_lib  $lib

  if { [regexp -nocase {vhdl} $file_type] } {
    set log "vhdlan.log"
  } elseif { [regexp -nocase {verilog} $file_type] } {
    set log "vlogan.log"
  }
}

proc usf_vcs_write_compile_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars

  # step exec mode?
  if { $a_sim_vars(b_exec_step) } {
    return 0
  }

  set scr_filename "compile";append scr_filename [xcs_get_script_extn "vcs"]
  set scr_file [file normalize [file join $a_sim_vars(s_launch_dir) $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-VCS-012 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }
  puts $fh_scr "[xcs_get_shell_env]"
  xcs_write_script_header $fh_scr "compile" "vcs"
  xcs_write_version_id $fh_scr "vcs"
  if { {} != $a_sim_vars(s_tool_bin_path) } {
    if { $a_sim_vars(b_optimizeForRuntime) } {
      puts $fh_scr ""
      xcs_write_log_file_cleanup $fh_scr $a_sim_vars(run_logs_compile)
    }
    usf_vcs_init_env $fh_scr
    set b_set_shell_var_exit false
    [catch {set b_set_shell_var_exit [get_param "project.setShellVarsForSimulationScriptExit"]} err]
    if { $b_set_shell_var_exit } {
      puts $fh_scr "\n# catch pipeline exit status"
      xcs_write_pipe_exit $fh_scr
    }
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"[xcs_replace_with_var $a_sim_vars(s_tool_bin_path) "SIM_VER" "vcs"]\""

    usf_set_vcs_home $fh_scr

    if { $a_sim_vars(b_int_systemc_mode) } {
      if { $a_sim_vars(b_system_sim_design) } {
        # set gcc path
        puts $fh_scr "gcc_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_gcc_bin_path) "SIM_VER" "vcs"] "GCC_VER" "vcs"]\"\n"
      }
      # set system sim library paths
      if { $a_sim_vars(b_system_sim_design) } {
        puts $fh_scr "# set system shared library paths"
        puts $fh_scr "xv_cxl_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_clibs_dir) "SIM_VER" "vcs"] "GCC_VER" "vcs"]\""
        puts $fh_scr "xv_cpt_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_cpt_dir) "SIM_VER" "vcs"] "GCC_VER" "vcs"]\""
        puts $fh_scr "xv_ext_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_ext_dir) "SIM_VER" "vcs"] "GCC_VER" "vcs"]\""
        puts $fh_scr "xv_boost_lib_path=\"$a_sim_vars(s_boost_dir)\""
      }
    }
  }

  # write tcl pre hook
  set tcl_pre_hook [get_property "vcs.compile.tcl.pre" $a_sim_vars(fs_obj)]
  if { {} != $tcl_pre_hook } {
    puts $fh_scr "xv_path=\"$::env(XILINX_VIVADO)\""
    xcs_write_shell_step_fn $fh_scr
  }
  puts $fh_scr ""

  xcs_set_ref_dir $fh_scr $a_sim_vars(b_absolute_path) $a_sim_vars(s_launch_dir)

  set b_contain_verilog_srcs [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]

  #
  # pure vhdl design? check if glbl.v needs to be compiled for a pure vhdl design
  # if yes, then set the flag and write verilog command line option vars
  #
  if { !$b_contain_verilog_srcs } {
    if { [usf_vcs_check_if_glbl_file_needs_compilation] } {
      set b_contain_verilog_srcs 1
    }
  }

  set b_contain_vhdl_srcs    [xcs_contains_vhdl $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]

  if { $b_contain_vhdl_srcs } {
    usf_vcs_write_vhdl_compile_options $fh_scr
  }

  if { $b_contain_verilog_srcs } {
    usf_vcs_write_verilog_compile_options $fh_scr
  }

  if { $a_sim_vars(b_int_systemc_mode) } {
    # syscan (systemC)
    if { $a_sim_vars(b_contain_systemc_sources) } {
      usf_vcs_write_systemc_compile_options $fh_scr
    }
    # g++ (c++)
    if { $a_sim_vars(b_contain_cpp_sources) } {
      usf_vcs_write_cpp_compile_options $fh_scr
    }
    # gcc (c)
    if { $a_sim_vars(b_contain_c_sources) } {
      usf_vcs_write_c_compile_options $fh_scr
    }
  }

  # add tcl pre hook
  xcs_write_tcl_pre_hook $fh_scr $tcl_pre_hook $a_sim_vars(s_compile_pre_tcl_wrapper) $a_sim_vars(s_launch_dir)

  # write compile order files
  if { $a_sim_vars(b_optimizeForRuntime) } {
    # nopc
    if { $a_sim_vars(b_compile_simmodels) } {
      usf_compile_simmodel_sources $fh_scr
    }
    usf_vcs_write_compile_order_files_opt $fh_scr
    #usf_vcs_write_compile_order_files_msg $fh_scr
  } else {
    usf_vcs_write_compile_order_files $fh_scr
  }
 
  xcs_add_hard_block_wrapper $fh_scr "vcs" "+v2k" $a_sim_vars(s_launch_dir)
 
  # write glbl compile
  usf_vcs_write_glbl_compile $fh_scr

  close $fh_scr

  # directory for obj's
  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      set obj_dir "$a_sim_vars(s_launch_dir)/$a_sim_vars(tmp_obj_dir)"
      if { [file exists $obj_dir] } {
        [catch {file delete -force -- $obj_dir} error_msg]
      }
      [catch {file mkdir $obj_dir} error_msg]
    }
  }
}

proc usf_vcs_check_if_glbl_file_needs_compilation {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  #
  # same logic used in usf_vcs_write_glbl_compile to determine glbl top
  #
  set b_load_glbl [get_property "vcs.compile.load_glbl" [get_filesets $a_sim_vars(s_simset)]]
  if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
    if { [xcs_compile_glbl_file "vcs" $b_load_glbl $a_sim_vars(b_int_compile_glbl) $a_sim_vars(l_design_files) $a_sim_vars(s_simset) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $a_sim_vars(b_force_compile_glbl) } {

      # force no compile glbl
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        #******************************
        # yes, glbl.v is being compiled
        #******************************
        return true
      }
    }
  } else {
    # for post*, compile glbl if design contain verilog and netlist is vhdl
    if { (([xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] && ({VHDL} == $a_sim_vars(s_target_lang))) ||
          ($a_sim_vars(b_int_compile_glbl)) || ($a_sim_vars(b_force_compile_glbl))) } {

      # force no compile glbl
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        if { ({timing} == $a_sim_vars(s_type)) } {
          # This is not supported, netlist will be verilog always
        } else {
          if { [xcs_compile_glbl_file "vcs" $b_load_glbl $a_sim_vars(b_int_compile_glbl) $a_sim_vars(l_design_files) $a_sim_vars(s_simset) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || ($a_sim_vars(b_force_compile_glbl)) } {
            #******************************
            # yes, glbl.v is being compiled
            #******************************
            return true
          }
        }
      }
    }
  }
  #***************************
  # no, glbl.v is not compiled
  #***************************
  return false
}

# nopc
proc usf_compile_simmodel_sources { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set platform  "lin"

  set b_dbg 0
  if { $a_sim_vars(s_int_debug_mode) == "1" } {
    set b_dbg 1
  }

  set simulator "vcs"
  set data_dir [rdi::get_data_dir -quiet -datafile "systemc/simlibs"]
  set cpt_dir  [xcs_get_simmodel_dir "vcs" $a_sim_vars(s_gcc_version) "cpt"]

  # is pure-rtl sources for system simulation (selected_sim_model = rtl), don't need to compile the systemC/CPP/C sim-models
  if { [llength $a_sim_vars(l_simmodel_compile_order)] == 0 } {
    if { [file exists $a_sim_vars(s_simlib_dir)] } {
      # delete <run-dir>/simlibs dir (not required)
      [catch {file delete -force $a_sim_vars(s_simlib_dir)} error_msg]
    }
    return
  }

  # update mappings in synopsys_sim.setup
  usf_add_simmodel_mappings

  # find simmodel info from dat file and update do file
  foreach lib_name $a_sim_vars(l_simmodel_compile_order) {
    set lib_path [xcs_find_lib_path_for_simmodel $lib_name]
    set fh_dat 0
    set dat_file "$lib_path/.cxl.sim_info.dat"
    if {[catch {open $dat_file r} fh_dat]} {
      send_msg_id USF-VCS-016 WARNING "Failed to open file to read ($dat_file)\n"
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

    #send_msg_id USF-VCS-107 STATUS "Generating compilation commands for '$lib_name'\n"

    # create local lib dir
    set simlib_dir "$a_sim_vars(s_simlib_dir)/$lib_name"
    if { ![file exists $simlib_dir] } {
      if { [catch {file mkdir $simlib_dir} error_msg] } {
        send_msg_id USF-VCS-013 ERROR "Failed to create the directory ($simlib_dir): $error_msg\n"
        return 1
      }
    }

    # copy simmodel sources locally
    if { $a_sim_vars(b_int_export_source_files) } {
      if { {} == $simmodel_name } { send_msg_id USF-VCS-107 WARNING "Empty tag '$simmodel_name'!\n" }
      if { {} == $library_name  } { send_msg_id USF-VCS-107 WARNING "Empty tag '$library_name'!\n"  }

      set src_sim_model_dir "$data_dir/systemc/simlibs/$simmodel_name/$library_name/src"
      set dst_dir "$a_sim_vars(s_launch_dir)/simlibs/$library_name"
      if { [file exists $src_sim_model_dir] } {
        [catch {file delete -force $dst_dir/src} error_msg]
        if { [catch {file copy -force $src_sim_model_dir $dst_dir} error_msg] } {
          [catch {send_msg_id USF-VCS-108 ERROR "Failed to copy file '$src_sim_model_dir' to '$dst_dir': $error_msg\n"} err]
        } else {
          #puts "copied '$src_sim_model_dir' to run dir:'$a_sim_vars(s_launch_dir)/simlibs'\n"
          }
      } else {
        [catch {send_msg_id USF-VCS-108 ERROR "File '$src_sim_model_dir' does not exist\n"} err]
      }
    }

    # copy include dir
    set simlib_incl_dir "$lib_path/include"
    set target_dir      "$a_sim_vars(s_simlib_dir)/$lib_name"
    set target_incl_dir "$target_dir/include"
    if { ![file exists $target_incl_dir] } {
      if { [catch {file copy -force $simlib_incl_dir $target_dir} error_msg] } {
        [catch {send_msg_id USF-VCS-010 ERROR "Failed to copy file '$simlib_incl_dir' to '$target_dir': $error_msg\n"} err]
      }
    }

    # simmodel file_info.dat data
    set library_type            {}
    set output_format           {}
    set gplus_compile_flags     [list]
    set gplus_compile_flags_vcs [list]
    set gplus_compile_opt_flags [list]
    set gplus_compile_dbg_flags [list]
    set gcc_compile_flags       [list]
    set gcc_compile_opt_flags   [list]
    set gcc_compile_dbg_flags   [list]
    set ldflags                 [list]
    set ldflags_vcs             {}
    set gplus_ldflags_option    {}
    set gcc_ldflags_option      {}
    set ldflags_lin64           [list]
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
    set systemc_incl_dirs_vcs   [list]
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
      if { "<SYSTEMC_INCLUDE_DIRS_VCS>"   == $tag } { set systemc_incl_dirs_vcs   [split $value {,}] }
      if { "<CPP_INCLUDE_DIRS>"           == $tag } { set cpp_incl_dirs           [split $value {,}] }
      if { "<C_INCLUDE_DIRS>"             == $tag } { set c_incl_dirs             [split $value {,}] }
      if { "<OSCI_INCLUDE_DIRS>"          == $tag } { set osci_incl_dirs          [split $value {,}] }
      if { "<G++_COMPILE_FLAGS>"          == $tag } { set gplus_compile_flags     [split $value {,}] }
      if { "<G++_COMPILE_FLAGS_VCS>"      == $tag } { set gplus_compile_flags_vcs [split $value {,}] }
      if { "<G++_COMPILE_OPTIMIZE_FLAGS>" == $tag } { set gplus_compile_opt_flags [split $value {,}] }
      if { "<G++_COMPILE_DEBUG_FLAGS>"    == $tag } { set gplus_compile_dbg_flags [split $value {,}] }
      if { "<GCC_COMPILE_FLAGS>"          == $tag } { set gcc_compile_flags       [split $value {,}] }
      if { "<GCC_COMPILE_OPTIMIZE_FLAGS>" == $tag } { set gcc_compile_opt_flags   [split $value {,}] }
      if { "<GCC_COMPILE_DEBUG_FLAGS>"    == $tag } { set gcc_compile_dbg_flags   [split $value {,}] }
      if { "<LDFLAGS>"                    == $tag } { set ldflags                 [split $value {,}] }
      #if { "<LDFLAGS_VCS>"                == $tag } { set ldflags_vcs             $value }
      if { "<LDFLAGS_LNX64>"              == $tag } { set ldflags_lin64           [split $value {,}] }
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

    #
    # copy simmodel sources locally (if specified in include dir specification) - for default flow (non-export-source-files)
    #
    if { !$a_sim_vars(b_int_export_source_files) } {
      foreach incl_dir $systemc_incl_dirs {
        set leaf [file tail $incl_dir]
        if { ("src" == $leaf) || ("sysc" == $leaf) } {
          set src_sim_model_dir "$data_dir/systemc/simlibs/$simmodel_name/$library_name/$leaf"
          set dst_dir "$a_sim_vars(s_launch_dir)/simlibs/$library_name"
          if { [file exists $src_sim_model_dir] } {
            [catch {file delete -force $dst_dir/$leaf} error_msg]
            if { [catch {file copy -force $src_sim_model_dir $dst_dir} error_msg] } {
              [catch {send_msg_id USF-VCS-108 ERROR "Failed to copy file '$src_sim_model_dir' to '$dst_dir': $error_msg\n"} err]
            } else {
              puts "copied '$src_sim_model_dir' to run dir:'$dst_dir'\n"
            }
          } else {
            #[catch {send_msg_id USF-VCS-108 ERROR "File '$src_sim_model_dir' does not exist\n"} err]
          }
        }
      }
    }

    set obj_dir "$a_sim_vars(s_launch_dir)/vcs_lib/$lib_name"
    if { ![file exists $obj_dir] } {
      if { [catch {file mkdir $obj_dir} error_msg] } {
        send_msg_id USF-VCS-013 ERROR "Failed to create the directory ($obj_dir): $error_msg\n"
        return 1
      }
    }

    #
    # write systemC/CPP/C command line
    #
    if { [llength $sysc_files] > 0 } {
      set compiler "syscan"
      puts $fh "# compile '$lib_name' model sources"
      foreach src_file $sysc_files {
        set file_name [file root [file tail $src_file]]

        set args [list]
        if { {} != $a_sim_vars(sysc_ver) } {
          lappend args "-sysc=$a_sim_vars(sysc_ver)"
        }
        lappend args "-full64"
        lappend args "-cpp $a_sim_vars(s_gcc_bin_path)/g++"
        lappend args "-cflags \""
        lappend args "-DSC_INCLUDE_DYNAMIC_PROCESSES"

        # <SYSTEMC_INCLUDE_DIRS>
        foreach incl_dir $systemc_incl_dirs {
          #if { [regexp {xv_ext_lib_path\/protobuf\/include} $incl_dir] } {
          #  set incl_dir [regsub -all {protobuf} $incl_dir {utils/protobuf}]
          #}
          lappend args "-I$incl_dir"
        }

        # <SYSTEMC_INCLUDE_DIRS_VCS>
        foreach incl_dir $systemc_incl_dirs_vcs {
          #if { [regexp {xv_ext_lib_path\/protobuf\/include} $incl_dir] } {
            #set incl_dir [regsub -all {protobuf} $incl_dir {utils/protobuf}]
          #}
          lappend args "-I$incl_dir"
        }

        # <CPP_COMPILE_OPTION>
        lappend args $cpp_compile_option

        # <G++_COMPILE_FLAGS>
        foreach opt $gplus_compile_flags     { lappend args $opt }
        foreach opt $gplus_compile_flags_vcs { lappend args $opt }
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

        lappend args "\""
        lappend args $src_file
        lappend args "-Mdir=vcs_lib/${lib_name}"

        set cmd_str [join $args " "]
        puts $fh "$a_sim_vars(s_tool_bin_path)/$compiler $cmd_str\n"
      }

      #
      # LINK (g++)
      #
      set compiler "g++"
      set args [list]
      lappend args "-m64"
      foreach src_file $sysc_files {
        set file_name [file root [file tail $src_file]]
        #set obj_file "vcs_lib/$lib_name/${file_name}.o"
        set obj_file "vcs_lib/${lib_name}/sysc/${file_name}.o"
        lappend args $obj_file
      }

      # <LDFLAGS>
      if { [llength $ldflags] > 0 } { foreach opt $ldflags { lappend args $opt } }

      # <LDFLAGS_VCS>
      #if { {} != $ldflags_vcs } {
      #  lappend args $ldflags_vcs
      #}

      if { [llength $ldflags_lin64] > 0 } { foreach opt $ldflags_lin64 { lappend args $opt } }

      # acd ldflags
      if { {} != $gplus_ldflags_option } { lappend args $gplus_ldflags_option }

      # <LDLIBS>
      if { [llength $ldlibs] > 0 } {
        foreach opt $ldlibs {
          set vcs_lib_dir "$a_sim_vars(s_launch_dir)/vcs_lib"
          if { [regexp "Lvcs_lib" $opt] } {
            set opt [regsub -all {vcs_lib} $opt $vcs_lib_dir]
          }
          lappend args $opt
        }
      }

      lappend args "-shared"
      lappend args "-o"
      lappend args "./vcs_lib/$lib_name/lib${lib_name}.so"

      set cmd_str [join $args " "]
      puts $fh "$a_sim_vars(s_gcc_bin_path)/$compiler $cmd_str\n"

    } elseif { [llength $cpp_files] > 0 } {
      puts $fh "# compile '$lib_name' model sources"
      set compiler "g++"
      #
      # COMPILE (g++)
      #
      foreach src_file $cpp_files {
        set file_name [file root [file tail $src_file]]
        set args [list]
        lappend args "-m64"
        lappend args "-c"

        # 1074568
        if { [regexp "^common_cpp_v1_0" $lib_name] } {
          lappend args "-DVCSSYSTEMC"
        }

        # <CPP_INCLUDE_DIRS>
        if { [llength $cpp_incl_dirs] > 0 } {
          foreach incl_dir $cpp_incl_dirs {
            lappend args "-I $incl_dir"
          }
        }

        # <CPP_COMPILE_OPTION>
        lappend args $cpp_compile_option

        # <G++_COMPILE_FLAGS>
        if { [llength $gplus_compile_flags] > 0 } {
          foreach opt $gplus_compile_flags {
            lappend args $opt
          }
        }

        # <G++_COMPILE_DEBUG_FLAGS>
        if { $b_dbg } {
          if { [llength $gplus_compile_dbg_flags] > 0 } {
            foreach opt $gplus_compile_dbg_flags {
              lappend args $opt
            }
          }
        # <G++_COMPILE_OPT_FLAGS>
        } else {
          if { [llength $gplus_compile_opt_flags] > 0 } {
            foreach opt $gplus_compile_opt_flags {
              lappend args $opt
            }
          }
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
        lappend args "vcs_lib/$lib_name/${file_name}.o"

        set cmd_str [join $args " "]
        puts $fh "$a_sim_vars(s_gcc_bin_path)/$compiler $cmd_str\n"
      }

      #
      # LINK (g++)
      #
      set args [list]
      foreach src_file $cpp_files {
        set file_name [file root [file tail $src_file]]
        set obj_file "vcs_lib/$lib_name/${file_name}.o"
        lappend args $obj_file
      }
      lappend args "-m64"
      lappend args "-shared"
      lappend args "-o"
      lappend args "vcs_lib/$lib_name/lib${lib_name}.so"

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
        set args [list]
        lappend args "-m64"
        lappend args "-c"

        # <C_INCLUDE_DIRS>
        if { [llength $c_incl_dirs] > 0 } {
          foreach incl_dir $c_incl_dirs {
            lappend args "-I $incl_dir"
          }
        }

        # <C_COMPILE_OPTION>
        lappend args $c_compile_option

        # <GCC_COMPILE_FLAGS>
        #
        # TODO : for now use gplus_compile_flags (add support for <GCC_COMPILE_FLAGS> in compile_simlib and update this accordingly)
        #      : add <GCC_COMPILE_FLAGS> tag in remote_port_c_v4
        #
        if { [llength $gplus_compile_flags] > 0 } {
          foreach opt $gplus_compile_flags {
            lappend args $opt
          }
        }

        # <GCC_COMPILE_DEBUG_FLAGS>
        if { $b_dbg } {
          if { [llength $gcc_compile_dbg_flags] > 0 } {
            foreach opt $gcc_compile_dbg_flags {
              lappend args $opt
            }
          }
        # <GCC_COMPILE_OPT_FLAGS>
        } else {
          if { [llength $gcc_compile_opt_flags] > 0 } {
            foreach opt $gcc_compile_opt_flags {
              lappend args $opt
            }
          }
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
        lappend args "vcs_lib/$lib_name/${file_name}.o"

        set cmd_str [join $args " "]
        puts $fh "$a_sim_vars(s_gcc_bin_path)/$compiler $cmd_str\n"
      }

      #
      # LINK (gcc)
      #
      set args [list]
      foreach src_file $c_files {
        set file_name [file root [file tail $src_file]]
        set obj_file "vcs_lib/$lib_name/${file_name}.o"
        lappend args $obj_file
      }
      lappend args "-m64"
      lappend args "-shared"
      lappend args "-o"
      lappend args "vcs_lib/$lib_name/lib${lib_name}.so"

      set cmd_str [join $args " "]
      puts $fh "$a_sim_vars(s_gcc_bin_path)/$compiler $cmd_str\n"
    }
  }
}

proc usf_add_simmodel_mappings { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  # file should be present by now
  set syn_file "$a_sim_vars(s_launch_dir)/synopsys_sim.setup"
  if { ![file exists $syn_file] } {
    return
  }

  # read synopsys_sim.setup contents
  set fh 0
  if {[catch {open $syn_file r} fh]} {
    send_msg_id USF-VCS-011 ERROR "Failed to open file to read ($synfile)\n"
    return 1
  }
  set data [split [read $fh] "\n"]
  close $fh

  # delete synopsys_sim.setup
  [catch {file delete -force $syn_file} error_msg]

  # create updated setup file (iterate over synopsys_sim.setup and replace the simulation model library path with local directory)
  set fh 0
  if {[catch {open $syn_file w} fh]} {
    send_msg_id USF-VCS-011 ERROR "Failed to open file to write ($syn_file)\n"
    return
  }

  set others_mapping ""
  set b_start_adding_sim_model_mappings false
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    # end of mappings?
    if { [regexp "^OTHERS" $line] } {
      set others_mapping $line
      set b_start_adding_sim_model_mappings true
    } else {
      puts $fh $line
    }

    if { $b_start_adding_sim_model_mappings } {
      foreach library $a_sim_vars(l_simmodel_compile_order) {
        set mapping "$library : $a_sim_vars(compiled_design_lib)/$library"      
        puts $fh $mapping
      }
    }
  }
  puts $fh $others_mapping
  close $fh
}

proc usf_vcs_write_elaborate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable a_sim_cache_all_ip_obj

  # step exec mode?
  if { $a_sim_vars(b_exec_step) } {
    return 0
  }

  set netlist_mode [get_property "nl.mode" $a_sim_vars(fs_obj)]

  set scr_filename "elaborate";append scr_filename [xcs_get_script_extn "vcs"]
  set scr_file [file normalize [file join $a_sim_vars(s_launch_dir) $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-VCS-013 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }
  puts $fh_scr "[xcs_get_shell_env]"
  xcs_write_script_header $fh_scr "elaborate" "vcs"
  xcs_write_version_id $fh_scr "vcs"
  if { {} != $a_sim_vars(s_tool_bin_path) } {
    usf_vcs_init_env $fh_scr
    set b_set_shell_var_exit false
    [catch {set b_set_shell_var_exit [get_param "project.setShellVarsForSimulationScriptExit"]} err]
    if { $b_set_shell_var_exit } {
      puts $fh_scr "\n# catch pipeline exit status"
      xcs_write_pipe_exit $fh_scr
    }
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"[xcs_replace_with_var $a_sim_vars(s_tool_bin_path) "SIM_VER" "vcs"]\""
 
    usf_set_vcs_home $fh_scr

    if { $a_sim_vars(b_int_systemc_mode) } {
      if { $a_sim_vars(b_system_sim_design) } {
        # set gcc path
		puts $fh_scr "gcc_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_gcc_bin_path) "SIM_VER" "vcs"] "GCC_VER" "vcs"]\""
		puts $fh_scr "sys_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_sys_link_path) "SIM_VER" "vcs"] "GCC_VER" "vcs"]\""
        
        # bind user specified libraries
        set l_link_sysc_libs [get_property "vcs.elaborate.link.sysc" $a_sim_vars(fs_obj)]
        set l_link_c_libs    [get_property "vcs.elaborate.link.c"    $a_sim_vars(fs_obj)]

        xcs_write_library_search_order $fh_scr "vcs" "elaborate" $a_sim_vars(b_compile_simmodels) $a_sim_vars(s_launch_dir) $a_sim_vars(s_gcc_version) $a_sim_vars(s_clibs_dir) $a_sim_vars(sp_cpt_dir) l_link_sysc_libs l_link_c_libs
      }
    }
  }
  set tool "vcs"
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
  set arg_list [list]
  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      if { {} != $a_sim_vars(sysc_ver) } {
        lappend arg_list "-sysc=$a_sim_vars(sysc_ver)"
      }
      lappend arg_list "-cpp \$\{gcc_path\}/g++"
    }
  }

  if { $a_sim_vars(b_uvm) } {
    lappend arg_list "-ntb_opts uvm-1.2 -R"
  }
 
  if { [get_property "vcs.elaborate.debug_acc" $a_sim_vars(fs_obj)] } {
    set dbg_sw "-debug_acc"
    lappend arg_list $dbg_sw
  }

  set arg_list [linsert $arg_list end "-t" "ps" "-licqueue"]

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
    set arg_list [linsert $arg_list end "+pulse_r/$path_delay +pulse_int_r/$int_delay +pulse_e/$path_delay +pulse_int_e/$int_delay"]
  }
  set arg_list [linsert $arg_list end "-l" "elaborate.log"]
  if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
    # donot pass os type
  } else {
     set arg_list [linsert $arg_list 0 "-full64"]
  }

  #
  # user design and xpm libraries will be resolved by setup file (post* simulation)
  #
  set b_auto_map_ref_lib false
  [catch {set b_auto_map_ref_lib [get_param simulator.autoMapVCSLibraryForNetlistSimulation]} err]
  if { $b_auto_map_ref_lib } {
    if { ({post-synthesis} == $a_sim_vars(s_mode)) || ({post-implementation} == $a_sim_vars(s_mode)) } {
      if { {timing} == $a_sim_vars(s_type) } {
        lappend arg_list "-liblist xil_defaultlib"
        lappend arg_list "-liblist simprims_ver"
        lappend arg_list "-liblist secureip"
      }
    }
  } else {
    if { ({post-synthesis} == $a_sim_vars(s_mode)) || ({post-implementation} == $a_sim_vars(s_mode)) } {
      if { {Verilog} == $a_sim_vars(s_target_lang) } {
        if { {functional} == $a_sim_vars(s_type) } {
          if { "virtexuplus58g" == [rdi::get_family -arch] } {
            lappend arg_list "-liblist unisim"
          }
          lappend arg_list "-liblist unisims_ver"
        } elseif { {timing} == $a_sim_vars(s_type) } {
          lappend arg_list "-liblist simprims_ver"
        }
        lappend arg_list "-liblist secureip"
        lappend arg_list "-liblist xil_defaultlib"
      } elseif { {VHDL} == $a_sim_vars(s_target_lang) } {
        if { {functional} == $a_sim_vars(s_type) } {
          # TODO: bind following 3 for hybrid only
          if { "virtexuplus58g" == [rdi::get_family -arch] } {
            lappend arg_list "-liblist unisim"
            lappend arg_list "-liblist unisims_ver"
            lappend arg_list "-liblist secureip"
          }
        } elseif { {timing} == $a_sim_vars(s_type) } {
          lappend arg_list "-liblist simprims_ver"
          lappend arg_list "-liblist secureip"
        }
        lappend arg_list "-liblist xil_defaultlib"
      }
      # bind hybrid unisims ver components that were compiled into 'unisim' library for versal
      if { "versal" == [rdi::get_family -arch] } {
        lappend arg_list "-liblist unisim"
      }
    }
  }

  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
        variable a_shared_library_path_coln
        # bind protected libraries
        set cpt_dir [rdi::get_data_dir -quiet -datafile "simmodels/vcs"]
        set sm_cpt_dir [xcs_get_simmodel_dir "vcs" $a_sim_vars(s_gcc_version) "cpt"]
        foreach {key value} [array get a_shared_library_path_coln] {
          set name [file tail $value]
          set lib_dir "$cpt_dir/$sm_cpt_dir/$name"
          if { ([regexp "^noc_v" $name]) || ([regexp "^noc2_v" $name]) } {
            set arg_list [linsert $arg_list end "\$xv_cpt_lib_path/${name}/lib${name}.so"]
            #if { [regexp "^noc_v1" $name] } {
            #  set arg_list [linsert $arg_list end "\$xv_cpt_lib_path/${name}/libnocbase_v1_0_0.a"]
            #}
          }
          if { ([regexp "^aie_cluster" $name]) || ([regexp "^aie_xtlm" $name]) } {
            set model_ver [rdi::get_aie_config_type]
            set lib_name "${model_ver}_cluster_v1_0_0"
            if { {aie} == $model_ver } {
              set lib_dir "$cpt_dir/$sm_cpt_dir/$lib_name"
            } else {
              set lib_dir "$cpt_dir/$sm_cpt_dir/$model_ver"
            }
            #set arg_list [linsert $arg_list end "-L$lib_dir"]
            #set arg_list [linsert $arg_list end "-l$lib_name"]
          }
        }
        # bind simmodels
        foreach {key value} [array get a_shared_library_path_coln] {
          set shared_lib_name $key
          set shared_lib_name [file root $shared_lib_name]
          set shared_lib_name [string trimleft $shared_lib_name "lib"]

          set sm_lib_dir [file normalize $value]
          set sm_lib_dir [regsub -all {[\[\]]} $sm_lib_dir {/}]

          if { $a_sim_vars(b_compile_simmodels) } {
            if { [regexp "^protobuf" $shared_lib_name] } {
             # skip
            } else {
              set sm_lib_dir "$a_sim_vars(s_launch_dir)/vcs_lib/$shared_lib_name"
            }
          }

          #if { [regexp "^protobuf" $shared_lib_name] } { continue; }
          if { ([regexp "^noc_v"         $shared_lib_name]) ||
               ([regexp "^noc2_v"        $shared_lib_name]) } {
            continue;
          }
          if { [regexp "^aie_xtlm_" $shared_lib_name] } {
            set model_ver [rdi::get_aie_config_type]
            set lib_name "${model_ver}_cluster_v1_0_0"
            set aie_lib_path ""
            if { {aie} == $model_ver } {
              set aie_lib_path "\$xv_cpt_lib_path/$lib_name"
            } else {
              set aie_lib_path "\$xv_cpt_lib_path/$model_ver"
            }
            set arg_list [linsert $arg_list end "-Mlib=$aie_lib_path"]
            set arg_list [linsert $arg_list end "-Mdir=$a_sim_vars(tmp_obj_dir)/_xil_csrc_"]
          }
          if { [xcs_is_sc_library $shared_lib_name] } {
            set arg_list [linsert $arg_list end "-Mlib=\$xv_cxl_lib_path/$shared_lib_name"]
            set arg_list [linsert $arg_list end "-Mdir=$a_sim_vars(tmp_obj_dir)/_xil_csrc_"]
          } else {
            if { [regexp "^protobuf" $shared_lib_name] } {
              set arg_list [linsert $arg_list end "-L\$xv_ext_lib_path/$shared_lib_name -l$shared_lib_name"]
            } else {
              set arg_list [linsert $arg_list end "-L\$xv_cxl_lib_path/$shared_lib_name -l$shared_lib_name"]
            }
          }
        }

        # link IP design libraries
        set shared_ip_libs [xcs_get_shared_ip_libraries $a_sim_vars(s_clibs_dir)]
        if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
          puts "------------------------------------------------------------------------------------------------------------------------------------"
          puts "Referenced pre-compiled shared libraries"
          puts "------------------------------------------------------------------------------------------------------------------------------------"
        }
        set uniq_shared_libs        [list]
        set shared_lib_objs_to_link [list]
        xcs_cache_ip_objs
        foreach ip [array names a_sim_cache_all_ip_obj] {
          set ip_obj $a_sim_cache_all_ip_obj($ip)
          set ipdef [get_property -quiet "ipdef" $ip_obj]
          set vlnv_name [xcs_get_library_vlnv_name $ip_obj $ipdef]
          if { [lsearch $shared_ip_libs $vlnv_name] != -1 } {
            if { [lsearch -exact $uniq_shared_libs $vlnv_name] == -1 } {
              lappend uniq_shared_libs $vlnv_name
              if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
                puts "(shared object) '$a_sim_vars(s_clibs_dir)/$vlnv_name'"
              }
              foreach obj_file_name [xcs_get_pre_compiled_shared_objects "vcs" $a_sim_vars(s_clibs_dir) $vlnv_name] {
                if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
                  puts " + linking $vlnv_name -> '$obj_file_name'"
                }
                lappend shared_lib_objs_to_link "$obj_file_name"
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
        foreach shared_lib_obj $shared_lib_objs_to_link {
          set arg_list [linsert $arg_list end "$shared_lib_obj"]
        }
        if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
          puts "------------------------------------------------------------------------------------------------------------------------------------"
        }

        set arg_list [linsert $arg_list end "-Mdir=c.obj"]
        set arg_list [linsert $arg_list end "-lstdc++fs"]
        if { $a_sim_vars(b_optimizeForRuntime) } {
          set arg_list [linsert $arg_list end $a_sim_vars(syscan_libname)]
        }
  
        set aie_ip_obj [xcs_find_ip "ai_engine"]
        if { {} != $aie_ip_obj } {
          lappend arg_list "-LDFLAGS -Wl,-undefined=_ZN7sc_core14sc_event_queueC1ENS_14sc_module_nameE,-undefined=_ZN5sc_dt12sc_concatref6m_poolE"
        }
      }
    }
  }

  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      #puts $fh_scr "# set gcc objects"
      set objs_arg [list]
      set uniq_objs [list]

      variable a_design_c_files_coln
      foreach {key value} [array get a_design_c_files_coln] {
        set c_file     $key
        set file_type  $value
        set file_name [file tail [file root $c_file]]
        append file_name ".o"
        if { [lsearch -exact $uniq_objs $file_name] == -1 } {
          lappend objs_arg "$a_sim_vars(tmp_obj_dir)/sysc/$file_name"
          lappend uniq_objs $file_name
        }
      }
      set objs_arg_str [join $objs_arg " "]
      #puts $fh_scr "gcc_objs=\"$objs_arg_str\"\n"
    }
  }

  set more_elab_options [string trim [get_property "vcs.elaborate.vcs.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_elab_options } {
    set arg_list [linsert $arg_list end "$more_elab_options"]
  }

  # bind user specified libraries
  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    set l_link_sysc_libs [get_property "vcs.elaborate.link.sysc" $a_sim_vars(fs_obj)]
    if { [llength $l_link_sysc_libs] > 0 } { foreach lib $l_link_sysc_libs { lappend arg_list $lib } }

    set l_link_c_libs [get_property "vcs.elaborate.link.c" $a_sim_vars(fs_obj)]
    if { [llength $l_link_c_libs] > 0 } { foreach lib $l_link_c_libs { lappend arg_list $lib } }
  }

  puts $fh_scr "\n# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  puts $fh_scr "\n# run elaboration"

  set tool_path_val "\$bin_path/$tool"
  if { {} == $a_sim_vars(s_tool_bin_path) } {
    set tool_path_val "$tool"
  }
  set arg_list [list "${tool_path_val}" "\$${tool}_opts"]

  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      #lappend arg_list "-sysc"
      #lappend arg_list "-L\$PWD"
      #lappend arg_list "-l$a_sim_vars(s_sim_top)_sc"
    }
  }
  
  set b_bind_dpi_c false
  [catch {set b_bind_dpi_c [get_param project.bindGTDPICModel]} err]
  set ip_obj [xcs_find_ip "gt_quad_base"]
  if { {} != $ip_obj } {
    set clib_dir $a_sim_vars(s_clibs_dir)
    append clib_dir "/secureip"
    set comp_name "gtye5_quad"
    # is this configured for gtyp?
    set config_type [get_property -quiet "config.gt_type" $ip_obj]
    if { [string equal -nocase $config_type "GTYP"] == 1 } {
      set comp_name "gtyp_quad"
    }
    set shared_library "lib${comp_name}.so"
    set quad_lib "$clib_dir/${shared_library}"

    if { $b_bind_dpi_c } {
      if { [file exists $quad_lib] } {
        #set gcc_cmd "-cc g++ -ld g++ -LDFLAGS \"-L/usr/lib -lstdc++\" [join $obj_files " "]"
        set gcc_cmd "-L$clib_dir -l${comp_name}"
        lappend arg_list $gcc_cmd
      } else {
        send_msg_id USF-VCS-070 "CRITICAL WARNING" "Shared library does not exist! '$quad_lib'\n"
      }
    }
  }

  set obj $a_sim_vars(sp_tcl_obj)
  if { [xcs_is_fileset $obj] } {
    set vhdl_generics [list]
    set vhdl_generics [get_property "generic" [get_filesets $obj]]
    if { [llength $vhdl_generics] > 0 } {
      xcs_append_generics "vcs" $vhdl_generics arg_list
    }
  }

  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      #lappend arg_list "-loadsc $a_sim_vars(s_sim_top)_sc"
    }
  }

  variable l_hard_blocks
  foreach hb $l_hard_blocks {
    set hb_wrapper "xil_defaultlib.${hb}_sim_wrapper"
    lappend arg_list "$hb_wrapper"
  }

  lappend arg_list "${top_lib}.$a_sim_vars(s_sim_top)"

  # logical noc top
  set lnoc_top [get_property -quiet "logical_noc_top" $a_sim_vars(fs_obj)]
  if { {} != $lnoc_top } {
    set lib [get_property -quiet "logical_noc_top_lib" $a_sim_vars(fs_obj)]
    lappend arg_list "${lib}.${lnoc_top}"
  }

  set top_level_inst_names {}
  usf_add_glbl_top_instance arg_list $top_level_inst_names

#  if { $a_sim_vars(b_int_systemc_mode) } {
#    if { $a_sim_vars(b_system_sim_design) } {
#    # set gcc path
#    if { {} != $a_sim_vars(s_gcc_bin_path) } {
#        # TODO: some of this code may need to go to vcs_opts
#        #puts $fh_scr "# generate shared object"
#        set link_arg_list [list "\$a_sim_vars(s_gcc_bin_path)/g++"]
#        lappend link_arg_list "-m64 -Wl,-G -shared -o"
#        lappend link_arg_list "lib$a_sim_vars(s_sim_top)_sc.so"
#        lappend link_arg_list "\$gcc_objs"
#        set l_sm_lib_paths [list]
#        foreach {library lib_dir} [array get a_shared_library_path_coln] {
#          set sm_lib_dir [file normalize $lib_dir]
#          set sm_lib_dir [regsub -all {[\[\]]} $sm_lib_dir {/}]
#          set lib_name [string trimleft $library "lib"]
#          set lib_name [string trimright $lib_name ".so"]
#          lappend link_arg_list "-L$sm_lib_dir -l$lib_name"
#        }
#
#        # link IP design libraries
#        set shared_ip_libs [xcs_get_shared_ip_libraries $a_sim_vars(s_clibs_dir)]
#        set ip_objs [get_ips -all -quiet]
#        if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
#          puts "------------------------------------------------------------------------------------------------------------------------------------"
#          puts "Referenced pre-compiled shared libraries"
#          puts "------------------------------------------------------------------------------------------------------------------------------------"
#        }
#        set uniq_shared_libs        [list]
#        set shared_lib_objs_to_link [list]
#        foreach ip_obj $ip_objs {
#          set ipdef [get_property -quiet "ipdef" $ip_obj]
#          set vlnv_name [xcs_get_library_vlnv_name $ip_obj $ipdef]
#          if { [lsearch $shared_ip_libs $vlnv_name] != -1 } {
#            if { [lsearch -exact $uniq_shared_libs $vlnv_name] == -1 } {
#              lappend uniq_shared_libs $vlnv_name
#              if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
#                puts "(shared object) '$a_sim_vars(s_clibs_dir)/$vlnv_name'"
#              }
#              foreach obj_file_name [xcs_get_pre_compiled_shared_objects "vcs" $a_sim_vars(s_clibs_dir) $vlnv_name] {
#                if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
#                  puts " + linking $vlnv_name -> '$obj_file_name'"
#                }
#                lappend shared_lib_objs_to_link "$obj_file_name"
#              }
#            }
#          }
#        }
#        foreach shared_lib_obj $shared_lib_objs_to_link {
#          lappend link_arg_list "$shared_lib_obj"
#        }
#        if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
#          puts "------------------------------------------------------------------------------------------------------------------------------------"
#        }
#        #lappend link_arg_list "\$sys_libs"
#        #set link_args [join $link_arg_list " "]
#        #puts $fh_scr "$link_args\n"
#      }
#    }
#  }

  lappend arg_list "-o"
  lappend arg_list "$a_sim_vars(s_sim_top)_simv"
  set cmd_str [join $arg_list " "]

  puts $fh_scr "$cmd_str"
  close $fh_scr
}

proc usf_add_glbl_top_instance { opts_arg top_level_inst_names } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts

  variable a_sim_vars

  set b_verilog_sim_netlist 0
  set b_vhdl_sim_netlist 0
  if { ({post_synth_sim} == $a_sim_vars(s_simulation_flow)) || ({post_impl_sim} == $a_sim_vars(s_simulation_flow)) } {
    if { {Verilog} == $a_sim_vars(s_target_lang) } {
      set b_verilog_sim_netlist 1
    }
    if { {VHDL} == $a_sim_vars(s_target_lang) } {
      set b_vhdl_sim_netlist 1
    }
  }

  set b_add_glbl 0
  set b_top_level_glbl_inst_set 0

  # is glbl specified explicitly?
  if { ([lsearch ${top_level_inst_names} {glbl}] != -1) } {
    set b_top_level_glbl_inst_set 1
  }

  set b_load_glbl [get_property "vcs.compile.load_glbl" $a_sim_vars(fs_obj)]
  if { [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $b_verilog_sim_netlist } {
    if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
      if { (!$b_top_level_glbl_inst_set) && $b_load_glbl } {
        set b_add_glbl 1
      }
    } else {
      # for post* sim flow add glbl top if design contains verilog sources or verilog netlist add glbl top if not set earlier
      if { !$b_top_level_glbl_inst_set } {
        if { [xcs_compile_glbl_file "vcs" $b_load_glbl $a_sim_vars(b_int_compile_glbl) $a_sim_vars(l_design_files) $a_sim_vars(s_simset) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] } {
          set b_add_glbl 1
        }
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

  # versal
  if { $a_sim_vars(b_int_compile_glbl) } {
    # for pure VHDL design instantiating verilog primitives, do not set glbl top
    if { [xcs_is_pure_vhdl_design $a_sim_vars(l_design_files)] } {
      set b_add_glbl 0
    }
    if { !$b_add_glbl } {
      # for behav
      if { ({behav_sim} == $a_sim_vars(s_simulation_flow)) } {
        if { [xcs_is_pure_vhdl_design $a_sim_vars(l_design_files)] } {
          set b_add_glbl 1
        }
      }
      # for post* when target lang is vhdl, set glbl
      if { ({post_synth_sim} == $a_sim_vars(s_simulation_flow)) || ({post_impl_sim} == $a_sim_vars(s_simulation_flow)) } {
        if { $b_vhdl_sim_netlist } {
          set b_add_glbl 1
        }
      }
    }
  }

  # force add glbl top
  if { !$b_add_glbl } {
    if { $a_sim_vars(b_force_compile_glbl) } {
      set b_add_glbl 1
    }
  }

  # force no compile glbl
  if { $b_add_glbl && $a_sim_vars(b_force_no_compile_glbl) } {
    set b_add_glbl 0
  }

  set b_set_glbl_top 0
  if { $b_add_glbl } {
    set b_is_pure_vhdl [xcs_is_pure_vhdl_design $a_sim_vars(l_design_files)]
    set b_xpm_cdc      [xcs_glbl_dependency_for_xpm]
    if { $b_is_pure_vhdl && $b_xpm_cdc && ({behav_sim} == $a_sim_vars(s_simulation_flow)) } {
      # no op - donot pass glbl (VCS reports Error-[VH-DANGLEVL-NA] VL top in pure VHDL flow), but set if force compile
      #
      # revisit:- no-check required based on cr:1096784 but will revisit if some other test is reporting dangling issue
      #           enabling by default for now
      #if { $a_sim_vars(b_force_compile_glbl) } {
         set b_set_glbl_top 1
      #}
    } else {
      set b_set_glbl_top 1
    }
  }

  if { $b_set_glbl_top } {
    set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
    lappend opts "${top_lib}.glbl"
  }
}

proc usf_vcs_write_simulate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  # step exec mode?
  if { $a_sim_vars(b_exec_step) } {
    return 0
  }

  set filename "simulate";append filename ".sh"
  set file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh_scr 0
  if {[catch {open $file w} fh_scr]} {
    send_msg_id USF-VCS-015 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
 
  puts $fh_scr "[xcs_get_shell_env]"
  xcs_write_script_header $fh_scr "simulate" "vcs"
  xcs_write_version_id $fh_scr "vcs"
  if { {} != $a_sim_vars(s_tool_bin_path) } {
    usf_vcs_init_env $fh_scr
    set b_set_shell_var_exit false
    [catch {set b_set_shell_var_exit [get_param "project.setShellVarsForSimulationScriptExit"]} err]
    if { $b_set_shell_var_exit } {
      puts $fh_scr "\n# catch pipeline exit status"
      xcs_write_pipe_exit $fh_scr
    }
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"[xcs_replace_with_var $a_sim_vars(s_tool_bin_path) "SIM_VER" "vcs"]\""

    usf_set_vcs_home $fh_scr

    if { $a_sim_vars(b_int_systemc_mode) } {
      if { $a_sim_vars(b_system_sim_design) } {
        puts $fh_scr "sys_path=\"$a_sim_vars(s_sys_link_path)\""
        if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
          xcs_write_launch_mode_for_vitis $fh_scr "vcs"
        }
 
        # bind user specified libraries
        set l_link_sysc_libs [get_property "vcs.elaborate.link.sysc" $a_sim_vars(fs_obj)]
        set l_link_c_libs    [get_property "vcs.elaborate.link.c"    $a_sim_vars(fs_obj)]

        xcs_write_library_search_order $fh_scr "vcs" "simulate" $a_sim_vars(b_compile_simmodels) $a_sim_vars(s_launch_dir) $a_sim_vars(s_gcc_version) $a_sim_vars(s_clibs_dir) $a_sim_vars(sp_cpt_dir) l_link_sysc_libs l_link_c_libs
      }
    }
  }

  set ip_obj [xcs_find_ip "gt_quad_base"]
  if { {} != $ip_obj } {
    set secureip_dir "$a_sim_vars(compiled_library_dir)/secureip"
    if { [file exists $secureip_dir] } {
      puts $fh_scr "\n# set library search order"
      puts $fh_scr "LD_LIBRARY_PATH=$secureip_dir:\$LD_LIBRARY_PATH"
    }
  }
  
  set do_filename "$a_sim_vars(s_sim_top)_simulate.do"
  usf_create_do_file "vcs" $do_filename
  set tool "$a_sim_vars(s_sim_top)_simv"
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
  set arg_list [list "-ucli" "-licqueue" "-l" "simulate.log"]

  set more_sim_options [string trim [get_property "vcs.simulate.vcs.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_sim_options } {
    set arg_list [linsert $arg_list end "$more_sim_options"]
  }

  if { $a_sim_vars(b_batch) || $a_sim_vars(b_scripts_only) } {
    # no gui
    if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
      set arg_list [linsert $arg_list end "\$mode"]
    } else {
      # for scripts_only mode, set script for simulator gui mode (pass -gui)
      if { $a_sim_vars(b_gui) } {
        set arg_list [linsert $arg_list end "-gui"]
      }
    }
  } else {
    # launch_simulation - if called from vivado in gui mode only
    if { $a_sim_vars(b_int_is_gui_mode) } {
      set arg_list [linsert $arg_list end "-gui"]
    }
  }

  puts $fh_scr "\n# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  set arg_list [list "./$a_sim_vars(s_sim_top)_simv"]
  set arg_list [list $arg_list "\$${tool}_opts"]
  lappend arg_list "-do"
  lappend arg_list "$do_filename"
  set cmd_str [join $arg_list " "]

  puts $fh_scr "\n# run simulation"
  puts $fh_scr "$cmd_str"
  close $fh_scr
}

proc usf_set_vcs_home { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars
  if { $a_sim_vars(b_scripts_only) } {
    if { {} == $a_sim_vars(s_vcs_home) } {
      if { [info exists ::env(VCS_HOME)] } {
        set a_sim_vars(s_vcs_home) $::env(VCS_HOME)
      } else {
        set a_sim_vars(s_vcs_home) [file dirname $a_sim_vars(s_install_path)]
        send_msg_id USF-VCS-099 WARNING "VCS_HOME env variable not found! Setting it to '$a_sim_vars(s_vcs_home)' in the generated scripts using install path '$a_sim_vars(s_install_path)'\n"
        set ::env(VCS_HOME) $a_sim_vars(s_vcs_home)
      }
    }
    if { ({} != $a_sim_vars(s_vcs_home)) && ([file exists $a_sim_vars(s_vcs_home)]) && ([file isdirectory $a_sim_vars(s_vcs_home)]) } {
      puts $fh_scr "\n# VCS_HOME setting"
      puts $fh_scr "export VCS_HOME=[xcs_replace_with_var $a_sim_vars(s_vcs_home) "SIM_VER" "vcs"]"
    }
  }
}

proc usf_vcs_map_pre_compiled_libs { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { !$a_sim_vars(b_use_static_lib) } {
    return
  }

  set lib_path [get_property "sim.ipstatic.compiled_library_dir" [current_project]]
  set ini_file [file join $lib_path "synopsys_sim.setup"]
  if { ![file exists $ini_file] } {
    return
  }

  set fh_ini 0
  if { [catch {open $ini_file r} fh_ini] } {
    send_msg_id USF-VCS-099 WARNING "Failed to open file for read ($ini_file)\n"
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
      if { ([regexp {^--} $line]) } {
        set b_lib_start false
        continue
      }
      if { [regexp ":" $line] } {
        puts $fh "$line"
      }
    }
  }
}

proc usf_vcs_create_setup_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  variable l_ip_static_libs
  variable l_local_design_libraries

  set filename "setup";append filename [xcs_get_script_extn "vcs"]
  set scr_file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-VCS-017 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  puts $fh_scr "[xcs_get_shell_env]"
  xcs_write_script_header $fh_scr "setup" "vcs"
  xcs_write_version_id $fh_scr "vcs"

  puts $fh_scr "\n# Script usage"
  puts $fh_scr "usage()"
  puts $fh_scr "\{"
  puts $fh_scr "  msg=\"Usage: setup.sh \[-help\]\\n\\"
  puts $fh_scr "Usage: setup.sh \[-reset_run\]\\n\\n\\\n\\"
  puts $fh_scr "\[-help\] -- Print help\\n\\n\\"
  puts $fh_scr "\[-reset_run\] -- Recreate simulator setup files and library mappings for a clean run. The generated files\\n\\"
  puts $fh_scr "\\t\\tfrom the previous run will be removed automatically.\\n\""
  puts $fh_scr "  echo -e \$msg"
  puts $fh_scr "  exit 1"
  puts $fh_scr "\}"

  puts $fh_scr "\n# Create design library directory paths and define design library mappings in cds.lib"
  puts $fh_scr "create_lib_mappings()"
  puts $fh_scr "\{"
  set simulator "vcs"
  set libs [list]
  set design_libs [xcs_get_design_libs $a_sim_vars(l_design_files) 0 0 0]
  foreach lib $design_libs {
    if { $a_sim_vars(b_use_static_lib) && ([xcs_is_static_ip_lib $lib $l_ip_static_libs]) } {
      # continue if no local library found or continue if this library is precompiled (not local)
      if { ([llength $l_local_design_libraries] == 0) || (![xcs_is_local_ip_lib $lib $l_local_design_libraries]) } {
        continue
      }
    }
    if { {} == $lib } {
      continue;
    }
    if { {work} == $lib } {
      continue;
    }
    lappend libs [string tolower $lib]
  }

  set default_lib [string tolower $a_sim_vars(default_top_library)]
  if { [lsearch -exact $libs $default_lib] == -1 } {
    lappend libs $default_lib
  }

  puts $fh_scr "  libs=([join $libs " "])"
  puts $fh_scr "  file=\"synopsys_sim.setup\""
  set design_lib "${simulator}_lib"
  if { $a_sim_vars(b_absolute_path) } {
    set lib_dir_path [file normalize [string map {\\ /} [file join $a_sim_vars(s_launch_dir) ${design_lib}]]]
    puts $fh_scr "  dir=\"$lib_dir_path\"\n"
  } else {
    puts $fh_scr "  dir=\"${design_lib}\"\n"
  }
  puts $fh_scr "  if \[\[ -e \$file \]\]; then"
  puts $fh_scr "    rm -f \$file"
  puts $fh_scr "  fi"
  puts $fh_scr "  if \[\[ -e \$dir \]\]; then"
  puts $fh_scr "    rm -rf \$dir"
  puts $fh_scr "  fi"
  puts $fh_scr ""
  puts $fh_scr "  touch \$file"

  set compiled_lib_dir $a_sim_vars(compiled_library_dir)
  if { ![file exists $compiled_lib_dir] } {
    puts $fh_scr "  lib_map_path=\"<SPECIFY_COMPILED_LIB_PATH>\""
  } else {
    puts $fh_scr "  lib_map_path=\"$compiled_lib_dir\""
  }

  set file "synopsys_sim.setup"
  puts $fh_scr "  incl_ref=\"OTHERS=\$lib_map_path/$file\""
  set b_search_ref_lib_mod false
  [catch {set b_search_ref_lib_mod [get_param "simulator.searchMatchingModuleFromSetupFile"]} err]
  if { $b_search_ref_lib_mod } {
    puts $fh_scr "  echo \"LIBRARY_SCAN=TRUE\" >> \$file"
  }
  puts $fh_scr "  for (( i=0; i<\$\{#libs\[*\]\}; i++ )); do"
  puts $fh_scr "    lib=\"\$\{libs\[i\]\}\""
  puts $fh_scr "    lib_dir=\"\$dir/\$lib\""
  puts $fh_scr "    if \[\[ ! -e \$lib_dir \]\]; then"
  puts $fh_scr "      mkdir -p \$lib_dir"
  puts $fh_scr "      mapping=\"\$lib : \$dir/\$lib\""
  puts $fh_scr "      echo \$mapping >> \$file"
  puts $fh_scr "    fi"
  puts $fh_scr "  done"
  puts $fh_scr "  echo \$incl_ref >> \$file"
  puts $fh_scr "\}"
  puts $fh_scr ""
  puts $fh_scr "# Delete generated files from the previous run"
  puts $fh_scr "reset_run()"
  puts $fh_scr "\{"
  set file_list [list "64" "ucli.key" "AN.DB" "csrc" "$a_sim_vars(s_sim_top)_simv" "$a_sim_vars(s_sim_top)_simv.daidir" "inter.vpd" \
                      "vlogan.log" "vhdlan.log" "syscan.log" "compile.log" "elaborate.log" "simulate.log" \
                      "c.obj" ".vlogansetup.env" ".vlogansetup.args" ".vcs_lib_lock" "scirocco_command.log"] 
  set files [join $file_list " "]
  puts $fh_scr "  files_to_remove=($files)"
  puts $fh_scr "  for (( i=0; i<\$\{#files_to_remove\[*\]\}; i++ )); do"
  puts $fh_scr "    file=\"\$\{files_to_remove\[i\]\}\""
  puts $fh_scr "    if \[\[ -e \$file \]\]; then"
  puts $fh_scr "      rm -rf \$file"
  puts $fh_scr "    fi"
  puts $fh_scr "  done"
  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    puts $fh_scr "  if \[\[ -e $a_sim_vars(tmp_obj_dir) \]\]; then"
    puts $fh_scr "    rm -rf $a_sim_vars(tmp_obj_dir)"
    puts $fh_scr "  fi"
    puts $fh_scr "  mkdir $a_sim_vars(tmp_obj_dir)"
  }
  puts $fh_scr "\}"
  puts $fh_scr ""

  puts $fh_scr "setup()"
  puts $fh_scr "\{"
  puts $fh_scr "  case \$1 in"
  puts $fh_scr "    \"-reset_run\" )"
  puts $fh_scr "      reset_run"
  puts $fh_scr "      echo -e \"INFO: Simulation run files deleted.\\n\""
  puts $fh_scr "      exit 0"
  puts $fh_scr "    ;;"
  puts $fh_scr "    * )"
  puts $fh_scr "    ;;"
  puts $fh_scr "  esac\n"
  puts $fh_scr "  create_lib_mappings"
  puts $fh_scr "  touch hdl.var"
  puts $fh_scr "  echo -e \"INFO: Simulation setup files and library mappings created.\\n\""
  puts $fh_scr "  # Add any setup/initialization commands here:-"
  puts $fh_scr "  # <user specific commands>"
  puts $fh_scr "\}"
  puts $fh_scr ""

  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 4]
  set copyright_1 [lindex $version_txt 5]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  puts $fh_scr "# Script info"
  puts $fh_scr "echo -e \"setup.sh - Script generated by launch_simulation ($version-id)\\n\"\n"
  puts $fh_scr "# Check command line args"
  puts $fh_scr "if \[\[ \$# > 1 \]\]; then"
  puts $fh_scr "  echo -e \"ERROR: invalid number of arguments specified\\n\""
  puts $fh_scr "  usage"
  puts $fh_scr "fi\n"
  puts $fh_scr "if \[\[ (\$# == 1 ) && (\$1 != \"-reset_run\" && \$1 != \"-help\" && \$1 != \"-h\") \]\]; then"
  puts $fh_scr "  echo -e \"ERROR: unknown option specified '\$1' (type \"setup.sh -help\" for for more info)\""
  puts $fh_scr "  exit 1"
  puts $fh_scr "fi"
  puts $fh_scr ""
  puts $fh_scr "if \[\[ (\$1 == \"-help\" || \$1 == \"-h\") \]\]; then"
  puts $fh_scr "  usage"
  puts $fh_scr "fi\n"
  puts $fh_scr "# Launch script"
  puts $fh_scr "setup \$1"
  close $fh_scr

  xcs_make_file_executable $scr_file
}

proc usf_vcs_write_vhdl_compile_options { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars
 
  set tool "vhdlan"
  set arg_list [list]

  if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
    # donot pass os type
  } else {
    set arg_list [linsert $arg_list 0 "-full64"]
    #if { $a_sim_vars(b_int_systemc_mode) } {
    #  if { $a_sim_vars(b_system_sim_design) } {
    #    lappend arg_list ""
    #  }
    #}
  }
  if { $a_sim_vars(b_optimizeForRuntime) } {
    lappend arg_list "-l $a_sim_vars(tmp_log_file)"
  }

  set more_vhdlan_options [string trim [get_property "vcs.compile.vhdlan.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_vhdlan_options } {
    set arg_list [linsert $arg_list end "$more_vhdlan_options"]
  }

  puts $fh_scr "\n# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
}

proc usf_vcs_write_verilog_compile_options { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars

  set tool "vlogan"
  set arg_list [list]

  if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
    # donot pass os type
  } else {
    set arg_list [linsert $arg_list 0 "-full64"]
    if { $a_sim_vars(b_int_systemc_mode) } {
      if { $a_sim_vars(b_system_sim_design) } {
        lappend arg_list "-sysc"
      }
    }
  }
  if { $a_sim_vars(b_optimizeForRuntime) } {
    lappend arg_list "-l $a_sim_vars(tmp_log_file)"
  }

  set more_vlogan_options [string trim [get_property "vcs.compile.vlogan.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_vlogan_options } {
    set arg_list [linsert $arg_list end "$more_vlogan_options"]
  }

  puts $fh_scr "\n# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""

  if { $a_sim_vars(b_uvm) } {
    puts $fh_scr "\n# set UVM command line args"
    puts $fh_scr "uvm_opts=\"-ntb_opts uvm-1.2\""
  }

}

proc usf_vcs_write_systemc_compile_options { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars

  if { $a_sim_vars(b_optimizeForRuntime) } {
    set tool "g++"
    puts $fh_scr "\n# set ${tool} command line args for systemC shared library and systemC/HDL interface model"
    set arg_list [list "-fPIC -O3 -std=c++11 -g -DCOMMON_CPP_DLL -DSC_INCLUDE_DYNAMIC_PROCESSES"]
    if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
      set arg_list [linsert $arg_list 0 "-m32"]
    } else {
      set arg_list [linsert $arg_list 0 "-m64"]
    }
    puts $fh_scr "gpp_sysc_opts=\"[join $arg_list " "]\""

    set arg_list [list "-fPIC -O3 -std=c++11 -Wall -Wno-deprecated -DSC_INCLUDE_DYNAMIC_PROCESSES"]
    puts $fh_scr "gpp_sysc_hdl_opts=\"[join $arg_list " "]\""
  }

  set tool "syscan"
  set arg_list [list]
  if { {} != $a_sim_vars(sysc_ver) } {
    lappend arg_list "-sysc=$a_sim_vars(sysc_ver)"
  }
  lappend arg_list "-sysc=opt_if"
  lappend arg_list "-cpp \$\{gcc_path\}/g++"
  lappend arg_list "-V"

  set arg_list [linsert $arg_list end [list "-l" "${tool}.log"]]
  if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
    set arg_list [linsert $arg_list 0 ""]
  } else {
    set arg_list [linsert $arg_list 0 "-full64"]
  }

  set more_syscan_options [string trim [get_property "vcs.compile.syscan.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_syscan_options } {
    set arg_list [linsert $arg_list end "$more_syscan_options"]
  }

  puts $fh_scr "\n# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""

  # syscan gcc options
  set syscan_gcc_opts [list]
  set system_includes    "-I. "

  #append system_includes "-I\$\{PWD\}/c.obj/sysc/include "
  if { {} != $a_sim_vars(sysc_ver) } {
    append system_includes "-I\$\{VCS_HOME\}/include/systemc$a_sim_vars(sysc_ver) "
  }
  #append system_includes "-I\$\{VCS_HOME\}/lib "
  append system_includes "-I\$\{VCS_HOME\}/include "
  append system_includes "-I\$\{VCS_HOME\}/include/cosim/bf "
  append system_includes "-DVCSSYSTEMC=1 "
  append syscan_gcc_opts $system_includes

  #lappend syscan_gcc_opts "-std=c++11"
  #lappend syscan_gcc_opts "-fPIC"
  #lappend syscan_gcc_opts "-c"
  #lappend syscan_gcc_opts "-Wall"
  #lappend syscan_gcc_opts "-Wno-deprecated"
  #lappend syscan_gcc_opts "-DSC_INCLUDE_DYNAMIC_PROCESSES"
  
  variable l_system_sim_incl_dirs
  set incl_dirs [list]
  set uniq_dirs [list]
  foreach dir $l_system_sim_incl_dirs {
    if { [lsearch -exact $uniq_dirs $dir] == -1 } {
      lappend uniq_dirs $dir
      lappend incl_dirs "-I$dir"
    }
  }

  set incl_dir_str [join $incl_dirs " "]
  if { {} != $incl_dir_str } {
    append syscan_gcc_opts " $incl_dir_str"
  }

  # reference simmodel shared library include directories
  variable a_shared_library_path_coln
  set l_sim_model_incl_dirs [list]

  foreach {key value} [array get a_shared_library_path_coln] {
    set shared_lib_name $key
    set lib_path        $value
    set sim_model_incl_dir "$lib_path/include"
    if { [file exists $sim_model_incl_dir] } {
      if { !$a_sim_vars(b_absolute_path) } {
        # relative path
        set b_resolved 0
        set resolved_path [xcs_resolve_sim_model_dir "vcs" $sim_model_incl_dir $a_sim_vars(s_clibs_dir) $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved false ""]
        if { $b_resolved } {
          set sim_model_incl_dir $resolved_path
        } else {
          set sim_model_incl_dir "[xcs_get_relative_file_path $sim_model_incl_dir $a_sim_vars(s_launch_dir)]"
        }
      }
      lappend l_sim_model_incl_dirs $sim_model_incl_dir
    }
  }

  # simset include dir
  foreach incl_dir [get_property "systemc_include_dirs" $a_sim_vars(fs_obj)] {
    if { !$a_sim_vars(b_absolute_path) } {
      set incl_dir "[xcs_get_relative_file_path $incl_dir $a_sim_vars(s_launch_dir)]"
    }
    lappend l_sim_model_incl_dirs "$incl_dir"
  }

  if { [llength $l_sim_model_incl_dirs] > 0 } {
    # save system incl dirs
    variable l_systemc_incl_dirs
    set l_systemc_incl_dirs $l_sim_model_incl_dirs
    # append to gcc options
    foreach incl_dir $l_sim_model_incl_dirs {
      append syscan_gcc_opts " -I$incl_dir"
    }
  }
  puts $fh_scr "${tool}_gcc_opts=\"$syscan_gcc_opts\"\n"
}

proc usf_vcs_write_cpp_compile_options { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars

  set tool "g++"
  set arg_list [list "-c -fPIC -O3 -std=c++11 -DCOMMON_CPP_DLL"]
  if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
    set arg_list [linsert $arg_list 0 "-m32"]
  } else {
    set arg_list [linsert $arg_list 0 "-m64"]
  }
  set more_gplus_options [string trim [get_property "vcs.compile.g++.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_gplus_options } {
    set arg_list [linsert $arg_list end "$more_gplus_options"]
  }
  puts $fh_scr "\n# set ${tool} command line args"
  puts $fh_scr "gpp_opts=\"[join $arg_list " "]\""
}

proc usf_vcs_write_c_compile_options { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars

  set tool "gcc"
  set arg_list [list "-c -fPIC -O3"]
  if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
    set arg_list [linsert $arg_list 0 "-m32"]
  } else {
    set arg_list [linsert $arg_list 0 "-m64"]
  }
  set more_gcc_options [string trim [get_property "vcs.compile.gcc.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_gcc_options } {
    set arg_list [linsert $arg_list end "$more_gcc_options"]
  }
  puts $fh_scr "\n# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
}

proc usf_vcs_write_compile_order_files_opt { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars
  
  set log              {}
  set null             "2>/dev/null"
  set prev_lib         {}
  set prev_file_type   {}
  set redirect_cmd_str "2>&1 | tee"

  set n_file_group       1
  set n_vhd_file_group   0
  set n_ver_file_group   0
  set n_gplus_file_group 0
  set n_gcc_file_group   0
  set b_first          true

  #################
  # cpp/C - g++/gcc 
  #################
  if { $a_sim_vars(b_contain_cpp_sources) || $a_sim_vars(b_contain_c_sources) } {
    puts $fh_scr "echo \"Compiling C/CPP sources...\""
    foreach file $a_sim_vars(l_design_files) {
      set fargs       [split $file {|}]
      set type        [lindex $fargs 0]
      set file_type   [lindex $fargs 1]
      set lib         [lindex $fargs 2]
      set cmd_str     [lindex $fargs 3]
      set src_file    [lindex $fargs 4]
      set b_static_ip [lindex $fargs 5]
      if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
      set compiler [file tail [lindex [split $cmd_str " "] 0]]
      switch -exact -- $compiler {
        "g++"    -
        "gcc"    {
          set gcc_cmd "$cmd_str \\\n$src_file \\"
          if { {} != $a_sim_vars(s_tool_bin_path) } {
            set gcc_cmd "\$bin_path/$cmd_str \\\n$src_file \\"
          }
          puts $fh_scr "$gcc_cmd"
          set cstr "$a_sim_vars(clog)"
          if { $n_file_group > 1 } {set cstr "-a $a_sim_vars(clog)"}
          puts $fh_scr "$redirect_cmd_str $cstr\n"
          incr n_file_group
        }
      }
    }
  }

  ##################
  # systemc - g++/gcc 
  ##################
  if { $a_sim_vars(b_contain_systemc_sources) } {
    set log "syscan.log"
    if { $n_file_group > 1 } { puts $fh_scr "" }
    puts $fh_scr "echo \"Compiling SystemC sources...\""
    variable a_sim_cache_sysc_stub_files
    set sysc_stub_modules [list]
    set b_first true
    foreach file $a_sim_vars(l_design_files) {
      set fargs       [split $file {|}]
      set type        [lindex $fargs 0]
      set file_type   [lindex $fargs 1]
      set lib         [lindex $fargs 2]
      set cmd_str     [lindex $fargs 3]
      set src_file    [lindex $fargs 4]
      set b_static_ip [lindex $fargs 5]
      if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
      set compiler [file tail [lindex [split $cmd_str " "] 0]]
      switch -exact -- $compiler {
        "syscan" {
          if { $b_first } {
            set cmd_str "\$gcc_path/g++ \$gpp_sysc_opts \$syscan_gcc_opts "
            set gcc_cmd "$cmd_str \\\n$src_file \\"
            puts $fh_scr "$gcc_cmd"
            set b_first false
          } else {
            puts $fh_scr "$src_file \\"
          }
          set sysc_src_file [string trim $src_file {\"}]
          set module_name [file root [file tail $sysc_src_file]]
          if { [info exists a_sim_cache_sysc_stub_files($module_name)] } {
            lappend sysc_stub_modules "$module_name"
          }
        }
      }
    }
    incr n_file_group

    puts $fh_scr "-shared -o $a_sim_vars(syscan_libname) \\"
    set rdcs "$redirect_cmd_str"
    puts $fh_scr "$rdcs -a compile.log &"

    # TODO:
    #set cstr "$a_sim_vars(clog)"
    #if { $n_file_group > 1 } { set cstr "-a $a_sim_vars(clog)" }
    #append rdcs $cstr
    #append rdcs "; cat $a_sim_vars(tmp_log_file)"
    #set rdap " > $log $null"
    #append rdcs $rdap
    #puts $fh_scr "$rdcs &"

    puts $fh_scr "GCC_SYSC_PID=\$!"
    puts $fh_scr ""
  }

  #####################
  # uvm
  #####################
  if { $a_sim_vars(b_uvm) } {
    puts $fh_scr "echo \"Compiling UVM package sources...\""
    if { {} != $a_sim_vars(s_tool_bin_path) } {
      puts $fh_scr "\$bin_path/vlogan \$vlogan_opts \$uvm_opts \\"
    } else {
      puts $fh_scr "vlogan \$vlogan_opts \$uvm_opts \\"
    }
    puts $fh_scr "2>&1 | tee compile.log; cat .tmp_log > uvm.log 2>/dev/null\n"
  }

  #####################
  # RTL - vhdlan/vlogan
  #####################
  set rdap {}
  set b_first true

  puts $fh_scr "echo \"Compiling RTL sources...\""
  foreach file $a_sim_vars(l_design_files) {
    set fargs       [split $file {|}]
    set type        [lindex $fargs 0]
    set file_type   [lindex $fargs 1]
    set lib         [lindex $fargs 2]
    set cmd_str     [lindex $fargs 3]
    set src_file    [lindex $fargs 4]
    set b_static_ip [lindex $fargs 5]
    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
    set compiler [file tail [lindex [split $cmd_str " "] 0]]
    switch -exact -- $compiler {
      "vhdlan" -
      "vlogan" {
        # vlogan expects double back slash
        if { ([regexp { } $src_file] && [regexp -nocase {vlogan} $cmd_str]) } {
          set src_file [string trim $src_file "\""]
          regsub -all { } $src_file {\\\\ } src_file
        }

        if { $b_first } {
          set b_first false
          usf_vcs_set_initial_cmd $fh_scr $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
        } else {
          if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } { 
            puts $fh_scr "$src_file \\"
          } else {
            set rdcs "$redirect_cmd_str"
            set cstr "$a_sim_vars(clog)"
            if { $n_file_group > 1 } { set cstr "-a $a_sim_vars(clog)" }
            append rdcs " $cstr"
            append rdcs "; cat $a_sim_vars(tmp_log_file)"
            if { "vhdlan.log" == $log } { incr n_vhd_file_group;if { $n_vhd_file_group == 1 } { set rdap " > $log $null" } else { set rdap " >> $log $null" }}
            if { "vlogan.log" == $log } { incr n_ver_file_group;if { $n_ver_file_group == 1 } { set rdap " > $log $null" } else { set rdap " >> $log $null" }}
            append rdcs $rdap
            puts $fh_scr "$rdcs\n"
            incr n_file_group
            usf_vcs_set_initial_cmd $fh_scr $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
          }
        }
      }
    }
  }
  # last redirect command for vhdl/verilog file groups
  if { ("vhdlan.log" == $log) || ("vlogan.log" == $log) } {
    if { "vhdlan.log" == $log } { incr n_vhd_file_group   }
    if { "vlogan.log" == $log } { incr n_ver_file_group   }
    if { ($n_vhd_file_group > 1) || ($n_vhd_file_group > 1) } { incr n_file_group }
    set rdcs "$redirect_cmd_str"
    set cstr "$a_sim_vars(clog)"
    if { $n_file_group > 1 } { set cstr "-a $a_sim_vars(clog)" }
    append rdcs " $cstr";append rdcs "; cat $a_sim_vars(tmp_log_file)"
    # only 1 vhdl or verilog file to compile?
    if { [expr $n_vhd_file_group + $n_ver_file_group] == 1 } {
      set rdap " > $log $null"
    } else {
      if {"vhdlan.log" == $log} { if {$n_vhd_file_group == 1} {set rdap " > $log $null"} else {set rdap " >> $log $null"}}
      if {"vlogan.log" == $log} { if {$n_ver_file_group == 1} {set rdap " > $log $null"} else {set rdap " >> $log $null"}}
    }
    append rdcs $rdap
    puts $fh_scr "$rdcs"
  }

  ########################
  # syscan - compile stubs
  ########################
  if { $a_sim_vars(b_contain_systemc_sources) } {
    set gcc_cmd "syscan "
    if { {} != $a_sim_vars(s_tool_bin_path) } {
      set gcc_cmd "\$bin_path/syscan "
    }
    append gcc_cmd "\$syscan_opts -cflags \"\$gpp_sysc_hdl_opts \$syscan_gcc_opts\" -Mdir=c.obj \\"
 
    puts $fh_scr ""
    puts $fh_scr "echo \"Waiting for jobs to finish...\""
    puts $fh_scr "wait \$GCC_SYSC_PID"
    puts $fh_scr ""
    puts $fh_scr "echo \"Generating stub-wrappers...\""
    puts $fh_scr "$gcc_cmd"
    foreach stub_mod $sysc_stub_modules {
      puts $fh_scr "$a_sim_vars(syscan_libname):$stub_mod \\"
    }
    puts $fh_scr "$redirect_cmd_str -a compile.log"
  }
}

proc usf_vcs_write_compile_order_files_msg { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars
  
  set log              {}
  set null             "2>/dev/null"
  set prev_lib         {}
  set prev_file_type   {}
  set redirect_cmd_str "2>&1 | tee"
  set n_file_group     1
  set n_vhd_file_group 0
  set n_ver_file_group 0
  set b_first          true
  set b_last_src_rtl   true

  puts $fh_scr "# compile design source files"
  foreach file $a_sim_vars(l_design_files) {
    set fargs       [split $file {|}]
    set type        [lindex $fargs 0]
    set file_type   [lindex $fargs 1]
    set lib         [lindex $fargs 2]
    set cmd_str     [lindex $fargs 3]
    set src_file    [lindex $fargs 4]
    set b_static_ip [lindex $fargs 5]

    # if IP static file for pre-compile flow? continue
    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } {
      continue
    }

    # compiler name
    set compiler [file tail [lindex [split $cmd_str " "] 0]]
    switch -exact -- $compiler {
      "vhdlan" -
      "vlogan" {
        # vlogan expects double back slash
        if { ([regexp { } $src_file] && [regexp -nocase {vlogan} $cmd_str]) } {
          set src_file [string trim $src_file "\""]
          regsub -all { } $src_file {\\\\ } src_file
        }

        # first occurence (start of rtl command line)
        if { $b_first } {
          set b_first false
          usf_vcs_set_initial_cmd $fh_scr $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
        } else {
          if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } { 
            puts $fh_scr "$src_file \\"
          } else {
            set rdcs "$redirect_cmd_str"
            set cstr "$a_sim_vars(clog)"
            if { $n_file_group > 1 } { set cstr "-a $a_sim_vars(clog)" }
            append rdcs " $cstr"
            append rdcs "; cat $a_sim_vars(tmp_log_file)"
            if { "vhdlan.log" == $log } { incr n_vhd_file_group;if { $n_vhd_file_group == 1 } { set rdap " > $log $null" } else { set rdap " >> $log $null" }}
            if { "vlogan.log" == $log } { incr n_ver_file_group;if { $n_ver_file_group == 1 } { set rdap " > $log $null" } else { set rdap " >> $log $null" }}
            append rdcs $rdap
            puts $fh_scr "$rdcs\n"

            incr n_file_group
            usf_vcs_set_initial_cmd $fh_scr $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
          }
        }
      }
      "syscan" -
      "g++"    -
      "gcc"    {
        # previous compilation step re-direction (if any)
        if { ("vhdlan.log" == $log) || ("vlogan.log" == $log) } {
          set rdcs "$redirect_cmd_str"
          set cstr "$a_sim_vars(clog)"
          if { $n_file_group > 1 } { set cstr "-a $a_sim_vars(clog)" }
          append rdcs " $cstr"
          append rdcs "; cat $a_sim_vars(tmp_log_file)"
          if { "vhdlan.log" == $log } { incr n_vhd_file_group;if { $n_vhd_file_group == 1 } { set rdap " > $log $null" } else { set rdap " >> $log $null" }}
          if { "vlogan.log" == $log } { incr n_ver_file_group;if { $n_ver_file_group == 1 } { set rdap " > $log $null" } else { set rdap " >> $log $null" }}
          append rdcs $rdap
          puts $fh_scr "$rdcs\n"
        }

        if { "syscan" == $compiler } {
          variable a_sim_cache_sysc_stub_files
          # trim double-quotes
          set sysc_src_file [string trim $src_file {\"}]

          # get the module name and if corresponding stub exists, append the module name to source file
          set module_name [file root [file tail $sysc_src_file]]
          if { [info exists a_sim_cache_sysc_stub_files($module_name)] } {
            append sysc_src_file ":$module_name"

            # switch to speedup data propagation from systemC to RTL with the interface model
            set cmd_str [regsub {\-cflags} $cmd_str {-sysc=opt_if -cflags}]
          }
          set src_file "\"$sysc_src_file\""
        }
       
        # setup command line
        set gcc_cmd "$cmd_str \\\n$src_file \\"
        if { {} != $a_sim_vars(s_tool_bin_path) } {
          set gcc_cmd "\$bin_path/$cmd_str \\\n$src_file \\"
        }
        puts $fh_scr "$gcc_cmd"

        # setup redirection
        set cstr "$a_sim_vars(clog)"
        if { $n_file_group > 1 } {set cstr "-a $a_sim_vars(clog)"}
        puts $fh_scr "$redirect_cmd_str $cstr\n"
 
        incr n_file_group
        set log {}
        set b_last_src_rtl false

      }
      default {
        # not supported
      }
    }
  }

  # last redirect command for vhdl/verilog file groups
  if { $b_last_src_rtl } {
    if { "vhdlan.log" == $log } { incr n_vhd_file_group }
    if { "vlogan.log" == $log } { incr n_ver_file_group }
   
    # count number of file groups 
    if { ($n_vhd_file_group > 1) || ($n_vhd_file_group > 1) } { incr n_file_group }

    set rdcs "$redirect_cmd_str"
    set cstr "$a_sim_vars(clog)"
    if { $n_file_group > 1 } { set cstr "-a $a_sim_vars(clog)" }
    append rdcs " $cstr";append rdcs "; cat $a_sim_vars(tmp_log_file)"
  
    # only 1 vhdl or verilog file to compile?
    if { [expr $n_vhd_file_group + $n_ver_file_group] == 1 } {
      set rdap " > $log $null"
    } else {
      if {"vhdlan.log" == $log} { if {$n_vhd_file_group == 1} {set rdap " > $log $null"} else {set rdap " >> $log $null"}}
      if {"vlogan.log" == $log} { if {$n_ver_file_group == 1} {set rdap " > $log $null"} else {set rdap " >> $log $null"}}
    }
    append rdcs $rdap
    puts $fh_scr "$rdcs"
  }
}

proc usf_vcs_write_compile_order_files { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars
  
  puts $fh_scr "# compile design source files"
  
  set b_first true
  set prev_lib  {}
  set prev_file_type {}
  set redirect_cmd_str "2>&1 | tee"
  set log {}
  set b_redirect false
  set b_appended false
  set b_add_redirect true
  set b_add_once true
  set b_first_vhdlan true
  set b_first_vlogan true
  set n_vhd_count 1
  set n_ver_count 1

  foreach file $a_sim_vars(l_design_files) {
    set fargs       [split $file {|}]
    set type        [lindex $fargs 0]
    set file_type   [lindex $fargs 1]
    set lib         [lindex $fargs 2]
    set cmd_str     [lindex $fargs 3]
    set src_file    [lindex $fargs 4]
    set b_static_ip [lindex $fargs 5]

    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }

    set compiler [file tail [lindex [split $cmd_str " "] 0]]

    if { ("syscan" == $compiler) || ("g++" == $compiler) || ("gcc" == $compiler) } {

      if { (!$b_redirect) || (!$b_appended) } {
        if { $b_add_once } {
          puts $fh_scr "$redirect_cmd_str -a $log"
          set b_add_redirect false
          set b_add_once false
        }
      }

      if { "syscan" == $compiler } {
        puts $fh_scr ""
        variable a_sim_cache_sysc_stub_files
        set sysc_src_file [string trim $src_file {\"}]
        set module_name [file root [file tail $sysc_src_file]]
        if { [info exists a_sim_cache_sysc_stub_files($module_name)] } {
          append sysc_src_file ":$module_name"
          # switch to speedup data propagation from systemC to RTL with the interface model
          set cmd_str [regsub {\-cflags} $cmd_str {-sysc=opt_if -cflags}]
        }
        set sysc_src_file "\"$sysc_src_file\""
        if { {} != $a_sim_vars(s_tool_bin_path) } {
          puts $fh_scr "\$bin_path/$cmd_str \\\n$sysc_src_file"
        } else {
          puts $fh_scr "$cmd_str \\\n$sysc_src_file"
        }
      } else {
        if { ("g++" == $compiler) || ("gcc" == $compiler) } {
          puts $fh_scr ""
          if { {} != $a_sim_vars(s_gcc_bin_path) } {
            puts $fh_scr "\$gcc_path/$cmd_str \\\n$src_file"
          } else {
            puts $fh_scr "$cmd_str \\\n$src_file"
          }
        }
      }
    } else {
      # vlogan expects double back slash
      if { ([regexp { } $src_file] && [regexp -nocase {vlogan} $cmd_str]) } {
        set src_file [string trim $src_file "\""]
        regsub -all { } $src_file {\\\\ } src_file
      }
  
      set b_redirect false
      set b_appended false
  
      if { $b_first } {
        set b_first false
        usf_vcs_set_initial_cmd $fh_scr $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
      } else {
        if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } { 
          puts $fh_scr "$src_file \\"
          set b_redirect true
        } else {
          set rdcs "$redirect_cmd_str $log"
          if { "vhdlan.log" == $log } {
            incr n_vhd_count
            if { $b_first_vhdlan } {
              set b_first_vhdlan false
            } else {
              set rdcs "$redirect_cmd_str -a $log"
            }
          }
          if { "vlogan.log" == $log } {
            incr n_ver_count
            if { $b_first_vlogan } {
              set b_first_vlogan false
            } else {
              set rdcs "$redirect_cmd_str -a $log"
            }
          }
          puts $fh_scr "$rdcs\n"
          usf_vcs_set_initial_cmd $fh_scr $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
          set b_appended true
        }
      }
    }
  }

  if { $b_add_redirect } {
    if { (!$b_redirect) || (!$b_appended) } {
      set rdcs "$redirect_cmd_str -a $log"
      if { ("vhdlan.log" == $log) && ($n_vhd_count == 1) } {
        set rdcs "$redirect_cmd_str $log"
      }
      if { ("vlogan.log" == $log) && ($n_ver_count == 1) } {
        set rdcs "$redirect_cmd_str $log"
      }
      puts $fh_scr "$rdcs\n"
    }
  }
}

proc usf_vcs_write_glbl_compile { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars
  
  set null "2>/dev/null"

  set glbl_file "glbl.v"
  if { $a_sim_vars(b_absolute_path) } {
    set glbl_file [file normalize [file join $a_sim_vars(s_launch_dir) $glbl_file]]
  }

  # compile glbl file
  set b_load_glbl [get_property "vcs.compile.load_glbl" $a_sim_vars(fs_obj)]
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
  if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
    if { [xcs_compile_glbl_file "vcs" $b_load_glbl $a_sim_vars(b_int_compile_glbl) $a_sim_vars(l_design_files) $a_sim_vars(s_simset) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $a_sim_vars(b_force_compile_glbl) } {
      set work_lib_sw {}
      if { {work} != $top_lib } {
        set work_lib_sw "-work $top_lib "
      }
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
        set file_str "${work_lib_sw}\"${glbl_file}\""
        puts $fh_scr "\n# compile glbl module"
        if { $a_sim_vars(b_optimizeForRuntime) } {
          if { {} != $a_sim_vars(s_tool_bin_path) } {
            puts $fh_scr "\$bin_path/vlogan \$vlogan_opts +v2k $file_str \\\n2>&1 | tee -a $a_sim_vars(clog); cat $a_sim_vars(tmp_log_file) >> vlogan.log $null"
          } else {
            puts $fh_scr "vlogan \$vlogan_opts +v2k $file_str \\\n2>&1 | tee -a $a_sim_vars(clog); cat $a_sim_vars(tmp_log_file) >> vlogan.log $null"
          }
        } else {
          if { {} != $a_sim_vars(s_tool_bin_path) } {
            puts $fh_scr "\$bin_path/vlogan \$vlogan_opts +v2k $file_str 2>&1 | tee -a vlogan.log"
          } else {
            puts $fh_scr "vlogan \$vlogan_opts +v2k $file_str 2>&1 | tee -a vlogan.log"
          }
        }
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
          if { [xcs_compile_glbl_file "vcs" $b_load_glbl $a_sim_vars(b_int_compile_glbl) $a_sim_vars(l_design_files) $a_sim_vars(s_simset) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || ($a_sim_vars(b_force_compile_glbl)) } {
            set work_lib_sw {}
            if { {work} != $top_lib } {
              set work_lib_sw "-work $top_lib "
            }
            xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
            set file_str "${work_lib_sw}\"${glbl_file}\""
            puts $fh_scr "\n# compile glbl module"
            if { $a_sim_vars(b_optimizeForRuntime) } {
              if { {} != $a_sim_vars(s_tool_bin_path) } {
                puts $fh_scr "\$bin_path/vlogan \$vlogan_opts +v2k $file_str \\\n2>&1 | tee -a $a_sim_vars(clog); cat $a_sim_vars(tmp_log_file) >> vlogan.log $null"
              } else {
                puts $fh_scr "vlogan \$vlogan_opts +v2k $file_str \\\n2>&1 | tee -a $a_sim_vars(clog); cat $a_sim_vars(tmp_log_file) >> vlogan.log $null"
              }
            } else {
              if { {} != $a_sim_vars(s_tool_bin_path) } {
                puts $fh_scr "\$bin_path/vlogan \$vlogan_opts +v2k $file_str 2>&1 | tee -a vlogan.log"
              } else {
                puts $fh_scr "vlogan \$vlogan_opts +v2k $file_str 2>&1 | tee -a vlogan.log"
              }
            }
          }
        }
      }
    }
  }
}

proc usf_vcs_init_env { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set b_init_env [get_property -quiet "init_simulator_env" $a_sim_vars(fs_obj)] 
  if { $b_init_env } {
    set gnu_pkg_dir [file dirname [file dirname $a_sim_vars(s_gcc_bin_path)]]
    puts $fh_scr "\n# source VCS GNU package script (for setting GCC, binutils and LD_LIBRARY_PATH)"
    puts $fh_scr "if \[\[ -z \$VG_GNU_PACKAGE \]\]; then"
    puts $fh_scr "  export VG_GNU_PACKAGE=\"$gnu_pkg_dir\""
    puts $fh_scr "fi\n"
    puts $fh_scr "echo \"VG_GNU_PACKAGE=\$VG_GNU_PACKAGE\""
    puts $fh_scr "source \$VG_GNU_PACKAGE/source_me_gcc920_64.sh"
  }
}

}
