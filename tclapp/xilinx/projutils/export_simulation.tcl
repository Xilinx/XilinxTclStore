####################################################################################
#
# export_simulation.tcl
#
# Script created on 07/12/2013 by Raj Klair (Xilinx, Inc.)
#
####################################################################################
package require Vivado 1.2014.1
package require struct::matrix

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
  # [-single_step]: Generate script to launch all steps in one step
  # [-ip_netlist <arg> = verilog]: Select the IP netlist for the compile order (value=verilog|vhdl)
  # [-export_source_files]: Copy design files to output directory
  # [-32bit]: Perform 32bit compilation
  # [-force]: Overwrite previous files
  # -directory <arg>: Directory where the simulation script will be exported
  # -simulator <arg>: Simulator for which the simulation script will be created (value=xsim|modelsim|questa|ies|vcs)

  # Return Value:
  # None

  # Categories: simulation, xilinxtclstore

  variable a_sim_vars
  xps_init_vars
  set options [split $args " "]

  if {[lsearch $options {-simulator}] == -1} {
    send_msg_id XPS-Tcl-001 ERROR "Missing option '-simulator', please type 'export_simulation -help' for usage info.\n"
    return
  }

  if {[lsearch $options {-directory}] == -1} {
    send_msg_id XPS-Tcl-002 ERROR "Missing option '-directory', please type 'export_simulation -help' for usage info.\n"
    return
  }

  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-of_objects"               { incr i;set a_sim_vars(s_comp_file) [lindex $args $i] }
      "-32bit"                    { set a_sim_vars(b_32bit) 1 }
      "-absolute_path"            { set a_sim_vars(b_absolute_path) 1 }
      "-single_step"              { set a_sim_vars(b_single_step) 1 }
      "-ip_netlist"               { incr i;set a_sim_vars(s_ip_netlist) [string tolower [lindex $args $i]];set a_sim_vars(b_ip_netlist) 1 }
      "-export_source_files"      { set a_sim_vars(b_xport_src_files) 1 }
      "-lib_map_path"             { incr i;set a_sim_vars(s_lib_map_path) [lindex $args $i] }
      "-script_name"              { incr i;set a_sim_vars(s_script_filename) [lindex $args $i] }
      "-force"                    { set a_sim_vars(b_overwrite) 1 }
      "-simulator"                { incr i;set a_sim_vars(s_simulator) [string tolower [lindex $args $i]] }
      "-directory"                { incr i;set a_sim_vars(s_launch_dir) [lindex $args $i] }
      default {
        if { [regexp {^-} $option] } {
          send_msg_id XPS-Tcl-003 ERROR "Unknown option '$option', please type 'export_simulation -help' for usage info.\n"
          return
        }
      }
    }
  }

  if { {vcs_mx} == $a_sim_vars(s_simulator) } {
    set $a_sim_vars(s_simulator) "vcs"
  }

  if { [xps_invalid_options $options] } {
    return
  }

  if { [xps_create_rundir] } {
    return
  }

  xps_set_simulator_name
  xps_set_target_obj
  xps_gen_mem_files
  xps_update_compile_order
  xps_get_compile_order_files
  xps_process_cmd_str
  if { [xps_invalid_flow_options $options] } {
    return
  }

  if { [xps_write_sim_script] } {
    return
  }

  if { [xps_write_filelist] } {
    return
  }

  return
}
}

namespace eval ::tclapp::xilinx::projutils {
proc xps_init_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set a_sim_vars(s_simulator)         ""
  set a_sim_vars(s_simulator_name)    ""
  set a_sim_vars(s_lib_map_path)      ""
  set a_sim_vars(s_script_filename)   ""
  set a_sim_vars(s_script_extn)       "sh"
  set a_sim_vars(s_launch_dir)        ""
  set a_sim_vars(s_srcs_dir)          ""
  set a_sim_vars(s_incl_dir)          ""
  set a_sim_vars(s_ip_netlist)        "verilog"
  set a_sim_vars(b_ip_netlist)        0
  set a_sim_vars(b_32bit)             0
  set a_sim_vars(s_comp_file)         {}
  set a_sim_vars(b_absolute_path)     0             
  set a_sim_vars(b_single_step)       0             
  set a_sim_vars(b_xport_src_files)   0             
  set a_sim_vars(b_overwrite)         0
  set a_sim_vars(fs_obj)              [current_fileset -simset]
  set a_sim_vars(sp_tcl_obj)          ""
  set a_sim_vars(s_top)               ""
  set a_sim_vars(b_is_managed)        [get_property managed_ip [current_project]]
  set a_sim_vars(s_install_path)      {}
  set a_sim_vars(b_scripts_only)      0
  set a_sim_vars(global_files_value)  {}
  set a_sim_vars(default_lib)         [get_property default_lib [current_project]]
 
  set a_sim_vars(do_filename)         "simulate.do"

  variable l_compile_order_files      [list]
  variable l_design_files             [list]
  
  variable l_valid_simulator_types    [list]
  set l_valid_simulator_types         [list xsim modelsim questa ies vcs]

  variable l_valid_ip_netlist_types   [list]
  set l_valid_ip_netlist_types        [list verilog vhdl]
  
  variable l_valid_ip_extns           [list]
  set l_valid_ip_extns                [list ".xci" ".bd" ".slx"]
  
  variable s_data_files_filter
  set s_data_files_filter             "FILE_TYPE == \"Data Files\" || FILE_TYPE == \"Memory Initialization Files\" || FILE_TYPE == \"Coefficient Files\""
  
  variable s_embedded_files_filter
  set s_embedded_files_filter         "FILE_TYPE == \"BMM\" || FILE_TYPE == \"ElF\""

  variable s_non_hdl_data_files_filter
  set s_non_hdl_data_files_filter \
               "FILE_TYPE != \"Verilog\"                      && \
                FILE_TYPE != \"Verilog Header\"               && \
                FILE_TYPE != \"Verilog Template\"             && \
                FILE_TYPE != \"VHDL\"                         && \
                FILE_TYPE != \"VHDL 2008\"                    && \
                FILE_TYPE != \"VHDL Template\"                && \
                FILE_TYPE != \"EDIF\"                         && \
                FILE_TYPE != \"NGC\"                          && \
                FILE_TYPE != \"IP\"                           && \
                FILE_TYPE != \"XCF\"                          && \
                FILE_TYPE != \"NCF\"                          && \
                FILE_TYPE != \"UCF\"                          && \
                FILE_TYPE != \"XDC\"                          && \
                FILE_TYPE != \"NGO\"                          && \
                FILE_TYPE != \"Waveform Configuration File\"  && \
                FILE_TYPE != \"BMM\"                          && \
                FILE_TYPE != \"ELF\""
}
}

namespace eval ::tclapp::xilinx::projutils {
proc xps_invalid_options { options } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  variable l_valid_simulator_types
  variable l_valid_ip_netlist_types

  if { [lsearch -exact $l_valid_simulator_types $a_sim_vars(s_simulator)] == -1 } {
    send_msg_id XPS-Tcl-004 ERROR "Invalid simulator type specified. Please type 'export_simulation -help' for usage info.\n"
    return 1
  }

  if { $a_sim_vars(b_ip_netlist) } {
    if { [lsearch -exact $l_valid_ip_netlist_types $a_sim_vars(s_ip_netlist)] == -1 } {
      send_msg_id XPS-Tcl-005 ERROR "Invalid ip netlist type specified. Please type 'export_simulation -help' for usage info.\n"
      return 1
    }
  }

  if { ([lsearch $options {-of_objects}] != -1) && ([llength $a_sim_vars(sp_tcl_obj)] == 0) } {
    send_msg_id XPS-Tcl-006 ERROR "Invalid object specified. The object does not exist.\n"
    return 1
  }

  switch $a_sim_vars(s_simulator) {
    "questa" -
    "vcs" {
      if { $a_sim_vars(b_ip_netlist) } {
        if { ($a_sim_vars(b_single_step)) && ({vhdl} == $a_sim_vars(s_ip_netlist)) } {
          send_msg_id XPS-Tcl-007 ERROR "Single step flow is not applicable for IP's with VHDL netlist. Please select Verilog netlist for this simulator.\n"
          return 1
        }
      }
    }
  }

  return 0
}

proc xps_invalid_flow_options { options } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  switch $a_sim_vars(s_simulator) {
    "questa" -
    "vcs" {
      if { ($a_sim_vars(b_single_step)) && ([xps_contains_vhdl]) } {
        [catch {send_msg_id XPS-Tcl-008 ERROR "Single step flow is not applicable for designs with VHDL netlist.\n"}]
        return 1
      }
    }
  }

  return 0
}

proc xps_create_rundir {} {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:
 
  variable a_sim_vars
 
  if { [string length $a_sim_vars(s_launch_dir)] == 0 } {
    send_msg_id XPS-Tcl-009 ERROR "Missing directory value. Please specify the output directory path for the exported files.\n"
    return 1
  }
 
  set dir [file normalize [string map {\\ /} $a_sim_vars(s_launch_dir)]]
  if { [file exists $dir] } {
    foreach file_path [glob -nocomplain -directory $dir *] {
      if {[catch {file delete -force $file_path} error_msg] } {
        send_msg_id XPS-Tcl-010 ERROR "failed to delete file ($file_path): $error_msg\n"
        return 1
      }
    }
  } else {
    if {[catch {file mkdir $dir} error_msg] } {
      send_msg_id XPS-Tcl-011 ERROR "failed to create the directory ($dir): $error_msg\n"
      return 1
    }
  }

  if { $a_sim_vars(b_xport_src_files) } {
    set a_sim_vars(s_srcs_dir) [file normalize [file join $dir "srcs"]]
    if {[catch {file mkdir $a_sim_vars(s_srcs_dir)} error_msg] } {
      send_msg_id XPS-Tcl-012 ERROR "failed to create the directory ($a_sim_vars(s_srcs_dir)): $error_msg\n"
      return 1
    }
    set a_sim_vars(s_incl_dir) [file normalize [file join $a_sim_vars(s_srcs_dir) "incl"]]
    if {[catch {file mkdir $a_sim_vars(s_incl_dir)} error_msg] } {
      send_msg_id XPS-Tcl-013 ERROR "failed to create the directory ($a_sim_vars(s_incl_dir)): $error_msg\n"
      return 1
    }
  }

  set a_sim_vars(s_launch_dir) $dir

  return 0
}

proc xps_set_simulator_name {} {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:
 
  variable a_sim_vars
  switch -regexp -- $a_sim_vars(s_simulator) {
    "xsim"     { set a_sim_vars(s_simulator_name) "Vivado Simulator (Xilinx, Inc.)" }
    "modelsim" { set a_sim_vars(s_simulator_name) "ModelSim Simulator (Mentor Graphics)" }
    "questa"   { set a_sim_vars(s_simulator_name) "Questa Advanced Simulator (Mentor Graphics)" }
    "ies"      { set a_sim_vars(s_simulator_name) "Incisive Enterprise Simulator (Cadence Design Systems, Inc.)" }
    "vcs"      { set a_sim_vars(s_simulator_name) "Verilog Compiler Simulator (Synopsys, Inc.)" }
  }
}

proc xps_set_target_obj {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set comp_file $a_sim_vars(s_comp_file)
  if { {} != $comp_file } {
    set a_sim_vars(sp_tcl_obj) [get_files -all -quiet [list "$comp_file"]]
    set a_sim_vars(s_top) [file root [file tail $a_sim_vars(sp_tcl_obj)]]
  } else {
    if { $a_sim_vars(b_is_managed) } {
      set ips [get_ips -quiet]
      if {[llength $ips] == 0} {
        send_msg_id XPS-Tcl-014 INFO "No IP's found in the current project.\n"
        return 1
      }
      send_msg_id XPS-Tcl-015 ERROR "No IP source object specified. Please type 'export_simulation -help' for usage info.\n"
      return 1
    } else {
      set a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj)
      xps_verify_ip_status
      set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
    }
  }
}

proc xps_gen_mem_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable s_embedded_files_filter

  if { [xps_is_fileset $a_sim_vars(sp_tcl_obj)] } {
    set embedded_files [get_files -all -quiet -filter $s_embedded_files_filter]
    if { [llength $embedded_files] > 0 } {
      send_msg_id XPS-Tcl-016 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
      generate_mem_files $a_sim_vars(s_launch_dir)
    }
  }
}

proc xps_update_compile_order { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  update_compile_order -fileset [current_fileset]
  update_compile_order -fileset [current_fileset -simset]
}

