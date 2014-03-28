package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export write_slr_pblock_xdc
}

proc ::tclapp::xilinx::designutils::write_slr_pblock_xdc {args} {
	# Summary : Exports the current SLR placement to pblock constraints in an XDC file

	# Argument Usage:
	# -file <arg>: Output file name
	# [-cell <arg> = current_instance]: Root of the design to process the SLR placement. If not specified, runs on current_instance
	# [-force]: Overwrite existing file
	# [-pblock_prefix <arg> = auto_generated_slr_pblock_]: The name prefix given to each specific SLR pblock
	# [-usage]: Usage information

	# Return Value:
	# The name of the output file

	# Categories: xilinxtclstore, designutils

	return [uplevel ::tclapp::xilinx::designutils::write_slr_pblock_xdc::write_slr_pblock_xdc $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::write_slr_pblock_xdc {
} ]


proc ::tclapp::xilinx::designutils::write_slr_pblock_xdc::write_slr_pblock_xdc {args} {	
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
  
	## Set Default option values
	array set opts {-help 0 -pblock_prefix "auto_generated_slr_pblock_"}
	
	##
	set commandLine "write_slr_pblock_xdc $args"
	
	## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
		switch -regexp -- $optionName {
			{-c(e(l(l)?)?)?$}                                      { set opts(-cell)          [lshift args]}
            {-fi(l(e)?)?$}                                         { set opts(-file)          [lshift args]}
			{-fo(r(c(e)?)?)?$}                                     { set opts(-force)         1}
			{-p(b(l(o(c(k(_(p(r(e(f(i(x)?)?)?)?)?)?)?)?)?)?)?)?$}  { set opts(-pblock_prefix) [lshift args]}
            {-u(s(a(g(e)?)?)?)?$}                                  { set opts(-help)          1}
            default {
                return -code error "ERROR: \[write_slr_pblock_xdc\] Unknown option '[lindex $args 0]', please type 'write_slr_pblock_xdc -help' for usage info."
            }
        }
    }
	
	## Display help information
    if {$opts(-help) == 1} {
        puts "write_slr_pblock_xdc\n"
        puts "Description:"
        puts "  Exports the current SLR placement to pblock constraints"
        puts ""
        puts "Syntax:"
        puts "  write_slr_pblock_xdc \[-cell <arg>\] \[-file <arg>\] \[-force\]"
		puts "                       \[-pblock_prefix <arg>\] \[-help\]"  
        puts ""
        puts "Usage:"
        puts "  Name                Description"
        puts "  -------------------------------"
        puts "  \[-cell\]             Given cell hierarchy for processing."
        puts "                      Default: \[current_instance .\]"
		puts "  \[-file\]             Write the XDC into the specified file."
		puts "  \[-force\]            Overwrite the existing file on the filesystem."
        puts "  \[-pblock_prefix\]    The prefix of the name given to each specific SLR pblock"
        puts "                      Default: auto_generated_slr_pblock_"	
        puts ""
		puts "Description:"
		puts ""
		puts "  Writes XDC specific pblock constraints based on the current design placement"
		puts "  for each SLR.  The XDC file can be exported from the top-level or from a"
		puts "  specific hierarchical cell."
		puts ""
        puts "Example:"
		puts ""
        puts "  The following example creates an XDC file which contains SLR specific"
        puts "  pblock constraints for each of the cells under the current level of hierarchy."
        puts ""
        puts "  write_slr_pblock_xdc -file slr_pblock.xdc"
        puts ""
        return
    }
	
	## Check to see if the file option is used, error if not as its required
	if {![info exists opts(-file)]} {
		puts "ERROR: \[write_slr_pblock_xdc\] Option -file required to create XDC file.  Please rerun with -file option."
		return -code error
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
				puts "ERROR: \[write_slr_pblock_xdc\] File $fileName exists.  Please rerun with -force option to overwrite the existing file."
				return -code error					
			} else {
				puts "INFO: \[write_slr_pblock_xdc\] Overwriting file $fileName as -force option is used."
			}
		}
	}
	
	## Check if cell option was used, abd error if cell is not found
	if {[info exists opts(-cell)]} {
		## Get Cell object from cell option
		set cellObj [get_cells -quiet $opts(-cell)]
		
		## Check if cell object exits, error if not found
		if {[llength $cellObj]==0} {
			puts "ERROR: \[write_slr_pblock_xdc\] Unable to find cell $opts(-cell) for argument -cell."
			return -code error
		## If multiple cells found, error.
		} elseif {[llength $cellObj]>1} {
			puts "ERROR: \[write_slr_pblock_xdc\] Found [llength $cellObj] cells for -cell argument $cellObj. Please specify 1 cell object."
			return -code error
		## Since correctly finding one cell, set the cell to the current instance
		} else {
			puts "INFO: \[write_slr_pblock_xdc\] Setting current_instance to argument value $opts(-cell)."
			current_instance -quiet [get_cells $opts(-cell)]
		}
	}
	
	## Process the current level hierarchy for pblock SLR constraint extraction
	array set slrConstraintArray [process_slr_pblock_from_hierarchy -pblock_prefix $opts(-pblock_prefix)]
	
	## Create a variable with the file header information
	set    fileHeader "################################################################################################\n"
	append fileHeader "# File     :  $fileName\n"
	append fileHeader "# Project  :  [current_project]\n"
	append fileHeader "# Part     :  [get_property PART [current_project]]\n"
	append fileHeader "# Version  :  [lindex [split [version] \n] 0] [lindex [split [version] \n] 1]\n"
	append fileHeader "# Date     :  [clock format [clock seconds]]\n"
	append fileHeader "# Command  :  $commandLine\n"	
	append fileHeader "################################################################################################\n"
	
	## open the filename for writing
	set fileHandle [open $fileName "w"]
	## send the header to the file
	puts $fileHandle $fileHeader
	## send the data to the file
	foreach slrName [lsort [array names slrConstraintArray]] {
		## Get 
		set clockRegionList [get_clock_regions_from_slr -name $slrName -return_string]
	
		puts $fileHandle "create_pblock $opts(-pblock_prefix)$slrName"
		puts $fileHandle "resize_pblock $opts(-pblock_prefix)$slrName -add \[list [join $clockRegionList]\]"
		puts $fileHandle "[join [lsort $slrConstraintArray($slrName)] "\n"]\n"
	}
	
	## close the file, ensuring the data is written out before you continue with processing.
	close $fileHandle
	
	## Return the name of the output file
	return $fileName
}

