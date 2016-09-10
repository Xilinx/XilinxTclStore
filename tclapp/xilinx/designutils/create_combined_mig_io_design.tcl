package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::designutils {
    namespace export create_combined_mig_io_design
}

proc ::tclapp::xilinx::designutils::create_combined_mig_io_design {args} {
	# Summary : Creates a new project instantiating the given MIG IP into a single design for IO pin planning

	# Argument Usage:
	# [-force]: Overwrite existing project
    # [-project_name <arg> = combined_mig_io_design]: Name of the combined MIG IP project
	# [-out_dir <arg>]: Output directory of the combined MIG IP project
	# objects: MIG IP objects to be combined into a project
	# [-usage]: Usage information

	# Return Value:
    # 0 if success, TCL_ERROR if failed  
	
	# Categories: xilinxtclstore, designutils

	return [uplevel ::tclapp::xilinx::designutils::create_combined_mig_io_design::create_combined_mig_io_design $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::xilinx::designutils::create_combined_mig_io_design {
} ]

#######################################################################
# Name: create_combined_mig_io_design
# Usage: create_combined_mig_io_design -project_name my_example_design [get_ips mig_0] 
# Descr: Creates a new project instantiating the given IP into a single 
#        design for IO pin planning.
#######################################################################
proc ::tclapp::xilinx::designutils::create_combined_mig_io_design::create_combined_mig_io_design {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 
	
	## Set Default option values
	array set opts {-help 0 -project_name combined_mig_design}
	
	## Set the command line used
	set commandLine "create_combined_mig_io_design $args"
	
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
		switch -regexp -- $optionName {
			{-f(o(r(c(e)?)?)?)?$}                             { set opts(-force)        1}
			{-p(r(o(j(e(c(t(_(n(a(m(e)?)?)?)?)?)?)?)?)?)?)?$} { set opts(-project_name) [lshift args]}
			{-o(u(t(_(d(i(r)?)?)?)?)?)?$}                     { set opts(-out_dir)      [lshift args]}
            {-h(e(l(p)?)?)?$}                                 { set opts(-help)         1}
            {-u(s(a(g(e)?)?)?)?$}                             { set opts(-help)         1}			
            default {
                return -code error "ERROR: \[create_combined_mig_io_design\] Unknown option '[lindex $args 0]', please type 'create_combined_mig_io_design -help' for usage info."
            }
        }
    }

	## Display help information
    if {$opts(-help) == 1} {
        puts "create_combined_mig_io_design\n"
        puts "Description:"
        puts "  Creates a new project instantiating the given MIG IP into a single design"
        puts "  for IO pin planning."
        puts ""
        puts "Syntax:"
        puts "  create_combined_mig_io_design \[-force\] \[-project_name <arg>\]"
		puts "                                \[-out_dir <arg>\] \[-help\] <objects>"
        puts ""
        puts "Usage:"
        puts "  Name                Description"
        puts "  -------------------------------"
		puts "  \[-force\]            Overwrite existing project"
		puts "  \[-out_dir\]          Name of the combined MIG IP project"
		puts "  \[-project_name\]     Output directory of the combined MIG IP project"
		puts "  <objects>           Objects to be combined into a project"
        puts ""
        puts "Example:"
        puts "  The following example will create a new project called my_example_design"
		puts "  with two instances of the mig_0 IP and one instance of mig_1."
        puts ""
        puts "  create_combined_mig_io_design -project_name my_example_design \[get_ips mig_0 mig_0 mig_1\]"
        puts ""
        return
    }

	## Check if an IP list was given
	if {[llength $args]==0} {
		return -code error "ERROR: \[create_combined_mig_io_design\] Missing value 'objects', please type 'create_combined_mig_io_design -help' for usage info."
	} else {
		## Parse Object List Classes
		set objectList [parse_object_list -objects [get_ips [concat {*}$args]] -klasses {ip}]
	}	

	## Check if the output directory option is set
	if {![info exists opts(-out_dir)]} {
		## Set the output directory to the level above the current project
		set opts(-out_dir) [file normalize [get_property -quiet DIRECTORY [current_project -quiet]]/..]
	}
	## Check if the project directory already exists on disk
	if {[file exists [file normalize $opts(-out_dir)/$opts(-project_name)]]} {
		## Check if the -force option was used
		if {![info exists opts(-force)]} {
			return -code error "ERROR: \[create_combined_mig_io_design\] Project $opts(-project_name) exists. Please rerun with -force option to overwrite the existing project."				
		} else {
			puts "INFO: \[create_combined_mig_io_design\] Overwriting project $opts(-project_name) as -force option is used."
		}	
	}

	## Check if object list has at least one object
	if {[llength $objectList]==0} {
		return -code error "ERROR: \[create_combined_mig_io_design\] No IP Objects found"
	}
	
	## Get the target language of the project to determine how to search for the IP instantiation templates
	set targetLanguageString [get_property -quiet TARGET_LANGUAGE [current_project -quiet]]
	
	## Create the dictionary for storing the IP
	set ipDict [dict create]
	
	## Loop through each IP object in the object list
	foreach ipObj $objectList {
		## Check the target language value to determine how to search for the instantiation template files 
		if {$targetLanguageString eq "VHDL"} {
			set fileSearchString "*.vho"
			return -code error "ERROR: \[create_combined_mig_io_design\] Target Language $targetLanguageString is not supported."
		} else {
			set fileSearchString "*.veo"
		}
		
		## Check if the instantiation template was generated
		if {[lsearch [get_property DELIVERED_TARGETS $ipObj] "instantiation_template"]==-1 || [lsearch [get_property STALE_TARGETS $ipObj] "instantiation_template"]>=0} {
			## Check if the IP can generate since teh instantiation template target is missing or stale
			if {[get_property -quiet CAN_IP_GENERATE $ipObj]==0} {
				return -code error "ERROR: \[create_combined_mig_io_design\] Unable to generate instantiation template for IP $ipObj. Please run report_ip_status for more information."
			} else {
				puts "INFO: \[create_combined_mig_io_design\] Generating Instantiation Template for IP $ipObj."
				## Generate the instantiation template
				generate_target {instantiation_template} $ipObj
			}
		}
		
		## Get the instantiation template file object
		set templateFileObj [get_files -quiet -of_objects $ipObj -filter "NAME=~$fileSearchString"]
		
		## Parse the IP instance instantiation template
		set ipCellDict [parse_design_instantiation_template $templateFileObj $targetLanguageString]
		
		## Check if the IP instance already exists in the IP cell dictionary
		while {[dict exists $ipDict [dict get $ipCellDict name]]} {
			## Get the index value of the instance name to increment the value
			if {[regexp {(\S+)(\d+)$} [dict get $ipCellDict name] matchString instanceName instanceIndex]} {
				## Increment the instance name index number
				incr instanceIndex
				## Set the name of the IP instance dictionary
				dict set ipCellDict name $instanceName$instanceIndex
			} else {
				return -code error "ERROR: \[create_combined_mig_io_design\] Unable to parse instance name [dict get $ipCellDict name]."
			}
			
		}
			
		## Add the IP cell dictionary to the cell dictionary
		dict set ipDict [dict get $ipCellDict name] cell $ipCellDict
		dict set ipDict [dict get $ipCellDict name] xci [get_property -quiet IP_FILE $ipObj]
	}
	
	## Create the example Tcl project creation script
	create_project_from_mig_ip_cell_dictionary -ip_dict $ipDict -top "top" -project_name $opts(-project_name) -out_dir $opts(-out_dir)
	
	return 0
}

