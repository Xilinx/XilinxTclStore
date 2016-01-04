package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export timing_report_to_verilog
}

proc ::tclapp::xilinx::designutils::timing_report_to_verilog {args} {
	# Summary : Convert timing paths to a Verilog structural netlist

	# Argument Usage:
	# [-filename <arg> = xlnx_strip_model]: Output file name for Verilog, Tcl, and XDC files
	# [-force]: Overwrite existing file
	# [-obfuscation]: Creates ambiguious naming for cells, nets, and ports
	# -of_objects <arg>: Get the timing report specified from the get_timing_paths objects
	# [-report_string <arg>]: Timing path report as string from report_timing command (Required if -of_objects is not used)
	# [-usage]: Usage information

	# Return Value:
	# 0 on success

	# Categories: xilinxtclstore, designutils
	
	return [uplevel [concat [list ::tclapp::xilinx::designutils::timing_report_to_verilog::timing_report_to_verilog] $args]]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::timing_report_to_verilog {
} ]

# #########################################################
# timing_report_to_verilog
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::timing_report_to_verilog {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0 -filename xlnx_strip_model -obfuscation 0 -debug 0}
    
    ## Parse arguments from option command line
	while {[llength $args]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
		switch -regexp -- $optionName {
            {-fi(l(e(n(a(m(e)?)?)?)?)?)?$}                        { set opts(-filename)      [lshift args]}
			{-fo(r(c(e)?)?)?$}                                    { set opts(-force)         1}
            {-ob(f(u(s(c(a(t(i(o(n)?)?)?)?)?)?)?)?)?$}            { set opts(-obfuscation)   1}
			{-of(_(o(b(j(e(c(t(s)?)?)?)?)?)?)?)?$}                { set opts(-of_objects)    [lshift args]}
            {-r(e(p(o(r(t(_(s(t(r(i(n(g)?)?)?)?)?)?)?)?)?)?)?)?$} { set opts(-report_string) [lshift args]}
			{-d(e(b(u(g)?)?)?)?$}                                 { set opts(-debug)         1}
            {-h(e(l(p)?)?)?$}                                     { set opts(-help)          1}
            {-u(s(a(g(e)?)?)?)?$}                                 { set opts(-help)          1}			
            default {
                return -code error "ERROR: \[timing_report_to_verilog\] Unknown option '[lindex $args 0]', please type 'timing_report_to_verilog -help' for usage info."
            }
        }
    }
	
	## Display help information
    if {$opts(-help) == 1} {
        puts "timing_report_to_verilog\n"
        puts "Description:"
        puts "  Converts timing paths to a Verilog structural netlist."
        puts ""
        puts "Syntax:"
        puts "  timing_report_to_verilog \[-filename <arg>\] \[-of_objects <arg>\]"
		puts "                           \[-obfuscation\] \[-report_string <arg>\]"
        puts ""
        puts "Returns:"
        puts "  Generates a file containing a structured Verilog netlist and associated contraints for the"
        puts "  timing paths specified"
        puts ""
        puts "Usage:"
        puts "  Name                Description"
        puts "  -------------------------------"
        puts "  \[-filename\]         Output file name for Verilog and XDC files."
        puts "                      Default: xlnx_strip_model"
        puts "  \[-force\]            Overwrites existing file."
		puts "  \[-obfuscation\]      Creates ambiguous naming for cells, nets, and ports."
		puts "                      (Optional)"
		puts "  \[-of_objects\]       Get the timing report specified from the get_timing_paths"
        puts "                      objects."
		puts "                      (Priority over -report_string)"
        puts "  \[-report_string\]    Timing path report as string from report_timing"
		puts "                      (Required if not using -of_objects)"
        puts ""
		puts "Description:"
		puts ""
		puts "  Writes a Verilog Structural netlist from a timing report produced by the Vivado"
		puts "  report_timing command. The Verilog and associated XDC file can be used in Vivado"
		puts "  to simulate the path behavior from a larger design."
		puts ""
        puts "Example:"
		puts ""
		puts "  The following example creates a Verilog structural netlist using the -of_objects option and"
		puts "  the get_timing_paths command for the three paths with the worst calculated slack."
		puts ""
		puts "  timing_report_to_verilog -of_objects \[get_timing_paths -max_paths 3\]"
		puts ""
	    puts "  This next example creates a Verilog structural netlist based on the two timing paths"
        puts "  with the worst calculated slack parsed directly from the timing report."
        puts ""
        puts "  timing_report_to_verilog -filename xlnx_design -report_string \[report_timing -input_pins -max_paths 2 -return_string\]"
        puts ""
        puts "  *NOTE* The report_timing string requires the -input_pins and -return_string switches for proper processing of the report."
		puts ""
        return
    }
	
	## Check if -of_objects or -report_string was used as required
	if {[info exists opts(-of_objects)]==0 && [info exists opts(-report_string)]==0} {
		return -code error "ERROR: \[timing_report_to_verilog\] Switch -report_string or -of_objects is required.  Please use -help for more information."
	} elseif {[info exists opts(-of_objects)]} {
		## Parse Object List Classes
		set objectList [parse_object_list -objects $opts(-of_objects) -klasses {timing_path}]
	} else {
		## Set Timing Report String to the string given as an argument
		set timingReportString $opts(-report_string)
	}
	
	## Check if a Verilog file exists with -filename option and error if -force option is not used
	if {[file exists "$opts(-filename).v"]} {
		## Check if the -force option was used
		if {![info exists opts(-force)]} {
			return -code error "ERROR: \[timing_report_to_verilog\] File $opts(-filename).v exists.  Please rerun with -force option to overwrite the existing file."				
		} else {
			puts "INFO: \[timing_report_to_verilog\] Overwriting $opts(-filename) files as -force option is used."
		}
	}
	
	## Check if -of_objects arguments was processed
	if {[info exists objectList]} {
		## Check if object list has at least one object
		if {[llength $objectList]==0} {
			return -code error "ERROR: \[timing_report_to_verilog\] No Timing Path Objects found from -of_objects option."
		} else {
			## Report timing on the list of timing paths
			set timingReportString [report_timing -of_objects $objectList -return_string]
		}
	}
	
    ##########################################################
    # Debug
    ##########################################################
    # Output debug only when the user sets the option
	if {$opts(-debug)==1} {
		proc dbg {msg} { puts "DEBUG: \[[lindex [info level [expr [info level]-2]] 0]\] $msg" }
		proc dbgVar {varName} {
			upvar 1 $varName varValue
			dbg "$varName = '$varValue'"
		}
	} else {
		proc dbg {msg} {}
		proc dbgVar {varName} {}
	}
		
	## Parse the timing report and return the timing path cell data structure objects
    set timingPathCellsDict [parse_timing_report -report_string $timingReportString -obfuscation $opts(-obfuscation)] 
	
	## Check to ensure at least one timing path dictionary exists before processing
	if {[llength $timingPathCellsDict]==0} {
		puts "ERROR: \[[get_current_proc_name]\] No timing paths found in timing report. Please check if timing report contains any timing paths or -return_string option was used.  If so, please contact script owner."
		return -code error
	} else {
		## Initialize the Verilog Objects dictionary
		set verilogObjectsDict [dict create]
		
		## Loop through each path object in the timing path dictionary
		foreach cellTimingPathDictID [dict keys $timingPathCellsDict] {
			## Set the Verilog object dictionary from the path object
			set verilogDict [path_to_verilog_dict -dict_object [dict get $timingPathCellsDict $cellTimingPathDictID] -verilog_dict $verilogObjectsDict]
			## Store the Verilog object in the Verilog Object dictionary
			dict set verilogObjectsDict [dict get $verilogDict orig_name] $verilogDict
		}
	}
	
    ## Write the Verilog test case based on the Verilog objects
	write_verilog_testcase -design_name $opts(-filename) -dict $verilogObjectsDict
	
	return 0
}

# #########################################################
# parse_timing_path_objects
# (INCOMPLETE - Still waiting for additional support)
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::parse_timing_path_objects {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0 -obfuscation 0}
    
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
		    {-d(i(c(t)?)?)?$}                              { set opts(-dict)          [lshift args]}
			{-n(a(m(e)?)?)?$}                              { set opts(-name)          [lshift args]}
            {-ob(f(u(s(c(a(t(i(o(n)?)?)?)?)?)?)?)?)?$}     { set opts(-obfuscation)   [lshift args]}
			{-of(_(o(b(j(e(c(t(s)?)?)?)?)?)?)?)?$}         { set opts(-of_objects)    [lshift args]}
            {-h(e(l(p)?)?)?$}                              { set opts(-help)          1}
            default {
                return -code error "ERROR: \[parse_timing_path_objects\] Unknown option '[lindex $args 0]', please type 'parse_timing_path_objects -help' for usage info."
            }
        }
    }	
	
	## Check if the -of_objects option was used and validate the objects passed, error if not
	if {[info exists opts(-of_objects)]} {
		## Parse Object List Classes
		set objectList [parse_object_list -objects $opts(-of_objects) -klasses {timing_path}]
	} else {
		return -code error "ERROR: \[parse_timing_path_objects\] Switch -of_objects is required.  Please use -help for more information."
	}
	
	## Check if the -dict option was used and create if necessary
	if {[info exists opts(-dict)]} {
		## Create the dictionary to store the timing path objects
		set opts(-dict) [dict create]
	}
	
	## Initialize path index to 0
	set pathIndex 0
	
	## Loop though each timing object
	foreach timingObj $objectList {
		## Get the list of pins of the timing object
		set pinList [get_pins -quiet -of_objects $timingObj]
		
		## Get the startpoint pin name of the timing object 
		set startpointPinName [get_property -quiet STARTPOINT_PIN $timingObj]
		
		## Check if the startpoint is already in the timing path pin list
		if {[lsearch -exact $pinList $startpointPinName]<0} {
			## Append the startpoint to the front of the list
			lunshift pinList $startpointPinName
		}
		
		## Get the endpoint pin name of the timing object 
		set endpointPinName [get_property -quiet ENDPOINT_PIN $timingObj]
		
		## Check if the endpoint is already in the timing path pin list
		if {[lsearch -exact $pinList $startpointPinName]<0} {
			## Append the endpoint to the end of the list
			lappend pinList $startpointPinName
		}
		
		## Loop though each pin of the timing object pin list
		foreach pinName $pinList {
			## Get the pin object from the pin name
			set pinObj [get_pins -quiet $pinName]
			
			## Check if the pin object was found
			if {[llength $pinObj]==0} {
				## Check if the pin name is a port
				set portObj [get_ports -quiet $pinName]
				
				## Check if the port object was found
				if {[llength $portObj]==0} {
					return -code error "ERROR: \[parse_timing_path_objects\] Unable to find pin/port object $pinName."
				} else {
					## Obfuscate name is desired
					if {$opts(-obfuscation)==1} {
						## Rename based on instance name argument
						set newPortName "$opts(-name)\_$pathIndex"
					} else {
						## Remove hierarchy from port object
						set newPortName [regsub -all {\/} [get_property NAME $portObj] "_"]
						set newPortName [regsub -all {\[} $newPortName "_"]
						set newPortName [regsub -all {\]} $newPortName "_"]
						set newPortName [regsub -all {\.} $newPortName "_"]
						set newPortName [regsub -all {\-} $newPortName "_"]
					}
					
					## Check if Port already defined in path dictionary, if not add to the dictionary
					if {![path_cell_name_exists? -dict $opts(-dict) -value $portObj]} {	
						## Add Port object to Path Dictionary
						dict set opts(-dict) "$opts(-name)$pathIndex" type        "port"
						dict set opts(-dict) "$opts(-name)$pathIndex" name        $portObj
						dict set opts(-dict) "$opts(-name)$pathIndex" direction   [get_property -quiet DIRECTION $portObj]
						dict set opts(-dict) "$opts(-name)$pathIndex" net_name    $newPortName
						dict set opts(-dict) "$opts(-name)$pathIndex" tag         $opts(-name)
						dict set opts(-dict) "$opts(-name)$pathIndex" index       $pathIndex
						
						dbg "DEBUG: Dict $opts(-name)$pathIndex: [dict get $opts(-dict) "$opts(-name)$pathIndex"]"
						
						## Store the current output value for next iteration
						set previousOutputName $newPortName
						
						dbg "DEBUG: Previous Output Name: $previousOutputName"
						
						## Increment the Path Index
						incr pathIndex
					} else {
						dbg "DEBUG: $opts(-name)$pathIndex: Port Object $portObj already exists in path."
						
						## Get the previous path instance from the Path Dictionary
						set previousPathDict [get_path_dict_by_cell_name -dict $opts(-dict) -value $portObj]
						## Get the output net name for the next iteration
						set previousOutputName [dict get $previousPathDict net_name]
						
						dbgVar previousOutputName
					}					
				}
			} else {
				## Get the cell object associated with the pin object
				set cellObj [get_cells -quiet -of_objects $pinObj]
			
				## Check if Cell already exists in Path Dictionary
				if {[path_cell_name_exists? -dict $opts(-dict) -value $cellObj]} {
					## Get the previous path instance from the Path Dictionary
					set previousPathDict [get_path_dict_by_cell_name -dict $opts(-dict) -value $cellObj]
					
					## Check if the direction of the pin object is an input
					if {[get_property -quiet DIRECTION $pinObj] eq "IN"} {
						## Get the input pin dictionary from the path instance
						set previousInputPinsDict [dict get $previousPathDict input_pins]
						
						## Check if input pin doesn't already exists in the input pin dictionary
						if {![dictionary_value_exists? -dict $previousInputPinsDict -key "name" -value $pinObj]} {
							dbg "DEBUG: \[parse_timing_path_objects\] Adding new input to previous cell path."
							
							## Check if previous output value is defined
							if {$previousOutputName ne ""} { 
								## Add current input pin object to Input Pin Dictionary
								dict set previousInputPinsDict $pinObj type "pin"
								dict set previousInputPinsDict $pinObj name $pinObj
								dict set previousInputPinsDict $pinObj net_name $previousOutputName
							} else {
								return -code error "ERROR: \[parse_timing_path_objects\] Previous Output Path is undefined. Please contact script owner."		 							
							}
						}
						
						## Update the dictionary with the updated input pins for the cell object
						dict set previousPathDict input_pins $previousInputPinsDict

					## Check if the direction of the pin object is an output
					} elseif {[get_property -quiet DIRECTION $pinObj] eq "OUT"} {
						## Get the output pin dictionary from the path instance
						set previousOutputPinsDict [dict get $previousPathDict output_pins]
						
						## Check if output pin doesn't already exists in the output pin dictionary
						if {![dictionary_value_exists? -dict $previousOutputPinsDict -key "name" -value $pinObj]} {
							dbg "DEBUG: \[parse_timing_report_paths\] Adding new output to previous cell path."
							
							## Obfuscate name of the output net if desired
							if {$opts(-obfuscation)==1} {
								## Rename based on instance name argument
								set newNetName "$opts(-name)\_$pathIndex\_wire"
							} else {
								## Get the net object from the output pin object
								set netObj [get_nets -quiet -of_objects $outputPinObj]
								
								## Remove hierarchy from net object
								set newNetName [regsub -all {\/} [get_property NAME $netObj] "_"]
								set newNetName [regsub -all {\[} $newNetName "_"]
								set newNetName [regsub -all {\]} $newNetName "_"]
								set newNetName [regsub -all {\.} $newNetName "_"]
								set newNetName [regsub -all {\-} $newNetName "_"]
								
								## Append wire to the name to avoid collision with cell instance names
								append newNetName "_wire"
							}
							
							## Add current output pin object to Output Pin Dictionary
							dict set previousOutputPinsDict $pinObj type "pin"
							dict set previousOutputPinsDict $pinObj name $pinObj
							dict set previousOutputPinsDict $pinObj net_name $newNetName
							
							## Set the previous output object dictionary to the newly created output pin
							set previousOutputName [dict get $previousOutputPinsDict $pinObj net_name]
							
							dbgVar previousOutputName
						} else {
							## Set the previous output object dictionary to the previously created output pin object for the next iteration
							set previousOutputName [dict get $previousOutputPinsDict $pinObj net_name]
							
							dbgVar previousOutputName
						}
						
						## Update the dictionary with the updated output pins for the cell object
						dict set previousPathDict output_pins $previousOutputPinsDict
						
					## Error if direction is neither in nor out
					} else {
						return -code error "ERROR: \[parse_timing_path_objects\] Unable to determine pin direction [get_property -quiet DIRECTION $pinObj] for pin $pinObj."
					}
					
					## Update the dictionary with the updated path with the updated pins
					dict set opts(-dict) "[dict get $previousPathDict tag][dict get $previousPathDict index]" $previousPathDict

				## Create New Dictionary for Cell Object
				} else {
					## Obfuscate name is desired
					if {$opts(-obfuscation)==1} {
						## Rename based on instance name argument
						set newCellName "$opts(-name)$pathIndex"
					} else {
						## Remove hierarchy from port object
						set newCellName [regsub -all {\/} [get_property NAME $cellObj] "_"]
						set newCellName [regsub -all {\[} $newCellName "_"]
						set newCellName [regsub -all {\]} $newCellName "_"]
						set newCellName [regsub -all {\.} $newCellName "_"]
						set newCellName [regsub -all {\-} $newCellName "_"]
					}
						
					## Add Cell Object to Dictionary (No Input Pin Object)
					dict set opts(-dict) "$opts(-name)$pathIndex" type        "cell"
					dict set opts(-dict) "$opts(-name)$pathIndex" name        $cellObj
					dict set opts(-dict) "$opts(-name)$pathIndex" instance    $newCellName
					dict set opts(-dict) "$opts(-name)$pathIndex" input_pins  [dict create]
					dict set opts(-dict) "$opts(-name)$pathIndex" output_pins [dict create]
					dict set opts(-dict) "$opts(-name)$pathIndex" clock_pins  [dict create]
					dict set opts(-dict) "$opts(-name)$pathIndex" tag         $opts(-name)
					dict set opts(-dict) "$opts(-name)$pathIndex" index       $pathIndex

					## Check if the direction of the pin object is an input
					if {[get_property -quiet DIRECTION $pinObj] eq "IN"} {
					
					## Check if the direction of the pin object is an output
					} elseif {[get_property -quiet DIRECTION $pinObj] eq "OUT"} {
						## Obfuscate name of the output net if desired
						if {$opts(-obfuscation)==1} {
							## Rename based on instance name argument
							set newNetName "$opts(-name)\_$pathIndex\_wire"
						} else {
							## Get the net object from the output pin object
							set netObj [get_nets -quiet -of_objects $pinObj]
							
							## Remove hierarchy from net object
							set newNetName [regsub -all {\/} [get_property NAME $netObj] "_"]
							set newNetName [regsub -all {\[} $newNetName "_"]
							set newNetName [regsub -all {\]} $newNetName "_"]
							set newNetName [regsub -all {\.} $newNetName "_"]
							set newNetName [regsub -all {\-} $newNetName "_"]
							
							## Append wire to the name to avoid collision with cell instance names
							append newNetName "_wire"
						}
							
						## Create Output Pin Dictionary
						dict set outputPinDict $pinObj type "pin"
						dict set outputPinDict $pinObj name $pinObj
						dict set outputPinDict $pinObj net_name $newNetName
					
						## Add the output pins dictionary to the cell dictionary
						dict set opts(-dict) "$opts(-name)$pathIndex" output_pins $outputPinDict
						
						## Set the previous output object dictionary to the previously created output pin object for the next iteration
						set previousOutputName [dict get $outputPinDict $pinObj net_name]
						
						dbgVar previousOutputName					
					## Error if direction is neither in nor out
					} else {
						return -code error "ERROR: \[parse_timing_path_objects\] Unable to determine pin direction [get_property -quiet DIRECTION $pinObj] for pin $pinObj."
					}
				}		
			}
			
			## Increment the path index
			incr pathIndex	
		}
	}
}

