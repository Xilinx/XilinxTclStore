
########################################################################################
## 20/11/2014 - First release 1.0
########################################################################################

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export make_template
}




# ########################################################################################
# main make_template procedure

proc ::tclapp::icl::protoip::make_template {args} {
	# Summary: Build the IP prototype project template in the current working directory

	# Argument Usage:
	# -type <arg>: Template type
	# -project_name <arg>: Project name
	# -input <arg>: Input vector name,size and type separated by ':' symbol
	# -output <arg>: Output vector name,size and type separated by ':' symbol
	# [-usage]: Usage information

	# Return Value:
	# Return the IP prototype project template according to the specified input and outputs vectors in the [WORKING DIRECTORY]. The project configuration parameters report is available in [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt. If any error occur TCL_ERROR is returned

	# Categories: 
	# xilinxtclstore, protoip
  
  uplevel [concat ::tclapp::icl::protoip::make_template::make_template $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::icl::protoip::make_template::make_template {
  variable version {20/11/2014}
} ]	  

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G R A M                              # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::icl::protoip::make_template::make_template { args } {
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

	puts ""
	puts ""

    #-------------------------------------------------------
    # read command line arguments
    #-------------------------------------------------------
    set error 0
    set help 0
    set filename {}
    set input {}
    set input_vectors {}
    set input_vectors_length {}
	set input_vectors_type {}
	set input_vectors_integer_length {}
	set input_vectors_fraction_length {}
    set output {}
    set output_vectors {}
    set output_vectors_length {}
	set output_vectors_type {}
	set output_vectors_integer_length {}
	set output_vectors_fraction_length {}
	set project_name {}
	set type_template {}
	set type_design_flow {}
    set returnString 0
	set str_fix "fix"
	set str_float "float"
	
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
		 -type -
        {^-t(y(pe?)?)?$} {
             set type_template [lshift args]
			 set type_design_flow "vivado"
             if {$type_template == {}} {
				puts " -E- NO template type specified."
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
  Usage: make_template
 -type <arg>          - Template project type. 
                        Now only a template with the algorithm running inside 
                        the FPGA programmable logic is supported ('PL').
                        It's a mandatory field
 -project_name <arg>  - Project name
                        It's a mandatory field
 -input <arg>         - Input vector name,size and type separated by : symbol
                        Type can be: float or fix:xx:yy. 
                        Where 'xx' is the integer length and 'yy' the 
                        fraction length
                        Repeat the command for every input vectors
                        All inputs and outputs must be of the same type: 
                        float or fix
 -output <arg>        - Output vector name,size and type separated by : symbol
                        Type can be: float or fix:xx:yy. 
                        Where 'xx' is the integer length and 'yy' the 
                        fraction length
                        Repeat the command for every output vectors
                        All inputs and outputs must be of the same type: 
                        float or fix
  [-usage|-u]         - This help message

 Description: 
  Build the IP prototype project template in the [WORKING DIRECTORY] 
  according to the specified input and outputs vectors.
  The project configuration parameters report is available in 
  [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt
 
 

 Example 1:
  IP prototype with 2 inputs vectors: 
  x0[10] fixed point (integer length 4 and fraction length 2)
  x1[2] fixed point (integer length 6 and fraction length 2)
  
  1 output vector: 
  y0[3] fixed point (integer length 3 and fraction length 2)
  
  make_template -type PL -project_name my_project0 -input x0:1:fix:4:2 -input x1:2:fix:6:4 -output y0:3:fix:3:2
  
 Example 2:
  IP prototype with 2 inputs vectors: 
  x0[1] floating point
  x1[2] floating point
  
  1 output vector: 
  y0[4] floating point
  
  make_template -type PL -project_name my_project0 -input x0:1:float -input x1:2:float -output y0:4:float


} ]
      # HELP -->
      return {}
    }    
    
 if {$error} {
    error " -E- some error(s) happened. Cannot continue. Use the -usage option for more details"
  }   
    
    
    
if {$help==0} {  


	set  file_name ""
	append file_name ".metadata/" $project_name "_configuration_parameters.dat"
	
	if {$project_name == {}} {
	
		error " -E- NO project name specified. Use the -usage option for more details."
		
	} else {

		#If $type_template is not specified, make_template.tcl has been called from Matlab, otherwise from within Vivado
		if {$type_template == {}} { 
			#Call from Matlab: then load data from "configuration_parameters_matlab_interface.dat" 
		
			set  file_name ""
			append file_name ".metadata/configuration_parameters_matlab_interface.dat"
			set fp [open $file_name r]
			set file_data [read $fp]
			close $fp
			set data [split $file_data "\n"]

			set r_project_name [lindex $data 1]

			set new_num_input_vectors [lindex $data 3]
			set new_num_output_vectors [lindex $data [expr ($new_num_input_vectors * 5) + 4 + 1]]
			set new_input_vectors {}
			set new_input_vectors_length {}
			set new_input_vectors_type {}
			set new_input_vectors_integer_length {}
			set new_input_vectors_fraction_length {}
			set new_output_vectors {}
			set new_output_vectors_length {}
			set new_output_vectors_type {}
			set new_output_vectors_integer_length {}
			set new_output_vectors_fraction_length {}

			for {set i 0} {$i < $new_num_input_vectors} {incr i} {
				lappend new_input_vectors [lindex $data [expr 4 + ($i * 5)]]
				lappend new_input_vectors_length [lindex $data [expr 5 + ($i * 5)]]
				lappend new_input_vectors_type [lindex $data [expr 6 + ($i * 5)]]
				lappend new_input_vectors_integer_length [lindex $data [expr 7 + ($i * 5)]]
				lappend new_input_vectors_fraction_length [lindex $data [expr 8 + ($i * 5)]]
			}
			for {set i 0} {$i < $new_num_output_vectors} {incr i} {
				lappend new_output_vectors [lindex $data [expr ($new_num_input_vectors * 5) + 4 + 2 + ($i * 5)]]
				lappend new_output_vectors_length [lindex $data [expr ($new_num_input_vectors * 5) + 4 + 3 + ($i * 5)]]
				lappend new_output_vectors_type [lindex $data [expr ($new_num_input_vectors * 5) + 4 + 4 + ($i * 5)]]
				lappend new_output_vectors_integer_length [lindex $data [expr ($new_num_input_vectors * 5) + 4 + 5 + ($i * 5)]]
				lappend new_output_vectors_fraction_length [lindex $data [expr ($new_num_input_vectors * 5) + 4 + 6 + ($i * 5)]]
			}		
			set new_type_template [lindex $data [expr ($new_num_input_vectors * 5) + ($new_num_output_vectors * 5) + 5 + 16]]
			set new_type_design_flow [lindex $data [expr ($new_num_input_vectors * 5) + ($new_num_output_vectors * 5) + 5 + 18]] 


			# update configuration parameters
			set m 0
			foreach i $new_input_vectors_type {
				if {$i==1} {
					set new_input_vectors_type [lreplace $new_input_vectors_type $m $m "fix"]
				} else {
					set new_input_vectors_type [lreplace $new_input_vectors_type $m $m "float"]
				}
				incr m
			}
			set m 0
			foreach i $new_output_vectors_type {
				if {$i==1} {
					set new_output_vectors_type [lreplace $new_output_vectors_type $m $m "fix"]
				} else {
					set new_output_vectors_type [lreplace $new_output_vectors_type $m $m "float"]
				}
				incr m
			}
		
		
			set num_input_vectors $new_num_input_vectors
			set num_output_vectors $new_num_output_vectors
			set input_vectors $new_input_vectors 
			set input_vectors_length $new_input_vectors_length 
			set input_vectors_type $new_input_vectors_type 
			set input_vectors_integer_length $new_input_vectors_integer_length 
			set input_vectors_fraction_length $new_input_vectors_fraction_length 
			set output_vectors $new_output_vectors
			set output_vectors_length $new_output_vectors_length 
			set output_vectors_type $new_output_vectors_type 
			set output_vectors_integer_length $new_output_vectors_integer_length 
			set output_vectors_fraction_length $new_output_vectors_fraction_length 
			set type_template $new_type_template
			set type_design_flow $new_type_design_flow

		} 	
	}
		


		
	#-------------------------------------------------------
		# integer and fraction length correctness checks
		#-------------------------------------------------------
		set count 0
		set str_fix "fix"
		foreach i $input_vectors {
			if {[lindex $input_vectors_type $count]==$str_fix} {
				if {[expr [lindex $input_vectors_integer_length $count] + [lindex $input_vectors_fraction_length $count]]>=32} {
					puts " -E- input vector $i: word length (integer_length + fraction_length) must be smaller or equal to 32 bits."
					incr error
				}
			} 
			incr count
		}
		set count 0
		set str_fix "fix"
		foreach i $output_vectors {
			if {[lindex $output_vectors_type $count]==$str_fix} {
				if {[expr [lindex $output_vectors_integer_length $count] + [lindex $output_vectors_fraction_length $count]]>=32} {
					puts " -E- output vector $i: word length (integer_length + fraction_length) must be smaller or equal to 32 bits."
					incr error
				}
			} 
			incr count
		}
		

		#-------------------------------------------------------
		# Input and outputs correctness checks
		# Print to screen input and outputs vectors if any, 
		#------------------------------------------------------- 

		#checks if there are input vector with the same name
		set error_i 0
		set count_i 0
		foreach i $input_vectors {
			set count_j 0
			foreach j $input_vectors {
				if {$count_j > $count_i} { 
					if {$i == $j} {
						incr error_i
					}
				}
				incr count_j
			}
			incr count_i
		}
		if {$error_i>0} {
			puts " -E- there are inputs vector with the same name"
			incr error
		}
		
		#checks if there are output vector with the same name
		set error_o 0
		set count_i 0
		foreach i $output_vectors {
			set count_j 0
			foreach j $output_vectors {
				if {$count_j > $count_i} { 
					if {$i == $j} {
						incr error_o
					}
				}
				incr count_j
			}
			incr count_i
		}
		if {$error_o>0} {
			puts " -E- there are outputs vector with the same name"
			incr error
		}
		

		#checks if there is at least one input vector 
		   if {[lindex $input_vectors 0] == {}} {
			puts " -E- there are NO input vectors."
			incr error
		   }
		   #checks if there is at least one output vector 
		   if {[lindex $output_vectors 0] == {}} {
			puts " -E- there are NO outputs vectors."
			incr error
		   }
		   
		   if {$error==0} {
				puts ""
				puts "Input vectors list:"
				puts "---------------------------"
				set m 0
				foreach i $input_vectors {
					if {[lindex $input_vectors_length $m] != {}}  {
						if {[lindex $input_vectors_type $m]==$str_fix} {
							puts "input vector  $m: '$i' is [lindex $input_vectors_length $m] element(s) of [lindex $input_vectors_type $m](s) (integer length = [lindex $input_vectors_integer_length $m] bits, fraction length = [lindex $input_vectors_fraction_length $m] bits)"
						} else {
							puts "input vector  $m: '$i' is [lindex $input_vectors_length $m] element(s) of [lindex $input_vectors_type $m](s) "
						}
					}
					incr m
					}

			puts ""    
			
			
				puts ""
				puts "Output vectors list:"
				puts "---------------------------"
				set m 0
				foreach i $output_vectors {
					if {[lindex $output_vectors_length $m] != {}}  {
						if {[lindex $output_vectors_type $m]==$str_fix} {
							puts "output vector  $m: '$i' is [lindex $output_vectors_length $m] element(s) of [lindex $output_vectors_type $m](s) (integer length = [lindex $output_vectors_integer_length $m] bits, fraction length = [lindex $output_vectors_fraction_length $m] bits)"
						} else {
							puts "output vector  $m: '$i' is [lindex $output_vectors_length $m] element(s) of [lindex $output_vectors_type $m](s) "
						}
					}
					incr m
					}
				puts ""
			}	

    
}

 if {$error} {
    error " -E- some error(s) happened. Cannot continue. Use the -usage option for more details"
  }  
 
   

if {$error==0} {  

	#-------------------------------------------------------
	# Make project directory structure
	#-------------------------------------------------------

	file mkdir .metadata 
	
	file mkdir doc
	
	file mkdir ip_design/src
	file mkdir ip_design/test/prj
	file mkdir ip_design/test/stimuli/$project_name
	file mkdir ip_design/test/results/$project_name
	file mkdir ip_design/build/prj

	file mkdir ip_prototype/src
	file mkdir ip_prototype/test/prj
	file mkdir ip_prototype/test/results/$project_name
	file mkdir ip_prototype/build/prj

	
	

	#default parameters
	set fclk 100; 
	set FPGA_name "xc7z020clg484-1" 
	set board_name "zedboard"
	set type_eth "udp"
	set mem_base_address 33554432; #32 MB
	set num_test 1
	set type_test "c"
	
	

	#make project configuration parameters file
	[::tclapp::icl::protoip::make_template::make_project_configuration_parameters_dat $project_name $input_vectors $input_vectors_length $input_vectors_type $input_vectors_integer_length $input_vectors_fraction_length $output_vectors $output_vectors_length $output_vectors_type $output_vectors_integer_length $output_vectors_fraction_length $fclk $FPGA_name $board_name $type_eth $mem_base_address $num_test $type_test $type_template $type_design_flow]
	##make configuration parameters readme
	[::tclapp::icl::protoip::make_template::make_ip_configuration_parameters_readme_txt $project_name]
	
	
	#load configuration parameters
	set  file_name ""
	append file_name ".metadata/" $project_name "_configuration_parameters.dat"
	set fp [open $file_name r]
	set file_data [read $fp]
	close $fp
	set data [split $file_data "\n"]

	set num_input_vectors [lindex $data 3]
	set num_output_vectors [lindex $data [expr ($num_input_vectors * 5) + 4 + 1]]

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
	


	if {$type_template == "PL"} {
	
	
	if {$count_is_fix==[expr $num_input_vectors+$num_output_vectors] || $count_is_float==[expr $num_input_vectors+$num_output_vectors]} {
	
		#make ip_design template source files
		[::tclapp::icl::protoip::make_template::make_foo_user_cpp $project_name]
		[::tclapp::icl::protoip::make_template::make_foo_cpp $project_name]
		[::tclapp::icl::protoip::make_template::make_foo_data_h $project_name]
		[::tclapp::icl::protoip::make_template::make_directives $project_name]
		[::tclapp::icl::protoip::make_template::make_ip_design_build_tcl $project_name]
		
		##make ip_design test templates source files
		[::tclapp::icl::protoip::make_template::make_foo_test_cpp $project_name]
		[::tclapp::icl::protoip::make_template::make_foo_user_m $project_name]
		[::tclapp::icl::protoip::make_template::make_load_configuration_parameters_m]
		[::tclapp::icl::protoip::make_template::make_ip_design_test_tcl $project_name] 
		[::tclapp::icl::protoip::make_template::FPGAclientMATLAB_m]
		[::tclapp::icl::protoip::make_template::FPGAclientMATLAB_c]
		[::tclapp::icl::protoip::make_template::make_FPGAclientAPI_h $project_name]

		##make ip_prototype template source files

		[::tclapp::icl::protoip::make_template::make_FPGAserver_h $project_name]
		[::tclapp::icl::protoip::make_template::make_test_HIL_m $project_name]
		[::tclapp::icl::protoip::make_template::make_echo_c $project_name]
		[::tclapp::icl::protoip::make_template::make_main_c]
		[::tclapp::icl::protoip::make_template::MicroZed_PS_properties_v02_tcl]
		

		
		##make ip_prototype_make_sdk_prj_tcl
		[::tclapp::icl::protoip::make_template::make_build_sdk_project_tcl]
		[::tclapp::icl::protoip::make_template::make_run_fpga_prototype_tcl]
		
		} else {

			set tmp_str ""
			append tmp_str " -E- Inputs and Outputs must be either fixed-point or floating-point."
			puts $tmp_str
			incr error
		}
		
	} else {			
		
		set tmp_str ""
		append tmp_str " -E- Template project type " $type_template "is not supported. Please type 'icl::protoip::make_template -usage' for usage info"
		puts $tmp_str
		incr error

	}
	
}


	
	
 

    if {$error} {
	puts ""
      error " -E- some error(s) happened. Please type 'icl::protoip::make_template -usage' for usage info"
    }

    puts ""
	set tmp_str ""
	append tmp_str "Template project type " $type_template " built in [pwd] folder successfully"
    return -code ok $tmp_str
}

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         MAKE TEMPLATE PROCEDURES                             # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

# ########################################################################################
# license header tcl format

proc ::tclapp::icl::protoip::make_template::license_tcl {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set file  [lindex $args 0]

# puts $file "# ##############################################################################################"
# puts $file "# Copyright (c) 2014, Imperial College London"
# puts $file "# All rights reserved."
# puts $file "#"
# puts $file "# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:"
# puts $file "#"
# puts $file "# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer."
# puts $file "#"
# puts $file "# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution."
# puts $file "#"
# puts $file "# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
# puts $file "# ##############################################################################################"
# puts $file ""
puts $file "# ##############################################################################################"
puts $file "# icl::protoip"
puts $file "# Author: asuardi <https://github.com/asuardi>"
puts $file "# Date: November - 2014"
puts $file "# ##############################################################################################"
puts $file ""
puts $file ""
return -code ok

}



# ########################################################################################
# license header C/C++ format

proc ::tclapp::icl::protoip::make_template::license_c {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set file  [lindex $args 0]

# puts $file "/* "
# puts $file "* Copyright (c) 2014, Imperial College London"
# puts $file "* All rights reserved."
# puts $file "* "
# puts $file "* Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:"
# puts $file "* "
# puts $file "* 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer."
# puts $file "* "
# puts $file "* 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution."
# puts $file "* "
# puts $file "* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
# puts $file "*/"
puts $file "/* "
puts $file "* icl::protoip"
puts $file "* Author: asuardi <https://github.com/asuardi>"
puts $file "* Date: November - 2014"
puts $file "*/"
puts $file ""
puts $file ""
return -code ok

}


# ########################################################################################
# license header Matlab format

proc ::tclapp::icl::protoip::make_template::license_m {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set file  [lindex $args 0]

# puts $file "%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
# puts $file "% Copyright (c) 2014, Imperial College London"
# puts $file "% All rights reserved."
# puts $file "%"
# puts $file "% Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:"
# puts $file "%"
# puts $file "% 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer."
# puts $file "%"
# puts $file "% 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution."
# puts $file "%"
# puts $file "% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
# puts $file "%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
# puts $file ""
puts $file "%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
puts $file "% icl::protoip"
puts $file "% Author: asuardi <https://github.com/asuardi>"
puts $file "% Date: November - 2014"
puts $file "%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
puts $file ""
puts $file ""
return -code ok

}


# ########################################################################################
# make configuration_parameters.tcl  file

proc ::tclapp::icl::protoip::make_template::make_project_configuration_parameters_dat {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:
  
set project_name [lindex $args 0]
set input_vectors [lindex $args 1]
set input_vectors_length [lindex $args 2]
set input_vectors_type [lindex $args 3]
set input_vectors_integer_length [lindex $args 4]
set input_vectors_fraction_length [lindex $args 5]
set output_vectors [lindex $args 6]
set output_vectors_length [lindex $args 7]
set output_vectors_type [lindex $args 8]
set output_vectors_integer_length [lindex $args 9]
set output_vectors_fraction_length [lindex $args 10]
set fclk [lindex $args 11]
set FPGA_name [lindex $args 12]
set board_name [lindex $args 13]
set type_eth [lindex $args 14]
set mem_base_address [lindex $args 15]
set num_test [lindex $args 16]
set type_test [lindex $args 17]
set type_template [lindex $args 18]
set type_design_flow [lindex $args 19]



set str_fix "fix"
 
set  file_name ""
append file_name ".metadata/" $project_name "_configuration_parameters.dat"
  
set file [open $file_name w]

#project name
puts $file "#Project_name"
puts $file $project_name

#Inputs:
puts $file "#Input"
set count 0
foreach i $input_vectors {
	incr count
}
#Number of inputs vectors
puts $file $count
set count 0
foreach i $input_vectors {
	#Vector name
	puts $file $i
	#Number of elements
	puts $file [lindex $input_vectors_length $count]
	#Data type: 0=FLOAT (floating-point single precision), 1=FIX (fixed-point up to 32 bits word length)
	if {[lindex $input_vectors_type $count]==$str_fix} {
		puts $file 1
	} else {
		puts $file 0
	}
	#Integer length
	puts $file [lindex $input_vectors_integer_length $count]
	#Fraction length
	puts $file [lindex $input_vectors_fraction_length $count]
	incr count
}

#Outputs:
puts $file "#Output"
set count 0
foreach i $output_vectors {
	incr count
}
#Number of ouputs vectors
puts $file $count
set count 0
foreach i $output_vectors {
	#Vector name
	puts $file $i
	#Number of elements
	puts $file [lindex $output_vectors_length $count]
	#Data type: 0=FLOAT (floating-point single precision), 1=FIX (fixed-point up to 32 bits word length)
	if {[lindex $output_vectors_type $count]==$str_fix} {
		puts $file 1
	} else {
		puts $file 0
	}
	#Integer length
	puts $file [lindex $output_vectors_integer_length $count]
	#Fraction length
	puts $file [lindex $output_vectors_fraction_length $count]
	incr count
}

#fclk:
puts $file "#fclk"
puts $file $fclk

#FPGA_name:
puts $file "#FPGA_name"
puts $file $FPGA_name

#board_name:
puts $file "#board_name"
puts $file $board_name

#type_eth:
set str_udp "udp"
set str_tcp "tcp"

puts $file "#type_eth"
if {$type_eth==$str_udp} {
	puts $file 0
} elseif {$type_eth==$str_tcp} {
	puts $file 1
} 

#mem_base_address:
puts $file "#mem_base_address"
puts $file $mem_base_address

#num_test:
puts $file "#num_test"
puts $file $num_test

#type_test:
set str_none "none"
set str_c "c"
set str_xsim "xsim"
set str_modelsim "modelsim"

puts $file "#type_test"
if {$type_test==$str_c} {
	puts $file 1
} elseif {$type_test==$str_xsim} {
	puts $file 2
} elseif {$type_test==$str_modelsim} {
	puts $file 3
} else {
	puts $file 0
}

#type_template:
puts $file "#type_template"
puts $file $type_template

#type_design_flow:
puts $file "#type_design_flow"
puts $file $type_design_flow



close $file
return -code ok

}



# ########################################################################################
# make ip_design/src/foo_user.cpp  file

proc ::tclapp::icl::protoip::make_template::make_foo_user_cpp {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set project_name [lindex $args 0]

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
set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 


set file [open  ip_design/src/foo_user.cpp w]

#add license_c header
[::tclapp::icl::protoip::make_template::license_c $file]

puts $file "#include \"foo_data.h\""
puts $file ""
puts $file ""
set m 0
foreach i $input_vectors {
	incr m
	if { $m == 1} {  
		append tmp_line "void foo_user(  data_t_" $i "_in " $i "_in_int\["  [string toupper $i] "_IN_LENGTH\],"
		puts $file $tmp_line
		unset tmp_line
	} else {
	append tmp_line "				data_t_" $i "_in " $i "_in_int\["  [string toupper $i] "_IN_LENGTH\],"
	puts $file $tmp_line
	unset tmp_line
	}
}
set m 0
foreach i $output_vectors {
	incr m
	if { $m == [llength $output_vectors]} {  
		append tmp_line "				data_t_" $i "_out " $i "_out_int\["  [string toupper $i] "_OUT_LENGTH\])"
		puts $file $tmp_line
		unset tmp_line
	} else {
	append tmp_line "				data_t_" $i "_out " $i "_out_int\["  [string toupper $i] "_OUT_LENGTH\],"
	puts $file $tmp_line
	unset tmp_line
	}
}
puts $file "{"
puts $file ""
puts $file "	///////////////////////////////////////"
puts $file "	//ADD USER algorithm here below:"
puts $file "	//(this is an example)"


set count_i 0
foreach i $output_vectors {

puts $file "	alg_$count_i : for(int i = 0; i <[string toupper $i]_OUT_LENGTH; i++)"
puts $file "	{"


set tmp_line ""
append tmp_line "		" $i "_out_int\[i\]=0;"
puts $file $tmp_line
foreach j $input_vectors {
	
puts $file "		loop_$j : for(int i_$j = 0; i_$j <[string toupper $j]_IN_LENGTH; i_$j++)"
puts $file "		\{"		
set tmp_line ""
append tmp_line "			" $i "_out_int\[i\]=" $i "_out_int\[i\] + (data_t_" $i "_out)" $j "_in_int\[i_" $j "\];"
puts $file $tmp_line
puts $file "		\}"	

	}

puts $file "	}"
puts $file ""
incr count_i
}
	


puts $file "}"
close $file

return -code ok

}



# ########################################################################################
# make ip_design/src/foo.cpp  file


