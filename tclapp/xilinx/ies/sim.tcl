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
package require Vivado 1.2013.1
package require ::tclapp::xilinx::ies::helpers

namespace eval ::tclapp::xilinx::ies {
proc setup { args } {
  # Summary: initialize global vars and prepare for simulation
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # true (0) if success, false (1) otherwise

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
  # Summary: run the compile step for compiling the design files
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

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

  send_msg_id Vivado-IES-003 INFO "ies::elaborate design"

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

  send_msg_id Vivado-IES-004 INFO "ies::simulate design"

  usf_ies_write_simulate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::ies::usf_launch_script "ies" $step
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

  # set default object
  if { [::tclapp::xilinx::ies::usf_set_sim_tcl_obj] } {
    puts "failed to set tcl obj"
    return 1
  }

  # print launch_simulation arg values
  #::tclapp::xilinx::ies::usf_print_args

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
      "-batch"          { set ::tclapp::xilinx::ies::a_sim_vars(b_batch) 1 }
      "-int_os_type"    { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_int_os_type) [lindex $args $i] }
      "-int_debug_mode" { incr i;set ::tclapp::xilinx::ies::a_sim_vars(s_int_debug_mode) [lindex $args $i] }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id Vivado-IES-005 ERROR "Unknown option '$option', please type 'simulate -help' for usage info.\n"
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
  send_msg_id Vivado-ies-006 INFO "Finding pre-compiled libraries...\n"
  # check property value
  set dir [get_property "COMPXLIB.COMPILED_LIBRARY_DIR" [current_project]]
  set cds_file [file normalize [file join $dir $cds_file]]
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
   send_msg_id Vivado-ies-007 INFO "Compiled library path:$compiled_lib_dir\n"
   return
  }
  send_msg_id Vivado-ies-008 "CRITICAL WARNING" "Failed to find the pre-compiled simulation library information!\n"
  send_msg_id Vivado-ies-009 INFO "Please set the 'COMPXLIB.COMPILED_LIBRARY_DIR' project property to the directory where Xilinx simulation libraries are compiled.\n"
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
    send_msg_id Vivado-IES-010 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  set lib_map_path $::tclapp::xilinx::ies::a_ies_sim_vars(s_compiled_lib_dir)
  if { {} == $lib_map_path } {
    set lib_map_path "?"
  }
  puts $fh "INCLUDE $lib_map_path/$filename"
  set libs [list]
  set files [::tclapp::xilinx::ies::usf_uniquify_cmd_str [::tclapp::xilinx::ies::usf_get_files_for_compilation]]
  set design_libs [usf_ies_get_design_libs $files]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend libs [string tolower $lib]
  }
  set dir_name "ies"
  foreach lib_name $libs {
    set lib_dir [file join $dir_name $lib_name]
    set lib_dir_path [file normalize [string map {\\ /} [file join $dir $lib_dir]]]
    if { ! [file exists $lib_dir_path] } {
      if {[catch {file mkdir $lib_dir_path} error_msg] } {
        send_msg_id Vivado-IES-011 ERROR "failed to create the directory ($lib_dir_path): $error_msg\n"
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
    send_msg_id Vivado-IES-012 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  close $fh

  # create setup file
  usf_ies_create_setup_script

}

proc usf_ies_write_compile_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::ies::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)
  set default_lib [get_property "DEFAULT_LIB" [current_project]]

  set filename "compile";append filename [::tclapp::xilinx::ies::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $filename]]
  set fh_scr 0

  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id Vivado-IES-013 ERROR "failed to open file to write ($scr_file)\n"
    return 1
  }

  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "#!/bin/sh -f"
    ::tclapp::xilinx::ies::usf_write_script_header_info $fh_scr $scr_file
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"$::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)\"\n"
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
  puts $fh_scr "# set ${tool} command line args"
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
  puts $fh_scr "\n# set ${tool} command line args"
  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\"\n"
  } else {
    puts $fh_scr "set ${tool}_opts=\"[join $arg_list " "]\"\n"
  }

  set files [::tclapp::xilinx::ies::usf_uniquify_cmd_str [::tclapp::xilinx::ies::usf_get_files_for_compilation]]
  puts $fh_scr "# compile design source files"
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
    puts $fh_scr "\n# compile glbl module\n\$bin_path/ncvlog \$ncvlog_opts $file_str"
  }

  close $fh_scr
}