# #########################################################
# parse_timing_report
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::parse_timing_report {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0 -obfuscation 0}
    
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
            {-o(b(f(u(s(c(a(t(i(o(n)?)?)?)?)?)?)?)?)?)?$}         { set opts(-obfuscation)   [lshift args]}
			{-r(e(p(o(r(t(_(s(t(r(i(n(g)?)?)?)?)?)?)?)?)?)?)?)?$} { set opts(-report_string) [lshift args]}
            {-h(e(l(p)?)?)?$}                                     { set opts(-help)          1}
            default {
                return -code error "ERROR: \[parse_timing_report\] Unknown option '[lindex $args 0]', please type 'parse_timing_report -help' for usage info."
            }
        }
    }
	
	## Check to ensure the require report_string option is used
	if {[info exists opts(-report_string)]==0} {
        return -code error "ERROR: \[parse_timing_report\] Switch -report_string is required.  Please use -help for more information."
	}
	
	## Parse string for multiple report paths
	set reportPaths [regexp -inline -all -- {(Slack\s.+?)slack\s+-*\d+\.\d+} $opts(-report_string)]
	
	## Initialize Timing Path Cells Dictionary variable
	unset -nocomplain timingPathCellsDict
	
	## Create the dictionary for the timing path cells
	set timingPathCellsDict [dict create]

	## Loop through each timing report
	for { set x 0 } { $x < [llength $reportPaths]} {incr x 2} {
		set pathReport [lindex $reportPaths $x]
		
		if {[regexp {Slack.+?--+\s\s\s\s--+(.*?)--+\s\s\s\s--+(.*?)--+\s\s\s\s--+(.*?)\s+clock\spessimism} $pathReport matchString sourceSection dataSection destinationSection]} {		
			## Parse Source Clock Report Paths and Store necessary data
			set timingPathCellsDict [parse_timing_report_paths -report_string $sourceSection -name "srcclk[expr $x/2]" -dict $timingPathCellsDict -obfuscation $opts(-obfuscation)]
		
			## Parse Destination Clock Report Paths and Store necessary data
			set timingPathCellsDict [parse_timing_report_paths -report_string $destinationSection -name "dstclk[expr $x/2]" -dict $timingPathCellsDict -obfuscation $opts(-obfuscation)]
		
			## Parse Data Report Paths and Store necessary data
			set timingPathCellsDict [parse_timing_report_paths -report_string $dataSection -name "datapath[expr $x/2]" -dict $timingPathCellsDict -obfuscation $opts(-obfuscation)]
			
		} elseif {[regexp {Slack.+?--+\s\s\s\s--+(.*?)--+\s\s\s\s--+(.*?)\s+clock\spessimism} $pathReport matchString sourceSection dataSection]} {		
			## Parse Source Clock Report Paths and Store necessary data
			set timingPathCellsDict [parse_timing_report_paths -report_string $sourceSection -name "srcclk[expr $x/2]" -dict $timingPathCellsDict -obfuscation $opts(-obfuscation)]
		
			## Parse Data Report Paths and Store necessary data
			set timingPathCellsDict [parse_timing_report_paths -report_string $dataSection -name "datapath[expr $x/2]" -dict $timingPathCellsDict -obfuscation $opts(-obfuscation)]
		} elseif {[regexp {Slack.+?--+\s\s\s\s--+(.*?)--+\s\s\s\s--+\s+max\sdelay} $pathReport matchString dataSection]} {
			## Parse Source Clock Report Paths and Store necessary data
			set timingPathCellsDict [parse_timing_report_paths -report_string $dataSection -name "datapath[expr $x/2]" -dict $timingPathCellsDict -obfuscation $opts(-obfuscation)]			
	
		} else {
			puts "ERROR: \[[get_current_proc_name]\] Unable to parse timing path report."
		}
	}

	## Return the timing path cells dictionary
	return $timingPathCellsDict
}


# #########################################################
# add_timing_report_path
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::add_timing_report_path {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0 -obfuscation 0}
    
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
		    {-d(i(c(t)?)?)?$}                            { set opts(-dict)          [lshift args]}
			{-i(n(d(e(x)?)?)?)?$}                        { set opts(-index)         [lshift args]}
			{-n(a(m(e)?)?)?$}                            { set opts(-name)          [lshift args]}
			{-obj(e(c(t(s)?)?)?)?$}                      { set opts(-objects)       [lshift args]}
            {-obf(u(s(c(a(t(i(o(n)?)?)?)?)?)?)?)?$}      { set opts(-obfuscation)   [lshift args]}
            {-h(e(l(p)?)?)?$}                            { set opts(-help)          1}
            default {
                return -code error "ERROR: \[add_timing_report_path\] Unknown option '[lindex $args 0]', please type 'add_timing_report_path -help' for usage info."
            }
        }
    }
	
	## Check to ensure the object length is 2 (one input pin and one output pin)
	if {[llength $opts(-objects)]==2} {
		## Set the input and output objects from the list
		set outputObjectName [lindex $opts(-objects) 0]
		set inputObjectName  [lindex $opts(-objects) 1]
		
		## Get the pin object from the output name
		set outputPinObj [get_pins -quiet $outputObjectName]
		
		## Check if the output pin object exists
		if {[llength $outputPinObj]==0} {
			## Get the port object from the output name
			set portObj [get_ports -quiet $outputObjectName]
			
			## Check if the port object exists
			if {[llength $portObj]==0} {
				return -code error "ERROR: \[add_timing_report_path\] Output object $outputObjectName is neither a pin nor port."
			} else {
				## Obfuscate name is desired
				if {$opts(-obfuscation)==1} {
					## Rename based on instance name argument
					set portName "$opts(-name)\_$opts(-index)"
				} else {
					## Remove hierarchy from port object
					set portName [regsub -all {\/} [get_property NAME $portObj] "_"]
					set portName [regsub -all {\[} $portName "_"]
					set portName [regsub -all {\]} $portName "_"]
					set portName [regsub -all {\.} $portName "_"]
					set portName [regsub -all {\-} $portName "_"]
				}
				
				## Check if Port already defined in path dictionary, if not add to the dictionary
				if {![path_cell_name_exists? -dict $opts(-dict) -value $portObj]} {
					## Add Port object to Path Dictionary
					dict set opts(-dict) "$opts(-name)$opts(-index)" type        "port"
					dict set opts(-dict) "$opts(-name)$opts(-index)" name        $portObj
					dict set opts(-dict) "$opts(-name)$opts(-index)" direction   [get_property -quiet DIRECTION $portObj]
					dict set opts(-dict) "$opts(-name)$opts(-index)" net_name    $portName
					dict set opts(-dict) "$opts(-name)$opts(-index)" tag         $opts(-name)
					dict set opts(-dict) "$opts(-name)$opts(-index)" index       $opts(-index)
					
					## Get any non-generated clock objects on the port
					set clockObj [get_clocks -quiet -of_objects $portObj -filter {IS_USER_GENERATED || !IS_GENERATED}]
					## Check if any clock objects exist
					if {[llength $clockObj]!=0} {
						## Check if the source pin of the clock object is equal to the current port
						if {[lsearch [get_property -quiet SOURCE_PINS $clockObj] $portObj]>=0} {
							dbg "$opts(-name)$opts(-index): Clock Object $clockObj"
							## Add the clock object to the port
							dict set opts(-dict) "$opts(-name)$opts(-index)" clock_object name $clockObj
						}
					}
					
					dbgVar opts(-dict)
					
					## Store the current output value for next iteration
					set outputNetName $portName
					
					dbgVar outputNetName
				} else {
					## Get the previous path instance from the Path Dictionary
					set previousPathDict [get_path_dict_by_cell_name -dict $opts(-dict) -value $portObj]
					## Get the output net name for the next iteration
					set outputNetName [dict get $previousPathDict net_name]
	
					dbgVar outputNetName
				}
			}
		} else {
			## Get the cell object from the output port
			set cellObj [get_cells -quiet -of_objects $outputPinObj]
			
			## Check if Cell already exists in Path Dictionary
			if {[path_cell_name_exists? -dict $opts(-dict) -value $cellObj]} {
				## Get the previous path instance from the Path Dictionary
				set previousPathDict [get_path_dict_by_cell_name -dict $opts(-dict) -value $cellObj]
				
				## Verify the direction of the pin object is an output
				if {[get_property -quiet DIRECTION $outputPinObj] eq "OUT"} {
					## Get the output pin dictionary from the path instance
					set previousOutputPinsDict [dict get $previousPathDict output_pins]
							
					## Check if input pin doesn't already exists in the input pin dictionary
					if {![dictionary_value_exists? -dict $previousOutputPinsDict -key "name" -value $outputPinObj]} {
						dbg "Adding new output to previous cell $cellObj"
						
						## Obfuscate name of the output net if desired
						if {$opts(-obfuscation)==1} {
							## Rename based on instance name argument
							set newNetName "$opts(-name)\_$opts(-index)\_wire"
						} else {
							## Get the net object from the output pin object
							set netObj [get_nets -quiet -of_objects $outputPinObj]
									
							## Remove hierarchy from net object
							set newNetName [regsub -all {\/} [get_property NAME $netObj] "_"]
							set newNetName [regsub -all {\[} $newNetName "_"]
							set newNetName [regsub -all {\]} $newNetName "_"]
							set newNetName [regsub -all {\.} $newNetName "_"]
							set newNetName [regsub -all {\-} $newNetName "_"]
									
							## Append wire to the name to avoid collision with cell instance names
							append newNetName "_wire"
						}
								
						## Add current output pin object to Output Pin Dictionary
						dict set previousOutputPinsDict $outputPinObj type "pin"
						dict set previousOutputPinsDict $outputPinObj name $outputPinObj
						dict set previousOutputPinsDict $outputPinObj net_name $newNetName
						
						## Get any non-generated clock objects on the output pin
						set clockObj [get_clocks -quiet -of_objects $outputPinObj -filter {IS_USER_GENERATED || !IS_GENERATED}]
						## Check if any clock objects exist
						if {[llength $clockObj]!=0} {
							## Check if the source pin of the clock object is equal to the current output pin
							if {[lsearch [get_property -quiet SOURCE_PINS $clockObj] $outputPinObj]>=0} {
								dbg "$opts(-name)$opts(-index): Clock Object $clockObj"
								## Add the clock object to the output pin
								dict set previousOutputPinsDict $outputPinObj clock_object name $clockObj
								
								## Check if the clock is user generated
								if {[get_property -quiet IS_USER_GENERATED $clockObj]} {
									dbg "$opts(-name)$opts(-index): $clockObj found as generated clock"
									## Determine the updated net name for the source clock pin
									set sourceClockPinObj [get_pins -quiet [get_property -quiet SOURCE $clockObj]]
									## Check if the source clock pin was found
									if {[llength $sourceClockPinObj]==0} {
										puts "CRITICAL WARNING: \[add_timing_report_path\] Unable to determine source clock pin for generated clock $clockObj"
									} else {
										## Get the source clock pin cell object
										set sourceClockCellObj [get_cells -quiet -of_objects $sourceClockPinObj]
										## Check if Cell already exists in Path Dictionary
										if {[path_cell_name_exists? -dict $opts(-dict) -value $sourceClockCellObj]} {
											## Get the previous path instance from the Path Dictionary
											set sourceClockPathDict [get_path_dict_by_cell_name -dict $opts(-dict) -value $sourceClockCellObj]

											## Add the source clock pin net_name to the output pin
											dict set previousOutputPinsDict $outputPinObj clock_object source_clock_pin "[dict get $sourceClockPathDict instance]/[get_property -quiet REF_PIN_NAME $sourceClockPinObj]"
										} else {
											puts "CRITICAL WARNING: \[add_timing_report_path\] Source clock pin $sourceClockPinObj for generated clock $clockObj not previously found in timing report"
										}
									}
								}
							}
						}
						
						## Set the output net name to the net name in the output pins dictionary
						set outputNetName [dict get $previousOutputPinsDict $outputPinObj net_name]
								
						dbgVar outputNetName
					} else {
						## Get the output net name for the previously defined input pin
						set outputNetName [dict get $previousOutputPinsDict $outputPinObj net_name]
								
						dbgVar outputNetName
					}
							
					## Update the dictionary with the updated output pins for the cell object
					dict set previousPathDict output_pins $previousOutputPinsDict
					## Update the dictionary with the updated path
					dict set opts(-dict) "[dict get $previousPathDict tag][dict get $previousPathDict index]" $previousPathDict
				} else {
					return -code error "ERROR: \[add_timing_report_path\] Output pin $outputPinObj is not an output."
				}
			## Create New Dictionary for Cell Object
			} else {
				## Obfuscate name is desired
				if {$opts(-obfuscation)==1} {
					## Rename based on instance name argument
					set newCellName "$opts(-name)$opts(-index)"
				} else {
					## Remove hierarchy from port object
					set newCellName [regsub -all {\/} [get_property NAME $cellObj] "_"]
					set newCellName [regsub -all {\[} $newCellName "_"]
					set newCellName [regsub -all {\]} $newCellName "_"]
					set newCellName [regsub -all {\.} $newCellName "_"]
					set newCellName [regsub -all {\-} $newCellName "_"]
				}
							
				## Add Cell Object to Dictionary
				dict set opts(-dict) "$opts(-name)$opts(-index)" type        "cell"
				dict set opts(-dict) "$opts(-name)$opts(-index)" name        $cellObj
				dict set opts(-dict) "$opts(-name)$opts(-index)" instance    $newCellName
				dict set opts(-dict) "$opts(-name)$opts(-index)" input_pins  [dict create]
				dict set opts(-dict) "$opts(-name)$opts(-index)" output_pins [dict create]
				dict set opts(-dict) "$opts(-name)$opts(-index)" clock_pins  [dict create]
				dict set opts(-dict) "$opts(-name)$opts(-index)" tag         $opts(-name)
				dict set opts(-dict) "$opts(-name)$opts(-index)" index       $opts(-index)
				
				## Obfuscate name of the output net if desired
				if {$opts(-obfuscation)==1} {
					## Rename based on instance name argument
					set newNetName "$opts(-name)\_$opts(-index)\_wire"
				} else {
					## Get the net object from the output pin object
					set netObj [get_nets -quiet -of_objects $outputPinObj]
								
					## Remove hierarchy from net object
					set newNetName [regsub -all {\/} [get_property NAME $netObj] "_"]
					set newNetName [regsub -all {\[} $newNetName "_"]
					set newNetName [regsub -all {\]} $newNetName "_"]
					set newNetName [regsub -all {\.} $newNetName "_"]
					set newNetName [regsub -all {\-} $newNetName "_"]
								
					## Append wire to the name to avoid collision with cell instance names
					append newNetName "_wire"
				}
								
				## Create Output Pin Dictionary
				dict set outputPinDict $outputPinObj type "pin"
				dict set outputPinDict $outputPinObj name $outputPinObj
				dict set outputPinDict $outputPinObj net_name $newNetName
						
				## Add the output pins dictionary to the cell dictionary
				dict set opts(-dict) "$opts(-name)$opts(-index)" output_pins $outputPinDict
					
				## Set the previous output object dictionary to the previously created output pin object for the next iteration
				set outputNetName [dict get $outputPinDict $outputPinObj net_name]
							
				dbgVar outputNetName					
			}
		}
		
		## Get the pin object from the output name
		set inputPinObj [get_pins -quiet $inputObjectName]
		
		## Check if the output pin object exists
		if {[llength $inputObjectName]==0} {
			## Get the port object from the output name
			set portObj [get_ports -quiet $inputObjectName]
			
			## Check if the port object exists
			if {[llength $portObj]==0} {
				return -code error "ERROR: \[add_timing_report_path\] Input object $inputObjectName is neither a pin nor port."
			} else {
				## Obfuscate name is desired
				if {$opts(-obfuscation)==1} {
					## Rename based on instance name argument
					set portName "$opts(-name)\_$opts(-index)"
				} else {
					## Remove hierarchy from port object
					set portName [regsub -all {\/} [get_property NAME $portObj] "_"]
					set portName [regsub -all {\[} $portName "_"]
					set portName [regsub -all {\]} $portName "_"]
					set portName [regsub -all {\.} $portName "_"]
					set portName [regsub -all {\-} $portName "_"]
				}
				
				## Check if Port already defined in path dictionary, if not add to the dictionary
				if {![path_cell_name_exists? -dict $opts(-dict) -value $portObj]} {	
					## Add Port object to Path Dictionary
					dict set opts(-dict) "$opts(-name)$opts(-index)_1" type        "port"
					dict set opts(-dict) "$opts(-name)$opts(-index)_1" name        $portObj
					dict set opts(-dict) "$opts(-name)$opts(-index)_1" direction   [get_property -quiet DIRECTION $portObj]
					dict set opts(-dict) "$opts(-name)$opts(-index)_1" net_name    $portName
					dict set opts(-dict) "$opts(-name)$opts(-index)_1" tag         $opts(-name)
					dict set opts(-dict) "$opts(-name)$opts(-index)_1" index       "$opts(-index)_1"
				}
			}
		} else {
			## Get the cell object from the input pin object
			set cellObj [get_cells -quiet -of_objects $inputPinObj]
			
			## Check if Cell already exists in Path Dictionary
			if {[path_cell_name_exists? -dict $opts(-dict) -value $cellObj]} {
				## Get the previous path instance from the Path Dictionary
				set previousPathDict [get_path_dict_by_cell_name -dict $opts(-dict) -value $cellObj]
				
				## Verify the direction of the pin object is an input
				if {[get_property -quiet DIRECTION $inputPinObj] eq "IN"} {
					## Get the input pin dictionary from the path instance
					set previousInputPinsDict [dict get $previousPathDict input_pins]
							
					## Check if input pin doesn't already exists in the input pin dictionary
					if {![dictionary_value_exists? -dict $previousInputPinsDict -key "name" -value $inputPinObj]} {
						dbg "Adding new input to previous cell $cellObj."
						
						if {[info exists outputNetName]} {
							## Add current output pin object to Output Pin Dictionary
							dict set previousInputPinsDict $inputPinObj type "pin"
							dict set previousInputPinsDict $inputPinObj name $inputPinObj
							dict set previousInputPinsDict $inputPinObj net_name $outputNetName
							
							## Set the Unique site pins to determine fixed routing constraints
							set sitePinList [lsort -uniq [get_site_pins -quiet -of_objects $inputPinObj]]
							## Get the nodes for the specified site pins
							set nodeList    [get_nodes -quiet -of_objects [get_nets -quiet -of_objects $inputPinObj] -to $sitePinList] 
							
							dbgVar inputPinObj
							dbgVar sitePinList
							dbgVar nodeList
							
							## Check if any node routing exists
							if {[llength $nodeList]>0} {
								## Add the node list to the fixed routing constraint
								dict set previousInputPinsDict $inputPinObj fixed_route $nodeList
								## Check if the cell instance is of type LUT
								if {[regexp {LUT} [get_property -quiet REF_NAME $cellObj]]} {
									## Get the site pin name for the respective input pin
									set sitePinName [regsub .*/ [lindex $sitePinList 0] ""]
									## Set the physical pin location from the site pin name
									set physicalPinName [regsub {B|C|D|E|F|G|H} $sitePinName "A"]
									## Add the input and site pins to the LOCK_PINS constraint list
									dict set previousInputPinsDict $inputPinObj lock_pins "[get_property -quiet REF_PIN_NAME $inputPinObj]:$physicalPinName"
											
									dbg "lock_pins = [get_property -quiet REF_PIN_NAME $inputPinObj]:$physicalPinName"
								}
							}
						} else {
							return -code error "ERROR: \[add_timing_report_path\] Unable to find output net for input pin $inputPinObj"
						}
					}
					
					## Update the dictionary with the updated input pins for the cell object
					dict set previousPathDict input_pins $previousInputPinsDict
					## Update the dictionary with the updated path
					dict set opts(-dict) "[dict get $previousPathDict tag][dict get $previousPathDict index]" $previousPathDict
				} else {
					return -code error "ERROR: \[add_timing_report_path\] Input pin $inputPinObj is not an input."
				}
			## Create New Dictionary for Cell Object
			} else {
				## Obfuscate name is desired
				if {$opts(-obfuscation)==1} {
					## Rename based on instance name argument
					set newCellName "$opts(-name)$opts(-index)"
				} else {
					## Remove hierarchy from port object
					set newCellName [regsub -all {\/} [get_property NAME $cellObj] "_"]
					set newCellName [regsub -all {\[} $newCellName "_"]
					set newCellName [regsub -all {\]} $newCellName "_"]
					set newCellName [regsub -all {\.} $newCellName "_"]
					set newCellName [regsub -all {\-} $newCellName "_"]
				}
								
				## Add Cell Object to Dictionary
				dict set opts(-dict) "$opts(-name)$opts(-index)_1" type        "cell"
				dict set opts(-dict) "$opts(-name)$opts(-index)_1" name        $cellObj
				dict set opts(-dict) "$opts(-name)$opts(-index)_1" instance    $newCellName
				dict set opts(-dict) "$opts(-name)$opts(-index)_1" input_pins  [dict create]
				dict set opts(-dict) "$opts(-name)$opts(-index)_1" output_pins [dict create]
				dict set opts(-dict) "$opts(-name)$opts(-index)_1" clock_pins  [dict create]
				dict set opts(-dict) "$opts(-name)$opts(-index)_1" tag         $opts(-name)
				dict set opts(-dict) "$opts(-name)$opts(-index)_1" index       "$opts(-index)_1"
				
				if {[info exists outputNetName]} {
					## Add current input pin object to Input Pin Dictionary
					dict set inputPinDict $inputPinObj type "pin"
					dict set inputPinDict $inputPinObj name $inputPinObj
					dict set inputPinDict $inputPinObj net_name $outputNetName	
					
					## Set the Unique site pins to determine fixed routing constraints
					set sitePinList [lsort -uniq [get_site_pins -quiet -of_objects $inputPinObj]]
					## Get the nodes for the specified site pins
					set nodeList    [get_nodes -quiet -of_objects [get_nets -quiet -of_objects $inputPinObj] -to $sitePinList] 
					
					dbgVar inputPinObj
					dbgVar sitePinList
					dbgVar nodeList
					
					## Check if any node routing exists
					if {[llength $nodeList]>0} {
						## Add the node list to the fixed routing constraint
						dict set inputPinDict $inputPinObj fixed_route $nodeList
						## Check if the cell instance is of type LUT
						if {[regexp {LUT} [get_property -quiet REF_NAME $cellObj]]} {
							## Get the site pin name for the respective input pin
							set sitePinName [regsub .*/ [lindex $sitePinList 0] ""]
							## Set the physical pin location from the site pin name
							set physicalPinName [regsub {B|C|D|E|F|G|H} $sitePinName "A"]
							## Add the input and site pins to the LOCK_PINS constraint list
							dict set inputPinDict $inputPinObj lock_pins "[get_property -quiet REF_PIN_NAME $inputPinObj]:$physicalPinName"
									
							dbg "LOCK_PINS = [get_property -quiet REF_PIN_NAME $inputPinObj]:$physicalPinName"
						}
					}
					
					## Add the input pins dictionary to the cell dictionary
					dict set opts(-dict) "$opts(-name)$opts(-index)_1" input_pins $inputPinDict
				} else {
					return -code error "ERROR: \[add_timing_report_path\] Unable to find output net for input pin $inputPinObj"
				}
			}
		}
	}
	
	return $opts(-dict)
}

