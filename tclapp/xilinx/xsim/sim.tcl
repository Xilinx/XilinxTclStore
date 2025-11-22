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
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::xsim {
  namespace export setup
}

namespace eval ::tclapp::xilinx::xsim {
proc setup { args } {
  # Summary: initialize global vars and prepare for simulation
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task 
  # Return Value:
  # true (0) if success, false (1) otherwise

  # initialize global variables
  set args [string trim $args "\}\{"]

  # donot re-initialze, if -int_setup_sim_vars found in args (for -step flow only)
  if { [lsearch -exact $args {-int_setup_sim_vars}] == -1 } {
    usf_init_vars
  }

  # control precompile flow
  variable a_sim_vars
  xcs_control_pre_compile_flow a_sim_vars(b_use_static_lib)

  # read simulation command line args and set global variables
  usf_xsim_setup_args $args

  # set NoC binding type
  if { $a_sim_vars(b_int_system_design) } {
    xcs_bind_legacy_noc
  }

  # perform initial simulation tasks
  if { [usf_xsim_setup_simulation] } {
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

  set scr_filename {}
  send_msg_id USF-XSim-002 INFO "XSim::Compile design"
  usf_xsim_write_compile_script scr_filename
  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  usf_launch_script "xsim" $step
  #usf_xsim_include_xvhdl_log
}

proc elaborate { args } {
  # Summary: run the elaborate step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task 
  # Return Value:
  # none

  set scr_filename {}
  send_msg_id USF-XSim-003 INFO "XSim::Elaborate design"
  usf_xsim_write_elaborate_script scr_filename
  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  usf_launch_script "xsim" $step
}

proc simulate { args } {
  # Summary: run the simulate step for simulating the elaborated design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task 
  # Return Value:
  # none

  variable a_sim_vars

  send_msg_id USF-XSim-004 INFO "XSim::Simulate design"

  # create setup files
  set scr_filename {}
  set cmd_file {}
  set wcfg_file {}
  set b_add_view 0
  set l_sm_lib_paths [list]
  set cmd_args [usf_xsim_write_simulate_script l_sm_lib_paths cmd_file wcfg_file b_add_view scr_filename]

  set proc_name [lindex [split [info level 0] " "] 0]
  set step [lindex [split $proc_name {:}] end]
  usf_launch_script "xsim" $step

  if { $a_sim_vars(b_scripts_only) } {
    set fh 0
    set file [file normalize [file join $a_sim_vars(s_launch_dir) "simulate.log"]]
    if {[catch {open $file w} fh]} {
      send_msg_id USF-XSim-016 ERROR "Failed to open file to write ($file)\n"
    } else {
      puts $fh "INFO: Scripts generated successfully. Please see the 'Tcl Console' window for details."
      close $fh
    }

    # write run script
    usf_write_run_script "xsim" $a_sim_vars(run_logs)

    return
  }

  # is dll requested?
  set b_dll [get_property "xelab.dll" $a_sim_vars(fs_obj)]
  if { $b_dll } {
    set lib_extn {.dll}
    if {$::tcl_platform(platform) == "unix"} {
      set lib_extn {.so}
    }
    set dll_lib_name "xsimk";append dll_lib_name $lib_extn
    set dll_file [file normalize [file join $a_sim_vars(s_launch_dir) "xsim.dir" $a_sim_vars(s_snapshot) $dll_lib_name]]
    if { [file exists $dll_file] } {
      send_msg_id USF-XSim-006 INFO "Shared library for snapshot '$a_sim_vars(s_snapshot)' generated:$dll_file"
    } else {
      send_msg_id USF-XSim-007 ERROR "Failed to generate the shared library for snapshot '$a_sim_vars(s_snapshot)'!"
    }
    return
  }

  # is standalone mode?
  set standalone_mode [get_property -quiet "xelab.standalone" $a_sim_vars(fs_obj)]

  if { $standalone_mode } {
    # no op
  } else {
    # launch xsim
    send_msg_id USF-XSim-008 INFO "Loading simulator feature"
    load_feature simulator
  }

  set cwd [pwd]
  cd $a_sim_vars(s_launch_dir)
  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    set cmd "set ::env(SIM_VER_XSIM) $a_sim_vars(s_sim_version)"
    if {[catch {eval $cmd} err_msg]} {
      puts $err_msg
      [catch {send_msg_id USF-XSim-102 ERROR "Failed to set the SIM_VER_XSIM env!"}]
    } else {
      #[catch {send_msg_id USF-XSim-103 STATUS "SIM_VER_XSIM=$::env(SIM_VER_XSIM)"}]
    }
    set cmd "set ::env(GCC_VER_XSIM) $a_sim_vars(s_gcc_version)"
    if {[catch {eval $cmd} err_msg]} {
      puts $err_msg
      [catch {send_msg_id USF-XSim-102 ERROR "Failed to set the GCC_VER_XSIM env!"}]
    } else {
      #[catch {send_msg_id USF-XSim-103 STATUS "GCC_VER_XSIM=$::env(GCC_VER_XSIM)"}]
    }

    if {$::tcl_platform(platform) == "unix"} {
      if { [file exists $a_sim_vars(ubuntu_lib_dir)] } {
        set cmd "set ::env(LIBRARY_PATH) $a_sim_vars(ubuntu_lib_dir)"
        if { [info exists ::env(LIBRARY_PATH)] } {
          append cmd ":$::env(LIBRARY_PATH)"
        }
        if {[catch {eval $cmd} err_msg]} {
          puts $err_msg
          [catch {send_msg_id USF-XSim-102 ERROR "Failed to set the LIBRARY_PATH env!"}]
        } else {
          #[catch {send_msg_id USF-XSim-103 STATUS "LIBRARY_PATH=$::env(LIBRARY_PATH)"}]
        }
      }

      # default Vivado install path
      set vivado_install_path $::env(XILINX_VIVADO)
      if { [info exists ::env(VIVADO_LOC)] } {
        set vivado_install_path $::env(VIVADO_LOC)
      }
      set cmd "set ::env(xv_ref_path) \"$vivado_install_path\""
      if {[catch {eval $cmd} err_msg]} {
        puts $err_msg
        [catch {send_msg_id USF-XSim-102 ERROR "Failed to set the xv_ref_path!"}]
      } else {
        #[catch {send_msg_id USF-XSim-103 STATUS "xv_ref_path=$::env(xv_ref_path)"}]
      }

      # set cpt lib path for aie
      set aie_ip_obj [xcs_find_ip "ai_engine"]
      if { {} != $aie_ip_obj } {
        set cmd "set ::env(xv_cpt_lib_path) \"$a_sim_vars(sp_cpt_dir)\""
        if {[catch {eval $cmd} err_msg]} {
          puts $err_msg
          [catch {send_msg_id USF-XSim-102 ERROR "Failed to set the xv_cpt_lib_path!"}]
        } else {
          #[catch {send_msg_id USF-XSim-103 STATUS "xv_cpt_lib_path=$::env(xv_cpt_lib_path)"}]
        }
      }

      set cmd "set ::env(LD_LIBRARY_PATH) \"$a_sim_vars(s_launch_dir):$::env(RDI_LIBDIR)"
      if { [llength l_sm_lib_paths] > 0 } {
        foreach sm_lib_path $l_sm_lib_paths {
          append cmd ":$sm_lib_path"
        }
      }
      if { {} != $aie_ip_obj } {
        append cmd ":\$::env(XILINX_VITIS)/aietools/lib/lnx64.o"
      }
      append cmd ":$::env(LD_LIBRARY_PATH)\""
      set cmd [regsub -all {\$xv_ref_path} $cmd {$::env(xv_ref_path)}]
      set cmd [regsub -all {\$\{SIM_VER_XSIM\}} $cmd {$::env(SIM_VER_XSIM)}]
      set cmd [regsub -all {\$\{GCC_VER_XSIM\}} $cmd {$::env(GCC_VER_XSIM)}]
      if {[catch {eval $cmd} err_msg]} {
        puts $err_msg
        [catch {send_msg_id USF-XSim-102 ERROR "Failed to set the LD_LIBRARY_PATH!"}]
      } else {
        #[catch {send_msg_id USF-XSim-103 STATUS "LD_LIBRARY_PATH=$::env(LD_LIBRARY_PATH)"}]
      }

      if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
        puts "------------------------------------------------------------------------------------------------------------------------------------"
        puts "LIBRARY PATH SETTINGS"
        puts "------------------------------------------------------------------------------------------------------------------------------------"
        puts "xv_ref_path=$::env(xv_ref_path)"
        if { {} != $aie_ip_obj } {
          puts "xv_cpt_lib_path=$::env(xv_cpt_lib_path)"
        }
        puts "------------------------------------------------------------------------------------------------------------------------------------"
      }
    } else {
      # set PATH env to reference shared lib's
      set b_en_code true
      if { $b_en_code } {
        set b_bind_shared_lib 0
        [catch {set b_bind_shared_lib [get_param project.bindSharedLibraryForXSCElab]} err]
        if { $b_bind_shared_lib } {
          set cmd "set ::env(xv_cxl_win_path) $a_sim_vars(s_clibs_dir)"
          if {[catch {eval $cmd} err_msg]} {
            puts $err_msg
            [catch {send_msg_id USF-XSim-102 ERROR "Failed to set the xv_cxl_win_path env!"}]
          }
          set cxl_lib_paths [list]
          variable a_shared_library_path_coln
          foreach {key value} [array get a_shared_library_path_coln] {
            set shared_lib_name $key
            set lib_path        $value
            set lib_name        [file root $shared_lib_name]
            set lib_name        [string trimleft $lib_name {lib}]
            lappend cxl_lib_paths "\$::env(xv_cxl_win_path)/ip/$lib_name"
          }
          set cxl_lib_paths_str [join $cxl_lib_paths ";"]
          set cmd "set ::env(PATH) \"$cxl_lib_paths_str;\$::env(PATH)\""
          if {[catch {eval $cmd} err_msg]} {
            puts $err_msg
            [catch {send_msg_id USF-XSim-102 ERROR "Failed to set the PATH env!"}]
          }
          if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
            puts "------------------------------------------------------------------------------------------------------------------------------------"
            puts "LIBRARY PATH SETTINGS"
            puts "------------------------------------------------------------------------------------------------------------------------------------"
            puts "xv_cxl_win_path=$::env(xv_cxl_win_path)"
            puts "PATH=$::env(PATH)"
            puts "------------------------------------------------------------------------------------------------------------------------------------"
          }
        }
      }
    }
  }

  if { $standalone_mode } {
    # no op
  } else {
    if {[catch {eval "xsim $cmd_args"} err_msg]} {
      puts $err_msg
      set step "simulate"
      [catch {send_msg_id USF-XSim-062 ERROR "'$step' step failed with errors. Please check the Tcl console or log files for more information.\n"}]
      cd $cwd
      # IMPORTANT - *** DONOT MODIFY THIS ***
      error "_SIM_STEP_RUN_EXEC_ERROR_"
      # IMPORTANT - *** DONOT MODIFY THIS ***
      return 1
    } else {
      cd $cwd
      send_msg_id USF-XSim-096 INFO "XSim completed. Design snapshot '$a_sim_vars(s_snapshot)' loaded."
      set rt [string trim [get_property "xsim.simulate.runtime" $a_sim_vars(fs_obj)]]
      if { {} != $rt } {
        send_msg_id USF-XSim-097 INFO "XSim simulation ran for $rt"
      }
    
      # close for batch flow
      if { $a_sim_vars(b_batch) } {
        send_msg_id USF-XSim-009 INFO "Closing simulation..."
        close_sim
      }
    }
  }
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

  variable a_sim_vars
 
  # set the simulation flow
  xcs_set_simulation_flow $a_sim_vars(s_simset) $a_sim_vars(s_mode) $a_sim_vars(s_type) a_sim_vars(s_flow_dir_key) a_sim_vars(s_simulation_flow)
 
  # set default object
  if { [xcs_set_sim_tcl_obj $a_sim_vars(s_comp_file) $a_sim_vars(s_simset) a_sim_vars(sp_tcl_obj) a_sim_vars(s_sim_top)] } {
    return 1
  }

  # setup snapshot name
  set a_sim_vars(s_snapshot) [usf_xsim_get_snapshot]

  # *****************************************************************
  # is step exec mode? for xsim we just need to set the snapshot name
  # *****************************************************************
  if { $a_sim_vars(b_int_setup_sim_vars) } {
    return 0
  }

  if { ({post_synth_sim} == $a_sim_vars(s_simulation_flow)) || ({post_impl_sim} == $a_sim_vars(s_simulation_flow)) } {
    set a_sim_vars(b_netlist_sim) 1
  }

  # enable systemC non-precompile flow if global pre-compiled static IP flow is disabled 
  if { !$a_sim_vars(b_use_static_lib) } {
    set a_sim_vars(b_compile_simmodels) 1
  }

  if { $a_sim_vars(b_compile_simmodels) } {
    set a_sim_vars(s_simlib_dir) "$a_sim_vars(s_launch_dir)/simlibs"
    if { ![file exists $a_sim_vars(s_simlib_dir)] } {
      if { [catch {file mkdir $a_sim_vars(s_simlib_dir)} error_msg] } {
        send_msg_id USF-XSim-013 ERROR "Failed to create the directory ($a_sim_vars(s_simlib_dir)): $error_msg\n"
        return 1
      }
    }
  }

  # initialize boost library reference
  set a_sim_vars(s_boost_dir) [xcs_get_boost_library_path]

  # TODO: perf-fix 
  # initialize XPM libraries (if any)
  xcs_get_xpm_libraries

  # get hard-blocks
  #xcs_get_hard_blocks

  # initialize compiled design library
  if { [get_param "simulation.compileDesignLibsToXSimLib"] } {
    set a_sim_vars(compiled_design_lib) "xsim_lib"
  }

  # write functional/timing netlist for post-* simulation
  set a_sim_vars(s_netlist_file) [xcs_write_design_netlist $a_sim_vars(s_simset)          \
                                                           $a_sim_vars(s_simulation_flow) \
                                                           $a_sim_vars(s_type)            \
                                                           $a_sim_vars(s_sim_top)         \
                                                           $a_sim_vars(s_launch_dir)      \
                                 ]

  # prepare IP's for simulation
  # xcs_prepare_ip_for_simulation $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(s_launch_dir)

  variable l_compiled_libraries
  variable l_xpm_libraries
  set b_reference_xpm_library 0
  if { [llength $l_xpm_libraries] > 0 } {
    if { [get_param project.usePreCompiledXPMLibForSim] } {
      set b_reference_xpm_library 1
    }
  }
  if { ($a_sim_vars(b_use_static_lib)) && ([xcs_is_ip_project] || $b_reference_xpm_library || $a_sim_vars(b_int_use_ini_file)) } {
    usf_set_compiled_lib_dir
    set l_local_ip_libs [xcs_get_libs_from_local_repo $a_sim_vars(b_use_static_lib) $a_sim_vars(s_local_ip_repo_leaf_dir) $a_sim_vars(b_int_sm_lib_ref_debug)]
    set libraries [xcs_get_compiled_libraries $a_sim_vars(compiled_library_dir) $a_sim_vars(b_int_sm_lib_ref_debug)]
    # filter local ip definitions
    foreach lib $libraries {
      if { [lsearch -exact $l_local_ip_libs $lib] != -1 } {
        # The pre-compiled library is found from local repo as well, so we will use and compile this
        # local repo version during compilation. Do not add to valid list of pre-compiled libraries
        # collection (l_compiled_libraries).
        continue
      } else {
        # List of final pre-compiled libraries after filtering the ones that either failed to compile or
        # not found in the local repo. All other libraries found in the design if not in this list will
        # be compiled locally.
        lappend l_compiled_libraries $lib
      }
    }
  }
  
  set a_sim_vars(s_clibs_dir) $a_sim_vars(compiled_library_dir)


  # generate mem files
  xcs_generate_mem_files_for_simulation $a_sim_vars(sp_tcl_obj) $a_sim_vars(s_launch_dir)

  # fetch the compile order for the specified object
  xcs_xport_data_files $a_sim_vars(sp_tcl_obj) $a_sim_vars(s_simset) $a_sim_vars(s_sim_top) $a_sim_vars(s_launch_dir) $a_sim_vars(dynamic_repo_dir)

  # cache all design files
  variable a_sim_cache_all_design_files_obj
  foreach file_obj [get_files -quiet -all] {
    set name [get_property -quiet "name" $file_obj]
    set a_sim_cache_all_design_files_obj($name) $file_obj
  }

  # cache all IPs 
  variable a_sim_cache_all_ip_obj 
  foreach ip_obj [lsort -unique [get_ips -all -quiet]] {
    set name [get_property -quiet name $ip_obj]
    set a_sim_cache_all_ip_obj($name) $ip_obj
  }

  # cache all system verilog package libraries
  xcs_find_sv_pkg_libs $a_sim_vars(s_launch_dir) $a_sim_vars(b_int_sm_lib_ref_debug)

  # find noc IP, if any for netlist functional simulation
  if { $a_sim_vars(b_enable_netlist_sim) && $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) } {
    set a_sim_vars(sp_xlnoc_bd_obj) [get_files -all -quiet "xlnoc.bd"]
  }

  # fetch design files
  variable l_local_design_libraries 
  set global_files_str {}
  set a_sim_vars(l_design_files) [xcs_uniquify_cmd_str [usf_get_files_for_compilation global_files_str]]

  # print IPs that were not found from clibs
  xcs_print_local_IP_compilation_msg $a_sim_vars(b_int_sm_lib_ref_debug) $l_local_design_libraries $a_sim_vars(compiled_library_dir)

  # contains system verilog? (for uvm)
  set a_sim_vars(b_contain_sv_srcs) [xcs_contains_system_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]

  # is system design?
  if { $a_sim_vars(b_contain_systemc_sources) || $a_sim_vars(b_contain_cpp_sources) || $a_sim_vars(b_contain_c_sources) || $a_sim_vars(b_contain_asm_sources) } {
    set a_sim_vars(b_system_sim_design) 1
  }

  # for non-precompile mode set the compiled library for system simulation 
  if { !$a_sim_vars(b_use_static_lib) } {
    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      usf_xsim_set_clibs_for_non_precompile_flow
      set a_sim_vars(s_clibs_dir) $a_sim_vars(compiled_library_dir)
    }
  }

  # extract simulation model library info
  set ip_dir "$a_sim_vars(s_clibs_dir)/ip"
  if { ![file exists $ip_dir] } {
    set ip_dir $a_sim_vars(s_clibs_dir)
  }

  # TODO: perf-fix
  xcs_fetch_lib_info "xsim" $ip_dir $a_sim_vars(b_int_sm_lib_ref_debug)

  # systemC headers
  set a_sim_vars(b_contain_systemc_headers) [xcs_contains_systemc_headers]

  # find shared library paths from all IPs 
  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    set b_en_code true
    if { $b_en_code } {
      xcs_find_shared_lib_paths "xsim" $a_sim_vars(s_gcc_version) $a_sim_vars(s_clibs_dir) $a_sim_vars(custom_sm_lib_dir) $a_sim_vars(b_int_sm_lib_ref_debug) a_sim_vars(sp_cpt_dir) a_sim_vars(sp_ext_dir)
    }
  }

  # create custom library directory (xsim_lib)
  if { [get_param "simulation.compileDesignLibsToXSimLib"] } {
    usf_xsim_create_lib_dir
  }
 
  set b_create_default_ini 1
  set b_reference_xpm_library 0
  if { [llength $l_xpm_libraries] > 0 } {
    if { [get_param project.usePreCompiledXPMLibForSim] } {
      set b_reference_xpm_library 1
    }
  }
  if { ($a_sim_vars(b_use_static_lib)) && ([xcs_is_ip_project] || $b_reference_xpm_library) || $a_sim_vars(b_int_use_ini_file) } {
    set filename "xsim.ini"
    set file [file join $a_sim_vars(s_launch_dir) $filename]

    # at this point the ini file must exist in run for pre-compile flow, if not create default
    # for user design libraries since the static files will be exported for these libraries
    if { [file exists $file] } {
      # re-align local libraries for the ones that were not found in compiled library
      usf_realign_local_mappings $file l_local_design_libraries

      # re-align sim model libraries if custom path specified
      usf_realign_custom_simmodel_libraries $file

      set b_create_default_ini 0
    }
  }

  if { $b_create_default_ini } {
    usf_xsim_write_setup_file
  }

  return 0
}

proc usf_set_compiled_lib_dir { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set filename "xsim.ini"
  set file [file join $a_sim_vars(s_launch_dir) $filename]

  # delete xsim.ini from run dir
  if { [file exists $file] } {
    [catch {file delete -force $file} error_msg]
  }

  # find/copy xsim.ini file into run dir
  if { [usf_xsim_verify_compiled_lib] } {
    return
  }

  if { ![file exists $file] } {
    return
  }

  set fh 0
  if {[catch {open $file a} fh]} {
    send_msg_id USF-XSim-011 ERROR "Failed to open file to append ($file)\n"
    return
  }
  usf_xsim_map_pre_compiled_libs $fh
  close $fh

  return
}

proc usf_realign_local_mappings { ini_file l_local_design_libraries_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_local_design_libraries_arg l_local_libraries
  variable a_sim_vars

  if { ![file exists $ini_file] } {
    return
  }

  # read xsim.ini contents
  set fh 0
  if {[catch {open $ini_file r} fh]} {
    send_msg_id USF-XSim-011 ERROR "Failed to open file to read ($ini_file)\n"
    return 1
  }
  set data [split [read $fh] "\n"]
  close $fh
  set l_updated_mappings [list]
  set l_local_mappings_found_in_ini [list]
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    set library [string trim [lindex [split $line "="] 0]]
    if { [lsearch -exact $l_local_libraries $library] != -1 } {
      set line "$library=$a_sim_vars(compiled_design_lib)/$library"
      lappend l_local_mappings_found_in_ini $library
    }
    lappend l_updated_mappings $line
  }

  # add local libraries not found in ini
  foreach library $l_local_libraries {
    if { [lsearch -exact $l_local_mappings_found_in_ini $library] == -1 } {
      lappend l_updated_mappings "$library=$a_sim_vars(compiled_design_lib)/$library"
    }
  }

  # first make back up
  set ini_file_bak ${ini_file}.bak
  [catch {file copy -force $ini_file $ini_file_bak} error_msg]

  # delete ini file
  [catch {file delete -force $ini_file} error_msg]

  # create fresh updated copy
  set fh 0
  if {[catch {open $ini_file w} fh]} {
    send_msg_id USF-XSim-011 ERROR "Failed to open file to write ($ini_file)\n"
    # revert backup ini file
    [catch {file copy -force $ini_file_bak $ini_file} error_msg]
    return
  }
  foreach line $l_updated_mappings {
    puts $fh $line
  }
  close $fh
}