#######################################################################
# Name:  
# Usage: 
# Descr: 
#        
#######################################################################
proc ::tclapp::xilinx::designutils::create_combined_mig_io_design::create_project_from_mig_ip_cell_dictionary {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 
	
	## Set Default option values
	array set opts {-help 0 -force 0 -project_name my_example_design}
	
	## Set the command line used
	set commandLine "create_project_from_ip_cell_dictionary $args"
	
    ## Parse arguments from option command line
	while {[string match -* [lindex $args 0]]} {
		## Set the name of the first level option
        set optionName [lshift args]
		## Check for the option name in the regular expression
		switch -regexp -- $optionName {
			{-i(p(_(d(i(c(t)?)?)?)?)?)?$}                     { set opts(-ip_dict)      [lshift args]}
			{-o(u(t(_(d(i(r)?)?)?)?)?)?$}                     { set opts(-out_dir)      [lshift args]}
			{-p(r(o(j(e(c(t(_(n(a(m(e)?)?)?)?)?)?)?)?)?)?)?$} { set opts(-project_name) [lshift args]}
			{-t(o(p)?)?$}                                     { set opts(-top)          [lshift args]} 
            {-h(e(l(p)?)?)?$}                                 { set opts(-help)         1}
            {-u(s(a(g(e)?)?)?)?$}                             { set opts(-help)         1}			
            default {
                return -code error "ERROR: \[create_combined_mig_io_design\] Unknown option '[lindex $args 0]', please type 'create_combined_mig_io_design -help' for usage info."
            }
        }
    }
	
	## Set the directory for the new project
	set newProjectDirectory [file normalize $opts(-out_dir)/$opts(-project_name)]
	## Set the part for the new project
	set newProjectPart [get_property -quiet PART [current_project -quiet]]
	
	## Get the properties of the current project
	set simLanguage     [get_property -quiet SIMULATOR_LANGUAGE [current_project -quiet]]
	set targetLanguage  [get_property -quiet TARGET_LANGUAGE [current_project -quiet]]
	set targetSimulator [get_property -quiet TARGET_SIMULATOR [current_project -quiet]]
	set ipRepoPathList  [get_property -quiet IP_REPO_PATHS [current_project -quiet]]
	set boardPart       [get_property -quiet BOARD_PART [current_project -quiet]]
		
	## Create the new project for the combined IP design.  REturn error if create_project fails
	if {[catch {create_project -part $newProjectPart -force $opts(-project_name) $newProjectDirectory} catchErrorString]} {
		puts "ERROR: \[create_combined_mig_io_design\] Unable to create new combined MIG project"
		error [string trimright $catchErrorString]
	}
	
	## Set the current_project to the new project
	current_project -quiet $opts(-project_name)

	## Set the properties of the new project
	set_property SIMULATOR_LANGUAGE $simLanguage [current_project -quiet $opts(-project_name)]
	set_property TARGET_LANGUAGE $targetLanguage [current_project -quiet $opts(-project_name)]
	set_property TARGET_SIMULATOR $targetSimulator [current_project -quiet $opts(-project_name)]
	
	## Set the IP repositories set if used
	if {[llength $ipRepoPathList]>0} {
		set_property IP_REPO_PATHS $ipRepoPathList [current_project -quiet $opts(-project_name)]
	}
	
	## Set the Board part if it's used
	if {[llength $boardPart]>0} {
		set_property BOARD_PART $boardPart [current_project -quiet $opts(-project_name)]
	}
	
	## Create the sources directory for the new file top-level file
	file mkdir $newProjectDirectory/$opts(-project_name)/$opts(-project_name).srcs/sources_1/new
	## Create the empty top-level file in the sources location
	close [open $newProjectDirectory/$opts(-project_name)/$opts(-project_name).srcs/sources_1/new/$opts(-top).v w]
	## Add the file to the created project
	add_files $newProjectDirectory/$opts(-project_name)/$opts(-project_name).srcs/sources_1/new/$opts(-top).v
	
	## Create a Header for the new Verilog File
	set    verilogHeaderString "////////////////////////////////////////////////////////////////////////////////////////////////\n"
	append verilogHeaderString "// File     :  $opts(-top).v\n"
	append verilogHeaderString "// Version  :  [lindex [split [version] \n] 0] [lindex [split [version] \n] 1]\n"
	append verilogHeaderString "// Date     :  [clock format [clock seconds]]\n"
	append verilogHeaderString "////////////////////////////////////////////////////////////////////////////////////////////////\n"

	## Initialize the Verilog Module variable with the first line of the module definition
	set verilogModuleString "module $opts(-top) (\n";
	
	## Initialize XCI file list variable
	set xciFileList ""
	
	## Loop through each IP in the cell dictionary
	foreach ipDictID [dict keys $opts(-ip_dict)] {
		## Add the XCI file to the file list
		lappend xciFileList [dict get $opts(-ip_dict) $ipDictID xci]
		
		## Initialize the Verilog Instance variable with the first line of the instance
		set verilogInstanceString "[dict get $opts(-ip_dict) $ipDictID cell ref_name] [dict get $opts(-ip_dict) $ipDictID cell name] (\n"
		
		## Loop through each Module Port of the Dictionary
		foreach modulePortDictID [lsort [dict keys [dict get $opts(-ip_dict) $ipDictID cell ports]]] {
			## Set the dictionary of the specific port from the Module Port Dictionary
			set portDict [dict get $opts(-ip_dict) $ipDictID cell ports $modulePortDictID]

			## Check if the port name is named "_app_" or "_user_" or "dbg_" (specific for MIG Ultrascale)
			if {[regexp {_app_} [dict get $portDict name]] || [regexp {_user_} [dict get $portDict name]] || [regexp {dbg_} [dict get $portDict name]]} {
				## Check if the port direction is output (case insensitive check)
				if {[string tolower [dict get $portDict direction]] eq "output"} {
					## Append the module port to the instantiation template
					append verilogInstanceString "\t.[dict get $portDict name]\(\),\n"
				} else {
					## Check if the Port is of type Vector
					if {[dict get $portDict bus_type] eq "vector"} {
						## Append the vector Verilog 2001 syntax for the module port, prefix the port name with the name of the IP dictionary ID
						append verilogInstanceString "\t.[dict get $portDict name]\([expr abs([dict get $portDict bus_start]-[dict get $portDict bus_end])+1]'b0\),\n"
					## Else the Port is of type Scalar
					} else {
						## Append the module port to the instantiation template
						append verilogInstanceString "\t.[dict get $portDict name]\(1'b0\),\n"
					}
				}
			} else {
				## Append the module port to the instantiation template
				append verilogInstanceString "\t.[dict get $portDict name]\($ipDictID\_[dict get $portDict name]\),\n"
					
				## Check if the Port is of type Vector
				if {[dict get $portDict bus_type] eq "vector"} {
					## Append the vector Verilog 2001 syntax for the module port, prefix the port name with the name of the IP dictionary ID
					append verilogModuleString "\t[dict get $portDict direction] \[[dict get $portDict bus_start]:[dict get $portDict bus_end]\] $ipDictID\_[dict get $portDict name],\n"
				## Else the Port is of type Scalar
				} else {
					## Append the scalar Verilog 2001 syntax for the module port, prefix the port name with the name of the IP dictionary ID
					append verilogModuleString "\t[dict get $portDict direction] $ipDictID\_[dict get $portDict name],\n"		
				}
			}
		}
		
		## Remove the final comma since the last cell property has been processed
		set verilogInstanceString [string range $verilogInstanceString 0 end-2]
		## Append the end of the instance declaration.
		append verilogInstanceString "\n);\n"
		
		## Append the instance to the Verilog instantiation list
		lappend instantiationTemplateList $verilogInstanceString
	}

	## Remove the final comma since the last cell property has been processed
    set verilogModuleString [string range $verilogModuleString 0 end-2]	

	## Append the end of the module port declaration.
	append verilogModuleString "\n);\n"
	## Append some line breaks for code readability
	append verilogModuleString "\n\n"
	## Append each line of the instantiation template from the VEO file
	append verilogModuleString "[join $instantiationTemplateList \n]"
	## Append some line breaks for code readability
	append verilogModuleString "\n\n"

	## Append the endmodule statement
	append verilogModuleString "endmodule\n";
	
	## Add the IP (XCI files) to the created project by reference
	import_files [lsort -uniq $xciFileList]
	
	## Open the empty top-level file for writing
	set fileId [open $newProjectDirectory/$opts(-project_name)/$opts(-project_name).srcs/sources_1/new/$opts(-top).v "w"]
	## Write the header to the output file
	puts $fileId $verilogHeaderString
	## Write the entire Verilog module to the output file
	puts -nonewline $fileId $verilogModuleString
	## Close the file handle
	close $fileId
}

