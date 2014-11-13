######################################################################
#
# sim.tcl
#
# based on XilinxTclStore\tclapp\xilinx\modelsim\sim.tcl
#
######################################################################

package require Vivado 1.2014.1

namespace eval ::tclapp::aldec::riviera {

proc setup { args } {
  # Summary: initialize global vars and prepare for simulation
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # true (0) if success, false (1) otherwise

  # initialize global variables
  ::tclapp::aldec::riviera::usf_init_vars

  # read simulation command line args and set global variables
  usf_setup_args $args

  # perform initial simulation tasks
  if { [usf_setup_simulation] } {
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

  send_msg_id USF-[getSimulatorName]-76 INFO "[getSimulatorName]::Compile design"
  if { [get_param project.writeNativeScriptForUnifiedSimulation] } {
    usf_write_compile_script_native
  } else {
    usf_write_compile_script
  }

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::aldec::riviera::usf_launch_script "riviera" $step
}

proc elaborate { args } {
  # Summary: run the elaborate step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none
  
  return ;#[BS] we don't have elaborate step

  send_msg_id USF-[getSimulatorName]-77 INFO "[getSimulatorName]::Elaborate design"
  if { [get_param project.writeNativeScriptForUnifiedSimulation] } {
    usf_write_elaborate_script_native
  } else {
    usf_write_elaborate_script
  }

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::aldec::riviera::usf_launch_script "riviera" $step
}

proc simulate { args } {
  # Summary: run the simulate step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none

  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)

  send_msg_id USF-[getSimulatorName]-78 INFO "[getSimulatorName]::Simulate design"
  usf_write_simulate_script

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::aldec::riviera::usf_launch_script "riviera" $step

  if { $::tclapp::aldec::riviera::a_sim_vars(b_scripts_only) } {
    set fh 0
    set file [file normalize [file join $dir "simulate.log"]]
    if {[catch {open $file w} fh]} {
      send_msg_id USF-[getSimulatorName]-79 ERROR "Failed to open file to write ($file)\n"
    } else {
      puts $fh "INFO: Scripts generated successfully. Please see the 'Tcl Console' window for details."
      close $fh
    }
  }
}
}

