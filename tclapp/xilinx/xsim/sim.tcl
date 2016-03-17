######################################################################
#
# sim.tcl (simulation script for the 'Vivado Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
######################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::xsim {
  namespace export setup
}

namespace eval ::tclapp::xilinx::xsim {
proc setup { args } {
  # Summary: initialize global vars and prepare for simulation
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task 
  # Return Value:
  # true (0) if success, false (1) otherwise

  # initialize global variables
  ::tclapp::xilinx::xsim::usf_init_vars

  # control precompile flow
  variable a_sim_vars
  xcs_control_pre_compile_flow a_sim_vars(b_use_static_lib)

  # read simulation command line args and set global variables
  usf_xsim_setup_args $args

  # perform initial simulation tasks
  if { [usf_xsim_setup_simulation] } {
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

  set scr_filename {}
  send_msg_id USF-XSim-002 INFO "XSim::Compile design"
  usf_xsim_write_compile_script scr_filename
  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::xsim::usf_launch_script "xsim" $step
  #::tclapp::xilinx::xsim::usf_xsim_include_xvhdl_log
}

proc elaborate { args } {
  # Summary: run the elaborate step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task 
  # Return Value:
  # none

  set scr_filename {}
  send_msg_id USF-XSim-003 INFO "XSim::Elaborate design"
  usf_xsim_write_elaborate_script scr_filename
  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::xsim::usf_launch_script "xsim" $step
}

proc simulate { args } {
  # Summary: run the simulate step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task 
  # Return Value:
  # none

  set scr_filename {}
  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]
  set snapshot $::tclapp::xilinx::xsim::a_xsim_vars(s_snapshot)
  send_msg_id USF-XSim-004 INFO "XSim::Simulate design"
  # create setup files
  set cmd_file {}
  set wcfg_file {}
  set b_add_view 0
  set cmd_args [usf_xsim_write_simulate_script cmd_file wcfg_file b_add_view scr_filename]

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::xsim::usf_launch_script "xsim" $step

  if { $::tclapp::xilinx::xsim::a_sim_vars(b_scripts_only) } {
    set fh 0
    set file [file normalize [file join $dir "simulate.log"]]
    if {[catch {open $file w} fh]} {
      send_msg_id USF-XSim-016 ERROR "Failed to open file to write ($file)\n"
    } else {
      puts $fh "INFO: Scripts generated successfully. Please see the 'Tcl Console' window for details."
      close $fh
    }
    return
  }

  # is dll requested?
  set b_dll [get_property "XELAB.DLL" $fs_obj]
  if { $b_dll } {
    set lib_extn {.dll}
    if {$::tcl_platform(platform) == "unix"} {
      set lib_extn {.so}
    }
    set dll_lib_name "xsimk";append dll_lib_name $lib_extn
    set dll_file [file normalize [file join $dir "xsim.dir" $snapshot $dll_lib_name]]
    if { [file exists $dll_file] } {
      send_msg_id USF-XSim-006 INFO "Shared library for snapshot '$snapshot' generated:$dll_file"
    } else {
      send_msg_id USF-XSim-007 ERROR "Failed to generate the shared library for snapshot '$snapshot'!"
    }
    return
  }

  # launch xsim
  send_msg_id USF-XSim-008 INFO "Loading simulator feature"
  load_feature simulator

  set cwd [pwd]
  cd $dir
  if {[catch {eval "xsim $cmd_args"} err_msg]} {
    puts $err_msg
    set step "simulate"
    [catch {send_msg_id USF-XSim-062 ERROR "'$step' step failed with errors. Please check the Tcl console or log files for more information.\n"}]
    cd $cwd
    # IMPORTANT - *** DONOT MODIFY THIS ***
    error "_SIM_STEP_RUN_EXEC_ERROR_"
    # IMPORTANT - *** DONOT MODIFY THIS ***
    return 1
  } else {
    cd $cwd
    send_msg_id USF-XSim-096 INFO "XSim completed. Design snapshot '$snapshot' loaded."
    set rt [string trim [get_property "XSIM.SIMULATE.RUNTIME" $fs_obj]]
    if { {} != $rt } {
      send_msg_id USF-XSim-097 INFO "XSim simulation ran for $rt"
    }
  
    # close for batch flow
    if { $::tclapp::xilinx::xsim::a_sim_vars(b_batch) } {
      send_msg_id USF-XSim-009 INFO "Closing simulation..."
      close_sim
    }
  }
}
}

#
# XSim simulation flow
#
namespace eval ::tclapp::xilinx::xsim {
proc usf_xsim_setup_simulation { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set run_dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)
 
  # set the simulation flow
  ::tclapp::xilinx::xsim::usf_set_simulation_flow
 
  # set default object
  if { [::tclapp::xilinx::xsim::usf_set_sim_tcl_obj] } {
    puts "failed to set tcl obj"
    return 1
  }

  # initialize Vivado simulator variables
  usf_xsim_init_simulation_vars

  # print launch_simulation arg values
  #::tclapp::xilinx::xsim::usf_print_args

  # write functional/timing netlist for post-* simulation
  ::tclapp::xilinx::xsim::usf_write_design_netlist

  # prepare IP's for simulation
  #::tclapp::xilinx::xsim::usf_prepare_ip_for_simulation

  variable l_compiled_libraries
  if { $a_sim_vars(b_use_static_lib) } {
    usf_set_compiled_lib_dir
    set l_compiled_libraries [xcs_get_compiled_libraries $a_sim_vars(compiled_library_dir)]
  }

  # generate mem files
  ::tclapp::xilinx::xsim::usf_generate_mem_files_for_simulation

  # fetch the compile order for the specified object
  ::tclapp::xilinx::xsim::usf_xport_data_files

  # fetch design files
  variable l_local_design_libraries 
  set global_files_str {}
  set ::tclapp::xilinx::xsim::a_sim_vars(l_design_files) \
     [xcs_uniquify_cmd_str [::tclapp::xilinx::xsim::usf_get_files_for_compilation global_files_str]]

  set ::tclapp::xilinx::xsim::a_sim_vars(global_files_value) $global_files_str
 
  set b_create_default_ini 1
  if { $a_sim_vars(b_use_static_lib) } {
    set filename "xsim.ini"
    set file [file join $run_dir $filename]

    # at this point the ini file must exist in run for pre-compile flow, if not create default
    # for user design libraries since the static files will be exported for these libraries
    if { [file exists $file] } {
      # re-align local libraries for the ones that were not found in compiled library
      usf_realign_local_mappings $file l_local_design_libraries
      set b_create_default_ini 0
    }
  }

