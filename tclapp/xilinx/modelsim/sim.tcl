######################################################################
#
# sim.tcl (simulation script for the 'ModelSim/Questa Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
######################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::modelsim {
  namespace export setup
}

namespace eval ::tclapp::xilinx::modelsim {
proc setup { args } {
  # Summary: initialize global vars and prepare for simulation
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # true (0) if success, false (1) otherwise

  # initialize global variables
  ::tclapp::xilinx::modelsim::usf_init_vars

  # control precompile flow
  variable a_sim_vars
  xcs_control_pre_compile_flow a_sim_vars(b_use_static_lib)

  # read simulation command line args and set global variables
  usf_modelsim_setup_args $args

  # perform initial simulation tasks
  if { [usf_modelsim_setup_simulation] } {
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

  send_msg_id USF-ModelSim-002 INFO "ModelSim::Compile design"
  usf_modelsim_write_compile_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::modelsim::usf_launch_script "modelsim" $step
}

proc elaborate { args } {
  # Summary: run the elaborate step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  #send_msg_id USF-ModelSim-003 INFO "ModelSim::Elaborate design"
  #usf_modelsim_write_elaborate_script

  #set proc_name [lindex [split [info level 0] " "] 0]
  #set step [lindex [split $proc_name {:}] end]
  #::tclapp::xilinx::modelsim::usf_launch_script "modelsim" $step
}

proc simulate { args } {
  # Summary: run the simulate step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  set dir $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)

  send_msg_id USF-ModelSim-004 INFO "ModelSim::Simulate design"
  usf_modelsim_write_simulate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::modelsim::usf_launch_script "modelsim" $step

  if { $::tclapp::xilinx::modelsim::a_sim_vars(b_scripts_only) } {
    set fh 0
    set file [file normalize [file join $dir "simulate.log"]]
    if {[catch {open $file w} fh]} {
      send_msg_id USF-ModelSim-016 ERROR "Failed to open file to write ($file)\n"
    } else {
      puts $fh "INFO: Scripts generated successfully. Please see the 'Tcl Console' window for details."
      close $fh
    }
  }
}
}

#
# ModelSim/Questa simulation flow
#
namespace eval ::tclapp::xilinx::modelsim {
proc usf_modelsim_setup_simulation { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  ::tclapp::xilinx::modelsim::usf_set_simulator_path "modelsim"

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

  # initialize ModelSim simulator variables
  usf_modelsim_init_simulation_vars

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

  # find/copy modelsim.ini file into run dir
  set clibs_dir [usf_modelsim_verify_compiled_lib]

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
  set ::tclapp::xilinx::modelsim::a_sim_vars(l_design_files) \
     [xcs_uniquify_cmd_str [::tclapp::xilinx::modelsim::usf_get_files_for_compilation global_files_str]]

  # create library directory
  usf_modelsim_create_lib_dir

  return 0
}

proc usf_modelsim_init_simulation_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_modelsim_sim_vars
  set a_modelsim_sim_vars(s_compiled_lib_dir) {}
}

proc usf_modelsim_setup_args { args } {
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
  # [-install_path <arg>]: Custom ModelSim installation directory path
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

  # Categories: xilinxtclstore, modelsim

  set args [string trim $args "\}\{"]

  # process options
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-simset"                 { incr i;set ::tclapp::xilinx::modelsim::a_sim_vars(s_simset) [lindex $args $i]          }
      "-mode"                   { incr i;set ::tclapp::xilinx::modelsim::a_sim_vars(s_mode) [lindex $args $i]            }
      "-type"                   { incr i;set ::tclapp::xilinx::modelsim::a_sim_vars(s_type) [lindex $args $i]            }
      "-scripts_only"           { set ::tclapp::xilinx::modelsim::a_sim_vars(b_scripts_only) 1                           }
      "-of_objects"             { incr i;set ::tclapp::xilinx::modelsim::a_sim_vars(s_comp_file) [lindex $args $i]       }
      "-absolute_path"          { set ::tclapp::xilinx::modelsim::a_sim_vars(b_absolute_path) 1                          }
      "-lib_map_path"           { incr i;set ::tclapp::xilinx::modelsim::a_sim_vars(s_lib_map_path) [lindex $args $i]    }
      "-install_path"           { incr i;set ::tclapp::xilinx::modelsim::a_sim_vars(s_install_path) [lindex $args $i];\
                                         set ::tclapp::xilinx::modelsim::a_sim_vars(b_install_path_specified) 1          }
      "-batch"                  { set ::tclapp::xilinx::modelsim::a_sim_vars(b_batch) 1                                  }
      "-run_dir"                { incr i;set ::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir) [lindex $args $i]      }
      "-int_os_type"            { incr i;set ::tclapp::xilinx::modelsim::a_sim_vars(s_int_os_type) [lindex $args $i]     }
      "-int_debug_mode"         { incr i;set ::tclapp::xilinx::modelsim::a_sim_vars(s_int_debug_mode) [lindex $args $i]  }
      "-int_ide_gui"            { set ::tclapp::xilinx::modelsim::a_sim_vars(b_int_is_gui_mode) 1                        }
      "-int_halt_script"        { set ::tclapp::xilinx::modelsim::a_sim_vars(b_int_halt_script) 1                        }
      "-int_compile_glbl"       { set ::tclapp::xilinx::modelsim::a_sim_vars(b_int_compile_glbl) 1                       }
      "-int_sm_lib_ref_debug"   { set ::tclapp::xilinx::modelsim::a_sim_vars(b_int_sm_lib_ref_debug) 1                   }
      "-int_csim_compile_order" { set ::tclapp::xilinx::modelsim::a_sim_vars(b_int_csim_compile_order) 1                 }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id USF-ModelSim-006 WARNING "Unknown option '$option' specified (ignored)\n"
        }
      }
    }
  }
}

