######################################################################
#
# sim.tcl
#
# Simulation script for the 'Cadence Xcelium Parallel Simulator'
#
# Script created on 04/17/2017 by Raj Klair (Xilinx, Inc.)
#
# 2017.3 - v1.0 (rev 1)
#  * initial version
#
######################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::xcelium {
  namespace export setup
}

namespace eval ::tclapp::xilinx::xcelium {
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
  usf_xcelium_setup_args $args

  # set NoC binding type
  if { $a_sim_vars(b_int_system_design) } {
    xcs_bind_legacy_noc
  }

  # perform initial simulation tasks
  if { [usf_xcelium_setup_simulation] } {
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

  send_msg_id USF-Xcelium-002 INFO "Xcelium::Compile design"
  usf_xcelium_write_compile_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  usf_launch_script "xcelium" $step
}

proc elaborate { args } {
  # Summary: run the elaborate step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  send_msg_id USF-Xcelium-003 INFO "Xcelium::Elaborate design"
  usf_xcelium_write_elaborate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  usf_launch_script "xcelium" $step
}

proc simulate { args } {
  # Summary: run the simulate step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  variable a_sim_vars

  send_msg_id USF-Xcelium-004 INFO "Xcelium::Simulate design"
  usf_xcelium_write_simulate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  usf_launch_script "xcelium" $step

  if { $a_sim_vars(b_scripts_only) } {
    set fh 0
    set file [file normalize [file join $a_sim_vars(s_launch_dir) "simulate.log"]]
    if {[catch {open $file w} fh]} {
      send_msg_id USF-Xcelium-016 ERROR "Failed to open file to write ($file)\n"
    } else {
      puts $fh "INFO: Scripts generated successfully. Please see the 'Tcl Console' window for details."
      close $fh
    }
  }
}
}

#
# Xcelium simulation flow
#
namespace eval ::tclapp::xilinx::xcelium {

proc usf_xcelium_setup_simulation { args } {
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
        send_msg_id USF-Xcelium-013 ERROR "Failed to create the directory ($a_sim_vars(s_simlib_dir)): $error_msg\n"
        return 1
      }
    }
  }

  usf_set_simulator_path "xcelium"

  if { $a_sim_vars(b_int_system_design) } {
    usf_set_systemc_library_path "xcelium"
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

  # find/copy cds.lib file into run dir
  set a_sim_vars(s_clibs_dir) [usf_xcelium_verify_compiled_lib]

  # verify GCC version from CLIBs (make sure it matches, else throw critical warning)
  xcs_verify_clibs_gcc_version $a_sim_vars(s_clibs_dir) $a_sim_vars(s_gcc_version) "xcelium"

  # set ABI=0 for 6.3 version (not supported for this release)
  if { [regexp -nocase {^6.3} $a_sim_vars(s_gcc_version)] } {
    set a_sim_vars(b_ABI) 1
  }

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
    xcs_fetch_lib_info "xcelium" $a_sim_vars(s_clibs_dir) $a_sim_vars(b_int_sm_lib_ref_debug)
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
  if { $a_sim_vars(b_contain_systemc_sources) || $a_sim_vars(b_contain_cpp_sources) || $a_sim_vars(b_contain_c_sources) } {
    set a_sim_vars(b_system_sim_design) 1
  }

  if { $a_sim_vars(b_int_systemc_mode) } {
    # systemC headers
    set a_sim_vars(b_contain_systemc_headers) [xcs_contains_systemc_headers]

    # find shared library paths from all IPs
    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      if { [xcs_contains_C_files] } {
        xcs_find_shared_lib_paths "xcelium" $a_sim_vars(s_gcc_version) $a_sim_vars(s_clibs_dir) $a_sim_vars(custom_sm_lib_dir) $a_sim_vars(b_int_sm_lib_ref_debug) a_sim_vars(sp_cpt_dir) a_sim_vars(sp_ext_dir)
      }
    }
  }

  if { $a_sim_vars(b_compile_simmodels) } {
    # get the design simmodel compile order
    set a_sim_vars(l_simmodel_compile_order) [xcs_get_simmodel_compile_order]
  }

  # create setup file
  usf_xcelium_write_setup_files

  return 0
}

proc usf_xcelium_setup_args { args } {
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
  # [-install_path <arg>]: Custom Xcelium installation directory path
  # [-batch]: Execute batch flow simulation run (non-gui)
  # [-exec]: Execute script (applicable with -step switch only)
  # [-run_dir <arg>]: Simulation run directory
  # [-int_os_type]: OS type (32 or 64) (internal use)
  # [-int_setup_sim_vars]: Initialize sim vars only (internal use)
  # [-int_debug_mode]: Debug mode (internal use)
  # [-int_ide_gui]: Vivado launch mode is gui (internal use)
  # [-int_halt_script]: Halt and generate error if simulator tools not found (internal use)
  # [-int_systemc_mode]: SystemC mode (internal use)
  # [-int_dpi_mode]: DPI mode (internal use)
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

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: xilinxtclstore, xcelium
  
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
      "-int_dpi_mode"             { set a_sim_vars(b_int_dpi_mode)             1                 }
      "-int_system_design"        { set a_sim_vars(b_int_system_design)        1                 }
      "-int_compile_glbl"         { set a_sim_vars(b_int_compile_glbl)         1                 }
      "-int_sm_lib_ref_debug"     { set a_sim_vars(b_int_sm_lib_ref_debug)     1                 }
      "-int_csim_compile_order"   { set a_sim_vars(b_int_csim_compile_order)   1                 }
      "-int_export_source_files"  { set a_sim_vars(b_int_export_source_files)  1                 }
      "-int_en_vitis_hw_emu_mode" { set a_sim_vars(b_int_en_vitis_hw_emu_mode) 1                 }
      "-int_perf_analysis"        { set a_sim_vars(b_int_perf_analysis)        1                 }
      "-int_setup_sim_vars"       { set a_sim_vars(b_int_setup_sim_vars)       1                 }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id USF-Xcelium-005 WARNING "Unknown option '$option' specified (ignored)\n"
        }
      }
    }
  }
}

proc usf_xcelium_verify_compiled_lib {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set cds_filename "cds.lib"
  set compiled_lib_dir {}
  send_msg_id USF-Xcelium-006 INFO "Finding pre-compiled libraries...\n"
  # check property value
  set dir [get_property "compxlib.xcelium_compiled_library_dir" [current_project]]
  set cds_file [file normalize [file join $dir $cds_filename]]
  if { [file exists $cds_file] } {
    set compiled_lib_dir $dir
  }
  # 1. check -lib_map_path
  # is -lib_map_path specified and point to valid location?
  if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
    set a_sim_vars(s_lib_map_path) [file normalize $a_sim_vars(s_lib_map_path)]
    if { [file exists $a_sim_vars(s_lib_map_path)] } {
      set compiled_lib_dir $a_sim_vars(s_lib_map_path)
    } else {
      send_msg_id USF-Xcelium-010 WARNING "The path specified with the -lib_map_path does not exist:'$a_sim_vars(s_lib_map_path)'\n"
    }
  }
  # 1a. find cds.lib from current working directory
  if { {} == $compiled_lib_dir } {
    set dir [file normalize [pwd]]
    set cds_file [file normalize [file join $dir $cds_filename]]
    if { [file exists $cds_file] } {
      set compiled_lib_dir $dir
    }
  }
  # return if found, else warning
  if { {} != $compiled_lib_dir } {
   send_msg_id USF-Xcelium-007 INFO "Using cds.lib from '$compiled_lib_dir/cds.lib'\n"
   set a_sim_vars(compiled_library_dir) $compiled_lib_dir
   return $compiled_lib_dir
  }
  if { $a_sim_vars(b_scripts_only) } {
    send_msg_id USF-Xcelium-018 WARNING "The pre-compiled simulation library could not be located. Please make sure to reference this library before executing the scripts.\n"
  } else {
    send_msg_id USF-Xcelium-008 "CRITICAL WARNING" "Failed to find the pre-compiled simulation library!\n"
  }
  send_msg_id USF-Xcelium-009 INFO \
     "Please set the 'COMPXLIB.XCELIUM_COMPILED_LIBRARY_DIR' project property to the directory where Xilinx simulation libraries are compiled for Xcelium.\n"

  return $compiled_lib_dir
}

