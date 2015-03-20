
########################################################################################
## 20/11/2014 - First release 1.0
########################################################################################


namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_design_build
}



proc ::tclapp::icl::protoip::ip_design_build {args} {

	  # Summary: Build the IP XACT of the project according to the specification in [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt using Vivado HLS.

	  # Argument Usage:
	  # -project_name <arg>: Project name
      # [-input <arg>]: Input vector name, size and type separated by : symbol
      # [-output <arg>]: Output vector name, size and type separated by : symbol
      # [-fclk <arg>]: Circuit clock frequency
      # [-FPGA_name <arg>]: FPGA device name
	  # [-usage]: Usage information

	  # Return Value:
	  # return the built IP XACT and the IP design report in [WORKING DIRECTORY]/doc/project_name/ip_design.txt. If any error occur TCL_ERROR is returned

	  # Categories: 
	  # xilinxtclstore, protoip
	  
  uplevel [concat ::tclapp::icl::protoip::ip_design_build::ip_design_build $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::icl::protoip::ip_design_build {
  variable version {20/11/2014}
} ]



#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G R A M                              # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::icl::protoip::ip_design_build::ip_design_build { args } {
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
		-fclk -
        {^-f(c(lk?)?)?$} {
             set fclk [lshift args]
             if {$fclk == {}} {
				puts " -E- NO clock frequency name specified."
				incr error
             } 
	     }
		 -FPGA_name -
        {^-F(P(G(A(_(n(a(me?)?)?)?)?)?)?)?$} {
             set FPGA_name [lshift args]
             if {$FPGA_name == {}} {
				puts " -E- NO FPGA name specified."
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
                puts " -E- option '$name' is not a valid option. Use the -usage option for more details."
                incr error
              } else {
                puts " -E- option '$name' is not a valid option. Use the -usage option for more details."
                incr error
              }
        }
      }
    }
    
  if {$help} {
      puts [format {
  Usage: ip_design_build
  -project_name <arg> - Project name
                        It's a mandatory field
 [-input <arg>]       - Input vector name,size and type separated by : symbol
                        Type can be: float or fix:xx:yy. 
                        Where 'xx' is the integer length and 'yy' the 
                        fraction length
                        Repeat the command for every input vector to update
                        All inputs and outputs must be of the same type: 
                        float or fix
 [-output <arg>]      - Output vector name,size and type separated by : symbol
                        Type can be: float or fix:xx:yy. 
                        Where 'xx' is the integer length and 'yy' the 
                        fraction length
                        Repeat the command for every output to update
                        All inputs and outputs must be of the same type: 
                        float or fix
  [-fclk <arg>]       - Circuit clock frequency
  [-FPGA_name <arg>]  - FPGA device name

  [-usage|-u]         - This help message

  Description: 
   Build the IP XACT of the project named 'project_name' according to the 
   specification in [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt
   using Vivado HLS. 
   
   The new specified inputs parameters overwrite 
   the one specified into configuration parameters
   [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt.
  
   This command should be run after 'make_template' command only.

  Example:
   ip_design_build -project_name my_project0
   ip_design_build -project_name my_project0 -input x1:2:fix:4:6 -output y0:3:fix:2:4 -fclk 150 -FPGA_name xc7z020clg484-1


  } ]
      # HELP -->
      return {}
    }
	
  if {$error} {
    error " -E- some error(s) happened. Cannot continue. Use the -usage option for more details."
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
			set old_input_vectors {}
			set old_input_vectors_length {}
			set old_input_vectors_type {}
			set old_input_vectors_integer_length {}
			set old_input_vectors_fraction_length {}
			set old_output_vectors {}
			set old_output_vectors_length {}
			set old_output_vectors_type {}
			set old_output_vectors_integer_length {}
			set old_output_vectors_fraction_length {}

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

			set old_fclk [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 2]] 
			set old_FPGA_name [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 4]] 
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
			
			
			
			if {$FPGA_name == {}} {
				set FPGA_name $old_FPGA_name
			} 
			if {$fclk == {}} {
				set fclk $old_fclk
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

			set type_test "none"
			
			
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
				
				# update ip_design/src/foo_data.h file
				[::tclapp::icl::protoip::make_template::make_foo_data_h $project_name]
				# update ip_design/src/FPGAclientAPI.h file
				[::tclapp::icl::protoip::make_template::make_FPGAclientAPI_h  $project_name]
				# update directives
				[::tclapp::icl::protoip::make_template::update_directives  $project_name] 
				

				puts ""
				puts "Calling Vivado_HLS to build the IP ..."
					
				# run Vivado HLS IP build
				set  file_name ""
				append file_name ".metadata/" $project_name "_ip_design_build.tcl"
					
				set vivado_hls_p [open "|vivado_hls -f $file_name" r]
				while {![eof $vivado_hls_p]} { gets $vivado_hls_p line ; puts $line }
				close $vivado_hls_p

					
				#set vivado_hls_exit_flag=0 if error, vivado_hls_exit_flag=1 if NOT error
				set vivado_hls_exit_flag [file isdirectory ip_design/build/prj/$project_name/solution1/impl]
				
				
				if {$vivado_hls_exit_flag==1} {
					[::tclapp::icl::protoip::ip_design_build::make_ip_design_readme_txt $project_name]
				} else {
					incr error
				}
				puts ""
			
			} else {			
				
			
				error " -E- Inputs and Outputs must be either fixed-point or floating-point. Use the -usage option for more details."


			}
		
		}
	}
	

}



    if {$error} {
		puts "Vivado_HLS: IP built ERROR. Please check Vivado_HLS log file at <WORKING_DIRECTORY>/vivado_hls.log  for error(s) info."
		puts ""
		return -code error
	} else {
		puts "Vivado_HLS: IP built successfully"
		puts ""
		return -code ok
	}

    
}


