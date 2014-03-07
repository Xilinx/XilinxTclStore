####################################################################################
#
# export_simulation.tcl (export a simulation script file for IES/VCS_MX simulator)
#
# Script created on 07/12/2013 by Raj Klair (Xilinx, Inc.)
#
# 2014.1 - v1.0 (rev. 1)
#  * no changes
#
# 2013.4 - v1.0 (rev. 1)
#  * no change
#
# 2013.3 - version 1.0 (rev. 1)
#  * initial version
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::projutils {
  namespace export export_simulation
}

namespace eval ::tclapp::xilinx::projutils {
proc export_simulation {args} {
  # Summary:
  # Export a script and associated data files (if any) for driving standalone simulation using the specified simulator. 

  # Argument Usage:
  # [-of_objects <arg> = None]: Export simulation script for the specified object
  # [-lib_map_path <arg> = Empty]: Precompiled simulation library directory path. If not specified, then please follow the instructions in the generated script header to manually provide the simulation library mapping information.
  # [-script_name <arg> = top_module.sh]: Output shell script filename. If not specified, then file with a default name will be created with the '.sh' extension.
  # [-absolute_path]: Make all file paths absolute wrt the reference directory
  # [-32bit]: Perform 32bit compilation
  # [-force]: Overwrite previous files
  # -directory <arg>: Directory where the simulation script will be exported
  # -simulator <arg>: Simulator for which the simulation script will be created (<name>: ies|vcs_mx)

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: xilinxtclstore, projutils

  variable a_xport_sim_vars
  variable l_valid_simulator_types

  reset_global_sim_vars

  set options [split $args " "]
  # these options are must
  if {[lsearch $options {-simulator}] == -1} {
    send_msg_id Vivado-projutils-013 ERROR "Missing option '-simulator', please type 'export_simulation -help' for usage info.\n"
    return 1
  }
  if {[lsearch $options {-directory}] == -1} {
    send_msg_id Vivado-projutils-039 ERROR "Missing option '-directory', please type 'export_simulation -help' for usage info.\n"
    return 1
  }

  # process options
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-of_objects"               { incr i;set a_xport_sim_vars(sp_tcl_obj) [lindex $args $i] }
      "-32bit"                    { set a_xport_sim_vars(b_32bit) 1 }
      "-absolute_path"            { set a_xport_sim_vars(b_absolute_path) 1 }
      "-lib_map_path"             { incr i;set a_xport_sim_vars(s_lib_map_path) [lindex $args $i] }
      "-script_name"              { incr i;set a_xport_sim_vars(s_script_filename) [lindex $args $i] }
      "-force"                    { set a_xport_sim_vars(b_overwrite) 1 }
      "-simulator"                { incr i;set a_xport_sim_vars(s_simulator) [lindex $args $i] }
      "-directory"                { incr i;set a_xport_sim_vars(s_out_dir) [lindex $args $i] }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id Vivado-projutils-014 ERROR "Unknown option '$option', please type 'export_simulation -help' for usage info.\n"
          return 1
        }
      }
    }
  }

  # is project open?
  set a_xport_sim_vars(s_project_name) [get_property name [current_project]]
  set a_xport_sim_vars(s_project_dir) [get_property directory [current_project]]

  # is valid simulator specified?
  if { [lsearch -exact $l_valid_simulator_types $a_xport_sim_vars(s_simulator)] == -1 } {
    send_msg_id Vivado-projutils-015 ERROR \
      "Invalid simulator type specified. Please type 'export_simulation -help' for usage info.\n"
    return 1
  }

  # is valid tcl obj specified?
  if { ([lsearch $options {-of_objects}] != -1) && ([llength $a_xport_sim_vars(sp_tcl_obj)] == 0) } {
    send_msg_id Vivado-projutils-038 ERROR "Invalid object specified. The object does not exist.\n"
    return 1
  }
 
  # set pretty name
  if { [set_simulator_name] } {
    return 1
  }

  # is managed project?
  set a_xport_sim_vars(b_is_managed) [get_property managed_ip [current_project]]

  # setup run dir
  if { [create_sim_files_dir] } {
    return 1
  }

  # set default object if not specified, bail out if no object found
  if { [set_default_tcl_obj] } {
    return 1
  }

  # write script
  if { [write_sim_script] } {
    return 1
  }

  # generate mem files
  if { [is_embedded_flow] } {
    send_msg_id Vivado-projutils-060 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
    generate_mem_files $a_xport_sim_vars(s_out_dir)
  }

  # TCL_OK
  return 0
}
}

namespace eval ::tclapp::xilinx::projutils {
#
# export_simulation tcl script argument & file handle vars
#
variable a_xport_sim_vars
variable l_compile_order_files [list]

variable l_valid_simulator_types [list]
set l_valid_simulator_types [list ies vcs_mx]

variable l_valid_ip_extns [list]
set l_valid_ip_extns [list ".xci" ".bd" ".slx"]

variable s_data_files_filter
set s_data_files_filter "FILE_TYPE == \"Data Files\" || FILE_TYPE == \"Memory Initialization Files\" || FILE_TYPE == \"Coefficient Files\""

# embedded file extension types
variable s_embedded_files_filter
set s_embedded_files_filter        "FILE_TYPE == \"BMM\" || FILE_TYPE == \"ElF\""

proc reset_global_sim_vars {} {
  # Summary: initializes global namespace simulation vars
  # This helper command is used to reset the simulation variables used in the script.
  # Argument Usage:
  # none
  # Return Value:
  # None

  variable a_xport_sim_vars

  set a_xport_sim_vars(s_simulator)         ""
  set a_xport_sim_vars(s_simulator_name)    ""
  set a_xport_sim_vars(s_lib_map_path)      ""
  set a_xport_sim_vars(s_script_filename)   ""
  set a_xport_sim_vars(s_script_extn)       "sh"
  set a_xport_sim_vars(s_out_dir)           ""
  set a_xport_sim_vars(b_32bit)             0
  set a_xport_sim_vars(b_absolute_path)     0             
  set a_xport_sim_vars(b_overwrite)         0
  set a_xport_sim_vars(sp_tcl_obj)          ""
  set a_xport_sim_vars(s_sim_top)           ""
  set a_xport_sim_vars(s_project_name)      ""
  set a_xport_sim_vars(s_project_dir)       ""
  set a_xport_sim_vars(b_is_managed)        0 

  set l_compile_order_files               [list]
}

proc set_default_tcl_obj {} {
  # Summary: If -of_objects not specified, then for managed-ip project error out
  #          or set active simulation fileset for an RTL/GateLvl project
  # Argument Usage:
  # none
  # Return Value:
  # true (0) if success, false (1) otherwise
 
  variable a_xport_sim_vars
  set tcl_obj $a_xport_sim_vars(sp_tcl_obj)
  if { [string length $tcl_obj] == 0 } {
    if { $a_xport_sim_vars(b_is_managed) } {
      set ips [get_ips]
      if {[llength $ips] == 0} {
        send_msg_id Vivado-projutils-016 INFO "No IP's found in the current project.\n"
        return 1
      }
      # object not specified, error
      send_msg_id Vivado-projutils-035 ERROR "No IP source object specified. Please type 'export_simulation -help' for usage info.\n"
      return 1
    } else {
      set curr_simset [current_fileset -simset]
      # do we have upto date ip's (generated and not stale)? if not print critical warning
      verify_ip_status $curr_simset
      set sim_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_filesets $curr_simset]]
      if { [llength $sim_files] == 0 } {
        send_msg_id Vivado-projutils-017 INFO "No simulation files found in the current simset.\n"
        return 1
      }
      set a_xport_sim_vars(sp_tcl_obj) $curr_simset
    }
  } else {
    # is valid tcl object?
    if { ![is_ip $tcl_obj] } {
      if { [is_fileset $tcl_obj] } {
        set fs_type [get_property fileset_type [get_filesets $tcl_obj]]
        if { [string equal -nocase $fs_type "Constrs"] } {
          send_msg_id Vivado-projutils-034 ERROR "Invalid object type specified\n"
          return 1
        }
        # do we have upto date ip (generated and not stale)? if not print critical warning
        verify_ip_status $tcl_obj
      }
    } else {
      set ip_file ""
      # is ip object? fetch associated file, else just return file
      if {[regexp -nocase {^ip} [get_property [rdi::get_attr_specs CLASS -object $tcl_obj] $tcl_obj]] } {
        set ip_file [get_files -all -quiet [get_property ip_file $tcl_obj]]
      } else {
        set ip_file [get_files -all -quiet $tcl_obj]
      }
      set ip_obj_count [llength $ip_file]
      if { $ip_obj_count == 0 } {
        send_msg_id Vivado-projutils-009 ERROR "The specified object could not be found in the project:$tcl_obj\n"
        return 1
      } elseif { $ip_obj_count > 1 } {
        send_msg_id Vivado-projutils-019 ERROR "The script expects exactly one object got $ip_obj_count\n"
        return 1
      }
      # is IP locked?
      if { [get_property is_locked $ip_file] == 1} {
        send_msg_id Vivado-projutils-041 WARNING "The specified object is locked:$tcl_obj\n"
      }
      set a_xport_sim_vars(sp_tcl_obj) $ip_file
      # do we have upto date ip (generated and not stale)? if not print critical warning
      verify_ip_status $a_xport_sim_vars(sp_tcl_obj)
    }
  }
  return 0
}
 
