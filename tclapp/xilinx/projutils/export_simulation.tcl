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
proc xps_init_vars {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  #
  # define bool vars
  #
  set a_sim_vars(b_lib_map_path_specified)        0
  set a_sim_vars(b_gcc_bin_path_specified)        0
  set a_sim_vars(b_script_specified)              0
  set a_sim_vars(b_runtime_specified)             0
  set a_sim_vars(b_define_specified)              0
  set a_sim_vars(b_generic_specified)             0
  set a_sim_vars(b_include_specified)             0
  set a_sim_vars(b_more_options_specified)        0
  set a_sim_vars(b_extract_ip_sim_files)          0
  set a_sim_vars(b_32bit)                         0
  set a_sim_vars(b_is_ip_object_specified)        0
  set a_sim_vars(b_is_fs_object_specified)        0
  set a_sim_vars(b_absolute_path)                 0
  set a_sim_vars(b_single_step)                   0
  set a_sim_vars(b_xport_src_files)               0
  set a_sim_vars(b_generate_hier_access)          0 
  set a_sim_vars(b_overwrite)                     0
  set a_sim_vars(b_of_objects_specified)          0
  set a_sim_vars(b_contain_sv_srcs)               0
  set a_sim_vars(b_contain_systemc_sources)       0
  set a_sim_vars(b_contain_cpp_sources)           0
  set a_sim_vars(b_contain_c_sources)             0
  set a_sim_vars(b_contain_systemc_headers)       0
  set a_sim_vars(b_system_sim_design)             0
  set a_sim_vars(b_ip_user_files_dir_specified)   0
  set a_sim_vars(b_ipstatic_source_dir_specified) 0
  set a_sim_vars(b_directory_specified)           0
  set a_sim_vars(b_scripts_only)                  0
  set a_sim_vars(b_use_static_lib)                0
  set a_sim_vars(b_int_systemc_mode)              [get_param "project.enableSystemCSupport"]
  set a_sim_vars(b_int_system_design)             [rdi::is_system_sim_design]
  set a_sim_vars(b_int_sm_lib_ref_debug)          0

  set a_sim_vars(b_compile_simmodels)             0
  #
  # define string vars
  #
  set data_dir                              [rdi::get_data_dir -quiet -datafile "ip/xilinx"]
  set a_sim_vars(s_ip_repo_dir)             [file normalize [file join $data_dir "ip/xilinx"]]
  set a_sim_vars(curr_time)                 [clock format [clock seconds]]
  set a_sim_vars(curr_proj_obj)             [current_project]
  set a_sim_vars(fs_obj)                    [current_fileset -simset]
  set a_sim_vars(s_simulator)               "all"
  set a_sim_vars(s_xport_dir)               "export_sim"
  set a_sim_vars(s_simulator_name)          ""
  set a_sim_vars(s_script_filename)         ""
  set a_sim_vars(s_runtime)                 ""
  set a_sim_vars(ip_filename)               ""
  set a_sim_vars(s_ip_file_extn)            ".xci"
  set a_sim_vars(sp_of_objects)             {}
  set a_sim_vars(s_ip_user_files_dir)       ""
  set a_sim_vars(s_ipstatic_source_dir)     ""
  set a_sim_vars(src_mgmt_mode)             "All"
  set a_sim_vars(s_simulation_flow)         "behav_sim"
  set a_sim_vars(sp_tcl_obj)                ""
  set a_sim_vars(s_top)                     ""
  set a_sim_vars(s_install_path)            ""
  set a_sim_vars(s_lib_map_path)            ""
  set a_sim_vars(global_files_str)          ""
  set a_sim_vars(default_lib)               "xil_defaultlib"
  set a_sim_vars(do_filename)               "simulate.do"
  set a_sim_vars(s_bypass_script_filename)  "gen_hier_access_info"
  set a_sim_vars(s_compile_pre_tcl_wrapper) "vivado_wc_pre"; # wrapper file for executing user tcl (not supported currently in export_sim)
  set a_sim_vars(sp_cpt_dir)                {}
  set a_sim_vars(sp_ext_dir)                {}
  set a_sim_vars(custom_sm_lib_dir)         {}
  set a_sim_vars(s_gcc_bin_path)            {}
  set a_sim_vars(s_gcc_version)             {}
  set a_sim_vars(s_sys_link_path)           {}
  set a_sim_vars(b_ref_sysc_lib_env)        [get_param "project.refSystemCLibPathWithXilinxEnv"]
  set a_sim_vars(tmp_obj_dir)               "c.obj"
  set a_sim_vars(syscan_libname)            "lib_sc.so"
  # 
  # define list vars
  #
  variable l_simulators               [list xsim modelsim questa ies xcelium vcs riviera activehdl]
  variable l_xpm_libraries            [list]
  variable l_system_sim_incl_dirs     [list]
  variable l_lib_map_path             [list]
  variable l_compile_order_files      [list]
  variable l_compile_order_files_uniq [list]
  variable l_design_files             [list]
  variable l_compiled_libraries       [list]
  variable l_local_design_libraries   [list]
  variable l_systemc_incl_dirs        [list]
  variable l_target_simulator         [list]
  variable l_include_dirs             [list]
  variable l_more_options             [list]
  variable l_defines                  [list]
  variable l_generics                 [list]
  variable a_sim_sv_pkg_libs          [list]
  variable l_valid_simulator_types    [list]
  variable l_valid_ip_extns           [list]

  variable s_data_files_filter
  variable s_embedded_files_filter
  variable s_non_hdl_data_files_filter
  variable a_sim_cache_extract_source_from_repo
  variable a_sim_cache_gen_mem_files

  set l_valid_simulator_types         [list all xsim modelsim questa ies xcelium vcs vcs_mx ncsim riviera activehdl]
  set l_valid_ip_extns                [list ".xci" ".bd" ".slx"]
  set s_data_files_filter \
                                      "FILE_TYPE == \"Data Files\"                  || \
                                       FILE_TYPE == \"Memory File\"                 || \
                                       FILE_TYPE == \"STATIC MEMORY FILE\"          || \
                                       FILE_TYPE == \"Memory Initialization Files\" || \
                                       FILE_TYPE == \"CSV\"                         || \
                                       FILE_TYPE == \"Coefficient Files\"           || \
                                       FILE_TYPE == \"Configuration Data Object\""

  set s_embedded_files_filter \
                                      "FILE_TYPE == \"BMM\" || \
                                       FILE_TYPE == \"ELF\""

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

 
  # 
  # common - imported to <ns>::xcs_* - home is defined in <app>.tcl
  #
  if { ! [info exists ::tclapp::xilinx::projutils::_xcs_defined] } {
    variable home
    source -notrace "$home/common/utils.tcl"
  }
  
  variable a_sim_cache_result
  array unset a_sim_cache_result

  variable a_sim_cache_all_design_files_obj
  array unset a_sim_cache_all_design_files_obj

  variable a_sim_cache_all_bd_files
  array unset a_sim_cache_all_bd_files

  variable a_sim_cache_parent_comp_files
  array unset a_sim_cache_parent_comp_files

  variable a_sim_cache_lib_info
  array unset a_sim_cache_lib_info

  variable a_sim_cache_lib_type_info
  array unset a_sim_cache_lib_type_info

  variable a_sim_cache_ip_repo_header_files
  array unset a_sim_cache_ip_repo_header_files

  variable a_shared_library_path_coln
  array unset a_shared_library_path_coln

  variable a_shared_library_mapping_path_coln
  array unset a_shared_library_mapping_path_coln

  array unset a_sim_cache_extract_source_from_repo
  array unset a_sim_cache_gen_mem_files

  variable a_sim_cache_sysc_stub_files
  array unset a_sim_cache_sysc_stub_files
}

proc export_simulation {args} {
  # Summary: Export a script and associated data files (if any) for driving standalone simulation using the specified simulator.

  # Argument Usage:
  # [-simulator <arg> = all]: Simulator for which the simulation script will be created (value=all|xsim|modelsim|questa|ies|xcelium|vcs|riviera|activehdl)
  # [-of_objects <arg> = None]: Export simulation script for the specified object
  # [-ip_user_files_dir <arg> = Empty]: Directory path to the exported IP/BD (Block Design) user files (for static, dynamic and data files)
  # [-ipstatic_source_dir <arg> = Empty]: Directory path to the exported IP/BD static files
  # [-lib_map_path <arg> = Empty]: Precompiled simulation library directory path. If not specified, then please follow the instructions in the generated script header to manually provide the simulation library mapping information.
  # [-gcc_install_path <arg> = Empty]: GNU compiler installation directory path for the g++/gcc executables.
  # [-script_name <arg> = top_module.sh]: Output script filename. If not specified, then a file with a default name will be created.
  # [-directory <arg> = export_sim]: Directory where the simulation script will be generated
  # [-runtime <arg> = Empty]: Run simulation for this time (default:full simulation run or until a logical break or finish condition)
  # [-define <arg> = Empty]: Read verilog defines from the list specified with this switch
  # [-generic <arg> = Empty]: Read vhdl generics from the list specified with this switch
  # [-include <arg> = Empty]: Read include directory paths from the list specified with this switch
  # [-more_options <arg> = Empty]: Pass specified options to the simulator tool
  # [-use_ip_compiled_libs]: Reference pre-compiled IP static library during compilation. This switch requires -ip_user_files_dir and -ipstatic_source_dir switches as well for generating scripts using pre-compiled IP library.
  # [-absolute_path]: Make all file paths absolute
  # [-export_source_files]: Copy IP/BD design files to output directory
  # [-generate_hier_access]: Extract path for hierarchical access simulation
  # [-32bit]: Perform 32bit compilation
  # [-force]: Overwrite previous files

  # Return Value:
  # None

  # Categories: simulation, xilinxtclstore

  variable a_sim_vars
  variable l_lib_map_path
  variable l_defines
  variable l_generics
  variable l_include_dirs
  variable l_more_options

  xps_init_vars

  set a_sim_vars(options) [split $args " "]

  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]

    # special processing for lib_map_path switch
    if { [xps_process_lib_map_path $option] } {
      continue
    }

    switch -regexp -- $option {
      "-simulator"                { incr i;set a_sim_vars(s_simulator)           [string tolower [lindex $args $i]]                                        }
      "-lib_map_path"             { incr i;set l_lib_map_path                    [lindex $args $i];set a_sim_vars(b_lib_map_path_specified)              1 }
      "-gcc_install_path"         { incr i;set a_sim_vars(s_gcc_bin_path)        [lindex $args $i];set a_sim_vars(b_gcc_bin_path_specified)              1 }
      "-of_objects"               { incr i;set a_sim_vars(sp_of_objects)         [lindex $args $i];set a_sim_vars(b_of_objects_specified)                1 }
      "-ip_user_files_dir"        { incr i;set a_sim_vars(s_ip_user_files_dir)   [lindex $args $i];set a_sim_vars(b_ip_user_files_dir_specified)         1 }
      "-ipstatic_source_dir"      { incr i;set a_sim_vars(s_ipstatic_source_dir) [lindex $args $i];set a_sim_vars(b_ipstatic_source_dir_specified)       1 }
      "-script_name"              { incr i;set a_sim_vars(s_script_filename)     [lindex $args $i];set a_sim_vars(b_script_specified)                    1 }
      "-directory"                { incr i;set a_sim_vars(s_xport_dir)           [lindex $args $i];set a_sim_vars(b_directory_specified)                 1 }
      "-runtime"                  { incr i;set a_sim_vars(s_runtime)             [lindex $args $i];set a_sim_vars(b_runtime_specified)                   1 }
      "-define"                   { incr i;set l_defines                         [lindex $args $i];set a_sim_vars(b_define_specified)                    1 }
      "-generic"                  { incr i;set l_generics                        [lindex $args $i];set a_sim_vars(b_generic_specified)                   1 }
      "-include"                  { incr i;set l_include_dirs                    [lindex $args $i];set a_sim_vars(b_include_specified)                   1 }
      "-more_options"             { incr i;set l_more_options                    [lindex $args $i];set a_sim_vars(b_more_options_specified)              1 }
      "-32bit"                    { set a_sim_vars(b_32bit)                                                                                              1 }
      "-absolute_path"            { set a_sim_vars(b_absolute_path)                                                                                      1 }
      "-use_ip_compiled_libs"     { set a_sim_vars(b_use_static_lib)                                                                                     1 }
      "-export_source_files"      { set a_sim_vars(b_xport_src_files)                                                                                    1 }
      "-generate_hier_access"     { set a_sim_vars(b_generate_hier_access)                                                                               1 }
      "-force"                    { set a_sim_vars(b_overwrite)                                                                                          1 }
      default {
        if { [regexp {^-} $option] } {
          send_msg_id exportsim-Tcl-003 ERROR "Unknown option '$option', please type 'export_simulation -help' for usage info.\n"
          return
        }
      }
    }
  }

  # valid options?
  if { [xps_invalid_options] } {
    return
  }

  # control precompile flow
  xcs_control_pre_compile_flow a_sim_vars(b_use_static_lib)

  # print pre-compile info msg
  xps_print_precompile_lib_info_msg

  # set target simulator
  xps_set_target_simulator

  # set object
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

  # set webtalk
  xps_set_webtalk_data

  # cache all design files
  variable a_sim_cache_all_design_files_obj 
  foreach file_obj [get_files -quiet -all] {
    set name [get_property -quiet name $file_obj]
    set a_sim_cache_all_design_files_obj($name) $file_obj
  }

  # initialize boost library reference
  set a_sim_vars(s_boost_dir) [xcs_get_boost_library_path]

  # initialize XPM libraries (if any)
  xcs_get_xpm_libraries

  # cache all system verilog package libraries
  xcs_find_sv_pkg_libs "[pwd]" false

  #
  # export simulation processing
  #
  
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
  array unset a_sim_cache_lib_info
  array unset a_sim_cache_lib_type_info
  array unset a_sim_cache_ip_repo_header_files
  array unset a_shared_library_path_coln
  array unset a_shared_library_mapping_path_coln

  return
}
}

namespace eval ::tclapp::xilinx::projutils {

proc xps_process_lib_map_path { option } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  variable l_lib_map_path

  # trim braces, leading or trailing spaces, if any for processing -lib_map_path switch
  set opt_arg_val $option
  set opt_arg_val [string trim $opt_arg_val "\{\} "]

  # is -lib_map_path?
  if { [regexp {^\-lib_map_path} $opt_arg_val] } {
    set l_option [split $opt_arg_val { }]
    #************************************************************************************
    # process, if contains switch name and value together as a single option entity, e.g
    #
    #  "-lib_map_path [list {modelsim=/tmp/msim_lib} {ies=/tmp/ies_lib}])"
    #  "-lib_map_path /tmp/mlib"
    #************************************************************************************
    if { [llength $l_option] > 1 } {
      # get the -lib_map_path value part
      set opt_val [join [lrange $l_option 1 end]]

      # trim brackets, if any
      set opt_val [string trim $opt_val "\]\[ "]

      # trim "list" word, braces and space, if any
      set opt_val [string trimleft $opt_val {list}]
      set opt_val [string trim $opt_val "\{\} "]
 
      # wrap in single curly braces and set the value 
      set l_lib_map_path "\{$opt_val\}"
      set a_sim_vars(b_lib_map_path_specified) 1

      # option processed
      return true 
    }
  }
  return false
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

  return 0
}