# #########################################################
# parse_timing_report_paths
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::parse_timing_report_paths {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0 -obfuscation 0}
    
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
		    {-d(i(c(t)?)?)?$}                                     { set opts(-dict)          [lshift args]}
			{-n(a(m(e)?)?)?$}                                     { set opts(-name)          [lshift args]}
            {-o(b(f(u(s(c(a(t(i(o(n)?)?)?)?)?)?)?)?)?)?$}         { set opts(-obfuscation)   [lshift args]}
			{-r(e(p(o(r(t(_(s(t(r(i(n(g)?)?)?)?)?)?)?)?)?)?)?)?$} { set opts(-report_string) [lshift args]}
            {-h(e(l(p)?)?)?$}                                     { set opts(-help)          1}
            default {
                return -code error "ERROR: \[parse_timing_report\] Unknown option '[lindex $args 0]', please type 'parse_timing_report -help' for usage info."
            }
        }
    }
	
	## Remove Extra Line Break between Cell and Delay Paths
	regsub -all {\s+(-*\d)} $opts(-report_string) " \\1" reportString
	## Remove Leading Whitespace
	regsub -all {^\s+} $reportString " " reportString
	## Remove Trailing Whitespace
	regsub -all {\s+$} $reportString " " reportString
	
	## Initialize Section Index List
	set pathIndex 0
	
	## Initialize Output Object Variable
	set outputObject ""
	
	## Loop through each Path for the Section of the Timing Report
	foreach reportLine [split $reportString \n] {
		## Remove Excess Whitespace
		regsub -all {\s+} $reportLine " " reportLine
		
		#dbg "Path $pathIndex: $reportLine"
		
		## Check if timing report line is of a Port Object or a datapath_only pin object
		if {[regexp {^\s*(\w+)*\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(r|f)\s(\S+)\s*$} $reportLine matchString locValue incrValue pathValue edgeValue portName] || [regexp {^\s*\(.*\)\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(r|f)\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(r|f)\s(\S+)\s*$} $reportLine matchString incrValue pathValue edgeValue tmpInc tmpPath tmpEdge portName] || [regexp {^\s*(\w+)*\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(r|f)\s(\S+)\s*\((IN|OUT)\)\s*$} $reportLine matchString locValue incrValue pathValue edgeValue portName tmpDirection]} {
			## Store the Port Object
			set portObj [get_ports -quiet $portName]
			
			## Check if Port Object exists
			if {[llength $portObj]==0} {
				## Get store the pin object instead since port object doesn't exist
				set pinObj [get_pins -quiet $portName]
				
				## Check if Pin Object exists
				if {[llength $pinObj]==0} {
					return -code error "ERROR: \[parse_timing_report_paths\] Unable to find pin/port object $portName."
				} else {
					## Check if the direction of the pin object is an input
					if {[get_property -quiet DIRECTION $pinObj] eq "IN"} {
						dbg "Input Pin Object: $pinObj"
						dbg "Pin Pair: $outputObject $pinObj"
						
						## Check to ensure that the output pin object exists
						if {[llength $outputObject]!=0} {
							## Add the timing report path to the dictionary
							set opts(-dict) [add_timing_report_path -objects [list $outputObject $pinObj] -dict $opts(-dict) -index $pathIndex -name $opts(-name) -obfuscation $opts(-obfuscation)]
						} else {
							## Skip unreported driver for input pin in timing report
							dbg "Skipping path due to unreferenced output object for input pin object: $pinObj"
						}
					## Check if the direction of the pin object is an output
					} elseif {[get_property -quiet DIRECTION $pinObj] eq "OUT"} {
						dbg "Output Pin Object: $pinObj"
						## Set the output object to the output pin
						set outputObject $pinObj
						
						## Get the cell object from the pin
						set cellObj [get_cells -quiet -of_objects $pinObj]
						
						## Check if the output pin belongs to an MMCM or PLL
						if {[regexp {^(MMCM|PLL)} [get_property -quiet REF_NAME $cellObj]]} {
							## Add the feedback path for the clock management block
							## Add the feedback path for the clock management block
					set opts(-dict) [add_clock_management_block_feedback_path -dict $opts(-dict) -object $outputObject -name $opts(-name) -index $pathIndex -obfuscation $opts(-obfuscation)]
						}
					}
				}
			} else {			
				## Check if the direction of the port object is an input
				if {[get_property -quiet DIRECTION $portObj] eq "IN"} {
					dbg "Input Port Object: $portObj (OUT)"
					## Set the output object to the input port
					set outputObject $portObj
				## Check if the direction of the port object is an output
				} elseif {[get_property -quiet DIRECTION $portObj] eq "OUT"} {
					dbg "Output Port Object: $portObj (IN)"
					dbg "Pin Pair: $outputObject $portObj"
					## Add the timing report path to the dictionary
					set opts(-dict) [add_timing_report_path -objects [list $outputObject $portObj] -dict $opts(-dict) -index $pathIndex -name $opts(-name) -obfuscation $opts(-obfuscation)]
				}
			}
			
			## Increment the Path Index
			incr pathIndex
		} elseif {[regexp {^\s*(X\d+Y\d+\s+\(\s*CLOCK_ROOT\s*\)\s+)?net\s\(fo=(\d+)(,\s(\w+))*\)\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(\S+)\s*$} $reportLine matchString clockRootHeader fanoutNum tempValue statusValue incrValue pathValue netName]} {
			## Get the net object from the net name
			set netObj [get_nets -quiet $netName]
			
			## Check if Net Object exists
			if {[llength $netObj]==0} {
				return -code error "ERROR: \[[get_current_proc_name]\] Unable to find net object $netName."
			}			
			
			#dbg "DEBUG: $opts(-name)$pathIndex: Skipping net path of Timing Report"
			
			## Increment the Path Index
			incr pathIndex
		
		## Use Regular Expression to check for Input Pin or Output Pad Path
		} elseif {[regexp {^\s*(\w+)*\s*(\w+)*\s(r|f)\s(\S+)\s*$} $reportLine matchString locValue libraryName edgeValue pinName]} {
			## Store Input Pin Object
			set inputPinObj   [get_pins -quiet $pinName]
			## Store Output Port Object
			set outputPortObj [get_ports -quiet $pinName]
							
			## Check if Input Pin Object or Output Port Object exists
			if {([llength $inputPinObj]==0) && ([llength $outputPortObj]==0)} {
				puts "ERROR: \[[get_current_proc_name]\] Unable to find input pin object or output port object for $pinName."
				return -code error
			} elseif {[llength $inputPinObj]==0} {
				## Unset the Input Pin Object if no input pin was found
				unset -nocomplain inputPinObj
				
				dbg "Output Port Object: $outputPortObj"
				## Set the output object to the output port
				set outputObject $pinObj
			} else {
				## Unset the output port object if not output port was found
				unset -nocomplain outputPortObj
				
				dbg "Input Pin Object: $inputPinObj"
				dbg "Pin Pair: $outputObject $inputPinObj"
				## Add the timing report path to the dictionary
				set opts(-dict) [add_timing_report_path -objects [list $outputObject $inputPinObj] -dict $opts(-dict) -index $pathIndex -name $opts(-name) -obfuscation $opts(-obfuscation)]
			}
			
			## Increment the Path Index
			incr pathIndex
		
		## Use Regular Expression to check for Output Pin Path
		} elseif {[regexp {^\s*((\w+)\s)*(\S+)\s\((\S+)\)\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(r|f)\s(\S+)\s*$} $reportLine matchString tmpValue locValue libraryName arcName incrValue pathValue edgeValue outputPin] || [regexp {^\s*(\S+)\s(\S+)\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(r|f)\s(\S+)\s*$} $reportLine matchString locValue libraryName incrValue pathValue edgeValue outputPin]} {
			## Store Output Pin Object
			set outputPinObj [get_pins -quiet $outputPin]
			
			# Check if Output Pin Object exists
			if {[llength $outputPinObj]==0} {
				## Check if last line in data path which is a cell instance
				set cellObj [get_cells -quiet $outputPin]
				
				## Check if Cell Object is defined
				if {[llength $cellObj]==0} {
					return -code error "ERROR: \[get_current_proc_name\] Unable to find cell object from or by $outputPin."
				}
			} else {
				dbg "Output Pin Object: $outputPinObj"
				
				## Set the output object to the output pin
				set outputObject $outputPinObj
				
				## Get the cell object from the pin
				set cellObj [get_cells -quiet -of_objects $outputPinObj]
				
				## Check if the output pin belongs to an MMCM or PLL
				if {[regexp {^(MMCM|PLL)} [get_property -quiet REF_NAME $cellObj]]} {
					## Add the feedback path for the clock management block
					set opts(-dict) [add_clock_management_block_feedback_path -dict $opts(-dict) -object $outputObject -name $opts(-name) -index $pathIndex -obfuscation $opts(-obfuscation)]
				}
			}			
		} else {
			#dbg "DEBUG: Unable to parse $reportLine."
		}
	}
	
	return $opts(-dict)
}

