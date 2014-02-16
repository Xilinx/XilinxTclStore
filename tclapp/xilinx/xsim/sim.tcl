######################################################################
# HEADER_BEGIN
# COPYRIGHT NOTICE
# Copyright 2001-2014 Xilinx Inc. All Rights Reserved.
# http://www.xilinx.com/support
# HEADER_END
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
package require Vivado 2013.1
package require ::tclapp::xilinx::xsim::helpers

namespace eval ::tclapp::xilinx::xsim {
proc setup { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # initialize global variables
  ::tclapp::xilinx::xsim::usf_init_vars

  # initialize Vivado simulator variables
  usf_xsim_init_simulation_vars

  # read simulation command line args and set global variables
  usf_xsim_setup_args $args

  # perform initial simulation tasks
  if { [usf_xsim_setup_simulation] } {
    return 1
  }
  return 0
}

proc compile { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set scr_filename {}
  usf_xsim_write_compile_script scr_filename
  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::xsim::usf_launch_script "xsim" $step
}

proc elaborate { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set scr_filename {}
  send_msg_id Vivado-XSim-999 INFO "xsim::elaborate design"
  usf_xsim_write_elaborate_script scr_filename
  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  ::tclapp::xilinx::xsim::usf_launch_script "xsim" $step
}

proc simulate { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set scr_filename {}
  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)
  set fs_obj [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]
  set snapshot $::tclapp::xilinx::xsim::a_xsim_vars(s_snapshot)
  send_msg_id Vivado-XSim-999 INFO "xsim::simulate design"
  # create setup files
  set cmd_file {}
  set wcfg_file {}
  set b_add_view 0
  usf_xsim_write_simulate_script cmd_file wcfg_file b_add_view scr_filename

  if { $::tclapp::xilinx::xsim::a_sim_vars(b_scripts_only) } {
    send_msg_id Vivado-XSim-999 INFO "Scripts generated."
    return 0
  }

  # set launch args
  set key [usf_xsim_get_running_simulation_obj_key]
  #set log_file ${snapshot};append log_file ".log"
  set log_file "simulate";append log_file ".log"
  set view_arg {}
  if { $b_add_view } {
    set view_arg " -view \{$wcfg_file\}"
  }
  set more_options [string trim [get_property "XSIM.SIMULATE.MORE_OPTIONS" $fs_obj]]

  # launch xsim
  send_msg_id Vivado-XSim-999 INFO "Loading simulator feature"
  load_feature simulator

  set cwd [pwd]
  cd $dir
  set retval [xsim $snapshot -key $key -tclbatch $cmd_file -log $log_file]
  cd $cwd

  #set proc_name [lindex [split [info level 0] " "] 0]
  #set step [lindex [split $proc_name {:}] end]
  #::tclapp::xilinx::xsim::usf_launch_script "xsim" $step

  # close for batch flow
  if { $::tclapp::xilinx::xsim::a_sim_vars(b_batch) } {
    send_msg_id Vivado-XSim-999 INFO "Closing simulation..."
    close_sim
  }

  return 0
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
 
  # set the simulation flow
  ::tclapp::xilinx::xsim::usf_set_simulation_flow

  # set the simulation run dir
  ::tclapp::xilinx::xsim::usf_set_run_dir

  set run_dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)

  # create simulation launch dir <project>/<project.sim>/<simset>/<mode>/<type>
  if { [file exists $run_dir] && (!$::tclapp::xilinx::xsim::a_sim_vars(b_noclean_dir)) } {
    # TODO: check for running snapshots if any (shutdown them first)
  }
  ::tclapp::xilinx::xsim::usf_create_launch_dir

  # set default object
  if { [::tclapp::xilinx::xsim::usf_set_sim_tcl_obj] } {
    puts "failed to set tcl obj"
    return 1
  }
  # print launch_simulation arg values
  ::tclapp::xilinx::xsim::usf_print_args

  # write functional/timing netlist for post-* simulation
  ::tclapp::xilinx::xsim::usf_write_design_netlist

  # prepare IP's for simulation
  ::tclapp::xilinx::xsim::usf_prepare_ip_for_simulation

  # fetch the compile order for the specified object
  ::tclapp::xilinx::xsim::usf_get_compile_order_for_obj

  # create setup file
  #usf_xsim_write_setup_files

  return 0
}