  if { $b_create_default_ini } {
    usf_xsim_write_setup_file
  }

  return 0
}

proc usf_set_compiled_lib_dir { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set run_dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)

  set filename "xsim.ini"
  set file [file join $run_dir $filename]

  # delete xsim.ini from run dir
  if { [file exists $file] } {
    [catch {file delete -force $file} error_msg]
  }

  # find/copy xsim.ini file into run dir
  if { [usf_xsim_verify_compiled_lib] } {
    return
  }

  if { ![file exists $file] } {
    return
  }

  set fh 0
  if {[catch {open $file a} fh]} {
    send_msg_id USF-XSim-011 ERROR "Failed to open file to append ($file)\n"
    return
  }
  usf_xsim_map_pre_compiled_libs $fh
  close $fh

  return
}

proc usf_realign_local_mappings { ini_file l_local_design_libraries_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_local_design_libraries_arg l_local_libraries

  if { ![file exists $ini_file] } {
    return
  }

  # read xsim.ini contents
  set fh 0
  if {[catch {open $ini_file r} fh]} {
    send_msg_id USF-XSim-011 ERROR "Failed to open file to read ($ini_file)\n"
    return 1
  }
  set data [split [read $fh] "\n"]
  close $fh
  set l_updated_mappings [list]
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    set library [string trim [lindex [split $line "="] 0]]
    if { [lsearch -exact $l_local_libraries $library] != -1 } {
      set line "$library=xsim.dir/$library"
    }
    lappend l_updated_mappings $line
  }

  # first make back up
  set ini_file_bak ${ini_file}.bak
  [catch {file copy -force $ini_file $ini_file_bak} error_msg]

  # delete ini file
  [catch {file delete -force $ini_file} error_msg]

  # create fresh updated copy
  set fh 0
  if {[catch {open $ini_file w} fh]} {
    send_msg_id USF-XSim-011 ERROR "Failed to open file to write ($ini_file)\n"
    # revert backup ini file
    [catch {file copy -force $ini_file_bak $ini_file} error_msg]
    return
  }
  foreach line $l_updated_mappings {
    puts $fh $line
  }
  close $fh
}

proc usf_xsim_init_simulation_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_xsim_vars
  set a_xsim_vars(s_snapshot) [usf_xsim_get_snapshot]
}

proc usf_xsim_setup_args { args } {
  # Summary:
 
  # Argument Usage:
  # [-simset <arg>]: Name of the simulation fileset
  # [-mode <arg>]: Simulation mode. Values: behavioral, post-synthesis, post-implementation
  # [-type <arg>]: Netlist type. Values: functional, timing. This is only applicable when mode is set to post-synthesis or post-implementation
  # [-scripts_only]: Only generate scripts
  # [-of_objects <arg>]: Generate do file for this object (applicable with -scripts_only option only)
  # [-absolute_path]: Make all file paths absolute wrt the reference directory
  # [-lib_map_path <arg>]: Precompiled simulation library directory path
  # [-batch]: Execute batch flow simulation run (non-gui)
  # [-run_dir <arg>]: Simulation run directory
  # [-int_os_type]: OS type (32 or 64) (internal use)
  # [-int_debug_mode]: Debug mode (internal use)
 
  # Return Value:
  # true (0) if success, false (1) otherwise
 
  # Categories: xilinxtclstore, xsim
 
  set args [string trim $args "\}\{"]
 
  # process options
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-simset"         { incr i;set ::tclapp::xilinx::xsim::a_sim_vars(s_simset) [lindex $args $i] }
      "-mode"           { incr i;set ::tclapp::xilinx::xsim::a_sim_vars(s_mode) [lindex $args $i] }
      "-type"           { incr i;set ::tclapp::xilinx::xsim::a_sim_vars(s_type) [lindex $args $i] }
      "-scripts_only"   { set ::tclapp::xilinx::xsim::a_sim_vars(b_scripts_only) 1 }
      "-of_objects"     { incr i;set ::tclapp::xilinx::xsim::a_sim_vars(s_comp_file) [lindex $args $i]}
      "-absolute_path"  { set ::tclapp::xilinx::xsim::a_sim_vars(b_absolute_path) 1 }
      "-lib_map_path"   { incr i;set ::tclapp::xilinx::xsim::a_sim_vars(s_lib_map_path) [lindex $args $i] }
      "-batch"          { set ::tclapp::xilinx::xsim::a_sim_vars(b_batch) 1 }
      "-run_dir"        { incr i;set ::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir) [lindex $args $i] }
      "-int_os_type"    { incr i;set ::tclapp::xilinx::xsim::a_sim_vars(s_int_os_type) [lindex $args $i] }
      "-int_debug_mode" { incr i;set ::tclapp::xilinx::xsim::a_sim_vars(s_int_debug_mode) [lindex $args $i] }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id USF-XSim-010 ERROR "Unknown option '$option', please type 'launch_simulation -help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

proc usf_xsim_verify_compiled_lib {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set run_dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)

  set filename "xsim.ini"
  send_msg_id USF-XSim-007 INFO "Finding pre-compiled libraries...\n"

  # 1. is -lib_map_path specified and point to valid location?
  if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
    set a_sim_vars(s_lib_map_path) [file normalize $a_sim_vars(s_lib_map_path)]
    set ini_file [file normalize [file join $a_sim_vars(s_lib_map_path) $filename]]
    if { [file exists $ini_file] } {
      if { [usf_copy_ini_file $a_sim_vars(s_lib_map_path)] } {
        return 1
      }  
      set a_sim_vars(compiled_library_dir) $a_sim_vars(s_lib_map_path)
      return 0
    } else {
      usf_print_compiled_lib_msg
      return 1
    }
  }

  # 2. if empty property (default), calculate default install location
  set dir [get_property "COMPXLIB.XSIM_COMPILED_LIBRARY_DIR" [current_project]]
  if { {} == $dir } {
    set dir $::env(XILINX_VIVADO)
    set dir [file normalize [file join $dir "data/xsim"]]
  }
  set file [file normalize [file join $dir $filename]]
  if { [file exists $file] } {
    if { [usf_copy_ini_file $dir] } {
     return 1
    }
    set a_sim_vars(compiled_library_dir) $dir
    return 0
  } else {
    usf_print_compiled_lib_msg
    return 1
  }

  return 1
}

