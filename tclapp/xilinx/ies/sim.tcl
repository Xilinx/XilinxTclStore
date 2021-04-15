######################################################################
#
# sim.tcl (simulation script for the 'Cadence IES Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
######################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::ies {
  namespace export setup
}

namespace eval ::tclapp::xilinx::ies {
proc setup { args } {
  # Summary: initialize global vars and prepare for simulation
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # true (0) if success, false (1) otherwise

  # initialize global variables
  ::tclapp::xilinx::ies::usf_init_vars

  # control precompile flow
  variable a_sim_vars
  xcs_control_pre_compile_flow a_sim_vars(b_use_static_lib)

  # read simulation command line args and set global variables
  usf_ies_setup_args $args

  # perform initial simulation tasks
  if { [usf_ies_setup_simulation] } {
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

  send_msg_id USF-IES-002 INFO "IES::Compile design"
  usf_ies_write_compile_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::ies::usf_launch_script "ies" $step
}

proc elaborate { args } {
  # Summary: run the elaborate step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  send_msg_id USF-IES-003 INFO "IES::Elaborate design"
  usf_ies_write_elaborate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::ies::usf_launch_script "ies" $step
}

proc simulate { args } {
  # Summary: run the simulate step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)

  send_msg_id USF-IES-004 INFO "IES::Simulate design"
  usf_ies_write_simulate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::ies::usf_launch_script "ies" $step

  if { $::tclapp::xilinx::ies::a_sim_vars(b_scripts_only) } {
    set fh 0
    set file [file normalize [file join $dir "simulate.log"]]
    if {[catch {open $file w} fh]} {
      send_msg_id USF-IES-016 ERROR "Failed to open file to write ($file)\n"
    } else {
      puts $fh "INFO: Scripts generated successfully. Please see the 'Tcl Console' window for details."
      close $fh
    }
  }
}
}

#
# IES simulation flow
#
namespace eval ::tclapp::xilinx::ies {

proc usf_ies_setup_simulation { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  ::tclapp::xilinx::ies::usf_set_simulator_path "ies"
 
  # set the simulation flow
  xcs_set_simulation_flow $a_sim_vars(s_simset) $a_sim_vars(s_mode) $a_sim_vars(s_type) a_sim_vars(s_flow_dir_key) a_sim_vars(s_simulation_flow)

  if { ({post_synth_sim} == $a_sim_vars(s_simulation_flow)) || ({post_impl_sim} == $a_sim_vars(s_simulation_flow)) } {
    set a_sim_vars(b_netlist_sim) 1
  }

  if { [get_param "project.enableCentralSimRepo"] } {
    # no op
  } else {
    # extract ip simulation files
    xcs_extract_ip_files a_sim_vars(b_extract_ip_sim_files)
  }
	
  # set default object
  if { [xcs_set_sim_tcl_obj $a_sim_vars(s_comp_file) $a_sim_vars(s_simset) a_sim_vars(sp_tcl_obj) a_sim_vars(s_sim_top)] } {
    return 1
  }

  # initialize IES simulator variables
  usf_ies_init_simulation_vars

  # initialize XPM libraries (if any)
  xcs_get_xpm_libraries

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
  set clibs_dir [usf_ies_verify_compiled_lib]

  variable l_compiled_libraries
  variable l_xpm_libraries
  set b_reference_xpm_library 0
  if { [llength $l_xpm_libraries] > 0 } {
     if { [get_param project.usePreCompiledXPMLibForSim] } {
      set b_reference_xpm_library 1
    }
  }
  if { ($a_sim_vars(b_use_static_lib)) && ([xcs_is_ip_project] || $b_reference_xpm_library) } {
    set l_local_ip_libs [xcs_get_libs_from_local_repo $a_sim_vars(b_use_static_lib) $a_sim_vars(b_int_sm_lib_ref_debug)]
    if { {} != $clibs_dir } {
      set libraries [xcs_get_compiled_libraries $clibs_dir $a_sim_vars(b_int_sm_lib_ref_debug)]
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

  # generate mem files
  xcs_generate_mem_files_for_simulation $a_sim_vars(sp_tcl_obj) $a_sim_vars(s_launch_dir)

  # fetch the compile order for the specified object
  xcs_xport_data_files $a_sim_vars(sp_tcl_obj) $a_sim_vars(s_simset) $a_sim_vars(s_sim_top) $a_sim_vars(s_launch_dir) $a_sim_vars(dynamic_repo_dir)

  # cache all design files
  variable a_sim_cache_all_design_files_obj
  foreach file_obj [get_files -quiet -all] {
    set name [get_property -quiet name $file_obj]
    set a_sim_cache_all_design_files_obj($name) $file_obj
  }

  # cache all system verilog package libraries
  xcs_find_sv_pkg_libs $a_sim_vars(s_launch_dir) $a_sim_vars(b_int_sm_lib_ref_debug)

  # find hbm IP, if any for netlist functional simulation
  if { $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) } {
    set a_sim_vars(sp_hbm_ip_obj) [xcs_find_ip "hbm"]
  }

  # fetch design files
  set global_files_str {}
  set ::tclapp::xilinx::ies::a_sim_vars(l_design_files) \
     [xcs_uniquify_cmd_str [::tclapp::xilinx::ies::usf_get_files_for_compilation global_files_str]]

  # create setup file
  usf_ies_write_setup_files

  return 0
}

proc usf_ies_init_simulation_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_ies_sim_vars
  set a_ies_sim_vars(s_compiled_lib_dir)  {}
}

proc usf_ies_setup_args { args } {
  # Summary:
  # 

  # Argument Usage:
  # [-simset <arg>]: Name of the simulation fileset
  # [-mode <arg>]: Simulation mode. Values: behavioral, post-synthesis, post-implementation
  # [-type <arg>]: Netlist type. Values: functional, timing. This is only applicable when mode is set to post-synthesis or post-implementation
  # [-scripts_only]: Only generate scripts
  # [-of_objects <arg>]: Generate do file for this object (applicable with -scripts_only option only)
  # [-absolute_path]: Make all file paths absolute wrt the reference directory
  # [-lib_map_path <arg>]: Precompiled simulation library directory path
  # [-install_path <arg>]: Custom IES installation directory path
  # [-batch]: Execute batch flow simulation run (non-gui)
  # [-run_dir <arg>]: Simulation run directory
  # [-int_os_type]: OS type (32 or 64) (internal use)
  # [-int_debug_mode]: Debug mode (internal use)
  # [-int_ide_gui]: Vivado launch mode is gui (internal use)
  # [-int_halt_script]: Halt and generate error if simulator tools not found (internal use)
  # [-int_compile_glbl]: Compile glbl (internal use)
  # [-int_sm_lib_ref_debug]: Print simulation model library referencing debug messages (internal use)
  # [-int_csim_compile_order]: Use compile order for co-simulation (internal use)

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: xilinxtclstore, ies

  set args [string trim $args "\}\{"]

  # process options
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-simset"                 { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_simset) [lindex $args $i]          }
      "-mode"                   { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_mode) [lindex $args $i]            }
      "-type"                   { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_type) [lindex $args $i]            }
      "-scripts_only"           { set ::tclapp::xilinx::ies::a_sim_vars(b_scripts_only) 1                           }
      "-of_objects"             { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_comp_file) [lindex $args $i]       }
      "-absolute_path"          { set ::tclapp::xilinx::ies::a_sim_vars(b_absolute_path) 1                          }
      "-lib_map_path"           { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_lib_map_path) [lindex $args $i]    }
      "-install_path"           { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_install_path) [lindex $args $i]    }
      "-batch"                  { set ::tclapp::xilinx::ies::a_sim_vars(b_batch) 1                                  }
      "-run_dir"                { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_launch_dir) [lindex $args $i]      }
      "-int_os_type"            { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_int_os_type) [lindex $args $i]     }
      "-int_debug_mode"         { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_int_debug_mode) [lindex $args $i]  }
      "-int_ide_gui"            { set ::tclapp::xilinx::ies::a_sim_vars(b_int_is_gui_mode) 1                        }
      "-int_halt_script"        { set ::tclapp::xilinx::ies::a_sim_vars(b_int_halt_script) 1                        }
      "-int_compile_glbl"       { set ::tclapp::xilinx::ies::a_sim_vars(b_int_compile_glbl) 1                       }
      "-int_sm_lib_ref_debug"   { set ::tclapp::xilinx::ies::a_sim_vars(b_int_sm_lib_ref_debug) 1                   }
      "-int_csim_compile_order" { set ::tclapp::xilinx::ies::a_sim_vars(b_int_csim_compile_order) 1                 }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id USF-IES-005 WARNING "Unknown option '$option' specified (ignored)\n"
        }
      }
    }
  }
}