proc usf_xsim_init_simulation_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_xsim_vars
  set a_xsim_vars(b_32bit)    0
  set a_xsim_vars(s_snapshot) [usf_xsim_get_snapshot]
  set a_xsim_vars(s_dbg_sw)   {-dbg}
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
  # [-noclean_dir]: Do not remove simulation run directory files
  # [-batch]: Execute batch flow simulation run (non-gui)
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
      "-noclean_dir"    { set ::tclapp::xilinx::xsim::a_sim_vars(b_noclean_dir) 1 }
      "-batch"          { set ::tclapp::xilinx::xsim::a_sim_vars(b_batch) 1 }
      "-int_os_type"    { incr i;set ::tclapp::xilinx::xsim::a_sim_vars(s_int_os_type) [lindex $args $i] }
      "-int_debug_mode" { incr i;set ::tclapp::xilinx::xsim::a_sim_vars(s_int_debug_mode) [lindex $args $i] }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id Vivado-XSim-999 ERROR "Unknown option '$option', please type 'simulate -help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

proc usf_xsim_write_setup_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)

  set filename "xsim.ini"
  set file [file normalize [file join $dir $filename]]
  set fh 0

  if {[catch {open $file w} fh]} {
    send_msg_id Vivado-XSim-999 ERROR "failed to open file to write ($file)\n"
    return 1
  }

  foreach lib [::tclapp::xilinx::xsim::usf_get_compile_order_libs] {
    puts $fh "$lib=xsim.dir/$lib"
  }
  close $fh
}

