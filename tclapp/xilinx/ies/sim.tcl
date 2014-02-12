####################################################################################################
# COPYRIGHT NOTICE
# Copyright 2001-2014 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
#
# Date Created     :  01/01/2014
# Script name      :  sim.tcl
# Tool Version     :  Vivado 2014.1
# Description      :  Simulation flow for "IES" Simulator
# Revision History :
#   01/01/2014 1.0  - Initial version
#
####################################################################################################
package require Vivado 2013.1
package require ::tclapp::xilinx::ies::helpers

#
# Main Launch Steps
#
namespace eval ::tclapp::xilinx::ies {
proc setup { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # initialize global variables
  ::tclapp::xilinx::ies::usf_init_vars

  # initialize IES simulator variables
  usf_ies_init_simulation_vars

  # read simulation command line args and set global variables
  usf_ies_setup_args $args

  # perform initial simulation tasks
  if { [usf_ies_setup_simulation] } {
    return 1
  }
  return 0
}

proc compile { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  usf_ies_write_compile_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::ies::usf_launch_script "ies" $step
}

proc elaborate { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  send_msg_id Vivado-IES-999 INFO "ies::elaborate design"

  usf_ies_write_elaborate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::ies::usf_launch_script "ies" $step
  return 0
}

proc simulate { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  send_msg_id Vivado-IES-999 INFO "ies::simulate design"

  usf_ies_write_simulate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::ies::usf_launch_script "ies" $step

  return 0
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
  ::tclapp::xilinx::ies::usf_set_simulation_flow
	
  # set the simulation run dir
  ::tclapp::xilinx::ies::usf_set_run_dir

  # create simulation launch dir <project>/<project.sim>/<simset>/<mode>/<type>
  ::tclapp::xilinx::ies::usf_create_launch_dir

  # set default object
  if { [::tclapp::xilinx::ies::usf_set_sim_tcl_obj] } {
    puts "failed to set tcl obj"
    return 1
  }

  # print launch_simulation arg values
  ::tclapp::xilinx::ies::usf_print_args

  # write functional/timing netlist for post-* simulation
  ::tclapp::xilinx::ies::usf_write_design_netlist

  # prepare IP's for simulation
  ::tclapp::xilinx::ies::usf_prepare_ip_for_simulation

  usf_ies_verify_compiled_lib

  # fetch the compile order for the specified object
  ::tclapp::xilinx::ies::usf_get_compile_order_for_obj

  # create setup file
  usf_ies_write_setup_files

  return 0
}

proc usf_ies_init_simulation_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_ies_sim_vars

  set a_ies_sim_vars(b_32bit)  0
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
  # [-install_path <arg>]: Custom IES installation directory path
  # [-noclean_dir]: Do not remove simulation run directory files
  # [-batch]: Execute batch flow simulation run (non-gui)
  # [-int_os_type]: OS type (32 or 64) (internal use)
  # [-int_debug_mode]: Debug mode (internal use)

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: xilinxtclstore, ies

  set args [string trim $args "\}\{"]

  # process options
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-simset"         { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_simset) [lindex $args $i] }
      "-mode"           { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_mode) [lindex $args $i] }
      "-type"           { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_type) [lindex $args $i] }
      "-scripts_only"   { set ::tclapp::xilinx::ies::a_sim_vars(b_scripts_only) 1 }
      "-of_objects"     { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_comp_file) [lindex $args $i]}
      "-absolute_path"  { set ::tclapp::xilinx::ies::a_sim_vars(b_absolute_path) 1 }
      "-install_path"   { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_install_path) [lindex $args $i] }
      "-noclean_dir"    { set ::tclapp::xilinx::ies::a_sim_vars(b_noclean_dir) 1 }
      "-batch"          { set ::tclapp::xilinx::ies::a_sim_vars(b_batch) 1 }
      "-int_os_type"    { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_int_os_type) [lindex $args $i] }
      "-int_debug_mode" { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_int_debug_mode) [lindex $args $i] }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id Vivado-IES-999 ERROR "Unknown option '$option', please type 'simulate -help' for usage info.\n"
          return 1
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

  set cds_file "cds.lib"
  set compiled_lib_dir {}
  send_msg_id Vivado-ies-999 INFO "Finding pre-compiled libraries...\n"
  # check property value
  set dir [get_property "COMPXLIB.COMPILED_LIBRARY_DIR" [current_project]]
  set file [file normalize [file join $dir $cds_file]]
  if { [file exists $cds_file] } {
    set compiled_lib_dir $dir
  }
  # check param
  if { {} == $compiled_lib_dir } {
    set dir [get_param "simulator.compiled_library_dir"]
    set file [file normalize [file join $dir $cds_file]]
    if { [file exists $file] } {
      set compiled_lib_dir $dir
    }
  }
  # return if found, else warning
  if { {} != $compiled_lib_dir } {
   set ::tclapp::xilinx::ies::a_ies_sim_vars(s_compiled_lib_dir) $compiled_lib_dir
   send_msg_id Vivado-ies-999 INFO "Compiled library path:'dir'\n"
   return
  }
  send_msg_id Vivado-ies-999 "CRITICAL WARNING" "Failed to find the pre-compiled simulation library information!\n"
  send_msg_id Vivado-ies-999 INFO "Please set the 'COMPXLIB.COMPILED_LIBRARY_DIR' project property to the directory where Xilinx simulation libraries are compiled.\n"
}

