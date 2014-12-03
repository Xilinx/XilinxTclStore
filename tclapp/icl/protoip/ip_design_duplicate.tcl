
########################################################################################
## 20/11/2014 - First release 1.0
########################################################################################

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_design_duplicate
}


proc ::tclapp::icl::protoip::ip_design_duplicate {args} {

	  # Summary: Duplicate a project in [WORKING DIRECTORY]

	  # Argument Usage:
	  # -from <arg>: Original project name to copy
	  # -to <arg>: New project name
	  # [-usage]: Usage information

	  # Return Value:
	  # Duplicated project. If any error(s) occur TCL_ERROR is returned.

	  # Categories: 
	  # xilinxtclstore, protoip
	  
	 uplevel [concat ::tclapp::icl::protoip::ip_design_duplicate::ip_design_duplicate $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::icl::protoip::ip_design_duplicate::ip_design_duplicate {
  variable version {20/11/2014}
} ]	  

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G R A M                              # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::icl::protoip::ip_design_duplicate::ip_design_duplicate { args } {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories: xilinxtclstore, ultrafast


	proc lshift {inputlist} {
      # Summary :
      # Argument Usage:
      # Return Value:
    
      upvar $inputlist argv
      set arg  [lindex $argv 0]
      set argv [lrange $argv 1 end]
      return $arg
    }  
	  
    #-------------------------------------------------------
    # read command line arguments
    #-------------------------------------------------------
    set error 0
    set help 0
    set project_name_oiginal {}
    set project_name_new {}

    set returnString 0
    while {[llength $args]} {
      set name [lshift args]
      switch -regexp -- $name {
		-from -
        {^-f(r(om?)?)?$} {
             set project_name_oiginal [lshift args]
             if {$project_name_oiginal == {}} {
				puts " -E- NO orinal project name specified."
				incr error
             } 
	     }
		-to -
        {^-to$} {
             set project_name_new [lshift args]
             if {$project_name_new == {}} {
				puts " -E- NO new project name specified."
				incr error
             } 
	     }
       -usage -
		  {^-u(s(a(ge?)?)?)?$} -
		  -help -
		  {^-h(e(lp?)?)?$} {
			   set help 1
		  }
		  ^--version$ {
			   variable version
			   return $version
		  }
        default {
              if {[string match "-*" $name]} {
                puts " -E- option '$name' is not a valid option. Use the -usage option for more details"
                incr error
              } else {
                puts " -E- option '$name' is not a valid option. Use the -usage option for more details"
                incr error
              }
        }
      }
    }
    
 if {$help} {
      puts [format {
 Usage: ip_design_duplicate
  -from <arg>:  - Original project name to copy
                  It's a mandatory field
  -to <arg>:    - New project name
                  It's a mandatory field
  [-usage|-u]:  - This help message

 Description: Make a copy of a project in [WORKING DIRECTORY]

 Example:
  ip_design_duplicate -from project_name_original -to project_name_new


	} ]
      # HELP -->
      return {}
    }
   

if {$error==0} {  

	if {$project_name_oiginal == {}} {

			error " -E- NO original project name to copy specified. Use the -usage option for more details."
			
		} else {
		
	if {$project_name_new == {}} {

			error " -E- NO new project name specified. Use the -usage option for more details."
			
		} else {	
	
		set  file_name_from ""
		append file_name_from ".metadata/" $project_name_oiginal "_configuration_parameters.dat"
		set  file_name_to ""
		append file_name_to ".metadata/" $project_name_new "_configuration_parameters.dat"
		
		if {[file exists $file_name_from]==0} {

			set tmp_error ""
			append tmp_error "-E- " $project_name_oiginal " does NOT exist. Use the -usage option for more details."
			error $tmp_error


		} else {
			if {[file exists $file_name_to]==1} {

				set tmp_error ""
				append tmp_error "-E- project " $project_name_new " already exists. Provide an new project name. Use the -usage option for more details."
				error $tmp_error


			} else {
				file mkdir ip_design/test/stimuli/$project_name_new
				file mkdir ip_design/test/results/$project_name_new
				#configuration_parameters
				file copy -force $file_name_from $file_name_to
				[::tclapp::icl::protoip::make_template::make_ip_configuration_parameters_readme_txt $project_name_new]
				#directives
				set  file_name_from ""
				append file_name_from "ip_design/src/" $project_name_oiginal "_directives.tcl"
				set  file_name_to ""
				append file_name_to "ip_design/src/" $project_name_new "_directives.tcl"
				file copy -force $file_name_from $file_name_to
				#ip_design_build
				set  file_name_from ""
				append file_name_from ".metadata/" $project_name_oiginal "_ip_design_build.tcl"
				set  file_name_to ""
				append file_name_to ".metadata/" $project_name_new "_ip_design_build.tcl"
				file copy -force $file_name_from $file_name_to
				# UPDATE ip_design_build project_name
				set file_read $file_name_to
				set file_write $file_name_to
				set insert_key "# Project name"
				set new_lines ""
				set tmp_line ""
				append tmp_line "set project_name \"$project_name_new\""
				lappend new_lines $tmp_line
				[::tclapp::icl::protoip::ip_design_duplicate::addlines $file_read $file_write $insert_key $new_lines]
				#ip_design_test
				set  file_name_from ""
				append file_name_from ".metadata/" $project_name_oiginal "_ip_design_test.tcl"
				set  file_name_to ""
				append file_name_to ".metadata/" $project_name_new "_ip_design_test.tcl"
				file copy -force $file_name_from $file_name_to
				# UPDATE ip_design_test project_name
				set  file_name_to ""
				append file_name_to ".metadata/" $project_name_new "_ip_design_test.tcl"
				set file_read $file_name_to
				set file_write $file_name_to
				set insert_key "# Project name"
				set new_lines ""
				set tmp_line ""
				append tmp_line "set project_name \"$project_name_new\""
				lappend new_lines $tmp_line
				[::tclapp::icl::protoip::ip_design_duplicate::addlines $file_read $file_write $insert_key $new_lines]
				
			}
		}
	
	 } 
	 }
}
	
	


    if {$error} {
		puts ""
		return -code error
	} else {
		set tmp_line ""
		append tmp_line "Project " $project_name_oiginal " succesfully duplicated as " $project_name_new
		puts $tmp_line
		puts ""
		return -code ok
	}

    
}


#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                    IP DESIGN DUPLICATE PROCEDURES                            # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::icl::protoip::ip_design_duplicate::addlines {file_read file_write insert_key new_lines} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:
  
	#Read lines of file echo_original.c into variable “lines”
	set f [open $file_read "r"]
	set lines [split [read $f] "\n"]
	close $f

	#Find the insertion index in the reversed list
	set idx [lsearch -regexp [lreverse $lines] $insert_key]
	if {$idx < 0} {
		error "did not find insertion point in $file_read"
	}

	#Insert the lines (I'm assuming they're listed in the variable “linesToInsert”)
	set lines [lreplace $lines end-[expr $idx-1] end-[expr $idx-1] {*}$new_lines]

	#Write the lines back to the file
	set f [open $file_write "w"]
	puts $f [join $lines "\n"]
	close $f
	
	return -code ok
}