proc usf_ies_verify_compiled_lib {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set b_scripts_only $::tclapp::xilinx::ies::a_sim_vars(b_scripts_only)

  set cds_filename "cds.lib"
  set compiled_lib_dir {}
  send_msg_id USF-IES-006 INFO "Finding pre-compiled libraries...\n"
  # check property value
  set dir [get_property "COMPXLIB.IES_COMPILED_LIBRARY_DIR" [current_project]]
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
      send_msg_id USF-IES-010 WARNING "The path specified with the -lib_map_path does not exist:'$a_sim_vars(s_lib_map_path)'\n"
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
   set ::tclapp::xilinx::ies::a_ies_sim_vars(s_compiled_lib_dir) $compiled_lib_dir
   send_msg_id USF-IES-007 INFO "Using cds.lib from '$compiled_lib_dir/cds.lib'\n"
   return $compiled_lib_dir
  }
  if { $b_scripts_only } {
    send_msg_id USF-IES-018 WARNING "The pre-compiled simulation library could not be located. Please make sure to reference this library before executing the scripts.\n"
  } else {
    send_msg_id USF-IES-008 "CRITICAL WARNING" "Failed to find the pre-compiled simulation library!\n"
  }
  send_msg_id USF-IES-009 INFO \
     "Please set the 'COMPXLIB.IES_COMPILED_LIBRARY_DIR' project property to the directory where Xilinx simulation libraries are compiled for IES.\n"

  return $compiled_lib_dir
}

