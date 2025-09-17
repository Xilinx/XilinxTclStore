######################################################################
#
# sim.tcl
#
# based on XilinxTclStore\tclapp\xilinx\modelsim\sim.tcl
#
######################################################################

package require Vivado 1.2014.1

package require ::tclapp::aldec::common::helpers 1.42

package provide ::tclapp::aldec::common::sim 1.42

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
    
  if { [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.record_AXI_MM] [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]] == 1 } {
    set protoinst_files [::tclapp::aldec::common::helpers::getProtoinstFiles $::tclapp::aldec::common::helpers::properties(dynamic_repo_dir)]

    if { [llength $protoinst_files] > 0 } {
      foreach protoinst_f $protoinst_files {
        [catch {::tclapp::aldec::common::helpers::createAxiBusMonitor $protoinst_f
	        send_msg_id USF-${simulatorName}-83 INFO "AXI bus monitor generated succesfully."	} error_msg]        
        }
      }
  }
  usf_aldec_write_compile_script

  if { !$onlyGenerateScripts } {
    set proc_name [lindex [split [info level 0] " "] 0]
    set step [lindex [split $proc_name {:}] end]
    ::tclapp::aldec::common::helpers::usf_launch_script $step
  }

  	if { [ ::tclapp::aldec::common::helpers::isGenerateLaibraryMode ] == 1 && [ ::tclapp::aldec::common::helpers::isGuiMode ] == 1 } {
		createLibraryCfg
	}
}