proc xps_get_compile_order_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compile_order_files
  variable s_data_files_filter
  variable s_non_hdl_data_files_filter

  set tcl_obj $a_sim_vars(sp_tcl_obj)

  if { [xps_is_ip $tcl_obj] } {
    set ip_filename [file tail $tcl_obj]
    set l_compile_order_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]]
    set ip_filter "FILE_TYPE == \"IP\""
    set ip_name [file tail $tcl_obj]
    set data_files [list]
    set data_files [concat $data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_data_files_filter]]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_non_hdl_data_files_filter] {
      if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
        if { [get_property {IS_USER_DISABLED} $file] } {
          continue;
        }
      }
      lappend data_files $file
    }
    xps_export_data_files $data_files
  } elseif { [xps_is_fileset $tcl_obj] } {
    set used_in_val "simulation"
    switch [get_property "FILESET_TYPE" [get_filesets $tcl_obj]] {
      "DesignSrcs"     { set used_in_val "synthesis" }
      "SimulationSrcs" { set used_in_val "simulation"}
      "BlockSrcs"      { set used_in_val "synthesis" }
    }
    set l_compile_order_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $tcl_obj]]
    xps_export_fs_data_files $s_data_files_filter
    xps_export_fs_non_hdl_data_files
  } else {
    send_msg_id XPS-Tcl-017 INFO "Unsupported object source: $tcl_obj\n"
    return 1
  }
}

proc xps_export_fs_non_hdl_data_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable s_non_hdl_data_files_filter
  set data_files [list]
  foreach file [get_files -all -quiet -of_objects [get_filesets $a_sim_vars(fs_obj)] -filter $s_non_hdl_data_files_filter] {
    if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
      if { [get_property {IS_USER_DISABLED} $file] } {
        continue;
      }
    }
    lappend data_files $file
  }
  xps_export_data_files $data_files
}

proc xps_process_cmd_str {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set global_files_str {}

  set b_lang_updated 0
  set curr_lang [string tolower [get_property simulator_language [current_project]]]
  if { $a_sim_vars(b_ip_netlist) } {
    if { $curr_lang != $a_sim_vars(s_ip_netlist) } {
      set_property simulator_language $a_sim_vars(s_ip_netlist) [current_project]
      set b_lang_updated 1
    }
  }
  set a_sim_vars(l_design_files) [xps_uniquify_cmd_str [xps_get_files global_files_str]]
  if { $b_lang_updated } {
    set_property simulator_language $curr_lang [current_project]
  }
  set a_sim_vars(global_files_value) $global_files_str
}

proc xps_get_files { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $global_files_str_arg global_files_str

  variable a_sim_vars
  variable l_compile_order_files

  set files          [list]
  set tcl_obj        $a_sim_vars(sp_tcl_obj)
  set linked_src_set [get_property "SOURCE_SET" $tcl_obj]
  set target_lang    [get_property "TARGET_LANGUAGE" [current_project]]
  set src_mgmt_mode  [get_property "SOURCE_MGMT_MODE" [current_project]]

  set incl_file_paths [list]
  set incl_files      [list]

  send_msg_id XPS-Tcl-018 INFO "Finding global include files..."
  xps_get_global_include_files incl_file_paths incl_files

  set global_incl_files $incl_files
  set global_files_str [xps_get_global_include_file_cmdstr incl_files]

  send_msg_id XPS-Tcl-019 INFO "Finding include directories and verilog header directory paths..."
  set l_incl_dirs_opts [list]
  foreach dir [concat [xps_get_verilog_incl_dirs] [xps_get_verilog_incl_file_dirs {}]] {
    lappend l_incl_dirs_opts "+incdir+\"$dir\""
  }

  if { [xps_is_fileset $tcl_obj] } {
    set b_add_sim_files 1
    if { {} != $linked_src_set } {
      xps_add_block_fs_files $global_files_str l_incl_dirs_opts files
    }
    if { {All} == $src_mgmt_mode } {
      send_msg_id XPS-Tcl-020 INFO "Fetching design files from '$tcl_obj'..."
      foreach file $l_compile_order_files {
        if { [xps_is_global_include_file $global_files_str $file] } { continue }
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
        set compiler [xps_get_compiler $file_type]
        set l_other_compiler_opts [list]
        xps_append_compiler_options $compiler $file_type l_other_compiler_opts
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
        set cmd_str [xps_get_cmdstr $file $file_type $compiler $g_files l_other_compiler_opts l_incl_dirs_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
        }
      }
      set b_add_sim_files 0
    } else {
      if { {} != $linked_src_set } {
        set srcset_obj [get_filesets $linked_src_set]
        if { {} != $srcset_obj } {
          set used_in_val "simulation"
          send_msg_id XPS-Tcl-021 INFO "Fetching design files from '$srcset_obj'...(this may take a while)..."
          set l_compile_order_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $srcset_obj]]
          foreach file $l_compile_order_files {
            set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
            set compiler [xps_get_compiler $file_type]
            set l_other_compiler_opts [list]
            xps_append_compiler_options $compiler $file_type l_other_compiler_opts
            if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
            set g_files $global_files_str
            if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
            set cmd_str [xps_get_cmdstr $file $file_type $compiler $g_files l_other_compiler_opts l_incl_dirs_opts]
            if { {} != $cmd_str } {
              lappend files $cmd_str
            }
          }
        }
      }
    }

    if { $b_add_sim_files } {
      send_msg_id XPS-Tcl-022 INFO "Fetching design files from '$a_sim_vars(fs_obj)'..."
      foreach file [get_files -quiet -all -of_objects $a_sim_vars(fs_obj)] {
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
        set compiler [xps_get_compiler $file_type]
        set l_other_compiler_opts [list]
        xps_append_compiler_options $compiler $file_type l_other_compiler_opts
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
        if { [get_property "IS_AUTO_DISABLED" [lindex [get_files -quiet -all [list "$file"]] 0]]} { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
        set cmd_str [xps_get_cmdstr $file $file_type $compiler $g_files l_other_compiler_opts l_incl_dirs_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
        }
      }
    }
  } elseif { [xps_is_ip $tcl_obj] } {
    send_msg_id XPS-Tcl-023 INFO "Fetching design files from IP '$tcl_obj'..."
    foreach file $l_compile_order_files {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
      set compiler [xps_get_compiler $file_type]
      set l_other_compiler_opts [list]
      xps_append_compiler_options $compiler $file_type l_other_compiler_opts
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
      set cmd_str [xps_get_cmdstr $file $file_type $compiler $g_files l_other_compiler_opts l_incl_dirs_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
      }
    }
  }
  return $files
}

proc xps_is_ip { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable l_valid_ip_extns 
  if { [lsearch -exact $l_valid_ip_extns [file extension $tcl_obj]] >= 0 } {
    return 1
  } else {
    if {[regexp -nocase {^ip} [get_property [rdi::get_attr_specs CLASS -object $tcl_obj] $tcl_obj]] } {
      return 1
    }
  }
  return 0
}

proc xps_is_fileset { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if {[regexp -nocase {^fileset_type} [rdi::get_attr_specs -quiet -object $tcl_obj -regexp .*FILESET_TYPE.*]]} {
    return 1
  }
  return 0
}

proc xps_uniquify_cmd_str { cmd_strs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set cmd_str_set   [list]
  set uniq_cmd_strs [list]
  foreach str $cmd_strs {
    if { [lsearch -exact $cmd_str_set $str] == -1 } {
      lappend cmd_str_set $str
      lappend uniq_cmd_strs $str
    }
  }
  return $uniq_cmd_strs
}

proc xps_add_block_fs_files { global_files_str l_incl_dirs_opts_arg files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts
  upvar $files_arg files

  send_msg_id XPS-Tcl-024 INFO "Finding block fileset files..."
  set vhdl_filter "FILE_TYPE == \"VHDL\" || FILE_TYPE == \"VHDL 2008\""
  foreach file [xps_get_files_from_block_filesets $vhdl_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
    set compiler [xps_get_compiler $file_type]
    set l_other_compiler_opts [list]
    xps_append_compiler_options $compiler $file_type l_other_compiler_opts
    set cmd_str [xps_get_cmdstr $file $file_type $compiler {} l_other_compiler_opts l_incl_dirs_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
    }
  }
  set verilog_filter "FILE_TYPE == \"Verilog\""
  foreach file [xps_get_files_from_block_filesets $verilog_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
    set compiler [xps_get_compiler $file_type]
    set l_other_compiler_opts [list]
    xps_append_compiler_options $compiler $file_type l_other_compiler_opts
    set cmd_str [xps_get_cmdstr $file $file_type $compiler $global_files_str l_other_compiler_opts l_incl_dirs_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
    }
  }
}

proc xps_get_files_from_block_filesets { filter_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set file_list [list]
  set filter "FILESET_TYPE == \"BlockSrcs\""
  set used_in_val "simulation"
  set fs_objs [get_filesets -filter $filter]
  if { [llength $fs_objs] > 0 } {
    foreach fs_obj $fs_objs {
      set fs_name [get_property "NAME" $fs_obj]
      set files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fs_obj] -filter $filter_type]
      if { [llength $files] > 0 } {
        foreach file $files {
          lappend file_list $file
        }
      }
    }
  }
  return $file_list
}

proc xps_get_cmdstr { file file_type compiler global_files_str l_other_compiler_opts_arg  l_incl_dirs_opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  upvar $l_other_compiler_opts_arg l_other_compiler_opts
  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts

  set dir             $a_sim_vars(s_launch_dir)
  set b_absolute_path $a_sim_vars(b_absolute_path)
  set cmd_str {}
  set associated_library [get_property "DEFAULT_LIB" [current_project]]

  set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]

  if { {} != $file_obj } {
    if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
      set associated_library [get_property "LIBRARY" $file_obj]
    }
    # extract only if the file is an object
    set file [extract_files -files [list "$file"] -base_dir $dir/ip_files]
  }

  set src_file $file

  if { $a_sim_vars(b_absolute_path) } {
    set file "[xps_resolve_file_path $file]"
  } else {
    switch $a_sim_vars(s_simulator) {
      "xsim" -
      "modelsim" -
      "questa" {
        set file "./[xps_get_relative_file_path $file $dir]"
        if { $a_sim_vars(b_xport_src_files) } {
          set file "./srcs/[file tail $src_file]"
        }
      }
      "ies" -
      "vcs" {
        set file "\$ref_dir/[xps_get_relative_file_path $file $dir]"
        if { $a_sim_vars(b_xport_src_files) } {
          set file "\$ref_dir/incl"
        }
      }
    }
  }

  set arg_list [list]
  if { [string length $compiler] > 0 } {
    lappend arg_list $compiler
    switch $a_sim_vars(s_simulator) {
      "xsim" {}
      default {
        set arg_list [linsert $arg_list end "-work"]
      }
    }
    set arg_list [linsert $arg_list end "$associated_library"]
    if { {} != $global_files_str } {
      set arg_list [linsert $arg_list end "$global_files_str"]
    }
  }

  set arg_list [concat $arg_list $l_other_compiler_opts]

  set file_str [join $arg_list " "]
  set type [xps_get_file_type_category $file_type]
  set ip_file [xps_get_ip_name $src_file]
  set cmd_str "$type#$file_type#$associated_library#$src_file#$file_str#$ip_file#\"$file\""
  return $cmd_str
}

proc xps_get_ip_name { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  set ip {}
  set file_obj [get_files -all -quiet $src_file]
  if { {} == $file_obj } {
    set file_obj [get_files -all -quiet [file tail $src_file]]
  }

  set props [list_property $file_obj]
  if { [lsearch $props "PARENT_COMPOSITE_FILE"] != -1 } {
    set ip [get_property "PARENT_COMPOSITE_FILE" $file_obj]
  }
  return $ip
}

proc xps_get_file_type_category { file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set type {UNKNOWN}
  switch $file_type {
    {VHDL} -
    {VHDL 2008} {
      set type {VHDL}
    }
    {Verilog} -
    {SystemVerilog} -
    {Verilog Header} {
      set type {VERILOG}
    }
  }
  return $type
}

