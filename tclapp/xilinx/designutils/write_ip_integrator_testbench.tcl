package require Vivado 1.2015.1

namespace eval ::tclapp::xilinx::designutils {	namespace export write_ip_integrator_testbench }

proc ::tclapp::xilinx::designutils::write_ip_integrator_testbench {{args ""}} {
	# Summary: Create a testbench for an IP Integrator design and optionally add it to the current project

	#Argument Usage:
	# [-verilog]: This option specifies the output language for the testbench.  The default language is VHDL.
	# [-output <arg>]: This option specifies the path and name of the output file.  The default path is (pwd) and default name is test_<infile>< .vhd | .v >.
	# [-addToProject]: This option adds the output file to the Simulation Sources and sets it as top.  The default is to not add it to the project but display the commands in the Tcl console.
	# [<infile.bd>]: This option specifies which IP Integrator design to create a test bench for.  The default is the \[current_bd_design\].  <infile.bd> must be the last argument.

	# Return Value:
	# 0

	# Categories: xilinxtclstore, simulation, ip integrator

	return [uplevel [concat [list ::tclapp::xilinx::designutils::write_ip_integrator_testbench::write_ip_integrator_testbench] $args]]
}

eval [list namespace eval ::tclapp::xilinx::designutils::write_ip_integrator_testbench {
} ]


proc ::tclapp::xilinx::designutils::write_ip_integrator_testbench::putsf {arg1 arg2} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

	if {$arg1 eq 1} {
		puts $arg2
	} elseif {$arg1 ne 0} {
		puts $arg1 $arg2
	}
}

proc ::tclapp::xilinx::designutils::write_ip_integrator_testbench::lshift {inputlist} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}

