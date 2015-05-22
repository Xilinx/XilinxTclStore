package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export write_loc_constraints
}

proc ::tclapp::xilinx::designutils::write_loc_constraints {args} {
	# Summary : Creates a constraints file with the specified design LOCs

    # Argument Usage:
    # -file <arg>: Name of the output constraint file
    # [-all_placement]: Include non-fixed cell placement
    # [-cell <arg>]: Given cell hierarchy for processing
    # [-force]: Overwrite existing file
    # [-include_bels]: Include BEL level placement constraints
    # [-of_objects <arg>]: List of objects of which to create LOC constraints
    # [-primitive_group <arg>]: Filter cells by the specified group

	# Return Value:
	# file name

	# Categories: xilinxtclstore, designutils
	
	return [uplevel [concat [list ::tclapp::xilinx::designutils::write_loc_constraints::write_loc_constraints] $args]]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::write_loc_constraints {
} ]

proc ::tclapp::xilinx::designutils::write_loc_constraints::write_loc_constraints {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinxtclstore, designutils
	
	## Set Default option values
	array set opts {-help 0 -include_bels 0}
	
	## Set the command line used
	set commandLine "write_loc_constraints $args"
	
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
		switch -regexp -- $optionName {
			{-a(l(l(_(p(l(a(c(e(m(e(n(t)?)?)?)?)?)?)?)?)?)?)?)?$}         { set     opts(-all_placement)   1}
			{-c(e(l(l)?)?)?$}                                             { set     opts(-cell)            [lshift args]}
            {-fi(l(e)?)?$}                                                { set     opts(-file)            [lshift args]}
			{-fo(r(c(e)?)?)?$}                                            { set     opts(-force)           1}
			{-i(n(c(l(u(d(e(_(b(e(l(s)?)?)?)?)?)?)?)?)?)?)?}              { set     opts(-include_bels)    1}
			{-o(f(_(o(b(j(e(c(t(s)?)?)?)?)?)?)?)?)?$}                     { set     opts(-of_objects)      [lshift args]}
			{-p(r(i(m(i(t(i(v(e(_(g(r(o(u(p)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} { lappend opts(-primitive_group) [lshift args]}
            {-h(e(l(p)?)?)?$}                                             { set     opts(-help)            1}
            {-u(s(a(g(e)?)?)?)?$}                                         { set     opts(-help)            1}			
            default {
                return -code error "ERROR: \[write_loc_constraints\] Unknown option '[lindex $args 0]', please type 'write_loc_constraints -help' for usage info."
            }
        }
    }

	if {$opts(-help) == 1} {
		puts "write_loc_constraints"
		puts ""
		puts "Description:"
		puts "  Creates a constraints file with the specified design LOCs."
		puts ""
		puts "Syntax:"
		puts "  write_loc_constraints \[-file <arg>\] \[-force\] \[-of_objects <arg>\]"
		puts "                        \[-cell <arg>\] \[-all_placement\] \[-include_bels\]"
		puts "                        \[-primitive_group <arg>\] \[-help\]"
		puts ""
		puts "Usage:" 
        puts "  Name                Description"
        puts "  -------------------------------"
		puts "  \[-all_placement\]    Include non-fixed cell placement."
        puts "  \[-cell\]             Given cell hierarchy for processing."
        puts "                      Default: \[current_instance .\]"
		puts "  \[-file\]             Name of the output constraint file."
		puts "  \[-force\]            Overwrite existing file."
		puts "  \[-include_bels\]     Include BEL level placement constraints."
		puts "  \[-of_objects\]       List of objects of which to create LOC constraints."
		puts "  \[-primitive_group\]  Filter cells by the specified group."
        puts ""
		puts "Description:"
		puts ""
		puts "  Writes LOC constraints to a Xilinx Design Constraints file (XDC). The XDC"
		puts "  can be exported from the top-level, or from a specific hierarchical cell."
		puts ""
        puts "Example:"
		puts ""
        puts "  The following example creates an XDC file which contains the fixed placement"
        puts "  cells in the open design."
        puts ""
        puts "    write_loc_constraints -file fixed_only.xdc"
        puts ""
		puts "  The following example creates an XDC file which contains the all the placed"
        puts "  cells (fixed and non-fixed) in the open design for the specified primitive"
		puts "  groups BMEM (BlockRAMs) and MULT (DSPs)."
		puts ""
		puts "  NOTE: The primitive group is specific to the device architecture. For this"
		puts "        example, the primitive groups are intended for the 7 Series architecture."
        puts ""
        puts "    write_loc_constraints -file my_locs.xdc -all_placement -primitive_group BMEM \\"
		puts "      -primitive_group MULT"
        puts ""
		puts "  The following example creates an XDC file which contains the all the placement"
        puts "  information from the given cell list including the SLICE BEL locations."
        puts ""
        puts "    write_loc_constraints -file my_sub_locs.xdc -all_placement \\"
		puts "      -include_bels -of_objects \[get_cells my_sub/*\]"
		puts ""
        return
	}
	
	## Check to see if the file option is used, error if not as its required
	if {![info exists opts(-file)]} {
		return -code error "ERROR: \[write_loc_constraints\] Option -file required to create constraints file.  Please rerun with -file option."
	} else {
		## Check if file contains *.xdc extension, add if missing
		if {![regexp -nocase {.*\.xdc$} $opts(-file)]} {
			set fileName "$opts(-file).xdc"
		} else {
			set fileName $opts(-file)
		}
		
		## Check if filename exists and error if -force option is not used
		if {[file exists $fileName]} {
			if {![info exists opts(-force)]} {
				puts "ERROR: \[write_loc_constraints\] File $fileName exists.  Please rerun with -force option to overwrite the existing file."
				return -code error					
			} else {
				puts "INFO: \[write_loc_constraints\] Overwriting file $fileName as -force option is used."
			}
		}
	}
	
	## Get the current instance scope of the design as the script was executed
	set origCurrentInstanceCell [current_instance -quiet .]
	
	## Check if the -cell option was used, verify the option is correct
	if {[info exists opts(-cell)]} {
		## Get cell object from the -cell option
		set optionCellObj [get_cells -quiet $opts(-cell)]
		
		## Check if object exists
		if {[llength $optionCellObj]==0} {
			return -code error "ERROR: \[write_loc_constraints\] Unable to find cell object $opts(-cell) from -cell option."
		## Check if more than one object was returned
		} elseif {[llength $optionCellObj]>1} {
			return -code error "ERROR: \[write_loc_constraints\] Found more than 1 cell object ([join $optionCellObj ',']) from -cell option."
		} else {
			## Set the current instance to the top of the design
			current_instance -quiet
			## Set the current instance to the cell object set by the -cell option
			current_instance -quiet $optionCellObj
		}
	}		

	## Check to see if the of_objects option was used
	if {[info exists opts(-of_objects)]} {
		## Parse the object list to ensure that only cell objects exist
		set objectList [parse_object_list -objects $opts(-of_objects) -klasses {cell}]
		
		## Check if the the -primitive_group option was used
		if {[info exists opts(-primitive_group)]} {
			## Filter the object list based on the primitive group arguments
			set objectList [filter $objectList "PRIMITIVE_GROUP==[join $opts(-primitive_group) " || PRIMITIVE_GROUP=="]"]
		}
	} else {
		## Check if the the -primitive_group option was used
		if {[info exists opts(-primitive_group)]} {
			## Check if the -all_placement option was used
			if {[info exists opts(-all_placement)]} {
				## Get all the cells for the specified primitive group
				set objectList [get_cells -quiet -hier -filter "PRIMITIVE_LEVEL!=INTERNAL && PRIMITIVE_GROUP==[join $opts(-primitive_group) " || PRIMITIVE_GROUP=="]"]
			} else {
				## Get all the fixed placement cells for the specified primitive groups
				set objectList [get_cells -quiet -hier -filter "IS_LOC_FIXED && PRIMITIVE_LEVEL!=INTERNAL && PRIMITIVE_GROUP==[join $opts(-primitive_group) " || PRIMITIVE_GROUP=="]"]
			}
		} else {
			## Check if the -all_placement option was used
			if {[info exists opts(-all_placement)]} {
				## Get all the cells in the design
				set objectList [get_cells -quiet -hier -filter "IS_PRIMITIVE && PRIMITIVE_LEVEL!=INTERNAL"]
			} else {
				## Get all the fixed placement cells for the design
				set objectList [get_cells -quiet -hier -filter "IS_LOC_FIXED && IS_PRIMITIVE && PRIMITIVE_LEVEL!=INTERNAL"]
			}
		}
    }

	## Verify the object list contains at least one object
	if {[llength $objectList]==0} {
		puts "WARNING: \[write_loc_constraints\] No cells selected or found. No constraint file produced." 
		return;
	}
	
	## Report the total number of cell objects found
    puts "INFO: \[write_loc_constraints\] [llength $objectList] objects selected."

	## Initialize the constraint file list
	set constraintFileList [list]
	
	## Loop through each cell object
	foreach cellObj $objectList {
		## Get the LOC property of the cell and ensure it exists
		if {[get_property LOC $cellObj] ne ""} {
			## Check if a BEL property exists on the cell
			if {$opts(-include_bels) && ([get_property BEL $cellObj] ne "")} {
				## Parse the BEL property to determine the BEL location
				if {[regexp {^\s*SLICE\w\.(\S+)} [get_property BEL $cellObj] matchString belName]} {
					## Output the XDC constraints for the LOC and BEL values
					lappend constraintFileList  "set_property LOC [get_property LOC $cellObj] \[get_cells {$cellObj}\]"
					lappend constraintFileList  "set_property BEL $belName \[get_cells {$cellObj}\]"
				} else {
					## Unable to parse the BEL constraint, will just write the LOC.
					## Output the XDC constraints for the LOC value
                    lappend constraintFileList  "set_property LOC [get_property LOC $cellObj] \[get_cells {$cellObj}\]"
				}
			} else {
				## No BEL constraint exists
				## Output the XDC constraints for the LOC value
                lappend constraintFileList  "set_property LOC [get_property LOC $cellObj] \[get_cells {$cellObj}\]"
			}
		}
    }

	## open the filename for writing
	set fileHandle [open $fileName "w"]
	## send the data to the file
	puts $fileHandle [join $constraintFileList "\n"]
	## close the file, ensuring the data is written out before you continue with processing.
	close $fileHandle
	
	## Check if the -cell option was used to reset the current instance back to the previous state
	if {[info exists opts(-cell)]} {
		## Reset the current instance back to the scope prior to script execution
		current_instance -quiet	
		
		## Check if the original current instance value is non-empty
		if {[llength $origCurrentInstanceCell]!=0} {
			## Set the current instance based on the original current cell instance
			current_instance -quiet $origCurrentInstanceCell
		}
	}
	
	## Return the name of the output file
	return [file join [pwd] $fileName]
}

#######################################################################
# Name:  parse_object_list
# Usage: parse_object_list -klasses {cell pin} -objects [get_cells]
# Descr: Parses the object list to only return objects of the specified 
#        class type
#######################################################################
proc ::tclapp::xilinx::designutils::write_loc_constraints::parse_object_list {args} {
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

        puts "CRITICAL WARNING: \[write_loc_constraints\] list of objects specified contains $klassCount object(s) of types '([join $klassList ", "])' other than the types '([join $opts(-klasses) ", "])' supported by the constraint.\n"
    }

    ## Return the supported object list
    return $objectList
}

# #########################################################
# lshift
# #########################################################
proc ::tclapp::xilinx::designutils::write_loc_constraints::lshift {varname} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinxtclstore, designutils
	upvar $varname argv
	set r [lindex $argv 0]
	set argv [lrange $argv 1 end]
	return $r
}