proc xps_get_design_libs {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set libs [list]
  foreach file $a_sim_vars(l_design_files) {
    set type      [lindex [split $file {#}] 0]
    set file_type [lindex [split $file {#}] 1]
    set library   [lindex [split $file {#}] 2]
    if { {} == $library } {
      continue;
    }
    if { [lsearch -exact $libs $library] == -1 } {
      lappend libs $library
    }
  }
  return $libs
}

proc xps_get_relative_file_path { file_path_to_convert relative_to } {
  # Summary:
  # Argument Usage:
  # file_path_to_convert:
  # Return Value:

  variable a_sim_vars
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
  set fc_comps_len [llength $file_comps]
  set rt_comps_len [llength $relative_to_comps]
  # compare each dir element of file_to_convert and relative_to, set the flag and
  # get the final index till these sub-dirs matched
  while { [lindex $file_comps $index] == [lindex $relative_to_comps $index] } {
    if { !$found_match } { set found_match true }
    incr index
    if { ($index == $fc_comps_len) || ($index == $rt_comps_len) } {
      break;
    }
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

proc xps_resolve_file_path { file_dir_path_to_convert } {
  # Summary: Make file path relative to ref_dir if relative component found
  # Argument Usage:
  # file_dir_path_to_convert: input file to make relative to specfied path
  # Return Value:
  # Relative path wrt the path specified

  variable a_sim_vars
  set ref_dir [file normalize [string map {\\ /} $a_sim_vars(s_launch_dir)]]
  set ref_comps [lrange [split $ref_dir "/"] 1 end]
  set file_comps [lrange [split [file normalize [string map {\\ /} $file_dir_path_to_convert]] "/"] 1 end]
  set index 1
  while { [lindex $ref_comps $index] == [lindex $file_comps $index] } {
    incr index
  }
  # is file path within reference dir? return relative path
  if { $index == [llength $ref_comps] } {
    return [xps_get_relative_file_path $file_dir_path_to_convert $ref_dir]
  }
  # return absolute
  return $file_dir_path_to_convert
}

proc xps_export_fs_data_files { filter } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set data_files [list]
  set ips [get_files -all -quiet -filter "FILE_TYPE == \"IP\""]
  foreach ip $ips {
    set ip_name [file tail $ip]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter] {
      lappend data_files $file
    }
  }
  set filesets [list]
  lappend filesets [get_filesets -filter "FILESET_TYPE == \"BlockSrcs\""]
  lappend filesets [current_fileset -srcset]
  lappend filesets $a_sim_vars(fs_obj)

  foreach fs_obj $filesets {
    foreach file [get_files -all -quiet -of_objects [get_filesets $fs_obj] -filter $filter] {
      lappend data_files $file
    }
  }
  xps_export_data_files $data_files
}

proc xps_export_data_files { data_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set export_dir $a_sim_vars(s_launch_dir)
  if { [llength $data_files] > 0 } {
    set data_files [xps_remove_duplicate_files $data_files]
    foreach file $data_files {
      if {[catch {file copy -force $file $export_dir} error_msg] } {
        send_msg_id XPS-Tcl-025 WARNING "Failed to copy file '$file' to '$export_dir' : $error_msg\n"
      }
    }
  }
}

proc xps_write_sim_script {} {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:
 
  variable a_sim_vars
 
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xps_is_ip $tcl_obj] } {
    set a_sim_vars(s_top) [file tail [file root $tcl_obj]]
    send_msg_id XPS-Tcl-026 INFO "Inspecting IP design source files for '$a_sim_vars(s_top)'...\n"
    if {[xps_export_sim_files_for_ip $tcl_obj]} {
      return 1
    }
  } elseif { [xps_is_fileset $tcl_obj] } {
    set a_sim_vars(s_top) [get_property top [get_filesets $tcl_obj]]
    send_msg_id XPS-Tcl-027 INFO "Inspecting design source files for '$a_sim_vars(s_top)' in fileset '$tcl_obj'...\n"
    if {[string length $a_sim_vars(s_top)] == 0} {
      set a_sim_vars(s_top) "unknown"
    }
    if { [xps_export_sim_files_for_fs] } {
      return 1
    }
  } else {
    send_msg_id XPS-Tcl-028 INFO "Unsupported object source: $tcl_obj\n"
    return 1
  }
  send_msg_id XPS-Tcl-029 INFO \
    "File '$a_sim_vars(s_script_filename)' exported (file path:$a_sim_vars(s_launch_dir)/$a_sim_vars(s_script_filename))\n"
 
  return 0
}

proc xps_write_filelist {} {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:
 
  variable a_sim_vars
  set dir [file normalize [file join $a_sim_vars(s_launch_dir)]]

  set fh 0
  set file [file join $dir "filelist.f"]
  if {[catch {open $file w} fh]} {
    send_msg_id XPS-Tcl-030 ERROR "failed to open file to write ($file)\n"
    return 1
  }

  set lines [list]
  foreach file $::tclapp::xilinx::projutils::a_sim_vars(l_design_files) {
    set fargs    [split $file {#}]
    set type          [lindex $fargs 0]
    set file_type     [lindex $fargs 1]
    set lib           [lindex $fargs 2]
    set proj_src_file [lindex $fargs 3]
    set cmd_str       [lindex $fargs 4]
    set ip_file       [lindex $fargs 5]
    set src_file      [lindex $fargs 6]

    set filename [file tail $proj_src_file]
    set ipname   [file rootname [file tail $ip_file]]
    lappend lines "$filename $lib $ipname"
  }
  struct::matrix file_matrix;
  file_matrix add columns 3;
  foreach line $lines {
    file_matrix add row $line;
  }
  puts $fh [file_matrix format 2string]
  file_matrix destroy
  close $fh

  return 0
}

proc xps_export_sim_files_for_ip { tcl_obj } {
  # Summary: 
  # Argument Usage:
  # source object
  # Return Value:
  # true (0) if success, false (1) otherwise

  variable a_sim_vars
  variable s_data_files_filter
  variable l_compile_order_files
  set ip_filename [file tail $tcl_obj]
  set l_compile_order_files [xps_remove_duplicate_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]]]
  xps_print_source_info
  if { {} == $a_sim_vars(s_script_filename) } {
    set simulator $a_sim_vars(s_simulator)
    set ip_name [file root $ip_filename]
    set a_sim_vars(s_script_filename) "${ip_name}_sim_${simulator}.$a_sim_vars(s_script_extn)"
  }
  if { [xps_write_script] } {
    return 1
  }
  return 0
}
 
proc xps_export_sim_files_for_fs { } {
  # Summary: 
  # Argument Usage:
  # source object
  # Return Value:
  # true (0) if success, false (1) otherwise
  
  variable a_sim_vars
  xps_print_source_info
  if { {} == $a_sim_vars(s_script_filename) } {
    set simulator $a_sim_vars(s_simulator)
    set a_sim_vars(s_script_filename) "$a_sim_vars(s_top)_sim_${simulator}.$a_sim_vars(s_script_extn)"
  }
  if { [xps_write_script] } {
    return 1
  }
  return 0
}

proc xps_print_source_info {} {
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
    set file_type [get_property file_type [get_files -quiet -all [list "$file"]]]
    switch -- $file_type {
      {VHDL}    { incr n_vhdl_srcs    }
      {Verilog} { incr n_verilog_srcs }
    }
  }
  send_msg_id XPS-Tcl-031 INFO "Number of design source files found = $n_total_srcs\n"
}
 
proc xps_write_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  
  set file [file normalize [file join $a_sim_vars(s_launch_dir) $a_sim_vars(s_script_filename)]]
 
  # recommend -force if file exists
  if { [file exists $file] && (!$a_sim_vars(b_overwrite)) } {
    send_msg_id XPS-Tcl-032 ERROR "Simulation file '$file' already exist. Use -force option to overwrite."
    return 1
  }
    
  if { [file exists $file] } {
    if {[catch {file delete -force $file} error_msg] } {
      send_msg_id XPS-Tcl-033 ERROR "failed to delete file ($file): $error_msg\n"
      return 1
    }
  }
 
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id XPS-Tcl-034 ERROR "failed to open file to write ($file)\n"
    return 1
  }
 
  send_msg_id XPS-Tcl-035 INFO \
    "Generating simulation files for the '$a_sim_vars(s_simulator_name)' simulator...\n"
 
  # write header, compiler command/options
  if { [xps_write_driver_script $fh] } {
    return 1
  }
  close $fh
 
  # make filelist executable
  if {$::tcl_platform(platform) == "unix"} {
    if {[catch {exec chmod a+x $file} error_msg] } {
      send_msg_id XPS-Tcl-036 WARNING "failed to change file permissions to executable ($file): $error_msg\n"
    }
  }
 
  return 0
}
 
proc xps_write_driver_script { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  variable l_compile_order_files
  set dir $a_sim_vars(s_launch_dir)

  xps_write_header $fh
  xps_print_usage $fh
  xps_write_libs $fh
  switch -regexp -- $a_sim_vars(s_simulator) {
    "ies" -
    "vcs" {
      xps_create_do_file
    }
  }
  xps_write_glbl $fh
  xps_write_reset $fh

  puts $fh "# STEP: setup"
  puts $fh "setup()\n\{"

  xps_write_proc_stmt $fh

  puts $fh "  # Add any setup/initialization commands here:-\n"
  puts $fh "  # <user specific commands>\n"
  puts $fh "\}\n"

  if { $a_sim_vars(b_single_step) } {
    puts $fh "# RUN_STEP: <execute>"
    puts $fh "execute()\n\{"
    switch -regexp -- $a_sim_vars(s_simulator) {
      "xsim" -
      "modelsim" -
      "questa" {
      }
      default {
        puts $fh "  # Directory path for design sources and include directories (if any) wrt this path"
        if { $a_sim_vars(b_absolute_path) } {
          puts $fh "  ref_dir=\"$a_sim_vars(s_launch_dir)/$a_sim_vars(s_srcs_dir)\""
        } else {
          if { $a_sim_vars(b_xport_src_files) } {
            puts $fh "  ref_dir=\"./srcs\""
          } else {
            puts $fh "  ref_dir=\".\""
          }
        }
      }
    }
    switch -regexp -- $a_sim_vars(s_simulator) {
      "xsim" {
        xps_write_prj_single_step
        xps_write_xelab_cmdline $fh
        xps_write_xsim_cmdline $fh
      }
      "modelsim" {
        puts $fh "  source run.do 2>&1 | tee -a run.log"
        xps_write_do_file_for_compile
      }
      "questa" {
        set filename "run.f"
        puts $fh "  xil_lib=[file normalize [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]]"
        set arg_list [list "-f $filename" \
                           "-y \$xil_lib/verilog/src/retarget/" \
                           "+libext+.v" \
                           "-y \$xil_lib/verilog/src/unisims/" \
                           "+libext+.v" \
                           "-incr +acc" \
                           "-l run.log" \
                           "./glbl.v"
                     ]
        #"-R -do \"run 1000ns; quit\""
        foreach dir [concat [xps_get_verilog_incl_dirs] [xps_get_verilog_incl_file_dirs {} true]] {
          lappend arg_list "+incdir+\"$dir\""
        }
        set cmd_str [join $arg_list " \\\n       "]
        puts $fh "  qverilog $cmd_str"
    
        set fh_1 0
        set file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
        if {[catch {open $file w} fh_1]} {
          send_msg_id XPS-Tcl-037 ERROR "failed to open file to write ($file)\n"
          return 1
        }
        xps_write_compile_order $fh_1
        close $fh_1
      }
      "ies" {
        set filename "run.f"
        set arg_list [list "-V93" \
                           "-timescale 1ns/1ps" \
                           "-top $a_sim_vars(s_top)" \
                           "-f $filename" \
                           "-l run.log" \
                     ]
        foreach dir [concat [xps_get_verilog_incl_dirs] [xps_get_verilog_incl_file_dirs {} true]] {
          lappend arg_list "+incdir+\"$dir\""
        }
        set cmd_str [join $arg_list " \\\n       "]
        puts $fh "  irun $cmd_str"
    
        set fh_1 0
        set file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
        if {[catch {open $file w} fh_1]} {
          send_msg_id XPS-Tcl-038 ERROR "failed to open file to write ($file)\n"
          return 1
        }
        xps_write_compile_order $fh_1
        close $fh_1
      }
      "vcs" {
        set filename "run.f"
        puts $fh "  xil_lib=[file normalize [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]]"
        set arg_list [list "-V" \
                           "-f $filename" \
                           "+libext+.v" \
                           "-y \$xil_lib/verilog/src/retarget/" \
                           "+libext+.v" \
                           "-y \$xil_lib/verilog/src/unisims/" \
                           "+libext+.v" \
                           "-lca +v2k" \
                           "-sverilog" \
                           "-l run.log" \
                     ]

                          # "-f \$xil_lib/secureip/secureip_cell.list.f"
        foreach dir [concat [xps_get_verilog_incl_dirs] [xps_get_verilog_incl_file_dirs {} true]] {
          lappend arg_list "+incdir+\"$dir\""
        }
        set cmd_str [join $arg_list " \\\n       "]
        puts $fh "  vcs $cmd_str"
        #puts $fh "  ./simv"
    
        set fh_1 0
        set file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
        if {[catch {open $file w} fh_1]} {
          send_msg_id XPS-Tcl-039 ERROR "failed to open file to write ($file)\n"
          return 1
        }
        xps_write_compile_order $fh_1
        close $fh_1
      }
    }
    puts $fh "\}\n"
  } else {
    puts $fh "# RUN_STEP: <compile>"
    puts $fh "compile()\n\{"
    switch -regexp -- $a_sim_vars(s_simulator) {
      "xsim" -
      "modelsim" -
      "questa" {
      }
      default {
        puts $fh "  # Directory path for design sources and include directories (if any) wrt this path"
        if { $a_sim_vars(b_absolute_path) } {
          puts $fh "  ref_dir=\"$a_sim_vars(s_launch_dir)/$a_sim_vars(s_srcs_dir)\""
        } else {
          if { $a_sim_vars(b_xport_src_files) } {
            puts $fh "  ref_dir=\"./srcs\""
          } else {
            puts $fh "  ref_dir=\".\""
          }
        }
      }
    }
  
    if {[llength $l_compile_order_files] == 0} {
      puts $fh "# None (no sources present)"
      puts $fh "\}"
      return 0
    }
  
    switch -regexp -- $a_sim_vars(s_simulator) {
      "modelsim" -
      "questa" {
      }
      default {
        puts $fh "\n  # Command line options"
      }
    }

    switch -regexp -- $a_sim_vars(s_simulator) {
      "xsim" {
        set arg_list [list]
        if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-m64"] }
        if { [xps_contains_verilog] } {
          puts $fh "  opts_ver=\"[join $arg_list " "]\""
        }

        set arg_list [list]
        if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-m64"] }
        if { [xps_contains_vhdl] } {
          puts $fh "  opts_vhd=\"[join $arg_list " "]\"\n"
        }
      }
      "ies" { 
        set arg_list [list "-V93" "-RELAX" "-logfile" "ncvhdl.log" "-append_log"]
        if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-64bit"] }
        puts $fh "  opts_vhd=\"[join $arg_list " "]\""

        set arg_list [list "-messages" "-logfile" "ncvlog.log" "-append_log"]
        if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-64bit"] }
        puts $fh "  opts_ver=\"[join $arg_list " "]\"\n"
      }
      "vcs"   {
        set arg_list [list]
        if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-full64"] }
        puts $fh "  opts_vhd=\"[join $arg_list " "]\""

        set arg_list [list]
        if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-full64"] }
        puts $fh "  opts_ver=\"[join $arg_list " "]\"\n"
      }
    }
    puts $fh "  # Compile design files" 
    switch $a_sim_vars(s_simulator) { 
      "xsim" {
        set redirect "2>&1 | tee compile.log"
        if { [xps_contains_verilog] } {
          puts $fh "  xvlog \$opts_ver -prj vlog.prj $redirect"
        }
        if { [xps_contains_vhdl] } {
          puts $fh "  xvhdl \$opts_vhd -prj vhdl.prj $redirect"
        }
        xps_write_xsim_prj
      }
      "modelsim" -
      "questa" {
        puts $fh "  source compile.do 2>&1 | tee -a compile.log"
        xps_write_do_file_for_compile
      }
      "ies" -
      "vcs" {
        xps_write_compile_order $fh
      }
    }
   
    if { [xps_contains_verilog] } {
      switch -regexp -- $a_sim_vars(s_simulator) {
        "ies" {
          puts $fh "\n  ncvlog \$opts_ver -work $a_sim_vars(default_lib) \\\n\    \"./glbl.v\""
        }
        "vcs" {
          set sw {}
          if { {work} != $a_sim_vars(default_lib) } {
            set sw "-work $a_sim_vars(default_lib)"
          }
          puts $fh "  vlogan \$opts_ver +v2k $sw \"glbl.v\""
        }
      }
    }
    puts $fh "\}\n"
    switch -regexp -- $a_sim_vars(s_simulator) {
      "modelsim" {}
      default {
        xps_write_elaboration_cmds $fh
      }
    }
    xps_write_simulation_cmds $fh
  }
  puts $fh "\n# Main steps"
  puts $fh "run()\n\{"
  puts $fh "  setup \$1 \$2"
  if { $a_sim_vars(b_single_step) } {
    puts $fh "  execute"
  } else {
    puts $fh "  compile"
    switch -regexp -- $a_sim_vars(s_simulator) {
      "modelsim" {}
      default {
        puts $fh "  elaborate"
      }
    }
    puts $fh "  simulate"
  }
  puts $fh "\}"
  xps_write_main $fh
  return 0
}

proc xps_remove_duplicate_files { compile_order_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

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

proc xps_set_initial_cmd { fh cmd_str src_file file_type lib prev_file_type_arg prev_lib_arg log_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:
  # None

  variable a_sim_vars

  upvar $prev_file_type_arg prev_file_type
  upvar $prev_lib_arg  prev_lib
  upvar $log_arg log

  switch $a_sim_vars(s_simulator) {
    "modelsim" -
    "questa" {
      puts $fh "$cmd_str \\"
      puts $fh "$src_file \\"
    }
    "ies" -
    "vcs" {
      puts $fh "  $cmd_str \\"
      if { $a_sim_vars(b_xport_src_files) } {
        puts $fh "    \$ref_dir/$src_file \\"
      } else {
        puts $fh "    $src_file \\"
      }
    }
  }

  set prev_file_type $file_type
  set prev_lib  $lib

  switch $a_sim_vars(s_simulator) {
    "vcs" {
      if { [regexp -nocase {vhdl} $file_type] } {
        set log "vhdlan.log"
      } elseif { [regexp -nocase {verilog} $file_type] } {
        set log "vlogan.log"
      }
    }
  }
}
 
proc xps_write_compile_order { fh } {
  # Summary: Write compile order for the target simulator
  # Argument Usage:
  # fh - file handle
  # Return Value:
  # none
 
  variable a_sim_vars

  set b_first true
  set prev_lib  {}
  set prev_file_type {}
  set log {}
  set redirect_cmd_str "    2>&1 | tee -a"
  set b_redirect false
  set b_appended false

  foreach file $a_sim_vars(l_design_files) {
    set fargs    [split $file {#}]

    set type           [lindex $fargs 0]
    set file_type      [lindex $fargs 1]
    set lib            [lindex $fargs 2]
    set proj_src_file  [lindex $fargs 3]
    set cmd_str        [lindex $fargs 4]
    set ip_file        [lindex $fargs 5]
    set src_file       [lindex $fargs 6]

    set proj_src_filename [file tail $proj_src_file]
    if { $a_sim_vars(b_xport_src_files) } {
      set target_dir $a_sim_vars(s_srcs_dir)
      if { {} != $ip_file } {
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "$ip_name/$proj_src_filename"
        set ip_dir [file join $a_sim_vars(s_srcs_dir) $ip_name] 
        if { ![file exists $ip_dir] } {
          if {[catch {file mkdir $ip_dir} error_msg] } {
            send_msg_id XPS-Tcl-040 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
            return 1
          }
        }
        set target_dir $ip_dir
      }
      if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
        send_msg_id XPS-Tcl-041 WARNING "failed to copy file '$proj_src_file' to '$a_sim_vars(s_srcs_dir)' : $error_msg\n"
      }
    }
   
    switch $a_sim_vars(s_simulator) {
      "vcs" {
        # vlogan expects double back slash
        if { ([regexp { } $src_file] && [regexp -nocase {vlogan} $cmd_str]) } {
          set src_file [string trim $src_file "\""]
          regsub -all { } $src_file {\\\\ } src_file
        }
      }
    }

    if { $a_sim_vars(b_single_step) } {
      set file $proj_src_file
      regsub -all {\"} $file {} file
      puts $fh $file
      continue
    }

    set b_redirect false
    set b_appended false

    if { $b_first } {
      set b_first false
      if { $a_sim_vars(b_xport_src_files) } {
        xps_set_initial_cmd $fh $cmd_str $proj_src_filename $file_type $lib prev_file_type prev_lib log
      } else {
        xps_set_initial_cmd $fh $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
      }
    } else {
      if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
        if { $a_sim_vars(b_xport_src_files) } {
          puts $fh "    \$ref_dir/$proj_src_filename \\"
        } else {
          puts $fh "    $src_file \\"
        }
        set b_redirect true
      } else {
        switch $a_sim_vars(s_simulator) {
          "ies"    { puts $fh "" }
          "vcs"    { puts $fh "$redirect_cmd_str $log\n" }
        }
        if { $a_sim_vars(b_xport_src_files) } {
          xps_set_initial_cmd $fh $cmd_str $proj_src_filename $file_type $lib prev_file_type prev_lib log
        } else {
          xps_set_initial_cmd $fh $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
        }
        set b_appended true
      }
    }
  }

  if { $a_sim_vars(b_single_step) } {
    #
  } else {
    switch $a_sim_vars(s_simulator) {
      "vcs" {
        if { (!$b_redirect) || (!$b_appended) } {
          puts $fh "$redirect_cmd_str $log\n"
        }
      }
    }
  }
}

proc xps_write_header { fh } {
  # Summary: Driver script header info
  # Argument Usage:
  # fh - file descriptor
  # Return Value:
  # none
 
  variable a_sim_vars
 
  set curr_time   [clock format [clock seconds]]
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
 
  puts $fh "#!/bin/sh -f"
  puts $fh "# $product (TM) $version_id\n#"
  puts $fh "# Filename    : $a_sim_vars(s_script_filename)"
  puts $fh "# Simulator   : $a_sim_vars(s_simulator_name)"
  puts $fh "# Description : Simulation script for compiling, elaborating and verifying the project source files."
  puts $fh "#               The script will automatically create the design libraries sub-directories in the run"
  puts $fh "#               directory, add the library logical mappings in the simulator setup file, create default"
  puts $fh "#               'do' file, copy glbl.v into the run directory for verilog sources in the design (if any),"
  puts $fh "#               execute compilation, elaboration and simulation steps. By default, the source file and"
  puts $fh "#               include directory paths will be set relative to the 'ref_dir' variable unless the"
  puts $fh "#               -absolute_path is specified in which case the paths will be set absolute.\n#"
  puts $fh "# Generated by $product on $curr_time"
  puts $fh "# $copyright \n#"
  puts $fh "# usage: $a_sim_vars(s_script_filename) \[-help\]"
  puts $fh "# usage: $a_sim_vars(s_script_filename) \[-noclean_files\]"
  puts $fh "# usage: $a_sim_vars(s_script_filename) \[-reset_run\]\n#"

  puts $fh "# Prerequisite:- To compile and run simulation, you must compile the Xilinx simulation libraries using the"
  puts $fh "# 'compile_simlib' TCL command. For more information about this command, run 'compile_simlib -help' in the"
  puts $fh "# $product Tcl Shell. Once the libraries have been compiled successfully, specify the -lib_map_path switch"
  puts $fh "# that points to these libraries and rerun export_simulation. For more information about this switch please"
  puts $fh "# type 'export_simulation -help' in the Tcl shell.\n#"
  puts $fh "# Alternatively, if the libraries are already compiled then replace <SPECIFY_COMPILED_LIB_PATH> in this script"
  puts $fh "# with the compiled library directory path.\n#"
  puts $fh "# Additional references - 'Xilinx Vivado Design Suite User Guide:Logic simulation (UG900)'\n#"
  puts $fh "# ********************************************************************************************************\n\n"
}

proc xps_write_elaboration_cmds { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  variable l_compile_order_files

  set design_files $a_sim_vars(l_design_files)
  set top          $a_sim_vars(s_top)

  puts $fh "# RUN_STEP: <elaborate>"
  puts $fh "elaborate()\n\{"
  if {[llength $l_compile_order_files] == 0} {
    puts $fh "# None (no sources present)"
    return
  }
 
  switch -regexp -- $a_sim_vars(s_simulator) {
    "xsim" {
      xps_write_xelab_cmdline $fh
    }
    "modelsim" -
    "questa" {
      puts $fh "  source elaborate.do 2>&1 | tee -a elaborate.log"
      xps_write_do_file_for_elaborate
    }
    "ies" { 
      set top_lib [xps_get_top_library]
      set arg_list [list "-relax -access +rwc -messages" "-logfile" "elaborate.log" "-timescale 1ns/1ps"]
      if { ! $a_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64bit"]
      }

      # design contains ax-bfm ip? insert bfm library
      if { [xps_is_axi_bfm] } {
        set simulator_lib [xps_get_bfm_lib $a_sim_vars(s_simulator)]
        if { {} != $simulator_lib } {
          set arg_list [linsert $arg_list 0 "-loadvpi \"$simulator_lib:xilinx_register_systf\""]
        } else {
          send_msg_id XPS-Tcl-042 ERROR "Failed to locate simulator library from 'XILINX_VIVADO' environment variable."
        }
      }

      puts $fh "  opts=\"[join $arg_list " "]\""

      set arg_list [list]
      foreach lib [xps_get_compile_order_libs] {
        if {[string length $lib] == 0} { continue; }
        lappend arg_list "-libname"
        lappend arg_list "[string tolower $lib]"
      }
      set arg_list [linsert $arg_list end "-libname" "unisims_ver" "-libname" "secureip"]
      puts $fh "  libs=\"[join $arg_list " "]\""

      set arg_list [list "ncelab" "\$opts"]
      if { [xps_is_fileset $a_sim_vars(sp_tcl_obj)] } {
        set vhdl_generics [list]
        set vhdl_generics [get_property vhdl_generic [get_filesets $a_sim_vars(sp_tcl_obj)]]
        if { [llength $vhdl_generics] > 0 } {
          xps_append_define_generics $vhdl_generics "ncelab" arg_list
        }
      }
      lappend arg_list "${top_lib}.$a_sim_vars(s_top)"
      if { [xps_contains_verilog] } {
        lappend arg_list "${top_lib}.glbl"
      }
      lappend arg_list "\$libs"
      set cmd_str [join $arg_list " "]
      puts $fh "  $cmd_str"
    }
    "vcs" {
      set top_lib [xps_get_top_library]
      set arg_list [list "-debug_pp" "-t" "ps" "-licwait" "-60" "-l" "elaborate.log"]
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-full64"] }

      # design contains ax-bfm ip? insert bfm library
      if { [xps_is_axi_bfm] } {
        set simulator_lib [xps_get_bfm_lib $a_sim_vars(s_simulator)]
        if { {} != $simulator_lib } {
          set arg_list [linsert $arg_list 0 "-load \"$simulator_lib:xilinx_register_systf\""]
        } else {
          send_msg_id XPS-Tcl-043 ERROR "Failed to locate simulator library from 'XILINX' environment variable."
        }
      }

      puts $fh "  opts=\"[join $arg_list " "]\"\n"
 
      set arg_list [list "vcs" "\$opts" "${top_lib}.$a_sim_vars(s_top)"]
      if { [xps_contains_verilog] } {
        lappend arg_list "${top_lib}.glbl"
      }
      lappend arg_list "-o"
      lappend arg_list "$a_sim_vars(s_top)_simv"
      set cmd_str [join $arg_list " "]
      puts $fh "  $cmd_str"
    }
  }
  puts $fh "\}\n"
}
 
proc xps_write_simulation_cmds { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  variable l_compile_order_files

  set top $::tclapp::xilinx::projutils::a_sim_vars(s_top)

  puts $fh "# RUN_STEP: <simulate>"
  puts $fh "simulate()\n\{"
  if {[llength $l_compile_order_files] == 0} {
    puts $fh "# None (no sources present)"
    return
  }
 
  switch -regexp -- $a_sim_vars(s_simulator) {
    "xsim" {
      xps_write_xsim_cmdline $fh
    }
    "modelsim" -
    "questa" {
      set cmd_str "  vsim -64 -c -do \"do \{$a_sim_vars(do_filename)\}\" -l simulate.log"
      puts $fh $cmd_str
      xps_write_do_file_for_simulate
    }
    "ies" { 
      set top_lib [xps_get_top_library]

      set arg_list [list "-logfile" "simulate.log"]
      if { !$a_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64bit"]
      }
      puts $fh "  opts=\"[join $arg_list " "]\""

      set arg_list [list "ncsim" "\$opts" "${top_lib}.$a_sim_vars(s_top)" "-input" "$a_sim_vars(do_filename)"]
      set cmd_str [join $arg_list " "]
      puts $fh "  $cmd_str"
    }
    "vcs" {
      set arg_list [list "-ucli" "-licwait" "-60" "-l" "simulate.log"]
      puts $fh "  opts=\"[join $arg_list " "]\""
      puts $fh ""

      set arg_list [list "./$a_sim_vars(s_top)_simv" "\$opts" "-do" "$a_sim_vars(do_filename)"]
      set cmd_str [join $arg_list " "]
      puts $fh "  $cmd_str"
    }
  }
  puts $fh "\}"
}

proc xps_create_udo_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # if udo file exists, return
  if { [file exists $file] } {
    return 0
  }
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id XPS-Tcl-044 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  close $fh
}

proc xps_find_files { src_files_arg filter } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $src_files_arg src_files

  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xps_is_ip $tcl_obj] } {
    set ip_name [file tail $tcl_obj]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter] {
      if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
        if { [get_property {IS_USER_DISABLED} $file] } {
          continue;
        }
      }
      set file [file normalize $file]
      if { $a_sim_vars(b_absolute_path) } {
        set file "[xps_resolve_file_path $file]"
      } else {
        set file "[xps_get_relative_file_path $file $a_sim_vars(s_launch_dir)]"
      }
      lappend src_files $file
    }
  } elseif { [xps_is_fileset $tcl_obj] } {
    set filesets       [list]

    lappend filesets $a_sim_vars(fs_obj)
    set linked_src_set [get_property "SOURCE_SET" $a_sim_vars(fs_obj)]
    if { {} != $linked_src_set } {
      lappend filesets $linked_src_set
    }

    # add block filesets
    set blk_filter "FILESET_TYPE == \"BlockSrcs\""
    foreach blk_fs_obj [get_filesets -filter $blk_filter] {
      lappend filesets $blk_fs_obj
    }

    foreach fs_obj $filesets {
      foreach file [get_files -quiet -of_objects [get_filesets $fs_obj] -filter $filter] {
        if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
          if { [get_property {IS_USER_DISABLED} $file] } {
            continue;
          }
        }
        set file [file normalize $file]
        if { $a_sim_vars(b_absolute_path) } {
          set file "[xps_resolve_file_path $file]"
        } else {
          set file "[xps_get_relative_file_path $file $a_sim_vars(s_launch_dir)]"
        }
        lappend src_files $file
      }
    }
  }
}