proc usf_modelsim_verify_compiled_lib {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set b_scripts_only $::tclapp::xilinx::modelsim::a_sim_vars(b_scripts_only)

  set ini_file "modelsim.ini"
  set compiled_lib_dir {}

  send_msg_id USF-modelsim-007 INFO "Finding pre-compiled libraries...\n"

  # 1. check MODELSIM
  if { {} == $compiled_lib_dir } {
    if { [info exists ::env(MODELSIM)] } {
      set file [file normalize $::env(MODELSIM)]
      if { {} != $file } {
        if { [file exists $file] && [file isfile $file] && [file readable $file] && [file writable $file] } {
          set compiled_lib_dir [file dirname $file]
        } else {
          send_msg_id USF-modelsim-025 ERROR \
            "The INI file specified with the MODELSIM environment variable is not accessible. Please check the file permissions.\n"
          return $compiled_lib_dir
        }
      }
    }
  }
  # 2. not found? find in project default dir (<project>/<project>.cache/compile_simlib
  set dir [get_property "COMPXLIB.MODELSIM_COMPILED_LIBRARY_DIR" [current_project]]
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
      send_msg_id USF-ModelSim-010 WARNING "The path specified with the -lib_map_path does not exist:'$a_sim_vars(s_lib_map_path)'\n"
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
    set file [file normalize [file join $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir) $ini_file]]
    if { ! [file exists $file] } {
      if { $b_scripts_only } {
        send_msg_id USF-modelsim-024 WARNING "The pre-compiled simulation library could not be located. Please make sure to reference this library before executing the scripts.\n"
      } else {
        send_msg_id USF-modelsim-008 "CRITICAL WARNING" "Failed to find the pre-compiled simulation library!\n"
      }
      send_msg_id USF-modelsim-009 INFO " Recommendation:- Please follow these instructions to resolve this issue:-\n\
                                             - set the 'COMPXLIB.MODELSIM_COMPILED_LIBRARY_DIR' project property to the directory where Xilinx simulation libraries are compiled for ModelSim/QuestaSim, or\n\
                                             - set the 'MODELSIM' environment variable to point to the $ini_file file, or\n\
                                             - set the 'WD_MGC' environment variable to point to the directory containing the $ini_file file\n"
    }
  } else {
    # 6. copy to run dir
    set ini_file_path [file normalize [file join $compiled_lib_dir $ini_file]]
    if { [file exists $ini_file_path] } {
      if {[catch {file copy -force $ini_file_path $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)} error_msg] } {
        send_msg_id USF-modelsim-010 ERROR "Failed to copy file ($ini_file): $error_msg\n"
      } else {
        send_msg_id USF-modelsim-011 INFO "File '$ini_file_path' copied to run dir:'$::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)'\n"
      }
    }
  }
  return $compiled_lib_dir
}

proc usf_modelsim_create_lib_dir {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set dir $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)
  set design_lib_dir "$dir/modelsim_lib"

  if { ![file exists $design_lib_dir] } {
    if { [catch {file mkdir $design_lib_dir} error_msg] } {
      send_msg_id USF-ModelSim-013 ERROR "Failed to create the directory ($design_lib_dir): $error_msg\n"
      return 1
    }
  }
}

proc usf_modelsim_write_compile_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::modelsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::modelsim::a_sim_vars(s_simset)]

  set do_filename {}
  set do_filename $top;append do_filename "_compile.do"
  set do_file [file normalize [file join $dir $do_filename]]
  send_msg_id USF-ModelSim-015 INFO "Creating automatic 'do' files...\n"
  usf_modelsim_create_do_file_for_compilation $do_file

  # write compile.sh/.bat
  usf_modelsim_write_driver_shell_script $do_filename "compile"
}

