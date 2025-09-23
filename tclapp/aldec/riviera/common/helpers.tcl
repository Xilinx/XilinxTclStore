###############################################################################
#
# helpers.tcl
#
# based on XilinxTclStore\tclapp\xilinx\modelsim\helpers.tcl
#
###############################################################################

package require Vivado 1.2014.1
package require json 

package provide ::tclapp::aldec::common::helpers 1.42

namespace eval ::tclapp::aldec::common {

namespace eval helpers {
  proc createAxiBusMonitor { {_protoinstFilePath "" } } {
		variable properties
		variable scriptPath $properties(launch_directory)
    variable protocolInstcesList
    variable protocolInstcesData 
		variable protoinstFilesList
		variable _outputPath [file join $scriptPath "axi_bus_monitor"]
		
		[catch { file mkdir $_outputPath} error_msg]
		
		if { $_protoinstFilePath ne "" } {
      set file [ open $_protoinstFilePath r ]
      set protocolInstcesList [read $file]
      close $file
    }

    parseProtocolInstcesList

		#Generate axi_bus_monitor.sv file
		generateAxiBusMonitor [file rootname [file tail $_protoinstFilePath]]
		
		#Copy AXI Transaction Recorder		
    }

    proc parseProtocolInstcesList {} {
        variable protocolInstcesList
        variable protocolInstcesData

        set json [ ::json::json2dict $protocolInstcesList ]
        set modulesContent  [ dict get $json modules ]
		
		if {[info exists protocolInstcesData]} { unset protocolInstcesData }
		
		foreach _moduleName [ dict keys $modulesContent ] {
			set _tmp [dict get $modulesContent $_moduleName]
			set _tmp2 [dict get $_tmp proto_instances]
			
			foreach _interfaceName [ dict keys $_tmp2 ] {
				dict set _interfaceData moduleName $_moduleName
				dict set _interfaceData interfaceName [ string trimleft $_interfaceName / ]
				dict set _interfaceData interfaceType [ dict get [ dict get $_tmp2 $_interfaceName ] interface ]
				
				#get signals data
				if {[info exists _portList]} { unset _portList }
				set _ports [ dict get [ dict get $_tmp2 $_interfaceName ] ports ]
				foreach _port [dict keys $_ports ] {
					dict set _portList $_port [ dict get [ dict get $_ports $_port ] actual ]					
				}				
				dict set _interfaceData interfacePorts $_portList
				
				# Array of collections describing ports for each module/interface
				#set interfaceList($_interfaceName) $_interfaceData						
				set protocolInstcesData($_moduleName$_interfaceName) $_interfaceData
			}
		}
    }

	proc generateAxiBusMonitor {_protoinstFilename} {
		variable properties
		variable protocolInstcesData
		variable scriptPath $properties(launch_directory)
		variable _outputPath
		variable protoinstFilesList
		variable path
		# Output file name		
		set path "axi_bus_monitor_${_protoinstFilename}.sv"
		
		lappend  protoinstFilesList  $path 
		generateABMFile $_outputPath $path protocolInstcesData $_protoinstFilename
	}
	
	proc generateABMFile { _outputPath _path _templateContent _protoinstFilename } {
        set directories [ lrange $_path 0 end-1 ]
        set name [ lindex $_path end ]


        set directoryPath [ file normalize [ file join $_outputPath {*}$directories ] ]

        file mkdir $directoryPath
		
        set filePath [ file join $directoryPath $name ]
        set content [ generateABMFileContent $_templateContent $_protoinstFilename]

        set file [ open $filePath "w" ]
        puts -nonewline $file $content
        close $file   
    }

    proc generateABMFileContent { _template _protoinstFilename } {
        variable protocolInstcesData
        variable fileContent 
		
		variable USE_VECTOR_RANGES
		
# Header
		set fileContent "// (c) Aldec, Inc.\n// All rights reserved.\n\n"

# Parameter defines
# TODO: currently parameters values are hardcoded - if they cannot by obtained from protoinst then could be possibly read from some kine od cfg file
		append fileContent \
			"// The aximm interface parameters\
			\n`define DATA_BUS_WIDTH 32\
			\n`define ADDRESS_WIDTH 32\
			\n`define ID_WIDTH 4\
			\n`define AWUSER_BUS_WIDTH 16\
			\n`define ARUSER_BUS_WIDTH 16\
			\n`define RUSER_BUS_WIDTH 16\
			\n`define WUSER_BUS_WIDTH 16\
			\n`define BUSER_BUS_WIDTH 16 \
			\n// The axis interface parameters\
			\n`define AXIS_DATA_BUS_WIDTH 32\
            \n`define TID_WIDTH 8\
            \n`define TDEST_WIDTH 4\
            \n`define TUSER_WIDTH 1\
			\n\n"	
		
		append fileContent "module axi_bus_monitor_$_protoinstFilename;\n\n"
		
		set localSignalsDeclaration ""
		set recordersInstantiations ""
		set initialProcesContent ""
						
		foreach _index [array names protocolInstcesData] {
		    # debug line below displays all parsed data for each protocol instance
		    #puts "protocolInstcesData($_index): $protocolInstcesData($_index)"
		
# TODO - iteration should detect different "moduleName" values - probably for each module name the ekstra bus_monitor_module should be generated
# Until the *protoinstal file contains one module it will work - later the interfsces and parameters have to be splited between modules
# Solution: iterate through all protocol names, collect separate list of protocols for each modules then process it seperately or redesign array of parsed data
#TODO - "_moduleName" is a temporary variable to get module name - to fix in next release
		    
			set _moduleName [ dict get $protocolInstcesData($_index) moduleName ]
			
			set _underscoredIfaceName [string map { / _ } [ dict get $protocolInstcesData($_index) interfaceName ] ]
			
#TODO - start if(protocol type)...
# We need different recorders for different interfaces types
# TODO: Consider: Now we checking full name of interface type - mayby we should only the "aximm" or "axis" strings
			
		# AXI Memory Mapped (aximm) interfaces	
	        if { [dict get $protocolInstcesData($_index) interfaceType] eq "xilinx.com:interface:aximm:1.0" } {
			    # Set a name for the instance of the recorder
				set _recorderInstanceName $_underscoredIfaceName\_trans_rec_i				
			    # Header for local monitor signals of current protocol instance
				append localSignalsDeclaration "\t// Local signals mirrors for " [ dict get $protocolInstcesData($_index) interfaceName ] " aximm interface. \n"
			    # Header for $signal_agent signals assignments for current protocol instance
				append initialProcesContent "\t// Setting the mirror signals for " [ dict get $protocolInstcesData($_index) interfaceName ] " aximm interface. \n"			
			    # Instantations of TransactionRecorderAxi4 module
				append recordersInstantiations "\t// Monitor for " [ dict get $protocolInstcesData($_index) interfaceName ] " aximm interface. \n"
				append recordersInstantiations "\tTransactionRecorderAxi4\n"
			    # Print module parameters list
				append recordersInstantiations "\t#\(\n\t\t.DATA_BUS_WIDTH(`DATA_BUS_WIDTH), \n\t\t.ADDRESS_WIDTH(`ADDRESS_WIDTH), \n\t\t.ID_WIDTH(`ID_WIDTH),\
						\n\t\t.AWUSER_BUS_WIDTH(`AWUSER_BUS_WIDTH), \n\t\t.ARUSER_BUS_WIDTH(`ARUSER_BUS_WIDTH), \n\t\t.RUSER_BUS_WIDTH(`RUSER_BUS_WIDTH),\
						\n\t\t.WUSER_BUS_WIDTH(`WUSER_BUS_WIDTH), \n\t\t.BUSER_BUS_WIDTH(`BUSER_BUS_WIDTH),\n\t\t.INSTANCE(\"$_recorderInstanceName\")\n\t)\n"			
			    # Generate instance name
				append recordersInstantiations "\t" $_recorderInstanceName "\n"

				#module port list
				append recordersInstantiations "\t(\n"
				
				set _ports [ dict get $protocolInstcesData($_index) interfacePorts ]
				set _portsNumber [ dict size $_ports ]
				
				foreach _port [dict keys $_ports ] {
					incr _portsNumber -1				
					set _signalHierarchy [ dict get $protocolInstcesData($_index) interfaceName ] 
					set _signalHierarchy [ string range $_signalHierarchy 0 [string last / $_signalHierarchy ] ]
					set _signalHierarchy [ string map { / . } $_signalHierarchy ]
					#Rename Vivado notation style port name from ARESETN to ARESETn used by TransactionRecorder
					if {$_port == "ARESETN"} {
						append recordersInstantiations "\t\t." "ARESETn" "(" $_underscoredIfaceName\_$_port ")"
					#Connection of Vivado active high reset port named ARESETN to ARESETn port of TransactionRecorder
					} elseif {$_port == "ARESET"} {
						append recordersInstantiations "\t\t." "ARESETn" "(" ~$_underscoredIfaceName\_$_port ")"
					} else {
						append recordersInstantiations "\t\t." $_port "(" $_underscoredIfaceName\_$_port ")"
					}				
					if { $_portsNumber == 0 } { 
						append recordersInstantiations "\n"
					} else {
						append recordersInstantiations ",\n"
					}
				
				# Create a local monitor signal for each port
					if {$_port == "AWADDR" || $_port == "ARADDR"} {
						append localSignalsDeclaration "\treg \[`ADDRESS_WIDTH-1:0\] " $_underscoredIfaceName\_$_port ";\n"
					} elseif {$_port == "WDATA" || $_port == "RDATA"} {
						append localSignalsDeclaration "\treg \[`DATA_BUS_WIDTH-1:0\] " $_underscoredIfaceName\_$_port ";\n"
					} elseif {$_port == "AWID" || $_port == "WID" || $_port == "BID" || $_port == "ARID" || $_port == "RID" } {
						append localSignalsDeclaration "\treg \[`ID_WIDTH-1:0\]" $_underscoredIfaceName\_$_port ";\n"
					} elseif {$_port == "AWUSER"} {
						append localSignalsDeclaration "\treg \[`AWUSER_BUS_WIDTH-1:0\] " $_underscoredIfaceName\_$_port ";\n"
					} elseif {$_port == "ARUSER"} {
						append localSignalsDeclaration "\treg \[`ARUSER_BUS_WIDTH-1:0\] " $_underscoredIfaceName\_$_port ";\n"
					} elseif {$_port == "RUSER"} {
						append localSignalsDeclaration "\treg \[`RUSER_BUS_WIDTH-1:0\] " $_underscoredIfaceName\_$_port ";\n"
					} elseif {$_port == "WUSER"} {
						append localSignalsDeclaration "\treg \[`WUSER_BUS_WIDTH-1:0\] " $_underscoredIfaceName\_$_port ";\n"
					} elseif {$_port == "BUSER"} {
						append localSignalsDeclaration "\treg \[`BUSER_BUS_WIDTH-1:0\] " $_underscoredIfaceName\_$_port ";\n"
					} elseif {$_port == "ARLEN" || $_port == "AWLEN"} {
						append localSignalsDeclaration "\treg \[7:0\] " $_underscoredIfaceName\_$_port ";\n"
					} elseif {$_port == "AWCACHE" || $_port == "AWQOS" || $_port == "AWREGION" || $_port == "ARCACHE" || $_port == "ARQOS" || $_port == "ARREGION" } {
						append localSignalsDeclaration "\treg \[3:0\] " $_underscoredIfaceName\_$_port ";\n"
					} elseif {$_port == "AWSIZE" || $_port == "AWPROT" || $_port == "ARSIZE" || $_port == "ARPROT" } {
						append localSignalsDeclaration "\treg \[2:0\] " $_underscoredIfaceName\_$_port ";\n"
					} elseif {$_port == "AWBURST" || $_port == "AWLOCK" || $_port == "BRESP" || $_port == "ARBURST" || $_port == "ARLOCK" || $_port == "RRESP" } {
						append localSignalsDeclaration "\treg \[1:0\] " $_underscoredIfaceName\_$_port ";\n"
					} else {
						append localSignalsDeclaration "\treg " $_underscoredIfaceName\_$_port ";\n"
					}		
				
				# Create a $signal_agent assigments for each port
					variable _portName [dict get $_ports $_port] ]
					variable _bracketIndex [string first \[ $_portName]
					if { !$USE_VECTOR_RANGES && $_bracketIndex > 0 } { set _portName [ string range $_portName 0 [ expr { $_bracketIndex-1 } ] ] }
					append initialProcesContent "\t\t\$signal_agent(\"" $_signalHierarchy $_portName "\", \"" $_underscoredIfaceName\_$_port "\", 0 );\n"
				}
				
				append recordersInstantiations "\t);\n"
				append localSignalsDeclaration "\n"
				append initialProcesContent "\n"
			
			} else {
				send_msg_id USF-[usf_aldec_getSimulatorName]-99 WARNING "WARNING: Ommitted monitor generation for unsupported [dict get $protocolInstcesData($_index) interfaceType] protocol!\n"
			}
		}
		
		append fileContent $localSignalsDeclaration
		append fileContent $recordersInstantiations "\n"
		if {$initialProcesContent ne ""} {
		append fileContent "\tinitial\n\tbegin\n"
		append fileContent $initialProcesContent
		append fileContent "\tend\n\n"
		}
		append fileContent "endmodule\n\n"
		
		
		append fileContent "// Instantiate AXI_BUS_MONITOR_$_protoinstFilename in top level testbench\n\n"
		append fileContent "bind " $_moduleName " axi_bus_monitor_$_protoinstFilename axi_bus_monitor_i();\n"
		
		
		return $fileContent
    }

proc isIpProject {} {
	set fsFilter \
		   "FILESET_TYPE == \"SimulationSrcs\" \
		|| FILESET_TYPE == \"DesignSrcs\" \
        || FILESET_TYPE == \"BlockSrcs\""

	set ftFilter \
		  "FILE_TYPE == \"IP\" \
		|| FILE_TYPE == \"IPX\" \
        || FILE_TYPE == \"DSP Design Sources\" \
		|| FILE_TYPE == \"Block Designs\""

	foreach fsObject [ get_filesets -quiet -filter $fsFilter ] {
		set ip_files [ get_files -quiet -all -of_objects $fsObject -filter $ftFilter ]
		if { [ llength $ip_files ] > 0 } {
			return true
		}
	}

	return false
}

proc getXpmLibraries { } {
	set returnLibraries [ list ]

	set xpmLibraries [ get_property -quiet "XPM_LIBRARIES" [ current_project ] ]
	set autoXpmLibraries [ auto_detect_xpm -quiet -search_ips -no_set_property ]
	set allXpmLibraries [ concat $xpmLibraries $autoXpmLibraries ]

	if { [ llength $allXpmLibraries ] > 0 } {
		foreach library $allXpmLibraries {
			if { [ lsearch $returnLibraries $library ] == -1 } {
				lappend returnLibraries $library
			}
		}
	}

	return $returnLibraries
}

proc getCompiledLibraryLocation { } {
	variable properties

	set librariesLocation ""

	switch -- [ get_property target_simulator [ current_project ] ] {
		Riviera { set librariesLocation [ get_property COMPXLIB.RIVIERA_COMPILED_LIBRARY_DIR [ current_project ] ] }
		ActiveHDL { set librariesLocation [ get_property COMPXLIB.ACTIVEHDL_COMPILED_LIBRARY_DIR [ current_project ] ] }
	}

	if { $properties(s_lib_map_path) != "" } {
		set librariesLocation $properties(s_lib_map_path)
	} 

	if { ![ file isfile [ file join $librariesLocation library.cfg ] ] } {
		createLibraryCfgFile $librariesLocation
	}

	return $librariesLocation
}

proc createLibraryCfgFile { _path } {

	set libraries [ list ]
	lappend libraries "\$INCLUDE = \"\$VSIMSALIBRARYCFG\""

	foreach libraryDirectory [ glob -nocomplain -directory $_path * ] {
        if { ![file isdirectory $libraryDirectory] } {
			continue
		}

		set libraryName [ file tail $libraryDirectory ]
		set libraryPath [ file join $libraryDirectory $libraryName.lib ]	

		if { ![ file exists $libraryPath ] } {
			continue
		}

		set libraryPath [ usf_get_relative_file_path $libraryPath $_path]

		lappend libraries "$libraryName = \"$libraryPath\""
	}

	if { [ llength $libraries ] < 2 } {
		return 
	}

	set libraryCfgPath [ usf_file_normalize [ file join $_path "library.cfg" ] ]

	set fileStream 0
	if { [ catch {open $libraryCfgPath w} fileStream ] } {
		send_msg_id USF-[usf_aldec_getSimulatorName]-90 ERROR "Failed to open file to write ($libraryCfgPath)\n"
		return
	}

	foreach library $libraries {
		puts $fileStream $library
	}

	close $fileStream
}

proc getCompiledLibrariesFromFile { _librariesDirectory } {  
	set libraries [ list ]
	set file [ file normalize [ file join $_librariesDirectory ".cxl.stat" ] ]

	if { ![ file exists $file ] } {
		return $libraries
	}

	set fh 0
	if { [ catch { open $file r } fh ] } {
		return $libraries
	}

	set libraryData [ split [ read $fh ] "\n" ]
	close $fh

	foreach line $libraryData {
		set line [ string trim $line ]

		if { [string length $line] == 0 } {
			continue;
		}

		if { [ regexp {^#} $line ] } {
			continue;
		}

		set tokens [ split $line {,} ]
		set library [ lindex $tokens 0 ]
		
		if { [ lsearch -exact $libraries $library ] == -1 } {
			lappend libraries $library
		}
	}

	return $libraries
}

proc findCompiledLibraries { } {
	variable properties
	variable compiledLibraries

	set compiledLibraryLocation [getCompiledLibraryLocation]
	set referenceXpmLibrary 0

	if { [ llength [ getXpmLibraries ] ] > 0 } {
		if { [ get_param project.usePreCompiledXPMLibForSim ] } {
			set referenceXpmLibrary 1
		}
	}

	if { ( $properties(b_use_static_lib) ) && ( [ isIpProject ] || $referenceXpmLibrary) } {
		set localIpLibaries [ getLibrariesFromLocalRepo ]
		if { {} != $compiledLibraryLocation } {
			set libraries [ getCompiledLibrariesFromFile $compiledLibraryLocation ]

			foreach lib $libraries {
				if { [ lsearch -exact $localIpLibaries $lib ] != -1 } {
					continue
				} else {
					lappend compiledLibraries $lib
				}
			}
		}
	}
}

proc getLibrariesFromLocalRepo {} {
	set installRepo [ file normalize [ file join [ rdi::get_data_dir -quiet -datafile "ip" ] "ip" ] ]
	set installComps [ split [string map {\\ /} $installRepo] {/} ]
	set index [ lsearch -exact $installComps "IP_HEAD" ]

	if { $index == -1 } {
		set installDir $installRepo
	} else {
		set installDir [ join [ lrange $installComps $index end ] "/" ]
	}

	variable a_sim_lib_info
	array unset a_sim_lib_info

	variable a_locked_ips
	array unset a_locked_ips

	variable a_custom_ips
	array unset a_custom_ips

	set libraryDict [ dict create ]
	foreach ipObject [get_ips -all -quiet] {
		if { {} == $ipObject } {
			continue
		}
  
		if { [ get_property -quiet is_locked $ipObject ] } {
			foreach fileObject [ get_files -quiet -all -of_objects $ipObject -filter {USED_IN=~"*ipstatic*"} ] {
				set lib [ get_property library $fileObject ]
				if { {xil_defaultlib} == $lib } {
					continue
				}

				dict append libraryDict $lib

				if { ![ info exists a_sim_lib_info($lib) ] } {
					set a_sim_lib_info($ipObject#$lib) "LOCKED_IP"

					if { ![info exists a_locked_ips($lib)] } {
						set a_locked_ips($lib) $ipObject
					}
				}
			}
		} else {
			set ipDefObject [ get_ipdefs -quiet -all [ get_property -quiet ipdef $ipObject ] ]
			if { {} == $ipDefObject } {
				continue
			}

			set localRepo [ lindex [ get_property -quiet repository $ipDefObject ] 0 ]
			if { {} == $localRepo } {
				continue
			}

			set localRepo [ string map {\\ /} $localRepo ]
			if { {ip_repo} != [ file tail $localRepo ] } {
				continue
			}

			set localComps [ split $localRepo {/} ]
			set index [ lsearch -exact $localComps "IP_HEAD" ]
			if { $index == -1 } {
				set localDirectory $localRepo
			} else {
				set localDirectory [ join [ lrange $localComps $index end ] "/" ]
			}

			if { [ string equal -nocase $installDir $localDirectory] != 1 } {
				foreach fileObject [ get_files -quiet -all -of_objects $ipObject -filter {USED_IN=~"*ipstatic*"} ] {
					set lib [ get_property library $fileObject ]
					if { {xil_defaultlib} == $lib } {
						continue
					}
					
					dict append libraryDict $lib

					if { ![ info exists a_sim_lib_info($lib) ] } {
						set a_sim_lib_info($ipObject#$lib) "CUSTOM_IP"

						if { ![ info exists a_custom_ips($lib) ] } {
							set a_custom_ips($lib) $ipObject
						}
					}
				}
			}
		}
	}

	return [ dict keys $libraryDict ]
}

proc isLockedIp { _library } {
	variable a_locked_ips

	if { [ info exists a_locked_ips($_library) ] } {
		return true
	}

	return false
}

proc isCustomIp { _library } {
	variable a_custom_ips

	if { [ info exists a_custom_ips($_library) ] } {
		return true
	}

	return false
}

proc printIpCompileMessage { _library } {
	variable a_locked_ips
	variable a_custom_ips

	set common_txt "source(s) will be compiled locally with the design"
  
	if { [ isLockedIp $_library ] } {
		send_msg_id USF-[usf_aldec_getSimulatorName]-040 INFO "Using sources from the locked IP version (pre-compiled version will not be referenced) - $_library\n"
	} elseif { [ isCustomIp $_library ] } {
		send_msg_id USF-[usf_aldec_getSimulatorName]-040 INFO "Using sources from the custom IP version (pre-compiled version will not be referenced) - $_library\n"
	} else {
		send_msg_id USF-[usf_aldec_getSimulatorName]-040 INFO "IP version not found from pre-compiled library ($_library) - $common_txt\n"
	}
}

proc getDesignLibraries { _files } {
	set libraries [ list ]

	foreach file $_files {
		set fargs [ split $file {|} ]
		set type [ lindex $fargs 0 ]
		set file_type [ lindex $fargs 1 ]
		set library [ lindex $fargs 2 ]
		if { {} == $library } {
			continue;
		}

		if { [lsearch -exact $libraries $library] == -1 } {
			lappend libraries $library
		}
	}

	return $libraries
}

proc isDesignLibrary { _libraryName } {
	variable properties

	set designFiles $properties(designFiles)
	set designLibraries [ getDesignLibraries $designFiles ]

	foreach library $designLibraries {
		if { [ string compare -nocase $_libraryName $library ] == 0 } {
			return 1
		}
	}

	return 0
}

proc isBatchMode { } {
	variable properties

	set batchModeEnabled $properties(batch_mode_enabled)
	set onlyGenerateScripts $properties(only_generate_scripts)

	if { $batchModeEnabled || $onlyGenerateScripts } {
		return 1
	}

	return 0
}

proc isGuiMode { } {
	variable properties

	if { $properties(batch_mode_enabled) } {
		return 0
	}
	
	if { $properties(b_gui) } {
		return 1
	}
	
	if { $properties(only_generate_scripts) } {
		return 0
	}

	return 1
}

proc isOnlyGenerateScripts { } {
	variable properties

	if { $properties(only_generate_scripts) && !$properties(b_gui) } {
		return 1
	}

	return 0
}

proc findPrecompiledLibrary { } {
	variable precompiledLibrary

	set librariesLocation [ ::tclapp::aldec::common::helpers::getCompiledLibraryLocation ]
	if { $librariesLocation == "" } {
		return
	}

	set libraryCfgFile [ file join $librariesLocation library.cfg ]
	if { ![ file isfile $libraryCfgFile ] } {
		return
	}

	set libraryCfg [ open $libraryCfgFile r ]

	while { ! [eof $libraryCfg ] } {
		gets $libraryCfg line
		if { [ regexp {\s*([^\s]+)\s*=\s*\"?([^\s\"]+).*} $line tmp mapName mapPath ] } {

			if { [ file pathtype $mapPath ] != "absolute" } {
				set mapPath [ file join $librariesLocation $mapPath ]
			}

			if { ![ file isfile [ usf_file_normalize $mapPath ] ] } {
				continue
			}

			lappend precompiledLibrary $mapName
		}
	}

	close $libraryCfg
}

proc checkLibraryWasCompiled { _library } {
	variable precompiledLibrary

	foreach library $precompiledLibrary {
		if { [ string compare -nocase $_library $library ] == 0 } {
			return 1
		}
	}

	return 0
}

proc extractSuboreSystemVerilogPackageLibraries { _vlnv } {
	variable systemVerilogPackageLibraries

	set ipDef [ get_ipdefs -quiet -all -vlnv $_vlnv ]
	if { "" == $ipDef } {
		return
	}

	set ipXml [ get_property xml_file_name $ipDef ]
	set ipComp [ ipx::open_core -set_current false $ipXml ]

	foreach fileGroup [ ipx::get_file_groups -of $ipComp ] {
		set type [get_property type $fileGroup ]

		if { ([ string last "simulation" $type ] != -1) && ($type != "examples_simulation") } {
			set subLibraryCores [ get_property component_subcores $fileGroup ]
			set orderedSubCores [ list ]

			foreach subVlnv $subLibraryCores {
				set orderedSubCores [ linsert $orderedSubCores 0 $subVlnv ]
			}

			foreach subVlnv $orderedSubCores {
				extractSuboreSystemVerilogPackageLibraries $subVlnv
			}
			
			foreach staticFile [ ipx::get_files -filter {USED_IN=~"*ipstatic*"} -of $fileGroup ] {
				set fileEntry [ split $staticFile { } ]
				lassign $fileEntry file_key comp_ref file_group_name file_path
				set ipFile [ lindex $fileEntry 3 ]
				set fileType [ get_property type [ ipx::get_files $ipFile -of_objects $fileGroup ] ]

				if { {systemVerilogSource} == $fileType } {
					set library [ get_property library_name [ ipx::get_files $ipFile -of_objects $fileGroup ] ]
					if { ({} != $library) && ({xil_defaultlib} != $library) } {
						if { [ lsearch $systemVerilogPackageLibraries $library ] == -1 } {
							lappend systemVerilogPackageLibraries $library
						}
					}
				}
			}
		}
	}
}

proc findSystemVerilogPackageLibraries { _runDirectory } {
	variable systemVerilogPackageLibraries

	set tmpDirectory "$_runDirectory/_tmp_ip_comp_"
	set ipComps [ list ]

	foreach ip [ get_ips -all -quiet ] {
		set ipFile [ get_property ip_file $ip ]
		set ipFilename [ file rootname $ipFile ]
		append ipFilename ".xml"

		if { ![file exists $ipFilename] } {

			set ipFileObject [ get_files -all -quiet $ipFilename ]
			if { ({} != $ipFileObject) && ([ file exists $ipFileObject ]) } {
				set ipFilename [ extract_files -files [ list "$ipFileObject" ] -base_dir "$tmpDirectory" ]
			}

			if { ![file exists $ipFilename] } {
				continue;
			}
		}

		lappend ipComps $ipFilename
	}

	foreach ipXml $ipComps {
		set ipComp [ ipx::open_core -set_current false $ipXml ]
		set vlnv [ get_property vlnv $ipComp ]

		foreach fileGroup [ ipx::get_file_groups -of $ipComp ] {
			set type [ get_property type $fileGroup ]

			if { ([ string last "simulation" $type ] != -1) && ($type != "examples_simulation") } {
				set subLibraryCores [ get_property component_subcores $fileGroup ]
				if { [ llength $subLibraryCores ] == 0 } {
					continue
				}

				set orderedSubCores [ list ]
				foreach subVlnv $subLibraryCores {
					set orderedSubCores [ linsert $orderedSubCores 0 $subVlnv ]
				}

				foreach subVlnv $orderedSubCores {
					extractSuboreSystemVerilogPackageLibraries $subVlnv
				}

				foreach staticFile [ ipx::get_files -filter {USED_IN=~"*ipstatic*"} -of $fileGroup ] {
					set fileEntry [ split $staticFile { } ]
					lassign $fileEntry file_key comp_ref file_group_name file_path
					set ipFile [ lindex $fileEntry 3 ]
					set fileType [ get_property type [ ipx::get_files $ipFile -of_objects $fileGroup ] ]

					if { {systemVerilogSource} == $fileType } {
						set library [ get_property library_name [ ipx::get_files $ipFile -of_objects $fileGroup ] ]
						if { ({} != $library) && ({xil_defaultlib} != $library) } {
							if { [lsearch $systemVerilogPackageLibraries $library] == -1 } {
								lappend systemVerilogPackageLibraries $library
							}
						}
					}
				}
			}
		}

		ipx::unload_core $ipComp
	}

	if { [file exists $tmpDirectory] } {
		[ catch {file delete -force $tmpDirectory} error_msg ]
	}

	if { [ get_param "project.compileXilinxVipLocalForDesign" ] } {
		set filter "FILE_TYPE == \"SystemVerilog\""
		
		foreach systemVerilogFileObject [ get_files -quiet -compile_order sources -used_in simulation -of_objects [ current_fileset -simset ] -filter $filter ] {
			if { [lsearch -exact [list_property -quiet $systemVerilogFileObject] {LIBRARY}] != -1 } {
				set library [get_property -quiet "LIBRARY" $systemVerilogFileObject]
				if { {} != $library } {
					if { [ lsearch -exact $systemVerilogPackageLibraries $library ] == -1 } {
						lappend systemVerilogPackageLibraries $library
					}
				}
			}
		}
	}

	if { [ get_param "project.usePreCompiledXilinxVIPLibForSim" ] } {
		if { [ is_vip_ip_required ] } {
			lappend systemVerilogPackageLibraries "xilinx_vip"
		}
	}
}

proc getXilinxVipFiles {} {  
	variable systemVerilogPackageLibraries	

	set xv_files [list]
	if { [ llength $systemVerilogPackageLibraries ] == 0 } {
		return $xv_files
	}

	set xv_dir [ file normalize "[rdi::get_data_dir -quiet -datafile "xilinx_vip"]/xilinx_vip" ]
	set file "$xv_dir/xilinx_vip_pkg.list.f"
	if { ![ file exists $file ] } {
		send_msg_id SIM-[usf_aldec_getSimulatorName]-058 WARNING "File does not exist! '$file'\n"
		return $xv_files
	}

	set fh 0
	if { [catch {open $file r} fh] } {
		send_msg_id SIM-[usf_aldec_getSimulatorName]-058 WARNING "Failed to open file for read! '$file'\n"
		return $xv_files
	}

	set sv_file_data [ split [ read $fh ] "\n" ]
	close $fh

	foreach line $sv_file_data {
		if { [string length $line] == 0 } {
			continue;
		}

		if { [regexp {^#} $line] } {
			continue;
		}

		set file_path_str [ string map {\\ /} $line ]
		set replace "XILINX_VIVADO/data/xilinx_vip"
		set with "$xv_dir"
		regsub -all $replace $file_path_str $with file_path_str
		set file_path_str [ string trimleft $file_path_str {$} ]
		set sv_file_path [ string map {\\ /} $file_path_str ]

		if { [ file exists $sv_file_path ] } {
			lappend xv_files $sv_file_path
		}
	}

	return $xv_files
}

proc getVipIncludeDirs { } {
	variable systemVerilogPackageLibraries

	set includeDir {}
	if { [ llength $systemVerilogPackageLibraries ] > 0 } {
		set data_dir [ rdi::get_data_dir -quiet -datafile xilinx_vip ]
		set includeDir "${data_dir}/xilinx_vip/include"
		if { [ file exists $includeDir ] } {
			return $includeDir
		}
	}

	return $includeDir
}

proc setPreCompiledLibraries2DesignBrowser { _generateLaibraryMode } {
	variable generateLaibraryMode

	set generateLaibraryMode $_generateLaibraryMode
}

proc setlnlglbl { _glbl } {
	variable userSetGlbl

	set userSetGlbl $_glbl
}

proc isGenerateLaibraryMode { } {
	variable generateLaibraryMode

	if { [ get_property target_simulator [ current_project ] ] == "ActiveHDL" } {

		if { [ info exists generateLaibraryMode ] } {
			return $generateLaibraryMode
		}

		return 1
	}

	return 0
}

proc isGlblByUser { } {
	variable userSetGlbl

	if { [ info exists userSetGlbl ] } {
		return $userSetGlbl
	}

	return 0
}

proc usf_aldec_get_file_path_from_project { _file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $_file file

  set tmp [lindex [get_files -quiet $file] 0]
  if { $tmp != "" } {
    set file $tmp
  }
}
proc getProtoinstFiles { dynamic_repo_dir } {
  
  set protoinst_f [list]
  set repo_src_file ""
  set filter "FILE_TYPE == \"Protocol Instance\""
  
  foreach file [get_files -quiet -all -filter $filter] {
    if { ![file exists $file] } {
       continue
    }
    set file [getProtoFileFromRepo $file $dynamic_repo_dir  repo_src_file]
    if { {} != $file } {
      lappend protoinst_f $file
    }
  }
  return $protoinst_f
}
proc getProtoFileFromRepo { src_file dynamic_repo_dir  repo_src_file_arg } {
  
  upvar $repo_src_file_arg repo_src_file

  variable a_sim_cache_all_design_files_obj

  set filename [file tail $src_file]
  set file_dir [file dirname $src_file]
  set file_obj {}

  if { [info exists a_sim_cache_all_design_files_obj($src_file)] } {
    set file_obj $a_sim_cache_all_design_files_obj($src_file)
  } else {
    set file_obj [lindex [get_files -all [list "$src_file"]] 0]
  }

  set parent_comp_file [get_property -quiet parent_composite_file $file_obj]
  if { {} == $parent_comp_file } {
    return $src_file
  }
  
  set parent_comp_file_type [get_property -quiet file_type [lindex [get_files -all [list "$parent_comp_file"]] 0]]
  set core_name             [file root [file tail $parent_comp_file]]

  set ip_dir {}
  if { ({Block Designs} == $parent_comp_file_type) } {
    set top_ip_file_name {}
    set ip_dir [usf_get_ip_output_dir_from_parent_composite $src_file top_ip_file_name]
    if { {} == $ip_dir } {
      return $src_file
    }
  } else {
    return $src_file
  }
  
  set hdl_dir_file [usf_get_sub_file_path $file_dir $ip_dir]
  set repo_target_dir [file join $dynamic_repo_dir "bd" $core_name $hdl_dir_file]
  set repo_src_file "$repo_target_dir/$filename"

  if { [file exists $repo_src_file] } {
    [catch {file copy -force $src_file $repo_target_dir} error_msg]
    return $repo_src_file
  }
  return $src_file
}

proc usf_aldec_is_file_disabled { _file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set isDisabled 0
  catch { set isDisabled [get_property IS_USER_DISABLED [get_files -quiet $_file]] }
  return $isDisabled
}

proc usf_aldec_get_vivado_version {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { [regexp {[0-9]{4}\.[0-9]+} [version -short] value] } {
    return $value
  } else {
    return 0.0
  }
}

proc usf_aldec_correctSetupArgs { args } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # Projects created prior to Vivado 2016.1 with enabled "generate scripts only" option, and imported into newer Vivado, 
  # still pass -scripts_only switch, but it doesn't exist anymore in gui so we need to remove it from args
  if { [usf_aldec_get_vivado_version] < 2016.1 } {
    return
  }

  upvar $args _args
  regsub -- {-scripts_only} $_args "" _args
  }

proc usf_aldec_appendSimulationCoverageOptions { _optionsList } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties

  upvar $_optionsList optionsList  
  set fileset_object [get_filesets $properties(simset)]

  set switches ""

  if { [get_property [usf_aldec_getPropertyName SIMULATE.STATEMENT_COVERAGE] $fileset_object] } {
    append switches "s"
  }
  if { [get_property [usf_aldec_getPropertyName SIMULATE.BRANCH_COVERAGE] $fileset_object] } {
    append switches "b"
  }
  if { [get_property [usf_aldec_getPropertyName SIMULATE.FUNCTIONAL_COVERAGE] $fileset_object] } {
    append switches "f"
  }
  if { [get_property [usf_aldec_getPropertyName SIMULATE.EXPRESSION_COVERAGE] $fileset_object] } {
    append switches "e"
  }
  if { [get_property [usf_aldec_getPropertyName SIMULATE.CONDITION_COVERAGE] $fileset_object] } {
    append switches "c"
  }
  if { [get_property [usf_aldec_getPropertyName SIMULATE.PATH_COVERAGE] $fileset_object] } {
    append switches "p"
  }
  if { [get_property [usf_aldec_getPropertyName SIMULATE.TOGGLE_COVERAGE] $fileset_object] } {
    append switches "t"
  }
  if { [get_property [usf_aldec_getPropertyName SIMULATE.ASSERTION_COVERAGE] $fileset_object] } {
    append switches "a"
  }
  if { [get_property [usf_aldec_getPropertyName SIMULATE.FSM_COVERAGE] $fileset_object] } {
    append switches "m"
  }

  if { $switches != "" } {
    lappend optionsList "-acdb -acdb_cov $switches"
  }
}

proc usf_aldec_appendCompilationCoverageOptions { _optionsList compiler } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties

  upvar $_optionsList optionsList
  set fileset_object [get_filesets $properties(simset)]

  # -------------- main options -------------

  set switches ""  

  if { [get_property [usf_aldec_getPropertyName COMPILE.STATEMENT_COVERAGE] $fileset_object] } {
    append switches "s"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.BRANCH_COVERAGE] $fileset_object] } {
    append switches "b"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.EXPRESSION_COVERAGE] $fileset_object] } {
    append switches "e"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.CONDITION_COVERAGE] $fileset_object] } {
    append switches "c"
  }
  if { ( $compiler == "acom" || $compiler == "vcom" ) && [get_property [usf_aldec_getPropertyName COMPILE.PATH_COVERAGE] $fileset_object] } {
    append switches "p"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.ASSERTION_COVERAGE] $fileset_object] } {
    append switches "a"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.FSM_COVERAGE] $fileset_object] } {
    append switches "m"
  }

  if { $switches != "" } {
    lappend optionsList "-coverage $switches"
  }

  # --------- additional options ---------------

  set switches ""

  if { [get_property [usf_aldec_getPropertyName COMPILE.ENABLE_EXPRESSIONS_ON_SUBPROGRAM_ARGUMENTS] $fileset_object] } {
    lappend switches "args"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.ENABLE_ATOMIC_EXPRESSIONS_IN_THE_CONDITIONAL_STATEMENTS] $fileset_object] } {
    lappend switches "implicit"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.ENABLE_THE_EXPRESSIONS_CONSISTING_OF_ONE_VARIABLE_ONLY] $fileset_object] } {
    lappend switches "onevar"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.ENABLE_THE_EXPRESSIONS_WITH_RELATIONAL_OPERATORS] $fileset_object] } {
    lappend switches "relational"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.ENABLE_THE_EXPRESSIONS_RETURNING_VECTORS] $fileset_object] } {
    lappend switches "vectors"
  }
  if { [get_property [usf_aldec_getPropertyName COMPILE.ENABLE_FSM_SEQUENCES_IN_FSM_COVERAGE] $fileset_object] } {
    lappend switches "fsmsequence"
  }

  if { $switches != "" } {
    lappend optionsList "-coverage_options [join $switches +]"
  }
}