proc xps_append_define_generics { def_gen_list tool opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

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

proc xps_get_compiler { file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set compiler ""

  if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } {
    switch -regexp -- $a_sim_vars(s_simulator) {
      "xsim"     { set compiler "vhdl" }
      "modelsim" -
      "questa"   { set compiler "vcom" }
      "ies"      { set compiler "ncvhdl" }
      "vcs"      { set compiler "vhdlan" }
    }
  } elseif { ({Verilog} == $file_type) || ({SystemVerilog} == $file_type) || ({Verilog Header} == $file_type) } {
    switch -regexp -- $a_sim_vars(s_simulator) {
      "xsim"     { set compiler "verilog" }
      "modelsim" -
      "questa"   { set compiler "vlog" }
      "ies"      { set compiler "ncvlog" }
      "vcs"      { set compiler "vlogan" }
    }
  }
  return $compiler
}
 
proc xps_append_compiler_options { tool file_type opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
 
  variable a_sim_vars
  set simulator $a_sim_vars(s_simulator)

  switch $tool {
    "vcom" {
      set s_64bit {-64}
      set arg_list [list $s_64bit]
      lappend arg_list "-93"
      set cmd_str [join $arg_list " "]
      lappend opts $cmd_str
    }
    "vlog" {
      set s_64bit {-64}
      set arg_list [list $s_64bit]
      lappend arg_list "-incr"
      set cmd_str [join $arg_list " "]
      lappend opts $cmd_str
    }
    "ncvhdl" { lappend opts "\$opts_vhd" }
    "vhdlan" { lappend opts "\$opts_ver" }
    "ncvlog" {
      lappend opts "\$opts_ver"
      if { [string equal -nocase $file_type "systemverilog"] } {
        lappend opts "-sv"
      }
    }
    "vlogan" {
      lappend opts "\$opts_ver"
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
      if { [xps_is_fileset $a_sim_vars(sp_tcl_obj)] } {
        set verilog_defines [list]
        set verilog_defines [get_property verilog_define [get_filesets $a_sim_vars(sp_tcl_obj)]]
        if { [llength $verilog_defines] > 0 } {
          xps_append_define_generics $verilog_defines $tool opts
        }
      }
 
      # include dirs
      foreach dir [concat [xps_get_verilog_incl_dirs] [xps_get_verilog_incl_file_dirs {}]] {
        lappend opts "+incdir+\"$dir\""
      }
    }
  }
}
 