proc xps_print_precompile_lib_info_msg { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set b_print 1
  set b_is_ip_project [xcs_is_ip_project]

  # print cw for 3rd party simulator when -lib_map_path is not specified
  if { {all} != $a_sim_vars(s_simulator) } {
    if { {xsim} == $a_sim_vars(s_simulator) } {
      # no op
    } else {
      # is pre-compile flow with design containing IPs for a 3rd party simulator?
      if { ($a_sim_vars(b_use_static_lib)) && $b_is_ip_project } {
        # is -lib_map_path not specified?
        if { !$a_sim_vars(b_lib_map_path_specified) } {
          send_msg_id exportsim-Tcl-056 "CRITICAL WARNING" \
           "Library mapping is not provided. The scripts will not be aware of pre-compiled libraries. It is highly recommended to use the -lib_map_path switch and point to the relevant simulator library mapping file path.\n"
          set b_print 0
        }
      }
    }
  }

  if { ($a_sim_vars(b_use_static_lib)) && $b_is_ip_project } {
    if { $b_print } {
      send_msg_id exportsim-Tcl-040 INFO "Using compiled simulation libraries for IPs\n"
    }
  }
}

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
}

proc xps_set_webtalk_data {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_target_simulator

  foreach simulator $l_target_simulator {
    set prop "webtalk.${simulator}_export_sim" 
    set curr_val [get_property -quiet $prop $a_sim_vars(curr_proj_obj)]
    if { [string is integer $curr_val] } {
      incr curr_val
      [catch {set_property $prop $curr_val $a_sim_vars(curr_proj_obj)} err]
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
  if { [xps_write_sim_script $run_dir $data_files $filename] } {
    return
  }
  return 0
}
}

#
# First-level helper procs
#
namespace eval ::tclapp::xilinx::projutils {

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
        set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
      } elseif { $fs_type == "SimulationSrcs" } {
        set a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj)

        rdi::verify_ip_sim_status -all
        set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
      }
    } else {
      # no -of_objects specifed, set default active simset
      set a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj)

      rdi::verify_ip_sim_status -all
      set a_sim_vars(s_top) [get_property TOP $a_sim_vars(fs_obj)]
    }
  }
  return 0
}

proc xps_create_rundir { dir run_dir_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  upvar $run_dir_arg run_dir

  variable a_sim_vars
  variable l_target_simulator
  variable l_valid_ip_extns

  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xcs_is_ip $tcl_obj $l_valid_ip_extns] } {
    if { $a_sim_vars(b_directory_specified) } {
      set ip_dir [file tail [file dirname $tcl_obj]]
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

proc xps_create_dir { dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { ![file exists $dir] } {
    if {[catch {file mkdir $dir} error_msg] } {
      send_msg_id exportsim-Tcl-011 ERROR "failed to create the directory ($dir): $error_msg\n"
      return 1
    }
  }
  return 0
}

proc xps_readme { dir } {
  # Summary:
  # Argument Usage:
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

proc xps_xport_data_files { data_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $data_files_arg data_files

  variable a_sim_vars
  variable s_data_files_filter
  variable s_non_hdl_data_files_filter
  variable l_valid_ip_extns

  set tcl_obj $a_sim_vars(sp_tcl_obj)
  if { [xcs_is_ip $tcl_obj $l_valid_ip_extns] } {
    set ip_filter "FILE_TYPE == \"IP\""
    set ip_name [file tail $tcl_obj]
    set data_files [concat $data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_data_files_filter]]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_non_hdl_data_files_filter] {
      if { [lsearch -exact [list_property -quiet $file] {IS_USER_DISABLED}] != -1 } {
        if { [get_property {IS_USER_DISABLED} $file] } {
          continue;
        }
      }
      lappend data_files $file
    }

    #
    # for exporting BD design, add source fileset nocattrs.dat file for NoC (it resides in source fileset)
    #
    if { {} != [xcs_find_ip "noc"] } {
      set noc_attrs [get_files -all -quiet -of_objects [current_fileset] -filter "FILE_TYPE == \"Data Files\"" nocattrs.dat]
      if { {} != $noc_attrs } {
        lappend data_files $noc_attrs
      }
    }
  } elseif { [xcs_is_fileset $tcl_obj] } {
    xps_export_fs_data_files $s_data_files_filter data_files
    xps_export_fs_non_hdl_data_files data_files
  } else {
    send_msg_id exportsim-Tcl-017 INFO "Unsupported object source: $tcl_obj\n"
    return 1
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

  set l_local_ip_libs [xcs_get_libs_from_local_repo $a_sim_vars(b_use_static_lib)]
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
      xps_print_msg_for_unsupported_simulator_ip $tcl_obj $simulator

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

    if { $a_sim_vars(b_generate_hier_access) } {
     xps_generate_hier_access $simulator $dir
    } 
  }
  return 0
}
}

#
# Second-level helper procs
#
namespace eval ::tclapp::xilinx::projutils {

proc xps_get_compiled_libraries { simulator l_local_ip_libs_arg } { 
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_local_ip_libs_arg l_local_ip_libs

  variable a_sim_vars
  variable l_target_simulator

  set compiled_libraries [list]

  if { !$a_sim_vars(b_use_static_lib) } {
    return $compiled_libraries
  }

  set clibs_dir [xps_get_lib_map_path $simulator]
  if { {} != $clibs_dir } {
    set libraries [xcs_get_compiled_libraries $clibs_dir]
    # filter local ip definitions
    foreach lib $libraries {
      if { [lsearch -exact $l_local_ip_libs $lib] != -1 } {
        continue
      } else {
        lappend compiled_libraries $lib
      }
    }
  }
  return $compiled_libraries
}

proc xps_print_message_for_unsupported_simulator_fileset { fs_obj simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  foreach ip_obj [get_ips -all -quiet] {
    set ip_file [get_property -quiet ip_file $ip_obj]
    set extn [string tolower [file extension $ip_file]]
    if { ({.xci} == $extn) } {
      xps_print_msg_for_unsupported_simulator_ip $ip_file $simulator
    }
  }
}

proc xps_write_script { simulator dir filename } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars
  variable l_compile_order_files
  variable l_compile_order_files_uniq

  if { [xps_check_script $simulator $dir $filename] } {
    return 1
  }

  # set gcc
  if { $a_sim_vars(b_int_system_design) } {
    xps_set_gcc_version_path $simulator
  }

  # extract simulation model library info
  set clibs_dir [xps_get_lib_map_path $simulator]
  set ip_dir "$clibs_dir/ip"
  if { ![file exists $ip_dir] } {
    set ip_dir $clibs_dir
  }
  xcs_fetch_lib_info $simulator $ip_dir 0


  # systemC headers
  set a_sim_vars(b_contain_systemc_headers) [xcs_contains_systemc_headers]

  # find shared library paths from all IPs
  if { $a_sim_vars(b_int_systemc_mode) } {
    if { [xcs_contains_C_files] } {
      xcs_find_shared_lib_paths $simulator $a_sim_vars(s_gcc_version) $clibs_dir $a_sim_vars(custom_sm_lib_dir) $a_sim_vars(b_int_sm_lib_ref_debug) a_sim_vars(sp_cpt_dir) a_sim_vars(sp_ext_dir)
    }

    # cache all systemC stub files for vcs
    if { "vcs" == $simulator } {
      variable a_sim_cache_sysc_stub_files
      foreach file_obj [get_files -quiet -all "*_stub.sv"] {
        set name [get_property -quiet name $file_obj]
        set file_name [file root [file tail $name]]
        set module_name [string trimright $file_name "_stub"]
        set a_sim_cache_sysc_stub_files($module_name) $file_obj
      }
    }

  }

  set a_sim_vars(l_design_files) [xcs_uniquify_cmd_str [xps_get_files $simulator $dir]]

  # is system design?
  if { $a_sim_vars(b_contain_systemc_sources) || $a_sim_vars(b_contain_cpp_sources) || $a_sim_vars(b_contain_c_sources) } {
    set a_sim_vars(b_system_sim_design) 1
  }

  # contains system verilog? (for uvm)
  set a_sim_vars(b_contain_sv_srcs) [xcs_contains_system_verilog $a_sim_vars(l_design_files)]

  # TODO: for non-precompile mode set the compiled library for system simulation

  set l_compile_order_files_uniq [xcs_uniquify_cmd_str $l_compile_order_files]

  xps_write_simulation_script $simulator $dir