# #########################################################
#
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::add_clock_management_block_feedback_path {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0}

    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
		    {-d(i(c(t)?)?)?$}                       { set opts(-dict)          [lshift args]}
			{-i(n(d(e(x)?)?)?)?$}                   { set opts(-index)         [lshift args]}
			{-n(a(m(e)?)?)?$}                       { set opts(-name)          [lshift args]}
			{-obf(u(s(c(a(t(i(o(n)?)?)?)?)?)?)?)?$} { set opts(-obfuscation)   [lshift args]}
            {-obj(e(c(t)?)?)?$}                     { set opts(-object)        [lshift args]}
            {-h(e(l(p)?)?)?$}                       { set opts(-help)          1}
            default {
                return -code error "ERROR: \[add_clock_management_block_feedback\] Unknown option '[lindex $args 0]', please type 'parse_timing_report -help' for usage info."
            }
        }
    }
	
	## Get the pin object from the argument object list
	set outputPinObj [get_pins -quiet $opts(-object)]
	## Get the cell object from the pin
	set cellObj [get_cells -quiet -of_objects $outputPinObj]
	
	## Check if the output pin belongs to an MMCM or PLL
	if {[regexp {^(MMCM|PLL)} [get_property -quiet REF_NAME $cellObj]]} {
		dbg "Adding CLKFBIN for cell [get_cells -quiet -of_objects $outputPinObj]"
		## Get the CLKFBIN pin for the cell
		set feedbackInPinObj [get_pins -quiet -filter {REF_PIN_NAME=="CLKFBIN"} -of_objects $cellObj]
		## Get the driver of the feedback input pin
		set feedbackInDriverPinObj [get_pins -quiet -filter {DIRECTION==OUT} -of_objects [get_nets -quiet -of_objects $feedbackInPinObj]]
		
		## Check that the feedback driver exists
		if {[llength $feedbackInDriverPinObj]==0} {
			## Check if the driver of the feedback pin is a port
			set feedbackInPortObj [get_ports -quiet -filter {DIRECTION==IN} -of_objects [get_nets -quiet -of_objects $feedbackInPinObj]]
			
			## Check if the feedback driver port exists
			if {[llength $feedbackInPortObj]==0} {
				puts "CRITICAL WARNING: \[add_clock_management_block_feedback\] Unable to find Feedback input path for $cellObj"
			} else {
				dbg "Pin Pair: $feedbackInPortObj $feedbackInPinObj"
				## Add the feedback path to the dictionary
				set opts(-dict) [add_timing_report_path -objects [list $feedbackInPortObj $feedbackInPinObj] -dict $opts(-dict) -index $opts(-index) -name $opts(-name) -obfuscation $opts(-obfuscation)]
			}
		} else {
			dbg "Pin Pair: $feedbackInDriverPinObj $feedbackInPinObj"
			## Add the feedback path to the dictionary
			set opts(-dict) [add_timing_report_path -objects [list $feedbackInDriverPinObj $feedbackInPinObj] -dict $opts(-dict) -index $opts(-index) -name $opts(-name) -obfuscation $opts(-obfuscation)]
		}
		
		## Get the CLKFBOUT pin of the cell
		set feedbackOutPinObj [get_pins -quiet -filter {REF_PIN_NAME=="CLKFBOUT"} -of_objects $cellObj]	
		## Get the feedback load pins
		set feedbackOutLoadPinList [get_pins -quiet -filter {DIRECTION==IN} -of_objects [get_nets -quiet -of_objects $feedbackOutPinObj]]
		
		## Check if any loads were found on the feedback out
		if {[llength $feedbackOutLoadPinList]==0} {
			## Check if the load of the feedback pin is a port
			set feedbackOutPortObj [get_ports -quiet -filter {DIRECTION==OUT} -of_objects [get_nets -quiet -of_objects $feedbackOutPinObj]]
			
			## Check if the feedback load port exists
			if {[llength $feedbackOutPortObj]==0} {
				puts "CRITICAL WARNING: \[add_clock_management_block_feedback\] Unable to find Feedback output path for $cellObj"
			} else {
				## Add the feedback path to the dictionary
				set opts(-dict) [add_timing_report_path -objects [list $feedbackOutPinObj $feedbackOutPortObj] -dict $opts(-dict) -index $opts(-index) -name $opts(-name) -obfuscation $opts(-obfuscation)]
			}
		} elseif {[llength $feedbackOutLoadPinList]>1} {
			## Get Feedback input driver cell
			set feedbackInDriverCellObj [get_cells -quiet -of_objects $feedbackInDriverPinObj]
			## Check if the CLKFBOUT load list contains the CLKFBIN driver
			set feedbackInDriverLoadPinList [get_pins -quiet -filter "NAME=~$feedbackInDriverCellObj/*" -of_objects [get_nets -quiet -of_objects $feedbackOutPinObj]]
			
			## Check if CLKFBIN Driver is a load pin for the CLKFBOUT
			if {[llength $feedbackInDriverLoadPinList]==0} {
				puts "CRITICAL WARNING: \[add_clock_management_block_feedback\] Too many loads ([llength $feedbackOutLoadPinList]) on Feedback output path for $cellObj"
			} else {
				## Add the feedback path to the dictionary
				set opts(-dict) [add_timing_report_path -objects [list $feedbackOutPinObj $feedbackInDriverLoadPinList] -dict $opts(-dict) -index $opts(-index) -name $opts(-name) -obfuscation $opts(-obfuscation)]
			}
		} else {
			## Add the feedback path to the dictionary
			set opts(-dict) [add_timing_report_path -objects [list $feedbackOutPinObj $feedbackOutLoadPinList] -dict $opts(-dict) -index $opts(-index) -name $opts(-name) -obfuscation $opts(-obfuscation)]
		}
	}
	
	return $opts(-dict)
}
# #########################################################
# parse_timing_report_paths_orig
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::parse_timing_report_paths_orig {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0 -obfuscation 0}
    
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
		    {-d(i(c(t)?)?)?$}                                     { set opts(-dict)          [lshift args]}
			{-n(a(m(e)?)?)?$}                                     { set opts(-name)          [lshift args]}
            {-o(b(f(u(s(c(a(t(i(o(n)?)?)?)?)?)?)?)?)?)?$}         { set opts(-obfuscation)   [lshift args]}
			{-r(e(p(o(r(t(_(s(t(r(i(n(g)?)?)?)?)?)?)?)?)?)?)?)?$} { set opts(-report_string) [lshift args]}
            {-h(e(l(p)?)?)?$}                                     { set opts(-help)          1}
            default {
                return -code error "ERROR: \[parse_timing_report\] Unknown option '[lindex $args 0]', please type 'parse_timing_report -help' for usage info."
            }
        }
    }
	
	## Remove Extra Line Break between Cell and Delay Paths
	regsub -all {\s+(-*\d)} $opts(-report_string) " \\1" reportString
	## Remove Leading Whitespace
	regsub -all {^\s+} $reportString " " reportString
	## Remove Trailing Whitespace
	regsub -all {\s+$} $reportString " " reportString
	
	## Initialize Section Index List
	set pathIndex 0
	
	## Loop through each Path for the Section of the Timing Report
	foreach reportLine [split $reportString \n] {
		## Remove Excess Whitespace
		regsub -all {\s+} $reportLine " " reportLine
		
		dbg "Path $pathIndex: $reportLine"
		
		## Check if timing report line is of a Port Object or a datapath_only pin object
		if {[regexp {^\s*(\w+)*\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(r|f)\s(\S+)\s*$} $reportLine matchString locValue incrValue pathValue edgeValue portName] || [regexp {^\s*\(.*\)\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(r|f)\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(r|f)\s(\S+)\s*$} $reportLine matchString incrValue pathValue edgeValue tmpInc tmpPath tmpEdge portName] || [regexp {^\s*(\w+)*\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(r|f)\s(\S+)\s*\((IN|OUT)\)\s*$} $reportLine matchString locValue incrValue pathValue edgeValue portName tmpDirection]} {
			## Store the Port Object
			set portObj [get_ports -quiet $portName]
			
			## Check if Port Object exists
			if {[llength $portObj]==0} {
				## Get store the pin object instead since port object doesn't exist
				set pinObj [get_pins -quiet $portName]
				
				## Check if Pin Object exists
				if {[llength $pinObj]==0} {
					return -code error "ERROR: \[parse_timing_report_paths\] Unable to find pin/port object $portName."
				} else {
					## Get the cell object associated with the pin object
					set cellObj [get_cells -quiet -of_objects $pinObj]
			
					## Check if Cell already exists in Path Dictionary
					if {[path_cell_name_exists? -dict $opts(-dict) -value $cellObj]} {
						## Get the previous path instance from the Path Dictionary
						set previousPathDict [get_path_dict_by_cell_name -dict $opts(-dict) -value $cellObj]
						
						## Check if the direction of the pin object is an input
						if {[get_property -quiet DIRECTION $pinObj] eq "IN"} {
							## Get the input pin dictionary from the path instance
							set previousInputPinsDict [dict get $previousPathDict input_pins]
							
							## Check if input pin doesn't already exists in the input pin dictionary
							if {![dictionary_value_exists? -dict $previousInputPinsDict -key "name" -value $pinObj]} {
								dbg "DEBUG: \[parse_timing_path_objects\] Adding new input to previous cell path."
								
								## Check if previous output value is defined
								if {[info exists previousOutputName] && ($previousOutputName ne "")} { 
									## Add current input pin object to Input Pin Dictionary
									dict set previousInputPinsDict $pinObj type "pin"
									dict set previousInputPinsDict $pinObj name $pinObj
									dict set previousInputPinsDict $pinObj net_name $previousOutputName
									
									##### joshg
									set sitePinList [lsort -uniq [get_site_pins -quiet -of_objects $pinObj]]
									set nodeList    [get_nodes -quiet -of_objects [get_nets -quiet -of_objects $pinObj] -to $sitePinList] 
									
									dbgVar pinObj
									dbgVar sitePinList
									dbgVar nodeList
									
									if {[llength $nodeList]>0} {
										dict set previousInputPinsDict $pinObj fixed_route $nodeList
										
										if {[regexp {LUT} [get_property -quiet REF_NAME [get_cells -quiet -of_objects $pinObj]]]} {
											## Get the site pin name for the respective input pin
											set sitePinName [regsub .*/ [lindex $sitePinList 0] ""]   							
											dict set previousInputPinsDict $pinObj lock_pins "[get_property -quiet REF_PIN_NAME $pinObj]:$sitePinName"
											
											dbg "lock_pins = [get_property -quiet REF_PIN_NAME $pinObj]:$sitePinName"
										}
									}
								## Possible to have undriven clock input based on recovery removal checks
								} elseif {[get_property CLOCK_PIN $pinObj]==1} {
									return -code error "ERROR: \[parse_timing_path_objects\] Previous Output Path is undefined. Please contact script owner."		 							
								}
							}
							
							## Update the dictionary with the updated input pins for the cell object
							dict set previousPathDict input_pins $previousInputPinsDict

						## Check if the direction of the pin object is an output
						} elseif {[get_property -quiet DIRECTION $pinObj] eq "OUT"} {
							## Get the output pin dictionary from the path instance
							set previousOutputPinsDict [dict get $previousPathDict output_pins]
							
							## Check if output pin doesn't already exists in the output pin dictionary
							if {![dictionary_value_exists? -dict $previousOutputPinsDict -key "name" -value $pinObj]} {
								dbg "DEBUG: \[parse_timing_report_paths\] Adding new output to previous cell path."
								
								## Obfuscate name of the output net if desired
								if {$opts(-obfuscation)==1} {
									## Rename based on instance name argument
									set newNetName "$opts(-name)\_$pathIndex\_wire"
								} else {
									## Get the net object from the output pin object
									set netObj [get_nets -quiet -of_objects $outputPinObj]
									
									## Remove hierarchy from net object
									set newNetName [regsub -all {\/} [get_property NAME $netObj] "_"]
									set newNetName [regsub -all {\[} $newNetName "_"]
									set newNetName [regsub -all {\]} $newNetName "_"]
									set newNetName [regsub -all {\.} $newNetName "_"]
									set newNetName [regsub -all {\-} $newNetName "_"]
									
									## Append wire to the name to avoid collision with cell instance names
									append newNetName "_wire"
								}
								
								## Add current output pin object to Output Pin Dictionary
								dict set previousOutputPinsDict $pinObj type "pin"
								dict set previousOutputPinsDict $pinObj name $pinObj
								dict set previousOutputPinsDict $pinObj net_name $newNetName
								
								## Set the previous output object dictionary to the newly created output pin
								set previousOutputName [dict get $previousOutputPinsDict $pinObj net_name]
								
								dbgVar previousOutputName
							} else {
								## Set the previous output object dictionary to the previously created output pin object for the next iteration
								set previousOutputName [dict get $previousOutputPinsDict $pinObj net_name]
								
								dbgVar previousOutputName
							}
							
							## Update the dictionary with the updated output pins for the cell object
							dict set previousPathDict output_pins $previousOutputPinsDict
							
						## Error if direction is neither in nor out
						} else {
							return -code error "ERROR: \[parse_timing_path_objects\] Unable to determine pin direction [get_property -quiet DIRECTION $pinObj] for pin $pinObj."
						}
						
						## Update the dictionary with the updated path with the updated pins
						dict set opts(-dict) "[dict get $previousPathDict tag][dict get $previousPathDict index]" $previousPathDict
					## Create New Dictionary for Cell Object
					} else {
						## Obfuscate name is desired
						if {$opts(-obfuscation)==1} {
							## Rename based on instance name argument
							set newCellName "$opts(-name)$pathIndex"
						} else {
							## Remove hierarchy from port object
							set newCellName [regsub -all {\/} [get_property NAME $cellObj] "_"]
							set newCellName [regsub -all {\[} $newCellName "_"]
							set newCellName [regsub -all {\]} $newCellName "_"]
							set newCellName [regsub -all {\.} $newCellName "_"]
							set newCellName [regsub -all {\-} $newCellName "_"]
						}
							
						## Add Cell Object to Dictionary (No Input Pin Object)
						dict set opts(-dict) "$opts(-name)$pathIndex" type        "cell"
						dict set opts(-dict) "$opts(-name)$pathIndex" name        $cellObj
						dict set opts(-dict) "$opts(-name)$pathIndex" instance    $newCellName
						dict set opts(-dict) "$opts(-name)$pathIndex" input_pins  [dict create]
						dict set opts(-dict) "$opts(-name)$pathIndex" output_pins [dict create]
						dict set opts(-dict) "$opts(-name)$pathIndex" clock_pins  [dict create]
						dict set opts(-dict) "$opts(-name)$pathIndex" tag         $opts(-name)
						dict set opts(-dict) "$opts(-name)$pathIndex" index       $pathIndex

						## Check if the direction of the pin object is an input
						if {[get_property -quiet DIRECTION $pinObj] eq "IN"} {
						
						## Check if the direction of the pin object is an output
						} elseif {[get_property -quiet DIRECTION $pinObj] eq "OUT"} {
							## Obfuscate name of the output net if desired
							if {$opts(-obfuscation)==1} {
								## Rename based on instance name argument
								set newNetName "$opts(-name)\_$pathIndex\_wire"
							} else {
								## Get the net object from the output pin object
								set netObj [get_nets -quiet -of_objects $pinObj]
								
								## Remove hierarchy from net object
								set newNetName [regsub -all {\/} [get_property NAME $netObj] "_"]
								set newNetName [regsub -all {\[} $newNetName "_"]
								set newNetName [regsub -all {\]} $newNetName "_"]
								set newNetName [regsub -all {\.} $newNetName "_"]
								set newNetName [regsub -all {\-} $newNetName "_"]
								
								## Append wire to the name to avoid collision with cell instance names
								append newNetName "_wire"
							}
								
							## Create Output Pin Dictionary
							dict set outputPinDict $pinObj type "pin"
							dict set outputPinDict $pinObj name $pinObj
							dict set outputPinDict $pinObj net_name $newNetName
						
							## Add the output pins dictionary to the cell dictionary
							dict set opts(-dict) "$opts(-name)$pathIndex" output_pins $outputPinDict
							
							## Set the previous output object dictionary to the previously created output pin object for the next iteration
							set previousOutputName [dict get $outputPinDict $pinObj net_name]
							
							dbgVar previousOutputName					
						## Error if direction is neither in nor out
						} else {
							return -code error "ERROR: \[parse_timing_path_objects\] Unable to determine pin direction [get_property -quiet DIRECTION $pinObj] for pin $pinObj."
						}
					}		
				}
			} else {			
				## Obfuscate name is desired
				if {$opts(-obfuscation)==1} {
					## Rename based on instance name argument
					set portName "$opts(-name)\_$pathIndex"
				} else {
					## Remove hierarchy from port object
					set portName [regsub -all {\/} [get_property NAME $portObj] "_"]
					set portName [regsub -all {\[} $portName "_"]
					set portName [regsub -all {\]} $portName "_"]
					set portName [regsub -all {\.} $portName "_"]
					set portName [regsub -all {\-} $portName "_"]
				}
				
				## Check if Port already defined in path dictionary, if not add to the dictionary
				if {![path_cell_name_exists? -dict $opts(-dict) -value $portObj]} {	
					## Add Port object to Path Dictionary
					dict set opts(-dict) "$opts(-name)$pathIndex" type        "port"
					dict set opts(-dict) "$opts(-name)$pathIndex" name        $portObj
					dict set opts(-dict) "$opts(-name)$pathIndex" direction   [get_property -quiet DIRECTION $portObj]
					dict set opts(-dict) "$opts(-name)$pathIndex" net_name    $portName
					dict set opts(-dict) "$opts(-name)$pathIndex" tag         $opts(-name)
					dict set opts(-dict) "$opts(-name)$pathIndex" index       $pathIndex
					
					dbg "DEBUG: Dict $opts(-name)$pathIndex: [dict get $opts(-dict) "$opts(-name)$pathIndex"]"
					
					## Store the current output value for next iteration
					set previousOutputName $portName
					
					dbg "DEBUG: Previous Output Name: $previousOutputName"
				} else {
					dbg "DEBUG: $opts(-name)$pathIndex: Port Object $portObj already exists in path."
					
					## Get the previous path instance from the Path Dictionary
					set previousPathDict [get_path_dict_by_cell_name -dict $opts(-dict) -value $portObj]
					## Get the output net name for the next iteration
					set previousOutputName [dict get $previousPathDict net_name]
					
					dbgVar previousOutputName
				}
			}
			
			## Increment the Path Index
			incr pathIndex
		} elseif {[regexp {^\s*(X\d+Y\d+\s+\(\s*CLOCK_ROOT\s*\)\s+)?net\s\(fo=(\d+)(,\s(\w+))*\)\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(\S+)\s*$} $reportLine matchString clockRootHeader fanoutNum tempValue statusValue incrValue pathValue netName]} {
			## Get the net object from the net name
			set netObj [get_nets -quiet $netName]
			
			## Check if Net Object exists
			if {[llength $netObj]==0} {
				return -code error "ERROR: \[[get_current_proc_name]\] Unable to find net object $netName."
			}			
			
			dbg "DEBUG: $opts(-name)$pathIndex: Skipping net path of Timing Report"
			
			## Increment the Path Index
			incr pathIndex
		
		## Use Regular Expression to check for Input Pin or Output Pad Path
		} elseif {[regexp {^\s*(\w+)*\s*(\w+)*\s(r|f)\s(\S+)\s*$} $reportLine matchString locValue libraryName edgeValue pinName]} {
			## Store Input Pin Object
			set inputPinObj   [get_pins -quiet $pinName]
			## Store Output Port Object
			set outputPortObj [get_ports -quiet $pinName]
							
			## Check if Input Pin Object or Output Port Object exists
			if {([llength $inputPinObj]==0) && ([llength $outputPortObj]==0)} {
				puts "ERROR: \[[get_current_proc_name]\] Unable to find input pin object or output port object for $pinName."
				return -code error
			} elseif {[llength $inputPinObj]==0} {
				## Unset the Input Pin Object if no input pin was found
				unset -nocomplain inputPinObj
			} else {
				## Unset the output port object if not output port was found
				unset -nocomplain outputPortObj
			}
			
			## Increment the Path Index
			incr pathIndex
		
		## Use Regular Expression to check for Output Pin Path
		} elseif {[regexp {^\s*((\w+)\s)*(\S+)\s\((\S+)\)\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(r|f)\s(\S+)\s*$} $reportLine matchString tmpValue locValue libraryName arcName incrValue pathValue edgeValue outputPin] || [regexp {^\s*(\S+)\s(\S+)\s(-*\d+\.\d+)\s(-*\d+\.\d+)\s(r|f)\s(\S+)\s*$} $reportLine matchString locValue libraryName incrValue pathValue edgeValue outputPin]} {
			## Store Output Pin Object
			set outputPinObj [get_pins -quiet $outputPin]
			
			# Check if Output Pin Object exists
			if {[llength $outputPinObj]==0} {
				## Check if last line in data path which is a cell instance
				set cellObj [get_cells -quiet $outputPin]
			} else {
				## Store Cell Object from Output Pin Object
				set cellObj [get_cells -quiet -of_objects $outputPinObj]				
			}

			## Check if Cell Object is defined
			if {[llength $cellObj]==0} {
				return -code error "ERROR: \[get_current_proc_name\] Unable to find cell object from or by $outputPin."
			} else {
				## Obfuscate name is desired
				if {$opts(-obfuscation)==1} {
					## Rename based on instance name argument
					set outputPinName "$opts(-name)\_$pathIndex\_wire"
				} else {
					## Get the net object from the output pin object
					set netObj [get_nets -quiet -of_objects $outputPinObj]
						
					## Remove hierarchy from net object
					set outputPinName [regsub -all {\/} [get_property NAME $netObj] "_"]
					set outputPinName [regsub -all {\[} $outputPinName "_"]
					set outputPinName [regsub -all {\]} $outputPinName "_"]
					set outputPinName [regsub -all {\.} $outputPinName "_"]
					set outputPinName [regsub -all {\-} $outputPinName "_"]
					## Append wire to the name to avoid collision with cell instance names
					append outputPinName "_wire"
				}
				
				## Check if Cell already exists in Path Dictionary
				if {[path_cell_name_exists? -dict $opts(-dict) -value $cellObj]} {
					dbg "DEBUG: $opts(-name)$pathIndex: Found Existing Cell $cellObj."
					
					## Get the previous path instance from the Path Dictionary
					set previousPathDict [get_path_dict_by_cell_name -dict $opts(-dict) -value $cellObj]
										
					## Get the input pin dictionary from the path instance
					set previousInputPinsDict [dict get $previousPathDict input_pins]
					
					## Check if input pin object already exists in input pin list
					if {[info exists inputPinObj]} {
						## Check if input pin doesn't already exists in the input pin dictionary
						if {![dictionary_value_exists? -dict $previousInputPinsDict -key "name" -value $inputPinObj]} {
							dbg "DEBUG: \[parse_timing_report_paths\] Adding new input to previous cell path."
							
							## Check if previous output value is defined
							if {$prevOutput ne ""} { 
								## Add current input pin object to Input Pin Dictionary
								dict set previousInputPinsDict $inputPinObj type "pin"
								dict set previousInputPinsDict $inputPinObj name $inputPinObj
								dict set previousInputPinsDict $inputPinObj net_name $previousOutputName
								
								##### joshg
								set sitePinList [lsort -uniq [get_site_pins -quiet -of_objects $inputPinObj]]
								set nodeList    [get_nodes -quiet -of_objects [get_nets -quiet -of_objects $inputPinObj] -to $sitePinList] 
								
								dbgVar inputPinObj
								dbgVar sitePinList
								dbgVar nodeList
								
								if {[llength $nodeList]>0} {
									dict set previousInputPinsDict $inputPinObj fixed_route $nodeList
									
									if {[regexp {LUT} [get_property -quiet REF_NAME [get_cells -quiet -of_objects $inputPinObj]]]} {
										## Get the site pin name for the respective input pin
										set sitePinName [regsub .*/ [lindex $sitePinList 0] ""]  							
										dict set previousInputPinsDict $inputPinObj lock_pins "[get_property -quiet REF_PIN_NAME $inputPinObj]:$sitePinName"
										
										dbg "lock_pins = [get_property -quiet REF_PIN_NAME $inputPinObj]:$sitePinName"
									}
								}
							} else {
								return -code error "ERROR: \[get_current_proc_name\] Previous Output Path is undefined. Please contact script owner."		 							
							}
						}
					}
					
					## Get the output pin dictionary from the path instance
					set previousOutputPinsDict [dict get $previousPathDict output_pins]
					
					## Check that the output pin object isn't empty
					if {[llength $outputPinObj]>0} {
						## Check if output pin doesn't already exists in the output pin dictionary
						if {![dictionary_value_exists? -dict $previousOutputPinsDict -key "name" -value $outputPinObj]} {
							dbg "DEBUG: \[parse_timing_report_paths\] Adding new output to previous cell path."
							
							## Add current output pin object to Output Pin Dictionary
							dict set previousOutputPinsDict $outputPinObj type "pin"
							dict set previousOutputPinsDict $outputPinObj name $outputPinObj
							dict set previousOutputPinsDict $outputPinObj net_name $outputPinName
							
							## Set the previous output object dictionary to the newly created output pin
							set previousOutputName [dict get $previousOutputPinsDict $outputPinObj net_name]
							
							dbgVar previousOutputName
						} else {
							## Set the previous output object dictionary to the previously created output pin object for the next iteration
							set previousOutputName [dict get $previousOutputPinsDict $outputPinObj net_name]
							
							dbgVar previousOutputName
						}
					}
					
					## Update the dictionary with the updated input pins for the cell object
					dict set previousPathDict input_pins $previousInputPinsDict
					## Update the dictionary with the updated output pins for the cell object
					dict set previousPathDict output_pins $previousOutputPinsDict
					
					## Update the dictionary with the updated path with the updated pins
					dict set opts(-dict) "[dict get $previousPathDict tag][dict get $previousPathDict index]" $previousPathDict

					## Increment the path index
					incr pathIndex
				} else {
					## Obfuscate name is desired
					if {$opts(-obfuscation)==1} {
						## Rename based on instance name argument
						set cellName "$opts(-name)$pathIndex"
					} else {
						## Remove hierarchy from port object
						set cellName [regsub -all {\/} [get_property NAME $cellObj] "_"]
						set cellName [regsub -all {\[} $cellName "_"]
						set cellName [regsub -all {\]} $cellName "_"]
						set cellName [regsub -all {\.} $cellName "_"]
						set cellName [regsub -all {\-} $cellName "_"]
					}
		
					if {[info exists inputPinObj]==0} {
						## Create Output Pin Dictionary
						dict set outputPinDict $outputPinObj type "pin"
						dict set outputPinDict $outputPinObj name $outputPinObj
						dict set outputPinDict $outputPinObj net_name $outputPinName
						
						## Add Cell Object to Dictionary (No Input Pin Object)
						dict set opts(-dict) "$opts(-name)$pathIndex" type        "cell"
						dict set opts(-dict) "$opts(-name)$pathIndex" name        $cellObj
						dict set opts(-dict) "$opts(-name)$pathIndex" instance    $cellName
						dict set opts(-dict) "$opts(-name)$pathIndex" input_pins  [dict create]
						dict set opts(-dict) "$opts(-name)$pathIndex" output_pins $outputPinDict
						dict set opts(-dict) "$opts(-name)$pathIndex" clock_pins  [dict create]
						dict set opts(-dict) "$opts(-name)$pathIndex" tag         $opts(-name)
						dict set opts(-dict) "$opts(-name)$pathIndex" index       $pathIndex
						
						## Set the previous output object dictionary to the previously created output pin object for the next iteration
						set previousOutputName [dict get $outputPinDict $outputPinObj net_name]
						
						dbgVar previousOutputName
					} elseif {$outputPinObj eq ""} {
						## Add current input pin object to Input Pin Dictionary
						dict set inputPinDict $inputPinObj type "pin"
						dict set inputPinDict $inputPinObj name $inputPinObj
						dict set inputPinDict $inputPinObj net_name $previousOutputName		
						
						##### joshg
						set sitePinList [lsort -uniq [get_site_pins -quiet -of_objects $inputPinObj]]
						set nodeList    [get_nodes -quiet -of_objects [get_nets -quiet -of_objects $inputPinObj] -to $sitePinList] 
						
						dbgVar inputPinObj
						dbgVar sitePinList
						dbgVar nodeList
						
						if {[llength $nodeList]>0} {
							dict set inputPinDict $inputPinObj fixed_route $nodeList
							
							if {[regexp {LUT} [get_property -quiet REF_NAME [get_cells -quiet -of_objects $inputPinObj]]]} {
								## Get the site pin name for the respective input pin
								set sitePinName [regsub .*/ [lindex $sitePinList 0] ""]  							
								dict set inputPinDict $inputPinObj lock_pins "[get_property -quiet REF_PIN_NAME $inputPinObj]:$sitePinName"
								
								dbg "lock_pins = [get_property -quiet REF_PIN_NAME $inputPinObj]:$sitePinName"
							}
						}
						
						## Add Cell Object to Path dictionary (No Output Pin Object)
						dict set opts(-dict) "$opts(-name)$pathIndex" type        "cell"
						dict set opts(-dict) "$opts(-name)$pathIndex" name        $cellObj
						dict set opts(-dict) "$opts(-name)$pathIndex" instance    $cellName
						dict set opts(-dict) "$opts(-name)$pathIndex" input_pins  $inputPinDict
						dict set opts(-dict) "$opts(-name)$pathIndex" output_pins [dict create]
						dict set opts(-dict) "$opts(-name)$pathIndex" clock_pins  [dict create]
						dict set opts(-dict) "$opts(-name)$pathIndex" tag         $opts(-name)
						dict set opts(-dict) "$opts(-name)$pathIndex" index       $pathIndex             
						
						## Store the empty output object dictionary for next iteration
						set previousOutputName ""

                        dbgVar previousOutputName
					} else {
						## Add current input pin object to Input Pin Dictionary
						dict set inputPinDict $inputPinObj type "pin"
						dict set inputPinDict $inputPinObj name $inputPinObj
						dict set inputPinDict $inputPinObj net_name $previousOutputName	
						
						##### joshg
						set sitePinList [lsort -uniq [get_site_pins -quiet -of_objects $inputPinObj]]
						set nodeList    [get_nodes -quiet -of_objects [get_nets -quiet -of_objects $inputPinObj] -to $sitePinList] 
						
						dbgVar inputPinObj
						dbgVar sitePinList
						dbgVar nodeList
						
						if {[llength $nodeList]>0} { 
							dict set inputPinDict $inputPinObj fixed_route $nodeList
							
							if {[regexp {LUT} [get_property -quiet REF_NAME [get_cells -quiet -of_objects $inputPinObj]]]} {
								## Get the site pin name for the respective input pin
								set sitePinName [regsub .*/ [lindex $sitePinList 0] ""]  							
								dict set inputPinDict $inputPinObj lock_pins "[get_property -quiet REF_PIN_NAME $inputPinObj]:$sitePinName"	
								
								dbg "lock_pins = [get_property -quiet REF_PIN_NAME $inputPinObj]:$sitePinName"
							}
						}
						
						## Create Output Pin Dictionary
						dict set outputPinDict $outputPinObj type "pin"
						dict set outputPinDict $outputPinObj name $outputPinObj
						dict set outputPinDict $outputPinObj net_name $outputPinName
					
						## Add Cell Object to Path dictionary (No Output Pin Object)
						dict set opts(-dict) "$opts(-name)$pathIndex" type        "cell"
						dict set opts(-dict) "$opts(-name)$pathIndex" name        $cellObj
						dict set opts(-dict) "$opts(-name)$pathIndex" instance    $cellName
						dict set opts(-dict) "$opts(-name)$pathIndex" input_pins  $inputPinDict
						dict set opts(-dict) "$opts(-name)$pathIndex" output_pins $outputPinDict
						dict set opts(-dict) "$opts(-name)$pathIndex" clock_pins  [dict create]
						dict set opts(-dict) "$opts(-name)$pathIndex" tag         $opts(-name)
						dict set opts(-dict) "$opts(-name)$pathIndex" index       $pathIndex     
						
						## Store the current output value for next iteration
						set previousOutputName [dict get $outputPinDict $outputPinObj net_name]
						
						dbgVar previousOutputName
					}
					
					## Increment the Path Index
					incr pathIndex						
				}
				
				## Reset all variables
				foreach varname {cellObj netObj inputPinObj portName outputPortObj outputPinObj inputPinDict outputPinDict previousInputPinsDict previousOutputPinsDict previousClockPinsDict previousPathDict} { unset -nocomplain $varname }				
			}
		} else {
			dbg "DEBUG: Unable to parse $reportLine."
		}
	}
	
	## Add Cell for clock pin remainder
	if {[info exists inputPinObj]} {
		dbg "Add Cell for Input Clock Pin Remainder."
		## Get the cell object from the input clock pin
		set cellObj [get_cells -quiet -of_objects $inputPinObj]
		
		## Obfuscate name is desired
		if {$opts(-obfuscation)==1} {
			## Rename based on instance name argument
			set cellName "$opts(-name)$pathIndex"
		} else {
			## Remove hierarchy from port object
			set cellName [regsub -all {\/} [get_property NAME $cellObj] "_"]
			set cellName [regsub -all {\[} $cellName "_"]
			set cellName [regsub -all {\]} $cellName "_"]
			set cellName [regsub -all {\.} $cellName "_"]
			set cellName [regsub -all {\-} $cellName "_"]
		}
		
		##
		if {[info exists previousOutputName] && $previousOutputName ne ""} {
			## Check if Cell already exists in Path Dictionary
			if {[path_cell_name_exists? -dict $opts(-dict) -value $cellObj]} {
				dbg "DEBUG: $opts(-name)$pathIndex: Found Existing Cell $cellObj."
				
				## Get the previous path instance from the Path Dictionary
				set previousPathDict [get_path_dict_by_cell_name -dict $opts(-dict) -value $cellObj]
			
				## Get the clock pin dictionary from the path instance
				set previousClockPinsDict [dict get $previousPathDict clock_pins]
				
				## Check if input pin doesn't already exists in the input pin dictionary
				if {![dictionary_value_exists? -dict $previousClockPinsDict -key "name" -value $inputPinObj]} {
					## Add current clock pin object to Clock Pin Dictionary
					dict set previousClockPinsDict $inputPinObj type "pin"
					dict set previousClockPinsDict $inputPinObj name $inputPinObj
					dict set previousClockPinsDict $inputPinObj net_name $previousOutputName
					
					##### joshg
					set sitePinList [lsort -uniq [get_site_pins -quiet -of_objects $inputPinObj]]
					set nodeList    [get_nodes -quiet -of_objects [get_nets -quiet -of_objects $inputPinObj] -to [lindex $sitePinList 0]] 
					
					dbgVar inputPinObj
					dbgVar sitePinList
					dbgVar nodeList
					
					if {[llength $nodeList]>0} { 
						dict set previousClockPinsDict $inputPinObj fixed_route $nodeList
						
						if {[regexp {LUT} [get_property -quiet REF_NAME [get_cells -quiet -of_objects $inputPinObj]]]} {
							## Get the site pin name for the respective input pin
							set sitePinName [regsub .*/ [lindex $sitePinList 0] ""]  
							dict set previousClockPinsDict $inputPinObj lock_pins "[get_property -quiet REF_PIN_NAME $inputPinObj]:$sitePinName"
							
							dbg "lock_pins = [get_property -quiet REF_PIN_NAME $inputPinObj]:$sitePinName"
						}
					}
					
					## Update the dictionary with the updated clock pins for the cell object
					dict set previousPathDict clock_pins $previousClockPinsDict
				}
				
				## Update the dictionary with the updated clock pins for the cell object
				dict set opts(-dict) "[dict get $previousPathDict tag][dict get $previousPathDict index]" $previousPathDict
			} else {
				dict set clockPinsDict $inputPinObj type "pin"
				dict set clockPinsDict $inputPinObj name $inputPinObj
				dict set clockPinsDict $inputPinObj net_name $previousOutputName
			
				## Add Cell Object to Path dictionary (No Output Pin or Input Pin Object)
				dict set opts(-dict) "$opts(-name)$pathIndex" type        "cell"
				dict set opts(-dict) "$opts(-name)$pathIndex" name        $cellObj
				dict set opts(-dict) "$opts(-name)$pathIndex" instance    $cellName
				dict set opts(-dict) "$opts(-name)$pathIndex" input_pins  [dict create]
				dict set opts(-dict) "$opts(-name)$pathIndex" output_pins [dict create]
				dict set opts(-dict) "$opts(-name)$pathIndex" clock_pins  $clockPinsDict
				dict set opts(-dict) "$opts(-name)$pathIndex" tag         $opts(-name)
				dict set opts(-dict) "$opts(-name)$pathIndex" index       $pathIndex     				
			}		
		} else {
			return -code error "ERROR: \[[get_current_proc_name]\] Failure to determine previous output pin for clock network pin $inputPinObj.  Please contact script owner."        
		}
		
		## Reset all variables
		foreach varname {cellObj netObj inputPinObj portName outputPortObj clockPins prevPath prevOutput listPosition inputPinDict outputPinDict previousInputPinsDict previousOutputPinsDict previousClockPinsDict previousPathDict} { if {[info exists $varname]} { unset $varname } }
	##
	} elseif {[info exists outputPortObj]} {
		dbg "Add Output Port Remainder to Path $outputPortObj."

		## Check if Port already defined in path dictionary, if not add to the dictionary
		if {![path_cell_name_exists? -dict $opts(-dict) -value $outputPortObj]} {
			## Check to ensure that the previous output name to the port was defined
			if {[llength $previousOutputName]==0} {
				return -code error "ERROR: \[[get_current_proc_name]\] The driving net name was not previously defined for output port $outputPortObj."
			} else {
				## Add Port object to Path Dictionary
				dict set opts(-dict) "$opts(-name)$pathIndex" type        "port"
				dict set opts(-dict) "$opts(-name)$pathIndex" name        $outputPortObj
				dict set opts(-dict) "$opts(-name)$pathIndex" direction   [get_property -quiet DIRECTION $outputPortObj]
				dict set opts(-dict) "$opts(-name)$pathIndex" net_name    $previousOutputName
				dict set opts(-dict) "$opts(-name)$pathIndex" tag         $opts(-name)
				dict set opts(-dict) "$opts(-name)$pathIndex" index       $pathIndex
			}
		}
	
		## Reset all variables
		foreach varname {cellObj netObj inputPinObj portName outputPortObj inputPinDict outputPinDict previousInputPinsDict previousOutputPinsDict previousClockPinsDict previousPathDict} { if {[info exists $varname]} { unset $varname } }
	}
	
	return $opts(-dict)
}