proc usf_print_compiled_lib_msg {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set b_scripts_only $::tclapp::xilinx::xsim::a_sim_vars(b_scripts_only)

  if { $b_scripts_only } {
    send_msg_id USF-XSim-024 WARNING "The compiled IP simulation library could not be located. Please make sure to reference this library before executing the scripts.\n"
  } else {
    send_msg_id USF-XSim-008 "CRITICAL WARNING" "Failed to find the pre-compiled simulation library. IPs will be compiled locally as part of the simulation.\n"
  }
}

proc usf_copy_ini_file { dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set run_dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)

  # check from install area (xsim/ip/xsim_ip.ini)
  set file [file join $dir "ip" "xsim_ip.ini"]
  if { [file exists $file] } {
    set target_file [file join $run_dir "xsim.ini"]
    if { [catch {file copy -force $file $target_file} error_msg] } {
      send_msg_id USF-XSim-010 ERROR "Failed to copy file ($file): $error_msg\n"
      return 1
    } else {
      send_msg_id USF-XSim-011 INFO "File '$file' copied to run dir:'$run_dir'\n"
      return 0
    }
  }

  # now copy the default xsim.ini
  set file [file join $dir "xsim.ini"]
  if { [file exists $file] } {
    if { [catch {file copy -force $file $run_dir} error_msg] } {
      send_msg_id USF-XSim-010 ERROR "Failed to copy file ($file): $error_msg\n"
      return 1
    } else {
      send_msg_id USF-XSim-011 INFO "File '$file' copied to run dir:'$run_dir'\n"
      return 0
    }
  }
  return 0
}

proc usf_xsim_write_setup_file {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set top $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)

  set filename "xsim.ini"
  set file [file normalize [file join $dir $filename]]
  set fh 0

  if {[catch {open $file w} fh]} {
    send_msg_id USF-XSim-011 ERROR "Failed to open file to write ($file)\n"
    return 1
  }

  set design_libs [usf_xsim_get_design_libs $::tclapp::xilinx::xsim::a_sim_vars(l_design_files)]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    set lib_name [string tolower $lib]
    puts $fh "$lib=xsim.dir/$lib_name"
  }
  
  close $fh
}

