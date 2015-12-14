######################################################################
#
# sim.tcl
#
# based on XilinxTclStore\tclapp\xilinx\modelsim\sim.tcl
#
######################################################################

package require Vivado 1.2014.1

package require ::tclapp::aldec::common::helpers 1.3

package provide ::tclapp::aldec::common::sim 1.3

namespace eval ::tclapp::aldec::common {

namespace eval sim {

proc setup { args } {
  # Summary: initialize global vars and prepare for simulation
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # true (0) if success, false (1) otherwise

  # initialize global variables
  ::tclapp::aldec::common::helpers::usf_init_vars

  # read simulation command line args and set global variables
  usf_setup_args $args

  # perform initial simulation tasks
  if { [usf_aldec_setup_simulation] } {
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
  
  set simulatorName [::tclapp::aldec::common::helpers::usf_aldec_getSimulatorName]

  send_msg_id USF-${simulatorName}-81 INFO "${simulatorName}::Compile design"
  usf_aldec_write_compile_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::aldec::common::helpers::usf_launch_script $step
}

proc elaborate { args } {
  # Summary: run the elaborate step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none
}

proc simulate { args } {
  # Summary: run the simulate step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  set dir $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)
  
  set simulatorName [::tclapp::aldec::common::helpers::usf_aldec_getSimulatorName]

  send_msg_id USF-${simulatorName}-82 INFO "${simulatorName}::Simulate design"
  usf_write_simulate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::aldec::common::helpers::usf_launch_script $step

  if { $::tclapp::aldec::common::helpers::a_sim_vars(b_scripts_only) } {
    set fh 0
    set file [file normalize [file join $dir "simulate.log"]]
    if {[catch {open $file w} fh]} {
      send_msg_id USF-${simulatorName}-83 ERROR "Failed to open file to write ($file)\n"
    } else {
      puts $fh "INFO: Scripts generated successfully. Please see the 'Tcl Console' window for details."
      close $fh
    }
  }
}
}

namespace eval ::tclapp::aldec::common::sim {

proc usf_aldec_getPropertyName { property } {
  switch -- [get_property target_simulator [current_project]] {
    Riviera { return "RIVIERA.$property" }
    ActiveHDL { return "ACTIVEHDL.$property" }
  }
}

proc usf_aldec_getSimulatorName {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  return [::tclapp::aldec::common::helpers::usf_aldec_getSimulatorName]
}

proc usf_aldec_setup_simulation { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  ::tclapp::aldec::common::helpers::usf_aldec_set_simulator_path

  # set the simulation flow
  ::tclapp::aldec::common::helpers::usf_set_simulation_flow

  # set default object
  if { [::tclapp::aldec::common::helpers::usf_set_sim_tcl_obj] } {
    return 1
  }

  # write functional/timing netlist for post-* simulation
  ::tclapp::aldec::common::helpers::usf_write_design_netlist

  # prepare IP's for simulation
  ::tclapp::aldec::common::helpers::usf_prepare_ip_for_simulation

  # fetch the compile order for the specified object
  ::tclapp::aldec::common::helpers::usf_xport_data_files


  # fetch design files
  set global_files_str {}
  set ::tclapp::aldec::common::helpers::a_sim_vars(l_design_files) \
     [::tclapp::aldec::common::helpers::usf_uniquify_cmd_str [::tclapp::aldec::common::helpers::usf_get_files_for_compilation global_files_str]]

  # create setup file
  usf_aldec_write_setup_files

  return 0
}

proc usf_setup_args { args } {
  # Summary:
  # 

  # Argument Usage:
  # [-simset <arg>]: Name of the simulation fileset
  # [-mode <arg>]: Simulation mode. Values: behavioral, post-synthesis, post-implementation
  # [-type <arg>]: Netlist type. Values: functional, timing. This is only applicable when mode is set to post-synthesis or post-implementation
  # [-scripts_only]: Only generate scripts
  # [-of_objects <arg>]: Generate do file for this object (applicable with -scripts_only option only)
  # [-absolute_path]: Make all file paths absolute wrt the reference directory
  # [-install_path <arg>]: Custom ModelSim installation directory path
  # [-batch]: Execute batch flow simulation run (non-gui)
  # [-run_dir <arg>]: Simulation run directory
  # [-int_os_type]: OS type (32 or 64) (internal use)
  # [-int_debug_mode]: Debug mode (internal use)

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: xilinxtclstore

  set args [string trim $args "\}\{"]

  # process options
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-simset"         { incr i;set ::tclapp::aldec::common::helpers::a_sim_vars(s_simset) [lindex $args $i] }
      "-mode"           { incr i;set ::tclapp::aldec::common::helpers::a_sim_vars(s_mode) [lindex $args $i] }
      "-type"           { incr i;set ::tclapp::aldec::common::helpers::a_sim_vars(s_type) [lindex $args $i] }
      "-scripts_only"   { set ::tclapp::aldec::common::helpers::a_sim_vars(b_scripts_only) 1 }
      "-of_objects"     { incr i;set ::tclapp::aldec::common::helpers::a_sim_vars(s_comp_file) [lindex $args $i]}
      "-absolute_path"  { set ::tclapp::aldec::common::helpers::a_sim_vars(b_absolute_path) 1 }
      "-install_path"   { incr i;set ::tclapp::aldec::common::helpers::a_sim_vars(s_install_path) [lindex $args $i] }
      "-batch"          { set ::tclapp::aldec::common::helpers::a_sim_vars(b_batch) 1 }
      "-run_dir"        { incr i;set ::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir) [lindex $args $i] }
      "-int_os_type"    { incr i;set ::tclapp::aldec::common::helpers::a_sim_vars(s_int_os_type) [lindex $args $i] }
      "-int_debug_mode" { incr i;set ::tclapp::aldec::common::helpers::a_sim_vars(s_int_debug_mode) [lindex $args $i] }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id USF-[usf_aldec_getSimulatorName]-84 ERROR "Unknown option '$option', please type 'launch_simulation -help' for usage info.\n"
          return 1
        }
      }
    }
  }
}