# #########################################################
# path_to_verilog_dict
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::path_to_verilog_dict {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0}
    
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
            {-d(i(c(t_(o(b(j(e(c(t)?)?)?)?)?)?)?)?)?$}                                { set opts(-dict_object)        [lshift args]}
			{-v(e(r(i(l(o(g(_(d(i(c(t)?)?)?)?)?)?)?)?)?)?)?$}                         { set opts(-verilog_dict)       [lshift args]}
            {-h(e(l(p)?)?)?$}                                                         { set opts(-help)               1}
            default {
                return -code error "ERROR: \[path_to_verilog\] Unknown option '[lindex $args 0]', please type 'path_to_verilog -help' for usage info."
            }
        }
    }
	
	## Get object type from the cell dictionary
	set objectType	[dict get $opts(-dict_object) type]
	## Get tag from the cell dictionary tag
    set tagName     [dict get $opts(-dict_object) tag]
	## Get path index from the cell dictionary index
    set pathIndex   [dict get $opts(-dict_object) index]
	
    ## Initialize the cell pins dictionary
	set cellObjectPinsDict  [dict create]
    ## Initialize the cell generated ports dictionary
	set generatedPortsDict  [dict create]
	## Initialize the cell property dictionary
	set cellPropertyDict    [dict create]
	## Initialize the clock object dictionary
	set clockObjectDict     [dict create]
	## Initialize the fixed routing dictionary
	set fixedRouteDict      [dict create]
	
	## Initialize the input and ports list variables
	set inputPortsList	{}
    set outputPortsList {}	

	## Initialize the count variable for the generated port list
    set generatedPortCount	0
	
	## Initialize Verilog Object dictionary
	set verilogObjDict      [dict create]
	
	## Initialize the timing, physical, and routing constraints list variables
	set timingConstraintsList   {}
	set physicalConstraintsList {}
	set routingConstraintsList  {}

	## Initialize cell object pin filter for processing
	set cellObjPinFilter [list]
	
    ## Unset the persisted Verilog Object
    array unset verilogObj

	#dbgVar opts(-dict_object)
	
	## Check if the dictionary object is of type cell
	if {$objectType eq "cell"} {
		## Get input pin dictionary from the cell dictionary input_pins
		set inputPinsDict  [dict get $opts(-dict_object) input_pins]
		## Get output pin dictionary from the cell dictionary output_pins
		set outputPinsDict [dict get $opts(-dict_object) output_pins]
		## Get clock pin dictionary from the cell dictionary clock_pins
		set clockPinsDict  [dict get $opts(-dict_object) clock_pins]
		
		## Get cell object from the cell dictionary name
		set cellObj [get_cells -quiet [dict get $opts(-dict_object) name]]
		
		## Check to ensure the cell object exists, else check if cell retargeting is required.
		if {[llength $cellObj]==0} {
			return -code error "ERROR: \[path_to_verilog\] Unable to find cell object $cellObj."
		} else {	
			## Check if INTERNAL primitive and retarget to MACRO primitive
			if {[get_property -quiet PRIMITIVE_LEVEL $cellObj] eq "INTERNAL"} {
				dbg "Internal Primitive Cell $cellObj"
				
				## Loop through each input pin in the dictionary to find equivalent pin on the MACRO level cell
				foreach inputPinDictID [dict keys $inputPinsDict] {
					## Get the dictionary pin object from the Output Pins Dictionary
					set inputPinDict [dict get $inputPinsDict $inputPinDictID]
					
					## Check to ensure the output pin is of type "pin"
					if {[dict get $inputPinDict type] eq "pin"} {
						## Get all pins attached to the internal primitive net
						set netPinList [get_pins -quiet -of_objects [get_nets -quiet -of_objects [get_pins -quiet [dict get $inputPinDict name]]]]
						
						## Loop through each pin found on the net 
						foreach netPinObj $netPinList {
							## Get cell from the pin object
							set netCellObj [get_cells -quiet -of_objects $netPinObj]
				
							## Check if Cell object is a MACRO level primitive
							if {[get_property PRIMITIVE_LEVEL $netCellObj] eq "MACRO"} {
								## Add the retargeted cell object to the retarget dictionary
								dict set retargetCellDict name $netCellObj
								
								## Add Output Pin to retargeted output Dictionary
								dict set retargetInputPinDict $netPinObj type "pin"
								dict set retargetInputPinDict $netPinObj name $netPinObj
								dict set retargetInputPinDict $netPinObj net_name [dict get $inputPinDict net_name]
								
								if {[dict exists $inputPinDict fixed_route]} {
									dict set retargetInputPinDict $netPinObj fixed_route [dict get $inputPinDict fixed_route]
								}
								
								if {[dict exists $inputPinDict lock_pins]} {
									set lockPinsString [dict get $inputPinDict lock_pins]
									set lockPinsList [split $lockPinsString ":"]
									dict set retargetInputPinDict $netPinObj lock_pins "[get_property REF_PIN_NAME $netPinObj]:[lindex $lockPinsList 1]"
								}
								
								## Set the retargeted Cell Object
								set retargetedCellObj $netCellObj
								
								dbgVar retargetedCellObj
							}							
						}
					} else {
						puts "CRITICAL WARNING: \[path_to_verilog\] Unable to process object type [dict get $inputPinDict type] for internal cell retargeting."
					}
				}
				
				## Loop through each output pin in the dictionary to find equivalent pin on the MACRO level cell
				foreach outputPinDictID [dict keys $outputPinsDict] {
					## Get the dictionary pin object from the Output Pins Dictionary
					set outputPinDict [dict get $outputPinsDict $outputPinDictID]
					
					## Check to ensure the output pin is of type "pin"
					if {[dict get $outputPinDict type] eq "pin"} {
						## Get all pins attached to the internal primitive net
						set netPinList [get_pins -quiet -of_objects [get_nets -quiet -of_objects [get_pins -quiet [dict get $outputPinDict name]]]]
						
						## Loop through each pin found on the net 
						foreach netPinObj $netPinList {
							## Get cell from the pin object
							set netCellObj [get_cells -quiet -of_objects $netPinObj]
							
							## Check if Cell object is a MACRO level primitive
							if {[get_property PRIMITIVE_LEVEL $netCellObj] eq "MACRO"} {
								## Add the retargeted cell object to the retargeted dictionary
								dict set retargetCellDict name $netCellObj
								
								## Add Output Pin to Retarget output Dictionary
								dict set retargetOutputPinDict $netPinObj type "pin"
								dict set retargetOutputPinDict $netPinObj name $netPinObj
								dict set retargetOutputPinDict $netPinObj net_name [dict get $outputPinDict net_name]
								
								## Set the Retargeted Cell Object
								set retargetedCellObj $netCellObj
								
								dbgVar retargetedCellObj
							}							
						}
					} else {
						puts "CRITICAL WARNING: \[path_to_verilog\] Unable to process object type [dict get $outputPinDict type] for internal cell retargeting."
					}
				}

				## Loop through each clock pin in the dictionary to find equivalent pin on the MACRO level cell
				foreach clockPinDictID [dict keys $clockPinsDict] {
					## Get the dictionary pin object from the Output Pins Dictionary
					set clockPinDict [dict get $clockPinsDict $clockPinDictID]
					
					## Check to ensure the output pin is of type "pin"
					if {[dict get $clockPinDict type] eq "pin"} {
						## Get all pins attached to the internal primitive net
						set netPinList [get_pins -quiet -of_objects [get_nets -quiet -of_objects [get_pins -quiet [dict get $clockPinDict name]]]]
						
						## Loop through each pin found on the net 
						foreach netPinObj $netPinList {
							## Get cell from the pin object
							set netCellObj [get_cells -quiet -of_objects $netPinObj]
							
							## Check if Cell object is a MACRO level primitive
							if {[get_property PRIMITIVE_LEVEL $netCellObj] eq "MACRO"} {
								## Add the retargeted cell object to the retarget dictionary
								dict set retargetCellDict name $netCellObj
								
								## Add Output Pin to Retarget output Dictionary
								dict set retargetClockPinDict $netPinObj type "pin"
								dict set retargetClockPinDict $netPinObj name $netPinObj
								dict set retargetClockPinDict $netPinObj net_name [dict get $clockPinDict net_name]
								
								if {[dict exists $clockPinDict fixed_route]} {
									dict set retargetClockPinDict $netPinObj fixed_route [dict get $clockPinDict fixed_route]
								}
								
								if {[dict exists $clockPinDict lock_pins]} {
									set lockPinsString [dict get $clockPinDict lock_pins]
									set lockPinsList [split $lockPinsString ":"]
									dict set retargetClockPinDict $netPinObj lock_pins "[get_property REF_PIN_NAME $netPinObj]:[lindex $lockPinsList 1]"
								}
								
								## Set the Retargeted Cell Object
								set retargetedCellObj $netCellObj
								
								dbgVar retargetedCellObj
							}							
						}
					} else {
						puts "CRITICAL WARNING: \[path_to_verilog\] Unable to process object type [dict get $clockPinDict type] for internal cell retargeting."
					}
				}	

				puts "INFO: \[path_to_verilog\] Retargeting INTERNAL primitive [get_property LIB_CELL $cellObj] to [get_property LIB_CELL $retargetedCellObj] primitive."
				
				## Set input pin dictionary to the retargeted cell input_pins
				if {[info exists retargetInputPinDict]} {
					set inputPinsDict  $retargetInputPinDict
				}
				
				## Set output pin dictionary to the retargeted cell output_pins
				if {[info exists retargetOutputPinDict]} {
					set outputPinsDict $retargetOutputPinDict
				}
				
				## Set clock pin dictionary to the retargeted cell clock_pins
				if {[info exists retargetClockPinDict]} {
					set clockPinsDict  $retargetClockPinDict
				}	
				## Update the cell object to the retargeted cell object
				set cellObj $retargetedCellObj
			}
		}
		
		## Check if Verilog object exists for cell object
		if {[dict exists $opts(-verilog_dict) $cellObj]} {
			## Set the Verilog object dictionary to the existing Verilog dictionary object
			set verilogObjDict [dict get $opts(-verilog_dict) $cellObj]
			## Set the cell pins dictionary from the Verilog dictionary object
			set cellObjectPinsDict [dict get $verilogObjDict pins]
            ## Set the cell top-level input ports
            set inputPortsList [dict get $verilogObjDict input_ports]
			## Set the cell top-level output ports
			set outputPortsList [dict get $verilogObjDict output_ports]
		}
		
		## Get the list of pin objects on the cell object
		set cellPinList [lsort [get_pins -quiet -of_objects $cellObj]]
		
		## Loop through each pin on the cell object
		foreach cellPinObj $cellPinList {
			## Parse pin to determine name and bus value
			if [regexp {.+/(\w+)(\[(\d+)\])?} $cellPinObj matchString pinName busString busBit] {
				## Check if the cell pin already exists in the cell object pins dictionary
				if {![dictionary_value_exists? -dict $cellObjectPinsDict -key "pin_name" -value $pinName]} {
					## Create the dictionary for the cell pin
					set cellPinDict [dict create]
					
					## Set the cell pin properties to the dictionary
					dict set cellPinDict pin_name $pinName
					
					## Check if the busBit value is empty, set as scalar, otherwise set as vector
					dict set cellPinDict type [expr {($busBit eq "") ? "scalar" : "vector"}]
				} else {
					## Get the cell pin dictionary from the cell objects pins dictionary
					set cellPinDict [dict get $cellObjectPinsDict $pinName]
				}
				
				## Check if the Direction of the cell pin object is an input
				if {[get_property DIRECTION $cellPinObj] eq "IN"} {
					## Check if the cell pin object exists in the input pin dictionary
					if {[dictionary_value_exists? -dict $inputPinsDict -key "name" -value $cellPinObj]} {
						## Get the input pin dictionary from the input pins dictionary
						set inputPinDict [dict get $inputPinsDict $cellPinObj]
						
						## Set the fixed route property for the net, if exists
						if {[dict exists $inputPinDict fixed_route]} {
							dict set fixedRouteDict [dict get $inputPinDict net_name] net_name [dict get $inputPinDict net_name]
							dict set fixedRouteDict [dict get $inputPinDict net_name] fixed_route [dict get $inputPinDict fixed_route]
						}
						
						## Set the lock_pins property for the cell
						if {[dict exists $inputPinDict lock_pins]} {
							set lockPinsArray([dict get $inputPinDict net_name]) [dict get $inputPinDict lock_pins]
						}
						
						## Check if the pin object is a scalar or vector
						if {[dict get $cellPinDict type] eq "scalar"} {
							## Set the scalar pin as bit 0 in the dictionary
							dict set cellPinDict bus_index 0 value [dict get $inputPinDict net_name]
							## Set the scalar pin as used
							dict set cellPinDict bus_index 0 is_used 1
						} else {
							## Set the vector bit based on the bit value to the dictionary
							dict set cellPinDict bus_index $busBit value [dict get $inputPinDict net_name]
							## Set the vector bit as used
							dict set cellPinDict bus_index $busBit is_used 1
						}
					## Check if the cell pin object exists in the clock pin dictionary
					} elseif {[dictionary_value_exists? -dict $clockPinsDict -key "name" -value $cellPinObj]} {
						## Get the input pin dictionary from the input pins dictionary
						set clockPinDict [dict get $clockPinsDict $cellPinObj]
						
						## Set the fixed route property for the net
						if {[dict exists $clockPinDict fixed_route]} {
							dict set fixedRouteDict [dict get $clockPinDict net_name] net_name [dict get $clockPinDict net_name]
							dict set fixedRouteDict [dict get $clockPinDict net_name] fixed_route [dict get $clockPinDict fixed_route]
						}
						
						## Set the lock_pins property for the cell
						if {[dict exists $clockPinDict lock_pins]} {
							set lockPinsArray([dict get $clockPinDict net_name]) [dict get $clockPinDict lock_pins]
						}
						
						## Check if the pin object is a scalar or vector
						if {[dict get $cellPinDict type] eq "scalar"} {
							## Set the scalar pin as bit 0 in the dictionary
							dict set cellPinDict bus_index 0 value [dict get $clockPinDict net_name]
							## Set the scalar pin as used
							dict set cellPinDict bus_index 0 is_used 1
						} else {
							## Set the vector bit based on the bit value to the dictionary
							dict set cellPinDict bus_index $busBit value [dict get $clockPinDict net_name]
							## Set the vector bit as used
							dict set cellPinDict bus_index $busBit is_used 1
						}
					## Since the pin is not found in the path dictionary, set value based on net type
					} else {
						## Get the net object from the cell pin object
						set netObj  [get_nets -quiet -of_objects $cellPinObj]
					
						## Check whether net object exists
						if {[llength $netObj]!=0} {
							## Set the connectivity based on net type (Power, Ground, Signal)
							switch -nocase [get_property TYPE $netObj] {
								"Power" {
									## Check if the pin object is a scalar or vector
									if {[dict get $cellPinDict type] eq "scalar"} {
										## Set the scalar pin as bit 0 in the dictionary to VCC
										dict set cellPinDict bus_index 0 value "1'b1"
									} else {
										## Set the vector bit based on the bit value to the dictionary to VCC
										dict set cellPinDict bus_index $busBit value "1'b1"
									}
								}
								"Ground" {
									## Check if the pin object is a scalar or vector
									if {[dict get $cellPinDict type] eq "scalar"} {
										## Set the scalar pin as bit 0 in the dictionary to GND
										dict set cellPinDict bus_index 0 value "1'b0"
									} else {
										## Set the vector bit based on the bit value to the dictionary to GND
										dict set cellPinDict bus_index $busBit value "1'b0"
									}									
								}
								default {
									## Check if the pin object is a scalar or vector
									if {[dict get $cellPinDict type] eq "scalar"} {
										## Check if the signal is already used
										if {![dict exists $cellPinDict bus_index 0 is_used]} {
											## Set the scalar pin as bit 0 in the dictionary to input pin
											dict set cellPinDict bus_index 0 value "[dict get $opts(-dict_object) instance]\_input$generatedPortCount" 
											## Set the scalar pin as used
											dict set cellPinDict bus_index 0 is_used 1
											
											dbg "Adding Generated Port for $cellPinObj"
											
											## Add the newly created port the generated port dictionary
											dict set generatedPortsDict "[dict get $opts(-dict_object) instance]\_input$generatedPortCount" name "[dict get $opts(-dict_object) instance]\_input$generatedPortCount"
											dict set generatedPortsDict "[dict get $opts(-dict_object) instance]\_input$generatedPortCount" type "port"
											dict set generatedPortsDict "[dict get $opts(-dict_object) instance]\_input$generatedPortCount" direction "IN"
										
											## Increment the generated port count variable
											incr generatedPortCount
										}
									} else {
										## Check if the signal is already used
										if {![dict exists $cellPinDict bus_index $busBit is_used]} {
											## Set the vector bit based on the bit value to the dictionary to an input pin
											dict set cellPinDict bus_index $busBit value "[dict get $opts(-dict_object) instance]\_input$generatedPortCount"
											## Set the vector bit as used
											dict set cellPinDict bus_index $busBit is_used 1
											
											dbg "Adding Generated Port for $cellPinObj"
											
											## Add the newly created port the generated port dictionary
											dict set generatedPortsDict "[dict get $opts(-dict_object) instance]\_input$generatedPortCount" name "[dict get $opts(-dict_object) instance]\_input$generatedPortCount"
											dict set generatedPortsDict "[dict get $opts(-dict_object) instance]\_input$generatedPortCount" type "port"
											dict set generatedPortsDict "[dict get $opts(-dict_object) instance]\_input$generatedPortCount" direction "IN"
										
											## Increment the generated port count variable
											incr generatedPortCount
										}
									}
								}
							}
						}	
				    }

					## Set the cell pin dictionary to the cell object pins dictionary
					dict set cellObjectPinsDict $pinName $cellPinDict
					
				## Check if the Direction of the cell pin object is an output
				} elseif {[get_property DIRECTION $cellPinObj] eq "OUT"} {
					## Check if output pins dictionary is empty
					if {[llength $outputPinsDict]==0} {
						## Dump debug information for cell endpoint output pin
						dbgVar outputPinsDict
						dbgVar cellPinObj
						
						## Check if the pin object is a scalar or vector
						if {[dict get $cellPinDict type] eq "scalar"} {
							## Set the scalar pin as bit 0 in the dictionary to input pin
							dict set cellPinDict bus_index 0 value "[dict get $opts(-dict_object) instance]\_output$generatedPortCount" 
						} else {
							## Set the vector bit based on the bit value to the dictionary to an input pin
							dict set cellPinDict bus_index $busBit value "[dict get $opts(-dict_object) instance]\_output$generatedPortCount"
						}
						
						## Set the cell pin dictionary to the cell object pins dictionary
						dict set cellObjectPinsDict "[dict get $opts(-dict_object) instance]\_output$generatedPortCount"  $cellPinDict
									
						## Add the newly created port the generated port dictionary
						dict set generatedPortsDict "[dict get $opts(-dict_object) instance]\_output$generatedPortCount" name "[dict get $opts(-dict_object) instance]\_output$generatedPortCount"
						dict set generatedPortsDict "[dict get $opts(-dict_object) instance]\_output$generatedPortCount" type "port"
						dict set generatedPortsDict "[dict get $opts(-dict_object) instance]\_output$generatedPortCount" direction "OUT"
									
						## Increment the generated port count variable
						incr generatedPortCount
					## Check if cell pin object exists in output pins dictionary
					} elseif {[dictionary_value_exists? -dict $outputPinsDict -key "name" -value $cellPinObj]} {
						## Get the output pin dictionary from the output pins dictionary
						set outputPinDict [dict get $outputPinsDict $cellPinObj]
					
						## Check if the output port has already been defined in the cell object pins dictionary
						if {[dictionary_value_exists? -dict $cellObjectPinsDict -key "pin_name" -value $pinName]} {
							## Check if the pin object is a scalar or vector
							if {[dict get $cellPinDict type] eq "scalar"} {
								## Set the scalar pin as bit 0 in the dictionary to output pin
								dict set cellPinDict bus_index 0 value [dict get $outputPinDict net_name]
							} else {
								## Set the vector bit based on the bit value to the dictionary to an output pin
								dict set cellPinDict bus_index $busBit value [dict get $outputPinDict net_name]
							}
							
							## Set the cell pin dictionary to the cell object pins dictionary
							dict set cellObjectPinsDict $pinName $cellPinDict
						} else {
							## Check if the pin object is a scalar or vector
							if {[dict get $cellPinDict type] eq "scalar"} {
								## Set the scalar pin as bit 0 in the dictionary to output pin
								dict set cellPinDict bus_index 0 value [dict get $outputPinDict net_name]
							} else {						
								## Get the BUS_STOP property of the pin object
								set busStopValue  [get_property BUS_STOP [get_pins -quiet [dict get $outputPinDict name]]]
								## Get the BUS_START property of the pin object
								set busStartValue [get_property BUS_START [get_pins -quiet [dict get $outputPinDict name]]]
								
								## Loop through each bit of the bus and setup dummy wires to control the 
								for { set i $busStopValue } { $i <= $busStartValue } { incr i } {
									if {$i==$busBit} {
										## Set the vector bit based on the bit value to the dictionary to an output pin
										dict set cellPinDict bus_index $i value [dict get $outputPinDict net_name]
									} else {
										## Set the vector bit to a dummy wire to the output dictionary
										dict set cellPinDict bus_index $i value "dummy_$tagName\_$pinName\_$i"
									}
								}
							}
							
							## Set the cell pin dictionary to the cell object pins dictionary
							dict set cellObjectPinsDict $pinName $cellPinDict
						}
						
						## Check if the clock object exists for the cell pin
						if {[dict exists $outputPinDict clock_object]} {
							dbg "Adding [dict get $outputPinDict clock_object name] to clock dictionary"
							## Add the clock object to the clock object dictionary
							dict set clockObjectDict [dict get $outputPinDict clock_object name] source_type [dict get $outputPinDict type]
							dict set clockObjectDict [dict get $outputPinDict clock_object name] source_name "[dict get $opts(-dict_object) instance]/[get_property -quiet REF_PIN_NAME $cellPinObj]"
							
							## Check if source pin exists in dictionary
							if {[dict exists $outputPinDict clock_object source_clock_pin]} {
								## Add the clock object source clock pin for the generated clock
								dict set clockObjectDict [dict get $outputPinDict clock_object name] source_clock_pin [dict get $outputPinDict clock_object source_clock_pin]
							}
						}
					}
				}
			} else {
            	return -code error "ERROR: \[path_to_verilog\] Failure to parse [get_property DIRECTION $cellPin] cell pin $cellPinObj."
            }
		}
		
		## Create a list of all the properties to filter from the cell object
		#set propertyFilter [list "BEL" "IS_BEL_FIXED" "IS_LOC_FIXED" "IS_PARTITION" "LOC" "BUS_NAME" "BUS_INFO" "XILINX_LEGACY_PRIM" "PRIMITIVE_TYPE" "BOX_TYPE" "SOFT_HLUTNM" "__SRVAL" "ASYNC_REG" "IOB" "msgon" "equivalent_register_removal" "XILINX_TRANSFORM_PINMAP" "xc_map"]
    	## Return all the properties associated with the cell object
		#set reportProperty [report_property -return_string $cellObj]
   
   		## Loop through each attribute in the report property list
    	#foreach propertyLine [split $reportProperty "\n"] {
    	#	## Check to ensure the value is visible to the user, if not do not add to the list
    	#	if {[regexp {^\s*(\S+)\s+(\w+)\s+false\s+true\s+(\S+)} $propertyLine matchString propertyName propertyType propertyValue]} {
		#		## Check to ensure the attribute is not in the property filter list
        #		if {[lsearch $propertyFilter $propertyName]<0} {
		#			## Add the property to the cell property dictionary
		#			dict set cellPropertyDict $propertyName name $propertyName
		#			dict set cellPropertyDict $propertyName type $propertyType
		#			dict set cellPropertyDict $propertyName value $propertyValue
        #		}	
        #	}
    	#}
        
        ## Get all the configuration properties from the library cell object
        set configPropertyList [list_property [get_lib_cells -quiet -of_objects $cellObj] -regexp {^CONFIG\.\w+$}]
		## Remove the CONFIG. prefix to return a list of only the property names
        set propertyList [regsub -all {CONFIG.} $configPropertyList ""]
        
        ## Loop through each property in the list
        foreach propertyName $propertyList {
        	## Check to ensure the property value exists on the cell
            if {[llength [get_property -quiet $propertyName $cellObj]]!=0} {
	        	## Add the property to the cell property dictionary
				dict set cellPropertyDict $propertyName name $propertyName
				dict set cellPropertyDict $propertyName type [get_property -quiet CONFIG.$propertyName\.TYPE [get_lib_cells -quiet -of_objects $cellObj]]
				dict set cellPropertyDict $propertyName value [get_property -quiet $propertyName $cellObj]
        	}
        }

		## Check if the cell is a LUT and check if the LUT equation has been set
		if {[regexp {LUT(\d+)} [get_property REF_NAME $cellObj] matchString lutSizeValue] && ![dict exists $cellPropertyDict "INIT"]} {
			## Set initial INIT string value for 64-bit XOR function
			set initString "6996966996696996"
			set bitSizeValue [expr int(pow(2, $lutSizeValue-2))]
			
			## Add the missing INIT property to the cell property dictionary based on the XOR function
			dict set cellPropertyDict $propertyName name "INIT"
			dict set cellPropertyDict $propertyName type "hex"
			dict set cellPropertyDict $propertyName value "[expr 4*$bitSizeValue][string range $initString end-[expr ($bitSizeValue-1)] end]"
		}
    
		## Check if LOC property is set on cell
    	if {[get_property LOC $cellObj] ne ""} {
			## Add a set_property LOC constraint to the physical constraints list
			lappend physicalConstraintsList "set_property LOC [get_property LOC $cellObj] \[get_cells [dict get $opts(-dict_object) instance]\]"
			
			## Since LOC property exists and from a SLICE, check for BEL property, check if not MACRO level cell
			if {([regexp {^SLICE_} [get_property LOC $cellObj]]) && ([get_property BEL $cellObj] ne "") && ([get_property PRIMITIVE_LEVEL $cellObj] ne "MACRO")} {\
				## Add a set_property BEL constraint to the physical constraints list
				lappend physicalConstraintsList "set_property BEL [get_property -quiet BEL $cellObj] \[get_cells [dict get $opts(-dict_object) instance]\]"
			}
    	}
		
	} elseif {$objectType eq "port"} {	
		## Check the direction of the port object
		if {[dict get $opts(-dict_object) direction] eq "IN"} {
			## Append the port name to the input port list
			lappend inputPortsList [dict get $opts(-dict_object) net_name]
		} elseif {[dict get $opts(-dict_object) direction] eq "OUT"} {
			## Append the port name to the output port list
			lappend outputPortsList [dict get $opts(-dict_object) net_name]
		}
		
		## Check if the clock object exists for the cell pin
		if {[dict exists $opts(-dict_object) clock_object]} {
			dbg "Adding [dict get $opts(-dict_object) clock_object name] to clock dictionary"
			## Add the clock object to the clock object dictionary
			dict set clockObjectDict [dict get $opts(-dict_object) clock_object name] source_type [dict get $opts(-dict_object) type]
			dict set clockObjectDict [dict get $opts(-dict_object) clock_object name] source_name [dict get $opts(-dict_object) net_name]
							
			## Check if source pin exists in dictionary
			if {[dict exists $opts(-dict_object) clock_object source_clock_pin]} {
				## Add the clock object source clock pin for the generated clock
				dict set clockObjectDict [dict get $opts(-dict_object) clock_object name] source_clock_pin [dict get $opts(-dict_object) clock_object source_clock_pin]
			}
		}
	}
	
	# ## Check if the clock object exists for the cell pin
	# if {[dict exists $opts(-dict_object) clock_object]} {
		# dbg "Adding [dict get $opts(-dict_object) clock_object name] to Clock Dictionary"
		# ## Add the clock object to the clock object dictionary
		# dict set clockObjectDict [dict get $opts(-dict_object) clock_object name] source_type $objectType
		# dict set clockObjectDict [dict get $opts(-dict_object) clock_object name] source_name [dict get $opts(-dict_object) net_name]
		# ## Check if source pin exists in dictionary
		# if {[dict exists $opts(-dict_object) clock_object source_clock_pin]} {
			# ## Add the clock object source clock pin for the generated clock
			# dict set clockObjectDict [dict get $opts(-dict_object) clock_object name] source_clock_pin [dict get $opts(-dict_object) clock_object source_clock_pin]
		# }
	# }
	
	
	
	# ## Check the first index of the path to create the appropriate timing constraints, if available
	# if {$pathIndex==2} {
		# ## Check if the object is a port object
		# if {$objectType eq "port"} {
			# ## Get the port object from the object name
			# set portObj [get_ports -quiet [dict get $opts(-dict_object) name]]
			
			# ## Check if the port object exists
			# if {[llength $portObj]==0} {
				# return -code error "ERROR: \[path_to_verilog\] Unable to find port object [dict get $opts(-dict_object) name]."
			# } else {
				# ## Get the clocks associated from the port object
				# set clockObject [get_clocks -quiet -of_objects $portObj]
				
				# ## Check if clock object exists on the port object
				# if {[llength $clockObject]!=0} {
					# ## Add a create_clock constraint to the timing constraints list
					# lappend timingConstraintsList "create_clock -name [get_property NAME $clockObject] -period [get_property PERIOD $clockObject] -waveform {[get_property WAVEFORM $clockObject]} \[get_ports [dict get $opts(-dict_object) net_name]\]"
				# } else {
					# dbg "No Clock Found on Port $portObj."
				# }
			# }
		# ## Ensure that the cell has output pins associated with the timing path
		# } elseif {($objectType eq "cell") && ([llength $outputPinsDict]!=0)} {
			# ## Loop through each output pin of the cell to check for a timing constraint
			# dict for {dictKey dictValue} $outputPinsDict { 
				# ## Get the output name from associated pin dictionary
				# set outputFullPinName [get_pins -quiet [dict get $dictValue name]]
				# ## Get the clocks associated from the output pin object
				# set clockObject [get_clocks -quiet -of_objects [get_pins -quiet $outputFullPinName]]
				
				# ## Check if clock object exists on output pin
				# if {[llength $clockObject]>0} {
					# ## Set the name of the pin based on the associated name changes from the script
					# if {[regexp {.*/(\w+)} $outputFullPinName matchString outputPinName]} {
						# ## Set the new output pin name based on the associated timing path
						# set newOutputFullPinName "[dict get $opts(-dict_object) instance]/$outputPinName"
					# } else {
						# return -code error "ERROR: \[path_to_verilog\] Unable to parse pin $outputFullPinName to create associated timing constraint.."
					# }
					
					# ## Add a create_clock constraint to the timing constraints list
					# lappend timingConstraintsList "create_clock -name [get_property NAME $clockObject] -period [get_property PERIOD $clockObject] -waveform {[get_property WAVEFORM $clockObject]} \[get_pins $newOutputFullPinName\]"		
				# } 
			# }
		# }
	# }
	
	## Check if any clock objects have been defined
	if {[llength $clockObjectDict]>0} {
		dbg "Found Clock"
		## Loop through each key in the dictionary
		foreach clockObjectDictID [dict keys $clockObjectDict] {
			## Get the clock object
			set clockObject [get_clocks -quiet $clockObjectDictID]
			
			## Check if the clock object is a primary clock
			if {![get_property IS_GENERATED $clockObject]} {
				## Check if clock object is on a port 
				if {[dict get $clockObjectDict $clockObjectDictID source_type] eq "port"} {
					## Add a create_clock constraint to the timing constraints list
					lappend timingConstraintsList "create_clock -name [get_property NAME $clockObject] -period [get_property PERIOD $clockObject] -waveform {[get_property WAVEFORM $clockObject]} \[get_ports [dict get $clockObjectDict $clockObjectDictID source_name]\]"
				} else {
					## Add a create_clock constraint to the timing constraints list
					lappend timingConstraintsList "create_clock -name [get_property NAME $clockObject] -period [get_property PERIOD $clockObject] -waveform {[get_property WAVEFORM $clockObject]} \[get_pins [dict get $clockObjectDict $clockObjectDictID source_name]\]"		
				}
			} elseif {[get_property IS_GENERATED $clockObject]} {
				## Check if clock object is on a port 
				if {[dict get $clockObjectDict $clockObjectDictID source_type] eq "port"} {
					## Add a create generated clock to the timing constraints list
					lappend timingConstraintsList "create_generated_clock -name [get_property NAME $clockObject] -divide_by [expr ([string equal "" [get_property DIVIDE_BY $clockObject]])?"1":"[get_property DIVIDE_BY $clockObject]"] -multiply_by [expr ([string equal "" [get_property MULTIPLY_BY $clockObject]])?"1":"[get_property MULTIPLY_BY $clockObject]"] -source \[get_pins [dict get $clockObjectDict $clockObjectDictID source_clock_pin]\] \[get_ports [dict get $clockObjectDict $clockObjectDictID source_name]\]"
				} else {
					## Add a create generated clock to the timing constraints list
					lappend timingConstraintsList "create_generated_clock -name [get_property NAME $clockObject] -divide_by [expr ([string equal "" [get_property DIVIDE_BY $clockObject]])?"1":"[get_property DIVIDE_BY $clockObject]"] -multiply_by [expr ([string equal "" [get_property MULTIPLY_BY $clockObject]])?"1":"[get_property MULTIPLY_BY $clockObject]"] -source \[get_pins [dict get $clockObjectDict $clockObjectDictID source_clock_pin]\] \[get_pins [dict get $clockObjectDict $clockObjectDictID source_name]\]"
				}
			}
		}
	}
	
	## Get the exceptions report to determine if the cell belongs to a timing exception constraint
	#set exceptionsReport [report_exceptions -quiet -return_string -from [get_cells -quiet [dict get $opts(-dict_object) name]]
	
	## Loop through each generated port in dictionary and store into input and output port lists
	foreach generatedPortsDictID [dict keys $generatedPortsDict] {
		## Check if port is an input
		if {[dict get $generatedPortsDict $generatedPortsDictID direction] eq "IN"} {
			## Append generated input port to the input ports list
			lappend inputPortsList [dict get $generatedPortsDict $generatedPortsDictID name]
		## Check if port is an output
		} elseif {[dict get $generatedPortsDict $generatedPortsDictID direction] eq "OUT"} {
			## Append generated output port to the output ports list
			lappend outputPortsList [dict get $generatedPortsDict $generatedPortsDictID name]
		}
	}
	
	## Loop through each fixed route in the dictionary
	foreach fixedRouteDictID [dict keys $fixedRouteDict] {
		## Append the fixed route constraint to the routing constraint list
		lappend routingConstraintsList "set_property FIXED_ROUTE \{[dict get $fixedRouteDict $fixedRouteDictID fixed_route]\} \[get_nets [dict get $fixedRouteDict $fixedRouteDictID net_name]\]"
	}
	
	if {[info exists lockPinsArray]} {
		foreach netName [array names lockPinsArray] {
			lappend physicalConstraintsList "set_property LOCK_PINS \{$lockPinsArray($netName)\} \[get_cells [dict get $opts(-dict_object) instance]\]"
		}
	}
		
	## Set the type of cell for the Verilog object dictionary
	dict set verilogObjDict type $objectType
	
	## Check if the object type is of type cell
	if {$objectType eq "cell"} {
		## Set the REF_NAME, instance name, and pins of the Verilog object dictionary
        dict set verilogObjDict ref_name  [get_property REF_NAME $cellObj]
		dict set verilogObjDict orig_name $cellObj
		dict set verilogObjDict name      [dict get $opts(-dict_object) instance]
        dict set verilogObjDict pins      $cellObjectPinsDict
		 
		## Set the properties value of the Verilog object dictionary
		dict set verilogObjDict properties $cellPropertyDict
	} else {
		## Set the port net name as the Verilog object name
		dict set verilogObjDict name     [dict get $opts(-dict_object) net_name]
		## Set the port name as the original name for the Verilog object
		dict set verilogObjDict orig_name [dict get $opts(-dict_object) name]
	}
    
	## Set the input and output ports of the Verilog module
	dict set verilogObjDict input_ports    $inputPortsList
    dict set verilogObjDict output_ports   $outputPortsList
	
	## Set the timing constraints value of the Verilog object dictionary
	dict set verilogObjDict timing_constraints $timingConstraintsList		
	
	## Set the physical constraints value of the Verilog object dictionary
	dict set verilogObjDict physical_constraints $physicalConstraintsList

	## Set the routing constraints value of the Verilog object dictionary
    dict set verilogObjDict routing_constraints $routingConstraintsList

	## Return Verilog object dictionary
    return $verilogObjDict
}