proc usf_xsim_write_compile_script { scr_filename_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $scr_filename_arg scr_filename
  variable a_sim_vars
  variable a_xsim_vars
 
  set top $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]
  set src_mgmt_mode [get_property "SOURCE_MGMT_MODE" [current_project]]
  set target_lang   [get_property "TARGET_LANGUAGE" [current_project]]

  set b_contain_verilog_srcs [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]
  set b_contain_vhdl_srcs    [xcs_contains_vhdl $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]

  # set param to force nosort (default is false)
  set nosort_param [get_param "simulation.donotRecalculateCompileOrderForXSim"] 
  set log_filename "compile.log"

  # write compile.sh/.bat
  set scr_filename "compile";append scr_filename [::tclapp::xilinx::xsim::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-XSim-015 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  set s_plat_sw "-m64"
  if { [get_property 32bit $fs_obj] } {
    set s_plat_sw "-m32"
  }

  set s_dbg_sw {}
  set dbg $::tclapp::xilinx::xsim::a_sim_vars(s_int_debug_mode)
  if { $dbg } {
    set s_dbg_sw {-dbg}
  }

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "#!/bin/bash -f"
    puts $fh_scr "xv_path=\"$::env(XILINX_VIVADO)\""
    if { [get_param "project.allowSharedLibraryType"] } {
      puts $fh_scr "xv_lib_path=\"$::env(RDI_LIBDIR)\""
    }
    ::tclapp::xilinx::xsim::usf_write_shell_step_fn $fh_scr
  } else {
    puts $fh_scr "@echo off"
    puts $fh_scr "set xv_path=[::tclapp::xilinx::xsim::usf_get_rdi_bin_path]"
  }

  # write verilog prj if design contains verilog sources 
  if { $b_contain_verilog_srcs } {
    set vlog_filename ${top};append vlog_filename "_vlog.prj"
    set vlog_file [file normalize [file join $dir $vlog_filename]]
    set fh_vlog 0
    if {[catch {open $vlog_file w} fh_vlog]} {
      send_msg_id USF-XSim-012 ERROR "Failed to open file to write ($vlog_file)\n"
      return 1
    }
    puts $fh_vlog "# compile verilog/system verilog design source files"
    foreach file $::tclapp::xilinx::xsim::a_sim_vars(l_design_files) {
      set fargs       [split $file {|}]
      set type        [lindex $fargs 0]
      set file_type   [lindex $fargs 1]
      set lib         [lindex $fargs 2]
      set cmd_str     [lindex $fargs 3]
      set b_static_ip [lindex $fargs 4]
      if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
      switch $type {
        {VERILOG} { puts $fh_vlog $cmd_str }
      }
    }

    set glbl_file "glbl.v"
    if { $::tclapp::xilinx::xsim::a_sim_vars(b_absolute_path) } {
      set glbl_file [file normalize [file join $dir $glbl_file]]
    }

    # compile glbl file for behav
    if { {behav_sim} == $::tclapp::xilinx::xsim::a_sim_vars(s_simulation_flow) } {
      set b_load_glbl [get_property "XSIM.ELABORATE.LOAD_GLBL" [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]]
      if { [::tclapp::xilinx::xsim::usf_compile_glbl_file "xsim" $b_load_glbl $::tclapp::xilinx::xsim::a_sim_vars(l_design_files)] } {
        set top_lib [::tclapp::xilinx::xsim::usf_get_top_library]
        xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
        set file_str "$top_lib \"${glbl_file}\""
        puts $fh_vlog "\n# compile glbl module\nverilog $file_str"
      }
    } else {
      # for post* compile glbl if design contain verilog and netlist is vhdl
      if { [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] && ({VHDL} == $target_lang) } {
        if { ({timing} == $::tclapp::xilinx::xsim::a_sim_vars(s_type)) } {
          # This is not supported, netlist will be verilog always
        } else {
          set top_lib [::tclapp::xilinx::xsim::usf_get_top_library]
          xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
          set file_str "$top_lib \"${glbl_file}\""
          puts $fh_vlog "\n# compile glbl module\nverilog $file_str"
        }
      }
    }

    # nosort? (verilog)
    set b_no_sort [get_property "XSIM.COMPILE.XVLOG.NOSORT" [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]]
    if { $b_no_sort || $nosort_param || ({DisplayOnly} == $src_mgmt_mode) || ({None} == $src_mgmt_mode) } {
      puts $fh_vlog "\n# Do not sort compile order\nnosort"
    }
    close $fh_vlog

    set xvlog_arg_list [list "$s_plat_sw"]
    if { [get_property "XSIM.COMPILE.XVLOG.RELAX" $fs_obj] } {
      lappend xvlog_arg_list "--relax"
    }
    lappend xvlog_arg_list "-prj $vlog_filename"
    set more_xvlog_options [string trim [get_property "XSIM.COMPILE.XVLOG.MORE_OPTIONS" $fs_obj]]
    if { {} != $more_xvlog_options } {
      set xvlog_arg_list [linsert $xvlog_arg_list end "$more_xvlog_options"]
    }
    set xvlog_cmd_str [join $xvlog_arg_list " "]

    set cmd "xvlog $xvlog_cmd_str"
    puts $fh_scr "echo \"$cmd\""

    if {$::tcl_platform(platform) == "unix"} {
      set log_cmd_str $log_filename
      set full_cmd "\$xv_path/bin/xvlog $xvlog_cmd_str 2>&1 | tee $log_cmd_str"
      puts $fh_scr "ExecStep $full_cmd"
    } else {
      set log_cmd_str " -log xvlog.log"
      puts $fh_scr "call %xv_path%/xvlog $s_dbg_sw $xvlog_cmd_str$log_cmd_str"
      puts $fh_scr "call type xvlog.log > $log_filename"
    }
  }
  
  # write vhdl prj if design contains vhdl sources 
  if { $b_contain_vhdl_srcs } {
    set vhdl_filename ${top};append vhdl_filename "_vhdl.prj"
    set vhdl_file [file normalize [file join $dir $vhdl_filename]]
    set fh_vhdl 0
    if {[catch {open $vhdl_file w} fh_vhdl]} {
      send_msg_id USF-XSim-013 ERROR "Failed to open file to write ($vhdl_file)\n"
      return 1
    }
    puts $fh_vhdl "# compile vhdl design source files"
    foreach file $::tclapp::xilinx::xsim::a_sim_vars(l_design_files) {
      set fargs       [split $file {|}]
      set type        [lindex $fargs 0]
      set file_type   [lindex $fargs 1]
      set lib         [lindex $fargs 2]
      set cmd_str     [lindex $fargs 3]
      set b_static_ip [lindex $fargs 4]
      if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
      switch $type {
        {VHDL}    { puts $fh_vhdl $cmd_str }
      }
    }
    # nosort? (vhdl)
    set b_no_sort [get_property "XSIM.COMPILE.XVHDL.NOSORT" [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]]
    if { $b_no_sort || $nosort_param || ({DisplayOnly} == $src_mgmt_mode) || ({None} == $src_mgmt_mode) } {
      puts $fh_vhdl "\n# Do not sort compile order\nnosort"
    }
    close $fh_vhdl

    set xvhdl_arg_list [list "$s_plat_sw"]
    if { [get_property "XSIM.COMPILE.XVHDL.RELAX" $fs_obj] } {
      lappend xvhdl_arg_list "--relax"
    }
    lappend xvhdl_arg_list "-prj $vhdl_filename"
    set more_xvhdl_options [string trim [get_property "XSIM.COMPILE.XVHDL.MORE_OPTIONS" $fs_obj]]
    if { {} != $more_xvhdl_options } {
      set xvhdl_arg_list [linsert $xvhdl_arg_list end "$more_xvhdl_options"]
    }
    set xvhdl_cmd_str [join $xvhdl_arg_list " "]

    set cmd "xvhdl $xvhdl_cmd_str"
    puts $fh_scr "echo \"$cmd\""

    if {$::tcl_platform(platform) == "unix"} {
      set log_cmd_str $log_filename
      set full_cmd "\$xv_path/bin/xvhdl $xvhdl_cmd_str 2>&1 | tee -a $log_cmd_str"
      puts $fh_scr "ExecStep $full_cmd"
    } else {
      set log_cmd_str " -log xvhdl.log"
      puts $fh_scr "call %xv_path%/xvhdl $s_dbg_sw $xvhdl_cmd_str$log_cmd_str"
      if { $b_contain_verilog_srcs } {
        puts $fh_scr "call type xvhdl.log >> $log_filename"
      } else {
        puts $fh_scr "call type xvhdl.log > $log_filename"
      }
    }
  }
  
  set b_sw_lib 0
  set args_list [list]
  if { [get_param "project.allowSharedLibraryType"] } {
    if {$::tcl_platform(platform) == "unix"} {
      set b_default_sw_lib 0
      foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_filesets $fs_obj]] {
        set file_dir [file dirname $file]
        set file_name [file tail $file]
        set final_file_name $file_dir\/$file_name 
        if [string match "lib*so" $file_name] {
          # remove "lib" from prefix and ".so" extension 
          set file_name [string range $file_name 3 end-3]
          set final_file_name "-l$file_name"
          set file_dir "[xcs_get_relative_file_path $file_dir $dir]"
        }
        
        if { {Shared Library} == [get_property FILE_TYPE $file] } {
          if { $b_default_sw_lib == 0 } {
            lappend args_list "\ng++ -shared -o libsls.so -L\$xv_lib_path/ -lxaxi_tlm -Wl,-rpath -Wl,\$xv_lib_path/ -lsystemc -L$file_dir\/ $final_file_name"
            # file_dir already set in g++ command? donot add
            if { [info exists a_shared_lib_dirs($file_dir) ] == 0 } {
              lappend args_list "-Wl,-rpath -Wl,$file_dir"
              set a_shared_lib_dirs($file_dir) $file_dir
            }
            incr b_default_sw_lib 1
            incr b_sw_lib 1
          } else {
            lappend args_list "-L$file_dir\/ $final_file_name"
            if { [info exists a_shared_lib_dirs($file_dir)] == 0 } {
              lappend args_list "-Wl,-rpath -Wl,$file_dir"
              set a_shared_lib_dirs($file_dir) $file_dir
            }
          }
        }
      }
    }
  }

  if { $b_sw_lib == 1} {
    puts $fh_scr [join $args_list " "]
  }
  
  if {$::tcl_platform(platform) != "unix"} {
    puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
    puts $fh_scr "if \"%errorlevel%\"==\"0\" goto SUCCESS"
    puts $fh_scr ":END"
    puts $fh_scr "exit 1"
    puts $fh_scr ":SUCCESS"
    puts $fh_scr "exit 0"
  }
  close $fh_scr
}