proc usf_aldec_write_setup_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::common::helpers::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)

  # msim lib dir
  set lib_dir [file normalize [file join $dir "msim"]]
  if { [file exists $lib_dir] } {
    if {[catch {file delete -force $lib_dir} error_msg] } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-85 ERROR "Failed to delete directory ($lib_dir): $error_msg\n"
      return 1
    }
  }
}

proc usf_aldec_write_compile_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::common::helpers::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::aldec::common::helpers::a_sim_vars(s_simset)]

  set do_filename {}

  set do_filename $top;append do_filename "_compile.do"
  set do_file [file normalize [file join $dir $do_filename]]

  send_msg_id USF-[usf_aldec_getSimulatorName]-86 INFO "Creating automatic 'do' files...\n"

  usf_aldec_create_do_file_for_compilation $do_file

  # write compile.sh/.bat
  usf_aldec_write_driver_shell_script $do_filename "compile"
}

proc usf_write_simulate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::common::helpers::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::aldec::common::helpers::a_sim_vars(s_simset)]
  set do_filename {}
  set do_filename $top;append do_filename "_simulate.do"
  set do_file [file normalize [file join $dir $do_filename]]
  usf_aldec_create_do_file_for_simulation $do_file

  # write elaborate.sh/.bat
  usf_aldec_write_driver_shell_script $do_filename "simulate"
}

proc usf_create_udo_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # if udo file exists, return
  if { [file exists $file] } {
    return 0
  }
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id USF-[usf_aldec_getSimulatorName]-87 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  usf_aldec_write_header $fh $file
  close $fh
}