proc write_sim_script {} {
  # Summary: Get the compiled order for the specified source object and export files
  # Argument Usage:
  # none
  # Return Value:
  # true (0) if success, false (1) otherwise
 
  variable a_xport_sim_vars
 
  set tcl_obj $a_xport_sim_vars(sp_tcl_obj)
  if { [is_ip $tcl_obj] } {
    set a_xport_sim_vars(s_sim_top) [file tail [file root $tcl_obj]]
    send_msg_id Vivado-projutils-042 INFO "Inspecting IP design source files for '$a_xport_sim_vars(s_sim_top)'...\n"
    if {[export_sim_files_for_ip $tcl_obj]} {
      return 1
    }
  } elseif { [is_fileset $tcl_obj] } {
    set a_xport_sim_vars(s_sim_top) [get_property top [get_filesets $tcl_obj]]
    send_msg_id Vivado-projutils-008 INFO "Inspecting design source files for '$a_xport_sim_vars(s_sim_top)' in fileset '$tcl_obj'...\n"
    if {[string length $a_xport_sim_vars(s_sim_top)] == 0} {
      set a_xport_sim_vars(s_sim_top) "unknown"
    }
    if {[export_sim_files_for_fs $tcl_obj]} {
      return 1
    }
  } else {
    send_msg_id Vivado-projutils-020 INFO "Unsupported object source: $tcl_obj\n"
    return 1
  }
  send_msg_id Vivado-projutils-021 INFO \
    "File '$a_xport_sim_vars(s_script_filename)' exported (file path:$a_xport_sim_vars(s_out_dir)/$a_xport_sim_vars(s_script_filename))\n"
 
  return 0
}
 
proc export_sim_files_for_ip { tcl_obj } {
  # Summary: 
  # Argument Usage:
  # source object
  # Return Value:
  # true (0) if success, false (1) otherwise

  variable a_xport_sim_vars
  variable s_data_files_filter
  variable l_compile_order_files

  set obj_name [file root [file tail $tcl_obj]]
  set ip_filename [file tail $tcl_obj]
  set l_compile_order_files [remove_duplicate_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]]]
  print_source_info

  if { {} == $a_xport_sim_vars(s_script_filename) } {
    set simulator $a_xport_sim_vars(s_simulator)
    set ip_name [file root $ip_filename]
    set a_xport_sim_vars(s_script_filename) "${ip_name}_sim_${simulator}.$a_xport_sim_vars(s_script_extn)"
  }
 
  if {[export_simulation_for_object $obj_name]} {
    return 1
  }
 
  # fetch ip data files and export to output dir
  set data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_filename] -filter $s_data_files_filter]
  export_data_files $data_files
 
  return 0
}
 
proc export_sim_files_for_fs { tcl_obj } {
  # Summary: 
  # Argument Usage:
  # source object
  # Return Value:
  # true (0) if success, false (1) otherwise
  
  variable a_xport_sim_vars
  variable l_compile_order_files

  set obj_name $tcl_obj
  set used_in_val "simulation"
  switch [get_property fileset_type [get_filesets $tcl_obj]] {
    "DesignSrcs"     { set used_in_val "synthesis" }
    "SimulationSrcs" { set used_in_val "simulation"}
    "BlockSrcs"      { set used_in_val "synthesis" }
  }

  set l_compile_order_files [remove_duplicate_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $tcl_obj]]]
  if { [llength $l_compile_order_files] == 0 } {
    send_msg_id Vivado-projutils-018 INFO "Empty fileset: $obj_name\n"
    return 1
  } else {
    print_source_info
    if { {} == $a_xport_sim_vars(s_script_filename) } {
      set simulator $a_xport_sim_vars(s_simulator)
      set a_xport_sim_vars(s_script_filename) "$a_xport_sim_vars(s_sim_top)_sim_${simulator}.$a_xport_sim_vars(s_script_extn)"
    }

    if {[export_simulation_for_object $obj_name]} {
      return 1
    }
 
    # fetch data files for all IP's in simset and export to output dir
    export_fs_data_files
  }

  return 0
}
 
proc is_ip { tcl_obj } {
  # Summary: Determine if specified source object is IP
  # Argument Usage:
  # source object
  # Return Value:
  # true (1) if specified object is an IP, false (0) otherwise
 
  variable l_valid_ip_extns 

  # check if ip file extension
  if { [lsearch -exact $l_valid_ip_extns [file extension $tcl_obj]] >= 0 } {
    return 1
  } else {
    # check if IP object
    if {[regexp -nocase {^ip} [get_property [rdi::get_attr_specs CLASS -object $tcl_obj] $tcl_obj]] } {
      return 1
    }
  }
  return 0
}

proc is_fileset { tcl_obj } {
  # Summary: Determine if specified tcl source object is fileset
  # Argument Usage:
  # source object
  # Return Value:
  # true (1) if specified object is a fileset, false (0) otherwise

  if {[regexp -nocase {^fileset_type} [rdi::get_attr_specs -quiet -object $tcl_obj -regexp .*FILESET_TYPE.*]]} {
    return 1
  }
 
  return 0
}

proc print_source_info {} {
  # Summary: Print sources information on the console
  # Argument Usage:
  # none
  # Return Value:
  # None
 
  variable l_compile_order_files
 
  set n_total_srcs [llength $l_compile_order_files]
  set n_vhdl_srcs     0
  set n_verilog_srcs  0
  
  foreach file $l_compile_order_files {
    set file_type [get_property file_type [get_files -quiet -all $file]]
    switch -- $file_type {
      {VHDL}    { incr n_vhdl_srcs    }
      {Verilog} { incr n_verilog_srcs }
    }
  }

  send_msg_id Vivado-projutils-004 INFO "Number of design source files found = $n_total_srcs\n"
}
 
