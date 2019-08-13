######################################################################
#
# sim.tcl
#
# based on XilinxTclStore\tclapp\xilinx\modelsim\sim.tcl
#
######################################################################

package require Vivado 1.2014.1

package require ::tclapp::aldec::common::helpers 1.16

package provide ::tclapp::aldec::common::sim 1.16

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
  usf_setup_args $args
  set onlyGenerateScripts $::tclapp::aldec::common::helpers::properties(only_generate_scripts)
  set simulatorName [::tclapp::aldec::common::helpers::usf_aldec_getSimulatorName]

  send_msg_id USF-${simulatorName}-82 INFO "${simulatorName}::Compile design"
  usf_aldec_write_compile_script

  if { !$onlyGenerateScripts } {
    set proc_name [lindex [split [info level 0] " "] 0]
    set step [lindex [split $proc_name {:}] end]
    ::tclapp::aldec::common::helpers::usf_launch_script $step
  }

  	if { [ ::tclapp::aldec::common::helpers::isGenerateLaibraryMode ] == 1 && [ ::tclapp::aldec::common::helpers::isBatchMode ] != 1 } {
		createLibraryCfg
	}
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
  usf_setup_args $args
  set onlyGenerateScripts $::tclapp::aldec::common::helpers::properties(only_generate_scripts)
  set dir $::tclapp::aldec::common::helpers::properties(launch_directory)
  
  set simulatorName [::tclapp::aldec::common::helpers::usf_aldec_getSimulatorName]

  send_msg_id USF-${simulatorName}-83 INFO "${simulatorName}::Simulate design"
  usf_write_simulate_script

  if { !$onlyGenerateScripts } {
    set proc_name [lindex [split [info level 0] " "] 0]
    set step [lindex [split $proc_name {:}] end]
    ::tclapp::aldec::common::helpers::usf_launch_script $step
  }

  if { $onlyGenerateScripts } {
    set fh 0
    set file [::tclapp::aldec::common::helpers::usf_file_normalize [file join $dir "simulate.log"]]
    if {[catch {open $file w} fh]} {
      send_msg_id USF-${simulatorName}-84 ERROR "Failed to open file to write ($file)\n"
    } else {
  # change file permissions to executable
      foreach file [list "compile.sh" "simulate.sh"] {
        set file_path "$dir/$file"
        if { [file exists $file_path] } {
         ::tclapp::aldec::common::helpers::usf_make_file_executable $file_path
        }
      }
      puts $fh "INFO: Scripts generated successfully. Please see the 'Tcl Console' window for details."
      close $fh
    }
  }
}
}