proc usf_aldec_create_do_file_for_compilation { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  send_msg_id USF-[usf_aldec_getSimulatorName]-88 INFO "$do_file\n"

  set top $::tclapp::aldec::common::helpers::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::aldec::common::helpers::a_sim_vars(s_simset)]
  set b_absolute_path $::tclapp::aldec::common::helpers::a_sim_vars(b_absolute_path)
  set target_simulator [get_property target_simulator [current_project]]
  if { $target_simulator == "ActiveHDL" } {
    set b_absolute_path 1
  }  

  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-[usf_aldec_getSimulatorName]-89 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_aldec_write_header $fh $do_file
  usf_aldec_add_quit_on_error $fh "compile"

  usf_aldec_createDesignIfNeeded $fh

  puts $fh "vlib work\n"

  set design_libs [usf_aldec_get_design_libs $::tclapp::aldec::common::helpers::a_sim_vars(l_design_files)]

  # TODO:
  # If DesignFiles contains VHDL files, but simulation language is set to Verilog, we should issue CW
  # Vice verse, if DesignFiles contains Verilog files, but simulation language is set to VHDL

  set libraryPrefix [::tclapp::aldec::common::helpers::usf_aldec_getLibraryPrefix]
  
  set b_default_lib false
  set default_lib [get_property "DEFAULT_LIB" [current_project]]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    puts $fh "vlib ${libraryPrefix}$lib"
    puts $fh "vdel -lib $lib -all"
    if { $default_lib == $lib } {
      set b_default_lib true
    }
  }
  if { !$b_default_lib } {
    puts $fh "vlib ${libraryPrefix}$default_lib"
    puts $fh "vdel -lib $default_lib -all"
  }
   
  puts $fh ""

  if { $b_absolute_path } {
    puts $fh "null \[set origin_dir \"$dir\"\]"
  } else {
    puts $fh "null \[set origin_dir \".\"\]"
  }

  set vlog_arg_list [list]
  set vlog_syntax [get_property [usf_aldec_getPropertyName COMPILE.VLOG_SYNTAX] $fs_obj]
  lappend vlog_arg_list "-$vlog_syntax"
  if { [get_property [usf_aldec_getPropertyName COMPILE.DEBUG] $fs_obj] } {
    lappend vlog_arg_list "-dbg"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.INCREMENTAL] $fs_obj] } {
    lappend vlog_arg_list "-incr"
  }
  set more_vlog_options [string trim [get_property [usf_aldec_getPropertyName COMPILE.VLOG.MORE_OPTIONS] $fs_obj]]
  if { {} != $more_vlog_options } {
    set vlog_arg_list [linsert $vlog_arg_list end "$more_vlog_options"]
  }
  set vlog_cmd_str [join $vlog_arg_list " "]
  puts $fh "null \[set vlog_opts \{$vlog_cmd_str\}\]"

  set vcom_arg_list [list]
  set vhdl_syntax [get_property [usf_aldec_getPropertyName COMPILE.VHDL_SYNTAX] $fs_obj]
  lappend vcom_arg_list "-$vhdl_syntax"
  if { [get_property [usf_aldec_getPropertyName COMPILE.VHDL_RELAX] $fs_obj] } {
    lappend vcom_arg_list "-relax"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.DEBUG] $fs_obj] } {
    lappend vcom_arg_list "-dbg"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.INCREMENTAL] $fs_obj] } {
    lappend vcom_arg_list "-incr"
  }
  set more_vcom_options [string trim [get_property [usf_aldec_getPropertyName COMPILE.VCOM.MORE_OPTIONS] $fs_obj]]
  if { {} != $more_vcom_options } {
    set vcom_arg_list [linsert $vcom_arg_list end "$more_vcom_options"]
  }
  set vcom_cmd_str [join $vcom_arg_list " "]
  puts $fh "null \[set vcom_opts \{$vcom_cmd_str\}\]"

  puts $fh ""

  foreach file $::tclapp::aldec::common::helpers::a_sim_vars(l_design_files) {
    set fargs       [split $file {|}]
    set type        [lindex $fargs 0]
    set file_type   [lindex $fargs 1]
    set lib         [lindex $fargs 2]
    set cmd_str     [lindex $fargs 3]
    set src_file    [lindex $fargs 4]
    set b_static_ip [lindex $fargs 5]
    
    puts $fh "eval $cmd_str $src_file"
  }

  # compile glbl file
  set b_load_glbl [get_property [usf_aldec_getPropertyName COMPILE.LOAD_GLBL] [get_filesets $::tclapp::aldec::common::helpers::a_sim_vars(s_simset)]]
  if { [::tclapp::aldec::common::helpers::usf_compile_glbl_file $target_simulator $b_load_glbl $::tclapp::aldec::common::helpers::a_sim_vars(l_design_files)] } {
    ::tclapp::aldec::common::helpers::usf_copy_glbl_file
    set top_lib [::tclapp::aldec::common::helpers::usf_get_top_library]
    set file_str "-work $top_lib \"[usf_aldec_getGlblPath]\""
    puts $fh "\n# compile glbl module\nvlog $file_str"
  }

  puts $fh "\n[usf_aldec_getQuitCmd]"
  close $fh
}