proc usf_aldec_getSimulatorName {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  switch -- [get_property target_simulator [current_project]] {
    Riviera { return Riviera-PRO }
    ActiveHDL { return Active-HDL }
    default { error "Unknown target simulator" }
  }
}

proc usf_aldec_getLibraryPrefix {} {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  switch -- [get_property target_simulator [current_project]] {
    Riviera { return "riviera/" }
    ActiveHDL { return "activehdl/" }
    default { error "Unknown target simulator" }
  }
}

proc usf_aldec_get_origin_dir_path { _path } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable properties
  
  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {

    set useAbsolutePaths $properties(use_absolute_paths)
    if { [get_property target_simulator [current_project]] == "ActiveHDL" } {
	  set useAbsolutePaths 1
    }

    if { $useAbsolutePaths == 1 } {
	  return [ usf_resolve_file_path $_path ]
	}

    return $_path
  } else {
	if { [file pathtype $_path] == "relative" } {
	  return "\$origin_dir/$_path"
	} else {
	  return $_path
	}
  }
}

proc usf_init_vars {} {
  # Summary: initializes global namespace vars
  # Argument Usage:
  # Return Value:

	variable a_sim_cache_all_bd_files
	variable a_sim_cache_parent_comp_files
	variable compiledLibraries [ list ]
	variable localDesignLibraries [ list ]
	variable systemVerilogPackageLibraries [ list ]
	variable compileOrderFilesUniq [ list ]
	variable precompiledLibrary [ list ]
	variable a_sim_cache_lib_info
	variable a_sim_cache_lib_type_info
	variable a_shared_library_path_coln
	variable a_locked_ips
	variable a_custom_ips
	
	variable properties
	variable generateLaibraryMode
	variable userSetGlbl
	variable protocolInstcesList
	variable protoinstFilesList
	variable USE_VECTOR_RANGES 
	
	array unset a_sim_cache_all_bd_files
	array unset a_sim_cache_parent_comp_files
	array unset a_sim_cache_lib_info
	array unset a_sim_cache_lib_type_info
	array unset a_shared_library_path_coln
	array unset a_locked_ips
	array unset a_custom_ips

  set project                      [current_project]
  set properties(project_name)     [get_property "NAME" $project]
  set properties(project_dir)      [get_property "DIRECTORY" $project]
  set properties(is_managed)       [get_property "MANAGED_IP" $project]
  set properties(launch_directory) {}
  set properties(s_sim_top)        [get_property "TOP" [current_fileset -simset]]
  set properties(associatedLibrary) [get_property "DEFAULT_LIB" $project]
  
  set properties(b_compile_simmodels)       0
  set properties(l_simmodel_compile_order)  [list]
  set properties(s_simlib_dir)              {}
  set properties(b_int_export_source_files) 0
  set properties(s_gcc_bin_path)            {}
  set properties(s_sim_version)				{}
  set properties(b_int_compile_glbl)  0
  
  # launch_simulation tcl task args
  set properties(simset)           [current_fileset -simset]
  set properties(mode)             "behavioral"
  set properties(s_type)                {}
  set properties(only_generate_scripts) 0
  set properties(b_gui) 0
  set properties(s_comp_file)           {}
  set properties(use_absolute_paths)    0
  set properties(s_install_path)        {}
  set properties(s_lib_map_path)        {}
  set properties(batch_mode_enabled)    0
  set properties(s_int_os_type)         {}
  set properties(s_int_debug_mode)      0

	set properties(b_int_systemc_mode) 	1
	set properties(custom_sm_lib_dir)	{}
	set properties(sp_cpt_dir) {}
	set properties(sp_ext_dir) {}
	set properties(b_int_csim_compile_order) 0 
    set properties(b_int_sm_lib_ref_debug)    0
	set properties(b_contain_systemc_sources) 0
	set properties(b_contain_cpp_sources)     0
	set properties(b_contain_c_sources)       0
	set properties(b_contain_systemc_headers) 0	
	set properties(b_int_en_vitis_hw_emu_mode) 0
#    if { [ info exists ::env(XIL_ENABLE_VITIS_CODE_HOOKS) ] } {
#      set properties(b_int_en_vitis_hw_emu_mode) 1
#    }

  set properties(dynamic_repo_dir)        [get_property ip.user_files_dir [current_project]]
  set properties(ipstatic_dir)            [get_property sim.ipstatic.source_dir [current_project]]
  set properties(b_use_static_lib)        [get_property sim.ipstatic.use_precompiled_libs [current_project]]
  
  set properties(b_force_no_compile_glbl) [get_property "force_no_compile_glbl" [get_filesets $properties(simset)]] 

  set data_dir [rdi::get_data_dir -quiet -datafile "ip/xilinx"]
  set properties(ip_repository_path) [file normalize [file join $data_dir "ip/xilinx"]]

  set properties(s_tool_bin_path)    {}

  set properties(sp_tcl_obj)         {}
  set properties(b_extract_ip_sim_files) 0

  # fileset compile order
  variable l_compile_order_files     [list]
  variable designFiles               [list]

  # ip static libraries
  variable l_ip_static_libs          [list]

  # ip file extension types
  variable l_valid_ip_extns          [list]
  set l_valid_ip_extns               [list ".xci" ".bd" ".slx"]

  # hdl file extension types
  variable valid_hdl_extensions          [list]
  set valid_hdl_extensions               [list ".vhd" ".vhdl" ".vhf" ".vho" ".v" ".vf" ".verilog" ".vr" ".vg" ".vb" ".tf" ".vlog" ".vp" ".vm" ".vh" ".h" ".svh" ".sv" ".veo"]
 
  # data file extension types 
  variable s_data_files_filter
  set s_data_files_filter \
	  "FILE_TYPE == \"Data Files\" \
	|| FILE_TYPE == \"Memory File\" \
	|| FILE_TYPE == \"STATIC MEMORY FILE\" \
	|| FILE_TYPE == \"Memory Initialization Files\" \
	|| FILE_TYPE == \"CSV\" \
	|| FILE_TYPE == \"Coefficient Files\" \
	|| FILE_TYPE == \"Configuration Data Object\""

  # embedded file extension types 
  variable s_embedded_files_filter
  set s_embedded_files_filter        "FILE_TYPE == \"BMM\" || FILE_TYPE == \"ElF\""

  # non-hdl data files filter
  variable s_non_hdl_data_files_filter
  set s_non_hdl_data_files_filter \
               "FILE_TYPE != \"Verilog\"                      && \
                FILE_TYPE != \"SystemVerilog\"                && \
                FILE_TYPE != \"Verilog Header\"               && \
                FILE_TYPE != \"Verilog Template\"             && \
                FILE_TYPE != \"VHDL\"                         && \
                FILE_TYPE != \"VHDL 2008\"                    && \
                FILE_TYPE != \"VHDL 2019\"                    && \
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

  # simulation mode types
  variable a_sim_mode_types
  set a_sim_mode_types(behavioral)          {behav}
  set a_sim_mode_types(post-synthesis)      {synth}
  set a_sim_mode_types(post-implementation) {impl}
  set a_sim_mode_types(funcsim)             {func}
  set a_sim_mode_types(timesim)             {timing}

  set properties(s_flow_dir_key)            {behav}
  set properties(s_simulation_flow)         {behav_sim}
  set properties(s_netlist_mode)            {funcsim}

  # netlist file
  set properties(s_netlist_file)            {}

  # transaction generator
  set protoinstFilesList {}
  set USE_VECTOR_RANGES false
  
  xcs_set_common_param_vars
}

proc usf_create_options { simulator opts } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # create options
  usf_create_fs_options_spec $simulator $opts

  if { ![get_property IS_READONLY [current_project]] } {
    # simulation fileset objects
    foreach fileset_object [get_filesets -filter {FILESET_TYPE == SimulationSrcs}] {
      usf_set_fs_options $fileset_object $simulator $opts
    }
  }
}

proc usf_create_fs_options_spec { simulator opts } {
  # Summary:
  # Argument Usage:
  # Return Value:

  # create properties on the fileset object
  foreach { row } $opts  {
    set name  [lindex $row 0]
    set type  [lindex $row 1]
    set value [lindex $row 2]
    set desc  [lindex $row 3]

    # setup property name
    set prop_name "${simulator}.${name}"

    set prop_name [string tolower $prop_name]

    # is registered already?
    if { [usf_is_option_registered_on_simulator $prop_name $simulator] } {
      continue;
    }

    # is enum type?
    if { {enum} == $type } {
      set e_value   [lindex $value 0]
      set e_default [lindex $value 1]
      set e_values  [lindex $value 2]
      # create enum property
      create_property -name "${prop_name}" -type $type -description $desc -enum_values $e_values -default_value $e_default -class fileset -no_register
    } elseif { {file} == $type } {
      set f_extns   [lindex $row 4]
      set f_desc    [lindex $row 5]
      # create file property
      set v_default $value
      create_property -name "${prop_name}" -type $type -description $desc -default_value $v_default -file_types $f_extns -display_text $f_desc -class fileset -no_register
    } else {
      set v_default $value
      create_property -name "${prop_name}" -type $type -description $desc -default_value $v_default -class fileset -no_register
    }
  }
  return 0
}

proc usf_set_fs_options { fileset_object simulator opts } {
  # Summary:
  # Argument Usage:
  # Return Value:

  foreach { row } $opts  {
    set name  [lindex $row 0]
    set type  [lindex $row 1]
    set value [lindex $row 2]
    set desc  [lindex $row 3]

    set prop_name "${simulator}.${name}"

    # is registered already?
    if { [usf_is_option_registered_on_simulator $prop_name $simulator] } {
      continue;
    }

    # is enum type?
    if { {enum} == $type } {
      set value   [lindex $value 0]
      set e_default [lindex $value 1]
      set e_values  [lindex $value 2]
      set_property -name "${prop_name}" -value $value -objects ${fileset_object}
    } else {
      set v_default $value
      set_property -name "${prop_name}" -value $value -objects ${fileset_object}
    }
  }
  return 0
}

proc usf_is_option_registered_on_simulator { prop_name simulator } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set str_1 [string tolower $prop_name]
  # get registered options from simulator for the current simset
  foreach option_name [get_property "REGISTERED_OPTIONS" [get_simulators $simulator]] {
    set str_2 [string tolower $option_name]
    if { [string compare $str_1 $str_2] == 0 } {
      return true
    }
  }
  return false
}

proc usf_set_simulation_flow {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties

  set fileset_object [get_filesets $properties(simset)]
  set simulation_flow {unknown}
  set type_dir {timing}
  if { {behavioral} == $properties(mode) } {
    if { ({functional} == $properties(s_type)) || ({timing} == $properties(s_type)) } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-1 ERROR "Invalid simulation type '$properties(s_type)' specified. Please see 'simulate -help' for more details.\n"
      return 1
    }
    set simulation_flow "behav_sim"
    set properties(s_flow_dir_key) "behav"

    # set simulation and netlist mode on simset
    set_property sim_mode "behavioral" $fileset_object

  } elseif { {post-synthesis} == $properties(mode) } {
    if { ({functional} != $properties(s_type)) && ({timing} != $properties(s_type)) } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-2 ERROR "Invalid simulation type '$properties(s_type)' specified. Please see 'simulate -help' for more details.\n"
      return 1
    }
    set simulation_flow "post_synth_sim"
    if { {functional} == $properties(s_type) } {
      set type_dir "func"
    }
    set properties(s_flow_dir_key) "synth/${type_dir}"

    # set simulation and netlist mode on simset
    set_property sim_mode "post-synthesis" $fileset_object
    if { {functional} == $properties(s_type) } {
      set_property "NL.MODE" "funcsim" $fileset_object
    }
    if { {timing} == $properties(s_type) } {
      set_property "NL.MODE" "timesim" $fileset_object
    }
  } elseif { ({post-implementation} == $properties(mode)) || ({timing} == $properties(mode)) } {
    if { ({functional} != $properties(s_type)) && ({timing} != $properties(s_type)) } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-3 ERROR "Invalid simulation type '$properties(s_type)' specified. Please see 'simulate -help' for more details.\n"
      return 1
    }
    set simulation_flow "post_impl_sim"
    if { {functional} == $properties(s_type) } {
      set type_dir "func"
    }
    set properties(s_flow_dir_key) "impl/${type_dir}"

    # set simulation and netlist mode on simset
    set_property sim_mode "post-implementation" $fileset_object
    if { {functional} == $properties(s_type) } { set_property "NL.MODE" "funcsim" $fileset_object }
    if { {timing} == $properties(s_type) } { set_property "NL.MODE" "timesim" $fileset_object }
  } else {
    send_msg_id USF-[usf_aldec_getSimulatorName]-4 ERROR "Invalid simulation mode '$properties(mode)' specified. Please see 'simulate -help' for more details.\n"
    return 1
  }
  set properties(s_simulation_flow) $simulation_flow
  return 0
}

proc usf_extract_ip_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  if { ![get_property corecontainer.enable [current_project]] } {
    return
  }
  set properties(b_extract_ip_sim_files) [get_property extract_ip_sim_files [current_project]]
  if { $properties(b_extract_ip_sim_files) } {
    foreach ip [get_ips -all -quiet] {
      set xci_ip_name "${ip}.xci"
      set xcix_ip_name "${ip}.xcix"
      set xcix_file_path [get_property core_container [get_files -quiet -all ${xci_ip_name}]]
      if { {} != $xcix_file_path } {
        [catch {rdi::extract_ip_sim_files -of_objects [get_files -quiet -all ${xcix_ip_name}]} err]
      }
    }
  }
}

proc usf_set_sim_tcl_obj {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set comp_file $properties(s_comp_file)
  if { {} != $comp_file } {
    # -of_objects <full-path-to-ip-composite-file>
    set properties(sp_tcl_obj) [get_files -all -quiet [list "$comp_file"]]
    set properties(s_sim_top) [file root [file tail $properties(sp_tcl_obj)]]
  } else {
    set properties(sp_tcl_obj) [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]
    # set current simset
    if { {} == $properties(sp_tcl_obj) } {
      set properties(sp_tcl_obj) [current_fileset -simset]
    }
    set properties(s_sim_top) [get_property TOP [get_filesets $properties(sp_tcl_obj)]]
  }
  send_msg_id USF-[usf_aldec_getSimulatorName]-5 INFO "Simulation object is '$properties(sp_tcl_obj)'...\n"
  return 0
}

