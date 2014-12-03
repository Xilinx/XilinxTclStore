
########################################################################################
## 20/11/2014 - First release 1.0
########################################################################################

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_design_test_debug
}


proc ::tclapp::icl::protoip::ip_design_test_debug {args} {

	  # Summary: Open the project named 'project_name' in the Vivado HLS GUI to run a C/RTL simulation.

	  # Argument Usage:
	  # -project_name <arg>: Project name
	  # -type_test <arg>: Test(s) type
	  # [-usage]: Usage information

	  # Return Value:
	  # Return the Vivado HLS GUI to debug the C/RTL simulation. If any error occur TCL_ERROR is returned

	  # Categories: 
	  # xilinxtclstore, protoip
	  
 uplevel [concat ::tclapp::icl::protoip::ip_design_test_debug::ip_design_test_debug $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::icl::protoip::ip_design_test_debug::ip_design_test_debug {
  variable version {20/11/2014}
} ]	  

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G R A M                              # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::icl::protoip::ip_design_test_debug::ip_design_test_debug { args } {
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
	set type_test {}
    set returnString 0
	set str_fix "fix"
	set str_float "float"
	set str_c "c"
	set str_xsim "xsim"
	set str_modelsim "modelsim"
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
		  -type_test -
        {^-t(y(p(e(_(t(e(st?)?)?)?)?)?)?)?$} {
             set type_test [lshift args]
             if {$type_test == {}} {
				puts " -E- NO test(s) type specified."
				incr error
             } else {
				if {$type_test != $str_c && $type_test != $str_xsim && $type_test != $str_modelsim} {
					puts " -E- test(s) type specified is not supported. Use the -usage option for more details"
					incr error
				 }
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
 Usage: ip_design_test_debug
  -project_name <arg>   - Project name
                          It's a mandatory field
  -type_test <arg>     - Test(s) type: 
                         'c' for C-simulation, 
                         'xsim' for RTL-simulation via Xilinx Xsim, 
                         'modelsim' for RTL-simulation via Menthor Graphics Modelsim
                         It's a mandatory field
  [-usage|-u]           - This help message

 Description: 
  Open the project named 'project_name' in the Vivado HLS GUI to debug a 
  C/RTL simulation.
  
  This command can be run after 'ip_design_test' command only.

 Example:
  ip_design_test_debug -project_name my_project0 -type_test c


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
			set type_design_flow [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 18]] 
			
			if {$type_test == {}} { 
				if {$type_design_flow=="matlab"} {
					set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]]
					if {$type_test==0} {
						set type_test "none"
					} elseif {$type_test==1} {
						set type_test "c"
					} elseif {$type_test==2} {
						set type_test "xsim"
					} elseif {$type_test==3} {
						set type_test "modelsim"
					}					
				}
			}
		
		if {$type_test == {}} { 

			error "-E- NO test(s) type specified. Use the -usage option for more details."
			
		} else {
		
		if {$type_test==$str_xsim || $type_test==$str_modelsim} {
		
			set  file_name ""
			append file_name "ip_design/test/prj/" $project_name "/solution1/sim"
			
			if {[file exists $file_name] == 0} { 


				set tmp_error ""
				append tmp_error "-E- " $project_name " has NOT been built. Please run icl::ip_design_test -project_name " $project_name " -type_test " $type_test " first. Use the -usage option for more details."
				error $tmp_error
			}
			
		} elseif {$type_test==$str_c} {
		
			set  file_name ""
			append file_name "ip_design/test/prj/" $project_name "/solution1"
			
			if {[file exists $file_name] == 0} { 


				set tmp_error ""
				append tmp_error "-E- " $project_name " has NOT been built. Please run icl::ip_design_test -project_name " $project_name " -type_test " $type_test " first. Use the -usage option for more details."
				error $tmp_error
			}
		
		}



			puts ""
			puts "Calling Vivado_HLS GUI ..."
			

			cd ip_design/test/prj

			
			# run Vivado HLS IP test
				
			set vivado_hls_p [open "|vivado_hls -p $project_name" r]
			while {![eof $vivado_hls_p]} { gets $vivado_hls_p line ; puts $line }
			close $vivado_hls_p

			if {$type_test==$str_xsim || $type_test==$str_modelsim} {
			
				set directives_from ""
				append directives_from $project_name "/solution1/directives.tcl"
				set directives_to ""
				append directives_to "../../src/" $project_name "_directives.tcl"
				file copy -force  $directives_from $directives_to
			
			}

			
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