proc xps_get_compile_order_libs { } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  variable l_compile_order_files
 
  set libs [list]
  foreach file $l_compile_order_files {
    if { [lsearch -exact [list_property [lindex [get_files -all [list "$file"]] 0]] {LIBRARY}] == -1} {
      continue;
    }
    foreach f [get_files -all [list "$file"]] {
      set library [get_property library $f]
      if { [lsearch -exact $libs $library] == -1 } {
        lappend libs $library
      }
    }
  }
  return $libs
}

proc xps_get_top_library { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compile_order_files

  set tcl_obj $a_sim_vars(sp_tcl_obj)

  # was -of_objects <ip> specified?, fetch current fileset
  if { [xps_is_ip $tcl_obj] } {
    set tcl_obj $a_sim_vars(fs_obj)
  }

  # 1. get the default top library set for the project
  set default_top_library [get_property "DEFAULT_LIB" [current_project]]

  # 2. get the library associated with the top file from the 'top_lib' property on the fileset
  set fileset_top_library [get_property "TOP_LIB" [get_filesets $tcl_obj]]

  # 3. get the library associated with the last file in compile order
  set co_top_library {}
  if { [llength $l_compile_order_files] > 0 } {
    set co_top_library [get_property "LIBRARY" [lindex [get_files -all [list "[lindex $l_compile_order_files end]"]] 0]]
  }

  # 4. if default top library is set and the compile order file library is different
  #    than this default, return the compile order file library
  if { {} != $default_top_library } {
    # compile order library is set and is different then the default
    if { ({} != $co_top_library) && ($default_top_library != $co_top_library) } {
      return $co_top_library
    } else {
      # worst case (default is set but compile order file library is empty or we failed to get the library for some reason)
      return $default_top_library
    }
  }

  # 5. default top library is empty at this point
  #    if fileset top library is set and the compile order file library is different
  #    than this default, return the compile order file library
  if { {} != $fileset_top_library } {
    # compile order library is set and is different then the fileset
    if { ({} != $co_top_library) && ($fileset_top_library != $co_top_library) } {
      return $co_top_library
    } else {
      # worst case (fileset library is set but compile order file library is empty or we failed to get the library for some reason)
      return $fileset_top_library
    }
  }

  # 6. Both the default and fileset library are empty, return compile order library else xilinx default
  if { {} != $co_top_library } {
    return $co_top_library
  }

  return "xil_defaultlib"
}
 
proc xps_contains_verilog {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set design_files $a_sim_vars(l_design_files)

  set b_verilog_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {#}] 0]
    switch $type {
      {VERILOG} {
        set b_verilog_srcs 1
      }
    }
  }
  return $b_verilog_srcs 
}

proc xps_contains_vhdl {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set design_files $a_sim_vars(l_design_files)
  set b_vhdl_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {#}] 0]
    switch $type {
      {VHDL} -
      {VHDL 2008} {
        set b_vhdl_srcs 1
      }
    }
  }

  return $b_vhdl_srcs
}

proc xps_append_generics { generic_list opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts

  foreach element $generic_list {
    set key_val_pair [split $element "="]
    set name [lindex $key_val_pair 0]
    set val  [lindex $key_val_pair 1]
    set str "-g$name="
    if { [string length $val] > 0 } {
      set str $str$val
    }
    lappend opts $str
  }
}

