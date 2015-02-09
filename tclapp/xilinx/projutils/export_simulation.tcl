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
  # [-simulator <arg> = all]: Simulator for which the simulation script will be created (value=all|xsim|modelsim|questa|ies|vcs)
  # [-of_objects <arg> = None]: Export simulation script for the specified object
  # [-lib_map_path <arg> = Empty]: Precompiled simulation library directory path. If not specified, then please follow the instructions in the generated script header to manually provide the simulation library mapping information.
  # [-script_name <arg> = top_module.sh/.bat]: Output shell script filename. If not specified, then file with a default name will be created.
  # [-absolute_path]: Make all file paths absolute wrt the reference directory
  # [-single_step]: Generate script to launch all steps in one step
  # [-ip_netlist <arg> = verilog]: Select the IP netlist for the compile order (value=verilog|vhdl)
  # [-directory <arg> = export_sim]: Directory where the simulation script will be exported
  # [-export_source_files]: Copy design files to output directory
  # [-reset_config_options]: Regenerate 'expsim_options.cfg' file with the default options.
  # [-32bit]: Perform 32bit compilation
  # [-force]: Overwrite previous files

  # Return Value:
  # None

  # Categories: simulation, xilinxtclstore

  variable a_sim_vars
  xps_init_vars
  set a_sim_vars(options) [split $args " "]

  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-of_objects"               { incr i;set a_sim_vars(sp_of_objects) [lindex $args $i] }
      "-32bit"                    { set a_sim_vars(b_32bit) 1 }
      "-absolute_path"            { set a_sim_vars(b_absolute_path) 1 }
      "-single_step"              { set a_sim_vars(b_single_step) 1 }
      "-ip_netlist"               { incr i;set a_sim_vars(s_ip_netlist) [string tolower [lindex $args $i]];set a_sim_vars(b_ip_netlist) 1 }
      "-export_source_files"      { set a_sim_vars(b_xport_src_files) 1 }
      "-reset_config_options"     { set a_sim_vars(b_reset_config_opts) 1 }
      "-lib_map_path"             { incr i;set a_sim_vars(s_lib_map_path) [lindex $args $i] }
      "-script_name"              { incr i;set a_sim_vars(s_script_filename) [lindex $args $i] }
      "-force"                    { set a_sim_vars(b_overwrite) 1 }
      "-simulator"                { incr i;set a_sim_vars(s_simulator) [string tolower [lindex $args $i]] }
      "-directory"                { incr i;set a_sim_vars(s_xport_dir) [lindex $args $i] }
      default {
        if { [regexp {^-} $option] } {
          send_msg_id exportsim-Tcl-003 ERROR "Unknown option '$option', please type 'export_simulation -help' for usage info.\n"
          return
        }
      }
    }
  }

  if { [xps_invalid_options] } { return }
  xps_set_target_simulator
  if { [xps_create_rundir] } { return }
  xps_readme
  xps_extract_ip_files
  if { [xps_set_target_obj] } { return }
  if { ([lsearch $a_sim_vars(options) {-of_objects}] != -1) && ([llength $a_sim_vars(sp_tcl_obj)] == 0) } {
    send_msg_id exportsim-Tcl-006 ERROR "Invalid object specified. The object does not exist.\n"
    return 1
  }
  xps_gen_mem_files
  set data_files [list]
  xps_get_compile_order_files data_files
  xps_set_script_filename
  xps_export_config
  if { [xps_write_sim_script $data_files] } { return }

  set readme_file [file join $a_sim_vars(s_xport_dir) "README.txt"]
  send_msg_id exportsim-Tcl-030 INFO \
    "Please see readme file for instructions on how to use the generated script: '$readme_file'\n"

  return
}
}

namespace eval ::tclapp::xilinx::projutils {
proc xps_init_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set a_sim_vars(s_simulator)         "all"
  set a_sim_vars(s_xport_dir)         "export_sim"
  set a_sim_vars(s_simulator_name)    ""
  set a_sim_vars(b_xsim_specified)    0
  set a_sim_vars(s_lib_map_path)      ""
  set a_sim_vars(s_script_filename)   ""
  set a_sim_vars(s_ip_netlist)        "verilog"
  set a_sim_vars(b_ip_netlist)        0
  set a_sim_vars(ip_filename)         ""
  set a_sim_vars(b_extract_ip_sim_files) 0
  set a_sim_vars(b_32bit)             0
  set a_sim_vars(sp_of_objects)       {}
  set a_sim_vars(b_is_ip_object_specified)      0
  set a_sim_vars(b_is_fs_object_specified)      0
  set a_sim_vars(b_absolute_path)     0             
  set a_sim_vars(b_single_step)       0             
  set a_sim_vars(b_xport_src_files)   0             
  set a_sim_vars(b_reset_config_opts) 0             
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
  set a_sim_vars(opts_file)           "export_sim_options.cfg"

  variable l_compile_order_files      [list]
  variable l_design_files             [list]
  variable l_simulators               [list xsim modelsim questa ies vcs]
  variable l_target_simulator         [list]

  variable l_valid_simulator_types    [list]
  set l_valid_simulator_types         [list all xsim modelsim questa ies vcs vcs_mx ncsim]
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

proc xps_set_target_simulator {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_simulators
  variable l_target_simulator
  if { {all} == $a_sim_vars(s_simulator) } {
    foreach simulator $l_simulators {
      if { ($::tcl_platform(platform) != "unix") && ({ies} == $simulator || {vcs} == $simulator)} {
        continue
      }
      lappend l_target_simulator $simulator
    }
  } else {
    if { {vcs_mx} == $a_sim_vars(s_simulator) } {
      set $a_sim_vars(s_simulator) "vcs"
    }
    if { {ncsim} == $a_sim_vars(s_simulator) } {
      set $a_sim_vars(s_simulator) "ies"
    }
    lappend l_target_simulator $a_sim_vars(s_simulator)
  }

  if { ([llength $l_target_simulator] == 1) && ({xsim} == [lindex $l_target_simulator 0]) } {
    set a_sim_vars(b_xsim_specified) 1
  }
}

proc xps_invalid_options {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_valid_simulator_types
  variable l_valid_ip_netlist_types
  if { {} != $a_sim_vars(s_script_filename) } {
    set extn [string tolower [file extension $a_sim_vars(s_script_filename)]]
    if {($::tcl_platform(platform) == "unix") && ({.sh} != $extn) } {
      [catch {send_msg_id exportsim-Tcl-004 ERROR "Invalid script file extension '$extn' specified. Please provide script filename with the '.sh' extension.\n"} err]
      return 1
    }
    if {($::tcl_platform(platform) != "unix") && ({.bat} != $extn) } {
      [catch {send_msg_id exportsim-Tcl-004 ERROR "Invalid script file extension '$extn' specified. Please provide script filename with the '.bat' extension.\n"} err]
      return 1
    }
  }

  if { [lsearch -exact $l_valid_simulator_types $a_sim_vars(s_simulator)] == -1 } {
    send_msg_id exportsim-Tcl-004 ERROR "Invalid simulator type specified. Please type 'export_simulation -help' for usage info.\n"
    return 1
  }

  if {($::tcl_platform(platform) != "unix") && ({ies} == $a_sim_vars(s_simulator) || {vcs} == $a_sim_vars(s_simulator)) } {
    send_msg_id exportsim-Tcl-004 ERROR "Export simulation is not supported for '$simulator' on this platform.\n"
    return 1
  }

  if { $a_sim_vars(b_ip_netlist) } {
    if { [lsearch -exact $l_valid_ip_netlist_types $a_sim_vars(s_ip_netlist)] == -1 } {
      send_msg_id exportsim-Tcl-005 ERROR "Invalid ip netlist type specified. Please type 'export_simulation -help' for usage info.\n"
      return 1
    }
  }
  switch $a_sim_vars(s_simulator) {
    "questa" -
    "vcs" {
      if { $a_sim_vars(b_ip_netlist) } {
        if { ($a_sim_vars(b_single_step)) && ({vhdl} == $a_sim_vars(s_ip_netlist)) } {
          send_msg_id exportsim-Tcl-007 ERROR \
            "Single step simulation flow is not applicable for IP's containing VHDL netlist. Please select Verilog netlist for this simulator.\n"
          return 1
        }
      }
    }
  }
  return 0
}

proc xps_extract_ip_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  variable l_target_simulator
  if { $a_sim_vars(b_xsim_specified) } {
    return
  }

  if { ![get_property enable_core_container [current_project]] } {
    return
  }
 
  set a_sim_vars(b_extract_ip_sim_files) [get_property extract_ip_sim_files [current_project]]

  if { $a_sim_vars(b_extract_ip_sim_files) } {
    foreach ip [get_ips] {
      set xci_ip_name "${ip}.xci"
      set xcix_ip_name "${ip}.xcix"
      set xcix_file_path [get_property core_container [get_files -all ${xci_ip_name}]] 
      if { {} != $xcix_file_path } {
        [catch {rdi::extract_ip_sim_files -of_objects [get_files -all ${xcix_ip_name}]} err]
      }
    }
  }
}

proc xps_invalid_flow_options {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  switch $a_sim_vars(s_simulator) {
    "questa" -
    "vcs" {
      if { ($a_sim_vars(b_single_step)) && ([xps_contains_vhdl]) } {
        [catch {send_msg_id exportsim-Tcl-008 ERROR \
          "Design contains VHDL sources. The single step simulation flow is not applicable for this simulator. Please remove the '-single_step' switch and try again.\n"}]
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
  variable l_target_simulator
  set dir [file normalize [string map {\\ /} $a_sim_vars(s_xport_dir)]]
  if { ! [file exists $dir] } {
    if {[catch {file mkdir $dir} error_msg] } {
      send_msg_id exportsim-Tcl-009 ERROR "failed to create the directory ($dir): $error_msg\n"
      return 1
    }
  }
  if { {all} == $a_sim_vars(s_simulator) } {
    foreach simulator $l_target_simulator {
      set sim_dir [file join $dir $simulator]
      if { [xps_create_dir $sim_dir] } {
        return 1
      }
    }
  } else {
    set sim_dir [file join $dir $a_sim_vars(s_simulator)]
    if { [xps_create_dir $sim_dir] } {
      return 1
    }
  }
  set a_sim_vars(s_xport_dir) $dir
  return 0
}

proc xps_readme {} {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:

  variable a_sim_vars
  set fh 0
  set filename "README.txt"
  set file [file join $a_sim_vars(s_xport_dir) $filename]
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-030 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  set curr_time   [clock format [clock seconds]]
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]

  puts $fh "# $product (TM) $version_id\n#"
  puts $fh "# $filename (generated by export_simulation on $curr_time)"
  puts $fh "#\n# This file explains the usage of export_simulation, directory structure and exported files\n#"
  puts $fh "1. Usage"
  puts $fh ""
  puts $fh "To run simulation, cd to the ./<simulator> directory and execute the generated script."
  puts $fh "For example:-"
  puts $fh ""
  puts $fh "% cd questa"
  set extn ".bat"
  if {$::tcl_platform(platform) == "unix"} { set extn ".sh" }
  puts $fh "% ./top$extn"
  puts $fh ""
  puts $fh "The export simulation flow requires the Xilinx pre-compiled simulation library components"
  puts $fh "for the simulator. These components are referred using the -lib_map_path switch. If this"
  puts $fh "switch is specified, export_simulation will automatically point to this library path in"
  puts $fh "the generated script and update/copy the simulator script file in the exported directory."
  puts $fh ""
  puts $fh "If this switch is not specified, the pre-compiled simulation library information is not"
  puts $fh "included in the exported scripts and this may cause simulation errors when running this"
  puts $fh "script. Please refer to the generated script header 'Prerequisite' section for more details."
  puts $fh ""
  puts $fh "2. Directory Structure"
  puts $fh ""
  puts $fh "By default, if the -directory switch is not specified, export_simulation will create the"
  puts $fh "following directory structure:-"
  puts $fh ""
  puts $fh "<current_working_directory>/export_sim/<simulator>"
  puts $fh ""
  puts $fh "For example, if the current working directory is /tmp/test, then the export_simulation will"
  puts $fh "will create the following directory path:-"
  puts $fh ""
  puts $fh "/tmp/test/export_sim/questa"
  puts $fh ""
  puts $fh "If -directory switch is specified, export_simulation will create a simulator sub-directory"
  puts $fh "under the specified directory path."
  puts $fh ""
  puts $fh "For example, the 'export_simulation -directory /tmp/test/my_test_area/func_sim' command will"
  puts $fh "create the following directory:-"
  puts $fh ""
  puts $fh "/tmp/test/my_test_area/func_sim/questa"
  puts $fh ""
  puts $fh "By default, if -simulator is not specified, export_simulation will create a simulator sub-directory"
  puts $fh "for each simulator and export the files for each simulator in this sub-directory respectively."
  puts $fh ""
  puts $fh "IMPORTANT: Please note that the simulation library path must be specified manually in the generated"
  puts $fh "script for the respective simulator. Please refer to the generated script header 'Prerequisite'"
  puts $fh "section for more details."
  puts $fh ""
  puts $fh "3. Exported script and files"
  puts $fh ""
  puts $fh "Export simulation will create the driver shell script, setup files and copy the design sources in"
  puts $fh "the output directory path."
  puts $fh ""
  puts $fh "By default, when the -script_name switch is not specified, export_simulation will create the following"
  puts $fh "script name:-"
  puts $fh ""
  puts $fh "<simulation_top>.sh  (Unix)"
  puts $fh "<simulation_top>.bat (Windows)"
  puts $fh ""
  puts $fh "When exporting the files for an IP using the -of_objects switch, export_simulation will create the"
  puts $fh "following script name:-"
  puts $fh ""
  puts $fh "<ip-name>.sh  (Unix)"
  puts $fh "<ip-name>.bat (Windows)"
  puts $fh ""
  puts $fh "Export simulation will create the setup files for the target simulator specified with the -simulator switch."
  puts $fh ""
  puts $fh "For example, if the target simulator is \"ies\", export_simulation will create the 'cds.lib', 'hdl.var' and design"
  puts $fh "library diectories and mappings in the 'cds.lib' file.\n"
  puts $fh "4. Running simulation\n"
  puts $fh "To launch simulation, cd to the simulator directory (<simulator>) and type the generated script file name. The script"
  puts $fh "will launch 3-step flow for compiling, elaborating and simulating the design. If '-single_step' switch is specified,"
  puts $fh "the script will execute 1-step flow for compiling, elaborating and simulating the design.\n"

  close $fh
}

proc xps_create_dir { dir } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:

  if { [file exists $dir] } {
    #set files [glob -nocomplain -directory $dir *]
    #foreach file_path $files {
    #  if {[catch {file delete -force $file_path} error_msg] } {
    #    send_msg_id exportsim-Tcl-010 ERROR "failed to delete file ($file_path): $error_msg\n"
    #    return 1
    #  }
    #}
  } else {
    if {[catch {file mkdir $dir} error_msg] } {
      send_msg_id exportsim-Tcl-011 ERROR "failed to create the directory ($dir): $error_msg\n"
      return 1
    }
  }
  return 0
}

proc xps_create_srcs_dir { dir } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:
  
  variable a_sim_vars
  set srcs_dir {}
  if { $a_sim_vars(b_xport_src_files) } {
    set srcs_dir [file normalize [file join $dir "srcs"]]
    if {[catch {file mkdir $srcs_dir} error_msg] } {
      send_msg_id exportsim-Tcl-012 ERROR "failed to create the directory ($srcs_dir): $error_msg\n"
      return 1
    }
    set incl_dir [file normalize [file join $srcs_dir "incl"]]
    if {[catch {file mkdir $incl_dir} error_msg] } {
      send_msg_id exportsim-Tcl-013 ERROR "failed to create the directory ($incl_dir): $error_msg\n"
      return 1
    }
  }
  return $srcs_dir
}