  send_msg_id exportsim-Tcl-029 INFO \
    "Script generated: '$dir/$filename'\n"

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

proc xps_write_simulator_readme { simulator dir } {
  # Summary:
  # Argument Usage:
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

proc xps_create_srcs_dir { dir } {
  # Summary:
  # Argument Usage:
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

proc xps_export_fs_non_hdl_data_files { data_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $data_files_arg data_files

  variable a_sim_vars
  variable s_non_hdl_data_files_filter

  foreach file [get_files -all -quiet -of_objects [get_filesets $a_sim_vars(fs_obj)] -filter $s_non_hdl_data_files_filter] {
    if { [lsearch -exact [list_property -quiet $file] {IS_USER_DISABLED}] != -1 } {
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

  set l_C_incl_dirs_opts     [list]

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

  if { $a_sim_vars(b_int_systemc_mode) } {
    set b_en_code true
    if { $b_en_code } {
      if { [xcs_contains_C_files] } {
        variable a_shared_library_path_coln
        foreach {key value} [array get a_shared_library_path_coln] {
          set shared_lib_name $key
          set lib_path        $value

          set incl_dir "$lib_path/include"
          if { [file exists $incl_dir] } {
            if { !$a_sim_vars(b_absolute_path) } {
              # get relative file path for the compiled library
              set incl_dir "[xcs_get_relative_file_path $incl_dir $launch_dir]"
            }
            #lappend l_C_incl_dirs_opts "\"+incdir+$incl_dir\""
            lappend l_C_incl_dirs_opts "-I \"$incl_dir\""
          }
        }

        foreach incl_dir [get_property "SYSTEMC_INCLUDE_DIRS" $a_sim_vars(fs_obj)] {
          if { !$a_sim_vars(b_absolute_path) } {
            set incl_dir "[xcs_get_relative_file_path $incl_dir $launch_dir]"
          }
          #lappend l_C_incl_dirs_opts "\"+incdir+$incl_dir\""
          lappend l_C_incl_dirs_opts "-I \"$incl_dir\""
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

  if { $a_sim_vars(b_int_systemc_mode) && \
       (("xsim" == $simulator) || ("questa" == $simulator) || ("xcelium" == $simulator) || ("vcs" == $simulator)) } {
    # design contain systemc sources? 
    variable l_system_sim_incl_dirs
    set sc_filter  "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC\")"
    set cpp_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"CPP\")"
    set c_filter   "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C\")"

    set sc_header_filter  "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC Header\")"
    set cpp_header_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C Header Files\")"
    set c_header_filter   "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C Header Files\")"

    # fetch systemc files
    set sc_files [xcs_get_c_files $sc_filter 1]
    if { [llength $sc_files] > 0 } {
      send_msg_id exportsim-Tcl-024 INFO "Finding SystemC sources..."
      # fetch systemc include files (.h)
      set l_incl_dir [list]
      foreach dir [xcs_get_c_incl_dirs $simulator $launch_dir $a_sim_vars(s_boost_dir) $sc_header_filter $a_sim_vars(s_ip_user_files_dir) $a_sim_vars(b_xport_src_files) $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
        lappend l_incl_dir "-I \"$dir\""
        lappend l_system_sim_incl_dirs $dir
      }


      # dependency on cpp source headers
      # fetch cpp include files (.h)
      foreach dir [xcs_get_c_incl_dirs $simulator $launch_dir $a_sim_vars(s_boost_dir) $cpp_header_filter $a_sim_vars(s_ip_user_files_dir) $a_sim_vars(b_xport_src_files) $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
        lappend l_incl_dir "-I \"$dir\""
      }

      # append simulation model libraries
      foreach C_incl_dir $l_C_incl_dirs_opts {
        lappend l_incl_dir $C_incl_dir
      }

      foreach file $sc_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }

        # set flag
        if { !$a_sim_vars(b_contain_systemc_sources) } {
          set a_sim_vars(b_contain_systemc_sources) true
        }
 
        # is dynamic? process
        set used_in_values [get_property "USED_IN" [lindex [get_files -quiet -all [list "$file"]] 0]]
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

    # fetch cpp files
    set cpp_files [xcs_get_c_files $cpp_filter 1]
    if { [llength $cpp_files] > 0 } {
      set g_files {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      # fetch systemc include files (.h)
      set l_incl_dir [list]
      foreach dir [xcs_get_c_incl_dirs $simulator $launch_dir $a_sim_vars(s_boost_dir) $cpp_filter $a_sim_vars(s_ip_user_files_dir) $a_sim_vars(b_xport_src_files) $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
        lappend l_incl_dir "-I \"$dir\""
        lappend l_system_sim_incl_dirs $dir
      }
     
      # append simulation model libraries
      foreach C_incl_dir $l_C_incl_dirs_opts {
        lappend l_incl_dir $C_incl_dir
      }

      foreach file $cpp_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }

        # set flag
        if { !$a_sim_vars(b_contain_cpp_sources) } {
          set a_sim_vars(b_contain_cpp_sources) true
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

    # fetch c files
    set c_files [xcs_get_c_files $c_filter 1]
    if { [llength $c_files] > 0 } {
      set g_files {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      # fetch systemc include files (.h)
      set l_incl_dir [list]
      foreach dir [xcs_get_c_incl_dirs $simulator $launch_dir $a_sim_vars(s_boost_dir) $c_filter $a_sim_vars(s_ip_user_files_dir) $a_sim_vars(b_xport_src_files) $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
        lappend l_incl_dir "-I \"$dir\""
        lappend l_system_sim_incl_dirs $dir
      }

      # append simulation model libraries
      foreach C_incl_dir $l_C_incl_dirs_opts {
        lappend l_incl_dir $C_incl_dir
      }
      
      foreach file $c_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }

        # set flag
        if { !$a_sim_vars(b_contain_c_sources) } {
          set a_sim_vars(b_contain_c_sources) true
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
  return $files
}

proc xps_get_ip_file_from_repo { ip_file src_file library launch_dir b_static_ip_file_arg  } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $b_static_ip_file_arg b_static_ip_file

  variable a_sim_vars

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

  upvar $b_is_static_arg      b_is_static
  upvar $b_is_dynamic_arg     b_is_dynamic
  upvar $b_add_ref_arg        b_add_ref
  upvar $b_wrap_in_quotes_arg b_wrap_in_quotes

  variable a_sim_cache_extract_source_from_repo
  variable a_sim_vars
  variable l_compiled_libraries
  variable l_local_design_libraries
  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_all_bd_files

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
  set used_in_values [xcs_find_used_in_values $full_src_file_obj]
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
  
  upvar $l_other_compiler_opts_arg l_other_compiler_opts
  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts

  variable a_sim_vars
  variable a_sim_cache_all_design_files_obj

  set b_absolute_path $a_sim_vars(b_absolute_path)
  set cmd_str {}
  set associated_library $a_sim_vars(default_lib);
  set srcs_dir [file normalize "$launch_dir/srcs"]
  if { $b_skip_file_obj_access } {
    if { $b_xpm } {
      if { [string length $xpm_library] != 0 } {
        set associated_library $xpm_library
      } else {
        set associated_library "xpm"
      }
    }
  } else {
    set file_obj {}
    if { [info exists a_sim_cache_all_design_files_obj($file)] } {
      set file_obj $a_sim_cache_all_design_files_obj($file)
    } else {
      set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
    }
    if { {} != $file_obj } {
      if { [lsearch -exact [list_property -quiet $file_obj] {LIBRARY}] != -1 } {
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
        } elseif { {syscan} == $compiler } {
          # no work library required
        } else {
          set arg_list [linsert $arg_list end "-work"]
        }
      }
    }

    if { ({g++} == $compiler) || ({gcc} == $compiler) } {
      set arg_list [linsert $arg_list end "-c"]
    } elseif { {syscan} == $compiler } {
      # no work library required
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
  }
   
  if { ("xsim"    == $simulator) || \
       ("questa"  == $simulator) || \
       ("xcelium" == $simulator) || \
       ("vcs"     == $simulator) } {

    if { {sccom} == $compiler } {
      set arg_list [concat $arg_list $l_incl_dirs_opts]
    } elseif { {g++} == $compiler } {
      set arg_list [concat $arg_list $l_incl_dirs_opts]
    } elseif { {gcc} == $compiler } {
      set arg_list [concat $arg_list $l_incl_dirs_opts]
    }
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

proc xps_export_fs_data_files { filter data_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $data_files_arg data_files

  variable a_sim_vars

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

proc xps_get_lib_map_path { simulator {b_ignore_default_for_xsim 0} } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_lib_map_path

  # convert to string for truncating extra braces, if any
  set lmp_str [join $l_lib_map_path { }]
  set lmp_str [string trim $lmp_str "\{\} "]

  # convert back to list of paths
  set lmp_paths [split $lmp_str { }]
  
  set lmp_value {}
  if { $a_sim_vars(b_lib_map_path_specified) } {
    foreach lmp $lmp_paths {
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


proc xps_check_script { simulator dir filename } {
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
    # cleanup generated data
    set file_list [list]
    set file_dir_list [list]
    xps_get_files_to_remove $simulator file_list file_dir_list
    # delete files
    set files_to_delete [concat $file_list $file_dir_list]
    foreach file_name $files_to_delete {
      set file_path "$dir/$file_name"
      [catch {file delete -force $file_path} error_msg]
    }
  }
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
      send_msg_id exportsim-Tcl-036 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
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

  if { {ies} == $simulator } {
    xps_write_single_step_for_ies $fh_unix $launch_dir $srcs_dir
  } elseif { {xcelium} == $simulator } {
    xps_write_single_step_for_xcelium $fh_unix $launch_dir $srcs_dir
  } else {
    xps_write_multi_step $simulator $fh_unix $launch_dir $srcs_dir
  }
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

  switch $simulator { 
    "xsim" {
      set redirect "2>&1 | tee compile.log"
      if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
        puts $fh_unix "  xvlog \$xvlog_opts -prj vlog.prj $redirect"
      }
      if { [xcs_contains_vhdl $a_sim_vars(l_design_files)] } {
        puts $fh_unix "  xvhdl \$xvhdl_opts -prj vhdl.prj $redirect"
      }
      if { $a_sim_vars(b_contain_systemc_sources) } {
        set sc_opts [xps_get_sc_compile_options $simulator "xsc" $launch_dir]
        puts $fh_unix "  xsc -c \$xsc_opts $sc_opts -f xsc.prj $redirect"
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
      if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
        xps_write_compile_order_for_vcs_systemc "vcs" $fh_unix $launch_dir $srcs_dir
      }
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

  puts $fh_unix "\}\n"

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
    if { $a_sim_vars(b_generate_hier_access) } {
      puts $fh_unix "  simulate \$1"
    } else {
      puts $fh_unix "  simulate"
    }
  }
  puts $fh_unix "\}\n"
}

proc xps_set_systemc_cmd { simulator fh src_file log_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:
  # None

  upvar $log_arg log

  variable a_sim_vars

  switch $simulator {
    "xsim" {
      if { $a_sim_vars(b_single_step) } {
       # 
      } else {
        if { $a_sim_vars(b_xport_src_files) } {
          puts $fh "srcs/$src_file"
        } else {
          puts $fh "$src_file"
        }
      }
    }
  }
}

proc xps_set_initial_cmd { simulator fh cmd_str srcs_dir src_file file_type lib opts_str prev_file_type_arg prev_lib_arg log_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $prev_file_type_arg prev_file_type
  upvar $prev_lib_arg  prev_lib
  upvar $log_arg log

  variable a_sim_vars

  switch $simulator {
    "xsim" {
      if { $a_sim_vars(b_single_step) } {
       # 
      } else {
        puts $fh "$cmd_str ${opts_str} \\"
        set s_file [string trim $src_file {\"}]
        puts $fh "\"$s_file\" \\"
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
      if { $a_sim_vars(b_system_sim_design) } {
        if { [regexp -nocase {vhdl} $file_type] } {
          puts $fh "  $cmd_str \\"
        } else {
          puts $fh "  $cmd_str -sysc \\"
        }
      } else {
        puts $fh "  $cmd_str \\"
      }
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
  # Summary:
  # Argument Usage:
  # Return Value:
 
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

    set compiler [file tail [lindex [split $cmd_str " "] 0]]
    if { ("vcs" == $simulator) && (("syscan" == $compiler) || ("g++" == $compiler) || ("gcc" == $compiler)) } {
      # handled by xps_write_compile_order_for_vcs_systemc for multi-step flow
      continue
    }

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

proc xps_write_compile_order_for_vcs_systemc { simulator fh launch_dir srcs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
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

    set compiler [file tail [lindex [split $cmd_str " "] 0]]
    switch -exact -- $compiler {
      "syscan" -
      "g++"    -
      "gcc"    {
        if { "syscan" == $compiler } {
          variable a_sim_cache_sysc_stub_files
          # trim double-quotes
          set sysc_src_file [string trim $src_file {\"}]

          # get the module name and if corresponding stub exists, append the module name to source file
          set module_name [file root [file tail $sysc_src_file]]
          if { [info exists a_sim_cache_sysc_stub_files($module_name)] } {
            append sysc_src_file ":$module_name"

            # switch to speedup data propagation from systemC to RTL with the interface model
            set cmd_str [regsub {\-cflags} $cmd_str {-sysc=opt_if -cflags}]
          }
          set src_file "\"$sysc_src_file\""
        }
        # setup command line
        set src_file [string trim $src_file {\"}]
        set gcc_cmd "$cmd_str \\\n    \"\$ref_dir/$src_file\""
        puts $fh "  $gcc_cmd\n"
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
      set b_append_log false

      if { "questa" == $simulator } {
       if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_contain_systemc_sources) } {
          # write sccom cmd line
          set args [list]
          xps_questa_get_sccom_cmd_args $clibs_dir args
          set sccom_cmd_str [join $args " "]
          puts $fh_unix "  sccom $sccom_cmd_str 2>&1 | tee elaborate.log\n"
          set b_append_log true
        }
      }

      set append_sw " "
      if { $b_append_log } { set append_sw " -a " }
      puts $fh_unix "  source elaborate.do 2>&1 | tee${append_sw} elaborate.log"
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

  switch -regexp -- $simulator {
    "xsim"      { xps_write_xsim_sim_cmdline      $fh_unix $dir }
    "modelsim"  { xps_write_modelsim_sim_cmdline  $fh_unix $dir }
    "questa"    { xps_write_questa_sim_cmdline    $fh_unix $dir }
    "ies"       { xps_write_ies_sim_cmdline       $fh_unix $dir }
    "xcelium"   { xps_write_xcelium_sim_cmdline   $fh_unix $dir }
    "vcs"       { xps_write_vcs_sim_cmdline       $fh_unix $dir }
    "riviera"   { xps_write_riviera_sim_cmdline   $fh_unix $dir }
    "activehdl" { xps_write_activehdl_sim_cmdline $fh_unix $dir }
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
      if {$::tcl_platform(platform) == "windows"} {
        # -64 not supported
        set s_64bit {}
      }
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
      xps_append_more_options $simulator "compile" "vcom" arg_list
      set cmd_str [join $arg_list " "]
      lappend opts $cmd_str
    }
    "vlog" {
      set s_64bit {-64}
      if {$::tcl_platform(platform) == "windows"} {
        # -64 not supported
        set s_64bit {}
      }
      if { $a_sim_vars(b_32bit) } {
        set s_64bit {-32}
      }
      set arg_list [list $s_64bit]
      if { ({riviera} == $simulator) || ({activehdl} == $simulator) } {
        # reset arg list (platform switch not applicable for riviera/active-hdl)
        set arg_list [list]
      }
      xps_append_config_opts arg_list $simulator "vlog"
      xps_append_more_options $simulator "compile" "vlog" arg_list
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
      if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_contain_systemc_sources) } {
        if { {questa} == $simulator } {
          set s_64bit {-64}
          if { $a_sim_vars(b_32bit) } {
            set s_64bit {-32}
          }
          set arg_list [list $s_64bit]
          lappend arg_list "-cpppath \"$a_sim_vars(s_gcc_bin_path)/g++\""
          lappend arg_list "-std=c++11"
          xps_append_config_opts arg_list $simulator "sccom"
          xps_append_more_options "questa" "compile" "sccom" arg_list
          set cmd_str [join $arg_list " "]
          lappend opts $cmd_str
        }
      }
    }
    "g++" {
      if { $a_sim_vars(b_contain_systemc_sources) } {
        set arg_list [list]
        xps_append_config_opts arg_list $simulator "g++"
        if { ({vcs} == $simulator) } {
          lappend arg_list "\$gpp_opts"
          lappend arg_list "-c -o $a_sim_vars(tmp_obj_dir)/${file_name}.o"
        }
        set cmd_str [join $arg_list " "]
        lappend opts $cmd_str
      }
    }
    "gcc" {
      if { $a_sim_vars(b_contain_systemc_sources) } {
        set arg_list [list]
        xps_append_config_opts arg_list $simulator "gcc"
        if { ({vcs} == $simulator) } {
          lappend arg_list "\$gcc_opts"
          lappend arg_list "-c -o $a_sim_vars(tmp_obj_dir)/${file_name}.o"
        }
        set cmd_str [join $arg_list " "]
        lappend opts $cmd_str
      }
    }
    "syscan" {
      if { $a_sim_vars(b_contain_systemc_sources) } {
        set arg_list [list]
        xps_append_config_opts arg_list $simulator "syscan"
        lappend arg_list "\$syscan_opts"
        lappend arg_list "-cflags"
        lappend arg_list "\"-O3 -std=c++11 -fPIC -Wall -Wno-deprecated -DSC_INCLUDE_DYNAMIC_PROCESSES \$syscan_gcc_opts\""
        lappend arg_list "-Mdir=$a_sim_vars(tmp_obj_dir)"
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

      if { "vlogan" == $tool } {
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
  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_unix "\[-gen_bypass\] -- Generate hierarchical path information from the design\\n\\n\\"
  }
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
      set compiled_lib_dir {}

      # 1. is -lib_map_path specified and point to valid location?
      set lmp [xps_get_lib_map_path $simulator]
      if { ({} != $lmp) && ([file exists $lmp]) } {
        set ini_file "$lmp/xsim.ini"
        if { [file exists $ini_file] } {
          set compiled_lib_dir $lmp
        }
      }
      
      # 2. find from XILINX_VIVADO
      if { {} == $compiled_lib_dir } {
        if { [info exists ::env(XILINX_VIVADO)] } {
          set xil_dir $::env(XILINX_VIVADO)
          set compiled_lib_dir [file normalize "$xil_dir/data/xsim"]
        }
      }

      set a_sim_vars(s_lib_map_path) $compiled_lib_dir

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
        set b_resolve_rdi_datadir 0
        if { [get_param "simulation.resolveDataDirEnvPathForXSim"] } {
          puts $fh_unix "    # Resolve RDI_DATADIR with absolute library path"
          puts $fh_unix "    resolve_rdi_datadir \$lib_map_path\n"
          set b_resolve_rdi_datadir 1
        }
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
        puts $fh_unix "    rm -f \$file_backup\n"
        puts $fh_unix "    # Create a backup copy of the xsim.ini file"
        puts $fh_unix "    cp \$file \$file_backup\n"
        puts $fh_unix "    # Read libraries from backup file and search in local library collection"
        puts $fh_unix "    while read -r line"
        puts $fh_unix "    do"
        puts $fh_unix "      IN=\$line\n"
        puts $fh_unix "      # Split mapping entry with '=' delimiter to fetch library name and mapping"
        puts $fh_unix "      read lib_name mapping <<<\$(IFS=\"=\"; echo \$IN)\n"
        puts $fh_unix "      # If local library found, then construct the local mapping and add to local mapping collection"
        puts $fh_unix "      if `echo \$\{local_libs\[@\]\} | grep -wq \$lib_name` ; then"
        puts $fh_unix "        line=\"\$lib_name=xsim.dir/\$lib_name\""
        puts $fh_unix "        local_mappings+=(\"\$lib_name\")"
        puts $fh_unix "      fi\n"
        puts $fh_unix "      # Add to updated library mapping collection"
        puts $fh_unix "      updated_mappings+=(\"\$line\")"
        puts $fh_unix "    done < \"\$file_backup\"\n"
        puts $fh_unix "    # Append local libraries not found originally from xsim.ini"
        puts $fh_unix "    for (( i=0; i<\$\{#local_libs\[*\]\}; i++ )); do"
        puts $fh_unix "      lib_name=\"\$\{local_libs\[i\]\}\""
        puts $fh_unix "      if `echo \$\{local_mappings\[@\]\} | grep -wvq \$lib_name` ; then"
        puts $fh_unix "        line=\"\$lib_name=xsim.dir/\$lib_name\""
        puts $fh_unix "        updated_mappings+=(\"\$line\")"
        puts $fh_unix "      fi"
        puts $fh_unix "    done\n"
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

        if { $b_resolve_rdi_datadir } {
          puts $fh_unix "# Resolve RDI_DATADIR with absolute library path"
          puts $fh_unix "resolve_rdi_datadir()"
          puts $fh_unix "\{"
          puts $fh_unix "  lib_map_path=\$1"
          puts $fh_unix "  resolved_mappings=()"
          puts $fh_unix "  file=\"xsim.ini\""
          puts $fh_unix "  file_backup=\"xsim.ini.bak\"\n"
          puts $fh_unix "  if \[\[ ! -e \$file \]\]; then"
          puts $fh_unix "    return"
          puts $fh_unix "  fi\n"
          puts $fh_unix "  # Create a backup copy of the xsim.ini file"
          puts $fh_unix "  if \[\[ ! -e \$file_backup \]\]; then"
          puts $fh_unix "    cp \$file \$file_backup"
          puts $fh_unix "  fi\n"
          puts $fh_unix "  # Replace RDI_DATADIR with lib_map_path value"
          puts $fh_unix "  while read -r line"
          puts $fh_unix "  do"
          puts $fh_unix "    IN=\$line\n"
          puts $fh_unix "    # Split mapping entry with '=' delimiter to fetch library name and mapping"
          puts $fh_unix "    read lib_name mapping <<<\$(IFS=\"=\"; echo \$IN)"
          puts $fh_unix "    if \[\[ \$mapping =~ .*RDI_DATADIR.* \]\]; then"
          puts $fh_unix "      mapping=\"\$\{mapping/\\\$RDI_DATADIR/\$lib_map_path\}\""
          puts $fh_unix "      mapping=\"\$\{mapping/data\\/xsim\\/xsim/data/xsim\}\""
          puts $fh_unix "    fi"
          puts $fh_unix "    line=\"\$lib_name=\$mapping\"\n"
          puts $fh_unix "    # Add to library mapping collection"
          puts $fh_unix "    resolved_mappings+=(\"\$line\")"
          puts $fh_unix "  done < \"\$file\"\n"
          puts $fh_unix "  # Write updated mappings in xsim.ini"
          puts $fh_unix "  rm -f \$file"
          puts $fh_unix "  for (( i=0; i<\$\{#resolved_mappings\[*\]\}; i++ )); do"
          puts $fh_unix "    lib_name=\"\$\{resolved_mappings\[i\]\}\""
          puts $fh_unix "    echo \$lib_name >> \$file"
          puts $fh_unix "  done"
          puts $fh_unix "\}\n"
        }

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
  set design_libs [xcs_get_design_libs $a_sim_vars(l_design_files)]
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
        set proj_src_filename "ip/$ip_name/$lib/$proj_src_filename"
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
    
      if { {SYSTEMC} == $ft } {
        if { $a_sim_vars(b_xport_src_files) } {
          xps_set_systemc_cmd "xsim" $fh $proj_src_filename log
        } else {
          xps_set_systemc_cmd "xsim" $fh $src_file log
        }
      } else {
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

  if { {SYSTEMC} == $ft } {
    # is nosort supported?
  } else {
    puts $fh "\nnosort"
  }

  close $fh
}

proc xps_get_xsim_verilog_options { launch_dir opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts

  variable a_sim_vars
  variable l_defines
  variable l_include_dirs
  variable l_compiled_libraries

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
  if { [get_param "project.usePreCompiledXilinxVIPLibForSim"] } {
    if { [xcs_design_contain_sv_ip] } {
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
  set design_libs [xcs_get_design_libs $a_sim_vars(l_design_files)]
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
      set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
      # 1076948 - default access to nets/ports/registers (npr)
      set arg_list [list "+acc=npr" "-l" "elaborate.log"]
      if { !$a_sim_vars(b_32bit) } {
        if {$::tcl_platform(platform) == "windows"} {
          # -64 not supported
        } else {
          set arg_list [linsert $arg_list 0 "-64"]
        }
      }

      if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
        lappend arg_list "-cpppath $a_sim_vars(s_gcc_bin_path)/g++"
      }

      xps_append_more_options "questa" "elaborate" "vopt" arg_list

      if { [llength $l_generics] > 0 } {
        xps_append_generics $l_generics arg_list
      }

      set t_opts [join $arg_list " "]

      set design_files $a_sim_vars(l_design_files)
      set design_libs [xcs_get_design_libs $design_files 1]

      # add simulation libraries
      set arg_list [list]

      # add sv pkg libraries
      #variable a_sim_sv_pkg_libs
      #foreach lib $a_sim_sv_pkg_libs {
      #  if { [lsearch $design_libs $lib] == -1 } {
      #    lappend arg_list "-L"
      #    lappend arg_list "$lib"
      #  }
      #}

      # add user design libraries
      foreach lib $design_libs {
        if {[string length $lib] == 0} { continue; }
        lappend arg_list "-L"
        lappend arg_list "$lib"
        #lappend arg_list "[string tolower $lib]"
      }

      # add xilinx vip library
      if { [get_param "project.usePreCompiledXilinxVIPLibForSim"] } {
        if { [xcs_design_contain_sv_ip] } {
          lappend arg_list "-L xilinx_vip"
        }
      }

      if { [xcs_contains_verilog $design_files] } {
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
        # pass xpm library reference for behavioral simulation only
        set arg_list [linsert $arg_list end "-L" "xpm"]
      }

      lappend arg_list "-work"
      lappend arg_list $a_sim_vars(default_lib)

      set d_libs [join $arg_list " "]
      set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]

      set arg_list [list]
      lappend arg_list "vopt"
      xps_append_config_opts arg_list $simulator "vopt"

      lappend arg_list $t_opts
      lappend arg_list "$d_libs"

      set top $a_sim_vars(s_top)
      lappend arg_list "${top_lib}.$top"
      if { [xcs_contains_verilog $design_files] } {
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

# for modelsim, questa, riviera, active_hdl
proc xps_write_do_file_for_simulate { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set b_absolute_path $a_sim_vars(b_absolute_path)
  set filename $a_sim_vars(do_filename)
  set do_file [file normalize "$dir/$filename"]
  set fh 0
  set do_file_hbs [file normalize "$dir/simulate_hbs.do"]
  set fh_hbs 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id exportsim-Tcl-059 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }
  if { $a_sim_vars(b_generate_hier_access) } {
    if {[catch {open $do_file_hbs w} fh_hbs]} {
      send_msg_id exportsim-Tcl-059 ERROR "Failed to open file to write ($do_file_hbs)\n"
      return 1
    }
  }
  set wave_do_filename "wave.do"
  set wave_do_file [file normalize "$dir/$wave_do_filename"]
  xps_create_wave_do_file $wave_do_file
  set cmd_str {}
  set cmd_str_hbs {}
  switch $simulator {
    "modelsim" -
    "riviera" -
    "activehdl" { 
      set cmd_str [xps_get_simulation_cmdline_modelsim $simulator]
      if { $a_sim_vars(b_generate_hier_access) } {
        set cmd_str_hbs [xps_get_simulation_cmdline_modelsim $simulator "true"]
      }
    }
    "questa" {
      set cmd_str [xps_get_simulation_cmdline_questa]
      if { $a_sim_vars(b_generate_hier_access) } {
        set cmd_str_hbs [xps_get_simulation_cmdline_questa "true"]
      }
    }
  }

  switch $simulator {
    "modelsim" -
    "questa" {
      puts $fh "onbreak {quit -f}"
      puts $fh "onerror {quit -f}\n"
      if { $a_sim_vars(b_generate_hier_access) } {
        puts $fh_hbs "onbreak {quit -f}"
        puts $fh_hbs "onerror {quit -f}\n"
      }
    }
    "riviera" -
    "activehdl" {
      puts $fh "onbreak {quit -force}"
      puts $fh "onerror {quit -force}\n"
      if { $a_sim_vars(b_generate_hier_access) } {
        puts $fh_hbs "onbreak {quit -force}"
        puts $fh_hbs "onerror {quit -force}\n"
      }
    }
  }

  puts $fh "$cmd_str"
  puts $fh "\nset NumericStdNoWarnings 1"
  puts $fh "set StdArithNoWarnings 1"
  puts $fh "\ndo \{$wave_do_filename\}"
  puts $fh "\nview wave"
  puts $fh "view structure"
  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_hbs "$cmd_str_hbs"
    puts $fh_hbs "\ndo \{$wave_do_filename\}"
    puts $fh_hbs "\nview wave"
    puts $fh_hbs "view structure"
  }
  switch $simulator {
    "modelsim" -
    "questa" {
      puts $fh "view signals"
      if { $a_sim_vars(b_generate_hier_access) } {
        puts $fh_hbs "view signals"
      }
    }
  }
  puts $fh ""
  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_hbs ""
  }
  set top $a_sim_vars(s_top)
  set udo_filename $top;append udo_filename ".udo"
  set udo_file [file normalize "$dir/$udo_filename"]
  xps_create_udo_file $udo_file
  puts $fh "do \{$top.udo\}"
  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_hbs "do \{$top.udo\}"
  }
  set runtime "run -all"
  if { $a_sim_vars(b_runtime_specified) } {
    set runtime "run $a_sim_vars(s_runtime)"
  }
  puts $fh "\n$runtime"
  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_hbs "\n$runtime"
  }
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
  if { $a_sim_vars(b_generate_hier_access) } {
    if {[llength $tcl_src_files] > 0} {
      puts $fh_hbs ""
      foreach file $tcl_src_files {
        puts $fh_hbs "source \{$file\}"
      }
      puts $fh_hbs ""
    }
  }
  if { ({riviera} == $simulator) || ({activehdl} == $simulator) } {
    puts $fh "\nendsim"
    if { $a_sim_vars(b_generate_hier_access) } {
      puts $fh_hbs "\nendsim"
    }
  }
  puts $fh "\nquit -force"
  close $fh
  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_hbs "\nquit -force"
    close $fh_hbs
  }
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

proc xps_get_simulation_cmdline_questa { {b_hier_access "false"}} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set simulator "questa"
  set args [list]
  lappend args "vsim"

  xps_append_config_opts args "questa" "vsim"
  xps_append_more_options "questa" "simulate" "vsim" args

  if { $b_hier_access } {
    lappend args "+GEN_BYPASS"
  }

  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]

  lappend args "-lib"
  lappend args $top_lib
  lappend args "$a_sim_vars(s_top)_opt"

  set cmd_str [join $args " "]

  return $cmd_str
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

proc xps_write_reset { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set file_list     [list]
  set file_dir_list [list]
  set files         [list]

  xps_get_files_to_remove $simulator file_list file_dir_list

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
        #puts $fh_unix "# Command line options"
      }
    }

    switch -regexp -- $simulator {
      "xsim"    { xps_write_xsim_opt_args    $fh_unix $launch_dir }
      "ies"     { xps_write_ies_opt_args     $fh_unix }
      "xcelium" { xps_write_xcelium_opt_args $fh_unix }
      "vcs"     { xps_write_vcs_opt_args     $fh_unix $launch_dir }
    }
  }

  variable l_compiled_libraries
  switch $simulator {
    "questa" {
      if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_contain_systemc_sources) } {
        # set LD_LIBRARY_PATH for sim-models
        xps_export_ld_lib $simulator $fh_unix
      }
    }
    "ies" -
    "xcelium" -
    "vcs" {
      set libs [list]
      foreach lib [xcs_get_design_libs $a_sim_vars(l_design_files)] {
        if {[string length $lib] == 0} { continue; }
        if { ({work} == $lib) && ({vcs} == $simulator) } { continue; }
        if { $a_sim_vars(b_use_static_lib) && ([xcs_is_static_ip_lib $lib $l_compiled_libraries]) } {
          # no op
        } else {
          lappend libs [string tolower $lib]
        }
      }
      
      if { "vcs" == $simulator } {
        if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_contain_systemc_sources) } {
          # set LD_LIBRARY_PATH for sim-models
          xps_export_ld_lib $simulator $fh_unix
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
      puts $fh_unix "sim_lib_dir=\"${simulator}_lib\"\n"
    }
  }

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

proc xps_write_check_args { fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  
  puts $fh_unix "# Check command line arguments"
  puts $fh_unix "check_args()\n\{"
  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_unix "  if \[\[ (\$1 == 1 ) && (\$2 != \"-lib_map_path\" && \$2 != \"-gen_bypass\" && \$2 != \"-noclean_files\" && \$2 != \"-reset_run\" && \$2 != \"-help\" && \$2 != \"-h\") \]\]; then"
  } else {
    puts $fh_unix "  if \[\[ (\$1 == 1 ) && (\$2 != \"-lib_map_path\" && \$2 != \"-noclean_files\" && \$2 != \"-reset_run\" && \$2 != \"-help\" && \$2 != \"-h\") \]\]; then"
  }
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
  set ip_name    [file tail $tcl_obj]
  set filter     "FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\""

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
  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_all_bd_files
  variable l_valid_ip_extns

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
            # if full path to vh_file not found, prepend project dir (for the cases when ipstatic dir is empty)
            if { ![file exists $vh_file] } {
              set proj_dir [get_property directory $a_sim_vars(curr_proj_obj)]
              set vh_file "$proj_dir/$vh_file"
            }
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

  set ip_name   [file tail $tcl_obj]
  set incl_dirs [list]
  set filter    "FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\""
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
        if { [lsearch -exact [list_property -quiet $file_obj] {LIBRARY}] != -1 } {
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

proc xps_generate_hier_access { simulator dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_vars

  set version_txt [split [version] "\n"]
  set version     [lindex $version_txt 0]
  set swbuild     [lindex $version_txt 1]
  set copyright   [lindex $version_txt 3]
  set product     [lindex [split $version " "] 0]
  set version_id  [join [lrange $version 1 end] " "]
  set extn ".txt"
  set script_filename $a_sim_vars(s_bypass_script_filename)$extn

  set fh 0
  set script_file "$dir/$script_filename"
  if {[catch {open $script_file w} fh]} {
    send_msg_id exportsim-Tcl-030 ERROR "failed to open file to write ($script_file)\n"
    return 1
  }

  puts $fh "********************************************************************************************************************"
  puts $fh "# $product (TM) $version_id\n#"
  puts $fh "# Filename    : $script_filename"
  puts $fh "# Simulator   : [xcs_get_simulator_pretty_name $simulator]"
  puts $fh "# Description : Help text file for instructions on how to generate and instantiate the bypass module in the design."
  puts $fh ""
  puts $fh "# Generated by $product on $a_sim_vars(curr_time)"
  puts $fh "# $swbuild\n#"
  puts $fh "# $copyright \n#"
  puts $fh "********************************************************************************************************************"
  puts $fh "Please read the following instructions on how to generate and instantiate the bypass file in the design:-\n"
  puts $fh "Step 1: Execute wget in unix shell to fetch the bypass generation utility script from GitHub"
  puts $fh "wget https://raw.githubusercontent.com/Xilinx/XilinxTclStore/2020.1-dev/tclapp/xilinx/projutils/generate_hier_access.tcl"
  puts $fh ""
  puts $fh "Step 2: Start Tcl interpreter"
  puts $fh "/usr/bin/tclsh"
  puts $fh ""
  puts $fh "Step 3: Source and execute the 'generate_hier_access.tcl' file in Tcl shell"
  puts $fh "% source generate_hier_access.tcl"
  puts $fh "% generate_hier_access -log simulate.log"
  puts $fh ""
  puts $fh "Step 4: Verify bypass (xil_dut_bypass.sv) and driver (xil_bypass_driver.v) files generated in the current directory."
  puts $fh ""
  puts $fh "Step 5: Update design testbench to instantiate the bypass module"
  puts $fh ""
  puts $fh "Step 6: Execute $a_sim_vars(s_script_filename).sh to run hier-access simulation"

  close $fh
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

proc xps_print_msg_for_unsupported_simulator_ip { ip simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set extn [string tolower [file extension $ip]]
  if { ({.bd} == $extn) } {
    return
  }

  set ip_filename [file tail $ip]
  set ip_name [file rootname [file tail $ip_filename]]
  set ip_props [list_property -quiet [lindex [get_ips -all $ip_name] 0]]

  if { [lsearch -nocase $ip_props "unsupported_simulators"] != -1 } {
    set invalid_simulators [get_property -quiet unsupported_simulators [get_ips -quiet $ip_name]]
    if { [lsearch -nocase $invalid_simulators $simulator] != -1 } {
      [catch {send_msg_id exportsim-Tcl-068 ERROR "Simulation of '${ip_name}' is not supported for '$simulator' simulator. Please contact the IP provider to add support for this simulator.\n"} error]
    }
  }
}

}

#
# xsim_proc - XSim helper procs
#
namespace eval ::tclapp::xilinx::projutils {

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

  if { $a_sim_vars(b_contain_systemc_sources) } {
    set filename "xsc.prj"
    set file [file normalize "$dir/$filename"]
    xps_write_prj $dir $file "SYSTEMC" $srcs_dir
  }
}

proc xps_write_xsim_opt_args { fh_unix launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set clibs_dir [xps_get_lib_map_path "xsim"]
  
  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    puts $fh_unix "# Set system shared library paths"
    puts $fh_unix "xv_cxl_lib_path=\"$clibs_dir\""
    puts $fh_unix "xv_cpt_lib_path=\"$a_sim_vars(sp_cpt_dir)\""
    puts $fh_unix "xv_ext_lib_path=\"$a_sim_vars(sp_ext_dir)\""
    puts $fh_unix "xv_boost_lib_path=\"$a_sim_vars(s_boost_dir)\"\n"

    # for aie
    set aie_ip_obj [xcs_find_ip "ai_engine"]
    if { {} != $aie_ip_obj } {
      puts $fh_unix "export CHESSDIR=\"\$XILINX_VITIS/aietools/tps/lnx64/target/chessdir\"\n"
    }
  }

  set arg_list [list]
  xps_append_config_opts arg_list "xsim" "xvlog"
  xps_append_more_options "xsim" "compile" "xvlog" arg_list

  # append uvm
  if { $a_sim_vars(b_contain_sv_srcs) } {
    lappend arg_list "-L uvm"
  }

  if { [xcs_contains_verilog $a_sim_vars(l_design_files)] } {
    # append sv pkg libs
    variable a_sim_sv_pkg_libs
    foreach sv_pkg_lib $a_sim_sv_pkg_libs {
      lappend arg_list "-L $sv_pkg_lib"
    }
    puts $fh_unix "# Set xvlog options"
    puts $fh_unix "xvlog_opts=\"[join $arg_list " "]\"\n"
  }

  set arg_list [list]
  xps_append_config_opts arg_list "xsim" "xvhdl"
  xps_append_more_options "xsim" "compile" "xvhdl" arg_list
  if { [xcs_contains_vhdl $a_sim_vars(l_design_files)] } {
    puts $fh_unix "# Set xvlog options"
    puts $fh_unix "xvhdl_opts=\"[join $arg_list " "]\"\n"
  }

  # system design
  if { $a_sim_vars(b_contain_systemc_sources) } {
    set arg_list [list]
    puts $fh_unix "# Set xsc options"
    xps_append_more_options "xsim" "compile" "xsc" arg_list
    puts $fh_unix "xsc_opts=\"[join $arg_list " "]\"\n"
  }

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    xps_write_lib_var_for_xsim_simulate $fh_unix
  }
}

proc xps_write_xsim_sim_cmdline { fh_unix dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars


  set args [list]
  lappend args "xsim"
  xps_append_config_opts args "xsim" "xsim"
  xps_append_more_options "xsim" "simulate" "xsim" args

  lappend args $a_sim_vars(s_top)
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

  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_unix "  if \[\[ (\$1 == \"-gen_bypass\") \]\]; then"
    puts $fh_unix "    #"
    puts $fh_unix "    # extract hierarchical information of the design in simulate.log file"
    puts $fh_unix "    #"
    set bypass_args $args
    lappend bypass_args "-testplusarg GEN_BYPASS"
    puts $fh_unix "    [join $bypass_args " "]"
    puts $fh_unix "  else"
    puts $fh_unix "    #"
    puts $fh_unix "    # launch hierarchical access simulation"
    puts $fh_unix "    #"
    puts $fh_unix "    [join $args " "]"
    puts $fh_unix "  fi"
  } else {
    puts $fh_unix "  [join $args " "]"
  }
}

proc xps_write_lib_var_for_xsim_simulate { fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  variable a_shared_library_path_coln

  # default Vivado install path
  set vivado_install_path $::env(XILINX_VIVADO)
 
  # custom Vivado install path set via VIVADO_LOC
  set custom_vivado_install_path ""
  if { [info exists ::env(VIVADO_LOC)] } {
    set custom_vivado_install_path $::env(VIVADO_LOC)
  }

  puts $fh_unix "# Set custom Vivado library path"
  # xv_ref_path for Vivado installation
  if { $a_sim_vars(b_ref_sysc_lib_env) } {
    puts $fh_unix "xv_ref_path=\$\{VIVADO_LOC:-\"\$XILINX_VIVADO\"\}"
  } else {
    puts $fh_unix "xv_ref_path=\$\{VIVADO_LOC:-\"$vivado_install_path\"\}"
  }

  # get the install path
  set install_path $vivado_install_path
  if { ($custom_vivado_install_path != "") && ([file exists $custom_vivado_install_path]) && ([file isdirectory $custom_vivado_install_path]) } {
    set install_path $custom_vivado_install_path
  }

  # construct sim-model library paths
  set libraries    [list]
  set sm_lib_paths [list]

  foreach {library lib_dir} [array get a_shared_library_path_coln] {
    lappend libraries $library
    set sm_lib_dir [file normalize $lib_dir]
    set sm_lib_dir [regsub -all {[\[\]]} $sm_lib_dir {/}]

    set match_string "/data/xsim/ip/"
    set b_processed_lib_path [xps_append_sm_lib_path sm_lib_paths $install_path $sm_lib_dir $match_string]
    if { !$b_processed_lib_path } {
      set match_string "/data/simmodels/xsim/"
      set b_processed_lib_path [xps_append_sm_lib_path sm_lib_paths $install_path $sm_lib_dir $match_string]
    }

    if { !$b_processed_lib_path } {
      lappend sm_lib_paths $sm_lib_dir
    }
  }

  set cxl_dirs [list]
  set clibs_dir [xps_get_lib_map_path "xsim"]
  foreach sm_path $sm_lib_paths {
    lappend l_sm_lib_paths $sm_path
    set b_resolved 0
    set resolved_path [xcs_resolve_sim_model_dir "xsim" $sm_path $clibs_dir $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved $a_sim_vars(b_compile_simmodels) "obj"]
    if { $b_resolved } {
      lappend cxl_dirs $resolved_path
    } else {
      lappend cxl_dirs $sm_path
    }
  }
  set sm_lib_path_str [join $cxl_dirs ":"]
  puts $fh_unix "xv_lib_path=\"\$xv_ref_path/lib/lnx64.o/Default:\$xv_ref_path/lib/lnx64.o\""
  puts $fh_unix "\nLD_LIBRARY_PATH=\$PWD:\$xv_lib_path:$sm_lib_path_str:\$LD_LIBRARY_PATH\n"
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

proc xps_write_xelab_cmdline { fh_unix launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  variable l_defines
  variable l_generics
  variable l_include_dirs
  variable l_compiled_libraries

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    set args [list]
    xps_get_simmodel_lib_opts_for_elab "xsim" $launch_dir args
    set args_str [join $args " "]
    puts $fh_unix "  xsc $args_str"
  }

  set args [list]
  xps_append_config_opts args "xsim" "xelab"
  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    xps_append_config_opts_sysc "xsim" $launch_dir args
  }
 
  xps_append_more_options "xsim" "elaborate" "xelab" args

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

  # TODO: coverage options
 
  # add user design libraries
  set design_libs [xcs_get_design_libs $a_sim_vars(l_design_files)]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend args "-L $lib"
  }

  # add uvm
  if { $a_sim_vars(b_contain_sv_srcs) } {
    lappend args "-L uvm"
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

  if { $a_sim_vars(b_contain_systemc_sources) } {
    set lib_extn ".dll"
    if {$::tcl_platform(platform) == "unix"} {
      set lib_extn ".so"
    }
    if {$::tcl_platform(platform) == "unix"} {
      lappend args "-sv_root \".\" -sc_lib libdpi${lib_extn}"
    }
  }

  lappend args "--snapshot $a_sim_vars(s_top)"

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
}

#
# modelsim_proc - Modelsim helper procs
#
namespace eval ::tclapp::xilinx::projutils {

proc xps_write_modelsim_sim_cmdline { fh_unix dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set s_64bit {}
  if { !$a_sim_vars(b_32bit) } {
    if {$::tcl_platform(platform) == "windows"} {
      # -64 not supported
    } else {
      set s_64bit {-64}
    }
  }
  set arg_list [list]
  set opts [string trim [join $arg_list " "]]
  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_unix "  if \[\[ (\$1 == \"-gen_bypass\") \]\]; then"
    puts $fh_unix "    #"
    puts $fh_unix "    # extract hierarchical information of the design in simulate.log file"
    puts $fh_unix "    #"
    set cmd_str "vsim $s_64bit $opts -c -do \"do \{simulate_hbs.do\}\" -l simulate.log"
    puts $fh_unix "    $cmd_str"
    puts $fh_unix "  else"
    puts $fh_unix "    #"
    puts $fh_unix "    # launch hierarchical access simulation"
    puts $fh_unix "    #"
    set cmd_str "vsim $s_64bit $opts -c -do \"do \{$a_sim_vars(do_filename)\}\" -l simulate.log"
    puts $fh_unix "    $cmd_str"
    puts $fh_unix "  fi"
  } else {
    set cmd_str "vsim $s_64bit $opts -c -do \"do \{$a_sim_vars(do_filename)\}\" -l simulate.log"
    puts $fh_unix "  $cmd_str"
  }
  xps_write_do_file_for_simulate "modelsim" $dir
}

proc xps_get_simulation_cmdline_modelsim { simulator {b_hier_access "false"} } {
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
      set opts [list]
      lappend opts "+acc"
      xps_append_more_options $simulator "elaborate" "vsim" opts
      set opts_str [join $opts " "]
      lappend args "-voptargs=\"$opts_str\""
      xps_append_more_options $simulator "simulate" "vsim" args
      if { $b_hier_access } {
        lappend args "+GEN_BYPASS"
      }
    }
    "riviera" -
    "activehdl" {
      xps_append_config_opts args $simulator "asim"
      lappend args "+access +r +m+$a_sim_vars(s_top)"
      xps_append_more_options $simulator "simulate" "asim" args
      if { $b_hier_access } {
        lappend args "+GEN_BYPASS"
      }
    }
  }

  if { [llength $l_generics] > 0 } {
    xps_append_generics $l_generics args
  }

  set t_opts [join $args " "]
  set args [list]

  # add user design libraries
  set design_libs [xcs_get_design_libs $a_sim_vars(l_design_files)]
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
}

#
# questa_proc - Questa helper procs
#
namespace eval ::tclapp::xilinx::projutils {

proc xps_write_questa_sim_cmdline { fh_unix dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set s_64bit {}
  if { !$a_sim_vars(b_32bit) } {
    if {$::tcl_platform(platform) == "windows"} {
      # -64 not supported
    } else {
      set s_64bit {-64}
    }
  }
  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_unix "  if \[\[ (\$1 == \"-gen_bypass\") \]\]; then"
    puts $fh_unix "    #"
    puts $fh_unix "    # extract hierarchical information of the design in simulate.log file"
    puts $fh_unix "    #"
    set cmd_str "vsim $s_64bit -c -do \"do \{simulate_hbs.do\}\" -l simulate.log"
    puts $fh_unix "    $cmd_str"
    puts $fh_unix "  else"
    puts $fh_unix "    #"
    puts $fh_unix "    # launch hierarchical access simulation"
    puts $fh_unix "    #"
    set cmd_str "vsim $s_64bit -c -do \"do \{$a_sim_vars(do_filename)\}\" -l simulate.log"
    puts $fh_unix "    $cmd_str"
    puts $fh_unix "  fi"
  } else {
    set args [list]
    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_contain_systemc_sources) } {
      lappend args "-cpppath \"$a_sim_vars(s_gcc_bin_path)/g++\""
    }
    set opts [join $args " "]
    set cmd_str "vsim $s_64bit $opts -c -do \"do \{$a_sim_vars(do_filename)\}\" -l simulate.log"
    puts $fh_unix "  $cmd_str"
  }
  xps_write_do_file_for_simulate "questa" $dir
}

proc xps_questa_get_sccom_cmd_args { clibs_dir args_opts } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  upvar $args_opts opts

  if {$::tcl_platform(platform) == "unix"} {
    lappend opts {-64}
  }

  lappend opts "-cpppath \"$a_sim_vars(s_gcc_bin_path)/g++\""
  xps_append_more_options "questa" "elaborate" "sccom" opts
  lappend opts "-link"

  set ip_obj [xcs_find_ip "ai_engine"]
  if { {} != $ip_obj } {
    lappend opts "-Wl,-u -Wl,_ZN5sc_dt12sc_concatref6m_poolE"
  }

  variable a_shared_library_path_coln
  foreach {key value} [array get a_shared_library_path_coln] {
    set sc_lib   $key
    set lib_path $value
    set lib_name [file root $sc_lib]
    set lib_name [string trimleft $lib_name {lib}]
    set lib_dir "$lib_path"

    if { ([xcs_is_c_library $lib_name]) || ([xcs_is_cpp_library $lib_name]) } {
      lappend opts "-L$lib_dir"
      lappend opts "-l$lib_name"
    } else {
      lappend opts "-lib $lib_name"
    }
  }
  lappend args "-lib $a_sim_vars(default_lib)"

  # bind IP static librarries
  set shared_ip_libs [xcs_get_shared_ip_libraries $clibs_dir]
  set uniq_shared_libs    [list]
  set shared_libs_to_link [list]

  foreach ip_obj [get_ips -all -quiet] {
    set ipdef [get_property -quiet IPDEF $ip_obj]
    set vlnv_name [xcs_get_library_vlnv_name $ip_obj $ipdef]
    set ssm_type [get_property -quiet selected_sim_model $ip_obj]
    if { [lsearch $shared_ip_libs $vlnv_name] != -1 } {
      if { [lsearch -exact $uniq_shared_libs $vlnv_name] == -1 } {
        if { ("tlm" == $ssm_type) } {
          # bind systemC library
          lappend shared_libs_to_link $vlnv_name
          lappend uniq_shared_libs $vlnv_name
        } else {
          # rtl, tlm_dpi (no binding)
        }
      }
    }
  }

  foreach vlnv_name $shared_libs_to_link {
    lappend opts "-lib $vlnv_name"
  }

  lappend opts "-work $a_sim_vars(default_lib)"
}

}

#
# ies_proc - IES helper procs
#
namespace eval ::tclapp::xilinx::projutils {

proc xps_write_ies_opt_args { fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set tool "irun"
  set arg_list [list]
  xps_append_config_opts arg_list "ies" $tool
  if { !$a_sim_vars(b_32bit) } {
    set arg_list [linsert $arg_list 0 "-64bit"]
  }

  puts $fh_unix "${tool}_opts=\"[join $arg_list " "]\""
  puts $fh_unix ""
}

proc xps_write_ies_sim_cmdline { fh_unix dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set tool "ncsim"
  set arg_list [list]
  lappend arg_list $tool
  xps_append_config_opts arg_list "ies" $tool

  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
  lappend arg_list "\$${tool}_opts" "${top_lib}.$a_sim_vars(s_top)" "-input" "$a_sim_vars(do_filename)"
  set cmd_str [join $arg_list " "]
  puts $fh_unix "  $cmd_str"
}

proc xps_write_single_step_for_ies { fh_unix launch_dir srcs_dir } {
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
    foreach lib [xcs_get_design_libs $a_sim_vars(l_design_files)] {
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
  set opts [list]
  if { [llength $l_defines] > 0 } {
    xps_append_define_generics $l_defines $tool_name "ies" opts
  }

  if { [llength $l_generics] > 0 } {
    xps_append_define_generics $l_generics $tool_name "ies" opts
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
    foreach dir [concat [xps_get_verilog_incl_dirs "ies" $launch_dir $prefix_ref_dir] [xps_get_verilog_incl_file_dirs "ies" $launch_dir $prefix_ref_dir] [xcs_get_vip_include_dirs]] {
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

  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_unix "  if \[\[ (\$1 == \"-gen_bypass\") \]\]; then"
    puts $fh_unix "    #"
    puts $fh_unix "    # extract hierarchical information of the design in simulate.log file"
    puts $fh_unix "    #"
    set bypass_args $arg_list
    lappend bypass_args "+GEN_BYPASS"
    set cmd_str [join $bypass_args " \\\n       "]
    puts $fh_unix "    ${tool_name} \$${tool_name}_opts \\"
    puts $fh_unix "       $cmd_str"
    puts $fh_unix "  else"
    puts $fh_unix "    #"
    puts $fh_unix "    # launch hierarchical access simulation"
    puts $fh_unix "    #"
    set cmd_str [join $arg_list " \\\n       "]
    puts $fh_unix "    ${tool_name} \$${tool_name}_opts \\"
    puts $fh_unix "       $cmd_str"
    puts $fh_unix "  fi"
  } else {
    set cmd_str [join $arg_list " \\\n       "]
    puts $fh_unix "  ${tool_name} \$${tool_name}_opts \\"
    puts $fh_unix "       $cmd_str"
  }

  set fh_run 0
  set file [file normalize "$launch_dir/$filename"]
  if { [catch {open $file w} fh_run] } {
    send_msg_id exportsim-Tcl-038 ERROR "failed to open file to write ($file)\n"
    return 1
  }

  set a_sim_vars(b_single_step) 1
  xps_write_compile_order_for_ies_xcelium_vcs "ies" $fh_run $launch_dir $srcs_dir
  set a_sim_vars(b_single_step) 0

  close $fh_run
  puts $fh_unix "\}\n"

  return 0
}
}

#
# xcelium_proc - Xcelium helper procs
#
namespace eval ::tclapp::xilinx::projutils {

proc xps_write_xcelium_opt_args { fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set tool "xrun"
  set arg_list [list]
  xps_append_config_opts arg_list "xcelium" $tool
  if { !$a_sim_vars(b_32bit) } {
    set arg_list [linsert $arg_list 0 "-64bit"]
  }

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_contain_systemc_sources) } {
    set arg_list [linsert $arg_list 1 "-sysc"]
  }

  #xps_append_more_options "xcelium" "compile" "xrun" arg_list

  puts $fh_unix "# Set ${tool} options"
  puts $fh_unix "${tool}_opts=\"[join $arg_list " "]\"\n"
  
  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_contain_systemc_sources) } {
    set opts "-nodep -gnu -gcc_vers 6.3"
    puts $fh_unix "# Set xmsc options"
    puts $fh_unix "xmsc_opts=\"$opts\"\n"

    set opts "-Wcxx,-std=c++11,-fPIC,-c,-Wall,-Wno-deprecated -D_GLIBCXX_USE_CXX11_ABI=0 -DSC_INCLUDE_DYNAMIC_PROCESSES"
    puts $fh_unix "# Set xmsc gcc options"
    puts $fh_unix "xmsc_gcc_opts=\"$opts\"\n"
  }
}

proc xps_write_xcelium_sim_cmdline { fh_unix dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set tool "xmsim"
  set arg_list [list]
  lappend arg_list $tool
  xps_append_config_opts arg_list "xcelium" $tool

  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_lib)]
  lappend arg_list "\$${tool}_opts" "${top_lib}.$a_sim_vars(s_top)" "-input" "$a_sim_vars(do_filename)"
  set cmd_str [join $arg_list " "]
  puts $fh_unix "  $cmd_str"
}

proc xps_write_single_step_for_xcelium { fh_unix launch_dir srcs_dir } {
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
    foreach lib [xcs_get_design_libs $a_sim_vars(l_design_files)] {
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

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    variable a_shared_library_path_coln
    foreach {library lib_dir} [array get a_shared_library_path_coln] {
      if { ("libprotobuf.so" == $library) && (!$b_bind_protobuf) } {
        # don't bind shared library but bind static library built with the simmodel itself
        continue
      }
      # don't bind static protobuf (simmodel will bind these during compilation)
      if { ("libprotobuf.a" == $library) } {
        continue;
      }
      set lib_name $library
      # fetch lib name only
      set lib_name [string trimleft $lib_name "lib"]
      set lib_name [string trimright $lib_name ".so"]
  
      set sm_lib_dir [file normalize $lib_dir]
      set sm_lib_dir [regsub -all {[\[\]]} $sm_lib_dir {/}]
      if { [regexp "^noc_v" $lib_name] || [regexp "^aie_cluster_v" $lib_name] } {
        set cmd_str "-L\$xv_cpt_lib_path/$lib_name -l${lib_name}"
      } else {
        set cmd_str "-L\$xv_cxl_lib_path/$lib_name -l${lib_name}"
      }
      lappend arg_list $cmd_str

      # append noc_base
      if { [regexp "^noc_v" $lib_name] } {
        set cmd_str "-L\$xv_cpt_lib_path/$lib_name -lnocbase_v1_0_0"
        lappend arg_list $cmd_str
      }
    }
  }

  set tool_name "xrun"
  set opts [list]
  if { [llength $l_defines] > 0 } {
    xps_append_define_generics $l_defines $tool_name "xcelium" opts
  }

  if { [llength $l_generics] > 0 } {
    xps_append_define_generics $l_generics $tool_name "xcelium" opts
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
    #set gfile "glbl.v"
    #if { $a_sim_vars(b_absolute_path) } {
    #  set gfile "\"$launch_dir/$gfile\""
    #}
    #lappend arg_list "$gfile"
  }
  
  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    lappend arg_list "-cpp_ext .cpp,.cxx"
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
    foreach dir [concat [xps_get_verilog_incl_dirs "xcelium" $launch_dir $prefix_ref_dir] [xps_get_verilog_incl_file_dirs "xcelium" $launch_dir $prefix_ref_dir] [xcs_get_vip_include_dirs]] {
      if { [lsearch -exact $uniq_dirs $dir] == -1 } {
        lappend uniq_dirs $dir
        lappend arg_list "+incdir+\"$dir\""
      }
    }
  }

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_contain_systemc_sources) } {
    lappend arg_list "-xmsc_runargs \"\$xmsc_opts\""
    lappend arg_list "-xmsc_runargs \"\$xmsc_gcc_opts\""
    
    set filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC Header\")"
    set prefix_ref_dir false

    set l_incl_dirs [list]
    foreach dir [xcs_get_c_incl_dirs "xcelium" $launch_dir $a_sim_vars(s_boost_dir) $filter $a_sim_vars(s_ip_user_files_dir) false $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
      lappend l_incl_dirs "$dir"
    }
 
    # reference SystemC include directories
    set clibs_dir [xps_get_lib_map_path "xcelium"]
    foreach {key value} [array get a_shared_library_path_coln] {
      set shared_lib_name $key
      set lib_path        $value
      set incl_dir "$lib_path/include"
      if { [file exists $incl_dir] } {
        if { !$a_sim_vars(b_absolute_path) } {
          set b_resolved 0
          set resolved_path [xcs_resolve_sim_model_dir "xcelium" $incl_dir $clibs_dir $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved $a_sim_vars(b_compile_simmodels) "include"]
          if { $b_resolved } {
            set incl_dir $resolved_path
          } else {
            set incl_dir "[xcs_get_relative_file_path $incl_dir $launch_dir]"
          }
        }
        lappend l_incl_dirs "$incl_dir"
      }
    }
  
    foreach incl_dir [get_property "SYSTEMC_INCLUDE_DIRS" $a_sim_vars(fs_obj)] {
      if { !$a_sim_vars(b_absolute_path) } {
        set incl_dir "[xcs_get_relative_file_path $incl_dir $launch_dir]"
      }
      lappend l_incl_dirs "$incl_dir"
    }
   
    if { [llength $l_incl_dirs] > 0 } {
      foreach incl_dir $l_incl_dirs {
        lappend arg_list "-xmsc_runargs \"-I$incl_dir\""
      }
    }
  }

  if { $a_sim_vars(b_runtime_specified) } {
    if { [xps_create_ixrun_do_file $launch_dir] } {
      lappend arg_list "-input $a_sim_vars(do_filename)"
    }
  }

  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_unix "  if \[\[ (\$1 == \"-gen_bypass\") \]\]; then"
    puts $fh_unix "    #"
    puts $fh_unix "    # extract hierarchical information of the design in simulate.log file"
    puts $fh_unix "    #"
    set bypass_args $arg_list
    lappend bypass_args "+GEN_BYPASS"
    set cmd_str [join $bypass_args " \\\n       "]
    puts $fh_unix "    ${tool_name} \$${tool_name}_opts \\"
    puts $fh_unix "       $cmd_str"
    puts $fh_unix "  else"
    puts $fh_unix "    #"
    puts $fh_unix "    # launch hierarchical access simulation"
    puts $fh_unix "    #"
    set cmd_str [join $arg_list " \\\n       "]
    puts $fh_unix "    ${tool_name} \$${tool_name}_opts \\"
    puts $fh_unix "       $cmd_str"
    puts $fh_unix "  fi"
  } else {
    set cmd_str [join $arg_list " \\\n       "]
    puts $fh_unix "  ${tool_name} \$${tool_name}_opts \\"
    puts $fh_unix "       $cmd_str"
  }

  set fh_run 0
  set file [file normalize "$launch_dir/$filename"]
  if { [catch {open $file w} fh_run] } {
    send_msg_id exportsim-Tcl-038 ERROR "failed to open file to write ($file)\n"
    return 1
  }

  set a_sim_vars(b_single_step) 1
  xps_write_compile_order_for_ies_xcelium_vcs "xcelium" $fh_run $launch_dir $srcs_dir
  set a_sim_vars(b_single_step) 0

  close $fh_run
  puts $fh_unix "\}\n"

  return 0
}
}

#
# vcs_proc - VCS helper procs
#
namespace eval ::tclapp::xilinx::projutils {

proc xps_write_vcs_opt_args { fh_unix launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    puts $fh_unix "# Set gcc install path"
    puts $fh_unix "gcc_path=\"$a_sim_vars(s_gcc_bin_path)\""
    puts $fh_unix "sys_path=\"$a_sim_vars(s_sys_link_path)\"\n"

    set lmp [xps_get_lib_map_path "vcs"]
    puts $fh_unix "# Set system shared library paths"
    puts $fh_unix "xv_cxl_lib_path=\"$lmp\""
    puts $fh_unix "xv_cpt_lib_path=\"$a_sim_vars(sp_cpt_dir)\""
    puts $fh_unix "xv_ext_lib_path=\"$a_sim_vars(sp_ext_dir)\""
    puts $fh_unix "xv_boost_lib_path=\"$a_sim_vars(s_boost_dir)\"\n"
  }

  set arg_list [list]
  xps_append_config_opts arg_list "vcs" "vlogan"
  if { !$a_sim_vars(b_32bit) } {
    set arg_list [linsert $arg_list 0 "-full64"]
    if { $a_sim_vars(b_int_systemc_mode) } {
      if { $a_sim_vars(b_system_sim_design) } {
        lappend arg_list "-sysc"
      }
    }
  }
  xps_append_more_options "vcs" "compile" "vlogan" arg_list
  
  puts $fh_unix "# Set vlogan compile options"
  puts $fh_unix "vlogan_opts=\"[join $arg_list " "]\"\n"

  set arg_list [list]
  xps_append_config_opts arg_list "vcs" "vhdlan"
  if { !$a_sim_vars(b_32bit) } {
    set arg_list [linsert $arg_list 0 "-full64"]
  }
  xps_append_more_options "vcs" "compile" "vhdlan" arg_list
  puts $fh_unix "# Set vhdlan compile options"
  puts $fh_unix "vhdlan_opts=\"[join $arg_list " "]\"\n"

  set arg_list [list]
  xps_append_config_opts arg_list "vcs" "vcs"

  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      lappend arg_list "-sysc=232"
      lappend arg_list "-cpp \$\{gcc_path\}/g++"
    }
  }

  set arg_list [linsert $arg_list end "-debug_acc+pp+dmptf"]
  set arg_list [linsert $arg_list end "-t" "ps" "-licqueue" "-l" "elaborate.log"]
  if { !$a_sim_vars(b_32bit) } {
    set arg_list [linsert $arg_list 0 "-full64"]
  }

  set arg_list [list]
  xps_append_config_opts arg_list "vcs" "vcs"

  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      lappend arg_list "-sysc=232"
      lappend arg_list "-cpp \$\{gcc_path\}/g++"
    }
  }

  set arg_list [linsert $arg_list end "-debug_acc+pp+dmptf"]
  set arg_list [linsert $arg_list end "-t" "ps" "-licqueue" "-l" "elaborate.log"]
  if { !$a_sim_vars(b_32bit) } {
    set arg_list [linsert $arg_list 0 "-full64"]
  }

  if { $a_sim_vars(b_int_systemc_mode) } {
    if { $a_sim_vars(b_system_sim_design) } {
      set lmp [xps_get_lib_map_path "vcs"]
      variable a_shared_library_path_coln
      # bind protected libraries
      set cpt_dir [rdi::get_data_dir -quiet -datafile "simmodels/vcs"]
      set sm_cpt_dir [xcs_get_simmodel_dir "vcs" $a_sim_vars(s_gcc_version) "cpt"]
      foreach {key value} [array get a_shared_library_path_coln] {
        set name [file tail $value]
        set lib_dir "$cpt_dir/$sm_cpt_dir/$name"
        if { [regexp "^noc_v" $name] } {
          set arg_list [linsert $arg_list end "$lib_dir/lib${name}.so"]
          set arg_list [linsert $arg_list end "$lib_dir/libnocbase_v1_0_0.a"]
        }
        if { ([regexp "^aie_cluster" $name]) || ([regexp "^aie_xtlm" $name]) } {
          set lib_dir "$cpt_dir/$sm_cpt_dir/aie_cluster_v1_0_0"
          # 1080663 - bind with aie_xtlm_v1_0_0 during compile time
          # TODO: find way to make this data-driven
          set arg_list [linsert $arg_list end "-L$lib_dir"]
          set arg_list [linsert $arg_list end "-laie_cluster_v1_0_0"]
        }
      }

      foreach {key value} [array get a_shared_library_path_coln] {
        set shared_lib_name $key
        set shared_lib_name [file root $shared_lib_name]
        set shared_lib_name [string trimleft $shared_lib_name "lib"]

        set sm_lib_dir [file normalize $value]
        set sm_lib_dir [regsub -all {[\[\]]} $sm_lib_dir {/}]

        #if { [regexp "^protobuf" $shared_lib_name] } { continue; }
        if { [regexp "^noc_v" $shared_lib_name] } { continue; }
        if { [regexp "^aie_xtlm_" $shared_lib_name] } {
          set aie_lib_dir "$cpt_dir/$sm_cpt_dir/aie_cluster_v1_0_0"
          # 1080663 - bind with aie_xtlm_v1_0_0 during compile time
          # TODO: find way to make this data-driven
          set arg_list [linsert $arg_list end "-Mlib=$aie_lib_dir"]
          set arg_list [linsert $arg_list end "-Mdir=$a_sim_vars(tmp_obj_dir)/_xil_csrc_"]
        }
        if { [xcs_is_sc_library $shared_lib_name] } {
          set arg_list [linsert $arg_list end "-Mlib=$sm_lib_dir"]
          set arg_list [linsert $arg_list end "-Mdir=$a_sim_vars(tmp_obj_dir)/_xil_csrc_"]
        } else {
          set arg_list [linsert $arg_list end "-L$sm_lib_dir -l$shared_lib_name"]
        }
      }

      # link IP design libraries
      set shared_ip_libs [xcs_get_shared_ip_libraries $lmp]
      set ip_objs [get_ips -all -quiet]
      if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
        puts "------------------------------------------------------------------------------------------------------------------------------------"
        puts "Referenced pre-compiled shared libraries"
        puts "------------------------------------------------------------------------------------------------------------------------------------"
      }
      set uniq_shared_libs        [list]
      set shared_lib_objs_to_link [list]
      foreach ip_obj $ip_objs {
        set ipdef [get_property -quiet IPDEF $ip_obj]
        set vlnv_name [xcs_get_library_vlnv_name $ip_obj $ipdef]
        if { [lsearch $shared_ip_libs $vlnv_name] != -1 } {
          if { [lsearch -exact $uniq_shared_libs $vlnv_name] == -1 } {
            lappend uniq_shared_libs $vlnv_name
            if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
              puts "(shared object) '$a_sim_vars(s_clibs_dir)/$vlnv_name'"
            }
            foreach obj_file_name [xcs_get_pre_compiled_shared_objects "vcs" $lmp $vlnv_name] {
              if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
                puts " + linking $vlnv_name -> '$obj_file_name'"
              }
              lappend shared_lib_objs_to_link "$obj_file_name"
            }
          }
        }
      }

      foreach shared_lib_obj $shared_lib_objs_to_link {
        set arg_list [linsert $arg_list end "$shared_lib_obj"]
      }
      if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
        puts "------------------------------------------------------------------------------------------------------------------------------------"
      }

      set arg_list [linsert $arg_list end "-Mdir=c.obj"]
      set arg_list [linsert $arg_list end "-lstdc++fs"]
    }
    xps_append_more_options "vcs" "elaborate" "vcs" arg_list

    #puts $fh_scr "# set gcc objects"
    set objs_arg [list]
    set uniq_objs [list]

    variable a_design_c_files_coln
    foreach {key value} [array get a_design_c_files_coln] {
      set c_file     $key
      set file_type  $value
      set file_name [file tail [file root $c_file]]
      append file_name ".o"
      if { [lsearch -exact $uniq_objs $file_name] == -1 } {
        lappend objs_arg "$a_sim_vars(tmp_obj_dir)/sysc/$file_name"
        lappend uniq_objs $file_name
      }
    }
    set objs_arg_str [join $objs_arg " "]
    #puts $fh_scr "gcc_objs=\"$objs_arg_str\"\n"
  }
  puts $fh_unix "# Set vcs elaboration options"
  puts $fh_unix "vcs_elab_opts=\"[join $arg_list " "]\"\n"

  set arg_list [list]
  xps_append_config_opts arg_list "vcs" "simv"
  lappend arg_list "-ucli" "-licqueue" "-l" "simulate.log"
  xps_append_more_options "vcs" "simulate" "vcs" arg_list
  puts $fh_unix "# Set vcs simulation options"
  puts $fh_unix "vcs_sim_opts=\"[join $arg_list " "]\"\n"

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    if { $a_sim_vars(b_contain_systemc_sources) } {
      set tool "syscan"
      set arg_list [list]
      lappend arg_list "-sysc=232"
      lappend arg_list "-sysc=opt_if"
      lappend arg_list "-cpp \${gcc_path}/g++"
      lappend arg_list "-V"
      lappend arg_list "-l ${tool}.log"
      if { !$a_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-full64"]
      }
      xps_append_more_options "vcs" "compile" "syscan" arg_list
      puts $fh_unix "# Set ${tool} options"
      puts $fh_unix "syscan_opts=\"[join $arg_list " "]\"\n"
    }

    if { $a_sim_vars(b_contain_cpp_sources) } {
      set tool "g++"
      set arg_list [list "-c -fPIC -O3 -std=c++11 -DCOMMON_CPP_DLL"]
      if { $a_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-m32"]
      } else {
        set arg_list [linsert $arg_list 0 "-m64"]
      }
      xps_append_more_options "vcs" "compile" "g++" arg_list
      puts $fh_unix "\n# Set ${tool} options"
      puts $fh_unix "gpp_opts=\"[join $arg_list " "]\"\n"
    }

    if { $a_sim_vars(b_contain_cpp_sources) } {
      set tool "gcc"
      set arg_list [list "-c -fPIC -O3"]
      if { $a_sim_vars(b_32bit) } {
        set arg_list [linsert $arg_list 0 "-m32"]
      } else {
        set arg_list [linsert $arg_list 0 "-m64"]
      }
      xps_append_more_options "vcs" "compile" "gcc" arg_list
      puts $fh_unix "\n# Set ${tool} options"
      puts $fh_unix "gcc_opts=\"[join $arg_list " "]\"\n"
    }
   
    set args [list]
    lappend args "-I."
    lappend args "-I\$\{VCS_HOME\}/include/systemc232"
    lappend args "-I\$\{VCS_HOME\}/include"
    lappend args "-I\$\{VCS_HOME\}/include/cosim/bf"
    lappend args "-DVCSSYSTEMC=1"

    variable l_system_sim_incl_dirs
    set uniq_dirs [list]
    foreach dir $l_system_sim_incl_dirs {
      if { [lsearch -exact $uniq_dirs $dir] == -1 } {
        lappend uniq_dirs $dir
        lappend args "-I$dir"
      }
    }

    # reference simmodel shared library include directories
    variable a_shared_library_path_coln
    set l_sim_model_incl_dirs [list]
    set clibs_dir $lmp

    foreach {key value} [array get a_shared_library_path_coln] {
      set shared_lib_name $key
      set lib_path        $value
      set sim_model_incl_dir "$lib_path/include"
      if { [file exists $sim_model_incl_dir] } {
        if { !$a_sim_vars(b_absolute_path) } {
          # relative path
          set b_resolved 0
          set resolved_path [xcs_resolve_sim_model_dir "vcs" $sim_model_incl_dir $clibs_dir $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved false ""]
          if { $b_resolved } {
            set sim_model_incl_dir $resolved_path
          } else {
            set sim_model_incl_dir "[xcs_get_relative_file_path $sim_model_incl_dir $launch_dir]"
          }
        }
        lappend l_sim_model_incl_dirs $sim_model_incl_dir
      }
    }

    # simset include dir
    foreach incl_dir [get_property "SYSTEMC_INCLUDE_DIRS" $a_sim_vars(fs_obj)] {
      if { !$a_sim_vars(b_absolute_path) } {
        set incl_dir "[xcs_get_relative_file_path $incl_dir $launch_dir]"
      }
      lappend l_sim_model_incl_dirs "$incl_dir"
    }

    if { [llength $l_sim_model_incl_dirs] > 0 } {
      # save system incl dirs
      variable l_systemc_incl_dirs
      set l_systemc_incl_dirs $l_sim_model_incl_dirs

      # append to gcc options
      foreach incl_dir $l_sim_model_incl_dirs {
        lappend args "-I$incl_dir"
      }
    }
    set gcc_opts_str [join $args " "]
    puts $fh_unix "# Set syscan gcc options"
    puts $fh_unix "syscan_gcc_opts=\"$gcc_opts_str\"\n"
  }
}