proc xps_verify_ip_status {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set regen_ip [dict create] 
  if { [xps_is_ip $a_sim_vars(sp_tcl_obj)] } {
    set ip [file root [file tail $a_sim_vars(sp_tcl_obj)]]
    # is user-disabled? or auto_disabled? skip
    if { ({0} == [get_property is_enabled [get_files -all ${ip}.xci]]) ||
         ({1} == [get_property is_auto_disabled [get_files -all ${ip}.xci]]) } {
      return
    }
    dict set regen_ip $ip d_targets [get_property delivered_targets [get_ips -quiet $ip]]
    dict set regen_ip $ip generated [get_property is_ip_generated [get_ips -quiet $ip]]
    dict set regen_ip $ip stale [get_property stale_targets [get_ips -quiet $ip]]
  } else {
    foreach ip [get_ips -quiet] {
      # is user-disabled? or auto_disabled? continue
      if { ({0} == [get_property is_enabled [get_files -all ${ip}.xci]]) ||
           ({1} == [get_property is_auto_disabled [get_files -all ${ip}.xci]]) } {
        continue
      }
      dict set regen_ip $ip d_targets [get_property delivered_targets [get_ips -quiet $ip]]
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
    send_msg_id XPS-Tcl-045 "CRITICAL WARNING" \
       "The following IPs have not generated output products yet or have subsequently been updated, making the current\n\
       output products out-of-date. It is strongly recommended that these IPs be re-generated and then this script run again to get a complete output.\n\
       To generate the output products please see 'generate_target' Tcl command.\n\
       $msg_txt"
  }
}

proc xps_print_usage { fh } {
  # Summary: Print usage helper in script file
  # Argument Usage:
  # None
  # Return Value:
  # None 

  variable a_sim_vars

  puts $fh "# Script usage"
  puts $fh "usage()"
  puts $fh "\{"
  puts $fh "  msg=\"Usage: $a_sim_vars(s_script_filename) \[-help\]\\n\\"
  puts $fh "Usage: $a_sim_vars(s_script_filename) \[-noclean_files\]\\n\\"
  puts $fh "Usage: $a_sim_vars(s_script_filename) \[-reset_run\]\\n\\n\\\n\\"
  puts $fh "\[-help\] -- Print help\\n\\n\\"
  puts $fh "\[-noclean_files\] -- Do not remove simulator generated files from the previous run\\n\\n\\"
  puts $fh "\[-reset_run\] -- Recreate simulator setup files and library mappings for a clean run. The generated files\\n\\"
  puts $fh "\\t\\tfrom the previous run will be removed automatically.\\n\""
  puts $fh "  echo -e \$msg"
  puts $fh "  exit 1"
  puts $fh "\}"
  puts $fh ""
}

proc xps_write_libs { fh } {
  # Summary: Print design library mappings helper in script file
  # Argument Usage:
  # File handle
  # Return Value:
  # None 

  variable a_sim_vars

  set simulator $a_sim_vars(s_simulator)
  switch $simulator {
    "modelsim" -
    "questa" {
      puts $fh "# Copy modelsim.ini file"
      puts $fh "copy_setup_file()"
      puts $fh "\{"
      puts $fh "  file=\"modelsim.ini\""
    }
    "ies" -
    "vcs" {
      puts $fh "# Create design library directory paths and define design library mappings in cds.lib"
      puts $fh "create_lib_mappings()"
      puts $fh "\{"

      set libs [list]
      foreach lib [xps_get_compile_order_libs] {
        if {[string length $lib] == 0} { continue; }
        if { ({work} == $lib) && ({vcs} == $simulator) } { continue; }
        lappend libs [string tolower $lib]
      }
      puts $fh "  libs=([join $libs " "])"
      switch -regexp -- $simulator {
        "ies"      { puts $fh "  file=\"cds.lib\"" }
        "vcs"      { puts $fh "  file=\"synopsys_sim.setup\"" }
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
    }
  }

  if { {xsim} == $a_sim_vars(s_simulator) } {
    # no check required
  } else {
    # is -lib_map_path specified and point to valid location?
    if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
      set a_sim_vars(s_lib_map_path) [file normalize $a_sim_vars(s_lib_map_path)]
      set compiled_lib_dir $a_sim_vars(s_lib_map_path)
      if { ![file exists $compiled_lib_dir] } {
        [catch {send_msg_id XPS-Tcl-046 ERROR "Compiled simulation library directory path does not exist:$compiled_lib_dir\n"}]
        puts $fh "  lib_map_path=\"<SPECIFY_COMPILED_LIB_PATH>\""
      } else {
        puts $fh "  lib_map_path=\"$compiled_lib_dir\""
      }
    } else {
      send_msg_id XPS-Tcl-047 WARNING \
         "The pre-compiled simulation library directory path was not specified (-lib_map_path), which may\n\
         cause simulation errors when running this script. Please refer to the generated script header section for more details."
      puts $fh "  lib_map_path=\"<SPECIFY_COMPILED_LIB_PATH>\""
    }
  }
 
  switch -regexp -- $simulator {
    "modelsim" -
    "questa" {
      puts $fh "  src_file=\"\$lib_map_path/\$file\""
      puts $fh "  if \[\[ ! -e \$file \]\]; then"
      puts $fh "    cp \$src_file ."
      puts $fh "  fi"
      puts $fh "\}\n"
    }
    "ies" {
      set file "cds.lib"
      puts $fh "  incl_ref=\"INCLUDE \$lib_map_path/$file\""
      puts $fh "  echo \$incl_ref >> \$file"
    }
    "vcs" {
      set file "synopsys_sim.setup"
      puts $fh "  incl_ref=\"OTHERS=\$lib_map_path/$file\""
      puts $fh "  echo \$incl_ref >> \$file"
    }
  }

  switch -regexp -- $simulator {
    "ies" -
    "vcs" {
      puts $fh ""
      puts $fh "  for (( i=0; i<\$\{#libs\[*\]\}; i++ )); do"
      puts $fh "    lib=\"\$\{libs\[i\]\}\""
      puts $fh "    lib_dir=\"\$dir/\$lib\""
      puts $fh "    if \[\[ ! -e \$lib_dir \]\]; then"
      puts $fh "      mkdir -p \$lib_dir"
    }
  }

  switch -regexp -- $simulator {
    "ies"      { puts $fh "      mapping=\"DEFINE \$lib \$dir/\$lib\"" }
    "vcs"      { puts $fh "      mapping=\"\$lib : \$dir/\$lib\"" }
  }

  switch -regexp -- $simulator {
    "ies" -
    "vcs" {
      puts $fh "      echo \$mapping >> \$file"
      puts $fh "    fi"
      puts $fh "  done"
      puts $fh "\}"
      puts $fh ""
    }
  }
}

proc xps_create_do_file {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set do_file [file join $a_sim_vars(s_launch_dir) $a_sim_vars(do_filename)]
  set fh_do 0
  if {[catch {open $do_file w} fh_do]} {
    send_msg_id XPS-Tcl-048 ERROR "failed to open file to write ($do_file)\n"
  } else {
    switch -regexp -- $a_sim_vars(s_simulator) {
      "ies"      {
        puts $fh_do "set pack_assert_off {numeric_std std_logic_arith}"
        puts $fh_do "\ndatabase -open waves -into waves.shm -default"
        puts $fh_do "probe -create -shm -all -variables -depth 1\n"
        puts $fh_do "run 1000ns"
        puts $fh_do "exit"
      }
      "vcs"      {
        puts $fh_do "quit"
      }
    }
  }
  close $fh_do
}

proc xps_write_xsim_prj { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set top $a_sim_vars(s_top)
  set dir $a_sim_vars(s_launch_dir)

  if { [xps_contains_verilog] } {
    set filename "vlog.prj"
    set file [file normalize [file join $dir $filename]]
    xps_write_prj $file "VERILOG"
  }

  if { [xps_contains_vhdl] } {
    set filename "vhdl.prj"
    set file [file normalize [file join $dir $filename]]
    xps_write_prj $file "VHDL"
  }
}

proc xps_write_prj { file ft } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id XPS-Tcl-049 "Failed to open file to write ($file)\n"
    return 1
  }

  foreach file $a_sim_vars(l_design_files) {
    set fargs         [split $file {#}]
    set type          [lindex $fargs 0]
    set file_type     [lindex $fargs 1] 
    set lib           [lindex $fargs 2] 
    set proj_src_file [lindex $fargs 3]
    set cmd_str       [lindex $fargs 4]
    set ip_file       [lindex $fargs 5]
    set src_file      [lindex $fargs 6]

    if { $ft == $type } {
      set proj_src_filename [file tail $proj_src_file]
      if { $a_sim_vars(b_xport_src_files) } {
        set target_dir $a_sim_vars(s_srcs_dir)
        if { {} != $ip_file } {
          set ip_name [file rootname [file tail $ip_file]]
          set proj_src_filename "$ip_name/$proj_src_filename"
          set ip_dir [file join $a_sim_vars(s_srcs_dir) $ip_name] 
          if { ![file exists $ip_dir] } {
            if {[catch {file mkdir $ip_dir} error_msg] } {
              send_msg_id XPS-Tcl-050 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
              return 1
            }
          }
          set target_dir $ip_dir
        }
        if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
          send_msg_id XPS-Tcl-051 WARNING "failed to copy file '$proj_src_file' to '$a_sim_vars(s_srcs_dir)' : $error_msg\n"
        }
      }
      puts $fh "$cmd_str $src_file"
    }
  }

  if { {VERILOG} == $ft } {
    puts $fh "\nverilog [xps_get_top_library] \"glbl.v\""
    puts $fh "\nnosort"
  }

  close $fh
}

proc xps_write_prj_single_step {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set dir $a_sim_vars(s_launch_dir)

  set filename "run.prj"
  set file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id XPS-Tcl-052 "Failed to open file to write ($file)\n"
    return 1
  }

  foreach file $a_sim_vars(l_design_files) {
    set fargs         [split $file {#}]
    set type          [lindex $fargs 0]
    set file_type     [lindex $fargs 1] 
    set lib           [lindex $fargs 2] 
    set proj_src_file [lindex $fargs 3]
    set cmd_str       [lindex $fargs 4]
    set ip_file       [lindex $fargs 5]
    set src_file      [lindex $fargs 6]

    set proj_src_filename [file tail $proj_src_file]
    if { $a_sim_vars(b_xport_src_files) } {
      set target_dir $a_sim_vars(s_srcs_dir)
      if { {} != $ip_file } {
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "$ip_name/$proj_src_filename"
        set ip_dir [file join $a_sim_vars(s_srcs_dir) $ip_name] 
        if { ![file exists $ip_dir] } {
          if {[catch {file mkdir $ip_dir} error_msg] } {
            send_msg_id XPS-Tcl-053 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
            return 1
          }
        }
        set target_dir $ip_dir
      }
      if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
        send_msg_id XPS-Tcl-054 WARNING "failed to copy file '$proj_src_file' to '$a_sim_vars(s_srcs_dir)' : $error_msg\n"
      }
    }
    puts $fh "$cmd_str $src_file"
  }

  if { [xps_contains_verilog] } {
    puts $fh "\nverilog [xps_get_top_library] \"glbl.v\""
    puts $fh "\nnosort"
  }

  close $fh
}

proc xps_write_do_file_for_compile { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set filename "compile.do"
  if { $a_sim_vars(b_single_step) } {
    set filename "run.do"
  }
   
  set do_file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id XPS-Tcl-055 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  puts $fh "vlib work"
  puts $fh "vlib msim\n"

  set design_libs [xps_get_design_libs] 

  set b_default_lib false
  set default_lib [get_property "DEFAULT_LIB" [current_project]]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    puts $fh "vlib msim/$lib"
    if { $default_lib == $lib } {
      set b_default_lib true
    }
  }
  if { !$b_default_lib } {
    puts $fh "vlib msim/$default_lib"
    puts $fh "vlib msim/$default_lib"
  }

  puts $fh ""

  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    puts $fh "vmap $lib msim/$lib"
  }
  if { !$b_default_lib } {
    puts $fh "vmap $default_lib msim/$default_lib"
  }
  puts $fh ""

  set log "compile.log"
  set redirect_cmd_str "2>&1 | tee -a $log"
  set redirect_cmd_str ""

  set b_first true
  set prev_lib  {}
  set prev_file_type {}
  set b_redirect false
  set b_appended false

  foreach file $a_sim_vars(l_design_files) {
    set fargs    [split $file {#}]

    set type          [lindex $fargs 0]
    set file_type     [lindex $fargs 1]
    set lib           [lindex $fargs 2]
    set proj_src_file [lindex $fargs 3]
    set cmd_str       [lindex $fargs 4]
    set ip_file       [lindex $fargs 5]
    set src_file      [lindex $fargs 6]

    set proj_src_filename [file tail $proj_src_file]
    if { $a_sim_vars(b_xport_src_files) } {
      set target_dir $a_sim_vars(s_srcs_dir)
      if { {} != $ip_file } {
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "$ip_name/$proj_src_filename"
        set ip_dir [file join $a_sim_vars(s_srcs_dir) $ip_name] 
        if { ![file exists $ip_dir] } {
          if {[catch {file mkdir $ip_dir} error_msg] } {
            send_msg_id XPS-Tcl-056 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
            return 1
          }
        }
        set target_dir $ip_dir
      }
      if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
        send_msg_id XPS-Tcl-057 WARNING "failed to copy file '$proj_src_file' to '$a_sim_vars(s_srcs_dir)' : $error_msg\n"
      }
    }

    if { $b_first } {
      set b_first false
      xps_set_initial_cmd $fh $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
    } else {
      if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
        puts $fh "$src_file \\"
        set b_redirect true
      } else {
        puts $fh "$redirect_cmd_str"
        xps_set_initial_cmd $fh $cmd_str $src_file $file_type $lib prev_file_type prev_lib log
        set b_appended true
      }
    }
  }

  if { (!$b_redirect) || (!$b_appended) } {
    puts $fh "$redirect_cmd_str"
  }

  # compile glbl file
  puts $fh "\nvlog -work [xps_get_top_library] \"glbl.v\""

  if { $a_sim_vars(b_single_step) } {
    set cmd_str [xps_get_simulation_cmdline_modelsim]
    puts $fh "\n$cmd_str"
  }
  close $fh
}

