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
  # [-simulator <arg> = all]: Simulator for which the simulation script will be created (value=all|xsim|modelsim|questa|ies|xcelium|vcs|riviera|activehdl)
  # [-of_objects <arg> = None]: Export simulation script for the specified object
  # [-ip_user_files_dir <arg> = Empty]: Directory path to the exported IP/BD (Block Design) user files (for static, dynamic and data files)
  # [-ipstatic_source_dir <arg> = Empty]: Directory path to the exported IP/BD static files
  # [-lib_map_path <arg> = Empty]: Precompiled simulation library directory path. If not specified, then please follow the instructions in the generated script header to manually provide the simulation library mapping information.
  # [-script_name <arg> = top_module.sh]: Output script filename. If not specified, then a file with a default name will be created.
  # [-directory <arg> = export_sim]: Directory where the simulation script will be generated
  # [-runtime <arg> = Empty]: Run simulation for this time (default:full simulation run or until a logical break or finish condition)
  # [-define <arg> = Empty]: Read verilog defines from the list specified with this switch
  # [-generic <arg> = Empty]: Read vhdl generics from the list specified with this switch
  # [-include <arg> = Empty]: Read include directory paths from the list specified with this switch
  # [-use_ip_compiled_libs]: Reference pre-compiled IP static library during compilation. This switch requires -ip_user_files_dir and -ipstatic_source_dir switches as well for generating scripts using pre-compiled IP library.
  # [-absolute_path]: Make all file paths absolute
  # [-export_source_files]: Copy IP/BD design files to output directory
  # [-32bit]: Perform 32bit compilation
  # [-force]: Overwrite previous files

  # Return Value:
  # None

  # Categories: simulation, xilinxtclstore

  if { ![get_param "project.enableExportSimulation"] } {
    send_msg_id exportsim-Tcl-001 INFO \
      "This command is not available in the current release of Vivado and will be enhanced for future releases of Vivado to support all simulators, please contact Xilinx (FAE, tech support or forum) for more information.\n"
    return
  }

  variable a_sim_vars
  variable l_lib_map_path
  variable l_defines
  variable l_generics
  variable l_include_dirs

  xps_init_vars
  set a_sim_vars(options) [split $args " "]

  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-simulator"                { incr i;set a_sim_vars(s_simulator)           [string tolower [lindex $args $i]]                                        }
      "-lib_map_path"             { incr i;set l_lib_map_path                    [lindex $args $i];set a_sim_vars(b_lib_map_path_specified)              1 }
      "-of_objects"               { incr i;set a_sim_vars(sp_of_objects)         [lindex $args $i];set a_sim_vars(b_of_objects_specified)                1 }
      "-ip_user_files_dir"        { incr i;set a_sim_vars(s_ip_user_files_dir)   [lindex $args $i];set a_sim_vars(b_ip_user_files_dir_specified)         1 }
      "-ipstatic_source_dir"      { incr i;set a_sim_vars(s_ipstatic_source_dir) [lindex $args $i];set a_sim_vars(b_ipstatic_source_dir_specified)       1 }
      "-script_name"              { incr i;set a_sim_vars(s_script_filename)     [lindex $args $i];set a_sim_vars(b_script_specified)                    1 }
      "-directory"                { incr i;set a_sim_vars(s_xport_dir)           [lindex $args $i];set a_sim_vars(b_directory_specified)                 1 }
      "-runtime"                  { incr i;set a_sim_vars(s_runtime)             [lindex $args $i];set a_sim_vars(b_runtime_specified)                   1 }
      "-define"                   { incr i;set l_defines                         [lindex $args $i];set a_sim_vars(b_define_specified)                    1 }
      "-generic"                  { incr i;set l_generics                        [lindex $args $i];set a_sim_vars(b_generic_specified)                   1 }
      "-include"                  { incr i;set l_include_dirs                    [lindex $args $i];set a_sim_vars(b_include_specified)                   1 }
      "-32bit"                    { set a_sim_vars(b_32bit)                                                                                              1 }
      "-absolute_path"            { set a_sim_vars(b_absolute_path)                                                                                      1 }
      "-use_ip_compiled_libs"     { set a_sim_vars(b_use_static_lib)                                                                                     1 }
      "-export_source_files"      { set a_sim_vars(b_xport_src_files)                                                                                    1 }
      "-force"                    { set a_sim_vars(b_overwrite)                                                                                          1 }
      default {
        if { [regexp {^-} $option] } {
          send_msg_id exportsim-Tcl-003 ERROR "Unknown option '$option', please type 'export_simulation -help' for usage info.\n"
          return
        }
      }
    }
  }

  if { [xps_invalid_options] } {
    return
  }

  # control precompile flow
  xcs_control_pre_compile_flow a_sim_vars(b_use_static_lib)

  set b_print_compiled_simlib_msg 1

  # print cw for 3rd party simulator when -lib_map_path is not specified
  if { {all} != $a_sim_vars(s_simulator) } {
    if { {xsim} == $a_sim_vars(s_simulator) } {
      # no op
    } else {
      # is pre-compile flow with design containing IPs for a 3rd party simulator?
      if { ($a_sim_vars(b_use_static_lib)) && [xcs_is_ip_project] } {
        # is -lib_map_path not specified?
        if { !$a_sim_vars(b_lib_map_path_specified) } {
          send_msg_id exportsim-Tcl-056 "CRITICAL WARNING" \
           "Library mapping is not provided. The scripts will not be aware of pre-compiled libraries. It is highly recommended to use the -lib_map_path switch and point to the relevant simulator library mapping file path.\n"
          set b_print_compiled_simlib_msg 0
        }
      }
    }
  }

  if { ($a_sim_vars(b_use_static_lib)) && [xcs_is_ip_project] } {
    if { $b_print_compiled_simlib_msg } {
      send_msg_id exportsim-Tcl-040 INFO "Using compiled simulation libraries for IPs\n"
    }
  }

  xps_set_target_simulator

  set objs $a_sim_vars(sp_of_objects)
  if { $a_sim_vars(b_of_objects_specified) && ({} == $objs) } {
    send_msg_id exportsim-Tcl-000 INFO "No objects found specified with the -of_objects switch.\n"
    return
  }

  # check ip user files dir
  if { $a_sim_vars(b_ip_user_files_dir_specified) } {
    set a_sim_vars(s_ip_user_files_dir) [file normalize $a_sim_vars(s_ip_user_files_dir)]
    if { ![file exists $a_sim_vars(s_ip_user_files_dir)] } {
      send_msg_id exportsim-Tcl-000 ERROR "Directory path specified with the '-ip_user_files_dir' does not exist:'$a_sim_vars(s_ip_user_files_dir)'\n"
      return
    }
  }

  # set ipstatic dir
  if { $a_sim_vars(b_ipstatic_source_dir_specified) } {
    set a_sim_vars(s_ipstatic_source_dir) [file normalize $a_sim_vars(s_ipstatic_source_dir)]
  }

  xps_set_webtalk_data

  variable a_sim_cache_all_design_files_obj 
  # cache all design files
  foreach file_obj [get_files -quiet -all] {
    set name [get_property -quiet name $file_obj]
    set a_sim_cache_all_design_files_obj($name) $file_obj
  }

  # initialize XPM libraries (if any)
  xcs_get_xpm_libraries

  # cache all system verilog package libraries
  xcs_find_sv_pkg_libs "[pwd]"

  # no -of_objects specified
  if { ({} == $objs) || ([llength $objs] == 1) } {
    if { [xps_xport_simulation $objs] } {
      return
    }
  } else {
    foreach obj $objs {
      if { [xps_xport_simulation $obj] } {
        continue
      }
    }
  }

  # clear cache
  array unset a_sim_cache_result
  array unset a_sim_cache_extract_source_from_repo
  array unset a_sim_cache_gen_mem_files
  array unset a_sim_cache_all_design_files_obj
  array unset a_sim_cache_all_bd_files
  array unset a_sim_cache_parent_comp_files
  array unset a_sim_cache_ip_repo_header_files

  return
}
}

namespace eval ::tclapp::xilinx::projutils {
proc xps_init_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set a_sim_vars(curr_time)           [clock format [clock seconds]]
  set a_sim_vars(s_simulator)         "all"
  set a_sim_vars(s_xport_dir)         "export_sim"
  set a_sim_vars(s_simulator_name)    ""
  set a_sim_vars(b_xsim_specified)    0
  set a_sim_vars(b_lib_map_path_specified) 0
  set a_sim_vars(b_script_specified)  0
  set a_sim_vars(s_script_filename)   ""
  set a_sim_vars(s_runtime)           ""
  set a_sim_vars(b_runtime_specified) 0
  set a_sim_vars(b_define_specified) 0
  set a_sim_vars(b_generic_specified) 0
  set a_sim_vars(b_include_specified) 0
  set a_sim_vars(ip_filename)         ""
  set a_sim_vars(s_ip_file_extn)      ".xci"
  set a_sim_vars(b_extract_ip_sim_files) 0
  set a_sim_vars(b_32bit)             0
  set a_sim_vars(sp_of_objects)       {}
  set a_sim_vars(b_is_ip_object_specified)      0
  set a_sim_vars(b_is_fs_object_specified)      0
  set a_sim_vars(b_absolute_path)     0             
  set a_sim_vars(b_single_step)       0             
  set a_sim_vars(b_xport_src_files)   0             
  set a_sim_vars(b_overwrite)         0
  set a_sim_vars(b_of_objects_specified)        0
  set a_sim_vars(s_ip_user_files_dir) ""
  set a_sim_vars(s_ipstatic_source_dir) ""
  set a_sim_vars(b_contain_systemc_sources) 0

  # initialize ip repository dir
  set data_dir [rdi::get_data_dir -quiet -datafile "ip/xilinx"]
  set a_sim_vars(s_ip_repo_dir) [file normalize [file join $data_dir "ip/xilinx"]]

  set a_sim_vars(b_ip_user_files_dir_specified)        0
  set a_sim_vars(b_ipstatic_source_dir_specified)        0
  set a_sim_vars(b_directory_specified)         0
  set a_sim_vars(src_mgmt_mode)       "All"
  set a_sim_vars(s_simulation_flow)   "behav_sim"
  set a_sim_vars(fs_obj)              [current_fileset -simset]
  set a_sim_vars(sp_tcl_obj)          ""
  set a_sim_vars(s_top)               ""
  set a_sim_vars(s_install_path)      {}
  set a_sim_vars(b_scripts_only)      0
  set a_sim_vars(global_files_str)    {}
  set a_sim_vars(default_lib)         "xil_defaultlib"
  set a_sim_vars(do_filename)         "simulate.do"
  set a_sim_vars(b_use_static_lib)    0

  # wrapper file for executing user tcl (not supported currently in export_sim)
  set a_sim_vars(s_compile_pre_tcl_wrapper)  "vivado_wc_pre"

  # list of xpm libraries
  variable l_xpm_libraries [list]

  variable l_lib_map_path             [list]
  variable l_compile_order_files      [list]
  variable l_compile_order_files_uniq [list]
  variable l_design_files             [list]
  variable l_compiled_libraries       [list]
  variable l_local_design_libraries   [list]

  variable l_simulators               [list xsim modelsim questa ies vcs riviera activehdl]
  variable l_target_simulator         [list]

  variable l_valid_simulator_types    [list]
  set l_valid_simulator_types         [list all xsim modelsim questa ies vcs vcs_mx ncsim riviera activehdl]

  set b_enable_xclm_sim false
  [catch {set b_enable_xclm_sim [get_param project.enableXceliumSimulation]} err]
  if { $b_enable_xclm_sim } {
    lappend l_simulators "xcelium"
    lappend l_valid_simulator_types "xcelium"
  }

  variable l_valid_ip_extns           [list]
  set l_valid_ip_extns                [list ".xci" ".bd" ".slx"]

  variable s_data_files_filter
  set s_data_files_filter             "FILE_TYPE == \"Data Files\" || FILE_TYPE == \"Memory File\" || FILE_TYPE == \"Memory Initialization Files\" || FILE_TYPE == \"Coefficient Files\""

  variable s_embedded_files_filter
  set s_embedded_files_filter         "FILE_TYPE == \"BMM\" || FILE_TYPE == \"ELF\""

  variable s_non_hdl_data_files_filter
  set s_non_hdl_data_files_filter \
               "FILE_TYPE != \"Verilog\"                      && \
                FILE_TYPE != \"SystemVerilog\"                && \
                FILE_TYPE != \"Verilog Header\"               && \
                FILE_TYPE != \"Verilog/SystemVerilog Header\" && \
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
                FILE_TYPE != \"ELF\"                          && \
                FILE_TYPE != \"Design Checkpoint\""

  variable l_include_dirs  [list]
  variable l_defines       [list]
  variable l_generics      [list]

  variable a_sim_sv_pkg_libs [list]
  
  # common - imported to <ns>::xcs_* - home is defined in <app>.tcl
  if { ! [info exists ::tclapp::xilinx::projutils::_xcs_defined] } {
    variable home
    source -notrace "$home/common/utils.tcl"
  }
  
  # setup cache
  variable a_sim_cache_result
  variable a_sim_cache_extract_source_from_repo
  variable a_sim_cache_gen_mem_files
  variable a_sim_cache_all_bd_files
  variable a_sim_cache_parent_comp_files
  variable a_sim_cache_ip_repo_header_files

  array unset a_sim_cache_result
  array unset a_sim_cache_extract_source_from_repo
  array unset a_sim_cache_gen_mem_files
  array unset a_sim_cache_all_bd_files
  array unset a_sim_cache_parent_comp_files
  array unset a_sim_cache_ip_repo_header_files
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
      lappend l_target_simulator $simulator
    }
  } else {
    if { {vcs_mx} == $a_sim_vars(s_simulator) } {
      set a_sim_vars(s_simulator) "vcs"
    }
    if { {ncsim} == $a_sim_vars(s_simulator) } {
      set a_sim_vars(s_simulator) "ies"
    }
    lappend l_target_simulator $a_sim_vars(s_simulator)
  }

  if { ([llength $l_target_simulator] == 1) && ({xsim} == [lindex $l_target_simulator 0]) } {
    set a_sim_vars(b_xsim_specified) 1
  }
}

proc xps_set_webtalk_data {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_target_simulator
  set proj_obj [current_project]
  foreach simulator $l_target_simulator {
    set prop "webtalk.${simulator}_export_sim" 
    set curr_val [get_property -quiet $prop $proj_obj]
    if { [string is integer $curr_val] } {
      incr curr_val
      [catch {set_property $prop $curr_val $proj_obj} err]
    }
  }
}

proc xps_xport_simulation { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  if { [xps_set_target_obj $obj] } {
    return 1
  }

  set xport_dir [file normalize [string map {\\ /} $a_sim_vars(s_xport_dir)]]
  set run_dir {}
  if { [xps_create_rundir $xport_dir run_dir] } {
    return 1
  }

  # main readme
  xps_readme $run_dir
  xps_xtract_ips
  if { ([lsearch $a_sim_vars(options) {-of_objects}] != -1) && ([llength $a_sim_vars(sp_tcl_obj)] == 0) } {
    send_msg_id exportsim-Tcl-006 ERROR "Invalid object specified. The object does not exist.\n"
    return 1
  }


  set data_files [list]
  xps_xport_data_files data_files
  xps_set_script_filename

  set filename ${a_sim_vars(s_script_filename)}.sh

  if { [xps_write_sim_script $run_dir $data_files $filename] } { return }

  set readme_file "$run_dir/README.txt"
  #send_msg_id exportsim-Tcl-030 INFO \
  #  "Please see readme file for instructions on how to use the generated script: '$readme_file'\n"

  return 0
}

proc xps_invalid_options {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_valid_simulator_types
  if { {} != $a_sim_vars(s_script_filename) } {
    set extn [string tolower [file extension $a_sim_vars(s_script_filename)]]
    if { ({.sh} != $extn) } {
      [catch {send_msg_id exportsim-Tcl-004 ERROR "Invalid script file extension '$extn' specified. Please provide script filename with the '.sh' extension.\n"} err]
      return 1
    }
  }

  if { [lsearch -exact $l_valid_simulator_types $a_sim_vars(s_simulator)] == -1 } {
    [catch {send_msg_id exportsim-Tcl-004 ERROR "Invalid simulator type specified. Please type 'export_simulation -help' for usage info.\n"} err]
    return 1
  }

  set b_enable_xclm_sim false
  [catch {set b_enable_xclm_sim [get_param project.enableXceliumSimulation]} err]
  if { ({xcelium} == $a_sim_vars(s_simulator)) && (!$b_enable_xclm_sim) } {
    [catch {send_msg_id exportsim-Tcl-004 ERROR "Invalid simulator type specified. Please type 'export_simulation -help' for usage info.\n"} err]
    return 1
  }
  
  return 0
}

proc xps_xtract_ips {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { $a_sim_vars(b_xport_src_files) } {
    foreach ip [get_ips -all -quiet] {
      set xci_ip_name "${ip}.xci"
      set xcix_ip_name "${ip}.xcix"
      set xcix_file_path [get_property core_container [get_files -quiet -all ${xci_ip_name}]] 
      if { {} != $xcix_file_path } {
        [catch {rdi::extract_ip_sim_files -quiet -of_objects [get_files -quiet -all ${xcix_ip_name}]} err]
      }
    }
  }
}

proc xps_create_rundir { dir run_dir_arg } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:
 
  variable a_sim_vars
  variable l_target_simulator
  variable l_valid_ip_extns
  upvar $run_dir_arg run_dir

  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xcs_is_ip $tcl_obj $l_valid_ip_extns] } {
    if { $a_sim_vars(b_directory_specified) } {
      set ip_dir [file tail [file dirname $tcl_obj]]
      #append ip_dir "_sim"
      set dir [file normalize "$dir/$ip_dir"]
    } else {
      set ip_dir [file dirname $tcl_obj]
      set ip_filename [file tail $tcl_obj]
      set dir [file normalize [string map {\\ /} $ip_dir]]
      append dir "_sim"
    }
  }
  if { ! [file exists $dir] } {
    if {[catch {file mkdir $dir} error_msg] } {
      send_msg_id exportsim-Tcl-009 ERROR "failed to create the directory ($dir): $error_msg\n"
      return 1
    }
  }
  if { {all} == $a_sim_vars(s_simulator) } {
    foreach simulator $l_target_simulator {
      set sim_dir "$dir/$simulator"
      if { [xps_create_dir $sim_dir] } {
        return 1
      }
    }
  } else {
    set sim_dir "$dir/$a_sim_vars(s_simulator)"
    if { [xps_create_dir $sim_dir] } {
      return 1
    }
  }
  set run_dir $dir
  return 0
}

proc xps_readme { dir } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:

  variable a_sim_vars
  set fh 0
  set filename "README.txt"
  set file "$dir/$filename"
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-030 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 3]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]

  puts $fh "################################################################################"
  puts $fh "# $product (TM) $version_id\n#"
  puts $fh "# $filename: Please read the sections below to understand the steps required"
  puts $fh "#             to simulate the design for a simulator, the directory structure"
  puts $fh "#             and the generated exported files.\n#"
  puts $fh "################################################################################\n"
  puts $fh "1. Simulate Design\n"
  puts $fh "To simulate design, cd to the simulator directory and execute the script.\n"
  puts $fh "For example:-\n"
  puts $fh "% cd questa"
  set lib_path "c:\\design\\questa\\clibs"
  set sep "\\"
  set drive {c:}
  set extn ".sh"
  set lib_path "/design/questa/clibs"
  set sep "/"
  set drive {}
  puts $fh "% ./top$extn\n"
  puts $fh "The export simulation flow requires the Xilinx pre-compiled simulation library"
  puts $fh "components for the target simulator. These components are referred using the"
  puts $fh "'-lib_map_path' switch. If this switch is specified, then the export simulation"
  puts $fh "will automatically set this library path in the generated script and update,"
  puts $fh "copy the simulator setup file(s) in the exported directory.\n"
  puts $fh "If '-lib_map_path' is not specified, then the pre-compiled simulation library"
  puts $fh "information will not be included in the exported scripts and that may cause"
  puts $fh "simulation errors when running this script. Alternatively, you can provide the"
  puts $fh "library information using this switch while executing the generated script.\n"
  puts $fh "For example:-\n"
  puts $fh "% ./top$extn -lib_map_path $lib_path\n"
  puts $fh "Please refer to the generated script header 'Prerequisite' section for more details.\n"
  puts $fh "2. Directory Structure\n"
  puts $fh "By default, if the -directory switch is not specified, export_simulation will"
  puts $fh "create the following directory structure:-\n"
  puts $fh "<current_working_directory>${sep}export_sim${sep}<simulator>\n"
  puts $fh "For example, if the current working directory is $drive${sep}tmp${sep}test, export_simulation"
  puts $fh "will create the following directory path:-\n"
  puts $fh "$drive${sep}tmp${sep}test${sep}export_sim${sep}questa\n"
  puts $fh "If -directory switch is specified, export_simulation will create a simulator"
  puts $fh "sub-directory under the specified directory path.\n"
  puts $fh "For example, 'export_simulation -directory $drive${sep}tmp${sep}test${sep}my_test_area${sep}func_sim'"
  puts $fh "command will create the following directory:-\n"
  puts $fh "$drive${sep}tmp${sep}test${sep}my_test_area${sep}func_sim${sep}questa\n"
  puts $fh "By default, if -simulator is not specified, export_simulation will create a"
  puts $fh "simulator sub-directory for each simulator and export the files for each simulator"
  puts $fh "in this sub-directory respectively.\n"
  puts $fh "IMPORTANT: Please note that the simulation library path must be specified manually"
  puts $fh "in the generated script for the respective simulator. Please refer to the generated"
  puts $fh "script header 'Prerequisite' section for more details.\n"
  puts $fh "3. Exported script and files\n"
  puts $fh "Export simulation will create the driver shell script, setup files and copy the"
  puts $fh "design sources in the output directory path.\n"
  puts $fh "By default, when the -script_name switch is not specified, export_simulation will"
  puts $fh "create the following script name:-\n"
  puts $fh "<simulation_top>.sh  (Unix)"
  puts $fh "When exporting the files for an IP using the -of_objects switch, export_simulation"
  puts $fh "will create the following script name:-\n"
  puts $fh "<ip-name>.sh  (Unix)"
  puts $fh "Export simulation will create the setup files for the target simulator specified"
  puts $fh "with the -simulator switch.\n"
  puts $fh "For example, if the target simulator is \"ies\", export_simulation will create the"
  puts $fh "'cds.lib', 'hdl.var' and design library diectories and mappings in the 'cds.lib'"
  puts $fh "file.\n"

  close $fh
}