# #########################################################
# write_verilog_testcase
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::write_verilog_testcase {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0}
    
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
            {-d(e(s(i(g(n(_(n(a(m(e)?)?)?)?)?)?)?)?)?)?$}    { set opts(-design_name) [lshift args]}
			{-d(i(c(t)?)?)?$}                                { set opts(-dict)        [lshift args]}
            {-h(e(l(p)?)?)?$}                                { set opts(-help)        1}
            default {
                return -code error "ERROR: \[write_verilog_testcase\] Unknown option '[lindex $args 0]', please type 'write_verilog_testcase -help' for usage info."
            }
        }
    }
   	
	puts "INFO: \[write_verilog_testcase\] Creating Verilog Structural Netlist: $opts(-design_name).v"
	
    ## Open a filehandle channell for the Verilog structural netlist
	set fileChannelID [open "$opts(-design_name).v" w]    
    
    ## Write the Verilog code to the opened filehandle
    write_verilog_testcase_top_level -channel_id $fileChannelID -design_name $opts(-design_name) -dict $opts(-dict)

	## Close the filehandle channel   
    close $fileChannelID

	puts "INFO: \[write_verilog_testcase\] Creating XDC Constraints File: $opts(-design_name).xdc"
	
    ## Open a filehandle for the XDC constraints file
    set fileChannelID [open "$opts(-design_name).xdc" w]    

    ## Write the constraints code to the opened filehandle        
    write_verilog_testcase_xdc -channel_id $fileChannelID -dict $opts(-dict)

	## Close the filehandle channel       
    close $fileChannelID
    
	puts "INFO: \[write_verilog_testcase\] Creating Vivado Tcl Run Script: $opts(-design_name).tcl"
	
    ## Open a filehandle for the design run script
    set fileChannelID [open "$opts(-design_name).tcl" w]    

    ## Write the design run script to the opened filehandle         
   write_verilog_testcase_script -channel_id $fileChannelID -design_name $opts(-design_name) 1

	## Close the filehandle channel    
    close $fileChannelID
}