proc usf_realign_custom_simmodel_libraries { ini_file } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  if { ![file exists $ini_file] } {
    return
  }

  set lib_coln [list]
  set lib_paths [list]
  variable a_shared_library_mapping_path_coln
  foreach {library lib_dir} [array get a_shared_library_mapping_path_coln] {
    lappend lib_coln $library
    lappend lib_paths $lib_dir
  }

  # replace mappings paths
  set fh 0
  if {[catch {open $ini_file r} fh]} {
    send_msg_id USF-XSim-011 ERROR "Failed to open file to read ($ini_file)\n"
    return
  }
  set data [split [read $fh] "\n"]
  close $fh

  # get the updated mappings collection
  set l_updated_mappings [list]
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } {
      continue;
    }
    set library [string trim [lindex [split $line "="] 0]]
    if { [lsearch -exact $lib_coln $library] != -1 } {
      set lib_path $a_shared_library_mapping_path_coln($library)
      set line "$library=$lib_path/$library"
    }
    lappend l_updated_mappings $line
  }

  # delete exisiting bak file, if exist and then make backup
  set ini_file_bak ${ini_file}.bak
  if { [file exists $ini_file_bak] } {
    [catch {file delete -force $ini_file_bak} error_msg]
  }
  [catch {file copy -force $ini_file $ini_file_bak} error_msg]

  # delete ini file
  [catch {file delete -force $ini_file} error_msg]

  # create fresh updated copy of ini file with updated mappings
  set fh 0
  if {[catch {open $ini_file w} fh]} {
    send_msg_id USF-XSim-011 ERROR "Failed to open file to write ($ini_file)\n"
    # revert backup ini file
    [catch {file copy -force $ini_file_bak $ini_file} error_msg]
    return
  }
  foreach line $l_updated_mappings {
    puts $fh $line
  }
  close $fh 
  return
}

proc usf_xsim_setup_args { args } {
  # Summary:
 
  # Argument Usage:
  # [-simset <arg>]: Name of the simulation fileset
  # [-mode <arg>]: Simulation mode. Values: behavioral, post-synthesis, post-implementation
  # [-type <arg>]: Netlist type. Values: functional, timing. This is only applicable when mode is set to post-synthesis or post-implementation
  # [-scripts_only]: Only generate scripts
  # [-gui]: Invoke simulator in GUI mode for scripts only
  # [-of_objects <arg>]: Generate do file for this object (applicable with -scripts_only option only)
  # [-absolute_path]: Make all file paths absolute wrt the reference directory
  # [-lib_map_path <arg>]: Precompiled simulation library directory path
  # [-install_path <arg>]: Custom XSim installation directory path
  # [-batch]: Execute batch flow simulation run (non-gui)
  # [-exec]: Execute script (applicable with -step switch only)
  # [-run_dir <arg>]: Simulation run directory
  # [-int_sm_lib_dir <arg>]: Simulation model library directory
  # [-int_os_type]: OS type (32 or 64) (internal use)
  # [-int_setup_sim_vars]: Initialize sim vars only (internal use)
  # [-int_debug_mode]: Debug mode (internal use)
  # [-int_systemc_mode]: SystemC mode (internal use)
  # [-int_system_design]: Design configured for system simulation (internal use)
  # [-int_gcc_bin_path <arg>]: GCC path (internal use)
  # [-int_gcc_version <arg>]: GCC version (internal use)
  # [-int_sim_version <arg>]: Simulator version (internal use)
  # [-int_aie_work_dir <arg>]: AIE work dir (internal use)
  # [-int_rtl_kernel_mode]: RTL Kernel simulation mode (internal use)
  # [-int_compile_glbl]: Compile glbl (internal use)
  # [-int_sm_lib_ref_debug]: Print simulation model library referencing debug messages (internal use)
  # [-int_csim_compile_order]: Use compile order for co-simulation (internal use)
  # [-int_en_system_sim_code]: Enable code for system simulation (internal use)
  # [-int_export_source_files]: Export IP sources to simulation run directory (internal use)
  # [-int_en_vitis_hw_emu_mode]: Enable code for Vitis HW-EMU (internal use)
  # [-int_use_ini_file]: Use mapping file for RTL design (internal use)
  # [-int_bind_sip_cores]: Bind SIP core library (internal use)
 
  # Return Value:
  # true (0) if success, false (1) otherwise
 
  # Categories: xilinxtclstore, xsim

  variable a_sim_vars 
  set args [string trim $args "\}\{"]
 
  # process options
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-simset"                   { incr i;set a_sim_vars(s_simset)            [lindex $args $i] }
      "-mode"                     { incr i;set a_sim_vars(s_mode)              [lindex $args $i] }
      "-type"                     { incr i;set a_sim_vars(s_type)              [lindex $args $i] }
      "-of_objects"               { incr i;set a_sim_vars(s_comp_file)         [lindex $args $i] }
      "-lib_map_path"             { incr i;set a_sim_vars(s_lib_map_path)      [lindex $args $i] }
      "-install_path"             { incr i;set a_sim_vars(s_install_path)      [lindex $args $i] }
      "-run_dir"                  { incr i;set a_sim_vars(s_launch_dir)        [lindex $args $i] }
      "-int_os_type"              { incr i;set a_sim_vars(s_int_os_type)       [lindex $args $i] }
      "-int_debug_mode"           { incr i;set a_sim_vars(s_int_debug_mode)    [lindex $args $i] }
      "-int_gcc_bin_path"         { incr i;set a_sim_vars(s_gcc_bin_path)      [lindex $args $i] }
      "-int_gcc_version"          { incr i;set a_sim_vars(s_gcc_version)       [lindex $args $i] }
      "-int_sim_version"          { incr i;set a_sim_vars(s_sim_version)       [lindex $args $i] }
      "-int_aie_work_dir"         { incr i;set a_sim_vars(s_aie_work_dir)      [lindex $args $i] }
      "-int_sm_lib_dir"           { incr i;set a_sim_vars(custom_sm_lib_dir)   [lindex $args $i] }
      "-scripts_only"             { set a_sim_vars(b_scripts_only)             1                 }
      "-gui"                      { set a_sim_vars(b_gui)                      1                 }
      "-absolute_path"            { set a_sim_vars(b_absolute_path)            1                 }
      "-batch"                    { set a_sim_vars(b_batch)                    1                 }
      "-exec"                     { set a_sim_vars(b_exec_step) 1;set a_sim_vars(b_scripts_only) 0}
      "-int_systemc_mode"         { set a_sim_vars(b_int_systemc_mode)         1                 }
      "-int_system_design"        { set a_sim_vars(b_int_system_design)        1                 }
      "-int_rtl_kernel_mode"      { set a_sim_vars(b_int_rtl_kernel_mode)      1                 }
      "-int_compile_glbl"         { set a_sim_vars(b_int_compile_glbl)         1                 }
      "-int_sm_lib_ref_debug"     { set a_sim_vars(b_int_sm_lib_ref_debug)     1                 }
      "-int_csim_compile_order"   { set a_sim_vars(b_int_csim_compile_order)   1                 }
      "-int_export_source_files"  { set a_sim_vars(b_int_export_source_files)  1                 }
      "-int_en_vitis_hw_emu_mode" { set a_sim_vars(b_int_en_vitis_hw_emu_mode) 1                 }
      "-int_use_ini_file"         { set a_sim_vars(b_int_use_ini_file)         1                 }
      "-int_bind_sip_cores"       { set a_sim_vars(b_int_bind_sip_cores)       1                 }
      "-int_setup_sim_vars"       { set a_sim_vars(b_int_setup_sim_vars)       1                 }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id USF-XSim-010 WARNING "Unknown option '$option' specified (ignored)\n"
        }
      }
    }
  }

  #
  # TEMP-FIX: set gcc flag
  #
  if { "6.2.0" == $a_sim_vars(s_gcc_version) } {
    set a_sim_vars(b_gcc_version) 1
  } 

  ###################
  # logic var setting
  ###################
  if {$a_sim_vars(s_int_debug_mode) == "1"   } {set a_sim_vars(s_dbg_sw) "-dbg"}
  if {$::tcl_platform(platform)     == "unix"} {set a_sim_vars(script_cmt_tag) "#"}
}

proc usf_xsim_get_compiled_library_dir {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set filename "xsim.ini"
  set clibs_dir {}
  # 1. is -lib_map_path specified and point to valid location?
  if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
    set clibs_dir [file normalize $a_sim_vars(s_lib_map_path)]
    set ini_file "$clibs_dir/$filename"
    if { [file exists $ini_file] } {
      return $clibs_dir
    }
  }

  # 2. if empty property (default), calculate default install location
  set clibs_dir [get_property "compxlib.xsim_compiled_library_dir" $a_sim_vars(curr_proj)]
  if { {} == $clibs_dir } {
    set clibs_dir $::env(XILINX_VIVADO)
    set clibs_dir [file normalize [file join $clibs_dir "data/xsim"]]
  }
  set ini_file "$clibs_dir/$filename"
  if { [file exists $ini_file] } {
    return $clibs_dir
  }

  # not found, return empty
  return $clibs_dir
}

proc usf_xsim_verify_compiled_lib {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set filename "xsim.ini"
  send_msg_id USF-XSim-007 INFO "Finding pre-compiled libraries...\n"
  # 1. is -lib_map_path specified and point to valid location?
  if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
    if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
      puts "(DEBUG) - checking -lib_map_path..."
    }
    set a_sim_vars(s_lib_map_path) [file normalize $a_sim_vars(s_lib_map_path)]
    set ini_file [file normalize [file join $a_sim_vars(s_lib_map_path) $filename]]
    if { [file exists $ini_file] } {
      if { [usf_copy_ini_file $a_sim_vars(s_lib_map_path)] } {
        return 1
      }
      usf_resolve_rdi_datadir $a_sim_vars(s_launch_dir) $a_sim_vars(s_lib_map_path)
      set a_sim_vars(compiled_library_dir) $a_sim_vars(s_lib_map_path)
      if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
        puts "(DEBUG) - compiled library path set to '$a_sim_vars(compiled_library_dir)'"
      }
      return 0
    } else {
      usf_print_compiled_lib_msg
      return 1
    }
  }

  # 2. if empty property (default), calculate default install location
  set dir [get_property "compxlib.xsim_compiled_library_dir" $a_sim_vars(curr_proj)]
  set b_resolve_rdi_datadir_env false
  if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
    puts "(DEBUG) - checking compxlib.xsim_compiled_library_dir property..."
  }
  if { {} == $dir } {
    set dir $::env(XILINX_VIVADO)
    set dir [file normalize [file join $dir "data/xsim"]]
    if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
      puts "(DEBUG) - property value empty, using XILINX_VIVADO ($dir)"
    }
  } else {
    set b_resolve_rdi_datadir_env true
    if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
      puts "(DEBUG) - property currently set to '$dir'"
    }
    # if pointing to local clibs, donot resolve $RDI_DATADIR (use xsim.ini asis)
    set local_clibs_dir $dir
    set local_clibs_dir [regsub -all {[\[\]]} $local_clibs_dir {/}]
    if { [regexp {prep/rdi/vivado/data/clibs/xsim} $local_clibs_dir] } {
      if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
        puts "(DEBUG) - using local clibs '$local_clibs_dir'"
      }
      set b_resolve_rdi_datadir_env false
    }
  }
  set file [file normalize [file join $dir $filename]]
  if { [file exists $file] } {
    if { [usf_copy_ini_file $dir] } {
     return 1
    }
    if { $b_resolve_rdi_datadir_env } {
      # TODO: perf-fix
      if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
        puts "(DEBUG) - resolving RDI_DATADIR in xsim.ini..."
      }
      usf_resolve_rdi_datadir $a_sim_vars(s_launch_dir) $dir
    }
    set a_sim_vars(compiled_library_dir) $dir
    if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
      puts "(DEBUG) - compiled library path set to '$a_sim_vars(compiled_library_dir)'"
    }
    return 0
  }

  # failed to find the compiled library, print msg
  usf_print_compiled_lib_msg
  return 1
}

proc usf_xsim_set_clibs_for_non_precompile_flow {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set filename "xsim.ini"
  send_msg_id USF-XSim-007 INFO "Finding pre-compiled libraries...\n"

  # 1. is -lib_map_path specified and point to valid location?
  if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
    set a_sim_vars(s_lib_map_path) [file normalize $a_sim_vars(s_lib_map_path)]
    set ini_file [file normalize [file join $a_sim_vars(s_lib_map_path) $filename]]
    if { [file exists $ini_file] } {
      set a_sim_vars(compiled_library_dir) $a_sim_vars(s_lib_map_path)
      return 0
    } else {
      usf_print_compiled_lib_msg
      return 1
    }
  }

  # 2. if empty property (default), calculate default install location
  set dir [get_property "compxlib.xsim_compiled_library_dir" $a_sim_vars(curr_proj)]
  if { {} == $dir } {
    set dir $::env(XILINX_VIVADO)
    set dir [file normalize [file join $dir "data/xsim"]]
  }
  set file [file normalize [file join $dir $filename]]
  if { [file exists $file] } {
    set a_sim_vars(compiled_library_dir) $dir
    return 0
  }

  # failed to find the compiled library, print msg
  usf_print_compiled_lib_msg
  return 1
}

proc usf_print_compiled_lib_msg {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { $a_sim_vars(b_scripts_only) } {
    send_msg_id USF-XSim-024 WARNING "The compiled IP simulation library could not be located. Please make sure to reference this library before executing the scripts.\n"
  } else {
    send_msg_id USF-XSim-008 WARNING "Failed to find the pre-compiled simulation library. IPs will be compiled locally as part of the simulation.\n"
  }
}

proc usf_copy_ini_file { dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set file [file join $dir "xsim.ini"]
  if { [file exists $file] } {
    if { [catch {file copy -force $file $a_sim_vars(s_launch_dir)} error_msg] } {
      send_msg_id USF-XSim-010 ERROR "Failed to copy file ($file): $error_msg\n"
      return 1
    } else {
      send_msg_id USF-XSim-011 INFO "File '$file' copied to run dir:'$a_sim_vars(s_launch_dir)'\n"

      # print IP repo info from clibs dir
      xcs_print_ip_repo_info $dir $a_sim_vars(b_int_sm_lib_ref_debug)

      return 0
    }
  }

  return 0
}

proc xcs_print_ip_repo_info { clibs_dir {b_int_sm_lib_ref_debug 0} } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set info_dir "$clibs_dir/ip"
  set info_file_path "$info_dir/.cxl.repo.info"

  if { ![file exists $info_file_path] } {
    return
  }

  set fh 0
  if { [catch {open $info_file_path r} fh]} {
    return
  }
  set repo_data [split [read $fh] "\n"]
  close $fh

  foreach repo_path $repo_data {
    if { {} == $repo_path } { continue }
    if { $b_int_sm_lib_ref_debug } {
      puts "(DEBUG) - repo_path: $repo_path"
    }
    if { [regexp {data/ip/xilinx} $repo_path] } {
      send_msg_id SIM-utils-082 INFO "Catalog repository used for pre-compiled IPs: '$repo_path'\n"
      break
    }
  }
}

proc usf_resolve_rdi_datadir { run_dir cxl_prop_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set b_param_mode_set 0
  set b_env_mode_set 0
  if { [get_param "simulation.resolveDataDirEnvPathForXSim"] } {
    set b_param_mode_set 1
    if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
      puts "(DEBUG) - param 'simulation.resolveDataDirEnvPathForXSim is enabled' (\$RDI_DATADIR env will be resolved in local xsim.ini, if found)"
    }
  } else {
    # check env
    if { [info exists ::env(RESOLVE_DATADIR_ENV_PATH_FOR_XSIM)] } {
      set b_env_mode_set 1
      if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
        puts "(DEBUG) - env 'RESOLVE_DATADIR_ENV_PATH_FOR_XSIM' is set (\$RDI_DATADIR env will be resolved in local xsim.ini, if found)"
      }
    } else {
      # skip RDI_DATADIR env replacement with absolute clib path
      if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
        if { (!$b_param_mode_set) && (!$b_env_mode_set) } {
          puts "(DEBUG) - neither 'simulation.resolveDataDirEnvPathForXSim' param or 'RESOLVE_DATADIR_ENV_PATH_FOR_XSIM' env set, \$RDI_DATADIR will NOT be resolved in local xsim.ini"
        }
      }
      return 0
    }
  }

  set ini_file "$run_dir/xsim.ini"
  if { ![file exists $ini_file] } {
    return 0
  }

  set fh 0
  if { [catch {open $ini_file r} fh] } {
    [catch {send_msg_id USF-XSim-011 ERROR "Failed to open file to read ($file)\n"} error]
    return 0
  }
  set ini_data [read $fh]
  close $fh
  
  set libs [list]
  set ini_data [split $ini_data "\n"]
  foreach line $ini_data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    if { [regexp {^--} $line] } { continue; }
    set library_name [lindex [split $line "="] 0]
    lappend libs $library_name
  }
  [catch {file delete -force $ini_file} error_msg]

  # now recreate xsim.ini with the directory mappings from the path specified with compxlib.xsim_compiled_library_dir property
  set fh 0
  if { [catch {open $ini_file w} fh] } {
    [catch {send_msg_id USF-XSim-011 ERROR "Failed to open file to write ($file)\n"} error]
    return 0
  }
  foreach library $libs {
    if { {} == $library } { continue; }
    puts $fh "$library=[usf_resolve_compiled_library_dir $cxl_prop_dir $library]"
  }
  close $fh

  if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
    puts "(DEBUG) - compiled library absolute path updated in xsim.ini: '$ini_file'"
  }

  return 0
}

proc usf_resolve_compiled_library_dir { cxl_prop_dir library } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # internal vhdl libraries
  if { ($library == "ieee"              ) ||
       ($library == "ieee_2008"         ) ||
       ($library == "ieee_proposed"     ) ||
       ($library == "ieee_proposed_2008") ||
       ($library == "std"               ) ||
       ($library == "std_2008"          ) ||
       ($library == "synopsys"          ) ||
       ($library == "synopsys_2008"     ) ||
       ($library == "vl"                ) ||
       ($library == "vl_2008"           ) } {

    set dir "$cxl_prop_dir/vhdl/$library"
    if { [file exists $dir] } {
      return $dir
    }
  }

  # internal system verilog libraries
  if { $library == "uvm" } {
    set dir "$cxl_prop_dir/system_verilog/$library"
    if { [file exists $dir] } {
      return $dir
    }
  }

  # vhdl base libraries
  if { ($library == "unifast" ) ||
       ($library == "unimacro") ||
       ($library == "unisim"  ) } {

    set dir "$cxl_prop_dir/vhdl/$library"
    if { [file exists $dir] } {
      return $dir
    } else {
      set dir "$cxl_prop_dir/ip/$library"
      if { [file exists $dir] } {
        return $dir
      } else {
        set dir "$cxl_prop_dir/$library"
        return $dir
      }
    }
  }

  # verilog base libraries
  if { ($library == "secureip"    ) ||
       ($library == "unifast_ver" ) ||
       ($library == "unimacro_ver") ||
       ($library == "unisims_ver" ) ||
       ($library == "simprims_ver") } {

    set dir "$cxl_prop_dir/verilog/$library"
    if { [file exists $dir] } {
      return $dir
    } else {
      set dir "$cxl_prop_dir/ip/$library"
      if { [file exists $dir] } {
        return $dir
      } else {
        set dir "$cxl_prop_dir/$library"
        return $dir
      }
    }
  }

  # ips
  set dir "$cxl_prop_dir/ip/$library"
  if { [file exists $dir] } {
    return $dir
  }
 
  # default
  set dir "$cxl_prop_dir/$library"
  return $dir
}

proc usf_xsim_write_setup_file {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable a_sim_sv_pkg_libs
  variable l_compiled_libraries

  set filename "xsim.ini"
  set file [file normalize [file join $a_sim_vars(s_launch_dir) $filename]]
  set fh 0

  if {[catch {open $file w} fh]} {
    send_msg_id USF-XSim-011 ERROR "Failed to open file to write ($file)\n"
    return 1
  }

  set b_uvm_added 0

  # add base lib mappings
  set b_add_base_lib_mappings 0
  [catch {set b_add_base_lib_mappings [get_param project.addBaseLibMappingsForXSim]} err]
  if { $b_add_base_lib_mappings } {
    puts $fh "std=\$RDI_DATADIR/xsim/vhdl/std"
    puts $fh "ieee=\$RDI_DATADIR/xsim/vhdl/ieee"
    puts $fh "ieee_proposed=\$RDI_DATADIR/xsim/vhdl/ieee_proposed"
    puts $fh "vl=\$RDI_DATADIR/xsim/vhdl/vl"
    puts $fh "synopsys=\$RDI_DATADIR/xsim/vhdl/synopsys"
    puts $fh "uvm=\$RDI_DATADIR/xsim/system_verilog/uvm"
    puts $fh "secureip=\$RDI_DATADIR/xsim/verilog/secureip"
    puts $fh "unisim=\$RDI_DATADIR/xsim/vhdl/unisim"
    puts $fh "unimacro=\$RDI_DATADIR/xsim/vhdl/unimacro"
    puts $fh "unifast=\$RDI_DATADIR/xsim/vhdl/unifast"
    puts $fh "unisims_ver=\$RDI_DATADIR/xsim/verilog/unisims_ver"
    puts $fh "unimacro_ver=\$RDI_DATADIR/xsim/verilog/unimacro_ver"
    puts $fh "unifast_ver=\$RDI_DATADIR/xsim/verilog/unifast_ver"
    puts $fh "simprims_ver=\$RDI_DATADIR/xsim/verilog/simprims_ver"
    set b_uvm_added 1
  }
 
  if { !$b_uvm_added } { 
    # add uvm mapping for system verilog
    if { $a_sim_vars(b_contain_sv_srcs) } {
      set uvm_lib [xcs_find_uvm_library]
      if { {} != $uvm_lib } {
        puts $fh "uvm=$uvm_lib"
      }
    }
  }

  set design_libs [xcs_get_design_libs $a_sim_vars(l_design_files) 0 0 0]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    set lib_name [string tolower $lib]
    puts $fh "$lib=$a_sim_vars(compiled_design_lib)/$lib_name"
  }

  # if xilinx_vip packages referenced, add mapping
  #if { [llength $a_sim_sv_pkg_libs] > 0 } {
  #  set library "xilinx_vip"
  #  set cxl_prop_dir [usf_xsim_get_compiled_library_dir]
  #  puts $fh "$library=[usf_resolve_compiled_library_dir $cxl_prop_dir $library]"
  #}

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
    if { [string length $a_sim_vars(s_lib_map_path)] > 0 } {
      set dir [file normalize $a_sim_vars(s_lib_map_path)]
      set ini_file [file join $dir $filename]
      if { [file exists $ini_file] } {
        puts $fh "$lib_name=${dir}/$lib_name"
        set b_mapping_set 1
      }
    }
    if { !$b_mapping_set } {
      set dir [get_property "compxlib.xsim_compiled_library_dir" $a_sim_vars(curr_proj)]
      if { {} == $dir } {
        set dir $::env(XILINX_VIVADO)
        set dir [file normalize [file join $dir "data/xsim"]]
      }
      set ini_file [file normalize [file join $dir $filename]]
      if { [file exists $ini_file] } {
        puts $fh "$lib_name=${dir}/$lib_name"
      }
    }
  }
  
  close $fh
}