proc usf_xsim_write_elaborate_script { scr_filename_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $scr_filename_arg scr_filename
  variable a_xsim_vars

  set top $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)

  # write elaborate.sh/.bat
  set scr_filename "elaborate";append scr_filename [::tclapp::xilinx::xsim::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-XSim-016 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  set s_dbg_sw {}
  set dbg $::tclapp::xilinx::xsim::a_sim_vars(s_int_debug_mode)
  if { $dbg } {
    set s_dbg_sw {-dbg}
  }

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "#!/bin/bash -f"
    puts $fh_scr "xv_path=\"$::env(XILINX_VIVADO)\""
    ::tclapp::xilinx::xsim::usf_write_shell_step_fn $fh_scr
    set args [usf_xsim_get_xelab_cmdline_args]
    puts $fh_scr "ExecStep \$xv_path/bin/xelab $args"
  } else {
    puts $fh_scr "@echo off"
    puts $fh_scr "set xv_path=[::tclapp::xilinx::xsim::usf_get_rdi_bin_path]"
    set args [usf_xsim_get_xelab_cmdline_args]
    puts $fh_scr "call %xv_path%/xelab $s_dbg_sw $args"
    puts $fh_scr "if \"%errorlevel%\"==\"0\" goto SUCCESS"
    puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
    puts $fh_scr ":END"
    puts $fh_scr "exit 1"
    puts $fh_scr ":SUCCESS"
    puts $fh_scr "exit 0"
  }
  close $fh_scr
}

proc usf_xsim_write_simulate_script { cmd_file_arg wcfg_file_arg b_add_view_arg scr_filename_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $scr_filename_arg scr_filename

  upvar $cmd_file_arg cmd_file
  upvar $wcfg_file_arg wcfg_file
  upvar $b_add_view_arg b_add_view

  set top $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]

  # get the wdb file information
  set wdf_file [get_property "XSIM.SIMULATE.WDB" $fs_obj]
  if { {} == $wdf_file } {
    set wdf_file $::tclapp::xilinx::xsim::a_xsim_vars(s_snapshot);append wdf_file ".wdb"
    #set wdf_file "xsim";append wdf_file ".wdb"
  } else {
    set wdf_file [file normalize $wdf_file]
  }

  # get the wcfg file information
  set b_linked_wcfg_exist 0
  set wcfg_files [usf_get_wcfg_files $fs_obj]
  set wdb_filename [file root [file tail $wdf_file]]
  set b_wcfg_files 0
  if { [llength $wcfg_files] > 0 } {
    set b_wcfg_files 1
  }
  if { !$b_wcfg_files } {
    # check WCFG file with the same prefix name present in the WDB file
    set wcfg_file_in_wdb_dir ${wdb_filename};append wcfg_file_in_wdb_dir ".wcfg"
    #set wcfg_file_in_wdb_dir [file normalize [file join $dir $wcfg_file_in_wdb_dir]]
    if { [file exists $wcfg_file_in_wdb_dir] } {
      set b_linked_wcfg_exist 1
    }
  }

  set b_add_wave 0
  set b_add_view 0

  # wcfg file specified?
  if { $b_wcfg_files } {
    # pass -view
    set b_add_view 1
  } elseif { $b_linked_wcfg_exist } {
    # do not pass "add wave" and "-view"
  } else {
    set b_add_wave 1
  }

  set cmd_file ${top};append cmd_file ".tcl"
  usf_xsim_write_cmd_file $cmd_file $b_add_wave

  set scr_filename "simulate";append scr_filename [::tclapp::xilinx::xsim::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-XSim-018 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }
  set b_batch 1
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "#!/bin/bash -f"
    puts $fh_scr "xv_path=\"$::env(XILINX_VIVADO)\""
    ::tclapp::xilinx::xsim::usf_write_shell_step_fn $fh_scr
    # TODO: once xsim picks the "so"s path at runtime , we can remove the following code
    if { [get_param "project.allowSharedLibraryType"] } {
      set args_list [list]
      foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_filesets $fs_obj]] {
        set file_type [get_property FILE_TYPE $file]
        set file_dir [file dirname $file] 
        set file_name [file tail $file] 
        if { $file_type == "Shared Library" } {
          set file_dir "[xcs_get_relative_file_path $file_dir $dir]"
          if {[info exists a_shared_lib_dirs($file_dir)] == 0} {
            set a_shared_lib_dirs($file_dir) $file_dir
            lappend args_list "$file_dir"
          }
        }
      }
      if {[llength $args_list] != 0} {
        set cmd_args [join $args_list ":"]
        puts $fh_scr "\nexport LD_LIBRARY_PATH=$cmd_args:\$PWD:\$LD_LIBRARY_PATH\n"
      }
    }
    set cmd_args [usf_xsim_get_xsim_cmdline_args $cmd_file $wcfg_files $b_add_view $b_batch]
    puts $fh_scr "ExecStep \$xv_path/bin/xsim $cmd_args"
  } else {
    puts $fh_scr "@echo off"
    puts $fh_scr "set xv_path=[::tclapp::xilinx::xsim::usf_get_rdi_bin_path]"
    set cmd_args [usf_xsim_get_xsim_cmdline_args $cmd_file $wcfg_files $b_add_view $b_batch]
    puts $fh_scr "call %xv_path%/xsim $cmd_args"
    puts $fh_scr "if \"%errorlevel%\"==\"0\" goto SUCCESS"
    puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
    puts $fh_scr ":END"
    puts $fh_scr "exit 1"
    puts $fh_scr ":SUCCESS"
    puts $fh_scr "exit 0"
  }
  close $fh_scr

  set b_batch 0
  set cmd_args [usf_xsim_get_xsim_cmdline_args $cmd_file $wcfg_files $b_add_view $b_batch]

  if { $::tclapp::xilinx::xsim::a_sim_vars(b_scripts_only) } {
    # scripts only
  } else {
    set step "simulate"
    send_msg_id USF-XSim-061 INFO "Executing '[string toupper $step]' step in '$dir'"
    send_msg_id USF-XSim-098 INFO   "*** Running xsim\n"
    send_msg_id USF-XSim-099 STATUS "   with args \"$cmd_args\"\n"
  }

  return $cmd_args
}