proc usf_modelsim_write_elaborate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::modelsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::modelsim::a_sim_vars(s_simset)]

  set do_filename {}
  set do_filename $top;append do_filename "_elaborate.do"
  set do_file [file normalize [file join $dir $do_filename]]
  usf_modelsim_create_do_file_for_elaboration $do_file

  # write elaborate.sh/.bat
  usf_modelsim_write_driver_shell_script $do_filename "elaborate"
}

proc usf_modelsim_write_simulate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::modelsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::modelsim::a_sim_vars(s_simset)]

  set do_filename {}
  # is custom do file specified?
  set custom_do_file [get_property "MODELSIM.SIMULATE.CUSTOM_DO" $fs_obj]
  if { {} != $custom_do_file } {
    send_msg_id USF-ModelSim-014 INFO "Using custom 'do' file '$custom_do_file'...\n"
    set do_filename $custom_do_file
  } else {
    set do_filename $top;append do_filename "_simulate.do"
    set do_file [file normalize [file join $dir $do_filename]]
    
    usf_modelsim_create_do_file_for_simulation $do_file
  }

  # write elaborate.sh/.bat
  usf_modelsim_write_driver_shell_script $do_filename "simulate"
}

proc usf_modelsim_create_udo_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # if udo file exists, return
  if { [file exists $file] } {
    return 0
  }
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id USF-ModelSim-023 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  usf_modelsim_write_header $fh $file
  close $fh
}

proc usf_modelsim_create_wave_do_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { [file exists $file] } {
    return 0
  }
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id USF-ModelSim-017 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  usf_modelsim_write_header $fh $file
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

