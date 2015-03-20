
########################################################################################
## 20/11/2014 - First release 1.0
########################################################################################

namespace eval ::tclapp::icl::protoip {
    # Export procs that should be allowed to import into other namespaces
    namespace export ip_prototype_build_debug
}


proc ::tclapp::icl::protoip::ip_prototype_build_debug {args} {

	  # Summary: Open Vivado GUI to debug the project named 'project_name' according to the project configuration parameters [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt

	  # Argument Usage:
	  # -project_name <arg>: Project name
	  # -board_name <arg>: Evaluation board name
	  # [-usage]: Usage information

	  # Return Value:
	  # Open Vivado GUI to debug the prototype hardware project. If any error occur TCL_ERROR is returned

	  # Categories: 
	  # xilinxtclstore, protoip
	  
uplevel [concat ::tclapp::icl::protoip::ip_prototype_build_debug::ip_prototype_build_debug $args]
}

# Trick to silence the linter
eval [list namespace eval ::tclapp::icl::protoip::ip_prototype_build_debug::ip_prototype_build_debug {
  variable version {20/11/2014}
} ]	  

#**********************************************************************************#
# #******************************************************************************# #
# #                                                                              # #
# #                         M A I N   P R O G R A M                              # #
# #                                                                              # #
# #******************************************************************************# #
#**********************************************************************************#

proc ::tclapp::icl::protoip::ip_prototype_build_debug::ip_prototype_build_debug { args } {
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
		  -board_name -
        {^-b(o(a(r(d(_(n(a(me?)?)?)?)?)?)?)?)?$} {
             set board_name [lshift args]
             if {$board_name == {}} {
				puts " -E- NO board name specified."
				incr error
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
 Usage: ip_prototype_build_debug
  -project_name <arg>  - Project name
                         It's a mandatory field
  -board_name <arg>    - Evaluation board name
                         It's a mandatory field
  [-usage|-u]          - This help message


 Description: 
  Open Vivado GUI to debug the project named 'project_name' 
  associated to the evaluation board name 'board_name'
  according to the project configuration parameters
  [WORKING DIRECTORY]/doc/project_name/ip_configuration_parameters.txt
  
  This command should be run after 'ip_prototype_build' command only.

 Example:
  ip_prototype_build_debug -project_name my_project0 -board_name zedboard


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

		
		set target_dir ""
		append target_dir "ip_prototype/build/prj/" $project_name "." $board_name	
			
		if {[file exists $target_dir] == 0} { 

			set tmp_error ""
			append tmp_error "-E- " $project_name " associated to " $board_name " does NOT exist. Use the -usage option for more details."
			error $tmp_error
			
		} else {	
			
		puts ""
		puts "Open Vivado GUI ..."

		
		
		cd $target_dir
		
		set vivado_p [open "|vivado -mode gui prototype.xpr" r]
		while {![eof $vivado_p]} { gets $vivado_p line ; puts $line }
		close $vivado_p

		cd ../../../../

		}
		}
	
	}
	}

}




	puts ""
    if {$error} {
		puts ""
		return -code error
    } else {
		puts "Vivado GUI closed successfully"
		puts ""
		return -code ok
	}

}


  