proc xps_write_vcs_sim_cmdline { fh_unix dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_unix "  if \[\[ (\$1 == \"-gen_bypass\") \]\]; then"
    puts $fh_unix "    #"
    puts $fh_unix "    # extract hierarchical information of the design in simulate.log file"
    puts $fh_unix "    #"
    set arg_list [list "./$a_sim_vars(s_top)_simv" "\$vcs_sim_opts" "+GEN_BYPASS" "-do" "$a_sim_vars(do_filename)"]
    set cmd_str [join $arg_list " "]
    puts $fh_unix "    $cmd_str"
    puts $fh_unix "  else"
    puts $fh_unix "    #"
    puts $fh_unix "    # launch hierarchical access simulation"
    puts $fh_unix "    #"
    set arg_list [list "./$a_sim_vars(s_top)_simv" "\$vcs_sim_opts" "-do" "$a_sim_vars(do_filename)"]
    set cmd_str [join $arg_list " "]
    puts $fh_unix "    $cmd_str"
    puts $fh_unix "  fi"
  } else {
    set arg_list [list "./$a_sim_vars(s_top)_simv" "\$vcs_sim_opts" "-do" "$a_sim_vars(do_filename)"]
    set cmd_str [join $arg_list " "]
    puts $fh_unix "  $cmd_str"
  }
}
}