proc xps_get_simulator_pretty_name { name } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:
 
  set pretty_name {}
  switch -regexp -- $name {
    "xsim"     { set pretty_name "Vivado Simulator" }
    "modelsim" { set pretty_name "ModelSim Simulator" }
    "questa"   { set pretty_name "Questa Advanced Simulator" }
    "ies"      { set pretty_name "Incisive Enterprise Simulator" }
    "vcs"      { set pretty_name "Verilog Compiler Simulator" }
  }
  return $pretty_name
}

proc xps_set_target_obj {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set a_sim_vars(b_is_ip_object_specified) 0
  set a_sim_vars(b_is_fs_object_specified) 0
  if { {} != $a_sim_vars(sp_of_objects) } {
    set a_sim_vars(b_is_ip_object_specified) [xps_is_ip $a_sim_vars(sp_of_objects)]
    set a_sim_vars(b_is_fs_object_specified) [xps_is_fileset $a_sim_vars(sp_of_objects)]
  }
  if { {1} == $a_sim_vars(b_is_ip_object_specified) } {
    set comp_file $a_sim_vars(sp_of_objects)
    if { {.xci} != [file extension $comp_file] } {
      set comp_file ${comp_file}.xci
    }
    set a_sim_vars(sp_tcl_obj) [get_files -all -quiet [list "$comp_file"]]
    set a_sim_vars(s_top) [file root [file tail $a_sim_vars(sp_tcl_obj)]]
    xps_verify_ip_status
  } else {
    if { $a_sim_vars(b_is_managed) } {
      set ips [get_ips -quiet]
      if {[llength $ips] == 0} {
        send_msg_id exportsim-Tcl-014 INFO "No IP's found in the current project.\n"
        return 1
      }
      send_msg_id exportsim-Tcl-015 ERROR "No IP source object specified. Please type 'export_simulation -help' for usage info.\n"
      return 1
    } else {
      if { $a_sim_vars(b_is_fs_object_specified) } {
        set fs_type [get_property fileset_type [get_filesets $a_sim_vars(sp_of_objects)]]
        set fs_of_obj [get_property name [get_filesets $a_sim_vars(sp_of_objects)]]
        set fs_active {}
        if { $fs_type == "DesignSrcs" } {
          set fs_active [get_property name [current_fileset]]
        } elseif { $fs_type == "SimulationSrcs" } {
          set fs_active [get_property name [get_filesets $a_sim_vars(fs_obj)]]
        } else {
          send_msg_id exportsim-Tcl-015 ERROR "Invalid simulation fileset '$fs_of_obj' of type '$fs_type' specified with the -of_objects switch. Please specify a 'current' simulation or design source fileset.\n"
          return 1
        }
        
        # must work on the current fileset
        if { $fs_of_obj != $fs_active } {
          [catch {send_msg_id exportsim-Tcl-015 ERROR \
            "The specified fileset '$fs_of_obj' is not 'current' (current fileset is '$fs_active'). Please set '$fs_of_obj' as current fileset using the 'current_fileset' Tcl command and retry this command.\n"} err]
          return 1
        }

        # -of_objects specifed, set default active source set
        if { $fs_type == "DesignSrcs" } {
          set a_sim_vars(fs_obj) [current_fileset]
          set a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj)
          xps_verify_ip_status
          update_compile_order -fileset $a_sim_vars(sp_tcl_obj)
          set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
        } elseif { $fs_type == "SimulationSrcs" } {
          set a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj)
          xps_verify_ip_status
          update_compile_order -fileset $a_sim_vars(sp_tcl_obj)
          set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
        }
      } else {
        # no -of_objects specifed, set default active simset
        set a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj)
        xps_verify_ip_status
        update_compile_order -fileset $a_sim_vars(sp_tcl_obj)
        set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
      }
    }
  }
  return 0
}

proc xps_gen_mem_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable s_embedded_files_filter
  variable l_target_simulator
  if { [xps_is_fileset $a_sim_vars(sp_tcl_obj)] } {
    set embedded_files [get_files -all -quiet -filter $s_embedded_files_filter]
    if { [llength $embedded_files] > 0 } {
      send_msg_id exportsim-Tcl-016 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
      foreach simulator $l_target_simulator {
        set dir [file join $a_sim_vars(s_xport_dir) $simulator] 
        generate_mem_files $dir
      }
    }
  }
}

proc xps_get_compile_order_files { data_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compile_order_files
  variable s_data_files_filter
  variable s_non_hdl_data_files_filter
  upvar $data_files_arg data_files
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xps_is_ip $tcl_obj] } {
    set ip_filename [file tail $tcl_obj]
    set l_compile_order_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]]
    set ip_filter "FILE_TYPE == \"IP\""
    set ip_name [file tail $tcl_obj]
    set data_files [concat $data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_data_files_filter]]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_non_hdl_data_files_filter] {
      if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
        if { [get_property {IS_USER_DISABLED} $file] } {
          continue;
        }
      }
      lappend data_files $file
    }
  } elseif { [xps_is_fileset $tcl_obj] } {
    set used_in_val "simulation"
    switch [get_property "FILESET_TYPE" [get_filesets $tcl_obj]] {
      "DesignSrcs"     { set used_in_val "synthesis" }
      "SimulationSrcs" { set used_in_val "simulation"}
      "BlockSrcs"      { set used_in_val "synthesis" }
    }
    set l_compile_order_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $tcl_obj]]
    xps_export_fs_data_files $s_data_files_filter data_files
    xps_export_fs_non_hdl_data_files data_files
  } else {
    send_msg_id exportsim-Tcl-017 INFO "Unsupported object source: $tcl_obj\n"
    return 1
  }
}

proc xps_export_fs_non_hdl_data_files { data_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable s_non_hdl_data_files_filter
  upvar $data_files_arg data_files
  foreach file [get_files -all -quiet -of_objects [get_filesets $a_sim_vars(fs_obj)] -filter $s_non_hdl_data_files_filter] {
    if { [lsearch -exact [list_property $file] {IS_USER_DISABLED}] != -1 } {
      if { [get_property {IS_USER_DISABLED} $file] } {
        continue;
      }
    }
    lappend data_files $file
  }
}

proc xps_process_cmd_str { simulator dir } {
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
  set a_sim_vars(l_design_files) [xps_uniquify_cmd_str [xps_get_files $simulator $dir global_files_str]]
  if { $b_lang_updated } {
    set_property simulator_language $curr_lang [current_project]
  }
  set a_sim_vars(global_files_value) $global_files_str
}

proc xps_get_files { simulator launch_dir global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $global_files_str_arg global_files_str
  variable a_sim_vars
  variable l_compile_order_files
  set files          [list]
  set tcl_obj        $a_sim_vars(sp_tcl_obj)
  set linked_src_set {}
  if { ([xps_is_fileset $a_sim_vars(sp_tcl_obj)]) && ({SimulationSrcs} == [get_property fileset_type $a_sim_vars(fs_obj)]) } {
    set linked_src_set [get_property "SOURCE_SET" $a_sim_vars(fs_obj)]
  }
  set target_lang    [get_property "TARGET_LANGUAGE" [current_project]]
  set src_mgmt_mode  [get_property "SOURCE_MGMT_MODE" [current_project]]
  set incl_file_paths [list]
  set incl_files      [list]

  send_msg_id exportsim-Tcl-018 INFO "Finding global include files..."
  xps_get_global_include_files $launch_dir incl_file_paths incl_files

  set global_incl_files $incl_files
  set global_files_str [xps_get_global_include_file_cmdstr $launch_dir incl_files]

  send_msg_id exportsim-Tcl-019 INFO "Finding include directories and verilog header directory paths..."
  set l_incl_dirs_opts [list]
  foreach dir [concat [xps_get_verilog_incl_dirs $simulator $launch_dir] [xps_get_verilog_incl_file_dirs $simulator $launch_dir {}]] {
    lappend l_incl_dirs_opts "+incdir+\"$dir\""
  }

  if { [xps_is_fileset $tcl_obj] } {
    set xpm_libraries [get_property -quiet xpm_libraries [current_project]]
    foreach library $xpm_libraries {
      foreach file [rdi::get_xpm_files -library_name $library] {
        set file_type "SystemVerilog"
        set compiler [xps_get_compiler $simulator $file_type]
        set l_other_compiler_opts [list]
        xps_append_compiler_options $simulator $launch_dir $compiler $file_type $global_files_str l_other_compiler_opts
        set g_files $global_files_str
        set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler $g_files l_other_compiler_opts l_incl_dirs_opts 1]
        if { {} != $cmd_str } {
          lappend files $cmd_str
        }
      }
    }
    set b_add_sim_files 1
    if { {} != $linked_src_set } {
      xps_add_block_fs_files $simulator $launch_dir $global_files_str l_incl_dirs_opts files
    }
    if { {All} == $src_mgmt_mode } {
      send_msg_id exportsim-Tcl-020 INFO "Fetching design files from '$tcl_obj'..."
      foreach file $l_compile_order_files {
        if { [xps_is_global_include_file $global_files_str $file] } { continue }
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
        set compiler [xps_get_compiler $simulator $file_type]
        set l_other_compiler_opts [list]
        xps_append_compiler_options $simulator $launch_dir $compiler $file_type $global_files_str l_other_compiler_opts
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
        set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler $g_files l_other_compiler_opts l_incl_dirs_opts]
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
          send_msg_id exportsim-Tcl-021 INFO "Fetching design files from '$srcset_obj'...(this may take a while)..."
          set l_compile_order_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $srcset_obj]]
          foreach file $l_compile_order_files {
            set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
            set compiler [xps_get_compiler $simulator $file_type]
            set l_other_compiler_opts [list]
            xps_append_compiler_options $simulator $launch_dir $compiler $file_type $global_files_str l_other_compiler_opts
            if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
            set g_files $global_files_str
            if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
            set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler $g_files l_other_compiler_opts l_incl_dirs_opts]
            if { {} != $cmd_str } {
              lappend files $cmd_str
            }
          }
        }
      }
    }

    if { $b_add_sim_files } {
      send_msg_id exportsim-Tcl-022 INFO "Fetching design files from '$a_sim_vars(fs_obj)'..."
      foreach file [get_files -quiet -all -of_objects $a_sim_vars(fs_obj)] {
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
        set compiler [xps_get_compiler $simulator $file_type]
        set l_other_compiler_opts [list]
        xps_append_compiler_options $simulator $launch_dir $compiler $file_type $global_files_str l_other_compiler_opts
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
        if { [get_property "IS_AUTO_DISABLED" [lindex [get_files -quiet -all [list "$file"]] 0]]} { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
        set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler $g_files l_other_compiler_opts l_incl_dirs_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
        }
      }
    }
  } elseif { [xps_is_ip $tcl_obj] } {
    send_msg_id exportsim-Tcl-023 INFO "Fetching design files from IP '$tcl_obj'..."
    foreach file $l_compile_order_files {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
      set compiler [xps_get_compiler $simulator $file_type]
      set l_other_compiler_opts [list]
      xps_append_compiler_options $simulator $launch_dir $compiler $file_type $global_files_str l_other_compiler_opts
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } { set g_files {} }
      set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler $g_files l_other_compiler_opts l_incl_dirs_opts]
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

proc xps_add_block_fs_files { simulator launch_dir global_files_str l_incl_dirs_opts_arg files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts
  upvar $files_arg files

  send_msg_id exportsim-Tcl-024 INFO "Finding block fileset files..."
  set vhdl_filter "FILE_TYPE == \"VHDL\" || FILE_TYPE == \"VHDL 2008\""
  foreach file [xps_get_files_from_block_filesets $vhdl_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
    set compiler [xps_get_compiler $simulator $file_type]
    set l_other_compiler_opts [list]
    xps_append_compiler_options $simulator $launch_dir $compiler $file_type $global_files_str l_other_compiler_opts
    set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler {} l_other_compiler_opts l_incl_dirs_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
    }
  }
  set verilog_filter "FILE_TYPE == \"Verilog\""
  foreach file [xps_get_files_from_block_filesets $verilog_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
    set compiler [xps_get_compiler $simulator $file_type]
    set l_other_compiler_opts [list]
    xps_append_compiler_options $simulator $launch_dir $compiler $file_type $global_files_str l_other_compiler_opts
    set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $compiler $global_files_str l_other_compiler_opts l_incl_dirs_opts]
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