proc elaborate { args } {
  # Summary: run the elaborate step for elaborating the compiled design
  # Argument Usage:
  # args: command line args passed from launch_simulation tcl task
  # Return Value:
  # none
  
  # write elaborate.sh/.bat
  set scriptFileName "elaborate"
  append scriptFileName [::tclapp::aldec::common::helpers::usf_get_script_extn]

  set dir $::tclapp::aldec::common::helpers::properties(launch_directory)
  set scriptFile [::tclapp::aldec::common::helpers::usf_file_normalize [file join $dir $scriptFileName]]
  
  set scriptFileHandle 0
  if {[catch {open $scriptFile w} scriptFileHandle]} {
    send_msg_id USF-[usf_aldec_getSimulatorName]-95 ERROR "Failed to open file to write ($scriptFile)\n"
    return 1
  }

  aldecHeader $scriptFileHandle $scriptFileName "elaborating"
  
  close $scriptFileHandle
  
  ::tclapp::aldec::common::helpers::usf_make_file_executable $scriptFile
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
  ::tclapp::aldec::common::helpers::usf_aldec_set_gcc_path

  # set the simulation flow
  ::tclapp::aldec::common::helpers::usf_set_simulation_flow

  # set default object
  if { [::tclapp::aldec::common::helpers::usf_set_sim_tcl_obj] } {
    return 1
  }

  # enable systemC non-precompile flow if global pre-compiled static IP flow is disabled
  if { !$::tclapp::aldec::common::helpers::properties(b_use_static_lib) } {
    set ::tclapp::aldec::common::helpers::properties(b_compile_simmodels) 1
  }

  if { $::tclapp::aldec::common::helpers::properties(b_compile_simmodels) } {
    set ::tclapp::aldec::common::helpers::properties(s_simlib_dir) \
    "$::tclapp::aldec::common::helpers::properties(launch_directory)/simlibs"

    if { ![ file exists $::tclapp::aldec::common::helpers::properties(s_simlib_dir) ] } {
      if { [catch { file mkdir $::tclapp::aldec::common::helpers::properties(s_simlib_dir) } error_msg] } {
        send_msg_id USF-[usf_aldec_getSimulatorName]-013 ERROR \
        "Failed to create the directory ($::tclapp::aldec::common::helpers::properties(s_simlib_dir)): $error_msg\n"
        return 1
      }
    }
  }

  # write functional/timing netlist for post-* simulation
  ::tclapp::aldec::common::helpers::usf_write_design_netlist

  # prepare IP's for simulation
  # ::tclapp::aldec::common::helpers::usf_prepare_ip_for_simulation

  # fetch the compile order for the specified object
  ::tclapp::aldec::common::helpers::usf_xport_data_files

  set launchDirectory $::tclapp::aldec::common::helpers::properties(launch_directory)
  ::tclapp::aldec::common::helpers::findSystemVerilogPackageLibraries $launchDirectory

  ::tclapp::aldec::common::helpers::cacheAllDesign
  ::tclapp::aldec::common::helpers::findCompiledLibraries 

  # extract simulation model library info
  ::tclapp::aldec::common::helpers::usf_fetch_lib_info \
    [ get_property target_simulator [ current_project ] ] \
    [ ::tclapp::aldec::common::helpers::getCompiledLibraryLocation ] \
    $::tclapp::aldec::common::helpers::properties(b_int_sm_lib_ref_debug)

  # find shared library paths from all IPs
  if { [ ::tclapp::aldec::common::helpers::isSystemCEnabled ] } {
    if { [::tclapp::aldec::common::helpers::usf_contains_C_files] } {
      ::tclapp::aldec::common::helpers::usf_find_shared_lib_paths \
        [ string tolower [ get_property target_simulator [ current_project ] ] ]\
        [ ::tclapp::aldec::common::helpers::getCompiledLibraryLocation ] \
        $::tclapp::aldec::common::helpers::properties(custom_sm_lib_dir) \
        $::tclapp::aldec::common::helpers::properties(b_int_sm_lib_ref_debug) \
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
  # [-gui]: Invoke simulator in GUI mode for scripts only
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
	  "-gui"            { set ::tclapp::aldec::common::helpers::properties(b_gui) 1 }
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
	  "-int_en_vitis_hw_emu_mode" { set ::tclapp::aldec::common::helpers::properties(b_int_en_vitis_hw_emu_mode) 1				}
      "-int_export_source_files"  { set ::tclapp::aldec::common::helpers::properties(b_int_export_source_files)  1                 }
      "-int_gcc_bin_path"         { incr i;set ::tclapp::aldec::common::helpers::properties(s_gcc_bin_path)      [lindex $args $i] }
      "-int_compile_glbl"         { set ::tclapp::aldec::common::helpers::properties(b_int_compile_glbl)         1                 }
      "-int_sim_version"          { incr i;set ::tclapp::aldec::common::helpers::properties(s_sim_version)       [lindex $args $i] }
	  
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

  send_msg_id USF-[usf_aldec_getSimulatorName]-87 INFO "Creating automatic compilation macro...\n"

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
	
	send_msg_id USF-[usf_aldec_getSimulatorName]-97 INFO "Creating automatic simulation macro...\n"
	
    usf_aldec_create_do_file_for_simulation $do_file
  }

  # write elaborate.sh/.bat
  usf_aldec_write_driver_shell_script $do_filename "simulate"
}

proc mapLibraryCfg { _variable { _simulation 0 } } {

	set simset [ get_filesets $::tclapp::aldec::common::helpers::properties(simset) ]
	set usePrecompiledIp $::tclapp::aldec::common::helpers::properties(b_use_static_lib)
	set basicLlibraries [ get_property [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName compile.basic_libraries ] $simset ]

	if { $usePrecompiledIp != 1 && $basicLlibraries != 1 } {
		return
	}

	set librariesLocation [ ::tclapp::aldec::common::helpers::getCompiledLibraryLocation ]
	if { $librariesLocation == "" } {
		send_msg_id USF-[usf_aldec_getSimulatorName]-100 WARNING "The location of compiled libraries is not set."
		return
	}

	set libraryCfgFile [ file join $librariesLocation library.cfg ]
	if { ![ file isfile $libraryCfgFile ] } {
		send_msg_id USF-[usf_aldec_getSimulatorName]-101 WARNING "Cannot find the \"library.cfg\" file in the compiled library location ('$librariesLocation')."
		return
	}

	set topLibrary [ ::tclapp::aldec::common::helpers::usf_get_top_library ]
	set libraryCfg [ open $libraryCfgFile r ]
	set xpmLibrary [ ::tclapp::aldec::common::helpers::getXpmLibraries ]

	set librariesPattern [ list ]
	if { $_simulation == 0 } {
		set simulationFlow $::tclapp::aldec::common::helpers::properties(s_simulation_flow)
		set designFiles $::tclapp::aldec::common::helpers::properties(designFiles)

		set netlistMode [ get_property "NL.MODE" $simset ]
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

		set compileUnifast [ get_property [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName ELABORATE.UNIFAST ] $simset ]
		if { ([ ::tclapp::aldec::common::helpers::usf_contains_vhdl $designFiles ]) && ({behav_sim} == $simulationFlow) } {
			if { [ get_param "simulation.addUnifastLibraryForVhdl" ] } {
				if { $compileUnifast } {
					lappend librariesPattern "unifast"
				} elseif { [ get_property "unifast" $simset ] } {
					lappend librariesPattern "unifast"
				}
			}
		}

		if { ([::tclapp::aldec::common::helpers::usf_contains_verilog $designFiles]) && ({behav_sim} == $simulationFlow) } {
			if { $compileUnifast } {
				lappend librariesPattern "unifast_ver"
			} elseif { [ get_property "unifast" $simset ] } {
				lappend librariesPattern "unifast_ver"
			}

			lappend librariesPattern "unisims_ver"
			lappend librariesPattern "unimacro_ver"
		}

		lappend librariesPattern "secureip"
		lappend librariesPattern "unisim"
		lappend librariesPattern "unimacro"
		lappend librariesPattern "unifast"
	}

	lappend librariesPattern "xilinx_vip"

	if { [ llength $xpmLibrary ] > 0 } {
		lappend librariesPattern "xpm"
	}

	if { $usePrecompiledIp } {
		puts $_variable "vmap -link \{$librariesLocation\}"
	} else {
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

				set isAdded 0
				foreach library $librariesPattern {
					if { $mapName == $library } {

						if { $usePrecompiledIp == 1 } {
							puts $_variable "vmap $mapName \{$mapPath\}"
						} elseif { $mapName != "xilinx_vip" && $mapName != "xpm" } {
							puts $_variable "vmap $mapName \{$mapPath\}"
							send_msg_id USF-[usf_aldec_getSimulatorName]-102 INFO "The global \"$mapName\" library has been replaced by the local library."
						}

						set isAdded 1
						break
					}
				}

				if { $usePrecompiledIp == 1 && !$isAdded && [ ::tclapp::aldec::common::helpers::isDesignLibrary $mapName ] == 1 } {
					puts $_variable "vmap $mapName \{$mapPath\}"
				}
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

  if { $::tclapp::aldec::common::helpers::properties(b_compile_simmodels) } {
    set ::tclapp::aldec::common::helpers::properties(l_simmodel_compile_order) [xcs_get_simmodel_compile_order]

    foreach lib $::tclapp::aldec::common::helpers::properties(l_simmodel_compile_order) {
	  puts $fh "vlib [getLibraryDir]/$lib"
    }
  }

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

    if { $::tclapp::aldec::common::helpers::properties(b_compile_simmodels) } {
      foreach lib $::tclapp::aldec::common::helpers::properties(l_simmodel_compile_order) {
        if { $use_absolute_paths } {
          set dir $::tclapp::aldec::common::helpers::properties(launch_directory)
          puts $fh "vmap $lib $dir/$lib"
        } else {
          puts $fh "vmap $lib [getLibraryDir]/$lib"
        }
      }
    }

	if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
      # no op
    } else {
	  if { $use_absolute_paths } {
		set dir $::tclapp::aldec::common::helpers::properties(launch_directory)
		puts $fh "null \[set origin_dir \"$dir\"\]"
	  } else {
		puts $fh "null \[set origin_dir \".\"\]"
	  }
    }
	
  set vlog_cmd_str [ ::tclapp::aldec::common::helpers::getVlogOptions ]
  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    # no op
  } else {
    puts $fh "null \[set vlog_opts \{$vlog_cmd_str\}\]"
  }

  set vcom_cmd_str [ ::tclapp::aldec::common::helpers::getVcomOptions ]
  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    # no op
  } else {
    puts $fh "null \[set vcom_opts \{$vcom_cmd_str\}\]"
  }

  puts $fh ""

  if { $::tclapp::aldec::common::helpers::properties(b_compile_simmodels) } {
    usf_compile_simmodel_sources $fh
  }

  set prev_lib  {}
  set prev_file_type {}
  set b_group_files [get_param "project.assembleFilesByLibraryForUnifiedSim"]
  set useAddsc 0
  set output [ ::tclapp::aldec::common::helpers::getSystemCLibrary ]
	
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

		set cmd_str [ convertToUnifiedSimulation $cmd_str $vlog_cmd_str $vcom_cmd_str ]
		set src_file [ convertToUnifiedSimulation $src_file $vlog_cmd_str $vcom_cmd_str ]

		set commandLine ""
		set newLine 0

		foreach item [ split $cmd_str " " ] {

			if { $item == "" } {
				continue
			}

			if { $commandLine == "" && $item != "ccomp" } {
				set commandLine $cmd_str
				break
			}

			if { $commandLine != "" } {
				if { [ string index $item 0 ] == "-" || $newLine || [ regexp ".*xilinx_versal.o$" $item ] || [ regexp ".*xilinx_zynqmp.o$" $item ] } {
					append commandLine " \\\n\t"
					set newLine 0
				} else {
					append commandLine " "
				}
			}

			if { $output == $item } {
				set newLine 1
			}

			append commandLine "$item"
		}

		if { $b_group_files } {
			if { ( $file_type != $prev_file_type ) || ( $lib != $prev_lib ) } {
				set prev_file_type $file_type
				set prev_lib $lib
				puts $fh ""
				puts $fh "$commandLine \\"
			}
			puts $fh "\t$src_file \\"
			
		} else {
			puts $fh "$commandLine $src_file"
		}

		if { $file_type == "SystemC" } {
			set useAddsc 1
		}
	}

	if { [ ::tclapp::aldec::common::helpers::isSystemCEnabled ] && $useAddsc == 1 } {
		puts $fh "\naddsc -work $defaultLibraryName [ ::tclapp::aldec::common::helpers::getSystemCLibrary ]"
	}
  if { [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.record_AXI_MM] $fs_obj] == 1 } {
	  compile_transacrion_recorder_files $fh
  }
  if { $b_group_files } {
    # break multi-line command
    puts $fh ""
  }

  # compile glbl file
  set sim_flow $::tclapp::aldec::common::helpers::properties(s_simulation_flow)
  set b_load_glbl [ get_property [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName COMPILE.LOAD_GLBL ] [ get_filesets $::tclapp::aldec::common::helpers::properties(simset) ] ]
  set simulator [ string tolower [ get_property target_simulator [ current_project ] ] ]
  set design_files $::tclapp::aldec::common::helpers::properties(designFiles)

  set glblWasAdded 0
  if { {behav_sim} == $sim_flow } {
    if { [ ::tclapp::aldec::common::helpers::usf_compile_glbl_file $simulator $b_load_glbl $design_files ] || $::tclapp::aldec::common::helpers::properties(b_force_compile_glbl) } {
      if { $::tclapp::aldec::common::helpers::properties(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        set glblWasAdded 1
        ::tclapp::aldec::common::helpers::usf_copy_glbl_file
        set top_lib [::tclapp::aldec::common::helpers::usf_get_top_library]
        set file_str "-work $top_lib \"[usf_aldec_getGlblPath]\""
        puts $fh "\n# compile glbl module\nvlog $file_str"
      }
    }
  } else {
    # for post* compile glbl if design contain verilog and netlist is vhdl
    set targetLang  [get_property "TARGET_LANGUAGE" [current_project]]

    if { \
         ([::tclapp::aldec::common::helpers::usf_contains_verilog $design_files ] && ({VHDL} == $targetLang)) \
      || ($::tclapp::aldec::common::helpers::properties(b_int_compile_glbl)) \
      || ($::tclapp::aldec::common::helpers::properties(b_force_compile_glbl)) \
    } {
      if { $::tclapp::aldec::common::helpers::properties(b_force_no_compile_glbl) } {
        # skip glbl compile if force no compile set
      } else {
        if { ({timing} == $::tclapp::aldec::common::helpers::properties(s_type)) } {
          # This is not supported, netlist will be verilog always
        } else {
          set glblWasAdded 1
          ::tclapp::aldec::common::helpers::usf_copy_glbl_file
          set top_lib [::tclapp::aldec::common::helpers::usf_get_top_library]
          set file_str "-work $top_lib \"[usf_aldec_getGlblPath]\""
          puts $fh "\n# compile glbl module\nvlog $file_str"
        }
      }
    }
  }

  if { $::tclapp::aldec::common::helpers::properties(b_force_no_compile_glbl) } {
  
  } elseif { $glblWasAdded == 0 && $b_load_glbl } {
    ::tclapp::aldec::common::helpers::usf_copy_glbl_file
    set top_lib [::tclapp::aldec::common::helpers::usf_get_top_library]
    set file_str "-work $top_lib \"[usf_aldec_getGlblPath]\""
    puts $fh "\n# compile glbl module\nvlog $file_str"
  }

  puts $fh "\n[usf_aldec_getQuitCmd]"

  close $fh
}