proc set_simulator_name {} {
  # Summary: Set simulator name for the specified simulator type
  # Argument Usage:
  # none
  # Return Value:
  # True (0) if name set, false (1) otherwise
 
  variable a_xport_sim_vars
  set simulator $a_xport_sim_vars(s_simulator)
  switch -regexp -- $simulator {
    "ies"       { set a_xport_sim_vars(s_simulator_name) "Cadence Incisive Enterprise" }
    "vcs_mx"    { set a_xport_sim_vars(s_simulator_name) "Synopsys VCS MX" }
    default {
      send_msg_id Vivado-projutils-026 ERROR "Invalid simulator ($simulator)\n"
      close $fh
      return 1
    }
  }
  return 0
}
 
proc create_sim_files_dir {} {
  # Summary: Create output directory where simulation files will be generated. Delete previous
  #          files if overwrite requested (-force)
  # Argument Usage:
  # none
  # Return Value:
  # true (0) if success, false (1) otherwise
 
  variable a_xport_sim_vars
 
  if { [string length $a_xport_sim_vars(s_out_dir)] == 0 } {
    send_msg_id Vivado-projutils-036 ERROR "Missing directory value. Please specify the output directory path for the exported files.\n"
    return 1
  }
 
  set dir [file normalize [string map {\\ /} $a_xport_sim_vars(s_out_dir)]]
  if { ! [file exists $dir] } {
    if {[catch {file mkdir $dir} error_msg] } {
      send_msg_id Vivado-projutils-023 ERROR "failed to create the directory ($dir): $error_msg\n"
      return 1
    }
  }
  set a_xport_sim_vars(s_out_dir) $dir
  return 0
}
 
proc export_simulation_for_object { obj_name } {
  # Summary: Open files and write compile order for the target simulator
  # Argument Usage:
  # obj_name - source object
  # Return Value:
  # true (0) if success, false (1) otherwise
 
  variable a_xport_sim_vars
  
  set file [file normalize [file join $a_xport_sim_vars(s_out_dir) $a_xport_sim_vars(s_script_filename)]]
 
  # recommend -force if file exists
  if { [file exists $file] && (!$a_xport_sim_vars(b_overwrite)) } {
    send_msg_id Vivado-projutils-032 ERROR "Simulation file '$file' already exist. Use -force option to overwrite."
    return 1
  }
    
  if { [file exists $file] } {
    if {[catch {file delete -force $file} error_msg] } {
      send_msg_id Vivado-projutils-033 ERROR "failed to delete file ($file): $error_msg\n"
      return 1
    }
  }
 
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id Vivado-projutils-025 ERROR "failed to open file to write ($file)\n"
    return 1
  }
 
  send_msg_id Vivado-projutils-024 INFO \
    "Generating simulation files for the '$a_xport_sim_vars(s_simulator_name)' simulator...\n"
 
  # write header, compiler command/options
  if { [write_driver_script $fh] } {
    return 1
  }
  close $fh
 
  # make filelist executable
  if {$::tcl_platform(platform) == "unix"} {
    if {[catch {exec chmod a+x $file} error_msg] } {
      send_msg_id Vivado-projutils-040 WARNING "failed to change file permissions to executable ($file): $error_msg\n"
    }
  }
 
  return 0
}
 
proc write_driver_script { fh } {
  # Summary: Write driver script for the target simulator
  # Argument Usage:
  # fh   - file handle
  # Return Value:
  # true (0) if success, false (1) otherwise
 
  variable a_xport_sim_vars
  variable l_compile_order_files
 
  write_script_header $fh
 
  # setup source dir var
  puts $fh "# Directory path for design sources and include directories (if any) wrt this path"
  if { $a_xport_sim_vars(b_absolute_path) } {
    puts $fh "reference_dir=\"$a_xport_sim_vars(s_out_dir)\""
  } else {
    puts $fh "reference_dir=\".\""
  }
  puts $fh ""

  print_usage $fh
  print_design_lib_mappings $fh
  create_do_file
  print_copy_glbl_file $fh
  print_reset_run $fh

  puts $fh "# STEP: setup"
  puts $fh "setup()\n\{"

  print_proc_case_stmt $fh

  puts $fh "  # Add any setup/initialization commands here:-\n"
  puts $fh "  # <user specific commands>\n"
  puts $fh "\}\n"

  puts $fh "# RUN_STEP: <compile>"
  puts $fh "compile()\n\{"
  if {[llength $l_compile_order_files] == 0} {
    puts $fh "# None (no sources present)"
    puts $fh "\}"
    return 0
  }
 
  switch -regexp -- $a_xport_sim_vars(s_simulator) {
    "ies" { 
      set tool "ncvhdl"
      set arg_list [list "-V93" "-RELAX" "-logfile" "${tool}.log" "-append_log"]
      if { !$a_xport_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64bit"]
      }
      puts $fh "  ${tool}_opts=\"[join $arg_list " "]\""

      set tool "ncvlog"
      set arg_list [list "-messages" "-logfile" "${tool}.log" "-append_log"]
      if { !$a_xport_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64bit"]
      }
      puts $fh "  ${tool}_opts=\"[join $arg_list " "]\"\n"
    }
    "vcs_mx"   {
      set tool "vhdlan"
      set arg_list [list "-l" "$tool.log"]
      if { !$a_xport_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-full64"]
      }
      puts $fh "  ${tool}_opts=\"[join $arg_list " "]\""

      set tool "vlogan"
      set arg_list [list "-l" "$tool.log"]
      if { !$a_xport_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-full64"]
      }
      puts $fh "  ${tool}_opts=\"[join $arg_list " "]\"\n"
    }
    default {
      send_msg_id Vivado-projutils-056 ERROR "Invalid simulator ($a_xport_sim_vars(s_simulator))\n"
      close $fh
      return 1
    }
  }

  wr_compile_order $fh
 
  # add glbl
  if { [contains_verilog] } {
    set s64bit ""
    set default_lib [get_property default_lib [current_project]]
    switch -regexp -- $a_xport_sim_vars(s_simulator) {
      "ies"      { 
        if { !$a_xport_sim_vars(b_32bit) } { set s64bit "-64bit" }
        set file_str "-work $default_lib \"glbl.v\""
        puts $fh "\n  # Compile glbl module\n  ncvlog \$ncvlog_opts $file_str"
      }
      "vcs_mx"   {
        if { !$a_xport_sim_vars(b_32bit) } { set s64bit "-full64" }
        set file_str "\"glbl.v\""
        set work_lib_sw {}
        if { {work} != $default_lib } {
          set work_lib_sw "-work $default_lib"
        }
        puts $fh "\n  # Compile glbl module\n  vlogan \$vlogan_opts +v2k $work_lib_sw $file_str"
      }
      default {
        send_msg_id Vivado-projutils-031 ERROR "Invalid simulator ($a_xport_sim_vars(s_simulator))\n"
        close $fh
        return 1
      }
    }
  }

  puts $fh "\}"
 
  puts $fh ""
  write_elaboration_cmds $fh
 
  puts $fh ""
  write_simulation_cmds $fh

  puts $fh ""
  puts $fh "# Main steps"
  puts $fh "run()\n\{\n  setup \$1 \$2\n  compile\n  elaborate\n  simulate\n\}\n"

  print_main_function $fh

  return 0
}

proc remove_duplicate_files { compile_order_files } {
  # Summary: Removes exact duplicate files (same file path)
  # Argument Usage:
  # files - compile order files
  # Return Value:
  # Unique files

  set file_list [list]
  set compile_order [list]
  foreach file $compile_order_files {
    set normalized_file_path [file normalize [string map {\\ /} $file]]
    if { [lsearch -exact $file_list $normalized_file_path] == -1 } {
      lappend file_list $normalized_file_path
      lappend compile_order $file
    }
  }
  return $compile_order
}
 