proc usf_xsim_create_lib_dir {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set design_lib_dir "$a_sim_vars(s_launch_dir)/$a_sim_vars(compiled_design_lib)"

  if { ![file exists $design_lib_dir] } {
    if { [catch {file mkdir $design_lib_dir} error_msg] } {
      send_msg_id USF-XSim-013 ERROR "Failed to create the directory ($design_lib_dir): $error_msg\n"
      return 1
    }
  }
}

proc usf_xsim_write_compile_script { scr_filename_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $scr_filename_arg scr_filename
  variable a_sim_vars

  # step exec mode?
  if { $a_sim_vars(b_exec_step) } {
    return 0
  }

  # write compile.sh/.bat
  set scr_filename "compile";append scr_filename [xcs_get_script_extn "xsim"]
  set scr_file [file normalize [file join $a_sim_vars(s_launch_dir) $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-XSim-015 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  # determine presence of source types 
  set b_contain_verilog_srcs [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]
  if { $a_sim_vars(b_int_compile_glbl) && (!$b_contain_verilog_srcs) } {
    set b_contain_verilog_srcs true 
  }
  if { (!$b_contain_verilog_srcs) && $a_sim_vars(b_force_compile_glbl) } {
    set b_contain_verilog_srcs true 
  }

  # is force no compile?
  if { $b_contain_verilog_srcs && $a_sim_vars(b_force_no_compile_glbl) } {
    set b_contain_verilog_srcs false
  }

  set b_contain_vhdl_srcs [xcs_contains_vhdl $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]
  set b_contain_sc_srcs false
  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    set sc_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC\")"
    set sc_files [xcs_get_c_files $sc_filter $a_sim_vars(b_int_csim_compile_order)]
    if { [llength $sc_files] > 0 } {
      set b_contain_sc_srcs true
    }
  }

  # set lang type flags
  set b_is_pure_verilog [xcs_is_pure_verilog $b_contain_verilog_srcs $b_contain_vhdl_srcs $b_contain_sc_srcs $a_sim_vars(b_contain_cpp_sources) $a_sim_vars(b_contain_c_sources) $a_sim_vars(b_contain_asm_sources)]
  set b_is_pure_vhdl    [xcs_is_pure_vhdl    $b_contain_verilog_srcs $b_contain_vhdl_srcs $b_contain_sc_srcs $a_sim_vars(b_contain_cpp_sources) $a_sim_vars(b_contain_c_sources) $a_sim_vars(b_contain_asm_sources)]
  set b_is_pure_systemc [xcs_is_pure_systemc $b_contain_verilog_srcs $b_contain_vhdl_srcs $b_contain_sc_srcs $a_sim_vars(b_contain_cpp_sources) $a_sim_vars(b_contain_c_sources) $a_sim_vars(b_contain_asm_sources)]
  set b_is_pure_cpp     [xcs_is_pure_cpp     $b_contain_verilog_srcs $b_contain_vhdl_srcs $b_contain_sc_srcs $a_sim_vars(b_contain_cpp_sources) $a_sim_vars(b_contain_c_sources) $a_sim_vars(b_contain_asm_sources)]
  set b_is_pure_c       [xcs_is_pure_c       $b_contain_verilog_srcs $b_contain_vhdl_srcs $b_contain_sc_srcs $a_sim_vars(b_contain_cpp_sources) $a_sim_vars(b_contain_c_sources) $a_sim_vars(b_contain_asm_sources)]
  set b_is_pure_asm     [xcs_is_pure_asm     $b_contain_verilog_srcs $b_contain_vhdl_srcs $b_contain_sc_srcs $a_sim_vars(b_contain_cpp_sources) $a_sim_vars(b_contain_c_sources) $a_sim_vars(b_contain_asm_sources)]

  # write systemc variables
  usf_xsim_write_systemc_variables $fh_scr

  # write tcl pre hook
  usf_xsim_write_tcl_pre_hook $fh_scr

  # cleanup files before recreating
  usf_delete_generated_files

  if { [get_param "project.optimizeScriptGenForSimulation"] } {
    if { $a_sim_vars(b_compile_simmodels) } {
      # write simmodel PRJ for non-precompile flow
      usf_xsim_write_simmodel_prj $fh_scr
    }

    # write systemc prj if design contains systemc sources 
    usf_xsim_write_systemc_prj $b_contain_sc_srcs $b_is_pure_systemc $fh_scr
  
    # write cpp prj if design contains cpp sources 
    usf_xsim_write_cpp_prj $b_is_pure_cpp $fh_scr
  
    # write c prj if design contains c sources 
    usf_xsim_write_c_prj $b_is_pure_c $fh_scr

    # write asm prj if design contains c sources 
    usf_xsim_write_asm_prj $b_is_pure_asm $fh_scr

    # write verilog prj if design contains verilog sources 
    usf_xsim_write_verilog_prj $b_contain_verilog_srcs $fh_scr
    
    # write vhdl prj if design contains verilog sources 
    usf_xsim_write_vhdl_prj $b_contain_verilog_srcs $b_contain_vhdl_srcs $b_is_pure_vhdl $fh_scr

    if {$::tcl_platform(platform) == "unix"} {
      # wait for jobs to finish
      puts $fh_scr "echo \"Waiting for jobs to finish...\""
      if { $b_contain_sc_srcs } {
        puts $fh_scr "wait \$XSC_SYSC_PID"
      }
      if { $a_sim_vars(b_contain_cpp_sources) } {
        puts $fh_scr "wait \$XSC_CPP_PID"
      }
      if { $a_sim_vars(b_contain_c_sources) } {
        puts $fh_scr "wait \$XSC_C_PID"
      }
      if { $a_sim_vars(b_contain_asm_sources) } {
        puts $fh_scr "wait \$XSC_ASM_PID"
      }
      puts $fh_scr "echo \"No pending jobs, compilation finished.\""
    }

  } else {
    # write verilog prj if design contains verilog sources 
    usf_xsim_write_verilog_prj $b_contain_verilog_srcs $fh_scr
    
    # write vhdl prj if design contains verilog sources 
    usf_xsim_write_vhdl_prj $b_contain_verilog_srcs $b_contain_vhdl_srcs $b_is_pure_vhdl $fh_scr
  
    # write systemc prj if design contains systemc sources 
    usf_xsim_write_systemc_prj $b_contain_sc_srcs $b_is_pure_systemc $fh_scr
  
    # write cpp prj if design contains cpp sources 
    usf_xsim_write_cpp_prj $b_is_pure_cpp $fh_scr
  
    # write c prj if design contains c sources 
    usf_xsim_write_c_prj $b_is_pure_c $fh_scr

    # write asm prj if design contains asm sources 
    usf_xsim_write_asm_prj $b_is_pure_asm $fh_scr
  }
   
  # write windows exit code
  usf_xsim_write_windows_exit_code $fh_scr

  close $fh_scr
}

proc usf_xsim_write_elaborate_script { scr_filename_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $scr_filename_arg scr_filename
  variable a_sim_vars

  # step exec mode?
  if { $a_sim_vars(b_exec_step) } {
    return 0
  }

  # write elaborate.sh/.bat
  set scr_filename "elaborate";append scr_filename [xcs_get_script_extn "xsim"]
  set scr_file [file normalize [file join $a_sim_vars(s_launch_dir) $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-XSim-016 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "[xcs_get_shell_env]"
    xcs_write_script_header $fh_scr "elaborate" "xsim"
    xcs_write_version_id $fh_scr "xsim"

    if { [get_param "project.allowSharedLibraryType"] } {
      puts $fh_scr "xv_lib_path=\"$::env(RDI_LIBDIR)\""
    }

    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      if { [file exists $a_sim_vars(ubuntu_lib_dir)] } {
        puts $fh_scr "\[ -z \"\$LIBRARY_PATH\" \] && export LIBRARY_PATH=$a_sim_vars(ubuntu_lib_dir) || export LIBRARY_PATH=$a_sim_vars(ubuntu_lib_dir):\$LIBRARY_PATH"
      }
    }
    puts $fh_scr "\n# catch pipeline exit status"
    xcs_write_pipe_exit $fh_scr
    if { [file exists $a_sim_vars(s_clibs_dir)] } {
      puts $fh_scr "\n# resolve compiled library path in xsim.ini"
      set data_dir [file dirname $a_sim_vars(s_clibs_dir)]
      puts $fh_scr "export RDI_DATADIR=\"[xcs_replace_with_var $data_dir "SIM_VER" "xsim"]\""
    }

    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      set aie_ip_obj [xcs_find_ip "ai_engine"]
      if { $a_sim_vars(b_ref_sysc_lib_env) } {
        puts $fh_scr "\n# set simulation library paths"
        puts $fh_scr "xv_cxl_lib_path=\"[xcs_replace_with_var [usf_xsim_resolve_sysc_lib_path "CLIBS" $a_sim_vars(s_clibs_dir)] "SIM_VER" "xsim"]\""
        puts $fh_scr "xv_cpt_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var [usf_xsim_resolve_sysc_lib_path "SPCPT" $a_sim_vars(sp_cpt_dir)] "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
        puts $fh_scr "xv_ext_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var [usf_xsim_resolve_sysc_lib_path "SPEXT" $a_sim_vars(sp_ext_dir)] "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
        puts $fh_scr "xv_boost_lib_path=\"[usf_xsim_resolve_sysc_lib_path "BOOST" $a_sim_vars(s_boost_dir)]\"\n"
      } else {
        if { $a_sim_vars(b_compile_simmodels) } {
          puts $fh_scr "\n# set simulation library paths"
          puts $fh_scr "xv_cxl_lib_path=\"simlibs\""
          puts $fh_scr "xv_cxl_obj_lib_path=\"$a_sim_vars(compiled_design_lib)\""
        } else {
          puts $fh_scr "\n# set simulation library paths"
          puts $fh_scr "xv_cxl_lib_path=\"[xcs_replace_with_var $a_sim_vars(s_clibs_dir) "SIM_VER" "xsim"]\""
        }
        puts $fh_scr "xv_cpt_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_cpt_dir) "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
        puts $fh_scr "xv_ext_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_ext_dir) "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
        puts $fh_scr "xv_boost_lib_path=\"$a_sim_vars(s_boost_dir)\""
      }
      # for aie
      if { {} != $aie_ip_obj } {
        puts $fh_scr "\n# set header/runtime library path for AIE compiler"
        puts $fh_scr "export CHESSDIR=\"\$XILINX_VITIS/aietools/tps/lnx64/target/chessdir\"\n"
      }
    }

    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      set args [usf_xsim_get_xsc_elab_cmdline_args]
      puts $fh_scr "\n$a_sim_vars(script_cmt_tag) link design libraries"
      puts $fh_scr "echo \"xsc $args\""
      puts $fh_scr "xsc $args"
      xcs_write_exit_code $fh_scr
    }

    set args [usf_xsim_get_xelab_cmdline_args]

    puts $fh_scr "$a_sim_vars(script_cmt_tag) elaborate design"
    puts $fh_scr "echo \"xelab [usf_xsim_escape_quotes $args]\""
    puts $fh_scr "xelab $args"

    xcs_write_exit_code $fh_scr

  } else {
    set log_filename "elaborate_xsc.log"

    puts $fh_scr "@echo off"
    xcs_write_script_header $fh_scr "elaborate" "xsim"
    xcs_write_version_id $fh_scr "xsim"

    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      puts $fh_scr "\n# set simulation library paths"
      puts $fh_scr "set xv_cxl_lib_path=\"[xcs_replace_with_var $a_sim_vars(s_clibs_dir) "SIM_VER" "xsim"]\""
      puts $fh_scr "set xv_cpt_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_cpt_dir) "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
      puts $fh_scr "set xv_ext_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_ext_dir) "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
      puts $fh_scr "set xv_boost_lib_path=\"$a_sim_vars(s_boost_dir)\"\n"

      # set PATH env to reference shared lib's 
      set b_bind_shared_lib 0
      [catch {set b_bind_shared_lib [get_param project.bindSharedLibraryForXSCElab]} err]
      if { $b_bind_shared_lib } {
        puts $fh_scr "set xv_cxl_win_path=$a_sim_vars(s_clibs_dir)"
        set cxl_lib_paths [list]
        variable a_shared_library_path_coln
        foreach {key value} [array get a_shared_library_path_coln] {
          set shared_lib_name $key
          set lib_path        $value
          set lib_name        [file root $shared_lib_name]
          set lib_name        [string trimleft $lib_name {lib}]
          lappend cxl_lib_paths "%xv_cxl_win_path%/ip/$lib_name"
        }
        set cxl_lib_paths_str [join $cxl_lib_paths ";"]
        puts $fh_scr "set PATH=$cxl_lib_paths_str;%PATH%\n"
      }
    }

    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      set args [usf_xsim_get_xsc_elab_cmdline_args]
      puts $fh_scr "\n$a_sim_vars(script_cmt_tag) link design libraries"
      puts $fh_scr "echo \"xsc $args\""
      puts $fh_scr "call xsc $a_sim_vars(s_dbg_sw) $args 2> xsc_err.log"
      puts $fh_scr "set exit_code=%errorlevel%"
      puts $fh_scr "call type xsc.log >> $log_filename"
      puts $fh_scr "call type xsc_err.log >> $log_filename"
      puts $fh_scr "call type xsc_err.log"
      puts $fh_scr "if \"%exit_code%\"==\"1\" goto END"
    }

    set args [usf_xsim_get_xelab_cmdline_args]

    set b_call_script_exit [get_property -quiet "xsim.call_script_exit" $a_sim_vars(fs_obj)]

    puts $fh_scr "$a_sim_vars(script_cmt_tag) elaborate design"
    puts $fh_scr "echo \"xelab [usf_xsim_escape_quotes $args]\""
    puts $fh_scr "call xelab $a_sim_vars(s_dbg_sw) $args"
    puts $fh_scr "if \"%errorlevel%\"==\"0\" goto SUCCESS"
    puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
    puts $fh_scr ":END"

    if { $a_sim_vars(b_scripts_only) && !($b_call_script_exit) } {
      # no exit
    } else {
      puts $fh_scr "exit 1"
    }

    puts $fh_scr ":SUCCESS"

    if { $a_sim_vars(b_scripts_only) && !($b_call_script_exit) } {
      # no exit
    } else {
      puts $fh_scr "exit 0"
    }
  }

  close $fh_scr
}

proc usf_xsim_write_simulate_script { l_sm_lib_paths_arg cmd_file_arg wcfg_file_arg b_add_view_arg scr_filename_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $scr_filename_arg   scr_filename
  upvar $l_sm_lib_paths_arg l_sm_lib_paths
  upvar $cmd_file_arg       cmd_file
  upvar $wcfg_file_arg      wcfg_file
  upvar $b_add_view_arg     b_add_view

  variable a_sim_vars

  # get the wdb file information
  set wdf_file [get_property "xsim.simulate.wdb" $a_sim_vars(fs_obj)]
  set b_add_wdb 0
  if { {} == $wdf_file } {
    set wdf_file $a_sim_vars(s_snapshot);append wdf_file ".wdb"
    #set wdf_file "xsim";append wdf_file ".wdb"
  } else {
    set b_add_wdb 1
    # only filename specified?
    if { {.} == [file dirname $wdf_file] } {
      set wdf_file "$a_sim_vars(s_launch_dir)/$wdf_file"
    }
    set wdf_file [file normalize $wdf_file]
    # is extension not specified?
    if { {.wdb} != [file extension $wdf_file] } {
      append wdf_file ".wdb"
    }
  }

  # get the wcfg file information
  set b_linked_wcfg_exist 0
  set wcfg_files [usf_get_wcfg_files $a_sim_vars(fs_obj)]
  set wdb_filename [file root [file tail $wdf_file]]
  set b_wcfg_files 0
  if { [llength $wcfg_files] > 0 } {
    set b_wcfg_files 1
  }
  if { !$b_wcfg_files } {
    # check WCFG file with the same prefix name present in the WDB file
    set wcfg_file_in_wdb_dir ${wdb_filename};append wcfg_file_in_wdb_dir ".wcfg"
    #set wcfg_file_in_wdb_dir [file normalize [file join $a_sim_vars(s_launch_dir) $wcfg_file_in_wdb_dir]]
    if { [file exists $wcfg_file_in_wdb_dir] } {
      set b_linked_wcfg_exist 1
    }
  }

  set b_add_wave 0
  set b_add_view 0

  # wcfg file specified?
  if { $b_wcfg_files } {
    # pass -view
    set b_add_view 1
  } elseif { $b_linked_wcfg_exist } {
    # do not pass "add wave" and "-view"
  } else {
    set b_add_wave 1
  }

  set cmd_file $a_sim_vars(s_sim_top);append cmd_file ".tcl"
  if { {} == [get_property "xsim.simulate.custom_tcl" $a_sim_vars(fs_obj)] } {
    # step exec mode?
    if { $a_sim_vars(b_exec_step) } {
      # exec-mode: cmd file should be present
    } else {
      usf_xsim_write_cmd_file $cmd_file $b_add_wave
    }
  } else {
    # step exec mode?
    if { $a_sim_vars(b_exec_step) } {
      # exec-mode: custom tcl file should be present
    } else {
      # custom tcl specified, delete existing auto generated tcl file from run dir
      set cmd_file [file normalize [file join $a_sim_vars(s_launch_dir) $cmd_file]]
      if { [file exists $cmd_file] } {
        [catch {file delete -force $cmd_file} error_msg]
      }
    }
  }

  # step exec mode?
  if { $a_sim_vars(b_exec_step) } {
    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      # exec-mode: cmd file should be present but need sim-model shared lib paths for running xsim in tcl console
      # for setting LD_LIBRARY_PATH (simulate step will call setup always since the vars needs to be set again)
      set install_path {}
      set vivado_install_path [usf_get_vivado_install_path install_path]
      set l_sm_lib_paths [usf_get_sm_lib_paths $install_path]
    }
  } else {
    if { [usf_xsim_write_scr_file $cmd_file $wcfg_files $b_add_view $wdf_file $b_add_wdb l_sm_lib_paths] } {
      return 1
    }
  }

  set b_batch 0
  set cmd_args [usf_xsim_get_xsim_cmdline_args $cmd_file $wcfg_files $b_add_view $wdf_file $b_add_wdb $b_batch]

  if { $a_sim_vars(b_scripts_only) } {
    # scripts only
  } else {
    # standalone mode
    set standalone_mode [get_property -quiet "xelab.standalone" $a_sim_vars(fs_obj)]
    if { $standalone_mode } {
      send_msg_id USF-XSim-104 INFO "Skipping simulation step (not applicable in standalone mode)"
    } else {
      set step "simulate"
      send_msg_id USF-XSim-061 INFO "Executing '[string toupper $step]' step in '$a_sim_vars(s_launch_dir)'"
      send_msg_id USF-XSim-098 INFO   "*** Running xsim\n"
      send_msg_id USF-XSim-099 STATUS "   with args \"$cmd_args\"\n"
    }
  }

  return $cmd_args
}