proc usf_xcelium_write_setup_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars

  variable l_ip_static_libs
  variable l_local_design_libraries

  set netlist_mode [get_property "nl.mode" $a_sim_vars(fs_obj)]

  #
  # cds.lib
  #
  set filename "cds.lib"
  set file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id USF-Xcelium-010 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  set lib_map_path $a_sim_vars(compiled_library_dir)
  if { {} == $lib_map_path } {
    set lib_map_path "?"
  }
  puts $fh "INCLUDE $lib_map_path/$filename"

  set b_bind_dpi_c false
  [catch {set b_bind_dpi_c [get_param project.bindGTDPICModel]} err]
  set ip_obj [xcs_find_ip "gt_quad_base"]
  # if bind_dpi is false, then set ip_obj to null (donot trigger code below)
  if { !$b_bind_dpi_c } {
    set ip_ob {}
  }

  #
  # create following empty dummy simprim mapping for functional and behavioral simulation in cds.lib
  #
  #  "DEFINE simprims_ver xcelium_lib/simprims_ver"
  #
  # so xmelab can bind the pre-compiled components from unisim library only and do not collide with
  # similar components that are compiled in simprim (this is a workaround for xcelium only since it
  # fails to bind on finding two instances of compiled library for the same component (one in unisim
  # and second in simprim)
  #
  # xmelab: *E,MULVLG: Possible bindings for instance of design unit 'DFE_NL_FIR' in 'xdfe_nlf_v1_0_0.xdfe_nlf_v1_0_0_top:xilinx' are:
  #     simprims_ver.DFE_NL_FIR:module
  #     unisims_ver.DFE_NL_FIR:module
  #
  # With the dummy binding, xmelab will find the expected component from unisim library only.
  #
  # NOTE: dummy binding is not required for timing (xmelab will bind the components from simprims)
  #
  set b_add_dummy_binding 0
  if { ({post_synth_sim} == $a_sim_vars(s_simulation_flow)) || ({post_impl_sim} == $a_sim_vars(s_simulation_flow)) } {
    if { {funcsim} == $netlist_mode } {
      set b_add_dummy_binding 1
    }
  } else {
    if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
      set b_add_dummy_binding 1
    }
  }

  if { ({} != $ip_obj) || $b_add_dummy_binding } {
    puts $fh "DEFINE simprims_ver xcelium_lib/simprims_ver"
    set simprim_dir "$a_sim_vars(s_launch_dir)/xcelium_lib/simprims_ver"
    if { ![file exists $simprim_dir] } {
      [catch {file mkdir $simprim_dir} error_msg]
    }
  }
  set libs [list]
  set design_libs [xcs_get_design_libs $a_sim_vars(l_design_files) 0 0 0]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend libs [string tolower $lib]
  }
  set dir_name "xcelium_lib"
  set b_default_lib false
  set default_lib $a_sim_vars(default_top_library)
  foreach lib_name $libs {
    if { $a_sim_vars(b_use_static_lib) && ([xcs_is_static_ip_lib $lib_name $l_ip_static_libs]) } {
      # continue if no local library found or if this library is precompiled (not local)
      if { ([llength $l_local_design_libraries] == 0) || (![xcs_is_local_ip_lib $lib_name $l_local_design_libraries]) } {
        continue
      }
    }
    set lib_dir [file join $dir_name $lib_name]
    set lib_dir_path [file normalize [string map {\\ /} [file join $a_sim_vars(s_launch_dir) $lib_dir]]]
    if { ! [file exists $lib_dir_path] } {
      if {[catch {file mkdir $lib_dir_path} error_msg] } {
        send_msg_id USF-Xcelium-011 ERROR "Failed to create the directory ($lib_dir_path): $error_msg\n"
        return 1
      }
    }
    if { $a_sim_vars(b_absolute_path) } {
      set lib_dir $lib_dir_path
    }
    puts $fh "DEFINE $lib_name $lib_dir"
    if { $default_lib == $lib_name } {
      set b_default_lib true
    }
  }
  if { !$b_default_lib } {
    set lib_dir [file join $dir_name $default_lib]
    set lib_dir_path [file normalize [string map {\\ /} [file join $a_sim_vars(s_launch_dir) $lib_dir]]]
    if { ! [file exists $lib_dir_path] } {
      if {[catch {file mkdir $lib_dir_path} error_msg] } {
        send_msg_id USF-Xcelium-011 ERROR "Failed to create the directory ($lib_dir_path): $error_msg\n"
        return 1
      }
    }
    if { $a_sim_vars(b_absolute_path) } {
      set lib_dir $lib_dir_path
    }
    puts $fh "DEFINE $default_lib $lib_dir"
  }

  if { $a_sim_vars(b_use_static_lib) } {
    usf_xcelium_map_pre_compiled_libs $fh
  }
 
  close $fh

  #
  # hdl.var
  #
  set filename "hdl.var"
  set file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id USF-Xcelium-012 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  close $fh

  # create setup file
  usf_xcelium_create_setup_script
}

proc usf_xcelium_set_initial_cmd { fh_scr cmd_str src_file file_type lib prev_file_type_arg prev_lib_arg log_arg } {
  # Summary: Print compiler command line and store previous file type and library information
  # Argument Usage:
  # Return Value:
  # None

  variable a_sim_vars

  upvar $prev_file_type_arg prev_file_type
  upvar $prev_lib_arg  prev_lib
  upvar $log_arg log

  if { {} != $a_sim_vars(s_tool_bin_path) } {
    puts $fh_scr "\$bin_path/$cmd_str \\"
  } else {
    puts $fh_scr "$cmd_str \\"
  }
  puts $fh_scr "$src_file \\"

  set prev_file_type $file_type
  set prev_lib  $lib

  if { [regexp -nocase {vhdl} $file_type] } {
    set log "xmvhdl.log"
  } elseif { [regexp -nocase {verilog} $file_type] } {
    set log "xmvlog.log"
  }
}

proc usf_xcelium_write_compile_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  # step exec mode?
  if { $a_sim_vars(b_exec_step) } {
    return 0
  }

  set filename "compile";append filename [xcs_get_script_extn "xcelium"]
  set scr_file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh_scr 0

  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-Xcelium-013 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  puts $fh_scr "[xcs_get_shell_env]"
  xcs_write_script_header $fh_scr "compile" "xcelium"
  xcs_write_version_id $fh_scr "xcelium"
  if { {} != $a_sim_vars(s_tool_bin_path) } {
    if { $a_sim_vars(b_optimizeForRuntime) } {
      puts $fh_scr ""
      xcs_write_log_file_cleanup $fh_scr $a_sim_vars(run_logs_compile)
    }
    set b_set_shell_var_exit false
    [catch {set b_set_shell_var_exit [get_param "project.setShellVarsForSimulationScriptExit"]} err]
    if { $b_set_shell_var_exit } {
      puts $fh_scr "\n# catch pipeline exit status"
      xcs_write_pipe_exit $fh_scr
    }
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"[xcs_replace_with_var $a_sim_vars(s_tool_bin_path) "SIM_VER" "xcelium"]\""
 
    if { $a_sim_vars(b_int_systemc_mode) } {
      if { $a_sim_vars(b_system_sim_design) } {
        # set gcc path
        puts $fh_scr "gcc_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_gcc_bin_path) "SIM_VER" "xcelium"] "GCC_VER" "xcelium"]\"\n"
      }
      # set system sim library paths
      if { $a_sim_vars(b_system_sim_design) } { 
        puts $fh_scr "# set system shared library paths"
        puts $fh_scr "xv_cxl_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_clibs_dir) "SIM_VER" "xcelium"] "GCC_VER" "xcelium"]\""
        puts $fh_scr "xv_cpt_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_cpt_dir) "SIM_VER" "xcelium"] "GCC_VER" "xcelium"]\""
        puts $fh_scr "xv_ext_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_ext_dir) "SIM_VER" "xcelium"] "GCC_VER" "xcelium"]\""
        puts $fh_scr "xv_boost_lib_path=\"$a_sim_vars(s_boost_dir)\""
      }
    }
  }

  # write tcl pre hook
  set tcl_pre_hook [get_property "xcelium.compile.tcl.pre" $a_sim_vars(fs_obj)]
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
    if { [usf_xcelium_check_if_glbl_file_needs_compilation] } {
      set b_contain_verilog_srcs 1
    }
  }

  set b_contain_vhdl_srcs    [xcs_contains_vhdl $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]

  if { $b_contain_vhdl_srcs } {
    usf_xcelium_write_vhdl_compile_options $fh_scr
  }

  if { $b_contain_verilog_srcs } {
    usf_xcelium_write_verilog_compile_options $fh_scr
  }

  if { $a_sim_vars(b_int_systemc_mode) } {
    # xmsc (systemC)
    if { $a_sim_vars(b_contain_systemc_sources) } {
      usf_xcelium_write_systemc_compile_options $fh_scr
    }
    # g++ (c++)
    if { $a_sim_vars(b_contain_cpp_sources) } {
      usf_xcelium_write_cpp_compile_options $fh_scr
    }
    # gcc (c)
    if { $a_sim_vars(b_contain_c_sources) } {
      usf_xcelium_write_c_compile_options $fh_scr
    }
  }

  # add tcl pre hook
  xcs_write_tcl_pre_hook $fh_scr $tcl_pre_hook $a_sim_vars(s_compile_pre_tcl_wrapper) $a_sim_vars(s_launch_dir)
 
  # write compile order files
  if { $a_sim_vars(b_optimizeForRuntime) } {
    if { $a_sim_vars(b_compile_simmodels) } {
      usf_compile_simmodel_sources $fh_scr
    }
    usf_xcelium_write_compile_order_files_wait $fh_scr
  } else {
    usf_xcelium_write_compile_order_files $fh_scr
  }

  xcs_add_hard_block_wrapper $fh_scr "xcelium" "" $a_sim_vars(s_launch_dir)

  # write glbl compile
  usf_xcelium_write_glbl_compile $fh_scr

  if { $a_sim_vars(b_optimizeForRuntime) } {
    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) && $a_sim_vars(b_contain_systemc_sources) } {
      puts $fh_scr "\necho \"Waiting for jobs to finish...\""
      puts $fh_scr "wait \$XMSC_SYSC_PID"
      puts $fh_scr "echo \"No pending jobs, compilation finished.\""
    }
  }

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

