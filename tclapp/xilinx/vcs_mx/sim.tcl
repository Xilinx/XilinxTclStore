######################################################################
#
# sim.tcl (simulation script for the 'Synopsys VCS_MX Simulator')
#
# Script created on 01/06/2014 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev 1)
#  * initial version
#
######################################################################
package require Vivado 2013.1
package require ::tclapp::xilinx::vcs_mx::helpers

namespace eval ::tclapp::xilinx::vcs_mx {
proc setup { args } {
  # Summary: initialize global vars and prepare for simulation
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # true (0) if success, false (1) otherwise

  # initialize global variables
  ::tclapp::xilinx::vcs_mx::usf_init_vars

  # initialize IES simulator variables
  usf_vcs_mx_init_simulation_vars

  # read simulation command line args and set global variables
  usf_vcs_mx_setup_args $args

  # perform initial simulation tasks
  if { [usf_vcs_mx_setup_simulation] } {
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

  usf_vcs_mx_write_compile_script
  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::vcs_mx::usf_launch_script "vcs_mx" $step
}

proc elaborate { args } {
  # Summary: run the elaboration step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  send_msg_id Vivado-VCS_MX-003 INFO "vcs_mx::elaborate design"
  usf_vcs_mx_write_elaborate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::vcs_mx::usf_launch_script "vcs_mx" $step
}

proc simulate { args } {
  # Summary: run the simulation step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  send_msg_id Vivado-VCS_MX-004 INFO "vcs_mx::simulate design"
  usf_vcs_mx_write_simulate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::vcs_mx::usf_launch_script "vcs_mx" $step
}
}

#
# VCS_MX simulation flow
#
namespace eval ::tclapp::xilinx::vcs_mx {
proc usf_vcs_mx_setup_simulation { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  ::tclapp::xilinx::vcs_mx::usf_set_simulator_path "vcs_mx"

  # set the simulation flow
  ::tclapp::xilinx::vcs_mx::usf_set_simulation_flow

  # set the simulation run dir
  ::tclapp::xilinx::vcs_mx::usf_set_run_dir

  # set default object
  if { [::tclapp::xilinx::vcs_mx::usf_set_sim_tcl_obj] } {
    puts "failed to set tcl obj"
    return 1
  }

  # print launch_simulation arg values
  #::tclapp::xilinx::vcs_mx::usf_print_args

  # write functional/timing netlist for post-* simulation
  ::tclapp::xilinx::vcs_mx::usf_write_design_netlist

  # prepare IP's for simulation
  ::tclapp::xilinx::vcs_mx::usf_prepare_ip_for_simulation

  usf_vcs_mx_verify_compiled_lib

  # fetch the compile order for the specified object
  ::tclapp::xilinx::vcs_mx::usf_get_compile_order_for_obj

  # create setup file
  usf_vcs_mx_write_setup_files

  return 0
}

proc usf_vcs_mx_init_simulation_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_vcs_mx_sim_vars
  set a_vcs_mx_sim_vars(b_32bit)            0
  set a_vcs_mx_sim_vars(s_compiled_lib_dir) {}
}

proc usf_vcs_mx_setup_args { args } {
  # Summary:
  # 

  # Argument Usage:
  # [-simset <arg>]: Name of the simulation fileset
  # [-mode <arg>]: Simulation mode. Values: behavioral, post-synthesis, post-implementation
  # [-type <arg>]: Netlist type. Values: functional, timing. This is only applicable when mode is set to post-synthesis or post-implementation
  # [-scripts_only]: Only generate scripts
  # [-of_objects <arg>]: Generate do file for this object (applicable with -scripts_only option only)
  # [-absolute_path]: Make all file paths absolute wrt the reference directory
  # [-install_path <arg>]: Custom VCS_MX installation directory path
  # [-batch]: Execute batch flow simulation run (non-gui)
  # [-int_os_type]: OS type (32 or 64) (internal use)
  # [-int_debug_mode]: Debug mode (internal use)

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: xilinxtclstore, vcs_mx

  set args [string trim $args "\}\{"]

  # process options
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-simset"         { incr i;set ::tclapp::xilinx::vcs_mx::a_sim_vars(s_simset) [lindex $args $i] }
      "-mode"           { incr i;set ::tclapp::xilinx::vcs_mx::a_sim_vars(s_mode) [lindex $args $i] }
      "-type"           { incr i;set ::tclapp::xilinx::vcs_mx::a_sim_vars(s_type) [lindex $args $i] }
      "-scripts_only"   { set ::tclapp::xilinx::vcs_mx::a_sim_vars(b_scripts_only) 1 }
      "-of_objects"     { incr i;set ::tclapp::xilinx::vcs_mx::a_sim_vars(s_comp_file) [lindex $args $i]}
      "-absolute_path"  { set ::tclapp::xilinx::vcs_mx::a_sim_vars(b_absolute_path) 1 }
      "-install_path"   { incr i;set ::tclapp::xilinx::vcs_mx::a_sim_vars(s_install_path) [lindex $args $i] }
      "-batch"          { set ::tclapp::xilinx::vcs_mx::a_sim_vars(b_batch) 1 }
      "-int_os_type"    { incr i;set ::tclapp::xilinx::vcs_mx::a_sim_vars(s_int_os_type) [lindex $args $i] }
      "-int_debug_mode" { incr i;set ::tclapp::xilinx::vcs_mx::a_sim_vars(s_int_debug_mode) [lindex $args $i] }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id Vivado-VCS_MX-005 ERROR "Unknown option '$option', please type 'simulate -help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

proc usf_vcs_mx_verify_compiled_lib {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set syn_file "synopsys_sim.setup"
  set compiled_lib_dir {}
  send_msg_id Vivado-VCS_MX-006 INFO "Finding pre-compiled libraries...\n"
  # check property value
  set dir [get_property "COMPXLIB.COMPILED_LIBRARY_DIR" [current_project]]
  set syn_file [file normalize [file join $dir $syn_file]]
  if { [file exists $syn_file] } {
    set compiled_lib_dir $dir
  }
  # check param
  if { {} == $compiled_lib_dir } {
    set dir [get_param "simulator.compiled_library_dir"]
    set file [file normalize [file join $dir $syn_file]]
    if { [file exists $file] } {
      set compiled_lib_dir $dir
    }
  }
  # return if found, else warning
  if { {} != $compiled_lib_dir } {
   set ::tclapp::xilinx::vcs_mx::a_vcs_mx_sim_vars(s_compiled_lib_dir) $compiled_lib_dir
   send_msg_id Vivado-VCS_MX-007 INFO "Compiled library path:'$compiled_lib_dir'\n"
   return
  }
  send_msg_id Vivado-VCS_MX-008 "CRITICAL WARNING" "Failed to find the pre-compiled simulation library information!\n"
  send_msg_id Vivado-VCS_MX-009 INFO "Please set the 'COMPXLIB.COMPILED_LIBRARY_DIR' project property to the directory where Xilinx simulation libraries are compiled.\n"
}

proc usf_vcs_mx_write_setup_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::vcs_mx::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::vcs_mx::a_sim_vars(s_launch_dir)
  set filename "synopsys_sim.setup"
  set file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id Vivado-VCS_MX-010 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  set lib_map_path $::tclapp::xilinx::vcs_mx::a_vcs_mx_sim_vars(s_compiled_lib_dir)
  if { {} == $lib_map_path } {
    set lib_map_path "?"
  }
  puts $fh "OTHERS=$lib_map_path/$filename"
  set libs [list]
  foreach lib [::tclapp::xilinx::vcs_mx::usf_get_compile_order_libs] {
    if {[string length $lib] == 0} { continue; }
    if { ({work} == $lib) && ({vcs_mx} == $simulator) } { continue; }
    lappend libs [string tolower $lib]
  }
  set dir_name "vcs_mx"
  foreach lib_name $libs {
    set lib_dir [file join $dir_name $lib_name]
    set lib_dir_path [file normalize [string map {\\ /} [file join $dir $lib_dir]]]
    if { ! [file exists $lib_dir_path] } {
      if {[catch {file mkdir $lib_dir_path} error_msg] } {
        send_msg_id Vivado-VCS_MX-011 ERROR "failed to create the directory ($lib_dir_path): $error_msg\n"
        return 1
      }
    }
    puts $fh "$lib_name : $lib_dir"
  }
  close $fh
}

proc usf_vcs_mx_write_compile_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::vcs_mx::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::vcs_mx::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::vcs_mx::a_sim_vars(s_simset)]
  set default_lib [get_property "DEFAULT_LIB" [current_project]]
  set scr_filename "compile";append scr_filename [::tclapp::xilinx::vcs_mx::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id Vivado-VCS_MX-012 ERROR "failed to open file to write ($scr_file)\n"
    return 1
  }
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "#!/bin/sh -f"
    ::tclapp::xilinx::vcs_mx::usf_write_script_header_info $fh_scr $scr_file
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"$::tclapp::xilinx::vcs_mx::a_sim_vars(s_tool_bin_path)\"\n"
  } else {
    puts $fh_scr "@echo off"
    puts $fh_scr "set bin_path=\"$::tclapp::xilinx::vcs_mx::a_sim_vars(s_tool_bin_path)\""
  }

  ::tclapp::xilinx::vcs_mx::usf_set_ref_dir $fh_scr
  set tool "vhdlan"
  set arg_list [list "-l" "${tool}.log"]
  if { !$::tclapp::xilinx::vcs_mx::a_vcs_mx_sim_vars(b_32bit) } {
    set arg_list [linsert $arg_list 0 "-full64"]
  }
  puts $fh_scr "# set ${tool} command line args"
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  } else {
    puts $fh_scr "set ${tool}_opts=\"[join $arg_list " "]\""
  }
  set tool "vlogan"
  set arg_list [list "-l" "${tool}.log"]
  if { !$::tclapp::xilinx::vcs_mx::a_vcs_mx_sim_vars(b_32bit) } {
    set arg_list [linsert $arg_list 0 "-full64"]
  }
  puts $fh_scr "\n# set ${tool} command line args"
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\"\n"
  } else {
    puts $fh_scr "set ${tool}_opts=\"[join $arg_list " "]\"\n"
  }

  set files [::tclapp::xilinx::vcs_mx::usf_uniquify_cmd_str [::tclapp::xilinx::vcs_mx::usf_get_files_for_compilation]]
  puts $fh_scr "# compile design source files"
  foreach file $files {
    set type    [lindex [split $file {#}] 0]
    set lib     [lindex [split $file {#}] 1]
    set cmd_str [lindex [split $file {#}] 2]
    puts $fh_scr "\$bin_path/$cmd_str"
  }
  # compile glbl file
  set b_load_glbl [get_property "VCS_MX.COMPILE.LOAD_GLBL" $fs_obj]
  if { [::tclapp::xilinx::vcs_mx::usf_compile_glbl_file "vcs_mx" $b_load_glbl] } {
    set work_lib_sw {}
    if { {work} != $default_lib } {
      set work_lib_sw "-work $default_lib "
    }
    set file_str "${work_lib_sw}\"[::tclapp::xilinx::vcs_mx::usf_get_glbl_file]\""
    puts $fh_scr "\n# compile glbl module\n\$bin_path/vlogan \$vlogan_opts +v2k $file_str"
  }
  close $fh_scr
}

proc usf_vcs_mx_write_elaborate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::vcs_mx::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::vcs_mx::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::vcs_mx::a_sim_vars(s_simset)]
  set scr_filename "elaborate";append scr_filename [::tclapp::xilinx::vcs_mx::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id Vivado-VCS_MX-013 ERROR "failed to open file to write ($scr_file)\n"
    return 1
  }
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "#!/bin/sh -f"
    ::tclapp::xilinx::vcs_mx::usf_write_script_header_info $fh_scr $scr_file
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"$::tclapp::xilinx::vcs_mx::a_sim_vars(s_tool_bin_path)\"\n"
  } else {
    puts $fh_scr "set bin_path=\"$::tclapp::xilinx::vcs_mx::a_sim_vars(s_tool_bin_path)\""
  }
  set tool "vcs"
  set top_lib [::tclapp::xilinx::vcs_mx::usf_get_top_library]
  set arg_list [list]
  if { [get_property "VCS_MX.ELABORATE.DEBUG_PP" $fs_obj] } {
    lappend arg_list {-debug_pp}
  }
  set arg_list [linsert $arg_list end "-t" "ps" "-licwait" "-60" "-l" "elaborate.log"]
  if { !$::tclapp::xilinx::vcs_mx::a_vcs_mx_sim_vars(b_32bit) } {
     set arg_list [linsert $arg_list 0 "-full64"]
  }

  # design contains ax-bfm ip? insert bfm library
  if { [::tclapp::xilinx::vcs_mx::usf_is_axi_bfm_ip] } {
    set simulator_lib [usf_get_simulator_lib_for_bfm]
    if { {} != $simulator_lib } {
      set arg_list [linsert $arg_list 0 "-load \"$simulator_lib:xilinx_register_systf\""]
    } else {
      send_msg_id Vivado-VCS_MX-014 ERROR "Failed to locate simulator library from 'XILINX' environment variable."
    }
  }

  puts $fh_scr "# set ${tool} command line args"
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\"\n"
  } else {
    puts $fh_scr "set ${tool}_opts=\"[join $arg_list " "]\"\n"
  }
  set tool_path "\$bin_path/$tool"
  set arg_list [list "${tool_path}" "\$${tool}_opts" "${top_lib}.$top"]
  if { [::tclapp::xilinx::vcs_mx::usf_contains_verilog] } {
    lappend arg_list "${top_lib}.glbl"
  }
  lappend arg_list "-o"
  lappend arg_list "${top}_simv"
  set cmd_str [join $arg_list " "]

  puts $fh_scr "# run elaboration"
  puts $fh_scr "$cmd_str"
  close $fh_scr
}

proc usf_vcs_mx_write_simulate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::vcs_mx::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::vcs_mx::a_sim_vars(s_launch_dir)
  set filename "simulate";append filename ".sh"
  set file [file normalize [file join $dir $filename]]
  set fh_scr 0
  if {[catch {open $file w} fh_scr]} {
    send_msg_id Vivado-VCS_MX-015 ERROR "failed to open file to write ($file)\n"
    return 1
  }
 
  puts $fh_scr "#!/bin/sh -f"
  ::tclapp::xilinx::vcs_mx::usf_write_script_header_info $fh_scr $file
  puts $fh_scr "\n# installation path setting"
  puts $fh_scr "bin_path=\"$::tclapp::xilinx::vcs_mx::a_sim_vars(s_tool_bin_path)\"\n"
  set do_filename "${top}.do"
  ::tclapp::xilinx::vcs_mx::usf_create_do_file "vcs_mx" $do_filename
  set tool "${top}_simv"
  set top_lib [::tclapp::xilinx::vcs_mx::usf_get_top_library]
  set arg_list [list "-ucli" "-licwait" "-60" "-l" "simulate.log"]

  puts $fh_scr "# set ${tool} command line args"
  puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  puts $fh_scr ""
  set arg_list [list "./${top}_simv"]
  if { $::tclapp::xilinx::vcs_mx::a_sim_vars(b_batch) } {
    # no gui
  } else {
    set arg_list [linsert $arg_list end "-gui"]
  }
  set arg_list [list $arg_list "\$${tool}_opts" "-do" "$do_filename"]
  set cmd_str [join $arg_list " "]

  puts $fh_scr "# run simulation"
  puts $fh_scr "$cmd_str"
  close $fh_scr
}
}