proc usf_ies_write_setup_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars
  variable l_ip_static_libs
  variable l_local_design_libraries
  set top $::tclapp::xilinx::ies::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)
  set sim_flow $::tclapp::xilinx::ies::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::xilinx::ies::a_sim_vars(s_simset)]
  set netlist_mode [get_property "NL.MODE" $fs_obj]

  #
  # cds.lib
  #
  set filename "cds.lib"
  set file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id USF-IES-010 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  set lib_map_path $::tclapp::xilinx::ies::a_ies_sim_vars(s_compiled_lib_dir)
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

  set b_add_dummy_binding 0
  if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    if { {funcsim} == $netlist_mode } {
      set b_add_dummy_binding 1
    }
  } else {
    # vhdl instantiates verilog for Versal behav sim (cr:1091134)
    if { "versal" == [rdi::get_family -arch] } {
      set b_add_dummy_binding 1
    }
  }

  if { ({} != $ip_obj) || $b_add_dummy_binding } {
    puts $fh "DEFINE simprims_ver ies_lib/simprims_ver"
    set simprim_dir "$dir/ies_lib/simprims_ver"
    if { ![file exists $simprim_dir] } {
      [catch {file mkdir $simprim_dir} error_msg]
    }
  }
  set libs [list]
  set design_libs [xcs_get_design_libs $::tclapp::xilinx::ies::a_sim_vars(l_design_files)]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend libs [string tolower $lib]
  }
  set dir_name "ies_lib"
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
    set lib_dir_path [file normalize [string map {\\ /} [file join $dir $lib_dir]]]
    if { ! [file exists $lib_dir_path] } {
      if {[catch {file mkdir $lib_dir_path} error_msg] } {
        send_msg_id USF-IES-011 ERROR "Failed to create the directory ($lib_dir_path): $error_msg\n"
        return 1
      }
    }
    if { $::tclapp::xilinx::ies::a_sim_vars(b_absolute_path) } {
      set lib_dir $lib_dir_path
    }
    puts $fh "DEFINE $lib_name $lib_dir"
    if { $default_lib == $lib_name } {
      set b_default_lib true
    }
  }
  if { !$b_default_lib } {
    set lib_dir [file join $dir_name $default_lib]
    set lib_dir_path [file normalize [string map {\\ /} [file join $dir $lib_dir]]]
    if { ! [file exists $lib_dir_path] } {
      if {[catch {file mkdir $lib_dir_path} error_msg] } {
        send_msg_id USF-IES-011 ERROR "Failed to create the directory ($lib_dir_path): $error_msg\n"
        return 1
      }
    }
    if { $::tclapp::xilinx::ies::a_sim_vars(b_absolute_path) } {
      set lib_dir $lib_dir_path
    }
    puts $fh "DEFINE $default_lib $lib_dir"
  }

  if { $a_sim_vars(b_use_static_lib) } {
    usf_ies_map_pre_compiled_libs $fh
  }
 
  close $fh

  #
  # hdl.var
  #
  set filename "hdl.var"
  set file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id USF-IES-012 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  close $fh

  # create setup file
  usf_ies_create_setup_script

}