proc usf_xsim_write_scr_file { cmd_file wcfg_files b_add_view wdf_file b_add_wdb l_sm_lib_paths_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $l_sm_lib_paths_arg l_sm_lib_paths 

  variable a_sim_vars

  set scr_filename "simulate";append scr_filename [xcs_get_script_extn "xsim"]
  set scr_file [file normalize [file join $a_sim_vars(s_launch_dir) $scr_filename]]
  set fh_scr 0
  if {[catch {open $scr_file w} fh_scr]} {
    send_msg_id USF-XSim-018 ERROR "Failed to open file to write ($scr_file)\n"
    return 1
  }

  # standalone mode
  set standalone_mode [get_property -quiet "xelab.standalone" $a_sim_vars(fs_obj)]
  set snapshot_dir "$a_sim_vars(s_snapshot)"

  set b_batch 1
  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "[xcs_get_shell_env]"
    xcs_write_script_header $fh_scr "simulate" "xsim"
    xcs_write_version_id $fh_scr "xsim"
    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      if { [file exists $a_sim_vars(ubuntu_lib_dir)] } {
        puts $fh_scr "\[ -z \"\$LIBRARY_PATH\" \] && export LIBRARY_PATH=$a_sim_vars(ubuntu_lib_dir) || export LIBRARY_PATH=$a_sim_vars(ubuntu_lib_dir):\$LIBRARY_PATH"
      }
    }
    puts $fh_scr "\n# catch pipeline exit status"
    xcs_write_pipe_exit $fh_scr
    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      set aie_ip_obj [xcs_find_ip "ai_engine"]
      if { $a_sim_vars(b_ref_sysc_lib_env) } {
        puts $fh_scr "\n# set simulation library paths"
        puts $fh_scr "export xv_cxl_lib_path=\"[xcs_replace_with_var [usf_xsim_resolve_sysc_lib_path "CLIBS" $a_sim_vars(s_clibs_dir)] "SIM_VER" "xsim"]\""
        puts $fh_scr "export xv_cxl_ip_path=\"\$xv_cxl_lib_path/ip\""
        puts $fh_scr "export xv_cpt_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var [usf_xsim_resolve_sysc_lib_path "SPCPT" $a_sim_vars(sp_cpt_dir)] "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
        puts $fh_scr "xv_ext_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var [usf_xsim_resolve_sysc_lib_path "SPEXT" $a_sim_vars(sp_ext_dir)] "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
      } else {
        if { $a_sim_vars(b_compile_simmodels) } {
          puts $fh_scr "\n# set simulation library paths"
          puts $fh_scr "xv_cxl_lib_path=\"simlibs\""
          puts $fh_scr "xv_cxl_obj_lib_path=\"$a_sim_vars(compiled_design_lib)\""
        } else {
          puts $fh_scr "\n# set simulation library paths"
          puts $fh_scr "export xv_cxl_lib_path=\"[xcs_replace_with_var $a_sim_vars(s_clibs_dir) "SIM_VER" "xsim"]\""
          puts $fh_scr "export xv_cxl_ip_path=\"\$xv_cxl_lib_path/ip\""
        }
        puts $fh_scr "export xv_cpt_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_cpt_dir) "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
        puts $fh_scr "xv_ext_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_ext_dir) "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
      }
      # for aie
      if { {} != $aie_ip_obj } {
        puts $fh_scr "\n# set header/runtime library path for AIE compiler"
        puts $fh_scr "export CHESSDIR=\"\$XILINX_VITIS/aietools/tps/lnx64/target/chessdir\""
        set aie_work_dir $a_sim_vars(s_aie_work_dir)
        if { {} != $aie_work_dir } {
          puts $fh_scr "export AIE_WORK_DIR=\"$aie_work_dir\""
        }
      }
    }
    
    # TODO: once xsim picks the "so"s path at runtime , we can remove the following code
    if { [get_param "project.allowSharedLibraryType"] } {
      puts $fh_scr "xv_lib_path=\"$::env(RDI_LIBDIR)\""
      set args_list [list]
      foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects $a_sim_vars(fs_obj)] {
        set file_type [get_property "file_type" $file]
        set file_dir [file dirname $file] 
        set file_name [file tail $file] 
        if { $file_type == "Shared Library" } {
          set file_dir "[xcs_get_relative_file_path $file_dir $a_sim_vars(s_launch_dir)]"
          if {[info exists a_shared_lib_dirs($file_dir)] == 0} {
            set a_shared_lib_dirs($file_dir) $file_dir
            lappend args_list "$file_dir"
          }
        }
      }
      if { [llength $args_list] > 0 } {
        set cmd_args [join $args_list ":"]
        if { [get_param "project.copyShLibsToCurrRunDir"] } {
          puts $fh_scr "\nexport LD_LIBRARY_PATH=\$PWD:\$xv_lib_path:\$LD_LIBRARY_PATH\n"
        } else {
          puts $fh_scr "\nexport LD_LIBRARY_PATH=$cmd_args:\$xv_lib_path:\$LD_LIBRARY_PATH\n"
        }
      }
      
    }

    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      set install_path {}
      set vivado_install_path [usf_get_vivado_install_path install_path]
      set l_sm_lib_paths [usf_get_sm_lib_paths $install_path]

      if { $a_sim_vars(b_ref_sysc_lib_env) } {
        puts $fh_scr "\nxv_ref_path=\$\{VIVADO_LOC:-\"\$XILINX_VIVADO\"\}"
      } else {
        puts $fh_scr "\nxv_ref_path=\$\{VIVADO_LOC:-\"$vivado_install_path\"\}"
      }

      set cxl_dirs [list]
      foreach sm_path $l_sm_lib_paths {
        set b_resolved 0
        set resolved_path [xcs_resolve_sim_model_dir "xsim" $sm_path $a_sim_vars(s_clibs_dir) $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved $a_sim_vars(b_compile_simmodels) "obj"]
        if { $b_resolved } {
          lappend cxl_dirs $resolved_path
        } else {
          lappend cxl_dirs $sm_path
        }
      }
      set sm_lib_path_str [join $cxl_dirs ":"]
      puts $fh_scr "xv_lib_path=\"\$xv_ref_path/lib/lnx64.o/Default:\$xv_ref_path/lib/lnx64.o\""

      set ld_path_str "export LD_LIBRARY_PATH=\$PWD:\$xv_lib_path:$sm_lib_path_str"
      set ip_obj [xcs_find_ip "ai_engine"]
      if { {} != $ip_obj } {
        append ld_path_str ":\$XILINX_VITIS/aietools/lib/lnx64.o"
      }
      puts $fh_scr "\n# set shared library paths"
      puts $fh_scr "$ld_path_str:\$LD_LIBRARY_PATH\n"
    }

    if { $standalone_mode } {
      puts $fh_scr "echo \"./xsim.dir/${snapshot_dir}/axsim \$*\""
      puts $fh_scr "./xsim.dir/${snapshot_dir}/axsim \$*"
    } else {
      set cmd_args [usf_xsim_get_xsim_cmdline_args $cmd_file $wcfg_files $b_add_view $wdf_file $b_add_wdb $b_batch]
      puts $fh_scr "$a_sim_vars(script_cmt_tag) simulate design"
      puts $fh_scr "echo \"xsim $cmd_args\""
      puts $fh_scr "xsim $cmd_args"
    }
    xcs_write_exit_code $fh_scr
  } else {
    puts $fh_scr "@echo off"
    xcs_write_script_header $fh_scr "simulate" "xsim"
    xcs_write_version_id $fh_scr "xsim"

    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      puts $fh_scr "\n# set simulation library paths"
      puts $fh_scr "set xv_cxl_lib_path=\"[xcs_replace_with_var $a_sim_vars(s_clibs_dir) "SIM_VER" "xsim"]\""
      puts $fh_scr "set xv_cpt_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_cpt_dir) "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
      puts $fh_scr "set xv_ext_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_ext_dir) "SIM_VER" "xsim"] "GCC_VER" "xsim"]\"\n"
      # set PATH env to reference shared lib's 
      set b_en_code true
      if { $b_en_code } {
        set b_bind_shared_lib 0
        [catch {set b_bind_shared_lib [get_param project.bindSharedLibraryForXSCElab]} err]
        if { $b_bind_shared_lib } {
          puts $fh_scr "set xv_cxl_win_path=$a_sim_vars(s_clibs_dir)"
          set cxl_lib_paths [list]
          variable a_shared_library_path_coln
          foreach {key value} [array get a_shared_library_path_coln] {
            set shared_lib_name $key
            set lib_path        $value
            set lib_name        [file root $shared_lib_name]
            set lib_name        [string trimleft $lib_name {lib}]
            lappend cxl_lib_paths "%xv_cxl_win_path%/ip/$lib_name"
          }
          set cxl_lib_paths_str [join $cxl_lib_paths ";"]
          puts $fh_scr "set PATH=$cxl_lib_paths_str;%PATH%\n"
        }
      }
    }

    if { $standalone_mode } {
      puts $fh_scr "echo \"./xsim.dir/${snapshot_dir}/axsim \$*\""
      puts $fh_scr "call ./xsim.dir/${snapshot_dir}/axsim %*"
    } else {
      set cmd_args [usf_xsim_get_xsim_cmdline_args $cmd_file $wcfg_files $b_add_view $wdf_file $b_add_wdb $b_batch]
      set b_call_script_exit [get_property -quiet "xsim.call_script_exit" $a_sim_vars(fs_obj)]
      puts $fh_scr "$a_sim_vars(script_cmt_tag) simulate design"
      puts $fh_scr "echo \"xsim $cmd_args\""
      puts $fh_scr "call xsim $a_sim_vars(s_dbg_sw) $cmd_args"
    }
    puts $fh_scr "if \"%errorlevel%\"==\"0\" goto SUCCESS"
    puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
    puts $fh_scr ":END"
    if { $a_sim_vars(b_scripts_only) && !($b_call_script_exit) } {
      # no exit
    } else {
      puts $fh_scr "exit 1"
    }
    puts $fh_scr ":SUCCESS"
    if { $a_sim_vars(b_scripts_only) && !($b_call_script_exit) } {
      # no exit
    } else {
      puts $fh_scr "exit 0"
    }
  }
  close $fh_scr
  
  return 0
}

proc usf_get_vivado_install_path { install_path_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $install_path_arg install_path

  # default Vivado install path
  set vivado_install_path $::env(XILINX_VIVADO)
	
  # custom Vivado install path set via VIVADO_LOC
  set custom_vivado_install_path ""
  if { [info exists ::env(VIVADO_LOC)] } {
    set custom_vivado_install_path $::env(VIVADO_LOC)
  }
  
  # get the install path
  set install_path $vivado_install_path
  if { ($custom_vivado_install_path != "") && ([file exists $custom_vivado_install_path]) && ([file isdirectory $custom_vivado_install_path]) } {
    set install_path $custom_vivado_install_path
  }

  return $vivado_install_path
}

proc usf_get_sm_lib_paths { install_path } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_shared_library_path_coln

  set libraries    [list]
  set sm_lib_paths [list]

  foreach {library lib_dir} [array get a_shared_library_path_coln] {
    lappend libraries $library
    set sm_lib_dir [file normalize $lib_dir]
    set sm_lib_dir [regsub -all {[\[\]]} $sm_lib_dir {/}]

    set match_string "/data/xsim/ip/"
    set b_processed_lib_path [usf_append_sm_lib_path sm_lib_paths $install_path $sm_lib_dir $match_string]
    if { !$b_processed_lib_path } {
      set match_string "/data/simmodels/xsim/"
      set b_processed_lib_path [usf_append_sm_lib_path sm_lib_paths $install_path $sm_lib_dir $match_string]
    }

    if { !$b_processed_lib_path } {
      lappend sm_lib_paths $sm_lib_dir
    }
  }
  return $sm_lib_paths
}

proc usf_get_wcfg_files { fs } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  set uniq_file_set [list]
  #set wcfg_files [split [get_property "xsim.view" $fs] { }]
  set filter "IS_ENABLED == 1"

  set wcfg_files [get_files -quiet -of_objects [get_filesets $fs] -filter $filter *.wcfg]
  if { [llength $wcfg_files] > 0 } {
    foreach file $wcfg_files {
      set file [string map {\\ /} $file]
      if { [lsearch -exact $uniq_file_set $file] == -1 } {
        lappend uniq_file_set $file
      }
    }
  }
  return $uniq_file_set 
}

proc usf_xsim_get_xelab_cmdline_args {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable l_compiled_libraries

  set args_list [list]

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    if { $a_sim_vars(b_gcc_version) } {
      lappend args_list "--gcc_version gcc-$a_sim_vars(s_gcc_version)"
    }
  }

  set id [get_property "id" $a_sim_vars(curr_proj)]
  if { {} != $id } {
    #lappend args_list "-wto $id"
  }

  # --incr
  if { [get_property "incremental" $a_sim_vars(fs_obj)] } {
    lappend args_list "--incr"
  }

  set standalone_mode [get_property -quiet "xelab.standalone" $a_sim_vars(fs_obj)]
  if { $standalone_mode } { lappend args_list "--standalone" }

  if { $standalone_mode } {
    send_msg_id USF-XSim-105 INFO "Debug level is not supported for standalone mode, setting it to 'off'\n"
    lappend args_list "--debug off"
    lappend args_list "--xdci"
  } else {
    # --debug
    set value [get_property "xsim.elaborate.debug_level" $a_sim_vars(fs_obj)]
    lappend args_list "--debug $value"
  }

  # --rangecheck
  set value [get_property "xsim.elaborate.rangecheck" $a_sim_vars(fs_obj)]
  if { $value } { lappend args_list "--rangecheck" }

  # --dll
  set value [get_property "xelab.dll" $a_sim_vars(fs_obj)]
  if { $value } { lappend args_list "--dll" }

  # --relax
  set value [get_property "xsim.elaborate.relax" $a_sim_vars(fs_obj)]
  if { $value } { lappend args_list "--relax" }

  # --mt
  set max_threads [get_param general.maxthreads]
  set mt_level [get_property "xsim.elaborate.mt_level" $a_sim_vars(fs_obj)]
  switch -regexp -- $mt_level {
    {auto} {
      if { {1} == $max_threads } {
        # no op, keep auto ('1' is not supported by xelab)
      } else {
        set mt_level $max_threads
      }
    }
    {off} {
      # use 'off' (turn off multi-threading)
    }
    default {
      # use 2, 4, 8, 16, 32
    }
  }
  
  lappend args_list "--mt $mt_level"

  set netlist_mode [get_property "nl.mode" $a_sim_vars(fs_obj)]

  set sim_flow $a_sim_vars(s_simulation_flow)
  if { ({post_synth_sim} == $sim_flow || {post_impl_sim} == $sim_flow) && ({timesim} == $netlist_mode) } {
     set delay [get_property "xsim.elaborate.sdf_delay" $a_sim_vars(fs_obj)]
     if { {sdfmin} == $delay } { lappend args_list "--mindelay" }
     if { {sdfmax} == $delay } { lappend args_list "--maxdelay" }
  }

  set b_bind_dpi_c false
  [catch {set b_bind_dpi_c [get_param project.bindGTDPICModel]} err]
  set ip_obj [xcs_find_ip "gt_quad_base"]
  if { {} != $ip_obj } {
    set gt_lib         "gtye5_quad"
    set shared_lib_dir "verilog/secureip"

    # make sure we have the clibs for non-precompile flow
    if { ([string length $a_sim_vars(s_clibs_dir)] == 0) && (!$a_sim_vars(b_use_static_lib)) } {
      usf_xsim_set_clibs_for_non_precompile_flow
      set a_sim_vars(s_clibs_dir) $a_sim_vars(compiled_library_dir)
    }

    if { ([string length $a_sim_vars(s_clibs_dir)] == 0) || (![file exists $a_sim_vars(s_clibs_dir)]) } {
      send_msg_id USF-XSim-010 WARNING "Compiled library directory path does not exist! '$a_sim_vars(s_clibs_dir)'\n"
    } else {
      # default install location
      set install_secureip "$a_sim_vars(s_clibs_dir)/$shared_lib_dir"
      if { [file exists $install_secureip] } {
        if { !$a_sim_vars(b_absolute_path) } {
          #set shared_lib_dir "[xcs_get_relative_file_path $install_secureip $a_sim_vars(s_launch_dir)]"
          set shared_lib_dir $install_secureip
        } else {
          set shared_lib_dir $install_secureip
        }
      } else {
        set shared_lib_dir "$a_sim_vars(s_clibs_dir)/secureip"
        send_msg_id USF-XSim-010 WARNING "Default compiled library path for secureip library does not exist ($install_secureip). Using library from '$shared_lib_dir'.\n"
        if { !$a_sim_vars(b_absolute_path) } {
          #set shared_lib_dir "[xcs_get_relative_file_path $shared_lib_dir $a_sim_vars(s_launch_dir)]"
          set shared_lib_dir $shared_lib_dir
        }
      }
      set shared_lib_dir [string map {\\ /} $shared_lib_dir]
    }
    if { $b_bind_dpi_c } {
      lappend args_list "-sv_root \"$shared_lib_dir\" -sv_lib $gt_lib"
    }
  }
 
  if { [get_param "project.allowSharedLibraryType"] } {
    foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_filesets $a_sim_vars(fs_obj)]] {
      set file_type [get_property "file_type" $file]
      if { {Shared Library} == $file_type } {
        set file_dir [file dirname $file]
        set file_dir "[xcs_get_relative_file_path $file_dir $a_sim_vars(s_launch_dir)]"

        if { [get_param "project.copyShLibsToCurrRunDir"] } {
          if { [catch {file copy -force $file $a_sim_vars(s_launch_dir)} error_msg] } {
            send_msg_id USF-XSim-010 ERROR "Failed to copy file ($file): $error_msg\n"
          } else {
            send_msg_id USF-XSim-011 INFO "File '$file' copied to run dir:'$a_sim_vars(s_launch_dir)'\n"
          }
          set file_dir "."
        }
        set file_name [file tail $file]
        lappend args_list "-sv_root \"$file_dir\" -sv_lib $file_name"
      }
    }
  }

  
  set unique_sysc_incl_dirs [list]
  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    set lib_extn ".dll"
    if {$::tcl_platform(platform) == "unix"} {
      set lib_extn ".so"
    }
    set b_en_code true
    if { $b_en_code } {
      variable a_shared_library_path_coln
      foreach {key value} [array get a_shared_library_path_coln] {
        set shared_lib_name $key
        set lib_path        $value
        set lib_name        [file root $shared_lib_name]

        #send_msg_id USF-XSim-104 INFO "Referencing library '$lib_name' from '$lib_path'\n"
 
        # relative path to library include dir
        set incl_dir "$lib_path/include"
        set b_resolved 0
        set resolved_path [xcs_resolve_sim_model_dir "xsim" $incl_dir $a_sim_vars(s_clibs_dir) $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved $a_sim_vars(b_compile_simmodels) "include"]
        if { $b_resolved } {
          set incl_dir $resolved_path
        } else {
          set incl_dir "[xcs_get_relative_file_path $incl_dir $a_sim_vars(s_launch_dir)]"
        }

        if { [lsearch -exact $unique_sysc_incl_dirs $incl_dir] == -1 } {
          lappend unique_sysc_incl_dirs $incl_dir
        }

        # is clibs, protected or ext dir? replace with variable
        set b_resolved 0
        set resolved_path [xcs_resolve_sim_model_dir "xsim" $lib_path $a_sim_vars(s_clibs_dir) $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved $a_sim_vars(b_compile_simmodels) "obj"]
        if { $b_resolved } {
          set rel_lib_path $resolved_path
        } else {
          set rel_lib_path  "[xcs_get_relative_file_path $lib_path $a_sim_vars(s_launch_dir)]"
        }

        set sc_args "-sv_root \"$rel_lib_path\" -sc_lib ${lib_name}${lib_extn} --include \"$incl_dir\""
        #puts sc_args=$sc_args
        lappend args_list $sc_args
      }
    }

    # bind user specified systemC/C/C++ libraries
    set l_link_sysc_libs [get_property "xsim.elaborate.link.sysc" $a_sim_vars(fs_obj)]
    foreach lib $l_link_sysc_libs {
      set lib_path [file dirname $lib]
      set lib_name [file tail $lib]
      set sc_args "-sv_root \"$lib_path\" -sc_lib ${lib_name}"
      lappend args_list $sc_args
    }
    set l_link_c_libs [get_property "xsim.elaborate.link.c" $a_sim_vars(fs_obj)]
    foreach lib $l_link_c_libs {
      set lib_path [file dirname $lib]
      set lib_name [file tail $lib]
      set sc_args "-sv_root \"$lib_path\" -sc_lib ${lib_name}"
      lappend args_list $sc_args
    }
  }

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    variable l_systemc_incl_dirs
    set l_incl_dir [list]
    set filter  "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC Header\")" 
    set prefix_ref_dir false
    foreach incl_dir [xcs_get_c_incl_dirs "xsim" $a_sim_vars(s_launch_dir) $a_sim_vars(s_boost_dir) $filter $a_sim_vars(dynamic_repo_dir) false $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
      if { [lsearch -exact $unique_sysc_incl_dirs $incl_dir] == -1 } {
        lappend unique_sysc_incl_dirs $incl_dir
        lappend args_list "--include \"$incl_dir\""
      }
    }
    if { [llength $l_systemc_incl_dirs] > 0 } {
      foreach incl_dir $l_systemc_incl_dirs {
        if { [lsearch -exact $unique_sysc_incl_dirs $incl_dir] == -1 } {
          lappend unique_sysc_incl_dirs $incl_dir
          lappend args_list "--include \"$incl_dir\""
        }
      }
    }
  
    foreach incl_dir [get_property "systemc_include_dirs" $a_sim_vars(fs_obj)] {
      if { !$a_sim_vars(b_absolute_path) } {
        set incl_dir "[xcs_get_relative_file_path $incl_dir $a_sim_vars(s_launch_dir)]"
      }
      if { [lsearch -exact $unique_sysc_incl_dirs $incl_dir] == -1 } {
        lappend unique_sysc_incl_dirs $incl_dir
        lappend args_list "--include \"$incl_dir\""
      }
    }
  }

  # -i
  #set unique_incl_dirs [list]
  #foreach incl_dir [get_property "include_dirs" $a_sim_vars(fs_obj)] {
  #  if { [lsearch -exact $unique_incl_dirs $incl_dir] == -1 } {
  #    lappend unique_incl_dirs $incl_dir
  #    lappend args_list "-i $incl_dir"
  #  }
  #}

  # -d (verilog macros)
  #set v_defines [get_property "verilog_define" $a_sim_vars(fs_obj)]
  #if { [llength $v_defines] > 0 } {
  #  foreach element $v_defines {
  #    set key_val_pair [split $element "="]
  #    set name [lindex $key_val_pair 0]
  #    set val  [lindex $key_val_pair 1]
  #    set str "$name"
  #    if { [string length $val] > 0 } {
  #      set str "$str=$val"
  #    }
  #    lappend args_list "-d \"$str\""
  #  }
  #}

  # -generic_top (verilog macros)
  set v_generics [get_property "generic" $a_sim_vars(fs_obj)]
  if { [llength $v_generics] > 0 } {
    foreach element $v_generics {
      set key_val_pair [split $element "="]
      set name [lindex $key_val_pair 0]
      set val  [lindex $key_val_pair 1]
      set str "$name="
      if { [string length $val] > 0 } {
        set str "$str$val"
      }
      lappend args_list "-generic_top \"$str\""
    }
  }

  # coverage options
  set cc_name     [get_property "xsim.elaborate.coverage.name"       $a_sim_vars(fs_obj)]
  set cc_dir      [get_property "xsim.elaborate.coverage.dir"        $a_sim_vars(fs_obj)]
  set cc_lib      [get_property "xsim.elaborate.coverage.library"    $a_sim_vars(fs_obj)]
  set cc_cell_def [get_property "xsim.elaborate.coverage.celldefine" $a_sim_vars(fs_obj)]

  if { {} != $cc_name } { lappend args_list "-cov_db_name $cc_name" }
  if { {} != $cc_dir  } { lappend args_list "-cov_db_dir $cc_dir" }

  if { $cc_lib        } { lappend args_list "-cc_libs"        }
  if { $cc_cell_def   } { lappend args_list "-cc_celldefines" }
 
  set cc_types [get_property "xsim.elaborate.coverage.type" $a_sim_vars(fs_obj)]; # cc_types = statement branch condition all
  #
  # 1. convert statement/branch/condition/toggle to s/b/c/t and append to values list
  # 2. throw error for invalid cc type
  # 3. either statement (s)/branch (b)/condition (c)/toggle (t)  or all (sbct) allowed else error
  # 4. if line specified, print deprecation warning and continue with statement
  #
  if { {} != $cc_types } {
    set values [list]
    set l_cc_types [split $cc_types { }]
    foreach type $l_cc_types {
      set type [string tolower [string trim $type]]
      switch $type {
        {line}      -
        {statement} -
        {s}         {
          set id "s";
          if { ([lsearch -exact $values $id] == -1) } {
            lappend values $id
          }
          if { {line} == $type } {
            send_msg_id USF-XSim-017 WARNING "Coverage type 'Line' is deprecated, please use equivalent type 'Statement' instead.\n"
          }
        }
        {branch}    -
        {b}         { set id "b";   if { ([lsearch -exact $values $id] == -1) } { lappend values $id } }
        {condition} -
        {c}         { set id "c";   if { ([lsearch -exact $values $id] == -1) } { lappend values $id } }
        {toggle}    -
        {t}         { set id "t";   if { ([lsearch -exact $values $id] == -1) } { lappend values $id } }
        {all}       -
        {sbct}      {
                      if { ([lsearch -exact $values "s"] == -1) } { lappend values "s" }
                      if { ([lsearch -exact $values "b"] == -1) } { lappend values "b" }
                      if { ([lsearch -exact $values "c"] == -1) } { lappend values "c" }
                      if { ([lsearch -exact $values "t"] == -1) } { lappend values "t" }
                    }
        default     { 
          set other_type $type 
          set b_print_warning 1
          # could be 'sb' (without space?)
          foreach id [split $other_type {}] {
            switch $id {
              {s} -
              {b} -
              {c} -
              {t} { if { ([lsearch -exact $values $id] == -1) } { lappend values $id } }
              default {
                if { $b_print_warning } {
                  [catch {send_msg_id USF-XSim-020 ERROR "Invalid coverage type '$id' specified for 'XSIM.ELABORATE.COVERAGE.TYPE' property (allowed types: Statement (or s) Branch (or b) Condition (or c) Toggle (or t) or All (or sbct))\n"} err]
                  set b_print_warning 0
                }
              }
            }
          }
        }
      }
    }
    set cc_value [join $values {}]
    if { [llength $cc_value] > 0 } {
      lappend args_list "-cc_type $cc_value"
    }
  }

  # override local param
  set override_param false
  [catch {set override_param [get_property -quiet "testbench_param_override" $a_sim_vars(fs_obj)]} msg]
  if { $override_param } {
    lappend args_list "-ignore_localparam_override"
  }

  # design source libs
  set design_libs [xcs_get_design_libs $a_sim_vars(l_design_files) 1 1 1]
  foreach lib $design_libs {
    if {[string length $lib] == 0} { continue; }
    lappend args_list "-L $lib"
  }
  
  # add uvm
  if { $a_sim_vars(b_contain_sv_srcs) } {
    lappend args_list "-L uvm"
  }

  if { $a_sim_vars(b_enable_netlist_sim) && $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) && ({} != $a_sim_vars(sp_xlnoc_bd_obj)) } {
    foreach noc_lib [xcs_get_noc_libs_for_netlist_sim $sim_flow $a_sim_vars(s_type)] {
      if { [regexp {^noc_nmu_v} $noc_lib] } { continue; }
      lappend args_list "-L $noc_lib"
    }
  }

  # add xilinx vip library
  if { [get_param "project.usePreCompiledXilinxVIPLibForSim"] } {
    if { [xcs_design_contain_sv_ip] } {
      lappend args_list "-L xilinx_vip"
    }
  }

  # add simulation libraries
  # post* simulation
  if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    if { [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || ({Verilog} == $a_sim_vars(s_target_lang)) } {
      if { {timesim} == $netlist_mode } {
        lappend args_list "-L simprims_ver"
      } else {
        lappend args_list "-L unisims_ver"
      }
    }
  }

  # behavioral simulation
  set b_compile_unifast 0
  set simulator_language [string tolower [get_property "simulator_language" $a_sim_vars(curr_proj)]]
  if { ([get_param "simulation.addUnifastLibraryForVhdl"]) && ({vhdl} == $simulator_language) } {
    set b_compile_unifast [get_property "unifast" $a_sim_vars(fs_obj)]
  }
  if { ([xcs_contains_vhdl $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast } {
      lappend args_list "-L unifast"
    }
  }

  set b_compile_unifast [get_property "unifast" $a_sim_vars(fs_obj)]
  if { ([xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast } {
      lappend args_list "-L unifast_ver"
    }
    lappend args_list "-L unisims_ver"
    lappend args_list "-L unimacro_ver"
  }

  if { $a_sim_vars(b_int_compile_glbl) || $a_sim_vars(b_force_compile_glbl) } {
    if { ([lsearch -exact $args_list "unisims_ver"] == -1) } {
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip unisims_ver
      } else {
        lappend args_list "-L unisims_ver"
      }
    }
  }

  # add secureip
  lappend args_list "-L secureip"

  # sip cores
  if { ("versal" == [rdi::get_family -arch]) && $a_sim_vars(b_int_bind_sip_cores) } {
    lappend args_list "-L hnicx"
    lappend args_list "-L cpm5n"
  }
  
  # RTL kernel
  if { [info exists a_sim_vars(b_int_rtl_kernel_mode)] } {
    if { $a_sim_vars(b_int_rtl_kernel_mode) } {
      if { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
        if { ([lsearch -exact $args_list "xpm"] == -1) } {
          lappend args_list "-L xpm"
        }
      }
    }
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
    # pass xpm library reference for behavioral simulation only
    if { {behav_sim} == $sim_flow } {
      lappend args_list "-L xpm"
    }
  }

  # add ap lib
  variable l_hard_blocks
  if { [llength $l_hard_blocks] > 0 } {
    lappend args_list "-L aph"
  }

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    lappend args_list "-sv_root \".\" -sc_lib libdpi${lib_extn}"
  }

  # snapshot
  lappend args_list "--snapshot $a_sim_vars(s_snapshot)"

  set path_delay 0
  set int_delay 0
  set tpd_prop "TRANSPORT_PATH_DELAY"
  set tid_prop "TRANSPORT_INT_DELAY"
  if { [lsearch -exact [list_property -quiet $a_sim_vars(fs_obj)] $tpd_prop] != -1 } {
    set path_delay [get_property $tpd_prop $a_sim_vars(fs_obj)]
  }
  if { [lsearch -exact [list_property -quiet $a_sim_vars(fs_obj)] $tid_prop] != -1 } {
    set int_delay [get_property $tid_prop $a_sim_vars(fs_obj)]
  }

  # avoid pulse swallowing for timing
  if { ({post_synth_sim} == $sim_flow || {post_impl_sim} == $sim_flow) && ({timesim} == $netlist_mode) } {
    lappend args_list "-transport_int_delays"
    lappend args_list "-pulse_r $path_delay"
    lappend args_list "-pulse_int_r $int_delay"
    lappend args_list "-pulse_e $path_delay"
    lappend args_list "-pulse_int_e $int_delay"
  }

  variable l_hard_blocks
  foreach hb $l_hard_blocks {
    set hb_wrapper "xil_defaultlib.${hb}_sim_wrapper"
    lappend args_list "$hb_wrapper"
  }

  # add top's
  set top_level_inst_names [usf_xsim_get_top_level_instance_names]
  foreach top $top_level_inst_names {
    lappend args_list "$top"
  }

  # add glbl top
  usf_add_glbl_top_instance args_list $top_level_inst_names
  lappend args_list "-log elaborate.log"

  # other options
  set other_opts [get_property "xsim.elaborate.xelab.more_options" $a_sim_vars(fs_obj)]
  if { {} != $other_opts } {
    lappend args_list "$other_opts"
  }

  set cmd_args [join $args_list " "]
  return $cmd_args
}

