#  icl::protoip
#  Suardi Andrea [a.suardi@imperial.ac.uk]
#  November - 2014


package require Vivado 1.2014.2

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_design_test_debug
}


proc ::tclapp::icl::protoip::ip_design_test_debug {args} {

	  # Summary: Open the project named 'project_name' in the Vivado HLS GUI to run a C/RTL simulation.

	  # Argument Usage:
	  # [-project_name <arg>]	- Project name
	  # [-usage]: 				Usage information

	  # Return Value:
	  # Return the Vivado HLS GUI to debug the C/RTL simulation. If any error occur TCL_ERROR is returned

	  # Categories: 
	  # xilinxtclstore, protoip
	  

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
    set filename {}
    set input {}
    set input_vectors {}
    set input_vectors_length {}
    set output {}
    set output_vectors {}
    set output_vectors_length {}
	set project_name {}
	set fclk {}
	set FPGA_name {}
    set returnString 0
		set str_fix "fix"
	set str_float "float"
    while {[llength $args]} {
      set name [lshift args]
      switch -regexp -- $name {
		 -project_name -
        {^-o(u(t(p(ut?)?)?)?)?$} {
             set project_name [lshift args]
             if {$project_name == {}} {
				puts " -E- NO project name specified."
				incr error
             } 
	     }
        -usage -
        {^-u(s(a(ge?)?)?)?$} {
             set help 1
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
    

   

if {$error==0} {  

	set  file_name ""
	append file_name ".metadata/" $project_name "_configuration_parameters.dat"
	
	if {$project_name == {}} {
			set tmp_str ""
			append tmp_str " -E- NO project name specified."
			puts $tmp_str
			incr error
			
		} else {
	
		if {[file exists $file_name] == 0} { 

			set tmp_str ""
			append tmp_str "-E- " $project_name " does NOT exist."
			puts $tmp_str
			incr error
		} else {
		
		
			

			puts ""
			puts "Calling Vivado_HLS GUI ..."
			

			cd ip_design/test/prj

			
			# run Vivado HLS IP test
				
			set vivado_hls_p [open "|vivado_hls -p $project_name" r]
			while {![eof $vivado_hls_p]} { gets $vivado_hls_p line ; puts $line }
			close $vivado_hls_p

			set directives_from ""
			append directives_from $project_name "/solution1/directives.tcl"
			set directives_to ""
			append directives_to "../../src/" $project_name "_directives.tcl"
			file copy -force  $directives_from $directives_to

			
			cd ../../../
			
			
		
		}
	}
	

}


	
	
  if {$help} {
      puts [format {
  Usage: ip_design_test_debug
  [-project_name <arg>]- Project name
						It's a mandatory field
  [-usage|-u]           - This help message

  Description: Open the project named 'project_name' in the Vivado HLS GUI to run a C/RTL simulation.

  Example:
  tclapp::icl::protoip::ip_design_test_debug -project_name my_project0


} ]
      # HELP -->
      return {}
    }

    if {$error} {
		puts "Vivado_HLS GUI error. Please check Vivado_HLS log file at <WORKING_DIRECTORY>/vivado_hls.log  for error(s) info."
		puts ""
		return -code error
	} else {
		puts "Vivado_HLS GUI closed successfully"
		puts ""
		return -code ok
	}

    
}