proc usf_get_wcfg_files { fs_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:
  set uniq_file_set [list]
  #set wcfg_files [split [get_property "XSIM.VIEW" $fs_obj] { }]
  set filter "IS_ENABLED == 1"
  set wcfg_files [get_files -quiet -of_objects [get_filesets $fs_obj] -filter $filter *.wcfg]
  if { [llength $wcfg_files] > 0 } {
    foreach file $wcfg_files {
      set file [string map {\\ /} $file]
      if { [lsearch -exact $uniq_file_set $file] == -1 } {
        lappend uniq_file_set $file
      }
    }
  }
  return $uniq_file_set 
}

proc usf_xsim_get_xelab_cmdline_args {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set top $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)
  set sim_flow $::tclapp::xilinx::xsim::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]

  set args_list [list]

  set id [get_property ID [current_project]]
  if { {} != $id } {
    lappend args_list "-wto $id"
  }

  if { [get_property 32bit $fs_obj] } {
    lappend args_list "-m32"
  } else {
    lappend args_list "-m64"
  } 

  # --debug
  set value [get_property "XSIM.ELABORATE.DEBUG_LEVEL" $fs_obj]
  lappend args_list "--debug $value"

  # --rangecheck
  set value [get_property "XSIM.ELABORATE.RANGECHECK" $fs_obj]
  if { $value } { lappend args_list "--rangecheck" }

  # --dll
  set value [get_property "XELAB.DLL" $fs_obj]
  if { $value } { lappend args_list "--dll" }

  # --relax
  set value [get_property "XSIM.ELABORATE.RELAX" $fs_obj]
  if { $value } { lappend args_list "--relax" }

  # --mt
  set max_threads [get_param general.maxthreads]
  set mt_level [get_property "XSIM.ELABORATE.MT_LEVEL" $fs_obj]
  switch -regexp -- $mt_level {
    {auto} {
      if { {1} == $max_threads } {
        # no op, keep auto ('1' is not supported by xelab)
      } else {
        set mt_level $max_threads
      }
    }
    {off} {
      # use 'off' (turn off multi-threading)
    }
    default {
      # use 2, 4, 8, 16, 32
    }
  }
  
  lappend args_list "--mt $mt_level"

  set netlist_mode [get_property "NL.MODE" $fs_obj]

  if { ({post_synth_sim} == $sim_flow || {post_impl_sim} == $sim_flow) && ({timesim} == $netlist_mode) } {
     set delay [get_property "XSIM.ELABORATE.SDF_DELAY" $fs_obj]
     if { {sdfmin} == $delay } { lappend args_list "--mindelay" }
     if { {sdfmax} == $delay } { lappend args_list "--maxdelay" }
  }
 
  # --include
  #set prefix_ref_dir "false"
  #foreach incl_dir [::tclapp::xilinx::xsim::usf_get_include_file_dirs $::tclapp::xilinx::xsim::a_sim_vars(global_files_value) $prefix_ref_dir] {
  #  set dir [string map {\\ /} $incl_dir]
  #  lappend args_list "--include \"$dir\""
  #}
  
  if { [get_param "project.allowSharedLibraryType"] } {
    if {$::tcl_platform(platform) == "unix"} {
      foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_filesets $fs_obj]] {
        if { {Shared Library} == [get_property FILE_TYPE $file] } {
          lappend args_list "--sv_root \".\/\" -sv_lib libsls.so"
          break
        }
      }
    }
  }	

  # -i
  #set unique_incl_dirs [list]
  #foreach incl_dir [get_property "INCLUDE_DIRS" $fs_obj] {
  #  if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
  #    lappend unique_incl_dirs $incl_dir
  #    lappend args_list "-i $incl_dir"
  #  }
  #}

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
      lappend args_list "-d \"$str\""
    }
  }

  # -generic_top (verilog macros)
  set v_generics [get_property "GENERIC" $fs_obj]
  if { [llength $v_generics] > 0 } {
    foreach element $v_generics {
      set key_val_pair [split $element "="]
      set name [lindex $key_val_pair 0]
      set val  [lindex $key_val_pair 1]
      set str "$name="
      if { [string length $val] > 0 } {
        set str "$str$val"
      }
      lappend args_list "-generic_top \"$str\""
    }
  }

  # design source libs
  set design_libs [usf_xsim_get_design_libs $::tclapp::xilinx::xsim::a_sim_vars(l_design_files)]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend args_list "-L $lib"
  }

  # add simulation libraries
  # post* simulation
  if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    if { [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || ({Verilog} == $target_lang) } {
      if { {timesim} == $netlist_mode } {
        lappend args_list "-L simprims_ver"
      } else {
        lappend args_list "-L unisims_ver"
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
      lappend args_list "-L unifast"
    }
  }

  set b_compile_unifast [get_property "unifast" $fs_obj]
  if { ([xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast } {
      lappend args_list "-L unifast_ver"
    }
    lappend args_list "-L unisims_ver"
    lappend args_list "-L unimacro_ver"
  }

  # add secureip
  lappend args_list "-L secureip"

  # snapshot
  lappend args_list "--snapshot $::tclapp::xilinx::xsim::a_xsim_vars(s_snapshot)"

  set path_delay 0
  set int_delay 0
  set tpd_prop "TRANSPORT_PATH_DELAY"
  set tid_prop "TRANSPORT_INT_DELAY"
  if { [lsearch -exact [list_property $fs_obj] $tpd_prop] != -1 } {
    set path_delay [get_property $tpd_prop $fs_obj]
  }
  if { [lsearch -exact [list_property $fs_obj] $tid_prop] != -1 } {
    set int_delay [get_property $tid_prop $fs_obj]
  }

  # avoid pulse swallowing for timing
  if { ({post_synth_sim} == $sim_flow || {post_impl_sim} == $sim_flow) && ({timesim} == $netlist_mode) } {
    lappend args_list "-transport_int_delays"
    lappend args_list "-pulse_r $path_delay"
    lappend args_list "-pulse_int_r $int_delay"
  }

  # add top's
  set top_level_inst_names [usf_xsim_get_top_level_instance_names]
  foreach top $top_level_inst_names {
    lappend args_list "$top"
  }

  # add glbl top
  usf_add_glbl_top_instance args_list $top_level_inst_names
  lappend args_list "-log elaborate.log"

  # other options
  set other_opts [get_property "XSIM.ELABORATE.XELAB.MORE_OPTIONS" $fs_obj]
  if { {} != $other_opts } {
    lappend args_list "$other_opts"
  }

  set cmd_args [join $args_list " "]
  return $cmd_args
}

proc usf_add_glbl_top_instance { opts_arg top_level_inst_names } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set fs_obj [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]
  upvar $opts_arg opts 
  set sim_flow $::tclapp::xilinx::xsim::a_sim_vars(s_simulation_flow)
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

  if { [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $b_verilog_sim_netlist } {
    if { {behav_sim} == $sim_flow } {
      set b_load_glbl [get_property "XSIM.ELABORATE.LOAD_GLBL" $fs_obj]
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

  if { $b_add_glbl } {
    set top_lib [::tclapp::xilinx::xsim::usf_get_top_library]
    # for post* top_lib is xil_defaultlib for glbl since it is compiled inside netlist
    if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
      set top_lib "xil_defaultlib"
    }
    lappend opts "${top_lib}.glbl"
  }
}

proc usf_xsim_get_xsim_cmdline_args { cmd_file wcfg_files b_add_view b_batch } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)
  set sim_flow $::tclapp::xilinx::xsim::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]
  set snapshot $::tclapp::xilinx::xsim::a_xsim_vars(s_snapshot)

  set args_list [list]
  lappend args_list $snapshot

  lappend args_list "-key"
  lappend args_list "\{[usf_xsim_get_running_simulation_obj_key]\}"

  set user_cmd_file [get_property "XSIM.TCLBATCH" $fs_obj]
  if { {} != $user_cmd_file } {
    set cmd_file $user_cmd_file
  }
  lappend args_list "-tclbatch"
  if { $b_batch } {
    lappend args_list "$cmd_file" 
  } else {
    lappend args_list "\{$cmd_file\}" 
  }
  if { $b_add_view } {
    foreach wcfg_file $wcfg_files {
      if { ![file exists $wcfg_file] } {
        send_msg_id USF-XSim-017 WARNING "WCFG file does not exist:$wcfg_file\n"
        continue;
      }
      lappend args_list "-view"
      if { $b_batch } {
        lappend args_list "$wcfg_file"
      } else {
        lappend args_list "\{$wcfg_file\}"
      }
    }
  }
  #set log_file ${snapshot};append log_file ".log"
  set log_file "simulate";append log_file ".log"
  lappend args_list "-log"
  if { $b_batch } {
    lappend args_list "$log_file"
  } else {
    lappend args_list "\{$log_file\}"
  }

  # more options
  set more_sim_options [string trim [get_property "XSIM.SIMULATE.XSIM.MORE_OPTIONS" $fs_obj]]
  if { {} != $more_sim_options } {
    lappend args_list $more_sim_options
  }
  set cmd_args [join $args_list " "]
  return $cmd_args
}