# #########################################################
#  process_slr_pblock_from_hierarchy
# #########################################################
proc ::tclapp::xilinx::designutils::write_slr_pblock_xdc::process_slr_pblock_from_hierarchy {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0 -constraint_list {}}
	
	## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
		switch -regexp -- $optionName {
            {-c(o(n(s(t(r(a(i(n(t(_(l(i(s(t)?)?)?)?)?)?)?)?)?)?)?)?)?)?$} { set opts(-constraint_list) [lshift args]}
			{-p(b(l(o(c(k(_(p(r(e(f(i(x)?)?)?)?)?)?)?)?)?)?)?)?$}         { set opts(-pblock_prefix)   [lshift args]}
            {-h(e(l(p)?)?)?$}                                             { set opts(-help)            1}
            default {
                return -code error "ERROR: \[process_slr_pblock_from_hierarchy\] Unknown option '[lindex $args 0]', please type 'process_slr_pblock_from_hierarchy -help' for usage info."
            }
        }
    }
	
	## Initialize the Array to store Constraint information
	array set constraintArray $opts(-constraint_list)
	## Get all the non-primitive cells under the current instance hierarchy scope
	set childCellList [get_cells -quiet -filter {!IS_PRIMITIVE}]
	
	## Check if current hierarchy contains any child cells
	if {[llength $childCellList]==0} {
		## Get all the relative primitive cells under the current hierarchy scope
		set leafCellList [get_cells -quiet -hier -filter "IS_PRIMITIVE && PRIMITIVE_LEVEL!=MACRO && LIB_CELL!=VCC && LIB_CELL!=GND"]
		## Initialize the SLR Cell Array
		array set slrCellArray {}
		## Loop through each primitive cell list
		foreach leafCellObj $leafCellList {
			## Get the SLR of the specified primitive cell
			set slrObj [get_slrs -quiet -of_objects $leafCellObj]
			## Check if SLR propery exists
			if {$slrObj ne ""} {
				## Check if the cell is an INTERNAL primitive as only MACRO primitives can be added to pblock
				if {[get_property -quiet PRIMITIVE_LEVEL $leafCellObj] eq "INTERNAL"} {
					## Get the MACRO cell object from the PARENT property of the INTERNAL cell object
					set macroCellObj [get_cells -quiet [get_property PARENT $leafCellObj]]
					## Store the MACRO cell by its SLR location
					lappend slrCellArray($slrObj) $macroCellObj
				} else {
					## Store the primitive cell by its SLR location
					lappend slrCellArray($slrObj) $leafCellObj
				}
			} else {
				puts "WARNING: \[process_slr_pblock_from_hierarchy\] Unable to process [get_property REF_NAME $leafCellObj] cell $leafCellObj.  Cell doesn't contain SLR information."
			}
		}
		
		## Loop through each SLR location of the array
		foreach slrName [array names slrCellArray] {
			## Sort and uniquify the list of cells for the specified SLR
			set slrCellList [lsort -uniq $slrCellArray($slrName)]
			
			## Store the XDC pblock constraint equivalent for the list of cells
			lappend constraintArray($slrName) "add_cells_to_pblock $opts(-pblock_prefix)$slrName \[get_cells \[list $slrCellList\]\]; # [llength $slrCellList] cell count"
		}
		
		## Unset the SLR Cell Array
		array unset slrCellArray
		
	} else {
		## Loop through each child cell of the current hierarchy
		foreach childCellObj $childCellList {
			## Reset the current instance to the top-level design
			current_instance -quiet
			## Move the current instance to the current child cell
			current_instance -quiet $childCellObj
			## Get hierarchical cell list of current child cell instance level
			set currentCellList [get_cells -quiet -hier]
			## Get the SLR list of all the hierarchical cells under the current child hierarchy level
			set slrList [get_slrs -quiet -of_objects $currentCellList]
			
			## Check to see if the cells are contained in a single SLR  
			if {[llength $slrList]==1} {
				## Store the XDC pblock constraint equivalent for the current child cell
				lappend constraintArray($slrList) "add_cells_to_pblock $opts(-pblock_prefix)$slrList \[get_cells $childCellObj\]; # [llength $currentCellList] cell count"
			} else {
				## Process the current child level hierarchy for pblock SLR constraint extraction
				array set constraintArray [process_slr_pblock_from_hierarchy -constraint_list [array get constraintArray] -pblock_prefix $opts(-pblock_prefix)]
			}
		}
	}
	
	## Reset the current instance to the top-level design
	current_instance -quiet
	## Return the constraint Array
	return [array get constraintArray]
}