proc usf_xcelium_check_if_glbl_file_needs_compilation {} {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars

  #
  # same logic used in usf_xcelium_write_glbl_compile to determine glbl top
  #
  if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
    set b_load_glbl [get_property "xcelium.compile.load_glbl" [get_filesets $a_sim_vars(s_simset)]]

    if { [xcs_compile_glbl_file "xcelium" $b_load_glbl $a_sim_vars(b_int_compile_glbl) $a_sim_vars(l_design_files) $a_sim_vars(s_simset) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $a_sim_vars(b_force_compile_glbl) } {

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
    if { (([xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] && ({VHDL} == $target_lang)) ||
          ($a_sim_vars(b_int_compile_glbl)) || ($a_sim_vars(b_force_compile_glbl))) } {

      # force no compile glbl
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        if { ({timing} == $a_sim_vars(s_type)) } {
          # This is not supported, netlist will be verilog always
        } else {
          #******************************
          # yes, glbl.v is being compiled
          #******************************
          return true
        }
      }
    }
  }
  #***************************
  # no, glbl.v is not compiled
  #***************************
  return false
}

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

  set simulator "xcelium"
  set data_dir [rdi::get_data_dir -quiet -datafile "systemc/simlibs"]
  set cpt_dir  [xcs_get_simmodel_dir "xcelium" $a_sim_vars(s_gcc_version) "cpt"]

  # is pure-rtl sources for system simulation (selected_sim_model = rtl), don't need to compile the systemC/CPP/C sim-models
  if { [llength $a_sim_vars(l_simmodel_compile_order)] == 0 } {
    if { [file exists $a_sim_vars(s_simlib_dir)] } {
      # delete <run-dir>/simlibs dir (not required)
      [catch {file delete -force $a_sim_vars(s_simlib_dir)} error_msg]
    }
    return
  }

  # update mappings in cds.lib
  usf_add_simmodel_mappings

  # find simmodel info from dat file and update do file
  foreach lib_name $a_sim_vars(l_simmodel_compile_order) {
    set lib_path [xcs_find_lib_path_for_simmodel $lib_name]
    set fh_dat 0
    set dat_file "$lib_path/.cxl.sim_info.dat"
    if {[catch {open $dat_file r} fh_dat]} {
      send_msg_id USF-Xcelium-016 WARNING "Failed to open file to read ($dat_file)\n"
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

    #send_msg_id USF-Xcelium-107 STATUS "Generating compilation commands for '$lib_name'\n"

    # create local lib dir
    set simlib_dir "$a_sim_vars(s_simlib_dir)/$lib_name"
    if { ![file exists $simlib_dir] } {
      if { [catch {file mkdir $simlib_dir} error_msg] } {
        send_msg_id USF-Xcelium-013 ERROR "Failed to create the directory ($simlib_dir): $error_msg\n"
        return 1
      }
    }

    # copy simmodel sources locally
    if { $a_sim_vars(b_int_export_source_files) } {
      if { {} == $simmodel_name } { send_msg_id USF-Xcelium-107 WARNING "Empty tag '$simmodel_name'!\n" }
      if { {} == $library_name  } { send_msg_id USF-Xcelium-107 WARNING "Empty tag '$library_name'!\n"  }

      set src_sim_model_dir "$data_dir/systemc/simlibs/$simmodel_name/$library_name/src"
      set dst_dir "$a_sim_vars(s_launch_dir)/simlibs/$library_name"
      if { [file exists $src_sim_model_dir] } {
        [catch {file delete -force $dst_dir/src} error_msg]
        if { [catch {file copy -force $src_sim_model_dir $dst_dir} error_msg] } {
          [catch {send_msg_id USF-Xcelium-108 ERROR "Failed to copy file '$src_sim_model_dir' to '$dst_dir': $error_msg\n"} err]
        } else {
          #puts "copied '$src_sim_model_dir' to run dir:'$a_sim_vars(s_launch_dir)/simlibs'\n"
          }
      } else {
        [catch {send_msg_id USF-Xcelium-108 ERROR "File '$src_sim_model_dir' does not exist\n"} err]
      }
    }

    # copy include dir
    set simlib_incl_dir "$lib_path/include"
    set target_dir      "$a_sim_vars(s_simlib_dir)/$lib_name"
    set target_incl_dir "$target_dir/include"
    if { ![file exists $target_incl_dir] } {
      if { [catch {file copy -force $simlib_incl_dir $target_dir} error_msg] } {
        [catch {send_msg_id USF-Xcelium-010 ERROR "Failed to copy file '$simlib_incl_dir' to '$target_dir': $error_msg\n"} err]
      }
    }

    # simmodel file_info.dat data
    set library_type            {}
    set output_format           {}
    set gplus_compile_flags     [list]
    set gplus_compile_flags_xcl [list]
    set gplus_compile_opt_flags [list]
    set gplus_compile_dbg_flags [list]
    set gcc_compile_flags       [list]
    set gcc_compile_opt_flags   [list]
    set gcc_compile_dbg_flags   [list]
    set ldflags                 [list]
    set ldflags_xcl             {}
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
    set systemc_incl_dirs_xcl   [list]
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
      if { "<SYSTEMC_INCLUDE_DIRS_XCELIUM>" == $tag } { set systemc_incl_dirs_xcl [split $value {,}] }
      if { "<CPP_INCLUDE_DIRS>"           == $tag } { set cpp_incl_dirs           [split $value {,}] }
      if { "<C_INCLUDE_DIRS>"             == $tag } { set c_incl_dirs             [split $value {,}] }
      if { "<OSCI_INCLUDE_DIRS>"          == $tag } { set osci_incl_dirs          [split $value {,}] }
      if { "<G++_COMPILE_FLAGS>"          == $tag } { set gplus_compile_flags     [split $value {,}] }
      if { "<G++_COMPILE_FLAGS_XCELIUM>"  == $tag } { set gplus_compile_flags_xcl [split $value {,}] }
      if { "<G++_COMPILE_OPTIMIZE_FLAGS>" == $tag } { set gplus_compile_opt_flags [split $value {,}] }
      if { "<G++_COMPILE_DEBUG_FLAGS>"    == $tag } { set gplus_compile_dbg_flags [split $value {,}] }
      if { "<GCC_COMPILE_FLAGS>"          == $tag } { set gcc_compile_flags       [split $value {,}] }
      if { "<GCC_COMPILE_OPTIMIZE_FLAGS>" == $tag } { set gcc_compile_opt_flags   [split $value {,}] }
      if { "<GCC_COMPILE_DEBUG_FLAGS>"    == $tag } { set gcc_compile_dbg_flags   [split $value {,}] }
      if { "<LDFLAGS>"                    == $tag } { set ldflags                 [split $value {,}] }
      if { "<LDFLAGS_XCELIUM>"            == $tag } { set ldflags_xcl             $value }
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
              [catch {send_msg_id USF-Xcelium-108 ERROR "Failed to copy file '$src_sim_model_dir' to '$dst_dir': $error_msg\n"} err]
            } else {
              puts "copied '$src_sim_model_dir' to run dir:'$dst_dir'\n"
            }
          } else {
            catch {send_msg_id USF-Xcelium-108 ERROR "File '$src_sim_model_dir' does not exist\n"} err]
          }
        }
      }
    }

    set obj_dir "$a_sim_vars(s_launch_dir)/xcelium_lib/$lib_name"
    if { ![file exists $obj_dir] } {
      if { [catch {file mkdir $obj_dir} error_msg] } {
        send_msg_id USF-Xcelium-013 ERROR "Failed to create the directory ($obj_dir): $error_msg\n"
        return 1
      }
    }
    
    #
    # write systemC/CPP/C command line
    #
    if { [llength $sysc_files] > 0 } {
      set compiler "xmsc"
      puts $fh "# compile '$lib_name' model sources"
      foreach src_file $sysc_files {
        set file_name [file root [file tail $src_file]]

        set args [list] 
        lappend args "-64bit"
        lappend args "-compiler $a_sim_vars(s_gcc_bin_path)/g++"
        lappend args "-noedg"
        lappend args "-cFlags \""
        lappend args "-DSC_INCLUDE_DYNAMIC_PROCESSES"

        # <SYSTEMC_INCLUDE_DIRS>
        foreach incl_dir $systemc_incl_dirs {
          if { [regexp {xv_ext_lib_path\/protobuf\/include} $incl_dir] } {
            set incl_dir [regsub -all {protobuf} $incl_dir {utils/protobuf}]
          }
          lappend args "-I$incl_dir"
        }

        # <SYSTEMC_INCLUDE_DIRS_XCELIUM>
        foreach incl_dir $systemc_incl_dirs_xcl {
          if { [regexp {xv_ext_lib_path\/protobuf\/include} $incl_dir] } {
            set incl_dir [regsub -all {protobuf} $incl_dir {utils/protobuf}]
          }
          lappend args "-I$incl_dir"
        }

        # <CPP_COMPILE_OPTION>
        lappend args $cpp_compile_option

        # <G++_COMPILE_FLAGS>
        foreach opt $gplus_compile_flags     { lappend args $opt }
        foreach opt $gplus_compile_flags_xcl { lappend args $opt }
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

        lappend args "-c"
        lappend args "-o xcelium_lib/${lib_name}/${file_name}.o"
        lappend args "\""
        lappend args "-work ${lib_name}"
        lappend args $src_file
        
        set cmd_str [join $args " "]
        puts $fh "$a_sim_vars(s_tool_bin_path)/xmsc $cmd_str\n"
      }
     
      #
      # LINK (g++)
      #
      set compiler "g++"
      set args [list]
      lappend args "-m64"
      foreach src_file $sysc_files {
        set file_name [file root [file tail $src_file]]
        #set obj_file "xcelium_lib/$lib_name/${file_name}.o"
        set obj_file "xcelium_lib/${lib_name}/${file_name}.o"
        lappend args $obj_file
      }
      set sys_link_path ""
      set gnu_subdir "systemc/lib/64bit/gnu"
      set check_sys_link_path "$a_sim_vars(s_tool_bin_path)/../../$gnu_subdir"
      if { ([file exists $check_sys_link_path]) && ([file isdirectory $check_sys_link_path]) } {
        set sys_link_path "\$bin_path/../../$gnu_subdir"
      } else {
        set check_sys_link_path "$a_sim_vars(s_tool_bin_path)/../$gnu_subdir"
        if { ([file exists $check_sys_link_path]) && ([file isdirectory $check_sys_link_path]) } {
          set sys_link_path "\$bin_path/../$gnu_subdir"
        }
      }

      lappend args "$sys_link_path/libscBootstrap_sh.so"
      lappend args "$sys_link_path/libxmscCoroutines_sh.so"
      lappend args "$sys_link_path/libsystemc_sh.so"
      
      # <LDFLAGS>
      if { [llength $ldflags] > 0 } { foreach opt $ldflags { lappend args $opt } }

      # <LDFLAGS_XCELIUM>
      if { {} != $ldflags_xcl } {
        lappend args $ldflags_xcl
      }
     
      if { [llength $ldflags_lin64] > 0 } { foreach opt $ldflags_lin64 { lappend args $opt } }
      
      # acd ldflags
      if { {} != $gplus_ldflags_option } { lappend args $gplus_ldflags_option }

      # <LDLIBS>
      if { [llength $ldlibs] > 0 } { foreach opt $ldlibs { lappend args $opt } }
 
      lappend args "-shared"
      lappend args "-o"
      lappend args "./xcelium_lib/$lib_name/lib${lib_name}.so"
     
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
        if { $a_sim_vars(b_ABI) } {
          lappend args "-D_GLIBCXX_USE_CXX11_ABI=0"
        }

        # <CPP_INCLUDE_DIRS>
        if { [llength $cpp_incl_dirs] > 0 } {
          foreach incl_dir $cpp_incl_dirs {
            # $xv_ext_lib_path/protobuf/include -> $xv_ext_lib_path/utils/protobuf/include
            if { [regexp {xv_ext_lib_path\/protobuf\/include} $incl_dir] } {
              set incl_dir [regsub -all {protobuf} $incl_dir {utils/protobuf}]
            }
            lappend args "-I $incl_dir"
          }
        }

        # <CPP_COMPILE_OPTION>
        lappend args $cpp_compile_option 

        # <G++_COMPILE_FLAGS>
        foreach opt $gplus_compile_flags     { lappend args $opt }
        foreach opt $gplus_compile_flags_xcl { lappend args $opt }
        if { $b_dbg } {
          foreach opt $gplus_compile_dbg_flags { lappend args $opt }
        } else {
          foreach opt $gplus_compile_opt_flags { lappend args $opt }
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
        lappend args "xcelium_lib/$lib_name/${file_name}.o"
        
        set cmd_str [join $args " "]
        puts $fh "$a_sim_vars(s_gcc_bin_path)/$compiler $cmd_str\n"
      }

      #
      # LINK (g++)
      #
      set args [list]
      foreach src_file $cpp_files {
        set file_name [file root [file tail $src_file]]
        set obj_file "xcelium_lib/$lib_name/${file_name}.o"
        lappend args $obj_file
      }
      lappend args "-m64"
      lappend args "-shared"
      lappend args "-o"
      lappend args "xcelium_lib/$lib_name/lib${lib_name}.so"

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
        if { $a_sim_vars(b_ABI) } {
          lappend args "-D_GLIBCXX_USE_CXX11_ABI=0"
        }

        # <C_INCLUDE_DIRS>
        if { [llength $c_incl_dirs] > 0 } {
          foreach incl_dir $c_incl_dirs {
            # $xv_ext_lib_path/protobuf/include -> $xv_ext_lib_path/utils/protobuf/include
            if { [regexp {xv_ext_lib_path\/protobuf\/include} $incl_dir] } {
              set incl_dir [regsub -all {protobuf} $incl_dir {utils/protobuf}]
            }
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
        lappend args "xcelium_lib/$lib_name/${file_name}.o"
        
        set cmd_str [join $args " "]
        puts $fh "$a_sim_vars(s_gcc_bin_path)/$compiler $cmd_str\n"
      }

      #
      # LINK (gcc)
      #
      set args [list]
      foreach src_file $c_files {
        set file_name [file root [file tail $src_file]]
        set obj_file "xcelium_lib/$lib_name/${file_name}.o"
        lappend args $obj_file
      }
      lappend args "-m64"
      lappend args "-shared"
      lappend args "-o"
      lappend args "xcelium_lib/$lib_name/lib${lib_name}.so"

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
  set cds_file "$a_sim_vars(s_launch_dir)/cds.lib"
  if { ![file exists $cds_file] } {
    return
  }

  # read cds.lib contents
  set fh 0
  if {[catch {open $cds_file r} fh]} {
    send_msg_id USF-Xcelium-011 ERROR "Failed to open file to read ($cds_file)\n"
    return 1
  }
  set data [split [read $fh] "\n"]
  close $fh

  # get current_mappings
  set l_current_mappings  [list]
  set l_current_libraries [list]
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } {
      continue;
    }
    if { [regexp {^INCLUDE} $line] } { continue; }
    lappend l_current_mappings $line

    set library [string trim [lindex [split $line " "] 1]]
    lappend l_current_libraries $library
  }
  
  # find new simmodel mappings to add
  set l_new_mappings [list]
  foreach library $a_sim_vars(l_simmodel_compile_order) {
    if { [lsearch -exact $l_current_mappings $library] == -1 } {
      set mapping "DEFINE $library $a_sim_vars(compiled_design_lib)/$library"
      lappend l_new_mappings $mapping
    }
  }

  # delete cds.lib
  [catch {file delete -force $cds_file} error_msg]

  # create fresh updated copy
  set fh 0
  if {[catch {open $cds_file w} fh]} {
    send_msg_id USF-Xcelium-011 ERROR "Failed to open file to write ($cds_file)\n"
    return
  }
  put $fh "INCLUDE $a_sim_vars(compiled_library_dir)/cds.lib"
  foreach line $l_current_mappings { puts $fh $line }
  foreach line $l_new_mappings     { puts $fh $line }
  close $fh
}