#
# riviera_proc - Riviera helper procs
#
namespace eval ::tclapp::xilinx::projutils {

proc xps_write_riviera_sim_cmdline { fh_unix dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_unix "  if \[\[ (\$1 == \"-gen_bypass\") \]\]; then"
    puts $fh_unix "    #"
    puts $fh_unix "    # extract hierarchical information of the design in simulate.log file"
    puts $fh_unix "    #"
    set cmd_str "runvsimsa -l simulate.log -do \"do \{simulate_hbs.do\}\""
    puts $fh_unix "    $cmd_str"
    puts $fh_unix "  else"
    puts $fh_unix "    #"
    puts $fh_unix "    # launch hierarchical access simulation"
    puts $fh_unix "    #"
    set cmd_str "runvsimsa -l simulate.log -do \"do \{$a_sim_vars(do_filename)\}\""
    puts $fh_unix "    $cmd_str"
    puts $fh_unix "  fi"
  } else {
    set cmd_str "runvsimsa -l simulate.log -do \"do \{$a_sim_vars(do_filename)\}\""
    puts $fh_unix "  $cmd_str"
  }
  xps_write_do_file_for_simulate "riviera" $dir
}
}

#
# activehdl_proc - Activehdl helper procs
#
namespace eval ::tclapp::xilinx::projutils {

proc xps_write_activehdl_sim_cmdline { fh_unix dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { $a_sim_vars(b_generate_hier_access) } {
    puts $fh_unix "  if \[\[ (\$1 == \"-gen_bypass\") \]\]; then"
    puts $fh_unix "    #"
    puts $fh_unix "    # extract hierarchical information of the design in simulate.log file"
    puts $fh_unix "    #"
    set cmd_str "runvsimsa -l simulate.log -do \"do \{simulate_hbs.do\}\""
    puts $fh_unix "    $cmd_str"
    puts $fh_unix "  else"
    puts $fh_unix "    #"
    puts $fh_unix "    # launch hierarchical access simulation"
    puts $fh_unix "    #"
    set cmd_str "runvsimsa -l simulate.log -do \"do \{$a_sim_vars(do_filename)\}\""
    puts $fh_unix "    $cmd_str"
    puts $fh_unix "  fi"
  } else {
    set cmd_str "runvsimsa -l simulate.log -do \"do \{$a_sim_vars(do_filename)\}\""
    puts $fh_unix "  $cmd_str"
  }
  xps_write_do_file_for_simulate "activehdl" $dir
}
}