proc usf_aldec_get_elaboration_cmdline {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  set top $::tclapp::aldec::common::helpers::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)
  set sim_flow $::tclapp::aldec::common::helpers::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::aldec::common::helpers::a_sim_vars(s_simset)]

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]

  set arg_list [list]

  if { [get_property [usf_aldec_getPropertyName ELABORATE.ACCESS] $fs_obj]
    || [get_property [usf_aldec_getPropertyName SIMULATE.LOG_ALL_SIGNALS] $fs_obj]
    || [get_property [usf_aldec_getPropertyName SIMULATE.SAIF] $fs_obj] != {} } {
    lappend arg_list "+access +r"
  } else {
    lappend arg_list "+access +r +m+$top"
  }

  set vhdl_generics [list]
  set vhdl_generics [get_property "GENERIC" [get_filesets $fs_obj]]
  if { [llength $vhdl_generics] > 0 } {
    ::tclapp::aldec::common::helpers::usf_append_generics $vhdl_generics arg_list  
  }

  set t_opts [join $arg_list " "]

  set design_files $::tclapp::aldec::common::helpers::a_sim_vars(l_design_files)

  # add simulation libraries
  set arg_list [list]
  # post* simulation
  if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    if { [::tclapp::aldec::common::helpers::usf_contains_verilog $design_files] || ({Verilog} == $target_lang) } {
      if { {timesim} == $netlist_mode } {
        set arg_list [linsert $arg_list end "-L" "simprims_ver"]
      } else {
        set arg_list [linsert $arg_list end "-L" "unisims_ver"]
      }
    }
  }

  # behavioral simulation
  set b_compile_unifast [get_property [usf_aldec_getPropertyName ELABORATE.UNIFAST] $fs_obj]

  if { ([::tclapp::aldec::common::helpers::usf_contains_vhdl $design_files]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast && [get_param "simulation.addUnifastLibraryForVhdl"] } {
      set arg_list [linsert $arg_list end "-L" "unifast"]
    }
  }

  if { ([::tclapp::aldec::common::helpers::usf_contains_verilog $design_files]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-L" "unifast_ver"]
    }
    set arg_list [linsert $arg_list end "-L" "unisims_ver"]
    set arg_list [linsert $arg_list end "-L" "unimacro_ver"]
  }

  # add secureip
  set arg_list [linsert $arg_list end "-L" "secureip"]

  # add design libraries
  set design_libs [usf_aldec_get_design_libs $design_files]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend arg_list "-L"
    lappend arg_list "$lib"
  }

  set d_libs [join $arg_list " "]  
  set arg_list [list $t_opts]
  lappend arg_list "$d_libs"
  set cmd_str [join $arg_list " "]
  return $cmd_str
}