proc xps_get_cmdstr { simulator launch_dir file file_type compiler global_files_str l_other_compiler_opts_arg  l_incl_dirs_opts_arg {b_skip_file_obj_access 0} } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  upvar $l_other_compiler_opts_arg l_other_compiler_opts
  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts
  set b_absolute_path $a_sim_vars(b_absolute_path)
  set cmd_str {}
  set associated_library [get_property "DEFAULT_LIB" [current_project]]
  set srcs_dir [file normalize [file join $launch_dir "srcs"]]
  if { $b_skip_file_obj_access } {
    #
  } else {
    set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
    if { {} != $file_obj } {
      if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
        set associated_library [get_property "LIBRARY" $file_obj]
      }
      if { $a_sim_vars(b_extract_ip_sim_files) && (!$a_sim_vars(b_xsim_specified)) } {
        set xcix_ip_path [get_property core_container $file_obj]
        if { {} != $xcix_ip_path } {
          set ip_name [file root [file tail $xcix_ip_path]]
          set ip_ext_dir [get_property ip_extract_dir [get_ips $ip_name]]
          set ip_file "./[xps_get_relative_file_path $file $ip_ext_dir]"
          # remove leading "./../"
          set ip_file [join [lrange [split $ip_file "/"] 2 end] "/"]
          set file [file join $ip_ext_dir $ip_file]
        } else {
          # set file [extract_files -files [list "$file"] -base_dir $launch_dir/ip_files]
        }
      }
    }
  }

  set src_file $file

  set ip_file {}
  if { $b_skip_file_obj_access } {
    #
  } else {
    set ip_file [xps_get_ip_name $src_file]
  }

  if { $a_sim_vars(b_absolute_path) } {
    set file "[xps_resolve_file_path $file $launch_dir]"
    if { $a_sim_vars(b_xport_src_files) } {
      set filename [file tail $src_file]
      set file "$launch_dir/srcs/$filename"
    }
  } else {
    switch $simulator {
      "xsim" -
      "modelsim" -
      "questa" {
        set file "./[xps_get_relative_file_path $file $launch_dir]"
        if { $a_sim_vars(b_xport_src_files) } {
          if { {} != $ip_file } {
            set proj_src_filename [file tail $src_file]
            set ip_name [file rootname [file tail $ip_file]]
            set proj_src_filename "ip/$ip_name/$proj_src_filename"
            set file "./srcs/$proj_src_filename"
          } else {
            set file "./srcs/[file tail $src_file]"
          }
        }
      }
      "ies" {
        set file "\$ref_dir/[xps_get_relative_file_path $file $launch_dir]"
        if { $a_sim_vars(b_single_step) } {
          set file "[xps_get_relative_file_path $src_file $launch_dir]"
        }
        if { $a_sim_vars(b_xport_src_files) } {
          set file "\$ref_dir/incl"
        }
      }
      "vcs" {
        set file "\$ref_dir/[xps_get_relative_file_path $file $launch_dir]"
        if { $a_sim_vars(b_xport_src_files) } {
          set file "\$ref_dir/incl"
        }
      }
    }
  }

  set arg_list [list]
  if { [string length $compiler] > 0 } {
    lappend arg_list $compiler
    switch $simulator {
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
  if { {vlog} == $compiler } {
    set arg_list [concat $arg_list $l_incl_dirs_opts]
  }
  set file_str [join $arg_list " "]
  set type [xps_get_file_type_category $file_type]


  set cmd_str "$type#$file_type#$associated_library#$src_file#$file_str#$ip_file#\"$file\""
  return $cmd_str
}

proc xps_get_ip_name { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  set ip {}
  set file_obj [lindex [get_files -all -quiet $src_file] 0]
  if { {} == $file_obj } {
    set file_obj [lindex [get_files -all -quiet [file tail $src_file]] 0]
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

proc xps_resolve_file_path { file_dir_path_to_convert launch_dir } {
  # Summary: Make file path relative to ref_dir if relative component found
  # Argument Usage:
  # file_dir_path_to_convert: input file to make relative to specfied path
  # Return Value:
  # Relative path wrt the path specified

  variable a_sim_vars
  set ref_dir [file normalize [string map {\\ /} $launch_dir]]
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

proc xps_export_fs_data_files { filter data_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $data_files_arg data_files
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
}

proc xps_export_data_files { data_files export_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_target_simulator
  if { [llength $data_files] > 0 } {
    set data_files [xps_remove_duplicate_files $data_files]
    foreach file $data_files {
      set file [extract_files -files [list "$file"] -base_dir $export_dir/ip_files]
      foreach simulator $l_target_simulator {
        set dir [file join $a_sim_vars(s_xport_dir) $simulator] 
        if {[catch {file copy -force $file $dir} error_msg] } {
          send_msg_id exportsim-Tcl-025 WARNING "Failed to copy file '$file' to '$dir' : $error_msg\n"
        } else {
          send_msg_id exportsim-Tcl-025 INFO "Exported '$file'\n"
        }
      }
    }
  }
}

proc xps_set_script_filename {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xps_is_ip $tcl_obj] } {
    set a_sim_vars(ip_filename) [file tail $tcl_obj]
    if { {} == $a_sim_vars(s_script_filename) } {
      set ip_name [file root $a_sim_vars(ip_filename)]
      set a_sim_vars(s_script_filename) "${ip_name}"
    }
  } elseif { [xps_is_fileset $tcl_obj] } {
    if { {} == $a_sim_vars(s_script_filename) } {
      set a_sim_vars(s_script_filename) "$a_sim_vars(s_top)"
      if { {} == $a_sim_vars(s_script_filename) } {
        set extn ".bat"
        if {$::tcl_platform(platform) == "unix"} {
          set extn ".sh"
        }
        set a_sim_vars(s_script_filename) "top$extn"
      }
    }
  }

  if { {} != $a_sim_vars(s_script_filename) } {
    set name $a_sim_vars(s_script_filename)
    set index [string last "." $name ]
    if { $index != -1 } {
      set a_sim_vars(s_script_filename) [string range $name 0 [expr $index - 1]]
    }
  }
}

proc xps_write_sim_script { data_files } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:

  variable a_sim_vars
  variable l_target_simulator
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  foreach simulator $l_target_simulator {
    set simulator_name [xps_get_simulator_pretty_name $simulator] 
    send_msg_id exportsim-Tcl-035 INFO \
      "Generating simulation files for the '$simulator_name' simulator...\n"
    set dir [file join $a_sim_vars(s_xport_dir) $simulator] 
    xps_create_dir $dir
    if { $a_sim_vars(b_xport_src_files) } {
      xps_create_dir [file join $dir "srcs"]
      xps_create_dir [file join $dir "srcs" "incl"]
      xps_create_dir [file join $dir "srcs" "ip"]
    }
    if { [xps_is_ip $tcl_obj] } {
      set a_sim_vars(s_top) [file tail [file root $tcl_obj]]
      send_msg_id exportsim-Tcl-026 INFO "Inspecting IP design source files for '$a_sim_vars(s_top)'...\n"
      xps_export_data_files $data_files $dir
      if {[xps_export_sim_files_for_ip $tcl_obj $simulator $dir]} {
        return 1
      }
    } elseif { [xps_is_fileset $tcl_obj] } {
      set a_sim_vars(s_top) [get_property top [get_filesets $tcl_obj]]
      send_msg_id exportsim-Tcl-027 INFO "Inspecting design source files for '$a_sim_vars(s_top)' in fileset '$tcl_obj'...\n"
      if {[string length $a_sim_vars(s_top)] == 0} {
        set a_sim_vars(s_top) "unknown"
      }
      xps_export_data_files $data_files $dir
      if { [xps_export_sim_files_for_fs $simulator $dir] } {
        return 1
      }
    } else {
      send_msg_id exportsim-Tcl-028 INFO "Unsupported object source: $tcl_obj\n"
      return 1
    }

    if { [xps_write_plain_filelist $dir] } {
      return 1
    }
    if { [xps_write_filelist_info $dir] } {
      return 1
    }
  }
  return 0
}


proc xps_export_config {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars

  set fh 0
  set file $a_sim_vars(opts_file)
  if { [file exists $file] } {
    if { $a_sim_vars(b_reset_config_opts) } {
      if {[catch {file delete -force $file} error_msg] } {
        [catch {send_msg_id exportsim-Tcl-033 ERROR "failed to delete file ($file): $error_msg\n"} err]
        return
      }
    } else {
      return
    }
  }
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-066 ERROR "failed to open file to write ($file)\n"
    return 1
  }

  set curr_time   [clock format [clock seconds]]
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]

  puts $fh "# $product (TM) $version_id\n#"
  puts $fh "# $file (generated by export_simulation on $curr_time)"
  puts $fh "#\n# Specify the switches for the simulator tools that will be added in the exported script.\n#"
  puts $fh "# Syntax:-\n#"
  puts $fh "# <simulator>:<tool>:<options>"
  puts $fh "#\n##########################################################################################\n#"
  puts $fh "# XSim\n#"
  puts $fh "xsim:xvlog:--relax"
  puts $fh "xsim:xvhdl:--relax"
  puts $fh "xsim:xelab:--relax --debug typical --mt auto"
  puts $fh "xsim:xsim:"
  puts $fh "#\n# ModelSim\n#"
  puts $fh "modelsim:vlog:-incr"
  puts $fh "modelsim:vcom:-93"
  puts $fh "modelsim:vsim:"
  puts $fh "#\n# Questa\n#"
  puts $fh "questa:vlog:"
  puts $fh "questa:vcom:"
  puts $fh "questa:vopt:"
  puts $fh "questa:vsim:"
  puts $fh "questa:qverilog:-incr +acc"
  puts $fh "#\n# IES\n#"
  puts $fh "ies:ncvlog:"
  puts $fh "ies:ncvhdl:-V93"
  puts $fh "ies:ncelab:-relax -access +rwc -messages"
  puts $fh "ies:ncsim:"
  puts $fh "ies:irun:-V93 -RELAX"
  puts $fh "#\n# VCS\n#"
  puts $fh "vcs:vlogan:-timescale=1ps/1ps"
  puts $fh "vcs:vhdlan:"
  puts $fh "vcs:vcs:"
  puts $fh "vcs:simv:"
  close $fh
}

proc xps_write_plain_filelist { launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  variable l_target_simulator
  foreach simulator $l_target_simulator {
    set dir [file join $a_sim_vars(s_xport_dir) $simulator] 
    set fh 0
    set file [file join $dir "filelist.f"]
    if {[catch {open $file w} fh]} {
      send_msg_id exportsim-Tcl-066 ERROR "failed to open file to write ($file)\n"
      return 1
    }
    foreach file $a_sim_vars(l_design_files) {
      set fargs         [split $file {#}]
      set proj_src_file [lindex $fargs 3]
      set pfile "[xps_get_relative_file_path $proj_src_file $dir]"
      if { $a_sim_vars(b_absolute_path) } {
        set pfile "[xps_resolve_file_path $proj_src_file $launch_dir]"
      }
      puts $fh $pfile
    }
    close $fh
  }
  return 0
}

proc xps_write_filelist_info { launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  variable l_target_simulator
  foreach simulator $l_target_simulator {
    set dir [file join $a_sim_vars(s_xport_dir) $simulator] 
    set fh 0
    set file [file join $dir "file_info.txt"]
    if {[catch {open $file w} fh]} {
      send_msg_id exportsim-Tcl-067 ERROR "failed to open file to write ($file)\n"
      return 1
    }
    set lines [list]
    lappend lines "Language File-Name IP Library File-Path"
    foreach file $a_sim_vars(l_design_files) {
      set fargs         [split $file {#}]
      set type          [lindex $fargs 0]
      set file_type     [lindex $fargs 1]
      set lib           [lindex $fargs 2]
      set proj_src_file [lindex $fargs 3]
      set ip_file       [lindex $fargs 5]
      set src_file      [lindex $fargs 6]
      set filename [file tail $proj_src_file]
      set ipname   [file rootname [file tail $ip_file]]
      set pfile "[xps_get_relative_file_path $proj_src_file $dir]"
      if { $a_sim_vars(b_absolute_path) } {
        set pfile "[xps_resolve_file_path $proj_src_file $launch_dir]"
      }
      if { {} != $ipname } {
        lappend lines "$file_type, $filename, $ipname, $lib, $pfile"
      } else {
        lappend lines "$file_type, $filename, *, $lib, $pfile"
      }
    }
    struct::matrix file_matrix;
    file_matrix add columns 5;
    foreach line $lines {
      file_matrix add row $line;
    }
    puts $fh [file_matrix format 2string]
    file_matrix destroy
    close $fh
  }
  return 0
}

proc xps_export_sim_files_for_ip { tcl_obj simulator dir } {
  # Summary: 
  # Argument Usage:
  # source object
  # Return Value:
  # true (0) if success, false (1) otherwise
  variable a_sim_vars
  variable l_compile_order_files
  set l_compile_order_files [xps_remove_duplicate_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$a_sim_vars(ip_filename)]]]
  xps_print_source_info
  if {[xps_write_script $simulator $dir]} {
    return 1
  }
  return 0
}
 
proc xps_export_sim_files_for_fs { simulator dir } {
  # Summary: 
  # Argument Usage:
  # source object
  # Return Value:
  # true (0) if success, false (1) otherwise
  variable a_sim_vars
  xps_print_source_info
  if {[xps_write_script $simulator $dir]} {
    return 1
  }
  return 0
}

proc xps_check_script { dir filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set file [file normalize [file join $dir $filename]]
  if { [file exists $file] && (!$a_sim_vars(b_overwrite)) } {
    [catch {send_msg_id exportsim-Tcl-032 ERROR "Script file exist:'$file'. Use the -force option to overwrite."} err]
    return 1
  }
  if { [file exists $file] } {
    if {[catch {file delete -force $file} error_msg] } {
      [catch {send_msg_id exportsim-Tcl-033 ERROR "failed to delete file ($file): $error_msg\n"} err]
      return 1
    }
    # cleanup other files
    set files [glob -nocomplain -directory $dir *]
    foreach file_path $files {
      if { {srcs} == [file tail $file_path] } { continue }
      if {[catch {file delete -force $file_path} error_msg] } {
        send_msg_id exportsim-Tcl-010 ERROR "failed to delete file ($file_path): $error_msg\n"
        return 1
      }
    }
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
  send_msg_id exportsim-Tcl-031 INFO "Number of design source files found = $n_total_srcs\n"
}

proc xps_write_script { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  set filename ${a_sim_vars(s_script_filename)}.bat
  if {$::tcl_platform(platform) == "unix"} {
    set filename ${a_sim_vars(s_script_filename)}.sh
  }
  if { [xps_check_script $dir $filename] } {
    return 1
  }
  xps_process_cmd_str $simulator $dir
  if { [xps_invalid_flow_options] } { return 1 }
  xps_write_simulation_script $simulator $dir
  send_msg_id exportsim-Tcl-029 INFO \
    "Script file exported: '$dir/$filename'\n"
  return 0
}
 
proc xps_write_simulation_script { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  set fh_unix 0
  set fh_win 0

  if {$::tcl_platform(platform) == "unix"} {
    set file [file join $dir $a_sim_vars(s_script_filename)] 
    set file_unix ${file}.sh
    if {[catch {open $file_unix w} fh_unix]} {
      send_msg_id exportsim-Tcl-034 ERROR "failed to open file to write ($file_unix)\n"
      return 1
    }
  } else {
    set file [file join $dir $a_sim_vars(s_script_filename)] 
    set file_win ${file}.bat
    if {[catch {open $file_win w} fh_win]} {
      send_msg_id exportsim-Tcl-034 ERROR "failed to open file to write ($file_win)\n"
      return 1
    }
  }

  if { [xps_write_driver_script $simulator $fh_unix $fh_win $dir] } {
    return 1
  }

  if {$::tcl_platform(platform) == "unix"} {
    close $fh_unix
    xps_set_permissions $file_unix
  } else {
    close $fh_win
    xps_set_permissions $file_win
  }
  return 0
}

proc xps_set_permissions { file } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  if {$::tcl_platform(platform) == "unix"} {
    if {[catch {exec chmod a+x $file} error_msg] } {
      send_msg_id exportsim-Tcl-036 WARNING "failed to change file permissions to executable ($file): $error_msg\n"
    }
  } else {
    if {[catch {exec attrib /D -R $file} error_msg] } {
      send_msg_id USF-XSim-070 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
    }
  }
}
 
proc xps_write_driver_script { simulator fh_unix fh_win launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  xps_write_main_driver_procs $simulator $fh_unix $fh_win

  if { ({ies} == $simulator) || ({vcs} == $simulator) } {
    if { $a_sim_vars(b_single_step) } {
      # no do file required
    } else {
      xps_create_ies_vcs_do_file $simulator $launch_dir
    }
  }

  xps_write_simulator_procs $simulator $fh_unix $fh_win $launch_dir

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "\n# Launch script"
    puts $fh_unix "run \$1"
  } else {
    puts $fh_win "\n:end"
    puts $fh_win "exit 1"
  }
  return 0
}

proc xps_write_main_driver_procs { simulator fh_unix fh_win } {
  # Summary:
  # Argument Usage:
  # Return Value:
  xps_write_header $simulator $fh_unix $fh_win
  xps_write_main $fh_unix $fh_win
  xps_write_setup $simulator $fh_unix $fh_win
  xps_write_glbl $fh_unix $fh_win
  xps_print_usage $fh_unix $fh_win
  xps_write_reset $simulator $fh_unix $fh_win
  xps_write_run_steps $simulator $fh_unix $fh_win
  if {$::tcl_platform(platform) == "unix"} {
    xps_write_libs_unix $simulator $fh_unix
  } else {
    xps_write_libs_win $simulator $fh_win
  }
}

proc xps_write_simulator_procs { simulator fh_unix fh_win launch_dir } { 
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars

  set srcs_dir [xps_create_srcs_dir $launch_dir]

  if { $a_sim_vars(b_single_step) } {
    xps_write_single_step $simulator $fh_unix $fh_win $launch_dir $srcs_dir
  } else {
    xps_write_multi_step $simulator $fh_unix $fh_win $launch_dir $srcs_dir
  }
}

proc xps_write_single_step { simulator fh_unix fh_win launch_dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  variable l_compile_order_files

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "# RUN_STEP: <execute>"
    puts $fh_unix "execute()\n\{"
  } else {
    puts $fh_win "\nrem # RUN_STEP: <execute>"
    puts $fh_win ":execute"
  }

  if { ({ies} == $simulator) || ({vcs} == $simulator) } {
    #xps_write_ref_dir $fh_unix $launch_dir $srcs_dir
  }
  switch -regexp -- $simulator {
    "xsim" {
      xps_write_prj_single_step $launch_dir $srcs_dir
      xps_write_xelab_cmdline $fh_unix $fh_win $launch_dir
      #xps_write_xsim_cmdline $fh_unix $fh_win $launch_dir
    }
    "modelsim" {
      if {$::tcl_platform(platform) == "unix"} {
        puts $fh_unix "  source run.do 2>&1 | tee -a run.log"
      } else {
        puts $fh_win "call vsim -c -do \"do \{run.do\}\" -l run.log"
        puts $fh_win "if \"%errorlevel%\"==\"1\" goto end"
      }
      xps_write_do_file_for_compile $simulator $launch_dir $srcs_dir
    }
    "questa" {
      set filename "run.f"
      set lib_path_value [file normalize [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]]
      if {$::tcl_platform(platform) == "unix"} {
        puts $fh_unix "  XILINX_VIVADO=$::env(XILINX_VIVADO)"
        puts $fh_unix "  export XILINX_VIVADO"
      } else {
        puts $fh_win "set XILINX_VIVADO=$::env(XILINX_VIVADO)"
      }
      set arg_list [list]
      xps_append_config_opts arg_list "questa" "qverilog"
      lappend arg_list   "-f $filename"
      #foreach filelist [xps_get_secureip_filelist] {
      #  lappend arg_list $filelist
      #}
      lappend arg_list "-f $::env(XILINX_VIVADO)/data/secureip/secureip_cell.list.f" \
                       "-y $::env(XILINX_VIVADO)/data/verilog/src/retarget/" \
                       "+libext+.v" \
                       "-y $::env(XILINX_VIVADO)/data/verilog/src/unisims/" \
                       "+libext+.v" \
                       "-l run.log" \
                       "./glbl.v"
      #"-R -do \"run 1000ns; quit\""
      foreach dir [concat [xps_get_verilog_incl_dirs $simulator $launch_dir] [xps_get_verilog_incl_file_dirs $simulator $launch_dir {} true]] {
        lappend arg_list "+incdir+\"$dir\""
      }
      set cmd_str [join $arg_list " \\\n       "]
      if {$::tcl_platform(platform) == "unix"} {
        puts $fh_unix "  qverilog $cmd_str"
      } else {
        puts $fh_win "call qverilog $cmd_str"
      }

      set fh_1 0
      set file [file normalize [file join $launch_dir $filename]]
      if {[catch {open $file w} fh_1]} {
        send_msg_id exportsim-Tcl-037 ERROR "failed to open file to write ($file)\n"
        return 1
      }
      xps_write_compile_order $simulator $fh_1 $launch_dir $srcs_dir
      close $fh_1
    }
    "ies" {
      set filename "run.f"
      set arg_list [list]
      puts $fh_unix "  XILINX_VIVADO=$::env(XILINX_VIVADO)"
      puts $fh_unix "  export XILINX_VIVADO"
      set b_verilog_only 0
      if { [xps_contains_verilog] && ![xps_contains_vhdl] } {
        set b_verilog_only 1
      }
      xps_append_config_opts arg_list "ies" "irun"
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list end "-64bit"] }
      lappend arg_list  "-timescale 1ps/1ps" \
                         "-top $a_sim_vars(s_top)" \
                         "-f $filename"
      if { $b_verilog_only } {
      lappend arg_list   "-f $::env(XILINX_VIVADO)/data/secureip/secureip_cell.list.f"
      }
      if { [xps_contains_verilog] } {
      lappend arg_list "glbl.v"
      }
      if { $b_verilog_only } {
      lappend arg_list   "-y $::env(XILINX_VIVADO)/data/verilog/src/retarget/" \
                         "+libext+.v" \
                         "-y $::env(XILINX_VIVADO)/data/verilog/src/unisims/" \
                         "+libext+.v"
      }
      lappend arg_list   "-l run.log"
      if { $a_sim_vars(b_single_step) } {
        lappend arg_list "+incdir+\"./srcs/incl\""
      }

      set cmd_str [join $arg_list " \\\n       "]
      puts $fh_unix "  irun $cmd_str"
      set fh_1 0
      set file [file normalize [file join $launch_dir $filename]]
      if {[catch {open $file w} fh_1]} {
        send_msg_id exportsim-Tcl-038 ERROR "failed to open file to write ($file)\n"
        return 1
      }
      xps_write_compile_order $simulator $fh_1 $launch_dir $srcs_dir
      close $fh_1
    }
    "vcs" {
      set filename "run.f"
      puts $fh_unix "  XILINX_VIVADO=$::env(XILINX_VIVADO)"
      puts $fh_unix "  export XILINX_VIVADO"
      set arg_list [list]
      xps_append_config_opts arg_list "vcs" "vcs"
      lappend arg_list   "-V" \
                         "-timescale=1ps/1ps" \
                         "-f $filename" \
                         "-f $::env(XILINX_VIVADO)/data/secureip/secureip_cell.list.f"
      if { [xps_contains_verilog] } {
        lappend arg_list "glbl.v"
      }
      lappend arg_list   "+libext+.v" \
                         "-y $::env(XILINX_VIVADO)/data/verilog/src/retarget/" \
                         "+libext+.v" \
                         "-y $::env(XILINX_VIVADO)/verilog/src/unisims/" \
                         "+libext+.v" \
                         "-lca -v2005 +v2k"

      if { [xps_contains_system_verilog] } {
        lappend args_list "-sverilog"
      }

      lappend arg_list "-l run.log"
      foreach dir [concat [xps_get_verilog_incl_dirs $simulator $launch_dir] [xps_get_verilog_incl_file_dirs $simulator $launch_dir {} true]] {
        lappend arg_list "+incdir+\"$dir\""
      }
      lappend arg_list "-R"
      set cmd_str [join $arg_list " \\\n       "]
      puts $fh_unix "  vcs $cmd_str"
      #puts $fh_unix "  ./simv"
  
      set fh_1 0
      set file [file normalize [file join $launch_dir $filename]]
      if {[catch {open $file w} fh_1]} {
        send_msg_id exportsim-Tcl-039 ERROR "failed to open file to write ($file)\n"
        return 1
      }
      xps_write_compile_order $simulator $fh_1 $launch_dir $srcs_dir
      close $fh_1
    }
  }
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "\}\n"
  } else {
    puts $fh_win "goto:eof\n"
  }
  return 0
}

