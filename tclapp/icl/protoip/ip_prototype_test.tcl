
########################################################################################
## 20/11/2014 - First release 1.0
########################################################################################

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_prototype_test
}


proc ::tclapp::icl::protoip::ip_prototype_test {args} {

	  # Summary: Run a test of the IP prototype named 'project_name' according to the specification in [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt. A connected evaluation board is required.

	  # Argument Usage:
	  # -project_name <arg>: Project name
	  # -board_name <arg>: Evaluation board name
	  # -num_test <arg>: Number of test(s)
	  # [-usage]: Usage information

	  # Return Value:
	  # Return the test results in [WORKING DIRECTORY]/ip_prototype/test/results/project_name. If any error occur TCL_ERROR is returned.

	  # Categories: 
	  # xilinxtclstore, protoip
	  
uplevel [concat ::tclapp::icl::protoip::ip_prototype_test::ip_prototype_test $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::icl::protoip::ip_prototype_test::ip_prototype_test {
  variable version {20/11/2014}
} ]	  

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G R A M                              # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::icl::protoip::ip_prototype_test::ip_prototype_test { args } {
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
    set filename {}
	set fclk {}
    set FPGA_name {}
    set board_name {}
    set type_eth {}
    set mem_base_address {}
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
		  -board_name -
        {^-b(o(a(r(d(_(n(a(me?)?)?)?)?)?)?)?)?$} {
             set board_name [lshift args]
             if {$board_name == {}} {
				puts " -E- NO board name specified."
				incr error
             } 
	     }
	   -num_test -
        {^-n(u(m(_(t(e(st?)?)?)?)?)?)?$} {
             set num_test [lshift args]
             if {$num_test == {}} {
				puts " -E- NO number of test(s) specified."
				incr error
             } else {
				if {$num_test < 1} {
					puts " -E- number of test(s) must be greater than 0."
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
 Usage: ip_prototype_test
  -project_name <arg>       - Project name
                              It's a mandatory field
  -board_name <arg>         - Evaluation board name
                              It's a mandatory field
  -num_test <arg>           - Number of test(s)
                              It's a mandatory field
  [-usage|-u]               - This help message

 Description: 
  Run a HIL test of the IP prototype named 'project_name'
  according to the project configuration parameters
 [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt
   
 An evaluation board connected to an host computer through an Ethernet cable is required.
 
 This command must be run after 'ip_prototype_load' command only.
  
  
 Example:
  ip_prototype_test -project_name my_project0 -board_name zedboard -num_test 1


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
		
		if {$board_name == {}} {
	
			error " -E- NO board name specified. Use the -usage option for more details."
			
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
			set old_board_name [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 6]] 
			set type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
			set mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
			set old_num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
			set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]]
			set type_template [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 16]]			
			set type_design_flow [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 18]] 
			

		
			# update configuration parameters
			set m 0
			foreach i $input_vectors_type {
				if {$i==1} {
					set input_vectors_type [lreplace $input_vectors_type $m $m "fix"]
				} else {
					set input_vectors_type [lreplace $input_vectors_type $m $m "float"]
				}
				incr m
			}
			set m 0
			foreach i $output_vectors_type {
				if {$i==1} {
					set output_vectors_type [lreplace $output_vectors_type $m $m "fix"]
				} else {
					set output_vectors_type [lreplace $output_vectors_type $m $m "float"]
				}
				incr m
			}
			
			if {$type_eth==0} {
				set type_eth "udp"
			} elseif {$type_eth==1} {
				set type_eth "tcp"
			} 

			set type_test "none"
			

			
			set source_file ""
			append source_file "ip_prototype/build/prj/" $project_name "." $board_name "/prototype.runs/impl_1/design_1_wrapper.sysdef"
			
			if {[file exists $source_file] == 0} { 

				set tmp_error ""
				append tmp_error "-E- " $project_name " associated to " $board_name " has not been built. Use the -usage option for more details."
				error $tmp_error

			
			} else {
			
			set type_design_flow "vivado"
			[::tclapp::icl::protoip::make_template::make_project_configuration_parameters_dat $project_name $input_vectors $input_vectors_length $input_vectors_type $input_vectors_integer_length $input_vectors_fraction_length $output_vectors $output_vectors_length $output_vectors_type $output_vectors_integer_length $output_vectors_fraction_length $fclk $FPGA_name $board_name $type_eth $mem_base_address $num_test $type_test $type_template $type_design_flow]

			# update ip_design/src/FPGAclientAPI.h file
			[::tclapp::icl::protoip::make_template::make_FPGAclientAPI_h  $project_name]
			
	
			puts ""
			puts "Calling Matlab to test the IP running on the FPGA evaluation board..."
			
			
				set tmp_dir "ip_prototype/test/results/"
				append tmp_dir $project_name
				file mkdir $tmp_dir
				cd $tmp_dir
				
				set time_stamp [clock format [clock seconds] -format "%Y-%m-%d_T%H-%M"]
				
				foreach i $input_vectors {
					set file_name ""
					append file_name $i "_in_log.dat"
					if {[file exists $file_name] == 1} { 
						set file_name_new ""
						append file_name_new $time_stamp "_backup_" $i "_in_log.dat"
						file copy -force $file_name $file_name_new
						file delete -force $file_name
					}
				}
				
				foreach i $output_vectors {
					set file_name ""
					append file_name "fpga_" $i "_out_log.dat"
					if {[file exists $file_name] == 1} { 
						set file_name_new ""
						append file_name_new $time_stamp "_backup_fpga_" $i "_out_log.dat"
						file copy -force $file_name $file_name_new
						file delete -force $file_name
					}
					set file_name ""
					append file_name "matlab_" $i "_out_log.dat"
					if {[file exists $file_name] == 1} { 
						set file_name_new ""
						append file_name_new $time_stamp "_backup_matlab_" $i "_out_log.dat"
						file copy -force $file_name $file_name_new
						file delete -force $file_name
					}
				}
				
				set file_name ""
				append file_name "fpga_time_log.dat"
				if {[file exists $file_name] == 1} { 
					set file_name_new ""
					append file_name_new $time_stamp "_backup_fpga_time_log.dat"
					file copy -force $file_name $file_name_new
					file delete -force $file_name
				}
				
				cd ../../../../
			
			set project_name_to_Matlab ""
			append project_name_to_Matlab "'" $project_name "'"

			cd ip_design/src
			file delete -force _locked
			 
			set status [ catch { exec matlab.exe -nojvc -nosplash -nodesktop -r test_HIL($project_name_to_Matlab)} output ]

			# Wait until the Matlab has finished
			while {true} {
				if { [file exists _locked] == 1} {  
					after 1000
					break
				}
			}
			
			cd ../../
	

		
}
}
	
	}
	}

}


	

	puts ""
    if {$error} {
		puts "IP prototype test error."
		puts ""
		return -code error
    } else {
		puts "IP prototype tested successfully with HIL setup."
		puts ""
		return -code ok
	}

}