proc usf_ies_set_initial_cmd { fh_scr cmd_str src_file file_type lib prev_file_type_arg prev_lib_arg } {
  # Summary: Print compiler command line and store previous file type and library information
  # Argument Usage:
  # Return Value:
  # None

  upvar $prev_file_type_arg prev_file_type
  upvar $prev_lib_arg  prev_lib

  set tool_path $::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)

  if { {} != $tool_path } {
    puts $fh_scr "\$bin_path/$cmd_str \\"
  } else {
    puts $fh_scr "$cmd_str \\"
  }
  puts $fh_scr "$src_file \\"

  set prev_file_type $file_type
  set prev_lib  $lib
}

proc usf_ies_write_compile_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set top $::tclapp::xilinx::ies::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::ies::a_sim_vars(s_simset)]
  set tool_path $::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)
  set target_lang [get_property "TARGET_LANGUAGE" [current_project]]

  set filename "compile";append filename [xcs_get_script_extn "ies"]
  set scr_file [file normalize [file join $dir $filename]]
  set fh_scr 0

  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-IES-013 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  puts $fh_scr "#!/bin/bash -f"
  xcs_write_script_header $fh_scr "compile" "ies"
  if { {} != $tool_path } {
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"$tool_path\""
  }

  # write tcl pre hook
  set tcl_pre_hook [get_property IES.COMPILE.TCL.PRE $fs_obj]
  if { {} != $tcl_pre_hook } {
    puts $fh_scr "xv_path=\"$::env(XILINX_VIVADO)\""
    xcs_write_shell_step_fn $fh_scr
  }
  puts $fh_scr ""

  xcs_set_ref_dir $fh_scr $a_sim_vars(b_absolute_path) $a_sim_vars(s_launch_dir)

  set b_contain_verilog_srcs [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]
  set b_contain_vhdl_srcs    [xcs_contains_vhdl $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]

  if { $b_contain_vhdl_srcs } {
    usf_ies_write_vhdl_compile_options $fh_scr
  }

  if { $b_contain_verilog_srcs } {
    usf_ies_write_verilog_compile_options $fh_scr
  }

  # add tcl pre hook
  if { {} != $tcl_pre_hook } {
    if { ![file exists $tcl_pre_hook] } {
      [catch {send_msg_id USF-IES-103 ERROR "File does not exist:'$tcl_pre_hook'\n"} err]
    }
    set tcl_wrapper_file $a_sim_vars(s_compile_pre_tcl_wrapper)
    xcs_delete_backup_log $tcl_wrapper_file $dir
    xcs_write_tcl_wrapper $tcl_pre_hook ${tcl_wrapper_file}.tcl $dir
    set vivado_cmd_str "-mode batch -notrace -nojournal -log ${tcl_wrapper_file}.log -source ${tcl_wrapper_file}.tcl"
    set cmd "vivado $vivado_cmd_str"
    puts $fh_scr "echo \"$cmd\""
    set full_cmd "\$xv_path/bin/vivado $vivado_cmd_str"
    puts $fh_scr "ExecStep $full_cmd\n"
  }

  puts $fh_scr "# compile design source files"

  set b_first true
  set prev_lib  {}
  set prev_file_type {}

  foreach file $::tclapp::xilinx::ies::a_sim_vars(l_design_files) {
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
      usf_ies_set_initial_cmd $fh_scr $cmd_str $src_file $file_type $lib prev_file_type prev_lib
    } else {
      if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
        puts $fh_scr "$src_file \\"
      } else {
        puts $fh_scr ""
        usf_ies_set_initial_cmd $fh_scr $cmd_str $src_file $file_type $lib prev_file_type prev_lib
      }
    }
  }

  set glbl_file "glbl.v"
  if { $::tclapp::xilinx::ies::a_sim_vars(b_absolute_path) } {
    set glbl_file [file normalize [file join $dir $glbl_file]]
  }

  # compile glbl file
  if { {behav_sim} == $::tclapp::xilinx::ies::a_sim_vars(s_simulation_flow) } {
    set b_load_glbl [get_property "IES.COMPILE.LOAD_GLBL" [get_filesets $::tclapp::xilinx::ies::a_sim_vars(s_simset)]]
    if { [xcs_compile_glbl_file "ies" $b_load_glbl $a_sim_vars(b_int_compile_glbl) $a_sim_vars(l_design_files) $a_sim_vars(s_simset) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $a_sim_vars(b_force_compile_glbl) } {
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
        set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $fs_obj $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
        set file_str "-work $top_lib \"${glbl_file}\""
        puts $fh_scr "\n# compile glbl module"
        if { {} != $tool_path } {
          puts $fh_scr "\$bin_path/ncvlog \$ncvlog_opts $file_str"
        } else {
          puts $fh_scr "ncvlog \$ncvlog_opts $file_str"
        }
      }
    }
  } else {
    # for post* compile glbl if design contain verilog and netlist is vhdl
    if { (([xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] && ({VHDL} == $target_lang)) ||
          ($a_sim_vars(b_int_compile_glbl)) || ($a_sim_vars(b_force_compile_glbl))) } { 
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        if { ({timing} == $::tclapp::xilinx::ies::a_sim_vars(s_type)) } {
          # This is not supported, netlist will be verilog always
        } else {
          xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
          set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $fs_obj $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
          set file_str "-work $top_lib \"${glbl_file}\""
          puts $fh_scr "\n# compile glbl module"
          if { {} != $tool_path } {
            puts $fh_scr "\$bin_path/ncvlog \$ncvlog_opts $file_str"
          } else {
            puts $fh_scr "ncvlog \$ncvlog_opts $file_str"
          }
        }
      }
    }
  }

  close $fh_scr
}