proc wr_compile_order { fh } {
  # Summary: Write compile order for the target simulator
  # Argument Usage:
  # fh - file handle
  # Return Value:
  # none
 
  variable a_xport_sim_vars
  variable l_compile_order_files
 
  foreach file $l_compile_order_files {
    set cmd_str [list]
    set file_type [get_property file_type [lindex [get_files -quiet -all $file] 0]]
    if { [lsearch -exact [list_property [lindex [get_files -quiet -all $file] 0]] {LIBRARY}] == -1} {
      continue;
    }
    set associated_library [get_property library [lindex [get_files -quiet -all $file] 0]]
    if { $a_xport_sim_vars(b_absolute_path) } {
      set file "[resolve_file_path $file]"
    } else {
      set file "\$reference_dir/[get_relative_file_path $file $a_xport_sim_vars(s_out_dir)]"
    }

    set compiler [get_compiler_name $file_type]
    if { [string length $compiler] > 0 } {
      set arg_list [list $compiler]
      append_compiler_options $compiler $file_type arg_list
      switch -regexp -- $a_xport_sim_vars(s_simulator) {
        "ies" { 
          set arg_list [linsert $arg_list end "-work" "$associated_library" "\"$file\""]
        }
        "vcs_mx" {
          if { [string equal -nocase $associated_library "work"] } {
            set arg_list [linsert $arg_list end "\"$file\""]
          } else {
            set arg_list [linsert $arg_list end "-work" "$associated_library" "\"$file\""]
          }
        }
      }
      set file_str [join $arg_list " "]
      puts $fh "  $file_str"
    }
  }
}

proc write_script_header { fh } {
  # Summary: Driver script header info
  # Argument Usage:
  # fh - file descriptor
  # Return Value:
  # none
 
  variable a_xport_sim_vars
 
  set curr_time   [clock format [clock seconds]]
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
 
  puts $fh "#!/bin/sh -f"
  puts $fh "# $product (TM) $version_id\n#"
  puts $fh "# Filename    : $a_xport_sim_vars(s_script_filename)"
  puts $fh "# Description : Simulation script for compiling, elaborating and verifying the project source files in"
  puts $fh "#               '$a_xport_sim_vars(s_simulator_name)' simulator. The script will automatically create the design"
  puts $fh "#               libraries sub-directories in the run directory, add the library logical mappings in the"
  puts $fh "#               simulator setup file, create default 'do' file, copy glbl.v into the run directory for"
  puts $fh "#               verilog sources in the design (if any), execute compilation, elaboration and simulation"
  puts $fh "#               steps.\n#"
  puts $fh "#               By default, the source file and include directory paths will be set relative to the"
  puts $fh "#               'reference_dir' variable unless the -absolute_path is specified in which case the paths"
  puts $fh "#               will be set absolute.\n#"
  puts $fh "# Generated by $product on $curr_time"
  puts $fh "# $copyright \n#"
  puts $fh "# usage: $a_xport_sim_vars(s_script_filename) \[-help\]"
  puts $fh "# usage: $a_xport_sim_vars(s_script_filename) \[-noclean_files\]"
  puts $fh "# usage: $a_xport_sim_vars(s_script_filename) \[-reset_run\]\n#"
  puts $fh "# Prerequisite:- To compile and run simulation, you must compile the Xilinx simulation libraries using the"
  puts $fh "# 'compile_simlib' TCL command. For more information about this command, run 'compile_simlib -help' in the"
  puts $fh "# $product Tcl Shell. Once the libraries have been compiled successfully, specify the -lib_map_path switch"
  puts $fh "# that points to these libraries and rerun export_simulation. For more information about this switch please"
  puts $fh "# type 'export_simulation -help' in the Tcl shell.\n#"
  puts $fh "# Alternatively, if the libraries are already compiled then replace <SPECIFY_COMPILED_LIB_PATH> in this script"
  puts $fh "# with the compiled library directory path.\n#"
  puts $fh "# Additional references - 'Xilinx Vivado Design Suite User Guide:Logic simulation (UG900)'\n#"
  puts $fh "# ********************************************************************************************************\n"
}

proc write_elaboration_cmds { fh } {
  # Summary: Driver script header info
  # Argument Usage:
  # files - compile order files
  # fh - file descriptor
  # Return Value:
  # none
 
  variable a_xport_sim_vars
  variable l_compile_order_files
 
  puts $fh "# RUN_STEP: <elaborate>"
  puts $fh "elaborate()\n\{"
  if {[llength $l_compile_order_files] == 0} {
    puts $fh "# None (no sources present)"
    return
  }

 
  switch -regexp -- $a_xport_sim_vars(s_simulator) {
    "ies" { 
      set tool "ncelab"
      set top_lib [get_top_library]
      set arg_list [list "-relax -access +rwc -messages" "-logfile" "$a_xport_sim_vars(s_sim_top)_elab.log"]
      if { !$a_xport_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64bit"]
      }

      # design contains ax-bfm ip? insert bfm library
      if { [is_axi_bfm_ip] } {
        set simulator_lib [get_simulator_lib_for_bfm "ies"]
        if { {} != $simulator_lib } {
          set arg_list [linsert $arg_list 0 "-loadvpi $simulator_lib:xilinx_register_systf"]
        } else {
          send_msg_id Vivado-projutils-059 ERROR "Failed to locate simulator library from 'XILINX' environment variable."
        }
      }

      puts $fh "  ${tool}_opts=\"[join $arg_list " "]\""

      set arg_list [list]
      foreach lib [get_compile_order_libs] {
        if {[string length $lib] == 0} { continue; }
        lappend arg_list "-libname"
        lappend arg_list "[string tolower $lib]"
      }
      set arg_list [linsert $arg_list end "-libname" "unisims_ver" "-libname" "secureip"]
      puts $fh "  design_libs_elab=\"[join $arg_list " "]\"\n"

      set arg_list [list $tool "\$${tool}_opts"]
      if { [is_fileset $a_xport_sim_vars(sp_tcl_obj)] } {
        set vhdl_generics [list]
        set vhdl_generics [get_property vhdl_generic [get_filesets $a_xport_sim_vars(sp_tcl_obj)]]
        if { [llength $vhdl_generics] > 0 } {
          append_define_generics $vhdl_generics $tool arg_list
        }
      }
      lappend arg_list "${top_lib}.$a_xport_sim_vars(s_sim_top)"
      if { [contains_verilog] } {
        lappend arg_list "${top_lib}.glbl"
      }
      lappend arg_list "\$design_libs_elab"
      set cmd_str [join $arg_list " "]
      puts $fh "  $cmd_str"
    }
    "vcs_mx" {
      set tool "vcs"
      set top_lib [get_top_library]
      set arg_list [list "-debug_pp" "-t" "ps" "-licwait" "-60" "-l" "$a_xport_sim_vars(s_sim_top)_comp.log"]
      if { !$a_xport_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-full64"]
      }

      # design contains ax-bfm ip? insert bfm library
      if { [is_axi_bfm_ip] } {
        set simulator_lib [get_simulator_lib_for_bfm "vcs_mx"]
        if { {} != $simulator_lib } {
          set arg_list [linsert $arg_list 0 "-load $simulator_lib:xilinx_register_systf"]
        } else {
          send_msg_id Vivado-projutils-057 ERROR "Failed to locate simulator library from 'XILINX' environment variable."
        }
      }

      puts $fh "  ${tool}_opts=\"[join $arg_list " "]\"\n"
 
      set arg_list [list "$tool" "\$${tool}_opts" "${top_lib}.$a_xport_sim_vars(s_sim_top)"]
      if { [contains_verilog] } {
        lappend arg_list "${top_lib}.glbl"
      }
      lappend arg_list "-o"
      lappend arg_list "$a_xport_sim_vars(s_sim_top)_simv"
      set cmd_str [join $arg_list " "]
      puts $fh "  $cmd_str"
    }
  }
  puts $fh "\}"
}
 