namespace eval ::tclapp::aldec::riviera {
proc usf_setup_simulation { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  ::tclapp::aldec::riviera::usf_set_simulator_path "riviera"

  # set the simulation flow
  ::tclapp::aldec::riviera::usf_set_simulation_flow

  # set default object
  if { [::tclapp::aldec::riviera::usf_set_sim_tcl_obj] } {
    return 1
  }

  # write functional/timing netlist for post-* simulation
  ::tclapp::aldec::riviera::usf_write_design_netlist

  # prepare IP's for simulation
  ::tclapp::aldec::riviera::usf_prepare_ip_for_simulation

  # generate mem files
  #::tclapp::aldec::riviera::usf_generate_mem_files_for_simulation

  # find/copy modelsim.ini file into run dir
  #usf_verify_compiled_lib ;#[BS] do we need this?

  # fetch the compile order for the specified object
  ::tclapp::aldec::riviera::usf_get_compile_order_for_obj

  # fetch design files
  set global_files_str {}
  set ::tclapp::aldec::riviera::a_sim_vars(l_design_files) \
     [::tclapp::aldec::riviera::usf_uniquify_cmd_str [::tclapp::aldec::riviera::usf_get_files_for_compilation global_files_str]]

  # create setup file
  usf_write_setup_files

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

  #[BS] do we need care about these switches? which can be removed?
  # process options
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-simset"         { incr i;set ::tclapp::aldec::riviera::a_sim_vars(s_simset) [lindex $args $i] }
      "-mode"           { incr i;set ::tclapp::aldec::riviera::a_sim_vars(s_mode) [lindex $args $i] }
      "-type"           { incr i;set ::tclapp::aldec::riviera::a_sim_vars(s_type) [lindex $args $i] }
      "-scripts_only"   { set ::tclapp::aldec::riviera::a_sim_vars(b_scripts_only) 1 }
      "-of_objects"     { incr i;set ::tclapp::aldec::riviera::a_sim_vars(s_comp_file) [lindex $args $i]}
      "-absolute_path"  { set ::tclapp::aldec::riviera::a_sim_vars(b_absolute_path) 1 }
      "-install_path"   { incr i;set ::tclapp::aldec::riviera::a_sim_vars(s_install_path) [lindex $args $i] }
      "-batch"          { set ::tclapp::aldec::riviera::a_sim_vars(b_batch) 1 }
      "-run_dir"        { incr i;set ::tclapp::aldec::riviera::a_sim_vars(s_launch_dir) [lindex $args $i] }
      "-int_os_type"    { incr i;set ::tclapp::aldec::riviera::a_sim_vars(s_int_os_type) [lindex $args $i] }
      "-int_debug_mode" { incr i;set ::tclapp::aldec::riviera::a_sim_vars(s_int_debug_mode) [lindex $args $i] }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id USF-[getSimulatorName]-80 ERROR "Unknown option '$option', please type 'launch_simulation -help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

proc usf_verify_compiled_lib {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set b_scripts_only $::tclapp::aldec::riviera::a_sim_vars(b_scripts_only)

  set ini_file "modelsim.ini"
  set compiled_lib_dir {}

  send_msg_id USF-[getSimulatorName]-81 INFO "Finding pre-compiled libraries...\n"

  # 1. find in project default dir (<project>/<project>.cache/compile_simlib
  set dir [get_property "COMPXLIB.COMPILED_LIBRARY_DIR" [current_project]]
  set file [file normalize [file join $dir $ini_file]]
  if { [file exists $file] } {
    set compiled_lib_dir $dir
  }
  # 1a. find modelsim.ini from current working directory
  if { {} == $compiled_lib_dir } {
    set dir [file normalize [pwd]]
    set file [file normalize [file join $dir $ini_file]]
    if { [file exists $file] } {
      set compiled_lib_dir $dir
    }
  }
  # 2. not found? check MODELSIM
  if { {} == $compiled_lib_dir } {
    if { [info exists ::env(MODELSIM)] } {
      set file [file normalize $::env(MODELSIM)]
      if { {} != $file } {
        set compiled_lib_dir [file dirname $file]
      }
    }
  }
  # 3. not found? check MGC_WD
  if { {} == $compiled_lib_dir } {
    if { [info exists ::env(MGC_WD)] } {
      set file_dir [file normalize $::env(MGC_WD)]
      if { {} != $file_dir } {
        set compiled_lib_dir $file_dir
      }
    }
  }
  # 4. not found? finally check in run dir
  if { {} == $compiled_lib_dir } {
    set file [file normalize [file join $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir) $ini_file]]
    if { ! [file exists $file] } {
      if { $b_scripts_only } {
        send_msg_id USF-[getSimulatorName]-82 WARNING "The pre-compiled simulation library could not be located. Please make sure to reference this library before executing the scripts.\n"
      } else {
        send_msg_id USF-[getSimulatorName]-83 "CRITICAL WARNING" "Failed to find the pre-compiled simulation library!\n"
      }
      send_msg_id USF-[getSimulatorName]-84 INFO " Recommendation:- Please follow these instructions to resolve this issue:-\n\
                                             - set the 'COMPXLIB.COMPILED_LIBRARY_DIR' project property to the directory where Xilinx simulation libraries are compiled for ModelSim/QuestaSim, or\n\
                                             - set the 'MODELSIM' environment variable to point to the $ini_file file, or\n\
                                             - set the 'WD_MGC' environment variable to point to the directory containing the $ini_file file\n"
    }
  } else {
    # 5. copy to run dir
    set ini_file_path [file normalize [file join $compiled_lib_dir $ini_file]]
    if { [file exists $ini_file_path] } {
      if {[catch {file copy -force $ini_file_path $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)} error_msg] } {
        send_msg_id USF-[getSimulatorName]-85 ERROR "Failed to copy file ($ini_file): $error_msg\n"
      } else {
        send_msg_id USF-[getSimulatorName]-86 INFO "File '$ini_file_path' copied to run dir:'$::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)'\n"
      }
    }
  }
}

proc usf_write_setup_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::riviera::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)

  # msim lib dir
  set lib_dir [file normalize [file join $dir "msim"]]
  if { [file exists $lib_dir] } {
    if {[catch {file delete -force $lib_dir} error_msg] } {
      send_msg_id USF-[getSimulatorName]-87 ERROR "Failed to delete directory ($lib_dir): $error_msg\n"
      return 1
    }
  }

  #if { [catch {file mkdir $lib_dir} error_msg] } {
  #  send_msg_id USF-[getSimulatorName]-88 ERROR "Failed to create the directory ($lib_dir): $error_msg\n"
  #  return 1
  #}
}

