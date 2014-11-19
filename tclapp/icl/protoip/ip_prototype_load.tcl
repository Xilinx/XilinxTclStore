#  icl::protoip
#  Suardi Andrea [a.suardi@imperial.ac.uk]
#  November - 2014


package require Vivado 1.2014.2

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_prototype_load
}


proc ::tclapp::icl::protoip::ip_prototype_load {args} {

	  # Summary: Build the FPGA Ethernet server application using SDK according to the specification in <WORKING DIRECTORY>/design_parameters.tcl and program the FPGA. A connected evaluation board is required.

	  # Argument Usage:
	  # [-project_name <arg>]	- Project name
	  # [-type_eth <arg>]  		- Ethernet connection protocol (UDP-IP or TCP-IP)
	  # [-mem_base_address <arg>]  - DDR3 memory base address
	  # [-usage]: Usage information

	  # Return Value:
	  # Return the built FPGA Ethernet server running on the FPGA ARM processor and the loaded designed IP on the FPGA. If any error occur TCL_ERROR is returned

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
		 -type_eth -
        {^-o(u(t(p(ut?)?)?)?)?$} {
             set type_eth [lshift args]
             if {$type_eth == {}} {
				puts " -E- NO ethernet connection type name specified."
				incr error
             } 
	     }
		  -mem_base_address -
        {^-o(u(t(p(ut?)?)?)?)?$} {
             set mem_base_address [lshift args]
             if {$mem_base_address == {}} {
				puts " -E- NO DDR3 memory base address specified."
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
			
			
		

			
			# update configuration parameters
			
			if {$board_name == {}} {
				set board_name $old_board_name
			}
			if {$mem_base_address == {}} {
				set mem_base_address $old_mem_base_address
			}
			
			if {$type_eth == {}} {
				set type_eth $old_type_eth
				if {$type_eth==0} {
					set type_eth "udp"
				} elseif {$type_eth==1} {
					set type_eth "tcp"
				}
			} 
			
			if {$type_eth=="udp" || $type_eth=="tcp"} {
				set flag_compile 1
			} else {
				set flag_compile 0
				set tmp_str ""
				append tmp_str " -E- Ethernet type not supported. Use the -usage option for more details."
				puts $tmp_str
				incr error
			}
			
			
			if {$flag_compile==1} {
			
			
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
			

			set type_test "none"
			
			[::tclapp::icl::protoip::make_project_configuration_parameters_dat $project_name $input_vectors $input_vectors_length $input_vectors_type $input_vectors_integer_length $input_vectors_fraction_length $output_vectors $output_vectors_length $output_vectors_type $output_vectors_integer_length $output_vectors_fraction_length $fclk $FPGA_name $board_name $type_eth $mem_base_address $num_test $type_test]
			[::tclapp::icl::protoip::make_ip_configuration_parameters_readme_txt $project_name]
			
			# update ip_design/src/FPGAclientAPI.h file
			[::tclapp::icl::protoip::make_FPGAclientAPI_h  $project_name]
			# update directives
			[::tclapp::icl::protoip::make_echo_c $project_name]
			[::tclapp::icl::protoip::make_FPGAserver_h $project_name]

			set source_file ""
			append source_file "../../../build/prj/" $project_name "." $board_name "/prototype.runs/impl_1/design_1_wrapper.sysdef"
		
			set target_dir ""
			append target_dir "ip_prototype/test/prj/" $project_name "." $board_name
			
		
			#export to SDK
			file delete -force $target_dir
			file mkdir $target_dir
			cd $target_dir
			file copy -force $source_file design_1_wrapper.hdf
			file copy -force ../../../../.metadata/build_sdk_project.tcl build_sdk_project.tcl
			file copy -force ../../../../.metadata/run_fpga_prototype.tcl run_fpga_prototype.tcl
			
			
			# Create SDK Project
			puts "Calling SDK to build the software project ..."

			set sdk_p [open "|xsdk -batch -batch -source build_sdk_project.tcl" r]
			while {![eof $sdk_p]} { gets $sdk_p line ; puts $line }
			close $sdk_p
			
			# set sdk_exit_flag=0 if error, sdk_exit_flag=1 if NOT error
			set sdk_exit_flag [file exists test_fpga/Release/test_fpga.elf]

			

			set error 0
			if {$sdk_exit_flag==1}  {
				puts ""
				puts "Programming the FPGA ..."
				
				set xmd_p [open "|xmd -tcl run_fpga_prototype.tcl" r]
				while {![eof $xmd_p]} { gets $xmd_p line ; puts $line }
				close $xmd_p
				after 5000
				puts "FPGA UDP/TCP server started. FPGA prototype is ready to be used !"
			} else {
				incr error
			}
			
			
		
			
			
			cd ../../../../

			
		}

	
	}
	}

}


	
  if {$help} {
      puts [format {
	Usage: ip_prototype_load
	[-project_name <arg>]	- Project name
							It's a mandatory field
	[-type_eth <arg>]  		- Ethernet connection protocol (udp for UDP-IP connection or tcp for TCP-IP connection)
	[-mem_base_address <arg>]  - DDR3 memory base address

  Description: Build the FPGA Ethernet server application using SDK according to the specification in <WORKING DIRECTORY>/design_parameters.tcl and program the FPGA. A connected evaluation board is required.

  Example:
  tclapp::icl::protoip::ip_prototype_load -project_name my_project0 -type_eth udp -mem_base_address 0


} ]
      # HELP -->
      return {}
    }

	puts ""
    if {$error} {
		puts "SDK: FPGA software project built ERROR. Please run tclapp::icl::protoip::ip_prototype_load_debug to open SDK GUI and debug the software project using Eclipse enviroment"
		puts ""
		return -code error
    } else {
		puts ""
		return -code ok
	}

}