namespace eval ::tclapp::aldec::common::sim {

proc createLibraryCfg { } {
	set dir $::tclapp::aldec::common::helpers::properties(launch_directory)
	set projectName $::tclapp::aldec::common::helpers::properties(project_name)
	set libraryCfgPath [::tclapp::aldec::common::helpers::usf_file_normalize [ file join $dir $projectName "library.cfg" ] ]

	catch { file mkdir [file dirname $libraryCfgPath] }

	set fileStream 0
	if { [ catch {open $libraryCfgPath w} fileStream ] } {
		send_msg_id USF-[usf_aldec_getSimulatorName]-90 ERROR "Failed to open file to write ($libraryCfgPath)\n"
		return
	}

	puts $fileStream "\$include = \"\$VSIMSALIBRARYCFG\""
	puts $fileStream "\$include = \"./../\""
	close $fileStream
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

  variable properties

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

  set launchDirectory $::tclapp::aldec::common::helpers::properties(launch_directory)
  ::tclapp::aldec::common::helpers::findSystemVerilogPackageLibraries $launchDirectory

  ::tclapp::aldec::common::helpers::findAllDesignFiles
  ::tclapp::aldec::common::helpers::findCompiledLibraries 

	# extract simulation model library info
	::tclapp::aldec::common::helpers::usf_fetch_lib_info \
		[ get_property target_simulator [ current_project ] ] \
		[ ::tclapp::aldec::common::helpers::getCompiledLibraryLocation ]

	# find shared library paths from all IPs
	if { [ ::tclapp::aldec::common::helpers::isSystemCEnabled ] } {
		if { [::tclapp::aldec::common::helpers::usf_contains_C_files] } {
			::tclapp::aldec::common::helpers::usf_find_shared_lib_paths \
				[ get_property target_simulator [ current_project ] ] \
				[ ::tclapp::aldec::common::helpers::getCompiledLibraryLocation ] \
				$::tclapp::aldec::common::helpers::properties(custom_sm_lib_dir) \
				::tclapp::aldec::common::helpers::properties(sp_cpt_dir) \
				::tclapp::aldec::common::helpers::properties(sp_ext_dir)
		}
	}
	
  # fetch design files
  set global_files_str {}
  set ::tclapp::aldec::common::helpers::properties(designFiles) \
     [::tclapp::aldec::common::helpers::usf_uniquify_cmd_str [::tclapp::aldec::common::helpers::usf_get_files_for_compilation global_files_str]]

  # create setup file
  usf_aldec_write_setup_files

	::tclapp::aldec::common::helpers::findCompileOrderFilesUniq
	::tclapp::aldec::common::helpers::findPrecompiledLibrary
	
  return 0
}

proc usf_setup_args { args } {
  # Summary:
  # 

  # Argument Usage:
  # [-simset <arg>]: Name of the simulation fileset
  # [-mode <arg>]: Simulation mode. Values: behavioral, post-synthesis, post-implementation
  # [-type <arg>]: Netlist type. Values: functional, timing. This is only applicable when mode is set to post-synthesis or post-implementation
  # [-scripts_only]: (obsolete) Only generate scripts
  # [-generate_scripts_only]: (internal) Only generate scripts
  # [-of_objects <arg>]: Generate do file for this object (applicable with -scripts_only option only)
  # [-absolute_path]: Make all file paths absolute wrt the reference directory
  # [-lib_map_path <arg>]: Precompiled simulation library directory path
  # [-install_path <arg>]: Custom ModelSim installation directory path
  # [-batch]: Execute batch flow simulation run (non-gui)
  # [-run_dir <arg>]: Simulation run directory
  # [-int_os_type]: OS type (32 or 64) (internal use)
  # [-int_debug_mode]: Debug mode (internal use)
  # [-int_systemc_mode]: SystemC mode (internal use)
  # [-int_sm_lib_ref_debug]: Print simulation model library referencing debug messages (internal use)
  # [-int_csim_compile_order]: Use compile order for co-simulation (internal use)

  # Return Value:
  # true (0) if success, false (1) otherwise

  # Categories: xilinxtclstore

  set args [string trim $args "\}\{"]
  #puts "Debug:"
  #puts $args

  # process options
  for {set i 0} {$i < [llength $args]} {incr i} {
    set option [string trim [lindex $args $i]]
    switch -regexp -- $option {
      "-simset"         { incr i;set ::tclapp::aldec::common::helpers::properties(simset) [lindex $args $i] }
      "-mode"           { incr i;set ::tclapp::aldec::common::helpers::properties(mode) [lindex $args $i] }
      "-type"           { incr i;set ::tclapp::aldec::common::helpers::properties(s_type) [lindex $args $i] }
      "-scripts_only|-generate_scripts_only"   { set ::tclapp::aldec::common::helpers::properties(only_generate_scripts) 1 }
      "-of_objects"     { incr i;set ::tclapp::aldec::common::helpers::properties(s_comp_file) [lindex $args $i]}
      "-absolute_path"  { set ::tclapp::aldec::common::helpers::properties(use_absolute_paths) 1 }
      "-lib_map_path"   { incr i;set ::tclapp::aldec::common::helpers::properties(s_lib_map_path) [lindex $args $i] }
      "-install_path"   { incr i;set ::tclapp::aldec::common::helpers::properties(s_install_path) [lindex $args $i] }
      "-batch"          { set ::tclapp::aldec::common::helpers::properties(batch_mode_enabled) 1 }
      "-run_dir"        { incr i;set ::tclapp::aldec::common::helpers::properties(launch_directory) [lindex $args $i] }
      "-int_os_type"    { incr i;set ::tclapp::aldec::common::helpers::properties(s_int_os_type) [lindex $args $i] }
      "-int_debug_mode" { incr i;set ::tclapp::aldec::common::helpers::properties(s_int_debug_mode) [lindex $args $i] }
	  "-int_systemc_mode"		{ set ::tclapp::aldec::common::helpers::properties(b_int_systemc_mode) 1	}
	  "-int_sm_lib_dir"         { incr i;set ::tclapp::aldec::common::helpers::properties(custom_sm_lib_dir) [lindex $args $i] }
      "-int_sm_lib_ref_debug"   { set ::tclapp::aldec::common::helpers::properties(b_int_sm_lib_ref_debug) 1                   }
	  "-int_csim_compile_order" { set ::tclapp::aldec::common::helpers::properties(b_int_csim_compile_order) 1                 }
      default {
        # is incorrect switch specified?
        if { [regexp {^-} $option] } {
          send_msg_id USF-[usf_aldec_getSimulatorName]-85 WARNING "Unknown option '$option', please type 'launch_simulation -help' for usage info.\n"
        }
      }
    }
  }
  #puts "Debug:"
  #puts $::tclapp::aldec::common::helpers::properties(only_generate_scripts)
}


proc usf_aldec_write_setup_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::common::helpers::properties(s_sim_top)
  set dir $::tclapp::aldec::common::helpers::properties(launch_directory)

  # msim lib dir
  set lib_dir [::tclapp::aldec::common::helpers::usf_file_normalize [file join $dir "msim"]]
  if { [file exists $lib_dir] } {
    if {[catch {file delete -force $lib_dir} error_msg] } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-86 ERROR "Failed to delete directory ($lib_dir): $error_msg\n"
      return 1
    }
  }
}

proc usf_aldec_write_compile_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::common::helpers::properties(s_sim_top)
  set fs_obj [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]

  set do_filename {}

  set do_filename $top; append do_filename "_compile.do"
  set dir $::tclapp::aldec::common::helpers::properties(launch_directory)
  set do_file [::tclapp::aldec::common::helpers::usf_file_normalize [file join $dir $do_filename]]

  send_msg_id USF-[usf_aldec_getSimulatorName]-87 INFO "Creating automatic 'do' files...\n"

  usf_aldec_create_do_file_for_compilation $do_file

  # write compile.sh/.bat
  usf_aldec_write_driver_shell_script $do_filename "compile"
}

