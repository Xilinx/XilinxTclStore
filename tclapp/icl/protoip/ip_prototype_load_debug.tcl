#  icl::protoip
#  Suardi Andrea [a.suardi@imperial.ac.uk]
#  November - 2014


package require Vivado 1.2014.2

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_prototype_load_debug
}


proc ::tclapp::icl::protoip::ip_prototype_load_debug {args} {

	  # Summary: Compile the Vivado project according to the specification in <WORKING DIRECTORY>/design_parameters.tcl

	  # Argument Usage:
	  # [-project_name <arg>]- Project name
	  # [-usage]: Usage information

	  # Return Value:
	  # return the built FPGA Ethernet server running on the FPGA ARM processor and the loaded designed IP on the FPGA. If any error occur TCL_ERROR is returned

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
			set num_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 12]] 
			set type_test [lindex $data [expr ($num_input_vectors * 5) + ($num_output_vectors * 5) + 5 + 14]] 
			
			
		

			set source_file ""
			append source_file "../../../build/prj/" $project_name "." $board_name "/prototype.runs/impl_1/design_1_wrapper.sysdef"
		
			set target_dir ""
			append target_dir "ip_prototype/test/prj/" $project_name "." $board_name
			
		
			#export to SDK
			cd $target_dir
			file copy -force $source_file design_1_wrapper.hdf
			file copy -force ../../../../.metadata/build_sdk_project.tcl build_sdk_project.tcl
			file copy -force ../../../../.metadata/run_fpga_prototype.tcl run_fpga_prototype.tcl
			
			cd ../../../../
			
			
			# Create SDK Project
			puts "Calling SDK GUI ..."
			
			set command_name "|xsdk -workspace "
			append command_name $target_dir

			set sdk_p [open $command_name r]
			
			

	
	}
	}

}


	
  if {$help} {
      puts [format {
	Usage: ip_prototype_load_debug
	[-project_name <arg>]	- Project name
							It's a mandatory field

  Description: Build and start the FPGA Ethernet server running on the FPGA ARM processor and load the designed IP on the FPGA.

  Example:
  tclapp::icl::protoip::ip_prototype_load_debug -project_name my_project0


} ]
      # HELP -->
      return {}
    }

	puts ""
    if {$error} {
		puts "SDK: FPGA software project built ERROR. Please run tclapp::icl::protoip::ip_prototype_build_sdk_debug to open SDK GUI and debug the software project using Eclipse"
		puts ""
		return -code error
    } else {
		puts ""
		return -code ok
	}

}