proc usf_compile_simmodel_sources { fh } {

  set platform "lin"
  if {$::tcl_platform(platform) == "windows"} {
    set platform "win"
  }

  set b_dbg 0
  if { $::tclapp::aldec::common::helpers::properties(s_int_debug_mode) == "1" } {
    set b_dbg 1
  }

  set simulator [ string tolower [ get_property target_simulator [ current_project ] ] ]
  set data_dir [ rdi::get_data_dir -quiet -datafile "systemc/simlibs" ]
  set cpt_dir  [ ::tclapp::aldec::common::helpers::usf_get_simmodel_dir $simulator "cpt" ]
  set boostPath [ ::tclapp::aldec::common::helpers::usf_get_boost_library_path ]

  # is pure-rtl sources for system simulation (selected_sim_model = rtl), don't need to compile the systemC/CPP/C sim-models
  if { [ llength $::tclapp::aldec::common::helpers::properties(l_simmodel_compile_order) ] == 0 } {
    if { [file exists $::tclapp::aldec::common::helpers::properties(s_simlib_dir)] } {
      # delete <run-dir>/simlibs dir (not required)
      [catch {file delete -force $::tclapp::aldec::common::helpers::properties(s_simlib_dir)} error_msg]
    }
    return
  }

  # find simmodel info from dat file and update do file
  foreach lib_name $::tclapp::aldec::common::helpers::properties(l_simmodel_compile_order) {

    set lib_path [xcs_find_lib_path_for_simmodel $lib_name]
    set fh_dat 0
    set dat_file "$lib_path/.cxl.sim_info.dat"

    if {[catch {open $dat_file r} fh_dat]} {
      send_msg_id USF-[usf_aldec_getSimulatorName]-77 WARNING "Failed to open file to read ($dat_file)\n"
      continue
    }

    set data [split [read $fh_dat] "\n"]
    close $fh_dat

    # is current platform supported?
    set simulator_platform {}
    set simmodel_name      {}
    set library_name       {}
    set b_process          0

    foreach line $data {
      set line [ string trim $line ]
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

    # not supported, work on next simmodel
    if { !$b_process } { continue }

    #send_msg_id USF-[usf_aldec_getSimulatorName]-107 STATUS "Generating compilation commands for '$lib_name'\n"

    # create local lib dir
    set simlib_dir "$::tclapp::aldec::common::helpers::properties(s_simlib_dir)/$lib_name"
    if { ![file exists $simlib_dir] } {
      if { [catch {file mkdir $simlib_dir} error_msg] } {
        send_msg_id USF-[usf_aldec_getSimulatorName]-013 ERROR "Failed to create the directory ($simlib_dir): $error_msg\n"
        return 1
      }
    }

    # copy simmodel sources locally
    if { $::tclapp::aldec::common::helpers::properties(b_int_export_source_files) } {
      if { {} == $simmodel_name } { send_msg_id USF-[usf_aldec_getSimulatorName]-107 WARNING "Empty tag '$simmodel_name'!\n" }
      if { {} == $library_name  } { send_msg_id USF-[usf_aldec_getSimulatorName]-107 WARNING "Empty tag '$library_name'!\n"  }

      set src_sim_model_dir "$data_dir/systemc/simlibs/$simmodel_name/$library_name/src"
      set dst_dir "$::tclapp::aldec::common::helpers::properties(launch_directory)/simlibs/$library_name"
      if { [file exists $src_sim_model_dir] } {
        [catch {file delete -force $dst_dir/src} error_msg]
        if { [catch {file copy -force $src_sim_model_dir $dst_dir} error_msg] } {
          [catch {send_msg_id USF-[usf_aldec_getSimulatorName]-108 ERROR "Failed to copy file '$src_sim_model_dir' to '$dst_dir': $error_msg\n"} err]
        } else {
          #puts "copied '$src_sim_model_dir' to run dir:'$a_sim_vars(s_launch_dir)/simlibs'\n"
        }
      } else {
        [catch {send_msg_id USF-[usf_aldec_getSimulatorName]-108 ERROR "File '$src_sim_model_dir' does not exist\n"} err]
      }
    }

    # copy include dir
    set simlib_incl_dir "$lib_path/include"
    set target_dir      "$::tclapp::aldec::common::helpers::properties(s_simlib_dir)/$lib_name"
    set target_incl_dir "$target_dir/include"

    if { ![file exists $target_incl_dir] } {
      if { [catch {file copy -force $simlib_incl_dir $target_dir} error_msg] } {
        [catch {send_msg_id USF-[usf_aldec_getSimulatorName]-010 ERROR "Failed to copy file '$simlib_incl_dir' to '$target_dir': $error_msg\n"} err]
      }
    }

    # simmodel file_info.dat data
    set library_type            {}
    set output_format           {}
    set gplus_compile_flags     [list]
    set gplus_compile_opt_flags [list]
    set gplus_compile_dbg_flags [list]
    set gcc_compile_flags       [list]
    set gcc_compile_opt_flags   [list]
    set gcc_compile_dbg_flags   [list]
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
    set systemc_compile_option  {}
    set cpp_compile_option      {}
    set c_compile_option        {}
    set shared_lib              {}
    set systemc_incl_dirs       [list]
    set cpp_incl_dirs           [list]
    set osci_incl_dirs          [list]
    set c_incl_dirs             [list]

    set sysc_files              [list]
    set cpp_files               [list]
    set c_files                 [list]

    # process simmodel data from .dat file
    foreach line $data {
      set line [string trim $line]
      if { {} == $line } { continue }
      set line_info [split $line {:}]
      set tag       [lindex $line_info 0]
      set value     [lindex $line_info 1]

      # collect sources
      if { ("<SYSTEMC_SOURCES>" == $tag) || ("<CPP_SOURCES>" == $tag) || ("<C_SOURCES>" == $tag) } {
        set file_path "$data_dir/$value"

        # local file path where sources will be copied for export option
        if { $::tclapp::aldec::common::helpers::properties(b_int_export_source_files) } {
          set dirs [split $value "/"]
          set value [join [lrange $dirs 3 end] "/"]
          set file_path "simlibs/$value"
        }

        if { ("<SYSTEMC_SOURCES>" == $tag) } { lappend sysc_files $file_path }
        if { ("<CPP_SOURCES>"     == $tag) } { lappend cpp_files  $file_path }
        if { ("<C_SOURCES>"       == $tag) } { lappend c_files    $file_path }
      }

      # get simmodel info
      if { "<LIBRARY_TYPE>"               == $tag } { set library_type            $value             }
      if { "<OUTPUT_FORMAT>"              == $tag } { set output_format           $value             }
      if { "<SYSTEMC_INCLUDE_DIRS>"       == $tag } { set systemc_incl_dirs       [split $value {,}] }
      if { "<CPP_INCLUDE_DIRS>"           == $tag } { set cpp_incl_dirs           [split $value {,}] }
      if { "<C_INCLUDE_DIRS>"             == $tag } { set c_incl_dirs             [split $value {,}] }
      if { "<OSCI_INCLUDE_DIRS>"          == $tag } { set osci_incl_dirs          [split $value {,}] }
      if { "<G++_COMPILE_FLAGS>"          == $tag } { set gplus_compile_flags     [split $value {,}] }
      if { "<G++_COMPILE_OPTIMIZE_FLAGS>" == $tag } { set gplus_compile_opt_flags [split $value {,}] }
      if { "<G++_COMPILE_DEBUG_FLAGS>"    == $tag } { set gplus_compile_dbg_flags [split $value {,}] }
      if { "<GCC_COMPILE_FLAGS>"          == $tag } { set gcc_compile_flags       [split $value {,}] }
      if { "<GCC_COMPILE_OPTIMIZE_FLAGS>" == $tag } { set gcc_compile_opt_flags   [split $value {,}] }
      if { "<GCC_COMPILE_DEBUG_FLAGS>"    == $tag } { set gcc_compile_dbg_flags   [split $value {,}] }
      if { "<LDFLAGS>"                    == $tag } { set ldflags                 [split $value {,}] }
      if { "<LDFLAGS_LNX64>"              == $tag } { set ldflags_lin64           [split $value {,}] }
      if { "<LDFLAGS_WIN64>"              == $tag } { set ldflags_win64           [split $value {,}] }
      if { "<G++_LDFLAGS_OPTION>"         == $tag } { set gplus_ldflags_option    $value             }
      if { "<GCC_LDFLAGS_OPTION>"         == $tag } { set gcc_ldflags_option      $value             }
      if { "<LDLIBS>"                     == $tag } { set ldlibs                  [split $value {,}] }
      if { "<LDLIBS_LNX64>"               == $tag } { set ldlibs_lin64            [split $value {,}] }
      if { "<LDLIBS_WIN64>"               == $tag } { set ldlibs_win64            [split $value {,}] }
      if { "<G++_LDLIBS_OPTION>"          == $tag } { set gplus_ldlibs_option     $value             }
      if { "<GCC_LDLIBS_OPTION>"          == $tag } { set gcc_ldlibs_option       $value             }
      if { "<SYSTEMC_DEPENDENT_LIBS>"     == $tag } { set sysc_dep_libs           $value             }
      if { "<CPP_DEPENDENT_LIBS>"         == $tag } { set cpp_dep_libs            $value             }
      if { "<C_DEPENDENT_LIBS>"           == $tag } { set c_dep_libs              $value             }
      if { "<SCCOM_COMPILE_FLAGS>"        == $tag } { set sccom_compile_flags     $value             }
      if { "<MORE_XSC_OPTIONS>"           == $tag } { set more_xsc_options        [split $value {,}] }
      if { "<SIMULATOR_PLATFORM>"         == $tag } { set simulator_platform      $value             }
      if { "<SYSTEMC_COMPILE_OPTION>"     == $tag } { set systemc_compile_option  $value             }
      if { "<CPP_COMPILE_OPTION>"         == $tag } { set cpp_compile_option      $value             }
      if { "<C_COMPILE_OPTION>"           == $tag } { set c_compile_option        $value             }
      if { "<SHARED_LIBRARY>"             == $tag } { set shared_lib              $value             }
    }

    # set obj_dir "$::tclapp::aldec::common::helpers::properties(launch_directory)/questa_lib/$lib_name"
    # if { ![file exists $obj_dir] } {
      # if { [catch {file mkdir $obj_dir} error_msg] } {
        # send_msg_id USF-[usf_aldec_getSimulatorName]-013 ERROR "Failed to create the directory ($obj_dir): $error_msg\n"
        # return 1
      # }
    # }

    # write systemC/CPP/C command line

    if { [llength $sysc_files] > 0 } {

      puts $fh "# compile '$lib_name' model sources"
      set compiler "ccomp"

      # COMPILE (ccomp)

      set args [list]
      # lappend args "-64"
      # lappend args "-cpppath $::tclapp::aldec::common::helpers::properties(s_gcc_bin_path)/g++"

      # <SYSTEMC_COMPILE_OPTION>
      if { {} != $systemc_compile_option } { lappend args $systemc_compile_option }

      # <SCCOM_COMPILE_FLAGS>
      lappend args "$sccom_compile_flags"
  
      # <SYSTEMC_INCLUDE_DIRS> 
      if { [llength $systemc_incl_dirs] > 0 } { 
        foreach incl_dir $systemc_incl_dirs {
          if { [regexp {^\$xv_cpt_lib_path} $incl_dir] } {
            set str_to_replace "xv_cpt_lib_path"
            set str_replace_with "$cpt_dir"
            regsub -all $str_to_replace $incl_dir $str_replace_with incl_dir 
            set incl_dir [string trimleft $incl_dir {\$}]
            set incl_dir "$data_dir/$incl_dir"
          }
          if { [regexp {^\$xv_ext_lib_path} $incl_dir] } {
            set str_to_replace "xv_ext_lib_path"
            set str_replace_with "$::tclapp::aldec::common::helpers::properties(sp_ext_dir)"
            regsub -all $str_to_replace $incl_dir $str_replace_with incl_dir 
            set incl_dir [string trimleft $incl_dir {\$}]
          }

          if { [ regexp -nocase "^/tps/boost.*" $incl_dir ] } {
            lappend args "-I $boostPath"
          } else {
            lappend args "-I $incl_dir"
          }
        }
      }

      # <CPP_COMPILE_OPTION> 
      lappend args $cpp_compile_option

      # <G++_COMPILE_FLAGS>
      foreach opt $gplus_compile_flags { lappend args $opt }

      # <G++_COMPILE_OPTIMIZE_FLAGS>
      foreach opt $gplus_compile_opt_flags { lappend args $opt }

      # config simmodel options
      set cfg_opt "${simulator}.compile.${compiler}.${library_name}"
      set cfg_val ""
      [catch {set cfg_val [get_param $cfg_opt]} err]
      if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
        lappend args "$cfg_val"
      }

      # global simmodel option (if any)
      set cfg_opt "${simulator}.compile.${compiler}.global"
      set cfg_val ""
      [catch {set cfg_val [get_param $cfg_opt]} err]
      if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
        lappend args "$cfg_val"
      }

      set cmd_str [ join $args " " ]

      foreach sysc_file $sysc_files { 
        set file_name [file root [file tail $sysc_file]]
        set obj_file "${file_name}.o"

        puts $fh "$compiler $cmd_str $sysc_file -o [getLibraryDir]/$lib_name/${obj_file}\n"
      }

      # LINK (ccomp)

      set args [list]
      # lappend args "-64"
      # lappend args "-cpppath $::tclapp::aldec::common::helpers::properties(s_gcc_bin_path)/g++"

      # <SYSTEMC_COMPILE_OPTION>
      if { {} != $systemc_compile_option } {
        set compileOption ""

        foreach piece [ split $systemc_compile_option " " ] {
          if { $piece == "-c" } {
            continue
          }

          append compileOption " $piece"
        }

        lappend args $compileOption
      }
      
      lappend args "-shared"
      # lappend args "-lib $lib_name"
 
      # <LDFLAGS>
      if { [llength $ldflags] > 0 } { foreach opt $ldflags { lappend args $opt } }

      if {$::tcl_platform(platform) == "windows"} {
        if { [llength $ldflags_win64] > 0 } { foreach opt $ldflags_win64 { lappend args $opt } }
      } else {
        if { [llength $ldflags_lin64] > 0 } { foreach opt $ldflags_lin64 { lappend args $opt } }
      }
    
      # acd ldflags 
      if { {} != $gplus_ldflags_option } { lappend args $gplus_ldflags_option }
   
      # <LDLIBS>
      if { [llength $ldlibs] > 0 } {
        foreach opt $ldlibs {
          if { [regexp {\$xv_cpt_lib_path} $opt] } {
            set cpt_dir_path "$data_dir/$cpt_dir"
            set str_to_replace {\$xv_cpt_lib_path}
            set str_replace_with "$cpt_dir_path"
            regsub -all $str_to_replace $opt $str_replace_with opt 
          }
          lappend args $opt
        }
      }

      foreach src_file $sysc_files {
        set file_name [file root [file tail $src_file]]
        set obj_file "[getLibraryDir]/$lib_name/${file_name}.o"
        lappend args $obj_file
      }

      set fileName "[getLibraryDir]/$lib_name/lib${lib_name}.so"

      lappend args "-o"
      lappend args "$fileName"

      if {$::tcl_platform(platform) == "windows"} {
        if { [llength $ldlibs_win64] > 0 } { foreach opt $ldlibs_win64 { lappend args $opt } }
      } else {
        if { [llength $ldlibs_lin64] > 0 } { foreach opt $ldlibs_lin64 { lappend args $opt } }
      }
    
      # acd ldlibs
      if { {} != $gplus_ldlibs_option } { lappend args "$gplus_ldlibs_option" }
    
      # lappend args "-work $lib_name"
      set cmd_str [join $args " "]
      puts $fh "$compiler $cmd_str\n"

    } elseif { [llength $cpp_files] > 0 } {
      puts $fh "# compile '$lib_name' model sources"
      set compiler "g++"

      # COMPILE (g++)

      foreach src_file $cpp_files {
        set file_name [file root [file tail $src_file]]
        set obj_file "${file_name}.o"

        # construct g++ compile command line
        set args [list]
        lappend args "-c"

        # <CPP_INCLUDE_DIRS>
        if { [llength $cpp_incl_dirs] > 0 } {
          foreach incl_dir $cpp_incl_dirs {
            if { [regexp {^\$xv_ext_lib_path} $incl_dir] } {
              set str_to_replace "xv_ext_lib_path"
              set str_replace_with "$::tclapp::aldec::common::helpers::properties(sp_ext_dir)"
              regsub -all $str_to_replace $incl_dir $str_replace_with incl_dir 
              set incl_dir [string trimleft $incl_dir {\$}]
            }

            if { [ regexp -nocase "^/tps/boost.*" $incl_dir ] } {
              lappend args "-I $boostPath"
            } else {
              lappend args "-I $incl_dir"
            }
          }
        }

        # <CPP_COMPILE_OPTION>
        lappend args $cpp_compile_option

        # <G++_COMPILE_FLAGS>
        if { [llength $gplus_compile_flags] > 0 } { foreach opt $gplus_compile_flags { lappend args $opt } }

        # <G++_COMPILE_OPTIMIZE_FLAGS>
        if { $b_dbg } {
          if { [llength $gplus_compile_dbg_flags] > 0 } { foreach opt $gplus_compile_dbg_flags { lappend args $opt } }
        } else {
          if { [llength $gplus_compile_opt_flags] > 0 } { foreach opt $gplus_compile_opt_flags { lappend args $opt } }
        }

        # config simmodel options
        set cfg_opt "${simulator}.compile.${compiler}.${library_name}"
        set cfg_val ""
        [catch {set cfg_val [get_param $cfg_opt]} err]
        if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
          lappend args "$cfg_val"
        }
      
        # global simmodel option (if any)
        set cfg_opt "${simulator}.compile.${compiler}.global"
        set cfg_val ""
        [catch {set cfg_val [get_param $cfg_opt]} err]
        if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
          lappend args "$cfg_val"
        }

        lappend args $src_file
        lappend args "-o"
        lappend args "[getLibraryDir]/$lib_name/${obj_file}"

        set cmd_str [join $args " "]
        puts $fh "$::tclapp::aldec::common::helpers::properties(s_gcc_bin_path)/$compiler $cmd_str\n"
      }

      # LINK (g++)

      set args [list]
      foreach src_file $cpp_files {
        set file_name [file root [file tail $src_file]]
        set obj_file "[getLibraryDir]/$lib_name/${file_name}.o"
        lappend args $obj_file
      }

      lappend args "-shared"
      lappend args "-o"
      lappend args "[getLibraryDir]/$lib_name/lib${lib_name}.so"
      
      set cmd_str [join $args " "]
      puts $fh "$::tclapp::aldec::common::helpers::properties(s_gcc_bin_path)/$compiler $cmd_str\n"

    } elseif { [llength $c_files] > 0 } {
      puts $fh "# compile '$lib_name' model sources"
      set compiler "gcc"

      # COMPILE (gcc)

      foreach src_file $c_files {
        set file_name [file root [file tail $src_file]]
        set obj_file "${file_name}.o"

        # construct gcc compile command line
        set args [list]
        lappend args "-c"

        # <C_INCLUDE_DIRS>
        if { [llength $c_incl_dirs] > 0 } { 
          foreach incl_dir $c_incl_dirs {
            if { [ regexp -nocase "^/tps/boost.*" $incl_dir ] } {
              lappend args "-I $boostPath"
            } else {
              lappend args "-I $incl_dir"
            }
          }
        }

        # <C_COMPILE_OPTION>
        lappend args $c_compile_option

        lappend args "-fPIC"

        # <GCC_COMPILE_FLAGS>
        if { [llength $gcc_compile_flags] > 0 } { foreach opt $gcc_compile_flags { lappend args $opt } }

        # <GCC_COMPILE_OPTIMIZE_FLAGS>
        if { $b_dbg } {
          if { [llength $gcc_compile_dbg_flags] > 0 } { foreach opt $gcc_compile_dbg_flags { lappend args $opt } }
        } else {
          if { [llength $gcc_compile_opt_flags] > 0 } { foreach opt $gcc_compile_opt_flags { lappend args $opt } }
        }

        # config simmodel options
        set cfg_opt "${simulator}.compile.${compiler}.${library_name}"
        set cfg_val ""
        [catch {set cfg_val [get_param $cfg_opt]} err]
        if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
          lappend args "$cfg_val"
        }
      
        # global simmodel option (if any)
        set cfg_opt "${simulator}.compile.${compiler}.global"
        set cfg_val ""
        [catch {set cfg_val [get_param $cfg_opt]} err]
        if { ({<empty>} != $cfg_val) && ({} != $cfg_val) } {
          lappend args "$cfg_val"
        }

        lappend args $src_file
        lappend args "-o"
        lappend args "[getLibraryDir]/$lib_name/${obj_file}"

        set cmd_str [join $args " "]
        puts $fh "$::tclapp::aldec::common::helpers::properties(s_gcc_bin_path)/$compiler $cmd_str\n"
      }

      # LINK (gcc)

      set args [list]
      foreach src_file $c_files { 
        set file_name [file root [file tail $src_file]]
        set obj_file "[getLibraryDir]/$lib_name/${file_name}.o"
        lappend args $obj_file
      }

      lappend args "-shared"
      lappend args "-o"
      lappend args "[getLibraryDir]/$lib_name/lib${lib_name}.so"
      
      set cmd_str [join $args " "]
      puts $fh "$::tclapp::aldec::common::helpers::properties(s_gcc_bin_path)/$compiler $cmd_str\n"

    }
  }
}
proc compile_transacrion_recorder_files { _fh } {
			
	set defaultLibraryName [ get_property "DEFAULT_LIB" [ current_project ] ]
  set install_path $::tclapp::aldec::common::helpers::properties(s_install_path)
	if { $install_path == "" } {
    set install_path [get_param "simulator.rivieraInstallPath"] 
  }

  set _sourcesPath [::tclapp::aldec::common::helpers::usf_file_normalize [file join $install_path  .. "vlib/aldec_axi_bfm/hdl"]]
	
  if { ![file exist $_sourcesPath/TransactionRecorder.sv] } {
    [catch {send_msg_id USF-[usf_aldec_getSimulatorName]-100 ERROR "Cannot find $_sourcesPath/TransactionRecorder.sv.\n"} error_msg]        
  }
  
  if { [llength $::tclapp::aldec::common::helpers::protoinstFilesList] != 0 } { 
	
		puts $_fh "\nvlog -work $defaultLibraryName \"\+incdir+axi_bus_monitor\" \\"
		puts $_fh "\t\"$_sourcesPath/TransactionRecorder.sv\" \\"

		foreach protoinstFile $::tclapp::aldec::common::helpers::protoinstFilesList { 
		set protoinstFilePath "$::tclapp::aldec::common::helpers::properties(launch_directory)/axi_bus_monitor/$protoinstFile"
		if {[file exists $protoinstFilePath]} {
			puts $_fh "\t\"./axi_bus_monitor/$protoinstFile\" \\"
			}
	 }
	}
}
proc getLibraryDir { } {
  set libraryDir [ string tolower [ get_property target_simulator [ current_project ] ] ]
  append libraryDir "_lib"
  
  return $libraryDir
}