proc usf_write_simulate_script {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set fs_obj [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]

  set do_filename [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.CUSTOM_DO] $fs_obj]
  ::tclapp::aldec::common::helpers::usf_aldec_get_file_path_from_project do_filename

  if { ![file isfile $do_filename] || [::tclapp::aldec::common::helpers::usf_aldec_is_file_disabled $do_filename] } {

    if { $do_filename != "" } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-88 WARNING "Custom DO file '$do_filename' not found or disabled.\n"
    }

    set top $::tclapp::aldec::common::helpers::properties(s_sim_top)
    set do_filename $top
    append do_filename "_simulate.do"
    set dir $::tclapp::aldec::common::helpers::properties(launch_directory)
    set do_file [::tclapp::aldec::common::helpers::usf_file_normalize [file join $dir $do_filename]]
    usf_aldec_create_do_file_for_simulation $do_file
  }

  # write elaborate.sh/.bat
  usf_aldec_write_driver_shell_script $do_filename "simulate"
}

proc mapLibraryCfg { _variable { _simulation 0 } } {
	set usePrecompiledIp $::tclapp::aldec::common::helpers::properties(b_use_static_lib)
	if { $usePrecompiledIp != 1 } {
		return
	}

	set librariesLocation [ ::tclapp::aldec::common::helpers::getCompiledLibraryLocation ]
	if { $librariesLocation == "" } {
		return
	}

	set libraryCfgFile [ file join $librariesLocation library.cfg ]
	if { ![ file isfile $libraryCfgFile ] } {
		return
	}

	set topLibrary [ ::tclapp::aldec::common::helpers::usf_get_top_library ]
	set libraryCfg [ open $libraryCfgFile r ]
	set xpmLibrary [ ::tclapp::aldec::common::helpers::getXpmLibraries ]

	set librariesPattern [ list ]
	if { $_simulation == 0 } {
		set simulationFlow $::tclapp::aldec::common::helpers::properties(s_simulation_flow)
		set designFiles $::tclapp::aldec::common::helpers::properties(designFiles)
		set fs_obj [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]

		set netlistMode [ get_property "NL.MODE" $fs_obj ]
		set targetLang  [get_property "TARGET_LANGUAGE" [current_project]]

		if { ({post_synth_sim} == $simulationFlow) || ({post_impl_sim} == $simulationFlow) } {
			if { [ ::tclapp::aldec::common::helpers::usf_contains_verilog $designFiles ] || ({Verilog} == $targetLang) } {
				if { {timesim} == $netlistMode } {
					lappend librariesPattern "simprims_ver"
				} else {
					lappend librariesPattern "unisims_ver"
				}
			}
		}

		set compileUnifast [ get_property [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName ELABORATE.UNIFAST ] $fs_obj ]
		if { ([ ::tclapp::aldec::common::helpers::usf_contains_vhdl $designFiles ]) && ({behav_sim} == $simulationFlow) } {
			if { $compileUnifast && [ get_param "simulation.addUnifastLibraryForVhdl" ] } {
				lappend librariesPattern "unifast"
			}
		}

		if { ([::tclapp::aldec::common::helpers::usf_contains_verilog $designFiles]) && ({behav_sim} == $simulationFlow) } {
			if { $compileUnifast } {
				lappend librariesPattern "unifast_ver"
			}

			lappend librariesPattern "unisims_ver"
			lappend librariesPattern "unimacro_ver"
		}

		lappend librariesPattern "secureip"
		lappend librariesPattern "unisim"
	}

	lappend librariesPattern "xilinx_vip"

	if { [ llength $xpmLibrary ] > 0 } {
		lappend librariesPattern "xpm"
	}
	
	while { ! [eof $libraryCfg ] } {
		gets $libraryCfg line
		if { [ regexp {\s*([^\s]+)\s*=\s*\"?([^\s\"]+).*} $line tmp mapName mapPath ] } {

			if { [ file pathtype $mapPath ] != "absolute" } {
				set mapPath [ file join $librariesLocation $mapPath ]
			}

			set mapPath [ ::tclapp::aldec::common::helpers::usf_file_normalize $mapPath ]

			if { ![ file isfile $mapPath ] } {
				continue
			}

			if { $_simulation == 1 && [ ::tclapp::aldec::common::helpers::isGenerateLaibraryMode ] == 1 && $topLibrary != $mapName } {
				continue
			}	

			foreach library $librariesPattern {
				if { $mapName == $library } {
					puts $_variable "vmap $mapName \{$mapPath\}"
					continue
				}
			}

			if { [ ::tclapp::aldec::common::helpers::isDesignLibrary $mapName ] == 1 } {
				puts $_variable "vmap $mapName \{$mapPath\}"
			}
		}
	}

	close $libraryCfg

	puts $_variable ""
}

proc usf_aldec_create_do_file_for_compilation { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  send_msg_id USF-[usf_aldec_getSimulatorName]-89 INFO "$do_file\n"

  set top $::tclapp::aldec::common::helpers::properties(s_sim_top)
  set use_absolute_paths $::tclapp::aldec::common::helpers::properties(use_absolute_paths)
  set target_simulator [get_property target_simulator [current_project]]
  if { $target_simulator == "ActiveHDL" } {
    set use_absolute_paths 1
  }  

  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-[usf_aldec_getSimulatorName]-90 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_aldec_write_header $fh $do_file
  usf_aldec_add_quit_on_error $fh "compile"

  set fs_obj [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]
  set tcl_pre_hook [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName COMPILE.TCL.PRE] $fs_obj]
  ::tclapp::aldec::common::helpers::usf_aldec_get_file_path_from_project tcl_pre_hook
  if { [file isfile $tcl_pre_hook] && ![::tclapp::aldec::common::helpers::usf_aldec_is_file_disabled $tcl_pre_hook] } {
    puts $fh "\nsource \{$tcl_pre_hook\}\n"
  } elseif { $tcl_pre_hook != "" } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-91 WARNING "File '$tcl_pre_hook' not found or disabled.\n"
  }

  puts $fh "vlib work\n"

  mapLibraryCfg $fh

  set design_libs [::tclapp::aldec::common::helpers::getDesignLibraries $::tclapp::aldec::common::helpers::properties(designFiles)]

  # TODO:
  # If DesignFiles contains VHDL files, but simulation language is set to Verilog, we should issue CW
  # Vice verse, if DesignFiles contains Verilog files, but simulation language is set to VHDL

	set libraryPrefix [ ::tclapp::aldec::common::helpers::usf_aldec_getLibraryPrefix ]
	set defaultLibraryMapped false
	set defaultLibraryName [ get_property "DEFAULT_LIB" [ current_project ] ]
	set usePrecompiledIp $::tclapp::aldec::common::helpers::properties(b_use_static_lib)

	foreach lib $design_libs {
		if { [ string length $lib ] == 0 } {
			continue;
		}

		if { $usePrecompiledIp == 1 && [ ::tclapp::aldec::common::helpers::checkLibraryWasCompiled $lib ] == 1 } {
			continue
		}

		puts $fh "vlib ${libraryPrefix}$lib"

		if { [ get_property INCREMENTAL $fs_obj ] == 0 } {
			puts $fh "vdel -lib $lib -all"
		}

		if { $defaultLibraryName == $lib } {
			set defaultLibraryMapped true
		}
	}

	if { !$defaultLibraryMapped } {
		puts $fh "vlib ${libraryPrefix}$defaultLibraryName"
		
		if { [ get_property INCREMENTAL $fs_obj ] == 0 } {
			puts $fh "vdel -lib $defaultLibraryName -all"
		}
	}

	puts $fh ""

	if { $use_absolute_paths } {
		set dir $::tclapp::aldec::common::helpers::properties(launch_directory)
		puts $fh "null \[set origin_dir \"$dir\"\]"
	} else {
		puts $fh "null \[set origin_dir \".\"\]"
	}

	set vlog_arg_list [ list ]
	::tclapp::aldec::common::helpers::usf_aldec_appendCompilationCoverageOptions vlog_arg_list vlog

	if { [ get_property [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName COMPILE.DEBUG ] $fs_obj ] } {
		lappend vlog_arg_list "-dbg"
	}

	if { [ get_property INCREMENTAL $fs_obj ] == 1 } {
		lappend vlog_arg_list "-incr"
	}

	if { [ llength [ ::tclapp::aldec::common::helpers::getXpmLibraries ] ] > 0 } {
		lappend vlog_arg_list "-l xpm"
	}

	set more_vlog_options [ string trim [ get_property [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName COMPILE.VLOG.MORE_OPTIONS ] $fs_obj ] ]
	if { {} != $more_vlog_options } {
		set vlog_arg_list [ linsert $vlog_arg_list end "$more_vlog_options" ]
	}

	set xilinxVipWasAdded 0
	foreach lib $design_libs {
		if { [ string length $lib ] == 0 } {
			continue;
		}

		lappend vlog_arg_list "-l"
		lappend vlog_arg_list "$lib"

		if { $lib == "xilinx_vip" } {
			set xilinxVipWasAdded 1
		}
	}

	if { $xilinxVipWasAdded == 0 && [ get_param "project.usePreCompiledXilinxVIPLibForSim" ] && [ ::tclapp::aldec::common::helpers::is_vip_ip_required ] } {
		lappend vlog_arg_list "-l"
		lappend vlog_arg_list "xilinx_vip"
	}

  set vlog_cmd_str [join $vlog_arg_list " "]
  puts $fh "null \[set vlog_opts \{$vlog_cmd_str\}\]"

  set vcom_arg_list [list]
  ::tclapp::aldec::common::helpers::usf_aldec_appendCompilationCoverageOptions vcom_arg_list vcom
  if { [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName COMPILE.VHDL_RELAX] $fs_obj] } {
    lappend vcom_arg_list "-relax"
  }
  if { [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName COMPILE.DEBUG] $fs_obj] } {
    lappend vcom_arg_list "-dbg"
  }
  if { [get_property INCREMENTAL $fs_obj] == 1 } {
    lappend vcom_arg_list "-incr"
  }
  set more_vcom_options [string trim [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName COMPILE.VCOM.MORE_OPTIONS] $fs_obj]]
  if { {} != $more_vcom_options } {
    set vcom_arg_list [linsert $vcom_arg_list end "$more_vcom_options"]
  }

  set vcom_cmd_str [join $vcom_arg_list " "]
  puts $fh "null \[set vcom_opts \{$vcom_cmd_str\}\]"

  puts $fh ""

  set prev_lib  {}
  set prev_file_type {}
  set b_group_files [get_param "project.assembleFilesByLibraryForUnifiedSim"]
  set useAddsc 0
	
	foreach file $::tclapp::aldec::common::helpers::properties(designFiles) {
		set fargs [ split $file {|} ]
		set type [ lindex $fargs 0 ]
		set file_type [ lindex $fargs 1 ]
		set lib [ lindex $fargs 2 ]
		set cmd_str [ lindex $fargs 3 ]
		set src_file [ lindex $fargs 4 ]
		set b_static_ip [ lindex $fargs 5 ]

		if { $usePrecompiledIp == 1 && [ ::tclapp::aldec::common::helpers::checkLibraryWasCompiled $lib ] == 1 } {
			continue
		}

		if { ![ regexp "\".*\"" $src_file ] } {
			set src_file "\"$src_file\""
		}
		
		if { $b_group_files } {
			if { ( $file_type != $prev_file_type ) || ( $lib != $prev_lib ) } {
				set prev_file_type $file_type
				set prev_lib $lib
				puts $fh ""
				puts $fh "$cmd_str \\"
			}
			puts $fh "\t$src_file \\"
			
		} else {
			puts $fh "$cmd_str $src_file"
		}

		if { $file_type == "SystemC" } {
			set useAddsc 1
		}
	}

	if { [ ::tclapp::aldec::common::helpers::isSystemCEnabled ] && $useAddsc == 1 } {
		puts $fh "\naddsc [ ::tclapp::aldec::common::helpers::getSystemCLibrary ]"
	}

  if { $b_group_files } {
    # break multi-line command
    puts $fh ""
  }

  # compile glbl file
  set b_load_glbl [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName COMPILE.LOAD_GLBL] [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]]
  if { [::tclapp::aldec::common::helpers::usf_compile_glbl_file $target_simulator $b_load_glbl $::tclapp::aldec::common::helpers::properties(designFiles)] } {
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
  
  set top $::tclapp::aldec::common::helpers::properties(s_sim_top)
  set sim_flow $::tclapp::aldec::common::helpers::properties(s_simulation_flow)
  set fs_obj [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]

  set target_lang  [get_property "TARGET_LANGUAGE" [current_project]]
  set netlist_mode [get_property "NL.MODE" $fs_obj]

  set arg_list [list]

  if { [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName ELABORATE.ACCESS] $fs_obj]
    || [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.LOG_ALL_SIGNALS] $fs_obj]
    || [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.SAIF] $fs_obj] != {} } {
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

  set design_files $::tclapp::aldec::common::helpers::properties(designFiles)

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
  set b_compile_unifast [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName ELABORATE.UNIFAST] $fs_obj]

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
	set design_libs [ ::tclapp::aldec::common::helpers::getDesignLibraries $design_files ]
	set xilinxVipWasAdded 0
	foreach lib $design_libs {
		if {[string length $lib] == 0} { continue; }
		lappend arg_list "-L"
		lappend arg_list "$lib"

		if { $lib == "xilinx_vip" } {
			set xilinxVipWasAdded 1
		}
	}

    if { $xilinxVipWasAdded == 0 && [ get_param "project.usePreCompiledXilinxVIPLibForSim" ] && [ ::tclapp::aldec::common::helpers::is_vip_ip_required ] } {
		lappend arg_list "-L" "xilinx_vip"
	}
  
  set d_libs [join $arg_list " "]  
  set arg_list [list $t_opts]
  lappend arg_list "$d_libs"
  set cmd_str [join $arg_list " "]
  return $cmd_str
}