proc usf_write_design_netlist {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  # is behavioral?, return
  if { {behav_sim} == $properties(s_simulation_flow) } {
    return
  }
  set extn [usf_get_netlist_extn 1]

  # generate netlist
  set net_filename     [usf_get_netlist_filename];append net_filename "$extn"
  set sdf_filename     [usf_get_netlist_filename];append sdf_filename ".sdf"
  set net_file         [usf_file_normalize [file join $properties(launch_directory) $net_filename]]
  set sdf_file         [usf_file_normalize [file join $properties(launch_directory) $sdf_filename]]
  set netlist_cmd_args [usf_get_netlist_writer_cmd_args $extn]
  set sdf_cmd_args     [usf_get_sdf_writer_cmd_args]
  set design_mode      [get_property DESIGN_MODE [current_fileset]]

  # check run status
  switch -regexp -- $properties(s_simulation_flow) {
    {post_synth_sim} {
      if { {RTL} == $design_mode } {
        if { [get_param "project.checkRunResultsForUnifiedSim"] } {
          set synth_run [current_run -synthesis]
          set status [get_property "STATUS" $synth_run]
          if { ([regexp -nocase {^synth_design complete} $status] != 1) } {
            send_msg_id USF-[usf_aldec_getSimulatorName]-6 ERROR \
               "Synthesis results not available! Please run 'Synthesis' from the GUI or execute 'launch_runs <synth>' command from the Tcl console and retry this operation.\n"
            return 1
          }
        }
      }

      if { {RTL} == $design_mode } {
        set synth_run [current_run -synthesis]
        set netlist $synth_run 
        # is design for the current synth run already opened in memory?
        set synth_design [get_designs -quiet $synth_run]
        if { {} != $synth_design } {
          # design already opened, set it current
          current_design $synth_design
        } else {
          if { [catch {open_run $synth_run -name $netlist} open_error] } {
            #send_msg_id USF-[usf_aldec_getSimulatorName]-7 WARNING "open_run failed:$open_err"
          } else {
            current_design $netlist
          }
        }
      } elseif { {GateLvl} == $design_mode } {
        set netlist "rtl_1"
        # is design already opened in memory?
        set synth_design [get_designs -quiet $netlist]
        if { {} != $synth_design } {
          # design already opened, set it current
          current_design $synth_design
        } else {
          # open the design
          link_design -name $netlist
        }
      } else {
        send_msg_id USF-[usf_aldec_getSimulatorName]-8 ERROR "Unsupported design mode found while opening the design for netlist generation!\n"
        return 1
      }

      set design_in_memory [current_design]
      send_msg_id USF-[usf_aldec_getSimulatorName]-9 INFO "Writing simulation netlist file for design '$design_in_memory'..."
      # write netlist/sdf
      set wv_args "-nolib $netlist_cmd_args -file $net_file"
      if { {functional} == $properties(s_type) } {
        set wv_args "-mode funcsim $wv_args"
      } elseif { {timing} == $properties(s_type) } {
        set wv_args "-mode timesim $wv_args"
      }
      if { {.v} == $extn } {
        send_msg_id USF-[usf_aldec_getSimulatorName]-10 INFO "write_verilog $wv_args"
        eval "write_verilog $wv_args"
      } else {
        send_msg_id USF-[usf_aldec_getSimulatorName]-11 INFO "write_vhdl $wv_args"
        eval "write_vhdl $wv_args"
      }
      if { {timing} == $properties(s_type) } {
        send_msg_id USF-[usf_aldec_getSimulatorName]-12 INFO "Writing SDF file..."
        set ws_args "-mode timesim $sdf_cmd_args -file $sdf_file"
        send_msg_id USF-[usf_aldec_getSimulatorName]-13 INFO "write_sdf $ws_args"
        eval "write_sdf $ws_args"
      }
      set properties(s_netlist_file) $net_file
    }
    {post_impl_sim} {
      set impl_run [current_run -implementation]
      set netlist $impl_run
      if { [get_param "project.checkRunResultsForUnifiedSim"] } {
        set status [get_property "STATUS" $impl_run]
        if { ![get_property can_open_results $impl_run] } {
          send_msg_id USF-[usf_aldec_getSimulatorName]-14 ERROR \
             "Implementation results not available! Please run 'Implementation' from the GUI or execute 'launch_runs <impl>' command from the Tcl console and retry this operation.\n"
          return 1
        }
      }

      # is design for the current impl run already opened in memory?
      set impl_design [get_designs -quiet $impl_run]
      if { {} != $impl_design } {
        # design already opened, set it current
        current_design $impl_design
      } else {
        if { [catch {open_run $impl_run -name $netlist} open_err] } {
          #send_msg_id USF-[usf_aldec_getSimulatorName]-15 WARNING "open_run failed:$open_err"
        } else {
          current_design $impl_run
        }
      }

      set design_in_memory [current_design]
      send_msg_id USF-[usf_aldec_getSimulatorName]-16 INFO "Writing simulation netlist file for design '$design_in_memory'..."

      # write netlist/sdf
      set wv_args "-nolib $netlist_cmd_args -file $net_file"
      if { {functional} == $properties(s_type) } {
        set wv_args "-mode funcsim $wv_args"
      } elseif { {timing} == $properties(s_type) } {
        set wv_args "-mode timesim $wv_args"
      }
      if { {.v} == $extn } {
        send_msg_id USF-[usf_aldec_getSimulatorName]-17 INFO "write_verilog $wv_args"
        eval "write_verilog $wv_args"
      } else {
        send_msg_id USF-[usf_aldec_getSimulatorName]-18 INFO "write_vhdl $wv_args"
        eval "write_vhdl $wv_args"
      }
      if { {timing} == $properties(s_type) } {
        send_msg_id USF-[usf_aldec_getSimulatorName]-19 INFO "Writing SDF file..."
        set ws_args "-mode timesim $sdf_cmd_args -file $sdf_file"
        send_msg_id USF-[usf_aldec_getSimulatorName]-20 INFO "write_sdf $ws_args"
        eval "write_sdf $ws_args"
      }

      set properties(s_netlist_file) $net_file
    }
  }
  if { [file exist $net_file] } { send_msg_id USF-[usf_aldec_getSimulatorName]-21 INFO "Netlist generated:$net_file" }
  if { [file exist $sdf_file] } { send_msg_id USF-[usf_aldec_getSimulatorName]-22 INFO "SDF generated:$sdf_file" }
}

proc usf_xport_data_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  variable s_data_files_filter
  variable s_non_hdl_data_files_filter
  set tcl_obj $properties(sp_tcl_obj)
  if { [usf_is_ip $tcl_obj] } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-23 INFO "Inspecting IP design source files for '$properties(s_sim_top)'...\n"

    # export ip data files to run dir
    if { [get_param "project.copyDataFilesForSim"] } {
      set ip_filter "FILE_TYPE == \"IP\""
      set ip_name [file tail $tcl_obj]
      set data_files [list]
      set data_files [concat $data_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_data_files_filter]]
      # non-hdl data files 
      foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $s_non_hdl_data_files_filter] {
        if { [lsearch -exact [list_property -quiet $file] {IS_USER_DISABLED}] != -1 } {
          if { [get_property {IS_USER_DISABLED} $file] } {
            continue;
          }
        }
        lappend data_files $file
      }
      usf_export_data_files $data_files
    }
  } elseif { [usf_is_fileset $tcl_obj] } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-24 INFO "Inspecting design source files for '$properties(s_sim_top)' in fileset '$tcl_obj'...\n"
    # export all fileset data files to run dir
    if { [get_param "project.copyDataFilesForSim"] } {
      usf_export_fs_data_files $s_data_files_filter
    }
    # export non-hdl data files to run dir
    usf_export_fs_non_hdl_data_files
  } else {
    send_msg_id USF-[usf_aldec_getSimulatorName]-25 INFO "Unsupported object source: $tcl_obj\n"
    return 1
  }
}

proc usf_uniquify_cmd_str { cmd_strs } {
  # Summary: Removes exact duplicate files (same file path)
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

proc usf_get_compile_order_files { } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable l_compile_order_files
  return [usf_uniquify_cmd_str $l_compile_order_files]
}

proc usf_get_top_library { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  variable compileOrderFilesUniq 

  set flow    $properties(s_simulation_flow)
  set tcl_obj $properties(sp_tcl_obj)

  set src_mgmt_mode         [get_property "SOURCE_MGMT_MODE" [current_project]]
  set manual_compile_order  [expr {$src_mgmt_mode != "All"}]

  # was -of_objects <ip> specified?, fetch current fileset
  if { [usf_is_ip $tcl_obj] } {
    set tcl_obj [get_filesets $properties(simset)]
  }

  # 1. get the default top library set for the project
  set default_top_library $properties(associatedLibrary)

  # 2. get the library associated with the top file from the 'top_lib' property on the fileset
  set fs_top_library [get_property "TOP_LIB" [get_filesets $tcl_obj]]

  # 3. get the library associated with the last file in compile order
  set co_top_library {}
  if { ({behav_sim} == $flow) } {
    set filelist $compileOrderFilesUniq 
    if { [llength $filelist] > 0 } {
      set file_list [get_files -all [list "[lindex $filelist end]"]]
      if { [llength $file_list] > 0 } {
        set co_top_library [get_property "LIBRARY" [lindex $file_list 0]]
      }     
    }
  } elseif { ({post_synth_sim} == $flow) || ({post_impl_sim} == $flow) } {
    set file_list [get_files -quiet -compile_order sources -used_in synthesis_post -of_objects [get_filesets $tcl_obj]]
    if { [llength $file_list] > 0 } {
      set co_top_library [get_property "LIBRARY" [lindex $file_list end]]
    }
  }

  # 4. if default top library is set and the compile order file library is different
  #    than this default, return the compile order file library
  if { {} != $default_top_library } {
    # manual compile order, we just return the file set's top
    if { $manual_compile_order && ({} != $fs_top_library) } {
      return $fs_top_library
    }
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
  if { {} != $fs_top_library } {
    # manual compile order, we just return the file set's top
    if { $manual_compile_order } {
      return $fs_top_library
    }
    # compile order library is set and is different then the fileset
    if { ({} != $co_top_library) && ($fs_top_library != $co_top_library) } {
      return $co_top_library
    } else {
      # worst case (fileset library is set but compile order file library is empty or we failed to get the library for some reason)
      return $fs_top_library
    }
  }

  # 6. Both the default and fileset library are empty, return compile order library else xilinx default
  if { {} != $co_top_library } {
    return $co_top_library
  }

  return "xil_defaultlib"
}

proc usf_contains_vhdl { design_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties

  set flow $properties(s_simulation_flow)

  set b_vhdl_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {|}] 0]
    switch $type {
      {VHDL} -
      {VHDL 2008} -
      {VHDL 2019} {
        set b_vhdl_srcs 1
      }
    }
  }

  if { (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && (!$b_vhdl_srcs) } {
    set extn [file extension $properties(s_netlist_file)]
    if { {.vhd} == $extn } {
      set b_vhdl_srcs 1
    }
  }

  return $b_vhdl_srcs
}

proc usf_contains_verilog { design_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties

  set flow $properties(s_simulation_flow)

  set b_verilog_srcs 0
  foreach file $design_files {
    set type [lindex [split $file {|}] 0]
    switch $type {
      {VERILOG} {
        set b_verilog_srcs 1
      }
    }
  }

  if { [usf_glbl_dependency_for_xpm] } {
    if { !$b_verilog_srcs } {
      set b_verilog_srcs 1
    }
  }

  if { (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && (!$b_verilog_srcs) } {
    set extn [file extension $properties(s_netlist_file)]
    if { {.v} == $extn } {
      set b_verilog_srcs 1
    }
  }

  return $b_verilog_srcs
}

proc usf_glbl_dependency_for_xpm {} {

  foreach library [ getXpmLibraries ] {
    foreach file [rdi::get_xpm_files -library_name $library] {
      set filebase [file root [file tail $file]]
      # xpm_cdc core has depedency on glbl
      if { {xpm_cdc} == $filebase } {
        return 1
      }
    }
  }

  return 0
}

proc usf_is_fileset { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if {[regexp -nocase {^fileset_type} [rdi::get_attr_specs -quiet -object $tcl_obj -regexp .*FILESET_TYPE.*]]} {
    return 1
  }
  return 0
}

proc usf_append_define_generics { def_gen_list tool opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  set b_group_files [get_param "project.assembleFilesByLibraryForUnifiedSim"]

  foreach element $def_gen_list {
    set key_val_pair [split $element "="]
    set name [lindex $key_val_pair 0]
    set val  [lindex $key_val_pair 1]
    set str "+define+$name=" 
    if { $b_group_files } {    
      # escape '
      if { [regexp {'} $val] } {
        regsub -all {'} $val {\\'} val
      }
    }

    if { [string length $val] > 0 } {
	  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
        set str "$str$val"
      } else {
        set str "$str\"$val\""
      }
    }

    switch -regexp -- $tool {
      "vlog" { lappend opts "$str"  }
    }
  }
}

proc usf_append_generics { generic_list opts_arg } {
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

proc usf_compile_glbl_file { simulator b_load_glbl design_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set fileset_object      [get_filesets $properties(simset)]
  set target_lang [get_property "TARGET_LANGUAGE" [current_project]]
  set flow        $properties(s_simulation_flow)

  if { [ usf_contains_verilog $design_files ] } {
    if { $b_load_glbl } {
      return 1
    }
    return 0
  } elseif { [ usf_glbl_dependency_for_xpm ] } {
    if { $b_load_glbl } {
      return 1
    }
    return 0
  }

  # target lang is vhdl and glbl is added as top for post-implementation and post-synthesis and load glbl set (default)
  if { ((({VHDL} == $target_lang) || ({VHDL 2008} == $target_lang)) && (({post_synth_sim} == $flow) || ({post_impl_sim} == $flow)) && $b_load_glbl) } {
    return 1
  }
  
  
  if { $properties(b_int_compile_glbl) } {
    return 1
  }

  return 0
}

proc xcs_set_common_param_vars { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties

  set properties(b_force_compile_glbl) [get_param "project.forceCompileGlblForSimulation"]

  if { !$properties(b_force_compile_glbl) } {
    set properties(b_force_compile_glbl) [ get_property "force_compile_glbl" [get_filesets $properties(simset)] ]
  }
}

proc usf_copy_glbl_file {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set run_dir $properties(launch_directory)

  set target_glbl_file [usf_file_normalize [file join $run_dir "glbl.v"]]
  if { [file exists $target_glbl_file] } {
    return
  }

  set data_dir [rdi::get_data_dir -quiet -datafile verilog/src/glbl.v]
  set src_glbl_file [usf_file_normalize [file join $data_dir "verilog/src/glbl.v"]]

  if {[catch {file copy -force $src_glbl_file $run_dir} error_msg] } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-26 WARNING "Failed to copy glbl file '$src_glbl_file' to '$run_dir' : $error_msg\n"
  }
}

proc usf_create_do_file { simulator do_filename } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set fileset_object [current_fileset -simset]
  set top $::tclapp::aldec::common::helpers::properties(s_sim_top)
  set do_file [file join $properties(launch_directory) $do_filename]
  set fh_do 0
  if {[catch {open $do_file w} fh_do]} {
    send_msg_id USF-[usf_aldec_getSimulatorName]-27 ERROR "Failed to open file to write ($do_file)\n"
  } else {
    set time [get_property "RUNTIME" $fileset_object]
    puts $fh_do "run $time"
  }
  close $fh_do
}

proc usf_prepare_ip_for_simulation { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  #if { [regexp {^post_} $properties(s_simulation_flow)] } {
  #  return
  #}
  variable properties
  # list of block filesets and corresponding runs to launch
  set fileset_objects        [list]
  set runs_to_launch [list]
  # target object (fileset or ip)
  set target_obj $properties(sp_tcl_obj)
  if { [usf_is_fileset $target_obj] } {
    set fs $target_obj
    # add specified fileset (expected simulation fileset)
    lappend fileset_objects $fs
    # add linked source fileset
    if { {SimulationSrcs} == [get_property "FILESET_TYPE" [get_filesets $fs]] } {
      set src_set [get_property "SOURCE_SET" [get_filesets $fs]]
      if { {} != $src_set } {
        lappend fileset_objects $src_set
      }
    }
    # add block filesets
    set filter "FILESET_TYPE == \"BlockSrcs\""
    foreach blk_fileset_object [get_filesets -filter $filter] {
      lappend fileset_objects $blk_fileset_object
    }
    set ip_filter "FILE_TYPE == \"IP\""
    foreach fileset_object $fileset_objects {
      set fs_name [get_property "NAME" [get_filesets $fileset_object]]
      send_msg_id USF-[usf_aldec_getSimulatorName]-28 INFO "Inspecting fileset '$fs_name' for IP generation...\n"
      # get ip composite files
      foreach comp_file [get_files -quiet -of_objects [get_filesets $fileset_object] -filter $ip_filter] {
        usf_generate_comp_file_for_simulation $comp_file runs_to_launch
      }
    }
    # fileset contains embedded sources? generate mem files
    if { [usf_is_embedded_flow] } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-29 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
      generate_mem_files $properties(launch_directory)
    }
  } elseif { [usf_is_ip $target_obj] } {
    set comp_file $target_obj
    usf_generate_comp_file_for_simulation $comp_file runs_to_launch
  } else {
    send_msg_id USF-[usf_aldec_getSimulatorName]-30 ERROR "Unknown target '$target_obj'!\n"
  }
  # generate functional netlist  
  if { [llength $runs_to_launch] > 0 } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-31 INFO "Launching block-fileset run '$runs_to_launch'...\n"
    launch_runs $runs_to_launch

    foreach run $runs_to_launch {
      wait_on_run [get_property "NAME" [get_runs $run]]
    }
  }
  # update compile order
  if { {None} != [get_property "SOURCE_MGMT_MODE" [current_project]] } {
    foreach fs $fileset_objects {
      if { [usf_fs_contains_hdl_source $fs] } {
        update_compile_order -fileset [get_filesets $fs]
      }
    }
  }
}

proc usf_generate_mem_files_for_simulation { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties

  if { [usf_is_fileset $properties(sp_tcl_obj)] } {
    # fileset contains embedded sources? generate mem files
    if { [usf_is_embedded_flow] } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-32 INFO "Design contains embedded sources, generating MEM files for simulation...\n"
      generate_mem_files $properties(launch_directory)
    }
  }
}

proc usf_fs_contains_hdl_source { fs } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_valid_ip_extns
  variable valid_hdl_extensions

  set b_contains_hdl 0
  set tokens [split [find_top -fileset $fs -return_file_paths] { }]
  for {set i 0} {$i < [llength $tokens]} {incr i} {
    set top [string trim [lindex $tokens $i]];incr i
    set file [string trim [lindex $tokens $i]]
    if { ({} == $top) || ({} == $file) } { continue; }
    set extn [file extension $file]

    # skip ip's
    if { [lsearch -exact $l_valid_ip_extns $extn] >= 0 } { continue; }

    # check if any HDL sources present in fileset
    if { [lsearch -exact $valid_hdl_extensions $extn] >= 0 } {
      set b_contains_hdl 1
      break
    }
  }
  return $b_contains_hdl
}

proc usf_aldec_set_simulator_path {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties

  set bin_path  {}
  set tool_name {} 
  set path_sep  {;}

  if {$::tcl_platform(platform) == "unix"} { set path_sep {:} }
  set install_path $properties(s_install_path)
  send_msg_id USF-[usf_aldec_getSimulatorName]-33 INFO "Finding simulator installation...\n"

  switch -- [get_property target_simulator [current_project]] {
    Riviera {
      set tool_extn {.bat}
      if {$::tcl_platform(platform) == "unix"} { set tool_extn {} }
      set tool_name "../rungui";append tool_name ${tool_extn}
      if { $install_path == "" } {
        set install_path [get_param "simulator.rivieraInstallPath"] 
      }
    }
    ActiveHDL {
      set tool_extn {.exe}
      if {$::tcl_platform(platform) == "unix"} { set tool_extn {} }    
      set tool_name "avhdl";append tool_name ${tool_extn}
      if { $install_path == "" } {
        set install_path [get_param "simulator.activehdlInstallPath"] 
      }
    }
  }

  if { {} == $install_path } {
    set bin_path [usf_get_bin_path $tool_name $path_sep]
    if { {} == $bin_path } {
      if { $properties(only_generate_scripts) } {
        set bin_path {<specify-simulator-tool-path>}
        send_msg_id USF-[usf_aldec_getSimulatorName]-34 WARNING \
          "Simulator executable path could not be located. Please make sure to set the path in the generated scripts manually before executing these scripts.\n"
      } else {
        send_msg_id USF-[usf_aldec_getSimulatorName]-35 ERROR \
          "Failed to locate '$tool_name' executable in the shell environment 'PATH' variable. Please source the settings script included with the installation and retry this operation again.\n"
        # IMPORTANT - *** DONOT MODIFY THIS ***
        error "_SIM_STEP_RUN_EXEC_ERROR_"
        # IMPORTANT - *** DONOT MODIFY THIS ***
        return 1
      }
    } else {
      send_msg_id USF-[usf_aldec_getSimulatorName]-36 INFO "Using simulator executables from '$bin_path'\n"
    }
  } else {
    set install_path [usf_file_normalize [string map {\\ /} $install_path]]
    set install_path [string trimright $install_path {/}]
    set bin_path $install_path
    set tool_path [file join $install_path $tool_name]
    # Couldn't find it at install path, so try inserting /bin.
    # This is a bit roundabout with new variables so we don't change the
    # originals. If this doesn't work, we want the error messages to report
    # based on the originals.
    set tool_bin_path {}
    if { ![file exists $tool_path] } {
      set tool_bin_path [file join $install_path "bin" $tool_name]
      if { [file exists $tool_bin_path] } {
        set tool_path $tool_bin_path
        set bin_path [file join $install_path "bin"]
      }
    }
    if { [file exists $tool_path] && ![file isdirectory $tool_path] } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-37 INFO "Using simulator executables from '$tool_path'\n"
    } else {
      send_msg_id USF-[usf_aldec_getSimulatorName]-38 ERROR "Path to custom '$tool_name' executable program does not exist:$tool_path'\n"
    }
  }

  set properties(s_tool_bin_path) [string map {/ \\\\} $bin_path]
  if {$::tcl_platform(platform) == "unix"} {
    set properties(s_tool_bin_path) $bin_path
  }
}


proc usf_aldec_set_gcc_path {} {
  variable properties

  if { $properties(s_gcc_bin_path) != "" && [ file exists $properties(s_gcc_bin_path) ] } {
    return
  }

  set directoryPath [ file dirname $properties(s_tool_bin_path)]

  switch -- [get_property target_simulator [current_project]] {
    Riviera {
      if {$::tcl_platform(platform) == "unix"} {

        set gccPath [ file join $directoryPath "gcc_Linux" ]
        if { ![ file exists $gccPath ] } {
          set gccPath [ file join $directoryPath "gcc_Linux64" ]
        }
        set properties(s_gcc_bin_path) [ file join $gccPath "bin" ]
      } else {

        set properties(s_gcc_bin_path) [ file join $directoryPath "mingw" "bin" ]
      }
    }
    ActiveHDL {
      set properties(s_gcc_bin_path) [ file join $directoryPath "mingw" "bin" ]
    }
  }
}

proc usf_get_files_for_compilation { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  upvar $global_files_str_arg global_files_str

  set sim_flow $properties(s_simulation_flow)
 
  set design_files [list]
  if { ({behav_sim} == $sim_flow) } {
    set design_files [usf_get_files_for_compilation_behav_sim $global_files_str]
  } elseif { ({post_synth_sim} == $sim_flow) || ({post_impl_sim} == $sim_flow) } {
    set design_files [usf_get_files_for_compilation_post_sim $global_files_str]
  }
  return $design_files
}

proc getVersalCipsLibrary {} {

	set libraryLocation [getCompiledLibraryLocation]

	foreach libraryDirectory [ glob -nocomplain -directory $libraryLocation * ] {
        if { ![ file isdirectory $libraryDirectory ] } {
			continue
		}

		set libraryName [ file tail $libraryDirectory ]
	
		if { ![ regexp "^versal_cips_.*" $libraryName ] || [ regexp "^versal_cips_ps_vip_.*" $libraryName ] } {
			continue
		}

		foreach file [ glob -nocomplain -directory $libraryDirectory * ] {
			set fileExtension [ file extension $file ]
			if { {.o} == $fileExtension } {
				return $file
			}
		}
	}

	return ""
}


proc getLibraryVersion { _ipdef } {
  set ip_name [ lindex [ split $_ipdef ":" ] 2 ]
  set ip_version [ lindex [ split $_ipdef ":" ] 3 ]

  set ipNameVersion $ip_name  
  append ipNameVersion "_v"
  append ipNameVersion [ string map {. "_"} $ip_version ]

  return $ipNameVersion
}

proc findLibraryFile { _libarayName } {
  set libraryLocation [ getCompiledLibraryLocation ]

  foreach libraryDirectory [ glob -nocomplain -directory $libraryLocation * ] {
    if { ![ file isdirectory $libraryDirectory ] } {
      continue
    }

    set libraryName [ file tail $libraryDirectory ]
    if { [ string first $_libarayName $libraryName ] == -1 } {
      continue
    }

    foreach file [ glob -nocomplain -directory $libraryDirectory * ] {
      set fileExtension [ file extension $file ]
      if { {.o} == $fileExtension } {
        return $file
      }
    }
  }

  return ""
}

proc getZynqUltraLibrary {} {

  set libraryLocation [ getCompiledLibraryLocation ]

  set ip_objs [get_ips -all -quiet]
  foreach ip_obj $ip_objs {
    set ipdef [get_property -quiet IPDEF $ip_obj]
    set ip_name [ lindex [ split $ipdef ":" ] 2 ] 	
	set ipNameVersion [ getLibraryVersion $ipdef ]

	if { [ regexp "^zynq_ultra_ps_e.*" $ipNameVersion ] } {
	  set libraryFile [ findLibraryFile $ipNameVersion ]
	  if { $libraryFile != "" } {
        return $libraryFile
	  }

	  set libraryFile [ findLibraryFile $ip_name ]
	  if { $libraryFile != "" } {
        return $libraryFile
	  }
	} elseif { [ regexp "^zynq_ultra_ps_e_vip_.*" $ipNameVersion ] } {
	  set libraryFile [ findLibraryFile $ipNameVersion ]
	  if { $libraryFile != "" } {
        return $libraryFile
	  }

	  set libraryFile [ findLibraryFile $ip_name ]
	  if { $libraryFile != "" } {
        return $libraryFile
	  }
	}
  }

  return ""
}