proc usf_xcelium_write_elaborate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable a_sim_cache_all_ip_obj

  # step exec mode?
  if { $a_sim_vars(b_exec_step) } {
    return 0
  }

  variable l_compiled_libraries

  set netlist_mode [get_property "nl.mode" $a_sim_vars(fs_obj)]

  set filename "elaborate";append filename [xcs_get_script_extn "xcelium"]
  set scr_file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh_scr 0

  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-Xcelium-014 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }
 
  variable a_shared_library_path_coln
  puts $fh_scr "[xcs_get_shell_env]"
  xcs_write_script_header $fh_scr "elaborate" "xcelium"
  xcs_write_version_id $fh_scr "xcelium"
  if { {} != $a_sim_vars(s_tool_bin_path) } {
    set b_set_shell_var_exit false
    [catch {set b_set_shell_var_exit [get_param "project.setShellVarsForSimulationScriptExit"]} err]
    if { $b_set_shell_var_exit } {
      puts $fh_scr "\n# catch pipeline exit status"
      xcs_write_pipe_exit $fh_scr
    }
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"[xcs_replace_with_var $a_sim_vars(s_tool_bin_path) "SIM_VER" "xcelium"]\""

    if { $a_sim_vars(b_int_systemc_mode) } {
      if { $a_sim_vars(b_system_sim_design) } {
        # set gcc path
        puts $fh_scr "gcc_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(s_gcc_bin_path) "SIM_VER" "xcelium"] "GCC_VER" "xcelium"]\""
        puts $fh_scr "sys_path=\"[xcs_replace_with_var $a_sim_vars(s_sys_link_path) "SIM_VER" "xcelium"]\""

        # bind user specified libraries
        set l_link_sysc_libs [get_property "xcelium.elaborate.link.sysc" $a_sim_vars(fs_obj)]
        set l_link_c_libs    [get_property "xcelium.elaborate.link.c"    $a_sim_vars(fs_obj)]

        xcs_write_library_search_order $fh_scr "xcelium" "elaborate" $a_sim_vars(b_compile_simmodels) $a_sim_vars(s_launch_dir) $a_sim_vars(s_gcc_version) $a_sim_vars(s_clibs_dir) $a_sim_vars(sp_cpt_dir) l_link_sysc_libs l_link_c_libs
      }
    }
    puts $fh_scr ""
  }

  set tool "xmelab"
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
  set arg_list [list "-relax"]
  set access_mode "rwc"
  if { $a_sim_vars(b_int_perf_analysis) } {
    set access_mode "r"
  }
 
  # enable signal visibility
  set b_acc [get_property -quiet xcelium.elaborate.acc $a_sim_vars(fs_obj)]
  if { $b_acc } {
    lappend arg_list "-access +$access_mode"
  }

  lappend arg_list "-namemap_mixgen"

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
    set arg_list [linsert $arg_list end "-pulse_r $path_delay -pulse_int_r $int_delay -pulse_e $path_delay -pulse_int_e $int_delay"]
  }

  set arg_list [linsert $arg_list end "-messages -logfile elaborate.log"]

  if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
    # donot pass os type
  } else {
     set arg_list [linsert $arg_list 0 "-64bit"]
  }

  if { [get_property "xcelium.elaborate.update" $a_sim_vars(fs_obj)] } {
    set arg_list [linsert $arg_list end "-update"]
  }

  puts $fh_scr "# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  set design_libs [xcs_get_design_libs $a_sim_vars(l_design_files) 0 1 1]

  set arg_list [list]
  # add simulation libraries

  # add user design libraries
  foreach lib $design_libs {
    if {[string length $lib] == 0} {
      continue;
    }
    lappend arg_list "-libname"
    lappend arg_list "[string tolower $lib]"
  }

  # add xilinx vip library
  if { [get_param "project.usePreCompiledXilinxVIPLibForSim"] } {
    if { [xcs_design_contain_sv_ip] } {
      lappend arg_list "-libname"
      lappend arg_list "xilinx_vip"
    }
  }

  # post* simulation
  if { ({post_synth_sim} == $a_sim_vars(s_simulation_flow)) || ({post_impl_sim} == $a_sim_vars(s_simulation_flow)) } {
    if { [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || ({Verilog} == $a_sim_vars(s_target_lang)) } {
      if { {timesim} == $netlist_mode } {
        set arg_list [linsert $arg_list end "-libname" "simprims_ver"]
      } else {
        set arg_list [linsert $arg_list end "-libname" "unisims_ver"]
      }
    }
  }

  # behavioral simulation
  set b_compile_unifast 0
  set simulator_language [string tolower [get_property "simulator_language" [current_project]]]
  if { ([get_param "simulation.addUnifastLibraryForVhdl"]) && ({vhdl} == $simulator_language) } {
    set b_compile_unifast [get_property "unifast" $a_sim_vars(fs_obj)]
  }

  if { ([xcs_contains_vhdl $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $a_sim_vars(s_simulation_flow)) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-libname" "unifast"]
    }
  }

  set b_compile_unifast [get_property "unifast" $a_sim_vars(fs_obj)]
  if { ([xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $a_sim_vars(s_simulation_flow)) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-libname" "unifast_ver"]
    }
    set arg_list [linsert $arg_list end "-libname" "unisims_ver"]
    set arg_list [linsert $arg_list end "-libname" "unimacro_ver"]
  }

  # add secureip
  set arg_list [linsert $arg_list end "-libname" "secureip"]

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
    # pass xpm library reference for behavioral simulation only
    if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
      set arg_list [linsert $arg_list end "-libname" "xpm"]
    }
  }

  # add ap lib
  variable l_hard_blocks
  if { [llength $l_hard_blocks] > 0 } {
    lappend arg_list "-libname aph"
  }

  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
        variable a_shared_library_path_coln
        foreach {key value} [array get a_shared_library_path_coln] {
          set shared_lib_name $key
          set shared_lib_name [file root $shared_lib_name]
          set shared_lib_name [string trimleft $shared_lib_name "lib"]
          if { [regexp "^protobuf" $shared_lib_name] } { continue; }
          # filter protected
          if { [regexp "^noc_v" $shared_lib_name] } { continue; }
          if { [regexp "^noc2_v" $shared_lib_name] } { continue; }
          set arg_list [linsert $arg_list end "-libname" $shared_lib_name]
        }
      }
    }
  }

  puts $fh_scr "\n# set design libraries"
  puts $fh_scr "design_libs_elab=\"[join $arg_list " "]\"\n"

  set b_link_user_libraries 0
  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      puts $fh_scr "# set gcc objects"
      usf_xcelium_write_gcc_objs $fh_scr

      puts $fh_scr "# link simulator system libraries"

      set sys_libs [list]
      lappend sys_libs "\$sys_path/libscBootstrap_sh.so"
      lappend sys_libs "\$sys_path/libxmscCoroutines_sh.so"
      lappend sys_libs "\$sys_path/libsystemc_sh.so"
      lappend sys_libs "\$sys_path/libxmscCoSimXM_sh.so"
      lappend sys_libs "\$sys_path/libxmsctlm2_sh.so"
      lappend sys_libs "\$sys_path/libscBootstrap_sh.so"
   
      set sys_libs_str [join $sys_libs " "]

      puts $fh_scr "sys_libs=\"$sys_libs_str\"\n"

      # bind user specified libraries
      set l_link_sysc_libs [get_property "xcelium.elaborate.link.sysc" $a_sim_vars(fs_obj)]
      set l_link_c_libs    [get_property "xcelium.elaborate.link.c"    $a_sim_vars(fs_obj)]
      if { ([llength $l_link_sysc_libs] > 0) || ([llength $l_link_c_libs] > 0) } {
        set b_link_user_libraries 1
        set user_libs [list]
        puts $fh_scr "# link user specified libraries"
        foreach lib $l_link_sysc_libs { lappend user_libs $lib }
        foreach lib $l_link_c_libs    { lappend user_libs $lib }
        set user_libs_str [join $user_libs " "]
        puts $fh_scr "user_libs=\"$user_libs_str\"\n"
      }
    }
  }

  set tool_path_val "\$bin_path/$tool"
  if { {} == $a_sim_vars(s_tool_bin_path) } {
    set tool_path_val "$tool"
  }
  set arg_list [list ${tool_path_val} "\$${tool}_opts"]

  set obj $a_sim_vars(sp_tcl_obj)
  if { [xcs_is_fileset $obj] } {
    set vhdl_generics [list]
    set vhdl_generics [get_property "generic" [get_filesets $obj]]
    if { [llength $vhdl_generics] > 0 } {
      xcs_append_generics "xcelium" $vhdl_generics arg_list
    }
  }

  # more options
  set more_elab_options [string trim [get_property "xcelium.elaborate.xmelab.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_elab_options } {
    set arg_list [linsert $arg_list end "$more_elab_options"]
  }

  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      # workaround for xmelab performance issue
      lappend arg_list "-work xil_defaultlib"
      #
      if { $a_sim_vars(b_int_dpi_mode) } {
        lappend arg_list "-loadsc libdpi"
      } else {
        lappend arg_list "-loadsc $a_sim_vars(s_sim_top)_sc"
      }
    }
  }

  lappend arg_list "\$design_libs_elab"
  lappend arg_list "${top_lib}.$a_sim_vars(s_sim_top)"

  variable l_hard_blocks
  foreach hb $l_hard_blocks {
    set hb_wrapper "xil_defaultlib.${hb}_sim_wrapper"
    lappend arg_list "$hb_wrapper"
  }

  # logical noc top
  set lnoc_top [get_property -quiet "logical_noc_top" $a_sim_vars(fs_obj)]
  if { {} != $lnoc_top } {
    set lib [get_property -quiet "logical_noc_top_lib" $a_sim_vars(fs_obj)]
    lappend arg_list "${lib}.${lnoc_top}"
  }

  set top_level_inst_names {}
  usf_add_glbl_top_instance arg_list $top_level_inst_names

  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      # set gcc path
      if { {} != $a_sim_vars(s_gcc_bin_path) } {
        puts $fh_scr "# generate shared object"
        set link_arg_list [list "\$gcc_path/g++"]
        lappend link_arg_list "-m64 -Wl,-G -shared -o"
        if { $a_sim_vars(b_int_dpi_mode) } {
          lappend link_arg_list "libdpi.so"
        } else {
          lappend link_arg_list "$a_sim_vars(s_sim_top)_sc.so"
        }
        lappend link_arg_list "\$gcc_objs"

        # bind protected libs
        set cpt_dir [rdi::get_data_dir -quiet -datafile "simmodels/xcelium"]
        set sm_cpt_dir [xcs_get_simmodel_dir "xcelium" $a_sim_vars(s_gcc_version) "cpt"]
        foreach {key value} [array get a_shared_library_path_coln] {
          set name [file tail $value]
          set lib_dir "$cpt_dir/$sm_cpt_dir/$name"
          if { ([regexp "^noc_v" $name]) ||
               ([regexp "^noc2_v" $name]) } {
            set name [string trimleft $key "lib"]
            set name [string trimright $name ".so"]
            lappend link_arg_list "-L\$xv_cpt_lib_path/$name -l$name"
          }

          if { ([regexp "^aie_cluster" $name]) || ([regexp "^aie_xtlm" $name]) } {
            set model_ver [rdi::get_aie_config_type]
            set lib_name "${model_ver}_cluster_v1_0_0"
            if { {aie} == $model_ver } {
              set lib_dir "$cpt_dir/$sm_cpt_dir/$lib_name"
            } else {
              set lib_dir "$cpt_dir/$sm_cpt_dir/$model_ver"
            }
            #lappend link_arg_list "-L$lib_dir -l$lib_name"
          }
        }

        # bind sim-models
        set l_sm_lib_paths [list]
        foreach {library lib_dir} [array get a_shared_library_path_coln] {
          set name [file tail $lib_dir]
          if { ([regexp "^noc_v" $name])        ||
               ([regexp "^noc2_v" $name])       ||
               ([regexp "^aie_cluster" $name]) } {
            continue;
          }

          # don't bind static protobuf (simmodel will bind these during compilation)
          if { ("libprotobuf.a" == $library) } {
            continue;
          }
          
          set sm_lib_dir [file normalize $lib_dir]
          set sm_lib_dir [regsub -all {[\[\]]} $sm_lib_dir {/}]
          set lib_name [string trimleft $library "lib"]
          set lib_name [string trimright $lib_name ".so"]

          if { $a_sim_vars(b_compile_simmodels) } {
            set lib_type [file tail [file dirname $lib_dir]]
            if { ("protobuf" == $lib_name) || ("protected" == $lib_type) } {
              # skip
            } else {
              set sm_lib_dir "xcelium_lib/$lib_name"
            }
          }

          lappend link_arg_list "-L\$xv_cxl_lib_path/$name -l$name"
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
              foreach obj_file_name [xcs_get_pre_compiled_shared_objects "xcelium" $a_sim_vars(s_clibs_dir) $vlnv_name] {
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
          lappend link_arg_list "$shared_lib_obj"
        }
        if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
          puts "------------------------------------------------------------------------------------------------------------------------------------"
        }


        lappend link_arg_list "\$sys_libs"
        if { $b_link_user_libraries } {
          lappend link_arg_list "\$user_libs"
        }
        set link_args [join $link_arg_list " "]
        puts $fh_scr "$link_args\n"
      }
    }
  }

  puts $fh_scr "# run elaboration"
  set cmd_str [join $arg_list " "]
  puts $fh_scr "$cmd_str"
  close $fh_scr
}