proc usf_write_compile_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::riviera::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::aldec::riviera::a_sim_vars(s_simset)]

  set do_filename {}

  set do_filename $top;append do_filename "_compile.do"
  set do_file [file normalize [file join $dir $do_filename]]

  send_msg_id USF-[getSimulatorName]-89 INFO "Creating automatic 'do' files...\n"

  usf_create_do_file_for_compilation $do_file

  # write compile.sh/.bat
  usf_write_driver_shell_script $do_filename "compile"
}

proc usf_write_compile_script_native {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  ##############################################
  # No do file generation for native script mode
  ##############################################

  # write native compile.sh/.bat
  usf_write_driver_shell_script_native "compile"
}

proc usf_write_elaborate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::riviera::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::aldec::riviera::a_sim_vars(s_simset)]
  set do_filename {}
  set do_filename $top;append do_filename "_elaborate.do"
  set do_file [file normalize [file join $dir $do_filename]]
  usf_create_do_file_for_elaboration $do_file

  # write elaborate.sh/.bat
  usf_write_driver_shell_script $do_filename "elaborate"
}

proc usf_write_elaborate_script_native {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  ##############################################
  # No do file generation for native script mode
  ##############################################

  # write elaborate.sh/.bat
  usf_write_driver_shell_script_native "elaborate"
}

proc usf_write_simulate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::riviera::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::aldec::riviera::a_sim_vars(s_simset)]
  set do_filename {}
  set do_filename $top;append do_filename "_simulate.do"
  set do_file [file normalize [file join $dir $do_filename]]
  usf_create_do_file_for_simulation $do_file

  # write elaborate.sh/.bat
  usf_write_driver_shell_script $do_filename "simulate"
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
    send_msg_id USF-[getSimulatorName]-90 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  usf_write_header $fh $file
  close $fh
}

proc usf_create_wave_do_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { [file exists $file] } {
    return 0
  }
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id USF-[getSimulatorName]-91 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  usf_write_header $fh $file
  
  set fs_obj [get_filesets $::tclapp::aldec::riviera::a_sim_vars(s_simset)]
  if { [get_property "RIVIERA.SIMULATE.LOG_ALL_SIGNALS" $fs_obj] } {  
    puts $fh "log -rec *"
    if { [::tclapp::aldec::riviera::usf_contains_verilog $::tclapp::aldec::riviera::a_sim_vars(l_design_files)] } {
      puts $fh "log /glbl/GSR"
    }
  }

  close $fh
}