proc usf_aldec_get_simulation_cmdline {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::common::helpers::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)
  set flow $::tclapp::aldec::common::helpers::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::aldec::common::helpers::a_sim_vars(s_simset)]

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]

  set tool "asim"
  set arg_list [list "$tool" "-t 1ps"]
  
  if { [get_property target_simulator [current_project]] == "ActiveHDL" } {
    lappend arg_list "-asdb"
  }

  lappend arg_list [usf_aldec_get_elaboration_cmdline]
  
  if { [get_property [usf_aldec_getPropertyName SIMULATE.VERILOG_ACCELERATION] $fs_obj] } {
    lappend arg_list "-O5"
  } else {
    lappend arg_list "-O2"
  }
  
  if { [get_property [usf_aldec_getPropertyName SIMULATE.DEBUG] $fs_obj] } {
    lappend arg_list "-dbg"
  }  

  set more_sim_options [string trim [get_property [usf_aldec_getPropertyName SIMULATE.ASIM.MORE_OPTIONS] $fs_obj]]
  if { {} != $more_sim_options } {
    set arg_list [linsert $arg_list end "$more_sim_options"]
  }

  # design contains ax-bfm ip? insert bfm library
  if { [::tclapp::aldec::common::helpers::usf_is_axi_bfm_ip] } {
    set simulator_lib [::tclapp::aldec::common::helpers::usf_get_simulator_lib_for_bfm]
    if { {} != $simulator_lib } {
      set arg_list [linsert $arg_list end "-pli \"$simulator_lib\""]
    } else {
      send_msg_id USF-[usf_aldec_getSimulatorName]-90 ERROR "Failed to locate simulator library from 'XILINX' environment variable."
    }
  }

  set top_lib [::tclapp::aldec::common::helpers::usf_get_top_library]
  lappend arg_list "${top_lib}.${top}"

  set design_files $::tclapp::aldec::common::helpers::a_sim_vars(l_design_files)
  if { [::tclapp::aldec::common::helpers::usf_contains_verilog $design_files] } {
    lappend arg_list "${top_lib}.glbl"
  }

  set cmd_str [join $arg_list " "]
  return $cmd_str
}

proc usf_aldec_setSimulationPrerequisites { out } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  if { [get_property target_simulator [current_project]] != "ActiveHDL" } {
    return
  }
  
  set designName [current_project]
  set targetDir $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)

  puts $out "opendesign ${targetDir}/${designName}/${designName}.adf"
  puts $out "set SIM_WORKING_FOLDER \$dsn/.."
}

proc usf_aldec_getDefaultDatasetName {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  switch -- [get_property target_simulator [current_project]] {
    Riviera { return "dataset.asdb" }
    ActiveHDL { return "\$waveformoutput" }
  }  
}