proc usf_modelsim_create_do_file_for_compilation { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_ip_static_libs
  variable l_local_design_libraries
  set top $::tclapp::xilinx::modelsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::modelsim::a_sim_vars(s_simset)]
  set b_absolute_path $::tclapp::xilinx::modelsim::a_sim_vars(b_absolute_path)
  set tool_path $::tclapp::xilinx::modelsim::a_sim_vars(s_tool_bin_path)
  set target_lang [get_property "TARGET_LANGUAGE" [current_project]]
  set b_scripts_only $::tclapp::xilinx::modelsim::a_sim_vars(b_scripts_only)
  set DS "\\\\"
  if {$::tcl_platform(platform) == "unix"} {
    set DS "/"
  }
  set tool_path_str ""
  if { $::tclapp::xilinx::modelsim::a_sim_vars(b_install_path_specified) } {
    set tool_path_str "$tool_path${DS}"
  }

  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-ModelSim-018 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_modelsim_write_header $fh $do_file

  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    # no op
  } else {
    usf_add_quit_on_error $fh "compile"
  }

  set design_lib_dir "$dir/modelsim_lib"
  set lib_dir_path [file normalize [string map {\\ /} $design_lib_dir]]
  if { $::tclapp::xilinx::modelsim::a_sim_vars(b_absolute_path) } {
    puts $fh "${tool_path_str}vlib $lib_dir_path/work" 
    puts $fh "${tool_path_str}vlib $lib_dir_path/msim\n"
  } else {
    puts $fh "${tool_path_str}vlib modelsim_lib/work"
    puts $fh "${tool_path_str}vlib modelsim_lib/msim\n"
  }

  set design_libs [xcs_get_design_libs $::tclapp::xilinx::modelsim::a_sim_vars(l_design_files)]

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
    if { $::tclapp::xilinx::modelsim::a_sim_vars(b_absolute_path) } {
      puts $fh "${tool_path_str}vlib $lib_dir_path/$lib_path"
    } else {
      puts $fh "${tool_path_str}vlib modelsim_lib/$lib_path"
    }
  }
  if { !$b_default_lib } {
    if { $::tclapp::xilinx::modelsim::a_sim_vars(b_absolute_path) } {
      puts $fh "${tool_path_str}vlib $lib_dir_path/msim/$default_lib"
    } else {
      puts $fh "${tool_path_str}vlib modelsim_lib/msim/$default_lib"
    }
  }
   
  puts $fh ""

  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    if { $a_sim_vars(b_use_static_lib) && ([xcs_is_static_ip_lib $lib $l_ip_static_libs]) } {
      # continue if no local library found or continue if this library is precompiled (not local)
      if { ([llength $l_local_design_libraries] == 0) || (![xcs_is_local_ip_lib $lib $l_local_design_libraries]) } {
        continue
      }
    }
    if { $::tclapp::xilinx::modelsim::a_sim_vars(b_absolute_path) } {
      puts $fh "${tool_path_str}vmap $lib $lib_dir_path/msim/$lib"
    } else {
      puts $fh "${tool_path_str}vmap $lib modelsim_lib/msim/$lib"
    }
  }
  if { !$b_default_lib } {
    if { $::tclapp::xilinx::modelsim::a_sim_vars(b_absolute_path) } {
      puts $fh "${tool_path_str}vmap $default_lib $lib_dir_path/msim/$default_lib"
    } else {
      puts $fh "${tool_path_str}vmap $default_lib modelsim_lib/msim/$default_lib"
    }
  }

  if { $a_sim_vars(b_use_static_lib) } {
    set cmd "${tool_path_str}vmap"
    usf_modelsim_map_pre_compiled_libs $fh $cmd
  }

  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    # no op
  } else {
    puts $fh ""
    if { $b_absolute_path } {
      puts $fh "set origin_dir \"$dir\""
    } else {
      puts $fh "set origin_dir \".\""
    }
  }

  set vlog_arg_list [list]
  if { [get_property "INCREMENTAL" $fs_obj] } {
    lappend vlog_arg_list "-incr"
  }
  set more_vlog_options [string trim [get_property "MODELSIM.COMPILE.VLOG.MORE_OPTIONS" $fs_obj]]
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
  set more_vcom_options [string trim [get_property "MODELSIM.COMPILE.VCOM.MORE_OPTIONS" $fs_obj]]
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

  set b_first true
  set prev_lib  {}
  set prev_file_type {}
  set b_redirect false
  set b_appended false

  foreach file $::tclapp::xilinx::modelsim::a_sim_vars(l_design_files) {
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
      usf_modelsim_set_initial_cmd $fh $cmd_str $src_file $file_type $lib prev_file_type prev_lib
    } else {
      if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
        puts $fh "$src_file \\"
        set b_redirect true
      } else {
        puts $fh ""
        usf_modelsim_set_initial_cmd $fh $cmd_str $src_file $file_type $lib prev_file_type prev_lib
        set b_appended true
      }
    }
  }

  if { (!$b_redirect) || (!$b_appended) } {
    puts $fh ""
  }

  set glbl_file "glbl.v"
  if { $::tclapp::xilinx::modelsim::a_sim_vars(b_absolute_path) } {
    set glbl_file [file normalize [file join $dir $glbl_file]]
  }

  # compile glbl file
  if { {behav_sim} == $::tclapp::xilinx::modelsim::a_sim_vars(s_simulation_flow) } {
    set b_load_glbl [get_property "MODELSIM.COMPILE.LOAD_GLBL" [get_filesets $::tclapp::xilinx::modelsim::a_sim_vars(s_simset)]]
    if { [xcs_compile_glbl_file "modelsim" $b_load_glbl $a_sim_vars(b_int_compile_glbl) $a_sim_vars(l_design_files) $a_sim_vars(s_simset) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $a_sim_vars(b_force_compile_glbl) } {
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
        set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $fs_obj $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
        set file_str "-work $top_lib \"${glbl_file}\""
        puts $fh "\n# compile glbl module\n${tool_path_str}vlog $file_str"
      }
    }
  } else {
    # for post* compile glbl if design contain verilog and netlist is vhdl
    if { (([xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] && ({VHDL} == $target_lang)) ||
          ($a_sim_vars(b_int_compile_glbl)) || ($a_sim_vars(b_force_compile_glbl))) } {
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        if { ({timing} == $::tclapp::xilinx::modelsim::a_sim_vars(s_type)) } {
          # This is not supported, netlist will be verilog always
        } else {
          xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
          set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $fs_obj $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
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
    if { ![get_param "simulator.quitOnSimulationComplete"] && $b_scripts_only } {
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

proc usf_modelsim_create_do_file_for_elaboration { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::modelsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)
  set b_batch $::tclapp::xilinx::modelsim::a_sim_vars(b_batch)
  set b_scripts_only $::tclapp::xilinx::modelsim::a_sim_vars(b_scripts_only)

  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-ModelSim-019 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_modelsim_write_header $fh $do_file
  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    # no op
  } else {
    usf_add_quit_on_error $fh "elaborate"
  }

  
  if { [get_param "project.enable2StepFlowForModelSim"] } {
    # call vopt args in simulation
  } else {
    set cmd_str [usf_modelsim_get_elaboration_cmdline]
    puts $fh "$cmd_str"
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
    if { ![get_param "simulator.quitOnSimulationComplete"] && $b_scripts_only } {
      # for debugging purposes, do not quit from vsim shell
    } else {
      puts $fh "\nquit -force"
    }
    # *** windows only ***
  }

  close $fh
}

proc usf_modelsim_get_elaboration_cmdline {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compiled_libraries
  set top $::tclapp::xilinx::modelsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)
  set sim_flow $::tclapp::xilinx::modelsim::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::xilinx::modelsim::a_sim_vars(s_simset)]

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]

  set tool "vopt"
  set arg_list [list]

  if { [get_param project.writeNativeScriptForUnifiedSimulation] } {
    if { [get_property 32bit $fs_obj] } {
      lappend arg_list {-32}
    } else {
      if {$::tcl_platform(platform) == "windows"} {
        # -64 not supported
      } else {
        lappend arg_list {-64}
      }
    }
  }

  if { [get_property "MODELSIM.ELABORATE.ACC" $fs_obj] } {
    lappend arg_list "+acc"
  }

  set vhdl_generics [list]
  set vhdl_generics [get_property "GENERIC" [get_filesets $fs_obj]]
  if { [llength $vhdl_generics] > 0 } {
    ::tclapp::xilinx::modelsim::usf_append_generics $vhdl_generics arg_list  
  }

  set more_vopt_options [string trim [get_property "MODELSIM.ELABORATE.VOPT.MORE_OPTIONS" $fs_obj]]
  if { {} != $more_vopt_options } {
    set arg_list [linsert $arg_list end "$more_vopt_options"]
  }

  set t_opts [join $arg_list " "]

  set design_files $::tclapp::xilinx::modelsim::a_sim_vars(l_design_files)
  set design_libs [xcs_get_design_libs $design_files]

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

  # add xilinx vip library
  if { [get_param "project.usePreCompiledXilinxVIPLibForSim"] } {
    if { [xcs_design_contain_sv_ip] } {
      lappend arg_list "-L"
      lappend arg_list "xilinx_vip"
    }
  }

  # post* simulation
  if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    if { [xcs_contains_verilog $design_files $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || ({Verilog} == $target_lang) } {
      if { {timesim} == $netlist_mode } {
        set arg_list [linsert $arg_list end "-L" "simprims_ver"]
      } else {
        set arg_list [linsert $arg_list end "-L" "unisims_ver"]
      }
    }
  }

  # behavioral simulation
  set b_compile_unifast 0
  set simulator_language [string tolower [get_property simulator_language [current_project]]]
  if { ([get_param "simulation.addUnifastLibraryForVhdl"]) && ({vhdl} == $simulator_language) } {
    set b_compile_unifast [get_property "unifast" $fs_obj]
  }

  if { ([xcs_contains_vhdl $design_files $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-L" "unifast"]
    }
  }

  set b_compile_unifast [get_property "unifast" $fs_obj]
  if { ([xcs_contains_verilog $design_files $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-L" "unifast_ver"]
    }
    set arg_list [linsert $arg_list end "-L" "unisims_ver"]
    set arg_list [linsert $arg_list end "-L" "unimacro_ver"]
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
      set arg_list [linsert $arg_list end "-L" "xpm"]
    }
  }

  lappend arg_list "-work"
  lappend arg_list $a_sim_vars(default_top_library)
  
  set d_libs [join $arg_list " "]
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $fs_obj $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
  set arg_list [list $tool $t_opts]
  lappend arg_list "$d_libs"
  lappend arg_list "${top_lib}.$top"
  if { ([xcs_contains_verilog $design_files $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) || $a_sim_vars(b_int_compile_glbl) || $a_sim_vars(b_force_compile_glbl) } {    
    if { $a_sim_vars(b_force_no_compile_glbl) } {
      # skip glbl top if force no compile set
    } else {
      lappend arg_list "${top_lib}.glbl"
    }
  }
  lappend arg_list "-o"
  lappend arg_list "${top}_opt"
  set cmd_str [join $arg_list " "]
  return $cmd_str
}

proc usf_modelsim_get_simulation_cmdline {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set top $::tclapp::xilinx::modelsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)
  set flow $::tclapp::xilinx::modelsim::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::xilinx::modelsim::a_sim_vars(s_simset)]

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]

  set tool "vsim"
  set arg_list [list "$tool"]

  set more_sim_options [string trim [get_property "MODELSIM.SIMULATE.VSIM.MORE_OPTIONS" $fs_obj]]
  if { {} != $more_sim_options } {
    set arg_list [linsert $arg_list end "$more_sim_options"]
  }

  lappend arg_list "-lib"
  lappend arg_list $a_sim_vars(default_top_library)
  lappend arg_list "${top}_opt"

  set cmd_str [join $arg_list " "]
  return $cmd_str
}