proc usf_get_files_for_compilation_behav_sim { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable versalCips
  variable zynqUltra
  variable properties
  variable compiledLibraries
  variable systemVerilogPackageLibraries	
  variable l_compile_order_files
  
  set fs_obj [get_filesets $properties(simset)]
  
  upvar $global_files_str_arg global_files_str

  set files                 [list]
  set l_compile_order_files [list]
  set target_obj            $properties(sp_tcl_obj)
  set simset_obj            [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]
  set linked_src_set        [get_property "SOURCE_SET" $simset_obj]
  set target_lang           [get_property "TARGET_LANGUAGE" [current_project]]
  set src_mgmt_mode         [get_property "SOURCE_MGMT_MODE" [current_project]]

  # get global include file paths
  set incl_file_paths [list]
  set incl_files      [list]
  send_msg_id USF-[usf_aldec_getSimulatorName]-39 INFO "Finding global include files..."
  usf_get_global_include_files incl_file_paths incl_files

  set global_incl_files $incl_files
  set global_files_str [usf_get_global_include_file_cmdstr incl_files]

  # verilog incl dir's and verilog headers directory path if any
  send_msg_id USF-[usf_aldec_getSimulatorName]-40 INFO "Finding include directories and verilog header directory paths..."
  set include_directories_options [list]
  set unique_directories [list]

  foreach dir [concat [usf_get_include_dirs] [usf_get_verilog_header_paths] [getVipIncludeDirs] ] {
    if { [lsearch -exact $unique_directories $dir] == -1 } {
      lappend unique_directories $dir
      lappend include_directories_options "\"+incdir+$dir\""
    }
  }

    if { ( [ lsearch -exact $compiledLibraries "xilinx_vip" ] == -1 ) } {
		if { [ llength $systemVerilogPackageLibraries ] > 0 } {
			set incl_dir_opts "\\\"+incdir+[getVipIncludeDirs]\\\""
			foreach file [ getXilinxVipFiles ] {
				set fileType "SystemVerilog"
				set g_files $global_files_str
				set cmd_str [ getFileCmdStr $file $fileType true $g_files incl_dir_opts "" "xilinx_vip" ]

				if { {} != $cmd_str } {
					lappend files $cmd_str
					lappend l_compile_order_files $file
				}
			}
		}
	 } elseif { [ is_vip_ip_required ] } {
		set data_dir [rdi::get_data_dir -quiet -datafile xilinx_vip]
		set dir "${data_dir}/xilinx_vip/include"
		if { [lsearch -exact $unique_directories $dir] == -1 } {
			lappend unique_directories $dir
			lappend include_directories_options "\"+incdir+$dir\""
		}
	}

	set l_C_incl_dirs_opts     [list]
	set ststemCLibraryPaths ""
	set ststemCLibraryNames ""
	
	if { [ isSystemCEnabled ] } {
    set b_en_code true
    if { $b_en_code } {
      if { [usf_contains_C_files] } {
	  
        variable a_shared_library_path_coln
        foreach {key value} [array get a_shared_library_path_coln] {
          set shared_lib_name $key
          set lib_path        $value

          set incl_dir "$lib_path/include"
          if { $properties(b_compile_simmodels) } {
            set lib_name [ file tail $lib_path ]
            set lib_type [ file tail [ file dirname $lib_path ] ]

            if { ("protobuf" == $lib_name) || ("protected" == $lib_type) } {
              lappend l_C_incl_dirs_opts "-I \"$lib_path/include\""
              
              set ststemCLibraryPaths "$ststemCLibraryPaths -L $lib_path"
              set ststemCLibraryNames "$ststemCLibraryNames -l[file tail $lib_path]"
            } else {
              set incl_dir "simlibs/$lib_name/include"
              lappend l_C_incl_dirs_opts "-I \"$incl_dir\""

              set lib_path [ file join [ getLibraryDir ] $lib_name ]

              set ststemCLibraryPaths "$ststemCLibraryPaths -L $lib_path"
              set ststemCLibraryNames "$ststemCLibraryNames -l[file tail $lib_path]"
            }  

          } else {
            if { [file exists $incl_dir] } {
              if { !$properties(use_absolute_paths) } {
                # get relative file path for the compiled library
                set incl_dir "[usf_get_relative_file_path $incl_dir $properties(launch_directory)]"
              }
              #lappend l_C_incl_dirs_opts "\"+incdir+$incl_dir\""
              lappend l_C_incl_dirs_opts "-I \"$incl_dir\""

              set ststemCLibraryPaths "$ststemCLibraryPaths -L $lib_path"
              set ststemCLibraryNames "$ststemCLibraryNames -l[file tail $lib_path]"
            }
          }
        }

        foreach incl_dir [get_property "SYSTEMC_INCLUDE_DIRS" $fs_obj] {
          if { !$properties(use_absolute_paths) } {
            set incl_dir "[usf_get_relative_file_path $incl_dir $properties(launch_directory)]"
          }
          #lappend l_C_incl_dirs_opts "\"+incdir+$incl_dir\""
          lappend l_C_incl_dirs_opts "-I \"$incl_dir\""
		  
		  set ststemCLibraryPaths "$ststemCLibraryPaths -L $lib_path"
		  set ststemCLibraryNames "$ststemCLibraryNames -l[file tail $lib_path]"
        }

		if { $versalCips == 1 } {
			set versalCipsLibrary [ getVersalCipsLibrary ]
			if { $versalCipsLibrary != "" } {
				set ststemCLibraryNames "$ststemCLibraryNames $versalCipsLibrary"
			}
		}

		if { $zynqUltra == 1 } {
		  set zynqUltraLibrary [ getZynqUltraLibrary ]
		  if { $zynqUltraLibrary != "" } {
			set ststemCLibraryNames "$ststemCLibraryNames $zynqUltraLibrary"
		  }
		}

      }
    }
  }
	
  # prepare command line args for fileset files
  if { [usf_is_fileset $target_obj] } {
    set used_in_val "simulation"
    switch [get_property "FILESET_TYPE" [get_filesets $target_obj]] {
      "DesignSrcs"     { set used_in_val "synthesis" }
      "SimulationSrcs" { set used_in_val "simulation"}
      "BlockSrcs"      { set used_in_val "synthesis" }
    }

	set b_using_xpm_libraries false
    foreach library [ getXpmLibraries ] {
      foreach file [rdi::get_xpm_files -library_name $library] {
        set file_type "SystemVerilog"
        set g_files $global_files_str
        set cmd_str [usf_get_file_cmd_str $file $file_type $g_files include_directories_options true]

        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
		  set b_using_xpm_libraries true
        }
      }
    }

	if { $b_using_xpm_libraries } {
		if { [string equal -nocase [get_property "SIMULATOR_LANGUAGE" [current_project] ] "verilog"] == 1 } {
			# do not compile vhdl component file if simulator language is verilog
		} else {
			set xpm_library [ usf_get_common_xpm_library ]
			set common_xpm_vhdl_files [ usf_get_common_xpm_vhdl_files ]
			
			foreach file $common_xpm_vhdl_files {
				set file_type "VHDL"
				set g_files {}
				set cmd_str [ usf_get_file_cmd_str $file $file_type $g_files other_ver_opts true $xpm_library ]

				if { {} != $cmd_str } {
					lappend files $cmd_str
					lappend l_compile_order_files $file
				}
			}
		}
    }

    set b_add_sim_files 1
    # add files from block filesets
    if { {} != $linked_src_set } {
      if { [get_param project.addBlockFilesetFilesForUnifiedSim] } {
        usf_add_block_fs_files $global_files_str include_directories_options files l_compile_order_files
      }
    }
    # add files from simulation compile order
    if { {All} == $src_mgmt_mode } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-41 INFO "Fetching design files from '$target_obj'..."
      foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $target_obj]] {
        if { [usf_is_global_include_file $global_files_str $file] } { continue }
        set file_type [ get_property "FILE_TYPE" $file ]
        if { ![ is_hdl_type $file_type ] } { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
        set cmd_str [usf_get_file_cmd_str $file $file_type $g_files include_directories_options]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
      set b_add_sim_files 0
    } else {
      # add files from SOURCE_SET property value
      if { {} != $linked_src_set } {
        set srcset_obj [get_filesets $linked_src_set]
        if { {} != $srcset_obj } {
          send_msg_id USF-[usf_aldec_getSimulatorName]-42 INFO "Fetching design files from '$srcset_obj'...(this may take a while)..."
          foreach file [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $srcset_obj]] {
            set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
            set is_type_hdl [is_hdl_type $file_type]
            if { !$is_type_hdl } { continue }
            set g_files $global_files_str
            if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
            set cmd_str [usf_get_file_cmd_str $file $file_type $g_files include_directories_options]
            if { {} != $cmd_str } {
              lappend files $cmd_str
              lappend l_compile_order_files $file
            }
          }
        }
      }
    }

    if { $b_add_sim_files } {
      # add additional files from simulation fileset
      send_msg_id USF-[usf_aldec_getSimulatorName]-43 INFO "Fetching design files from '$properties(simset)'..."
      foreach file [get_files -quiet -all -of_objects [get_filesets $properties(simset)]] {
        set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
        set is_type_hdl [is_hdl_type $file_type]
        if { !$is_type_hdl } { continue }
        if { [get_property "IS_AUTO_DISABLED" [lindex [get_files -quiet -all [list "$file"]] 0]]} { continue }
        set g_files $global_files_str
        if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
        set cmd_str [usf_get_file_cmd_str $file $file_type $g_files include_directories_options]
        if { {} != $cmd_str } {
          lappend files $cmd_str
          lappend l_compile_order_files $file
        }
      }
    }
  } elseif { [usf_is_ip $target_obj] } {
    # prepare command line args for fileset ip files
    send_msg_id USF-[usf_aldec_getSimulatorName]-44 INFO "Fetching design files from IP '$target_obj'..."
    set ip_filename [file tail $target_obj]
    foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]] {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
      set is_type_hdl [is_hdl_type $file_type]
      if { !$is_type_hdl } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type $g_files include_directories_options]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  }
  
  if { [ isSystemCEnabled ] } {
    # design contain systemc sources?
    set simulator [ get_property target_simulator [ current_project ] ]
    set prefix_ref_dir false
    set sc_filter  "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC\")"
    set cpp_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"CPP\")"
    set c_filter   "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C\")"

    set sc_header_filter  "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"SystemC Header\")"
    set cpp_header_filter "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C Header Files\")"
    set c_header_filter   "(USED_IN_SIMULATION == 1) && (FILE_TYPE == \"C Header Files\")"

    # fetch systemc files
    set sc_files [usf_get_c_files $sc_filter $properties(b_int_csim_compile_order)]
    if { [llength $sc_files] > 0 } {
	
      set g_files {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      # fetch systemc include files (.h)
      set l_incl_dir [list]
      foreach dir [usf_get_c_incl_dirs $simulator $properties(launch_directory) [usf_get_boost_library_path] $sc_header_filter $properties(dynamic_repo_dir) false $properties(use_absolute_paths) $prefix_ref_dir] {
        addToUniqueList l_incl_dir "-I \"$dir\""
      }

      # dependency on cpp source headers
      # fetch cpp include files (.h)
      foreach dir [usf_get_c_incl_dirs $simulator $properties(launch_directory) [usf_get_boost_library_path] $cpp_header_filter $properties(dynamic_repo_dir) false $properties(use_absolute_paths) $prefix_ref_dir] {
        addToUniqueList l_incl_dir "-I \"$dir\""
      }

      # append simulation model libraries
      foreach C_incl_dir $l_C_incl_dirs_opts {
        addToUniqueList l_incl_dir $C_incl_dir
      }

      foreach file $sc_files {
        set file_extn [file extension $file]
        if { {.h} == $file_extn } {
          continue
        }
        # set flag
        if { !$properties(b_contain_systemc_sources) } {
          set properties(b_contain_systemc_sources) true
        }
          
        # is dynamic? process
        set used_in_values [get_property "USED_IN" [lindex [get_files -quiet -all [list "$file"]] 0]]
        if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
          set file_type "SystemC"
          set cmd_str [usf_get_file_cmd_str_c $file $file_type false $g_files l_dummy_incl_dirs_opts l_incl_dir $ststemCLibraryPaths $ststemCLibraryNames]
          if { {} != $cmd_str } {
            lappend files $cmd_str
            lappend compile_order_files $file
          }
        }
      }
    }

    # fetch cpp files
    set cpp_files [usf_get_c_files $cpp_filter $properties(b_int_csim_compile_order)]
    if { [llength $cpp_files] > 0 } {
      set g_files {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      # fetch systemc include files (.h)
      set l_incl_dir [list]
      foreach dir [usf_get_c_incl_dirs $simulator $properties(launch_directory) [usf_get_boost_library_path] $cpp_header_filter $properties(dynamic_repo_dir) false $properties(use_absolute_paths) $prefix_ref_dir] {
        lappend l_incl_dir "-I \"$dir\""
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
        set used_in_values [get_property "USED_IN" [lindex [get_files -quiet -all [list "$file"]] 0]]
        # is HLS C source?
        if { [lsearch -exact $used_in_values "c_source"] != -1 } {
          continue
        }
        # set flag
        if { !$properties(b_contain_cpp_sources) } {
          set properties(b_contain_cpp_sources) true
        }
        # is dynamic? process
        if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
          set file_type "CPP"
          set cmd_str [usf_get_file_cmd_str_c $file $file_type false $g_files l_dummy_incl_dirs_opts l_incl_dir $ststemCLibraryPaths $ststemCLibraryNames]
          if { {} != $cmd_str } {
            lappend files $cmd_str
            lappend compile_order_files $file
          }
        }
      }
    }

    # fetch c files
    set c_files [usf_get_c_files $c_filter $properties(b_int_csim_compile_order)]
    if { [llength $c_files] > 0 } {
      set g_files {}
      #send_msg_id exportsim-Tcl-024 INFO "Finding SystemC files..."
      # fetch systemc include files (.h)
      set l_incl_dir [list]
      foreach dir [usf_get_c_incl_dirs $simulator $properties(launch_directory) [usf_get_boost_library_path] $c_header_filter $properties(dynamic_repo_dir) false $properties(use_absolute_paths) $prefix_ref_dir] {
        lappend l_incl_dir "-I \"$dir\""
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
        set used_in_values [get_property "USED_IN" [lindex [get_files -quiet -all [list "$file"]] 0]]
        # is HLS C source?
        if { [lsearch -exact $used_in_values "c_source"] != -1 } {
          continue
        }
        # set flag
        if { !$properties(b_contain_c_sources) } {
          set properties(b_contain_c_sources) true
        }
        # is dynamic? process
        if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
          set file_type "C"
          set cmd_str [usf_get_file_cmd_str_c $file $file_type false $g_files l_dummy_incl_dirs_opts l_incl_dir $ststemCLibraryPaths $ststemCLibraryNames]
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

proc getLibraryDir { } {
  set libraryDir [ string tolower [ get_property target_simulator [ current_project ] ] ]
  append libraryDir "_lib"
  
  return $libraryDir
}

proc usf_get_files_for_compilation_post_sim { global_files_str_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  variable l_compile_order_files
  upvar $global_files_str_arg global_files_str

  set files         [list]
  set l_compile_order_files [list]
  set netlist_file  $properties(s_netlist_file)
  set target_obj    $properties(sp_tcl_obj)
  set target_lang   [get_property "TARGET_LANGUAGE" [current_project]]
  set src_mgmt_mode [get_property "SOURCE_MGMT_MODE" [current_project]]

  # get global include file paths
  set incl_file_paths [list]
  set incl_files      [list]
  usf_get_global_include_files incl_file_paths incl_files

  set global_incl_files $incl_files
  set global_files_str [usf_get_global_include_file_cmdstr incl_files]

  # verilog incl dir's and verilog headers directory path if any
  set include_directories_options [list]
  set unique_directories [list]
  foreach dir [concat [usf_get_include_dirs] [usf_get_verilog_header_paths] [getVipIncludeDirs]] {
    if { [lsearch -exact $unique_directories $dir] == -1 } {
      lappend unique_directories $dir
      lappend include_directories_options "\"+incdir+$dir\""
    }
  }

  if { {} != $netlist_file } {
    set file_type "Verilog"
    if { {.vhd} == [file extension $netlist_file] } {
      set file_type "VHDL"
    }
    set cmd_str [usf_get_file_cmd_str $netlist_file $file_type {} include_directories_options]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend l_compile_order_files $netlist_file
    }
  }

  # add testbench files if any
  #set vhdl_filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"VHDL\" || FILE_TYPE == \"VHDL 2008\")"
  #foreach file [usf_get_testbench_files_from_ip $vhdl_filter] {
  #  if { [lsearch -exact [list_property -quiet $file] {FILE_TYPE}] == -1 } {
  #    continue;
  #  }
  #  #set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
  #  set file_type [get_property "FILE_TYPE" $file]
  #  set cmd_str [usf_get_file_cmd_str $file $file_type {} include_directories_options]
  #  if { {} != $cmd_str } {
  #    lappend files $cmd_str
  #    lappend l_compile_order_files $file
  #  }
  #}
  ##set verilog_filter "USED_IN_TESTBENCH == 1 && FILE_TYPE == \"Verilog\" && FILE_TYPE == \"Verilog Header\""
  #set verilog_filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"Verilog\" || FILE_TYPE == \"SystemVerilog\")"
  #foreach file [usf_get_testbench_files_from_ip $verilog_filter] {
  #  if { [lsearch -exact [list_property -quiet $file] {FILE_TYPE}] == -1 } {
  #    continue;
  #  }
  #  #set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
  #  set file_type [get_property "FILE_TYPE" $file]
  #  set cmd_str [usf_get_file_cmd_str $file $file_type {} include_directories_options]
  #  if { {} != $cmd_str } {
  #    lappend files $cmd_str
  #    lappend l_compile_order_files $file
  #  }
  #}

  # prepare command line args for fileset files
  if { [usf_is_fileset $target_obj] } {

    # 851957 - if simulation and design source file tops are same (no testbench), skip adding simset files. Just pass the netlist above.
    set src_fs_top [get_property top [current_fileset]]
    set sim_fs_top [get_property top [get_filesets $properties(simset)]]
    if { $src_fs_top == $sim_fs_top } {
      return $files
    }

    # add additional files from simulation fileset
    set simset_files [get_files -compile_order sources -used_in synthesis_post -of_objects [get_filesets $properties(simset)]]
    foreach file $simset_files {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
      set is_type_hdl [is_hdl_type $file_type]
      if { !$is_type_hdl } { continue }
      #if { [get_property "IS_AUTO_DISABLED" [lindex [get_files -quiet -all [list "$file"]] 0]]} { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type $g_files include_directories_options]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  } elseif { [usf_is_ip $target_obj] } {
    # prepare command line args for fileset ip files
    set ip_filename [file tail $target_obj]
    foreach file [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_filename]] {
      set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
      set is_type_hdl [is_hdl_type $file_type]
      if { !$is_type_hdl } { continue }
      set g_files $global_files_str
      if { ({VHDL} == $file_type) || ({VHDL} == $file_type) } { set g_files {} }
      set cmd_str [usf_get_file_cmd_str $file $file_type $g_files include_directories_options]
      if { {} != $cmd_str } {
        lappend files $cmd_str
        lappend l_compile_order_files $file
      }
    }
  }
  return $files
}

proc usf_add_block_fs_files { global_files_str include_directories_options_arg files_arg compile_order_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $include_directories_options_arg include_directories_options
  upvar $files_arg files
  upvar $compile_order_files_arg compile_order_files

  set vhdl_filter "FILE_TYPE == \"VHDL\" || FILE_TYPE == \"VHDL 2008\" || FILE_TYPE == \"VHDL 2019\""
  foreach file [usf_get_files_from_block_filesets $vhdl_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
    set cmd_str [usf_get_file_cmd_str $file $file_type {} include_directories_options]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend compile_order_files $file
    }
  }
  set verilog_filter "FILE_TYPE == \"Verilog\" || FILE_TYPE == \"SystemVerilog\""
  foreach file [usf_get_files_from_block_filesets $verilog_filter] {
    set file_type [get_property "FILE_TYPE" [lindex [get_files -quiet -all [list "$file"]] 0]]
    set cmd_str [usf_get_file_cmd_str $file $file_type $global_files_str include_directories_options]
    if { {} != $cmd_str } {
      lappend files $cmd_str
      lappend compile_order_files $file
    }
  }
}

proc usf_is_global_include_file { global_files_str file_to_find } {
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

proc usf_launch_script { step } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set extn [usf_get_script_extn]
  set scr_file ${step}$extn
  set run_dir $properties(launch_directory)

  set shell_script_file [usf_file_normalize [file join $run_dir $scr_file]]
  usf_make_file_executable $shell_script_file

  if { $properties(only_generate_scripts) } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-45 INFO "Script generated:[usf_file_normalize [file join $run_dir $scr_file]]"
    return 0
  }

  set b_wait 0
  if { $properties(batch_mode_enabled) } {
    set b_wait 1 
  }
  set faulty_run 0
  set cwd [pwd]
  cd $::tclapp::aldec::common::helpers::properties(launch_directory)
  send_msg_id USF-[usf_aldec_getSimulatorName]-46 INFO "Executing '[string toupper $step]' step in '$run_dir'"
  set results_log {}
  switch $step {
    {compile} -
    {elaborate} {
      if {[catch {rdi::run_program $scr_file} error_log]} {
        set faulty_run 1
      }
      # check errors
      if { [usf_aldec_check_errors $step results_log] } {
        set faulty_run 1
      }
    }
    {simulate} {
      set retval 0
      set error_log {}
      if { $b_wait } {
        set retval [catch {rdi::run_program $scr_file} error_log]
      } else {
        set retval [catch {rdi::run_program -no_wait $scr_file} error_log]
      }
      if { $retval } {
	    [catch { send_msg_id USF-[usf_aldec_getSimulatorName]-47 ERROR "Failed to launch $scr_file:$error_log\n" }]
        set faulty_run 1
      }
    }
  }
  cd $cwd

  if { $faulty_run } {
    [catch {send_msg_id USF-[usf_aldec_getSimulatorName]-48 ERROR "'$step' step failed with error(s). Please check the Tcl console output or '$results_log' file for more information.\n"}]
    # IMPORTANT - *** DONOT MODIFY THIS ***
    error "_SIM_STEP_RUN_EXEC_ERROR_"
    # IMPORTANT - *** DONOT MODIFY THIS ***
    return 1
  }
  return 0
}

proc usf_write_shell_step_fn { fh } {
  # Summary:
  # Argument Usage:
  # Return Value:

  puts $fh "ExecStep()"
  puts $fh "\{"
  puts $fh "\"\$@\""
  puts $fh "RETVAL=\$?"
  puts $fh "if \[ \$RETVAL -ne 0 \]"
  puts $fh "then"
  puts $fh "exit \$RETVAL"
  puts $fh "fi"
  puts $fh "\}"
}

proc usf_resolve_uut_name { uut_arg } {
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

proc usf_get_script_extn {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set scr_extn ".bat"
  if {$::tcl_platform(platform) == "unix"} {
    set scr_extn ".sh"
  }
  return $scr_extn
}

proc usf_make_file_executable { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if {$::tcl_platform(platform) == "unix"} {
    if {[catch {exec chmod a+x $file} error_msg] } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-96 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
    }
  } else {
    if {[catch {exec attrib /D -R $file} error_msg] } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-96 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
    }
  }
}

proc getSimulatorVersion {} {
	variable properties
	
	switch -- [ get_property target_simulator [ current_project ] ] {
		Riviera {
			set tool_extn {.bat}		
			if { $::tcl_platform(platform) == "unix" } {
				set tool_extn {}
			}

			set vsimsa [file join $properties(s_tool_bin_path) "../runvsimsa$tool_extn"]
			if { [ file isfile $vsimsa ] } {
				set in [open "| \"$vsimsa\" -version"]
				set resultExe [read $in]
				close $in

				if { $resultExe != "" } {
					regexp -nocase {(\d+.)+} $resultExe version
					return [ string trim $version ]
				}
			}	
		}
		ActiveHDL {
			set vsimsa [file join $properties(s_tool_bin_path) vsim.exe ]
			set resultExe ""

			catch { set resultExe [ exec $vsimsa -version ] } 

			if { $resultExe != "" } {
				regexp -nocase {(\d+.)+} $resultExe version
				return [ string trim $version ]
			}
		}
	}

	return ""
}

proc usf_aldec_get_platform {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties

  switch -- [get_property target_simulator [current_project]] {
    Riviera {
      set tool_extn {.bat}
      if { $::tcl_platform(platform) == "unix" } { set tool_extn {} }
      set vsimsa [file join $properties(s_tool_bin_path) "../runvsimsa$tool_extn"]
      if { [file isfile $vsimsa] } {
        set in [open "| \"$vsimsa\" -version"]
        set data [read $in]
        close $in
        switch -regexp -- $data {
          "built for Windows " { return "win32" }
          "built for Windows64" { return "win64" }
          "built for Linux " { return "lnx32" }
          "built for Linux64" { return "lnx64" }
        }
      }
    }
    ActiveHDL {
      set avhdlXml [file join $properties(s_tool_bin_path) avhdl.xml]
      if { [file isfile $avhdlXml] } {
        set in [open $avhdlXml r]
        while { ![eof $in] } {
          gets $in line
          if { [regexp {UserConfigPath.+\\32-bit\\.+} $line] } {
            return "win32"
          } elseif { [regexp {UserConfigPath.+\\64-bit\\.+} $line] } {
            return "win64"
          }
        }
        close $in
      }
    }
  }
  
  send_msg_id USF-[usf_aldec_getSimulatorName]-49 WARNING "Failed to detect whether 32- or 64-bit version of [usf_aldec_getSimulatorName] is installed.\n"

  set fileset_object [get_filesets $properties(simset)]
  set platform {}
  set os $::tcl_platform(platform)
  set b_32_bit [get_property 32bit $fileset_object]
  if { {windows} == $os } {
    set platform "win64"
    if { $b_32_bit } {
      set platform "win32"
    }
  }

  if { {unix} == $os } {
    set platform "lnx64"
    if { $b_32_bit } {
      set platform "lnx32"
    }
  }
  return $platform
}

proc usf_is_axi_bfm_ip {} {
  # Summary: Finds VLNV property value for the IP and checks to see if the IP is AXI_BFM
  # Argument Usage:
  # Return Value:
  # true (1) if specified IP is axi_bfm, false (0) otherwise

  foreach ip [get_ips -all -quiet] {
    set ip_def [lindex [split [get_property "IPDEF" [get_ips -all -quiet $ip]] {:}] 2]
    set ip_def_obj [get_ipdefs -quiet -regexp .*${ip_def}.*]
    #puts ip_def_obj=$ip_def_obj
    if { {} != $ip_def_obj } {
      set value [get_property "VLNV" $ip_def_obj]
      #puts is_axi_bfm_ip=$value
      if { ([regexp -nocase {axi_bfm} $value]) || ([regexp -nocase {processing_system7} $value]) } {
        return 1
      }
    }
  }
  return 0
}