proc ::tclapp::icl::protoip::make_template::make_foo_cpp {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set project_name [lindex $args 0]

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
set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 



set file [open ip_design/src/foo.cpp w]

#add license_c header
[::tclapp::icl::protoip::make_template::license_c $file]

puts $file "#include \"foo_data.h\""
puts $file ""
puts $file ""
set m 0
foreach i $input_vectors {
	incr m
	if { $m == 1} {  
		append tmp_line "void foo_user(  data_t_" $i "_in " $i "_in_int\["  [string toupper $i] "_IN_LENGTH\],"
		puts $file $tmp_line
		unset tmp_line
	} else {
	append tmp_line "				data_t_" $i "_in " $i "_in_int\["  [string toupper $i] "_IN_LENGTH\],"
	puts $file $tmp_line
	unset tmp_line
	}
}
set m 0
foreach i $output_vectors {
	incr m
	if { $m == [llength $output_vectors]} {  
		append tmp_line "				data_t_" $i "_out " $i "_out_int\["  [string toupper $i] "_OUT_LENGTH\]);"
		puts $file $tmp_line
		unset tmp_line
	} else {
	append tmp_line "				data_t_" $i "_out " $i "_out_int\["  [string toupper $i] "_OUT_LENGTH\],"
	puts $file $tmp_line
	unset tmp_line
	}
}



puts $file ""
puts $file ""
puts $file "void foo	("

foreach i $input_vectors {
	append tmp_line "				uint32_t byte_" $i "_in_offset,"
	puts $file $tmp_line
	unset tmp_line
}
foreach i $output_vectors {
	append tmp_line "				uint32_t byte_" $i "_out_offset,"
	puts $file $tmp_line
	unset tmp_line
}



puts $file "				volatile data_t_memory *memory_inout)"
puts $file "{"
puts $file ""


puts $file "	#ifndef __SYNTHESIS__"
puts $file "	//Any system calls which manage memory allocation within the system, for example malloc(), alloc() and free(), must be removed from the design code prior to synthesis. "
puts $file ""
foreach i $input_vectors {
	append tmp_line "	data_t_interface_" $i "_in *" $i "_in;"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	" $i "_in = (data_t_interface_" $i "_in *)malloc([string toupper $i]_IN_LENGTH*sizeof(data_t_interface_" $i "_in));"
	puts $file $tmp_line
	unset tmp_line
}
foreach i $output_vectors {
	append tmp_line "	data_t_interface_" $i "_out *" $i "_out;"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	" $i "_out = (data_t_interface_" $i "_out *)malloc([string toupper $i]_OUT_LENGTH*sizeof(data_t_interface_" $i "_out));"
	puts $file $tmp_line
	unset tmp_line
}
puts $file ""
foreach i $input_vectors {
	append tmp_line "	data_t_" $i "_in *" $i "_in_int;"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	" $i "_in_int = (data_t_" $i "_in *)malloc([string toupper $i]_IN_LENGTH*sizeof (data_t_" $i "_in));"
	puts $file $tmp_line
	unset tmp_line
}
foreach i $output_vectors {
	append tmp_line "	data_t_" $i "_out *" $i "_out_int;"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	" $i "_out_int = (data_t_" $i "_out *)malloc([string toupper $i]_OUT_LENGTH*sizeof (data_t_" $i "_out));"
	puts $file $tmp_line
	unset tmp_line
}
puts $file ""

puts $file "	#else"
puts $file "	//for synthesis"
puts $file ""
foreach i $input_vectors {
	append tmp_line "	data_t_interface_" $i "_in  " $i "_in\[[string toupper $i]_IN_LENGTH\];"
	puts $file $tmp_line
	unset tmp_line
}
foreach i $output_vectors {
	append tmp_line "	data_t_interface_" $i "_out  " $i "_out\[[string toupper $i]_OUT_LENGTH\];"
	puts $file $tmp_line
	unset tmp_line
}
puts $file ""
foreach i $input_vectors {
	append tmp_line "	data_t_" $i "_in  " $i "_in_int\[[string toupper $i]_IN_LENGTH\];"
	puts $file $tmp_line
	unset tmp_line
}
foreach i $output_vectors {
	append tmp_line "	data_t_" $i "_out  " $i "_out_int\[[string toupper $i]_OUT_LENGTH\];"
	puts $file $tmp_line
	unset tmp_line
}
puts $file ""
puts $file "	#endif"



puts $file ""


foreach i $input_vectors {

	puts $file "	#if FLOAT_FIX_[string toupper $i]_IN == 1"
	puts $file "	///////////////////////////////////////"
	puts $file "	//load input vectors from memory (DDR)"
	puts $file ""
	
	append tmp_line "	memcpy(" $i "_in,(const data_t_memory*)(memory_inout+byte_" $i "_in_offset/4),[string toupper $i]_IN_LENGTH*sizeof(data_t_memory));"
	puts $file $tmp_line
	unset tmp_line
	
	puts $file ""
	puts $file "    //Initialisation: cast to the precision used for the algorithm"

	puts $file "	input_cast_loop_$i:for (int i=0; i< [string toupper $i]_IN_LENGTH; i++)"
		append tmp_line "		" $i "_in_int\[i\]=(data_t_" $i "_in)" $i "_in\[i\];"
		puts $file $tmp_line
		unset tmp_line
		puts $file ""

	puts $file ""
	puts $file "	#elif FLOAT_FIX_[string toupper $i]_IN == 0"
	puts $file "	///////////////////////////////////////"
	puts $file "	//load input vectors from memory (DDR)"
	puts $file ""

		append tmp_line "	memcpy(" $i "_in_int,(const data_t_memory*)(memory_inout+byte_" $i "_in_offset/4),[string toupper $i]_IN_LENGTH*sizeof(data_t_memory));"
		puts $file $tmp_line
		unset tmp_line

	puts $file ""
	puts $file "	#endif"
	puts $file ""
	puts $file ""


}



puts $file ""
puts $file "	///////////////////////////////////////"
puts $file "	//USER algorithm function (foo_user.cpp) call"
puts $file "	//Input vectors are:"
foreach i $input_vectors {
	append tmp_line "	//" $i "_in_int\[[string toupper $i]_IN_LENGTH\] -> data type is data_t_" $i "_in"
	puts $file $tmp_line
	unset tmp_line
}
puts $file "	//Output vectors are:"
foreach i $output_vectors {
	append tmp_line "	//" $i "_out_int\[[string toupper $i]_OUT_LENGTH\] -> data type is data_t_" $i "_out"
	puts $file $tmp_line
	unset tmp_line
}

set m 0
foreach i $input_vectors {
	incr m
	if { $m == 1} {  
		append tmp_line "	foo_user_top: foo_user(	" 	$i "_in_int,"
		puts $file $tmp_line
		unset tmp_line
	} else {
	append tmp_line "							"	$i "_in_int,"
	puts $file $tmp_line
	unset tmp_line
	}
}
set m 0
foreach i $output_vectors {
	incr m
	if { $m == [llength $output_vectors]} {  
		append tmp_line "							" 	$i "_out_int);"
		puts $file $tmp_line
		unset tmp_line
	} else {
	append tmp_line "							"	$i "_out_int,"
	puts $file $tmp_line
	unset tmp_line
	}
}
puts $file ""
puts $file ""




set m 0
foreach i $output_vectors {

	puts $file "	#if FLOAT_FIX_[string toupper $i]_OUT == 1"
	puts $file "	///////////////////////////////////////"
	puts $file "	//store output vectors to memory (DDR)"
	puts $file ""
	puts $file "	output_cast_loop_$i: for(int i = 0; i <  [string toupper $i]_OUT_LENGTH; i++)"

	append tmp_line "		" $i "_out\[i\]=(data_t_interface_" $i "_out)" $i "_out_int\[i\];"
	puts $file $tmp_line
	unset tmp_line
	
	puts $file ""
	puts $file "	//write results vector y_out to DDR"
	append tmp_line "	memcpy((data_t_memory *)(memory_inout+byte_" $i "_out_offset/4)," $i "_out,[string toupper $i]_OUT_LENGTH*sizeof(data_t_memory));"
	puts $file $tmp_line
	unset tmp_line
	puts $file ""
	puts $file "	#elif FLOAT_FIX_[string toupper $i]_OUT == 0"
	

	puts $file "	///////////////////////////////////////"
	puts $file "	//write results vector y_out to DDR"
	
	append tmp_line "	memcpy((data_t_memory *)(memory_inout+byte_" $i "_out_offset/4)," $i "_out_int,[string toupper $i]_OUT_LENGTH*sizeof(data_t_memory));"
	puts $file $tmp_line
	unset tmp_line
	
	puts $file ""
	puts $file "	#endif"
	puts $file ""
	puts $file ""
	
	
}





puts $file ""
puts $file ""
puts $file "}"
close $file

return -code ok
}


# ########################################################################################
# make ip_design/src/foo_data.h  file