proc xps_write_simulator_readme { simulator dir } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:

  variable a_sim_vars
  set fh 0
  set filename "README.txt"
  set file "$dir/$filename"
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-030 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 3]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  set extn ".sh"
  set scr_name $a_sim_vars(s_script_filename)$extn
  puts $fh "################################################################################"
  puts $fh "# $product (TM) $version_id\n#"
  puts $fh "# $filename: Please read the sections below to understand the steps required to"
  puts $fh "#             run the exported script and information about the source files.\n#"
  puts $fh "# Generated by export_simulation on $a_sim_vars(curr_time)\n#"
  puts $fh "################################################################################\n"
  puts $fh "1. How to run the generated simulation script:-\n"
  puts $fh "From the shell prompt in the current directory, issue the following command:-\n"
  puts $fh "./${scr_name}\n"
  if { ({ies} == $simulator) || ({xcelium} == $simulator) } {
    puts $fh "This command will launch the 'execute' function for the single-step flow. This"
    puts $fh "function is called from the main 'run' function in the script file."
  } else {
    puts $fh "This command will launch the 'compile', 'elaborate' and 'simulate' functions"
    puts $fh "implemented in the script file for the 3-step flow. These functions are called"
    puts $fh "from the main 'run' function in the script file."
  }
  puts $fh "\nThe 'run' function first executes the 'setup' function, the purpose of which is to"
  puts $fh "create simulator specific setup files, create design library mappings and library"
  puts $fh "directories and copy 'glbl.v' from the Vivado software install location into the"
  puts $fh "current directory.\n"
  puts $fh "The 'setup' function is also used for removing the simulator generated data in"
  puts $fh "order to reset the current directory to the original state when export_simulation"
  puts $fh "was launched from Vivado. This generated data can be removed by specifying the"
  puts $fh "'-reset_run' switch to the './${scr_name}' script.\n"
  puts $fh "./${scr_name} -reset_run\n"
  puts $fh "To keep the generated data from the previous run but regenerate the setup files and"
  puts $fh "library directories, use the '-noclean_files' switch.\n"
  puts $fh "./${scr_name} -noclean_files\n"
  puts $fh "For more information on the script, please type './${scr_name} -help'.\n"
  puts $fh "2. Additional design information files:-\n"
  puts $fh "export_simulation generates following additional file that can be used for fetching"
  puts $fh "the design files information or for integrating with external custom scripts.\n"
  puts $fh "Name   : file_info.txt"
  puts $fh "Purpose: This file contains detail design file information based on the compile order"
  puts $fh "         when export_simulation was executed from Vivado. The file contains information"
  puts $fh "         about the file type, name, whether it is part of the IP, associated library"
  puts $fh "         and the file path information."
  close $fh
  return 0
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
    set srcs_dir [file normalize "$dir/srcs"]
    if {[catch {file mkdir $srcs_dir} error_msg] } {
      send_msg_id exportsim-Tcl-012 ERROR "failed to create the directory ($srcs_dir): $error_msg\n"
      return 1
    }
    set incl_dir [file normalize "$srcs_dir/incl"]
    if {[catch {file mkdir $incl_dir} error_msg] } {
      send_msg_id exportsim-Tcl-013 ERROR "failed to create the directory ($incl_dir): $error_msg\n"
      return 1
    }
  }
  return $srcs_dir
}

proc xps_set_target_obj { obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_valid_ip_extns

  set a_sim_vars(b_is_ip_object_specified) 0
  set a_sim_vars(b_is_fs_object_specified) 0
  if { {} != $obj } {
    set a_sim_vars(b_is_ip_object_specified) [xcs_is_ip $obj $l_valid_ip_extns]
    set a_sim_vars(b_is_fs_object_specified) [xcs_is_fileset $obj]
  }
  if { {1} == $a_sim_vars(b_is_ip_object_specified) } {
    set comp_file $obj
    set file_extn [file extension $comp_file]
    if { [lsearch -exact $l_valid_ip_extns ${file_extn}] == -1 } {
      # valid extention not found, set default (.xci)
      set comp_file ${comp_file}$a_sim_vars(s_ip_file_extn)
    } else {
      set a_sim_vars(s_ip_file_extn) $file_extn
    }
    set a_sim_vars(sp_tcl_obj) [get_files -all -quiet [list "$comp_file"]]
    set a_sim_vars(s_top) [file root [file tail $a_sim_vars(sp_tcl_obj)]]
    rdi::verify_ip_sim_status -all $a_sim_vars(sp_tcl_obj)
  } else {
    if { $a_sim_vars(b_is_fs_object_specified) } {
      set fs_type [get_property fileset_type [get_filesets $obj]]
      set fs_of_obj [get_property name [get_filesets $obj]]
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
        rdi::verify_ip_sim_status -all
        #update_compile_order -quiet -fileset $a_sim_vars(sp_tcl_obj)
        set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
      } elseif { $fs_type == "SimulationSrcs" } {
        set a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj)
        rdi::verify_ip_sim_status -all
        #update_compile_order -quiet -fileset $a_sim_vars(sp_tcl_obj)
        set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
      }
    } else {
      # no -of_objects specifed, set default active simset
      set a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj)
      rdi::verify_ip_sim_status -all
      #update_compile_order -quiet -fileset $a_sim_vars(sp_tcl_obj)
      set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
    }
  }
  return 0
}

proc xps_gen_mem_files { run_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_cache_gen_mem_files
  variable a_sim_vars
  variable l_target_simulator

  set s_ip_dir [file tail [file dirname $run_dir]]
  set s_hash "_${s_ip_dir}"; # cache hash, _ prepend supports empty args

  # if mem files cache setup, copy mem files from this cache run dir to other simulator dir
  if { [info exists a_sim_cache_gen_mem_files($s_hash)] } { 
    if { ! [file isdirectory $run_dir] } {
      if { [catch {file mkdir $run_dir} error] } {
        send_msg_id exportsim-Tcl-068 ERROR "failed to create directory: $run_dir\n$error"
      }
    }

    foreach file [glob -nocomplain -directory $a_sim_cache_gen_mem_files($s_hash) *.mem] {
      if { [catch {file copy -force $file $run_dir} error] } {
        send_msg_id exportsim-Tcl-069 ERROR "failed to copy '${file}' to '${run_dir}': $error"
      }
    }
    return
  }

  if { [xcs_is_embedded_flow] } {
    #send_msg_id exportsim-Tcl-016 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
    generate_mem_files $run_dir
    set a_sim_cache_gen_mem_files($s_hash) $run_dir
  }
}

# TODO: The xcs_copy_glbl_file should be a drop-in replacement, but this algorithm
#       checks that the l_design_files contains_verilog, which is different so leaving for now.
proc xps_copy_glbl { run_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
    set glbl_file [file normalize "$data_dir/verilog/src/glbl.v"]
    if { [file exists $glbl_file] } {
      set target_file [file normalize "$run_dir/glbl.v"]
      if { ![file exists $target_file] } {
        if {[catch {file copy -force $glbl_file $run_dir} error_msg] } {
          send_msg_id exportsim-Tcl-041 WARNING "failed to copy file '$glbl_file' to '$run_dir' : $error_msg\n"
        }
      }
    }
  }
}

proc xps_xport_data_files { data_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable s_data_files_filter
  variable s_non_hdl_data_files_filter
  variable l_valid_ip_extns
  upvar $data_files_arg data_files

  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xcs_is_ip $tcl_obj $l_valid_ip_extns] } {
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
  } elseif { [xcs_is_fileset $tcl_obj] } {
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

proc xps_get_files { simulator launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compile_order_files
  variable l_valid_ip_extns
  variable l_compiled_libraries
  set files          [list]
  set l_compile_order_files [list]
  set target_obj            $a_sim_vars(sp_tcl_obj)
  set linked_src_set        {}
  if { ([xcs_is_fileset $a_sim_vars(sp_tcl_obj)]) && ({SimulationSrcs} == [get_property fileset_type $a_sim_vars(fs_obj)]) } {
    set linked_src_set [get_property "SOURCE_SET" $a_sim_vars(fs_obj)]
  }
  set incl_file_paths [list]
  set incl_files      [list]

  #send_msg_id exportsim-Tcl-018 INFO "Finding global include files..."
  set prefix_ref_dir "false"
  switch $simulator {
    "ies" -
    "xcelium" -
    "vcs" {
      set prefix_ref_dir "true"
    }
  }
  xps_get_global_include_files $launch_dir incl_file_paths incl_files $prefix_ref_dir

  set global_incl_files $incl_files
  set a_sim_vars(global_files_str) [xps_get_global_include_file_cmdstr $simulator $launch_dir incl_files]

  #send_msg_id exportsim-Tcl-019 INFO "Finding include directories and verilog header directory paths..."
  set l_incl_dirs_opts [list]
  set l_verilog_incl_dirs [list]
  set uniq_dirs [list]
  foreach dir [concat [xps_get_verilog_incl_dirs $simulator $launch_dir $prefix_ref_dir] [xps_get_verilog_incl_file_dirs $simulator $launch_dir $prefix_ref_dir] [xcs_get_vip_include_dirs]] {
    lappend l_verilog_incl_dirs $dir
    if { {vcs} == $simulator } {
      set dir [string trim $dir "\""]
      regsub -all { } $dir {\\\\ } dir
    }
    if { [lsearch -exact $uniq_dirs $dir] == -1 } {
      lappend uniq_dirs $dir
      if { ({questa} == $simulator) || ({modelsim} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator) } {
        lappend l_incl_dirs_opts "\"+incdir+$dir\""
      } else {
        lappend l_incl_dirs_opts "+incdir+\"$dir\""
      }
    }
  }

  # if xilinx_vip not referenced, compile it locally
  if { ([lsearch -exact $l_compiled_libraries "xilinx_vip"] == -1) } {
    variable a_sim_sv_pkg_libs
    if { [llength $a_sim_sv_pkg_libs] > 0 } {
      set incl_dir_opts {}
      if { ({questa} == $simulator) || ({modelsim} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator) } {
        set incl_dir_opts "\\\"+incdir+[xcs_get_vip_include_dirs]\\\""
      } elseif { ({ies} == $simulator) || ({xcelium} == $simulator) } {
        set incl_dir_opts "+incdir+\"[xcs_get_vip_include_dirs]\""
      } elseif { {vcs} == $simulator } {
        set incl_dir_opts "+incdir+[xcs_get_vip_include_dirs]"
      }

      foreach file [xcs_get_xilinx_vip_files] {
        set file_type "SystemVerilog"
        set compiler [xcs_get_compiler_name $simulator $file_type]
        set l_other_compiler_opts [list]
        xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
        set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type true $compiler l_other_compiler_opts incl_dir_opts 1 "" "xilinx_vip"]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }
  }

  set b_compile_xpm_library 1
  # reference XPM modules from precompiled libs if param is set
  set b_reference_xpm_library 0
  [catch {set b_reference_xpm_library [get_param project.usePreCompiledXPMLibForSim]} err]

  # for precompile flow, if xpm library not found from precompiled libs, compile it locally
  # for non-precompile flow, compile xpm locally and do not reference precompiled xpm library
  if { $b_reference_xpm_library } {
    if { $a_sim_vars(b_use_static_lib) } {
      if { ([lsearch -exact $l_compiled_libraries "xpm"] == -1) } {
        set b_reference_xpm_library 0
      }
    } else {
      set b_reference_xpm_library 0
    }
  }

  if { $b_reference_xpm_library } {
    set b_compile_xpm_library 0
  }

  if { $b_compile_xpm_library } {
    variable l_xpm_libraries
    set b_using_xpm_libraries false
    foreach library $l_xpm_libraries {
      foreach file [rdi::get_xpm_files -library_name $library] {
        set file_type "SystemVerilog"
        set compiler [xcs_get_compiler_name $simulator $file_type]
        set l_other_compiler_opts [list]
        xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
        set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type true $compiler l_other_compiler_opts l_incl_dirs_opts 1]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
          set b_using_xpm_libraries true
        }
      }
    }
    if { $b_using_xpm_libraries } {
      set xpm_library [xcs_get_common_xpm_library]
      set common_xpm_vhdl_files [xcs_get_common_xpm_vhdl_files]
      foreach file $common_xpm_vhdl_files {
        set file_type "VHDL"
        set compiler [xcs_get_compiler_name $simulator $file_type]
        set l_other_compiler_opts [list]
        set b_is_xpm true
        xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
        set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type $b_is_xpm $compiler l_other_compiler_opts l_incl_dirs_opts 1 $xpm_library]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }
  }

  if { [xcs_is_fileset $target_obj] } {
    set used_in_val "simulation"
    switch [get_property "FILESET_TYPE" [get_filesets $target_obj]] {
      "DesignSrcs"     { set used_in_val "synthesis" }
      "SimulationSrcs" { set used_in_val "simulation"}
      "BlockSrcs"      { set used_in_val "synthesis" }
    }

    set b_add_sim_files 1
    if { {} != $linked_src_set } {
      if { [get_param project.addBlockFilesetFilesForUnifiedSim] } {
        xps_add_block_fs_files $simulator $launch_dir l_incl_dirs_opts l_verilog_incl_dirs files l_compile_order_files
      }
    }

    if { {All} == $a_sim_vars(src_mgmt_mode) } {
      #send_msg_id exportsim-Tcl-020 INFO "Fetching design files from '$target_obj'..."
      foreach fs_file_obj [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $target_obj]] {
        if { [xcs_is_global_include_file $fs_file_obj $a_sim_vars(global_files_str)] } { continue }
        set file_type [get_property "FILE_TYPE" $fs_file_obj]
        set compiler [xcs_get_compiler_name $simulator $file_type]
        set l_other_compiler_opts [list]
        xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
        set cmd_str [xps_get_cmdstr $simulator $launch_dir $fs_file_obj $file_type false $compiler l_other_compiler_opts l_incl_dirs_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $fs_file_obj
        }
      }
      set b_add_sim_files 0
    } else {
      if { {} != $linked_src_set } {
        set srcset_obj [get_filesets $linked_src_set]
        if { {} != $srcset_obj } {
          set used_in_val "simulation"
          #send_msg_id exportsim-Tcl-021 INFO "Fetching design files from '$srcset_obj'...(this may take a while)..."
          foreach fs_file_obj [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $srcset_obj]] {
            set file_type [get_property "FILE_TYPE" $fs_file_obj]
            set compiler [xcs_get_compiler_name $simulator $file_type]
            set l_other_compiler_opts [list]
            xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
            if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
            set cmd_str [xps_get_cmdstr $simulator $launch_dir $fs_file_obj $file_type false $compiler l_other_compiler_opts l_incl_dirs_opts]
            if { {} != $cmd_str } {
              lappend files $cmd_str
              lappend l_compile_order_files $fs_file_obj
            }
          }
        }
      }
    }

    if { $b_add_sim_files } {
      #send_msg_id exportsim-Tcl-022 INFO "Fetching design files from '$a_sim_vars(fs_obj)'..."
      foreach fs_file_obj [get_files -quiet -all -of_objects $a_sim_vars(fs_obj)] {
        set file_type [get_property "FILE_TYPE" $fs_file_obj]
        set compiler [xcs_get_compiler_name $simulator $file_type]
        set l_other_compiler_opts [list]
        xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
        if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
        if { [get_property "IS_AUTO_DISABLED" $fs_file_obj]} { continue }
        set cmd_str [xps_get_cmdstr $simulator $launch_dir $fs_file_obj $file_type false $compiler l_other_compiler_opts l_incl_dirs_opts]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $fs_file_obj
        }
      }
    }
  } elseif { [xcs_is_ip $target_obj $l_valid_ip_extns] } {
    #send_msg_id exportsim-Tcl-023 INFO "Fetching design files from IP '$target_obj'..."
    set ip_filename [file tail $target_obj]
    foreach ip_file_obj [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet $ip_filename]] {
      set file_type [get_property "FILE_TYPE" $ip_file_obj]
      set compiler [xcs_get_compiler_name $simulator $file_type]
      set l_other_compiler_opts [list]
      xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
      if { ({Verilog} != $file_type) && ({SystemVerilog} != $file_type) && ({VHDL} != $file_type) && ({VHDL 2008} != $file_type) } { continue }
      set cmd_str [xps_get_cmdstr $simulator $launch_dir $ip_file_obj $file_type false $compiler l_other_compiler_opts l_incl_dirs_opts]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $ip_file_obj
      }
    }
  }

  if { [get_param "project.enableSystemCSupport"] } {

    # design contain systemc/cpp sources? 
    set sc_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC\")"
    set cpp_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"CPP\")"
    set c_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C\")"

    # fetch systemc files
    set sc_files [xcs_get_sc_files $sc_filter]
    if { [llength $sc_files] > 0 } {
      send_msg_id exportsim-Tcl-024 INFO "Finding SystemC sources..."
      # fetch systemc include files (.h)
      set l_incl_dir [list]
      foreach dir [xcs_get_c_incl_dirs $simulator $launch_dir $sc_filter $a_sim_vars(s_ip_user_files_dir) $a_sim_vars(b_xport_src_files) $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
        lappend l_incl_dir "-I \"$dir\""
      }

      # dependency on cpp source headers
      # fetch cpp include files (.h)
      foreach dir [xcs_get_c_incl_dirs $simulator $launch_dir $cpp_filter $a_sim_vars(s_ip_user_files_dir) $a_sim_vars(b_xport_src_files) $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
        lappend l_incl_dir "-I \"$dir\""
      }

      # get the xtlm include dir from compiled library
      set dir "[xps_get_lib_map_path $simulator]/xtlm/include"

      # get relative file path for the compiled library
      set relative_dir "[xcs_get_relative_file_path $dir $launch_dir]"
      lappend l_incl_dir "-I \"$relative_dir\""

      if { "vcs" == $simulator } {
        # get the systemc include dir from data
        set dir [xcs_get_systemc_include_dir]
        set relative_dir "[xcs_get_relative_file_path $dir $launch_dir]"
        lappend l_incl_dir "-I \"$relative_dir\""
      }
  
      foreach file $sc_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }

        if { ({.cpp} == $file_extn) || ({.cxx} == $file_extn) } {
          # set flag
          if { !$a_sim_vars(b_contain_systemc_sources) } {
            set a_sim_vars(b_contain_systemc_sources) true
          }
 
          # is dynamic? process
          set used_in_values [get_property "USED_IN" $file]
          if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
            set file_type "SystemC"
            set compiler [xcs_get_compiler_name $simulator $file_type]
  
            set l_other_opts [list]
            xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_incl_dir l_other_opts
            set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type false $compiler l_other_opts l_incl_dir]
            if { {} != $cmd_str } {
              lappend files $cmd_str
              lappend compile_order_files $file
            }
          }
        }
      }
    }

    # fetch cpp files
    set cpp_files [get_files -quiet -all -filter $cpp_filter]
    if { [llength $cpp_files] > 0 } {
      set g_files {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      # fetch systemc include files (.h)
      set l_incl_dir [list]
      foreach dir [xcs_get_c_incl_dirs $simulator $launch_dir $cpp_filter $a_sim_vars(s_ip_user_files_dir) $a_sim_vars(b_xport_src_files) $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
        lappend l_incl_dir "-I \"$dir\""
      }
      
      # get the xtlm include dir from compiled library
      set dir "[xps_get_lib_map_path $simulator]/xtlm/include"

      # get relative file path for the compiled library
      set relative_dir "[xcs_get_relative_file_path $dir $launch_dir]"
      lappend l_incl_dir "-I \"$relative_dir\""

      foreach file $cpp_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }
        if { {.cpp} == $file_extn } {
          # set flag
          if { !$a_sim_vars(b_contain_systemc_sources) } {
            set a_sim_vars(b_contain_systemc_sources) true
          }

          # is dynamic? process
          set used_in_values [get_property "USED_IN" $file]
          if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
            set file_type "CPP"
            set compiler [xcs_get_compiler_name $simulator $file_type]
  
            set l_other_opts [list]
            xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_incl_dir l_other_opts
            set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type false $compiler l_other_opts l_incl_dir]
            if { {} != $cmd_str } {
              lappend files $cmd_str
              lappend compile_order_files $file
            }
          }
        }
      }
    }

    # fetch c files
    set c_files [get_files -quiet -all -filter $c_filter]
    if { [llength $c_files] > 0 } {
      set g_files {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      # fetch systemc include files (.h)
      set l_incl_dir [list]
      foreach dir [xcs_get_c_incl_dirs $simulator $launch_dir $c_filter $a_sim_vars(s_ip_user_files_dir) $a_sim_vars(b_xport_src_files) $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
        lappend l_incl_dir "-I \"$dir\""
      }
      
      # get the xtlm include dir from compiled library
      set dir "[xps_get_lib_map_path $simulator]/xtlm/include"

      # get relative file path for the compiled library
      set relative_dir "[xcs_get_relative_file_path $dir $launch_dir]"
      lappend l_incl_dir "-I \"$relative_dir\""

      foreach file $c_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }
        if { {.c} == $file_extn } {
          # set flag
          if { !$a_sim_vars(b_contain_systemc_sources) } {
            set a_sim_vars(b_contain_systemc_sources) true
          }

          # is dynamic? process
          set used_in_values [get_property "USED_IN" $file]
          if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
            set file_type "C"
            set compiler [xcs_get_compiler_name $simulator $file_type]
  
            set l_other_opts [list]
            xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_incl_dir l_other_opts
            set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type false $compiler l_other_opts l_incl_dir]
            if { {} != $cmd_str } {
              lappend files $cmd_str
              lappend compile_order_files $file
            }
          }
        }
      }
    }
  }
  return $files
}