proc usf_get_simulator_lib_for_bfm {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { [usf_aldec_get_vivado_version] >= 2017.1 } {
    return
  }

  set simulator_lib {}
  set xil           $::env(XILINX_VIVADO)
  set path_sep      {;}
  set lib_extn      {.dll}
  set platform      [::tclapp::aldec::common::helpers::usf_aldec_get_platform]

  if {$::tcl_platform(platform) == "unix"} { set path_sep {:} }
  if {$::tcl_platform(platform) == "unix"} { set lib_extn {.so} }

  set lib_name "libxil_riviera"; append lib_name $lib_extn

  if { {} != $xil } {
    append platform ".o"
    set lib_path {}
    send_msg_id USF-[usf_aldec_getSimulatorName]-50 INFO "Finding simulator library from 'XILINX_VIVADO'..."
    foreach path [split $xil $path_sep] {
      set file [usf_file_normalize [file join $path "lib" $platform $lib_name]]
      if { [file exists $file] } {
        send_msg_id USF-[usf_aldec_getSimulatorName]-51 INFO "Using library:'$file'"
        set simulator_lib $file
        break
      } else {
        send_msg_id USF-[usf_aldec_getSimulatorName]-52 WARNING "Library not found:'$file'"
      }
    }
  } else {
    send_msg_id USF-[usf_aldec_getSimulatorName]-53 ERROR "Environment variable 'XILINX_VIVADO' is not set!"
  }

  if { $simulator_lib == {} } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-54 ERROR "Failed to locate simulator library from 'XILINX' environment variable."
  }

  return $simulator_lib
}
}

#
# Low level helper procs
# 
namespace eval ::tclapp::aldec::common::helpers {
proc usf_get_netlist_extn { warning } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties

  set extn {.v}
  set target_lang [get_property "TARGET_LANGUAGE" [current_project]]
  if { {VHDL} == $target_lang } {
    set extn {.vhd}
  }
  
  if { (({VHDL} == $target_lang) && ({timing} == $properties(s_type))) } {
    set extn {.v}
    if { $warning } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-55 INFO "The target language is set to VHDL, it is not supported for simulation type '$properties(s_type)', using Verilog instead.\n"
    }
  }
  return $extn
}

proc usf_get_netlist_filename { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set filename $properties(s_sim_top)
  switch -regexp -- $properties(s_simulation_flow) {
    {behav_sim} { set filename [append filename "_behav"] }
    {post_synth_sim} -
    {post_impl_sim} {
      switch -regexp -- $properties(s_type) {
        {functional} { set filename [append filename "_func"] }
        {timing} {set filename [append filename "_time"] }
      }
    }
  }
  switch -regexp -- $properties(s_simulation_flow) {
    {post_synth_sim} { set filename [append filename "_synth"] }
    {post_impl_sim}  { set filename [append filename "_impl"] }
  }
  return $filename
}

proc usf_export_data_files { data_files } {
  # Summary: 
  # Argument Usage:
  # Return Value:

  variable properties
  variable l_target_simulator
  set export_dir $properties(launch_directory)
  if { [llength $data_files] > 0 } {
    set data_files [usf_remove_duplicate_files $data_files]
    foreach file $data_files {
      set extn [file extension $file]
	  set filename [file tail $file]
      switch -- $extn {
        {.c} -
        {.zip} -
        {.hwh} -
        {.hwdef} -
        {.xml} {
		  if { {} != [usf_cache_result {usf_get_top_ip_filename $file}] } {
            if { [regexp {_addr_map.xml} ${filename}] } {
              # keep these files
            } else {
              continue
            }
          } else {
            # skip other c files
            if { {.c} == $extn } { continue }
          }
        }
      }
      set target_file [file join $export_dir [file tail $file]]
      if { [get_param project.enableCentralSimRepo] } {
        set mem_init_dir [usf_file_normalize [file join $properties(dynamic_repo_dir) "mem_init_files"]]
        set data_file [extract_files -force -no_paths -files [list "$file"] -base_dir $mem_init_dir]
        if {[catch {file copy -force $data_file $export_dir} error_msg] } {
          send_msg_id USF-[usf_aldec_getSimulatorName]-56 WARNING "Failed to copy file '$data_file' to '$export_dir' : $error_msg\n"
        } else {
          send_msg_id USF-[usf_aldec_getSimulatorName]-57 INFO "Exported '$target_file'\n"
        }
      } else {
        set data_file [extract_files -force -no_paths -files [list "$file"] -base_dir $export_dir]
        send_msg_id USF-[usf_aldec_getSimulatorName]-58 INFO "Exported '$target_file'\n"
      }
    }
  }
}

proc usf_export_fs_data_files { filter } {
  variable properties

  set data_files [list]
  
  foreach ip_obj [ get_ips -quiet -all ] {
    set data_files [ concat $data_files [ get_files -all -quiet -of_objects $ip_obj -filter $filter ] ]
  }

  set filesets [list]
  lappend filesets [ get_filesets -filter "FILESET_TYPE == \"BlockSrcs\"" ]
  lappend filesets [ current_fileset -srcset ]
  lappend filesets [ get_filesets $properties(simset) ]

  foreach fs_obj $filesets {
    set data_files [ concat $data_files [ get_files -all -quiet -of_objects $fs_obj -filter $filter ] ]
  }
  
  usf_export_data_files $data_files
}

proc usf_export_fs_non_hdl_data_files {} {
  # Summary: Copy fileset IP data files to output directory
  # Argument Usage:
  # Return Value:

  variable properties
  variable s_non_hdl_data_files_filter

  set fileset_object [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]
  set data_files [list]
  foreach file [get_files -all -quiet -of_objects [get_filesets $fileset_object] -filter $s_non_hdl_data_files_filter] {
    # skip user disabled (if the file supports is_user_disabled property
    if { [lsearch -exact [list_property -quiet $file] {IS_USER_DISABLED}] != -1 } {
      if { [get_property {IS_USER_DISABLED} $file] } {
        continue;
      }
    }
    lappend data_files $file
  }
  usf_export_data_files $data_files
}

proc usf_get_files_from_block_filesets { filter_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set file_list [list]
  set filter "FILESET_TYPE == \"BlockSrcs\""
  set used_in_val "simulation"
  set fileset_objects [get_filesets -filter $filter]
  if { [llength $fileset_objects] > 0 } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-59 INFO "Finding block fileset files..."
    foreach fileset_object $fileset_objects {
      set fs_name [get_property "NAME" $fileset_object]
      send_msg_id USF-[usf_aldec_getSimulatorName]-60 INFO "Inspecting fileset '$fs_name' for '$filter_type' files...\n"
      #set files [usf_remove_duplicate_files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fileset_object] -filter $filter_type]]
      set files [get_files -quiet -compile_order sources -used_in $used_in_val -of_objects [get_filesets $fileset_object] -filter $filter_type]
      if { [llength $files] == 0 } {
        send_msg_id USF-[usf_aldec_getSimulatorName]-61 INFO "No files found in '$fs_name'\n"
        continue
      } else {
        foreach file $files {
          lappend file_list $file
        }
      }
    }
  }
  return $file_list
}

proc usf_remove_duplicate_files { compile_order_files } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set file_list [list]
  set compile_order [list]
  foreach file $compile_order_files {
    set normalized_file_path [usf_file_normalize [string map {\\ /} $file]]
    if { [lsearch -exact $file_list $normalized_file_path] == -1 } {
      lappend file_list $normalized_file_path
      lappend compile_order $file
    }
  }
  return $compile_order
}

proc usf_get_include_dirs { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set dir_names [list]
  set tcl_obj $properties(sp_tcl_obj)
  set incl_dirs [list]
  set incl_dir_str {}
  if { [usf_is_ip $tcl_obj] } {
    set incl_dir_str [usf_get_incl_dirs_from_ip $tcl_obj]
    set incl_dirs [split $incl_dir_str "|"]
  } else {
    #puts "DEBUG:" 
    #set temp [get_property "INCLUDE_DIRS" [get_filesets $tcl_obj]]
    #puts $temp
    set incl_dir_str [usf_resolve_incl_dir_property_value [get_property "INCLUDE_DIRS" [get_filesets $tcl_obj]]]
    set incl_prop_dirs [split $incl_dir_str "|"]

    # include dirs from design source set
    set linked_src_set [get_property "SOURCE_SET" [get_filesets $tcl_obj]]
    if { {} != $linked_src_set } {
      set src_fileset_object [get_filesets $linked_src_set]
      set dirs [usf_resolve_incl_dir_property_value [get_property "INCLUDE_DIRS" [get_filesets $src_fileset_object]]]
      foreach dir [split $dirs "|"] {
        if { [lsearch -exact $incl_prop_dirs $dir] == -1 } {
          lappend incl_prop_dirs $dir
        }
      }
    }

    foreach dir $incl_prop_dirs {
      if { $properties(use_absolute_paths) } {
        set dir "[usf_resolve_file_path $dir]"
      } else {
        set dir "[usf_aldec_get_origin_dir_path [usf_get_relative_file_path $dir $properties(launch_directory)]]"
      }
      lappend incl_dirs $dir
    }
  }
  foreach vh_dir $incl_dirs {
    set vh_dir [string trim $vh_dir {\{\}}]
    lappend dir_names $vh_dir
  }
  return [lsort -unique $dir_names]
}

proc usf_get_verilog_header_paths {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set simset_obj     [get_filesets $properties(simset)]
  set include_paths  [list]
  # 1. get paths for verilog header files (.vh, .h)
  usf_get_header_include_paths include_paths 
  # 2. add include dirs if any
  foreach dir [usf_get_include_dirs] {
    lappend include_paths $dir
  }
  # 3. uniquify paths (its quite possible that files marked with global include can be a "VERILOG_HEADER' as well collected in step 1)
  set final_unique_paths  [list]
  set incl_header_paths   [list]
  foreach path $include_paths {
    if { [lsearch -exact $final_unique_paths $path] == -1 } {
      lappend incl_header_paths $path
      lappend final_unique_paths $path
    }
  }
  return $incl_header_paths
}

proc usf_get_header_include_paths { incl_header_paths_arg } {
  upvar $incl_header_paths_arg incl_header_paths

  usf_add_unique_incl_paths incl_header_paths
}

proc usf_add_unique_incl_paths { incl_header_paths_arg } {
  variable properties
  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_all_bd_files

  upvar $incl_header_paths_arg incl_header_paths

  set unique_paths   [list]  
  set dir $properties(launch_directory)

  # setup the filter to include only header types enabled for simulation
  set filter "USED_IN_SIMULATION == 1 && (FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog/SystemVerilog Header\")"
  set vh_files [get_files -all -quiet -filter $filter]
  
  foreach vh_file $vh_files {
    set vh_file_obj {}
    if { [ info exists a_sim_cache_all_design_files_obj($vh_file) ] } {
      set vh_file_obj $a_sim_cache_all_design_files_obj($vh_file)
    } else {
      set vh_file_obj [ lindex [ get_files -all -quiet $vh_file ] 0 ]
    }

    if { [get_property "IS_GLOBAL_INCLUDE" $vh_file_obj] } {
      continue
    }

    # set vh_file [extract_files -files [list "$vh_file"] -base_dir $dir/ip_files]
    set vh_file [usf_xtract_file $vh_file]
    if { [get_param project.enableCentralSimRepo] } {
      set b_is_bd 0
      if { [ info exists a_sim_cache_all_bd_files($vh_file) ] } {
        set b_is_bd 1
      } else {
        set b_is_bd [usf_is_bd_file $vh_file]
        if { $b_is_bd } {
          set a_sim_cache_all_bd_files($vh_file) $b_is_bd
        }
      }
      set used_in_values [get_property "USED_IN" $vh_file_obj] 
	  if { [lsearch -exact $used_in_values "ipstatic"] == -1 } {
        set vh_file [usf_fetch_header_from_dynamic $vh_file $b_is_bd]
      } else {
        if { $b_is_bd } {
          set vh_file [usf_fetch_ipi_static_file $vh_file]
        } else {
          set vh_file_path [usf_fetch_ip_static_file $vh_file $vh_file_obj]
          if { $properties(b_use_static_lib) && [file exists $vh_file_path] || !$properties(b_use_static_lib) } {
            set vh_file $vh_file_path
          }
        }
      }
    }
    set file_path [usf_file_normalize [string map {\\ /} [file dirname $vh_file]]]
    if { [lsearch -exact $unique_paths $file_path] == -1 } {
      if { $properties(use_absolute_paths) } {
        set incl_file_path "[usf_resolve_file_path $file_path]"
      } else {
        set incl_file_path "[usf_aldec_get_origin_dir_path [usf_get_relative_file_path $file_path $dir]]"
      }
      lappend incl_header_paths $incl_file_path
      lappend unique_paths      $file_path
    }
  }
}

proc usf_get_global_include_files { incl_file_paths_arg incl_files_arg { ref_dir "true" } } {
  # Summary: find source files marked as global include
  # Argument Usage:
  # Return Value:

  upvar $incl_file_paths_arg incl_file_paths
  upvar $incl_files_arg      incl_files
  variable properties
  set filesets       [list]
  set dir            $properties(launch_directory)
  set simset_obj     [get_filesets $properties(simset)]
  set linked_src_set [get_property "SOURCE_SET" $simset_obj]
  set incl_files_set [list]

  if { {} != $linked_src_set } {
    lappend filesets $linked_src_set
  }
  lappend filesets $simset_obj
  set filter "FILE_TYPE == \"Verilog\" || FILE_TYPE == \"Verilog Header\" || FILE_TYPE == \"Verilog Template\""
  foreach fileset_object $filesets {
    set vh_files [get_files -quiet -all -of_objects [get_filesets $fileset_object] -filter $filter]
    foreach file $vh_files {
      # skip if not marked as global include
      if { ![get_property "IS_GLOBAL_INCLUDE" [lindex [get_files -quiet -all [list "$file"]] 0]] } {
        continue
      }

      # skip if marked user disabled
      if { [get_property "IS_USER_DISABLED" [lindex [get_files -quiet -all [list "$file"]] 0]] } {
        continue
      }

      set file [usf_xtract_file $file]
      set file [usf_file_normalize [string map {\\ /} $file]]
      if { [lsearch -exact $incl_files_set $file] == -1 } {
        lappend incl_files_set $file
        lappend incl_files     $file
        set incl_file_path [usf_file_normalize [string map {\\ /} [file dirname $file]]]
        if { $properties(use_absolute_paths) } {
          set incl_file_path "[usf_resolve_file_path $incl_file_path]"
        } else {
          if { $ref_dir } {
            set incl_file_path "[usf_aldec_get_origin_dir_path [usf_get_relative_file_path $incl_file_path $dir]]"
          }
        }
        lappend incl_file_paths $incl_file_path
      }
    }
  }
}

proc usf_get_incl_dirs_from_ip { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set launch_dir $properties(launch_directory)
  set ip_name [file tail $tcl_obj]
  set incl_dirs [list]
  set filter "FILE_TYPE == \"Verilog Header\""
  set vh_files [get_files -quiet -compile_order sources -used_in simulation -of_objects [get_files -quiet *$ip_name] -filter $filter]
  foreach file $vh_files {
    # set file [extract_files -files [list "$file"] -base_dir $launch_dir/ip_files]
    set file [usf_xtract_file $file]
    set dir [file dirname $file]
    if { [get_param project.enableCentralSimRepo] } {
      set b_static_ip_file 0
      set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
      set associated_library {}
      if { {} != $file_obj } {
        if { [lsearch -exact [list_property -quiet $file_obj] {LIBRARY}] != -1 } {
          set associated_library [get_property "LIBRARY" $file_obj]
        }
      }
      set file [usf_get_ip_file_from_repo $tcl_obj $file $associated_library $launch_dir b_static_ip_file]
      set dir [file dirname $file]
      # remove leading "./"
      if { [regexp {^\.\/} $dir] } {
        set dir [join [lrange [split $dir "/"] 1 end] "/"]
      }
    } else {
      if { $properties(use_absolute_paths) } {
        set dir "[usf_resolve_file_path $dir]"
      } else {
        set dir "[usf_aldec_get_origin_dir_path [usf_get_relative_file_path $dir $properties(launch_directory)]]"
      }
    }
    lappend incl_dirs $dir
  }
  set incl_dirs [join $incl_dirs "|"]
  return $incl_dirs
}

proc usf_file_normalize { _path } {
  # Summary: On Windows 'file normalize' changes a link path into a target path, which fools relative paths calculation. This procedure does simplified normalization for links on Windows.
  # Argument Usage:
  # Return Value:

  if { $::tcl_platform(platform) != {windows} } {
    return [file normalize $_path]
  }

  # check if it is a link
  set itIsLink 0
  set path {}

  foreach element [file split $_path] {
    set path [file join $path $element]
    if { [catch { file link $path }] } {
      continue
    }
    set itIsLink 1
    break
  }

  if { !$itIsLink } {
    return [file normalize $_path]
  }

  # do simplified normalization
  set elements {}
  foreach element [file split $_path] {
    if { $element == "." } {
      continue
    } elseif { $element == ".." } {
      set elements [lreplace $elements end end]
    } else {
      lappend elements $element
    }
  }

  set path {}
  foreach element $elements {
    set path [file join $path $element]
  }

  return $path
}

proc usf_get_relative_file_path { file_path_to_convert relative_to } {
  # Summary: Get the relative path wrt to path specified
  # Argument Usage:
  # file_path_to_convert: input file to make relative to specfied path
  # Return Value:
  # Relative path wrt the path specified

  # make sure we are dealing with a valid relative_to directory. If regular file or is not a directory, get directory
  if { [file isfile $relative_to] || ![file isdirectory $relative_to] } {
    set relative_to [file dirname $relative_to]
  }

  set cwd [usf_file_normalize [pwd]]
  # is relative_to "relative"? convert to absolute as well wrt cwd
  if { [file pathtype $relative_to] eq "relative" } {
    set relative_to [file join $cwd $relative_to]
  }

  # normalize
  set file_path         [usf_file_normalize $file_path_to_convert]
  set relative_to       [usf_file_normalize $relative_to]
  set file_comps        [file split $file_path]
  set relative_to_comps [file split $relative_to]
  set found_match       false
  set index             0
  set fc_comps_len      [llength $file_comps]
  set rt_comps_len      [llength $relative_to_comps]
  # compare each dir element of file_to_convert and relative_to, set the flag and
  # get the final index till these sub-dirs matched
  while { $::tcl_platform(platform) == {windows} && [string equal -nocase [lindex $file_comps $index] [lindex $relative_to_comps $index]] 
    || $::tcl_platform(platform) != {windows} && [string equal [lindex $file_comps $index] [lindex $relative_to_comps $index]] } {
    set found_match true
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

proc usf_resolve_file_path { file_dir_path_to_convert } {
  # Summary: Make file path relative to origin_dir if relative component found
  # Argument Usage:
  # file_dir_path_to_convert: input file to make relative to specfied path
  # Return Value:
  # Relative path wrt the path specified

  variable properties
  set ref_dir [usf_file_normalize [string map {\\ /} $properties(launch_directory)]]
  set ref_comps [lrange [split $ref_dir "/"] 1 end]
  set file_comps [lrange [split [usf_file_normalize [string map {\\ /} $file_dir_path_to_convert]] "/"] 1 end]
  set index 1
  while { [lindex $ref_comps $index] == [lindex $file_comps $index] } {
    incr index
  }
  # is file path within reference dir? return relative path
  if { $index == [llength $ref_comps] } {
    return [usf_get_relative_file_path $file_dir_path_to_convert $ref_dir]
  }
  # return absolute
  return $file_dir_path_to_convert
}

proc usf_is_ip { tcl_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

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

proc usf_is_embedded_flow {} {
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

proc usf_get_compiler_name { file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set compiler ""
  if { ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) } {
    set compiler "vcom"
  } elseif { ({Verilog} == $file_type) || ({SystemVerilog} == $file_type) || ({Verilog Header} == $file_type) } {
    set compiler "vlog"
  } elseif { "SystemC" == $file_type } {
	set compiler "ccomp"	
  } elseif { "CPP" == $file_type } {
	set compiler "g++"	
  } elseif { "C" == $file_type } {
	set compiler "gcc"
  }
  return $compiler
}

proc usf_aldec_append_compiler_options { tool file_type opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  variable properties
  
  set fileset_object [get_filesets $properties(simset)]
  set s_64bit {-64}
  if { [get_property 32bit $fileset_object] } {
    set s_64bit {-32}
  }

  switch $tool {
    "vcom" {
      lappend opts "\{*\}\$${tool}_opts"
    }
    "vlog" {
      lappend opts "\{*\}\$${tool}_opts"
    }
	"ccomp" {
      if { [ isSystemCEnabled ] } {
        set arg_list [list]
        # if {$::tcl_platform(platform) == "unix"} {
          # lappend arg_list $s_64bit
        # }
		
		lappend arg_list "-sc"
		lappend arg_list "-visibility"
        lappend arg_list "-std=c++11"
		lappend arg_list "-DSC_INCLUDE_DYNAMIC_PROCESSES"
		lappend arg_list "-DRIVIERA"
		lappend arg_list "-o [getSystemCLibrary]"

		set compiler [get_property target_simulator [current_project]]	
        set more_opts [get_property $compiler.compile.ccomp.more_options $fileset_object]
        if { {} != $more_opts } {
          lappend arg_list "$more_opts"
        }
        set cmd_str [join $arg_list " "]
        lappend opts $cmd_str
      }
    }
    "g++" {
      if { [ isSystemCEnabled ] } {
        lappend opts "-c"
      }
    }
    "gcc" {
      if { [ isSystemCEnabled ] } {
        lappend opts "-c"
      }
    }
  }
}

proc usf_aldec_getPropertyName { property } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  switch -- [get_property target_simulator [current_project]] {
    Riviera { return "RIVIERA.$property" }
    ActiveHDL { return "ACTIVEHDL.$property" }
  }
}

proc usf_aldec_get_compiler_standard_by_file_type { file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  set fileset_object [get_filesets $::tclapp::aldec::common::helpers::properties(simset)]
  
  switch -nocase -regexp -- $file_type {
    "^VHDL$" {
      switch -- [get_property [usf_aldec_getPropertyName COMPILE.VHDL_SYNTAX] $fileset_object] {
        93 { return "-93" }
        2002 { return "-2002" }
        2008 { return "-2008" }
        2019 { return "-2019" }
      }
    }
    "^VHDL 2008$" {
      return "-2008"
    }
    "^VHDL 2019$" {
      return "-2019"
    }
    "^Verilog|Verilog Header$" {
      switch -- [get_property [usf_aldec_getPropertyName COMPILE.VLOG_SYNTAX] $fileset_object] {
        1995 { return "-v95" }
        2001 { return "-v2k" }
        2005 { return "-v2k5" }
      }
    }
    "^SystemVerilog$" {
      switch -- [get_property [usf_aldec_getPropertyName COMPILE.SV_SYNTAX] $fileset_object] {
        2005 { return "-sv2k5" }
        2009 { return "-sv2k9" }
        2012 {
          switch -- [get_property target_simulator [current_project]] {
            Riviera { return "" }
            ActiveHDL { return "-sv2k12" }
          }
        }
      }
    }
  }
}

proc usf_append_other_options { tool file_type global_files_str opts_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $opts_arg opts
  variable properties
  set fileset_object [get_filesets $properties(simset)]
  switch $tool {
    "vlog" {
      # verilog defines
      set verilog_defines [list]
      set verilog_defines [get_property "VERILOG_DEFINE" [get_filesets $fileset_object]]
      if { [llength $verilog_defines] > 0 } {
        usf_append_define_generics $verilog_defines $tool opts
      }
    }
  }
}

proc usf_make_file_executable { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if {$::tcl_platform(platform) == "unix"} {
    if {[catch {exec chmod a+x $file} error_msg] } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-62 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
    }
  } else {
    if {[catch {exec attrib /D -R $file} error_msg] } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-63 WARNING "Failed to change file permissions to executable ($file): $error_msg\n"
    }
  }
}

proc usf_generate_comp_file_for_simulation { comp_file runs_to_launch_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $runs_to_launch_arg runs_to_launch
  set ts [get_property "SIMULATOR_LANGUAGE" [current_project]]
  set ip_filename [file tail $comp_file]
  set ip_name     [file root $ip_filename]
  # - does the ip support behavioral language?,
  #   -- if yes, then generate simulation products (if not generated by ip earlier)
  #   -- if not, then does ip synth checkpoint set?,
  #       --- if yes, then generate all products (if not generated by ip earlier)
  #       --- if not, then error with recommendation
  # and also generate the IP netlist
  if { [get_property "IS_IP_BEHAV_LANG_SUPPORTED" $comp_file] } {
    # does ip generated simulation products? if not, generate them
    if { ![get_property "IS_IP_GENERATED_SIM" $comp_file] } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-64 INFO "Generating simulation products for IP '$ip_name'...\n"
      set delivered_targets [get_property delivered_targets [get_ips -quiet ${ip_name}]]
      if { [regexp -nocase {simulation} $delivered_targets] } {
        generate_target {simulation} [get_files [list "$comp_file"]] -force
      }
    } else {
      send_msg_id USF-[usf_aldec_getSimulatorName]-65 INFO "IP '$ip_name' is up-to-date for simulation\n"
    }
  } elseif { [get_property "GENERATE_SYNTH_CHECKPOINT" $comp_file] } {
    # make sure ip is up-to-date
    if { ![get_property "IS_IP_GENERATED" $comp_file] } {
      generate_target {all} [get_files [list "$comp_file"]] -force
      send_msg_id USF-[usf_aldec_getSimulatorName]-66 INFO "Generating functional netlist for IP '$ip_name'...\n"
      usf_generate_ip_netlist $comp_file runs_to_launch
    } else {
      send_msg_id USF-[usf_aldec_getSimulatorName]-67 INFO "IP '$ip_name' is upto date for all products\n"
    }
  } else {
    # at this point, ip doesnot support behavioral language and synth check point is false, so advise
    # users to select synthesized checkpoint option or set the "generate_synth_checkpoint' ip property.
    set simulator_lang [get_property "SIMULATOR_LANGUAGE" [current_project]]
    set error_msg "IP contains simulation files that do not support the current Simulation Language: '$simulator_lang'.\n"
    if { [get_property "IS_IP_SYNTH_TARGET_SUPPORTED" $comp_file] } {
      append error_msg "Resolution:-\n"
      append error_msg "1)\n"
      append error_msg "or\n2) Select the option Generate Synthesized Checkpoint (.dcp) in the Generate Output Products dialog\
                        to automatically create a matching simulation netlist, or set the 'GENERATE_SYNTH_CHECKPOINT' property on the core."
    } else {
      # no synthesis, so no recommendation to do a synth checkpoint.
    }
    send_msg_id USF-[usf_aldec_getSimulatorName]-68 WARNING "$error_msg\n"
    #return 1
  }
}