proc usf_xsim_get_xsc_elab_cmdline_args {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set args_list [list]

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    if { $a_sim_vars(b_gcc_version) } {
      lappend args_list "--gcc_version gcc-$a_sim_vars(s_gcc_version)"
    }
  }

  set lib_extn ".dll"
  if {$::tcl_platform(platform) == "unix"} {
    set lib_extn ".so"
    lappend args_list "--shared"
  } else {
    lappend args_list "--shared_systemc"
  }

  # other options
  set other_opts [get_property "xsim.elaborate.xsc.more_options" $a_sim_vars(fs_obj)]
  if { {} != $other_opts } {
    lappend args_list "$other_opts"
  }
  lappend args_list "-lib $a_sim_vars(default_top_library)"

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    set shared_ip_libs [xcs_get_shared_ip_libraries $a_sim_vars(s_clibs_dir)]
    if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
      puts "------------------------------------------------------------------------------------------------------------------------------------"
      puts "Referenced pre-compiled shared libraries"
      puts "------------------------------------------------------------------------------------------------------------------------------------"
    }
    set uniq_shared_libs    [list]
    set shared_libs_to_link [list]
    variable a_sim_cache_all_ip_obj
    xcs_cache_ip_objs
    foreach ip [array names a_sim_cache_all_ip_obj] {
      set ip_obj $a_sim_cache_all_ip_obj($ip)
      set ipdef [get_property -quiet "ipdef" $ip_obj]
      set vlnv_name [xcs_get_library_vlnv_name $ip_obj $ipdef]
      set ssm_type [get_property -quiet "selected_sim_model" $ip_obj]
      if { [lsearch $shared_ip_libs $vlnv_name] != -1 } {
        if { [lsearch -exact $uniq_shared_libs $vlnv_name] == -1 } {
          if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
            puts " IP - $ip_obj ($vlnv_name) - SELECTED_SIM_MODEL=$ssm_type"
          }
          if { ("tlm" == $ssm_type) } {
            # bind systemC library
            lappend shared_libs_to_link $vlnv_name
            lappend uniq_shared_libs $vlnv_name
            if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
              puts "      (BIND)-> $a_sim_vars(s_clibs_dir)/$vlnv_name"
            }
          } else {
            # rtl, tlm_dpi (no binding)
            if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
              puts "      (SKIP)-> $a_sim_vars(s_clibs_dir)/$vlnv_name"
            }
          }
        }
      } else {
        # check if incompatible version found from compiled area
        if { $a_sim_vars(b_int_sm_lib_ref_debug) } {
          set ip_name [get_property -quiet "name" $ip_obj]
          # ipdef -> xilinx.com:ip:versal_cips:3.0 -> versal_cips_v
          set ip_prefix [lindex [split $ipdef {:}] 2]
          set ip_prefix "${ip_prefix}_v"

          # match first part from clibs area to see if it matches
          set matches [lsearch -regexp -all $shared_ip_libs $ip_prefix]
          if { [llength $matches] > 0 } {
            puts " WARNING: Expected pre-compiled shared library for '$vlnv_name' referenced in IP '$ip_name' not found!"
            puts "          (Library '$vlnv_name' will not be linked during elaboration)"
            puts "          Available version(s) present in CLIBS '$a_sim_vars(s_clibs_dir)':"
            foreach index $matches {
              puts "           + [lindex $shared_ip_libs $index]"
            }
          }
        }
      }
    }
    foreach vlnv_name $shared_libs_to_link {
      lappend args_list "-lib $vlnv_name"
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
          set resolved_path [xcs_resolve_sim_model_dir "xsim" $lib_path $a_sim_vars(s_clibs_dir) $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved $a_sim_vars(b_compile_simmodels) "obj"]
          if { $b_resolved } {
            set rel_lib_path $resolved_path
          } else {
            set rel_lib_path [xcs_get_relative_file_path $lib_path $a_sim_vars(s_launch_dir)]
          }

          #send_msg_id USF-XSim-104 INFO "Referencing library '$lib_name' from '$lib_path'\n"
          set sc_args "-gcc_link_options \"-L$rel_lib_path -l${lib_name}\"" 
          lappend args_list $sc_args
        }
      }
    }

    # bind user specified systemC/C/C++ libraries
    set l_link_sysc_libs [get_property "xsim.elaborate.link.sysc" $a_sim_vars(fs_obj)]
    foreach lib $l_link_sysc_libs {
      set lib_path [file dirname $lib]
      set lib_name [file root [file tail $lib]]
      set lib_name [string trimleft $lib_name {lib}]
      set sc_args "-gcc_link_options \"-L$lib_path -l${lib_name}\"" 
      lappend args_list $sc_args
    }
    set l_link_c_libs [get_property "xsim.elaborate.link.c" $a_sim_vars(fs_obj)]
    foreach lib $l_link_c_libs {
      set lib_path [file dirname $lib]
      set lib_name [file root [file tail $lib]]
      set lib_name [string trimleft $lib_name {lib}]
      set sc_args "-gcc_link_options \"-L$lib_path -l${lib_name}\"" 
      lappend args_list $sc_args
    }
  }

  lappend args_list "-o libdpi${lib_extn}"

  set cmd_args [join $args_list " "]
  return $cmd_args
}

proc usf_add_glbl_top_instance { opts_arg top_level_inst_names } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts 

  variable a_sim_vars

  set b_verilog_sim_netlist 0
  if { ({post_synth_sim} == $a_sim_vars(s_simulation_flow)) || ({post_impl_sim} == $a_sim_vars(s_simulation_flow)) } {
    if { {Verilog} == $a_sim_vars(s_target_lang) } {
      set b_verilog_sim_netlist 1
    }
  }

  set b_add_glbl 0
  set b_top_level_glbl_inst_set 0
  
  # is glbl specified explicitly?
  if { ([lsearch ${top_level_inst_names} {glbl}] != -1) } {
    set b_top_level_glbl_inst_set 1
  }

  set b_load_glbl [get_property "xsim.elaborate.load_glbl" $a_sim_vars(fs_obj)]
  if { [xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $b_verilog_sim_netlist } {
    if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
      if { (!$b_top_level_glbl_inst_set) && $b_load_glbl } {
        set b_add_glbl 1
      }
    } else {
      # for post* sim flow add glbl top if design contains verilog sources or verilog netlist add glbl top if not set earlier
      if { !$b_top_level_glbl_inst_set } {
        set b_add_glbl 1
      }
    }
  }

  if { !$b_add_glbl } {
    if { $a_sim_vars(b_int_compile_glbl) } {
      set b_add_glbl 1
    }
  }

  if { !$b_add_glbl } {
    if { $b_load_glbl } {
      # TODO: revisit this for pure vhdl, causing failures 
      #set b_add_glbl 1
    }
  }

  # force compile glbl
  if { (!$b_add_glbl) && $a_sim_vars(b_force_compile_glbl) } {
    set b_add_glbl 1
  }

  # force no compile glbl
  if { $b_add_glbl && $a_sim_vars(b_force_no_compile_glbl) } {
    set b_add_glbl 0
  }

  if { $b_add_glbl } {
    set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
    lappend opts "${top_lib}.glbl"
  }
}

proc usf_xsim_get_xsim_cmdline_args { cmd_file wcfg_files b_add_view wdb_file b_add_wdb b_batch } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set args_list [list]
  lappend args_list $a_sim_vars(s_snapshot)
  lappend args_list "-key"
  lappend args_list "\{[usf_xsim_get_running_simulation_obj_key]\}"

  set user_cmd_file [get_property "xsim.simulate.custom_tcl" $a_sim_vars(fs_obj)]
  if { {} != $user_cmd_file } {
    set cmd_file $user_cmd_file
  }
  lappend args_list "-tclbatch"
  if { $b_batch } {
    lappend args_list "$cmd_file" 
    # for scripts_only mode, set script for simulator gui mode (pass -gui)
    if { $a_sim_vars(b_scripts_only) && $a_sim_vars(b_gui) } {
      lappend args_list "-gui"
    }
  } else {
    lappend args_list "\{$cmd_file\}" 
  }

  # for undefined aie_work_dir or aiesim_config, add onerror quit for xsim to exit gracefully
  set aie_ip_obj [xcs_find_ip "ai_engine"]
  if { {} != $aie_ip_obj } {
    lappend args_list "-onerror quit"
  }

  set p_inst_files [xcs_get_protoinst_files $a_sim_vars(dynamic_repo_dir)]
  if { [llength $p_inst_files] > 0 } {
    set target_pinst_dir "$a_sim_vars(s_launch_dir)/protoinst_files"
    if { ![file exists $target_pinst_dir] } {
      [catch {file mkdir $target_pinst_dir} error_msg]
    }
    foreach p_file $p_inst_files {
      if { ![file exists $p_file] } { continue; }
      set filename [file tail $p_file]
      set target_p_file "$target_pinst_dir/$filename"
      if { [file exists $target_p_file] } {
        [catch {file delete -force $target_p_file} error_msg]
      }
      if { [catch {file copy -force $p_file $target_pinst_dir} error_msg] } {
        [catch {send_msg_id USF-XSim-010 ERROR "Failed to copy file '$p_file' to '$target_pinst_dir': $error_msg\n"} err]
      } else {
        #send_msg_id USF-XSim-011 INFO "File '$p_file' copied to '$target_pinst_dir'\n"
      }
      lappend args_list "-protoinst"
      lappend args_list "\"protoinst_files/$filename\""
    }
  }

  if { $b_add_view } {
    foreach wcfg_file $wcfg_files {
      if { ![file exists $wcfg_file] } {
        send_msg_id USF-XSim-017 WARNING "WCFG file does not exist:$wcfg_file\n"
        continue;
      }
      lappend args_list "-view"
      if { $b_batch } {
        lappend args_list "$wcfg_file"
      } else {
        if { [regexp "\\s+" $wcfg_file match] } {
          lappend args_list "\{\{$wcfg_file\}\}"
        } else {
          lappend args_list "\{$wcfg_file\}"
        }
      }
    }
  }

  if { $b_add_wdb } {
    lappend args_list "-wdb"
    if { $b_batch } {
      lappend args_list "$wdb_file"
    } else {
      lappend args_list "\{$wdb_file\}"
    }
  }
    
  #set log_file $a_sim_vars(s_snapshot);append log_file ".log"
  set log_file "simulate";append log_file ".log"
  lappend args_list "-log"
  if { $b_batch } {
    lappend args_list "$log_file"
  } else {
    lappend args_list "\{$log_file\}"
  }

  # allow positional args from command line
  if { $a_sim_vars(b_scripts_only) } {
    set b_positional_args [get_property "xsim.simulate.add_positional" $a_sim_vars(fs_obj)]
    if { $b_positional_args } {
      if {$::tcl_platform(platform) == "unix"} {
        lappend args_list "\$*"
      } else { 
        lappend args_list "%*"
      }
    }
  }

  # more options
  set more_sim_options [string trim [get_property "xsim.simulate.xsim.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_sim_options } {
    lappend args_list $more_sim_options
  }
  set cmd_args [join $args_list " "]
  return $cmd_args
}