proc usf_aldec_get_simulation_cmdline {} {
	set top $::tclapp::aldec::common::helpers::properties(s_sim_top)
	set flow $::tclapp::aldec::common::helpers::properties(s_simulation_flow)
	set fs_obj [ get_filesets $::tclapp::aldec::common::helpers::properties(simset) ]

	set target_lang [ get_property "TARGET_LANGUAGE" [ current_project ] ]
	set netlist_mode [ get_property "NL.MODE" $fs_obj ]

	set tool "asim"
	set argumentsList [ list "$tool" ]

	::tclapp::aldec::common::helpers::usf_aldec_appendSimulationCoverageOptions argumentsList

	if { [ get_property target_simulator [ current_project ] ] == "ActiveHDL" } {
		lappend argumentsList "-asdb"
		
		if { [ ::tclapp::aldec::common::helpers::isBatchMode ] == 1 } {
			lappend argumentsList [usf_aldec_getDefaultDatasetName]
		}
	}

	lappend argumentsList [ usf_aldec_get_elaboration_cmdline ]

	if { [ get_property [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.VERILOG_ACCELERATION ] $fs_obj ] } {
		lappend argumentsList "-O5"
	} else {
		lappend argumentsList "-O2"
	}

	if { [ llength [ ::tclapp::aldec::common::helpers::getXpmLibraries ] ] > 0 } {
		lappend argumentsList "-L xpm"
	}

	if { [get_property [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.DEBUG ] $fs_obj ] } {
		lappend argumentsList "-dbg"
	}

	set more_sim_options [ string trim [ get_property [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.ASIM.MORE_OPTIONS ] $fs_obj ] ]
	if { {} != $more_sim_options } {
		set argumentsList [ linsert $argumentsList end "$more_sim_options" ]
	}

	if { [ ::tclapp::aldec::common::helpers::usf_is_axi_bfm_ip ] } {
	set simulator_lib [ ::tclapp::aldec::common::helpers::usf_get_simulator_lib_for_bfm ]
		if { {} != $simulator_lib } {
			set argumentsList [ linsert $argumentsList end "-pli \"$simulator_lib\"" ]
		}
	}

	set top_lib [ ::tclapp::aldec::common::helpers::usf_get_top_library ]
	lappend argumentsList "${top_lib}.${top}"

	set design_files $::tclapp::aldec::common::helpers::properties(designFiles)
	if { [ ::tclapp::aldec::common::helpers::usf_contains_verilog $design_files ] } {
		lappend argumentsList "${top_lib}.glbl"
	}

	return [ join $argumentsList " " ]
}