proc usf_modelsim_get_simulation_cmdline_2step {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compiled_libraries
  set top $::tclapp::xilinx::modelsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)
  set sim_flow $::tclapp::xilinx::modelsim::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::xilinx::modelsim::a_sim_vars(s_simset)]

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]

  set tool "vsim"
  set arg_list [list]
  if { [get_property "MODELSIM.ELABORATE.ACC" $fs_obj] } {
    set vopt_args "-voptargs=\"+acc\""
    lappend arg_list $vopt_args
  }

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
    lappend arg_list "+transport_int_delays"
    lappend arg_list "+pulse_e/$path_delay"
    lappend arg_list "+pulse_int_e/$int_delay"
    lappend arg_list "+pulse_r/$path_delay"
    lappend arg_list "+pulse_int_r/$int_delay"
  }

  set vhdl_generics [list]
  set vhdl_generics [get_property "GENERIC" [get_filesets $fs_obj]]
  if { [llength $vhdl_generics] > 0 } {
    ::tclapp::xilinx::modelsim::usf_append_generics $vhdl_generics arg_list  
  }

  set more_sim_options [string trim [get_property "MODELSIM.SIMULATE.VSIM.MORE_OPTIONS" $fs_obj]]
  if { {} != $more_sim_options } {
    set arg_list [linsert $arg_list end "$more_sim_options"]
  }

  set t_opts [join $arg_list " "]

  set design_files $::tclapp::xilinx::modelsim::a_sim_vars(l_design_files)
  set design_libs [xcs_get_design_libs $design_files 1]

  # add simulation libraries
  set arg_list [list]

  # add user design libraries
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend arg_list "-L"
    lappend arg_list "$lib"
    #lappend arg_list "[string tolower $lib]"
  }

  # add xilinx vip library
  if { [get_param "project.usePreCompiledXilinxVIPLibForSim"] } {
    if { [xcs_design_contain_sv_ip] } {
      lappend arg_list "-L"
      lappend arg_list "xilinx_vip"
    }
  }

  # post* simulation
  if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    if { [xcs_contains_verilog $design_files $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || ({Verilog} == $target_lang) } {
      if { {timesim} == $netlist_mode } {
        set arg_list [linsert $arg_list end "-L" "simprims_ver"]
      } else {
        set arg_list [linsert $arg_list end "-L" "unisims_ver"]
      }
    }
  }

  # behavioral simulation
  set b_compile_unifast 0
  set simulator_language [string tolower [get_property simulator_language [current_project]]]
  if { ([get_param "simulation.addUnifastLibraryForVhdl"]) && ({vhdl} == $simulator_language) } {
    set b_compile_unifast [get_property "unifast" $fs_obj]
  }

  if { ([xcs_contains_vhdl $design_files $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-L" "unifast"]
    }
  }

  set b_compile_unifast [get_property "unifast" $fs_obj]
  if { ([xcs_contains_verilog $design_files $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-L" "unifast_ver"]
    }
    set arg_list [linsert $arg_list end "-L" "unisims_ver"]
    set arg_list [linsert $arg_list end "-L" "unimacro_ver"]
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
      if { ([lsearch -exact $l_compiled_libraries "xpm"] == -1) } {
        set b_reference_xpm_library 0
      }
    } else {
      set b_reference_xpm_library 0
    }
  }

  if { $b_reference_xpm_library } {
    if { {behav_sim} == $sim_flow } {
      set arg_list [linsert $arg_list end "-L" "xpm"]
    }
  }

  lappend arg_list "-lib"
  lappend arg_list $a_sim_vars(default_top_library)
  
  set d_libs [join $arg_list " "]
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $fs_obj $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
  set arg_list [list $tool $t_opts]
  lappend arg_list "$d_libs"
  lappend arg_list "${top_lib}.$top"
  set top_level_inst_names {}
  usf_add_glbl_top_instance arg_list $top_level_inst_names

  set cmd_str [join $arg_list " "]
  return $cmd_str
}