proc usf_generate_ip_netlist { comp_file runs_to_launch_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $runs_to_launch_arg runs_to_launch
  set comp_file_obj [get_files [list "$comp_file"]]
  set comp_file_fs  [get_property "FILESET_NAME" $comp_file_obj]
  if { ![get_property "GENERATE_SYNTH_CHECKPOINT" $comp_file_obj] } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-69 INFO "Generate synth checkpoint is 'false':$comp_file\n"
    # if synth checkpoint read-only, return
    if { [get_property "IS_IP_SYNTH_CHECKPOINT_READONLY" $comp_file_obj] } {
      send_msg_id USF-[usf_aldec_getSimulatorName]-70 WARNING "Synth checkpoint property is 'readonly' ... skipping:$comp_file\n"
      return
    }
    # set property to create a DCP/structural simulation file
    send_msg_id USF-[usf_aldec_getSimulatorName]-71 INFO "Setting synth checkpoint for generating simulation netlist:$comp_file\n"
    set_property "GENERATE_SYNTH_CHECKPOINT" true $comp_file_obj
  } else {
    send_msg_id USF-[usf_aldec_getSimulatorName]-72 INFO "Generate synth checkpoint is set:$comp_file\n"
  }
  # block fileset name is based on the basename of the IP
  set src_file [usf_file_normalize $comp_file]
  set ip_basename [file root [file tail $src_file]]
  # block-fileset may not be created at this point, so quiet if not found
  set block_fileset_object [get_filesets -quiet $ip_basename]
  # "block fileset" exists? if not create it
  if { {} == $block_fileset_object } {
    create_fileset -blockset "$ip_basename"
    set block_fileset_object [get_filesets $ip_basename]
    send_msg_id USF-[usf_aldec_getSimulatorName]-73 INFO "Block-fileset created:$block_fileset_object"
    # set fileset top
    set comp_file_top [get_property "IP_TOP" $comp_file_obj]
    set_property "TOP" $comp_file_top [get_filesets $ip_basename]
    # move sub-design to block-fileset
    send_msg_id USF-[usf_aldec_getSimulatorName]-74 INFO "Moving ip composite source(s) to '$ip_basename' fileset"
    move_files -fileset [get_filesets $ip_basename] [get_files -of_objects [get_filesets $comp_file_fs] $src_file] 
  }
  if { {BlockSrcs} != [get_property "FILESET_TYPE" $block_fileset_object] } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-75 ERROR "Given source file is not associated with a design source fileset.\n"
    return 1
  }
  # construct block-fileset run for the netlist
  set run_name $ip_basename;append run_name "_synth_1"
  if { ![get_property "IS_INITIALIZED" [get_runs $run_name]] } {
    reset_run $run_name
  }
  lappend runs_to_launch $run_name
  send_msg_id USF-[usf_aldec_getSimulatorName]-76 INFO "Run scheduled for '$ip_basename':$run_name\n"
}

proc usf_get_testbench_files_from_ip { file_type_filter } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set tb_filelist [list]
  set ip_filter "FILE_TYPE == \"IP\""
  foreach ip [get_files -all -quiet -filter $ip_filter] {
    set ip_name [file tail $ip]
    set tb_files [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $file_type_filter]
    if { [llength $tb_files] > 0 } {
      foreach tb $tb_files {
        set tb_file_obj [lindex [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] $tb] 0]
        if { {simulation testbench} == [get_property "USED_IN" $tb_file_obj] } {
          if { [lsearch -exact [list_property -quiet $tb_file_obj] {IS_USER_DISABLED}] != -1 } {
            if { [get_property {IS_USER_DISABLED} $tb_file_obj] } {
              continue;
            }
          }
          lappend tb_filelist $tb
        }
      }
    }
  }
  return $tb_filelist
}

proc usf_get_bin_path { tool_name path_sep } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set path_value $::env(PATH)
  set bin_path {}
  foreach path [split $path_value $path_sep] {
    set exe_file [usf_file_normalize [file join $path $tool_name]]
    if { [file exists $exe_file] } {
      set bin_path $path
      break
    }
  }
  return $bin_path
}

proc usf_get_global_include_file_cmdstr { incl_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $incl_files_arg incl_files
  variable properties
  set file_str [list]
  foreach file $incl_files {
    lappend file_str "\"$file\""
  }
  return [join $file_str " "]
}

proc findCompileOrderFilesUniq { } {
	variable l_compile_order_files
	variable compileOrderFilesUniq

	set compileOrderFilesUniq [usf_uniquify_cmd_str $l_compile_order_files]
}

proc getFileCmdStr { file _fileType _xpm _globalFilesStr _includeDirsOptions { _xpmLibrary {} } { _xvLibrary {} } } {
    variable properties
	variable a_sim_cache_all_design_files_obj

	upvar $_includeDirsOptions includeDirsOptions

	set launchDirectory $properties(launch_directory)
	set associatedLibrary $properties(associatedLibrary)
	set commandStr {}
	set fileObject {}

	if { [ info exists a_sim_cache_all_design_files_obj($file) ] } {
		set fileObject $a_sim_cache_all_design_files_obj($file)
	} else {
		set fileObject [ lindex [ get_files -quiet -all [ list "$file" ] ] 0 ]
	}

	if { {} != $fileObject } {
		if { [ lsearch -exact [ list_property -quiet $fileObject ] {LIBRARY} ] != -1 } {
			set associatedLibrary [ get_property "LIBRARY" $fileObject ]
		}
		
		if { [ get_param "project.enableCentralSimRepo" ] } {
			# # no op
		} else {
			if { $properties(b_extract_ip_sim_files) } {
				set ipPath [ get_property core_container $fileObject ]
				if { {} != $ipPath } {
					set ipName [ file root [ file tail $ipPath ] ]
					set ipDir [ get_property ip_extract_dir [ get_ips -all -quiet $ipName ] ]
					set ipFile "[usf_get_relative_file_path $file $ipDir]"
					set ipFile [join [lrange [split $ipFile "/"] 1 end] "/"]
					set file [ file join $ipDir $ipFile ]
				} else {
				}
			}
		}
	} else {
		if { ($_xpm) && ([ string length $_xpmLibrary ] != 0)} {
			set associatedLibrary $_xpmLibrary
		}
	}

	if { {} != $_xvLibrary } {
		set associatedLibrary $_xvLibrary
	}

	set b_static_ip_file 0
	if { !$_xpm } {
		set ipFile [ usf_get_top_ip_filename $file ]

		set file [ usf_get_ip_file_from_repo $ipFile $file $associatedLibrary $launchDirectory b_static_ip_file ]
	}

	if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
	} else {
		regsub -all { } $file {\\\\ } file
	}

	set compiler [ usf_get_compiler_name $_fileType ]
	set argList [list]
	if { [ string length $compiler] > 0 } {
		lappend argList $compiler
		lappend argList [ usf_aldec_get_compiler_standard_by_file_type $_fileType ]
		usf_aldec_append_compiler_options $compiler $_fileType argList
		set argList [ linsert $argList end "-work $associatedLibrary" "$_globalFilesStr" ]
	}
	usf_append_other_options $compiler $_fileType $_globalFilesStr argList
  
	if { {vlog} == $compiler } {
		set argList [concat $argList $includeDirsOptions]
	}

	set file_str [join $argList " "]
	set type [usf_get_file_type_category $_fileType]
	set commandStr "$type|$_fileType|$associatedLibrary|$file_str|\"$file\"|$b_static_ip_file"
	return $commandStr
}

proc usf_get_file_cmd_str { \
	file \
	file_type \
	global_files_str \
	include_directories_options_arg \
	{ _xpm 0 } \
	{ _xpmLibrary {} } \
} {
	variable properties
	variable a_sim_cache_all_design_files_obj

	upvar $include_directories_options_arg include_directories_options

	set use_absolute_paths $properties(use_absolute_paths)
	set cmd_str {}
	set associated_library $properties(associatedLibrary)

	set file_obj {}
  	if { [ info exists a_sim_cache_all_design_files_obj($file) ] } {
		set file_obj $a_sim_cache_all_design_files_obj($file)
	} else {
		set file_obj [ lindex [ get_files -quiet -all [ list "$file" ] ] 0 ]
	}

	if { {} != $file_obj } {
		if { [lsearch -exact [ list_property -quiet $file_obj ] {LIBRARY}] != -1 } {
			set associated_library [get_property "LIBRARY" $file_obj]
		}

		if { [ get_param "project.enableCentralSimRepo" ] } {
			# no op
		} else {
			if { $properties(b_extract_ip_sim_files) } {
				set xcix_ip_path [ get_property core_container $file_obj ]
				if { {} != $xcix_ip_path } {
					set ip_name [ file root [ file tail $xcix_ip_path ] ]
					set ip_ext_dir [ get_property ip_extract_dir [ get_ips -all -quiet $ip_name ] ]
					set ip_file "[usf_get_relative_file_path $file $ip_ext_dir]"

					set ip_file [ join [lrange [ split $ip_file "/" ] 1 end] "/" ]
					set file [ file join $ip_ext_dir $ip_file ]
				} else {
					# set file [extract_files -files [list "$file"] -base_dir $dir/ip_files]
				}
			}
		}
	} else { ; # File object is not defined. Check if this is an XPM file...
		if { $_xpm } {
			if { [string length $_xpmLibrary] != 0 } {
				set associated_library $_xpmLibrary
			} else {
				set associated_library "xpm"
			}
		}
	}

	set b_static_ip_file 0
	if { !$_xpm } {
		set ip_file [ usf_get_top_ip_filename $file ]
		set file [usf_get_ip_file_from_repo $ip_file $file $associated_library $properties(launch_directory) b_static_ip_file]
	}
	
	set compiler [usf_get_compiler_name $file_type]
	set arg_list [ list ]
	if { [string length $compiler] > 0 } {
		lappend arg_list $compiler
		lappend arg_list [ usf_aldec_get_compiler_standard_by_file_type $file_type ]
		usf_aldec_append_compiler_options $compiler $file_type arg_list
		set arg_list [linsert $arg_list end "-work $associated_library" "$global_files_str"]
	}
	usf_append_other_options $compiler $file_type $global_files_str arg_list

	if { {vlog} == $compiler } {
		set arg_list [concat $arg_list $include_directories_options]
	}

	set file_str [join $arg_list " "]
	set type [usf_get_file_type_category $file_type]
	set cmd_str "$type|$file_type|$associated_library|$file_str|$file|$b_static_ip_file"
	return $cmd_str
}

proc usf_get_top_ip_filename { src_file } {
	variable a_sim_cache_all_design_files_obj

	set top_ip_file {}

   	if { [ info exists a_sim_cache_all_design_files_obj($src_file) ] } {
		set file_obj $a_sim_cache_all_design_files_obj($src_file)
	} else {
		set file_obj [ lindex [ get_files -quiet -all [ list "$src_file" ] ] 0 ]
	}

	if { {} == $file_obj } {
		set file_obj [ lindex [ get_files -all -quiet [ file tail $src_file ] ] 0 ]
	}

	if { {} == $file_obj } {
		return $top_ip_file
	}

	set props [ list_property -quiet $file_obj ]
	if { [ lsearch $props "PARENT_COMPOSITE_FILE" ] != -1 } {
		set top_ip_file [ usf_find_top_level_ip_file $src_file ]
	}

	return $top_ip_file
}

proc usf_get_file_type_category { file_type } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set type {UNKNOWN}
  switch $file_type {
    {VHDL} -
    {VHDL 2008} -
    {VHDL 2019} {
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

proc usf_get_netlist_writer_cmd_args { extn } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set fileset_object                 [get_filesets $properties(simset)]
  set nl_cell                [get_property "NL.CELL" $fileset_object]
  set nl_incl_unisim_models  [get_property "NL.INCL_UNISIM_MODELS" $fileset_object]
  set nl_rename_top          [get_property "NL.RENAME_TOP" $fileset_object]
  set nl_sdf_anno            [get_property "NL.SDF_ANNO" $fileset_object]
  set nl_write_all_overrides [get_property "NL.WRITE_ALL_OVERRIDES" $fileset_object]
  set args                   [list]

  if { {} != $nl_cell }          { lappend args "-cell";lappend args $nl_cell }
  if { $nl_write_all_overrides } { lappend args "-write_all_overrides" }

  if { {} != $nl_rename_top } {
    if { {.v} == $extn } {
      lappend args "-rename_top";lappend args $nl_rename_top
    } elseif { {.vhd} == $extn } {
      lappend args "-rename_top";lappend args $nl_rename_top
    }
  }

  if { ({timing} == $properties(s_type)) } {
    if { $nl_sdf_anno } {
      lappend args "-sdf_anno true"
    } else {
      lappend args "-sdf_anno false"
    }
  }

  if { $nl_incl_unisim_models } { lappend args "-include_unisim" }
  lappend args "-force"
  set cmd_args [join $args " "]
  return $cmd_args
}

proc usf_get_sdf_writer_cmd_args { } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set fileset_object            [get_filesets $properties(simset)]
  set nl_cell           [get_property "NL.CELL" $fileset_object]
  set nl_rename_top     [get_property "NL.RENAME_TOP" $fileset_object]
  set nl_process_corner [get_property "NL.PROCESS_CORNER" $fileset_object]
  set args              [list]

  if { {} != $nl_cell } {lappend args "-cell";lappend args $nl_cell}
  lappend args "-process_corner";lappend args $nl_process_corner
  if { {} != $nl_rename_top } {lappend "-rename_top_module";lappend args $nl_rename_top}
  lappend args "-force"
  set cmd_args [join $args " "]
  return $cmd_args
}

proc usf_aldec_check_errors { step results_log_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $results_log_arg results_log
  
  variable properties
  set run_dir $properties(launch_directory)

  set retval 0
  set log [usf_file_normalize [file join $run_dir ${step}.log]]
  set fh 0
  if {[catch {open $log r} fh]} {
    send_msg_id USF-[usf_aldec_getSimulatorName]-77 WARNING "Failed to open file to read ($log)\n"
  } else {
    set log_data [read $fh]
    close $fh
    set log_data [split $log_data "\n"]
    foreach line $log_data {
      if { [ regexp -nocase {executing.+onerror} $line ] } {
        set results_log $log
        set retval 1
        break
      }
      if { [regexp -nocase {([0-9]+)\s+Errors} $line tmp errorsCount] && $errorsCount } {
        set results_log $log
        set retval 1
        break
      }
      if { [regexp -nocase {^Error:.+$} $line] } {
        set results_log $log
        set retval 1
        break
      }      
    }
  }
  if { $retval } {
    [catch {send_msg_id USF-[usf_aldec_getSimulatorName]-78 INFO "Step results log file:'$log'\n"}]
    return 1
  }
  return 0
}

proc usf_resolve_incl_dir_property_value { incl_dirs } {
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

proc usf_find_files { src_files_arg filter } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  upvar $src_files_arg src_files

  set tcl_obj $properties(sp_tcl_obj)
  if { [usf_is_ip $tcl_obj] } {
    set ip_name [file tail $tcl_obj]
    foreach file [get_files -all -quiet -of_objects [get_files -quiet *$ip_name] -filter $filter] {
      if { [lsearch -exact [list_property -quiet $file] {IS_USER_DISABLED}] != -1 } {
        if { [get_property {IS_USER_DISABLED} $file] } {
          continue;
        }
      }
      set file [usf_file_normalize $file]
      if { $properties(use_absolute_paths) } {
        set file "[usf_resolve_file_path $file]"
      } else {
        set file "[usf_get_relative_file_path $file $properties(launch_directory)]"
      }
      lappend src_files $file
    }
  } elseif { [usf_is_fileset $tcl_obj] } {
    set filesets       [list]
    set simset_obj     [get_filesets $properties(simset)]

    lappend filesets $simset_obj
    set linked_src_set [get_property "SOURCE_SET" $simset_obj]
    if { {} != $linked_src_set } {
      lappend filesets $linked_src_set
    }

    # add block filesets
    set blk_filter "FILESET_TYPE == \"BlockSrcs\""
    foreach blk_fileset_object [get_filesets -filter $blk_filter] {
      lappend filesets $blk_fileset_object
    }

    foreach fileset_object $filesets {
      foreach file [get_files -quiet -of_objects [get_filesets $fileset_object] -filter $filter] {
        if { [lsearch -exact [list_property -quiet $file] {IS_USER_DISABLED}] != -1 } {
          if { [get_property {IS_USER_DISABLED} $file] } {
            continue;
          }
        }
        set file [usf_file_normalize $file]
        if { $properties(use_absolute_paths) } {
          set file "[usf_resolve_file_path $file]"
        } else {
          set file "[usf_get_relative_file_path $file $properties(launch_directory)]"
        }
        lappend src_files $file
      }
    }
  }
}

proc usf_xtract_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  if { [get_param "project.enableCentralSimRepo"] } {
    return $file
  }

  variable properties
  if { $properties(b_extract_ip_sim_files) } {
    set file_obj [lindex [get_files -quiet -all [list "$file"]] 0]
    set xcix_ip_path [get_property core_container $file_obj]
    if { {} != $xcix_ip_path } {
      set ip_name [file root [file tail $xcix_ip_path]]
      set ip_ext_dir [get_property ip_extract_dir [get_ips -all -quiet $ip_name]]
      set ip_file "[usf_get_relative_file_path $file $ip_ext_dir]"
      # remove leading "../"
      set ip_file [join [lrange [split $ip_file "/"] 1 end] "/"]
      set file [file join $ip_ext_dir $ip_file]
    }
  }
  return $file
}

proc usf_get_ip_file_from_repo { ip_file src_file library launch_dir is_static_ip_file_arg } {

	variable properties
	variable l_ip_static_libs
	upvar $is_static_ip_file_arg is_static_ip_file

	if { (![ get_param project.enableCentralSimRepo] ) || ({} == $ip_file) } {
		if { $properties(use_absolute_paths) } {
			set src_file "[usf_resolve_file_path $src_file]"
		} else {
			if { [file pathtype $src_file] == "absolute" } {
				set src_file "[usf_get_relative_file_path $src_file $launch_dir]"
			}
			set src_file "[usf_aldec_get_origin_dir_path $src_file]"
		}

		return $src_file
	}

	if { ({} != $properties(dynamic_repo_dir)) && ([ file exist $properties(dynamic_repo_dir) ]) } {
		set b_is_static 0
		set b_is_dynamic 0
		set src_file [ usf_get_source_from_repo $ip_file $src_file $launch_dir b_is_static b_is_dynamic ]
		set is_static_ip_file $b_is_static
		if { (!$b_is_static) && (!$b_is_dynamic) } {
			# send_msg_id USF-[usf_aldec_getSimulatorName]-79 "CRITICAL WARNING" "IP file is neither static or dynamic:'$src_file'\n"
		}

		if { $b_is_static } {
			set is_static_ip_file 1
			lappend l_ip_static_libs [string tolower $library]
		}
	}

	if { $properties(use_absolute_paths) } {
		set src_file "[usf_resolve_file_path $src_file]"
	} else {
		if { [file pathtype $src_file] == "absolute" } {
			set src_file "[usf_get_relative_file_path $src_file $launch_dir]"
		}
		set src_file "[usf_aldec_get_origin_dir_path $src_file]"
	}

  return $src_file
}