proc write_simulation_cmds { fh } {
  # Summary: Driver script simulation commands info
  # Argument Usage:
  # files - compile order files
  # fh - file descriptor
  # Return Value:
 
  variable a_xport_sim_vars
  variable l_compile_order_files
 
  puts $fh "# RUN_STEP: <simulate>"
  puts $fh "simulate()\n\{"
  if {[llength $l_compile_order_files] == 0} {
    puts $fh "# None (no sources present)"
    return
  }
 
  set do_filename "$a_xport_sim_vars(s_sim_top).do"
  switch -regexp -- $a_xport_sim_vars(s_simulator) {
    "ies" { 
      set tool "ncsim"
      set top_lib [get_top_library]

      set arg_list [list "-logfile" "$a_xport_sim_vars(s_sim_top)_sim.log"]
      if { !$a_xport_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64bit"]
      }
      puts $fh "  ${tool}_opts=\"[join $arg_list " "]\"\n"

      set arg_list [list "$tool" "\$${tool}_opts" "${top_lib}.$a_xport_sim_vars(s_sim_top)" "-input" "$do_filename"]
      set cmd_str [join $arg_list " "]
      puts $fh "  $cmd_str"
    }
    "vcs_mx" {
      set tool "$a_xport_sim_vars(s_sim_top)_simv"
      set arg_list [list "-ucli" "-licwait" "-60" "-l" "$a_xport_sim_vars(s_sim_top)_sim.log"]
      puts $fh "  ${tool}_opts=\"[join $arg_list " "]\""
      puts $fh ""

      set arg_list [list "./$a_xport_sim_vars(s_sim_top)_simv" "\$${tool}_opts" "-do" "$do_filename"]
      set cmd_str [join $arg_list " "]
      puts $fh "  $cmd_str"
    }
  }
  puts $fh "\}"
}

proc append_define_generics { def_gen_list tool opts_arg } {
  # Summary: Append verilog defines/vhdl generics for the specified tool
  # Argument Usage:
  # def_gen_list - list of defines or generics
  # tool - compiler
  # opts_arg - options list to be appended
  # Return Value:
  # none

  foreach element $def_gen_list {
    set key_val_pair [split $element "="]
    set name [lindex $key_val_pair 0]
    set val  [lindex $key_val_pair 1]
    if { [string length $val] > 0 } {
      switch -regexp -- $tool {
        "ncvlog" { lappend opts_arg "-define"  ; lappend opts_arg "\"$name=$val\""  }
        "vlogan" { lappend opts_arg "+define+" ; lappend opts_arg "\"$name=$val\""  }
        "ies"    { lappend opts_arg "-g"       ; lappend opts_arg "\"$name=>$val\"" }
      }
    }
  }
}

proc get_compiler_name { file_type } {
  # Summary: Return applicable compiler application name based on filetype for the target simulator
  # Argument Usage:
  # file_type - file type
  # Return Value:
  # compiler name if valid filetype, else empty string

  variable a_xport_sim_vars

  set compiler ""

  if { {VHDL} == $file_type } {
    switch -regexp -- $a_xport_sim_vars(s_simulator) {
      "ies"    { set compiler "ncvhdl" }
      "vcs_mx" { set compiler "vhdlan" }
    }
  } elseif { ({Verilog} == $file_type) || ({SystemVerilog} == $file_type) } {
    switch -regexp -- $a_xport_sim_vars(s_simulator) {
      "ies"    { set compiler "ncvlog" }
      "vcs_mx" { set compiler "vlogan" }
    }
  }
  return $compiler
}
 
proc append_compiler_options { tool file_type opts_arg } {
  # Summary: Add switches (options) for the target compiler tool
  # Argument Usage:
  # tool - compiler name
  # file_type - file type
  # opts_arg - options list to be appended
  # Return Value:
  # none

  upvar $opts_arg opts
 
  variable a_xport_sim_vars

  switch $tool {
    "ncvhdl" -
    "vhdlan" {
      lappend opts "\$${tool}_opts"
    }
    "ncvlog" {
      lappend opts "\$${tool}_opts"
      if { [string equal -nocase $file_type "systemverilog"] } {
        lappend opts "-sv"
      }
    }
    "vlogan" {
      lappend opts "\$${tool}_opts"
      if { [string equal -nocase $file_type "verilog"] } {
        lappend opts "+v2k"
      } elseif { [string equal -nocase $file_type "systemverilog"] } {
        lappend opts "-sverilog"
      }
    }
  }

  # append verilog defines, include dirs and include file dirs
  switch $tool {
    "ncvlog" -
    "vlogan" {
      # verilog defines
      if { [is_fileset $a_xport_sim_vars(sp_tcl_obj)] } {
        set verilog_defines [list]
        set verilog_defines [get_property verilog_define [get_filesets $a_xport_sim_vars(sp_tcl_obj)]]
        if { [llength $verilog_defines] > 0 } {
          append_define_generics $verilog_defines $tool opts
        }
      }
 
      # include dirs
      foreach dir [concat [find_verilog_incl_dirs] [find_verilog_incl_file_dirs]] {
        lappend opts "+incdir+\"$dir\""
      }
    }
  }
}
 
proc find_verilog_incl_dirs { } {
  # Summary: Get the verilog include directory paths
  # Argument Usage:
  # none
  # Return Value:
  # Sorted unique list of verilog include directories (if any)

  variable a_xport_sim_vars
 
  set dir_names [list]

  set tcl_obj $a_xport_sim_vars(sp_tcl_obj)
  if { [is_ip $tcl_obj] } {
    set incl_dir_str [find_incl_dirs_from_ip $tcl_obj]
  } else {
    set incl_dir_str [get_property include_dirs [get_filesets $tcl_obj]]
  }

  set incl_dirs [split $incl_dir_str " "]
  foreach vh_dir $incl_dirs {
    set dir [file normalize $vh_dir]
    if { $a_xport_sim_vars(b_absolute_path) } {
      set dir "[resolve_file_path $dir]"
    } else {
      set dir "\$reference_dir/[get_relative_file_path $dir $a_xport_sim_vars(s_out_dir)]"
    }
    lappend dir_names $dir
  }
  return [lsort -unique $dir_names]
}
 
proc find_verilog_incl_file_dirs {} {
  # Summary: Get the verilog include directory paths for files of type "Verilog Header"
  # Argument Usage:
  # none
  # Return Value:
  # Sorted unique list of verilog include directory paths for files of type "Verilog Header"
 
  variable a_xport_sim_vars
 
  set dir_names [list]
 
  set tcl_obj $a_xport_sim_vars(sp_tcl_obj)
  if { [is_ip $tcl_obj] } {
    set vh_files [find_incl_files_from_ip $tcl_obj]
  } else {
    set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"Verilog Header\""
    set vh_files [get_files -quiet -filter $filter]
  }

  foreach vh_file $vh_files {
    set dir [file normalize [file dirname $vh_file]]
    if { $a_xport_sim_vars(b_absolute_path) } {
      set dir "[resolve_file_path $dir]"
    } else {
      set dir "\$reference_dir/[get_relative_file_path $dir $a_xport_sim_vars(s_out_dir)]"
    }
    lappend dir_names $dir
  }
  if {[llength $dir_names] > 0} {
    return [lsort -unique $dir_names]
  }
 
  return $dir_names
}
 