proc usf_aldec_create_do_file_for_simulation { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::common::helpers::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)
  set b_batch $::tclapp::aldec::common::helpers::a_sim_vars(b_batch)
  set b_scripts_only $::tclapp::aldec::common::helpers::a_sim_vars(b_scripts_only)
  set fs_obj [get_filesets $::tclapp::aldec::common::helpers::a_sim_vars(s_simset)]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-[usf_aldec_getSimulatorName]-91 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_aldec_write_header $fh $do_file
  usf_aldec_add_quit_on_error $fh "simulate"

  usf_aldec_setSimulationPrerequisites $fh

  puts $fh [usf_aldec_get_simulation_cmdline]
  puts $fh ""

  set b_log_all_signals [get_property [usf_aldec_getPropertyName SIMULATE.LOG_ALL_SIGNALS] $fs_obj]
  if { $b_log_all_signals } {
    puts $fh "log -rec *"
    if { [::tclapp::aldec::common::helpers::usf_contains_verilog $::tclapp::aldec::common::helpers::a_sim_vars(l_design_files)] } {
      puts $fh "log /glbl/GSR"
    }
  }
  
  set uut [get_property [usf_aldec_getPropertyName SIMULATE.UUT] $fs_obj]
  if { {} == $uut } {
    set uut "/$top/uut"
  }
 
  # generate saif file for power estimation
  set saif [get_property [usf_aldec_getPropertyName SIMULATE.SAIF] $fs_obj]
  if { !$b_log_all_signals } {
    if { {} != $saif } {
      set rec ""
      if { $::tclapp::aldec::common::helpers::a_sim_vars(s_mode) != {behavioral} } {
        set rec "-rec"
      }
      puts $fh "log $rec ${uut}/*"
    }
  }

  puts $fh "wave *"

  set rt [string trim [get_property [usf_aldec_getPropertyName SIMULATE.RUNTIME] $fs_obj]]
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

  # generate saif file for power estimation
  if { {} != $saif } {
    set extn [string tolower [file extension $saif]]
    if { {.saif} != $extn } {
      append saif ".saif"
    }
    if { [get_property target_simulator [current_project]] == "ActiveHDL" } {
      puts $fh "asdbdump -flush"
    }

    set rec ""
    if { $::tclapp::aldec::common::helpers::a_sim_vars(s_mode) != {behavioral} } {
      set rec "-rec"
    }
    puts $fh "asdb2saif -internal -scope $rec ${uut}/* [usf_aldec_getDefaultDatasetName] \{$saif\}"
  }

  # add TCL sources
  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\""
  ::tclapp::aldec::common::helpers::usf_find_files tcl_src_files $filter
  if {[llength $tcl_src_files] > 0} {
    puts $fh ""
    foreach file $tcl_src_files {
      puts $fh "source \{$file\}"
    }
    puts $fh ""
  }

  if { $b_batch || $b_scripts_only } {
    puts $fh "\nendsim"
    puts $fh "\n[usf_aldec_getQuitCmd]"
  }
  close $fh
}

proc usf_aldec_write_header { fh filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  set timestamp   [clock format [clock seconds]]
  set mode_type   $::tclapp::aldec::common::helpers::a_sim_vars(s_mode)
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

proc usf_aldec_writeWindowsExecutableCmdLine { out batch_sw do_filename log_filename } {
  if { [get_property target_simulator [current_project]] == "ActiveHDL" } {
  
    puts $out "call \"%bin_path%/avhdl\" -do \"do -tcl \{$do_filename\}\""
    puts $out "set error=%errorlevel%"
    
    # copy log file
    set designName [current_project]
    set targetDir $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)
    set logFile [file nativename "${targetDir}/${designName}/log/console.log"]
    puts $out "copy /Y \"$logFile\" \"$log_filename\""  
    #
    
    puts $out "set errorlevel=%error%"
    
  } else {
    if { $batch_sw != "" } {
      puts $out "call \"%bin_path%/../runvsimsa\" -l \"$log_filename\" -do \"do \{$do_filename\}\""
    } else {
      puts $out "call \"%bin_path%/../rungui\" -l \"$log_filename\" -do \"do \{$do_filename\}\""
    }
  }
}