proc usf_xsim_write_compile_script { scr_filename_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $scr_filename_arg scr_filename
  variable a_xsim_vars
 
  set top $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)
  set src_mgmt_mode [get_property "SOURCE_MGMT_MODE" [current_project]]
 
  set vlog_filename ${top};append vlog_filename "_vlog.prj"
  set vlog_file [file normalize [file join $dir $vlog_filename]]
  set fh_vlog 0
  if {[catch {open $vlog_file w} fh_vlog]} {
    send_msg_id Vivado-XSim-999 ERROR "failed to open file to write ($vlog_file)\n"
    return 1
  }
 
  set vhdl_filename ${top};append vhdl_filename "_vhdl.prj"
  set vhdl_file [file normalize [file join $dir $vhdl_filename]]
  set fh_vhdl 0
  if {[catch {open $vhdl_file w} fh_vhdl]} {
    send_msg_id Vivado-XSim-999 ERROR "failed to open file to write ($vhdl_file)\n"
    return 1
  }
 
  set files [::tclapp::xilinx::xsim::usf_uniquify_cmd_str [::tclapp::xilinx::xsim::usf_get_files_for_compilation]]
  foreach file $files {
    set type    [lindex [split $file {#}] 0]
    set lib     [lindex [split $file {#}] 1]
    set cmd_str [lindex [split $file {#}] 2]
    switch $type {
      {VERILOG} { puts $fh_vlog $cmd_str }
      {VHDL}    { puts $fh_vhdl $cmd_str }
      default   { 
        send_msg_id Vivado-XSim-999 ERROR "Unknown filetype '$type':$file\n"
      }
    }
  }
 
  # compile glbl file
  set b_load_glbl [get_property "XSIM.ELABORATE.LOAD_GLBL" [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]]
  if { [::tclapp::xilinx::xsim::usf_compile_glbl_file "xsim" $b_load_glbl] } {
    set default_lib [get_property "DEFAULT_LIB" [current_project]]
    set file_str "$default_lib \"[::tclapp::xilinx::xsim::usf_get_glbl_file]\""
    puts $fh_vlog "\n# Compile glbl module\nverilog $file_str"
  }
 
  # nosort?
  set b_no_sort [get_property "XSIM.COMPILE.XVLOG.NOSORT" [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]]
  if { $b_no_sort || ({DisplayOnly} == $src_mgmt_mode) || ({None} == $src_mgmt_mode) } {
    puts $fh_vlog "\n# Do not sort compile order\nnosort"
  }
    
  close $fh_vlog
  close $fh_vhdl

  # write compile.sh/.bat
  set scr_filename "compile";append scr_filename [::tclapp::xilinx::xsim::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id Vivado-XSim-999 ERROR "failed to open file to write ($scr_file)\n"
    return 1
  }
 
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "#!/bin/sh -f"
    puts $fh_scr "xv_path=\"$::env(XILINX_VIVADO)\""
    ::tclapp::xilinx::xsim::usf_write_shell_step_fn $fh_scr
    puts $fh_scr "ExecStep \$xv_path/bin/xvlog -prj $vlog_filename" 
    puts $fh_scr "ExecStep \$xv_path/bin/xvhdl -prj $vhdl_filename" 
  } else {
    puts $fh_scr "@echo off"
    puts $fh_scr "set xv_path=\"$::env(RDI_BINROOT)\""
    puts $fh_scr "call %xv_path%/xvlog $a_xsim_vars(s_dbg_sw) -prj $vlog_filename -log compile.log"
    puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
    puts $fh_scr "call %xv_path%/xvhdl $a_xsim_vars(s_dbg_sw) -prj $vhdl_filename -log compile.log"
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
    send_msg_id Vivado-XSim-999 ERROR "failed to open file to write ($scr_file)\n"
    return 1
  }

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "#!/bin/sh -f"
    puts $fh_scr "xv_path=\"$::env(XILINX_VIVADO)\""
    ::tclapp::xilinx::xsim::usf_write_shell_step_fn $fh_scr
    set args [usf_xsim_get_xelab_cmdline_args]
    puts $fh_scr "ExecStep \$xv_path/bin/xelab $args"
  } else {
    puts $fh_scr "@echo off"
    puts $fh_scr "set xv_path=\"$::env(RDI_BINROOT)\""
    set args [usf_xsim_get_xelab_cmdline_args]
    puts $fh_scr "call %xv_path%/xelab $a_xsim_vars(s_dbg_sw) $args"
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
    #set wdf_file $::tclapp::xilinx::xsim::a_xsim_vars(s_snapshot);append wdf_file ".wdb"
    set wdf_file "xsim";append wdf_file ".wdb"
  } else {
    set wdf_file [file normalize $wdf_file]
  }

  # get the wcfg file information
  set b_linked_wcfg_exist 0
  set wdb_filename [file root [file tail $wdf_file]]
  set wcfg_file [get_property "XSIM.SIMULATE.VIEW" $fs_obj]
  if { {} == $wcfg_file } {
    set wcfg_file_in_wdb_dir ${wdb_filename};append wcfg_file_in_wdb_dir ".wcfg"
    set wcfg_file_in_wdb_dir [file normalize [file join $dir $wcfg_file_in_wdb_dir]]
    if { [file exists $wcfg_file_in_wdb_dir] } {
      set b_linked_wcfg_exist 1
    }
  } else {
    set wcfg_file [file normalize $wcfg_file]
    if { ![file exists $wcfg_file] } {
      send_msg_id Vivado-XSim-999 WARNING "Specified wcfg file '$wcfg_file' doesn't exist, ignored\n"
      set wcfg_file {}
    }
  }

  set b_add_wave 0
  set b_add_view 0

  if { {} != $wcfg_file } {
    # pass -view
    set b_add_view 1
  } elseif { $b_linked_wcfg_exist } {
    # do not pass "add wave" and "-view"
  } else {
    set b_add_wave 1
  }

  # get command file (if specified)
  set cmd_file [get_property "XSIM.SIMULATE.TCLBATCH" $fs_obj]
  if { {} == $cmd_file } {
    set cmd_file ${top};append cmd_file ".tcl"
    usf_xsim_write_cmd_file $cmd_file $b_add_wave
  }

  set scr_filename "simulate";append scr_filename [::tclapp::xilinx::xsim::usf_get_script_extn]
  set scr_file [file normalize [file join $dir $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id Vivado-XSim-999 ERROR "failed to open file to write ($scr_file)\n"
    return 1
  }
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "#!/bin/sh -f"
    puts $fh_scr "xv_path=\"$::env(XILINX_VIVADO)\""
    ::tclapp::xilinx::xsim::usf_write_shell_step_fn $fh_scr
    set cmd_args [usf_xsim_get_xsim_cmdline_args $cmd_file $wcfg_file $b_add_view]
    puts $fh_scr "ExecStep \$xv_path/bin/xsim $cmd_args"
  } else {
    puts $fh_scr "@echo off"
    puts $fh_scr "set xv_path=\"$::env(RDI_BINROOT)\""
    set cmd_args [usf_xsim_get_xsim_cmdline_args $cmd_file $wcfg_file $b_add_view]
    puts $fh_scr "call %xv_path%/xsim $cmd_args"
    puts $fh_scr "if \"%errorlevel%\"==\"0\" goto SUCCESS"
    puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
    puts $fh_scr ":END"
    puts $fh_scr "exit 1"
    puts $fh_scr ":SUCCESS"
    puts $fh_scr "exit 0"
  }
  close $fh_scr
}

proc usf_xsim_get_xelab_cmdline_args {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
  set dir $::tclapp::xilinx::xsim::a_sim_vars(s_launch_dir)
  set sim_flow $::tclapp::xilinx::xsim::a_sim_vars(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::xilinx::xsim::a_sim_vars(s_simset)]

  set args_list [list]

  set os $::tclapp::xilinx::xsim::a_sim_vars(s_int_os_type)
  if { {64} == $os } { lappend args_list "-m64" }
  if { {32} == $os } { lappend args_list "-m32" }

  set dbg $::tclapp::xilinx::xsim::a_sim_vars(s_int_debug_mode)
  if { $dbg } { lappend args_list "-dbg" }

  # --debug
  set value [get_property "XSIM.ELABORATE.DEBUG_LEVEL" $fs_obj]
  lappend args_list "--debug $value"

  # --rangecheck
  set value [get_property "XSIM.ELABORATE.RANGECHECK" $fs_obj]
  if { $value } { lappend args_list "--rangecheck" }

  # --dll
  set value [get_property "XSIM.ELABORATE.DLL" $fs_obj]
  if { $value } { lappend args_list "--dll" }

  # --relax
  set value [get_property "XSIM.ELABORATE.RELAX" $fs_obj]
  if { $value } { lappend args_list "--relax" }

  # --mt
  set value [get_property "XSIM.ELABORATE.MT_LEVEL" $fs_obj]
  if { {auto} != $value } { lappend args_list "--mt $value" }

  set netlist_mode [get_property "NL.MODE" $fs_obj]

  if { ({post_synth_sim} == $sim_flow || {post_impl_sim} == $sim_flow) && ({timesim} == $netlist_mode) } {
     set delay [get_property "XSIM.ELABORATE.SDF_DELAY" $fs_obj]
     if { {sdfmin} == $delay } { lappend args_list "--mindelay" }
     if { {sdfmax} == $delay } { lappend args_list "--maxdelay" }
  }
 
  # --include
  foreach incl_dir [::tclapp::xilinx::xsim::usf_get_include_file_dirs] {
    set dir [string map {\\ /} $incl_dir]
    lappend args_list "--include $dir"
  }

  # -i
  set unique_incl_dirs [list]
  foreach incl_dir [get_property "INCLUDE_DIRS" $fs_obj] {
    if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
      lappend unique_incl_dirs $incl_dir
      lappend args_list "-i $incl_dir"
    }
  }

  # -d (verilog macros)
  set v_defines [get_property "VERILOG_DEFINE" $fs_obj]
  if { [llength $v_defines] > 0 } {
    foreach element $v_defines {
      set key_val_pair [split $element "="]
      set name [lindex $key_val_pair 0]
      set val  [lindex $key_val_pair 1]
      if { [string length $val] > 0 } {
        set str "\"$name=$val\""
        lappend args_list "-d $str"
      }
    }
  }

  # -generic_top (verilog macros)
  set v_generics [get_property "VHDL_GENERIC" $fs_obj]
  if { [llength $v_generics] > 0 } {
    foreach element $v_generics {
      set key_val_pair [split $element "="]
      set name [lindex $key_val_pair 0]
      set val  [lindex $key_val_pair 1]
      if { [string length $val] > 0 } {
        set str "\"$name=$val\""
        lappend args_list "-generic_top $str"
      }
    }
  }

  # design source libs
  foreach lib [::tclapp::xilinx::xsim::usf_get_compile_order_libs] {
    lappend args_list "-L $lib"
  }

  # add simulation libraries
  set b_compile_unifast [get_property "XSIM.ELABORATE.UNIFAST" $fs_obj]
  if { [::tclapp::xilinx::xsim::usf_add_unisims $b_compile_unifast] } { lappend args_list "-L unisims_ver" }
  if { [::tclapp::xilinx::xsim::usf_add_simprims] } { lappend args_list "-L simprims_ver" }
  if { [::tclapp::xilinx::xsim::usf_add_unifast $b_compile_unifast] } { lappend args_list "-L unifast_ver" }
  if { [::tclapp::xilinx::xsim::usf_add_unimacro] } { lappend args_list "-L unimacro_ver" }
  if { [::tclapp::xilinx::xsim::usf_add_secureip] } { lappend args_list "-L secureip" }

  # snapshot
  lappend args_list "--snapshot $::tclapp::xilinx::xsim::a_xsim_vars(s_snapshot)"

  # avoid pulse swallowing for timing
  if { ({post_synth_sim} == $sim_flow || {post_impl_sim} == $sim_flow) && ({timesim} == $netlist_mode) } {
    lappend args_list "-transport_int_delays"
    lappend args_list "-pulse_r 0"
    lappend args_list "-pulse_int_r 0"
  }

  # add top's
  set top_level_inst_names [usf_xsim_get_top_level_instance_names]
  foreach top $top_level_inst_names {
    lappend args_list "$top"
  }

  # add glbl top
  set b_verilog_sim_netlist 0
  if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    set target_lang [get_property "TARGET_LANGUAGE" [current_project]]
    if { {Verilog} == $target_lang } {
      set b_verilog_sim_netlist 1
    }
  }
  set top_lib [::tclapp::xilinx::xsim::usf_get_top_library]
  if { [::tclapp::xilinx::xsim::usf_contains_verilog] || $b_verilog_sim_netlist } {
    set b_load_glbl [get_property "XSIM.ELABORATE.LOAD_GLBL" $fs_obj]
    if { ([lsearch ${top_level_inst_names} {glbl}] == -1) && $b_load_glbl } {
      set glbl_name ${top_lib}.glbl
      lappend args_list "$glbl_name"
    }
  }

  lappend args_list "-log elaborate.log"

  # other options
  set other_opts [get_property "XSIM.ELABORATE.MORE_OPTIONS" $fs_obj]
  if { {} != $other_opts } {
    lappend args_list "$other_opts"
  }

  set cmd_args [join $args_list " "]
  return $cmd_args
}

proc usf_xsim_get_xsim_cmdline_args { cmd_file wcfg_file b_add_view } {
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

  # TODO:cr filed
  #lappend args_list "-key"
  #lappend args_list "[usf_xsim_get_running_simulation_obj_key]"

  lappend args_list "-tclbatch"
  lappend args_list "$cmd_file" 
  if { $b_add_view } {
    lappend args_list "-view"
    lappend args_list "$wcfg_file"
  }
  #set log_file ${snapshot};append log_file ".log"
  set log_file "simulate";append log_file ".log"
  lappend args_list "-log"
  lappend args_list "$log_file"

  # more options
  set more_options [string trim [get_property "XSIM.SIMULATE.MORE_OPTIONS" $fs_obj]]
  if { {} != $more_options } {
    lappend args_list $more_options
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
    send_msg_id Vivado-XSim-999 ERROR "failed to open file to write ($cmd_file)\n"
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

  set b_timing 0
  if { {timing} == $::tclapp::xilinx::xsim::a_sim_vars(s_type) } {
    set b_timimg 1
  }
  # generate saif file for power estimation
  set saif [get_property "XSIM.SIMULATE.SAIF" $fs_obj]
  if { {} != $saif } {
    set uut [get_property "UNIT_UNDER_TEST" $fs_obj]
    puts $fh_scr "open_saif \"$saif\""
    if { {} == $uut } {
      set uut "/$top/uut/*"
    }
    if { $b_timing } {
      puts $fh_scr "log_saif \[get_objects -r *\]"
    } else {
      set filter "get_objects -filter \{type==in_port || type==out_port || type==inout_port\}"
      puts $fh_scr "log_saif \[$filter [::tclapp::xilinx::xsim::usf_resolve_uut_name uut]\]"
    }
  }

  set runtime [get_property "RUNTIME" $fs_obj]
  if { {} != $runtime } {
    puts $fh_scr "run $runtime"
  }

  if { {} != $saif } {
    puts $fh_scr "close_saif"
  }

  set filter "FILE_TYPE == \"TCL\""
  foreach file [get_files -all -quiet -used_in "simulation" -filter $filter] {
     puts $fh_scr "source \{$file\}"
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
  #set snapshot [get_property "XELAB.SNAPSHOT" [get_filesets $a_sim_vars(s_simset)]]
  set snapshot {<Default>}
  if { ({<Default>} == $snapshot) || ({} == $snapshot) } {
    set snapshot $::tclapp::xilinx::xsim::a_sim_vars(s_sim_top)
    switch -regexp -- $::tclapp::xilinx::xsim::a_sim_vars(s_simulation_flow) {
      {behav_sim} { set snapshot [append snapshot "_behav"] }
      {post_synth_sim} -
      {post_impl_sim} {
        switch -regexp -- $a_sim_vars(s_type) {
          {functional} { set snapshot [append snapshot "_func"] }
          {timing} {set snapshot [append snapshot "_time"] }
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
  set assoc_lib "${top_lib}";append assoc_lib {.}
  set top_names [split $top " "]
  if { [llength $top_names] > 1 } {
    foreach name $top_names {
      if { [lsearch $top_level_instance_names $name] == -1 } {
        if { ![regexp "^$assoc_lib" $name] } {
          set name ${assoc_lib}$name
        }
        lappend top_level_instance_names $name
      }
    }
  } else {
    set name $top_names
    if { ![regexp "^$assoc_lib" $name] } {
      set name ${assoc_lib}$name
    }
    lappend top_level_instance_names $name
  }
  return $top_level_instance_names
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
}