proc usf_add_glbl_top_instance { opts_arg top_level_inst_names } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set fs_obj [get_filesets $::tclapp::xilinx::modelsim::a_sim_vars(s_simset)]
  upvar $opts_arg opts
  set sim_flow $::tclapp::xilinx::modelsim::a_sim_vars(s_simulation_flow)
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

  set b_load_glbl [get_property "MODELSIM.COMPILE.LOAD_GLBL" $fs_obj]
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

proc usf_modelsim_create_do_file_for_simulation { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::modelsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)
  set b_batch $::tclapp::xilinx::modelsim::a_sim_vars(b_batch)
  set b_scripts_only $::tclapp::xilinx::modelsim::a_sim_vars(b_scripts_only)
  set fs_obj [get_filesets $::tclapp::xilinx::modelsim::a_sim_vars(s_simset)]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-ModelSim-021 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_modelsim_write_header $fh $do_file
  set wave_do_filename $top;append wave_do_filename "_wave.do"
  set wave_do_file [file normalize [file join $dir $wave_do_filename]]
  set custom_wave_do_file [get_property "MODELSIM.SIMULATE.CUSTOM_WAVE_DO" $fs_obj]
  if { {} != $custom_wave_do_file } {
    set wave_do_filename $custom_wave_do_file
    # custom wave do specified, delete existing auto generated wave do file from run dir
    if { [file exists $wave_do_file] } {
      [catch {file delete -force $wave_do_file} error_msg]
    }
  } else {
    usf_modelsim_create_wave_do_file $wave_do_file
  }
  set cmd_str [usf_modelsim_get_simulation_cmdline]
  if { [get_param "project.enable2StepFlowForModelSim"] } {
    set cmd_str [usf_modelsim_get_simulation_cmdline_2step]
  }
  usf_add_quit_on_error $fh "simulate"

  puts $fh "$cmd_str"
  if { [get_property "MODELSIM.SIMULATE.IEEE_WARNINGS" $fs_obj] } {
    puts $fh "\nset NumericStdNoWarnings 1"
    puts $fh "set StdArithNoWarnings 1"
  }
  puts $fh "\ndo \{$wave_do_filename\}"
  puts $fh "\nview wave"
  puts $fh "view structure"
  puts $fh "view signals\n"

  set b_log_all_signals [get_property "MODELSIM.SIMULATE.LOG_ALL_SIGNALS" $fs_obj]
  if { $b_log_all_signals } {
    puts $fh "log -r /*\n"
  }
 
  # generate saif file for power estimation
  set saif [get_property "MODELSIM.SIMULATE.SAIF" $fs_obj] 
  if { {} != $saif } {
    set uut {}
    [catch {set uut [get_property -quiet "MODELSIM.SIMULATE.UUT" $fs_obj]} msg]
    set saif_scope [get_property "MODELSIM.SIMULATE.SAIF_SCOPE" $fs_obj]
    if { {} != $saif_scope } {
      set uut $saif_scope
    }
    if { {} == $uut } {
      set uut "/$top/uut/*"
    }
    set simulator "modelsim"
    if { ({functional} == $::tclapp::xilinx::modelsim::a_sim_vars(s_type)) || \
         ({timing} == $::tclapp::xilinx::modelsim::a_sim_vars(s_type)) } {
      puts $fh "power add -r -in -inout -out -internal [xcs_resolve_uut_name $simulator uut]\n"
    } else {
      puts $fh "power add -in -inout -out -internal [xcs_resolve_uut_name $simulator uut]\n"
    }
  }
  # create custom UDO file
  set udo_file [get_property "MODELSIM.SIMULATE.CUSTOM_UDO" $fs_obj]
  if { {} == $udo_file } {
    set udo_filename $top;append udo_filename ".udo"
    set udo_file [file normalize [file join $dir $udo_filename]]
    usf_modelsim_create_udo_file $udo_file
    puts $fh "do \{$top.udo\}"
  } else {
    puts $fh "do \{$udo_file\}"
  }

  # write tcl post hook
  set tcl_post_hook [get_property MODELSIM.SIMULATE.TCL.POST $fs_obj]
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

  set rt [string trim [get_property "MODELSIM.SIMULATE.RUNTIME" $fs_obj]]
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
  set sim_obj [get_filesets $::tclapp::xilinx::modelsim::a_sim_vars(s_simset)]
  xcs_find_files tcl_src_files $::tclapp::xilinx::modelsim::a_sim_vars(sp_tcl_obj) $filter $dir $::tclapp::xilinx::modelsim::a_sim_vars(b_absolute_path) $sim_obj
  if {[llength $tcl_src_files] > 0} {
    puts $fh ""
    foreach file $tcl_src_files {
      puts $fh "source \{$file\}"
    }
    puts $fh ""
  }

  if { $b_batch } {
    puts $fh "\nquit -force"
  } elseif { $b_scripts_only } {
    if { [get_param "simulator.quitOnSimulationComplete"] } {
      puts $fh "\nquit -force"
    }
  } else {
    # launch_simulation - if called from vivado in batch or Tcl mode, quit
    if { !$::tclapp::xilinx::modelsim::a_sim_vars(b_int_is_gui_mode) } {
      puts $fh "\nquit -force"
    }
  }
  close $fh
}