proc ::tclapp::xilinx::designutils::write_ip_integrator_testbench::write_ip_integrator_testbench {{args ""}} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

	set error 0
	set help 0
	set returnString 0
	set debugMode 0

	set _outputLanguage "vhd"
	set _outputFile ""
	set _addToProject 0
	set _inputFile ""
	putsf $debugMode "Checking Variables"

	while {[llength $args]} {
		set name [string tolower [lshift args]]
		switch -regexp -- $name {
			-verilog -
			{^-v(e(r(i(l)og?)?)?)?$} {
				set _outputLanguage "v"
			}
			-vhdl -
			{^-vh(dl?)?$} {
				set _outputLanguage "vhd"
			}
			-output -
			{^-o(u(t(p(ut?)?)?)?)?$} {
				set _outputFile [lshift args]
				if {$_outputFile == {}} {
					puts " -E- no filename specified."
					incr error
				}
			}
			-addtoproject -
			{^-a(d(d(t(o(p(r(o(j(e(ct?)?)?)?)?)?)?)?)?)?)?$} {
				set _addToProject 1
			}
			-help -
			{^-h(e(lp)?)?$} {
				set help 1
			}
		        -usage -
		        {^-u(s(a(ge?)?)?)?$} {
			        set help 1
		        }
			default {
				if {[string match "-*" $name]} {
					puts " -E- option '$name' is not a valid option.  Use the -help option for more details"
					incr error
				} else {
					set _inputFile $name
				}
			}

		}
	}

	if {$help} {
		puts [format {
Usage:
  Name                Description
  -------------------------------
  [-verilog]          Create the testbench in Verilog
  [-output <file>]    Write the testbench using this file location
  [-addToProject]     Run commands to add the testbench to the project and make it active
  [<infile.bd>]       IP Integrator Block Diagram to be used

Categories:
Custom

Description:

  Create a testbench for an IP Integrator design and optionally add it to the current project

Arguments:

  -verilog - (Optional) This option specifies the output language for the testbench.  The default
  language is VHDL. 

  -output - (Optional) This option specifies the path and name of the output file.  The default
  path is (pwd) and default name is test_<infile>< .vhd | .v >.

  -addToProject - (Optional) This option adds the output file to the Simulation Sources and sets
  it as top.  The default is to not add it to the project but display the commands in the Tcl
  console.

  <infile.bd> - (Optional) This option specifies which IP Integrator design to create a test bench
  for.  The default is the [current_bd_design].  <infile.bd> must be the last argument.

Example:

  The following example creates a VHDL testbench based on the current_bd_design and adds it to the
  project:

    write_ip_integrator_testbench -addToProject

  This example creates a Verilog testbench based on the given input file and sets the output files
  path and name:

    write_ip_integrator_testbench -verilog -output \"c:/vipi/testbenches/tb_mydesign.v\" \"c:/vipi/sources/mydesign.v\"
} ]
	return {}
	}






	# Determine File Names
	set _bdName [string map {".bd" ""} $_inputFile]
	if {$_bdName eq ""} {
		set _bdName [current_bd_design]
		if {$_bdName eq ""} {
			puts "No current bd file is open or <infile>$_inputFile does not exist, please open a Block Design or specifiy a valid <infile.bd> to continue"
			return -1
		}
	} else {
		open_bd_design $_inputFile
	}
	set _bdNameFull $_bdName
	set _bdName [lindex [file split [file rootname $_bdName]] end]

	if {$_outputFile eq ""} {
		set _tbName "[pwd]/test_$_bdName.$_outputLanguage"
		set _tbName_noExt_path [file rootname $_tbName]
		set _tbName_noExt [lindex [file split $_tbName_noExt_path ] end]
	} else {
		set _tbName_noExt_path [file rootname $_outputFile]
		set _tbName_noExt [lindex [file split $_tbName_noExt_path ] end]
		set _tbName "$_tbName_noExt_path.$_outputLanguage"
	}


	# Validate to get port sizes
	validate_bd_design -force

	# Process the Design
	set writeThisFile [open $_tbName w]
	if {$_outputLanguage eq "v"} {
		set writeVHDLFile 0
		set writeVerilogFile $writeThisFile
	} else {
		set writeVHDLFile $writeThisFile
		set writeVerilogFile 0
	}

	putsf $writeVHDLFile "library IEEE;\nuse IEEE.STD_LOGIC_1164.ALL;"
	putsf $writeVHDLFile "\nentity $_tbName_noExt is \nend $_tbName_noExt;\n"
	putsf $writeVHDLFile "\narchitecture TB of $_tbName_noExt is\n"
	putsf $writeVerilogFile "`timescale 1ns / 1ps"
	putsf $writeVerilogFile "\nmodule $_tbName_noExt ();\n"
	
	set _bdPorts [get_bd_ports]

	# find all clocks, resets, enables
	foreach {_bdPort} $_bdPorts {
		set _theType [get_property TYPE $_bdPort]
		if {$_theType eq "clk"} {
			lappend _makeClk $_bdPort
			lappend _makeClk [get_property CONFIG.FREQ_HZ $_bdPort]
		}
		if {$_theType eq "rst"} {
			lappend _makeReset $_bdPort
			lappend _makeReset [get_property CONFIG.POLARITY $_bdPort]
		}
	}
	if {[info exists _makeReset] eq 0} {set _makeReset ""}
	if {[info exists _makeClk] eq 0} {set _makeClk ""}

	set _bdIPorts [get_bd_intf_ports -filter {VLNV =~ "*:diff_clock_rtl:*"}]
	# find all clocks, resets, enables
	foreach {_bdIPort} $_bdIPorts {
		if {[get_property CONFIG.FREQ_HZ $_bdIPort] ne ""} {
			foreach {_bdPort} [get_bd_ports -filter {INTF == 1}] {
				if {[string match "$_bdIPort*" $_bdPort]} {
					if {[string tolower [lindex [split $_bdPort ""] end]] eq "p"} {
						lappend _makeClk $_bdPort
						lappend _makeClk [get_property CONFIG.FREQ_HZ $_bdIPort]
						if {$debugMode ne "0"} {puts "$_bdPort has P polarity [get_property CONFIG.POLARITY $_bdPort]"}
					} elseif {[string tolower [lindex [split $_bdPort ""] end]] eq "n"} {
						if {$debugMode ne "0"} {puts "$_bdPort has N polarity [get_property CONFIG.POLARITY $_bdPort]"}
						set _bdPort [string map {"/" ""} $_bdPort ]
						lappend _makeNClk $_bdPort 
						lappend _makeNClk [join [lreplace [split $_bdPort ""] end end "p"] ""]
					}
				}
			}
		}
	}

	# component declaration
	putsf $writeVHDLFile "component $_bdName is\nport ("
	foreach {_bdPort} $_bdPorts {
		set _bdPin [string map {"/" ""} $_bdPort]
		set _bdDir [get_property DIR $_bdPort]
		if {$_bdDir eq "I"} {
			set _bdDir "in"
		} elseif {$_bdDir eq "O"} {
			set _bdDir "out"
		} elseif {$_bdDir eq "IO"} {
			set _bdDir "inout"
		}
		# do I need an IO?
		set _bdLeft [get_property LEFT $_bdPort]
		set _bdRight [get_property RIGHT $_bdPort]
		set _bdVector ""
		set _vbdVector ""
		if {$_bdLeft ne ""} {
			set dto "to"
			if {$_bdLeft > $_bdRight} {set dto "downto"}
			set _bdVector "_VECTOR ($_bdLeft $dto $_bdRight)"
			set _vbdVector "\[$_bdLeft:$_bdRight\]"
		}
		set _semi ";"
		set _comma ","
		if {$_bdPort eq [lindex $_bdPorts end]} {
			set _semi ""
			set _comma ""
		}
		putsf $writeVHDLFile "  $_bdPin : $_bdDir STD_LOGIC$_bdVector$_semi"
		lappend _bdSignals "signal $_bdPin : STD_LOGIC$_bdVector;"
		lappend _bdConnections "  $_bdPin => $_bdPin$_comma"
		if {[lsearch $_makeClk $_bdPort] >= 0} {
			lappend _vbdSignals "reg $_vbdVector $_bdPin;"
		} elseif {[lsearch $_makeReset $_bdPort] >= 0} {
			lappend _vbdSignals "reg $_vbdVector $_bdPin;"
		} else {
			lappend _vbdSignals "wire $_vbdVector $_bdPin;"
		}
		lappend _vbdConnections "  .$_bdPin ($_bdPin)$_comma"
	}
	putsf $writeVHDLFile ");\nend component $_bdName;\n"
	foreach {_bdSignal} $_bdSignals {
		putsf $writeVHDLFile $_bdSignal
	}
	foreach {_vbdSignal} $_vbdSignals {
		putsf $writeVerilogFile $_vbdSignal
	}
	putsf $writeVHDLFile "begin\n"
	putsf $writeVHDLFile "DUT: component $_bdName port map ("
	putsf $writeVerilogFile "$_bdName DUT ("
	foreach {_bdConnection} $_bdConnections {
		putsf $writeVHDLFile $_bdConnection
	}
	foreach {_vbdConnection} $_vbdConnections {
		putsf $writeVerilogFile $_vbdConnection
	}
	putsf $writeVHDLFile ");\n"
	putsf $writeVerilogFile ");\n"

	# clocks
	if {[info exists _makeClk]} {}
	if {$_makeClk ne ""} {
		foreach {_clk _freq} $_makeClk {
			set _halfPeriod [expr double(500000000) / double($_freq)]
			putsf $writeVHDLFile "process\nbegin"
			set _bdPin [string map {"/" ""} $_clk]
			putsf $writeVHDLFile "  $_bdPin <= '0';"
			putsf $writeVHDLFile "  wait for $_halfPeriod ns;"
			putsf $writeVHDLFile "  $_bdPin <= '1';"
			putsf $writeVHDLFile "  wait for $_halfPeriod ns;"
			putsf $writeVHDLFile "end process;"

#			set _halfPeriod [expr ($_halfPeriod * 1000)]
			putsf $writeVerilogFile "always\nbegin"
			putsf $writeVerilogFile "  $_bdPin = 0;"
			putsf $writeVerilogFile "  #$_halfPeriod;"
			putsf $writeVerilogFile "  $_bdPin = 1;"
			putsf $writeVerilogFile "  #$_halfPeriod;"
			putsf $writeVerilogFile "end"
		}
	}
	if {[info exists _makeNClk]} {
		foreach {_clkn _clkp} $_makeNClk {
			putsf $writeVHDLFile "$_clkn <= NOT $_clkp;"
			putsf $writeVerilogFile "assign $_clkn = !$_clkp;"
		}
	}
	
	# resets
	if {[info exists _makeReset]} {}
	if {$_makeReset ne ""} {
		foreach {_reset _polarity} $_makeReset {
			if {$_polarity eq "ACTIVE_LOW"} { 
				set _asserted "0"
				set _deasserted "1"
			} else {
				set _deasserted "0"
				set _asserted "1"
			}
			putsf $writeVHDLFile "process\nbegin"
			set _bdPin [string map {"/" ""} $_reset]
			putsf $writeVHDLFile "  $_bdPin <= '$_asserted';"
			putsf $writeVHDLFile "  wait for 100 ns;"
			putsf $writeVHDLFile "  $_bdPin <= '$_deasserted';"
			putsf $writeVHDLFile "  wait;"
			putsf $writeVHDLFile "end process;"

			putsf $writeVerilogFile "initial\nbegin"
			putsf $writeVerilogFile "  $_bdPin = $_asserted;"
			putsf $writeVerilogFile "  #100;"
			putsf $writeVerilogFile "  $_bdPin = $_deasserted;"
			putsf $writeVerilogFile "end"
		}
	}
	
	putsf $writeVHDLFile "\nend TB;\n"
	putsf $writeVerilogFile "\nendmodule\n"
	close $writeThisFile


	# mark debugs
	foreach {_bdIntfNet} [get_bd_intf_nets] {
		if {[get_property HDL_ATTRIBUTE.MARK_DEBUG $_bdIntfNet] eq "true"} {
			if {$debugMode ne "0"} {puts " Resolvng MARK_DEBUG on $_bdIntfNet"}
			set _connectedIntfs [get_bd_intf_pins -of_objects $_bdIntfNet]
			set _connectedPins [get_bd_pins -of_objects [get_bd_intf_pins -of_objects $_bdIntfNet]]
			set _connectedPinsFull $_connectedPins
			foreach {_connectedIntf} $_connectedIntfs {
				if {$debugMode ne "0"} {puts "  Resolvng pins on $_connectedIntf"}
				set _connectedPins [string map [list [string tolower $_connectedIntf] ""] $_connectedPins]
			}
			set _connectedPinsTmp ""
			foreach {_connectedPin} $_connectedPins {
				lappend _connectedPinsTmp [lindex [split $_connectedPin "_"] end]
			}
			set _connectedPins $_connectedPinsTmp
			if {$debugMode ne "0"} {puts "  Finding underlying nets with 2+ connections"}
			if {[info exists _pinMatches] ne 0} {unset _pinMatches}
			foreach {_connectedPin} $_connectedPins {
				if {$_connectedPin eq ""} {continue}
				#if {$debugMode ne "0"} {puts "  Checking $_connectedPin"}
				set _pinSpots [lsearch -all $_connectedPins $_connectedPin]
				if {[llength $_pinSpots] > 1} {
					if {[info exists _pinMatches] eq 0 } {
						if {$debugMode ne "0"} {puts "   Adding $_connectedPin at indices $_pinSpots"}
						lappend _pinMatches $_pinSpots 
					} elseif {[lsearch $_pinMatches $_pinSpots] < 0} {
						if {$debugMode ne "0"} {puts "   Adding $_connectedPin at indices $_pinSpots"}
						lappend _pinMatches $_pinSpots 
					}
				}
			}
			if {[info exists _pinMatches] ne 0} {
				foreach {_spots} $_pinMatches {
					foreach {_spot} $_spots {
						#if {$debugMode ne "0"} {puts "  Resolving index $_spot"}
						set _cpfSpot [lindex $_connectedPinsFull $_spot]
						if {[get_property DIR $_cpfSpot] eq "O"} {
							if {$debugMode ne "0"} {puts "   Adding $_cpfSpot to waveform under $_bdIntfNet divider"}
							dict set divider $_bdIntfNet $_cpfSpot 1
							lappend _addProbeIntf $_cpfSpot
						}

					}
				}
			}
		}
	}
	foreach {_bdNet} [get_bd_nets] {
		if {[get_property HDL_ATTRIBUTE.MARK_DEBUG $_bdNet] eq "true"} {
			if {$debugMode ne "0"} {puts " Resolvng MARK_DEBUG on $_bdNet"}
			lappend _addProbe $_bdNet
		}
	}
	#
	set _awName "add_wave_$_bdName.tcl"
	set writeThisFile [open $_awName w]	
	if {[info exists _addProbeIntf]} {
		dict for {_divName _netDict} $divider {
			putsf $writeThisFile "add_wave_divider \"$_divName\""
			dict for {_netIs _nully} $_netDict {
				putsf $writeThisFile "add_wave {{/$_tbName_noExt/DUT$_netIs}}"			}
		}
#		foreach {_bdIntfNet} $_addProbeIntf {
#			putsf $writeThisFile "add_wave {{/$_tbName_noExt/DUT$_bdIntfNet}}"
#		}
	}
	if {[info exists _addProbe]} {
		foreach {_bdIntfNet} $_addProbe {
			putsf $writeThisFile "add_wave {{/$_tbName_noExt/DUT/$_bdIntfNet}}"
		}
	}
	close $writeThisFile


	# final data dump
	if {$_addToProject} {
		add_files -fileset sim_1 -norecurse $_tbName
		set_property top $_tbName_noExt [get_filesets sim_1]
	} else {
		puts "Wrote $_tbName"
		puts " Add to this project with the commands:"
	#	puts "set_property SOURCE_SET sources_1 [get_filesets sim_1]"
		puts "add_files -fileset sim_1 -norecurse $_tbName"
	#	puts "update_compile_order -fileset sim_1"
		puts "set_property top $_tbName_noExt \[get_filesets sim_1\]"
		puts "gedit $_tbName &"
	}

	puts "\n If you get any errors in simulation on port mismatch, please Validate the Block Design (F6)"
	puts "\n To add mark_debug signals to the simulation, after launching \"Simulation\":"
	puts "source [pwd]/$_awName"
	

	if {$error} {
		error " -E- some error(s) happened. Cannot continue"
	}

	return -code ok 0

}
	