#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         IP DESIGN BUILD PROCEDURES                           # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#


# ########################################################################################
# make doc/project_name/ip_design.txt file

proc ::tclapp::icl::protoip::ip_design_build::make_ip_design_readme_txt {args} {
  # Summary :
  # Argument Usage:
  # Return Value:
  # Categories:


set project_name [lindex $args 0]
	
	
			# #######################################  
			# #######################################  
			# Extract IP pre implementation information (timing, resources and latency
			
			set target_file ""
			append target_file "ip_design/build/prj/"  $project_name "/solution1/syn/report/foo_csynth.rpt"
			
			# #######################################  
			# Extract timing information
			
			set f [open $target_file]
			set file_data [read $f]
			close $f
			
			set data [split $file_data "\n"]
			set count_line 0;
			foreach line $data {
				incr count_line
				if {[regexp {Timing} $line all value]} {
					set target_line [expr [incr count_line 5]]
					break
				}
			}
			
			set count_line 0;
			foreach line $data {
				incr count_line
				if {$count_line == $target_line} {
					break
				}
			}

			
			set line_size [expr [ string length $line]-1]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]

			set line_size [expr [ string length $line]-1]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]	
			regsub -all -- {[^0-9.-]} $tmp_str "" clock_target	
			#if the clock_traget is not available, set it to 0
			if {$clock_target == ""} {
				set clock_target 0
			}
			
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]	
			regsub -all -- {[^0-9.-]} $tmp_str "" clock_estimated	
			#if the clock_traget is not available, set it to 0
			if {$clock_estimated == ""} {
				set clock_estimated 0
			}
			
			
			# #######################################  
			# Extract latency information
			
			set f [open $target_file]
			set file_data [read $f]
			close $f
			
			set data [split $file_data "\n"]
			set count_line 0;
			foreach line $data {
				incr count_line
				if {[regexp {Latency} $line all value]} {
					set target_line [expr [incr count_line 6]]
					break
				}
			}
			
			set count_line 0;
			foreach line $data {
				incr count_line
				if {$count_line == $target_line} {
					break
				}
			}

			
			
			set line_size [expr [ string length $line]-1]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]

			set line_size [expr [ string length $line]-1]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]	
			regsub -all -- {[^0-9.-]} $tmp_str "" latency	
			#if the latency is not available, set it to 0
			if {$latency == ""} {
				set latency 0
			}


			# #######################################  
			# Extract the resource utilization

			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {Total} $line all value]} {
				break
			    }
			}
			close $f

			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]

			
			#extract BRAM_18K
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			

			
			regsub -all -- {[^0-9.-]} $tmp_str "" BRAM
			#if the BRAM is not available, set it to 0
			if {$BRAM == ""} {
				set BRAM 0
			}

			 
			# extract DSP48E
			 set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			 regsub -all -- {[^0-9.-]} $tmp_str "" DSP48E
			# if the DSP48E is not available, set it to 0
			if {$DSP48E == ""} {
				set DSP48E 0
			}

			 #extract FF
			 set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			 regsub -all -- {[^0-9.-]} $tmp_str "" FF
			 #if the FF is not available, set it to 0
			if {$FF == ""} {
				set FF 0
			}

			 
			# extract LUT
			 set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" LUT
			#if the LUT is not available, set it to 0
			if {$LUT == ""} {
				set LUT 0
			}
			
			
			# #######################################  
			# Extract the resource available

			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {Available} $line all value]} {
				break
			    }
			}
			close $f

			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]

			
			#extract BRAM_18K
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			

			
			regsub -all -- {[^0-9.-]} $tmp_str "" BRAM_available
			#if the BRAM_available is not available, set it to 0
			if {$BRAM_available == ""} {
				set BRAM_available 0
			}

			 
			# extract DSP48E
			 set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			 regsub -all -- {[^0-9.-]} $tmp_str "" DSP48E_available
			# if the DSP48E_available is not available, set it to 0
			if {$DSP48E_available == ""} {
				set DSP48E_available 0
			}

			 #extract FF
			 set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			 regsub -all -- {[^0-9.-]} $tmp_str "" FF_available
			 #if the FF_available is not available, set it to 0
			if {$FF_available == ""} {
				set FF_available 0
			}

			 
			# extract LUT
			 set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" LUT_available
			#if the LUT_available is not available, set it to 0
			if {$LUT_available == ""} {
				set LUT_available 0
			}
			
			
			# #######################################  
			# #######################################  
			# Extract Algorithm pre implementation information (resources and latency)
			
			set target_file ""
			append target_file "ip_design/build/prj/"  $project_name "/solution1/syn/report/foo_foo_user_csynth.rpt"
			
			# #######################################  
			# Extract timing information
			
			set f [open $target_file]
			set file_data [read $f]
			close $f
			
			set data [split $file_data "\n"]
			set count_line 0;
			foreach line $data {
				incr count_line
				if {[regexp {Timing} $line all value]} {
					set target_line [expr [incr count_line 5]]
					break
				}
			}
			
			set count_line 0;
			foreach line $data {
				incr count_line
				if {$count_line == $target_line} {
					break
				}
			}

			
			set line_size [expr [ string length $line]-1]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]

			set line_size [expr [ string length $line]-1]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]	
			regsub -all -- {[^0-9.-]} $tmp_str "" clock_target_alg	
			#if the clock_traget is not available, set it to 0
			if {$clock_target_alg == ""} {
				set clock_target_alg 0
			}
			
			set line [string range $line $index_pipe $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]	
			regsub -all -- {[^0-9.-]} $tmp_str "" clock_estimated_alg	
			#if the clock_traget is not available, set it to 0
			if {$clock_estimated_alg == ""} {
				set clock_estimated_alg 0
			}
			
			
			# #######################################  
			# Extract latency information
			
			set f [open $target_file]
			set file_data [read $f]
			close $f
			
			set data [split $file_data "\n"]
			set count_line 0;
			foreach line $data {
				incr count_line
				if {[regexp {Latency} $line all value]} {
					set target_line [expr [incr count_line 6]]
					break
				}
			}
			
			set count_line 0;
			foreach line $data {
				incr count_line
				if {$count_line == $target_line} {
					break
				}
			}

			
			
			set line_size [expr [ string length $line]-1]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]

			set line_size [expr [ string length $line]-1]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]
			
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]	
			regsub -all -- {[^0-9.-]} $tmp_str "" latency_alg	
			#if the latency is not available, set it to 0
			if {$latency_alg == ""} {
				set latency_alg 0
			}


			# #######################################  
			# Extract the resource utilization

			set f [open $target_file]
			while {[gets $f line] != -1} {
			    if {[regexp {Total} $line all value]} {
				break
			    }
			}
			close $f

			
			set line_size [expr [ string length $line]-1]
			set line [string range $line 1 $line_size]
			set index_pipe [expr [string first "|" $line ] +1]
			set line [string range $line $index_pipe $line_size]

			
			#extract BRAM_18K
			set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			

			
			regsub -all -- {[^0-9.-]} $tmp_str "" BRAM_alg
			#if the BRAM is not available, set it to 0
			if {$BRAM_alg == ""} {
				set BRAM_alg 0
			}

			 
			# extract DSP48E
			 set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			 regsub -all -- {[^0-9.-]} $tmp_str "" DSP48E_alg
			# if the DSP48E is not available, set it to 0
			if {$DSP48E_alg == ""} {
				set DSP48E_alg 0
			}

			 #extract FF
			 set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			 regsub -all -- {[^0-9.-]} $tmp_str "" FF_alg
			 #if the FF is not available, set it to 0
			if {$FF_alg == ""} {
				set FF_alg 0
			}

			 
			# extract LUT
			 set index_pipe [expr [string first "|" $line ] +1]
			set tmp_str  [string range $line 0 $index_pipe]
			set line [string range $line $index_pipe $line_size]
			regsub -all -- {[^0-9.-]} $tmp_str "" LUT_alg
			#if the LUT is not available, set it to 0
			if {$LUT_alg == ""} {
				set LUT_alg 0
			}
			
		
			
			# ####################################### 
			# Write report file
			# Make IP synthesis report
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


			set dir_name ""
			append dir_name "doc/" $project_name
			file mkdir $dir_name
			
			# make ip_design.dat
			
			set  file_name ""
			append file_name "doc/" $project_name "/ip_design.dat"

			set file [open $file_name w]


			puts $file $clock_target
			puts $file $clock_estimated
			puts $file $clock_target_alg
			puts $file $clock_estimated_alg
			puts $file $latency
			puts $file [expr $clock_target * $latency / 1000]
			puts $file $latency_alg
			puts $file [expr $clock_target_alg * $latency_alg / 1000]
			puts $file $BRAM
			puts $file $DSP48E
			puts $file $FF
			puts $file $LUT
			puts $file $BRAM_alg
			puts $file $DSP48E_alg
			puts $file $FF_alg
			puts $file $LUT_alg
		
			close $file
			
			# make ip_design.txt

			set  file_name ""
			append file_name "doc/" $project_name "/ip_design.txt"

			set file [open $file_name w]


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
			puts $file ""
			puts $file "---------------------------------------------------------"
			puts $file "IP design C/RTL test(s): input and output vectors has been mapped into a virtual memory at the following addresses:"
			puts $file "(the virtual memory is used by foo_test.cpp)"
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
			set tmp_line ""
			append tmp_line "IP build report: " $project_name
			puts $file $tmp_line
			puts $file "----------------------------------------------------------"
		
			puts $file ""
			puts $file ""
			puts $file "Timing:"
			puts $file "------------------------"
			puts $file ""
			puts $file "* IP"
			set tmp_line ""
			append tmp_line "   target clock period (ns): " $clock_target
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "   estimated clock period (ns): " $clock_estimated
			puts $file $tmp_line
			
			puts $file ""
			puts $file "	* User function"
			set tmp_line ""
			append tmp_line "	   target clock period (ns): " $clock_target_alg
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "	   estimated clock period (ns): " $clock_estimated_alg
			puts $file $tmp_line

			puts $file ""
			if [expr $clock_target < $clock_estimated] {
				puts $file "WARNING: Time constraints might NOT be met during IP prototyping. You might increase clock target period to met time constraints."	
			} else {
				puts $file "Time constraints might be met during IP prototyping. You can reduce clock target period to build a faster design."
			}
			
			
			puts $file ""
			puts $file ""
			puts $file "Latency:"
			puts $file "------------------------"
			puts $file ""
			puts $file "* IP"
			set tmp_line ""
			append tmp_line "   latency (clock cycles): " $latency
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "   latency (us): " [expr $clock_target * $latency / 1000]
			puts $file $tmp_line
			
			puts $file ""
			puts $file "	* User function"
			set tmp_line ""
			append tmp_line "	   latency (clock cycles): " $latency_alg
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "	   latency (us): " [expr $clock_target_alg * $latency_alg / 1000]
			puts $file $tmp_line

			
			puts $file ""
			puts $file ""
			puts $file "Resource utilization:"
			puts $file "------------------------"
			puts $file ""
			puts $file "* IP"
			if [expr $BRAM <= $BRAM_available] { 
				set tmp_line ""
				append tmp_line "   BRAM_18K: " $BRAM " (" [expr $BRAM * 100 / $BRAM_available] "%) used out off " $BRAM_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   BRAM_18K: " $BRAM " (" [expr $BRAM * 100 / $BRAM_available] "%) used out off " $BRAM_available " available. WARNING: the design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or to reduce the design size."
				puts $file $tmp_line
			}
			if [expr $DSP48E <= $DSP48E_available] { 
				set tmp_line ""
				append tmp_line "   DSP48E: " $DSP48E  " (" [expr $DSP48E * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   DSP48E: " $DSP48E  " (" [expr $DSP48E * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available. WARNING: the design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $FF <= $FF_available] { 
				set tmp_line ""
				append tmp_line "   FF: " $FF " (" [expr $FF * 100 / $FF_available] "%) used out off " $FF_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   FF: " $FF " (" [expr $FF * 100 / $FF_available] "%) used out off " $FF_available " available. WARNING: the design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $LUT <= $LUT_available] { 
				set tmp_line ""
				append tmp_line "   LUT: " $LUT " (" [expr $LUT * 100 / $LUT_available] "%) used out off " $LUT_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "   LUT: " $LUT " (" [expr $LUT * 100 / $LUT_available] "%) used out off " $LUT_available " available. WARNING: the design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			
			puts $file ""
			puts $file "	* User function"
			if [expr $BRAM_alg <= $BRAM_available] { 
				set tmp_line ""
				append tmp_line "	   BRAM_18K: " $BRAM_alg " (" [expr $BRAM_alg * 100 / $BRAM_available] "%) used out off " $BRAM_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "	   BRAM_18K: " $BRAM_alg " (" [expr $BRAM_alg * 100 / $BRAM_available] "%) used out off " $BRAM_available " available. WARNING: the design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or to reduce the design size."
				puts $file $tmp_line
			}
			if [expr $DSP48E_alg <= $DSP48E_available] { 
				set tmp_line ""
				append tmp_line "	   DSP48E: " $DSP48E_alg  " (" [expr $DSP48E_alg * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "	   DSP48E: " $DSP48E_alg  " (" [expr $DSP48E_alg * 100 / $DSP48E_available] "%) used out off " $DSP48E_available " available. WARNING: the design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $FF_alg <= $FF_available] { 
				set tmp_line ""
				append tmp_line "	   FF: " $FF_alg " (" [expr $FF_alg * 100 / $FF_available] "%) used out off " $FF_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "	   FF: " $FF_alg " (" [expr $FF_alg * 100 / $FF_available] "%) used out off " $FF_available " available. WARNING: the design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			if [expr $LUT_alg <= $LUT_available] { 
				set tmp_line ""
				append tmp_line "	   LUT: " $LUT_alg " (" [expr $LUT_alg * 100 / $LUT_available] "%) used out off " $LUT_available " available."
				puts $file $tmp_line
			} else {
				set tmp_line ""
				append tmp_line "	   LUT: " $LUT_alg " (" [expr $LUT_alg * 100 / $LUT_available] "%) used out off " $LUT_available " available. WARNING: the design does NOT fit into the selected FPGA. Consider to use a bigger FPGA or reduce the design size."
				puts $file $tmp_line
			}
			
			
			set tmp_line ""
			puts $file $tmp_line
			set tmp_line ""
			append tmp_line "NOTE: IP design performance might be enhanced by adding directives from Vivado_HLS GUI interface. Run \"tclapp::icl::protoip::ip_design_build_debug\" to open " $project_name " with Vivado_HLS GUI interface."
			puts $file $tmp_line
			
			
			
			
			close $file
			

			set f [open $file_name]
			set file_data [read $f]
			close $f
			
			set data [split $file_data "\n"]


			foreach i $data {

				puts $i
			}
			
	return -code ok
}