proc usf_xsim_write_cmd_file { cmd_filename b_add_wave } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set cmd_file [file normalize [file join $a_sim_vars(s_launch_dir) $cmd_filename]]
  set fh_scr 0
  if {[catch {open $cmd_file w} fh_scr]} {
    send_msg_id USF-XSim-019 ERROR "Failed to open file to write ($cmd_file)\n"
    return 1
  }

  set dbg_level [get_property "xsim.elaborate.debug_level" $a_sim_vars(fs_obj)]
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

  set b_post_sim 0
  if { ({functional} == $a_sim_vars(s_type)) || \
       ({timing} == $a_sim_vars(s_type)) } {
    set b_post_sim 1
  }
  # generate saif file for power estimation
  set saif [get_property "xsim.simulate.saif" $a_sim_vars(fs_obj)]
  set b_all_signals [get_property "xsim.simulate.saif_all_signals" $a_sim_vars(fs_obj)]
  if { {} != $saif } {
    set uut {}
    [catch {set uut [get_property -quiet "xsim.simulate.uut" $a_sim_vars(fs_obj)]} msg]
    set saif_scope [get_property "xsim.simulate.saif_scope" $a_sim_vars(fs_obj)]
    if { {} != $saif_scope } {
      set uut $saif_scope
    }
    puts $fh_scr "\nopen_saif \"$saif\""
    if { {} != $uut } {
      set uut_name [xcs_resolve_uut_name "xsim" uut]
      puts $fh_scr "set curr_xsim_wave_scope \[current_scope\]"
      puts $fh_scr "current_scope $uut_name"
    }

    if { $b_post_sim } {
      puts $fh_scr "log_saif \[get_objects -r *\]"
    } else {
      if { $b_all_signals } {
        puts $fh_scr "log_saif \[get_objects -r *\]"
      } else {
        set filter "-filter \{type==in_port || type==out_port || type==inout_port\}"
        puts $fh_scr "log_saif \[get_objects $filter *\]"
      }
    }
    if { {} != $uut } {
      puts $fh_scr "current_scope \$curr_xsim_wave_scope"
      puts $fh_scr "unset curr_xsim_wave_scope"
    }
  }

  if { [get_property "xsim.simulate.log_all_signals" $a_sim_vars(fs_obj)] } {
    puts $fh_scr "log_wave -r /"
  }

  # write tcl post hook
  set tcl_post_hook [get_property "xsim.simulate.tcl.post" $a_sim_vars(fs_obj)]
  if { {} != $tcl_post_hook } {
    puts $fh_scr "\n# execute post tcl file"
    puts $fh_scr "set rc \[catch \{"
    puts $fh_scr "  puts \"source $tcl_post_hook\""
    puts $fh_scr "  source \"$tcl_post_hook\""
    puts $fh_scr "\} result\]"
    puts $fh_scr "if \{\$rc\} \{"
    puts $fh_scr "  \[catch \{send_msg_id USF-simtcl-1 ERROR \"\$result\"\}\]"
    puts $fh_scr "  \[catch \{send_msg_id USF-simtcl-2 ERROR \"Script failed:$tcl_post_hook\"\}\]"
    #puts $fh_scr "  return -code error"
    puts $fh_scr "\}"
  }

  if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
    set debug_mode [get_property -quiet "hw_emu.debug_mode" $a_sim_vars(fs_obj)]
    if { {wdb} == $debug_mode } {
      puts $fh_scr "\nif \{ \[file exists vitis_params.tcl\] \} \{"
      puts $fh_scr "  source vitis_params.tcl"
      puts $fh_scr "\}"
      puts $fh_scr "\nif \{ \[info exists ::env(USER_PRE_SIM_SCRIPT)\] \} \{"
      puts $fh_scr "  if \{ \[catch \{source \$::env(USER_PRE_SIM_SCRIPT)\} msg\] \} \{"
      puts $fh_scr "    puts \$msg"
      puts $fh_scr "  \}"
      puts $fh_scr "\}"
    }
  }

  if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
    set debug_mode [get_property -quiet "hw_emu.is_waveform_mode" $a_sim_vars(fs_obj)]
    if { $debug_mode } {
      puts $fh_scr "\nif \{ \[info exists ::env(VITIS_WAVEFORM)\] \} \{"
      puts $fh_scr "  if \{ \[file exists \$::env(VITIS_WAVEFORM)\] == 1\} \{"
      puts $fh_scr "    open_wave_config \$::env(VITIS_WAVEFORM)"
      puts $fh_scr "  \}"
      puts $fh_scr "\}"
    }
  }

  if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
    puts $fh_scr "\nif \{ \[file exists pre_sim_tool_scripts.tcl\] \} \{"
    puts $fh_scr "  source pre_sim_tool_scripts.tcl"
    puts $fh_scr "\}"
  }

  set rt [string trim [get_property "xsim.simulate.runtime" $a_sim_vars(fs_obj)]]
  if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
    puts $fh_scr "\nputs \"We are running simulator for infinite time. Added some default signals in the waveform. You can pause simulation and add signals and then resume the simulaion again.\""
    puts $fh_scr "puts \"\""
    puts $fh_scr "puts \"Stopping at breakpoint in simulator also stops the host code execution\""
    puts $fh_scr "puts \"\""
    puts $fh_scr "if \{ \[info exists ::env(VITIS_LAUNCH_WAVEFORM_GUI) \] \} \{"
    puts $fh_scr "  run 1ns"
    puts $fh_scr "\} else \{"
    if { {} == $rt } {
      # no runtime specified
      # puts $fh_scr "  run all"
    } else {
      set rt_value [string tolower $rt]
      if { ({all} == $rt_value) || (![regexp {^[0-9]} $rt_value]) } {
        puts $fh_scr "  run all"
      } else {
        puts $fh_scr "  run $rt"
      }
    }
    puts $fh_scr "\}"
  } else {
    if { {} == $rt } {
      # no runtime specified
      # puts $fh_scr "\nrun all"
    } else {
      set rt_value [string tolower $rt]
      if { ({all} == $rt_value) || (![regexp {^[0-9]} $rt_value]) } {
        puts $fh_scr "\nrun all"
      } else {
        puts $fh_scr "\nrun $rt"
      }
    }
  }

  if { {} != $saif } {
    puts $fh_scr "close_saif"
  }

  # add TCL sources
  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\" && IS_USER_DISABLED == 0"
  xcs_find_files tcl_src_files $a_sim_vars(sp_tcl_obj) $filter $a_sim_vars(s_launch_dir) $a_sim_vars(b_absolute_path) $a_sim_vars(fs_obj)
  if {[llength $tcl_src_files] > 0} {
    puts $fh_scr ""
    foreach file $tcl_src_files {
       puts $fh_scr "source -notrace \{$file\}"
    }
    puts $fh_scr ""
  }
  
  if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
    puts $fh_scr "\nif \{ \[file exists post_sim_tool_scripts.tcl\] \} \{"
    puts $fh_scr "  source post_sim_tool_scripts.tcl"
    puts $fh_scr "\}\n"
  }

  if { $a_sim_vars(b_int_en_vitis_hw_emu_mode) } {
    set debug_mode [get_property -quiet "hw_emu.debug_mode" $a_sim_vars(fs_obj)]
    if { {wdb} == $debug_mode } {
      puts $fh_scr "if \{ \[info exists ::env(VITIS_LAUNCH_WAVEFORM_BATCH) \] \} \{"
      puts $fh_scr "  if \{ \[info exists ::env(USER_POST_SIM_SCRIPT) \] \} \{"
      puts $fh_scr "    if \{ \[catch \{source \$::env(USER_POST_SIM_SCRIPT)\} msg\] \} \{"
      puts $fh_scr "      puts \$msg"
      puts $fh_scr "    \}"
      puts $fh_scr "  \}"
      puts $fh_scr "  quit"
      puts $fh_scr "\}"
    }
  } else {
    if { $a_sim_vars(b_scripts_only) } {
      set b_no_quit [get_property "xsim.simulate.no_quit" $a_sim_vars(fs_obj)]
      if { $b_no_quit || $a_sim_vars(b_gui) } {
        # do not quit simulation
      } else {
        # quit simulation
        puts $fh_scr "quit"
      }
    }
  }

  close $fh_scr
}

proc usf_xsim_get_running_simulation_obj_key {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set mode      [usf_xsim_get_sim_mode_as_pretty_str $a_sim_vars(s_mode)]
  set flow_type [usf_xsim_get_sim_flow_type_as_pretty_str $a_sim_vars(s_type)]
  set fs_name   [get_property "name" $a_sim_vars(fs_obj)]

  if { {Unknown} == $flow_type } {
    set flow_type "Functional"  
  }

  set key $mode;append key {:};append key $fs_name;append key {:};append key $flow_type;append key {:};append key $a_sim_vars(s_sim_top)
  return $key
} 

proc usf_xsim_get_snapshot {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set snapshot [get_property "xsim.elaborate.snapshot" $a_sim_vars(fs_obj)]

  if { ({<Default>} == $snapshot) || ({} == $snapshot) } {
    set snapshot $a_sim_vars(s_sim_top)
    switch -regexp -- $a_sim_vars(s_simulation_flow) {
      {behav_sim} {
        set snapshot [append snapshot "_behav"]
      }
      {post_synth_sim} -
      {post_impl_sim} {
        switch -regexp -- $a_sim_vars(s_type) {
          {functional} { set snapshot [append snapshot "_func"] }
          {timing}     { set snapshot [append snapshot "_time"] }
          default      { set snapshot [append snapshot "_unknown"] }
        }
      }
    }
    switch -regexp -- $a_sim_vars(s_simulation_flow) {
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
  set top $a_sim_vars(s_sim_top)
  set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
  set top_names [split $top " "]
  if { [llength $top_names] > 1 } {
    foreach name $top_names {
      if { [lsearch $top_level_instance_names $name] == -1 } {
        lappend top_level_instance_names [usf_get_top_name $name $top_lib]
      }
    }
  } else {
    set name $top_names
    lappend top_level_instance_names [usf_get_top_name $name $top_lib]
  }

  # logical noc
  set lnoc_top [get_property -quiet "logical_noc_top" $a_sim_vars(fs_obj)]
  if { {} != $lnoc_top } {
    set lib [get_property -quiet "logical_noc_top_lib" $a_sim_vars(fs_obj)]
    lappend top_level_instance_names [usf_get_top_name $lnoc_top $lib]
  }

  return $top_level_instance_names
}

proc usf_get_top_name { name top_lib } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  set top {}
  # check if top defines the library already (mylib.top)
  set lib {}
  if { [regexp {\.} $name] } {
    set lib [lindex [split $name "."] 0]
  }
  # if library already prefixed, append lib.top name as is, else prefix it
  if { $lib == $top_lib } {
    # name already contains library, return the name as is
    set top $name
  } else {
    # name does not contain library, append library
    set top "${top_lib}.$name"
  }
  return $top
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

proc usf_xsim_set_initial_cmd { fh_scr cmd_str src_file file_type lib prev_file_type_arg prev_lib_arg } {
  # Summary: Print compiler command line and store previous file type and library information
  # Argument Usage:
  # Return Value:
  # None

  upvar $prev_file_type_arg prev_file_type
  upvar $prev_lib_arg  prev_lib

  puts $fh_scr "$cmd_str \\"
  puts $fh_scr "\"$src_file\" \\"

  set prev_file_type $file_type
  set prev_lib $lib
}

proc usf_xsim_map_pre_compiled_libs { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  set lib_path [get_property "sim.ipstatic.compiled_library_dir" $a_sim_vars(curr_proj)]
  set ini_file [file join $lib_path "xsim.ini"]
  if { ![file exists $ini_file] } {
    return
  }

  set fh_ini 0
  if { [catch {open $ini_file r} fh_ini] } {
    send_msg_id USF-XSim-099 WARNING "Failed to open file for read ($ini_file)\n"
    return
  }
  set ini_data [read $fh_ini]
  close $fh_ini

  set ini_data [split $ini_data "\n"]
  set b_lib_start false
  foreach line $ini_data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    if { [regexp "^secureip" $line] } {
      set b_lib_start true
    }
    if { $b_lib_start } {
      if { [regexp "^secureip" $line] ||
           [regexp "^unisim" $line] ||
           [regexp "^simprim" $line] ||
           [regexp "^unifast" $line] ||
           [regexp "^unimacro" $line] } {
        continue
      }
      if { ([regexp {^--} $line]) } {
        set b_lib_start false
        continue
      }
      if { [regexp "=" $line] } {
        puts $fh "$line"
      }
    }
  }
}

proc usf_xsim_include_xvhdl_log {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if {$::tcl_platform(platform) == "unix"} {
    # for unix, compile log redirection is taken care by unix commands
  } else {
    # for windows, append xvhdl log to compile.log
    set compile_log [file normalize [file join $a_sim_vars(s_launch_dir) "compile.log"]]
    set xvhdl_log [file normalize [file join $a_sim_vars(s_launch_dir) "xvhdl.log"]]
    if { [file exists $xvhdl_log] } {
      set fh 0
      if {[catch {open $xvhdl_log r} fh]} {
        send_msg_id USF-XSim-100 ERROR "Failed to open file for read ($xvhdl_log)\n"
      } else {
        set data [read $fh]
        set log_data [split $data "\n"]
        close $fh
  
        # open compile.log for append
        set fh 0
        if {[catch {open $compile_log a} fh]} {
          send_msg_id USF-XSim-101 ERROR "Failed to open file for append ($compile_log)\n"
        } else {
          foreach line $log_data {
            puts $fh [string trim $line]
          }
          close $fh
        }
      }
    }
  }
}

proc usf_get_rdi_bin_path {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set rdi_path $::env(RDI_BINROOT)
  set rdi_path [string map {/ \\\\} $rdi_path]
  return $rdi_path
}

proc usf_append_sm_lib_path { sm_lib_paths_arg install_path sm_lib_dir match_string } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
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
      set ref_dir "\$xv_ref_path[xcs_replace_with_var [xcs_replace_with_var $file_path_str "SIM_VER" "xsim"] "GCC_VER" "xsim"]"
      #
      # for non-precompile mode set the unprotected simmodel dir to full compiled lib path "<install>/data/xsim/ip/<simmodel>"
      # NOTE: $xv_ref_path is not applicable
      # 
      if { $a_sim_vars(b_compile_simmodels) } {
        set ref_dir "$path_to_consider"
      }
    }
    lappend sm_lib_paths $ref_dir

    return true
  }
  return false
}

proc usf_xsim_resolve_sysc_lib_path { type lib_path } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set resolved_path $lib_path

  # forward slash
  set lib_path [string map {\\ /} $lib_path]
  set sub_dirs [split $lib_path {/}]
  # data path
  set data_index [lsearch -exact $sub_dirs "data"]
  set data_path  [join [lrange $sub_dirs $data_index end] "/"]
  # tps path
  set data_index [lsearch -exact $sub_dirs "tps"]
  set tps_path   [join [lrange $sub_dirs $data_index end] "/"]
  switch $type {
    {CLIBS} { set resolved_path "\$XILINX_VIVADO/$data_path" }
    {SPCPT} -
    {SPEXT} { set resolved_path "\$XILINX_VIVADO/$data_path" }
    {BOOST} { set resolved_path "\$XILINX_VIVADO/$tps_path"  }
    default { send_msg_id USF-XSim-106 INFO "unknown systemc pre-compiled library path: '$type'!" }
  }
  return $resolved_path
}

proc usf_xsim_write_systemc_variables { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if {$::tcl_platform(platform) == "unix"} {
    puts $fh_scr "[xcs_get_shell_env]"
    xcs_write_script_header $fh_scr "compile" "xsim"
    xcs_write_version_id $fh_scr "xsim"
    puts $fh_scr "\n# catch pipeline exit status"
    xcs_write_pipe_exit $fh_scr
    if { [file exists $a_sim_vars(s_clibs_dir)] } {
      puts $fh_scr "\n# resolve compiled library path in xsim.ini"
      set data_dir [file dirname $a_sim_vars(s_clibs_dir)]
      puts $fh_scr "export RDI_DATADIR=\"[xcs_replace_with_var $data_dir "SIM_VER" "xsim"]\""
    }
    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      if { $a_sim_vars(b_ref_sysc_lib_env) } {
        puts $fh_scr "\n# set simulation library paths"
        puts $fh_scr "xv_cxl_lib_path=\"[xcs_replace_with_var [usf_xsim_resolve_sysc_lib_path "CLIBS" $a_sim_vars(s_clibs_dir)] "SIM_VER" "xsim"]\""
        puts $fh_scr "xv_cpt_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var [usf_xsim_resolve_sysc_lib_path "SPCPT" $a_sim_vars(sp_cpt_dir)] "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
        puts $fh_scr "xv_ext_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var [usf_xsim_resolve_sysc_lib_path "SPEXT" $a_sim_vars(sp_ext_dir)] "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
        puts $fh_scr "xv_boost_lib_path=\"[usf_xsim_resolve_sysc_lib_path "BOOST" $a_sim_vars(s_boost_dir)]\"\n"
      } else {
        if { $a_sim_vars(b_compile_simmodels) } {
          puts $fh_scr "\n# set simulation library paths"
          puts $fh_scr "xv_cxl_lib_path=\"simlibs\""
          puts $fh_scr "xv_cxl_obj_lib_path=\"$a_sim_vars(compiled_design_lib)\""
        } else {
          puts $fh_scr "\n# set simulation library paths"
          puts $fh_scr "xv_cxl_lib_path=\"[xcs_replace_with_var $a_sim_vars(s_clibs_dir) "SIM_VER" "xsim"]\""
        }
        puts $fh_scr "xv_cpt_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_cpt_dir) "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
        puts $fh_scr "xv_ext_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_ext_dir) "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
        puts $fh_scr "xv_boost_lib_path=\"$a_sim_vars(s_boost_dir)\"\n"
      }
    }
  } else {
    puts $fh_scr "@echo off"
    # TODO: perf-fix
    xcs_write_script_header $fh_scr "compile" "xsim"
    xcs_write_version_id $fh_scr "xsim"
    puts $fh_scr ""
    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      puts $fh_scr "\n# set simulation library paths"
      puts $fh_scr "set xv_cxl_lib_path=\"[xcs_replace_with_var $a_sim_vars(s_clibs_dir) "SIM_VER" "xsim"]\""
      puts $fh_scr "set xv_cpt_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_cpt_dir) "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
      puts $fh_scr "set xv_ext_lib_path=\"[xcs_replace_with_var [xcs_replace_with_var $a_sim_vars(sp_ext_dir) "SIM_VER" "xsim"] "GCC_VER" "xsim"]\""
      puts $fh_scr "set xv_boost_lib_path=\"$a_sim_vars(s_boost_dir)\"\n"
    }
  }
}

proc usf_xsim_write_tcl_pre_hook { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_vars 

  set tcl_pre_hook [get_property "xsim.compile.tcl.pre" $a_sim_vars(fs_obj)]
  if { {} == $tcl_pre_hook } {
    return
  }

  set tcl_pre_hook [file normalize $tcl_pre_hook]
  if { ![file exists $tcl_pre_hook] } {
    [catch {send_msg_id USF-XSim-103 ERROR "File does not exist:'$tcl_pre_hook'\n"} err]
  }
  set tcl_wrapper_file $a_sim_vars(s_compile_pre_tcl_wrapper)
  xcs_delete_backup_log $tcl_wrapper_file $a_sim_vars(s_launch_dir)
  xcs_write_tcl_wrapper $tcl_pre_hook ${tcl_wrapper_file}.tcl $a_sim_vars(s_launch_dir)
  set vivado_cmd_str "-mode batch -notrace -nojournal -log ${tcl_wrapper_file}.log -source ${tcl_wrapper_file}.tcl"
  set cmd "vivado $vivado_cmd_str"
  puts $fh_scr "echo \"$cmd\""
  if {$::tcl_platform(platform) == "unix"} {
    set full_cmd "vivado $vivado_cmd_str"
    puts $fh_scr "$full_cmd"
    xcs_write_exit_code $fh_scr
  } else {
    puts $fh_scr "call vivado $vivado_cmd_str"
  }
}