proc usf_create_do_file_for_compilation { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  send_msg_id USF-[getSimulatorName]-92 INFO "$do_file\n"

  set top $::tclapp::aldec::riviera::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::aldec::riviera::a_sim_vars(s_simset)]
  set b_absolute_path $::tclapp::aldec::riviera::a_sim_vars(b_absolute_path)

  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-[getSimulatorName]-93 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_write_header $fh $do_file
  usf_add_quit_on_error $fh "compile"

  puts $fh "vlib work\n"

  set design_libs [usf_get_design_libs $::tclapp::aldec::riviera::a_sim_vars(l_design_files)]

  # TODO:
  # If DesignFiles contains VHDL files, but simulation language is set to Verilog, we should issue CW
  # Vice verse, if DesignFiles contains Verilog files, but simulation language is set to VHDL

  set libraryPrefix [getLibraryPrefix]
  
  set b_default_lib false
  set default_lib [get_property "DEFAULT_LIB" [current_project]]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    puts $fh "vlib ${libraryPrefix}$lib"
    puts $fh "vdel -lib ${libraryPrefix}$lib -all"
    if { $default_lib == $lib } {
      set b_default_lib true
    }
  }
  if { !$b_default_lib } {
    puts $fh "vlib ${libraryPrefix}$default_lib"
    puts $fh "vdel -lib ${libraryPrefix}$default_lib -all"
  }
   
  puts $fh ""

  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    puts $fh "vmap $lib ${libraryPrefix}$lib"
  }
  if { !$b_default_lib } {
    puts $fh "vmap $default_lib ${libraryPrefix}$default_lib"
  }
  puts $fh ""

  if { $b_absolute_path } {
    puts $fh "null \[set origin_dir \"$dir\"\]"
  } else {
    puts $fh "null \[set origin_dir \".\"\]"
  }

  set vlog_arg_list [list]
  set vlog_syntax [get_property "RIVIERA.COMPILE.VLOG_SYNTAX" $fs_obj]
  lappend vlog_arg_list "-$vlog_syntax"
  if { [get_property "RIVIERA.COMPILE.VERILOG_STRICT" $fs_obj] } {
    lappend vlog_arg_list "-j"
  }
  if { [get_property "RIVIERA.COMPILE.DEBUG" $fs_obj] } {
    lappend vlog_arg_list "-dbg"
  }
  if { [get_property "RIVIERA.COMPILE.INCREMENTAL" $fs_obj] } {
    lappend vlog_arg_list "-incr"
  }
  set more_vlog_options [string trim [get_property "RIVIERA.COMPILE.VLOG.MORE_OPTIONS" $fs_obj]]
  if { {} != $more_vlog_options } {
    set vlog_arg_list [linsert $vlog_arg_list end "$more_vlog_options"]
  }
  set vlog_cmd_str [join $vlog_arg_list " "]
  puts $fh "null \[set vlog_opts \{$vlog_cmd_str\}\]"

  set vcom_arg_list [list]
  set vhdl_syntax [get_property "RIVIERA.COMPILE.VHDL_SYNTAX" $fs_obj]
  lappend vcom_arg_list "-$vhdl_syntax"
  if { [get_property "RIVIERA.COMPILE.VHDL_RELAX" $fs_obj] } {
    lappend vcom_arg_list "-relax"
  }
  if { [get_property "RIVIERA.COMPILE.REORDER" $fs_obj] } {
    lappend vcom_arg_list "-reorder"
  }
  if { [get_property "RIVIERA.COMPILE.DEBUG" $fs_obj] } {
    lappend vcom_arg_list "-dbg"
  }
  if { [get_property "RIVIERA.COMPILE.INCREMENTAL" $fs_obj] } {
    lappend vcom_arg_list "-incr"
  }
  set more_vcom_options [string trim [get_property "RIVIERA.COMPILE.VCOM.MORE_OPTIONS" $fs_obj]]
  if { {} != $more_vcom_options } {
    set vcom_arg_list [linsert $vcom_arg_list end "$more_vcom_options"]
  }
  set vcom_cmd_str [join $vcom_arg_list " "]
  puts $fh "null \[set vcom_opts \{$vcom_cmd_str\}\]"

  puts $fh ""

  foreach file $::tclapp::aldec::riviera::a_sim_vars(l_design_files) {
    set fargs    [split $file {#}]
    
    set type     [lindex $fargs 0]
    set lib      [lindex $fargs 1]
    set cmd_str  [lindex $fargs 2]
    set src_file [lindex $fargs 3]
    
    puts $fh "eval $cmd_str $src_file"
  }

  # compile glbl file
  set b_load_glbl [get_property "RIVIERA.COMPILE.LOAD_GLBL" [get_filesets $::tclapp::aldec::riviera::a_sim_vars(s_simset)]]
  if { [::tclapp::aldec::riviera::usf_compile_glbl_file "riviera" $b_load_glbl $::tclapp::aldec::riviera::a_sim_vars(l_design_files)] } {
    ::tclapp::aldec::riviera::usf_copy_glbl_file
    set top_lib [::tclapp::aldec::riviera::usf_get_top_library]
    set file_str "-work $top_lib \"glbl.v\""
    puts $fh "\n# compile glbl module\nvlog $file_str"
  }

  puts $fh "\nquit -force"
  close $fh
}

proc usf_create_do_file_for_elaboration { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::riviera::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)
  set b_batch $::tclapp::aldec::riviera::a_sim_vars(b_batch)
  set b_scripts_only $::tclapp::aldec::riviera::a_sim_vars(b_scripts_only)

  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-[getSimulatorName]-94 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_write_header $fh $do_file
  usf_add_quit_on_error $fh "elaborate"

  set cmd_str [usf_get_elaboration_cmdline]
  puts $fh "$cmd_str"
  puts $fh "\nquit -force"

  close $fh
}