proc usf_xsim_write_cmd_file { cmd_filename b_add_wave } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)
  set sim_flow $::tclapp::xilinx::xsim::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]
  set cmd_file [file normalize [file join $dir $cmd_filename]]
  set fh_scr 0
  if {[catch {open $cmd_file w} fh_scr]} {
    send_msg_id USF-XSim-019 ERROR "Failed to open file to write ($cmd_file)\n"
    return 1
  }

  set dbg_level [get_property "XSIM.ELABORATE.DEBUG_LEVEL" $fs_obj]
  if { {off} == $dbg_level } {
    # keeping this if block, in case any specific change required for this case later
  } else {
    puts $fh_scr "set curr_wave \[current_wave_config\]"
    puts $fh_scr "if \{ \[string length \$curr_wave\] == 0 \} \{"
    puts $fh_scr "  if \{ \[llength \[get_objects\]\] > 0\} \{"
    puts $fh_scr "    add_wave /"
    puts $fh_scr "    set_property needs_save false \[current_wave_config\]"
    puts $fh_scr "  \} else \{"
    puts $fh_scr "     send_msg_id Add_Wave-1 WARNING \"No top level signals found. Simulator will start without a wave window. If you want to open a wave window go to 'File->New Waveform Configuration' or type 'create_wave_config' in the TCL console.\""
    puts $fh_scr "  \}"
    puts $fh_scr "\}"
  }

  set b_post_sim 0
  if { ({functional} == $::tclapp::xilinx::xsim::a_sim_vars(s_type)) || \
       ({timing} == $::tclapp::xilinx::xsim::a_sim_vars(s_type)) } {
    set b_post_sim 1
  }
  # generate saif file for power estimation
  set saif [get_property "XSIM.SIMULATE.SAIF" $fs_obj]
  set b_all_signals [get_property "XSIM.SIMULATE.SAIF_ALL_SIGNALS" $fs_obj]
  if { {} != $saif } {
    set uut [get_property "XSIM.SIMULATE.UUT" $fs_obj]
    puts $fh_scr "\nopen_saif \"$saif\""
    if { {} != $uut } {
      set uut_name [::tclapp::xilinx::xsim::usf_resolve_uut_name_with_scope uut]
      puts $fh_scr "set curr_xsim_wave_scope \[current_scope\]"
      puts $fh_scr "current_scope $uut_name"
    }

    if { $b_post_sim } {
      puts $fh_scr "log_saif \[get_objects -r *\]"
    } else {
      if { $b_all_signals } {
        puts $fh_scr "log_saif \[get_objects -r *\]"
      } else {
        set filter "-filter \{type==in_port || type==out_port || type==inout_port\}"
        puts $fh_scr "log_saif \[get_objects $filter *\]"
      }
    }
    if { {} != $uut } {
      puts $fh_scr "current_scope \$curr_xsim_wave_scope"
      puts $fh_scr "unset curr_xsim_wave_scope"
    }
  }

  set rt [string trim [get_property "XSIM.SIMULATE.RUNTIME" $fs_obj]]
  if { {} == $rt } {
    # no runtime specified
    # puts $fh_scr "\nrun all"
  } else {
    set rt_value [string tolower $rt]
    if { ({all} == $rt_value) || (![regexp {^[0-9]} $rt_value]) } {
      puts $fh_scr "\nrun all"
    } else {
      puts $fh_scr "\nrun $rt"
    }
  }

  if { {} != $saif } {
    puts $fh_scr "close_saif"
  }

  # add TCL sources
  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\""
  ::tclapp::xilinx::xsim::usf_find_files tcl_src_files $filter
  if {[llength $tcl_src_files] > 0} {
    puts $fh_scr ""
    foreach file $tcl_src_files {
       puts $fh_scr "source -notrace \{$file\}"
    }
    puts $fh_scr ""
  }
    
  if { $::tclapp::xilinx::xsim::a_sim_vars(b_scripts_only) } {
    puts $fh_scr "quit"
  }
  close $fh_scr
}