proc find_incl_dirs_from_ip { tcl_obj } {
  # Summary: Get the verilog include directory paths for files of type "Verilog Header" for an IP
  # Argument Usage:
  # tcl_obj - source object type
  # Return Value:
  # List of verilog include directory paths in an IP for files of type "Verilog Header"
 
  variable a_xport_sim_vars 

  set ip_name [file tail $tcl_obj]
  set incl_dirs [list]
  set filter "FILE_TYPE == \"Verilog Header\""
  set vh_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    set dir [file dirname $file]
    if { $a_xport_sim_vars(b_absolute_path) } {
      set dir "[resolve_file_path $dir]"
    } else {
      set dir "\$reference_dir/[get_relative_file_path $dir $a_xport_sim_vars(s_out_dir)]"
    }
    lappend incl_dirs $dir
  }

  return $incl_dirs
}
 
proc find_incl_files_from_ip { tcl_obj } {
  # Summary: Get the verilog include files of type "Verilog Header" for an IP
  # Argument Usage:
  # none
  # Return Value:
  # List of verilog include directory files in an IP for files of type "Verilog Header"
 
  variable a_xport_sim_vars

  set incl_files [list]
  set ip_name [file tail $tcl_obj]
  set filter "FILE_TYPE == \"Verilog Header\""
  set vh_files [get_files -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    if { $a_xport_sim_vars(b_absolute_path) } {
      set file "[resolve_file_path $file]"
    } else {
      set file "\$reference_dir/[get_relative_file_path $file $a_xport_sim_vars(s_out_dir)]"
    }
    lappend incl_files $file
  }

  return $incl_files
}
 
proc export_data_files { data_files } {
  # Summary: Copy IP data files to output directory
  # Argument Usage:
  # data_files - List of data files
  # Return Value:
  # none
 
  variable a_xport_sim_vars

  set export_dir $a_xport_sim_vars(s_out_dir)
  
  # export now
  foreach file $data_files {
    if {[catch {file copy -force $file $export_dir} error_msg] } {
      send_msg_id Vivado-projutils-027 WARNING "failed to copy file '$file' to '$export_dir' : $error_msg\n"
    } else {
      send_msg_id Vivado-projutils-028 INFO "exported '$file'\n"
    }
  }
}
 
proc export_fs_data_files { } {
  # Summary: Copy fileset IP data files to output directory
  # Argument Usage:
  # none
  # Return Value:
  # none
 
  variable a_xport_sim_vars
  variable s_data_files_filter
 
  # export all IP data files 
  set ip_filter "FILE_TYPE == \"IP\""
  set ips [get_files -all -quiet -filter $ip_filter]
  foreach ip $ips {
    set ip_name [file tail $ip]
    set data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_data_files_filter]
    export_data_files $data_files
  }
 
  # export fileset data files
  foreach fs_obj [list [current_fileset] [current_fileset -simset]] {
    set fs_data_files [get_files -all -quiet -of_objects [get_filesets -quiet $fs_obj] -filter $s_data_files_filter]
    export_data_files $fs_data_files
  }
}
 
proc get_compile_order_libs { } {
  # Summary: Find unique list of design libraries
  # Argument Usage:
  # files: list of design files
  # Return Value:
  # Unique list of libraries (if any)
 
  variable a_xport_sim_vars
  variable l_compile_order_files
 
  set libs [list]
  foreach file $l_compile_order_files {
    if { [lsearch -exact [list_property [lindex [get_files -all $file] 0]] {LIBRARY}] == -1} {
      continue;
    }
    foreach f [get_files -all $file] {
      set library [get_property library $f]
      if { [lsearch -exact $libs $library] == -1 } {
        lappend libs $library
      }
    }
  }
  return $libs
}

proc get_top_library { } {
  # Summary: Find the "top" library from the compile order
  # Argument Usage:
  # none
  # Return Value:
  # Top library name
 
  variable a_xport_sim_vars
  variable l_compile_order_files

  set tcl_obj $a_xport_sim_vars(sp_tcl_obj)
  set top_lib ""
  if { [is_fileset $tcl_obj] } {
    set top_lib [get_property top_lib [get_filesets $tcl_obj]]
  }

  if { [string length $top_lib] == 0 } {
    if { [llength $l_compile_order_files] > 0 } {
      set top_lib [get_property library [lindex [get_files -all [lindex $l_compile_order_files end]] 0]]
    }
  }

  if { [string length $top_lib] == 0 } {
    set top_lib [get_property default_lib [current_project]]
  }

  return $top_lib
}
 
proc contains_verilog {} {
  # Summary: Check if the input file type is of type verilog or verilog header
  # Argument Usage:
  # files: list of files
  # Return Value:
  # True (1) if of type verilog, False (0) otherwise
 
  variable l_compile_order_files

  foreach file $l_compile_order_files {
    set file_type [get_property file_type [get_files -quiet -all $file]]
    if {[regexp -nocase {^verilog} $file_type] ||
        [regexp -nocase {^systemverilog} $file_type]} {
      return 1
    }
  }
  return 0
}

proc verify_ip_status { tcl_obj } {
  # Summary: Report critical warnings on non generated and stale ip's 
  # Argument Usage:
  # None
  # Return Value:
  # None

  variable a_xport_sim_vars

  set regen_ip [dict create] 
  if { [is_ip $tcl_obj] } {
    set ip [file root [file tail $tcl_obj]]
    # is user-disabled? or auto_disabled? skip
    if { ({0} == [get_property is_enabled [get_files -all ${ip}.xci]]) ||
         ({1} == [get_property is_auto_disabled [get_files -all ${ip}.xci]]) } {
      return
    }
    dict set regen_ip $ip d_targets [get_property delivered_targets [get_ips $ip]]
    dict set regen_ip $ip generated [get_property is_ip_generated [get_ips $ip]]
    dict set regen_ip $ip stale [get_property stale_targets [get_ips $ip]]
  } else {
    foreach ip [get_ips] {
      # is user-disabled? or auto_disabled? continue
      if { ({0} == [get_property is_enabled [get_files -all ${ip}.xci]]) ||
           ({1} == [get_property is_auto_disabled [get_files -all ${ip}.xci]]) } {
        continue
      }
      dict set regen_ip $ip d_targets [get_property delivered_targets [get_ips $ip]]
      dict set regen_ip $ip generated [get_property is_ip_generated $ip]
      dict set regen_ip $ip stale [get_property stale_targets $ip]
    }
  } 

  set not_generated [list]
  set stale_ips [list]
  dict for {ip regen} $regen_ip {
    dic with regen {
      if { {} == $d_targets } {
        continue
      }
      if { {0} == $generated } {
        lappend not_generated $ip
      } else {
        if { [llength $stale] > 0 } {
          lappend stale_ips $ip
        }
      }
    }
  }

  if { ([llength $not_generated] > 0 ) || ([llength $stale_ips] > 0) } {
    set txt [list]
    foreach ip $not_generated { lappend txt "Status - (Not Generated) IP NAME = $ip" }
    foreach ip $stale_ips     { lappend txt "Status - (Out of Date)   IP NAME = $ip" }
    set msg_txt [join $txt "\n"]
    send_msg_id Vivado-projutils-001 "CRITICAL WARNING" \
       "The following IPs have not generated output products yet or have subsequently been updated, making the current\n\
       output products out-of-date. It is strongly recommended that these IPs be re-generated and then this script run again to get a complete output.\n\
       $msg_txt"
  }
}
 