# #########################################################
# write_verilog_testcase_top_level
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::write_verilog_testcase_top_level {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
 	## Set Default option values
	array set opts {-help 0}
    
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
			{-c(h(a(n(n(e(l(_(i(d)?)?)?)?)?)?)?)?)?$}        { set opts(-channel_id)  [lshift args]}
            {-d(e(s(i(g(n(_(n(a(m(e)?)?)?)?)?)?)?)?)?)?$}    { set opts(-design_name) [lshift args]}
			{-d(i(c(t)?)?)?$}                                { set opts(-dict)        [lshift args]}
            {-h(e(l(p)?)?)?$}                                { set opts(-help)        1}
            default {
                return -code error "ERROR: \[write_verilog_testcase_top_level\] Unknown option '[lindex $args 0]', please type 'write_verilog_testcase_top_level -help' for usage info."
            }
        }
    }
	
	## Loop through each verilog object in the dictionary
	foreach verilogDictID [dict keys $opts(-dict)] {
		## Get the verilog object dictionary
		set verilogDict [dict get $opts(-dict) $verilogDictID]
		
		## Append all the ports created for this verilog object to the top-level input ports list
		lappend inputPortList [dict get $verilogDict input_ports]
		
		## Append all the ports created for this verilog object to the top-level output ports list
		lappend outputPortList [dict get $verilogDict output_ports]
		
		## Check if the Verilog object is of type cell
		if {[dict get $verilogDict type] eq "cell"} {
			## Write the Verilog instantiation from the Verilog cell dictionary
			lappend verilogInstanceList [write_verilog_instantiation -dict $verilogDict]
		}
	}
	
	## Print the Verilog top-level module declaration to the filehandle channel id
    puts $opts(-channel_id) "module $opts(-design_name) ([join [concat [concat {*}$inputPortList] [concat {*}$outputPortList]] ", "]);\n"
    
	## Print the Verilog port declarations to the filehandle channel id
    puts $opts(-channel_id) "\tinput  [join [concat {*}$inputPortList] ", "];\n"
    puts $opts(-channel_id) "\toutput [join [concat {*}$outputPortList] ", "];\n"
    
	## Loop through each Verilog object instantiation
    foreach verilogInstance $verilogInstanceList {
		## Print the Verilog cell instantiation to the filehandle channel id
    	puts $opts(-channel_id) $verilogInstance
    }
    
	## Print the endmodule declaration
    puts $opts(-channel_id) "\nendmodule"
	
	## Return from the procedure
	return
}