proc xps_write_multi_step { simulator fh_unix fh_win launch_dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compile_order_files
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "\n# RUN_STEP: <compile>"
    puts $fh_unix "compile()\n\{"
  } else {
    puts $fh_win "\nrem # RUN_STEP: <compile>"
    puts $fh_win ":compile"
  }

  if { ({ies} == $simulator) || ({vcs} == $simulator) } {
    xps_write_ref_dir $fh_unix $launch_dir $srcs_dir
  }

  if {[llength $l_compile_order_files] == 0} {
    if {$::tcl_platform(platform) == "unix"} {
      puts $fh_unix "# None (no sources present)"
      puts $fh_unix "\}"
    } else {
      puts $fh_win "rem # None (no sources present)"
      puts $fh_win "goto:eof"
    }
    return 0
  }
  
  switch -regexp -- $simulator {
    "modelsim" -
    "questa" {
    }
    default {
      if {$::tcl_platform(platform) == "unix"} {
        puts $fh_unix "  # Command line options"
      } else {
        puts $fh_win "rem # Command line options"
      }
    }
  }

  set opts_ver_win {}
  set opts_vhd_win {}
  switch -regexp -- $simulator {
    "xsim" {
      set arg_list [list]
      xps_append_config_opts arg_list "xsim" "xvlog"
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-m64"] }
      if { [xps_contains_verilog] } {
        if {$::tcl_platform(platform) == "unix"} {
          puts $fh_unix "  opts_ver=\"[join $arg_list " "]\""
        }
        set opts_ver_win [join $arg_list " "]
      }
      set arg_list [list]
      xps_append_config_opts arg_list "xsim" "xvhdl"
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-m64"] }
      if { [xps_contains_vhdl] } {
        if {$::tcl_platform(platform) == "unix"} {
          puts $fh_unix "  opts_vhd=\"[join $arg_list " "]\""
        }
        set opts_vhd_win [join $arg_list " "]
      }
    }
    "ies" { 
      set arg_list [list]
      xps_append_config_opts arg_list "ies" "ncvlog"
      set arg_list [linsert $arg_list end "-messages" "-logfile" "ncvlog.log" "-append_log"]
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-64bit"] }
      puts $fh_unix "  opts_ver=\"[join $arg_list " "]\""

      set arg_list [list]
      xps_append_config_opts arg_list "ies" "ncvhdl"
      set arg_list [linsert $arg_list end "-RELAX" "-logfile" "ncvhdl.log" "-append_log"]
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-64bit"] }
      puts $fh_unix "  opts_vhd=\"[join $arg_list " "]\""
    }
    "vcs"   {
      set arg_list [list]
      xps_append_config_opts arg_list "vcs" "vlogan"
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-full64"] }
      puts $fh_unix "  opts_ver=\"[join $arg_list " "]\""

      set arg_list [list]
      xps_append_config_opts arg_list "vcs" "vhdlan"
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-full64"] }
      puts $fh_unix "  opts_vhd=\"[join $arg_list " "]\""
    }
  }

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "\n  # Compile design files" 
  } else {
    #puts $fh_win "rem # Compile design files" 
  }

  switch $simulator { 
    "xsim" {
      set redirect "2>&1 | tee compile.log"
      if { [xps_contains_verilog] } {
        if {$::tcl_platform(platform) == "unix"} {
          puts $fh_unix "  xvlog \$opts_ver -prj vlog.prj $redirect"
        } else {
          puts $fh_win "call xvlog $opts_ver_win -prj vlog.prj -log compile.log"
        }
      }
      if { [xps_contains_vhdl] } {
        if {$::tcl_platform(platform) == "unix"} {
          puts $fh_unix "  xvhdl \$opts_vhd -prj vhdl.prj $redirect"
        } else {
          puts $fh_win "call xvhdl $opts_vhd_win -prj vhdl.prj -log compile.log"
        }
      }
      xps_write_xsim_prj $launch_dir $srcs_dir
    }
    "modelsim" -
    "questa" {
      if {$::tcl_platform(platform) == "unix"} {
        puts $fh_unix "  source compile.do 2>&1 | tee -a compile.log"
      } else {
        puts $fh_win "call vsim -64 -c -do \"do \{compile.do\}\" -l compile.log"
      }
      xps_write_do_file_for_compile $simulator $launch_dir $srcs_dir
    }
    "ies" -
    "vcs" {
      xps_write_compile_order $simulator $fh_unix $launch_dir $srcs_dir
    }
  }
   
  if { [xps_contains_verilog] } {
    switch -regexp -- $simulator {
      "ies" {
        puts $fh_unix "\n  ncvlog \$opts_ver -work $a_sim_vars(default_lib) \\\n\    \"./glbl.v\""
      }
      "vcs" {
        set sw {}
        if { {work} != $a_sim_vars(default_lib) } {
          set sw "-work $a_sim_vars(default_lib)"
        }
        puts $fh_unix "  vlogan $sw \$opts_ver +v2k \\\n    ./glbl.v \\\n  2>&1 | tee -a vlogan.log"
      }
    }
  }

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "\}\n"
  } else {
    puts $fh_win "goto:eof"
  }

  switch -regexp -- $simulator {
    "modelsim" {}
    default {
      xps_write_elaboration_cmds $simulator $fh_unix $fh_win $launch_dir
    }
  }
  xps_write_simulation_cmds $simulator $fh_unix $fh_win $launch_dir
  return 0
}

proc xps_append_config_opts { opts_arg simulator tool } {
  # Summary:
  # Argument Usage:
  # Return Value:
  upvar $opts_arg opts
  variable a_sim_vars
  set fh 0
  set file $a_sim_vars(opts_file)
  if { ![file exists $file] } {
    return
  }
  if { [catch {open $file r} fh] } {
    send_msg_id exportsim-Tcl-044 ERROR "Failed to open file to read ($file)\n"
    return  
  }
  set data [read $fh]
  close $fh

  set args_list [list]
  set data [split $data "\n"]
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; } 
    if {[regexp {^#} $line]} { continue; }
    set tokens [split $line {:}]
    set name_id [lindex $tokens 0]
    set tool_id [lindex $tokens 1]
    set tool_opts [lindex $tokens 2]
    if { $simulator == $name_id } {
      if { $tool == $tool_id } {
        lappend args_list $tool_opts
      }
    }
  }
  set opts_str [string trim [join $args_list " "]]
  if { {} != $opts_str } {
    lappend opts $opts_str
  }
}

proc xps_write_ref_dir { fh_unix launch_dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  puts $fh_unix "  # Directory path for design sources and include directories (if any) wrt this path"
  if { $a_sim_vars(b_absolute_path) } {
    puts $fh_unix "  ref_dir=\"$launch_dir/$srcs_dir\""
  } else {
    if { $a_sim_vars(b_xport_src_files) } {
      puts $fh_unix "  ref_dir=\"./srcs\""
    } else {
      puts $fh_unix "  ref_dir=\".\""
    }
  }
}

proc xps_write_run_steps { simulator fh_unix fh_win } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "# Main steps"
    puts $fh_unix "run()\n\{"
    puts $fh_unix "  setup \$1 \$2"
    if { $a_sim_vars(b_single_step) } {
      puts $fh_unix "  execute"
    } else {
      puts $fh_unix "  compile"
      switch -regexp -- $simulator {
        "modelsim" {}
        default {
          puts $fh_unix "  elaborate"
        }
      }
      puts $fh_unix "  simulate"
    }
    puts $fh_unix "\}\n"
  } else {
    puts $fh_win "\nrem Main steps"
    puts $fh_win ":run"
    puts $fh_win "call:setup %1"
    puts $fh_win "if \"%errorlevel%\"==\"1\" goto end"
    puts $fh_win "call:copy_glbl_file"
    puts $fh_win "if \"%errorlevel%\"==\"1\" goto end"
    if { $a_sim_vars(b_single_step) } {
      puts $fh_win "call:execute"
      puts $fh_win "if \"%errorlevel%\"==\"1\" goto end"
    } else {
      puts $fh_win "call:compile"
      puts $fh_win "if \"%errorlevel%\"==\"1\" goto end"
      switch -regexp -- $simulator {
        "modelsim" {}
        default {
          puts $fh_win "call:elaborate"
          puts $fh_win "if \"%errorlevel%\"==\"1\" goto end"
        }
      } 
      puts $fh_win "call:simulate"
      puts $fh_win "if \"%errorlevel%\"==\"1\" goto end"
    }
    puts $fh_win "goto:eof"
  }
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