proc usf_get_elaboration_cmdline {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  set top $::tclapp::aldec::riviera::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)
  set sim_flow $::tclapp::aldec::riviera::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::aldec::riviera::a_sim_vars(s_simset)]

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]

  set arg_list [list]

  if { [get_property "RIVIERA.ELABORATE.ACCESS" $fs_obj] } {
    lappend arg_list "+access +r"
  }

  set vhdl_generics [list]
  set vhdl_generics [get_property "GENERIC" [get_filesets $fs_obj]]
  if { [llength $vhdl_generics] > 0 } {
    ::tclapp::aldec::riviera::usf_append_generics $vhdl_generics arg_list  
  }

  set t_opts [join $arg_list " "]

  set design_files $::tclapp::aldec::riviera::a_sim_vars(l_design_files)

  # add simulation libraries
  set arg_list [list]
  # post* simulation
  if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    if { [usf_contains_verilog $design_files] || ({Verilog} == $target_lang) } {
      if { {timesim} == $netlist_mode } {
        set arg_list [linsert $arg_list end "-L" "simprims_ver"]
      } else {
        set arg_list [linsert $arg_list end "-L" "unisims_ver"]
      }
    }
  }

  # behavioral simulation
  set b_compile_unifast [get_property "RIVIERA.ELABORATE.UNIFAST" $fs_obj]

  if { ([::tclapp::aldec::riviera::usf_contains_vhdl $design_files]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast && [get_param "simulation.addUnifastLibraryForVhdl"] } {
      set arg_list [linsert $arg_list end "-L" "unifast"]
    }
  }

  if { ([usf_contains_verilog $design_files]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-L" "unifast_ver"]
    }
    set arg_list [linsert $arg_list end "-L" "unisims_ver"]
    set arg_list [linsert $arg_list end "-L" "unimacro_ver"]
  }

  # add secureip
  set arg_list [linsert $arg_list end "-L" "secureip"]

  # add design libraries
  set design_libs [usf_get_design_libs $design_files]
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

proc usf_get_simulation_cmdline {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::riviera::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)
  set flow $::tclapp::aldec::riviera::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::aldec::riviera::a_sim_vars(s_simset)]

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]

  set tool "asim"
  set arg_list [list "$tool" "-t 1ps"]
  
  lappend arg_list [usf_get_elaboration_cmdline]
  
  if { [get_property "RIVIERA.SIMULATE.VERILOG_ACCELERATION" $fs_obj] } {
    lappend arg_list "-O5"
  } else {
    lappend arg_list "-O2"
  }
  
  if { [get_property "RIVIERA.SIMULATE.DEBUG" $fs_obj] } {
    lappend arg_list "-dbg"
  }  

  set more_sim_options [string trim [get_property "RIVIERA.SIMULATE.ASIM.MORE_OPTIONS" $fs_obj]]
  if { {} != $more_sim_options } {
    set arg_list [linsert $arg_list end "$more_sim_options"]
  }

  # design contains ax-bfm ip? insert bfm library
  if { [::tclapp::aldec::riviera::usf_is_axi_bfm_ip] } {
    set simulator_lib [usf_get_simulator_lib_for_bfm]
    if { {} != $simulator_lib } {
      set arg_list [linsert $arg_list end "-pli \"$simulator_lib\""]
    } else {
      send_msg_id USF-[getSimulatorName]-95 ERROR "Failed to locate simulator library from 'XILINX' environment variable."
    }
  }

  set top_lib [::tclapp::aldec::riviera::usf_get_top_library]
  lappend arg_list "${top_lib}.${top}"

  set uut [get_property "RIVIERA.SIMULATE.UUT" $fs_obj]
  if { $uut != "" } {  
    lappend arg_list $uut
  }

  set design_files $::tclapp::aldec::riviera::a_sim_vars(l_design_files)
  if { [::tclapp::aldec::riviera::usf_contains_verilog $design_files] } {
    lappend arg_list "${top_lib}.glbl"
  }

  set cmd_str [join $arg_list " "]
  return $cmd_str
}