proc usf_xsim_write_verilog_prj { b_contain_verilog_srcs fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { !$b_contain_verilog_srcs } { return }

  variable a_sim_vars

  set b_first true
  set prev_lib  {}
  set prev_file_type {}

  set vlog_filename $a_sim_vars(s_sim_top);append vlog_filename "_vlog.prj"
  set vlog_file [file normalize [file join $a_sim_vars(s_launch_dir) $vlog_filename]]
  set fh_vlog 0
  if {[catch {open $vlog_file w} fh_vlog]} {
    send_msg_id USF-XSim-012 ERROR "Failed to open file to write ($vlog_file)\n"
    return 1
  }

  puts $fh_vlog "# compile verilog/system verilog design source files"
  foreach file $a_sim_vars(l_design_files) {
    set fargs       [split $file {|}]
    set type        [lindex $fargs 0]
    set file_type   [lindex $fargs 1]
    set lib         [lindex $fargs 2]
    set cmd_str     [lindex $fargs 3]
    set src_file    [lindex $fargs 4]
    set b_static_ip [lindex $fargs 5]
    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
    switch $type {
      {VERILOG} {
        if { $b_first } {
          set b_first false
          usf_xsim_set_initial_cmd $fh_vlog $cmd_str $src_file $file_type $lib prev_file_type prev_lib
        } else {
          if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
            puts $fh_vlog "\"$src_file\" \\"
          } else {
            puts $fh_vlog ""
            usf_xsim_set_initial_cmd $fh_vlog $cmd_str $src_file $file_type $lib prev_file_type prev_lib
          }
        }
      }
    }
  }
 
  xcs_add_hard_block_wrapper $fh_vlog "xsim" "" $a_sim_vars(s_launch_dir)

  set glbl_file "glbl.v"
  if { $a_sim_vars(b_absolute_path) } {
    set glbl_file [file normalize [file join $a_sim_vars(s_launch_dir) $glbl_file]]
  }

  # compile glbl file for behav
  if { {behav_sim} == $a_sim_vars(s_simulation_flow) } {
    set b_load_glbl [get_property "xsim.elaborate.load_glbl" [get_filesets $a_sim_vars(s_simset)]]

    if { [xcs_compile_glbl_file "xsim" $b_load_glbl $a_sim_vars(b_int_compile_glbl) $a_sim_vars(l_design_files) $a_sim_vars(s_simset) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] || $a_sim_vars(b_force_compile_glbl) } {
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
        xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
        set file_str "$top_lib \"${glbl_file}\""
        puts $fh_vlog "\n# compile glbl module\nverilog $file_str"
      }
    }
  } else {
    # for post* compile glbl if design contain verilog and netlist is vhdl
    if { (([xcs_contains_verilog $a_sim_vars(l_design_files) $a_sim_vars(s_simulation_flow) $a_sim_vars(s_netlist_file)] && ({VHDL} == $a_sim_vars(s_target_lang))) ||
          ($a_sim_vars(b_int_compile_glbl))) || $a_sim_vars(b_force_compile_glbl) } {
      if { $a_sim_vars(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        if { ({timing} == $a_sim_vars(s_type)) } {
          # This is not supported, netlist will be verilog always
        } else {
          set top_lib [xcs_get_top_library $a_sim_vars(s_simulation_flow) $a_sim_vars(sp_tcl_obj) $a_sim_vars(fs_obj) $a_sim_vars(src_mgmt_mode) $a_sim_vars(default_top_library)]
          xcs_copy_glbl_file $a_sim_vars(s_launch_dir)
          set file_str "$top_lib \"${glbl_file}\""
          puts $fh_vlog "\n# compile glbl module\nverilog $file_str"
        }
      }
    }
  }

  # nosort? (verilog)
  set nosort_param [get_param "simulation.donotRecalculateCompileOrderForXSim"] 
  set b_no_sort [get_property "xsim.compile.xvlog.nosort" $a_sim_vars(fs_obj)]
  if { $b_no_sort || $nosort_param || ({DisplayOnly} == $a_sim_vars(src_mgmt_mode)) || ({None} == $a_sim_vars(src_mgmt_mode)) } {
    puts $fh_vlog "\n# Do not sort compile order\nnosort"
  }
  close $fh_vlog

  # construct command line args
  variable a_sim_sv_pkg_libs
  set log_filename "compile.log"
  set xvlog_arg_list [list]

  if { [get_property "incremental" $a_sim_vars(fs_obj)] } {
    lappend xvlog_arg_list "--incr"
  }
  if { [get_property "xsim.compile.xvlog.relax" $a_sim_vars(fs_obj)] } {
    lappend xvlog_arg_list "--relax"
  }
  
  # for noc netlist functional simulation
  if { $a_sim_vars(b_enable_netlist_sim) && $a_sim_vars(b_netlist_sim) && ({functional} == $a_sim_vars(s_type)) && ({} != $a_sim_vars(sp_xlnoc_bd_obj)) } {
    lappend xvlog_arg_list "-d NETLIST_SIM"
  }

  # append uvm
  if { $a_sim_vars(b_contain_sv_srcs) } {
    lappend xvlog_arg_list "-L uvm"
  }
  # append sv pkg libs
  foreach sv_pkg_lib $a_sim_sv_pkg_libs {
    lappend xvlog_arg_list "-L $sv_pkg_lib"
  }
  set more_xvlog_options [string trim [get_property "xsim.compile.xvlog.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_xvlog_options } {
    set xvlog_arg_list [linsert $xvlog_arg_list end "$more_xvlog_options"]
  }
  lappend xvlog_arg_list "-prj $vlog_filename"
  set xvlog_cmd_str [join $xvlog_arg_list " "]

  set cmd "xvlog $xvlog_cmd_str"
  puts $fh_scr "$a_sim_vars(script_cmt_tag) compile Verilog/System Verilog design sources"
  puts $fh_scr "echo \"$cmd\""

  if {$::tcl_platform(platform) == "unix"} {
    set log_cmd_str $log_filename
    set full_cmd "xvlog $xvlog_cmd_str 2>&1 | tee $log_cmd_str"
    puts $fh_scr "$full_cmd"
    xcs_write_exit_code $fh_scr
  } else {
    set log_cmd_str " -log xvlog.log"
    puts $fh_scr "call xvlog $a_sim_vars(s_dbg_sw) $xvlog_cmd_str$log_cmd_str"
    puts $fh_scr "call type xvlog.log > $log_filename"
  }
}

proc usf_xsim_write_vhdl_prj { b_contain_verilog_srcs b_contain_vhdl_srcs b_is_pure_vhdl fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { !$b_contain_vhdl_srcs } { return }

  variable a_sim_vars

  set b_first true
  set prev_lib  {}
  set prev_file_type {}

  # write vhdl prj if design contains vhdl sources 
  set vhdl_filename $a_sim_vars(s_sim_top);append vhdl_filename "_vhdl.prj"
  set vhdl_file [file normalize [file join $a_sim_vars(s_launch_dir) $vhdl_filename]]
  set fh_vhdl 0
  if {[catch {open $vhdl_file w} fh_vhdl]} {
    send_msg_id USF-XSim-013 ERROR "Failed to open file to write ($vhdl_file)\n"
    return 1
  }
  puts $fh_vhdl "# compile vhdl design source files"
  foreach file $a_sim_vars(l_design_files) {
    set fargs       [split $file {|}]
    set type        [lindex $fargs 0]
    set file_type   [lindex $fargs 1]
    set lib         [lindex $fargs 2]
    set cmd_str     [lindex $fargs 3]
    set src_file    [lindex $fargs 4]
    set b_static_ip [lindex $fargs 5]
    if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
    switch $type {
      {VHDL} {
        if { $b_first } {
          set b_first false
          usf_xsim_set_initial_cmd $fh_vhdl $cmd_str $src_file $file_type $lib prev_file_type prev_lib
        } else {
          if { ($file_type == $prev_file_type) && ($lib == $prev_lib) } {
            puts $fh_vhdl "\"$src_file\" \\"
          } else {
            puts $fh_vhdl ""
            usf_xsim_set_initial_cmd $fh_vhdl $cmd_str $src_file $file_type $lib prev_file_type prev_lib
          }
        }
      }
    }
  }
  # nosort? (vhdl)
  set nosort_param [get_param "simulation.donotRecalculateCompileOrderForXSim"] 
  set b_no_sort [get_property "xsim.compile.xvhdl.nosort" $a_sim_vars(fs_obj)]
  if { $b_no_sort || $nosort_param || ({DisplayOnly} == $a_sim_vars(src_mgmt_mode)) || ({None} == $a_sim_vars(src_mgmt_mode)) } {
    puts $fh_vhdl "\n# Do not sort compile order\nnosort"
  }
  close $fh_vhdl

  # construct command line args
  set log_filename "compile.log"
  set xvhdl_arg_list [list]
  if { [get_property "incremental" $a_sim_vars(fs_obj)] } {
    lappend xvhdl_arg_list "--incr"
  }
  if { [get_property "xsim.compile.xvhdl.relax" $a_sim_vars(fs_obj)] } {
    lappend xvhdl_arg_list "--relax"
  }
  lappend xvhdl_arg_list "-prj $vhdl_filename"
  set more_xvhdl_options [string trim [get_property "xsim.compile.xvhdl.more_options" $a_sim_vars(fs_obj)]]
  if { {} != $more_xvhdl_options } {
    set xvhdl_arg_list [linsert $xvhdl_arg_list end "$more_xvhdl_options"]
  }
  set xvhdl_cmd_str [join $xvhdl_arg_list " "]

  set cmd "xvhdl $xvhdl_cmd_str"
  puts $fh_scr "$a_sim_vars(script_cmt_tag) compile VHDL design sources"
  puts $fh_scr "echo \"$cmd\""

  if {$::tcl_platform(platform) == "unix"} {
    set log_cmd_str $log_filename
    set append_sw " -a "
    if { $b_is_pure_vhdl } { set append_sw " " }
    set full_cmd "xvhdl $xvhdl_cmd_str 2>&1 | tee${append_sw}${log_cmd_str}"
    puts $fh_scr "$full_cmd"
    xcs_write_exit_code $fh_scr
  } else {
    set log_cmd_str " -log xvhdl.log"
    puts $fh_scr "call xvhdl $a_sim_vars(s_dbg_sw) $xvhdl_cmd_str$log_cmd_str"
    if { $b_contain_verilog_srcs } {
      puts $fh_scr "call type xvhdl.log >> $log_filename"
    } else {
      puts $fh_scr "call type xvhdl.log > $log_filename"
    }
  }
}

# nopc
proc usf_xsim_write_simmodel_prj { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
  variable a_shared_library_path_coln

  set platform "lin"
  if {$::tcl_platform(platform) == "windows"} {
    set platform "win"
  }

  set b_dbg 0
  if { $a_sim_vars(s_int_debug_mode) == "1" } {
    set b_dbg 1
  }

  set simulator "xsim"
  set compiler  "xsc"

  set data_dir [rdi::get_data_dir -quiet -datafile "systemc/simlibs"]
  # get the design simmodel compile order
  set simmodel_compile_order [xcs_get_simmodel_compile_order]

  # is pure-rtl sources for system simulation (selected_sim_model = rtl), don't need to compile the systemC/CPP/C sim-models
  if { [llength $simmodel_compile_order] == 0 } {
    if { [file exists $a_sim_vars(s_simlib_dir)] } {
      # delete <run-dir>/simlibs dir (not required)
      [catch {file delete -force $a_sim_vars(s_simlib_dir)} error_msg]
    }
    return
  }

  # update mappings in xsim.ini
  usf_add_simmodel_mappings $simmodel_compile_order

  foreach lib_name $simmodel_compile_order {
    set lib_path [xcs_find_lib_path_for_simmodel $lib_name]
    #puts "lib_path:$lib_name = $lib_path"
    #
    set fh 0
    set dat_file "$lib_path/.cxl.sim_info.dat"
    if {[catch {open $dat_file r} fh]} {
      send_msg_id USF-XSim-016 WARNING "Failed to open file to read ($dat_file)\n"
      continue
    }
    set data [split [read $fh] "\n"]
    close $fh

    # current platform supported?
    set simulator_platform {}
    set simmodel_name      {}
    set library_name       {}
    set b_process 0
    foreach line $data {
      set line [string trim $line]
      if { {} == $line } { continue }
      set line_info [split $line {:}]
      set tag   [lindex $line_info 0]
      set value [lindex $line_info 1]
      if { "<SIMMODEL_NAME>"              == $tag } { set simmodel_name $value } 
      if { "<LIBRARY_NAME>"               == $tag } { set library_name $value  }
      if { "<SIMULATOR_PLATFORM>" == $tag } {
        if { ("all" == $value) || (("linux" == $value) && ("lin" == $platform)) || (("windows" == $vlue) && ("win" == $platform)) } {
          # supported
          set b_process 1
        } else {
          continue
        }
      }
    }
    if { !$b_process } { continue }

    #send_msg_id USF-XSim-107 STATUS "Generating compilation commands for '$lib_name'\n"

    # create local lib dir
    set simlib_dir "$a_sim_vars(s_simlib_dir)/$lib_name"
    if { ![file exists $simlib_dir] } {
      if { [catch {file mkdir $simlib_dir} error_msg] } {
        send_msg_id USF-XSim-013 ERROR "Failed to create the directory ($simlib_dir): $error_msg\n"
        return 1
      }
    }
    # copy simmodel sources locally
    if { $a_sim_vars(b_int_export_source_files) } {
      if { {} == $simmodel_name } { send_msg_id USF-XSim-107 WARNING "Empty tag '$simmodel_name'!\n" }
      if { {} == $library_name  } { send_msg_id USF-XSim-107 WARNING "Empty tag '$library_name'!\n"  }

      set src_sim_model_dir "$data_dir/systemc/simlibs/$simmodel_name/$library_name/src"
      set dst_dir "$a_sim_vars(s_launch_dir)/simlibs/$library_name"
      if { [file exists $src_sim_model_dir] } {
        [catch {file delete -force $dst_dir/src} error_msg]
        if { [catch {file copy -force $src_sim_model_dir $dst_dir} error_msg] } {
          [catch {send_msg_id USF-XSim-108 ERROR "Failed to copy file '$src_sim_model_dir' to '$dst_dir': $error_msg\n"} err]
        } else {
          #puts "copied '$src_sim_model_dir' to run dir:'$a_sim_vars(s_launch_dir)/simlibs'\n"
        }
      } else {
        [catch {send_msg_id USF-XSim-108 ERROR "File '$src_sim_model_dir' does not exist\n"} err]
      }
    }
    # copy include dir
    set simlib_incl_dir "$lib_path/include" 
    set target_dir "$a_sim_vars(s_simlib_dir)/$lib_name"
    set target_incl_dir "$target_dir/include"
    if { ![file exists $target_incl_dir] } {
      if { [catch {file copy -force $simlib_incl_dir $target_dir} error_msg] } {
        [catch {send_msg_id USF-XSim-010 ERROR "Failed to copy file '$simlib_incl_dir' to '$target_dir': $error_msg\n"} err]
      }
    }

    # open prj file
    set prj_filename "${lib_name}_xsc.prj"
    set prj "$a_sim_vars(s_launch_dir)/$prj_filename"
    set fh_prj 0
    if {[catch {open $prj w} fh_prj]} {
      send_msg_id USF-XSim-016 WARNING "Failed to open file to write ($prj)\n"
      continue
    }
    puts $fh_prj "$a_sim_vars(script_cmt_tag) compile $lib_name model source files"

    # simmodel file_info.dat data
    set library_type            {}
    set output_format           {}
    set gplus_compile_flags     [list]
    set gplus_compile_opt_flags [list]
    set gplus_compile_dbg_flags [list]
    set ldflags                 [list]
    set gplus_ldflags_option    {}
    set gcc_ldflags_option      {}
    set ldflags_lin64           [list]
    set ldflags_win64           [list]
    set ldlibs                  [list]
    set ldlibs_lin64            [list]
    set ldlibs_win64            [list]
    set gplus_ldlibs_option     {}
    set gcc_ldlibs_option       {}
    set sysc_dep_libs           {}
    set cpp_dep_libs            {}
    set c_dep_libs              {}
    set sccom_compile_flags     {}
    set more_xsc_options        [list]
    set simulator_platform      {}
    set cpp_compile_option      {}
    set c_compile_option        {}
    set shared_lib              {}
    set systemc_incl_dirs       [list]
    set cpp_incl_dirs           [list]
    set osci_incl_dirs          [list]
    set c_incl_dirs             [list]

    foreach line $data {
      set line [string trim $line]
      if { {} == $line } { continue }
      set line_info [split $line {:}]
      set tag       [lindex $line_info 0]
      set value     [lindex $line_info 1]

      if { ("<SYSTEMC_SOURCES>" == $tag) || ("<CPP_SOURCES>" == $tag) || ("<C_SOURCES>" == $tag) } {
        set file_path "$data_dir/$value"
        if { $a_sim_vars(b_int_export_source_files) } {
          set dirs [split $value "/"]
          set value [join [lrange $dirs 3 end] "/"]
          set file_path "simlibs/$value"
        }
        puts $fh_prj "\"$file_path\""
      }

      if { "<LIBRARY_TYPE>"               == $tag } { set library_type $value                        }
      if { "<OUTPUT_FORMAT>"              == $tag } { set output_format $value                       }
      if { "<SYSTEMC_INCLUDE_DIRS>"       == $tag } { set systemc_incl_dirs [split $value {,}]       }
      if { "<CPP_INCLUDE_DIRS>"           == $tag } { set cpp_incl_dirs [split $value {,}]           }
      if { "<C_INCLUDE_DIRS>"             == $tag } { set c_incl_dirs [split $value {,}]             }
      if { "<OSCI_INCLUDE_DIRS>"          == $tag } { set osci_incl_dirs [split $value {,}]          }
      if { "<G++_COMPILE_FLAGS>"          == $tag } { set gplus_compile_flags [split $value {,}]     }
      if { "<G++_COMPILE_OPTIMIZE_FLAGS>" == $tag } { set gplus_compile_opt_flags [split $value {,}] }
      if { "<G++_COMPILE_DEBUG_FLAGS>"    == $tag } { set gplus_compile_dbg_flags [split $value {,}] }
      if { "<LDFLAGS>"                    == $tag } { set ldflags [split $value {,}]                 }
      if { "<LDFLAGS_LIN64>"              == $tag } { set ldflags_lin64 [split $value {,}]           }
      if { "<LDFLAGS_WIN64>"              == $tag } { set ldflags_win64 [split $value {,}]           }
      if { "<G++_LDFLAGS_OPTION>"         == $tag } { set gplus_ldflags_option $value                }
      if { "<GCC_LDFLAGS_OPTION>"         == $tag } { set gcc_ldflags_option $value                  }
      if { "<LDLIBS>"                     == $tag } { set ldlibs [split $value {,}]                  }
      if { "<LDLIBS_LIN64>"               == $tag } { set ldlibs_lin64 [split $value {,}]            }
      if { "<LDLIBS_WIN64>"               == $tag } { set ldlibs_win64 [split $value {,}]            }
      if { "<G++_LDLIBS_OPTION>"          == $tag } { set gplus_ldlibs_option $value                 }
      if { "<GCC_LDLIBS_OPTION>"          == $tag } { set gcc_ldlibs_option $value                   }
      if { "<SYSTEMC_DEPENDENT_LIBS>"     == $tag } { set sysc_dep_libs $value                       }
      if { "<CPP_DEPENDENT_LIBS>"         == $tag } { set cpp_dep_libs $value                        }
      if { "<C_DEPENDENT_LIBS>"           == $tag } { set c_dep_libs $value                          }
      if { "<SCCOM_COMPILE_FLAGS>"        == $tag } { set sccom_compile_flags $value                 }
      if { "<MORE_XSC_OPTIONS>"           == $tag } { set more_xsc_options [split $value {,}]        }
      if { "<SIMULATOR_PLATFORM>"         == $tag } { set simulator_platform $value                  }
      if { "<CPP_COMPILE_OPTION>"         == $tag } { set cpp_compile_option $value                  }
      if { "<C_COMPILE_OPTION>"           == $tag } { set c_compile_option $value                    }
      if { "<SHARED_LIBRARY>"             == $tag } { set shared_lib $value                          }
    }
    close $fh_prj

    #
    # 1. compile sources
    # 
    set xsc_arg_list [list]

    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      if { $a_sim_vars(b_gcc_version) } {
        lappend xsc_arg_list "--gcc_version gcc-$a_sim_vars(s_gcc_version)"
      }
    }

    lappend xsc_arg_list "-c"
    if { $b_dbg } { lappend xsc_arg_list "-dbg" }
  
    if { [llength $more_xsc_options]  > 0 } { foreach opt $more_xsc_options       { lappend xsc_arg_list $opt } }


    if { [llength $systemc_incl_dirs] > 0 } { foreach incl_dir $systemc_incl_dirs { lappend xsc_arg_list "--gcc_compile_options \"-I$incl_dir\"" } }
    if { [llength $cpp_incl_dirs]     > 0 } { foreach incl_dir $cpp_incl_dirs     { lappend xsc_arg_list "--gcc_compile_options \"-I$incl_dir\"" } }
    if { [llength $c_incl_dirs]       > 0 } { foreach incl_dir $c_incl_dirs       { lappend xsc_arg_list "--gcc_compile_options \"-I$incl_dir\"" } }
   
    switch $library_type {
      {SystemC} -
      {CPP} { if { {} != $cpp_compile_option } { lappend xsc_arg_list "--gcc_compile_options \"$cpp_compile_option\"" } }
      {C}   { if { {} != $c_compile_option   } { lappend xsc_arg_list "--gcc_compile_options \"$c_compile_option\""   } }
    }

    if { [llength $gplus_compile_flags] > 0 } { foreach c_flag $gplus_compile_flags { lappend xsc_arg_list "--gcc_compile_options \"$c_flag\"" } }

    if { $b_dbg } {
      if { [llength $gplus_compile_dbg_flags] > 0 } { foreach c_flag $gplus_compile_dbg_flags { lappend xsc_arg_list "--gcc_compile_options \"$c_flag\"" } }
    } else {
      if { [llength $gplus_compile_opt_flags] > 0 } { foreach c_flag $gplus_compile_opt_flags { lappend xsc_arg_list "--gcc_compile_options \"$c_flag\"" } }
    }

    # config simmodel options
    set cfg_opt "${simulator}.compile.${compiler}.${library_name}"
    set cfg_val ""
    [catch {set cfg_val [get_param $cfg_opt]} err]
    if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
      lappend xsc_arg_list "--gcc_compile_options \"$cfg_val\""
    }

    # global simmodel option (if any)
    set cfg_opt "${simulator}.compile.${compiler}.global"
    set cfg_val ""
    [catch {set cfg_val [get_param $cfg_opt]} err]
    if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
      lappend xsc_arg_list "--gcc_compile_options \"$cfg_val\""
    }
   
    lappend xsc_arg_list "-work $lib_name"
    lappend xsc_arg_list "-f $prj_filename"

    set xsc_cmd_str [join $xsc_arg_list " "]

    set log_filename "compile.log"
    puts $fh_scr "$a_sim_vars(script_cmt_tag) compile '$lib_name' model sources"
    puts $fh_scr "echo \"xsc $xsc_cmd_str\""

    if {$::tcl_platform(platform) == "unix"} {
      set log_cmd_str $log_filename
      set append_sw " -a "
      #if { $b_is_pure_systemc } { set append_sw " " }
      set full_cmd "xsc $xsc_cmd_str 2>&1 | tee${append_sw}${log_cmd_str}"
      # not applicable
      #if { [get_param "project.optimizeScriptGenForSimulation"] } {
      #  append full_cmd " &"
      #}
      puts $fh_scr "$full_cmd"
      xcs_write_exit_code $fh_scr
    } else {
      puts $fh_scr "call xsc $a_sim_vars(s_dbg_sw) $xsc_cmd_str 2> xsc_err.log"
      puts $fh_scr "call type xsc.log >> $log_filename"
      puts $fh_scr "call type xsc_err.log >> $log_filename"
      puts $fh_scr "call type xsc_err.log"
    }

    #
    # 2. Generate shared library (link)
    # 
    set xsc_arg_list {}
    if { $b_dbg } { lappend xsc_arg_list "-dbg" }

    if { [llength $more_xsc_options] > 0 } { foreach opt $more_xsc_options { lappend xsc_arg_list $opt } }

    # link objs into shared lib
    set switch_name "--shared"
    if {$::tcl_platform(platform) == "windows"} { set switch_name "--shared_systemc" }
    if { {static} == $output_format } { switch_name "--static" }
    lappend xsc_arg_list $switch_name 

    if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
      if { $a_sim_vars(b_gcc_version) } {
        lappend xsc_arg_list "--gcc_version gcc-$a_sim_vars(s_gcc_version)"
      }
    }

    # <LDFLAGS>
    if { [llength $ldflags] > 0 } { foreach ld_flag $ldflags { lappend xsc_arg_list "--gcc_link_options \"$ld_flag\"" } }
    if {$::tcl_platform(platform) == "windows"} {
      if { [llength $ldflags_win64] > 0 } { foreach ld_flag $ldflags_win64 { lappend xsc_arg_list "--gcc_link_options \"$ld_flag\"" } }
    } else {
      if { [llength $ldflags_lin64] > 0 } { foreach ld_flag $ldflags_lin64 { lappend xsc_arg_list "--gcc_link_options \"$ld_flag\"" } }
    }

    # acd ldflags
    switch $library_type {
      {SystemC} -
      {CPP} { if { {} != $gplus_ldflags_option } { lappend xsc_arg_list "--gcc_compile_options \"$gplus_ldflags_option\"" } }
      {C}   { if { {} != $gcc_ldflags_option   } { lappend xsc_arg_list "--gcc_compile_options \"$gcc_ldflags_option\""   } }
    }

    # <LDLIBS>
    if { [llength $ldlibs] > 0 } { foreach ld_lib $ldlibs { lappend xsc_arg_list "--gcc_link_options \"$ld_lib\"" } }

    if {$::tcl_platform(platform) == "windows"} {
      if { [llength $ldlibs_win64] > 0 } { foreach ld_lib $ldlibs_win64 { lappend xsc_arg_list "--gcc_link_options \"$ld_lib\"" } }
    } else {
      if { [llength $ldlibs_lin64] > 0 } { foreach ld_lib $ldlibs_lin64 { lappend xsc_arg_list "--gcc_link_options \"$ld_lib\"" } }
    }

    # acd ldlibs
    switch $library_type {
      {SystemC} -
      {CPP} { if { {} != $gplus_ldlibs_option } { lappend xsc_arg_list "--gcc_compile_options \"$gplus_ldlibs_option\"" } }
      {C}   { if { {} != $gcc_ldlibs_option   } { lappend xsc_arg_list "--gcc_compile_options \"$gcc_ldlibs_option\""   } }
    }

    # <OUTPUT_SHARED_LIBRARY>
    set lib_type ".so"
    if {$::tcl_platform(platform) == "windows"} {
      set lib_type ".dll"
    }
    if { {static} == $output_format } {
      set lib_type ".a"
    }

    # bind linked libraries
    #set sysc_link_libs [list]
    #set cpp_link_libs  [list]
    #set c_link_libs    [list]
    #xcs_find_dependent_simmodel_libraries $lib_name sysc_link_libs cpp_link_libs c_link_libs

    #set link_args [list]
    #foreach lib $sysc_link_libs { lappend link_args "-L$a_sim_vars(compiled_design_lib)/${lib} -l${lib}" }
    #foreach lib $cpp_link_libs  { lappend link_args "-L$a_sim_vars(compiled_design_lib)/${lib} -l${lib}" }
    #foreach lib $c_link_libs    { lappend link_args "-L$a_sim_vars(compiled_design_lib)/${lib} -l${lib}" }
    #if { [llength $link_args] > 0 } {
    #  set link_args_str [join $link_args " "]
    #  lappend xsc_arg_list "--gcc_link_options \"$link_args_str\""
    #}
 
    #lappend xsc_arg_list "-o \"\$xv_cxl_lib_path/$lib_name/lib${lib_name}.so\""
    
    lappend xsc_arg_list "-o \"\$xv_cxl_obj_lib_path/$lib_name/lib${lib_name}${lib_type}\""
    lappend xsc_arg_list "-work $lib_name"
    set xsc_cmd_str [join $xsc_arg_list " "]
    puts $fh_scr "echo \"xsc $xsc_cmd_str\""

    if {$::tcl_platform(platform) == "unix"} {
      set log_cmd_str $log_filename
      set append_sw " -a "
      #if { $b_is_pure_systemc } { set append_sw " " }
      set full_cmd "xsc $xsc_cmd_str 2>&1 | tee${append_sw}${log_cmd_str}"
      # not applicable
      #if { [get_param "project.optimizeScriptGenForSimulation"] } {
      #  append full_cmd " &"
      #}
      puts $fh_scr "$full_cmd"
      xcs_write_exit_code $fh_scr
    } else {
      puts $fh_scr "call xsc $a_sim_vars(s_dbg_sw) $xsc_cmd_str 2> xsc_err.log"
      puts $fh_scr "call type xsc.log >> $log_filename"
      puts $fh_scr "call type xsc_err.log >> $log_filename"
      puts $fh_scr "call type xsc_err.log"
    }
  }
}