proc usf_ies_write_elaborate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compiled_libraries
  set top $::tclapp::xilinx::ies::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)
  set sim_flow $::tclapp::xilinx::ies::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::xilinx::ies::a_sim_vars(s_simset)]
  set tool_path $::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]

  set filename "elaborate";append filename [xcs_get_script_extn "ies"]
  set scr_file [file normalize [file join $dir $filename]]
  set fh_scr 0

  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-IES-014 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }
 
  puts $fh_scr "#!/bin/bash -f"
  xcs_write_script_header $fh_scr "elaborate" "ies"
  if { {} != $tool_path } {
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"$tool_path\"\n"
  }

  set tool "ncelab"
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $fs_obj $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
  set arg_list [list "-relax -access +rwc -namemap_mixgen"]

  set path_delay 0
  set int_delay 0
  set tpd_prop "TRANSPORT_PATH_DELAY"
  set tid_prop "TRANSPORT_INT_DELAY"
  if { [lsearch -exact [list_property -quiet $fs_obj] $tpd_prop] != -1 } {
    set path_delay [get_property $tpd_prop $fs_obj]
  }
  if { [lsearch -exact [list_property -quiet $fs_obj] $tid_prop] != -1 } {
    set int_delay [get_property $tid_prop $fs_obj]
  }

  if { ({post_synth_sim} == $sim_flow || {post_impl_sim} == $sim_flow) && ({timesim} == $netlist_mode) } {
    set arg_list [linsert $arg_list end "-pulse_r $path_delay -pulse_int_r $int_delay -pulse_e $path_delay -pulse_int_e $int_delay"]
  }

  set arg_list [linsert $arg_list end "-messages -logfile elaborate.log"]

  if { [get_property 32bit $fs_obj] } {
    # donot pass os type
  } else {
     set arg_list [linsert $arg_list 0 "-64bit"]
  }

  if { [get_property "IES.ELABORATE.UPDATE" $fs_obj] } {
    set arg_list [linsert $arg_list end "-update"]
  }

  set more_elab_options [string trim [get_property "IES.ELABORATE.NCELAB.MORE_OPTIONS" $fs_obj]]
  if { {} != $more_elab_options } {
    set arg_list [linsert $arg_list end "$more_elab_options"]
  }

  puts $fh_scr "# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  set design_libs [xcs_get_design_libs $::tclapp::xilinx::ies::a_sim_vars(l_design_files)]

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
  if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    if { [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || ({Verilog} == $target_lang) } {
      if { {timesim} == $netlist_mode } {
        set arg_list [linsert $arg_list end "-libname" "simprims_ver"]
      } else {
        set arg_list [linsert $arg_list end "-libname" "unisims_ver"]
      }
    }
  }

  # behavioral simulation
  set b_compile_unifast 0
  set simulator_language [string tolower [get_property simulator_language [current_project]]]
  if { ([get_param "simulation.addUnifastLibraryForVhdl"]) && ({vhdl} == $simulator_language) } {
    set b_compile_unifast [get_property "unifast" $fs_obj]
  }

  if { ([xcs_contains_vhdl $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-libname" "unifast"]
    }
  }

  set b_compile_unifast [get_property "unifast" $fs_obj]
  if { ([xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $sim_flow) } {
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
    if { {behav_sim} == $sim_flow } {
      set arg_list [linsert $arg_list end "-libname" "xpm"]
    }
  }

  puts $fh_scr "\n# set design libraries"
  puts $fh_scr "design_libs_elab=\"[join $arg_list " "]\"\n"

  set tool_path_val "\$bin_path/$tool"
  if { {} == $tool_path } {
    set tool_path_val "$tool"
  }
  set arg_list [list ${tool_path_val} "\$${tool}_opts"]

  set obj $::tclapp::xilinx::ies::a_sim_vars(sp_tcl_obj)
  if { [xcs_is_fileset $obj] } {
    set vhdl_generics [list]
    set vhdl_generics [get_property "GENERIC" [get_filesets $obj]]
    if { [llength $vhdl_generics] > 0 } {
      ::tclapp::xilinx::ies::usf_append_generics $vhdl_generics arg_list
    }
  }

  lappend arg_list "\$design_libs_elab"
  lappend arg_list "${top_lib}.$top"
  set top_level_inst_names {}
  usf_add_glbl_top_instance arg_list $top_level_inst_names

  puts $fh_scr "# run elaboration"
  set cmd_str [join $arg_list " "]
  puts $fh_scr "$cmd_str"
  close $fh_scr
}

proc usf_add_glbl_top_instance { opts_arg top_level_inst_names } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set fs_obj [get_filesets $::tclapp::xilinx::ies::a_sim_vars(s_simset)]
  upvar $opts_arg opts
  set sim_flow $::tclapp::xilinx::ies::a_sim_vars(s_simulation_flow)
  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]

  set b_verilog_sim_netlist 0
  if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    set target_lang [get_property "TARGET_LANGUAGE" [current_project]]
    if { {Verilog} == $target_lang } {
      set b_verilog_sim_netlist 1
    }
  }

  set b_add_glbl 0
  set b_top_level_glbl_inst_set 0

  # is glbl specified explicitly?
  if { ([lsearch ${top_level_inst_names} {glbl}] != -1) } {
    set b_top_level_glbl_inst_set 1
  }

  set b_load_glbl [get_property "IES.COMPILE.LOAD_GLBL" $fs_obj]
  if { [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $b_verilog_sim_netlist } {
    if { {behav_sim} == $sim_flow } {
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
    set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $fs_obj $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
    lappend opts "${top_lib}.glbl"
  }
}

proc usf_ies_write_simulate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set top $::tclapp::xilinx::ies::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::ies::a_sim_vars(s_simset)]
  set b_scripts_only $::tclapp::xilinx::ies::a_sim_vars(b_scripts_only)
  set tool_path $::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)

  set filename "simulate";append filename [xcs_get_script_extn "ies"]
  set scr_file [file normalize [file join $dir $filename]]
  set fh_scr 0

  if { [catch {open $scr_file w} fh_scr] } {
    send_msg_id USF-IES-016 ERROR "Failed to open file to write ($file)\n"
    return 1
  }

  puts $fh_scr "#!/bin/bash -f"
  xcs_write_script_header $fh_scr "simulate" "ies"
  if { {} != $tool_path } {
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"$tool_path\"\n"
  }

  set do_filename "${top}_simulate.do"

  ::tclapp::xilinx::ies::usf_create_do_file "ies" $do_filename
	
  set tool "ncsim"
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $fs_obj $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
  set arg_list [list "-logfile" "simulate.log"]
  if { [get_property 32bit $fs_obj] } {
    # donot pass os type
  } else {
    set arg_list [linsert $arg_list 0 "-64bit"]
  }

  if { [get_property "IES.SIMULATE.UPDATE" $fs_obj] } {
    set arg_list [linsert $arg_list end "-update"]
  }

  set more_sim_options [string trim [get_property "IES.SIMULATE.NCSIM.MORE_OPTIONS" $fs_obj]]
  if { {} != $more_sim_options } {
    set arg_list [linsert $arg_list end "$more_sim_options"]
  }

  if { $::tclapp::xilinx::ies::a_sim_vars(b_batch) || $b_scripts_only } {
   # no gui
  } else {
    # launch_simulation - if called from vivado in gui mode only
    if { $::tclapp::xilinx::ies::a_sim_vars(b_int_is_gui_mode) } {
      set arg_list [linsert $arg_list end "-gui"]
    }
  }

  puts $fh_scr "# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  puts $fh_scr ""

  set tool_path_val "\$bin_path/$tool"
  if { {} == $tool_path } {
    set tool_path_val "$tool"
  }
  set arg_list [list "${tool_path_val}" "\$${tool}_opts" "${top_lib}.$top" "-input" "$do_filename"]
  set ip_obj [xcs_find_ip "gt_quad_base"]
  if { {} != $ip_obj } {
    variable a_ies_sim_vars
    set clibs_dir $a_ies_sim_vars(s_compiled_lib_dir)
    #lappend arg_list "-sv_root \"$clibs_dir/secureip\""
    #lappend arg_list "-sv_lib gtye5_quad.so"
  }
  set cmd_str [join $arg_list " "]

  puts $fh_scr "# run simulation"
  puts $fh_scr "$cmd_str"
  close $fh_scr
}