proc usf_get_source_from_repo { ip_file orig_src_file launch_dir b_is_static_arg b_is_dynamic_arg } {
	variable a_sim_cache_all_bd_files
	variable properties
	variable a_sim_cache_all_design_files_obj
	variable compiledLibraries
	variable localDesignLibraries

	upvar $b_is_static_arg b_is_static
	upvar $b_is_dynamic_arg b_is_dynamic

	set src_file $orig_src_file

	set b_wrap_in_quotes 0
	if { [ regexp {\"} $src_file ] } {
		set b_wrap_in_quotes 1
		regsub -all {\"} $src_file {} src_file
	}

	set b_add_ref 0 
	if { [ regexp -nocase {^\$ref_dir} $src_file ] } {
		set b_add_ref 1
		set src_file [ string range $src_file 9 end ]
		set src_file "$src_file"
	}

	set filename [ file tail $src_file ]

	set ip_name [ file root [ file tail $ip_file ] ] 

	set full_src_file_path [ usf_find_file_from_compile_order $ip_name $src_file ]

	set full_src_file_obj {}
	if { [ info exists a_sim_cache_all_design_files_obj($full_src_file_path) ] } {
		set full_src_file_obj $a_sim_cache_all_design_files_obj($full_src_file_path)
	} else {
		set full_src_file_obj [ lindex [ get_files -all [ list "$full_src_file_path" ] ] 0 ]
	}
    if { {} == $full_src_file_obj } {
		return $orig_src_file
	}

	set dst_cip_file $full_src_file_path
	set used_in_values [ get_property "USED_IN" $full_src_file_obj ]
    set library [ get_property "LIBRARY" $full_src_file_obj ]
	set b_file_is_static 0

	if { [ lsearch -exact $used_in_values "ipstatic" ] == -1 } {
		set b_found_in_repo 0

		if { [ usf_cache_result {usf_is_core_container $ip_file $ip_name} ] } {
			set dst_cip_file [ usf_get_dynamic_sim_file_core_container $full_src_file_path ]
		} else {
			set dst_cip_file [ usf_get_dynamic_sim_file_core_classic $full_src_file_path ]
		}
	} else {
		set b_file_is_static 1
	}

	set b_is_dynamic 1
	set b_is_bd_ip 0
    if { [ info exists a_sim_cache_all_bd_files($full_src_file_path) ] } {
		set b_is_bd_ip 1
	} else {
		set b_is_bd_ip [usf_is_bd_file $full_src_file_path ]

		if { $b_is_bd_ip } {
			set a_sim_cache_all_bd_files($full_src_file_path) $b_is_bd_ip
		}
	}

    set ip_static_file {}
	if { $b_file_is_static } {
		set ip_static_file $full_src_file_path
	}
  
	if { {} != $ip_static_file } {
		set b_is_static 0
		set b_is_dynamic 0
		set dst_cip_file $ip_static_file

		set b_process_file 1
		if { $properties(b_use_static_lib) } {
			if { [ lsearch -exact $compiledLibraries $library ] != -1 } {
				set b_process_file 0
				set b_is_static 1
			} else {
				if { [lsearch -exact $localDesignLibraries $library] == -1 } {
					lappend localDesignLibraries $library
					printIpCompileMessage $library
				}	
			}
		}
	
		if { $b_process_file } {
			if { $b_is_bd_ip } {
				set dst_cip_file [ usf_fetch_ipi_static_file $ip_static_file ]
			} else {
				set parent_comp_file [get_property parent_composite_file -quiet $full_src_file_obj ]
				set dst_cip_file [usf_find_ipstatic_file_path $ip_static_file $parent_comp_file]

				# skip if file exists
				if { ({} == $dst_cip_file) || (![ file exists $dst_cip_file ]) } {
					# if parent composite file is empty, extract to default ipstatic dir (the extracted path is expected to be
					# correct in this case starting from the library name (e.g fifo_generator_v13_0_0/hdl/fifo_generator_v13_0_rfs.vhd))
					if { {} == $parent_comp_file } {
						set dst_cip_file [extract_files -no_ip_dir -quiet -files [list "$ip_static_file"] -base_dir $properties(ipstatic_dir)]
						#puts extracted_file_no_pc=$dst_cip_file
					} else {
						# parent composite is not empty, so get the ip output dir of the parent composite and subtract it from source file
						set parent_ip_name [file root [file tail $parent_comp_file]]
						set ip_output_dir [get_property ip_output_dir [get_ips -all $parent_ip_name]]
						#puts src_ip_file=$ip_static_file

						# get the source ip file dir
						set src_ip_file_dir [file dirname $ip_static_file]

						# strip the ip_output_dir path from source ip file and prepend static dir
						set lib_dir [usf_get_sub_file_path $src_ip_file_dir $ip_output_dir]
						set target_extract_dir [usf_file_normalize [file join $properties(ipstatic_dir) $lib_dir]]
						#puts target_extract_dir=$target_extract_dir

						set dst_cip_file [extract_files -no_path -quiet -files [list "$ip_static_file"] -base_dir $target_extract_dir]
						#puts extracted_file_with_pc=$dst_cip_file
					}
				}
			}
		}
	}

	if { [file exist $dst_cip_file] } {
		if { $properties(use_absolute_paths) } {
			set dst_cip_file "[usf_resolve_file_path $dst_cip_file]"
		} else {
			if { $b_add_ref } {
				set dst_cip_file "\$ref_dir/[usf_get_relative_file_path $dst_cip_file $launch_dir]"
			} else {
				set dst_cip_file "[usf_get_relative_file_path $dst_cip_file $launch_dir]"
			}
		}
		if { $b_wrap_in_quotes } {
			set dst_cip_file "\"$dst_cip_file\""
		}
		set orig_src_file $dst_cip_file
	}

	return $orig_src_file
}

proc usf_find_top_level_ip_file { _file } {
	variable a_sim_cache_all_design_files_obj
	variable a_sim_cache_parent_comp_files

	set comp_file $_file

	set MAX_PARENT_COMP_LEVELS 10
	set count 0
	while (1) {
		incr count
		if { $count > $MAX_PARENT_COMP_LEVELS } { break }

		if { [ info exists a_sim_cache_all_design_files_obj($comp_file) ] } {
			set file_obj $a_sim_cache_all_design_files_obj($comp_file)
		} else {
			set file_obj [ lindex [ get_files -quiet -all [ list "$comp_file" ] ] 0 ]
		}
		if { {} == $file_obj } {

			set file_name [ file tail $comp_file ]
			set file_obj [ lindex [ get_files -all "$file_name" ] 0 ]
			set comp_file $file_obj
		}
		if { [ info exists a_sim_cache_parent_comp_files($comp_file) ] } {
			break
		} else {
			set props [ list_property -quiet $file_obj ]
			if { [ lsearch $props "PARENT_COMPOSITE_FILE" ] == -1 } {
				break
			}	
		}

		set comp_file [get_property parent_composite_file -quiet $file_obj]
	}

	return $comp_file
}

proc usf_is_bd_file { src_file } {
	variable a_sim_cache_all_design_files_obj
	variable a_sim_cache_parent_comp_files

	set comp_file $src_file
	set MAX_PARENT_COMP_LEVELS 10
	set count 0
	while (1) {
		incr count
		if { $count > $MAX_PARENT_COMP_LEVELS } { break }
		set file_obj {}
		if { [ info exists a_sim_cache_all_design_files_obj($comp_file) ] } {
			set file_obj $a_sim_cache_all_design_files_obj($comp_file)
		} else {
			set file_obj [ lindex [ get_files -all [ list "$comp_file" ] ] 0 ]
		}

		if { [ info exists a_sim_cache_parent_comp_files($comp_file) ] } {
			break
		} else {
			set props [list_property -quiet $file_obj]
			if { [ lsearch $props "PARENT_COMPOSITE_FILE" ] == -1 } {
				set a_sim_cache_parent_comp_files($comp_file) true
				break
			}
		}

		set comp_file [ get_property parent_composite_file -quiet $file_obj ]
	}

	if { {.bd} == [file extension $comp_file] } {
		return  1
	}

	return 0
}

proc usf_fetch_ip_static_file { file vh_file_obj } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties

  # /tmp/tp/tp.srcs/sources_1/ip/my_ip/bd_0/ip/ip_2/axi_infrastructure_v1_1_0/hdl/verilog/axi_infrastructure_v1_1_0_header.vh
  set src_ip_file $file
  set src_ip_file [string map {\\ /} $src_ip_file]
  #puts src_ip_file=$src_ip_file

  # get parent composite file path dir
  set comp_file [get_property parent_composite_file -quiet $vh_file_obj]

  if { [get_param "project.enableRevisedDirStructure"] } {
    set proj [get_property "NAME" [current_project]]
    set from "/${proj}.srcs/"
    set with "/${proj}.gen/"
    if { [regexp $with $src_ip_file] } {
      regsub -all $from $comp_file $with comp_file
    }
  }
 
  set comp_file_dir [file dirname $comp_file]
  set comp_file_dir [string map {\\ /} $comp_file_dir]
  # /tmp/tp/tp.srcs/sources_1/ip/my_ip/bd_0/ip/ip_2
  #puts comp_file_dir=$comp_file_dir

  # strip parent dir from file path dir
  set lib_file_path {}
  # axi_infrastructure_v1_1_0/hdl/verilog/axi_infrastructure_v1_1_0_header.vh

  set src_file_dirs  [file split [usf_file_normalize $src_ip_file]]
  set comp_file_dirs [file split [usf_file_normalize $comp_file_dir]]
  set src_file_len [llength $src_file_dirs]
  set comp_dir_len [llength $comp_file_dir]

  set index 1
  #puts src_file_dirs=$src_file_dirs
  #puts com_file_dirs=$comp_file_dirs
  while { [lindex $src_file_dirs $index] == [lindex $comp_file_dirs $index] } {
    incr index
    if { ($index == $src_file_len) || ($index == $comp_dir_len) } {
      break;
    }
  }
  set lib_file_path [join [lrange $src_file_dirs $index end] "/"]
  #puts lib_file_path=$lib_file_path

  set dst_cip_file [file join $properties(ipstatic_dir) $lib_file_path]
  # /tmp/tp/tp.ip_user_files/ipstatic/axi_infrastructure_v1_1_0/hdl/verilog/axi_infrastructure_v1_1_0_header.vh
  #puts dst_cip_file=$dst_cip_file
  return $dst_cip_file
}

proc usf_fetch_ipi_static_file { file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set src_ip_file $file

  if { $properties(b_use_static_lib) } {
    return $src_ip_file
  }

  set comps [lrange [split $src_ip_file "/"] 0 end]
  set to_match "xilinx.com"
  set index 0
  set b_found [usf_find_comp comps index $to_match]
  if { !$b_found } {
    set to_match "user_company"
    set b_found [usf_find_comp comps index $to_match]
  }
  if { !$b_found } {
    return $src_ip_file
  }

  set file_path_str [join [lrange $comps 0 $index] "/"]
  set ip_lib_dir "$file_path_str"

  #puts ip_lib_dir=$ip_lib_dir
  set ip_lib_dir_name [file tail $ip_lib_dir]
  set target_ip_lib_dir [file join $properties(ipstatic_dir) $ip_lib_dir_name]
  #puts target_ip_lib_dir=$target_ip_lib_dir

  # get the sub-dir path after "xilinx.com/xbip_utils_v3_0"
  set ip_hdl_dir [join [lrange $comps 0 $index] "/"]
  set ip_hdl_dir "$ip_hdl_dir"
  # /demo/ipshared/xilinx.com/xbip_utils_v3_0/hdl
  #puts ip_hdl_dir=$ip_hdl_dir
  incr index

  set ip_hdl_sub_dir [join [lrange $comps $index end] "/"]
  # /hdl/xbip_utils_v3_0_vh_rfs.vhd
  #puts ip_hdl_sub_dir=$ip_hdl_sub_dir

  set dst_cip_file [file join $target_ip_lib_dir $ip_hdl_sub_dir]
  #puts dst_cip_file=$dst_cip_file

  # repo static file does not exist? maybe generate_target or export_ip_user_files was not executed, fall-back to project src file
  if { ![file exists $dst_cip_file] } {
    return $src_ip_file
  }

  return $dst_cip_file
}

proc usf_get_dynamic_sim_file_core_container { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable properties

  set filename  [file tail $src_file]
  set file_dir  [file dirname $src_file]
  set file_obj  [lindex [get_files -all [list "$src_file"]] 0]
  set xcix_file [get_property core_container $file_obj]
  set core_name [file root [file tail $xcix_file]]

  set parent_comp_file      [get_property parent_composite_file -quiet $file_obj]
  set parent_comp_file_type [get_property file_type [lindex [get_files -all [list "$parent_comp_file"]] 0]]

  set ip_dir {}
  if { {Block Designs} == $parent_comp_file_type } {
    set ip_dir [file join [file dirname $xcix_file] $core_name]
  } else {
    set top_ip_file_name {}
    set ip_dir [usf_get_ip_output_dir_from_parent_composite $src_file top_ip_file_name]
  }
  set hdl_dir_file [usf_get_sub_file_path $file_dir $ip_dir]
  set repo_src_file [file join $properties(dynamic_repo_dir) "ip" $core_name $hdl_dir_file $filename]

  if { [file exists $repo_src_file] } {
    return $repo_src_file
  }

  #send_msg_id exportsim-Tcl-80 WARNING "Corresponding IP user file does not exist:'$repo_src_file'!, using default:'$src_file'"
  return $src_file
}

proc usf_get_dynamic_sim_file_core_classic { src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set filename  [file tail $src_file]
  set file_dir  [file dirname $src_file]
  set file_obj  [lindex [get_files -all [list "$src_file"]] 0]

  set top_ip_file_name {}
  set ip_dir [usf_get_ip_output_dir_from_parent_composite $src_file top_ip_file_name]
  set hdl_dir_file [usf_get_sub_file_path $file_dir $ip_dir]

  set top_ip_name [file root [file tail $top_ip_file_name]]
  set extn [file extension $top_ip_file_name]
  set repo_src_file {}
  set sub_dir "ip"
  if { {.bd} == $extn } {
    set sub_dir "bd"
  }
  set repo_src_file [file join $properties(dynamic_repo_dir) $sub_dir $top_ip_name $hdl_dir_file $filename]
  if { [file exists $repo_src_file] } {
    return $repo_src_file
  }
  return $src_file
}

proc usf_get_ip_output_dir_from_parent_composite { src_file top_ip_file_name_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:
  variable a_sim_cache_all_design_files_obj
  variable a_sim_cache_parent_comp_files
  
  upvar $top_ip_file_name_arg top_ip_file_name
   
  set comp_file $src_file
  set MAX_PARENT_COMP_LEVELS 10
  set count 0
  while (1) {
    incr count
    if { $count > $MAX_PARENT_COMP_LEVELS } { break }

	set file_obj  {}
    if { [ info exists a_sim_cache_all_design_files_obj($comp_file) ] } {
      set file_obj $a_sim_cache_all_design_files_obj($comp_file)
    } else {
      set file_obj [ lindex [get_files -all -quiet [ list "$comp_file" ] ] 0 ]
    }

    set props [list_property -quiet $file_obj]
    if { [lsearch $props "PARENT_COMPOSITE_FILE"] == -1 } {
      break
    }
    set comp_file [get_property parent_composite_file -quiet $file_obj]
    #puts "+comp_file=$comp_file"
  }
  set top_ip_name [file root [file tail $comp_file]]
  set top_ip_file_name $comp_file

  set file_obj  {}
  if { [ info exists a_sim_cache_all_design_files_obj($comp_file) ] } {
    set file_obj $a_sim_cache_all_design_files_obj($comp_file)
  } else {
    set file_obj [ lindex [get_files -all -quiet [ list "$comp_file" ] ] 0 ]
  }

  set root_comp_file_type [get_property file_type $file_obj]

  if { {Block Designs} == $root_comp_file_type } {
    set ip_output_dir [file dirname $comp_file]
  } else {
    set ip_output_dir [get_property ip_output_dir [get_ips -all $top_ip_name]]
  }
  return $ip_output_dir
}

proc usf_fetch_header_from_dynamic { vh_file b_is_bd } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  #puts vh_file=$vh_file
  set ip_file [usf_get_top_ip_filename $vh_file]
  if { {} == $ip_file } {
    return $vh_file
  }
  set ip_name [file root [file tail $ip_file]]
  #puts ip_name=$ip_name

  # if not core-container (classic), return original source file from project
  if { ![usf_is_core_container $ip_file $ip_name] } {
    return $vh_file
  }

  set vh_filename   [file tail $vh_file]
  set vh_file_dir   [file dirname $vh_file]
  set output_dir    [get_property IP_OUTPUT_DIR [lindex [get_ips -all $ip_name] 0]]
  set sub_file_path [usf_get_sub_file_path $vh_file_dir $output_dir]

  # construct full repo dynamic file path
  set sub_dir "ip"
  if { $b_is_bd } {
    set sub_dir "bd"
  }
  set vh_file [file join $properties(dynamic_repo_dir) $sub_dir $ip_name $sub_file_path $vh_filename]
  #puts vh_file=$vh_file

  return $vh_file
}

proc usf_get_sub_file_path { src_file_path dir_path_to_remove } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set s_file $src_file_path
  set d_file $dir_path_to_remove
	
  if { [get_param "project.enableRevisedDirStructure"] } {
	set proj [get_property "NAME" [current_project]]
    set from "/${proj}.srcs/"
    set with "/${proj}.gen/"
    if { [regexp $with $s_file] } {
	  regsub -all $from $d_file $with d_file
	}
  }

  set src_path_comps [file split [usf_file_normalize $s_file]]
  set dir_path_comps [file split [usf_file_normalize $d_file]]
   
  set src_path_len [llength $src_path_comps]
  set dir_path_len [llength $dir_path_comps]

  set index 1
  while { [lindex $src_path_comps $index] == [lindex $dir_path_comps $index] } {
    incr index
    if { ($index == $src_path_len) || ($index == $dir_path_len) } {
      break;
    }
  }
  set sub_file_path [join [lrange $src_path_comps $index end] "/"]
  return $sub_file_path
}

proc usf_is_core_container { ip_file ip_name } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set b_is_container 1
  if { [get_property sim.use_central_dir_for_ips [current_project]] } {
    return $b_is_container
  }

  set file_extn [file extension $ip_file]
  #puts $ip_name=$file_extn

  # is this ip core-container? if not return 0 (classic)
  set value [string trim [get_property core_container [get_files -all -quiet ${ip_name}${file_extn}]]]
  if { {} == $value } {
    set b_is_container 0
  }
  return $b_is_container
}

proc usf_find_ipstatic_file_path { src_ip_file parent_comp_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  set dest_file {}
  set filename [file tail $src_ip_file]
  set file_obj [lindex [get_files -quiet -all [list "$src_ip_file"]] 0]
  if { {} == $file_obj } {
    set file_obj [lindex [get_files -quiet -all $filename] 0]
  }
  if { {} == $file_obj } {
    return $dest_file
  }

  if { {} == $parent_comp_file } {
    set library_name [get_property library $file_obj]
    set comps [lrange [split $src_ip_file "/"] 1 end]
    set index 0
    set b_found false
    set to_match $library_name
    set b_found [usf_find_comp comps index $to_match]
    if { $b_found } {
      set file_path_str [join [lrange $comps $index end] "/"]
      #puts file_path_str=$file_path_str
      set dest_file [usf_file_normalize [file join $properties(ipstatic_dir) $file_path_str]]
    }
  } else {
    set parent_ip_name [file root [file tail $parent_comp_file]]
    set ip_output_dir [get_property ip_output_dir [get_ips -all $parent_ip_name]]
    set src_ip_file_dir [file dirname $src_ip_file]
    set lib_dir [usf_get_sub_file_path $src_ip_file_dir $ip_output_dir]
    set target_extract_dir [usf_file_normalize [file join $properties(ipstatic_dir) $lib_dir]]
    set dest_file [file join $target_extract_dir $filename]
  }
  return $dest_file
}

proc usf_find_file_from_compile_order { ip_name src_file } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable compileOrderFilesUniq

  #puts src_file=$src_file
  set file [string map {\\ /} $src_file]

  set sub_dirs [list]
  set comps [lrange [split $file "/"] 1 end]
  foreach comp $comps {
    if { {.} == $comp } continue;
    if { {..} == $comp } continue;
    lappend sub_dirs $comp
  }
  set file_path_str [join $sub_dirs "/"]

  set str_to_replace "/{$ip_name}/"
  set str_replace_with "/${ip_name}/"
  regsub -all $str_to_replace $file_path_str $str_replace_with file_path_str
  #puts file_path_str=$file_path_str

  foreach file $compileOrderFilesUniq {
    set file [string map {\\ /} $file]
    #puts +co_file=$file
    if { [string match  *$file_path_str $file] } {
      set src_file $file
      break
    }
  }
  #puts out_file=$src_file
  return $src_file
}

proc usf_is_static_ip_lib { library } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable l_ip_static_libs
  set library [string tolower $library]
  if { [lsearch $l_ip_static_libs $library] != -1 } {
    return true
  }
  return false
}

proc usf_find_comp { comps_arg index_arg to_match } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $comps_arg comps
  upvar $index_arg index
  set index 0
  set b_found false
  foreach comp $comps {
    incr index
    if { $to_match != $comp } continue;
    set b_found true
    break
  }
  return $b_found
}

proc is_hdl_type { file_type } {
  return [expr { ({Verilog} == $file_type) || ({SystemVerilog} == $file_type) || ({VHDL} == $file_type) || ({VHDL 2008} == $file_type) || ({VHDL 2019} == $file_type) }]
}

proc vip_ips {} {
    return [list "axi_vip" "axi4stream_vip"]
}

proc is_vip_ip_required {} {
  foreach ip_obj [get_ips -all -quiet] {
    set requires_vip [get_property -quiet requires_vip $ip_obj]
    if { $requires_vip } {
      return true
    }
  }

  foreach ip_obj [get_ips -all -quiet] {
    set ipdef [get_property -quiet IPDEF $ip_obj]
    set ip_name [lindex [split $ipdef ":"] 2]
    if { [lsearch -nocase [vip_ips] $ip_name] != -1 } {
      return true
    }
  }
  return false 
}

