package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export convert_muxfx_to_luts
}

proc ::tclapp::xilinx::designutils::convert_muxfx_to_luts {args} {
	# Summary : Replaces MUXFX cells with LUT3 cells in an open synthesized design

	# Argument Usage:
	# [-cell <arg> = current_instance]: Root of the design to process the MUXFX replacement. If not specified, runs on current_instance
	# [-only_muxf8]: Replaces only MUXF8 cells
	# [-usage]: Usage information

	# Return Value:
	# 0 if success

	# Categories: xilinxtclstore, designutils

	return [uplevel ::tclapp::xilinx::designutils::convert_muxfx_to_luts::convert_muxfx_to_luts $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::convert_muxfx_to_luts {
    variable prevPC
} ]

proc ::tclapp::xilinx::designutils::convert_muxfx_to_luts::convert_muxfx_to_luts {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinxtclstore, designutils
	
	## Set Default option values
	array set opts {-help 0}
    
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
		switch -regexp -- $optionName {
			{-c(e(l(l)?)?)?$}                          { set opts(-cell)       [lshift args]}
			{-o(n(l(y(_(m(u(x(f(8)?)?)?)?)?)?)?)?)?$}  { set opts(-only_muxf8) 1}
            {-h(e(l(p)?)?)?$}                          { set opts(-help)       1}
            {-u(s(a(g(e)?)?)?)?$}                      { set opts(-help)       1}			
            default {
                return -code error "ERROR: \[convert_mux_cells_to_luts\] Unknown option '[lindex $args 0]', please type 'convert_mux_cells_to_luts -help' for usage info."
            }
        }
    }

		## Display help information
    if {$opts(-help) == 1} {
        puts "convert_muxfx_to_luts\n"
        puts "Description:"
        puts "  Replaces MUXFX cells with LUT3 cells in an open synthesized design"
        puts ""
        puts "Syntax:"
        puts "  convert_muxfx_to_luts \[-cell <arg>\] \[-only_muxf8\] \[-help\]"
        puts ""
        puts "Usage:"
        puts "  Name                Description"
        puts "  -------------------------------"
        puts "  \[-cell\]             Given cell hierarchy for processing."
        puts "                      Default: \[current_instance .\]"
        puts "  \[-only_muxf8\]       Replaces only MUXF8 cells."
        puts ""
        puts "Description:"
        puts ""
        puts "  Replaces all the MUXFX (MUXF7 and MUXF8) cells within an open synthesized design"
        puts "  with LUT3 cells.  The design must be unplaced and the MUXFX cells cannot be part"
        puts "  of a primitive macro."
        puts ""
        puts "Example:"
        puts ""
        puts "  The following example will replace all the MUXF7 and MUXF8 cells within"
        puts "  the opened synthesized design."
        puts ""
        puts "  convert_muxfx_to_luts"
        puts ""
        return
    }
	
	## Get the current instance scope of the design as the script was executed
	set origCurrentInstanceCell [current_instance -quiet .]
	
	## Check if the -cell option was used, verify the option is correct
	if {[info exists opts(-cell)]} {
		## Get cell object from the -cell option
		set optionCellObj [get_cells -quiet $opts(-cell)]
		
		## Check if object exists
		if {[llength $optionCellObj]==0} {
			return -code error "ERROR: \[convert_mux_cells_to_luts\] Unable to find cell object $opts(-cell) from -cell option."
		## Check if more than one object was returned
		} elseif {[llength $optionCellObj]>1} {
			return -code error "ERROR: \[convert_mux_cells_to_luts\] Found more than 1 cell object ([join $optionCellObj ',']) from -cell option."
		} else {
			## Set the current instance to the top of the design
			current_instance -quiet
			## Set the current instance to the cell object set by the -cell option
			current_instance -quiet $optionCellObj
		}
	}	
	
	## Check if the -only_muxf8 option was used, add only the MUXF8 to cell list if yes
	if {[info exists opts(-only_muxf8)]} {
		## Get the list of the MUXF8 cells in the design
		set cellList [get_cells -quiet -hier -filter {REF_NAME==MUXF8}]	
	} else {
		## Get the list of all the MUXFX cells in the design
		set cellList [get_cells -quiet -hier -filter {REF_NAME==MUXF7 || REF_NAME==MUXF8}]
	}
	
	## Check that at least one cell exists in the list
	if {[llength $cellList]==0} {
		puts "INFO: \[convert_mux_cells_to_luts\] No MUXFX cells found in the design from level [current_instance -quiet .]."
		return
	} else {
		puts "INFO: \[convert_mux_cells_to_luts\] Found [llength $cellList] MUX cells in the design from level [current_instance -quiet .]."
	}
	
	## Reset the current instance back to the top-level scope to properly create and connect objects
	current_instance -quiet
	
	## Initialize the warning list variable
	set warningList ""
	
	## Initialize the cell count variable
	set cellCount 0
	
	## Get the total count of MUXFX cells in the list
	set totalCount [llength $cellList]
	
	## Loop through each cell object in the list
	foreach cellObj $cellList {
		## Increment the cell count for the Progress Bar
		incr cellCount 1
		
		## Check to ensure that Vivado is not in GUI mode
		if {$rdi::mode!="gui"} {
			## Update the Progress Bar
			tclapp::xilinx::designutils::convert_muxfx_to_luts::progressBar $totalCount $cellCount
		}
		
		## Check to ensure that the MUX is not part of a MACRO cell
		if {[get_property -quiet PRIMITIVE_LEVEL $cellObj] eq "INTERNAL"} {
			lappend warningList "CRITICAL WARNING: \[convert_mux_cells_to_luts\] MUX cell $cellObj belongs to MACRO level primitive.  Unable to convert this primitive."
			## Move to the next cell object
			continue
		}
		
		## Get the pins associated with the cell object
		set pinList [get_pins -quiet -of_objects $cellObj]
		
		## Set the name of the new LUT object
		set lutCellName "$cellObj\_LUT_replacement"
		
		## Create a LUT cell
		if {[catch {create_cell -reference "LUT3" $lutCellName} returnString]} {
			## Append to the warning list the error returned
			lappend warningList $returnString
			## Move to the next cell object
			continue			
		}
		
		## Get the newly created LUT3 cell
		set lutCellObj [get_cells -quiet $lutCellName]
		
		## Check to ensure that the LUT object was created
		if {[llength $lutCellObj]==0} {
			lappend warningList "CRITICAL WARNING: \[convert_mux_cells_to_luts\] Unable to find newly created LUT cell $lutCellName for MUX $cellObj."
			## Move to the next cell object
			continue
		}
		
		## Set the INIT string of the new LUT object
		set_property INIT "8'hAC" $lutCellObj
		
		## Initialize the pin count
		set pinCount 0
		
		## Loop through each pin object in the pin list
		foreach pinObj $pinList {
			## Get the net object from the pin
			set netObj [get_nets -quiet -of_object $pinObj]

			## Check that a net object exists
			if {[llength $netObj]==0} {
				## Skip the pin and move to the next pin in the list
				continue
			}
			
			## Parse the pin object based on the pin name
			switch -regexp "$pinObj" {
				".*/S$" {
					## Get the I2 pin of the LUT cell
					set lutPinObj [get_pins -quiet "$lutCellName/I2"]
					
					## Check that the LUT pin exists
					if {[llength $lutPinObj]==0} {
						return -code error "ERROR: \[convert_mux_cells_to_luts\] Unable to find LUT pin $lutCellName/I2"
					}
		
					## Connect the net object to the I2 pin of the LUT3
					if {[catch {connect_net -hier -net $netObj -objects $lutPinObj} returnString]} {
						## If error occurred during the connection, delete the LUT object
 						#remove_cell -quiet $lutCellObj
                        # The linter complains on the above line. The workaround is to call remove_cell as below:
                        eval [list remove_cell -quiet $lutCellObj]
						## Append to the warning list the error returned
						lappend warningList $returnString
						## Break the loop and move onto the next MUXFX cell
						break
					}
					
					## Increment the total pin count of the list
					incr pinCount 1
				}
				".*/I0$" {
					## Get the I1 pin of the LUT cell
					set lutPinObj [get_pins -quiet "$lutCellName/I1"]
					
					## Check that the LUT pin exists
					if {[llength $lutPinObj]==0} {
						return -code error "ERROR: \[convert_mux_cells_to_luts\] Unable to find LUT pin $lutCellName/I1"
					}
		
					## Connect the net object to the I1 pin of the LUT3
					if {[catch {connect_net -hier -net $netObj -objects $lutPinObj} returnString]} {
						## If error occurred during the connection, delete the LUT object
 						#remove_cell -quiet $lutCellObj
                        # The linter complains on the above line. The workaround is to call remove_cell as below:
                        eval [list remove_cell -quiet $lutCellObj]
						## Append to the warning list the error returned
						lappend warningList $returnString
						## Break the loop and move onto the next MUXFX cell
						break
					}
					
					## Increment the total pin count of the list
					incr pinCount 1
				}
				".*/I1$" {
					## Get the I0 pin of the LUT cell
					set lutPinObj [get_pins -quiet "$lutCellName/I0"]
					
					## Check that the LUT pin exists
					if {[llength $lutPinObj]==0} {
						return -code error "ERROR: \[convert_mux_cells_to_luts\] Unable to find LUT pin $lutCellName/I0"
					}
		
					## Connect the net object to the I0 pin of the LUT3
					if {[catch {connect_net -hier -net $netObj -objects $lutPinObj} returnString]} {
						## If error occurred during the connection, delete the LUT object
 						#remove_cell -quiet $lutCellObj
                        # The linter complains on the above line. The workaround is to call remove_cell as below:
                        eval [list remove_cell -quiet $lutCellObj]
						## Append to the warning list the error returned
						lappend warningList $returnString
						## Break the loop and move onto the next MUXFX cell
						break
					}
					
					## Increment the total pin count of the list
					incr pinCount 1
				}
				".*/O$" {
					## Get the O pin of the LUT cell
					set lutPinObj [get_pins -quiet "$lutCellName/O"]
					
					## Check that the LUT pin exists
					if {[llength $lutPinObj]==0} {
						return -code error "ERROR: \[convert_mux_cells_to_luts\] Unable to find LUT pin $lutCellName/O"
					}
		
					## Connect the net object to the O pin of the LUT3
					if {[catch {connect_net -hier -net $netObj -objects $lutPinObj} returnString]} {
						## If error occurred during the connection, delete the LUT object
 						#remove_cell -quiet $lutCellObj
                        # The linter complains on the above line. The workaround is to call remove_cell as below:
                        eval [list remove_cell -quiet $lutCellObj]
						## Append to the warning list the error returned
						lappend warningList $returnString
						## Break the loop and move onto the next MUXFX cell
						break
					}
					
					## Increment the total pin count of the list
					incr pinCount 1
				}
				default {
					## Error if unable to determine pin of MUXFX
					return -code error "ERROR: \[convert_mux_cells_to_luts\] Unable to determine equivalent LUT pin for MUXFX object pin $pinObj."
				}	
			}
		}
		
		## Check to ensure the entire pin list was converted
		if {$pinCount==[llength $pinList]} {
			## Delete the MUXFX cell
 			#remove_cell -quiet $cellObj
            # The linter complains on the above line. The workaround is to call remove_cell as below:
            eval [list remove_cell -quiet $cellObj]
		} else {
			## Append to the warning list that the MUX was not converted
			lappend warningList "CRITICAL WARNING: \[convert_mux_cells_to_luts\] Unable to convert MUX $cellObj to LUT object."
		}
	}
	
	## Print WARNING messages if applicable
	if {[llength $warningList]>0} {
		puts [join $warningList "\n"];
	}
	
	## Reset the current instance back to the scope prior to script execution
	current_instance -quiet
	
	## Check if the original current instance value is empty
	if {[llength $origCurrentInstanceCell] == 0} {
		## Set the current instance to the top-level design
		current_instance -quiet [get_property TOP [current_design]]
	} else {
		## Set the current instance based on the original current cell instance
		current_instance -quiet $origCurrentInstanceCell
	}

	return 0
}

# #########################################################
# lshift
# #########################################################
proc ::tclapp::xilinx::designutils::convert_muxfx_to_luts::lshift {varname} {
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

# ###################################################################
# Name:  progressBar
# Usage: progressBar totalsize current
# Descr: show progress bar and % of completion
#        source: http://wiki.tcl.tk/5953
# ###################################################################
proc ::tclapp::xilinx::designutils::convert_muxfx_to_luts::progressBar {totalsize current} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinxtclstore, designutils
	
    variable prevPC
    if {![info exist prevPC]} {set prevPC -1}
    if {$totalsize == 0} { set totalsize $current }
    set percent [expr int(100.1 * $current/$totalsize)]
    if {$percent == $prevPC} {return} else {set prevPC $percent}
    set txt "\r  |"
    set portion [expr 40.0 * $current/$totalsize]
    for {set x 0} {$x <= $portion} {incr x} { append txt "=" }
    for {} {$x < 40} {incr x} { append txt " " }
    append txt "| [format "%3d" $percent] %"
    puts -nonewline $txt
    flush stdout
    if {$totalsize == $current} {
        puts "\n\n"
        flush stdout
        set prevPC -1
    }
}