proc usf_xsim_get_running_simulation_obj_key {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
  set mode [usf_xsim_get_sim_mode_as_pretty_str $::tclapp::xilinx::xsim::a_sim_vars(s_mode)]
  set flow_type [usf_xsim_get_sim_flow_type_as_pretty_str $::tclapp::xilinx::xsim::a_sim_vars(s_type)]
  set fs_obj [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]
  set fs_name [get_property "NAME" $fs_obj]

  if { {Unknown} == $flow_type } {
    set flow_type "Functional"  
  }

  set key $mode;append key {:};append key $fs_name;append key {:};append key $flow_type;append key {:};append key $top
  return $key
} 

proc usf_xsim_get_snapshot {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set snapshot [get_property "XSIM.ELABORATE.SNAPSHOT" [get_filesets $a_sim_vars(s_simset)]]
  if { ({<Default>} == $snapshot) || ({} == $snapshot) } {
    set snapshot $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
    switch -regexp -- $::tclapp::xilinx::xsim::a_sim_vars(s_simulation_flow) {
      {behav_sim} {
        set snapshot [append snapshot "_behav"]
      }
      {post_synth_sim} -
      {post_impl_sim} {
        switch -regexp -- $a_sim_vars(s_type) {
          {functional} { set snapshot [append snapshot "_func"] }
          {timing}     { set snapshot [append snapshot "_time"] }
          default      { set snapshot [append snapshot "_unknown"] }
        }
      }
    }
    switch -regexp -- $::tclapp::xilinx::xsim::a_sim_vars(s_simulation_flow) {
      {post_synth_sim} { set snapshot [append snapshot "_synth"] }
      {post_impl_sim}  { set snapshot [append snapshot "_impl"] }
    }
  }
  return $snapshot
}

proc usf_xsim_get_top_level_instance_names {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set top_level_instance_names [list]
  set top $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
  set top_lib [::tclapp::xilinx::xsim::usf_get_top_library]
  set top_names [split $top " "]
  if { [llength $top_names] > 1 } {
    foreach name $top_names {
      if { [lsearch $top_level_instance_names $name] == -1 } {
        lappend top_level_instance_names [usf_get_top_name $name $top_lib]
      }
    }
  } else {
    set name $top_names
    lappend top_level_instance_names [usf_get_top_name $name $top_lib]
  }
  return $top_level_instance_names
}

proc usf_get_top_name { name top_lib } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  set top {}
  # check if top defines the library already (mylib.top)
  set lib {}
  if { [regexp {\.} $name] } {
    set lib [lindex [split $name "."] 0]
  }
  # if library already prefixed, append lib.top name as is, else prefix it
  if { $lib == $top_lib } {
    # name already contains library, return the name as is
    set top $name
  } else {
    # name does not contain library, append library
    set top "${top_lib}.$name"
  }
  return $top
}

proc usf_xsim_get_sim_flow_type_as_pretty_str { type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set flow_type [string tolower $type]
  set ft {Unknown}
  if { {functional} == $flow_type } {
    set ft "Functional"
  } elseif { {timing} == $flow_type } {
    set ft "Timing"
  }
  return $ft
}

proc usf_xsim_get_sim_mode_as_pretty_str { mode } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set mode_type [string tolower $mode]
  set ms {}
  if { {behavioral} == $mode_type } {
    set ms "Behavioral"
  } elseif { {post-synthesis} == $mode_type } {
    set ms "Post-Synthesis"
  } elseif { {post-implementation} == $mode_type } {
    set ms "Post-Implementation"
  } else {
    set ms "Unknown"
  }
  return $ms
}

proc usf_xsim_get_design_libs { design_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set libs [list]
  foreach file $design_files {
    set fargs     [split $file {|}]
    set type      [lindex $fargs 0]
    set file_type [lindex $fargs 1]
    set library   [lindex $fargs 2]
    set cmd_str   [lindex $fargs 3]
    if { {} == $library } {
      continue;
    }
    if { [lsearch -exact $libs $library] == -1 } {
      lappend libs $library
    }
  }
  return $libs
}

proc usf_xsim_map_pre_compiled_libs { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set lib_path [get_property sim.ipstatic.compiled_library_dir [current_project]]
  set ini_file [file join $lib_path "xsim.ini"]
  if { ![file exists $ini_file] } {
    return
  }

  set fh_ini 0
  if { [catch {open $ini_file r} fh_ini] } {
    send_msg_id USF-XSim-099 WARNING "Failed to open file for read ($ini_file)\n"
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
      if { [regexp "=" $line] } {
        puts $fh "$line"
      }
    }
  }
}

proc usf_xsim_include_xvhdl_log {} {
  # Summary: copy xvhdl log into compile log for windows
  # Argument Usage:
  # Return Value:

  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)

  if {$::tcl_platform(platform) == "unix"} {
    # for unix, compile log redirection is taken care by unix commands
  } else {
    # for windows, append xvhdl log to compile.log
    set compile_log [file normalize [file join $dir "compile.log"]]
    set xvhdl_log [file normalize [file join $dir "xvhdl.log"]]
    if { [file exists $xvhdl_log] } {
      set fh 0
      if {[catch {open $xvhdl_log r} fh]} {
        send_msg_id USF-XSim-100 ERROR "Failed to open file for read ($xvhdl_log)\n"
      } else {
        set data [read $fh]
        set log_data [split $data "\n"]
        close $fh
  
        # open compile.log for append
        set fh 0
        if {[catch {open $compile_log a} fh]} {
          send_msg_id USF-XSim-101 ERROR "Failed to open file for append ($compile_log)\n"
        } else {
          foreach line $log_data {
            puts $fh [string trim $line]
          }
          close $fh
        }
      }
    }
  }
}
}