proc usf_add_simmodel_mappings { simmodel_compile_order } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  # file should be present by now
  set ini_file "$a_sim_vars(s_launch_dir)/xsim.ini"
  if { ![file exists $ini_file] } {
    return
  }

  # read xsim.ini contents
  set fh 0
  if {[catch {open $ini_file r} fh]} {
    send_msg_id USF-XSim-011 ERROR "Failed to open file to read ($ini_file)\n"
    return 1
  }
  set data [split [read $fh] "\n"]
  close $fh

  # get current_mappings
  set l_current_mappings  [list]
  set l_current_libraries [list]
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } {
      continue;
    }
    lappend l_current_mappings $line

    set library [string trim [lindex [split $line "="] 0]]
    lappend l_current_libraries $library
  }

  # find new simmodel mappings to add
  set l_new_mappings [list]
  foreach library $simmodel_compile_order {
    if { [lsearch -exact $l_current_mappings $library] == -1 } {
      set mapping "$library=$a_sim_vars(compiled_design_lib)/$library"
      lappend l_new_mappings $mapping
    }
  }

  # delete xsim.ini
  [catch {file delete -force $ini_file} error_msg]

  # create fresh updated copy
  set fh 0
  if {[catch {open $ini_file w} fh]} {
    send_msg_id USF-XSim-011 ERROR "Failed to open file to write ($ini_file)\n"
    return
  }
  foreach line $l_current_mappings { puts $fh $line }
  foreach line $l_new_mappings     { puts $fh $line }
  close $fh
}

proc usf_xsim_write_systemc_prj { b_contain_sc_srcs b_is_pure_systemc fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
    set sc_filename "$a_sim_vars(s_sim_top)_xsc.prj"
    set sc_file [file normalize [file join $a_sim_vars(s_launch_dir) $sc_filename]]
    if { $b_contain_sc_srcs } {
      set fh_sc 0
      if {[catch {open $sc_file w} fh_sc]} {
        send_msg_id USF-XSim-016 ERROR "Failed to open file to write ($sc_file)\n"
        return 1
      }
      puts $fh_sc "# compile SystemC design source files"
      foreach file $a_sim_vars(l_design_files) {
        set fargs       [split $file {|}]
        set type        [lindex $fargs 0]
        set file_type   [lindex $fargs 1]
        set lib         [lindex $fargs 2]
        set cmd_str     [lindex $fargs 3]
        set src_file    [lindex $fargs 4]
        set b_static_ip [lindex $fargs 5]
        if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
        switch $type {
          {SYSTEMC} {
            puts $fh_sc "\"$src_file\""
          }
        }
      }
      close $fh_sc

      set xsc_arg_list [list]

      if { $a_sim_vars(b_int_systemc_mode) && $a_sim_vars(b_system_sim_design) } {
        if { $a_sim_vars(b_gcc_version) } {
          lappend xsc_arg_list "--gcc_version gcc-$a_sim_vars(s_gcc_version)"
        }
      }
 
      lappend xsc_arg_list "-c"

      # --mt
      set max_threads [get_param general.maxthreads]
      set mt_level [get_property "xsim.compile.xsc.mt_level" $a_sim_vars(fs_obj)]
      switch -regexp -- $mt_level {
        {auto} {
          if { {1} == $max_threads } {
            # no op, keep auto ('1' is not supported by xelab)
          } else {
            set mt_level $max_threads
          }
        }
        {off} {
          # use 'off' (turn off multi-threading)
        }
        default {
          # use 2, 4, 8, 16, 32
        }
      }
      lappend xsc_arg_list "--mt $mt_level"

      # revisit this once we switch to higher version (1.66 will support this by default)
      lappend xsc_arg_list "--gcc_compile_options \"-DBOOST_SYSTEM_NO_DEPRECATED\""
      set more_xsc_options [string trim [get_property "xsim.compile.xsc.more_options" $a_sim_vars(fs_obj)]]
      if { {} != $more_xsc_options } {
        set xsc_arg_list [linsert $xsc_arg_list end "$more_xsc_options"]
      }

      # fetch systemc include files (.h)
      set simulator "xsim"
      set prefix_ref_dir false
      set filter  "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC Header\")"
      set l_incl_dirs [list]
      foreach dir [xcs_get_c_incl_dirs $simulator $a_sim_vars(s_launch_dir) $a_sim_vars(s_boost_dir) $filter $a_sim_vars(dynamic_repo_dir) false $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
        lappend l_incl_dirs "$dir"
      }
     
      # reference SystemC include directories 
      set b_en_code true
      if { $b_en_code } {
        variable a_shared_library_path_coln
        foreach {key value} [array get a_shared_library_path_coln] {
          set shared_lib_name $key
          set lib_path        $value
          set incl_dir "$lib_path/include"
          if { [file exists $incl_dir] } {
            if { !$a_sim_vars(b_absolute_path) } {
              set b_resolved 0
              set resolved_path [xcs_resolve_sim_model_dir "xsim" $incl_dir $a_sim_vars(s_clibs_dir) $a_sim_vars(sp_cpt_dir) $a_sim_vars(sp_ext_dir) b_resolved $a_sim_vars(b_compile_simmodels) "include"]
              if { $b_resolved } {
                set incl_dir $resolved_path
              } else {
                set incl_dir "[xcs_get_relative_file_path $incl_dir $a_sim_vars(s_launch_dir)]"
              }
            }
            lappend l_incl_dirs "$incl_dir"
          }
        }

        foreach incl_dir [get_property "systemc_include_dirs" $a_sim_vars(fs_obj)] {
          if { !$a_sim_vars(b_absolute_path) } {
            set incl_dir "[xcs_get_relative_file_path $incl_dir $a_sim_vars(s_launch_dir)]"
          }
          lappend l_incl_dirs "$incl_dir"
        }
      }
 
      variable l_systemc_incl_dirs
      set l_systemc_incl_dirs $l_incl_dirs

      if { [llength $l_incl_dirs] > 0 } {
        lappend xsc_arg_list "--gcc_compile_options"
        set incl_dir_strs [list]
        foreach incl_dir $l_incl_dirs {
          lappend incl_dir_strs "-I$incl_dir"
        }
        set incl_dir_cmd_str [join $incl_dir_strs " "]
        lappend xsc_arg_list "\"$incl_dir_cmd_str\""
      }
      lappend xsc_arg_list "-work $a_sim_vars(default_top_library)"
      lappend xsc_arg_list "-f $sc_filename"
      set xsc_cmd_str [join $xsc_arg_list " "]
      set log_filename "compile.log"
      puts $fh_scr "$a_sim_vars(script_cmt_tag) compile systemC design sources"
      puts $fh_scr "echo \"xsc $xsc_cmd_str\""
      if {$::tcl_platform(platform) == "unix"} {
        set log_cmd_str $log_filename
        set append_sw " -a "
        if { $b_is_pure_systemc } { set append_sw " " }
        set full_cmd "xsc $xsc_cmd_str 2>&1 | tee${append_sw}${log_cmd_str}"
        if { [get_param "project.optimizeScriptGenForSimulation"] } {
          append full_cmd " &"
        }
        puts $fh_scr "$full_cmd"
        puts $fh_scr "XSC_SYSC_PID=\$!"
        xcs_write_exit_code $fh_scr
      } else {
        puts $fh_scr "call xsc $a_sim_vars(s_dbg_sw) $xsc_cmd_str 2> xsc_err.log"
        puts $fh_scr "call type xsc.log >> $log_filename"
        puts $fh_scr "call type xsc_err.log >> $log_filename"
        puts $fh_scr "call type xsc_err.log"
      }
    }
  }
}

proc usf_xsim_write_cpp_prj { b_is_pure_cpp fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { !$a_sim_vars(b_int_systemc_mode) } {
    return
  }

  # cpp prj file
  if { !$a_sim_vars(b_contain_cpp_sources) } {
    return
  }

  set cpp_filename "$a_sim_vars(s_sim_top)_cpp.prj"
  set cpp_file [file normalize [file join $a_sim_vars(s_launch_dir) $cpp_filename]]
  set cpp_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"CPP\")"
  set cpp_files [xcs_get_c_files $cpp_filter $a_sim_vars(b_int_csim_compile_order)]
  if { [llength $cpp_files] > 0 } {
    set fh_cpp 0
    if {[catch {open $cpp_file w} fh_cpp]} {
      send_msg_id USF-XSim-016 ERROR "Failed to open file to write ($cpp_file)\n"
      return 1
    }
    puts $fh_cpp "# compile cpp design source files"
    foreach file $a_sim_vars(l_design_files) {
      set fargs       [split $file {|}]
      set type        [lindex $fargs 0]
      set file_type   [lindex $fargs 1]
      set lib         [lindex $fargs 2]
      set cmd_str     [lindex $fargs 3]
      set src_file    [lindex $fargs 4]
      set b_static_ip [lindex $fargs 5]
      if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
      switch $type {
        {CPP} {
          puts $fh_cpp "\"$src_file\""
        }
      }
    }
    close $fh_cpp

    set xsc_arg_list [list]
    lappend xsc_arg_list "-c"
    set more_xsc_options [string trim [get_property "xsim.compile.xsc.more_options" $a_sim_vars(fs_obj)]]
    if { {} != $more_xsc_options } {
      set xsc_arg_list [linsert $xsc_arg_list end "$more_xsc_options"]
    }

    # fetch systemc include files (.h)
    set simulator "xsim"
    set prefix_ref_dir false
    set l_incl_dirs [list]
    set filter  "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C Header Files\")"
    foreach dir [xcs_get_c_incl_dirs $simulator $a_sim_vars(s_launch_dir) $a_sim_vars(s_boost_dir) $filter $a_sim_vars(dynamic_repo_dir) false $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
      lappend l_incl_dirs "$dir"
    }
   
    if { [llength $l_incl_dirs] > 0 } {
      lappend xsc_arg_list "--gcc_compile_options"
      set incl_dir_strs [list]
      foreach incl_dir $l_incl_dirs {
        lappend incl_dir_strs "-I$incl_dir"
      }
      set incl_dir_cmd_str [join $incl_dir_strs " "]
      lappend xsc_arg_list "\"$incl_dir_cmd_str\""
    }
    lappend xsc_arg_list "-work $a_sim_vars(default_top_library)"
    lappend xsc_arg_list "-f $cpp_filename"
    set xsc_cmd_str [join $xsc_arg_list " "]
    set log_filename "compile.log"
    puts $fh_scr "$a_sim_vars(script_cmt_tag) compile CPP design sources"
    puts $fh_scr "echo \"xsc $xsc_cmd_str\""
    if {$::tcl_platform(platform) == "unix"} {
      set log_cmd_str $log_filename
      set append_sw " -a "
      if { $b_is_pure_cpp } { set append_sw " " }
      set full_cmd "xsc $xsc_cmd_str 2>&1 | tee${append_sw}${log_cmd_str}"
      if { [get_param "project.optimizeScriptGenForSimulation"] } {
        append full_cmd " &"
      }
      puts $fh_scr "$full_cmd"
      puts $fh_scr "XSC_CPP_PID=\$!"
      xcs_write_exit_code $fh_scr
    } else {
      puts $fh_scr "call xsc $a_sim_vars(s_dbg_sw) $xsc_cmd_str 2> xsc_err.log"
      puts $fh_scr "call type xsc.log >> $log_filename"
      puts $fh_scr "call type xsc_err.log >> $log_filename"
      puts $fh_scr "call type xsc_err.log"
    }
  }
}

proc usf_xsim_write_c_prj { b_is_pure_c fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { !$a_sim_vars(b_int_systemc_mode) } {
    return
  }

  # c prj file
  if { !$a_sim_vars(b_contain_c_sources) } {
    return
  }

  set c_filename "$a_sim_vars(s_sim_top)_c.prj"
  set c_file [file normalize [file join $a_sim_vars(s_launch_dir) $c_filename]]
  set c_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C\")"
  set c_files [xcs_get_c_files $c_filter $a_sim_vars(b_int_csim_compile_order)]
  if { [llength $c_files] > 0 } {
    set fh_c 0
    if {[catch {open $c_file w} fh_c]} {
      send_msg_id USF-XSim-016 ERROR "Failed to open file to write ($c_file)\n"
      return 1
    }
    puts $fh_c "# compile c design source files"
    foreach file $a_sim_vars(l_design_files) {
      set fargs       [split $file {|}]
      set type        [lindex $fargs 0]
      set file_type   [lindex $fargs 1]
      set lib         [lindex $fargs 2]
      set cmd_str     [lindex $fargs 3]
      set src_file    [lindex $fargs 4]
      set b_static_ip [lindex $fargs 5]
      if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
      switch $type {
        {C} {
          puts $fh_c "\"$src_file\""
        }
      }
    }
    close $fh_c

    set xsc_arg_list [list]
    lappend xsc_arg_list "-c"
    set more_xsc_options [string trim [get_property "xsim.compile.xsc.more_options" $a_sim_vars(fs_obj)]]
    if { {} != $more_xsc_options } {
      set xsc_arg_list [linsert $xsc_arg_list end "$more_xsc_options"]
    }

    # fetch systemc include files (.h)
    set simulator "xsim"
    set prefix_ref_dir false
    set l_incl_dirs [list]
    set filter  "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C Header Files\")" 
    foreach dir [xcs_get_c_incl_dirs $simulator $a_sim_vars(s_launch_dir) $a_sim_vars(s_boost_dir) $filter $a_sim_vars(dynamic_repo_dir) false $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
      lappend l_incl_dirs "$dir"
    }
   
    if { [llength $l_incl_dirs] > 0 } {
      lappend xsc_arg_list "--gcc_compile_options"
      set incl_dir_strs [list]
      foreach incl_dir $l_incl_dirs {
        lappend incl_dir_strs "-I$incl_dir"
      }
      set incl_dir_cmd_str [join $incl_dir_strs " "]
      lappend xsc_arg_list "\"$incl_dir_cmd_str\""
    }
    lappend xsc_arg_list "-work $a_sim_vars(default_top_library)"
    lappend xsc_arg_list "-f $c_filename"
    set xsc_cmd_str [join $xsc_arg_list " "]
    set log_filename "compile.log"
    puts $fh_scr "$a_sim_vars(script_cmt_tag) compile C design sources"
    puts $fh_scr "echo \"xsc $xsc_cmd_str\""

    if {$::tcl_platform(platform) == "unix"} {
      set log_cmd_str $log_filename
      set append_sw " -a "
      if { $b_is_pure_c } { set append_sw " " }
      set full_cmd "xsc $xsc_cmd_str 2>&1 | tee${append_sw}${log_cmd_str}"
      if { [get_param "project.optimizeScriptGenForSimulation"] } {
        append full_cmd " &"
      }
      puts $fh_scr "$full_cmd"
      puts $fh_scr "XSC_C_PID=\$!"
      xcs_write_exit_code $fh_scr
    } else {
      puts $fh_scr "call xsc $a_sim_vars(s_dbg_sw) $xsc_cmd_str 2> xsc_err.log"
      puts $fh_scr "call type xsc.log >> $log_filename"
      puts $fh_scr "call type xsc_err.log >> $log_filename"
      puts $fh_scr "call type xsc_err.log"
    }
  }
}

proc usf_xsim_write_asm_prj { b_is_pure_asm fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  if { !$a_sim_vars(b_int_systemc_mode) } {
    return
  }

  # asm prj file
  if { !$a_sim_vars(b_contain_asm_sources) } {
    return
  }

  set asm_filename "$a_sim_vars(s_sim_top)_asm.prj"
  set asm_file [file normalize [file join $a_sim_vars(s_launch_dir) $asm_filename]]
  set asm_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"ASM\")"
  set asm_files [xcs_get_asm_files $asm_filter $a_sim_vars(b_int_csim_compile_order)]
  if { [llength $asm_files] > 0 } {
    set fh_asm 0
    if {[catch {open $asm_file w} fh_asm]} {
      send_msg_id USF-XSim-016 ERROR "Failed to open file to write ($asm_file)\n"
      return 1
    }
    puts $fh_asm "# compile assembly design source files"
    foreach file $a_sim_vars(l_design_files) {
      set fargs       [split $file {|}]
      set type        [lindex $fargs 0]
      set file_type   [lindex $fargs 1]
      set lib         [lindex $fargs 2]
      set cmd_str     [lindex $fargs 3]
      set src_file    [lindex $fargs 4]
      set b_static_ip [lindex $fargs 5]
      if { $a_sim_vars(b_use_static_lib) && ($b_static_ip) } { continue }
      switch $type {
        {ASM} {
          puts $fh_asm "\"$src_file\""
        }
      }
    }
    close $fh_asm

    set xsc_arg_list [list]
    lappend xsc_arg_list "-c"
    set more_xsc_options [string trim [get_property "xsim.compile.xsc.more_options" $a_sim_vars(fs_obj)]]
    if { {} != $more_xsc_options } {
      set xsc_arg_list [linsert $xsc_arg_list end "$more_xsc_options"]
    }

    # fetch systemc include files (.h)
    set simulator "xsim"
    set prefix_ref_dir false
    set l_incl_dirs [list]
    set filter  "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C Header Files\")" 
    foreach dir [xcs_get_c_incl_dirs $simulator $a_sim_vars(s_launch_dir) $a_sim_vars(s_boost_dir) $filter $a_sim_vars(dynamic_repo_dir) false $a_sim_vars(b_absolute_path) $prefix_ref_dir] {
      lappend l_incl_dirs "$dir"
    }
   
    if { [llength $l_incl_dirs] > 0 } {
      lappend xsc_arg_list "--gcc_compile_options"
      set incl_dir_strs [list]
      foreach incl_dir $l_incl_dirs {
        lappend incl_dir_strs "-I$incl_dir"
      }
      set incl_dir_cmd_str [join $incl_dir_strs " "]
      lappend xsc_arg_list "\"$incl_dir_cmd_str\""
    }
    lappend xsc_arg_list "-work $a_sim_vars(default_top_library)"
    lappend xsc_arg_list "-f $asm_filename"
    set xsc_cmd_str [join $xsc_arg_list " "]
    set log_filename "compile.log"
    puts $fh_scr "$a_sim_vars(script_cmt_tag) compile assembly design sources"
    puts $fh_scr "echo \"xsc $xsc_cmd_str\""

    if {$::tcl_platform(platform) == "unix"} {
      set log_cmd_str $log_filename
      set append_sw " -a "
      if { $b_is_pure_asm } { set append_sw " " }
      set full_cmd "xsc $xsc_cmd_str 2>&1 | tee${append_sw}${log_cmd_str}"
      if { [get_param "project.optimizeScriptGenForSimulation"] } {
        append full_cmd " &"
      }
      puts $fh_scr "$full_cmd"
      puts $fh_scr "XSC_ASM_PID=\$!"
      xcs_write_exit_code $fh_scr
    } else {
      puts $fh_scr "call xsc $a_sim_vars(s_dbg_sw) $xsc_cmd_str 2> xsc_err.log"
      puts $fh_scr "call type xsc.log >> $log_filename"
      puts $fh_scr "call type xsc_err.log >> $log_filename"
      puts $fh_scr "call type xsc_err.log"
    }
  }
}

proc usf_xsim_write_windows_exit_code { fh_scr } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars
 
  if {$::tcl_platform(platform) != "unix"} {
    set b_call_script_exit [get_property -quiet "xsim.call_script_exit" $a_sim_vars(fs_obj)]
    puts $fh_scr "if \"%errorlevel%\"==\"1\" goto END"
    puts $fh_scr "if \"%errorlevel%\"==\"0\" goto SUCCESS"
    puts $fh_scr ":END"
    if { $a_sim_vars(b_scripts_only) && !($b_call_script_exit) } {
      # no exit
    } else {
      puts $fh_scr "exit 1"
    }
    puts $fh_scr ":SUCCESS"
    if { $a_sim_vars(b_scripts_only) && !($b_call_script_exit) } {
      # no exit
    } else {
      puts $fh_scr "exit 0"
    }
  }
}

proc usf_delete_generated_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_vars

  # delete files for the simset top
  foreach prj_file [glob -nocomplain -directory $a_sim_vars(s_launch_dir) *_vlog.prj] { [catch {file delete -force $prj_file} error_msg] }
  foreach prj_file [glob -nocomplain -directory $a_sim_vars(s_launch_dir) *_vhdl.prj] { [catch {file delete -force $prj_file} error_msg] }
  foreach prj_file [glob -nocomplain -directory $a_sim_vars(s_launch_dir) *_xsc.prj]  { [catch {file delete -force $prj_file} error_msg] }
}

proc usf_xsim_escape_quotes { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set cmd $args
  set b_found 0
  set updated_args [list]
  set args_list [split $args " "]

  # args contain -d or -generic_top? (verilog_define)
  # --incr --debug typical --relax --mt 8 -d "a=20" -d \"hex=64'h1234\" -generic_top "g=342"
  if { [regexp { \-d } $args_list] } {
    foreach arg $args_list {
      if { {-d} == $arg } {
        # set flag for next arg value ("a=20")
        set b_found 1
        lappend updated_args $arg
        continue
      }
      if { $b_found } {
        # if value specified is of type hex (val=128'h123)? wrap in quotes with back-slash
        if { [regexp {'} $arg] } {
          set val [string trim $arg \"]
          set arg "\\\"$val\\\""
        }
        set b_found 0
      }
      lappend updated_args $arg
    }
    set cmd [join $updated_args " "]
  } elseif { [regexp { \-generic_top } $args_list] } {
    foreach arg $args_list {
      if { {-generic_top} == $arg } {
        # set flag for next arg value ("g=342")
        set b_found 1
        lappend updated_args $arg
        continue
      }
      if { $b_found } {
        # if value specified is of type hex (val=128'h123)? wrap in quotes with back-slash
        if { [regexp {'} $arg] } {
          set val [string trim $arg \"]
          set arg "\\\"$val\\\""
        }
        set b_found 0
      }
      lappend updated_args $arg
    }
    set cmd [join $updated_args " "]
  }

  # trim curly-braces
  return [string trim $cmd "\{\}"]
}

}
