
########################################################################################
## 20/11/2014 - First release 1.0
########################################################################################

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_prototype_load
}


proc ::tclapp::icl::protoip::ip_prototype_load {args} {

	  # Summary: Build the FPGA Ethernet server application using SDK according to the specification in [WORKING DIRECTORY]/design_parameters.tcl and program the FPGA. A connected evaluation board is required.

	  # Argument Usage:
	  # -project_name <arg>: Project name
	  # -board_name <arg>: Evaluation board name
	  # -type_eth <arg>: Ethernet connection protocol (UDP-IP or TCP-IP)
	  # [-mem_base_address <arg>]: DDR3 memory base address
	  # [-usage]: Usage information

	  # Return Value:
	  # Return the built FPGA Ethernet server running on the FPGA ARM processor and the loaded designed IP on the FPGA. If any error occur TCL_ERROR is returned

	  # Categories: 
	  # xilinxtclstore, protoip
	  
 uplevel [concat ::tclapp::icl::protoip::ip_prototype_load::ip_prototype_load $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::icl::protoip::ip_prototype_load::ip_prototype_load {
  variable version {20/11/2014}
} ]	  

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G R A M                              # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::icl::protoip::ip_prototype_load::ip_prototype_load { args } {
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
		 -type_eth -
        {^-t(y(p(e(_(e(th?)?)?)?)?)?)?$} {
             set type_eth [lshift args]
             if {$type_eth == {}} {
				puts " -E- NO ethernet connection type name specified."
				incr error
             } 
	     }
		  -mem_base_address -
        {^-m(e(m(_(b(a(s(e(_(a(d(r(e(s?)?)?)?)?)?)?)?)?)?)?)?)?)?$} {
             set mem_base_address [lshift args]
             if {$mem_base_address == {}} {
				puts " -E- NO DDR3 memory base address specified."
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
 Usage: ip_prototype_load
  -project_name <arg>       - Project name
                              It's a mandatory field
  -board_name <arg>         - Evaluation board name
                              It's a mandatory field
  -type_eth <arg>           - Ethernet connection protocol 
                              ('udp' for UDP-IP connection or 'tcp' for TCP-IP connection)
                              It's a mandatory field
  [-mem_base_address <arg>] - DDR3 memory base address
  [-usage|-u]               - This help message

 Description: 
  Build the FPGA Ethernet server application using SDK according 
  to the project configuration parameters
 [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt
  and program the FPGA.
  
 An evaluation board connected to an host computer through an Ethernet and USB JTAG cable is required.
 
 This command can be run after 'ip_prototype_build' command only.

 Example:
  ip_prototype_load -project_name my_project0  -board_name zedboard -type_eth udp
  ip_prototype_load -project_name my_project0  -board_name zedboard -type_eth udp -mem_base_address 33554432


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
			set old_type_eth [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 8]] 
			set old_mem_base_address [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 10]] 
			set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
			set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 
			set type_template [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 16]]
			set type_design_flow [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 18]] 
			
		

			
			# update configuration parameters
			
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
				

				set tmp_error ""
				append tmp_error " -E- Ethernet type" $type_eth " is not supported. Use the -usage option for more details."
				error $tmp_error

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
			
			

			set source_file ""
			append source_file "ip_prototype/build/prj/" $project_name "." $board_name "/prototype.runs/impl_1/design_1_wrapper.sysdef"
			
			if {[file exists $source_file] == 0} { 

				set tmp_error ""
				append tmp_error "-E- " $project_name " associated to " $board_name " has not been built. Use the -usage option for more details."
				error $tmp_error
			
			} else {
			
			[::tclapp::icl::protoip::make_template::make_project_configuration_parameters_dat $project_name $input_vectors $input_vectors_length $input_vectors_type $input_vectors_integer_length $input_vectors_fraction_length $output_vectors $output_vectors_length $output_vectors_type $output_vectors_integer_length $output_vectors_fraction_length $fclk $FPGA_name $board_name $type_eth $mem_base_address $num_test $type_test $type_template $type_design_flow]
			[::tclapp::icl::protoip::make_template::make_ip_configuration_parameters_readme_txt $project_name]
			
			# update ip_design/src/FPGAclientAPI.h file
			[::tclapp::icl::protoip::make_template::make_FPGAclientAPI_h  $project_name]
			# update directives
			[::tclapp::icl::protoip::make_template::make_echo_c $project_name]
			[::tclapp::icl::protoip::make_template::make_FPGAserver_h $project_name]
		
			set target_dir ""
			append target_dir "ip_prototype/test/prj/" $project_name "." $board_name
			
			set source_file ""
			append source_file "../../../build/prj/" $project_name "." $board_name "/prototype.runs/impl_1/design_1_wrapper.sysdef"
		
			#export to SDK
			file delete -force $target_dir
			file mkdir $target_dir
			cd $target_dir
			file copy -force $source_file design_1_wrapper.hdf
			
			file copy -force ../../../../.metadata/build_sdk_project.tcl build_sdk_project.tcl
			file copy -force ../../../../.metadata/run_fpga_prototype.tcl run_fpga_prototype.tcl
			
			
			# Create SDK Project
			puts "Calling SDK to build the software project ..."

			set sdk_p [open "|xsct build_sdk_project.tcl" r]
			while {![eof $sdk_p]} { gets $sdk_p line ; puts $line }
			close $sdk_p
			
			# set sdk_exit_flag=0 if error, sdk_exit_flag=1 if NOT error
			set sdk_exit_flag [file exists workspace1/test_fpga/Release/test_fpga.elf]


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
	}

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