# #########################################################
# write_verilog_instantiation
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::write_verilog_instantiation {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
 	## Set Default option values
	array set opts {-help 0}
    
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
			{-d(i(c(t)?)?)?$}                                { set opts(-dict)        [lshift args]}
            {-h(e(l(p)?)?)?$}                                { set opts(-help)        1}
            default {
                return -code error "ERROR: \[write_verilog_instantiation\] Unknown option '[lindex $args 0]', please type 'write_verilog_instantiation -help' for usage info."
            }
        }
    }

	## Initialize Verilog Instantiation String
	set verilogInstantiationString ""
	
	## Get the properties listed for the cell object in the dictionary
	set cellPropertyDict [dict get $opts(-dict) properties]
	
	## Check if any cell properties exist in the dictionary
	if {[llength $cellPropertyDict]>0} {
		## Append the module name instantiation of the cell object
		append verilogInstantiationString "\t[dict get $opts(-dict) ref_name] # (\n"
		
		## Loop through each cell property in the dictionary
		foreach cellPropertyDictID [dict keys $cellPropertyDict] {
			## Get the value type of the property
			set propertyValueType [dict get $cellPropertyDict $cellPropertyDictID type]
			
			## Check if the value type is string or enum
			if {$propertyValueType eq "string" || $propertyValueType eq "enum"} {
				## Append the property to the instantiation with double-quotes around the value
				append verilogInstantiationString "\t\t.[dict get $cellPropertyDict $cellPropertyDictID name]\(\"[dict get $cellPropertyDict $cellPropertyDictID value]\"),\n"
			} else {
				## Append the property to the instantiation
				append verilogInstantiationString "\t\t.[dict get $cellPropertyDict $cellPropertyDictID name]\([dict get $cellPropertyDict $cellPropertyDictID value]),\n"
			}
		}
		
		## Remove the final comma since the last cell property has been processed
       	set verilogInstantiationString [string range $verilogInstantiationString 0 end-2]
        
        ## Append the instance name of the Verilog cell instantiation
        append verilogInstantiationString "\n\t) [dict get $opts(-dict) name] (\n"
		
	## No cell properties found
	} else {
    	## Append the module name and instance name for the instantiation of the cell object
    	append verilogInstantiationString "\t[dict get $opts(-dict) ref_name] [dict get $opts(-dict) name] (\n"
    }
    
	## Get the pins listed for the cell object in the dictionary
	set cellPinsDict [dict get $opts(-dict) pins]	
	
	## Loop through each cell pin in the dictionary
	foreach cellPinsDictID [dict keys $cellPinsDict] {
		## Get the cell pin dictionary for the given ID
		set cellPinDict [dict get $cellPinsDict $cellPinsDictID]
		
		## Check if cell pin is of type scalar
		if {[dict get $cellPinDict type] eq "scalar"} {
			## Check if the pin is connected
			if {[dict exists $cellPinDict bus_index]} {
				## Append the scalar pin to the instantiation
				append verilogInstantiationString "\t\t.[dict get $cellPinDict pin_name]\([dict get $cellPinDict bus_index 0 value]\),\n"
			} else {
				append verilogInstantiationString "\t\t.[dict get $cellPinDict pin_name]\(\),\n"
			}
		} else {
			## Initialize vector list variable for the pin
			set pinVectorList {}
			
			## Loop through all keys in the dictionary to find the vector numeric keys
			foreach cellPinDictKey [dict keys [dict get $cellPinDict bus_index]] {
				## Check if the cell pin dictionary key is a integer value equivalent to the bit location
				if {[regexp {\d+} $cellPinDictKey]} {
					## Insert the net name in the cell pins dictionary for the given vector bit to the pin vector list
					set pinVectorList [linsert $pinVectorList $cellPinDictKey [dict get $cellPinDict bus_index $cellPinDictKey value]]
				}
			}
			
			## Order the signal list to match the required Verilog instantiation format
			set orderedPinVectorList [join [lreverse $pinVectorList] ","]
			
			## Append the vector signals to the instantiation
			append verilogInstantiationString "\t\t.[dict get $cellPinDict pin_name]\(\{$orderedPinVectorList\}\),\n"			
		}
    }
    
	## Remove the final comma since the last cell pin has been processed
    set verilogInstantiationString [string range $verilogInstantiationString 0 end-2]
    
	## Append a line break and a close brace for the end of the port instantiation
    append verilogInstantiationString "\n\t);\n"

    ## Return the Verilog cell instantiation string
    return $verilogInstantiationString
}

# #########################################################
# write_verilog_testcase_xdc
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::write_verilog_testcase_xdc {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
 	## Set Default option values
	array set opts {-help 0}
    
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
			{-c(h(a(n(n(e(l(_(i(d)?)?)?)?)?)?)?)?)?$}        { set opts(-channel_id)  [lshift args]}
			{-d(i(c(t)?)?)?$}                                { set opts(-dict)        [lshift args]}
            {-h(e(l(p)?)?)?$}                                { set opts(-help)        1}
            default {
                return -code error "ERROR: \[write_verilog_testcase_xdc\] Unknown option '[lindex $args 0]', please type 'write_verilog_testcase_xdc -help' for usage info."
            }
        }
    }
	
	## Initialize timing, physical, and routing constraint variables
	set physicalConstraintsList {}
    set timingConstraintsList   {}
	set routingConstraintsList  {}

	## Loop through each verilog object in the dictionary
	foreach verilogDictID [dict keys $opts(-dict)] {
		## Get the verilog object dictionary
		set verilogDict [dict get $opts(-dict) $verilogDictID]
		
		## Append all the physical constraints created for this verilog object to the top-level physical constraints list
		lappend physicalConstraintsList [dict get $verilogDict physical_constraints]
		
		## Append all the routing constraints created for this verilog object to the top-level routing constraints list
		lappend routingConstraintsList [dict get $verilogDict routing_constraints]

		## Append all the timing constraints created for this verilog object to the top-level timing constraints list
		lappend timingConstraintsList [dict get $verilogDict timing_constraints]
	}
	
	## Check there exists at least 1 physical constraint
	if {[llength $physicalConstraintsList]>0} {
		## Print a physical constraint header to the filehandle channel 
		puts $opts(-channel_id) "#####################################################################################################"
		puts $opts(-channel_id) "## Physical Constraints                                                                            ##"
		puts $opts(-channel_id) "#####################################################################################################"     
		
		## Print the physical constraints to the filehandle channel 
		puts $opts(-channel_id) [join [join $physicalConstraintsList "\n"] "\n"]
		## Add for output file readability
		puts $opts(-channel_id) "\n"
    }

	## Check there exists at least 1 routing constraint
    if {[llength $routingConstraintsList]>0} {
        ## Print a routing constraint header to the filehandle channel
        puts $opts(-channel_id) "#####################################################################################################"
        puts $opts(-channel_id) "## Routing Constraints                                                                             ##"
        puts $opts(-channel_id) "#####################################################################################################"

        ## Print the physical constraints to the filehandle channel
        puts $opts(-channel_id) [join [join $routingConstraintsList "\n"] "\n"]
        ## Add for output file readability
        puts $opts(-channel_id) "\n"
    }
	
	## Check there exists at least 1 timing constraint
	if {[llength $timingConstraintsList]>0} {
		## Print a timing constraint header to the filehandle channel 
		puts $opts(-channel_id) "#####################################################################################################"
		puts $opts(-channel_id) "## Timing Constraints                                                                              ##"
		puts $opts(-channel_id) "#####################################################################################################"  
    	
		## Print the timing constraints to the filehandle channel 
		puts $opts(-channel_id) [join [join $timingConstraintsList "\n"] "\n"]
		## Add for output file readability
		puts $opts(-channel_id) "\n"		
	}

	## Return from the procedure
	return
}

# #########################################################
# write_verilog_testcase_script
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::write_verilog_testcase_script {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
 	## Set Default option values
	array set opts {-help 0 -implemented 0}
    
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
			{-c(h(a(n(n(e(l(_(i(d)?)?)?)?)?)?)?)?)?$}        { set opts(-channel_id)  [lshift args]}
            {-d(e(s(i(g(n(_(n(a(m(e)?)?)?)?)?)?)?)?)?)?$}    { set opts(-design_name) [lshift args]}
			{-i(m(p(l(e(m(e(n(t(e(d)?)?)?)?)?)?)?)?)?)?$}    { set opts(-implemented) [lshift args]}
            {-h(e(l(p)?)?)?$}                                { set opts(-help)        1}
            default {
                return -code error "ERROR: \[write_verilog_testcase_top_level\] Unknown option '[lindex $args 0]', please type 'write_verilog_testcase_top_level -help' for usage info."
            }
        }
    }
    
	## Print the commands to read the design into Vivado to the filehandle channel
    puts $opts(-channel_id) "read_verilog $opts(-design_name).v"
    puts $opts(-channel_id) "read_xdc $opts(-design_name).xdc"
    puts $opts(-channel_id) "link_design -mode out_of_context -top $opts(-design_name) -part [get_property PART [current_design]]"
    
	## If the Implementation Flag is set, add route_design to the script.
	if {$opts(-implemented)==1} {
		puts $opts(-channel_id) "route_design"
	}
	
	## Add the report_timing command to report the worst timing paths
    puts $opts(-channel_id) "report_timing"
 
	## Return from the procedure
	return 
}

# #########################################################
# parse_object_list
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::parse_object_list {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0}
	
	## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
			-k(l(a(s(s(e(s)?)?)?)?)?)?     { set opts(-klasses)     [lshift args]}
			-o(b(j(e(c(t(s)?)?)?)?)?)?     { set opts(-objects)     [lshift args]}
			-h(e(l(p)?)?)?                 { set opts(-help)        1}
            default {
                return -code error "ERROR: \[parse_object_list\] Unknown option '[lindex $args 0]', please type 'parse_object_list -help' for usage info."
            }
        }
    }
	
	## Display help information
    if {$opts(-help) == 1} {
        return
    }
	
	## Initialize Object List variable
	set objectList [list]
	
	## Loop through each object passed as an argument option
	foreach optionObj $opts(-objects) {
		## Get the Class name of the object
		set klassName [get_property CLASS $optionObj]
		## Search to check if object klass is of a supported type
		if {[lsearch $opts(-klasses) $klassName]>-1} {
			lappend objectList $optionObj
		} else {
			## Count the number of unsupported klasses
			incr klassArray($klassName) 1
		}
	}
	
	##
	if {[array exists klassArray]} {
		## Get all found unsupported klass names
		set klassList [array names klassArray]
		
		foreach klassName [array names klassArray] {
			incr klassCount $klassArray($klassName)
		}
		
		puts "CRITICAL WARNING: [get_current_proc_name]: list of objects specified contains $klassCount object(s) of types '([join $klassList ", "])' other than the types '([join $opts(-klasses) ", "])' supported by the constraint.\n"
	}
	
	## Return the supported object list
	return $objectList
}

# #########################################################
# lshift
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::lshift {varname} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	upvar $varname argv
	set r [lindex $argv 0]
	set argv [lrange $argv 1 end]
	return $r
}

# #########################################################
# lunshift
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::lunshift {varname val {nth 0}} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	upvar $varname argv
	set argv [concat $val $argv]
}

# #########################################################
# 
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::get_current_main_proc_name {} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	return [lindex [info level 1] 0]
}

# #########################################################
# 
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::get_current_proc_name {} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	return [lindex [info level [expr [info level]-1]] 0]
}

# #########################################################
# 
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::get_current_proc_call_by_name {} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	return [lindex [info level [expr [info level]-2]] 0]
}

# #########################################################
# 
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::get_path_dict_by_cell_name {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0}
	
	## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
			{-d(i(c(t)?)?)?$}         { set opts(-dict)    [lshift args]}
			{-v(a(l(u(e)?)?)?)?$}     { set opts(-value)   [lshift args]}
			{-h(e(l(p)?)?)?}          { set opts(-help)    1}
            default {
                return -code error "ERROR: \[get_path_dict_by_cell_name\] Unknown option '[lindex $args 0]', please type 'get_path_dict_by_cell_name -help' for usage info."
            }
        }
    }
	
	set pathObject ""
	
	dict for {dictKey dictVal} $opts(-dict) { 
		if {[catch {dict get $dictVal "name"} keyName] == 0 && $keyName eq $opts(-value)} {
			set pathObject $dictVal
		}
	}
	
	return $pathObject
}

# #########################################################
# 
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::path_cell_name_exists? {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0}
	
	## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
			{-d(i(c(t)?)?)?$}         { set opts(-dict)    [lshift args]}
			{-v(a(l(u(e)?)?)?)?$}     { set opts(-value)   [lshift args]}
			{-h(e(l(p)?)?)?}          { set opts(-help)    1}
            default {
                return -code error "ERROR: \[path_cell_name_exists?\] Unknown option '[lindex $args 0]', please type 'path_cell_name_exists? -help' for usage info."
            }
        }
    }
	
	return [dictionary_value_exists? -dict $opts(-dict) -key "name" -value $opts(-value)]
}

# #########################################################
# 
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::dictionary_value_exists? {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0}
	
	## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
        switch -regexp -- $optionName {
			{-d(i(c(t)?)?)?$}         { set opts(-dict)    [lshift args]}
			{-k(e(y)?)?$}             { set opts(-key)     [lshift args]}
			{-v(a(l(u(e)?)?)?)?$}     { set opts(-value)   [lshift args]}
			{-h(e(l(p)?)?)?$}         { set opts(-help)    1}
            default {
                return -code error "ERROR: \[dictionary_value_exists?\] Unknown option '[lindex $args 0]', please type 'dictionary_value_exists? -help' for usage info."
            }
        }
    }
	
	set booleanResult false
	
	dict for {dictKey dictVal} $opts(-dict) { 
		if {[catch {dict get $dictVal $opts(-key)} keyName] == 0 && $keyName eq $opts(-value)} {
			set booleanResult true
		}
	}
	
	return $booleanResult
}

# #########################################################
# 
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::debug_print_cell_timing_path_dict {timingPathCellDict} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	dbg "\tType:         [dict get $timingPathCellDict type]"
	dbg "\tName:         [dict get $timingPathCellDict name]"
	dbg "\tTag:          [dict get $timingPathCellDict tag]"
	dbg "\tIndex:        [dict get $timingPathCellDict index]"
	if {[dict get $timingPathCellDict type] ne "port"} {
		dbg "\tInput Pins:   [dict get $timingPathCellDict input_pins]"
		dbg "\tOutput Pins:  [dict get $timingPathCellDict output_pins]"
		dbg "\tClock Pins:   [dict get $timingPathCellDict clock_pins]"
		
	}
	
	if {[dict exists $timingPathCellDict clock_object]} {
		dbg "\tClock Object: [dict get $timingPathCellDict clock_object name]"
	}
}

# #########################################################
# 
# #########################################################
proc ::tclapp::xilinx::designutils::timing_report_to_verilog::debug_print_verilog_object_dict {verilogObjectDict} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	dbg "\tREF_NAME:       [dict get $verilogObjectDict ref_name]"
	dbg "\tName:           [dict get $verilogObjectDict name]"
	dbg "\tPins:           [dict get $verilogObjectDict pins]"
	dbg "\tProperties:     [dict get $verilogObjectDict properties]"
	dbg "\tInput Ports:    [dict get $verilogObjectDict input_ports]"
	dbg "\tOutput Ports:   [dict get $verilogObjectDict output_ports]"
	dbg "\tPhysical Const: [dict get $verilogObjectDict physical_constraints]"
	dbg "\tTiming Const:   [dict get $verilogObjectDict timing_constraints]"
}