proc xps_write_do_file_for_elaborate { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set filename "elaborate.do"
  set do_file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id XPS-Tcl-058 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  switch $a_sim_vars(s_simulator) {
    "modelsim" {
    }
    "questa" {
      set top_lib [xps_get_top_library]
      set arg_list [list "+acc" "-l" "elaborate.log"]
      if { !$a_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64"]
      }

      set vhdl_generics [list]
      set vhdl_generics [get_property "GENERIC" [get_filesets $a_sim_vars(fs_obj)]]
      if { [llength $vhdl_generics] > 0 } {
        xps_append_generics $vhdl_generics arg_list
      }

      set t_opts [join $arg_list " "]

      set arg_list [list]
      if { [xps_contains_verilog] } {
        set arg_list [linsert $arg_list end "-L" "unisims_ver"]
        set arg_list [linsert $arg_list end "-L" "unimacro_ver"]
      }

      # add secureip
      set arg_list [linsert $arg_list end "-L" "secureip"]

      # add design libraries
      set design_libs [xps_get_design_libs]
      foreach lib $design_libs {
        if {[string length $lib] == 0} { continue; }
        lappend arg_list "-L"
        lappend arg_list "$lib"
      }

      set default_lib [get_property "DEFAULT_LIB" [current_project]]
      lappend arg_list "-work"
      lappend arg_list $default_lib

      set d_libs [join $arg_list " "]
      set top_lib [xps_get_top_library]
      set arg_list [list "vopt" $t_opts]
      lappend arg_list "$d_libs"

      set top $a_sim_vars(s_top)
      lappend arg_list "${top_lib}.$top"
      if { [xps_contains_verilog] } {
        lappend arg_list "${top_lib}.glbl"
      }
      lappend arg_list "-o"
      lappend arg_list "${top}_opt"
      set cmd_str [join $arg_list " "]
      puts $fh "  $cmd_str"
    }
  }
  close $fh
}

proc xps_write_do_file_for_simulate { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set dir             $a_sim_vars(s_launch_dir)
  set b_absolute_path $a_sim_vars(b_absolute_path)
  set simulator       $a_sim_vars(s_simulator)

  set filename simulate.do
  set do_file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id XPS-Tcl-059 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }
  set wave_do_filename "wave.do"
  set wave_do_file [file normalize [file join $dir $wave_do_filename]]

  xps_create_wave_do_file $wave_do_file
  set cmd_str {}
  switch $simulator {
    "modelsim" { set cmd_str [xps_get_simulation_cmdline_modelsim] }
    "questa"   { set cmd_str [xps_get_simulation_cmdline_questa] }
  }

  puts $fh "onbreak {quit -f}"
  puts $fh "onerror {quit -f}\n"

  puts $fh "$cmd_str"
  puts $fh "\ndo \{$wave_do_filename\}"
  puts $fh "\nview wave"
  puts $fh "view structure"
  puts $fh "view signals\n"

  set top $a_sim_vars(s_top)
  # create custom UDO file
  set udo_filename $top;append udo_filename ".udo"
  set udo_file [file normalize [file join $dir $udo_filename]]
  xps_create_udo_file $udo_file
  puts $fh "do \{$top.udo\}"
  puts $fh "\nrun 1000ns"

  # add TCL sources
  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\""
  xps_find_files tcl_src_files $filter
  if {[llength $tcl_src_files] > 0} {
    puts $fh ""
    foreach file $tcl_src_files {
      puts $fh "source \{$file\}"
    }
    puts $fh ""
  }
  puts $fh "\nquit -force"
  close $fh
}

proc xps_create_wave_do_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { [file exists $file] } {
    return 0
  }
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id xps-Tcl-060 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  puts $fh "add wave *"

  if { [xps_contains_verilog] } {
    puts $fh "add wave /glbl/GSR"
  }
}

proc xps_get_simulation_cmdline_modelsim {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set simulator $a_sim_vars(s_simulator)
  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set args [list "-voptargs=\"+acc\"" "-t 1ps"]
  if { $a_sim_vars(b_single_step) } {
    set args [linsert $args 1 "-c"]
  }
  if { $a_sim_vars(b_single_step) } {
    set args [linsert $args end "-do \"run 1000ns;quit -force\""]
  }
  set vhdl_generics [list]
  set vhdl_generics [get_property "GENERIC" [get_filesets $a_sim_vars(fs_obj)]]
  if { [llength $vhdl_generics] > 0 } {
    xps_append_generics $vhdl_generics args
  }

  # design contains ax-bfm ip? insert bfm library
  if { [xps_is_axi_bfm_ip] } {
    set simulator_lib [xps_get_simulator_lib_for_bfm]
    if { {} != $simulator_lib } {
      set args [linsert $args end "-pli \"$simulator_lib\""]
    } else {
      [catch {send_msg_id XPS-Tcl-061 ERROR "Failed to locate simulator library from 'XILINX' environment variable."}]
    }
  }
  set t_opts [join $args " "]

  # add simulation libraries
  set args [list]
  if { [xps_contains_verilog] } {
    set args [linsert $args end "-L" "unisims_ver"]
    set args [linsert $args end "-L" "unimacro_ver"]
  }

  # add secureip
  set args [linsert $args end "-L" "secureip"]

  # add design libraries
  set design_libs [xps_get_design_libs]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend args "-L"
    lappend args "$lib"
    #lappend args "[string tolower $lib]"
  }

  set default_lib [get_property "DEFAULT_LIB" [current_project]]
  lappend args "-lib"
  lappend args $default_lib

  set d_libs [join $args " "]
  set top_lib [xps_get_top_library]

  set args [list "vsim" $t_opts]
  lappend args "$d_libs"

  lappend args "${top_lib}.$a_sim_vars(s_top)"
  if { [xps_contains_verilog] } {
    lappend args "${top_lib}.glbl"
  }
  return [join $args " "]
}

proc xps_get_simulation_cmdline_questa {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set simulator $a_sim_vars(s_simulator)

  set args [list "vsim" "-t 1ps"]
  set more_sim_options [string trim [get_property "$simulator.SIMULATE.VSIM.MORE_OPTIONS" $a_sim_vars(fs_obj)]]
  if { {} != $more_sim_options } {
    set args [linsert $args end "$more_sim_options"]
  }

  # design contains ax-bfm ip? insert bfm library
  if { [xps_is_axi_bfm_ip] } {
    set simulator_lib [xps_get_simulator_lib_for_bfm]
    if { {} != $simulator_lib } {
      set args [linsert $args end "-pli \"$simulator_lib\""]
    } else {
      [catch {send_msg_id XPS-Tcl-062 ERROR "Failed to locate simulator library from 'XILINX' environment variable."}]
    }
  }

  set default_lib [get_property "DEFAULT_LIB" [current_project]]
  lappend args "-lib"
  lappend args $default_lib
  lappend args "$a_sim_vars(s_top)_opt"

  set cmd_str [join $args " "]
  return $cmd_str
}

proc xps_write_xelab_cmdline { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set args [list "xelab"]
  lappend args "-wto [get_property ID [current_project]]"
  lappend args "-m64"
  lappend args "--debug typical"
  lappend args "--relax"
  lappend args "--mt auto"

  # --include
  set prefix_ref_dir "false"
  foreach incl_dir [xps_get_verilog_incl_file_dirs $a_sim_vars(global_files_value) $prefix_ref_dir] {
    set dir [string map {\\ /} $incl_dir]
    lappend args "--include \"$dir\""
  }

  # -i
  set unique_incl_dirs [list]
  foreach incl_dir [get_property "INCLUDE_DIRS" $a_sim_vars(fs_obj)] {
    if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
      lappend unique_incl_dirs $incl_dir
      lappend args "-i $incl_dir"
    }
  }

  # -d
  set v_defines [get_property "VERILOG_DEFINE" $a_sim_vars(fs_obj)]
  if { [llength $v_defines] > 0 } {
    foreach element $v_defines {
      set key_val_pair [split $element "="]
      set name [lindex $key_val_pair 0]
      set val  [lindex $key_val_pair 1]
      set str "$name="
      if { [string length $val] > 0 } {
        set str "$str$val"
      }
      lappend args "-d \"$str\""
    }
  }

  # -generic_top
  set v_generics [get_property "GENERIC" $a_sim_vars(fs_obj)]
  if { [llength $v_generics] > 0 } {
    foreach element $v_generics {
      set key_val_pair [split $element "="]
      set name [lindex $key_val_pair 0]
      set val  [lindex $key_val_pair 1]
      set str "$name="
      if { [string length $val] > 0 } {
        set str "$str$val"
      }
      lappend args "-generic_top \"$str\""
    }
  }

  # -L
  set design_libs [xps_get_design_libs]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend args "-L $lib"
  }
  if { [xps_contains_verilog] } {
    lappend args "-L unisims_ver"
    lappend args "-L unimacro_ver"
  }
  lappend args "-L secureip"

  # -snapshot
  lappend args "--snapshot [xps_get_snapshot]"

  # top
  foreach top [xps_get_tops] {
    lappend args "$top"
  }

  # glbl
  if { [xps_contains_verilog] } {
    if { ([lsearch [xps_get_tops] {glbl}] == -1) } {
      set top_lib [xps_get_top_library]
      lappend args "${top_lib}.glbl"
    }
  }

  if { $a_sim_vars(b_single_step) } {
    set filename "run.prj"
    lappend args "-prj $filename"
  }

  if { $a_sim_vars(b_single_step) } {
    lappend args "2>&1 | tee -a run.log"
  } else {
    lappend args "-log elaborate.log"
  }
  puts $fh "  [join $args " "]"
}

proc xps_write_xsim_cmdline { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set args [list "xsim"]
  lappend args [xps_get_snapshot]
  lappend args "-key"
  lappend args "\{[xps_get_obj_key]\}"
  set cmd_file "cmd.tcl"
  xps_write_xsim_tcl_cmd_file $cmd_file
  lappend args "-tclbatch"
  lappend args "$cmd_file"
  if { $a_sim_vars(b_single_step) } {
    lappend args "2>&1 | tee -a run.log"
  } else {
    set log_file "simulate";append log_file ".log"
    lappend args "-log"
    lappend args "$log_file"
  }
  puts $fh "  [join $args " "]"
}

proc xps_get_obj_key {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set mode "Behavioral"
  set fs_name [get_property "NAME" $a_sim_vars(fs_obj)]
  set flow_type "Functional"
  set key $mode;append key {:};append key $fs_name;append key {:};append key $flow_type;append key {:};append key $a_sim_vars(s_top)
  return $key
}

proc xps_write_xsim_tcl_cmd_file { filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id XPS-Tcl-063 ERROR "Failed to open file to write ($file)\n"
    return 1
  }

  puts $fh "set curr_wave \[current_wave_config\]"
  puts $fh "if \{ \[string length \$curr_wave\] == 0 \} \{"
  puts $fh "  if \{ \[llength \[get_objects\]\] > 0\} \{"
  puts $fh "    add_wave /"
  puts $fh "    set_property needs_save false \[current_wave_config\]"
  puts $fh "  \} else \{"
  puts $fh "     send_msg_id Add_Wave-1 WARNING \"No top level signals found. Simulator will start without a wave window. If you want to open a wave window go to 'File->New Waveform Configuration' or type 'create_wave_config' in the TCL console.\""
  puts $fh "  \}"
  puts $fh "\}"
  puts $fh "\nrun 1000ns"

  # add TCL sources
  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\""
  xps_find_files tcl_src_files $filter
  if {[llength $tcl_src_files] > 0} {
    puts $fh ""
    foreach file $tcl_src_files {
       puts $fh "source -notrace \{$file\}"
    }
    puts $fh ""
  }
  puts $fh "quit"
  close $fh
}