proc usf_xcelium_write_gcc_objs { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { [get_param "project.appendObjectDescriptorForXmsc"] } {
    set objs_arg [list]
    set uniq_objs [list]

    variable a_design_c_files_coln
    foreach {key value} [array get a_design_c_files_coln] {
      set c_file     $key
      set file_type  $value
      set file_name [file tail [file root $c_file]]
      if { ($a_sim_vars(b_optimizeForRuntime) && ("SystemC" == $file_type)) } {
        append file_name "_0"
      }
      append file_name ".o"
      if { [lsearch -exact $uniq_objs $file_name] == -1 } {
        if { ($a_sim_vars(b_optimizeForRuntime) && ("SystemC" == $file_type)) } {
          lappend objs_arg "$a_sim_vars(tmp_obj_dir)/xmsc_obj/$file_name"
        } else {
          lappend objs_arg "$a_sim_vars(tmp_obj_dir)/$file_name"
        }
        lappend uniq_objs $file_name
      }
    }
    set objs_arg_str [join $objs_arg " "]
    puts $fh_scr "gcc_objs=\"$objs_arg_str\"\n"
  } else {
    puts $fh_scr "obj_coln=\$(find c.obj/xmsc_obj -iname \"*.o\" 2>/dev/null)"
    puts $fh_scr "gcc_objs=\${obj_coln\[*\]// /,}\n"
  }
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

  set b_load_glbl [get_property "xcelium.compile.load_glbl" $a_sim_vars(fs_obj)]
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

proc usf_xcelium_write_simulate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  # step exec mode?
  if { $a_sim_vars(b_exec_step) } {
    return 0
  }

  set filename "simulate";append filename [xcs_get_script_extn "xcelium"]
  set scr_file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh_scr 0

  if { [catch {open $scr_file w} fh_scr] } {
    send_msg_id USF-Xcelium-016 ERROR "Failed to open file to write ($file)\n"
    return 1
  }

  puts $fh_scr "[xcs_get_shell_env]"
  xcs_write_script_header $fh_scr "simulate" "xcelium"
  xcs_write_version_id $fh_scr "xcelium"
  if { {} != $a_sim_vars(s_tool_bin_path) } {
    set b_set_shell_var_exit false
    [catch {set b_set_shell_var_exit [get_param "project.setShellVarsForSimulationScriptExit"]} err]
    if { $b_set_shell_var_exit } {
      puts $fh_scr "\n# catch pipeline exit status"
      xcs_write_pipe_exit $fh_scr
    }
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"[xcs_replace_with_var $a_sim_vars(s_tool_bin_path) "SIM_VER" "xcelium"]\""

    if { $a_sim_vars(b_int_systemc_mode) } {
      if { $a_sim_vars(b_system_sim_design) } {
        puts $fh_scr "sys_path=\"[xcs_replace_with_var $a_sim_vars(s_sys_link_path) "SIM_VER" "xcelium"]\""
        if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
          xcs_write_launch_mode_for_vitis $fh_scr "xcelium"
        }

        # bind user specified libraries
        set l_link_sysc_libs [get_property "xcelium.elaborate.link.sysc" $a_sim_vars(fs_obj)]
        set l_link_c_libs    [get_property "xcelium.elaborate.link.c"    $a_sim_vars(fs_obj)]

        xcs_write_library_search_order $fh_scr "xcelium" "simulate" $a_sim_vars(b_compile_simmodels) $a_sim_vars(s_launch_dir) $a_sim_vars(s_gcc_version) $a_sim_vars(s_clibs_dir) $a_sim_vars(sp_cpt_dir) l_link_sysc_libs l_link_c_libs
      }
    }
    puts $fh_scr ""
  }

  set do_filename "$a_sim_vars(s_sim_top)_simulate.do"

  usf_create_do_file "xcelium" $do_filename
	
  set tool "xmsim"
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
  set arg_list [list "-logfile" "simulate.log"]
  if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
    # donot pass os type
  } else {
    set arg_list [linsert $arg_list 0 "-64bit"]
  }

  if { [get_property "xcelium.simulate.update" $a_sim_vars(fs_obj)] } {
    set arg_list [linsert $arg_list end "-update"]
  }

  set more_sim_options [string trim [get_property "xcelium.simulate.xmsim.more_options" $a_sim_vars(fs_obj)]]
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

  puts $fh_scr "# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  puts $fh_scr ""

  set tool_path_val "\$bin_path/$tool"
  if { {} == $a_sim_vars(s_tool_bin_path) } {
    set tool_path_val "$tool"
  }
  set arg_list [list "${tool_path_val}" "\$${tool}_opts"]

  set b_bind_dpi_c false
  [catch {set b_bind_dpi_c [get_param project.bindGTDPICModel]} err]
  set ip_obj [xcs_find_ip "gt_quad_base"]
  if { {} != $ip_obj } {
    if { $b_bind_dpi_c } {
      lappend arg_list "-sv_root \"$a_sim_vars(s_clibs_dir)/secureip\""
      lappend arg_list "-sv_lib libgtye5_quad.so"
    }
  }
  lappend arg_list "${top_lib}.$a_sim_vars(s_sim_top)"
  lappend arg_list "-input"
  lappend arg_list "$do_filename"
  set cmd_str [join $arg_list " "]

  puts $fh_scr "# run simulation"
  puts $fh_scr "$cmd_str"
  close $fh_scr
}

