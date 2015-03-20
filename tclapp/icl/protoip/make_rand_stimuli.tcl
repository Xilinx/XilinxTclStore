
########################################################################################
## 20/11/2014 - First release 1.0
########################################################################################

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export make_rand_stimuli
}


proc ::tclapp::icl::protoip::make_rand_stimuli {args} {

	  # Summary: Create input vectors with random data (-5,5) to be used as stimuli by ip_design_test.

	  # Argument Usage:
	  # -project_name <arg>: Project name
      # [-input <arg>]: Input vector name,size and type separated by : symbol
      # [-output <arg>]: Output vector name,size and type separated by : symbol
	  # [-usage]: Usage information

	  # Return Value:
	  # Return stimuli vectors in [WORKING DIRECTORY]/ip_design/test/stimuli/project_name and the expected results (using floating point double precision) in [WORKING DIRECTORY]/ip_design/test/results/project_name for the template project. If any error occur TCL_ERROR is returned

	  # Categories: 
	  # xilinxtclstore, protoip
	  
 uplevel [concat ::tclapp::icl::protoip::make_rand_stimuli::make_rand_stimuli $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::icl::protoip::make_rand_stimuli::make_rand_stimuli {
  variable version {20/11/2014}
} ]	  

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G R A M                              # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::icl::protoip::make_rand_stimuli::make_rand_stimuli { args } {
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
	set num_test {}
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
	  -input -
        {^-i(n(p(ut?)?)?)?$} {
            set input [lshift args]
            if {$input == {}} {
               puts " -E- NO input specified."
               incr error
            } else {
				set records [split $input ":"]
				if {[lindex $records 1] == {}} {
					puts " -E- input vector [lindex $records 0]: NO lengths specified."
					incr error
				} else {
					if {[lindex $records 2] == {}} {
						puts " -E- input vector [lindex $records 0]: NO data representation specified."
						incr error
					} else {
						if {[lindex $records 2]==$str_fix} {
							if {[lindex $records 3] == {}} {
								puts " -E- input vector [lindex $records 0]: NO integer length specified."
								incr error
							}
							if {[lindex $records 4] == {}} {
								puts " -E- input vector [lindex $records 0]: NO fraction length specified."
								incr error
							}
						}
					}
				}

				lappend input_vectors [lindex $records 0]
				lappend input_vectors_length [lindex $records 1]
	
				#correctness checks:
				
				#vector length
				if {[string is integer -strict [lindex $records 1]]==1} {
					if {[lindex $records 1]<1} {
						puts " -E- input vector [lindex $records 0]: length must be an integer greater than 0."
						incr error
					}
				} else {
					puts " -E- input vector [lindex $records 0]: length must be an integer greater than 0."
					incr error
				}
				
				#data type
				if {[lindex $records 2] == $str_fix} {
					lappend input_vectors_type "fix"
				} elseif {[lindex $records 2] == $str_float} {
					lappend input_vectors_type "float"
				} else {
					puts " -E- input vector [lindex $records 0]: NO correct data representation specified."
					incr error
				}
				
				#integer_length
				if {[lindex $records 2] == $str_fix} {
					lappend input_vectors_integer_length [lindex $records 3]
					if {[string is integer -strict [lindex $records 3]]==0} {
						puts " -E- input vector [lindex $records 0]: integer length must be an integer."
						incr error
					} else {
						if {[lindex $records 3]<1} {
							puts " -E- input vector [lindex $records 0]: integer length must be an integer greater than 0."
							incr error
						}
					}
				} else {
					lappend input_vectors_integer_length 0
				}
				
				#fraction_length
				if {[lindex $records 2] == $str_fix} {
					lappend input_vectors_fraction_length [lindex $records 4]
					if {[string is integer -strict [lindex $records 4]]==0} {
						puts " -E- input vector [lindex $records 0]: fraction length must be an integer."
						incr error
					}
				} else {
					lappend input_vectors_fraction_length 0
				}
	
			}
	     }

	     
	    
	 -output -
        {^-o(u(t(p(ut?)?)?)?)?$} {
             set output [lshift args]
             if {$output == {}} {
				puts " -E- no output specified."
				incr error
             } else {
				set records [split $output ":"]
				if {[lindex $records 1] == {}} {
					puts " -E- output vector [lindex $records 0]: NO lengths specified."
					incr error
				} else {
					if {[lindex $records 2] == {}} {
						puts " -E- output vector [lindex $records 0]: NO data representation specified."
						incr error
					} else {
						if {[lindex $records 2]==$str_fix} {
							if {[lindex $records 3] == {}} {
								puts " -E- output vector [lindex $records 0]: NO integer length specified."
								incr error
							}
							if {[lindex $records 4] == {}} {
								puts " -E- output vector [lindex $records 0]: NO fraction length specified."
								incr error
							}
						}
					}
				}

				lappend output_vectors [lindex $records 0]
				lappend output_vectors_length [lindex $records 1]
	
				#correctness checks:
				
				#vector length
				if {[string is integer -strict [lindex $records 1]]==1} {
					if {[lindex $records 1]<1} {
						puts " -E- output vector [lindex $records 0]: length must be an integer greater than 0."
						incr error
					}
				} else {
					puts " -E- output vector [lindex $records 0]: length must be an integer greater than 0."
					incr error
				}
				
				#data type
				if {[lindex $records 2] == $str_fix} {
					lappend output_vectors_type "fix"
				} elseif {[lindex $records 2] == $str_float} {
					lappend output_vectors_type "float"
				} else {
					puts " -E- output vector [lindex $records 0]: NO correct data representation specified."
					incr error
				}
				
				#integer_length
				if {[lindex $records 2] == $str_fix} {
					lappend output_vectors_integer_length [lindex $records 3]
					if {[string is integer -strict [lindex $records 3]]==0} {
						puts " -E- output vector [lindex $records 0]: integer length must be an integer."
						incr error
					} else {
						if {[lindex $records 3]<1} {
							puts " -E- output vector [lindex $records 0]: integer length must be an integer greater than 0."
							incr error
						}
					}
				} else {
					lappend output_vectors_integer_length 0
				}
				
				#fraction_length
				if {[lindex $records 2] == $str_fix} {
					lappend output_vectors_fraction_length [lindex $records 4]
					if {[string is integer -strict [lindex $records 4]]==0} {
						puts " -E- output vector [lindex $records 0]: fraction length must be an integer."
						incr error
					}
				} else {
					lappend output_vectors_fraction_length 0
				}
	
			}
	     }
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
 Usage: ip_design_test
  -project_name <arg>  - Project name
                         It's a mandatory field
 [-input <arg>]        - Input vector name,size and type separated by : symbol
                         Type can be: float or fix:xx:yy. 
                         Where 'xx' is the integer length and 'yy' the 
                         fraction length
                         Repeat the command for every input vector to update
                         All inputs and outputs must be of the same type: 
                         float or fix
 [-output <arg>]       - Output vector name,size and type separated by : symbol
                         Type can be: float or fix:xx:yy. 
                         Where 'xx' is the integer length and 'yy' the 
                         fraction length
                         Repeat the command for every output to update
                         All inputs and outputs must be of the same type: 
                         float or fix
 [-usage|-u]           - This help message

  Description: 
   Create input vectors with random data (-5,5) to be used as stimuli 
   by ip_design_test and store them in  [WORKING DIRECTORY]/ip_design/test/stimuli/project_name.
   Expected results (using floating point double precision) 
   for the template project are stored in 
   [WORKING DIRECTORY]/ip_design/test/results/project_name.

  This command should be run before 'ip_design_test' command.


  Example:
   ip_design_make_rand_stimuli -project_name my_project0
   ip_design_make_rand_stimuli -project_name my_project0 -input x1:2:fix:4:6 -output y0:3:fix:2:4


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

			for {set i 0} {$i < $num_input_vectors} {incr i} {
				lappend old_input_vectors [lindex $data [expr 4 + ($i * 5)]]
				lappend old_input_vectors_length [lindex $data [expr 5 + ($i * 5)]]
				lappend old_input_vectors_type [lindex $data [expr 6 + ($i * 5)]]
				lappend old_input_vectors_integer_length [lindex $data [expr 7 + ($i * 5)]]
				lappend old_input_vectors_fraction_length [lindex $data [expr 8 + ($i * 5)]]
			}
			for {set i 0} {$i < $num_output_vectors} {incr i} {
				lappend old_output_vectors [lindex $data [expr ($num_input_vectors * 5) + 4 + 2 + ($i * 5)]]
				lappend old_output_vectors_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 3 + ($i * 5)]]
				lappend old_output_vectors_type [lindex $data [expr ($num_input_vectors * 5) + 4 + 4 + ($i * 5)]]
				lappend old_output_vectors_integer_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 5 + ($i * 5)]]
				lappend old_output_vectors_fraction_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 6 + ($i * 5)]]
			}

			set fclk [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 2]] 
			set FPGA_name [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 4]] 
			set board_name [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 6]] 
			set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
			set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
			set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
			set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 
			set type_template [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 16]] 
			set type_design_flow [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 18]] 

			
			# update configuration parameters
			set m 0
			foreach i $old_input_vectors_type {
				if {$i==1} {
					set old_input_vectors_type [lreplace $old_input_vectors_type $m $m "fix"]
				} else {
					set old_input_vectors_type [lreplace $old_input_vectors_type $m $m "float"]
				}
				incr m
			}
			set m 0
			foreach i $old_output_vectors_type {
				if {$i==1} {
					set old_output_vectors_type [lreplace $old_output_vectors_type $m $m "fix"]
				} else {
					set old_output_vectors_type [lreplace $old_output_vectors_type $m $m "float"]
				}
				incr m
			}
		
			
			if {$type_eth==0} {
				set type_eth "udp"
			} elseif {$type_eth==1} {
				set type_eth "tcp"
			} 
			
			
			
			set m 0
			foreach i $input_vectors {
				set position [lsearch -exact $old_input_vectors $i]
				puts $position
				if {$position !=-1} {
					set old_input_vectors [lreplace $old_input_vectors $position $position $i]
					set old_input_vectors_length [lreplace $old_input_vectors_length $position $position [lindex $input_vectors_length $m]]
					set old_input_vectors_type [lreplace $old_input_vectors_type $position $position [lindex $input_vectors_type $m]]
					set old_input_vectors_integer_length [lreplace $old_input_vectors_integer_length $position $position [lindex $input_vectors_integer_length $m]]
					set old_input_vectors_fraction_length [lreplace $old_input_vectors_fraction_length $position $position [lindex $input_vectors_fraction_length $m]]	
				} else {
				
					set tmp_error ""
					append tmp_error " -E- NO input vector " $i " found. Use the -usage option for more details."
					error $tmp_error
				}
				
				incr m
			}
			set m 0
			foreach i $output_vectors {
				set position [lsearch -exact $old_output_vectors $i]
				if {$position !=-1} {
					set old_output_vectors [lreplace $old_output_vectors $position $position $i]
					set old_output_vectors_length [lreplace $old_output_vectors_length $position $position [lindex $output_vectors_length $m]]
					set old_output_vectors_type [lreplace $old_output_vectors_type $position $position [lindex $output_vectors_type $m]]
					set old_output_vectors_integer_length [lreplace $old_output_vectors_integer_length $position $position [lindex $output_vectors_integer_length $m]]
					set old_output_vectors_fraction_length [lreplace $old_output_vectors_fraction_length $position $position [lindex $output_vectors_fraction_length $m]]	
				} else {
				
					set tmp_error ""
					append tmp_error " -E- NO output vector " $i " found. Use the -usage option for more details."
					error $tmp_error
				}
				incr m
			}
			
			set input_vectors $old_input_vectors 
			set input_vectors_length $old_input_vectors_length 
			set input_vectors_type $old_input_vectors_type 
			set input_vectors_integer_length $old_input_vectors_integer_length 
			set input_vectors_fraction_length $old_input_vectors_fraction_length 
			set output_vectors $old_output_vectors
			set output_vectors_length $old_output_vectors_length 
			set output_vectors_type $old_output_vectors_type 
			set output_vectors_integer_length $old_output_vectors_integer_length 
			set output_vectors_fraction_length $old_output_vectors_fraction_length 
			
			
			set count_is_float 0
			set count_is_fix 0
			foreach i $input_vectors_type {
				if {$i==$str_fix} {
					incr count_is_fix
				} else {
					incr count_is_float
				}
			}
			foreach i $output_vectors_type {
				if {$i==$str_fix} {
					incr count_is_fix
				} else {
					incr count_is_float
				}
			}

			if {$count_is_fix==[expr $num_input_vectors+$num_output_vectors] || $count_is_float==[expr $num_input_vectors+$num_output_vectors]} {
			
				[::tclapp::icl::protoip::make_template::make_project_configuration_parameters_dat $project_name $input_vectors $input_vectors_length $input_vectors_type $input_vectors_integer_length $input_vectors_fraction_length $output_vectors $output_vectors_length $output_vectors_type $output_vectors_integer_length $output_vectors_fraction_length $fclk $FPGA_name $board_name $type_eth $mem_base_address $num_test $type_test $type_template $type_design_flow]

				[::tclapp::icl::protoip::make_template::make_ip_configuration_parameters_readme_txt $project_name]
				
				set template_project_result 0
				
				set m 0
				foreach i $input_vectors {
					set  file_name ""
					append file_name "ip_design/test/stimuli/" $project_name "/" $i "_in.dat"

					set file [open $file_name w]
					
					for {set j 0} {$j < [lindex $input_vectors_length $m]} {incr j} {
						set new_data [expr (rand()-0.5)*10]
						puts $file $new_data
						set template_project_result [expr $template_project_result + $new_data]
					}
					incr m
					close $file
				}
				
				set m 0
				foreach i $output_vectors {
					set  file_name ""
					append file_name "ip_design/test/results/" $project_name "/" $i "_out_project_template_expected_result.dat"

					set file [open $file_name w]
					
					for {set j 0} {$j < [lindex $output_vectors_length $m]} {incr j} {
						puts $file $template_project_result
					}
					incr m
					close $file
				}
				
			} else {			
				

				error  " -E- Inputs and Outputs must be either fixed-point or floating-point. Use the -usage option for more details."


			}	
		
		}
	}

	

}


	


    if {$error} {
		puts ""
		return -code error
	} else {
		puts "Stimulus vectors with random data and template project expected results created succesfully"
		puts ""
		return -code ok
	}

    
}