proc xps_resolve_uut_name { uut_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $uut_arg uut
  set uut [string map {\\ /} $uut]
  # prepend slash
  if { ![string match "/*" $uut] } {
    set uut "/$uut"
  }
  # append *
  if { [string match "*/" $uut] } {
    set uut "${uut}*"
  }
  # append /*
  if { {/*} != [string range $uut end-1 end] } {
    set uut "${uut}/*"
  }
  return $uut
}

proc xps_get_tops {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set inst_names [list]

  set top $a_sim_vars(s_top)
  set top_lib [xps_get_top_library]
  set assoc_lib "${top_lib}";append assoc_lib {.}

  set top_names [split $top " "]
  if { [llength $top_names] > 1 } {
    foreach name $top_names {
      if { [lsearch $inst_names $name] == -1 } {
        if { ![regexp "^$assoc_lib" $name] } {
          set name ${assoc_lib}$name
        }
        lappend inst_names $name
      }
    }
  } else {
    set name $top_names
    if { ![regexp "^$assoc_lib" $name] } {
      set name ${assoc_lib}$name
    }
    lappend inst_names $name
  }
  return $inst_names
}

proc xps_get_snapshot {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set snapshot $a_sim_vars(s_top)
  return $snapshot
}

proc xps_write_glbl { fh } {
  # Summary:
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

proc xps_write_reset { fh } {
  # Summary: Print reset_run helper in script file
  # Argument Usage:
  # File handle
  # Return Value:
  # None 

  variable a_sim_vars

  puts $fh "# Remove generated data from the previous run and re-create setup files/library mappings"
  puts $fh "reset_run()"
  puts $fh "\{"
  set top $a_sim_vars(s_top)
  set file_list [list]
  set files [list]
  switch -regexp -- $a_sim_vars(s_simulator) {
    "xsim" {
      set file_list [list "xelab.pb" "xsim.jou" "xvhdl.log" "xvlog.log" "compile.log" "elaborate.log" "simulate.log" \
                           "xelab.log" "xsim.log" "run.log" "xsim.dir" "xvhdl.pb" "xvlog.pb" "$a_sim_vars(s_top).wdb"]
    }
    "modelsim" {
      set file_list [list "work" "msim" "compile.log" "simulate.log" "vsim.wlf"]
    }
    "questa" {
      set file_list [list "work" "msim" "compile.log" "simulate.log" "vsim.wlf"]
    }
    "ies" { 
      set file_list [list "INCA_libs" "ncsim.key" "ncvlog.log" "ncvhdl.log" "compile.log" "elaborate.log" "simulate.log" "run.log" "waves.shm"]
    }
    "vcs" {
      set file_list [list "64" "ucli.key" "AN.DB" "csrc" "${top}_simv" "${top}_simv.daidir" \
                          "vlogan.log" "vhdlan.log" "compile.log" "elaborate.log" "simulate.log" \
                          ".vlogansetup.env" ".vlogansetup.args" ".vcs_lib_lock" "scirocco_command.log"]
    }
  }
  set files [join $file_list " "]
  puts $fh "  files_to_remove=($files)"
  puts $fh "  for (( i=0; i<\$\{#files_to_remove\[*\]\}; i++ )); do"
  puts $fh "    file=\"\$\{files_to_remove\[i\]\}\""
  puts $fh "    if \[\[ -e \$file \]\]; then"
  puts $fh "      rm -rf \$file"
  puts $fh "    fi"
  puts $fh "  done"
  puts $fh "\}"
  puts $fh ""
}

proc xps_write_proc_stmt { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars

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
  switch -regexp -- $a_sim_vars(s_simulator) {
    "modelsim" -
    "questa" {
      puts $fh "     copy_setup_file"
    }
    "ies" -
    "vcs" {
      puts $fh "     create_lib_mappings"
    }
  }
  switch -regexp -- $a_sim_vars(s_simulator) {
    "ies" { puts $fh "     touch hdl.var" }
  }
  if { [xps_contains_verilog] } { puts $fh "     copy_glbl_file" }
  puts $fh "  esac"
  puts $fh ""
}

proc xps_write_main { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
 
  puts $fh "# Script info"
  puts $fh "echo -e \"$a_sim_vars(s_script_filename) - Script generated by export_simulation ($version-id)\\n\"\n"
  puts $fh "# Check command line args"
  puts $fh "if \[\[ \$# > 1 \]\]; then"
  puts $fh "  echo -e \"ERROR: invalid number of arguments specified\\n\""
  puts $fh "  usage"
  puts $fh "fi\n"
  puts $fh "if \[\[ (\$# == 1 ) && (\$1 != \"-noclean_files\" && \$1 != \"-reset_run\" && \$1 != \"-help\" && \$1 != \"-h\") \]\]; then"
  puts $fh "  echo -e \"ERROR: unknown option specified '\$1' (type \"$a_sim_vars(s_script_filename) -help\" for for more info)\""
  puts $fh "  exit 1"
  puts $fh "fi"
  puts $fh ""
  puts $fh "if \[\[ (\$1 == \"-help\" || \$1 == \"-h\") \]\]; then"
  puts $fh "  usage"
  puts $fh "fi\n"
  puts $fh "# Launch script"
  puts $fh "run \$1"
}

proc xps_is_axi_bfm {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  foreach ip [get_ips -quiet] {
    set ip_def [lindex [split [get_property "IPDEF" [get_ips -quiet $ip]] {:}] 2]
    set value [get_property "VLNV" [get_ipdefs -regexp .*${ip_def}.*]]
    if { ([regexp -nocase {axi_bfm} $value]) || ([regexp -nocase {processing_system7} $value]) } {
      return 1
    }
  }
  return 0
}

proc xps_get_plat {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set platform {}
  set os $::tcl_platform(platform)
  if { {windows}   == $os } { set platform "win32" }
  if { {windows64} == $os } { set platform "win64" }
  if { {unix} == $os } {
    if { {x86_64} == $::tcl_platform(machine) } {
      set platform "lnx64"
    } else {
      set platform "lnx32"
    }
  }
  return $platform
}

proc xps_get_bfm_lib { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set simulator_lib {}
  set xil           $::env(XILINX_VIVADO)
  set path_sep      {;}
  set lib_extn      {.dll}
  set platform      [xps_get_plat]

  if {$::tcl_platform(platform) == "unix"} { set path_sep {:} }
  if {$::tcl_platform(platform) == "unix"} { set lib_extn {.so} }

  set lib_name {}
  switch -regexp -- $simulator {
    "ies"      { set lib_name "libxil_ncsim" }
    "vcs"      { set lib_name "libxil_vcs" }
  }

  set lib_name $lib_name$lib_extn
  if { {} != $xil } {
    append platform ".o"
    set lib_path {}
    foreach path [split $xil $path_sep] {
      set file [file normalize [file join $path "lib" $platform $lib_name]]
      if { [file exists $file] } {
        set simulator_lib $file
        break
      }
    }
  } else {
    send_msg_id XPS-Tcl-064 ERROR "Environment variable 'XILINX_VIVADO' is not set!"
  }
  return $simulator_lib
}

proc xps_get_incl_files_from_ip { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set incl_files [list]
  set ip_name [file tail $tcl_obj]
  set filter "FILE_TYPE == \"Verilog Header\""
  set vh_files [get_files -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    if { $a_sim_vars(b_absolute_path) } {
      set file "[xps_resolve_file_path $file]"
    } else {
      if { $a_sim_vars(b_xport_src_files) } {
        set file "\$ref_dir/incl"
      } else {
        set file "\$ref_dir/[xps_get_relative_file_path $file $a_sim_vars(s_launch_dir)]"
      }
    }
    lappend incl_files $file
  }
  return $incl_files
}

proc xps_get_verilog_incl_file_dirs { global_files_str { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set launch_dir $a_sim_vars(s_launch_dir)
  set dir_names [list]
  set vh_files [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)

  if { [xps_is_ip $tcl_obj] } {
    set vh_files [xps_get_incl_files_from_ip $tcl_obj]
  } else {
    set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"Verilog Header\""
    set vh_files [get_files -all -quiet -filter $filter]
  }

  if { {} != $global_files_str } {
    set global_files [split $global_files_str { }]
    foreach g_file $global_files {
      set g_file [string trim $g_file {\"}]
      lappend vh_files [get_files -quiet -all $g_file]
    }
  }

  foreach vh_file $vh_files {
    set vh_file [extract_files -files [list "$vh_file"] -base_dir $launch_dir/ip_files]
    set dir [file normalize [file dirname $vh_file]]

    if { $a_sim_vars(b_xport_src_files) } {
      set export_dir $a_sim_vars(s_incl_dir)
      if {[catch {file copy -force $vh_file $export_dir} error_msg] } {
        send_msg_id XPS-Tcl-065 WARNING "Failed to copy file '$vh_file' to '$export_dir' : $error_msg\n"
      }
    }

    if { $a_sim_vars(b_absolute_path) } {
      set dir "[xps_resolve_file_path $dir]"
    } else {
      if { $ref_dir } {
        if { $a_sim_vars(b_xport_src_files) } {
          set dir "\$ref_dir/incl"
        } else {
          set dir "\$ref_dir/[xps_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
        }
      }
    }
    lappend dir_names $dir
  }

  if {[llength $dir_names] > 0} {
    return [lsort -unique $dir_names]
  }
  return $dir_names
}

proc xps_get_verilog_incl_dirs { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set dir_names [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  set incl_dir_str {}

  if { [xps_is_ip $tcl_obj] } {
    set incl_dir_str [xps_get_incl_dirs_from_ip $tcl_obj]
    set incl_dirs [split $incl_dir_str " "]
  } else {
    set incl_dir_str [xps_resolve_incldir [get_property "INCLUDE_DIRS" [get_filesets $tcl_obj]]]
    set incl_dirs [split $incl_dir_str "#"]
  }

  foreach vh_dir $incl_dirs {
    set dir [file normalize $vh_dir]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[xps_resolve_file_path $dir]"
    } else {
      if { $a_sim_vars(b_xport_src_files) } {
        set dir "\$ref_dir/incl"
      } else {
        set dir "\$ref_dir/[xps_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
      }
    }
    lappend dir_names $dir
  }
  return [lsort -unique $dir_names]
}

proc xps_resolve_incldir { incl_dirs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set resolved_path {}
  set incl_dirs [string map {\\ /} $incl_dirs]
  set path_elem {}
  set comps [split $incl_dirs { }]
  foreach elem $comps {
    # path element starts slash (/)? or drive (c:/)?
    if { [string match "/*" $elem] || [regexp {^[a-zA-Z]:} $elem] } {
      if { {} != $path_elem } {
        # previous path is complete now, add hash and append to resolved path string
        set path_elem "$path_elem#"
        append resolved_path $path_elem
      }
      # setup new path
      set path_elem "$elem"
    } else {
      # sub-dir with space, append to current path
      set path_elem "$path_elem $elem"
    }
  }
  append resolved_path $path_elem
  return $resolved_path
}

proc xps_get_incl_dirs_from_ip { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set launch_dir $a_sim_vars(s_launch_dir)
  set ip_name [file tail $tcl_obj]
  set incl_dirs [list]
  set filter "FILE_TYPE == \"Verilog Header\""
  set vh_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    set file [extract_files -files [list "$file"] -base_dir $launch_dir/ip_files]
    set dir [file dirname $file]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[xps_resolve_file_path $dir]"
    } else {
      if { $a_sim_vars(b_xport_src_files) } {
        set dir "\$ref_dir/incl"
      } else {
        set dir "\$ref_dir/[xps_get_relative_file_path $dir $a_sim_vars(s_launch_dir)]"
      }
    }
    lappend incl_dirs $dir
  }
  return $incl_dirs
}

proc xps_get_global_include_files { incl_file_paths_arg incl_files_arg { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $incl_file_paths_arg incl_file_paths
  upvar $incl_files_arg      incl_files

  variable a_sim_vars
  set filesets       [list]
  set dir            $a_sim_vars(s_launch_dir)
  set linked_src_set [get_property "SOURCE_SET" $a_sim_vars(fs_obj)]
  set incl_files_set [list]

  if { {} != $linked_src_set } {
    lappend filesets $linked_src_set
  }
  lappend filesets $a_sim_vars(fs_obj)
  set filter "FILE_TYPE == \"Verilog\" || FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog Template\""
  foreach fs_obj $filesets {
    set vh_files [get_files -quiet -of_objects [get_filesets $fs_obj] -filter $filter]
    foreach file $vh_files {
      # skip if not marked as global include
      if { ![get_property "IS_GLOBAL_INCLUDE" [lindex [get_files -quiet [list "$file"]] 0]] } {
        continue
      }
      # skip if marked user disabled
      if { [get_property "IS_USER_DISABLED" [lindex [get_files -quiet [list "$file"]] 0]] } {
        continue
      }
      set file [file normalize [string map {\\ /} $file]]
      if { [lsearch -exact $incl_files_set $file] == -1 } {
        lappend incl_files_set $file
        lappend incl_files     $file
        set incl_file_path [file normalize [string map {\\ /} [file dirname $file]]]
        if { $a_sim_vars(b_absolute_path) } {
          set incl_file_path "[xps_resolve_file_path $incl_file_path]"
        } else {
          if { $ref_dir } {
            if { $a_sim_vars(b_xport_src_files) } {
              set incl_file_path "\$ref_dir/incl"
            } else {
              set incl_file_path "\$ref_dir/[xps_get_relative_file_path $incl_file_path $dir]"
            }
          }
        }
        lappend incl_file_paths $incl_file_path
      }
    }
  }
}

proc xps_get_global_include_file_cmdstr { incl_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $incl_files_arg incl_files
  variable a_sim_vars
  set file_str [list]
  set launch_dir $a_sim_vars(s_launch_dir)
  foreach file $incl_files {
    set file [extract_files -files [list "$file"] -base_dir $launch_dir/ip_files]
    lappend file_str "\"$file\""
  }
  return [join $file_str " "]
}

proc xps_is_global_include_file { global_files_str file_to_find } {
  # Summary:
  # Argument Usage:
  # Return Value:

  foreach g_file [split $global_files_str { }] {
    set g_file [string trim $g_file {\"}]
    if { [string compare $g_file $file_to_find] == 0 } {
      return true
    }
  }
  return false
}

proc xps_is_axi_bfm_ip {} {
  # Summary: Finds VLNV property value for the IP and checks to see if the IP is AXI_BFM
  # Argument Usage:
  # Return Value:
  # true (1) if specified IP is axi_bfm, false (0) otherwise

  foreach ip [get_ips -quiet] {
    set ip_def [lindex [split [get_property "IPDEF" [get_ips -quiet $ip]] {:}] 2]
    set value [get_property "VLNV" [get_ipdefs -regexp .*${ip_def}.*]]
    if { ([regexp -nocase {axi_bfm} $value]) || ([regexp -nocase {processing_system7} $value]) } {
      return 1
    }
  }
  return 0
}

}