proc xps_get_ip_file_from_repo { ip_file src_file library launch_dir b_static_ip_file_arg  } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $b_static_ip_file_arg b_static_ip_file
  if { ![get_param project.enableCentralSimRepo] } { return $src_file }
  #if { $a_sim_vars(b_xport_src_files) }            { return $src_file }
  if { {} == $ip_file }                            { return $src_file }

  if { ({} != $a_sim_vars(s_ip_user_files_dir)) && ([file exist $a_sim_vars(s_ip_user_files_dir)]) } {
    set b_is_static 0
    set b_is_dynamic 0
    set b_add_ref 0
    set b_wrap_in_quotes 0
    set dst_cip_file [xps_extract_source_from_repo $ip_file $src_file b_is_static b_is_dynamic b_add_ref b_wrap_in_quotes]
    set src_file [xps_get_source_from_repo $src_file $dst_cip_file $b_add_ref $b_wrap_in_quotes $launch_dir]
    set b_static_ip_file $b_is_static
    if { (!$b_is_static) && (!$b_is_dynamic) } {
      #send_msg_id exportsim-Tcl-056 "CRITICAL WARNING" "IP file is neither static or dynamic:'$src_file'\n"
    }
    # phase-2
    if { $b_is_static } {
      set b_static_ip_file 1
    }
  } else {
    set b_add_ref 0
    if {[regexp -nocase {^\$ref_dir} $src_file]} {
      set b_add_ref 1
      set src_file [string range $src_file 9 end]
      set src_file "$src_file"
    }
    if { [file exist $src_file] } {
      if { $a_sim_vars(b_absolute_path) } {
        set src_file "[xcs_resolve_file_path $src_file $launch_dir]"
      } else {
        if { $b_add_ref } {
          set src_file "\$ref_dir/[xcs_get_relative_file_path $src_file $launch_dir]"
        } else {
          set src_file "[xcs_get_relative_file_path $src_file $launch_dir]"
        }
      }
    }
  }

  return $src_file
}

proc xps_extract_source_from_repo { ip_file orig_src_file b_is_static_arg b_is_dynamic_arg b_add_ref_arg b_wrap_in_quotes_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_cache_extract_source_from_repo
  variable a_sim_vars
  variable l_compiled_libraries
  variable l_local_design_libraries
  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_all_bd_files
  upvar $b_is_static_arg b_is_static
  upvar $b_is_dynamic_arg b_is_dynamic
  upvar $b_add_ref_arg b_add_ref
  upvar $b_wrap_in_quotes_arg b_wrap_in_quotes

  set s_hash "_${ip_file}-${orig_src_file}"; # cache hash, _ prepend supports empty args
  # IMPORTANT: when exporting for multiple simulators, the values of b_is_static for a given file
  #            could change based on compiled libraries data from lib_map_path, so don't use hash
  #            at this point for precompiled flow, just process all files.
  set b_use_hash 1
  if { $a_sim_vars(b_use_static_lib) } {
    set b_use_hash 0
  }
  if { $b_use_hash } {
    if { [info exists a_sim_cache_extract_source_from_repo($s_hash)] } { 
      if { [info exists a_sim_cache_extract_source_from_repo("${s_hash}-b_is_static")] } { 
        set b_is_static $a_sim_cache_extract_source_from_repo("${s_hash}-b_is_static") 
      }
      set b_is_dynamic $a_sim_cache_extract_source_from_repo("${s_hash}-b_is_dynamic") 
      set b_add_ref $a_sim_cache_extract_source_from_repo("${s_hash}-b_add_ref") 
      set b_wrap_in_quotes $a_sim_cache_extract_source_from_repo("${s_hash}-b_wrap_in_quotes") 
      return $a_sim_cache_extract_source_from_repo($s_hash) 
    }
  }

  #puts org_file=$orig_src_file
  set src_file $orig_src_file

  set b_wrap_in_quotes 0
  set a_sim_cache_extract_source_from_repo("${s_hash}-b_wrap_in_quotes") $b_wrap_in_quotes
  if { [regexp {\"} $src_file] } {
    set b_wrap_in_quotes 1
    set a_sim_cache_extract_source_from_repo("${s_hash}-b_wrap_in_quotes") $b_wrap_in_quotes
    regsub -all {\"} $src_file {} src_file
  }

  set b_add_ref 0 
  set a_sim_cache_extract_source_from_repo("${s_hash}-b_add_ref") $b_add_ref
  if {[regexp -nocase {^\$ref_dir} $src_file]} {
    set b_add_ref 1
    set a_sim_cache_extract_source_from_repo("${s_hash}-b_add_ref") $b_add_ref
    set src_file [string range $src_file 9 end]
    set src_file "$src_file"
  }
  #puts src_file=$src_file
  set filename [file tail $src_file]
  #puts ip_file=$ip_file
  set ip_name [file root [file tail $ip_file]] 

  set full_src_file_path [xcs_find_file_from_compile_order $ip_name $src_file]
  #puts ful_file=$full_src_file_path
  set full_src_file_obj {}
  if { [info exists a_sim_cache_all_design_files_obj($full_src_file_path)] } {
    set full_src_file_obj $a_sim_cache_all_design_files_obj($full_src_file_path)
  } else {
    set full_src_file_obj [lindex [get_files -quiet -all [list "$full_src_file_path"]] 0]
  }
  if { {} == $full_src_file_obj } {
    return $orig_src_file
  }
  #puts ip_name=$ip_name

  set dst_cip_file $full_src_file_path
  set used_in_values [get_property "USED_IN" $full_src_file_obj]
  set library [get_property "LIBRARY" $full_src_file_obj]
  set b_file_is_static 0
  # is dynamic?
  if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
    set file_extn [file extension $ip_file]
    set b_found_in_repo 0
    set repo_src_file {}
    if { [xcs_cache_result {xcs_is_core_container ${ip_name}${file_extn}}] } {
      set dst_cip_file [xcs_get_dynamic_sim_file_core_container $full_src_file_path $a_sim_vars(s_ip_user_files_dir) b_found_in_repo repo_src_file]
      if { !$b_found_in_repo } {
        send_msg_id exportsim-Tcl-024 ERROR "The expected IP dynamic file(s) does not exist from the path specified with -ip_user_files_dir switch. Please make sure that the files were exported to '$a_sim_vars(s_ip_user_files_dir)' directory or specify the directory where these exported files are present.\n"
      }
    } else {
      set dst_cip_file [xcs_get_dynamic_sim_file_core_classic $full_src_file_path $a_sim_vars(s_ip_user_files_dir) b_found_in_repo repo_src_file]
    }
  } else {
    set b_file_is_static 1
  }

  set b_is_dynamic 1
  set a_sim_cache_extract_source_from_repo("${s_hash}-b_is_dynamic") $b_is_dynamic
  set b_is_bd_ip 0
  if { [info exists a_sim_cache_all_bd_files($full_src_file_path)] } {
    set b_is_bd_ip 1
  } else {
    set b_is_bd_ip [xcs_is_bd_file $full_src_file_path]
    if { $b_is_bd_ip } {
      set a_sim_cache_all_bd_files($full_src_file_path) $b_is_bd_ip
    }
  }

  # is static ip file? set flag and return
  #puts ip_name=$ip_name
  set ip_static_file {}
  if { $b_file_is_static } {
    set ip_static_file $full_src_file_path
  }
  if { {} != $ip_static_file } {
    #puts ip_static_file=$ip_static_file
    set b_is_static 0
    set a_sim_cache_extract_source_from_repo("${s_hash}-b_is_static") $b_is_static
    set b_is_dynamic 0
    set a_sim_cache_extract_source_from_repo("${s_hash}-b_is_dynamic") $b_is_dynamic
    set dst_cip_file $ip_static_file 

    set b_process_file 1
    if { $a_sim_vars(b_use_static_lib) } {
      # use pre-compiled lib
      if { [lsearch -exact $l_compiled_libraries $library] != -1 } {
        set b_process_file 0
        set b_is_static 1
        set a_sim_cache_extract_source_from_repo("${s_hash}-b_is_static") $b_is_static
      } else {
        # add this library to have the new mapping
        if { [lsearch -exact $l_local_design_libraries $library] == -1 } {
          lappend l_local_design_libraries $library
        }
      }
    }

    if { $b_process_file } {
      if { $b_is_bd_ip } {
        set dst_cip_file [xcs_fetch_ipi_static_file $full_src_file_obj $ip_static_file $a_sim_vars(s_ipstatic_source_dir)] 
      } else {
        # get the parent composite file for this static file
        set parent_comp_file [get_property parent_composite_file -quiet $full_src_file_obj]

        # calculate destination path
        set dst_cip_file [xcs_find_ipstatic_file_path $full_src_file_obj $ip_static_file $parent_comp_file $a_sim_vars(s_ipstatic_source_dir)]

        # skip if file exists
        if { ({} == $dst_cip_file) || (![file exists $dst_cip_file]) } {
          # if parent composite file is empty, extract to default ipstatic dir (the extracted path is expected to be
          # correct in this case starting from the library name (e.g fifo_generator_v13_0_0/hdl/fifo_generator_v13_0_rfs.vhd))
          if { {} == $parent_comp_file } {
            set dst_cip_file [extract_files -no_ip_dir -quiet -files [list "$full_src_file_obj"] -base_dir $a_sim_vars(s_ipstatic_source_dir)]
            #puts extracted_file_no_pc=$dst_cip_file
          } else {
            # parent composite is not empty, so get the ip output dir of the parent composite and subtract it from source file
            set parent_ip_name [file root [file tail $parent_comp_file]]
            set ip_output_dir [get_property ip_output_dir [get_ips -all $parent_ip_name]]
            #puts src_ip_file=$ip_static_file
  
            # get the source ip file dir
            set src_ip_file_dir [file dirname $ip_static_file]
    
            # strip the ip_output_dir path from source ip file and prepend static dir
            set lib_dir [xcs_get_sub_file_path $src_ip_file_dir $ip_output_dir]
            set target_extract_dir [file normalize "$a_sim_vars(s_ipstatic_source_dir)/$lib_dir"]
            #puts target_extract_dir=$target_extract_dir
    
            set dst_cip_file [extract_files -no_path -quiet -files [list "$full_src_file_obj"] -base_dir $target_extract_dir]
            #puts extracted_file_with_pc=$dst_cip_file
          }
        }
      }
    }
  }
  return [set a_sim_cache_extract_source_from_repo($s_hash) $dst_cip_file]
}

proc xps_get_source_from_repo { orig_src_file dst_cip_file b_add_ref b_wrap_in_quotes launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { [file exist $dst_cip_file] } {
    if { $a_sim_vars(b_absolute_path) } {
      set dst_cip_file "[xcs_resolve_file_path $dst_cip_file $launch_dir]"
    } else {
      if { $b_add_ref } {
        set dst_cip_file "\$ref_dir/[xcs_get_relative_file_path $dst_cip_file $launch_dir]"
      } else {
        set dst_cip_file "[xcs_get_relative_file_path $dst_cip_file $launch_dir]"
      }
    }
    if { $b_wrap_in_quotes } {
      set dst_cip_file "\"$dst_cip_file\""
    }
    set orig_src_file $dst_cip_file
  }
  return $orig_src_file
}

proc xps_add_block_fs_files { simulator launch_dir l_incl_dirs_opts_arg l_verilog_incl_dirs_arg files_arg compile_order_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts
  upvar $l_verilog_incl_dirs_arg l_verilog_incl_dirs 
  upvar $files_arg files
  upvar $compile_order_files_arg compile_order_files

  #send_msg_id exportsim-Tcl-024 INFO "Finding block fileset files..."
  set vhdl_filter "FILE_TYPE == \"VHDL\" || FILE_TYPE == \"VHDL 2008\""
  foreach file [xcs_get_files_from_block_filesets $vhdl_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
    set compiler [xcs_get_compiler_name $simulator $file_type]
    set l_other_compiler_opts [list]
    xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
    set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type false $compiler {} l_other_compiler_opts l_incl_dirs_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend compile_order_files $file
    }
  }
  set verilog_filter "FILE_TYPE == \"Verilog\" || FILE_TYPE == \"SystemVerilog\""
  foreach file [xcs_get_files_from_block_filesets $verilog_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
    set compiler [xcs_get_compiler_name $simulator $file_type]
    set l_other_compiler_opts [list]
    xps_append_compiler_options $simulator $launch_dir $compiler $file_type l_verilog_incl_dirs l_other_compiler_opts
    set cmd_str [xps_get_cmdstr $simulator $launch_dir $file $file_type false $compiler l_other_compiler_opts l_incl_dirs_opts]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend compile_order_files $file
    }
  }
}

proc xps_get_cmdstr { simulator launch_dir file file_type b_xpm compiler l_other_compiler_opts_arg  l_incl_dirs_opts_arg {b_skip_file_obj_access 0} {xpm_library {}} {xv_lib {}}} {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  variable a_sim_cache_all_design_files_obj
  upvar $l_other_compiler_opts_arg l_other_compiler_opts
  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts
  set b_absolute_path $a_sim_vars(b_absolute_path)
  set cmd_str {}
  set associated_library $a_sim_vars(default_lib);
  set srcs_dir [file normalize "$launch_dir/srcs"]
  if { $b_skip_file_obj_access } {
    if { ($b_xpm) && ([string length $xpm_library] != 0)} {
      set associated_library $xpm_library
    }
  } else {
    set file_obj {}
    if { [info exists a_sim_cache_all_design_files_obj($file)] } {
      set file_obj $a_sim_cache_all_design_files_obj($file)
    } else {
      set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
    }
    if { {} != $file_obj } {
      if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
        set associated_library [get_property "LIBRARY" $file_obj]
      }
      if { ($a_sim_vars(b_extract_ip_sim_files) || $a_sim_vars(b_xport_src_files)) } {
        set xcix_ip_path [get_property core_container $file_obj]
        if { {} != $xcix_ip_path } {
          set ip_name [file root [file tail $xcix_ip_path]]
          set ip_ext_dir [get_property ip_extract_dir [get_ips -all -quiet $ip_name]]
          set ip_file "[xcs_get_relative_file_path $file $ip_ext_dir]"
          # remove leading "../"
          set ip_file [join [lrange [split $ip_file "/"] 1 end] "/"]
          set file "$ip_ext_dir/$ip_file"
        } else {
          # set file [extract_files -files [list "$file"] -base_dir $launch_dir/ip_files]
        }
      }
    }
  }
  
  if { {} != $xv_lib } {
    set associated_library $xv_lib
  }

  set src_file $file

  set ip_file {}
  set b_static_ip_file 0
  if { $b_skip_file_obj_access } {
    #
  } else {
    set ip_file [xcs_cache_result {xcs_get_top_ip_filename $src_file}]
    if { $a_sim_vars(b_xport_src_files) } {
      # no-op for default flow
      if { $a_sim_vars(b_use_static_lib) } {
        set file [xps_get_ip_file_from_repo $ip_file $src_file $associated_library $launch_dir b_static_ip_file]
      }
    } else {
      set file [xps_get_ip_file_from_repo $ip_file $src_file $associated_library $launch_dir b_static_ip_file]
    }
    #puts file=$file
  }

  set arg_list [list]
  if { [string length $compiler] > 0 } {
    lappend arg_list $compiler
    switch $simulator {
      "xsim" {}
      default {
        if { ({g++} == $compiler) || ({gcc} == $compiler) } {
          # no work library required
        } else {
          set arg_list [linsert $arg_list end "-work"]
        }
      }
    }

    if { ({g++} == $compiler) || ({gcc} == $compiler) } {
      set arg_list [linsert $arg_list end "-c"]
    } else {
      set arg_list [linsert $arg_list end "$associated_library"]
    }

    if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) } {
      # do not add global files for 2008
    } else {
      if { {} != $a_sim_vars(global_files_str) } {
        set arg_list [linsert $arg_list end [xps_resolve_global_file_paths $simulator $launch_dir]]
      }
    }
  }

  set arg_list [concat $arg_list $l_other_compiler_opts]
  if { {vlog} == $compiler } {
    set arg_list [concat $arg_list $l_incl_dirs_opts]
  } elseif { {sccom} == $compiler } {
    set arg_list [concat $arg_list $l_incl_dirs_opts]
  } elseif { {g++} == $compiler } {
    set arg_list [concat $arg_list $l_incl_dirs_opts]
  } elseif { {gcc} == $compiler } {
    set arg_list [concat $arg_list $l_incl_dirs_opts]
  }
  set file_str [join $arg_list " "]
  set type [xcs_get_file_type_category $file_type]


  set cmd_str "$type|$file_type|$associated_library|$src_file|$file_str|$ip_file|\"$file\"|$b_static_ip_file|$b_xpm"
  return $cmd_str
}