proc xps_set_initial_cmd { simulator fh cmd_str src_file file_type lib opts_str prev_file_type_arg prev_lib_arg log_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:
  # None

  variable a_sim_vars
  upvar $prev_file_type_arg prev_file_type
  upvar $prev_lib_arg  prev_lib
  upvar $log_arg log
  switch $simulator {
    "xsim" {
      if { $a_sim_vars(b_single_step) } {
       # 
      } else {
        puts $fh "$cmd_str \\"
        if { $a_sim_vars(b_xport_src_files) } {
          puts $fh "./srcs/$src_file ${opts_str} \\"
        } else {
          puts $fh "$src_file ${opts_str} \\"
        }
      }
    }
    "modelsim" -
    "questa" {
      puts $fh "$cmd_str \\"
      puts $fh "$src_file \\"
    }
    "ies" {
      if { $a_sim_vars(b_single_step) } {
        puts $fh "-makelib ies/$lib \\"
        if { $a_sim_vars(b_xport_src_files) } {
          puts $fh "  ./srcs/$src_file \\"
        } else {
          puts $fh "  $src_file \\"
        }
      } else {
        puts $fh "  $cmd_str \\"
        if { $a_sim_vars(b_xport_src_files) } {
          puts $fh "    \$ref_dir/$src_file \\"
        } else {
          puts $fh "    $src_file \\"
        }
      }
    }
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
  switch $simulator {
    "vcs" {
      if { [regexp -nocase {vhdl} $file_type] } {
        set log "vhdlan.log"
      } elseif { [regexp -nocase {verilog} $file_type] } {
        set log "vlogan.log"
      }
    }
  }
}
 
proc xps_write_compile_order { simulator fh launch_dir srcs_dir } {
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
  set redirect_cmd_str "  2>&1 | tee -a"
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
      set target_dir $srcs_dir
      if { {} != $ip_file } {
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "ip/$ip_name/$proj_src_filename"
        set ip_dir [file join $srcs_dir "ip" $ip_name] 
        if { ![file exists $ip_dir] } {
          if {[catch {file mkdir $ip_dir} error_msg] } {
            send_msg_id exportsim-Tcl-040 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
            return 1
          }
        }
        set target_dir $ip_dir
      }
      if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
        send_msg_id exportsim-Tcl-041 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
      }
    }
   
    switch $simulator {
      "vcs" {
        # vlogan expects double back slash
        if { ([regexp { } $src_file] && [regexp -nocase {vlogan} $cmd_str]) } {
          set src_file [string trim $src_file "\""]
          regsub -all { } $src_file {\\\\ } src_file
        }
      }
    }

    if { $a_sim_vars(b_single_step) } {
      switch $simulator {
        "ies" { }
        default {
          set file $proj_src_file
          regsub -all {\"} $file {} file

          if { $a_sim_vars(b_absolute_path) } {
            set file "[xps_resolve_file_path $file $launch_dir]"
          } else {
            set file "[xps_get_relative_file_path $file $launch_dir]"
          }
          if { $a_sim_vars(b_xport_src_files) } {
            set file "./srcs/$proj_src_filename"
          }
          puts $fh $file
          continue
        }
      }
    }

    set b_redirect false
    set b_appended false
    if { $b_first } {
      set b_first false
      if { $a_sim_vars(b_xport_src_files) } {
        xps_set_initial_cmd $simulator $fh $cmd_str $proj_src_filename $file_type $lib {} prev_file_type prev_lib log
      } else {
        xps_set_initial_cmd $simulator $fh $cmd_str $src_file $file_type $lib {} prev_file_type prev_lib log
      }
    } else {
      if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
        # single_step
        if { $a_sim_vars(b_single_step) } {
          if { $a_sim_vars(b_xport_src_files) } {
            switch $simulator {
              "ies" {
                puts $fh "  ./srcs/$proj_src_filename \\"
              }
              "vcs" {
                puts $fh "    ./srcs/$proj_src_filename \\"
              }
            }
          } else {
            switch $simulator {
              "ies" {
                puts $fh "  $src_file \\"
              }
              "vcs" {
                puts $fh "    $proj_src_file \\"
              }
            }
          }
        } else {
          if { $a_sim_vars(b_xport_src_files) } {
            switch $simulator {
              "ies" {
                puts $fh "    \$ref_dir/$proj_src_filename \\"
              }
              "vcs" {
                puts $fh "    \$ref_dir/$proj_src_filename \\"
              }
            }
          } else {
            switch $simulator {
              "ies" {
                puts $fh "    $src_file \\"
              }
              "vcs" {
                puts $fh "    $src_file \\"
              }
            }
          }
        }
        set b_redirect true
      } else {
        switch $simulator {
          "ies" { 
            if { $a_sim_vars(b_single_step) } {
              puts $fh "-endlib"
            } else {
              puts $fh ""
            }
          }
          "vcs"    { puts $fh "$redirect_cmd_str $log\n" }
        }
        if { $a_sim_vars(b_xport_src_files) } {
          xps_set_initial_cmd $simulator $fh $cmd_str $proj_src_filename $file_type $lib {} prev_file_type prev_lib log
        } else {
          xps_set_initial_cmd $simulator $fh $cmd_str $src_file $file_type $lib {} prev_file_type prev_lib log
        }
        set b_appended true
      }
    }
  }

  if { $a_sim_vars(b_single_step) } {
    switch $simulator {
      "ies" { 
        puts $fh "-endlib"
      }
    }
  } else {
    switch $simulator {
      "vcs" {
        if { (!$b_redirect) || (!$b_appended) } {
          puts $fh "$redirect_cmd_str $log\n"
        }
      }
    }
  }

  if { [xps_contains_verilog] } {
    if { $a_sim_vars(b_single_step) } { 
      switch -regexp -- $simulator {
        "ies" {
          puts $fh "-makelib ies/xil_defaultlib \\"
          puts $fh "  ./glbl.v"
          puts $fh "-endlib"
        }
      }
    }
  }
}

proc xps_write_header { simulator fh_unix fh_win } {
  # Summary:
  # Argument Usage:
  # Return Value:
  # none
 
  variable a_sim_vars
 
  set curr_time   [clock format [clock seconds]]
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "#!/bin/sh -f"
    puts $fh_unix "# $product (TM) $version_id\n#"
    puts $fh_unix "# Filename    : $a_sim_vars(s_script_filename)"
    puts $fh_unix "# Simulator   : [xps_get_simulator_pretty_name $simulator]"
    puts $fh_unix "# Description : Simulation script for compiling, elaborating and verifying the project source files."
    puts $fh_unix "#               The script will automatically create the design libraries sub-directories in the run"
    puts $fh_unix "#               directory, add the library logical mappings in the simulator setup file, create default"
    puts $fh_unix "#               'do' file, copy glbl.v into the run directory for verilog sources in the design (if any),"
    puts $fh_unix "#               execute compilation, elaboration and simulation steps. By default, the source file and"
    puts $fh_unix "#               include directory paths will be set relative to the 'ref_dir' variable unless the"
    puts $fh_unix "#               -absolute_path is specified in which case the paths will be set absolute.\n#"
    puts $fh_unix "# Generated by $product on $curr_time"
    puts $fh_unix "# $copyright \n#"
    puts $fh_unix "# usage: $a_sim_vars(s_script_filename).sh \[-help\]"
    puts $fh_unix "# usage: $a_sim_vars(s_script_filename).sh \[-noclean_files\]"
    puts $fh_unix "# usage: $a_sim_vars(s_script_filename).sh \[-reset_run\]\n#"
    puts $fh_unix "# Prerequisite:- To compile and run simulation, you must compile the Xilinx simulation libraries using the"
    puts $fh_unix "# 'compile_simlib' TCL command. For more information about this command, run 'compile_simlib -help' in the"
    puts $fh_unix "# $product Tcl Shell. Once the libraries have been compiled successfully, specify the -lib_map_path switch"
    puts $fh_unix "# that points to these libraries and rerun export_simulation. For more information about this switch please"
    puts $fh_unix "# type 'export_simulation -help' in the Tcl shell.\n#"
    puts $fh_unix "# Alternatively, if the libraries are already compiled then replace <SPECIFY_COMPILED_LIB_PATH> in this script"
    puts $fh_unix "# with the compiled library directory path.\n#"
    puts $fh_unix "# Additional references - 'Xilinx Vivado Design Suite User Guide:Logic simulation (UG900)'\n#"
    puts $fh_unix "# ********************************************************************************************************\n"
  } else {  
    puts $fh_win "@echo off"
    puts $fh_win "rem # $product (TM) $version_id\nrem #"
    puts $fh_win "rem # Filename    : $a_sim_vars(s_script_filename)"
    puts $fh_win "rem # Simulator   : [xps_get_simulator_pretty_name $simulator]"
    puts $fh_win "rem # Description : Simulation script for compiling, elaborating and verifying the project source files."
    puts $fh_win "rem #               The script will automatically create the design libraries sub-directories in the run"
    puts $fh_win "rem #               directory, add the library logical mappings in the simulator setup file, create default"
    puts $fh_win "rem #               'do' file, copy glbl.v into the run directory for verilog sources in the design (if any),"
    puts $fh_win "rem #               execute compilation, elaboration and simulation steps. By default, the source file and"
    puts $fh_win "rem #               include directory paths will be set relative to the 'ref_dir' variable unless the"
    puts $fh_win "rem #               -absolute_path is specified in which case the paths will be set absolute.\nrem #"
    puts $fh_win "rem # Generated by $product on $curr_time"
    puts $fh_win "rem # $copyright \nrem #"
    puts $fh_win "rem # usage: $a_sim_vars(s_script_filename).bat \[-help\]"
    puts $fh_win "rem # usage: $a_sim_vars(s_script_filename).bat \[-noclean_files\]"
    puts $fh_win "rem # usage: $a_sim_vars(s_script_filename).bat \[-reset_run\]\nrem #"
    puts $fh_win "rem # Prerequisite:- To compile and run simulation, you must compile the Xilinx simulation libraries using the"
    puts $fh_win "rem # 'compile_simlib' TCL command. For more information about this command, run 'compile_simlib -help' in the"
    puts $fh_win "rem # $product Tcl Shell. Once the libraries have been compiled successfully, specify the -lib_map_path switch"
    puts $fh_win "rem # that points to these libraries and rerun export_simulation. For more information about this switch please"
    puts $fh_win "rem # type 'export_simulation -help' in the Tcl shell.\nrem #"
    puts $fh_win "rem # Alternatively, if the libraries are already compiled then replace <SPECIFY_COMPILED_LIB_PATH> in this script"
    puts $fh_win "rem # with the compiled library directory path.\nrem #"
    puts $fh_win "rem # Additional references - 'Xilinx Vivado Design Suite User Guide:Logic simulation (UG900)'\nrem #"
    puts $fh_win "rem # ********************************************************************************************************\n"
  }
}

proc xps_write_elaboration_cmds { simulator fh_unix fh_win dir} {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  variable l_compile_order_files
  set design_files $a_sim_vars(l_design_files)
  set top $a_sim_vars(s_top)

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "# RUN_STEP: <elaborate>"
    puts $fh_unix "elaborate()\n\{"
  } else {
    puts $fh_win "\nrem # RUN_STEP: <elaborate>"
    puts $fh_win ":elaborate"
  }

  if {[llength $l_compile_order_files] == 0} {
    if {$::tcl_platform(platform) == "unix"} {
      puts $fh_unix "# None (no sources present)"
    } else {
      puts $fh_win "rem # None (no sources present)"
    }
    return 0
  }
 
  switch -regexp -- $simulator {
    "xsim" {
      xps_write_xelab_cmdline $fh_unix $fh_win $dir
    }
    "modelsim" -
    "questa" {
      if {$::tcl_platform(platform) == "unix"} {
        puts $fh_unix "  source elaborate.do 2>&1 | tee -a elaborate.log"
      } else {
        puts $fh_win "call vsim -64 -c -do \"do \{elaborate.do\}\" -l elaborate.log"
      }
      xps_write_do_file_for_elaborate $simulator $dir
    }
    "ies" { 
      set top_lib [xps_get_top_library]
      set arg_list [list]
      xps_append_config_opts arg_list "ies" "ncelab"
      set arg_list [linsert $arg_list end "-logfile" "elaborate.log" "-timescale 1ps/1ps"]
      if { ! $a_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64bit"]
      }
      # design contains ax-bfm ip? insert bfm library
      if { [xps_is_axi_bfm] } {
        set simulator_lib [xps_get_bfm_lib $simulator]
        if { {} != $simulator_lib } {
          set arg_list [linsert $arg_list 0 "-loadvpi \"$simulator_lib:xilinx_register_systf\""]
        } else {
          send_msg_id exportsim-Tcl-020 "CRITICAL WARNING" \
            "Failed to locate the simulator library from 'XILINX_VIVADO' environment variable. Library does not exist.\n"
        }
      }
      puts $fh_unix "  opts=\"[join $arg_list " "]\""
      set arg_list [list]
      if { [xps_contains_verilog] } {
        lappend arg_list "-libname unisims_ver"
        lappend arg_list "-libname unimacro_ver"
      }
      lappend arg_list "-libname secureip"
      foreach lib [xps_get_compile_order_libs] {
        if {[string length $lib] == 0} { continue; }
        lappend arg_list "-libname"
        lappend arg_list "[string tolower $lib]"
      }
      puts $fh_unix "  libs=\"[join $arg_list " "]\""

      set arg_list [list "ncelab" "\$opts"]
      if { [xps_is_fileset $a_sim_vars(sp_tcl_obj)] } {
        set vhdl_generics [list]
        set vhdl_generics [get_property vhdl_generic [get_filesets $a_sim_vars(fs_obj)]]
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
      puts $fh_unix "  $cmd_str"
    }
    "vcs" {
      set top_lib [xps_get_top_library]
      set arg_list [list]
      xps_append_config_opts arg_list "vcs" "vcs"
      set arg_list [linsert $arg_list end "-debug_pp" "-t" "ps" "-licqueue" "-l" "elaborate.log"]
      if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-full64"] }
      # design contains ax-bfm ip? insert bfm library
      if { [xps_is_axi_bfm] } {
        set simulator_lib [xps_get_bfm_lib $simulator]
        if { {} != $simulator_lib } {
          set arg_list [linsert $arg_list 0 "-load \"$simulator_lib:xilinx_register_systf\""]
        } else {
          send_msg_id exportsim-Tcl-020 "CRITICAL WARNING" \
            "Failed to locate the simulator library from 'XILINX_VIVADO' environment variable. Library does not exist.\n"
        }
      }
      puts $fh_unix "  opts=\"[join $arg_list " "]\"\n"
      set arg_list [list "vcs" "\$opts" "${top_lib}.$a_sim_vars(s_top)"]
      if { [xps_contains_verilog] } {
        lappend arg_list "${top_lib}.glbl"
      }
      lappend arg_list "-o"
      lappend arg_list "$a_sim_vars(s_top)_simv"
      set cmd_str [join $arg_list " "]
      puts $fh_unix "  $cmd_str"
    }
  }
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "\}\n"
  } else {
    puts $fh_win "goto:eof"
  }
  return 0
}
 
proc xps_write_simulation_cmds { simulator fh_unix fh_win dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  variable l_compile_order_files

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "# RUN_STEP: <simulate>"
    puts $fh_unix "simulate()\n\{"
  } else {
    puts $fh_win "\nrem # RUN_STEP: <simulate>"
    puts $fh_win ":simulate"
  }
  if {[llength $l_compile_order_files] == 0} {
    if {$::tcl_platform(platform) == "unix"} {
      puts $fh_unix "# None (no sources present)"
    } else {
      puts $fh_win "rem # None (no sources present)"
    }
    return 0
  }
 
  switch -regexp -- $simulator {
    "xsim" {
      xps_write_xsim_cmdline $fh_unix $fh_win $dir
    }
    "modelsim" -
    "questa" {
      set cmd_str "vsim -64 -c -do \"do \{$a_sim_vars(do_filename)\}\" -l simulate.log"
      if {$::tcl_platform(platform) == "unix"} {
        puts $fh_unix "  $cmd_str"
      } else {
        puts $fh_win "call $cmd_str"
      }
      xps_write_do_file_for_simulate $simulator $dir
    }
    "ies" { 
      set top_lib [xps_get_top_library]
      set arg_list [list "-logfile" "simulate.log"]
      if { !$a_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64bit"]
      }
      puts $fh_unix "  opts=\"[join $arg_list " "]\""
      set arg_list [list]
      lappend arg_list "ncsim"
      xps_append_config_opts arg_list $simulator "ncsim"
      lappend arg_list "\$opts" "${top_lib}.$a_sim_vars(s_top)" "-input" "$a_sim_vars(do_filename)"
      set cmd_str [join $arg_list " "]
      puts $fh_unix "  $cmd_str"
    }
    "vcs" {
      set arg_list [list]
      xps_append_config_opts arg_list $simulator "simv"
      lappend arg_list "-ucli" "-licqueue" "-l" "simulate.log"
      puts $fh_unix "  opts=\"[join $arg_list " "]\""
      puts $fh_unix ""
      set arg_list [list "./$a_sim_vars(s_top)_simv" "\$opts" "-do" "$a_sim_vars(do_filename)"]
      set cmd_str [join $arg_list " "]
      puts $fh_unix "  $cmd_str"
    }
  }
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "\}"
  } else {
    puts $fh_win "goto:eof"
  } 
  return 0
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
    send_msg_id exportsim-Tcl-044 ERROR "Failed to open file to write ($file)\n"
    return 1
  }
  close $fh
}