proc usf_fetch_lib_info { simulator clibs_dir b_int_sm_lib_ref_debug } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_cache_lib_info
  variable a_sim_cache_lib_type_info

  if { ![file exists $clibs_dir] } {
    return
  }

  foreach lib_dir [glob -nocomplain -directory $clibs_dir *] {
    set dat_file "$lib_dir/.cxl.lib_info.dat"
	
    if { ![file exists $dat_file] } { continue; }
    set fh 0
    if { [catch {open $dat_file r} fh] } { continue; }
    set lib_data [split [read $fh] "\n"]
    close $fh

    set library     {}
    set type        {}
    set ldlibs_sysc {}
    set ldlibs_cpp  {}
    set ldlibs_c    {}

    foreach line $lib_data {
      set line [string trim $line]
      if { [string length $line] == 0 } { continue; }
      if { [regexp {^#} $line] } { continue; }
      set tokens [split $line {:}]
      set tag   [lindex $tokens 0]
      set value [lindex $tokens 1]
	  
      if { "Name" == $tag } {
        set library $value
      } elseif { "Type" == $tag } {
        set type $value
      } elseif { "Link_SYSTEMC" == $tag } {
        set ldlibs_sysc $value
      } elseif { "Link_CPP" == $tag } {
        set ldlibs_cpp $value
      } elseif { "Link_C" == $tag } {
        set ldlibs_c $value
      }

      # add to library type database
      if { {} != $library } {
        set a_sim_cache_lib_type_info($library) $type
      }
    }
    # SystemC#xtlm#noc_v1_0_0,common_cpp_v1_0#xyz_v1_0
    set array_value "$type#$ldlibs_sysc#$ldlibs_cpp#$ldlibs_c"
	
    # add the linked libraries to library type database
    usf_add_library_type_to_database $array_value

    set a_sim_cache_lib_info($library) $array_value
  }
  
  # print library type information
  if { $b_int_sm_lib_ref_debug } {
    usf_print_shared_lib_type_info
  }
}

proc usf_add_library_type_to_database { value } {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable a_sim_cache_lib_type_info

  # SystemC#xtlm#noc_v1_0_0,common_cpp_v1_0#xyz_v1_0
  set values        [split $value "#"]
  set sysc_libs_str [lindex $values 1]
  set cpp_libs_str  [lindex $values 2]
  set c_libs_str    [lindex $values 3]

  set sysc_libs [split $sysc_libs_str {,}]
  foreach library $sysc_libs {
    if { "empty" == $library } { break }
    set a_sim_cache_lib_type_info($library) "SystemC"
  }
  set cpp_libs [split $cpp_libs_str {,}]
  foreach library $cpp_libs {
    if { "empty" == $library } { break }
    set a_sim_cache_lib_type_info($library) "CPP"
  }
  set c_libs [split $c_libs_str {,}]
  foreach library $c_libs {
    if { "empty" == $library } { break }
    set a_sim_cache_lib_type_info($library) "C"
  }
}

proc usf_contains_C_files {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set c_filter  "(USED_IN_SIMULATION == 1) && ((FILE_TYPE == \"SystemC\") || (FILE_TYPE == \"CPP\") || (FILE_TYPE == \"C\"))"
  if { [llength [get_files -quiet -all -filter $c_filter ]] > 0 } {
    return true
  }
  return false
}

proc usf_find_shared_lib_paths { simulator clibs_dir custom_sm_lib_dir b_int_sm_lib_ref_debug sp_cpt_dir_arg sp_ext_dir_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $sp_cpt_dir_arg sp_cpt_dir
  upvar $sp_ext_dir_arg sp_ext_dir
 
  # any library referenced in IP?
  set lib_coln [usf_get_sc_libs $b_int_sm_lib_ref_debug]
  if { [llength $lib_coln] == 0 } {
    return
  }

  # target directory paths to search for
  set target_paths [usf_get_target_sm_paths $simulator $clibs_dir $custom_sm_lib_dir $b_int_sm_lib_ref_debug sp_cpt_dir sp_ext_dir]

  # additional linked libraries
  set linked_libs           [list]
  set uniq_linked_libs      [list]
  set processed_shared_libs [list]

  variable a_shared_library_path_coln
  variable a_shared_library_mapping_path_coln
  variable a_sim_cache_lib_info

  set extn "dll"
  if {$::tcl_platform(platform) == "unix"} {
    set extn "so"
  }
  
  # Iterate over the shared library collection found from the packaged IPs in the design (systemc_libraries) and
  # search for this shared library from the known paths. Also find the linked libraries that were referenced in
  # the dat file for a given library that was packaged in IP.
  foreach library $lib_coln {
    # target shared library name to search for
    set shared_libname "lib${library}.${extn}"

    # is systemc library?
    set b_is_systemc_library [usf_is_sc_library $library]

    if { $b_int_sm_lib_ref_debug } {
      puts "Finding shared library '$shared_libname'..."
    }
    # iterate over target paths to search for this library name
    foreach path $target_paths {
      #set path [file normalize $path]
      set path [regsub -all {[\[\]]} $path {/}]

      # is this shared library already processed from a given path? 
      if { [lsearch -exact $processed_shared_libs $shared_libname] != -1 } { continue; }

      if { $b_int_sm_lib_ref_debug } {
        puts " + Library search path:$path"
      }
      set lib_dir_path_found ""
      foreach lib_dir [glob -nocomplain -directory $path *] {
        if { ![file isdirectory $lib_dir] } { continue; }

        # make sure we deal with the right shared library path (library=xtlm, path=/tmp/foo/bar/xtlm)
        set lib_leaf_dir_name [file tail $lib_dir]
        if { $library != $lib_leaf_dir_name } {
          continue
        }
        set sh_file_path "$lib_dir/$shared_libname"
        if { $b_is_systemc_library } {
          if { {questa} == $simulator } {
            set gcc_version [get_param "simulator.${simulator}.gcc.version"]
            if {$::tcl_platform(platform) == "unix"} {
              set sh_file_path "$lib_dir/_sc/linux_x86_64_gcc-${gcc_version}/systemc.so"
              if { $b_int_sm_lib_ref_debug } {
                puts "  + shared lib path:$sh_file_path"
              }
            }
          }
        }
        if { [file exists $sh_file_path] || $::tclapp::aldec::common::helpers::properties(b_compile_simmodels) } {
          if { ![info exists a_shared_library_path_coln($shared_libname)] } {
            set a_shared_library_path_coln($shared_libname) $lib_dir
            set lib_path_dir [file dirname $lib_dir]
            set a_shared_library_mapping_path_coln($library) $lib_path_dir
            if { $b_int_sm_lib_ref_debug } {
              puts "  + Added '$shared_libname:$lib_dir' to collection" 
            }
            lappend processed_shared_libs $shared_libname
            set lib_dir_path_found $lib_dir
            break;
          }
        }
      }

      if { $lib_dir_path_found != "" } {
        # get any dependent libraries if any from this shared library dir
        set dat_file "$lib_dir_path_found/.cxl.lib_info.dat"
        if { [file exists $dat_file] } {
          # any dependent library info fetched from .cxl.lib_info.dat?
          if { [info exists a_sim_cache_lib_info($library)] } {
            # "SystemC#xtlm#common_cpp_v1_0,proto_v1_0#xyz_v1_0"
            set values [split $a_sim_cache_lib_info($library) {#}]
            set values_len [llength $values]
            # make sure we have some data to process
            if { $values_len > 1 } {
              set tag [lindex $values 0]

              # get the systemC linked libraries
              if { ("SystemC" == $tag) || ("C" == $tag) || ("CPP" == $tag)} {

                # process systemC linked libraries (xtlm)
                # "SystemC#xtlm#common_cpp_v1_0,proto_v1_0#xyz_v1_0"
                set libs [split [lindex $values 1] {,}]
                if { [llength $libs] > 0 } {
                  foreach lib $libs {
                    if { "empty" == $lib } { continue }
                    if { [lsearch -exact $uniq_linked_libs $lib] == -1 } {
                      # is linked library already part of search collection?
                      if { [lsearch -exact $lib_coln $lib] != -1 } {
                        continue;
                      }
  
                      lappend linked_libs $lib
                      lappend uniq_linked_libs $lib
                      if { $b_int_sm_lib_ref_debug } {
                        puts "    + Added linked library:$lib"
                      }
                      #send_msg_id SIM-utils-001 STATUS "Added '$lib' for processing\n"
                    }
                  }
                }

                # process cpp linked libraries (common_cpp_v1_0,proto_v1_0)
                # "SystemC#xtlm#common_cpp_v1_0,proto_v1_0#xyz_v1_0"
                set libs [split [lindex $values 2] {,}]
                if { [llength $libs] > 0 } {
                  foreach lib $libs {
                    if { "empty" == $lib } { continue }
                    if { [lsearch -exact $uniq_linked_libs $lib] == -1 } {
                      # is linked library already part of search collection?
                      if { [lsearch -exact $lib_coln $lib] != -1 } {
                        continue;
                      }
  
                      lappend linked_libs $lib
                      lappend uniq_linked_libs $lib
                      if { $b_int_sm_lib_ref_debug } {
                        puts "    + Added linked library:$lib"
                      }
                      #send_msg_id SIM-utils-001 STATUS "Added '$lib' for processing\n"
                    }
                  }
                }

                # process C linked libraries (xyz_v1_0)
                # "SystemC#xtlm#common_cpp_v1_0,proto_v1_0#xyz_v1_0"
                set libs [split [lindex $values 3] {,}]
                if { [llength $libs] > 0 } {
                  foreach lib $libs {
                    if { "empty" == $lib } { continue }
                    if { [lsearch -exact $uniq_linked_libs $lib] == -1 } {
                      # is linked library already part of search collection?
                      if { [lsearch -exact $lib_coln $lib] != -1 } {
                        continue;
                      }
  
                      lappend linked_libs $lib
                      lappend uniq_linked_libs $lib
                      if { $b_int_sm_lib_ref_debug } {
                        puts "    + Added linked library:$lib"
                      }
                      #send_msg_id SIM-utils-001 STATUS "Added '$lib' for processing\n"
                    }
                  }
                }
              }
            }
          }
        } else {
          if { $b_int_sm_lib_ref_debug } {
            puts "    + error: file does not exist '$dat_file'"
          }
        }
      }
    }
  }

  if { $b_int_sm_lib_ref_debug } {
    puts "Processing linked libraries..."
  }
  # find shared library paths for the linked libraries
  foreach library $linked_libs {
    # target shared library name to search for
    set shared_libname "lib${library}.${extn}"
    if { $b_int_sm_lib_ref_debug } {
      puts " + Finding linked shared library:$shared_libname"
    }
    # iterate over target paths to search for this library name
    foreach path $target_paths {
      #set path [file normalize $path]
      set path [regsub -all {[\[\]]} $path {/}]
      foreach lib_dir [glob -nocomplain -directory $path *] {
        set sh_file_path "$lib_dir/$shared_libname"
        if { [file exists $sh_file_path] } {
          if { ![info exists a_shared_library_path_coln($shared_libname)] } {
            set a_shared_library_path_coln($shared_libname) $lib_dir
            set lib_path_dir [file dirname $lib_dir]
            set a_shared_library_mapping_path_coln($library) $lib_path_dir
            if { $b_int_sm_lib_ref_debug } {
              puts "  + Added '$shared_libname:$lib_dir' to collection" 
            }
          }
        }
      }
    }
  }

  # print extracted shared library information
  if { $b_int_sm_lib_ref_debug } {
    usf_print_shared_lib_info
  }
}

proc usf_get_sc_libs { {b_int_sm_lib_ref_debug 0} } {
  variable versalCips
  variable zynqUltra
  # Summary:
  # Argument Usage:
  # Return Value:

  # find referenced libraries from IP
  set prop_name "systemc_libraries"
  set versalCips 0
  set zynqUltra 0
  set ref_libs            [list]
  set uniq_ref_libs       [list]
  set v_ip_names          [list]
  set v_ip_defs           [list]
  set v_allowed_sim_types [list]
  set v_tlm_types         [list]
  set v_sysc_libs         [list]

  foreach ip_obj [get_ips -quiet -all] {
    if { ([lsearch -exact [list_property -quiet $ip_obj] {SYSTEMC_LIBRARIES}] != -1) && ([lsearch -exact [list_property -quiet $ip_obj] {SELECTED_SIM_MODEL}] != -1) } {
      set ip_name           [get_property -quiet name               $ip_obj]
      set ip_def            [get_property -quiet ipdef              $ip_obj]
      set allowed_sim_types [get_property -quiet allowed_sim_types  $ip_obj]
      set tlm_type          [get_property -quiet selected_sim_model $ip_obj]
      set sysc_libs         [get_property -quiet $prop_name         $ip_obj]
      set ip_def            [lindex [split $ip_def {:}] 2]
      
	  lappend v_ip_names $ip_name
	  lappend v_ip_defs $ip_def
	  lappend v_allowed_sim_types $allowed_sim_types
	  lappend v_tlm_types $tlm_type
	  lappend v_sysc_libs $sysc_libs

	  if { $ip_def == "versal_cips" } {
		set versalCips 1
	  } elseif { $ip_def == "zynq_ultra_ps_e" } {
	    set zynqUltra 1
	  }

      if { [string equal -nocase $tlm_type "tlm"] == 1 } { 
        if { $b_int_sm_lib_ref_debug } {
          #puts " +$ip_name:$ip_def:$tlm_type:$sysc_libs"
        }
        foreach lib [get_property -quiet $prop_name $ip_obj] {
          if { [lsearch -exact $uniq_ref_libs $lib] == -1 } {
            lappend uniq_ref_libs $lib
            lappend ref_libs $lib
          }
        }
      }
    }
  }
  set fmt {%-50s%-2s%-30s%-2s%-20s%-2s%-10s%-2s%-20s}
  set sep ":"
  if { $b_int_sm_lib_ref_debug } {
    puts "-------------------------------------------------------------------------------------------------------------------------------------------------------------"
    puts " IP                                                 IPDEF                           Allowed Types         Selected    SystemC Libraries"
    puts "-------------------------------------------------------------------------------------------------------------------------------------------------------------"
    foreach name $v_ip_names def $v_ip_defs sim_type $v_allowed_sim_types tlm_type $v_tlm_types sys_lib $v_sysc_libs {
      puts [format $fmt $name $sep $def $sep $sim_type $sep $tlm_type $sep $sys_lib]
      puts "-------------------------------------------------------------------------------------------------------------------------------------------------------------"
    }
    puts "\nLibraries referenced from IP's"
    puts "------------------------------"
    foreach sc_lib $ref_libs {
      puts " + $sc_lib" 
    }
    puts "------------------------------"
  }
  
  return $ref_libs
}

proc usf_get_target_sm_paths { simulator clibs_dir custom_sm_lib_dir b_int_sm_lib_ref_debug sp_cpt_dir_arg sp_ext_dir_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $sp_cpt_dir_arg sp_cpt_dir
  upvar $sp_ext_dir_arg sp_ext_dir

  set target_paths [list]

  set sm_cpt_dir [usf_get_simmodel_dir $simulator "cpt"]
  set cpt_dir [rdi::get_data_dir -quiet -datafile "simmodels/$simulator"]

  # default protected dir
  set tp "$cpt_dir/$sm_cpt_dir"
  if { ([file exists $tp]) && ([file isdirectory $tp]) } {
    lappend target_paths $tp
  } else {
    # fallback
    if { "xsim" == $simulator } {
      set tp [file dirname $clibs_dir]
      set tp "$tp/$sm_cpt_dir"
      if { ([file exists $tp]) && ([file isdirectory $tp]) } {
        lappend target_paths $tp
      }
    }
  }

  set sp_cpt_dir $tp

  # default ext dir
  set sm_ext_dir [usf_get_simmodel_dir $simulator "ext"]
  lappend target_paths "$cpt_dir/$sm_ext_dir"

  set sp_ext_dir "$cpt_dir/$sm_ext_dir"

  # add ip dir for xsim
  if { "xsim" == $simulator } {
    lappend target_paths "$clibs_dir/ip"
  }

  # prepend custom simmodel library paths, if specified? 
  set sm_lib_path $custom_sm_lib_dir
  if { $sm_lib_path != "" } {
    set custom_paths [list]
    foreach cpath [split $sm_lib_path ":"] {
      if { ($cpath != "") && ([file exists $cpath]) && ([file isdirectory $cpath]) } {
        lappend custom_paths $cpath
      }
    }
    if { [llength $custom_paths] > 0 } {
      set target_paths [concat $custom_paths $target_paths]
    }
  }

  # add compiled library directory
  lappend target_paths "$clibs_dir"

  if { $b_int_sm_lib_ref_debug } {
    puts "-----------------------------------------------------------------------------------------------------------"
    puts "Target paths to search"
    puts "-----------------------------------------------------------------------------------------------------------"
    foreach target_path $target_paths {
      puts "Path: $target_path"
    }
    puts "-----------------------------------------------------------------------------------------------------------"
  }

  return $target_paths
}

proc usf_get_simmodel_dir { simulator type } {
  variable properties

  set platform "win64"
  set extn     "dll"
  if {$::tcl_platform(platform) == "unix"} {
    set platform "lnx64"
    set extn "so"
  }

  set sim_version $properties(s_sim_version)
  if { {} == $sim_version } {
	set sim_version [get_param "simulator.${simulator}.version"]
  }
  
  set gcc_version [get_param "simulator.${simulator}.gcc.version"]
  
  # prefix path
  set prefix_dir "simmodels/${simulator}/${sim_version}/${platform}/${gcc_version}"

  # construct path
  set dir {}
  if { "cpt" == $type } {
    set dir "${prefix_dir}/systemc/protected"
  } elseif { "ext" == $type } {
    set dir "${prefix_dir}/ext"
  }
  
  return $dir
}

proc usf_is_sc_library { library } {
  # Summary:
  # Argument Usage:
  # Return Value:
  
  variable a_sim_cache_lib_type_info
  if { {} == $library } {
    return 0
  }

  if { [info exists a_sim_cache_lib_type_info($library)] } {
    if { "SystemC" == $a_sim_cache_lib_type_info($library) } {
      return 1
    }
  }
  return 0
}

proc usf_get_c_files { c_filter {b_csim_compile_order 0} } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  set c_files [list]
  if { $b_csim_compile_order } {
    foreach file_obj [get_files -quiet -compile_order sources -used_in simulation -filter $c_filter -of_objects [current_fileset -simset]] {
      lappend c_files $file_obj
    }
  } else {
    foreach file_obj [get_files -quiet -all -filter $c_filter] {
      if { [lsearch -exact [list_property -quiet $file_obj] {PARENT_COMPOSITE_FILE}] != -1 } {
        set comp_file [get_property parent_composite_file -quiet $file_obj]
        if { "" == $comp_file } {
          continue
        }
        set file_extn [file extension $comp_file]
        if { (".xci" == $file_extn) } {
          usf_add_c_files_from_xci $comp_file $c_filter c_files
        } elseif { (".bd" == $file_extn) } {
          set bd_file_name [file tail $comp_file]
          set bd_obj [get_files -quiet -all $bd_file_name]
          if { "" != $bd_obj } {
            if { [lsearch -exact [list_property -quiet $bd_obj] {PARENT_COMPOSITE_FILE}] != -1 } {
              set comp_file [get_property parent_composite_file -quiet $bd_obj]
              if { "" != $comp_file } {
                set file_extn [file extension $comp_file]
                if { (".xci" == $file_extn) } {
                  usf_add_c_files_from_xci $comp_file $c_filter c_files
                }
              }
            } else {
              # this is top level BD for this SystemC/CPP/C file, so add it
              lappend c_files $file_obj
            }
          } else {
            # this is top level BD for this SystemC/CPP/C file, so add it
            lappend c_files $file_obj
          }
        }
      } else {
        lappend c_files $file_obj
      }
    }
  }
  return $c_files
}

proc usf_get_boost_library_path {} {
  # Summary:
  # Argument Usage:
  # Return Value:

  set boost_incl_dir {}
  set sep ";"
  if {$::tcl_platform(platform) == "unix"} {
    set sep ":"
  }

  if { [info exists ::env(RDI_DATADIR)] } {
    foreach data_dir [split $::env(RDI_DATADIR) $sep] {
	  set incl_dir "[file dirname $data_dir]/tps"

      foreach boostDirectory [ glob -nocomplain -directory $incl_dir * ] {
        if { ![ file isdirectory $boostDirectory ] || ! [ regexp -nocase "boost.*" [ file tail $boostDirectory ] ] } {
          continue
        }

        set incl_dir $boostDirectory
        break
      }

      if { [file exists $incl_dir] } {
        set boost_incl_dir $incl_dir
        set boost_incl_dir [regsub -all {[\[\]]} $boost_incl_dir {/}]
        break
      }
    }
  } else {
    send_msg_id SIM-utils-059 WARNING "Failed to get the boost library path (RDI_DATADIR environment variable is not set).\n"
  }
  return $boost_incl_dir
}

proc usf_get_c_incl_dirs { simulator launch_dir boost_dir c_filter s_ip_user_files_dir b_xport_src_files b_absolute_path { ref_dir "true" } } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set incl_dirs [list]
  set uniq_incl_dirs [list]

  foreach file [ get_files -compile_order sources -used_in simulation -quiet -filter $c_filter ] {
    set file_extn [file extension $file]

    # consider header (.h) files only
    if { {.h} != $file_extn } {
      continue
    }

    set used_in_values [get_property "USED_IN" [lindex [get_files -quiet -all [list "$file"]] 0]]
    # is HLS source?
    if { [lsearch -exact $used_in_values "c_source"] != -1 } {
      continue
    }

    # fetch header file
    set sc_header_file [usf_fetch_header_from_export $file true $s_ip_user_files_dir]
    set dir [file normalize [file dirname $sc_header_file]]

    # is export_source_files? copy to local incl dir
    if { $b_xport_src_files } {
      set export_dir "$launch_dir/srcs/incl"
      if {[catch {file copy -force $sc_header_file $export_dir} error_msg] } {
        send_msg_id SIM-utils-057 INFO "Failed to copy file '$vh_file' to '$export_dir' : $error_msg\n"
      }
    }

    # make absolute
    if { $b_absolute_path } {
      set dir "[xcs_resolve_file_path $dir $launch_dir]"
    } else {
      if { $ref_dir } {
        if { $b_xport_src_files } {
          set dir "\$ref_dir/incl"
          if { ({modelsim} == $simulator) || ({questa} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator) } {
            set dir "srcs/incl"
          }
        } else {
          if { ({modelsim} == $simulator) || ({questa} == $simulator) || ({riviera} == $simulator) || ({activehdl} == $simulator) } {
            set dir "[usf_get_relative_file_path $dir $launch_dir]"
          } else {
            set dir "\$ref_dir/[usf_get_relative_file_path $dir $launch_dir]"
          }
        }
      } else {
        if { $b_xport_src_files } {
          set dir "srcs/incl"
        } else {
          set dir "[usf_get_relative_file_path $dir $launch_dir]"
        }
      }
    }
    if { [lsearch -exact $uniq_incl_dirs $dir] == -1 } {
      lappend uniq_incl_dirs $dir
      lappend incl_dirs "$dir"
    }
  }

  # add boost header references for include dir
  if { "xsim" == $simulator } {
    set boost_dir "%xv_boost_lib_path%"
    if {$::tcl_platform(platform) == "unix"} {
      set boost_dir "\$xv_boost_lib_path"
    }
  }
  lappend incl_dirs "$boost_dir"

  return $incl_dirs
}

proc usf_fetch_header_from_export { vh_file b_is_bd dynamic_repo_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:
  #
  variable a_sim_cache_all_design_files_obj

  # get the header file object
  set vh_file_obj  {}
  if { [info exists a_sim_cache_all_design_files_obj($vh_file)] } {
    set vh_file_obj $a_sim_cache_all_design_files_obj($vh_file)
  } else {
    set vh_file_obj [lindex [get_files -all -quiet $vh_file] 0]
  }
  set ip_file ""
  # get the ip name from parent composite filename
  set props [list_property -quiet $vh_file_obj]
  if { [lsearch $props "PARENT_COMPOSITE_FILE"] != -1 } {
    set ip_file [get_property PARENT_COMPOSITE_FILE $vh_file_obj]
  } else {
    return $vh_file 
  }

  if { $ip_file eq "" } {
    return $vh_file 
  }

  # fetch the output directory from the IP this header file belongs to
  set ip_filename [file tail $ip_file]
  set ip_name     [file root $ip_filename]
  set output_dir {}
  set ip_obj [lindex [get_ips -quiet -all $ip_name] 0]
  if { "" != $ip_obj } {
    set output_dir [get_property -quiet IP_OUTPUT_DIR $ip_obj]
  } else {
    set output_dir [get_property -quiet NAME [get_files -all $ip_filename]]
    set output_dir [file dirname $output_dir]
  }
  if { [string length $output_dir] == 0 } {
    return $vh_file
  }

  # find out the extra sub-file path from the header source file wrt the output directory value,
  # and construct the output file path
  set vh_filename   [file tail $vh_file]
  set vh_file_dir   [file dirname $vh_file]
  set sub_file_path [usf_get_sub_file_path $vh_file_dir $output_dir]

  set output_file_path "$output_dir/$sub_file_path"

  if { [regexp -nocase "sources_1/bd" $output_file_path] } {
    # traverse the path
    set dir   [string map {\\ /} $output_file_path]
    set dirs  [split $dir {/}]
    set index [lsearch $dirs "sources_1"]
    incr index
    set bd_path [join [lrange $dirs $index end] "/"]
    set ip_user_vh_file "$dynamic_repo_dir/$bd_path/$vh_filename"
    if { [file exists $ip_user_vh_file] } {
      return $ip_user_vh_file
    }
  }

  # fall-back : construct full repo dynamic file path
  set sub_dir "ip"
  if { $b_is_bd } {
    set sub_dir "bd"
  }
  set ip_user_vh_file [file join $dynamic_repo_dir $sub_dir $ip_name $sub_file_path $vh_filename]
  if { [file exists $ip_user_vh_file] } {
    return $ip_user_vh_file
  }

  return $vh_file
}

proc usf_get_file_cmd_str_c { file file_type b_xpm global_files_str l_incl_dirs_opts_arg l_C_incl_dirs_opts_arg _ststemCLibraryPaths _ststemCLibraryNames {xpm_library {}} {xv_lib {}}} {
  # Summary:
  # Argument Usage:
  # Return Value:

  variable properties
  upvar $l_incl_dirs_opts_arg l_incl_dirs_opts
  upvar $l_C_incl_dirs_opts_arg l_C_incl_dirs_opts
  variable a_sim_cache_all_design_files_obj
  set dir             $properties(launch_directory)
  set b_absolute_path $properties(use_absolute_paths)
  set cmd_str {}
  set associated_library $properties(associatedLibrary)
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
    if { [get_param "project.enableCentralSimRepo"] } {
      # no op
    } else {
      if { $properties(b_extract_ip_sim_files) } {
        set xcix_ip_path [get_property core_container $file_obj]
        if { {} != $xcix_ip_path } {
          set ip_name [file root [file tail $xcix_ip_path]]
          set ip_ext_dir [get_property ip_extract_dir [get_ips -all -quiet $ip_name]]
          set ip_file "[usf_get_relative_file_path $file $ip_ext_dir]"
          # remove leading "../"
          set ip_file [join [lrange [split $ip_file "/"] 1 end] "/"]
          set file [file join $ip_ext_dir $ip_file]
        } else {
          # set file [extract_files -files [list "$file"] -base_dir $dir/ip_files]
        }
      }
    }
  } else { ; # File object is not defined. Check if this is an XPM file...
    if { ($b_xpm) && ([string length $xpm_library] != 0)} {
      set associated_library $xpm_library
    }
  }

  if { {} != $xv_lib } {
    set associated_library $xv_lib
  }
  
  set b_static_ip_file 0
  set ip_file {}
  if { !$b_xpm } {
    set ip_file [usf_cache_result {usf_get_top_ip_filename $file}]
    set file [usf_get_ip_file_from_repo $ip_file $file $associated_library $dir b_static_ip_file]
  }
  
  if { [get_param "project.writeNativeScriptForUnifiedSimulation"] } {
    # no op
  } else {
    # any spaces in file path, escape it?
    regsub -all { } $file {\\\\ } file
  }

  set compiler [usf_get_compiler_name $file_type]
  set arg_list [list]
  if { [string length $compiler] > 0 } {
    lappend arg_list $compiler
    usf_aldec_append_compiler_options $compiler $file_type arg_list

    if { ({g++} == $compiler) || ({gcc} == $compiler) } {
       # no work library required
    } else {
      set arg_list [linsert $arg_list end "$global_files_str"]
    }
  }
  usf_append_other_options $compiler $file_type $global_files_str arg_list

  # append include dirs for verilog sources
  if { {vlog} == $compiler } {
    set arg_list [concat $arg_list $l_incl_dirs_opts]
  } elseif { {ccomp} == $compiler } {
	set arg_list [concat $arg_list $_ststemCLibraryPaths] 
    set arg_list [concat $arg_list $l_C_incl_dirs_opts]
	set arg_list [concat $arg_list $_ststemCLibraryNames]
  } elseif { ({g++} == $compiler) || ({gcc} == $compiler) } {
    set arg_list [concat $arg_list $_ststemCLibraryPaths]
    set arg_list [concat $arg_list $l_C_incl_dirs_opts]
	set arg_list [concat $arg_list $_ststemCLibraryNames]
  }
 
  set file_str [join $arg_list " "]
  set type [usf_get_file_type_category $file_type]
  set cmd_str "$type|$file_type|$associated_library|$file_str|\"$file\"|$b_static_ip_file"
  
  return $cmd_str
}

proc usf_cache_result {args} {
  # Summary: Return calculated results if they exists else execute the command args
  #          NOTE: do not use this for procs containing upvars (in general), but to
  #          cache a proc that use upvar, see (a_cache_get_dynamic_sim_file_bd)
  # Argument Usage:
  # Return Value:
  variable a_sim_cache_result

  # replace "[" and "]" with "|"
  set cache_hash [regsub -all {[\[\]]} $args {|}];
  set cache_hash [uplevel expr \"$cache_hash\"]

  # Verify cache with the actual values
  #puts "CACHE_ARGS=${args}"
  #puts "CACHE_HASH=${cache_hash}"
  #if { [info exists a_sim_cache_result($cache_hash)] } {
  #  #puts " CACHE_EXISTS"
  #  set old $a_sim_cache_result($cache_hash)
  #  set a_sim_cache_result($cache_hash) [uplevel eval $args]
  #  if { "$a_sim_cache_result($cache_hash)" != "$old" } {
  #    error "CACHE_VALIDATION: difference detected, halting flow\n OLD: ${old}\n NEW: $a_sim_cache_result($cache_hash)"
  #  }
  #  return $a_sim_cache_result($cache_hash)
  #}

  # NOTE: to disable caching (with this proc) comment this block
  if { [info exists a_sim_cache_result($cache_hash)] } {
    # return evaluated result
    return $a_sim_cache_result($cache_hash)
  }
  # end NOTE

  # evaluate first time
  return [set a_sim_cache_result($cache_hash) [uplevel eval $args]]
}

proc isSystemCEnabled {} {
	variable properties

	if { $properties(b_int_systemc_mode) } {
		return 1
	}

	return 0
}

proc usf_find_ip { name } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set null_ip_obj {}
  foreach ip_obj [get_ips -all -quiet] {
    set ipdef [get_property -quiet IPDEF $ip_obj]
    set ip_name [lindex [split $ipdef ":"] 2]
    if { [string first $name $ip_name] != -1} {
      return $ip_obj
    }
  }
  return $null_ip_obj
}

proc usf_get_shared_ip_libraries { clibs_dir } {
  # Summary:
  # Argument Usage:
  # Return Value:

  set shared_ip_libs [list]
  set file [file normalize [file join $clibs_dir ".cxl.stat"]]
  if { ![file exists $file] } {
    return $shared_ip_libs
  }

  set fh 0
  if { [catch {open $file r} fh] } {
    return $shared_ip_libs
  }
  set lib_data [split [read $fh] "\n"]
  close $fh

  foreach line $lib_data {
    set line [string trim $line]
    if { [string length $line] == 0 } { continue; }
    if { [regexp {^#} $line] } { continue; }
    
    set tokens [split $line {,}]
    set library [string trim [lindex $tokens 0]]
    set shared_lib_token [lindex $tokens 3]
    if { {} != $shared_lib_token } {
      set lib_tokens [split $shared_lib_token {=}]
      set is_shared_lib [string trim [lindex $lib_tokens 1]]
      if { {1} == $is_shared_lib } {
        lappend shared_ip_libs $library
      }
    }
  }
  return $shared_ip_libs
}

proc getSystemCLibrary {} {
	variable properties

#	return $properties(associatedLibrary)
	return lib_$properties(project_name)
}

proc usf_add_c_files_from_xci { comp_file c_filter c_files_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $c_files_arg c_files

  set ip_name [file root [file tail $comp_file]]
  set ip [get_ips -quiet -all $ip_name]
  if { "" != $ip } {
    set selected_sim_model [string tolower [get_property -quiet selected_sim_model $ip]]
    if { "tlm" == $selected_sim_model } {
      foreach ip_file_obj [get_files -quiet -all -filter $c_filter -of_objects $ip] {
        set used_in_values [get_property "USED_IN" $ip_file_obj]
        if { [lsearch -exact $used_in_values "ipstatic"] != -1 } {
          continue;
        }
        set c_files [concat $c_files $ip_file_obj]
      }
    }
  }
}

proc usf_print_shared_lib_type_info { } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_sim_cache_lib_type_info
  set fmt {%-50s%-2s%-10s}
  set sep ":"
  set libs [list]
  set types [list]
  foreach {library type} [array get a_sim_cache_lib_type_info] {
    lappend libs $library
    lappend types $type
  }
  puts "--------------------------------------------------------------------"
  puts "Shared libraries:-"
  puts "--------------------------------------------------------------------"
  puts " LIBRARY                                            TYPE"
  puts "--------------------------------------------------------------------"
  foreach lib $libs type $types {
    puts [format $fmt $lib $sep $type]
    puts "--------------------------------------------------------------------"
  }
  puts ""
}

proc usf_print_shared_lib_info { } {
  # Summary:
  # Argument Usage:
  # Return Value:
 
  variable a_shared_library_path_coln
  set fmt {%-25s%-2s%-80s}
  set sep ":"
  set libs [list]
  set dirs [list]
  foreach {library lib_dir} [array get a_shared_library_path_coln] {
    lappend libs $library
    lappend dirs $lib_dir
  }
  puts "-----------------------------------------------------------------------------------------------------------"
  puts "Extracted shared library path information"
  puts "-----------------------------------------------------------------------------------------------------------"
  foreach lib $libs dir $dirs {
    puts [format $fmt $lib $sep $dir]
  }
  puts "-----------------------------------------------------------------------------------------------------------"
}

proc usf_get_common_xpm_library {} {
	return "xpm"
}

proc usf_get_common_xpm_vhdl_files {} {
	set files [list]
	# is override param dir specified?
	set ip_dir [ get_param "project.xpm.overrideIPDir" ]
	
	if { ({} != $ip_dir) && [file exists $ip_dir] } {
		set comp_file "$ip_dir/xpm_VCOMP.vhd"
		if { ![ file exists $comp_file ] } {
			set file [usf_get_path_from_data "ip/xpm/xpm_VCOMP.vhd"]	
			set comp_file $file

			send_msg_id SIM-[usf_aldec_getSimulatorName]-99 WARNING "The component file does not exist! '$comp_file'. Using default: '$file'\n"
		}
		lappend files $comp_file
	} else {
		lappend files [usf_get_path_from_data "ip/xpm/xpm_VCOMP.vhd"]
	}

	return $files
}

proc usf_get_path_from_data { path_from_data } {
  set data_dir [ rdi::get_data_dir -quiet -datafile $path_from_data ]
  return [ file normalize [ file join $data_dir $path_from_data ] ]
}

proc getVcomOptions { } {
	variable properties

	set simset [ get_filesets $properties(simset) ]
	set vcomOptions [ list ]

	usf_aldec_appendCompilationCoverageOptions vcomOptions vcom

	if { [ get_property [ usf_aldec_getPropertyName COMPILE.VHDL_RELAX ] $simset ] } {
		lappend vcomOptions "-relax"
	}
 
	if { [ get_property [ usf_aldec_getPropertyName COMPILE.DEBUG ] $simset ] } {
		lappend vcomOptions "-dbg"
	}

	if { [ get_property INCREMENTAL $simset ] == 1 } {
		lappend vcomOptions "-incr"
	}
  
	set more_vcom_options [ string trim [ get_property [ usf_aldec_getPropertyName COMPILE.VCOM.MORE_OPTIONS ] $simset ] ]
	if { {} != $more_vcom_options } {
		set vcomOptions [ linsert $vcomOptions end "$more_vcom_options" ]
	}

	return [join $vcomOptions " "]
}

proc getVlogOptions { } {
	variable properties

	set vlogOptions [ list ]
	set simset [ get_filesets $properties(simset) ]
	set designLibraries [ getDesignLibraries $properties(designFiles) ]

	usf_aldec_appendCompilationCoverageOptions vlogOptions vlog

	if { [ get_property [ usf_aldec_getPropertyName COMPILE.DEBUG ] $simset ] } {
		lappend vlogOptions "-dbg"
	}

	if { [ get_property INCREMENTAL $simset ] == 1 } {
		lappend vlogOptions "-incr"
	}

	if { [ llength [ getXpmLibraries ] ] > 0 && [ lsearch -exact $designLibraries "xpm" ] == -1 } {
		lappend vlogOptions "-l xpm"
	}

	set more_vlog_options [ string trim [ get_property [ usf_aldec_getPropertyName COMPILE.VLOG.MORE_OPTIONS ] $simset ] ]
	if { {} != $more_vlog_options } {
		set vlogOptions [ linsert $vlogOptions end "$more_vlog_options" ]
	}

	set xilinxVipWasAdded 0
	foreach lib $designLibraries {
		if { [ string length $lib ] == 0 } {
			continue;
		}

		lappend vlogOptions "-l"
		lappend vlogOptions "$lib"

		if { $lib == "xilinx_vip" } {
			set xilinxVipWasAdded 1
		}
	}

	if { $xilinxVipWasAdded == 0 && [ get_param "project.usePreCompiledXilinxVIPLibForSim" ] && [ is_vip_ip_required ] } {
		lappend vlogOptions "-l"
		lappend vlogOptions "xilinx_vip"
	}

	return [join $vlogOptions " "]
}

proc addToUniqueList { _currentList _newItem } {
	upvar $_currentList currentList

	foreach item $currentList {
		if { $item == $_newItem } {
			return
		}
	}

	lappend currentList $_newItem
}

proc usf_write_launch_mode_for_vitis { _scriptFileHandle } {
  variable properties

  puts $_scriptFileHandle "\n# set simulator launch mode"

  if { $properties(only_generate_scripts) || $properties(batch_mode_enabled) } {
    puts $_scriptFileHandle "mode=\"-c\""
  } else {
    puts $_scriptFileHandle "mode=\"-gui\""
  }

  puts $_scriptFileHandle "arg=\$\{1:-default\}"
  puts $_scriptFileHandle "if \[ \$arg = \"off\" \] || \[ \$arg = \"batch\" \]; then"
  puts $_scriptFileHandle "  mode=\"-c\""
  puts $_scriptFileHandle "elif \[ \$arg = \"gui\" \]; then"
  puts $_scriptFileHandle "  mode=\"-gui\""
  puts $_scriptFileHandle "fi\n"
}

proc cacheAllDesign { } {
  variable a_sim_cache_all_design_files_obj

  foreach fileName [ get_files -quiet -all ] {
    set name [ get_property -quiet "name" $fileName ]
    set a_sim_cache_all_design_files_obj($name) $fileName
  }
}

}

#
# not used currently
#
namespace eval ::tclapp::aldec::common::helpers {
proc usf_get_top { top_arg } {
  # Summary:
  # Argument Usage:
  # Return Value:

  upvar $top_arg top
  set fileset_object [get_filesets $properties(simset)]
  set fs_name [get_property "NAME" $fileset_object]
  set top [get_property "TOP" $fileset_object]
  if { {} == $top } {
    send_msg_id USF-[usf_aldec_getSimulatorName]-81 ERROR "Top module not set for fileset '$fs_name'. Please ensure that a valid \
       value is provided for 'top'. The value for 'top' can be set/changed using the 'Top Module Name' field under\
       'Project Settings', or using the 'set_property top' Tcl command (e.g. set_property top <name> \[current_fileset\])."
    return 1
  }
  return 0
}

}

}