proc xcs_find_lib_path_for_simmodel { simmodel } {

  set lib_path {}
  foreach {key value} [array get ::tclapp::aldec::common::helpers::a_shared_library_path_coln] {
    set shared_lib_name $key
    set lib_name [file root $shared_lib_name]
    set lib_name [string trimleft $lib_name {lib}]
    if { $simmodel == $lib_name } {
      set lib_path $value
      return $lib_path
    }
  }
}

proc xcs_get_simmodel_compile_order { } { 
  set sm_order [list]

  # get simmodel list referenced in the design
  set lib_names [list]
  foreach {key value} [array get ::tclapp::aldec::common::helpers::a_shared_library_path_coln] {
    set shared_lib_name $key
    set lib_name [file root $shared_lib_name]
    set lib_name [string trimleft $lib_name {lib}]
    lappend lib_names $lib_name
  }

  # find compile order and construct order for the simmodels referenced in the design
  set compile_order_file [::tclapp::aldec::common::helpers::usf_get_path_from_data "systemc/simlibs/compile_order.dat"]
  set fh 0
  if { [catch {open $compile_order_file r} fh] } {
    send_msg_id SIM-[usf_aldec_getSimulatorName]-068 WARNING "Failed to open file for read! '$compile_order_file'\n"
    return $sm_order
  }
  set data [split [read $fh] "\n"]
  close $fh
  foreach line $data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    if { [regexp {^#} $line] } { continue; }
    set lib_name $line
    if { {xtlm} == $lib_name } {
      set index [lsearch -exact $lib_names $lib_name]
    } else {
      set index [lsearch -regexp $lib_names $lib_name]
    }
    if { {-1} != $index } {
      set sm_lib [lindex $lib_names $index]
      lappend sm_order $sm_lib
    }
  }
  return $sm_order
} 

proc convertToUnifiedSimulation { _command _vlogOptions _vcomOptions } {

	if { [ get_param "project.writeNativeScriptForUnifiedSimulation" ] } {

		regsub -all -- {{\*}\$vlog_opts} $_command "$_vlogOptions" result
		regsub -all -- {{\*}\$vcom_opts} $result "$_vcomOptions" result

		return $result		
	} else {
		return $_command
	}
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
  if { [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.record_AXI_MM] $fs_obj] == 1 } {  
    lappend arg_list "+access +r+w"
  } elseif { [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName ELABORATE.ACCESS] $fs_obj]
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
	if { [get_param "simulation.addUnifastLibraryForVhdl"] } {
	  if { $b_compile_unifast } {
        set arg_list [linsert $arg_list end "-L" "unifast"]
      } elseif { [get_property "unifast" $fs_obj] } {
	    set arg_list [linsert $arg_list end "-L" "unifast"]
	  }
	}
  }

  if { ([::tclapp::aldec::common::helpers::usf_contains_verilog $design_files]) && ({behav_sim} == $sim_flow) } {
    if { $b_compile_unifast } {
      set arg_list [linsert $arg_list end "-L" "unifast_ver"]
    } elseif { [get_property "unifast" $fs_obj] } {
	  set arg_list [linsert $arg_list end "-L" "unifast_ver"]
	}

    set arg_list [linsert $arg_list end "-L" "unisims_ver"]
    set arg_list [linsert $arg_list end "-L" "unimacro_ver"]
  }

  set b_load_glbl [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName COMPILE.LOAD_GLBL] $fs_obj ]
  if { $::tclapp::aldec::common::helpers::properties(b_int_compile_glbl) || $::tclapp::aldec::common::helpers::properties(b_force_compile_glbl) || $b_load_glbl } {
    if { ([lsearch -exact $arg_list "unisims_ver"] == -1) } {
      if { $::tclapp::aldec::common::helpers::properties(b_force_no_compile_glbl) } {
        # skip unisims_ver
      } else {
        set arg_list [linsert $arg_list end "-L" "unisims_ver"]
      }
    }
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

  # if { $::tclapp::aldec::common::helpers::properties(b_compile_simmodels) } {
    # foreach lib $::tclapp::aldec::common::helpers::properties(l_simmodel_compile_order) {
      # if {[string length $lib] == 0} { continue; }
      # lappend arg_list "-L"
      # lappend arg_list "$lib"
    # }
  # }

  if { $xilinxVipWasAdded == 0 && [ get_param "project.usePreCompiledXilinxVIPLibForSim" ] && [ ::tclapp::aldec::common::helpers::is_vip_ip_required ] } {
    lappend arg_list "-L" "xilinx_vip"
  }

  set d_libs [join $arg_list " "]  
  set arg_list [list $t_opts]
  lappend arg_list "$d_libs"
  set cmd_str [join $arg_list " "]
  return $cmd_str
}