proc xps_find_files { src_files_arg filter dir } {
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
        set file "[xps_resolve_file_path $file $dir]"
      } else {
        set file "[xps_get_relative_file_path $file $dir]"
      }
      lappend src_files $file
    }
  } elseif { [xps_is_fileset $tcl_obj] } {
    set filesets       [list]

    lappend filesets $a_sim_vars(fs_obj)
    set linked_src_set {}
    if { ({SimulationSrcs} == [get_property fileset_type $a_sim_vars(fs_obj)]) } {
      set linked_src_set [get_property "SOURCE_SET" $a_sim_vars(fs_obj)]
    }
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
          set file "[xps_resolve_file_path $file $dir]"
        } else {
          set file "[xps_get_relative_file_path $file $dir]"
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

proc xps_get_compiler { simulator file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set compiler ""
  if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } {
    switch -regexp -- $simulator {
      "xsim"     { set compiler "vhdl" }
      "modelsim" -
      "questa"   { set compiler "vcom" }
      "ies"      { set compiler "ncvhdl" }
      "vcs"      { set compiler "vhdlan" }
    }
  } elseif { ({Verilog} == $file_type) || ({SystemVerilog} == $file_type) || ({Verilog Header} == $file_type) } {
    switch -regexp -- $simulator {
      "xsim"     {
        set compiler "verilog"
        if { {SystemVerilog} == $file_type } {
          set compiler "sv"
        }
      }
      "modelsim" -
      "questa"   { set compiler "vlog" }
      "ies"      { set compiler "ncvlog" }
      "vcs"      { set compiler "vlogan" }
    }
  }
  return $compiler
}
 
proc xps_append_compiler_options { simulator launch_dir tool file_type global_files_str opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  variable a_sim_vars
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  switch $tool {
    "vcom" {
      set s_64bit {-64}
      set arg_list [list $s_64bit]
      #lappend arg_list "-93"
      xps_append_config_opts arg_list $simulator "vcom"
      set cmd_str [join $arg_list " "]
      lappend opts $cmd_str
    }
    "vlog" {
      set s_64bit {-64}
      set arg_list [list $s_64bit]
      xps_append_config_opts arg_list $simulator "vlog"
      set cmd_str [join $arg_list " "]
      lappend opts $cmd_str
      if { [string equal -nocase $file_type "systemverilog"] } {
        lappend opts "-sv"
      }
    }
    "ncvhdl" { 
       lappend opts "\$opts_vhd"
    }
    "vhdlan" {
       lappend opts "\$opts_vhd"
    }
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
        set verilog_defines [get_property verilog_define [get_filesets $a_sim_vars(fs_obj)]]
        if { [llength $verilog_defines] > 0 } {
          xps_append_define_generics $verilog_defines $tool opts
        }
      }
 
      # include dirs
      foreach dir [concat [xps_get_verilog_incl_dirs $simulator $launch_dir] [xps_get_verilog_incl_file_dirs $simulator $launch_dir {}]] {
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

proc xps_contains_system_verilog {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set design_files $a_sim_vars(l_design_files)
  set b_sys_verilog_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {#}] 1]
    if { {SystemVerilog} == $type } {
      set b_sys_verilog_srcs 1
    }
  }
  return $b_sys_verilog_srcs 
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
  set b_single_ip 0
  if { [xps_is_ip $a_sim_vars(sp_tcl_obj)] } {
    set ip [file root [file tail $a_sim_vars(sp_tcl_obj)]]
    # is user-disabled? or auto_disabled? skip
    if { ({0} == [get_property is_enabled [get_files -all ${ip}.xci]]) ||
         ({1} == [get_property is_auto_disabled [get_files -all ${ip}.xci]]) } {
      return
    }
    dict set regen_ip $ip d_targets [get_property delivered_targets [get_ips -quiet $ip]]
    dict set regen_ip $ip generated [get_property is_ip_generated [get_ips -quiet $ip]]
    dict set regen_ip $ip generated_sim [get_property is_ip_generated_sim [lindex [get_files -all -quiet ${ip}.xci] 0]]
    dict set regen_ip $ip stale [get_property stale_targets [get_ips -quiet $ip]]
    set b_single_ip 1
  } else {
    foreach ip [get_ips -quiet] {
      # is user-disabled? or auto_disabled? continue
      if { ({0} == [get_property is_enabled [get_files -all ${ip}.xci]]) ||
           ({1} == [get_property is_auto_disabled [get_files -all ${ip}.xci]]) } {
        continue
      }
      dict set regen_ip $ip d_targets [get_property delivered_targets [get_ips -quiet $ip]]
      dict set regen_ip $ip generated [get_property is_ip_generated $ip]
      dict set regen_ip $ip generated_sim [get_property is_ip_generated_sim [lindex [get_files -all -quiet ${ip}.xci] 0]]
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
      if { {0} == $generated_sim } {
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
    if { $b_single_ip } {
      send_msg_id exportsim-Tcl-045 "CRITICAL WARNING" \
         "The '$ip' IP have not generated output products yet or have subsequently been updated, making the current\n\
         output products out-of-date. It is strongly recommended that this IP be re-generated and then this script run again to get a complete output.\n\
         To generate the output products please see 'generate_target' Tcl command.\n\
         $msg_txt"
    } else {
      send_msg_id exportsim-Tcl-045 "CRITICAL WARNING" \
         "The following IPs have not generated output products yet or have subsequently been updated, making the current\n\
         output products out-of-date. It is strongly recommended that these IPs be re-generated and then this script run again to get a complete output.\n\
         To generate the output products please see 'generate_target' Tcl command.\n\
         $msg_txt"
    }
  }
}

proc xps_print_usage { fh_unix fh_win } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "# Script usage"
    puts $fh_unix "usage()"
    puts $fh_unix "\{"
    puts $fh_unix "  msg=\"Usage: $a_sim_vars(s_script_filename).sh \[-help\]\\n\\"
    puts $fh_unix "Usage: $a_sim_vars(s_script_filename).sh \[-noclean_files\]\\n\\"
    puts $fh_unix "Usage: $a_sim_vars(s_script_filename).sh \[-reset_run\]\\n\\n\\\n\\"
    puts $fh_unix "\[-help\] -- Print help\\n\\n\\"
    puts $fh_unix "\[-noclean_files\] -- Do not remove simulator generated files from the previous run\\n\\n\\"
    puts $fh_unix "\[-reset_run\] -- Recreate simulator setup files and library mappings for a clean run. The generated files\\n\\"
    puts $fh_unix "\\t\\tfrom the previous run will be removed automatically.\\n\""
    puts $fh_unix "  echo -e \$msg"
    puts $fh_unix "  exit 1"
    puts $fh_unix "\}"
    puts $fh_unix ""
  } else {
    puts $fh_win "\nrem Script usage"
    puts $fh_win ":usage"
    puts $fh_win "set NL=^& echo."
    puts $fh_win "set msg1=Usage: $a_sim_vars(s_script_filename).bat \[-help\]"
    puts $fh_win "set msg2=Usage: $a_sim_vars(s_script_filename).bat \[-noclean_files\]"
    puts $fh_win "set msg3=Usage: $a_sim_vars(s_script_filename).bat \[-reset_run\]"
    puts $fh_win "set msg4=\[-help\] -- Print help"
    puts $fh_win "set msg5=\[-noclean_files\] -- Do not remove simulator generated files from the previous run"
    puts $fh_win "set msg6=\[-reset_run\] -- Recreate simulator setup files and library mappings for a clean run. The generated files"
    puts $fh_win "set msg7=                from the previous run will be removed automatically."
    puts $fh_win "echo %msg1%%NL%%msg2%%NL%%msg3%%NL%%NL%%msg4%%NL%%NL%%msg5%%NL%%NL%%msg6%%NL%%msg7%%NL%"
    puts $fh_win "exit 0"
    puts $fh_win "goto:eof"
  }
}

proc xps_write_libs_unix { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  switch $simulator {
    "modelsim" -
    "questa" {
      puts $fh_unix "# Copy modelsim.ini file"
      puts $fh_unix "copy_setup_file()"
      puts $fh_unix "\{"
      puts $fh_unix "  file=\"modelsim.ini\""
    }
    "ies" -
    "vcs" {
      puts $fh_unix "# Create design library directory paths and define design library mappings in cds.lib"
      puts $fh_unix "create_lib_mappings()"
      puts $fh_unix "\{"
      set libs [list]
      foreach lib [xps_get_compile_order_libs] {
        if {[string length $lib] == 0} { continue; }
        if { ({work} == $lib) && ({vcs} == $simulator) } { continue; }
        lappend libs [string tolower $lib]
      }
      puts $fh_unix "  libs=([join $libs " "])"
      switch -regexp -- $simulator {
        "ies"      { puts $fh_unix "  file=\"cds.lib\"" }
        "vcs"      { puts $fh_unix "  file=\"synopsys_sim.setup\"" }
      }
      puts $fh_unix "  dir=\"$simulator\"\n"
      puts $fh_unix "  if \[\[ -e \$file \]\]; then"
      puts $fh_unix "    rm -f \$file"
      puts $fh_unix "  fi\n"
      puts $fh_unix "  if \[\[ -e \$dir \]\]; then"
      puts $fh_unix "    rm -rf \$dir"
      puts $fh_unix "  fi"
      puts $fh_unix ""
      puts $fh_unix "  touch \$file"
    }
  }

  if { {xsim} == $simulator } {
    # no check required
  } else {
    # is -lib_map_path specified and point to valid location?
    if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
      set a_sim_vars(s_lib_map_path) [file normalize $a_sim_vars(s_lib_map_path)]
      set compiled_lib_dir $a_sim_vars(s_lib_map_path)
      if { ![file exists $compiled_lib_dir] } {
        [catch {send_msg_id exportsim-Tcl-046 ERROR "Compiled simulation library directory path does not exist:$compiled_lib_dir\n"}]
        puts $fh_unix "  lib_map_path=\"<SPECIFY_COMPILED_LIB_PATH>\""
      } else {
        puts $fh_unix "  lib_map_path=\"$compiled_lib_dir\""
      }
    } else {
      #send_msg_id exportsim-Tcl-047 WARNING \
      #   "The pre-compiled simulation library directory path was not specified (-lib_map_path), which may\n\
      #   cause simulation errors when running this script. Please refer to the generated script header section for more details."
      puts $fh_unix "  lib_map_path=\"<SPECIFY_COMPILED_LIB_PATH>\""
    }
  }
 
  switch -regexp -- $simulator {
    "modelsim" -
    "questa" {
      puts $fh_unix "  src_file=\"\$lib_map_path/\$file\""
      puts $fh_unix "  if \[\[ ! -e \$file \]\]; then"
      puts $fh_unix "    cp \$src_file ."
      puts $fh_unix "  fi"
      puts $fh_unix "\}\n"
    }
    "ies" {
      set file "cds.lib"
      puts $fh_unix "  incl_ref=\"INCLUDE \$lib_map_path/$file\""
      puts $fh_unix "  echo \$incl_ref >> \$file"
    }
    "vcs" {
      set file "synopsys_sim.setup"
      puts $fh_unix "  incl_ref=\"OTHERS=\$lib_map_path/$file\""
      puts $fh_unix "  echo \$incl_ref >> \$file"
    }
  }

  switch -regexp -- $simulator {
    "ies" -
    "vcs" {
      puts $fh_unix ""
      puts $fh_unix "  for (( i=0; i<\$\{#libs\[*\]\}; i++ )); do"
      puts $fh_unix "    lib=\"\$\{libs\[i\]\}\""
      puts $fh_unix "    lib_dir=\"\$dir/\$lib\""
      puts $fh_unix "    if \[\[ ! -e \$lib_dir \]\]; then"
      puts $fh_unix "      mkdir -p \$lib_dir"
    }
  }

  switch -regexp -- $simulator {
    "ies"      { puts $fh_unix "      mapping=\"DEFINE \$lib \$dir/\$lib\"" }
    "vcs"      { puts $fh_unix "      mapping=\"\$lib : \$dir/\$lib\"" }
  }

  switch -regexp -- $simulator {
    "ies" -
    "vcs" {
      puts $fh_unix "      echo \$mapping >> \$file"
      puts $fh_unix "    fi"
      puts $fh_unix "  done"
      puts $fh_unix "\}"
      puts $fh_unix ""
    }
  }
}

proc xps_write_libs_win { simulator fh_win } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set b_compiled_lib_path_specified 0
  switch $simulator {
    "modelsim" -
    "questa" {
      puts $fh_win "\nrem # Copy modelsim.ini file"
      puts $fh_win ":copy_setup_file"
      puts $fh_win "set file=modelsim.ini"
    }
  }

  if { {xsim} == $simulator } {
    # no check required
  } else {
    # is -lib_map_path specified and point to valid location?
    if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
      set a_sim_vars(s_lib_map_path) [file normalize $a_sim_vars(s_lib_map_path)]
      set compiled_lib_dir $a_sim_vars(s_lib_map_path)
      if { ![file exists $compiled_lib_dir] } {
        [catch {send_msg_id exportsim-Tcl-046 ERROR "Compiled simulation library directory path does not exist:$compiled_lib_dir\n"}]
        puts $fh_win "set lib_map_path=\"SPECIFY_COMPILED_LIB_PATH\""
      } else {
        set clib_dir [string map {/ \\} $compiled_lib_dir]
        puts $fh_win "set lib_map_path=$clib_dir"
        set b_compiled_lib_path_specified 1
      }
    } else {
      send_msg_id exportsim-Tcl-047 WARNING \
         "The pre-compiled simulation library directory path was not specified (-lib_map_path), which may\n\
         cause simulation errors when running this script. Please refer to the generated script header section for more details."
      puts $fh_win "set lib_map_path=\"SPECIFY_COMPILED_LIB_PATH\""
    }
  }
 
  switch -regexp -- $simulator {
    "modelsim" -
    "questa" {
      puts $fh_win "set src_file=%lib_map_path%\\%file%"
      puts $fh_win "if not exist %file% ("
      if { $b_compiled_lib_path_specified } {
        puts $fh_win "  copy /Y %src_file% . >nul"
      } else {
        puts $fh_win "  rem copy /Y %src_file% . >nul"
      }
      puts $fh_win ")"
      puts $fh_win "goto:eof"
    }
  }
}