proc get_relative_file_path { file_path_to_convert relative_to } {
  # Summary: Get the relative path wrt to path specified
  # Argument Usage:
  # file_path_to_convert: input file to make relative to specfied path
  # Return Value:
  # Relative path wrt the path specified
 
  variable a_xport_sim_vars
 
  # make sure we are dealing with a valid relative_to directory. If regular file or is not a directory, get directory
  if { [file isfile $relative_to] || ![file isdirectory $relative_to] } {
    set relative_to [file dirname $relative_to]
  }
 
  set cwd [file normalize [pwd]]
 
  if { [file pathtype $file_path_to_convert] eq "relative" } {
    # is relative_to path same as cwd?, just return this path, no further processing required
    if { [string equal $relative_to $cwd] } {
      return $file_path_to_convert
    }
    # the specified path is "relative" but something else, so make it absolute wrt current working dir
    set file_path_to_convert [file join $cwd $file_path_to_convert]
  }
 
  # is relative_to "relative"? convert to absolute as well wrt cwd
  if { [file pathtype $relative_to] eq "relative" } {
    set relative_to [file join $cwd $relative_to]
  }
 
  # normalize 
  set file_path_to_convert [file normalize $file_path_to_convert]
  set relative_to          [file normalize $relative_to]
 
  set file_path $file_path_to_convert
  set file_comps        [file split $file_path]
  set relative_to_comps [file split $relative_to]
 
  set found_match false
  set index 0
 
  # compare each dir element of file_to_convert and relative_to, set the flag and
  # get the final index till these sub-dirs matched
  while { [lindex $file_comps $index] == [lindex $relative_to_comps $index] } {
    if { !$found_match } { set found_match true }
    incr index
  }
 
  # any common dirs found? convert path to relative
  if { $found_match } {
    set parent_dir_path ""
    set rel_index $index
    # keep traversing the relative_to dirs and build "../" levels
    while { [lindex $relative_to_comps $rel_index] != "" } {
      set parent_dir_path "../$parent_dir_path"
      incr rel_index
    }
 
    # 
    # at this point we have parent_dir_path setup with exact number of sub-dirs to go up
    #
 
    # now build up part of path which is relative to matched part
    set rel_path ""
    set rel_index $index
 
    while { [lindex $file_comps $rel_index] != "" } {
      set comps [lindex $file_comps $rel_index]
      if { $rel_path == "" } {
        # first dir
        set rel_path $comps
      } else {
        # append remaining dirs
        set rel_path "${rel_path}/$comps"
      }
      incr rel_index
    }
 
    # prepend parent dirs, this is the complete resolved path now
    set resolved_path "${parent_dir_path}${rel_path}"
 
    return $resolved_path
  }
 
  # no common dirs found, just return the normalized path 
  return $file_path
}

proc resolve_file_path { file_dir_path_to_convert } {
  # Summary: Make file path relative to reference_dir if relative component found
  # Argument Usage:
  # file_dir_path_to_convert: input file to make relative to specfied path
  # Return Value:
  # Relative path wrt the path specified

  variable a_xport_sim_vars

  set ref_dir [file normalize [string map {\\ /} $a_xport_sim_vars(s_out_dir)]]
  set ref_comps [lrange [split $ref_dir "/"] 1 end]
  set file_comps [lrange [split [file normalize [string map {\\ /} $file_dir_path_to_convert]] "/"] 1 end]

  set index 1
  while { [lindex $ref_comps $index] == [lindex $file_comps $index] } {
    incr index
  }
 
  # is file path within reference dir? return relative path
  if { $index == [llength $ref_comps] } {
    return [get_relative_file_path $file_dir_path_to_convert $ref_dir]
  }

  # return absolute 
  return $file_dir_path_to_convert
}

proc print_usage { fh } {
  # Summary: Print usage helper in script file
  # Argument Usage:
  # None
  # Return Value:
  # None 

  variable a_xport_sim_vars

  puts $fh "# Script usage"
  puts $fh "usage()"
  puts $fh "\{"
  puts $fh "  msg=\"Usage: $a_xport_sim_vars(s_script_filename) \[-help\]\\n\\"
  puts $fh "Usage: $a_xport_sim_vars(s_script_filename) \[-noclean_files\]\\n\\"
  puts $fh "Usage: $a_xport_sim_vars(s_script_filename) \[-reset_run\]\\n\\n\\\n\\"
  puts $fh "\[-help\] -- Print help\\n\\n\\"
  puts $fh "\[-noclean_files\] -- Do not remove simulator generated files from the previous run\\n\\n\\"
  puts $fh "\[-reset_run\] -- Recreate simulator setup files and library mappings for a clean run. The generated files\\n\\"
  puts $fh "\\t\\tfrom the previous run will be removed automatically.\\n\""
  puts $fh "  echo -e \$msg"
  puts $fh "  exit 1"
  puts $fh "\}"
  puts $fh ""
}

proc print_design_lib_mappings { fh } {
  # Summary: Print design library mappings helper in script file
  # Argument Usage:
  # File handle
  # Return Value:
  # None 

  variable a_xport_sim_vars

  puts $fh "# Create design library directory paths and define design library mappings in cds.lib"
  puts $fh "create_lib_mappings()"
  puts $fh "\{"

  set simulator $a_xport_sim_vars(s_simulator)
  set libs [list]
  foreach lib [get_compile_order_libs] {
    if {[string length $lib] == 0} { continue; }
    if { ({work} == $lib) && ({vcs_mx} == $simulator) } { continue; }
    lappend libs [string tolower $lib]
  }
  puts $fh "  libs=([join $libs " "])"
  switch -regexp -- $simulator {
    "ies"    { puts $fh "  file=\"cds.lib\"" }
    "vcs_mx" { puts $fh "  file=\"synopsys_sim.setup\"" }
  }
  puts $fh "  dir=\"$simulator\"\n"
  puts $fh "  if \[\[ -e \$file \]\]; then"
  puts $fh "    rm -f \$file"
  puts $fh "  fi\n"
  puts $fh "  if \[\[ -e \$dir \]\]; then"
  puts $fh "    rm -rf \$dir"
  puts $fh "  fi"
  puts $fh ""
  puts $fh "  touch \$file"

  # is -lib_map_path specified and point to valid location?
  if { [string length $a_xport_sim_vars(s_lib_map_path)] > 0 } {
    set a_xport_sim_vars(s_lib_map_path) [file normalize $a_xport_sim_vars(s_lib_map_path)]
    set compiled_lib_dir $a_xport_sim_vars(s_lib_map_path)
    if { ![file exists $compiled_lib_dir] } {
      send_msg_id Vivado-projutils-052 ERROR \
        "Compiled simulation library directory path does not exist:$compiled_lib_dir\n"
      puts $fh "  lib_map_path=\"<SPECIFY_COMPILED_LIB_PATH>\""
    } else {
      puts $fh "  lib_map_path=\"$compiled_lib_dir\""
    }
  } else {
    send_msg_id Vivado-projutils-055 WARNING \
       "The pre-compiled simulation library directory path was not specified (-lib_map_path), which may\n\
       cause simulation errors when running this script. Please refer to the generated script header section for more details."
    puts $fh "  lib_map_path=\"<SPECIFY_COMPILED_LIB_PATH>\""
  }

  switch -regexp -- $simulator {
    "ies"    {
      set file "cds.lib"
      puts $fh "  incl_ref=\"INCLUDE \$lib_map_path/$file\""
      puts $fh "  echo \$incl_ref >> \$file"
    }
    "vcs_mx" {
      set file "synopsys_sim.setup"
      puts $fh "  incl_ref=\"OTHERS=\$lib_map_path/$file\""
      puts $fh "  echo \$incl_ref >> \$file"
    }
  }

  puts $fh ""
  puts $fh "  for (( i=0; i<\$\{#libs\[*\]\}; i++ )); do"
  puts $fh "    lib=\"\$\{libs\[i\]\}\""
  puts $fh "    lib_dir=\"\$dir/\$lib\""
  puts $fh "    if \[\[ ! -e \$lib_dir \]\]; then"
  puts $fh "      mkdir -p \$lib_dir"

  switch -regexp -- $simulator {
    "ies"    { puts $fh "      mapping=\"DEFINE \$lib \$dir/\$lib\"" }
    "vcs_mx" { puts $fh "      mapping=\"\$lib : \$dir/\$lib\"" }
  }

  puts $fh "      echo \$mapping >> \$file"
  puts $fh "    fi"
  puts $fh "  done"
  puts $fh "\}"
  puts $fh ""
}