#
# common_proc - Common simulator helper procs
#
namespace eval ::tclapp::xilinx::projutils {

proc xps_append_more_options { simulator step tool arg_list_var } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_more_options
  upvar $arg_list_var arg_list
 
  if { $a_sim_vars(b_more_options_specified) } {
    foreach opt_spec $l_more_options {
      # {questa.elaborate.vopt:-L xpm, -timescale 1ps/1ps}
      set opt_arg_values [split $opt_spec {:}]

      # questa.elaborate.vopt
      set step_spec [lindex $opt_arg_values 0]
      set step_values [split $step_spec {.}]

      set sim_name  [lindex $step_values 0] ;# questa
      set step_name [lindex $step_values 1] ;# elaborate
      set tool_name [lindex $step_values 2] ;# vopt

      if { ($simulator == $sim_name) && ($step == $step_name) && ($tool == $tool_name) } {
        # -L xpm, -timescale 1ps/1ps
        set switch_names [split [lindex $opt_arg_values 1] {,}]
        foreach sw_spec $switch_names {
          set sw_spec [string trim $sw_spec]
          lappend arg_list $sw_spec
        }
      }
    }
  }
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
      puts $fh_unix "# Set the compiled library directory path"
      puts $fh_unix "ref_lib_dir=\"$cds_lmp\"\n"