proc usf_create_do_file_for_simulation { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::riviera::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)
  set b_batch $::tclapp::aldec::riviera::a_sim_vars(b_batch)
  set b_scripts_only $::tclapp::aldec::riviera::a_sim_vars(b_scripts_only)
  set fs_obj [get_filesets $::tclapp::aldec::riviera::a_sim_vars(s_simset)]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-[getSimulatorName]-96 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_write_header $fh $do_file
  #set wave_do_filename $top;append wave_do_filename "_wave.do" ;#[BS]
  #set wave_do_file [file normalize [file join $dir $wave_do_filename]] ;#[BS]
  #usf_create_wave_do_file $wave_do_file ;#[BS]
  set cmd_str [usf_get_simulation_cmdline]
  usf_add_quit_on_error $fh "simulate"

  puts $fh "$cmd_str"
  #puts $fh "do \{$wave_do_filename\}" ;#[BS]
  puts $fh ""
  #puts $fh "view wave" ;#[BS]
  #puts $fh "view structure" ;#[BS]
  #puts $fh "view signals"; #[BS]
  puts $fh ""

  set b_log_all_signals [get_property "RIVIERA.SIMULATE.LOG_ALL_SIGNALS" $fs_obj]
  if { $b_log_all_signals } {
    puts $fh "log -rec *"
    if { [::tclapp::aldec::riviera::usf_contains_verilog $::tclapp::aldec::riviera::a_sim_vars(l_design_files)] } {
      puts $fh "log /glbl/GSR"
    }
  }
  
  set uut [get_property "RIVIERA.SIMULATE.UUT" $fs_obj]
  if { {} == $uut } {
    set uut "/$top/uut"
  }  
 
  # generate saif file for power estimation
  set saif [get_property "RIVIERA.SIMULATE.SAIF" $fs_obj] 
  if { {} != $saif } {
    puts $fh "wave -ports ${uut}/*"
  }

  set rt [string trim [get_property "RIVIERA.SIMULATE.RUNTIME" $fs_obj]]
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
    puts $fh "asdb2saif -internal -scope ${uut}/* wave.asdb \{$saif\}"
  }

  # add TCL sources
  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\""
  ::tclapp::aldec::riviera::usf_find_files tcl_src_files $filter
  if {[llength $tcl_src_files] > 0} {
    puts $fh ""
    foreach file $tcl_src_files {
      puts $fh "source \{$file\}"
    }
    puts $fh ""
  }

  if { $b_batch || $b_scripts_only } {
    puts $fh "\nquit -force"
  }
  close $fh
}

proc usf_write_header { fh filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  set timestamp   [clock format [clock seconds]]
  set mode_type   $::tclapp::aldec::riviera::a_sim_vars(s_mode)
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

proc usf_write_driver_shell_script { do_filename step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)
  set b_batch $::tclapp::aldec::riviera::a_sim_vars(b_batch)
  set b_scripts_only $::tclapp::aldec::riviera::a_sim_vars(b_scripts_only)

  set scr_filename $step;append scr_filename [::tclapp::aldec::riviera::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-[getSimulatorName]-97 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  set batch_sw {-c}
  if { ({simulate} == $step) && (!$b_batch) && (!$b_scripts_only) } {
    set batch_sw {}
  }

  set log_filename "${step}.log"
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "#!/bin/sh -f"
    puts $fh_scr "bin_path=\"$::tclapp::aldec::riviera::a_sim_vars(s_tool_bin_path)\""
    ::tclapp::aldec::riviera::usf_write_shell_step_fn $fh_scr
    puts $fh_scr "ExecStep \$bin_path/vsim $batch_sw -do \"do \{$do_filename\}\" -l $log_filename"
  } else {
    puts $fh_scr "@echo off"
    puts $fh_scr "set bin_path=$::tclapp::aldec::riviera::a_sim_vars(s_tool_bin_path)"
    puts $fh_scr "call \"%bin_path%/vsim\" $batch_sw -do \"do \{$do_filename\}\" -l $log_filename"
    puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
    puts $fh_scr "if \"%errorlevel%\"==\"0\" goto SUCCESS"
    puts $fh_scr ":END"
    puts $fh_scr "exit 1"
    puts $fh_scr ":SUCCESS"
    puts $fh_scr "exit 0"
  }
  close $fh_scr
}

proc usf_write_driver_shell_script_native { step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)
  set b_batch $::tclapp::aldec::riviera::a_sim_vars(b_batch)
  set b_scripts_only $::tclapp::aldec::riviera::a_sim_vars(b_scripts_only)

  set scr_filename $step;append scr_filename [::tclapp::aldec::riviera::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-[getSimulatorName]-98 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  set log_filename "${step}.log"
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "#!/bin/sh -f"
    usf_write_header $fh_scr $scr_file
    puts $fh_scr "\n# installation path setting"
    puts $fh_scr "bin_path=\"$::tclapp::aldec::riviera::a_sim_vars(s_tool_bin_path)\""
    usf_write_shell_step_fn_native $step $fh_scr
  } 
  close $fh_scr
}