proc usf_ies_write_elaborate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::ies::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)
  set flow $::tclapp::xilinx::ies::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::xilinx::ies::a_sim_vars(s_simset)]

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]

  set filename "elaborate";append filename [::tclapp::xilinx::ies::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $filename]]
  set fh_scr 0

  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id Vivado-IES-014 ERROR "failed to open file to write ($scr_file)\n"
    return 1
  }
 
  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "#!/bin/sh -f"
    ::tclapp::xilinx::ies::usf_write_script_header_info $fh_scr $scr_file
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"$::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)\"\n"
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

  # design contains ax-bfm ip? insert bfm library
  if { [::tclapp::xilinx::ies::usf_is_axi_bfm_ip] } {
    set simulator_lib [usf_get_simulator_lib_for_bfm]
    if { {} != $simulator_lib } {
      set arg_list [linsert $arg_list 0 "-loadvpi \"$simulator_lib:xilinx_register_systf\""]
    } else {
      send_msg_id Vivado-VCS_MX-015 ERROR "Failed to locate simulator library from 'XILINX' environment variable."
    }
  }

  puts $fh_scr "# set ${tool} command line args"
  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  } else {
    puts $fh_scr "set ${tool}_opts=\"[join $arg_list " "]\""
  }

  set arg_list [list]
  # add simulation libraries

  # post* simulation
  if { ({post_synth_sim} == $flow) || ({post_impl_sim} == $flow) } {
    if { [usf_contains_verilog] || ({Verilog} == $target_lang) } {
      if { {timesim} == $netlist_mode } {
        set arg_list [linsert $arg_list end "-libname" "simprims_ver"]
      } else {
        set arg_list [linsert $arg_list end "-libname" "unisims_ver"]
      }
    }
  }

  # behavioral simulation
  set b_compile_unifast [get_property "IES.COMPILE.UNIFAST" $fs_obj]
  if { ([usf_contains_verilog]) && ({behav_sim} == $flow) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-libname" "unifast_ver"]
    }
    set arg_list [linsert $arg_list end "-libname" "unisims_ver"]
    set arg_list [linsert $arg_list end "-libname" "unimacro_ver"]
  }

  # add secureip
  set arg_list [linsert $arg_list end "-libname" "secureip"]

  # add design libraries
  set files [::tclapp::xilinx::ies::usf_uniquify_cmd_str [::tclapp::xilinx::ies::usf_get_files_for_compilation]]
  set design_libs [usf_ies_get_design_libs $files]
  foreach lib $design_libs {
    if {[string length $lib] == 0} {
      continue;
    }
    lappend arg_list "-libname"
    lappend arg_list "[string tolower $lib]"
  }

  puts $fh_scr "\n# set design libraries"
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

  lappend arg_list "\$design_libs_elab"
  lappend arg_list "${top_lib}.$top"
  if { [::tclapp::xilinx::ies::usf_contains_verilog] } {
    lappend arg_list "${top_lib}.glbl"
  }

  puts $fh_scr "# run elaboration"
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
  set scr_file [file normalize [file join $dir $filename]]
  set fh_scr 0

  if { [catch {open $scr_file w} fh_scr] } {
    send_msg_id Vivado-IES-016 ERROR "failed to open file to write ($file)\n"
    return 1
  }

  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "#!/bin/sh -f"
    ::tclapp::xilinx::ies::usf_write_script_header_info $fh_scr $scr_file
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"$::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)\"\n"
  } else {
    puts $fh_scr "@echo off"
    puts $fh_scr "set bin_path=\"$::tclapp::xilinx::ies::a_sim_vars(s_tool_bin_path)\""
  }

  set do_filename "${top}_simulate.do"

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

  puts $fh_scr "# set ${tool} command line args"
  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "${tool}_opts=\"[join $arg_list " "]\""
  } else {
    puts $fh_scr "set ${tool}_opts=\"[join $arg_list " "]\""
  }
  puts $fh_scr ""

  set tool_path "\$bin_path/$tool"
  set arg_list [list "${tool_path}" "\$${tool}_opts" "${top_lib}.$top" "-input" "$do_filename"]
  set cmd_str [join $arg_list " "]

  puts $fh_scr "# run simulation"
  puts $fh_scr "$cmd_str"
  close $fh_scr
}

proc usf_ies_get_design_libs { files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set libs [list]
  foreach file $files {
    set type    [lindex [split $file {#}] 0]
    set library [lindex [split $file {#}] 1]
    set cmd_str [lindex [split $file {#}] 2]
    if { {} == $library } {
      continue;
    }
    if { [lsearch -exact $libs $library] == -1 } {
      lappend libs $library
    }
  }
  return $libs
}

proc usf_ies_create_setup_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set dir $::tclapp::xilinx::ies::a_sim_vars(s_launch_dir)
  set filename "setup";append filename [::tclapp::xilinx::ies::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id Vivado-IES-999 ERROR "failed to open file to write ($scr_file)\n"
    return 1
  }

  if {$::tcl_platform(platform) == "unix"} { 
    puts $fh_scr "#!/bin/sh -f"
    ::tclapp::xilinx::ies::usf_write_script_header_info $fh_scr $scr_file
    puts $fh_scr "\n# Create design library directory paths and define design library mappings in cds.lib"
    puts $fh_scr "create_lib_mappings()"
    puts $fh_scr "\{"
    set simulator "ies"
    set libs [list]
    set files [::tclapp::xilinx::ies::usf_uniquify_cmd_str [::tclapp::xilinx::ies::usf_get_files_for_compilation]]
    set design_libs [usf_ies_get_design_libs $files]
    foreach lib $design_libs {
      if { {} == $lib } {
        continue;
      }
      lappend libs [string tolower $lib]
    }

    puts $fh_scr "  libs=([join $libs " "])"
    puts $fh_scr "  file=\"cds.lib\""
    puts $fh_scr "  dir=\"$simulator\"\n"
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
    puts $fh_scr "setup()"
    puts $fh_scr "\{"
    puts $fh_scr "  create_lib_mappings"
    puts $fh_scr "  touch hdl.var"
    puts $fh_scr "  # Add any setup/initialization commands here:-"
    puts $fh_scr "  # <user specific commands>"
    puts $fh_scr "\}"
    puts $fh_scr ""
    puts $fh_scr "setup"
  }
  close $fh_scr

  usf_make_file_executable $scr_file
}
}
