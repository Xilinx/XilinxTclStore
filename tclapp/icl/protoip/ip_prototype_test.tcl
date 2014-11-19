#  icl::protoip
#  Suardi Andrea [a.suardi@imperial.ac.uk]
#  November - 2014


package require Vivado 1.2014.2

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_prototype_test
}


proc ::tclapp::icl::protoip::ip_prototype_test {args} {

	  # Summary: Run a test of the IP prototype named 'project_name' according to the specification in <WORKING DIRECTORY>/doc/project_name/ip_configuration_parameters.txt. A connected evaluation board is required.

	  # Argument Usage:
	  # [-project_name <arg>]	- Project name
	  # [-num_test <arg>]  		- Number of test(s)
	  # [-usage]: 				Usage information

	  # Return Value:
	  # Return the test results in <WORKING DIRECTORY>/ip_prototype/test/results/project_name. If any error occur TCL_ERROR is returned.

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
        {^-o(u(t(p(ut?)?)?)?)?$} {
             set project_name [lshift args]
             if {$project_name == {}} {
				puts " -E- NO project name specified."
				incr error
             } 
	     }
	   -num_test -
        {^-o(u(t(p(ut?)?)?)?)?$} {
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
			set old_num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
			set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 

			
			# update configuration parameters
			
			if {$num_test == {}} {
				set num_test $old_num_test
			} 
		
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
			
			
			
			
			
			[::tclapp::icl::protoip::make_project_configuration_parameters_dat $project_name $input_vectors $input_vectors_length $input_vectors_type $input_vectors_integer_length $input_vectors_fraction_length $output_vectors $output_vectors_length $output_vectors_type $output_vectors_integer_length $output_vectors_fraction_length $fclk $FPGA_name $board_name $type_eth $mem_base_address $num_test $type_test]

			# update ip_design/src/FPGAclientAPI.h file
			[::tclapp::icl::protoip::make_FPGAclientAPI_h  $project_name]
			

	
			puts ""
			puts "Calling Matlab to test the IP running on the FPGA evaluation board..."
			
			set tmp_dir ".metadata/"
			append tmp_dir $project_name
			file mkdir $tmp_dir
			
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
			 
			set status [ catch { exec matlab.exe --nospash -nodesktop -r test_HIL($project_name_to_Matlab)} output ]

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


	
  if {$help} {
      puts [format {
	Usage: ip_prototype_test
	[-project_name <arg>]- Project name
							It's a mandatory field
	[-num_test <arg>]  - Number of test(s)
							It's a mandatory field

  Description: Run a test of the IP prototype named 'project_name' according to the specification in <WORKING DIRECTORY>/doc/project_name/ip_configuration_parameters.txt.

  Example:
  tclapp::icl::protoip::ip_prototype_test -project_name my_project0 -num_test 1


} ]
      # HELP -->
      return {}
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