proc usf_ies_write_setup_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::ies::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)

  #
  # cds.lib
  #
  set filename "cds.lib"
  set file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id Vivado-IES-999 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  puts $fh "INCLUDE $::tclapp::xilinx::ies::a_ies_sim_vars(s_compiled_lib_dir)/$filename"
  set libs [list]
  foreach lib [::tclapp::xilinx::ies::usf_get_compile_order_libs] {
    if {[string length $lib] == 0} { continue; }
    lappend libs [string tolower $lib]
  }
  set dir_name "ies"
  foreach lib_name $libs {
    set lib_dir [file join $dir_name $lib_name]
    set lib_dir_path [file normalize [string map {\\ /} [file join $dir $lib_dir]]]
    if { ! [file exists $lib_dir_path] } {
      if {[catch {file mkdir $lib_dir_path} error_msg] } {
        send_msg_id Vivado-IES-999 ERROR "failed to create the directory ($lib_dir_path): $error_msg\n"
        return 1
      }
    }
    puts $fh "DEFINE $lib_name $lib_dir"
  }
  close $fh

  #
  # hdl.var
  #
  set filename "hdl.var"
  set file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id Vivado-IES-999 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  close $fh
}

proc usf_ies_write_compile_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::ies::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)
  set default_lib [get_property "DEFAULT_LIB" [current_project]]

  set filename "compile";append filename [::tclapp::xilinx::ies::usf_get_script_extn]
  set file [file normalize [file join $dir $filename]]
  set fh_scr 0

  if {[catch {open $file w} fh_scr]} {
    send_msg_id Vivado-IES-999 ERROR "failed to open file to write ($file)\n"
    return 1
  }

  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "#!/bin/sh -f"
    puts $fh_scr "bin_path=\"$::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)\""
  } else {
    puts $fh_scr "@echo off"
    puts $fh_scr "set bin_path=\"$::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)\""
  }
  ::tclapp::xilinx::ies::usf_set_ref_dir $fh_scr

  set tool "ncvhdl"
  set arg_list [list "-V93" "-RELAX" "-logfile" "${tool}.log" "-append_log"]
  if { !$::tclapp::xilinx::ies::a_ies_sim_vars(b_32bit) } {
    set arg_list [linsert $arg_list 0 "-64bit"]
  }
  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  } else {
    puts $fh_scr "set ${tool}_opts=\"[join $arg_list " "]\""
  }
 
  set tool "ncvlog"
  set arg_list [list "-messages" "-logfile" "${tool}.log" "-append_log"]
  if { !$::tclapp::xilinx::ies::a_ies_sim_vars(b_32bit) } {
    set arg_list [linsert $arg_list 0 "-64bit"]
  }
  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\"\n"
  } else {
    puts $fh_scr "set ${tool}_opts=\"[join $arg_list " "]\"\n"
  }

  set files [::tclapp::xilinx::ies::usf_uniquify_cmd_str [::tclapp::xilinx::ies::usf_get_files_for_compilation "ies"]]
  foreach file $files {
    set type    [lindex [split $file {#}] 0]
    set lib     [lindex [split $file {#}] 1]
    set cmd_str [lindex [split $file {#}] 2]
    puts $fh_scr "\$bin_path/$cmd_str"
  }

  # compile glbl file
  set b_load_glbl [get_property "IES.COMPILE.LOAD_GLBL" [get_filesets $::tclapp::xilinx::ies::a_sim_vars(s_simset)]]
  if { [::tclapp::xilinx::ies::usf_compile_glbl_file "ies" $b_load_glbl] } {
    set file_str "-work $default_lib \"[::tclapp::xilinx::ies::usf_get_glbl_file]\""
    puts $fh_scr "\n# Compile glbl module\n\$bin_path/ncvlog \$ncvlog_opts $file_str"
  }

  close $fh_scr
}

proc usf_ies_write_elaborate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::ies::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::ies::a_sim_vars(s_simset)]

  set filename "elaborate";append filename [::tclapp::xilinx::ies::usf_get_script_extn]
  set file [file normalize [file join $dir $filename]]
  set fh_scr 0

  if {[catch {open $file w} fh_scr]} {
    send_msg_id Vivado-IES-999 ERROR "failed to open file to write ($file)\n"
    return 1
  }
 
  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "#!/bin/sh -f"
    puts $fh_scr "bin_path=\"$::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)\""
  } else {
    puts $fh_scr "@echo off"
    puts $fh_scr "set bin_path=\"$::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)\""
  }

  set tool "ncelab"
  set top_lib [::tclapp::xilinx::ies::usf_get_top_library]
  set arg_list [list "-relax -access +rwc -messages" "-logfile" "elaborate.log"]

  if { !$::tclapp::xilinx::ies::a_ies_sim_vars(b_32bit) } {
     set arg_list [linsert $arg_list 0 "-64bit"]
  }

  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  } else {
    puts $fh_scr "set ${tool}_opts=\"[join $arg_list " "]\""
  }

  set arg_list [list]
  foreach lib [::tclapp::xilinx::ies::usf_get_compile_order_libs] {
     if {[string length $lib] == 0} {
       continue;
     }
     lappend arg_list "-libname"
     lappend arg_list "[string tolower $lib]"
  }

  # add simulation libraries
  set b_compile_unifast [get_property "IES.COMPILE.UNIFAST" $fs_obj]
  if { [::tclapp::xilinx::ies::usf_add_unisims $b_compile_unifast] } { set arg_list [linsert $arg_list end "-libname" "unisims_ver"] }
  if { [::tclapp::xilinx::ies::usf_add_simprims] } { set arg_list [linsert $arg_list end "-libname" "simprims_ver"] }
  if { [::tclapp::xilinx::ies::usf_add_unifast $b_compile_unifast] } {  set arg_list [linsert $arg_list end "-libname" "unifast"] }
  if { [::tclapp::xilinx::ies::usf_add_unimacro] } { set arg_list [linsert $arg_list end "-libname" "unimacro"] }
  if { [::tclapp::xilinx::ies::usf_add_secureip] } { set arg_list [linsert $arg_list end "-libname" "secureip"] }

  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "design_libs_elab=\"[join $arg_list " "]\"\n"
  } else {
    puts $fh_scr "set design_libs_elab=\"[join $arg_list " "]\"\n"
  }

  set tool_path "\$bin_path/$tool"
  set arg_list [list ${tool_path} "\$${tool}_opts"]

  set obj $::tclapp::xilinx::ies::a_sim_vars(sp_tcl_obj)
  if { [::tclapp::xilinx::ies::usf_is_fileset $obj] } {
    set vhdl_generics [list]
    set vhdl_generics [get_property "VHDL_GENERIC" [get_filesets $obj]]
    if { [llength $vhdl_generics] > 0 } {
       ::tclapp::xilinx::ies::usf_append_define_generics $vhdl_generics $tool arg_list
    }
  }

  lappend arg_list "${top_lib}.$top"
  if { [::tclapp::xilinx::ies::usf_contains_verilog] } {
    lappend arg_list "${top_lib}.glbl"
  }

  lappend arg_list "\$design_libs_elab"
  set cmd_str [join $arg_list " "]
  puts $fh_scr "$cmd_str"
  close $fh_scr
}

proc usf_ies_write_simulate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::ies::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)
  set filename "simulate";append filename [::tclapp::xilinx::ies::usf_get_script_extn]
  set file [file normalize [file join $dir $filename]]
  set fh_scr 0

  if { [catch {open $file w} fh_scr] } {
    send_msg_id Vivado-IES-999 ERROR "failed to open file to write ($file)\n"
    return 1
  }

  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "#!/bin/sh -f"
    puts $fh_scr "bin_path=\"$::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)\""
  } else {
    puts $fh_scr "@echo off"
    puts $fh_scr "set bin_path=\"$::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)\""
  }

  set do_filename "${top}.do"

  ::tclapp::xilinx::ies::usf_create_do_file "ies" $do_filename
	
  set tool "ncsim"
  set top_lib [::tclapp::xilinx::ies::usf_get_top_library]
  set arg_list [list "-logfile" "simulate.log"]
  if { !$::tclapp::xilinx::ies::a_ies_sim_vars(b_32bit) } {
    set arg_list [linsert $arg_list 0 "-64bit"]
  }
  if { $::tclapp::xilinx::ies::a_sim_vars(b_batch) } {
   # no gui
  } else {
    set arg_list [linsert $arg_list end "-gui"]
  }

  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  } else {
    puts $fh_scr "set ${tool}_opts=\"[join $arg_list " "]\""
  }
  puts $fh_scr ""

  set tool_path "\$bin_path/$tool"
  set arg_list [list "${tool_path}" "\$${tool}_opts" "${top_lib}.$top" "-input" "$do_filename"]
  set cmd_str [join $arg_list " "]

  puts $fh_scr "$cmd_str"
  close $fh_scr
}
}
