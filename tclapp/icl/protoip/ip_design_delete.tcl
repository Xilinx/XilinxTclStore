
########################################################################################
## 20/11/2014 - First release 1.0
########################################################################################

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_design_build_debug
}



namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_design_delete
}


proc ::tclapp::icl::protoip::ip_design_delete {args} {

	  # Summary: Delete a project from [WORKING DIRECTORY]

	  # Argument Usage:
	  # -project_name <arg>: Project name to delete
	  # [-usage]: Usage information

	  # Return Value:
	  # If any error(s) occur TCL_ERROR is returned.

	  # Categories: 
	  # xilinxtclstore, protoip
	  
 uplevel [concat ::tclapp::icl::protoip::ip_design_delete::ip_design_delete $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::icl::protoip::ip_design_delete::ip_design_delete {
  variable version {20/11/2014}
} ]	  

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G R A M                              # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::icl::protoip::ip_design_delete::ip_design_delete { args } {
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
    set project_name {}

    set returnString 0
    while {[llength $args]} {
      set name [lshift args]
      switch -regexp -- $name {
		 -project_name -
        {^-p(r(o(j(e(c(t(_(n(a(me?)?)?)?)?)?)?)?)?)?)?$} {
             set project_name [lshift args]
             if {$project_name == {}} {
				puts " -E- NO project name specified."
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
 Usage: ip_design_delete
  -project_name <arg> - Project name
                        It's a mandatory field
 [-usage|-u]:         - This help message

 Description: 
  Delete a project from [WORKING DIRECTORY]

 Example:
  ip_design_delete -project_name my_project0


	} ]
      # HELP -->
      return {}
    }

if {$error} {
    error " -E- some error(s) happened. Cannot continue. Use the -usage option for more details"
  }	

if {$error==0} {  

	set  file_name ""
	append file_name ".metadata/" $project_name "_configuration_parameters.dat"
	
	if {$project_name == {}} {

			error " -E- NO project name specified. Use the -usage option for more details."
			
		} else {

		if {[file exists $file_name] == 0} { 

			set tmp_error ""
			append tmp_error "-E- " $project_name " does NOT exist. Use the -usage option for more details."
			error $tmp_error
			
		} else {


			#load configuration parameters
			set  file_name ""
			append file_name ".metadata/" $project_name "_configuration_parameters.dat"
			set fp [open $file_name r]
			set file_data [read $fp]
			close $fp
			set data [split $file_data "\n"]

			set num_input_vectors [lindex $data 3]
			set num_output_vectors [lindex $data [expr ($num_input_vectors * 5) + 4 + 1]]
			set input_vectors {}
			set input_vectors_length {}
			set input_vectors_type {}
			set input_vectors_integer_length {}
			set input_vectors_fraction_length {}
			set output_vectors {}
			set output_vectors_length {}
			set output_vectors_type {}
			set output_vectors_integer_length {}
			set output_vectors_fraction_length {}

			for {set i 0} {$i < $num_input_vectors} {incr i} {
				lappend input_vectors [lindex $data [expr 4 + ($i * 5)]]
				lappend input_vectors_length [lindex $data [expr 5 + ($i * 5)]]
				lappend input_vectors_type [lindex $data [expr 6 + ($i * 5)]]
				lappend input_vectors_integer_length [lindex $data [expr 7 + ($i * 5)]]
				lappend input_vectors_fraction_length [lindex $data [expr 8 + ($i * 5)]]
			}
			for {set i 0} {$i < $num_output_vectors} {incr i} {
				lappend output_vectors [lindex $data [expr ($num_input_vectors * 5) + 4 + 2 + ($i * 5)]]
				lappend output_vectors_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 3 + ($i * 5)]]
				lappend output_vectors_type [lindex $data [expr ($num_input_vectors * 5) + 4 + 4 + ($i * 5)]]
				lappend output_vectors_integer_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 5 + ($i * 5)]]
				lappend output_vectors_fraction_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 6 + ($i * 5)]]
			}

			set fclk [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 2]] 
			set FPGA_name [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 4]] 
			set board_name [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 6]] 
			set old_type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
			set old_mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
			set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
			set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 
			set type_template [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 16]] 
			set type_design_flow [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 18]] 
				
				

			set filename ""
			append filename "doc/" $project_name
			file delete -force $filename
			set filename ""
			append filename "ip_design/build/prj/" $project_name
			file delete -force $filename
			set filename ""
			append filename "ip_design/src/" $project_name "_directives.tcl"
			file delete -force $filename
			append filename "ip_design/test/prj/" $project_name
			file delete -force $filename
			set filename ""
			append filename "ip_design/test/stimuli/" $project_name
			file delete -force $filename
			set filename ""
			append filename "ip_design/test/results/" $project_name
			file delete -force $filename
			set filename ""
			append filename "ip_prototype/build/prj/" $project_name "." $board_name
			file delete -force $filename
			set filename ""
			append filename "ip_prototype/test/prj/" $project_name "." $board_name
			file delete -force $filename
			set filename ""
			append filename "ip_prototype/test/results/" $project_name
			file delete -force $filename
			set filename ""
			append filename ".metadata/" $project_name
			file delete -force $filename
			set filename ""
			append filename ".metadata/" $project_name "_ip_design_build.tcl"
			file delete -force $filename
			set filename ""
			append filename ".metadata/" $project_name "_ip_design_test.tcl"
			file delete -force $filename
			set filename ""
			append filename ".metadata/" $project_name "_configuration_parameters.dat"
			file delete -force $filename
		
		}
	}
	
}
	

 
    if {$error} {
		puts ""
		return -code error
	} else {
		set tmp_str ""
		append tmp_str "Project " $project_name " deleted succesfully."
		puts $tmp_str
		puts ""
		return -code ok
	}

    
}