      if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
        puts $fh_unix "# Set system shared library paths"
        puts $fh_unix "xv_cxl_lib_path=\"$lmp\""
        puts $fh_unix "xv_cpt_lib_path=\"$a_sim_vars(sp_cpt_dir)\""
        puts $fh_unix "xv_ext_lib_path=\"$a_sim_vars(sp_ext_dir)\""
        puts $fh_unix "xv_boost_lib_path=\"$a_sim_vars(s_boost_dir)\"\n"
      }
    }
  }
}

proc xps_append_config_opts { opts_arg simulator tool } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts

  set opts_str {}
  switch -exact -- $simulator {
    "xsim" {
      if {"xvlog" == $tool} {set opts_str "--incr --relax"}
      if {"xvhdl" == $tool} {set opts_str "--incr --relax"}
      if {"xsc"   == $tool} {set opts_str ""}
      if {"xelab" == $tool} {set opts_str "--incr --debug typical --relax --mt auto"}
      if {"xsim"  == $tool} {set opts_str ""}
    }
    "modelsim" {
      if {"vlog" == $tool} {set opts_str "-incr -mfcu"}
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
      if {"vlog"     == $tool} {set opts_str "-incr -mfcu"}
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

proc xps_get_files_to_remove { simulator file_list_arg file_dir_list_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $file_list_arg file_list
  upvar $file_dir_list_arg file_dir_list

  variable a_sim_vars
  set top $a_sim_vars(s_top)

  switch -regexp -- $simulator {
    "xsim" {
      set file_list     [list "xelab.pb" "xsim.jou" "xvhdl.log" "xvlog.log" "compile.log" "elaborate.log" "simulate.log" \
                              "xelab.log" "xsim.log" "run.log" "xvhdl.pb" "xvlog.pb" "${top}.wdb"]
      set file_dir_list [list "xsim.dir"]
    }
    "modelsim" {
      set file_list     [list "compile.log" "elaborate.log" "simulate.log" "vsim.wlf"]
      set file_dir_list [list "modelsim_lib"]
    }
    "questa" {
      set file_list     [list "compile.log" "elaborate.log" "simulate.log" "vsim.wlf"]
      set file_dir_list [list "questa_lib"]
    }
    "ies" { 
      set file_list     [list "ncsim.key" "irun.key" "irun.log" "waves.shm" "irun.history" ".simvision"]
      set file_dir_list [list "INCA_libs"]
    }
    "xcelium" { 
      set file_list     [list "xmsim.key" "xrun.key" "xrun.log" "waves.shm" "xrun.history" ".simvision"]
      set file_dir_list [list "xcelium.d" "xcelium"]
    }
    "vcs" {
      set file_list     [list "ucli.key" "${top}_simv" "vlogan.log" "vhdlan.log" "compile.log" "elaborate.log" "simulate.log" \
                              ".vlogansetup.env" ".vlogansetup.args" ".vcs_lib_lock" "scirocco_command.log"]
      set file_dir_list [list "64" "AN.DB" "csrc" "${top}_simv.daidir"]
    }
    "riviera" {
      set file_list     [list "compile.log" "elaboration.log" "simulate.log" "dataset.asdb"]
      set file_dir_list [list "work" "riviera"]
    }
    "activehdl" {
      set file_list     [list "compile.log" "elaboration.log" "simulate.log" "dataset.asdb"]
      set file_dir_list [list "work" "activehdl"]
    }
  }
}

proc xps_set_gcc_version_path { simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  # TODO: support for -gcc_version
  switch -regexp -- $simulator {
    "xsim" {
      set gcc_type {}
      set a_sim_vars(s_gcc_version) [xcs_get_gcc_version $simulator $a_sim_vars(s_gcc_version) gcc_type $a_sim_vars(b_int_sm_lib_ref_debug)]
      switch $gcc_type {
        1 { send_msg_id exportsim-Tcl-074 INFO "Using GCC version '$a_sim_vars(s_gcc_version)'"                             }
      }
    }
    "questa" {
      set gcc_type {}
      set a_sim_vars(s_gcc_version) [xcs_get_gcc_version $simulator $a_sim_vars(s_gcc_version) gcc_type $a_sim_vars(b_int_sm_lib_ref_debug)]
      switch $gcc_type {
        1 { send_msg_id exportsim-Tcl-074 INFO "Using GCC version '$a_sim_vars(s_gcc_version)'"                             }
      }
    }
    "xcelium" {
      set gcc_type {}
      set a_sim_vars(s_gcc_version) [xcs_get_gcc_version $simulator $a_sim_vars(s_gcc_version) gcc_type $a_sim_vars(b_int_sm_lib_ref_debug)]
      switch $gcc_type {
        1 { send_msg_id exportsim-Tcl-074 INFO "Using GCC version '$a_sim_vars(s_gcc_version)'"                             }
      }

      set xm_root {}
      [catch {set xm_root [exec xmroot]} error]
      if { {} == $xm_root } {
        set path_sep  {:}
        set tool_name "xmsim"
        set bin_path [xcs_get_bin_path $tool_name $path_sep]
        set xm_root [join [lrange [split $bin_path "/"] 0 end-3] "/"]
      }
      set sys_link "$xm_root/tools/systemc/lib/64bit/gnu"
      if { ![file exists $sys_link] } {
        send_msg_id exportsim-Tcl-075 INFO "The Xcelium GNU executables could not be located. Please check if the simulator is installed correctly.\n"
      }

      set a_sim_vars(s_sys_link_path) "$sys_link"
      send_msg_id exportsim-Tcl-076 INFO "Simulator systemC library path set to '$a_sim_vars(s_sys_link_path)'\n"
    }
    "vcs" {
      set gcc_type {}
      set a_sim_vars(s_gcc_version) [xcs_get_gcc_version $simulator $a_sim_vars(s_gcc_version) gcc_type $a_sim_vars(b_int_sm_lib_ref_debug)]
      switch $gcc_type {
        1 { send_msg_id exportsim-Tcl-074 INFO "Using GCC version '$a_sim_vars(s_gcc_version)'"                             }
      }

      # set vcs system library
      set sys_link ""
      if { [info exists ::env(VG_GNU_PACKAGE)] } {
        set sys_link "$::env(VG_GNU_PACKAGE)/gcc-$a_sim_vars(s_gcc_version)"
      }

      if { ![file exists $sys_link] } {
        # if not found from GNU package, find from VCS_HOME
        if { [info exists ::env(VCS_HOME)] } {
          set sys_link "$::env(VCS_HOME)/gnu/linux/gcc-64"
        }
        if { ![file exists $sys_link] } {
          send_msg_id exportsim-Tcl-075 INFO "The VCS GNU executables could not be located. Please check if the simulator is installed correctly.\n"
        }
      }

      set a_sim_vars(s_sys_link_path) "$sys_link"
      send_msg_id exportsim-Tcl-076 INFO "Simulator systemC library path set to '$a_sim_vars(s_sys_link_path)'\n"
    }
  }
}

proc xps_resolve_sysc_lib_path { type lib_path } { 
  # Summary:
  # Argument Usage:
  # Return Value:

  set resolved_path $lib_path

  # forward slash
  set lib_path   [string map {\\ /} $lib_path]
  set sub_dirs   [split $lib_path {/}]

  # data path
  set data_index [lsearch -exact $sub_dirs "data"]
  set data_path  [join [lrange $sub_dirs $data_index end] "/"]

  # tps path
  set data_index [lsearch -exact $sub_dirs "tps"]
  set tps_path   [join [lrange $sub_dirs $data_index end] "/"]

  switch $type {
    {CLIBS} {
      set resolved_path "\$XILINX_VIVADO/$data_path"
    }
    {SPCPT} -
    {SPEXT} {
      set resolved_path "\$XILINX_VIVADO/$data_path"
    }
    {BOOST} {
      set resolved_path "\$XILINX_VIVADO/$tps_path"
    }
    default {
      send_msg_id exportsim-Tcl-075 INFO "unknown systemc pre-compiled library path: '$type'!"
    }
  }
  return $resolved_path
}

proc xps_get_sc_compile_options { simulator compiler launch_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set arg_list [list]
  xps_append_config_opts arg_list $simulator $compiler
  lappend arg_list "--gcc_compile_options \"-DBOOST_SYSTEM_NO_DEPRECATED\""

  set filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC Header\")"
  set prefix_ref_dir false

  set l_incl_dirs [list]
  foreach dir [xcs_get_c_incl_dirs $simulator $launch_dir $a_sim_vars(s_boost_dir) $filter $a_sim_vars(s_ip_user_files_dir) false $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
    lappend l_incl_dirs "$dir"
  }
 
  # reference SystemC include directories
  set b_en_code true
  if { $b_en_code } {
    set clibs_dir [xps_get_lib_map_path $simulator]
    variable a_shared_library_path_coln
    foreach {key value} [array get a_shared_library_path_coln] {
      set shared_lib_name $key
      set lib_path        $value
      set incl_dir "$lib_path/include"
      if { [file exists $incl_dir] } {
        if { !$a_sim_vars(b_absolute_path) } {
          set b_resolved 0
          set resolved_path [xcs_resolve_sim_model_dir $simulator $incl_dir $clibs_dir $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved $a_sim_vars(b_compile_simmodels) "include"]
          if { $b_resolved } {
            set incl_dir $resolved_path
          } else {
            set incl_dir "[xcs_get_relative_file_path $incl_dir $launch_dir]"
          }
        }
        lappend l_incl_dirs "$incl_dir"
      }
    }

    foreach incl_dir [get_property "SYSTEMC_INCLUDE_DIRS" $a_sim_vars(fs_obj)] {
      if { !$a_sim_vars(b_absolute_path) } {
        set incl_dir "[xcs_get_relative_file_path $incl_dir $launch_dir]"
      }
      lappend l_incl_dirs "$incl_dir"
    }
  }

  variable l_systemc_incl_dirs
  set l_systemc_incl_dirs $l_incl_dirs

  set sc_filename "xsc.prj"
  if { [llength $l_incl_dirs] > 0 } {
    lappend arg_list "--gcc_compile_options"
    set incl_dir_strs [list]
    foreach incl_dir $l_incl_dirs {
      lappend incl_dir_strs "-I$incl_dir"
    }
    set incl_dir_cmd_str [join $incl_dir_strs " "]
    lappend arg_list "\"$incl_dir_cmd_str\""
  }

  lappend arg_list "-work $a_sim_vars(default_lib)"
  set xsc_opts [join $arg_list " "]
  return $xsc_opts
}

proc xps_append_sm_lib_path { sm_lib_paths_arg install_path sm_lib_dir match_string } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $sm_lib_paths_arg sm_lib_paths

  if { [regexp -nocase $match_string $sm_lib_dir] } {
    # find location of the sub-string directory path from simulation model library dir
    set index [string first $match_string $sm_lib_dir]
    if { $index == -1 } {
      return false
    }

    # find last part of the directory structure starting from this index
    set file_path_str [string range $sm_lib_dir $index end]

    # check if simulation model sub-directory exist from install path. The install path could be workspace
    # where the directory may not exist, in which case fall back to default library path.
    
    # default library path
    set ref_dir $sm_lib_dir

    # install path (if exist)
    set path_to_consider "$install_path$file_path_str"
    if { ([file exists $path_to_consider]) && ([file isdirectory $path_to_consider]) } {
      set ref_dir "\$xv_ref_path$file_path_str"
    }
    lappend sm_lib_paths $ref_dir

    return true
  }
  return false
}

proc xps_get_simmodel_lib_opts_for_elab { simulator launch_dir opts_args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  upvar $opts_args opts

  set lib_extn ".dll"
  if {$::tcl_platform(platform) == "unix"} {
    set lib_extn ".so"
    lappend opts "--shared"
  } else {
    lappend opts "--shared_systemc"
  }
  xps_append_more_options "xsim" "elaborate" "xsc" opts
  lappend opts "-lib $a_sim_vars(default_lib)" 

  set clibs_dir [xps_get_lib_map_path $simulator]
  set shared_ip_libs [xcs_get_shared_ip_libraries $clibs_dir]
  set ip_objs [get_ips -all -quiet]

  if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
    puts "------------------------------------------------------------------------------------------------------------------------------------"
    puts "Referenced pre-compiled shared libraries"
    puts "------------------------------------------------------------------------------------------------------------------------------------"
  }

  set uniq_shared_libs    [list]
  set shared_libs_to_link [list]
  foreach ip_obj $ip_objs {
    set ipdef [get_property -quiet IPDEF $ip_obj]
    set vlnv_name [xcs_get_library_vlnv_name $ip_obj $ipdef]
    set ssm_type [get_property -quiet selected_sim_model $ip_obj]
    if { [lsearch $shared_ip_libs $vlnv_name] != -1 } {
      if { [lsearch -exact $uniq_shared_libs $vlnv_name] == -1 } {
        if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
          puts " IP - $ip_obj ($vlnv_name) - SELECTED_SIM_MODEL=$ssm_type"
        }
        if { ("tlm" == $ssm_type) } {
          lappend shared_libs_to_link $vlnv_name
          lappend uniq_shared_libs $vlnv_name
          if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
            puts "      (BIND)-> $clibs_dir/$vlnv_name"
          }
        } else {
          if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
            puts "      (SKIP)-> $clibs_dir/$vlnv_name"
          }
        }
      }
    }
  }

  foreach vlnv_name $shared_libs_to_link {
    lappend opts "-lib $vlnv_name"
  }

  if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
    puts "------------------------------------------------------------------------------------------------------------------------------------"
  }

  set b_en_code true
  if { $b_en_code } {
    set b_bind_shared_lib 0
    [catch {set b_bind_shared_lib [get_param project.bindSharedLibraryForXSCElab]} err]
    if { $b_bind_shared_lib } {
      variable a_shared_library_path_coln
      foreach {key value} [array get a_shared_library_path_coln] {
        set shared_lib_name $key
        set lib_path        $value
        set lib_name        [file root $shared_lib_name]
        set lib_name        [string trimleft $lib_name {lib}]

        set b_resolved 0
        set rel_lib_path {}
        set resolved_path [xcs_resolve_sim_model_dir $simulator $lib_path $clibs_dir $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved $a_sim_vars(b_compile_simmodels) "obj"]
        if { $b_resolved } {
          set rel_lib_path $resolved_path
        } else {
          set rel_lib_path [xcs_get_relative_file_path $lib_path $launch_dir]
        }

        set sc_opts "-gcc_link_options \"-L$rel_lib_path -l${lib_name}\""
        lappend opts $sc_opts
      }
    }
  }

  lappend opts "-o libdpi${lib_extn}" 
}