proc xps_resolve_global_file_paths { simulator launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set file_paths [string trim $a_sim_vars(global_files_str)]
  if { {} == $file_paths } { return $file_paths }

  set resolved_file_paths [list]
  foreach g_file [split $file_paths {|}] {
    set file [string trim $g_file {\"}]
    set src_file [file tail $file]
    if { $a_sim_vars(b_absolute_path) } {
      switch -regexp -- $simulator {
        "ies" -
        "xcelium" -
        "vcs" {
          if { $a_sim_vars(b_xport_src_files) } {
            set file "\$ref_dir/incl/$src_file"
          } else {
            set file [file normalize $file]
          }
        }
        default {
          if { $a_sim_vars(b_xport_src_files) } {
            set file "$launch_dir/srcs/incl/$src_file"
          } else {
            set file "[xcs_resolve_file_path $file $launch_dir]"
          }
        }
      }
    } else {
      switch -regexp -- $simulator {
        "ies" -
        "xcelium" -
        "vcs" {
          if { $a_sim_vars(b_xport_src_files) } {
            set file "\$ref_dir/incl/$src_file"
          } else {
            set file "\$ref_dir/[xcs_get_relative_file_path $file $launch_dir]"
          }
        }
        default {
          if { $a_sim_vars(b_xport_src_files) } {
            set file "srcs/incl/$src_file"
          } else {
            set file "[xcs_get_relative_file_path $file $launch_dir]"
          }
        }
      }
    }
    lappend resolved_file_paths "\"$file\""
  }
  return [join $resolved_file_paths " "]
} 

proc xps_get_design_libs {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set libs [list]
  foreach file $a_sim_vars(l_design_files) {
    set fargs     [split $file {|}]
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

proc xps_export_fs_data_files { filter data_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  upvar $data_files_arg data_files
  foreach ip_obj [get_ips -quiet -all] {
    set data_files [concat $data_files [get_files -all -quiet -of_objects $ip_obj -filter $filter]]
  } 

  set l_fs [list]
  lappend l_fs [get_filesets -filter "FILESET_TYPE == \"BlockSrcs\""]
  lappend l_fs [current_fileset -srcset]
  lappend l_fs $a_sim_vars(fs_obj)
  foreach fs_obj $l_fs {
    set data_files [concat $data_files [get_files -all -quiet -of_objects $fs_obj -filter $filter]]
  }
}

proc xps_set_script_filename {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_valid_ip_extns

  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xcs_is_ip $tcl_obj $l_valid_ip_extns] } {
    set a_sim_vars(ip_filename) [file tail $tcl_obj]
    if { ! $a_sim_vars(b_script_specified) } {
      set ip_name [file root $a_sim_vars(ip_filename)]
      set a_sim_vars(s_script_filename) "${ip_name}"
    }
  } elseif { [xcs_is_fileset $tcl_obj] } {
    if { ! $a_sim_vars(b_script_specified) } {
      set a_sim_vars(s_script_filename) "$a_sim_vars(s_top)"
      if { {} == $a_sim_vars(s_script_filename) } {
        set extn ".sh"
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

proc xps_write_sim_script { run_dir data_files filename } {
  # Summary:
  # Argument Usage:
  # none
  # Return Value:

  variable a_sim_vars
  variable l_target_simulator
  variable l_valid_ip_extns
  variable l_compiled_libraries

  set l_local_ip_libs [xcs_get_libs_from_local_repo]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  foreach simulator $l_target_simulator {
    # initialize and fetch compiled libraries for precompile flow
    set l_compiled_libraries [xps_get_compiled_libraries $simulator l_local_ip_libs]
    set simulator_name [xcs_get_simulator_pretty_name $simulator] 
    #puts ""
    send_msg_id exportsim-Tcl-035 INFO \
      "Exporting simulation files for \"[string toupper $simulator]\" ($simulator_name)...\n"
    set dir "$run_dir/$simulator"
    xps_create_dir $dir
    if { $a_sim_vars(b_xport_src_files) } {
      xps_create_dir "$dir/srcs"
      xps_create_dir "$dir/srcs/incl"
      xps_create_dir "$dir/srcs/ip"
    }
    if { [xcs_is_ip $tcl_obj $l_valid_ip_extns] } {
      set a_sim_vars(s_top) [file tail [file root $tcl_obj]]
      #send_msg_id exportsim-Tcl-026 INFO "Inspecting IP design source files for '$a_sim_vars(s_top)'...\n"

      # check if IP support current simulator
      xps_print_message_for_unsupported_simulator_ip $tcl_obj $simulator

      if {[xps_write_script $simulator $dir $filename]} {
        return 1
      }
    } elseif { [xcs_is_fileset $tcl_obj] } {
      set a_sim_vars(s_top) [get_property top [get_filesets $tcl_obj]]
      #send_msg_id exportsim-Tcl-027 INFO "Inspecting design source files for '$a_sim_vars(s_top)' in fileset '$tcl_obj'...\n"
      if {[string length $a_sim_vars(s_top)] == 0} {
        send_msg_id exportsim-Tcl-070 ERROR \
        "A simulation top was not set. Before running export_simulation a top must be set on the simulation\
        fileset. The top can be set on the simulation fileset by running: set_property top <top_module> \[current_fileset -simset\]\n"
        #set a_sim_vars(s_top) "unknown"
      }

      # check if IP support current simulator (all ips from this fileset)
      xps_print_message_for_unsupported_simulator_fileset $tcl_obj $simulator
     
      if {[xps_write_script $simulator $dir $filename]} {
        return 1
      }
    } else {
      #send_msg_id exportsim-Tcl-028 INFO "Unsupported object source: $tcl_obj\n"
      return 1
    }

    xcs_export_data_files $dir $a_sim_vars(s_ip_user_files_dir) $data_files
    xps_gen_mem_files $dir
    xps_copy_glbl $dir

    if { [xps_write_simulator_readme $simulator $dir] } {
      return 1
    }

    if { [xps_write_filelist_info $simulator $dir] } {
      return 1
    }
  }
  return 0
}

proc xps_get_lib_map_path { simulator {b_ignore_default_for_xsim 0} } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_lib_map_path
  
  set lmp_value {}
  if { $a_sim_vars(b_lib_map_path_specified) } {
    foreach lmp $l_lib_map_path {
      set lmp [string trim $lmp "\}\{ "]
      if { {} == $lmp } { continue }
      if { [regexp {=} $lmp] } {
        set value [split $lmp {=}]
        set name [lindex $value 0]
        set lmp  [lindex $value 1]
        if { [string equal -nocase $simulator $name] } {
          if { {} == $lmp } { continue }
          set lmp_value [file normalize $lmp]
          break;
        }
      } else {
        set lmp_value [file normalize $lmp]
      }
    }
  }

  if { $b_ignore_default_for_xsim } {
    # no op
  } else {
    # default for xsim
    if { ({} == $lmp_value) && ({xsim} == $simulator) } {
      set dir {}
      if { [info exists ::env(XILINX_VIVADO)] } {
        set dir $::env(XILINX_VIVADO)
      }
      set lmp_value [file normalize "$dir/data/xsim"]
    }
  }
  return $lmp_value
}

proc xps_get_compiled_libraries { simulator l_local_ip_libs_arg } { 
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_local_ip_libs_arg l_local_ip_libs
  variable a_sim_vars
  variable l_target_simulator
  set libraries [list]
  set compiled_libraries [list]

  if { !$a_sim_vars(b_use_static_lib) } {
    return $compiled_libraries
  }

  set clibs_dir [xps_get_lib_map_path $simulator]
  if { {} != $clibs_dir } {
    set libraries [xcs_get_compiled_libraries $clibs_dir]
  }

  # filter local ip definitions
  foreach lib $libraries {
    if { [lsearch -exact $l_local_ip_libs $lib] != -1 } {
      continue
    } else {
      lappend compiled_libraries $lib
    }
  }
  return $compiled_libraries
}

proc xps_check_script { dir filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set file [file normalize "$dir/$filename"]
  if { [file exists $file] && (!$a_sim_vars(b_overwrite)) } {
    send_msg_id exportsim-Tcl-032 ERROR "Script file exist:'$file'. Use the -force option to overwrite or select 'Overwrite files' from 'File->Export->Export Simulation' dialog box in GUI."
    return 1
  }
  if { [file exists $file] } {
    if {[catch {file delete -force $file} error_msg] } {
      send_msg_id exportsim-Tcl-033 ERROR "failed to delete file ($file): $error_msg\n"
      return 1
    }
    # cleanup other files
    set files [glob -nocomplain -directory $dir *]
    foreach file_path $files {
      if { {srcs} == [file tail $file_path] } { continue }
      if { {modelsim.ini} == [file tail $file_path] } { continue }
      if { {cds.lib} == [file tail $file_path] } { continue }
      if { {synopsys_sim.setup} == [file tail $file_path] } { continue }
      if { {xsim.ini} == [file tail $file_path] } { continue }
      if {[catch {file delete -force $file_path} error_msg] } {
        send_msg_id exportsim-Tcl-010 ERROR "failed to delete file ($file_path): $error_msg\n"
        return 1
      }
    }
  }
  return 0
}

proc xps_write_script { simulator dir filename } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  variable l_compile_order_files
  variable l_compile_order_files_uniq

  if { [xps_check_script $dir $filename] } {
    return 1
  }

  set a_sim_vars(l_design_files) [xcs_uniquify_cmd_str [xps_get_files $simulator $dir]]
  set l_compile_order_files_uniq [xcs_uniquify_cmd_str $l_compile_order_files]
  
  xps_write_simulation_script $simulator $dir
  send_msg_id exportsim-Tcl-029 INFO \
    "Script generated: '$dir/$filename'\n"
  return 0
}
 
proc xps_write_simulation_script { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  set fh_unix 0

  set file "$dir/$a_sim_vars(s_script_filename)"
  set file_unix ${file}.sh
  if {[catch {open $file_unix w} fh_unix]} {
    send_msg_id exportsim-Tcl-034 ERROR "failed to open file to write ($file_unix)\n"
    return 1
  }

  if { [xps_write_driver_script $simulator $fh_unix $dir] } {
    return 1
  }

  close $fh_unix
  xps_set_permissions $file_unix
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
      send_msg_id USF-XSim-071 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
    }
  }
}
 
proc xps_write_driver_script { simulator fh_unix launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  xps_write_main_driver_procs $simulator $fh_unix $launch_dir

  if { {vcs} == $simulator } {
    xps_create_vcs_do_file $launch_dir
  }

  xps_write_reset $simulator $fh_unix
  xps_write_check_args $fh_unix
  xps_print_usage $fh_unix

  puts $fh_unix "# Launch script"
  puts $fh_unix "run \$1 \$2"
  return 0
}

proc xps_write_main_driver_procs { simulator fh_unix launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  xps_write_header $simulator $fh_unix
  xps_write_main $simulator $fh_unix $launch_dir
  #xps_write_glbl $fh_unix
  xps_write_libs_unix $simulator $fh_unix $launch_dir
  xps_write_lib_dir $simulator $fh_unix $launch_dir
}

proc xps_write_simulator_procs { simulator fh_unix launch_dir srcs_dir } { 
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars

  if { ({ies} == $simulator) || ({xcelium} == $simulator) } {
    xps_write_single_step_for_ies_xcelium $simulator $fh_unix $launch_dir $srcs_dir
  } else {
    xps_write_multi_step $simulator $fh_unix $launch_dir $srcs_dir
  }
}

proc xps_write_single_step_for_ies_xcelium { simulator fh_unix launch_dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_defines
  variable l_generics
  variable l_compiled_libraries
  puts $fh_unix "# RUN_STEP: <execute>"
  puts $fh_unix "execute()\n\{"

  set filename "run.f"
  set arg_list [list]
  set b_verilog_only 0
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] && ![xcs_contains_vhdl $a_sim_vars(l_design_files)] } {
    set b_verilog_only 1
  }

  set base_libs [list "unisim" "unisims_ver" "secureip" "unimacro" "unimacro_ver"]
  # reference XPM modules from precompiled libs if param is set
  set b_reference_xpm_library 0
  [catch {set b_reference_xpm_library [get_param project.usePreCompiledXPMLibForSim]} err]

  # for precompile flow, if xpm library not found from precompiled libs, compile it locally
  # for non-precompile flow, compile xpm locally and do not reference precompiled xpm library
  if { $b_reference_xpm_library } {
    if { $a_sim_vars(b_use_static_lib) } {
      if { ([lsearch -exact $l_compiled_libraries "xpm"] == -1) } {
        set b_reference_xpm_library 0
      }
    } else {
      set b_reference_xpm_library 0
    }
  }

  if { $b_reference_xpm_library } {
    lappend base_libs "xpm"
  }
  if { $a_sim_vars(b_use_static_lib) } {
    variable l_compiled_libraries
    foreach lib [xps_get_design_libs] {
      if {[string length $lib] == 0} { continue; }
      if { [xcs_is_static_ip_lib $lib $l_compiled_libraries] } {
        lappend base_libs [string tolower $lib]
      }
    }
  }

  # add xilinx vip library
  if { [get_param "project.usePreCompiledXilinxVIPLibForSim"] } {
    if { [xcs_design_contain_sv_ip] } {
      if { ([lsearch -exact $l_compiled_libraries "xilinx_vip"] != -1) } {
        lappend base_libs "xilinx_vip"
      }
    }
  }

  foreach lib $base_libs {
    lappend arg_list "-reflib \"\$ref_lib_dir/$lib:$lib\""
  }

  set tool_name "irun"
  if { {xcelium} == $simulator } {
    set tool_name "xrun"
  } 
  set opts [list]
  if { [llength $l_defines] > 0 } {
    xps_append_define_generics $l_defines $tool_name $simulator opts
  }

  if { [llength $l_generics] > 0 } {
    xps_append_define_generics $l_generics $tool_name $simulator opts
  }

  if { [llength $opts] > 0 } {
    foreach opt $opts {
      set opt_str [string trim $opt "\{\}"]
      lappend arg_list  "$opt_str"
    }
  }

  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]

  lappend arg_list  "-top ${top_lib}.$a_sim_vars(s_top)"
  set run_file $filename
  if { $a_sim_vars(b_absolute_path) } {
    set run_file "\"$launch_dir/$run_file\""
  }
  lappend arg_list  "-f $run_file"

  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    lappend arg_list "-top glbl"
    set gfile "glbl.v"
    if { $a_sim_vars(b_absolute_path) } {
      set gfile "\"$launch_dir/$gfile\""
    }
    lappend arg_list "$gfile"
  }

  if { $a_sim_vars(b_xport_src_files) } {
    set incl_file_dir "srcs/incl"
    if { $a_sim_vars(b_absolute_path) } {
      set incl_file_dir "$srcs_dir/incl"
    }
    lappend arg_list "+incdir+\"$incl_file_dir\""
  } else {
    set prefix_ref_dir "false"
    set uniq_dirs [list]
    foreach dir [concat [xps_get_verilog_incl_dirs $simulator $launch_dir $prefix_ref_dir] [xps_get_verilog_incl_file_dirs $simulator $launch_dir $prefix_ref_dir] [xcs_get_vip_include_dirs]] {
      if { [lsearch -exact $uniq_dirs $dir] == -1 } {
        lappend uniq_dirs $dir
        lappend arg_list "+incdir+\"$dir\""
      }
    }
  }

  if { $a_sim_vars(b_runtime_specified) } {
    if { [xps_create_ixrun_do_file $launch_dir] } {
      lappend arg_list "-input $a_sim_vars(do_filename)"
    }
  }

  set cmd_str [join $arg_list " \\\n       "]

  puts $fh_unix "  ${tool_name} \$${tool_name}_opts \\"
  puts $fh_unix "       $cmd_str"

  set fh_run 0
  set file [file normalize "$launch_dir/$filename"]
  if { [catch {open $file w} fh_run] } {
    send_msg_id exportsim-Tcl-038 ERROR "failed to open file to write ($file)\n"
    return 1
  }

  set a_sim_vars(b_single_step) 1
  xps_write_compile_order_for_ies_xcelium_vcs $simulator $fh_run $launch_dir $srcs_dir
  set a_sim_vars(b_single_step) 0

  close $fh_run
  puts $fh_unix "\}\n"

  return 0
}

proc xps_write_multi_step { simulator fh_unix launch_dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  puts $fh_unix "# RUN_STEP: <compile>"
  puts $fh_unix "compile()\n\{"

  if {[llength $a_sim_vars(l_design_files)] == 0} {
    puts $fh_unix "  # None (no simulation source files found)"
    puts $fh_unix "  echo -e \"INFO: No simulation source file(s) to compile\\n\""
    puts $fh_unix "  exit 0"
    puts $fh_unix "\}"
    return 0
  }

  puts $fh_unix "  # Compile design files" 

  switch $simulator { 
    "xsim" {
      set redirect "2>&1 | tee compile.log"
      if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
        puts $fh_unix "  xvlog \$xvlog_opts -prj vlog.prj $redirect"
      }
      if { [xcs_contains_vhdl $a_sim_vars(l_design_files)] } {
        puts $fh_unix "  xvhdl \$xvhdl_opts -prj vhdl.prj $redirect"
      }
      xps_write_xsim_prj $launch_dir $srcs_dir
    }
    "modelsim" -
    "riviera" -
    "activehdl" -
    "questa" {
      puts $fh_unix "  source compile.do 2>&1 | tee -a compile.log"
      xps_write_do_file_for_compile $simulator $launch_dir $srcs_dir
    }
    "vcs" {
      xps_write_compile_order_for_ies_xcelium_vcs "vcs" $fh_unix $launch_dir $srcs_dir
    }
  }
   
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
    switch -regexp -- $simulator {
      "vcs" {
        set sw {}
        if { {work} != $top_lib } {
          set sw "-work $top_lib"
        }

        set gfile "glbl.v"
        if { $a_sim_vars(b_absolute_path) } {
          set gfile "\"$launch_dir/$gfile\""
        }
        puts $fh_unix "  vlogan $sw \$vlogan_opts +v2k \\\n    $gfile \\\n  2>&1 | tee -a vlogan.log"
      }
    }
  }

  puts $fh_unix "\n\}\n"

  switch -regexp -- $simulator {
    "modelsim" -
    "riviera" -
    "activehdl" {}
    default {
      xps_write_elaboration_cmds $simulator $fh_unix $launch_dir
    }
  }

  xps_write_simulation_cmds $simulator $fh_unix $launch_dir

  return 0
}

proc xps_append_config_opts { opts_arg simulator tool } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  set opts_str {}
  switch -exact -- $simulator {
    "xsim" {
      if {"xvlog" == $tool} {set opts_str "--relax"}
      if {"xvhdl" == $tool} {set opts_str "--relax"}
      if {"xelab" == $tool} {set opts_str "--relax --debug typical --mt auto"}
      if {"xsim"  == $tool} {set opts_str ""}
    }
    "modelsim" {
      if {"vlog" == $tool} {set opts_str "-incr"}
      if {"vcom" == $tool} {set opts_str ""}
      if {"vsim" == $tool} {set opts_str ""}
    }
    "riviera" {
      if {"vlog" == $tool} {set opts_str ""}
      if {"vcom" == $tool} {set opts_str ""}
      if {"asim" == $tool} {set opts_str ""}
    }
    "activehdl" {
      if {"vlog" == $tool} {set opts_str ""}
      if {"vcom" == $tool} {set opts_str ""}
      if {"asim" == $tool} {set opts_str ""}
    }
    "questa" {
      if {"vlog"     == $tool} {set opts_str ""}
      if {"vcom"     == $tool} {set opts_str ""}
      if {"vopt"     == $tool} {set opts_str ""}
      if {"vsim"     == $tool} {set opts_str ""}
      if {"qverilog" == $tool} {set opts_str "-incr +acc"}
      if {"sccom"    == $tool} {set opts_str ""}
      if {"g++"      == $tool} {set opts_str ""}
      if {"gcc"      == $tool} {set opts_str ""}
    }
    "ies" {
      if {"irun"   == $tool} {set opts_str "-v93 -relax -access +rwc -namemap_mixgen"}
    }
    "xcelium" {
      if {"xrun"   == $tool} {set opts_str "-v93 -relax -access +rwc -namemap_mixgen"}
    }
    "vcs" {
      if {"vlogan" == $tool} {set opts_str ""}
      if {"vhdlan" == $tool} {set opts_str ""}
      if {"vcs"    == $tool} {set opts_str ""}
      if {"simv"   == $tool} {set opts_str ""}
      if {"g++"    == $tool} {set opts_str ""}
      if {"gcc"    == $tool} {set opts_str ""}
    }
  }
  if { {} != $opts_str } {
    lappend opts $opts_str
  }
}

proc xps_write_ref_dir { fh_unix launch_dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set txt "# Directory path for design sources and include directories (if any) wrt this path"
  if { $a_sim_vars(b_absolute_path) } {
    if { $a_sim_vars(b_xport_src_files) } {
      puts $fh_unix "$txt"
      puts $fh_unix "ref_dir=\"$srcs_dir\""
    }
  } else {
    puts $fh_unix "$txt"
    if { $a_sim_vars(b_xport_src_files) } {
      puts $fh_unix "ref_dir=\"srcs\""
    } else {
      puts $fh_unix "ref_dir=\".\"\n"
      puts $fh_unix "# Override directory with 'export_sim_ref_dir' env path value if set in the shell"
      puts $fh_unix "if \[\[ (! -z \"\$export_sim_ref_dir\") && (\$export_sim_ref_dir != \"\") \]\]; then"
      puts $fh_unix "  ref_dir=\"\$export_sim_ref_dir\""
      puts $fh_unix "fi"
    }
  }
  puts $fh_unix ""
}

proc xps_write_run_steps { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  puts $fh_unix "# Main steps"
  puts $fh_unix "run()\n\{"
  puts $fh_unix "  check_args \$# \$1"
  puts $fh_unix "  setup \$1 \$2"
  if { ({ies} == $simulator) || ({xcelium} == $simulator) } {
    puts $fh_unix "  execute"
  } else {
    puts $fh_unix "  compile"
    switch -regexp -- $simulator {
      "modelsim" -
      "riviera" -
      "activehdl" {}
      default {
        puts $fh_unix "  elaborate"
      }
    }
    puts $fh_unix "  simulate"
  }
  puts $fh_unix "\}\n"
}