proc ::tclapp::icl::protoip::make_template::make_foo_data_h {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set project_name [lindex $args 0]

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
set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 


#create foo_data.h file
set file [open "ip_design/src/foo_data.h" w]


#add license_c header
[::tclapp::icl::protoip::make_template::license_c $file]

puts $file "#include <vector>"
puts $file "#include <iostream>"
puts $file "#include <stdio.h>"
puts $file "#include \"math.h\""
puts $file "#include \"ap_fixed.h\""
puts $file "#include <stdint.h>"
puts $file "#include <cstdlib>"
puts $file "#include <cstring>"
puts $file "#include <stdio.h>"
puts $file "#include <math.h>"
puts $file "#include <fstream>"
puts $file "#include <string>"
puts $file "#include <sstream>"
puts $file "#include <vector>"
puts $file ""
puts $file ""
puts $file "// Define FLOAT_FIX_VECTOR_NAME=1 to enable  fixed-point (up to 32 bits word length) arithmetic precision or "
puts $file "// FLOAT_FIX_VECTOR_NAME=0 to enable floating-point single arithmetic precision."

set m 0
foreach i $input_vectors {
	set tmp_line ""
	if { [lindex $input_vectors_type $m] == 1} {  
		append tmp_line "#define FLOAT_FIX_[string toupper $i]_IN 1"
	} else {  
		append tmp_line "#define FLOAT_FIX_[string toupper $i]_IN 0"
	}
	puts $file $tmp_line
	incr m
}

set m 0
foreach i $output_vectors {
	set tmp_line ""
	if { [lindex $output_vectors_type $m] == 1} {  
		append tmp_line "#define FLOAT_FIX_[string toupper $i]_OUT 1"
	} else {  
		append tmp_line "#define FLOAT_FIX_[string toupper $i]_OUT 0"
	}
	puts $file $tmp_line
	incr m
}



puts $file ""
puts $file "//Input vectors INTEGERLENGTH:"
set m 0
foreach i $input_vectors {
	set tmp_line ""
	append tmp_line "#define [string toupper $i]_IN_INTEGERLENGTH [lindex $input_vectors_integer_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file "//Output vectors INTEGERLENGTH:"
set m 0
foreach i $output_vectors {
	set tmp_line ""
	append tmp_line "#define [string toupper $i]_OUT_INTEGERLENGTH [lindex $output_vectors_integer_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file ""


puts $file ""
puts $file "//Input vectors FRACTIONLENGTH:"
set m 0
foreach i $input_vectors {
	set tmp_line ""
	append tmp_line "#define [string toupper $i]_IN_FRACTIONLENGTH [lindex $input_vectors_fraction_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file "//Output vectors FRACTIONLENGTH:"
set m 0
foreach i $output_vectors {
	set tmp_line ""
	append tmp_line "#define [string toupper $i]_OUT_FRACTIONLENGTH [lindex $output_vectors_fraction_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file ""




puts $file ""
puts $file "//Input vectors size:"
set m 0
foreach i $input_vectors {
	set tmp_line ""
	append tmp_line "#define [string toupper $i]_IN_LENGTH [lindex $input_vectors_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file "//Output vectors size:"
set m 0
foreach i $output_vectors {
	set tmp_line ""
	append tmp_line "#define [string toupper $i]_OUT_LENGTH [lindex $output_vectors_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file ""
puts $file ""

set m 0
foreach i $input_vectors_type {
	if ($i==1) {
		incr m
	}
}
foreach i $input_vectors_type {
	if ($i==1) {
		incr m
	}
}



puts $file ""
puts $file ""
if ($m==0) {
	puts $file "typedef float data_t_memory;"
} else {
	puts $file "typedef uint32_t data_t_memory;"
}
puts $file ""
puts $file ""


foreach i $input_vectors {
		set tmp_line ""	
		append tmp_line "#if FLOAT_FIX_[string toupper $i]_IN == 1"
		puts $file $tmp_line
		set tmp_line ""	
		append tmp_line "	typedef ap_fixed<[string toupper $i]_IN_INTEGERLENGTH+[string toupper $i]_IN_FRACTIONLENGTH,[string toupper $i]_IN_INTEGERLENGTH,AP_TRN_ZERO,AP_SAT> data_t_" $i "_in;"
		puts $file $tmp_line
		set tmp_line ""	
		append tmp_line "	typedef ap_fixed<32,32-[string toupper $i]_IN_FRACTIONLENGTH,AP_TRN_ZERO,AP_SAT> data_t_interface_" $i "_in;"
		puts $file $tmp_line
		set tmp_line ""	
		append tmp_line "#endif"
		puts $file $tmp_line
}



foreach i $input_vectors {
		set tmp_line ""
		append tmp_line "#if FLOAT_FIX_[string toupper $i]_IN == 0"
		puts $file $tmp_line
		set tmp_line ""
		append tmp_line "	typedef float data_t_" $i "_in;"
		puts $file $tmp_line
		set tmp_line ""
		append tmp_line "	typedef float data_t_interface_" $i "_in;"
		puts $file $tmp_line
		set tmp_line ""	
		append tmp_line "#endif"
		puts $file $tmp_line
}





foreach i $output_vectors {
		set tmp_line ""	
		append tmp_line "#if FLOAT_FIX_[string toupper $i]_OUT == 1 "
		puts $file $tmp_line
		set tmp_line ""	
		append tmp_line "	typedef ap_fixed<[string toupper $i]_OUT_INTEGERLENGTH+[string toupper $i]_OUT_FRACTIONLENGTH,[string toupper $i]_OUT_INTEGERLENGTH,AP_TRN_ZERO,AP_SAT> data_t_" $i "_out;"
		puts $file $tmp_line
		set tmp_line ""	
		append tmp_line "	typedef ap_fixed<32,32-[string toupper $i]_OUT_FRACTIONLENGTH,AP_TRN_ZERO,AP_SAT> data_t_interface_" $i "_out;"
		puts $file $tmp_line
		set tmp_line ""	
		append tmp_line "#endif"
		puts $file $tmp_line
}



foreach i $output_vectors {
		set tmp_line ""
		append tmp_line "#if FLOAT_FIX_[string toupper $i]_OUT == 0 "
		puts $file $tmp_line
		set tmp_line ""
		append tmp_line "	typedef float data_t_" $i "_out;"
		puts $file $tmp_line
		set tmp_line ""
		append tmp_line "	typedef float data_t_interface_" $i "_out;"
		puts $file $tmp_line
		set tmp_line ""	
		append tmp_line "#endif"
		puts $file $tmp_line
}







close $file

return -code ok
}



# ########################################################################################
# make ip_design/src/directives.tcl  file

proc ::tclapp::icl::protoip::make_template::make_directives {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:
  
set project_name [lindex $args 0]

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
set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 



set  file_name ""
append file_name "ip_design/src/" $project_name "_directives.tcl"

set file [open $file_name w]



puts $file "# ################################################################## "
set tmp_line ""
append tmp_line "# Directives used by Vivado HLS project " $project_name
puts $file $tmp_line
puts $file ""


set m 0
foreach i $input_vectors_length {
	set m [expr $m + $i]
	}
foreach i $output_vectors_length {
	set m [expr $m + $i]
	}
puts $file "# DDR3 memory m_axi interface directives"
puts $file "set_directive_interface -mode m_axi -depth [expr $m *1] \"foo\" memory_inout"
puts $file ""
puts $file "# IP core handling directives"
puts $file "set_directive_interface -mode s_axilite -bundle BUS_A \"foo\""
puts $file ""
puts $file "# Input vectors offset s_axilite interface directives"
foreach i $input_vectors {
	set tmp_line ""
	append tmp_line "set_directive_interface -mode s_axilite -register -bundle BUS_A \"foo\" byte\_" $i "_in_offset"
	puts $file $tmp_line
}
puts $file ""
puts $file "# Output vectors offset s_axilite interface directives"
foreach i $output_vectors {
	set tmp_line ""
	append tmp_line "set_directive_interface -mode s_axilite -register -bundle BUS_A \"foo\" byte\_" $i "_out_offset"
	puts $file $tmp_line

}
puts $file ""
puts $file "set_directive_inline -off \"foo_user\""
puts $file ""


puts $file "# pipeline the for loop named \"input_cast_loop_*\" in foo.cpp"
set count_i 0
foreach i $input_vectors {
	set tmp_line ""	
	append tmp_line "set_directive_pipeline \"foo/input_cast_loop_$i\""
	puts $file $tmp_line
	incr count_i
}
puts $file "# pipeline the for loop named \"output_cast_loop_*\" in foo.cpp"
set count_i 0
foreach i $output_vectors {
	set tmp_line ""	
	append tmp_line "set_directive_pipeline \"foo/output_cast_loop_$i\""
	puts $file $tmp_line
	incr count_i
}


close $file
return -code ok

}

# ########################################################################################
# make ip_design/src/directives.tcl  file

proc ::tclapp::icl::protoip::make_template::update_directives {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:
  
set project_name [lindex $args 0]

#load configuration parameters
set  file_name ""
append file_name ".metadata/" $project_name "_configuration_parameters.dat"
set fp [open $file_name r]
set file_data [read $fp]
close $fp
set data [split $file_data "\n"]

set num_input_vectors [lindex $data 3]
set num_output_vectors [lindex $data [expr ($num_input_vectors * 5) + 4 + 1]]

set input_vectors_length {}
set output_vectors_length {}

for {set i 0} {$i < $num_input_vectors} {incr i} {
	lappend input_vectors_length [lindex $data [expr 5 + ($i * 5)]]
}
for {set i 0} {$i < $num_output_vectors} {incr i} {
	lappend output_vectors_length [lindex $data [expr ($num_input_vectors * 5) + 4 + 3 + ($i * 5)]]
}




set  file_name ""
append file_name "ip_design/src/" $project_name "_directives.tcl"

set file [open $file_name r]
set file_data [read $file]
close $file


set data [split $file_data "\n"]
set count_line 0;
foreach line $data {
	if {[regexp {set_directive_interface -mode m_axi -depth} $line all value]} {
		break
	}
	incr count_line
}

puts $count_line


set count_data 0
foreach j $input_vectors_length {
	set count_data [expr $count_data + $j]
}
foreach j $output_vectors_length {
	set count_data [expr $count_data + $j]
}

set file [open $file_name w]

set m 0
foreach i $data {
	if {$m==$count_line} {
		puts $file "set_directive_interface -mode m_axi -depth [expr $count_data *1] \"foo\" memory_inout"
	} else {
		puts $file $i
		puts $i
	}
	incr m
}

close $file
return -code ok

}




# ########################################################################################
# make .metadata/project_name_ip_design_build.tcl file

proc ::tclapp::icl::protoip::make_template::make_ip_design_build_tcl {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set project_name [lindex $args 0]

set  file_name ""
append file_name ".metadata/" $project_name "_ip_design_build.tcl"

set file [open $file_name w]




puts $file ""
puts $file ""
puts $file "# ####################################################################################################################"
puts $file "# #################################################################################################################### "
puts $file "#  PROCEDURES"
puts $file "# #################################################################################################################### "
puts $file "# #################################################################################################################### "
puts $file ""
puts $file ""
puts $file "# ############################# "
puts $file "# procedure used to pass arguments to a tcl script (source: http://wiki.tcl.tk/10025)"
puts $file "proc src \{file args\} \{"
puts $file "  set argv \$::argv"
puts $file "  set argc \$::argc"
puts $file "  set ::argv \$args"
puts $file "  set ::argc \[llength \$args\]"
puts $file "  set code \[catch \{uplevel \[list source \$file\]\} return\]"
puts $file "  set ::argv \$argv"
puts $file "  set ::argc \$argc"
puts $file "  return -code \$code \$return"
puts $file "\}"
puts $file ""
puts $file ""
puts $file "# ####################################################################################################################"
puts $file "# #################################################################################################################### "
puts $file "#  BUILD"
puts $file "# #################################################################################################################### "
puts $file "# #################################################################################################################### "
puts $file ""
puts $file "# Project name"
set tmp_str ""
append tmp_str "set project_name \"" $project_name "\""
puts $file $tmp_str
puts $file "# ############################# "
puts $file "# #############################   "
puts $file "# Load configuration parameters"
puts $file ""
puts $file ""
puts $file "#load configuration parameters"
puts $file "set  file_name \"\""
puts $file "append file_name \".metadata/\" \$project_name \"_configuration_parameters.dat\""
puts $file "set fp \[open \$file_name r\]"
puts $file "set file_data \[read \$fp\]"
puts $file "close \$fp"
puts $file "set data \[split \$file_data \"\\n\"]"
puts $file ""
puts $file "set num_input_vectors \[lindex \$data 3]"
puts $file "set num_output_vectors \[lindex \$data \[expr (\$num_input_vectors * 5) + 4 + 1\]\]"
puts $file "set fclk \[lindex \$data \[expr (\$num_input_vectors * 5) + (\$num_output_vectors * 5) + 5 + 2\]\]"
puts $file "set FPGA_name \[lindex \$data \[expr (\$num_input_vectors * 5) + (\$num_output_vectors * 5) + 5 + 4\]\]" 
puts $file ""
puts $file "# ############################# "
puts $file "# ############################# "
puts $file "# Run Vivado HLS"
puts $file ""
puts $file "# Create a new project named \"project_name\""
puts $file "cd ip_design/build/prj"
puts $file "open_project -reset \$project_name"
puts $file "set_top foo"
puts $file ""
puts $file "# Add here below other files made by the user:"
puts $file "set filename \[format \"../../src/foo_data.h\"\] "
puts $file "add_files \$filename"
puts $file "set filename \[format \"../../src/foo_user.cpp\"\] "
puts $file "add_files \$filename"
puts $file "set filename \[format \"../../src/foo.cpp\"\] "
puts $file "add_files \$filename"
puts $file ""
puts $file "# compute circuit clock period in ns"
puts $file "set time \[ expr 1000/\$fclk\]"
puts $file ""
puts $file "# Configure the design"
puts $file "open_solution -reset \"solution1\""
puts $file "set FPGA_name_full \"\""
puts $file "append FPGA_name_full \"\{\" \$FPGA_name \"\}\""
puts $file "set_part \$FPGA_name_full"
puts $file "create_clock -period \$time -name default"
puts $file "# Configure implementation directives to build an optimized FPGA circuit"
puts $file "set directives_destination_name \"\""
puts $file "append directives_destination_name \"../../src/\" \$project_name \"_directives.tcl\""
puts $file "source \$directives_destination_name"
puts $file ""
puts $file "# Run design implementation"
puts $file "csynth_design"
puts $file "export_design -format ip_catalog -description \"Template IP generated by Andrea Suardi a.suardi@imperial.ac.uk\" -vendor \"icl.ac.uk\" -library \"hls\" -version \"1.0\""
puts $file ""
puts $file ""
puts $file "# close Vivado HLS project"
puts $file "close_solution"
puts $file "close_project"
puts $file ""
puts $file "cd .."
puts $file "cd .."
puts $file "cd .."
puts $file ""
puts $file "exit"
close $file

return -code ok

}



# ########################################################################################
# make .metadata/project_name_ip_design_test.tcl file

proc ::tclapp::icl::protoip::make_template::make_ip_design_test_tcl {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set project_name [lindex $args 0]

set  file_name ""
append file_name ".metadata/" $project_name "_ip_design_test.tcl"

set file [open $file_name w]




puts $file ""
puts $file ""
puts $file "# ####################################################################################################################"
puts $file "# #################################################################################################################### "
puts $file "#  PROCEDURES"
puts $file "# #################################################################################################################### "
puts $file "# #################################################################################################################### "
puts $file ""
puts $file ""
puts $file "# ############################# "
puts $file "# procedure used to pass arguments to a tcl script (source: http://wiki.tcl.tk/10025)"
puts $file "proc src \{file args\} \{"
puts $file "  set argv \$::argv"
puts $file "  set argc \$::argc"
puts $file "  set ::argv \$args"
puts $file "  set ::argc \[llength \$args\]"
puts $file "  set code \[catch \{uplevel \[list source \$file\]\} return\]"
puts $file "  set ::argv \$argv"
puts $file "  set ::argc \$argc"
puts $file "  return -code \$code \$return"
puts $file "\}"
puts $file ""
puts $file ""
puts $file "# ####################################################################################################################"
puts $file "# #################################################################################################################### "
puts $file "#  BUILD"
puts $file "# #################################################################################################################### "
puts $file "# #################################################################################################################### "
puts $file ""
puts $file "# Project name"
set tmp_str ""
append tmp_str "set project_name \"" $project_name "\""
puts $file $tmp_str
puts $file "# ############################# "
puts $file "# #############################   "
puts $file "# Load configuration parameters"
puts $file ""
puts $file ""
puts $file "#load configuration parameters"
puts $file "set  file_name \"\""
puts $file "append file_name \"../../.metadata/\" \$project_name \"_configuration_parameters.dat\""
puts $file "set fp \[open \$file_name r\]"
puts $file "set file_data \[read \$fp\]"
puts $file "close \$fp"
puts $file "set data \[split \$file_data \"\\n\"]"
puts $file ""
puts $file "set num_input_vectors \[lindex \$data 3]"
puts $file "set num_output_vectors \[lindex \$data \[expr (\$num_input_vectors * 5) + 4 + 1\]\]"
puts $file "set fclk \[lindex \$data \[expr (\$num_input_vectors * 5) + (\$num_output_vectors * 5) + 5 + 2\]\]"
puts $file "set FPGA_name \[lindex \$data \[expr (\$num_input_vectors * 5) + (\$num_output_vectors * 5) + 5 + 4\]\]" 
puts $file "set type_test \[lindex \$data \[expr (\$num_input_vectors * 5) + (\$num_output_vectors * 5) + 5 + 14\]\]"
puts $file "set input_vectors \{\}"
puts $file "for \{set i 0\} \{\$i < \$num_input_vectors\} \{incr i\} \{"
puts $file "    lappend input_vectors \[lindex \$data \[expr 4 + (\$i * 5)\]\]"
puts $file "\} "
puts $file "set output_vectors \{\}"
puts $file "for \{set i 0\} \{\$i < \$num_output_vectors\} \{incr i\} \{"
puts $file "    lappend output_vectors \[lindex \$data \[expr (\$num_input_vectors * 5) + 4 + 2 + (\$i * 5)\]\]"
puts $file "\}"
puts $file ""
puts $file "cd ../.."
puts $file ""
puts $file "# ############################# "
puts $file "# ############################# "
puts $file "# Run Vivado HLS"
puts $file ""
puts $file "# Create a new project named \"project_name\""
puts $file "cd ip_design/test/prj"
puts $file "open_project -reset \$project_name"
puts $file "set_top foo"
puts $file ""
puts $file "# Add here below other files made by the user:"
puts $file "set filename \[format \"../../src/foo_data.h\"\] "
puts $file "add_files \$filename"
puts $file "set filename \[format \"../../src/foo_user.cpp\"\] "
puts $file "add_files \$filename"
puts $file "set filename \[format \"../../src/foo.cpp\"\] "
puts $file "add_files \$filename"
puts $file ""
puts $file "# Add testbench files"
puts $file "set filename \[format \"../../src/foo_test.cpp\"\]" 
puts $file "add_files -tb \$filename"
puts $file "unset filename"
puts $file "foreach i \$input_vectors \{"
puts $file "	append tmp_name \"../stimuli/\" \$project_name \"/\" \$i \"_in.dat\" "
puts $file "	set filename \[format \$tmp_name\] "
puts $file "	add_files -tb \$filename"
puts $file "	unset filename"
puts $file "	unset tmp_name"
puts $file "\}"
puts $file ""	
puts $file "# compute circuit clock period in ns"
puts $file "set time \[ expr 1000/\$fclk\]"
puts $file ""
puts $file "# Configure the design"
puts $file "open_solution -reset \"solution1\""
puts $file "set FPGA_name_full \"\""
puts $file "append FPGA_name_full \"\{\" \$FPGA_name \"\}\""
puts $file "set_part \$FPGA_name_full"
puts $file "create_clock -period \$time -name default"
puts $file "# Configure implementation directives to build an optimized FPGA circuit"
puts $file "set directives_destination_name \"\""
puts $file "append directives_destination_name \"../../src/\" \$project_name \"_directives.tcl\""
puts $file "source \$directives_destination_name"
puts $file ""
puts $file "# Build and run design simulation"
puts $file "if \{\$type_test==1\} \{"
puts $file "	csim_design -clean"
puts $file "\} elseif \{\$type_test==2\} \{"
puts $file "	csynth_design"
puts $file "	cosim_design -trace_level all -rtl verilog -tool xsim"
puts $file "\} elseif \{\$type_test==3\} \{"
puts $file "	csynth_design"
puts $file "	cosim_design -trace_level all -rtl verilog -tool modelsim"
puts $file "\}"
puts $file ""
puts $file "# close Vivado HLS project"
puts $file "close_solution"
puts $file "close_project"
puts $file ""
puts $file ""
puts $file "foreach i \$output_vectors \{"
puts $file "	set source_file \"\""
puts $file "	set target_file \"\""
puts $file "	append source_file \$project_name \"/solution1/\""
puts $file "	if \{\$type_test==1\} \{"
puts $file "		append source_file \"csim/build/\" \$i \"_out.dat\"" 
puts $file "	\} elseif \{\$type_test==2\} \{"
puts $file "		append source_file \"sim/wrapc/\" \$i \"_out.dat\" "
puts $file "	\} elseif \{\$type_test==3\} \{"
puts $file "		append source_file \"sim/wrapc/\" \$i \"_out.dat\" "
puts $file "	\}"
puts $file "	append target_file \"../results/\" \$project_name \"/\" \$i \"_out.dat\" "
puts $file "	file copy -force \$source_file \$target_file"
puts $file ""
puts $file "\}"
puts $file ""
puts $file ""
puts $file "cd .."
puts $file "cd .."
puts $file "cd .."
puts $file ""
puts $file "exit"
close $file

return -code ok

}



# ########################################################################################
# make ip_design/src/foo_test.cpp  file

proc ::tclapp::icl::protoip::make_template::make_foo_test_cpp {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:
  
set project_name [lindex $args 0]

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
set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 


set file [open  ip_design/src/foo_test.cpp w]

#add license_c header
[::tclapp::icl::protoip::make_template::license_c $file]




puts $file "#include \"foo_data.h\""
puts $file ""
puts $file ""
puts $file ""
puts $file "void foo	(	"

foreach i $input_vectors {
	append tmp_line "				uint32_t byte_" $i "_in_offset,"
	puts $file $tmp_line
	unset tmp_line
}
foreach i $output_vectors {
	append tmp_line "				uint32_t byte_" $i "_out_offset,"
	puts $file $tmp_line
	unset tmp_line
}

puts $file "				volatile data_t_memory *memory_inout);"
puts $file ""
puts $file ""
puts $file "using namespace std;"
puts $file "#define BUF_SIZE 64"
puts $file ""
puts $file "//Input and Output vectors base addresses in the virtual memory"
set address_store_name "0"
set m 0
foreach i $input_vectors {
	
	append tmp_line "#define " $i "_IN_DEFINED_MEM_ADDRESS " $address_store_name
	puts $file $tmp_line
	unset tmp_line
	set address_store_name {(}
	for {set j 0} {$j <= $m} {incr j} {
		append address_store_name "[string toupper [lindex $input_vectors $j]]_IN_LENGTH"
		if {$j==$m} {
			append address_store_name ")*4"
		} else {
			append address_store_name "+"
		}
	}
	incr m
}
foreach i $output_vectors {
	append tmp_line "#define " $i "_OUT_DEFINED_MEM_ADDRESS " $address_store_name
	puts $file $tmp_line
	unset tmp_line
	set count_j 0
	set address_store_name {(}
	foreach j $input_vectors { 
		append address_store_name "[string toupper $j]_IN_LENGTH+"
		incr count_j
	}
	for {set j $count_j} {$j <= $m} {incr j} {
		append address_store_name "[string toupper [lindex $output_vectors [expr $j-$count_j]]]_OUT_LENGTH"
		if {$j==$m} {
			append address_store_name ")*4"
		} else {
			append address_store_name "+"
		}
	}
	incr m
}



puts $file ""
puts $file ""
puts $file "int main()"
puts $file "{"
puts $file ""
puts $file "	char filename\[BUF_SIZE\]={0};"
puts $file ""
puts $file "    int max_iter;"
puts $file ""
foreach i $input_vectors {
	append tmp_line "	uint32_t byte_" $i "_in_offset;"
	puts $file $tmp_line
	unset tmp_line
}
foreach i $output_vectors {
	append tmp_line "	uint32_t byte_" $i "_out_offset;"
	puts $file $tmp_line
	unset tmp_line
}
puts $file ""
puts $file "	int32_t tmp_value;"
puts $file ""
puts $file "	//assign the input/output vectors base address in the DDR memory"
foreach i $input_vectors {
	append tmp_line "	byte_" $i "_in_offset=" $i "_IN_DEFINED_MEM_ADDRESS;"
	puts $file $tmp_line
	unset tmp_line
}
foreach i $output_vectors {
	append tmp_line "	byte_" $i "_out_offset=" $i "_OUT_DEFINED_MEM_ADDRESS;"
	puts $file $tmp_line
	unset tmp_line
}
puts $file ""
puts $file "	//allocate a memory named address of uint32_t or float words. Number of words is 1024 * (number of inputs and outputs vectors)"
puts $file "	data_t_memory *memory_inout;"

set malloc_length "("
foreach i $input_vectors {
append malloc_length [string toupper $i] "_IN_LENGTH+"
}
set m 0
foreach i $output_vectors {
append malloc_length [string toupper $i] "_OUT_LENGTH"
if {$m ==[expr [llength $output_vectors] -1]} {
	append malloc_length ")*4);"
} else {
	append malloc_length "+"
}
incr m
}


append tmp_line "	memory_inout = (data_t_memory *)malloc(" $malloc_length " //malloc size should be sum of input and output vector lengths * 4 Byte"
puts $file $tmp_line
unset tmp_line
puts $file ""
puts $file "	FILE *stimfile;"
puts $file "	FILE * pFile;"
puts $file "	int count_data;"
puts $file ""	
puts $file ""
set m 0
foreach i $input_vectors {
	append tmp_line "	float *" $i "_in;"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	" $i "_in = (float *)malloc(" [string toupper $i] "_IN_LENGTH*sizeof (float));"
	puts $file $tmp_line
	unset tmp_line
	incr m
}
set m 0
foreach i $output_vectors {
	append tmp_line "	float *" $i "_out;"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	" $i "_out = (float *)malloc(" [string toupper $i] "_OUT_LENGTH*sizeof (float));"
	puts $file $tmp_line
	unset tmp_line
	incr m
}
puts $file ""
set m 0
foreach i $input_vectors {
	incr m
	puts $file ""
	puts $file "	////////////////////////////////////////"
	append tmp_line "	//read " $i "_in vector"
	puts $file $tmp_line
	unset tmp_line
	puts $file ""
	append tmp_line "	// Open stimulus " $i "_in.dat file for reading"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	sprintf(filename,\"" $i "_in.dat\");"
	puts $file $tmp_line
	unset tmp_line
	puts $file "	stimfile = fopen(filename, \"r\");"
	puts $file ""
	puts $file "	// read data from file"
	append tmp_line "	ifstream input" $m "(filename);"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	vector<float> myValues" $m ";"
	puts $file $tmp_line
	unset tmp_line
	puts $file ""
	puts $file "	count_data=0;"
	puts $file ""
	append tmp_line "	for (float f; input" $m " >> f; )"
	puts $file $tmp_line
	unset tmp_line
	puts $file "	{"
	append tmp_line "		myValues" $m ".push_back(f);"
	puts $file $tmp_line
	unset tmp_line
	puts $file "		count_data++;"
	puts $file "	}"
	
	puts $file ""
	puts $file "	//fill in input vector"
	puts $file "	for (int i = 0; i<count_data; i++)"
	puts $file "	{"
	puts $file "		if  (i < [string toupper $i]_IN_LENGTH) {"
	append tmp_line "			" $i "_in\[i\]=(float)myValues" $m "\[i]\;"
	puts $file $tmp_line
	unset tmp_line
	puts $file ""			
	puts $file "			#if FLOAT_FIX_[string toupper $i]_IN == 1"
	append tmp_line "				tmp_value=(int32_t)(" $i "_in\[i\]*(float)pow(2,([string toupper $i]_IN_FRACTIONLENGTH)));"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "				memory_inout\[i+byte_" $i "_in_offset/4\] = *(uint32_t*)&tmp_value;"
	puts $file $tmp_line
	unset tmp_line
	puts $file "			#elif FLOAT_FIX_[string toupper $i]_IN == 0"
	append tmp_line "				memory_inout\[i+byte_" $i "_in_offset/4\] = (float)" $i "_in\[i\];"
	puts $file $tmp_line
	unset tmp_line
	puts $file "			#endif"
	puts $file "		}"
	puts $file ""
	puts $file "	}"
	puts $file ""
}
puts $file ""
puts $file "	/////////////////////////////////////"
puts $file "	// foo c-simulation"
puts $file "	"
puts $file "	foo(	"
foreach i $input_vectors {
	append tmp_line "				byte_" $i "_in_offset,"
	puts $file $tmp_line
	unset tmp_line
}
foreach i $output_vectors {
	append tmp_line "				byte_" $i "_out_offset,"
	puts $file $tmp_line
	unset tmp_line
}
puts $file "				memory_inout);"
puts $file "	"
puts $file "	"
foreach i $output_vectors {
	puts $file "	/////////////////////////////////////"
	append tmp_line "	// read computed " $i "_out and store it as " $i "_out.dat"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	pFile = fopen (\"" $i "_out.dat\",\"w+\");"
	puts $file $tmp_line
	unset tmp_line
	puts $file ""
	puts $file "	for (int i = 0; i < [string toupper $i]_OUT_LENGTH; i++)"
	puts $file "	{"
	puts $file ""
	puts $file "		#if FLOAT_FIX_[string toupper $i]_OUT == 1"
	append tmp_line "			tmp_value=*(int32_t*)&memory_inout\[i+byte_" $i "_out_offset/4\];"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "			" $i "_out\[i\]=((float)tmp_value)/(float)pow(2,([string toupper $i]_OUT_FRACTIONLENGTH));"
	puts $file $tmp_line
	unset tmp_line
	puts $file "		#elif FLOAT_FIX_[string toupper $i]_OUT == 0"
	append tmp_line "			" $i "_out\[i\]=(float)memory_inout\[i+byte_" $i "_out_offset/4\];"
	puts $file $tmp_line
	unset tmp_line
	puts $file "		#endif"
	puts $file "		"
	append tmp_line "		fprintf(pFile,\"%f \\n \"," $i "_out\[i\]);"
	puts $file $tmp_line
	unset tmp_line
	puts $file ""
	puts $file "	}"
	puts $file "	fprintf(pFile,\"\\n\");"
	puts $file "	fclose (pFile);"
	puts $file "		"
}

puts $file ""
puts $file "	return 0;"
puts $file "}"

close $file
return -code ok

}


# ########################################################################################
# make ip_design/src/write_stimulus.m  file


proc ::tclapp::icl::protoip::make_template::make_write_stimulus_m {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:
  
set input_vectors [lindex $args 0]
set input_vectors_length [lindex $args 1]
set output_vectors [lindex $args 2]
set output_vectors_length [lindex $args 3]

set file [open  ip_design/src/write_stimulus.m w]

#add license_m header
[::tclapp::icl::protoip::make_template::license_m $file]


puts $file "function write_testbench(num_simulation,sim_type)"
puts $file ""
puts $file ""
puts $file "tmp_str=strcat('Writing stimulus files set ', num2str(num_simulation));"
puts $file "disp(tmp_str);"
puts $file ""
set m 0
foreach i $input_vectors {
	append tmp_line "[string toupper [lindex $input_vectors $m]]_IN_LENGTH=[lindex $input_vectors_length $m];"
	puts $file $tmp_line
	unset tmp_line
	incr m
}
set m 0
foreach i $output_vectors {
	append tmp_line "[string toupper [lindex $output_vectors $m]]_OUT_LENGTH=[lindex $output_vectors_length $m];"
	puts $file $tmp_line
	unset tmp_line
	incr m
}
puts $file ""
puts $file "rng('shuffle');"


# generate random stimulus vectors
set m 0
foreach i $input_vectors {

	puts $file ""
	puts $file "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	append tmp_line "% generate random stimulus vector " $i "_in. (-5<=" $i "_in <=5)"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line $i "_in=rand(1,[string toupper [lindex $input_vectors $m]]_IN_LENGTH)*10-5;"
	puts $file $tmp_line
	unset tmp_line
	incr m

}

puts $file ""
puts $file ""
puts $file ""
puts $file ""

# save the random stimulus vectors
foreach i $input_vectors {

	# save generated random stimulus vectors. This vector will be loaded by the simulator
	puts $file ""
	puts $file ""
	puts $file "	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	append tmp_line "% write " $i "_in.dat to file"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "filename = strcat('" $i "_in.dat');"
	puts $file $tmp_line
	unset tmp_line
	puts $file "fid = fopen(filename, 'w+');"
	puts $file "   "
	append tmp_line "for j=1:length(" $i "_in)"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	fprintf(fid, '%2.18f\\n'," $i "_in(j));"
	puts $file $tmp_line
	unset tmp_line
	puts $file "end"
	puts $file ""
	puts $file "fclose(fid);"
	
	# save generated random stimulus vectors logs
	puts $file ""
	puts $file "	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	append tmp_line "%save " $i "_in_log"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "filename = strcat('../', sim_type, '/results/" $i "_in_log.dat');"
	puts $file $tmp_line
	unset tmp_line
	puts $file "fid = fopen(filename, 'a+');"
	puts $file "   "
	append tmp_line "for j=1:length(" $i "_in)"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	fprintf(fid, '%2.18f,'," $i "_in(j));"
	puts $file $tmp_line
	unset tmp_line
	puts $file "end"
	puts $file "	fprintf(fid, '\\n');"
	puts $file ""
	puts $file "fclose(fid);"

}



puts $file ""
puts $file ""
puts $file ""
puts $file "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
puts $file "%write a dummy file to tell tcl script to continue with the execution"
puts $file ""
puts $file "filename = strcat('_locked');"
puts $file "fid = fopen(filename, 'w');"
puts $file "fprintf(fid, 'locked write\\n');"
puts $file "fclose(fid);"
puts $file ""
puts $file "quit;"
puts $file ""
puts $file "end"

close $file
return -code ok

}



# ########################################################################################
# make ip_design/src/read_results.m  file

proc ::tclapp::icl::protoip::make_template::read_results_m {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:
  
set input_vectors [lindex $args 0]
set input_vectors_length [lindex $args 1]
set output_vectors [lindex $args 2]
set output_vectors_length [lindex $args 3]

set file [open  ip_design/src/read_results.m w]

#add license_m header
[::tclapp::icl::protoip::make_template::license_m $file]



puts $file "function read_results(num_simulation,sim_type)"
puts $file ""
puts $file ""
puts $file "tmp_str=strcat('Reading simulation result set  ', num2str(num_simulation));"
puts $file "disp(tmp_str);"
puts $file ""
set m 0
foreach i $input_vectors {
	append tmp_line "[string toupper [lindex $input_vectors $m]]_IN_LENGTH=[lindex $input_vectors_length $m];"
	puts $file $tmp_line
	unset tmp_line
	incr m
}
set m 0
foreach i $output_vectors {
	append tmp_line "[string toupper [lindex $output_vectors $m]]_OUT_LENGTH=[lindex $output_vectors_length $m];"
	puts $file $tmp_line
	unset tmp_line
	incr m
}


# read random stimulus vectors
foreach i $input_vectors {

	puts $file ""
	puts $file "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	append tmp_line "% read random stimulus vector " $i "_in."
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "load " $i "_in.dat;"
	puts $file $tmp_line
	unset tmp_line
}

puts $file ""
puts $file ""


# read FPGA simulation results and save the log
foreach i $output_vectors {

	puts $file ""
	puts $file "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	append tmp_line "% read simulation results " $i "_out."
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "load " $i "_out.dat;"
	puts $file $tmp_line
	unset tmp_line
	
	# save FPGA simulation results logs
	puts $file ""
	append tmp_line "	%save " $i "_out_log"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	filename = strcat('../', sim_type, '/results/fpga_" $i "_out_log.dat');"
	puts $file $tmp_line
	unset tmp_line
	puts $file "	fid = fopen(filename, 'a+');"
	puts $file "   "
	append tmp_line "	for j=1:length(" $i "_out)"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "		fprintf(fid, '%2.18f,'," $i "_out(j));"
	puts $file $tmp_line
	unset tmp_line
	puts $file "	end"
	puts $file "	fprintf(fid, '\\n');"
	puts $file ""
	puts $file "	fclose(fid);"
	puts $file ""
	puts $file ""
}

# compute Matlab (floating point double precision) simulation results

set count_i 0
foreach i $output_vectors {

	puts $file ""
	puts $file "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	append tmp_line "% compute with Matlab and save in a file simulation results " $i "_out"
	puts $file $tmp_line
	unset tmp_line

puts $file "for i=1:[string toupper $i]_OUT_LENGTH"



	append tmp_line "	matlab_" $i "_out(i)="
	set m 0
	foreach j $input_vectors {
		for {set jj 1} {$jj <= [lindex $input_vectors_length $m]} {incr jj} {
			if { $m ==[expr [llength $input_vectors] -1] && $jj== [lindex $input_vectors_length $m]} {  
				append tmp_line $j "_in([expr $jj]);"
			} else {
				append tmp_line $j "_in([expr $jj])+"
			}
		}
		incr m
	}
	puts $file $tmp_line
	unset tmp_line

puts $file "end"
puts $file ""
incr count_i


# save generated random stimulus vectors logs
	puts $file ""
	puts $file "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	append tmp_line "%save " $i "_in_log"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "filename = strcat('../', sim_type, '/results/matlab_" $i "_out_log.dat');"
	puts $file $tmp_line
	unset tmp_line
	puts $file "fid = fopen(filename, 'a+');"
	puts $file ""
	append tmp_line "for j=1:length(matlab_" $i "_out)"
	puts $file $tmp_line
	unset tmp_line
	append tmp_line "	fprintf(fid, '%2.18f,',matlab_" $i "_out(j));"
	puts $file $tmp_line
	unset tmp_line
	puts $file "end"
	puts $file "fprintf(fid, '\\n');"
	puts $file ""
	puts $file "fclose(fid);"
	
	
}



puts $file ""
puts $file ""
puts $file ""
puts $file "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
puts $file "%write a dummy file to tell tcl script to continue with the execution"
puts $file ""
puts $file "filename = strcat('_locked');"
puts $file "fid = fopen(filename, 'w');"
puts $file "fprintf(fid, 'locked write\\n');"
puts $file "fclose(fid);"
puts $file ""
puts $file "quit;"
puts $file ""
puts $file "end"


close $file
return -code ok

}


# ########################################################################################
# make ip_design/src/foo_user.m  file

proc ::tclapp::icl::protoip::make_template::make_foo_user_m {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:
  
  set project_name [lindex $args 0]

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
set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 
set file [open  ip_design/src/foo_user.m w]

#add license_m header
[::tclapp::icl::protoip::make_template::license_m $file]



set tmp_line "function \["
set m 0
foreach i $output_vectors {
	if { $m ==[expr [llength $output_vectors] -1] } {
		append tmp_line $i "_out_int\] = foo_user(project_name,"
	} else {
		append tmp_line $i "_out_int, "
	}
	incr m
}
set m 0
foreach i $input_vectors {
	if { $m ==[expr [llength $input_vectors] -1] } {
		append tmp_line $i "_in_int)"
	} else {
		append tmp_line $i "_in_int, "
	}
	incr m
}

puts $file $tmp_line
puts $file ""
puts $file ""
puts $file "	% load project configuration parameters: input and output vectors (name, size, type, NUM_TEST, TYPE_TEST)"
puts $file "	load_configuration_parameters(project_name);"
puts $file ""


# compute Matlab (floating point double precision) simulation results

# set count_i 0
# foreach i $output_vectors {

	# puts $file "	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	# set tmp_line ""
	# append tmp_line "	% compute with Matlab and save in a file simulation results " $i "_out_int"
	# puts $file $tmp_line
	# unset tmp_line

# puts $file "	for i=1:[string toupper $i]_OUT_LENGTH"



	# append tmp_line "		" $i "_out_int(i)="
	# set m 0
	# foreach j $input_vectors {
		# for {set jj 1} {$jj <= [lindex $input_vectors_length $m]} {incr jj} {
			# if { $m ==[expr [llength $input_vectors] -1] && $jj== [lindex $input_vectors_length $m]} {  
				# append tmp_line $j "_in_int([expr $jj]);"
			# } else {
				# append tmp_line $j "_in_int([expr $jj])+"
			# }
		# }
		# incr m
	# }
	# puts $file $tmp_line
	# unset tmp_line

# puts $file "	end"
# puts $file ""
# puts $file ""

# }


set count_i 0
foreach i $output_vectors {

puts $file "	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
set tmp_line ""
append tmp_line "	% compute with Matlab and save in a file simulation results " $i "_out_int"
puts $file $tmp_line
unset tmp_line

puts $file "	for i=1:[string toupper $i]_OUT_LENGTH"


set tmp_line ""
append tmp_line "		" $i "_out_int(i)=0;"
puts $file $tmp_line
foreach j $input_vectors {
	
puts $file "		for i_$j = 1:[string toupper $j]_IN_LENGTH"		
set tmp_line ""
append tmp_line "			" $i "_out_int(i)=" $i "_out_int(i) + " $j "_in_int(i_" $j ");"
puts $file $tmp_line
puts $file "		end"	

	}

puts $file "	end"
puts $file ""
incr count_i
}


puts $file "end"



puts $file ""



close $file
return -code ok

}







# ########################################################################################
# make ip_prototype/src/interface_library.h file

proc ::tclapp::icl::protoip::make_template::make_interface_library_h {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set input_vectors [lindex $args 0]
set input_vectors_length [lindex $args 1]
set output_vectors [lindex $args 2]
set output_vectors_length [lindex $args 3]
set float_fix [lindex $args 4]
set bits_word_integer_length [lindex $args 5]
set bits_word_fraction_length [lindex $args 6]
set type_eth [lindex $args 7]
set mem_base_address [lindex $args 8]


set file [open ip_prototype/src/interface_library.h w]


#add license_c header
[::tclapp::icl::protoip::make_template::license_c $file]

puts $file ""
puts $file "////////////////////////////////////////////////////////////"
puts $file "//Ethernet interface configuration (UDP or TCP)"
if { $type_eth == 1} { 
puts $file "#define TYPE_ETH 1 //1 for TCP, 0 for UDP"
} elseif  { $type_eth == 0} { 
puts $file "#define TYPE_ETH 0 //1 for TCP, 0 for UDP"
}
puts $file "#define FPGA_IP \"192.168.1.10\" //FPGA IP"
puts $file "#define FPGA_NM \"255.255.255.0\" //Netmask"
puts $file "#define FPGA_GW \"192.168.1.1\" //Gateway"
puts $file "#define FPGA_PORT 2007"
puts $file "#define DEBUG 0 //1 to enable debug printf, 0 to disable debug printf"
puts $file ""
puts $file "//Set design arithmetic precision (every variable is represented with the same precision)"
append tmp_line "#define FLOAT_FIX " $float_fix "// set 0=FLOAT (floating-point single precision), 1=FIX (fixed-point up to 32 bits word length)"
puts $file $tmp_line
unset tmp_line
puts $file ""
puts $file "//ONLY if FIXED-POINT, define how many bit to use to"
puts $file "//represent the integer and the fraction part  "
puts $file "//REMARK1: make attention when choosing the integer length because overflow can occur."
puts $file "//REMARK2: maximum word length size (bits_word_integer_length+bits_word_fraction_length) is 32, minimum integer length size is 1"
puts $file "//- define how many bits use to represent the integer length (INTEGERLENGTH) "
append tmp_line "#define INTEGERLENGTH " $bits_word_integer_length
puts $file $tmp_line
unset tmp_line
puts $file "//- define how many bits use to represent the fraction length (FRACTIONLENGTH) "
append tmp_line "#define FRACTIONLENGTH " $bits_word_fraction_length
puts $file $tmp_line
unset tmp_line
puts $file ""
puts $file ""
puts $file "//Input vectors size:"
set m 0
foreach i $input_vectors {
	append tmp_line "#define [string toupper $i]_IN_LENGTH [lindex $input_vectors_length $m]"
	puts $file $tmp_line
	unset tmp_line
	incr m
}
set m 0
foreach i $output_vectors {
	append tmp_line "#define [string toupper $i]_OUT_LENGTH [lindex $output_vectors_length $m]"
	puts $file $tmp_line
	unset tmp_line
	incr m
}
puts $file ""
puts $file ""
puts $file "//FPGA vectors memory maps"

set address_store_name "0"
set m 0
foreach i $input_vectors {
	
	append tmp_line "#define " $i "_IN_DEFINED_MEM_ADDRESS " $address_store_name
	puts $file $tmp_line
	unset tmp_line
	set address_store_name "[expr ($mem_base_address/256)*256]+("
	for {set j 0} {$j <= $m} {incr j} {
		append address_store_name "[string toupper [lindex $input_vectors $j]]_IN_LENGTH"
		if {$j==$m} {
			append address_store_name ")*4"
		} else {
			append address_store_name "+"
		}
	}
	incr m
}
foreach i $output_vectors {
	append tmp_line "#define " $i "_OUT_DEFINED_MEM_ADDRESS " $address_store_name
	puts $file $tmp_line
	unset tmp_line
	set count_j 0
	set address_store_name "[expr ($mem_base_address/256)*256]+("
	foreach j $input_vectors { 
		append address_store_name "[string toupper $j]_IN_LENGTH+"
		incr count_j
	}
	for {set j $count_j} {$j <= $m} {incr j} {
		append address_store_name "[string toupper [lindex $output_vectors [expr $j-$count_j]]]_OUT_LENGTH"
		if {$j==$m} {
			append address_store_name ")*4"
		} else {
			append address_store_name "+"
		}
	}
	incr m
}


puts $file ""
puts $file ""
puts $file "///////////////////////////////////////////////////////////////"
puts $file "//////////////////DO NOT EDIT HERE BELOW///////////////////////"
puts $file "//FPGA interface data specification:"
puts $file "#define ETH_PACKET_LENGTH 256+2 //Ethernet packet length in double words (32 bits) (from Matlab to  FPGA)"
puts $file "#define ETH_PACKET_LENGTH_RECV 64+2 //Ethernet packet length in double words (32 bits) (from FPGA to Matlab)"





close $file
return -code ok

}



# ########################################################################################
# make ip_design/src/test_HIL.m file

proc ::tclapp::icl::protoip::make_template::make_test_HIL_m {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:


set project_name [lindex $args 0]

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
set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 



set file [open ip_design/src/test_HIL.m w]


#add license_c header
[::tclapp::icl::protoip::make_template::license_m $file]



puts $file ""
puts $file "function test_HIL(project_name)"
puts $file ""
puts $file ""
puts $file "addpath('../../.metadata');"
puts $file "mex FPGAclientMATLAB.c"
set tmp_line ""
append tmp_line "load_configuration_parameters(project_name)"
puts $file $tmp_line
puts $file ""



puts $file ""
puts $file "rng('shuffle');"
puts $file ""
puts $file "for i=1:NUM_TEST"

	puts $file "	tmp_disp_str=strcat('Test number ',num2str(i));"
	puts $file "	disp(tmp_disp_str)"

	# generate and save in a file the random stimulus vectors
	set m 0
	foreach i $input_vectors {

		puts $file ""
		puts $file ""
		puts $file "	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
		set tmp_line ""
		append tmp_line "	%% generate random stimulus vector " $i "_in. (-5<=" $i "_in <=5)"
		puts $file $tmp_line
		unset tmp_line
		append tmp_line "	" $i "_in=rand(1,[string toupper [lindex $input_vectors $m]]_IN_LENGTH)*10-5;"
		puts $file $tmp_line
		unset tmp_line
		incr m
		
		
		# save generated random stimulus vectors logs
		puts $file ""
		puts $file "	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
		append tmp_line "	%save " $i "_in_log"
		puts $file $tmp_line
		unset tmp_line
		puts $file "	if (TYPE_TEST==0)"
		set tmp_line ""
		append tmp_line "		filename = strcat('../../ip_prototype/test/results/', project_name ,'/" $i "_in_log.dat');"
		puts $file $tmp_line
		puts $file "	else"
		set tmp_line ""
		append tmp_line "		filename = strcat('../test/results/', project_name ,'/" $i "_in_log.dat');"
		puts $file $tmp_line	
		puts $file "	end"
		set tmp_line ""
		unset tmp_line
		puts $file "	fid = fopen(filename, 'a+');"
		puts $file "   "
		append tmp_line "	for j=1:length(" $i "_in)"
		puts $file $tmp_line
		unset tmp_line
		append tmp_line "		fprintf(fid, '%2.18f,'," $i "_in(j));"
		puts $file $tmp_line
		unset tmp_line
		puts $file "	end"
		puts $file "	fprintf(fid, '\\n');"
		puts $file ""
		puts $file "	fclose(fid);"
		
	}

	puts $file ""
	puts $file ""
	puts $file "	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	puts $file "	%% Start Matlab timer"
	puts $file "	tic"
	puts $file ""
	puts $file "	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	puts $file "	%% send the stimulus to the FPGA simulation model when IP design test or to FPGA evaluation borad when IP prototype, execute the algorithm and read back the results"
	
	# rest IP
	puts $file "	% reset IP"

	puts $file "	Packet_type=1; % 1 for reset, 2 for start, 3 for write to IP vector packet_internal_ID, 4 for read from IP vector packet_internal_ID of size packet_output_size"
	puts $file "	packet_internal_ID=0;"
	puts $file "	packet_output_size=1;"
	puts $file "	data_to_send=1;"
	puts $file "	FPGAclientMATLAB(data_to_send,Packet_type,packet_internal_ID,packet_output_size);"

	# send input vectors to FPGA
	puts $file ""
	puts $file ""
	puts $file "	% send data to FPGA"
	set m 0
	foreach i $input_vectors {
		append tmp_line "	% send " $i "_in"
		puts $file $tmp_line
		unset tmp_line
		
		puts $file "	Packet_type=3; % 1 for reset, 2 for start, 3 for write to IP vector packet_internal_ID, 4 for read from IP vector packet_internal_ID of size packet_output_size"
		append tmp_line "	packet_internal_ID=" $m ";"
		puts $file $tmp_line
		unset tmp_line
		puts $file "	packet_output_size=1;"
		append tmp_line "	data_to_send=" $i "_in;"
		puts $file $tmp_line
		unset tmp_line
		puts $file "	FPGAclientMATLAB(data_to_send,Packet_type,packet_internal_ID,packet_output_size);"
		incr m
		puts $file ""
	}
	
	# Start FPGA
	puts $file ""
	puts $file "	% start FPGA"

	puts $file "	Packet_type=2; % 1 for reset, 2 for start, 3 for write to IP vector packet_internal_ID, 4 for read from IP vector packet_internal_ID of size packet_output_size"
	puts $file "	packet_internal_ID=0;"
	puts $file "	packet_output_size=1;"
	puts $file "	data_to_send=0;"
	puts $file "	FPGAclientMATLAB(data_to_send,Packet_type,packet_internal_ID,packet_output_size);"

	# read data from FPGA
	puts $file ""
	puts $file ""
	puts $file "	% read data from FPGA"

	set m 0
	foreach i $output_vectors {
		append tmp_line "	% read fpga_" $i "_out"
		puts $file $tmp_line
		unset tmp_line
		
		puts $file "	Packet_type=4; % 1 for reset, 2 for start, 3 for write to IP vector packet_internal_ID, 4 for read from IP vector packet_internal_ID of size packet_output_size"
		append tmp_line "	packet_internal_ID=" $m ";"
		puts $file $tmp_line
		unset tmp_line
		append tmp_line "	packet_output_size=[string toupper [lindex $output_vectors $m]]_OUT_LENGTH;"
		puts $file $tmp_line
		unset tmp_line
		puts $file "	data_to_send=0;"
		puts $file "	\[output_FPGA, time_IP\] = FPGAclientMATLAB(data_to_send,Packet_type,packet_internal_ID,packet_output_size);"
		append tmp_line "	fpga_" $i "_out=output_FPGA;"
		puts $file $tmp_line
		unset tmp_line
		incr m
	
	}
	
	puts $file "	% Stop Matlab timer"
	puts $file "	time_matlab=toc;"
	puts $file "	time_communication=time_matlab-time_IP;"
	puts $file ""
		
	set m 0
	foreach i $output_vectors {
		
		# save FPGA test results logs
		puts $file ""
		set tmp_line ""
		append tmp_line "	%save fpga_" $i "_out_log.dat"
		puts $file $tmp_line
		unset tmp_line
		puts $file "	if (TYPE_TEST==0)"
		set tmp_line ""
		append tmp_line "		filename = strcat('../../ip_prototype/test/results/', project_name ,'/fpga_" $i "_out_log.dat');"
		puts $file $tmp_line
		puts $file "	else"
		set tmp_line ""
		append tmp_line "		filename = strcat('../test/results/', project_name ,'/fpga_" $i "_out_log.dat');"
		puts $file $tmp_line	
		puts $file "	end"
		set tmp_line ""
		puts $file "	fid = fopen(filename, 'a+');"
		puts $file "   "
		append tmp_line "	for j=1:length(fpga_" $i "_out)"
		puts $file $tmp_line
		unset tmp_line
		append tmp_line "		fprintf(fid, '%2.18f,',fpga_" $i "_out(j));"
		puts $file $tmp_line
		unset tmp_line
		puts $file "	end"
		puts $file "	fprintf(fid, '\\n');"
		puts $file ""
		puts $file "	fclose(fid);"
		puts $file ""
		puts $file ""
	
	}
	
		puts $file ""
		set tmp_line ""
		append tmp_line "	%save fpga_time_log.dat"
		puts $file $tmp_line
		unset tmp_line
		puts $file "	if (TYPE_TEST==0)"
		set tmp_line ""
		append tmp_line "		filename = strcat('../../ip_prototype/test/results/', project_name ,'/fpga_time_log.dat');"
		puts $file $tmp_line
		puts $file "	else"
		set tmp_line ""
		append tmp_line "		filename = strcat('../test/results/', project_name ,'/fpga_time_log.dat');"
		puts $file $tmp_line	
		puts $file "	end"
		set tmp_line ""
		puts $file "	fid = fopen(filename, 'a+');"
		puts $file "   "
		unset tmp_line
		append tmp_line "	fprintf(fid, '%2.18f, %2.18f \\n',time_IP, time_communication);"
		puts $file $tmp_line
		unset tmp_line
	
		puts $file ""
		puts $file "	fclose(fid);"
		puts $file ""
		puts $file ""

	
	set tmp_line ""
	puts $file "	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
	puts $file "	%% compute with Matlab and save in a file simulation results"
	set tmp_line ""
	
	set tmp_line "	\["
	set m 0
	foreach i $output_vectors {
		if { $m ==[expr [llength $output_vectors] -1] } {
			append tmp_line "matlab_" $i "_out\] = foo_user(project_name,"
		} else {
			append tmp_line "matlab_" $i "_out, "
		}
		incr m
	}
	set m 0
	foreach i $input_vectors {
		if { $m ==[expr [llength $input_vectors] -1] } {
			append tmp_line $i "_in);"
		} else {
			append tmp_line $i "_in, "
		}
		incr m
	}

	puts $file $tmp_line
	puts $file ""
	set tmp_line ""
	
		
		# save Matlab simulation results logs
		set m 0
		foreach i $output_vectors {
	
			puts $file ""
			append tmp_line "	%save matlab_" $i "_out_log"
			puts $file $tmp_line
			puts $file "	if (TYPE_TEST==0)"
			set tmp_line ""
			append tmp_line "		filename = strcat('../../ip_prototype/test/results/', project_name ,'/matlab_" $i "_out_log.dat');"
			puts $file $tmp_line
			puts $file "	else"
			set tmp_line ""
			append tmp_line "		filename = strcat('../test/results/', project_name ,'/matlab_" $i "_out_log.dat');"
			puts $file $tmp_line	
			puts $file "	end"
			set tmp_line ""
			unset tmp_line
			puts $file "	fid = fopen(filename, 'a+');"
			puts $file "   "
			append tmp_line "	for j=1:length(matlab_" $i "_out)"
			puts $file $tmp_line
			unset tmp_line
			append tmp_line "		fprintf(fid, '%2.18f,',matlab_" $i "_out(j));"
			puts $file $tmp_line
			unset tmp_line
			puts $file "	end"
			puts $file "	fprintf(fid, '\\n');"
			puts $file ""
			puts $file "	fclose(fid);"
			puts $file ""


		}
	
puts $file "end"

puts $file ""
puts $file ""
puts $file ""
puts $file "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
puts $file "%write a dummy file to tell tcl script to continue with the execution"
puts $file ""
puts $file "filename = strcat('_locked');"
puts $file "fid = fopen(filename, 'w');"
puts $file "fprintf(fid, 'locked write\\n');"
puts $file "fclose(fid);"
puts $file ""
puts $file "if strcmp(TYPE_DESIGN_FLOW,'vivado')"
puts $file "	quit;"
puts $file "end"
puts $file ""
puts $file "end"


close $file
return -code ok

}



# ########################################################################################
# make ip_prototype/src/echo.c file
proc ::tclapp::icl::protoip::make_template::make_echo_c {args} {

  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:


set project_name [lindex $args 0]

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
set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 



set file [open ip_prototype/src/echo.c w]


#add license_c header
[::tclapp::icl::protoip::make_template::license_c $file]


puts $file "#include <stdio.h>"
puts $file "#include <string.h>"
puts $file ""
puts $file "#include \"lwip/err.h\""
puts $file "#include \"lwip/tcp.h\""
puts $file "#include \"lwip/udp.h\""
puts $file "#ifdef __arm__"
puts $file "#include \"xil_printf.h\""
puts $file "#endif"
puts $file "#include <stdint.h>"
puts $file ""
puts $file "#include \"xil_cache.h\""
puts $file "#include \"xparameters.h\""
puts $file "#include \"xparameters_ps.h\"	/* defines XPAR values */"
puts $file "#include \"xstatus.h\""
puts $file "#include \"xil_io.h\""
puts $file "#include \"xscutimer.h\""
puts $file "#include \"platform_config.h\""
puts $file ""
puts $file "#include \"xfoo.h\""
puts $file "#include \"FPGAserver.h\""
puts $file ""

puts $file "#define TIMER_DEVICE_ID		XPAR_XSCUTIMER_0_DEVICE_ID"
puts $file "#define TIMER_LOAD_VALUE	0xFFFFFFE"
puts $file "#define TIMER_RES_DIVIDER 	40"
puts $file "#define NSECS_PER_SEC 		667000000/2"
puts $file "#define EE_TICKS_PER_SEC 	(NSECS_PER_SEC / TIMER_RES_DIVIDER)"
puts $file ""
puts $file "typedef uint32_t           Xint32;     /**< signed 32-bit */"
puts $file ""
puts $file ""
puts $file "//define as global variables"
puts $file "XFoo xcore;"
puts $file "XFoo_Config config;"
puts $file "XScuTimer Timer;"
puts $file ""
puts $file "unsigned int CntValue1 = 0;"
puts $file "unsigned int CntValue2 = 0;"
puts $file ""

foreach i $input_vectors {

	set tmp_line ""
	append tmp_line "Xint32 *" $i "_in_ptr_ddr = (Xint32 *)" $i "_IN_DEFINED_MEM_ADDRESS;"
	puts $file $tmp_line
}

foreach i $output_vectors {

	set tmp_line ""
	append tmp_line "Xint32 *" $i "_out_ptr_ddr = (Xint32 *)" $i "_OUT_DEFINED_MEM_ADDRESS;"
	puts $file $tmp_line
}

puts $file ""
puts $file "/* Variables used for handling the packet */"
puts $file "uint8_t *payload_ptr;		/* Payload pointer */"
puts $file "Xint32   payload_temp;		/* 32-bit interpretation of payload */"
puts $file "uint8_t *payload_temp_char = (uint8_t *)&payload_temp;  /* Char interpretation of payload */"
puts $file ""
puts $file "Xint32 inputvec\[ETH_PACKET_LENGTH\];"
puts $file "Xint32 outvec\[ETH_PACKET_LENGTH\];"
puts $file "int32_t inputvec_fix\[ETH_PACKET_LENGTH\];"
puts $file "int32_t outvec_fix\[ETH_PACKET_LENGTH\];"
puts $file ""
puts $file "unsigned int write_offset;"
puts $file "int packet_internal_ID_previous;"
puts $file ""
puts $file ""
puts $file "int transfer_data() \{"
puts $file "	return 0;"
puts $file "\}"
puts $file ""
puts $file ""

puts $file "void print_app_header()"
puts $file "\{"
puts $file "	xil_printf(\"\\n\\r\");"
puts $file "	xil_printf(\"\\n\\r\");"
puts $file "	xil_printf(\"---------------------------- ICL::PROTOIP-----------------------------------\\n\\r\");"
puts $file "	xil_printf(\"------------------- (FPGA UPD/IP and TCP/IP server) ------------------------\\n\\r\");"
puts $file "	xil_printf(\"----------------- asuardi <https://github.com/asuardi> ---------------------\\n\\r\");"
puts $file "	xil_printf(\"-------------------------------- v1.0 --------------------------------------\\n\\r\");"
puts $file "	xil_printf(\"\\n\\r\");"
puts $file "	xil_printf(\"\\n\\r\");"
puts $file "	if (TYPE_ETH==1)"
puts $file "		xil_printf(\"Starting TCP/IP server ...\\n\\r\");"
puts $file "	if (TYPE_ETH==0)"
puts $file "		xil_printf(\"Starting UDP/IP server ...\\n\\r\");"
puts $file "	xil_printf(\"\\n\\r\");"
puts $file "	xil_printf(\"\\n\\r\");"
puts $file "\}"
puts $file ""
puts $file ""
puts $file "inline static void get_payload()\{"
puts $file "	payload_temp_char\[0\] = *payload_ptr++;"
puts $file "	payload_temp_char\[1\] = *payload_ptr++;"
puts $file "	payload_temp_char\[2\] = *payload_ptr++;"
puts $file "	payload_temp_char\[3\] = *payload_ptr++;"
puts $file "\}"
puts $file ""
puts $file ""
puts $file "unsigned int IpTimer(unsigned int TimerIntrId,unsigned short Mode)"
puts $file ""
puts $file "\{"
puts $file ""
puts $file "    int                 Status;"
puts $file "    XScuTimer_Config    *ConfigPtr;"
puts $file "    volatile unsigned int     CntValue  = 0;"
puts $file "    XScuTimer           *TimerInstancePtr = &Timer;"
puts $file ""
puts $file ""
puts $file "    if (Mode == 0) \{"
puts $file ""
puts $file "      // Initialize the Private Timer so that it is ready to use"
puts $file ""
puts $file "      ConfigPtr = XScuTimer_LookupConfig(TimerIntrId);"
puts $file ""
puts $file "      Status = XScuTimer_CfgInitialize(TimerInstancePtr, ConfigPtr,"
puts $file "                     ConfigPtr->BaseAddr);"
puts $file ""
puts $file "      if (Status != XST_SUCCESS) \{"
puts $file "          return XST_FAILURE; \}"
puts $file ""
puts $file "      // Load the timer prescaler register."
puts $file ""
puts $file "      XScuTimer_SetPrescaler(TimerInstancePtr, TIMER_RES_DIVIDER);"
puts $file ""
puts $file "      // Load the timer counter register."
puts $file ""
puts $file "      XScuTimer_LoadTimer(TimerInstancePtr, TIMER_LOAD_VALUE);"
puts $file ""
puts $file "      // Start the timer counter and read start value"
puts $file ""
puts $file "      XScuTimer_Start(TimerInstancePtr);"
puts $file "      CntValue = XScuTimer_GetCounterValue(TimerInstancePtr);"
puts $file ""
puts $file "    \}"
puts $file ""
puts $file "    else \{"
puts $file ""
puts $file "       //  Read stop value and stop the timer counter"
puts $file ""
puts $file "       CntValue = XScuTimer_GetCounterValue(TimerInstancePtr);"
puts $file "       XScuTimer_Stop(TimerInstancePtr);"
puts $file ""
puts $file ""
puts $file "    \}"
puts $file ""
puts $file "    return CntValue;"
puts $file ""
puts $file "\}"


puts $file ""
puts $file ""
puts $file "void udp_server_function(void *arg, struct udp_pcb *pcb,"
puts $file "		struct pbuf *p, struct ip_addr *addr, u16_t port)\{"
puts $file ""
puts $file ""
puts $file "	struct pbuf pnew;"
puts $file "	int k1;"
puts $file "	int k;"
puts $file "	int i;"
puts $file ""
puts $file "	int packet_type;"
puts $file "	int packet_internal_ID;"
puts $file "	int packet_internal_ID_offset;"
puts $file ""
puts $file "	int timer=0;"
puts $file ""
puts $file "	float tmp_float;"
puts $file ""
puts $file "	XScuTimer_Config *ConfigPtr;"
puts $file "	XScuTimer *TimerInstancePtr = &Timer;"
puts $file ""
puts $file ""
puts $file "	xcore.Bus_a_BaseAddress = 0x43c00000;"
puts $file "	xcore.IsReady = XIL_COMPONENT_IS_READY;"
puts $file ""
puts $file ""
puts $file ""
puts $file "	// Only respond when the packet is the correct length"
puts $file "		if (p->len == (ETH_PACKET_LENGTH)*sizeof(int32_t))\{"
puts $file ""
puts $file ""
puts $file "			/* Pick up a pointer to the payload */"
puts $file "			payload_ptr = (unsigned char *)p->payload;"
puts $file ""
puts $file "			//Free the packet buffer"
puts $file "			pbuf_free(p);"
puts $file ""
puts $file "			// Get the payload out"
puts $file "			for(k1=0;k1<ETH_PACKET_LENGTH;k1++)\{"
puts $file "				get_payload();"
puts $file "				inputvec\[k1\] = payload_temp;"
puts $file "			\}"
puts $file ""
puts $file "				//extract informations form the input packet"
puts $file "				tmp_float=*(float*)&inputvec\[ETH_PACKET_LENGTH-2\];"
puts $file "				packet_type=(int)tmp_float & 0x0000FFFF;"
puts $file "				packet_internal_ID=((int)tmp_float & 0xFFFF0000) >> 16; //if write packet_type, packet_num is the data vector ID"
puts $file ""
puts $file "				tmp_float=*(float*)&inputvec\[ETH_PACKET_LENGTH-1\];"
puts $file "				packet_internal_ID_offset=(int)tmp_float; //if write packet_type, packet_num is the data vector ID"
puts $file ""
puts $file "			if (DEBUG)\{"
puts $file "				printf(\"\\n\");"
puts $file "				printf(\"Received packet:\\n\");"
puts $file "				printf(\"packet_type=%x\\n\",packet_type);"
puts $file "				printf(\"packet_internal_ID=%x\\n\",packet_internal_ID);"
puts $file "				printf(\"packet_internal_ID_offset=%x\\n\",packet_internal_ID_offset);"
puts $file "			\}"
puts $file ""
puts $file ""
puts $file "			if (packet_type==1) //reset IP"
puts $file "						\{"
puts $file ""
puts $file "							if (DEBUG)"
puts $file "								printf(\"Reset IP ...\\n\");"
puts $file ""
puts $file "							if (XFoo_IsIdle(&xcore)==1)"
puts $file "							\{"
puts $file "								if (DEBUG)\{"
puts $file "									printf(\"The core is ready to be used\\n\");"
puts $file "								\}"
puts $file "							\}"
puts $file "							else"
puts $file "								printf(\"ERROR: reprogram the FPGA !\\n\"); //should be added the IP reset procedure"
puts $file ""
puts $file "						\}"
puts $file "					else if (packet_type==2) //start IP"
puts $file "							\{"
puts $file ""
puts $file "								if (DEBUG)"
puts $file "									printf(\"Start IP ...\\n\");"
puts $file ""
foreach i $input_vectors {

	set tmp_line ""
	append tmp_line "								XFoo_Set_byte_" $i "_in_offset(&xcore," $i "_IN_DEFINED_MEM_ADDRESS);"
	puts $file $tmp_line

}
foreach i $output_vectors {

	set tmp_line ""
	append tmp_line "								XFoo_Set_byte_" $i "_out_offset(&xcore," $i "_OUT_DEFINED_MEM_ADDRESS);"
	puts $file $tmp_line

}
puts $file ""
puts $file "								//Start timer"
puts $file "								CntValue1 = IpTimer(TIMER_DEVICE_ID,0);"
puts $file ""
puts $file "								//Start IP core"
puts $file "								XFoo_Start(&xcore);"
puts $file ""
puts $file "								//wait until the IP has finished. If an Ethernet read request arrive, it will be served only when the IP will finish. FPGAclientAPI has a timeout of 1 day."
puts $file "								while (XFoo_IsIdle(&xcore)!=1)"
puts $file "								\{"
puts $file "									if (DEBUG)"
puts $file "										printf(\"Wait until the IP has finished ...\\n\");"
puts $file "								\}"
puts $file ""
puts $file "								//Stop timer"
puts $file "								CntValue2 = IpTimer(TIMER_DEVICE_ID,1);"
puts $file ""
puts $file "								if (DEBUG)"
puts $file "								\{"
puts $file "									printf (\"IP Timer: beginning of the counter is : %d \\n\", CntValue1);"
puts $file "									printf (\"IP Timer: end of the counter is : %d \\n\", CntValue2);"
puts $file "								\}"
puts $file ""
puts $file "					\}"
puts $file "					else if (packet_type==3) //write data DDR"
puts $file "					\{"
puts $file ""
puts $file "						if (DEBUG)"
puts $file "						printf(\"Write data to DDR ...\\n\");"
puts $file ""
puts $file "						switch (packet_internal_ID)"
puts $file "						\{"


set m 0
foreach i $input_vectors {

	set tmp_line ""
	append tmp_line "							case " $m ": //" $i "_in"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "							if (DEBUG)"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "									printf(\"write " $i "_in\\n\\r\");"
	puts $file $tmp_line
	
puts $file ""
set tmp_line ""	
append tmp_line "							if (FLOAT_FIX_" [string toupper $i] "_IN==1) \{"
puts $file $tmp_line

set tmp_line ""	
append tmp_line "								for (i=0; i<ETH_PACKET_LENGTH-2; i++)"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "								\{"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "									tmp_float=*(float*)&inputvec\[i\];"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "									inputvec_fix\[i\]=(int32_t)(tmp_float*pow(2," [string toupper $i] "_IN_FRACTIONLENGTH));"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "								\}"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "								memcpy(" $i "_in_ptr_ddr+(ETH_PACKET_LENGTH-2)*packet_internal_ID_offset,inputvec_fix,(ETH_PACKET_LENGTH-2)*4);"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "							\} else \{ //floating-point"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "								memcpy(" $i "_in_ptr_ddr+(ETH_PACKET_LENGTH-2)*packet_internal_ID_offset,inputvec,(ETH_PACKET_LENGTH-2)*4);"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "							\}"
puts $file $tmp_line

	
	
	
	set tmp_line ""
	append tmp_line "							break;"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "							"
	puts $file $tmp_line
	
	incr m
}

puts $file "							default:"
puts $file "							break;"
puts $file "						\}"
puts $file ""
puts $file "					\}"
puts $file ""
puts $file "					else if (packet_type==4) //read data from DDR"
puts $file "					\{"
puts $file "						"
puts $file "						tmp_float=((float)CntValue1-(float)CntValue2) / (float)EE_TICKS_PER_SEC;"
puts $file "						if (DEBUG)"
puts $file "							printf(\"IP time = %f \[s\]\\n\",tmp_float);"
puts $file ""
puts $file "						outvec\[ETH_PACKET_LENGTH_RECV-1\]=*(Xint32*)&tmp_float;  //time"
puts $file ""
puts $file ""
puts $file "						//Initialise output vector"
puts $file "						for(i=0;i<ETH_PACKET_LENGTH_RECV-2;i++)"
puts $file "						\{"
puts $file "							tmp_float=1.0;"
puts $file "							outvec\[i\]=*(Xint32*)&tmp_float;"
puts $file "						\}"
puts $file "						"
puts $file "						"
puts $file "						switch (packet_internal_ID)"
puts $file "						\{"


set m 0
foreach i $output_vectors {

	set tmp_line ""
	append tmp_line "							case " $m ": //" $i "_in"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "							if (DEBUG)"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "								printf(\"read " $i "_out\\n\\r\");"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "							memcpy(outvec_fix," $i "_out_ptr_ddr+(ETH_PACKET_LENGTH_RECV-2)*packet_internal_ID_offset,(ETH_PACKET_LENGTH_RECV-2)*4);"
	puts $file $tmp_line
	
	
set tmp_line ""
append tmp_line "							for (i=0; i<ETH_PACKET_LENGTH_RECV-2; i++)"
puts $file $tmp_line
set tmp_line ""
append tmp_line "							\{"
puts $file $tmp_line
set tmp_line ""
append tmp_line "								if (FLOAT_FIX_" [string toupper $i] "_OUT==1) \{ //fixed-point"
puts $file $tmp_line
set tmp_line ""
append tmp_line "									tmp_float=((float)outvec_fix\[i\])/pow(2," [string toupper $i] "_OUT_FRACTIONLENGTH);"
puts $file $tmp_line
set tmp_line ""
append tmp_line "									outvec\[i\]=*(Xint32*)&tmp_float;"
puts $file $tmp_line
set tmp_line ""
append tmp_line "								\} else \{ //floating point"
puts $file $tmp_line
set tmp_line ""
append tmp_line "									outvec\[i\]=outvec_fix\[i\];"
puts $file $tmp_line
set tmp_line ""
append tmp_line "								\}"
puts $file $tmp_line
set tmp_line ""
append tmp_line "							\}"
puts $file $tmp_line

	set tmp_line ""
	append tmp_line "							break;"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "							"
	puts $file $tmp_line
	
	incr m
}

puts $file "							default:"
puts $file "							break;"
puts $file "						\}"
puts $file "						"
puts $file "						"
puts $file ""						
puts $file "						// send back the payload"
puts $file "						// We now need to return the result"
puts $file "						pnew.next = NULL;"
puts $file "						pnew.payload = (unsigned char *)outvec;"
puts $file "						pnew.len = ETH_PACKET_LENGTH*sizeof(Xint32);"
puts $file "						pnew.type = PBUF_RAM;"
puts $file "						pnew.tot_len = pnew.len;"
puts $file "						pnew.ref = 1;"
puts $file "						pnew.flags = 0;"
puts $file ""
puts $file ""
puts $file "						udp_sendto(pcb, &pnew, addr, port);"
puts $file ""
puts $file "					\}"
puts $file "					else if (packet_type==5) //read data from DDR"
puts $file "					\{"
puts $file ""
puts $file "						//Initialise output vector"
puts $file "						for(i=0;i<ETH_PACKET_LENGTH;i++)"
puts $file "						\{"
puts $file "							tmp_float=1.0;"
puts $file "							outvec\[i\]=*(Xint32*)&tmp_float;"
puts $file "						\}"
puts $file "						"
puts $file "						// send back the payload"
puts $file "						// We now need to return the result"
puts $file "						pnew.next = NULL;"
puts $file "						pnew.payload = (unsigned char *)outvec;"
puts $file "						pnew.len = ETH_PACKET_LENGTH*sizeof(Xint32);"
puts $file "						pnew.type = PBUF_RAM;"
puts $file "						pnew.tot_len = pnew.len;"
puts $file "						pnew.ref = 1;"
puts $file "						pnew.flags = 0;"
puts $file ""
puts $file "						udp_sendto(pcb, &pnew, addr, port);"
puts $file ""
puts $file "					\}"
puts $file ""
puts $file "				\}"
puts $file "				/* free the received pbuf */"
puts $file "				pbuf_free(p);"
puts $file ""
puts $file "				return ERR_OK;"
puts $file ""
puts $file "	//printf(\"Time was: %d\\n\", tval);"
puts $file "\}"
puts $file ""
puts $file ""

puts $file "err_t tcp_server_function(void *arg, struct tcp_pcb *tpcb,"
puts $file "                               struct pbuf *p, err_t err)"
puts $file ""
puts $file "\{"
puts $file ""
puts $file "	int k1;"
puts $file "	int i;"
puts $file "	int len;"
puts $file ""
puts $file "	int packet_type;"
puts $file "	int packet_internal_ID;"
puts $file "	int packet_internal_ID_offset;"
puts $file ""
puts $file "	int timer=0;"
puts $file ""
puts $file "	float tmp_float;"
puts $file ""
puts $file ""
puts $file "	XScuTimer_Config *ConfigPtr;"
puts $file "	XScuTimer *TimerInstancePtr = &Timer;"
puts $file ""
puts $file ""
puts $file "	xcore.Bus_a_BaseAddress = 0x43c00000;"
puts $file "	xcore.IsReady = XIL_COMPONENT_IS_READY;"
puts $file ""
puts $file ""
puts $file ""


puts $file "	// indicate that the packet has been received"
puts $file "	tcp_recved(tpcb, p->len);"
puts $file ""
puts $file "	// Only respond when the packet is the correct length"
puts $file "	if (p->len == (ETH_PACKET_LENGTH)*sizeof(int32_t))\{"
puts $file ""
puts $file ""
puts $file "		/* Pick up a pointer to the payload */"
puts $file "		payload_ptr = (unsigned char *)p->payload;"
puts $file ""
puts $file "			//Free the packet buffer"
puts $file "			pbuf_free(p);"
puts $file ""
puts $file "			// Get the payload out"
puts $file "			for(k1=0;k1<ETH_PACKET_LENGTH;k1++)\{"
puts $file "				get_payload();"
puts $file "				inputvec\[k1\] = payload_temp;"
puts $file "			\}"
puts $file ""
puts $file "				//extract informations form the input packet"
puts $file "				tmp_float=*(float*)&inputvec\[ETH_PACKET_LENGTH-2\];"
puts $file "				packet_type=(int)tmp_float & 0x0000FFFF;"
puts $file "				packet_internal_ID=((int)tmp_float & 0xFFFF0000) >> 16; //if write packet_type, packet_num is the data vector ID"
puts $file ""
puts $file "				tmp_float=*(float*)&inputvec\[ETH_PACKET_LENGTH-1\];"
puts $file "				packet_internal_ID_offset=(int)tmp_float; //if write packet_type, packet_num is the data vector ID"
puts $file ""
puts $file "			if (DEBUG)\{"
puts $file "				printf(\"\\n\");"
puts $file "				printf(\"Received packet:\\n\");"
puts $file "				printf(\"packet_type=%x\\n\",packet_type);"
puts $file "				printf(\"packet_internal_ID=%x\\n\",packet_internal_ID);"
puts $file "				printf(\"packet_internal_ID_offset=%x\\n\",packet_internal_ID_offset);"
puts $file "			\}"
puts $file ""
puts $file ""
puts $file "			if (packet_type==1) //reset IP"
puts $file "						\{"
puts $file ""
puts $file "							if (DEBUG)"
puts $file "								printf(\"Reset IP ...\\n\");"
puts $file ""
puts $file "							if (XFoo_IsIdle(&xcore)==1)"
puts $file "							\{"
puts $file "								if (DEBUG)\{"
puts $file "									printf(\"The core is ready to be used\\n\");"
puts $file "								\}"
puts $file "							\}"
puts $file "							else"
puts $file "								printf(\"ERROR: reprogram the FPGA !\\n\"); //should be added the IP reset procedure"
puts $file ""
puts $file "						\}"
puts $file "					else if (packet_type==2) //start IP"
puts $file "							\{"
puts $file ""
puts $file "								if (DEBUG)"
puts $file "									printf(\"Start IP ...\\n\");"
puts $file ""
foreach i $input_vectors {

	set tmp_line ""
	append tmp_line "								XFoo_Set_byte_" $i "_in_offset(&xcore," $i "_IN_DEFINED_MEM_ADDRESS);"
	puts $file $tmp_line

}
foreach i $output_vectors {

	set tmp_line ""
	append tmp_line "								XFoo_Set_byte_" $i "_out_offset(&xcore," $i "_OUT_DEFINED_MEM_ADDRESS);"
	puts $file $tmp_line

}
puts $file ""
puts $file "								//Start timer"
puts $file "								CntValue1 = IpTimer(TIMER_DEVICE_ID,0);"
puts $file ""
puts $file "								//Start IP core"
puts $file "								XFoo_Start(&xcore);"
puts $file ""
puts $file "								//wait until the IP has finished. If an Ethernet read request arrive, it will be served only when the IP will finish. FPGAclientAPI has a timeout of 1 day."
puts $file "								while (XFoo_IsIdle(&xcore)!=1)"
puts $file "								\{"
puts $file "									if (DEBUG)"
puts $file "										printf(\"Wait until the IP has finished ...\\n\");"
puts $file "								\}"
puts $file ""
puts $file "								//Stop timer"
puts $file "								CntValue2 = IpTimer(TIMER_DEVICE_ID,1);"
puts $file ""
puts $file "								if (DEBUG)"
puts $file "								\{"
puts $file "									printf (\"IP Timer: beginning of the counter is : %d \\n\", CntValue1);"
puts $file "									printf (\"IP Timer: end of the counter is : %d \\n\", CntValue2);"
puts $file "								\}"
puts $file ""
puts $file "					\}"
puts $file "					else if (packet_type==3) //write data DDR"
puts $file "					\{"
puts $file ""
puts $file "						if (DEBUG)"
puts $file "						printf(\"Write data to DDR ...\\n\");"
puts $file ""
puts $file "						switch (packet_internal_ID)"
puts $file "						\{"


set m 0
foreach i $input_vectors {

	set tmp_line ""
	append tmp_line "							case " $m ": //" $i "_in"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "							if (DEBUG)"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "									printf(\"write " $i "_in\\n\\r\");"
	puts $file $tmp_line
	
puts $file ""
set tmp_line ""	
append tmp_line "							if (FLOAT_FIX_" [string toupper $i] "_IN==1) \{"
puts $file $tmp_line

set tmp_line ""	
append tmp_line "								for (i=0; i<ETH_PACKET_LENGTH-2; i++)"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "								\{"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "									tmp_float=*(float*)&inputvec\[i\];"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "									inputvec_fix\[i\]=(int32_t)(tmp_float*pow(2," [string toupper $i] "_IN_FRACTIONLENGTH));"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "								\}"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "								memcpy(" $i "_in_ptr_ddr+(ETH_PACKET_LENGTH-2)*packet_internal_ID_offset,inputvec_fix,(ETH_PACKET_LENGTH-2)*4);"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "							\} else \{ //floating-point"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "								memcpy(" $i "_in_ptr_ddr+(ETH_PACKET_LENGTH-2)*packet_internal_ID_offset,inputvec,(ETH_PACKET_LENGTH-2)*4);"
puts $file $tmp_line
set tmp_line ""	
append tmp_line "							\}"
puts $file $tmp_line

	
	
	
	set tmp_line ""
	append tmp_line "							break;"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "							"
	puts $file $tmp_line
	
	incr m
}

puts $file "							default:"
puts $file "							break;"
puts $file "						\}"
puts $file ""
puts $file "					\}"
puts $file ""
puts $file "					else if (packet_type==4) //read data from DDR"
puts $file "					\{"
puts $file "						"
puts $file "						tmp_float=((float)CntValue1-(float)CntValue2) / (float)EE_TICKS_PER_SEC;"
puts $file "						if (DEBUG)"
puts $file "							printf(\"IP time = %f \[s\]\\n\",tmp_float);"
puts $file ""
puts $file "						outvec\[ETH_PACKET_LENGTH_RECV-1\]=*(Xint32*)&tmp_float;  //time"
puts $file ""
puts $file ""
puts $file "						//Initialise output vector"
puts $file "						for(i=0;i<ETH_PACKET_LENGTH_RECV-2;i++)"
puts $file "						\{"
puts $file "							tmp_float=1.0;"
puts $file "							outvec\[i\]=*(Xint32*)&tmp_float;"
puts $file "						\}"
puts $file "						"
puts $file "						"
puts $file "						switch (packet_internal_ID)"
puts $file "						\{"


set m 0
foreach i $output_vectors {

	set tmp_line ""
	append tmp_line "							case " $m ": //" $i "_in"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "							if (DEBUG)"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "								printf(\"read " $i "_out\\n\\r\");"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "							memcpy(outvec_fix," $i "_out_ptr_ddr+(ETH_PACKET_LENGTH_RECV-2)*packet_internal_ID_offset,(ETH_PACKET_LENGTH_RECV-2)*4);"
	puts $file $tmp_line
	
	
set tmp_line ""
append tmp_line "							for (i=0; i<ETH_PACKET_LENGTH_RECV-2; i++)"
puts $file $tmp_line
set tmp_line ""
append tmp_line "							\{"
puts $file $tmp_line
set tmp_line ""
append tmp_line "								if (FLOAT_FIX_" [string toupper $i] "_OUT==1) \{ //fixed-point"
puts $file $tmp_line
set tmp_line ""
append tmp_line "									tmp_float=((float)outvec_fix\[i\])/pow(2," [string toupper $i] "_OUT_FRACTIONLENGTH);"
puts $file $tmp_line
set tmp_line ""
append tmp_line "									outvec\[i\]=*(Xint32*)&tmp_float;"
puts $file $tmp_line
set tmp_line ""
append tmp_line "								\} else \{ //floating point"
puts $file $tmp_line
set tmp_line ""
append tmp_line "									outvec\[i\]=outvec_fix\[i\];"
puts $file $tmp_line
set tmp_line ""
append tmp_line "								\}"
puts $file $tmp_line
set tmp_line ""
append tmp_line "							\}"
puts $file $tmp_line

	set tmp_line ""
	append tmp_line "							break;"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "							"
	puts $file $tmp_line
	
	incr m
}

puts $file "							default:"
puts $file "							break;"
puts $file "						\}"
puts $file "						"
puts $file "						"

puts $file ""
puts $file "			// send back the payload"
puts $file "			err = tcp_write(tpcb, outvec, ETH_PACKET_LENGTH*sizeof(Xint32), TCP_WRITE_FLAG_MORE);"
puts $file "			tcp_output(tpcb); //send data now"
puts $file ""
puts $file "		\}"
puts $file "					else if (packet_type==5) //read data from DDR"
puts $file "					\{"
puts $file ""
puts $file "						//Initialise output vector"
puts $file "						for(i=0;i<ETH_PACKET_LENGTH;i++)"
puts $file "						\{"
puts $file "							tmp_float=1.0;"
puts $file "							outvec\[i\]=*(Xint32*)&tmp_float;"
puts $file "						\}"
puts $file ""
puts $file "			// send back the payload"
puts $file "			err = tcp_write(tpcb, outvec, ETH_PACKET_LENGTH*sizeof(Xint32), TCP_WRITE_FLAG_MORE);"
puts $file "			tcp_output(tpcb); //send data now"
puts $file ""
puts $file "		\}"
puts $file ""
puts $file "	\}"
puts $file ""
puts $file "	/* free the received pbuf */"
puts $file "	pbuf_free(p);"
puts $file ""
puts $file "	return ERR_OK;"
puts $file "\}"
puts $file ""
puts $file ""
puts $file "err_t tcp_accept_callback(void *arg, struct tcp_pcb *newpcb, err_t err)"
puts $file "\{"
puts $file "	static int connection = 1;"
puts $file ""
puts $file ""
puts $file "		/* set the receive callback for this connection */"
puts $file "		tcp_recv(newpcb, tcp_server_function);"
puts $file ""
puts $file ""
puts $file "	/* increment for subsequent accepted connections */"
puts $file "	connection++;"
puts $file ""
puts $file "	return ERR_OK;"
puts $file "\}"
puts $file ""
puts $file ""
puts $file "int start_application()"
puts $file "\{"
puts $file ""
puts $file "	err_t err;"
puts $file "	unsigned port = 2007;"
puts $file ""
puts $file ""
puts $file "	// bind to specified @port"
puts $file "if (TYPE_ETH==1)\{ //TCP interface"
puts $file "		struct tcp_pcb *pcb;"
puts $file "		pcb = tcp_new();"
puts $file ""
puts $file ""
puts $file "		//create new TCP PCB structure */"
puts $file "		if (!pcb) \{"
puts $file "			xil_printf(\"Error creating PCB. Out of Memory\\n\\r\");"
puts $file "			return -1;"
puts $file "		\}"
puts $file ""
puts $file "		err = tcp_bind(pcb, IP_ADDR_ANY, port);"
puts $file ""
puts $file "		if (err != ERR_OK) \{"
puts $file "			xil_printf(\"Unable to bind to port %d: err = %d\", port, err);"
puts $file "			return -2;"
puts $file "		\}"
puts $file ""
puts $file "		/* we do not need any arguments to callback functions */"
puts $file "		//tcp_arg(pcb, NULL);"
puts $file ""
puts $file "		/* listen for connections */"
puts $file "		pcb = tcp_listen(pcb);"
puts $file "		if (!pcb) \{"
puts $file "			xil_printf(\"Out of memory while tcp_listen\\n\\r\");"
puts $file "			return -3;"
puts $file "		\}"
puts $file ""
puts $file "		//xil_printf(\"Got here: start_application\\n\\r\");"
puts $file ""
puts $file "		/* specify callback to use for incoming connections */"
puts $file "		tcp_accept(pcb, tcp_accept_callback);"
puts $file ""
puts $file "		xil_printf(\"TCP/IP  FPGA interface framework server started @ port %d\\n\\r\", port);"
puts $file ""
puts $file "\}"
puts $file ""
puts $file "else //UDP interface"
puts $file "\{"
puts $file ""
puts $file "		struct udp_pcb *pcb;"
puts $file "		pcb = udp_new();"
puts $file ""
puts $file "		//create new TCP PCB structure"
puts $file "		if (!pcb) \{"
puts $file "			xil_printf(\"Error creating PCB. Out of Memory\\n\\r\");"
puts $file "			return -1;"
puts $file "		\}"
puts $file ""
puts $file "		err = udp_bind(pcb, IP_ADDR_ANY, port);"
puts $file ""
puts $file "		if (err != ERR_OK) \{"
puts $file "			xil_printf(\"Unable to bind to port %d: err = %d\", port, err);"
puts $file "			return -2;"
puts $file "		\}"
puts $file ""
puts $file "		// specify callback to use for incoming connections"
puts $file "		udp_recv(pcb, udp_server_function, NULL);"
puts $file ""
puts $file "		xil_printf(\"UDP/IP FPGA interface framework server started @ port %d\\n\\r\", port);"
puts $file ""
puts $file "\}"
puts $file ""
puts $file "	return 0;"
puts $file "\}"



close $file
return -code ok

}



# ########################################################################################
# make ip_prototype/src/main.c file

proc ::tclapp::icl::protoip::make_template::make_main_c {} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:


set file [open ip_prototype/src/main.c w]


#add license_c header
[::tclapp::icl::protoip::make_template::license_c $file]

puts $file ""
puts $file "#include <stdio.h>"
puts $file ""
puts $file "#include \"xparameters.h\""
puts $file ""
puts $file "#include \"netif/xadapter.h\""
puts $file ""
puts $file "#include \"platform.h\""
puts $file "#include \"platform_config.h\""
puts $file "#include \"lwipopts.h\""
puts $file "#ifdef __arm__"
puts $file "#include \"xil_printf.h\""
puts $file "#endif"
puts $file ""
puts $file ""
puts $file ""
puts $file "#define INVALID 0"
puts $file ""
puts $file "#include\"FPGAserver.h\""
puts $file ""
puts $file "/* defined by each RAW mode application */"
puts $file "void print_app_header();"
puts $file "int start_application();"
puts $file "int transfer_data();"
puts $file "void platform_enable_interrupts();"
puts $file "/* missing declaration in lwIP */"
puts $file "void lwip_init();"
puts $file ""
puts $file ""
puts $file "static struct netif server_netif;"
puts $file "struct netif *echo_netif;"
puts $file ""
puts $file ""
puts $file ""
puts $file "void print_ip(char *msg, struct ip_addr *ip) "
puts $file "\{"
puts $file "	printf(msg);"
puts $file "	printf(\"%d.%d.%d.%d\\\n\\r\", ip4_addr1(ip), ip4_addr2(ip), "
puts $file "			ip4_addr3(ip), ip4_addr4(ip));"
puts $file "\}"
puts $file ""
puts $file "void print_ip_settings(struct ip_addr *ip, struct ip_addr *mask, struct ip_addr *gw)"
puts $file "\{"
puts $file ""
puts $file "	print_ip(\"Board IP: \", ip);"
puts $file "	print_ip(\"Netmask : \", mask);"
puts $file "	print_ip(\"Gateway : \", gw);"
puts $file "\}"
puts $file ""
puts $file ""
puts $file ""
puts $file ""
puts $file "unsigned int ip_to_int (const char * ip, unsigned int  *a1, unsigned int  *a2, unsigned int  *a3, unsigned int  *a4)"
puts $file "\{"
puts $file "    /* The return value. */"
puts $file "   unsigned v = 0;"
puts $file "   /* The count of the number of bytes processed. */"
puts $file "    int i;"
puts $file "    /* A pointer to the next digit to process. */"
puts $file "    const char * start;"
puts $file ""
puts $file "    start = ip;"
puts $file "    for (i = 0; i < 4; i++) \{"
puts $file "        /* The digit being processed. */"
puts $file "        char c;"
puts $file "        /* The value of this byte. */"
puts $file "        int n = 0;"
puts $file "        while (1) \{"
puts $file "           c = * start;"
puts $file "           start++;"
puts $file "            if (c >= '0' && c <= '9') \{"
puts $file "               n *= 10;"
puts $file "                n += c - '0';"
puts $file "           \}"
puts $file "            /* We insist on stopping at \".\" if we are still parsing"
puts $file "               the first, second, or third numbers. If we have reached"
puts $file "               the end of the numbers, we will allow any character. */"
puts $file "           else if ((i < 3 && c == '.') || i == 3) \{"
puts $file "                break;"
puts $file "            \}"
puts $file "            else \{"
puts $file "                return INVALID;"
puts $file "            \}"
puts $file "       \}"
puts $file "        if (n >= 256) \{"
puts $file "            return INVALID;"
puts $file "        \}"
puts $file "        v *= 256;"
puts $file "        v += n;"
puts $file "    \}"
puts $file ""
puts $file ""
puts $file "	*a1=(unsigned int )(v & 0x000000FF);"
puts $file "	*a2=(unsigned int )((v & 0x0000FF00)>>8);"
puts $file "	*a3=(unsigned int )((v & 0x00FF0000)>>16);"
puts $file "	*a4=(unsigned int )((v & 0xFF000000)>>24);"
puts $file ""
puts $file ""
puts $file "   return v;"
puts $file "\}"
puts $file ""
puts $file ""
puts $file ""
puts $file "int main()"
puts $file "\{"
puts $file ""
puts $file "	struct ip_addr ipaddr, netmask, gw;"
puts $file "	unsigned FPGA_port_number;"
puts $file "	char *FPGA_ip_address;"
puts $file "	char *FPGA_netmask;"
puts $file "	char *FPGA_gateway;"
puts $file "	unsigned integer_ip;"
puts $file ""
puts $file "	unsigned int  FPGA_ip_address_a1,FPGA_ip_address_a2,FPGA_ip_address_a3,FPGA_ip_address_a4;"
puts $file "	unsigned int  FPGA_netmask_a1,FPGA_netmask_a2,FPGA_netmask_a3,FPGA_netmask_a4;"
puts $file "	unsigned int  FPGA_gateway_a1,FPGA_gateway_a2,FPGA_gateway_a3,FPGA_gateway_a4;"
puts $file ""
puts $file "	//EXAMPLE: set FPGA IP and port number"
puts $file "	FPGA_ip_address=FPGA_IP;"
puts $file "	FPGA_netmask=FPGA_NM;"
puts $file "	FPGA_gateway=FPGA_GW;"
puts $file "	FPGA_port_number=FPGA_PORT;"
puts $file ""
puts $file "	//extract FPGA IP address from string"
puts $file "	if (ip_to_int (FPGA_ip_address,&FPGA_ip_address_a1,&FPGA_ip_address_a2,&FPGA_ip_address_a3,&FPGA_ip_address_a4) == INVALID) \{"
puts $file "		printf (\"'%s' is not a valid IP address for FPGA server.\\n\", FPGA_ip_address);"
puts $file "		return 1;"
puts $file "	\}"
puts $file ""
puts $file "	//extract FPGA netmask address from string"
puts $file "	if (ip_to_int (FPGA_netmask,&FPGA_netmask_a1,&FPGA_netmask_a2,&FPGA_netmask_a3,&FPGA_netmask_a4) == INVALID) \{"
puts $file "		printf (\"'%s' is not a valid netmask address for FPGA server.\\n\", FPGA_netmask);"
puts $file "		return 1;"
puts $file "	\}"
puts $file ""
puts $file "	//extract FPGA gateway address from string"
puts $file "	if (ip_to_int (FPGA_gateway,&FPGA_gateway_a1,&FPGA_gateway_a2,&FPGA_gateway_a3,&FPGA_gateway_a4) == INVALID) \{"
puts $file "		printf (\"'%s' is not a valid gateway address for FPGA server.\\n\", FPGA_gateway);"
puts $file "		return 1;"
puts $file "	\}"
puts $file ""
puts $file "	/* the mac address of the board. this should be unique per board */"
puts $file "	unsigned char mac_ethernet_address\[\] ="
puts $file "	\{ 0x00, 0x0a, 0x35, 0x00, 0x01, 0x02 \};"
puts $file ""
puts $file "	echo_netif = &server_netif;"
puts $file ""
puts $file "	init_platform();"
puts $file "	Xil_DCacheDisable();"
puts $file ""
puts $file "	/* initliaze IP addresses to be used */"
puts $file "	IP4_ADDR(&ipaddr,  FPGA_ip_address_a4, FPGA_ip_address_a3,   FPGA_ip_address_a2, FPGA_ip_address_a1);"
puts $file "	IP4_ADDR(&netmask, FPGA_netmask_a4, FPGA_netmask_a3, FPGA_netmask_a2,  FPGA_netmask_a1);"
puts $file "	IP4_ADDR(&gw,      FPGA_gateway_a4, FPGA_gateway_a3,   FPGA_gateway_a2,  FPGA_gateway_a1);"
puts $file "	print_app_header();"
puts $file "	print_ip_settings(&ipaddr, &netmask, &gw);"
puts $file "	lwip_init();"
puts $file ""
puts $file ""
puts $file ""
puts $file "  	/* Add network interface to the netif_list, and set it as default */"
puts $file "	if (!xemac_add(echo_netif, &ipaddr, &netmask,&gw, mac_ethernet_address,PLATFORM_EMAC_BASEADDR)) \{"
puts $file "		xil_printf(\"Error adding N/W interface\\n\\r\");"
puts $file "		return -1;"
puts $file "	\}"
puts $file "	netif_set_default(echo_netif);"
puts $file ""
puts $file "	/* specify that the network if is up */"
puts $file "	netif_set_up(echo_netif);"
puts $file ""
puts $file "	/* now enable interrupts */"
puts $file "	platform_enable_interrupts();"
puts $file ""
puts $file ""
puts $file "	/* start the application (web server, rxtest, txtest, etc..) */"
puts $file "	start_application();"
puts $file ""
puts $file "	/* receive and process packets */"
puts $file "	while (1) \{"
puts $file "		xemacif_input(echo_netif);"
puts $file "		transfer_data();"
puts $file "	\}"
puts $file "  "
puts $file "	/* never reached */"
puts $file "	cleanup_platform();"
puts $file ""
puts $file "	return 0;"
puts $file "\}"
puts $file ""


close $file
return -code ok

}


# ########################################################################################
# make ip_design/src/FPGAclientMATLAB.m file

proc ::tclapp::icl::protoip::make_template::FPGAclientMATLAB_m {} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:


set file [open ip_design/src/FPGAclientMATLAB.m w]


#add license_m header
[::tclapp::icl::protoip::make_template::license_m $file]


puts $file ""
puts $file "function \[\] = FPGAclientMATLAB(varargin)"
puts $file ""
puts $file "error('mex file absent, type ''mex FPGAclientMATLAB.c'' to compile');"

close $file
return -code ok

}



# ########################################################################################
# make ip_design/src/FPGAclientMATLAB.c file

proc ::tclapp::icl::protoip::make_template::FPGAclientMATLAB_c {} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:


set file [open ip_design/src/FPGAclientMATLAB.c w]


#add license_c header
[::tclapp::icl::protoip::make_template::license_c $file]
puts $file ""

puts $file "#include \"mex.h\""
puts $file "#include \"matrix.h\""
puts $file ""
puts $file "#include\"FPGAclientAPI.h\""

puts $file ""
puts $file ""
puts $file ""
puts $file ""
puts $file "    "
# puts $file "int UDPclient_wrap(char ip_address\[\], unsigned port_number, double din\[ETH_PACKET_LENGTH\], unsigned Packet_type, double dout\[ETH_PACKET_LENGTH_RECV\], double *PC_time, double *FPGA_time);"
# puts $file "int TCPclient_wrap(char ip_address\[\], unsigned port_number, double din\[ETH_PACKET_LENGTH\], unsigned Packet_type, double dout\[ETH_PACKET_LENGTH_RECV\], double *PC_time, double *FPGA_time);"
# puts $file "void error(char *msg);"
puts $file ""
puts $file ""
puts $file "    "
puts $file "    "
puts $file "   "
puts $file ""
puts $file ""
puts $file ""
puts $file ""
puts $file "void mexFunction( int nlhs, mxArray *plhs\[\] , int nrhs, const mxArray *prhs\[\] )"
puts $file "\{"
puts $file "	double * time_matlab;"
puts $file "	double * time_fpga;"
puts $file "	double * data;"
puts $file "	double * M_values;"
puts $file "	mwSize row_size,col_size;"
puts $file "	mwSize  *dims;"
puts $file "	double * results;"
puts $file "	double output_data_eth\[ETH_PACKET_LENGTH_RECV\];"
puts $file "	int i,j;"
puts $file "	double time_fpga_int;"
puts $file "    int flag;"
puts $file "	"
puts $file "	double flag_IP_running;"
puts $file "   "
puts $file "    double port;"
puts $file "    double link;"
puts $file "    double ptype;"
puts $file "    double pID;"
puts $file "    double poutsize;"
puts $file "	char *FPGA_ip_address;"
puts $file "    int buflen;"
puts $file "    int status;"
puts $file "    unsigned FPGA_port_number;"
puts $file "    unsigned FPGA_link;"
puts $file "    unsigned Packet_type;"
puts $file "    unsigned packet_input_size;"
puts $file "    unsigned packet_internal_ID;"
puts $file "    unsigned packet_output_size;"
puts $file "    double *input_data;"
puts $file "    double *output_data;"
puts $file "    double input_data_eth\[ETH_PACKET_LENGTH\];"
puts $file "    double packet_internal_ID_offset;"
puts $file "    "
puts $file ""
puts $file "    "
puts $file "	if(nrhs > 4 || nlhs > 3)"
puts $file "	\{"
puts $file "	    "
puts $file "	    plhs\[0\]    = mxCreateDoubleMatrix(0 , 0 ,  mxREAL);"
puts $file "        plhs\[1\]    = mxCreateDoubleMatrix(0 , 0 ,  mxREAL);"
puts $file "        plhs\[2\]    = mxCreateDoubleMatrix(0 , 0 ,  mxREAL);"
puts $file "	    return;"
puts $file "	\}"
puts $file "	"
puts $file "   "
puts $file "    "
puts $file ""
puts $file "            "
puts $file "     //input array"
puts $file "    data = mxGetPr(prhs\[0\]);"
puts $file "    dims = mxGetDimensions(prhs\[0\]);"
puts $file "    if (dims\[1\]==1)"
puts $file "        packet_input_size = dims\[0\]; //vector length"
puts $file "    else if (dims\[0\]==1)"
puts $file "        packet_input_size = dims\[1\]; //vector length"
puts $file ""
puts $file "    input_data = (double*)mxMalloc(packet_input_size*sizeof(double));"
puts $file ""
puts $file " "
puts $file "    //Packet_type"
puts $file "    ptype = mxGetScalar(prhs\[1\]);"
puts $file "    Packet_type=(unsigned)(ptype);"
puts $file "    "
puts $file "     //packet_internal_ID"
puts $file "    pID = mxGetScalar(prhs\[2\]);"
puts $file "    packet_internal_ID=(unsigned)(pID);"
puts $file "    "
puts $file "    //packet_output_size"
puts $file "    poutsize = mxGetScalar(prhs\[3\]);"
puts $file "    packet_output_size=(unsigned)(poutsize);"
puts $file "    "
puts $file "   "
puts $file "    for (i=0; i<packet_input_size; i++) \{"
puts $file "		input_data\[i\]=*(data+i);"
puts $file "		//printf (\"input_data\[%d\]=%f \\n\",i,input_data\[i\]);"
puts $file "	\}"
puts $file "    "
puts $file "	"
puts $file "    //malloc output vector"
puts $file "    output_data = (double*)mxMalloc(packet_output_size*sizeof(double));"
puts $file "	"
puts $file "	time_fpga_int=0;"
puts $file "    "
puts $file "	"
puts $file "   "
puts $file "	FPGAclient( input_data, packet_input_size, Packet_type, packet_internal_ID, packet_output_size, output_data,&time_fpga_int);"
puts $file ""
puts $file "    "
puts $file "   	// ----- output ----- "
puts $file "    "
puts $file "    "
puts $file "    // Create a 0-by-0 mxArray: allocate the memory dynamically"
puts $file "    plhs\[0\] = mxCreateNumericMatrix(0, 0, mxDOUBLE_CLASS, mxREAL);"
puts $file ""
puts $file "    // Put the output_data array into the mxArray and define its dimensions "
puts $file "    mxSetPr(plhs\[0\], output_data);"
puts $file "    mxSetM(plhs\[0\], packet_output_size);"
puts $file "    mxSetN(plhs\[0\], 1);"
puts $file ""
puts $file "	plhs\[1\]    = mxCreateDoubleScalar  (mxREAL );"
puts $file "	time_fpga = (double *) mxGetPr(plhs\[1\]);"
puts $file "    "
puts $file "  *time_fpga=time_fpga_int;"
puts $file "  "
puts $file "  mxFree(input_data);"
puts $file ""
puts $file "	  "
puts $file "\}"
puts $file ""
puts $file ""
puts $file ""

puts $file ""
puts $file ""




close $file
return -code ok

}




# ########################################################################################
# make ip_prototype/src/FPGAclientMATLAB.m file

proc ::tclapp::icl::protoip::make_template::MicroZed_PS_properties_v02_tcl {} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:


set file [open .metadata/MicroZed_PS_properties_v02.tcl w]



puts $file ""
puts $file "############################################################################"
puts $file "# PS Bank Voltage, Busses, Clocks "
puts $file "############################################################################"
puts $file "set_property -dict \[ list \\"
puts $file "	CONFIG.PCW_PRESET_BANK0_VOLTAGE \{LVCMOS 3.3V\} \\"
puts $file "	CONFIG.PCW_PRESET_BANK1_VOLTAGE \{LVCMOS 1.8V\} \\"
puts $file "	CONFIG.PCW_PACKAGE_NAME \{clg400\} \\"
puts $file "	CONFIG.PCW_USE_M_AXI_GP0 \{0\} \\"
puts $file "	CONFIG.PCW_USE_M_AXI_GP1 \{0\} \\"
puts $file "	CONFIG.PCW_CRYSTAL_PERIPHERAL_FREQMHZ \{33.333333\} \\"
puts $file "	CONFIG.PCW_APU_CLK_RATIO_ENABLE \{6:2:1\} \\"
puts $file "	CONFIG.PCW_CPU_PERIPHERAL_CLKSRC \{ARM PLL\} \\"
puts $file "	CONFIG.PCW_DDR_PERIPHERAL_CLKSRC \{DDR PLL\} \\"
puts $file "	CONFIG.PCW_QSPI_PERIPHERAL_CLKSRC \{IO PLL\} \\"
puts $file "	CONFIG.PCW_ENET0_PERIPHERAL_CLKSRC \{IO PLL\} \\"
puts $file "	CONFIG.PCW_SDIO_PERIPHERAL_CLKSRC \{IO PLL\} \\"
puts $file "	CONFIG.PCW_UART_PERIPHERAL_CLKSRC \{IO PLL\} \\"
puts $file "	CONFIG.PCW_TTC0_CLK0_PERIPHERAL_CLKSRC \{CPU_1X\} \\"
puts $file "	CONFIG.PCW_TTC0_CLK1_PERIPHERAL_CLKSRC \{CPU_1X\} \\"
puts $file "	CONFIG.PCW_TTC0_CLK2_PERIPHERAL_CLKSRC \{CPU_1X\} \\"
puts $file "	CONFIG.PCW_APU_PERIPHERAL_FREQMHZ \{666.666666\} \\"
puts $file "	CONFIG.PCW_UIPARAM_ACT_DDR_FREQ_MHZ \{533.333333\} \\"
puts $file "	CONFIG.PCW_ENET0_PERIPHERAL_FREQMHZ \{1000 Mbps\} \\"
puts $file "	CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ \{50\} \\"
puts $file "	CONFIG.PCW_QSPI_PERIPHERAL_FREQMHZ \{200.000000\} \\"
puts $file "	CONFIG.PCW_UART_PERIPHERAL_FREQMHZ \{50\} \\"
puts $file "	CONFIG.PCW_USB0_PERIPHERAL_FREQMHZ \{60\} \\"
puts $file "	CONFIG.PCW_TTC0_CLK0_PERIPHERAL_FREQMHZ \{111.111115\} \\"
puts $file "	CONFIG.PCW_TTC0_CLK1_PERIPHERAL_FREQMHZ \{111.111115\} \\"
puts $file "	CONFIG.PCW_TTC0_CLK2_PERIPHERAL_FREQMHZ \{111.111115\} \\"
puts $file "\] \[get_bd_cells \]"
puts $file ""
puts $file "############################################################################"
puts $file "# Fabric Clocks - CLK0 enabled, CLK\[3:1\] disabled by default"
puts $file "############################################################################"
puts $file "set_property -dict \[ list \\"
puts $file "	CONFIG.PCW_FCLK0_PERIPHERAL_CLKSRC \{IO PLL\} \\"
puts $file "	CONFIG.PCW_FCLK1_PERIPHERAL_CLKSRC \{IO PLL\} \\"
puts $file "	CONFIG.PCW_FCLK2_PERIPHERAL_CLKSRC \{IO PLL\} \\"
puts $file "	CONFIG.PCW_FCLK3_PERIPHERAL_CLKSRC \{IO PLL\} \\"
puts $file "	CONFIG.PCW_FCLK_CLK0_BUF \{true\} \\"
puts $file "	CONFIG.PCW_FCLK_CLK1_BUF \{false\} \\"
puts $file "	CONFIG.PCW_FCLK_CLK2_BUF \{false\} \\"
puts $file "	CONFIG.PCW_FCLK_CLK3_BUF \{false\} \\"
puts $file "	CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ \{100\} \\"
puts $file "	CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ \{100\} \\"
puts $file "	CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ \{33.333333\} \\"
puts $file "	CONFIG.PCW_FPGA3_PERIPHERAL_FREQMHZ \{50\} \\"
puts $file "	CONFIG.PCW_EN_CLK0_PORT \{1\} \\"
puts $file "	CONFIG.PCW_EN_CLK1_PORT \{0\} \\"
puts $file "	CONFIG.PCW_EN_CLK2_PORT \{0\} \\"
puts $file "	CONFIG.PCW_EN_CLK3_PORT \{0\} \\"
puts $file "	CONFIG.PCW_EN_RST0_PORT \{1\} \\"
puts $file "	CONFIG.PCW_EN_RST1_PORT \{0\} \\"
puts $file "	CONFIG.PCW_EN_RST2_PORT \{0\} \\"
puts $file "	CONFIG.PCW_EN_RST3_PORT \{0\} \\"
puts $file "\] \[get_bd_cells \]"
puts $file ""
puts $file "############################################################################"
puts $file "# DDR3 "
puts $file "############################################################################"
puts $file "set_property -dict \[ list \\"
puts $file "	CONFIG.PCW_EN_DDR \{1\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_PARTNO \{MT41K256M16 RE-125\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DEVICE_CAPACITY \{4096 MBits\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_T_FAW \{40.0\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_T_RC \{48.75\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_CWL \{6\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DRAM_WIDTH \{16 Bits\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_T_RAS_MIN \{35.0\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_SPEED_BIN \{DDR3_1066F\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_CLOCK_0_LENGTH_MM \{39.7\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_CLOCK_1_LENGTH_MM \{39.7\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_CLOCK_2_LENGTH_MM \{54.14\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_CLOCK_3_LENGTH_MM \{54.14\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DQ_0_LENGTH_MM \{49.59\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DQ_1_LENGTH_MM \{51.74\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DQ_2_LENGTH_MM \{50.32\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DQ_3_LENGTH_MM \{48.55\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DQS_0_LENGTH_MM \{50.05\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DQS_1_LENGTH_MM \{50.43\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DQS_2_LENGTH_MM \{50.10\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DQS_3_LENGTH_MM \{50.01\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE \{1\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL \{1\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE \{1\} \\"
puts $file " 	CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 \{-0.071\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 \{-0.072\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_2 \{0.017\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_3 \{-0.032\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY0 \{0.356\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY1 \{0.364\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY2 \{0.411\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY3 \{0.423\} \\"
puts $file "	CONFIG.PCW_UIPARAM_DDR_USE_INTERNAL_VREF \{1\} \\"
puts $file "\] \[get_bd_cells \]"
puts $file ""
puts $file "############################################################################"
puts $file "# Peripheral assignments"
puts $file "#   with the exception of GPIO:"
puts $file "#   		Pmod: 0, 9-15"
puts $file "#   		LED:  47"
puts $file "#   		PB:   51 "
puts $file "############################################################################"
puts $file "set_property -dict \[ list \\"
puts $file "	CONFIG.PCW_QSPI_GRP_SINGLE_SS_IO \{MIO 1 .. 6\} \\"
puts $file "	CONFIG.PCW_USB0_RESET_IO \{MIO 7\} \\"
puts $file "	CONFIG.PCW_QSPI_GRP_FBCLK_IO \{MIO 8\} \\"
puts $file "	CONFIG.PCW_ENET0_ENET0_IO \{MIO 16 .. 27\} \\"
puts $file "	CONFIG.PCW_USB0_USB0_IO \{MIO 28 .. 39\} \\"
puts $file "	CONFIG.PCW_SD0_SD0_IO \{MIO 40 .. 45\} \\"
puts $file "	CONFIG.PCW_SD0_GRP_CD_IO \{MIO 46\} \\"
puts $file "	CONFIG.PCW_UART1_UART1_IO \{MIO 48 .. 49\} \\"
puts $file "	CONFIG.PCW_SD0_GRP_WP_IO \{MIO 50\} \\"
puts $file "	CONFIG.PCW_ENET0_GRP_MDIO_IO \{MIO 52 .. 53\} \\"
puts $file "	CONFIG.PCW_TTC0_TTC0_IO \{EMIO\} \\"
puts $file "\] \[get_bd_cells \]"
puts $file ""
puts $file "############################################################################"
puts $file "# Enable Peripherals "
puts $file "############################################################################"
puts $file "set_property -dict \[ list \\"
puts $file "	CONFIG.PCW_QSPI_PERIPHERAL_ENABLE \{1\} \\"
puts $file "	CONFIG.PCW_QSPI_GRP_FBCLK_ENABLE \{1\} \\"
puts $file "	CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE \{1\} \\"
puts $file "	CONFIG.PCW_USB0_PERIPHERAL_ENABLE \{1\} \\"
puts $file "	CONFIG.PCW_ENET0_PERIPHERAL_ENABLE \{1\} \\"
puts $file "	CONFIG.PCW_ENET0_GRP_MDIO_ENABLE \{1\} \\"
puts $file "	CONFIG.PCW_SD0_PERIPHERAL_ENABLE \{1\} \\"
puts $file "	CONFIG.PCW_SD0_GRP_CD_ENABLE \{1\} \\"
puts $file "	CONFIG.PCW_SD0_GRP_WP_ENABLE \{1\} \\"
puts $file "	CONFIG.PCW_UART1_PERIPHERAL_ENABLE \{1\} \\"
puts $file "	CONFIG.PCW_GPIO_PERIPHERAL_ENABLE \{1\} \\"
puts $file "	CONFIG.PCW_GPIO_MIO_GPIO_ENABLE \{1\} \\"
puts $file "	CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE \{0\} \\"
puts $file "	CONFIG.PCW_TTC0_PERIPHERAL_ENABLE \{1\} \\"
puts $file "\] \[get_bd_cells \]"
puts $file ""
puts $file "############################################################################"
puts $file "# Configure MIOs"
puts $file "#   - disable all pull-ups"
puts $file "#   - slew set to SLOW"
puts $file "############################################################################"
puts $file "set_property -dict \[ list \\"
puts $file "	CONFIG.PCW_MIO_0_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_1_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_2_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_3_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_4_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_5_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_6_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_7_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_8_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_9_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_10_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_11_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_12_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_13_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_14_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_15_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_16_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_17_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_18_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_19_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_20_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_21_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_22_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_23_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_24_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_25_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_26_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_27_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_28_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_29_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_30_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_31_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_32_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_33_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_34_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_35_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_36_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_37_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_38_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_39_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_40_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_41_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_42_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_43_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_44_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_45_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_46_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_47_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_48_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_49_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_50_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_51_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_52_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_53_PULLUP \{disabled\} \\"
puts $file "	CONFIG.PCW_MIO_0_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_1_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_2_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_3_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_4_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_5_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_6_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_7_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_8_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_9_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_10_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_11_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_12_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_13_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_14_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_15_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_16_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_17_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_18_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_19_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_20_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_21_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_22_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_23_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_24_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_25_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_26_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_27_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_28_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_29_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_30_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_31_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_32_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_33_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_34_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_35_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_36_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_37_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_38_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_39_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_40_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_41_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_42_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_43_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_44_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_45_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_46_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_47_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_48_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_49_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_50_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_51_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_52_SLEW \{slow\} \\"
puts $file "	CONFIG.PCW_MIO_53_SLEW \{slow\} \\"
puts $file "\] \[get_bd_cells \]"
puts $file ""
puts $file "############################################################################"
puts $file "# Enable USB Reset last"
puts $file "############################################################################"
puts $file "set_property -dict \[ list \\"
puts $file "	CONFIG.PCW_USB0_RESET_ENABLE \{1\} \\"
puts $file "\] \[get_bd_cells \]"
puts $file ""
puts $file "############################################################################"
puts $file "# End MicroZed Presets "
puts $file "############################################################################"
puts $file ""

close $file
return -code ok

}


# ########################################################################################
# make doc/project_name/make_ip_configuration_parameters_readme.txt file

proc ::tclapp::icl::protoip::make_template::make_ip_configuration_parameters_readme_txt {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set project_name [lindex $args 0]


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
set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 
set type_template [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 16]] 


set dir_name ""
append dir_name "doc/" $project_name
file mkdir $dir_name

set  file_name ""
append file_name "doc/" $project_name "/ip_configuration_parameters.txt"

set file [open $file_name w]

set tmp_line ""
append tmp_line "Template type: " $type_template
puts $file $tmp_line
puts $file ""
puts $file ""
puts $file "---------------------------------------------------------"
puts $file "Input and output vectors:"
puts $file "---------------------------------------------------------"
puts $file ""
puts $file "Name			| Direction		| Number of data 			| Data representation"
puts $file ""
set m 0
foreach i $input_vectors { 
	set tmp_line ""
	append tmp_line $i "			 	| Input         | [string toupper [lindex $input_vectors $m]]_IN_LENGTH=[lindex $input_vectors_length $m] 			|data type \"data_t_" $i "_in\" is "
	if {[lindex $input_vectors_type $m]==0} { #floating point
		append tmp_line "floating-point single precision (32 bits)"
	} else {
		append tmp_line "fixed-point: " [string toupper [lindex $input_vectors $m]] "_IN_INTEGERLENGTH=" [lindex $input_vectors_integer_length $m] "  bits integer length, " [string toupper [lindex $input_vectors $m]] "_IN_FRACTIONLENGTH=" [lindex $input_vectors_fraction_length $m] "  bits fraction length"
	}
	puts $file $tmp_line
	incr m
}
set m 0
foreach i $output_vectors {
	set tmp_line ""
	append tmp_line $i "			 	| Output         | [string toupper [lindex $output_vectors $m]]_OUT_LENGTH=[lindex $output_vectors_length $m] 			|data type \"data_t_" $i "_in\" is "
	if {[lindex $output_vectors_type $m]==0} { #floating point
		append tmp_line "floating-point single precision (32 bits)"
	} else {
		append tmp_line "fixed-point: " [string toupper [lindex $output_vectors $m]] "_OUT_INTEGERLENGTH=" [lindex $output_vectors_integer_length $m] "  bits integer length, " [string toupper [lindex $output_vectors $m]] "_OUT_FRACTIONLENGTH=" [lindex $output_vectors_fraction_length $m] "  bits fraction length"
	}
	puts $file $tmp_line
	incr m

}
puts $file ""
puts $file "NOTES: 1) the following constants are defined in ip_design/src/foo_data.h and are used by ip_design/src/foo.cpp, ip_design/src/foo_user.cpp and ip_design/src/foo_test.cpp"
puts $file "       2) ip_design/src/foo_data.h is generated automatically, please do not edit manually."
puts $file ""

puts $file "// FLOAT_FIX_VECTOR_NAME=1 to enable  fixed-point (up to 32 bits word length) arithmetic precision or "
puts $file "// FLOAT_FIX_VECTOR_NAME=0 to enable floating-point single arithmetic precision."

set m 0
foreach i $input_vectors {
	set tmp_line ""
	if { [lindex $input_vectors_type $m] == 1} {  
		append tmp_line "FLOAT_FIX_[string toupper $i]_IN=1"
	} else {  
		append tmp_line "FLOAT_FIX_[string toupper $i]_IN=0"
	}
	puts $file $tmp_line
	incr m
}

set m 0
foreach i $output_vectors {
	set tmp_line ""
	if { [lindex $output_vectors_type $m] == 1} {  
		append tmp_line "FLOAT_FIX_[string toupper $i]_OUT=1"
	} else {  
		append tmp_line "FLOAT_FIX_[string toupper $i]_OUT=0"
	}
	puts $file $tmp_line
	incr m
}



puts $file ""
puts $file "// Input vectors INTEGERLENGTH:"
set m 0
foreach i $input_vectors {
	set tmp_line ""
	append tmp_line "[string toupper $i]_IN_INTEGERLENGTH=[lindex $input_vectors_integer_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file "// Output vectors INTEGERLENGTH:"
set m 0
foreach i $output_vectors {
	set tmp_line ""
	append tmp_line "[string toupper $i]_OUT_INTEGERLENGTH=[lindex $output_vectors_integer_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file ""



puts $file "// Input vectors FRACTIONLENGTH:"
set m 0
foreach i $input_vectors {
	set tmp_line ""
	append tmp_line "[string toupper $i]_IN_FRACTIONLENGTH=[lindex $input_vectors_fraction_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file "// Output vectors FRACTIONLENGTH:"
set m 0
foreach i $output_vectors {
	set tmp_line ""
	append tmp_line "[string toupper $i]_OUT_FRACTIONLENGTH=[lindex $output_vectors_fraction_length $m]"
	puts $file $tmp_line
	incr m
}





puts $file ""
puts $file "//Input vectors size:"
set m 0
foreach i $input_vectors {
	set tmp_line ""
	append tmp_line "[string toupper $i]_IN_LENGTH=[lindex $input_vectors_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file "//Output vectors size:"
set m 0
foreach i $output_vectors {
	set tmp_line ""
	append tmp_line "[string toupper $i]_OUT_LENGTH=[lindex $output_vectors_length $m]"
	puts $file $tmp_line
	incr m
}


puts $file ""
puts $file ""
puts $file "---------------------------------------------------------"
puts $file "FPGA circuit clock frequency"
puts $file "---------------------------------------------------------"
set tmp_line ""
append tmp_line $fclk " MHz"
puts $file $tmp_line
puts $file ""
puts $file "NOTE: This clock is also used to clock the IP axi-master and axi-slave interface. Please do not exceed 200MHz in order to guarantee time closure during the ip_prototype_build phase."
puts $file ""
puts $file ""
puts $file "---------------------------------------------------------"
puts $file "FPGA name"
puts $file "---------------------------------------------------------"
set tmp_line ""
append tmp_line $FPGA_name
puts $file $tmp_line
puts $file ""
puts $file "NOTE: Any Xilinx 7 Series and Zynq®-7000 are supported, but only a some of them are supported if the purpose is to prototype the designed IP."
puts $file ""
puts $file ""
puts $file "---------------------------------------------------------"
puts $file "Evaluation Borad name"
puts $file "---------------------------------------------------------"
set tmp_line ""
append tmp_line $board_name
puts $file $tmp_line
puts $file ""
puts $file "NOTE: Prototype is available only on the supported Evaluation boards which mount the following FPGAs:"
puts $file "- zedboard : FPGA name should be xc7z020clg484-1"
puts $file "- microzedboard : FPGA name should be xc7z020clg400-1"
puts $file "- zc702 : FPGA name should be xc7z020clg484-1"
puts $file "- zc706 : FPGA name should be xc7z045ffg900-2"
puts $file ""
puts $file ""
puts $file "---------------------------------------------------------"
puts $file "Ethernet connection type"
puts $file "---------------------------------------------------------"
set tmp_line ""
if {$type_eth==0} {
	append tmp_line "UDP-IP"
} elseif {$type_eth==1} {
	append tmp_line "TCP-IP"
} 
puts $file $tmp_line
puts $file ""
puts $file ""
puts $file "---------------------------------------------------------"
puts $file "DDR3 memory base address"
puts $file "---------------------------------------------------------"
set tmp_line ""
append tmp_line $mem_base_address
puts $file $tmp_line
puts $file ""
puts $file ""
puts $file "---------------------------------------------------------"
puts $file "Number of test(s)"
puts $file "---------------------------------------------------------"
set tmp_line ""
append tmp_line $num_test
puts $file $tmp_line
puts $file ""
puts $file ""
puts $file "---------------------------------------------------------"
puts $file "Type of C/RTL test(s): c, xsim, modelsim"
puts $file "---------------------------------------------------------"
set tmp_line ""
if {$type_test==0} {
	append tmp_line "No C/RTL test(s) selected"
} elseif {$type_test==1} {
	append tmp_line "c"
} elseif {$type_test==2} {
	append tmp_line "xsim"
} elseif {$type_test==3} {
	append tmp_line "modelsim"
} 
puts $file $tmp_line



puts $file ""
puts $file ""
puts $file "---------------------------------------------------------"
puts $file "IP design C/RTL test(s):"
puts $file "Input and output vectors has been mapped into a virtual memory at the following addresses:"
puts $file "---------------------------------------------------------"
puts $file ""
puts $file "Name			| Base address in Byte"
puts $file ""
set vectors_list [concat $input_vectors $output_vectors]
set vectors_list_length [concat $input_vectors_length $output_vectors_length]
set address_store_name "0"
set address_store "0"
set m 0
foreach i $input_vectors { 
		set tmp_line ""
		append tmp_line $i "			 	| 0x[format %08X $address_store] <- $address_store_name"
		puts $file $tmp_line
		unset tmp_line
		set address_store [expr $address_store+([lindex $vectors_list_length $m])*4]
		set address_store_name {(}
		for {set j 0} {$j <= $m} {incr j} {
			append address_store_name "[string toupper [lindex $input_vectors $j]]_IN_LENGTH"
			if {$j==$m} {
				append address_store_name ")*4"
			} else {
				append address_store_name "+"
			}
		}
		incr m
}

foreach i $output_vectors {
		set tmp_line ""
		append tmp_line $i "			 	| 0x[format %08X $address_store] <- $address_store_name"
		puts $file $tmp_line
		unset tmp_line
		set address_store [expr $address_store+([lindex $vectors_list_length $m])*4]
		set address_store_name {(}
		set count_j 0
		foreach j $input_vectors { 
			append address_store_name "[string toupper $j]_IN_LENGTH+"
			incr count_j
		}
		for {set j $count_j} {$j <= $m} {incr j} {
			append address_store_name "[string toupper [lindex $output_vectors [expr $j-$count_j]]]_OUT_LENGTH"
			if {$j==$m} {
				append address_store_name ")*4"
			} else {
				append address_store_name "+"
			}
		}
		incr m
}


puts $file ""
puts $file ""
puts $file "---------------------------------------------------------"
puts $file "IP prototype test(s):"
puts $file "Input and output vectors has been mapped into external DDR3 memory at the following addresses:"
puts $file "---------------------------------------------------------"
puts $file ""
puts $file "Name			| Base address in Byte"
puts $file ""
set vectors_list [concat $input_vectors $output_vectors]
set vectors_list_length [concat $input_vectors_length $output_vectors_length]
set address_store_name "0"
set address_store $mem_base_address
set m 0
foreach i $input_vectors { 
		set tmp_line ""
		append tmp_line $i "			 	| 0x[format %08X $address_store] <- $address_store_name"
		puts $file $tmp_line
		unset tmp_line
		set address_store [expr $address_store+([lindex $vectors_list_length $m])*4]
		set address_store_name {(}
		for {set j 0} {$j <= $m} {incr j} {
			append address_store_name "[string toupper [lindex $input_vectors $j]]_IN_LENGTH"
			if {$j==$m} {
				append address_store_name ")*4"
			} else {
				append address_store_name "+"
			}
		}
		incr m
}

foreach i $output_vectors {
		set tmp_line ""
		append tmp_line $i "			 	| 0x[format %08X $address_store] <- $address_store_name"
		puts $file $tmp_line
		unset tmp_line
		set address_store [expr $address_store+([lindex $vectors_list_length $m])*4]
		set address_store_name {(}
		set count_j 0
		foreach j $input_vectors { 
			append address_store_name "[string toupper $j]_IN_LENGTH+"
			incr count_j
		}
		for {set j $count_j} {$j <= $m} {incr j} {
			append address_store_name "[string toupper [lindex $output_vectors [expr $j-$count_j]]]_OUT_LENGTH"
			if {$j==$m} {
				append address_store_name ")*4"
			} else {
				append address_store_name "+"
			}
		}
		incr m
}



puts $file ""
puts $file "NOTE: the external DDR memory is shared memory between the CPU embedded into the FPGA and the Algorithm implemented into the FPGA programmable logic (PL)."
puts $file ""
puts $file ""
puts $file "To send input vectors from the host (Matlab) to the FPGA call Matlab function \"FPGAclientMATLAB\" in \"test_HIL.m\" using the following parameters:"
puts $file ""
puts $file "Input vector name		| Packet type 	|	Packet internal ID 	| Data to send	| Packet output size"
set m 0
foreach i $input_vectors { 
		append tmp_line $i "			 			| 3				| " $m "						| data vector	| 0"
		puts $file $tmp_line
		unset tmp_line
		incr m
}
puts $file ""
puts $file ""
puts $file ""
puts $file "To read output vectors from the FPGA to the host PC call Matlab function \"FPGAclientMATLAB\" in \"test_HIL.m\" using the following parameters:"
puts $file ""
puts $file "Output vector name		| Packet type 	|	Packet internal ID 	| Data to send	| Packet output size"
set m 0
foreach i $output_vectors { 
		append tmp_line $i "			 			| 4				| " $m "						| 0				| [lindex $output_vectors_length $m]"
		puts $file $tmp_line
		unset tmp_line
		incr m
}

close $file

return -code ok

}


# ########################################################################################
# make ip_prototype/src/build_sdk_project.tcl file

proc ::tclapp::icl::protoip::make_template::make_build_sdk_project_tcl {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set file [open  .metadata/build_sdk_project.tcl w]


#add license_tcl header
[::tclapp::icl::protoip::make_template::license_tcl $file]


puts $file ""

puts $file "set workspace_name \"workspace1\""
puts $file "set hdf \"design_1_wrapper.hdf\""
puts $file ""
puts $file "sdk set_workspace \$workspace_name"
puts $file "sdk create_hw_project -name design_1_wrapper_hw_platform_1 -hwspec \$hdf"
puts $file "sdk create_app_project -name test_fpga -proc ps7_cortexa9_0 -hwproject design_1_wrapper_hw_platform_1 -lang C  -app {lwIP Echo Server}"
puts $file ""
puts $file "file copy -force ../../../src/echo.c workspace1/test_fpga/src"
puts $file "file copy -force ../../../src/main.c workspace1/test_fpga/src"
puts $file "file copy -force ../../../src/FPGAserver.h workspace1/test_fpga/src"
puts $file ""
puts $file "sdk build_project -type all"



close $file

return -code ok

}

# ########################################################################################
# make ip_prototype/src/run_fpga_prototype.tcl file

proc ::tclapp::icl::protoip::make_template::make_run_fpga_prototype_tcl {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set file [open  .metadata/run_fpga_prototype.tcl w]


#add license_tcl header
[::tclapp::icl::protoip::make_template::license_tcl $file]


puts $file ""

puts $file "connect arm hw"
puts $file "source workspace1/design_1_wrapper_hw_platform_1/ps7_init.tcl"
puts $file "ps7_init"
puts $file "fpga -f workspace1/design_1_wrapper_hw_platform_1/design_1_wrapper.bit"
puts $file "ps7_post_config"
puts $file "rst -processor"
puts $file "dow workspace1/test_fpga/Release/test_fpga.elf"
puts $file "run"


close $file

return -code ok

}


# ########################################################################################
# make .metadata/load_configuration_parameters.m file

proc ::tclapp::icl::protoip::make_template::make_load_configuration_parameters_m {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:

set file [open  .metadata/load_configuration_parameters.m w]


#add license_m header
[::tclapp::icl::protoip::make_template::license_m $file]

puts $file "function load_configuration_parameters(project_name)"
puts $file ""
puts $file "    filename=strcat(project_name,'_configuration_parameters.dat');"
puts $file "    fileID=fopen(filename,'r');"
puts $file "    tmp=textscan(fileID, '%s');"
puts $file "    fclose(fileID);"
puts $file "    configuration_parameters=tmp\{1,1\};"
puts $file "    num_inputs_value=str2double(configuration_parameters\{4,1\});"
puts $file "    num_outputs_value=str2double(configuration_parameters\{6+num_inputs_value*5,1\});"
puts $file ""
puts $file "    assignin('caller', 'num_inputs', num_inputs_value)"
puts $file "    assignin('caller', 'num_outputs', num_outputs_value)"
puts $file "    "
puts $file "    for i=0:num_inputs_value-1"
puts $file "        %size"
puts $file "        tmp_str=strcat(upper(configuration_parameters\{5+i*5,1\}),'_IN_LENGTH');"
puts $file "        input_size=str2double(configuration_parameters\{6+i*5,1\});"
puts $file "        assignin('caller', tmp_str, input_size);"
puts $file "        %float_fix=0 if floating point, float_fix=1 if fixed-point"
puts $file "        tmp_str=strcat('FLOAT_FIX_',upper(configuration_parameters\{5+i*5,1\}),'_IN');"
puts $file "        input_size=str2double(configuration_parameters\{7+i*5,1\});"
puts $file "        assignin('caller', tmp_str, input_size);"
puts $file "        %integer length"
puts $file "        tmp_str=strcat(upper(configuration_parameters\{5+i*5,1\}),'_IN_INTEGERLENGTH');"
puts $file "       input_size=str2double(configuration_parameters\{8+i*5,1\});"
puts $file "        assignin('caller', tmp_str, input_size);"
puts $file "        %fraction length"
puts $file "        tmp_str=strcat(upper(configuration_parameters\{5+i*5,1\}),'_IN_FRACTIONLENGTH');"
puts $file "        input_size=str2double(configuration_parameters\{9+i*5,1\});"
puts $file "        assignin('caller', tmp_str, input_size);"
puts $file "        "
puts $file "    end"
puts $file "    "
puts $file "    for i=0:num_outputs_value-1"
puts $file "        %size"
puts $file "        tmp_str=strcat(upper(configuration_parameters\{7+5*num_inputs_value+i*5,1\}),'_OUT_LENGTH');"
puts $file "        input_size=str2double(configuration_parameters\{8+5*num_inputs_value+i*5,1\});"
puts $file "        assignin('caller', tmp_str, input_size);"
puts $file "        %float_fix=0 if floating point, float_fix=1 if fixed-point"
puts $file "        tmp_str=strcat('FLOAT_FIX_',upper(configuration_parameters\{7+5*num_inputs_value+i*5,1\}),'_IN');"
puts $file "        input_size=str2double(configuration_parameters\{9+5*num_inputs_value+i*5,1\});"
puts $file "        assignin('caller', tmp_str, input_size);"
puts $file "        %integer length"
puts $file "        tmp_str=strcat(upper(configuration_parameters\{7+5*num_inputs_value+i*5,1\}),'_IN_INTEGERLENGTH');"
puts $file "        input_size=str2double(configuration_parameters\{10+5*num_inputs_value+i*5,1\});"
puts $file "        assignin('caller', tmp_str, input_size);"
puts $file "        %fraction length"
puts $file "        tmp_str=strcat(upper(configuration_parameters\{7+5*num_inputs_value+i*5,1\}),'_IN_FRACTIONLENGTH');"
puts $file "        input_size=str2double(configuration_parameters\{11+5*num_inputs_value+i*5,1\});"
puts $file "        assignin('caller', tmp_str, input_size);"
puts $file "    end"
puts $file "    "
puts $file "    num_test_value=str2double(configuration_parameters\{18+num_inputs_value*5+num_outputs_value*5,1\});"
puts $file "    assignin('caller', 'NUM_TEST', num_test_value);"
puts $file "    "
puts $file "    type_test_value=str2double(configuration_parameters\{20+num_inputs_value*5+num_outputs_value*5,1\});"
puts $file "    assignin('caller', 'TYPE_TEST', type_test_value);"
puts $file ""
puts $file "    type_design_flow=(configuration_parameters\{24+num_inputs_value*5+num_outputs_value*5,1\});"
puts $file "    assignin('caller', 'TYPE_DESIGN_FLOW', type_design_flow);"
puts $file ""
puts $file "end"

close $file

return -code ok

}


# ########################################################################################
# make ip_design/src/FPGAclientAPI.h file

proc ::tclapp::icl::protoip::make_template::make_FPGAclientAPI_h {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:
  
set project_name [lindex $args 0]


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
set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 

if ($type_test!=0) {
	set mem_base_address 0
}

set file [open ip_design/src/FPGAclientAPI.h w]


#add license_c header
[::tclapp::icl::protoip::make_template::license_c $file]

puts $file ""
puts $file "#include<stdio.h>"
puts $file "#include<stdlib.h>"
puts $file ""
puts $file "#ifdef _WIN32"
puts $file "	#include<winsock2.h>"
puts $file "	#include<time.h>"
puts $file "	#pragma comment(lib,\"ws2_32.lib\")"
puts $file "#else"
puts $file "	#include<sys/socket.h>"
puts $file "	#include<arpa/inet.h>"
puts $file "	#include<netinet/in.h>"
puts $file "	#include<netdb.h>"
puts $file "	#include<sys/select.h>"
puts $file "	#include<sys/time.h>"
puts $file "    #include<unistd.h>"
puts $file "#endif"
puts $file "#include<stdint.h>"
puts $file "#include<string.h>"
puts $file "#include<fcntl.h>"
puts $file "#include <math.h>"
puts $file ""
puts $file ""



puts $file "////////////////////////////////////////////////////////////"
puts $file ""
puts $file "//Input vectors size:"
set m 0
foreach i $input_vectors {
	set tmp_line ""
	append tmp_line "#define [string toupper $i]_IN_LENGTH [lindex $input_vectors_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file "//Output vectors size:"
set m 0
foreach i $output_vectors {
	set tmp_line ""
	append tmp_line "#define [string toupper $i]_OUT_LENGTH [lindex $output_vectors_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file ""
puts $file ""


puts $file "////////////////////////////////////////////////////////////"
puts $file "//Test configuration:"
set tmp_line ""
append tmp_line "#define TYPE_TEST " $type_test
puts $file $tmp_line


puts $file ""
puts $file ""
puts $file "////////////////////////////////////////////////////////////"
puts $file ""
puts $file "//Ethernet interface configuration:"
if { $type_eth == 1} { 
puts $file "#define TYPE_ETH 1 //1 for TCP, 0 for UDP"
} elseif  { $type_eth == 0} { 
puts $file "#define TYPE_ETH 0 //1 for TCP, 0 for UDP"
}
puts $file "#define FPGA_IP \"192.168.1.10\" //FPGA IP"
puts $file "#define FPGA_NM \"255.255.255.0\" //Netmask"
puts $file "#define FPGA_GW \"192.168.1.1\" //Gateway"
puts $file "#define FPGA_PORT 2007"
puts $file ""
puts $file ""
puts $file "///////////////////////////////////////////////////////////////"
puts $file ""
puts $file "//FPGA interface data specification:"
puts $file "#define ETH_PACKET_LENGTH 256+2 //Ethernet packet length in double words (32 bits) (from Matlab to  FPGA)"
puts $file "#define ETH_PACKET_LENGTH_RECV 64+2 //Ethernet packet length in double words (32 bits) (from FPGA to Matlab)"
puts $file ""
puts $file ""
puts $file ""
puts $file ""
puts $file "///////////////////////////////////////////////////////////////"
puts $file ""
puts $file "int FPGAclient(double input_data\[\], unsigned packet_input_size, unsigned Packet_type, unsigned packet_internal_ID, unsigned packet_output_size, double output_data\[\], double *FPGA_time)"
puts $file "\{"
puts $file "	"
puts $file "	double input_data_eth\[ETH_PACKET_LENGTH\];"
puts $file "	double output_data_eth\[ETH_PACKET_LENGTH_RECV\];"
puts $file "	double packet_internal_ID_offset;"
puts $file "	int float_fix;"
puts $file "	int fraction_length;"
puts $file "	unsigned FPGA_port_number;"
puts $file "	unsigned FPGA_link;"
puts $file "	char *FPGA_ip_address;"
puts $file "	unsigned i;"
puts $file "	unsigned j;"
puts $file "	int flag;"
puts $file "	int count_send;"
puts $file "	double flag_IP_running;"
puts $file "	"
puts $file "	//FPGA IP address"
puts $file "	FPGA_ip_address = FPGA_IP;"
puts $file ""
puts $file "	//FPGA port"
puts $file "	FPGA_port_number=FPGA_PORT;"
puts $file ""
puts $file "	//FPGA link"
puts $file "	FPGA_link=TYPE_ETH;"
puts $file "	"
puts $file "	packet_internal_ID_offset=0;"
puts $file "	"

puts $file "	   #if (TYPE_TEST==0) //IP design build, IP prototype"
puts $file "    "
puts $file "	   if (Packet_type==4) //data read"
puts $file "	    \{"
puts $file "		"
puts $file "	       //read the output vector in chunks of ETH_PACKET_LENGTH_RECV-2 elements"
puts $file "	       for (i=0; i<packet_output_size; i=i+ETH_PACKET_LENGTH_RECV-2)"
puts $file "	       //     for (i=0; i<1; i++)"
puts $file "		\{"
puts $file "		"
# puts $file "			flag_IP_running=1;"
# puts $file "			"
# puts $file "			while(flag_IP_running==1)"
# puts $file "				\{"
# puts $file "				"
puts $file "					//fill in the vector buffer to be sent to Ethernet"
puts $file "					"
puts $file "					//vector label"
puts $file "					input_data_eth\[ETH_PACKET_LENGTH-2\]=(double)pow(2,16)*packet_internal_ID+Packet_type; "       
puts $file "					input_data_eth\[ETH_PACKET_LENGTH-1\]=packet_internal_ID_offset;"
puts $file "					"
puts $file "					"
puts $file "					// main call"
puts $file "					if (FPGA_link==1) //TCP interface"
puts $file "						flag=TCPclient_wrap(FPGA_ip_address,FPGA_port_number,input_data_eth,Packet_type,output_data_eth,float_fix,fraction_length);"
puts $file "				    else"
puts $file "					   flag=UDPclient_wrap(FPGA_ip_address,FPGA_port_number,input_data_eth,Packet_type,output_data_eth,float_fix,fraction_length);"
puts $file "	 "
puts $file "					*FPGA_time=output_data_eth\[ETH_PACKET_LENGTH_RECV-1\];"
# puts $file "					"
# puts $file "					flag_IP_running=output_data_eth\[ETH_PACKET_LENGTH_RECV-2\];"
# puts $file "					if (flag_IP_running==1)"
# puts $file "						printf(\"Waiting FPGA is running ...\\n\");"
# puts $file "				"
# puts $file "				\}"
puts $file "		    "
puts $file "		    // assemble the read chucks into the output vector "
puts $file "		    for (j=0; ((j<ETH_PACKET_LENGTH_RECV-2) && (packet_internal_ID_offset*(ETH_PACKET_LENGTH_RECV-2)+j<packet_output_size)); j++) {"
puts $file "			output_data\[(unsigned)packet_internal_ID_offset*(ETH_PACKET_LENGTH_RECV-2)+j\]=output_data_eth\[j\];"
puts $file "		    } "
puts $file "		    "
puts $file "		    packet_internal_ID_offset++;"
puts $file "			"
puts $file "		\}"
puts $file "	    \}"
puts $file "	    else"
puts $file "	    \{"
puts $file "	    count_send=0;"
puts $file "		//split the input vector in chunks of ETH_PACKET_LENGTH-2 elements"
puts $file "		for (i=0; i<packet_input_size; i=i+ETH_PACKET_LENGTH-2)"
puts $file "		\{"
puts $file "		   "
puts $file "		   count_send++;"
puts $file "				if ( count_send == 8 ) //every 8 packets sent, FPGAclientAPI wait the server have finished all the writing operations."
puts $file "				\{"
puts $file "	    			count_send=0;"
puts $file "					Packet_type=5;"
puts $file "					//vector label"
puts $file "					input_data_eth\[ETH_PACKET_LENGTH-2\]=(double)pow(2,16)*packet_internal_ID+Packet_type;"
puts $file "					input_data_eth\[ETH_PACKET_LENGTH-1\]=packet_internal_ID_offset;"
puts $file "					// main call, it is a read request: blocking operation"
puts $file "					if (FPGA_link==1) //TCP interface"
puts $file "					   flag=TCPclient_wrap(FPGA_ip_address,FPGA_port_number,input_data_eth,Packet_type,output_data_eth,float_fix,fraction_length);"
puts $file "					else"
puts $file "						flag=UDPclient_wrap(FPGA_ip_address,FPGA_port_number,input_data_eth,Packet_type,output_data_eth,float_fix,fraction_length);"
puts $file "		   "
puts $file "					Packet_type=3;"				
puts $file "				 \}"
puts $file "		"
puts $file "		    //fill in the vector buffer to be sent to Ethernet"
puts $file "		    "
puts $file "		    //vector data"
puts $file "		    for (j=0; (j<(ETH_PACKET_LENGTH-2) && (packet_internal_ID_offset*(ETH_PACKET_LENGTH-2)+j<packet_input_size)); j++) {"
puts $file "			input_data_eth\[j\]=input_data\[(unsigned)packet_internal_ID_offset*(ETH_PACKET_LENGTH-2)+j\];"
puts $file "		    }  "
puts $file "		    //vector label"
puts $file "		    input_data_eth\[ETH_PACKET_LENGTH-2\]=(double)pow(2,16)*packet_internal_ID+Packet_type;   "     
puts $file "		    input_data_eth\[ETH_PACKET_LENGTH-1\]=packet_internal_ID_offset;"
puts $file ""
puts $file "		    "
puts $file ""
puts $file "		    // main call "
puts $file "		    if (FPGA_link==1) //TCP interface"
puts $file "		       flag=TCPclient_wrap(FPGA_ip_address,FPGA_port_number,input_data_eth,Packet_type,output_data_eth,float_fix,fraction_length);"
puts $file "		   else"
puts $file "		       flag=UDPclient_wrap(FPGA_ip_address,FPGA_port_number,input_data_eth,Packet_type,output_data_eth,float_fix,fraction_length);"
puts $file "		   "
puts $file "		   packet_internal_ID_offset++;"
puts $file ""
puts $file "		\}"
puts $file "		"
puts $file "	    \}"
puts $file "		#else // IP design test"
puts $file "			switch (Packet_type)"
puts $file "			\{"



set tmp_line ""
puts $file "			case 2:"
puts $file "				start_simulation();"
puts $file "				break;"
puts $file "			case 3:"
puts $file "				write_stimuli(input_data, packet_internal_ID);"
puts $file "				break;"
puts $file "			case 4:"
puts $file "				read_results(output_data, packet_internal_ID, packet_output_size);"
puts $file "				break;"
puts $file "			default:"
puts $file "				break;"
puts $file "			\}"



puts $file "		#endif"
puts $file "	"
puts $file "	"
puts $file "\}"
puts $file ""
puts $file ""
puts $file ""
puts $file "int UDPclient_wrap(char ip_address\[\], unsigned port_number, double din\[ETH_PACKET_LENGTH\], unsigned Packet_type, double dout\[ETH_PACKET_LENGTH_RECV\], int float_fix, int fraction_length)"
puts $file "\{"
puts $file "    "
puts $file "    int socket_handle; // Handle for the socket"
puts $file "    int connect_id; // Connection ID"
puts $file "    struct sockaddr_in server_address;	// Server address"
puts $file "	struct sockaddr_in client_address;	// client address"
puts $file "    int saddr_len = sizeof(server_address); // Server address length"
puts $file "	int caddr_len = sizeof(client_address); // Client address length"
puts $file "    struct hostent *server;		// Server host entity"
puts $file "	struct hostent *client;		// Client host entity"
puts $file "    int n;						// Iterator"
puts $file "    int k;						// Iterator"
puts $file "	int i;"
puts $file "    struct timeval tv;			// Select timeout structure"
puts $file "    fd_set Reader;				// Struct for select function"
puts $file "    int err;					// Error flag for return data"
puts $file "    int ss;						// Return from select function"
puts $file "	"
puts $file "	int timeout;				//timeout \[s\]"
puts $file "	char host_name\[256\];		// Host name of this computer "
puts $file "    "
puts $file "    int32_t tmp_databuffer;"
puts $file "	"
puts $file "    float databuffer_float\[ETH_PACKET_LENGTH\];		// Buffer for outgoing data"
puts $file "    float incoming_float\[ETH_PACKET_LENGTH_RECV\];			// Buffer for return data"
puts $file "	"
puts $file ""
puts $file "	#ifdef _WIN32"
puts $file "		WSADATA wsaData;"
puts $file "	#endif"
puts $file ""
puts $file "    int tmp_time;"
puts $file ""
puts $file "	// Platform specific variables for timing "
puts $file "    #ifdef _WIN32"
puts $file "        LARGE_INTEGER t1;"
puts $file "        LARGE_INTEGER t2;"
puts $file "        LARGE_INTEGER freq;"
puts $file "   #else"
puts $file "        struct timeval t1;          // For timing call length"
puts $file "        struct timeval t2;          // For timing call length"
puts $file "   #endif "
puts $file ""
puts $file " "
puts $file "    #ifdef _WIN32"
puts $file "    	int iResult;"
puts $file "		// Open windows connection"
puts $file "		iResult = WSAStartup(MAKEWORD(2,2), &wsaData);"
puts $file "		if (iResult != 0) \{"
puts $file "	    	printf(\"Could not open Windows connection. WSAStartup failed: %d\\n\", iResult);"
puts $file "    		return 1;"
puts $file "		\}"
puts $file "	#endif"
puts $file ""
puts $file ""
puts $file ""
puts $file "	server = gethostbyname(ip_address);"
puts $file "	port_number = port_number;"
puts $file "	timeout=86400; //timeout in seconds: 1 day"
puts $file ""
puts $file "	"
puts $file ""
puts $file ""
puts $file "    if (server == NULL) \{"
puts $file "        fprintf(stderr,\"ERROR, no such host1\\n\");"
puts $file "		#ifdef _WIN32"
puts $file "			WSACleanup();"
puts $file "		#endif"
puts $file "		return 1;"
puts $file "    \}"
puts $file "    "
puts $file "    // Open a datagram socket."
puts $file "    socket_handle = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);"
puts $file "    if (socket_handle == 0xFFFF)\{"
puts $file "        printf(\"Could not create socket.\\n\");"
puts $file "		#ifdef _WIN32"
puts $file "			WSACleanup();"
puts $file "		#endif"
puts $file "		return 1;"
puts $file "    \}"
puts $file "    "
puts $file "    "
puts $file "    // Clear out server struct"
puts $file "    memset( (void *) &server_address, 0, sizeof(server_address));"
puts $file "   "
puts $file "	//Set family and port"
puts $file "    server_address.sin_family = AF_INET;"
puts $file "	server_address.sin_port = htons(port_number);"
puts $file "    "
puts $file "    //Set server address"
puts $file "	memcpy((char *)&server_address.sin_addr.s_addr,"
puts $file "          (char *)server->h_addr,"
puts $file "          server->h_length);"
puts $file ""
puts $file "	"
puts $file ""
puts $file ""
puts $file "	"
puts $file "	#ifdef _WIN32"
puts $file "        QueryPerformanceCounter(&t1);"
puts $file "    #else"
puts $file "        gettimeofday(&t1, NULL);"
puts $file "    #endif"
puts $file "    "
puts $file "    // Set timeout values"
puts $file "   "
puts $file "    tv.tv_sec = timeout;"
puts $file "    tv.tv_usec = 0;"
puts $file "    "
puts $file "    // Set FDS u/p"
puts $file "    "
puts $file "    FD_ZERO(&Reader);"
puts $file "    FD_SET(socket_handle, &Reader);"
puts $file ""
puts $file ""
puts $file "	// Input data cast to float"
puts $file "	for ( i = 0; i < ETH_PACKET_LENGTH; i++)"
puts $file "		databuffer_float\[i\]=(float)din\[i\];"
puts $file "    "
puts $file "	// Send data to FPGA"
puts $file "    err = sendto(socket_handle, (void *)databuffer_float, sizeof(databuffer_float), 0,(struct sockaddr *)&server_address, saddr_len);"

puts $file "    if (!err)\{"
puts $file "        printf(\"Error transmitting data.\\n\");"
puts $file "		#ifdef _WIN32"
puts $file "			closesocket(socket_handle);"
puts $file "			WSACleanup();"
puts $file "		#else"
puts $file "			close(socket_handle);"
puts $file "		#endif"
puts $file "		return 1;"
puts $file "    \}"
puts $file "    "
puts $file "    "
puts $file "    // --------read from DDR--------"
puts $file "    "
puts $file "    if (Packet_type==4 || Packet_type==5)"
puts $file "    \{"
puts $file "    "
puts $file "        ss = select(socket_handle+1, &Reader, NULL, NULL, &tv);"
puts $file ""
puts $file "        if (ss)"
puts $file "        \{"
puts $file "			// receive data from FPGA"
puts $file "            err = recvfrom(socket_handle, (void *)incoming_float, sizeof(incoming_float), 0,NULL,NULL);"
puts $file "            if (err < 0) "
puts $file "                \{printf(\"Error receiving data.\\n\");"
puts $file "                #ifdef _WIN32"
puts $file "                    closesocket(socket_handle);"
puts $file "                    WSACleanup();"
puts $file "                #else"
puts $file "                    close(socket_handle);"
puts $file "                #endif"
puts $file "                return 1;"
puts $file "            \}"
puts $file "            else"
puts $file "            \{"
puts $file "                 //Output data cast to double"
puts $file "                 for ( i = 0; i < ETH_PACKET_LENGTH_RECV; i++)"
puts $file "                     dout\[i\] = (double)incoming_float\[i\];"
puts $file "            \}"
puts $file "        \} "
puts $file "        else "
puts $file "        \{"
puts $file "               printf(\"Time out \\n\");"
puts $file "                #ifdef _WIN32"
puts $file "                    closesocket(socket_handle);"
puts $file "                    WSACleanup();"
puts $file "                #else"
puts $file "                    close(socket_handle);"
puts $file "                #endif"
puts $file "                return 1;"
puts $file "        \}"
puts $file ""
puts $file ""
puts $file "    \}"

puts $file "    "
puts $file "#ifdef _WIN32"
puts $file "    closesocket(socket_handle);"
puts $file "    WSACleanup();"
puts $file "#else"
puts $file "    close(socket_handle);"
puts $file "#endif"
puts $file ""
puts $file "return 0;"
puts $file "\}"
puts $file ""
puts $file ""
puts $file ""
puts $file ""
puts $file "int TCPclient_wrap(char ip_address\[\], unsigned port_number,double din\[ETH_PACKET_LENGTH\],unsigned Packet_type, double dout\[ETH_PACKET_LENGTH_RECV\], int float_fix, int fraction_length)"
puts $file "\{"
puts $file "    "
puts $file "    int socket_handle; // Handle for the socket"
puts $file "    int connect_id; // Connection ID"
puts $file "    struct sockaddr_in server_address;	// Server address"
puts $file "	struct sockaddr_in client_address;	// client address"
puts $file "    int saddr_len = sizeof(server_address); // Server address length"
puts $file "	int caddr_len = sizeof(client_address); // Client address length"
puts $file "    struct hostent *server;		// Server host entity"
puts $file "	struct hostent *client;		// Client host entity"
puts $file "    int n;						// Iterator"
puts $file "    int k;						// Iterator"
puts $file "	int i;"
puts $file "    struct timeval tv;			// Select timeout structure"
puts $file "    fd_set Reader;				// Struct for select function"
puts $file "    int err;					// Error flag for return data"
puts $file "    int ss;						// Return from select function"
puts $file "	"
puts $file "	int timeout;				//timeout \[s\]"
puts $file "	char host_name\[256\];		// Host name of this computer "
puts $file ""
puts $file "    int tmp_time;"
puts $file "    int32_t tmp_databuffer;"
puts $file "        "
puts $file "    float databuffer_float\[ETH_PACKET_LENGTH\];		// Buffer for outgoing data"
puts $file "    float incoming_float\[ETH_PACKET_LENGTH_RECV\];			// Buffer for return data"
puts $file "    "
puts $file "    "
puts $file "	#ifdef _WIN32"
puts $file "		WSADATA wsaData;"
puts $file "	#endif"
puts $file ""
puts $file ""
puts $file "	// Platform specific variables for timing "
puts $file "    #ifdef _WIN32"
puts $file "        LARGE_INTEGER t1;"
puts $file "        LARGE_INTEGER t2;"
puts $file "        LARGE_INTEGER freq;"
puts $file "    #else"
puts $file "        struct timeval t1;          // For timing call length"
puts $file "        struct timeval t2;          // For timing call length"
puts $file "    #endif "
puts $file ""
puts $file " "
puts $file "    #ifdef _WIN32"
puts $file "    	int iResult;"
puts $file "		// Open windows connection"
puts $file "		iResult = WSAStartup(MAKEWORD(2,2), &wsaData);"
puts $file "		if (iResult != 0) \{"
puts $file "	    	printf(\"Could not open Windows connection. WSAStartup failed: %d\\n\", iResult);"
puts $file "    		return 1;"
puts $file "		\}"
puts $file "	#endif"
puts $file ""
puts $file "	server = gethostbyname(ip_address);"
puts $file "	port_number = port_number;"
puts $file "	timeout=86400; //timeout in seconds: 1 day"
puts $file ""
puts $file "	"
puts $file ""
puts $file ""
puts $file "    if (server == NULL) \{"
puts $file "        fprintf(stderr,\"ERROR, no such host1\\n\");"
puts $file "		#ifdef _WIN32"
puts $file "			WSACleanup();"
puts $file "		#endif"
puts $file "		return 1;"
puts $file "    \}"
puts $file "    "
puts $file "    // Open a datagram socket."
puts $file "    socket_handle = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);"
puts $file "    if (socket_handle == 0xFFFF)\{"
puts $file "        printf(\"Could not create socket.\\n\");"
puts $file "		#ifdef _WIN32"
puts $file "			WSACleanup();"
puts $file "		#endif"
puts $file "		return 1;"
puts $file "    \}"
puts $file "    "
puts $file "    "
puts $file "    // Clear out server struct"
puts $file "    memset( (void *) &server_address, 0, sizeof(server_address));"
puts $file "   "
puts $file "	//Set family and port"
puts $file "    server_address.sin_family = AF_INET;"
puts $file "	server_address.sin_port = htons(port_number);"
puts $file "    "
puts $file "    //Set server address"
puts $file "	memcpy((char *)&server_address.sin_addr.s_addr,"
puts $file "          (char *)server->h_addr,"
puts $file "          server->h_length);"
puts $file ""
puts $file "    // Connect to the server"
puts $file "	if (connect(socket_handle, (struct sockaddr *)&server_address, sizeof(struct sockaddr_in)))"
puts $file "	\{"
puts $file "		fprintf(stderr, \"Cannot bind address to socket.\\n\");"
puts $file "		#ifdef _WIN32"
puts $file "			closesocket(socket_handle);"
puts $file "			WSACleanup();"
puts $file "		#else"
puts $file "			close(socket_handle);"
puts $file "		#endif"
puts $file "		return 1;"
puts $file "	\}     "
puts $file ""
puts $file ""
puts $file ""
puts $file "	"
puts $file "	#ifdef _WIN32"
puts $file "       QueryPerformanceCounter(&t1);"
puts $file "    #else"
puts $file "        gettimeofday(&t1, NULL);"
puts $file "    #endif"
puts $file "    "
puts $file "    // Set timeout values"
puts $file "    "
puts $file "    tv.tv_sec = timeout;"
puts $file "    tv.tv_usec = 0;"
puts $file "    "
puts $file "    // Set FDS u/p"
puts $file "    "
puts $file "    FD_ZERO(&Reader);"
puts $file "    FD_SET(socket_handle, &Reader);"
puts $file ""
puts $file ""
puts $file "	// Input data cast to float"
puts $file "	for ( i = 0; i < ETH_PACKET_LENGTH; i++)"
puts $file "	\{"
puts $file "		databuffer_float\[i\]=(float)din\[i\];"
puts $file "	\}"
puts $file "    "
puts $file "	// Send data to FPGA"
puts $file "	err = send(socket_handle, (void *)databuffer_float, sizeof(databuffer_float), 0);"
puts $file "         "
puts $file ""
puts $file "    if (!err)\{"
puts $file "        printf(\"Error transmitting data.\\n\");"
puts $file "		#ifdef _WIN32"
puts $file "			closesocket(socket_handle);"
puts $file "			WSACleanup();"
puts $file "		#else"
puts $file "			close(socket_handle);"
puts $file "		#endif"
puts $file "		return 1;"
puts $file "    \}"
puts $file "    "
puts $file ""
puts $file "    // --------read from DDR--------"
puts $file "    "
puts $file "    if (Packet_type==4 || Packet_type==5)"
puts $file "    \{"
puts $file "        "
puts $file "        ss = select(socket_handle+1, &Reader, NULL, NULL, &tv);"
puts $file ""
puts $file "        if (ss)"
puts $file "        \{"
puts $file "			// receive data from FPGA"
puts $file "            err = recv(socket_handle, (void *)incoming_float, sizeof(incoming_float), 0);"
puts $file "            "
puts $file "            "
puts $file "            if (err < 0) "
puts $file "                \{printf(\"Error receiving data.\\n\");"
puts $file "                #ifdef _WIN32"
puts $file "                    closesocket(socket_handle);"
puts $file "                    WSACleanup();"
puts $file "                #else"
puts $file "                    close(socket_handle);"
puts $file "                #endif"
puts $file "                return 1;"
puts $file "            \}"
puts $file "            else"
puts $file "            \{"
puts $file "                 //Output data cast to double"
puts $file "                 for ( i = 0; i < ETH_PACKET_LENGTH_RECV; i++)"
puts $file "                 	dout\[i\] = (double)incoming_float\[i\];"
puts $file "				"
puts $file "            \}"
puts $file "        \} "
puts $file "        else "
puts $file "        \{"
puts $file "                printf(\"Time out \\n\");"
puts $file "                #ifdef _WIN32"
puts $file "                    closesocket(socket_handle);"
puts $file "                    WSACleanup();"
puts $file "                #else"
puts $file "                    close(socket_handle);"
puts $file "                #endif"
puts $file "                return 1;"
puts $file "        \}"
puts $file ""
puts $file "       "
puts $file "       "
puts $file "    \}"
puts $file ""
puts $file ""
puts $file "	"
puts $file "    "
puts $file "#ifdef _WIN32"
puts $file "    closesocket(socket_handle);"
puts $file "    WSACleanup();"
puts $file "#else"
puts $file "    close(socket_handle);"
puts $file "#endif"
puts $file ""
puts $file "return 0;"
puts $file "\}"
puts $file ""
puts $file ""

puts $file ""
puts $file ""

puts $file "int write_stimuli(double input_data\[\], unsigned packet_internal_ID)"
puts $file "\{"
puts $file "	FILE * pFile;"
puts $file "	int i;"

puts $file "	switch (packet_internal_ID)"
puts $file "	\{"

set m 0
foreach i $input_vectors {

	set tmp_line ""
	append tmp_line "	case " $m ": //" $i "_in"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "		// store " $i "_in into ../../ip_design/test/stimuli/" $project_name "/" $i "_in.dat"
	puts $file $tmp_line
	set tmp_line ""
	append tmp_line "		pFile = fopen (\"../../ip_design/test/stimuli/" $project_name "/" $i "_in.dat\",\"w+\");"
	puts $file $tmp_line
	puts $file ""
	puts $file "		for (i = 0; i < [string toupper $i]_IN_LENGTH; i++)"
	puts $file "		\{"
	set tmp_line ""
	append tmp_line "			fprintf(pFile,\"%2.18f \\n\",input_data\[i\]);"
	puts $file $tmp_line
	set tmp_line ""
	puts $file "		\}"
	puts $file "		fprintf(pFile,\"\\n\");"
	puts $file "		fclose (pFile);"
	puts $file "		"
	
	incr m
}

puts $file "		default:"
puts $file "		break;"
puts $file "	\}"

puts $file "\}"


puts $file "int start_simulation()"
puts $file "\{"

set tmp_line ""
append tmp_line "	system(\"vivado_hls -f ../../.metadata/" $project_name "_ip_design_test.tcl\");"
puts $file $tmp_line

puts $file "\}"

puts $file ""

puts $file ""
puts $file ""

puts $file "int read_results(double output_data\[\], unsigned packet_internal_ID, unsigned packet_output_size)"
puts $file "\{"
puts $file ""
puts $file "	FILE * pFile;"
puts $file "	int i;"
puts $file "	double output_data_tmp;"
puts $file ""
puts $file "	switch (packet_internal_ID)"
puts $file "	\{"

set m 0
foreach i $output_vectors {

	set tmp_line ""
	append tmp_line "	case " $m ": //" $i "_in"
	puts $file $tmp_line
	
	set tmp_line ""
	append tmp_line "		// load ../../ip_design/test/results/" $project_name "/" $i "_out.dat"
	puts $file $tmp_line
	set tmp_line ""
	append tmp_line "		pFile = fopen (\"../../ip_design/test/results/" $project_name "/" $i "_out.dat\",\"r\");"
	puts $file $tmp_line
	puts $file ""
	puts $file "		for (i = 0; i < packet_output_size; i++)"
	puts $file "		\{"
	set tmp_line ""
	append tmp_line "			fscanf(pFile,\"%lf\",\&output_data_tmp);"
	puts $file $tmp_line
	set tmp_line ""
	append tmp_line "			output_data\[i\]=output_data_tmp;"
	puts $file $tmp_line
	set tmp_line ""
	puts $file "		\}"
	puts $file "		fclose (pFile);"
	puts $file "		"
	
	incr m
}

puts $file "		default:"
puts $file "		break;"
puts $file "	\}"

puts $file ""
puts $file "\}"



close $file
return -code ok

}



# ########################################################################################
# make ip_prototype/src/FPGAserver.h file

proc ::tclapp::icl::protoip::make_template::make_FPGAserver_h {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:
  
set project_name [lindex $args 0]


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
set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 

if ($type_test!=0) {
	set mem_base_address 0
}

set file [open ip_prototype/src/FPGAserver.h w]


#add license_c header
[::tclapp::icl::protoip::make_template::license_c $file]




puts $file "////////////////////////////////////////////////////////////"
puts $file "#define DEBUG 0 //1 to enable debug printf, 0 to disable debug printf"
puts $file ""
puts $file ""
puts $file "////////////////////////////////////////////////////////////"
puts $file "// Define FLOAT_FIX_VECTOR_NAME=1 to enable  fixed-point (up to 32 bits word length) arithmetic precision or "
puts $file "// FLOAT_FIX_VECTOR_NAME=0 to enable floating-point single arithmetic precision."

set m 0
foreach i $input_vectors {
	set tmp_line ""
	if { [lindex $input_vectors_type $m] == 1} {  
		append tmp_line "#define FLOAT_FIX_[string toupper $i]_IN 1"
	} else {  
		append tmp_line "#define FLOAT_FIX_[string toupper $i]_IN 0"
	}
	puts $file $tmp_line
	incr m
}

set m 0
foreach i $output_vectors {
	set tmp_line ""
	if { [lindex $output_vectors_type $m] == 1} {  
		append tmp_line "#define FLOAT_FIX_[string toupper $i]_OUT 1"
	} else {  
		append tmp_line "#define FLOAT_FIX_[string toupper $i]_OUT 0"
	}
	puts $file $tmp_line
	incr m
}



puts $file ""
puts $file "//Input vectors FRACTIONLENGTH:"
set m 0
foreach i $input_vectors {
	set tmp_line ""
	append tmp_line "#define [string toupper $i]_IN_FRACTIONLENGTH [lindex $input_vectors_fraction_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file "//Output vectors FRACTIONLENGTH:"
set m 0
foreach i $output_vectors {
	set tmp_line ""
	append tmp_line "#define [string toupper $i]_OUT_FRACTIONLENGTH [lindex $output_vectors_fraction_length $m]"
	puts $file $tmp_line
	incr m
}
puts $file ""



puts $file "////////////////////////////////////////////////////////////"
puts $file "//FPGA vectors memory maps"

set address_store [expr ($mem_base_address/256)*256]
set m 0
foreach i $input_vectors_length {
	set tmp_line ""
	append tmp_line "#define " [lindex $input_vectors $m] "_IN_DEFINED_MEM_ADDRESS " $address_store
	puts $file $tmp_line 
	set address_store [expr ($i*4) + $address_store]
	incr m
}
set m 0
foreach i $output_vectors_length {
	set tmp_line ""
	append tmp_line "#define " [lindex $output_vectors $m] "_OUT_DEFINED_MEM_ADDRESS " $address_store
	puts $file $tmp_line 
	set address_store [expr ($i*4) + $address_store]
	incr m
}




puts $file ""
puts $file ""
puts $file "////////////////////////////////////////////////////////////"
puts $file "//Ethernet interface configuration:"
if { $type_eth == 1} { 
puts $file "#define TYPE_ETH 1 //1 for TCP, 0 for UDP"
} elseif  { $type_eth == 0} { 
puts $file "#define TYPE_ETH 0 //1 for TCP, 0 for UDP"
}
puts $file "#define FPGA_IP \"192.168.1.10\" //FPGA IP"
puts $file "#define FPGA_NM \"255.255.255.0\" //Netmask"
puts $file "#define FPGA_GW \"192.168.1.1\" //Gateway"
puts $file "#define FPGA_PORT 2007"
puts $file ""
puts $file ""
puts $file "///////////////////////////////////////////////////////////////"
puts $file "//////////////////DO NOT EDIT HERE BELOW///////////////////////"
puts $file "//FPGA interface data specification:"
puts $file "#define ETH_PACKET_LENGTH 256+2 //Ethernet packet length in double words (32 bits) (from Matlab to  FPGA)"
puts $file "#define ETH_PACKET_LENGTH_RECV 64+2 //Ethernet packet length in double words (32 bits) (from FPGA to Matlab)"
puts $file ""
puts $file ""


close $file
return -code ok

}