proc usf_aldec_write_driver_shell_script { do_filename step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set dir $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)
  set b_batch $::tclapp::aldec::common::helpers::a_sim_vars(b_batch)
  set b_scripts_only $::tclapp::aldec::common::helpers::a_sim_vars(b_scripts_only)

  set scr_filename $step;append scr_filename [::tclapp::aldec::common::helpers::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-[usf_aldec_getSimulatorName]-92 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  set batch_sw {-c}
  if { ({simulate} == $step) && (!$b_batch) && (!$b_scripts_only) } {
    set batch_sw {}
  }
  
  set log_filename "${step}.log"
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "#!/bin/sh -f"
    puts $fh_scr "bin_path=\"$::tclapp::aldec::common::helpers::a_sim_vars(s_tool_bin_path)\""
    ::tclapp::aldec::common::helpers::usf_write_shell_step_fn $fh_scr
    if { $batch_sw != "" } {
      puts $fh_scr "ExecStep \$bin_path/../runvsimsa -l $log_filename -do \"do \{$do_filename\}\""
    } else {
      puts $fh_scr "ExecStep \$bin_path/../rungui -l $log_filename -do \"do \{$do_filename\}\""
    }
  } else {
    puts $fh_scr "@echo off"

    if { $step == "simulate" } {
        set simulator_lib [::tclapp::aldec::common::helpers::usf_get_simulator_lib_for_bfm]
        if { {} != $simulator_lib } {		
            puts $fh_scr "set PATH=[file dirname $simulator_lib];%PATH%"
        }
    }

    puts $fh_scr "set bin_path=$::tclapp::aldec::common::helpers::a_sim_vars(s_tool_bin_path)"
    usf_aldec_writeWindowsExecutableCmdLine $fh_scr $batch_sw $do_filename $log_filename
    puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
    puts $fh_scr "if \"%errorlevel%\"==\"0\" goto SUCCESS"
    puts $fh_scr ":END"
    puts $fh_scr "exit 1"
    puts $fh_scr ":SUCCESS"
    puts $fh_scr "exit 0"
  }
  close $fh_scr
}

proc usf_aldec_get_design_libs { files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set libs [list]
  foreach file $files {
    set fargs     [split $file {|}]
    set type      [lindex $fargs 0]
    set file_type [lindex $fargs 1]
    set library   [lindex $fargs 2]
    if { {} == $library } {
      continue;
    }
    if { [lsearch -exact $libs $library] == -1 } {
      lappend libs $library
    }
  }
  return $libs
}

proc usf_aldec_add_quit_on_error { fh step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_batch        $::tclapp::aldec::common::helpers::a_sim_vars(b_batch)
  set b_scripts_only $::tclapp::aldec::common::helpers::a_sim_vars(b_scripts_only)
  
  #hide 'onerror' command from called 'onerror' handler if error occurred: used as error detection in log files
  puts $fh "transcript off"
  #
  
  switch -- [get_property target_simulator [current_project]] {
    Riviera { set noQuitOnError [get_param "simulator.rivieraNoQuitOnError"] }
    ActiveHDL { set noQuitOnError [get_param "simulator.activehdlNoQuitOnError"] }
  }  

  if { ({compile} == $step) || ({elaborate} == $step) } {
    puts $fh "onbreak \{[usf_aldec_getQuitCmd]\}"
    puts $fh "onerror \{[usf_aldec_getQuitCmd]\}\n"
  } elseif { ({simulate} == $step) } {
    if { !$noQuitOnError } {
      puts $fh "onbreak \{[usf_aldec_getQuitCmd]\}"
      puts $fh "onerror \{[usf_aldec_getQuitCmd]\}\n"
    } 

    # quit on error always for batch/scripts only and when param is true
    if { ($b_batch || $b_scripts_only) && $noQuitOnError } {
      puts $fh "onbreak \{[usf_aldec_getQuitCmd]\}"
      puts $fh "onerror \{[usf_aldec_getQuitCmd]\}\n"
    }
  }
}

proc usf_aldec_createDesignIfNeeded { out } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  if { [get_property target_simulator [current_project]] != "ActiveHDL" } {
    return
  }
  
  set designName [current_project]
  set targetDir $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)
  
  puts $out "createdesign \{$designName\} \{$targetDir\}"
  puts $out "opendesign \{${targetDir}/${designName}/${designName}.adf\}"
}

proc usf_aldec_getQuitCmd {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  if { [get_property target_simulator [current_project]] == "ActiveHDL" } {
    return "quit"
  } else {
    return "quit -force"
  }  
}

proc usf_aldec_getGlblPath {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  if { [get_property target_simulator [current_project]] == "ActiveHDL" } {
    return $::tclapp::aldec::common::helpers::a_sim_vars(s_launch_dir)/glbl.v
  } else {
    return glbl.v
  }
}

}

}