proc xps_set_initial_cmd { simulator fh cmd_str srcs_dir src_file file_type lib opts_str prev_file_type_arg prev_lib_arg log_arg } {
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
        puts $fh "$cmd_str ${opts_str} \\"
        if { $a_sim_vars(b_xport_src_files) } {
          puts $fh "srcs/$src_file \\"
        } else {
          puts $fh "$src_file \\"
        }
      }
    }
    "modelsim" -
    "riviera" -
    "activehdl" -
    "questa" {
      puts $fh "$cmd_str \\"
      puts $fh "$src_file \\"
    }
    "ies" -
    "xcelium" {
      if { $a_sim_vars(b_single_step) } {
        set opts {}
        if { [string equal -nocase $file_type "systemverilog"] } {
          set opts "-sv "
        } elseif { [string equal -nocase $file_type "vhdl 2008"] } {
          set opts "-v200x "
        }
        puts $fh "-makelib ${simulator}_lib/$lib $opts\\"
        if { $a_sim_vars(b_xport_src_files) } {
          if { $a_sim_vars(b_absolute_path) } {
            puts $fh "  $srcs_dir/$src_file \\"
          } else {
            puts $fh "  srcs/$src_file \\"
          }
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

# multi-step (vcs), single-step (ies, xcelium) 
proc xps_write_compile_order_for_ies_xcelium_vcs { simulator fh launch_dir srcs_dir } {
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
    set fargs          [split $file {|}]
    set type           [lindex $fargs 0]
    set file_type      [lindex $fargs 1]
    set lib            [lindex $fargs 2]
    set proj_src_file  [lindex $fargs 3]
    set cmd_str        [lindex $fargs 4]
    set ip_file        [lindex $fargs 5]
    set src_file       [lindex $fargs 6]
    set b_static_ip    [lindex $fargs 7]
    set b_xpm          [lindex $fargs 8]

    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }

    if { $a_sim_vars(b_absolute_path) || $b_xpm} {
      # no op
    } else {
      switch $simulator {
        "ies" -
        "xcelium" {
          if { $a_sim_vars(b_xport_src_files) } {
            set source_file "\$ref_dir/incl"
            if { {} != $ip_file } {
              # no op
            } else {
            }
          } else {
            if { {} != $ip_file } {
              set source_file [string trim $src_file {\"}]
              set src_file "\$ref_dir/$source_file"
              if { $a_sim_vars(b_single_step) } {
                set src_file "$source_file"
              }
              set src_file "\"$src_file\""
            } else {
              set source_file [string trim $src_file {\"}]
              set src_file "\$ref_dir/[xcs_get_relative_file_path $source_file $launch_dir]"
              if { $a_sim_vars(b_single_step) } {
                set src_file "[xcs_get_relative_file_path $proj_src_file $launch_dir]"
              }
              set src_file "\"$src_file\""
            }
          }
        }
        "vcs" {
          if { $a_sim_vars(b_xport_src_files) } {
            set source_file "\$ref_dir/incl"
            if { {} != $ip_file } {
              # no op
            } else {
            }
          } else {
            if { {} != $ip_file } {
              set source_file [string trim $src_file {\"}]
              set src_file "\$ref_dir/$source_file"
              #set src_file "\$ref_dir/[xcs_get_relative_file_path $source_file $launch_dir]"
              set src_file "\"$src_file\""
            } else {
              set source_file [string trim $src_file {\"}]
              set src_file "\$ref_dir/[xcs_get_relative_file_path $source_file $launch_dir]"
              set src_file "\"$src_file\""
            }
          }
        }
      }
    }
    set proj_src_filename [file tail $proj_src_file]
    if { $a_sim_vars(b_xport_src_files) } {
      set target_dir $srcs_dir
      if { {} != $ip_file } {
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "ip/$ip_name/$lib/$proj_src_filename"
        set ip_dir "$srcs_dir/ip/$ip_name/$lib"
        if { ![file exists $ip_dir] } {
          if {[catch {file mkdir $ip_dir} error_msg] } {
            send_msg_id exportsim-Tcl-040 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
            return 1
          }
        }
        set target_dir $ip_dir
      }
      if { [get_param project.enableCentralSimRepo] } {
        if { $a_sim_vars(b_xport_src_files) } {
          if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
            send_msg_id exportsim-Tcl-041 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
          }
        } else { 
          set repo_file $src_file
          set repo_file [string trim $repo_file "\""]
          if {[catch {file copy -force $repo_file $target_dir} error_msg] } {
            send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$repo_file' to '$srcs_dir' : $error_msg\n"
          }
        }
      } else {
        if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
          send_msg_id exportsim-Tcl-041 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
        }
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

    set b_redirect false
    set b_appended false
    if { $b_first } {
      set b_first false
      if { $a_sim_vars(b_xport_src_files) } {
        xps_set_initial_cmd $simulator $fh $cmd_str $srcs_dir $proj_src_filename $file_type $lib {} prev_file_type prev_lib log
      } else {
        xps_set_initial_cmd $simulator $fh $cmd_str $srcs_dir $src_file $file_type $lib {} prev_file_type prev_lib log
      }
    } else {
      if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
        # single_step
        if { $a_sim_vars(b_single_step) } {
          if { $a_sim_vars(b_xport_src_files) } {
            switch $simulator {
              "ies" -
              "xcelium" {
                if { $a_sim_vars(b_absolute_path) } {
                  puts $fh "  $srcs_dir/$proj_src_filename \\"
                } else {
                  puts $fh "  srcs/$proj_src_filename \\"
                }
              }
            }
          } else {
            switch $simulator {
              "ies" -
              "xcelium" {
                puts $fh "  $src_file \\"
              }
            }
          }
        } else {
          if { $a_sim_vars(b_xport_src_files) } {
            switch $simulator {
              "ies" -
              "xcelium" {
                puts $fh "    \$ref_dir/$proj_src_filename \\"
              }
              "vcs" {
                puts $fh "    \$ref_dir/$proj_src_filename \\"
              }
            }
          } else {
            switch $simulator {
              "ies" -
              "xcelium" {
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
          "ies" -
          "xcelium" {
            if { $a_sim_vars(b_single_step) } {
              puts $fh "-endlib"
            } else {
              puts $fh ""
            }
          }
          "vcs"    { puts $fh "$redirect_cmd_str $log\n" }
        }
        if { $a_sim_vars(b_xport_src_files) } {
          xps_set_initial_cmd $simulator $fh $cmd_str $srcs_dir $proj_src_filename $file_type $lib {} prev_file_type prev_lib log
        } else {
          xps_set_initial_cmd $simulator $fh $cmd_str $srcs_dir $src_file $file_type $lib {} prev_file_type prev_lib log
        }
        set b_appended true
      }
    }
  }

  if { $a_sim_vars(b_single_step) } {
    switch $simulator {
      "ies" -
      "xcelium" {
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

  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    if { $a_sim_vars(b_single_step) } { 
      switch -regexp -- $simulator {
        "ies" -
        "xcelium" {
          puts $fh "-makelib ${simulator}_lib/$a_sim_vars(default_lib) \\"
          set file "glbl.v"
          if { $a_sim_vars(b_absolute_path) } {
            set file "\"$launch_dir/$file\""
          }
          puts $fh "  $file"
          puts $fh "-endlib"
        }
      }
    }
  }
  # do not remove this
  puts $fh ""

}

proc xps_write_header { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:
  # none
 
  variable a_sim_vars
 
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set swbuild     [lindex $version_txt 1]
  set copyright   [lindex $version_txt 3]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  set extn ".sh"
  set script_file $a_sim_vars(s_script_filename)$extn
  puts $fh_unix "#!/bin/bash -f"
  puts $fh_unix "#*********************************************************************************************************"
  puts $fh_unix "# $product (TM) $version_id\n#"
  puts $fh_unix "# Filename    : $a_sim_vars(s_script_filename)$extn"
  puts $fh_unix "# Simulator   : [xcs_get_simulator_pretty_name $simulator]"
  puts $fh_unix "# Description : Simulation script for compiling, elaborating and verifying the project source files."
  puts $fh_unix "#               The script will automatically create the design libraries sub-directories in the run"
  puts $fh_unix "#               directory, add the library logical mappings in the simulator setup file, create default"
  puts $fh_unix "#               'do/prj' file, execute compilation, elaboration and simulation steps.\n#"
  puts $fh_unix "# Generated by $product on $a_sim_vars(curr_time)"
  puts $fh_unix "# $swbuild\n#"
  puts $fh_unix "# $copyright \n#"
  puts $fh_unix "# usage: $script_file \[-help\]"
  puts $fh_unix "# usage: $script_file \[-lib_map_path\]"
  puts $fh_unix "# usage: $script_file \[-noclean_files\]"
  puts $fh_unix "# usage: $script_file \[-reset_run\]\n#"
  switch -regexp -- $simulator {
    "xsim" {
    }
    default {
      puts $fh_unix "# Prerequisite:- To compile and run simulation, you must compile the Xilinx simulation libraries using the"
      puts $fh_unix "# 'compile_simlib' TCL command. For more information about this command, run 'compile_simlib -help' in the"
      puts $fh_unix "# $product Tcl Shell. Once the libraries have been compiled successfully, specify the -lib_map_path switch"
      puts $fh_unix "# that points to these libraries and rerun export_simulation. For more information about this switch please"
      puts $fh_unix "# type 'export_simulation -help' in the Tcl shell.\n#"
      puts $fh_unix "# You can also point to the simulation libraries by either replacing the <SPECIFY_COMPILED_LIB_PATH> in this"
      puts $fh_unix "# script with the compiled library directory path or specify this path with the '-lib_map_path' switch when"
      puts $fh_unix "# executing this script. Please type '$script_file -help' for more information.\n#"
      puts $fh_unix "# Additional references - 'Xilinx Vivado Design Suite User Guide:Logic simulation (UG900)'\n#"
    }
  }
  puts $fh_unix "#*********************************************************************************************************\n"
}

proc xps_write_elaboration_cmds { simulator fh_unix dir} {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  variable l_generics
  set top $a_sim_vars(s_top)

  puts $fh_unix "# RUN_STEP: <elaborate>"
  puts $fh_unix "elaborate()\n\{"

  if {[llength $a_sim_vars(l_design_files)] == 0} {
    puts $fh_unix "# None (no sources present)"
    return 0
  }
 
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
  set clibs_dir [xps_get_lib_map_path $simulator]
  switch -regexp -- $simulator {
    "xsim" {
      xps_write_xelab_cmdline $fh_unix $dir
    }
    "modelsim" -
    "riviera" -
    "activehdl" -
    "questa" {
      if { $a_sim_vars(b_contain_systemc_sources) } {
        set shared_ip_libs [list]
        foreach shared_ip_lib [xcs_get_shared_ip_libraries $clibs_dir] {
          set lib_dir "[xps_get_lib_map_path $simulator]/$shared_ip_lib"
          lappend shared_ip_libs $lib_dir
        }
        if { [llength $shared_ip_libs] > 0 } {
          set shared_ip_libs_env_path [join $shared_ip_libs ":"]
          puts $fh_unix "  export LD_LIBRARY_PATH=$shared_ip_libs_env_path:\$LD_LIBRARY_PATH"
        }
      }
      puts $fh_unix "  source elaborate.do 2>&1 | tee -a elaborate.log"
      xps_write_do_file_for_elaborate $simulator $dir
    }
    "ies" -
    "xcelium" {
      set compiler "ncelab"
      if { {xcelium} == $simulator } {
        set compiler "xmelab"
      }
      set arg_list [list $compiler "\$ncelab_opts"]
      if { [xcs_is_fileset $a_sim_vars(sp_tcl_obj)] } {
        if { [llength $l_generics] > 0 } {
          xps_append_define_generics $l_generics $compiler $simulator arg_list
        }
      }
      lappend arg_list "${top_lib}.$a_sim_vars(s_top)"
      if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
        lappend arg_list "${top_lib}.glbl"
      }
      lappend arg_list "\$design_libs"
      set cmd_str [join $arg_list " "]
      puts $fh_unix "  $cmd_str"
    }
    "vcs" {
      set arg_list [list "vcs" "\$vcs_elab_opts" "${top_lib}.$a_sim_vars(s_top)"]
      if { [xcs_is_fileset $a_sim_vars(sp_tcl_obj)] } {
        if { [llength $l_generics] > 0 } {
          xps_append_define_generics $l_generics "vcs" $simulator arg_list
        }
      }
      if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
        lappend arg_list "${top_lib}.glbl"
      }
      lappend arg_list "-o"
      lappend arg_list "$a_sim_vars(s_top)_simv"
      set cmd_str [join $arg_list " "]
      puts $fh_unix "  $cmd_str"
    }
  }
  puts $fh_unix "\}\n"
  return 0
}
 
proc xps_write_simulation_cmds { simulator fh_unix dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars

  puts $fh_unix "# RUN_STEP: <simulate>"
  puts $fh_unix "simulate()\n\{"
  if {[llength $a_sim_vars(l_design_files)] == 0} {
    puts $fh_unix "# None (no sources present)"
    return 0
  }

  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
  switch -regexp -- $simulator {
    "xsim" {
      xps_write_xsim_cmdline $fh_unix $dir
    }
    "riviera" -
    "activehdl" {
      set cmd_str "runvsimsa -l simulate.log -do \"do \{$a_sim_vars(do_filename)\}\""
      puts $fh_unix "  $cmd_str"
      xps_write_do_file_for_simulate $simulator $dir
    }
    "modelsim" {
      set s_64bit {}
      if { !$a_sim_vars(b_32bit) } {
        set s_64bit {-64}
      }
      set cmd_str "vsim $s_64bit -c -do \"do \{$a_sim_vars(do_filename)\}\" -l simulate.log"
      puts $fh_unix "  $cmd_str"
      xps_write_do_file_for_simulate $simulator $dir
    }
    "questa" {
      set s_64bit {}
      if { !$a_sim_vars(b_32bit) } {
        set s_64bit {-64}
      }
      set cmd_str "vsim $s_64bit -c -do \"do \{$a_sim_vars(do_filename)\}\" -l simulate.log"
      puts $fh_unix "  $cmd_str"
      xps_write_do_file_for_simulate $simulator $dir
    }
    "ies" -
    "xcelium" {
      set tool "ncsim"
      if { {xcelium} == $tool } {
        set tool "xmsim"
      }
      set arg_list [list]
      lappend arg_list $tool
      xps_append_config_opts arg_list $simulator $tool
      lappend arg_list "\$${tool}_opts" "${top_lib}.$a_sim_vars(s_top)" "-input" "$a_sim_vars(do_filename)"
      set cmd_str [join $arg_list " "]
      puts $fh_unix "  $cmd_str"
    }
    "vcs" {
      set arg_list [list "./$a_sim_vars(s_top)_simv" "\$vcs_sim_opts" "-do" "$a_sim_vars(do_filename)"]
      set cmd_str [join $arg_list " "]
      puts $fh_unix "  $cmd_str"
    }
  }
  puts $fh_unix "\}\n"
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

proc xps_append_define_generics { def_gen_list tool simulator opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  foreach element $def_gen_list {
    set key_val_pair [split $element "="]
    set name [lindex $key_val_pair 0]
    set val  [lindex $key_val_pair 1]
    set str {}
    switch $tool {
      "vlog" {
        switch -regexp -- $simulator {
          "riviera" { set str "+define+$name"  }
          default   { set str "+define+$name=" }
        }
      }
      "ncvlog" -
      "xmvlog" -
      "irun" -
      "xrun"   { set str "-define \"$name=" }
      "vlogan" { set str "+define+$name="   }
      "ncelab" -
      "xmelab" -
      "ies"    -
      "xcelium" { set str "-generic \"$name=>" }
      "vcs"     { set str "-gv $name=\""       }
    }

    if { [string length $val] > 0 } {
      if { {vlog} == $tool } {
        if { [regexp {'} $val] } {
          regsub -all {'} $val {\\'} val
        }
      }
    }

    if { [string length $val] > 0 } {
      switch $tool {
        "vlog"   { set str "$str$val"   }
        "ncvlog" -
        "xmvlog" -
        "irun"   -
        "xrun"   { set str "$str$val\""   }
        "vlogan" { set str "$str\"$val\"" }
        "ncelab" -
        "xmelab" -
        "ies"    -
        "xcelium" { set str "$str$val\"" }
        "vcs"     { set str "$str$val\"" }
      }
    } else {
      switch $tool {
        "vlog"   { set str "$str"   }
        "ncvlog" -
        "xmvlog" -
        "irun"   -
        "xrun"   { set str "$str\"" }
        "vlogan" { set str "$str"   }
        "ncelab" -
        "xmelab" -
        "ies"    -
        "xcelium" { set str "$str\"" }
        "vcs"     { set str "$str\"" }
      }
    }
    lappend opts "$str"
  }
}

proc xps_append_compiler_options { simulator launch_dir tool file_type l_verilog_incl_dirs_arg opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_verilog_incl_dirs_arg l_verilog_incl_dirs
  upvar $opts_arg opts
  variable a_sim_vars
  variable l_defines
  variable a_sim_sv_pkg_libs
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  switch $tool {
    "vcom" {
      set s_64bit {-64}
      if { $a_sim_vars(b_32bit) } {
        set s_64bit {-32}
      }
      set arg_list [list $s_64bit]
      if { ({riviera} == $simulator) || ({activehdl} == $simulator) } {
        set arg_list [list]
      }
      set opts_str "-93"
      if { [string equal -nocase $file_type "vhdl 2008"] } {
        set opts_str "-2008"
      }
      lappend arg_list $opts_str
      xps_append_config_opts arg_list $simulator "vcom"
      set cmd_str [join $arg_list " "]
      lappend opts $cmd_str
    }
    "vlog" {
      set s_64bit {-64}
      if { $a_sim_vars(b_32bit) } {
        set s_64bit {-32}
      }
      set arg_list [list $s_64bit]
      if { ({riviera} == $simulator) || ({activehdl} == $simulator) } {
        # reset arg list (platform switch not applicable for riviera/active-hdl)
        set arg_list [list]
      }
      xps_append_config_opts arg_list $simulator "vlog"
      set cmd_str [join $arg_list " "]
      lappend opts $cmd_str
      if { ({riviera} == $simulator) || ({activehdl} == $simulator) } {
        if { [string equal -nocase $file_type "systemverilog"] } {
          lappend opts "-sv2k12"
        } else {
          lappend opts "-v2k5"
        }
      } else {
        # for ModelSim/Questa pass -sv for system verilog filetypes
        if { [string equal -nocase $file_type "systemverilog"] } {
          lappend opts "-sv"
          # append sv pkg libs
          foreach sv_pkg_lib $a_sim_sv_pkg_libs {
            lappend opts "-L $sv_pkg_lib"
          }
        }
      }
    }
    "sccom" {
      set s_64bit {-64}
      if { $a_sim_vars(b_32bit) } {
        set s_64bit {-32}
      }
      set arg_list [list $s_64bit]
      xps_append_config_opts arg_list $simulator "sccom"
      set cmd_str [join $arg_list " "]
      lappend opts $cmd_str
    }
    "g++" {
      if { $a_sim_vars(b_contain_systemc_sources) } {
        set arg_list [list]
        xps_append_config_opts arg_list $simulator "g++"
        set cmd_str [join $arg_list " "]
        lappend opts $cmd_str
      }
    }
    "gcc" {
      if { $a_sim_vars(b_contain_systemc_sources) } {
        set arg_list [list]
        xps_append_config_opts arg_list $simulator "gcc"
        set cmd_str [join $arg_list " "]
        lappend opts $cmd_str
      }
    }
    "ncvhdl" { 
      lappend opts "\$ncvhdl_opts"
    }
    "xmvhdl" { 
      lappend opts "\$xmvhdl_opts"
    }
    "vhdlan" {
      lappend opts "\$vhdlan_opts"
      if { [string equal -nocase $file_type "vhdl 2008"] } {
        lappend opts "-vhdl08"
      }
    }
    "ncvlog" {
      lappend opts "\$ncvlog_opts"
      if { [string equal -nocase $file_type "systemverilog"] } {
        lappend opts "-sv"
      }
    }
    "xmvlog" {
      lappend opts "\$xmvlog_opts"
      if { [string equal -nocase $file_type "systemverilog"] } {
        lappend opts "-sv"
      }
    }
    "vlogan" {
      lappend opts "\$vlogan_opts"
      if { [string equal -nocase $file_type "verilog"] } {
        lappend opts "+v2k"
      } elseif { [string equal -nocase $file_type "systemverilog"] } {
        lappend opts "-sverilog"
      }
    }
  }

  # append verilog defines, include dirs and include file dirs
  switch $tool {
    "vlog" -
    "ncvlog" -
    "xmvlog" -
    "vlogan" {
      if { [llength $l_defines] > 0 } {
        xps_append_define_generics $l_defines $tool $simulator opts
      }
 
      # include dirs
      set prefix_ref_dir "true"
      set uniq_dirs [list]
      foreach dir $l_verilog_incl_dirs {
        if { {vlogan} == $tool } {
          set dir [string trim $dir "\""]
          regsub -all { } $dir {\\\\ } dir
        }
        if { [lsearch -exact $uniq_dirs $dir] == -1 } {
          lappend uniq_dirs $dir
          if { ({questa} == $simulator) || ({modelsim} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator)} {
            lappend opts "\"+incdir+$dir\""
          } else {
            lappend opts "+incdir+\"$dir\""
          }
        }
      }
    }
  }
}
 
proc xps_contains_system_verilog {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set design_files $a_sim_vars(l_design_files)
  set b_sys_verilog_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {|}] 1]
    if { {SystemVerilog} == $type } {
      set b_sys_verilog_srcs 1
    }
  }
  return $b_sys_verilog_srcs 
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
  variable l_valid_ip_extns

  set regen_ip [dict create] 
  set b_single_ip 0
  if { ([xcs_is_ip $a_sim_vars(sp_tcl_obj) $l_valid_ip_extns]) && ({.xci} == $a_sim_vars(s_ip_file_extn)) } {
    set ip [file root [file tail $a_sim_vars(sp_tcl_obj)]]
    set ip_obj [get_ips -all -quiet $ip]
    # make sure ip advertises targets and support simulation target
    if { {} == [get_property delivered_targets $ip_obj] } {
      return
    }
    if { [lsearch [get_property supported_targets $ip_obj] "simulation"] == -1 } {
      return
    }
    set xci_obj [lindex [get_files -quiet -all ${ip}.xci] 0]
    # is user-disabled? or auto_disabled? skip
    if { ({0} == [get_property is_enabled $xci_obj]) ||
         ({1} == [get_property is_auto_disabled $xci_obj]) } {
      return
    }
    dict set regen_ip $ip generated_sim [get_property is_ip_generated_sim $xci_obj]
    dict set regen_ip $ip stale         [get_property stale_targets $ip_obj]
    set b_single_ip 1
  } else {
    foreach ip_obj [lsort -unique [get_ips -all -quiet]] {
      # make sure ip advertises targets and support simulation target
      if { {} == [get_property delivered_targets $ip_obj] } {
        continue
      }
      if { [lsearch [get_property supported_targets $ip_obj] "simulation"] == -1 } {
        continue
      }
           
      # is user-disabled? or auto_disabled? continue
      set ip_file {}
      set ip_file_xci [lindex [get_files -quiet -all ${ip_obj}.xci] 0]
      if { [llength $ip_file_xci] == 0 } {
        set ip_file [get_files -quiet -all ${ip_obj}.xco]
      } else {
        set ip_file $ip_file_xci
      }
      if { [llength $ip_file] == 0 } {
        continue
      }
      if { ({0} == [get_property is_enabled $ip_file]) ||
           ({1} == [get_property is_auto_disabled $ip_file]) } {
        continue
      }
      dict set regen_ip $ip_obj generated_sim [get_property is_ip_generated_sim $ip_file_xci]
      dict set regen_ip $ip_obj stale [get_property stale_targets $ip_obj]
    }
  } 

  set not_generated [list]
  set stale_ips [list]
  dict for {ip regen} $regen_ip {
    dict with regen {
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

proc xps_print_usage { fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  puts $fh_unix "# Script usage"
  puts $fh_unix "usage()"
  puts $fh_unix "\{"
  puts $fh_unix "  msg=\"Usage: $a_sim_vars(s_script_filename).sh \[-help\]\\n\\"
  puts $fh_unix "Usage: $a_sim_vars(s_script_filename).sh \[-lib_map_path\]\\n\\"
  puts $fh_unix "Usage: $a_sim_vars(s_script_filename).sh \[-reset_run\]\\n\\"
  puts $fh_unix "Usage: $a_sim_vars(s_script_filename).sh \[-noclean_files\]\\n\\n\\"
  puts $fh_unix "\[-help\] -- Print help information for this script\\n\\n\\"
  puts $fh_unix "\[-lib_map_path\ <path>] -- Compiled simulation library directory path. The simulation library is compiled\\n\\"
  puts $fh_unix "using the compile_simlib tcl command. Please see 'compile_simlib -help' for more information.\\n\\n\\"
  puts $fh_unix "\[-reset_run\] -- Recreate simulator setup files and library mappings for a clean run. The generated files\\n\\"
  puts $fh_unix "from the previous run will be removed. If you don't want to remove the simulator generated files, use the\\n\\"
  puts $fh_unix "-noclean_files switch.\\n\\n\\"
  puts $fh_unix "\[-noclean_files\] -- Reset previous run, but do not remove simulator generated files from the previous run.\\n\\n\""
  puts $fh_unix "  echo -e \$msg"
  puts $fh_unix "  exit 1"
  puts $fh_unix "\}"
  puts $fh_unix ""
}

proc xps_write_libs_unix { simulator fh_unix launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_local_design_libraries
  switch $simulator {
    "xsim" {
      if { $a_sim_vars(b_use_static_lib) } {
        puts $fh_unix "# Copy xsim.ini file"
        puts $fh_unix "copy_setup_file()"
        puts $fh_unix "\{"
        puts $fh_unix "  file=\"xsim.ini\""
      }
    }
    "riviera" -
    "activehdl" {
      puts $fh_unix "# Map library.cfg file"
      puts $fh_unix "map_setup_file()"
      puts $fh_unix "\{"
      puts $fh_unix "  file=\"library.cfg\""
    }
    "modelsim" -
    "questa" {
      puts $fh_unix "# Copy modelsim.ini file"
      puts $fh_unix "copy_setup_file()"
      puts $fh_unix "\{"
      puts $fh_unix "  file=\"modelsim.ini\""
    }
    "vcs" {
      puts $fh_unix "# Define design library mappings"
      puts $fh_unix "create_lib_mappings()"
      puts $fh_unix "\{"
      puts $fh_unix "  file=\"synopsys_sim.setup\""
      puts $fh_unix "  if \[\[ -e \$file \]\]; then"
      puts $fh_unix "    if \[\[ (\$1 == \"\") \]\]; then"
      puts $fh_unix "      return"
      puts $fh_unix "    else"
      puts $fh_unix "      rm -rf \$file"
      puts $fh_unix "    fi"
      puts $fh_unix "  fi\n"
      puts $fh_unix "  touch \$file\n"
    }
  }

  if { {xsim} == $simulator } {
    if { $a_sim_vars(b_use_static_lib) } {

      # default dir
      set compiled_lib_dir {}
      if { [info exists ::env(XILINX_VIVADO)] } {
        set xil_dir $::env(XILINX_VIVADO)
        set compiled_lib_dir [file normalize "$xil_dir/data/xsim"]
      }
      puts $fh_unix "  lib_map_path=\"$compiled_lib_dir\""
      puts $fh_unix "  if \[\[ (\$1 != \"\") \]\]; then"
      puts $fh_unix "    lib_map_path=\"\$1\""
      puts $fh_unix "  fi"
    } else {
      xps_write_xsim_setup_file $launch_dir
    }
  } elseif { ({riviera} == $simulator) || ({activehdl} == $simulator) || ({modelsim} == $simulator) || ({questa} == $simulator) || ({vcs} == $simulator) } {
    # is -lib_map_path specified and point to valid location?
    set lmp [xps_get_lib_map_path $simulator]
    if { {} != $lmp } {
      set compiled_lib_dir $lmp
      if { ![file exists $compiled_lib_dir] } {
        [catch {send_msg_id exportsim-Tcl-046 ERROR "Compiled simulation library directory path does not exist:$compiled_lib_dir\n"}]
        puts $fh_unix "  lib_map_path=\"<SPECIFY_COMPILED_LIB_PATH>\""
        puts $fh_unix "  if \[\[ (\$1 != \"\" && -e \$1) \]\]; then"
        puts $fh_unix "    lib_map_path=\"\$1\""
        puts $fh_unix "  else"
        puts $fh_unix "    echo -e \"ERROR: Compiled simulation library directory path not specified or does not exist (type \"./top.sh -help\" for more information)\\n\""
        puts $fh_unix "  fi"
      } else {
        puts $fh_unix "  if \[\[ (\$1 != \"\") \]\]; then"
        puts $fh_unix "    lib_map_path=\"\$1\""
        puts $fh_unix "  else"
        puts $fh_unix "    lib_map_path=\"$compiled_lib_dir\""
        puts $fh_unix "  fi"
      }
    } else {
      puts $fh_unix "  lib_map_path=\"\""
      puts $fh_unix "  if \[\[ (\$1 != \"\") \]\]; then"
      puts $fh_unix "    lib_map_path=\"\$1\""
      puts $fh_unix "  fi"
    }
  }
 
  switch -regexp -- $simulator {
    "xsim" {
      if { $a_sim_vars(b_use_static_lib) } {
        puts $fh_unix "  if \[\[ (\$lib_map_path != \"\") \]\]; then"
        puts $fh_unix "    src_file=\"\$lib_map_path/\$file\""
        puts $fh_unix "    if \[\[ -e \$src_file \]\]; then"
        puts $fh_unix "      cp \$src_file ."
        puts $fh_unix "    fi"
        puts $fh_unix "\n    # Map local design libraries to xsim.ini"
        puts $fh_unix "    map_local_libs\n"
        puts $fh_unix "  fi"
        puts $fh_unix "\}\n"

        set local_libs [join $l_local_design_libraries " "]
        puts $fh_unix "# Map local design libraries"
        puts $fh_unix "map_local_libs()"
        puts $fh_unix "\{"
        puts $fh_unix "  updated_mappings=()"
        puts $fh_unix "  local_mappings=()\n"
        puts $fh_unix "  # Local design libraries"
        puts $fh_unix "  local_libs=($local_libs)\n"
        puts $fh_unix "  if \[\[ 0 == \$\{#local_libs\[@\]\} \]\]; then"
        puts $fh_unix "    return"
        puts $fh_unix "  fi\n"
        puts $fh_unix "  file=\"xsim.ini\""
        puts $fh_unix "  file_backup=\"xsim.ini.bak\"\n"
        puts $fh_unix "  if \[\[ -e \$file \]\]; then"
        puts $fh_unix "    rm -f \$file_backup"
        puts $fh_unix "    # Create a backup copy of the xsim.ini file"
        puts $fh_unix "    cp \$file \$file_backup"
        puts $fh_unix "    # Read libraries from backup file and search in local library collection"
        puts $fh_unix "    while read -r line"
        puts $fh_unix "    do"
        puts $fh_unix "      IN=\$line"
        puts $fh_unix "      # Split mapping entry with '=' delimiter to fetch library name and mapping"
        puts $fh_unix "      read lib_name mapping <<<\$(IFS=\"=\"; echo \$IN)"
        puts $fh_unix "      # If local library found, then construct the local mapping and add to local mapping collection"
        puts $fh_unix "      if `echo \$\{local_libs\[@\]\} | grep -wq \$lib_name` ; then"
        puts $fh_unix "        line=\"\$lib_name=xsim.dir/\$lib_name\""
        puts $fh_unix "        local_mappings+=(\"\$lib_name\")"
        puts $fh_unix "      fi"
        puts $fh_unix "      # Add to updated library mapping collection"
        puts $fh_unix "      updated_mappings+=(\"\$line\")"
        puts $fh_unix "    done < \"\$file_backup\""
        puts $fh_unix "    # Append local libraries not found originally from xsim.ini"
        puts $fh_unix "    for (( i=0; i<\$\{#local_libs\[*\]\}; i++ )); do"
        puts $fh_unix "      lib_name=\"\$\{local_libs\[i\]\}\""
        puts $fh_unix "      if `echo \$\{local_mappings\[@\]\} | grep -wvq \$lib_name` ; then"
        puts $fh_unix "        line=\"\$lib_name=xsim.dir/\$lib_name\""
        puts $fh_unix "        updated_mappings+=(\"\$line\")"
        puts $fh_unix "      fi"
        puts $fh_unix "    done"
        puts $fh_unix "    # Write updated mappings in xsim.ini"
        puts $fh_unix "    rm -f \$file"
        puts $fh_unix "    for (( i=0; i<\$\{#updated_mappings\[*\]\}; i++ )); do"
        puts $fh_unix "      lib_name=\"\$\{updated_mappings\[i\]\}\""
        puts $fh_unix "      echo \$lib_name >> \$file"
        puts $fh_unix "    done"
        puts $fh_unix "  else"
        puts $fh_unix "    for (( i=0; i<\$\{#local_libs\[*\]\}; i++ )); do"
        puts $fh_unix "      lib_name=\"\$\{local_libs\[i\]\}\""
        puts $fh_unix "      mapping=\"\$lib_name=xsim.dir/\$lib_name\""
        puts $fh_unix "      echo \$mapping >> \$file"
        puts $fh_unix "    done"
        puts $fh_unix "  fi"
        puts $fh_unix "\}\n"

        # physically copy file to run dir for windows
        if {$::tcl_platform(platform) == "windows"} {
          set dir {}
          if { [info exists ::env(XILINX_VIVADO)] } {
            set dir $::env(XILINX_VIVADO)
          }
          if { {} != $dir } {
            set clibs_dir [file normalize "$dir/data/xsim"]
            set target_file "$launch_dir/xsim.ini"
            set ip_file "$clibs_dir/xsim.ini"
            if { [file exists $ip_file] } {
              if {[catch {file copy -force $ip_file $target_file} error_msg] } {
                send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$ip_file' to '$launch_dir' : $error_msg\n"
              }
            }
          } else {
            send_msg_id exportsim-Tcl-051 WARNING "Failed to get the xsim.ini file from XILINX_VIVADO! Please set XILINX_VIVADO to the install location.\n"
          }
        }
      } else {
        if {$::tcl_platform(platform) == "windows"} {
          set lmp [xps_get_lib_map_path $simulator 1]
          if { {} != $lmp } {
            set ip_file "$lmp/xsim.ini"
            set target_file "$launch_dir/xsim.ini"
            if { [file exists $ip_file] } {
              if {[catch {file copy -force $ip_file $target_file} error_msg] } {
                send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$ip_file' to '$launch_dir' : $error_msg\n"
              }
            }
          }
        }
      }
    }
    "riviera" -
    "activehdl" {
      puts $fh_unix "  if \[\[ (\$lib_map_path != \"\") \]\]; then"
      puts $fh_unix "    src_file=\"\$lib_map_path/\$file\""
      puts $fh_unix "    if \[\[ -e \$src_file \]\]; then"
      puts $fh_unix "      vmap -link \$lib_map_path"
      puts $fh_unix "    fi"
      puts $fh_unix "  fi"
      puts $fh_unix "\}\n"

      # physically copy library.cfg file to run dir for windows
      if {$::tcl_platform(platform) == "windows"} {
        set lmp [xps_get_lib_map_path $simulator]
        if { {} != $lmp } {
          set ini_file "$lmp/library.cfg"
          set target_file "$launch_dir/library.cfg"
          if { [file exists $ini_file] } {
            if {[catch {file copy -force $ini_file $target_file} error_msg] } {
              send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$ini_file' to '$launch_dir' : $error_msg\n"
            }
          }
        }
      }
    }
    "modelsim" -
    "questa" {
      puts $fh_unix "  if \[\[ (\$lib_map_path != \"\") \]\]; then"
      puts $fh_unix "    src_file=\"\$lib_map_path/\$file\""
      puts $fh_unix "    cp \$src_file ."
      puts $fh_unix "  fi"
      puts $fh_unix "\}\n"

      # physically copy modelsim.ini file to run dir for windows
      if {$::tcl_platform(platform) == "windows"} {
        set lmp [xps_get_lib_map_path $simulator]
        if { {} != $lmp } {
          set ini_file "$lmp/modelsim.ini"
          set target_file "$launch_dir/modelsim.ini"
          if { [file exists $ini_file] } {
            if {[catch {file copy -force $ini_file $target_file} error_msg] } {
              send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$ini_file' to '$launch_dir' : $error_msg\n"
            }
          }
        }
      }
    }
  }

  switch -regexp -- $simulator {
    "vcs" {
      puts $fh_unix ""
      puts $fh_unix "  for (( i=0; i<\$\{#design_libs\[*\]\}; i++ )); do"
      puts $fh_unix "    lib=\"\$\{design_libs\[i\]\}\""
      puts $fh_unix "    mapping=\"\$lib:\$sim_lib_dir/\$lib\""
      puts $fh_unix "    echo \$mapping >> \$file"
      puts $fh_unix "  done\n"
      set file "synopsys_sim.setup"
      puts $fh_unix "  if \[\[ (\$lib_map_path != \"\") \]\]; then"
      puts $fh_unix "    incl_ref=\"OTHERS=\$lib_map_path/$file\""
      puts $fh_unix "    echo \$incl_ref >> \$file"
      puts $fh_unix "  fi"
      puts $fh_unix "\}\n"
    }
  }
}

proc xps_write_lib_dir { simulator fh_unix launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  switch $simulator {
    "ies" -
    "xcelium" -
    "vcs" {
      puts $fh_unix "# Create design library directory paths"
      puts $fh_unix "create_lib_dir()\n\{"
      puts $fh_unix "  if \[\[ -e \$sim_lib_dir \]\]; then"
      puts $fh_unix "    rm -rf \$sim_lib_dir"
      puts $fh_unix "  fi\n"
      puts $fh_unix "  for (( i=0; i<\$\{#design_libs\[*\]\}; i++ )); do"
      puts $fh_unix "    lib=\"\$\{design_libs\[i\]\}\""
      puts $fh_unix "    lib_dir=\"\$sim_lib_dir/\$lib\""
      puts $fh_unix "    if \[\[ ! -e \$lib_dir \]\]; then"
      puts $fh_unix "      mkdir -p \$lib_dir"
      puts $fh_unix "    fi"
      puts $fh_unix "  done"
      puts $fh_unix "\}\n"
    }
    "modelsim" -
    "questa" {
      puts $fh_unix "# Create design library directory"
      puts $fh_unix "create_lib_dir()\n\{"
      puts $fh_unix "  lib_dir=\"${simulator}_lib\""
      puts $fh_unix "  if \[\[ -e \$lib_dir \]\]; then"
      puts $fh_unix "    rm -rf \$lib_dir"
      puts $fh_unix "  fi\n"
      puts $fh_unix "  mkdir $\lib_dir\n"
      puts $fh_unix "\}\n"
    }
  }
}

proc xps_create_vcs_do_file { dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set do_file "$dir/$a_sim_vars(do_filename)"
  set fh_do 0
  if {[catch {open $do_file w} fh_do]} {
    send_msg_id exportsim-Tcl-048 ERROR "failed to open file to write ($do_file)\n"
  } else {
    set runtime "run"
    if { $a_sim_vars(b_runtime_specified) } {
      set runtime "run $a_sim_vars(s_runtime)"
    }
    puts $fh_do "$runtime"
    puts $fh_do "quit"
  }
  close $fh_do
}

proc xps_create_ixrun_do_file { dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set do_file "$dir/$a_sim_vars(do_filename)"
  set fh_do 0
  if {[catch {open $do_file w} fh_do]} {
    send_msg_id exportsim-Tcl-048 ERROR "failed to open file to write ($do_file)\n"
    return false
  } else {
    set runtime "run $a_sim_vars(s_runtime)"
    puts $fh_do "$runtime"
    puts $fh_do "exit"
  }
  close $fh_do
  return true
}

proc xps_write_xsim_setup_file { launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compiled_libraries
  variable a_sim_sv_pkg_libs
  set top $a_sim_vars(s_top)
  set filename "xsim.ini"
  set file [file normalize "$launch_dir/$filename"]
  set fh 0
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-049 "Failed to open file to write ($file)\n"
    return 1
  }
  set design_libs [xps_get_design_libs] 
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    set lib_name [string tolower $lib]
    puts $fh "$lib=xsim.dir/$lib_name"
  }

  # if xilinx_vip packages referenced, add mapping
  if { [llength $a_sim_sv_pkg_libs] > 0 } {
    set lmp [xps_get_lib_map_path "xsim"]
    set library "xilinx_vip"
    puts $fh "$library=$lmp/ip/$library"
  }

  # reference XPM modules from precompiled libs if param is set
  set b_reference_xpm_library 0
  [catch {set b_reference_xpm_library [get_param project.usePreCompiledXPMLibForSim]} err]

  # for precompile flow, if xpm library not found from precompiled libs, compile it locally
  # for non-precompile flow, compile xpm locally and do not reference precompiled xpm library
  if { $b_reference_xpm_library } {
    if { $a_sim_vars(b_use_static_lib) } {
      if { ([lsearch -exact $l_compiled_libraries "xpm"] == -1) } {
        set b_reference_xpm_library 0
      }
    } else {
      set b_reference_xpm_library 0
    }
  }

  if { $b_reference_xpm_library } {
    set filename "xsim.ini"
    set lib_name "xpm"
    set b_mapping_set 0
    set lmp [xps_get_lib_map_path "xsim" 1]
    if { {} != $lmp } {
      set dir $lmp
      set ini_file "$dir/$filename"
      if { [file exists $ini_file] } {
        puts $fh "$lib_name=${dir}/$lib_name"
        set b_mapping_set 1
      }
    }
    if { !$b_mapping_set } {
      set dir $::env(XILINX_VIVADO)
      set dir [file normalize "$dir/data/xsim"]
      set ini_file [file normalize "$dir/$filename"]
      if { [file exists $ini_file] } {
        puts $fh "$lib_name=${dir}/$lib_name"
      }
    }
  }
  close $fh
}

proc xps_write_xsim_prj { dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set top $a_sim_vars(s_top)
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    set filename "vlog.prj"
    set file [file normalize "$dir/$filename"]
    xps_write_prj $dir $file "VERILOG" $srcs_dir
  }

  if { [xcs_contains_vhdl $a_sim_vars(l_design_files)] } {
    set filename "vhdl.prj"
    set file [file normalize "$dir/$filename"]
    xps_write_prj $dir $file "VHDL" $srcs_dir
  }
}

proc xps_write_prj { launch_dir file ft srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  set opts [list]
  if { {VERILOG} == $ft } {
    xps_get_xsim_verilog_options $launch_dir opts
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

  foreach file $a_sim_vars(l_design_files) {
    set fargs         [split $file {|}]
    set type          [lindex $fargs 0]
    set file_type     [lindex $fargs 1] 
    set lib           [lindex $fargs 2] 
    set proj_src_file [lindex $fargs 3]
    set cmd_str       [lindex $fargs 4]
    set ip_file       [lindex $fargs 5]
    set src_file      [lindex $fargs 6]
    set b_static_ip   [lindex $fargs 7]
    set b_xpm         [lindex $fargs 8]

    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }

    if { $a_sim_vars(b_xport_src_files) } {
      set source_file {}
      if { {} != $ip_file } {
        set proj_src_filename [file tail $proj_src_file]
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "ip/$ip_name/$proj_src_filename"
        set source_file "srcs/$proj_src_filename"
      } else {
        set source_file "srcs/[file tail $proj_src_file]"
        if { $a_sim_vars(b_absolute_path) } {
          set proj_src_filename [file tail $proj_src_file]
          set source_file "$srcs_dir/$proj_src_filename"
        }
      }
      set src_file "\"$source_file\""
    } else {
      if { {} != $ip_file } {
        # no op
      } else {
        set source_file [string trim $src_file {\"}]
        set src_file "[xcs_get_relative_file_path $source_file $launch_dir]"
        if { $a_sim_vars(b_absolute_path) || $b_xpm } {
          set src_file $proj_src_file 
        }
        set src_file "\"$src_file\""
      }
    }

    if { $ft == $type } {
      set proj_src_filename [file tail $proj_src_file]
      if { $a_sim_vars(b_xport_src_files) } {
        set target_dir $srcs_dir
        if { {} != $ip_file } {
          set ip_name [file rootname [file tail $ip_file]]
          set ip_dir "$srcs_dir/ip/$ip_name/$lib"
          if { ![file exists $ip_dir] } {
            if {[catch {file mkdir $ip_dir} error_msg] } {
              send_msg_id exportsim-Tcl-050 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
              return 1
            }
          }
          if { $a_sim_vars(b_absolute_path) } {
            set proj_src_filename "$ip_dir/$proj_src_filename"
          } else {
            set proj_src_filename "srcs/ip/$ip_name/$lib/$proj_src_filename"
          }
          set target_dir $ip_dir
        } else {
          if { $a_sim_vars(b_absolute_path) } {
            set proj_src_filename "$srcs_dir/$proj_src_filename"
          } else {
            set proj_src_filename "srcs/$proj_src_filename"
          }
        }
        if { ([get_param project.enableCentralSimRepo]) } {
          if { $a_sim_vars(b_xport_src_files) } {
            if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
              send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
            }
          } else {
            set repo_file $src_file
            set repo_file [string trim $repo_file "\""]
            if {[catch {file copy -force $repo_file $target_dir} error_msg] } {
              send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$repo_file' to '$srcs_dir' : $error_msg\n"
            }
          }
        } else {
          if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
            send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
          }
        }
      }

      if { $b_first } {
        set b_first false
        if { $a_sim_vars(b_xport_src_files) } {
          xps_set_initial_cmd "xsim" $fh $cmd_str $srcs_dir $proj_src_filename $file_type $lib ${opts_str} prev_file_type prev_lib log
        } else {
          xps_set_initial_cmd "xsim" $fh $cmd_str $srcs_dir $src_file $file_type $lib ${opts_str} prev_file_type prev_lib log
        }
      } else {
        if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
          puts $fh "$src_file \\"
        } else {
          puts $fh ""
          if { $a_sim_vars(b_xport_src_files) } {
            xps_set_initial_cmd "xsim" $fh $cmd_str $srcs_dir $proj_src_filename $file_type $lib ${opts_str} prev_file_type prev_lib log
          } else {
            xps_set_initial_cmd "xsim" $fh $cmd_str $srcs_dir $src_file $file_type $lib ${opts_str} prev_file_type prev_lib log
          }
        }
      }
    }
  }

  if { {VERILOG} == $ft } {
    puts $fh ""
    set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
    set gfile "glbl.v"
    if { $a_sim_vars(b_absolute_path) } {
      set gfile "$launch_dir/$gfile"
    }
    puts $fh "verilog $top_lib \"$gfile\""
  }
  puts $fh "\nnosort"

  close $fh
}

proc xps_get_xsim_verilog_options { launch_dir opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_defines
  variable l_include_dirs
  variable l_compiled_libraries
  upvar $opts_arg opts
  # include_dirs
  set unique_incl_dirs [list]
  set incl_dir_str [xps_resolve_incldir $l_include_dirs]
  foreach incl_dir [split $incl_dir_str "|"] {
    if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
      lappend unique_incl_dirs $incl_dir
      if { $a_sim_vars(b_absolute_path) } {
        set incl_dir "[xcs_resolve_file_path $incl_dir $launch_dir]"
      } else {
        set incl_dir "[xcs_get_relative_file_path $incl_dir $launch_dir]"
      }
      lappend opts "-i \"$incl_dir\""
    }
  }

  # include dirs from design source set
  set linked_src_set [get_property "SOURCE_SET" [get_filesets $a_sim_vars(fs_obj)]]
  if { {} != $linked_src_set } {
    set src_fs_obj [get_filesets $linked_src_set]
    set incl_dir_str [xps_resolve_incldir $l_include_dirs]
    foreach incl_dir [split $incl_dir_str "|"] {
      if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
        lappend unique_incl_dirs $incl_dir
        if { $a_sim_vars(b_absolute_path) } {
          set incl_dir "[xcs_resolve_file_path $incl_dir $launch_dir]"
        } else {
          set incl_dir "[xcs_get_relative_file_path $incl_dir $launch_dir]"
        }
        lappend opts "-i \"$incl_dir\""
      }
    }
  }

  # xilinx_vip
  if { ([lsearch -exact $l_compiled_libraries "xilinx_vip"] == -1) } {
    variable a_sim_sv_pkg_libs
    if { [llength $a_sim_sv_pkg_libs] > 0 } {
      lappend opts "--include \"[xcs_get_vip_include_dirs]\""
    }
  }

  # --include
  set prefix_ref_dir "false"
  foreach incl_dir [xps_get_verilog_incl_file_dirs "xsim" $launch_dir $prefix_ref_dir] {
    set incl_dir [string map {\\ /} $incl_dir]
    lappend opts "--include \"$incl_dir\""
  }
  # -d (verilog macros)
  if { [llength $l_defines] > 0 } {
    foreach element $l_defines {
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

# multi-step (modelsim and questa)
proc xps_write_do_file_for_compile { simulator dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compiled_libraries
  set filename "compile.do"
  if { $a_sim_vars(b_single_step) } {
    set filename "run.do"
  }
  set do_file [file normalize "$dir/$filename"]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id exportsim-Tcl-055 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }
  set design_lib_dir "${simulator}_lib"
  set lib_dir "$design_lib_dir/msim"
  if { ({riviera} == $simulator) || ({activehdl} == $simulator) } {
    puts $fh "vlib work"
    set lib_dir $simulator
  } else {
    puts $fh "vlib ${design_lib_dir}/work"
  }
  puts $fh "vlib $lib_dir\n"
  set design_libs [xps_get_design_libs] 
  set b_default_lib false
  set default_lib $a_sim_vars(default_lib)
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    if { $default_lib == $lib } {
      set b_default_lib true
    }
    set lib_path "$lib_dir/$lib"
    if { $a_sim_vars(b_use_static_lib) && ([xcs_is_static_ip_lib $lib $l_compiled_libraries]) } {
      continue
    }
    puts $fh "vlib $lib_path"
  }
  if { !$b_default_lib } {
    puts $fh "vlib $lib_dir/$default_lib"
  }
  puts $fh ""
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    if { $a_sim_vars(b_use_static_lib) && ([xcs_is_static_ip_lib $lib $l_compiled_libraries]) } {
      # no op
    } else {
      puts $fh "vmap $lib $lib_dir/$lib"
    }
  }
  if { !$b_default_lib } {
    puts $fh "vmap $default_lib $lib_dir/$default_lib"
  }
  puts $fh ""
  set log "compile.log"
  set b_first true
  set prev_lib  {}
  set prev_file_type {}
  set b_redirect false
  set b_appended false
  foreach file $a_sim_vars(l_design_files) {
    set fargs         [split $file {|}]
    set type          [lindex $fargs 0]
    set file_type     [lindex $fargs 1]
    set lib           [lindex $fargs 2]
    set proj_src_file [lindex $fargs 3]
    set cmd_str       [lindex $fargs 4]
    set ip_file       [lindex $fargs 5]
    set src_file      [lindex $fargs 6]
    set b_static_ip   [lindex $fargs 7]
    set b_xpm         [lindex $fargs 8]

    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }

    if { $a_sim_vars(b_absolute_path) || $b_xpm } {
      if { $a_sim_vars(b_xport_src_files) } {
        set source_file {}
        if { {} != $ip_file } {
          set proj_src_filename [file tail $proj_src_file]
          set ip_name [file rootname [file tail $ip_file]]
          set proj_src_filename "ip/$ip_name/$lib/$proj_src_filename"
          set source_file "$srcs_dir/$proj_src_filename"
        } else {
          set source_file "$srcs_dir/[file tail $proj_src_file]"
        }
        set src_file "\"$source_file\""
      }
    } else {
      if { $a_sim_vars(b_xport_src_files) } {
        set source_file {}
        if { {} != $ip_file } {
          set proj_src_filename [file tail $proj_src_file]
          set ip_name [file rootname [file tail $ip_file]]
          set proj_src_filename "ip/$ip_name/$lib/$proj_src_filename"
          set source_file "srcs/$proj_src_filename"
        } else {
          set source_file "srcs/[file tail $src_file]"
          set source_file [string trim $source_file {\"}]
        }
        set src_file "\"$source_file\""
      } else {
        if { {} != $ip_file } {
          # no op
        } else {
          set source_file [string trim $src_file {\"}]
          set src_file "[xcs_get_relative_file_path $source_file $dir]"
          set src_file "\"$src_file\""
        }
      }
    }

    set proj_src_filename [file tail $proj_src_file]
    if { $a_sim_vars(b_xport_src_files) } {
      set target_dir $srcs_dir
      if { {} != $ip_file } {
        set ip_name [file rootname [file tail $ip_file]]
        set proj_src_filename "ip/$ip_name/$lib/$proj_src_filename"
        set ip_dir "$srcs_dir/ip/$ip_name/$lib"
        if { ![file exists $ip_dir] } {
          if {[catch {file mkdir $ip_dir} error_msg] } {
            send_msg_id exportsim-Tcl-056 ERROR "failed to create the directory ($ip_dir): $error_msg\n"
            return 1
          }
        }
        #if { $a_sim_vars(b_absolute_path) } {
        #  set proj_src_filename "$ip_dir/$proj_src_filename"
        #}
        set target_dir $ip_dir
      }
      if { [get_param project.enableCentralSimRepo] } {
        if { $a_sim_vars(b_xport_src_files) } {
          if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
             send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
          }
        } else {
          set repo_file $src_file
          set repo_file [string trim $repo_file "\""]
          if {[catch {file copy -force $repo_file $target_dir} error_msg] } {
            send_msg_id exportsim-Tcl-051 WARNING "failed to copy file '$repo_file' to '$srcs_dir' : $error_msg\n"
          }
        }
      } else {
        if {[catch {file copy -force $proj_src_file $target_dir} error_msg] } {
          send_msg_id exportsim-Tcl-057 WARNING "failed to copy file '$proj_src_file' to '$srcs_dir' : $error_msg\n"
        }
      }
    }

    if { $b_first } {
      set b_first false
      xps_set_initial_cmd $simulator $fh $cmd_str $srcs_dir $src_file $file_type $lib {} prev_file_type prev_lib log
    } else {
      if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
        puts $fh "$src_file \\"
        set b_redirect true
      } else {
        puts $fh ""
        xps_set_initial_cmd $simulator $fh $cmd_str $srcs_dir $src_file $file_type $lib {} prev_file_type prev_lib log
        set b_appended true
      }
    }
  }

  if { (!$b_redirect) || (!$b_appended) } {
    puts $fh ""
  }

  # compile glbl file
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
    set file "glbl.v"
    if { $a_sim_vars(b_absolute_path) } {
      set file "$dir/$file"
    }
    puts $fh "\nvlog -work $top_lib \\\n\"$file\""
  }
  if { $a_sim_vars(b_single_step) } {
    set cmd_str [xps_get_simulation_cmdline_modelsim $simulator]
    puts $fh "\n$cmd_str"
  }

  # do not remove this
  puts $fh ""

  close $fh
}

proc xps_write_do_file_for_elaborate { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_generics
  variable l_compiled_libraries
  variable a_sim_sv_pkg_libs
  set filename "elaborate.do"
  set do_file [file normalize "$dir/$filename"]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id exportsim-Tcl-058 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  set clibs_dir [xps_get_lib_map_path $simulator]

  switch $simulator {
    "modelsim" {
    }
    "questa" {
      if { $a_sim_vars(b_contain_systemc_sources) } {
        # systemc
        set args [list]
        lappend args "sccom"
        if { !$a_sim_vars(b_32bit) } {
          set args [linsert $args end "-64"]
        }
        lappend args "-link"
        foreach lib [xcs_get_sc_libs] {
          lappend args "-lib $lib"
        }
        lappend args "-lib $a_sim_vars(default_lib)"
        foreach shared_ip_lib [xcs_get_shared_ip_libraries $clibs_dir] {
          set lib_dir "[xps_get_lib_map_path $simulator]/$shared_ip_lib"
          lappend args "-L$lib_dir"
          lappend args "-l${shared_ip_lib}"
          lappend args "-lib ${shared_ip_lib}"
        }
        lappend args "-work $a_sim_vars(default_lib)"
        set cmd_str [join $args " "]
        puts $fh "$cmd_str"
      }
 
      # RTL
      set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
      set arg_list [list "+acc" "-l" "elaborate.log"]
      if { !$a_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-64"]
      }
      if { [llength $l_generics] > 0 } {
        xps_append_generics $l_generics arg_list
      }
      set t_opts [join $arg_list " "]
      set arg_list [list]
      # add user design libraries
      set design_libs [xps_get_design_libs]

      # add sv pkg libraries
      #variable a_sim_sv_pkg_libs
      #foreach lib $a_sim_sv_pkg_libs {
      #  if { [lsearch $design_libs $lib] == -1 } {
      #    lappend arg_list "-L"
      #    lappend arg_list "$lib"
      #  }
      #}

      foreach lib $design_libs {
        if {[string length $lib] == 0} { continue; }
        lappend arg_list "-L"
        lappend arg_list "$lib"
      }

      if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
        # append sv pkg libs
        foreach sv_pkg_lib $a_sim_sv_pkg_libs {
          lappend arg_list "-L $sv_pkg_lib"
        }
      }

      if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
        set arg_list [linsert $arg_list end "-L" "unisims_ver"]
        set arg_list [linsert $arg_list end "-L" "unimacro_ver"]
      }
      # add secureip
      set arg_list [linsert $arg_list end "-L" "secureip"]
      # reference XPM modules from precompiled libs if param is set
      set b_reference_xpm_library 0
      [catch {set b_reference_xpm_library [get_param project.usePreCompiledXPMLibForSim]} err]

      # for precompile flow, if xpm library not found from precompiled libs, compile it locally
      # for non-precompile flow, compile xpm locally and do not reference precompiled xpm library
      if { $b_reference_xpm_library } {
        if { $a_sim_vars(b_use_static_lib) } {
          if { ([lsearch -exact $l_compiled_libraries "xpm"] == -1) } {
            set b_reference_xpm_library 0
          }
        } else {
          set b_reference_xpm_library 0
        }
      }

      if { $b_reference_xpm_library } {
        set arg_list [linsert $arg_list end "-L" "xpm"]
      }
      set default_lib $a_sim_vars(default_lib)
      lappend arg_list "-work"
      lappend arg_list $top_lib
      set d_libs [join $arg_list " "]
      set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
      set arg_list [list]
      lappend arg_list "vopt"
      xps_append_config_opts arg_list $simulator "vopt"
      lappend arg_list $t_opts
      lappend arg_list "$d_libs"
      set top $a_sim_vars(s_top)
      lappend arg_list "${top_lib}.$top"
      if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
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
  set do_file [file normalize "$dir/$filename"]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id exportsim-Tcl-059 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }
  set wave_do_filename "wave.do"
  set wave_do_file [file normalize "$dir/$wave_do_filename"]
  xps_create_wave_do_file $wave_do_file
  set cmd_str {}
  switch $simulator {
    "modelsim" -
    "riviera" -
    "activehdl" { 
      set cmd_str [xps_get_simulation_cmdline_modelsim $simulator]
    }
    "questa"   { set cmd_str [xps_get_simulation_cmdline_questa] }
  }

  switch $simulator {
    "modelsim" -
    "questa" {
      puts $fh "onbreak {quit -f}"
      puts $fh "onerror {quit -f}\n"
    }
    "riviera" -
    "activehdl" {
      puts $fh "onbreak {quit -force}"
      puts $fh "onerror {quit -force}\n"
    }
  }

  puts $fh "$cmd_str"
  puts $fh "\ndo \{$wave_do_filename\}"
  puts $fh "\nview wave"
  puts $fh "view structure"
  switch $simulator {
    "modelsim" -
    "questa" {
      puts $fh "view signals"
    }
  }
  puts $fh ""
  set top $a_sim_vars(s_top)
  set udo_filename $top;append udo_filename ".udo"
  set udo_file [file normalize "$dir/$udo_filename"]
  xps_create_udo_file $udo_file
  puts $fh "do \{$top.udo\}"
  set runtime "run -all"
  if { $a_sim_vars(b_runtime_specified) } {
    set runtime "run $a_sim_vars(s_runtime)"
  }
  puts $fh "\n$runtime"
  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\" && IS_USER_DISABLED == 0"
  xcs_find_files tcl_src_files $a_sim_vars(sp_tcl_obj) $filter $dir $a_sim_vars(b_absolute_path) $a_sim_vars(fs_obj)
  if {[llength $tcl_src_files] > 0} {
    puts $fh ""
    foreach file $tcl_src_files {
      puts $fh "source \{$file\}"
    }
    puts $fh ""
  }
  if { ({riviera} == $simulator) || ({activehdl} == $simulator) } {
    puts $fh "\nendsim"
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
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    puts $fh "add wave /glbl/GSR"
  }
  close $fh
}

proc xps_get_simulation_cmdline_modelsim { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_generics
  variable l_compiled_libraries
  set args [list]
  switch -regexp -- $simulator {
    "modelsim" {
      xps_append_config_opts args $simulator "vsim"
      lappend args "-voptargs=\"+acc\"" "-t 1ps"
    }
    "riviera" -
    "activehdl" {
      xps_append_config_opts args $simulator "asim"
      lappend args "-t 1ps +access +r +m+$a_sim_vars(s_top)"
    }
  }
  if { [llength $l_generics] > 0 } {
    xps_append_generics $l_generics args
  }
  set t_opts [join $args " "]
  set args [list]
  # add user design libraries
  set design_libs [xps_get_design_libs]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend args "-L"
    lappend args "$lib"
    #lappend args "[string tolower $lib]"
  }
  # add xilinx vip library
  if { [get_param "project.usePreCompiledXilinxVIPLibForSim"] } {
    if { [xcs_design_contain_sv_ip] } {
      lappend args "-L xilinx_vip"
    }
  }
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    set args [linsert $args end "-L" "unisims_ver"]
    set args [linsert $args end "-L" "unimacro_ver"]
  }
  set args [linsert $args end "-L" "secureip"]
  # reference XPM modules from precompiled libs if param is set
  set b_reference_xpm_library 0
  [catch {set b_reference_xpm_library [get_param project.usePreCompiledXPMLibForSim]} err]

  # for precompile flow, if xpm library not found from precompiled libs, compile it locally
  # for non-precompile flow, compile xpm locally and do not reference precompiled xpm library
  if { $b_reference_xpm_library } {
    if { $a_sim_vars(b_use_static_lib) } {
      if { ([lsearch -exact $l_compiled_libraries "xpm"] == -1) } {
        set b_reference_xpm_library 0
      }
    } else {
      set b_reference_xpm_library 0
    }
  }

  if { $b_reference_xpm_library } {
    set args [linsert $args end "-L" "xpm"]
  }
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
  if { ({riviera} == $simulator) || ({activehdl} == $simulator) } {
    lappend args "-O5"
  } else {
    lappend args "-lib"
    lappend args $top_lib
  }
  set d_libs [join $args " "]
  set args [list "vsim" $t_opts]
  if { ({riviera} == $simulator) || ({activehdl} == $simulator) } {
    set args [list "asim" $t_opts]
  }
  lappend args "$d_libs"
  lappend args "${top_lib}.$a_sim_vars(s_top)"
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
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

  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]

  lappend args "-lib"
  lappend args $top_lib
  lappend args "$a_sim_vars(s_top)_opt"

  set cmd_str [join $args " "]

  return $cmd_str
}

proc xps_write_xelab_cmdline { fh_unix launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_defines
  variable l_generics
  variable l_include_dirs
  variable l_compiled_libraries
  set args [list]
  xps_append_config_opts args "xsim" "xelab"
  if { [llength $l_defines] > 0 } {
    foreach element $l_defines {
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
  if { [llength $l_generics] > 0 } {
    foreach element $l_generics {
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
  # add user design libraries
  set design_libs [xps_get_design_libs]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend args "-L $lib"
  }
  # add xilinx vip library
  if { [get_param "project.usePreCompiledXilinxVIPLibForSim"] } {
    if { [xcs_design_contain_sv_ip] } {
      lappend args "-L xilinx_vip"
    }
  }
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    lappend args "-L unisims_ver"
    lappend args "-L unimacro_ver"
  }
  lappend args "-L secureip"
  # reference XPM modules from precompiled libs if param is set
  set b_reference_xpm_library 0
  [catch {set b_reference_xpm_library [get_param project.usePreCompiledXPMLibForSim]} err]

  # for precompile flow, if xpm library not found from precompiled libs, compile it locally
  # for non-precompile flow, compile xpm locally and do not reference precompiled xpm library
  if { $b_reference_xpm_library } {
    if { $a_sim_vars(b_use_static_lib) } {
      if { ([lsearch -exact $l_compiled_libraries "xpm"] == -1) } {
        set b_reference_xpm_library 0
      }
    } else {
      set b_reference_xpm_library 0
    }
  }

  if { $b_reference_xpm_library } {
    lappend args "-L xpm"
  }
  lappend args "--snapshot [xps_get_snapshot]"
  foreach top [xps_get_tops] {
    lappend args "$top"
  }
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    if { ([lsearch [xps_get_tops] {glbl}] == -1) } {
      set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
      lappend args "${top_lib}.glbl"
    }
  }
  lappend args "-log elaborate.log"
 
  set args_str [join $args " "]

  if {$::tcl_platform(platform) == "windows"} {
    set fh_win 0 
    set file "$launch_dir/elab.opt"
    if { [catch {open $file w} fh_win] } {
      send_msg_id exportsim-Tcl-063 ERROR "Failed to open file to write ($file)\n"
    } else {
      puts $fh_win $args_str 
      close $fh_win
    }
  }
  puts $fh_unix "  xelab $args_str"
}

proc xps_write_xsim_cmdline { fh_unix dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set args [list]

  lappend args "xsim"
  xps_append_config_opts args "xsim" "xsim"

  lappend args [xps_get_snapshot]
  lappend args "-key"
  lappend args "\{[xps_get_obj_key]\}"

  set cmd_file "cmd.tcl"
  xps_write_xsim_tcl_cmd_file $dir $cmd_file

  lappend args "-tclbatch"
  lappend args "$cmd_file"

  set p_inst_files [xcs_get_protoinst_files $a_sim_vars(s_ip_user_files_dir)]
  if { [llength $p_inst_files] > 0 } {
    set target_pinst_dir "$dir/protoinst_files"
    if { ![file exists $target_pinst_dir] } {
      [catch {file mkdir $target_pinst_dir} error_msg]
    }
    foreach p_file $p_inst_files {
      if { ![file exists $p_file] } { continue; }
      set filename [file tail $p_file]
      set target_p_file "$target_pinst_dir/$filename"
      if { ![file exists $target_p_file] } {
        if { [catch {file copy -force $p_file $target_pinst_dir} error_msg] } {
          [catch {send_msg_id exportsim-Tcl-072 ERROR "Failed to copy file '$p_file' to '$target_pinst_dir': $error_msg\n"} err]
        } else {
          #send_msg_id exportsim-Tcl-073 INFO "File '$p_file' copied to '$target_pinst_dir'\n"
        }
      }
      lappend args "-protoinst"
      lappend args "\"protoinst_files/$filename\""
    }
  }

  set log_file "simulate";append log_file ".log"

  lappend args "-log"
  lappend args "$log_file"

  puts $fh_unix "  [join $args " "]"
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
  set file [file normalize "$dir/$filename"]
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
  set runtime "run -all"
  if { $a_sim_vars(b_runtime_specified) } {
    set runtime "run $a_sim_vars(s_runtime)"
  }
  puts $fh "\n$runtime"

  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\" && IS_USER_DISABLED == 0"
  xcs_find_files tcl_src_files $a_sim_vars(sp_tcl_obj) $filter $dir $a_sim_vars(b_absolute_path) $a_sim_vars(fs_obj)
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

proc xps_get_tops {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set inst_names [list]
  set top $a_sim_vars(s_top)
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
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

proc xps_write_reset { simulator fh_unix } {
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
    "modelsim" {
      set file_list [list "compile.log" "elaborate.log" "simulate.log" "vsim.wlf"]
      set file_dir_list [list "modelsim_lib"]
    }
    "questa" {
      set file_list [list "compile.log" "elaborate.log" "simulate.log" "vsim.wlf"]
      set file_dir_list [list "questa_lib"]
    }
    "riviera" {
      set file_list [list "compile.log" "elaboration.log" "simulate.log" "dataset.asdb"]
      set file_dir_list [list "work" "riviera"]
    }
    "activehdl" {
      set file_list [list "compile.log" "elaboration.log" "simulate.log" "dataset.asdb"]
      set file_dir_list [list "work" "activehdl"]
    }
    "ies" { 
      set file_list [list "ncsim.key" "irun.key" "irun.log" "waves.shm" "irun.history" ".simvision"]
      set file_dir_list [list "INCA_libs"]
    }
    "xcelium" { 
      set file_list [list "xmsim.key" "xrun.key" "xrun.log" "waves.shm" "xrun.history" ".simvision"]
      set file_dir_list [list "xcelium.d" "xcelium"]
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

  puts $fh_unix "# Delete generated data from the previous run"
  puts $fh_unix "reset_run()"
  puts $fh_unix "\{"
  puts $fh_unix "  files_to_remove=($files $files_dir)"
  puts $fh_unix "  for (( i=0; i<\$\{#files_to_remove\[*\]\}; i++ )); do"
  puts $fh_unix "    file=\"\$\{files_to_remove\[i\]\}\""
  puts $fh_unix "    if \[\[ -e \$file \]\]; then"
  puts $fh_unix "      rm -rf \$file"
  puts $fh_unix "    fi"
  puts $fh_unix "  done"
  switch -regexp -- $simulator {
    "modelsim" -
    "questa" -
    "ies" -
    "xcelium" -
    "vcs" {
      puts $fh_unix "\n  create_lib_dir"
    }
  }
  puts $fh_unix "\}"
  puts $fh_unix ""
}

proc xps_write_setup { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  set extn [string tolower [file extension $a_sim_vars(s_script_filename)]]
  puts $fh_unix "# STEP: setup"
  puts $fh_unix "setup()\n\{"
  puts $fh_unix "  case \$1 in"
  puts $fh_unix "    \"-lib_map_path\" )"
  puts $fh_unix "      if \[\[ (\$2 == \"\") \]\]; then"
  puts $fh_unix "        echo -e \"ERROR: Simulation library directory path not specified (type \\\"./$a_sim_vars(s_script_filename).sh -help\\\" for more information)\\n\""
  puts $fh_unix "        exit 1"
  switch -regexp -- $simulator {
    "ies" -
    "xcelium" {
      puts $fh_unix "      else"
      puts $fh_unix "        ref_lib_dir=\$2"
    }
  }
  puts $fh_unix "      fi"
  #puts $fh_unix "      # precompiled simulation library directory path"
  switch -regexp -- $simulator {
    "xsim" {
      if { $a_sim_vars(b_use_static_lib) } {
        puts $fh_unix "     copy_setup_file \$2"
      }
    }
    "riviera" -
    "activehdl" {
      puts $fh_unix "     map_setup_file \$2"
    }
    "modelsim" -
    "questa" {
      puts $fh_unix "     copy_setup_file \$2"
    }
    "vcs" {
      puts $fh_unix "      create_lib_mappings \$2"
    }
  }
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    #puts $fh_unix "     copy_glbl_file"
  }
  puts $fh_unix "    ;;"
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
    "xsim" {
      if { $a_sim_vars(b_use_static_lib) } {
        puts $fh_unix "     copy_setup_file \$2"
      }
    }
    "riviera" -
    "activehdl" {
      puts $fh_unix "     map_setup_file \$2"
    }
    "modelsim" -
    "questa" {
      puts $fh_unix "     copy_setup_file \$2"
    }
    "vcs" {
      puts $fh_unix "      create_lib_mappings \$2"
    }
  }
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    #puts $fh_unix "     copy_glbl_file"
  }
  puts $fh_unix "  esac\n"
  switch -regexp -- $simulator {
    "modelsim" -
    "questa" -
    "ies" -
    "xcelium" -
    "vcs" {
      puts $fh_unix "  create_lib_dir\n"
    }
  }
  puts $fh_unix "  # Add any setup/initialization commands here:-\n"
  puts $fh_unix "  # <user specific commands>\n"
  puts $fh_unix "\}\n"
}

proc xps_write_main { simulator fh_unix launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable a_sim_sv_pkg_libs
  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set copyright   [lindex $version_txt 3]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]

  set srcs_dir [xps_create_srcs_dir $launch_dir]

  if { ({ies} == $simulator) || ({xcelium} == $simulator) || ({vcs} == $simulator) } {
    xps_write_ref_dir $fh_unix $launch_dir $srcs_dir
  }

  xps_write_lib_map_path_dir $simulator $fh_unix

  if { $a_sim_vars(b_single_step) } {
    # no op
  } else {
    switch -regexp -- $simulator {
      "xsim" {
        #puts $fh_unix "xv_path=\"$::env(XILINX_VIVADO)\"\n"
      }
    }
    switch -regexp -- $simulator {
      "modelsim" -
      "riviera" -
      "activehdl" -
      "questa" {
      }
      default {
        puts $fh_unix "# Command line options"
      }
    }

    switch -regexp -- $simulator {
      "xsim" {
        set arg_list [list]
        xps_append_config_opts arg_list "xsim" "xvlog"
        if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
          # append sv pkg libs
          foreach sv_pkg_lib $a_sim_sv_pkg_libs {
            lappend arg_list "-L $sv_pkg_lib"
          }
          puts $fh_unix "xvlog_opts=\"[join $arg_list " "]\""
        }
        set arg_list [list]
        xps_append_config_opts arg_list "xsim" "xvhdl"
        if { [xcs_contains_vhdl $a_sim_vars(l_design_files)] } {
          puts $fh_unix "xvhdl_opts=\"[join $arg_list " "]\""
        }
        puts $fh_unix ""
      }
      "ies" -
      "xcelium" {
        set tool "irun"
        if { {xcelium} == $simulator } {
          set tool "xrun"
        }
        set arg_list [list]
        xps_append_config_opts arg_list $simulator $tool
        if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-64bit"] }

        puts $fh_unix "${tool}_opts=\"[join $arg_list " "]\""
        puts $fh_unix ""
      }
      "vcs"   {
        set arg_list [list]
        xps_append_config_opts arg_list "vcs" "vlogan"
        if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-full64"] }
        puts $fh_unix "vlogan_opts=\"[join $arg_list " "]\""
        set arg_list [list]
        xps_append_config_opts arg_list "vcs" "vhdlan"
        if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-full64"] }
        puts $fh_unix "vhdlan_opts=\"[join $arg_list " "]\""
        set arg_list [list]
        xps_append_config_opts arg_list "vcs" "vcs"
        set arg_list [linsert $arg_list end "-debug_pp" "-t" "ps" "-licqueue" "-l" "elaborate.log"]
        if { !$a_sim_vars(b_32bit) } { set arg_list [linsert $arg_list 0 "-full64"] }
        puts $fh_unix "vcs_elab_opts=\"[join $arg_list " "]\""
        set arg_list [list]
        xps_append_config_opts arg_list $simulator "simv"
        lappend arg_list "-ucli" "-licqueue" "-l" "simulate.log"
        puts $fh_unix "vcs_sim_opts=\"[join $arg_list " "]\""
        puts $fh_unix ""
      }
    }
  }

  variable l_compiled_libraries
  switch $simulator {
    "ies" -
    "xcelium" -
    "vcs" {
      set libs [list]
      foreach lib [xps_get_design_libs] {
        if {[string length $lib] == 0} { continue; }
        if { ({work} == $lib) && ({vcs} == $simulator) } { continue; }
        if { $a_sim_vars(b_use_static_lib) && ([xcs_is_static_ip_lib $lib $l_compiled_libraries]) } {
          # no op
        } else {
          lappend libs [string tolower $lib]
        }
      }
      puts $fh_unix "# Design libraries"
      puts $fh_unix "design_libs=([join $libs " "])"
    }
  }

  switch $simulator {
    "ies" -
    "xcelium" -
    "vcs" {
      puts $fh_unix "\n# Simulation root library directory"
      puts $fh_unix "sim_lib_dir=\"${simulator}_lib\""
    }
  }

  puts $fh_unix ""

  puts $fh_unix "# Script info"
  puts $fh_unix "echo -e \"$a_sim_vars(s_script_filename).sh - Script generated by export_simulation ($version-id)\\n\"\n"
  xps_write_run_steps $simulator $fh_unix
  xps_write_simulator_procs $simulator $fh_unix $launch_dir $srcs_dir
  xps_write_setup $simulator $fh_unix
  #puts $fh_unix "# Check command line args"
  #puts $fh_unix "if \[\[ \$# > 1 \]\]; then"
  #puts $fh_unix "  echo -e \"ERROR: invalid number of arguments specified\\n\""
  #puts $fh_unix "  usage"
  #puts $fh_unix "fi\n"
}

proc xps_write_lib_map_path_dir { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  switch -regexp -- $simulator {
    "ies" -
    "xcelium" { 
      set cds_lmp "."
      set cds_file {}
      set lmp [xps_get_lib_map_path $simulator]
      if { {} != $lmp } {
        set cds_file "$lmp/cds.lib"
        if { [file exist $cds_file] } {
          set cds_lmp $lmp
        } else {
          #send_msg_id exportsim-Tcl-040 ERROR "Failed to find the 'cds.lib' file from the directory specified with the -lib_map_path switch (${cds_file})\n"
        }
      }
      puts $fh_unix "# Set the compiled library directory"
      puts $fh_unix "ref_lib_dir=\"$cds_lmp\"\n"
    }
  }
}

proc xps_write_check_args { fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  
  puts $fh_unix "# Check command line arguments"
  puts $fh_unix "check_args()\n\{"
  puts $fh_unix "  if \[\[ (\$1 == 1 ) && (\$2 != \"-lib_map_path\" && \$2 != \"-noclean_files\" && \$2 != \"-reset_run\" && \$2 != \"-help\" && \$2 != \"-h\") \]\]; then"
  puts $fh_unix "    echo -e \"ERROR: Unknown option specified '\$2' (type \\\"./$a_sim_vars(s_script_filename).sh -help\\\" for more information)\\n\""
  puts $fh_unix "    exit 1"
  puts $fh_unix "  fi"
  puts $fh_unix ""
  puts $fh_unix "  if \[\[ (\$2 == \"-help\" || \$2 == \"-h\") \]\]; then"
  puts $fh_unix "    usage"
  puts $fh_unix "  fi"
  puts $fh_unix "\}\n"
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

proc xps_get_incl_files_from_ip { launch_dir tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set incl_files [list]
  set ip_name [file tail $tcl_obj]
  set filter "FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\""
  set vh_files [get_files -quiet -all -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    lappend incl_files $file
  }
  return $incl_files
}

proc xps_get_verilog_incl_file_dirs { simulator launch_dir { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_valid_ip_extns
  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_all_bd_files
  set d_dir_names [dict create]
  set vh_files [list]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xcs_is_ip $tcl_obj $l_valid_ip_extns] } {
    set vh_files [xps_get_incl_files_from_ip $launch_dir $tcl_obj]
  } else {
    set filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\")"
    set vh_files [get_files -all -quiet -filter $filter]
  }

  if { {} != $a_sim_vars(global_files_str) } {
    set global_files [split $a_sim_vars(global_files_str) {|}]
    foreach g_file $global_files {
      set g_file [string trim $g_file {\"}]
      lappend vh_files [get_files -quiet -all $g_file]
    }
  }
  foreach vh_file $vh_files {
    set vh_file_obj {}
    if { [info exists a_sim_cache_all_design_files_obj($vh_file)] } {
      set vh_file_obj $a_sim_cache_all_design_files_obj($vh_file)
    } else {
      set vh_file_obj [lindex [get_files -all -quiet [list "$vh_file"]] 0]
    }
    # set vh_file [extract_files -files [list "[file tail $vh_file]"] -base_dir $launch_dir/ip_files]
    set vh_file [xps_xtract_file $vh_file]
    if { [get_param project.enableCentralSimRepo] } {
      set b_is_bd 0
      if { [info exists a_sim_cache_all_bd_files($vh_file)] } {
        set b_is_bd 1
      } else {
        set b_is_bd [xcs_is_bd_file $vh_file]
        if { $b_is_bd } {
          set a_sim_cache_all_bd_files($vh_file) $b_is_bd
        }
      }
      set used_in_values [get_property "USED_IN" $vh_file_obj]
      if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
        set vh_file [xcs_fetch_header_from_dynamic $vh_file $b_is_bd $a_sim_vars(s_ip_user_files_dir)]
      } else {
        if { $b_is_bd } {
          set vh_file [xcs_fetch_ipi_static_header_file $vh_file_obj $vh_file $a_sim_vars(s_ipstatic_source_dir) $a_sim_vars(s_ip_repo_dir)]
        } else {
          set vh_file_path [xcs_fetch_ip_static_header_file $vh_file $vh_file_obj $a_sim_vars(s_ipstatic_source_dir) $a_sim_vars(s_ip_repo_dir)]
          if { $a_sim_vars(b_use_static_lib) } {
            if { [file exists $vh_file_path] } {
              set vh_file $vh_file_path
            }
          } else {
            set vh_file $vh_file_path
          }
        }
      }
    }
    set dir [file normalize [file dirname $vh_file]]

    if { $a_sim_vars(b_xport_src_files) } {
      set export_dir "$launch_dir/srcs/incl"
      if {[catch {file copy -force $vh_file $export_dir} error_msg] } {
        send_msg_id exportsim-Tcl-065 WARNING "Failed to copy file '$vh_file' to '$export_dir' : $error_msg\n"
      }
    }

    if { $a_sim_vars(b_absolute_path) } {
      set dir "[xcs_resolve_file_path $dir $launch_dir]"
    } else {
      if { $ref_dir } {
        if { $a_sim_vars(b_xport_src_files) } {
          set dir "\$ref_dir/incl"
          if { ({modelsim} == $simulator) || ({questa} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator) } {
            set dir "srcs/incl"
          }
        } else {
          if { ({modelsim} == $simulator) || ({questa} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator) } {
            set dir "[xcs_get_relative_file_path $dir $launch_dir]"
          } else {
            set dir "\$ref_dir/[xcs_get_relative_file_path $dir $launch_dir]"
          }
        }
      } else {
        if { $a_sim_vars(b_xport_src_files) } {
          set dir "srcs/incl"
        } else {
          set dir "[xcs_get_relative_file_path $dir $launch_dir]"
        }
      }
    }
    dict append d_dir_names $dir
  }

  return [dict keys $d_dir_names]
}

proc xps_get_verilog_incl_dirs { simulator launch_dir ref_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_valid_ip_extns
  variable l_include_dirs

  set d_dir_names [dict create]
  set tcl_obj $a_sim_vars(sp_tcl_obj)
  set incl_dirs [list]
  set incl_dir_str {}

  if { [xcs_is_ip $tcl_obj $l_valid_ip_extns] } {
    set incl_dir_str [xps_get_incl_dirs_from_ip $simulator $launch_dir $tcl_obj]
    set incl_dirs [split $incl_dir_str "|"]
  } else {
    set incl_dir_str [xps_resolve_incldir $l_include_dirs]
    set incl_prop_dirs [split $incl_dir_str "|"]

    # include dirs from design source set
    set linked_src_set [get_property "SOURCE_SET" [get_filesets $tcl_obj]]
    if { {} != $linked_src_set } {
      set src_fs_obj [get_filesets $linked_src_set]
      set dirs [xps_resolve_incldir $l_include_dirs]
      foreach dir [split $dirs "|"] {
        if { [lsearch -exact $incl_prop_dirs $dir] == -1 } {
          lappend incl_prop_dirs $dir
        }
      }
    }

    foreach dir $incl_prop_dirs {
      if { $a_sim_vars(b_absolute_path) } {
        set dir "[xcs_resolve_file_path $dir $launch_dir]"
      } else {
        if { $ref_dir } {
          if { $a_sim_vars(b_xport_src_files) } {
            set dir "\$ref_dir/incl"
            if { ({modelsim} == $simulator) || ({questa} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator) } {
              set dir "srcs/incl"
            }
          } else {
            if { ({modelsim} == $simulator) || ({questa} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator) } {
              set dir "[xcs_get_relative_file_path $dir $launch_dir]"
            } else {
              set dir "\$ref_dir/[xcs_get_relative_file_path $dir $launch_dir]"
            }
          }
        } else {
          if { $a_sim_vars(b_xport_src_files) } {
            set dir "srcs/incl"
          } else {
            set dir "[xcs_get_relative_file_path $dir $launch_dir]"
          }
        }
      }
      lappend incl_dirs $dir
    }
  }

  foreach vh_dir $incl_dirs {
    set vh_dir [string trim $vh_dir {\{\}}]
    dict append d_dir_names $vh_dir
  }
  return [dict keys $d_dir_names]
}

proc xps_resolve_incldir { incl_dirs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set resolved_path {}
  set incl_dirs [string map {\\ /} $incl_dirs]
  set path_elem {}
  foreach elem $incl_dirs {
    set elem [string trim $elem "\""]
    # path element starts slash (/)? or drive (c:/)?
    if { [string match "/*" $elem] || [regexp {^[a-zA-Z]:} $elem] } {
      if { {} != $path_elem } {
        # previous path is complete now, add hash and append to resolved path string
        set path_elem "$path_elem|"
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

proc xps_get_incl_dirs_from_ip { simulator launch_dir tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable a_sim_cache_all_design_files_obj
  set ip_name [file tail $tcl_obj]
  set incl_dirs [list]
  set filter "FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\""
  set vh_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    # set file [extract_files -files [list "[file tail $file]"] -base_dir $launch_dir/ip_files]
    set file [xps_xtract_file $file]
    set dir [file dirname $file]
    if { [get_param project.enableCentralSimRepo] } {
      set b_static_ip_file 0
      set file_obj {}
      if { [info exists a_sim_cache_all_design_files_obj($file)] } {
        set file_obj $a_sim_cache_all_design_files_obj($file)
      } else {
        set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
      }
      set associated_library {}
      if { {} != $file_obj } {
        if { [lsearch -exact [list_property $file_obj] {LIBRARY}] != -1 } {
          set associated_library [get_property "LIBRARY" $file_obj]
        }
      }
      set file [xps_get_ip_file_from_repo $tcl_obj $file $associated_library $launch_dir b_static_ip_file]
      set dir [file dirname $file]
      # remove leading "./"
      if { [regexp {^\.\/} $dir] } {
        set dir [join [lrange [split $dir "/"] 1 end] "/"]
      }
      if { $a_sim_vars(b_xport_src_files) } {
        set dir "\$ref_dir/incl"
        if { ({modelsim} == $simulator) || ({questa} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator) } {
          set dir "srcs/incl"
        }
      } else {
        if { ({modelsim} == $simulator) || ({questa} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator) } {
          # not required, the dir is already returned in right format for relative and absolute
          #set dir "[xcs_get_relative_file_path $dir $launch_dir]"
        } else {
          set dir "\$ref_dir/$dir"
        }
      }
    } else {
      if { $a_sim_vars(b_absolute_path) } {
        set dir "[xcs_resolve_file_path $dir $launch_dir]"
      } else {
        if { $a_sim_vars(b_xport_src_files) } {
          set dir "\$ref_dir/incl"
        } else {
          set dir "\$ref_dir/[xcs_get_relative_file_path $dir $launch_dir]"
        }
      }
    }
    lappend incl_dirs $dir
  }
  set incl_dirs [join $incl_dirs "|"]
  return $incl_dirs
}

proc xps_get_global_include_files { launch_dir incl_file_paths_arg incl_files_arg { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $incl_file_paths_arg incl_file_paths
  upvar $incl_files_arg      incl_files

  variable a_sim_vars
  variable a_sim_cache_all_design_files_obj
  set filesets       [list]
  set dir            $launch_dir
  set linked_src_set {}
  if { ([xcs_is_fileset $a_sim_vars(sp_tcl_obj)]) && ({SimulationSrcs} == [get_property fileset_type $a_sim_vars(fs_obj)]) } {
    set linked_src_set [get_property "SOURCE_SET" $a_sim_vars(fs_obj)]
  }
  set incl_files_set [list]

  if { {} != $linked_src_set } {
    lappend filesets $linked_src_set
  }
  lappend filesets $a_sim_vars(fs_obj)
  # find verilog files marked as global include and not user disabled
  set filter "(FILE_TYPE == \"Verilog\"                      || \
               FILE_TYPE == \"Verilog Header\"               || \
               FILE_TYPE == \"Verilog/SystemVerilog Header\" || \
               FILE_TYPE == \"Verilog Template\")            && \
              (IS_GLOBAL_INCLUDE == 1 && IS_USER_DISABLED == 0)"
  foreach fs_obj $filesets {
    foreach file [get_files -quiet -all -of_objects [get_filesets $fs_obj] -filter $filter] {
      set file_obj {}
      if { [info exists a_sim_cache_all_design_files_obj($file)] } {
        set file_obj $a_sim_cache_all_design_files_obj($file)
      } else {
        set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
      }
      set file [file normalize [string map {\\ /} $file]]
      if { [lsearch -exact $incl_files_set $file] == -1 } {
        lappend incl_files_set $file
        lappend incl_files     $file
        set incl_file_path [file normalize [string map {\\ /} [file dirname $file]]]
        if { $a_sim_vars(b_absolute_path) } {
          set incl_file_path "[xcs_resolve_file_path $incl_file_path $launch_dir]"
        } else {
          if { $ref_dir } {
            if { $a_sim_vars(b_xport_src_files) } {
              set incl_file_path "\$ref_dir/incl"
            } else {
              set incl_file_path "\$ref_dir/[xcs_get_relative_file_path $incl_file_path $dir]"
            }
          } else {
            if { $a_sim_vars(b_xport_src_files) } {
              set incl_file_path "srcs/incl"
            } else {
              set incl_file_path "[xcs_get_relative_file_path $incl_file_path $dir]"
            }
          }
        }
        lappend incl_file_paths $incl_file_path
      }
    }
  }
}

proc xps_get_global_include_file_cmdstr { simulator launch_dir incl_files_arg } {
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
  return [join $file_str "|"]
}

proc xps_xtract_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable a_sim_cache_all_design_files_obj
  
  if { $a_sim_vars(b_extract_ip_sim_files) } {
    set file_obj {}
    if { [info exists a_sim_cache_all_design_files_obj($file)] } {
      set file_obj $a_sim_cache_all_design_files_obj($file)
    } else {
      set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
    }
    set xcix_ip_path [get_property core_container $file_obj]
    if { {} != $xcix_ip_path } {
      set ip_name [file root [file tail $xcix_ip_path]]
      set ip_ext_dir [get_property ip_extract_dir [get_ips -all -quiet $ip_name]]
      set ip_file "[xcs_get_relative_file_path $file $ip_ext_dir]"
      # remove leading "../"
      set ip_file [join [lrange [split $ip_file "/"] 1 end] "/"]
      set file "$ip_ext_dir/$ip_file"
    }
  }
  return $file
}

proc xps_write_filelist_info { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_vars
  variable l_target_simulator
  set fh 0
  set file "$dir/file_info.txt"
  if {[catch {open $file w} fh]} {
    send_msg_id exportsim-Tcl-067 ERROR "failed to open file to write ($file)\n"
    return 1
  }
  
  # get include file dirs
  set prefix_ref_dir "false"
  set incl_dirs {}
  foreach dir [concat [xps_get_verilog_incl_dirs $simulator $dir $prefix_ref_dir] [xps_get_verilog_incl_file_dirs $simulator $dir $prefix_ref_dir]] {
    set dir "incdir=\"$dir\""
    append incl_dirs $dir
  }
  set incl_dir_str {}
  foreach str $incl_dirs {
    append incl_dir_str $str
  }

  foreach file $a_sim_vars(l_design_files) {
    set fargs         [split $file {|}]
    set type          [lindex $fargs 0]
    set file_type     [string tolower [lindex $fargs 1]]
    set lib           [lindex $fargs 2]
    set proj_src_file [lindex $fargs 3]
    set ip_file       [lindex $fargs 5]
    set src_file      [lindex $fargs 6]
    set b_static_ip   [lindex $fargs 7]
    set b_xpm         [lindex $fargs 8]
    set filename [file tail $proj_src_file]
    set ipname   [file rootname [file tail $ip_file]]
  
    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
    set src_file [xps_resolve_file $proj_src_file $lib $ip_file $src_file $dir]
    set pfile $src_file
    puts $fh "$filename,$file_type,$lib,$pfile,$incl_dir_str"
  }
  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    set file "glbl.v"
    if { $a_sim_vars(b_absolute_path) } {
      set file [file normalize "$dir/$file"]
    }
    set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
    puts $fh "glbl.v,Verilog,$top_lib,$file"
  }
  close $fh
  return 0
}

proc xps_resolve_file { proj_src_file lib ip_file src_file dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  set src_file [string trim $src_file "\""]
  if { {} == $ip_file } {
    set source_file [string trim $proj_src_file {\"}]
    if { $a_sim_vars(b_absolute_path) } {
      set src_file "[xcs_resolve_file_path $source_file $dir]"
    } else {
      set src_file "[xcs_get_relative_file_path $source_file $dir]"
    }
  }
  if { $a_sim_vars(b_xport_src_files) } {
    if { {} != $ip_file } {
      set proj_src_filename [file tail $proj_src_file]
      set ip_name [file rootname [file tail $ip_file]]
      set proj_src_filename "ip/$ip_name/$lib/$proj_src_filename"
      set src_file "srcs/$proj_src_filename"
    } else {
      set src_file "srcs/[file tail $proj_src_file]"
    }
    if { $a_sim_vars(b_absolute_path) } {
      set src_file [file normalize "$dir/$src_file"]
    }
  }
  return $src_file
}

proc xps_print_message_for_unsupported_simulator_ip { ip simulator } {
  # Summary: check if IP support current simulator
  # Argument Usage:
  # Return Value:

  set extn [string tolower [file extension $ip]]
  if { ({.bd} == $extn) } {
    return
  }

  set ip_filename [file tail $ip]
  set ip_name [file rootname [file tail $ip_filename]]
  set ip_props [list_property [lindex [get_ips -all $ip_name] 0]]
  if { [lsearch -nocase $ip_props "unsupported_simulators"] != -1 } {
    set invalid_simulators [get_property -quiet unsupported_simulators [get_ips -quiet $ip_name]]
    if { [lsearch -nocase $invalid_simulators $simulator] != -1 } {
      [catch {send_msg_id exportsim-Tcl-068 ERROR "Simulation of '${ip_name}' is not supported for '$simulator' simulator. Please contact the IP provider to add support for this simulator.\n"} error]
    }
  }
}

proc xps_print_message_for_unsupported_simulator_fileset { fs_obj simulator } {
  # Summary: check if all IPs in fileset support current simulator
  # Argument Usage:
  # Return Value:

  foreach ip_obj [get_ips -all -quiet] {
    set ip_file [get_property -quiet ip_file $ip_obj]
    set extn [string tolower [file extension $ip_file]]
    if { ({.xci} == $extn) } {
      xps_print_message_for_unsupported_simulator_ip $ip_file $simulator
    }
  }
}
}