proc usf_ies_map_pre_compiled_libs { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { !$a_sim_vars(b_use_static_lib) } {
    return
  }

  set lib_path [get_property sim.ipstatic.compiled_library_dir [current_project]]
  set ini_file [file join $lib_path "cds.lib"]
  if { ![file exists $ini_file] } {
    return
  }

  set fh_ini 0
  if { [catch {open $ini_file r} fh_ini] } {
    send_msg_id USF-IES-099 WARNING "Failed to open file for read ($ini_file)\n"
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

proc usf_ies_create_setup_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_ip_static_libs
  variable l_local_design_libraries
  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)
  set top $::tclapp::xilinx::ies::a_sim_vars(s_sim_top)
  set filename "setup";append filename [xcs_get_script_extn "ies"]
  set scr_file [file normalize [file join $dir $filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-IES-017 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  puts $fh_scr "#!/bin/bash -f"
  xcs_write_script_header $fh_scr "setup" "ies"

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
  set simulator "ies"
  set libs [list]
  set design_libs [xcs_get_design_libs $::tclapp::xilinx::ies::a_sim_vars(l_design_files)]
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
  if { $::tclapp::xilinx::ies::a_sim_vars(b_absolute_path) } {
    set lib_dir_path [file normalize [string map {\\ /} [file join $dir $design_lib]]]
    puts $fh_scr "  dir=\"$lib_dir_path\"\n"
  } else {
    puts $fh_scr "  dir=\"$design_lib\"\n"
  }
  puts $fh_scr "  if \[\[ -e \$file \]\]; then"
  puts $fh_scr "    rm -f \$file"
  puts $fh_scr "  fi"
  puts $fh_scr "  if \[\[ -e \$dir \]\]; then"
  puts $fh_scr "    rm -rf \$dir"
  puts $fh_scr "  fi"
  puts $fh_scr ""
  puts $fh_scr "  touch \$file"

  set compiled_lib_dir $::tclapp::xilinx::ies::a_ies_sim_vars(s_compiled_lib_dir)
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
  set file_list [list "ncsim.key" "ncvlog.log" "ncvhdl.log" "compile.log" "elaborate.log" "waves.shm"]
  set files [join $file_list " "]
  puts $fh_scr "  files_to_remove=($files)"
  puts $fh_scr "  for (( i=0; i<\$\{#files_to_remove\[*\]\}; i++ )); do"
  puts $fh_scr "    file=\"\$\{files_to_remove\[i\]\}\""
  puts $fh_scr "    if \[\[ -e \$file \]\]; then"
  puts $fh_scr "      rm -rf \$file"
  puts $fh_scr "    fi"
  puts $fh_scr "  done"
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
  set copyright   [lindex $version_txt 2]
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

proc usf_ies_write_vhdl_compile_options { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars
  set fs_obj [get_filesets $a_sim_vars(s_simset)]

  set tool "ncvhdl"
  set arg_list [list "-messages"]

  if { [get_property "IES.COMPILE.RELAX" $fs_obj] } {
    set arg_list [linsert $arg_list end "-relax"]
  }

  set arg_list [linsert $arg_list end [list "-logfile" "${tool}.log"]]
  #lappend arg_list "-append_log"

  if { [get_property 32bit $fs_obj] } {
    # donot pass os type
  } else {
    set arg_list [linsert $arg_list 0 "-64bit"]
  }

  if { [get_property "INCREMENTAL" $fs_obj] } {
    set arg_list [linsert $arg_list end "-update"]
  }

  set more_ncvhdl_options [string trim [get_property "IES.COMPILE.NCVHDL.MORE_OPTIONS" $fs_obj]]
  if { {} != $more_ncvhdl_options } {
    set arg_list [linsert $arg_list end "$more_ncvhdl_options"]
  }

  puts $fh_scr "# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\"\n"
}

proc usf_ies_write_verilog_compile_options { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars
  set fs_obj [get_filesets $a_sim_vars(s_simset)]

  set tool "ncvlog"
  set arg_list [list "-messages" "-logfile" "${tool}.log"]
  #lappend arg_list "-append_log"

  if { [get_property 32bit $fs_obj] } {
    # donot pass os type
  } else {
    set arg_list [linsert $arg_list 0 "-64bit"]
  }

  if { [get_property "INCREMENTAL" $fs_obj] } {
    set arg_list [linsert $arg_list end "-update"]
  }

  set more_ncvlog_options [string trim [get_property "IES.COMPILE.NCVLOG.MORE_OPTIONS" $fs_obj]]
  if { {} != $more_ncvlog_options } {
    set arg_list [linsert $arg_list end "$more_ncvlog_options"]
  }

  puts $fh_scr "# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\"\n"
}

}