proc xps_create_ies_vcs_do_file { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set do_file [file join $dir $a_sim_vars(do_filename)]
  set fh_do 0
  if {[catch {open $do_file w} fh_do]} {
    send_msg_id exportsim-Tcl-048 ERROR "failed to open file to write ($do_file)\n"
  } else {
    switch -regexp -- $simulator {
      "ies"      {
        puts $fh_do "set pack_assert_off {numeric_std std_logic_arith}"
        puts $fh_do "\ndatabase -open waves -into waves.shm -default"
        puts $fh_do "probe -create -shm -all -variables -depth 1\n"
        puts $fh_do "run"
        puts $fh_do "exit"
      }
      "vcs"      {
        puts $fh_do "run"
        puts $fh_do "quit"
      }
    }
  }
  close $fh_do
}

proc xps_write_xsim_prj { dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set top $a_sim_vars(s_top)
  if { [xps_contains_verilog] } {
    set filename "vlog.prj"
    set file [file normalize [file join $dir $filename]]
    xps_write_prj $dir $file "VERILOG" $srcs_dir
  }

  if { [xps_contains_vhdl] } {
    set filename "vhdl.prj"
    set file [file normalize [file join $dir $filename]]
    xps_write_prj $dir $file "VHDL" $srcs_dir
  }
}

proc xps_write_prj { launch_dir file ft srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set global_files_str {}
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  set opts [list]
  if { {VERILOG} == $ft } {
    # include_dirs
    set unique_incl_dirs [list]
    set incl_dir_str [xps_resolve_incldir [get_property "INCLUDE_DIRS" [get_filesets $a_sim_vars(fs_obj)]]]
    foreach incl_dir [split $incl_dir_str "#"] {
      if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
        lappend unique_incl_dirs $incl_dir
        if { $a_sim_vars(b_absolute_path) } {
          set incl_dir "[xps_resolve_file_path $incl_dir $launch_dir]"
        } else {
          set incl_dir "[xps_get_relative_file_path $incl_dir $launch_dir]"
        }
        lappend opts "-i \"$incl_dir\""
      }
    }
    # --include
    set prefix_ref_dir "false"
    foreach incl_dir [xps_get_include_file_dirs $launch_dir $global_files_str $prefix_ref_dir] {
      set incl_dir [string map {\\ /} $incl_dir]
      lappend opts "--include \"$incl_dir\""
    }
    # -d (verilog macros)
    set v_defines [get_property "VERILOG_DEFINE" [get_filesets $a_sim_vars(fs_obj)]]
    if { [llength $v_defines] > 0 } {
      foreach element $v_defines {
        set key_val_pair [split $element "="]
        set name [lindex $key_val_pair 0]
        set val  [lindex $key_val_pair 1]
        set str "$name="
        if { [string length $val] > 0 } {
          set str "$str$val"
        }
        lappend opts "-d \"$str\""
      }
    }
  }

  set opts_str [join $opts " "]

  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-049 "Failed to open file to write ($file)\n"
    return 1
  }

  set log "compile.log"
  set b_first true
  set prev_lib  {}
  set prev_file_type {}
  set b_redirect false
  set b_appended false

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
        set target_dir $srcs_dir
        if { {} != $ip_file } {
          set ip_name [file rootname [file tail $ip_file]]
          set proj_src_filename "ip/$ip_name/$proj_src_filename"
          set ip_dir [file join $srcs_dir "ip" $ip_name] 
          if { ![file exists $ip_dir] } {
            if {[catch {file mkdir $ip_dir} error_msg] } {
              send_msg_id exportsim-Tcl-050 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
              return 1
            }
          }
          set target_dir $ip_dir
        }
        if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
          send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
        }
      }

      if { $a_sim_vars(b_xport_src_files) } {
        puts $fh "$cmd_str $proj_src_filename ${opts_str}"
      } else {
        puts $fh "$cmd_str $src_file ${opts_str}"
      }
      # TODO: this does not work for verilog defines
      #if { $b_first } {
      #  set b_first false
      #  if { $a_sim_vars(b_xport_src_files) } {
      #    xps_set_initial_cmd "xsim" $fh $cmd_str $proj_src_filename $file_type $lib ${opts_str} prev_file_type prev_lib log
      #  } else {
      #    xps_set_initial_cmd "xsim" $fh $cmd_str $src_file $file_type $lib ${opts_str} prev_file_type prev_lib log
      #  }
      #} else {
      #  if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
      #    puts $fh "$src_file \\"
      #    set b_redirect true
      #  } else {
      #    puts $fh ""
      #    if { $a_sim_vars(b_xport_src_files) } {
      #      xps_set_initial_cmd "xsim" $fh $cmd_str $proj_src_filename $file_type $lib ${opts_str} prev_file_type prev_lib log
      #    } else {
      #      xps_set_initial_cmd "xsim" $fh $cmd_str $src_file $file_type $lib ${opts_str} prev_file_type prev_lib log
      #    }
      #    set b_appended true
      #  }
      #}
    }
  }

  if { {VERILOG} == $ft } {
    puts $fh "\nverilog [xps_get_top_library] \"glbl.v\""
    puts $fh "\nnosort"
  }

  close $fh
}

proc xps_write_prj_single_step { dir srcs_dir} {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set filename "run.prj"
  set file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-052 "Failed to open file to write ($file)\n"
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
      set target_dir $srcs_dir
      if { {} != $ip_file } {
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "ip/$ip_name/$proj_src_filename"
        set ip_dir [file join $srcs_dir "ip" $ip_name] 
        if { ![file exists $ip_dir] } {
          if {[catch {file mkdir $ip_dir} error_msg] } {
            send_msg_id exportsim-Tcl-053 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
            return 1
          }
        }
        set target_dir $ip_dir
      }
      if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
        send_msg_id exportsim-Tcl-054 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
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

proc xps_write_do_file_for_compile { simulator dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set filename "compile.do"
  if { $a_sim_vars(b_single_step) } {
    set filename "run.do"
  }
  set do_file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id exportsim-Tcl-055 ERROR "Failed to open file to write ($do_file)\n"
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
      set target_dir $srcs_dir
      if { {} != $ip_file } {
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "ip/$ip_name/$proj_src_filename"
        set ip_dir [file join $srcs_dir "ip" $ip_name] 
        if { ![file exists $ip_dir] } {
          if {[catch {file mkdir $ip_dir} error_msg] } {
            send_msg_id exportsim-Tcl-056 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
            return 1
          }
        }
        set target_dir $ip_dir
      }
      if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
        send_msg_id exportsim-Tcl-057 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
      }
    }

    if { $b_first } {
      set b_first false
      xps_set_initial_cmd $simulator $fh $cmd_str $src_file $file_type $lib {} prev_file_type prev_lib log
    } else {
      if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
        puts $fh "$src_file \\"
        set b_redirect true
      } else {
        puts $fh ""
        xps_set_initial_cmd $simulator $fh $cmd_str $src_file $file_type $lib {} prev_file_type prev_lib log
        set b_appended true
      }
    }
  }

  if { (!$b_redirect) || (!$b_appended) } {
    puts $fh ""
  }

  # compile glbl file
  puts $fh "\nvlog -work [xps_get_top_library] \"glbl.v\""
  if { $a_sim_vars(b_single_step) } {
    set cmd_str [xps_get_simulation_cmdline_modelsim]
    puts $fh "\n$cmd_str"
  }
  if {$::tcl_platform(platform) != "unix"} {
    puts $fh "\nquit -f"
  }
  close $fh
}

proc xps_write_do_file_for_elaborate { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set filename "elaborate.do"
  set do_file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id exportsim-Tcl-058 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  switch $simulator {
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
      set arg_list [list]
      lappend arg_list "vopt"
      xps_append_config_opts arg_list $simulator "vopt"
      lappend arg_list $t_opts
      lappend arg_list "$d_libs"
      set top $a_sim_vars(s_top)
      lappend arg_list "${top_lib}.$top"
      if { [xps_contains_verilog] } {
        lappend arg_list "${top_lib}.glbl"
      }
      lappend arg_list "-o"
      lappend arg_list "${top}_opt"
      set cmd_str [join $arg_list " "]
      puts $fh "$cmd_str"
    }
  }
  close $fh
}

proc xps_write_do_file_for_simulate { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set b_absolute_path $a_sim_vars(b_absolute_path)
  set filename $a_sim_vars(do_filename)
  set do_file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id exportsim-Tcl-059 ERROR "Failed to open file to write ($do_file)\n"
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
  set udo_filename $top;append udo_filename ".udo"
  set udo_file [file normalize [file join $dir $udo_filename]]
  xps_create_udo_file $udo_file
  puts $fh "do \{$top.udo\}"
  puts $fh "\nrun -all"
  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\""
  xps_find_files tcl_src_files $filter $dir
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
  close $fh
}

proc xps_get_simulation_cmdline_modelsim {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set args [list]
  xps_append_config_opts args "modelsim" "vsim"
  if { !$a_sim_vars(b_32bit) } {
    set args [linsert $args end "-64"]
  }
  lappend args "-voptargs=\"+acc\"" "-t 1ps"
  if { $a_sim_vars(b_single_step) } {
    set args [linsert $args 1 "-c"]
  }
  if { $a_sim_vars(b_single_step) } {
    set args [linsert $args end "-do \"run -all;quit -force\""]
  }
  set vhdl_generics [list]
  set vhdl_generics [get_property "GENERIC" [get_filesets $a_sim_vars(fs_obj)]]
  if { [llength $vhdl_generics] > 0 } {
    xps_append_generics $vhdl_generics args
  }
  if { [xps_is_axi_bfm] } {
    set simulator_lib [xps_get_bfm_lib "modelsim"]
    if { {} != $simulator_lib } {
      set args [linsert $args end "-pli \"$simulator_lib\""]
    } else {
      send_msg_id exportsim-Tcl-020 "CRITICAL WARNING" \
        "Failed to locate the simulator library from 'XILINX_VIVADO' environment variable. Library does not exist.\n"
    }
  }
  set t_opts [join $args " "]
  set args [list]
  if { [xps_contains_verilog] } {
    set args [linsert $args end "-L" "unisims_ver"]
    set args [linsert $args end "-L" "unimacro_ver"]
  }
  set args [linsert $args end "-L" "secureip"]
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
  set simulator "questa"
  set args [list]
  lappend args "vsim"
  xps_append_config_opts args "questa" "vsim"
  lappend args "-t 1ps"
  if { [xps_is_axi_bfm] } {
    set simulator_lib [xps_get_bfm_lib $simulator]
    if { {} != $simulator_lib } {
      set args [linsert $args end "-pli \"$simulator_lib\""]
    } else {
      send_msg_id exportsim-Tcl-020 "CRITICAL WARNING" \
        "Failed to locate the simulator library from 'XILINX_VIVADO' environment variable. Library does not exist.\n"
    }
  }
  set default_lib [get_property "DEFAULT_LIB" [current_project]]
  lappend args "-lib"
  lappend args $default_lib
  lappend args "$a_sim_vars(s_top)_opt"
  set cmd_str [join $args " "]
  return $cmd_str
}

proc xps_write_xelab_cmdline { fh_unix fh_win launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set args [list "xelab"]
  xps_append_config_opts args "xsim" "xelab"
  lappend args "-wto [get_property ID [current_project]]"
  if { !$a_sim_vars(b_32bit) } { lappend args "-m64" }
  set prefix_ref_dir "false"
  foreach incl_dir [xps_get_verilog_incl_file_dirs "xsim" $launch_dir $a_sim_vars(global_files_value) $prefix_ref_dir] {
    set dir [string map {\\ /} $incl_dir]
    lappend args "--include \"$dir\""
  }
  set unique_incl_dirs [list]
  foreach incl_dir [get_property "INCLUDE_DIRS" $a_sim_vars(fs_obj)] {
    if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
      lappend unique_incl_dirs $incl_dir
      lappend args "-i $incl_dir"
    }
  }
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
  lappend args "--snapshot [xps_get_snapshot]"
  foreach top [xps_get_tops] {
    lappend args "$top"
  }
  if { [xps_contains_verilog] } {
    if { ([lsearch [xps_get_tops] {glbl}] == -1) } {
      set top_lib [xps_get_top_library]
      lappend args "${top_lib}.glbl"
    }
  }
  if { $a_sim_vars(b_single_step) } {
    set filename "run.prj"
    lappend args "-prj $filename"
    lappend args "-R"
  }
  if { $a_sim_vars(b_single_step) } {
    lappend args "2>&1 | tee -a run.log"
  } else {
    lappend args "-log elaborate.log"
  }
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "  [join $args " "]"
  } else {
    puts $fh_win "call [join $args " "]"
  }
}

proc xps_write_xsim_cmdline { fh_unix fh_win dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set args [list "xsim"]
  xps_append_config_opts args "xsim" "xsim"
  lappend args [xps_get_snapshot]
  lappend args "-key"
  lappend args "\{[xps_get_obj_key]\}"
  set cmd_file "cmd.tcl"
  if { $a_sim_vars(b_single_step) } {
    # 
  } else {
    xps_write_xsim_tcl_cmd_file $dir $cmd_file
  }
  lappend args "-tclbatch"
  lappend args "$cmd_file"
  if { $a_sim_vars(b_single_step) } {
    lappend args "2>&1 | tee -a run.log"
  } else {
    set log_file "simulate";append log_file ".log"
    lappend args "-log"
    lappend args "$log_file"
  }
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "  [join $args " "]"
  } else {
    puts $fh_win "call [join $args " "]"
  }
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

proc xps_write_xsim_tcl_cmd_file { dir filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set file [file normalize [file join $dir $filename]]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-063 ERROR "Failed to open file to write ($file)\n"
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
  puts $fh "\nrun -all"

  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\""
  xps_find_files tcl_src_files $filter $dir
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
  if { ![string match "/*" $uut] } {
    set uut "/$uut"
  }
  if { [string match "*/" $uut] } {
    set uut "${uut}*"
  }
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

proc xps_write_glbl { fh_unix fh_win } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
  set glbl_file [file normalize [file join $data_dir "verilog/src/glbl.v"]]

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "# Copy glbl.v file into run directory"
    puts $fh_unix "copy_glbl_file()"
    puts $fh_unix "\{"
    puts $fh_unix "  glbl_file=\"glbl.v\""
    puts $fh_unix "  src_file=\"$glbl_file\""
    puts $fh_unix "  if \[\[ ! -e \$glbl_file \]\]; then"
    puts $fh_unix "    cp \$src_file ."
    puts $fh_unix "  fi"
    puts $fh_unix "\}"
    puts $fh_unix ""
  } else {
    puts $fh_win "\nrem Copy glbl.v file into run directory"
    puts $fh_win ":copy_glbl_file"
    puts $fh_win "set glbl_file=glbl.v"
    set file [string map {/ \\} $glbl_file]
    puts $fh_win "set src_file=$file"
    puts $fh_win "if not exist %glbl_file% ("
    puts $fh_win "  copy /Y %src_file% %glbl_file% >nul"
    puts $fh_win ")"
    puts $fh_win "goto:eof"
  }
}