# #########################################################
#  get_clock_regions_from_slr
# #########################################################
proc ::tclapp::xilinx::designutils::write_slr_pblock_xdc::get_clock_regions_from_slr {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 

    # Categories: xilinctclstore, designutils
	
	## Set Default option values
	array set opts {-help 0 -return_strings 0}
	
	## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
		switch -regexp -- $optionName {
            {-n(a(m(e)?)?)?$}                                         { set opts(-name)           [lshift args]}
			{-r(e(t(u(r(n(_(s(t(r(i(n(g(s)?)?)?)?)?)?)?)?)?)?)?)?)?$} { set opts(-return_strings) 1} 
            {-h(e(l(p)?)?)?$}                                         { set opts(-help)           1}
            default {
                return -code error "ERROR: \[get_clock_regions_from_slr\] Unknown option '[lindex $args 0]', please type 'get_clock_regions_from_slr -help' for usage info."
            }
        }
    }
	
	## Display help information
    if {$opts(-help) == 1} {
		return
	}
	
	## Get the SLR object
	set slrObj [get_slrs -quiet $opts(-name)]
	## Get the clock region objects from the SLR object
	set regionList [get_clock_regions -quiet -of_objects $slrObj]
	
	## Check if the return strings option is selected
	if {$opts(-return_strings)} {
		## Convert the clock region objects to CLOCKREGION strings
		foreach regionName $regionList {
			lappend clockRegionList "CLOCKREGION_$regionName"
		}
	} else {
		## Set the clock region objects to the list
		set clockRegionList $regionList
	}
	
	## Return the list of clock region objects/strings
	return $clockRegionList
}

# #########################################################
# lshift
# #########################################################
proc ::tclapp::xilinx::designutils::write_slr_pblock_xdc::lshift {varname} {
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