#######################################################################
# Name: parse_design_instantiation_template
# Usage: parse_design_instantiation_template $fileObj "Verilog"
# Descr: 
#        
#######################################################################
proc ::tclapp::xilinx::designutils::create_combined_mig_io_design::parse_design_instantiation_template {fileObj targetLanguageString} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 
	
	## Get the file size of the object
	set fileSize [file size $fileObj]
	## Open the instantiation template file for reading
	set fileChannelID [open $fileObj r]
	## Read the file data from the channel
	set fileData [read $fileChannelID $fileSize]
	## Close the file channel for the instantiation template
	close $fileChannelID
		
	## Create the dictionary for storing the design instance cell
	set cellDict [dict create]
	## Create the Dictionary for storing each port of the instantiation template for the module declaration
	set modulePortDict [dict create]
	
	## Check if the target language is Verilog
	if {$targetLanguageString eq "Verilog"} {
		## Loop through each line of the file data of the Verilog Instantiation template
		foreach dataLine [split $fileData "\n"] {
			## Parse the connect of the instantiation template to search for the instance declaration
			if {[regexp {^\s*(\w+)\s+(\w+)\s*\(} $dataLine matchString moduleName instanceName]} {
				## Add the information related to the cell instance
				dict set cellDict ref_name $moduleName
				dict set cellDict name $moduleName\_inst0
			## Parse the comment of the instantiation template to search for the vector port type of the IP instance 
			} elseif {[regexp {\s+(input|output|inout)\s+(wire)?\s*\[\s*(\d+)\s*:\s*(\d+)\]\s+(\w+)\s*$} $dataLine matchString portDirection wireDeclaration busStart busEnd portName]} {
				## Add the port to the module port dictionary
				dict set modulePortDict $portName type "port"
				dict set modulePortDict $portName bus_type "vector"
				dict set modulePortDict $portName bus_start $busStart
				dict set modulePortDict $portName bus_end $busEnd
				dict set modulePortDict $portName direction $portDirection
				dict set modulePortDict $portName name $portName
			## Parse the comment of the instantiation template to search for the scalar port type of the IP instance 
			} elseif {[regexp {\s+(input|output|inout)\s+(wire)?\s*(\w+)\s*$} $dataLine matchString portDirection wireDeclaration portName]} {
				## Add the port to the module port dictionary
				dict set modulePortDict $portName type "port"
				dict set modulePortDict $portName bus_type "scalar"			
				dict set modulePortDict $portName direction $portDirection
				dict set modulePortDict $portName name $portName
			}
		}
	}
	
	## Add the ports dictionary to the cell dictionary
	dict set cellDict ports $modulePortDict
	
	## Return the Cell Dictionary
	return $cellDict
}

#######################################################################
# Name:  
# Usage: 
# Descr: 
#        
#######################################################################
proc ::tclapp::xilinx::designutils::create_combined_mig_io_design::lshift {varname} {
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


#######################################################################
# Name:  
# Usage: 
# Descr: 
#        
#######################################################################
proc ::tclapp::xilinx::designutils::create_combined_mig_io_design::parse_object_list {args} {
    # Summary :

    # Argument Usage:

    # Return Value:
    # 
	
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

    ## Check if the klass Array exists
    if {[array exists klassArray]} {
        ## Get all found unsupported klass names
        set klassList [array names klassArray]
		
		## Loop through each klass array name and increment the count
        foreach klassName [array names klassArray] {
            incr klassCount $klassArray($klassName)
        }

        puts "CRITICAL WARNING: \[parse_object_list\] list of objects specified contains $klassCount object(s) of types '([join $klassList ", "])' other than the types '([join $opts(-klasses) ", "])' supported by the constraint.\n"
    }

    ## Return the supported object list
    return $objectList
}