proc usf_get_design_libs { files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set libs [list]
  foreach file $files {
    set type    [lindex [split $file {#}] 0]
    set library [lindex [split $file {#}] 1]
    if { {} == $library } {
      continue;
    }
    if { [lsearch -exact $libs $library] == -1 } {
      lappend libs $library
    }
  }
  return $libs
}

proc usf_set_initial_cmd { fh_scr cmd_str src_file type lib prev_type_arg prev_lib_arg } {
  # Summary: Print compiler command line and store previous file type and library information
  # Argument Usage:
  # Return Value:
  # None

  upvar $prev_type_arg prev_type
  upvar $prev_lib_arg  prev_lib

  puts $fh_scr "eval $cmd_str \\"
  puts $fh_scr "$src_file \\"

  set prev_type $type
  set prev_lib  $lib
}

proc usf_write_shell_step_fn_native { step fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::riviera::a_sim_vars(s_sim_top)
  set dir $::tclapp::aldec::riviera::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::aldec::riviera::a_sim_vars(s_simset)]
  set b_absolute_path $::tclapp::aldec::riviera::a_sim_vars(b_absolute_path)

  if { {compile} == $step } {
    puts $fh_scr "\n# directory path for design sources and include directories (if any) wrt this path"
    if { $b_absolute_path } {
      puts $fh_scr "origin_dir=\"$dir\""
    } else {
      puts $fh_scr "origin_dir=\".\""
    }
  
    set vlog_arg_list [list]
    set vlog_syntax [get_property "RIVIERA.COMPILE.VLOG_SYNTAX" $fs_obj]
    lappend vlog_arg_list "-$vlog_syntax"
    if { [get_property "RIVIERA.COMPILE.VERILOG_STRICT" $fs_obj] } {
      lappend vlog_arg_list "-j"
    }
    if { [get_property "RIVIERA.COMPILE.DEBUG" $fs_obj] } {
      lappend vlog_arg_list "-dbg"
    }
    if { [get_property "RIVIERA.COMPILE.INCREMENTAL" $fs_obj] } {
      lappend vlog_arg_list "-incr"
    }
    set more_vlog_options [string trim [get_property "RIVIERA.COMPILE.VLOG.MORE_OPTIONS" $fs_obj]]
    if { {} != $more_vlog_options } {
      set vlog_arg_list [linsert $vlog_arg_list end "$more_vlog_options"]
    }
    set vlog_cmd_str [join $vlog_arg_list " "]
    puts $fh_scr "\n# set vlog command line args"
    puts $fh_scr "vlog_opts=\"$vlog_cmd_str\""
  
    set vcom_arg_list [list]
    set vhdl_syntax [get_property "RIVIERA.COMPILE.VHDL_SYNTAX" $fs_obj]
    lappend vcom_arg_list "-$vhdl_syntax"
    if { [get_property "RIVIERA.COMPILE.VHDL_RELAX" $fs_obj] } {
      lappend vcom_arg_list "-relax"
    }
    if { [get_property "RIVIERA.COMPILE.REORDER" $fs_obj] } {
      lappend vcom_arg_list "-reorder"
    }
    if { [get_property "RIVIERA.COMPILE.DEBUG" $fs_obj] } {
      lappend vcom_arg_list "-dbg"
    }
    if { [get_property "RIVIERA.COMPILE.INCREMENTAL" $fs_obj] } {
      lappend vcom_arg_list "-incr"
    }
    set more_vcom_options [string trim [get_property "RIVIERA.COMPILE.VCOM.MORE_OPTIONS" $fs_obj]]
    if { {} != $more_vcom_options } {
      set vcom_arg_list [linsert $vcom_arg_list end "$more_vcom_options"]
    }
    set vcom_cmd_str [join $vcom_arg_list " "]
    puts $fh_scr "\n# set vcom command line args"
    puts $fh_scr "vcom_opts=\"$vcom_cmd_str\""
  
    set log "${step}.log"
    set redirect_cmd_str "2>&1 | tee -a $log"
  
    puts $fh_scr "\n# create libraries"
    puts $fh_scr "\$bin_path/vlib work $redirect_cmd_str"
    puts $fh_scr "\$bin_path/vlib msim $redirect_cmd_str\n"
  
    set design_libs [usf_get_design_libs $::tclapp::aldec::riviera::a_sim_vars(l_design_files)]
  
    # TODO:
    # If DesignFiles contains VHDL files, but simulation language is set to Verilog, we should issue CW
    # Vice verse, if DesignFiles contains Verilog files, but simulation language is set to VHDL
  
    set b_default_lib false
    set default_lib [get_property "DEFAULT_LIB" [current_project]]
    foreach lib $design_libs {
      if {[string length $lib] == 0} { continue; }
      puts $fh_scr "\$bin_path/vlib msim/$lib $redirect_cmd_str"
      if { $default_lib == $lib } {
        set b_default_lib true
      }
    }
    if { !$b_default_lib } {
      puts $fh_scr "\$bin_path/vlib msim/$default_lib $redirect_cmd_str"
    }
     
    puts $fh_scr "\n# map libraries"
    foreach lib $design_libs {
      if {[string length $lib] == 0} { continue; }
      puts $fh_scr "\$bin_path/vmap $lib msim/$lib $redirect_cmd_str"
    }
    if { !$b_default_lib } {
      puts $fh_scr "\$bin_path/vmap $default_lib msim/$default_lib $redirect_cmd_str"
    }
  
    puts $fh_scr "\n# compile design source files"

    set b_first true
    set prev_lib  {}
    set prev_type {}
    set b_redirect false
    set b_appended false
    set b_group_files [get_param "project.assembleFilesByLibraryForUnifiedSim"]

    foreach file $::tclapp::aldec::riviera::a_sim_vars(l_design_files) {
      set fargs    [split $file {#}]
      
      set type     [lindex $fargs 0]
      set lib      [lindex $fargs 1]
      set cmd_str  [lindex $fargs 2]
      set src_file [lindex $fargs 3]

      if { $b_group_files } {
        if { $b_first } {
          set b_first false
          usf_set_initial_cmd $fh_scr $cmd_str $src_file $type $lib prev_type prev_lib
        } else {
          if { ($type == $prev_type) && ($lib == $prev_lib) } {
            puts $fh_scr "$src_file \\"
            set b_redirect true
          } else {
            puts $fh_scr "$redirect_cmd_str\n"
            usf_set_initial_cmd $fh_scr $cmd_str $src_file $type $lib prev_type prev_lib
            set b_appended true
          }
        }
      } else {
        puts $fh_scr "\$bin_path/$cmd_str $src_file $redirect_cmd_str"
      }
    }

    if { $b_group_files } {
      if { (!$b_redirect) || (!$b_appended) } {
        puts $fh_scr "$redirect_cmd_str\n"
      }
    }
  
    # compile glbl file
    set b_load_glbl [get_property "RIVIERA.COMPILE.LOAD_GLBL" [get_filesets $::tclapp::aldec::riviera::a_sim_vars(s_simset)]]
    if { [::tclapp::aldec::riviera::usf_compile_glbl_file "riviera" $b_load_glbl $::tclapp::aldec::riviera::a_sim_vars(l_design_files)] } {
      ::tclapp::aldec::riviera::usf_copy_glbl_file
      set top_lib [::tclapp::aldec::riviera::usf_get_top_library]
      set file_str "-work $top_lib \"glbl.v\""
      puts $fh_scr "\n# compile glbl module\n\$bin_path/vlog $file_str $redirect_cmd_str"
    }
  } elseif { {elaborate} == $step } {
    set cmd_str [usf_get_elaboration_cmdline]
    puts $fh_scr ""

    set log "${step}.log"
    set redirect_cmd_str "2>&1 | tee -a $log"

    puts $fh_scr "\$bin_path/$cmd_str $redirect_cmd_str"
  }
}

proc usf_add_quit_on_error { fh step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_batch        $::tclapp::aldec::riviera::a_sim_vars(b_batch)
  set b_scripts_only $::tclapp::aldec::riviera::a_sim_vars(b_scripts_only)
  
  #hide 'onerror' command from called 'onerror' handler if error occurred: used as error detection in log files
  puts $fh "transcript off"
  #

  if { ({compile} == $step) || ({elaborate} == $step) } {
    puts $fh "onbreak {quit -force}"
    puts $fh "onerror {quit -force}\n"
  } elseif { ({simulate} == $step) } {
    if { ![get_param "simulator.rivieraNoQuitOnError"] } {
      puts $fh "onbreak {quit -force}"
      puts $fh "onerror {quit -force}\n"
    } 

    # quit on error always for batch/scripts only and when param is true
    if { ($b_batch || $b_scripts_only) && ([get_param "simulator.rivieraNoQuitOnError"])  } {
      puts $fh "onbreak {quit -force}"
      puts $fh "onerror {quit -force}\n"
    }
  }
}
}