proc xps_append_config_opts_sysc { simulator launch_dir opts_args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  upvar $opts_args opts

  set clibs_dir [xps_get_lib_map_path $simulator]
  set lib_extn ".dll"
  if {$::tcl_platform(platform) == "unix"} {
    set lib_extn ".so"
  }

  set unique_sysc_incl_dirs [list]
  variable a_shared_library_path_coln
  foreach {key value} [array get a_shared_library_path_coln] {
    set shared_lib_name $key
    set lib_path        $value
    set lib_name        [file root $shared_lib_name]

    # relative path to library include dir
    set incl_dir "$lib_path/include"
    set b_resolved 0
    set resolved_path [xcs_resolve_sim_model_dir $simulator $incl_dir $clibs_dir $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved $a_sim_vars(b_compile_simmodels) "include"]
    if { $b_resolved } {
      set incl_dir $resolved_path
    } else {
      set incl_dir "[xcs_get_relative_file_path $incl_dir $launch_dir]"
    }

    if { [lsearch -exact $unique_sysc_incl_dirs $incl_dir] == -1 } {
      lappend unique_sysc_incl_dirs $incl_dir
    }

    # is clibs, protected or ext dir? replace with variable
    set b_resolved 0
    set resolved_path [xcs_resolve_sim_model_dir $simulator $lib_path $clibs_dir $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved $a_sim_vars(b_compile_simmodels) "obj"]
    if { $b_resolved } {
      set rel_lib_path $resolved_path
    } else {
      set rel_lib_path  "[xcs_get_relative_file_path $lib_path $launch_dir]"
    }

    set sc_opts "-sv_root \"$rel_lib_path\" -sc_lib ${lib_name}${lib_extn} --include \"$incl_dir\""
    #puts sc_opts=$sc_opts
    lappend opts $sc_opts
  }

  set l_incl_dir [list]
  set filter  "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC Header\")"
  set prefix_ref_dir false
  foreach incl_dir [xcs_get_c_incl_dirs $simulator $launch_dir $a_sim_vars(s_boost_dir) $filter $a_sim_vars(s_ip_user_files_dir) false $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
    if { [lsearch -exact $unique_sysc_incl_dirs $incl_dir] == -1 } {
      lappend unique_sysc_incl_dirs $incl_dir
      lappend opts "--include \"$incl_dir\""
    }
  }

  variable l_systemc_incl_dirs
  if { [llength $l_systemc_incl_dirs] > 0 } {
    foreach incl_dir $l_systemc_incl_dirs {
      if { [lsearch -exact $unique_sysc_incl_dirs $incl_dir] == -1 } {
        lappend unique_sysc_incl_dirs $incl_dir
        lappend opts "--include \"$incl_dir\""
      }
    }
  }

  foreach incl_dir [get_property "SYSTEMC_INCLUDE_DIRS" $a_sim_vars(fs_obj)] {
    if { !$a_sim_vars(b_absolute_path) } {
      set incl_dir "[xcs_get_relative_file_path $incl_dir $launch_dir]"
    }

    if { [lsearch -exact $unique_sysc_incl_dirs $incl_dir] == -1 } {
      lappend unique_sysc_incl_dirs $incl_dir
      lappend opts "--include \"$incl_dir\""
    }
  }
}

proc xps_export_ld_lib { simulator fh_unix } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set clibs_dir [xps_get_lib_map_path $simulator]
  set shared_ip_libs [list]

  lappend shared_ip_libs "."

  # get data dir from $XILINX_VIVADO/data/simmodels/questa (will return $XILINX_VIVADO/data)
  set data_dir [rdi::get_data_dir -quiet -datafile "simmodels/questa"]

  # design contains AIE? bind protected cluster library
  # ($XILINX_VIVADO/data/simmodels/questa/2019.4/lnx64/5.3.0/systemc/protected/aie_cluster_v1_0_0/libaie_cluster_v1_0_0.so)
  set aie_ip_obj [xcs_find_ip "ai_engine"]
  if { {} != $aie_ip_obj } {
    # get protected sub-dir (simmodels/questa/2019.4/lnx64/5.3.0/systemc/protected)
    set cpt_dir [xcs_get_simmodel_dir "questa" $a_sim_vars(s_gcc_version) "cpt"]
    set model "aie_cluster_v1_0_0"

    # $XILINX_VIVADO/data/simmodels/questa/2019.4/lnx64/5.3.0/systemc/protected/aie_cluster_v1_0_0
    # 1080663 - bind with aie_xtlm_v1_0_0 during compile time
    # TODO: find way to make this data-driven
    lappend shared_ip_libs "$data_dir/$cpt_dir/$model"
  }

  variable a_shared_library_path_coln
  foreach {key value} [array get a_shared_library_path_coln] {
    set sc_lib   $key
    set lib_path $value
    set lib_dir "$lib_path"

    lappend shared_ip_libs $lib_dir
  }

  # bind IP static librarries
  set sh_ip_libs [xcs_get_shared_ip_libraries $clibs_dir]
  set uniq_shared_libs    [list]
  set shared_libs_to_link [list]

  foreach ip_obj [get_ips -all -quiet] {
    set ipdef [get_property -quiet IPDEF $ip_obj]
    set vlnv_name [xcs_get_library_vlnv_name $ip_obj $ipdef]
    set ssm_type [get_property -quiet selected_sim_model $ip_obj]
    if { [lsearch $sh_ip_libs $vlnv_name] != -1 } {
      if { [lsearch -exact $uniq_shared_libs $vlnv_name] == -1 } {
        if { ("tlm" == $ssm_type) } {
          # bind systemC library
          lappend shared_libs_to_link $vlnv_name
          lappend uniq_shared_libs $vlnv_name
        } else {
          # rtl, tlm_dpi (no binding)
        }
      }
    }
  }

  foreach vlnv_name $shared_libs_to_link {
    set lib_dir "$clibs_dir/$vlnv_name"
    lappend shared_ip_libs $lib_dir
  }

  if { "vcs" == $simulator } {
    lappend shared_ip_libs "\$sys_path"
  }

  if { [llength $shared_ip_libs] > 0 } {
    set shared_ip_libs_env_path [join $shared_ip_libs ":"]
    puts $fh_unix "LD_LIBRARY_PATH=$shared_ip_libs_env_path:\$LD_LIBRARY_PATH\n"
  }
  puts $fh_unix "export xv_cpt_lib_path=\"$a_sim_vars(sp_cpt_dir)\""
  # for aie
  if { {} != $aie_ip_obj } {
    puts $fh_unix "export CHESSDIR=\"\$XILINX_VITIS/aietools/tps/lnx64/target/chessdir\""
  }
  puts $fh_unix ""
}

}