proc usf_modelsim_write_header { fh filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  set timestamp   [clock format [clock seconds]]
  set mode_type   $::tclapp::xilinx::modelsim::a_sim_vars(s_mode)
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

proc usf_modelsim_write_driver_shell_script { do_filename step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set dir $::tclapp::xilinx::modelsim::a_sim_vars(s_launch_dir)
  set b_batch $::tclapp::xilinx::modelsim::a_sim_vars(b_batch)
  set b_scripts_only $::tclapp::xilinx::modelsim::a_sim_vars(b_scripts_only)
  set tool_path $::tclapp::xilinx::modelsim::a_sim_vars(s_tool_bin_path)
  set fs_obj [get_filesets $::tclapp::xilinx::modelsim::a_sim_vars(s_simset)]

  set scr_filename $step;append scr_filename [xcs_get_script_extn "modelsim"]
  set scr_file [file normalize [file join $dir $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-ModelSim-022 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  set batch_sw {-c}
  if { ({simulate} == $step) } {
    # launch_simulation
    if { (!$b_batch) && (!$b_scripts_only) } {
      # launch_simulation - if called from vivado in batch or Tcl mode, run in command mode
      if { !$::tclapp::xilinx::modelsim::a_sim_vars(b_int_is_gui_mode) } {
        set batch_sw {-c}
      } else {
        set batch_sw {}
      }
    }
  }


  set s_64bit {}
  if {$::tcl_platform(platform) == "unix"} {
    if { [get_property 32bit $fs_obj] } {
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
  set tcl_pre_hook [get_property MODELSIM.COMPILE.TCL.PRE $fs_obj]

  set log_filename "${step}.log"
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "#!/bin/bash -f"
    xcs_write_script_header $fh_scr $step "modelsim"
    if { {} != $tool_path } {
      puts $fh_scr "bin_path=\"$tool_path\""
    }
    if { {} != $tcl_pre_hook } {
      puts $fh_scr "xv_path=\"$::env(XILINX_VIVADO)\""
    }
    xcs_write_pipe_exit $fh_scr
    # add tcl pre hook
    if { ({compile} == $step) && ({} != $tcl_pre_hook) } {
      if { ![file exists $tcl_pre_hook] } {
        [catch {send_msg_id USF-ModelSim-103 ERROR "File does not exist:'$tcl_pre_hook'\n"} err]
      }
      set tcl_wrapper_file $a_sim_vars(s_compile_pre_tcl_wrapper)
      xcs_delete_backup_log $tcl_wrapper_file $dir
      xcs_write_tcl_wrapper $tcl_pre_hook ${tcl_wrapper_file}.tcl $dir
      set vivado_cmd_str "-mode batch -notrace -nojournal -log ${tcl_wrapper_file}.log -source ${tcl_wrapper_file}.tcl"
      set cmd "vivado $vivado_cmd_str"
      puts $fh_scr "echo \"$cmd\""
      set full_cmd "\$xv_path/bin/vivado $vivado_cmd_str"
      puts $fh_scr "$full_cmd"
      xcs_write_exit_code $fh_scr
    }

    if { (({compile} == $step) || ({elaborate} == $step)) && [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
      puts $fh_scr "source $do_filename 2>&1 | tee $log_filename"
      xcs_write_exit_code $fh_scr
    } else {
      if { {} != $tool_path } {
        puts $fh_scr "\$bin_path/vsim $s_64bit $batch_sw -do \"do \{$do_filename\}\" -l $log_filename"
        xcs_write_exit_code $fh_scr
      } else {
        puts $fh_scr "vsim $s_64bit $batch_sw -do \"do \{$do_filename\}\" -l $log_filename"
        xcs_write_exit_code $fh_scr
      }
    }
  } else {
    # windows
    puts $fh_scr "@echo off"
    if { {} != $tool_path } {
      xcs_write_script_header $fh_scr $step "modelsim"
      puts $fh_scr "set bin_path=$tool_path"
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
        xcs_delete_backup_log $tcl_wrapper_file $dir
        xcs_write_tcl_wrapper $tcl_pre_hook ${tcl_wrapper_file}.tcl $dir
        set vivado_cmd_str "-mode batch -notrace -nojournal -log ${tcl_wrapper_file}.log -source ${tcl_wrapper_file}.tcl"
        set cmd "vivado $vivado_cmd_str"
        puts $fh_scr "echo \"$cmd\""
        set full_cmd "%xv_path%/bin/vivado $vivado_cmd_str"
        puts $fh_scr "call $full_cmd"
      }
      puts $fh_scr "call %bin_path%/vsim $s_64bit $batch_sw -do \"do \{$do_filename\}\" -l $log_filename"
    } else {
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

proc usf_modelsim_map_pre_compiled_libs { fh cmd } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { !$a_sim_vars(b_use_static_lib) } {
    return
  }

  set lib_path [get_property sim.ipstatic.compiled_library_dir [current_project]]
  set ini_file [file join $lib_path "modelsim.ini"]
  if { ![file exists $ini_file] } {
    return
  }

  set fh_ini 0
  if { [catch {open $ini_file r} fh_ini] } {
    send_msg_id USF-ModelSim-099 WARNING "Failed to open file for read ($ini_file)\n"
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

proc usf_modelsim_set_initial_cmd { fh_scr cmd_str src_file file_type lib prev_file_type_arg prev_lib_arg } {
  # Summary: Print compiler command line and store previous file type and library information
  # Argument Usage:
  # Return Value:
  # None

  upvar $prev_file_type_arg prev_file_type
  upvar $prev_lib_arg  prev_lib
  set tool_path $::tclapp::xilinx::modelsim::a_sim_vars(s_tool_bin_path)
  set DS "\\\\"
  if {$::tcl_platform(platform) == "unix"} {
    set DS "/"
  }
  set tool_path_str ""
  if { $::tclapp::xilinx::modelsim::a_sim_vars(b_install_path_specified) } {
    set tool_path_str "$tool_path${DS}"
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

  set b_scripts_only $::tclapp::xilinx::modelsim::a_sim_vars(b_scripts_only)

  if { $b_scripts_only } {
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