proc xps_write_reset { simulator fh_unix fh_win } {
  # Summary:
  # Argument Usage:
  # File handle
  # Return Value:
  # None 

  variable a_sim_vars

  set top $a_sim_vars(s_top)
  set file_list [list]
  set file_dir_list [list]
  set files [list]
  switch -regexp -- $simulator {
    "xsim" {
      set file_list [list "xelab.pb" "xsim.jou" "xvhdl.log" "xvlog.log" "compile.log" "elaborate.log" "simulate.log" \
                           "xelab.log" "xsim.log" "run.log" "xvhdl.pb" "xvlog.pb" "$a_sim_vars(s_top).wdb"]
      set file_dir_list [list "xsim.dir"]
    }
    "modelsim" -
    "questa" {
      set file_list [list "compile.log" "simulate.log" "vsim.wlf"]
      set file_dir_list [list "work" "msim"]
    }
    "ies" { 
      set file_list [list "ncsim.key" "irun.key" "ncvlog.log" "ncvhdl.log" "compile.log" "elaborate.log" "simulate.log" "run.log" "waves.shm"]
      set file_dir_list [list "INCA_libs"]
    }
    "vcs" {
      set file_list [list "ucli.key" "${top}_simv" \
                          "vlogan.log" "vhdlan.log" "compile.log" "elaborate.log" "simulate.log" \
                          ".vlogansetup.env" ".vlogansetup.args" ".vcs_lib_lock" "scirocco_command.log"]
      set file_dir_list [list "64" "AN.DB" "csrc" "${top}_simv.daidir"]
    }
  }
  set files [join $file_list " "]
  set files_dir [join $file_dir_list " "]

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "# Remove generated data from the previous run and re-create setup files/library mappings"
    puts $fh_unix "reset_run()"
    puts $fh_unix "\{"
    puts $fh_unix "  files_to_remove=($files $files_dir)"
    puts $fh_unix "  for (( i=0; i<\$\{#files_to_remove\[*\]\}; i++ )); do"
    puts $fh_unix "    file=\"\$\{files_to_remove\[i\]\}\""
    puts $fh_unix "    if \[\[ -e \$file \]\]; then"
    puts $fh_unix "      rm -rf \$file"
    puts $fh_unix "    fi"
    puts $fh_unix "  done"
    puts $fh_unix "\}"
    puts $fh_unix ""
  } else { 
    puts $fh_win "\nrem Remove generated data from the previous run and re-create setup files/library mappings"
    puts $fh_win ":reset_run"
    puts $fh_win "for %%x in ($files) do ("
    puts $fh_win "  if exist %%x ("
    puts $fh_win "    del /f %%x"
    puts $fh_win "  )"
    puts $fh_win ")"
    puts $fh_win "for %%x in ($files_dir) do ("
    puts $fh_win "  if exist %%x\. ("
    puts $fh_win "    rd /s /q \"%%x\" /s /q"
    puts $fh_win "  )"
    puts $fh_win ")"
    puts $fh_win "goto:eof"
  }
}

proc xps_write_setup { simulator fh_unix fh_win } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "# STEP: setup"
    puts $fh_unix "setup()\n\{"
    puts $fh_unix "  case \$1 in"
    puts $fh_unix "    \"-reset_run\" )"
    puts $fh_unix "      reset_run"
    puts $fh_unix "      echo -e \"INFO: Simulation run files deleted.\\n\""
    puts $fh_unix "      exit 0"
    puts $fh_unix "    ;;"
    puts $fh_unix "    \"-noclean_files\" )"
    puts $fh_unix "      # do not remove previous data"
    puts $fh_unix "    ;;"
    puts $fh_unix "    * )"
    switch -regexp -- $simulator {
      "modelsim" -
      "questa" {
        puts $fh_unix "     copy_setup_file"
      }
      "ies" -
      "vcs" {
        puts $fh_unix "     create_lib_mappings"
      }
    }
    switch -regexp -- $simulator {
      "ies" { puts $fh_unix "     touch hdl.var" }
    }
    if { [xps_contains_verilog] } {
      puts $fh_unix "     copy_glbl_file"
    }
    puts $fh_unix "  esac"
    puts $fh_unix ""
    puts $fh_unix "  # Add any setup/initialization commands here:-\n"
    puts $fh_unix "  # <user specific commands>\n"
    puts $fh_unix "\}\n"
  } else {
    puts $fh_win "\nrem RUN_STEP: <setup>"
    puts $fh_win ":setup"
    puts $fh_win "set msg=INFO: Simulation run files deleted."
    puts $fh_win "if \"%1\"==\"-reset_run\" ("
    puts $fh_win "  call:reset_run"
    puts $fh_win "  if \"%errorlevel%\"==\"1\" goto end"
    puts $fh_win "  echo. & echo %msg%"
    puts $fh_win "  exit 0"
    puts $fh_win ") else ("
    puts $fh_win "if \"%1\"==\"-noclean_files\" ("
    puts $fh_win "  rem do not remove previous data"
    puts $fh_win ") else ("
    switch -regexp -- $simulator {
      "modelsim" -
      "questa" {
        puts $fh_win "  call:copy_setup_file"
      }
      "ies" -
      "vcs" {
        puts $fh_win "  call:create_lib_mappings"
      }
    }
    switch -regexp -- $simulator {
      "ies" { puts $fh_win "  call::create_hdl_var" }
    }
    if { [xps_contains_verilog] } {
      puts $fh_win "  call:copy_glbl_file"
      puts $fh_win "  if \"%errorlevel%\"==\"1\" goto end"
    }
    puts $fh_win "))"
    puts $fh_win "\nrem Add any setup/initialization commands here:-"
    puts $fh_win "rem <user specific commands>"
    puts $fh_win "goto:eof"
  }
}

proc xps_write_main { fh_unix fh_win } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 2]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_unix "# Script info"
    puts $fh_unix "echo -e \"$a_sim_vars(s_script_filename).sh - Script generated by export_simulation ($version-id)\\n\"\n"
    puts $fh_unix "# Check command line args"
    puts $fh_unix "if \[\[ \$# > 1 \]\]; then"
    puts $fh_unix "  echo -e \"ERROR: invalid number of arguments specified\\n\""
    puts $fh_unix "  usage"
    puts $fh_unix "fi\n"
    puts $fh_unix "if \[\[ (\$# == 1 ) && (\$1 != \"-noclean_files\" && \$1 != \"-reset_run\" && \$1 != \"-help\" && \$1 != \"-h\") \]\]; then"
    puts $fh_unix "  echo -e \"ERROR: unknown option specified '\$1' (type \"$a_sim_vars(s_script_filename) -help\" for for more info)\""
    puts $fh_unix "  exit 1"
    puts $fh_unix "fi"
    puts $fh_unix ""
    puts $fh_unix "if \[\[ (\$1 == \"-help\" || \$1 == \"-h\") \]\]; then"
    puts $fh_unix "  usage"
    puts $fh_unix "fi\n"
  } else { 
    puts $fh_win "rem Script info"
    puts $fh_win "echo $a_sim_vars(s_script_filename).bat - Script generated by export_simulation ($version-id)"
    puts $fh_win "set /a cnt=0"
    puts $fh_win "for %%a in (%*) do set /a cnt+=1\n"
    puts $fh_win "rem Check command line args"
    puts $fh_win "if %cnt% gtr 1 ("
    puts $fh_win "  echo. & echo ERROR: invalid number of arguments specified & echo."
    puts $fh_win "  call:usage"
    puts $fh_win ")\n"
    puts $fh_win "if %cnt% equ 1 ("
    puts $fh_win "  if not \"%1\"==\"-noclean_files\" if not \"%1\"==\"-reset_run\" if not \"%1\"==\"-help\" if not \"%1\"==\"-h\" ("
    puts $fh_win "    echo ERROR: unknown option specified '%1'. Type \"$a_sim_vars(s_script_filename).bat -help\" for for more info."
    puts $fh_win "    exit 1"
    puts $fh_win "  )"
    puts $fh_win ")"
    puts $fh_win ""
    puts $fh_win "if \"%1\"==\"-help\" (call:usage)"
    puts $fh_win "if \"%1\"==\"-h\" (call:usage)\n"
    puts $fh_win "rem Launch script"
    puts $fh_win "call:run %1"
    puts $fh_win "exit 0"
    puts $fh_win "goto:eof"
  }
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
  variable a_sim_vars
  set platform {}
  set os $::tcl_platform(platform)
  if { {windows} == $os } {
    set platform "win64"
    if { $a_sim_vars(b_32bit) } {
      set platform "win32"
    }
  }
  if { {unix} == $os } {
    set platform "lnx64"
    if { $a_sim_vars(b_32bit) } {
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
    "modelsim" -
    "questa"   { set lib_name "libxil_vsim" }
    "ies"      { set lib_name "libxil_ncsim" }
    "vcs"      { set lib_name "libxil_vcs" }
  }

  set lib_name $lib_name$lib_extn
  if { {} != $xil } {
    append platform ".o"
    set lib_path {}
    send_msg_id exportsim-Tcl-116 INFO "Finding simulator library from 'XILINX_VIVADO'..."
    foreach path [split $xil $path_sep] {
      set file [file normalize [file join $path "lib" $platform $lib_name]]
      if { [file exists $file] } {
        send_msg_id exportsim-Tcl-117 INFO "Using library:'$file'"
        set simulator_lib $file
        break
      } else {
        send_msg_id exportsim-Tcl-118 WARNING "Library not found:'$file'"
      }
    }
  } else {
    send_msg_id exportsim-Tcl-064 ERROR "Environment variable 'XILINX_VIVADO' is not set!"
  }
  return $simulator_lib
}

proc xps_get_incl_files_from_ip { launch_dir tcl_obj } {
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
      set file "[xps_resolve_file_path $file $launch_dir]"
    } else {
      if { $a_sim_vars(b_xport_src_files) } {
        set file "\$ref_dir/incl"
      } else {
        set file "\$ref_dir/[xps_get_relative_file_path $file $launch_dir]"
      }
    }
    lappend incl_files $file
  }
  return $incl_files
}

proc xps_get_verilog_incl_file_dirs { simulator launch_dir global_files_str { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set dir_names [list]
  set vh_files [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xps_is_ip $tcl_obj] } {
    set vh_files [xps_get_incl_files_from_ip $launch_dir $tcl_obj]
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
    # set vh_file [extract_files -files [list "[file tail $vh_file]"] -base_dir $launch_dir/ip_files]
    set dir [file normalize [file dirname $vh_file]]

    if { $a_sim_vars(b_xport_src_files) } {
      set export_dir [file join $launch_dir "./srcs/incl"]
      if {[catch {file copy -force $vh_file $export_dir} error_msg] } {
        send_msg_id exportsim-Tcl-065 WARNING "Failed to copy file '$vh_file' to '$export_dir' : $error_msg\n"
      }
    }

    if { $a_sim_vars(b_absolute_path) } {
      set dir "[xps_resolve_file_path $dir $launch_dir]"
    } else {
      if { $ref_dir } {
        if { $a_sim_vars(b_xport_src_files) } {
          set dir "\$ref_dir/incl"
          if { ({modelsim} == $simulator) || ({questa} == $simulator) } {
            set dir "./srcs/incl"
          }
        } else {
          if { ({modelsim} == $simulator) || ({questa} == $simulator) } {
            set dir "./[xps_get_relative_file_path $dir $launch_dir]"
          } else {
            set dir "\$ref_dir/[xps_get_relative_file_path $dir $launch_dir]"
          }
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

proc xps_get_verilog_incl_dirs { simulator launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set dir_names [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  set incl_dir_str {}

  if { [xps_is_ip $tcl_obj] } {
    set incl_dir_str [xps_get_incl_dirs_from_ip $launch_dir $tcl_obj]
    set incl_dirs [split $incl_dir_str " "]
  } else {
    set incl_dir_str [xps_resolve_incldir [get_property "INCLUDE_DIRS" [get_filesets $tcl_obj]]]
    set incl_dirs [split $incl_dir_str "#"]
  }

  foreach vh_dir $incl_dirs {
    set dir [file normalize $vh_dir]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[xps_resolve_file_path $dir $launch_dir]"
    } else {
      if { $a_sim_vars(b_xport_src_files) } {
        set dir "\$ref_dir/incl"
        if { ({modelsim} == $simulator) || ({questa} == $simulator) } {
          set dir "./srcs/incl"
        }
      } else {
        if { ({modelsim} == $simulator) || ({questa} == $simulator) } {
          set dir "./[xps_get_relative_file_path $dir $launch_dir]"
        } else {
          set dir "\$ref_dir/[xps_get_relative_file_path $dir $launch_dir]"
        }
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

proc xps_get_incl_dirs_from_ip { launch_dir tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set ip_name [file tail $tcl_obj]
  set incl_dirs [list]
  set filter "FILE_TYPE == \"Verilog Header\""
  set vh_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    # set file [extract_files -files [list "[file tail $file]"] -base_dir $launch_dir/ip_files]
    set dir [file dirname $file]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[xps_resolve_file_path $dir $launch_dir]"
    } else {
      if { $a_sim_vars(b_xport_src_files) } {
        set dir "\$ref_dir/incl"
      } else {
        set dir "\$ref_dir/[xps_get_relative_file_path $dir $launch_dir]"
      }
    }
    lappend incl_dirs $dir
  }
  return $incl_dirs
}

proc xps_get_global_include_files { launch_dir incl_file_paths_arg incl_files_arg { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $incl_file_paths_arg incl_file_paths
  upvar $incl_files_arg      incl_files

  variable a_sim_vars
  set filesets       [list]
  set dir            $launch_dir
  set linked_src_set {}
  if { ([xps_is_fileset $a_sim_vars(sp_tcl_obj)]) && ({SimulationSrcs} == [get_property fileset_type $a_sim_vars(fs_obj)]) } {
    set linked_src_set [get_property "SOURCE_SET" $a_sim_vars(fs_obj)]
  }
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
          set incl_file_path "[xps_resolve_file_path $incl_file_path $launch_dir]"
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

proc xps_get_global_include_file_cmdstr { launch_dir incl_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $incl_files_arg incl_files
  variable a_sim_vars
  set file_str [list]
  foreach file $incl_files {
    # set file [extract_files -files [list "[file tail $file]"] -base_dir $launch_dir/ip_files]
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

proc xps_get_include_file_dirs { launch_dir global_files_str { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set dir_names [list]
  set vh_files [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xps_is_ip $tcl_obj] } {
    set vh_files [xps_get_incl_files_from_ip $launch_dir $tcl_obj]
  } else {
    set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"Verilog Header\""
    set vh_files [get_files -all -quiet -filter $filter]
  }

  # append global files (if any)
  if { {} != $global_files_str } {
    set global_files [split $global_files_str { }]
    foreach g_file $global_files {
      set g_file [string trim $g_file {\"}]
      lappend vh_files [get_files -quiet -all $g_file]
    }
  }

  foreach vh_file $vh_files {
    # set vh_file [extract_files -files [list "[file tail $vh_file]"] -base_dir $launch_dir/ip_files]
    set dir [file normalize [file dirname $vh_file]]
    if { $a_sim_vars(b_absolute_path) } {
      set dir "[xps_resolve_file_path $dir $launch_dir]"
     } else {
       if { $ref_dir } {
        set dir "\$origin_dir/[xps_get_relative_file_path $dir $launch_dir]"
      } else {
        set dir "[xps_get_relative_file_path $dir $launch_dir]"
      }
    }
    lappend dir_names $dir
  }
  if {[llength $dir_names] > 0} {
    return [lsort -unique $dir_names]
  }
  return $dir_names
}

proc xps_get_secureip_filelist {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
  set file [file normalize [file join $data_dir "secureip/secureip_cell.list.f"]]
  set fh 0
  if {[catch {open $file r} fh]} {
    send_msg_id exportsim-Tcl-066 ERROR "failed to open file to read ($file))\n"
    return 1
  }
  set data [read $fh]
  close $fh
  set filelist [list]
  set data [split $data "\n"]
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; } 
    set file_str [split [lindex [split $line {=}] 0] { }]
    set str_1 [string trim [lindex $file_str 0]]
    set str_2 [string trim [lindex $file_str 1]]
    #set str_2 [string map {\$XILINX_VIVADO $::env(XILINX_VIVADO)} $str_2]
    lappend filelist "$str_1 $str_2" 
  }
  return $filelist
}
}