proc usf_xcelium_map_pre_compiled_libs { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { !$a_sim_vars(b_use_static_lib) } {
    return
  }

  set lib_path [get_property "sim.ipstatic.compiled_library_dir" [current_project]]
  set ini_file [file join $lib_path "cds.lib"]
  if { ![file exists $ini_file] } {
    return
  }

  set fh_ini 0
  if { [catch {open $ini_file r} fh_ini] } {
    send_msg_id USF-Xcelium-099 WARNING "Failed to open file for read ($ini_file)\n"
    return
  }
  set ini_data [read $fh_ini]
  close $fh_ini

  set ini_data [split $ini_data "\n"]
  set b_lib_start false
  foreach line $ini_data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    if { [regexp "^DEFINE secureip" $line] } {
      set b_lib_start true
    }
    if { $b_lib_start } {
      if { [regexp "^DEFINE secureip" $line] ||
           [regexp "^DEFINE unisim" $line] ||
           [regexp "^DEFINE simprim" $line] ||
           [regexp "^DEFINE unifast" $line] ||
           [regexp "^DEFINE unimacro" $line] } {
        continue
      }
      if { ([regexp {^#} $line]) || ([regexp {^--} $line]) } {
        set b_lib_start false
        continue
      }
      if { [regexp "^DEFINE" $line] } {
        puts $fh "$line"
      }
    }
  }
}

proc usf_xcelium_create_setup_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  variable l_ip_static_libs
  variable l_local_design_libraries

  set filename "setup";append filename [xcs_get_script_extn "xcelium"]
  set scr_file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-Xcelium-017 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  puts $fh_scr "[xcs_get_shell_env]"
  xcs_write_script_header $fh_scr "setup" "xcelium"
  xcs_write_version_id $fh_scr "xcelium"

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
  set simulator "xcelium"
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
    lappend libs [string tolower $lib]
  }

  set default_lib [string tolower $a_sim_vars(default_top_library)]
  if { [lsearch -exact $libs $default_lib] == -1 } {
    lappend libs $default_lib
  }

  puts $fh_scr "  libs=([join $libs " "])"
  puts $fh_scr "  file=\"cds.lib\""
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

  set file "cds.lib"
  puts $fh_scr "  incl_ref=\"INCLUDE \$lib_map_path/$file\""
  puts $fh_scr "  echo \$incl_ref >> \$file"
  puts $fh_scr "  for (( i=0; i<\$\{#libs\[*\]\}; i++ )); do"
  puts $fh_scr "    lib=\"\$\{libs\[i\]\}\""
  puts $fh_scr "    lib_dir=\"\$dir/\$lib\""
  puts $fh_scr "    if \[\[ ! -e \$lib_dir \]\]; then"
  puts $fh_scr "      mkdir -p \$lib_dir"
  puts $fh_scr "      mapping=\"DEFINE \$lib \$dir/\$lib\""
  puts $fh_scr "      echo \$mapping >> \$file"
  puts $fh_scr "    fi"
  puts $fh_scr "  done"
  puts $fh_scr "\}"
  puts $fh_scr ""
  puts $fh_scr "# Delete generated files from the previous run"
  puts $fh_scr "reset_run()"
  puts $fh_scr "\{"
  set file_list [list "xmsim.key" "xmvlog.log" "xmvhdl.log" "compile.log" "elaborate.log" "waves.shm"]
  set files [join $file_list " "]
  puts $fh_scr "  files_to_remove=($files)"
  puts $fh_scr "  for (( i=0; i<\$\{#files_to_remove\[*\]\}; i++ )); do"
  puts $fh_scr "    file=\"\$\{files_to_remove\[i\]\}\""
  puts $fh_scr "    if \[\[ -e \$file \]\]; then"
  puts $fh_scr "      rm -rf \$file"
  puts $fh_scr "    fi"
  puts $fh_scr "  done"
  puts $fh_scr "  rm -rf ./$a_sim_vars(tmp_obj_dir)"
  puts $fh_scr "  mkdir $a_sim_vars(tmp_obj_dir)"
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

proc usf_xcelium_write_vhdl_compile_options { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set tool "xmvhdl"
  set arg_list [list "-messages"]

  if { [get_property "xcelium.compile.relax" $a_sim_vars(fs_obj)] } {
    set arg_list [linsert $arg_list end "-relax"]
  }
  
  if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
    # donot pass os type
  } else {
    set arg_list [linsert $arg_list 0 "-64bit"]
  }

  if { $a_sim_vars(b_optimizeForRuntime) } {
    lappend arg_list "-logfile $a_sim_vars(tmp_log_file)"
  } else {
    set arg_list [linsert $arg_list end [list "-logfile" "${tool}.log"]]
    #lappend arg_list "-append_log"
  }
  
  if { [get_property "incremental" $a_sim_vars(fs_obj)] } {
    set arg_list [linsert $arg_list end "-update"]
  }
  
  set more_xmvhdl_options [string trim [get_property "xcelium.compile.xmvhdl.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_xmvhdl_options } {
    set arg_list [linsert $arg_list end "$more_xmvhdl_options"]
  }
  
  puts $fh_scr "# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\"\n"
}

proc usf_xcelium_write_verilog_compile_options { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set tool "xmvlog"
  set arg_list [list "-messages"]

  if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
    # donot pass os type
  } else {
    set arg_list [linsert $arg_list 0 "-64bit"]
  }

  if { $a_sim_vars(b_optimizeForRuntime) } {
    lappend arg_list "-logfile $a_sim_vars(tmp_log_file)"
  } else {
    set arg_list [linsert $arg_list end [list "-logfile" "${tool}.log"]]
    #lappend arg_list "-append_log"
  }
  
  if { [get_property "incremental" $a_sim_vars(fs_obj)] } {
    set arg_list [linsert $arg_list end "-update"]
  }

  # search for sv packages
  #usf_append_sv_pkgs arg_list
  
  set more_xmvlog_options [string trim [get_property "xcelium.compile.xmvlog.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_xmvlog_options } {
    set arg_list [linsert $arg_list end "$more_xmvlog_options"]
  }
  
  puts $fh_scr "# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\"\n"
}

proc usf_append_sv_pkgs { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $args arg_list
  variable a_sim_vars

  set design_libs [list]

  foreach lib [xcs_get_design_libs $a_sim_vars(l_design_files) 0 0 0] {
    if {[string length $lib] == 0} { continue; }
    if { "xil_defaultlib" == $lib } {
      lappend design_libs "-pkgsearch $lib"
      continue
    }
    set pkg_data_file "$a_sim_vars(s_clibs_dir)/$lib/.cxl.svpkg.dat"
    if { [file exists $pkg_data_file] } {
      lappend design_libs "-pkgsearch $lib"
    }
  }
  set lib_str [join $design_libs " "]
  set arg_list [linsert $arg_list end $lib_str]
}

proc usf_xcelium_write_systemc_compile_options { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set tool "xmsc"
  set arg_list [list "-messages"]
  set arg_list [linsert $arg_list end [list "-logfile" "${tool}.log"]]
  #lappend arg_list "-append_log"

  if { [get_property "32bit" $a_sim_vars(fs_obj)] } {
    set arg_list [linsert $arg_list 0 "-32bit"]
  } else {
    set arg_list [linsert $arg_list 0 "-64bit"]
  }

  set b_no_sysc_analysis false
  [catch {set b_no_sysc_analysis [get_param "simulator.donotCollectSystemCInfoForXcelium"]} err]
  if { $b_no_sysc_analysis } {
    set arg_list [linsert $arg_list 1 "-noedg"]
  }

  if { $a_sim_vars(b_optimizeForRuntime) } {
    lappend arg_list "-stop comp"
    lappend arg_list "-nodep"
    lappend arg_list "-gnu"
    set gcc_ver {}
    [catch {set gcc_ver [rdi::get_gcc_prod_version "xcelium"]} err]
    if { {} == $gcc_ver } {
      set gcc_ver [get_param "simulator.xcelium.gcc.version"]
    }
    set vers [split $gcc_ver "."]
    set major [lindex $vers 0]
    set minor [lindex $vers 1]
    set xcl_gcc_ver "${major}.${minor}"
    lappend arg_list "-gcc_vers $xcl_gcc_ver"
    lappend arg_list "-cxxext cxx"
    lappend arg_list "-xmscrc $a_sim_vars(tmp_obj_dir)"
  }

  set more_xmsc_options [string trim [get_property "xcelium.compile.xmsc.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_xmsc_options } {
    set arg_list [linsert $arg_list end "$more_xmsc_options"]
  }

  puts $fh_scr "# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""

  # xmsc gcc options
  set xmsc_gcc_opts [list]
  if { $a_sim_vars(b_optimizeForRuntime) } {
    lappend xmsc_gcc_opts "-Wcxx,-std=c++11,-fPIC,-c,-Wall,-Wno-deprecated"
  } else {
    lappend xmsc_gcc_opts "-std=c++11"
    lappend xmsc_gcc_opts "-fPIC"
    lappend xmsc_gcc_opts "-c"
    lappend xmsc_gcc_opts "-Wall"
    lappend xmsc_gcc_opts "-Wno-deprecated"
  }
  if { $a_sim_vars(b_ABI) } {
    lappend xmsc_gcc_opts "-D_GLIBCXX_USE_CXX11_ABI=0"
  }
  lappend xmsc_gcc_opts "-DSC_INCLUDE_DYNAMIC_PROCESSES"

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
    append xmsc_gcc_opts " $incl_dir_str"
  }

  # reference simmodel shared library include directories
  variable a_shared_library_path_coln
  set l_sim_model_incl_dirs [list]

  # param to bind shared protobuf
  set b_bind_protobuf false
  [catch {set b_bind_protobuf [get_param "project.bindProtobufSharedLibForXcelium"]} err]

  foreach {key value} [array get a_shared_library_path_coln] {
    set shared_lib_name $key
    if { ("libprotobuf.so" == $shared_lib_name) && (!$b_bind_protobuf) } {
      # don't bind shared library but bind static library built with the simmodel itself 
      continue
    }
    set lib_path            $value
    set sim_model_incl_dir "$lib_path/include"
    if { [file exists $sim_model_incl_dir] } {
      if { !$a_sim_vars(b_absolute_path) } {
        # relative path
        set b_resolved 0
        set resolved_path [xcs_resolve_sim_model_dir "xcelium" $sim_model_incl_dir $a_sim_vars(s_clibs_dir) $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved false ""]
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
      append xmsc_gcc_opts " -I$incl_dir"
    }
  }
  puts $fh_scr "${tool}_gcc_opts=\"$xmsc_gcc_opts\"\n"
}

proc usf_xcelium_write_cpp_compile_options { fh_scr } {
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
  set more_gplus_options [string trim [get_property "xcelium.compile.g++.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_gplus_options } {
    set arg_list [linsert $arg_list end "$more_gplus_options"]
  }
  puts $fh_scr "# set ${tool} command line args"
  puts $fh_scr "gpp_opts=\"[join $arg_list " "]\"\n"
}

proc usf_xcelium_write_c_compile_options { fh_scr } {
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
  set more_gcc_options [string trim [get_property "xcelium.compile.gcc.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_gcc_options } {
    set arg_list [linsert $arg_list end "$more_gcc_options"]
  }
  puts $fh_scr "# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\"\n"
}

proc usf_xcelium_write_compile_order_files_wait { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set log              {}
  set null             "2>/dev/null"
  set prev_lib         {}
  set prev_file_type   {}
  set redirect_cmd_str "2>&1 | tee"
  set cmd_str          {}

  set n_file_group       1
  set n_vhd_file_group   0
  set n_ver_file_group   0
  set n_gplus_file_group 0
  set n_gcc_file_group   0

  set b_first          true
  set b_c_cmd          true

  puts $fh_scr "# compile design source files"

  # write filelist for systemC (for xmsc_run)
  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) && $a_sim_vars(b_contain_systemc_sources) } {
    set fh 0
    set file_name "$a_sim_vars(s_sim_top)_xmsc.f"
    set file "$a_sim_vars(s_launch_dir)/$file_name"
    if {[catch {open $file w} fh]} {
      send_msg_id USF-Xcelium-016 ERROR "Failed to open file to write ($file)\n"
    } else {
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
        if { "xmsc_run" == $compiler } {
          # "$origin_dir/../../../../prj.ip_user_files/sim/snoc_sc.cpp" -> ../../../../prj.ip_user_files/sim/snoc_sc.cpp
          set sfile [string trim $src_file {\"}]
          set sfile [string trimleft $sfile {\$}]
          set sfile [string trimleft $sfile {origin_dir}]
          set sfile [string trimleft $sfile {/}]

          set src_file $sfile
          puts $fh "$src_file"
        }
      }
      close $fh
    }

    # write xmsc cmd
    set gcc_cmd "\$bin_path/$cmd_str"
    if { {} != $a_sim_vars(s_tool_bin_path) } {
      set compiler [file tail [lindex [split $cmd_str " "] 0]]
      if { "xmsc_run" == $compiler } {
        set compiler_path "$a_sim_vars(s_tool_bin_path)/$compiler"
        if { [file exists $compiler_path] } {
          set gcc_cmd "\$bin_path/$cmd_str"
        } else {
          set xcl_tool_path "$a_sim_vars(s_tool_bin_path)"
          set parent_dir [file dirname $xcl_tool_path]
          set parent_dir [file dirname $parent_dir]
          set compiler_path "$parent_dir/bin/$compiler"
          if { [file exists $compiler_path] } {
            set gcc_cmd "\$bin_path/../../bin/$cmd_str"
          }
        }
      } else {
        set gcc_cmd "\$bin_path/../../bin/$cmd_str"
      }
    }
    append gcc_cmd "$redirect_cmd_str $a_sim_vars(clog) &"
    incr n_file_group

    puts $fh_scr $gcc_cmd
    puts $fh_scr "XMSC_SYSC_PID=\$!\n"
  }

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
    if { "xmsc_run" == $compiler } {
      continue
    }

    switch -exact -- $compiler {
      "xmvhdl" -
      "xmvlog" {
        #
        # previous compilation step re-direction (if any)
        #
        if { ("gplus.log" == $log) || ("gcc.log" == $log) } {
          set cstr "$a_sim_vars(clog)"
          if { $n_file_group > 1 } { set cstr "-a $a_sim_vars(clog)" }
          puts $fh_scr "$redirect_cmd_str $cstr\n"
        }

        # first occurence (start of rtl command line)
        if { $b_first } {
          set b_first false
          usf_xcelium_set_initial_cmd $fh_scr $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
        } else {
          if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
            puts $fh_scr "$src_file \\"
          } else {
            set rdcs "$redirect_cmd_str"
            set cstr "$a_sim_vars(clog)"
            if { $n_file_group > 1 } { set cstr "-a $a_sim_vars(clog)" }
            append rdcs " $cstr"
            append rdcs "; cat $a_sim_vars(tmp_log_file)"
            if { "xmvhdl.log" == $log } { incr n_vhd_file_group;if { $n_vhd_file_group == 1 } { set rdap " > $log $null" } else { set rdap " >> $log $null" }}
            if { "xmvlog.log" == $log } { incr n_ver_file_group;if { $n_ver_file_group == 1 } { set rdap " > $log $null" } else { set rdap " >> $log $null" }}
            append rdcs $rdap
            puts $fh_scr "$rdcs\n"

            incr n_file_group
            usf_xcelium_set_initial_cmd $fh_scr $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
          }
        }
      }
      "g++"      -
      "gcc"      {
        # previous compilation step re-direction (if any)
        if { ("xmvhdl.log" == $log) || ("xmvlog.log" == $log) } {
          set rdcs "$redirect_cmd_str"
          set cstr "$a_sim_vars(clog)"
          if { $n_file_group > 1 } { set cstr "-a $a_sim_vars(clog)" }
          append rdcs " $cstr"
          append rdcs "; cat $a_sim_vars(tmp_log_file)"
          if { "xmvhdl.log" == $log } { incr n_vhd_file_group;if { $n_vhd_file_group == 1 } { set rdap " > $log $null" } else { set rdap " >> $log $null" }}
          if { "xmvlog.log" == $log } { incr n_ver_file_group;if { $n_ver_file_group == 1 } { set rdap " > $log $null" } else { set rdap " >> $log $null" }}
          append rdcs $rdap
          puts $fh_scr "$rdcs\n"
        }

        # setup command line
        set gcc_cmd "$cmd_str \\\n$src_file \\"
        if { {} != $a_sim_vars(s_tool_bin_path) } {
          set gcc_cmd "\$gcc_path/$cmd_str \\\n$src_file \\"
        }
        puts $fh_scr "$gcc_cmd"

        # setup redirection
        set cstr "$a_sim_vars(clog)"
        if { $n_file_group > 1 } {set cstr "-a $a_sim_vars(clog)"}
        puts $fh_scr "$redirect_cmd_str $cstr\n"

        incr n_file_group
        if { "g++" == $compiler } { incr n_gplus_file_group; set log "gplus.log" }
        if { "gcc" == $compiler } { incr n_gcc_file_group;   set log "gcc.log"   }
      }
      default {
        # not supported
      }
    }
  }

  # last redirect command for rtl and gcc
  if { ("xmvhdl.log" == $log) || ("xmvlog.log" == $log) } {
    if { "xmvhdl.log" == $log } { incr n_vhd_file_group   }
    if { "xmvlog.log" == $log } { incr n_ver_file_group   }

    # count number of file groups
    if { ($n_vhd_file_group > 1) || ($n_ver_file_group > 1) } { incr n_file_group }

    set rdcs "$redirect_cmd_str"
    set cstr "$a_sim_vars(clog)"
    if { $n_file_group > 1 } { set cstr "-a $a_sim_vars(clog)" }

    append rdcs " $cstr";append rdcs "; cat $a_sim_vars(tmp_log_file)"

    # only 1 vhdl or verilog file to compile?
    if { [expr $n_vhd_file_group + $n_ver_file_group] == 1 } {
      set rdap " > $log $null"
    } else {
      if {"xmvhdl.log" == $log} { if {$n_vhd_file_group == 1} {set rdap " > $log $null"} else {set rdap " >> $log $null"}}
      if {"xmvlog.log" == $log} { if {$n_ver_file_group == 1} {set rdap " > $log $null"} else {set rdap " >> $log $null"}}
    }
    append rdcs $rdap
    puts $fh_scr "$rdcs"
  }
}

proc usf_xcelium_write_compile_order_files { fh_scr } {
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

    if { ("xmsc" == $compiler) || ("g++" == $compiler) || ("gcc" == $compiler) } {
      if { "xmsc" == $compiler } {
        puts $fh_scr ""
        if { {} != $a_sim_vars(s_tool_bin_path) } {
          puts $fh_scr "\$bin_path/$cmd_str \\\n$src_file"
        } else {
          puts $fh_scr "$cmd_str \\\n$src_file"
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
      if { $b_first } {
        set b_first false
        usf_xcelium_set_initial_cmd $fh_scr $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
      } else {
        if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
          puts $fh_scr "$src_file \\"
        } else {
          puts $fh_scr ""
          usf_xcelium_set_initial_cmd $fh_scr $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
        }
      }
    }
  }
}

proc usf_xcelium_write_glbl_compile { fh_scr } {
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
  if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
    set b_load_glbl [get_property "xcelium.compile.load_glbl" [get_filesets $a_sim_vars(s_simset)]]
    if { [xcs_compile_glbl_file "xcelium" $b_load_glbl $a_sim_vars(b_int_compile_glbl) $a_sim_vars(l_design_files) $a_sim_vars(s_simset) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $a_sim_vars(b_force_compile_glbl) } {
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
        set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
        set file_str "-work $top_lib \"${glbl_file}\""
        puts $fh_scr "\n# compile glbl module"
        if { $a_sim_vars(b_optimizeForRuntime) } {
          if { {} != $a_sim_vars(s_tool_bin_path) } {
            puts $fh_scr "\$bin_path/xmvlog \$xmvlog_opts $file_str \\\n2>&1 | tee -a $a_sim_vars(clog); cat $a_sim_vars(tmp_log_file) >> xmvlog.log $null"
          } else {
            puts $fh_scr "xmvlog \$xmvlog_opts $file_str \\\n2>&1 | tee -a $a_sim_vars(clog); cat $a_sim_vars(tmp_log_file) >> xmvlog.log $null"
          }
        } else {
          if { {} != $a_sim_vars(s_tool_bin_path) } {
            puts $fh_scr "\$bin_path/xmvlog \$xmvlog_opts $file_str"
          } else {
            puts $fh_scr "xmvlog \$xmvlog_opts $file_str"
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
          xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
          set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
          set file_str "-work $top_lib \"${glbl_file}\""
          puts $fh_scr "\n# compile glbl module"
          if { $a_sim_vars(b_optimizeForRuntime) } {
            if { {} != $a_sim_vars(s_tool_bin_path) } {
              puts $fh_scr "\$bin_path/xmvlog \$xmvlog_opts $file_str \\\n2>&1 | tee -a $a_sim_vars(clog); cat $a_sim_vars(tmp_log_file) >> xmvlog.log $null"
            } else {
              puts $fh_scr "xmvlog \$xmvlog_opts $file_str \\\n2>&1 | tee -a $a_sim_vars(clog); cat $a_sim_vars(tmp_log_file) >> xmvlog.log $null"
            }
          } else {
            if { {} != $a_sim_vars(s_tool_bin_path) } {
              puts $fh_scr "\$bin_path/xmvlog \$xmvlog_opts $file_str"
            } else {
              puts $fh_scr "xmvlog \$xmvlog_opts $file_str"
            }
          }
        }
      }
    }
  }
}

}
