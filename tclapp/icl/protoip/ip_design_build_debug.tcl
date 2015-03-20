
########################################################################################
## 20/11/2014 - First release 1.0
########################################################################################

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_design_build_debug
}


proc ::tclapp::icl::protoip::ip_design_build_debug {args} {

	  # Summary: Open the project named 'project_name' in the Vivado HLS GUI.

	  # Argument Usage:
	  # -project_name <arg> : Project name
	  # [-usage]: Usage information

	  # Return Value:
	  # Return the Vivado HLS GUI to debug the IP hardware design. If any error occur TCL_ERROR is returned

	  # Categories: 
	  # xilinxtclstore, protoip
	  
 uplevel [concat ::tclapp::icl::protoip::ip_design_build_debug::ip_design_build_debug $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::icl::protoip::ip_design_build_debug::ip_design_build_debug {
  variable version {20/11/2014}
} ]	  

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G R A M                              # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::icl::protoip::ip_design_build_debug::ip_design_build_debug { args } {
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
  Usage: ip_design_build_debug
  -project_name <arg>  - Project name
                         It's a mandatory field
  [-usage|-u]          - This help message

  Description: 
   Open the project named 'project_name' in the Vivado HLS GUI 
   to debug the IP hardware design.
  
   This command can be run after 'ip_design_build' command only.


  Example:
   ip_design_build_debug -project_name my_project0


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
		
			set  file_name ""
			append file_name "ip_design/build/prj/" $project_name "/solution1/solution1.directive"
		
		
			if {[file exists $file_name] == 0} { 


			set tmp_error ""
			append tmp_error "-E- " $project_name " has NOT been built. Please run icl::ip_design_build -project_name " $project_name "first. Use the -usage option for more details."
			error $tmp_error

			} else {

				puts ""
				puts "Calling Vivado_HLS GUI ..."
				

				cd ip_design/build/prj

				
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