proc create_do_file {} {
  # Summary: Create default do file
  # Argument Usage:
  # none
  # Return Value:
  # None 

  variable a_xport_sim_vars

  set do_filename "$a_xport_sim_vars(s_sim_top).do"
  set do_file [file join $a_xport_sim_vars(s_out_dir) $do_filename]
  set fh_do 0
  if {[catch {open $do_file w} fh_do]} {
    send_msg_id Vivado-projutils-043 ERROR "failed to open file to write ($do_file)\n"
  } else {
    puts $fh_do "run"
    switch -regexp -- $a_xport_sim_vars(s_simulator) {
      "ies"    { puts $fh_do "exit" }
      "vcs_mx" { puts $fh_do "quit" }
    }
  }
  close $fh_do
}

proc print_copy_glbl_file { fh } {
  # Summary: Print copy glbl.v file helper in script file
  # Argument Usage:
  # File handle
  # Return Value:
  # None 

  set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
  set glbl_file [file normalize [file join $data_dir "verilog/src/glbl.v"]]

  puts $fh "# Copy glbl.v file into run directory"
  puts $fh "copy_glbl_file()"
  puts $fh "\{"
  puts $fh "  glbl_file=\"glbl.v\""
  puts $fh "  src_file=\"$glbl_file\""
  puts $fh "  if \[\[ ! -e \$glbl_file \]\]; then"
  puts $fh "    cp \$src_file ."
  puts $fh "  fi"
  puts $fh "\}"
  puts $fh ""
}

proc print_reset_run { fh } {
  # Summary: Print reset_run helper in script file
  # Argument Usage:
  # File handle
  # Return Value:
  # None 

  variable a_xport_sim_vars

  puts $fh "# Remove generated data from the previous run and re-create setup files/library mappings"
  puts $fh "reset_run()"
  puts $fh "\{"
  set top $a_xport_sim_vars(s_sim_top)
  switch -regexp -- $a_xport_sim_vars(s_simulator) {
    "ies" { 
      set file_list [list "ncsim.key" "ncvlog.log" "ncvhdl.log" "${top}_elab.log" "${top}_sim.log"]
      set files [join $file_list " "]
      puts $fh "  files_to_remove=($files)"
    }
    "vcs_mx" {
      set file_list [list "64" "ucli.key" "AN.DB" "csrc" "${top}_simv" "${top}_simv.daidir" \
                          "vlogan.log" "vhdlan.log" "${top}_comp.log" "${top}_elab.log" "${top}_sim.log" \
                          ".vlogansetup.env" ".vlogansetup.args" ".vcs_lib_lock" "scirocco_command.log"]
      set files [join $file_list " "]
      puts $fh "  files_to_remove=($files)"
    }
  }
  puts $fh "  for (( i=0; i<\$\{#files_to_remove\[*\]\}; i++ )); do"
  puts $fh "    file=\"\$\{files_to_remove\[i\]\}\""
  puts $fh "    if \[\[ -e \$file \]\]; then"
  puts $fh "      rm -rf \$file"
  puts $fh "    fi"
  puts $fh "  done"
  puts $fh "\}"
  puts $fh ""
}

proc print_proc_case_stmt { fh } {
  # Summary: Print reset_run helper in script file
  # Argument Usage:
  # File handle
  # Return Value:
  # None 
 
  variable a_xport_sim_vars

  puts $fh "  case \$1 in"
  puts $fh "    \"-reset_run\" )"
  puts $fh "      reset_run"
  puts $fh "      echo -e \"INFO: Simulation run files deleted.\\n\""
  puts $fh "      exit 0"
  puts $fh "    ;;"
  puts $fh "    \"-noclean_files\" )"
  puts $fh "      # do not remove previous data"
  puts $fh "    ;;"
  puts $fh "    * )"
  puts $fh "     create_lib_mappings"
  switch -regexp -- $a_xport_sim_vars(s_simulator) {
    "ies" { puts $fh "     touch hdl.var" }
  }
  if { [contains_verilog] } { puts $fh "     copy_glbl_file" }
  puts $fh "  esac"
  puts $fh ""
}

proc print_main_function { fh } {
  # Summary: Print main args helper in script file
  # Argument Usage:
  # File handle
  # Return Value:
  # None 

  variable a_xport_sim_vars

  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
 
  puts $fh "# Script info"
  puts $fh "echo -e \"$a_xport_sim_vars(s_script_filename) - Script generated by export_simulation ($version-id)\\n\"\n"
  puts $fh "# Check command line args"
  puts $fh "if \[\[ \$# > 1 \]\]; then"
  puts $fh "  echo -e \"ERROR: invalid number of arguments specified\\n\""
  puts $fh "  usage"
  puts $fh "fi\n"
  puts $fh "if \[\[ (\$# == 1 ) && (\$1 != \"-noclean_files\" && \$1 != \"-reset_run\" && \$1 != \"-help\" && \$1 != \"-h\") \]\]; then"
  puts $fh "  echo -e \"ERROR: unknown option specified '\$1' (type \"$a_xport_sim_vars(s_script_filename) -help\" for for more info)\""
  puts $fh "  exit 1"
  puts $fh "fi"
  puts $fh ""
  puts $fh "if \[\[ (\$1 == \"-help\" || \$1 == \"-h\") \]\]; then"
  puts $fh "  usage"
  puts $fh "fi\n"
  puts $fh "# Launch script"
  puts $fh "run \$1"
}

proc is_axi_bfm_ip {} {
  # Summary: Finds VLNV property value for the IP and checks to see if the IP is AXI_BFM
  # Argument Usage:
  # Return Value:
  # true (1) if specified IP is axi_bfm, false (0) otherwise

  foreach ip [get_ips] {
    set ip_def [lindex [split [get_property "IPDEF" [get_ips $ip]] {:}] 2]
    set value [get_property "VLNV" [get_ipdefs -regexp .*${ip_def}.*]]
    if { [regexp -nocase {axi_bfm} $value] } {
      return 1
    }
  }
  return 0
}

proc get_platform_name {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set platform {}
  set os $::tcl_platform(platform)
  if { {windows}   == $os } { set platform "win32" }
  if { {windows64} == $os } { set platform "win64" }
  if { {unix} == $os } {
    if { {x86_64} == $::tcl_platform(machine) } {
      set platform "lin64"
    } else {
      set platform "lin32"
    }
  }
  return $platform
}

proc get_simulator_lib_for_bfm { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set simulator_lib {}
  set xil           $::env(XILINX)
  set path_sep      {;}
  set lib_extn      {.dll}
  set platform      [get_platform_name]

  if {$::tcl_platform(platform) == "unix"} { set path_sep {:} }
  if {$::tcl_platform(platform) == "unix"} { set lib_extn {.so} }

  set lib_name "libxil_ncsim"
  if { {vcs_mx} == $simulator } {
    set lib_name "libxil_vcs"
  }
  set lib_name $lib_name$lib_extn
  if { {} != $xil } {
    set lib_path {}
    foreach path [split $xil $path_sep] {
      set file [file normalize [file join $path "lib" $platform $lib_name]]
      if { [file exists $file] } {
        set simulator_lib $file
        break
      }
    }
  } else {
    send_msg_id Vivado-projutils-058 ERROR "Environment variable 'XILINX' is not set!"
  }
  return $simulator_lib
}

proc is_embedded_flow {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable s_embedded_files_filter
  set embedded_files [get_files -all -quiet -filter $s_embedded_files_filter]
  if { [llength $embedded_files] > 0 } {
    return 1
  }
  return 0
}

}