proc usf_add_glbl_top_instance { opts_arg top_level_inst_names } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts

  set flow $::tclapp::aldec::common::helpers::properties(s_simulation_flow)
  set target_lang [ get_property "TARGET_LANGUAGE" [ current_project ] ]

  set b_verilog_sim_netlist 0
  if { ({post_synth_sim} == $flow) || ({post_impl_sim} == $flow) } {
    if { {Verilog} == $target_lang } {
      set b_verilog_sim_netlist 1
    }
  }

  set b_add_glbl 0
  set b_top_level_glbl_inst_set 0

  # is glbl specified explicitly?
  if { ([lsearch ${top_level_inst_names} {glbl}] != -1) } {
    set b_top_level_glbl_inst_set 1
  }

  set fs_obj [ get_filesets $::tclapp::aldec::common::helpers::properties(simset) ]
  set b_load_glbl [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName COMPILE.LOAD_GLBL] $fs_obj ]
  set design_files $::tclapp::aldec::common::helpers::properties(designFiles)

  if { [ ::tclapp::aldec::common::helpers::usf_contains_verilog $design_files ] || $b_verilog_sim_netlist } {
    if { {behav_sim} == $flow } {
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
    if { $::tclapp::aldec::common::helpers::properties(b_int_compile_glbl) } {
      set b_add_glbl 1
    }
  }

  if { !$b_add_glbl } {
    if { $b_load_glbl } {
      # TODO: revisit this for pure vhdl, causing failures
      set b_add_glbl 1
    }
  }

  # force compile glbl
  if { !$b_add_glbl } {
    if { $::tclapp::aldec::common::helpers::properties(b_force_compile_glbl) } {
      set b_add_glbl 1
    }
  }

  # force no compile glbl
  if { $b_add_glbl && $::tclapp::aldec::common::helpers::properties(b_force_no_compile_glbl) } {
    set b_add_glbl 0
  }
  
  if { $b_add_glbl } {
    set top_lib [ ::tclapp::aldec::common::helpers::usf_get_top_library ]
    if { [ ::tclapp::aldec::common::helpers::isGlblByUser ] == 1 } {
      lappend opts "unisims_ver.glbl"
    } else {
      lappend opts "${top_lib}.glbl"
    }	
  }
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
		
		if { [ ::tclapp::aldec::common::helpers::isGuiMode ] != 1 } {
			lappend argumentsList [usf_aldec_getDefaultDatasetName]
		}
	}

	set path_delay 0
	set int_delay 0
	set tpd_prop "TRANSPORT_PATH_DELAY"
	set tid_prop "TRANSPORT_INT_DELAY"
	if { [lsearch -exact [list_property -quiet $fs_obj] $tpd_prop] != -1 } {
		set path_delay [get_property $tpd_prop $fs_obj]
	}
	if { [lsearch -exact [list_property -quiet $fs_obj] $tid_prop] != -1 } {
		set int_delay [get_property $tid_prop $fs_obj]
	}

	if { ({post_synth_sim} == $flow || {post_impl_sim} == $flow) && ({timesim} == $netlist_mode) } {
		lappend argumentsList "+transport_int_delays"
		lappend argumentsList "+pulse_e/$path_delay"
		lappend argumentsList "+pulse_int_e/$int_delay"
		lappend argumentsList "+pulse_r/$path_delay"
		lappend argumentsList "+pulse_int_r/$int_delay"
	}

	lappend argumentsList [ usf_aldec_get_elaboration_cmdline ]

	if { [ get_property [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.VERILOG_ACCELERATION ] $fs_obj ] } {
		lappend argumentsList "-O5"
	} else {
		lappend argumentsList "-O2"
	}

	set design_libs [::tclapp::aldec::common::helpers::getDesignLibraries $::tclapp::aldec::common::helpers::properties(designFiles)]
	if { [ llength [ ::tclapp::aldec::common::helpers::getXpmLibraries ] ] > 0 && [lsearch -exact $design_libs "xpm"] == -1 } {
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

	set top_level_inst_names {}
	usf_add_glbl_top_instance argumentsList $top_level_inst_names
	
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

	set batch_mode_enabled $::tclapp::aldec::common::helpers::properties(batch_mode_enabled)
	set only_generate_scripts $::tclapp::aldec::common::helpers::properties(only_generate_scripts)
	set noQuitOnError [get_param "simulator.activehdlNoQuitOnError"]
	if { $noQuitOnError && [ ::tclapp::aldec::common::helpers::isGuiMode ] == 1 } {
		puts $out "transcript on"
	}

	if { [ ::tclapp::aldec::common::helpers::isGuiMode ] == 1 } {
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

	if { [ ::tclapp::aldec::common::helpers::isGuiMode ] == 1 } {
		puts $out "set worklib $designLibraryName"
	}

	foreach mappedLibraryName $existingMappings {
		if { [ string compare -nocase $mappedLibraryName $designLibraryName ] != 0 } {
			puts $out "vmap -del $mappedLibraryName"
		}
	}

	
	if { [ ::tclapp::aldec::common::helpers::isGenerateLaibraryMode ] != 1 || [ ::tclapp::aldec::common::helpers::isGuiMode ] == 1 } {
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
	
	if { [ ::tclapp::aldec::common::helpers::isGuiMode ] == 1 } {
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

  send_msg_id USF-[usf_aldec_getSimulatorName]-98 INFO "$do_file\n"
  
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

  if { $::tclapp::aldec::common::helpers::properties(b_int_en_vitis_hw_emu_mode) } {
    puts $fh "\nif \{ \[file exists vitis_params.tcl\] \} \{"
    puts $fh "  source vitis_params.tcl"
    puts $fh "\}"
    puts $fh "if \{ \[info exists ::env(USER_PRE_SIM_SCRIPT)\] \} \{"
    puts $fh "  if \{ \[catch \{source \$::env(USER_PRE_SIM_SCRIPT)\} msg\] \} \{"
    puts $fh "    puts \$msg"
    puts $fh "  \}"
    puts $fh "\}"
	puts $fh ""
  }

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

	set uut {}
	[ catch { set uut [ get_property -quiet [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.UUT ] $fs_obj ] } msg ]
	set saif_scope [ get_property [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.SAIF_SCOPE ] $fs_obj ]
	if { {} != $saif_scope } {
		set uut $saif_scope
    }
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

	if { [ get_param "project.writeNativeScriptForUnifiedSimulation" ] && [ ::tclapp::aldec::common::helpers::isOnlyGenerateScripts ] == 0 } {
		if { !$::tclapp::aldec::common::helpers::properties(batch_mode_enabled) } {
			puts $fh "wave *"
		} elseif { !$b_log_all_signals } {
			puts $fh "log *"
		}
	} else {
		puts $fh "if { !\[batch_mode\] } {"
		puts $fh "\twave *"
		puts -nonewline $fh "}" 
		if { !$b_log_all_signals } {
			puts $fh " else {"
			puts $fh "\tlog *"
			puts $fh "}"
		}
	}

  puts $fh ""

  set rt [ string trim [ get_property [ ::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.RUNTIME ] $fs_obj ] ]
  if { $::tclapp::aldec::common::helpers::properties(b_int_en_vitis_hw_emu_mode) } {
    puts $fh "puts \"We are running simulator for infinite time. Added some default signals in the waveform. You can pause simulation and add signals and then resume the simulation again.\""
    puts $fh "puts \"Stopping at breakpoint in simulator also stops the host code execution\""
    puts $fh "if \{ \[info exists ::env(VITIS_LAUNCH_WAVEFORM_GUI) \] \} \{"
    puts $fh "  run 1ns"
    puts $fh "\} else \{"
    if { {} == $rt } {
      # no runtime specified
      puts $fh "  run"
    } else {
      set rt_value [string tolower $rt]
      if { ({all} == $rt_value) || (![regexp {^[0-9]} $rt_value]) } {
        puts $fh "  run -all"
      } else {
        puts $fh "  run $rt"
      }
    }
    puts $fh "\}"
  } else {
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
  puts $fh ""
  # generate AXI MM transactions
  if { [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.record_AXI_MM] $fs_obj] == 1 } {  
    puts $fh "tsv.view.activate"
    puts $fh ""
  }
  set tcl_post_hook [get_property [::tclapp::aldec::common::helpers::usf_aldec_getPropertyName SIMULATE.TCL.POST] $fs_obj]
  ::tclapp::aldec::common::helpers::usf_aldec_get_file_path_from_project tcl_post_hook
  if { [file isfile $tcl_post_hook] && ![::tclapp::aldec::common::helpers::usf_aldec_is_file_disabled $tcl_post_hook] } {
    puts $fh "source \{$tcl_post_hook\}"
	puts $fh ""
  } elseif { $tcl_post_hook != "" } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-94 WARNING "File '$tcl_post_hook' not found or disabled.\n"
  }

  # generate saif file for power estimation
  if { {} != $saif } {
    set extn [string tolower [file extension $saif]]
    if { {.saif} != $extn } {
      append saif ".saif"
    }

	set batch_mode_enabled $::tclapp::aldec::common::helpers::properties(batch_mode_enabled)
    if { [get_property target_simulator [current_project]] == "ActiveHDL" && !$batch_mode_enabled } {
      puts $fh "asdbdump -flush"
    }

    set rec ""
    if { $::tclapp::aldec::common::helpers::properties(mode) != {behavioral} } {
      set rec "-rec"
    }
    puts $fh "asdb2saif -internal -scope $rec ${uut}/* [usf_aldec_getDefaultDatasetName] \{$saif\}"
	puts $fh ""
  }

  # add TCL sources
  set tcl_src_files [list]
  set filter "USED_IN_SIMULATION == 1 && FILE_TYPE == \"TCL\""
  ::tclapp::aldec::common::helpers::usf_find_files tcl_src_files $filter
  if {[llength $tcl_src_files] > 0} {
    foreach file $tcl_src_files {
      puts $fh "source \{$file\}"
    }
    puts $fh ""
  }

  if { $::tclapp::aldec::common::helpers::properties(b_int_en_vitis_hw_emu_mode) } {
    puts $fh "if \{ \[info exists ::env(VITIS_LAUNCH_WAVEFORM_BATCH) \] \} \{"
    puts $fh "  if \{ \[info exists ::env(USER_POST_SIM_SCRIPT) \] \} \{"
    puts $fh "    if \{ \[catch \{source \$::env(USER_POST_SIM_SCRIPT)\} msg\] \} \{"
    puts $fh "      puts \$msg"
    puts $fh "    \}"
    puts $fh "  \}"
    puts $fh "\}"
	puts $fh ""
  } 

  if { \
	   [ ::tclapp::aldec::common::helpers::isOnlyGenerateScripts ] == 1 \
	|| $::tclapp::aldec::common::helpers::properties(b_int_en_vitis_hw_emu_mode) \
  } {
    puts $fh "if { \[batch_mode\] } {"
    puts $fh "  endsim"
    puts $fh "  [usf_aldec_getQuitCmd]"
    puts $fh "}"
  } elseif { $::tclapp::aldec::common::helpers::properties(batch_mode_enabled) } {
    puts $fh "endsim"
    puts $fh "[usf_aldec_getQuitCmd]"
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
  set mode_type   $::tclapp::aldec::common::helpers::properties(mode)
  set name        [file tail $filename]
  set simulatorName [::tclapp::aldec::common::helpers::usf_aldec_getSimulatorName]
  
  puts $fh "#############################################################################################"
  puts $fh "#"
  puts $fh "# File name : $name"
  puts $fh "# Created on: $timestamp"
  puts $fh "#"
  puts $fh "# Script automatically generated by Aldec Tcl Store app 1.42 for '$mode_type' simulation,"
  puts $fh "# in $version for $simulatorName simulator."
  puts $fh "#"
  puts $fh "#############################################################################################"
}

proc aldecHeader { _file _fileName _proces } {

	set version_txt [ split [ version ] "\n" ]
	set version     [ lindex $version_txt 0 ]
	set version_id  [ join [ lrange $version 1 end ] " " ]
	set timestamp   [ clock format [clock seconds ] ]
	set simulatorName [ ::tclapp::aldec::common::helpers::usf_aldec_getSimulatorName ]

	if { $::tcl_platform(platform) == "unix" } {
	
		puts $_file "#!/usr/bin/bash"
		puts $_file "# *********************************************************************************************"
		puts $_file "# Vivado (TM) $version_id"
		puts $_file "#"
		puts $_file "# Filename    : $_fileName"
		puts $_file "# Simulator   : $simulatorName Simulator"
		puts $_file "# Description : Script for $_proces design source files, automatically generated by Aldec Tcl Store app 1.42"
		puts $_file "# Created on  : $timestamp"
		puts $_file "#"
		puts $_file "# usage: $_fileName"
		puts $_file "#"
		puts $_file "# *********************************************************************************************"
	} else {
		puts $_file "REM *********************************************************************************************"
		puts $_file "REM Vivado (TM) $version_id"
		puts $_file "REM"
		puts $_file "REM Filename    : $_fileName"
		puts $_file "REM Simulator   : $simulatorName Simulator"
		puts $_file "REM Description : Script for $_proces design source files, automatically generated by Aldec Tcl Store app 1.42"
		puts $_file "REM Created on  : $timestamp"
		puts $_file "REM"
		puts $_file "REM usage: $_fileName"
		puts $_file "REM"
		puts $_file "REM *********************************************************************************************"
	}
	
	if { $_proces == "elaborating" } {
		puts $_file "exit 0"
	}

}

proc usf_aldec_writeWindowsExecutableCmdLine { _out _batch _doFile _logFile _step } {
	if { [ get_property target_simulator [ current_project ] ] == "ActiveHDL" } {

		set doParameters "-do \""
		if { $_step == "simulate" } {
			append doParameters "set resume_on_error 1; "
		}
		append doParameters "do -tcl"

		if { $_batch != "" } {
			puts $_out "call \"%bin_path%/VSimSA\" -l \"$_logFile\" $doParameters $_doFile\""	
		} else {
			puts $_out "call \"%bin_path%/avhdl\" $doParameters \{$_doFile\}\""
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

proc checkExists { _list _parameter } {
  foreach parameter $_list {
    if { $parameter == $_parameter } {
	  return 1
	}
  }

  return 0
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

  if { $step == "compile" } {
    set headerStep "compiling"
  } else {
    set headerStep "simulating"
  }

  if {$::tcl_platform(platform) != "unix"} {
    puts $scriptFileHandle "@echo off"
  }

  aldecHeader $scriptFileHandle $scriptFileName $headerStep
  
  set batch_sw {-c}
  if { ({simulate} == $step) } {
    # launch_simulation
	if { (!$batch_mode_enabled) && (!$only_generate_scripts) } {
      set batch_sw {}
	}
	
	# for scripts_only mode, set script for simulator gui mode (don't pass -c)
    if { $::tclapp::aldec::common::helpers::properties(b_gui) } {
      set batch_sw {}
    }  
  }
  
  set log_filename "${step}.log"
  if {$::tcl_platform(platform) == "unix"} {
    puts $scriptFileHandle "bin_path=\"$::tclapp::aldec::common::helpers::properties(s_tool_bin_path)\""

	if { [ ::tclapp::aldec::common::helpers::isSystemCEnabled ] } {
      if { $::tclapp::aldec::common::helpers::properties(b_contain_systemc_sources) } {
	    if { {simulate} == $step } {
		  if { $::tclapp::aldec::common::helpers::properties(b_int_en_vitis_hw_emu_mode) } {
            ::tclapp::aldec::common::helpers::usf_write_launch_mode_for_vitis $scriptFileHandle
          }
	    }
	  }
	}

	set simulator [ string tolower [ get_property target_simulator [ current_project ] ] ]
	set xilinxPath $::env(XILINX_VIVADO)
	set simulatorVersion [get_param "simulator.${simulator}.version"]
	set gccVersion [get_param "simulator.${simulator}.gcc.version"]
	
	if { [ ::tclapp::aldec::common::helpers::isSystemCEnabled ] } {
		if { $::tclapp::aldec::common::helpers::properties(b_compile_simmodels) } {
			set xv_cxl_lib_path_dir "simlibs"
		} else {
			set xv_cxl_lib_path_dir [ ::tclapp::aldec::common::helpers::getCompiledLibraryLocation ]
		}

		puts $scriptFileHandle "export xv_cxl_lib_path=\"$xv_cxl_lib_path_dir\""   
		puts $scriptFileHandle "export xv_cxl_ip_path=\"\$xv_cxl_lib_path\""

		set xvCptLibPath [ file join $xilinxPath "data" "simmodels" "riviera" $simulatorVersion "lnx64" $gccVersion "systemc" "protected" ]
		if { [ file exists $xvCptLibPath ] } {
			puts $scriptFileHandle "export xv_cpt_lib_path=\"$xvCptLibPath\""
		}

		if { $::tclapp::aldec::common::helpers::properties(b_compile_simmodels) } {
			puts $scriptFileHandle "export xv_ext_lib_path=\"$::tclapp::aldec::common::helpers::properties(sp_ext_dir)\""
		}
	}

    set aie_ip_obj {}
    if { [ ::tclapp::aldec::common::helpers::isSystemCEnabled ] } {
      if { $::tclapp::aldec::common::helpers::properties(b_contain_systemc_sources) } {
        if { ({elaborate} == $step) || ({simulate} == $step) || ({compile} == $step)} {
          set shared_ip_libs [list]
          set aie_ip_obj [::tclapp::aldec::common::helpers::usf_find_ip "ai_engine"]

     #     variable a_shared_library_path_coln
          foreach {key value} [array get ::tclapp::aldec::common::helpers::a_shared_library_path_coln] {
            set sc_lib   $key
            set lib_path $value
            set lib_dir "$lib_path"

            if { $::tclapp::aldec::common::helpers::properties(b_compile_simmodels) } {
              set lib_name [file tail $lib_path]
              set lib_type [file tail [file dirname $lib_path]]
              if { ("protobuf" == $lib_name) || ("protected" == $lib_type) } {
                # skip
              } else {
                set lib_dir "[getLibraryDir]/$lib_name"
              }
            }

            lappend shared_ip_libs $lib_dir
          }
 
          set libraryLocation [ ::tclapp::aldec::common::helpers::getCompiledLibraryLocation ]
 
          set ip_objs [get_ips -all -quiet]
          set shared_ip_libraries [::tclapp::aldec::common::helpers::usf_get_shared_ip_libraries $libraryLocation]

          foreach ip_obj $ip_objs {
            set ipdef [get_property -quiet IPDEF $ip_obj]
            set ip_name [ lindex [ split $ipdef ":" ] 2 ]
            set ip_version [ lindex [ split $ipdef ":" ] 3 ]

            set ipNameVersion $ip_name
            append ipNameVersion "_v"
            append ipNameVersion [ string map {. "_"} $ip_version ]
            
            set found 0
            foreach shared_ip_lib $shared_ip_libraries {			
              if { [ string first $ipNameVersion $shared_ip_lib ] != -1 } {
                set lib_dir "$libraryLocation/$shared_ip_lib"
                
                if { [ checkExists $shared_ip_libs $lib_dir ] == 0 } {
                  lappend shared_ip_libs $lib_dir
                }

                set found 1
                break
              }
            }

            if { $found == 0 } {
              foreach shared_ip_lib $shared_ip_libraries {			
                if { [ string first $ip_name $shared_ip_lib ] != -1 } {
                  set lib_dir "$libraryLocation/$shared_ip_lib"

                  if { [ checkExists $shared_ip_libs $lib_dir ] == 0 } {
                    lappend shared_ip_libs $lib_dir
                  }

                  break
                }
              }
            }
          }

          if { [llength $shared_ip_libs] > 0 } {
            set shared_ip_libs_env_path [join $shared_ip_libs ":"]
            set ld_path_str "export LD_LIBRARY_PATH=$shared_ip_libs_env_path"
            if { {} != $aie_ip_obj } {
              append ld_path_str ":\$XILINX_VITIS/aietools/lib/lnx64.o"
            }
            puts $scriptFileHandle "$ld_path_str:\$LD_LIBRARY_PATH"			
          }
        }
      }
    }

    ::tclapp::aldec::common::helpers::usf_write_shell_step_fn $scriptFileHandle

    if { \
	     [ ::tclapp::aldec::common::helpers::isSystemCEnabled ] \
      && $::tclapp::aldec::common::helpers::properties(b_contain_systemc_sources) \
	  && $::tclapp::aldec::common::helpers::properties(b_int_en_vitis_hw_emu_mode) \
	  && "simulate" == $step \
	} {
		puts $scriptFileHandle ""
		puts $scriptFileHandle "if \[ \$mode = \"-c\" \]; then"
		puts $scriptFileHandle "  ExecStep \$bin_path/../runvsimsa -l $log_filename -do \"do \{$do_filename\}\""
		puts $scriptFileHandle "elif \[ \$mode = \"-gui\" \]; then"
		puts $scriptFileHandle "  ExecStep \$bin_path/../rungui -l $log_filename -do \"do \{$do_filename\}\""
		puts $scriptFileHandle "fi"
	} else {
		if { $batch_sw != "" } {
		  puts $scriptFileHandle "ExecStep \$bin_path/../runvsimsa -l $log_filename -do \"do \{$do_filename\}\""
		} else {
		  puts $scriptFileHandle "ExecStep \$bin_path/../rungui -l $log_filename -do \"do \{$do_filename\}\""
		}
	}
  } else {
    if { $step == "simulate" } {
        set simulator_lib [::tclapp::aldec::common::helpers::usf_get_simulator_lib_for_bfm]
        if { {} != $simulator_lib } {		
            puts $scriptFileHandle "set PATH=[file dirname $simulator_lib];%PATH%"
        }
    }

    puts $scriptFileHandle "set bin_path=$::tclapp::aldec::common::helpers::properties(s_tool_bin_path)"
    usf_aldec_writeWindowsExecutableCmdLine $scriptFileHandle $batch_sw $do_filename $log_filename $step
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
    if { !$noQuitOnError || [ ::tclapp::aldec::common::helpers::isGuiMode ] == 0 } {
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