proc getExistingLibraryMappingsNames { } {
  set projlibCfgDir [file join $::tclapp::aldec::common::helpers::properties(launch_directory) [current_project]]
  set projlibCfgPath [file join $projlibCfgDir "projlib.cfg"] 

  if { ![file exists $projlibCfgPath] } {
    return {}
  }

  set projlibCfg [open $projlibCfgPath r]
  
  set existingMappings {}

  while { ![eof $projlibCfg] } {
    gets $projlibCfg line
    if { [regexp {\s*([^\s]+)\s*=\s*\"?[^\s\"]+.*} $line tmp mappingName] } {
      lappend existingMappings $mappingName
    }
  }

  close $projlibCfg
  
  return $existingMappings
}

proc usf_aldec_writeSimulationPrerequisites { out } {

	set designName [current_project]
	set designLibraryName $designName
	set targetDirectory $::tclapp::aldec::common::helpers::properties(launch_directory)
	set usePrecompiledIp $::tclapp::aldec::common::helpers::properties(b_use_static_lib)

	puts $out "transcript on"

	if { [ ::tclapp::aldec::common::helpers::isBatchMode ] != 1 } {
		puts $out "quiet on"
		puts $out "createdesign \{$designName\} \{$targetDirectory\}"
		puts $out "opendesign \{${targetDirectory}/${designName}/${designName}.adf\}"
		puts $out "set SIM_WORKING_FOLDER \$dsn/.."
	}

	set existingMappings [ getExistingLibraryMappingsNames ]

	if { [ get_property target_simulator [ current_project ] ] == "ActiveHDL" } {
		set designLibraryName [ split $designLibraryName ]
		set designLibraryName [ join $designLibraryName _ ]
	}

	if { [ ::tclapp::aldec::common::helpers::isBatchMode ] != 1 } {
		puts $out "set worklib $designLibraryName"
	}

	foreach mappedLibraryName $existingMappings {
		if { [ string compare -nocase $mappedLibraryName $designLibraryName ] != 0 } {
			puts $out "vmap -del $mappedLibraryName"
		}
	}

	
	if { [ ::tclapp::aldec::common::helpers::isGenerateLaibraryMode ] != 1 || [ ::tclapp::aldec::common::helpers::isBatchMode ] != 1 } {
		mapLibraryCfg $out 1

		set libraryPrefix [ ::tclapp::aldec::common::helpers::usf_aldec_getLibraryPrefix ]
		set librariesNames [ ::tclapp::aldec::common::helpers::getDesignLibraries $::tclapp::aldec::common::helpers::properties(designFiles) ]
		set topLibrary [ ::tclapp::aldec::common::helpers::usf_get_top_library ]

		foreach libraryName $librariesNames {
			if { [ string length $libraryName ] == 0 } {
				continue;
			}

			if { $usePrecompiledIp == 1 && [ ::tclapp::aldec::common::helpers::checkLibraryWasCompiled $libraryName ] == 1 } {
				continue
			}

			if { [ ::tclapp::aldec::common::helpers::isGenerateLaibraryMode ] == 1 && $topLibrary != $libraryName } {
				continue
			}

			puts $out "vmap $libraryName \{${targetDirectory}/${libraryPrefix}$libraryName\}"
		}
	}
	
	if { [ ::tclapp::aldec::common::helpers::isBatchMode ] != 1 } {
		puts $out "quiet off"
	}
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

proc usf_aldec_write_run_string_to_file { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set fs_obj [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]
  set rt [string trim [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.RUNTIME] $fs_obj]]
  if { {} == $rt } {
    # no runtime specified
    puts $fh "run"
  } else {
    set rt_value [string tolower $rt]
    if { ({all} == $rt_value) || (![regexp {^[0-9]} $rt_value]) } {
      puts $fh "run -all"
    } else {
      puts $fh "run $rt"
    }
  }
}

proc usf_aldec_create_do_file_for_simulation { do_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set top $::tclapp::aldec::common::helpers::properties(s_sim_top)
  set fs_obj [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]
  set fh 0
  if {[catch {open $do_file w} fh]} {
    send_msg_id USF-[usf_aldec_getSimulatorName]-92 ERROR "Failed to open file to write ($do_file)\n"
    return 1
  }

  usf_aldec_write_header $fh $do_file
  usf_aldec_add_quit_on_error $fh "simulate"
  

  if { [get_property target_simulator [current_project]] == "ActiveHDL" } {
    usf_aldec_writeSimulationPrerequisites $fh
  }

  puts $fh [usf_aldec_get_simulation_cmdline]
  puts $fh ""

  set customDoFile [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.CUSTOM_UDO] $fs_obj]
  ::tclapp::aldec::common::helpers::usf_aldec_get_file_path_from_project customDoFile
  if { [file isfile $customDoFile] && ![::tclapp::aldec::common::helpers::usf_aldec_is_file_disabled $customDoFile] } {
    puts $fh "do \{$customDoFile\}\n"
  } elseif { $customDoFile != "" } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-93 WARNING "File '$customDoFile' not found or disabled.\n"
  }

  set b_log_all_signals [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.LOG_ALL_SIGNALS] $fs_obj]
  if { $b_log_all_signals } {
    puts $fh "log -rec *"
    if { [::tclapp::aldec::common::helpers::usf_contains_verilog $::tclapp::aldec::common::helpers::properties(designFiles)] } {
      puts $fh "log /glbl/GSR"
    }
  }
  
  set uut [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.UUT] $fs_obj]
  if { {} == $uut } {
    set uut "/$top/uut"
  }
 
  # generate saif file for power estimation
  set saif [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.SAIF] $fs_obj]
  if { !$b_log_all_signals } {
    if { {} != $saif } {
      set rec ""
      if { $::tclapp::aldec::common::helpers::properties(mode) != {behavioral} } {
        set rec "-rec"
      }
      puts $fh "log $rec ${uut}/*"
    }
  }

  puts $fh "if { !\[batch_mode\] } {"
  puts $fh "\twave *"
  puts -nonewline $fh "}" 
  if { !$b_log_all_signals } {
    puts $fh " else {"
    puts $fh "\tlog *"
    puts $fh "}"
  }

  puts $fh "\n"

  usf_aldec_write_run_string_to_file $fh

  set tcl_post_hook [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.TCL.POST] $fs_obj]
  ::tclapp::aldec::common::helpers::usf_aldec_get_file_path_from_project tcl_post_hook
  if { [file isfile $tcl_post_hook] && ![::tclapp::aldec::common::helpers::usf_aldec_is_file_disabled $tcl_post_hook] } {
    puts $fh "\nsource \{$tcl_post_hook\}\n"
  } elseif { $tcl_post_hook != "" } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-94 WARNING "File '$tcl_post_hook' not found or disabled.\n"
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
    if { $::tclapp::aldec::common::helpers::properties(mode) != {behavioral} } {
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

  puts $fh "if \[batch_mode\] {"
  puts $fh "\tendsim"
  puts $fh "\t[usf_aldec_getQuitCmd]"
  puts $fh "}"

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
  set mode_type   $::tclapp::aldec::common::helpers::properties(mode)
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

proc usf_aldec_writeWindowsExecutableCmdLine { _out _batch _doFile _logFile } {
	if { [ get_property target_simulator [ current_project ] ] == "ActiveHDL" } {
		if { $_batch != "" } {
			puts $_out "call \"%bin_path%/VSimSA\" -l \"$_logFile\" -do \"do -tcl $_doFile\""	
		} else {
			puts $_out "call \"%bin_path%/avhdl\" -do \"do -tcl \{$_doFile\}\""
			puts $_out "set error=%errorlevel%"

			set designName [ current_project ]
			set targetDirectory $::tclapp::aldec::common::helpers::properties(launch_directory)
			set logFile [ file nativename "${targetDirectory}/${designName}/log/console.log" ]
			puts $_out "copy /Y \"$logFile\" \"$_logFile\""

			puts $_out "set errorlevel=%error%"
		}
	} else {

		if { $_batch != "" } {
			puts $_out "call \"%bin_path%/../runvsimsa\" -l \"$_logFile\" -do \"do \{$_doFile\}\""
		} else {
			puts $_out "call \"%bin_path%/../rungui\" -l \"$_logFile\" -do \"do \{$_doFile\}\""
		}
	}
}

proc usf_aldec_write_driver_shell_script { do_filename step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set batch_mode_enabled $::tclapp::aldec::common::helpers::properties(batch_mode_enabled)
  set only_generate_scripts $::tclapp::aldec::common::helpers::properties(only_generate_scripts)

  set scriptFileName $step;append scriptFileName [::tclapp::aldec::common::helpers::usf_get_script_extn]
  set dir $::tclapp::aldec::common::helpers::properties(launch_directory)
  set scriptFile [::tclapp::aldec::common::helpers::usf_file_normalize [file join $dir $scriptFileName]]
  set scriptFileHandle 0
  if {[catch {open $scriptFile w} scriptFileHandle]} {
    send_msg_id USF-[usf_aldec_getSimulatorName]-95 ERROR "Failed to open file to write ($scriptFile)\n"
    return 1
  }

  set batch_sw {-c}
  if { ({simulate} == $step) && (!$batch_mode_enabled) && (!$only_generate_scripts) } {
    set batch_sw {}
  }
  
  set log_filename "${step}.log"
  if {$::tcl_platform(platform) == "unix"} {
    puts $scriptFileHandle "#!/bin/sh -f"
    puts $scriptFileHandle "bin_path=\"$::tclapp::aldec::common::helpers::properties(s_tool_bin_path)\""
   
    if { [ ::tclapp::aldec::common::helpers::isSystemCEnabled ] } {
      if { $::tclapp::aldec::common::helpers::properties(b_contain_systemc_sources) } {
        if { ({elaborate} == $step) || ({simulate} == $step) || ({compile} == $step)} {
          set shared_ip_libs [list]

     #     variable a_shared_library_path_coln
          foreach {key value} [array get ::tclapp::aldec::common::helpers::a_shared_library_path_coln] {
            set sc_lib   $key
            set lib_path $value
            set lib_dir "$lib_path"
			
            lappend shared_ip_libs $lib_dir
          }
 
		  set libraryLocation [ ::tclapp::aldec::common::helpers::getCompiledLibraryLocation ]
 
          set ip_objs [get_ips -all -quiet]
          foreach shared_ip_lib [::tclapp::aldec::common::helpers::usf_get_shared_ip_libraries $libraryLocation] { 
            foreach ip_obj $ip_objs {
              set ipdef [get_property -quiet IPDEF $ip_obj]
              set ip_name [lindex [split $ipdef ":"] 2]
              if { [string first $ip_name $shared_ip_lib] != -1} {
                set lib_dir "$libraryLocation/$shared_ip_lib"
                lappend shared_ip_libs $lib_dir
              }
            }
          }
		  
          if { [llength $shared_ip_libs] > 0 } {
            set shared_ip_libs_env_path [join $shared_ip_libs ":"]
            puts $scriptFileHandle "export LD_LIBRARY_PATH=$shared_ip_libs_env_path:\$LD_LIBRARY_PATH"
          }
        }
      }
    }

   ::tclapp::aldec::common::helpers::usf_write_shell_step_fn $scriptFileHandle
    if { $batch_sw != "" } {
      puts $scriptFileHandle "ExecStep \$bin_path/../runvsimsa -l $log_filename -do \"do \{$do_filename\}\""
    } else {
      puts $scriptFileHandle "ExecStep \$bin_path/../rungui -l $log_filename -do \"do \{$do_filename\}\""
    }
  } else {
    puts $scriptFileHandle "@echo off"

    if { $step == "simulate" } {
        set simulator_lib [::tclapp::aldec::common::helpers::usf_get_simulator_lib_for_bfm]
        if { {} != $simulator_lib } {		
            puts $scriptFileHandle "set PATH=[file dirname $simulator_lib];%PATH%"
        }
    }

    puts $scriptFileHandle "set bin_path=$::tclapp::aldec::common::helpers::properties(s_tool_bin_path)"
    usf_aldec_writeWindowsExecutableCmdLine $scriptFileHandle $batch_sw $do_filename $log_filename
    puts $scriptFileHandle "exit %errorlevel%"
  }
  close $scriptFileHandle
}

proc usf_aldec_add_quit_on_error { fh step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set batch_mode_enabled $::tclapp::aldec::common::helpers::properties(batch_mode_enabled)
  set only_generate_scripts $::tclapp::aldec::common::helpers::properties(only_generate_scripts)
  
  switch -- [get_property target_simulator [current_project]] {
    Riviera { set noQuitOnError [get_param "simulator.rivieraNoQuitOnError"] }
    ActiveHDL { set noQuitOnError [get_param "simulator.activehdlNoQuitOnError"] }
  }  

  if { ({compile} == $step) || ({elaborate} == $step) } {
    usf_aldec_writeOnBreakOnErrorCommands $fh
  } elseif { ({simulate} == $step) } {
    if { !$noQuitOnError || $batch_mode_enabled || $only_generate_scripts } {
      usf_aldec_writeOnBreakOnErrorCommands $fh
    } 
  }
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
    return $::tclapp::aldec::common::helpers::properties(launch_directory)/glbl.v
  } else {
    return glbl.v
  }
}

proc usf_aldec_writeOnBreakOnErrorCommands { fileHandle } {
  ### IMPORTANT - if transcript is ON it will cause to dump onerror to log, wchich will cause error in vivado
  puts $fileHandle "transcript off"
  puts $fileHandle "onbreak \{[usf_aldec_getQuitCmd]\}"
  puts $fileHandle "onerror \{[usf_aldec_getQuitCmd]\}\n"
  puts $fileHandle "transcript on"
}

}

}
